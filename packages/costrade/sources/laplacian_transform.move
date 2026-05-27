/// Laplacian distribution — inverse-CDF transform.
/// F^{-1}(p) = μ - β * sgn(p - 0.5) * ln(1 - 2|p - 0.5|)
/// Mirrors `grndx::laplacian_transform`.
module costrade::laplacian_transform {

    use costrade::fixed_point64::{Self, FixedPoint64};
    use costrade::fixed_point64_with_sign::{Self, FixedPoint64WithSign};
    use costrade::math_fixed64;
    use costrade::math_fixed64_with_sign;

    const EGREATER_THAN_RANGE: u64 = 0;

    /// Convert a uniform random integer `random_number` in [0, range) to a
    /// Laplace variate with location `mu` and scale `beta`.
    ///
    /// Steps:
    ///   1. p = random_number / range  (normalise to [0,1))
    ///   2. p_sub = p - 0.5
    ///   3. ln_param = 1 - 2 |p_sub|
    ///   4. result = mu - beta * sgn(p_sub) * ln(ln_param)
    public fun uniform_to_laplacian(
        random_number: u128,
        range:         u128,
        mu:            FixedPoint64WithSign,
        beta:          FixedPoint64,
    ): FixedPoint64WithSign {
        assert!(random_number < range, EGREATER_THAN_RANGE);

        let one = 1u128 << 64;
        let half = one / 2; // 0.5 in FP64

        // p = random_number / range  (FP64)
        let p_raw = math_fixed64::mul_div_raw(random_number, one, range << 64);

        // p_sub = p - 0.5
        let p_sub_raw: u128;
        let p_sub_positive: bool;
        if (p_raw >= half) {
            p_sub_raw      = p_raw - half;
            p_sub_positive = true;
        } else {
            p_sub_raw      = half - p_raw;
            p_sub_positive = false;
        };

        // ln_param = 1 - 2*|p_sub|   (always in (0,1) when p != 0.5)
        let two_abs_p_sub = 2 * p_sub_raw;
        let ln_param_raw  = if (one > two_abs_p_sub) { one - two_abs_p_sub } else { 1 };

        // ln(ln_param)  — ln_param < 1, so result is negative
        let (ln_raw, ln_pos) = math_fixed64::ln_signed(
            fixed_point64::create_from_raw_value(ln_param_raw),
        );

        // sgn(p_sub) * ln(ln_param)
        // sgn(p_sub) == p_sub_positive
        // ln(ln_param) is negative (ln_pos = false), so:
        //   sgn(p_sub) == true  → product = ln(ln_param) (negative)
        //   sgn(p_sub) == false → product = -ln(ln_param) (positive)
        let prod_pos = if (p_sub_positive) { ln_pos } else { !ln_pos };
        let prod_signed = fixed_point64_with_sign::create_from_raw_value(ln_raw, prod_pos);

        // beta * sgn_prod
        let beta_signed  = fixed_point64_with_sign::create_from_raw_value(
            fixed_point64::get_raw_value(beta),
            true,
        );
        let beta_x_prod = math_fixed64_with_sign::mul(beta_signed, prod_signed);

        // result = mu - beta * sgn(p_sub) * ln(ln_param)
        fixed_point64_with_sign::sub(mu, beta_x_prod)
    }
}
