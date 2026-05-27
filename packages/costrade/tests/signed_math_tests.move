/// Tests for signed FP64 arithmetic and math operations.
#[test_only]
module costrade::signed_math_tests {

    use costrade::fixed_point64_with_sign::{Self};
    use costrade::math_fixed64_with_sign::{Self};

    const ONE: u128 = 1 << 64;

    fun within_ppm(a: u128, b: u128, ppm: u128): bool {
        if (a == b) return true;
        let diff = if (a > b) { a - b } else { b - a };
        let ref  = if (a > b) { a } else { b };
        diff * 1_000_000 <= ref * ppm
    }

    // ── FixedPoint64WithSign construction ───────────────────────────────────────

    #[test]
    fun test_create_positive() {
        let x = fixed_point64_with_sign::create_from_raw_value(ONE, true);
        assert!(fixed_point64_with_sign::get_raw_value(x) == ONE, 0);
        assert!(fixed_point64_with_sign::is_positive(x), 0);
    }

    #[test]
    fun test_create_negative() {
        let x = fixed_point64_with_sign::create_from_raw_value(ONE, false);
        assert!(fixed_point64_with_sign::get_raw_value(x) == ONE, 0);
        assert!(!fixed_point64_with_sign::is_positive(x), 0);
    }

    #[test]
    fun test_create_from_rational() {
        let half = fixed_point64_with_sign::create_from_rational(1, 2, true);
        assert!(fixed_point64_with_sign::get_raw_value(half) == ONE / 2, 0);
    }

    // ── add ────────────────────────────────────────────────────────────────────

    #[test]
    fun test_add_both_positive() {
        let a = fixed_point64_with_sign::create_from_raw_value(3 * ONE, true);
        let b = fixed_point64_with_sign::create_from_raw_value(2 * ONE, true);
        let c = fixed_point64_with_sign::add(a, b);
        assert!(fixed_point64_with_sign::get_raw_value(c) == 5 * ONE, 0);
        assert!(fixed_point64_with_sign::is_positive(c), 0);
    }

    #[test]
    fun test_add_both_negative() {
        let a = fixed_point64_with_sign::create_from_raw_value(3 * ONE, false);
        let b = fixed_point64_with_sign::create_from_raw_value(2 * ONE, false);
        let c = fixed_point64_with_sign::add(a, b);
        assert!(fixed_point64_with_sign::get_raw_value(c) == 5 * ONE, 0);
        assert!(!fixed_point64_with_sign::is_positive(c), 0);
    }

    #[test]
    fun test_add_pos_neg_pos_result() {
        // 5 + (-3) = 2  (positive result)
        let a = fixed_point64_with_sign::create_from_raw_value(5 * ONE, true);
        let b = fixed_point64_with_sign::create_from_raw_value(3 * ONE, false);
        let c = fixed_point64_with_sign::add(a, b);
        assert!(fixed_point64_with_sign::get_raw_value(c) == 2 * ONE, 0);
        assert!(fixed_point64_with_sign::is_positive(c), 0);
    }

    #[test]
    fun test_add_pos_neg_neg_result() {
        // 2 + (-5) = -3  (negative result)
        let a = fixed_point64_with_sign::create_from_raw_value(2 * ONE, true);
        let b = fixed_point64_with_sign::create_from_raw_value(5 * ONE, false);
        let c = fixed_point64_with_sign::add(a, b);
        assert!(fixed_point64_with_sign::get_raw_value(c) == 3 * ONE, 0);
        assert!(!fixed_point64_with_sign::is_positive(c), 0);
    }

    // ── sub ────────────────────────────────────────────────────────────────────

    #[test]
    fun test_sub_positive() {
        let a = fixed_point64_with_sign::create_from_raw_value(7 * ONE, true);
        let b = fixed_point64_with_sign::create_from_raw_value(3 * ONE, true);
        let c = fixed_point64_with_sign::sub(a, b);
        assert!(fixed_point64_with_sign::get_raw_value(c) == 4 * ONE, 0);
        assert!(fixed_point64_with_sign::is_positive(c), 0);
    }

    #[test]
    fun test_sub_to_negative() {
        // 3 - 7 = -4
        let a = fixed_point64_with_sign::create_from_raw_value(3 * ONE, true);
        let b = fixed_point64_with_sign::create_from_raw_value(7 * ONE, true);
        let c = fixed_point64_with_sign::sub(a, b);
        assert!(fixed_point64_with_sign::get_raw_value(c) == 4 * ONE, 0);
        assert!(!fixed_point64_with_sign::is_positive(c), 0);
    }

    // ── revert_sign / abs ──────────────────────────────────────────────────────

