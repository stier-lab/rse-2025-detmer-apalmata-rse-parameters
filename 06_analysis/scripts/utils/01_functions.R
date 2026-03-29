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
    figures_exp         = file.path(project_root, "06_analysis/figures/supplementary/exploratory")
  )

  for (dir in dirs) dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  return(dirs)
}

# =============================================================================
# 3. SIZE CLASS FUNCTIONS
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
# 4. DATA VALIDATION
# =============================================================================

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
# 5. MANUSCRIPT FIGURE HELPERS
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
# 6. OVERDISPERSION TEST (binomial GLMMs)
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
# 7. STATISTICAL METRICS
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
# 8. CONSOLE OUTPUT HELPERS
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
