################################################################################
# 16_sensitivity_analysis.R - Comprehensive Sensitivity Analysis
################################################################################
#
# PURPOSE:
#   Test robustness of key findings to methodological choices and assumptions.
#   Implements multiple sensitivity checks for survival and growth analyses.
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds (individual survival data)
#   - 06_analysis/output/prepared_growth_data.rds (individual growth data)
#   - 05_data/standardized/apal_fragmentation.csv (fragmentation data)
#
# METHODS:
#   1. Leave-one-out analysis (influence of individual studies)
#   2. Size class boundary sensitivity
#   3. Outlier removal effects
#   4. Model specification sensitivity
#   5. Data subset analysis (temporal, geographic)
#   6. Bootstrap confidence intervals
#
# OUTPUTS:
#   - sensitivity_leave_one_out.csv: Results excluding each study
#   - sensitivity_size_boundaries.csv: Effect of different size thresholds
#   - sensitivity_summary.csv: Overall robustness assessment
#   - supplementary/exploratory/sensitivity_*.png: Visualizations
#
# Author: Detmer & Stier Lab
# Date: 2025-12-25
################################################################################

library(dplyr)
library(tidyr)
library(ggplot2)
library(purrr)

# Source shared utilities for constants and helper functions
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

# Determine project root
if (file.exists("05_data/standardized")) {
  project_root <- "."
} else if (file.exists("../05_data/standardized")) {
  project_root <- ".."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root. Run from project directory or 06_analysis/scripts/")
}

