# Consolidated Review 2026-04-06

This document supersedes the raw spawned note in
[04_spawn_review_2026-04-06.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/model_audit/04_spawn_review_2026-04-06.md)
for current-state review. It reflects the post-fix repo state after targeted
script reruns and refresh-audit regeneration.

## Scope

- spawned parallel reviewers across early/core models, synthesis, disturbance,
  advanced models, and reporting/traceability
- mapped the maintained repo surfaces from `README.md`, `06_analysis/README.md`,
  and `07_reporting/README.md`
- checked the working diff, parsed modified R scripts, and verified
  `git diff --check`
- reran targeted scripts whose outputs were stale relative to code fixes:
  `08`, `10`, `12`, `14b`, `19`, `22`, `23`, `26`, `29`, `30`, `31`, `32`,
  `43`, `46`, `47`, and `48`, plus a direct refresh of the new matrix leverage
  diagnostics tied to `13`

## Applied Fixes In This Pass

1. **DHW support classification is now cluster-aware, not row-count-only.**
   Files:
   [08_climate_demography.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/08_climate_demography.R),
   [32_disturbance_survival_analysis.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/32_disturbance_survival_analysis.R)
   Refreshed outputs:
   [climate_dhw_coverage.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/climate_dhw_coverage.csv),
   [climate_dhw_glmm.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/climate_dhw_glmm.csv),
   [disturbance_dhw_coverage.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/disturbance_dhw_coverage.csv),
   [disturbance_survival_glmm.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/disturbance_survival_glmm.csv)
   Outcome:
   DHW support is now `sparse` for the current 2-study / 2-region / 10-study-year subset, and DHW p-values are suppressed in the sparse-support exports.

2. **The expanded-meta parent-study jackknife no longer duplicates split parents.**
   File:
   [14b_expanded_meta_analysis.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/14b_expanded_meta_analysis.R)
   Refreshed output:
   [expanded_meta_primary_jackknife.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/expanded_meta_primary_jackknife.csv)
   Outcome:
   the jackknife now has one row per parent study (`17` rows), rather than repeating `NOAA_survey`, `vardi_2011`, and `garrison_ward_2008`.

3. **The Florida Keys size-matched export now reports the correct model class.**
   File:
   [29_natural_vs_restoration.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/29_natural_vs_restoration.R)
   Refreshed output:
   [natural_vs_restoration_size_matched.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/natural_vs_restoration_size_matched.csv)
   Outcome:
   `model_class` is now `glm`, matching the descriptive model actually exported.

4. **Invalid two-cluster robust tables are no longer printed as if they were usable inference.**
   File:
   [29_natural_vs_restoration.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/29_natural_vs_restoration.R)
   Outcome:
   the script now suppresses printed cluster-robust coefficient tables in the known two-study Florida Keys case, keeping the console narrative aligned with the descriptive-only framing.

5. **The disturbance-size interaction layer now emits diagnostics instead of aborting.**
   File:
   [37_disturbance_size_interaction.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/37_disturbance_size_interaction.R)
   Output:
   [disturbance_size_model_diagnostics.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/disturbance_size_model_diagnostics.csv)
   Outcome:
   the diagnostics helper no longer collides with tidy evaluation on `model`, and the diagnostics export is now present.

6. **The disturbance timeline and DHW overlay outputs were regenerated from the patched script.**
   File:
   [32_disturbance_survival_analysis.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/32_disturbance_survival_analysis.R)
   Refreshed figure:
   [FigSXX_disturbance_timeline.png](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/figures/supplementary/FigSXX_disturbance_timeline.png)
   Outcome:
   the current disturbance timeline and DHW outputs now reflect the patched figure builder and the sparse-support DHW framing.

7. **The stochastic IPM diagnostics export now has an explicit mixed-row schema.**
   File:
   [43_stochastic_ipm_disturbance_model.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/43_stochastic_ipm_disturbance_model.R)
   Refreshed output:
   [stochastic_ipm_model_diagnostics.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/stochastic_ipm_model_diagnostics.csv)
   Outcome:
   the file now uses `row_type` plus dedicated recruitment columns instead of overloading `aic` and `deviance_explained`.

8. **Traceability docs were corrected for dead-path drift.**
   File:
   [claim_output_crosswalk.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/claim_output_crosswalk.md)
   Outcome:
   the dead `publication/allometry_analysis.png` reference was removed, and `recommend_studies.csv` was corrected to
   [recommended_studies.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recommended_studies.csv).

9. **The refresh audit was rerun after the targeted fixes.**
   File:
   [48_pipeline_refresh_audit.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/48_pipeline_refresh_audit.R)
   Refreshed outputs:
   [canonical_artifact_status.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/canonical_artifact_status.csv),
   [pipeline_refresh_report.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/generated/pipeline_refresh_report.md)

