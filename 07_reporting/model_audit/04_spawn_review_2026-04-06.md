# Spawn Review 2026-04-06

This note consolidates the repo-wide review pass across the current working tree. The review focused on the maintained analysis surface, the current unpublished diff, diagnostic exports, figure freshness, and the manuscript-facing reporting layer.

## Audit method

- mapped the maintained repo surfaces from `README.md`, `06_analysis/README.md`, and `07_reporting/README.md`
- scanned the current diff with `git diff --stat`, `git diff --name-only`, and targeted unified diffs for the largest script changes
- verified that the modified R scripts still parse cleanly (`parse_failures=0`) and that the current diff is free of whitespace / patch-format problems (`git diff --check`)
- inspected the new diagnostic exports and the artifact freshness registry instead of relying only on prose reports

This pass did not re-run the full pipeline. Findings below therefore distinguish between code-state issues, reporting drift, and stale generated artifacts.

## Applied fixes in this pass

- Updated [43_stochastic_ipm_disturbance_model.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/advanced_models/43_stochastic_ipm_disturbance_model.md) so it now reflects the explicit recruitment scenarios already present in code and outputs.
- Updated [46_recurrent_event_frailty_model.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/advanced_models/46_recurrent_event_frailty_model.md) to surface the PH diagnostics output and frame the frailty-based `cox.zph` results more carefully.
- Updated [47_spatiotemporal_hierarchical_model.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/advanced_models/47_spatiotemporal_hierarchical_model.md) to mention the exported `k.check` diagnostics and the remaining survey-year smooth warning.

## Findings

### 1. DHW support is labeled too optimistically relative to the independent support actually available

Files:
- `06_analysis/scripts/08_climate_demography.R:147-165`
- `06_analysis/scripts/32_disturbance_survival_analysis.R:199-216`
- `06_analysis/output/climate_dhw_coverage.csv`
- `06_analysis/output/climate_dhw_glmm.csv`

What the code does:
- assigns `inference_support = "moderate"` once the number of matched rows reaches 500
- does not use the number of independent study-region-year cells, studies, or regions to determine that label

Why this matters:
- `climate_dhw_coverage.csv` shows `1746` matched survival rows, but only `10` unique study-region-year rows with DHW support
- `climate_dhw_glmm.csv` shows the fitted subset is effectively only `2` studies and `2` regions
- the current label can therefore read as if the climate signal has moderate independent support when it is mostly Florida-weighted row-level reuse

Recommended fix:
- compute support tiers from independent support units first, not raw rows
- keep both row-level and cluster-level counts in the export
- downgrade the headline support label unless study / region / study-year coverage clears a stricter threshold

### 2. The stochastic-IPM diagnostics file currently overloads model-fit columns with recruitment metadata

Files:
- `06_analysis/scripts/43_stochastic_ipm_disturbance_model.R:261-286`
- `06_analysis/output/stochastic_ipm_model_diagnostics.csv`

What the code does:
- appends recruitment-scenario rows to `stochastic_ipm_model_diagnostics.csv`
- stores `annual_recruits_per_mature_colony` inside the `aic` column
- stores a settlement-survival product inside the `deviance_explained` column

Why this matters:
- downstream readers or scripts can misread those rows as actual GAM fit diagnostics
- the resulting CSV now mixes two incompatible schemas in one table

Recommended fix:
- split recruitment assumptions into a dedicated tidy output, or
- add properly named columns and an explicit row type field instead of overloading `aic` and `deviance_explained`

### 3. The frailty PH diagnostics export reports global test values that are not reliable enough to summarize at face value

Files:
- `06_analysis/scripts/46_recurrent_event_frailty_model.R:151-182`
- `06_analysis/output/recurrent_event_ph_diagnostics.csv`

What the code does:
- runs `cox.zph()` directly on the frailty fits and exports both the global row and the worst term

Why this matters:
- the exported global rows have non-integer effective degrees of freedom (`462.94` and `9.59`)
- one global p-value is `1` even though the worst term (`prior_shrink_events`) is extremely small in both models
- this is a classic sign that the penalized-frailty summary is not behaving like a simple unpenalized PH diagnostic

