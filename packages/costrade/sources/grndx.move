/// Main perpetuals trading module — orderbook, accounts, deposits, withdrawals,
/// trading positions, and price cranking.
/// Mirrors `grndx::just` (file `grndx.move`) re-implemented for Sui.
///
/// Key architectural changes from Aptos:
///   • Global resources (`has key` stored at addresses) → Sui shared objects
///     passed as `&mut T` parameters.
///   • `Coin<AptosCoin>` → `Coin<SUI>` / `Balance<SUI>`.
///   • `smart_table` → `sui::table::Table`.
///   • `aptos_framework::randomness` → `sui::random::Random` parameter.
///   • `init_module` → `fun init(ctx)` (package initializer).
module costrade::grndx {

    use std::vector;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};
    use sui::event;
    use sui::sui::SUI;
    use sui::random::{Self, Random};
    use costrade::box_muller;
    use costrade::fixed_point64;
    use costrade::fixed_point64_with_sign;
    use costrade::math_fixed64;
    use costrade::math_fixed64_with_sign;

    // ── Constants ────────────────────────────────────────────────────────────────

    const ENOT_OWNER:          u64 = 1;
    const ENO_ACCOUNT:         u64 = 2;
    const EINSUFFICIENT_FUNDS: u64 = 3;
    const ENO_POSITION:        u64 = 4;
    const EALREADY_ACCOUNT:    u64 = 5;

    const PRICE_RESET:   u64 = 52_500_000;
    const PRICE_MAX:     u64 = 100_000_000;
    const PRICE_MIN:     u64 = 5_000_000;
    const SCALE:         u64 = 1_000_000;   // 1 SUI = 1 000 000 MIST

    // ── On-chain types ───────────────────────────────────────────────────────────

    /// Composite key for each market account.
    public struct MarketAccountKey has copy, drop, store {
        protocol_address: address,
        user_address:     address,
    }

    /// Per-user market state.
    public struct MarketAccount has store {
        instrument_balance: Balance<SUI>,   // unrealised position value
        margin_balance:     Balance<SUI>,   // posted margin
        owner:              address,
        order_counter:      u64,
        contract_balance:   u64,            // open contract quantity
        side_long:          bool,
        index_position:     u64,            // price at which position was opened
    }

    /// Central orderbook — deployed as a shared object.
    public struct Orderbook has key, store {
        id:       UID,
        accounts: Table<MarketAccountKey, MarketAccount>,
        admin:    address,
    }

    /// Stateful price / message structs for cranking.
    public struct RandomIndex has key, store {
        id:    UID,
        price: u64,
    }

    public struct Message has key, store {
        id:         UID,
        my_message: u64,
    }

    // ── Events ────────────────────────────────────────────────────────────────────

    public struct PriceEvent has copy, drop {
        price: u64,
    }

    public struct RandomIndexEvent has copy, drop {
        price: u64,
    }

    public struct LiquidatePositionEvent has copy, drop {
        user:       address,
        pnl:        u64,
        is_profit:  bool,
    }

    public struct TradeEvent has copy, drop {
        user:      address,
        leverage:  u64,
        contracts: u64,
        side_long: bool,
        price:     u64,
    }

    public struct OpenAccountEvent has copy, drop {
        user: address,
    }

    // ── Module initialiser ────────────────────────────────────────────────────────

    fun init(ctx: &mut TxContext) {
        let admin = tx_context::sender(ctx);

        let book = Orderbook {
            id:       object::new(ctx),
            accounts: table::new(ctx),
            admin,
        };
        transfer::share_object(book);

        let ri = RandomIndex { id: object::new(ctx), price: PRICE_RESET };
        transfer::share_object(ri);

        let msg = Message { id: object::new(ctx), my_message: 0 };
        transfer::share_object(msg);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) { init(ctx); }

    // ── Account management ────────────────────────────────────────────────────────

    /// Open a market account for the caller.
    public entry fun hope_it(
        book: &mut Orderbook,
        ctx:  &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let key  = MarketAccountKey {
            protocol_address: object::id_address(book),
            user_address:     user,
        };
        assert!(!table::contains(&book.accounts, key), EALREADY_ACCOUNT);

        let account = MarketAccount {
            instrument_balance: balance::zero<SUI>(),
            margin_balance:     balance::zero<SUI>(),
            owner:              user,
            order_counter:      0,
            contract_balance:   0,
            side_long:          true,
            index_position:     0,
        };
        table::add(&mut book.accounts, key, account);
        event::emit(OpenAccountEvent { user });
    }

    // ── Deposits / withdrawals ────────────────────────────────────────────────────

    /// Deposit SUI into the caller's margin balance.
    public entry fun depeche_it(
        book: &mut Orderbook,
        coin: Coin<SUI>,
        ctx:  &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let key  = make_key(book, user);
        assert!(table::contains(&book.accounts, key), ENO_ACCOUNT);

        let account = table::borrow_mut(&mut book.accounts, key);
        assert!(account.owner == user, ENOT_OWNER);
        let bal = coin::into_balance(coin);
        balance::join(&mut account.margin_balance, bal);
    }

    /// Withdraw `amount` MIST from the caller's margin balance.
    public entry fun without_it(
        book:   &mut Orderbook,
        amount: u64,
        ctx:    &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let key  = make_key(book, user);
        assert!(table::contains(&book.accounts, key), ENO_ACCOUNT);

        let account = table::borrow_mut(&mut book.accounts, key);
        assert!(account.owner == user, ENOT_OWNER);
        assert!(balance::value(&account.margin_balance) >= amount, EINSUFFICIENT_FUNDS);

        let payout = coin::from_balance(
            balance::split(&mut account.margin_balance, amount),
            ctx,
        );
        transfer::public_transfer(payout, user);
    }

    // ── Trading ───────────────────────────────────────────────────────────────────

    /// Open / update a leveraged position.
    /// `leverage`  — integer multiplier (1–100)
    /// `contracts` — number of contracts
    /// `side_long` — true = long, false = short
    public entry fun said_it(
        book:      &mut Orderbook,
        rand_idx:  &RandomIndex,
        leverage:  u64,
        contracts: u64,
        side_long: bool,
        ctx:       &mut TxContext,
    ) {
        let user  = tx_context::sender(ctx);
        let key   = make_key(book, user);
        assert!(table::contains(&book.accounts, key), ENO_ACCOUNT);
        let price = rand_idx.price;

        let account = table::borrow_mut(&mut book.accounts, key);
        assert!(account.owner == user, ENOT_OWNER);

        // Required margin = contracts * price / leverage / SCALE
        let required_margin = contracts * price / leverage / SCALE;
        assert!(balance::value(&account.margin_balance) >= required_margin, EINSUFFICIENT_FUNDS);

        account.contract_balance = contracts;
        account.side_long        = side_long;
        account.index_position   = price;
        account.order_counter    = account.order_counter + 1;

        event::emit(TradeEvent {
            user,
            leverage,
            contracts,
            side_long,
            price,
        });
    }

    /// Liquidate / close a position and settle PnL.
    public entry fun liquidate_it(
        book:     &mut Orderbook,
        rand_idx: &RandomIndex,
        ctx:      &mut TxContext,
    ) {
        let user  = tx_context::sender(ctx);
        let key   = make_key(book, user);
        assert!(table::contains(&book.accounts, key), ENO_ACCOUNT);

        let account   = table::borrow_mut(&mut book.accounts, key);
        assert!(account.owner == user, ENOT_OWNER);
        assert!(account.contract_balance > 0, ENO_POSITION);

        let current_price = rand_idx.price;
        let open_price    = account.index_position;
        let contracts     = account.contract_balance;

        // PnL = (current - open) * contracts / SCALE  (can be negative)
        let pnl_is_profit: bool;
        let pnl_amount:    u64;

        if (account.side_long) {
            if (current_price >= open_price) {
                pnl_amount    = (current_price - open_price) * contracts / SCALE;
                pnl_is_profit = true;
            } else {
                pnl_amount    = (open_price - current_price) * contracts / SCALE;
                pnl_is_profit = false;
            }
        } else {
            if (open_price >= current_price) {
                pnl_amount    = (open_price - current_price) * contracts / SCALE;
                pnl_is_profit = true;
            } else {
                pnl_amount    = (current_price - open_price) * contracts / SCALE;
                pnl_is_profit = false;
            }
        };

        // Settle: if profit, transfer from instrument to margin; if loss, vice versa.
        if (pnl_is_profit) {
            let avail = balance::value(&account.instrument_balance);
            let pay   = if (pnl_amount <= avail) { pnl_amount } else { avail };
            let b     = balance::split(&mut account.instrument_balance, pay);
            balance::join(&mut account.margin_balance, b);
        } else {
            let avail = balance::value(&account.margin_balance);
            let take  = if (pnl_amount <= avail) { pnl_amount } else { avail };
            let b     = balance::split(&mut account.margin_balance, take);
            balance::join(&mut account.instrument_balance, b);
        };

        account.contract_balance = 0;
        account.index_position   = 0;

        event::emit(LiquidatePositionEvent { user, pnl: pnl_amount, is_profit: pnl_is_profit });
    }

    // ── Price cranking ─────────────────────────────────────────────────────────────

    /// Update the random price index using a Box–Muller normal draw.
    ///
    /// price_new = sqrt(exp(z / 200)) / 200 * price_old
    /// If price falls outside [PRICE_MIN, PRICE_MAX], reset to PRICE_RESET.
    public entry fun crank_random_index(
        book:     &mut Orderbook,
        rand_idx: &mut RandomIndex,
        msg:      &mut Message,
        rng:      &Random,
        ctx:      &mut TxContext,
    ) {
        let mut generator = random::new_generator(rng, ctx);
        let z = box_muller::normal_r1(&mut generator);

        let one = 1u128 << 64;
        let scaled  = math_fixed64_with_sign::div_u128(z, 200);
        let e_val   = math_fixed64_with_sign::exp(scaled);
        let e_fp    = fixed_point64::create_from_raw_value(
            fixed_point64_with_sign::get_raw_value(e_val),
        );
        let factor  = math_fixed64::sqrt(e_fp);
        let factor_raw = fixed_point64::get_raw_value(factor);

        // new_price = old_price * factor / 2^64
        let new_price_u128 = math_fixed64::mul_div_raw(
            (rand_idx.price as u128),
            factor_raw,
            one,
        );
        let mut new_price = new_price_u128 as u64;

        if (new_price > PRICE_MAX || new_price < PRICE_MIN) {
            new_price = PRICE_RESET;
        };

        rand_idx.price  = new_price;
        msg.my_message  = msg.my_message + 1;

        event::emit(PriceEvent { price: new_price });
        event::emit(RandomIndexEvent { price: new_price });
    }

    // ── Read-only helpers ──────────────────────────────────────────────────────────

    public fun get_price(rand_idx: &RandomIndex): u64 { rand_idx.price }

    public fun margin_balance_of(book: &Orderbook, user: address): u64 {
        let key = make_key(book, user);
        if (table::contains(&book.accounts, key)) {
            balance::value(&table::borrow(&book.accounts, key).margin_balance)
        } else {
            0
        }
    }

    public fun position_of(book: &Orderbook, user: address): (u64, bool, u64) {
        let key = make_key(book, user);
        if (table::contains(&book.accounts, key)) {
            let acc = table::borrow(&book.accounts, key);
            (acc.contract_balance, acc.side_long, acc.index_position)
        } else {
            (0, true, 0)
        }
    }

    // ── Private helpers ────────────────────────────────────────────────────────────

    fun make_key(book: &Orderbook, user: address): MarketAccountKey {
        MarketAccountKey {
            protocol_address: object::id_address(book),
            user_address:     user,
        }
    }

    /// Lookup table: 10^e for e in 0..18.
    public fun exp64(e: u8): u64 {
        if      (e == 0)  { 1 }
        else if (e == 1)  { 10 }
        else if (e == 2)  { 100 }
        else if (e == 3)  { 1_000 }
        else if (e == 4)  { 10_000 }
        else if (e == 5)  { 100_000 }
        else if (e == 6)  { 1_000_000 }
        else if (e == 7)  { 10_000_000 }
        else if (e == 8)  { 100_000_000 }
        else if (e == 9)  { 1_000_000_000 }
        else if (e == 10) { 10_000_000_000 }
        else if (e == 11) { 100_000_000_000 }
        else if (e == 12) { 1_000_000_000_000 }
        else if (e == 13) { 10_000_000_000_000 }
        else if (e == 14) { 100_000_000_000_000 }
        else if (e == 15) { 1_000_000_000_000_000 }
        else if (e == 16) { 10_000_000_000_000_000 }
        else if (e == 17) { 100_000_000_000_000_000 }
        else              { 1_000_000_000_000_000_000 }
    }
}