10. **The disturbance sensitivity summary now uses the intended no-context Neely subset.**
    File:
    [30_disturbance_sensitivity.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/30_disturbance_sensitivity.R)
    Refreshed output:
    [disturbance_sensitivity_summary.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/disturbance_sensitivity_summary.csv)
    Outcome:
    the “Excluding all timeline-linked context” scenario now uses the corrected Neely filter path in code; the current output correctly drops to `k = 1` and therefore no longer tries to overstate that scenario as a multi-study meta-analysis.

11. **Frailty PH handling is now specification-level, not export-only.**
    File:
    [46_recurrent_event_frailty_model.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/46_recurrent_event_frailty_model.R)
    Refreshed output:
    [recurrent_event_model_fit.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_model_fit.csv),
    [recurrent_event_ph_diagnostics.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/recurrent_event_ph_diagnostics.csv)
    Outcome:
    both frailty fits now model `prior_shrink_events` with an explicit `log_time_mid` interaction, so the strongest PH stress point is handled in the specification itself; the diagnostics export now reports `time_varying_prior_shrink_modeled` rather than presenting face-value global `cox.zph` summaries for frailty fits.

12. **The spatiotemporal layer now has an upgraded temporal specification plus external diagnostics.**
    File:
    [47_spatiotemporal_hierarchical_model.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/47_spatiotemporal_hierarchical_model.R)
    Refreshed outputs:
    [spatiotemporal_survival_kcheck.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/spatiotemporal_survival_kcheck.csv),
    [spatiotemporal_growth_kcheck.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/spatiotemporal_growth_kcheck.csv),
    [spatiotemporal_region_blocked_cv.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/spatiotemporal_region_blocked_cv.csv),
    [spatiotemporal_spatial_residual_check.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/spatiotemporal_spatial_residual_check.csv),
    [spatiotemporal_spatial_predictions.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/spatiotemporal_spatial_predictions.csv)
    Outcome:
    survival now combines a higher-flexibility year smooth with a year-level random effect, the positive-growth model uses year-level heterogeneity rather than forcing an unsupported smooth, survival `k.check` no longer flags the year term (`p = 0.4875`), residual spatial dependence is now checked explicitly, region-blocked CV is exported, and the spatial prediction export remains join-safe.

13. **The refresh registry now tracks the diagnostics layer as canonical artifacts.**
    File:
    [01_functions.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/utils/01_functions.R)
    Refreshed outputs:
    [canonical_artifact_registry.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/canonical_artifact_registry.csv),
    [pipeline_refresh_report.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/generated/pipeline_refresh_report.md)
    Outcome:
    the registry now includes the new diagnostics outputs (`77` artifacts total), and the generated refresh report shows a dedicated `diagnostics` category with no stale or missing artifacts.

14. **The growth comparison layer now distinguishes the script-04 inflection from the manuscript threshold.**
    File:
    [23_verification.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/23_verification.R)
    Outcome:
    the `853 cm2` value from `04_growth_rate_comparison.R` is now labeled as an “RGR allometry inflection” rather than a manuscript growth threshold.

15. **The CV layer now validates the threshold workflow rather than only linear baselines.**
    File:
    [10_cross_validation.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/10_cross_validation.R)
    Refreshed outputs:
    [cross_validation_results.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/cross_validation_results.csv),
    [cv_performance_summary.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/cv_performance_summary.csv),
    [cv_model_comparison.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/cv_model_comparison.csv),
    [cv_growth_model_comparison.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/cv_growth_model_comparison.csv)
    Outcome:
    the main CV outputs now target the threshold hinge model, add imbalance-robust metrics (`PR-AUC`, balanced accuracy), and compare nonlinear candidates rather than only simple linear/logistic baselines.

16. **The model-selection layer is now explicitly split between baseline reference tables and manuscript-aligned workflow summaries.**
    File:
    [12_model_selection.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/12_model_selection.R)
    Refreshed outputs:
    [model_summary_table.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/model_summary_table.csv),
    [model_selection_workflow_alignment.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/model_selection_workflow_alignment.csv)
    Outcome:
    the classical AIC/BIC tables are now labeled as `classical_baseline_reference`, while the retained threshold/GAM workflow is summarized separately in a manuscript-facing alignment file.

17. **The transition-matrix leverage surface is now explicit at the source level.**
    File:
    [13_transition_matrix.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/13_transition_matrix.R)
    Refreshed outputs:
    [transition_matrix_model_diagnostics.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/transition_matrix_model_diagnostics.csv),
    [transition_matrix_source_leverage.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/transition_matrix_source_leverage.csv)
    Outcome:
    the matrix layer now exports direct source concentration metrics: current SC5 survival support is `83.2%` NOAA and fragmentation support is `100%` Vardi, so the leverage boundary is no longer an implicit reviewer-only concern.

