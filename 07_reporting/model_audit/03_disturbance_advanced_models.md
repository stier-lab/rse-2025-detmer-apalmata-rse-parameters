# Disturbance and Advanced Model Audit

Scope: scripts `31` through `48` in `06_analysis/scripts`.

This pass tightened several diagnostics without changing estimands. Added during this review:
`heat_stress_model_diagnostics.csv`, `disturbance_sensitivity_scenario_status.csv`,
`disturbance_sensitivity_influence.csv`, `disturbance_size_model_diagnostics.csv`,
`multistate_model_diagnostics.csv` (expanded), `joint_longitudinal_fit_metrics.csv` (expanded),
`recurrent_event_ph_diagnostics.csv`, and `spatiotemporal_*_kcheck.csv`.

Overall pattern:
the scripts usually have the right model family and at least one comparison metric
(`AIC`, `LRT`, bootstrap, or calibration), but several still need explicit checks for
convergence, overdispersion, basis adequacy, proportional hazards, or sensitivity to
thin strata.

| Script | Model family / role | Diagnostics already present | Remaining issues a statistician would care about |
|---|---|---|---|
| `31_heat_stress_overlay.R` | Binomial GLMM for DHW vs survival; correlation and meta-analysis moderator test | Support-aware diagnostics table, verified-cache preference, overdispersion check, coefficient table, Spearman correlation, and descriptive-only suppression of moderator inference under sparse support | The main remaining issue is the data itself, not the framing: DHW coverage is still sparse and mostly cache/LUT backed, so this layer should stay support-only unless independent coverage improves. |
| `32_disturbance_survival_analysis.R` | Binomial GLMMs for DHW and disturbance severity; timeline overlay; return intervals | Overdispersion checks, OR/CI tables, merge diagnostics, DHW coverage table, cleaned timeline figure, event-frequency summaries | Stronger now because it prefers the verified overlay, reports DHW support explicitly, and the timeline render no longer throws scale/row-drop warnings. The main remaining risk is still alignment: year join uses start-of-interval logic and could blur exposure timing. No out-of-sample validation or lag sensitivity yet. |
| `33_hurricane_exposure.R` | Descriptive hurricane exposure extraction / coding | Event parsing and coverage summaries | Not a formal model, but the risk is provenance: event-to-region coding needs to stay synchronized with the curated timeline and any future region splits. |
| `34_disturbance_summaries.R` | Descriptive disturbance timeline / summary graphics | Counts and grouped summaries | No formal inferential model. Main issue is reproducibility of the taxonomy and keeping acute vs context-only definitions aligned with the rest of the pipeline. |
| `35_curate_literature_scope.R` | Scope curation / inclusion flags | Reproducible screening labels and retained subsets | No model diagnostics. The key issue is maintaining a defensible inclusion rule as new site data and new literature are added. |
| `36_shrinkage_retrogression_summary.R` | Descriptive shrinkage and observed retrogression summary | Binomial CIs, subset comparison (matrix-compatible vs all-clean), study summaries, retrogression probabilities | Still descriptive. A statistician would want the transition definitions kept identical to the matrix workflow and the heuristic “matrix-compatible” subset documented very clearly. |
| `37_disturbance_size_interaction.R` | Binomial GLMM interaction models for survival and positive growth | `AIC`, `BIC`, `logLik`, LRT, overdispersion, singular-fit and convergence metadata in the new diagnostics table | Interaction strata can be thin, especially under acute disturbance. No calibration or residual review yet, and random-slope alternatives are not explored. |
| `38_study_window_disturbance_audit.R` | Deterministic interval-overlap audit | Overlap counts, mismatch counts, baseline-exclusion counts | No model diagnostics apply. The risk is logical drift if prep-time interval rules change and this audit is not rerun. |
| `39_restoration_subtype_sensitivity.R` | Bootstrap-weighted subtype summaries | Bootstrap CIs, subtype mapping confidence, sample sizes | The subtype mapping is partly heuristic. It is defensible as a curation layer, but not as a formal causal comparison unless the mapping rules are treated as fixed design choices. |
| `40_manzello_heatwave_scenarios.R` | Scenario simulation / counterfactual projection | Bootstrap lambda propagation, scenario projections, summary table | This is a scenario layer, not an empirical fit. The main issue is transparency: the results depend on matrix assumptions plus a single heatwave dose-response curve. |
| `41_multistate_transition_model.R` | Two-part multistate model: cloglog death hazard + multinomial alive transitions | Expanded diagnostics table with class, `AIC`, `BIC`, `logLik`, overdispersion, singular fit, convergence message, and multinomial optimizer metadata | Still no bootstrap uncertainty on the composed matrix, no posterior/predictive check for transition probabilities, and no formal goodness-of-fit beyond point estimates. |
| `42_joint_longitudinal_survival_model.R` | Two-stage longitudinal + hazard model | Calibration by decile, Brier score, AUC, `AIC`/`BIC`/`logLik`, downgrade reason for the longitudinal fit | This is explicitly a two-stage approximation, not a full joint model. The biggest unresolved issue is interpretation of the latent-velocity term and whether the approximation is stable to alignment choices. |
| `43_stochastic_ipm_disturbance_model.R` | Regime-conditioned GAM-based stochastic IPM with explicit recruitment scenarios | GAM diagnostics table with `AIC` and deviance explained, recruitment-scenario table, scenario simulation summary | This is now a true survival+growth+recruitment scenario model rather than a zero-recruitment viability proxy. Remaining issues are basis-dimension checks, residual diagnostics, and stronger sensitivity tests for kernel discretization and regime-class mapping. |
| `44_regime_switching_model.R` | Hidden-state annual regime model / Gaussian HMM | `logLik`, `AIC`, `BIC`, posterior state series, regime classification tables | Main concerns are identifiability and sensitivity to the number of states / initializations. Needs clearer posterior predictive or classification-uncertainty reporting if it becomes manuscript-facing. |
| `45_distributed_lag_disturbance_model.R` | Binomial GLMMs and LMMs with lagged disturbance windows | `AIC`, `BIC`, coefficient CIs, window vs unconstrained comparisons | No explicit overdispersion/singularity diagnostics. Lag coefficients can be collinear, and the exposure construction should be stress-tested against alternative lag definitions. |
| `46_recurrent_event_frailty_model.R` | Cox frailty / cluster-robust recurrent-event hazards | Concordance, `AIC`, frailty theta, and the new proportional-hazards diagnostics | Stronger now, but still needs careful interpretation of the frailty distribution and recurrent-event ordering. PH diagnostics are necessary but not sufficient for model adequacy. |
| `47_spatiotemporal_hierarchical_model.R` | Binomial GAMMs with temporal and spatial smooths | `AIC`/`logLik`/R²/scale, variance components, `k.check`, region-blocked CV, and spatial residual checks | The main remaining issue is transferability under Florida-heavy support, not hidden missing diagnostics: the basis and residual checks are now exported, but blocked holdouts still expose structural thinness in some regions. |
| `48_pipeline_refresh_audit.R` | Pipeline metadata / artifact freshness audit | Canonical inventory, canonical statistics, artifact registry, freshness table | Not a statistical model. The main issue is maintenance: keep generated reporting docs and the registry synchronized whenever new site data lands. |

Bottom line:
the advanced layer is statistically credible, but the manuscript-facing subset should only claim
what is supported by the available diagnostics. The most important residual items are
coverage imbalance, thin strata in disturbance interactions, and explicit uncertainty
around the latent/state-space style analyses.
