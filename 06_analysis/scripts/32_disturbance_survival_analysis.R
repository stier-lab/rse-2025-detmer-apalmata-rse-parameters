#!/usr/bin/env Rscript
################################################################################
# 32_DISTURBANCE_SURVIVAL_ANALYSIS.R
# Formal Analysis of Disturbance Events and Colony Survival
################################################################################
#
# PURPOSE:
#   Link documented Caribbean disturbance events (hurricanes, bleaching,
#   disease, cold snaps) to individual colony survival using the two time
#   series datasets (NOAA and Neely) that span multiple years at Florida Keys
#   sites. Quantify the effect of degree heating weeks (DHW) and disturbance
#   severity on annual survival using GLMMs, and characterize disturbance
#   frequency and return intervals.
#
# APPROACH:
#   1. Merge the disturbance event database with individual survival records
#      by region and survey_yr (start of the observation interval).
#   2. Create a 2-panel timeline figure showing FL Keys annual survival for
#      NOAA and Neely with disturbance events annotated.
#   3. Fit GLMMs testing DHW and disturbance severity as predictors of
#      survival, controlling for colony size and study/location random effects.
#   4. Compute disturbance frequency statistics and return intervals.
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#   - 05_data/standardized/caribbean_disturbance_events.csv
#   - 06_analysis/output/heat_stress_by_site_year_verified.csv (preferred if present)
#   - 06_analysis/output/heat_stress_by_site_year.csv
#
# OUTPUTS:
#   - 06_analysis/output/disturbance_survival_glmm.csv
#   - 06_analysis/output/disturbance_frequency.csv
#   - 06_analysis/figures/supplementary/FigSXX_disturbance_timeline.png (+.pdf)
#
# CRITICAL NOTES:
#   - survey_yr = START of observation interval. A colony surveyed in 2014
#     was exposed to disturbances during the 2014-2015 interval.
#   - NOAA FL Keys: 2004-2024 (19 years of time series)
#   - Neely FL Keys: 2010-2015 (6 years, overlaps with NOAA)
#   - Overdispersion checks on all binomial GLMMs (project convention).
#   - DHW data are satellite-derived (ERDDAP) at site-year resolution.
#
# Author: Detmer & Stier Lab
# Date: 2026-03-30
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

suppressPackageStartupMessages(library(patchwork))

set.seed(42)

dirs <- setup_output_dirs()

print_header("32: DISTURBANCE-SURVIVAL ANALYSIS")

# ==============================================================================
# SECTION 1: LOAD DATA
# ==============================================================================

print_subheader("Loading data")

# --- Prepared survival data ---
surv_data <- readRDS(file.path(dirs$output, "prepared_survival_data.rds"))
print_info(sprintf("Survival data: %d observations, %d studies",
                    nrow(surv_data), dplyr::n_distinct(surv_data$study)))

# --- Disturbance event database ---
disturbance_db <- readr::read_csv(
  file.path(get_project_root(), "05_data/standardized/caribbean_disturbance_events.csv"),
  show_col_types = FALSE
)
print_info(sprintf("Disturbance database: %d events across %d regions",
                    nrow(disturbance_db), dplyr::n_distinct(disturbance_db$region)))

# --- DHW data (satellite-derived, site-year resolution) ---
dhw_candidates <- c(
  file.path(dirs$output, "heat_stress_by_site_year_verified.csv"),
  file.path(dirs$output, "heat_stress_by_site_year.csv")
)
dhw_file <- dhw_candidates[file.exists(dhw_candidates)][1]

