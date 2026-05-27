/// Box–Muller transform: converts uniform random numbers to a standard-normal
/// distribution.  Mirrors `grndx::box_muller`.
///
/// Randomness API change from Aptos → Sui:
///   `normal_r1(r: &mut RandomGenerator)` instead of using `aptos_framework::randomness`.
module costrade::box_muller {

    use std::vector;
    use sui::random::RandomGenerator;
    use costrade::fixed_point64::{Self, FixedPoint64};
    use costrade::fixed_point64_with_sign::{Self, FixedPoint64WithSign};
    use costrade::math_fixed64;
    use costrade::math_fixed64_with_sign;
    use costrade::cos_sin;
    use costrade::pi;

    // ── Core transform ──────────────────────────────────────────────────────────

    /// Given (u1, u2) sampled uniformly in [1, range), produce the two
    /// normally-distributed variates z0 and z1 via the Box–Muller formula:
    ///
    ///   z0 = sqrt(-2 ln(u1)) * cos(2π u2)
    ///   z1 = sqrt(-2 ln(u1)) * sin(2π u2)
    ///
    /// u1, u2 must be in (0, range).
    public fun normalize_u1_u2(u1: u128, u2: u128, range: u128): (FixedPoint64WithSign, FixedPoint64WithSign) {
        let (mag, theta_raw) = mag_and_theta(u1, u2, range);
        let z0 = math_fixed64_with_sign::mul(mag, cos_sin::cosx(theta_raw, 10));
        let z1 = math_fixed64_with_sign::mul(mag, cos_sin::sinx(theta_raw, 10));
        (z0, z1)
    }

    /// Same as `normalize_u1_u2` but returns only z0.
    public fun normalize_u1_u2_r1(u1: u128, u2: u128, range: u128): FixedPoint64WithSign {
        let (mag, theta_raw) = mag_and_theta(u1, u2, range);
        math_fixed64_with_sign::mul(mag, cos_sin::cosx(theta_raw, 10))
    }

    /// Batch-convert a vector of u64 random numbers to normally-distributed
    /// signed FP64 values.  The vector is split in half: first half = U1, second = U2.
    public fun uniform_to_normal(random_numbers: vector<u64>, range: u128): vector<FixedPoint64WithSign> {
        let (u1s, u2s) = get_two_parts(random_numbers);
        let n = vector::length(&u1s);
        let mut result: vector<FixedPoint64WithSign> = vector::empty();
        let mut i = 0;
        while (i < n) {
            let u1 = (*vector::borrow(&u1s, i) as u128);
            let u2 = (*vector::borrow(&u2s, i) as u128);
            let z0 = normalize_u1_u2_r1(u1, u2, range);
            vector::push_back(&mut result, z0);
            i = i + 1;
        };
        result
    }

    /// Generate a single standard-normal variate using live randomness.
    /// In Sui, random sampling is done via `RandomGenerator`.
    public(package) fun normal_r1(rng: &mut RandomGenerator): FixedPoint64WithSign {
        use sui::random;
        let range: u128 = 10_000_000_000_000_000;
        // u1 must be strictly > 0 (avoid ln(0)); sample in [1, range)
        let u1 = (random::generate_u128_in_range(rng, 1, range) as u128);
        let u2 = (random::generate_u128_in_range(rng, 1, range) as u128);
        normalize_u1_u2_r1(u1, u2, range)
    }

    /// Split a flat vector into first-half (U1) and second-half (U2) sub-vectors.
    public fun get_two_parts(numbers: vector<u64>): (vector<u128>, vector<u128>) {
        let len  = vector::length(&numbers);
        let half = len / 2;
        let mut u1s: vector<u128> = vector::empty();
        let mut u2s: vector<u128> = vector::empty();
        let mut i = 0;
        while (i < half) {
            vector::push_back(&mut u1s, (*vector::borrow(&numbers, i) as u128));
            i = i + 1;
        };
        while (i < len) {
            vector::push_back(&mut u2s, (*vector::borrow(&numbers, i) as u128));
            i = i + 1;
        };
        (u1s, u2s)
    }

    // ── Private ─────────────────────────────────────────────────────────────────

    /// Compute the magnitude `sqrt(-2 ln(u1/range))` and theta `2π * u2/range`
    /// for the Box–Muller formula.
    fun mag_and_theta(u1: u128, u2: u128, range: u128): (FixedPoint64WithSign, u128) {
        let one = 1u128 << 64;
        // Normalise u1 to FP64 in (0,1):  u1_fp64 = u1 * 2^64 / range
        let u1_fp64 = math_fixed64::mul_div_raw(u1, one, range);
        // -2 * ln(u1_fp64):  ln will be negative since u1_fp64 < 1, so -2*ln > 0.
        let (ln_raw, ln_pos) = math_fixed64::ln_signed(
            fixed_point64::create_from_raw_value(u1_fp64),
        );
        // We want -2 * ln(u1).  Since u1 in (0,1), ln(u1) < 0, so -2*ln(u1) > 0.
        let neg_2ln_raw = 2 * ln_raw;
        let neg_2ln_fp  = fixed_point64_with_sign::create_from_raw_value(neg_2ln_raw, !ln_pos);
        let mag = math_fixed64_with_sign::sqrt(neg_2ln_fp);

        // theta = 2π * u2/range  (result is FP64 raw in [0, 2π))
        // pi2_raw = 2π in FP64 = 2 * pi_const; result = pi2_raw * u2 / range
        let pi2_raw = pi::get_pi_const() * 2;
        let theta_raw = math_fixed64::mul_div_raw(pi2_raw, u2, range);
        (mag, theta_raw)
    }
}