Recommended fix:
- suppress or explicitly flag global PH summaries as non-comparable for frailty fits
- retain the term-level flags
- if this layer becomes manuscript-central, revisit `prior_shrink_events` with time-varying effects or a different recurrent-event parameterization

### 4. The advanced-model reporting layer had drifted behind the current code and outputs

Files:
- `07_reporting/advanced_models/43_stochastic_ipm_disturbance_model.md`
- `07_reporting/advanced_models/46_recurrent_event_frailty_model.md`
- `07_reporting/advanced_models/47_spatiotemporal_hierarchical_model.md`
- `06_analysis/output/stochastic_ipm_simulation_summary.csv`
- `06_analysis/output/recurrent_event_ph_diagnostics.csv`
- `06_analysis/output/spatiotemporal_survival_kcheck.csv`

What drifted:
- the stochastic IPM report still said there was no explicit recruitment term
- the recurrent-event report did not mention the new PH-diagnostics output
- the spatiotemporal report did not mention the newly exported `k.check` files or the time-smooth warning

Fix applied:
- those three reporting documents were updated in this pass

### 5. The freshness machinery correctly detects stale artifacts, but the generated prose summary is not specific enough to tell the reader which ones

Files:
- `07_reporting/generated/pipeline_refresh_report.md`
- `06_analysis/output/canonical_artifact_status.csv`
- `06_analysis/output/pipeline_artifact_freshness.csv`

Evidence:
- `pipeline_refresh_report.md` reports one stale disturbance result and one stale supplementary figure
- the machine-readable registry identifies those specific stale artifacts as:
  - `06_analysis/output/disturbance_size_survival_model.csv`
  - `06_analysis/figures/supplementary/FigS17_disturbance_size_interaction.png`

Why this matters:
- the refresh summary is easy to skim, but it still requires a second file open to identify the stale products

Recommended fix:
- add a short stale-artifact list to `pipeline_refresh_report.md` or the generated markdown mirror of `canonical_artifact_status.csv`

### 6. The spatiotemporal survival model still has a mild basis-dimension warning that should stay visible in interpretation

Files:
- `06_analysis/output/spatiotemporal_survival_kcheck.csv`
- `07_reporting/advanced_models/47_spatiotemporal_hierarchical_model.md`

Evidence:
- `spatiotemporal_survival_kcheck.csv` reports `p = 0.0425` for `s(survey_year_num)` in the spatiotemporal survival fit

Interpretation:
- this is not a crash-level problem, but it is enough to keep the temporal smooth in the support-only bucket until a slightly larger `k`, blocked CV, and residual spatial checks are explored

Recommended fix:
- test a larger basis for the survival year smooth
- add blocked validation and residual spatial-autocorrelation checks before promoting this layer

## Strongest surfaces in the current repo state

- The modified R scripts parse cleanly, and the current diff has no `git diff --check` failures.
- The transition-matrix layer is well-instrumented after the new diagnostics additions:
  - `transition_matrix_model_diagnostics.csv`
  - `transition_matrix_imputation_sensitivity.csv`
- The expanded meta-analysis layer now has a materially better review surface:
  - `expanded_meta_primary_model_diagnostics.csv`
  - `expanded_meta_moderator_diagnostics.csv`
  - `expanded_meta_primary_jackknife.csv`
- The artifact registry and freshness outputs are doing useful work. They surfaced the stale `FigS17` branch immediately without manual guesswork.

## Weakest surfaces in the current repo state

- DHW-supported inference remains thin in terms of independent support, even after the overlay work.
- The stochastic IPM remains useful as an exploratory viability extension, but its recruitment layer is still scenario scaffolding rather than an empirically calibrated demographic component.
- The recurrent-event frailty layer is informative, but its PH diagnostics need more careful framing than the current raw export provides.
- The spatiotemporal layer has the right diagnostics directionally, but it still needs blocked validation and residual structure checks before it can move beyond support analysis.

## Bottom line

The current unpublished pass mostly improves diagnostics, caution flags, and audit traceability rather than introducing obvious syntax-level breakage. The main remaining issues are not broken code paths; they are support mislabeling, mixed-schema diagnostics output, advanced-model reporting drift, and a few places where the diagnostics should constrain interpretation more explicitly than they do now.
