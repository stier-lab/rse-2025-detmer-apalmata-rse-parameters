#!/usr/bin/env Rscript
################################################################################
# 04_GROWTH_RATE_COMPARISON.R
# Comprehensive Analysis of Growth Rates and Relative Growth Rates
################################################################################
#
# PURPOSE: Dedicated analysis of absolute vs. relative growth rate patterns
#          in A. palmata, with explicit discussion of allometric assumptions
#
# KEY ANALYSES:
#   1. Absolute Growth Rate (AGR) - cm²/yr
#   2. Relative Growth Rate (RGR) - yr⁻¹ (growth/initial_size)
#   3. Size-dependent patterns and thresholds
#   4. Variance explanation comparison (AGR vs RGR)
#   5. Natural vs. restored population comparison
#   6. Allometric assumptions and limitations
#
# ALLOMETRIC CONTEXT:
#   Size measurements use 2D planar area (L × W × % live), following
#   Vardi et al. 2012. This is a projection of the 3D coral structure.
#
#   For A. palmata (branching/elkhorn coral):
#   - Small colonies (<100 cm²): Plate-like, 2D proxy reasonable
#   - Large colonies (>1000 cm²): Complex branching, 2D underestimates
#
#   RGR partially corrects for this because both numerator and denominator
#   use the same measurement approach. However, the scaling factor between
#   2D planar area and true 3D tissue area varies with colony size.
#
# INPUTS:
#   - analysis/output/prepared_growth_data.rds
#
# OUTPUTS:
#   - analysis/output/growth_rate_analysis.rds
#   - analysis/output/growth_rate_summary.csv
#   - analysis/output/rgr_vs_agr_comparison.csv
#   - analysis/figures/supplementary/exploratory/growth_rate_analysis.png
#
# Author: Detmer & Stier Lab
# Date: 2024-12-29
################################################################################

# NOTE: This script uses percentile-based RGR trimming (0.5th-99.5th percentile)
# rather than the absolute growth threshold used in 03_growth_thresholds.R
# (which filters on pct_change > -50% and < 200%). The percentile approach is
# more robust to distributional differences across size classes. Both approaches
# are valid; results should be compared for sensitivity.

# =============================================================================
# 0. SETUP
# =============================================================================

library(dplyr)
library(tidyr)
library(purrr)
library(ggplot2)
library(mgcv)
library(scales)

# Try optional packages
has_lme4 <- requireNamespace("lme4", quietly = TRUE)
has_patchwork <- requireNamespace("patchwork", quietly = TRUE)

if (has_lme4) library(lme4)
if (has_patchwork) library(patchwork)

