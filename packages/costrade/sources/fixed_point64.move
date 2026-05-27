/// FixedPoint64 — a Q64.64 unsigned fixed-point number.
/// The raw `value` field represents the real number `value / 2^64`.
/// This module mirrors the Aptos stdlib `aptos_std::fixed_point64` API,
/// re-implemented natively for Sui (which has no built-in equivalent).
module costrade::fixed_point64 {

    const E_RATIO_OUT_OF_RANGE: u64 = 131077;
    const E_DENOMINATOR_ZERO:   u64 = 131078;
    const E_UNDERFLOW:          u64 = 131079;

    /// MAX raw value is u128::MAX
    const MAX_U128: u256 = 340282366920938463463374607431768211455;

    public struct FixedPoint64 has copy, drop, store {
        value: u128,
    }

    // ── Constructors ────────────────────────────────────────────────────────────

    public fun create_from_raw_value(value: u128): FixedPoint64 {
        FixedPoint64 { value }
    }

    /// `n / d` encoded as FixedPoint64.
    public fun create_from_rational(n: u128, d: u128): FixedPoint64 {
        assert!(d != 0, E_DENOMINATOR_ZERO);
        // Shift n left 64 bits then divide, using u256 to avoid overflow.
        let shifted = (n as u256) << 64;
        let result  = shifted / (d as u256);
        assert!(result <= MAX_U128, E_RATIO_OUT_OF_RANGE);
        FixedPoint64 { value: (result as u128) }
    }

    // ── Accessors ───────────────────────────────────────────────────────────────

    public fun get_raw_value(x: FixedPoint64): u128 { x.value }

    /// Round down to the nearest integer.
    public fun floor(x: FixedPoint64): u128 { x.value >> 64 }

    /// Round to the nearest integer.
    public fun round(x: FixedPoint64): u128 {
        let floor_val = x.value >> 64;
        let frac      = x.value & 0xFFFFFFFFFFFFFFFF;
        if (frac >= (1u128 << 63)) { floor_val + 1 } else { floor_val }
    }

    // ── Arithmetic ──────────────────────────────────────────────────────────────

    public fun add(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
        FixedPoint64 { value: x.value + y.value }
    }

    public fun sub(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
        assert!(x.value >= y.value, E_UNDERFLOW);
        FixedPoint64 { value: x.value - y.value }
    }

    /// Returns (x * y) / z without intermediate overflow, using u256.
    public fun mul_div(x: FixedPoint64, y: FixedPoint64, z: FixedPoint64): FixedPoint64 {
        assert!(z.value != 0, E_DENOMINATOR_ZERO);
        let numerator = (x.value as u256) * (y.value as u256);
        let result    = numerator / (z.value as u256);
        assert!(result <= MAX_U128, E_RATIO_OUT_OF_RANGE);
        FixedPoint64 { value: (result as u128) }
    }

    /// Multiply a plain u128 integer by a FixedPoint64 factor.
    public fun multiply_u128(val: u128, factor: FixedPoint64): u128 {
        (((val as u256) * (factor.value as u256)) >> 64) as u128
    }

    // ── Comparison helpers ──────────────────────────────────────────────────────

    public fun is_zero(x: FixedPoint64): bool { x.value == 0 }

    public fun less_or_equal(x: FixedPoint64, y: FixedPoint64): bool {
        x.value <= y.value
    }

    public fun greater_or_equal(x: FixedPoint64, y: FixedPoint64): bool {
        x.value >= y.value
    }
}
