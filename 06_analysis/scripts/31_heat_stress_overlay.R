#!/usr/bin/env Rscript
################################################################################
# 31_HEAT_STRESS_OVERLAY.R
# NOAA Coral Reef Watch DHW Overlay for All Study Sites
################################################################################
#
# PURPOSE:
#   Query NOAA Coral Reef Watch (CRW) 5km Degree Heating Weeks (DHW) data for
#   every unique site-year combination in the A. palmata demographic dataset.
#   Overlay DHW onto survival data, classify heat stress, and analyze the
#   relationship between thermal stress and survival.
#
# APPROACH:
#   1. Extract unique lat/lon + year from individual and summary survival data
#   2. Query NOAA CRW DHW via ERDDAP (rerddap → httr fallback → literature LUT)
#   3. Classify heat stress using standard NOAA CRW thresholds
#   4. Merge with individual survival data
#   5. Analyze survival by heat stress category; test as meta-analysis moderator
#
# INPUTS:
#   - 05_data/standardized/apal_surv_ind.csv
#   - 05_data/standardized/apal_surv_summ.csv
#   - 06_analysis/output/expanded_meta_analysis_study_effects.csv (for moderator)
#
# OUTPUTS:
#   - 06_analysis/output/heat_stress_by_site_year.csv
#   - 06_analysis/output/heat_stress_survival_analysis.csv
#   - 06_analysis/output/heat_stress_model_diagnostics.csv
#   - 06_analysis/figures/supplementary/FigSXX_heat_stress_survival.png
#
# NOTES:
#   - CRW 5km product starts in 1985; pre-1985 studies get NA
#   - ERDDAP queries are rate-limited (0.5 s between requests)
#   - If ERDDAP is unreachable, a curated literature lookup table is used
#
# Author: Detmer & Stier Lab
# Date: 2026-03
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

# Additional packages for ERDDAP queries
has_rerddap <- requireNamespace("rerddap", quietly = TRUE)
has_httr    <- requireNamespace("httr",    quietly = TRUE)
has_metafor <- requireNamespace("metafor", quietly = TRUE)

set.seed(42)

cat("\n")
cat("==============================================================================\n")
cat("  31: HEAT STRESS OVERLAY (NOAA Coral Reef Watch DHW)\n")
cat("==============================================================================\n\n")

# Paths
dirs <- setup_output_dirs()
output_dir <- dirs$output
fig_dir    <- dirs$figures_supp
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# SECTION 1: EXTRACT UNIQUE SITE-YEAR COMBINATIONS
# ==============================================================================

print_header("1. Extracting unique site-year combinations")

# --- Load individual survival data ---
surv_ind <- read_csv(
  file.path(get_project_root(), "05_data/standardized/apal_surv_ind.csv"),
  show_col_types = FALSE
)
if (names(surv_ind)[1] %in% c("...1", "X1", "")) surv_ind <- surv_ind %>% dplyr::select(-1)

# --- Load summary survival data ---
surv_summ <- read_csv(
  file.path(get_project_root(), "05_data/standardized/apal_surv_summ.csv"),
  show_col_types = FALSE
)
if (names(surv_summ)[1] %in% c("...1", "X1", "")) surv_summ <- surv_summ %>% dplyr::select(-1)

# --- Extract unique site-year from individual data ---
site_years_ind <- surv_ind %>%
  dplyr::filter(!is.na(latitude) & !is.na(longitude) & !is.na(survey_yr)) %>%
  dplyr::mutate(
    lat_round = round(latitude, 1),
    lon_round = round(longitude, 1)
  ) %>%
  dplyr::distinct(study, region, lat_round, lon_round, survey_yr) %>%
  dplyr::mutate(data_source = "individual")

# --- Extract unique site-year from summary data ---
site_years_summ <- surv_summ %>%
  dplyr::filter(!is.na(latitude) & !is.na(longitude) & !is.na(survey_yr)) %>%
  dplyr::filter(!is.nan(latitude) & !is.nan(longitude)) %>%
  dplyr::mutate(
    lat_round = round(latitude, 1),
    lon_round = round(longitude, 1)
  ) %>%
  dplyr::distinct(study, region, lat_round, lon_round, survey_yr) %>%
  dplyr::mutate(data_source = "summary")

# --- Combine and deduplicate ---
site_years_all <- bind_rows(site_years_ind, site_years_summ) %>%
  dplyr::distinct(lat_round, lon_round, survey_yr, .keep_all = TRUE) %>%
  dplyr::arrange(study, survey_yr)

cat(sprintf("  Individual data: %d unique site-years\n", nrow(site_years_ind)))
cat(sprintf("  Summary data:    %d unique site-years\n", nrow(site_years_summ)))
cat(sprintf("  Combined (deduplicated): %d unique site-years\n", nrow(site_years_all)))
cat(sprintf("  Year range: %d - %d\n", min(site_years_all$survey_yr), max(site_years_all$survey_yr)))
cat(sprintf("  Unique studies: %d\n", n_distinct(site_years_all$study)))
cat(sprintf("  Unique locations (lat/lon): %d\n",
            nrow(distinct(site_years_all, lat_round, lon_round))))

# Flag pre-1985 site-years (CRW data unavailable)
n_pre1985 <- sum(site_years_all$survey_yr < 1985)
if (n_pre1985 > 0) {
  cat(sprintf("\n  NOTE: %d site-years before 1985 (CRW unavailable) -- will be set to NA\n",
              n_pre1985))
}

classify_dhw_support <- function(n_rows, n_studies, n_regions, n_study_years) {
  if (!is.finite(n_rows) || n_rows <= 0) return("none")
  if (!is.finite(n_studies) || !is.finite(n_regions) || !is.finite(n_study_years)) {
    return("sparse")
  }
  if (n_studies < 3 || n_regions < 3 || n_study_years < 12) return("sparse")
  if (n_rows >= 500 && n_studies >= 5 && n_regions >= 5 && n_study_years >= 20) {
    return("moderate")
  }
  if (n_rows >= 100) return("limited")
  "sparse"
}

# ==============================================================================
# SECTION 2: QUERY NOAA CRW DHW VIA ERDDAP
# ==============================================================================

print_header("2. Querying NOAA Coral Reef Watch DHW via ERDDAP")

