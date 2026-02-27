################################################################################
# 09_power_analysis.R - Sample Size Recommendations for Future Studies
################################################################################
#
# PURPOSE:
#   Calculate statistical power for various study designs and provide
#   recommendations for sample sizes in under-studied size classes and regions.
#
# METHODS:
#   - Simulation-based power analysis for survival detection
#   - GLM power estimation (conservative) using observed variance components
#   - Sample size curves for different effect sizes
#   - Gap-prioritized recommendations
#
# OUTPUTS:
#   - power_curves.csv: Power by sample size for different scenarios
#   - sample_size_recommendations.csv: Recommended N per size/region
#   - power_analysis_summary.csv: Overall power statistics
#   - supplementary/exploratory/power_curves.png
#
# IMPORTANT CAVEAT (Hoenig & Heisey 2001):
#   Post-hoc (observed) power analysis is uninformative for interpreting
#   results of completed studies. This script provides PROSPECTIVE sample
#   size recommendations for future study design only.
#   Ref: Hoenig JM, Heisey DM (2001) The abuse of power. Am Stat 55(1):19-24
#
# Author: Detmer & Stier Lab
# Date: 2025-12-25
################################################################################

library(dplyr)
library(tidyr)
library(ggplot2)

# Source shared utilities for constants and helper functions
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("analysis/scripts/utils/shared_utilities.R")) {
  source("analysis/scripts/utils/shared_utilities.R")
}

dirs <- setup_output_dirs()
output_dir <- dirs$output
fig_explore_dir <- file.path(dirs$figures_supp, "exploratory")
dir.create(fig_explore_dir, showWarnings = FALSE, recursive = TRUE)

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  09: SAMPLE SIZE RECOMMENDATIONS FOR FUTURE STUDIES          ║\n")
cat("║  Prospective Power Analysis for Under-Studied Groups         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("=" , rep("=", 68), "\n", sep = "")
cat("  SAMPLE SIZE RECOMMENDATIONS FOR FUTURE STUDIES\n")
cat("=" , rep("=", 68), "\n\n", sep = "")
cat("IMPORTANT (Hoenig & Heisey 2001):\n")
cat("  Post-hoc power is uninformative for interpreting current results.\n")
cat("  These calculations use OBSERVED variance components as planning values\n")
cat("  for FUTURE study design, not to evaluate the current dataset.\n\n")

# =============================================================================
# SETUP
# =============================================================================

# Load prepared data
cat("Loading prepared data and variance estimates...\n")
survival_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))

# Define size classes
survival_data <- survival_data %>%
  mutate(
    size_class = case_when(
      size_cm2 <= 25 ~ "SC1",
      size_cm2 <= 100 ~ "SC2",
      size_cm2 <= 500 ~ "SC3",
      size_cm2 <= 2000 ~ "SC4",
      TRUE ~ "SC5"
    ),
    size_class = factor(size_class, levels = c("SC1", "SC2",
                                                "SC3", "SC4",
                                                "SC5"))
  )

# =============================================================================
# ESTIMATE VARIANCE COMPONENTS FROM DATA
# =============================================================================

cat("\nEstimating variance components from observed data...\n")

