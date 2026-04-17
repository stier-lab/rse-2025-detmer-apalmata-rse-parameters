# Final Filename Normalization Plan

This plan is designed to leave the repo with one manuscript-facing filename per retained figure/table concept, while preserving legacy or support files for traceability.

## 1. Canonical Main-Text Filenames

| Final canonical filename | Current conflict to resolve | Action |
|---|---|---|
| `06_analysis/figures/manuscript/Fig1_study_landscape.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/manuscript/Fig2_demographic_rates.png` and `.pdf` | `Fig2_vital_rates.*` (removed) | Use `Fig2_demographic_rates.*` as canonical. Legacy files deleted. |
| `06_analysis/figures/manuscript/Fig3_caribbean_synthesis.png` and `.pdf` | none in the current main figure plan | Leave as is. |
| `06_analysis/figures/manuscript/Fig4_population_model.png` and `.pdf` | `Fig6_population_model.png` (removed) | Use `Fig4_population_model.*` as the manuscript figure. Legacy file deleted. |

## 2. Canonical Supplementary Filenames

| Final canonical filename | Current conflict to resolve | Action |
|---|---|---|
| `06_analysis/figures/supplementary/FigS1_size_distribution.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/supplementary/FigS2_data_gaps.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/supplementary/FigS3_model_diagnostics.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/supplementary/FigS4_model_selection.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/supplementary/FigS5_threshold_analysis.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/supplementary/FigS6_agr_vs_rgr.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/supplementary/FigS7_allometry.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/supplementary/FigS8_natural_vs_restoration.png` and `.pdf` | (collision resolved: former `FigS8_forest_plots.*` renamed to `FigS21_forest_plots.*`) | Leave as is. |
| `06_analysis/figures/supplementary/FigS9_heterogeneity.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/supplementary/FigS10_context_comparison.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/supplementary/FigS11_climate_demography.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/supplementary/FigS12_sensitivity.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/supplementary/FigS13_cross_validation.png` and `.pdf` | `FigS13_sensitivity.*` | Keep `FigS13_cross_validation.*` as canonical. |
| `06_analysis/figures/supplementary/FigS14_population_projections.png` and `.pdf` | `FigS14_context_comparison.*` | Keep `FigS14_population_projections.*` as canonical. |
| `06_analysis/figures/supplementary/FigS15_regional_survival.png` and `.pdf` | none | Leave as is. |
| `06_analysis/figures/supplementary/FigS16_shrinkage_retrogression_summary.png` and `.pdf` | `shrinkage_retrogression_summary.*` (removed) | S16 is the numbered canonical output. Unnumbered duplicates deleted. |
| `06_analysis/figures/supplementary/FigS17_disturbance_size_interaction.png` and `.pdf` | `disturbance_size_interaction.*` (removed) | S17 is the numbered canonical output. Unnumbered duplicates deleted. |
| `06_analysis/figures/supplementary/FigS18_disturbance_summary.png` and `.pdf` | `disturbance_timeline_highres.*`, `disturbance_regional_severity.*` (moved to `exploratory/`) | S18 is the numbered combined summary. Support figures moved to `exploratory/`. |
| `06_analysis/figures/supplementary/FigS19_restoration_subtype_sensitivity.png` and `.pdf` | `restoration_subtype_sensitivity.*` (removed) | S19 is the numbered canonical output. Unnumbered duplicates deleted. |

## 3. Canonical Supplementary Tables

| Final canonical filename | Current conflict to resolve | Action |
|---|---|---|
| `07_reporting/manuscript/tables/TableS1_disturbance_chronology.md` and `.csv` | `disturbance_summary_table.*` | Use Table S1 as the manuscript-facing filename. |
| `07_reporting/manuscript/tables/TableS2_study_window_disturbance_audit.md` | `study_window_disturbance_audit.md` | Use Table S2 as the manuscript-facing filename. |

## 4. Renaming / Regeneration Order

1. Regenerate the figure-producing scripts that now emit the canonical names directly.
2. Rebuild the disturbance tables so Table S1 and Table S2 exist under manuscript-facing names.
3. Update all reporting docs to use the canonical filenames and number labels.
4. Leave legacy or support-only filenames in the repo unless they become confusing enough to archive in a later cleanup pass.

## 5. Keep But Do Not Treat As Final Manuscript Items

- `06_analysis/figures/manuscript/Fig4_size_class_survival.*`
- `06_analysis/figures/supplementary/exploratory/disturbance_timeline_highres.*`
- `06_analysis/figures/supplementary/exploratory/disturbance_regional_severity.*`
- Advanced dynamic model outputs in `supplementary/exploratory/`

Note: Former `FigS8_forest_plots.*`, `FigSXX_disturbance_sensitivity.*`, `FigSXX_heat_stress_survival.*`, and `FigSXX_natural_vs_restoration_comparison.*` have been assigned proper numbers (S21, S25, S24, S26 respectively) and are now part of the formal numbered set. Old archive figures (`Fig2_vital_rates.*`, `Fig3_natural_vs_restoration.png`, `Fig5_expanded_forest_plot.png`, `Fig6_population_model.png`) have been deleted.

These remain useful for internal checking and revision support, but they are not part of the final numbered figure/table surface.
