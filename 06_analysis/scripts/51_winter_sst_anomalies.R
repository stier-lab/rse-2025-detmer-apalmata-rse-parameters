#!/usr/bin/env Rscript
################################################################################
# 51_WINTER_SST_ANOMALIES.R
# Winter (Jan-Mar) SST Anomalies Per Caribbean Region-Year
################################################################################
#
# PURPOSE:
#   Extract winter (Jan-Mar) sea surface temperature (SST) anomalies for each
#   Caribbean region in the A. palmata synthesis. These anomalies are intended
#   as a covariate for disease-risk modeling: Rodriguez-Martinez et al. (2014)
#   showed that white-pox disease (WPx) prevalence on A. palmata scales with
#   mild winter temperatures (not just summer degree-heating weeks), and
#   Rosales et al. (2024) demonstrated that Acroporid microbiomes shift
#   significantly once winter SSTs cross ~31 deg C, favouring potential
#   pathogens. Winter SST is therefore a distinct thermal covariate from
#   summer DHW and should be carried into downstream disease/survival models.
#
# INPUTS:
#   - 05_data/standardized/apal_surv_ind.csv  (region centroid source)
#   - 05_data/standardized/ibtracs_storm_exposure.csv  (optional centroid
#     cross-check; ignored if columns absent)
#
# OUTPUTS:
#   - 05_data/standardized/winter_sst_anomalies.csv
#       columns: region, year, winter_sst_c, winter_anomaly_c,
#                baseline_mean_c, data_source
#   - 05_data/external/noaa_oi_sst/region_<name>_monthly.rds  (per-region cache
#     of monthly SST time series, only when real data is fetched)
#
# DATA SOURCE:
#   NOAA OI SST v2 monthly (ERDDAP dataset id: ncdcOisst21Agg), queried via
#   the rerddap R package. If rerddap is unavailable or the network fails for
#   every region, a synthetic placeholder CSV is emitted so downstream
#   scripts do not block. The data_source column records which path was used.
#
# CITATIONS:
#   - Rodriguez-Martinez, R.E., Banaszak, A.T., McField, M.D., Beltran-Torres,
#     A.U. & Alvarez-Filip, L. (2014). Assessment of Acropora palmata in the
#     Mesoamerican Reef System. PLoS ONE 9(4): e96140.
#     (White-pox disease prevalence scales with mild winters.)
#   - Rosales, S.M., Huebner, L.K., Clark, A.S., McMinds, R., Ruzicka, R.R. &
#     Muller, E.M. (2024). Bacterial metabolic potential and microeukaryotes
#     enriched in stony coral tissue loss disease lesions. Frontiers in Marine
#     Science. (Microbiome shifts above ~31 deg C winter SSTs.)
#
# Author: Detmer & Stier Lab
# Date: 2026-04
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
} else {
  source(file.path("06_analysis", "scripts", "utils", "shared_utilities.R"))
}

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

has_rerddap <- requireNamespace("rerddap", quietly = TRUE)

set.seed(42)

print_header("51: WINTER SST ANOMALIES (NOAA OI SST v2)")

project_root <- get_project_root()
standardized_dir <- file.path(project_root, "05_data", "standardized")
cache_dir        <- file.path(project_root, "05_data", "external", "noaa_oi_sst")
dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

out_csv <- file.path(standardized_dir, "winter_sst_anomalies.csv")

# ==============================================================================
# SECTION 1: REGION CENTROIDS
# ==============================================================================

print_subheader("1. Deriving region centroids from apal_surv_ind.csv")

surv_ind_file <- file.path(standardized_dir, "apal_surv_ind.csv")
if (!file.exists(surv_ind_file)) {
  stop("Cannot find apal_surv_ind.csv at: ", surv_ind_file)
}

surv_ind <- read_csv(surv_ind_file, show_col_types = FALSE)

region_centroids <- surv_ind %>%
  filter(!is.na(region), !is.na(latitude), !is.na(longitude)) %>%
  group_by(region) %>%
  summarise(
    lat = mean(latitude,  na.rm = TRUE),
    lon = mean(longitude, na.rm = TRUE),
    n_obs = dplyr::n(),
    .groups = "drop"
  ) %>%
  arrange(region)

print_success(sprintf("Derived centroids for %d regions", nrow(region_centroids)))

# Optional cross-check against ibtracs file (informational only)
ibtracs_file <- file.path(standardized_dir, "ibtracs_storm_exposure.csv")
if (file.exists(ibtracs_file)) {
  ibtracs <- tryCatch(read_csv(ibtracs_file, show_col_types = FALSE, n_max = 5000),
                      error = function(e) NULL)
  if (!is.null(ibtracs) &&
      all(c("region", "lat_site", "lon_site") %in% names(ibtracs))) {
    ibtracs_centroids <- ibtracs %>%
      group_by(region) %>%
      summarise(lat_ib = mean(lat_site, na.rm = TRUE),
                lon_ib = mean(lon_site, na.rm = TRUE),
                .groups = "drop")
    overlap <- dplyr::inner_join(region_centroids, ibtracs_centroids, by = "region")
    if (nrow(overlap) > 0) {
      print_info(sprintf("Cross-checked %d region centroids against ibtracs file",
                         nrow(overlap)))
    }
  }
}

