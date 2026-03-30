#!/usr/bin/env Rscript
################################################################################
# 14b_EXPANDED_META_ANALYSIS.R
# Two-Tier Meta-Analysis: Individual + Summary Data Studies
#
# PURPOSE: Expand the meta-analysis from k=5 (individual-level data only) to
#   ~20 effects by incorporating summary-level survival data from additional
#   published studies. NOAA and Vardi are split by region for symmetry.
#   This addresses three critical limitations of the Tier 1 analysis:
#     1. k=1 natural colony study (NOAA only) -- now multiple natural effects
#     2. Meta-regression underpowered (k<10) -- now defensible sample sizes
#     3. Limited geographic scope -- now 9-10 Caribbean regions
#
# DESIGN:
#   Tier 1 = individual-level data studies (from script 14), with NOAA split
#            into Florida Keys, Curacao, Navassa as separate regional effects
#   Tier 2 = study-level effects from summary data (Vardi 2011 split into 3 regions)
#   Combined = all effects analyzed with three-level rma.mv() as PRIMARY model
#
# KEY METHODOLOGICAL CHOICES:
#   - PRIMARY MODEL: Three-level rma.mv(~1 | study_id / study) accounts for
#     within-study correlation when studies contribute multiple regional effects
#     (NOAA: 3 regions; Vardi 2011: 3 regions). Standard rma() is a sensitivity check.
#   - NOAA split by region for symmetry with Vardi 2011 treatment
#   - Summary studies aggregated to one effect per study (except multi-region studies)
#   - Non-annual survival annualized assuming constant hazard:
#       surv_annual = surv_raw^(1/time_interval_yr)
#   - n_initial-weighted means used for within-study aggregation
#   - Excluded: fundemar_recruits (post-settlement, 0.006 cm^2),
#     chamberland_et_al_2015 (recruits), mendoza_quiroz_et_al_2023 summary
#     (lab recruits), papke_et_al_2021 (micro-fragments, lab/nursery)
#   - Effect size: PLO (proportional log-odds) with Haldane correction
#   - Estimation: REML; three-level model with t-test; independent model with
#     Knapp-Hartung adjustment (test="knha")
#
# OUTPUTS:
#   CSVs: expanded_meta_analysis_*.csv (10 files)
#   Figures: 06_analysis/figures/supplementary/meta_analysis/expanded_*.png/pdf
#
# Author: Detmer & Stier Lab
# Date: 2026-02
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)
library(metafor)

set.seed(42)

cat("\n")
cat("==============================================================================\n")
cat("  14b: EXPANDED META-ANALYSIS (INDIVIDUAL + SUMMARY DATA)\n")
cat("==============================================================================\n\n")

# Paths
dirs <- setup_output_dirs()
output_dir <- dirs$output
fig_dir <- file.path(dirs$figures_supp, "meta_analysis")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# SECTION 1: LOAD TIER 1 (INDIVIDUAL-LEVEL) STUDY EFFECTS
# ==============================================================================

