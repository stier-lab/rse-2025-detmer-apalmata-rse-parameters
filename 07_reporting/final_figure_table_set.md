# Final Figure and Table Set

This is the current recommended final manuscript/supplement set for the paper. The guiding rule is:

- keep the main text anchored to the figure structure already represented in `07_reporting/figure_legends.txt`
- formalize the strongest new completeness products as numbered supplementary items
- leave duplicate or manuscript-candidate variants in the repo as internal support outputs rather than pretending they are part of the final numbered set

## Main Text Figures

| Number | Title / concept | Canonical filename | Generating script | Decision |
|---|---|---|---|---|
| Fig. 1 | Study landscape and data availability | `06_analysis/figures/manuscript/Fig1_study_landscape.png` and `.pdf` | `18_fig1_study_landscape.R` | Keep as main text. |
| Fig. 2 | Size-dependent vital rates and nonlinear thresholds | `06_analysis/figures/manuscript/Fig2_demographic_rates.png` and `.pdf` | `19_fig2_demographic_rates.R` | Keep as main text. Canonicalize `Fig2_demographic_rates`; archive `Fig2_vital_rates.*` as old naming. |
| Fig. 3 | Caribbean-wide survival synthesis | `06_analysis/figures/manuscript/Fig3_caribbean_synthesis.png` and `.pdf` | `20b_fig_expanded_forest_plot.R` | Keep as main text. This is the meta-analytic synthesis figure. |
| Fig. 4 | Population viability assessment | `06_analysis/figures/manuscript/Fig4_population_model.png` and `.pdf` | `22_fig6_population_model.R` | Keep as main text. This is the viability endpoint figure. |

## Formal Supplementary Figures

| Number | Title / concept | Canonical filename | Generating script | Decision |
|---|---|---|---|---|
| Fig. S1 | Size distribution | `06_analysis/figures/supplementary/FigS1_size_distribution.png` and `.pdf` | `18_fig1_study_landscape.R` | Keep. |
| Fig. S2 | Data gaps / certainty matrix | `06_analysis/figures/supplementary/FigS2_data_gaps.png` and `.pdf` | `23_figS2_data_gaps.R` | Keep. |
| Fig. S3 | Model diagnostics | `06_analysis/figures/supplementary/FigS3_model_diagnostics.png` and `.pdf` | `24_supp_S3_S4.R` | Keep. |
| Fig. S4 | Model selection | `06_analysis/figures/supplementary/FigS4_model_selection.png` and `.pdf` | `24_supp_S3_S4.R` | Keep. |
| Fig. S5 | Threshold analysis | `06_analysis/figures/supplementary/FigS5_threshold_analysis.png` and `.pdf` | `25_supp_S5_S6_S7_thresholds_growth.R` | Keep. |
| Fig. S6 | AGR vs RGR | `06_analysis/figures/supplementary/FigS6_agr_vs_rgr.png` and `.pdf` | `25_supp_S5_S6_S7_thresholds_growth.R` | Keep. |
| Fig. S7 | Allometry | `06_analysis/figures/supplementary/FigS7_allometry.png` and `.pdf` | `25_supp_S5_S6_S7_thresholds_growth.R` | Keep. |
| Fig. S8 | Shared-range natural vs restoration comparison | `06_analysis/figures/supplementary/FigS8_natural_vs_restoration.png` and `.pdf` | `21_fig3_natural_vs_restoration.R` | Keep. This is the confounding-aware overlap-zone comparison. |
| Fig. S9 | Heterogeneity | `06_analysis/figures/supplementary/FigS9_heterogeneity.png` and `.pdf` | `26_supp_S8_S9.R` | Keep. |
| Fig. S10 | Context comparison | `06_analysis/figures/supplementary/FigS10_context_comparison.png` and `.pdf` | `27_supp_S10_S11.R` | Keep. |
| Fig. S11 | Climate demography | `06_analysis/figures/supplementary/FigS11_climate_demography.png` and `.pdf` | `27_supp_S10_S11.R` | Keep. |
| Fig. S12 | Sensitivity | `06_analysis/figures/supplementary/FigS12_sensitivity.png` and `.pdf` | `28_supp_S12_S13_S14.R` | Keep. |
| Fig. S13 | Cross-validation | `06_analysis/figures/supplementary/FigS13_cross_validation.png` and `.pdf` | `28_supp_S12_S13_S14.R` | Keep. `FigS13_sensitivity.*` remains archived/legacy only. |
| Fig. S14 | Population projections | `06_analysis/figures/supplementary/FigS14_population_projections.png` and `.pdf` | `28_supp_S12_S13_S14.R` | Keep. |
| Fig. S15 | Regional survival | `06_analysis/figures/supplementary/FigS15_regional_survival.png` and `.pdf` | `20c_fig_regional_survival.R` | Keep. |
| Fig. S16 | Shrinkage / retrogression summary | `06_analysis/figures/supplementary/FigS16_shrinkage_retrogression_summary.png` and `.pdf` | `36_shrinkage_retrogression_summary.R` | Keep. This formalizes partial mortality as a first-class demographic result. |
| Fig. S17 | Disturbance-by-size interaction | `06_analysis/figures/supplementary/FigS17_disturbance_size_interaction.png` and `.pdf` | `37_disturbance_size_interaction.R` | Keep. Strong survival interaction support. |
| Fig. S18 | Disturbance chronology / summary | `06_analysis/figures/supplementary/FigS18_disturbance_summary.png` and `.pdf` | `34_disturbance_summaries.R` | Keep. This is the formal disturbance-context figure. |
| Fig. S19 | Restoration subtype sensitivity | `06_analysis/figures/supplementary/FigS19_restoration_subtype_sensitivity.png` and `.pdf` | `39_restoration_subtype_sensitivity.R` | Keep. This is the main subtype-specific restoration support figure. |

