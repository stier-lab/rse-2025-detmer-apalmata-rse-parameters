# Script-to-Figure Mapping

Generated: 2026-04-07

This document maps every figure-producing script to its output figure(s).
Script filenames are intentionally NOT renamed to avoid breaking `run_all.R`
and cross-references. See the Notes column for naming quirks.

---

## Manuscript Figures (Fig 1--4)

| Script | Manuscript Figure | Output Filename | Notes |
|--------|------------------|-----------------|-------|
| 18_fig1_study_landscape.R | Fig 1 | Fig1_study_landscape | Also produces FigS1 (see below) |
| 19_fig2_demographic_rates.R | Fig 2 | Fig2_demographic_rates | 3 panels: survival GAM, RGR GAM, size-class synthesis |
| 20b_fig_expanded_forest_plot.R | Fig 3 | Fig3_caribbean_synthesis | k=17 forest plot + regional survival |
| 22_fig6_population_model.R | Fig 4 | Fig4_population_model | **Filename says "fig6" but output is Fig 4** |

---

## Supplementary Figures (FigS1--FigS20)

| Script | Supp Figure | Output Filename | Notes |
|--------|------------|-----------------|-------|
| 18_fig1_study_landscape.R | FigS1 | FigS1_size_distribution | Secondary output from the Fig 1 script |
| 23_figS2_data_gaps.R | FigS2 | FigS2_data_gaps | **Script number 23 shared with 23_verification.R** |
| 24_supp_S3_S4.R | FigS3 | FigS3_model_diagnostics | |
| 24_supp_S3_S4.R | FigS4 | FigS4_model_selection | |
| 25_supp_S5_S6_S7_thresholds_growth.R | FigS5 | FigS5_threshold_analysis | |
| 25_supp_S5_S6_S7_thresholds_growth.R | FigS6 | FigS6_agr_vs_rgr | |
| 25_supp_S5_S6_S7_thresholds_growth.R | FigS7 | FigS7_allometry | |
| 21_fig3_natural_vs_restoration.R | FigS8 | FigS8_natural_vs_restoration | **Filename says "fig3" but output is FigS8** |
| 26_supp_S8_S9.R | FigS8 | FigS8_forest_plots | **NUMBER COLLISION with FigS8 above** |
| 26_supp_S8_S9.R | FigS9 | FigS9_heterogeneity | |
| 27_supp_S10_S11.R | FigS10 | FigS10_context_comparison | |
| 27_supp_S10_S11.R | FigS11 | FigS11_climate_demography | |
| 28_supp_S12_S13_S14.R | FigS12 | FigS12_sensitivity | |
| 28_supp_S12_S13_S14.R | FigS13 | FigS13_cross_validation | |
| 28_supp_S12_S13_S14.R | FigS14 | FigS14_population_projections | |
| 20c_fig_regional_survival.R | FigS15 | FigS15_regional_survival | |
| 40_manzello_heatwave_scenarios.R | FigS15 | FigS15_heatwave_scenarios | **NUMBER COLLISION with FigS15 above** |
| 36_shrinkage_retrogression_summary.R | FigS16 | FigS16_shrinkage_retrogression_summary | Also saves unnumbered duplicate `shrinkage_retrogression_summary` |
| 37_disturbance_size_interaction.R | FigS17 | FigS17_disturbance_size_interaction | Also saves unnumbered duplicate `disturbance_size_interaction` |
| 34_disturbance_summaries.R | FigS18 | FigS18_disturbance_summary | Also saves `disturbance_timeline_highres` and `disturbance_regional_severity` |
| 39_restoration_subtype_sensitivity.R | FigS19 | FigS19_restoration_subtype_sensitivity | Also saves unnumbered duplicate `restoration_subtype_sensitivity` |
| 49_annual_survival_timeseries.R | FigS20 | FigS20_annual_survival_timeseries | |

---

## Unnumbered Supplementary Figures (FigSXX_*)

These figures exist on disk but have not been assigned final supplementary numbers.

| Script | Output Filename | Content |
|--------|-----------------|---------|
| 29_natural_vs_restoration.R | FigSXX_natural_vs_restoration_comparison | Extended natural vs restoration within-region comparison |
| 30_disturbance_sensitivity.R | FigSXX_disturbance_sensitivity | Disturbance sensitivity scenarios |
| 31_heat_stress_overlay.R | FigSXX_heat_stress_survival | Heat stress (DHW) overlay on survival |
| 32_disturbance_survival_analysis.R | FigSXX_disturbance_timeline | Disturbance event timeline |
| 50_temporal_synthesis_figure.R | FigSXX_temporal_synthesis | Stochastic projections + regime + heatwave lambda (3 panels) |

