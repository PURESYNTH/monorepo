/// Chi-square distribution (df=1) via the Box–Muller transform.
/// A chi-square(1) variate is simply the square of a standard-normal variate.
/// Mirrors `grndx::chisquare_transform`.
module costrade::chisquare_transform {

    use std::vector;
    use costrade::fixed_point64::{Self, FixedPoint64};
    use costrade::fixed_point64_with_sign;
    use costrade::math_fixed64;
    use costrade::math_fixed64_with_sign;
    use costrade::box_muller;

    /// Convert a vector of uniform u64 random numbers to chi-square variates.
    ///
    /// Steps:
    ///   1. box_muller::uniform_to_normal → vector of N(0,1) values
    ///   2. Find the maximum absolute value
    ///   3. Normalise each value to [0, 1] by dividing by the max
    ///   4. Square each value  → chi-square(1) in [0, 1]
    public fun uniform_to_chisquare(
        uniform_numbers: vector<u64>,
        range:           u128,
    ): vector<FixedPoint64> {
        let normals = box_muller::uniform_to_normal(uniform_numbers, range);
        let n = vector::length(&normals);
        if (n == 0) return vector::empty();

        // Find maximum absolute value
        let mut max_val = fixed_point64_with_sign::get_raw_value(*vector::borrow(&normals, 0));
        let mut i = 1;
        while (i < n) {
            let v = fixed_point64_with_sign::get_raw_value(*vector::borrow(&normals, i));
            if (v > max_val) max_val = v;
            i = i + 1;
        };
        if (max_val == 0) return vector::empty();

        let one = 1u128 << 64;

        // Normalise and square
        let mut result: vector<FixedPoint64> = vector::empty();
        let mut j = 0;
        while (j < n) {
            let abs_raw  = fixed_point64_with_sign::get_raw_value(*vector::borrow(&normals, j));
            // normalised = abs_raw / max_val  (FP64)
            let norm_raw = math_fixed64::mul_div_raw(abs_raw, one, max_val);
            // squared = norm^2  (FP64)
            let sq_raw   = math_fixed64::mul_div_raw(norm_raw, norm_raw, one);
            vector::push_back(&mut result, fixed_point64::create_from_raw_value(sq_raw));
            j = j + 1;
        };
        result
    }
}
