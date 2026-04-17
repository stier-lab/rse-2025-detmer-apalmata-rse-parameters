# 41 Multistate Transition Model

## Objective
Build a first-pass multistate demographic model for *Acropora palmata* that goes beyond static transition counts by explicitly modeling:
- interval-adjusted death risk (`SC1-SC5 -> Dead`)
- conditional alive transitions (`SC1-SC5 -> SC1-SC5`)
- backward movement (retrogression) alongside stasis and forward transitions

## Data and Construction
Script: `06_analysis/scripts/41_multistate_transition_model.R`  
Inputs:
- `06_analysis/output/prepared_survival_data.rds`
- `06_analysis/output/prepared_growth_data.rds`

Filtering and harmonization:
- Natural colonies only (matching existing transition-matrix logic)
- Near-annual intervals retained (`0.5-1.5` years)
- Canonical state definition reused from project constants: `SC1-SC5` by live tissue area (`size_for_class`)
- Alive transition endpoint uses `size_final_cm2 = size_for_class + growth_metric * time_interval_yr`

Panels used:
- Survival panel: `n = 5,508` intervals
- Alive-transition panel (growth-linked survivors): `n = 4,388` intervals
- Studies represented after filtering: `3`

## Model Specification
1. Death hazard model:
- `glmer` with complementary log-log link and `offset(log(time_interval_yr))`
- Formula: `dead ~ state_from + disturbance_any + geo_domain + (1|study) + offset(log(interval))`
- Purpose: approximate annualized hazard while respecting uneven interval duration

2. Alive transition model:
- `nnet::multinom` for `state_to_alive`
- Formula: `state_to_alive ~ state_from + disturbance_any + geo_domain + log_interval`
- Mild ridge regularization (`decay = 1e-3`) used to reduce separation instability

3. Matrix composition:
- Annual transition matrix over `SC1-SC5 + Dead`:
  - `P(to alive state j | from i) = S_i * T_ij`
  - `P(Dead | from i) = 1 - S_i`
  - `Dead` absorbing (`Dead -> Dead = 1`)

## Run Status
Executed successfully with current environment (`glmerMod` + `multinom`).  
All expected `multistate_*` outputs were written to `06_analysis/output/`.

## Key Outputs
- `multistate_dataset_summary.csv`
- `multistate_survival_model_coefficients.csv`
- `multistate_alive_transition_model_coefficients.csv`
- `multistate_survival_state_predictions.csv`
- `multistate_alive_transition_predictions.csv`
- `multistate_transition_matrix_annual.csv`
- `multistate_transition_matrix_annual_wide.csv`
- `multistate_retrogression_metrics.csv`
- `multistate_observed_alive_transition_counts.csv`
- `multistate_observed_death_by_state.csv`
- `multistate_model_diagnostics.csv`

## First-Pass Findings
Reference scenario (`disturbance = none`, `geo_domain = Florida`, annual interval):
- Predicted annual death probabilities:
  - `SC1: 0.0789`
  - `SC2: 0.0458`
  - `SC3: 0.0294`
  - `SC4: 0.0139`
  - `SC5: 0.00718`

Conditional retrogression probabilities (`given alive`):
- `SC2: 0.00363`
- `SC3: 0.0849`
- `SC4: 0.142`
- `SC5: 0.0505`

Matrix validity check:
- All from-state columns sum to `1.0` in `multistate_transition_matrix_annual_wide.csv`.

## Limitations in This Iteration
1. Sparse SC1 transition sample:
- Alive-transition panel has only `43` SC1 observations, so SC1 destination probabilities are high-uncertainty.

2. Limited spatial/study breadth after strict filters:
- Effective model support is from 3 studies and heavily Florida-dominated domain structure.

3. Conditional transition model has no random effects:
- `multinom` does not natively include study-level random intercepts here; clustering is only partially handled through covariates and regularization.

4. Disturbance simplification:
- Disturbance was collapsed to `none` vs `any` to avoid sparse-category separation in this first pass.

## Recommended Next Iteration
1. Move to a hierarchical Bayesian multinomial transition model (study random effects, partial pooling across sparse states).
2. Add cluster bootstrap by study for interval estimates on composed matrix elements.
3. Expand regime structure from `none/any` to richer disturbance states once sample support is sufficient.
4. Test full-range interval handling (beyond `0.5-1.5`) with explicit continuous-time transition assumptions.
