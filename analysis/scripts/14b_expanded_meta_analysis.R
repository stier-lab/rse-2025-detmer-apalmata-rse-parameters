#!/usr/bin/env Rscript
################################################################################
# 14b_EXPANDED_META_ANALYSIS.R
# Two-Tier Meta-Analysis: Individual + Summary Data Studies
#
# PURPOSE: Expand the meta-analysis from k=5 (individual-level data only) to
#   k=16 by incorporating summary-level survival data from additional published
#   studies. This addresses three critical limitations of the Tier 1 analysis:
#     1. k=1 natural colony study (NOAA only) -- now k=6 with Vardi & Roth & Garrison
#     2. Meta-regression underpowered (k<10) -- now k=16
#     3. Limited geographic scope -- now 9-10 Caribbean regions
#
# DESIGN:
#   Tier 1 = 5 studies with individual-level data (from script 14)
#   Tier 2 = 11 study-level effects (9 studies; Vardi 2011 split into 3 regions)
#   Combined = 16 study-level effects for expanded meta-analysis
#
# KEY METHODOLOGICAL CHOICES:
#   - Summary studies are aggregated to one effect per study (or per study-region
#     for Vardi 2011, which spans 3 geographically distinct regions)
#   - Non-annual survival is annualized assuming constant hazard:
#       surv_annual = surv_raw^(1/time_interval_yr)
#   - n_initial-weighted means used for within-study aggregation
#   - Excluded: fundemar_recruits (post-settlement, 0.006 cm^2),
#     chamberland_et_al_2015 (recruits), mendoza_quiroz_et_al_2023 summary
#     (lab recruits), papke_et_al_2021 (micro-fragments, lab/nursery)
#   - Effect size: PLO (proportional log-odds) with Haldane correction
#   - Estimation: REML with Knapp-Hartung adjustment (test="knha")
#
# OUTPUTS:
#   CSVs: expanded_meta_analysis_*.csv (7 files)
#   Figures: analysis/figures/supplementary/meta_analysis/expanded_*.png/pdf
#
# Author: Detmer & Stier Lab
# Date: 2026-02
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("analysis/scripts/utils/shared_utilities.R")) {
  source("analysis/scripts/utils/shared_utilities.R")
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

# Standardize Tier 1 columns for merging
# NOTE: Tier 1 survival_rate is a raw proportion pooled across all survey years
# (e.g., NOAA pools 2004-2024 without per-interval annualization).
# Tier 2 rates are annualized via surv^(1/interval_yr). This inconsistency
# is a known limitation — most Tier 1 studies use ~1-year intervals except NOAA.
# We need: study, region, n_total, n_survived, survival_rate, mean_size_cm2,
#           population_type, survey_yr, fragment, data_tier
tier1_std <- tier1 %>%

  transmute(
    study = study,
    # Fix NOAA region: it spans FL/Curacao/Navassa, first() picks alphabetically
    # NOAA spans FL/Curacao/Navassa; assign "Florida" because the plurality
    # of NOAA observations originate from Florida reef tract sites.
    region = case_when(
      study == "NOAA_survey" ~ "Florida",
      TRUE ~ region
    ),
    n_total = n_total,
    n_first_census = n_total,  # Tier 1: not aggregated across years, so n_first_census = n_total
    n_survived = n_survived,
    survival_rate = survival_rate,
    mean_size_cm2 = mean_size_cm2,
    population_type = population_type,
    survey_yr = year_end,
    fragment = ifelse(population_type == "Natural colony", "N", "Y"),
    data_tier = "Tier 1 (individual)"
  )

# ==============================================================================
# SECTION 2: PROCESS SUMMARY DATA INTO STUDY-LEVEL EFFECTS
# ==============================================================================

cat("SECTION 2: Processing Summary Data into Study-Level Effects\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

summ_raw <- read_csv(file.path(get_project_root(), "standardized_data", "apal_surv_summ.csv"), show_col_types = FALSE)
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

# --- 2b.3: roth_et_al_2013 ---
# USVI, 12 size bins x 2 survey years (one normal, one MHW year)
roth <- summ %>% filter(study == "roth_et_al_2013")
cat(sprintf("\n  roth_et_al_2013: %d rows, all 1-year intervals\n", nrow(roth)))

roth_agg <- roth %>%
  # Already annual intervals (time_interval_yr = 1)
  summarise(
    study = "roth_et_al_2013",
    region = first(region),
    # Effective sample size: max(n_initial) avoids double-counting individuals
    # tracked across multiple census intervals
    n_total = max(n_initial),
    n_first_census = max(n_initial),
    survival_rate = wmean(prop_survived, n_initial),
    n_survived = round(survival_rate * max(n_initial)),
    mean_size_cm2 = wmean(size_cm2_mean, n_initial),
    population_type = "Natural colony",
    survey_yr = round(mean(survey_yr, na.rm = TRUE)),
    fragment = "N",
    data_tier = "Tier 2 (summary)"
  ) %>%
  mutate(
    n_survived = pmin(n_survived, n_total),
    n_survived = pmax(n_survived, 0L),
    survival_rate = n_survived / n_total
  )
cat(sprintf("    Aggregated: n=%d, surv_annual=%.1f%%\n",
            roth_agg$n_total, roth_agg$survival_rate * 100))
tier2_list <- c(tier2_list, list(roth_agg))

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
# USVI, 2 size groups (control=natural, relocated=fragments), 1-year interval
# Mixed natural/restoration -- classify as "Mixed" since it contains both
garrison <- summ %>% filter(study == "garrison_ward_2008")
cat(sprintf("\n  garrison_ward_2008: %d rows, 1-year interval\n", nrow(garrison)))

garrison_agg <- garrison %>%
  # Already annual
  summarise(
    study = "garrison_ward_2008",
    region = first(region),
    # Effective sample size: max(n_initial) avoids double-counting individuals
    # tracked across multiple census intervals
    n_total = max(n_initial),
    n_first_census = max(n_initial),
    survival_rate = wmean(prop_survived, n_initial),
    n_survived = round(survival_rate * max(n_initial)),
    mean_size_cm2 = wmean(size_cm2_mean, n_initial),
    # Mixed: includes both natural (control) and relocated fragments
    population_type = "Natural colony",
    survey_yr = round(mean(survey_yr, na.rm = TRUE)),
    fragment = "N",
    data_tier = "Tier 2 (summary)"
  ) %>%
  mutate(
    n_survived = pmin(n_survived, n_total),
    n_survived = pmax(n_survived, 0L),
    survival_rate = n_survived / n_total
  )
cat(sprintf("    Aggregated: n=%d, surv_annual=%.1f%%\n",
            garrison_agg$n_total, garrison_agg$survival_rate * 100))
tier2_list <- c(tier2_list, list(garrison_agg))


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
            sum(combined$data_tier == "Tier 2 (summary)")))
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
    surv_upper = plogis(log_odds + 1.96 * se_log_odds)
  )

