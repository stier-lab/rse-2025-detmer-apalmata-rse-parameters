################################################################################
# 01_functions.R - Shared Functions for Analysis Pipeline
################################################################################
#
# Requires: 00_libraries.R, 00b_color_palette.R, 00c_analysis_constants.R
#
# Sections:
#   1. Project root detection
#   2. Output directory setup
#   3. Size class functions
#   4. Data validation
#   5. Manuscript figure helpers (theme, boundaries, save)
#   6. Overdispersion test (binomial GLMMs)
#   7. Statistical metrics (binary classification, I-squared)
#   8. Console output helpers
#   9. Pipeline metadata helpers
# Note: Threshold detection functions moved to 02_threshold_functions.R
################################################################################

# =============================================================================
# 1. PROJECT ROOT DETECTION
# =============================================================================

find_project_root <- function() {
  candidates <- c(".", "..", "../..", "../../..")
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "05_data/standardized"))) {
      return(normalizePath(candidate))
    }
    # Fallback: also check old layout for backward compatibility
    if (file.exists(file.path(candidate, "standardized_data"))) {
      return(normalizePath(candidate))
    }
  }
  stop("Cannot find project root. Run from project directory or 06_analysis/scripts/")
}

get_project_root <- function() {
  if (!exists(".project_root_cache", envir = .GlobalEnv)) {
    assign(".project_root_cache", find_project_root(), envir = .GlobalEnv)
  }
  get(".project_root_cache", envir = .GlobalEnv)
}

# =============================================================================
# 2. OUTPUT DIRECTORY SETUP
# =============================================================================

setup_output_dirs <- function(project_root = NULL) {
  if (is.null(project_root)) project_root <- get_project_root()

  dirs <- list(
    output              = file.path(project_root, "06_analysis/output"),
    figures_manuscript  = file.path(project_root, "06_analysis/figures/manuscript"),
    figures_supp        = file.path(project_root, "06_analysis/figures/supplementary"),
    figures_exp         = file.path(project_root, "06_analysis/figures/supplementary/exploratory"),
    reporting_generated = file.path(project_root, "07_reporting/generated")
  )

  for (dir in dirs) dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  return(dirs)
}

# =============================================================================
# 3. PIPELINE METADATA HELPERS
# =============================================================================

read_data_registry <- function(project_root = NULL) {
  if (is.null(project_root)) project_root <- get_project_root()

  registry_file <- file.path(project_root, "05_data/standardized/data_registry.csv")
  if (!file.exists(registry_file)) {
    stop(sprintf("Data registry not found: %s", registry_file))
  }

  readr::read_csv(registry_file, show_col_types = FALSE) %>%
    dplyr::mutate(
      required_columns = trimws(required_columns),
      key_columns = trimws(key_columns),
      study_column = trimws(study_column),
      region_column = trimws(region_column),
      year_column = trimws(year_column)
    )
}

split_registry_field <- function(x) {
  if (length(x) == 0 || is.na(x) || trimws(x) == "") {
    return(character(0))
  }

  trimws(unlist(strsplit(as.character(x), ";")))
}

count_duplicate_keys <- function(df, key_columns) {
  if (length(key_columns) == 0 || !all(key_columns %in% names(df))) {
    return(NA_integer_)
  }

  nrow(df) - nrow(dplyr::distinct(df, dplyr::across(dplyr::all_of(key_columns))))
}

snapshot_standardized_table <- function(file_path,
                                        file_role = NA_character_,
                                        description = NA_character_,
                                        required_columns = character(0),
                                        key_columns = character(0),
                                        study_column = NA_character_,
                                        region_column = NA_character_,
                                        year_column = NA_character_) {
  exists_flag <- file.exists(file_path)
  info <- if (exists_flag) file.info(file_path) else NULL

  out <- data.frame(
    file_name = basename(file_path),
    path = normalizePath(file_path, winslash = "/", mustWork = FALSE),
    exists = exists_flag,
    file_role = file_role,
    description = description,
    modified_time = if (exists_flag) format(info$mtime, "%Y-%m-%d %H:%M:%S") else NA_character_,
    file_size_bytes = if (exists_flag) as.numeric(info$size) else NA_real_,
    md5 = if (exists_flag) as.character(tools::md5sum(file_path)) else NA_character_,
    n_rows = NA_integer_,
    n_cols = NA_integer_,
    n_studies = NA_integer_,
    n_regions = NA_integer_,
    min_year = NA_real_,
    max_year = NA_real_,
    missing_required_columns = NA_character_,
    duplicate_key_rows = NA_integer_,
    stringsAsFactors = FALSE
  )

  if (!exists_flag) {
    out$missing_required_columns <- paste(required_columns, collapse = "; ")
    return(out)
  }

  df <- readr::read_csv(file_path, show_col_types = FALSE, progress = FALSE)
  if (names(df)[1] %in% c("...1", "X1", "")) {
    df <- dplyr::select(df, -1)
  }

  missing_cols <- setdiff(required_columns, names(df))
  year_values <- if (!is.na(year_column) && year_column %in% names(df)) {
    suppressWarnings(as.numeric(df[[year_column]]))
  } else {
    numeric(0)
  }

  out$n_rows <- nrow(df)
  out$n_cols <- ncol(df)
  out$n_studies <- if (!is.na(study_column) && study_column %in% names(df)) dplyr::n_distinct(df[[study_column]]) else NA_integer_
  out$n_regions <- if (!is.na(region_column) && region_column %in% names(df)) dplyr::n_distinct(df[[region_column]]) else NA_integer_
  out$min_year <- if (length(year_values) > 0 && any(!is.na(year_values))) min(year_values, na.rm = TRUE) else NA_real_
  out$max_year <- if (length(year_values) > 0 && any(!is.na(year_values))) max(year_values, na.rm = TRUE) else NA_real_
  out$missing_required_columns <- if (length(missing_cols) == 0) "" else paste(missing_cols, collapse = "; ")
  out$duplicate_key_rows <- count_duplicate_keys(df, key_columns)

  out
}