# Get observed survival rates and variance by size class
size_stats <- survival_data %>%
  group_by(size_class) %>%
  summarise(
    n_obs = n(),
    mean_survival = mean(survived, na.rm = TRUE),
    var_survival = var(survived, na.rm = TRUE),
    se_survival = sd(survived, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>%
  mutate(
    # Use observed variance for power calculations
    # For binomial, theoretical variance = p(1-p)/n
    theoretical_var = mean_survival * (1 - mean_survival),
    # Overdispersion ratio: values > 1 indicate clustering effects
    # ICC computed below is used to adjust power via design effect (DEFF)
    overdispersion = var_survival / (mean_survival * (1 - mean_survival))
  )

cat("\nObserved variance by size class:\n")
print(size_stats)

# Get variance by region
region_stats <- survival_data %>%
  group_by(region) %>%
  summarise(
    n_obs = n(),
    mean_survival = mean(survived, na.rm = TRUE),
    var_survival = var(survived, na.rm = TRUE),
    .groups = "drop"
  )

# Estimate between-study variance using DerSimonian-Laird moment estimator
study_stats <- survival_data %>%
  group_by(study) %>%
  summarise(
    n_obs = n(),
    mean_survival = mean(survived, na.rm = TRUE),
    .groups = "drop"
  )

# Correct tau² estimation (DerSimonian-Laird moment estimator)
# Within-study variance for each study (binomial): var_i = p_i*(1-p_i)/n_i
study_stats <- study_stats %>%
  mutate(
    within_var = mean_survival * (1 - mean_survival) / n_obs
  )

# DerSimonian-Laird: Q-based estimator
k <- nrow(study_stats)
# Apply continuity correction for studies with 0% or 100% survival
# (avoids Inf weights from zero within-study variance)
study_stats$within_var <- pmax(study_stats$within_var, 0.25 / study_stats$n_obs)
w <- 1 / study_stats$within_var  # inverse-variance weights
mu_hat <- sum(w * study_stats$mean_survival) / sum(w)
Q <- sum(w * (study_stats$mean_survival - mu_hat)^2)
C <- sum(w) - sum(w^2) / sum(w)
tau_sq <- max(0, (Q - (k - 1)) / C)

cat(sprintf("\nVariance components (DerSimonian-Laird estimator):\n"))
cat(sprintf("  Between-study heterogeneity (tau²): %.6f\n", tau_sq))
cat(sprintf("  Previous (total variance) estimate: %.6f\n", var(study_stats$mean_survival, na.rm = TRUE)))
cat(sprintf("  Difference shows within-study variance was: %.6f\n",
    var(study_stats$mean_survival, na.rm = TRUE) - tau_sq))

# ICC = tau² / (tau² + within_study_variance)
mean_within_var <- mean(study_stats$within_var, na.rm = TRUE)
icc_survival <- tau_sq / (tau_sq + mean_within_var)
mean_cluster_size <- mean(study_stats$n_obs)
cat(sprintf("  Mean within-study variance: %.6f\n", mean_within_var))
cat(sprintf("  Intraclass correlation (ICC): %.3f\n", icc_survival))
cat(sprintf("  Typical cluster size: %.0f\n", mean_cluster_size))
deff_observed <- 1 + (mean_cluster_size - 1) * icc_survival
cat(sprintf("  Design effect (DEFF): %.2f\n", deff_observed))
cat("NOTE: Design effect incorporated into power calculations.\n")

# Save variance components
power_variance_components <- data.frame(
  component = c("tau_sq", "mean_within_var", "icc", "deff", "mean_cluster_size", "k_studies"),
  value = c(tau_sq, mean_within_var, icc_survival, deff_observed, mean_cluster_size, k)
)
write.csv(power_variance_components, file.path(output_dir, "power_variance_components.csv"), row.names = FALSE)
cat("  Saved: power_variance_components.csv\n")

# Save baseline parameters
baseline_survival_rate <- mean(survival_data$survived, na.rm = TRUE)
power_parameters <- data.frame(
  baseline_survival = baseline_survival_rate,
  alpha = 0.05,
  icc = icc_survival,
  deff = deff_observed,
  tau_sq = tau_sq,
  n_studies = k
)
write.csv(power_parameters, file.path(output_dir, "power_parameters.csv"), row.names = FALSE)
cat("  Saved: power_parameters.csv\n")

# =============================================================================
# POWER CALCULATION FUNCTIONS
# =============================================================================

#' Calculate power for detecting survival difference from baseline
#' Using normal approximation to binomial with design effect for clustered data
calc_power_binomial <- function(n, p1, p2, alpha = 0.05,
                                 icc = 0, cluster_size = 1) {
  # Design effect for clustered data
  if (is.na(icc) || is.nan(icc)) icc <- 0
  deff <- 1 + (cluster_size - 1) * icc
  n_effective <- n / deff

  if (n_effective <= 0 || is.na(n_effective) || is.nan(n_effective)) return(NA_real_)

  # Two-sample test for proportions
  p_pooled <- (p1 + p2) / 2
  se <- sqrt(2 * p_pooled * (1 - p_pooled) / n_effective)

  if (is.na(se) || is.nan(se) || se == 0) return(1)

  z_alpha <- qnorm(1 - alpha/2)
  z <- abs(p1 - p2) / se

  power <- 1 - pnorm(z_alpha - z) + pnorm(-z_alpha - z)
  return(power)
}

#' Calculate sample size for desired power (adjusted for clustering)
calc_sample_size <- function(p1, p2, power = 0.80, alpha = 0.05,
                              icc = 0, cluster_size = 1) {
  if (p1 == p2) return(Inf)

  z_alpha <- qnorm(1 - alpha/2)
  z_beta <- qnorm(power)

  p_pooled <- (p1 + p2) / 2

  # Base sample size (unadjusted)
  n_base <- 2 * (z_alpha + z_beta)^2 * p_pooled * (1 - p_pooled) / (p1 - p2)^2

  # Apply design effect for clustered data
  deff <- 1 + (cluster_size - 1) * icc
  n <- n_base * deff

  return(ceiling(n))
}

# NOTE: This simulation uses GLM (fixed effects only), not GLMM (mixed effects).
# Power estimates are CONSERVATIVE for hierarchical designs: a true GLMM would
# have more power by borrowing strength across groups, but would be computationally
# expensive for simulation (500+ glmer fits with convergence issues).
# Results are labeled "GLM power (conservative)" to avoid confusion.
#' Simulation-based power for GLM (conservative; see note above)
simulate_power_glm <- function(n_per_group, n_groups, effect_size,
                                 baseline_p = 0.75, tau_sq = 0.01,
                                 n_sims = 500, alpha = 0.05) {

  sig_count <- 0

  for (i in 1:n_sims) {
    # Generate random group effects
    group_effects <- rnorm(n_groups, 0, sqrt(tau_sq))

    # Generate data for control and treatment
    control_data <- data.frame(
      group = rep(1:n_groups, each = n_per_group),
      treatment = 0
    )
    control_data$prob <- plogis(qlogis(baseline_p) + group_effects[control_data$group])
    control_data$y <- rbinom(nrow(control_data), 1, control_data$prob)

    treatment_p <- baseline_p + effect_size
    treatment_data <- data.frame(
      group = rep(1:n_groups, each = n_per_group),
      treatment = 1
    )
    treatment_data$prob <- plogis(qlogis(treatment_p) + group_effects[treatment_data$group])
    treatment_data$y <- rbinom(nrow(treatment_data), 1, treatment_data$prob)

    all_data <- rbind(control_data, treatment_data)

    # Simple test (for speed - real analysis would use lme4)
    model <- suppressWarnings(glm(y ~ treatment, data = all_data, family = binomial))
    p_val <- tryCatch({
      summary(model)$coefficients["treatment", "Pr(>|z|)"]
    }, error = function(e) 1)

    if (p_val < alpha) sig_count <- sig_count + 1
  }

  return(sig_count / n_sims)
}

# =============================================================================
# GENERATE POWER CURVES
# =============================================================================

cat("\nGenerating power curves for different scenarios...\n")

# Define scenarios
sample_sizes <- c(10, 20, 30, 50, 75, 100, 150, 200, 300, 500)
effect_sizes <- c(0.05, 0.10, 0.15, 0.20)  # Difference in survival probability
# Use the overall pooled survival estimate computed from data (baseline_survival_rate,
# ~line 161). Fall back to 0.75 if unavailable for any reason.
baseline_survival <- if (exists("baseline_survival_rate") && !is.na(baseline_survival_rate)) {
  baseline_survival_rate
} else {
  0.75  # approximate overall pooled estimate across all studies
}

power_curves <- expand.grid(
  n = sample_sizes,
  effect_size = effect_sizes
) %>%
  rowwise() %>%
  mutate(
    p1 = baseline_survival,
    p2 = min(baseline_survival + effect_size, 0.999),
    power = calc_power_binomial(n, p1, p2, icc = icc_survival,
                                 cluster_size = mean_cluster_size)
  ) %>%
  ungroup()

cat("  ✓ Basic power curves calculated\n")

# =============================================================================
# SAMPLE SIZE RECOMMENDATIONS BY SIZE CLASS
# =============================================================================

cat("\nCalculating sample size recommendations by size class...\n")

# Current sample sizes and survival rates
current_n <- survival_data %>%
  group_by(size_class) %>%
  summarise(
    current_n = n(),
    current_survival = mean(survived, na.rm = TRUE),
    .groups = "drop"
  )

# Calculate recommended N to achieve 80% power for detecting 10% difference
size_recommendations <- current_n %>%
  mutate(
    # Recommended N for 10% difference detection (adjusted for clustering)
    recommended_n_10pct = sapply(current_survival, function(p) {
      calc_sample_size(p, pmin(0.99, p + 0.10), power = 0.80,
                        icc = icc_survival, cluster_size = mean_cluster_size)
    }),
    # Recommended N for 15% difference detection (adjusted for clustering)
    recommended_n_15pct = sapply(current_survival, function(p) {
      calc_sample_size(p, pmin(0.99, p + 0.15), power = 0.80,
                        icc = icc_survival, cluster_size = mean_cluster_size)
    }),
    # Current power to detect 10% difference (adjusted for clustering)
    current_power_10pct = mapply(function(n, p) {
      calc_power_binomial(n, p, pmin(0.99, p + 0.10),
                           icc = icc_survival, cluster_size = mean_cluster_size)
    }, current_n, current_survival),
    # Gap (additional samples needed)
    gap_10pct = pmax(0, recommended_n_10pct - current_n),
    gap_15pct = pmax(0, recommended_n_15pct - current_n),
    # Priority score (higher = more urgent)
    priority_score = gap_10pct / (current_n + 1)
  ) %>%
  arrange(desc(priority_score))

cat("\nSample size recommendations by size class:\n")
print(size_recommendations)

# =============================================================================
# SAMPLE SIZE RECOMMENDATIONS BY REGION
# =============================================================================

cat("\nCalculating sample size recommendations by region...\n")

region_n <- survival_data %>%
  group_by(region) %>%
  summarise(
    current_n = n(),
    current_survival = mean(survived, na.rm = TRUE),
    .groups = "drop"
  )

region_recommendations <- region_n %>%
  mutate(
    recommended_n_10pct = sapply(current_survival, function(p) {
      if (is.na(p) || p <= 0 || p >= 1) return(NA)
      calc_sample_size(p, pmin(0.99, p + 0.10), power = 0.80,
                        icc = icc_survival, cluster_size = mean_cluster_size)
    }),
    current_power_10pct = mapply(function(n, p) {
      if (is.na(p) || p <= 0 || p >= 1) return(NA)
      calc_power_binomial(n, p, pmin(0.99, p + 0.10),
                           icc = icc_survival, cluster_size = mean_cluster_size)
    }, current_n, current_survival),
    gap_10pct = pmax(0, recommended_n_10pct - current_n, na.rm = TRUE),
    priority_score = gap_10pct / (current_n + 1)
  ) %>%
  arrange(desc(priority_score))

cat("\nSample size recommendations by region:\n")
print(region_recommendations)

# =============================================================================
# SIZE x REGION COMBINED RECOMMENDATIONS
# =============================================================================

cat("\nCalculating combined size × region recommendations...\n")

size_region_n <- survival_data %>%
  group_by(size_class, region) %>%
  summarise(
    current_n = n(),
    current_survival = mean(survived, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(!is.na(current_survival), current_survival > 0, current_survival < 1)

combined_recommendations <- size_region_n %>%
  mutate(
    recommended_n_10pct = sapply(current_survival, function(p) {
      calc_sample_size(p, pmin(0.99, p + 0.10), power = 0.80,
                        icc = icc_survival, cluster_size = mean_cluster_size)
    }),
    current_power = mapply(function(n, p) {
      calc_power_binomial(n, p, pmin(0.99, p + 0.10),
                           icc = icc_survival, cluster_size = mean_cluster_size)
    }, current_n, current_survival),
    gap = pmax(0, recommended_n_10pct - current_n),
    priority = case_when(
      gap > 200 ~ "HIGH",
      gap > 100 ~ "MEDIUM",
      gap > 0 ~ "LOW",
      TRUE ~ "ADEQUATE"
    )
  ) %>%
  arrange(desc(gap))

cat("\nTop 10 priority gaps (size × region):\n")
print(head(combined_recommendations, 10))

# =============================================================================
# SIMULATION-BASED POWER FOR GLM (CONSERVATIVE)
# =============================================================================

cat("\nRunning simulation-based GLM power analysis (conservative) for hierarchical designs...\n")

# Test power for detecting effect with hierarchical structure
glm_scenarios <- expand.grid(
  n_per_site = c(10, 20, 50),
  n_sites = c(3, 5, 10),
  effect_size = c(0.10, 0.15)
)

glm_power <- glm_scenarios %>%
  rowwise() %>%
  mutate(
    total_n = n_per_site * n_sites * 2,  # Two groups
    power = simulate_power_glm(
      n_per_group = n_per_site,
      n_groups = n_sites,
      effect_size = effect_size,
      baseline_p = baseline_survival,
      tau_sq = tau_sq,
      n_sims = 1000  # Increased from 200 for stable power estimates (MC SE < 1.5% at 80% power)
    )
  ) %>%
  ungroup()

cat("\nGLM power (conservative) by study design:\n")
print(glm_power)

# =============================================================================
# SAVE OUTPUTS
# =============================================================================

cat("\nSaving power analysis outputs...\n")

# Power curves
write.csv(power_curves, file.path(output_dir, "power_curves.csv"), row.names = FALSE)
cat("  ✓ Saved: power_curves.csv\n")

# Size recommendations
write.csv(size_recommendations, file.path(output_dir, "sample_size_by_size_class.csv"), row.names = FALSE)
cat("  ✓ Saved: sample_size_by_size_class.csv\n")

# Region recommendations
write.csv(region_recommendations, file.path(output_dir, "sample_size_by_region.csv"), row.names = FALSE)
cat("  ✓ Saved: sample_size_by_region.csv\n")

# Combined recommendations
write.csv(combined_recommendations, file.path(output_dir, "sample_size_recommendations.csv"), row.names = FALSE)
cat("  ✓ Saved: sample_size_recommendations.csv\n")

# GLM power (conservative)
write.csv(glm_power, file.path(output_dir, "glm_power_scenarios.csv"), row.names = FALSE)
cat("  ✓ Saved: glm_power_scenarios.csv\n")

# =============================================================================
# GROWTH SAMPLE SIZE RECOMMENDATIONS
# =============================================================================
cat("\n\n=== GROWTH OUTCOME SAMPLE SIZE RECOMMENDATIONS ===\n")

# Extract growth variance components
growth_data <- tryCatch(readRDS(file.path(output_dir, "prepared_growth_data.rds")), error = function(e) NULL)

if (!is.null(growth_data)) {
  growth_var <- var(growth_data$growth_cm2_yr, na.rm = TRUE)
  cat(sprintf("  Growth variance: %.2f\n", growth_var))

  # Estimate growth DEFF from between-study heterogeneity
  # Check if 'study' column exists in growth data
  if ("study" %in% names(growth_data)) {
    growth_study_stats <- growth_data %>%
      group_by(study) %>%
      summarise(
        n_obs = n(),
        mean_growth = mean(growth_cm2_yr, na.rm = TRUE),
        within_var = var(growth_cm2_yr, na.rm = TRUE) / n(),
        .groups = "drop"
      ) %>%
      filter(!is.na(within_var), within_var > 0)

    k_growth <- nrow(growth_study_stats)
    if (k_growth >= 2) {
      w_growth <- 1 / growth_study_stats$within_var
      mu_hat_growth <- sum(w_growth * growth_study_stats$mean_growth) / sum(w_growth)
      Q_growth <- sum(w_growth * (growth_study_stats$mean_growth - mu_hat_growth)^2)
      C_growth <- sum(w_growth) - sum(w_growth^2) / sum(w_growth)
      tau_sq_growth <- max(0, (Q_growth - (k_growth - 1)) / C_growth)

      mean_within_var_growth <- mean(growth_study_stats$within_var, na.rm = TRUE)
      icc_growth <- tau_sq_growth / (tau_sq_growth + mean_within_var_growth)
      mean_cluster_size_growth <- mean(growth_study_stats$n_obs)
      deff_growth <- 1 + (mean_cluster_size_growth - 1) * icc_growth

      cat(sprintf("  Growth tau² (DerSimonian-Laird): %.4f\n", tau_sq_growth))
      cat(sprintf("  Growth ICC: %.3f\n", icc_growth))
      cat(sprintf("  Growth DEFF: %.2f\n", deff_growth))
    } else {
      deff_growth <- 1
      cat("  Only 1 growth study — DEFF set to 1 (no clustering adjustment)\n")
    }
  } else {
    deff_growth <- 1
    cat("  No 'study' column in growth data — DEFF set to 1\n")
  }

  # Power for detecting growth rate differences (two-sample t-test framework)
  calc_power_continuous <- function(n_per_group, effect_size_d, alpha = 0.05, deff = 1) {
    n_eff <- n_per_group / deff
    se <- sqrt(2 / n_eff)
    z_alpha <- qnorm(1 - alpha/2)
    z_stat <- effect_size_d / se
    power <- pnorm(z_stat - z_alpha) + pnorm(-z_stat - z_alpha)
    return(power)
  }

  # Cohen's d values from 0.1 to 1.0
  effect_sizes_d <- seq(0.1, 1.0, by = 0.1)
  growth_sample_sizes <- c(10, 20, 50, 100, 200, 500)

  growth_power_grid <- expand.grid(n = growth_sample_sizes, d = effect_sizes_d)
  growth_power_grid$power <- mapply(calc_power_continuous,
                                     growth_power_grid$n, growth_power_grid$d,
                                     MoreArgs = list(deff = deff_growth))

  cat("Growth power analysis (sample sizes needed per group for 80% power, DEFF-adjusted):\n")
  for (d in c(0.2, 0.5, 0.8)) {
    n_needed <- ceiling(2 * ((qnorm(0.975) + qnorm(0.8)) / d)^2 * deff_growth)
    cat(sprintf("  Cohen's d = %.1f: n = %d per group (DEFF = %.2f)\n", d, n_needed, deff_growth))
  }

  write.csv(growth_power_grid, file.path(output_dir, "growth_power_analysis.csv"), row.names = FALSE)
  cat("  Saved: growth_power_analysis.csv\n")
} else {
  cat("  Growth data not available. Skipping growth power analysis.\n")
}

# =============================================================================
# CREATE VISUALIZATIONS
# =============================================================================

cat("\nCreating power analysis visualizations...\n")

# Power curves plot
p1 <- ggplot(power_curves, aes(x = n, y = power, color = factor(effect_size))) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2) +
  geom_hline(yintercept = 0.80, linetype = "dashed", color = "gray40") +
  annotate("text", x = 50, y = 0.82, label = "80% power threshold",
           hjust = 0, size = 3, color = "gray40") +
  scale_x_log10(breaks = c(10, 30, 100, 300)) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
  scale_color_viridis_d(name = "Effect Size\n(Δ survival)",
                        labels = c("5%", "10%", "15%", "20%")) +
  labs(
    title = "Statistical Power by Sample Size",
    subtitle = sprintf("Power to detect survival differences from baseline (%.0f%%)", baseline_survival * 100),
    x = "Sample Size (per group)",
    y = "Statistical Power"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold")
  )

ggsave(file.path(fig_explore_dir, "power_curves.png"), p1,
       width = 8, height = 6, dpi = 150)
cat("  ✓ Saved: power_curves.png\n")

# Sample size gap by size class
p2 <- size_recommendations %>%
  pivot_longer(cols = c(current_n, recommended_n_10pct),
               names_to = "type", values_to = "n") %>%
  mutate(type = ifelse(type == "current_n", "Current", "Recommended (10% effect)")) %>%
  ggplot(aes(x = size_class, y = n, fill = type)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_y_log10() +
  scale_fill_manual(values = c("Current" = "#4A90D9", "Recommended (10% effect)" = "#E74C3C")) +
  labs(
    title = "Current vs Recommended Sample Sizes by Size Class",
    subtitle = "Recommended N for 80% power to detect 10% survival difference",
    x = "Size Class",
    y = "Sample Size (log scale)",
    fill = ""
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom",
    plot.title = element_text(face = "bold")
  )

ggsave(file.path(fig_explore_dir, "sample_size_gaps.png"), p2,
       width = 8, height = 6, dpi = 150)
cat("  ✓ Saved: sample_size_gaps.png\n")

# =============================================================================
# SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  SAMPLE SIZE RECOMMENDATIONS COMPLETE                         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("KEY FINDINGS:\n")
cat("─────────────────────────────────────────────────────────────────\n")

# Most underpowered size class
most_underpowered <- size_recommendations %>%
  filter(priority_score == max(priority_score, na.rm = TRUE))

cat(sprintf("  Most underpowered size class: %s\n", most_underpowered$size_class[1]))
cat(sprintf("    Current N: %d, Recommended N: %d, Gap: %d\n",
            most_underpowered$current_n[1],
            most_underpowered$recommended_n_10pct[1],
            most_underpowered$gap_10pct[1]))
cat(sprintf("    Current power: %.1f%%\n", most_underpowered$current_power_10pct[1] * 100))

# Most underpowered region
most_underpowered_region <- region_recommendations %>%
  filter(!is.na(priority_score)) %>%
  filter(priority_score == max(priority_score, na.rm = TRUE))

if (nrow(most_underpowered_region) > 0) {
  cat(sprintf("\n  Most underpowered region: %s\n", most_underpowered_region$region[1]))
  cat(sprintf("    Current N: %d, Gap: %d\n",
              most_underpowered_region$current_n[1],
              most_underpowered_region$gap_10pct[1]))
}

cat("\nRECOMMENDATIONS:\n")
cat("─────────────────────────────────────────────────────────────────\n")

# Minimum sample sizes
cat("  Minimum sample sizes for 80% power:\n")
cat("    • Detect 10% difference: ~", round(median(size_recommendations$recommended_n_10pct, na.rm = TRUE)), " per group\n")
cat("    • Detect 15% difference: ~", round(median(size_recommendations$recommended_n_15pct, na.rm = TRUE)), " per group\n")

# GLM (conservative) recommendations
adequate_glm <- glm_power %>% filter(power >= 0.80)
if (nrow(adequate_glm) > 0) {
  min_design <- adequate_glm %>% filter(total_n == min(total_n))
  cat(sprintf("\n  Minimum hierarchical design for 80%% power:\n"))
  cat(sprintf("    • %d colonies per site × %d sites = %d total\n",
              min_design$n_per_site[1], min_design$n_sites[1], min_design$total_n[1]))
}

cat("\n  Priority sampling targets:\n")
high_priority <- combined_recommendations %>% filter(priority == "HIGH") %>% head(5)
for (i in 1:min(5, nrow(high_priority))) {
  cat(sprintf("    %d. %s × %s (need %d more)\n",
              i, high_priority$size_class[i], high_priority$region[i], high_priority$gap[i]))
}

cat("\nOutputs:\n")
cat("  - power_curves.csv (power by sample size)\n")
cat("  - sample_size_by_size_class.csv (recommendations by size)\n")
cat("  - sample_size_by_region.csv (recommendations by region)\n")
cat("  - sample_size_recommendations.csv (combined size × region)\n")
cat("  - glm_power_scenarios.csv (hierarchical design power, conservative)\n")
cat("  - power_curves.png (visualization)\n")
cat("  - sample_size_gaps.png (gap visualization)\n")
