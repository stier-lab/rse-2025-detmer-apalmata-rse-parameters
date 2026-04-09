# Analysis Scripts

R analysis pipeline for *Acropora palmata* size-structured demographic parameter estimation. This directory holds the maintained execution surface: standardization helpers, numbered analyses, manuscript figure builders, scenario extensions, advanced dynamic models, and verification utilities.

For directory-level navigation, see [06_analysis/README.md](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/README.md).
For the parent goal, paper goals, and current completeness roadmap, see [paper_scope_and_analysis_roadmap.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/paper_scope_and_analysis_roadmap.md).
For the current core/supporting/exploratory labeling, see [analysis_inventory_labels.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/analysis_inventory_labels.md).
For the retained manuscript-facing figure/table set, see [final_figure_table_set.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/final_figure_table_set.md).
For the script-by-script diagnostics and outstanding-issues review, see [model_audit/README.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/model_audit/README.md).

---

## Numbering Scheme

There are currently **54 top-level R scripts** in this directory. The numbered scripts define the main analytical surface; `00_*` helpers and `23_verification.R` sit around that numbered core.

Scripts are numbered sequentially (01--47, with 14b, 20b, 20c, 31b variants) in pipeline execution order:

| Range | Category | Description |
|-------|----------|-------------|
| **01** | Data preparation | Loading, cleaning, standardizing raw data |
| **02--07** | Core analysis | Survival, growth, variance, gaps, integration |
| **08--12** | Robustness & supplementary | Climate, power, cross-validation, context, model selection |
| **13--17** | Synthesis | Matrix model, meta-analysis, heterogeneity, sensitivity, parameters |
| **18--22** | Main figures & candidates | Publication-ready figures plus manuscript-candidate support figures |
| **23** | Data gaps + verification | Fig S2 data gaps heatmap; end-to-end output checks |
| **24--28** | Supplementary figures | Publication-ready supplementary figures (Fig S3--S14) |
| **29--40** | Context + disturbance | Natural/restoration sensitivity, disturbance overlays, audit products, completeness extensions, and scenario layers |
| **41--47** | Advanced dynamic models | Multistate, joint longitudinal-survival, stochastic IPM, regime-switching, distributed-lag, recurrent-event, and spatiotemporal extensions |

## Canonical Entry Points

- `run_all.R`
  Full maintained pipeline orchestrator. This is the canonical rerun path after adding or updating standardized site data.
- `01_data_preparation.R`
  Builds the prepared panels used by almost every downstream script and validates the maintained standardized inputs against [data_registry.csv](/Users/adrianstier/Detmer-2025-coral-parameters/05_data/standardized/data_registry.csv).
- `19_fig2_demographic_rates.R`, `20b_fig_expanded_forest_plot.R`, `22_fig6_population_model.R`
  Core manuscript-facing figure builders.
- `34_disturbance_summaries.R`, `36_shrinkage_retrogression_summary.R`, `37_disturbance_size_interaction.R`, `38_study_window_disturbance_audit.R`, `39_restoration_subtype_sensitivity.R`
  Completeness layer that supports the disturbance/restoration side of the paper.
- `23_verification.R`, `48_pipeline_refresh_audit.R`
  Canonical stats/assertion generation plus the final inventory/artifact refresh layer that updates machine-readable reporting outputs.

## Core Manuscript Pipeline (start here)

If you want to understand the paper, read these 8 scripts in order:

| Script | What it does | Produces |
|--------|-------------|----------|
| 01_data_preparation.R | Load and clean all data; build cell-weighted survival dataset | prepared_survival_data.rds, prepared_survival_cells.rds |
| 13_transition_matrix.R | Build 5x5 Lefkovitch matrix, compute lambda, bootstrap uncertainty | transition_matrix.csv, lambda_bootstrap_samples.rds |
| 14b_expanded_meta_analysis.R | Three-level meta-analysis of survival across 17 studies | expanded_meta_analysis_results.csv |
| 17_update_parameter_lists.R | Generate RSE model parameters | parameter_lists/*.rds |
| 18_fig1_study_landscape.R | Figure 1: Caribbean map + data availability | Fig1_study_landscape.pdf |
| 19_fig2_demographic_rates.R | Figure 2: Survival + growth GAMs | Fig2_demographic_rates.pdf |
| 20b_fig_expanded_forest_plot.R | Figure 3: Forest plot + regional survival | Fig3_caribbean_synthesis.pdf |
| 22_fig6_population_model.R | Figure 4: Transition matrix, elasticity, lambda | Fig4_population_model.pdf |

---

## Pipeline Dependency Flow

```
01_data_preparation
        │
        ├── prepared_survival_data.rds ─────────────┐
        ├── prepared_growth_data.rds ───────────────┤
        ├── prepared_survival_cells.rds ──┐         │
        │   (individual + summary,        │         │
        │    cell-level weighted)          │         │
        ▼                                 │         ▼
┌───────────────────────────┐             │ ┌───────────────────┐
│  Core Analysis (02--07)   │             │ │  07_integrate_    │
│  02 survival thresholds   │             │ │  summary_data     │
│  03 growth thresholds     │             │ │  (diagnostic only)│
│  04 growth rate comparison│             │ └─────────┬─────────┘
│  05 variance partitioning │             │           │
│  06 data gap analysis     │             │           ▼
└───────────┬───────────────┘             │ ┌───────────────────┐
            │                             │ │  Robustness       │
            │                             │ │  08 climate       │
            │                             │ │  09 power         │
            │                             │ │  10 cross-valid.  │
            │                             │ │  11 context       │
            │                             │ │  12 model select. │
            │                             │ └─────────┬─────────┘
            │                             │           │
            └───────────────┬─────────────┴───────────┘
                            ▼
                  ┌────────────────────────┐
                  │  Synthesis             │
                  │  13 matrix model *     │
                  │  14 meta-analysis      │
                  │  14b expanded meta     │
                  │  15 heterogeneity      │
                  │  16 sensitivity        │
                  │  17 parameters *       │
                  │  * uses cells dataset  │
                  └─────────┬──────────────┘
                            ▼
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                  ▼
┌──────────────────┐ ┌────────────────┐ ┌────────────────┐
│  Main Figures    │ │  Data Gaps +   │ │  Supp. Figures │
│  18 Fig 1 + S1   │ │  Verification  │ │  24 S3-S4      │
│  19 Fig 2        │ │  23 Fig S2     │ │  25 S5-S7      │
│  20 support fig  │ │  23 verification│ │  26 S8-S9      │
│  20b Fig 3       │ └────────────────┘ │  27 S10-S11    │
│  20c Fig S15     │                    │  28 S12-S14    │
│  21 Fig S8       │                    └────────────────┘
│  22 Fig 4        │
└──────────────────┘
```

---

## Script Reference

### 01 -- Data Preparation

| Script | Description | Key Outputs |
|--------|-------------|-------------|
| `01_data_preparation.R` | Load, clean, and standardize data from 18+ studies; assign size classes (SC1--SC5); create analysis-ready variables; build cell-level survival dataset combining individual + summary data with sample-size weights | `prepared_survival_data.rds`, `prepared_growth_data.rds`, `prepared_survival_cells.rds` |

### 02--07 -- Core Analysis

These scripts carry the project's main nonlinearity work. Scripts `02`, `03`, and `04` are the size-threshold and curvature analysis surface; script `25` is the figure-production layer for those results.

| Script | Description | Key Outputs |
|--------|-------------|-------------|
| `02_survival_thresholds.R` | Size-survival threshold detection via GAM second derivatives, hockey-stick regression, cluster bootstrap, LOSO sensitivity | `survival_thresholds.csv`, `survival_diagnostics.csv` |
| `03_growth_thresholds.R` | Size-growth threshold detection for absolute growth, relative growth rate, and probability of positive growth | `growth_thresholds.csv`, `growth_diagnostics.csv` |
| `04_growth_rate_comparison.R` | AGR vs RGR comparison, allometric relationships, size-scaling analysis (~1,970 lines, largest script) | `growth_rate_comparison.csv`, allometric model outputs |
| `05_variance_partitioning.R` | Variance decomposition across size, space, and time dimensions | `variance_partitioning.csv` |
| `06_data_gap_analysis.R` | Certainty scoring by size class and region; gap prioritization for future research | `gap_prioritization.csv`, certainty matrices |
| `07_integrate_summary_data.R` | Diagnostic forest plots and regional estimates combining individual + summary data (descriptive only; parameter estimation now uses `prepared_survival_cells.rds` via scripts 13/17) | Combined datasets (not read by downstream parameter scripts) |

### 08--12 -- Robustness & Supplementary

| Script | Description | Key Outputs |
|--------|-------------|-------------|
| `08_climate_demography.R` | Climate-demography integration with maintained DHW overlay support, temporal trends, and climate-vulnerability summaries | `climate_survival_effects.csv`, `climate_dhw_coverage.csv`, `climate_dhw_glmm.csv` |
| `09_power_analysis.R` | Statistical power calculations for future study design | `power_analysis_*.csv` |
| `10_cross_validation.R` | Leave-one-study-out cross-validation of survival and growth models | `cross_validation_results.csv` |
| `11_context_comparison.R` | Field vs nursery vs laboratory context effects on demographic rates | `context_*.csv` |
| `12_model_selection.R` | Model comparison tables (AIC, BIC, R-squared) across candidate models | `model_selection_*.csv` |

### 13--17 -- Synthesis

| Script | Description | Key Outputs |
|--------|-------------|-------------|
| `13_transition_matrix.R` | 5x5 Lefkovitch population projection matrix, eigenvalue analysis (lambda), elasticity analysis, bootstrap uncertainty, and explicit leverage exports. Survival rates from cell-level weighted data (`prepared_survival_cells.rds`, individual + summary); growth from individual records. | `transition_matrix.csv`, `elasticity_matrix.csv`, `population_parameters.csv`, `transition_matrix_imputation_sensitivity.csv`, `transition_matrix_model_diagnostics.csv` |
| `14_meta_analysis.R` | Formal random-effects meta-analysis (k=5 studies), Knapp-Hartung adjustment, moderator analysis, subgroup analyses | `meta_analysis_results.csv`, `meta_analysis_study_effects.csv`, `meta_analysis_stratified.csv` |
| `14b_expanded_meta_analysis.R` | Two-tier expanded meta-analysis (17 studies, 22 effects), individual + summary data, clustered natural-vs-restoration moderator analysis, and primary-model jackknife diagnostics | `expanded_meta_analysis_results.csv`, `expanded_meta_analysis_study_effects.csv`, `expanded_meta_primary_model_diagnostics.csv`, `expanded_meta_primary_jackknife.csv`, `expanded_meta_moderator_diagnostics.csv` |
| `15_heterogeneity_analysis.R` | I-squared, Q-tests, heterogeneity source identification, between-study variance decomposition | `heterogeneity_analysis.csv` |
| `16_sensitivity_analysis.R` | Leave-one-study-out sensitivity, elasticity perturbation, NOAA-dominance checks | `sensitivity_*.csv` |
| `17_update_parameter_lists.R` | Serialize bootstrap parameter distributions to RDS format for the web platform API. Field and nursery survival use cell-level weighted data (individual + summary); growth and lab survival use individual records. | `parameter_lists/*.rds` |

### 18--28 -- Manuscript Figures

| Script | Description | Key Outputs |
|--------|-------------|-------------|
| `18_fig1_study_landscape.R` | Figure 1: Study landscape (Caribbean map, 16 studies) + Fig S1 size dist | `figures/manuscript/Fig1_*` |
| `19_fig2_demographic_rates.R` | Figure 2: Demographic rates — survival + RGR vs size | `figures/manuscript/Fig2_*` |
| `20_fig_size_class_survival_synthesis.R` | Standalone size-class survival synthesis figure used as manuscript-support output | `figures/manuscript/Fig4_size_class_survival.*` |
| `20b_fig_expanded_forest_plot.R` | Figure 3: Caribbean-wide survival synthesis (forest + regional) | `figures/manuscript/Fig3_*` |
| `20c_fig_regional_survival.R` | Figure S15: Regional survival variation | `figures/supplementary/FigS15_*` |
| `21_fig3_natural_vs_restoration.R` | Figure S8: Shared-range natural vs restoration comparison | `figures/supplementary/FigS8_*` |
| `22_fig6_population_model.R` | Figure 4: Population model — elasticity, bootstrap lambda, LOSO | `figures/manuscript/Fig4_population_model.*` |
| `23_figS2_data_gaps.R` | Figure S2: Data gaps heatmap | `figures/supplementary/FigS2_*` |
| `24_supp_S3_S4.R` | Figure S3: Survival coefficients; Figure S4: Growth coefficients | `figures/supplementary/FigS3_*`, `FigS4_*` |
| `25_supp_S5_S6_S7_thresholds_growth.R` | Figure S5--S7: Threshold detection, growth diagnostics | `figures/supplementary/FigS5_*`, `FigS6_*`, `FigS7_*` |
| `26_supp_S8_S9.R` | Figure S8--S9: Meta-analysis forest plots and heterogeneity decomposition | `figures/supplementary/FigS8_*`, `FigS9_*` |
| `27_supp_S10_S11.R` | Figure S10--S11: Model selection comparison | `figures/supplementary/FigS10_*`, `FigS11_*` |
| `28_supp_S12_S13_S14.R` | Figure S12--S14: Diagnostics, residuals, additional robustness | `figures/supplementary/FigS12_*`, `FigS13_*`, `FigS14_*` |

### 29--40 -- Context, Disturbance, Completeness, and Heatwave Extensions

| Script | Description | Key Outputs |
|--------|-------------|-------------|
| `29_natural_vs_restoration.R` | Expanded natural vs restoration comparison outside the main figure script surface; Florida Keys size-matched subsection is descriptive only because study and population type are aliased | `natural_vs_restoration_*.csv` |
| `30_disturbance_sensitivity.R` | Disturbance sensitivity analysis using baseline-exclusion vs chronic-context distinctions, now with scenario-status and within-scenario influence exports | `disturbance_sensitivity_*.csv`, `disturbance_interval_comparison.csv` |
| `31_heat_stress_overlay.R` | Heat stress overlay against demographic intervals, with verified-cache preference and sparse-support descriptive framing | `heat_stress_*.csv` |
| `31b_verify_dhw.R` | Verification utilities for DHW inputs and site-year joins | `dhw_verification_*.csv` |
| `32_disturbance_survival_analysis.R` | Disturbance regime overlays and survival analyses with verified-DHW preference and DHW support auditing | `disturbance_survival_glmm.csv`, `disturbance_dhw_coverage.csv`, disturbance timeline figures |
| `33_hurricane_exposure.R` | Hurricane exposure summaries by region and category | `hurricane_exposure_*.csv` |
| `34_disturbance_summaries.R` | Publication-quality disturbance catalogs, summary tables, and summary figures | `disturbance_event_catalog.csv`, `disturbance_summary_by_*.csv` |
| `35_curate_literature_scope.R` | Scope-screen life-history and disturbance evidence tables into analysis-ready subsets | `*_analysis.csv` literature tables |
| `36_shrinkage_retrogression_summary.R` | Standalone synthesis of shrinkage frequency, tissue loss, and retrogression probabilities by size class and study | `shrinkage_retrogression_*.csv`, `retrogression_probability_by_size_class.csv`, `FigS16_shrinkage_retrogression_summary.*` |
| `37_disturbance_size_interaction.R` | Disturbance × size interaction analysis for survival and positive growth | `disturbance_size_*.csv`, `FigS17_disturbance_size_interaction.*` |
| `38_study_window_disturbance_audit.R` | Rebuild and audit study-window overlaps with the curated disturbance timeline | `study_window_disturbance_*.csv`, `TableS2_study_window_disturbance_audit.md` |
| `39_restoration_subtype_sensitivity.R` | Reclassify broad restoration fragments into defensible subtypes and summarize subtype-specific demography | `restoration_subtype_*.csv`, `FigS19_restoration_subtype_sensitivity.*` |
| `40_manzello_heatwave_scenarios.R` | Layer catastrophic heatwave mortality thresholds onto the chronic demographic regime via scenario projections | `manzello_dose_response.csv`, `heatwave_scenario_*.csv`, `FigS15_heatwave_scenarios.*` |

### 41--47 -- Advanced Dynamic Model Extensions

These scripts push beyond the main GLMM + matrix-model surface. They are best treated as advanced extensions until they are fully folded into the manuscript claim structure.

| Script | Description | Key Outputs |
|--------|-------------|-------------|
| `41_multistate_transition_model.R` | Interval-adjusted multistate size-class transition model with explicit death state and retrogression summaries | `multistate_*.csv` |
| `42_joint_longitudinal_survival_model.R` | Two-stage joint approximation linking live-size trajectory to interval mortality hazard | `joint_longitudinal_*.csv`, `joint_longitudinal_risk_curve.png` |
| `43_stochastic_ipm_disturbance_model.R` | Disturbance-conditioned stochastic IPM / kernel viability projection layer with explicit recruitment scenarios | `stochastic_ipm_*.csv`, `stochastic_ipm_recruitment_scenarios.csv`, `stochastic_ipm_projection_trajectories.*` |
| `44_regime_switching_model.R` | Hidden-state regime classification of annual survival-condition deviations | `regime_switching_*.csv`, `regime_switching_year_states.*` |
| `45_distributed_lag_disturbance_model.R` | Distributed-lag disturbance models for survival, positive growth, and RGR | `distributed_lag_*.csv`, `distributed_lag_coefficients.*` |
| `46_recurrent_event_frailty_model.R` | Colony-history recurrent-event shrinkage and terminal mortality frailty models | `recurrent_event_*.csv` |
| `47_spatiotemporal_hierarchical_model.R` | Spatiotemporal hierarchical GAMM layer over site coordinates and site-year structure | `spatiotemporal_*.csv`, `spatiotemporal_hierarchical_summary.*` |

### Utilities -- Verification & Shared Code

| Script | Description |
|--------|-------------|
| `run_all.R` | Master pipeline orchestrator -- runs all scripts in order |
| `23_verification.R` | End-to-end verification checks on outputs |
| `utils/shared_utilities.R` | Loader — sources all utility modules below |
| `utils/00_libraries.R` | Centralized package loading (core + optional) |
| `utils/00b_color_palette.R` | Color palettes: `OKABE_ITO`, `MANUSCRIPT_PALETTE`, `SIZE_CLASS_COLORS` |
| `utils/00c_analysis_constants.R` | Constants: `SIZE_BREAKS`, `SIZE_LABELS`, `N_STUDIES` |
| `utils/01_functions.R` | All shared functions: `theme_manuscript()`, `overdisp_test()`, `save_manuscript_fig()`, `geom_sc_boundaries()`, etc. |
| `utils/02_threshold_functions.R` | Detmer et al. (2025) threshold detection: `gratia` derivatives, nonlinearity gate, LOSO jackknife, 4 threshold definitions |

---

## Nonlinearity Workflow

If you specifically want the nonlinear size-dependence analyses, the canonical sequence is:

1. `01_data_preparation.R`
2. `02_survival_thresholds.R`
3. `03_growth_thresholds.R`
4. `04_growth_rate_comparison.R`
5. `25_supp_S5_S6_S7_thresholds_growth.R`

These scripts produce the threshold estimates, derivative diagnostics, allometric comparisons, and the manuscript-ready figure set for that analytical thread.

---

## Running the Pipeline

### Full pipeline (~45--60 minutes)

```bash
cd 06_analysis/scripts
Rscript run_all.R
```

### Automatic Refresh Surface

When `run_all.R` completes successfully, the maintained pipeline is expected to refresh not just model outputs and figures, but also the reporting surface used to keep manuscript-facing numbers in sync:

- [canonical_statistics.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/canonical_statistics.csv)
- [pipeline_assertion_checks.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/pipeline_assertion_checks.csv)
- [standardized_data_inventory.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/standardized_data_inventory.csv)
- [canonical_artifact_status.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/canonical_artifact_status.csv)
- [pipeline_refresh_report.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/generated/pipeline_refresh_report.md)
- [canonical_statistics.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/generated/canonical_statistics.md)

### Individual scripts

From the project root:
```bash
Rscript 06_analysis/scripts/01_data_preparation.R
Rscript 06_analysis/scripts/02_survival_thresholds.R
```

From the scripts directory:
```bash
cd 06_analysis/scripts
Rscript 01_data_preparation.R
Rscript 02_survival_thresholds.R
```

All scripts auto-detect the project root:
```r
if (file.exists("standardized_data")) {
  project_root <- "."
} else if (file.exists("../../standardized_data")) {
  project_root <- "../.."
}
```

### Adding a New Site

The maintained pattern is:

1. put raw source files in `05_data/original/`
2. standardize them in a `00_standardize_<site>.R` helper
3. append or rebuild the canonical tables under `05_data/standardized/`
4. update [data_registry.csv](/Users/adrianstier/Detmer-2025-coral-parameters/05_data/standardized/data_registry.csv) if the maintained schema changes
5. rerun `run_all.R`

---

## Output Directories

```
06_analysis/
├── output/                         # 286 generated CSV/RDS result files
│   ├── prepared_survival_data.rds   # Individual 0/1 records (from 01, used by 40+ scripts)
│   ├── prepared_growth_data.rds    # Individual growth records (from 01)
│   ├── prepared_survival_cells.rds # Cell-level ind+summary survival (from 01, used by 13,17)
│   ├── survival_*.csv              # Survival analysis (from 02)
│   ├── growth_*.csv                # Growth analysis (from 03, 04)
│   ├── variance_partitioning.csv   # Variance decomposition (from 05)
│   ├── gap_prioritization.csv      # Data gaps (from 06)
│   ├── transition_matrix.csv       # Population matrix (from 13)
│   ├── elasticity_matrix.csv       # Elasticity (from 13)
│   ├── meta_analysis_*.csv         # Meta-analysis (from 14)
│   ├── expanded_meta_*.csv         # Expanded meta-analysis (from 14b)
│   ├── sensitivity_*.csv           # Sensitivity (from 16)
│   └── model_selection_*.csv       # Model comparison (from 12)
│
├── figures/
│   ├── manuscript/                 # Canonical main-text figures + support variants
│   │   ├── Fig1_*.png/.pdf         # Main text
│   │   ├── Fig2_*.png/.pdf         # Main text
│   │   ├── Fig3_*.png/.pdf         # Main text
│   │   ├── Fig4_*.png/.pdf         # Main text
│   │   └── support-only variants   # e.g. Fig4_size_class_survival.*, Fig5_*, Fig6_*
│   │
│   └── supplementary/              # Canonical supplement + support-only variants
│       ├── FigS1_*.png/.pdf        # Size distribution (from 18)
│       ├── FigS2_*.png/.pdf        # Data gaps heatmap (from 23)
│       ├── FigS3--S15_*.png/.pdf   # Diagnostics, robustness, and regional survival
│       ├── FigS16--S19_*.png/.pdf  # Shrinkage, disturbance, and restoration completeness figures
│       ├── exploratory/
│       ├── diagnostics/
│       └── meta_analysis/
│
parameter_lists/                    # RDS files consumed by the web platform API (from 17)
```

---

## Key Results

| Metric | Value |
|--------|-------|
| Population growth rate (lambda) | 0.888 (95% CI: 0.740–0.959) |
| Most critical parameter | SC5 stasis (58.6% of matrix-cell elasticity) |
| Between-study heterogeneity | I-squared = 97.2% |
| NOAA data share | 78% of individual-level observations |
| Total observations | 7,346 individual records + 332 summary records from 16 studies (cell-weighted) |

---

## R Package Dependencies

```r
# Core
library(tidyverse)
library(readr)

# Statistical models
library(mgcv)        # GAMs
library(lme4)        # GLMMs
library(lmerTest)    # GLMM p-values
library(broom)       # Model tidying

# Meta-analysis
library(metafor)     # Random-effects models

# Threshold detection (Detmer et al. 2025)
library(gratia)      # GAM derivatives with simultaneous CIs
library(pracma)      # findpeaks() for derivative peak detection

# Visualization
library(ggplot2)
library(patchwork)   # Multi-panel figures
library(scales)

# Bootstrap & validation
library(boot)
library(caret)
```

---

*Last updated: 2026-04-07*
