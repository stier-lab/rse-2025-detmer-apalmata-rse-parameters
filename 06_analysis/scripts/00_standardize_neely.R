#!/usr/bin/env Rscript
################################################################################
# 00_standardize_neely.R
# Convert Neely et al. 2022 FKNMS data from wide to long format
################################################################################
#
# PURPOSE:
#   Reads the Neely lab APAL monitoring data (878 colonies, 7 timepoints,
#   Florida Keys 2010-2016) and converts it to the standardized format used
#   by our analysis pipeline. Appends rows to apal_surv_ind.csv and
#   apal_growth_ind.csv.
#
# INPUT:
#   05_data/original/Neely_et_al_2022_FKNMS_APAL.xlsx
#
# OUTPUT:
#   Modifies (appends to):
#     05_data/standardized/apal_surv_ind.csv
#     05_data/standardized/apal_growth_ind.csv
#
# DISTURBANCE HANDLING:
#   A catastrophic mortality event occurred between Fall 2013 (TP4) and
#   Winter 2014-15 (TP5), with survival dropping from 94.6% to 53.2%.
#   All intervals are included in the primary analysis with the disturbance
#   column flagged:
#     - TP4->TP5: "disease_2014" (catastrophic mortality)
#     - TP5->TP6: "disease_2014_aftermath" (continued elevated mortality)
#     - All other intervals: NA (no known disturbance)
#   Downstream scripts use this flag for sensitivity analyses.
#
# NOAA OVERLAP: None. Neely monitors Middle/Lower Keys + Dry Tortugas;
#   NOAA monitors Upper Keys. Sites are fully independent.
#
# Author: Detmer & Stier Lab
# Date: 2026-04-01
################################################################################

library(readxl)
library(dplyr)
library(tidyr)
library(readr)
library(lubridate)

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  00: STANDARDIZE NEELY ET AL. 2022 FKNMS DATA               ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# Detect project root
if (file.exists("05_data/standardized")) {
  project_root <- "."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root.")
}

input_file <- file.path(project_root, "05_data/original/Neely_et_al_2022_FKNMS_APAL.xlsx")
surv_file <- file.path(project_root, "05_data/standardized/apal_surv_ind.csv")
growth_file <- file.path(project_root, "05_data/standardized/apal_growth_ind.csv")

if (!file.exists(input_file)) {
  stop("Neely data file not found: ", input_file)
}

# Check if Neely data already appended
existing_surv <- read_csv(surv_file, show_col_types = FALSE)
if ("neely_et_al_2022" %in% existing_surv$study) {
  cat("Neely data already present in apal_surv_ind.csv — removing old rows first.\n")
  existing_surv <- existing_surv %>% filter(study != "neely_et_al_2022")
  write_csv(existing_surv, surv_file)
}

existing_growth <- read_csv(growth_file, show_col_types = FALSE)
if ("neely_et_al_2022" %in% existing_growth$study) {
  cat("Neely data already present in apal_growth_ind.csv — removing old rows first.\n")
  existing_growth <- existing_growth %>% filter(study != "neely_et_al_2022")
  write_csv(existing_growth, growth_file)
}

# ==============================================================================
# SECTION 1: READ AND PARSE RAW DATA
# ==============================================================================

