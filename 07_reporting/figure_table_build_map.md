# Figure and Table Build Map

This file records the current manuscript-facing build surface after the latest completeness pass. It is intentionally narrower than the full set of figure files present in the repo: only the retained manuscript and supplementary items are listed as formal build targets.

## Main Text Figures

| Item | Script | Canonical output |
|---|---|---|
| Fig. 1 Study landscape | `18_fig1_study_landscape.R` | `06_analysis/figures/manuscript/Fig1_study_landscape.png` and `.pdf` |
| Fig. 2 Demographic rates | `19_fig2_demographic_rates.R` | `06_analysis/figures/manuscript/Fig2_demographic_rates.png` and `.pdf` |
| Fig. 3 Caribbean synthesis | `20b_fig_expanded_forest_plot.R` | `06_analysis/figures/manuscript/Fig3_caribbean_synthesis.png` and `.pdf` |
| Fig. 4 Population viability | `22_fig6_population_model.R` | `06_analysis/figures/manuscript/Fig4_population_model.png` and `.pdf` |

## Supplementary Figures

| Item | Script | Canonical output |
|---|---|---|
| Fig. S1 Size distribution | `18_fig1_study_landscape.R` | `06_analysis/figures/supplementary/FigS1_size_distribution.png` and `.pdf` |
| Fig. S2 Data gaps / certainty | `23_figS2_data_gaps.R` | `06_analysis/figures/supplementary/FigS2_data_gaps.png` and `.pdf` |
| Fig. S3 Model diagnostics | `24_supp_S3_S4.R` | `06_analysis/figures/supplementary/FigS3_model_diagnostics.png` and `.pdf` |
| Fig. S4 Model selection | `24_supp_S3_S4.R` | `06_analysis/figures/supplementary/FigS4_model_selection.png` and `.pdf` |
| Fig. S5 Threshold analysis | `25_supp_S5_S6_S7_thresholds_growth.R` | `06_analysis/figures/supplementary/FigS5_threshold_analysis.png` and `.pdf` |
| Fig. S6 AGR vs RGR | `25_supp_S5_S6_S7_thresholds_growth.R` | `06_analysis/figures/supplementary/FigS6_agr_vs_rgr.png` and `.pdf` |
| Fig. S7 Allometry | `25_supp_S5_S6_S7_thresholds_growth.R` | `06_analysis/figures/supplementary/FigS7_allometry.png` and `.pdf` |
| Fig. S8 Shared-range natural vs restoration | `21_fig3_natural_vs_restoration.R` | `06_analysis/figures/supplementary/FigS8_natural_vs_restoration.png` and `.pdf` |
| Fig. S9 Heterogeneity | `26_supp_S8_S9.R` | `06_analysis/figures/supplementary/FigS9_heterogeneity.png` and `.pdf` |
| Fig. S10 Context comparison | `27_supp_S10_S11.R` | `06_analysis/figures/supplementary/FigS10_context_comparison.png` and `.pdf` |
| Fig. S11 Climate demography | `27_supp_S10_S11.R` | `06_analysis/figures/supplementary/FigS11_climate_demography.png` and `.pdf` |
| Fig. S12 Sensitivity | `28_supp_S12_S13_S14.R` | `06_analysis/figures/supplementary/FigS12_sensitivity.png` and `.pdf` |
| Fig. S13 Cross-validation | `28_supp_S12_S13_S14.R` | `06_analysis/figures/supplementary/FigS13_cross_validation.png` and `.pdf` |
| Fig. S14 Population projections | `28_supp_S12_S13_S14.R` | `06_analysis/figures/supplementary/FigS14_population_projections.png` and `.pdf` |
| Fig. S15 Regional survival | `20c_fig_regional_survival.R` | `06_analysis/figures/supplementary/FigS15_regional_survival.png` and `.pdf` |
| Fig. S16 Shrinkage / retrogression summary | `36_shrinkage_retrogression_summary.R` | `06_analysis/figures/supplementary/FigS16_shrinkage_retrogression_summary.png` and `.pdf` |
| Fig. S17 Disturbance-by-size interaction | `37_disturbance_size_interaction.R` | `06_analysis/figures/supplementary/FigS17_disturbance_size_interaction.png` and `.pdf` |
| Fig. S18 Disturbance summary | `34_disturbance_summaries.R` | `06_analysis/figures/supplementary/FigS18_disturbance_summary.png` and `.pdf` |
| Fig. S19 Restoration subtype sensitivity | `39_restoration_subtype_sensitivity.R` | `06_analysis/figures/supplementary/FigS19_restoration_subtype_sensitivity.png` and `.pdf` |

## Supplementary Tables

| Item | Script / source | Canonical output |
|---|---|---|
| Table S1 Disturbance chronology | `34_disturbance_summaries.R` | `07_reporting/tables/TableS1_disturbance_chronology.md` and `.csv` |
| Table S2 Study-window disturbance audit | `38_study_window_disturbance_audit.R` | `07_reporting/tables/TableS2_study_window_disturbance_audit.md` |
| Table S3 Size-class synthesis | reporting synthesis | `07_reporting/tables/size_class_synthesis_table.md` |

## Support-Only Outputs Still Present In Repo

These remain valuable but are not part of the formal numbered build surface:

- `06_analysis/figures/manuscript/Fig4_size_class_survival.*`
- `06_analysis/figures/manuscript/Fig5_expanded_forest_plot.png`
- `06_analysis/figures/manuscript/Fig6_population_model.png`
- `06_analysis/figures/supplementary/FigS8_forest_plots.*`
- `06_analysis/figures/supplementary/FigSXX_disturbance_sensitivity.*`
- `06_analysis/figures/supplementary/FigSXX_heat_stress_survival.*`
- `06_analysis/figures/supplementary/FigSXX_natural_vs_restoration_comparison.*`
- `06_analysis/figures/supplementary/disturbance_timeline_highres.*`
- `06_analysis/figures/supplementary/disturbance_regional_severity.*`

## Manual Checks After Regeneration

1. Confirm the main-text figure numbers in `07_reporting/figure_legends.txt` still match the actual retained figure set.
2. Confirm `Fig2_demographic_rates.*`, `FigS16_*`, `FigS17_*`, `FigS18_*`, `FigS19_*`, `TableS1_*`, and `TableS2_*` are regenerated under the canonical names.
3. Keep `claim_output_crosswalk.md`, `final_figure_table_set.md`, and this build map in sync whenever the manuscript-facing set changes.
