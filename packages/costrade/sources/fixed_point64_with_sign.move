/// Signed Q64.64 fixed-point number.
/// Wraps a raw `u128` (same representation as `FixedPoint64`) together with a
/// boolean sign flag.  `positive == true` means the value is >= 0.
///
/// Mirrors `grndx::fixed_point64_with_sign` from the Aptos codebase.
module costrade::fixed_point64_with_sign {

    use costrade::fixed_point64::{Self, FixedPoint64};

    const E_RATIO_OUT_OF_RANGE: u64 = 131077;
    const MAX_U128: u256 = 340282366920938463463374607431768211455;

    public struct FixedPoint64WithSign has copy, drop, store {
        value:    u128,
        positive: bool,
    }

    // ── Constructors ────────────────────────────────────────────────────────────

    public fun create_from_raw_value(value: u128, positive: bool): FixedPoint64WithSign {
        FixedPoint64WithSign { value, positive }
    }

    /// `(number / denominator)` with explicit sign.
    public fun create_from_rational(number: u128, denominator: u128, positive: bool): FixedPoint64WithSign {
        let fp = fixed_point64::create_from_rational(number, denominator);
        FixedPoint64WithSign { value: fixed_point64::get_raw_value(fp), positive }
    }

    // ── Accessors ───────────────────────────────────────────────────────────────

    public fun get_raw_value(x: FixedPoint64WithSign): u128 { x.value }
    public fun is_positive(x: FixedPoint64WithSign): bool   { x.positive }

    public fun remove_sign(x: FixedPoint64WithSign): FixedPoint64 {
        fixed_point64::create_from_raw_value(x.value)
    }

    /// Absolute value (always positive).
    public fun abs(x: FixedPoint64WithSign): FixedPoint64WithSign {
        FixedPoint64WithSign { value: x.value, positive: true }
    }

    public fun abs_u128(x: FixedPoint64WithSign): u128 { x.value }

    /// Negate: flip the sign.
    public fun revert_sign(x: FixedPoint64WithSign): FixedPoint64WithSign {
        FixedPoint64WithSign { value: x.value, positive: !x.positive }
    }

    // ── Comparison ──────────────────────────────────────────────────────────────

    public fun greater_or_equal_without_sign(a: FixedPoint64WithSign, b: FixedPoint64WithSign): bool {
        a.value >= b.value
    }

    public fun is_equal(x: FixedPoint64WithSign, y: FixedPoint64WithSign): bool {
        x.value == y.value && x.positive == y.positive
    }

    public fun less(x: FixedPoint64WithSign, y: FixedPoint64WithSign): bool {
        is_positive(sub(y, x))
    }

    public fun greater_or_equal(x: FixedPoint64WithSign, y: FixedPoint64WithSign): bool {
        let diff = sub(x, y);
        is_positive(diff) || diff.value == 0
    }

    // ── Arithmetic ──────────────────────────────────────────────────────────────

    public fun add(x: FixedPoint64WithSign, y: FixedPoint64WithSign): FixedPoint64WithSign {
        let xr = x.value;
        let yr = y.value;
        let xp = x.positive;
        let yp = y.positive;

        let result: u256;
        let sign:   bool;

        if (xp && yp) {
            result = (xr as u256) + (yr as u256);
            sign   = true;
        } else if (xp && !yp) {
            if (xr >= yr) {
                result = (xr as u256) - (yr as u256);
                sign   = true;
            } else {
                result = (yr as u256) - (xr as u256);
                sign   = false;
            }
        } else if (!xp && yp) {
            if (yr >= xr) {
                result = (yr as u256) - (xr as u256);
                sign   = true;
            } else {
                result = (xr as u256) - (yr as u256);
                sign   = false;
            }
        } else {
            // both negative
            result = (xr as u256) + (yr as u256);
            sign   = false;
        };

        assert!(result <= MAX_U128, E_RATIO_OUT_OF_RANGE);
        FixedPoint64WithSign { value: (result as u128), positive: sign }
    }

    public fun sub(x: FixedPoint64WithSign, y: FixedPoint64WithSign): FixedPoint64WithSign {
        add(x, revert_sign(y))
    }
}
