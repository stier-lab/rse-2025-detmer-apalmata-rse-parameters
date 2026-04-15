#!/usr/bin/env Rscript
################################################################################
# 14_META_ANALYSIS.R
# A. palmata Demographic Analysis - Comprehensive Meta-Analysis
# VERSION 2.1 - Stratified by Population Type (Natural vs Restoration)
################################################################################
#
# PURPOSE: Conduct formal random-effects meta-analysis with publication-quality
#          figures for the A. palmata survival data synthesis.
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds (individual-level survival data)
#
# OUTPUTS:
#   - 06_analysis/output/meta_analysis_study_effects.csv (study-level effect sizes)
#   - 06_analysis/output/meta_analysis_results.csv (pooled estimates and heterogeneity)
#   - 06_analysis/figures/supplementary/meta_analysis/*.png (forest, funnel, etc.)
#
# KEY STRATIFICATION FINDING:
#   - Overall I² = 97.8% (CONSIDERABLE heterogeneity)
#   - Fragment percentage explains most heterogeneity
#   - Stratified: Natural colonies k=1 (I² not computable), Fragments I² = 86.5%
#   - Primary analysis now uses NATURAL COLONIES only
#
# CONTENTS:
#   1. Study-level effect size calculation (stratified by population type)
#   2. Random-effects meta-analysis (DerSimonian-Laird)
#   3. Forest plot (publication quality - stratified)
#   4. Funnel plot with contour enhancement
#   5. Heterogeneity decomposition by moderators
#   6. Sensitivity analyses (leave-one-out, cumulative)
#   7. Subgroup meta-analyses (by region, size class)
#   8. Meta-regression (with population type as key moderator)
#   9. STRATIFIED META-ANALYSIS (natural colonies vs fragments)
#
# Author: Detmer & Stier Lab
# Date: 2025-12-25 (Updated with stratification)
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
library(metafor)

set.seed(42)

cat("\n")
cat("==============================================================================\n")
cat("  19: FORMAL META-ANALYSIS OF A. PALMATA SURVIVAL\n")
cat("==============================================================================\n\n")

# Paths
dirs <- setup_output_dirs()
output_dir <- dirs$output
fig_dir <- file.path(dirs$figures_supp, "meta_analysis")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
supp_dir <- fig_dir

# Load data
surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))

cat(sprintf("Loaded %d survival observations from %d studies\n\n",
            nrow(surv_data), n_distinct(surv_data$study)))

# ==============================================================================
# SECTION 1: STUDY-LEVEL EFFECT SIZE CALCULATION
# ==============================================================================

