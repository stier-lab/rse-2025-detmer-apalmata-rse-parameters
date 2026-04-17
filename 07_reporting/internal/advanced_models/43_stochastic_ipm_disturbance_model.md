# 43: Stochastic Disturbance-Driven IPM (Approximation)

## Goal
Extend viability analysis beyond the static matrix by fitting disturbance-regime-conditioned vital rates and projecting population trajectories under stochastic regime sequences.

## Data Used
- `06_analysis/output/prepared_survival_data.rds`
- `06_analysis/output/prepared_growth_data.rds`
- `05_data/standardized/apal_life_history_parameters_analysis.csv`

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
- A survival-growth kernel was built
- An additive recruitment kernel was layered on under three explicit scenarios:
  - `zero`
  - `conservative`
  - `optimistic`
- Deterministic kernel lambda was computed

Kernel lambdas (`06_analysis/output/stochastic_ipm_regime_kernel_lambdas.csv`):
- Zero-recruitment kernels:
  - Baseline exclusion: `0.851`
  - Catastrophic: `0.509`
  - Context only: `0.824`
  - None: `0.832`
- Optimistic recruitment only nudged the kernel lambdas upward by a few ten-thousandths to thousandths; it did not change the qualitative ordering or bring any regime near replacement.

## Stochastic Projection Design
Projection horizon: 50 years, 800 simulations, initial abundance index = 1000.

Scenarios:
- `markov`: regime switches via empirical year-to-year transition matrix
- `iid`: regime draws from empirical frequencies (independent by year)
- `none_only`: no-disturbance counterfactual using only the `none` kernel

Outputs:
- `06_analysis/output/stochastic_ipm_model_diagnostics.csv`
- `06_analysis/output/stochastic_ipm_recruitment_scenarios.csv`
- `06_analysis/output/stochastic_ipm_regime_kernel_lambdas.csv`
- `06_analysis/output/stochastic_ipm_regime_transition_matrix.csv`
- `06_analysis/output/stochastic_ipm_year_regime_series.csv`
- `06_analysis/output/stochastic_ipm_projection_quantiles.csv`
- `06_analysis/output/stochastic_ipm_simulation_summary.csv`
- `06_analysis/figures/supplementary/stochastic_ipm_projection_trajectories.png`
- `06_analysis/figures/supplementary/stochastic_ipm_projection_trajectories.pdf`

## Main Results
From `stochastic_ipm_simulation_summary.csv`:
- Markov switching:
  - zero recruitment `lambda = 0.7804`
  - conservative recruitment `lambda = 0.7816`
  - optimistic recruitment `lambda = 0.7806`
- IID switching:
  - zero recruitment `lambda = 0.8050`
  - conservative recruitment `lambda = 0.8051`
  - optimistic recruitment `lambda = 0.8045`
- None-only counterfactual:
  - zero recruitment `lambda = 0.8187`
  - conservative recruitment `lambda = 0.8188`
  - optimistic recruitment `lambda = 0.8191`
- All nine scenario combinations had quasi-extinction probability `1.00` by year 50 at the current abundance threshold.

Interpretation:
- All modeled regime mixtures remain below replacement (`lambda < 1`).
- The IPM stochastic lambdas (0.78-0.82) are lower than the Lefkovitch matrix lambda (0.961) because: (a) the IPM fits its own GAMs to near-annual intervals only, while the matrix uses study-level rma() across all intervals; (b) the IPM conditions on disturbance regime, separating catastrophic years that the matrix averages over; (c) the continuous size kernel captures mortality patterns that the 5-class discretization smooths.
- Catastrophic years strongly depress the long-run growth trajectory. The catastrophic kernel lambda (0.509) corresponds to the Neely 2014 bleaching event.
- The current recruitment scenarios are too small to materially change the viability conclusion; they function as explicit assumption bounds, not a rescue mechanism. The `recruit_surv_pars.rds` file (s_recruit = 0.028) provides empirical post-settlement survival for future fecundity modeling.
- Even the no-disturbance counterfactual remains declining under currently estimated natural-colony vital rates.

## Limitations
1. This is an IPM approximation, not a full latent state-space fit with observation error decomposition.
2. Catastrophic regime sample size is small (`n=57` survival, `n=36` growth), so catastrophic kernel uncertainty is high.
3. Year-level regime transitions are inferred from available survey years; some years are missing in the observed sequence.
4. Recruitment is now explicit, but the scalars are scenario-based and anchored to retained life-history parameters rather than estimated from integrated colony-to-recruit data.
5. The diagnostics file currently mixes true model-fit rows with recruitment-scenario metadata; treat the recruitment rows as assumption records, not AIC/deviance outputs.
6. Regional imbalance remains (Florida-heavy data), so transition dynamics are not uniformly Caribbean-representative.

## Suggested Next Iteration
- Add bootstrap uncertainty around kernels and stochastic lambda.
- Separate recruitment assumption records from model-fit diagnostics into a dedicated tidy output.
- Replace scenario-scaled recruitment with an empirically calibrated or sensitivity-bounded fecundity workflow.
- Compare Markov projections with event-sequence replay using the curated disturbance chronology.
