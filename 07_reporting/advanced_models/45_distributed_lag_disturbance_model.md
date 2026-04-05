# 45. Distributed-Lag Disturbance Analysis

## Objective

Extend colony-level demographic modeling beyond contemporaneous disturbance flags by explicitly modeling lagged disturbance exposure (`lag 0-3 years`) for:

- survival (`survived`)
- growth state (`positive_growth`)
- continuous growth response (`rgr`)

The model uses prepared panel datasets and year-indexed curated disturbance events.

## Data Inputs

- `06_analysis/output/prepared_survival_data.rds`
- `06_analysis/output/prepared_growth_data.rds`
- `05_data/standardized/apal_disturbance_stressor_timeline.csv`

Lag exposure is built at `region_group x year` and attached to each colony interval by survey year.

## Exposure Construction

Disturbance events were expanded into annual exposure records using canonical region mapping and event year spans.

Three exposure families were modeled:

- `acute_exclusion`: events flagged as baseline-exclusion (or `acute_event`)
- `context_pressure`: non-exclusion chronic/biotic/framework pressure events
- `catastrophic`: events classified as catastrophic by intensity/impact rules

For each family, lags `l0..l3` were attached, then aggregated into:

- `recent` window: `l0 + l1`
- `delayed` window: `l2 + l3`

## Models

For each outcome, three models were fit:

1. `base`: size + interval controls only
2. `window`: recent/delayed lag windows
3. `unconstrained`: separate lag-0..lag-3 coefficients

All models include study-level random intercepts (`(1 | study)`).

## Primary Results

From `distributed_lag_model_comparison.csv`:

- Survival: unconstrained lag model strongly improved fit (`AIC 5010.6`) vs window (`5090.2`) and base (`5189.3`).
- Positive growth: unconstrained lag model improved fit (`6590.5`) vs window (`6611.4`) and base (`6746.1`).
- RGR: window model was best (`25687.9`), with unconstrained lags over-parameterized.

Key coefficient patterns:

- Survival:
  - `acute_l1` and `acute_l2` positive; `acute_l0` positive but smaller.
  - `catastrophic_l0` and `catastrophic_l1` strongly negative.
  - Context lag effects weaker and mixed.
- Positive growth:
  - `acute_l0` and `acute_l1` negative.
  - `acute_l2` positive rebound signal.
  - `catastrophic_l0` negative.
- RGR:
  - Lag effects are weaker than for binary outcomes; `context_recent` is modestly negative in the window model.

## Interpretation

The fitted lag structure is consistent with disturbance-memory dynamics:

- immediate catastrophic shocks depress survival/growth probability
- non-catastrophic acute events show a delayed association pattern (possible survivor/compositional effects and post-disturbance restructuring)
- chronic context pressure contributes more diffuse lag effects than sharp acute pulses

This is a substantial extension beyond standard GLMMs because it explicitly distinguishes contemporaneous and delayed disturbance signals in a unified panel framework.

## Diagnostics and Limitations

Observed warnings indicate expected stress points for high-dimensional lag random-effects models:

- rank deficiency in unconstrained lag terms
- near-singularity / identifiability warnings in some fits
- unstable estimates for sparse terms (notably `catastrophic_delayed`, `catastrophic_l3`)

Implications:

- treat catastrophic delayed coefficients as low-information
- prioritize window-model inference for robust interpretation where unconstrained terms are unstable
- consider penalized or Bayesian distributed-lag shrinkage in next iteration

Additional structural caveats:

- lag anchoring is by survey year (interval start), not full interval-integrated intensity
- region-level exposures may not capture micro-site heterogeneity in event intensity
- Florida-heavy panel composition still dominates inference

## Generated Artifacts

- `06_analysis/output/distributed_lag_year_region_exposure.csv`
- `06_analysis/output/distributed_lag_survival_panel.csv`
- `06_analysis/output/distributed_lag_growth_panel.csv`
- `06_analysis/output/distributed_lag_model_comparison.csv`
- `06_analysis/output/distributed_lag_survival_model_terms.csv`
- `06_analysis/output/distributed_lag_growth_model_terms.csv`
- `06_analysis/output/distributed_lag_effect_summary.csv`
- `06_analysis/output/distributed_lag_prediction_grid.csv`
- `06_analysis/figures/supplementary/distributed_lag_coefficients.png`
- `06_analysis/figures/supplementary/distributed_lag_coefficients.pdf`

## Next Iteration Recommendations

1. Replace unconstrained lag terms with penalized distributed-lag basis (e.g., Bayesian shrinkage in `brms`/`rstan`).
2. Couple lagged disturbance with size interaction terms (`lag x log_size`) under stronger regularization.
3. Add interval-integrated exposure weighting for multi-year intervals.
4. Expand to explicit event-family-specific models (hurricane, bleaching, disease) once sample support is sufficient.