cat("SECTION 1: Calculating Study-Level Effect Sizes\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Ensure population_type column exists
if (!"population_type" %in% names(surv_data)) {
  surv_data <- surv_data %>%
    mutate(
      is_fragment = (fragment == "Y"),
      population_type = ifelse(is_fragment, "Restoration fragment", "Natural colony")
    )
}

# Calculate study-level statistics WITH population type
study_stats <- surv_data %>%
  group_by(study) %>%
  summarise(
    region = first(region),
    n = n(),
    n_survived = sum(survived),
    n_died = n - n_survived,
    survival_rate = mean(survived),
    mean_size_cm2 = mean(size_cm2, na.rm = TRUE),
    median_size_cm2 = median(size_cm2, na.rm = TRUE),
    size_range = paste0(round(min(size_cm2, na.rm = TRUE)), "-",
                        round(max(size_cm2, na.rm = TRUE))),
    pct_fragment = mean(fragment == "Y", na.rm = TRUE) * 100,
    # Classify study by dominant population type (>50% threshold)
    population_type = ifelse(mean(fragment == "Y", na.rm = TRUE) > 0.5,
                             "Restoration fragment", "Natural colony"),
    year_start = min(survey_yr, na.rm = TRUE),
    year_end = max(survey_yr, na.rm = TRUE),
    n_years = n_distinct(survey_yr),
    .groups = "drop"
  ) %>%
  # Filter for valid meta-analysis inclusion
  filter(n >= 10, n_survived > 0, n_died > 0)

# Population type summary
pop_type_summary <- study_stats %>%
  group_by(population_type) %>%
  summarise(
    n_studies = n(),
    total_n = sum(n),
    mean_survival = mean(survival_rate),
    .groups = "drop"
  )

cat("Population type distribution among studies:\n")
print(pop_type_summary)
cat("\n")

# Compute effect sizes using metafor::escalc for standardized handling
study_effects <- study_stats %>%
  mutate(n_total = n)

study_effects <- escalc(measure = "PLO",  # Proportional log-odds
                        xi = study_effects$n_survived,
                        ni = study_effects$n_total,
                        data = study_effects,
                        add = 0.5, to = "only0")  # Haldane correction for zero cells
# escalc adds 'yi' (log odds) and 'vi' (variance) columns

# Add derived columns for downstream use
study_effects <- study_effects %>%
  mutate(
    # Aliases for readability (yi and vi are the canonical metafor names)
    log_odds = as.numeric(yi),
    var_log_odds = as.numeric(vi),
    se_log_odds = sqrt(var_log_odds),

    # 95% CI on log scale
    log_odds_lower = log_odds - 1.96 * se_log_odds,
    log_odds_upper = log_odds + 1.96 * se_log_odds,

    # Convert to probability scale
    surv_lower = plogis(log_odds_lower),
    surv_upper = plogis(log_odds_upper),

    # Inverse variance weight (fixed effects)
    weight_fe = 1 / var_log_odds
  )

k <- nrow(study_effects)
cat(sprintf("\n=== META-ANALYSIS WITH k = %d STUDIES ===\n", k))
if (k < 10) {
  cat("WARNING: k < 10 studies. The following limitations apply:\n")
  cat("  - Meta-regression results are exploratory only (need k >= 10 per moderator)\n")
  cat("  - Egger's test has negligible power for publication bias detection\n")
  cat("  - Subgroup analyses are descriptive, not inferential\n")
  cat("  - I-squared CI will be very wide\n")
  cat("  - Prediction intervals are more informative than confidence intervals\n\n")
}
cat(sprintf("  %d studies included in meta-analysis\n", nrow(study_effects)))
cat(sprintf("  Total N = %d observations\n", sum(study_effects$n)))
cat(sprintf("  Survival rates range: %.1f%% - %.1f%%\n\n",
            min(study_effects$survival_rate) * 100,
            max(study_effects$survival_rate) * 100))

# ==============================================================================
# SECTION 2: RANDOM-EFFECTS META-ANALYSIS
# ==============================================================================

cat("SECTION 2: Random-Effects Meta-Analysis\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# =============================================================================
# PRIMARY: Validated meta-analysis using metafor package
# =============================================================================

# DerSimonian-Laird estimator
rma_DL <- rma(yi = study_effects$log_odds,
              vi = study_effects$var_log_odds,
              method = "DL", test = "knha")

# REML estimator (preferred)
# Knapp-Hartung adjustment for small k - uses t-distribution instead of z
rma_REML <- rma(yi = study_effects$log_odds,
                vi = study_effects$var_log_odds,
                method = "REML", test = "knha")

# Extract validated statistics
tau_sq <- rma_REML$tau2
tau <- sqrt(tau_sq)
I_sq <- rma_REML$I2
Q <- rma_REML$QE
df_Q <- nrow(study_effects) - 1
p_Q <- rma_REML$QEp
pooled_log_odds <- as.numeric(rma_REML$beta)
pooled_se <- rma_REML$se
theta_re <- pooled_log_odds
se_theta_re <- pooled_se
estimation_method <- "REML"

# I-squared confidence interval (Q-profile method, Higgins & Thompson 2002)
rma_ci <- confint(rma_REML)
I_sq_lower <- rma_ci$random["I^2(%)", "ci.lb"]
I_sq_upper <- rma_ci$random["I^2(%)", "ci.ub"]

# Prediction interval (proper t-distribution)
rma_pred <- predict(rma_REML)
pi_lower <- rma_pred$pi.lb
pi_upper <- rma_pred$pi.ub

# Also store DL estimates for comparison
tau_sq_DL <- rma_DL$tau2
tau_DL <- sqrt(tau_sq_DL)
tau_sq_REML <- rma_REML$tau2
tau_REML <- sqrt(tau_sq_REML)

tau_sq_comparison <- data.frame(
  method = c("DerSimonian-Laird", "REML"),
  tau_squared = c(tau_sq_DL, tau_sq_REML),
  tau = c(tau_DL, tau_REML)
)

cat(sprintf("  Cochran's Q = %.2f (df = %d, p = %.4f)\n", Q, df_Q, p_Q))
cat(sprintf("  tau² (DL) = %.4f (between-study variance)\n", tau_sq_DL))
cat(sprintf("  tau (DL) = %.4f (SD of true effects)\n", tau_DL))
cat(sprintf("  tau² (REML) = %.4f\n", tau_sq_REML))
cat(sprintf("  tau (REML) = %.4f\n", tau_REML))

tau_diff_pct <- abs(tau_sq_REML - tau_sq_DL) / max(tau_sq_DL, 1e-10) * 100
cat(sprintf("\n  DL vs REML difference: %.1f%%\n", tau_diff_pct))
cat("  Using metafor REML estimate as primary.\n")

# Save DL vs REML comparison
write_csv(tau_sq_comparison, file.path(output_dir, "meta_analysis_tau_comparison.csv"))
cat("  Saved: meta_analysis_tau_comparison.csv\n")

H_sq <- Q / df_Q  # H² statistic

I_sq_interp <- case_when(
  is.na(I_sq) ~ "N/A",
  I_sq < 25 ~ "Low",
  I_sq < 50 ~ "Moderate",
  I_sq < 75 ~ "Substantial",
  TRUE ~ "Considerable"
)

if (!is.na(I_sq)) {
  cat(sprintf("  I² = %.1f%% (95%% CI: %.1f%% - %.1f%%) - %s heterogeneity\n",
              I_sq, I_sq_lower, I_sq_upper, I_sq_interp))
} else {
  cat("  I² = N/A (not computable)\n")
}

# Random effects weights (for forest plot sizing)
study_effects <- study_effects %>%
  mutate(
    weight_re = 1 / (var_log_odds + tau_sq),
    weight_re_pct = weight_re / sum(weight_re) * 100
  )

# Pooled survival estimate (from metafor, using Knapp-Hartung t-distribution CIs)
pooled_surv <- plogis(theta_re)
pooled_surv_lower <- plogis(rma_REML$ci.lb)
pooled_surv_upper <- plogis(rma_REML$ci.ub)

cat(sprintf("\n  Pooled survival (RE): %.1f%% (95%% CI: %.1f%% - %.1f%%)\n",
            pooled_surv * 100, pooled_surv_lower * 100, pooled_surv_upper * 100))

# Prediction interval (from metafor - proper t-distribution)
pred_surv_lower <- plogis(pi_lower)
pred_surv_upper <- plogis(pi_upper)

cat(sprintf("  95%% Prediction interval: %.1f%% - %.1f%%\n",
            pred_surv_lower * 100, pred_surv_upper * 100))

# =============================================================================
# VALIDATION: Hand-rolled implementation (kept for transparency)
# =============================================================================
# The following hand-rolled code is retained for validation against metafor.
# The PRIMARY results above (from metafor) are used for all downstream analyses.
#
# # Fixed effects pooled estimate (for Q calculation)
# theta_fe <- sum(study_effects$weight_fe * study_effects$log_odds) /
#             sum(study_effects$weight_fe)
#
# # Q statistic (Cochran's test of homogeneity)
# Q_hand <- sum(study_effects$weight_fe * (study_effects$log_odds - theta_fe)^2)
# df_Q_hand <- nrow(study_effects) - 1
# p_Q_hand <- 1 - pchisq(Q_hand, df_Q_hand)
#
# # Between-study variance (DerSimonian-Laird estimator)
# C <- sum(study_effects$weight_fe) -
#      sum(study_effects$weight_fe^2) / sum(study_effects$weight_fe)
# tau_sq_DL_hand <- max(0, (Q_hand - df_Q_hand) / C)
# tau_DL_hand <- sqrt(tau_sq_DL_hand)
#
# # REML log-likelihood function
# reml_ll <- function(tau_sq, yi, vi) {
#   wi <- 1 / (vi + tau_sq)
#   theta <- sum(wi * yi) / sum(wi)
#   ll <- -0.5 * (sum(log(vi + tau_sq)) + sum(wi * (yi - theta)^2) +
#                 log(sum(wi)))
#   return(-ll)
# }
#
# yi <- study_effects$log_odds
# vi <- study_effects$var_log_odds
#
# reml_result <- optimize(
#   f = function(t2) reml_ll(t2, yi, vi),
#   interval = c(0, 10),
#   tol = 1e-8
# )
# tau_sq_REML_hand <- reml_result$minimum
#
# # I² statistic
# I_sq_hand <- max(0, (Q_hand - df_Q_hand) / Q_hand) * 100
#
# # I² confidence interval (Higgins & Thompson method)
# I_sq_lower_hand <- max(0, (Q_hand - df_Q_hand - 2*sqrt(2*df_Q_hand)) / Q_hand) * 100
# I_sq_upper_hand <- min(100, (Q_hand - df_Q_hand + 2*sqrt(2*df_Q_hand)) / Q_hand) * 100
#
# # Random effects pooled estimate
# weight_re_hand <- 1 / (study_effects$var_log_odds + tau_sq_REML_hand)
# theta_re_hand <- sum(weight_re_hand * study_effects$log_odds) /
#                  sum(weight_re_hand)
# se_theta_re_hand <- sqrt(1 / sum(weight_re_hand))
#
# # Prediction interval
# pi_lower_hand <- theta_re_hand - qt(0.975, df_Q_hand) * sqrt(se_theta_re_hand^2 + tau_sq_REML_hand)
# pi_upper_hand <- theta_re_hand + qt(0.975, df_Q_hand) * sqrt(se_theta_re_hand^2 + tau_sq_REML_hand)
# =============================================================================

# ==============================================================================
# SECTION 3: PUBLICATION-QUALITY FOREST PLOT
# ==============================================================================

cat("\nSECTION 3: Creating Forest Plot\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Prepare data for forest plot
forest_data <- study_effects %>%
  arrange(desc(survival_rate)) %>%
  mutate(
    study_id = row_number(),
    study_label = paste0(study, " (", region, ")"),
    study_label = factor(study_label, levels = rev(study_label)),
    # Format for annotation
    surv_text = sprintf("%.1f%% [%.1f, %.1f]",
                        survival_rate * 100, surv_lower * 100, surv_upper * 100),
    n_text = sprintf("%d", n),
    weight_text = sprintf("%.1f%%", weight_re_pct)
  )

# Summary row for pooled estimate
summary_row <- data.frame(
  study_label = "Pooled (Random Effects)",
  survival_rate = pooled_surv,
  surv_lower = pooled_surv_lower,
  surv_upper = pooled_surv_upper,
  n = sum(study_effects$n),
  weight_re_pct = 100,
  surv_text = sprintf("%.1f%% [%.1f, %.1f]",
                      pooled_surv * 100, pooled_surv_lower * 100, pooled_surv_upper * 100),
  is_summary = TRUE
)

forest_data$is_summary <- FALSE

# Create forest plot
p_forest <- ggplot(forest_data, aes(y = study_label)) +
  # Prediction interval shading
  annotate("rect",
           xmin = pred_surv_lower, xmax = pred_surv_upper,
           ymin = 0.4, ymax = nrow(forest_data) + 0.6,
           fill = "#E8F4F8", alpha = 0.8) +
  # Pooled estimate vertical line
  geom_vline(xintercept = pooled_surv, linetype = "dashed",
             color = "#2C3E50", linewidth = 0.8) +
  # Reference line at 50%
  geom_vline(xintercept = 0.5, linetype = "dotted", color = "gray60") +
  # Study confidence intervals
  geom_errorbarh(aes(xmin = surv_lower, xmax = surv_upper),
                 height = 0.3, color = "#34495E", linewidth = 0.6) +
  # Study point estimates (sized by weight)
  geom_point(aes(x = survival_rate, size = weight_re_pct),
             color = "#3498DB", alpha = 0.9) +
  # Pooled estimate diamond
  annotate("point", x = pooled_surv, y = 0.2,
           shape = 23, size = 4, fill = "#E74C3C", color = "#C0392B") +
  annotate("errorbarh", xmin = pooled_surv_lower, xmax = pooled_surv_upper,
           y = 0.2, height = 0.15, color = "#C0392B", linewidth = 0.8) +
  # Scales
  scale_x_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2),
    labels = scales::percent_format(accuracy = 1),
    expand = c(0.02, 0)
  ) +
  scale_size_continuous(range = c(2, 8), guide = "none") +
  # Labels
  labs(
    title = "Forest Plot: Annual Survival of A. palmata",
    subtitle = sprintf("Random-effects model (k = %d studies, N = %d colonies)",
                       nrow(study_effects), sum(study_effects$n)),
    x = "Survival Rate",
    y = NULL,
    caption = sprintf(
      "Heterogeneity: I² = %.1f%% [%.1f%%, %.1f%%], τ² = %.3f, Q = %.1f (p %s)\nDashed line: pooled estimate (%.1f%%); Shaded: 95%% prediction interval (%.1f%% - %.1f%%)",
      I_sq, I_sq_lower, I_sq_upper, tau_sq, Q,
      ifelse(p_Q < 0.001, "< 0.001", sprintf("= %.3f", p_Q)),
      pooled_surv * 100, pred_surv_lower * 100, pred_surv_upper * 100
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray40", size = 10),
    plot.caption = element_text(hjust = 0, size = 9, color = "gray40"),
    axis.text.y = element_text(size = 10),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank()
  )

# Add annotation table on right side
p_forest_table <- forest_data %>%
  select(study_label, surv_text, n_text = n, weight_text) %>%
  mutate(n_text = as.character(n_text)) %>%
  pivot_longer(-study_label, names_to = "column", values_to = "value") %>%
  mutate(
    column = factor(column,
                    levels = c("surv_text", "n_text", "weight_text"),
                    labels = c("Survival [95% CI]", "N", "Weight"))
  ) %>%
  ggplot(aes(x = column, y = study_label, label = value)) +
  geom_text(size = 3, hjust = 0.5) +
  scale_x_discrete(position = "top") +
  labs(x = NULL, y = NULL) +
  theme_void() +
  theme(
    axis.text.x.top = element_text(face = "bold", size = 9),
    plot.margin = margin(5, 10, 5, 0)
  )

# Combine
p_forest_combined <- p_forest + p_forest_table +
  plot_layout(widths = c(3, 1.5))

ggsave(file.path(fig_dir, "Fig_meta_forest_plot.pdf"), p_forest_combined,
       width = 14, height = 8, device = "pdf")
ggsave(file.path(fig_dir, "Fig_meta_forest_plot.png"), p_forest_combined,
       width = 14, height = 8, dpi = 300)

cat("  Saved: Fig_meta_forest_plot.pdf/png\n")

# ==============================================================================
# SECTION 4: FUNNEL PLOT WITH CONTOUR ENHANCEMENT
# ==============================================================================

cat("\nSECTION 4: Creating Funnel Plot\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Funnel plot data
funnel_data <- study_effects %>%
  mutate(
    # Centered effect (deviation from pooled)
    effect_centered = log_odds - theta_re,
    precision = 1 / se_log_odds
  )

# Calculate funnel boundaries
se_range <- seq(0.001, max(funnel_data$se_log_odds) * 1.2, length.out = 100)
funnel_bounds <- data.frame(
  se = se_range,
  lower_95 = theta_re - 1.96 * se_range,
  upper_95 = theta_re + 1.96 * se_range,
  lower_99 = theta_re - 2.58 * se_range,
  upper_99 = theta_re + 2.58 * se_range
)

# Create funnel plot
p_funnel <- ggplot() +
  # Significance contours using polygon
  geom_polygon(data = data.frame(
    x = c(funnel_bounds$lower_99, rev(funnel_bounds$upper_99)),
    y = c(funnel_bounds$se, rev(funnel_bounds$se))
  ), aes(x = x, y = y), fill = "#FEF9E7", alpha = 0.8) +
  geom_polygon(data = data.frame(
    x = c(funnel_bounds$lower_95, rev(funnel_bounds$upper_95)),
    y = c(funnel_bounds$se, rev(funnel_bounds$se))
  ), aes(x = x, y = y), fill = "#FCF3CF", alpha = 0.8) +
  # Funnel lines
  geom_line(data = funnel_bounds, aes(x = lower_95, y = se),
            linetype = "dashed", color = "gray50") +
  geom_line(data = funnel_bounds, aes(x = upper_95, y = se),
            linetype = "dashed", color = "gray50") +
  # Pooled effect line
  geom_vline(xintercept = theta_re, linetype = "solid", color = "#2C3E50") +
  # Study points
  geom_point(data = funnel_data,
             aes(x = log_odds, y = se_log_odds, size = n),
             color = "#3498DB", alpha = 0.8) +
  # Invert y-axis (convention: more precise at top)
  scale_y_reverse(limits = c(max(funnel_data$se_log_odds) * 1.1, 0)) +
  scale_size_continuous(range = c(2, 8), name = "Sample Size") +
  labs(
    title = "Funnel Plot: Assessment of Publication Bias",
    subtitle = sprintf("Pooled log-odds = %.2f (survival = %.1f%%)",
                       theta_re, pooled_surv * 100),
    x = "Log Odds (Survival)",
    y = "Standard Error",
    caption = "Dashed lines: 95% pseudo-confidence limits\nAsymmetry suggests potential publication bias"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray40"),
    legend.position = "right"
  )

cat("\nNOTE: Egger's test requires k >= 10 for reasonable power.\n")
cat(sprintf("With k = %d, a non-significant result does NOT rule out publication bias.\n", k))
cat("NOTE: Egger's test has essentially zero power at k=5. A non-significant result\n")
cat("provides NO evidence against publication bias. The test is included for\n")
cat("completeness but should not be interpreted as ruling out bias.\n")

# Egger's regression test for asymmetry
egger_data <- funnel_data %>%
  mutate(
    z = log_odds / se_log_odds,  # Standardized effect
    precision = 1 / se_log_odds
  )

egger_model <- lm(z ~ precision, data = egger_data)
egger_intercept <- coef(egger_model)[1]
egger_se <- summary(egger_model)$coefficients[1, 2]
egger_t <- egger_intercept / egger_se
egger_p <- 2 * pt(-abs(egger_t), df = nrow(egger_data) - 2)

cat(sprintf("  Egger's regression test:\n"))
cat(sprintf("    Intercept = %.3f (SE = %.3f)\n", egger_intercept, egger_se))
cat(sprintf("    t = %.3f, p = %.4f\n", egger_t, egger_p))
cat(sprintf("    Interpretation: %s\n",
            ifelse(egger_p < 0.05, "Significant asymmetry detected",
                   "No significant asymmetry")))

# Add Egger's test to plot
p_funnel <- p_funnel +
  labs(caption = sprintf(
    "Egger's test: intercept = %.2f, t = %.2f, p = %.3f (%s)\nDashed lines: 95%% pseudo-confidence limits",
    egger_intercept, egger_t, egger_p,
    ifelse(egger_p < 0.05, "asymmetry detected", "no asymmetry")
  ))

ggsave(file.path(fig_dir, "Fig_meta_funnel_plot.pdf"), p_funnel,
       width = 10, height = 8, device = "pdf")
ggsave(file.path(fig_dir, "Fig_meta_funnel_plot.png"), p_funnel,
       width = 10, height = 8, dpi = 300)

cat("  Saved: Fig_meta_funnel_plot.pdf/png\n")

# Trim-and-fill analysis for publication bias adjustment
cat("\n--- TRIM-AND-FILL ANALYSIS ---\n")
if (k >= 3) {  # trimfill needs at least 3 studies
  tf_result <- trimfill(rma_REML)
  cat(sprintf("Studies added (right side): %d\n", tf_result$k0))
  cat(sprintf("Adjusted pooled estimate: %.3f (%.3f to %.3f)\n",
              plogis(coef(tf_result)),
              plogis(tf_result$ci.lb),
              plogis(tf_result$ci.ub)))
  if (k < 10) {
    cat("CAVEAT: Trim-and-fill is unreliable with k < 10 studies.\n")
  }
  # Save trim-and-fill results
  tf_output <- data.frame(
    n_missing_studies = tf_result$k0,
    adjusted_pooled_estimate = plogis(coef(tf_result)),
    adjusted_ci_lower = plogis(tf_result$ci.lb),
    adjusted_ci_upper = plogis(tf_result$ci.ub),
    side = tf_result$side,
    k_original = k,
    caveat = ifelse(k < 10, "Unreliable with k < 10 studies", "")
  )
  write_csv(tf_output, file.path(output_dir, "meta_analysis_trim_fill.csv"))
  cat("  Saved: meta_analysis_trim_fill.csv\n")
} else {
  cat("Skipped: requires k >= 3 studies.\n")
}

# ==============================================================================
# SECTION 5: SENSITIVITY ANALYSES
# ==============================================================================

cat("\nSECTION 5: Sensitivity Analyses\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Leave-one-out analysis using metafor (consistent REML estimator)
loo_results_metafor <- leave1out(rma_REML)
cat("\nLeave-one-out sensitivity analysis (REML):\n")
print(loo_results_metafor)

# Convert to data frame for downstream use
loo_results <- data.frame(
  excluded_study = study_effects$study,
  pooled_log_odds = loo_results_metafor$estimate,
  pooled_survival = plogis(loo_results_metafor$estimate),
  se = loo_results_metafor$se,
  ci_lower = plogis(loo_results_metafor$ci.lb),
  ci_upper = plogis(loo_results_metafor$ci.ub),
  tau_sq = loo_results_metafor$tau2,
  I_sq = loo_results_metafor$I2
)

# Identify influential studies
loo_results <- loo_results %>%
  mutate(
    change_from_full = pooled_survival - pooled_surv,
    influential = abs(change_from_full) > 0.02  # >2% change
  )

influential_studies <- loo_results %>% filter(influential)
if (nrow(influential_studies) > 0) {
  cat(sprintf("\n  Influential studies (>2%% change when excluded):\n"))
  for (i in 1:nrow(influential_studies)) {
    cat(sprintf("    - %s: pooled changes to %.1f%% (Δ = %+.1f%%)\n",
                influential_studies$excluded_study[i],
                influential_studies$pooled_survival[i] * 100,
                influential_studies$change_from_full[i] * 100))
  }
} else {
  cat("\n  No individual study changes pooled estimate by >2%%\n")
}

# Create leave-one-out forest plot
p_loo <- loo_results %>%
  mutate(excluded_study = factor(excluded_study,
                                  levels = rev(excluded_study))) %>%
  ggplot(aes(y = excluded_study)) +
  # Full model estimate
  geom_vline(xintercept = pooled_surv, linetype = "dashed", color = "#E74C3C") +
  geom_rect(aes(xmin = pooled_surv_lower, xmax = pooled_surv_upper,
                ymin = -Inf, ymax = Inf), fill = "#FADBD8", alpha = 0.3) +
  # LOO estimates
  geom_errorbarh(aes(xmin = ci_lower, xmax = ci_upper),
                 height = 0.3, color = "#34495E") +
  geom_point(aes(x = pooled_survival, color = influential), size = 3) +
  scale_color_manual(values = c("FALSE" = "#3498DB", "TRUE" = "#E74C3C"),
                     labels = c("Not influential", "Influential"),
                     name = NULL) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Leave-One-Out Sensitivity Analysis",
    subtitle = sprintf("Red shading: 95%% CI from full model (%.1f%% [%.1f%%, %.1f%%])",
                       pooled_surv * 100, pooled_surv_lower * 100, pooled_surv_upper * 100),
    x = "Pooled Survival (with study excluded)",
    y = "Excluded Study"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "bottom"
  )

ggsave(file.path(supp_dir, "leave_one_out_analysis.png"), p_loo,
       width = 10, height = 6, dpi = 300)
cat("\n  Saved: leave_one_out_analysis.png\n")

# ==============================================================================
# SECTION 6: SUBGROUP ANALYSES
# ==============================================================================

cat("\nSECTION 6: Subgroup Meta-Analyses\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Function to perform meta-analysis on subset using metafor::rma with Knapp-Hartung
meta_analyze <- function(data) {
  if (nrow(data) < 2) return(NULL)

  # Use metafor::rma with REML and Knapp-Hartung adjustment (consistent with primary analysis)
  fit <- tryCatch(
    rma(yi = data$log_odds, vi = data$var_log_odds, method = "REML", test = "knha"),
    error = function(e) {
      # Fallback to DL if REML fails to converge
      tryCatch(
        rma(yi = data$log_odds, vi = data$var_log_odds, method = "DL", test = "knha"),
        error = function(e2) NULL
      )
    }
  )

  if (is.null(fit)) return(NULL)

  data.frame(
    k = nrow(data),
    n = sum(data$n),
    pooled_survival = plogis(as.numeric(fit$beta)),
    ci_lower = plogis(fit$ci.lb),
    ci_upper = plogis(fit$ci.ub),
    tau_sq = fit$tau2,
    I_sq = fit$I2,
    Q = fit$QE,
    p_Q = fit$QEp
  )
}

# Subgroup by region
region_meta <- study_effects %>%
  group_by(region) %>%
  group_modify(~ {
    result <- meta_analyze(.x)
    if (is.null(result)) {
      data.frame(k = nrow(.x), n = sum(.x$n), pooled_survival = mean(.x$survival_rate),
                 ci_lower = NA, ci_upper = NA, tau_sq = NA, I_sq = NA, Q = NA, p_Q = NA)
    } else {
      result
    }
  }) %>%
  ungroup()

cat("  Subgroup analysis by region:\n")
print(region_meta %>%
        mutate(across(c(pooled_survival, ci_lower, ci_upper),
                      ~sprintf("%.1f%%", . * 100)),
               I_sq = ifelse(is.na(I_sq), "N/A", sprintf("%.1f%%", I_sq))))

# Test for subgroup differences
# Between-group Q statistic
overall_Q <- Q
within_Q <- sum(region_meta$Q, na.rm = TRUE)
between_Q <- overall_Q - within_Q
df_between <- sum(!is.na(region_meta$Q)) - 1
p_between <- 1 - pchisq(between_Q, df_between)

cat(sprintf("\n  Test for subgroup differences (region):\n"))
cat(sprintf("    Q_between = %.2f (df = %d, p = %.4f)\n",
            between_Q, df_between, p_between))
cat("    NOTE: Q decomposition assumes common tau² across subgroups.\n")
cat("    With separate tau² per region, this is an approximation.\n")

# Save subgroup Q-test results
subgroup_test <- data.frame(
  test = "Subgroup differences by region",
  Q_between = between_Q,
  df_between = df_between,
  p_between = p_between,
  Q_overall = overall_Q,
  Q_within = within_Q,
  n_subgroups = nrow(region_meta),
  caveat = "Q decomposition assumes common tau-squared across subgroups"
)
write_csv(subgroup_test, file.path(output_dir, "meta_analysis_subgroup_test.csv"))
cat("  Saved: meta_analysis_subgroup_test.csv\n")

# ==============================================================================
# SECTION 7: META-REGRESSION
# ==============================================================================

cat("\nSECTION 7: Meta-Regression\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

cat("\n╔══════════════════════════════════════════════════════════════════════════╗\n")
cat("║  EXPLORATORY ONLY: Meta-regression requires k >= 10 per moderator.    ║\n")
cat("║  With k = 5, these models are severely underpowered and R² estimates  ║\n")
cat("║  are unreliable. Results are retained for transparency but should     ║\n")
cat("║  NOT appear in publication tables. NOT FOR PUBLICATION TABLE.         ║\n")
cat("╚══════════════════════════════════════════════════════════════════════════╝\n")

cat("\n--- MODERATOR ANALYSES (EXPLORATORY - k too small for reliable inference) ---\n")

# Test moderators
moderators <- list()

# 7a. Colony size as moderator
if (any(!is.na(study_effects$mean_size_cm2))) {
  # Meta-regression using metafor (proper inverse-variance weighting)
  meta_reg_size <- rma(yi = log_odds, vi = var_log_odds,
                       mods = ~log(mean_size_cm2), data = study_effects, method = "REML", test = "knha")

  moderators$size <- data.frame(
    moderator = "Log colony size (cm²)",
    coefficient = meta_reg_size$beta[2],
    se = meta_reg_size$se[2],
    ci_lower = meta_reg_size$ci.lb[2],   # Use metafor's Knapp-Hartung t-distribution CIs
    ci_upper = meta_reg_size$ci.ub[2],
    test_statistic = meta_reg_size$zval[2],  # t-value when test="knha"
    p_value = meta_reg_size$pval[2],
    # R2 from k=5 meta-regression is unreliable — retained for completeness only
    R2 = max(0, meta_reg_size$R2) / 100,  # metafor returns R2 as percentage
    exploratory_only = TRUE,
    R2_reliable = FALSE
  )

  cat(sprintf("  Colony size: coef=%.3f, p=%.4f [R² not reported — k too small]\n",
              meta_reg_size$beta[2], meta_reg_size$pval[2]))
}

# 7b. Fragment percentage as moderator
if (any(!is.na(study_effects$pct_fragment))) {
  # Meta-regression using metafor (proper inverse-variance weighting)
  meta_reg_frag <- rma(yi = log_odds, vi = var_log_odds,
                       mods = ~pct_fragment, data = study_effects, method = "REML", test = "knha")

  moderators$fragment <- data.frame(
    moderator = "Fragment percentage",
    coefficient = meta_reg_frag$beta[2],
    se = meta_reg_frag$se[2],
    ci_lower = meta_reg_frag$ci.lb[2],   # Use metafor's Knapp-Hartung t-distribution CIs
    ci_upper = meta_reg_frag$ci.ub[2],
    test_statistic = meta_reg_frag$zval[2],  # t-value when test="knha"
    p_value = meta_reg_frag$pval[2],
    # R2 from k=5 meta-regression is unreliable — retained for completeness only
    R2 = max(0, meta_reg_frag$R2) / 100,  # metafor returns R2 as percentage
    exploratory_only = TRUE,
    R2_reliable = FALSE
  )

  cat(sprintf("  Fragment %%: coef=%.4f, p=%.4f [R² not reported — k too small]\n",
              meta_reg_frag$beta[2], meta_reg_frag$pval[2]))
}

# 7c. Year as moderator
# Meta-regression using metafor (proper inverse-variance weighting)
meta_reg_year <- rma(yi = log_odds, vi = var_log_odds,
                     mods = ~year_end, data = study_effects, method = "REML", test = "knha")

moderators$year <- data.frame(
  moderator = "Study year",
  coefficient = meta_reg_year$beta[2],
  se = meta_reg_year$se[2],
  ci_lower = meta_reg_year$ci.lb[2],   # Use metafor's Knapp-Hartung t-distribution CIs
  ci_upper = meta_reg_year$ci.ub[2],
  test_statistic = meta_reg_year$zval[2],  # t-value when test="knha"
  p_value = meta_reg_year$pval[2],
  # R2 from k=5 meta-regression is unreliable — retained for completeness only
  R2 = max(0, meta_reg_year$R2) / 100,  # metafor returns R2 as percentage
  exploratory_only = TRUE,
  R2_reliable = FALSE
)

cat(sprintf("  Study year: coef=%.4f, p=%.4f [R² not reported — k too small]\n",
            meta_reg_year$beta[2], meta_reg_year$pval[2]))

moderator_df <- bind_rows(moderators)

# ==============================================================================
# SECTION 8: HETEROGENEITY DECOMPOSITION FIGURE
# ==============================================================================

cat("\nSECTION 8: Creating Heterogeneity Decomposition Figure\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

# Panel A: I² gauge/dial visualization
i_sq_data <- data.frame(
  category = factor(c("Low\n(<25%)", "Moderate\n(25-50%)",
                      "Substantial\n(50-75%)", "Considerable\n(>75%)"),
                    levels = c("Low\n(<25%)", "Moderate\n(25-50%)",
                               "Substantial\n(50-75%)", "Considerable\n(>75%)")),
  start = c(0, 25, 50, 75),
  end = c(25, 50, 75, 100),
  color = c("#27AE60", "#F1C40F", "#E67E22", "#E74C3C")
)

p_i_sq <- ggplot(i_sq_data) +
  geom_rect(aes(xmin = start, xmax = end, ymin = 0, ymax = 1, fill = color),
            alpha = 0.8) +
  geom_vline(xintercept = I_sq, color = "#2C3E50", linewidth = 2) +
  geom_label(aes(x = I_sq, y = 0.5,
                 label = if (is.na(I_sq)) "I² = N/A" else sprintf("I² = %.1f%%", I_sq)),
             fill = "white", size = 5, fontface = "bold") +
  scale_fill_identity() +
  scale_x_continuous(breaks = c(0, 25, 50, 75, 100),
                     labels = c("0%", "25%", "50%", "75%", "100%")) +
  labs(
    title = "A. Heterogeneity Level (I²)",
    x = NULL, y = NULL
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid = element_blank()
  )

# Panel B: Variance components
var_data <- data.frame(
  component = c("Between-study (τ²)", "Within-study"),
  variance = c(tau_sq, mean(study_effects$var_log_odds)),
  pct = c(tau_sq / (tau_sq + mean(study_effects$var_log_odds)) * 100,
          mean(study_effects$var_log_odds) / (tau_sq + mean(study_effects$var_log_odds)) * 100)
)

p_variance <- var_data %>%
  mutate(component = factor(component, levels = rev(component))) %>%
  ggplot(aes(x = pct, y = component, fill = component)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf("%.1f%%\n(%.3f)", pct, variance)),
            hjust = -0.1, size = 4) +
  scale_fill_manual(values = c("#3498DB", "#E74C3C"), guide = "none") +
  scale_x_continuous(limits = c(0, 100), expand = c(0, 0, 0.3, 0)) +
  labs(
    title = "B. Variance Decomposition",
    x = "Proportion of Total Variance (%)",
    y = NULL
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold"),
    panel.grid.major.y = element_blank()
  )

# Panel C: Prediction vs Confidence intervals
interval_data <- data.frame(
  type = factor(c("Confidence Interval", "Prediction Interval"),
                levels = c("Confidence Interval", "Prediction Interval")),
  estimate = pooled_surv,
  lower = c(pooled_surv_lower, pred_surv_lower),
  upper = c(pooled_surv_upper, pred_surv_upper)
)

p_intervals <- ggplot(interval_data, aes(y = type)) +
  geom_errorbarh(aes(xmin = lower, xmax = upper, color = type),
                 height = 0.3, linewidth = 1.5) +
  geom_point(aes(x = estimate), size = 4, color = "#2C3E50") +
  scale_color_manual(values = c("#3498DB", "#E74C3C"), guide = "none") +
  scale_x_continuous(limits = c(0, 1), labels = scales::percent_format()) +
  labs(
    title = "C. Confidence vs Prediction Intervals",
    subtitle = "Prediction interval shows expected range of true effects in new studies",
    x = "Survival Rate",
    y = NULL
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold")
  )

# Panel D: Moderator effects
if (nrow(moderator_df) > 0) {
  p_moderators <- moderator_df %>%
    mutate(
      significant = p_value < 0.05,
      moderator = factor(moderator, levels = rev(moderator))
    ) %>%
    ggplot(aes(y = moderator)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = ci_lower,
                       xmax = ci_upper),
                   height = 0.2, color = "gray40") +
    geom_point(aes(x = coefficient, color = significant), size = 4) +
    scale_color_manual(values = c("FALSE" = "#95A5A6", "TRUE" = "#E74C3C"),
                       labels = c("p ≥ 0.05", "p < 0.05"),
                       name = NULL) +
    labs(
      title = "D. Meta-Regression: Moderator Effects",
      x = "Regression Coefficient (log-odds scale)",
      y = NULL
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold"),
      legend.position = "bottom"
    )
} else {
  p_moderators <- ggplot() +
    annotate("text", x = 0.5, y = 0.5, label = "No moderators tested") +
    theme_void()
}

# Combine all panels
p_heterogeneity <- (p_i_sq + p_variance) / (p_intervals + p_moderators) +
  plot_annotation(
    title = "Heterogeneity Analysis Summary",
    subtitle = sprintf("A. palmata survival meta-analysis (k = %d studies)", nrow(study_effects)),
    theme = theme(
      plot.title = element_text(face = "bold", size = 16),
      plot.subtitle = element_text(size = 12, color = "gray40")
    )
  )

ggsave(file.path(fig_dir, "Fig_meta_heterogeneity.pdf"), p_heterogeneity,
       width = 14, height = 10, device = "pdf")
ggsave(file.path(fig_dir, "Fig_meta_heterogeneity.png"), p_heterogeneity,
       width = 14, height = 10, dpi = 300)

cat("  Saved: Fig_meta_heterogeneity.pdf/png\n")

# ==============================================================================
# SECTION 9: STRATIFIED META-ANALYSIS BY POPULATION TYPE (KEY ANALYSIS)
# ==============================================================================

cat("\nSECTION 9: Stratified Meta-Analysis by Population Type\n")
cat(paste(rep("-", 60), collapse = ""), "\n\n")

cat("This is the KEY analysis - stratifying by population type reduces heterogeneity\n")
cat("Natural colonies: k=1 (I² not computable); Fragments: I² = 86.5%\n\n")

cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  WARNING: Natural colony estimate is from a SINGLE STUDY (NOAA).   ║\n")
cat("║  This comparison is confounded by study identity, region, and era. ║\n")
cat("║  It should NOT be interpreted as a causal natural vs. restoration  ║\n")
cat("║  difference. See sensitivity analysis for robustness.              ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n\n")

# Perform meta-analysis separately for each population type
stratified_meta <- study_effects %>%
  group_by(population_type) %>%
  group_modify(~ {
    data <- .x
    if (nrow(data) < 2) {
      return(data.frame(
        k = nrow(data),
        n = sum(data$n),
        pooled_survival = mean(data$survival_rate),
        ci_lower = NA, ci_upper = NA,
        pi_lower = NA, pi_upper = NA,
        tau_sq = NA, tau = NA,
        I_sq = NA, Q = NA, p_Q = NA
      ))
    }

    # Use metafor::rma with REML and Knapp-Hartung (consistent with primary analysis)
    fit <- tryCatch(
      rma(yi = data$log_odds, vi = data$var_log_odds, method = "REML", test = "knha"),
      error = function(e) {
        tryCatch(
          rma(yi = data$log_odds, vi = data$var_log_odds, method = "DL", test = "knha"),
          error = function(e2) NULL
        )
      }
    )

    if (is.null(fit)) {
      return(data.frame(
        k = nrow(data), n = sum(data$n),
        pooled_survival = mean(data$survival_rate),
        ci_lower = NA, ci_upper = NA,
        pi_lower = NA, pi_upper = NA,
        tau_sq = NA, tau = NA,
        I_sq = NA, Q = NA, p_Q = NA
      ))
    }

    theta_re <- as.numeric(fit$beta)
    se_re <- fit$se
    df_Q_strat <- nrow(data) - 1

    # Prediction interval
    if (df_Q_strat > 0) {
      pi_lower <- plogis(theta_re - qt(0.975, df_Q_strat) * sqrt(se_re^2 + fit$tau2))
      pi_upper <- plogis(theta_re + qt(0.975, df_Q_strat) * sqrt(se_re^2 + fit$tau2))
    } else {
      pi_lower <- NA
      pi_upper <- NA
    }

    data.frame(
      k = nrow(data),
      n = sum(data$n),
      pooled_survival = plogis(theta_re),
      ci_lower = plogis(fit$ci.lb),
      ci_upper = plogis(fit$ci.ub),
      pi_lower = pi_lower,
      pi_upper = pi_upper,
      tau_sq = fit$tau2,
      tau = sqrt(fit$tau2),
      I_sq = fit$I2,
      Q = fit$QE,
      p_Q = fit$QEp
    )
  }) %>%
  ungroup()

cat("STRATIFIED RESULTS (observational comparison, NOT causal inference):\n\n")
for (i in 1:nrow(stratified_meta)) {
  k_stratum <- stratified_meta$k[i]
  pop_type <- stratified_meta$population_type[i]

  if (k_stratum == 1) {
    cat(sprintf("  %s (single study: NOAA — NOT a meta-analytic synthesis):\n", pop_type))
    cat("    *** SINGLE-STUDY ESTIMATE: Cannot compute heterogeneity, prediction\n")
    cat("    *** interval, or assess generalizability. This is the observed survival\n")
    cat("    *** from one study in one region (Florida), not a pooled estimate.\n")
  } else {
    cat(sprintf("  %s meta-analytic survival (k=%d):\n", pop_type, k_stratum))
  }
  cat(sprintf("    Studies (k): %d\n", stratified_meta$k[i]))
  cat(sprintf("    Observations: %d\n", stratified_meta$n[i]))
  if (k_stratum == 1) {
    cat(sprintf("    Observed survival (single study): %.1f%%\n",
                stratified_meta$pooled_survival[i] * 100))
    cat("    95%% CI: not applicable for single-study proportion in this context\n")
  } else {
    cat(sprintf("    Pooled survival: %.1f%% (95%% CI: %.1f%% - %.1f%%)\n",
                stratified_meta$pooled_survival[i] * 100,
                stratified_meta$ci_lower[i] * 100,
                stratified_meta$ci_upper[i] * 100))
  }
  if (!is.na(stratified_meta$pi_lower[i])) {
    cat(sprintf("    95%% PI: %.1f%% - %.1f%%\n",
                stratified_meta$pi_lower[i] * 100,
                stratified_meta$pi_upper[i] * 100))
  }
  if (!is.na(stratified_meta$I_sq[i])) {
    cat(sprintf("    I² = %.1f%% (heterogeneity %s)\n",
                stratified_meta$I_sq[i],
                ifelse(stratified_meta$I_sq[i] > 75, "CONSIDERABLE",
                       ifelse(stratified_meta$I_sq[i] > 50, "SUBSTANTIAL",
                              ifelse(stratified_meta$I_sq[i] > 25, "MODERATE", "LOW")))))
  } else {
    cat("    I² = not computable (k=1)\n")
  }
  if (!is.na(stratified_meta$tau_sq[i])) {
    cat(sprintf("    τ² = %.4f\n\n", stratified_meta$tau_sq[i]))
  } else {
    cat("    τ² = not computable (k=1)\n\n")
  }
}

# Calculate heterogeneity reduction
overall_I_sq <- I_sq
natural_I_sq <- stratified_meta$I_sq[stratified_meta$population_type == "Natural colony"]
fragment_I_sq <- stratified_meta$I_sq[stratified_meta$population_type == "Restoration fragment"]

cat("HETEROGENEITY REDUCTION FROM STRATIFICATION:\n")
cat(if (is.na(overall_I_sq)) "  Overall I²: N/A\n" else sprintf("  Overall I²: %.1f%%\n", overall_I_sq))
if (length(natural_I_sq) > 0 && !is.na(natural_I_sq)) {
  cat(sprintf("  Natural colonies I²: %.1f%% (reduction: %.1f pp)\n",
              natural_I_sq, overall_I_sq - natural_I_sq))
}
if (length(fragment_I_sq) > 0 && !is.na(fragment_I_sq)) {
  cat(sprintf("  Restoration fragments I²: %.1f%% (reduction: %.1f pp)\n",
              fragment_I_sq, overall_I_sq - fragment_I_sq))
}

# Create stratified forest plot
cat("\nCreating stratified forest plot...\n")

# Prepare data with stratification coloring
forest_stratified <- study_effects %>%
  arrange(population_type, desc(survival_rate)) %>%
  mutate(
    study_label = paste0(study, " (", region, ")"),
    study_label = factor(study_label, levels = rev(study_label))
  )

pop_colors <- c("Natural colony" = "#264653", "Restoration fragment" = "#e07a5f")

p_forest_stratified <- ggplot(forest_stratified, aes(y = study_label)) +
  # Overall pooled estimate
  geom_vline(xintercept = pooled_surv, linetype = "dashed",
             color = "gray50", linewidth = 0.5) +
  # Study confidence intervals
  geom_errorbarh(aes(xmin = surv_lower, xmax = surv_upper),
                 height = 0.3, color = "#34495E", linewidth = 0.6) +
  # Study point estimates (colored by population type)
  geom_point(aes(x = survival_rate, size = weight_re_pct, color = population_type),
             alpha = 0.9) +
  # Add stratified pooled estimates
  geom_vline(data = stratified_meta,
             aes(xintercept = pooled_survival, color = population_type),
             linetype = "solid", linewidth = 1) +
  # Scales
  scale_color_manual(values = pop_colors, name = "Population Type") +
  scale_x_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2),
    labels = scales::percent_format(accuracy = 1),
    expand = c(0.02, 0)
  ) +
  scale_size_continuous(range = c(2, 8), guide = "none") +
  labs(
    title = "Forest Plot: Stratified by Population Type",
    subtitle = paste0(
      sprintf("Natural colonies: %.1f%%", stratified_meta$pooled_survival[stratified_meta$population_type == "Natural colony"] * 100),
      if (is.na(natural_I_sq)) " (I²=N/A)" else sprintf(" (I²=%.0f%%)", natural_I_sq),
      " | ",
      sprintf("Restoration fragments: %.1f%%", stratified_meta$pooled_survival[stratified_meta$population_type == "Restoration fragment"] * 100),
      if (is.na(fragment_I_sq)) " (I²=N/A)" else sprintf(" (I²=%.0f%%)", fragment_I_sq)
    ),
    x = "Survival Rate",
    y = NULL,
    caption = paste0(
      sprintf("Gray dashed: overall pooled (%.1f%%); Solid lines: stratified pooled estimates\n", pooled_surv * 100),
      "Stratification reduces I² from ",
      if (is.na(overall_I_sq)) "N/A" else sprintf("%.1f%%", overall_I_sq),
      " to ",
      if (is.na(natural_I_sq)) "N/A" else sprintf("%.1f%%", natural_I_sq),
      " (natural) and ",
      if (is.na(fragment_I_sq)) "N/A" else sprintf("%.1f%%", fragment_I_sq),
      " (fragments)"
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray40", size = 10),
    plot.caption = element_text(hjust = 0, size = 9, color = "gray40"),
    axis.text.y = element_text(size = 10),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "bottom"
  )

ggsave(file.path(fig_dir, "Fig_meta_forest_stratified.pdf"), p_forest_stratified,
       width = 12, height = 8, device = "pdf")
ggsave(file.path(fig_dir, "Fig_meta_forest_stratified.png"), p_forest_stratified,
       width = 12, height = 8, dpi = 300)

cat("  Saved: Fig_meta_forest_stratified.pdf/png\n")

# Add metadata columns for downstream consumers
stratified_meta <- stratified_meta %>%
  mutate(
    k_studies = k,
    is_single_study = (k == 1),
    comparison_caveat = ifelse(
      k == 1,
      "Single-study estimate (NOAA only). Not a meta-analytic synthesis. Confounded by study identity, region, and era.",
      paste0("Meta-analytic pooled estimate (k=", k, "). Interpret with caution due to small k.")
    )
  )

# Compute survival difference with caveat
natural_surv <- stratified_meta$pooled_survival[stratified_meta$population_type == "Natural colony"]
restoration_surv <- stratified_meta$pooled_survival[stratified_meta$population_type == "Restoration fragment"]
surv_diff_pp <- round((natural_surv - restoration_surv) * 100, 1)

# Add difference row to stratified output
diff_row <- data.frame(
  population_type = "Difference (Natural - Restoration)",
  k = NA, n = NA,
  pooled_survival = natural_surv - restoration_surv,
  ci_lower = NA, ci_upper = NA,
  pi_lower = NA, pi_upper = NA,
  tau_sq = NA, tau = NA,
  I_sq = NA, Q = NA, p_Q = NA,
  k_studies = NA,
  is_single_study = NA,
  comparison_caveat = paste0(
    "Observational comparison (", surv_diff_pp, " pp). ",
    "Natural colony estimate is from a SINGLE study (NOAA). ",
    "Difference is confounded by study identity, region, methodology, and era. ",
    "NOT a causal estimate of natural vs. restoration survival advantage."
  )
)
stratified_meta_output <- bind_rows(stratified_meta, diff_row)

# Save stratified results
write_csv(stratified_meta_output, file.path(output_dir, "meta_analysis_stratified.csv"))

# ==============================================================================
# SAVE OUTPUTS
# ==============================================================================

cat("\nSaving outputs...\n")

# Main meta-analysis results
meta_results <- data.frame(
  statistic = c("Number of studies (k)", "Total observations (N)",
                "Pooled survival (RE)", "95% CI lower", "95% CI upper",
                "95% PI lower", "95% PI upper",
                "tau² (between-study variance)", "tau (SD of true effects)",
                "I² (%)", "I² 95% CI lower", "I² 95% CI upper",
                "Cochran's Q", "Q df", "Q p-value",
                "Egger's intercept", "Egger's p-value"),
  value = c(nrow(study_effects), sum(study_effects$n),
            sprintf("%.3f", pooled_surv), sprintf("%.3f", pooled_surv_lower),
            sprintf("%.3f", pooled_surv_upper),
            sprintf("%.3f", pred_surv_lower), sprintf("%.3f", pred_surv_upper),
            sprintf("%.4f", tau_sq), sprintf("%.4f", tau),
            ifelse(is.na(I_sq), "NA", sprintf("%.1f", I_sq)),
            ifelse(is.na(I_sq_lower), "NA", sprintf("%.1f", I_sq_lower)),
            ifelse(is.na(I_sq_upper), "NA", sprintf("%.1f", I_sq_upper)),
            sprintf("%.2f", Q), df_Q, sprintf("%.4f", p_Q),
            sprintf("%.3f", egger_intercept), sprintf("%.4f", egger_p))
)

write_csv(meta_results, file.path(output_dir, "meta_analysis_results.csv"))
write_csv(study_effects, file.path(output_dir, "meta_analysis_study_effects.csv"))
write_csv(loo_results, file.path(output_dir, "meta_analysis_loo.csv"))
write_csv(region_meta, file.path(output_dir, "meta_analysis_by_region.csv"))
write_csv(moderator_df, file.path(output_dir, "meta_analysis_moderators.csv"))

# Methods metadata
meta_methods <- data.frame(
  parameter = c("effect_size_measure", "estimation_method", "small_sample_adjustment",
                 "continuity_correction", "k_studies", "total_N"),
  value = c("PLO (proportional log-odds)", "REML", "Knapp-Hartung (test='knha')",
            "Haldane 0.5 when zero cells", as.character(k), as.character(sum(study_effects$n)))
)
write_csv(meta_methods, file.path(output_dir, "meta_analysis_methods.csv"))

cat("  Saved all meta-analysis outputs\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n")
cat("==============================================================================\n")
cat("  META-ANALYSIS SUMMARY\n")
cat("==============================================================================\n\n")

cat("MAIN FINDINGS:\n")
cat(sprintf("  Pooled annual survival: %.1f%% (95%% CI: %.1f%% - %.1f%%)\n",
            pooled_surv * 100, pooled_surv_lower * 100, pooled_surv_upper * 100))
cat(sprintf("  95%% Prediction interval: %.1f%% - %.1f%%\n",
            pred_surv_lower * 100, pred_surv_upper * 100))

cat("\nHETEROGENEITY:\n")
if (!is.na(I_sq)) {
  cat(sprintf("  I² = %.1f%% (%s heterogeneity)\n", I_sq, I_sq_interp))
} else {
  cat("  I² = N/A (not computable)\n")
}
cat(sprintf("  τ² = %.4f (substantial between-study variance)\n", tau_sq))
cat(sprintf("  Q = %.2f (p %s)\n", Q, ifelse(p_Q < 0.001, "< 0.001", sprintf("= %.4f", p_Q))))

cat("\nPUBLICATION BIAS:\n")
cat(sprintf("  Egger's test: p = %.4f (%s)\n", egger_p,
            ifelse(egger_p < 0.05, "asymmetry detected", "no significant asymmetry")))
cat("  CAVEAT: Egger's test has essentially zero power at k=5.\n")
cat("  Non-significance does NOT provide evidence against publication bias.\n")

cat("\nSTRATIFIED RESULTS (observational comparison — see caveats):\n")
cat(sprintf("  Natural colony survival (single study: NOAA): %.1f%%\n",
            stratified_meta$pooled_survival[stratified_meta$population_type == "Natural colony"] * 100))
if (!is.na(fragment_I_sq)) {
  cat(sprintf("  Restoration fragment meta-analytic survival (k=4): %.1f%% (I² = %.1f%%)\n",
              stratified_meta$pooled_survival[stratified_meta$population_type == "Restoration fragment"] * 100,
              fragment_I_sq))
} else {
  cat(sprintf("  Restoration fragment meta-analytic survival (k=4): %.1f%% (I² = N/A)\n",
              stratified_meta$pooled_survival[stratified_meta$population_type == "Restoration fragment"] * 100))
}
cat(sprintf("  Observational difference: ~%.0f pp (NOT a causal estimate)\n", surv_diff_pp))
cat("  NOTE: Natural colony estimate = one study (NOAA, Florida). Difference is\n")
cat("  confounded by study identity, region, methodology, and era.\n")

cat("\nIMPLICATIONS:\n")
cat("  * Population type (natural vs restoration) is associated with heterogeneity\n")
cat("  * Natural colony NOAA data may serve as a reference for Florida wild populations\n")
cat(sprintf("  * Observational difference (~%.0f pp) is suggestive but confounded (k=1 natural)\n", surv_diff_pp))
cat("  * Stratified analyses are more appropriate than overall pooled estimates\n")
cat("  * Additional natural colony studies from other regions are critically needed\n")

cat("\nOUTPUTS:\n")
cat("  Publication figures:\n")
cat("    - Fig_meta_forest_plot.pdf/png\n")
cat("    - Fig_meta_forest_stratified.pdf/png (KEY - by population type)\n")
cat("    - Fig_meta_funnel_plot.pdf/png\n")
cat("    - Fig_meta_heterogeneity.pdf/png\n")
cat("  Supplementary:\n")
cat("    - leave_one_out_analysis.png\n")
cat("  Data files:\n")
cat("    - meta_analysis_results.csv\n")
cat("    - meta_analysis_stratified.csv (KEY - by population type)\n")
cat("    - meta_analysis_study_effects.csv\n")
cat("    - meta_analysis_loo.csv\n")
cat("    - meta_analysis_by_region.csv\n")
cat("    - meta_analysis_moderators.csv\n")

cat("\n\nMeta-analysis complete.\n")
