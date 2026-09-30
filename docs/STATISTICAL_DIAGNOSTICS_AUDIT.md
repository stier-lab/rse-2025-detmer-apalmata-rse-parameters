# Statistical diagnostics audit

**Run date:** 2026-09-29  
**Scope:** manuscript-facing models and the expanded survival synthesis.

## What was run

- Static scan of `06_analysis/scripts`: 342 model/test calls and 178 diagnostic
  calls. This is an inventory, not a count of independent analyses.
- `14b_expanded_meta_analysis.R` under the available R installation.
- `20b_fig_expanded_forest_plot.R` and `22_fig6_population_model.R` to
  regenerate the two affected main figures.

## Corrected findings

1. **Annualization:** Tier 1 effects are now built from interval-level survival
   proportions annualized as \(S^{1/t}\), then aggregated within the original
   eight Tier-1 effects. Tier 2 uses the same transformation. The completed
   three-level REML model contains 17 parent studies and 22 effects, with pooled
   annual survival 78.7% (95% CI 70.4--85.1%; prediction interval 37.4--95.8%;
   I² = 97.6%).
2. **Pipeline failure:** a provenance-label change made the Tier-1-only
   sensitivity filter select zero rows. The filter now matches the Tier-1 label
   prefix and the full script completes.
3. **Effect definition:** the annualization path now explicitly retains the
   pre-specified Tier-1 membership and NOAA's three natural-colony regional
   effects. It does not silently add records that belong to other analyses.
4. **Matrix interpretation:** the bootstrap share with \(\lambda < 1\) is now
   labeled as a resampling frequency. It is not a probability of real-world
   decline; the matrix fixes sexual and external recruitment at zero.

## Remaining statistical limits (reported, not repairable by wording)

- The meta-analysis is highly heterogeneous and the prediction interval is
  broad; a pooled rate is not a Caribbean-wide constant.
- The disturbance interaction is observational (`size × exposure category` with
  study random intercept), so no causal disturbance effect is claimed.
- SC5 survival is NOAA-dominated and fragmentation support is Vardi-only.
- The locked `renv` environment has not yet reproduced on this host's R 4.6.1;
  clean-clone reproducibility remains a release gate.