build_standardized_inventory <- function(project_root = NULL, registry = NULL) {
  if (is.null(project_root)) project_root <- get_project_root()
  if (is.null(registry)) registry <- read_data_registry(project_root)

  rows <- lapply(seq_len(nrow(registry)), function(i) {
    row <- registry[i, ]
    snapshot_standardized_table(
      file_path = file.path(project_root, "05_data/standardized", row$file_name),
      file_role = row$file_role,
      description = row$description,
      required_columns = split_registry_field(row$required_columns),
      key_columns = split_registry_field(row$key_columns),
      study_column = ifelse(is.na(row$study_column) || row$study_column == "", NA_character_, row$study_column),
      region_column = ifelse(is.na(row$region_column) || row$region_column == "", NA_character_, row$region_column),
      year_column = ifelse(is.na(row$year_column) || row$year_column == "", NA_character_, row$year_column)
    )
  })

  dplyr::bind_rows(rows)
}

validate_registry_inputs <- function(project_root = NULL,
                                     registry = NULL,
                                     roles = c("canonical_input", "curated_support")) {
  if (is.null(project_root)) project_root <- get_project_root()
  if (is.null(registry)) registry <- read_data_registry(project_root)

  inventory <- build_standardized_inventory(project_root, registry)
  target <- inventory %>% dplyr::filter(file_role %in% roles)

  missing_files <- target %>% dplyr::filter(!exists)
  missing_columns <- target %>% dplyr::filter(exists, missing_required_columns != "")

  if (nrow(missing_files) > 0) {
    stop("Missing required standardized inputs: ", paste(missing_files$file_name, collapse = ", "))
  }

  if (nrow(missing_columns) > 0) {
    problems <- paste0(missing_columns$file_name, " [", missing_columns$missing_required_columns, "]")
    stop("Standardized inputs missing required columns: ", paste(problems, collapse = "; "))
  }

  inventory
}

write_markdown_lines <- function(lines, file_path) {
  dir.create(dirname(file_path), showWarnings = FALSE, recursive = TRUE)
  writeLines(lines, file_path, useBytes = TRUE)
  invisible(file_path)
}

# =============================================================================
# 4. SIZE CLASS FUNCTIONS
# =============================================================================

assign_size_class <- function(size_cm2, labels = "standard") {
  label_set <- switch(labels,
    "standard"    = SIZE_LABELS,
    "short"       = SIZE_LABELS_SHORT,
    "descriptive" = SIZE_LABELS_DESC,
    SIZE_LABELS
  )
  cut(size_cm2, breaks = SIZE_BREAKS, labels = label_set,
      include.lowest = TRUE, right = TRUE)
}

add_size_class <- function(df, size_col = "size_cm2", labels = "short") {
  if (!size_col %in% names(df)) {
    stop(sprintf("Column '%s' not found in data frame", size_col))
  }
  df$size_class <- assign_size_class(df[[size_col]], labels = labels)
  return(df)
}

# =============================================================================
# 5. DATA VALIDATION & QC
# =============================================================================

#' Flag sub-annual observation intervals
#' @param time_interval_yr Numeric vector of intervals in years
#' @param threshold Minimum threshold for annual classification (default 0.8)
is_sub_annual <- function(time_interval_yr, threshold = 0.8) {
  !is.na(time_interval_yr) & time_interval_yr < threshold
}

#' Flag biologically impossible growth values
#' @param growth_cm2_yr Numeric vector of annual growth
#' @param initial_size_cm2 Numeric vector of initial colony size
#' @param loss_tolerance Tolerance factor for tissue loss (default 1.1 = 110%)
#' @param gain_limit Maximum plausible growth factor (default 3.0 = 300%)
is_impossible_growth <- function(growth_cm2_yr, initial_size_cm2, 
                                 loss_tolerance = 1.1, gain_limit = 3.0) {
  # Tissue loss exceeding initial size by more than 10%
  is_impossible_loss <- (growth_cm2_yr < 0 & abs(growth_cm2_yr) > initial_size_cm2 * loss_tolerance)
  
  # Positive growth exceeding initial size by more than 200% (tripling)
  is_impossible_gain <- (growth_cm2_yr > 0 & growth_cm2_yr > initial_size_cm2 * gain_limit)
  
  return(is_impossible_loss | is_impossible_gain)
}

#' Flag regions with known high-variance growth (e.g., Navassa)
#' @param region Character vector of region names
is_high_variance_region <- function(region) {
  high_var_regions <- c("Navassa")
  region %in% high_var_regions
}

canonical_region_group <- function(region) {
  region_chr <- as.character(region)
  region_low <- trimws(tolower(region_chr))
  region_low <- gsub("_", " ", region_low)

  out <- rep(NA_character_, length(region_low))
  out[grepl("caribbean-wide|^caribbean$", region_low)] <- "Caribbean-wide"
  out[grepl("dry tortugas|florida|fl keys|middle keys", region_low)] <- "Florida"
  out[grepl("us virgin islands|usvi|virgin islands", region_low)] <- "US Virgin Islands"
  out[grepl("mexic", region_low)] <- "Mexican Caribbean"
  out[grepl("puerto rico", region_low)] <- "Puerto Rico"
  out[grepl("cuba", region_low)] <- "Cuba"
  out[grepl("belize", region_low)] <- "Belize"
  out[grepl("cura[cç]ao|curacao", region_low)] <- "Curacao"
  out[grepl("dominican republic", region_low)] <- "Dominican Republic"
  out[grepl("navassa", region_low)] <- "Navassa"

  empty_idx <- is.na(region_low) | region_low == ""
  out[empty_idx] <- NA_character_

  fallback_idx <- is.na(out) & !empty_idx
  out[fallback_idx] <- tools::toTitleCase(region_low[fallback_idx])
  out
}

expand_disturbance_regions <- function(region_string) {
  if (is.na(region_string) || region_string == "") {
    return(character(0))
  }

  tokens <- trimws(unlist(strsplit(as.character(region_string), "/")))
  tokens <- tokens[tokens != ""]
  unique(canonical_region_group(tokens))
}