# --- Curated literature fallback lookup table ---
# Known max DHW values for major Caribbean bleaching events from published literature
# Sources: Eakin et al. 2010, NOAA Coral Reef Watch summaries, Manzello 2015,
#          Skirving et al. 2019, NOAA/NESDIS 2024
# Values are approximate regional maxima (degree-C weeks)
dhw_literature_lut <- tribble(
  ~region_pattern,            ~year, ~dhw_max_literature, ~source,
  # 1998 mass bleaching
  "Florida",                  1998,  6.0,  "Manzello 2015",
  "Dry Tortugas",             1998,  4.5,  "Manzello 2015",
  "Puerto Rico",              1998,  7.0,  "Eakin et al. 2010",
  "Virgin",                   1998,  8.0,  "Eakin et al. 2010",
  "Jamaica",                  1998,  5.5,  "Eakin et al. 2010",
  "Curacao",                  1998,  4.0,  "Eakin et al. 2010",
  "Mexico",                   1998,  3.5,  "Eakin et al. 2010",
  "Dominican",                1998,  5.0,  "Eakin et al. 2010",
  "Bahamas",                  1998,  3.0,  "Eakin et al. 2010",
  "Cuba",                     1998,  4.0,  "Eakin et al. 2010",
  "Navassa",                  1998,  5.0,  "Eakin et al. 2010",
  # 2005 mass bleaching (worst Caribbean event on record)
  "Florida",                  2005,  9.0,  "Eakin et al. 2010",
  "Dry Tortugas",             2005,  5.0,  "Manzello 2015",
  "Puerto Rico",              2005, 12.0,  "Eakin et al. 2010",
  "Virgin",                   2005, 14.0,  "Eakin et al. 2010",
  "Jamaica",                  2005,  7.0,  "Eakin et al. 2010",
  "Curacao",                  2005,  6.0,  "Eakin et al. 2010",
  "Mexico",                   2005,  6.5,  "Eakin et al. 2010",
  "Dominican",                2005,  8.0,  "Eakin et al. 2010",
  "Bahamas",                  2005,  5.0,  "Eakin et al. 2010",
  "Cuba",                     2005,  6.0,  "Eakin et al. 2010",
  "Navassa",                  2005,  8.0,  "Eakin et al. 2010",
  # 2010 bleaching
  "Florida",                  2010,  7.0,  "Manzello 2015",
  "Dry Tortugas",             2010,  4.0,  "Manzello 2015",
  "Puerto Rico",              2010,  8.0,  "Skirving et al. 2019",
  "Virgin",                   2010,  9.0,  "Skirving et al. 2019",
  "Jamaica",                  2010,  5.0,  "Skirving et al. 2019",
  "Curacao",                  2010,  5.0,  "Skirving et al. 2019",
  "Mexico",                   2010,  6.0,  "Skirving et al. 2019",
  "Dominican",                2010,  6.0,  "Skirving et al. 2019",
  "Bahamas",                  2010,  5.5,  "Skirving et al. 2019",
  "Cuba",                     2010,  5.5,  "Skirving et al. 2019",
  "Navassa",                  2010,  6.0,  "Skirving et al. 2019",
  # 2014-2015 global bleaching event
  "Florida",                  2014,  5.0,  "NOAA CRW 2015",
  "Dry Tortugas",             2014,  3.0,  "NOAA CRW 2015",
  "Florida",                  2015,  6.0,  "NOAA CRW 2015",
  "Dry Tortugas",             2015,  4.0,  "NOAA CRW 2015",
  "Puerto Rico",              2015,  4.0,  "NOAA CRW 2015",
  "Virgin",                   2015,  5.0,  "NOAA CRW 2015",
  "Jamaica",                  2015,  4.5,  "NOAA CRW 2015",
  "Curacao",                  2015,  4.0,  "NOAA CRW 2015",
  "Mexico",                   2015,  5.5,  "NOAA CRW 2015",
  "Dominican",                2015,  4.0,  "NOAA CRW 2015",
  "Bahamas",                  2015,  5.0,  "NOAA CRW 2015",
  "Cuba",                     2015,  5.0,  "NOAA CRW 2015",
  "Navassa",                  2015,  4.5,  "NOAA CRW 2015",
  # 2023 mass bleaching (record ocean temperatures)
  "Florida",                  2023, 16.0,  "NOAA/NESDIS 2024",
  "Dry Tortugas",             2023, 10.0,  "NOAA/NESDIS 2024",
  "Puerto Rico",              2023,  8.0,  "NOAA/NESDIS 2024",
  "Virgin",                   2023,  9.0,  "NOAA/NESDIS 2024",
  "Jamaica",                  2023,  8.0,  "NOAA/NESDIS 2024",
  "Curacao",                  2023, 10.0,  "NOAA/NESDIS 2024",
  "Mexico",                   2023, 12.0,  "NOAA/NESDIS 2024",
  "Dominican",                2023,  9.0,  "NOAA/NESDIS 2024",
  "Bahamas",                  2023, 10.0,  "NOAA/NESDIS 2024",
  "Cuba",                     2023, 10.0,  "NOAA/NESDIS 2024",
  "Navassa",                  2023,  7.0,  "NOAA/NESDIS 2024"
)

# --- Function: query a single site-year from ERDDAP via rerddap ---
query_dhw_rerddap <- function(lat, lon, year) {
  if (!has_rerddap) return(NULL)

  # CRW 5km monthly DHW -- warm season is approximately June through December
  # for Caribbean sites

  start_date <- sprintf("%d-06-01", year)
  end_date   <- sprintf("%d-12-01", year)

  result <- tryCatch({
    info_obj <- rerddap::info("NOAA_DHW_monthly",
                              url = "https://coastwatch.pfeg.noaa.gov/erddap/")
    grid_data <- rerddap::griddap(
      info_obj,
      time   = c(start_date, end_date),
      latitude  = c(lat, lat),
      longitude = c(lon, lon),
      fields = "CRW_DHW"
    )
    df <- grid_data$data
    if (nrow(df) > 0 && "CRW_DHW" %in% names(df)) {
      return(max(df$CRW_DHW, na.rm = TRUE))
    }
    return(NULL)
  }, error = function(e) {
    return(NULL)
  })
  return(result)
}

