/// Pi constant and approximation algorithms.
/// Mirrors `grndx::pi` from the Aptos codebase.
module costrade::pi {

    use costrade::fixed_point64::{Self, FixedPoint64};

    /// PI * 2^64  — computed with the BBP formula (10 iterations).
    /// The real value of pi ≈ PI / 2^64.
    const PI: u128 = 57952155664616944161;

    // ── Public ──────────────────────────────────────────────────────────────────

    /// Return the precomputed PI constant as a raw u128 (FP64 representation).
    public fun get_pi_const(): u128 { PI }

    /// Leibniz series approximation:
    ///   pi = 4 * sum_n ( (-1)^n / (2n+1) )
    /// Accurate only for large `rep`.
    public fun leibniz_approx_pi(rep: u128): FixedPoint64 {
        let mut result = fixed_point64::create_from_raw_value(1u128 << 64); // 1.0
        let mut i: u128 = 1;
        while (i < rep) {
            if (i % 2 == 0) {
                result = fixed_point64::add(
                    result,
                    fixed_point64::create_from_rational(1, 2 * i + 1),
                );
            } else {
                result = fixed_point64::sub(
                    result,
                    fixed_point64::create_from_rational(1, 2 * i + 1),
                );
            };
            i = i + 1;
        };
        multiply(result, 4)
    }

    /// Bailey–Borwein–Plouffe (BBP) formula — much faster convergence.
    ///   pi = sum_k (1/16^k) * (4/(8k+1) - 2/(8k+4) - 1/(8k+5) - 1/(8k+6))
    public fun bbp_approx_pi(rep: u128): FixedPoint64 {
        // seed: k=0 term = 4/1 - 2/4 - 1/5 - 1/6
        let mut result = fixed_point64::sub(
            fixed_point64::create_from_raw_value(4u128 << 64),
            fixed_point64::create_from_rational(13, 15), // 2/4+1/5+1/6 = 13/15
        );
        let mut i: u128 = 1;
        while (i < rep) {
            let pow16 = pow16(i);
            result = fixed_point64::add(
                result,
                fixed_point64::create_from_rational(4, pow16 * (8 * i + 1)),
            );
            result = fixed_point64::sub(
                result,
                fixed_point64::create_from_rational(2, pow16 * (8 * i + 4)),
            );
            result = fixed_point64::sub(
                result,
                fixed_point64::create_from_rational(1, pow16 * (8 * i + 5)),
            );
            result = fixed_point64::sub(
                result,
                fixed_point64::create_from_rational(1, pow16 * (8 * i + 6)),
            );
            i = i + 1;
        };
        result
    }

    // ── Helpers ─────────────────────────────────────────────────────────────────

    fun multiply(x: FixedPoint64, n: u128): FixedPoint64 {
        let mut result = x;
        let mut j: u128 = 1;
        while (j < n) {
            result = fixed_point64::add(result, x);
            j = j + 1;
        };
        result
    }

    fun pow16(e: u128): u128 {
        let mut result: u128 = 1;
        let mut i: u128 = 0;
        while (i < e) {
            result = result * 16;
            i = i + 1;
        };
        result
    }
}