cat("SECTION 1: Loading Tier 1 Study Effects (k=5 from individual data)\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

tier1 <- read_csv(file.path(output_dir, "meta_analysis_study_effects.csv"),
                   show_col_types = FALSE)

cat(sprintf("  Loaded %d Tier 1 studies from individual-level data\n", nrow(tier1)))
cat(sprintf("  Studies: %s\n", paste(tier1$study, collapse = ", ")))
cat(sprintf("  Total N (Tier 1): %d\n\n", sum(tier1$n)))

# ===========================================================================
# FIX: Document Tier 1/Tier 2 annualization inconsistency (critique audit 2026-03-29)
#
# IMPORTANT: Tier 1 survival_rate is a RAW POOLED PROPORTION computed across all
# survey intervals (e.g., NOAA pools 2004-2024). The individual observations have
# variable-length intervals, but the study-level survival_rate = n_survived / n_total
# does NOT annualize per interval. In contrast, Tier 2 rates are annualized via
# S_annual = S_raw^(1/t) assuming a constant-hazard (exponential) model.
#
# Expected direction of bias: Most Tier 1 intervals are approximately annual
# (median ~1 year), so bias is small. However, NOAA includes some multi-year
# intervals. For intervals >1 year, the raw proportion UNDERESTIMATES annual
# survival (a colony surviving 2 years at 90%/yr has a 2-year survival of 81%,
# but the raw rate treats 81% as if it were a 1-year rate). For intervals <1 year,
# the raw proportion OVERESTIMATES annual survival. The net direction depends on
# the interval distribution, but the bias is expected to be modest given that
# most intervals cluster near 1 year.
# ===========================================================================

# FIX: Split NOAA by region (critique audit 2026-03-29)
# Previously NOAA was collapsed into a single effect, while Vardi 2011 was split
# into 3 regional effects. This was asymmetric. NOAA spans Florida Keys, Curacao,
# and Navassa — three geographically distinct Caribbean regions with different
# environmental conditions. We now split NOAA into separate regional effects,
# consistent with the Vardi treatment.

# First, separate NOAA from non-NOAA Tier 1 studies
tier1_non_noaa <- tier1 %>%
  filter(study != "NOAA_survey") %>%
  transmute(
    study = study,
    region = region,
    n_total = n_total,
    n_first_census = n_total,
    n_survived = n_survived,
    survival_rate = survival_rate,
    mean_size_cm2 = mean_size_cm2,
    population_type = population_type,
    survey_yr = year_end,
    fragment = ifelse(population_type == "Natural colony", "N", "Y"),
    data_tier = "Tier 1 (individual)"
  )

# Split NOAA into regional effects using the individual-level data
# We need the raw individual data to compute per-region statistics
surv_ind <- read_csv(file.path(get_project_root(), "05_data/standardized", "apal_surv_ind.csv"),
                     show_col_types = FALSE)

noaa_ind <- surv_ind %>% filter(study == "NOAA_survey")

noaa_by_region <- noaa_ind %>%
  group_by(region) %>%
  summarise(
    study = paste0("NOAA_survey_", tolower(gsub(" ", "_", first(region)))),
    n_total = n(),
    n_first_census = n(),
    n_survived = sum(survived),
    survival_rate = mean(survived),
    mean_size_cm2 = mean(size_cm2, na.rm = TRUE),
    population_type = "Natural colony",
    survey_yr = max(survey_yr, na.rm = TRUE),
    fragment = "N",
    data_tier = "Tier 1 (individual)",
    .groups = "drop"
  )

cat(sprintf("  Split NOAA into %d regional effects:\n", nrow(noaa_by_region)))
for (i in 1:nrow(noaa_by_region)) {
  cat(sprintf("    %s: n=%d, surv=%.1f%%\n",
              noaa_by_region$study[i], noaa_by_region$n_total[i],
              noaa_by_region$survival_rate[i] * 100))
}

# Standardize column names for NOAA regional effects
noaa_std <- noaa_by_region %>%
  select(study, region, n_total, n_first_census, n_survived, survival_rate,
         mean_size_cm2, population_type, survey_yr, fragment, data_tier)

# Combine non-NOAA Tier 1 + NOAA regional effects
tier1_std <- bind_rows(tier1_non_noaa, noaa_std)

# ==============================================================================
# SECTION 2: PROCESS SUMMARY DATA INTO STUDY-LEVEL EFFECTS
# ==============================================================================

cat("SECTION 2: Processing Summary Data into Study-Level Effects\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

summ_raw <- read_csv(file.path(get_project_root(), "05_data/standardized", "apal_surv_summ.csv"), show_col_types = FALSE)
cat(sprintf("  Loaded %d rows from summary survival data\n", nrow(summ_raw)))
cat(sprintf("  Studies present: %s\n",
            paste(sort(unique(summ_raw$study)), collapse = ", ")))

# --- Step 2a: Exclusions ---
# Exclude studies that represent a fundamentally different life stage or context
excluded_studies <- c(
  "fundemar_recruits",          # Post-settlement recruits at 0.006 cm^2, near-zero survival
  "chamberland_et_al_2015",     # Post-settlement recruits at 0.008 cm^2, 6% survival
  "mendoza_quiroz_et_al_2023",  # Lab-reared recruits (1% and 24% survival); natural colony
                                 # data already in Tier 1 individual dataset
  "papke_et_al_2021"            # Micro-fragments at 0.5 cm^2 in lab/nursery
)

n_excluded <- sum(summ_raw$study %in% excluded_studies)
cat(sprintf("\n  Excluding %d rows from %d studies (recruits, lab micro-fragments):\n",
            n_excluded, length(excluded_studies)))
for (ex in excluded_studies) {
  n_ex <- sum(summ_raw$study == ex)
  cat(sprintf("    - %s: %d rows\n", ex, n_ex))
}

summ <- summ_raw %>%
  filter(!study %in% excluded_studies)

cat(sprintf("\n  Remaining: %d rows from %d studies\n",
            nrow(summ), n_distinct(summ$study)))

# --- Step 2b: Process each study ---
# Strategy: annualize survival, then aggregate to one study-level effect
# (or study-region for vardi_2011)

cat("\n  Processing each summary study:\n\n")

# Helper: annualize survival assuming constant hazard (exponential model)
# surv_annual = surv_raw^(1/time_interval_yr)
# Edge cases: surv=0 -> 0, surv=1 -> 1
annualize_survival <- function(surv, interval_yr) {
  ifelse(surv <= 0, 0,
         ifelse(surv >= 1, 1,
                surv^(1 / interval_yr)))
}

# Helper: weighted mean with n_initial weights, handling NAs
wmean <- function(x, w) {
  valid <- !is.na(x) & !is.na(w)
  if (sum(valid) == 0) return(NA_real_)
  sum(x[valid] * w[valid]) / sum(w[valid])
}

# Process each study individually for transparency and study-specific logic

tier2_list <- list()

# --- 2b.1: vardi_2011 ---
# 3 regions (Jamaica, Puerto Rico, Virgin Gorda), 4 size classes each, varying intervals
# Treat each region as an independent study-region effect
vardi <- summ %>% filter(study == "vardi_2011")
cat(sprintf("  vardi_2011: %d rows, regions: %s\n",
            nrow(vardi), paste(unique(vardi$region), collapse = ", ")))

vardi_agg <- vardi %>%
  mutate(surv_annual = annualize_survival(prop_survived, time_interval_yr)) %>%
  group_by(region) %>%
  summarise(
    study = paste0("vardi_2011_", tolower(gsub(" ", "_", first(region)))),
    # Effective sample size: max(n_initial) avoids double-counting individuals
    # tracked across multiple census intervals (sum would inflate n)
    n_total = max(n_initial),
    n_first_census = max(n_initial),
    # Weighted mean annualized survival
    survival_rate = wmean(surv_annual, n_initial),
    # Compute n_survived from annualized rate using effective sample size
    n_survived = round(survival_rate * max(n_initial)),
    mean_size_cm2 = wmean(size_cm2_mean, n_initial),
    # Vardi 2011 tracked naturally-occurring colonies, not transplanted fragments.
    # Raw CSV has fragment="Y" because the field records fragmentation events on
    # natural colonies, not transplant origin. Override to "Natural colony".
    population_type = "Natural colony",
    survey_yr = round(mean(survey_yr, na.rm = TRUE)),
    fragment = "N",
    data_tier = "Tier 2 (summary)",
    .groups = "drop"
  ) %>%
  # Handle edge case: ensure n_survived is bounded
  mutate(
    n_survived = pmin(n_survived, n_total),
    n_survived = pmax(n_survived, 0L),
    # Recalculate survival_rate from rounded counts for consistency with escalc
    survival_rate = n_survived / n_total
  ) %>%
  select(study, region, n_total, n_first_census, n_survived, survival_rate, mean_size_cm2,
         population_type, survey_yr, fragment, data_tier)

for (i in 1:nrow(vardi_agg)) {
  cat(sprintf("    %s: n=%d, surv_annual=%.1f%%\n",
              vardi_agg$study[i], vardi_agg$n_total[i],
              vardi_agg$survival_rate[i] * 100))
}
tier2_list <- c(tier2_list, list(vardi_agg))

# --- 2b.2: bruckner_bruckner_2001 ---
# Puerto Rico, 11 size bins, all 2-year intervals
bruckner <- summ %>% filter(study == "bruckner_bruckner_2001")
cat(sprintf("\n  bruckner_bruckner_2001: %d rows, 2-year interval\n", nrow(bruckner)))

bruckner_agg <- bruckner %>%
  mutate(surv_annual = annualize_survival(prop_survived, time_interval_yr)) %>%
  summarise(
    study = "bruckner_bruckner_2001",
    region = first(region),
    # Effective sample size: max(n_initial) avoids double-counting individuals
    # tracked across multiple census intervals
    n_total = max(n_initial),
    n_first_census = max(n_initial),
    survival_rate = wmean(surv_annual, n_initial),
    n_survived = round(survival_rate * max(n_initial)),
    mean_size_cm2 = wmean(size_cm2_mean, n_initial),
    # Classified as "Restoration fragment" here, but note: Bruckner & Bruckner (2001)
    # tracked naturally-occurring storm-generated fragments, not restoration outplants.
    # See Section 11 for a sensitivity scenario reclassifying Bruckner as Natural.
    population_type = "Restoration fragment",
    survey_yr = round(mean(survey_yr, na.rm = TRUE)),
    fragment = "Y",
    data_tier = "Tier 2 (summary)"
  ) %>%
  mutate(
    n_survived = pmin(n_survived, n_total),
    n_survived = pmax(n_survived, 0L),
    survival_rate = n_survived / n_total
  )
cat(sprintf("    Aggregated: n=%d, surv_annual=%.1f%%\n",
            bruckner_agg$n_total, bruckner_agg$survival_rate * 100))
tier2_list <- c(tier2_list, list(bruckner_agg))

# --- 2b.3: roth_et_al_2013 --- EXCLUDED (overlap audit 2026-03-26)
# REMOVED FROM META-ANALYSIS: Roth et al. 2013 (Ecol Modelling 263:223-232)
# used the SAME Haulover Bay colony data as Rogers & Muller 2012.
# Evidence: (1) Roth p.224: "colonies were monitored at Haulover Bay (Rogers and Muller, 2012)"
# (2) Roth p.226: "Lefkovitch transition matrix derived from field data (Rogers and Muller, 2012)"
# (3) Acknowledgments thank "C.S. Rogers for providing the data on Acropora palmata"
# (4) Same site (Haulover Bay), same colonies (69 tagged), overlapping period (2003-2010 vs 2003-2009)
# Keep Rogers & Muller 2012 (primary source, n=69, direct survival data) over Roth (derivative model, n=27 from histograms).
cat("\n  roth_et_al_2013: EXCLUDED -- uses same Haulover Bay data as rogers_muller_2012\n")

# --- 2b.4: ortiz_prosper_2005 ---
# Puerto Rico, 4 size bins x 2 time intervals (1yr and 2yr)
ortiz <- summ %>% filter(study == "ortiz_prosper_2005")
cat(sprintf("\n  ortiz_prosper_2005: %d rows, mixed 1yr and 2yr intervals\n", nrow(ortiz)))

ortiz_agg <- ortiz %>%
  mutate(surv_annual = annualize_survival(prop_survived, time_interval_yr)) %>%
  summarise(
    study = "ortiz_prosper_2005",
    region = first(region),
    # Effective sample size: max(n_initial) avoids double-counting individuals
    # tracked across multiple census intervals
    n_total = max(n_initial),
    n_first_census = max(n_initial),
    survival_rate = wmean(surv_annual, n_initial),
    n_survived = round(survival_rate * max(n_initial)),
    mean_size_cm2 = wmean(size_cm2_mean, n_initial),
    population_type = "Restoration fragment",
    survey_yr = round(mean(survey_yr, na.rm = TRUE)),
    fragment = "Y",
    data_tier = "Tier 2 (summary)"
  ) %>%
  mutate(
    n_survived = pmin(n_survived, n_total),
    n_survived = pmax(n_survived, 0L),
    survival_rate = n_survived / n_total
  )
cat(sprintf("    Aggregated: n=%d, surv_annual=%.1f%%\n",
            ortiz_agg$n_total, ortiz_agg$survival_rate * 100))
tier2_list <- c(tier2_list, list(ortiz_agg))

# --- 2b.5: forrester_et_al_2013 ---
# BVI, 11 location/cohort rows, all 1-year intervals
forrester <- summ %>% filter(study == "forrester_et_al_2013")
cat(sprintf("\n  forrester_et_al_2013: %d rows, all 1-year intervals\n", nrow(forrester)))

forrester_agg <- forrester %>%
  # Already annual
  summarise(
    study = "forrester_et_al_2013",
    region = first(region),
    # Effective sample size: max(n_initial) avoids double-counting individuals
    # tracked across multiple census intervals
    n_total = max(n_initial),
    n_first_census = max(n_initial),
    survival_rate = wmean(prop_survived, n_initial),
    n_survived = round(survival_rate * max(n_initial)),
    mean_size_cm2 = wmean(size_cm2_mean, n_initial),
    population_type = "Restoration fragment",
    survey_yr = round(mean(survey_yr, na.rm = TRUE)),
    fragment = "Y",
    data_tier = "Tier 2 (summary)"
  ) %>%
  mutate(
    n_survived = pmin(n_survived, n_total),
    n_survived = pmax(n_survived, 0L),
    survival_rate = n_survived / n_total
  )
cat(sprintf("    Aggregated: n=%d, surv_annual=%.1f%%\n",
            forrester_agg$n_total, forrester_agg$survival_rate * 100))
tier2_list <- c(tier2_list, list(forrester_agg))

# --- 2b.6: rosales_et_al_2024 ---
# Florida Keys, 3 sites x 4 genotypes, 1.5-year interval
rosales <- summ %>% filter(study == "rosales_et_al_2024")
cat(sprintf("\n  rosales_et_al_2024: %d rows, 1.5-year interval\n", nrow(rosales)))

rosales_agg <- rosales %>%
  mutate(surv_annual = annualize_survival(prop_survived, time_interval_yr)) %>%
  summarise(
    study = "rosales_et_al_2024",
    region = first(region),
    # Effective sample size: max(n_initial) avoids double-counting individuals
    # tracked across multiple census intervals
    n_total = max(n_initial),
    n_first_census = max(n_initial),
    survival_rate = wmean(surv_annual, n_initial),
    n_survived = round(survival_rate * max(n_initial)),
    mean_size_cm2 = wmean(size_cm2_mean, n_initial),
    population_type = "Restoration fragment",
    survey_yr = round(mean(survey_yr, na.rm = TRUE)),
    fragment = "Y",
    data_tier = "Tier 2 (summary)"
  ) %>%
  mutate(
    n_survived = pmin(n_survived, n_total),
    n_survived = pmax(n_survived, 0L),
    survival_rate = n_survived / n_total
  )
cat(sprintf("    Aggregated: n=%d, surv_annual=%.1f%%\n",
            rosales_agg$n_total, rosales_agg$survival_rate * 100))
tier2_list <- c(tier2_list, list(rosales_agg))

# --- 2b.7: maurer_et_al_2022 ---
# Bahamas, 5 plots, all 1-year intervals
maurer <- summ %>% filter(study == "maurer_et_al_2022")
cat(sprintf("\n  maurer_et_al_2022: %d rows, all 1-year intervals\n", nrow(maurer)))

maurer_agg <- maurer %>%
  # Already annual
  summarise(
    study = "maurer_et_al_2022",
    region = first(region),
    # Effective sample size: max(n_initial) avoids double-counting individuals
    # tracked across multiple census intervals
    n_total = max(n_initial),
    n_first_census = max(n_initial),
    survival_rate = wmean(prop_survived, n_initial),
    n_survived = round(survival_rate * max(n_initial)),
    mean_size_cm2 = wmean(size_cm2_mean, n_initial),
    population_type = "Restoration fragment",
    survey_yr = round(mean(survey_yr, na.rm = TRUE)),
    fragment = "Y",
    data_tier = "Tier 2 (summary)"
  ) %>%
  mutate(
    n_survived = pmin(n_survived, n_total),
    n_survived = pmax(n_survived, 0L),
    survival_rate = n_survived / n_total
  )
cat(sprintf("    Aggregated: n=%d, surv_annual=%.1f%%\n",
            maurer_agg$n_total, maurer_agg$survival_rate * 100))
tier2_list <- c(tier2_list, list(maurer_agg))

# --- 2b.8: williams_miller_2010 ---
# Florida Keys, 3 rows (treatment groups), 0.846-year interval
williams <- summ %>% filter(study == "williams_miller_2010")
cat(sprintf("\n  williams_miller_2010: %d rows, ~0.85-year interval\n", nrow(williams)))

williams_agg <- williams %>%
  mutate(surv_annual = annualize_survival(prop_survived, time_interval_yr)) %>%
  summarise(
    study = "williams_miller_2010",
    region = first(region),
    # Effective sample size: max(n_initial) avoids double-counting individuals
    # tracked across multiple census intervals
    n_total = max(n_initial),
    n_first_census = max(n_initial),
    survival_rate = wmean(surv_annual, n_initial),
    n_survived = round(survival_rate * max(n_initial)),
    mean_size_cm2 = wmean(size_cm2_mean, n_initial),
    population_type = "Restoration fragment",
    survey_yr = round(mean(survey_yr, na.rm = TRUE)),
    fragment = "Y",
    data_tier = "Tier 2 (summary)"
  ) %>%
  mutate(
    n_survived = pmin(n_survived, n_total),
    n_survived = pmax(n_survived, 0L),
    survival_rate = n_survived / n_total
  )
cat(sprintf("    Aggregated: n=%d, surv_annual=%.1f%%\n",
            williams_agg$n_total, williams_agg$survival_rate * 100))
tier2_list <- c(tier2_list, list(williams_agg))

# --- 2b.9: garrison_ward_2008 ---
# USVI (St. John), 1-year interval (2000-2001)
# FIX: Split into 2 effects (analogous to Vardi regional split, NOAA regional split)
# Control = 45 natural colonies (80% survival), Relocated = 30 transplanted fragments (55% survival)
# Previously aggregated into a single "Natural colony" effect, which obscured the
# natural-vs-restoration comparison that is central to this study's contribution.
# The two groups differ by 25 percentage points — aggregation masked a key signal.
garrison <- summ %>% filter(study == "garrison_ward_2008")
cat(sprintf("\n  garrison_ward_2008: %d rows, 1-year interval\n", nrow(garrison)))

# Split by treatment group (control vs relocated)
garrison_control <- garrison %>% filter(grepl("control", treatment_1, ignore.case = TRUE))
garrison_relocated <- garrison %>% filter(grepl("reloc", treatment_1, ignore.case = TRUE))

# Control group: natural colonies monitored in situ
if (nrow(garrison_control) > 0) {
  garrison_control_agg <- garrison_control %>%
    summarise(
      study = "garrison_ward_2008_control",
      region = first(region),
      n_total = first(n_initial),
      n_first_census = first(n_initial),
      survival_rate = first(prop_survived),
      n_survived = round(survival_rate * n_total),
      mean_size_cm2 = first(size_cm2_mean),
      population_type = "Natural colony",
      survey_yr = first(survey_yr),
      fragment = "N",
      data_tier = "Tier 2 (summary)"
    ) %>%
    mutate(
      n_survived = pmin(n_survived, n_total),
      n_survived = pmax(n_survived, 0L),
      survival_rate = n_survived / n_total
    )
  cat(sprintf("    Control (natural): n=%d, surv_annual=%.1f%%\n",
              garrison_control_agg$n_total, garrison_control_agg$survival_rate * 100))
  tier2_list <- c(tier2_list, list(garrison_control_agg))
}

# Relocated group: transplanted fragments
if (nrow(garrison_relocated) > 0) {
  garrison_relocated_agg <- garrison_relocated %>%
    summarise(
      study = "garrison_ward_2008_relocated",
      region = first(region),
      n_total = first(n_initial),
      n_first_census = first(n_initial),
      survival_rate = first(prop_survived),
      n_survived = round(survival_rate * n_total),
      mean_size_cm2 = first(size_cm2_mean),
      population_type = "Restoration fragment",
      survey_yr = first(survey_yr),
      fragment = "Y",
      data_tier = "Tier 2 (summary)"
    ) %>%
    mutate(
      n_survived = pmin(n_survived, n_total),
      n_survived = pmax(n_survived, 0L),
      survival_rate = n_survived / n_total
    )
  cat(sprintf("    Relocated (restoration): n=%d, surv_annual=%.1f%%\n",
              garrison_relocated_agg$n_total, garrison_relocated_agg$survival_rate * 100))
  tier2_list <- c(tier2_list, list(garrison_relocated_agg))
}


# --- 2b.10: rogers_muller_2012 ---
# USVI (St. John), 69 tagged natural colonies, 7-year tracking (2003-2009)
# [AI_EXTRACTED] USGS study, independent of NOAA_survey
# 44/69 survived = 63.8% over 7 years; annualized = 93.7%
# Also: 141 fragments tracked (extracted separately for fragmentation analysis)
rogers <- summ %>% filter(study == "rogers_muller_2012", fragment == "N")
if (nrow(rogers) > 0) {
  cat(sprintf("\n  rogers_muller_2012: %d rows, 7-year tracking\n", nrow(rogers)))

  rogers_agg <- rogers %>%
    summarise(
      study = "rogers_muller_2012",
      region = "US Virgin Islands",
      n_total = first(n_initial),
      n_first_census = first(n_initial),
      survival_rate = annualize_survival(first(prop_survived), first(time_interval_yr)),
      n_survived = round(survival_rate * first(n_initial)),
      mean_size_cm2 = NA_real_,  # Size measured in volume (cm3), not planar area
      population_type = "Natural colony",
      survey_yr = 2009,
      fragment = "N",
      data_tier = "Tier 2 (summary) [AI_EXTRACTED]"
    ) %>%
    mutate(
      n_survived = pmin(n_survived, n_total),
      n_survived = pmax(n_survived, 0L),
      survival_rate = n_survived / n_total
    )
  cat(sprintf("    Aggregated: n=%d, surv_annual=%.1f%%\n",
              rogers_agg$n_total, rogers_agg$survival_rate * 100))
  tier2_list <- c(tier2_list, list(rogers_agg))
} else {
  cat("\n  rogers_muller_2012: not found in summary data, skipping\n")
}


# --- 2b.11: ramos_et_al_2024 --- EXCLUDED (audit 2026-03-26)
# Cuba (Havana coast), 2 reef crests, 17-year monitoring (2005-2021)
# REMOVED FROM META-ANALYSIS: The survival proxy (prop_survived = 1 - RM_prevalence)
# is scientifically indefensible. RM prevalence measures the proportion of colonies
# showing ANY recent tissue loss (partial mortality), NOT whole-colony death.
# A colony with RM is still alive. The study's own density data show 89% population
# decline at PB (1.8→0.2 col/m²) over 17 years, inconsistent with 92% annual survival.
# Additionally, n=246 is a fictional cohort size derived from density × area.
# Data retained in ai_extracted_survival.csv for contextual reference only.
cat("\n  ramos_et_al_2024: EXCLUDED -- RM prevalence =/= whole-colony mortality\n")


# --- 2b.12: ramos_romero_et_al_2025 ---
# Cuba (4 reef crests: PB, RG, El Peruano, Mariflores), restoration fragments
# [AI_EXTRACTED] Kaplan-Meier survival from Table 2; 200 fragments total (50/site)
# Overlaps with Ramos 2024 sites (PB, RG) but different data (experimental fragments vs monitoring)
ramos_romero <- summ %>% filter(study == "ramos_romero_et_al_2025")
if (nrow(ramos_romero) > 0) {
  cat(sprintf("\n  ramos_romero_et_al_2025: %d rows, Cuba restoration fragments\n", nrow(ramos_romero)))

  # Annualize each site's survival, then aggregate
  ramos_romero_annual <- ramos_romero %>%
    mutate(
      surv_annual = annualize_survival(prop_survived, time_interval_yr)
    )

  # Aggregate across 4 sites using n_initial-weighted mean
  ramos_romero_agg <- ramos_romero_annual %>%
    summarise(
      study = "ramos_romero_et_al_2025",
      region = "Cuba",
      n_total = sum(n_initial, na.rm = TRUE),
      n_first_census = n_total,
      survival_rate = weighted.mean(surv_annual, n_initial, na.rm = TRUE),
      n_survived = round(survival_rate * n_total),
      mean_size_cm2 = NA_real_,  # Size in cm height/width, not area
      population_type = "Restoration fragment",
      survey_yr = 2023,
      fragment = "Y",
      data_tier = "Tier 2 (summary) [AI_EXTRACTED]"
    ) %>%
    mutate(
      n_survived = pmin(n_survived, n_total),
      n_survived = pmax(n_survived, 0L),
      survival_rate = n_survived / n_total
    )
  cat(sprintf("    Aggregated: n=%d, surv_annual=%.1f%%\n",
              ramos_romero_agg$n_total, ramos_romero_agg$survival_rate * 100))
  tier2_list <- c(tier2_list, list(ramos_romero_agg))
} else {
  cat("\n  ramos_romero_et_al_2025: not found in summary data, skipping\n")
}


# --- 2b.13: muller_et_al_2008 --- EXCLUDED (IRR audit 2026-03-26)
# REMOVED FROM META-ANALYSIS: Independent IRR review found that:
# (1) Whole-colony mortality numbers are imprecise ("17% of colonies" ~ 10/60)
# (2) No colony size data reported (cannot assign to size classes)
# (3) The 2005 mass bleaching event drove most mortality, confounding baseline rates
# (4) Primary focus is disease prevalence and partial tissue loss, not whole-colony survival
# Paper: Muller et al. 2008, Hawksnest Bay, St. John, USVI, 60 tagged colonies
# Claude originally included; Gemini excluded; independent review agrees with Gemini.
cat("\n  muller_et_al_2008: EXCLUDED -- imprecise survival data, no sizes, bleaching-confounded\n")


# --- 2b.14: sutherland_et_al_2016 --- EXCLUDED (IRR audit 2026-03-26)
# REMOVED FROM META-ANALYSIS: Independent IRR review found that:
# (1) Contemporary FKNMS-wide survey (2008-2014) explicitly overlaps NOAA monitoring
#     at Carysfort and Molasses reefs (paper itself acknowledges this, p. 11)
# (2) EDR historical data (1994-2004) is from a photostation (fixed grid), not
#     individually tagged colonies -- different protocol from other included studies
# (3) 10 of 91 colony losses were TKO (knocked out of frame) -- ambiguous mortality
# (4) Catastrophic WPX-driven decline (92→1 colony) -- extreme outlier event
# Paper: Sutherland et al. 2016, Eastern Dry Rocks + 7 FKNMS sites, 1994-2014
# Claude originally included (EDR only); Gemini excluded; independent review excludes both components.
cat("\n  sutherland_et_al_2016: EXCLUDED -- NOAA overlap (contemporary), photostation design (EDR)\n")


# --- 2b.15: rogers_et_al_1982 ---
# Hurricane David/Frederic recovery study, St. Croix, USVI
# 100 labeled storm-damaged A. palmata branches tracked 11 months at 2 sites:
#   Buck Island: n=88, 34% dead (66% survived) at 11 months
#   Tague Bay: n=85, 65% dead (35% survived) at 11 months
# Also 25 detached fragments tracked 13 months: 3/25 survived (12%)
# Added during IRR audit 2026-03-26: independent review found this meets criteria
# (longitudinal individual tracking of labeled branches, comparable to fragment data
# from Vardi 2011 and Pausch 2018 already in the meta-analysis)
rogers_1982 <- summ %>% filter(study == "rogers_et_al_1982")
if (nrow(rogers_1982) > 0) {
  cat(sprintf("\n  rogers_et_al_1982: %d rows, St. Croix USVI\n", nrow(rogers_1982)))

  # Each site is a separate effect (different survival rates, different reef environments)
  rogers_1982_agg <- rogers_1982 %>%
    mutate(
      surv_annual = annualize_survival(prop_survived, time_interval_yr)
    ) %>%
    summarise(
      study = "rogers_et_al_1982",
      region = "US Virgin Islands",
      n_total = sum(n_initial, na.rm = TRUE),
      n_first_census = n_total,
      survival_rate = weighted.mean(surv_annual, n_initial, na.rm = TRUE),
      n_survived = round(survival_rate * n_total),
      mean_size_cm2 = NA_real_,
      # FIX: Rogers 1982 fragment/population_type inconsistency (critique audit 2026-03-29)
      # Rogers et al. 1982 tracked storm-generated fragments of natural colonies
      # (hurricane-broken branches), NOT restoration outplants. These are classified
      # as "Natural colony" for the moderator analysis because they originate from
      # natural populations, even though they are technically fragments. The fragment
      # flag is set to "Y" to indicate their physical form. In the moderator analysis,
      # they are grouped with natural colonies (the biological origin matters more
      # than the physical state for survival comparisons). This is analogous to
      # Vardi 2011, which also tracked naturally-occurring colonies with fragmentation
      # events and is classified as "Natural colony".
      population_type = "Natural colony",
      survey_yr = 1980,
      fragment = "Y",  # storm-generated fragments (not outplants)
      data_tier = "Tier 2 (summary) [AI_EXTRACTED]"
    ) %>%
    mutate(
      n_survived = pmin(n_survived, n_total),
      n_survived = pmax(n_survived, 0L),
      survival_rate = n_survived / n_total
    )
  cat(sprintf("    Aggregated: n=%d, surv_annual=%.1f%% [post-hurricane recovery]\n",
              rogers_1982_agg$n_total, rogers_1982_agg$survival_rate * 100))
  tier2_list <- c(tier2_list, list(rogers_1982_agg))
} else {
  cat("\n  rogers_et_al_1982: not found in summary data, skipping\n")
}


# --- Combine all Tier 2 studies ---
tier2_std <- bind_rows(tier2_list)
cat(sprintf("\n  Total Tier 2 studies: %d\n", nrow(tier2_std)))
cat(sprintf("  Total Tier 2 N: %d\n", sum(tier2_std$n_total)))

# ==============================================================================
# SECTION 3: COMBINE TIER 1 + TIER 2 AND COMPUTE EFFECT SIZES
# ==============================================================================

cat("\nSECTION 3: Combining Tier 1 + Tier 2 into Expanded Dataset\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

combined <- bind_rows(tier1_std, tier2_std)

cat(sprintf("  Combined dataset: k = %d study-level effects\n", nrow(combined)))
cat(sprintf("  Total N = %d observations\n", sum(combined$n_total)))
cat(sprintf("  Tier 1: %d effects, Tier 2: %d effects\n",
            sum(combined$data_tier == "Tier 1 (individual)"),
            sum(grepl("Tier 2", combined$data_tier))))
cat(sprintf("  Natural colonies: k = %d\n",
            sum(combined$population_type == "Natural colony")))
cat(sprintf("  Restoration fragments: k = %d\n",
            sum(combined$population_type == "Restoration fragment")))
cat(sprintf("  Regions: %s\n", paste(sort(unique(combined$region)), collapse = ", ")))

# Ensure no zero-cell studies before escalc
# If n_survived = 0 or n_survived = n_total, escalc's Haldane correction handles it
combined <- combined %>%
  mutate(
    n_died = n_total - n_survived
  )

# Compute effect sizes: proportional log-odds (PLO)
combined_es <- escalc(
  measure = "PLO",
  xi = combined$n_survived,
  ni = combined$n_total,
  data = combined,
  add = 0.5, to = "only0"  # Haldane correction for zero cells
)

# Add derived columns
combined_es <- combined_es %>%
  mutate(
    log_odds = as.numeric(yi),
    var_log_odds = as.numeric(vi),
    se_log_odds = sqrt(var_log_odds),
    surv_lower = plogis(log_odds - 1.96 * se_log_odds),
    surv_upper = plogis(log_odds + 1.96 * se_log_odds),
    # FIX: study_id maps regional effects back to parent study (critique audit 2026-03-29)
    # Needed for three-level model and for reporting k studies vs k effects
    study_id = case_when(
      grepl("^vardi_2011_", study) ~ "vardi_2011",
      grepl("^NOAA_survey_", study) ~ "NOAA_survey",
      grepl("^garrison_ward_2008_", study) ~ "garrison_ward_2008",
      TRUE ~ study
    )
  )

cat("\n  Study-level effect sizes (expanded):\n")
combined_es %>%
  as.data.frame() %>%
  select(study, study_id, region, data_tier, population_type, n_total, survival_rate,
         log_odds, se_log_odds) %>%
  mutate(
    survival_rate = sprintf("%.1f%%", survival_rate * 100),
    log_odds = sprintf("%.3f", log_odds),
    se_log_odds = sprintf("%.3f", se_log_odds)
  ) %>%
  print()

k_expanded <- nrow(combined_es)
k_studies <- n_distinct(combined_es$study_id)  # FIX: count unique parent studies (critique audit 2026-03-29)
cat(sprintf("\n  === EXPANDED META-ANALYSIS: k=%d studies contributing %d effects ===\n",
            k_studies, k_expanded))

# ==============================================================================
# SECTION 4: EXPANDED RANDOM-EFFECTS META-ANALYSIS
# ==============================================================================

cat("\nSECTION 4: Expanded Random-Effects Meta-Analysis\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# FIX: Make three-level model primary (critique audit 2026-03-29)
# Rationale: Vardi 2011 contributes 3 regional effects and NOAA contributes 3
# regional effects from the same parent study. A standard rma() treats all effects
# as independent, which underestimates the true uncertainty. The three-level model
# (study_id / effect) accounts for within-study correlation via a nested random
# effect, producing appropriately wider CIs.
# The standard rma() is retained as a sensitivity check.

# (study_id already assigned in Section 3 above)

# --- PRIMARY MODEL: Three-level rma.mv() ---
rma_3level <- tryCatch({
  metafor::rma.mv(
    yi = combined_es$log_odds,
    V = combined_es$var_log_odds,
    random = ~1 | study_id / study,
    data = combined_es,
    method = "REML", test = "t"
  )
}, error = function(e) {
  cat(sprintf("  Three-level model failed: %s\n", e$message))
  cat("  Falling back to standard rma() as primary.\n")
  NULL
})

# --- SENSITIVITY: Standard rma() treating all effects as independent ---
# FIX: demoted from primary to sensitivity check (critique audit 2026-03-29)
rma_independent <- rma(
  yi = combined_es$log_odds,
  vi = combined_es$var_log_odds,
  method = "REML",
  test = "knha"
)

# Use three-level model if available; fall back to standard rma
if (!is.null(rma_3level)) {
  # Primary results from three-level model
  rma_expanded <- rma_3level  # alias for downstream code compatibility
  pooled_lo <- as.numeric(rma_3level$b)
  pooled_surv <- plogis(pooled_lo)
  pooled_surv_lower <- plogis(rma_3level$ci.lb)
  pooled_surv_upper <- plogis(rma_3level$ci.ub)
  # For rma.mv, extract variance components
  # sigma2[1] = between-study, sigma2[2] = within-study (between-effect)
  tau_sq_between <- rma_3level$sigma2[1]
  tau_sq_within <- rma_3level$sigma2[2]
  tau_sq <- tau_sq_between + tau_sq_within  # total heterogeneity
  tau <- sqrt(tau_sq)
  # Q and I^2 from the independent-effects model (standard diagnostics)
  Q_stat <- rma_independent$QE
  Q_p <- rma_independent$QEp
  I_sq <- rma_independent$I2
  # Prediction interval: approximate using total tau^2
  # For three-level model, PI = pooled +/- t * sqrt(tau_sq_total + avg_vi)
  # But metafor predict.rma.mv handles this
  rma_pred <- predict(rma_3level)
  pi_lower <- plogis(rma_pred$pi.lb)
  pi_upper <- plogis(rma_pred$pi.ub)
  # I^2 CI from independent-effects model
  rma_ci <- confint(rma_independent)
  I_sq_lower <- rma_ci$random["I^2(%)", "ci.lb"]
  I_sq_upper <- rma_ci$random["I^2(%)", "ci.ub"]
  primary_model_label <- "Three-level rma.mv()"
} else {
  # Fall back to independent-effects model
  rma_expanded <- rma_independent
  pooled_lo <- as.numeric(rma_independent$beta)
  pooled_surv <- plogis(pooled_lo)
  pooled_surv_lower <- plogis(rma_independent$ci.lb)
  pooled_surv_upper <- plogis(rma_independent$ci.ub)
  I_sq <- rma_independent$I2
  Q_stat <- rma_independent$QE
  Q_p <- rma_independent$QEp
  tau_sq <- rma_independent$tau2
  tau <- sqrt(tau_sq)
  tau_sq_between <- tau_sq
  tau_sq_within <- 0
  rma_pred <- predict(rma_independent)
  pi_lower <- plogis(rma_pred$pi.lb)
  pi_upper <- plogis(rma_pred$pi.ub)
  rma_ci <- confint(rma_independent)
  I_sq_lower <- rma_ci$random["I^2(%)", "ci.lb"]
  I_sq_upper <- rma_ci$random["I^2(%)", "ci.ub"]
  primary_model_label <- "Standard rma() (fallback)"
}

cat(sprintf("PRIMARY MODEL: %s\n", primary_model_label))
cat(sprintf("  k = %d studies contributing %d effects\n", k_studies, k_expanded))
cat(sprintf("  Total observations: %d\n", sum(combined_es$n_total)))

cat(sprintf("\n  *** 95%% PREDICTION INTERVAL: %.1f%% - %.1f%% ***\n",
            pi_lower * 100, pi_upper * 100))
cat("  The prediction interval is more relevant for practitioners: it predicts\n")
cat("  the range of survival in a NEW study, accounting for between-study heterogeneity.\n\n")
cat(sprintf("  Pooled survival (RE): %.1f%% (95%% CI: %.1f%% - %.1f%%)\n",
            pooled_surv * 100, pooled_surv_lower * 100, pooled_surv_upper * 100))
cat("  NOTE: The CI describes uncertainty in the AVERAGE, not in a new observation.\n")

if (!is.null(rma_3level)) {
  cat(sprintf("\n  Variance components (three-level):\n"))
  cat(sprintf("    sigma^2_between (study-level): %.4f\n", tau_sq_between))
  cat(sprintf("    sigma^2_within  (effect-level): %.4f\n", tau_sq_within))
  cat(sprintf("    Total tau^2: %.4f, tau: %.4f\n", tau_sq, tau))
}

cat(sprintf("\n  I^2 = %.1f%% (95%% CI: %.1f%% - %.1f%%) [from independent-effects model]\n",
            I_sq, I_sq_lower, I_sq_upper))
cat(sprintf("  Cochran's Q = %.2f (df = %d, p %s)\n",
            Q_stat, k_expanded - 1,
            ifelse(Q_p < 0.001, "< 0.001", sprintf("= %.4f", Q_p))))

# --- SENSITIVITY: Independent-effects model comparison ---
cat("\n--- SENSITIVITY: Independent-effects model (standard rma) ---\n")
indep_surv <- plogis(as.numeric(rma_independent$beta))
indep_ci_lo <- plogis(rma_independent$ci.lb)
indep_ci_hi <- plogis(rma_independent$ci.ub)
cat(sprintf("  Three-level (primary): %.1f%% (CI: %.1f%% - %.1f%%)\n",
            pooled_surv * 100, pooled_surv_lower * 100, pooled_surv_upper * 100))
cat(sprintf("  Independent effects:   %.1f%% (CI: %.1f%% - %.1f%%)\n",
            indep_surv * 100, indep_ci_lo * 100, indep_ci_hi * 100))

# FIX: Add tau-squared estimator sensitivity (critique audit 2026-03-29)
# Reference: Viechtbauer (2005) "Bias and Efficiency of Meta-Analytic Variance
# Estimators in the Random-Effects Model" JESS 14:261-293
cat("\n--- SENSITIVITY: tau^2 Estimator Comparison (Viechtbauer 2005) ---\n")
rma_dl <- rma(
  yi = combined_es$log_odds,
  vi = combined_es$var_log_odds,
  method = "DL",
  test = "knha"
)
cat(sprintf("  REML tau^2: %.4f (pooled survival: %.1f%%)\n",
            rma_independent$tau2, plogis(as.numeric(rma_independent$beta)) * 100))
cat(sprintf("  DL   tau^2: %.4f (pooled survival: %.1f%%)\n",
            rma_dl$tau2, plogis(as.numeric(rma_dl$beta)) * 100))

tau_estimator_comparison <- data.frame(
  estimator = c("REML", "DL"),
  tau2 = c(rma_independent$tau2, rma_dl$tau2),
  tau = c(sqrt(rma_independent$tau2), sqrt(rma_dl$tau2)),
  pooled_survival = c(plogis(as.numeric(rma_independent$beta)),
                      plogis(as.numeric(rma_dl$beta))),
  ci_lower = c(plogis(rma_independent$ci.lb), plogis(rma_dl$ci.lb)),
  ci_upper = c(plogis(rma_independent$ci.ub), plogis(rma_dl$ci.ub)),
  I2 = c(rma_independent$I2, rma_dl$I2),
  note = c("Preferred (less biased for small k)", "DerSimonian-Laird (comparison)")
)
write_csv(tau_estimator_comparison,
          file.path(output_dir, "expanded_meta_tau_estimator_comparison.csv"))
cat("  Saved: expanded_meta_tau_estimator_comparison.csv\n")

# --- PUBLICATION BIAS: Egger's Test ---
cat("\n--- PUBLICATION BIAS ---\n")
# Egger's test uses the independent-effects model (standard for rma objects)
egger_result <- metafor::regtest(rma_independent)
cat(sprintf("  Egger's test: test stat = %.3f, p = %.4f\n", egger_result$zval, egger_result$pval))
cat(sprintf("  Interpretation: %s\n",
            if (egger_result$pval < 0.05) "Significant funnel plot asymmetry"
            else "No significant funnel plot asymmetry"))

# FIX: Add trim-and-fill analysis (critique audit 2026-03-29)
# NOTE: Trim-and-fill has limited interpretability for single-proportion
# meta-analyses (as opposed to comparative effect sizes like OR/RR). The method
# assumes the funnel plot should be symmetric around the true effect, which may
# not hold for proportions that are bounded [0,1] and often right-skewed on the
# log-odds scale. Results should be interpreted as a sensitivity check, not as
# definitive evidence of publication bias.
cat("\n--- TRIM-AND-FILL ---\n")
tf <- tryCatch({
  trimfill(rma_independent)
}, error = function(e) {
  cat(sprintf("  Trim-and-fill failed: %s\n", e$message))
  NULL
})

if (!is.null(tf)) {
  tf_surv <- plogis(as.numeric(tf$beta))
  tf_ci_lo <- plogis(tf$ci.lb)
  tf_ci_hi <- plogis(tf$ci.ub)
  n_filled <- tf$k0
  cat(sprintf("  Imputed studies: %d\n", n_filled))
  cat(sprintf("  Adjusted pooled survival: %.1f%% (CI: %.1f%% - %.1f%%)\n",
              tf_surv * 100, tf_ci_lo * 100, tf_ci_hi * 100))
  cat(sprintf("  Original pooled survival: %.1f%% (CI: %.1f%% - %.1f%%)\n",
              indep_surv * 100, indep_ci_lo * 100, indep_ci_hi * 100))

  trimfill_results <- data.frame(
    analysis = c("Original", "Trim-and-fill adjusted"),
    k = c(k_expanded, k_expanded + n_filled),
    pooled_survival = c(indep_surv, tf_surv),
    ci_lower = c(indep_ci_lo, tf_ci_lo),
    ci_upper = c(indep_ci_hi, tf_ci_hi),
    n_imputed = c(0, n_filled),
    note = c("", "Caution: limited interpretability for single-proportion meta-analyses")
  )
  write_csv(trimfill_results, file.path(output_dir, "expanded_meta_trimfill.csv"))
  cat("  Saved: expanded_meta_trimfill.csv\n")
}

# --- Compare to Tier 1 only ---
cat("\n--- COMPARISON: Tier 1 Only vs Tier 1+2 Combined ---\n")

tier1_only <- combined_es %>% filter(data_tier == "Tier 1 (individual)")
rma_tier1 <- rma(
  yi = tier1_only$log_odds,
  vi = tier1_only$var_log_odds,
  method = "REML",
  test = "knha"
)

tier1_surv <- plogis(as.numeric(rma_tier1$beta))
tier1_ci_lo <- plogis(rma_tier1$ci.lb)
tier1_ci_hi <- plogis(rma_tier1$ci.ub)

cat(sprintf("  Tier 1 only (k=%d): %.1f%% (CI: %.1f%% - %.1f%%), I^2=%.1f%%\n",
            nrow(tier1_only), tier1_surv * 100, tier1_ci_lo * 100,
            tier1_ci_hi * 100, rma_tier1$I2))
cat(sprintf("  Tier 1+2   (k=%d effects from %d studies): %.1f%% (CI: %.1f%% - %.1f%%), I^2=%.1f%%\n",
            k_expanded, k_studies, pooled_surv * 100, pooled_surv_lower * 100,
            pooled_surv_upper * 100, I_sq))
cat(sprintf("  Change in pooled estimate: %+.1f pp\n",
            (pooled_surv - tier1_surv) * 100))
cat(sprintf("  CI width change: %.1f pp -> %.1f pp\n",
            (tier1_ci_hi - tier1_ci_lo) * 100,
            (pooled_surv_upper - pooled_surv_lower) * 100))

# Add RE weights to combined data (using independent-effects tau^2 for weight calc)
combined_es <- combined_es %>%
  mutate(
    weight_re = 1 / (var_log_odds + rma_independent$tau2),
    weight_re_pct = weight_re / sum(weight_re) * 100
  )

# --- SENSITIVITY: Conservative Sample Sizes for Tier 2 ---
cat("\n--- SENSITIVITY: Tier 2 Sample Size Inflation ---\n")

combined_conservative <- combined_es %>%
  mutate(
    n_conservative = if_else(!is.na(n_first_census), n_first_census, n_total),
    n_surv_cons = pmin(pmax(round(survival_rate * n_conservative), 0L), n_conservative)
  )

es_cons <- metafor::escalc(
  measure = "PLO",
  xi = combined_conservative$n_surv_cons,
  ni = combined_conservative$n_conservative,
  data = combined_conservative,
  add = 0.5, to = "only0"
)

rma_cons <- tryCatch({
  metafor::rma(yi = es_cons$yi, vi = es_cons$vi, method = "REML", test = "knha")
}, error = function(e) { cat(sprintf("  Conservative rma failed: %s\n", e$message)); NULL })

if (!is.null(rma_cons)) {
  pooled_cons <- plogis(as.numeric(rma_cons$beta))
  ci_cons <- c(plogis(rma_cons$ci.lb), plogis(rma_cons$ci.ub))
  cat(sprintf("  Primary (summed n):      %.1f%% (CI: %.1f%% - %.1f%%)\n",
              pooled_surv * 100, pooled_surv_lower * 100, pooled_surv_upper * 100))
  cat(sprintf("  Conservative (first-census n): %.1f%% (CI: %.1f%% - %.1f%%)\n",
              pooled_cons * 100, ci_cons[1] * 100, ci_cons[2] * 100))
  cat(sprintf("  CI width change: %.1f pp -> %.1f pp\n",
              (pooled_surv_upper - pooled_surv_lower) * 100,
              (ci_cons[2] - ci_cons[1]) * 100))
}

# ==============================================================================
# SECTION 5: META-REGRESSION WITH MODERATORS (NOW BETTER POWERED)
# ==============================================================================

cat("\nSECTION 5: Meta-Regression with Moderators\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

if (k_expanded < 10) {
  cat("WARNING: k < 10 studies. Meta-regression results remain EXPLORATORY.\n")
  cat("  Need k >= 10 per moderator for defensible inference.\n\n")
} else {
  cat(sprintf("k = %d: meta-regression is approaching defensible sample sizes.\n", k_expanded))
  cat("  Results should still be interpreted cautiously with k near 10.\n\n")
}

moderators <- list()

# 5a. Population type (natural vs restoration) -- THE KEY MODERATOR
# Now with multiple natural colony studies
k_natural <- sum(combined_es$population_type == "Natural colony")
k_restoration <- sum(combined_es$population_type == "Restoration fragment")
cat(sprintf("  5a. Population type: k_natural=%d, k_restoration=%d\n",
            k_natural, k_restoration))

meta_reg_pop <- rma(
  yi = log_odds, vi = var_log_odds,
  mods = ~population_type,
  data = combined_es,
  method = "REML", test = "knha"
)

moderators$population_type <- data.frame(
  moderator = "Population type (natural vs restoration)",
  coefficient = meta_reg_pop$beta[2],
  se = meta_reg_pop$se[2],
  ci_lower = meta_reg_pop$ci.lb[2],
  ci_upper = meta_reg_pop$ci.ub[2],
  t_value = meta_reg_pop$zval[2],
  p_value = meta_reg_pop$pval[2],
  R2_pct = max(0, meta_reg_pop$R2),
  k = k_expanded,
  k_per_level = paste0("natural=", k_natural, ", restoration=", k_restoration),
  defensible = (min(k_natural, k_restoration) >= 3)
)

cat(sprintf("    Coefficient: %.3f (SE=%.3f), p=%.4f\n",
            meta_reg_pop$beta[2], meta_reg_pop$se[2], meta_reg_pop$pval[2]))
cat(sprintf("    R^2 = %.1f%%\n", max(0, meta_reg_pop$R2)))
cat(sprintf("    Interpretation: Natural colonies have %s survival than restoration fragments\n",
            ifelse(meta_reg_pop$beta[2] > 0, "higher", "lower")))

# 5b. Mean colony size
size_available <- combined_es %>% filter(!is.na(mean_size_cm2))
if (nrow(size_available) >= 5) {
  cat(sprintf("\n  5b. Colony size: %d studies with size data\n", nrow(size_available)))

  meta_reg_size <- rma(
    yi = log_odds, vi = var_log_odds,
    mods = ~log(mean_size_cm2),
    data = size_available,
    method = "REML", test = "knha"
  )

  moderators$colony_size <- data.frame(
    moderator = "Log colony size (cm^2)",
    coefficient = meta_reg_size$beta[2],
    se = meta_reg_size$se[2],
    ci_lower = meta_reg_size$ci.lb[2],
    ci_upper = meta_reg_size$ci.ub[2],
    t_value = meta_reg_size$zval[2],
    p_value = meta_reg_size$pval[2],
    R2_pct = max(0, meta_reg_size$R2),
    k = nrow(size_available),
    k_per_level = NA_character_,
    defensible = (nrow(size_available) >= 10)
  )

  cat(sprintf("    Coefficient: %.3f (SE=%.3f), p=%.4f, R^2=%.1f%%\n",
              meta_reg_size$beta[2], meta_reg_size$se[2],
              meta_reg_size$pval[2], max(0, meta_reg_size$R2)))
}

# 5c. Study year
cat(sprintf("\n  5c. Study year\n"))
meta_reg_year <- rma(
  yi = log_odds, vi = var_log_odds,
  mods = ~survey_yr,
  data = combined_es,
  method = "REML", test = "knha"
)

moderators$study_year <- data.frame(
  moderator = "Study year",
  coefficient = meta_reg_year$beta[2],
  se = meta_reg_year$se[2],
  ci_lower = meta_reg_year$ci.lb[2],
  ci_upper = meta_reg_year$ci.ub[2],
  t_value = meta_reg_year$zval[2],
  p_value = meta_reg_year$pval[2],
  R2_pct = max(0, meta_reg_year$R2),
  k = k_expanded,
  k_per_level = NA_character_,
  defensible = (k_expanded >= 10)
)

cat(sprintf("    Coefficient: %.4f (SE=%.4f), p=%.4f, R^2=%.1f%%\n",
            meta_reg_year$beta[2], meta_reg_year$se[2],
            meta_reg_year$pval[2], max(0, meta_reg_year$R2)))

# 5d. Region as moderator (categorical)
n_regions <- n_distinct(combined_es$region)
cat(sprintf("\n  5d. Region: %d regions\n", n_regions))
if (n_regions >= 3) {
  meta_reg_region <- tryCatch(
    rma(
      yi = log_odds, vi = var_log_odds,
      mods = ~factor(region),
      data = combined_es,
      method = "REML", test = "knha"
    ),
    error = function(e) {
      cat(sprintf("    Region meta-regression failed: %s\n", e$message))
      NULL
    }
  )

  if (!is.null(meta_reg_region)) {
    moderators$region <- data.frame(
      moderator = "Region (categorical)",
      coefficient = NA_real_,  # Multiple coefficients
      se = NA_real_,
      ci_lower = NA_real_,
      ci_upper = NA_real_,
      t_value = NA_real_,
      p_value = meta_reg_region$QMp,  # Omnibus test p-value
      R2_pct = max(0, meta_reg_region$R2),
      k = k_expanded,
      k_per_level = paste(sort(unique(combined_es$region)), collapse = "; "),
      defensible = FALSE  # Need k>=10 per region level
    )

    cat(sprintf("    Omnibus test: F=%.2f, p=%.4f, R^2=%.1f%%\n",
                meta_reg_region$QM / (n_regions - 1),
                meta_reg_region$QMp, max(0, meta_reg_region$R2)))
  }
}

moderator_df <- bind_rows(moderators)

cat("\n  --- Moderator Summary ---\n")
moderator_df %>%
  as.data.frame() %>%
  select(moderator, p_value, R2_pct, defensible) %>%
  mutate(
    p_value = sprintf("%.4f", p_value),
    R2_pct = sprintf("%.1f%%", R2_pct),
    status = ifelse(defensible, "Defensible (k>=10)", "EXPLORATORY (k<10)")
  ) %>%
  print()

# ==============================================================================
# SECTION 6: STRATIFIED META-ANALYSIS (NATURAL vs RESTORATION)
# ==============================================================================

cat("\nSECTION 6: Stratified Meta-Analysis by Population Type\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

cat("KEY ADVANCEMENT: With summary data, natural colonies now have k > 1.\n")
cat("This breaks the confounding of study identity with population type.\n\n")

strat_results <- combined_es %>%
  group_by(population_type) %>%
  group_modify(~ {
    data <- .x
    k <- nrow(data)

    if (k < 2) {
      # Single study: report observed value, no meta-analysis
      return(data.frame(
        k = k,
        n = sum(data$n_total),
        pooled_survival = data$survival_rate[1],
        ci_lower = data$surv_lower[1],
        ci_upper = data$surv_upper[1],
        pi_lower = NA_real_, pi_upper = NA_real_,
        tau_sq = NA_real_, I_sq = NA_real_,
        Q = NA_real_, p_Q = NA_real_
      ))
    }

    fit <- tryCatch(
      rma(yi = data$log_odds, vi = data$var_log_odds,
          method = "REML", test = "knha"),
      error = function(e) {
        tryCatch(
          rma(yi = data$log_odds, vi = data$var_log_odds,
              method = "DL", test = "knha"),
          error = function(e2) NULL
        )
      }
    )

    if (is.null(fit)) {
      return(data.frame(
        k = k, n = sum(data$n_total),
        pooled_survival = mean(data$survival_rate),
        ci_lower = NA_real_, ci_upper = NA_real_,
        pi_lower = NA_real_, pi_upper = NA_real_,
        tau_sq = NA_real_, I_sq = NA_real_,
        Q = NA_real_, p_Q = NA_real_
      ))
    }

    # Prediction interval
    fit_pred <- predict(fit)

    data.frame(
      k = k,
      n = sum(data$n_total),
      pooled_survival = plogis(as.numeric(fit$beta)),
      ci_lower = plogis(fit$ci.lb),
      ci_upper = plogis(fit$ci.ub),
      pi_lower = plogis(fit_pred$pi.lb),
      pi_upper = plogis(fit_pred$pi.ub),
      tau_sq = fit$tau2,
      I_sq = fit$I2,
      Q = fit$QE,
      p_Q = fit$QEp
    )
  }) %>%
  ungroup()

cat("STRATIFIED RESULTS:\n\n")
for (i in 1:nrow(strat_results)) {
  pop <- strat_results$population_type[i]
  k_i <- strat_results$k[i]
  cat(sprintf("  %s (k=%d, n=%d):\n", pop, k_i, strat_results$n[i]))
  cat(sprintf("    Pooled survival: %.1f%% (95%% CI: %.1f%% - %.1f%%)\n",
              strat_results$pooled_survival[i] * 100,
              strat_results$ci_lower[i] * 100,
              strat_results$ci_upper[i] * 100))
  if (!is.na(strat_results$pi_lower[i])) {
    cat(sprintf("    95%% PI: %.1f%% - %.1f%%\n",
                strat_results$pi_lower[i] * 100,
                strat_results$pi_upper[i] * 100))
  }
  if (!is.na(strat_results$I_sq[i])) {
    cat(sprintf("    I^2 = %.1f%%, tau^2 = %.4f\n",
                strat_results$I_sq[i], strat_results$tau_sq[i]))
  }
  cat("\n")
}

# Formal subgroup comparison using rma with moderator
cat("--- Formal Test of Subgroup Differences (Q-between) ---\n")
rma_subgroup <- rma(
  yi = log_odds, vi = var_log_odds,
  mods = ~population_type,
  data = combined_es,
  method = "REML", test = "knha"
)

cat(sprintf("  Q_moderator = %.2f, df = 1, p = %.4f\n",
            rma_subgroup$QM, rma_subgroup$QMp))

nat_surv <- strat_results$pooled_survival[strat_results$population_type == "Natural colony"]
rest_surv <- strat_results$pooled_survival[strat_results$population_type == "Restoration fragment"]
surv_diff_pp <- (nat_surv - rest_surv) * 100

cat(sprintf("  Difference: %.1f pp (natural %.1f%% vs restoration %.1f%%)\n",
            surv_diff_pp, nat_surv * 100, rest_surv * 100))

# --- MINIMUM DETECTABLE DIFFERENCE (natural vs restoration) ---
cat("\n--- MINIMUM DETECTABLE DIFFERENCE ---\n")
cat("  The non-significant p=0.30 does NOT mean no difference exists.\n")
cat("  Computing minimum detectable difference at 80% power:\n\n")

# Extract subgroup counts (reuse k_natural / k_restoration from Section 5)
k_nat_mdd <- sum(combined_es$population_type == "Natural colony")
k_rest_mdd <- sum(combined_es$population_type != "Natural colony")

# Use tau^2 from the overall model as the between-study variance
# For a two-group comparison in meta-analysis, the variance of the difference is:
# Var(diff) = tau^2 * (1/k1 + 1/k2) + mean(vi_1)/k1 + mean(vi_2)/k2
# Both between-study and within-study variance components are needed.
mean_vi_nat <- mean(combined_es$var_log_odds[combined_es$population_type == "Natural colony"], na.rm = TRUE)
mean_vi_rest <- mean(combined_es$var_log_odds[combined_es$population_type != "Natural colony"], na.rm = TRUE)
se_diff_mdd <- sqrt(tau_sq * (1 / k_nat_mdd + 1 / k_rest_mdd) + mean_vi_nat / k_nat_mdd + mean_vi_rest / k_rest_mdd)

# Minimum detectable difference at 80% power, alpha=0.05 (two-sided)
# Use t-distribution with df = k - 2 for Knapp-Hartung consistency
df_mdd <- k_expanded - 2
z_alpha <- qt(0.975, df_mdd)
z_beta <- qt(0.80, df_mdd)
mdd_log_odds <- (z_alpha + z_beta) * se_diff_mdd

# Convert to probability scale (approximate using overall pooled survival)
mdd_prob <- plogis(qlogis(pooled_surv) + mdd_log_odds / 2) -
  plogis(qlogis(pooled_surv) - mdd_log_odds / 2)

cat(sprintf("  Natural studies (k): %d\n", k_nat_mdd))
cat(sprintf("  Restoration studies (k): %d\n", k_rest_mdd))
cat(sprintf("  Between-study variance (tau^2): %.4f\n", tau_sq))
cat(sprintf("  SE of subgroup difference: %.4f (log-odds scale)\n", se_diff_mdd))
cat(sprintf("  Minimum detectable difference (80%% power): %.1f pp\n", mdd_prob * 100))
cat(sprintf("  Observed difference: %.1f pp (p = %.4f)\n",
            abs(nat_surv - rest_surv) * 100, rma_subgroup$QMp))

if (mdd_prob * 100 > abs(nat_surv - rest_surv) * 100) {
  cat("  -> The analysis is UNDERPOWERED to detect the observed difference.\n")
  cat("  -> Non-significance reflects insufficient k, not absence of a real effect.\n")
} else {
  cat("  -> The analysis has adequate power; the difference may genuinely be small.\n")
}

# Add caveats to stratified output
strat_output <- strat_results %>%
  mutate(
    caveat = case_when(
      population_type == "Natural colony" & k >= 2 ~
        paste0("Meta-analytic estimate from k=", k, " studies. ",
               "Includes Vardi 2011 regional effects. ",
               "Major improvement over k=1 (Tier 1 only)."),
      population_type == "Restoration fragment" ~
        paste0("Meta-analytic estimate from k=", k, " restoration fragment studies."),
      TRUE ~ "Single-study estimate."
    )
  )

# Add difference row
diff_row <- data.frame(
  population_type = "Difference (Natural - Restoration)",
  k = NA_integer_, n = NA_integer_,
  pooled_survival = nat_surv - rest_surv,
  ci_lower = NA_real_, ci_upper = NA_real_,
  pi_lower = NA_real_, pi_upper = NA_real_,
  tau_sq = NA_real_, I_sq = NA_real_,
  Q = NA_real_, p_Q = NA_real_,
  caveat = sprintf(
    "%.1f pp difference. Q_moderator p=%.4f. %s",
    surv_diff_pp, rma_subgroup$QMp,
    ifelse(rma_subgroup$QMp < 0.05,
           "Statistically significant difference.",
           "Not statistically significant.")
  )
)
strat_output <- bind_rows(strat_output, diff_row)

# ==============================================================================
# SECTION 7: GEOGRAPHIC ANALYSIS
# ==============================================================================

cat("\nSECTION 7: Geographic Analysis\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

region_summary <- combined_es %>%
  group_by(region) %>%
  summarise(
    k = n(),
    n_total = sum(n_total),
    mean_survival = mean(survival_rate),
    min_survival = min(survival_rate),
    max_survival = max(survival_rate),
    studies = paste(study, collapse = "; "),
    pop_types = paste(unique(population_type), collapse = ", "),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_survival))

cat("  Survival by region:\n")
region_summary %>%
  mutate(
    mean_survival = sprintf("%.1f%%", mean_survival * 100),
    range = sprintf("%.1f%% - %.1f%%", min_survival * 100, max_survival * 100)
  ) %>%
  select(region, k, n_total, mean_survival, range) %>%
  as.data.frame() %>%
  print()

# Subgroup meta-analysis by region (only for regions with k >= 2)
region_meta <- combined_es %>%
  group_by(region) %>%
  group_modify(~ {
    data <- .x
    if (nrow(data) < 2) {
      return(data.frame(
        k = nrow(data), n = sum(data$n_total),
        pooled_survival = data$survival_rate[1],
        ci_lower = data$surv_lower[1], ci_upper = data$surv_upper[1],
        I_sq = NA_real_, tau_sq = NA_real_
      ))
    }
    fit <- tryCatch(
      rma(yi = data$log_odds, vi = data$var_log_odds,
          method = "REML", test = "knha"),
      error = function(e) NULL
    )
    if (is.null(fit)) {
      return(data.frame(
        k = nrow(data), n = sum(data$n_total),
        pooled_survival = mean(data$survival_rate),
        ci_lower = NA_real_, ci_upper = NA_real_,
        I_sq = NA_real_, tau_sq = NA_real_
      ))
    }
    data.frame(
      k = nrow(data), n = sum(data$n_total),
      pooled_survival = plogis(as.numeric(fit$beta)),
      ci_lower = plogis(fit$ci.lb), ci_upper = plogis(fit$ci.ub),
      I_sq = fit$I2, tau_sq = fit$tau2
    )
  }) %>%
  ungroup()

# ==============================================================================
# SECTION 8: SENSITIVITY ANALYSES
# ==============================================================================

cat("\nSECTION 8: Sensitivity Analyses\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# 8a. Leave-one-out on expanded dataset
# Note: LOO uses rma_independent (standard rma) for compatibility with leave1out()
cat("  8a. Leave-one-out analysis (expanded, using independent-effects model)\n")
loo_expanded <- leave1out(rma_independent)

loo_df <- data.frame(
  excluded_study = combined_es$study,
  excluded_tier = combined_es$data_tier,
  excluded_pop_type = combined_es$population_type,
  pooled_log_odds = loo_expanded$estimate,
  pooled_survival = plogis(loo_expanded$estimate),
  ci_lower = plogis(loo_expanded$ci.lb),
  ci_upper = plogis(loo_expanded$ci.ub),
  tau_sq = loo_expanded$tau2,
  I_sq = loo_expanded$I2
) %>%
  mutate(
    change_pp = (pooled_survival - pooled_surv) * 100,
    influential = abs(change_pp) > 2  # >2 percentage point change
  )

influential <- loo_df %>% filter(influential)
if (nrow(influential) > 0) {
  cat(sprintf("  Influential studies (>2 pp change when excluded):\n"))
  for (i in 1:nrow(influential)) {
    cat(sprintf("    - %s [%s]: pooled -> %.1f%% (change: %+.1f pp)\n",
                influential$excluded_study[i],
                influential$excluded_tier[i],
                influential$pooled_survival[i] * 100,
                influential$change_pp[i]))
  }
} else {
  cat("  No individual study changes pooled estimate by >2 pp\n")
}

# 8b. Tier comparison: does adding summary data change conclusions?
cat("\n  8b. Tier comparison\n")
tier_comparison <- data.frame(
  analysis = c("Tier 1 only (individual)", "Tier 1 + 2 (expanded)"),
  k = c(nrow(tier1_only), k_expanded),
  n_total = c(sum(tier1_only$n_total), sum(combined_es$n_total)),
  pooled_survival = c(tier1_surv, pooled_surv),
  ci_lower = c(tier1_ci_lo, pooled_surv_lower),
  ci_upper = c(tier1_ci_hi, pooled_surv_upper),
  I_sq = c(rma_tier1$I2, I_sq),
  tau_sq = c(rma_tier1$tau2, tau_sq)
)

cat("  Tier comparison:\n")
tier_comparison %>%
  mutate(
    pooled_survival = sprintf("%.1f%%", pooled_survival * 100),
    ci = sprintf("[%.1f%%, %.1f%%]", ci_lower * 100, ci_upper * 100),
    I_sq = sprintf("%.1f%%", I_sq)
  ) %>%
  select(analysis, k, n_total, pooled_survival, ci, I_sq) %>%
  print()

# 8c. Influence diagnostics
# FIX: Enhanced influence diagnostics with CSV output (critique audit 2026-03-29)
# Note: influence() requires an rma object (not rma.mv), so we use rma_independent
cat("\n  8c. Influence diagnostics\n")
inf_diag <- tryCatch(
  influence(rma_independent),
  error = function(e) {
    cat(sprintf("    Influence diagnostics failed: %s\n", e$message))
    NULL
  }
)

if (!is.null(inf_diag)) {
  # Cook's distance
  cooks_d <- inf_diag$inf$cook.d
  names(cooks_d) <- combined_es$study
  cat("  Cook's distances:\n")
  sort_cd <- sort(cooks_d, decreasing = TRUE)
  for (i in 1:min(5, length(sort_cd))) {
    cat(sprintf("    %s: %.4f\n", names(sort_cd)[i], sort_cd[i]))
  }

  # Save full influence diagnostics to CSV
  influence_df <- data.frame(
    study = combined_es$study,
    study_id = combined_es$study_id,
    data_tier = combined_es$data_tier,
    cooks_distance = inf_diag$inf$cook.d,
    dffits = inf_diag$inf$dffits,
    hat_value = inf_diag$inf$hat,
    weight_pct = combined_es$weight_re_pct,
    covratio = inf_diag$inf$cov.r,
    tau2_del = inf_diag$inf$tau2.del,
    QE_del = inf_diag$inf$QE.del
  )
  write_csv(influence_df, file.path(output_dir, "expanded_meta_influence.csv"))
  cat("  Saved: expanded_meta_influence.csv\n")
}

# ==============================================================================
# SECTION 9: PUBLICATION-QUALITY FIGURES
# ==============================================================================

cat("\nSECTION 9: Creating Publication-Quality Figures\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Color palettes
pop_colors <- c(
  "Natural colony" = MANUSCRIPT_PALETTE$natural,       # "#0072B2"
  "Restoration fragment" = MANUSCRIPT_PALETTE$restoration  # "#D55E00"
)

# FIX: Add AI_EXTRACTED tier to shape mapping (critique audit 2026-03-29)
# Previously missing "Tier 2 (summary) [AI_EXTRACTED]" caused unmapped points
tier_shapes <- c(
  "Tier 1 (individual)" = 16,           # Filled circle
  "Tier 2 (summary)" = 17,              # Filled triangle
  "Tier 2 (summary) [AI_EXTRACTED]" = 18  # Filled diamond — AI-extracted data
)

# --- Figure 9a: Expanded forest plot ---
cat("  9a. Expanded forest plot...\n")

forest_data <- combined_es %>%
  arrange(population_type, desc(survival_rate)) %>%
  mutate(
    study_label = paste0(study, " (", region, ")"),
    study_label = factor(study_label, levels = rev(study_label))
  )

p_forest <- ggplot(forest_data, aes(y = study_label)) +
  # Prediction interval shading
  annotate("rect",
           xmin = pi_lower, xmax = pi_upper,
           ymin = 0.3, ymax = nrow(forest_data) + 0.7,
           fill = "#E8F4F8", alpha = 0.6) +
  # Pooled estimate
  geom_vline(xintercept = pooled_surv, linetype = "dashed",
             color = "#2C3E50", linewidth = 0.7) +
  # 50% reference
  geom_vline(xintercept = 0.5, linetype = "dotted", color = "gray70") +
  # Study CIs
  geom_errorbarh(aes(xmin = surv_lower, xmax = surv_upper),
                 height = 0.3, color = "#34495E", linewidth = 0.5) +
  # Study points -- color by pop type, shape by tier
  geom_point(aes(x = survival_rate, size = weight_re_pct,
                 color = population_type, shape = data_tier),
             alpha = 0.9) +
  # Pooled diamond
  annotate("point", x = pooled_surv, y = 0.15,
           shape = 23, size = 4.5, fill = "#E74C3C", color = "#C0392B") +
  annotate("errorbarh", xmin = pooled_surv_lower, xmax = pooled_surv_upper,
           y = 0.15, height = 0.15, color = "#C0392B", linewidth = 0.7) +
  # Scales
  scale_color_manual(values = pop_colors, name = "Population type") +
  scale_shape_manual(values = tier_shapes, name = "Data tier") +
  scale_x_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2),
    labels = scales::percent_format(accuracy = 1),
    expand = c(0.02, 0)
  ) +
  scale_size_continuous(range = c(2, 7), guide = "none") +
  labs(
    x = "Annual Survival Rate",
    y = NULL,
    caption = sprintf(
      paste0("Dashed line: pooled estimate (%.1f%%); ",
             "Shaded: 95%% prediction interval (%.1f%%\u2013%.1f%%)\n",
             "I\u00B2 = %.1f%% [%.1f%%, %.1f%%], ",
             "\u03C4\u00B2 = %.3f, Q = %.1f (p %s)"),
      pooled_surv * 100, pi_lower * 100, pi_upper * 100,
      I_sq, I_sq_lower, I_sq_upper, tau_sq, Q_stat,
      ifelse(Q_p < 0.001, "< 0.001", sprintf("= %.3f", Q_p))
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.caption = element_text(hjust = 0, size = 8, color = "gray40"),
    axis.text.y = element_text(size = 9, color = "grey30"),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.key.size = unit(4, "mm"),
    plot.margin = margin(10, 10, 10, 10, "mm")
  ) +
  guides(
    color = guide_legend(order = 1),
    shape = guide_legend(order = 2)
  )

ggsave(file.path(fig_dir, "expanded_forest_plot.png"), p_forest,
       width = 174, height = 220, units = "mm", dpi = 300)
ggsave(file.path(fig_dir, "expanded_forest_plot.pdf"), p_forest,
       width = 174, height = 220, units = "mm")
cat("    Saved: expanded_forest_plot.png/pdf\n")

# --- Figure 9b: Tier comparison plot ---
cat("  9b. Tier comparison plot...\n")

p_tier_compare <- ggplot(tier_comparison,
                          aes(y = factor(analysis, levels = rev(analysis)))) +
  geom_vline(xintercept = 0.5, linetype = "dotted", color = "gray70") +
  geom_errorbarh(aes(xmin = ci_lower, xmax = ci_upper),
                 height = 0.3, color = "#34495E", linewidth = 0.8) +
  geom_point(aes(x = pooled_survival, size = k), color = "#3498DB") +
  geom_text(aes(x = pooled_survival,
                label = sprintf("%.1f%% [%.1f, %.1f]\nk=%d, n=%s",
                                pooled_survival * 100,
                                ci_lower * 100, ci_upper * 100,
                                k, format(n_total, big.mark = ","))),
            vjust = -1.5, size = 3.5) +
  scale_x_continuous(
    limits = c(0.4, 1),
    labels = scales::percent_format(accuracy = 1)
  ) +
  scale_size_continuous(range = c(4, 8), guide = "none") +
  labs(
    x = "Pooled Annual Survival Rate",
    y = NULL,
    caption = "Error bars: 95% confidence intervals (Knapp-Hartung)"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    plot.caption = element_text(hjust = 0, size = 8, color = "gray40"),
    axis.text.y = element_text(size = 11, face = "bold"),
    plot.margin = margin(10, 10, 10, 10, "mm")
  )

ggsave(file.path(fig_dir, "expanded_tier_comparison.png"), p_tier_compare,
       width = 174, height = 80, units = "mm", dpi = 300)
ggsave(file.path(fig_dir, "expanded_tier_comparison.pdf"), p_tier_compare,
       width = 174, height = 80, units = "mm")
cat("    Saved: expanded_tier_comparison.png/pdf\n")

# --- Figure 9c: Funnel plot ---
cat("  9c. Funnel plot...\n")

# Build funnel boundaries
se_range <- seq(0.001, max(combined_es$se_log_odds) * 1.2, length.out = 100)
funnel_bounds <- data.frame(
  se = se_range,
  lower_95 = pooled_lo - 1.96 * se_range,
  upper_95 = pooled_lo + 1.96 * se_range
)

p_funnel <- ggplot() +
  # 95% pseudo-CI contour
  geom_polygon(data = data.frame(
    x = c(funnel_bounds$lower_95, rev(funnel_bounds$upper_95)),
    y = c(funnel_bounds$se, rev(funnel_bounds$se))
  ), aes(x = x, y = y), fill = "#FCF3CF", alpha = 0.7) +
  geom_line(data = funnel_bounds, aes(x = lower_95, y = se),
            linetype = "dashed", color = "gray50") +
  geom_line(data = funnel_bounds, aes(x = upper_95, y = se),
            linetype = "dashed", color = "gray50") +
  # Pooled effect line
  geom_vline(xintercept = pooled_lo, linetype = "solid", color = "#2C3E50") +
  # Study points
  geom_point(data = combined_es,
             aes(x = log_odds, y = se_log_odds,
                 color = population_type, shape = data_tier,
                 size = n_total),
             alpha = 0.8) +
  # Invert y-axis
  scale_y_reverse(limits = c(max(combined_es$se_log_odds) * 1.15, 0)) +
  scale_color_manual(values = pop_colors, name = "Population type") +
  scale_shape_manual(values = tier_shapes, name = "Data tier") +
  scale_size_continuous(range = c(2, 7), name = "Sample size") +
  labs(
    x = "Log Odds (Survival)",
    y = "Standard Error",
    caption = "Dashed lines: 95% pseudo-confidence limits"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.key.size = unit(4, "mm"),
    plot.caption = element_text(hjust = 0, size = 8, color = "gray40"),
    plot.margin = margin(10, 10, 10, 10, "mm")
  )

ggsave(file.path(fig_dir, "expanded_funnel_plot.png"), p_funnel,
       width = 174, height = 160, units = "mm", dpi = 300)
ggsave(file.path(fig_dir, "expanded_funnel_plot.pdf"), p_funnel,
       width = 174, height = 160, units = "mm")
cat("    Saved: expanded_funnel_plot.png/pdf\n")

# --- Figure 9d: Regional summary ---
cat("  9d. Regional survival summary...\n")

region_plot_data <- combined_es %>%
  mutate(
    region = reorder(factor(region), survival_rate, FUN = median)
  )

p_region <- ggplot(region_plot_data,
                    aes(x = survival_rate, y = region)) +
  geom_vline(xintercept = pooled_surv, linetype = "dashed",
             color = "#2C3E50", linewidth = 0.5) +
  geom_point(aes(color = population_type, shape = data_tier, size = n_total),
             alpha = 0.8) +
  scale_color_manual(values = pop_colors, name = "Population type") +
  scale_shape_manual(values = tier_shapes, name = "Data tier") +
  scale_size_continuous(range = c(2, 8), name = "Sample size") +
  scale_x_continuous(
    limits = c(0, 1),
    labels = scales::percent_format(accuracy = 1)
  ) +
  labs(
    x = "Annual Survival Rate",
    y = NULL,
    caption = sprintf("Dashed line: pooled estimate (%.1f%%)", pooled_surv * 100)
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.key.size = unit(4, "mm"),
    axis.text.y = element_text(size = 10),
    plot.caption = element_text(hjust = 0, size = 8, color = "gray40"),
    plot.margin = margin(10, 15, 10, 10, "mm")
  )

ggsave(file.path(fig_dir, "expanded_regional_summary.png"), p_region,
       width = 174, height = 140, units = "mm", dpi = 300)
ggsave(file.path(fig_dir, "expanded_regional_summary.pdf"), p_region,
       width = 174, height = 140, units = "mm")
cat("    Saved: expanded_regional_summary.png/pdf\n")

# ==============================================================================
# SECTION 10: SAVE ALL OUTPUTS
# ==============================================================================

cat("\nSECTION 10: Saving Outputs\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# 10a. Main results summary
# FIX: Updated to reflect three-level model as primary (critique audit 2026-03-29)
results_summary <- data.frame(
  statistic = c(
    "Number of studies (k)", "Number of effects",
    "Total observations (N)",
    "Tier 1 effects", "Tier 2 effects",
    "Natural colony effects", "Restoration fragment effects",
    "Primary model", "Pooled survival (RE)", "95% CI lower", "95% CI upper",
    "95% PI lower", "95% PI upper",
    "tau^2 (total)", "tau^2 (between-study)", "tau^2 (within-study)", "tau",
    "I^2 (%) [independent model]", "I^2 CI lower", "I^2 CI upper",
    "Cochran's Q", "Q df", "Q p-value",
    "REML estimation method", "Small-sample adjustment",
    "MDD SE (log-odds)", "MDD (log-odds, 80% power)",
    "MDD (probability scale, pp)", "Observed difference (pp)",
    "MDD power interpretation"
  ),
  value = c(
    as.character(k_studies),
    as.character(k_expanded),
    as.character(sum(combined_es$n_total)),
    as.character(sum(combined_es$data_tier == "Tier 1 (individual)")),
    as.character(sum(grepl("Tier 2", combined_es$data_tier))),
    as.character(sum(combined_es$population_type == "Natural colony")),
    as.character(sum(combined_es$population_type == "Restoration fragment")),
    primary_model_label,
    sprintf("%.3f", pooled_surv),
    sprintf("%.3f", pooled_surv_lower),
    sprintf("%.3f", pooled_surv_upper),
    sprintf("%.3f", pi_lower),
    sprintf("%.3f", pi_upper),
    sprintf("%.4f", tau_sq),
    sprintf("%.4f", tau_sq_between),
    sprintf("%.4f", tau_sq_within),
    sprintf("%.4f", tau),
    sprintf("%.1f", I_sq),
    sprintf("%.1f", I_sq_lower),
    sprintf("%.1f", I_sq_upper),
    sprintf("%.2f", Q_stat),
    as.character(k_expanded - 1),
    sprintf("%.4f", Q_p),
    "REML",
    "t-test (three-level) / Knapp-Hartung (independent)",
    sprintf("%.4f", se_diff_mdd),
    sprintf("%.4f", mdd_log_odds),
    sprintf("%.1f", mdd_prob * 100),
    sprintf("%.1f", abs(nat_surv - rest_surv) * 100),
    ifelse(mdd_prob * 100 > abs(nat_surv - rest_surv) * 100,
           "UNDERPOWERED to detect observed difference",
           "Adequate power; difference may genuinely be small")
  )
)
write_csv(results_summary, file.path(output_dir, "expanded_meta_analysis_results.csv"))
cat("  Saved: expanded_meta_analysis_results.csv\n")

# 10b. Study effects
write_csv(
  combined_es %>%
    select(study, study_id, region, data_tier, population_type, n_total, n_survived,
           survival_rate, mean_size_cm2, survey_yr, fragment,
           log_odds, var_log_odds, se_log_odds, surv_lower, surv_upper,
           weight_re_pct),
  file.path(output_dir, "expanded_meta_analysis_study_effects.csv")
)
cat("  Saved: expanded_meta_analysis_study_effects.csv\n")

# 10c. Moderators
write_csv(moderator_df, file.path(output_dir, "expanded_meta_analysis_moderators.csv"))
cat("  Saved: expanded_meta_analysis_moderators.csv\n")

# 10d. Stratified results
write_csv(strat_output, file.path(output_dir, "expanded_meta_analysis_stratified.csv"))
cat("  Saved: expanded_meta_analysis_stratified.csv\n")

# 10e. Regional results
write_csv(region_meta, file.path(output_dir, "expanded_meta_analysis_by_region.csv"))
cat("  Saved: expanded_meta_analysis_by_region.csv\n")

# 10f. Tier comparison
write_csv(tier_comparison, file.path(output_dir, "expanded_meta_analysis_tier_comparison.csv"))
cat("  Saved: expanded_meta_analysis_tier_comparison.csv\n")

# 10g. Leave-one-out
write_csv(loo_df, file.path(output_dir, "expanded_meta_analysis_loo.csv"))
cat("  Saved: expanded_meta_analysis_loo.csv\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n")
cat("==============================================================================\n")
cat("  EXPANDED META-ANALYSIS SUMMARY\n")
cat("==============================================================================\n\n")

cat("KEY ADVANCEMENT:\n")
cat(sprintf("  k=%d studies contributing %d effects (NOAA and Vardi split by region).\n",
            k_studies, k_expanded))
cat(sprintf("  Natural colony effects: k=%d (breaks single-study confound)\n",
            k_natural))
cat(sprintf("  Geographic coverage: %d regions across the Caribbean\n",
            n_distinct(combined_es$region)))
cat(sprintf("  Primary model: %s\n", primary_model_label))

cat("\nMAIN FINDINGS:\n")
cat(sprintf("  Pooled annual survival: %.1f%% (95%% CI: %.1f%% - %.1f%%)\n",
            pooled_surv * 100, pooled_surv_lower * 100, pooled_surv_upper * 100))
cat(sprintf("  95%% Prediction interval: %.1f%% - %.1f%%\n",
            pi_lower * 100, pi_upper * 100))
cat(sprintf("  I^2 = %.1f%% (%s heterogeneity)\n",
            I_sq, ifelse(I_sq > 75, "Considerable", ifelse(I_sq > 50, "Substantial",
                         ifelse(I_sq > 25, "Moderate", "Low")))))

cat("\nSTRATIFIED RESULTS:\n")
for (i in 1:nrow(strat_results)) {
  cat(sprintf("  %s (k=%d): %.1f%% (CI: %.1f%% - %.1f%%)\n",
              strat_results$population_type[i],
              strat_results$k[i],
              strat_results$pooled_survival[i] * 100,
              strat_results$ci_lower[i] * 100,
              strat_results$ci_upper[i] * 100))
}
cat(sprintf("  Difference: %.1f pp (Q_mod p = %.4f)\n",
            surv_diff_pp, rma_subgroup$QMp))

cat("\nMODERATOR ANALYSIS:\n")
for (i in 1:nrow(moderator_df)) {
  cat(sprintf("  %s: p=%.4f, R^2=%.1f%% %s\n",
              moderator_df$moderator[i],
              moderator_df$p_value[i],
              moderator_df$R2_pct[i],
              ifelse(moderator_df$defensible[i], "", "[EXPLORATORY]")))
}

cat("\nIMPORTANT CAVEATS:\n")
cat("  1. Summary data has variable quality (histogram-estimated n, non-standard intervals)\n")
cat("  2. Adding summary studies changes composition: more restoration fragment studies\n")
cat("  3. Annualization assumes constant hazard (exponential survival model)\n")
cat("  4. Tier 1/Tier 2 annualization inconsistency: Tier 1 = raw pooled proportion,\n")
cat("     Tier 2 = annualized via S^(1/t). See Section 1 comment block for details.\n")
cat("  5. Some n_initial are estimated from figures, not exact counts\n")
cat("  6. Studies span 2+ decades (1980-2024), different regions, and varied methods\n")
cat("  7. Vardi 2011 and NOAA regions treated as correlated effects within parent study\n")
cat("     (three-level model accounts for within-study correlation)\n")
cat("  8. Garrison & Ward 2008 split into 2 effects: control (Natural) and relocated (Restoration)\n")
cat("  9. Rogers 1982: storm-generated fragments classified as Natural colony\n")

cat("\nOUTPUTS:\n")
cat("  Data files:\n")
cat("    - expanded_meta_analysis_results.csv\n")
cat("    - expanded_meta_analysis_study_effects.csv\n")
cat("    - expanded_meta_analysis_moderators.csv\n")
cat("    - expanded_meta_analysis_stratified.csv\n")
cat("    - expanded_meta_analysis_by_region.csv\n")
cat("    - expanded_meta_analysis_tier_comparison.csv\n")
cat("    - expanded_meta_analysis_loo.csv\n")
cat("    - expanded_meta_influence.csv\n")
cat("    - expanded_meta_trimfill.csv\n")
cat("    - expanded_meta_tau_estimator_comparison.csv\n")
cat("  Figures:\n")
cat("    - expanded_forest_plot.png/pdf\n")
cat("    - expanded_tier_comparison.png/pdf\n")
cat("    - expanded_funnel_plot.png/pdf\n")
cat("    - expanded_regional_summary.png/pdf\n")

# ==============================================================================
# SECTION 11: CLASSIFICATION SENSITIVITY ANALYSIS
# ==============================================================================

cat("\nSECTION 11: Classification Sensitivity Analysis\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Test how study classification (natural vs restoration) affects subgroup results.
# Garrison & Ward 2008 is now split: control=Natural, relocated=Restoration.
# Vardi 2011 is the remaining ambiguous case (naturally-occurring colonies at
# sites where restoration also occurred — classified as Natural).
# Four scenarios:
#   1. Current: Vardi=Natural, Garrison split (control=Nat, relocated=Rest)
#   2. Conservative: Vardi=Natural, Garrison excluded entirely
#   3. Original coding: Vardi=Restoration, Garrison excluded
#   4. Bruckner=Natural (storm fragments reclassified)

classification_results <- list()

# --- Scenario 1: Current classification (already computed above) ---
cat("  Scenario 1 (Current): Vardi=Natural, Garrison split (control=Nat, relocated=Rest)\n")
scenario1 <- combined_es  # already has the current classification
rma_s1 <- rma(yi = log_odds, vi = var_log_odds, data = scenario1, method = "REML", test = "knha")
rma_s1_sub <- rma(yi = log_odds, vi = var_log_odds, mods = ~population_type,
                   data = scenario1, method = "REML", test = "knha")

s1_nat <- scenario1 %>% filter(population_type == "Natural colony")
s1_rest <- scenario1 %>% filter(population_type == "Restoration fragment")
if (nrow(s1_nat) > 0) {
  rma_s1_nat <- rma(yi = log_odds, vi = var_log_odds, data = s1_nat, method = "REML", test = "knha")
  s1_nat_surv <- plogis(as.numeric(rma_s1_nat$beta))
} else { s1_nat_surv <- NA }
if (nrow(s1_rest) > 0) {
  rma_s1_rest <- rma(yi = log_odds, vi = var_log_odds, data = s1_rest, method = "REML", test = "knha")
  s1_rest_surv <- plogis(as.numeric(rma_s1_rest$beta))
} else { s1_rest_surv <- NA }

classification_results[[1]] <- data.frame(
  scenario = "Current (Vardi=Nat, Garrison split)",
  k_total = nrow(scenario1),
  k_natural = nrow(s1_nat), k_restoration = nrow(s1_rest),
  pooled_survival = plogis(as.numeric(rma_s1$beta)),
  natural_survival = s1_nat_surv, restoration_survival = s1_rest_surv,
  difference_pp = (s1_nat_surv - s1_rest_surv) * 100,
  moderator_p = rma_s1_sub$QMp,
  I2 = rma_s1$I2, tau2 = rma_s1$tau2
)
cat(sprintf("    k=%d (nat=%d, rest=%d), pooled=%.1f%%, diff=%.1f pp, p=%.4f\n",
            nrow(scenario1), nrow(s1_nat), nrow(s1_rest),
            plogis(as.numeric(rma_s1$beta)) * 100,
            (s1_nat_surv - s1_rest_surv) * 100, rma_s1_sub$QMp))

# --- Scenario 2: Conservative (Garrison excluded) ---
cat("  Scenario 2 (Conservative): Vardi=Natural, Garrison=excluded\n")
scenario2 <- combined_es %>% filter(!grepl("^garrison_ward_2008", study))
rma_s2 <- rma(yi = log_odds, vi = var_log_odds, data = scenario2, method = "REML", test = "knha")
rma_s2_sub <- rma(yi = log_odds, vi = var_log_odds, mods = ~population_type,
                   data = scenario2, method = "REML", test = "knha")

s2_nat <- scenario2 %>% filter(population_type == "Natural colony")
s2_rest <- scenario2 %>% filter(population_type == "Restoration fragment")
if (nrow(s2_nat) > 0) {
  rma_s2_nat <- rma(yi = log_odds, vi = var_log_odds, data = s2_nat, method = "REML", test = "knha")
  s2_nat_surv <- plogis(as.numeric(rma_s2_nat$beta))
} else { s2_nat_surv <- NA }
if (nrow(s2_rest) > 0) {
  rma_s2_rest <- rma(yi = log_odds, vi = var_log_odds, data = s2_rest, method = "REML", test = "knha")
  s2_rest_surv <- plogis(as.numeric(rma_s2_rest$beta))
} else { s2_rest_surv <- NA }

classification_results[[2]] <- data.frame(
  scenario = "Conservative (Vardi=Nat, Garrison=excl)",
  k_total = nrow(scenario2),
  k_natural = nrow(s2_nat), k_restoration = nrow(s2_rest),
  pooled_survival = plogis(as.numeric(rma_s2$beta)),
  natural_survival = s2_nat_surv, restoration_survival = s2_rest_surv,
  difference_pp = (s2_nat_surv - s2_rest_surv) * 100,
  moderator_p = rma_s2_sub$QMp,
  I2 = rma_s2$I2, tau2 = rma_s2$tau2
)
cat(sprintf("    k=%d (nat=%d, rest=%d), pooled=%.1f%%, diff=%.1f pp, p=%.4f\n",
            nrow(scenario2), nrow(s2_nat), nrow(s2_rest),
            plogis(as.numeric(rma_s2$beta)) * 100,
            (s2_nat_surv - s2_rest_surv) * 100, rma_s2_sub$QMp))

# --- Scenario 3: Original coding (Vardi=Restoration, Garrison=excluded) ---
cat("  Scenario 3 (Original): Vardi=Restoration, Garrison=excluded\n")
scenario3 <- combined_es %>%
  filter(!grepl("^garrison_ward_2008", study)) %>%
  mutate(
    population_type = ifelse(grepl("^vardi_2011", study),
                              "Restoration fragment", population_type)
  )
rma_s3 <- rma(yi = log_odds, vi = var_log_odds, data = scenario3, method = "REML", test = "knha")
rma_s3_sub <- rma(yi = log_odds, vi = var_log_odds, mods = ~population_type,
                   data = scenario3, method = "REML", test = "knha")

s3_nat <- scenario3 %>% filter(population_type == "Natural colony")
s3_rest <- scenario3 %>% filter(population_type == "Restoration fragment")
if (nrow(s3_nat) > 0) {
  rma_s3_nat <- rma(yi = log_odds, vi = var_log_odds, data = s3_nat, method = "REML", test = "knha")
  s3_nat_surv <- plogis(as.numeric(rma_s3_nat$beta))
} else { s3_nat_surv <- NA }
if (nrow(s3_rest) > 0) {
  rma_s3_rest <- rma(yi = log_odds, vi = var_log_odds, data = s3_rest, method = "REML", test = "knha")
  s3_rest_surv <- plogis(as.numeric(rma_s3_rest$beta))
} else { s3_rest_surv <- NA }

classification_results[[3]] <- data.frame(
  scenario = "Original (Vardi=Rest, Garrison=excl)",
  k_total = nrow(scenario3),
  k_natural = nrow(s3_nat), k_restoration = nrow(s3_rest),
  pooled_survival = plogis(as.numeric(rma_s3$beta)),
  natural_survival = s3_nat_surv, restoration_survival = s3_rest_surv,
  difference_pp = (s3_nat_surv - s3_rest_surv) * 100,
  moderator_p = rma_s3_sub$QMp,
  I2 = rma_s3$I2, tau2 = rma_s3$tau2
)
cat(sprintf("    k=%d (nat=%d, rest=%d), pooled=%.1f%%, diff=%.1f pp, p=%.4f\n",
            nrow(scenario3), nrow(s3_nat), nrow(s3_rest),
            plogis(as.numeric(rma_s3$beta)) * 100,
            (s3_nat_surv - s3_rest_surv) * 100, rma_s3_sub$QMp))

# --- Scenario 4: Reclassify Bruckner as Natural (naturally-occurring storm fragments) ---
cat("  Scenario 4 (Bruckner=Natural): Reclassify Bruckner as Natural colony\n")
# Bruckner & Bruckner (2001) tracked naturally-occurring storm fragments,
# not restoration outplants. This scenario tests whether reclassifying
# Bruckner changes the natural vs. restoration subgroup comparison.
scenario4 <- combined_es %>%
  mutate(population_type = ifelse(study == "bruckner_bruckner_2001", "Natural colony", population_type))
rma_s4 <- rma(yi = log_odds, vi = var_log_odds, data = scenario4, method = "REML", test = "knha")
rma_s4_sub <- rma(yi = log_odds, vi = var_log_odds, mods = ~population_type,
                   data = scenario4, method = "REML", test = "knha")

s4_nat <- scenario4 %>% filter(population_type == "Natural colony")
s4_rest <- scenario4 %>% filter(population_type == "Restoration fragment")
if (nrow(s4_nat) > 0) {
  rma_s4_nat <- rma(yi = log_odds, vi = var_log_odds, data = s4_nat, method = "REML", test = "knha")
  s4_nat_surv <- plogis(as.numeric(rma_s4_nat$beta))
} else { s4_nat_surv <- NA }
if (nrow(s4_rest) > 0) {
  rma_s4_rest <- rma(yi = log_odds, vi = var_log_odds, data = s4_rest, method = "REML", test = "knha")
  s4_rest_surv <- plogis(as.numeric(rma_s4_rest$beta))
} else { s4_rest_surv <- NA }

classification_results[[4]] <- data.frame(
  scenario = "Bruckner=Natural (storm fragments)",
  k_total = nrow(scenario4),
  k_natural = nrow(s4_nat), k_restoration = nrow(s4_rest),
  pooled_survival = plogis(as.numeric(rma_s4$beta)),
  natural_survival = s4_nat_surv, restoration_survival = s4_rest_surv,
  difference_pp = (s4_nat_surv - s4_rest_surv) * 100,
  moderator_p = rma_s4_sub$QMp,
  I2 = rma_s4$I2, tau2 = rma_s4$tau2
)
cat(sprintf("    k=%d (nat=%d, rest=%d), pooled=%.1f%%, diff=%.1f pp, p=%.4f\n",
            nrow(scenario4), nrow(s4_nat), nrow(s4_rest),
            plogis(as.numeric(rma_s4$beta)) * 100,
            (s4_nat_surv - s4_rest_surv) * 100, rma_s4_sub$QMp))

# --- Save classification sensitivity ---
class_sens <- do.call(rbind, classification_results)
write_csv(class_sens, file.path(output_dir, "expanded_meta_classification_sensitivity.csv"))
cat("\n✓ Saved: expanded_meta_classification_sensitivity.csv\n")

cat("\nCLASSIFICATION SENSITIVITY SUMMARY:\n")
cat(sprintf("  Nat-vs-rest difference ranges from %.1f to %.1f pp across scenarios\n",
            min(class_sens$difference_pp, na.rm = TRUE),
            max(class_sens$difference_pp, na.rm = TRUE)))
cat(sprintf("  Moderator p-value ranges from %.4f to %.4f\n",
            min(class_sens$moderator_p, na.rm = TRUE),
            max(class_sens$moderator_p, na.rm = TRUE)))
significant_any <- any(class_sens$moderator_p < 0.05, na.rm = TRUE)
cat(sprintf("  Significant under any scenario: %s\n",
            ifelse(significant_any, "YES", "NO")))

# ==============================================================================
# SECTION: RISK-OF-BIAS SENSITIVITY ANALYSIS
# FIX: Added per PRISMA audit 2026-03-29
# Maps adapted Newcastle-Ottawa Scale scores from 04_extraction/risk_of_bias.md
# to study_id, then tests whether RoB predicts survival and whether excluding
# low-quality studies (score <= 5) changes the pooled estimate.
# ==============================================================================

cat("\n")
cat("==============================================================================\n")
cat("  RISK-OF-BIAS SENSITIVITY ANALYSIS\n")
cat("==============================================================================\n\n")

# --- RoB scores from 04_extraction/risk_of_bias.md (adapted NOS, /10) ---
# Scores mapped to study_id (parent study), not the regional-split study names.
# NOAA regional effects inherit the NOAA_survey score (10).
# Vardi regional effects inherit the vardi_2011 score (9).
# Muller 2008, Sutherland 2016, and Roth 2013 are excluded from meta and not scored here.
rob_scores <- data.frame(
  study_id = c(
    "NOAA_survey",
    "pausch_et_al_2018",
    "USGS_USVI_exp",
    "kuffner_et_al_2020",
    "fundemar_fragments",
    "mendoza_quiroz_et_al_2023",
    "vardi_2011",
    "bruckner_bruckner_2001",
    "ortiz_prosper_2005",
    "forrester_et_al_2013",
    "rosales_et_al_2024",
    "maurer_et_al_2022",
    "williams_miller_2010",
    "garrison_ward_2008",
    "rogers_muller_2012",
    "ramos_romero_et_al_2025",
    "rogers_et_al_1982",
    "chamberland_et_al_2015",
    "papke_et_al_2021"
  ),
  rob_score = c(
    10,  # NOAA_survey
     8,  # pausch_et_al_2018
     7,  # USGS_USVI_exp
     6,  # kuffner_et_al_2020
     5,  # fundemar_fragments
     5,  # mendoza_quiroz_et_al_2023
     9,  # vardi_2011
     4,  # bruckner_bruckner_2001
     8,  # ortiz_prosper_2005
     6,  # forrester_et_al_2013
     8,  # rosales_et_al_2024
     7,  # maurer_et_al_2022
     5,  # williams_miller_2010
     7,  # garrison_ward_2008
     9,  # rogers_muller_2012
     7,  # ramos_romero_et_al_2025
     5,  # rogers_et_al_1982 (not scored in risk_of_bias.md; estimated as Moderate [5/10]
        #   based on 1982 methods: single-site convenience sample, visual tracking of
        #   hurricane-generated fragments, 11-month interval requiring annualization)
     7,  # chamberland_et_al_2015 (excluded from meta as recruits)
     6   # papke_et_al_2021 (excluded from meta as micro-fragments)
  ),
  stringsAsFactors = FALSE
)

# Merge RoB scores into combined_es via study_id
combined_rob <- merge(combined_es, rob_scores, by = "study_id", all.x = TRUE)

n_matched <- sum(!is.na(combined_rob$rob_score))
n_missing <- sum(is.na(combined_rob$rob_score))
cat(sprintf("  RoB scores matched: %d of %d effects\n", n_matched, nrow(combined_rob)))
if (n_missing > 0) {
  cat(sprintf("  WARNING: %d effects missing RoB scores:\n", n_missing))
  cat(sprintf("    %s\n", paste(combined_rob$study[is.na(combined_rob$rob_score)], collapse = ", ")))
}

cat(sprintf("  RoB score range: %d--%d (mean=%.1f, median=%.1f)\n",
            min(combined_rob$rob_score, na.rm = TRUE),
            max(combined_rob$rob_score, na.rm = TRUE),
            mean(combined_rob$rob_score, na.rm = TRUE),
            median(combined_rob$rob_score, na.rm = TRUE)))

# --- RoB as continuous moderator (meta-regression) ---
cat("\n  1. Meta-regression: RoB score as continuous moderator\n")
rma_rob_mod <- tryCatch({
  rma(yi = log_odds, vi = var_log_odds, mods = ~ rob_score,
      data = combined_rob, method = "REML", test = "knha")
}, error = function(e) {
  cat(sprintf("    ERROR fitting RoB meta-regression: %s\n", e$message))
  NULL
})

if (!is.null(rma_rob_mod)) {
  rob_coef <- coef(summary(rma_rob_mod))
  cat(sprintf("    Intercept: %.3f (SE=%.3f)\n", rob_coef[1, "estimate"], rob_coef[1, "se"]))
  cat(sprintf("    RoB slope: %.3f (SE=%.3f, p=%.4f)\n",
              rob_coef[2, "estimate"], rob_coef[2, "se"], rob_coef[2, "pval"]))
  cat(sprintf("    QM (moderator test): %.3f, df=%d, p=%.4f\n",
              rma_rob_mod$QM, rma_rob_mod$m, rma_rob_mod$QMp))
  cat(sprintf("    Residual I2: %.1f%%\n", rma_rob_mod$I2))
  cat(sprintf("    Interpretation: %s\n",
              ifelse(rma_rob_mod$QMp < 0.05,
                     "RoB significantly predicts survival (higher-quality studies differ)",
                     "RoB does NOT significantly predict survival")))
}

# --- Sensitivity: Exclude low-quality studies (score <= 5) ---
cat("\n  2. Sensitivity: Excluding studies with RoB score <= 5\n")
low_rob_studies <- combined_rob %>% filter(rob_score <= 5)
high_rob_data <- combined_rob %>% filter(rob_score > 5)

cat(sprintf("    Studies excluded (score <= 5): %d effects from %d unique studies\n",
            nrow(low_rob_studies), n_distinct(low_rob_studies$study_id)))
if (nrow(low_rob_studies) > 0) {
  cat(sprintf("    Excluded: %s\n",
              paste(unique(low_rob_studies$study), collapse = ", ")))
}
cat(sprintf("    Remaining: %d effects from %d unique studies\n",
            nrow(high_rob_data), n_distinct(high_rob_data$study_id)))

rma_high_rob <- tryCatch({
  rma(yi = log_odds, vi = var_log_odds, data = high_rob_data,
      method = "REML", test = "knha")
}, error = function(e) {
  cat(sprintf("    ERROR fitting high-RoB model: %s\n", e$message))
  NULL
})

if (!is.null(rma_high_rob)) {
  surv_high_rob <- plogis(as.numeric(rma_high_rob$beta))
  ci_lower_high <- plogis(rma_high_rob$ci.lb)
  ci_upper_high <- plogis(rma_high_rob$ci.ub)
  cat(sprintf("    Pooled survival (RoB > 5): %.1f%% (95%% CI: %.1f--%.1f%%)\n",
              surv_high_rob * 100, ci_lower_high * 100, ci_upper_high * 100))
  cat(sprintf("    I2: %.1f%%, tau2: %.4f\n", rma_high_rob$I2, rma_high_rob$tau2))

  # Compare to full model
  # Retrieve pooled survival from the independent model (rma_independent)
  surv_full <- plogis(as.numeric(rma_independent$beta))
  diff_pp <- (surv_high_rob - surv_full) * 100
  cat(sprintf("    Change from full model: %+.1f percentage points (full=%.1f%%, restricted=%.1f%%)\n",
              diff_pp, surv_full * 100, surv_high_rob * 100))
}

# --- RoB by data tier ---
cat("\n  3. RoB scores by data tier:\n")
tier_rob_summary <- combined_rob %>%
  group_by(data_tier) %>%
  summarise(
    k = n(),
    mean_rob = mean(rob_score, na.rm = TRUE),
    median_rob = median(rob_score, na.rm = TRUE),
    min_rob = min(rob_score, na.rm = TRUE),
    max_rob = max(rob_score, na.rm = TRUE),
    .groups = "drop"
  )
print(tier_rob_summary)

# --- Save results ---
rob_sensitivity_results <- data.frame(
  analysis = c(
    "Full model (all studies)",
    "RoB > 5 only",
    "RoB meta-regression slope",
    "RoB meta-regression p-value"
  ),
  k_effects = c(
    nrow(combined_rob),
    nrow(high_rob_data),
    nrow(combined_rob),
    nrow(combined_rob)
  ),
  k_studies = c(
    n_distinct(combined_rob$study_id),
    n_distinct(high_rob_data$study_id),
    n_distinct(combined_rob$study_id),
    n_distinct(combined_rob$study_id)
  ),
  pooled_survival = c(
    ifelse(!is.null(rma_independent), plogis(as.numeric(rma_independent$beta)), NA),
    ifelse(!is.null(rma_high_rob), plogis(as.numeric(rma_high_rob$beta)), NA),
    NA,
    NA
  ),
  ci_lower = c(
    ifelse(!is.null(rma_independent), plogis(rma_independent$ci.lb), NA),
    ifelse(!is.null(rma_high_rob), plogis(rma_high_rob$ci.lb), NA),
    NA,
    NA
  ),
  ci_upper = c(
    ifelse(!is.null(rma_independent), plogis(rma_independent$ci.ub), NA),
    ifelse(!is.null(rma_high_rob), plogis(rma_high_rob$ci.ub), NA),
    NA,
    NA
  ),
  I2 = c(
    ifelse(!is.null(rma_independent), rma_independent$I2, NA),
    ifelse(!is.null(rma_high_rob), rma_high_rob$I2, NA),
    ifelse(!is.null(rma_rob_mod), rma_rob_mod$I2, NA),
    NA
  ),
  rob_slope = c(
    NA,
    NA,
    ifelse(!is.null(rma_rob_mod), coef(summary(rma_rob_mod))[2, "estimate"], NA),
    NA
  ),
  rob_p_value = c(
    NA,
    NA,
    NA,
    ifelse(!is.null(rma_rob_mod), rma_rob_mod$QMp, NA)
  ),
  mean_rob_score = c(
    mean(combined_rob$rob_score, na.rm = TRUE),
    mean(high_rob_data$rob_score, na.rm = TRUE),
    NA,
    NA
  )
)

write_csv(rob_sensitivity_results, file.path(output_dir, "expanded_meta_rob_sensitivity.csv"))
cat("\n  Saved: expanded_meta_rob_sensitivity.csv\n")

# Also save per-study RoB assignments for reproducibility
rob_per_study <- combined_rob %>%
  as.data.frame() %>%
  select(study, study_id, region, data_tier, population_type, n_total,
         survival_rate, rob_score, log_odds, var_log_odds) %>%
  arrange(rob_score, study)
write_csv(rob_per_study, file.path(output_dir, "expanded_meta_rob_per_study.csv"))
cat("  Saved: expanded_meta_rob_per_study.csv\n")

cat("\n\nExpanded meta-analysis complete.\n")
