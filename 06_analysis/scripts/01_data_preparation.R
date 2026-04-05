#!/usr/bin/env Rscript
################################################################################
# 01_DATA_PREPARATION.R
# A. palmata Demographic Analysis - Data Loading and Preparation
################################################################################
#
# PURPOSE: Load, clean, and prepare A. palmata demographic data for analysis
#          Creates standardized size classes and data quality summaries
#
# INPUTS:
#   - 05_data/standardized/apal_surv_ind.csv (individual survival data)
#   - 05_data/standardized/apal_growth_ind.csv (individual growth data)
#   - 05_data/standardized/apal_surv_summ.csv (summarized survival data)
#
# OUTPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#   - 06_analysis/output/standardized_data_inventory.csv
#   - 06_analysis/output/summary_survival_by_size.csv
#   - 06_analysis/output/summary_growth_by_size.csv
#   - 06_analysis/output/summary_survival_by_region.csv
#   - 06_analysis/output/summary_growth_by_region.csv
#   - 06_analysis/output/summary_survival_by_datatype.csv
#   - 06_analysis/output/summary_temporal_coverage.csv
#   - 06_analysis/output/data_filtering_audit.csv
#   - 06_analysis/output/size_class_distribution.csv
#   - 06_analysis/output/impossible_growth_summary.csv
#   - 06_analysis/output/observation_intervals.csv
#   - 06_analysis/output/study_metadata.csv
#
# CRITICAL SIZE VARIABLE NOTES:
# -----------------------------
# Raw data contains two size columns:
#   - size_cm2:      Total colony footprint (length × width)
#   - size_live_cm2: Live tissue area (length × width × fraction alive)
#
# For biological analyses, LIVE TISSUE AREA is the meaningful metric because:
#   1. Partially dead colonies (e.g., 5000 cm² total but 200 cm² alive) behave
#      like small colonies for survival/growth, not like large adults
#   2. Using total size misclassifies stressed colonies as SC5 "large adults"
#   3. This caused an artificial survival "drop" in large size classes
#
# This script standardizes size variables as follows:
#   - size_for_class: Live tissue area (used for size class assignment)
#   - size_cm2:       OVERWRITTEN with live tissue for downstream compatibility
#   - size_total_cm2: Original total colony size (preserved for reference)
#   - size_live_cm2:  Original live tissue column (unchanged)
#
# Author: Detmer & Stier Lab
# Date: 2025-12-22
# Updated: 2025-12-28 (fixed size variable handling)
################################################################################

# Load required packages
library(dplyr)
library(tidyr)
library(readr)

# Source shared utilities for constants and helper functions
# find_project_root() is defined here, along with SIZE_BREAKS, SIZE_LABELS, etc.
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  01: DATA PREPARATION FOR A. PALMATA DEMOGRAPHIC ANALYSIS    ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# Set paths - detect project root automatically
# Works when run from project root or analysis/scripts directory
if (file.exists("05_data/standardized")) {
  project_root <- "."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root. Run from project directory or 06_analysis/scripts/")
}