cat("SECTION 1: Reading raw data\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Read Sheet 1 (colony data) — skip the merged header row
raw <- read_excel(input_file, sheet = "Sheet1", skip = 1)
cat(sprintf("  Raw data: %d colonies x %d columns\n", nrow(raw), ncol(raw)))

# Read Sheet 2 (site locations)
locations <- read_excel(input_file, sheet = "Sheet2") %>%
  filter(!is.na(Site)) %>%
  mutate(
    lat = as.numeric(gsub("^N", "", Latitude)),
    lon = -abs(as.numeric(gsub("^W", "", gsub(" .*$", "", Longitude))))
  )

# Map site codes to location info
site_map <- data.frame(
  site_prefix = c("MR", "BB", "SR", "LK", "WS", "RK", "SK", "DT"),
  location = c("Marker 3 Reef", "Ball Buoy Reef", "Sombrero Reef",
               "Looe Key", "West Sambo Key", "Rock Key", "Sand Key",
               "Palmata Patch"),
  loc_group = c("Biscayne NP", "Biscayne NP", "Middle Keys",
                "Lower Keys", "Lower Keys", "Lower Keys", "Lower Keys",
                "Dry Tortugas NP"),
  lat = c(25.37328, 25.31618, 24.62592, 24.54593, 24.47987, 24.45449,
          24.45244, 24.62098),
  lon = c(-80.16062, -80.18725, -81.11045, -81.40731, -81.71284, -81.85842,
          -81.87706, -82.86745),
  stringsAsFactors = FALSE
)

# ==============================================================================
# SECTION 2: PIVOT WIDE TO LONG
# ==============================================================================

cat("\nSECTION 2: Pivoting to long format\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Rename columns for easier handling
colnames(raw) <- c("site", "coral_id",
                    "date_1", "lai_1", "date_2", "lai_2",
                    "date_3", "lai_3", "date_4", "lai_4",
                    "date_5", "lai_5", "date_6", "lai_6",
                    "date_7", "lai_7")

# Force LAI columns to numeric (some read as character)
for (tp in 1:7) {
  lai_col <- paste0("lai_", tp)
  raw[[lai_col]] <- as.numeric(raw[[lai_col]])
}

# Create long format: one row per colony per timepoint
long <- raw %>%
  pivot_longer(
    cols = matches("^(date|lai)_"),
    names_to = c(".value", "timepoint"),
    names_pattern = "(date|lai)_(\\d+)"
  ) %>%
  mutate(
    timepoint = as.integer(timepoint),
    survey_date = as.Date(date),
    survey_yr = year(survey_date)
  ) %>%
  filter(!is.na(lai)) %>%
  select(site, coral_id, timepoint, survey_date, survey_yr, lai)

cat(sprintf("  Long format: %d rows (colony x timepoint)\n", nrow(long)))
cat(sprintf("  Colonies: %d unique\n", n_distinct(long$coral_id)))
cat(sprintf("  Date range: %s to %s\n",
            min(long$survey_date, na.rm = TRUE),
            max(long$survey_date, na.rm = TRUE)))

# ==============================================================================
# SECTION 3: COMPUTE INTERVAL-LEVEL SURVIVAL AND GROWTH
# ==============================================================================

cat("\nSECTION 3: Computing survival and growth per interval\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Self-join consecutive timepoints
intervals <- long %>%
  inner_join(
    long %>% mutate(timepoint = timepoint - 1L),
    by = c("site", "coral_id", "timepoint"),
    suffix = c("_start", "_end")
  ) %>%
  # Only keep colonies alive at start
  filter(lai_start > 0) %>%
  mutate(
    survived = as.integer(lai_end > 0),
    delta_days = as.numeric(survey_date_end - survey_date_start),
    time_interval_yr = delta_days / 365.25,
    # Growth (for survivors only)
    growth_cm2_yr = ifelse(survived == 1, (lai_end - lai_start) / time_interval_yr, NA_real_),
    # Extract site prefix for location mapping
    site_prefix = gsub("\\d+$", "", site)
  )

cat(sprintf("  Intervals computed: %d\n", nrow(intervals)))
cat(sprintf("  Survived: %d (%.1f%%)\n",
            sum(intervals$survived), mean(intervals$survived) * 100))

# Tag disturbance intervals
# TP4->TP5 (Fall 2013 -> Winter 2014-15): catastrophic mortality event
# TP5->TP6 (Winter 2014-15 -> Fall 2015): continued elevated mortality
intervals <- intervals %>%
  mutate(
    disturbance = case_when(
      timepoint == 4 ~ "disease_2014",
      timepoint == 5 ~ "disease_2014_aftermath",
      TRUE ~ NA_character_
    )
  )

cat("\n  Per-interval survival:\n")
intervals %>%
  group_by(timepoint) %>%
  summarise(
    n = n(),
    surv = mean(survived),
    interval_yr = round(median(time_interval_yr), 2),
    disturbance = first(disturbance),
    .groups = "drop"
  ) %>%
  mutate(surv_pct = sprintf("%.1f%%", surv * 100)) %>%
  print()

# ==============================================================================
# SECTION 4: FORMAT FOR STANDARDIZED SCHEMA
# ==============================================================================

cat("\nSECTION 4: Formatting to standardized schema\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Join location info
intervals <- intervals %>%
  left_join(site_map, by = "site_prefix")

study_n <- n_distinct(intervals$coral_id)

# --- Survival records ---
neely_surv <- intervals %>%
  mutate(
    study = "neely_et_al_2022",
    region = "Florida Keys",
    plot = site,
    treatment_1 = NA_character_,
    treatment_2 = NA_character_,
    latitude = lat,
    longitude = lon,
    depth_m = NA_real_,
    data_type = "field",
    size_cm2 = lai_start,
    size_live_cm2 = lai_start,  # LAI IS live tissue area
    fragment = "N",
    study_notes = "Neely lab FKNMS monitoring; LAI = live tissue area (cm2); 0 = dead (absorbing state confirmed)",
    study_N = study_n,
    group_N = NA_integer_
  ) %>%
  # Compute group_N per plot per interval
  group_by(plot, timepoint) %>%
  mutate(group_N = n()) %>%
  ungroup() %>%
  select(
    study, region, location, plot, treatment_1, treatment_2,
    latitude, longitude, depth_m, survey_yr = survey_yr_start,
    data_type, coral_id, size_cm2, size_live_cm2, survived,
    fragment, time_interval_yr, disturbance, study_notes, study_N, group_N
  )

cat(sprintf("  Survival records: %d\n", nrow(neely_surv)))

# --- Growth records (survivors only, positive interval) ---
neely_growth <- intervals %>%
  filter(survived == 1, time_interval_yr > 0) %>%
  mutate(
    study = "neely_et_al_2022",
    region = "Florida Keys",
    plot = site,
    treatment_1 = NA_character_,
    treatment_2 = NA_character_,
    latitude = lat,
    longitude = lon,
    depth_m = NA_real_,
    data_type = "field",
    size_cm2 = lai_start,
    size_live_cm2 = lai_start,
    growth_live_cm2_yr = growth_cm2_yr,
    fragment = "N",
    study_notes = "Neely lab FKNMS monitoring; LAI = live tissue area (cm2)",
    study_N = study_n,
    group_N = NA_integer_
  ) %>%
  group_by(plot, timepoint) %>%
  mutate(group_N = n()) %>%
  ungroup() %>%
  select(
    study, region, location, plot, treatment_1, treatment_2,
    latitude, longitude, depth_m, survey_yr = survey_yr_start,
    data_type, coral_id, size_cm2, size_live_cm2,
    growth_cm2_yr, growth_live_cm2_yr,
    fragment, time_interval_yr, disturbance, study_notes, study_N, group_N
  )

cat(sprintf("  Growth records: %d\n", nrow(neely_growth)))

# ==============================================================================
# SECTION 5: APPEND TO STANDARDIZED FILES
# ==============================================================================

cat("\nSECTION 5: Appending to standardized data files\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Read existing data
existing_surv <- read_csv(surv_file, show_col_types = FALSE)
existing_growth <- read_csv(growth_file, show_col_types = FALSE)

cat(sprintf("  Existing survival: %d rows from %d studies\n",
            nrow(existing_surv), n_distinct(existing_surv$study)))
cat(sprintf("  Existing growth: %d rows from %d studies\n",
            nrow(existing_growth), n_distinct(existing_growth$study)))

# Ensure column alignment
surv_cols <- names(existing_surv)
growth_cols <- names(existing_growth)

# Add missing columns as NA if needed, drop the row index column
if ("...1" %in% surv_cols) {
  existing_surv <- existing_surv %>% select(-...1)
  surv_cols <- names(existing_surv)
}
if ("...1" %in% growth_cols) {
  existing_growth <- existing_growth %>% select(-...1)
  growth_cols <- names(existing_growth)
}

# Align Neely columns
for (col in surv_cols) {
  if (!col %in% names(neely_surv)) neely_surv[[col]] <- NA
}
neely_surv <- neely_surv[, surv_cols]

for (col in growth_cols) {
  if (!col %in% names(neely_growth)) neely_growth[[col]] <- NA
}
neely_growth <- neely_growth[, growth_cols]

# Append
combined_surv <- bind_rows(existing_surv, neely_surv)
combined_growth <- bind_rows(existing_growth, neely_growth)

# Write back
write_csv(combined_surv, surv_file)
write_csv(combined_growth, growth_file)

cat(sprintf("  Updated survival: %d rows from %d studies (+%d Neely)\n",
            nrow(combined_surv), n_distinct(combined_surv$study), nrow(neely_surv)))
cat(sprintf("  Updated growth: %d rows from %d studies (+%d Neely)\n",
            nrow(combined_growth), n_distinct(combined_growth$study), nrow(neely_growth)))

# ==============================================================================
# SECTION 6: SUMMARY STATISTICS
# ==============================================================================

cat("\nSECTION 6: Neely data summary\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

cat(sprintf("  Study: neely_et_al_2022\n"))
cat(sprintf("  Region: Florida Keys (Middle Keys, Lower Keys, Dry Tortugas, Biscayne NP)\n"))
cat(sprintf("  Colonies: %d unique\n", n_distinct(neely_surv$coral_id)))
cat(sprintf("  Survival records: %d\n", nrow(neely_surv)))
cat(sprintf("  Growth records: %d\n", nrow(neely_growth)))
cat(sprintf("  Overall survival: %.1f%%\n", mean(neely_surv$survived) * 100))
cat(sprintf("  Date range: 2010-11 to 2016-09\n"))
cat(sprintf("  Size range: %.0f - %.0f cm2\n",
            min(neely_surv$size_cm2), max(neely_surv$size_cm2)))

cat("\n  Disturbance-stratified survival:\n")
neely_surv %>%
  mutate(period = ifelse(is.na(disturbance), "Non-disturbance", disturbance)) %>%
  group_by(period) %>%
  summarise(n = n(), surv = round(mean(survived) * 100, 1), .groups = "drop") %>%
  print()

cat("\n  Per-site survival:\n")
neely_surv %>%
  group_by(location) %>%
  summarise(n = n(), surv = round(mean(survived) * 100, 1), .groups = "drop") %>%
  arrange(surv) %>%
  print()

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  NEELY DATA STANDARDIZATION COMPLETE                         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")
