/// Trigonometric functions using Maclaurin / Taylor series.
/// Mirrors `grndx::cos_sin` from the Aptos codebase.
module costrade::cos_sin {

    use costrade::fixed_point64::{Self, FixedPoint64};
    use costrade::fixed_point64_with_sign::{Self, FixedPoint64WithSign};
    use costrade::math_fixed64;
    use costrade::math_fixed64_with_sign;
    use costrade::pi;

    const EEXCEED_2PI: u64 = 0;
    const EZERO_COSX:  u64 = 1;

    // ── Helpers ─────────────────────────────────────────────────────────────────

    /// n!  as u128 (only valid for n <= 34 within u128)
    public fun factorial(n: u64): u128 {
        let mut result: u128 = 1;
        let mut i: u64 = 2;
        while (i <= n) {
            result = result * (i as u128);
            i = i + 1;
        };
        result
    }

    /// Degrees to radians (returns FP64 raw).
    public fun deg_to_rad(deg: u128): u128 {
        let pi_raw = pi::get_pi_const();
        // rad = deg * pi / 180
        math_fixed64::mul_div_raw(deg, pi_raw, 180u128 << 64)
    }

    // ── Core series ─────────────────────────────────────────────────────────────

    /// Maclaurin series for cos(x):
    ///   cos(x) = 1 - x²/2! + x⁴/4! - x⁶/6! + …
    /// Input: x and result are FP64 raw values.
    /// Works best for x in [-π/2, π/2].
    public fun maclaurin_approx_cosx(x: FixedPoint64, rep: u64): FixedPoint64 {
        let xr  = fixed_point64::get_raw_value(x);
        let one = 1u128 << 64;
        let x2  = math_fixed64::mul_div_raw(xr, xr, one); // x²

        let mut result = one; // 1.0 (positive)
        let mut term   = x2;  // x²
        let mut i: u64 = 1;
        let mut sign   = false; // start subtracting

        while (i <= rep) {
            // term at step i is  x^(2i) / (2i)!
            let denom_fp64 = (factorial(2 * i) as u128) << 64;
            let cur = math_fixed64::mul_div_raw(term, one, denom_fp64);

            if (sign) {
                result = result + cur;
            } else {
                if (result >= cur) { result = result - cur; } else { result = 0; }
            };
            sign = !sign;

            // term_next = term * x² / ((2i+1)*(2i+2))
            term = math_fixed64::mul_div_raw(term, x2, one);
            i    = i + 1;
        };
        fixed_point64::create_from_raw_value(result)
    }

    // ── Quadrant-aware cos / sin / tan ──────────────────────────────────────────

    /// cos(x) for x in [0, 2π].  Returns a signed FixedPoint64.
    public fun cosx(x: u128, rep: u64): FixedPoint64WithSign {
        let pi_val  = pi::get_pi_const();        // π
        let pi2_val = pi_val * 2;                // 2π  (raw FP64)
        let pi_half = pi_val / 2;               // π/2
        let pi_3half = pi_val + pi_half;        // 3π/2

        assert!(x <= pi2_val, EEXCEED_2PI);

        if (x <= pi_half) {
            // Q1: cos positive, value decreases from 1 to 0
            let c = maclaurin_approx_cosx(fixed_point64::create_from_raw_value(x), rep);
            fixed_point64_with_sign::create_from_raw_value(fixed_point64::get_raw_value(c), true)
        } else if (x <= pi_val) {
            // Q2: cos negative
            let x2 = pi_val - x;
            let c  = maclaurin_approx_cosx(fixed_point64::create_from_raw_value(x2), rep);
            fixed_point64_with_sign::create_from_raw_value(fixed_point64::get_raw_value(c), false)
        } else if (x <= pi_3half) {
            // Q3: cos negative
            let x3 = x - pi_val;
            let c  = maclaurin_approx_cosx(fixed_point64::create_from_raw_value(x3), rep);
            fixed_point64_with_sign::create_from_raw_value(fixed_point64::get_raw_value(c), false)
        } else {
            // Q4: cos positive
            let x4 = pi2_val - x;
            let c  = maclaurin_approx_cosx(fixed_point64::create_from_raw_value(x4), rep);
            fixed_point64_with_sign::create_from_raw_value(fixed_point64::get_raw_value(c), true)
        }
    }

    /// sin(x) = cos(π/2 − x) (shifting the quadrant logic accordingly).
    public fun sinx(x: u128, rep: u64): FixedPoint64WithSign {
        let pi_val  = pi::get_pi_const();
        let pi_half = pi_val / 2;
        let pi2_val = pi_val * 2;

        assert!(x <= pi2_val, EEXCEED_2PI);

        if (x <= pi_half) {
            // sin(x) = cos(π/2 - x), positive in Q1
            let arg = pi_half - x;
            let c   = maclaurin_approx_cosx(fixed_point64::create_from_raw_value(arg), rep);
            fixed_point64_with_sign::create_from_raw_value(fixed_point64::get_raw_value(c), true)
        } else if (x <= pi_val) {
            // sin positive in Q2
            let arg = x - pi_half;
            let c   = maclaurin_approx_cosx(fixed_point64::create_from_raw_value(arg), rep);
            fixed_point64_with_sign::create_from_raw_value(fixed_point64::get_raw_value(c), true)
        } else if (x <= pi_val + pi_half) {
            // sin negative in Q3
            let arg = x - pi_val;
            let c   = maclaurin_approx_cosx(fixed_point64::create_from_raw_value(pi_half - arg), rep);
            fixed_point64_with_sign::create_from_raw_value(fixed_point64::get_raw_value(c), false)
        } else {
            // sin negative in Q4
            let arg = pi2_val - x;
            let c   = maclaurin_approx_cosx(fixed_point64::create_from_raw_value(arg), rep);
            fixed_point64_with_sign::create_from_raw_value(fixed_point64::get_raw_value(c), false)
        }
    }

    /// tan(x) = sin(x) / cos(x).  Aborts if cos(x) == 0.
    public fun tanx(x: u128, rep: u64): FixedPoint64WithSign {
        let sin_val = sinx(x, rep);
        let cos_val = cosx(x, rep);
        assert!(fixed_point64_with_sign::get_raw_value(cos_val) != 0, EZERO_COSX);
        math_fixed64_with_sign::div(sin_val, cos_val)
    }

    // ── Degree-based variants ───────────────────────────────────────────────────

    public fun cosx_by_degree(deg: u128, rep: u64): FixedPoint64WithSign {
        cosx(deg_to_rad(deg), rep)
    }

    public fun sinx_by_degree(deg: u128, rep: u64): FixedPoint64WithSign {
        sinx(deg_to_rad(deg), rep)
    }

    public fun tanx_by_degree(deg: u128, rep: u64): FixedPoint64WithSign {
        tanx(deg_to_rad(deg), rep)
    }
}
