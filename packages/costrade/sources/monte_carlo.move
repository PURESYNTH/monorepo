/// Geometric Brownian Motion (GBM) price-path simulation via Monte Carlo.
/// Mirrors `grndx::monte_carlo`.
///
/// GBM formula per step:
///   S_t = S_{t-1} * exp((μ - 0.5 σ²) dt + σ √dt Z_t)
///
/// where Z_t ~ N(0,1) from the Box–Muller transform.
///
/// All price / rate inputs (s0, r, sigma, t) are FP64 raw values
/// (i.e. the real value multiplied by 2^64 on the client side).
module costrade::monte_carlo {

    use std::vector;
    use sui::random::{Self, Random, RandomGenerator};
    use costrade::fixed_point64::{Self, FixedPoint64};
    use costrade::fixed_point64_with_sign::{Self, FixedPoint64WithSign};
    use costrade::math_fixed64;
    use costrade::math_fixed64_with_sign;
    use costrade::box_muller;
    use costrade::pi;

    // ── Public entry points ─────────────────────────────────────────────────────

    /// Generate price paths from pre-supplied random numbers.
    ///
    /// Returns a 2-D vector:  paths[rep_idx][step_idx] = price (FP64 raw).
    public fun generate_spath(
        s0:              u128,   // initial price (FP64 raw)
        r:               u128,   // drift rate (FP64 raw)
        sigma:           u128,   // volatility (FP64 raw)
        t:               u128,   // time horizon (FP64 raw)
        nsteps:          u64,
        nrep:            u64,
        is_positive_r:   bool,
        random_numbers:  vector<u64>,
    ): vector<vector<u128>> {
        let normals = box_muller::uniform_to_normal(random_numbers, 10_000_000_000_000_000);
        compute_paths(s0, r, sigma, t, nsteps, nrep, is_positive_r, normals)
    }

    /// Generate price paths drawing randomness from the Sui RNG (u64_range).
    public entry fun generate_spath_with_range(
        s0:            u128,
        r:             u128,
        sigma:         u128,
        t:             u128,
        nsteps:        u64,
        nrep:          u64,
        max_excl:      u64,
        is_positive_r: bool,
        rng:           &Random,
        ctx:           &mut sui::tx_context::TxContext,
    ) {
        let mut generator = random::new_generator(rng, ctx);
        let random_numbers = generate_random_u64_range(&mut generator, nrep, nsteps, max_excl);
        // Result is discarded (entry function); callers use events or shared objects.
        let _ = generate_spath(s0, r, sigma, t, nsteps, nrep, is_positive_r, random_numbers);
    }

    /// Generate price paths drawing from a permutation-based RNG.
    public entry fun generate_spath_with_permutation(
        s0:            u128,
        r:             u128,
        sigma:         u128,
        t:             u128,
        nsteps:        u64,
        nrep:          u64,
        is_positive_r: bool,
        rng:           &Random,
        ctx:           &mut sui::tx_context::TxContext,
    ) {
        let mut generator = random::new_generator(rng, ctx);
        let random_numbers = generate_random_permutation(&mut generator, nrep, nsteps);
        let _ = generate_spath(s0, r, sigma, t, nsteps, nrep, is_positive_r, random_numbers);
    }

    // ── Internal helpers ────────────────────────────────────────────────────────