# --- Function: query a single site-year from ERDDAP via httr (REST fallback) ---
query_dhw_httr <- function(lat, lon, year) {
  if (!has_httr) return(NULL)

  # Try multiple ERDDAP endpoints and dataset IDs
  # noaacrwdhwDaily on coastwatch.noaa.gov has the actual DHW variable (degree_heating_week)
  # NOAA_DHW on coastwatch.pfeg.noaa.gov is a fallback
  dataset_ids <- c("noaacrwdhwDaily", "NOAA_DHW")

  for (dataset_id in dataset_ids) {
    start_date <- sprintf("%d-06-01T00:00:00Z", year)
    end_date   <- sprintf("%d-12-01T00:00:00Z", year)

    # Use correct server and variable name for each dataset
    if (dataset_id == "noaacrwdhwDaily") {
      base_url <- "https://coastwatch.noaa.gov/erddap/griddap"
      var_name <- "degree_heating_week"
    } else {
      base_url <- "https://coastwatch.pfeg.noaa.gov/erddap/griddap"
      var_name <- "CRW_DHW"
    }
    url <- sprintf(
      "%s/%s.csv?%s[(%s):(%s)][(%s):(%s)][(%s):(%s)]",
      base_url, dataset_id, var_name, start_date, end_date, lat, lat, lon, lon
    )

    result <- tryCatch({
      resp <- httr::GET(url, httr::timeout(30))
      if (httr::status_code(resp) == 200) {
        content_text <- httr::content(resp, as = "text", encoding = "UTF-8")
        # ERDDAP CSV: first row is variable names, second is units, then data
        lines <- strsplit(content_text, "\n")[[1]]
        if (length(lines) > 2) {
          # Skip header (line 1) and units (line 2), parse data rows
          data_lines <- lines[3:length(lines)]
          data_lines <- data_lines[nchar(trimws(data_lines)) > 0]
          if (length(data_lines) > 0) {
            vals <- sapply(data_lines, function(line) {
              parts <- strsplit(line, ",")[[1]]
              # CRW_DHW is typically the last column
              as.numeric(parts[length(parts)])
            }, USE.NAMES = FALSE)
            vals <- vals[!is.na(vals)]
            if (length(vals) > 0) return(max(vals))
          }
        }
      }
      NULL
    }, error = function(e) {
      NULL
    })

    if (!is.null(result)) return(result)
  }
  return(NULL)
}

# --- Function: match region to literature LUT ---
lookup_dhw_literature <- function(region, year) {
  # Try exact year match first
  yr_rows <- dhw_literature_lut %>% dplyr::filter(year == !!year)
  if (nrow(yr_rows) == 0) return(NULL)

  # Match region patterns against the input region string
  matches <- sapply(yr_rows$region_pattern, function(pat) grepl(pat, region, ignore.case = TRUE))
  match_rows <- yr_rows[matches, ]

  if (nrow(match_rows) > 0) {
    return(list(
      dhw = match_rows$dhw_max_literature[1],
      source = paste0("Literature LUT: ", match_rows$source[1])
    ))
  }
  return(NULL)
}

# --- Main DHW query loop ---
cat("Querying DHW for each site-year...\n")
cat(sprintf("  Method priority: cached lookup -> rerddap -> httr REST -> literature LUT -> NA\n"))
cat(sprintf("  Rate limit: 0.5s between ERDDAP requests\n\n"))

# Reuse any existing site-year cache before querying external sources
dhw_cache_candidates <- c(
  file.path(output_dir, "heat_stress_by_site_year_verified.csv"),
  file.path(output_dir, "heat_stress_by_site_year.csv")
)
dhw_cache_file <- dhw_cache_candidates[file.exists(dhw_cache_candidates)][1]
using_verified_cache <- length(dhw_cache_file) == 1 &&
  !is.na(dhw_cache_file) &&
  identical(basename(dhw_cache_file), "heat_stress_by_site_year_verified.csv")

if (length(dhw_cache_file) == 1 && !is.na(dhw_cache_file)) {
  dhw_cache <- read_csv(dhw_cache_file, show_col_types = FALSE) %>%
    dplyr::select(dplyr::any_of(c(
      "lat_round", "lon_round", "survey_yr", "max_dhw", "dhw_source", "query_status"
    ))) %>%
    dplyr::distinct(lat_round, lon_round, survey_yr, .keep_all = TRUE)

  site_years_all <- site_years_all %>%
    dplyr::left_join(dhw_cache, by = c("lat_round", "lon_round", "survey_yr"))

  cat(sprintf("  Loaded cache: %d site-years from %s\n\n",
              nrow(dhw_cache), basename(dhw_cache_file)))
} else {
  site_years_all$max_dhw <- NA_real_
  site_years_all$dhw_source <- NA_character_
  site_years_all$query_status <- NA_character_
}

n_total   <- nrow(site_years_all)
n_cached  <- sum(!is.na(site_years_all$query_status) | !is.na(site_years_all$dhw_source))
n_erddap  <- 0
n_httr    <- 0
n_lut     <- 0
n_na      <- 0
n_pre1985_actual <- 0

for (i in seq_len(n_total)) {
  lat  <- site_years_all$lat_round[i]
  lon  <- site_years_all$lon_round[i]
  yr   <- site_years_all$survey_yr[i]
  reg  <- site_years_all$region[i]

  # Progress reporting every 10 queries
  if (i %% 10 == 1 || i == n_total) {
    cat(sprintf("\r  Processing %d/%d (%.0f%%)...", i, n_total, i / n_total * 100))
  }

  # Reuse cached rows from earlier successful or explicit no-data runs
  if ((!is.na(site_years_all$max_dhw[i]) && !is.na(site_years_all$dhw_source[i])) ||
      (!is.na(site_years_all$query_status[i]) &&
       site_years_all$query_status[i] %in% c("success", "literature_lut", "pre-1985 (CRW unavailable)", "no_data")) ||
      (using_verified_cache && !is.na(site_years_all$query_status[i]) &&
       site_years_all$query_status[i] == "error")) {
    next
  }

  # Pre-1985: CRW data unavailable

  if (yr < 1985) {
    site_years_all$query_status[i] <- "pre-1985 (CRW unavailable)"
    n_pre1985_actual <- n_pre1985_actual + 1
    next
  }

  # Attempt 1: rerddap
  dhw_val <- query_dhw_rerddap(lat, lon, yr)
  if (!is.null(dhw_val) && is.finite(dhw_val)) {
    site_years_all$max_dhw[i]      <- dhw_val
    site_years_all$dhw_source[i]   <- "ERDDAP (rerddap)"
    site_years_all$query_status[i] <- "success"
    n_erddap <- n_erddap + 1
    Sys.sleep(0.5)  # Rate limit
    next
  }

  # Attempt 2: httr REST API
  dhw_val <- query_dhw_httr(lat, lon, yr)
  if (!is.null(dhw_val) && is.finite(dhw_val)) {
    site_years_all$max_dhw[i]      <- dhw_val
    site_years_all$dhw_source[i]   <- "ERDDAP (httr REST)"
    site_years_all$query_status[i] <- "success"
    n_httr <- n_httr + 1
    Sys.sleep(0.5)  # Rate limit
    next
  }

  # Attempt 3: Literature lookup table
  lut_result <- lookup_dhw_literature(reg, yr)
  if (!is.null(lut_result)) {
    site_years_all$max_dhw[i]      <- lut_result$dhw
    site_years_all$dhw_source[i]   <- lut_result$source
    site_years_all$query_status[i] <- "literature_lut"
    n_lut <- n_lut + 1
    next
  }

  # All methods failed
  site_years_all$query_status[i] <- "no_data"
  n_na <- n_na + 1
}
cat("\n\n")