parse_disturbance_intensity <- function(x) {
  x_chr <- as.character(x)
  x_chr <- trimws(x_chr)
  lower_bound <- sub("-.*$", "", x_chr)
  suppressWarnings(as.numeric(gsub("[^0-9.]+", "", lower_bound)))
}

classify_disturbance_severity <- function(metric, value, impact) {
  metric_low <- tolower(trimws(as.character(metric)))
  impact_low <- tolower(trimws(as.character(impact)))
  value_num <- parse_disturbance_intensity(value)

  out <- rep("Moderate", length(metric_low))

  out[metric_low == "category" & value_num >= 4] <- "Major"
  out[metric_low == "category" & value_num >= 5] <- "Catastrophic"

  out[metric_low %in% c("population loss", "urchin mortality") & value_num >= 50] <- "Major"
  out[metric_low %in% c("population loss", "urchin mortality") & value_num >= 80] <- "Catastrophic"

  out[metric_low == "dhw" & value_num >= 8] <- "Major"
  out[metric_low == "dhw" & value_num >= 20] <- "Catastrophic"

  out[metric_low == "min temp" & !is.na(value_num) & value_num <= 10] <- "Catastrophic"
  out[metric_low == "chlorophyll-a" & !is.na(value_num) & value_num >= 1] <- "Major"
  out[metric_low == "macroalgal cover" & !is.na(value_num) & value_num >= 80] <- "Major"
  out[metric_low == "caco3 reduction" & !is.na(value_num) & value_num >= 25] <- "Major"
  out[metric_low == "area" & !is.na(value_num) & value_num >= 500] <- "Major"
  out[metric_low == "fragments" & !is.na(value_num) & value_num >= 1000] <- "Major"
  out[metric_low == "peak biomass" & !is.na(value_num) & value_num >= 30] <- "Major"
  out[metric_low == "tissue loss" & !is.na(value_num) & value_num >= 10] <- "Major"
  out[metric_low == "frequency" & !is.na(value_num) & value_num >= 3] <- "Major"

  out[grepl("functional extinction|100% loss|80% destruction|foundational collapse|no recruitment",
            impact_low)] <- "Catastrophic"
  out[grepl("mass mortality|severe|devastating|collapse|phase shift", impact_low)] <- "Major"

  out
}

attach_disturbance_timeline <- function(df, timeline,
                                        region_col = "region",
                                        year_col = "survey_yr",
                                        interval_col = "time_interval_yr",
                                        legacy_col = "disturbance") {
  if (nrow(df) == 0 || nrow(timeline) == 0) {
    return(df)
  }

  expanded_rows <- lapply(seq_len(nrow(timeline)), function(i) {
    groups <- expand_disturbance_regions(timeline$Region[i])
    if (length(groups) == 0) {
      return(NULL)
    }

    data.frame(
      event_row = i,
      region_group = groups,
      Event_Name = timeline$Event_Name[i],
      Event_Type = timeline$Event_Type[i],
      Region = timeline$Region[i],
      Start_Year = timeline$Start_Year[i],
      End_Year = timeline$End_Year[i],
      Duration = timeline$Duration[i],
      Intensity_Metric = timeline$Intensity_Metric[i],
      Intensity_Value = timeline$Intensity_Value[i],
      Impact_Description = timeline$Impact_Description[i],
      Source = timeline$Source[i],
      Spatial_Scale = if ("Spatial_Scale" %in% names(timeline)) timeline$Spatial_Scale[i] else NA_character_,
      Analysis_Tier = if ("Analysis_Tier" %in% names(timeline)) timeline$Analysis_Tier[i] else NA_character_,
      Exclude_From_Baseline = if ("Exclude_From_Baseline" %in% names(timeline)) {
        as.logical(timeline$Exclude_From_Baseline[i])
      } else {
        NA
      },
      stringsAsFactors = FALSE
    )
  })

  timeline_long <- do.call(rbind, expanded_rows)
  if (is.null(timeline_long) || nrow(timeline_long) == 0) {
    return(df)
  }

  timeline_long$severity_class <- classify_disturbance_severity(
    timeline_long$Intensity_Metric,
    timeline_long$Intensity_Value,
    timeline_long$Impact_Description
  )
  timeline_long$Exclude_From_Baseline[is.na(timeline_long$Exclude_From_Baseline)] <- FALSE
  timeline_long$severity_rank <- c(Moderate = 2, Major = 3, Catastrophic = 4)[timeline_long$severity_class]
  timeline_long$duration_rank <- c(Acute = 1, Annual = 2, Chronic = 3)[timeline_long$Duration]

  survey_year <- suppressWarnings(as.numeric(df[[year_col]]))
  interval_years <- if (interval_col %in% names(df)) suppressWarnings(as.numeric(df[[interval_col]])) else rep(1, nrow(df))
  interval_years[is.na(interval_years) | interval_years <= 0] <- 1
  interval_end_year <- floor(survey_year + pmax(interval_years, 1) - 1e-9)
  interval_end_year[is.na(interval_end_year)] <- survey_year[is.na(interval_end_year)]
  row_region_group <- canonical_region_group(df[[region_col]])

  matches <- vector("list", nrow(df))
  for (i in seq_len(nrow(timeline_long))) {
    event_region <- timeline_long$region_group[i]
    applies <- !is.na(survey_year) &
      !is.na(row_region_group) &
      (event_region == "Caribbean-wide" | row_region_group == event_region) &
      survey_year <= timeline_long$End_Year[i] &
      interval_end_year >= timeline_long$Start_Year[i]

    hit_idx <- which(applies)
    if (length(hit_idx) > 0) {
      for (j in hit_idx) {
        matches[[j]] <- c(matches[[j]], i)
      }
    }
  }

  timeline_event_count <- integer(nrow(df))
  timeline_event_names <- rep(NA_character_, nrow(df))
  timeline_event_types <- rep(NA_character_, nrow(df))
  timeline_sources <- rep(NA_character_, nrow(df))
  timeline_spatial_scales <- rep(NA_character_, nrow(df))
  timeline_analysis_tiers <- rep(NA_character_, nrow(df))
  primary_event_name <- rep(NA_character_, nrow(df))
  primary_event_type <- rep(NA_character_, nrow(df))
  primary_intensity_value <- rep(NA_character_, nrow(df))
  primary_impact_description <- rep(NA_character_, nrow(df))
  disturbance_regime <- rep(NA_character_, nrow(df))
  exclude_from_baseline <- rep(FALSE, nrow(df))
  is_catastrophic <- rep(FALSE, nrow(df))
  is_major_disturbance <- rep(FALSE, nrow(df))

  legacy_disturbance <- if (legacy_col %in% names(df)) as.character(df[[legacy_col]]) else rep(NA_character_, nrow(df))

  for (row_idx in seq_len(nrow(df))) {
    match_idx <- unique(matches[[row_idx]])

    if (length(match_idx) == 0) {
      disturbance_regime[row_idx] <- if (!is.na(legacy_disturbance[row_idx]) && legacy_disturbance[row_idx] != "") {
        legacy_disturbance[row_idx]
      } else {
        "none"
      }
      next
    }

    matched <- timeline_long[match_idx, , drop = FALSE]
    matched <- matched[order(-as.integer(matched$Exclude_From_Baseline), -matched$severity_rank,
                             matched$duration_rank, matched$Start_Year, matched$Event_Name), , drop = FALSE]

    unique_events <- unique(matched$Event_Name)
    unique_types <- unique(matched$Event_Type)

    timeline_event_count[row_idx] <- length(unique_events)
    timeline_event_names[row_idx] <- paste(unique_events, collapse = "; ")
    timeline_event_types[row_idx] <- paste(unique_types, collapse = "; ")
    timeline_sources[row_idx] <- paste(unique(matched$Source), collapse = "; ")
    timeline_spatial_scales[row_idx] <- paste(unique(na.omit(matched$Spatial_Scale)), collapse = "; ")
    timeline_analysis_tiers[row_idx] <- paste(unique(na.omit(matched$Analysis_Tier)), collapse = "; ")

    primary_event_name[row_idx] <- matched$Event_Name[1]
    primary_event_type[row_idx] <- matched$Event_Type[1]
    primary_intensity_value[row_idx] <- matched$Intensity_Value[1]
    primary_impact_description[row_idx] <- matched$Impact_Description[1]

    disturbance_regime[row_idx] <- if (length(unique_types) == 1) unique_types[1] else "compound"
    exclude_from_baseline[row_idx] <- any(matched$Exclude_From_Baseline %in% TRUE)
    is_catastrophic[row_idx] <- any(matched$severity_class == "Catastrophic", na.rm = TRUE)
    is_major_disturbance[row_idx] <- any(matched$severity_class %in% c("Major", "Catastrophic"), na.rm = TRUE)
  }

  df$region_group <- row_region_group
  df$timeline_interval_end_year <- interval_end_year
  df$timeline_event_count <- timeline_event_count
  df$timeline_event_names <- timeline_event_names
  df$timeline_event_types <- timeline_event_types
  df$timeline_sources <- timeline_sources
  df$timeline_spatial_scales <- timeline_spatial_scales
  df$timeline_analysis_tiers <- timeline_analysis_tiers
  df$Event_Name <- primary_event_name
  df$Event_Type <- primary_event_type
  df$Intensity_Value <- primary_intensity_value
  df$Impact_Description <- primary_impact_description
  df$disturbance_regime <- disturbance_regime
  df$exclude_from_baseline <- exclude_from_baseline
  df$is_catastrophic <- is_catastrophic
  df$is_major_disturbance <- is_major_disturbance

  df
}

