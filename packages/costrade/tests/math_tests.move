/// Tests for fixed_point64 and math_fixed64.
#[test_only]
module costrade::math_tests {

    use costrade::fixed_point64::{Self};
    use costrade::math_fixed64::{Self};

    // 1.0 in raw FP64
    const ONE: u128 = 1 << 64;

    // ── Tolerance helper ────────────────────────────────────────────────────────
    // Returns true if |a - b| / max(a,b)  <=  ppm / 1_000_000.
    fun within_ppm(a: u128, b: u128, ppm: u128): bool {
        if (a == b) return true;
        let diff = if (a > b) { a - b } else { b - a };
        let ref  = if (a > b) { a } else { b };
        diff * 1_000_000 <= ref * ppm
    }

    // ── FixedPoint64 constructors ───────────────────────────────────────────────

    #[test]
    fun test_create_from_raw() {
        let x = fixed_point64::create_from_raw_value(ONE);
        assert!(fixed_point64::get_raw_value(x) == ONE, 0);
    }

    #[test]
    fun test_create_from_rational_half() {
        let half = fixed_point64::create_from_rational(1, 2);
        assert!(fixed_point64::get_raw_value(half) == ONE / 2, 0);
    }

    #[test]
    fun test_create_from_rational_quarter() {
        let q = fixed_point64::create_from_rational(1, 4);
        assert!(fixed_point64::get_raw_value(q) == ONE / 4, 0);
    }

    #[test]
    fun test_create_from_rational_integer() {
        let five = fixed_point64::create_from_rational(5, 1);
        assert!(fixed_point64::get_raw_value(five) == 5 * ONE, 0);
    }

    // ── Arithmetic ──────────────────────────────────────────────────────────────

    #[test]
    fun test_add() {
        let half = fixed_point64::create_from_rational(1, 2);
        let one  = fixed_point64::add(half, half);
        assert!(fixed_point64::get_raw_value(one) == ONE, 0);
    }

    #[test]
    fun test_sub() {
        let one  = fixed_point64::create_from_raw_value(ONE);
        let half = fixed_point64::create_from_rational(1, 2);
        let r    = fixed_point64::sub(one, half);
        assert!(fixed_point64::get_raw_value(r) == ONE / 2, 0);
    }

    #[test]
    fun test_floor_integer() {
        let two_half = fixed_point64::create_from_rational(5, 2); // 2.5
        assert!(fixed_point64::floor(two_half) == 2, 0);
    }

    #[test]
    fun test_round_up() {
        let two_half = fixed_point64::create_from_rational(5, 2); // 2.5
        assert!(fixed_point64::round(two_half) == 3, 0);
    }

    #[test]
    fun test_multiply_u128() {
        // 10 * 0.5 = 5
        let half   = fixed_point64::create_from_rational(1, 2);
        let result = fixed_point64::multiply_u128(10, half);
        assert!(result == 5, 0);
    }

    // ── mul_div_raw ─────────────────────────────────────────────────────────────

    #[test]
    fun test_mul_div_identity() {
        // (3 * 4) / 4 == 3  in FP64 raw units
        let r = math_fixed64::mul_div_raw(3 * ONE, 4 * ONE, 4 * ONE);
        assert!(r == 3 * ONE, 0);
    }

    #[test]
    fun test_mul_div_half() {
        // (1 * 1) / 2 == 0.5
        let r = math_fixed64::mul_div_raw(ONE, ONE, 2 * ONE);
        assert!(r == ONE / 2, 0);
    }

    // ── pow ────────────────────────────────────────────────────────────────────

    #[test]
    fun test_pow_zero_exp() {
        let x      = fixed_point64::create_from_rational(7, 3);
        let result = math_fixed64::pow(x, 0);
        assert!(fixed_point64::get_raw_value(result) == ONE, 0);
    }

    #[test]
    fun test_pow_one_exp() {
        let x      = fixed_point64::create_from_rational(3, 2);
        let result = math_fixed64::pow(x, 1);
        assert!(fixed_point64::get_raw_value(result) == fixed_point64::get_raw_value(x), 0);
    }

    #[test]
    fun test_pow_two_squared() {
        // 2^2 = 4
        let two    = fixed_point64::create_from_raw_value(2 * ONE);
        let result = math_fixed64::pow(two, 2);
        assert!(fixed_point64::get_raw_value(result) == 4 * ONE, 0);
    }

    #[test]
    fun test_pow_half_squared() {
        // (0.5)^2 = 0.25
        let half   = fixed_point64::create_from_rational(1, 2);
        let result = math_fixed64::pow(half, 2);
        assert!(fixed_point64::get_raw_value(result) == ONE / 4, 0);
    }

    #[test]
    fun test_pow_three_cubed() {
        // 3^3 = 27
        let three  = fixed_point64::create_from_raw_value(3 * ONE);
        let result = math_fixed64::pow(three, 3);
        assert!(fixed_point64::get_raw_value(result) == 27 * ONE, 0);
    }

    // ── sqrt ───────────────────────────────────────────────────────────────────

    #[test]
    fun test_sqrt_zero() {
        let zero   = fixed_point64::create_from_raw_value(0);
        let result = math_fixed64::sqrt(zero);
        assert!(fixed_point64::get_raw_value(result) == 0, 0);
    }