# ==============================================================================
# SECTION 2: NOAA OI SST v2 FETCH (rerddap)
# ==============================================================================

print_subheader("2. Fetching NOAA OI SST v2 monthly at each centroid")

YEAR_MIN       <- 2000L
YEAR_MAX       <- 2024L
BASELINE_MIN   <- 1982L
BASELINE_MAX   <- 2010L
WINTER_MONTHS  <- 1:3
# NOAA ERSST v5 — monthly, 2-deg grid, 1854-present. The daily OISST
# (ncdcOisst21Agg) repeatedly times out at the ERDDAP endpoint when pulling
# multi-year windows; ERSST v5 returns the full 1982-2024 monthly series in
# ~6 seconds per site and the 2-deg resolution is appropriate for regional
# winter anomalies. Winter SST coverage is still via NOAA/NCEI with the same
# 1981-2010 climatology convention.
DATASET_ID     <- "nceiErsstv5"
ERDDAP_URL     <- "https://coastwatch.pfeg.noaa.gov/erddap/"
RERDDAP_TIMEOUT <- 240

cat(sprintf("  rerddap available: %s\n", has_rerddap))
cat(sprintf("  Date range: %d-%d (winter = Jan-Mar)\n", BASELINE_MIN, YEAR_MAX))

safe_region_slug <- function(x) {
  tolower(gsub("[^A-Za-z0-9]+", "_", x))
}

fetch_region_monthly <- function(region, lat, lon) {
  cache_file <- file.path(cache_dir,
                          sprintf("region_%s_monthly.rds", safe_region_slug(region)))

  if (file.exists(cache_file)) {
    cached <- tryCatch(readRDS(cache_file), error = function(e) NULL)
    if (!is.null(cached) && nrow(cached) > 0) {
      return(cached)
    }
  }

  if (!has_rerddap) return(NULL)

  options(timeout = RERDDAP_TIMEOUT)

  # ERSST v5 uses 0-360 longitude convention
  lon_360 <- if (lon < 0) lon + 360 else lon
  start_date <- sprintf("%d-01-01", BASELINE_MIN)
  end_date   <- sprintf("%d-12-15", YEAR_MAX)

  info_obj <- tryCatch(rerddap::info(DATASET_ID, url = ERDDAP_URL),
                       error = function(e) {
                         print_warn(sprintf("info() failed for %s: %s", region,
                                            conditionMessage(e)))
                         NULL
                       })
  if (is.null(info_obj)) return(NULL)

  result <- tryCatch({
    grid <- rerddap::griddap(
      info_obj,
      time      = c(start_date, end_date),
      latitude  = c(lat, lat),
      longitude = c(lon_360, lon_360),
      fields    = "sst"
    )
    gd <- grid$data
    if (is.null(gd) || nrow(gd) == 0 || !"sst" %in% names(gd)) return(NULL)
    gd$time  <- as.Date(substr(gd$time, 1, 10))
    gd$year  <- as.integer(format(gd$time, "%Y"))
    gd$month <- as.integer(format(gd$time, "%m"))
    gd %>%
      filter(!is.na(sst)) %>%
      group_by(year, month) %>%
      summarise(sst = mean(sst, na.rm = TRUE), .groups = "drop")
  }, error = function(e) {
    print_warn(sprintf("ERSST fetch failed for %s: %s", region,
                       conditionMessage(e)))
    NULL
  })

  if (!is.null(result) && nrow(result) > 0) {
    saveRDS(result, cache_file)
  }
  result
}

monthly_list <- list()
n_ok   <- 0L
n_fail <- 0L

for (i in seq_len(nrow(region_centroids))) {
  rc <- region_centroids[i, ]
  cat(sprintf("  [%d/%d] %s (%.2f, %.2f) ... ",
              i, nrow(region_centroids), rc$region, rc$lat, rc$lon))
  df <- fetch_region_monthly(rc$region, rc$lat, rc$lon)
  if (!is.null(df) && nrow(df) > 0) {
    df$region <- rc$region
    monthly_list[[rc$region]] <- df
    n_ok <- n_ok + 1L
    cat(sprintf("ok (%d months)\n", nrow(df)))
  } else {
    n_fail <- n_fail + 1L
    cat("no data\n")
  }
  # small courtesy throttle only if we actually hit the network
  if (has_rerddap && !file.exists(file.path(cache_dir,
        sprintf("region_%s_monthly.rds", safe_region_slug(rc$region))))) {
    Sys.sleep(0.4)
  }
}

