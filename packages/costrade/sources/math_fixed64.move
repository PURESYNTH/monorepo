/// Math operations on `FixedPoint64` (unsigned, Q64.64).
/// Provides pow, sqrt, exp, ln, log2 — replacing the Aptos
/// `aptos_std::math_fixed64` API for the Sui target.
///
/// All inputs and outputs use the raw `u128` representation
/// (`value` field of `FixedPoint64`, i.e. real_value * 2^64).
module costrade::math_fixed64 {

    use costrade::fixed_point64::{Self, FixedPoint64};

    const E_ZERO_INPUT:       u64 = 0;
    const E_NEGATIVE:         u64 = 1;
    const E_OVERFLOW:         u64 = 2;

    /// ln(2) * 2^64  (rounded)
    const LN2: u128 = 12786308645202655660;

    /// 1.0 in Q64.64
    const ONE: u128 = 1 << 64;

    // ── Helpers (raw u128 arithmetic) ───────────────────────────────────────────

    /// `(a * b) / c` in u256 to avoid overflow.  Both inputs are FP64 raws.
    public fun mul_div_raw(a: u128, b: u128, c: u128): u128 {
        assert!(c != 0, E_ZERO_INPUT);
        let result = (a as u256) * (b as u256) / (c as u256);
        assert!(result <= 340282366920938463463374607431768211455u256, E_OVERFLOW);
        result as u128
    }

    /// Integer square-root of a u256 via Newton–Raphson.
    fun isqrt256(n: u256): u256 {
        if (n == 0) return 0;
        let mut x = n;
        let mut y = (n + 1) / 2;
        while (y < x) {
            x = y;
            y = (y + n / y) / 2;
        };
        x
    }

    // ── Public FixedPoint64 operations ──────────────────────────────────────────

    /// (x * y) / z  where all three are FixedPoint64.
    public fun mul_div(x: FixedPoint64, y: FixedPoint64, z: FixedPoint64): FixedPoint64 {
        fixed_point64::mul_div(x, y, z)
    }

    /// `x ^ n`  where x is FixedPoint64 and n is a u64 exponent.
    public fun pow(x: FixedPoint64, n: u64): FixedPoint64 {
        let mut result = ONE; // 1.0
        let mut base   = fixed_point64::get_raw_value(x);
        let mut exp_n  = n;
        while (exp_n > 0) {
            if (exp_n & 1 == 1) {
                result = mul_div_raw(result, base, ONE);
            };
            base  = mul_div_raw(base, base, ONE);
            exp_n = exp_n >> 1;
        };
        fixed_point64::create_from_raw_value(result)
    }

    /// sqrt(x) via `isqrt(x_raw << 64)` using u256 arithmetic.
    public fun sqrt(x: FixedPoint64): FixedPoint64 {
        let v   = fixed_point64::get_raw_value(x) as u256;
        let raw = isqrt256(v << 64) as u128;
        fixed_point64::create_from_raw_value(raw)
    }

    /// e^x  using Taylor series (works for |x_real| < ~20).
    /// For negative exponents, call with positive then invert (see math_fixed64_with_sign::exp).
    public fun exp(x: FixedPoint64): FixedPoint64 {
        let xv = fixed_point64::get_raw_value(x);
        // Taylor: 1 + x + x²/2! + x³/3! + … (20 terms)
        let mut sum    = ONE;             // 1.0
        let mut term   = xv;             // x^1 / 1!
        let mut i: u64 = 2;
        while (i <= 20) {
            sum = sum + term;
            // term_next = term * x / i
            term = mul_div_raw(term, xv, (i as u128) << 64);
            i    = i + 1;
        };
        fixed_point64::create_from_raw_value(sum)
    }

