# Repo-Wide Statistical Priorities

This file condenses the script-level audit into the main issues that still
matter for manuscript-quality statistical review.

## Strongest Current Diagnostics

- Threshold workflows in `02` and `03` already have broad comparison surfaces
  (`GLM`/`GLMM`/`GAM`, LOSO, derivative diagnostics, overdispersion checks).
- The matrix layer in `13` has unusually strong uncertainty products for this
  repo (`transition_matrix_bootstrap_ci.csv`, `elasticity_bootstrap_ci.csv`,
  `lambda_bootstrap_diagnostics.csv`, `transition_sample_sizes.csv`,
  `transition_matrix_source_leverage.csv`).
- The advanced layer now emits compact fit metadata for the main inferential
  scripts in `31`, `37`, `41`, `42`, `46`, and `47`, and `46`/`47` now export
  the follow-up diagnostics that were previously missing from reviewer-facing QA.
- The support layer now distinguishes baseline references from manuscript
  workflow products: `10` validates the threshold target with imbalance-robust
  metrics, and `12` exports `model_selection_workflow_alignment.csv`.
- The disturbance support layer now exports explicit guardrails instead of
  leaving them implicit: `30` writes scenario-status and leave-one-study-out
  influence tables, and `31` now emits support-aware diagnostics using the
  verified DHW cache when present.
- The main figure scripts are materially harder to drift now: `19` reads
  canonical threshold model objects, `22` pulls leverage annotations from
  `transition_matrix_source_leverage.csv`, and `26` hard-reads the expanded
  moderator output instead of falling back to the legacy file.
- The study-window overlap audit in `38` is one of the strongest QA products in
  the codebase because it rebuilds the disturbance assignment deterministically.

## Highest-Priority Residual Limits

1. **Florida Keys natural-vs-restoration inference**
   The size-matched Florida Keys comparison in `29` is now labeled descriptive
   only, but the broader paper should keep that interpretation disciplined until
   a valid small-cluster method is used.

2. **Three-level meta-analysis interpretation discipline**
   `14b_expanded_meta_analysis.R` is the right primary meta-analysis. It now has
   a primary-model parent-study jackknife and clustered moderator inference. The
   remaining issue is interpretive: publication-bias products still come from the
   independent-effects model and should stay labeled as sensitivity checks.

3. **Matrix-model leverage**
   `13` and `16` still lean heavily on concentrated upper-size support.
   That dependence is now explicit in `transition_matrix_source_leverage.csv`
   (`83.2%` NOAA for SC5 survival, `100%` Vardi for fragmentation), so the
   remaining issue is the biology/data dependency itself, not hidden uncertainty.

4. **Climate and disturbance attribution**
   `08` now uses centered temporal terms plus the maintained DHW overlay and
   fits an explicit DHW GLMM, while `31`/`32` prefer the verified heat-stress
   file and export coverage tables. The remaining issue is support quality:
   DHW coverage is still sparse and often literature-LUT backed, so climate
   attribution should stay cautious.

## Descriptive-Only Layers

These can stay in the repo, but they should not carry stronger inferential
language than the design supports:

- `11_context_comparison.R`
- `29_natural_vs_restoration.R` Florida Keys size-matched subsection
- `30_disturbance_sensitivity.R`
- `33_hurricane_exposure.R`
- `34_disturbance_summaries.R`
- `36_shrinkage_retrogression_summary.R`
- `39_restoration_subtype_sensitivity.R`
- `40_manzello_heatwave_scenarios.R`

## Advanced Models That Need Careful Framing

- `41_multistate_transition_model.R`: useful structure, still light on
  predictive uncertainty.
- `42_joint_longitudinal_survival_model.R`: strongest advanced diagnostics, but
  still a two-stage approximation rather than a full joint model.
- `43_stochastic_ipm_disturbance_model.R`: now includes explicit recruitment
  scenarios, but still needs stronger basis/residual diagnostics and kernel
  sensitivity checks before it becomes a primary manuscript result.
- `44_regime_switching_model.R`: state identifiability and initialization
  sensitivity remain central.
- `45_distributed_lag_disturbance_model.R`: lag collinearity and blocked
  validation still matter.
- `46_recurrent_event_frailty_model.R`: the main shrink-history PH problem is
  now modeled explicitly with a log-time interaction; keep this layer support-only
  rather than treating it as settled causal structure.
- `47_spatiotemporal_hierarchical_model.R`: temporal adequacy and follow-up
  diagnostics are materially stronger now (`k.check`, region-blocked CV, spatial
  residual checks), but Florida-heavy support still limits transfer claims.

## Immediate Next Actions

1. Re-run the full pipeline from the current code state before any release-grade
   freeze only if a single-provenance release snapshot is required; the touched
   statistical/reporting surfaces are already refreshed in the current worktree.
2. Keep manuscript claims tied only to analyses that are either well-diagnosed or
   explicitly labeled descriptive.
3. Use the new leverage and workflow-alignment exports directly in reporting
   rather than paraphrasing their conclusions from memory, and use the new
   disturbance scenario-status / influence exports when discussing exclusion
   sensitivity.
