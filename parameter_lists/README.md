# Parameter Lists

This directory contains pre-computed parameter estimates for the Regional Stochastic Ecosystem (RSE) model, stratified by data context (field, nursery, lab).

## Overview

| File | Context | Parameters |
|------|---------|------------|
| `field_surv_pars.rds` | Wild populations | Survival by size class |
| `field_growth_pars.rds` | Wild populations | Growth by size class |
| `nurs_surv_pars.rds` | In situ nurseries | Survival by size class |
| `nurs_growth_pars.rds` | In situ nurseries | Growth by size class |
| `lab_surv_pars.rds` | Ex situ/lab | Survival by size class |
| `lab_growth_pars.rds` | Ex situ/lab | Growth by size class |
| `recruit_surv_pars.rds` | Post-settlement recruits | s_recruit alternative to nursery s1 |
| `scenario_matrices.rds` | Biological-realism scenarios | 9-scenario 5×5 Lefkovitch matrices (S0–S8) for RSE sensitivity analyses |
| `helpers/qe_projection.R` | RSE helper | Base-R functions: `project_trajectory()`, `compute_qe()`, `scenario_qe()` |

See [`RSE_COMPATIBILITY.md`](RSE_COMPATIBILITY.md) for the scenario menu, usage examples, and calibration notes.

## What is the RSE Model?

