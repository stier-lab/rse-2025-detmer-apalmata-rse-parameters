#!/usr/bin/env Rscript
################################################################################
# 31b_VERIFY_DHW.R
# Re-query NOAA CRW DHW using CORRECT endpoint and verify existing values
################################################################################
#
# PURPOSE:
#   Re-query all site-year combinations using the correct NOAA CRW ERDDAP
#   endpoint (noaacrwdhwDaily on coastwatch.noaa.gov) to verify and update
#   DHW values from the original script 31.
#
# CORRECT ENDPOINT:
#   https://coastwatch.noaa.gov/erddap/griddap/noaacrwdhwDaily.csv?
#     degree_heating_week[(YYYY-06-01T12:00:00Z):(YYYY-12-01T12:00:00Z)]
#     [(LAT)][(LON)]
#
# INPUTS:
#   - 06_analysis/output/heat_stress_by_site_year.csv (existing values)
#
# OUTPUTS:
#   - 06_analysis/output/heat_stress_by_site_year_verified.csv
#   - 06_analysis/output/dhw_verification_summary.csv (per-study summary)
#   - 06_analysis/output/dhw_verification_log.csv (per-query log)
#
# Author: Detmer & Stier Lab
# Date: 2026-03
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

library(httr)
library(readr)
library(dplyr)
library(tidyr)

set.seed(42)

cat("\n")
cat("==============================================================================\n")
cat("  31b: VERIFY DHW VALUES (NOAA CRW correct endpoint)\n")
cat("==============================================================================\n\n")

# Resolve project root
project_root <- if (file.exists("06_analysis/output/heat_stress_by_site_year.csv")) {
  "."
} else if (file.exists("../../06_analysis/output/heat_stress_by_site_year.csv")) {
  "../.."
} else {
  stop("Cannot find project root. Run from project root or 06_analysis/scripts/")
}

output_dir <- file.path(project_root, "06_analysis/output")

# ==============================================================================
# SECTION 1: LOAD EXISTING DATA
# ==============================================================================

cat("1. Loading existing heat stress data...\n")

existing <- read_csv(
  file.path(output_dir, "heat_stress_by_site_year.csv"),
  show_col_types = FALSE
)

cat(sprintf("   Loaded %d site-year combinations\n", nrow(existing)))
cat(sprintf("   Years: %d - %d\n", min(existing$survey_yr), max(existing$survey_yr)))
cat(sprintf("   Studies: %d\n", n_distinct(existing$study)))

# Identify queryable rows (survey_yr >= 1985)
queryable <- existing %>%
  filter(survey_yr >= 1985)

cat(sprintf("   Queryable (>= 1985): %d site-years\n", nrow(queryable)))
cat(sprintf("   Pre-1985 (skipped): %d site-years\n", nrow(existing) - nrow(queryable)))

# ==============================================================================
# SECTION 2: QUERY CORRECT ERDDAP ENDPOINT
# ==============================================================================

cat("\n2. Querying NOAA CRW ERDDAP (correct endpoint)...\n")
cat("   Endpoint: coastwatch.noaa.gov/erddap/griddap/noaacrwdhwDaily\n")
cat("   Variable: degree_heating_week\n")
cat("   Time format: T12:00:00Z\n")
cat("   Rate limit: 1 second between queries\n\n")

