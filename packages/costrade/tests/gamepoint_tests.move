/// Tests for the COSPT gamepoint token (mint, burn, transfer).
#[test_only]
module costrade::gamepoint_tests {

    use sui::test_scenario::{Self};
    use sui::coin::{Self, TreasuryCap};
    use costrade::gamepoint::{Self, GAMEPOINT};

    const ADMIN:     address = @0xA;
    const ALICE:     address = @0xB;
    const BOB:       address = @0xC;

    fun deploy_gamepoint(): sui::test_scenario::Scenario {
        let mut s = test_scenario::begin(ADMIN);
        {
            gamepoint::init_for_testing(test_scenario::ctx(&mut s));
        };
        s
    }

    #[test]
    fun test_init_creates_treasury_cap() {
        let mut s = deploy_gamepoint();
        test_scenario::next_tx(&mut s, ADMIN);
        {
            // Admin should have received TreasuryCap
            assert!(test_scenario::has_most_recent_for_address<TreasuryCap<GAMEPOINT>>(ADMIN), 0);
        };
        test_scenario::end(s);
    }

    #[test]
    fun test_mint() {
        let mut s = deploy_gamepoint();
        test_scenario::next_tx(&mut s, ADMIN);
        {
            let mut cap = test_scenario::take_from_address<TreasuryCap<GAMEPOINT>>(&s, ADMIN);
            gamepoint::mint(&mut cap, 1000, ALICE, test_scenario::ctx(&mut s));
            test_scenario::return_to_address(ADMIN, cap);
        };
        test_scenario::next_tx(&mut s, ALICE);
        {
            let coin = test_scenario::take_from_address<coin::Coin<GAMEPOINT>>(&s, ALICE);
            assert!(coin::value(&coin) == 1000, 0);
            test_scenario::return_to_address(ALICE, coin);
        };
        test_scenario::end(s);
    }

    #[test]
    fun test_burn() {
        let mut s = deploy_gamepoint();
        // Mint to admin
        test_scenario::next_tx(&mut s, ADMIN);
        {
            let mut cap = test_scenario::take_from_address<TreasuryCap<GAMEPOINT>>(&s, ADMIN);
            gamepoint::mint(&mut cap, 500, ADMIN, test_scenario::ctx(&mut s));
            test_scenario::return_to_address(ADMIN, cap);
        };
        // Burn
        test_scenario::next_tx(&mut s, ADMIN);
        {
            let mut cap  = test_scenario::take_from_address<TreasuryCap<GAMEPOINT>>(&s, ADMIN);
            let     coin = test_scenario::take_from_address<coin::Coin<GAMEPOINT>>(&s, ADMIN);
            gamepoint::burn(&mut cap, coin);
            test_scenario::return_to_address(ADMIN, cap);
        };
        // Total supply should be 0
        test_scenario::next_tx(&mut s, ADMIN);
        {
            let cap = test_scenario::take_from_address<TreasuryCap<GAMEPOINT>>(&s, ADMIN);
            assert!(coin::total_supply(&cap) == 0, 0);
            test_scenario::return_to_address(ADMIN, cap);
        };
        test_scenario::end(s);
    }

    #[test]
    fun test_transfer() {
        let mut s = deploy_gamepoint();
        test_scenario::next_tx(&mut s, ADMIN);
        {
            let mut cap = test_scenario::take_from_address<TreasuryCap<GAMEPOINT>>(&s, ADMIN);
            gamepoint::mint(&mut cap, 200, ALICE, test_scenario::ctx(&mut s));
            test_scenario::return_to_address(ADMIN, cap);
        };
        // Alice transfers to Bob
        test_scenario::next_tx(&mut s, ALICE);
        {
            let c = test_scenario::take_from_address<coin::Coin<GAMEPOINT>>(&s, ALICE);
            gamepoint::transfer(c, BOB, test_scenario::ctx(&mut s));
        };
        test_scenario::next_tx(&mut s, BOB);
        {
            let c = test_scenario::take_from_address<coin::Coin<GAMEPOINT>>(&s, BOB);
            assert!(coin::value(&c) == 200, 0);
            test_scenario::return_to_address(BOB, c);
        };
        test_scenario::end(s);
    }
}