The Regional Stochastic Ecosystem (RSE) model is a spatially-explicit population simulation that lives in a [separate repository](https://github.com/stier-lab/Detmer-2025-coral-platform). It uses the parameter distributions generated here (survival, growth, fragmentation by size class and context) to project *A. palmata* population trajectories under different restoration and disturbance scenarios. The Lefkovitch matrix in Script 13 provides the deterministic baseline; the RSE model adds spatial structure, environmental stochasticity, and management interventions.

---

## File Format

All files are R Data Serialization (RDS) format. Load with:

```r
pars <- readRDS("parameter_lists/field_surv_pars.rds")
```

### Structure

Each RDS file is a list containing:

| Element | Type | Description |
|---------|------|-------------|
| `SC_surv_results` or `SC_growth_results` | named list | Bootstrap results per size class (mean, sd, ci_lower, ci_upper, n, n_studies, bootstrap_dist) |
| `surv_summary` or `growth_summary` | data.frame | Summary statistics by size class |
| `size_class_breaks` | numeric vector | Size class boundaries (cm²) |
| `n_observations` | integer | Total colonies (sum of cell sample sizes for survival) |
| `n_cells` | integer | Number of (study × size_class × interval) cells (survival only) |
| `n_studies` | integer | Number of source studies |
| `data_integration` | character | Weighting method (e.g., "study-level rma (from script 13, metafor::rma per size class)") |
| `generation_date` | POSIXct | Date parameters were generated |

---

## Size Classes

All parameter files use consistent size class definitions:

| Class | Range (cm²) | Boundaries |
|-------|-------------|------------|
| SC1 | 0-10 | [0, 10) |
| SC2 | 10-100 | [10, 100) |
| SC3 | 100-900 | [100, 900) |
| SC4 | 900-4000 | [900, 4000) |
| SC5 | ≥4000 | [4000, ∞) |

---

## Survival Parameters

### Bootstrap Replicates (`SC_surv_df`)

| Column | Type | Description |
|--------|------|-------------|
| `prop_survived` | numeric | Proportion surviving (0-1) |
| `size_class` | integer | Size class (1-5) |
| `replicate` | integer | Bootstrap replicate ID |
| `sample` | integer | Sample ID within replicate |
| `n` | numeric | Sample size for this draw |

### Summary Statistics (`surv_summary`)

| Column | Type | Description |
|--------|------|-------------|
| `size_class` | integer | Size class (1-5) |
| `n` | integer | Total observations |
| `mean` | numeric | Mean survival probability |
| `sd` | numeric | Standard deviation |
| `Q05` | numeric | 5th percentile |
| `Q25` | numeric | 25th percentile |
| `Q50` | numeric | Median |
| `Q75` | numeric | 75th percentile |
| `Q95` | numeric | 95th percentile |

### Typical Values (Field Data, study-level rma, natural colonies only)

| Size Class | N (colonies) | k (studies) | Mean Survival |
|------------|-------------|-------------|---------------|
| SC1 (0-10 cm²) | 129 | 3 | 0.507 |
| SC2 (10-100 cm²) | 1,265 | 4 | 0.731 |
| SC3 (100-900 cm²) | 2,304 | 5 | 0.786 |
| SC4 (900-4000 cm²) | 1,699 | 4 | 0.881 |
| SC5 (>4000 cm²) | 1,768 | 3 | 0.948 |

---

## Growth Parameters

### Bootstrap Replicates (`SC_growth_df`)

| Column | Type | Description |
|--------|------|-------------|
| `growth_cm2_yr` | numeric | Annual growth rate (cm²/year) |
| `size_class` | integer | Size class (1-5) |
| `replicate` | integer | Bootstrap replicate ID |
| `sample` | integer | Sample ID within replicate |
| `n` | numeric | Sample size for this draw |

### Summary Statistics (`growth_summary`)

| Column | Type | Description |
|--------|------|-------------|
| `size_class` | integer | Size class (1-5) |
| `n` | integer | Total observations |
| `mean` | numeric | Mean growth rate (cm²/year) |
| `sd` | numeric | Standard deviation |
| `Q05` | numeric | 5th percentile |
| `Q25` | numeric | 25th percentile |
| `Q50` | numeric | Median |
| `Q75` | numeric | 75th percentile |
| `Q95` | numeric | 95th percentile |

---

## Context Definitions

### Field (`field_*`)
Wild populations on natural reefs. Survival parameters are computed via study-level random-effects meta-analysis (`metafor::rma()` per size class, REML) from script 13's bootstrap output. Cells are first aggregated to study-level effects, then pooled via rma(). Growth parameters use individual-level data only.

**Characteristics:**
- Largest sample sizes (especially SC4-SC5)
- Long-term monitoring data
- Natural environmental conditions
- Survival from 16 studies via `prepared_survival_cells.rds`; growth from 7 individual-level studies

### Nursery (`nurs_*`)
In situ coral nurseries (underwater structures). Includes Pausch 2018, Fundemar, and restoration studies.

**Characteristics:**
- Primarily fragments
- Regular maintenance (algae removal)
- Elevated survival compared to wild
- Focus on SC1-SC3 size classes

### Lab (`lab_*`)
Ex situ facilities (land-based aquaria/tanks). Limited data available.

**Characteristics:**
- Controlled conditions
- Primarily settlers and small fragments
- Very small sample sizes
- May not represent natural conditions

---

## Usage in RSE Model

```r
# Load field survival parameters
field_surv <- readRDS("parameter_lists/field_surv_pars.rds")

# Access summary for model initialization
surv_by_sc <- field_surv$surv_summary

# Use bootstrap replicates for uncertainty propagation
boot_samples <- field_surv$SC_surv_df

# Get size class boundaries
breaks <- field_surv$size_class_breaks
```

### Stochastic Simulations

For each model timestep, draw survival probabilities from the bootstrap distribution:

```r
# Random draw for SC3 survival
sc3_boot <- boot_samples[boot_samples$size_class == 3, ]
random_survival <- sample(sc3_boot$prop_survived, 1)
```

---

## Generation

Parameters are generated by `06_analysis/scripts/17_update_parameter_lists.R`:

```bash
Rscript 06_analysis/scripts/17_update_parameter_lists.R
```

This script:
1. Reads field survival from script 13's rma() bootstrap output (`survival_bootstrap_by_sc.rds`, 2,000 iterations)
2. Loads `prepared_survival_cells.rds` for nursery survival (cell-level bootstrap, 500 iterations)
3. Loads `prepared_survival_data.rds` and `prepared_growth_data.rds` (individual records for lab/growth)
4. Generates hierarchical bootstrap replicates for growth (study-then-colony, 1,000 iterations)
5. Packages restoration recruit survival as `recruit_surv_pars.rds` with `s_recruit` parameter
6. Saves to RDS format with both analysis and RSE-compatible elements

---

## Caveats

1. **NOAA dominance**: Field parameters are heavily influenced by NOAA survey data (largest single contributor)
2. **Size class confounding**: SC1-SC2 are predominantly fragments; SC4-SC5 are predominantly colonies
3. **Nursery effects**: Nursery survival may be elevated due to maintenance
4. **Lab limitations**: Very small sample sizes for lab context
5. **Negative growth**: Present in field data; may need special handling

---

*Last updated: 2026-04-07*
*Generated by: 06_analysis/scripts/17_update_parameter_lists.R*
