# Figure Directory

This directory contains both the canonical manuscript-facing figure set and a wider layer of support-only or exploratory figure outputs.

Use [07_reporting/manuscript/figure_table_map.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/manuscript/figure_table_map.md) as the authoritative source for what is part of the final numbered build.

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
| Fig. S20 Annual survival time series | `49_annual_survival_timeseries.R` | `FigS20_annual_survival_timeseries.*` |
| Fig. S21 Forest plots | `26_supp_S8_S9.R` | `FigS21_forest_plots.*` |
| Fig. S22 Heatwave scenarios | `40_manzello_heatwave_scenarios.R` | `FigS22_heatwave_scenarios.*` |
| Fig. S23 Disturbance timeline | `32_disturbance_survival_analysis.R` | `FigS23_disturbance_timeline.*` |
| Fig. S24 Heat stress survival | `31_heat_stress_overlay.R` | `FigS24_heat_stress_survival.*` |
| Fig. S25 Disturbance sensitivity | `30_disturbance_sensitivity.R` | `FigS25_disturbance_sensitivity.*` |
| Fig. S26 Natural vs restoration comparison | `29_natural_vs_restoration.R` | `FigS26_natural_vs_restoration_comparison.*` |
| Fig. S28 Temporal synthesis | `49b_temporal_synthesis_figure.R` | `FigS28_temporal_synthesis.*` |
| Fig. S29 Biological realism scenarios | `61_fig_biological_realism.R` | `FigS29_biological_realism.*` |

*FigS27 number is intentionally vacant — former orphan placeholder removed 2026-04-24; downstream cross-refs to FigS28/FigS29 retained at original numbers.*

## Exploratory And Support-Only Figures (`supplementary/exploratory/`)

These files are not part of the final numbered manuscript build. They live in `supplementary/exploratory/` and include advanced dynamic model outputs and internal support diagnostics:

- `disturbance_timeline_highres.*` -- detailed disturbance timeline (from `34_disturbance_summaries.R`)
- `disturbance_regional_severity.*` -- regional severity heatmap (from `34_disturbance_summaries.R`)
- `distributed_lag_coefficients.*` -- distributed-lag disturbance model (from `45`)
- `regime_switching_year_states.*` -- HMM regime classification (from `44`)
- `spatiotemporal_hierarchical_summary.*` -- spatiotemporal GAMM (from `47`)
- `stochastic_ipm_projection_trajectories.*` -- stochastic IPM projections (from `43`)
- `joint_longitudinal_risk_curve.png` -- joint longitudinal-survival model (from `42`)
- `model_selection_survival.png`, `model_selection_growth.png`, `survival_coefficients.png` -- model comparison diagnostics (from `12`)
- `allometry_analysis.png` -- allometric analysis (from `04`)

## Model Diagnostics (`supplementary/diagnostics/`)

Base R diagnostic plots (residuals, Q-Q, DHARMa):

- `survival_model_diagnostics.png` -- from `02`
- `growth_model_diagnostics.png` -- from `03`

## Meta-Analysis Diagnostics (`supplementary/meta_analysis/`)

Internal diagnostic figures from scripts 14 and 14b:

- `Fig_meta_*` -- k=5 meta-analysis (forest, funnel, heterogeneity, stratified)
- `expanded_*` -- k=17/22 expanded meta-analysis (forest, funnel, tier comparison, regional, trim-and-fill)
- `leave_one_out_analysis.png` -- LOSO sensitivity

## Naming Convention

| Directory | Pattern | Example |
|-----------|---------|---------|
| `manuscript/` | `Fig{N}_{snake_case}.{pdf,png}` | `Fig1_study_landscape.pdf` |
| `supplementary/` | `FigS{N}_{snake_case}.{pdf,png}` | `FigS12_sensitivity.pdf` |
| `supplementary/exploratory/` | `{snake_case}.{pdf,png}` | `power_curves.png` |
| `supplementary/diagnostics/` | `{snake_case}.png` | `survival_model_diagnostics.png` |
| `supplementary/meta_analysis/` | `{prefix}_{snake_case}.{pdf,png}` | `expanded_forest_plot.pdf` |

- Manuscript and supplementary figures are always saved as both PNG and PDF via `save_manuscript_fig()`
- Exploratory figures may be PNG-only when they are internal diagnostics
- Figure numbering is defined in `utils/01_functions.R` (canonical registry)