    #[test]
    fun test_revert_sign() {
        let pos = fixed_point64_with_sign::create_from_raw_value(ONE, true);
        let neg = fixed_point64_with_sign::revert_sign(pos);
        assert!(!fixed_point64_with_sign::is_positive(neg), 0);
        assert!(fixed_point64_with_sign::get_raw_value(neg) == ONE, 0);
    }

    #[test]
    fun test_abs() {
        let neg = fixed_point64_with_sign::create_from_raw_value(5 * ONE, false);
        let pos = fixed_point64_with_sign::abs(neg);
        assert!(fixed_point64_with_sign::is_positive(pos), 0);
        assert!(fixed_point64_with_sign::get_raw_value(pos) == 5 * ONE, 0);
    }

    // ── comparison ─────────────────────────────────────────────────────────────

    #[test]
    fun test_less() {
        let small = fixed_point64_with_sign::create_from_raw_value(ONE, false);     // -1
        let big   = fixed_point64_with_sign::create_from_raw_value(ONE, true);      // +1
        assert!(fixed_point64_with_sign::less(small, big), 0);
        assert!(!fixed_point64_with_sign::less(big, small), 0);
    }

    #[test]
    fun test_greater_or_equal() {
        let a = fixed_point64_with_sign::create_from_raw_value(3 * ONE, true);
        let b = fixed_point64_with_sign::create_from_raw_value(3 * ONE, true);
        assert!(fixed_point64_with_sign::greater_or_equal(a, b), 0);
    }

    // ── mul / div ──────────────────────────────────────────────────────────────

    #[test]
    fun test_mul_pos_pos() {
        // 2 * 3 = 6, positive
        let a = fixed_point64_with_sign::create_from_raw_value(2 * ONE, true);
        let b = fixed_point64_with_sign::create_from_raw_value(3 * ONE, true);
        let c = math_fixed64_with_sign::mul(a, b);
        assert!(fixed_point64_with_sign::get_raw_value(c) == 6 * ONE, 0);
        assert!(fixed_point64_with_sign::is_positive(c), 0);
    }

    #[test]
    fun test_mul_pos_neg() {
        // 2 * (-3) = -6, negative
        let a = fixed_point64_with_sign::create_from_raw_value(2 * ONE, true);
        let b = fixed_point64_with_sign::create_from_raw_value(3 * ONE, false);
        let c = math_fixed64_with_sign::mul(a, b);
        assert!(fixed_point64_with_sign::get_raw_value(c) == 6 * ONE, 0);
        assert!(!fixed_point64_with_sign::is_positive(c), 0);
    }

    #[test]
    fun test_mul_neg_neg() {
        // (-2) * (-3) = 6, positive
        let a = fixed_point64_with_sign::create_from_raw_value(2 * ONE, false);
        let b = fixed_point64_with_sign::create_from_raw_value(3 * ONE, false);
        let c = math_fixed64_with_sign::mul(a, b);
        assert!(fixed_point64_with_sign::get_raw_value(c) == 6 * ONE, 0);
        assert!(fixed_point64_with_sign::is_positive(c), 0);
    }