## Formal Supplementary Tables

| Number | Title / concept | Canonical filename | Generating source | Decision |
|---|---|---|---|---|
| Table S1 | Disturbance chronology used in the demographic synthesis | `07_reporting/tables/TableS1_disturbance_chronology.md` and `.csv` | `34_disturbance_summaries.R` | Keep. |
| Table S2 | Study-window disturbance coverage audit | `07_reporting/tables/TableS2_study_window_disturbance_audit.md` | `38_study_window_disturbance_audit.R` | Keep. |
| Table S3 | Size-class synthesis for demographic risk and restoration interpretation | `07_reporting/tables/size_class_synthesis_table.md` | reporting synthesis | Keep as manuscript-supporting synthesis table if space permits; otherwise retain as revision-support material. |

## Internal Support Outputs To Retain But Not Number As Final Figures

| Product | Why it stays internal |
|---|---|
| `06_analysis/figures/manuscript/Fig4_size_class_survival.*` | Useful as a standalone bridge figure, but panel c of Fig. 2 and Table S3 already cover the size-class synthesis in the current paper structure. |
| `06_analysis/figures/manuscript/Fig5_expanded_forest_plot.png` | Useful internal or revision-support asset, but not part of the current numbered main-text set. |
| `06_analysis/figures/manuscript/Fig6_population_model.png` | Legacy duplicate naming branch relative to `Fig4_population_model.*`. |
| `06_analysis/figures/supplementary/FigS8_forest_plots.*` | Keep as an internal heterogeneity companion, but the current numbered S8 in the manuscript-facing set is the shared-range natural vs restoration figure. |
| `06_analysis/figures/supplementary/FigSXX_disturbance_sensitivity.*` | Useful sensitivity support output, but no longer needed as a numbered figure once S17, S18, Table S1, and Table S2 are in place. |
| `06_analysis/figures/supplementary/FigSXX_heat_stress_survival.*` | Exploratory context figure. |
| `06_analysis/figures/supplementary/FigSXX_natural_vs_restoration_comparison.*` | Superseded by Fig. S8 plus Fig. S19. |
| `06_analysis/figures/supplementary/disturbance_timeline_highres.*` and `disturbance_regional_severity.*` | Keep as build components / internal reporting assets rather than numbered final figures. |

## Bottom Line

The final manuscript-facing set is now organized around four main threads:

1. data landscape
2. size dependence and nonlinearity
3. Caribbean-wide synthesis and heterogeneity
4. population viability under a disturbance-shaped demographic regime

The new completeness work lands in the supplement as S16-S19 plus Tables S1-S2, which is where it can strengthen the paper without forcing a disruptive rewrite of the current main-text figure sequence.
