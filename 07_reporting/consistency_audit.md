# Consistency Audit

This file records the current manuscript-facing consistency check against the exported analysis outputs. It reflects the post-integration documentation state; the final step is to confirm the same values after the ongoing full pipeline rerun completes.

## Current Status

- The main stale legend values have been corrected: Fig. 2 now reflects the supported survival and growth nonlinearities, and Fig. 4 now reflects the current `lambda` and elasticity outputs.
- The meta-analysis counts and pooled survival remain unchanged, but heterogeneity is now reported consistently as `I^2 = 97.2%` in the manuscript-facing text.
- Disturbance handling, shrinkage / retrogression, the study-window audit, and the restoration subtype results are now surfaced in manuscript-facing docs rather than only living in support files.

## Audit Table

| Claim / location | Current manuscript-facing value | Source-of-truth file / value | Status | Note |
|---|---|---|---|---|
| Fig. 2 survival nonlinearity | Supported sigmoidal survival relationship with threshold near `7,498 cm2`; broad LOSO uncertainty | `06_analysis/output/survival_thresholds.csv`: `recommended_threshold_cm2 = 7497.66`, `loso_ci_lower = 2136.24`, `loso_ci_upper = 8748.34` | match | Wording is now aligned with the threshold output and no longer claims “no threshold.” |
| Fig. 2 growth nonlinearity | RGR threshold at `36.9 cm2`; bootstrap interval `36.9-38.9 cm2` | `06_analysis/output/growth_thresholds.csv`: `recommended_threshold_cm2 = 36.890`, `cluster_boot_ci_lower = 36.8898`, `cluster_boot_ci_upper = 38.9425` | match | Wording now reflects the current growth-threshold output. |
| Expanded meta-analysis summary | `k = 17`, `22 effects`, `N = 8,805`, pooled survival `78.0%`, CI `70.1-84.3%`, PI `39.5-95.1%`, `I^2 = 97.2%` | `06_analysis/output/expanded_meta_analysis_results.csv` | match | Counts and heterogeneity are now consistent across reporting docs. |
| Fig. 4 viability summary | `lambda = 0.961`, bootstrap interval `0.816-1.010`, P(decline) = 94.3% | `06_analysis/output/population_parameters.csv` | match | Values confirmed after switching to study-level rma() per size class (2026-04-14). |
| Fig. 4 elasticity interpretation | SC5 stasis contributes `58.9%` of matrix-cell elasticity | `06_analysis/output/elasticity_matrix.csv`, `06_analysis/output/vital_rate_elasticity.csv` | match | Elasticity confirmed after rma() update (2026-04-14). |
| Disturbance handling paragraph | `18` curated events: `11` acute baseline-exclusion and `7` context-only; pooled survival `75.9% -> 75.6%` when excluding baseline events | `06_analysis/output/disturbance_summary_by_tier.csv`, `06_analysis/output/disturbance_sensitivity_summary.csv` | match | The tiered disturbance logic is now aligned with the current outputs. |
| Shrinkage / retrogression results | Matrix-compatible shrinkage frequency `39.4%`; retrogression `15.2%` (SC2), `16.8%` (SC3), `17.2%` (SC4), `9.1%` (SC5) | `06_analysis/output/shrinkage_retrogression_subset_summary.csv`, `06_analysis/output/retrogression_probability_by_size_class.csv` | match | Now surfaced in Fig. 4 text and Fig. S16. |
| Study-window disturbance audit | `1,072` intervals, `7` studies, `53` zero-overlap, `74` one-event, `945` multi-event, `297` baseline-exclusion, `0` mismatches | `06_analysis/output/study_window_disturbance_summary_overall.csv`, `06_analysis/output/study_window_disturbance_rebuild_check.csv` | match | Canonical manuscript-facing table is now `TableS2_study_window_disturbance_audit.md`. |
| Restoration subtype sensitivity | Natural fragments `n = 3968`, `0.871`; nursery outplants `n = 1012`, `0.587`; re-cemented nursery outplants `n = 53`, `0.811`; outplanted colonies `n = 46`, `0.652` | `06_analysis/output/restoration_subtype_survival_summary.csv` | match | These values are now exposed in Fig. S19 and the narrative docs. |

## Remaining Check

The remaining required step is mechanical rather than conceptual:

- confirm that the ongoing full rerun regenerates the canonical filenames (`Fig2_demographic_rates`, `FigS16`-`FigS19`, `TableS1`, `TableS2`) and does not shift any of the audited numerical outputs