# Source shared utilities for canonical constants (SIZE_BREAKS, SIZE_LABELS, etc.)
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("analysis/scripts/utils/shared_utilities.R")) {
  source("analysis/scripts/utils/shared_utilities.R")
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  03b: GROWTH RATE ANALYSIS                                    ║\n")
cat("║  Absolute vs. Relative Growth Rate Patterns                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# Set paths
if (file.exists("standardized_data")) {
  project_root <- "."
} else if (file.exists("../../standardized_data")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root. Run from project directory or analysis/scripts/")
}

output_dir <- file.path(project_root, "analysis/output")
fig_dir <- file.path(project_root, "analysis/figures")
fig_dir_supp <- file.path(fig_dir, "supplementary/exploratory")
pub_fig_dir <- file.path(fig_dir, "publication")
dir.create(fig_dir_supp, showWarnings = FALSE, recursive = TRUE)
dir.create(pub_fig_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1. LOAD AND PREPARE DATA
# =============================================================================

cat("Loading growth data...\n")
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

cat(sprintf("  Total records: %d\n", nrow(growth_data)))
cat(sprintf("  Studies: %s\n", paste(unique(growth_data$study), collapse = ", ")))

# Apply quality filters
# 1. Remove impossible values (tissue loss > initial size)
if ("impossible_growth" %in% names(growth_data)) {
  n_impossible <- sum(growth_data$impossible_growth, na.rm = TRUE)
  cat(sprintf("  Removing %d impossible growth records\n", n_impossible))
  growth_clean <- growth_data %>% filter(!impossible_growth)
} else {
  growth_clean <- growth_data %>%
    filter(!((growth_cm2_yr < 0) & (abs(growth_cm2_yr) > size_cm2 * 1.1)))
}

# 2. Ensure required columns exist
# NOTE on RGR: Script 01 pre-computes rgr as coalesce(growth_live_cm2_yr, growth_cm2_yr) / size_for_class,
# which prefers live-tissue growth for NOAA data. We use that pre-computed column when available
# to stay consistent with the prepared data. Only recompute as fallback.
growth_clean <- growth_clean %>%
  filter(!is.na(size_cm2), size_cm2 > 0, !is.na(growth_cm2_yr)) %>%
  mutate(
    log_size = log(size_cm2),
    # Use consistent growth metric (prefer live-tissue when available)
    # This ensures AGR and RGR use the same underlying growth measurement
    growth_metric = coalesce(growth_live_cm2_yr, growth_cm2_yr),
    # Absolute Growth Rate (AGR) — same metric basis as RGR
    agr = growth_metric,
    # Relative Growth Rate (RGR): use pre-computed from script 01 if available
    # Script 01 defines: rgr = coalesce(growth_live_cm2_yr, growth_cm2_yr) / size_for_class
    # Fallback: growth_metric / size_cm2 (equivalent when growth_live_cm2_yr is absent)
    rgr = if ("rgr" %in% names(.)) rgr else growth_metric / size_cm2,
    # Percent change
    pct_change = rgr * 100,
    # Binary: positive growth (using consistent growth metric)
    positive_growth = as.integer(growth_metric > 0),
    # Population type: use canonical labels matching prepared data from script 01
    # Only assign if not already present (prepared data uses "Restoration fragment"/"Natural colony")
    population_type = if ("population_type" %in% names(.)) population_type else case_when(
      fragment == "Y" ~ "Restoration fragment",
      fragment == "N" ~ "Natural colony",
      TRUE ~ "Unknown"
    )
  ) %>%
  filter(!is.na(rgr))

# Remove extreme RGR outliers (top/bottom 0.5%)
rgr_bounds <- quantile(growth_clean$rgr, c(0.005, 0.995), na.rm = TRUE)
growth_clean <- growth_clean %>%
  filter(rgr >= rgr_bounds[1] & rgr <= rgr_bounds[2])

# 3. Exclude high-variance regions (e.g., Navassa) from main analyses
# These have unusually long observation intervals and extreme growth rates
# that can dominate model fits. They are analyzed separately in sensitivity.
if ("high_variance_region" %in% names(growth_clean)) {
  n_high_var <- sum(growth_clean$high_variance_region, na.rm = TRUE)
  if (n_high_var > 0) {
    cat(sprintf("  Excluding %d high-variance region records (Navassa) from main analysis\n", n_high_var))
    growth_high_var <- growth_clean %>% filter(high_variance_region)
    growth_clean <- growth_clean %>% filter(!high_variance_region)
  }
} else {
  # Fallback: filter by region name if flag not present
  n_navassa <- sum(growth_clean$region == "Navassa", na.rm = TRUE)
  if (n_navassa > 0) {
    cat(sprintf("  Excluding %d Navassa records (outlier growth rates) from main analysis\n", n_navassa))
    growth_high_var <- growth_clean %>% filter(region == "Navassa")
    growth_clean <- growth_clean %>% filter(region != "Navassa")
  }
}

cat(sprintf("  After filtering: %d records\n", nrow(growth_clean)))
cat(sprintf("  Size range: %.1f - %.1f cm²\n",
            min(growth_clean$size_cm2), max(growth_clean$size_cm2)))

# =============================================================================
# 2. DESCRIPTIVE STATISTICS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  GROWTH RATE DESCRIPTIVE STATISTICS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Overall statistics
overall_stats <- growth_clean %>%
  summarise(
    n = n(),
    # AGR stats
    agr_mean = mean(agr, na.rm = TRUE),
    agr_median = median(agr, na.rm = TRUE),
    agr_sd = sd(agr, na.rm = TRUE),
    agr_min = min(agr, na.rm = TRUE),
    agr_max = max(agr, na.rm = TRUE),
    # RGR stats
    rgr_mean = mean(rgr, na.rm = TRUE),
    rgr_median = median(rgr, na.rm = TRUE),
    rgr_sd = sd(rgr, na.rm = TRUE),
    # Proportions
    pct_positive = mean(positive_growth, na.rm = TRUE) * 100,
    pct_shrinking = mean(agr < 0, na.rm = TRUE) * 100
  )

cat("OVERALL GROWTH STATISTICS:\n")
cat(sprintf("  n = %d observations\n", overall_stats$n))
cat(sprintf("\n  Absolute Growth Rate (AGR):\n"))
cat(sprintf("    Mean:   %.1f cm²/yr\n", overall_stats$agr_mean))
cat(sprintf("    Median: %.1f cm²/yr\n", overall_stats$agr_median))
cat(sprintf("    SD:     %.1f cm²/yr\n", overall_stats$agr_sd))
cat(sprintf("    Range:  %.1f to %.1f cm²/yr\n", overall_stats$agr_min, overall_stats$agr_max))
cat(sprintf("\n  Relative Growth Rate (RGR):\n"))
cat(sprintf("    Mean:   %.3f yr⁻¹\n", overall_stats$rgr_mean))
cat(sprintf("    Median: %.3f yr⁻¹\n", overall_stats$rgr_median))
cat(sprintf("    SD:     %.3f yr⁻¹\n", overall_stats$rgr_sd))
cat(sprintf("\n  Proportions:\n"))
cat(sprintf("    Positive growth: %.1f%%\n", overall_stats$pct_positive))
cat(sprintf("    Shrinkage:       %.1f%%\n", overall_stats$pct_shrinking))

# Save overall descriptive statistics
growth_descriptive_df <- data.frame(
  metric = c("AGR", "RGR"),
  n = overall_stats$n,
  mean = c(overall_stats$agr_mean, overall_stats$rgr_mean),
  median = c(overall_stats$agr_median, overall_stats$rgr_median),
  sd = c(overall_stats$agr_sd, overall_stats$rgr_sd),
  min = c(overall_stats$agr_min, NA),
  max = c(overall_stats$agr_max, NA),
  pct_positive = overall_stats$pct_positive,
  pct_shrinking = overall_stats$pct_shrinking
)
write_csv(growth_descriptive_df, file.path(output_dir, "growth_descriptive_statistics.csv"))
cat("  Saved: growth_descriptive_statistics.csv\n")

# By size class
size_class_stats <- growth_clean %>%
  group_by(size_class) %>%
  summarise(
    n = n(),
    agr_mean = mean(agr, na.rm = TRUE),
    agr_median = median(agr, na.rm = TRUE),
    agr_sd = sd(agr, na.rm = TRUE),
    rgr_mean = mean(rgr, na.rm = TRUE),
    rgr_median = median(rgr, na.rm = TRUE),
    rgr_sd = sd(rgr, na.rm = TRUE),
    pct_positive = mean(positive_growth, na.rm = TRUE) * 100,
    pct_shrinking = mean(agr < 0, na.rm = TRUE) * 100,
    .groups = "drop"
  ) %>%
  arrange(size_class)

cat("\n\nGROWTH BY SIZE CLASS:\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat(sprintf("%-20s %6s %10s %10s %10s %10s %10s\n",
            "Size Class", "n", "AGR Mean", "AGR Med", "RGR Mean", "RGR Med", "% Pos"))
cat("─────────────────────────────────────────────────────────────────\n")
for (i in 1:nrow(size_class_stats)) {
  cat(sprintf("%-20s %6d %10.1f %10.1f %10.3f %10.3f %10.1f%%\n",
              as.character(size_class_stats$size_class[i]),
              size_class_stats$n[i],
              size_class_stats$agr_mean[i],
              size_class_stats$agr_median[i],
              size_class_stats$rgr_mean[i],
              size_class_stats$rgr_median[i],
              size_class_stats$pct_positive[i]))
}

# =============================================================================
# 3. SIZE-GROWTH RELATIONSHIPS: AGR vs RGR COMPARISON
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SIZE-GROWTH RELATIONSHIP ANALYSIS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Fit GAMs for both metrics
# NOTE: Using k=3 to constrain smoothness (allows at most 1 bend/inflection point)
# Higher k values (e.g., k=5) allow multiple wiggles that may overfit noise
cat("Fitting GAM models (k=3 for single-bend constraint)...\n")

# AGR ~ log(size) GAM
agr_gam <- gam(agr ~ s(log_size, k = 3), data = growth_clean, method = "REML")
agr_r2 <- summary(agr_gam)$r.sq
agr_dev_exp <- summary(agr_gam)$dev.expl
agr_edf <- summary(agr_gam)$edf

# RGR ~ log(size) GAM
rgr_gam <- gam(rgr ~ s(log_size, k = 3), data = growth_clean, method = "REML")
rgr_r2 <- summary(rgr_gam)$r.sq
rgr_dev_exp <- summary(rgr_gam)$dev.expl
rgr_edf <- summary(rgr_gam)$edf

# P(positive growth) ~ log(size) GAM
pos_gam <- gam(positive_growth ~ s(log_size, k = 3),
               data = growth_clean, family = binomial, method = "REML")
pos_edf <- summary(pos_gam)$edf
pos_dev_exp <- summary(pos_gam)$dev.expl

cat("\nMODEL COMPARISON: Size as Predictor of Growth\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat(sprintf("%-35s %10s %15s %8s\n", "Response Variable", "R²", "Deviance Expl.", "EDF"))
cat("─────────────────────────────────────────────────────────────────\n")
cat(sprintf("%-35s %10.3f %15.1f%% %8.2f\n", "Absolute Growth Rate (AGR)", agr_r2, agr_dev_exp * 100, agr_edf))
cat(sprintf("%-35s %10.3f %15.1f%% %8.2f\n", "Relative Growth Rate (RGR)", rgr_r2, rgr_dev_exp * 100, rgr_edf))
cat(sprintf("%-35s %10s %15.1f%% %8.2f\n", "P(Positive Growth)", "—", pos_dev_exp * 100, pos_edf))

cat("\n  Note: EDF (effective degrees of freedom) measures smoothness.\n")
cat("        EDF = 1 is linear; EDF = 2 allows one bend; k=3 constrains max EDF to ~2.\n")

# Stratify RGR analysis by data source (Issue: coalesce creates inter-study differences)
if ("rgr_source" %in% names(growth_clean)) {
  cat("\n--- RGR-SIZE RELATIONSHIP BY DATA SOURCE ---\n")
  for (src in unique(growth_clean$rgr_source)) {
    src_data <- growth_clean %>% filter(rgr_source == src)
    if (nrow(src_data) > 50) {
      src_gam <- tryCatch(
        gam(rgr ~ s(log_size, k = 3), data = src_data, method = "REML"),
        error = function(e) NULL
      )
      if (!is.null(src_gam)) {
        cat(sprintf("  %s (n=%d): R² = %.1f%%, EDF = %.1f\n",
                    src, nrow(src_data), summary(src_gam)$r.sq * 100,
                    sum(src_gam$edf)))
      }
    }
  }
}

# =============================================================================
# 3b. NULL SIMULATION: Testing for Spurious Self-Correlation in RGR
# =============================================================================
# RGR = growth / size creates a mathematical relationship between RGR and size
# even when growth is independent of size (Brett 2004, Ecology Letters).
# This simulation quantifies the expected R² from this artifact alone.

cat("\n")
print_subheader("NULL SIMULATION: Spurious Self-Correlation in RGR")

set.seed(42)
n_null_sims <- 1000
null_r2 <- numeric(n_null_sims)

cat(sprintf("  Running %d null simulations (shuffling growth, computing RGR)...\n", n_null_sims))

# Back-compute the actual RGR numerator (what script 01 used)
# Script 01 defines rgr = coalesce(growth_live_cm2_yr, growth_cm2_yr) / size_for_class,
# so the numerator is rgr * size_cm2, NOT agr (which is growth_cm2_yr alone).
rgr_numerator <- growth_clean$rgr * growth_clean$size_cm2

for (i in seq_len(n_null_sims)) {
  # Shuffle RGR numerator within studies to break the growth-size association
  # while preserving within-study growth distributions
  shuffled_numerator <- unsplit(
    lapply(split(rgr_numerator, growth_clean$study), sample),
    growth_clean$study
  )
  null_rgr <- shuffled_numerator / growth_clean$size_cm2

  # Same trimming as observed RGR (two-sided, matching percentile bounds)
  null_bounds <- quantile(null_rgr, c(0.005, 0.995), na.rm = TRUE)
  valid <- null_rgr >= null_bounds[1] & null_rgr <= null_bounds[2] & is.finite(null_rgr)

  if (sum(valid) > 50) {
    null_gam <- tryCatch({
      gam(null_rgr[valid] ~ s(growth_clean$log_size[valid], k = 3), method = "REML")
    }, error = function(e) NULL)
    null_r2[i] <- if (!is.null(null_gam)) summary(null_gam)$r.sq else NA
  } else {
    null_r2[i] <- NA
  }
}

null_r2_valid <- null_r2[!is.na(null_r2)]
null_r2_median <- median(null_r2_valid)
null_r2_mean <- mean(null_r2_valid)
null_r2_95 <- quantile(null_r2_valid, 0.95)
biological_signal_r2 <- rgr_r2 - null_r2_median
observed_percentile <- mean(null_r2_valid < rgr_r2) * 100

cat(sprintf("  Observed RGR R²:      %.3f (%.1f%%)\n", rgr_r2, rgr_r2 * 100))
cat(sprintf("  Null R² median:       %.3f (%.1f%%)\n", null_r2_median, null_r2_median * 100))
cat(sprintf("  Null R² 95th pctile:  %.3f (%.1f%%)\n", null_r2_95, null_r2_95 * 100))
cat(sprintf("  Biological signal:    %.3f (%.1f%%)\n", biological_signal_r2, biological_signal_r2 * 100))
cat(sprintf("  Observed percentile:  %.1f%%\n", observed_percentile))

if (biological_signal_r2 > 0.01) {
  cat("  -> RGR contains genuine biological signal beyond mathematical artifact.\n")
} else {
  cat("  -> WARNING: Most of the RGR-size relationship may be mathematical artifact.\n")
}

# Save results
null_sim_results <- data.frame(
  metric = c("observed_rgr_r2", "agr_r2", "null_median_r2", "null_mean_r2",
             "null_95th_r2", "biological_signal_r2", "observed_percentile",
             "corrected_rgr_vs_agr_ratio", "n_simulations"),
  value = c(rgr_r2, agr_r2, null_r2_median, null_r2_mean,
            null_r2_95, biological_signal_r2, observed_percentile,
            biological_signal_r2 / max(agr_r2, 0.001), n_null_sims)
)
write_csv(null_sim_results, file.path(output_dir, "rgr_null_simulation.csv"))
cat("  Saved: rgr_null_simulation.csv\n")

cat("\n")
cat("KEY FINDING:\n")
cat(sprintf("  CORRECTED COMPARISON (accounting for self-correlation):\n"))
cat(sprintf("  RGR apparent R²: %.1f%% (includes mathematical artifact)\n", rgr_r2 * 100))
cat(sprintf("  Null expectation R²: %.1f%% (spurious self-correlation)\n", null_r2_median * 100))
cat(sprintf("  Biological signal R²: %.1f%%\n", biological_signal_r2 * 100))
cat(sprintf("  AGR R²: %.1f%%\n", agr_r2 * 100))
cat(sprintf("  Corrected RGR/AGR ratio: %.1f×\n", biological_signal_r2 / max(agr_r2, 0.001)))
cat("  → RGR is the more meaningful metric for size-growth relationships\n")

# =============================================================================
# 3c. ALLOMETRIC EXPONENT TEST (Brett 2004 alternative)
# =============================================================================
# If log(final_size) ~ beta * log(initial_size) has beta < 1.0,
# RGR genuinely declines with size (negative allometry).
# If beta == 1.0, growth is proportional to size and RGR is constant.

print_subheader("ALLOMETRIC EXPONENT TEST")

# Compute final size = initial + growth
growth_clean_allom <- growth_clean %>%
  filter(is.finite(agr) & size_cm2 > 0) %>%
  mutate(final_size = size_cm2 + agr) %>%
  filter(final_size > 0)  # Need positive for log

allom_model <- lm(log(final_size) ~ log(size_cm2), data = growth_clean_allom)
allom_beta <- coef(allom_model)[2]
allom_se <- summary(allom_model)$coefficients[2, 2]
allom_ci <- confint(allom_model)[2, ]
allom_t <- (allom_beta - 1.0) / allom_se
allom_p <- 2 * pt(abs(allom_t), df = allom_model$df.residual, lower.tail = FALSE)

cat(sprintf("  Allometric exponent (beta): %.4f (SE: %.4f)\n", allom_beta, allom_se))
cat(sprintf("  95%% CI: [%.4f, %.4f]\n", allom_ci[1], allom_ci[2]))
cat(sprintf("  Test H0: beta = 1.0: t = %.3f, p = %.4f\n", allom_t, allom_p))

if (allom_ci[2] < 1.0) {
  cat("  -> NEGATIVE ALLOMETRY: beta < 1.0. RGR genuinely declines with size.\n")
  cat("  -> The RGR-size relationship has real biological signal beyond mathematical artifact.\n")
} else if (allom_ci[1] > 1.0) {
  cat("  -> POSITIVE ALLOMETRY: beta > 1.0. Larger corals grow disproportionately faster.\n")
} else {
  cat("  -> Isometry cannot be rejected. RGR-size relationship may be partly artifactual.\n")
}

# Save allometric results
allom_results <- data.frame(
  metric = c("allometric_beta", "beta_se", "beta_ci_lower", "beta_ci_upper",
             "t_vs_isometry", "p_vs_isometry", "n_observations"),
  value = c(allom_beta, allom_se, allom_ci[1], allom_ci[2],
            allom_t, allom_p, nrow(growth_clean_allom))
)
write_csv(allom_results, file.path(output_dir, "allometric_exponent_test.csv"))
cat("  Saved: allometric_exponent_test.csv\n")

# Save GAM fit details
growth_gam_fit_details <- data.frame(
  response = c("AGR", "RGR", "P(Positive Growth)"),
  r_squared = c(agr_r2, rgr_r2, NA),
  deviance_explained = c(agr_dev_exp, rgr_dev_exp, pos_dev_exp),
  edf = c(agr_edf, rgr_edf, pos_edf),
  aic = c(AIC(agr_gam), AIC(rgr_gam), AIC(pos_gam)),
  n_obs = nrow(growth_clean)
)
write_csv(growth_gam_fit_details, file.path(output_dir, "growth_gam_fit_details.csv"))
cat("  Saved: growth_gam_fit_details.csv\n")

# =============================================================================
# 4. HETEROSCEDASTICITY ANALYSIS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  HETEROSCEDASTICITY IN GROWTH DATA\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Calculate variance by size bin
var_by_size <- growth_clean %>%
  mutate(size_bin = cut(log_size, breaks = 10)) %>%
  group_by(size_bin) %>%
  summarise(
    log_size_mid = mean(log_size, na.rm = TRUE),
    size_cm2_mid = exp(mean(log_size, na.rm = TRUE)),
    agr_var = var(agr, na.rm = TRUE),
    agr_sd = sd(agr, na.rm = TRUE),
    rgr_var = var(rgr, na.rm = TRUE),
    rgr_sd = sd(rgr, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  filter(!is.na(log_size_mid))

# Filter out zero/NA variance bins before log transformation
var_by_size_valid <- var_by_size %>%
  filter(!is.na(agr_var), agr_var > 0, !is.na(rgr_var), rgr_var > 0)

# Test for heteroscedasticity relationship
agr_var_model <- lm(log(agr_var) ~ log_size_mid, data = var_by_size_valid)
rgr_var_model <- lm(log(rgr_var) ~ log_size_mid, data = var_by_size_valid)

agr_var_slope <- coef(agr_var_model)[2]
rgr_var_slope <- coef(rgr_var_model)[2]

cat("VARIANCE SCALING WITH SIZE:\n")
cat(sprintf("  AGR variance ~ size^%.2f (variance increases with size)\n", agr_var_slope))
cat(sprintf("  RGR variance ~ size^%.2f (variance %s with size)\n",
            rgr_var_slope,
            ifelse(abs(rgr_var_slope) < 0.5, "roughly constant",
                   ifelse(rgr_var_slope > 0, "increases", "decreases"))))

cat("\n")
cat("INTERPRETATION:\n")
if (agr_var_slope > 1) {
  cat("  AGR shows strong heteroscedasticity: larger colonies have much higher\n")
  cat("  variance in absolute growth. This violates OLS assumptions.\n")
}
if (abs(rgr_var_slope) < abs(agr_var_slope)) {
  cat("\n  RGR transformation reduces heteroscedasticity, making it more\n")
  cat("  suitable for linear modeling and threshold detection.\n")
}

# Save heteroscedasticity analysis
write_csv(var_by_size, file.path(output_dir, "growth_heteroscedasticity.csv"))
cat("  Saved: growth_heteroscedasticity.csv\n")

# =============================================================================
# 5. THRESHOLD DETECTION
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SIZE THRESHOLD ANALYSIS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Generate prediction grids
pred_grid <- data.frame(
  log_size = seq(min(growth_clean$log_size), max(growth_clean$log_size), length.out = 200)
)

# RGR predictions
pred_grid$rgr_fit <- predict(rgr_gam, newdata = pred_grid)
rgr_se <- predict(rgr_gam, newdata = pred_grid, se.fit = TRUE)
pred_grid$rgr_ci_lower <- rgr_se$fit - 1.96 * rgr_se$se.fit
pred_grid$rgr_ci_upper <- rgr_se$fit + 1.96 * rgr_se$se.fit

# AGR predictions
pred_grid$agr_fit <- predict(agr_gam, newdata = pred_grid)
agr_se <- predict(agr_gam, newdata = pred_grid, se.fit = TRUE)
pred_grid$agr_ci_lower <- agr_se$fit - 1.96 * agr_se$se.fit
pred_grid$agr_ci_upper <- agr_se$fit + 1.96 * agr_se$se.fit

# P(positive) predictions
pred_grid$pos_fit <- predict(pos_gam, newdata = pred_grid, type = "response") * 100
pos_se <- predict(pos_gam, newdata = pred_grid, type = "link", se.fit = TRUE)
pred_grid$pos_ci_lower <- plogis(pos_se$fit - 1.96 * pos_se$se.fit) * 100
pred_grid$pos_ci_upper <- plogis(pos_se$fit + 1.96 * pos_se$se.fit) * 100

# Find inflection points via second derivative (midpoint approach, consistent with script 11)
find_threshold <- function(fit_vals, log_size_vals) {
  # First derivative: dy/dx at midpoints
  d1 <- diff(fit_vals) / diff(log_size_vals)
  x_mid <- (log_size_vals[-length(log_size_vals)] + log_size_vals[-1]) / 2
  # Second derivative: d(d1)/d(x_mid)
  d2 <- diff(d1) / diff(x_mid)
  # Avoid edge effects (d2 has length n-2, adjust valid range accordingly)
  valid_range <- 8:(length(d2) - 8)
  inflection_idx <- valid_range[which.max(abs(d2[valid_range]))]
  # Map back to original grid: d2[i] corresponds roughly to x_vals[i+1]
  threshold_log <- log_size_vals[inflection_idx + 1]
  threshold_cm2 <- exp(threshold_log)
  max_curvature <- abs(d2[inflection_idx])
  return(list(threshold_log = threshold_log, threshold_cm2 = threshold_cm2,
              max_curvature = max_curvature, inflection_idx = inflection_idx + 1))
}

rgr_threshold <- find_threshold(pred_grid$rgr_fit, pred_grid$log_size)
agr_threshold <- find_threshold(pred_grid$agr_fit, pred_grid$log_size)
pos_threshold <- find_threshold(pred_grid$pos_fit, pred_grid$log_size)

cat("DETECTED THRESHOLDS (inflection points):\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat(sprintf("%-35s %12s %12s\n", "Metric", "Threshold", "Max Curvature"))
cat("─────────────────────────────────────────────────────────────────\n")
cat(sprintf("%-35s %10.0f cm² %12.4f\n", "Relative Growth Rate (RGR)",
            rgr_threshold$threshold_cm2, rgr_threshold$max_curvature))
cat(sprintf("%-35s %10.0f cm² %12.4f\n", "Absolute Growth Rate (AGR)",
            agr_threshold$threshold_cm2, agr_threshold$max_curvature))
cat(sprintf("%-35s %10.0f cm² %12.4f\n", "P(Positive Growth)",
            pos_threshold$threshold_cm2, pos_threshold$max_curvature))

# =============================================================================
# 6. NATURAL VS RESTORED COMPARISON
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  NATURAL VS RESTORED POPULATION COMPARISON\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

pop_comparison <- growth_clean %>%
  group_by(population_type) %>%
  summarise(
    n = n(),
    mean_size_cm2 = mean(size_cm2, na.rm = TRUE),
    agr_mean = mean(agr, na.rm = TRUE),
    agr_median = median(agr, na.rm = TRUE),
    rgr_mean = mean(rgr, na.rm = TRUE),
    rgr_median = median(rgr, na.rm = TRUE),
    pct_positive = mean(positive_growth, na.rm = TRUE) * 100,
    .groups = "drop"
  )

cat("Population Type Comparison:\n")
print(as.data.frame(pop_comparison))

# Statistical test
if (n_distinct(growth_clean$population_type) >= 2) {
  natural <- growth_clean %>% filter(population_type == "Natural colony")
  restored <- growth_clean %>% filter(population_type == "Restoration fragment")

  if (nrow(natural) > 10 && nrow(restored) > 10) {
    # Test population type effect accounting for study clustering
    # (Wilcoxon ignores hierarchical structure)
    cat("\n--- POPULATION TYPE EFFECT (mixed model) ---\n")
    pop_model <- tryCatch({
      lmer(rgr ~ population_type + (1|study), data = growth_clean)
    }, error = function(e) {
      cat(sprintf("Mixed model failed: %s\n", e$message))
      NULL
    })

    if (!is.null(pop_model)) {
      pop_summary <- summary(pop_model)
      pop_type_coef <- "population_typeRestoration fragment"
      if (pop_type_coef %in% rownames(pop_summary$coefficients)) {
        cat(sprintf("Population type effect: %.4f (SE: %.4f, t = %.2f)\n",
                    fixef(pop_model)[pop_type_coef],
                    pop_summary$coefficients[pop_type_coef, "Std. Error"],
                    pop_summary$coefficients[pop_type_coef, "t value"]))
      } else {
        # Try alternate level name
        pop_type_coef <- grep("population_type", rownames(pop_summary$coefficients), value = TRUE)
        if (length(pop_type_coef) > 0) {
          cat(sprintf("Population type effect: %.4f (SE: %.4f, t = %.2f)\n",
                      fixef(pop_model)[pop_type_coef[1]],
                      pop_summary$coefficients[pop_type_coef[1], "Std. Error"],
                      pop_summary$coefficients[pop_type_coef[1], "t value"]))
        }
      }
      # Satterthwaite p-value if lmerTest is available
      if (requireNamespace("lmerTest", quietly = TRUE)) {
        pop_model_lt <- lmerTest::lmer(rgr ~ population_type + (1|study), data = growth_clean)
        pop_lt_summary <- summary(pop_model_lt)
        pop_type_coef <- grep("population_type", rownames(pop_lt_summary$coefficients), value = TRUE)
        if (length(pop_type_coef) > 0) {
          cat(sprintf("  p-value (Satterthwaite): %.4f\n",
                      pop_lt_summary$coefficients[pop_type_coef[1], "Pr(>|t|)"]))
        }
      }
    }

    # Keep original Wilcoxon for reference (non-hierarchical)
    cat("\nWilcoxon test (ignoring clustering - for reference only):\n")
    rgr_test <- wilcox.test(natural$rgr, restored$rgr)
    cat(sprintf("  Wilcoxon p = %.4f\n", rgr_test$p.value))
    if (rgr_test$p.value < 0.05) {
      cat("  → Significant difference in RGR between population types\n")
    }
  }
}

# Save population comparison results
# Build data frame from pop_comparison plus statistical test results if available
pop_comparison_out <- pop_comparison %>%
  mutate(
    lmm_estimate = NA_real_,
    lmm_se = NA_real_,
    lmm_p = NA_real_,
    wilcox_p = NA_real_
  )
if (exists("pop_model") && !is.null(pop_model)) {
  pop_summ_coefs <- summary(pop_model)$coefficients
  pop_coef_name <- grep("population_type", rownames(pop_summ_coefs), value = TRUE)
  if (length(pop_coef_name) > 0) {
    # Assign LMM stats to the Restoration fragment row (the contrast)
    rest_row <- which(pop_comparison_out$population_type == "Restoration fragment")
    if (length(rest_row) > 0) {
      pop_comparison_out$lmm_estimate[rest_row] <- pop_summ_coefs[pop_coef_name[1], "Estimate"]
      pop_comparison_out$lmm_se[rest_row] <- pop_summ_coefs[pop_coef_name[1], "Std. Error"]
    }
    if (exists("pop_lt_summary")) {
      lt_coef_name <- grep("population_type", rownames(pop_lt_summary$coefficients), value = TRUE)
      if (length(lt_coef_name) > 0 && "Pr(>|t|)" %in% colnames(pop_lt_summary$coefficients)) {
        if (length(rest_row) > 0) {
          pop_comparison_out$lmm_p[rest_row] <- pop_lt_summary$coefficients[lt_coef_name[1], "Pr(>|t|)"]
        }
      }
    }
  }
}
if (exists("rgr_test")) {
  rest_row <- which(pop_comparison_out$population_type == "Restoration fragment")
  if (length(rest_row) > 0) {
    pop_comparison_out$wilcox_p[rest_row] <- rgr_test$p.value
  }
}
write_csv(pop_comparison_out, file.path(output_dir, "growth_population_comparison.csv"))
cat("  Saved: growth_population_comparison.csv\n")

# =============================================================================
# 7. ALLOMETRY ANALYSIS: INITIAL VS FINAL SIZE
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  ALLOMETRY ANALYSIS: INITIAL VS FINAL SIZE\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Calculate final size from initial + growth
growth_clean <- growth_clean %>%
  mutate(
    final_size = size_cm2 + growth_metric  # Use consistent growth metric (prefers live-tissue growth)
  ) %>%
  filter(final_size > 0) %>%  # Remove non-positive final sizes (consistent with section 3c)
  mutate(
    log_final_size = log(final_size),
    # Growth ratio (multiplicative growth factor)
    growth_ratio = final_size / size_cm2
  )

# 7a. Initial vs Final Size Relationship (Allometry)
cat("INITIAL VS FINAL SIZE RELATIONSHIP:\n")

# Fit log-log regression (allometric model)
allometry_model <- lm(log_final_size ~ log_size, data = growth_clean)
allometry_summary <- summary(allometry_model)
allometry_slope <- coef(allometry_model)[2]
allometry_intercept <- coef(allometry_model)[1]
allometry_r2 <- allometry_summary$r.squared

cat(sprintf("  log(Final Size) = %.3f + %.3f × log(Initial Size)\n",
            allometry_intercept, allometry_slope))
cat(sprintf("  R² = %.3f (%.1f%% of variance explained)\n", allometry_r2, allometry_r2 * 100))
cat(sprintf("  Allometric slope = %.3f\n", allometry_slope))

if (abs(allometry_slope - 1) < 0.05) {
  cat("  → Slope ≈ 1: Isometric growth (proportional scaling)\n")
} else if (allometry_slope > 1) {
  cat("  → Slope > 1: Positive allometry (large colonies grow disproportionately faster)\n")
} else {
  cat("  → Slope < 1: Negative allometry (small colonies grow relatively faster)\n")
}

# 7b. SIZE RANGE ANALYSIS BY STUDY (Critical for interpreting allometry)
cat("\n\n⚠️  CRITICAL: SIZE RANGE DIFFERENCES BY STUDY\n")
cat("─────────────────────────────────────────────────────────────────\n")

# Document size ranges for each study
size_ranges <- growth_clean %>%
  group_by(study) %>%
  summarise(
    n = n(),
    min_size = min(size_cm2, na.rm = TRUE),
    max_size = max(size_cm2, na.rm = TRUE),
    median_size = median(size_cm2, na.rm = TRUE),
    log_min = min(log_size, na.rm = TRUE),
    log_max = max(log_size, na.rm = TRUE),
    size_range_fold = max_size / min_size,
    .groups = "drop"
  ) %>%
  arrange(median_size)

cat(sprintf("%-25s %6s %12s %12s %10s %12s\n",
            "Study", "n", "Min (cm²)", "Max (cm²)", "Median", "Range (×)"))
cat("─────────────────────────────────────────────────────────────────\n")
for (i in 1:nrow(size_ranges)) {
  cat(sprintf("%-25s %6d %12.1f %12.1f %10.1f %12.1f×\n",
              size_ranges$study[i],
              size_ranges$n[i],
              size_ranges$min_size[i],
              size_ranges$max_size[i],
              size_ranges$median_size[i],
              size_ranges$size_range_fold[i]))
}

# Calculate overlap between studies
cat("\n  ⚠️  WARNING: Studies have MINIMAL SIZE OVERLAP\n")
overall_min <- max(size_ranges$min_size)  # Highest minimum
overall_max <- min(size_ranges$max_size)  # Lowest maximum
cat(sprintf("  Common size range across ALL studies: %.1f - %.1f cm²\n", overall_min, overall_max))

if (overall_max < overall_min) {
  cat("  → NO OVERLAPPING SIZE RANGE exists across all studies!\n")
  cat("  → ANCOVA results are EXTRAPOLATION, not true comparison\n")
} else {
  n_in_overlap <- sum(growth_clean$size_cm2 >= overall_min & growth_clean$size_cm2 <= overall_max)
  cat(sprintf("  → Only %d observations (%.1f%%) fall in the common range\n",
              n_in_overlap, 100 * n_in_overlap / nrow(growth_clean)))
}

# 7c. ALLOMETRIC ANALYSIS - FULL DATA (with caveats)
cat("\n\nALLOMETRIC DIFFERENCES ACROSS STUDIES (FULL DATA):\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat("⚠️  CAVEAT: Each study covers different size ranges - slopes may reflect\n")
cat("   different portions of a single underlying allometric curve, NOT\n")
cat("   truly different allometric relationships.\n\n")

# Fit study-specific allometric models
allometry_by_study_df <- growth_clean %>%
  group_by(study) %>%
  filter(n() >= 30) %>%  # Only studies with sufficient data
  nest() %>%
  mutate(result = map(data, function(d) {
    mod <- lm(log_final_size ~ log_size, data = d)
    tibble(
      n = nrow(d),
      slope = coef(mod)[2],
      slope_se = summary(mod)$coefficients[2, 2],
      intercept = coef(mod)[1],
      r_squared = summary(mod)$r.squared,
      min_size = min(d$size_cm2),
      max_size = max(d$size_cm2)
    )
  })) %>%
  select(-data) %>%
  unnest(result) %>%
  ungroup() %>%
  mutate(
    slope_ci_lower = slope - 1.96 * slope_se,
    slope_ci_upper = slope + 1.96 * slope_se
  )

cat(sprintf("%-22s %5s %7s %14s %6s %15s\n",
            "Study", "n", "Slope", "95% CI", "R²", "Size Range"))
cat("─────────────────────────────────────────────────────────────────\n")
for (i in 1:nrow(allometry_by_study_df)) {
  cat(sprintf("%-22s %5d %7.3f [%5.3f,%5.3f] %6.3f %6.0f-%-6.0f\n",
              allometry_by_study_df$study[i],
              allometry_by_study_df$n[i],
              allometry_by_study_df$slope[i],
              allometry_by_study_df$slope_ci_lower[i],
              allometry_by_study_df$slope_ci_upper[i],
              allometry_by_study_df$r_squared[i],
              allometry_by_study_df$min_size[i],
              allometry_by_study_df$max_size[i]))
}

# Save allometry by study
allometry_by_study_out <- allometry_by_study_df %>%
  select(study, slope, slope_se = slope_se, ci_lower = slope_ci_lower,
         ci_upper = slope_ci_upper, r_squared, n, size_min = min_size, size_max = max_size)
write_csv(allometry_by_study_out, file.path(output_dir, "allometry_by_study.csv"))
cat("  Saved: allometry_by_study.csv\n")

# ANCOVA: Test for study × size interaction (with caveat)
if (n_distinct(growth_clean$study) >= 2 && nrow(growth_clean) > 100) {
  ancova_model <- lm(log_final_size ~ log_size * study, data = growth_clean)
  ancova_anova <- anova(ancova_model)
  interaction_p <- ancova_anova["log_size:study", "Pr(>F)"]

  cat(sprintf("\nANCOVA Test for Study × Size Interaction:\n"))
  cat(sprintf("  F-statistic: %.2f, p-value: %.4f\n",
              ancova_anova["log_size:study", "F value"], interaction_p))

  if (interaction_p < 0.05) {
    cat("  → Statistically significant (p < 0.05)\n")
    cat("  ⚠️  BUT: This may reflect different SIZE RANGES, not different biology!\n")
    cat("     Studies sample different parts of the size spectrum.\n")
  } else {
    cat("  → Not significant: Consistent allometry across studies\n")
  }

  # Save ANCOVA results
  ancova_results_df <- data.frame(
    term = rownames(ancova_anova),
    df = ancova_anova$Df,
    sum_sq = ancova_anova$`Sum Sq`,
    mean_sq = ancova_anova$`Mean Sq`,
    f_value = ancova_anova$`F value`,
    p_value = ancova_anova$`Pr(>F)`
  )
  write_csv(ancova_results_df, file.path(output_dir, "allometry_ancova_results.csv"))
  cat("  Saved: allometry_ancova_results.csv\n")
}

# 7d. RESTRICTED ANALYSIS: Only overlapping size range
cat("\n\nALLOMETRIC ANALYSIS - RESTRICTED TO OVERLAPPING SIZES:\n")
cat("─────────────────────────────────────────────────────────────────\n")

# Find size range where at least 2 studies have data
# Use pairwise overlaps to be more permissive
size_ranges_list <- split(growth_clean$size_cm2, growth_clean$study)
studies_with_data <- names(size_ranges_list)

# Find the range where NOAA (largest study) overlaps with fragment studies
if ("NOAA_survey" %in% studies_with_data) {
  noaa_range <- range(size_ranges_list[["NOAA_survey"]])
  other_studies <- setdiff(studies_with_data, "NOAA_survey")

  # Find overlap between NOAA and each fragment study
  cat("Pairwise overlaps with NOAA (largest dataset):\n")
  for (s in other_studies) {
    s_range <- range(size_ranges_list[[s]])
    overlap_min <- max(noaa_range[1], s_range[1])
    overlap_max <- min(noaa_range[2], s_range[2])
    if (overlap_max > overlap_min) {
      n_noaa_overlap <- sum(size_ranges_list[["NOAA_survey"]] >= overlap_min &
                            size_ranges_list[["NOAA_survey"]] <= overlap_max)
      n_other_overlap <- sum(size_ranges_list[[s]] >= overlap_min &
                             size_ranges_list[[s]] <= overlap_max)
      cat(sprintf("  %s: %.0f-%.0f cm² (n_NOAA=%d, n_%s=%d)\n",
                  s, overlap_min, overlap_max, n_noaa_overlap, s, n_other_overlap))
    } else {
      cat(sprintf("  %s: NO OVERLAP with NOAA\n", s))
    }
  }
}

# Define a restricted range for valid comparisons (e.g., 25-500 cm² where most studies overlap)
restricted_min <- 25   # Most fragment studies start around here
restricted_max <- 500  # Upper end of most fragment studies

growth_restricted <- growth_clean %>%
  filter(size_cm2 >= restricted_min, size_cm2 <= restricted_max)

n_restricted <- nrow(growth_restricted)
studies_in_restricted <- n_distinct(growth_restricted$study)

cat(sprintf("\nRestricted analysis: %.0f-%.0f cm² (SC2-SC3 range)\n",
            restricted_min, restricted_max))
cat(sprintf("  n = %d observations (%.1f%% of data)\n",
            n_restricted, 100 * n_restricted / nrow(growth_clean)))
cat(sprintf("  %d studies with data in this range\n", studies_in_restricted))

if (n_restricted >= 100 && studies_in_restricted >= 2) {
  # Fit allometry in restricted range
  restricted_allometry <- growth_restricted %>%
    group_by(study) %>%
    filter(n() >= 20) %>%
    nest() %>%
    mutate(result = map(data, function(d) {
      mod <- lm(log_final_size ~ log_size, data = d)
      tibble(
        n = nrow(d),
        slope = coef(mod)[2],
        slope_se = summary(mod)$coefficients[2, 2],
        r_squared = summary(mod)$r.squared
      )
    })) %>%
    select(-data) %>%
    unnest(result) %>%
    ungroup()

  if (nrow(restricted_allometry) >= 2) {
    cat("\nAllometric slopes in restricted range:\n")
    cat(sprintf("%-25s %5s %7s %10s %6s\n", "Study", "n", "Slope", "SE", "R²"))
    for (i in 1:nrow(restricted_allometry)) {
      cat(sprintf("%-25s %5d %7.3f %10.3f %6.3f\n",
                  restricted_allometry$study[i],
                  restricted_allometry$n[i],
                  restricted_allometry$slope[i],
                  restricted_allometry$slope_se[i],
                  restricted_allometry$r_squared[i]))
    }

    # ANCOVA on restricted data
    restricted_ancova <- lm(log_final_size ~ log_size * study, data = growth_restricted)
    restricted_anova <- anova(restricted_ancova)
    if ("log_size:study" %in% rownames(restricted_anova)) {
      restricted_p <- restricted_anova["log_size:study", "Pr(>F)"]
      cat(sprintf("\nRestricted ANCOVA (comparable sizes): p = %.4f\n", restricted_p))
      if (restricted_p < 0.05) {
        cat("  → Significant even within comparable sizes - TRUE allometric differences\n")
      } else {
        cat("  → NOT significant within comparable sizes\n")
        cat("  → Previous significance may have been driven by size range differences!\n")
      }
    }
  }
} else {
  cat("  Insufficient data in restricted range for comparative analysis\n")
}

# 7e. Allometric Differences Across Regions
cat("\n\nALLOMETRIC DIFFERENCES ACROSS REGIONS:\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat("⚠️  CAVEAT: Regional differences are CONFOUNDED with study type.\n")
cat("   e.g., Florida Keys = mostly NOAA large colonies; Curaçao = mostly fragments\n\n")

# Show size ranges by region
region_sizes <- growth_clean %>%
  group_by(region) %>%
  summarise(
    n = n(),
    min_size = min(size_cm2, na.rm = TRUE),
    max_size = max(size_cm2, na.rm = TRUE),
    median_size = median(size_cm2, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(median_size)

cat(sprintf("%-20s %6s %10s %10s %10s\n", "Region", "n", "Min", "Max", "Median"))
cat("─────────────────────────────────────────────────────────────────\n")
for (i in 1:nrow(region_sizes)) {
  cat(sprintf("%-20s %6d %10.1f %10.1f %10.1f\n",
              region_sizes$region[i],
              region_sizes$n[i],
              region_sizes$min_size[i],
              region_sizes$max_size[i],
              region_sizes$median_size[i]))
}

allometry_by_region <- growth_clean %>%
  group_by(region) %>%
  filter(n() >= 30) %>%
  nest() %>%
  mutate(result = map(data, function(d) {
    mod <- lm(log_final_size ~ log_size, data = d)
    tibble(
      n = nrow(d),
      slope = coef(mod)[2],
      slope_se = summary(mod)$coefficients[2, 2],
      intercept = coef(mod)[1],
      r_squared = summary(mod)$r.squared,
      min_size = min(d$size_cm2),
      max_size = max(d$size_cm2)
    )
  })) %>%
  select(-data) %>%
  unnest(result) %>%
  ungroup() %>%
  mutate(
    slope_ci_lower = slope - 1.96 * slope_se,
    slope_ci_upper = slope + 1.96 * slope_se
  )

cat(sprintf("\n%-18s %5s %7s %14s %6s %15s\n",
            "Region", "n", "Slope", "95% CI", "R²", "Size Range"))
cat("─────────────────────────────────────────────────────────────────\n")
for (i in 1:nrow(allometry_by_region)) {
  cat(sprintf("%-18s %5d %7.3f [%5.3f,%5.3f] %6.3f %6.0f-%-6.0f\n",
              allometry_by_region$region[i],
              allometry_by_region$n[i],
              allometry_by_region$slope[i],
              allometry_by_region$slope_ci_lower[i],
              allometry_by_region$slope_ci_upper[i],
              allometry_by_region$r_squared[i],
              allometry_by_region$min_size[i],
              allometry_by_region$max_size[i]))
}

# ANCOVA for regions (with caveat)
if (n_distinct(growth_clean$region) >= 2) {
  region_ancova <- lm(log_final_size ~ log_size * region, data = growth_clean)
  region_anova <- anova(region_ancova)
  region_interaction_p <- region_anova["log_size:region", "Pr(>F)"]

  cat(sprintf("\nANCOVA Test for Region × Size Interaction:\n"))
  cat(sprintf("  F-statistic: %.2f, p-value: %.4f\n",
              region_anova["log_size:region", "F value"], region_interaction_p))

  if (region_interaction_p < 0.05) {
    cat("  → Statistically significant\n")
    cat("  ⚠️  BUT: Different regions sample different SIZE RANGES\n")
    cat("     Cannot separate true regional effects from size effects.\n")
  } else {
    cat("  → Not significant: Consistent allometry across regions\n")
  }
}

# 7f. Natural vs Restored Allometry
cat("\n\nNATURAL VS RESTORED ALLOMETRY:\n")
cat("─────────────────────────────────────────────────────────────────\n")

# First show size ranges for each type
type_sizes <- growth_clean %>%
  group_by(population_type) %>%
  summarise(
    n = n(),
    min_size = min(size_cm2, na.rm = TRUE),
    max_size = max(size_cm2, na.rm = TRUE),
    median_size = median(size_cm2, na.rm = TRUE),
    .groups = "drop"
  )

cat("Size ranges by population type:\n")
for (i in 1:nrow(type_sizes)) {
  cat(sprintf("  %s (n=%d): %.0f-%.0f cm² (median: %.0f)\n",
              type_sizes$population_type[i],
              type_sizes$n[i],
              type_sizes$min_size[i],
              type_sizes$max_size[i],
              type_sizes$median_size[i]))
}

# Check for overlap
nat_range <- type_sizes %>% filter(population_type == "Natural colony")
rest_range <- type_sizes %>% filter(population_type == "Restoration fragment")
if (nrow(nat_range) > 0 && nrow(rest_range) > 0) {
  overlap_min <- max(nat_range$min_size, rest_range$min_size)
  overlap_max <- min(nat_range$max_size, rest_range$max_size)
  if (overlap_max > overlap_min) {
    n_nat_overlap <- sum(growth_clean$population_type == "Natural colony" &
                         growth_clean$size_cm2 >= overlap_min &
                         growth_clean$size_cm2 <= overlap_max)
    n_rest_overlap <- sum(growth_clean$population_type == "Restoration fragment" &
                          growth_clean$size_cm2 >= overlap_min &
                          growth_clean$size_cm2 <= overlap_max)
    cat(sprintf("\n  Overlapping range: %.0f-%.0f cm²\n", overlap_min, overlap_max))
    cat(sprintf("  Natural in overlap: %d, Restored in overlap: %d\n",
                n_nat_overlap, n_rest_overlap))
  } else {
    cat("\n  ⚠️  NO OVERLAPPING SIZE RANGE between natural and restored!\n")
  }
}

allometry_by_type <- growth_clean %>%
  group_by(population_type) %>%
  filter(n() >= 30) %>%
  nest() %>%
  mutate(result = map(data, function(d) {
    mod <- lm(log_final_size ~ log_size, data = d)
    tibble(
      n = nrow(d),
      slope = coef(mod)[2],
      slope_se = summary(mod)$coefficients[2, 2],
      intercept = coef(mod)[1],
      r_squared = summary(mod)$r.squared,
      min_size = min(d$size_cm2),
      max_size = max(d$size_cm2)
    )
  })) %>%
  select(-data) %>%
  unnest(result) %>%
  ungroup()

cat("\n")
for (i in 1:nrow(allometry_by_type)) {
  cat(sprintf("%s (n=%d, %.0f-%.0f cm²):\n",
              allometry_by_type$population_type[i],
              allometry_by_type$n[i],
              allometry_by_type$min_size[i],
              allometry_by_type$max_size[i]))
  cat(sprintf("  Slope = %.3f (SE = %.3f)\n",
              allometry_by_type$slope[i], allometry_by_type$slope_se[i]))
  cat(sprintf("  R² = %.3f\n\n", allometry_by_type$r_squared[i]))
}

# Test for difference (with caveat about size ranges)
if (n_distinct(growth_clean$population_type) >= 2) {
  type_ancova <- lm(log_final_size ~ log_size * population_type, data = growth_clean)
  type_anova <- anova(type_ancova)
  type_interaction_p <- type_anova["log_size:population_type", "Pr(>F)"]

  cat(sprintf("ANCOVA Test for Population Type × Size Interaction:\n"))
  cat(sprintf("  p-value: %.4f\n", type_interaction_p))

  if (type_interaction_p < 0.05) {
    cat("  → Statistically significant\n")
    cat("  ⚠️  BUT: Natural colonies are MUCH LARGER than fragments on average\n")
    cat("     Slope differences may reflect SIZE RANGE, not population type.\n")
  } else {
    cat("  → Not significant: Similar allometric growth across population types\n")
  }

  # Do restricted analysis in overlapping range
  if (exists("overlap_min") && exists("overlap_max") && overlap_max > overlap_min) {
    growth_overlap <- growth_clean %>%
      filter(size_cm2 >= overlap_min, size_cm2 <= overlap_max)

    if (n_distinct(growth_overlap$population_type) >= 2 && nrow(growth_overlap) >= 50) {
      overlap_ancova <- lm(log_final_size ~ log_size * population_type, data = growth_overlap)
      overlap_anova <- anova(overlap_ancova)
      if ("log_size:population_type" %in% rownames(overlap_anova)) {
        overlap_p <- overlap_anova["log_size:population_type", "Pr(>F)"]
        cat(sprintf("\n  Restricted ANCOVA (overlapping sizes only): p = %.4f\n", overlap_p))
        if (overlap_p < 0.05) {
          cat("  → Significant even in comparable size range - TRUE difference\n")
        } else {
          cat("  → NOT significant in comparable size range\n")
          cat("  → Apparent difference was likely driven by size range confound\n")
        }
      }
    }
  }
}

# =============================================================================
# 7g. ADVANCED METHODS TO ADDRESS SIZE RANGE CONFOUND
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  ADVANCED ANALYSES FOR SIZE RANGE CONFOUND\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# ---- 7g.1: Mixed-Effects Model with Study as Random Effect ----
cat("7g.1 MIXED-EFFECTS MODEL (Study as Random Effect)\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat("This approach treats study as a random effect, allowing each study\n")
cat("to have its own intercept but estimating a common allometric slope.\n\n")

if (has_lme4) {
  # Random intercept model
  lmm_ri <- lmer(log_final_size ~ log_size + (1 | study), data = growth_clean)
  lmm_ri_summary <- summary(lmm_ri)

  # Random slope + intercept model
  lmm_rs <- tryCatch({
    lmer(log_final_size ~ log_size + (log_size | study), data = growth_clean)
  }, error = function(e) NULL)

  # Extract fixed effect (overall allometric slope)
  fixed_slope <- fixef(lmm_ri)["log_size"]
  fixed_se <- sqrt(diag(vcov(lmm_ri)))["log_size"]

  cat("Random Intercept Model:\n")
  cat(sprintf("  Fixed effect slope (overall allometry) = %.4f (SE = %.4f)\n",
              fixed_slope, fixed_se))
  cat(sprintf("  95%% CI: [%.4f, %.4f]\n",
              fixed_slope - 1.96 * fixed_se, fixed_slope + 1.96 * fixed_se))

  # Variance components
  var_comp <- as.data.frame(VarCorr(lmm_ri))
  study_var <- var_comp$vcov[var_comp$grp == "study"]
  residual_var <- var_comp$vcov[var_comp$grp == "Residual"]
  icc <- study_var / (study_var + residual_var)

  cat(sprintf("\n  Intraclass Correlation (ICC) = %.3f\n", icc))
  cat(sprintf("  → %.1f%% of residual variance is between-study\n", icc * 100))
  cat(sprintf("  → %.1f%% of residual variance is within-study\n", (1 - icc) * 100))

  if (!is.null(lmm_rs)) {
    # Compare random intercept vs random slope models
    anova_lmm <- anova(lmm_ri, lmm_rs)
    cat(sprintf("\n  Likelihood ratio test (random slope vs intercept): p = %.4f\n",
                anova_lmm$`Pr(>Chisq)`[2]))
    if (anova_lmm$`Pr(>Chisq)`[2] < 0.05) {
      cat("  → Random slopes significantly improve fit (allometry DOES differ by study)\n")

      # Extract random slopes
      ranef_slopes <- ranef(lmm_rs)$study
      cat("\n  Random slope deviations from fixed effect:\n")
      for (s in rownames(ranef_slopes)) {
        cat(sprintf("    %s: %.4f\n", s, ranef_slopes[s, "log_size"]))
      }
    } else {
      cat("  → Random slopes not needed (allometry is consistent across studies)\n")
    }
  }

  # Store for later
  lmm_fixed_slope <- fixed_slope
  lmm_fixed_se <- fixed_se

} else {
  cat("  [lme4 package not available - skipping mixed-effects models]\n")
  lmm_fixed_slope <- NA
  lmm_fixed_se <- NA
}

# ---- 7g.2: Piecewise/Segmented Regression ----
cat("\n\n7g.2 PIECEWISE REGRESSION (Breakpoint Detection)\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat("Testing if there's a breakpoint where allometric relationship changes.\n")
cat("Using k=3 to constrain to at most one bend (biological parsimony).\n\n")

# Use GAM with spline to detect nonlinearity (k=3 for single bend max)
gam_allometry <- gam(log_final_size ~ s(log_size, k = 3), data = growth_clean)
gam_linear <- lm(log_final_size ~ log_size, data = growth_clean)

# Report EDF
gam_allom_edf <- summary(gam_allometry)$edf
cat(sprintf("GAM EDF: %.2f (1=linear, 2=one bend)\n\n", gam_allom_edf))

# Compare AIC
gam_aic <- AIC(gam_allometry)
linear_aic <- AIC(gam_linear)

cat(sprintf("Linear model AIC:     %.1f\n", linear_aic))
cat(sprintf("GAM (nonlinear) AIC:  %.1f\n", gam_aic))
cat(sprintf("Difference (Δ AIC):   %.1f\n", linear_aic - gam_aic))

if (linear_aic - gam_aic > 10) {
  cat("\n→ Nonlinear model substantially better (ΔAIC > 10)\n")
  cat("→ Allometric relationship is NOT simply log-linear\n")

  # Find where the relationship changes most
  pred_allom <- data.frame(log_size = seq(min(growth_clean$log_size),
                                           max(growth_clean$log_size),
                                           length.out = 200))
  pred_allom$fit <- predict(gam_allometry, newdata = pred_allom)

  # Calculate local slope (first derivative) using midpoint approach (consistent with script 11)
  d1 <- diff(pred_allom$fit) / diff(pred_allom$log_size)
  x_mid <- (pred_allom$log_size[-nrow(pred_allom)] + pred_allom$log_size[-1]) / 2
  # Second derivative at midpoints of midpoints
  d2 <- diff(d1) / diff(x_mid)

  # Find breakpoint candidates (where second derivative magnitude is largest)
  # d2 has length n-2; valid indices avoid edge effects
  valid_idx <- 8:(length(d2) - 8)
  breakpoint_d2_idx <- valid_idx[which.max(abs(d2[valid_idx]))]
  # Map back to original grid: d2[i] corresponds roughly to pred_allom row i+1
  breakpoint_idx <- breakpoint_d2_idx + 1
  breakpoint_log <- pred_allom$log_size[breakpoint_idx]
  breakpoint_cm2 <- exp(breakpoint_log)

  # Compute local slopes for reporting (first derivative at nearby points)
  slope_before <- d1[max(1, breakpoint_d2_idx - 10)]
  slope_after <- d1[min(length(d1), breakpoint_d2_idx + 10)]

  cat(sprintf("\n  Detected breakpoint at ~%.0f cm² (log = %.2f)\n",
              breakpoint_cm2, breakpoint_log))
  cat(sprintf("  Local slope before: %.3f\n", slope_before))
  cat(sprintf("  Local slope after:  %.3f\n", slope_after))

} else if (linear_aic - gam_aic > 2) {
  cat("\n→ Nonlinear model somewhat better (2 < ΔAIC < 10)\n")
  cat("→ Possible mild nonlinearity, but linear approximation reasonable\n")
} else {
  cat("\n→ Linear model adequate (ΔAIC ≤ 2)\n")
  cat("→ No evidence for breakpoint in allometric relationship\n")
  breakpoint_cm2 <- NA
}

# ---- 7g.3: Stratified Analysis by Size Class ----
cat("\n\n7g.3 STRATIFIED ANALYSIS BY SIZE CLASS\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat("Compare allometry WITHIN size classes where studies overlap.\n\n")

# Identify which size classes have multiple studies
sc_study_counts <- growth_clean %>%
  group_by(size_class, study) %>%
  summarise(n = n(), .groups = "drop") %>%
  filter(n >= 20) %>%
  group_by(size_class) %>%
  summarise(
    n_studies = n_distinct(study),
    studies = paste(study, collapse = ", "),
    total_n = sum(n),
    .groups = "drop"
  )

cat("Size classes with data from multiple studies (n ≥ 20 per study):\n")
print(as.data.frame(sc_study_counts))

# For size classes with multiple studies, compare slopes
cat("\n\nWithin-size-class ANCOVA results:\n")
cat("─────────────────────────────────────────────────────────────────\n")

within_sc_results <- list()
for (sc in sc_study_counts$size_class[sc_study_counts$n_studies >= 2]) {
  sc_data <- growth_clean %>%
    filter(size_class == sc) %>%
    group_by(study) %>%
    filter(n() >= 20) %>%
    ungroup()

  if (n_distinct(sc_data$study) >= 2) {
    # Fit ANCOVA within this size class
    sc_ancova <- lm(log_final_size ~ log_size * study, data = sc_data)
    sc_anova <- anova(sc_ancova)

    if ("log_size:study" %in% rownames(sc_anova)) {
      sc_p <- sc_anova["log_size:study", "Pr(>F)"]

      # Get slopes by study within this SC
      sc_slopes <- sc_data %>%
        group_by(study) %>%
        nest() %>%
        mutate(result = map(data, function(d) {
          mod <- lm(log_final_size ~ log_size, data = d)
          tibble(slope = coef(mod)[2], n = nrow(d))
        })) %>%
        select(-data) %>%
        unnest(result)

      within_sc_results[[as.character(sc)]] <- list(
        p_value = sc_p,
        slopes = sc_slopes,
        n = nrow(sc_data)
      )

      cat(sprintf("\n%s (n = %d, %d studies):\n", sc, nrow(sc_data), n_distinct(sc_data$study)))
      cat(sprintf("  Interaction p-value: %.4f\n", sc_p))
      cat("  Slopes by study:\n")
      for (i in 1:nrow(sc_slopes)) {
        cat(sprintf("    %s: %.3f (n=%d)\n",
                    sc_slopes$study[i], sc_slopes$slope[i], sc_slopes$n[i]))
      }
      if (sc_p < 0.05) {
        cat("  → Significant difference within this size class!\n")
      } else {
        cat("  → No significant difference within this size class\n")
      }
    }
  }
}

# ---- 7g.4: Bootstrap Confidence Intervals for Slope Comparisons ----
cat("\n\n7g.4 BOOTSTRAP CONFIDENCE INTERVALS FOR SLOPE DIFFERENCES\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat("Non-parametric bootstrap to test if slopes truly differ.\n\n")

# Compare NOAA vs all fragment studies (if both have sufficient data)
if ("NOAA_survey" %in% growth_clean$study) {
  noaa_data <- growth_clean %>% filter(study == "NOAA_survey")
  frag_data <- growth_clean %>% filter(study != "NOAA_survey")

  if (nrow(noaa_data) >= 100 && nrow(frag_data) >= 100) {
    # NOTE: Cluster bootstrap resamples studies (not individual observations) to
    # account for within-study correlation. This produces wider but more honest
    # CIs that reflect between-study heterogeneity.
    cluster_bootstrap <- function(data) {
      studies <- unique(data$study)
      boot_studies <- sample(studies, replace = TRUE)
      do.call(rbind, lapply(boot_studies, function(s) {
        study_data <- data[data$study == s, ]
        study_data[sample(nrow(study_data), nrow(study_data), replace = TRUE), ]
      }))
    }

    # Bootstrap function
    boot_slope_diff <- function(data1, data2, n_boot = 1000) {
      diffs <- numeric(n_boot)
      for (i in 1:n_boot) {
        # Cluster bootstrap: resample studies, then collect all observations
        samp1 <- cluster_bootstrap(data1)
        samp2 <- cluster_bootstrap(data2)

        # Fit models
        mod1 <- lm(log_final_size ~ log_size, data = samp1)
        mod2 <- lm(log_final_size ~ log_size, data = samp2)

        # Calculate difference
        diffs[i] <- coef(mod1)[2] - coef(mod2)[2]
      }
      return(diffs)
    }

    cat("Bootstrapping slope difference (NOAA vs all fragments)...\n")
    set.seed(42)
    boot_diffs <- boot_slope_diff(noaa_data, frag_data, n_boot = 1000)

    # Observed difference
    obs_diff <- coef(lm(log_final_size ~ log_size, data = noaa_data))[2] -
                coef(lm(log_final_size ~ log_size, data = frag_data))[2]

    # Bootstrap CI
    boot_ci <- quantile(boot_diffs, c(0.025, 0.975))
    boot_p <- 2 * min(mean(boot_diffs > 0), mean(boot_diffs < 0))

    cat(sprintf("\n  NOAA slope:     %.4f (n = %d)\n",
                coef(lm(log_final_size ~ log_size, data = noaa_data))[2], nrow(noaa_data)))
    cat(sprintf("  Fragment slope: %.4f (n = %d)\n",
                coef(lm(log_final_size ~ log_size, data = frag_data))[2], nrow(frag_data)))
    cat(sprintf("  Difference:     %.4f\n", obs_diff))
    cat(sprintf("  Bootstrap 95%% CI: [%.4f, %.4f]\n", boot_ci[1], boot_ci[2]))
    cat(sprintf("  Bootstrap p-value: %.4f\n", boot_p))

    if (boot_ci[1] > 0 || boot_ci[2] < 0) {
      cat("\n  → CI excludes zero: slopes are significantly different\n")
    } else {
      cat("\n  → CI includes zero: slopes may not differ\n")
    }

    # But note the caveat!
    cat("\n  ⚠️ CAVEAT: This comparison is STILL confounded by size range!\n")
    cat("     NOAA samples 1-85,000 cm²; fragments sample 5-500 cm²\n")
    cat("     Use restricted analysis (7d) for valid comparison.\n")

    # Store results
    boot_slope_results <- list(
      noaa_slope = coef(lm(log_final_size ~ log_size, data = noaa_data))[2],
      frag_slope = coef(lm(log_final_size ~ log_size, data = frag_data))[2],
      diff = obs_diff,
      ci = boot_ci,
      p_value = boot_p
    )
  } else {
    cat("  Insufficient data for NOAA vs fragment bootstrap comparison\n")
    boot_slope_results <- NULL
  }
} else {
  cat("  NOAA survey not found in data\n")
  boot_slope_results <- NULL
}

# ---- 7g.5: GAM-based Nonlinear Allometry Test ----
cat("\n\n7g.5 NONLINEAR (GAM) ALLOMETRY BY GROUP\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat("Testing if relationship is truly linear in log-log space.\n")
cat("Using k=3 to allow at most one bend (biological parsimony).\n\n")

# Fit GAM for each population type (k=3 for single bend max)
for (pop_type in unique(growth_clean$population_type)) {
  pop_data <- growth_clean %>% filter(population_type == pop_type)

  if (nrow(pop_data) >= 100) {
    gam_pop <- gam(log_final_size ~ s(log_size, k = 3), data = pop_data)
    lm_pop <- lm(log_final_size ~ log_size, data = pop_data)

    gam_dev <- summary(gam_pop)$dev.expl
    lm_r2 <- summary(lm_pop)$r.squared
    edf <- summary(gam_pop)$edf  # Effective degrees of freedom

    cat(sprintf("%s (n = %d):\n", pop_type, nrow(pop_data)))
    cat(sprintf("  Linear R²:        %.4f\n", lm_r2))
    cat(sprintf("  GAM dev. expl.:   %.4f\n", gam_dev))
    cat(sprintf("  GAM edf:          %.2f (1 = linear, 2 = one bend)\n", edf))

    if (edf > 1.8) {
      cat("  → EDF near 2: relationship has one significant bend\n")
    } else if (edf > 1.3) {
      cat("  → EDF 1.3-1.8: mild nonlinearity\n")
    } else {
      cat("  → EDF ≈ 1: relationship is approximately linear\n")
    }
    cat("\n")
  }
}

# ---- 7g.6: Propensity Score Matching for Size-Matched Comparisons ----
cat("\n\n7g.6 SIZE-MATCHED COMPARISONS (Nearest Neighbor Matching)\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat("Creating size-matched pairs between natural and restored populations\n")
cat("to compare allometry at equivalent sizes.\n\n")

# Define natural vs restored groups
natural_growth <- growth_clean %>%
  filter(population_type == "Natural colony") %>%
  mutate(group = "Natural")
restored_growth <- growth_clean %>%
  filter(population_type == "Restoration fragment") %>%
  mutate(group = "Restored")

if (nrow(natural_growth) >= 50 && nrow(restored_growth) >= 50) {

  # Find overlapping size range
  match_min <- max(min(natural_growth$log_size), min(restored_growth$log_size))
  match_max <- min(max(natural_growth$log_size), max(restored_growth$log_size))

  cat(sprintf("Overlapping log-size range: [%.2f, %.2f] (%.0f-%.0f cm²)\n",
              match_min, match_max, exp(match_min), exp(match_max)))

  # Filter to overlapping range
  natural_overlap <- natural_growth %>% filter(log_size >= match_min, log_size <= match_max)
  restored_overlap <- restored_growth %>% filter(log_size >= match_min, log_size <= match_max)

  cat(sprintf("Natural colonies in overlap: %d\n", nrow(natural_overlap)))
  cat(sprintf("Restored fragments in overlap: %d\n", nrow(restored_overlap)))

  if (nrow(natural_overlap) >= 30 && nrow(restored_overlap) >= 30) {
    # Nearest neighbor matching on size
    # For each restored fragment, find closest natural colony in size

    # Use smaller group for matching
    if (nrow(restored_overlap) <= nrow(natural_overlap)) {
      smaller <- restored_overlap
      larger <- natural_overlap
      smaller_label <- "Restored"
      larger_label <- "Natural"
    } else {
      smaller <- natural_overlap
      larger <- restored_overlap
      smaller_label <- "Natural"
      larger_label <- "Restored"
    }

    # Perform 1:1 nearest neighbor matching
    matched_pairs <- data.frame()
    used_indices <- c()

    for (i in 1:nrow(smaller)) {
      target_size <- smaller$log_size[i]

      # Find unused match with closest size
      available <- setdiff(1:nrow(larger), used_indices)
      if (length(available) == 0) break

      distances <- abs(larger$log_size[available] - target_size)
      best_match_idx <- available[which.min(distances)]
      used_indices <- c(used_indices, best_match_idx)

      # Create matched pair
      pair <- data.frame(
        pair_id = i,
        smaller_log_size = smaller$log_size[i],
        smaller_log_final = smaller$log_final_size[i],
        smaller_group = smaller_label,
        larger_log_size = larger$log_size[best_match_idx],
        larger_log_final = larger$log_final_size[best_match_idx],
        larger_group = larger_label,
        size_diff = abs(smaller$log_size[i] - larger$log_size[best_match_idx])
      )
      matched_pairs <- rbind(matched_pairs, pair)
    }

    cat(sprintf("\nMatched %d pairs\n", nrow(matched_pairs)))
    cat(sprintf("Mean size difference: %.3f log-cm² (%.1f%% on natural scale)\n",
                mean(matched_pairs$size_diff),
                100 * (exp(mean(matched_pairs$size_diff)) - 1)))

    # Keep only close matches (within 0.5 log units = ~65% difference)
    close_matches <- matched_pairs %>% filter(size_diff <= 0.5)
    cat(sprintf("Close matches (diff ≤ 0.5 log): %d pairs (%.1f%%)\n",
                nrow(close_matches), 100 * nrow(close_matches) / nrow(matched_pairs)))

    if (nrow(close_matches) >= 20) {
      # Reshape for comparison
      matched_long <- close_matches %>%
        select(pair_id, smaller_log_size, smaller_log_final, smaller_group,
               larger_log_size, larger_log_final, larger_group) %>%
        pivot_longer(
          cols = c(smaller_log_size, larger_log_size),
          names_to = "size_type",
          values_to = "log_size"
        ) %>%
        mutate(
          log_final_size = ifelse(size_type == "smaller_log_size",
                                  smaller_log_final, larger_log_final),
          group = ifelse(size_type == "smaller_log_size",
                         smaller_group, larger_group)
        ) %>%
        select(pair_id, group, log_size, log_final_size)

      # Compare slopes in matched data
      matched_ancova <- lm(log_final_size ~ log_size * group, data = matched_long)
      matched_anova <- anova(matched_ancova)

      cat("\nMatched-pair ANCOVA results:\n")
      if ("log_size:group" %in% rownames(matched_anova)) {
        matched_p <- matched_anova["log_size:group", "Pr(>F)"]
        cat(sprintf("  Interaction p-value: %.4f\n", matched_p))

        if (matched_p < 0.05) {
          cat("  → Allometric slopes DIFFER even in size-matched pairs!\n")
          cat("  → This is evidence of TRUE biological difference.\n")
        } else {
          cat("  → Slopes do NOT significantly differ in matched pairs\n")
          cat("  → Apparent differences were driven by size confound.\n")
        }
      }

      # Calculate slopes for each group in matched data
      matched_slopes <- matched_long %>%
        group_by(group) %>%
        nest() %>%
        mutate(result = map(data, function(d) {
          mod <- lm(log_final_size ~ log_size, data = d)
          tibble(
            n = nrow(d),
            slope = coef(mod)[2],
            slope_se = summary(mod)$coefficients[2, 2]
          )
        })) %>%
        select(-data) %>%
        unnest(result)

      cat("\n  Matched-pair slopes:\n")
      for (i in 1:nrow(matched_slopes)) {
        cat(sprintf("    %s: %.4f ± %.4f (n=%d)\n",
                    matched_slopes$group[i],
                    matched_slopes$slope[i],
                    matched_slopes$slope_se[i] * 1.96,
                    matched_slopes$n[i]))
      }

      # Paired t-test on residuals from common slope model
      matched_common <- lm(log_final_size ~ log_size, data = matched_long)
      matched_long$resid <- residuals(matched_common)

      resid_by_group <- matched_long %>%
        group_by(pair_id, group) %>%
        summarise(resid = mean(resid), .groups = "drop") %>%
        pivot_wider(names_from = group, values_from = resid)

      if (all(c("Natural", "Restored") %in% names(resid_by_group))) {
        paired_test <- t.test(resid_by_group$Natural, resid_by_group$Restored, paired = TRUE)
        cat(sprintf("\n  Paired t-test on residuals: p = %.4f\n", paired_test$p.value))
        cat(sprintf("  Mean difference: %.4f\n", paired_test$estimate))
        if (paired_test$p.value < 0.05) {
          if (paired_test$estimate > 0) {
            cat("  → Natural colonies have systematically higher final size (controlling for initial size)\n")
          } else {
            cat("  → Restored fragments have systematically higher final size (controlling for initial size)\n")
          }
        }
      }

      # Store matched results
      matched_comparison_results <- list(
        n_pairs = nrow(close_matches),
        matched_slopes = matched_slopes,
        ancova_p = ifelse("log_size:group" %in% rownames(matched_anova),
                          matched_anova["log_size:group", "Pr(>F)"], NA)
      )

    } else {
      cat("\nInsufficient close matches for reliable comparison.\n")
      matched_comparison_results <- NULL
    }

  } else {
    cat("Insufficient data in overlapping range for matching.\n")
    matched_comparison_results <- NULL
  }
} else {
  cat("Insufficient data in one or both groups for matching.\n")
  matched_comparison_results <- NULL
}

# Save size-matched comparison results
if (!is.null(matched_comparison_results)) {
  natural_slope_val <- matched_comparison_results$matched_slopes %>%
    filter(group == "Natural") %>% pull(slope)
  restored_slope_val <- matched_comparison_results$matched_slopes %>%
    filter(group == "Restored") %>% pull(slope)
  size_matched_out <- data.frame(
    n_pairs = matched_comparison_results$n_pairs,
    natural_slope = if (length(natural_slope_val) > 0) natural_slope_val else NA_real_,
    restored_slope = if (length(restored_slope_val) > 0) restored_slope_val else NA_real_,
    ancova_p = matched_comparison_results$ancova_p,
    paired_t_p = if (exists("paired_test")) paired_test$p.value else NA_real_,
    bootstrap_diff = if (exists("boot_slope_results") && !is.null(boot_slope_results)) boot_slope_results$diff else NA_real_,
    bootstrap_ci_lower = if (exists("boot_slope_results") && !is.null(boot_slope_results)) boot_slope_results$ci[1] else NA_real_,
    bootstrap_ci_upper = if (exists("boot_slope_results") && !is.null(boot_slope_results)) boot_slope_results$ci[2] else NA_real_
  )
  write_csv(size_matched_out, file.path(output_dir, "growth_size_matched_comparison.csv"))
  cat("  Saved: growth_size_matched_comparison.csv\n")
}

# =============================================================================
# 7h. SIZE DISTRIBUTION ANALYSIS
# =============================================================================

cat("\n\nSIZE DISTRIBUTION BY STUDY:\n")
cat("─────────────────────────────────────────────────────────────────\n")

size_dist_by_study <- growth_clean %>%
  group_by(study) %>%
  summarise(
    n = n(),
    initial_mean = mean(size_cm2, na.rm = TRUE),
    initial_median = median(size_cm2, na.rm = TRUE),
    initial_min = min(size_cm2, na.rm = TRUE),
    initial_max = max(size_cm2, na.rm = TRUE),
    final_mean = mean(final_size, na.rm = TRUE),
    final_median = median(final_size, na.rm = TRUE),
    pct_grew = mean(growth_cm2_yr > 0, na.rm = TRUE) * 100,
    .groups = "drop"
  )

cat(sprintf("%-20s %6s %12s %12s %12s %8s\n",
            "Study", "n", "Init Mean", "Final Mean", "Init Range", "% Grew"))
cat("─────────────────────────────────────────────────────────────────\n")
for (i in 1:nrow(size_dist_by_study)) {
  cat(sprintf("%-20s %6d %12.1f %12.1f %5.0f-%-6.0f %7.1f%%\n",
              size_dist_by_study$study[i],
              size_dist_by_study$n[i],
              size_dist_by_study$initial_mean[i],
              size_dist_by_study$final_mean[i],
              size_dist_by_study$initial_min[i],
              size_dist_by_study$initial_max[i],
              size_dist_by_study$pct_grew[i]))
}

# =============================================================================
# 8. ALLOMETRIC ASSUMPTIONS DOCUMENTATION
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  ALLOMETRIC ASSUMPTIONS & LIMITATIONS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

cat("SIZE MEASUREMENT METHOD:\n")
cat("  Planar area = Length × Width × (% Live / 100)\n")
cat("  Following Vardi et al. 2012\n\n")

cat("IMPLICATIONS FOR A. PALMATA (BRANCHING CORAL):\n")
cat("  • Small colonies (<100 cm²): Plate-like morphology\n")
cat("    → 2D planar area is reasonable proxy for tissue area\n\n")
cat("  • Medium colonies (100-1000 cm²): Developing branches\n")
cat("    → 2D begins to underestimate true 3D tissue area\n\n")
cat("  • Large colonies (>1000 cm²): Complex 3D branching\n")
cat("    → 2D significantly underestimates tissue area\n\n")

cat("IMPACT ON GROWTH METRICS:\n")
cat("  AGR (cm²/yr): Underestimates true tissue gain for large colonies\n")
cat("               Branch extension may not increase planar footprint\n\n")
cat("  RGR (yr⁻¹):   Partially corrected because:\n")
cat("               RGR = growth / size\n")
cat("               If both underestimate by factor k:\n")
cat("               True RGR ≈ (k × growth) / (k × size) = growth/size\n")
cat("               → The k factor cancels (assuming constant scaling)\n\n")

cat("CAVEAT:\n")
cat("  The scaling factor k is NOT constant with size.\n")
cat("  As colonies develop more 3D structure, k increases.\n")
cat(sprintf("  This means RGR threshold (~%.0f cm²) may reflect:\n", rgr_threshold$threshold_cm2))
cat("    1. True biological transition in growth allocation\n")
cat("    2. Measurement artifact at morphological transition\n")
cat("    3. Both confounded\n\n")

cat("RECOMMENDATION:\n")
cat(sprintf("  Use RGR for size-growth comparisons (R² = %.1f%%)\n", rgr_r2 * 100))
cat("  Be cautious comparing absolute growth across size classes\n")
cat("  Consider colony height data for future 3D corrections\n")

# =============================================================================
# 8. SAVE RESULTS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SAVING RESULTS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Summary table
# NOTE: n_analysis_ready is the post-filter sample size (after removing impossible values,
# extreme outliers, high-variance regions, and RGR outliers). Raw data has more records.
growth_rate_summary <- data.frame(
  metric = c("AGR", "RGR", "P(Positive)"),
  r_squared = c(agr_r2, rgr_r2, NA),
  deviance_explained = c(agr_dev_exp, rgr_dev_exp, pos_dev_exp),
  threshold_cm2 = c(agr_threshold$threshold_cm2, rgr_threshold$threshold_cm2, pos_threshold$threshold_cm2),
  threshold_log = c(agr_threshold$threshold_log, rgr_threshold$threshold_log, pos_threshold$threshold_log),
  max_curvature = c(agr_threshold$max_curvature, rgr_threshold$max_curvature, pos_threshold$max_curvature),
  n_analysis_ready = nrow(growth_clean)
)

write_csv(growth_rate_summary,
          file.path(output_dir, "growth_rate_summary.csv"))
cat("  ✓ Saved: growth_rate_summary.csv\n")

# Size class stats
write_csv(size_class_stats,
          file.path(output_dir, "growth_by_size_class.csv"))
cat("  ✓ Saved: growth_by_size_class.csv\n")

# Full results
results <- list(
  overall_stats = overall_stats,
  size_class_stats = size_class_stats,
  pop_comparison = pop_comparison,
  variance_scaling = list(
    agr_var_slope = agr_var_slope,
    rgr_var_slope = rgr_var_slope,
    var_by_size = var_by_size
  ),
  model_comparison = growth_rate_summary,
  thresholds = list(
    rgr = rgr_threshold,
    agr = agr_threshold,
    pos = pos_threshold
  ),
  predictions = pred_grid,
  gam_models = list(
    agr = agr_gam,
    rgr = rgr_gam,
    pos = pos_gam
  ),
  allometry_notes = list(
    method = "2D planar area (L × W × % live)",
    reference = "Vardi et al. 2012",
    limitation = "Underestimates 3D tissue area for large branching colonies",
    rgr_advantage = "Ratio partially cancels measurement bias"
  ),
  advanced_analyses = list(
    mixed_effects = list(
      fixed_slope = if (exists("lmm_fixed_slope")) lmm_fixed_slope else NA,
      fixed_se = if (exists("lmm_fixed_se")) lmm_fixed_se else NA
    ),
    piecewise = list(
      linear_aic = if (exists("linear_aic")) linear_aic else NA,
      gam_aic = if (exists("gam_aic")) gam_aic else NA,
      breakpoint_cm2 = if (exists("breakpoint_cm2")) breakpoint_cm2 else NA
    ),
    within_size_class = if (exists("within_sc_results")) within_sc_results else NULL,
    bootstrap = if (exists("boot_slope_results")) boot_slope_results else NULL,
    matched_pairs = if (exists("matched_comparison_results")) matched_comparison_results else NULL
  )
)

saveRDS(results, file.path(output_dir, "growth_rate_analysis.rds"))
cat("  ✓ Saved: growth_rate_analysis.rds\n")

# =============================================================================
# 9. CREATE FIGURES
# =============================================================================

cat("\nCreating figures...\n")

# Theme
colors <- list(
  ocean_deep = "#1B4965",
  ocean_light = "#5FA8D3",
  coral_warm = "#E07A5F",
  coral_pale = "#F2CC8F",
  reef_green = "#81B29A",
  sand = "#F4F1DE",
  text_primary = "#1B4965",
  text_secondary = "#5C6B73"
)

theme_publication <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(size = 14, face = "bold", color = colors$ocean_deep),
      plot.subtitle = element_text(size = 10, color = colors$text_secondary),
      axis.title = element_text(size = 10, face = "bold"),
      axis.text = element_text(size = 9),
      legend.position = "right",
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
      strip.text = element_text(face = "bold", size = 10),
      plot.caption = element_text(size = 8, color = colors$text_secondary, hjust = 0)
    )
}

# Binned data for plotting
growth_binned <- growth_clean %>%
  mutate(size_bin = cut(log_size, breaks = 15)) %>%
  group_by(size_bin) %>%
  summarise(
    log_size = mean(log_size, na.rm = TRUE),
    agr_mean = mean(agr, na.rm = TRUE),
    rgr_mean = mean(rgr, na.rm = TRUE),
    pct_positive = mean(positive_growth, na.rm = TRUE) * 100,
    n = n(),
    .groups = "drop"
  ) %>%
  filter(!is.na(log_size))

# Panel 1: AGR vs Size
p1 <- ggplot() +
  geom_point(data = growth_clean, aes(x = log_size, y = agr),
             alpha = 0.1, size = 0.8, color = colors$ocean_light) +
  geom_hline(yintercept = 0, linetype = "dashed", color = colors$text_secondary) +
  geom_ribbon(data = pred_grid, aes(x = log_size, ymin = agr_ci_lower, ymax = agr_ci_upper),
              fill = colors$coral_warm, alpha = 0.3) +
  geom_line(data = pred_grid, aes(x = log_size, y = agr_fit),
            color = colors$coral_warm, linewidth = 1.2) +
  geom_point(data = growth_binned, aes(x = log_size, y = agr_mean, size = n),
             color = colors$ocean_deep, alpha = 0.8) +
  geom_vline(xintercept = agr_threshold$threshold_log, linetype = "dashed",
             color = colors$reef_green, linewidth = 0.8) +
  scale_x_continuous(name = expression(paste("Log colony size (log cm"^2, ")")),
                     sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                                         breaks = c(10, 100, 1000, 10000))) +
  scale_y_continuous(name = expression(paste("Absolute Growth Rate (cm"^2, "/yr)")),
                     limits = quantile(growth_clean$agr, c(0.02, 0.98))) +
  scale_size_continuous(range = c(2, 6), guide = "none") +
  labs(subtitle = sprintf("A. Absolute Growth Rate (AGR) — R² = %.1f%%", agr_r2 * 100)) +
  theme_publication()

# Panel 2: RGR vs Size
p2 <- ggplot() +
  geom_point(data = growth_clean, aes(x = log_size, y = rgr),
             alpha = 0.1, size = 0.8, color = colors$ocean_light) +
  geom_hline(yintercept = 0, linetype = "dashed", color = colors$text_secondary) +
  geom_ribbon(data = pred_grid, aes(x = log_size, ymin = rgr_ci_lower, ymax = rgr_ci_upper),
              fill = colors$coral_pale, alpha = 0.3) +
  geom_line(data = pred_grid, aes(x = log_size, y = rgr_fit),
            color = colors$coral_pale, linewidth = 1.2) +
  geom_point(data = growth_binned, aes(x = log_size, y = rgr_mean, size = n),
             color = colors$ocean_deep, alpha = 0.8) +
  geom_vline(xintercept = rgr_threshold$threshold_log, linetype = "dashed",
             color = colors$coral_warm, linewidth = 0.8) +
  annotate("text", x = rgr_threshold$threshold_log,
           y = max(pred_grid$rgr_ci_upper, na.rm = TRUE) * 0.9,
           label = sprintf("Threshold:\n%.0f cm²", rgr_threshold$threshold_cm2),
           hjust = -0.1, color = colors$coral_warm, fontface = "bold", size = 3.5) +
  scale_x_continuous(name = expression(paste("Log colony size (log cm"^2, ")")),
                     sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                                         breaks = c(10, 100, 1000, 10000))) +
  scale_y_continuous(name = expression(paste("Relative Growth Rate (yr"^-1, ")"))) +
  scale_size_continuous(range = c(2, 6), guide = "none") +
  labs(subtitle = sprintf("B. Relative Growth Rate (RGR) — R² = %.1f%%", rgr_r2 * 100)) +
  theme_publication()

# Panel 3: P(Positive Growth) vs Size
p3 <- ggplot() +
  geom_ribbon(data = pred_grid, aes(x = log_size, ymin = pos_ci_lower, ymax = pos_ci_upper),
              fill = colors$reef_green, alpha = 0.2) +
  geom_line(data = pred_grid, aes(x = log_size, y = pos_fit),
            color = colors$reef_green, linewidth = 1.2) +
  geom_point(data = growth_binned, aes(x = log_size, y = pct_positive, size = n),
             color = colors$ocean_deep, alpha = 0.8) +
  geom_hline(yintercept = 75, linetype = "dotted", color = colors$text_secondary) +
  annotate("text", x = min(pred_grid$log_size) + 0.3, y = 77,
           label = "75%", color = colors$text_secondary, size = 3, hjust = 0) +
  scale_x_continuous(name = expression(paste("Log colony size (log cm"^2, ")")),
                     sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                                         breaks = c(10, 100, 1000, 10000))) +
  scale_y_continuous(name = "Probability of Positive Growth (%)", limits = c(50, 100)) +
  scale_size_continuous(range = c(2, 6), guide = "none") +
  labs(subtitle = sprintf("C. Probability of Positive Growth — Dev. Expl. = %.1f%%", pos_dev_exp * 100)) +
  theme_publication()

# Panel 4: Variance comparison
var_plot_data <- var_by_size %>%
  select(log_size_mid, agr_sd, rgr_sd) %>%
  pivot_longer(cols = c(agr_sd, rgr_sd), names_to = "metric", values_to = "sd") %>%
  mutate(metric = ifelse(metric == "agr_sd", "AGR (cm²/yr)", "RGR (yr⁻¹)"))

p4 <- ggplot(var_plot_data, aes(x = log_size_mid, y = sd, color = metric)) +
  geom_point(size = 3, alpha = 0.8) +
  geom_smooth(method = "lm", se = FALSE, linetype = "dashed") +
  scale_color_manual(values = c("AGR (cm²/yr)" = colors$coral_warm, "RGR (yr⁻¹)" = colors$coral_pale)) +
  scale_x_continuous(name = expression(paste("Log colony size (log cm"^2, ")")),
                     sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                                         breaks = c(10, 100, 1000, 10000))) +
  labs(subtitle = "D. Heteroscedasticity: SD by Size",
       y = "Standard Deviation", color = "Metric") +
  theme_publication() +
  theme(legend.position = "bottom")

# Combine
if (has_patchwork) {
  fig_combined <- (p1 | p2) / (p3 | p4) +
    plot_annotation(
      title = "Growth Rate Analysis: AGR vs RGR Comparison",
      subtitle = sprintf("RGR biological signal R² = %.1f%% (corrected for self-correlation); reduces heteroscedasticity", biological_signal_r2 * 100),
      caption = sprintf("n = %s observations | RGR = growth/size normalizes for body size | Threshold at ~%.0f cm²",
                        scales::comma(nrow(growth_clean)), rgr_threshold$threshold_cm2),
      theme = theme(
        plot.title = element_text(size = 16, face = "bold", color = colors$ocean_deep),
        plot.subtitle = element_text(size = 11, color = colors$text_secondary),
        plot.caption = element_text(size = 9, color = colors$text_secondary)
      )
    )

  ggsave(file.path(fig_dir_supp, "growth_rate_analysis.png"),
         fig_combined, width = 14, height = 12, dpi = 300)
  cat("  ✓ Saved: growth_rate_analysis.png\n")

  # Also save individual panels
  ggsave(file.path(fig_dir_supp, "rgr_vs_size.png"),
         p2, width = 8, height = 6, dpi = 300)
  cat("  ✓ Saved: rgr_vs_size.png\n")
} else {
  ggsave(file.path(fig_dir_supp, "agr_vs_size.png"), p1, width = 8, height = 6, dpi = 300)
  ggsave(file.path(fig_dir_supp, "rgr_vs_size.png"), p2, width = 8, height = 6, dpi = 300)
  ggsave(file.path(fig_dir_supp, "pos_growth_vs_size.png"), p3, width = 8, height = 6, dpi = 300)
  cat("  ✓ Saved individual panels\n")
}

# =============================================================================
# 10. ALLOMETRY FIGURES
# =============================================================================

cat("\nCreating allometry figures...\n")

# ---- Panel A: Initial vs Final Size (log-log scale) ----
allometry_scatter <- ggplot(growth_clean, aes(x = log_size, y = log_final_size)) +
  geom_point(aes(color = study), alpha = 0.3, size = 1.5) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = colors$text_secondary, linewidth = 0.8) +
  geom_smooth(method = "lm", se = TRUE, color = colors$ocean_deep, linewidth = 1.2) +
  annotate("text", x = max(growth_clean$log_size, na.rm = TRUE) - 1,
           y = min(growth_clean$log_final_size, na.rm = TRUE) + 0.5,
           label = sprintf("Slope = %.3f\n(1:1 = isometric)",
                          coef(lm(log_final_size ~ log_size, data = growth_clean))[2]),
           hjust = 1, fontface = "bold", size = 4, color = colors$ocean_deep) +
  scale_color_viridis_d(option = "plasma", name = "Study") +
  labs(
    title = "A. Initial vs Final Size: Allometric Scaling",
    subtitle = "Dashed line = 1:1 (isometric); Solid = observed relationship",
    x = expression(paste("Log Initial Size (log cm"^2, ")")),
    y = expression(paste("Log Final Size (log cm"^2, ")"))
  ) +
  theme_publication() +
  theme(legend.position = "none")

# ---- Panel B: SIZE RANGE CONFOUND - Critical Visualization ----
# Create size range summary for visualization
size_range_viz <- growth_clean %>%
  group_by(study) %>%
  summarise(
    min_log = min(log_size, na.rm = TRUE),
    max_log = max(log_size, na.rm = TRUE),
    median_log = median(log_size, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  mutate(study = factor(study, levels = study[order(median_log)]))

size_range_plot <- ggplot(size_range_viz, aes(y = study)) +
  geom_segment(aes(x = min_log, xend = max_log, yend = study, color = study),
               linewidth = 4, alpha = 0.7) +
  geom_point(aes(x = median_log), color = "black", size = 3) +
  geom_vline(xintercept = log(c(25, 100, 500, 2000)),
             linetype = "dashed", color = "gray50", alpha = 0.5) +
  annotate("text", x = log(c(25, 100, 500, 2000)), y = 0.3,
           label = c("SC2", "SC3", "SC4", "SC5"),
           size = 3, color = "gray40", hjust = 0.5) +
  scale_color_viridis_d(option = "plasma", guide = "none") +
  scale_x_continuous(
    name = expression(paste("Log Size (log cm"^2, ")")),
    sec.axis = sec_axis(~exp(.), name = expression(paste("Size (cm"^2, ")")),
                        breaks = c(10, 100, 1000, 10000))
  ) +
  labs(
    title = "B. ⚠️ CRITICAL: Size Ranges by Study",
    subtitle = "Studies sample DIFFERENT size ranges — slope comparisons are confounded",
    y = "Study"
  ) +
  theme_publication() +
  theme(axis.text.y = element_text(size = 8))

# ---- Panel C: Allometry by Study (with caveat) ----
allometry_by_study_plot <- ggplot(growth_clean, aes(x = log_size, y = log_final_size, color = study)) +
  geom_point(alpha = 0.15, size = 1) +
  geom_smooth(method = "lm", se = TRUE, linewidth = 1) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.6) +
  scale_color_viridis_d(option = "plasma", name = "Study") +
  labs(
    title = "C. Allometric Slopes by Study",
    subtitle = "⚠️ Different slopes may reflect SIZE RANGE, not true allometric differences",
    x = expression(paste("Log Initial Size (log cm"^2, ")")),
    y = expression(paste("Log Final Size (log cm"^2, ")"))
  ) +
  theme_publication() +
  theme(legend.position = "right",
        legend.text = element_text(size = 7))

# ---- Panel D: Natural vs Restored Allometry (with caveat) ----
allometry_nat_rest <- ggplot(growth_clean, aes(x = log_size, y = log_final_size, color = population_type)) +
  geom_point(alpha = 0.2, size = 1.5) +
  geom_smooth(method = "lm", se = TRUE, linewidth = 1.3) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.6) +
  scale_color_manual(values = c("Natural colony" = colors$ocean_deep,
                                "Restoration fragment" = colors$coral_warm),
                     name = "Population Type") +
  labs(
    title = "D. Natural vs Restored Allometry",
    subtitle = "⚠️ Natural colonies are LARGER — slope difference may be size confound",
    x = expression(paste("Log Initial Size (log cm"^2, ")")),
    y = expression(paste("Log Final Size (log cm"^2, ")"))
  ) +
  theme_publication() +
  theme(legend.position = c(0.15, 0.85),
        legend.background = element_rect(fill = "white", color = NA))

# ---- Panel E: Size Distribution by Study ----
size_dist_study <- ggplot(growth_clean, aes(x = log_size, fill = study)) +
  geom_histogram(bins = 30, alpha = 0.7, position = "identity") +
  facet_wrap(~study, scales = "free_y", ncol = 2) +
  scale_fill_viridis_d(option = "plasma") +
  labs(
    title = "E. Size Distribution by Study",
    subtitle = "NOAA surveys sample large natural colonies; restoration studies focus on small fragments",
    x = expression(paste("Log Initial Size (log cm"^2, ")")),
    y = "Count"
  ) +
  theme_publication() +
  theme(legend.position = "none",
        strip.text = element_text(size = 8))

# ---- Panel F: Initial Size vs Growth Rate (shows RGR pattern) ----
size_vs_growth <- ggplot(growth_clean, aes(x = log_size, y = rgr, color = study)) +
  geom_point(alpha = 0.2, size = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", color = colors$text_secondary) +
  geom_smooth(method = "gam", formula = y ~ s(x), se = FALSE, linewidth = 1) +
  scale_color_viridis_d(option = "plasma", name = "Study") +
  coord_cartesian(ylim = c(-1, 5)) +
  labs(
    title = "F. Relative Growth Rate by Study",
    subtitle = "RGR declines with size across all studies",
    x = expression(paste("Log Initial Size (log cm"^2, ")")),
    y = expression(paste("RGR (yr"^-1, ")"))
  ) +
  theme_publication() +
  theme(legend.position = "right",
        legend.text = element_text(size = 7))

# ---- Panel G: Growth Ratio (Final/Initial) by Size ----
growth_ratio_plot <- ggplot(growth_clean, aes(x = log_size, y = growth_ratio)) +
  geom_point(aes(color = study), alpha = 0.2, size = 1) +
  geom_hline(yintercept = 1, linetype = "dashed", color = colors$text_secondary) +
  geom_smooth(method = "gam", formula = y ~ s(x), se = TRUE, color = colors$coral_warm, linewidth = 1.2) +
  coord_cartesian(ylim = c(0, 5)) +
  scale_color_viridis_d(option = "plasma") +
  labs(
    title = "G. Size Ratio (Final/Initial) by Initial Size",
    subtitle = "Small colonies can more than double; large colonies show modest proportional growth",
    x = expression(paste("Log Initial Size (log cm"^2, ")")),
    y = "Final Size / Initial Size"
  ) +
  theme_publication() +
  theme(legend.position = "none")

# Combine allometry panels (updated layout with size range warning)
if (has_patchwork) {
  allometry_combined <- (allometry_scatter | size_range_plot) /
                        (allometry_by_study_plot | allometry_nat_rest) /
                        (size_dist_study | size_vs_growth) +
    plot_annotation(
      title = "Allometric Growth Analysis: Initial vs Final Size Relationships",
      subtitle = "⚠️ CRITICAL: Studies sample different size ranges — interpret slope differences with caution",
      caption = paste0("n = ", scales::comma(nrow(growth_clean)), " growth observations | ",
                       "Size = 2D planar area (L × W × % live) | ",
                       "ANCOVA tests detect differences BUT confounded by non-overlapping size ranges"),
      theme = theme(
        plot.title = element_text(size = 16, face = "bold", color = colors$ocean_deep),
        plot.subtitle = element_text(size = 12, face = "bold", color = colors$coral_warm),
        plot.caption = element_text(size = 9, color = colors$text_secondary, hjust = 0)
      )
    )

  ggsave(file.path(pub_fig_dir, "allometry_analysis.png"),
         allometry_combined, width = 16, height = 18, dpi = 300)
  cat("  ✓ Saved: publication/allometry_analysis.png\n")

  # Also save key individual panels
  ggsave(file.path(fig_dir_supp, "initial_vs_final_size.png"),
         allometry_scatter, width = 8, height = 7, dpi = 300)
  cat("  ✓ Saved: initial_vs_final_size.png\n")

  ggsave(file.path(fig_dir_supp, "size_range_by_study.png"),
         size_range_plot, width = 10, height = 6, dpi = 300)
  cat("  ✓ Saved: size_range_by_study.png\n")

  ggsave(file.path(fig_dir_supp, "allometry_by_study.png"),
         allometry_by_study_plot, width = 10, height = 7, dpi = 300)
  cat("  ✓ Saved: allometry_by_study.png\n")

  ggsave(file.path(fig_dir_supp, "allometry_natural_vs_restored.png"),
         allometry_nat_rest, width = 8, height = 7, dpi = 300)
  cat("  ✓ Saved: allometry_natural_vs_restored.png\n")

} else {
  ggsave(file.path(fig_dir_supp, "initial_vs_final_size.png"),
         allometry_scatter, width = 8, height = 7, dpi = 300)
  ggsave(file.path(fig_dir_supp, "size_range_by_study.png"),
         size_range_plot, width = 10, height = 6, dpi = 300)
  ggsave(file.path(fig_dir_supp, "allometry_by_study.png"),
         allometry_by_study_plot, width = 10, height = 7, dpi = 300)
  ggsave(file.path(fig_dir_supp, "allometry_natural_vs_restored.png"),
         allometry_nat_rest, width = 8, height = 7, dpi = 300)
  cat("  ✓ Saved allometry individual panels\n")
}

# =============================================================================
# 11. SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  GROWTH RATE ANALYSIS COMPLETE                                ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("KEY FINDINGS:\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat(sprintf("1. RGR apparent R² = %.1f%%, biological signal R² = %.1f%% (null = %.1f%%), AGR R² = %.1f%%\n",
            rgr_r2 * 100, biological_signal_r2 * 100, null_r2_median * 100, agr_r2 * 100))
cat(sprintf("2. RGR threshold: ~%.0f cm² (where relative growth rate changes most)\n",
            rgr_threshold$threshold_cm2))
cat(sprintf("3. Overall positive growth: %.1f%%\n", overall_stats$pct_positive))
cat(sprintf("4. Large adults (>2000 cm²): %.1f%% positive, mean AGR = %.0f cm²/yr\n",
            size_class_stats$pct_positive[size_class_stats$size_class == "SC5"],
            size_class_stats$agr_mean[size_class_stats$size_class == "SC5"]))
cat("\n")
cat("ALLOMETRIC NOTES:\n")
cat("  • Size measured as 2D planar area (L × W × % live)\n")
cat("  • Underestimates 3D tissue for large branching colonies\n")
cat("  • RGR partially corrects by normalizing growth to size\n")
cat("  • Use caution comparing absolute growth across size classes\n")
cat("\n")

cat("ADVANCED ANALYSIS SUMMARY:\n")
cat("─────────────────────────────────────────────────────────────────\n")

# Mixed-effects summary
if (exists("lmm_fixed_slope") && !is.na(lmm_fixed_slope)) {
  cat(sprintf("• Mixed-effects model: Overall slope = %.4f (accounting for study variation)\n",
              lmm_fixed_slope))
}

# Nonlinearity summary
if (exists("linear_aic") && exists("gam_aic")) {
  delta_aic <- linear_aic - gam_aic
  if (delta_aic > 10) {
    cat(sprintf("• Nonlinearity detected: GAM better by %.1f AIC units\n", delta_aic))
  } else {
    cat("• Log-linear relationship adequate (no strong nonlinearity)\n")
  }
}

# Within size-class summary
if (exists("within_sc_results") && length(within_sc_results) > 0) {
  sig_sc <- sum(sapply(within_sc_results, function(x) x$p_value < 0.05))
  cat(sprintf("• Within-size-class ANCOVA: %d/%d size classes show significant slope differences\n",
              sig_sc, length(within_sc_results)))
}

# Bootstrap summary
if (exists("boot_slope_results") && !is.null(boot_slope_results)) {
  cat(sprintf("• Bootstrap NOAA vs fragments: diff = %.4f, 95%% CI [%.4f, %.4f]\n",
              boot_slope_results$diff, boot_slope_results$ci[1], boot_slope_results$ci[2]))
}

# Size-matched comparison summary
if (exists("matched_comparison_results") && !is.null(matched_comparison_results)) {
  cat(sprintf("• Size-matched comparison: %d pairs, ANCOVA p = %.4f\n",
              matched_comparison_results$n_pairs,
              matched_comparison_results$ancova_p))
  if (!is.na(matched_comparison_results$ancova_p) && matched_comparison_results$ancova_p < 0.05) {
    cat("  → TRUE biological differences persist after size matching\n")
  } else {
    cat("  → Apparent differences may be driven by size confound\n")
  }
}

cat("\n")
cat("⚠️  SIZE RANGE CONFOUND WARNING:\n")
cat("  Studies sample different size ranges — interpret slope comparisons with caution.\n")
cat("  Use restricted analyses (overlapping sizes) for valid between-study comparisons.\n")
cat("\n")
cat("Next step: Run 05_variance_partitioning.R\n\n")
