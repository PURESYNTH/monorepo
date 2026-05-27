/// Tests for pi constant and trigonometric functions.
#[test_only]
module costrade::trig_tests {

    use costrade::pi::{Self};
    use costrade::cos_sin::{Self};
    use costrade::fixed_point64_with_sign::{Self};

    const ONE: u128 = 1 << 64;

    fun within_ppm(a: u128, b: u128, ppm: u128): bool {
        if (a == b) return true;
        let diff = if (a > b) { a - b } else { b - a };
        let ref  = if (a > b) { a } else { b };
        diff * 1_000_000 <= ref * ppm
    }

    // ── Pi ─────────────────────────────────────────────────────────────────────

    #[test]
    fun test_pi_const() {
        // π * 2^64  ≈ 57952155664616944161
        let p = pi::get_pi_const();
        // Within 10 ppm of known value
        assert!(within_ppm(p, 57952155664616944161, 10), 0);
    }

    #[test]
    fun test_deg_to_rad_zero() {
        // 0° -> 0 rad
        let r = cos_sin::deg_to_rad(0);
        assert!(r == 0, 0);
    }

    #[test]
    fun test_deg_to_rad_180() {
        // 180° -> π
        let r = cos_sin::deg_to_rad(180 * ONE);
        assert!(within_ppm(r, pi::get_pi_const(), 100), 0);
    }

    // ── cos ────────────────────────────────────────────────────────────────────

    #[test]
    fun test_cos_zero() {
        // cos(0) = 1.0
        let c = cos_sin::cosx(0, 10);
        assert!(fixed_point64_with_sign::get_raw_value(c) == ONE, 0);
        assert!(fixed_point64_with_sign::is_positive(c), 0);
    }

    #[test]
    fun test_cos_pi_is_neg_one() {
        // cos(π) = -1.0  (within 1000 ppm due to Taylor truncation)
        let pi_val = pi::get_pi_const();
        let c = cos_sin::cosx(pi_val, 10);
        assert!(!fixed_point64_with_sign::is_positive(c), 0);
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(c), ONE, 1000), 0);
    }

    #[test]
    fun test_cos_2pi_is_one() {
        // cos(2π) = 1.0
        let two_pi = pi::get_pi_const() * 2;
        let c = cos_sin::cosx(two_pi, 10);
        assert!(fixed_point64_with_sign::is_positive(c), 0);
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(c), ONE, 1000), 0);
    }

    #[test]
    fun test_cos_pi_third_is_half() {
        // cos(π/3) = 0.5  (the Taylor series converges well here since π/3 < π/2)
        let pi_third = pi::get_pi_const() / 3;
        let c = cos_sin::cosx(pi_third, 10);
        assert!(fixed_point64_with_sign::is_positive(c), 0);
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(c), ONE / 2, 5000), 0);
    }

    // ── sin ────────────────────────────────────────────────────────────────────

    #[test]
    fun test_sin_pi_sixth_is_half() {
        // sin(π/6) = 0.5  (series arg = cos(π/3) which converges well)
        let pi_sixth = pi::get_pi_const() / 6;
        let s = cos_sin::sinx(pi_sixth, 10);
        assert!(fixed_point64_with_sign::is_positive(s), 0);
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(s), ONE / 2, 5000), 0);
    }

    #[test]
    fun test_sin_pi_half_is_one() {
        // sin(π/2) = 1.0
        let pi_half = pi::get_pi_const() / 2;
        let s = cos_sin::sinx(pi_half, 10);
        assert!(fixed_point64_with_sign::is_positive(s), 0);
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(s), ONE, 1000), 0);
    }


    #[test]
    fun test_sin_pi_positive_quadrant() {
        // sin(π/4) > 0
        let pi_quarter = pi::get_pi_const() / 4;
        let s = cos_sin::sinx(pi_quarter, 10);
        assert!(fixed_point64_with_sign::is_positive(s), 0);
    }

    #[test]
    fun test_sin_3pi_half_is_neg_one() {
        // sin(3π/2) = -1.0
        let three_pi_half = pi::get_pi_const() * 3 / 2;
        let s = cos_sin::sinx(three_pi_half, 10);
        assert!(!fixed_point64_with_sign::is_positive(s), 0);
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(s), ONE, 1000), 0);
    }

    // ── degree helpers ─────────────────────────────────────────────────────────

    #[test]
    fun test_cos_60_deg_is_half() {
        // cos(60°) = 0.5
        let c = cos_sin::cosx_by_degree(60 * ONE, 10);
        assert!(fixed_point64_with_sign::is_positive(c), 0);
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(c), ONE / 2, 5000), 0);
    }

    #[test]
    fun test_sin_90_deg_is_one() {
        // sin(90°) = 1
        let s = cos_sin::sinx_by_degree(90 * ONE, 10);
        assert!(fixed_point64_with_sign::is_positive(s), 0);
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(s), ONE, 1000), 0);
    }

    #[test]
    fun test_sin_30_deg_is_half() {
        // sin(30°) = 0.5
        let s = cos_sin::sinx_by_degree(30 * ONE, 10);
        assert!(fixed_point64_with_sign::is_positive(s), 0);
        assert!(within_ppm(fixed_point64_with_sign::get_raw_value(s), ONE / 2, 2000), 0);
    }

    // ── factorial ──────────────────────────────────────────────────────────────

    #[test]
    fun test_factorial_zero() {
        assert!(cos_sin::factorial(0) == 1, 0);
    }

    #[test]
    fun test_factorial_five() {
        assert!(cos_sin::factorial(5) == 120, 0);
    }

    #[test]
    fun test_factorial_ten() {
        assert!(cos_sin::factorial(10) == 3628800, 0);
    }
}