# Function: query a single site-year from the CORRECT ERDDAP endpoint
query_dhw_correct <- function(lat, lon, year, lat_precision = 1) {
  # Round lat/lon to specified precision
  lat_q <- round(lat, lat_precision)
  lon_q <- round(lon, lat_precision)

  start_date <- sprintf("%d-06-01T12:00:00Z", year)
  end_date   <- sprintf("%d-12-01T12:00:00Z", year)

  url <- sprintf(
    "https://coastwatch.noaa.gov/erddap/griddap/noaacrwdhwDaily.csv?degree_heating_week[(%s):(%s)][(%s)][(%s)]",
    start_date, end_date, lat_q, lon_q
  )

  result <- tryCatch({
    resp <- httr::GET(url, httr::timeout(60))
    status <- httr::status_code(resp)

    if (status == 200) {
      content_text <- httr::content(resp, as = "text", encoding = "UTF-8")
      lines <- strsplit(content_text, "\n")[[1]]

      # ERDDAP CSV format: row 1 = variable names, row 2 = units, rows 3+ = data
      if (length(lines) > 2) {
        data_lines <- lines[3:length(lines)]
        data_lines <- data_lines[nchar(trimws(data_lines)) > 0]

        if (length(data_lines) > 0) {
          # Parse the header to find the degree_heating_week column index
          header <- strsplit(lines[1], ",")[[1]]
          dhw_col <- which(header == "degree_heating_week")
          if (length(dhw_col) == 0) dhw_col <- length(header)  # fallback: last column

          vals <- sapply(data_lines, function(line) {
            parts <- strsplit(line, ",")[[1]]
            if (length(parts) >= dhw_col) {
              as.numeric(parts[dhw_col])
            } else {
              NA_real_
            }
          }, USE.NAMES = FALSE)

          vals <- vals[!is.na(vals)]
          if (length(vals) > 0) {
            return(list(
              max_dhw = max(vals),
              n_obs = length(vals),
              status = "success",
              url = url,
              error_msg = NA_character_
            ))
          }
        }
      }
      return(list(
        max_dhw = NA_real_,
        n_obs = 0L,
        status = "no_data_in_response",
        url = url,
        error_msg = "Response 200 but no valid data rows"
      ))
    } else {
      return(list(
        max_dhw = NA_real_,
        n_obs = 0L,
        status = paste0("http_", status),
        url = url,
        error_msg = httr::content(resp, as = "text", encoding = "UTF-8")
      ))
    }
  }, error = function(e) {
    return(list(
      max_dhw = NA_real_,
      n_obs = 0L,
      status = "error",
      url = url,
      error_msg = conditionMessage(e)
    ))
  })

  return(result)
}

# Initialize results storage
results <- data.frame(
  study = character(),
  region = character(),
  lat_round = numeric(),
  lon_round = numeric(),
  survey_yr = integer(),
  new_max_dhw = numeric(),
  n_daily_obs = integer(),
  query_status = character(),
  query_url = character(),
  retry_precision = character(),
  error_msg = character(),
  stringsAsFactors = FALSE
)

n_total <- nrow(queryable)
n_success <- 0
n_retry <- 0
n_fail <- 0

for (i in seq_len(n_total)) {
  row <- queryable[i, ]

  cat(sprintf("   [%3d/%d] %s | %s | %.1f, %.1f | %d ... ",
              i, n_total, row$study, row$region, row$lat_round, row$lon_round, row$survey_yr))

  # First attempt: original precision (0.1 degree)
  res <- query_dhw_correct(row$lat_round, row$lon_round, row$survey_yr, lat_precision = 1)
  retry_precision <- "0.1"

  # If failed, retry with 0.05 degree precision
  if (res$status != "success") {
    cat("retry(0.05)... ")
    Sys.sleep(1)
    res <- query_dhw_correct(row$lat_round, row$lon_round, row$survey_yr, lat_precision = 2)
    retry_precision <- "0.05"
    n_retry <- n_retry + 1
  }

  if (res$status == "success") {
    cat(sprintf("DHW = %.2f (%d obs)\n", res$max_dhw, res$n_obs))
    n_success <- n_success + 1
  } else {
    cat(sprintf("FAILED (%s)\n", res$status))
    n_fail <- n_fail + 1
  }

  results <- rbind(results, data.frame(
    study = row$study,
    region = row$region,
    lat_round = row$lat_round,
    lon_round = row$lon_round,
    survey_yr = row$survey_yr,
    new_max_dhw = res$max_dhw,
    n_daily_obs = res$n_obs,
    query_status = res$status,
    query_url = res$url,
    retry_precision = retry_precision,
    error_msg = ifelse(is.na(res$error_msg), "", res$error_msg),
    stringsAsFactors = FALSE
  ))

  # Rate limit: 1 second between requests
  Sys.sleep(1)
}

cat(sprintf("\n   Query complete: %d success, %d retried, %d failed out of %d\n",
            n_success, n_retry, n_fail, n_total))

# ==============================================================================
# SECTION 3: COMPARE NEW VALUES AGAINST EXISTING
# ==============================================================================