18. **The disturbance-sensitivity layer now exports scenario guardrails instead of leaving them implicit.**
    File:
    [30_disturbance_sensitivity.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/30_disturbance_sensitivity.R)
    Refreshed outputs:
    [disturbance_sensitivity_scenario_status.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/disturbance_sensitivity_scenario_status.csv),
    [disturbance_sensitivity_influence.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/disturbance_sensitivity_influence.csv)
    Outcome:
    the scenario layer now makes retained support explicit (`k`, retained records, retained disturbance burden, delta vs all-data) and exports leave-one-study-out pooled-survival shifts, so the small-`k` / leverage structure is inspectable rather than reviewer-implied.

19. **The legacy heat-stress overlay now obeys the maintained sparse-support framing.**
    File:
    [31_heat_stress_overlay.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/31_heat_stress_overlay.R)
    Refreshed outputs:
    [heat_stress_model_diagnostics.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/heat_stress_model_diagnostics.csv),
    [heat_stress_survival_analysis.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/heat_stress_survival_analysis.csv)
    Outcome:
    the script now prefers the verified DHW cache, classifies support by studies/regions/study-years, suppresses inferential p-values when support is sparse, and treats the moderator layer as descriptive support rather than as a primary climate-attribution result.

20. **Figure 2 no longer refits threshold GAMs inline.**
    File:
    [19_fig2_demographic_rates.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/19_fig2_demographic_rates.R)
    Refreshed figure:
    [Fig2_demographic_rates.png](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/figures/manuscript/Fig2_demographic_rates.png)
    Outcome:
    the manuscript demographic-rates figure now reads the canonical threshold model objects and prediction grids from `02`/`03`, reducing figure-level model drift.

21. **Figure 4 now pulls leverage annotations from the leverage export rather than hardcoded text.**
    File:
    [22_fig6_population_model.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/22_fig6_population_model.R)
    Refreshed figure:
    [Fig4_population_model.png](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/figures/manuscript/Fig4_population_model.png)
    Outcome:
    the population-model figure now reads [transition_matrix_source_leverage.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/transition_matrix_source_leverage.csv) directly, so the NOAA/Vardi dependence shown in the figure stays synchronized with the current matrix diagnostics.

22. **Supplementary meta-analysis figures now hard-read the expanded moderator output.**
    File:
    [26_supp_S8_S9.R](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/26_supp_S8_S9.R)
    Refreshed figures:
    [FigS8_forest_plots.png](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/figures/supplementary/FigS8_forest_plots.png),
    [FigS9_heterogeneity.png](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/figures/supplementary/FigS9_heterogeneity.png)
    Outcome:
    the supplementary meta-analysis figure script now fails fast if the expanded moderator surface is missing instead of silently falling back to the legacy moderator file.

## Remaining Structural Limits

1. **The transition-matrix layer still depends on sparse upper-size sources, but that dependency is now explicit rather than hidden.**
   Evidence:
   [transition_matrix_model_diagnostics.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/transition_matrix_model_diagnostics.csv),
   [transition_matrix_source_leverage.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/transition_matrix_source_leverage.csv),
   [transition_matrix_imputation_sensitivity.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/transition_matrix_imputation_sensitivity.csv)
   Read:
   this is now a documented data limit, not an untracked model bug. SC5 survival remains NOAA-heavy and fragmentation remains single-study.

2. **Climate attribution is still support-limited by sparse DHW coverage.**
   Evidence:
   [climate_dhw_coverage.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/climate_dhw_coverage.csv),
   [disturbance_dhw_coverage.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/disturbance_dhw_coverage.csv)
   Read:
   the DHW layer is now safely labeled descriptive, but the underlying support remains thin and should stay out of strong attribution language.

## Current Read On The Repo

- The repo is materially stronger than the raw diff suggested at the start of the review.
- The highest-value fixes in this pass were support reclassification, model-specification repair, external diagnostics, and artifact refresh.
- The previously open frailty, spatiotemporal, and CV/model-selection issues are now addressed at the code/output level.
- Figure-source drift is materially reduced on the maintained manuscript/supplementary surfaces that were still refitting or hardcoding live values.
- The remaining risks are structural evidence limits:
  thin DHW support and concentrated matrix leverage.
- Hand-maintained reporting prose is still a residual drift risk even after point fixes.

## Suggested Next Sequence

1. Keep matrix and lambda claims paired with [transition_matrix_source_leverage.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/transition_matrix_source_leverage.csv) and the imputation sensitivity export anywhere they appear in manuscript-facing prose.
2. Keep DHW/climate language descriptive unless new covariate coverage is added.
3. If a fully coherent end-to-end rerun is needed for release, rerun the whole pipeline from the current code state rather than mixing earlier and refreshed artifacts, but that is now a release-freeze operation rather than an open statistical QA issue.
