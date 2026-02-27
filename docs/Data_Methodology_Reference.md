# Data Methodology Reference
## Acropora palmata Demographic Parameters Database

**Complete documentation of data sources, standardization methods, and study-specific notes**

---

## Table of Contents

1. [Data Collection Overview](#1-data-collection-overview)
2. [Literature Search Methods](#2-literature-search-methods)
3. [Size Standardization](#3-size-standardization)
4. [Dataset Column Definitions](#4-dataset-column-definitions)
5. [Study-by-Study Notes](#5-study-by-study-notes)
6. [Fragmentation Data](#6-fragmentation-data)
7. [Short-Term Lab Survival Data](#7-short-term-lab-survival-data)
8. [Analysis Notes](#8-analysis-notes)

---

## 1. Data Collection Overview

### 1.1 General Approach

For each paper/dataset:
1. Created cleaned-up survival dataset and/or cleaned-up growth/shrinkage dataset
2. If raw data weren't available, recorded size range and sample size (made these datasets separate from those with individual data)
3. Put all notes/caveats/assumptions for each study in the "Study/Dataset notes" section
4. Combined all datasets into synthesized survival and growth datasets

### 1.2 Parameter Types

**Primary parameters being estimated:**
- Survival rates (proportion surviving one year)
- Growth rates (cm²/year)
- Shrinkage rates

**Secondary parameters:**
- Fragmentation rates (from matrix models)
- Short-term lab survival rates
- Fecundities
- Disturbance parameters

### 1.3 Inclusion Criteria

**Survival parameters:**
- Study needed to report initial number and size of colonies/fragments AND number surviving approximately one year later
- OR: initial size and proportion surviving approximately one year
- Studies with different time intervals were included; survival rates interpolated/extrapolated as needed

**Growth parameters:**
- Study recorded either initial and final sizes, OR initial sizes and colony growth rate
- Studies reporting only linear extension of branches were excluded (cannot convert to area)

---

## 2. Literature Search Methods

### 2.1 Search Strategy

Using Google Scholar, searched for ("Acropora palmata" OR "elkhorn coral") AND each of the following combinations:

1. `(surviv* OR mortality OR "hazard rate" OR "mortality rate")`
2. `(growth OR "linear extension" OR "calcification" OR "skeletal density" OR "areal growth" OR "extension rate")`
3. `(settlement OR settler* OR recruit* OR "recruitment rate" OR "spat" OR "larval" OR fecundity OR "egg" OR "planula*")`
4. `(outplant* OR restoration OR nursery) AND (survival OR growth OR mortality)`
5. `("long-term" OR "time series" OR monitoring OR "population trend*")`

### 2.2 Screening Process

1. For each combination of search terms, reviewed papers page by page (stopping once all seemed irrelevant)
2. Initial screening: skimmed papers to check if they measured growth and/or survival of *Acropora palmata* (colonies or fragments) with colony/fragment size information
3. Detailed review: determined if studies met criteria for model parameter estimation

---

## 3. Size Standardization

### 3.1 Live Planar Area Method

Following Vardi et al. 2012, use **live planar area** where possible:

> "We multiplied the longest axis of the colony (length) and longest perpendicular axis (width) as viewed from above, by a visual estimate of the percentage of live tissue, to estimate 2-dimensional projected live surface area, or colony size"

**Live Planar Area = Length × Width × Percent Alive**

**Exception:** For studies on new recruits, assumed colonies were circular (based on images of newly settled recruits) rather than rectangular.

### 3.2 Converting from Linear Measurements

For studies reporting only fragment or colony length (or max diameter):

1. Used available datasets with length and width measurements to calculate average width:length ratios
2. Filtered out fragments with >50% tissue mortality to avoid artificially small ratios
3. Calculated mean and min/max fragment or colony surface areas from reported lengths

**Alternative approach (not used):** Relationships in Table 3-1 of Vardi 2011 to convert from skeletal area to live area.

### 3.3 Matrix Model Data

Several studies reported survival/growth as matrix models (proportion transitioning between size classes).

**Decision:** Only use matrix data for survival and fragmentation information, NOT for growth/shrinkage rates.

**Rationale:** Matrix transitions don't provide informative size-based growth information:
- A coral that grew to the next size class could have only grown 1 cm² if it started just below the boundary
- A coral that stayed in the same size class could have grown almost the entire range of that size class

---

## 4. Dataset Column Definitions

### 4.1 Survival Dataset (Individual Data)

| Column | Description |
|--------|-------------|
| `study` | Name of study or dataset |
| `region` | Country/geographic region (e.g., Florida, USVI) |
| `location` | Name of reef, bay, etc. (if available) |
| `plot` | Sampling plot on reef (if available) |
| `treatment_1` | First experimental treatment (if applicable) |
| `treatment_2` | Second experimental treatment (if applicable) |
| `latitude` | Latitude in °N |
| `longitude` | Longitude in °W |
| `depth_m` | Site depth in meters |
| `survey_yr` | Year when corals were surveyed |
| `data_type` | `field`, `nursery_in` (in situ nursery), `nursery_ex` (ex situ/aquaria) |
| `coral_id` | Unique identifier for each tracked coral |
| `size_cm2` | Coral size at interval start (skeleton planar area) |
| `size_live_cm2` | Coral size at interval start (living area) |
| `survived` | 1 = alive at interval end, 0 = died |
| `fragment` | `Y` (fragmented), `N` (not fragmented) |
| `time_interval_yr` | Time interval in years |
| `disturbance` | Major disturbance during period (e.g., "storm", "MHW", or NA) |
| `study_notes` | Notes on size calculation, mortality measurement, etc. |
| `study_N` | Total individuals in entire study |
| `group_N` | Individuals per region/location/treatment group |

### 4.2 Growth Dataset (Individual Data)

| Column | Description |
|--------|-------------|
| `study` | Name of study or dataset |
| `region` | Country/geographic region |
| `location` | Name of reef, bay, etc. |
| `plot` | Sampling plot on reef |
| `treatment_1` | First experimental treatment |
| `treatment_2` | Second experimental treatment |
| `latitude` | Latitude in °N |
| `longitude` | Longitude in °W |
| `depth_m` | Site depth in meters |
| `survey_yr` | Year when corals were surveyed |
| `data_type` | `field`, `nursery_in`, `nursery_ex` |
| `coral_id` | Unique identifier for tracked coral |
| `size_cm2` | Coral size at interval start (skeleton planar area) |
| `size_live_cm2` | Coral size at interval start (living area) |
| `growth_cm2_yr` | Coral growth rate in cm²/year |
| `growth_live_cm2_yr` | Live tissue growth rate in cm²/year |
| `fragment` | `Y` (fragmented), `N` (not fragmented) |
| `size_units` | Planar area, live surface area, etc. |
| `time_interval_yr` | Time interval in years |
| `disturbance` | Major disturbance during period |
| `study_notes` | Notes on calculations |
| `study_N` | Total individuals in study |
| `group_N` | Individuals per group |

### 4.3 Survival Dataset (Summary Data - No Individual Sizes)

| Column | Description |
|--------|-------------|
| `study` | Name of study or dataset |
| `region` | Country/geographic region |
| `location` | Name of reef, bay, etc. |
| `plot` | Sampling plot on reef |
| `treatment_1` | First experimental treatment |
| `treatment_2` | Second experimental treatment |
| `latitude` | Latitude in °N |
| `longitude` | Longitude in °W |
| `depth_m` | Site depth in meters |
| `survey_yr` | Year when corals were surveyed |
| `data_type` | `field`, `nursery_in`, `nursery_ex` |
| `size_cm2_mean` | Mean coral size at interval start (skeleton planar area) |
| `size_cm2_sd` | Standard deviation of coral size |
| `size_cm2_min` | Min coral size (for studies with range only) |
| `size_cm2_max` | Max coral size (for studies with range only) |
| `size_live` | `N` (skeletal area), `Y` (live area), `both` (100% cover), `unknown` |
| `prop_survived` | Proportion surviving to interval end |
| `n_initial` | Number of corals/fragments at interval start |
| `fragment` | `Y` (fragmented), `N` (not fragmented) |
| `time_interval_yr` | Time interval in years |
| `disturbance` | Major disturbance during period |
| `study_notes` | Notes on calculations |

### 4.4 Growth Dataset (Summary Data - No Individual Sizes)

| Column | Description |
|--------|-------------|
| `study` | Name of study or dataset |
| `region` | Country/geographic region |
| `location` | Name of reef, bay, etc. |
| `plot` | Sampling plot on reef |
| `treatment_1` | First experimental treatment |
| `treatment_2` | Second experimental treatment |
| `latitude` | Latitude in °N |
| `longitude` | Longitude in °W |
| `depth_m` | Site depth in meters |
| `survey_yr` | Year when corals were surveyed |
| `data_type` | `field`, `nursery_in`, `nursery_ex` |
| `size_cm2_mean` | Mean coral size at interval start |
| `size_cm2_sd` | Standard deviation of coral size |
| `size_cm2_min` | Min coral size |
| `size_cm2_max` | Max coral size |
| `size_live` | `N`, `Y`, or `unknown` |
| `growth_cm2_yr_mean` | Mean growth rate (cm²/yr) |
| `growth_cm2_yr_sd` | SD of growth rate |
| `growth_cm2_yr_min` | Min growth rate reported |
| `growth_cm2_yr_max` | Max growth rate reported |
| `n_final` | Number of corals at interval end |
| `fragment` | `Y` (fragmented), `N` (not fragmented) |
| `time_interval_yr` | Time interval in years |
| `disturbance` | Major disturbance during period |
| `study_notes` | Notes on calculations |
| `study_N` | Total individuals in study |

---

## 5. Study-by-Study Notes

### 5.1 NOAA Survey (NOAA_survey)

**Source:** Southeast Fisheries Science Center, 2025: Elkhorn coral demographic monitoring from 2004-03-30 to 2024-08-15 (NCEI Accession 0142175)
- https://www.fisheries.noaa.gov/inport/item/22436

**Description:** Dana Williams et al.'s data on A. palmata demographic monitoring in Florida, Curaçao, and Navassa (small island between Haiti and Jamaica)

**Main dataset:** `TaggedColonyData.csv`
- Survey dates: given as quarter (1-4); calendar dates in `data_documentation/SurveyDates.csv`
- Metadata: in `data_documentation/DATA_DICTIONARY`

**Notes:**
- Monitored tagged A. palmata colonies in Florida, Curaçao, and Navassa
- Size measured as length, width, height, and percent of colony surface area covered with live tissue
- **Mortality definition:** Corals considered dead if:
  1. At least part of skeleton found with no tissue remaining, OR
  2. No skeleton/tissue left where coral had previously been
- Sampling interval varied across sites: from multiple times per year (some Florida sites) to once every three years (Navassa)
- For sites with >annual sampling, selected only sample dates approximately a year apart starting from first sample date
- Disturbance years recorded based on Vardi 2011 (same sites, storm disturbance noted in Fig. 4-2), but no information on years after 2011

**Critical caveat:** This study provides **78% of all survival data** and consists of large established colonies (mean ~7,788 cm²).

---

### 5.2 Pausch et al. 2018 (pausch_et_al_2018)

**Source:** Southeast Fisheries Science Center, 2025: CRCP-Acropora palmata fragment outplants: evaluating the performance in the Upper Florida Keys from 2014 to 2016
- https://www.fisheries.noaa.gov/inport/item/26790

**Description:** Dana Williams et al.'s data on A. palmata fragments in Florida

**Main datasets:**
- `Data_Table_Size.csv` (fragment size experiment)
- `Data_Table_Genet.csv` (fragment genet experiment)

**Notes:**
- Nursery-cultured, outplanted fragments in Florida
- **Two experiments:**
  1. Forereef: comparing survival of large and small fragments while controlling for genet
     - `treatment_1` = fragment size, `treatment_2` = genet
  2. Forereef vs. nearshore patch reefs: comparing performance of different genets
     - `treatment_1` = habitat, `treatment_2` = genet
- Data appear to match Pausch et al. 2018 (https://www.int-res.com/abstracts/meps/v592/meps12488)
- Survival rates matched paper only if assuming fragments that died were excluded from subsequent sampling years
- Time interval approximated as average interval for surviving fragments (~1 year)

**Critical caveat:** Fragment-based study with much smaller coral sizes (mean ~64 cm²) than NOAA survey.

---

### 5.3 USGS USVI (USGS_USVI_exp)

**Source:** USGS experimental growth data and time-series imagery for A. palmata and Pseudodiploria strigosa in USVI
- https://cmgds.marine.usgs.gov/catalog/spcmsc/Coral_growth_VI_USA_metadata.faq.html

**Notes:**
- Tagged colonies outplanted June 2019, monitored until July 2021
- Dataset includes growth rates and alive vs. dead status
- **Initial size:** Estimated from raw photographs for June 2019 and from initial sizes + reported growth rates for June 2020
- **Time intervals:**
  - Time 1: June 2019 to November 2019
  - Time 2: November 2019 to June 2020
  - Time 3: June 2020 to February 2021
  - Time 4: February 2021 to August 2021
- Data normalized to days between site visits (converted to rates)
- For standardized data: `time_interval_yr` = 1 for first interval (June 2019 to June 2020), 13/12 for second (June 2020 to Aug 2021)
- **Annual intervals analyzed:**
  - June 2019 to June 2020 (average growth rates over intervals 1+2)
  - June 2020 to July 2021 (average growth rates over intervals 3+4)
- "Dead" = no live tissue remaining at interval end
- Growth = change in coral planar-footprint area per day

---

### 5.4 Kuffner et al. 2020 (kuffner_et_al_2020)

**Source:** Kuffner et al. 2020
- Paper: https://www.int-res.com/abstracts/esr/v43/esr01083
- Data: https://coastal.er.usgs.gov/data-release/doi-P9KZEGXY/

**Notes:**
- Tagged colonies outplanted late April/early May 2018, monitored until fall 2019
- Dataset includes growth rates and alive vs. dead status
- **Initial size:** Estimated from raw photographs at initial time point
- **Time intervals:**
  - Time 1: Spring 2018 to Fall 2018
  - Time 2: Fall 2018 to Spring 2019
  - Time 3: Spring 2019 to Fall 2019
- Only used data from Spring 2018 through Spring 2019 (one year); assumed `time_interval_yr` = 1
- **Mortality definition:** ≥50% tissue mortality, but photos of "dead" corals all looked 100% dead

---

### 5.5 Mendoza Quiroz et al. 2023 (mendoza_quiroz_2023)

**Source:** https://peerj.com/articles/15813/

**Description:** A. palmata restoration in Mexico - individual growth data from in situ nursery and after outplanting on two reefs

**Notes:**
- **Size measurements:**
  - In situ nursery and Cuevones reef: size given only as diameter → assumed square (area = diameter²)
  - Picudas reef: size given as length and width (area = length × width)
- **Time intervals:**
  - In situ nursery and Cuevones reef: exact sampling dates given
  - Picudas reef: only month and year given → assumed `time_interval_yr` = 1 year
- **Ex situ nursery data:**
  - Numbers of recruits surviving at different time points after settlement (2011 and 2012 cohorts; Table 1)
  - Sizes of sample recruits from 2012 cohort (supplementary data)
  - Estimated growth rate as difference between mean sizes at months 3 and 12, converted to cm²/yr
- **Location note:** Paper reports Picudas reef at -87.85°W (on land); appears to actually be -86.85°W

---

### 5.6 Chamberland et al. 2015 (chamberland_et_al_2015)

**Source:** Chamberland et al. 2015

**Description:** Comparing survival of A. palmata settlers kept in lab (land-based nursery) vs. outplanted on reef in Curaçao

**Notes:**
- **Initial sizes:** Not given; assumed new settlers had diameter ~1 mm (based on photo of new settler in Fig. 1E)
- **Initial number:** Not explicitly stated; "used RSUs with similar settler densities (mean of 11.1 per substrate unit); 30 were assigned to the reef and 30 to the land-based nursery"
  - Assumed initial numbers: 30 × 11 = 330 per location
- **Survival rates at 11 months:** Estimated from bar plot in Fig. 2
- **Growth rates over 30 months:** Estimated using difference between sizes at 30 months and approximate initial sizes
  - **Note:** Very small sample sizes: only 9 individuals remained on reef, only 1 remained in lab

---

### 5.7 Fundemar Fragments (fundemar_fragments)

**Source:** "Crecimiento_Fragmentos_APAL.xlsx" data shared by Fundemar

**Information from Maria:**
- A. palmata fragments from 6 localities: Reef Balls, El Play, Catalina, Minitas, Coralina, and Majagual
- Fragments sub-fragmented into smaller pieces and placed in PVC table structures (one table per location, 7 frags of same individual in a table line) for conditioning and growth
- Regular maintenance including algal scrubbing, at least once every 2 weeks
- Nursery located next to Sombrero restoration site

**Notes:**
- Only Table 1 sampled over a full year; Tables 2-6 span only 5 months → only used survival data from Table 1
- Mismatch in row/tags/fragment labels for Tables 4 and 5 (don't match between sampling time points)

---

### 5.8 Fundemar Recruits (fundemar_recruits)

**Sources:**
- Survival: `Fundemar_Matriz_Supervivencia_Reclutas_Unificada.xlsx`
- Size: `Fundemar_Matriz_area_Reclutas.xlsx`

**Recruit Survival Notes:**
- Focused on survival after 12 months
- Removed cases where at least one recruit appeared on substrate after outplanting (unclear why this would happen; causes survival to increase over time)
- Youngest recruits with reported sizes were 5 months old → used average size of 5-month-old recruits as initial size

**Recruit Growth Notes:**
- Size data don't track individuals
- Estimated growth as change in mean size between largest available time windows:
  - 2020 cohort: months 5 to 12
  - 2019 cohort: months 10 to 16

---

### 5.9 Rosales et al. 2024 (rosales_et_al_2024)

**Source:** https://www.nature.com/articles/s43247-024-01816-7

**GitHub data:** https://github.com/srosales712/CoralPersistence/blob/master/Data/POR_meta_apal_live.csv

**Notes:**
- Some data available on GitHub appear to include individual size data (`POR_meta_apal_live.csv`), but only for subset of fragments
- Couldn't find clear metadata to verify column meanings
- Survival proportions didn't match Table S3 (only 1 of 4 genotypes matched)
- **Decision:** Used raw data to estimate initial fragment length (average of reported lengths) and survival rates from Table S3
- Survival rates interpolated to estimate annual survival (original values over 18 months)

---

### 5.10 Maurer et al. 2022 (maurer_et_al_2022)

**Source:** https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0267034

**Description:** Coral fragments on line nurseries in the Bahamas

**Notes:**
- No individual size information; paper states "Each A. palmata fragment was cut into approximately 5 × 5 cm pieces"
- **Assumed initial size:** 25 cm² for all fragments
- Data span three years but no information on coral sizes at start of years 2 and 3
- **Only used data from year 1**

---

### 5.11 Forrester et al. 2013 (forrester_et_al_2013)

**Source:** https://onlinelibrary.wiley.com/doi/10.1002/aqc.2374

**Description:** Storm-generated fragments in British Virgin Islands

**Notes:**
- Survival only reported as model predictions → no sample size information per size class
- Tables 1 and 2 have size ranges and fractions surviving each year → used these instead
- **Note:** Not broken down by size (ranges ~10 cm² to ~1000 cm²)
- Figure 5 shows size changes over time, but only as scatterplot → difficult to extract values
- **Size measurement method:**
  - Small colonies (simple shapes): surface area traced from digital photographs using image analysis
  - Large colonies (complex 3D branching): SAL = [(L + W + H)/3]² where L, H, W are length, width, height

---

### 5.12 Forrester et al. 2011 (forrester_et_al_2011)

**Source:** https://onlinelibrary.wiley.com/doi/10.1111/j.1526-100X.2010.00664.x

**Description:** Storm-generated fragments in British Virgin Islands

**Notes:**
- Included several experimental treatments (relocating fragments, attachment methods, algal scrubbing)
- **Focused on relocation treatment only:** survival proportions explicitly stated and repeated in two different years (largest sample sizes)
- LAI estimated by tracing perimeter of each surface from photos using ImageJ
- Fragment growth reported as percent change in LAI after 1 year
- **Growth not used:** Without exact initial sizes, too much error to assume all fragments started at mean size (ranges span <10 cm² to >900 cm²)

---

### 5.13 Garrison & Ward 2012 (garrison_ward_2012)

**Source:** https://www.sciencedirect.com/science/article/abs/pii/S0006320708003467

**Description:** Comparing survival of control colonies and transplanted fragments in USVI

**Notes:**
- Sizes only given as mean/SE (measured as longest diameter of living tissue)
- Used estimated W:L ratios to convert linear measurements to surface areas
- Proportion surviving estimated from Fig. 4b

---

### 5.14 Williams & Miller 2010 (williams_miller_2010)

**Source:** https://onlinelibrary.wiley.com/doi/10.1111/j.1526-100X.2009.00579.x

**Description:** Naturally occurring A. palmata fragments collected from Amanda's reef in Biscayne Bay, FL, transported to nearby patch reef

**Notes:**
- Experimental treatments: alternative attachment methods (epoxy, cable-tie, control)
- Only size information: range of fragment lengths and range of percent live tissue coverage
- Used estimated fragment W:L ratios to convert to range of skeletal surface areas
- **Time interval:** 44 weeks → extrapolated to annual survival rates

---

### 5.15 Bruckner & Bruckner 2001 (bruckner_bruckner_2001)

**Source:** Bruckner & Bruckner 2001

**Description:** Surveyed survival of naturally occurring fragments in Mona Island, Puerto Rico

**Notes:**
- All initial sizes and proportions surviving estimated from stacked histogram in Fig. 3
- **Note:** Figure includes larger size classes than in dataframe, but excluded due to few individuals (estimates likely inaccurate)
- **Time interval:** 2 years → survival rates interpolated to estimate annual rates

---

### 5.16 Schutter et al. 2023 (schutter_et_al_2023)

**Source:** Schutter et al. 2023

**Description:** Testing effects of feeding and water conditions on survival and growth of A. palmata recruits (raised ex situ and outplanted to nursery in Bahamas)

**Notes:**
- Survival calculated per plate as percentage of plugs with live recruits → can't get precise numbers surviving
- **Growth used instead:** differences in average sizes over different time intervals
  - Lab recruits: didn't differentiate treatments (didn't differ significantly)
  - Outplanted recruits: after 4 weeks in nursery
- **Sample sizes:**
  - Initial recruits differed between treatments: n=42 (ambient), n=49 (AxF), n=35 (TA), n=35 (TAxF)
  - Sample size at 53 days not stated → assumed proportion surviving = proportion of plugs with at least one recruit (estimated from Fig. 6, midpoint between 4 and 9 weeks)
  - Outplanted recruits: n=3-10 stated → assumed n=6 (midpoint rounded down)
- Data availability statement says data available upon request

---

### 5.17 Papke et al. 2021 (papke_et_al_2021)

**Source:** https://www.frontiersin.org/journals/marine-science/articles/10.3389/fmars.2021.623963/full

**Description:** Comparing growth of microfragments on ceramic vs. cement substrate in lab

**Notes:**
- Growth and survival measured over 193 days → extrapolated to estimate annual rates
- Survival was 100%, so extrapolated value unchanged

---

### 5.18 Ortiz Prosper 2005 (ortiz_prosper_2005)

**Source:** PhD thesis on storm-generated A. palmata fragments in Puerto Rico

**Description:** Includes matrix model built from tracking individual fragments

**Notes:**
- Size = initial live surface area of fragments
- **Size measurement:** "data from measurements of live coral tissue was used to calculate tissue surface area (cm²) (area = maximum length × width of live tissue portion of fragment in cm). Because underside of most fragments were already dead, fragment surface area was estimated using collected data from upper side of fragment"
- Figure 3.4 shows number of fragments in 200 cm² size intervals up to 3000 cm²
- Estimated numbers from figure; used to estimate mean fragment size in largest size class with reported survival rates (>600 cm²)
- **Smallest size class lower bound:** "Fragments under 10 cm long were not observed" → converted to min cm² using min width:length ratio

---

### 5.19 Roth et al. 2013 (roth_et_al_2013)

**Source:** https://www.sciencedirect.com/science/article/abs/pii/S0304380013002524

**Description:** Used data tracking individual A. palmata in US Virgin Islands to parameterize matrix model

**Notes:**
- Size measured as longest diameter in cm → converted to cm² using colony width:length ratios
- Numbers of colonies not explicitly stated → estimated from histograms in Fig. 5
- Matrix values averaged across 5 survey years → also averaged estimated numbers across these years
- Upper bound of largest size class estimated using same size intervals from smaller classes (no information on largest observed colony)

---

### 5.20 Vardi 2011 (vardi_2011)

**Source:** Tali Vardi's PhD thesis

**Description:** Tracked individual colonies and reported transition matrices for Florida, Curaçao, Navassa, Jamaica, Puerto Rico, and Virgin Gorda

**Notes:**
- Florida, Curaçao, Navassa sampling years and plot locations **included in large NOAA survey dataset** → assumed same corals, not duplicated here
- **Only used survival estimates from Jamaica, Puerto Rico, and Virgin Gorda**
- Only reported total initial number of colonies and proportions in each of four size classes
- Estimated initial number per size class from stacked bar plots in Fig. 4-2
- **Time interval adjustments:** Several surveys had intervals >1 or <1 year → interpolated/extrapolated to estimate annual survival

---

## 6. Fragmentation Data

### 6.1 Fragmentation Dataset Columns

| Column | Description |
|--------|-------------|
| `study` | Name of study or dataset |
| `region` | Country/geographic region |
| `location` | Name of reef, bay, etc. |
| `plot` | Sampling plot on reef |
| `treatment_1` | First experimental treatment |
| `treatment_2` | Second experimental treatment |
| `latitude` | Latitude in °N |
| `longitude` | Longitude in °W |
| `depth_m` | Site depth in meters |
| `survey_yr` | Year when corals were surveyed |
| `F4_SC1` | Annual production rate of SC1 fragments by SC4 corals |
| `F4_SC2` | Annual production rate of SC2 fragments by SC4 corals |
| `F4_SC3` | Annual production rate of SC3 fragments by SC4 corals |
| `F4_SC4` | Annual production rate of SC4 fragments by SC4 corals |
| `F5_SC1` | Annual production rate of SC1 fragments by SC5 corals |
| `F5_SC2` | Annual production rate of SC2 fragments by SC5 corals |
| `F5_SC3` | Annual production rate of SC3 fragments by SC5 corals |
| `F5_SC4` | Annual production rate of SC4 fragments by SC5 corals |
| `F5_SC5` | Annual production rate of SC5 fragments by SC5 corals |
| `time_interval_yr` | Time interval in years |
| `disturbance` | Major disturbance during period |
| `study_notes` | Notes on assumptions |

### 6.2 Source: Vardi 2011

Use fragmentation rates reported in Vardi 2011 because:
1. Larger size classes (which produce majority of fragments) match the model
2. Cover relatively large geographic range (Florida Keys, Curaçao, Navassa, Jamaica, Puerto Rico) using consistent methodology

**Vardi 2011 Methods:**
> "New fragments are assumed to arise from the existing stand of colonies and can be of any size class. New SC3 fragments are assumed to derive solely from pre-existing SC4 colonies. New fragments of SC1 and SC2 were assumed to derive from existing SC3 and SC4 colonies proportionally, based on the ratio of mean size of SC4 colonies to that of SC3 at the beginning of the time interval."

### 6.3 Size Class Splitting

Split smallest Vardi size class (SC1_V: 0-100 cm²) into two classes:
- SC1_new: 0-25 cm²
- SC2_new: 25-100 cm²

Since no information on whether SC1_V fragments would be in SC1_new or SC2_new, assumed fraction proportional to range covered:
- SC1_V spans 0-100 cm²
- SC1_new spans 0-25 cm² = 25% of range → 25% of SC1_V fragments go to SC1_new
- SC2_new spans 25-100 cm² = 75% of range → 75% of SC1_V fragments go to SC2_new

---

## 7. Short-Term Lab Survival Data

### 7.1 Dataset Columns

| Column | Description |
|--------|-------------|
| `study` | Name of study or dataset |
| `region` | Country/geographic region where spawn collected |
| `location` | Name of reef, bay where spawn collected |
| `treatment_1` | First experimental treatment |
| `treatment_2` | Second experimental treatment |
| `spawn_yr` | Year when corals surveyed |
| `substrate_type` | Type of settlement substrate used |
| `prop_survived` | Proportion surviving to interval end |
| `n_initial` | Initial number of settlers |
| `time_interval_d` | Time interval in days |
| `study_notes` | Notes on assumptions |

### 7.2 Randall & Szmant 2009

**Source:** https://www.journals.uchicago.edu/doi/10.1086/BBLv217n3p269

- First experiment (2007): spawn from Puerto Morelos Coral Reef National Park, Mexico
- Second experiment (2008): spawn from Tres Palmas Marine Reserve, Rincon, Puerto Rico (settler survival calculated for this experiment only)
- **Sample size:** 12 samples per temperature × 10 larvae per well = 120 per temperature
- Mean percent settlement in temperature treatments: 62%, 43%, 37%
- Post-settlement survivorship: 88%-100% across all treatments over 4 days
- Substrate: culture plate with CCA chip

### 7.3 Chamberland et al. 2015 (Lab Survival)

- Survival after 1 month in nursery: ~81% (from Fig. 2A)
- Substrate: clay pottery tripods
- See main Chamberland entry for full metadata

### 7.4 Erwin & Szmant 2010

**Source:** https://link.springer.com/article/10.1007/s00338-010-0634-1

- Spawn collected 2008 from Tres Palmas Marine Reserve, Rincon, Puerto Rico
- Substrate: 10 × 10 cm porcelain tiles (8 conditioned on reef, 8 unconditioned)
- `treatment_1` = tile conditioning, `treatment_2` = Hym-248 neuropeptide (4 treatments total, 4 tiles per treatment)
- 50 A. palmata planulae per tile
- Attachment to tile surfaces: 11.8% (unconditioned) and 17.0% (conditioned) with Hym-248; 0% without Hym-248 (most attachment on container sides)
- Short-term (12 and 36 days) survival assessed on reef

### 7.5 Albright et al. 2010

**Source:** https://www.pnas.org/doi/full/10.1073/pnas.1007273107

- Spawn from Upper Florida Keys, 2009
- Substrate: limestone settlement tiles + live rock as CCA source
- 3 CO₂ treatments, four 24-well plates per treatment, one tile + 10 larvae per well
- **Sample size:** 24 × 10 × 4 = 960 larvae per treatment
- Percent settlement in control: ~65%
- Settlement reduced by 45% at mid CO₂ and 69% at high CO₂ compared to control

---

## 8. Analysis Notes

### 8.1 General Approach

1. Make cleaned-up map and updated plots
2. Separate field data from nursery data
3. For individual survival data: binomial GLMM
   - Reference: https://library.virginia.edu/data/articles/getting-started-with-binomial-generalized-linear-mixed-models

### 8.2 Size Range Exclusions

For studies where size was only given as a range spanning multiple size classes with no information about means or variability: **excluded from size-class analyses** since they don't provide information on differences in survival between size classes.

### 8.3 Live Area Assumptions

Ideally would use live area, but not always available. In these cases: use skeletal area and assume 100% tissue cover.

### 8.4 Summary Data Handling

For data that did not measure individuals, randomly drew sizes and survival/growth of n individuals (where n = study's sample size) using available information:

| Information Available | Approach |
|----------------------|----------|
| Mean only, no variability info | Assume all individuals had mean value |
| Max and min only (no SD) | Draw from uniform distribution in range |
| Mean and SD available | Draw from normal distribution |

### 8.5 Time Interval Adjustments

For individual survival data with intervals ≠1 year:

| Scenario | Approach |
|----------|----------|
| Interval < 1 year AND coral died | Survival at 1 year would also be 0 |
| Interval > 1 year AND coral survived | Survival at 1 year would also be 1 |
| Survived < 1 year OR died after > 1 year | Use proportions surviving from region/year/size class to estimate rates; convert to annual; move to summary dataset |

---

## Document Information

**GitHub Repository:** https://github.com/stier-lab/Detmer-2025-coral-parameters

**Data Integration Pipeline:** See `APAL_data_integration.rmd`

**Analysis Pipeline:** See `APAL_data_analysis.rmd`

---

*Document prepared by: Raine Detmer & Adrian Stier*
*Ocean Recoveries Lab, UC Santa Barbara*
*December 2025*
