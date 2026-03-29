# Standardized Data

This directory contains cleaned, harmonized datasets derived from the original data sources. All data have been standardized to common units, column names, and size measurements following the protocols described in `APAL_data_integration.rmd`.

## Overview

| File | Records | Description |
|------|---------|-------------|
| `apal_surv_ind.csv` | 5,213 | Individual-level survival data |
| `apal_surv_summ.csv` | 320 | Summary survival data (no individual sizes) |
| `apal_surv_lab_short.csv` | 6 | Short-term lab settler survival |
| `apal_growth_ind.csv` | 4,344 | Individual-level growth data |
| `apal_growth_summ.csv` | 15 | Summary growth data |
| `apal_fragmentation.csv` | 13 | Fragmentation rates from matrix models |
| `apal_fragmentation_summ.csv` | 9 | Fragmentation rate summaries |

---

## Size Measurement Standard

### ⚠️ Critical: Two Size Columns

Individual data files contain **two distinct size columns**:

| Column | Description | Use Case |
|--------|-------------|----------|
| `size_cm2` | Total colony footprint (Length × Width) | Physical area of skeleton |
| `size_live_cm2` | Live tissue area (Length × Width × % Live) | **Biologically meaningful size** |

**For size class assignment and biological analyses, always use `size_live_cm2`.**

A partially dead colony (e.g., 5,000 cm² total but only 200 cm² alive) behaves like a small juvenile for survival/growth purposes, not like a large adult. Using `size_cm2` instead of `size_live_cm2` leads to misclassification of stressed colonies as "large adults" and causes artificial survival drops in large size classes.

### Size Calculations

Live planar area:
```
size_live_cm2 = Length × Width × (% Live / 100)
```

Total planar area (for reference only):
```
size_cm2 = Length × Width
```

### Size Classes

**Size classes are assigned using live tissue area (`size_live_cm2`):**

| Class | Range (cm²) | Description |
|-------|-------------|-------------|
| SC1 | 0-10 | Recruits, settlers |
| SC2 | 10-100 | Small juveniles |
| SC3 | 100-900 | Large juveniles |
| SC4 | 900-4000 | Subadults |
| SC5 | >4000 | Reproductive adults |

### Summary Data Size Variable

Summary data files (`apal_surv_summ.csv`, `apal_growth_summ.csv`) have a different structure:

- `size_cm2_mean`: Mean colony size (may be total OR live tissue)
- `size_live`: Categorical flag indicating what `size_cm2_mean` represents:
  - `"Y"` = Live tissue area (comparable to individual data)
  - `"N"` = Total colony size (may overestimate biological size class)
  - `"both"` = Both reported, assumed 100% tissue cover
  - `"unknown"` = Size measurement type not specified

**When using summary data, filter for `size_live == "Y"` or flag records with other values as having uncertain size class assignments.**

---

## Individual Survival Data (`apal_surv_ind.csv`)

Survival records for individually tracked corals over ~1-year intervals.

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `study` | string | Study identifier (e.g., "NOAA_survey", "pausch_2018") |
| `region` | string | Geographic region (e.g., "Florida Keys", "Curacao", "USVI") |
| `location` | string | Reef or site name |
| `plot` | string | Sampling plot (if applicable) |
| `treatment_1` | string | Primary experimental treatment (if applicable) |
| `treatment_2` | string | Secondary treatment (if applicable) |
| `latitude` | numeric | Latitude in °N |
| `longitude` | numeric | Longitude in °W |
| `depth_m` | string/numeric | Site depth in meters |
| `survey_yr` | integer | Year of initial survey |
| `data_type` | string | "field", "nursery_in" (in situ), or "nursery_ex" (ex situ) |
| `coral_id` | string | Unique coral identifier |
| `size_cm2` | numeric | Skeletal planar area at start (cm²) |
| `size_live_cm2` | numeric | Live planar area at start (cm²) |
| `survived` | integer | 1 = survived, 0 = died |
| `fragment` | string | "Y" = fragmented coral, "N" = intact colony |
| `time_interval_yr` | numeric | Time interval (years) |
| `disturbance` | string | Major disturbance noted (e.g., "storm", "MHW", NA) |
| `study_notes` | string | Study-specific methodology notes |
| `study_N` | integer | Total sample size in study |
| `group_N` | integer | Sample size in this region/location/treatment group |

### Data Sources