cat("\n3. Comparing new values against existing...\n")

# Rename existing columns before join to avoid ambiguity
existing_renamed <- existing %>%
  rename(old_max_dhw = max_dhw,
         old_category = heat_stress_category,
         old_source = dhw_source,
         old_status = query_status)

# Merge results with existing data
comparison <- existing_renamed %>%
  left_join(
    results %>% select(study, region, lat_round, lon_round, survey_yr,
                        new_max_dhw, n_daily_obs, new_query_status = query_status,
                        retry_precision, error_msg),
    by = c("study", "region", "lat_round", "lon_round", "survey_yr")
  ) %>%
  mutate(
    # Calculate discrepancy
    dhw_discrepancy = ifelse(!is.na(new_max_dhw) & !is.na(old_max_dhw),
                             abs(new_max_dhw - old_max_dhw), NA_real_),
    flagged = ifelse(!is.na(dhw_discrepancy) & dhw_discrepancy > 1, TRUE, FALSE)
  )

# Report discrepancies
n_compared <- sum(!is.na(comparison$dhw_discrepancy))
n_flagged <- sum(comparison$flagged, na.rm = TRUE)
cat(sprintf("   Comparable pairs: %d\n", n_compared))
cat(sprintf("   Discrepancies > 1 DHW: %d\n", n_flagged))

if (n_flagged > 0) {
  cat("\n   FLAGGED DISCREPANCIES:\n")
  flagged_rows <- comparison %>%
    filter(flagged == TRUE) %>%
    select(study, region, survey_yr, lat_round, lon_round,
           old_max_dhw, new_max_dhw, dhw_discrepancy, old_source, old_status)
  print(as.data.frame(flagged_rows), row.names = FALSE)
}

# Summary stats for matches
if (n_compared > 0) {
  cat(sprintf("\n   Mean absolute discrepancy: %.3f DHW\n",
              mean(comparison$dhw_discrepancy, na.rm = TRUE)))
  cat(sprintf("   Median absolute discrepancy: %.3f DHW\n",
              median(comparison$dhw_discrepancy, na.rm = TRUE)))
  cat(sprintf("   Max absolute discrepancy: %.3f DHW\n",
              max(comparison$dhw_discrepancy, na.rm = TRUE)))

  # Correlation
  valid <- comparison %>% filter(!is.na(old_max_dhw) & !is.na(new_max_dhw))
  if (nrow(valid) > 2) {
    cor_val <- cor(valid$old_max_dhw, valid$new_max_dhw, use = "complete.obs")
    cat(sprintf("   Correlation (old vs new): %.4f\n", cor_val))
  }
}

# ==============================================================================
# SECTION 4: BUILD VERIFIED OUTPUT
# ==============================================================================

cat("\n4. Building verified output...\n")

# Classify heat stress using standard NOAA CRW thresholds
classify_heat_stress <- function(dhw) {
  case_when(
    is.na(dhw) ~ NA_character_,
    dhw == 0   ~ "none",
    dhw < 4    ~ "minor",
    dhw < 8    ~ "moderate",
    TRUE       ~ "major"
  )
}

verified <- comparison %>%
  mutate(
    # Use new value where available, keep old where not queryable
    verified_max_dhw = case_when(
      survey_yr < 1985 ~ NA_real_,                    # Pre-CRW era
      !is.na(new_max_dhw) ~ new_max_dhw,              # New query succeeded
      TRUE ~ old_max_dhw                                # Keep original
    ),
    verified_source = case_when(
      survey_yr < 1985 ~ "pre-1985 (CRW unavailable)",
      !is.na(new_max_dhw) ~ "ERDDAP verified (noaacrwdhwDaily)",
      !is.na(old_max_dhw) ~ paste0("original: ", old_source, " (re-query failed)"),
      TRUE ~ "no_data"
    ),
    verified_category = classify_heat_stress(verified_max_dhw)
  ) %>%
  select(
    study, region, lat_round, lon_round, survey_yr,
    max_dhw = verified_max_dhw,
    heat_stress_category = verified_category,
    dhw_source = verified_source,
    query_status = new_query_status,
    old_max_dhw,
    old_source,
    dhw_discrepancy,
    flagged
  )

