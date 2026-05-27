/// Integration tests for the grndx trading module.
/// Uses test_scenario to simulate shared-object interactions.
#[test_only]
module costrade::trading_tests {

    use sui::test_scenario::{Self, Scenario};
    use sui::coin;
    use sui::sui::SUI;
    use costrade::grndx::{Self, Orderbook, RandomIndex, Message};

    const ADMIN: address = @0xA;
    const USER:  address = @0xB;
    const USER2: address = @0xC;

    // ── Helpers ─────────────────────────────────────────────────────────────────

    /// Deploy the grndx module and return the scenario after init.
    fun deploy(): Scenario {
        let mut s = test_scenario::begin(ADMIN);
        {
            grndx::init_for_testing(test_scenario::ctx(&mut s));
        };
        s
    }

    // ── Deployment ──────────────────────────────────────────────────────────────

    #[test]
    fun test_deploy_creates_shared_objects() {
        let mut s = deploy();
        test_scenario::next_tx(&mut s, ADMIN);
        {
            // Orderbook should exist as a shared object
            let book = test_scenario::take_shared<Orderbook>(&s);
            let ri   = test_scenario::take_shared<RandomIndex>(&s);
            let msg  = test_scenario::take_shared<Message>(&s);

            // Default price should be PRICE_RESET = 52_500_000
            assert!(grndx::get_price(&ri) == 52_500_000, 0);

            test_scenario::return_shared(book);
            test_scenario::return_shared(ri);
            test_scenario::return_shared(msg);
        };
        test_scenario::end(s);
    }

    // ── Account management ───────────────────────────────────────────────────────

