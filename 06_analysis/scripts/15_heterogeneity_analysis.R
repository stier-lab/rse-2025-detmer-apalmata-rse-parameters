################################################################################
# 15_heterogeneity_analysis.R - Meta-Analysis Heterogeneity Quantification
################################################################################
#
# PURPOSE:
#   Quantify between-study heterogeneity using meta-analysis methods (I², Q-tests)
#   to assess whether pooling estimates across studies is appropriate.
#
# BACKGROUND:
#   The A. palmata data synthesis combines 18+ studies with fundamentally different
#   methodologies (NOAA field colonies vs. Pausch fragments, 100-400x size differences).
#   Formal heterogeneity assessment is essential for proper meta-analytic inference.
#
# METHODS:
#   1. Calculate study-level effect sizes (log odds ratios for survival)
#   2. Compute Q statistic (test of homogeneity)
#   3. Calculate I² (proportion of variance due to heterogeneity)
#   4. Assess heterogeneity by moderators (size class, region, fragment status)
#   5. Produce forest plots with heterogeneity annotations
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#
# OUTPUTS:
#   - 06_analysis/output/heterogeneity_analysis.csv
#   - 06_analysis/output/study_effect_sizes.csv
#   - 06_analysis/output/moderator_effects.csv
#   - 06_analysis/figures/supplementary/exploratory/heterogeneity_forest_plot.png
#
# Author: Detmer & Stier Lab
# Date: 2025-12-25
################################################################################

# Load required packages
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)

