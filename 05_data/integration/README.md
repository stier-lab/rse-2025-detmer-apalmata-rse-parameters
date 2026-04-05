# R Markdown Documents

This directory contains 4 R Markdown documents for data integration, analysis, and documentation.

## Files

### APAL_data_integration.rmd
**Purpose:** Data standardization and harmonization pipeline

**Description:**
Processes raw data from multiple sources into standardized format. Documents all data cleaning decisions, size conversions, and quality flags.

**Inputs:**
- `05_data/original/*.csv`
- `05_data/original/*.xlsx`

**Outputs:**
- `05_data/standardized/apal_surv_ind.csv`
- `05_data/standardized/apal_surv_summ.csv`
- `05_data/standardized/apal_growth_ind.csv`
- `05_data/standardized/apal_growth_summ.csv`
- `05_data/standardized/apal_fragmentation.csv`
- `05_data/standardized/apal_surv_lab_short.csv`

**Key sections:**
1. Data source loading
2. Size standardization (convert to live planar area cm²)
3. Time interval adjustments
4. Column harmonization
5. Quality flagging
6. Export to CSV

---

### APAL_data_analysis.rmd
**Purpose:** Parameter estimation for RSE model

**Description:**
Comprehensive analysis of survival and growth parameters including threshold detection, variance partitioning, and population matrix construction.

**Inputs:**
- `05_data/standardized/*.csv`

**Outputs:**
- `06_analysis/output/*.csv`
- `06_analysis/figures/`
- `parameter_lists/*.rds`

**Key sections:**
1. Data preparation and size class assignment
2. Survival threshold analysis (GAM, bootstrap)
3. Growth threshold analysis
4. Size × Space × Time variance partitioning
5. Population transition matrix
6. Data gap identification
7. Publication figures

---

### Elasticity_Analysis_Walkthrough.Rmd
**Purpose:** Interactive walkthrough of the elasticity analysis

**Description:**
Step-by-step guide to the Lefkovitch matrix construction, eigenanalysis, and elasticity decomposition. Designed for collaborators who want to understand how λ and elasticity values are derived from the transition matrix.

**Inputs:**
- `06_analysis/output/transition_matrix.csv`
- `06_analysis/output/elasticity_matrix.csv`

**Key sections:**
1. Matrix construction from size-class transition probabilities
2. Eigenanalysis and λ calculation
3. Elasticity decomposition by vital rate type
4. Bootstrap uncertainty propagation

---

### APAL_Collaborator_Guide.Rmd
**Purpose:** Onboarding guide for project collaborators

**Description:**
Overview of the data pipeline, key findings, and how to navigate the repository. Intended for new collaborators joining the project who need to understand the analysis workflow and data structure.

**Key sections:**
1. Project overview and goals
2. Data sources and standardization
3. Analysis pipeline walkthrough
4. Key findings summary
5. How to contribute

---

## Running the Documents

### In RStudio
Open the `.rmd` file and click "Knit" or use:
```r
rmarkdown::render("APAL_data_integration.rmd")
rmarkdown::render("APAL_data_analysis.rmd")
```

### From Command Line
```bash
Rscript -e "rmarkdown::render('05_data/integration/APAL_data_integration.rmd')"
Rscript -e "rmarkdown::render('05_data/integration/APAL_data_analysis.rmd')"
```

---

## Relationship to Scripts

The R scripts in `06_analysis/scripts/` are modularized versions of the analyses in these RMarkdown documents:

| RMarkdown Section | Corresponding Script |
|-------------------|---------------------|
| Data integration | `01_data_preparation.R` |
| Survival thresholds | `02_survival_thresholds.R` |
| Growth thresholds | `03_growth_thresholds.R` |
| Variance partitioning | `05_variance_partitioning.R` |
| Gap analysis | `06_data_gap_analysis.R` |
| Transition matrix | `13_transition_matrix.R` |

The RMarkdown documents provide narrative context and methodology explanations, while the scripts are designed for reproducible batch execution.

---

## Dependencies

```r
# Core
library(tidyverse)
library(readxl)
library(readr)

# Analysis
library(mgcv)
library(lme4)
library(broom)

# Visualization
library(ggplot2)
library(patchwork)
library(scales)
library(sf)           # For maps
library(rnaturalearth)
```

---

*Last updated: 2025-12-28*
