# Analysis Scripts

R analysis pipeline for *Acropora palmata* size-structured demographic parameter estimation. Synthesizes 25,000+ observations from 18+ studies of Elkhorn Coral across the Caribbean.

---

## Numbering Scheme

Scripts are numbered sequentially (01--28, with 14b, 20b, 20c variants) in pipeline execution order:

| Range | Category | Description |
|-------|----------|-------------|
| **01** | Data preparation | Loading, cleaning, standardizing raw data |
| **02--07** | Core analysis | Survival, growth, variance, gaps, integration |
| **08--12** | Robustness & supplementary | Climate, power, cross-validation, context, model selection |
| **13--17** | Synthesis | Matrix model, meta-analysis, heterogeneity, sensitivity, parameters |
| **18--22** | Main figures | Publication-ready figures (Fig 1--6, Fig S1, S2, S15) |
| **23** | Data gaps + verification | Fig S2 data gaps heatmap; end-to-end output checks |
| **24--28** | Supplementary figures | Publication-ready supplementary figures (Fig S3--S14) |

---

## Pipeline Dependency Flow

```
01_data_preparation
        │
        ├───────────────────────────────────────────┐
        ▼                                           ▼
┌───────────────────────────┐             ┌───────────────────┐
│  Core Analysis (02--07)   │             │  07_integrate_    │
│  02 survival thresholds   │             │  summary_data     │
│  03 growth thresholds     │             └─────────┬─────────┘
│  04 growth rate comparison│                       │
│  05 variance partitioning │                       ▼
│  06 data gap analysis     │             ┌───────────────────┐
└───────────┬───────────────┘             │  Robustness       │
            │                             │  08 climate       │
            │                             │  09 power         │
            │                             │  10 cross-valid.  │
            │                             │  11 context       │
            │                             │  12 model select. │
            │                             └─────────┬─────────┘
            │                                       │
            └───────────────┬───────────────────────┘
                            ▼
                  ┌────────────────────────┐
                  │  Synthesis             │
                  │  13 matrix model       │
                  │  14 meta-analysis      │
                  │  14b expanded meta     │
                  │  15 heterogeneity      │
                  │  16 sensitivity        │
                  │  17 parameters         │
                  └─────────┬──────────────┘
                            ▼
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                  ▼
┌──────────────────┐ ┌────────────────┐ ┌────────────────┐
│  Main Figures    │ │  Data Gaps +   │ │  Supp. Figures │
│  18 Fig 1 + S1   │ │  Verification  │ │  24 S3-S4      │
│  19 Fig 2        │ │  23 Fig S2     │ │  25 S5-S7      │
│  20 Fig 4        │ │  23 verification│ │  26 S8-S9      │
│  20b Fig 5       │ └────────────────┘ │  27 S10-S11    │
│  20c Fig S15     │                    │  28 S12-S14    │
│  21 Fig 3        │                    └────────────────┘
│  22 Fig 6        │
└──────────────────┘
```

---

## Script Reference

### 01 -- Data Preparation

| Script | Description | Key Outputs |
|--------|-------------|-------------|
| `01_data_preparation.R` | Load, clean, and standardize data from 18+ studies; assign size classes (SC1--SC5); create analysis-ready variables | `prepared_survival_data.rds`, `prepared_growth_data.rds` |

### 02--07 -- Core Analysis

| Script | Description | Key Outputs |
|--------|-------------|-------------|
| `02_survival_thresholds.R` | Size-survival threshold detection via GAM second derivatives, hockey-stick regression, cluster bootstrap, LOSO sensitivity | `survival_thresholds.csv`, `survival_diagnostics.csv` |
| `03_growth_thresholds.R` | Size-growth threshold detection for absolute growth, relative growth rate, and probability of positive growth | `growth_thresholds.csv`, `growth_diagnostics.csv` |
| `04_growth_rate_comparison.R` | AGR vs RGR comparison, allometric relationships, size-scaling analysis (~1,970 lines, largest script) | `growth_rate_comparison.csv`, allometric model outputs |
| `05_variance_partitioning.R` | Variance decomposition across size, space, and time dimensions | `variance_partitioning.csv` |
| `06_data_gap_analysis.R` | Certainty scoring by size class and region; gap prioritization for future research | `gap_prioritization.csv`, certainty matrices |
| `07_integrate_summary_data.R` | Merge individual-level and study-level summary data sources into combined datasets | Combined datasets |

### 08--12 -- Robustness & Supplementary

| Script | Description | Key Outputs |
|--------|-------------|-------------|
| `08_climate_demography.R` | Climate-demography integration: ENSO indices, bleaching events, temperature effects on survival | `climate_survival_effects.csv` |
| `09_power_analysis.R` | Statistical power calculations for future study design | `power_analysis_*.csv` |
| `10_cross_validation.R` | Leave-one-study-out cross-validation of survival and growth models | `cross_validation_results.csv` |
| `11_context_comparison.R` | Field vs nursery vs laboratory context effects on demographic rates | `context_*.csv` |
| `12_model_selection.R` | Model comparison tables (AIC, BIC, R-squared) across candidate models | `model_selection_*.csv` |

### 13--17 -- Synthesis

