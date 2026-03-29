# PRISMA Data Extraction Verification Table

**Project:** *Acropora palmata* Size-Dependent Demography Synthesis (Detmer et al. 2025)
**Purpose:** Document exactly what was extracted from each included study, where values came from in the source paper, and any assumptions made. A reader should be able to trace any number in the meta-analysis back to a specific page, table, or figure in the source paper.

**Total included studies:** 16 unique studies contributing 20 study-level effects (NOAA split into FL Keys/Curacao/Navassa; Vardi 2011 split into Jamaica/PR/Virgin Gorda). Two additional studies were initially included but later removed: Ramos et al. 2024 (invalid survival proxy) and Roth et al. 2013 (data overlap with Rogers & Muller 2012 -- same Haulover Bay colonies).

**Data tiers:**
- **Tier 1 (individual-level):** 5 studies with raw colony/fragment-level data from public repositories or direct sharing. Survival rates computed directly from individual fates.
- **Tier 2 (summary, hand-extracted):** 10 study-level effects from 8 papers, extracted by R. Detmer from published tables, figures, and text. (Roth et al. 2013 was subsequently removed for data overlap with Rogers & Muller 2012.)
- **Tier 2 (summary, AI-extracted):** 3 study-level effects from 3 papers, extracted by Claude (Anthropic) from source PDFs in March 2026 and independently audited.

**Effect size:** Proportional log-odds (PLO) with Haldane correction for zero cells. All survival rates annualized assuming constant hazard: `surv_annual = surv_raw^(1/time_interval_yr)`.

---

## Tier 1 Studies (Individual-Level Data)

---

### Study 1: NOAA_survey

**Citation:** Southeast Fisheries Science Center (2025). Elkhorn coral demographic monitoring from 2004-03-30 to 2024-08-15. NCEI Accession 0142175. https://www.fisheries.noaa.gov/inport/item/22436

**Data source:** Public data repository (NOAA NCEI). Raw file: `original_data/NOAA_Tagged_Colony_Data.csv` with survey dates in `data_documentation/SurveyDates.csv`.

**Extractor:** Detmer (raw data processing via R scripts)

**Values extracted:**
- n_total: 3,968 — number of unique tagged colony-intervals with valid survival outcome
- n_survived: 3,456 — colonies alive at end of each ~1-year interval
- survival_rate: 0.871 — pooled across all intervals 2004-2024
- mean_size_cm2: 4,520.2 — mean live planar tissue area (L x W x %live / 100)
- population_type: Natural colony — wild tagged colonies on reef
- region: Florida (primary), Curacao, Navassa
- survey_yr: 2004-2024 (year_end = 2024)

**Assumptions:**
- Size = Length x Width x (%Live / 100), following Vardi et al. 2012 protocol
- Mortality defined as: (1) at least part of skeleton found with no tissue remaining, or (2) no skeleton/tissue left where coral had previously been
- For sites with sub-annual sampling, only survey dates approximately 1 year apart were selected, starting from the first sample date
- Disturbance years based on Vardi 2011 Fig. 4-2 (storm years); no disturbance data after 2011
- Assigned to "Florida" region in meta-analysis because the plurality of observations originate from Florida reef tract sites

**Audit status:** N/A (Tier 1 raw data; processed directly by analysis pipeline)

**Value entering meta-analysis:** survival_rate = 0.871, n = 3,968, log_odds = 1.910, SE = 0.047

---

### Study 2: pausch_et_al_2018

**Citation:** Pausch RE, Williams DE, Miller MW (2018). Impacts of fragment genotype, habitat, and size on outplant survival of nursery-cultured restored coral. *Mar Ecol Prog Ser* 592:109-117. Data: NOAA InPort 26790. https://www.fisheries.noaa.gov/inport/item/26790

**Data source:** Public data repository (NOAA InPort). Raw files: `original_data/Pausch_2018_Data_Table_Size.csv` and `Pausch_2018_Data_Table_Genet.csv`.

**Extractor:** Detmer (raw data processing via R scripts)

**Values extracted:**
- n_total: 968 — number of outplanted fragment-intervals
- n_survived: 556 — fragments alive at end of ~1-year interval
- survival_rate: 0.574 — pooled across all genets, habitats, sizes
- mean_size_cm2: 63.8 — mean fragment planar area
- population_type: Restoration fragment — nursery-cultured, outplanted fragments
- region: Florida (Upper Florida Keys)
- survey_yr: 2015-2016

**Assumptions:**
- Two experiments: (1) fragment size experiment on forereef controlling for genet, (2) genet performance across forereef and nearshore patch reefs
- Dead fragments were assumed not to appear in data in subsequent sampling years (survival rates matched Pausch et al. 2018 only under this assumption; not explicitly stated in metadata)
- Sampling time interval approximated as average interval for surviving fragments (~1 year)
- Size = L x W x %live planar area

**Audit status:** N/A (Tier 1 raw data)

**Value entering meta-analysis:** survival_rate = 0.574, n = 968, log_odds = 0.300, SE = 0.065

---

### Study 3: USGS_USVI_exp

**Citation:** USGS (2021). Experimental growth data and time-series imagery for *A. palmata* and *Pseudodiploria strigosa* in USVI. https://cmgds.marine.usgs.gov/catalog/spcmsc/Coral_growth_VI_USA_metadata.faq.html

**Data source:** Public data repository (USGS CMGDS). Raw file: `original_data/USGS_Palmata_growth_VI_USA.csv`.

**Extractor:** Detmer (raw data processing via R scripts)

