# 42. Joint Longitudinal-Survival Model (First-Pass)

## Objective
Link colony live-tissue trajectory to subsequent mortality risk in a reproducible framework that extends beyond standard GLMMs.

## Data and Scope
- Inputs:
  - `06_analysis/output/prepared_survival_data.rds`
  - `06_analysis/output/prepared_growth_data.rds`
- Analysis sample after filtering:
  - `7,267` interval records
  - `2,899` unique colonies
  - `6` studies
  - Event rate (`dead = 1`): `21.7%`

## Modeling Strategy
Because dedicated joint-model packages (`JMbayes2`, `JM`, `joineR`) were not installed in this environment, this analysis uses a two-stage joint approximation:

1. **Stage 1 (Longitudinal process):**
   - `nlme::lme` for `log(live_size + 1)`
   - Fixed effects: `year_center + year_center^2 + disturbance_state + pop_type`
   - Random structure attempted: `(1 + year_center | coral_id)`
   - Numerical instability detected (`singular precision matrix`), so the script downgraded to `(1 | coral_id)` and records this downgrade.

2. **Stage 2 (Survival process):**
   - Discrete-time hazard model with complementary log-log link and interval offset:
     - `dead ~ z_pred_log_live + z_pred_velocity + disturbance_state + pop_type + z_year + region + offset(log_dt)`
   - Preferred engine: `glmmTMB` with random intercepts for `coral_id` and `study` (used successfully in this run).
   - Dynamic markers from Stage 1:
     - `pred_log_live_start` (latent size state at interval start)
     - `pred_log_live_velocity` (latent trajectory velocity over interval)

## Main Results
- Fit and discrimination:
  - AUC: `0.816`
  - Brier score: `0.131`
- Key joint terms (`06_analysis/output/joint_longitudinal_key_results.csv`):
  - `z_pred_log_live`: estimate `-0.797`, HR `0.451`, p `< 1e-75`
    - Larger latent live-size state strongly lowers hazard.
  - `z_pred_velocity`: estimate `5.380`, HR `217.0`, p `< 1e-21`
    - Very large positive association; interpretation is unstable in this first-pass specification and should not be treated as causal.
- Calibration (`joint_longitudinal_calibration_by_decile.csv`):
  - Risk deciles separate well, but top-decile observed mortality (`0.726`) exceeds predicted (`0.550`), indicating underprediction in extreme-risk intervals.

## Output Files
- `06_analysis/output/joint_longitudinal_model_coefficients.csv`
- `06_analysis/output/joint_longitudinal_fit_metrics.csv`
- `06_analysis/output/joint_longitudinal_calibration_by_decile.csv`
- `06_analysis/output/joint_longitudinal_key_results.csv`
- `06_analysis/output/joint_longitudinal_interval_predictions.csv`
- `06_analysis/figures/supplementary/joint_longitudinal_risk_curve.png`

## Assumptions and Limitations
- This is a **two-stage approximation**, not a full Bayesian/shared-likelihood joint model.
- Stage-1 random slope was not numerically stable in this dataset; latent velocity therefore has reduced subject-specific fidelity.
- Disturbance categories are sparse in some strata (e.g., pollution), producing unstable coefficients with very large uncertainty.
- Study composition remains Florida-heavy; temporal and disturbance effects reflect that mixture.
- Interval mortality is modeled in discrete time with variable interval length offset; this is appropriate for current data structure but still an approximation to continuous hazard.

## Recommended Iteration Path
1. Refit Stage 1 with structured random slopes in a reduced/regularized subset (e.g., colonies with >=3 intervals), then project latent states to full data.
2. Replace categorical disturbance terms with harmonized tier/intensity variables to reduce sparse-cell instability.
3. If package installation becomes available, migrate this script to a true joint likelihood (`JMbayes2`) for tighter uncertainty propagation.
