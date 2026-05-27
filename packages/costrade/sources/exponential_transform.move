/// Exponential distribution — inverse-CDF transform.
/// x = -(1/λ) * ln(1 − F(x))  ≡  -(1/λ) * ln(1 − p)
/// Mirrors `grndx::exponential_transform`.
module costrade::exponential_transform {

    use costrade::fixed_point64::{Self, FixedPoint64};
    use costrade::math_fixed64;
    use costrade::math_fixed64_with_sign;
    use costrade::fixed_point64_with_sign;

    const EGREATER_THAN_RANGE: u64 = 0;

    /// Convert a uniform random integer `random_number` in [0, range) to an
    /// exponential variate with rate `lambda` (FixedPoint64, > 0).
    ///
    /// Returns a positive FixedPoint64.
    public fun uniform_to_exponential(
        random_number: u128,
        range:         u128,
        lambda:        FixedPoint64,
    ): FixedPoint64 {
        assert!(random_number < range, EGREATER_THAN_RANGE);

        let one = 1u128 << 64;

        // p = random_number / range  (FP64, in [0,1))
        let p_raw = math_fixed64::mul_div_raw(random_number, one, range << 64);

        // 1 - p  (always positive since p < 1)
        let one_minus_p = if (one > p_raw) { one - p_raw } else { 1 };

        // ln(1 - p) — result is <= 0
        let (ln_raw, _ln_pos) = math_fixed64::ln_signed(
            fixed_point64::create_from_raw_value(one_minus_p),
        );

        // -(1/lambda) * ln(1-p)
        // Since ln(1-p) <= 0, -ln(1-p) >= 0 → result is positive.
        // Divide by lambda: result = ln_raw / lambda_raw  in FP64 terms:
        //   (ln_raw / 2^64) / (lambda_raw / 2^64) = ln_raw / lambda_raw * 2^64
        let lambda_raw = fixed_point64::get_raw_value(lambda);
        let result_raw = math_fixed64::mul_div_raw(ln_raw, one, lambda_raw);

        fixed_point64::create_from_raw_value(result_raw)
    }
}