    /// Natural logarithm of x (x must be positive / non-zero).
    /// Returns a FixedPoint64; the caller must interpret the sign externally
    /// if x < 1 (use math_fixed64_with_sign::ln for signed results).
    ///
    /// Algorithm:
    ///   1. Factor out powers of 2: x = m * 2^k,  m in [1, 2)
    ///   2. ln(x) = k * ln(2) + ln(m)
    ///   3. ln(m) using series  2 * (t + t³/3 + t⁵/5 + …),  t = (m-1)/(m+1)
    ///
    /// Returns (raw_value, is_positive).
    public fun ln_signed(x: FixedPoint64): (u128, bool) {
        let v = fixed_point64::get_raw_value(x);
        assert!(v > 0, E_ZERO_INPUT);

        // Step 1: find k such that  v / 2^64  is in  [1, 2^k, 2^{k+1})
        // i.e. m_raw (a FP64 in [1,2)) and shift k (can be negative).
        let (m_raw, k_positive, k_abs) = normalize_fp64(v);

        // Step 2: ln(m_raw) via atanh series
        let ln_m_raw = ln_one_to_two(m_raw);  // always positive, m in [1,2)

        // Step 3: k * ln(2)
        // k * LN2  (both as raw FP64)
        let k_ln2 = (k_abs as u128) * LN2 / ONE;
        // Actually k*LN2 in raw FP64: k_abs * LN2 (LN2 is already in FP64 units)
        let k_ln2_raw = (k_abs as u128) * LN2;
        // Careful: (k_abs * LN2) is k * (ln2 * 2^64).
        // ln(x) = k*ln(2) + ln(m) as real numbers.
        // As FP64: raw_result = k * LN2 + ln_m_raw  (both already scaled by 2^64).
        // But "k * LN2" means k * (ln2 in FP64) = k * LN2 (just an integer multiply).
        // That gives a u128; fine if k is small.
        let _ = k_ln2; // suppress unused
        let ln_x_raw: u128;
        let ln_x_positive: bool;
        if (k_positive) {
            ln_x_raw      = k_ln2_raw + ln_m_raw;
            ln_x_positive = true;
        } else {
            // ln(x) = -k*ln(2) + ln(m)
            if (ln_m_raw >= k_ln2_raw) {
                ln_x_raw      = ln_m_raw - k_ln2_raw;
                ln_x_positive = true;
            } else {
                ln_x_raw      = k_ln2_raw - ln_m_raw;
                ln_x_positive = false;
            }
        };
        (ln_x_raw, ln_x_positive)
    }

    /// log2(x) = ln(x) / ln(2).  Returns (raw, is_positive).
    public fun log2_signed(x: FixedPoint64): (u128, bool) {
        let (ln_raw, positive) = ln_signed(x);
        // log2 = ln / ln2;  ln2 as FP64 raw = LN2
        let raw = mul_div_raw(ln_raw, ONE, LN2);
        (raw, positive)
    }

    // ── Private helpers ─────────────────────────────────────────────────────────

    /// Reduce a FP64 raw value `v` (v > 0) to `m_raw` in [2^64, 2^65)
    /// (representing a real value in [1, 2)) and return the base-2 exponent k
    /// (with sign) such that v_real = m_real * 2^k.
    ///
    /// Returns (m_raw, k_is_positive, k_abs).
    fun normalize_fp64(v: u128): (u128, bool, u64) {
        // MSB position of v: 0-indexed from LSB
        let msb = msb_u128(v);
        // v_real = v / 2^64,  so log2(v_real) = msb - 64
        // We want m_raw in [2^64, 2^65), meaning m_real in [1,2).
        // m_raw = v << (64 - msb)   if msb <= 64
        //         v >> (msb - 64)   if msb > 64
        let m_raw: u128;
        let k_positive: bool;
        let k_abs: u64;
        if (msb >= 64) {
            let shift = msb - 64;
            m_raw       = v >> (shift as u8);
            k_positive  = true;
            k_abs       = shift;
        } else {
            let shift = 64 - msb;
            m_raw       = v << (shift as u8);
            // v_real = m_real / 2^shift, so k = -shift
            k_positive  = false;
            k_abs       = shift;
        };
        (m_raw, k_positive, k_abs)
    }

    /// ln(m) for m in [1, 2) using the series:
    ///   t = (m - 1) / (m + 1)
    ///   ln(m) = 2 * (t + t³/3 + t⁵/5 + ...)
    /// Input: m_raw is FP64 raw in [2^64, 2^65)  i.e. m_real in [1,2).
    /// Output: FP64 raw representing ln(m_real).  Always positive.
    fun ln_one_to_two(m_raw: u128): u128 {
        // t = (m - 1) / (m + 1)
        let one = ONE;
        let t_raw = mul_div_raw(m_raw - one, one, m_raw + one);

        // Series: sum = t + t^3/3 + t^5/5 + ... (12 terms)
        let mut sum  = t_raw;
        let mut t2   = mul_div_raw(t_raw, t_raw, one); // t^2
        let mut term = t_raw;
        let mut n: u64 = 3;
        while (n <= 25) {
            term = mul_div_raw(term, t2, one);        // t^n
            sum  = sum + mul_div_raw(term, one, (n as u128) << 64);
            n    = n + 2;
        };
        // multiply by 2
        sum * 2
    }

    /// Position of the most significant bit of a u128 (0-indexed, returns 0 for value=1).
    fun msb_u128(v: u128): u64 {
        assert!(v > 0, E_ZERO_INPUT);
        let mut n: u64 = 0;
        let mut x = v;
        if (x >= (1u128 << 64)) { x = x >> 64; n = n + 64; };
        if (x >= (1u128 << 32)) { x = x >> 32; n = n + 32; };
        if (x >= (1u128 << 16)) { x = x >> 16; n = n + 16; };
        if (x >= (1u128 <<  8)) { x = x >>  8; n = n +  8; };
        if (x >= (1u128 <<  4)) { x = x >>  4; n = n +  4; };
        if (x >= (1u128 <<  2)) { x = x >>  2; n = n +  2; };
        if (x >= (1u128 <<  1)) {               n = n +  1; };
        n
    }
}
