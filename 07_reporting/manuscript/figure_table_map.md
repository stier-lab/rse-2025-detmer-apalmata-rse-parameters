# Figure and Table Map

Canonical mapping of every manuscript and supplementary figure/table to its generating script and output file. This is the single source of truth for what belongs in the numbered build.

---

## Manuscript Figures (Fig 1--4)

| Figure | Script | Output filename |
|--------|--------|-----------------|
| Fig 1 — Study landscape | `18_fig1_study_landscape.R` | `Fig1_study_landscape` (.png, .pdf) |
| Fig 2 — Demographic rates | `19_fig2_demographic_rates.R` | `Fig2_demographic_rates` (.png, .pdf) |
| Fig 3 — Caribbean synthesis | `20b_fig_expanded_forest_plot.R` | `Fig3_caribbean_synthesis` (.png, .pdf) |
| Fig 4 — Population viability | `22_fig6_population_model.R` | `Fig4_population_model` (.png, .pdf) |

**Notes:** Script 22 filename says "fig6" but its output is Fig 4 (historical artifact). Script 21 filename says "fig3" but its output is FigS8. Neither script has been renamed to avoid breaking `run_all.R`.

---

## Supplementary Figures (FigS1--FigS29)

| Figure | Script | Output filename | Notes |
|--------|--------|-----------------|-------|
| FigS1 — Size distribution | `18_fig1_study_landscape.R` | `FigS1_size_distribution` | Secondary output from the Fig 1 script |
| FigS2 — Data gaps | `23_figS2_data_gaps.R` | `FigS2_data_gaps` | Script number 23 shared with `23_verification.R` |
| FigS3 — Model diagnostics | `24_supp_S3_S4.R` | `FigS3_model_diagnostics` | |
| FigS4 — Model selection | `24_supp_S3_S4.R` | `FigS4_model_selection` | |
| FigS5 — Threshold analysis | `25_supp_S5_S6_S7_thresholds_growth.R` | `FigS5_threshold_analysis` | |
| FigS6 — AGR vs RGR | `25_supp_S5_S6_S7_thresholds_growth.R` | `FigS6_agr_vs_rgr` | |
| FigS7 — Allometry | `25_supp_S5_S6_S7_thresholds_growth.R` | `FigS7_allometry` | |
| FigS8 — Natural vs restoration | `21_fig3_natural_vs_restoration.R` | `FigS8_natural_vs_restoration` | Confounding-aware overlap-zone comparison |
| FigS9 — Heterogeneity | `26_supp_S8_S9.R` | `FigS9_heterogeneity` | |
| FigS10 — Context comparison | `27_supp_S10_S11.R` | `FigS10_context_comparison` | |
| FigS11 — Climate demography | `27_supp_S10_S11.R` | `FigS11_climate_demography` | |
| FigS12 — Sensitivity | `28_supp_S12_S13_S14.R` | `FigS12_sensitivity` | |
| FigS13 — Cross-validation | `28_supp_S12_S13_S14.R` | `FigS13_cross_validation` | |
| FigS14 — Population projections | `28_supp_S12_S13_S14.R` | `FigS14_population_projections` | |
| FigS15 — Regional survival | `20c_fig_regional_survival.R` | `FigS15_regional_survival` | |
| FigS16 — Shrinkage / retrogression | `36_shrinkage_retrogression_summary.R` | `FigS16_shrinkage_retrogression_summary` | |
| FigS17 — Disturbance x size | `37_disturbance_size_interaction.R` | `FigS17_disturbance_size_interaction` | |
| FigS18 — Disturbance summary | `34_disturbance_summaries.R` | `FigS18_disturbance_summary` | |
| FigS19 — Restoration subtype sensitivity | `39_restoration_subtype_sensitivity.R` | `FigS19_restoration_subtype_sensitivity` | |
| FigS20 — Annual survival time series | `49_annual_survival_timeseries.R` | `FigS20_annual_survival_timeseries` | |
| FigS21 — Forest plots | `26_supp_S8_S9.R` | `FigS21_forest_plots` | Meta-analysis forest plots (overall + stratified) |
| FigS22 — Heatwave scenarios | `40_manzello_heatwave_scenarios.R` | `FigS22_heatwave_scenarios` | Manzello 2025 dose-response projections |
| FigS23 — Disturbance timeline | `32_disturbance_survival_analysis.R` | `FigS23_disturbance_timeline` | |
| FigS24 — Heat stress survival | `31_heat_stress_overlay.R` | `FigS24_heat_stress_survival` | |
| FigS25 — Disturbance sensitivity | `30_disturbance_sensitivity.R` | `FigS25_disturbance_sensitivity` | |
| FigS26 — Natural vs restoration comparison | `29_natural_vs_restoration.R` | `FigS26_natural_vs_restoration_comparison` | |
| FigS27 — Disturbance summary | (orphan — no generating script) | `FigS27_disturbance_summary` | |
| FigS28 — Temporal synthesis | `49b_temporal_synthesis_figure.R` | `FigS28_temporal_synthesis` | |
| FigS29 — Biological realism scenarios | `61_fig_biological_realism.R` | `FigS29_biological_realism` | 9-scenario sensitivity framework: tornado plot of Δλ, sexual vs fragmentation pathway share, 50-yr projection trajectories |