    #[test]
    fun test_sqrt_one() {
        let one    = fixed_point64::create_from_raw_value(ONE);
        let result = math_fixed64::sqrt(one);
        assert!(fixed_point64::get_raw_value(result) == ONE, 0);
    }

    #[test]
    fun test_sqrt_four() {
        // sqrt(4.0) = 2.0
        let four   = fixed_point64::create_from_raw_value(4 * ONE);
        let result = math_fixed64::sqrt(four);
        assert!(fixed_point64::get_raw_value(result) == 2 * ONE, 0);
    }

    #[test]
    fun test_sqrt_quarter() {
        // sqrt(0.25) = 0.5
        let q      = fixed_point64::create_from_rational(1, 4);
        let result = math_fixed64::sqrt(q);
        // allow 1 ppm rounding
        assert!(within_ppm(fixed_point64::get_raw_value(result), ONE / 2, 1), 0);
    }

    #[test]
    fun test_sqrt_nine() {
        // sqrt(9.0) = 3.0
        let nine   = fixed_point64::create_from_raw_value(9 * ONE);
        let result = math_fixed64::sqrt(nine);
        assert!(fixed_point64::get_raw_value(result) == 3 * ONE, 0);
    }

    // ── exp ────────────────────────────────────────────────────────────────────

    #[test]
    fun test_exp_zero() {
        // exp(0) == 1 exactly
        let zero   = fixed_point64::create_from_raw_value(0);
        let result = math_fixed64::exp(zero);
        assert!(fixed_point64::get_raw_value(result) == ONE, 0);
    }

    #[test]
    fun test_exp_one() {
        // exp(1) ≈ 2.71828…  =>  raw ≈ 50143449209799256683
        // Allow 100 ppm (0.01%) error from Taylor truncation
        let one    = fixed_point64::create_from_raw_value(ONE);
        let result = math_fixed64::exp(one);
        let e_raw: u128 = 50143449209799256683;
        assert!(within_ppm(fixed_point64::get_raw_value(result), e_raw, 100), 0);
    }

    #[test]
    fun test_exp_two() {
        // exp(2) ≈ 7.38905…  => raw ≈ 136304026803...
        // 7.38905609893 * 2^64 ≈ 136304026803143040080
        let two    = fixed_point64::create_from_raw_value(2 * ONE);
        let result = math_fixed64::exp(two);
        let e2_raw: u128 = 136304026803143040080;
        assert!(within_ppm(fixed_point64::get_raw_value(result), e2_raw, 500), 0);
    }

    // ── ln ─────────────────────────────────────────────────────────────────────

    #[test]
    fun test_ln_one() {
        // ln(1) == 0
        let one = fixed_point64::create_from_raw_value(ONE);
        let (raw, _positive) = math_fixed64::ln_signed(one);
        // May have tiny rounding, allow 1 ppm of ONE
        assert!(raw <= ONE / 1_000_000, 0);
    }

    #[test]
    fun test_ln_e() {
        // ln(e) == 1.0;  e * 2^64 ≈ 50143449209799256683
        let e      = fixed_point64::create_from_raw_value(50143449209799256683);
        let (raw, positive) = math_fixed64::ln_signed(e);
        assert!(positive, 0);
        assert!(within_ppm(raw, ONE, 1000), 0);
    }

    #[test]
    fun test_ln_half_is_negative() {
        // ln(0.5) = -ln(2) < 0
        let half = fixed_point64::create_from_rational(1, 2);
        let (_raw, positive) = math_fixed64::ln_signed(half);
        assert!(!positive, 0);
    }

    #[test]
    fun test_ln_two() {
        // ln(2) ≈ LN2 raw = 12786308645202655660
        let two  = fixed_point64::create_from_raw_value(2 * ONE);
        let (raw, positive) = math_fixed64::ln_signed(two);
        assert!(positive, 0);
        assert!(within_ppm(raw, 12786308645202655660, 1000), 0);
    }

    #[test]
    fun test_ln_exp_roundtrip() {
        // exp(ln(3)) ≈ 3  (within 0.1%)
        let three    = fixed_point64::create_from_raw_value(3 * ONE);
        let (ln3, _) = math_fixed64::ln_signed(three);
        let e_ln3    = math_fixed64::exp(fixed_point64::create_from_raw_value(ln3));
        assert!(within_ppm(fixed_point64::get_raw_value(e_ln3), 3 * ONE, 2000), 0);
    }

    // ── log2 ───────────────────────────────────────────────────────────────────

    #[test]
    fun test_log2_one() {
        // log2(1) == 0
        let one = fixed_point64::create_from_raw_value(ONE);
        let (raw, _) = math_fixed64::log2_signed(one);
        assert!(raw <= ONE / 1_000_000, 0);
    }

    #[test]
    fun test_log2_two() {
        // log2(2) == 1.0 exactly
        let two = fixed_point64::create_from_raw_value(2 * ONE);
        let (raw, positive) = math_fixed64::log2_signed(two);
        assert!(positive, 0);
        assert!(within_ppm(raw, ONE, 1000), 0);
    }

    #[test]
    fun test_log2_four() {
        // log2(4) == 2.0
        let four = fixed_point64::create_from_raw_value(4 * ONE);
        let (raw, positive) = math_fixed64::log2_signed(four);
        assert!(positive, 0);
        assert!(within_ppm(raw, 2 * ONE, 1000), 0);
    }
}