validate_survival_data <- function(df) {
  required_cols <- c("survived", "size_cm2", "study")
  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    stop(sprintf("Missing required columns: %s", paste(missing, collapse = ", ")))
  }
  if (!all(df$survived %in% c(0, 1, NA))) warning("'survived' contains non-binary values")
  if (any(df$size_cm2 <= 0, na.rm = TRUE)) warning("'size_cm2' contains non-positive values")
  return(TRUE)
}

validate_growth_data <- function(df) {
  required_cols <- c("size_cm2", "final_size_cm2", "study")
  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    stop(sprintf("Missing required columns: %s", paste(missing, collapse = ", ")))
  }
  if (any(df$size_cm2 <= 0, na.rm = TRUE)) warning("'size_cm2' contains non-positive values")
  return(TRUE)
}

# =============================================================================
# 6. MANUSCRIPT FIGURE HELPERS
# =============================================================================

theme_manuscript <- function(base_size = 11) {
  pal <- MANUSCRIPT_PALETTE
  ggplot2::theme_minimal(base_size = base_size) %+replace%
    ggplot2::theme(
      text             = ggplot2::element_text(family = "sans", color = pal$slate_dark),
      plot.title       = ggplot2::element_blank(),
      plot.subtitle    = ggplot2::element_blank(),
      axis.title       = ggplot2::element_text(size = 11),
      axis.text        = ggplot2::element_text(size = 9, color = "grey30"),
      strip.text       = ggplot2::element_text(size = 10, face = "bold"),
      axis.line        = ggplot2::element_line(color = "grey30", linewidth = 0.4),
      panel.grid.major = ggplot2::element_line(color = pal$grid, linewidth = 0.4),
      panel.grid.minor = ggplot2::element_blank(),
      panel.background = ggplot2::element_rect(fill = "white", color = NA),
      plot.background  = ggplot2::element_rect(fill = "white", color = NA),
      legend.position  = "bottom",
      legend.box       = "horizontal",
      legend.key.size  = ggplot2::unit(4, "mm"),
      plot.margin      = ggplot2::margin(10, 10, 10, 10, "mm"),
      plot.tag         = ggplot2::element_text(size = 12, face = "bold", color = pal$slate_dark)
    )
}

geom_sc_boundaries <- function(bounds = c(10, 100, 900, 4000)) {
  pal <- MANUSCRIPT_PALETTE
  list(
    ggplot2::geom_vline(xintercept = bounds, linetype = "dotted",
                        color = pal$slate_light, linewidth = 0.4, alpha = 0.7),
    ggplot2::annotate("text",
                      x = c(3, 35, 300, 1900, 8000), y = Inf,
                      label = SIZE_LABELS,
                      vjust = 1.3, size = 3.0, color = pal$slate_mid, fontface = "bold")
  )
}

