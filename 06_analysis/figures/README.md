# Figure Directory

This directory contains both the canonical manuscript-facing figure set and a wider layer of support-only or exploratory figure outputs.

Use [07_reporting/final_figure_table_set.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/final_figure_table_set.md) and [07_reporting/figure_table_build_map.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/figure_table_build_map.md) as the authoritative sources for what is part of the final numbered build.

## Canonical Main-Text Figures (`manuscript/`)

| Figure | Script | Canonical files |
|---|---|---|
| Fig. 1 Study landscape | `18_fig1_study_landscape.R` | `Fig1_study_landscape.png` and `.pdf` |
| Fig. 2 Demographic rates | `19_fig2_demographic_rates.R` | `Fig2_demographic_rates.png` and `.pdf` |
| Fig. 3 Caribbean synthesis | `20b_fig_expanded_forest_plot.R` | `Fig3_caribbean_synthesis.png` and `.pdf` |
| Fig. 4 Population viability | `22_fig6_population_model.R` | `Fig4_population_model.png` and `.pdf` |

## Canonical Supplementary Figures (`supplementary/`)

| Figure | Script | Canonical files |
|---|---|---|
| Fig. S1 Size distribution | `18_fig1_study_landscape.R` | `FigS1_size_distribution.*` |
| Fig. S2 Data gaps | `23_figS2_data_gaps.R` | `FigS2_data_gaps.*` |
| Fig. S3 Model diagnostics | `24_supp_S3_S4.R` | `FigS3_model_diagnostics.*` |
| Fig. S4 Model selection | `24_supp_S3_S4.R` | `FigS4_model_selection.*` |
| Fig. S5 Threshold analysis | `25_supp_S5_S6_S7_thresholds_growth.R` | `FigS5_threshold_analysis.*` |
| Fig. S6 AGR vs RGR | `25_supp_S5_S6_S7_thresholds_growth.R` | `FigS6_agr_vs_rgr.*` |
| Fig. S7 Allometry | `25_supp_S5_S6_S7_thresholds_growth.R` | `FigS7_allometry.*` |
| Fig. S8 Shared-range natural vs restoration | `21_fig3_natural_vs_restoration.R` | `FigS8_natural_vs_restoration.*` |
| Fig. S9 Heterogeneity | `26_supp_S8_S9.R` | `FigS9_heterogeneity.*` |
| Fig. S10 Context comparison | `27_supp_S10_S11.R` | `FigS10_context_comparison.*` |
| Fig. S11 Climate demography | `27_supp_S10_S11.R` | `FigS11_climate_demography.*` |
| Fig. S12 Sensitivity | `28_supp_S12_S13_S14.R` | `FigS12_sensitivity.*` |
| Fig. S13 Cross-validation | `28_supp_S12_S13_S14.R` | `FigS13_cross_validation.*` |
| Fig. S14 Population projections | `28_supp_S12_S13_S14.R` | `FigS14_population_projections.*` |
| Fig. S15 Regional survival | `20c_fig_regional_survival.R` | `FigS15_regional_survival.*` |
| Fig. S16 Shrinkage / retrogression | `36_shrinkage_retrogression_summary.R` | `FigS16_shrinkage_retrogression_summary.*` |
| Fig. S17 Disturbance-by-size interaction | `37_disturbance_size_interaction.R` | `FigS17_disturbance_size_interaction.*` |
| Fig. S18 Disturbance summary | `34_disturbance_summaries.R` | `FigS18_disturbance_summary.*` |
| Fig. S19 Restoration subtype sensitivity | `39_restoration_subtype_sensitivity.R` | `FigS19_restoration_subtype_sensitivity.*` |

## Support-Only And Deprecated Figure Variants

These files remain useful for traceability or revision support, but they are **not** part of the final numbered manuscript build:

- `manuscript/Fig2_vital_rates.*`
- `manuscript/Fig3_natural_vs_restoration.png`
- `manuscript/Fig4_size_class_survival.*`
- `manuscript/Fig5_expanded_forest_plot.png`
- `manuscript/Fig6_population_model.png`
- `supplementary/FigS8_forest_plots.*`
- `supplementary/FigSXX_*`
- `supplementary/disturbance_timeline_highres.*`
- `supplementary/disturbance_regional_severity.*`
- advanced-model figures such as `distributed_lag_coefficients.*`, `joint_longitudinal_risk_curve.png`, `regime_switching_year_states.*`, `spatiotemporal_hierarchical_summary.*`, and `stochastic_ipm_projection_trajectories.*`

## Output Format

Canonical manuscript and supplementary figures are written as both PNG and PDF when the generating script supports both formats. Support-only outputs vary by script.