# ==============================================================================
# SECTION 5: WRITE OUTPUTS
# ==============================================================================

cat("\n5. Writing outputs...\n")

# 5a. Verified site-year file (clean version matching original format)
verified_clean <- verified %>%
  select(study, region, lat_round, lon_round, survey_yr,
         max_dhw, heat_stress_category, dhw_source, query_status)

write_csv(verified_clean,
          file.path(output_dir, "heat_stress_by_site_year_verified.csv"))
cat(sprintf("   Written: heat_stress_by_site_year_verified.csv (%d rows)\n",
            nrow(verified_clean)))

# 5b. Full verification log with discrepancies
write_csv(verified,
          file.path(output_dir, "dhw_verification_log.csv"))
cat(sprintf("   Written: dhw_verification_log.csv (%d rows)\n",
            nrow(verified)))

# ==============================================================================
# SECTION 6: STUDY-LEVEL SUMMARY
# ==============================================================================

cat("\n6. Creating study-level summary...\n")

study_summary <- verified %>%
  filter(!is.na(max_dhw)) %>%
  group_by(study) %>%
  summarise(
    n_site_years = n(),
    max_dhw_ever = max(max_dhw, na.rm = TRUE),
    year_max_dhw = survey_yr[which.max(max_dhw)],
    region_max_dhw = region[which.max(max_dhw)],
    n_years_dhw_ge_4 = sum(max_dhw >= 4, na.rm = TRUE),
    n_years_dhw_ge_8 = sum(max_dhw >= 8, na.rm = TRUE),
    mean_dhw = round(mean(max_dhw, na.rm = TRUE), 2),
    median_dhw = round(median(max_dhw, na.rm = TRUE), 2),
    years_covered = paste(sort(unique(survey_yr)), collapse = ", "),
    .groups = "drop"
  ) %>%
  arrange(desc(max_dhw_ever))

write_csv(study_summary,
          file.path(output_dir, "dhw_verification_summary.csv"))
cat(sprintf("   Written: dhw_verification_summary.csv (%d studies)\n",
            nrow(study_summary)))

# Print summary table
cat("\n   STUDY-LEVEL DHW SUMMARY:\n")
cat("   ", paste(rep("-", 100), collapse = ""), "\n")
cat(sprintf("   %-35s %5s %7s %5s %6s %6s\n",
            "Study", "N", "MaxDHW", "Year", ">=4", ">=8"))
cat("   ", paste(rep("-", 100), collapse = ""), "\n")

for (j in seq_len(nrow(study_summary))) {
  s <- study_summary[j, ]
  cat(sprintf("   %-35s %5d %7.2f %5d %6d %6d\n",
              substr(s$study, 1, 35),
              s$n_site_years,
              s$max_dhw_ever,
              s$year_max_dhw,
              s$n_years_dhw_ge_4,
              s$n_years_dhw_ge_8))
}

# ==============================================================================
# SECTION 7: OVERALL SUMMARY STATISTICS
# ==============================================================================

cat("\n7. Overall summary statistics:\n")

total_rows <- nrow(verified_clean)
n_with_dhw <- sum(!is.na(verified_clean$max_dhw))
n_no_data <- sum(is.na(verified_clean$max_dhw))

cat(sprintf("   Total site-years: %d\n", total_rows))
cat(sprintf("   With DHW values: %d (%.1f%%)\n", n_with_dhw, 100 * n_with_dhw / total_rows))
cat(sprintf("   No data: %d (%.1f%%)\n", n_no_data, 100 * n_no_data / total_rows))

if (n_with_dhw > 0) {
  cat(sprintf("\n   Heat stress categories (verified):\n"))
  cat_table <- verified_clean %>%
    filter(!is.na(heat_stress_category)) %>%
    count(heat_stress_category) %>%
    mutate(pct = round(100 * n / sum(n), 1))
  for (k in seq_len(nrow(cat_table))) {
    cat(sprintf("     %-12s: %3d (%5.1f%%)\n",
                cat_table$heat_stress_category[k],
                cat_table$n[k],
                cat_table$pct[k]))
  }
}

cat("\n==============================================================================\n")
cat("  31b: VERIFICATION COMPLETE\n")
cat("==============================================================================\n\n")
