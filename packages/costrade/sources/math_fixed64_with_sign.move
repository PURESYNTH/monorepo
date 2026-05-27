/// Math operations on `FixedPoint64WithSign` (signed Q64.64).
/// Mirrors `grndx::math_fixed64_with_sign` from the Aptos codebase.
module costrade::math_fixed64_with_sign {

    use std::vector;
    use costrade::fixed_point64::{Self, FixedPoint64};
    use costrade::fixed_point64_with_sign::{Self, FixedPoint64WithSign};
    use costrade::math_fixed64;

    const E_ZERO_DENOMINATOR: u64 = 0;
    const E_NEGATIVE:         u64 = 1;
    const E_ZERO_LENGTH:      u64 = 2;

    /// ln(2) * 2^64
    const LN2: u128 = 12786308645202655660;

    // ── Basic arithmetic ────────────────────────────────────────────────────────

    /// x / scalar (u128 denominator)
    public fun div_u128(x: FixedPoint64WithSign, denominator: u128): FixedPoint64WithSign {
        assert!(denominator != 0, E_ZERO_DENOMINATOR);
        let one = 1u128 << 64;
        let raw = math_fixed64::mul_div_raw(
            fixed_point64_with_sign::get_raw_value(x),
            one,
            denominator << 64,
        );
        fixed_point64_with_sign::create_from_raw_value(raw, fixed_point64_with_sign::is_positive(x))
    }

    /// x * y  (sign = sign(x) XOR NOT sign(y))
    public fun mul(x: FixedPoint64WithSign, y: FixedPoint64WithSign): FixedPoint64WithSign {
        let xp = fixed_point64_with_sign::is_positive(x);
        let yp = fixed_point64_with_sign::is_positive(y);
        let raw = math_fixed64::mul_div_raw(
            fixed_point64_with_sign::get_raw_value(x),
            fixed_point64_with_sign::get_raw_value(y),
            1u128 << 64,
        );
        fixed_point64_with_sign::create_from_raw_value(raw, xp == yp)
    }

    /// x / y
    public fun div(x: FixedPoint64WithSign, y: FixedPoint64WithSign): FixedPoint64WithSign {
        assert!(fixed_point64_with_sign::get_raw_value(y) != 0, E_ZERO_DENOMINATOR);
        let xp = fixed_point64_with_sign::is_positive(x);
        let yp = fixed_point64_with_sign::is_positive(y);
        let raw = math_fixed64::mul_div_raw(
            fixed_point64_with_sign::get_raw_value(x),
            1u128 << 64,
            fixed_point64_with_sign::get_raw_value(y),
        );
        fixed_point64_with_sign::create_from_raw_value(raw, xp == yp)
    }

    /// x ^ n  (n is a positive integer)
    public fun pow(x: FixedPoint64WithSign, n: u64): FixedPoint64WithSign {
        let fp = math_fixed64::pow(fixed_point64_with_sign::remove_sign(x), n);
        // Sign: positive^even = positive, positive^odd = positive,
        //       negative^even = positive, negative^odd = negative
        let positive = fixed_point64_with_sign::is_positive(x) || (n % 2 == 0);
        fixed_point64_with_sign::create_from_raw_value(fixed_point64::get_raw_value(fp), positive)
    }

    /// sqrt(x)  — x must be non-negative
    public fun sqrt(x: FixedPoint64WithSign): FixedPoint64WithSign {
        assert!(fixed_point64_with_sign::is_positive(x), E_NEGATIVE);
        let fp = math_fixed64::sqrt(fixed_point64_with_sign::remove_sign(x));
        fixed_point64_with_sign::create_from_raw_value(fixed_point64::get_raw_value(fp), true)
    }

    /// Natural logarithm — x must be positive.
    /// Delegates to math_fixed64::ln_signed which returns (raw, is_positive).
    public fun ln(x: FixedPoint64WithSign): FixedPoint64WithSign {
        assert!(fixed_point64_with_sign::is_positive(x), E_NEGATIVE);
        let (raw, positive) = math_fixed64::ln_signed(fixed_point64_with_sign::remove_sign(x));
        fixed_point64_with_sign::create_from_raw_value(raw, positive)
    }

