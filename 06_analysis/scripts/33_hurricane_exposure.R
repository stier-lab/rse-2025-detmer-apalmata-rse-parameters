#!/usr/bin/env Rscript
################################################################################
# 33_HURRICANE_EXPOSURE.R
# Tropical Cyclone Exposure for A. palmata Study Sites (IBTrACS)
################################################################################
#
# PURPOSE:
#   Query the IBTrACS database to identify ALL tropical cyclones that passed
#   within 200 km of our study sites. This provides a comprehensive disturbance
#   history for interpreting demographic patterns across regions.
#
# APPROACH:
#   1. Download IBTrACS Atlantic basin CSV (~150 MB) to /tmp/ (cached)
#   2. Define representative coordinates for each of our 15 study regions
#   3. Compute great-circle (Haversine) distance from each 6-hourly storm
#      position to each site
#   4. Filter to storms passing within 200 km; flag direct hits (<50 km)
#   5. Extract storm metadata at closest approach
#   6. Summarize exposure by region and category
#
# INPUTS:
#   - IBTrACS NA basin: https://www.ncei.noaa.gov/data/international-best-track-
#     archive-for-climate-stewardship-ibtracs/v04r01/access/csv/
#     ibtracs.NA.list.v04r01.csv
#
# OUTPUTS:
#   - 05_data/standardized/ibtracs_storm_exposure.csv
#   - 06_analysis/output/hurricane_exposure_summary.csv
#
# NOTES:
#   - IBTrACS CSV has a units row (row 2) that must be skipped
#   - USA_SSHS: -5=unknown, -4=post-tropical, -3=misc, -2=subtropical,
#     -1=tropical depression, 0=tropical storm, 1-5=hurricane categories
#   - Filtered to 1979+ (earliest study in our synthesis)
#   - Haversine formula used for great-circle distance
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
library(lubridate)

# Resolve project root
project_root <- if (file.exists("06_analysis/scripts/33_hurricane_exposure.R")) {
  "."
} else if (file.exists("33_hurricane_exposure.R")) {
  "../.."
} else {
  stop("Cannot determine project root. Run from project root or 06_analysis/scripts/")
}

set.seed(42)

cat("=== 33: Hurricane Exposure Analysis (IBTrACS) ===\n\n")

# ==============================================================================
# 1. DOWNLOAD IBTrACS ATLANTIC BASIN CSV
# ==============================================================================

ibtracs_url <- paste0(
  "https://www.ncei.noaa.gov/data/international-best-track-archive-for-",
  "climate-stewardship-ibtracs/v04r01/access/csv/ibtracs.NA.list.v04r01.csv"
)
ibtracs_local <- "/tmp/ibtracs_NA.csv"

if (!file.exists(ibtracs_local)) {
  cat("Downloading IBTrACS Atlantic basin CSV (~150 MB)...\n")
  cat("URL:", ibtracs_url, "\n")

  download_result <- tryCatch({
    download.file(ibtracs_url, ibtracs_local, mode = "wb", quiet = FALSE)
    TRUE
  }, error = function(e) {
    cat("ERROR downloading IBTrACS:", conditionMessage(e), "\n")
    FALSE
  })

  if (!download_result || !file.exists(ibtracs_local)) {
    stop("Failed to download IBTrACS data. Check internet connection.")
  }

  cat("Download complete:", round(file.size(ibtracs_local) / 1e6, 1), "MB\n\n")
} else {
  cat("IBTrACS file already cached at", ibtracs_local, "\n")
  cat("Size:", round(file.size(ibtracs_local) / 1e6, 1), "MB\n\n")
}

# ==============================================================================
# 2. READ IBTrACS DATA
# ==============================================================================

cat("Reading IBTrACS data (skipping units row)...\n")

# Read the header row first to get column names
header <- read_csv(ibtracs_local, n_max = 0, show_col_types = FALSE)
col_names <- names(header)