| Study | n | Region(s) | Data Type |
|-------|---|-----------|-----------|
| NOAA_survey | 4,025 | Florida Keys, Curacao, Navassa | field |
| pausch_2018 | 789 | Florida Keys | nursery_in |
| kuffner_et_al_2020 | 106 | Florida Keys | field |
| USGS_USVI | 92 | USVI | field |
| fundemar_fragments | 156 | Dominican Republic | nursery_in |
| mendoza_quiroz_et_al_2023 | 45 | Mexican Caribbean | nursery_in/field |

---

## Summary Survival Data (`apal_surv_summ.csv`)

Survival data where individual sizes were not available (only ranges or means reported).

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `study` | string | Study identifier |
| `region` | string | Geographic region |
| `location` | string | Reef or site name |
| `plot` | string | Sampling plot (if applicable) |
| `treatment_1` | string | Primary treatment |
| `treatment_2` | string | Secondary treatment |
| `latitude` | numeric | Latitude in °N |
| `longitude` | numeric | Longitude in °W |
| `depth_m` | numeric | Site depth in meters |
| `survey_yr` | integer | Year of survey |
| `data_type` | string | "field", "nursery_in", or "nursery_ex" |
| `size_cm2_mean` | numeric | Mean size at start (cm²) |
| `size_cm2_sd` | numeric | Standard deviation of size |
| `size_cm2_min` | numeric | Minimum size in range |
| `size_cm2_max` | numeric | Maximum size in range |
| `size_live` | string | "N" (skeletal), "Y" (live), "both" (100% cover), "unknown" |
| `prop_survived` | numeric | Proportion surviving (0-1) |
| `n_initial` | integer | Initial sample size |
| `fragment` | string | "Y" or "N" |
| `time_interval_yr` | numeric | Time interval (years) |
| `disturbance` | string | Disturbance event |
| `study_notes` | string | Methodology notes |
| `study_N` | integer | Total study sample size |

### Studies with Summary Data

- Rosales et al. 2024 (fragment restoration)
- Vardi 2011 matrix model data (Jamaica, Puerto Rico, Virgin Gorda)
- Ortiz Prosper 2005 (Puerto Rico fragments)
- Forrester et al. 2011, 2013 (BVI fragments)
- Garrison & Ward 2012 (USVI transplants)
- Williams & Miller 2010 (Florida fragments)
- Bruckner & Bruckner 2001 (Puerto Rico fragments)
- Maurer et al. 2022 (Bahamas nursery)

---

## Short-term Lab Survival (`apal_surv_lab_short.csv`)

Survival of settlers in laboratory/aquaria conditions over short time intervals (days to weeks).

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `study` | string | Study identifier |
| `region` | string | Region where spawn was collected |
| `location` | string | Collection site |
| `treatment_1` | string | Temperature or experimental treatment |
| `treatment_2` | string | Secondary treatment |
| `spawn_yr` | integer | Year spawn was collected |
| `substrate_type` | string | Settlement substrate description |
| `prop_survived` | numeric | Proportion surviving |
| `n_initial` | integer | Initial number of settlers |
| `time_interval_d` | numeric | Time interval in days |
| `study_notes` | string | Methodology notes |

### Studies

- Chamberland et al. 2015 (Curacao, clay pottery tripods)
- Randall & Szmant 2009 (Puerto Rico, culture plates with CCA)

---

## Individual Growth Data (`apal_growth_ind.csv`)

Growth rates for individually tracked corals.

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `study` | string | Study identifier |
| `region` | string | Geographic region |
| `location` | string | Reef or site name |
| `plot` | string | Sampling plot (if applicable) |
| `treatment_1` | string | Primary treatment |
| `treatment_2` | string | Secondary treatment |
| `latitude` | numeric | Latitude in °N |
| `longitude` | numeric | Longitude in °W |
| `depth_m` | string/numeric | Site depth in meters |
| `survey_yr` | integer | Year of initial survey |
| `data_type` | string | "field", "nursery_in", or "nursery_ex" |
| `coral_id` | string | Unique coral identifier |
| `size_cm2` | numeric | Skeletal planar area at start (cm²) |
| `size_live_cm2` | numeric | Live planar area at start (cm²) |
| `growth_cm2_yr` | numeric | Absolute growth rate (cm²/year) |
| `growth_live_cm2_yr` | numeric | Live tissue growth rate (cm²/year) |
| `fragment` | string | "Y" or "N" |
| `time_interval_yr` | numeric | Time interval (years) |
| `disturbance` | string | Disturbance event |
| `study_notes` | string | Methodology notes |
| `study_N` | integer | Total study sample size |
| `group_N` | integer | Group sample size |