data_dir <- file.path(project_root, "05_data/standardized")
output_dir <- file.path(project_root, "06_analysis/output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Validate canonical standardized inputs against the data registry
registry <- read_data_registry(project_root)
standardized_inventory <- validate_registry_inputs(
  project_root = project_root,
  registry = registry,
  roles = c("canonical_input", "curated_support")
)
write_csv(
  standardized_inventory,
  file.path(output_dir, "standardized_data_inventory.csv")
)

cat("Validated standardized inputs against data registry.\n")
cat(sprintf("  Registry entries: %d\n", nrow(registry)))
cat(sprintf("  Inventory snapshot written: %s\n\n",
            file.path("06_analysis/output", "standardized_data_inventory.csv")))

# Initialize filtering audit trail
filtering_audit <- data.frame(
  stage = character(),
  dataset = character(),
  n_before = integer(),
  n_removed = integer(),
  n_after = integer(),
  reason = character(),
  stringsAsFactors = FALSE
)

# =============================================================================
# 1. LOAD RAW DATA
# =============================================================================

cat("Loading data files...\n")

# Individual survival data
surv_ind <- read_csv(file.path(data_dir, "apal_surv_ind.csv"),
                     show_col_types = FALSE)
# Remove row index column if present (legacy CSV format)
if (names(surv_ind)[1] %in% c("...1", "X1", "")) surv_ind <- surv_ind %>% select(-1)

cat(sprintf("  Survival (individual): %d records\n", nrow(surv_ind)))
n_surv_loaded <- nrow(surv_ind)
filtering_audit <- rbind(filtering_audit, data.frame(
  stage = "load_raw", dataset = "survival", n_before = n_surv_loaded,
  n_removed = 0L, n_after = n_surv_loaded, reason = "Raw data loaded"))

# Duplicate detection: flag and remove exact duplicates
surv_dupes <- surv_ind %>%
  group_by(study, coral_id, survey_yr, location) %>%
  filter(n() > 1) %>%
  ungroup()
if (nrow(surv_dupes) > 0) {
  cat(sprintf("  WARNING: %d potential duplicate survival records detected — deduplicating\n", nrow(surv_dupes)))
  n_before_dedup_surv <- nrow(surv_ind)
  surv_ind <- surv_ind %>% distinct(study, coral_id, survey_yr, location, .keep_all = TRUE)
  cat(sprintf("  After deduplication: %d records\n", nrow(surv_ind)))
  filtering_audit <- rbind(filtering_audit, data.frame(
    stage = "deduplication", dataset = "survival", n_before = n_before_dedup_surv,
    n_removed = n_before_dedup_surv - nrow(surv_ind), n_after = nrow(surv_ind),
    reason = "Exact duplicate removal (study, coral_id, survey_yr, location)"))
} else {
  cat("  No duplicate survival records detected\n")
  filtering_audit <- rbind(filtering_audit, data.frame(
    stage = "deduplication", dataset = "survival", n_before = nrow(surv_ind),
    n_removed = 0L, n_after = nrow(surv_ind), reason = "No duplicates found"))
}

# Individual growth data
growth_ind <- read_csv(file.path(data_dir, "apal_growth_ind.csv"),
                       show_col_types = FALSE)
if (names(growth_ind)[1] %in% c("...1", "X1", "")) growth_ind <- growth_ind %>% select(-1)

cat(sprintf("  Growth (individual): %d records\n", nrow(growth_ind)))
n_growth_loaded <- nrow(growth_ind)
filtering_audit <- rbind(filtering_audit, data.frame(
  stage = "load_raw", dataset = "growth", n_before = n_growth_loaded,
  n_removed = 0L, n_after = n_growth_loaded, reason = "Raw data loaded"))

# Duplicate detection for growth data
growth_dupes <- growth_ind %>%
  group_by(study, coral_id, survey_yr, location) %>%
  filter(n() > 1) %>%
  ungroup()
if (nrow(growth_dupes) > 0) {
  cat(sprintf("  WARNING: %d potential duplicate growth records detected — deduplicating\n", nrow(growth_dupes)))
  n_before_dedup_growth <- nrow(growth_ind)
  growth_ind <- growth_ind %>% distinct(study, coral_id, survey_yr, location, .keep_all = TRUE)
  cat(sprintf("  After deduplication: %d records\n", nrow(growth_ind)))
  filtering_audit <- rbind(filtering_audit, data.frame(
    stage = "deduplication", dataset = "growth", n_before = n_before_dedup_growth,
    n_removed = n_before_dedup_growth - nrow(growth_ind), n_after = nrow(growth_ind),
    reason = "Exact duplicate removal (study, coral_id, survey_yr, location)"))
} else {
  cat("  No duplicate growth records detected\n")
  filtering_audit <- rbind(filtering_audit, data.frame(
    stage = "deduplication", dataset = "growth", n_before = nrow(growth_ind),
    n_removed = 0L, n_after = nrow(growth_ind), reason = "No duplicates found"))
}

# Summarized survival data (if exists)
surv_summ_file <- file.path(data_dir, "apal_surv_summ.csv")
if (file.exists(surv_summ_file)) {
  surv_summ <- read_csv(surv_summ_file, show_col_types = FALSE)
  if (names(surv_summ)[1] %in% c("...1", "X1", "")) surv_summ <- surv_summ %>% select(-1)
  cat(sprintf("  Survival (summary): %d records\n", nrow(surv_summ)))
} else {
  surv_summ <- NULL
  cat("  Survival (summary): not found\n")
}

cat("\n")

# =============================================================================
# 2. DEFINE SIZE CLASSES
# =============================================================================

cat("Defining size classes...\n\n")

# Size class definitions (in cm²) following Vardi (2011) boundaries
# SC1: Recruits/settlers (<10 cm²) - Very small, high mortality
# SC2: Small juveniles (10-100 cm²) - Establishing
# SC3: Large juveniles (100-900 cm²) - Growing phase
# SC4: Subadults (900-4000 cm²) - Approaching reproductive threshold
# SC5: Reproductive adults (>4000 cm²) - Full reproductive capacity

# Canonical size class labels - must match across all pipeline scripts
size_breaks <- c(0, 10, 100, 900, 4000, Inf)
size_labels <- c("SC1", "SC2", "SC3", "SC4", "SC5")

# Alternative: log-scale size for continuous analysis
# log_size will be used for threshold detection

cat("Size class definitions:\n")
cat("  SC1 (Recruit):      <10 cm²\n")
cat("  SC2 (Small Juv):    10-100 cm²\n")
cat("  SC3 (Large Juv):    100-900 cm²\n")
cat("  SC4 (Subadult):     900-4000 cm²\n")
cat("  SC5 (Adult):        >4000 cm²\n\n")

# =============================================================================
# 3. PREPARE SURVIVAL DATA
# =============================================================================

cat("Preparing survival data...\n")

# IMPORTANT: Use size_live_cm2 (live tissue area) for size class assignment
# This is biologically more meaningful than total colony size (size_cm2)
# because partially dead colonies with large total area but small live tissue
# behave like smaller colonies for survival purposes

# Validate survived is binary before coercion
stopifnot("survived values must be 0 or 1" = all(surv_ind$survived %in% c(0, 1, NA)))

surv_clean <- surv_ind %>%
  # Prefer size_live_cm2; fall back to size_cm2 if not available
  mutate(
    size_for_class = coalesce(size_live_cm2, size_cm2),
    size_measurement_type = if_else(!is.na(size_live_cm2), "live_tissue", "total_colony"),
    # Preserve original total colony size for reference
    size_total_cm2 = size_cm2
  ) %>%
  # Remove missing size values
  filter(!is.na(size_for_class), size_for_class > 0) %>%
  # Create size class based on LIVE tissue area
  mutate(
    size_class = cut(size_for_class,
                     breaks = size_breaks,
                     labels = size_labels,
                     include.lowest = TRUE),
    # Log-transformed size for threshold analysis (use live tissue)
    log_size = log(size_for_class),
    # IMPORTANT: Replace size_cm2 with live tissue size for downstream consistency
    # Downstream scripts that use size_cm2 will now get the biologically meaningful value
    size_cm2 = size_for_class,
    # Ensure survived is binary
    survived = as.integer(survived),
    # Create region-year identifier
    region_year = paste(region, survey_yr, sep = "_"),
    # Data type factor
    data_type = factor(data_type, levels = c("field", "nursery_in")),
    # Fragment status - critical for stratified analysis
    # Y = outplanted fragment, N = natural colony
    is_fragment = (fragment == "Y"),
    # Population type for stratification
    population_type = ifelse(is_fragment, "Restoration fragment", "Natural colony"),
    # Mortality definition varies by study (see docs/Data_Methodology_Reference.md)
    mortality_definition = case_when(
      study == "NOAA_survey" ~ "no_tissue_or_skeleton",
      study == "kuffner_et_al_2020" ~ "gte_50pct_tissue_loss",
      study == "pausch_et_al_2018" ~ "complete_mortality_or_missing",
      study == "USGS_USVI_exp" ~ "no_live_tissue",
      study == "mendoza_quiroz_et_al_2023" ~ "no_live_tissue",
      study == "fundemar_fragments" ~ "no_live_tissue",
      TRUE ~ "unknown"
    )
  ) %>%
  # Remove any records with missing survival
  filter(!is.na(survived))

cat(sprintf("  Records after cleaning: %d (removed %d)\n",
            nrow(surv_clean), nrow(surv_ind) - nrow(surv_clean)))
filtering_audit <- rbind(filtering_audit, data.frame(
  stage = "cleaning", dataset = "survival", n_before = nrow(surv_ind),
  n_removed = nrow(surv_ind) - nrow(surv_clean), n_after = nrow(surv_clean),
  reason = "Remove missing/zero size and missing survival"))

# Summary by size class
size_summary <- surv_clean %>%
  group_by(size_class) %>%
  summarise(
    n = n(),
    n_survived = sum(survived),
    survival_rate = mean(survived),
    mean_size = mean(size_cm2),
    .groups = "drop"
  )

cat("\nSurvival by size class:\n")
print(as.data.frame(size_summary))

cat("\n--- MORTALITY DEFINITION AUDIT ---\n")
mort_audit <- surv_clean %>% count(study, mortality_definition)
print(as.data.frame(mort_audit))
cat("  NOTE: Kuffner uses >=50% tissue loss (more liberal than other studies)\n")

# --- FLAG SUB-ANNUAL INTERVALS ---
if ("time_interval_yr" %in% names(surv_clean)) {
  surv_clean <- surv_clean %>%
    mutate(
      sub_annual_interval = is_sub_annual(time_interval_yr)
    )

  n_sub <- sum(surv_clean$sub_annual_interval, na.rm = TRUE)
  cat(sprintf("\n  Sub-annual interval records: %d (%.1f%%)\n",
              n_sub, n_sub / nrow(surv_clean) * 100))

  if (n_sub > 0) {
    sub_summary <- surv_clean %>%
      filter(sub_annual_interval) %>%
      group_by(study) %>%
      summarise(n = n(), mean_interval = mean(time_interval_yr, na.rm = TRUE),
                surv_rate = mean(survived), .groups = "drop")
    print(as.data.frame(sub_summary))
    cat("  WARNING: Sub-annual survivors may inflate annual survival estimates.\n")
    cat("  Downstream scripts should consider filtering on sub_annual_interval.\n")
  }

  # Compute annualized survival for sub-annual intervals

  # Assumes constant hazard: S_annual = S_observed^(1/t) where t is interval in years
  surv_clean <- surv_clean %>%
    mutate(
      surv_annualized = ifelse(
        sub_annual_interval & !is.na(time_interval_yr) & time_interval_yr > 0,
        as.numeric(survived)^(1/time_interval_yr),
        as.numeric(survived)
      )
    )

  n_annualized <- sum(surv_clean$surv_annualized != surv_clean$survived, na.rm = TRUE)
  cat(sprintf("  Annualized survival computed for %d sub-annual records (constant-hazard assumption)\n",
              n_annualized))
} else {
  surv_clean$sub_annual_interval <- FALSE
  surv_clean$surv_annualized <- as.numeric(surv_clean$survived)
}

# =============================================================================
# 4. PREPARE GROWTH DATA
# =============================================================================

cat("\nPreparing growth data...\n")

# IMPORTANT: Use size_live_cm2 (live tissue area) for size class assignment
# Same rationale as survival data - live tissue is more biologically meaningful

growth_clean <- growth_ind %>%
  # Prefer size_live_cm2; fall back to size_cm2 if not available
  mutate(
    size_for_class = coalesce(size_live_cm2, size_cm2),
    size_measurement_type = if_else(!is.na(size_live_cm2), "live_tissue", "total_colony"),
    # Preserve original total colony size for reference
    size_total_cm2 = size_cm2
  ) %>%
  # Remove missing size values
  filter(!is.na(size_for_class), size_for_class > 0,
         !is.na(growth_cm2_yr)) %>%
  mutate(
    size_class = cut(size_for_class,
                     breaks = size_breaks,
                     labels = size_labels,
                     include.lowest = TRUE),
    log_size = log(size_for_class),
    # IMPORTANT: Replace size_cm2 with live tissue size for downstream consistency
    size_cm2 = size_for_class,
    # RGR calculation: numerator uses live-tissue growth when available.
    # For NOAA, growth_live_cm2_yr tracks live tissue change; growth_cm2_yr tracks total skeleton.
    # coalesce ensures consistency: live tissue preferred, total skeleton as fallback.
    # size_for_class already uses coalesce(size_live_cm2, size_cm2)
    # Coalesced growth metric: prefer live tissue growth, fall back to total colony growth
    growth_metric = coalesce(growth_live_cm2_yr, growth_cm2_yr),
    rgr = growth_metric / size_for_class,
    rgr_source = if_else(!is.na(growth_live_cm2_yr), "growth_live_cm2_yr", "growth_cm2_yr"),
    # Growth category — uses coalesced metric for consistency with RGR
    growth_type = case_when(
      growth_metric < -10 ~ "shrinkage",
      growth_metric >= -10 & growth_metric <= 10 ~ "stable",
      growth_metric > 10 ~ "growth"
    ),
    region_year = paste(region, survey_yr, sep = "_"),
    data_type = factor(data_type, levels = c("field", "nursery_in"))
  )

# =============================================================================
# 4a. FLAG BIOLOGICALLY IMPOSSIBLE GROWTH VALUES
# =============================================================================
# DATA QUALITY NOTE (2024-12-29):
# Analysis identified 300 records (6.9% of growth data) with biologically
# impossible values where tissue loss exceeds the colony's initial size.
# These appear to be measurement/data entry errors primarily from NOAA survey.
#
# Criteria: coalesce(growth_live_cm2_yr, growth_cm2_yr) checked against size_for_class * 1.1
# (allowing 10% tolerance for measurement uncertainty)
#
# These records are FLAGGED but NOT removed in data preparation to allow
# downstream scripts to decide how to handle them. Scripts using growth data
# should filter on impossible_growth == FALSE for corrected analyses.

growth_clean <- growth_clean %>%
  mutate(
    # Use the same coalesced growth metric as RGR computation (growth_metric)
    # so the flag catches impossible values in the metric actually used downstream
    growth_for_check = coalesce(growth_live_cm2_yr, growth_cm2_yr),
    # Flag biologically impossible growth using centralized function
    impossible_growth = is_impossible_growth(growth_for_check, size_for_class)
  )

n_impossible <- sum(growth_clean$impossible_growth, na.rm = TRUE)
cat(sprintf("  ⚠ FLAGGED %d records (%.1f%%) with impossible growth values\n",
            n_impossible, n_impossible / nrow(growth_clean) * 100))
cat("    (tissue loss exceeds initial colony size - likely measurement errors)\n")

# =============================================================================
# 4b. FLAG HIGH-VARIANCE GROWTH REGIONS
# =============================================================================
# DATA QUALITY NOTE (2025-01-21):
# Navassa region has unusually high mean growth (826 cm²/yr vs ~50-100 expected)
# ... [rest of comments unchanged] ...

growth_clean <- growth_clean %>%
  mutate(
    # Flag high-variance regions using centralized function
    high_variance_region = is_high_variance_region(region)
  )

n_high_var <- sum(growth_clean$high_variance_region, na.rm = TRUE)
high_variance_regions <- sort(unique(growth_clean$region[growth_clean$high_variance_region]))
cat(sprintf("\n  ⚠ FLAGGED %d records (%.1f%%) from high-variance regions (%s)\n",
            n_high_var, n_high_var / nrow(growth_clean) * 100,
            paste(high_variance_regions, collapse = ", ")))
cat("    (legitimate data but requires careful interpretation - use median)\n")

# Report by study
if (n_impossible > 0) {
  impossible_by_study <- growth_clean %>%
    filter(impossible_growth) %>%
    count(study, name = "n_impossible") %>%
    arrange(desc(n_impossible))
  cat("\n  Impossible values by study:\n")
  print(as.data.frame(impossible_by_study))
}

cat(sprintf("  Records after cleaning: %d (removed %d)\n",
            nrow(growth_clean), nrow(growth_ind) - nrow(growth_clean)))
filtering_audit <- rbind(filtering_audit, data.frame(
  stage = "cleaning", dataset = "growth", n_before = nrow(growth_ind),
  n_removed = nrow(growth_ind) - nrow(growth_clean), n_after = nrow(growth_clean),
  reason = "Remove missing/zero size and missing growth"))
filtering_audit <- rbind(filtering_audit, data.frame(
  stage = "impossible_flagging", dataset = "growth", n_before = nrow(growth_clean),
  n_removed = n_impossible, n_after = nrow(growth_clean) - n_impossible,
  reason = "Flagged impossible growth (not removed, flag only)"))

cat("\n--- RGR SOURCE AUDIT ---\n")
rgr_audit <- growth_clean %>% count(study, rgr_source)
print(as.data.frame(rgr_audit))

# Summary by size class (ALL DATA - includes impossible values)
growth_summary_all <- growth_clean %>%
  group_by(size_class) %>%
  summarise(
    n = n(),
    mean_growth = mean(growth_cm2_yr, na.rm = TRUE),
    sd_growth = sd(growth_cm2_yr, na.rm = TRUE),
    pct_negative = mean(growth_cm2_yr < 0, na.rm = TRUE) * 100,
    mean_rgr = mean(rgr, na.rm = TRUE),
    .groups = "drop"
  )

cat("\nGrowth by size class (ALL DATA - includes impossible values):\n")
print(as.data.frame(growth_summary_all))

# Summary by size class (CORRECTED - excludes impossible values)
growth_summary <- growth_clean %>%
  filter(!impossible_growth) %>%
  group_by(size_class) %>%
  summarise(
    n = n(),
    mean_growth = mean(growth_cm2_yr, na.rm = TRUE),
    median_growth = median(growth_cm2_yr, na.rm = TRUE),
    sd_growth = sd(growth_cm2_yr, na.rm = TRUE),
    pct_positive = mean(growth_cm2_yr > 0, na.rm = TRUE) * 100,
    pct_negative = mean(growth_cm2_yr < 0, na.rm = TRUE) * 100,
    mean_rgr = mean(rgr, na.rm = TRUE),
    .groups = "drop"
  )

cat("\nGrowth by size class (CORRECTED - excludes impossible values):\n")
print(as.data.frame(growth_summary))
cat("  → Use CORRECTED values for publication and stakeholder reports\n")

# =============================================================================
# 5. GEOGRAPHIC AND TEMPORAL COVERAGE SUMMARY
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  DATA COVERAGE SUMMARY\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Geographic coverage - Survival
geo_surv <- surv_clean %>%
  group_by(region) %>%
  summarise(
    n_observations = n(),
    n_studies = n_distinct(study),
    n_sites = n_distinct(location),
    year_range = paste(min(survey_yr), max(survey_yr), sep = "-"),
    mean_survival = mean(survived),
    .groups = "drop"
  ) %>%
  arrange(desc(n_observations))

cat("SURVIVAL - Geographic coverage:\n")
print(as.data.frame(geo_surv))

# Geographic coverage - Growth
geo_growth <- growth_clean %>%
  group_by(region) %>%
  summarise(
    n_observations = n(),
    n_studies = n_distinct(study),
    n_sites = n_distinct(location),
    year_range = paste(min(survey_yr), max(survey_yr), sep = "-"),
    mean_growth = mean(growth_cm2_yr),
    .groups = "drop"
  ) %>%
  arrange(desc(n_observations))

cat("\nGROWTH - Geographic coverage:\n")
print(as.data.frame(geo_growth))

# Data type breakdown
dtype_surv <- surv_clean %>%
  group_by(data_type) %>%
  summarise(
    n = n(),
    pct = n() / nrow(surv_clean) * 100,
    mean_survival = mean(survived),
    .groups = "drop"
  )

cat("\nSURVIVAL - By data type:\n")
print(as.data.frame(dtype_surv))

# Temporal coverage
temporal <- surv_clean %>%
  group_by(survey_yr) %>%
  summarise(
    n_survival = n(),
    .groups = "drop"
  ) %>%
  left_join(
    growth_clean %>%
      group_by(survey_yr) %>%
      summarise(n_growth = n(), .groups = "drop"),
    by = "survey_yr"
  ) %>%
  arrange(survey_yr)

cat("\nTemporal coverage (year-by-year):\n")
cat(sprintf("  Year range: %d - %d\n", min(temporal$survey_yr), max(temporal$survey_yr)))
cat(sprintf("  Years with data: %d\n", nrow(temporal)))

# =============================================================================
# 6. DATA QUALITY FLAGS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  DATA QUALITY ASSESSMENT\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Size class sample size assessment
sample_sizes <- surv_clean %>%
  group_by(size_class, region) %>%
  summarise(n = n(), .groups = "drop") %>%
  pivot_wider(names_from = region, values_from = n, values_fill = 0)

# Flag low sample sizes
cat("Size class × Region sample sizes:\n")
print(as.data.frame(sample_sizes))

# Identify data gaps
cat("\nDATA GAP IDENTIFICATION:\n")

# Size class gaps
sc_total <- surv_clean %>%
  group_by(size_class) %>%
  summarise(n = n(), .groups = "drop")

for (i in 1:nrow(sc_total)) {
  if (sc_total$n[i] < 100) {
    cat(sprintf("  ⚠ LOW: %s has only %d observations\n",
                sc_total$size_class[i], sc_total$n[i]))
  }
}

# Regional gaps
regions_needed <- c("Florida Keys", "Bahamas", "Puerto Rico", "USVI", "Jamaica")
regions_present <- unique(surv_clean$region)
missing_regions <- setdiff(regions_needed, regions_present)
if (length(missing_regions) > 0) {
  cat(sprintf("  ⚠ MISSING REGIONS: %s\n", paste(missing_regions, collapse = ", ")))
}

# =============================================================================
# 7. INTEGRATE DISTURBANCE TIMELINE
# =============================================================================

cat("\nIntegrating disturbance timeline...\n")

# Load new disturbance timeline
timeline_file <- file.path(data_dir, "apal_disturbance_stressor_timeline.csv")
if (file.exists(timeline_file)) {
  timeline <- read_csv(timeline_file, show_col_types = FALSE)

  surv_clean <- attach_disturbance_timeline(
    surv_clean,
    timeline,
    region_col = "region",
    year_col = "survey_yr",
    interval_col = "time_interval_yr",
    legacy_col = "disturbance"
  )

  growth_clean <- attach_disturbance_timeline(
    growth_clean,
    timeline,
    region_col = "region",
    year_col = "survey_yr",
    interval_col = "time_interval_yr",
    legacy_col = "disturbance"
  )

  cat(sprintf("  ✓ Timeline-linked survival rows: %d\n",
              sum(surv_clean$timeline_event_count > 0, na.rm = TRUE)))
  cat(sprintf("  ✓ Timeline-linked growth rows: %d\n",
              sum(growth_clean$timeline_event_count > 0, na.rm = TRUE)))
  cat(sprintf("  ✓ Baseline-exclusion survival rows: %d\n",
              sum(surv_clean$exclude_from_baseline, na.rm = TRUE)))
  cat(sprintf("  ✓ Baseline-eligible survival rows: %d\n",
              sum(!surv_clean$exclude_from_baseline, na.rm = TRUE)))
} else {
  cat("  ⚠ Disturbance timeline file not found. Skipping integration.\n")
}

# =============================================================================
# 8. CREATE ANALYSIS-READY DATASETS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SAVING PREPARED DATA\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Save prepared data
saveRDS(surv_clean, file.path(output_dir, "prepared_survival_data.rds"))
cat(sprintf("✓ Saved: prepared_survival_data.rds (%d records)\n", nrow(surv_clean)))

saveRDS(growth_clean, file.path(output_dir, "prepared_growth_data.rds"))
cat(sprintf("✓ Saved: prepared_growth_data.rds (%d records)\n", nrow(growth_clean)))

# Save summary statistics
all_summaries <- list(
  survival_by_size = size_summary,
  growth_by_size = growth_summary,
  survival_by_region = geo_surv,
  growth_by_region = geo_growth,
  survival_by_datatype = dtype_surv,
  temporal_coverage = temporal
)

# Write summaries to CSV
for (name in names(all_summaries)) {
  write_csv(all_summaries[[name]],
            file.path(output_dir, paste0("summary_", name, ".csv")))
}
cat(sprintf("✓ Saved: %d summary tables\n", length(all_summaries)))

# --- Save data filtering audit trail ---
write_csv(filtering_audit, file.path(output_dir, "data_filtering_audit.csv"))
cat(sprintf("✓ Saved: data_filtering_audit.csv (%d rows)\n", nrow(filtering_audit)))

# --- Save size class distribution (survival + growth) ---
size_dist_surv <- surv_clean %>%
  group_by(size_class) %>%
  summarise(
    dataset = "survival",
    n = n(),
    median_size = median(size_cm2, na.rm = TRUE),
    q25 = quantile(size_cm2, 0.25, na.rm = TRUE),
    q75 = quantile(size_cm2, 0.75, na.rm = TRUE),
    min_size = min(size_cm2, na.rm = TRUE),
    max_size = max(size_cm2, na.rm = TRUE),
    .groups = "drop"
  )
size_dist_growth <- growth_clean %>%
  group_by(size_class) %>%
  summarise(
    dataset = "growth",
    n = n(),
    median_size = median(size_cm2, na.rm = TRUE),
    q25 = quantile(size_cm2, 0.25, na.rm = TRUE),
    q75 = quantile(size_cm2, 0.75, na.rm = TRUE),
    min_size = min(size_cm2, na.rm = TRUE),
    max_size = max(size_cm2, na.rm = TRUE),
    .groups = "drop"
  )
size_class_distribution <- bind_rows(size_dist_surv, size_dist_growth)
write_csv(size_class_distribution, file.path(output_dir, "size_class_distribution.csv"))
cat(sprintf("✓ Saved: size_class_distribution.csv (%d rows)\n", nrow(size_class_distribution)))

# --- Save impossible growth summary by study ---
impossible_growth_summary <- growth_clean %>%
  group_by(study) %>%
  summarise(
    n_impossible = sum(impossible_growth, na.rm = TRUE),
    n_total = n(),
    pct_impossible = round(n_impossible / n_total * 100, 2),
    .groups = "drop"
  ) %>%
  arrange(desc(pct_impossible))
write_csv(impossible_growth_summary, file.path(output_dir, "impossible_growth_summary.csv"))
cat(sprintf("✓ Saved: impossible_growth_summary.csv (%d rows)\n", nrow(impossible_growth_summary)))

# --- Save time interval statistics ---
# Compute overall and per-study statistics for observation intervals
interval_overall <- data.frame(
  study = "ALL",
  mean_interval = NA_real_,
  median_interval = NA_real_,
  sd_interval = NA_real_,
  min_interval = NA_real_,
  max_interval = NA_real_,
  n_obs = NA_integer_
)
# Combine intervals from both datasets
all_intervals <- bind_rows(
  surv_clean %>% select(study, time_interval_yr) %>% mutate(dataset = "survival"),
  growth_clean %>% select(study, time_interval_yr) %>% mutate(dataset = "growth")
)
if ("time_interval_yr" %in% names(all_intervals) && sum(!is.na(all_intervals$time_interval_yr)) > 0) {
  interval_overall <- data.frame(
    study = "ALL",
    mean_interval = mean(all_intervals$time_interval_yr, na.rm = TRUE),
    median_interval = median(all_intervals$time_interval_yr, na.rm = TRUE),
    sd_interval = sd(all_intervals$time_interval_yr, na.rm = TRUE),
    min_interval = min(all_intervals$time_interval_yr, na.rm = TRUE),
    max_interval = max(all_intervals$time_interval_yr, na.rm = TRUE),
    n_obs = sum(!is.na(all_intervals$time_interval_yr))
  )
  interval_by_study <- all_intervals %>%
    filter(!is.na(time_interval_yr)) %>%
    group_by(study) %>%
    summarise(
      mean_interval = mean(time_interval_yr, na.rm = TRUE),
      median_interval = median(time_interval_yr, na.rm = TRUE),
      sd_interval = sd(time_interval_yr, na.rm = TRUE),
      min_interval = min(time_interval_yr, na.rm = TRUE),
      max_interval = max(time_interval_yr, na.rm = TRUE),
      n_obs = n(),
      .groups = "drop"
    )
  observation_intervals <- bind_rows(interval_overall, interval_by_study)
} else {
  observation_intervals <- interval_overall
}
write_csv(observation_intervals, file.path(output_dir, "observation_intervals.csv"))
cat(sprintf("✓ Saved: observation_intervals.csv (%d rows)\n", nrow(observation_intervals)))

# --- Save study metadata table ---
study_meta_surv <- surv_clean %>%
  group_by(study) %>%
  summarise(
    region = paste(sort(unique(region)), collapse = "; "),
    year_min = min(survey_yr, na.rm = TRUE),
    year_max = max(survey_yr, na.rm = TRUE),
    population_type = paste(sort(unique(population_type)), collapse = "; "),
    n_survival = n(),
    mean_size_surv = mean(size_cm2, na.rm = TRUE),
    median_size_surv = median(size_cm2, na.rm = TRUE),
    .groups = "drop"
  )
study_meta_growth <- growth_clean %>%
  group_by(study) %>%
  summarise(
    n_growth = n(),
    mean_size_growth = mean(size_cm2, na.rm = TRUE),
    median_size_growth = median(size_cm2, na.rm = TRUE),
    .groups = "drop"
  )
study_metadata <- study_meta_surv %>%
  full_join(study_meta_growth, by = "study") %>%
  mutate(
    n_survival = replace_na(n_survival, 0L),
    n_growth = replace_na(n_growth, 0L),
    mean_size = coalesce(mean_size_surv, mean_size_growth),
    median_size = coalesce(median_size_surv, median_size_growth)
  ) %>%
  select(study, region, year_min, year_max, population_type,
         n_survival, n_growth, mean_size, median_size) %>%
  arrange(study)
write_csv(study_metadata, file.path(output_dir, "study_metadata.csv"))
cat(sprintf("✓ Saved: study_metadata.csv (%d rows)\n", nrow(study_metadata)))

# =============================================================================
# 8. FINAL SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  DATA PREPARATION COMPLETE                                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("SUMMARY:\n")
cat(sprintf("  Total survival observations: %d\n", nrow(surv_clean)))
cat(sprintf("  Total growth observations: %d\n", nrow(growth_clean)))
cat(sprintf("  Regions covered: %d\n", n_distinct(surv_clean$region)))
cat(sprintf("  Studies included: %d\n", n_distinct(surv_clean$study)))
cat(sprintf("  Year range: %d - %d\n",
            min(surv_clean$survey_yr), max(surv_clean$survey_yr)))

cat("\nSize class distribution (survival):\n")
for (i in 1:nrow(size_summary)) {
  cat(sprintf("  %s: n=%d, survival=%.1f%%\n",
              size_summary$size_class[i],
              size_summary$n[i],
              size_summary$survival_rate[i] * 100))
}

cat("\nNext step: Run 02_survival_thresholds.R\n\n")