---

## Advanced Model Figures (unnumbered, descriptive names)

These are produced by scripts 42--47 and saved with descriptive names rather than FigS numbers.

| Script | Output Filename | Content |
|--------|-----------------|---------|
| 42_joint_longitudinal_survival_model.R | joint_longitudinal_risk_curve | Joint longitudinal survival risk curve (PNG only, no PDF) |
| 43_stochastic_ipm_disturbance_model.R | stochastic_ipm_projection_trajectories | Stochastic IPM disturbance projections |
| 44_regime_switching_model.R | regime_switching_year_states | Hidden-state regime classification |
| 45_distributed_lag_disturbance_model.R | distributed_lag_coefficients | Distributed-lag model coefficients |
| 47_spatiotemporal_hierarchical_model.R | spatiotemporal_hierarchical_summary | Spatiotemporal hierarchical GAMM summary |

---

## Support/Working Figures (historical names, not in supplement)

| Script | Output Filename | Notes |
|--------|-----------------|-------|
| 20_fig_size_class_survival_synthesis.R | Fig4_size_class_survival | **NOT manuscript Fig 4.** Historical artifact; content absorbed into Fig 2c. Real Fig 4 is from script 22. |

---

## Non-Figure-Producing Scripts

The following scripts produce data/tables/verification output only (no figures):

| Script | Purpose |
|--------|---------|
| 00_standardize_neely.R | Neely data standardization |
| 01_data_preparation.R | Data prep and cleaning |
| 02_survival_thresholds.R | Survival threshold detection |
| 03_growth_thresholds.R | Growth threshold detection |
| 04_growth_rate_comparison.R | Growth rate analysis |
| 05_variance_partitioning.R | Variance partitioning |
| 06_data_gap_analysis.R | Data gap analysis |
| 07_integrate_summary_data.R | Summary data integration |
| 08_climate_demography.R | Climate-demography analysis |
| 09_power_analysis.R | Statistical power analysis |
| 10_cross_validation.R | Cross-validation |
| 11_context_comparison.R | Context comparison |
| 13_transition_matrix.R | Lefkovitch transition matrix |
| 14_meta_analysis.R | Meta-analysis (k=5) |
| 14b_expanded_meta_analysis.R | Expanded meta-analysis (k=17, 22 effects) |
| 15_heterogeneity_analysis.R | Heterogeneity decomposition |
| 16_sensitivity_analysis.R | Sensitivity / bootstrap lambda |
| 17_update_parameter_lists.R | Parameter list updates |
| 23_verification.R | Pipeline verification (shares number 23) |
| 31b_verify_dhw.R | DHW verification |
| 33_hurricane_exposure.R | IBTrACS hurricane exposure |
| 35_curate_literature_scope.R | Literature scope curation |
| 38_study_window_disturbance_audit.R | Study-window disturbance audit |
| 41_multistate_transition_model.R | Multistate transition model (no figures) |
| 46_recurrent_event_frailty_model.R | Recurrent event frailty model (no figures) |
| 48_pipeline_refresh_audit.R | Pipeline refresh audit (no figures) |

Note: Scripts 12_model_selection.R produces PNG-only exploratory plots (model_selection_survival.png, model_selection_growth.png, survival_coefficients.png) but no numbered supplementary figures.

---

## Known Naming Issues

1. **Script 22 filename ("fig6") vs output (Fig 4)**: Historical artifact from earlier numbering.
2. **Script 21 filename ("fig3") vs output (FigS8)**: Historical artifact from earlier numbering.
3. **Script 20 output ("Fig4_size_class_survival")**: Collides with real manuscript Fig 4. This is a working figure whose content was absorbed into Fig 2c.
4. **Script 23 number collision**: `23_figS2_data_gaps.R` (figure) and `23_verification.R` (verification) share number 23.
5. **FigS8 number collision**: `FigS8_natural_vs_restoration` (script 21) and `FigS8_forest_plots` (script 26) both use FigS8.
6. **FigS15 number collision**: `FigS15_regional_survival` (script 20c) and `FigS15_heatwave_scenarios` (script 40) both use FigS15.

None of these are renamed to avoid breaking the pipeline. Headers have been annotated with NOTE comments instead.