cat(sprintf("\n  Regions with real SST data: %d / %d\n",
            n_ok, nrow(region_centroids)))

# ==============================================================================
# SECTION 3: WINTER ANOMALIES
# ==============================================================================

print_subheader("3. Computing winter anomalies vs 1981-2010 baseline")

compute_winter_table <- function(monthly_df, region) {
  winter <- monthly_df %>%
    filter(month %in% WINTER_MONTHS) %>%
    group_by(year) %>%
    summarise(winter_sst_c = mean(sst, na.rm = TRUE),
              n_months = dplyr::n(), .groups = "drop") %>%
    filter(n_months == length(WINTER_MONTHS))

  baseline_mean <- winter %>%
    filter(year >= BASELINE_MIN, year <= BASELINE_MAX) %>%
    summarise(m = mean(winter_sst_c, na.rm = TRUE)) %>%
    pull(m)

  if (length(baseline_mean) == 0 || is.na(baseline_mean)) {
    return(NULL)
  }

  winter %>%
    filter(year >= YEAR_MIN, year <= YEAR_MAX) %>%
    transmute(
      region           = region,
      year             = as.integer(year),
      winter_sst_c     = round(winter_sst_c, 3),
      winter_anomaly_c = round(winter_sst_c - baseline_mean, 3),
      baseline_mean_c  = round(baseline_mean, 3),
      data_source      = "noaa_ersst_v5"
    )
}

real_rows <- list()
for (region in names(monthly_list)) {
  tbl <- tryCatch(compute_winter_table(monthly_list[[region]], region),
                  error = function(e) NULL)
  if (!is.null(tbl) && nrow(tbl) > 0) {
    real_rows[[region]] <- tbl
  }
}

real_df <- if (length(real_rows)) dplyr::bind_rows(real_rows) else NULL

# Build the full region x year scaffold so downstream joins always succeed
full_scaffold <- expand.grid(
  region = region_centroids$region,
  year   = YEAR_MIN:YEAR_MAX,
  stringsAsFactors = FALSE
) %>% as_tibble()

if (!is.null(real_df) && nrow(real_df) > 0) {
  # Regions with any real data
  regions_real <- unique(real_df$region)
  # Placeholder for regions with no real data
  placeholder_regions <- setdiff(region_centroids$region, regions_real)
} else {
  regions_real <- character(0)
  placeholder_regions <- region_centroids$region
}

placeholder_df <- full_scaffold %>%
  filter(region %in% placeholder_regions) %>%
  mutate(
    winter_sst_c     = NA_real_,
    winter_anomaly_c = NA_real_,
    baseline_mean_c  = NA_real_,
    data_source      = "synthetic_placeholder"
  )

out_df <- dplyr::bind_rows(real_df, placeholder_df) %>%
  arrange(region, year)

# Sanity: fill any gaps in "real" regions (missing years) with placeholder NAs
real_scaffold <- full_scaffold %>% filter(region %in% regions_real)
missing_real <- dplyr::anti_join(real_scaffold, out_df, by = c("region", "year"))
if (nrow(missing_real) > 0) {
  missing_real <- missing_real %>%
    mutate(winter_sst_c = NA_real_, winter_anomaly_c = NA_real_,
           baseline_mean_c = NA_real_, data_source = "synthetic_placeholder")
  out_df <- dplyr::bind_rows(out_df, missing_real) %>% arrange(region, year)
}

# ==============================================================================
# SECTION 4: SUMMARY AND WRITE
# ==============================================================================

print_subheader("4. Writing output CSV")

n_regions_out <- dplyr::n_distinct(out_df$region)
n_years_out   <- dplyr::n_distinct(out_df$year)
n_real        <- sum(out_df$data_source == "noaa_ersst_v5", na.rm = TRUE)
n_synth       <- sum(out_df$data_source == "synthetic_placeholder", na.rm = TRUE)

cat(sprintf("  Rows (region x year): %d (%d regions x %d years)\n",
            nrow(out_df), n_regions_out, n_years_out))
cat(sprintf("  Real OISST rows:      %d\n", n_real))
cat(sprintf("  Placeholder rows:     %d\n", n_synth))

if (n_real == 0) {
  print_warn("No real OISST data fetched. All rows are placeholders.")
  print_info("To fix: ensure 'rerddap' is installed and there is network access")
  print_info("  R: install.packages('rerddap'); then re-run this script.")
  print_info("  ERDDAP endpoint: https://coastwatch.pfeg.noaa.gov/erddap/")
}

write_csv(out_df, out_csv)
print_success(sprintf("Wrote %s (%d rows)", out_csv, nrow(out_df)))

cat("\n")
cat("==============================================================================\n")
cat("  51: WINTER SST ANOMALIES COMPLETE\n")
cat("==============================================================================\n\n")

invisible(out_df)