# Read data, skipping row 1 (header) and row 2 (units) — start at row 3
# We use skip = 2 and supply the column names manually
ibtracs_raw <- read_csv(
  ibtracs_local,
  skip = 2,
  col_names = col_names,
  col_types = cols(
    SID = col_character(),
    SEASON = col_integer(),
    NUMBER = col_integer(),
    BASIN = col_character(),
    SUBBASIN = col_character(),
    NAME = col_character(),
    ISO_TIME = col_character(),
    NATURE = col_character(),
    LAT = col_double(),
    LON = col_double(),
    WMO_WIND = col_character(),
    WMO_PRES = col_character(),
    WMO_AGENCY = col_character(),
    TRACK_TYPE = col_character(),
    DIST2LAND = col_character(),
    LANDFALL = col_character(),
    IFLAG = col_character(),
    USA_AGENCY = col_character(),
    USA_ATCF_ID = col_character(),
    USA_LAT = col_character(),
    USA_LON = col_character(),
    USA_RECORD = col_character(),
    USA_STATUS = col_character(),
    USA_WIND = col_character(),
    USA_PRES = col_character(),
    USA_SSHS = col_character(),
    USA_R34_NE = col_character(),
    USA_R34_SE = col_character(),
    USA_R34_SW = col_character(),
    USA_R34_NW = col_character(),
    USA_R50_NE = col_character(),
    USA_R50_SE = col_character(),
    USA_R50_SW = col_character(),
    USA_R50_NW = col_character(),
    USA_R64_NE = col_character(),
    USA_R64_SE = col_character(),
    USA_R64_SW = col_character(),
    USA_R64_NW = col_character(),
    .default = col_character()
  ),
  show_col_types = FALSE
)

cat("  Raw records:", nrow(ibtracs_raw), "\n")

# Parse key columns
ibtracs <- ibtracs_raw %>%
  mutate(
    lat = as.numeric(LAT),
    lon = as.numeric(LON),
    season = as.integer(SEASON),
    usa_wind = as.numeric(USA_WIND),
    usa_sshs = as.integer(USA_SSHS),
    iso_time = ymd_hms(ISO_TIME)
  ) %>%
  filter(
    !is.na(lat), !is.na(lon),
    season >= 1979
  )

cat("  After filtering to 1979+ with valid coords:", nrow(ibtracs), "\n\n")

# ==============================================================================
# 3. DEFINE STUDY SITE COORDINATES
# ==============================================================================

sites <- tibble::tribble(
  ~region,                  ~lat_site,  ~lon_site,
  "Florida Keys Upper",      25.1,      -80.3,
  "Florida Keys Lower",      24.5,      -81.4,
  "Dry Tortugas",            24.6,      -82.9,
  "Curacao",                 12.1,      -69.0,
  "Navassa",                 18.4,      -75.0,
  "US Virgin Islands",       17.8,      -64.7,
  "Puerto Rico",             18.0,      -67.0,
  "Jamaica",                 18.5,      -77.0,
  "British Virgin Islands",  18.5,      -64.6,
  "Dominican Republic",      18.4,      -68.8,
  "Mexican Caribbean",       20.5,      -87.3,
  "Cuba",                    23.0,      -82.0,
  "Bahamas",                 25.0,      -77.0,
  "St. Croix",               17.7,      -64.8,
  "Virgin Gorda",            18.5,      -64.4
)

cat("Study sites defined:", nrow(sites), "regions\n\n")

# ==============================================================================
# 4. HAVERSINE DISTANCE FUNCTION
# ==============================================================================

#' Compute great-circle distance in km using Haversine formula
#' @param lat1,lon1 Latitude/longitude of point 1 (degrees)
#' @param lat2,lon2 Latitude/longitude of point 2 (degrees)
#' @return Distance in km (vectorized)
haversine_km <- function(lat1, lon1, lat2, lon2) {
  # Convert to radians
  lat1_r <- lat1 * pi / 180
  lon1_r <- lon1 * pi / 180
  lat2_r <- lat2 * pi / 180
  lon2_r <- lon2 * pi / 180

  dlat <- lat2_r - lat1_r
  dlon <- lon2_r - lon1_r

  a <- sin(dlat / 2)^2 + cos(lat1_r) * cos(lat2_r) * sin(dlon / 2)^2
  c <- 2 * asin(pmin(1, sqrt(a)))  # pmin to handle floating point edge cases

  R <- 6371  # Earth radius in km
  return(R * c)
}

# ==============================================================================
# 5. COMPUTE DISTANCES — STORM POSITIONS TO SITES
# ==============================================================================

cat("Computing distances from storm positions to study sites...\n")
cat("  This may take a few minutes with", nrow(ibtracs), "storm positions x",
    nrow(sites), "sites...\n")

# Pre-filter: bounding box to reduce computation
# Caribbean region roughly: lat 10-28, lon -90 to -60
# Expand by ~2 degrees for 200 km buffer at these latitudes
ibtracs_caribbean <- ibtracs %>%
  filter(lat >= 8 & lat <= 30, lon >= -95 & lon <= -58)

