/// Probability distribution utilities + stateful random-index tracking.
/// Mirrors `grndx::prob_distribution`.
///
/// Aptos `has key` resources → Sui shared objects.
/// Aptos `#[randomness]` attribute → Sui `Random` passed as parameter.
module costrade::prob_distribution {

    use std::vector;
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::transfer;
    use sui::event;
    use sui::random::{Self, Random, RandomGenerator};
    use costrade::fixed_point64::{Self, FixedPoint64};
    use costrade::fixed_point64_with_sign::{Self, FixedPoint64WithSign};
    use costrade::math_fixed64;
    use costrade::math_fixed64_with_sign;
    use costrade::box_muller;
    use costrade::laplacian_transform;
    use costrade::exponential_transform;
    use costrade::chisquare_transform;

    // ── Shared state ─────────────────────────────────────────────────────────────

    /// Wraps a simple u64 message / last-seen index.
    public struct MessageRessource has key, store {
        id:           UID,
        my_Rmessage:  u64,
    }

    /// Stateful random index used for price cranking.
    public struct RandomIndex has key, store {
        id:    UID,
        price: u128,
    }

    // ── Events ───────────────────────────────────────────────────────────────────

    public struct IndexEvent has copy, drop {
        price: u64,
    }

    public struct RandomIndexEvent has copy, drop {
        price: u128,
    }

    // ── Init helpers ─────────────────────────────────────────────────────────────

    /// Create and share a fresh `RandomIndex` (callable by anyone once).
    public entry fun create_random_index(ctx: &mut TxContext) {
        let ri = RandomIndex { id: object::new(ctx), price: 0 };
        transfer::share_object(ri);
    }

    /// Reset the tracked price to zero.
    public entry fun reset_random_index(ri: &mut RandomIndex) {
        ri.price = 0;
    }

    // ── Normal-distribution helpers ──────────────────────────────────────────────

    /// Return `count` normally-distributed FP64WithSign values.
    public fun get_nd_random_numbers(
        rng:   &mut RandomGenerator,
        count: u64,
    ): vector<FixedPoint64WithSign> {
        let range: u128 = 10_000_000_000_000_000;
        let mut result: vector<FixedPoint64WithSign> = vector::empty();
        let mut i: u64 = 0;
        while (i < count) {
            let u1  = (random::generate_u128_in_range(rng, 1, range) as u128);
            let u2  = (random::generate_u128_in_range(rng, 1, range) as u128);
            let val = box_muller::normalize_u1_u2_r1(u1, u2, range);
            vector::push_back(&mut result, val);
            i = i + 1;
        };
        result
    }

    /// Return a single normally-distributed value.
    public fun get_nd_random_number(rng: &mut RandomGenerator): FixedPoint64WithSign {
        box_muller::normal_r1(rng)
    }

    /// Write a single normal-distribution draw to a shared `RandomIndex`.
    public entry fun set_nd_random_number(
        ri:  &mut RandomIndex,
        rng: &Random,
        ctx: &mut TxContext,
    ) {
        let mut generator = random::new_generator(rng, ctx);
        let val   = box_muller::normal_r1(&mut generator);
        ri.price  = fixed_point64_with_sign::get_raw_value(val);
        event::emit(RandomIndexEvent { price: ri.price });
    }

    /// Read the current `RandomIndex` price.
    public fun get_nd_random_index(ri: &RandomIndex): u128 { ri.price }

    // ── Other distribution helpers ───────────────────────────────────────────────

    /// Laplacian random numbers.
    public fun get_ll_random_numbers(
        rng:   &mut RandomGenerator,
        count: u64,
        mu:    FixedPoint64WithSign,
        beta:  FixedPoint64,
    ): vector<FixedPoint64WithSign> {
        let range: u128 = 10_000_000_000_000_000;
        let mut result: vector<FixedPoint64WithSign> = vector::empty();
        let mut i: u64 = 0;
        while (i < count) {
            let rn  = random::generate_u128_in_range(rng, 0, range - 1) as u128;
            let val = laplacian_transform::uniform_to_laplacian(rn, range, mu, beta);
            vector::push_back(&mut result, val);
            i = i + 1;
        };
        result
    }

    /// Exponential random numbers.
    public fun get_ed_random_numbers(
        rng:    &mut RandomGenerator,
        count:  u64,
        lambda: FixedPoint64,
    ): vector<FixedPoint64> {
        let range: u128 = 10_000_000_000_000_000;
        let mut result: vector<FixedPoint64> = vector::empty();
        let mut i: u64 = 0;
        while (i < count) {
            let rn  = random::generate_u128_in_range(rng, 0, range - 1) as u128;
            let val = exponential_transform::uniform_to_exponential(rn, range, lambda);
            vector::push_back(&mut result, val);
            i = i + 1;
        };
        result
    }

    /// Chi-square random numbers.
    public fun get_cq_random_numbers(
        rng:   &mut RandomGenerator,
        count: u64,
    ): vector<FixedPoint64> {
        let range: u64 = 10_000_000;
        let mut raw: vector<u64> = vector::empty();
        let mut i: u64 = 0;
        while (i < count * 2) {  // need 2n uniform samples for n chi-square values
            vector::push_back(&mut raw, random::generate_u64_in_range(rng, 1, (range as u64)));
            i = i + 1;
        };
        chisquare_transform::uniform_to_chisquare(raw, (range as u128))
    }

    // ── Price cranking (random-index update) ─────────────────────────────────────

    /// Update the `RandomIndex` price using a new Box–Muller normal draw.
    /// price_new = sqrt(exp(scaled_Z)) / 200 * price_old
    public entry fun crank_random_index(
        ri:  &mut RandomIndex,
        msg: &mut MessageRessource,
        rng: &Random,
        ctx: &mut TxContext,
    ) {
        let mut generator = random::new_generator(rng, ctx);
        let z = box_muller::normal_r1(&mut generator);

        let one = 1u128 << 64;
        // scaled_z = z / 200  (small increment)
        let scaled = math_fixed64_with_sign::div_u128(z, 200);
        // price factor = sqrt(exp(scaled_z))
        let e_val   = math_fixed64_with_sign::exp(scaled);
        let e_fp    = fixed_point64::create_from_raw_value(fixed_point64_with_sign::get_raw_value(e_val));
        let factor  = math_fixed64::sqrt(e_fp);
        let factor_raw = fixed_point64::get_raw_value(factor);

        // new_price = prev * factor / 2^64 / 200
        let new_price = math_fixed64::mul_div_raw(ri.price, factor_raw, one) / 200;

        ri.price     = new_price;
        msg.my_Rmessage = msg.my_Rmessage + 1;
        event::emit(RandomIndexEvent { price: new_price });
    }

    /// Variant that emits a u64 IndexEvent as well.
    public entry fun crank_random_index2(
        ri:  &mut RandomIndex,
        msg: &mut MessageRessource,
        rng: &Random,
        ctx: &mut TxContext,
    ) {
        crank_random_index(ri, msg, rng, ctx);
        event::emit(IndexEvent { price: (ri.price >> 64) as u64 });
    }
}