# Source shared utilities for constants and helper functions
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  15: HETEROGENEITY ANALYSIS (v2.1)                           ║\n")
cat("║  Stratified by Population Type (Natural vs Restoration)      ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# =============================================================================
# SETUP
# =============================================================================

if (file.exists("05_data/standardized")) {
  project_root <- "."
} else if (file.exists("../05_data/standardized")) {
  project_root <- ".."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root.")
}

output_dir <- file.path(project_root, "06_analysis/output")
fig_dir <- file.path(project_root, "06_analysis/figures/supplementary/exploratory")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# LOAD DATA
# =============================================================================

cat("Loading prepared data...\n")

surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

cat(sprintf("  Survival: %d observations from %d studies\n",
            nrow(surv_data), n_distinct(surv_data$study)))
cat(sprintf("  Growth: %d observations from %d studies\n",
            nrow(growth_data), n_distinct(growth_data$study)))
cat("\n")

# =============================================================================
# 1. CALCULATE STUDY-LEVEL EFFECT SIZES (SURVIVAL)
# =============================================================================

cat("Calculating study-level effect sizes for survival...\n")

# First, show population type breakdown
cat("\n  Population type breakdown:\n")
pop_breakdown <- surv_data %>%
  group_by(population_type) %>%
  summarise(
    n = n(),
    n_studies = n_distinct(study),
    survival = mean(survived),
    .groups = "drop"
  )
print(as.data.frame(pop_breakdown))

# PRIMARY: Group by study only (k=5), consistent with script 14 meta-analysis.
# NOAA is treated as one study even though it spans multiple regions.
study_effects <- surv_data %>%
  group_by(study) %>%
  summarise(
    region = paste(sort(unique(region)), collapse = "/"),
    n = n(),
    n_survived = sum(survived),
    n_died = n - n_survived,
    survival_rate = mean(survived),
    mean_size = mean(size_cm2, na.rm = TRUE),
    median_size = median(size_cm2, na.rm = TRUE),
    fragment_pct = mean(fragment == "Y", na.rm = TRUE) * 100,
    population_type = ifelse(mean(fragment == "Y", na.rm = TRUE) > 0.5,
                             "Restoration fragment", "Natural colony"),
    year_min = min(survey_yr),
    year_max = max(survey_yr),
    .groups = "drop"
  ) %>%
  filter(n >= 10) %>%  # Require minimum sample size; zero-cell studies handled by Haldane correction below
  mutate(
    # Haldane continuity correction: add 0.5 to ALL cells when ANY cell is zero
    # This is the standard approach (Haldane 1956) — applied uniformly
    needs_correction = (n_survived == 0) | (n_died == 0),
    n_survived_adj = ifelse(needs_correction, n_survived + 0.5, n_survived),
    n_died_adj = ifelse(needs_correction, n_died + 0.5, n_died),
    n_adj = n_survived_adj + n_died_adj,
    log_odds = log(n_survived_adj / n_died_adj),
    # Variance of log odds ratio
    var_log_odds = 1/n_survived_adj + 1/n_died_adj,
    se_log_odds = sqrt(var_log_odds),
    # Inverse variance weight
    weight = 1 / var_log_odds,
    # 95% CI for log odds
    log_odds_lower = log_odds - 1.96 * se_log_odds,
    log_odds_upper = log_odds + 1.96 * se_log_odds,
    # Convert to probability scale for interpretation
    prob_lower = exp(log_odds_lower) / (1 + exp(log_odds_lower)),
    prob_upper = exp(log_odds_upper) / (1 + exp(log_odds_upper))
  )

# SUPPLEMENTARY: Subregion analysis (study x region, k=7) for exploratory use
# This splits multi-region studies (e.g., NOAA) into regional subgroups
study_region_effects <- surv_data %>%
  group_by(study, region) %>%
  summarise(
    n = n(),
    n_survived = sum(survived),
    n_died = n - n_survived,
    survival_rate = mean(survived),
    mean_size = mean(size_cm2, na.rm = TRUE),
    fragment_pct = mean(fragment == "Y", na.rm = TRUE) * 100,
    population_type = ifelse(mean(fragment == "Y", na.rm = TRUE) > 0.5,
                             "Restoration fragment", "Natural colony"),
    year_min = min(survey_yr),
    year_max = max(survey_yr),
    .groups = "drop"
  ) %>%
  filter(n >= 10) %>%  # Require minimum sample size; zero-cell studies handled by Haldane correction below
  mutate(
    needs_correction = (n_survived == 0) | (n_died == 0),
    n_survived_adj = ifelse(needs_correction, n_survived + 0.5, n_survived),
    n_died_adj = ifelse(needs_correction, n_died + 0.5, n_died),
    n_adj = n_survived_adj + n_died_adj,
    log_odds = log(n_survived_adj / n_died_adj),
    var_log_odds = 1/n_survived_adj + 1/n_died_adj,
    se_log_odds = sqrt(var_log_odds),
    weight = 1 / var_log_odds
  )

# Save supplementary subregion analysis
write_csv(study_region_effects, file.path(output_dir, "heterogeneity_subregion_analysis.csv"))
cat(sprintf("  Supplementary subregion analysis (k=%d) saved: heterogeneity_subregion_analysis.csv\n",
            nrow(study_region_effects)))

cat(sprintf("  Studies with sufficient data: %d\n", nrow(study_effects)))

# =============================================================================
# 2. RANDOM EFFECTS META-ANALYSIS
# =============================================================================

cat("\nPerforming random effects meta-analysis...\n")

# Calculate Q statistic (test of homogeneity)
# Q = Σ wi * (yi - y_pooled)²

# Pooled estimate (fixed effects)
pooled_fixed <- sum(study_effects$weight * study_effects$log_odds) /
  sum(study_effects$weight)

# Q statistic
Q <- sum(study_effects$weight * (study_effects$log_odds - pooled_fixed)^2)
df_Q <- nrow(study_effects) - 1
p_Q <- 1 - pchisq(Q, df_Q)

cat(sprintf("  Q statistic: %.2f (df = %d, p = %.4f)\n", Q, df_Q, p_Q))

# Use metafor REML for consistency with formal meta-analysis (script 19)
if (requireNamespace("metafor", quietly = TRUE)) {
  rma_model <- metafor::rma(yi = study_effects$log_odds,
                             vi = study_effects$var_log_odds,
                             method = "REML", test = "knha")
  tau_sq <- rma_model$tau2
  tau <- sqrt(tau_sq)
  I_sq <- rma_model$I2
  Q <- rma_model$QE
  p_Q <- rma_model$QEp   # Update p_Q to match metafor's Q (replaces stale manual value)
  Q_p <- p_Q              # Alias for backward compatibility
  pooled_random <- as.numeric(rma_model$beta)
  se_pooled_random <- rma_model$se

  cat(sprintf("  tau² (between-study variance, REML): %.4f\n", tau_sq))
  cat(sprintf("  tau (SD of true effects): %.4f\n", tau))

  # Get I-squared CI via Q-profile method
  i2_ci <- confint(rma_model)
  I_sq_ci_lower <- i2_ci$random["I^2(%)", "ci.lb"]
  I_sq_ci_upper <- i2_ci$random["I^2(%)", "ci.ub"]
  cat(sprintf("  I² = %.1f%% (95%% CI: %.1f%% - %.1f%%)\n",
              I_sq, I_sq_ci_lower, I_sq_ci_upper))

  # Pooled survival estimate using model's Knapp-Hartung CIs
  pooled_survival_random <- plogis(pooled_random)
  ci_lower_random <- plogis(rma_model$ci.lb)
  ci_upper_random <- plogis(rma_model$ci.ub)

  # Prediction interval from metafor (uses proper t-distribution)
  rma_pred <- predict(rma_model)
  pi_lower <- rma_pred$pi.lb
  pi_upper <- rma_pred$pi.ub
  pred_surv_lower <- plogis(pi_lower)
  pred_surv_upper <- plogis(pi_upper)
} else {
  # Fallback to DerSimonian-Laird (if metafor not available)
  C <- sum(study_effects$weight) - sum(study_effects$weight^2) / sum(study_effects$weight)
  tau_sq <- max(0, (Q - df_Q) / C)
  tau <- sqrt(tau_sq)

  cat(sprintf("  tau² (between-study variance, DL fallback): %.4f\n", tau_sq))
  cat(sprintf("  tau (SD of true effects): %.4f\n", tau))

  I_sq <- max(0, (Q - df_Q) / Q) * 100
  I_sq_ci_lower <- NA
  I_sq_ci_upper <- NA

  weight_re <- 1 / (study_effects$var_log_odds + tau_sq)
  pooled_random <- sum(weight_re * study_effects$log_odds) / sum(weight_re)
  se_pooled_random <- sqrt(1 / sum(weight_re))

  pooled_survival_random <- plogis(pooled_random)
  ci_lower_random <- plogis(pooled_random - 1.96 * se_pooled_random)
  ci_upper_random <- plogis(pooled_random + 1.96 * se_pooled_random)

  k <- nrow(study_effects)
  t_crit <- qt(0.975, df = max(1, k - 2))
  pi_lower <- pooled_random - t_crit * sqrt(se_pooled_random^2 + tau_sq)
  pi_upper <- pooled_random + t_crit * sqrt(se_pooled_random^2 + tau_sq)
  pred_surv_lower <- plogis(pi_lower)
  pred_surv_upper <- plogis(pi_upper)
}

# Interpretation thresholds
I_sq_interpretation <- case_when(
  I_sq < 25 ~ "Low heterogeneity",
  I_sq < 50 ~ "Moderate heterogeneity",
  I_sq < 75 ~ "Substantial heterogeneity",
  TRUE ~ "Considerable heterogeneity"
)

cat(sprintf("  I² (heterogeneity proportion): %.1f%% (%s)\n", I_sq, I_sq_interpretation))

cat(sprintf("\nRandom effects pooled survival: %.1f%% (95%% CI: %.1f%% - %.1f%%)\n",
            pooled_survival_random * 100, ci_lower_random * 100, ci_upper_random * 100))

k <- nrow(study_effects)
cat(sprintf("  95%% prediction interval: %.1f%% - %.1f%%\n",
            pred_surv_lower * 100, pred_surv_upper * 100))
cat("  NOTE: For applied use, the prediction interval is more informative than the CI.\n")
cat("  It reflects the range of survival expected in any new study population.\n")

# =============================================================================
# 3. MODERATOR ANALYSIS (Meta-Regression)
# =============================================================================

cat("\nAnalyzing potential moderators of heterogeneity...\n")

# Test moderators: size, fragment status
moderator_results <- list()

# 3a. Size as moderator
if (any(!is.na(study_effects$mean_size))) {
  # Preferred: metafor meta-regression (proper inverse-variance weighting)
  if (requireNamespace("metafor", quietly = TRUE)) {
    mr_size <- metafor::rma(yi = log_odds, vi = var_log_odds,
                            mods = ~log(mean_size), data = study_effects, method = "REML", test = "knha")
    size_coef <- mr_size$beta[2]
    size_p <- mr_size$pval[2]
    size_r2 <- max(0, mr_size$R2)  # metafor R2 is already a percentage (0-100); store as-is for consistency with script 14b
  } else {
    size_model <- lm(log_odds ~ log(mean_size), data = study_effects,
                     weights = weight)
    size_coef <- coef(size_model)[2]
    size_p <- summary(size_model)$coefficients[2, 4]
    size_r2 <- summary(size_model)$r.squared
  }

  moderator_results$size <- data.frame(
    moderator = "Mean colony size (log)",
    coefficient = size_coef,
    p_value = size_p,
    r_squared = size_r2,
    interpretation = ifelse(size_p < 0.05,
                            "Significant: size explains heterogeneity",
                            "Not significant")
  )

  cat(sprintf("  Size effect: coef = %.3f, p = %.3f, R² = %.1f%%\n",
              size_coef, size_p, size_r2))
}

# 3b. Fragment status as moderator
if (any(!is.na(study_effects$fragment_pct))) {
  # Preferred: metafor meta-regression (proper inverse-variance weighting)
  if (requireNamespace("metafor", quietly = TRUE)) {
    mr_frag <- metafor::rma(yi = log_odds, vi = var_log_odds,
                            mods = ~fragment_pct, data = study_effects, method = "REML", test = "knha")
    frag_coef <- mr_frag$beta[2]
    frag_p <- mr_frag$pval[2]
    frag_r2 <- max(0, mr_frag$R2)  # metafor R2 is already a percentage (0-100); store as-is for consistency with script 14b
  } else {
    frag_model <- lm(log_odds ~ fragment_pct, data = study_effects,
                     weights = weight)
    frag_coef <- coef(frag_model)[2]
    frag_p <- summary(frag_model)$coefficients[2, 4]
    frag_r2 <- summary(frag_model)$r.squared
  }

  moderator_results$fragment <- data.frame(
    moderator = "Fragment percentage",
    coefficient = frag_coef,
    p_value = frag_p,
    r_squared = frag_r2,
    interpretation = ifelse(frag_p < 0.05,
                            "Significant: fragment status explains heterogeneity",
                            "Not significant")
  )

  cat(sprintf("  Fragment effect: coef = %.4f, p = %.3f, R² = %.1f%%\n",
              frag_coef, frag_p, frag_r2))
}

# 3c. Year as moderator
# Preferred: metafor meta-regression (proper inverse-variance weighting)
if (requireNamespace("metafor", quietly = TRUE)) {
  mr_year <- metafor::rma(yi = log_odds, vi = var_log_odds,
                          mods = ~year_max, data = study_effects, method = "REML", test = "knha")
  year_coef <- mr_year$beta[2]
  year_p <- mr_year$pval[2]
  year_r2 <- max(0, mr_year$R2)  # metafor R2 is already a percentage (0-100); store as-is for consistency with script 14b
} else {
  year_model <- lm(log_odds ~ year_max, data = study_effects, weights = weight)
  year_coef <- coef(year_model)[2]
  year_p <- summary(year_model)$coefficients[2, 4]
  year_r2 <- summary(year_model)$r.squared
}

moderator_results$year <- data.frame(
  moderator = "Study year (most recent)",
  coefficient = year_coef,
  p_value = year_p,
  r_squared = year_r2,
  interpretation = ifelse(year_p < 0.05,
                          "Significant: temporal trend in survival",
                          "Not significant")
)

cat(sprintf("  Year effect: coef = %.4f, p = %.3f, R² = %.1f%%\n",
            year_coef, year_p, year_r2))

# Combine moderator results
moderator_df <- bind_rows(moderator_results)

# =============================================================================
# 3b. STRATIFIED HETEROGENEITY BY POPULATION TYPE
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  STRATIFIED HETEROGENEITY: Natural Colonies vs Fragments\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Calculate I² separately for each population type
strat_het_results <- list()

for (pop_type in unique(study_effects$population_type)) {
  subset <- study_effects %>% filter(population_type == pop_type)

  if (nrow(subset) >= 2) {
    # Use metafor REML when available (consistent with script 14b); fallback to manual DL
    if (requireNamespace("metafor", quietly = TRUE) && nrow(subset) >= 3) {
      sub_rma <- metafor::rma(yi = subset$log_odds, vi = subset$var_log_odds, method = "REML")
      I_sq_sub <- sub_rma$I2
      Q_sub <- sub_rma$QE
      df_sub <- nrow(subset) - 1
      p_sub <- sub_rma$QEp
      tau_sq_sub <- sub_rma$tau2
    } else {
      # Fallback to manual DL for k=2 or when metafor is unavailable
      pooled_fix <- sum(subset$weight * subset$log_odds) / sum(subset$weight)
      Q_sub <- sum(subset$weight * (subset$log_odds - pooled_fix)^2)
      df_sub <- nrow(subset) - 1
      p_sub <- 1 - pchisq(Q_sub, df_sub)
      I_sq_sub <- max(0, (Q_sub - df_sub) / Q_sub) * 100
      C_sub <- sum(subset$weight) - sum(subset$weight^2) / sum(subset$weight)
      tau_sq_sub <- max(0, (Q_sub - df_sub) / C_sub)
    }

    cat(sprintf("  %s:\n", pop_type))
    cat(sprintf("    n_studies = %d, n_obs = %d\n", nrow(subset), sum(subset$n)))
    cat(sprintf("    I² = %.1f%%, Q = %.2f (p = %.3f)\n", I_sq_sub, Q_sub, p_sub))
    cat(sprintf("    Mean survival = %.1f%%\n", mean(subset$survival_rate) * 100))

    strat_het_results[[pop_type]] <- tibble(
      population_type = pop_type,
      n_studies = nrow(subset),
      n_observations = sum(subset$n),
      mean_survival = mean(subset$survival_rate),
      I_squared = I_sq_sub,
      Q_statistic = Q_sub,
      Q_p_value = p_sub,
      tau_squared = tau_sq_sub
    )
  } else {
    cat(sprintf("  %s: Insufficient data (n_studies = %d)\n", pop_type, nrow(subset)))
  }
}

strat_het_df <- bind_rows(strat_het_results)
if (nrow(strat_het_df) > 0) {
  write_csv(strat_het_df, file.path(output_dir, "heterogeneity_by_population.csv"))
  cat("\n  ✓ Saved: heterogeneity_by_population.csv\n")
}

# =============================================================================
# 4. HETEROGENEITY BY SIZE CLASS
# =============================================================================

cat("\nAnalyzing heterogeneity by size class...\n")

size_class_het <- surv_data %>%
  group_by(size_class, study) %>%
  summarise(
    n = n(),
    n_survived = sum(survived),
    survival_rate = mean(survived),
    .groups = "drop"
  ) %>%
  filter(n >= 5) %>%
  group_by(size_class) %>%
  summarise(
    n_studies = n(),
    n_total = sum(n),
    mean_survival = mean(survival_rate),
    sd_survival = sd(survival_rate),
    cv_survival = sd_survival / mean_survival,
    min_survival = min(survival_rate),
    max_survival = max(survival_rate),
    range_survival = max_survival - min_survival,
    .groups = "drop"
  ) %>%
  mutate(
    # Rough I² proxy: CV indicates heterogeneity
    heterogeneity_flag = ifelse(cv_survival > 0.3, "High", "Moderate")
  )

cat("\nHeterogeneity by size class:\n")
print(as.data.frame(size_class_het %>%
                      select(size_class, n_studies, n_total, mean_survival,
                             cv_survival, range_survival, heterogeneity_flag)))

# Save size-class heterogeneity table
write_csv(size_class_het, file.path(output_dir, "heterogeneity_by_size_class.csv"))
cat("  Saved: heterogeneity_by_size_class.csv\n")

# =============================================================================
# 5. COMPILE HETEROGENEITY SUMMARY
# =============================================================================

cat("\nCompiling heterogeneity analysis summary...\n")

heterogeneity_summary <- data.frame(
  metric = c("Q statistic", "Q degrees of freedom", "Q p-value",
             "tau² (between-study variance)", "tau (SD of true effects)",
             "I² (heterogeneity proportion)", "I² 95% CI lower", "I² 95% CI upper",
             "I² interpretation",
             "Pooled survival (random effects)", "95% CI lower", "95% CI upper",
             "Prediction interval lower", "Prediction interval upper",
             "Number of studies", "Total observations"),
  value = c(sprintf("%.2f", Q), df_Q, sprintf("%.4f", p_Q),
            sprintf("%.4f", tau_sq), sprintf("%.4f", tau),
            sprintf("%.1f%%", I_sq),
            ifelse(is.na(I_sq_ci_lower), "NA", sprintf("%.1f%%", I_sq_ci_lower)),
            ifelse(is.na(I_sq_ci_upper), "NA", sprintf("%.1f%%", I_sq_ci_upper)),
            I_sq_interpretation,
            sprintf("%.1f%%", pooled_survival_random * 100),
            sprintf("%.1f%%", ci_lower_random * 100),
            sprintf("%.1f%%", ci_upper_random * 100),
            sprintf("%.1f%%", pred_surv_lower * 100),
            sprintf("%.1f%%", pred_surv_upper * 100),
            nrow(study_effects), sum(study_effects$n))
)

# Save outputs
write_csv(heterogeneity_summary, file.path(output_dir, "heterogeneity_analysis.csv"))
cat("  ✓ Saved: heterogeneity_analysis.csv\n")

write_csv(study_effects, file.path(output_dir, "study_effect_sizes.csv"))
cat("  ✓ Saved: study_effect_sizes.csv\n")

write_csv(moderator_df, file.path(output_dir, "moderator_effects.csv"))
cat("  ✓ Saved: moderator_effects.csv\n")

# =============================================================================
# 6. CREATE FOREST PLOT WITH HETEROGENEITY
# =============================================================================

cat("\nCreating forest plot with heterogeneity annotations...\n")

# Prepare data for forest plot
study_effects_plot <- study_effects %>%
  arrange(survival_rate) %>%
  mutate(
    study_label = paste0(study, " (", region, ")"),
    study_label = factor(study_label, levels = study_label),
    weight_scaled = weight / max(weight) * 3  # Scale for plotting
  )

# Create forest plot
p_forest <- ggplot(study_effects_plot, aes(y = study_label)) +
  # Study-level estimates
  geom_point(aes(x = survival_rate, size = n),
             color = "steelblue", alpha = 0.8) +
  geom_errorbarh(aes(xmin = prob_lower, xmax = prob_upper),
                 height = 0.2, color = "steelblue", alpha = 0.6) +
  # Pooled estimate (diamond)
  geom_vline(xintercept = pooled_survival_random, linetype = "dashed",
             color = "coral", linewidth = 1) +
  # Prediction interval (shaded)
  annotate("rect", xmin = pred_surv_lower, xmax = pred_surv_upper,
           ymin = -Inf, ymax = Inf, alpha = 0.1, fill = "coral") +
  # Labels
  scale_x_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_size_continuous(range = c(2, 8), name = "Sample size") +
  labs(
    title = "Forest Plot: Survival Estimates by Study",
    subtitle = sprintf("Random effects model | I² = %.1f%% (%s)\nPooled survival = %.1f%% (95%% CI: %.1f%%-%.1f%%)",
                       I_sq, I_sq_interpretation,
                       pooled_survival_random * 100,
                       ci_lower_random * 100,
                       ci_upper_random * 100),
    x = "Survival rate",
    y = "",
    caption = sprintf("Dashed line: pooled estimate | Shaded region: 95%% prediction interval\nQ = %.2f (p = %.4f) | tau = %.3f",
                      Q, p_Q, tau)
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold"),
    panel.grid.major.y = element_blank(),
    legend.position = "bottom"
  )

ggsave(file.path(fig_dir, "heterogeneity_forest_plot.png"),
       p_forest, width = 10, height = 8, dpi = 300)
cat("  ✓ Saved: supplementary/exploratory/heterogeneity_forest_plot.png\n")

# =============================================================================
# 7. IMPLICATIONS FOR POOLED ESTIMATES
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  HETEROGENEITY ANALYSIS COMPLETE                             ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("KEY FINDINGS:\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat(sprintf("  I² = %.1f%% → %s\n", I_sq, I_sq_interpretation))
cat(sprintf("  Q test: p = %.4f → %s\n", p_Q,
            ifelse(p_Q < 0.05, "Significant heterogeneity detected",
                   "No significant heterogeneity")))
cat(sprintf("  Prediction interval: %.1f%% to %.1f%%\n",
            pred_surv_lower * 100, pred_surv_upper * 100))

cat("\nIMPLICATIONS:\n")
if (I_sq > 75) {
  cat("  ⚠ CONSIDERABLE HETEROGENEITY detected between studies.\n")
  cat("  → Pooled estimates should be interpreted with caution.\n")
  cat("  → Stratified analyses by study/context are preferred.\n")
  cat("  → Wide prediction interval indicates true effects vary substantially.\n")
} else if (I_sq > 50) {
  cat("  ⚠ SUBSTANTIAL HETEROGENEITY detected between studies.\n")
  cat("  → Consider stratifying by moderators (size, fragment status).\n")
  cat("  → Report prediction intervals alongside confidence intervals.\n")
} else if (I_sq > 25) {
  cat("  ℹ MODERATE HETEROGENEITY detected.\n")
  cat("  → Pooled estimates are usable with appropriate caveats.\n")
} else {
  cat("  ✓ LOW HETEROGENEITY - pooling is appropriate.\n")
}

cat("\nMODERATOR ANALYSIS:\n")
for (i in 1:nrow(moderator_df)) {
  cat(sprintf("  %s: %s (p = %.3f, R² = %.1f%%)\n",
              moderator_df$moderator[i],
              moderator_df$interpretation[i],
              moderator_df$p_value[i],
              moderator_df$r_squared[i]))
}

cat("\nOutputs:\n")
cat("  - heterogeneity_analysis.csv (summary statistics)\n")
cat("  - study_effect_sizes.csv (study-level estimates)\n")
cat("  - moderator_effects.csv (meta-regression results)\n")
cat("  - heterogeneity_forest_plot.png (visualization)\n\n")

# =============================================================================
# 8. MORTALITY DEFINITION AS MODERATOR (Tier 1 individual-level studies only)
# =============================================================================
# FIX: Add mortality definition as moderator (critique audit 2026-03-29)
# Mortality definitions vary across studies (CLAUDE.md Critical Constraints):
#   NOAA = no tissue/skeleton gone
#   Kuffner = >=50% tissue loss (most liberal)
#   Others = no live tissue at interval end

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  MORTALITY DEFINITION MODERATOR ANALYSIS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

mortality_def <- data.frame(
  study = c("NOAA_survey", "kuffner_et_al_2020", "pausch_et_al_2018",
            "USGS_USVI_exp", "mendoza_quiroz_et_al_2023", "fundemar_fragments"),
  mort_definition = c("no_tissue_or_skeleton_gone", "ge_50pct_tissue_loss",
                       "complete_or_missing", "no_live_tissue", "no_live_tissue", "no_live_tissue"),
  stringsAsFactors = FALSE
)

# Merge with study-level effects (Tier 1 only)
study_effects_mort <- merge(study_effects, mortality_def, by = "study", all.x = TRUE)
has_mort_data <- sum(!is.na(study_effects_mort$mort_definition))

cat(sprintf("  Studies with mortality definition: %d / %d\n",
            has_mort_data, nrow(study_effects_mort)))

if (has_mort_data >= 3 && requireNamespace("metafor", quietly = TRUE)) {
  # Only keep studies with mortality definition data
  study_effects_mort_valid <- study_effects_mort %>%
    filter(!is.na(mort_definition))

  cat("\n  Mortality definitions in Tier 1 studies:\n")
  print(table(study_effects_mort_valid$mort_definition))

  # Meta-regression with mortality definition as moderator
  # Only feasible if there are at least 2 levels with data
  n_levels <- length(unique(study_effects_mort_valid$mort_definition))
  if (n_levels >= 2 && nrow(study_effects_mort_valid) >= 3) {
    mr_mort <- tryCatch({
      metafor::rma(yi = log_odds, vi = var_log_odds,
                   mods = ~mort_definition,
                   data = study_effects_mort_valid,
                   method = "REML", test = "knha")
    }, error = function(e) {
      cat(sprintf("  Meta-regression failed: %s\n", e$message))
      NULL
    })

    if (!is.null(mr_mort)) {
      cat(sprintf("\n  Mortality definition moderator test (QM): %.2f, p = %.4f\n",
                  mr_mort$QM, mr_mort$QMp))
      cat(sprintf("  R² (variance explained by mortality definition): %.1f%%\n",
                  max(0, mr_mort$R2)))
      cat("\n  Coefficients:\n")
      print(coef(summary(mr_mort)))

      # Add to moderator results
      mort_mod_result <- data.frame(
        moderator = "Mortality definition",
        coefficient = NA_real_,  # categorical moderator, no single coefficient
        p_value = mr_mort$QMp,
        r_squared = max(0, mr_mort$R2),
        interpretation = ifelse(mr_mort$QMp < 0.05,
                                "Significant: mortality definition explains heterogeneity",
                                "Not significant: mortality definition does not explain heterogeneity")
      )

      # Append to moderator_df and re-save
      moderator_df <- bind_rows(moderator_df, mort_mod_result)
      write_csv(moderator_df, file.path(output_dir, "moderator_effects.csv"))
      cat("  Updated: moderator_effects.csv (with mortality definition)\n")
    }
  } else {
    cat(sprintf("  Insufficient levels (%d) or studies (%d) for mortality definition meta-regression\n",
                n_levels, nrow(study_effects_mort_valid)))
  }
} else {
  if (has_mort_data < 3) {
    cat("  Fewer than 3 studies with mortality definition data — skipping meta-regression\n")
  } else {
    cat("  metafor package not available — skipping mortality definition analysis\n")
  }
}

# =============================================================================
# 9. FDR CORRECTION FOR MULTIPLE MODERATOR TESTS
# =============================================================================
# FIX: FDR correction for multiple moderator tests (critique audit 2026-03-29)
# Script 14b tests population_type, colony_size, study_year, region as moderators.
# Script 15 tests size, fragment_pct, year, and now mortality_definition.
# Apply Benjamini-Hochberg FDR correction to all moderator p-values.

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  FDR CORRECTION FOR MODERATOR TESTS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Collect p-values from this script's moderator tests
if (nrow(moderator_df) > 0 && "p_value" %in% names(moderator_df)) {
  local_pvals <- moderator_df$p_value
  local_names <- moderator_df$moderator

  # Also try to load expanded meta-analysis moderator p-values (from script 14b)
  expanded_mod_file <- file.path(output_dir, "expanded_meta_analysis_moderators.csv")
  if (file.exists(expanded_mod_file)) {
    expanded_mods <- read_csv(expanded_mod_file, show_col_types = FALSE)
    if ("p_value" %in% names(expanded_mods) && "moderator" %in% names(expanded_mods)) {
      # Combine p-values from both sources, avoiding duplicates by moderator name
      combined_names <- c(local_names, expanded_mods$moderator)
      combined_pvals <- c(local_pvals, expanded_mods$p_value)

      # De-duplicate: if the same moderator appears in both, keep the expanded meta version
      dup_idx <- duplicated(combined_names, fromLast = TRUE)
      combined_names <- combined_names[!dup_idx]
      combined_pvals <- combined_pvals[!dup_idx]
    } else {
      combined_names <- local_names
      combined_pvals <- local_pvals
    }
  } else {
    combined_names <- local_names
    combined_pvals <- local_pvals
    cat("  NOTE: expanded_meta_analysis_moderators.csv not found.\n")
    cat("  FDR correction applied to script 15 moderators only.\n\n")
  }

  # Apply Benjamini-Hochberg FDR correction
  valid_mask <- !is.na(combined_pvals)
  if (sum(valid_mask) >= 2) {
    fdr_adjusted <- rep(NA_real_, length(combined_pvals))
    fdr_adjusted[valid_mask] <- p.adjust(combined_pvals[valid_mask], method = "BH")

    fdr_table <- data.frame(
      moderator = combined_names,
      raw_p = combined_pvals,
      fdr_p = fdr_adjusted,
      significant_raw = combined_pvals < 0.05,
      significant_fdr = fdr_adjusted < 0.05,
      stringsAsFactors = FALSE
    )

    cat("FDR-adjusted moderator p-values (Benjamini-Hochberg):\n")
    print(fdr_table)

    # Flag any results that change significance after FDR
    flipped <- fdr_table %>%
      filter(significant_raw != significant_fdr)
    if (nrow(flipped) > 0) {
      cat("\n  WARNING: The following moderators change significance after FDR correction:\n")
      for (i in seq_len(nrow(flipped))) {
        cat(sprintf("    %s: raw p = %.4f -> FDR p = %.4f\n",
                    flipped$moderator[i], flipped$raw_p[i], flipped$fdr_p[i]))
      }
    } else {
      cat("\n  No moderator tests change significance after FDR correction.\n")
    }

    # Save FDR-corrected results
    write_csv(fdr_table, file.path(output_dir, "moderator_fdr_correction.csv"))
    cat("  Saved: moderator_fdr_correction.csv\n")
  } else {
    cat("  Fewer than 2 valid moderator p-values — FDR correction not applicable.\n")
  }
} else {
  cat("  No moderator results available — FDR correction skipped.\n")
}

# =============================================================================
# 10. TEMPORAL TREND IN SURVIVAL (expanded meta, study year meta-regression)
# =============================================================================
# FIX: Temporal trend in survival via expanded meta study effects (critique audit 2026-03-29)
# Script 14b already runs this on the expanded meta (k=18). Here we run it on the
# Tier 1 individual-level studies (k=5) for comparison and to keep script 15 self-contained.

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  TEMPORAL TREND (STUDY YEAR META-REGRESSION, k=5)\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

if (requireNamespace("metafor", quietly = TRUE) && "year_max" %in% names(study_effects)) {
  temporal_mod <- tryCatch({
    metafor::rma(yi = log_odds, vi = var_log_odds,
                 mods = ~year_max,
                 data = study_effects,
                 method = "REML", test = "knha")
  }, error = function(e) {
    cat(sprintf("  Temporal meta-regression failed: %s\n", e$message))
    NULL
  })

  if (!is.null(temporal_mod)) {
    cat(sprintf("  Slope (log-odds per year): %.4f (SE: %.4f)\n",
                temporal_mod$beta[2], temporal_mod$se[2]))
    cat(sprintf("  p-value: %.4f\n", temporal_mod$pval[2]))
    cat(sprintf("  R² (variance explained): %.1f%%\n", max(0, temporal_mod$R2)))

    if (temporal_mod$pval[2] < 0.05) {
      direction <- ifelse(temporal_mod$beta[2] > 0, "improving", "declining")
      cat(sprintf("  Significant temporal trend: survival %s over time\n", direction))
    } else {
      cat("  No significant temporal trend detected in Tier 1 studies\n")
    }

    # Also check expanded meta (k=18) if available
    expanded_file <- file.path(output_dir, "expanded_meta_analysis_study_effects.csv")
    if (file.exists(expanded_file)) {
      expanded_es <- read_csv(expanded_file, show_col_types = FALSE)
      if (all(c("log_odds", "var_log_odds", "survey_yr") %in% names(expanded_es))) {
        temporal_expanded <- tryCatch({
          metafor::rma(yi = log_odds, vi = var_log_odds,
                       mods = ~survey_yr,
                       data = expanded_es,
                       method = "REML", test = "knha")
        }, error = function(e) NULL)

        if (!is.null(temporal_expanded)) {
          cat(sprintf("\n  Expanded meta (k=%d): slope = %.4f, p = %.4f, R² = %.1f%%\n",
                      nrow(expanded_es), temporal_expanded$beta[2],
                      temporal_expanded$pval[2], max(0, temporal_expanded$R2)))
        }
      }
    }
  }
} else {
  cat("  metafor not available or year_max not in study_effects — skipping\n")
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  EXTENDED HETEROGENEITY ANALYSIS COMPLETE                    ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")