    /// Core path computation, shared by all entry-point variants.
    public(package) fun compute_paths(
        s0:            u128,
        r:             u128,
        sigma:         u128,
        t:             u128,
        nsteps:        u64,
        nrep:          u64,
        is_positive_r: bool,
        normals:       vector<FixedPoint64WithSign>,
    ): vector<vector<u128>> {
        let mut paths = init_2d_vector(nsteps, nrep, s0);
        let one   = 1u128 << 64;
        let dt_raw = math_fixed64::mul_div_raw(t, one, (nsteps as u128) << 64);
        // σ²
        let sigma2 = math_fixed64::mul_div_raw(sigma, sigma, one);
        // nudt = (r - 0.5 σ²) * dt
        let half_sigma2 = sigma2 / 2;
        let nudt_signed: FixedPoint64WithSign;
        if (is_positive_r) {
            if (r >= half_sigma2) {
                let nudt_raw = math_fixed64::mul_div_raw(r - half_sigma2, dt_raw, one);
                nudt_signed  = fixed_point64_with_sign::create_from_raw_value(nudt_raw, true);
            } else {
                let nudt_raw = math_fixed64::mul_div_raw(half_sigma2 - r, dt_raw, one);
                nudt_signed  = fixed_point64_with_sign::create_from_raw_value(nudt_raw, false);
            }
        } else {
            let nudt_raw = math_fixed64::mul_div_raw(r + half_sigma2, dt_raw, one);
            nudt_signed  = fixed_point64_with_sign::create_from_raw_value(nudt_raw, false);
        };
        // sidt = σ * √dt
        let sqrt_dt_raw = math_fixed64::sqrt(fixed_point64::create_from_raw_value(dt_raw));
        let sidt_raw    = math_fixed64::mul_div_raw(
            sigma, fixed_point64::get_raw_value(sqrt_dt_raw), one
        );

        let mut rep_idx: u64 = 0;
        let mut z_offset: u64 = 0;
        while (rep_idx < nrep) {
            let mut step: u64 = 1;
            while (step <= nsteps) {
                let prev = *vector::borrow(vector::borrow(&paths, rep_idx), step - 1);
                let zt = *vector::borrow(&normals, (z_offset + step - 1) % vector::length(&normals));

                let exp_arg = calculate_exp(nudt_signed, sidt_raw, zt);
                let exp_val = math_fixed64_with_sign::exp(exp_arg);

                // new_price = prev * exp_val / 2^64
                let new_price = math_fixed64::mul_div_raw(
                    prev,
                    fixed_point64_with_sign::get_raw_value(exp_val),
                    one,
                );
                let row = vector::borrow_mut(&mut paths, rep_idx);
                *vector::borrow_mut(row, step) = new_price;
                step = step + 1;
            };
            z_offset = z_offset + nsteps;
            rep_idx  = rep_idx + 1;
        };
        paths
    }

    /// exp_arg = nudt + sidt * Z_t
    public(package) fun calculate_exp(
        sign_nudt: FixedPoint64WithSign,
        sidt_raw:  u128,
        zt:        FixedPoint64WithSign,
    ): FixedPoint64WithSign {
        let one = 1u128 << 64;
        let sidt_zt_raw = math_fixed64::mul_div_raw(
            sidt_raw,
            fixed_point64_with_sign::get_raw_value(zt),
            one,
        );
        let sidt_zt = fixed_point64_with_sign::create_from_raw_value(
            sidt_zt_raw,
            fixed_point64_with_sign::is_positive(zt),
        );
        fixed_point64_with_sign::add(sign_nudt, sidt_zt)
    }

    /// Initialise a (nrep × (nsteps+1)) matrix with `first_col_value` in column 0.
    public(package) fun init_2d_vector(nsteps: u64, nrep: u64, first_col_value: u128): vector<vector<u128>> {
        let mut rows: vector<vector<u128>> = vector::empty();
        let mut r: u64 = 0;
        while (r < nrep) {
            let mut row: vector<u128> = vector::empty();
            vector::push_back(&mut row, first_col_value);
            let mut s: u64 = 1;
            while (s <= nsteps) {
                vector::push_back(&mut row, 0);
                s = s + 1;
            };
            vector::push_back(&mut rows, row);
            r = r + 1;
        };
        rows
    }

    // ── Random-number generation helpers ────────────────────────────────────────

    /// Draw `nrep * nsteps` uniform u64 values from [1, max_excl).
    public(package) fun generate_random_u64_range(
        rng:      &mut RandomGenerator,
        nrep:     u64,
        nsteps:   u64,
        max_excl: u64,
    ): vector<u64> {
        let n = nrep * nsteps;
        let mut v: vector<u64> = vector::empty();
        let mut i: u64 = 0;
        while (i < n) {
            vector::push_back(&mut v, random::generate_u64_in_range(rng, 1, max_excl));
            i = i + 1;
        };
        v
    }

    /// Draw `nrep * nsteps` permutation-based u8 values scaled to u64.
    public(package) fun generate_random_permutation(
        rng:    &mut RandomGenerator,
        nrep:   u64,
        nsteps: u64,
    ): vector<u64> {
        let n = nrep * nsteps;
        let mut v: vector<u64> = vector::empty();
        let mut i: u64 = 0;
        while (i < n) {
            vector::push_back(&mut v, (random::generate_u8(rng) as u64) + 1);
            i = i + 1;
        };
        v
    }
}
