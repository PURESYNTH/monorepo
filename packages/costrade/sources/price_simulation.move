/// Thin wrapper around `monte_carlo` for convenient price simulation.
/// Mirrors `grndx::price_simulation`.
module costrade::price_simulation {

    use sui::random::Random;
    use sui::tx_context::TxContext;
    use costrade::monte_carlo;

    /// Generate a price path without an exclusion upper-bound (uses max_excl = 20).
    public entry fun get_spath_without_excl(
        s0:            u128,
        r:             u128,
        sigma:         u128,
        t:             u128,
        nsteps:        u64,
        nrep:          u64,
        is_positive_r: bool,
        rng:           &Random,
        ctx:           &mut TxContext,
    ) {
        monte_carlo::generate_spath_with_range(
            s0, r, sigma, t, nsteps, nrep, 20, is_positive_r, rng, ctx,
        )
    }

    /// Generate a price path with an explicit exclusion upper-bound.
    public entry fun get_spath_with_excl(
        s0:            u128,
        r:             u128,
        sigma:         u128,
        t:             u128,
        nsteps:        u64,
        nrep:          u64,
        max_excl:      u64,
        is_positive_r: bool,
        rng:           &Random,
        ctx:           &mut TxContext,
    ) {
        monte_carlo::generate_spath_with_range(
            s0, r, sigma, t, nsteps, nrep, max_excl, is_positive_r, rng, ctx,
        )
    }
}