**Values extracted:**
- n_total: 46 — outplanted colonies tracked across annual intervals
- n_survived: 30 — colonies alive at end of interval
- survival_rate: 0.652 — pooled across two ~1-year intervals (June 2019-June 2020, June 2020-Aug 2021)
- mean_size_cm2: 59.5 — estimated from raw photographs at initial time point (June 2019) and from initial sizes + reported growth rates for June 2020
- population_type: Restoration fragment — outplanted colonies
- region: USVI
- survey_yr: 2020-2021

**Assumptions:**
- Tagged colonies outplanted June 2019, monitored until July 2021
- Dataset includes growth rates and alive/dead status but not initial colony size; size estimated from raw photographs for June 2019 and from initial sizes + growth rates for June 2020
- Exact time intervals not given; approximated as 1 year for first interval (June 2019 to June 2020) and 13/12 year for second (June 2020 to Aug 2021)
- "Dead" = no live tissue remaining at end of time interval
- Growth = change in coral planar-footprint area per day

**Audit status:** N/A (Tier 1 raw data)

**Value entering meta-analysis:** survival_rate = 0.652, n = 46, log_odds = 0.629, SE = 0.310

---

### Study 4: kuffner_et_al_2020

**Citation:** Kuffner IB, Lidz BH, Hudson JH, Anderson JS (2020). Injured and threatened *Acropora palmata*: survival after fragmentation and re-cementation. *Endang Species Res* 43:269-279. Data: https://coastal.er.usgs.gov/data-release/doi-P9KZEGXY/

**Data source:** Public data repository (USGS Data Release). Raw file: `original_data/Kuffner_et_al_2020_*.csv`.

**Extractor:** Detmer (raw data processing via R scripts)

**Values extracted:**
- n_total: 53 — outplanted colonies tracked over spring 2018 to spring 2019
- n_survived: 43 — colonies alive at end of 1-year interval
- survival_rate: 0.811 — over 1-year interval (spring 2018 to spring 2019)
- mean_size_cm2: 17.6 — estimated from raw photographs at initial time point
- population_type: Restoration fragment — outplanted fragments
- region: Florida (Florida Keys)
- survey_yr: 2019

**Assumptions:**
- Colonies outplanted late April/early May 2018, monitored until fall 2019; three time intervals (spring-fall 2018, fall 2018-spring 2019, spring-fall 2019)
- Only data from Spring 2018 through Spring 2019 (one year) used; exact dates unavailable so time_interval_yr assumed to be 1
- Mortality defined as >=50% tissue mortality (but Detmer checked photos and all "dead" corals appeared 100% dead)
- Initial colony size estimated from raw photographs (not in dataset)

**Audit status:** N/A (Tier 1 raw data)

**Value entering meta-analysis:** survival_rate = 0.811, n = 53, log_odds = 1.459, SE = 0.351

---

### Study 5: fundemar_fragments

**Citation:** FUNDEMAR (unpublished). *A. palmata* fragment growth and survival data. Shared directly by Maria (FUNDEMAR, Dominican Republic). Raw file: `original_data/Crecimiento_Fragmentos_APAL.xlsx`.

**Data source:** Direct data sharing from FUNDEMAR (Dominican Republic coral restoration NGO).

**Extractor:** Detmer (raw data processing via R scripts)

**Values extracted:**
- n_total: 44 — fragments from Table 1 of the nursery dataset (the only table spanning a full year)
- n_survived: 38 — fragments alive at 1 year
- survival_rate: 0.864 — over 1-year interval
- mean_size_cm2: 20.1 — fragment planar area
- population_type: Restoration fragment — nursery-cultured fragments
- region: Dominican Republic (Sombrero restoration site)
- survey_yr: 2021

**Assumptions:**
- Fragments from 6 localities placed on PVC table structures, with regular algal scrubbing maintenance
- Only Table 1 data used (spans ~1 year); Tables 2-6 span only 5 months
- Tables 4 and 5 had mismatched row/tag/fragment labels between sampling time points (flagged by Detmer)

**Audit status:** N/A (Tier 1 raw data)

**Value entering meta-analysis:** survival_rate = 0.864, n = 44, log_odds = 1.846, SE = 0.439

---

## Tier 2 Studies (Summary-Level, Hand-Extracted by Detmer)

---

### Study 6: vardi_2011_jamaica

**Citation:** Vardi T (2011). Demographic assessment of the endangered coral *Acropora palmata* across the Caribbean using a population modeling approach. PhD Dissertation, University of Miami.

**Data source:** Dissertation Chapter 4, transition matrices (Fig. 4-2 stacked bar plots for initial colony counts per size class; matrix tables for survival proportions per size class).

**Extractor:** Detmer

**Values extracted:**
- n_total: 88 (effective n from max n_initial across size classes) — estimated from stacked bar plots in Fig. 4-2 (Jamaica panel). Size classes: SC1=16, SC2=46, SC3=17, SC4=21 (note: some individuals overlap across survey intervals)
- prop_survived per size class (4 rows in CSV):
  - SC1: 0.397 over 0.75 yr (n=16)
  - SC2: 0.780 over 0.75 yr (n=46)
  - SC3: 1.000 over 0.75 yr (n=17)
  - SC4: 0.934 over 0.75 yr (n=21)
- time_interval_yr: 0.75 — sub-annual, so survival rates extrapolated to annual
- mean_size_cm2: 35.7 (SC1), 291.5 (SC2), 1475.9 (SC3), 7288.3 (SC4) — averages from multiple regions; size conversions use estimated W:L ratios
- population_type: Natural colony — wild colonies tracked in Jamaica (Pear Tree Bottom, Rio Bueno, Split Rock)
- survey_yr: ~2009

**Assumptions:**
- Florida, Curacao, and Navassa regions from Vardi 2011 are excluded because they overlap with the NOAA survey dataset (same colonies, sites, and monitoring program)
- Colony counts per size class estimated visually from stacked bar plots in Fig. 4-2 (inherent reading error)
- Time intervals between surveys were <1 year in Jamaica, so survival rates were extrapolated to annual
- Size boundaries for size classes estimated (upper and lower bounds)
- Size means are averages across multiple regions
- Raw CSV has fragment="Y" because Vardi records fragmentation events on natural colonies; overridden to "Natural colony" in pipeline