save_manuscript_fig <- function(plot, filename, width_mm = 170, height_mm = 120,
                                fig_dir = NULL) {
  if (is.null(fig_dir)) {
    fig_dir <- file.path(get_project_root(), "06_analysis/figures/manuscript")
  }
  dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

  png_path <- file.path(fig_dir, paste0(filename, ".png"))
  pdf_path <- file.path(fig_dir, paste0(filename, ".pdf"))

  ggplot2::ggsave(png_path, plot = plot,
                  width = width_mm, height = height_mm, units = "mm", dpi = 300, bg = "white")

  pdf_device <- if (capabilities("cairo")) cairo_pdf else "pdf"
  ggplot2::ggsave(pdf_path, plot = plot,
                  width = width_mm, height = height_mm, units = "mm",
                  bg = "white", device = pdf_device)

  cat(sprintf("  Saved: %s (.png + .pdf) -- %d x %d mm\n", filename, width_mm, height_mm))
}

# =============================================================================
# 7. OVERDISPERSION TEST (binomial GLMMs)
# =============================================================================

#' Test for overdispersion in a binomial GLMM
#' @param model A fitted glmer model (family = binomial)
#' @return List with ratio, p_value, and overdispersed flag
overdisp_test <- function(model) {
  pearson_resid <- residuals(model, type = "pearson")
  n <- length(pearson_resid)
  # Count fixed effects + random effect variance parameters
  p <- length(fixef(model)) + sum(sapply(VarCorr(model), function(x) prod(dim(x))))
  ratio <- sum(pearson_resid^2) / (n - p)
  return(list(
    ratio = ratio,
    p_value = pchisq(sum(pearson_resid^2), df = n - p, lower.tail = FALSE),
    overdispersed = ratio > 1.5
  ))
}

# =============================================================================
# 8. STATISTICAL METRICS
# =============================================================================

#' Binary classification metrics (Brier, log-loss, AUC, accuracy)
calc_binary_metrics <- function(actual, predicted_prob, threshold = 0.5) {
  brier <- mean((predicted_prob - actual)^2, na.rm = TRUE)

  eps <- 1e-10
  predicted_prob <- pmax(pmin(predicted_prob, 1 - eps), eps)
  logloss <- -mean(actual * log(predicted_prob) +
                   (1 - actual) * log(1 - predicted_prob), na.rm = TRUE)

  if (length(unique(actual)) == 2) {
    pred_1 <- predicted_prob[actual == 1]
    pred_0 <- predicted_prob[actual == 0]
    if (length(pred_1) > 0 && length(pred_0) > 0) {
      auc <- mean(outer(pred_1, pred_0, ">")) + 0.5 * mean(outer(pred_1, pred_0, "=="))
    } else {
      auc <- NA
    }
  } else {
    auc <- NA
  }

  predicted_class <- as.numeric(predicted_prob >= threshold)
  accuracy <- mean(predicted_class == actual, na.rm = TRUE)
  tp <- sum(predicted_class == 1 & actual == 1, na.rm = TRUE)
  fp <- sum(predicted_class == 1 & actual == 0, na.rm = TRUE)
  fn <- sum(predicted_class == 0 & actual == 1, na.rm = TRUE)
  tn <- sum(predicted_class == 0 & actual == 0, na.rm = TRUE)
  sensitivity <- if ((tp + fn) > 0) tp / (tp + fn) else NA
  specificity <- if ((tn + fp) > 0) tn / (tn + fp) else NA

  data.frame(
    brier_score = brier, log_loss = logloss, auc = auc,
    accuracy = accuracy, sensitivity = sensitivity, specificity = specificity,
    n_test = length(actual)
  )
}

#' I-squared heterogeneity statistic
calc_i_squared <- function(Q, df) {
  I_sq <- max(0, (Q - df) / Q) * 100
  interpretation <- dplyr::case_when(
    I_sq < 25  ~ "Low",
    I_sq < 50  ~ "Moderate",
    I_sq < 75  ~ "Substantial",
    TRUE       ~ "Considerable"
  )
  I_sq_lower <- max(0, (Q - df - 1.96 * sqrt(2 * df)) / Q) * 100
  I_sq_upper <- min(100, (Q - df + 1.96 * sqrt(2 * df)) / Q) * 100

  list(
    I_squared = I_sq, I_sq_lower = I_sq_lower, I_sq_upper = I_sq_upper,
    interpretation = interpretation, Q = Q, df = df
  )
}

#' Wilson confidence interval for proportions
wilson_ci <- function(x, n, alpha = 0.05) {
  z <- qnorm(1 - alpha / 2)
  p_hat <- x / n
  denom <- 1 + z^2 / n
  center <- (p_hat + z^2 / (2 * n)) / denom
  margin <- z * sqrt((p_hat * (1 - p_hat) + z^2 / (4 * n)) / n) / denom
  list(estimate = p_hat, lower = max(0, center - margin), upper = min(1, center + margin))
}

# =============================================================================
# 9. CONSOLE OUTPUT HELPERS
# =============================================================================

print_header <- function(title, width = 65) {
  cat("\n")
  cat(paste0(rep("=", width), collapse = ""), "\n")
  cat(sprintf("  %s\n", title))
  cat(paste0(rep("=", width), collapse = ""), "\n\n")
}

print_subheader <- function(title, width = 65) {
  cat("\n")
  cat(paste0(rep("-", width), collapse = ""), "\n")
  cat(sprintf("  %s\n", title))
  cat(paste0(rep("-", width), collapse = ""), "\n")
}

print_success <- function(message) cat(sprintf("  > %s\n", message))
print_warn    <- function(message) cat(sprintf("  ! %s\n", message))
print_info    <- function(message) cat(sprintf("  i %s\n", message))

# =============================================================================
# 9. PIPELINE METADATA HELPERS
# =============================================================================