### Notes on Growth Data

- **Negative growth**: Common in NOAA data due to tissue loss or measurement error
- **Includes only surviving corals**: Dead corals excluded from growth calculations
- **Relative growth rate (RGR)** can be calculated as: `growth_cm2_yr / size_cm2`

---

## Summary Growth Data (`apal_growth_summ.csv`)

Growth data where only means/ranges were reported.

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `study` | string | Study identifier |
| `region` | string | Geographic region |
| `location` | string | Reef or site name |
| `plot` | string | Sampling plot |
| `treatment_1` | string | Primary treatment (often cohort/year) |
| `treatment_2` | string | Secondary treatment |
| `latitude` | numeric | Latitude in °N |
| `longitude` | numeric | Longitude in °W |
| `depth_m` | numeric | Site depth in meters |
| `survey_yr` | integer | Year of survey |
| `data_type` | string | "field", "lab", or "nursery" |
| `size_cm2_mean` | numeric | Mean initial size (cm²) |
| `size_cm2_sd` | numeric | Size standard deviation |
| `size_cm2_min` | numeric | Minimum size |
| `size_cm2_max` | numeric | Maximum size |
| `size_live` | string | Size type indicator |
| `growth_cm2_yr_mean` | numeric | Mean growth rate (cm²/year) |
| `growth_cm2_yr_sd` | numeric | Growth rate SD |
| `growth_cm2_yr_min` | numeric | Minimum growth rate |
| `growth_cm2_yr_max` | numeric | Maximum growth rate |
| `n_final` | integer | Sample size at end |
| `fragment` | string | "Y" or "N" |
| `time_interval_yr` | numeric | Time interval (years) |
| `disturbance` | string | Disturbance event |
| `study_notes` | string | Methodology notes |
| `study_N` | integer | Total study sample size |

---

## Fragmentation Data (`apal_fragmentation.csv`)

Annual fragmentation rates from matrix models (Vardi 2011).

### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `study` | string | "vardi_2011" |
| `region` | string | Geographic region |
| `location` | string | Reef names |
| `survey_yr` | integer | Year |
| `data_type` | string | "field" |
| `F4_SC1` | numeric | Rate: SC4 colonies producing SC1 fragments |
| `F4_SC2` | numeric | Rate: SC4 colonies producing SC2 fragments |
| `F4_SC3` | numeric | Rate: SC4 colonies producing SC3 fragments |
| `F4_SC4` | numeric | Rate: SC4 colonies producing SC4 fragments |
| `F5_SC1` | numeric | Rate: SC5 colonies producing SC1 fragments |
| `F5_SC2` | numeric | Rate: SC5 colonies producing SC2 fragments |
| `F5_SC3` | numeric | Rate: SC5 colonies producing SC3 fragments |
| `F5_SC4` | numeric | Rate: SC5 colonies producing SC4 fragments |
| `F5_SC5` | numeric | Rate: SC5 colonies producing SC5 fragments |
| `time_interval_yr` | numeric | Always 1 (annual) |
| `disturbance` | string | NA |
| `study_notes` | string | Methodology notes |

### Methodology

From Vardi 2011: "New fragments are assumed to arise from the existing stand of colonies and can be of any size class. New SC3 fragments are assumed to derive solely from pre-existing SC4 colonies."

---

## Fragmentation Summary (`apal_fragmentation_summ.csv`)

Summary statistics for fragmentation rates across all years and regions.

| Column | Type | Description |
|--------|------|-------------|
| `frag_type` | string | Fragment type (e.g., "F4_SC1") |
| `mean` | numeric | Mean annual rate |
| `Q05` | numeric | 5th percentile |
| `Q95` | numeric | 95th percentile |

---

## AI-Extracted Data (March 2026)

Two additional files contain data extracted from published PDFs by AI (Claude). These serve as both data sources and audit trails.

### `ai_extracted_survival.csv`

73 rows of detailed survival data from 7 studies. Every row has `[AI_EXTRACTED]` in `study_notes`. These are granular extractions (year-by-year, site-by-site, zone-by-zone) that were then aggregated into study-level entries appended to `apal_surv_summ.csv` (rows 321–330).

| Column | Type | Description |
|--------|------|-------------|
| All columns from `apal_surv_summ.csv` | — | Same schema |

