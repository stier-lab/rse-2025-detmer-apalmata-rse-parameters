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
| `SC_surv_df` or `SC_growth_df` | data.frame | Bootstrap replicates by size class |
| `surv_summary` or `growth_summary` | data.frame | Summary statistics by size class |
| `size_class_breaks` | numeric vector | Size class boundaries (cm²) |
| `n_observations` | integer | Total observations used |
| `n_studies` | integer | Number of source studies |
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

### Typical Values (Field Data)

| Size Class | n | Mean Survival | SD |
|------------|---|---------------|-----|
| SC1 (0-10 cm²) | TBD | TBD | TBD |
| SC2 (10-100 cm²) | TBD | TBD | TBD |
| SC3 (100-900 cm²) | TBD | TBD | TBD |
| SC4 (900-4000 cm²) | TBD | TBD | TBD |
| SC5 (>4000 cm²) | TBD | TBD | TBD |

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
Wild populations on natural reefs. Includes NOAA survey data and other observational studies.

**Characteristics:**
- Largest sample sizes (especially SC4-SC5)
- Long-term monitoring data
- Natural environmental conditions
- Mix of fragments and intact colonies

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

Parameters are generated by `analysis/scripts/17_update_parameter_lists.R`:

```bash
Rscript analysis/scripts/17_update_parameter_lists.R
```

This script:
1. Loads standardized data from `standardized_data/`
2. Filters by data type (field/nursery/lab)
3. Assigns size classes
4. Generates bootstrap replicates (n=1,000 per size class)
5. Calculates summary statistics
6. Saves to RDS format

---

## Caveats

1. **NOAA dominance**: Field parameters are heavily influenced by NOAA survey data (largest single contributor)
2. **Size class confounding**: SC1-SC2 are predominantly fragments; SC4-SC5 are predominantly colonies
3. **Nursery effects**: Nursery survival may be elevated due to maintenance
4. **Lab limitations**: Very small sample sizes for lab context
5. **Negative growth**: Present in field data; may need special handling

---

*Last updated: 2025-12-25*
*Generated by: analysis/scripts/17_update_parameter_lists.R*