**Audit status:** N/A (hand-extracted by domain expert)

**Value entering meta-analysis:** survival_rate = 0.761 (n_survived=67, n=88), annualized and n-weighted across 4 size classes. log_odds = 1.160, SE = 0.250

---

### Study 7: vardi_2011_puerto_rico

**Citation:** Same as Study 6 (Vardi 2011 dissertation).

**Data source:** Dissertation Chapter 4, Fig. 4-2 (Puerto Rico panel) and transition matrices.

**Extractor:** Detmer

**Values extracted:**
- n_total: 130 — estimated from stacked bar plots. Size classes: SC1=73, SC2=130, SC3=97, SC4=106 (max n_initial = 130)
- prop_survived per size class (4 rows):
  - SC1: 0.729 over 2.75 yr (n=73)
  - SC2: 0.777 over 2.75 yr (n=130)
  - SC3: 0.845 over 2.75 yr (n=97)
  - SC4: 0.878 over 2.75 yr (n=106)
- time_interval_yr: 2.75 — survival rates interpolated to annual
- mean_size_cm2: same cross-region averages as Jamaica
- population_type: Natural colony — Tres Palmas, Cayo Ron, and La Cordillera
- survey_yr: ~2010

**Assumptions:**
- Same as Study 6 regarding size class estimation
- 2.75-year interval requires interpolation: surv_annual = surv_raw^(1/2.75)

**Audit status:** N/A (hand-extracted by domain expert)

**Value entering meta-analysis:** survival_rate = 0.923 (n_survived=120, n=130), annualized and n-weighted. log_odds = 2.485, SE = 0.329

---

### Study 8: vardi_2011_virgin_gorda

**Citation:** Same as Study 6 (Vardi 2011 dissertation).

**Data source:** Dissertation Chapter 4, Fig. 4-2 (Virgin Gorda panel) and transition matrices.

**Extractor:** Detmer

**Values extracted:**
- n_total: 27 — estimated from stacked bar plots. Size classes: SC1=9, SC2=27, SC3=12, SC4=10
- prop_survived per size class (4 rows):
  - SC1: 0.718 over 1.75 yr (n=9)
  - SC2: 0.977 over 1.75 yr (n=27)
  - SC3: 0.953 over 1.75 yr (n=12)
  - SC4: 1.000 over 1.75 yr (n=10)
- time_interval_yr: 1.75 — interpolated to annual
- mean_size_cm2: same cross-region averages
- population_type: Natural colony — Mountain Point and West Dog
- survey_yr: ~2007

**Assumptions:**
- Small sample size (n=27 max); highest discretization error in meta-analysis (1/(2*27) = 1.9 percentage points)
- Same size estimation and interpolation assumptions as other Vardi regions

**Audit status:** N/A (hand-extracted by domain expert)

**Value entering meta-analysis:** survival_rate = 0.963 (n_survived=26, n=27), annualized and n-weighted. log_odds = 3.258, SE = 1.019

---

### Study 9: bruckner_bruckner_2001

**Citation:** Bruckner AW, Bruckner RJ (2001). Condition of restored *Acropora palmata* fragments off Mona Island, Puerto Rico, 2 years after the Fortuna Reefer ship grounding. *Coral Reefs* 20:235-243.

**Data source:** Fig. 3 (stacked histogram showing initial size classes and proportions surviving).

**Extractor:** Detmer

**Values extracted:**
- n_total: 105 (max n_initial across 11 size bins in CSV)
- prop_survived per size bin (11 rows): range 0.655 to 0.920 over 2-year interval
- time_interval_yr: 2 — all rows; annualized via surv^(1/2)
- mean_size_cm2: NA — size measured as fragment length only; no width data
- population_type: Restoration fragment (in pipeline), though these were naturally-occurring storm-generated fragments, not restoration outplants
- region: Puerto Rico (Mona Island)
- survey_yr: ~1999

**Assumptions:**
- All initial sizes and proportions surviving estimated from the stacked histogram in Fig. 3
- Larger size classes with very few individuals excluded by Detmer because estimates would be inaccurate
- Fragment size given only as length; no width data available. Size set to NA.
- Classified as "Restoration fragment" in pipeline because fragments were tracked after a ship grounding disturbance. NOTE: sensitivity analysis in Section 11 of 14b script reclassifies as Natural.
- 2-year survival rates interpolated to annual: surv_annual = surv_raw^(1/2)

**Audit status:** N/A (hand-extracted by domain expert)

**Value entering meta-analysis:** survival_rate = 0.905 (n_survived=95, n=105), annualized and n-weighted. log_odds = 2.251, SE = 0.332

---

### Study 10: roth_et_al_2013 -- EXCLUDED (data overlap with Rogers & Muller 2012)

**Citation:** Roth L, Muller EM, van Woesik R (2013). Population dynamics of endangered *Acropora palmata* in the northern Caribbean. *Ecol Modelling* 263:19-27.

**Status: EXCLUDED.** Removed during an exhaustive overlap audit. Roth et al. 2013 uses the same Haulover Bay (St. John, USVI) colony data as Rogers & Muller 2012, confirmed from the paper's explicit citation of and acknowledgments to the Rogers & Muller monitoring program. Including both would double-count the same individuals. Rogers & Muller 2012 is retained as the primary source.

**Data source:** Fig. 5 (histograms of colony counts per size class) and transition matrix tables. Colony counts estimated from histograms.

**Extractor:** Detmer

