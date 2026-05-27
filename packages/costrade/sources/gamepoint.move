/// COSPT — "Costrade Point" fungible token.
/// Mirrors `grndx::gamepoint` (Aptos fungible-asset standard) re-implemented
/// using the Sui Coin pattern.
///
/// One-time-witness pattern: `GAMEPOINT` struct is passed to `coin::create_currency`
/// in `init`, which mints zero tokens and hands the `TreasuryCap` to the deployer.
module costrade::gamepoint {

    use std::option;
    use std::string;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin, TreasuryCap, DenyCapV2};
    use sui::deny_list::DenyList;
    use sui::url;

    /// One-time witness — must match module name in SCREAMING_SNAKE_CASE.
    public struct GAMEPOINT has drop {}

    /// Admin capability — held by the deployer to mint / burn.
    public struct AdminCap has key, store {
        id: UID,
    }

    // ── Module initialiser ───────────────────────────────────────────────────────

    fun init(witness: GAMEPOINT, ctx: &mut TxContext) {
        let (treasury_cap, deny_cap, metadata) = coin::create_regulated_currency_v2(
            witness,
            0,   // decimals
            b"COSPT",
            b"Costrade Point",
            b"Costrade platform reward token",
            option::some(url::new_unsafe_from_bytes(
                b"https://f5c4dfa0fe2c14e113d9881788a255fa.blok.host/favicon.ico",
            )),
            false, // allow_global_pause
            ctx,
        );

        // Freeze the metadata object so it cannot be mutated post-deploy.
        transfer::public_freeze_object(metadata);

        // Send treasury cap and deny cap to the deployer.
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(treasury_cap, sender);
        transfer::public_transfer(deny_cap, sender);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) { init(GAMEPOINT {}, ctx); }

    // ── Token operations ─────────────────────────────────────────────────────────

    /// Mint `amount` COSPT tokens and send them to `recipient`.
    public entry fun mint(
        cap:       &mut TreasuryCap<GAMEPOINT>,
        amount:    u64,
        recipient: address,
        ctx:       &mut TxContext,
    ) {
        let coin = coin::mint(cap, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }

    /// Burn the provided coin.
    public entry fun burn(
        cap:  &mut TreasuryCap<GAMEPOINT>,
        coin: Coin<GAMEPOINT>,
    ) {
        coin::burn(cap, coin);
    }

    /// Freeze an account (prevent sends and receives).
    public entry fun freeze_account(
        deny_cap:   &mut DenyCapV2<GAMEPOINT>,
        deny_list:  &mut DenyList,
        account:    address,
        ctx:        &mut TxContext,
    ) {
        coin::deny_list_v2_add(deny_list, deny_cap, account, ctx);
    }

    /// Unfreeze an account.
    public entry fun unfreeze_account(
        deny_cap:  &mut DenyCapV2<GAMEPOINT>,
        deny_list: &mut DenyList,
        account:   address,
        ctx:       &mut TxContext,
    ) {
        coin::deny_list_v2_remove(deny_list, deny_cap, account, ctx);
    }

    /// Transfer `amount` COSPT from the caller's coin to `recipient`.
    public entry fun transfer(
        coin:      Coin<GAMEPOINT>,
        recipient: address,
        _ctx:      &mut TxContext,
    ) {
        transfer::public_transfer(coin, recipient);
    }
}
