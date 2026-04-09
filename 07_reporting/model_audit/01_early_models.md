# Early Model Audit

Scope: scripts `02` through `12` in `06_analysis/scripts`.

This section covers the threshold, growth, variance-partitioning, climate,
power, cross-validation, context-comparison, and model-selection layer.

## Overall

The early model layer already has a broad diagnostics surface. The main problems
are not total absence of checks, but mismatch between what is modeled upstream
and what is summarized downstream, plus a few places where the diagnostics are
too shallow for the claimed interpretation.

## Script-Level Issues

| Script | Model family / role | Diagnostics already present | Remaining issues a statistician would care about |
|---|---|---|---|
| `02_survival_thresholds.R` | GLM/GLMM/GAM/GAMM threshold workflow for survival | GLM vs GLMM vs GAM comparisons, overdispersion checks, `gam.check`, `k.check`, LOSO, derivative plots, model-comparison CSVs | Threshold stability remains the main issue. Add study-level influence diagnostics, concurvity checks, and stronger uncertainty reporting for the estimated threshold. |
| `03_growth_thresholds.R` | Gaussian/LMM/GAM threshold workflow for AGR, RGR, and positive growth | Heteroscedasticity screen, LMM/GLMM alternatives, LOSO, quantile regression, threshold comparison tables, positive-growth GLMM diagnostics | The script documents severe heteroscedasticity but still leans on simpler models. It needs saved residual diagnostics and a clearer justification for the primary model versus a variance-stabilized or two-part alternative. |
| `04_growth_rate_comparison.R` | AGR vs RGR comparison, allometry, matched comparisons | Null self-correlation simulation, GAM comparisons, heteroscedasticity analysis, ANCOVA/restricted overlap checks, mixed-effects allometry | The problem is sprawl. There is no single authoritative output that says which branch is canonical and which are supporting checks. Filters and thresholds should stay synchronized with script `03`. |
| `05_variance_partitioning.R` | Predictor-importance and variance summary layer | Unadjusted vs study-adjusted temporal trends, GLMM size×region interaction, VIF, pseudo-R², Nakagawa R², overdispersion checks, pseudoreplication checks | Much of this is predictor importance rather than true variance partitioning. Add singular-fit/convergence flags, uncertainty on R²/ICC, and either relabel the analysis or convert it to a cleaner multilevel decomposition. |
| `06_data_gap_analysis.R` | Coverage and evidence-gap prioritization | Coverage matrices, temporal summaries, certainty scores, priority ranking, exploratory plots | Gap scoring is ad hoc and count-based. It should be sensitivity-tested, tied to model precision/power, and expanded to reflect growth-side evidence quality as well as survival coverage. |
| `07_integrate_summary_data.R` | Individual + summary data integration | Reliability flags, overlap table, overlap-exclusion policy, resolved study/regional summaries, contribution accounting | The main overlap problem is now handled conservatively: individual rows dominate when a study appears in both sources. Remaining concerns are compatibility of summary-study definitions and whether mean-size based pooling should be further harmonized before publication-facing regional claims. |
| `08_climate_demography.R` | Temporal/disturbance analysis with sparse DHW overlay | Yearly summaries, centered-year temporal GLMM, nonlinear trend/LRT, DHW coverage table, DHW GLMM, regional and size variability summaries, temporal diagnostics CSV, and cohort-confounding check | The convergence/identifiability surface is cleaner now, but this is still not a full climate-attribution model. DHW is explicit, yet coverage remains sparse and mostly literature-LUT backed. Keep this framed as supportive climate context unless lagged climate covariates and stronger validation are added. |
| `09_power_analysis.R` | Retrospective/prospective power calculations | Heterogeneity estimates, analytical curves, simulation-based power, growth power grid, scenario outputs | Current design-effect inflation makes some recommendations unusable. The script should pivot to feasible prospective site×colony designs with scenario grids over ICC and site count. |
| `10_cross_validation.R` | LOSO/LORO/grouped CV for manuscript-aligned threshold targets | Brier/log-loss/AUC/PR-AUC/balanced accuracy, grouped schemes, temporal holdout, LOSCO, growth CV summaries, threshold-target prediction, nonlinear candidate comparison | The main misalignment is fixed: the exported CV layer now targets the threshold workflow and reports imbalance-robust metrics. Remaining weakness is that growth-side transfer remains poor and the GAM survival candidate is still unstable in some grouped folds. |
| `11_context_comparison.R` | Descriptive context contrasts | Omnibus and pairwise comparisons, overlap-zone GLMM, context-specific size models, context diagnostics | The script already warns that context is confounded, but some outputs still invite causal use. Keep it descriptive only and avoid “adjustment factor” framing. |
| `12_model_selection.R` | GLM/GLMM and LM/LMM AIC/BIC model-selection layer | AIC/BIC tables, coefficients with CIs, mixed-model diagnostics, overdispersion, model-selection figures, workflow-alignment export | The stale-summary problem is fixed by demoting the classical AIC tables to baseline-reference status and exporting `model_selection_workflow_alignment.csv` for the retained threshold/GAM workflow. Remaining limitation is that nonlinear models are summarized via alignment outputs rather than refit directly inside this script. |

## Highest-Priority Actions

1. Track growth-side external validation more aggressively; the threshold/GAM alignment problem for `10` and `12` is now addressed, but growth transfer remains weak.
2. Keep `08_climate_demography.R` framed as supportive climate context unless stronger DHW/SST coverage and lagged covariates are added.
3. Keep `11_context_comparison.R` descriptive only and retire any “adjustment factor” language.
4. Add residual/concurvity style diagnostics to the threshold scripts if they become manuscript-facing beyond their current support role.