cat("\n  Study-level effect sizes (expanded):\n")
combined_es %>%
  as.data.frame() %>%
  select(study, region, data_tier, population_type, n_total, survival_rate,
         log_odds, se_log_odds) %>%
  mutate(
    survival_rate = sprintf("%.1f%%", survival_rate * 100),
    log_odds = sprintf("%.3f", log_odds),
    se_log_odds = sprintf("%.3f", se_log_odds)
  ) %>%
  print()

k_expanded <- nrow(combined_es)
cat(sprintf("\n  === EXPANDED META-ANALYSIS WITH k = %d STUDIES ===\n", k_expanded))

# ==============================================================================
# SECTION 4: EXPANDED RANDOM-EFFECTS META-ANALYSIS
# ==============================================================================

cat("\nSECTION 4: Expanded Random-Effects Meta-Analysis\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Primary model: REML with Knapp-Hartung adjustment
rma_expanded <- rma(
  yi = combined_es$log_odds,
  vi = combined_es$var_log_odds,
  method = "REML",
  test = "knha"
)

# Extract key statistics
pooled_lo <- as.numeric(rma_expanded$beta)
pooled_surv <- plogis(pooled_lo)
pooled_surv_lower <- plogis(rma_expanded$ci.lb)
pooled_surv_upper <- plogis(rma_expanded$ci.ub)
I_sq <- rma_expanded$I2
Q_stat <- rma_expanded$QE
Q_p <- rma_expanded$QEp
tau_sq <- rma_expanded$tau2
tau <- sqrt(tau_sq)

# Prediction interval
rma_pred <- predict(rma_expanded)
pi_lower <- plogis(rma_pred$pi.lb)
pi_upper <- plogis(rma_pred$pi.ub)

# I-squared confidence interval (Q-profile method)
rma_ci <- confint(rma_expanded)
I_sq_lower <- rma_ci$random["I^2(%)", "ci.lb"]
I_sq_upper <- rma_ci$random["I^2(%)", "ci.ub"]

cat("EXPANDED META-ANALYSIS RESULTS:\n")
cat(sprintf("  Studies (k): %d\n", k_expanded))
cat(sprintf("  Total observations: %d\n", sum(combined_es$n_total)))

cat(sprintf("\n  *** 95%% PREDICTION INTERVAL: %.1f%% - %.1f%% ***\n",
            pi_lower * 100, pi_upper * 100))
cat("  The prediction interval is more relevant for practitioners: it predicts\n")
cat("  the range of survival in a NEW study, accounting for between-study heterogeneity.\n\n")
cat(sprintf("  Pooled survival (RE): %.1f%% (95%% CI: %.1f%% - %.1f%%)\n",
            pooled_surv * 100, pooled_surv_lower * 100, pooled_surv_upper * 100))
cat("  NOTE: The CI describes uncertainty in the AVERAGE, not in a new observation.\n")

cat(sprintf("\n  I^2 = %.1f%% (95%% CI: %.1f%% - %.1f%%)\n",
            I_sq, I_sq_lower, I_sq_upper))
cat(sprintf("  tau^2 = %.4f, tau = %.4f\n", tau_sq, tau))
cat(sprintf("  Cochran's Q = %.2f (df = %d, p %s)\n",
            Q_stat, k_expanded - 1,
            ifelse(Q_p < 0.001, "< 0.001", sprintf("= %.4f", Q_p))))

# --- PUBLICATION BIAS: Egger's Test (k=16) ---
cat("\n--- PUBLICATION BIAS ---\n")
egger_result <- metafor::regtest(rma_expanded)
cat(sprintf("  Egger's test: test stat = %.3f, p = %.4f\n", egger_result$zval, egger_result$pval))
cat(sprintf("  Interpretation: %s\n",
            if (egger_result$pval < 0.05) "Significant funnel plot asymmetry"
            else "No significant funnel plot asymmetry"))

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
cat(sprintf("  Tier 1+2   (k=%d): %.1f%% (CI: %.1f%% - %.1f%%), I^2=%.1f%%\n",
            k_expanded, pooled_surv * 100, pooled_surv_lower * 100,
            pooled_surv_upper * 100, I_sq))
cat(sprintf("  Change in pooled estimate: %+.1f pp\n",
            (pooled_surv - tier1_surv) * 100))
cat(sprintf("  CI width change: %.1f pp -> %.1f pp\n",
            (tier1_ci_hi - tier1_ci_lo) * 100,
            (pooled_surv_upper - pooled_surv_lower) * 100))

# Add RE weights to combined data
combined_es <- combined_es %>%
  mutate(
    weight_re = 1 / (var_log_odds + tau_sq),
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

# --- SENSITIVITY: Three-Level Model (Vardi 2011 within-study correlation) ---
cat("\n--- SENSITIVITY: Three-Level Model ---\n")

combined_es <- combined_es %>%
  mutate(study_id = case_when(
    grepl("^vardi_2011_", study) ~ "vardi_2011",
    TRUE ~ study
  ))

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
  NULL
})