cat("  Query results:\n")
cat(sprintf("    Cached reuse:         %d site-years\n", n_cached))
cat(sprintf("    ERDDAP (rerddap):    %d site-years\n", n_erddap))
cat(sprintf("    ERDDAP (httr REST):  %d site-years\n", n_httr))
cat(sprintf("    Literature LUT:      %d site-years\n", n_lut))
cat(sprintf("    Pre-1985 (NA):       %d site-years\n", n_pre1985_actual))
cat(sprintf("    No data (NA):        %d site-years\n", n_na))
cat(sprintf("    Total with DHW:      %d / %d (%.1f%%)\n",
            sum(!is.na(site_years_all$max_dhw)), n_total,
            sum(!is.na(site_years_all$max_dhw)) / n_total * 100))

# ==============================================================================
# SECTION 3: CLASSIFY HEAT STRESS
# ==============================================================================

print_header("3. Classifying heat stress")

# Standard NOAA CRW thermal stress thresholds (Degree Heating Weeks)
#   DHW = 0:       No stress
#   0 < DHW < 4:   Watch (minor heat stress)
#   4 <= DHW < 8:  Warning (moderate -- bleaching likely)
#   DHW >= 8:      Alert Level 2 (major -- mass bleaching & mortality expected)

site_years_all <- site_years_all %>%
  dplyr::mutate(
    heat_stress_category = dplyr::case_when(
      is.na(max_dhw)  ~ NA_character_,
      max_dhw == 0     ~ "none",
      max_dhw < 4      ~ "minor",
      max_dhw < 8      ~ "moderate",
      max_dhw >= 8     ~ "major",
      TRUE             ~ NA_character_
    ),
    heat_stress_category = factor(
      heat_stress_category,
      levels = c("none", "minor", "moderate", "major"),
      ordered = TRUE
    )
  )

# Summary
cat("  Heat stress classification:\n")
stress_summary <- site_years_all %>%
  dplyr::filter(!is.na(heat_stress_category)) %>%
  dplyr::count(heat_stress_category) %>%
  dplyr::mutate(pct = n / sum(n) * 100)
print(as.data.frame(stress_summary))

cat(sprintf("\n  DHW range: %.1f - %.1f (among sites with data)\n",
            min(site_years_all$max_dhw, na.rm = TRUE),
            max(site_years_all$max_dhw, na.rm = TRUE)))

# ==============================================================================
# SECTION 4: MERGE WITH SURVIVAL DATA
# ==============================================================================

print_header("4. Merging DHW with individual survival data")

# Create a lookup key for merging
dhw_lookup <- site_years_all %>%
  dplyr::select(lat_round, lon_round, survey_yr, max_dhw, heat_stress_category,
                dhw_source, query_status)

# Add rounded coordinates to individual survival data for merging
surv_with_dhw <- surv_ind %>%
  dplyr::mutate(
    lat_round = round(latitude, 1),
    lon_round = round(longitude, 1)
  ) %>%
  dplyr::left_join(dhw_lookup,
                   by = c("lat_round", "lon_round", "survey_yr")) %>%
  dplyr::select(-lat_round, -lon_round)

n_matched   <- sum(!is.na(surv_with_dhw$max_dhw))
n_total_ind <- nrow(surv_with_dhw)
cat(sprintf("  Matched %d / %d individual records (%.1f%%) with DHW data\n",
            n_matched, n_total_ind, n_matched / n_total_ind * 100))