discover_standardization_scripts <- function(project_root = NULL) {
  if (is.null(project_root)) project_root <- get_project_root()
  scripts_dir <- file.path(project_root, "06_analysis/scripts")
  sort(list.files(scripts_dir, pattern = "^00_.*\\.R$", full.names = FALSE))
}

label_script_name <- function(script_name) {
  stem <- basename(script_name)
  stem <- sub("\\.R$", "", stem)
  stem <- sub("^[0-9]+[a-z]?_", "", stem)
  stem <- gsub("_", " ", stem)
  tools::toTitleCase(stem)
}

pipeline_data_input_files <- function(project_root = NULL) {
  if (is.null(project_root)) project_root <- get_project_root()

  input_dirs <- c(
    file.path(project_root, "05_data/original"),
    file.path(project_root, "05_data/standardized")
  )
  pattern <- "\\.(csv|tsv|txt|xlsx|xls|rds|RDS)$"

  inputs <- unlist(lapply(input_dirs, function(dir_path) {
    if (!dir.exists(dir_path)) return(character(0))
    list.files(dir_path, pattern = pattern, full.names = TRUE)
  }))

  sort(unique(inputs))
}

standardized_data_summary <- function(project_root = NULL) {
  if (is.null(project_root)) project_root <- get_project_root()
  std_dir <- file.path(project_root, "05_data/standardized")
  csv_files <- sort(list.files(std_dir, pattern = "\\.csv$", full.names = TRUE))

  if (length(csv_files) == 0) {
    return(data.frame(
      file = character(),
      rows = integer(),
      cols = integer(),
      modified_time = character(),
      md5 = character(),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(csv_files, function(path) {
    data <- readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
    info <- file.info(path)
    data.frame(
      file = sub(paste0("^", normalizePath(project_root, winslash = "/"), "/"), "",
                 normalizePath(path, winslash = "/")),
      rows = nrow(data),
      cols = ncol(data),
      modified_time = format(info$mtime, "%Y-%m-%d %H:%M:%S"),
      md5 = unname(tools::md5sum(path)),
      stringsAsFactors = FALSE
    )
  })

  dplyr::bind_rows(rows)
}

canonical_artifact_registry <- function(project_root = NULL) {
  if (is.null(project_root)) project_root <- get_project_root()

  data.frame(
    category = c(
      rep("prepared_data", 2),
      rep("core_results", 5),
      rep("disturbance_results", 6),
      rep("diagnostics", 32),
      rep("verification", 2),
      rep("pipeline_audit", 3),
      rep("manuscript_figures", 4),
      rep("supplementary_figures", 19),
      rep("supplementary_tables", 2),
      rep("generated_reporting", 4)
    ),
    artifact = c(
      "prepared_survival_data",
      "prepared_growth_data",
      "survival_thresholds",
      "growth_thresholds",
      "expanded_meta_analysis_results",
      "population_parameters",
      "vital_rate_elasticity",
      "disturbance_sensitivity_summary",
      "disturbance_event_catalog",
      "shrinkage_retrogression_size_class_summary",
      "disturbance_size_survival_model",
      "study_window_disturbance_audit",
      "restoration_subtype_sensitivity",
      "survival_gam_diagnostics",
      "summary_temporal_coverage",
      "climate_dhw_coverage",
      "climate_dhw_glmm",
      "temporal_trend_glmm_diagnostics",
      "heat_stress_model_diagnostics",
      "disturbance_dhw_coverage",
      "disturbance_survival_glmm",
      "disturbance_sensitivity_model_diagnostics",
      "disturbance_sensitivity_scenario_status",
      "disturbance_sensitivity_influence",
      "disturbance_size_model_diagnostics",
      "expanded_meta_primary_model_diagnostics",
      "expanded_meta_primary_jackknife",
      "expanded_meta_moderator_diagnostics",
      "natural_vs_restoration_model_diagnostics",
      "lambda_bootstrap_diagnostics",
      "transition_matrix_model_diagnostics",
      "transition_matrix_imputation_sensitivity",
      "transition_matrix_source_leverage",
      "multistate_model_diagnostics",
      "joint_longitudinal_fit_metrics",
      "stochastic_ipm_model_diagnostics",
      "stochastic_ipm_recruitment_scenarios",
      "recurrent_event_ph_diagnostics",
      "spatiotemporal_data_coverage",
      "spatiotemporal_growth_kcheck",
      "spatiotemporal_survival_kcheck",
      "spatiotemporal_spatial_residual_check",
      "spatiotemporal_region_blocked_cv",
      "cv_growth_model_comparison",
      "model_selection_workflow_alignment",
      "canonical_statistics",
      "pipeline_assertion_checks",
      "standardized_data_inventory",
      "canonical_artifact_status",
      "pipeline_artifact_freshness",
      "Fig1_study_landscape",
      "Fig2_demographic_rates",
      "Fig3_caribbean_synthesis",
      "Fig4_population_model",
      "FigS1_size_distribution",
      "FigS2_data_gaps",
      "FigS3_model_diagnostics",
      "FigS4_model_selection",
      "FigS5_threshold_analysis",
      "FigS6_agr_vs_rgr",
      "FigS7_allometry",
      "FigS8_natural_vs_restoration",
      "FigS9_heterogeneity",
      "FigS10_context_comparison",
      "FigS11_climate_demography",
      "FigS12_sensitivity",
      "FigS13_cross_validation",
      "FigS14_population_projections",
      "FigS15_regional_survival",
      "FigS16_shrinkage_retrogression_summary",
      "FigS17_disturbance_size_interaction",
      "FigS18_disturbance_summary",
      "FigS19_restoration_subtype_sensitivity",
      "TableS1_disturbance_chronology",
      "TableS2_study_window_disturbance_audit",
      "generated_standardized_data_inventory",
      "generated_canonical_statistics",
      "generated_canonical_artifact_status",
      "generated_pipeline_refresh_report"
    ),
    script = c(
      "01_data_preparation.R",
      "01_data_preparation.R",
      "02_survival_thresholds.R",
      "03_growth_thresholds.R",
      "14b_expanded_meta_analysis.R",
      "13_transition_matrix.R",
      "13_transition_matrix.R",
      "30_disturbance_sensitivity.R",
      "34_disturbance_summaries.R",
      "36_shrinkage_retrogression_summary.R",
      "37_disturbance_size_interaction.R",
      "38_study_window_disturbance_audit.R",
      "39_restoration_subtype_sensitivity.R",
      "02_survival_thresholds.R",
      "01_data_preparation.R",
      "08_climate_demography.R",
      "08_climate_demography.R",
      "08_climate_demography.R",
      "31_heat_stress_overlay.R",
      "32_disturbance_survival_analysis.R",
      "32_disturbance_survival_analysis.R",
      "30_disturbance_sensitivity.R",
      "30_disturbance_sensitivity.R",
      "30_disturbance_sensitivity.R",
      "37_disturbance_size_interaction.R",
      "14b_expanded_meta_analysis.R",
      "14b_expanded_meta_analysis.R",
      "14b_expanded_meta_analysis.R",
      "29_natural_vs_restoration.R",
      "13_transition_matrix.R",
      "13_transition_matrix.R",
      "13_transition_matrix.R",
      "13_transition_matrix.R",
      "41_multistate_transition_model.R",
      "42_joint_longitudinal_survival_model.R",
      "43_stochastic_ipm_disturbance_model.R",
      "43_stochastic_ipm_disturbance_model.R",
      "46_recurrent_event_frailty_model.R",
      "47_spatiotemporal_hierarchical_model.R",
      "47_spatiotemporal_hierarchical_model.R",
      "47_spatiotemporal_hierarchical_model.R",
      "47_spatiotemporal_hierarchical_model.R",
      "47_spatiotemporal_hierarchical_model.R",
      "10_cross_validation.R",
      "12_model_selection.R",
      "23_verification.R",
      "23_verification.R",
      "01_data_preparation.R",
      "48_pipeline_refresh_audit.R",
      "48_pipeline_refresh_audit.R",
      "18_fig1_study_landscape.R",
      "19_fig2_demographic_rates.R",
      "20b_fig_expanded_forest_plot.R",
      "22_fig6_population_model.R",
      "18_fig1_study_landscape.R",
      "23_figS2_data_gaps.R",
      "24_supp_S3_S4.R",
      "24_supp_S3_S4.R",
      "25_supp_S5_S6_S7_thresholds_growth.R",
      "25_supp_S5_S6_S7_thresholds_growth.R",
      "25_supp_S5_S6_S7_thresholds_growth.R",
      "21_fig3_natural_vs_restoration.R",
      "26_supp_S8_S9.R",
      "27_supp_S10_S11.R",
      "27_supp_S10_S11.R",
      "28_supp_S12_S13_S14.R",
      "28_supp_S12_S13_S14.R",
      "28_supp_S12_S13_S14.R",
      "20c_fig_regional_survival.R",
      "36_shrinkage_retrogression_summary.R",
      "37_disturbance_size_interaction.R",
      "34_disturbance_summaries.R",
      "39_restoration_subtype_sensitivity.R",
      "34_disturbance_summaries.R",
      "38_study_window_disturbance_audit.R",
      "48_pipeline_refresh_audit.R",
      "48_pipeline_refresh_audit.R",
      "48_pipeline_refresh_audit.R",
      "48_pipeline_refresh_audit.R"
    ),
    path = c(
      "06_analysis/output/prepared_survival_data.rds",
      "06_analysis/output/prepared_growth_data.rds",
      "06_analysis/output/survival_thresholds.csv",
      "06_analysis/output/growth_thresholds.csv",
      "06_analysis/output/expanded_meta_analysis_results.csv",
      "06_analysis/output/population_parameters.csv",
      "06_analysis/output/vital_rate_elasticity.csv",
      "06_analysis/output/disturbance_sensitivity_summary.csv",
      "06_analysis/output/disturbance_event_catalog.csv",
      "06_analysis/output/shrinkage_retrogression_size_class_summary.csv",
      "06_analysis/output/disturbance_size_survival_model.csv",
      "06_analysis/output/study_window_disturbance_audit.csv",
      "06_analysis/output/restoration_subtype_sensitivity.csv",
      "06_analysis/output/survival_gam_diagnostics.csv",
      "06_analysis/output/summary_temporal_coverage.csv",
      "06_analysis/output/climate_dhw_coverage.csv",
      "06_analysis/output/climate_dhw_glmm.csv",
      "06_analysis/output/temporal_trend_glmm_diagnostics.csv",
      "06_analysis/output/heat_stress_model_diagnostics.csv",
      "06_analysis/output/disturbance_dhw_coverage.csv",
      "06_analysis/output/disturbance_survival_glmm.csv",
      "06_analysis/output/disturbance_sensitivity_model_diagnostics.csv",
      "06_analysis/output/disturbance_sensitivity_scenario_status.csv",
      "06_analysis/output/disturbance_sensitivity_influence.csv",
      "06_analysis/output/disturbance_size_model_diagnostics.csv",
      "06_analysis/output/expanded_meta_primary_model_diagnostics.csv",
      "06_analysis/output/expanded_meta_primary_jackknife.csv",
      "06_analysis/output/expanded_meta_moderator_diagnostics.csv",
      "06_analysis/output/natural_vs_restoration_model_diagnostics.csv",
      "06_analysis/output/lambda_bootstrap_diagnostics.csv",
      "06_analysis/output/transition_matrix_model_diagnostics.csv",
      "06_analysis/output/transition_matrix_imputation_sensitivity.csv",
      "06_analysis/output/transition_matrix_source_leverage.csv",
      "06_analysis/output/multistate_model_diagnostics.csv",
      "06_analysis/output/joint_longitudinal_fit_metrics.csv",
      "06_analysis/output/stochastic_ipm_model_diagnostics.csv",
      "06_analysis/output/stochastic_ipm_recruitment_scenarios.csv",
      "06_analysis/output/recurrent_event_ph_diagnostics.csv",
      "06_analysis/output/spatiotemporal_data_coverage.csv",
      "06_analysis/output/spatiotemporal_growth_kcheck.csv",
      "06_analysis/output/spatiotemporal_survival_kcheck.csv",
      "06_analysis/output/spatiotemporal_spatial_residual_check.csv",
      "06_analysis/output/spatiotemporal_region_blocked_cv.csv",
      "06_analysis/output/cv_growth_model_comparison.csv",
      "06_analysis/output/model_selection_workflow_alignment.csv",
      "06_analysis/output/canonical_statistics.csv",
      "06_analysis/output/pipeline_assertion_checks.csv",
      "06_analysis/output/standardized_data_inventory.csv",
      "06_analysis/output/canonical_artifact_status.csv",
      "06_analysis/output/pipeline_artifact_freshness.csv",
      "06_analysis/figures/manuscript/Fig1_study_landscape.png",
      "06_analysis/figures/manuscript/Fig2_demographic_rates.png",
      "06_analysis/figures/manuscript/Fig3_caribbean_synthesis.png",
      "06_analysis/figures/manuscript/Fig4_population_model.png",
      "06_analysis/figures/supplementary/FigS1_size_distribution.png",
      "06_analysis/figures/supplementary/FigS2_data_gaps.png",
      "06_analysis/figures/supplementary/FigS3_model_diagnostics.png",
      "06_analysis/figures/supplementary/FigS4_model_selection.png",
      "06_analysis/figures/supplementary/FigS5_threshold_analysis.png",
      "06_analysis/figures/supplementary/FigS6_agr_vs_rgr.png",
      "06_analysis/figures/supplementary/FigS7_allometry.png",
      "06_analysis/figures/supplementary/FigS8_natural_vs_restoration.png",
      "06_analysis/figures/supplementary/FigS9_heterogeneity.png",
      "06_analysis/figures/supplementary/FigS10_context_comparison.png",
      "06_analysis/figures/supplementary/FigS11_climate_demography.png",
      "06_analysis/figures/supplementary/FigS12_sensitivity.png",
      "06_analysis/figures/supplementary/FigS13_cross_validation.png",
      "06_analysis/figures/supplementary/FigS14_population_projections.png",
      "06_analysis/figures/supplementary/FigS15_regional_survival.png",
      "06_analysis/figures/supplementary/FigS16_shrinkage_retrogression_summary.png",
      "06_analysis/figures/supplementary/FigS17_disturbance_size_interaction.png",
      "06_analysis/figures/supplementary/FigS18_disturbance_summary.png",
      "06_analysis/figures/supplementary/FigS19_restoration_subtype_sensitivity.png",
      "07_reporting/tables/TableS1_disturbance_chronology.md",
      "07_reporting/tables/TableS2_study_window_disturbance_audit.md",
      "07_reporting/generated/standardized_data_inventory.md",
      "07_reporting/generated/canonical_statistics.md",
      "07_reporting/generated/canonical_artifact_status.md",
      "07_reporting/generated/pipeline_refresh_report.md"
    ),
    stringsAsFactors = FALSE
  )
}

build_file_manifest <- function(paths, project_root = NULL) {
  if (is.null(project_root)) project_root <- get_project_root()
  root_norm <- normalizePath(project_root, winslash = "/", mustWork = FALSE)

  if (length(paths) == 0) {
    return(data.frame(
      path = character(),
      exists = logical(),
      size_bytes = numeric(),
      modified_time = character(),
      md5 = character(),
      stringsAsFactors = FALSE
    ))
  }

  abs_paths <- vapply(paths, function(path) {
    if (grepl("^/", path)) {
      path
    } else {
      file.path(project_root, path)
    }
  }, character(1))

  info <- file.info(abs_paths)
  exists <- !is.na(info$size)
  md5 <- rep(NA_character_, length(abs_paths))
  if (any(exists)) {
    md5[exists] <- unname(tools::md5sum(abs_paths[exists]))
  }

  normalized_abs <- normalizePath(abs_paths, winslash = "/", mustWork = FALSE)
  rel_paths <- sub(paste0("^", root_norm, "/?"), "", normalized_abs)

  data.frame(
    path = rel_paths,
    exists = exists,
    size_bytes = ifelse(exists, info$size, NA_real_),
    modified_time = ifelse(exists, format(info$mtime, "%Y-%m-%d %H:%M:%S"), NA_character_),
    md5 = md5,
    stringsAsFactors = FALSE
  )
}

build_artifact_status <- function(registry, run_start = NULL, project_root = NULL) {
  if (is.null(project_root)) project_root <- get_project_root()
  manifest <- build_file_manifest(registry$path, project_root = project_root)

  out <- cbind(registry, manifest[, c("exists", "size_bytes", "modified_time", "md5")])
  if (!is.null(run_start)) {
    abs_paths <- file.path(project_root, registry$path)
    info <- file.info(abs_paths)
    out$generated_this_run <- out$exists & !is.na(info$mtime) & info$mtime >= run_start
  } else {
    out$generated_this_run <- NA
  }
  out
}

write_markdown_table <- function(df, path, title = NULL, intro = NULL) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  if (ncol(df) == 0) {
    lines <- c(if (!is.null(title)) paste0("# ", title), if (!is.null(intro)) intro, "", "_No rows available._")
    writeLines(lines, path)
    return(invisible(path))
  }

  header <- paste(names(df), collapse = " | ")
  separator <- paste(rep("---", ncol(df)), collapse = " | ")
  rows <- apply(df, 1, function(row) {
    paste(ifelse(is.na(row), "", as.character(row)), collapse = " | ")
  })

  lines <- c()
  if (!is.null(title)) lines <- c(lines, paste0("# ", title), "")
  if (!is.null(intro)) lines <- c(lines, intro, "")
  lines <- c(lines, paste0("| ", header, " |"),
             paste0("| ", separator, " |"),
             paste0("| ", rows, " |"))
  writeLines(lines, path)
  invisible(path)
}

# =============================================================================
# INITIALIZATION
# =============================================================================

.project_root_cache <- tryCatch(
  find_project_root(),
  error = function(e) {
    message("Note: Project root not found. Use find_project_root() manually.")
    NULL
  }
)

cat("Loaded 01_functions.R\n")
if (!is.null(.project_root_cache)) {
  cat(sprintf("  Project root: %s\n", .project_root_cache))
}