dominant_nonmissing <- function(x) {
  x <- x[!is.na(x) & nzchar(as.character(x))]
  if (length(x) == 0) return(NA_character_)
  names(sort(table(x), decreasing = TRUE))[1]
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

if (length(dhw_file) == 1 && !is.na(dhw_file)) {
  dhw_data <- readr::read_csv(dhw_file, show_col_types = FALSE)
  dhw_file_name <- basename(dhw_file)
  has_query_status <- "query_status" %in% names(dhw_data)
  has_dhw_source <- "dhw_source" %in% names(dhw_data)
  print_info(sprintf("DHW data (%s): %d site-year records", dhw_file_name, nrow(dhw_data)))
} else {
  print_warn("DHW file not found. DHW analysis will be skipped.")
  dhw_data <- NULL
  dhw_file_name <- NA_character_
}

# ==============================================================================
# SECTION 2: MERGE DISTURBANCE EVENTS WITH SURVIVAL DATA
# ==============================================================================

print_subheader("Merging disturbance events with survival records")

# --- Define severity numeric coding ---
severity_map <- c(
  "none"         = 0L,
  "minor"        = 1L,
  "moderate"     = 2L,
  "major"        = 3L,
  "catastrophic" = 4L
)

# --- Summarize disturbance events per region-year ---
# Each survival record's survey_yr is the START of the interval, so the colony
# was exposed to disturbances occurring in that year (and into the next).
disturbance_summary <- disturbance_db %>%
  dplyr::mutate(
    severity_numeric = severity_map[tolower(severity)],
    is_hurricane  = as.integer(event_type == "hurricane"),
    is_bleaching  = as.integer(event_type == "bleaching"),
    is_disease    = as.integer(event_type == "disease"),
    is_cold       = as.integer(event_type == "cold_snap")
  ) %>%
  dplyr::group_by(region, year) %>%
  dplyr::summarise(
    n_disturbance_events = dplyr::n(),
    max_event_severity   = max(severity_numeric, na.rm = TRUE),
    has_hurricane        = as.integer(any(is_hurricane == 1L)),
    has_bleaching        = as.integer(any(is_bleaching == 1L)),
    has_disease          = as.integer(any(is_disease == 1L)),
    has_cold             = as.integer(any(is_cold == 1L)),
    .groups = "drop"
  )

# Handle -Inf from max() when all NA
disturbance_summary <- disturbance_summary %>%
  dplyr::mutate(
    max_event_severity = dplyr::if_else(
      is.infinite(max_event_severity), NA_integer_, max_event_severity
    )
  )

print_info(sprintf("Disturbance summary: %d region-year combinations with events",
                    nrow(disturbance_summary)))

# --- Merge with survival data by region and survey_yr ---
surv_merged <- surv_data %>%
  dplyr::left_join(
    disturbance_summary,
    by = c("region" = "region", "survey_yr" = "year")
  ) %>%
  dplyr::mutate(
    # Fill NAs (no event recorded) with zeros
    n_disturbance_events = dplyr::if_else(is.na(n_disturbance_events), 0L, n_disturbance_events),
    max_event_severity   = dplyr::if_else(is.na(max_event_severity), 0L, max_event_severity),
    has_hurricane        = dplyr::if_else(is.na(has_hurricane), 0L, has_hurricane),
    has_bleaching        = dplyr::if_else(is.na(has_bleaching), 0L, has_bleaching),
    has_disease          = dplyr::if_else(is.na(has_disease), 0L, has_disease),
    has_cold             = dplyr::if_else(is.na(has_cold), 0L, has_cold)
  )

# --- Merge DHW data ---
# DHW data has study, region, lat_round, lon_round, survey_yr columns.
# Aggregate to study-region-year level (mean across spatial points).
if (!is.null(dhw_data)) {
  dhw_by_study_region_yr <- dhw_data %>%
    dplyr::group_by(study, region, survey_yr) %>%
    dplyr::summarise(
      max_dhw = if (all(is.na(max_dhw))) NA_real_ else max(max_dhw, na.rm = TRUE),
      n_site_rows = dplyr::n(),
      n_nonmissing_dhw = sum(!is.na(max_dhw)),
      dominant_query_status = if (has_query_status) dominant_nonmissing(query_status) else NA_character_,
      dominant_dhw_source = if (has_dhw_source) dominant_nonmissing(dhw_source) else NA_character_,
      .groups = "drop"
    )

  surv_merged <- surv_merged %>%
    dplyr::left_join(
      dhw_by_study_region_yr,
      by = c("study", "region", "survey_yr")
    )

  n_dhw_matched <- sum(!is.na(surv_merged$max_dhw))
  dhw_supported_studies <- dplyr::n_distinct(surv_merged$study[!is.na(surv_merged$max_dhw)])
  dhw_supported_regions <- dplyr::n_distinct(surv_merged$region[!is.na(surv_merged$max_dhw)])
  dhw_supported_study_years <- dplyr::n_distinct(
    surv_merged %>%
      dplyr::filter(!is.na(max_dhw)) %>%
      dplyr::select(study, region, survey_yr)
  )
  dhw_support_label <- classify_dhw_support(
    n_dhw_matched,
    dhw_supported_studies,
    dhw_supported_regions,
    dhw_supported_study_years
  )
  print_info(sprintf("DHW matched: %d / %d records (%.1f%%)",
                      n_dhw_matched, nrow(surv_merged),
                      n_dhw_matched / nrow(surv_merged) * 100))

  dhw_coverage <- tibble::tibble(
    dhw_file = dhw_file_name,
    n_site_year_rows = nrow(dhw_data),
    n_nonmissing_site_year_rows = sum(!is.na(dhw_data$max_dhw)),
    n_study_region_year_rows = nrow(dhw_by_study_region_yr),
    n_study_region_year_nonmissing = sum(!is.na(dhw_by_study_region_yr$max_dhw)),
    n_survival_rows = nrow(surv_merged),
    n_survival_rows_with_dhw = n_dhw_matched,
    pct_survival_rows_with_dhw = n_dhw_matched / nrow(surv_merged) * 100,
    n_studies_with_dhw = dhw_supported_studies,
    n_regions_with_dhw = dhw_supported_regions,
    n_unique_study_years_with_dhw = dhw_supported_study_years,
    n_query_error_rows = if ("query_status" %in% names(dhw_data)) sum(dhw_data$query_status == "error", na.rm = TRUE) else NA_integer_,
    n_no_data_rows = if ("query_status" %in% names(dhw_data)) sum(dhw_data$query_status == "no_data", na.rm = TRUE) else NA_integer_,
    inference_support = dhw_support_label,
    caveat = sprintf(
      "DHW overlay preferred from verified file when present, but current support is often literature-LUT backed and is supported here by %d studies, %d regions, and %d study-years.",
      dhw_supported_studies,
      dhw_supported_regions,
      dhw_supported_study_years
    )
  )
} else {
  surv_merged$max_dhw <- NA_real_
  dhw_coverage <- tibble::tibble(
    dhw_file = NA_character_,
    n_site_year_rows = 0L,
    n_nonmissing_site_year_rows = 0L,
    n_study_region_year_rows = 0L,
    n_study_region_year_nonmissing = 0L,
    n_survival_rows = nrow(surv_merged),
    n_survival_rows_with_dhw = 0L,
    pct_survival_rows_with_dhw = 0,
    n_studies_with_dhw = 0L,
    n_regions_with_dhw = 0L,
    n_unique_study_years_with_dhw = 0L,
    n_query_error_rows = NA_integer_,
    n_no_data_rows = NA_integer_,
    inference_support = "none",
    caveat = "No DHW file available."
  )
}

readr::write_csv(
  dhw_coverage,
  file.path(dirs$output, "disturbance_dhw_coverage.csv")
)
print_success("Saved disturbance_dhw_coverage.csv")

# --- Report merge diagnostics ---
n_with_disturbance <- sum(surv_merged$n_disturbance_events > 0)
print_info(sprintf("Records with >= 1 disturbance event: %d / %d (%.1f%%)",
                    n_with_disturbance, nrow(surv_merged),
                    n_with_disturbance / nrow(surv_merged) * 100))

cat("\n  Disturbance coverage by severity:\n")
print(table(surv_merged$max_event_severity, useNA = "ifany"))

# ==============================================================================
# SECTION 3: TIME SERIES VISUALIZATION
# ==============================================================================

print_subheader("Creating disturbance timeline figure")

# --- Restrict to NOAA + Neely FL Keys time series ---
ts_studies <- c("NOAA_survey", "neely_et_al_2022")
ts_data <- surv_merged %>%
  dplyr::filter(study %in% ts_studies, region == "Florida Keys")

print_info(sprintf("Time series data (NOAA + Neely FL Keys): %d records", nrow(ts_data)))

# --- Compute annual survival for each study ---
annual_surv <- ts_data %>%
  dplyr::group_by(study, survey_yr) %>%
  dplyr::summarise(
    n = dplyr::n(),
    n_survived = sum(survived),
    survival_rate = mean(survived),
    se = sqrt(survival_rate * (1 - survival_rate) / dplyr::n()),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    ci_lower = pmax(0, survival_rate - 1.96 * se),
    ci_upper = pmin(1, survival_rate + 1.96 * se)
  )

# --- Get FL Keys disturbance events for annotation ---
flk_events <- disturbance_db %>%
  dplyr::filter(region == "Florida Keys") %>%
  dplyr::mutate(
    severity_numeric = severity_map[tolower(severity)]
  )

# Define disturbance type colors
disturbance_colors <- c(
  "hurricane"  = "#0072B2",   # blue
  "bleaching"  = "#D55E00",   # red/vermillion
  "disease"    = "#E69F00",   # yellow/amber
  "cold_snap"  = "#56B4E9",   # cyan/light blue
  "other"      = "#999999"    # grey
)

disturbance_labels <- c(
  "hurricane"  = "Hurricane",
  "bleaching"  = "Bleaching",
  "disease"    = "Disease",
  "cold_snap"  = "Cold snap",
  "other"      = "Other"
)

# --- Helper function: build one panel ---
build_timeline_panel <- function(study_name, study_label, annual_data, events_data) {

  study_annual <- annual_data %>%
    dplyr::filter(study == study_name) %>%
    dplyr::filter(
      is.finite(survey_yr),
      is.finite(survival_rate),
      is.finite(ci_lower),
      is.finite(ci_upper),
      is.finite(n)
    )

  if (nrow(study_annual) == 0) {
    return(ggplot2::ggplot() + ggplot2::theme_void() +
             ggplot2::annotate("text", x = 0.5, y = 0.5,
                               label = paste("No data for", study_label)))
  }

  yr_range <- range(study_annual$survey_yr)

  # Filter events to the study's time range
  panel_events <- events_data %>%
    dplyr::filter(year >= yr_range[1], year <= yr_range[2]) %>%
    dplyr::mutate(
      event_type = dplyr::if_else(
        event_type %in% names(disturbance_colors),
        event_type,
        "other"
      ),
      event_type = factor(event_type, levels = names(disturbance_colors))
    ) %>%
    dplyr::filter(is.finite(year))

  # Assign y-position for event bars at the bottom of the panel
  # Stack events within the same year
  if (nrow(panel_events) > 0) {
    panel_events <- panel_events %>%
      dplyr::group_by(year) %>%
      dplyr::mutate(event_rank = dplyr::row_number()) %>%
      dplyr::ungroup() %>%
      dplyr::mutate(
        event_y = -0.02 - (event_rank - 1) * 0.035
      )
  }

  y_lower_limit <- if (nrow(panel_events) > 0) {
    min(-0.25, min(panel_events$event_y, na.rm = TRUE) - 0.03)
  } else {
    -0.25
  }

  p <- ggplot2::ggplot() +
    # Disturbance event bars at the bottom
    {if (nrow(panel_events) > 0) {
      list(
        ggplot2::geom_segment(
          data = panel_events,
          ggplot2::aes(x = year - 0.3, xend = year + 0.3,
                       y = event_y, yend = event_y,
                       color = event_type),
          linewidth = 2.5, lineend = "round",
          show.legend = TRUE
        ),
        # Severity markers: larger point for more severe events
        ggplot2::geom_point(
          data = panel_events %>% dplyr::filter(severity_numeric >= 3),
          ggplot2::aes(x = year, y = event_y),
          shape = 8, size = 1.5, color = "black", stroke = 0.5
        )
      )
    }} +
    # Survival line + points
    ggplot2::geom_ribbon(
      data = study_annual,
      ggplot2::aes(x = survey_yr, ymin = ci_lower, ymax = ci_upper),
      fill = MANUSCRIPT_PALETTE$slate_light, alpha = 0.3
    ) +
    ggplot2::geom_line(
      data = study_annual,
      ggplot2::aes(x = survey_yr, y = survival_rate),
      color = MANUSCRIPT_PALETTE$surv_dark, linewidth = 0.6
    ) +
    ggplot2::geom_point(
      data = study_annual,
      ggplot2::aes(x = survey_yr, y = survival_rate, size = n),
      color = MANUSCRIPT_PALETTE$surv_dark, shape = 16
    ) +
    # Scales
    ggplot2::scale_color_manual(
      values = disturbance_colors,
      labels = disturbance_labels,
      name = "Disturbance type",
      drop = FALSE
    ) +
    ggplot2::scale_size_continuous(
      range = c(1.5, 4),
      name = "n colonies",
      breaks = c(50, 200, 500, 1000)
    ) +
    ggplot2::scale_x_continuous(
      breaks = seq(2004, 2024, by = 2),
      limits = c(yr_range[1] - 0.5, yr_range[2] + 0.5)
    ) +
    ggplot2::scale_y_continuous(
      limits = c(y_lower_limit, 1.05),
      breaks = seq(0, 1, by = 0.2),
      labels = scales::number_format(accuracy = 0.1)
    ) +
    ggplot2::labs(
      x = "Year",
      y = "Annual survival"
    ) +
    # Strip label for study
    ggplot2::facet_wrap(~ study_label, ncol = 1) +
    theme_manuscript(base_size = 9) +
    ggplot2::theme(
      legend.position = "none",
      strip.text = ggplot2::element_text(size = 9, face = "bold", hjust = 0)
    )

  # Add the facet label by creating a dummy column
  study_annual$study_label <- study_label
  panel_events$study_label <- study_label

  # Rebuild with facet data
  p <- ggplot2::ggplot() +
    {if (nrow(panel_events) > 0) {
      ggplot2::geom_segment(
        data = panel_events,
        ggplot2::aes(x = year - 0.3, xend = year + 0.3,
                     y = event_y, yend = event_y,
                     color = event_type),
        linewidth = 2.5, lineend = "round"
      )
    }} +
    {if (nrow(panel_events) > 0) {
      ggplot2::geom_point(
        data = panel_events %>% dplyr::filter(severity_numeric >= 3),
        ggplot2::aes(x = year, y = event_y),
        shape = 8, size = 1.5, color = "black", stroke = 0.5
      )
    }} +
    ggplot2::geom_ribbon(
      data = study_annual,
      ggplot2::aes(x = survey_yr, ymin = ci_lower, ymax = ci_upper),
      fill = MANUSCRIPT_PALETTE$slate_light, alpha = 0.3
    ) +
    ggplot2::geom_line(
      data = study_annual,
      ggplot2::aes(x = survey_yr, y = survival_rate),
      color = MANUSCRIPT_PALETTE$surv_dark, linewidth = 0.6
    ) +
    ggplot2::geom_point(
      data = study_annual,
      ggplot2::aes(x = survey_yr, y = survival_rate, size = n),
      color = MANUSCRIPT_PALETTE$surv_dark, shape = 16
    ) +
    ggplot2::scale_color_manual(
      values = disturbance_colors,
      labels = disturbance_labels,
      name = "Disturbance type"
    ) +
    ggplot2::scale_size_continuous(
      range = c(1.5, 4),
      name = "n colonies",
      breaks = c(50, 200, 500, 1000)
    ) +
    ggplot2::scale_x_continuous(
      breaks = seq(2004, 2024, by = 2),
      limits = c(yr_range[1] - 0.5, yr_range[2] + 0.5)
    ) +
    ggplot2::scale_y_continuous(
      limits = c(y_lower_limit, 1.05),
      breaks = seq(0, 1, by = 0.2),
      labels = scales::number_format(accuracy = 0.1)
    ) +
    ggplot2::labs(x = "Year", y = "Annual survival") +
    theme_manuscript(base_size = 9) +
    ggplot2::theme()

  return(p)
}

# --- Build panels ---
p_noaa <- build_timeline_panel(
  "NOAA_survey", "NOAA FL Keys (2004-2024)",
  annual_surv, flk_events
)

p_neely <- build_timeline_panel(
  "neely_et_al_2022", "Neely et al. FL Keys (2010-2015)",
  annual_surv, flk_events
)

# --- Build shared legend ---
# Create a dummy plot for extracting the legend
legend_data <- data.frame(
  x = rep(1, 4), y = rep(1, 4),
  event_type = factor(
    c("hurricane", "bleaching", "disease", "cold_snap"),
    levels = names(disturbance_colors)
  )
)

p_legend <- ggplot2::ggplot(legend_data, ggplot2::aes(x = x, y = y, color = event_type)) +
  ggplot2::geom_point(size = 3) +
  ggplot2::scale_color_manual(
    values = disturbance_colors[c("hurricane", "bleaching", "disease", "cold_snap")],
    labels = disturbance_labels[c("hurricane", "bleaching", "disease", "cold_snap")],
    name = "Disturbance type",
    drop = FALSE
  ) +
  ggplot2::theme(legend.position = "bottom")

# --- Compose figure ---
p_combined <- (p_noaa + ggplot2::labs(tag = "a")) /
  (p_neely + ggplot2::labs(tag = "b")) +
  patchwork::plot_layout(
    heights = c(1, 0.7),
    guides = "collect"
  ) &
  ggplot2::theme(
    legend.position = "bottom",
    legend.box = "horizontal"
  )

# Manually add the disturbance color legend by making it visible
# (the size legend is secondary; disturbance type is the key message)
p_combined <- p_combined +
  patchwork::plot_annotation(
    caption = paste0(
      "Points = annual survival (size proportional to sample size). ",
      "Shading = 95% CI. ",
      "Colored bars = disturbance events; stars (*) mark major/catastrophic events."
    ),
    theme = ggplot2::theme(
      plot.caption = ggplot2::element_text(size = 7, hjust = 0, color = "grey40")
    )
  )

# --- Save figure ---
save_manuscript_fig(
  p_combined,
  "FigSXX_disturbance_timeline",
  width_mm = 174,
  height_mm = 160,
  fig_dir = dirs$figures_supp
)

print_success("Saved FigSXX_disturbance_timeline (.png + .pdf)")

# ==============================================================================
# SECTION 4: STATISTICAL ANALYSIS
# ==============================================================================

print_subheader("Statistical models: disturbance effects on survival")

# --- Restrict to the two time series datasets ---
ts_merged <- surv_merged %>%
  dplyr::filter(study %in% c("NOAA_survey", "neely_et_al_2022"))

print_info(sprintf("Analysis dataset (NOAA + Neely): %d records", nrow(ts_merged)))
cat("  Studies:\n")
print(table(ts_merged$study))
cat("  Disturbance severity distribution:\n")
print(table(ts_merged$max_event_severity))

# --- Model 1: DHW effect on survival ---
print_subheader("Model 1: DHW effect on survival")

# Check whether location is viable as a random effect
n_locations <- dplyr::n_distinct(ts_merged$location[!is.na(ts_merged$location)])
print_info(sprintf("Unique locations in time series data: %d", n_locations))

# Subset to records with DHW data
ts_dhw <- ts_merged %>%
  dplyr::filter(!is.na(max_dhw), !is.na(log_size))

print_info(sprintf("Records with DHW data: %d", nrow(ts_dhw)))

if (nrow(ts_dhw) >= 50) {
  # Try nested random effect (study/location); fall back to (1|study) + (1|location)
  m_dhw <- tryCatch({
    lme4::glmer(
      survived ~ log_size + max_dhw + (1 | study / location),
      data = ts_dhw,
      family = binomial,
      control = lme4::glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
    )
  }, error = function(e) {
    print_warn(sprintf("Nested RE failed: %s. Trying crossed RE.", e$message))
    tryCatch({
      lme4::glmer(
        survived ~ log_size + max_dhw + (1 | study) + (1 | location),
        data = ts_dhw,
        family = binomial,
        control = lme4::glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
      )
    }, error = function(e2) {
      print_warn(sprintf("Crossed RE failed: %s. Using study RE only.", e2$message))
      lme4::glmer(
        survived ~ log_size + max_dhw + (1 | study),
        data = ts_dhw,
        family = binomial,
        control = lme4::glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
      )
    })
  })

  cat("\n  --- DHW Model Summary ---\n")
  print(summary(m_dhw))

  # Overdispersion check
  od_dhw <- overdisp_test(m_dhw)
  cat(sprintf("\n  Overdispersion ratio: %.3f %s\n",
              od_dhw$ratio,
              if (od_dhw$overdispersed) "(WARNING: potential overdispersion)" else "(OK)"))

  # Extract coefficients as odds ratios
  coef_dhw <- as.data.frame(summary(m_dhw)$coefficients)
  coef_dhw$term <- rownames(coef_dhw)
  coef_dhw <- coef_dhw %>%
    dplyr::mutate(
      `Pr(>|z|)` = if (identical(dhw_coverage$inference_support[1], "sparse")) NA_real_ else `Pr(>|z|)`,
      odds_ratio    = exp(Estimate),
      or_ci_lower   = exp(Estimate - 1.96 * `Std. Error`),
      or_ci_upper   = exp(Estimate + 1.96 * `Std. Error`),
      model         = "DHW",
      overdispersion_ratio = od_dhw$ratio,
      dhw_file = dhw_coverage$dhw_file[1],
      dhw_support = dhw_coverage$inference_support[1],
      dhw_rows = dhw_coverage$n_survival_rows_with_dhw[1],
      inference_note = ifelse(
        identical(dhw_coverage$inference_support[1], "sparse"),
        "Descriptive only: DHW support too thin for inferential interpretation.",
        "Inferential summary."
      )
    )

  cat("\n  Odds ratios (DHW model):\n")
  dhw_p_display <- coef_dhw$`Pr(>|z|)`[coef_dhw$term == "max_dhw"]
  cat(sprintf(
    "    DHW: OR = %.3f (95%% CI: %.3f - %.3f), p = %s\n",
    coef_dhw$odds_ratio[coef_dhw$term == "max_dhw"],
    coef_dhw$or_ci_lower[coef_dhw$term == "max_dhw"],
    coef_dhw$or_ci_upper[coef_dhw$term == "max_dhw"],
    ifelse(is.na(dhw_p_display), "NA (descriptive only; sparse support)", sprintf("%.4f", dhw_p_display))
  ))

  dhw_or <- coef_dhw$odds_ratio[coef_dhw$term == "max_dhw"]
  if (dhw_or < 1) {
    cat(sprintf("    Interpretation: Each 1-unit DHW increase reduces survival odds by %.1f%%\n",
                (1 - dhw_or) * 100))
  } else {
    cat(sprintf("    Interpretation: Each 1-unit DHW increase is associated with %.1f%% higher odds of survival\n",
                (dhw_or - 1) * 100))
  }

} else {
  print_warn("Insufficient DHW data for GLMM (< 50 records)")
  coef_dhw <- NULL
}

# --- Model 2: Disturbance severity effect on survival ---
print_subheader("Model 2: Disturbance severity effect on survival")

ts_sev <- ts_merged %>%
  dplyr::filter(!is.na(log_size))

print_info(sprintf("Records for severity model: %d", nrow(ts_sev)))

if (nrow(ts_sev) >= 50) {
  m_severity <- tryCatch({
    lme4::glmer(
      survived ~ log_size + max_event_severity + (1 | study / location),
      data = ts_sev,
      family = binomial,
      control = lme4::glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
    )
  }, error = function(e) {
    print_warn(sprintf("Nested RE failed: %s. Trying crossed RE.", e$message))
    tryCatch({
      lme4::glmer(
        survived ~ log_size + max_event_severity + (1 | study) + (1 | location),
        data = ts_sev,
        family = binomial,
        control = lme4::glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
      )
    }, error = function(e2) {
      print_warn(sprintf("Crossed RE failed: %s. Using study RE only.", e2$message))
      lme4::glmer(
        survived ~ log_size + max_event_severity + (1 | study),
        data = ts_sev,
        family = binomial,
        control = lme4::glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
      )
    })
  })

  cat("\n  --- Severity Model Summary ---\n")
  print(summary(m_severity))

  # Overdispersion check
  od_sev <- overdisp_test(m_severity)
  cat(sprintf("\n  Overdispersion ratio: %.3f %s\n",
              od_sev$ratio,
              if (od_sev$overdispersed) "(WARNING: potential overdispersion)" else "(OK)"))

  # Extract coefficients as odds ratios
  coef_sev <- as.data.frame(summary(m_severity)$coefficients)
  coef_sev$term <- rownames(coef_sev)
  coef_sev <- coef_sev %>%
    dplyr::mutate(
      odds_ratio    = exp(Estimate),
      or_ci_lower   = exp(Estimate - 1.96 * `Std. Error`),
      or_ci_upper   = exp(Estimate + 1.96 * `Std. Error`),
      model         = "Severity",
      overdispersion_ratio = od_sev$ratio
    )

  cat("\n  Odds ratios (Severity model):\n")
  cat(sprintf("    Severity: OR = %.3f (95%% CI: %.3f - %.3f), p = %.4f\n",
              coef_sev$odds_ratio[coef_sev$term == "max_event_severity"],
              coef_sev$or_ci_lower[coef_sev$term == "max_event_severity"],
              coef_sev$or_ci_upper[coef_sev$term == "max_event_severity"],
              coef_sev$`Pr(>|z|)`[coef_sev$term == "max_event_severity"]))

  sev_or <- coef_sev$odds_ratio[coef_sev$term == "max_event_severity"]
  if (sev_or < 1) {
    cat(sprintf("    Interpretation: Each 1-step severity increase reduces survival odds by %.1f%%\n",
                (1 - sev_or) * 100))
  } else {
    cat(sprintf("    Interpretation: Each 1-step severity increase is associated with %.1f%% higher odds of survival\n",
                (sev_or - 1) * 100))
  }

} else {
  print_warn("Insufficient data for severity GLMM (< 50 records)")
  coef_sev <- NULL
}

# ==============================================================================
# SECTION 5: DISTURBANCE FREQUENCY ANALYSIS
# ==============================================================================

print_subheader("Disturbance frequency analysis")

# --- Compute disturbance frequency across all study-years in the synthesis ---
# Use the full survival dataset (all studies, all regions) for breadth,
# but also report FL Keys specifically for return intervals.

# Unique study-region-years in the survival data
study_region_years <- surv_merged %>%
  dplyr::distinct(study, region, survey_yr)

n_study_years <- nrow(study_region_years)
print_info(sprintf("Total unique study-region-years: %d", n_study_years))

# Merge disturbance info to these study-region-years
sry_with_dist <- study_region_years %>%
  dplyr::left_join(
    disturbance_summary,
    by = c("region" = "region", "survey_yr" = "year")
  ) %>%
  dplyr::mutate(
    n_disturbance_events = dplyr::if_else(is.na(n_disturbance_events), 0L, n_disturbance_events),
    max_event_severity   = dplyr::if_else(is.na(max_event_severity), 0L, max_event_severity),
    has_any_disturbance  = as.integer(n_disturbance_events > 0),
    has_major_or_catastrophic = as.integer(max_event_severity >= 3)
  )

# Overall fractions
frac_any <- mean(sry_with_dist$has_any_disturbance)
frac_major <- mean(sry_with_dist$has_major_or_catastrophic)

cat(sprintf("\n  Fraction of study-years with any documented disturbance: %.1f%% (%d / %d)\n",
            frac_any * 100,
            sum(sry_with_dist$has_any_disturbance),
            n_study_years))
cat(sprintf("  Fraction with major/catastrophic disturbance: %.1f%% (%d / %d)\n",
            frac_major * 100,
            sum(sry_with_dist$has_major_or_catastrophic),
            n_study_years))

# --- FL Keys return intervals ---
# Use all unique years in the disturbance database for FL Keys
flk_years <- disturbance_db %>%
  dplyr::filter(region == "Florida Keys") %>%
  dplyr::pull(year) %>%
  unique() %>%
  sort()

flk_year_range <- range(flk_years)
flk_span <- diff(flk_year_range) + 1

# Major/catastrophic events at FL Keys
flk_major_years <- disturbance_db %>%
  dplyr::filter(region == "Florida Keys",
                severity %in% c("major", "catastrophic")) %>%
  dplyr::pull(year) %>%
  unique() %>%
  sort()

n_major_years_flk <- length(flk_major_years)
return_interval_flk <- if (n_major_years_flk > 1) {
  flk_span / n_major_years_flk
} else {
  NA_real_
}

cat(sprintf("\n  FL Keys disturbance record: %d-%d (%d years)\n",
            flk_year_range[1], flk_year_range[2], flk_span))
cat(sprintf("  Years with major/catastrophic events: %s\n",
            paste(flk_major_years, collapse = ", ")))
cat(sprintf("  Number of major/catastrophic event-years: %d\n", n_major_years_flk))
cat(sprintf("  Estimated return interval for major events at FL Keys: %.1f years\n",
            return_interval_flk))

# --- By disturbance type ---
type_freq <- disturbance_db %>%
  dplyr::filter(region == "Florida Keys") %>%
  dplyr::group_by(event_type) %>%
  dplyr::summarise(
    n_events = dplyr::n(),
    n_years  = dplyr::n_distinct(year),
    min_year = min(year),
    max_year = max(year),
    n_major_catastrophic = sum(severity %in% c("major", "catastrophic")),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    return_interval_yr = flk_span / n_years
  ) %>%
  dplyr::arrange(event_type)

cat("\n  FL Keys disturbance frequency by type:\n")
print(as.data.frame(type_freq))

# --- Compile frequency output ---
frequency_df <- dplyr::bind_rows(
  data.frame(
    metric = "frac_study_years_any_disturbance",
    value  = frac_any,
    n      = sum(sry_with_dist$has_any_disturbance),
    total  = n_study_years,
    region = "all",
    notes  = "Fraction of all study-region-years with >= 1 documented event"
  ),
  data.frame(
    metric = "frac_study_years_major_catastrophic",
    value  = frac_major,
    n      = sum(sry_with_dist$has_major_or_catastrophic),
    total  = n_study_years,
    region = "all",
    notes  = "Fraction with severity >= major (3) or catastrophic (4)"
  ),
  data.frame(
    metric = "return_interval_major_flk",
    value  = return_interval_flk,
    n      = n_major_years_flk,
    total  = flk_span,
    region = "Florida Keys",
    notes  = sprintf("Estimated return interval: %.1f yr (%d major/catastrophic years in %d-year span)",
                      return_interval_flk, n_major_years_flk, flk_span)
  ),
  type_freq %>%
    dplyr::transmute(
      metric = paste0("return_interval_", event_type, "_flk"),
      value  = return_interval_yr,
      n      = n_years,
      total  = as.integer(flk_span),
      region = "Florida Keys",
      notes  = sprintf("%s: %d events in %d unique years over %d-year span",
                        event_type, n_events, n_years, flk_span)
    )
)

# ==============================================================================
# SECTION 6: SAVE OUTPUTS
# ==============================================================================

print_subheader("Saving outputs")

# --- GLMM results ---
if (!is.null(coef_dhw) || !is.null(coef_sev)) {
  glmm_results <- dplyr::bind_rows(coef_dhw, coef_sev) %>%
    dplyr::select(model, term, Estimate, `Std. Error`, `z value`, `Pr(>|z|)`,
                  odds_ratio, or_ci_lower, or_ci_upper, overdispersion_ratio,
                  dhw_file, dhw_support, dhw_rows, inference_note)

  readr::write_csv(
    glmm_results,
    file.path(dirs$output, "disturbance_survival_glmm.csv")
  )
  print_success("Saved disturbance_survival_glmm.csv")
} else {
  print_warn("No GLMM results to save (insufficient data for both models)")
}

# --- Disturbance frequency ---
readr::write_csv(
  frequency_df,
  file.path(dirs$output, "disturbance_frequency.csv")
)
print_success("Saved disturbance_frequency.csv")

# ==============================================================================
# SUMMARY
# ==============================================================================

print_header("32: DISTURBANCE-SURVIVAL ANALYSIS COMPLETE")

cat("KEY FINDINGS:\n\n")

cat("  Data integration:\n")
cat(sprintf("    %d survival records merged with disturbance events\n", nrow(surv_merged)))
cat(sprintf("    %.1f%% of records exposed to >= 1 disturbance event\n",
            n_with_disturbance / nrow(surv_merged) * 100))

if (!is.null(coef_dhw)) {
  dhw_row <- coef_dhw %>% dplyr::filter(term == "max_dhw")
  cat(sprintf("\n  DHW effect (GLMM):\n"))
  cat(sprintf(
    "    OR = %.3f (95%% CI: %.3f - %.3f), p = %s\n",
    dhw_row$odds_ratio, dhw_row$or_ci_lower, dhw_row$or_ci_upper,
    ifelse(is.na(dhw_row$`Pr(>|z|)`), "NA (descriptive only; sparse support)", sprintf("%.4f", dhw_row$`Pr(>|z|)`))
  ))
}

if (!is.null(coef_sev)) {
  sev_row <- coef_sev %>% dplyr::filter(term == "max_event_severity")
  cat(sprintf("\n  Disturbance severity effect (GLMM):\n"))
  cat(sprintf("    OR = %.3f (95%% CI: %.3f - %.3f), p = %.4f\n",
              sev_row$odds_ratio, sev_row$or_ci_lower, sev_row$or_ci_upper,
              sev_row$`Pr(>|z|)`))
}

cat(sprintf("\n  Disturbance frequency:\n"))
cat(sprintf("    %.1f%% of study-years have any documented disturbance\n", frac_any * 100))
cat(sprintf("    %.1f%% have major/catastrophic disturbance\n", frac_major * 100))
cat(sprintf("    FL Keys major event return interval: ~%.1f years\n", return_interval_flk))

cat("\n  Outputs:\n")
cat("    - 06_analysis/output/disturbance_survival_glmm.csv\n")
cat("    - 06_analysis/output/disturbance_dhw_coverage.csv\n")
cat("    - 06_analysis/output/disturbance_frequency.csv\n")
cat("    - 06_analysis/figures/supplementary/FigSXX_disturbance_timeline.png (+.pdf)\n")

cat("\n  CAVEATS:\n")
cat("    - Disturbance database is literature-compiled, not exhaustive\n")
cat(sprintf("    - DHW support: %s (%d matched survival rows from %s)\n",
            dhw_coverage$inference_support[1],
            dhw_coverage$n_survival_rows_with_dhw[1],
            ifelse(is.na(dhw_coverage$dhw_file[1]), "no file", dhw_coverage$dhw_file[1])))
cat("    - DHW data are satellite-derived at ~25km resolution and often literature-LUT backed\n")
cat("    - survey_yr = interval START; disturbances may span multi-year intervals\n")
cat("    - NOAA dominates the time series (78%% of data); interpret with caution\n")
cat("    - Neely overlap (2010-2015) provides partial independent validation\n\n")
