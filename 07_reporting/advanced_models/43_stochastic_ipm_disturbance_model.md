# 43: Stochastic Disturbance-Driven IPM (Approximation)

## Goal
Extend viability analysis beyond the static matrix by fitting disturbance-regime-conditioned vital rates and projecting population trajectories under stochastic regime sequences.

## Data Used
- `06_analysis/output/prepared_survival_data.rds`
- `06_analysis/output/prepared_growth_data.rds`

Filtering applied in this model:
- Natural colonies only (`population_type == "Natural colony"` for survival; `fragment == "N"` for growth)
- Near-annual intervals only (`0.5 <= time_interval_yr <= 1.5`)
- Positive, finite size values
- Impossible growth records removed where flagged

Final analysis sample:
- Survival: `n = 5,508`
- Growth: `n = 4,508`

## Disturbance Regime Encoding
Regimes were derived from prepared disturbance overlay columns:
- `catastrophic`: `is_catastrophic == TRUE`
- `baseline_exclusion`: `exclude_from_baseline == TRUE` (non-catastrophic)
- `context_only`: timeline overlap but not baseline exclusion
- `none`: no timeline overlap

Regime counts used by the fitted model:
- Survival: baseline exclusion `965`, catastrophic `57`, context only `4,144`, none `342`
- Growth: baseline exclusion `875`, catastrophic `36`, context only `3,321`, none `276`

## Model Structure
Two GAMs were fit:
1. Survival model (binomial logit):  
   `survived ~ regime_class + s(log_size) + s(log_size, by = regime_class)`
2. Growth model (Gaussian):  
   `delta_log_size ~ regime_class + s(log_size) + s(log_size, by = regime_class)`

Then, for each regime:
- Predicted survival and growth were mapped to a size mesh (`n = 140` in log-size space)
- A regime-specific IPM kernel was built
- Deterministic kernel lambda was computed

Kernel lambdas (`06_analysis/output/stochastic_ipm_regime_kernel_lambdas.csv`):
- Baseline exclusion: `0.851`
- Catastrophic: `0.509`
- Context only: `0.824`
- None: `0.832`

## Stochastic Projection Design
Projection horizon: 50 years, 800 simulations, initial abundance index = 1000.

Scenarios:
- `markov`: regime switches via empirical year-to-year transition matrix
- `iid`: regime draws from empirical frequencies (independent by year)
- `none_only`: no-disturbance counterfactual using only the `none` kernel

Outputs:
- `06_analysis/output/stochastic_ipm_model_diagnostics.csv`
- `06_analysis/output/stochastic_ipm_regime_kernel_lambdas.csv`
- `06_analysis/output/stochastic_ipm_regime_transition_matrix.csv`
- `06_analysis/output/stochastic_ipm_year_regime_series.csv`
- `06_analysis/output/stochastic_ipm_projection_quantiles.csv`
- `06_analysis/output/stochastic_ipm_simulation_summary.csv`
- `06_analysis/figures/supplementary/stochastic_ipm_projection_trajectories.png`
- `06_analysis/figures/supplementary/stochastic_ipm_projection_trajectories.pdf`

## Main Results
From `stochastic_ipm_simulation_summary.csv`:
- Markov switching: stochastic lambda `0.780`, quasi-extinction probability by year 50 = `1.00`
- IID switching: stochastic lambda `0.805`, quasi-extinction probability by year 50 = `1.00`
- None-only counterfactual: stochastic lambda `0.819`, quasi-extinction probability by year 50 = `1.00`

Interpretation:
- All modeled regime mixtures remain below replacement (`lambda < 1`).
- Catastrophic years strongly depress the long-run growth trajectory.
- Even the no-disturbance counterfactual remains declining under currently estimated natural-colony vital rates.

## Limitations
1. This is an IPM approximation, not a full latent state-space fit with observation error decomposition.
2. Catastrophic regime sample size is small (`n=57` survival, `n=36` growth), so catastrophic kernel uncertainty is high.
3. Year-level regime transitions are inferred from available survey years; some years are missing in the observed sequence.
4. No explicit recruitment/fecundity term was added; the model behaves as a post-settlement size-structured survival-growth system.
5. Regional imbalance remains (Florida-heavy data), so transition dynamics are not uniformly Caribbean-representative.

## Suggested Next Iteration
- Add bootstrap uncertainty around kernels and stochastic lambda.
- Add a fecundity/recruitment component with scenario bounds.
- Compare Markov projections with event-sequence replay using the curated disturbance chronology.
