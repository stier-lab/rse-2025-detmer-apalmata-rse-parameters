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

- `coxph(Surv(start, stop, shrink_event) ~ log_size + disturbance_state + prior_shrink_events + prior_shrink_events:log_time_mid + population_type + frailty(colony_uid) + strata(study))`

### Model B: Terminal Mortality Hazard with Dynamic Shrinkage History

Outcome:

- interval-level death event (`survived == 0`) with one terminal event per colony.

Form:

- `coxph(Surv(start, stop, death_event) ~ log_size + disturbance_state + prior_shrink_events + prior_shrink_events:log_time_mid + recent_shrink_lag1 + prior_any_shrink + frailty(colony_uid) + strata(study))`

Both models converged with frailty (no fallback required), see [recurrent_event_model_fit.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_model_fit.csv).

PH-screening output is now also exported in [recurrent_event_ph_diagnostics.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_ph_diagnostics.csv).
The current frailty fits treat the main PH stress point as a modeled time-varying effect: `prior_shrink_events` is paired with `prior_shrink_events:log_time_mid`, and the diagnostics file now records `time_varying_prior_shrink_modeled` rather than pretending that a global `cox.zph` summary is the main interpretive object for these transformed frailty fits.

## Key Results

### Recurrent Shrinkage (from [recurrent_event_shrinkage_model.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_shrinkage_model.csv))

- Larger size slightly increased recurrent shrinkage hazard (`HR = 1.038`, `p = 0.0013`).
- The shrinkage-history effect is now explicitly time-varying: the main `prior_shrink_events` term is positive early in follow-up (`HR = 1.296`, `p = 7.7e-05`), while `prior_shrink_events:log_time_mid` is negative (`HR = 0.861`, `p = 8.0e-06`), consistent with attenuation through time rather than a single PH-stable coefficient.
- Restoration fragments had higher recurrent shrinkage hazard than natural colonies (`HR = 1.966`, `p = 2.3e-05`).
- Disturbance-state contrasts were not significant after accounting for study strata and colony frailty.

### Terminal Mortality with Dynamic Shrinkage History (from [recurrent_event_mortality_model.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_mortality_model.csv))

- Larger size was strongly protective (`HR = 0.707`, `p < 1e-100`).
- Recent shrinkage in the immediately preceding interval increased mortality hazard (`HR = 1.563`, `p = 2.0e-04`).
- `prior_shrink_events` is now modeled as a time-varying history term: the main effect is weak near zero time (`HR = 1.167`, `p = 0.374`), while the interaction with `log_time_mid` is negative (`HR = 0.845`, `p = 0.0367`), implying a declining hazard contribution through follow-up.
- `prior_any_shrink` remained protective conditional on survival to later intervals (`HR = 0.335`, `p = 5.1e-12`), consistent with survivor selection among previously stressed colonies.
- Disturbance-state coefficients were negative in this within-study, frailty-adjusted specification; interpret as conditional contrasts after dynamic covariates, not as causal protection from disturbance.

Dynamic empirical risk profiles are in [recurrent_event_dynamic_risk_profiles.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_dynamic_risk_profiles.csv).

## Diagnostics note

- `recurrent_event_ph_diagnostics.csv` now records `time_varying_prior_shrink_modeled` for both outcomes.
- The relevant review question is no longer “did `prior_shrink_events` fail a PH screen?” but “does the fitted log-time interaction materially change interpretation?”
- These models remain useful as structured hazard summaries, but the shrinkage-history terms should still be treated as support analysis rather than final causal dynamics.

## Output Inventory

- [recurrent_event_panel_summary.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_panel_summary.csv)
- [recurrent_event_colony_history.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_colony_history.csv)
- [recurrent_event_shrinkage_model.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_shrinkage_model.csv)
- [recurrent_event_mortality_model.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_mortality_model.csv)
- [recurrent_event_model_fit.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_model_fit.csv)
- [recurrent_event_ph_diagnostics.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_ph_diagnostics.csv)
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
- The current implementation already uses a time-varying shrink-history effect, but recurrent shrinkage remains sensitive to how that history term is parameterized; if this layer is promoted beyond support analysis, a fuller recurrent-event framework would still be preferable.
- A full joint model (shared random effects between recurrent shrinkage intensity and terminal death hazard) would be a stronger next step than separate Cox models.
