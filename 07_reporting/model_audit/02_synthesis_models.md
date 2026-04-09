# Synthesis and Matrix Model Audit

Scope: scripts `13` through `30` in `06_analysis/scripts`.

This section covers the matrix model, meta-analysis, heterogeneity and
sensitivity layers, the figure scripts that consume them, and the
natural-vs-restoration and disturbance-sensitivity syntheses.

## Overall

The synthesis layer is analytically rich. The dominant remaining risks are now
structural leverage and interpretive discipline, not hidden figure-source drift:
the maintained figure scripts that were still refitting or reading legacy
surfaces now pull from canonical outputs directly.

## Script-Level Issues

| Script | Model family / role | Diagnostics already present | Remaining issues a statistician would care about |
|---|---|---|---|
| `13_transition_matrix.R` | Deterministic matrix model with hierarchical bootstrap | Bootstrap CIs, failure analysis, lambda diagnostics, transition sample sizes, elasticity outputs, fragmentation/fecundity sensitivity, matrix diagnostics CSV, and explicit imputation-vs-discard / fragmentation leverage exports | The leverage picture is now much clearer in one place. Remaining concerns are structural rather than hidden: SC5 survival is still NOAA-heavy and fragmentation is still Vardi-heavy. |
| `14_meta_analysis.R` | Legacy small-`k` random-effects meta-analysis | Forest/funnel plots, heterogeneity tables, tau-estimator comparison, trim-and-fill, LOO, moderator outputs | Best treated as a legacy/check analysis. Heterogeneity is extreme and the natural-vs-restoration stratification is not defensible as a primary inferential layer. |
| `14b_expanded_meta_analysis.R` | Primary three-level meta-analysis | Multilevel pooled effects, PI, tau/I² outputs, tier/classification sensitivity, trim-fill, RoB sensitivity, independent-model LOO/influence files, primary-model jackknife and diagnostics CSVs, and cluster-aware moderator diagnostics | The primary inferential surface is now internally consistent. The remaining issue is interpretation, not missing diagnostics: publication-bias products still come from the independent-effects model and should stay labeled as a sensitivity layer rather than blended into the primary three-level inference. |
| `15_heterogeneity_analysis.R` | Study-level heterogeneity exploration | Study effect sizes, moderator analyses, subgroup heterogeneity summaries | Conceptual drift is the problem. This duplicates parts of `14b` and mixes formal meta-analysis with ad hoc CV-style heterogeneity proxies. |
| `16_sensitivity_analysis.R` | Matrix robustness and scenario sensitivity | LOO, outlier, boundary, interval-length, geographic, bootstrap, fragmentation-allocation outputs | Fallback-to-full-data imputation softens the interpretation of robustness. Report imputed and no-imputation variants side by side. |
| `17_update_parameter_lists.R` | Parameter packaging / priors layer | Parameter bundles and console summaries | Needs machine-readable QA. Parameters that come from proxies or priors should be exported with provenance flags, not silently bundled. |
| `18`–`21`, `23_figS2_data_gaps.R` | Figure/display layer around study landscape and rate summaries | Descriptive summaries and figure products | These should be pure readers of validated outputs where possible. Refit logic should live upstream, not inside figure scripts. |
| `19_fig2_demographic_rates.R` | Manuscript figure for demographic rates | Canonical threshold-model objects and prediction grids from `02`/`03`, plus figure outputs and fit summaries | The maintained figure now reads canonical model objects instead of refitting GAMs inline. The remaining risk is maintenance discipline, not a live code-path mismatch. |
| `22_fig6_population_model.R` | Manuscript figure for the population model | Transition matrix, elasticity decomposition, bootstrap and LOSO panels, plus live leverage annotation from `transition_matrix_source_leverage.csv` | Fragmentation is now treated as a non-additive overlay and the figure reads leverage annotations from the diagnostics export. The remaining issue is caption/interpretation discipline, not hidden hardcoding. |
| `24`–`28` | Supplementary figure layer | Publication-ready figures based on upstream outputs | Source assertions are stronger now. In particular, `26` hard-reads `expanded_meta_analysis_moderators.csv` instead of falling back to the legacy moderator file. |
| `23_verification.R` | Canonical-statistics QA layer | Canonical statistics CSV, assertion table, all-current assertions passing | Still a soft QA layer. Critical assertions should hard-fail, and brittle hard-coded counts should become version-aware regression checks. |
| `29_natural_vs_restoration.R` | Within-region meta-analysis + Florida Keys size-matched comparison | Meta-analytic regional contrasts, overdispersion checks, size-class summaries, model diagnostics CSV | The Florida Keys size-matched model has only two studies and perfect study/population confounding. It should be treated as descriptive only, not as valid small-cluster inference. |
| `30_disturbance_sensitivity.R` | Scenario sensitivity for disturbance exclusions | Scenario-specific meta-analysis summaries, GAM comparisons, model diagnostics CSV, Neely GLMM check, and the new scenario-status / within-scenario influence exports | This is still descriptive/sensitivity-oriented rather than primary inference, but the small-`k` and leverage structure is now explicit in machine-readable outputs instead of being left implicit. |

## Highest-Priority Actions

1. Keep `29_natural_vs_restoration.R` descriptive in the Florida Keys size-matched section unless a valid two-cluster method replaces the current inferential framing.
2. Keep imputed vs no-imputation matrix uncertainty explicit in `13` and `16`, alongside the fragmentation-bracketing diagnostics.
3. Keep three-level meta-analysis claims tied to the clustered outputs, and label publication-bias diagnostics as independent-model sensitivity checks.
4. Keep figure scripts downstream of canonical outputs only. The main drift points are now patched, so this is a maintenance guardrail rather than an active repo bug.