# Summary by study
dhw_coverage <- surv_with_dhw %>%
  dplyr::group_by(study) %>%
  dplyr::summarise(
    n = n(),
    n_dhw = sum(!is.na(max_dhw)),
    pct_dhw = n_dhw / n * 100,
    mean_dhw = mean(max_dhw, na.rm = TRUE),
    max_dhw_val = if (all(is.na(max_dhw))) NA_real_ else max(max_dhw, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    mean_dhw = ifelse(is.nan(mean_dhw) | is.infinite(mean_dhw), NA_real_, mean_dhw),
    max_dhw_val = ifelse(is.infinite(max_dhw_val), NA_real_, max_dhw_val)
  )

cat("\n  DHW coverage by study:\n")
print(as.data.frame(dhw_coverage))

dhw_supported_studies <- dplyr::n_distinct(surv_with_dhw$study[!is.na(surv_with_dhw$max_dhw)])
dhw_supported_regions <- dplyr::n_distinct(surv_with_dhw$region[!is.na(surv_with_dhw$max_dhw)])
dhw_supported_study_years <- dplyr::n_distinct(
  surv_with_dhw %>%
    dplyr::filter(!is.na(max_dhw)) %>%
    dplyr::select(study, region, survey_yr)
)
dhw_support_label <- classify_dhw_support(
  n_rows = n_matched,
  n_studies = dhw_supported_studies,
  n_regions = dhw_supported_regions,
  n_study_years = dhw_supported_study_years
)
dhw_support_summary <- tibble::tibble(
  dhw_file = if (length(dhw_cache_file) == 1 && !is.na(dhw_cache_file)) basename(dhw_cache_file) else NA_character_,
  n_site_year_rows = nrow(site_years_all),
  n_site_year_rows_with_dhw = sum(!is.na(site_years_all$max_dhw)),
  n_survival_rows = n_total_ind,
  n_survival_rows_with_dhw = n_matched,
  pct_survival_rows_with_dhw = n_matched / n_total_ind * 100,
  n_studies_with_dhw = dhw_supported_studies,
  n_regions_with_dhw = dhw_supported_regions,
  n_unique_study_years_with_dhw = dhw_supported_study_years,
  n_query_error_rows = sum(site_years_all$query_status == "error", na.rm = TRUE),
  n_no_data_rows = sum(site_years_all$query_status == "no_data", na.rm = TRUE),
  inference_support = dhw_support_label,
  caveat = sprintf(
    "Verified DHW cache is preferred when present, but current support is often literature-LUT backed and is supported here by %d studies, %d regions, and %d study-years.",
    dhw_supported_studies,
    dhw_supported_regions,
    dhw_supported_study_years
  )
)

cat(sprintf(
  "\n  Support summary: %s (%d studies, %d regions, %d study-region-years)\n",
  dhw_support_summary$inference_support[1],
  dhw_support_summary$n_studies_with_dhw[1],
  dhw_support_summary$n_regions_with_dhw[1],
  dhw_support_summary$n_unique_study_years_with_dhw[1]
))

# ==============================================================================
# SECTION 5: ANALYZE HEAT STRESS IMPACT ON SURVIVAL
# ==============================================================================

print_header("5. Analyzing heat stress impact on survival")

# --- 5a. Survival by heat stress category ---
cat("  5a. Survival by heat stress category\n")

surv_by_stress <- surv_with_dhw %>%
  dplyr::filter(!is.na(heat_stress_category)) %>%
  dplyr::group_by(heat_stress_category) %>%
  dplyr::summarise(
    n = n(),
    n_survived = sum(survived),
    survival_rate = mean(survived),
    se = sqrt(survival_rate * (1 - survival_rate) / n()),
    n_studies = dplyr::n_distinct(study),
    mean_dhw = mean(max_dhw, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    ci_lower = pmax(0, survival_rate - 1.96 * se),
    ci_upper = pmin(1, survival_rate + 1.96 * se)
  )

cat("\n")
print(as.data.frame(surv_by_stress))

# --- 5b. GLMM: DHW effect on survival (controlling for size and study) ---
cat("\n  5b. GLMM: DHW effect on survival\n")

surv_for_model <- surv_with_dhw %>%
  dplyr::filter(!is.na(max_dhw) & !is.na(survived) & !is.na(size_cm2)) %>%
  dplyr::mutate(log_size = log(size_cm2 + 1))

dhw_glmm <- NULL
dhw_cor <- NULL
dhw_moderator <- NULL
if (nrow(surv_for_model) >= 50 && dplyr::n_distinct(surv_for_model$study) >= 2) {
  dhw_glmm <- tryCatch({
    lme4::glmer(survived ~ log_size + max_dhw + (1 | study),
                data = surv_for_model, family = binomial)
  }, error = function(e) {
    cat(sprintf("    GLMM failed: %s\n", e$message))
    NULL
  })

  if (!is.null(dhw_glmm)) {
    cat("\n    GLMM coefficients:\n")
    print(summary(dhw_glmm)$coefficients)

    # Overdispersion check
    od <- overdisp_test(dhw_glmm)
    cat(sprintf("\n    Overdispersion ratio: %.3f %s\n",
                od$ratio,
                if (od$overdispersed) "(WARNING: potential overdispersion)" else "(OK)"))

    # Extract DHW effect
    dhw_coef <- fixef(dhw_glmm)["max_dhw"]
    dhw_se   <- summary(dhw_glmm)$coefficients["max_dhw", "Std. Error"]
    dhw_z    <- summary(dhw_glmm)$coefficients["max_dhw", "z value"]
    dhw_p    <- summary(dhw_glmm)$coefficients["max_dhw", "Pr(>|z|)"]
    dhw_p_display <- if (identical(dhw_support_summary$inference_support[1], "sparse")) NA_real_ else dhw_p

    cat(sprintf("\n    DHW effect: %.4f (SE=%.4f, z=%.3f, p=%s)\n",
                dhw_coef, dhw_se, dhw_z,
                ifelse(is.na(dhw_p_display), "NA (descriptive only; sparse support)", sprintf("%.4f", dhw_p_display))))
    cat(sprintf("    Odds ratio per 1 DHW increase: %.4f\n", exp(dhw_coef)))
    if (identical(dhw_support_summary$inference_support[1], "sparse")) {
      cat("    Interpretation: descriptive association only; DHW support is too thin for inferential use.\n")
    } else {
      cat(sprintf("    Interpretation: Each additional DHW %s survival odds by %.1f%%\n",
                  ifelse(dhw_coef < 0, "decreases", "increases"),
                  abs(exp(dhw_coef) - 1) * 100))
    }
  }
}

# --- 5c. Correlation: DHW vs study-level survival ---
cat("\n  5c. Correlation between DHW and study-level survival\n")

study_level_dhw <- surv_with_dhw %>%
  dplyr::filter(!is.na(max_dhw)) %>%
  dplyr::group_by(study, region, survey_yr) %>%
  dplyr::summarise(
    n = n(),
    survival_rate = mean(survived),
    mean_dhw = mean(max_dhw, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::filter(n >= 10)  # Minimum sample size for reliable estimate

if (nrow(study_level_dhw) >= 5) {
  dhw_cor <- cor.test(study_level_dhw$mean_dhw, study_level_dhw$survival_rate,
                      method = "spearman", exact = FALSE)
  dhw_cor_p_display <- if (identical(dhw_support_summary$inference_support[1], "sparse")) NA_real_ else dhw_cor$p.value
  cat(sprintf("    Spearman rho = %.3f (p = %s, n = %d study-region-years)\n",
              dhw_cor$estimate,
              ifelse(is.na(dhw_cor_p_display), "NA (descriptive only; sparse support)", sprintf("%.4f", dhw_cor_p_display)),
              nrow(study_level_dhw)))
} else {
  cat(sprintf("    Insufficient study-level data for correlation (n = %d, need >= 5)\n",
              nrow(study_level_dhw)))
}

# --- 5d. Meta-analysis moderator: DHW effect on study-level survival ---
cat("\n  5d. Meta-analysis moderator test (DHW)\n")

meta_effects_file <- file.path(output_dir, "expanded_meta_analysis_study_effects.csv")
if (has_metafor && file.exists(meta_effects_file)) {
  library(metafor)

  meta_effects <- read_csv(meta_effects_file, show_col_types = FALSE)
  if (names(meta_effects)[1] %in% c("...1", "X1", "")) {
    meta_effects <- meta_effects %>% dplyr::select(-1)
  }

  cat(sprintf("    Loaded %d study effects from expanded meta-analysis\n", nrow(meta_effects)))

  # Match DHW to meta-analysis effects by study and region
  # Compute mean DHW per study-region across all years
  dhw_by_study_region <- site_years_all %>%
    dplyr::filter(!is.na(max_dhw)) %>%
    dplyr::group_by(study, region) %>%
    dplyr::summarise(
      mean_dhw = mean(max_dhw, na.rm = TRUE),
      max_dhw_val = max(max_dhw, na.rm = TRUE),
      n_years = n(),
      .groups = "drop"
    )

  # Attempt fuzzy matching on study name
  meta_with_dhw <- meta_effects %>%
    dplyr::left_join(dhw_by_study_region, by = c("study", "region"))

  # For NOAA split studies (NOAA_survey_florida_keys, etc.), try matching base name
  unmatched <- meta_with_dhw %>% dplyr::filter(is.na(mean_dhw))
  if (nrow(unmatched) > 0) {
    for (j in seq_len(nrow(unmatched))) {
      study_name <- unmatched$study[j]
      region_name <- unmatched$region[j]
      # Try matching on region alone (for NOAA splits)
      region_match <- dhw_by_study_region %>%
        dplyr::filter(region == region_name)
      if (nrow(region_match) > 0) {
        idx <- which(meta_with_dhw$study == study_name & meta_with_dhw$region == region_name)
        if (length(idx) == 1) {
          meta_with_dhw$mean_dhw[idx]    <- region_match$mean_dhw[1]
          meta_with_dhw$max_dhw_val[idx] <- region_match$max_dhw_val[1]
          meta_with_dhw$n_years[idx]     <- region_match$n_years[1]
        }
      }
    }
  }

  n_meta_dhw <- sum(!is.na(meta_with_dhw$mean_dhw))
  cat(sprintf("    Matched %d / %d effects with DHW data\n",
              n_meta_dhw, nrow(meta_with_dhw)))

  # Run moderator test if we have enough matched effects and required columns
  yi_col <- intersect(c("yi", "logit_surv", "plo"), names(meta_with_dhw))
  vi_col <- intersect(c("vi", "var_logit", "var_plo"), names(meta_with_dhw))

  if (identical(dhw_support_summary$inference_support[1], "sparse")) {
    cat("    Moderator test suppressed: DHW support is sparse, so this layer is descriptive only.\n")
  } else if (n_meta_dhw >= 5 && length(yi_col) > 0 && length(vi_col) > 0) {
    meta_subset <- meta_with_dhw %>%
      dplyr::filter(!is.na(mean_dhw) & !is.na(.data[[yi_col[1]]]) & !is.na(.data[[vi_col[1]]]))

    if (nrow(meta_subset) >= 5) {
      dhw_moderator <- tryCatch({
        metafor::rma(yi = meta_subset[[yi_col[1]]],
                     vi = meta_subset[[vi_col[1]]],
                     mods = ~ mean_dhw,
                     method = "REML",
                     test = "knha",
                     data = meta_subset)
      }, error = function(e) {
        cat(sprintf("    Moderator model failed: %s\n", e$message))
        NULL
      })

      if (!is.null(dhw_moderator)) {
        cat("\n    DHW moderator test results:\n")
        print(dhw_moderator)

        dhw_mod_coef <- coef(dhw_moderator)["mean_dhw"]
        dhw_mod_p    <- dhw_moderator$pval[2]
        cat(sprintf("\n    DHW moderator: coefficient = %.4f, p = %.4f\n",
                    dhw_mod_coef, dhw_mod_p))
        cat("    Interpretation: moderator fit retained as exploratory support, not a primary inferential claim.\n")
      }
    } else {
      cat("    Insufficient matched effects for moderator analysis after filtering\n")
    }
  } else {
    cat(sprintf("    Cannot run moderator test: %d matched effects, need >= 5\n", n_meta_dhw))
    if (length(yi_col) == 0 || length(vi_col) == 0) {
      cat("    Could not identify effect size (yi) or variance (vi) columns in meta-analysis data\n")
    }
  }
} else {
  if (!has_metafor) cat("    metafor package not available -- skipping moderator test\n")
  if (!file.exists(meta_effects_file)) {
    cat(sprintf("    Meta-analysis effects file not found: %s\n", meta_effects_file))
    cat("    Run script 14b_expanded_meta_analysis.R first\n")
  }
}

# ==============================================================================
# SECTION 6: SAVE OUTPUTS
# ==============================================================================

print_header("6. Saving outputs")

# --- 6a. Full DHW lookup table ---
dhw_output <- site_years_all %>%
  dplyr::select(study, region, lat_round, lon_round, survey_yr,
                max_dhw, heat_stress_category, dhw_source, query_status)

write_csv(dhw_output, file.path(output_dir, "heat_stress_by_site_year.csv"))
cat(sprintf("  Saved: heat_stress_by_site_year.csv (%d rows)\n", nrow(dhw_output)))

# --- 6b. Survival analysis by heat stress category ---
analysis_output <- list()
analysis_output$survival_by_category <- surv_by_stress
dhw_diag_rows <- list(
  tibble::tibble(
    component = "support_summary",
    analysis_mode = ifelse(identical(dhw_support_summary$inference_support[1], "sparse"), "descriptive_only", "screening"),
    n_obs = dhw_support_summary$n_survival_rows_with_dhw[1],
    n_studies = dhw_support_summary$n_studies_with_dhw[1],
    n_regions = dhw_support_summary$n_regions_with_dhw[1],
    n_study_years = dhw_support_summary$n_unique_study_years_with_dhw[1],
    estimate = NA_real_,
    p_value = NA_real_,
    aic = NA_real_,
    bic = NA_real_,
    log_likelihood = NA_real_,
    overdispersion_ratio = NA_real_,
    overdispersed = NA,
    inference_support = dhw_support_summary$inference_support[1],
    note = dhw_support_summary$caveat[1]
  )
)

if (!is.null(dhw_glmm)) {
  glmm_coefs <- as.data.frame(summary(dhw_glmm)$coefficients)
  glmm_coefs$term <- rownames(glmm_coefs)
  analysis_output$glmm_coefficients <- glmm_coefs

  dhw_diag_rows[[length(dhw_diag_rows) + 1]] <- tibble::tibble(
    component = "dhw_glmm",
    analysis_mode = ifelse(identical(dhw_support_summary$inference_support[1], "sparse"), "descriptive_only", "inferential_screen"),
    n_obs = nobs(dhw_glmm),
    n_studies = dplyr::n_distinct(surv_for_model$study),
    n_regions = dplyr::n_distinct(surv_for_model$region),
    n_study_years = dplyr::n_distinct(surv_for_model %>% dplyr::select(study, region, survey_yr)),
    estimate = unname(fixef(dhw_glmm)["max_dhw"]),
    p_value = if (identical(dhw_support_summary$inference_support[1], "sparse")) NA_real_ else {
      summary(dhw_glmm)$coefficients["max_dhw", "Pr(>|z|)"]
    },
    aic = AIC(dhw_glmm),
    bic = BIC(dhw_glmm),
    log_likelihood = as.numeric(logLik(dhw_glmm)),
    overdispersion_ratio = od$ratio,
    overdispersed = od$overdispersed,
    inference_support = dhw_support_summary$inference_support[1],
    note = ifelse(
      identical(dhw_support_summary$inference_support[1], "sparse"),
      "DHW GLMM retained as descriptive screening only because independent support is sparse.",
      "DHW GLMM fit on DHW-matched survival subset."
    )
  )
}

if (!is.null(dhw_cor)) {
  analysis_output$correlation <- data.frame(
    method = "Spearman",
    rho = as.numeric(dhw_cor$estimate),
    p_value = ifelse(identical(dhw_support_summary$inference_support[1], "sparse"), NA_real_, dhw_cor$p.value),
    n = nrow(study_level_dhw)
  )

  dhw_diag_rows[[length(dhw_diag_rows) + 1]] <- tibble::tibble(
    component = "study_level_correlation",
    analysis_mode = ifelse(identical(dhw_support_summary$inference_support[1], "sparse"), "descriptive_only", "inferential_screen"),
    n_obs = nrow(study_level_dhw),
    n_studies = dplyr::n_distinct(study_level_dhw$study),
    n_regions = dplyr::n_distinct(study_level_dhw$region),
    n_study_years = nrow(study_level_dhw),
    estimate = as.numeric(dhw_cor$estimate),
    p_value = ifelse(identical(dhw_support_summary$inference_support[1], "sparse"), NA_real_, dhw_cor$p.value),
    aic = NA_real_,
    bic = NA_real_,
    log_likelihood = NA_real_,
    overdispersion_ratio = NA_real_,
    overdispersed = NA,
    inference_support = dhw_support_summary$inference_support[1],
    note = "Study-level DHW-survival correlation; treat as descriptive when support is sparse."
  )
}

if (!is.null(dhw_moderator)) {
  dhw_diag_rows[[length(dhw_diag_rows) + 1]] <- tibble::tibble(
    component = "meta_moderator",
    analysis_mode = "exploratory_support",
    n_obs = dhw_moderator$k,
    n_studies = dhw_moderator$k,
    n_regions = dplyr::n_distinct(meta_subset$region),
    n_study_years = sum(meta_subset$n_years, na.rm = TRUE),
    estimate = unname(coef(dhw_moderator)["mean_dhw"]),
    p_value = dhw_moderator$pval[2],
    aic = AIC(dhw_moderator),
    bic = BIC(dhw_moderator),
    log_likelihood = as.numeric(logLik(dhw_moderator)),
    overdispersion_ratio = NA_real_,
    overdispersed = NA,
    inference_support = dhw_support_summary$inference_support[1],
    note = "Exploratory DHW moderator on matched study-level effects."
  )
}

dhw_diag <- dplyr::bind_rows(dhw_diag_rows)
write_csv(dhw_diag, file.path(output_dir, "heat_stress_model_diagnostics.csv"))
cat(sprintf("  Saved: heat_stress_model_diagnostics.csv (%d rows)\n", nrow(dhw_diag)))

# Combine into one summary table
analysis_summary <- surv_by_stress %>%
  dplyr::mutate(
    analysis_type = "survival_by_category",
    analysis_mode = ifelse(identical(dhw_support_summary$inference_support[1], "sparse"), "descriptive_only", "supporting_summary"),
    inference_support = dhw_support_summary$inference_support[1],
    caveat = dhw_support_summary$caveat[1]
  ) %>%
  dplyr::select(analysis_type, heat_stress_category, n, survival_rate, se,
                ci_lower, ci_upper, n_studies, mean_dhw, analysis_mode,
                inference_support, caveat)

write_csv(analysis_summary, file.path(output_dir, "heat_stress_survival_analysis.csv"))
cat(sprintf("  Saved: heat_stress_survival_analysis.csv (%d rows)\n", nrow(analysis_summary)))

# ==============================================================================
# SECTION 7: FIGURE -- FigSXX_heat_stress_survival
# ==============================================================================

print_header("7. Creating heat stress figure")

# Define heat stress colors (NOAA CRW-inspired palette)
heat_colors <- c(
  "none"     = "#2166AC",  # Blue -- no stress
  "minor"    = "#FDDBC7",  # Light orange -- watch
  "moderate" = "#F4A582",  # Orange -- warning
  "major"    = "#B2182B"   # Red -- alert level 2
)

heat_labels <- c(
  "none"     = "No stress\n(DHW = 0)",
  "minor"    = "Minor\n(0 < DHW < 4)",
  "moderate" = "Moderate\n(4 \u2264 DHW < 8)",
  "major"    = "Major\n(DHW \u2265 8)"
)

# Only create figure if we have data
if (sum(!is.na(surv_with_dhw$heat_stress_category)) >= 20) {

  # --- Panel a: Survival by heat stress category ---
  plot_data_a <- surv_by_stress %>%
    dplyr::filter(!is.na(heat_stress_category))

  if (nrow(plot_data_a) > 0) {
    p_a <- ggplot(plot_data_a,
                  aes(x = heat_stress_category, y = survival_rate,
                      fill = heat_stress_category)) +
      geom_col(width = 0.7, color = "grey30", linewidth = 0.3) +
      geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper),
                    width = 0.2, linewidth = 0.4) +
      geom_text(aes(y = 0.03, label = paste0("n=", n)),
                size = 3, color = "grey40") +
      scale_fill_manual(values = heat_colors, guide = "none") +
      scale_x_discrete(labels = heat_labels) +
      scale_y_continuous(limits = c(0, 1), expand = expansion(mult = c(0, 0.02))) +
      labs(x = "Heat stress category", y = "Annual survival rate") +
      theme_manuscript(base_size = 10) +
      theme(axis.text.x = element_text(size = 8))
  } else {
    p_a <- ggplot() + annotate("text", x = 0.5, y = 0.5, label = "Insufficient data") +
      theme_void()
  }

  # --- Panel b: DHW vs survival (scatter with study-level points) ---
  if (nrow(study_level_dhw) >= 3) {
    p_b <- ggplot(study_level_dhw,
                  aes(x = mean_dhw, y = survival_rate)) +
      geom_point(aes(size = n), alpha = 0.7, color = MANUSCRIPT_PALETTE$surv_mid) +
      geom_smooth(method = "lm", se = TRUE, color = MANUSCRIPT_PALETTE$accent,
                  linewidth = 0.8, alpha = 0.15) +
      scale_size_continuous(range = c(2, 8), name = "Sample size") +
      scale_y_continuous(limits = c(0, 1)) +
      labs(x = "Mean annual max DHW",
           y = "Annual survival rate") +
      theme_manuscript(base_size = 10) +
      theme(legend.position = "bottom",
            legend.key.size = unit(4, "mm"))

    # Add correlation annotation if available
    if (!is.null(dhw_cor)) {
      cor_label <- if (identical(dhw_support_summary$inference_support[1], "sparse")) {
        sprintf("rho = %.2f\nsupport = %s", dhw_cor$estimate, dhw_support_summary$inference_support[1])
      } else {
        sprintf("rho = %.2f, p = %.3f", dhw_cor$estimate, dhw_cor$p.value)
      }
      p_b <- p_b +
        annotate("text", x = Inf, y = Inf,
                 label = cor_label,
                 hjust = 1.1, vjust = 1.5, size = 3.5, color = "grey30")
    }
  } else {
    p_b <- ggplot() + annotate("text", x = 0.5, y = 0.5, label = "Insufficient data") +
      theme_void()
  }

  # --- Panel c: DHW timeline for major sites ---
  dhw_timeline <- site_years_all %>%
    dplyr::filter(!is.na(max_dhw)) %>%
    dplyr::group_by(study, region, lat_round, lon_round, survey_yr) %>%
    dplyr::summarise(
      max_dhw = if (all(is.na(max_dhw))) NA_real_ else max(max_dhw, na.rm = TRUE),
      heat_stress_category = dplyr::first(heat_stress_category),
      .groups = "drop"
    )

  if (nrow(dhw_timeline) >= 5) {
    p_c <- ggplot(dhw_timeline,
                  aes(x = survey_yr, y = max_dhw, color = region, group = interaction(study, lat_round))) +
      # Stress threshold bands
      annotate("rect", xmin = -Inf, xmax = Inf, ymin = 4, ymax = 8,
               fill = "#F4A582", alpha = 0.15) +
      annotate("rect", xmin = -Inf, xmax = Inf, ymin = 8, ymax = Inf,
               fill = "#B2182B", alpha = 0.10) +
      geom_hline(yintercept = c(4, 8), linetype = "dashed",
                 color = "grey60", linewidth = 0.3) +
      geom_point(size = 2.5, alpha = 0.8) +
      geom_line(alpha = 0.4, linewidth = 0.4) +
      scale_color_manual(values = OKABE_ITO[seq_len(min(length(OKABE_ITO),
                                                        dplyr::n_distinct(dhw_timeline$region)))],
                         name = "Region") +
      annotate("text", x = min(dhw_timeline$survey_yr) - 0.5, y = 6,
               label = "Bleaching\nlikely", size = 2.5, hjust = 0, color = "grey40") +
      annotate("text", x = min(dhw_timeline$survey_yr) - 0.5, y = 10,
               label = "Mass bleaching\nexpected", size = 2.5, hjust = 0, color = "grey40") +
      labs(x = "Year", y = "Max annual DHW (\u00B0C-weeks)") +
      theme_manuscript(base_size = 10) +
      theme(legend.position = "bottom",
            legend.key.size = unit(3, "mm"),
            legend.text = element_text(size = 7))
  } else {
    p_c <- ggplot() + annotate("text", x = 0.5, y = 0.5, label = "Insufficient data") +
      theme_void()
  }

  # --- Combine panels ---
  fig_combined <- (p_a | p_b) / p_c +
    plot_layout(heights = c(1, 1)) +
    plot_annotation(tag_levels = "a") &
    theme(plot.tag = element_text(face = "bold", size = 12))

  # Save figure
  fig_path <- file.path(fig_dir, "FigSXX_heat_stress_survival")
  ggsave(paste0(fig_path, ".png"), plot = fig_combined,
         width = 174, height = 180, units = "mm", dpi = 300, bg = "white")

  # PDF with fallback device
  pdf_device <- if (capabilities("cairo")) cairo_pdf else "pdf"
  ggsave(paste0(fig_path, ".pdf"), plot = fig_combined,
         width = 174, height = 180, units = "mm", bg = "white",
         device = pdf_device)

  cat(sprintf("  Saved: FigSXX_heat_stress_survival (.png + .pdf) -- 174 x 180 mm\n"))

} else {
  cat("  Insufficient DHW-matched data for figure (need >= 20 observations)\n")
  cat("  This likely means ERDDAP was unreachable and no literature LUT matches.\n")
}

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n")
cat("==============================================================================\n")
cat("  HEAT STRESS OVERLAY COMPLETE\n")
cat("==============================================================================\n\n")

cat("KEY FINDINGS:\n")
cat(sprintf("  Site-years queried: %d\n", n_total))
cat(sprintf("  Site-years with DHW: %d (%.1f%%)\n",
            sum(!is.na(site_years_all$max_dhw)),
            sum(!is.na(site_years_all$max_dhw)) / n_total * 100))
cat(sprintf("  Individual records matched: %d / %d (%.1f%%)\n",
            n_matched, n_total_ind, n_matched / n_total_ind * 100))
cat(sprintf("  DHW support: %s (%d studies, %d regions, %d study-region-years)\n",
            dhw_support_summary$inference_support[1],
            dhw_support_summary$n_studies_with_dhw[1],
            dhw_support_summary$n_regions_with_dhw[1],
            dhw_support_summary$n_unique_study_years_with_dhw[1]))

if (nrow(surv_by_stress) > 0) {
  cat("\n  Survival by heat stress:\n")
  for (i in seq_len(nrow(surv_by_stress))) {
    cat(sprintf("    %s: %.1f%% (n=%d, %d studies)\n",
                as.character(surv_by_stress$heat_stress_category[i]),
                surv_by_stress$survival_rate[i] * 100,
                surv_by_stress$n[i],
                surv_by_stress$n_studies[i]))
  }
}

if (!is.null(dhw_glmm)) {
  dhw_coef <- fixef(dhw_glmm)["max_dhw"]
  dhw_p_display <- if (identical(dhw_support_summary$inference_support[1], "sparse")) NA_real_ else {
    summary(dhw_glmm)$coefficients["max_dhw", "Pr(>|z|)"]
  }
  cat(sprintf("\n  GLMM: DHW effect on survival = %.4f (p = %s)\n",
              dhw_coef,
              ifelse(is.na(dhw_p_display), "NA (descriptive only; sparse support)", sprintf("%.4f", dhw_p_display))))
  if (identical(dhw_support_summary$inference_support[1], "sparse")) {
    cat("    Treat the DHW slope as supportive climate context, not strong attribution.\n")
  } else {
    cat(sprintf("    Each +1 DHW: %.1f%% change in survival odds\n",
                (exp(dhw_coef) - 1) * 100))
  }
}

cat("\nOutputs:\n")
cat("  - heat_stress_by_site_year.csv\n")
cat("  - heat_stress_survival_analysis.csv\n")
cat("  - heat_stress_model_diagnostics.csv\n")
cat("  - FigSXX_heat_stress_survival.png/.pdf\n")
cat("\n")