    /// log2(x)  — x must be positive.
    public fun log2(x: FixedPoint64WithSign): FixedPoint64WithSign {
        assert!(fixed_point64_with_sign::is_positive(x), E_NEGATIVE);
        let (raw, positive) = math_fixed64::log2_signed(fixed_point64_with_sign::remove_sign(x));
        fixed_point64_with_sign::create_from_raw_value(raw, positive)
    }

    /// e^x for any sign of x.
    /// If x >= 0: direct Taylor series.
    /// If x < 0: e^x = 1 / e^|x|.
    public fun exp(x: FixedPoint64WithSign): FixedPoint64WithSign {
        let one = fixed_point64_with_sign::create_from_raw_value(1u128 << 64, true);
        let abs_fp = math_fixed64::exp(fixed_point64_with_sign::remove_sign(x));
        let result = fixed_point64_with_sign::create_from_raw_value(
            fixed_point64::get_raw_value(abs_fp),
            true,
        );
        if (!fixed_point64_with_sign::is_positive(x)) {
            // e^(-|x|) = 1 / e^|x|
            div(one, result)
        } else {
            result
        }
    }

    // ── Aggregates ──────────────────────────────────────────────────────────────

    /// Maximum element of a non-empty vector.
    public fun maximum(numbers: vector<FixedPoint64WithSign>): FixedPoint64WithSign {
        assert!(vector::length(&numbers) > 0, E_ZERO_LENGTH);
        let mut max_val = *vector::borrow(&numbers, 0);
        let mut i = 1;
        while (i < vector::length(&numbers)) {
            let n = *vector::borrow(&numbers, i);
            let diff = fixed_point64_with_sign::sub(n, max_val);
            if (fixed_point64_with_sign::is_positive(diff)) {
                max_val = n;
            };
            i = i + 1;
        };
        max_val
    }

    /// Minimum element of a non-empty vector.
    public fun minimum(numbers: vector<FixedPoint64WithSign>): FixedPoint64WithSign {
        assert!(vector::length(&numbers) > 0, E_ZERO_LENGTH);
        let mut min_val = *vector::borrow(&numbers, 0);
        let mut i = 1;
        while (i < vector::length(&numbers)) {
            let n = *vector::borrow(&numbers, i);
            let diff = fixed_point64_with_sign::sub(min_val, n);
            if (fixed_point64_with_sign::is_positive(diff)) {
                min_val = n;
            };
            i = i + 1;
        };
        min_val
    }

    /// Sum of a vector.
    public fun sum(numbers: vector<FixedPoint64WithSign>): FixedPoint64WithSign {
        let mut s = fixed_point64_with_sign::create_from_raw_value(0, true);
        let mut i = 0;
        while (i < vector::length(&numbers)) {
            s = fixed_point64_with_sign::add(s, *vector::borrow(&numbers, i));
            i = i + 1;
        };
        s
    }

    /// Arithmetic mean.
    public fun mean(numbers: vector<FixedPoint64WithSign>): FixedPoint64WithSign {
        assert!(vector::length(&numbers) > 0, E_ZERO_LENGTH);
        let n   = vector::length(&numbers);
        let tot = sum(numbers);
        div_u128(tot, n as u128)
    }

    /// Population standard deviation.
    public fun std(numbers: vector<FixedPoint64WithSign>): FixedPoint64WithSign {
        let m   = mean(numbers);
        let mut s = fixed_point64_with_sign::create_from_raw_value(0, true);
        let mut i = 0;
        while (i < vector::length(&numbers)) {
            let diff  = fixed_point64_with_sign::sub(*vector::borrow(&numbers, i), m);
            let diff2 = pow(diff, 2);
            s = fixed_point64_with_sign::add(s, diff2);
            i = i + 1;
        };
        let variance = div_u128(s, vector::length(&numbers) as u128);
        sqrt(variance)
    }
}