cat("  After Caribbean bounding box filter:", nrow(ibtracs_caribbean), "positions\n")

# For each site, find storms within 200 km
results_list <- vector("list", nrow(sites))

for (i in seq_len(nrow(sites))) {
  site <- sites[i, ]

  # Compute distance from all storm positions to this site
  distances <- haversine_km(
    ibtracs_caribbean$lat, ibtracs_caribbean$lon,
    site$lat_site, site$lon_site
  )

  # Filter to within 200 km
  within_200 <- which(distances <= 200)

  if (length(within_200) > 0) {
    nearby <- ibtracs_caribbean[within_200, ] %>%
      mutate(
        region = site$region,
        lat_site = site$lat_site,
        lon_site = site$lon_site,
        distance_km = distances[within_200]
      )
    results_list[[i]] <- nearby
  }

  cat("  ", site$region, ":", length(within_200), "positions within 200 km\n")
}

# Combine all results
all_nearby <- bind_rows(results_list)
cat("\nTotal storm-site-position records within 200 km:", nrow(all_nearby), "\n")

# ==============================================================================
# 6. EXTRACT CLOSEST APPROACH PER STORM PER SITE
# ==============================================================================

cat("\nExtracting closest approach per storm per site...\n")

storm_exposure <- all_nearby %>%
  group_by(SID, NAME, season, region, lat_site, lon_site) %>%
  arrange(distance_km) %>%
  slice(1) %>%  # Keep only the closest approach

  ungroup() %>%
  mutate(
    # Clean up category
    category_at_closest = case_when(
      is.na(usa_sshs) ~ NA_character_,
      usa_sshs == -5 ~ "Unknown",
      usa_sshs == -4 ~ "Post-tropical",
      usa_sshs == -3 ~ "Miscellaneous",
      usa_sshs == -2 ~ "Subtropical",
      usa_sshs == -1 ~ "Tropical Depression",
      usa_sshs == 0  ~ "Tropical Storm",
      usa_sshs == 1  ~ "Category 1",
      usa_sshs == 2  ~ "Category 2",
      usa_sshs == 3  ~ "Category 3",
      usa_sshs == 4  ~ "Category 4",
      usa_sshs == 5  ~ "Category 5",
      TRUE ~ paste0("SSHS_", usa_sshs)
    ),
    direct_hit_50km = distance_km <= 50,
    # Use usa_wind where available; set NA for missing
    max_wind_kt = ifelse(is.na(usa_wind) | usa_wind <= 0, NA_real_, usa_wind)
  ) %>%
  select(
    storm_sid = SID,
    storm_name = NAME,
    year = season,
    region,
    lat_site,
    lon_site,
    closest_distance_km = distance_km,
    closest_date = iso_time,
    category_at_closest,
    usa_sshs_numeric = usa_sshs,
    max_wind_kt,
    direct_hit_50km
  ) %>%
  arrange(year, storm_sid, region)

cat("  Unique storm-site exposure records:", nrow(storm_exposure), "\n")
cat("  Unique storms:", n_distinct(storm_exposure$storm_sid), "\n")
cat("  Direct hits (<50 km):", sum(storm_exposure$direct_hit_50km, na.rm = TRUE), "\n\n")

# ==============================================================================
# 7. SAVE DETAILED STORM EXPOSURE
# ==============================================================================

output_exposure <- file.path(project_root, "05_data/standardized/ibtracs_storm_exposure.csv")

write_csv(storm_exposure, output_exposure)
cat("Saved detailed exposure to:", output_exposure, "\n")
cat("  Rows:", nrow(storm_exposure), "\n\n")

# ==============================================================================
# 8. CREATE SUMMARY TABLE: STORMS BY REGION AND CATEGORY
# ==============================================================================

cat("Creating hurricane exposure summary...\n")

# Category ordering for summary
cat_levels <- c(
  "Tropical Depression", "Tropical Storm",
  "Category 1", "Category 2", "Category 3", "Category 4", "Category 5",
  "Subtropical", "Post-tropical", "Miscellaneous", "Unknown"
)