    #[test]
    fun test_open_account() {
        let mut s = deploy();
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            grndx::hope_it(&mut book, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        test_scenario::next_tx(&mut s, USER);
        {
            let book = test_scenario::take_shared<Orderbook>(&s);
            // margin balance should be 0 initially
            assert!(grndx::margin_balance_of(&book, USER) == 0, 0);
            test_scenario::return_shared(book);
        };
        test_scenario::end(s);
    }

    #[test]
    #[expected_failure]
    fun test_open_account_twice_fails() {
        let mut s = deploy();
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            grndx::hope_it(&mut book, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        // Second call from same user should abort (EALREADY_ACCOUNT)
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            grndx::hope_it(&mut book, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        test_scenario::end(s);
    }

    // ── Deposit / Withdraw ───────────────────────────────────────────────────────

    #[test]
    fun test_deposit() {
        let mut s = deploy();
        // Open account
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            grndx::hope_it(&mut book, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        // Deposit 1000 MIST
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            let payment  = coin::mint_for_testing<SUI>(1000, test_scenario::ctx(&mut s));
            grndx::depeche_it(&mut book, payment, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        // Check balance
        test_scenario::next_tx(&mut s, USER);
        {
            let book = test_scenario::take_shared<Orderbook>(&s);
            assert!(grndx::margin_balance_of(&book, USER) == 1000, 0);
            test_scenario::return_shared(book);
        };
        test_scenario::end(s);
    }

    #[test]
    fun test_withdraw() {
        let mut s = deploy();
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            grndx::hope_it(&mut book, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            let payment  = coin::mint_for_testing<SUI>(500, test_scenario::ctx(&mut s));
            grndx::depeche_it(&mut book, payment, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        // Withdraw 200
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            grndx::without_it(&mut book, 200, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        test_scenario::next_tx(&mut s, USER);
        {
            let book = test_scenario::take_shared<Orderbook>(&s);
            assert!(grndx::margin_balance_of(&book, USER) == 300, 0);
            test_scenario::return_shared(book);
        };
        test_scenario::end(s);
    }

    #[test]
    #[expected_failure]
    fun test_withdraw_more_than_balance_fails() {
        let mut s = deploy();
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            grndx::hope_it(&mut book, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            let payment  = coin::mint_for_testing<SUI>(100, test_scenario::ctx(&mut s));
            grndx::depeche_it(&mut book, payment, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        // Try to withdraw 200 when balance is only 100 — should fail
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            grndx::without_it(&mut book, 200, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        test_scenario::end(s);
    }

    // ── Trading ──────────────────────────────────────────────────────────────────

    #[test]
    fun test_open_long_position() {
        let mut s = deploy();
        // Setup account with large deposit
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            grndx::hope_it(&mut book, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            // Deposit enough to cover margin: price=52_500_000, leverage=10, 1 contract
            // required = 1 * 52_500_000 / 10 / 1_000_000 = 5
            let payment = coin::mint_for_testing<SUI>(100_000, test_scenario::ctx(&mut s));
            grndx::depeche_it(&mut book, payment, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            let ri   = test_scenario::take_shared<RandomIndex>(&s);
            // leverage=10, contracts=1, long=true
            grndx::said_it(&mut book, &ri, 10, 1, true, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
            test_scenario::return_shared(ri);
        };
        test_scenario::next_tx(&mut s, USER);
        {
            let book = test_scenario::take_shared<Orderbook>(&s);
            let (contracts, side_long, _index_price) = grndx::position_of(&book, USER);
            assert!(contracts == 1, 0);
            assert!(side_long, 0);
            test_scenario::return_shared(book);
        };
        test_scenario::end(s);
    }

    #[test]
    fun test_liquidate_position() {
        let mut s = deploy();
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            grndx::hope_it(&mut book, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            let payment = coin::mint_for_testing<SUI>(1_000_000, test_scenario::ctx(&mut s));
            grndx::depeche_it(&mut book, payment, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            let ri   = test_scenario::take_shared<RandomIndex>(&s);
            grndx::said_it(&mut book, &ri, 10, 1, true, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
            test_scenario::return_shared(ri);
        };
        // Close (liquidate) the position
        test_scenario::next_tx(&mut s, USER);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            let ri   = test_scenario::take_shared<RandomIndex>(&s);
            grndx::liquidate_it(&mut book, &ri, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
            test_scenario::return_shared(ri);
        };
        test_scenario::next_tx(&mut s, USER);
        {
            let book = test_scenario::take_shared<Orderbook>(&s);
            let (contracts, _, _) = grndx::position_of(&book, USER);
            // Position should be closed
            assert!(contracts == 0, 0);
            test_scenario::return_shared(book);
        };
        test_scenario::end(s);
    }

    // ── Access control ────────────────────────────────────────────────────────────

    #[test]
    #[expected_failure]
    fun test_deposit_without_account_fails() {
        let mut s = deploy();
        // USER2 has no account — deposit must fail (ENO_ACCOUNT)
        test_scenario::next_tx(&mut s, USER2);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            let payment  = coin::mint_for_testing<SUI>(100, test_scenario::ctx(&mut s));
            grndx::depeche_it(&mut book, payment, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
        };
        test_scenario::end(s);
    }

    #[test]
    #[expected_failure]
    fun test_trade_without_account_fails() {
        let mut s = deploy();
        test_scenario::next_tx(&mut s, USER2);
        {
            let mut book = test_scenario::take_shared<Orderbook>(&s);
            let ri   = test_scenario::take_shared<RandomIndex>(&s);
            grndx::said_it(&mut book, &ri, 10, 1, true, test_scenario::ctx(&mut s));
            test_scenario::return_shared(book);
            test_scenario::return_shared(ri);
        };
        test_scenario::end(s);
    }

    // ── exp64 lookup table ────────────────────────────────────────────────────────

    #[test]
    fun test_exp64_table() {
        assert!(grndx::exp64(0) == 1, 0);
        assert!(grndx::exp64(1) == 10, 0);
        assert!(grndx::exp64(6) == 1_000_000, 0);
        assert!(grndx::exp64(9) == 1_000_000_000, 0);
        assert!(grndx::exp64(18) == 1_000_000_000_000_000_000, 0);
    }
}