**Values extracted (prior to exclusion):**
- n_total: 27 (max n_initial across 24 size-class x year rows)
- prop_survived per size class (24 rows, spanning 2 survey years): range 0.58 to 1.0 over 1-year intervals
- time_interval_yr: 1 — all annual intervals
- mean_size_cm2: NA — size measured as longest diameter (cm), converted to cm2 using colony W:L ratios described in Detmer's notes
- population_type: Natural colony — tracked individual A. palmata in USVI
- region: USVI (Haulover Bay, St. John Island)
- survey_yr: ~2010

**Assumptions:**
- Colony counts not explicitly stated in paper; estimated from histograms in Fig. 5
- Matrix values averaged across 5 survey years; colony counts also averaged across years
- Size measured as longest diameter; converted to cm2 using estimated colony width:length ratios (described in "Data structure" section of Detmer notes)
- Upper bound of largest size class estimated using same size intervals from smaller classes (no information on largest observed colony)
- Uppermost and lowermost size boundaries are estimated

**Audit status:** N/A (hand-extracted by domain expert). Subsequently excluded for data overlap.

**Value NOT entering meta-analysis:** survival_rate = 0.815 (n_survived=22, n=27). Excluded due to colony-level overlap with Rogers & Muller 2012.

---

### Study 11: ortiz_prosper_2005

**Citation:** Ortiz-Prosper AL (2005). Population dynamics of storm-generated *Acropora palmata* fragments on patch reefs in southwestern Puerto Rico. PhD Dissertation, University of Puerto Rico.

**Data source:** Transition matrix tables (1-year and 2-year intervals) and Fig. 3.4 (fragment size distribution histogram).

**Extractor:** Detmer

**Values extracted:**
- n_total: 207 (max n_initial across 8 rows: 4 size bins x 2 time intervals)
- prop_survived per size bin (8 rows):
  - 1-year interval (n=57,57,11,24): 0.474, 0.825, 0.909, 0.875
  - 2-year interval (n=207,77,33,47): 0.565, 0.767, 0.795, 0.933
- time_interval_yr: 1 or 2 — annualized for 2-year rows
- mean_size_cm2: 1,144 for largest size class (>600 cm2) — estimated from Fig. 3.4 fragment size distribution. Other classes = NA
- population_type: Restoration fragment — storm-generated fragments on patch reefs
- region: Puerto Rico (San Cristobal Reef; San Cristobal, Media Luna, and Laurel Reefs)
- survey_yr: ~2000

**Assumptions:**
- Size = initial live surface area (max length x width of live tissue, upper side only)
- Mean fragment size in largest size class (>600 cm2) estimated from Fig. 3.4 histogram showing number of fragments in 200 cm2 intervals up to 3000 cm2
- Lower bound of smallest class (<200 cm2): fragments under 10 cm long not observed, converted to min cm2 using estimated fragment W:L ratio
- Two time intervals (1-year and 2-year); 2-year rates annualized

**Audit status:** N/A (hand-extracted by domain expert)

**Value entering meta-analysis:** survival_rate = 0.787 (n_survived=163, n=207), annualized and n-weighted. log_odds = 1.310, SE = 0.170

---

### Study 12: forrester_et_al_2013

**Citation:** Forrester GE, Connell S, Taylor M, et al. (2013). Assessing and revising the survival of storm-generated coral fragments. *Aquatic Conserv: Mar Freshw Ecosyst* 24:153-159.

**Data source:** Tables 1 and 2 (size ranges and fractions surviving each year by cohort/location).

**Extractor:** Detmer

**Values extracted:**
- n_total: 257 (max n_initial across 11 cohort/year rows)
- prop_survived per row (11 rows): range 0.21 to 0.85 over 1-year intervals
- time_interval_yr: 1 — all annual intervals
- mean_size_cm2: 78 to 198 per row — size measured as LAI (live area index)
- population_type: Restoration fragment — storm-generated fragments on Guana Island, BVI
- region: British Virgin Islands (Guana Island)
- survey_yr: ~2009

**Assumptions:**
- Survival reported only as predictions from statistical model, but Tables 1 and 2 have information on size ranges and fractions surviving each year, so those were used instead
- Size measured differently for small vs. large colonies: small colonies traced from photos; large colonies estimated as [(L + W + H)/3]^2
- Figure 5 (scatterplot of fragment size changes over time) was not used because extracting values from the raw scatterplot would be too imprecise
- Sizes range from ~10 cm2 to ~1000 cm2, not broken down by size class within each cohort row

**Audit status:** N/A (hand-extracted by domain expert)

**Value entering meta-analysis:** survival_rate = 0.533 (n_survived=137, n=257), n-weighted mean across 11 rows. log_odds = 0.132, SE = 0.125

---

### Study 13: rosales_et_al_2024

**Citation:** Rosales SM, Huebner LK, Evans JS, et al. (2024). The persistence of restored coral depends more on reef environment than on genotype. *Commun Earth Environ* 5:726.