Studies: rogers_muller_2012, ramos_et_al_2024 (excluded from meta), ramos_romero_et_al_2025, zubillaga_et_al_2008 (cross-sectional, not in meta), caballero_aragon_et_al_2019 (cross-sectional), muller_et_al_2008, sutherland_et_al_2016.

### `ai_extracted_fragmentation.csv`

66 rows of fragmentation-related data from 4 studies. Flexible format (metric/value) since fragmentation data is heterogeneous across studies.

| Column | Type | Description |
|--------|------|-------------|
| `study` | string | Study identifier |
| `region` | string | Geographic region |
| `location` | string | Site name |
| `latitude`, `longitude` | numeric | Coordinates |
| `data_type` | string | "field" or "experiment" |
| `metric` | string | What was measured (e.g., "fragment_survival_6mo", "fragment_density_9mo") |
| `value` | numeric | The measured value |
| `unit` | string | Units (proportion, percent, cm, count, etc.) |
| `n` | numeric | Sample size |
| `size_class_or_range` | string | Size range if applicable |
| `time_interval` | string | Observation period |
| `notes` | string | Extraction notes |
| `data_source` | string | Always "ai_extracted" |

Studies: lirman_2000, fong_lirman_1995, highsmith_et_al_1980, rogers_muller_2012.

**Note:** These fragmentation data are contextual. They do NOT feed into the transition matrix pipeline, which uses only `apal_fragmentation.csv` (Vardi 2011 size-class-specific rates). The AI-extracted fragmentation data measures different things (fragment proportions, tissue loss rates, size-survival functions) that aren't in the F-matrix format.

### Audit status

All AI-extracted data was independently verified by audit agents that read each source PDF and compared every value. Findings and corrections documented in `docs/Data_Methodology_Reference.md` Section 8.

---

## Data Processing Pipeline

The standardization process is documented in `APAL_data_integration.rmd` and includes:

1. **Size conversion**: All measurements converted to live planar area (cm²)
2. **Time interval standardization**: Rates adjusted to annual basis
3. **Column harmonization**: Consistent naming across studies
4. **Quality flags**: Fragment status, data type, disturbance events
5. **Sample size tracking**: Study-level and group-level N

### Key Assumptions

- For studies without live tissue %, assumed 100% cover
- For diameter-only measurements, used empirical width:length ratios
- For recruits, assumed circular shape (area = π × d²/4)
- Survival interpolated/extrapolated for non-annual intervals
- For AI-extracted KM survival, `time_interval_yr` = full monitoring duration (not last KM event time)
- For AI-extracted annualization: `surv_annual = surv_raw^(1/time_interval_yr)` (constant hazard assumption)

---

## Usage Notes

### Loading in R
```r
library(readr)

# Individual-level data (Tier 1)
surv_ind <- read_csv("standardized_data/apal_surv_ind.csv")
growth_ind <- read_csv("standardized_data/apal_growth_ind.csv")

# Summary-level data (Tier 2, including AI-extracted rows 321+)
surv_summ <- read_csv("standardized_data/apal_surv_summ.csv")

# AI-extracted audit trail (not used directly in pipeline)
ai_surv <- read_csv("standardized_data/ai_extracted_survival.csv")
ai_frag <- read_csv("standardized_data/ai_extracted_fragmentation.csv")
```

### Distinguishing hand-extracted vs AI-extracted data

```r
# In apal_surv_summ.csv:
hand_extracted <- surv_summ %>% filter(!grepl("AI_EXTRACTED", study_notes))
ai_extracted <- surv_summ %>% filter(grepl("AI_EXTRACTED", study_notes))

# In 14b meta-analysis output:
# data_tier column: "Tier 2 (summary)" = hand, "Tier 2 (summary) [AI_EXTRACTED]" = AI
```

### Key Caveats

1. **NOAA dominance**: 78% of individual survival data comes from NOAA survey
2. **Fragment vs. colony**: Size classes SC1-SC2 are predominantly fragments; SC4-SC5 are predominantly intact colonies
3. **Simpson's Paradox**: Apparent survival differences by size may be confounded by fragment status
4. **Negative growth**: Present in NOAA data; may indicate tissue loss or measurement uncertainty
5. **AI-extracted data**: Clearly tagged and audited, but should be treated with appropriate caution. See audit log in `docs/Data_Methodology_Reference.md`.

---

*Last updated: 2026-03-26*
*Original data: APAL_data_integration.rmd (Detmer 2025)*
*AI-extracted extension: Claude (March 2026), audited*