All output files live under `06_analysis/figures/manuscript/` (Fig 1--4) or `06_analysis/figures/supplementary/` (FigS1--S29) and are saved as both PNG and PDF.

---

## Supplementary Tables

| Table | Script / source | Output file |
|-------|----------------|-------------|
| Table S1 — Disturbance chronology | `34_disturbance_summaries.R` | `07_reporting/manuscript/tables/TableS1_disturbance_chronology.md` and `.csv` |
| Table S2 — Study-window disturbance audit | `38_study_window_disturbance_audit.R` | `07_reporting/manuscript/tables/TableS2_study_window_disturbance_audit.md` |
| Table S3 — Size-class synthesis | Reporting synthesis | `07_reporting/manuscript/tables/size_class_synthesis_table.md` |

---

## Advanced Model Figures (unnumbered, descriptive names)

Produced by scripts 42--47. Not part of the numbered supplement.

| Script | Output filename | Content |
|--------|-----------------|---------|
| `42_joint_longitudinal_survival_model.R` | `joint_longitudinal_risk_curve` | Joint longitudinal survival risk curve |
| `43_stochastic_ipm_disturbance_model.R` | `stochastic_ipm_projection_trajectories` | Stochastic IPM disturbance projections |
| `44_regime_switching_model.R` | `regime_switching_year_states` | Hidden-state regime classification |
| `45_distributed_lag_disturbance_model.R` | `distributed_lag_coefficients` | Distributed-lag model coefficients |
| `47_spatiotemporal_hierarchical_model.R` | `spatiotemporal_hierarchical_summary` | Spatiotemporal hierarchical GAMM summary |

---

## Non-Figure-Producing Scripts

Scripts that produce data, tables, or verification output only (no figures):

`00_standardize_neely.R`, `01_data_preparation.R`, `02_survival_thresholds.R`, `03_growth_thresholds.R`, `04_growth_rate_comparison.R`, `05_variance_partitioning.R`, `06_data_gap_analysis.R`, `07_integrate_summary_data.R`, `08_climate_demography.R`, `09_power_analysis.R`, `10_cross_validation.R`, `11_context_comparison.R`, `12_model_selection.R`, `13_transition_matrix.R`, `14_meta_analysis.R`, `14b_expanded_meta_analysis.R`, `15_heterogeneity_analysis.R`, `16_sensitivity_analysis.R`, `17_update_parameter_lists.R`, `23_verification.R`, `31b_verify_dhw.R`, `33_hurricane_exposure.R`, `35_curate_literature_scope.R`, `38_study_window_disturbance_audit.R`, `41_multistate_transition_model.R`, `46_recurrent_event_frailty_model.R`, `48_pipeline_refresh_audit.R`.

---

## Known Naming Issues

1. **Script 22 ("fig6") vs output (Fig 4):** Historical artifact from earlier numbering.
2. **Script 21 ("fig3") vs output (FigS8):** Historical artifact from earlier numbering.
3. **Script 20 output ("Fig4_size_class_survival"):** Collides with real Fig 4. Working figure whose content was absorbed into Fig 2c.
4. **Script 23 number collision:** `23_figS2_data_gaps.R` (figure) and `23_verification.R` (verification) share number 23.