**Data source:** Table S3 (survival rates by genotype and site over 18 months) and GitHub repository (https://github.com/srosales712/CoralPersistence/) for fragment lengths.

**Extractor:** Detmer

**Values extracted:**
- n_total: 58 (max n_initial across 12 genotype-by-site rows: 4 genotypes x 3 sites)
- prop_survived per row (12 rows): range 0.097 to 1.0 over 1.5-year intervals
- time_interval_yr: 1.5 — all rows; annualized via surv^(1/1.5)
- mean_size_cm2: 40.7 — estimated from average of reported initial fragment lengths using W:L ratio
- population_type: Restoration fragment — nursery-cultured outplants
- region: Florida Keys (Carysfort Reef, North Dry Rocks Reef, Pickles Reef)
- survey_yr: 2019

**Assumptions:**
- GitHub repo data (POR_meta_apal_live.csv) appeared to have individual size data but only for a subset of fragments; metadata unclear; Detmer could not match survival proportions to Table S3 for 3 of 4 genotypes
- Decided to use raw data only for estimating initial fragment length, and use survival rates from Table S3
- Survival rates interpolated from 18-month interval to annual: surv_annual = surv_raw^(1/1.5)
- Size estimated from approximate fragment length using W:L conversion

**Audit status:** N/A (hand-extracted by domain expert)

**Value entering meta-analysis:** survival_rate = 0.793 (n_survived=46, n=58), annualized and n-weighted. log_odds = 1.344, SE = 0.324

---

### Study 14: maurer_et_al_2022

**Citation:** Maurer AS, Sura SA, Lirman D (2022). Abiotic and biotic drivers of *Acropora palmata* survival and performance on a coral restoration nursery in the upper Florida Keys. *PLoS ONE* 17:e0267034.

**Data source:** Published tables (survival per nursery line/plot, year 1 only).

**Extractor:** Detmer

**Values extracted:**
- n_total: 24 (max n_initial across 5 nursery plot rows at Castaway and Glassbottom sites)
- prop_survived per row (5 rows): 0.913 to 0.958 over 1-year interval
- time_interval_yr: 1 — year 1 only
- mean_size_cm2: 25 — all fragments approximately 5 x 5 cm
- population_type: Restoration fragment — nursery line fragments in the Bahamas
- region: Bahamas
- survey_yr: 2017

**Assumptions:**
- No individual size information; paper states "each *A. palmata* fragment was cut into approximately 5 x 5 cm pieces" so all assumed to be 25 cm2
- Data span 3 years but no information on colony sizes at start of years 2 and 3; only year 1 data used
- Small sample size (n=24 max) yields high discretization error

**Audit status:** N/A (hand-extracted by domain expert)

**Value entering meta-analysis:** survival_rate = 0.958 (n_survived=23, n=24), n-weighted mean. log_odds = 3.135, SE = 1.022

---

### Study 15: williams_miller_2010

**Citation:** Williams DE, Miller MW (2010). Stabilization of fragments to enhance *Acropora palmata* survival and growth after attachment to reefs. *Restor Ecol* 18:793-799.

**Data source:** Published tables (survival by stabilization treatment over 44 weeks).

**Extractor:** Detmer

**Values extracted:**
- n_total: 18 (max n_initial across 3 treatment rows; all treatments had n=18)
- prop_survived per row (3 rows): 0.681, 0.806, 0.870 over 0.846-year interval (44 weeks)
- time_interval_yr: 0.846 (44/52 weeks) — extrapolated to annual
- mean_size_cm2: NA — only size information was range of fragment lengths and range of %live tissue coverage
- population_type: Restoration fragment — naturally-occurring fragments collected from Amanda's Reef (Biscayne Bay, FL) and transported to a nearby patch reef
- region: Florida Keys (Biscayne National Park)
- survey_yr: ~2007

**Assumptions:**
- Size information limited to range of fragment lengths and %live tissue; converted to range of skeletal surface areas using estimated fragment W:L ratios
- 44-week interval extrapolated to annual survival rates: surv_annual = surv_raw^(1/0.846)
- Three experimental treatments (epoxy, cable-tie, control) each with n=18

**Audit status:** N/A (hand-extracted by domain expert)

**Value entering meta-analysis:** survival_rate = 0.778 (n_survived=14, n=18), annualized and n-weighted. log_odds = 1.253, SE = 0.567

---

### Study 16: garrison_ward_2008

**Citation:** Garrison VH, Ward G (2008). Storm-generated fragments of the reef coral *Acropora palmata*: Salvage and transplantation. *Biol Conserv* 141:1636-1643.

**Data source:** Fig. 4b (proportion surviving over time by treatment) and published text for mean sizes (mean/SE of longest diameter).

**Extractor:** Detmer

**Values extracted:**
- n_total: 45 (max n_initial across 2 treatment rows: control natural colonies n=45, transplanted fragments n=30)
- prop_survived per row (2 rows):
  - Control (natural colonies): 0.80 over 1 yr (n=45)
  - Transplanted (relocated fragments): 0.55 over 1 yr (n=30)
- time_interval_yr: 1 — annual
- mean_size_cm2: 470.2 (control), 219.7 (transplanted) — converted from mean longest diameter of living tissue using estimated W:L ratios
- population_type: Natural colony (in pipeline) — mixed study; includes both natural control and relocated fragments
- region: USVI (St. John Island)
- survey_yr: ~2000

**Assumptions:**
- Proportion surviving estimated from Fig. 4b
- Sizes given only as mean/SE of longest diameter of living tissue; converted to surface area using estimated colony W:L ratios from Detmer's cross-study calibration
- Classified as "Natural colony" in meta-analysis despite including transplanted fragments; the control colonies are the primary natural colony data
- Depth is midpoint of reported range

**Audit status:** N/A (hand-extracted by domain expert)

**Value entering meta-analysis:** survival_rate = 0.689 (n_survived=31, n=45), n-weighted mean. log_odds = 0.795, SE = 0.322

---

## Tier 2 Studies (Summary-Level, AI-Extracted, March 2026)

---

### Study 17: rogers_muller_2012

**Citation:** Rogers CS, Muller EM (2012). Bleaching, disease and recovery in the threatened scleractinian coral *Acropora palmata* in St. John, US Virgin Islands: 2003-2010. *Coral Reefs* 31:807-819.

**Data source:** Paper text (colony count and survival duration) and Fig. 7 (annual mortality bar chart, not used for meta-analysis value).

**Extractor:** AI (Claude) — March 2026

**Values extracted:**
- n_total: 69 — from paper text: "69 tagged natural colonies" monitored Jan 2003 to Dec 2009
- n_survived: 44 — from paper text: "44 of 69 survived 7 years"
- prop_survived (raw): 0.638 — 44/69 over 7 years
- time_interval_yr: 7 — full tracking duration 2003-2009
- mean_size_cm2: NA — size measured in volume (cm3), not planar area; range 48-1,949,900 cm3. Set to NA because volume is not convertible to planar area.
- population_type: Natural colony — wild colonies in Haulover Bay, St. John, USVI
- region: US Virgin Islands
- survey_yr: 2009
- fragment: N (whole colonies)

**Assumptions:**
- 7-year survival annualized: surv_annual = 0.638^(1/7) = 0.937
- Rounding: n_survived = round(0.937 x 69) = 65, so effective survival_rate = 65/69 = 0.942
- Colony mortality was primarily from disease (white pox) and bleaching (especially 2005)
- Fragment data (141 fragments, 44% survival over 6+ months) extracted separately but not used in meta-analysis
- Independence from NOAA_survey confirmed: different institution (USGS/NPS), different bay (Haulover Bay vs. NOAA sites), different monitoring protocol

**Audit status:** PASS. Audit found: 2003 Fig. 7 mortality read as ~13% when it should be ~7% (not used in meta-analysis). Fragment survival (44%) is a 6-month threshold, not cumulative. Core values (69 colonies, 44 survived, 7 years) verified against paper text.

**Value entering meta-analysis:** survival_rate = 0.942, n = 69, log_odds = 2.788, SE = 0.515

---

### Study 18: ramos_romero_et_al_2025

**Citation:** Ramos-Romero I, et al. (2025). [Restoration fragment survival in Cuba]. (Full citation in manuscript bibliography.)

**Data source:** Table 2 (Kaplan-Meier survival probabilities at end of monitoring period, by site and reef crest zone).

**Extractor:** AI (Claude) — March 2026

**Values extracted:**
- n_total: 200 — 50 fragments per site x 4 sites (25 per zone x 2 zones per site)
- prop_survived per site (4 rows in CSV, each averaging back-crest and fore-crest zones):
  - Playa Baracoa: 0.70 over 1.24 yr (avg of back=0.6, fore=0.8; 453 days)
  - Rincon de Guanabo: 0.50 over 1.19 yr (avg of back=0.3, fore=0.7; monitoring ~435 days)
  - El Peruano (Jardines de la Reina): 0.65 over 1.16 yr (avg of back=0.7, fore=0.6; ~423 days)
  - Mariflores (Jardines de la Reina): 0.80 over 1.16 yr (avg of back=0.7, fore=0.9; ~423 days)
- time_interval_yr: 1.16 to 1.24 — corrected from last KM event (232-347 days) to full monitoring duration (423-453 days)
- mean_size_cm2: NA — size described as cm height/width of fragments (1-7 cm), not convertible to planar area
- population_type: Restoration fragment — epoxy-attached to substrate
- region: Cuba (2 sites near Havana + 2 in Jardines de la Reina National Park)
- survey_yr: 2023

**Assumptions:**
- KM survival values averaged across back-crest and fore-crest zones within each site
- Time intervals corrected during audit: original extraction used time of last mortality event; corrected to full monitoring duration because KM survival is sustained through censoring period
- Study-level survival changed from 61.0% (pre-correction) to 70.5% (post-correction) after time interval corrections
- Fragments were 1-7 cm in width/height; size not converted to planar area

**Audit status:** PASS after corrections. Time intervals for 3/4 sites corrected from last KM event (232-347 days) to full monitoring duration (423-453 days). Study-level survival changed from 61.0% to 70.5%.

**Value entering meta-analysis:** survival_rate = 0.705 (n_survived=141, n=200), annualized and n-weighted. log_odds = 0.871, SE = 0.155

---

### Study 19: muller_et_al_2008 — EXCLUDED

**Citation:** Muller EM, Rogers CS, Spitzack AS, van Woesik R (2008). Bleaching increases likelihood of disease on *Acropora palmata* (Lamarck) in Hawksnest Bay, St. John, US Virgin Islands. *Coral Reefs* 27:191-195.

**Status:** EXCLUDED during IRR audit (March 2026).

**Data source:** Paper text (colony count, monitoring duration, mortality count).

**Extractor:** AI (Claude) — March 2026

**Values extracted (prior to exclusion):**
- n_total: 60 — from paper: "60 randomly selected tagged colonies" monitored monthly May 2004 to December 2006
- n_survived: ~45 (60 - ~15 dead) — paper states ~17% died (10 from bleaching + disease Oct-Dec 2005, plus ~5 from physical damage). Exact count ambiguous.
- prop_survived (raw): 0.75 — estimated as 45/60 over 2.583 years (31 months)
- time_interval_yr: 2.583 — 31 months (May 2004 to Dec 2006), corrected from initial extraction of 2.67 years
- mean_size_cm2: NA — size data not reported in planar area form
- population_type: Natural colony — wild colonies in Hawksnest Bay, St. John, USVI
- region: US Virgin Islands
- survey_yr: 2006

**Assumptions:**
- Annualized: surv_annual = 0.75^(1/2.583) = 0.898
- Rounding: n_survived = round(0.898 x 60) = 54, so effective survival_rate = 54/60 = 0.900
- Includes 2005 mass bleaching event; 87% of tissue loss attributed to disease
- Independence from Rogers & Muller 2012 confirmed: different bay (Hawksnest Bay, ~4 km from Haulover Bay), different colony set, overlapping time period but separate monitoring effort

**Audit status:** EXCLUDED. Time interval corrected from 2.67 to 2.583 years (31 months exact). Independence from Rogers & Muller 2012 confirmed but study excluded from meta-analysis during IRR audit.

**Value entering meta-analysis:** N/A — EXCLUDED

---

### Study 20: sutherland_et_al_2016 — EXCLUDED

**Citation:** Sutherland KP, Berry B, Park A, et al. (2016). Shifting white pox aetiologies affecting *Acropora palmata* in the Florida Keys, 1994-2014. *Phil Trans R Soc B* 371:20150205.

**Status:** EXCLUDED during IRR audit (March 2026). Contemporary FKNMS-wide survey explicitly overlaps NOAA at Carysfort and Molasses reefs (acknowledged in paper p. 11). EDR historical dataset is from a photostation, not tagged colonies.

**Data source:** Paper text and Fig. 1 (colony count decline at Eastern Dry Rocks photostation 1994-2004).

**Extractor:** AI (Claude) — March 2026

**Values extracted (prior to exclusion):**
- n_total: 92 — from paper: 92 colonies present in 1994 at Eastern Dry Rocks (EDR) photostation
- n_survived: 1 — from paper: 1 colony remained by 2004 (97.8% decline)
- prop_survived (raw): 0.011 — 1/92 over 10 years
- time_interval_yr: 10 — 1994 to 2004
- mean_size_cm2: NA — no individual size data reported
- population_type: Natural colony — wild reef population
- region: Florida Keys (Eastern Dry Rocks Reef, Lower Keys)
- survey_yr: 2004
- disturbance: WPX epidemic — peak white pox disease period

**Assumptions:**
- Annualized: surv_annual = 0.011^(1/10) = 0.637
- Rounding: n_survived = round(0.637 x 92) = 59, so effective survival_rate = 59/92 = 0.641
- Losses attributed to: 66 white pox (WPX), 15 DOA (non-disease), 10 TKO (total knock-out)
- This represents an extreme mortality event; the WPX epidemic decimated Florida A. palmata populations during this period
- FKNMS contemporary component (2008-2014, 126 colonies across 7 reefs) excluded from meta-analysis due to spatial overlap with NOAA monitoring sites (Carysfort, Molasses, Sombrero)
- EDR photostation is independent of NOAA monitoring (different institution, different site, earlier era)

**Audit status:** EXCLUDED. All extracted values verified against paper. Annotation-only error in CSV notes (0.629 should be 0.637 annualized) has no impact. Study excluded from meta-analysis during IRR audit due to overlap with NOAA monitoring (FKNMS component) and non-tagged colony methodology (EDR photostation component).

**Value entering meta-analysis:** N/A — EXCLUDED

---

### Study 21: rogers_et_al_1982

**Citation:** Rogers CS, Suchanek TH, Pecora FA (1982). Effects of Hurricanes David and Frederic (1979) on shallow *Acropora palmata* reef communities: St. Croix, U.S. Virgin Islands. *Bulletin of Marine Science* 32(2):532-548.

**Status:** INCLUDED — added during IRR audit (March 2026).

**Data source:** Table 5 — condition of labeled storm-damaged branches at 11 months post-hurricane.

**Extractor:** AI (Claude) — March 2026, added during IRR audit.

**Values extracted:**
- Buck Island:
  - n_total: 88 labeled branches
  - n_dead: 30 (34% dead)
  - n_survived: 58 (66% survival)
  - time_interval_yr: 0.917 (11 months)
- Tague Bay:
  - n_total: 85 labeled branches
  - n_dead: 55 (65% dead)
  - n_survived: 30 (35% survival)
  - time_interval_yr: 0.917 (11 months)
- Aggregated:
  - n_total: 173 (88 + 85)
  - Weighted mean annualized survival: ~48%
- fragment: Y — storm-generated fragments / broken branches, not outplanted
- population_type: Natural colony — wild reef, not outplanted
- mean_size_cm2: NA — branch dimensions not reported in planar area form
- region: US Virgin Islands (St. Croix — Buck Island and Tague Bay)
- survey_yr: 1980

**Assumptions:**
- Annualized: survival rates annualized from 11-month (0.917 yr) observation interval assuming constant hazard
- Fragment designation: labeled branches were storm-generated fragments broken by Hurricanes David and Frederic (1979), not restoration outplants
- Population type classified as Natural because these are fragments of wild colonies, not nursery-reared or transplanted material
- Independence from NOAA_survey: USGS/NPS monitoring at Buck Island and Tague Bay, St. Croix — entirely separate from NOAA's Florida/Curacao/Navassa monitoring network. Different institution, different island, different era (1979--1980 vs. 2004--2024).

**Audit status:** PASS. All values verified against Table 5 in source PDF.

**Value entering meta-analysis:** n = 173, weighted mean annualized survival ~48%, log_odds and SE computed by pipeline from site-level data.

---

## Excluded After Audit

---

### ramos_et_al_2024 (REMOVED)

**Citation:** Ramos Y, et al. (2024). [17-year monitoring of A. palmata in Cuba]. (Full citation in manuscript bibliography.)

**Data source:** Fig. 6A and 6B (recent mortality prevalence over time at Playa Baracoa and Rincon de Guanabo).

**Extractor:** AI (Claude) — March 2026. Initially extracted, then removed after audit.

**Values initially extracted:**
- prop_survived: 1 - RM_prevalence (e.g., 1 - 0.11 = 0.89 for 2012)
- n_total: NA (no tracked cohort; n=246 was fictional, derived from density x area)
- Multiple annual readings from Fig. 6A (PB) and Fig. 6B (RG)

**Reason for exclusion:** The survival proxy was scientifically indefensible. "Recent mortality" (RM) prevalence measures the proportion of colonies showing ANY recent tissue loss (partial mortality), not whole-colony death. A colony with RM is still alive. The study's own density data show 89% population decline at PB (1.8 to 0.2 col/m2) over 17 years, which contradicts the ~92% annual "survival" derived from the RM proxy. Additionally, n=246 was a fictional cohort size derived from density x area, not a tracked cohort.

**Audit status:** FAIL -- REMOVED from meta-analysis. Data retained in `ai_extracted_survival.csv` for contextual reference only. RG coordinates were also wrong by 25 km.

---

## Summary Table

| # | Study | Tier | Extractor | n | Survival (annual) | Region | Type | Source in Paper |
|---|-------|------|-----------|---|-------------------|--------|------|-----------------|
| 1 | NOAA_survey | 1 | Detmer | 3,968 | 87.1% | Florida+ | Natural | NCEI data repository |
| 2 | pausch_et_al_2018 | 1 | Detmer | 968 | 57.4% | Florida | Restoration | InPort data repository |
| 3 | USGS_USVI_exp | 1 | Detmer | 46 | 65.2% | USVI | Restoration | USGS data repository |
| 4 | kuffner_et_al_2020 | 1 | Detmer | 53 | 81.1% | Florida | Restoration | USGS data release |
| 5 | fundemar_fragments | 1 | Detmer | 44 | 86.4% | Dom. Rep. | Restoration | FUNDEMAR shared data |
| 6 | vardi_2011_jamaica | 2 | Detmer | 88 | 76.1% | Jamaica | Natural | Dissertation Fig. 4-2 |
| 7 | vardi_2011_puerto_rico | 2 | Detmer | 130 | 92.3% | Puerto Rico | Natural | Dissertation Fig. 4-2 |
| 8 | vardi_2011_virgin_gorda | 2 | Detmer | 27 | 96.3% | Virgin Gorda | Natural | Dissertation Fig. 4-2 |
| 9 | bruckner_bruckner_2001 | 2 | Detmer | 105 | 90.5% | Puerto Rico | Restoration | Fig. 3 histogram |
| 10 | roth_et_al_2013 | 2 | Detmer | 27 | 81.5% | USVI | Natural | Fig. 5 histograms |
| 11 | ortiz_prosper_2005 | 2 | Detmer | 207 | 78.7% | Puerto Rico | Restoration | Matrix tables + Fig. 3.4 |
| 12 | forrester_et_al_2013 | 2 | Detmer | 257 | 53.3% | BVI | Restoration | Tables 1 and 2 |
| 13 | rosales_et_al_2024 | 2 | Detmer | 58 | 79.3% | FL Keys | Restoration | Table S3 + GitHub |
| 14 | maurer_et_al_2022 | 2 | Detmer | 24 | 95.8% | Bahamas | Restoration | Published tables |
| 15 | williams_miller_2010 | 2 | Detmer | 18 | 77.8% | FL Keys | Restoration | Published tables |
| 16 | garrison_ward_2008 | 2 | Detmer | 45 | 68.9% | USVI | Natural | Fig. 4b + text |
| 17 | rogers_muller_2012 | 2 | AI (Claude) | 69 | 94.2% | USVI | Natural | Paper text: "44/69" |
| 18 | ramos_romero_et_al_2025 | 2 | AI (Claude) | 200 | 70.5% | Cuba | Restoration | Table 2 KM survival |
| 19 | muller_et_al_2008 | 2 | AI (Claude) | 60 | EXCLUDED | USVI | Natural | EXCLUDED during IRR audit |
| 20 | sutherland_et_al_2016 | 2 | AI (Claude) | 92 | EXCLUDED | FL Keys | Natural | EXCLUDED (NOAA overlap + photostation) |
| 21 | rogers_et_al_1982 | 2 | AI (Claude) | 173 | ~48% | USVI | Natural | Table 5 — storm-damaged branches |
| -- | ramos_et_al_2024 | 2 | AI (Claude) | NA | EXCLUDED | Cuba | Natural | REMOVED (RM =/= mortality) |

---

## Methodological Notes

### Annualization
All non-annual survival rates were annualized assuming a constant hazard (exponential survival model): `surv_annual = surv_raw^(1/time_interval_yr)`. This is the standard approach for demographic meta-analyses but assumes mortality risk is constant within the observation period.

### Aggregation to Study-Level Effects
Within-study rows (multiple size classes, sites, treatments, or years) were aggregated to a single study-level effect using `n_initial`-weighted means of annualized survival. The effective sample size was set to `max(n_initial)` across rows to avoid double-counting individuals tracked across multiple census intervals. For Vardi 2011, each geographic region was treated as an independent effect (3 regions = 3 effects) because they are geographically distant populations.

### Integer Rounding
The PLO effect size computation requires integer counts (n_survived, n_died). The pipeline computes `n_survived = round(survival_rate x n_total)`, which introduces discretization error bounded by +/-1/(2n). Worst cases: williams_miller_2010 (n=18, +/-2.8 pp), vardi_2011_virgin_gorda (n=27, +/-1.9 pp). This is within confidence intervals for all studies.

### Size Standardization
All sizes were converted to live planar tissue area (cm2) where possible. Studies reporting only linear dimensions (diameter, length) were converted using estimated width:length ratios calibrated from datasets with both measurements. Studies reporting volume (Rogers & Muller 2012) or lacking size data entirely had size set to NA. See `docs/Data_Methodology_Reference.md` Section 9 for full conversion rules.

### AI Extraction Verification
All four AI-extracted studies underwent independent verification by a separate AI audit agent that re-read each source PDF and compared every extracted number. Three of four studies required corrections (see individual audit status entries above). The Ramos et al. 2024 study was completely removed due to a fundamental conceptual error (interpreting partial tissue loss prevalence as whole-colony mortality). See `docs/Data_Methodology_Reference.md` Section 8 for the full audit log.

---

*Document prepared by: Adrian Stier & Claude (Anthropic), with primary extraction by Raine Detmer*
*Ocean Recoveries Lab, UC Santa Barbara*
*Date: March 2026*