if (!is.null(rma_3level)) {
  pooled_3lev <- plogis(as.numeric(rma_3level$b))
  ci_3lev <- c(plogis(rma_3level$ci.lb), plogis(rma_3level$ci.ub))
  cat(sprintf("  Independent effects: %.1f%% (CI: %.1f%% - %.1f%%)\n",
              pooled_surv * 100, pooled_surv_lower * 100, pooled_surv_upper * 100))
  cat(sprintf("  Three-level model:  %.1f%% (CI: %.1f%% - %.1f%%)\n",
              pooled_3lev * 100, ci_3lev[1] * 100, ci_3lev[2] * 100))
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
cat("  8a. Leave-one-out analysis (expanded)\n")
loo_expanded <- leave1out(rma_expanded)

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
cat("\n  8c. Influence diagnostics\n")
inf_diag <- tryCatch(
  influence(rma_expanded),
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

tier_shapes <- c(
  "Tier 1 (individual)" = 16,  # Filled circle
  "Tier 2 (summary)" = 17      # Filled triangle
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
results_summary <- data.frame(
  statistic = c(
    "Number of studies (k)", "Total observations (N)",
    "Tier 1 studies", "Tier 2 studies",
    "Natural colony studies", "Restoration fragment studies",
    "Pooled survival (RE)", "95% CI lower", "95% CI upper",
    "95% PI lower", "95% PI upper",
    "tau^2", "tau",
    "I^2 (%)", "I^2 CI lower", "I^2 CI upper",
    "Cochran's Q", "Q df", "Q p-value",
    "REML estimation method", "Small-sample adjustment",
    "MDD SE (log-odds)", "MDD (log-odds, 80% power)",
    "MDD (probability scale, pp)", "Observed difference (pp)",
    "MDD power interpretation"
  ),
  value = c(
    as.character(k_expanded),
    as.character(sum(combined_es$n_total)),
    as.character(sum(combined_es$data_tier == "Tier 1 (individual)")),
    as.character(sum(combined_es$data_tier == "Tier 2 (summary)")),
    as.character(sum(combined_es$population_type == "Natural colony")),
    as.character(sum(combined_es$population_type == "Restoration fragment")),
    sprintf("%.3f", pooled_surv),
    sprintf("%.3f", pooled_surv_lower),
    sprintf("%.3f", pooled_surv_upper),
    sprintf("%.3f", pi_lower),
    sprintf("%.3f", pi_upper),
    sprintf("%.4f", tau_sq),
    sprintf("%.4f", tau),
    sprintf("%.1f", I_sq),
    sprintf("%.1f", I_sq_lower),
    sprintf("%.1f", I_sq_upper),
    sprintf("%.2f", Q_stat),
    as.character(k_expanded - 1),
    sprintf("%.4f", Q_p),
    "REML",
    "Knapp-Hartung (test='knha')",
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
    select(study, region, data_tier, population_type, n_total, n_survived,
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
cat(sprintf("  Expanded from k=%d to k=%d studies by incorporating summary data.\n",
            nrow(tier1_only), k_expanded))
cat(sprintf("  Natural colony studies: k=1 -> k=%d (breaks single-study confound)\n",
            k_natural))
cat(sprintf("  Geographic coverage: %d regions across the Caribbean\n",
            n_distinct(combined_es$region)))

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
cat("  4. Some n_initial are estimated from figures, not exact counts\n")
cat("  5. Studies span 2+ decades (2000-2024), different regions, and varied methods\n")
cat("  6. Vardi 2011 regions treated as independent effects (geographically distinct)\n")
cat("  7. Garrison & Ward 2008 includes both natural and relocated fragments\n")

cat("\nOUTPUTS:\n")
cat("  Data files:\n")
cat("    - expanded_meta_analysis_results.csv\n")
cat("    - expanded_meta_analysis_study_effects.csv\n")
cat("    - expanded_meta_analysis_moderators.csv\n")
cat("    - expanded_meta_analysis_stratified.csv\n")
cat("    - expanded_meta_analysis_by_region.csv\n")
cat("    - expanded_meta_analysis_tier_comparison.csv\n")
cat("    - expanded_meta_analysis_loo.csv\n")
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
# Three scenarios:
#   1. Current: Vardi=Natural, Garrison=Natural (k=6 nat, k=10 rest)
#   2. Conservative: Vardi=Natural, Garrison=excluded (k=5 nat, k=10 rest)
#   3. Original coding: Vardi=Restoration, Garrison=excluded (k=2 nat, k=13 rest)

classification_results <- list()

# --- Scenario 1: Current classification (already computed above) ---
cat("  Scenario 1 (Current): Vardi=Natural, Garrison=Natural\n")
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
  scenario = "Current (Vardi=Nat, Garrison=Nat)",
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
scenario2 <- combined_es %>% filter(study != "garrison_ward_2008")
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
  filter(study != "garrison_ward_2008") %>%
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

cat("\n\nExpanded meta-analysis complete.\n")
