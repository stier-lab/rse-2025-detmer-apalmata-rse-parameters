# Analysis Inventory Labels

This inventory labels the major analysis threads relative to the paper goals so the manuscript can separate core claims from supporting context and optional exploratory material.

## Core

| Scripts / analysis thread | Label | Why it is core |
|---|---|---|
| `01_data_preparation.R` | Core | Establishes the analysis-ready demographic dataset, size classes, and QC flags used everywhere else. |
| `02_survival_thresholds.R`, `03_growth_thresholds.R`, `04_growth_rate_comparison.R`, `25_supp_S5_S6_S7_thresholds_growth.R` | Core | Main nonlinearity and threshold workflow for size-dependent survival and growth. |
| `13_transition_matrix.R`, `22_fig6_population_model.R` | Core | Main population-viability engine: `lambda`, elasticity, stochastic projections, and LOSO sensitivity. |
| `14b_expanded_meta_analysis.R`, `15_heterogeneity_analysis.R`, `16_sensitivity_analysis.R` | Core | Main synthesis layer for pooled survival, heterogeneity, and robustness. |
| `30_disturbance_sensitivity.R`, `32_disturbance_survival_analysis.R`, `34_disturbance_summaries.R` | Core | Disturbance regime framework, baseline-exclusion logic, and disturbance mapping through time and space. |
| `36_shrinkage_retrogression_summary.R` | Core | Makes partial mortality and retrogression explicit as a major demographic process. |
| `37_disturbance_size_interaction.R` | Core | Tests whether disturbance effects vary by size, which is central to the paper question. |
| `38_study_window_disturbance_audit.R` | Core | Documents and audits disturbance assignment at the study-window level. |
| `39_restoration_subtype_sensitivity.R` | Core | Replaces the broad restoration-fragment bucket with biologically defensible subtype comparisons. |

## Supporting

| Scripts / analysis thread | Label | Why it is supporting |
|---|---|---|
| `05_variance_partitioning.R`, `06_data_gap_analysis.R`, `07_integrate_summary_data.R` | Supporting | Useful for uncertainty, coverage, and dataset assembly, but not main claims. |
| `08_climate_demography.R`, `09_power_analysis.R`, `10_cross_validation.R`, `11_context_comparison.R`, `12_model_selection.R` | Supporting | Robustness, climate context, and model-comparison layers that inform interpretation. |
| `14_meta_analysis.R`, `17_update_parameter_lists.R` | Supporting | Smaller or implementation-oriented synthesis outputs that support the main meta-analysis pipeline. |
| `18_fig1_study_landscape.R`, `19_fig2_demographic_rates.R`, `20_fig_size_class_survival_synthesis.R`, `20b_fig_expanded_forest_plot.R`, `20c_fig_regional_survival.R`, `21_fig3_natural_vs_restoration.R` | Supporting | Main manuscript figures and synthesis visuals, but still subordinate to the paper's core claims. |
| `23_figS2_data_gaps.R`, `24_supp_S3_S4.R`, `26_supp_S8_S9.R`, `27_supp_S10_S11.R`, `28_supp_S12_S13_S14.R` | Supporting | Diagnostic and supplementary figure layer for transparency and reproducibility. |
| `29_natural_vs_restoration.R`, `31_heat_stress_overlay.R`, `31b_verify_dhw.R`, `35_curate_literature_scope.R` | Supporting | Useful adjunct analyses and screening utilities, but not central to the main story. |

## Exploratory

| Scripts / analysis thread | Label | Why it is exploratory |
|---|---|---|
| `41_multistate_transition_model.R`, `42_joint_longitudinal_survival_model.R`, `43_stochastic_ipm_disturbance_model.R`, `44_regime_switching_model.R`, `45_distributed_lag_disturbance_model.R`, `46_recurrent_event_frailty_model.R`, `47_spatiotemporal_hierarchical_model.R` | Exploratory advanced | High-value dynamic extensions that materially deepen the repo, but they are not yet frozen into the manuscript claim structure or canonical figure/table set. |
| Former `FigSXX_*` variants (now assigned proper numbers FigS23--FigS28) and archived exploratory figure outputs | Exploratory | Now numbered and included in the canonical build surface. See `07_reporting/manuscript/figure_table_map.md`. |
| Any side comparisons not carried into `claim_output_crosswalk.md` | Exploratory | If they do not map to a paper claim, they should remain background only. |

## Practical Rule

If a script directly supports one of the paper goals in `paper_scope_and_analysis_roadmap.md`, it is core. If it adds robustness, transparency, or interpretation, it is supporting. If it does not map to a manuscript claim, keep it exploratory or archive it.