    #[test]
    fun test_div() {
        // 6 / 2 = 3
        let a = fixed_point64_with_sign::create_from_raw_value(6 * ONE, true);
        let b = fixed_point64_with_sign::create_from_raw_value(2 * ONE, true);
        let c = math_fixed64_with_sign::div(a, b);
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(c), 3 * ONE, 1), 0);
        assert!(fixed_point64_with_sign::is_positive(c), 0);
    }

    #[test]
    fun test_div_neg() {
        // -6 / 2 = -3
        let a = fixed_point64_with_sign::create_from_raw_value(6 * ONE, false);
        let b = fixed_point64_with_sign::create_from_raw_value(2 * ONE, true);
        let c = math_fixed64_with_sign::div(a, b);
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(c), 3 * ONE, 1), 0);
        assert!(!fixed_point64_with_sign::is_positive(c), 0);
    }

    // ── pow ────────────────────────────────────────────────────────────────────

    #[test]
    fun test_pow_signed_even() {
        // (-2)^2 = 4, positive
        let neg2 = fixed_point64_with_sign::create_from_raw_value(2 * ONE, false);
        let r    = math_fixed64_with_sign::pow(neg2, 2);
        assert!(fixed_point64_with_sign::get_raw_value(r) == 4 * ONE, 0);
        assert!(fixed_point64_with_sign::is_positive(r), 0);
    }

    #[test]
    fun test_pow_signed_odd() {
        // (-2)^3 = -8, negative
        let neg2 = fixed_point64_with_sign::create_from_raw_value(2 * ONE, false);
        let r    = math_fixed64_with_sign::pow(neg2, 3);
        assert!(fixed_point64_with_sign::get_raw_value(r) == 8 * ONE, 0);
        assert!(!fixed_point64_with_sign::is_positive(r), 0);
    }

    // ── sqrt ───────────────────────────────────────────────────────────────────

    #[test]
    fun test_sqrt_signed() {
        let four = fixed_point64_with_sign::create_from_raw_value(4 * ONE, true);
        let r    = math_fixed64_with_sign::sqrt(four);
        assert!(fixed_point64_with_sign::get_raw_value(r) == 2 * ONE, 0);
        assert!(fixed_point64_with_sign::is_positive(r), 0);
    }

    // ── exp ────────────────────────────────────────────────────────────────────

    #[test]
    fun test_exp_pos_zero() {
        let zero = fixed_point64_with_sign::create_from_raw_value(0, true);
        let r    = math_fixed64_with_sign::exp(zero);
        assert!(fixed_point64_with_sign::get_raw_value(r) == ONE, 0);
        assert!(fixed_point64_with_sign::is_positive(r), 0);
    }

    #[test]
    fun test_exp_neg_zero() {
        // exp(-0) = 1
        let neg0 = fixed_point64_with_sign::create_from_raw_value(0, false);
        let r    = math_fixed64_with_sign::exp(neg0);
        // 1 / exp(0) = 1 / 1 = 1; value may be slightly off due to division
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(r), ONE, 10), 0);
    }

    #[test]
    fun test_exp_positive() {
        // exp(1) ≈ e
        let one = fixed_point64_with_sign::create_from_raw_value(ONE, true);
        let r   = math_fixed64_with_sign::exp(one);
        let e_raw: u128 = 50143449209799256683;
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(r), e_raw, 100), 0);
        assert!(fixed_point64_with_sign::is_positive(r), 0);
    }

    #[test]
    fun test_exp_negative() {
        // exp(-1) ≈ 0.36787944…  => raw ≈ 6788684284...
        // 1/e * 2^64 ≈ 6788684284600502704
        let neg1 = fixed_point64_with_sign::create_from_raw_value(ONE, false);
        let r    = math_fixed64_with_sign::exp(neg1);
        let inv_e: u128 = 6788684284600502704;
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(r), inv_e, 500), 0);
        assert!(fixed_point64_with_sign::is_positive(r), 0);
    }

    // ── ln ─────────────────────────────────────────────────────────────────────

    #[test]
    fun test_ln_one() {
        let one = fixed_point64_with_sign::create_from_raw_value(ONE, true);
        let r   = math_fixed64_with_sign::ln(one);
        assert!(fixed_point64_with_sign::get_raw_value(r) <= ONE / 1_000_000, 0);
    }

    #[test]
    fun test_ln_e() {
        let e   = fixed_point64_with_sign::create_from_raw_value(50143449209799256683, true);
        let r   = math_fixed64_with_sign::ln(e);
        assert!(fixed_point64_with_sign::is_positive(r), 0);
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(r), ONE, 1000), 0);
    }

    // ── aggregates ─────────────────────────────────────────────────────────────

    #[test]
    fun test_sum() {
        let v = vector[
            fixed_point64_with_sign::create_from_raw_value(ONE, true),
            fixed_point64_with_sign::create_from_raw_value(2 * ONE, true),
            fixed_point64_with_sign::create_from_raw_value(3 * ONE, true),
        ];
        let s = math_fixed64_with_sign::sum(v);
        assert!(fixed_point64_with_sign::get_raw_value(s) == 6 * ONE, 0);
        assert!(fixed_point64_with_sign::is_positive(s), 0);
    }

    #[test]
    fun test_mean() {
        let v = vector[
            fixed_point64_with_sign::create_from_raw_value(ONE, true),
            fixed_point64_with_sign::create_from_raw_value(3 * ONE, true),
        ];
        let m = math_fixed64_with_sign::mean(v);
        // mean([1,3]) = 2
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(m), 2 * ONE, 10), 0);
        assert!(fixed_point64_with_sign::is_positive(m), 0);
    }

    #[test]
    fun test_maximum() {
        let v = vector[
            fixed_point64_with_sign::create_from_raw_value(ONE, true),
            fixed_point64_with_sign::create_from_raw_value(5 * ONE, true),
            fixed_point64_with_sign::create_from_raw_value(2 * ONE, true),
        ];
        let max_val = math_fixed64_with_sign::maximum(v);
        assert!(fixed_point64_with_sign::get_raw_value(max_val) == 5 * ONE, 0);
    }

    #[test]
    fun test_minimum() {
        let v = vector[
            fixed_point64_with_sign::create_from_raw_value(4 * ONE, true),
            fixed_point64_with_sign::create_from_raw_value(ONE, true),
            fixed_point64_with_sign::create_from_raw_value(2 * ONE, true),
        ];
        let min_val = math_fixed64_with_sign::minimum(v);
        assert!(fixed_point64_with_sign::get_raw_value(min_val) == ONE, 0);
    }
}