# Per-region, per-category count
summary_long <- storm_exposure %>%
  filter(!is.na(category_at_closest)) %>%
  mutate(category_at_closest = factor(category_at_closest, levels = cat_levels)) %>%
  group_by(region, category_at_closest, .drop = FALSE) %>%
  summarise(
    n_storms = n(),
    n_direct_hits = sum(direct_hit_50km, na.rm = TRUE),
    mean_distance_km = round(mean(closest_distance_km, na.rm = TRUE), 1),
    .groups = "drop"
  )

# Also make a wide-format summary: storms by category
summary_wide <- storm_exposure %>%
  filter(!is.na(category_at_closest)) %>%
  count(region, category_at_closest) %>%
  pivot_wider(
    names_from = category_at_closest,
    values_from = n,
    values_fill = 0
  )

# Add totals
summary_wide <- summary_wide %>%
  mutate(total_storms = rowSums(select(., -region)))

# Per-region totals and hurricane counts
region_summary <- storm_exposure %>%
  group_by(region) %>%
  summarise(
    total_storms_200km = n(),
    total_direct_hits_50km = sum(direct_hit_50km, na.rm = TRUE),
    hurricanes_cat1plus = sum(usa_sshs_numeric >= 1, na.rm = TRUE),
    major_hurricanes_cat3plus = sum(usa_sshs_numeric >= 3, na.rm = TRUE),
    strongest_storm = storm_name[which.max(ifelse(is.na(max_wind_kt), 0, max_wind_kt))],
    strongest_wind_kt = max(max_wind_kt, na.rm = TRUE),
    first_year = min(year),
    last_year = max(year),
    .groups = "drop"
  ) %>%
  arrange(desc(total_storms_200km))

# Handle Inf from max() on all-NA
region_summary <- region_summary %>%
  mutate(strongest_wind_kt = ifelse(is.infinite(strongest_wind_kt), NA_real_, strongest_wind_kt))

output_summary <- file.path(project_root, "06_analysis/output/hurricane_exposure_summary.csv")
write_csv(region_summary, output_summary)
cat("Saved region summary to:", output_summary, "\n\n")

# Also save the detailed long-format summary
output_summary_detail <- file.path(project_root, "06_analysis/output/hurricane_exposure_by_category.csv")
write_csv(summary_long, output_summary_detail)
cat("Saved category breakdown to:", output_summary_detail, "\n\n")

# ==============================================================================
# 9. PRINT SUMMARY
# ==============================================================================

cat("=" , rep("=", 70), "\n", sep = "")
cat("HURRICANE EXPOSURE SUMMARY (1979-present, within 200 km)\n")
cat("=", rep("=", 70), "\n\n", sep = "")

cat("Total unique storms across all sites:", n_distinct(storm_exposure$storm_sid), "\n")
cat("Total storm-site exposure records:", nrow(storm_exposure), "\n")
cat("Direct hits (<50 km):", sum(storm_exposure$direct_hit_50km, na.rm = TRUE), "\n\n")

cat("--- Per-region summary ---\n\n")
for (i in seq_len(nrow(region_summary))) {
  r <- region_summary[i, ]
  cat(sprintf("  %-25s  %3d storms | %2d direct hits | %2d hurricanes | %2d major | strongest: %s (%s kt)\n",
              r$region, r$total_storms_200km, r$total_direct_hits_50km,
              r$hurricanes_cat1plus, r$major_hurricanes_cat3plus,
              r$strongest_storm,
              ifelse(is.na(r$strongest_wind_kt), "NA", as.character(r$strongest_wind_kt))))
}

cat("\n--- Top 10 most impactful storms (by number of sites affected) ---\n\n")

top_storms <- storm_exposure %>%
  group_by(storm_sid, storm_name, year) %>%
  summarise(
    sites_affected = n_distinct(region),
    direct_hits = sum(direct_hit_50km, na.rm = TRUE),
    max_category = max(usa_sshs_numeric, na.rm = TRUE),
    max_wind = max(max_wind_kt, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(sites_affected), desc(max_category)) %>%
  head(10)

for (i in seq_len(nrow(top_storms))) {
  s <- top_storms[i, ]
  cat(sprintf("  %s (%d) — %d sites, %d direct hits, max cat %s, max wind %s kt\n",
              s$storm_name, s$year, s$sites_affected, s$direct_hits,
              ifelse(is.infinite(s$max_category), "NA", as.character(s$max_category)),
              ifelse(is.infinite(s$max_wind) | is.na(s$max_wind), "NA", as.character(s$max_wind))))
}

cat("\n=== 33: Hurricane Exposure Analysis COMPLETE ===\n")