| Script | Description | Key Outputs |
|--------|-------------|-------------|
| `13_transition_matrix.R` | 5x5 Lefkovitch population projection matrix, eigenvalue analysis (lambda), elasticity analysis, bootstrap uncertainty | `transition_matrix.csv`, `elasticity_matrix.csv`, `population_parameters.csv` |
| `14_meta_analysis.R` | Formal random-effects meta-analysis (k=5 studies), Knapp-Hartung adjustment, moderator analysis, subgroup analyses | `meta_analysis_results.csv`, `meta_analysis_study_effects.csv`, `meta_analysis_stratified.csv` |
| `14b_expanded_meta_analysis.R` | Two-tier expanded meta-analysis (k=16 studies), individual + summary data, natural vs restoration moderator | `expanded_meta_analysis_results.csv`, `expanded_meta_analysis_study_effects.csv` |
| `15_heterogeneity_analysis.R` | I-squared, Q-tests, heterogeneity source identification, between-study variance decomposition | `heterogeneity_analysis.csv` |
| `16_sensitivity_analysis.R` | Leave-one-study-out sensitivity, elasticity perturbation, NOAA-dominance checks | `sensitivity_*.csv` |
| `17_update_parameter_lists.R` | Serialize bootstrap parameter distributions to RDS format for the web platform API | `parameter_lists/*.rds` |

### 18--28 -- Manuscript Figures

| Script | Description | Key Outputs |
|--------|-------------|-------------|
| `18_fig1_study_landscape.R` | Figure 1: Study landscape (Caribbean map, 16 studies) + Fig S1 size dist | `figures/manuscript/Fig1_*` |
| `19_fig2_demographic_rates.R` | Figure 2: Demographic rates — survival + RGR vs size | `figures/manuscript/Fig2_*` |
| `20_fig_size_class_survival_synthesis.R` | Figure 4: Size-class survival synthesis (15 studies) | `figures/manuscript/Fig4_*` |
| `20b_fig_expanded_forest_plot.R` | Figure 5: Expanded forest plot (k=16 meta-analysis) | `figures/manuscript/Fig5_*` |
| `20c_fig_regional_survival.R` | Figure S15: Regional survival variation | `figures/supplementary/FigS15_*` |
| `21_fig3_natural_vs_restoration.R` | Figure 3: Natural vs restoration comparison | `figures/manuscript/Fig3_*` |
| `22_fig6_population_model.R` | Figure 6: Population model — elasticity, bootstrap lambda, LOSO | `figures/manuscript/Fig6_*` |
| `23_figS2_data_gaps.R` | Figure S2: Data gaps heatmap | `figures/supplementary/FigS2_*` |
| `24_supp_S3_S4.R` | Figure S3: Survival coefficients; Figure S4: Growth coefficients | `figures/supplementary/FigS3_*`, `FigS4_*` |
| `25_supp_S5_S6_S7_thresholds_growth.R` | Figure S5--S7: Threshold detection, growth diagnostics | `figures/supplementary/FigS5_*`, `FigS6_*`, `FigS7_*` |
| `26_supp_S8_S9.R` | Figure S8--S9: Cross-validation, power analysis | `figures/supplementary/FigS8_*`, `FigS9_*` |
| `27_supp_S10_S11.R` | Figure S10--S11: Model selection comparison | `figures/supplementary/FigS10_*`, `FigS11_*` |
| `28_supp_S12_S13_S14.R` | Figure S12--S14: Diagnostics, residuals, additional robustness | `figures/supplementary/FigS12_*`, `FigS13_*`, `FigS14_*` |

### 23 & Utilities -- Verification & Shared Code

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

## Running the Pipeline

### Full pipeline (~45--60 minutes)

```bash
cd analysis/scripts
Rscript run_all.R
```

### Individual scripts

From the project root:
```bash
Rscript analysis/scripts/01_data_preparation.R
Rscript analysis/scripts/02_survival_thresholds.R
```

From the scripts directory:
```bash
cd analysis/scripts
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

---

## Output Directories

```
analysis/
├── output/                         # 168+ CSV/RDS result files
│   ├── prepared_*.rds              # Analysis-ready data (from 01)
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
│   ├── manuscript/                 # Main text figures (from 18--22)
│   │   ├── Fig1_*.png/.pdf         # PNG (300 DPI) + PDF (vector)
│   │   ├── Fig2_*.png/.pdf         # All at 170mm width
│   │   ├── Fig3_*.png/.pdf
│   │   ├── Fig4_*.png/.pdf
│   │   ├── Fig5_*.png/.pdf
│   │   └── Fig6_*.png/.pdf
│   │
│   └── supplementary/              # Supplementary figures (from 18, 20c, 23--28)
│       ├── FigS1_*.png/.pdf        # Size distribution (from 18)
│       ├── FigS2_*.png/.pdf        # Data gaps heatmap (from 23)
│       ├── FigS3--S14_*.png/.pdf   # Diagnostics & robustness (from 24--28)
│       ├── FigS15_*.png/.pdf       # Regional survival (from 20c)
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
| Population growth rate (lambda) | 0.986 (P(decline) = 87.3%) |
| Most critical parameter | SC5 stasis (54.8% of total elasticity) |
| Between-study heterogeneity | I-squared = 97.8% |
| NOAA data share | 78% of observations |
| Total observations | 25,000+ from 18+ studies |

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

*Last updated: 2026-02-23*