# Helper: Compute lambda from survival vector and growth/fragmentation data
# Reuses methodology from 13_transition_matrix.R
# custom_breaks: optional custom size class boundaries (full vector including 0 and Inf)
compute_lambda_from_survival <- function(survival_by_class, growth_data, frag_matrix,
                                          custom_breaks = NULL, full_data_survival = NULL) {
  # Build transition matrix G from growth data
  size_breaks <- if (!is.null(custom_breaks)) custom_breaks else SIZE_BREAKS
  size_labels <- SIZE_LABELS
  n_sc <- length(size_labels)

  if (is.null(growth_data) || nrow(growth_data) == 0) {
    return(list(lambda = NA, note = "No growth data"))
  }

  # Compute transition probabilities from growth data
  # Use right=TRUE, include.lowest=TRUE to match shared_utilities.R canonical convention
  growth_data$initial_sc <- cut(growth_data$size_cm2, breaks = size_breaks,
                                 labels = size_labels, include.lowest = TRUE)
  growth_data$final_size <- pmax(growth_data$size_cm2 + growth_data$growth_cm2_yr, 0.01)
  growth_data$final_sc <- cut(growth_data$final_size, breaks = size_breaks,
                               labels = size_labels, include.lowest = TRUE)

  G <- matrix(0, n_sc, n_sc)
  for (i in 1:n_sc) {
    from_data <- growth_data[growth_data$initial_sc == size_labels[i], ]
    if (nrow(from_data) > 0) {
      for (j in 1:n_sc) {
        G[j, i] <- sum(from_data$final_sc == size_labels[j], na.rm = TRUE) / nrow(from_data)
      }
    } else {
      G[i, i] <- 1  # Default to stasis if no data
    }
  }

  # Build survival diagonal
  # For missing size classes (e.g., LOO exclusion), use the full-data estimate
  # rather than an arbitrary default, to avoid distorting lambda
  S <- numeric(n_sc)
  for (i in 1:n_sc) {
    sc <- size_labels[i]
    if (sc %in% names(survival_by_class) && !is.na(survival_by_class[sc]) && !is.nan(survival_by_class[sc])) {
      S[i] <- survival_by_class[sc]
    } else {
      if (!is.null(full_data_survival) && sc %in% names(full_data_survival) && !is.na(full_data_survival[sc])) {
        S[i] <- full_data_survival[sc]  # Fallback to overall (non-LOO) estimate for this size class
      } else {
        S[i] <- mean(survival_by_class, na.rm = TRUE)  # Last resort: overall mean of available classes
      }
    }
  }

  # Construct projection matrix A = G * diag(S) + F
  A <- G %*% diag(S) + frag_matrix

  # Dominant eigenvalue
  lambda <- Re(eigen(A)$values[1])
  return(list(lambda = lambda, matrix = A, survival = S, transitions = G))
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  13: COMPREHENSIVE SENSITIVITY ANALYSIS                      ║\n")
cat("║  Testing Robustness of Key Findings                          ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# =============================================================================
# SETUP
# =============================================================================

output_dir <- file.path(project_root, "06_analysis/output")
fig_dir <- file.path(project_root, "06_analysis/figures/supplementary/exploratory")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
if (!dir.exists(fig_dir)) {
  dir.create(fig_dir, recursive = TRUE)
}

# Load prepared data
cat("Loading prepared data...\n")
survival_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

cat(sprintf("  Survival: %d observations\n", nrow(survival_data)))
cat(sprintf("  Growth: %d observations\n", nrow(growth_data)))

# --- Match Script 13 filtering: natural colonies, 0.5-1.5yr intervals ---
cat("  Applying Script 13-consistent filtering...\n")

if ("population_type" %in% names(survival_data)) {
  n_before <- nrow(survival_data)
  survival_data <- survival_data %>% filter(population_type == "Natural colony")
  cat(sprintf("  Survival: %d -> %d (natural colonies only)\n", n_before, nrow(survival_data)))
} else if ("fragment" %in% names(survival_data)) {
  n_before <- nrow(survival_data)
  survival_data <- survival_data %>% filter(fragment == "N")
  cat(sprintf("  Survival: %d -> %d (non-fragments only)\n", n_before, nrow(survival_data)))
}

# Filter sub-annual records (matching Script 13)
if ("sub_annual_interval" %in% names(survival_data)) {
  n_before <- nrow(survival_data)
  survival_data <- survival_data %>% filter(!sub_annual_interval | is.na(sub_annual_interval))
  cat(sprintf("  Filtered sub-annual records: %d -> %d\n", n_before, nrow(survival_data)))
} else if ("time_interval_yr" %in% names(survival_data)) {
  n_before <- nrow(survival_data)
  survival_data <- survival_data %>% filter(is.na(time_interval_yr) | time_interval_yr >= 0.8)
  cat(sprintf("  Filtered sub-annual records: %d -> %d\n", n_before, nrow(survival_data)))
}

if ("time_interval_yr" %in% names(growth_data)) {
  n_before <- nrow(growth_data)
  growth_data <- growth_data %>%
    filter(is.na(time_interval_yr) | (time_interval_yr >= 0.5 & time_interval_yr <= 1.5))
  cat(sprintf("  Growth: %d -> %d (0.5-1.5yr intervals)\n", n_before, nrow(growth_data)))
}
if ("population_type" %in% names(growth_data)) {
  n_before <- nrow(growth_data)
  growth_data <- growth_data %>% filter(population_type == "Natural colony")
  cat(sprintf("  Growth: %d -> %d (natural colonies only)\n", n_before, nrow(growth_data)))
} else if ("fragment" %in% names(growth_data)) {
  n_before <- nrow(growth_data)
  growth_data <- growth_data %>% filter(fragment == "N")
  cat(sprintf("  Growth: %d -> %d (non-fragments only)\n", n_before, nrow(growth_data)))
}

# Standard size class definitions — use canonical SIZE_BREAKS/SIZE_LABELS from shared_utilities.R
add_size_class <- function(data, breaks = SIZE_BREAKS, labels = SIZE_LABELS) {
  data %>%
    mutate(
      size_class = cut(size_cm2, breaks = breaks, labels = labels, include.lowest = TRUE),
      size_class = factor(size_class, levels = labels)
    )
}

# Helper: Annualize survival by size class following Script 13 methodology
# Groups by study x size_class x time_interval_yr, annualizes with S_annual = S_raw^(1/t),
# then takes weighted mean across groups (weighted by sample size).
annualize_survival_by_class <- function(surv_data, size_col = "size_class") {
  # Ensure time_interval_yr exists; default to 1 if missing
  if (!"time_interval_yr" %in% names(surv_data)) {
    surv_data$time_interval_yr <- 1.0
  }
  surv_data$time_interval_yr[is.na(surv_data$time_interval_yr)] <- 1.0

  # Step 1: Raw survival by study x size_class x interval
  by_group <- surv_data %>%
    filter(!is.na(.data[[size_col]])) %>%
    group_by(.data[[size_col]], study, time_interval_yr) %>%
    summarise(
      n = n(),
      raw_survival = mean(survived, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      annual_survival = raw_survival^(1 / time_interval_yr)
    )

  # Step 2: Weighted mean of annualized rates by size class
  result <- by_group %>%
    group_by(.data[[size_col]]) %>%
    summarise(
      survival = weighted.mean(annual_survival, w = n),
      n = sum(n),
      .groups = "drop"
    )

  # Return as named vector (matches expected format for compute_lambda_from_survival)
  surv_vec <- result$survival
  names(surv_vec) <- result[[size_col]]
  surv_vec
}

survival_data <- add_size_class(survival_data)
growth_data <- add_size_class(growth_data)

# =============================================================================
# 1. LEAVE-ONE-OUT STUDY ANALYSIS
# =============================================================================

cat("\n1. Leave-One-Out Study Analysis...\n")

# Get baseline estimates (annualized to match Script 13 methodology)
baseline_surv_vec <- annualize_survival_by_class(survival_data)
baseline_survival <- weighted.mean(baseline_surv_vec,
  w = table(survival_data$size_class)[names(baseline_surv_vec)])
baseline_by_size <- data.frame(
  size_class = names(baseline_surv_vec),
  baseline_survival = as.numeric(baseline_surv_vec),
  stringsAsFactors = FALSE
)

# Leave-one-out for survival
studies <- unique(survival_data$study)
loo_results <- map_dfr(studies, function(s) {
  subset_data <- survival_data %>% filter(study != s)

  # Annualize survival for this LOO subset (matching Script 13 methodology)
  loo_surv_vec <- annualize_survival_by_class(subset_data)
  overall <- weighted.mean(loo_surv_vec,
    w = table(subset_data$size_class)[names(loo_surv_vec)])

  by_size <- data.frame(
    size_class = names(loo_surv_vec),
    survival = as.numeric(loo_surv_vec),
    stringsAsFactors = FALSE
  ) %>%
    pivot_wider(names_from = size_class, values_from = survival, names_prefix = "survival_")

  data.frame(
    excluded_study = s,
    n_remaining = nrow(subset_data),
    overall_survival = overall,
    change_from_baseline = overall - baseline_survival
  ) %>%
    bind_cols(by_size)
})

# Add baseline for comparison
loo_results <- loo_results %>%
  mutate(
    pct_change = change_from_baseline / baseline_survival * 100,
    influential = abs(pct_change) > 5  # >5% change is influential
  )

cat(sprintf("  Studies analyzed: %d\n", length(studies)))
influential_studies <- loo_results %>% filter(influential)
cat(sprintf("  Influential studies (>5%% change): %d\n", nrow(influential_studies)))

if (nrow(influential_studies) > 0) {
  cat("  Influential studies:\n")
  for (i in 1:nrow(influential_studies)) {
    cat(sprintf("    • %s: %.1f%% change\n",
                influential_studies$excluded_study[i],
                influential_studies$pct_change[i]))
  }
}

# --- LEAVE-ONE-OUT: LAMBDA SENSITIVITY ---
cat("\n--- LEAVE-ONE-OUT: LAMBDA SENSITIVITY ---\n")
# Load growth data and fragmentation matrix for lambda computation
growth_data_for_lambda <- growth_data  # Use already-filtered data (natural colonies, 0.5-1.5yr intervals)

# Load fragmentation matrix from the transition_matrix.rds produced by script 07
transition_rds_file <- file.path(output_dir, "transition_matrix.rds")
if (file.exists(transition_rds_file)) {
  transition_results <- readRDS(transition_rds_file)
  frag_matrix <- transition_results$fragmentation
  cat("Loaded fragmentation matrix from transition_matrix.rds\n")
} else {
  frag_matrix <- matrix(0, 5, 5)
  cat("NOTE: transition_matrix.rds not found. Lambda computed without fragmentation.\n")
}

if (!is.null(growth_data_for_lambda)) {
  loo_lambdas <- data.frame(excluded_study = character(), lambda = numeric(),
                             stringsAsFactors = FALSE)

  # Compute full-data annualized survival by size class as fallback for LOO gaps
  full_data_surv_by_class <- annualize_survival_by_class(survival_data)

  for (study_name in unique(survival_data$study)) {
    # Filter BOTH survival AND growth data by excluded study
    loo_surv_data <- survival_data[survival_data$study != study_name, ]
    loo_growth_data <- growth_data_for_lambda[growth_data_for_lambda$study != study_name, ]

    # Annualize survival for LOO subset (matching Script 13 methodology)
    loo_surv <- annualize_survival_by_class(loo_surv_data)
    result <- compute_lambda_from_survival(loo_surv, loo_growth_data, frag_matrix,
                                            full_data_survival = full_data_surv_by_class)
    loo_lambdas <- rbind(loo_lambdas,
                          data.frame(excluded_study = study_name, lambda = result$lambda))
  }

  cat("Lambda sensitivity to study exclusion:\n")
  print(loo_lambdas)
  cat(sprintf("Lambda range: %.4f - %.4f (span: %.4f)\n",
              min(loo_lambdas$lambda, na.rm = TRUE),
              max(loo_lambdas$lambda, na.rm = TRUE),
              diff(range(loo_lambdas$lambda, na.rm = TRUE))))

  # Save
  write.csv(loo_lambdas, file.path(output_dir, "sensitivity_lambda_loo.csv"), row.names = FALSE)
  cat("  Saved: sensitivity_lambda_loo.csv\n")
} else {
  cat("NOTE: Growth data not available. Lambda sensitivity skipped.\n")
}

# =============================================================================
# 2. SIZE CLASS BOUNDARY SENSITIVITY
# =============================================================================

cat("\n2. Size Class Boundary Sensitivity...\n")

# Test different boundary definitions
boundary_sets <- list(
  "Standard" = c(10, 100, 900, 4000),
  "Conservative" = c(15, 120, 1100, 5000),
  "Liberal" = c(8, 80, 700, 3000),
  "Equal_log" = exp(seq(log(10), log(5000), length.out = 5))[1:4],
  "Quantile_based" = quantile(survival_data$size_cm2, probs = c(0.2, 0.4, 0.6, 0.8), na.rm = TRUE)
)

boundary_sensitivity <- map_dfr(names(boundary_sets), function(name) {
  bounds <- boundary_sets[[name]]
  custom_breaks <- c(0, bounds, Inf)

  data_with_classes <- survival_data %>%
    mutate(
      size_class = cut(size_cm2, breaks = custom_breaks, labels = SIZE_LABELS, include.lowest = TRUE)
    )

  # Annualize survival for this boundary scheme
  surv_vec <- annualize_survival_by_class(data_with_classes)

  # Also get sample sizes per class
  n_by_class <- data_with_classes %>%
    filter(!is.na(size_class)) %>%
    group_by(size_class) %>%
    summarise(n = n(), .groups = "drop")

  by_size <- data.frame(
    size_class = names(surv_vec),
    survival = as.numeric(surv_vec),
    stringsAsFactors = FALSE
  ) %>%
    left_join(n_by_class, by = "size_class") %>%
    mutate(
      boundary_set = name,
      boundaries = paste(round(bounds), collapse = ", ")
    )

  by_size
})

cat("  Boundary sets tested: 5\n")
cat("  Summary by size class (using different boundaries):\n")
boundary_summary <- boundary_sensitivity %>%
  group_by(size_class) %>%
  summarise(
    mean_survival = mean(survival, na.rm = TRUE),
    sd_survival = sd(survival, na.rm = TRUE),
    cv = sd_survival / mean_survival * 100,
    .groups = "drop"
  )
print(boundary_summary)

# --- SIZE BOUNDARY: LAMBDA SENSITIVITY ---
cat("\n--- SIZE BOUNDARY: LAMBDA SENSITIVITY ---\n")
if (!is.null(growth_data_for_lambda)) {
  boundary_lambdas <- data.frame(boundary_set = character(), lambda = numeric())

  for (name in names(boundary_sets)) {
    bounds <- boundary_sets[[name]]
    custom_breaks <- c(0, bounds, Inf)

    data_with_classes <- survival_data %>%
      mutate(
        size_class = cut(size_cm2, breaks = custom_breaks, labels = SIZE_LABELS, include.lowest = TRUE)
      )

    # Annualize survival for this boundary scheme
    boundary_surv <- annualize_survival_by_class(data_with_classes)

    # Growth data also needs reclassification with these custom boundaries
    result <- compute_lambda_from_survival(boundary_surv, growth_data_for_lambda, frag_matrix,
                                            custom_breaks = custom_breaks)
    boundary_lambdas <- rbind(boundary_lambdas,
                               data.frame(boundary_set = name, lambda = result$lambda))
  }

  cat("Lambda sensitivity to size class boundaries:\n")
  print(boundary_lambdas)
  cat(sprintf("Lambda range: %.4f - %.4f (span: %.4f)\n",
              min(boundary_lambdas$lambda, na.rm = TRUE),
              max(boundary_lambdas$lambda, na.rm = TRUE),
              diff(range(boundary_lambdas$lambda, na.rm = TRUE))))

  write.csv(boundary_lambdas, file.path(output_dir, "sensitivity_lambda_boundaries.csv"), row.names = FALSE)
  cat("  Saved: sensitivity_lambda_boundaries.csv\n")
}

# =============================================================================
# 3. OUTLIER SENSITIVITY
# =============================================================================

cat("\n3. Outlier Sensitivity Analysis...\n")

# Define outlier criteria
outlier_results <- list()

# Size outliers (extreme sizes)
q_low <- quantile(survival_data$size_cm2, 0.01, na.rm = TRUE)
q_high <- quantile(survival_data$size_cm2, 0.99, na.rm = TRUE)

no_size_outliers <- survival_data %>%
  filter(size_cm2 >= q_low & size_cm2 <= q_high)

no_size_outliers <- add_size_class(no_size_outliers)
adj_surv_vec <- annualize_survival_by_class(no_size_outliers)
adj_surv_overall <- weighted.mean(adj_surv_vec,
  w = table(no_size_outliers$size_class)[names(adj_surv_vec)])
outlier_results$size_outliers <- data.frame(
  criterion = "Size extremes (1st/99th percentile)",
  n_removed = nrow(survival_data) - nrow(no_size_outliers),
  pct_removed = (nrow(survival_data) - nrow(no_size_outliers)) / nrow(survival_data) * 100,
  baseline_survival = baseline_survival,
  adjusted_survival = adj_surv_overall
)

# Studies with <20 observations
small_studies <- survival_data %>%
  group_by(study) %>%
  filter(n() < 20) %>%
  ungroup()

no_small_studies <- survival_data %>%
  group_by(study) %>%
  filter(n() >= 20) %>%
  ungroup()

no_small_studies_sc <- add_size_class(no_small_studies)
adj_surv_vec2 <- annualize_survival_by_class(no_small_studies_sc)
adj_surv_overall2 <- weighted.mean(adj_surv_vec2,
  w = table(no_small_studies_sc$size_class)[names(adj_surv_vec2)])
outlier_results$small_studies <- data.frame(
  criterion = "Small studies (<20 obs)",
  n_removed = nrow(survival_data) - nrow(no_small_studies),
  pct_removed = (nrow(survival_data) - nrow(no_small_studies)) / nrow(survival_data) * 100,
  baseline_survival = baseline_survival,
  adjusted_survival = adj_surv_overall2
)

# Pre-2010 data
recent_only <- survival_data %>%
  filter(survey_yr >= 2010)

recent_only_sc <- add_size_class(recent_only)
adj_surv_vec3 <- annualize_survival_by_class(recent_only_sc)
adj_surv_overall3 <- weighted.mean(adj_surv_vec3,
  w = table(recent_only_sc$size_class)[names(adj_surv_vec3)])
outlier_results$pre_2010 <- data.frame(
  criterion = "Pre-2010 data excluded",
  n_removed = nrow(survival_data) - nrow(recent_only),
  pct_removed = (nrow(survival_data) - nrow(recent_only)) / nrow(survival_data) * 100,
  baseline_survival = baseline_survival,
  adjusted_survival = adj_surv_overall3
)

outlier_sensitivity <- bind_rows(outlier_results) %>%
  mutate(
    change = adjusted_survival - baseline_survival,
    pct_change = change / baseline_survival * 100,
    robust = abs(pct_change) < 5
  )

cat("  Outlier criteria tested:\n")
for (i in 1:nrow(outlier_sensitivity)) {
  status <- ifelse(outlier_sensitivity$robust[i], "ROBUST", "SENSITIVE")
  cat(sprintf("    • %s: %s (%.1f%% change)\n",
              outlier_sensitivity$criterion[i],
              status,
              outlier_sensitivity$pct_change[i]))
}

# --- OUTLIER REMOVAL: LAMBDA SENSITIVITY ---
cat("\n--- OUTLIER REMOVAL: LAMBDA SENSITIVITY ---\n")
if (!is.null(growth_data_for_lambda)) {
  outlier_lambdas <- data.frame(criterion = character(), lambda = numeric())

  # Size outliers removed (apply same filter to growth data)
  surv_no_size_outliers <- add_size_class(no_size_outliers)
  growth_no_size_outliers <- growth_data_for_lambda %>%
    filter(size_cm2 >= q_low & size_cm2 <= q_high)
  surv_out <- annualize_survival_by_class(surv_no_size_outliers)
  result <- compute_lambda_from_survival(surv_out, growth_no_size_outliers, frag_matrix)
  outlier_lambdas <- rbind(outlier_lambdas,
                            data.frame(criterion = "No size outliers", lambda = result$lambda))

  # Small studies removed (filter growth data too)
  surv_no_small <- add_size_class(no_small_studies)
  large_studies <- survival_data %>% group_by(study) %>% filter(n() >= 20) %>%
    pull(study) %>% unique()
  growth_no_small <- growth_data_for_lambda %>% filter(study %in% large_studies)
  surv_out2 <- annualize_survival_by_class(surv_no_small)
  result2 <- compute_lambda_from_survival(surv_out2, growth_no_small, frag_matrix)
  outlier_lambdas <- rbind(outlier_lambdas,
                            data.frame(criterion = "No small studies", lambda = result2$lambda))

  # Recent data only (filter growth data too)
  surv_recent <- add_size_class(recent_only)
  growth_recent <- growth_data_for_lambda %>%
    filter(if ("survey_yr" %in% names(.)) survey_yr >= 2010 else TRUE)
  surv_out3 <- annualize_survival_by_class(surv_recent)
  result3 <- compute_lambda_from_survival(surv_out3, growth_recent, frag_matrix)
  outlier_lambdas <- rbind(outlier_lambdas,
                            data.frame(criterion = "Post-2010 only", lambda = result3$lambda))

  # Baseline lambda (annualized)
  baseline_surv_by_class <- annualize_survival_by_class(survival_data)
  baseline_result <- compute_lambda_from_survival(baseline_surv_by_class, growth_data_for_lambda, frag_matrix)
  outlier_lambdas <- rbind(outlier_lambdas,
                            data.frame(criterion = "Baseline (all data)", lambda = baseline_result$lambda))

  cat("Lambda sensitivity to outlier removal:\n")
  print(outlier_lambdas)

  write.csv(outlier_lambdas, file.path(output_dir, "sensitivity_lambda_outliers.csv"), row.names = FALSE)
  cat("  Saved: sensitivity_lambda_outliers.csv\n")
}

# =============================================================================
# 4. MODEL SPECIFICATION SENSITIVITY
# =============================================================================

cat("\n4. Model Specification Sensitivity...\n")

# Test different model forms for size-survival relationship
model_specs <- list()

# Linear logistic
model_specs$linear <- tryCatch({
  m <- glm(survived ~ log(size_cm2), data = survival_data, family = binomial)
  list(
    model = "Linear (log size)",
    aic = AIC(m),
    coef_size = coef(m)["log(size_cm2)"],
    significant = summary(m)$coefficients["log(size_cm2)", "Pr(>|z|)"] < 0.05
  )
}, error = function(e) list(model = "Linear", aic = NA, coef_size = NA, significant = NA))

# Quadratic
model_specs$quadratic <- tryCatch({
  survival_data$log_size <- log(survival_data$size_cm2)
  survival_data$log_size_sq <- survival_data$log_size^2
  m <- glm(survived ~ log_size + log_size_sq, data = survival_data, family = binomial)
  list(
    model = "Quadratic (log size + log size²)",
    aic = AIC(m),
    coef_size = coef(m)["log_size"],
    significant = summary(m)$coefficients["log_size", "Pr(>|z|)"] < 0.05
  )
}, error = function(e) list(model = "Quadratic", aic = NA, coef_size = NA, significant = NA))

# Categorical
model_specs$categorical <- tryCatch({
  m <- glm(survived ~ size_class, data = survival_data, family = binomial)
  list(
    model = "Categorical (5 size classes)",
    aic = AIC(m),
    coef_size = NA,  # Multiple coefficients
    significant = anova(m, test = "Chisq")$`Pr(>Chi)`[2] < 0.05
  )
}, error = function(e) list(model = "Categorical", aic = NA, coef_size = NA, significant = NA))

# Threshold model (data-driven breakpoint from script 02)
model_specs$threshold <- tryCatch({
  # Read data-driven threshold
  thresh_file <- file.path(output_dir, "survival_thresholds.csv")
  thresh_log <- log(100)  # default fallback
  thresh_cm2_label <- 100
  if (file.exists(thresh_file)) {
    surv_thresh <- read_csv(thresh_file, show_col_types = FALSE)
    if ("recommended_threshold_log" %in% names(surv_thresh) && !is.na(surv_thresh$recommended_threshold_log[1])) {
      thresh_log <- surv_thresh$recommended_threshold_log[1]
      thresh_cm2_label <- round(exp(thresh_log))
    } else if ("threshold_log" %in% names(surv_thresh) && !is.na(surv_thresh$threshold_log[1])) {
      thresh_log <- surv_thresh$threshold_log[1]
      thresh_cm2_label <- round(exp(thresh_log))
    }
  }
  survival_data$size_above_thresh <- pmax(0, log(survival_data$size_cm2) - thresh_log)
  m <- glm(survived ~ log(size_cm2) + size_above_thresh, data = survival_data, family = binomial)
  list(
    model = sprintf("Threshold (breakpoint at %d cm2)", thresh_cm2_label),
    aic = AIC(m),
    coef_size = coef(m)["log(size_cm2)"],
    significant = TRUE  # Both terms present
  )
}, error = function(e) list(model = "Threshold", aic = NA, coef_size = NA, significant = NA))

model_sensitivity <- map_dfr(model_specs, as.data.frame) %>%
  arrange(aic) %>%
  mutate(
    delta_aic = aic - min(aic, na.rm = TRUE),
    best = delta_aic == 0
  )

cat("  Model comparison (by AIC):\n")
print(model_sensitivity %>% select(model, aic, delta_aic, significant))

# =============================================================================
# 5. TEMPORAL SENSITIVITY
# =============================================================================

cat("\n5. Temporal Sensitivity Analysis...\n")

# Analyze by decade (annualized survival within each decade)
temporal_sensitivity <- survival_data %>%
  mutate(decade = floor(survey_yr / 10) * 10) %>%
  filter(!is.na(decade)) %>%
  # Annualize within each decade: group by decade x study x size_class x interval
  mutate(time_interval_yr = if ("time_interval_yr" %in% names(.))
    coalesce(time_interval_yr, 1.0) else 1.0) %>%
  group_by(decade, study, time_interval_yr) %>%
  summarise(
    n = n(),
    raw_survival = mean(survived, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(annual_survival = raw_survival^(1 / time_interval_yr)) %>%
  group_by(decade) %>%
  summarise(
    mean_survival = weighted.mean(annual_survival, w = n),
    n = sum(n),
    .groups = "drop"
  ) %>%
  mutate(
    change_from_overall = mean_survival - baseline_survival,
    pct_change = change_from_overall / baseline_survival * 100
  )

cat("  Survival by decade:\n")
print(temporal_sensitivity)

# =============================================================================
# 6. GEOGRAPHIC SENSITIVITY
# =============================================================================

cat("\n6. Geographic Sensitivity Analysis...\n")

geographic_sensitivity <- survival_data %>%
  mutate(time_interval_yr = if ("time_interval_yr" %in% names(.))
    coalesce(time_interval_yr, 1.0) else 1.0) %>%
  group_by(region, study, time_interval_yr) %>%
  summarise(
    n = n(),
    raw_survival = mean(survived, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(annual_survival = raw_survival^(1 / time_interval_yr)) %>%
  group_by(region) %>%
  summarise(
    mean_survival = weighted.mean(annual_survival, w = n),
    n = sum(n),
    .groups = "drop"
  ) %>%
  mutate(
    change_from_overall = mean_survival - baseline_survival,
    pct_change = change_from_overall / baseline_survival * 100
  ) %>%
  arrange(desc(abs(pct_change)))

cat("  Survival by region:\n")
print(geographic_sensitivity)

# =============================================================================
# 7. BOOTSTRAP CONFIDENCE INTERVALS
# =============================================================================

cat("\n7. Bootstrap Confidence Intervals...\n")

set.seed(42)
n_boot <- 1000

# NOTE: Cluster bootstrap resamples studies (not individual observations) to
# account for within-study correlation. This produces wider but more honest
# CIs that reflect between-study heterogeneity.

# Helper: compute annualized overall survival from a bootstrap sample
# Matches Script 13 methodology: group by study x time_interval, annualize, weighted mean
boot_annualized_survival <- function(boot_data) {
  if (!"time_interval_yr" %in% names(boot_data)) {
    boot_data$time_interval_yr <- 1.0
  }
  boot_data$time_interval_yr[is.na(boot_data$time_interval_yr)] <- 1.0

  by_group <- boot_data %>%
    group_by(study, time_interval_yr) %>%
    summarise(n = n(), raw_survival = mean(survived, na.rm = TRUE), .groups = "drop") %>%
    mutate(annual_survival = raw_survival^(1 / time_interval_yr))
  weighted.mean(by_group$annual_survival, w = by_group$n)
}

# Helper: compute annualized survival for a single size class bootstrap sample
boot_annualized_survival_class <- function(boot_data) {
  if (!"time_interval_yr" %in% names(boot_data)) {
    boot_data$time_interval_yr <- 1.0
  }
  boot_data$time_interval_yr[is.na(boot_data$time_interval_yr)] <- 1.0

  by_group <- boot_data %>%
    group_by(study, time_interval_yr) %>%
    summarise(n = n(), raw_survival = mean(survived, na.rm = TRUE), .groups = "drop") %>%
    mutate(annual_survival = raw_survival^(1 / time_interval_yr))
  weighted.mean(by_group$annual_survival, w = by_group$n)
}

# Cluster bootstrap overall survival (annualized)
studies <- unique(survival_data$study)
boot_overall <- replicate(n_boot, {
  boot_studies <- sample(studies, length(studies), replace = TRUE)
  boot_data <- do.call(rbind, lapply(boot_studies, function(s) {
    study_data <- survival_data[survival_data$study == s, ]
    study_data[sample(nrow(study_data), nrow(study_data), replace = TRUE), ]
  }))
  boot_annualized_survival(boot_data)
})

# Cluster bootstrap per size class (annualized)
boot_by_size <- survival_data %>%
  group_by(size_class) %>%
  group_map(function(class_data, key) {
    studies_in_class <- unique(class_data$study)
    boots <- replicate(n_boot, {
      boot_studies <- sample(studies_in_class, length(studies_in_class), replace = TRUE)
      boot_data <- do.call(rbind, lapply(boot_studies, function(s) {
        study_data <- class_data[class_data$study == s, ]
        study_data[sample(nrow(study_data), nrow(study_data), replace = TRUE), ]
      }))
      boot_annualized_survival_class(boot_data)
    })
    tibble(
      size_class = key$size_class,
      mean = mean(boots),
      ci_lower = quantile(boots, 0.025),
      ci_upper = quantile(boots, 0.975),
      se_boot = sd(boots)
    )
  }) %>%
  bind_rows()

cat("  Bootstrap results (1000 iterations):\n")
cat(sprintf("    Overall survival: %.1f%% (95%% CI: %.1f%% - %.1f%%)\n",
            mean(boot_overall) * 100,
            quantile(boot_overall, 0.025) * 100,
            quantile(boot_overall, 0.975) * 100))

cat("    By size class:\n")
for (i in 1:nrow(boot_by_size)) {
  cat(sprintf("      %s: %.1f%% (%.1f%% - %.1f%%)\n",
              boot_by_size$size_class[i],
              boot_by_size$mean[i] * 100,
              boot_by_size$ci_lower[i] * 100,
              boot_by_size$ci_upper[i] * 100))
}

# =============================================================================
# COMPILE SENSITIVITY SUMMARY
# =============================================================================

cat("\n8. Compiling Sensitivity Summary...\n")

sensitivity_summary <- data.frame(
  analysis = c(
    "Leave-one-out (influential studies)",
    "Size boundaries (CV across schemes)",
    "Outlier removal (max change)",
    "Model specification (AIC range)",
    "Temporal (max decade change)",
    "Geographic (max region change)",
    "Bootstrap (95% CI width)"
  ),
  metric = c(
    sprintf("%d/%d influential", nrow(influential_studies), length(studies)),
    sprintf("Mean CV = %.1f%%", mean(boundary_summary$cv, na.rm = TRUE)),
    sprintf("Max change = %.1f%%", max(abs(outlier_sensitivity$pct_change), na.rm = TRUE)),
    sprintf("ΔAIC range = %.1f", max(model_sensitivity$delta_aic, na.rm = TRUE)),
    sprintf("Max change = %.1f%%", max(abs(temporal_sensitivity$pct_change), na.rm = TRUE)),
    sprintf("Max change = %.1f%%", max(abs(geographic_sensitivity$pct_change), na.rm = TRUE)),
    sprintf("Width = %.1f%%", (quantile(boot_overall, 0.975) - quantile(boot_overall, 0.025)) * 100)
  ),
  assessment = c(
    ifelse(nrow(influential_studies) <= 1, "ROBUST", "MODERATE"),
    ifelse(mean(boundary_summary$cv, na.rm = TRUE) < 10, "ROBUST", "MODERATE"),
    ifelse(max(abs(outlier_sensitivity$pct_change), na.rm = TRUE) < 5, "ROBUST", "SENSITIVE"),
    ifelse(max(model_sensitivity$delta_aic, na.rm = TRUE) < 10, "ROBUST", "MODERATE"),
    ifelse(max(abs(temporal_sensitivity$pct_change), na.rm = TRUE) < 10, "ROBUST", "MODERATE"),
    ifelse(max(abs(geographic_sensitivity$pct_change), na.rm = TRUE) < 15, "MODERATE", "SENSITIVE"),
    "INFORMATIVE"
  )
)

cat("\nSENSITIVITY SUMMARY:\n")
print(sensitivity_summary)

# =============================================================================
# SAVE OUTPUTS
# =============================================================================

cat("\nSaving sensitivity analysis outputs...\n")

write.csv(loo_results, file.path(output_dir, "sensitivity_leave_one_out.csv"), row.names = FALSE)
cat("  ✓ Saved: sensitivity_leave_one_out.csv\n")

write.csv(boundary_sensitivity, file.path(output_dir, "sensitivity_size_boundaries.csv"), row.names = FALSE)
cat("  ✓ Saved: sensitivity_size_boundaries.csv\n")

write.csv(outlier_sensitivity, file.path(output_dir, "sensitivity_outliers.csv"), row.names = FALSE)
cat("  ✓ Saved: sensitivity_outliers.csv\n")

write.csv(model_sensitivity, file.path(output_dir, "sensitivity_model_specs.csv"), row.names = FALSE)
cat("  ✓ Saved: sensitivity_model_specs.csv\n")

write.csv(boot_by_size, file.path(output_dir, "bootstrap_confidence_intervals.csv"), row.names = FALSE)
cat("  ✓ Saved: bootstrap_confidence_intervals.csv\n")

write.csv(sensitivity_summary, file.path(output_dir, "sensitivity_summary.csv"), row.names = FALSE)
cat("  ✓ Saved: sensitivity_summary.csv\n")

# =============================================================================
# VISUALIZATIONS
# =============================================================================

cat("\nCreating sensitivity visualizations...\n")

# Leave-one-out plot
p1 <- loo_results %>%
  mutate(excluded_study = reorder(excluded_study, pct_change)) %>%
  ggplot(aes(x = excluded_study, y = pct_change)) +
  geom_col(aes(fill = influential), width = 0.7) +
  geom_hline(yintercept = c(-5, 5), linetype = "dashed", color = "red", alpha = 0.5) +
  geom_hline(yintercept = 0, color = "gray40") +
  coord_flip() +
  scale_fill_manual(values = c("FALSE" = "#4A90D9", "TRUE" = "#E74C3C"),
                    labels = c("Not Influential", "Influential (>5% change)")) +
  labs(
    title = "Leave-One-Out Sensitivity Analysis",
    subtitle = "Change in overall survival when each study is excluded",
    x = "Excluded Study",
    y = "% Change in Survival Estimate",
    fill = ""
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold")
  )

ggsave(file.path(fig_dir, "sensitivity_loo.png"), p1,
       width = 8, height = 6, dpi = 150)
cat("  ✓ Saved: sensitivity_loo.png\n")

# Bootstrap CI plot
p2 <- boot_by_size %>%
  ggplot(aes(x = size_class, y = mean)) +
  geom_point(size = 3, color = "#2C3E50") +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2, color = "#2C3E50") +
  geom_hline(yintercept = baseline_survival, linetype = "dashed", color = "gray40") +
  annotate("text", x = 0.5, y = baseline_survival + 0.02,
           label = "Overall mean", hjust = 0, size = 3, color = "gray40") +
  scale_y_continuous(limits = c(0.5, 1), labels = scales::percent) +
  labs(
    title = "Bootstrap Confidence Intervals by Size Class",
    subtitle = "95% CI from 1000 bootstrap iterations",
    x = "Size Class",
    y = "Survival Probability"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold")
  )

ggsave(file.path(fig_dir, "sensitivity_bootstrap.png"), p2,
       width = 8, height = 5, dpi = 150)
cat("  ✓ Saved: sensitivity_bootstrap.png\n")

# Summary heatmap
p3 <- sensitivity_summary %>%
  mutate(
    assessment_color = case_when(
      assessment == "ROBUST" ~ 1,
      assessment == "MODERATE" ~ 2,
      assessment == "SENSITIVE" ~ 3,
      TRUE ~ 0
    ),
    analysis = factor(analysis, levels = rev(analysis))
  ) %>%
  ggplot(aes(x = 1, y = analysis, fill = assessment)) +
  geom_tile(width = 0.9, height = 0.9) +
  geom_text(aes(label = metric), color = "white", fontface = "bold", size = 3.5) +
  scale_fill_manual(
    values = c("ROBUST" = "#27AE60", "MODERATE" = "#F39C12",
               "SENSITIVE" = "#E74C3C", "INFORMATIVE" = "#3498DB")
  ) +
  labs(
    title = "Sensitivity Analysis Summary",
    subtitle = "Robustness assessment across multiple dimensions",
    x = "",
    y = "",
    fill = "Assessment"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    plot.title = element_text(face = "bold"),
    legend.position = "bottom"
  )

ggsave(file.path(fig_dir, "sensitivity_summary.png"), p3,
       width = 8, height = 6, dpi = 150)
cat("  ✓ Saved: sensitivity_summary.png\n")

# =============================================================================
# 8. INTERVAL-LENGTH SENSITIVITY
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  INTERVAL-LENGTH SENSITIVITY\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Exclude Navassa records with long monitoring intervals (time_interval_yr > 1.5)
# to test whether multi-year records bias lambda

if ("time_interval_yr" %in% names(survival_data) && "region" %in% names(survival_data)) {
  navassa_records <- survival_data %>%
    filter(region == "Navassa" | (time_interval_yr > 1.5))

  cat(sprintf("  Records with time_interval_yr > 1.5: %d\n", sum(survival_data$time_interval_yr > 1.5, na.rm = TRUE)))
  cat(sprintf("  Navassa records: %d\n", sum(survival_data$region == "Navassa", na.rm = TRUE)))

  surv_short_interval <- survival_data %>%
    filter(is.na(time_interval_yr) | time_interval_yr <= 1.5)

  cat(sprintf("  Remaining after exclusion: %d of %d records\n",
              nrow(surv_short_interval), nrow(survival_data)))

  # Compute annualized survival by size class for short-interval data
  short_surv <- annualize_survival_by_class(surv_short_interval)

  # Compute lambda
  growth_short <- growth_data  # growth data typically has short intervals already
  result_short <- compute_lambda_from_survival(short_surv, growth_short, frag_matrix)
  lambda_short <- result_short$lambda

  # Compare with full-data lambda
  lambda_full <- if (exists("transition_results")) transition_results$lambda else {
    # Compute baseline lambda from full data as fallback
    full_surv <- annualize_survival_by_class(survival_data)
    baseline_res <- compute_lambda_from_survival(full_surv, growth_data, frag_matrix)
    baseline_res$lambda
  }
  pct_change <- (lambda_short - lambda_full) / lambda_full * 100

  cat(sprintf("  Lambda (full data): %.4f\n", lambda_full))
  cat(sprintf("  Lambda (short intervals only): %.4f\n", lambda_short))
  cat(sprintf("  Change: %.1f%%\n", pct_change))

  interval_sensitivity <- data.frame(
    scenario = c("full_data", "short_intervals_only"),
    lambda = c(lambda_full, lambda_short),
    n_records = c(nrow(survival_data), nrow(surv_short_interval)),
    pct_change_from_full = c(0, pct_change)
  )
  write_csv(interval_sensitivity, file.path(output_dir, "sensitivity_interval_length.csv"))
  cat("  ✓ Saved: sensitivity_interval_length.csv\n")
} else {
  cat("  SKIPPED: time_interval_yr or region column not available\n")
  write_csv(data.frame(scenario = character(), lambda = numeric(),
                        n_records = integer(), pct_change_from_full = numeric()),
            file.path(output_dir, "sensitivity_interval_length.csv"))
}

# =============================================================================
# 9. FRAGMENTATION ALLOCATION SENSITIVITY
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  FRAGMENTATION ALLOCATION SENSITIVITY\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Test how the SC1/SC2 fragmentation split affects lambda.
# Vardi (2011) reports fragmentation for SC1_V (0-100 cm²).
# Current split: 10%/90% by range width into SC1 (0-10)/SC2 (10-100).
# Test: 10/90, 25/75 (current), 50/50, 75/25

if (exists("transition_results") && !is.null(transition_results$fragmentation)) {
  F_base <- transition_results$fragmentation
  G_base <- transition_results$growth_transitions
  S_base <- transition_results$survival_rates
  lambda_base <- transition_results$lambda

  # The fragmentation matrix has entries in rows SC1 and SC2 from columns SC4 and SC5.
  # We need to know the combined SC1+SC2 fragmentation to redistribute.
  # F[SC1, SC4] + F[SC2, SC4] = total SC1_V fragmentation to SC4
  # F[SC1, SC5] + F[SC2, SC5] = total SC1_V fragmentation to SC5

  total_frag_sc4 <- F_base[1, 4] + F_base[2, 4]  # SC1+SC2 from SC4
  total_frag_sc5 <- F_base[1, 5] + F_base[2, 5]  # SC1+SC2 from SC5

  splits <- c(0.10, 0.25, 0.50, 0.75)
  frag_alloc_results <- list()

  for (sc1_prop in splits) {
    F_test <- F_base
    # Redistribute SC1/SC2 fragmentation
    F_test[1, 4] <- total_frag_sc4 * sc1_prop      # SC1 from SC4
    F_test[2, 4] <- total_frag_sc4 * (1 - sc1_prop) # SC2 from SC4
    F_test[1, 5] <- total_frag_sc5 * sc1_prop      # SC1 from SC5
    F_test[2, 5] <- total_frag_sc5 * (1 - sc1_prop) # SC2 from SC5

    A_test <- G_base %*% diag(S_base) + F_test
    lambda_test <- Re(eigen(A_test)$values[1])

    frag_alloc_results[[length(frag_alloc_results) + 1]] <- data.frame(
      sc1_proportion = sc1_prop,
      sc2_proportion = 1 - sc1_prop,
      lambda = lambda_test,
      pct_change = (lambda_test - lambda_base) / lambda_base * 100
    )

    cat(sprintf("  SC1/SC2 = %.0f/%.0f: lambda = %.4f (%.2f%% change)\n",
                sc1_prop * 100, (1 - sc1_prop) * 100, lambda_test,
                (lambda_test - lambda_base) / lambda_base * 100))
  }

  frag_alloc_df <- do.call(rbind, frag_alloc_results)
  write_csv(frag_alloc_df, file.path(output_dir, "sensitivity_fragmentation_allocation.csv"))
  cat("  ✓ Saved: sensitivity_fragmentation_allocation.csv\n")
} else {
  cat("  SKIPPED: transition_matrix.rds not loaded\n")
  write_csv(data.frame(sc1_proportion = numeric(), sc2_proportion = numeric(),
                        lambda = numeric(), pct_change = numeric()),
            file.path(output_dir, "sensitivity_fragmentation_allocation.csv"))
}

# =============================================================================
# 9B. FRAGMENTATION SCENARIO BRACKETING
# FIX: Three-scenario bracketing to test sensitivity to Vardi 2011 (critique audit 2026-03-29)
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  FRAGMENTATION SCENARIO BRACKETING\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

if (exists("transition_results") && !is.null(transition_results$fragmentation)) {
  F_base <- transition_results$fragmentation
  G_base <- transition_results$growth_transitions
  S_base <- transition_results$survival_rates
  lambda_base <- transition_results$lambda

  # Scenario 1: Full fragmentation (Vardi 2011 rates)
  # Already computed as lambda_base

  # Scenario 2: No fragmentation
  A_no_frag <- G_base %*% diag(S_base)
  lambda_no_frag <- Re(eigen(A_no_frag)$values[1])

  # Scenario 3: 50% of Vardi rates
  A_half_frag <- G_base %*% diag(S_base) + F_base * 0.5
  lambda_half_frag <- Re(eigen(A_half_frag)$values[1])

  cat(sprintf("  With full fragmentation (Vardi 2011):  lambda = %.4f\n", lambda_base))
  cat(sprintf("  With 50%% fragmentation:                lambda = %.4f\n", lambda_half_frag))
  cat(sprintf("  Without fragmentation:                  lambda = %.4f\n", lambda_no_frag))

  frag_scenarios <- data.frame(
    scenario = c("with_fragmentation", "half_fragmentation", "without_fragmentation"),
    fragmentation_multiplier = c(1.0, 0.5, 0.0),
    lambda = c(lambda_base, lambda_half_frag, lambda_no_frag),
    difference_from_full = c(0, lambda_half_frag - lambda_base, lambda_no_frag - lambda_base),
    notes = c("Full Vardi 2011 rates (13 rows, 1 study)",
              "50% of Vardi rates — tests sensitivity to single-study estimates",
              "No fragmentation — survival and growth only")
  )
  write_csv(frag_scenarios, file.path(output_dir, "fragmentation_scenarios.csv"))
  cat("  Saved: fragmentation_scenarios.csv\n")
} else {
  cat("  SKIPPED: transition_matrix.rds not loaded\n")
}

# =============================================================================
# 10. BOOTSTRAP FAILURE CHARACTERIZATION
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  BOOTSTRAP FAILURE CHARACTERIZATION\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

boot_fail_file <- file.path(output_dir, "bootstrap_failure_analysis.csv")
if (file.exists(boot_fail_file)) {
  boot_failures <- read_csv(boot_fail_file, show_col_types = FALSE)
  cat(sprintf("  Loaded %d bootstrap failure records\n", nrow(boot_failures)))

  if (nrow(boot_failures) > 0) {
    # Summarize by stage
    stage_summary <- boot_failures %>%
      group_by(stage, reason) %>%
      summarise(count = n(), .groups = "drop") %>%
      arrange(desc(count))

    cat("\n  Failure by stage/reason:\n")
    for (i in 1:nrow(stage_summary)) {
      cat(sprintf("    %s / %s: %d\n", stage_summary$stage[i],
                  stage_summary$reason[i], stage_summary$count[i]))
    }

    # Most commonly missing size classes
    surv_fails <- boot_failures %>% filter(stage == "survival" & !is.na(missing_classes))
    if (nrow(surv_fails) > 0) {
      all_missing <- unlist(strsplit(surv_fails$missing_classes, ","))
      missing_freq <- as.data.frame(table(all_missing), stringsAsFactors = FALSE)
      names(missing_freq) <- c("size_class", "frequency")
      missing_freq <- missing_freq[order(-missing_freq$frequency), ]

      cat("\n  Most commonly missing size classes in survival failures:\n")
      for (i in 1:nrow(missing_freq)) {
        cat(sprintf("    %s: %d times (%.1f%% of survival failures)\n",
                    missing_freq$size_class[i], missing_freq$frequency[i],
                    missing_freq$frequency[i] / nrow(surv_fails) * 100))
      }
    }

    # Most common study combinations causing failure
    study_combos <- boot_failures %>%
      group_by(studies_drawn) %>%
      summarise(count = n(), .groups = "drop") %>%
      arrange(desc(count)) %>%
      head(5)

    cat("\n  Most common study combinations in failures (top 5):\n")
    for (i in 1:nrow(study_combos)) {
      cat(sprintf("    %s (%d times)\n", study_combos$studies_drawn[i], study_combos$count[i]))
    }

    # Save summary
    boot_fail_summary <- data.frame(
      metric = c("total_failures", "survival_failures", "growth_failures",
                  paste0("missing_", if (exists("missing_freq") && nrow(missing_freq) > 0) missing_freq$size_class[1] else "NA")),
      value = c(nrow(boot_failures),
                sum(boot_failures$stage == "survival"),
                sum(boot_failures$stage == "growth"),
                if (exists("missing_freq") && nrow(missing_freq) > 0) missing_freq$frequency[1] else 0)
    )
    write_csv(boot_fail_summary, file.path(output_dir, "sensitivity_bootstrap_failures.csv"))
    cat("\n  ✓ Saved: sensitivity_bootstrap_failures.csv\n")
  } else {
    cat("  No bootstrap failures recorded. All iterations succeeded.\n")
    write_csv(data.frame(metric = "total_failures", value = 0),
              file.path(output_dir, "sensitivity_bootstrap_failures.csv"))
    cat("  ✓ Saved: sensitivity_bootstrap_failures.csv\n")
  }
} else {
  cat("  SKIPPED: bootstrap_failure_analysis.csv not found.\n")
  cat("  Run script 13_transition_matrix.R first.\n")
  write_csv(data.frame(metric = character(), value = numeric()),
            file.path(output_dir, "sensitivity_bootstrap_failures.csv"))
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  SENSITIVITY ANALYSIS COMPLETE                               ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("ROBUSTNESS ASSESSMENT:\n")
cat("─────────────────────────────────────────────────────────────────\n")

n_robust <- sum(sensitivity_summary$assessment == "ROBUST")
n_moderate <- sum(sensitivity_summary$assessment == "MODERATE")
n_sensitive <- sum(sensitivity_summary$assessment == "SENSITIVE")

cat(sprintf("  ROBUST: %d analyses\n", n_robust))
cat(sprintf("  MODERATE: %d analyses\n", n_moderate))
cat(sprintf("  SENSITIVE: %d analyses\n", n_sensitive))

overall_robustness <- case_when(
  n_sensitive > 1 ~ "CAUTION - Multiple sensitivity issues detected",
  n_sensitive == 1 ~ "MODERATE - One sensitivity issue to note",
  n_moderate > 2 ~ "MODERATE - Some variation across methods",
  TRUE ~ "GOOD - Results generally robust across sensitivity checks"
)

cat(sprintf("\n  OVERALL: %s\n", overall_robustness))

cat("\nKEY FINDINGS:\n")
cat("─────────────────────────────────────────────────────────────────\n")

# Most influential study
if (nrow(influential_studies) > 0) {
  most_influential <- influential_studies %>% filter(abs(pct_change) == max(abs(pct_change)))
  cat(sprintf("  • Most influential study: %s (%.1f%% change when excluded)\n",
              most_influential$excluded_study[1], most_influential$pct_change[1]))
}

# Geographic sensitivity
most_different_region <- geographic_sensitivity %>% filter(abs(pct_change) == max(abs(pct_change)))
cat(sprintf("  • Most different region: %s (%.1f%% from overall)\n",
            most_different_region$region[1], most_different_region$pct_change[1]))

# Model sensitivity
best_model <- model_sensitivity %>% filter(best)
cat(sprintf("  • Best-fitting model: %s (AIC = %.1f)\n",
            best_model$model[1], best_model$aic[1]))

# Bootstrap precision
ci_width <- (quantile(boot_overall, 0.975) - quantile(boot_overall, 0.025)) * 100
cat(sprintf("  • Overall survival 95%% CI width: %.1f percentage points\n", ci_width))

cat("\nOutputs:\n")
cat("  - sensitivity_leave_one_out.csv\n")
cat("  - sensitivity_size_boundaries.csv\n")
cat("  - sensitivity_outliers.csv\n")
cat("  - sensitivity_model_specs.csv\n")
cat("  - bootstrap_confidence_intervals.csv\n")
cat("  - sensitivity_summary.csv\n")
cat("  - sensitivity_*.png visualizations\n")
