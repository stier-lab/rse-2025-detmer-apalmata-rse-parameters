# 46 Recurrent-Event / Dynamic Frailty Analysis

## Scope

This track implements a colony-panel, start-stop hazard framework that links:

- repeated shrinkage events (recurrent event process),
- disturbance-state exposure over time,
- and terminal mortality risk with time-varying shrinkage history.

The implementation is in [46_recurrent_event_frailty_model.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/46_recurrent_event_frailty_model.R).

## Data Basis

Inputs:

- [prepared_survival_data.rds](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/prepared_survival_data.rds)
- [prepared_growth_data.rds](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/prepared_growth_data.rds)

Constructed panel summary (from [recurrent_event_panel_summary.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_panel_summary.csv)):

- `n_rows = 7346` interval records
- `n_colonies = 2955`
- `n_studies = 7`, `n_regions = 7`
- `death_events = 1580`
- `shrinkage_intervals_observed = 5756`
- `shrinkage_events = 2208` (`38.36%` of observed shrinkage intervals)

## Model Design

### Model A: Recurrent Shrinkage Hazard

Outcome:

- recurrent shrinkage interval (`growth_metric < 0`) among intervals with observed growth.

Form:

- `coxph(Surv(start, stop, shrink_event) ~ log_size + disturbance_state + prior_shrink_events + population_type + frailty(colony_uid) + strata(study))`

### Model B: Terminal Mortality Hazard with Dynamic Shrinkage History

Outcome:

- interval-level death event (`survived == 0`) with one terminal event per colony.

Form:

- `coxph(Surv(start, stop, death_event) ~ log_size + disturbance_state + prior_shrink_events + recent_shrink_lag1 + prior_any_shrink + frailty(colony_uid) + strata(study))`

Both models converged with frailty (no fallback required), see [recurrent_event_model_fit.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_model_fit.csv).

## Key Results

### Recurrent Shrinkage (from [recurrent_event_shrinkage_model.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_shrinkage_model.csv))

- Larger size slightly increased recurrent shrinkage hazard (`HR = 1.043`, `p = 0.0053`).
- Higher prior shrinkage count reduced additional shrinkage hazard (`HR = 0.724`, `p < 1e-28`), consistent with event-history depletion/selection.
- Restoration fragments had higher recurrent shrinkage hazard than natural colonies (`HR = 2.053`, `p = 6.9e-05`).
- Disturbance-state contrasts were not significant after accounting for study strata and colony frailty.

### Terminal Mortality with Dynamic Shrinkage History (from [recurrent_event_mortality_model.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_mortality_model.csv))

- Larger size was strongly protective (`HR = 0.707`, `p < 1e-100`).
- Recent shrinkage in the immediately preceding interval increased mortality hazard (`HR = 1.654`, `p = 1.45e-05`).
- Prior shrinkage history terms (`prior_shrink_events`, `prior_any_shrink`) were associated with lower hazard conditional on surviving to later intervals, consistent with survivor selection.
- Disturbance-state coefficients were negative in this within-study, frailty-adjusted specification; interpret as conditional contrasts after dynamic covariates, not as causal protection from disturbance.

Dynamic empirical risk profiles are in [recurrent_event_dynamic_risk_profiles.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_dynamic_risk_profiles.csv).

## Output Inventory

- [recurrent_event_panel_summary.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_panel_summary.csv)
- [recurrent_event_colony_history.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_colony_history.csv)
- [recurrent_event_shrinkage_model.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_shrinkage_model.csv)
- [recurrent_event_mortality_model.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_mortality_model.csv)
- [recurrent_event_model_fit.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_model_fit.csv)
- [recurrent_event_dynamic_risk_profiles.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_dynamic_risk_profiles.csv)
- [recurrent_event_frailty_estimates.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_frailty_estimates.csv)

## Strengths

- Uses interval-censored panel timing (`start`, `stop`) rather than collapsing to single outcomes.
- Separates recurrent shrinkage process from terminal death process.
- Adds colony-level frailty to absorb unobserved heterogeneity beyond fixed covariates.
- Explicitly propagates time-varying shrinkage history into mortality risk.

## Limitations and Next Iteration Targets

- Disturbance exposure is interval-level and largely reconstructed from timeline overlays; event timing precision can be improved with site-specific environmental covariates.
- Growth is not observed for every survival interval; shrinkage-history covariates are therefore partially observed.
- Estimated frailty effects are not directly mappable to colony metadata in the current `coxph` frailty object export; the output file is retained as schema for future extraction refinement.
- A full joint model (shared random effects between recurrent shrinkage intensity and terminal death hazard) would be a stronger next step than separate Cox models.
