#!/usr/bin/env Rscript
################################################################################
# 23_VERIFICATION.R
# Statistical Output Verification for Publication Figures
# Extracts canonical values to ensure figure annotations are correct
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════════════╗\n")
cat("║  📊 STATISTICAL OUTPUT VERIFICATION                                   ║\n")
cat("║  Canonical values for publication figure annotations                  ║\n")
cat("╚═══════════════════════════════════════════════════════════════════════╝\n\n")

# Set paths
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

# ==============================================================================
# SURVIVAL ANALYSIS
# ==============================================================================

cat("═══════════════════════════════════════════════════════════════════════\n")
cat("SURVIVAL ANALYSIS (Natural Colonies Only)\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))

# Filter to natural colonies (exclude restoration fragments)
if ("population_type" %in% names(surv_data)) {
  surv_nat <- surv_data %>% filter(population_type == "Natural colony")
} else {
  surv_nat <- surv_data %>% filter(fragment != "Y" | is.na(fragment))
}

surv_nat <- surv_nat %>% filter(!is.na(log_size), !is.na(survived))

n_surv <- nrow(surv_nat)
n_studies <- n_distinct(surv_nat$study)

cat(sprintf("Sample Size: n = %d observations from %d studies\n\n", n_surv, n_studies))

# Fit logistic regression
glm_surv <- glm(survived ~ log_size, data = surv_nat, family = binomial)

# Odds Ratio
or_val <- exp(coef(glm_surv)[2])
or_ci <- exp(confint.default(glm_surv)[2, ])

cat("Logistic Regression: survived ~ log_size\n")
cat(sprintf("  Odds Ratio: %.3f\n", or_val))
cat(sprintf("  95%% CI: (%.3f, %.3f)\n", or_ci[1], or_ci[2]))
cat(sprintf("  Interpretation: Each 1-unit increase in log(size) multiplies\n"))
cat(sprintf("                  survival odds by %.2f\n\n", or_val))

# Pseudo R-squared (Tjur's D)
pred_probs <- predict(glm_surv, type = "response")
tjur_d <- abs(mean(pred_probs[surv_nat$survived == 1]) -
              mean(pred_probs[surv_nat$survived == 0]))

# McFadden R-squared
null_model <- glm(survived ~ 1, data = surv_nat, family = binomial)
mcfadden_r2 <- 1 - (logLik(glm_surv)[1] / logLik(null_model)[1])

# Nagelkerke R-squared
cox_snell <- 1 - exp((logLik(null_model)[1] - logLik(glm_surv)[1]) * (2/n_surv))
max_r2 <- 1 - exp(logLik(null_model)[1] * (2/n_surv))
nagelkerke_r2 <- cox_snell / max_r2

cat("Pseudo R-squared Variants:\n")
cat(sprintf("  Tjur's D:      %.4f (%.1f%%)  ← RECOMMENDED for figures\n", tjur_d, tjur_d * 100))
cat(sprintf("  McFadden:      %.4f (%.1f%%)\n", mcfadden_r2, mcfadden_r2 * 100))
cat(sprintf("  Nagelkerke:    %.4f (%.1f%%)\n", nagelkerke_r2, nagelkerke_r2 * 100))
cat("\n")
cat("  📝 Note: Tjur's D directly measures discrimination ability (difference\n")
cat("           in predicted probabilities between survived=1 and survived=0)\n\n")

# P-value
p_val <- summary(glm_surv)$coefficients[2, 4]
cat(sprintf("  P-value: %s\n\n", ifelse(p_val < 0.001, "p < 0.001", sprintf("p = %.4f", p_val))))

# GAM fit
suppressPackageStartupMessages(library(mgcv))
# k=4 following Samhouri et al. (2017) framework
gam_surv <- gam(survived ~ s(log_size, k = 4), data = surv_nat,
                family = binomial, method = "REML")
gam_dev <- summary(gam_surv)$dev.expl * 100
gam_edf <- sum(summary(gam_surv)$edf)

cat("GAM Fit: survived ~ s(log_size, k=4)\n")
cat(sprintf("  Deviance Explained: %.1f%%\n", gam_dev))
cat(sprintf("  Effective Degrees of Freedom: %.2f\n\n", gam_edf))

# Size class breakdown
sc_surv <- surv_nat %>%
  mutate(sc = gsub("_.*", "", size_class)) %>%
  group_by(sc) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    .groups = "drop"
  )

cat("Survival by Size Class:\n")
for (i in 1:nrow(sc_surv)) {
  cat(sprintf("  %s: %.1f%% (n = %d, SE = %.3f)\n",
              sc_surv$sc[i], sc_surv$survival[i] * 100,
              sc_surv$n[i], sc_surv$se[i]))
}

cat("\n")

# ==============================================================================
# GROWTH ANALYSIS
# ==============================================================================

cat("═══════════════════════════════════════════════════════════════════════\n")
cat("GROWTH ANALYSIS (Canonical Values from 04_growth_rate_comparison.R)\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

growth_summary_file <- file.path(output_dir, "growth_rate_summary.csv")

if (file.exists(growth_summary_file)) {
  growth_summary <- read_csv(growth_summary_file, show_col_types = FALSE)

  cat("Source: 06_analysis/output/growth_rate_summary.csv\n\n")

  agr_r2 <- growth_summary$r_squared[growth_summary$metric == "AGR"]
  rgr_r2 <- growth_summary$r_squared[growth_summary$metric == "RGR"]

  if (length(agr_r2) > 0 && length(rgr_r2) > 0) {
    improvement <- rgr_r2 / agr_r2

    cat(sprintf("Sample Size: n = %d growth observations\n\n",
                growth_summary$n_observations[1]))

    cat("R-squared Values (size ~ log_size relationship):\n")
    cat(sprintf("  Absolute Growth Rate (AGR): %.4f (%.1f%%)\n", agr_r2, agr_r2 * 100))
    cat(sprintf("  Relative Growth Rate (RGR): %.4f (%.1f%%)\n", rgr_r2, rgr_r2 * 100))
    cat(sprintf("  Improvement Factor: %.0fx\n\n", improvement))

    cat(sprintf("  Note: RGR explains %.0fx more variance than AGR because it accounts\n", improvement))
    cat("           for negative allometry (small colonies grow relatively faster)\n\n")

    # Thresholds
    rgr_threshold <- growth_summary$threshold_cm2[growth_summary$metric == "RGR"]
    if (length(rgr_threshold) > 0) {
      cat(sprintf("  RGR Threshold: %.1f cm² (where growth pattern changes most)\n\n",
                  rgr_threshold))
    }
  } else {
    cat("  ⚠ Warning: AGR/RGR metrics not found in growth_rate_summary.csv\n\n")
  }
} else {
  cat("  ⚠ Warning: growth_rate_summary.csv not found\n")
  cat("             Run 04_growth_rate_comparison.R first\n\n")
}

# Load raw growth data for size class breakdown
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

# Apply canonical filtering from 03b
if ("impossible_growth" %in% names(growth_data)) {
  growth_clean <- growth_data %>% filter(!impossible_growth)
} else {
  growth_clean <- growth_data %>%
    filter(!((growth_cm2_yr < 0) & (abs(growth_cm2_yr) > size_cm2 * 1.1)))
}

growth_clean <- growth_clean %>%
  filter(!is.na(size_cm2), size_cm2 > 0, !is.na(growth_cm2_yr))

if (!"rgr" %in% names(growth_clean)) {
  growth_clean <- growth_clean %>% mutate(rgr = growth_cm2_yr / size_cm2)
}

growth_clean <- growth_clean %>%
  mutate(positive = growth_cm2_yr > 0,
         sc = gsub("_.*", "", size_class)) %>%
  filter(!is.na(rgr), is.finite(rgr))

cat("Growth Summary by Size Class:\n")
sc_growth <- growth_clean %>%
  group_by(sc) %>%
  summarise(
    n = n(),
    mean_agr = mean(growth_cm2_yr),
    mean_rgr = mean(rgr),
    pct_positive = mean(positive) * 100,
    .groups = "drop"
  )

for (i in 1:nrow(sc_growth)) {
  cat(sprintf("  %s: AGR = %+.1f cm²/yr, RGR = %.2f yr⁻¹, %.0f%% positive (n = %d)\n",
              sc_growth$sc[i], sc_growth$mean_agr[i], sc_growth$mean_rgr[i],
              sc_growth$pct_positive[i], sc_growth$n[i]))
}

cat("\n")

# ==============================================================================
# POPULATION MATRIX & LAMBDA
# ==============================================================================

cat("═══════════════════════════════════════════════════════════════════════\n")
cat("POPULATION MATRIX MODEL\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

lambda_file <- file.path(output_dir, "lambda_bootstrap_samples.rds")

if (file.exists(lambda_file)) {
  lambda_samples <- readRDS(lambda_file)

  lambda_mean <- mean(lambda_samples)
  lambda_median <- median(lambda_samples)
  lambda_sd <- sd(lambda_samples)
  lambda_ci <- quantile(lambda_samples, c(0.025, 0.975))
  p_decline <- mean(lambda_samples < 1) * 100
  annual_decline <- (1 - lambda_mean) * 100

  cat(sprintf("Bootstrap Samples: n = %d replicates\n\n", length(lambda_samples)))

  cat("Population Growth Rate (Lambda):\n")
  cat(sprintf("  Mean:   %.4f\n", lambda_mean))
  cat(sprintf("  Median: %.4f\n", lambda_median))
  cat(sprintf("  SD:     %.4f\n", lambda_sd))
  cat(sprintf("  95%% CI: (%.3f, %.3f)\n\n", lambda_ci[1], lambda_ci[2]))

  cat("Interpretation:\n")
  cat(sprintf("  P(Decline): %.1f%% (%.0f of %d bootstrap replicates < 1)\n",
              p_decline, sum(lambda_samples < 1), length(lambda_samples)))
  cat(sprintf("  Annual Decline Rate: %.2f%% per year\n", annual_decline))
  cat(sprintf("  Time to 50%% population: %.1f years (at mean rate)\n\n",
              log(0.5) / log(lambda_mean)))

} else {
  cat("  ⚠ Warning: lambda_bootstrap_samples.rds not found\n")
  cat("             Run 13_transition_matrix.R first\n\n")
}

# Elasticity
elast_file <- file.path(output_dir, "elasticity_matrix.csv")

if (file.exists(elast_file)) {
  elast_df <- read_csv(elast_file, show_col_types = FALSE)
  names(elast_df)[1] <- "from"

  elast_long <- elast_df %>%
    pivot_longer(-from, names_to = "to", values_to = "elast")

  max_elast <- elast_long %>% filter(elast == max(elast, na.rm = TRUE))

  cat("Elasticity Analysis:\n")
  cat(sprintf("  Maximum Elasticity: %.1f%% (%s → %s)\n",
              max_elast$elast[1] * 100, max_elast$from[1], max_elast$to[1]))
  cat("  Interpretation: Large adult survival (SC5 stasis) is the most\n")
  cat("                  influential parameter for population growth\n\n")

  # Elasticity by transition type
  elast_type <- elast_long %>%
    mutate(type = case_when(
      from == to ~ "Stasis",
      to > from ~ "Growth",
      TRUE ~ "Retrogression"
    )) %>%
    group_by(type) %>%
    summarise(total = sum(elast, na.rm = TRUE), .groups = "drop")

  cat("  Elasticity by Transition Type:\n")
  for (i in 1:nrow(elast_type)) {
    cat(sprintf("    %s: %.1f%%\n", elast_type$type[i], elast_type$total[i] * 100))
  }

  cat("\n")
}

# ==============================================================================
# META-ANALYSIS
# ==============================================================================

cat("═══════════════════════════════════════════════════════════════════════\n")
cat("META-ANALYSIS (Study-Level Heterogeneity)\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

meta_file <- file.path(output_dir, "meta_analysis_results.csv")

if (file.exists(meta_file)) {
  meta_results <- read_csv(meta_file, show_col_types = FALSE)

  cat("Source: 06_analysis/output/meta_analysis_results.csv\n\n")

  # Extract key statistics
  get_meta_stat <- function(stat_name) {
    val <- meta_results$value[meta_results$statistic == stat_name]
    if (length(val) > 0) val[1] else NA
  }

  k_studies <- get_meta_stat("Number of studies (k)")
  n_obs <- get_meta_stat("Total observations (N)")
  pooled_surv <- get_meta_stat("Pooled survival (RE)")
  ci_lower <- get_meta_stat("95% CI lower")
  ci_upper <- get_meta_stat("95% CI upper")
  pi_lower <- get_meta_stat("95% PI lower")
  pi_upper <- get_meta_stat("95% PI upper")
  i_squared <- get_meta_stat("I² (%)")
  i2_ci_lower <- get_meta_stat("I² 95% CI lower")
  i2_ci_upper <- get_meta_stat("I² 95% CI upper")
  tau2 <- get_meta_stat("tau² (between-study variance)")
  cochran_q <- get_meta_stat("Cochran's Q")
  q_pval <- get_meta_stat("Q p-value")

  cat(sprintf("Studies Included: k = %.0f (n = %.0f observations)\n\n", k_studies, n_obs))

  cat("Random Effects Model:\n")
  cat(sprintf("  Pooled Survival: %.1f%%\n", pooled_surv * 100))
  cat(sprintf("  95%% Confidence Interval: (%.1f%%, %.1f%%)\n",
              ci_lower * 100, ci_upper * 100))
  cat(sprintf("  95%% Prediction Interval: (%.1f%%, %.1f%%)\n\n",
              pi_lower * 100, pi_upper * 100))

  cat("  📝 Note: Confidence interval shows precision of pooled estimate\n")
  cat("           Prediction interval shows expected range for NEW study\n\n")

  cat("Heterogeneity Assessment:\n")
  cat(sprintf("  I² = %.1f%% (95%% CI: %.1f%% - %.1f%%)\n", i_squared, i2_ci_lower, i2_ci_upper))
  cat(sprintf("  τ² = %.4f (between-study variance)\n", tau2))
  cat(sprintf("  Cochran's Q = %.2f (p %s)\n\n",
              cochran_q, ifelse(q_pval < 0.001, "< 0.001", sprintf("= %.4f", q_pval))))

  cat("  Interpretation:\n")
  if (i_squared > 75) {
    cat("    I² > 75%: CONSIDERABLE heterogeneity\n")
    cat("    Pooled estimate may not be generalizable across contexts\n")
    cat("    Stratified analysis by study/region is strongly recommended\n\n")
  } else if (i_squared > 50) {
    cat("    I² > 50%: MODERATE heterogeneity\n")
    cat("    Explore sources of variation (moderator analysis)\n\n")
  } else {
    cat("    I² < 50%: LOW heterogeneity\n")
    cat("    Pooled estimate is reasonably robust\n\n")
  }

} else {
  cat("  ⚠ Warning: meta_analysis_results.csv not found\n")
  cat("             Run 14_meta_analysis.R first\n\n")
}

# ==============================================================================
# THRESHOLD ANALYSIS
# ==============================================================================

cat("═══════════════════════════════════════════════════════════════════════\n")
cat("THRESHOLD ANALYSIS (Survival Size Threshold)\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

threshold_file <- file.path(output_dir, "survival_thresholds.csv")

if (file.exists(threshold_file)) {
  threshold_data <- read_csv(threshold_file, show_col_types = FALSE)

  cat("Source: 06_analysis/output/survival_thresholds.csv\n\n")

  # Detmer et al. (2025) framework columns
  gate_passed <- threshold_data$gate_passed[1]
  gate_aicc <- threshold_data$gate_delta_aicc[1]
  gate_mod <- threshold_data$gate_best_mod[1]
  func_form <- threshold_data$functional_form[1]
  rec_def <- threshold_data$recommended_definition[1]
  rec_cm2 <- threshold_data$recommended_threshold_cm2[1]
  rec_log <- threshold_data$recommended_threshold_log[1]

  cat("Detmer et al. (2025) Threshold Detection:\n")
  cat(sprintf("  Nonlinearity gate: %s (delta AICc = %.1f, passed = %s)\n",
              gate_mod, gate_aicc, gate_passed))
  cat(sprintf("  Functional form: %s\n", func_form))
  cat(sprintf("  Recommended definition: %s\n", rec_def))
  cat(sprintf("  Recommended threshold: %.1f cm² (log = %.2f)\n\n", rec_cm2, rec_log))

  # All 4 definitions
  cat("  All threshold definitions:\n")
  t1 <- threshold_data$t1_abs_max_d2_cm2[1]
  t2 <- threshold_data$t2_min_d2_cm2[1]
  t3 <- threshold_data$t3_zero_d2_cm2[1]
  t4 <- threshold_data$t4_zero_d1_cm2[1]
  cat(sprintf("    T1 (max|s''|):  %.0f cm²\n", t1))
  cat(sprintf("    T2 (min s''):   %.0f cm²\n", t2))
  cat(sprintf("    T3 (s''=0):     %.0f cm²\n", t3))
  cat(sprintf("    T4 (s'=0):      %s cm²\n", ifelse(is.na(t4), "NA", sprintf("%.0f", t4))))

  # LOSO results if available
  loso_n <- threshold_data$loso_n_folds[1]
  if (!is.na(loso_n) && loso_n > 0) {
    cat(sprintf("\n  LOSO jackknife: %d folds\n", loso_n))
    cat(sprintf("    Mean: %.2f log (%.0f cm²)\n",
                threshold_data$loso_threshold_mean[1],
                exp(threshold_data$loso_threshold_mean[1])))
    cat(sprintf("    SE: %.2f\n", threshold_data$loso_threshold_se[1]))
    cat(sprintf("    95%% CI: (%.0f, %.0f cm²)\n",
                exp(threshold_data$loso_ci_lower[1]),
                exp(threshold_data$loso_ci_upper[1])))
  } else {
    cat("\n  LOSO jackknife: skipped (gate failed or <2 studies)\n")
  }

  if (!isTRUE(gate_passed)) {
    cat("\n  NOTE: Nonlinearity gate did NOT pass.\n")
    cat("        GAM does not fit significantly better than linear model.\n")
    cat("        Threshold estimate has low confidence.\n")
  }
  cat("\n")

  # Backward-compat columns check
  compat_cols <- c("threshold_cm2", "cluster_boot_ci_lower", "cluster_boot_ci_upper", "cluster_boot_cv")
  missing_compat <- setdiff(compat_cols, names(threshold_data))
  if (length(missing_compat) == 0) {
    cat("  Backward-compat columns: all present\n\n")
  } else {
    cat(sprintf("  WARNING: Missing backward-compat columns: %s\n\n",
                paste(missing_compat, collapse = ", ")))
  }

} else {
  cat("  Warning: survival_thresholds.csv not found\n\n")
}

# Growth thresholds (Detmer framework)
growth_thresh_file <- file.path(output_dir, "growth_thresholds.csv")
if (file.exists(growth_thresh_file)) {
  growth_thresh <- read_csv(growth_thresh_file, show_col_types = FALSE)
  cat("Growth Thresholds (Detmer et al. 2025):\n")
  for (i in seq_len(nrow(growth_thresh))) {
    resp <- growth_thresh$response[i]
    gp <- growth_thresh$gate_passed[i]
    ff <- growth_thresh$functional_form[i]
    rd <- growth_thresh$recommended_definition[i]
    rc <- growth_thresh$recommended_threshold_cm2[i]
    cat(sprintf("  %s: gate=%s, form=%s, def=%s, threshold=%.0f cm²\n",
                resp, gp, ff, rd, rc))
  }
  cat("\n")
}

# ==============================================================================
# SUMMARY TABLE
# ==============================================================================

cat("═══════════════════════════════════════════════════════════════════════\n")
cat("QUICK REFERENCE: VALUES FOR FIGURE ANNOTATIONS\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

cat("Figure 2 (Survival):\n")
cat(sprintf("  OR = %.2f (95%% CI: %.2f-%.2f)\n", or_val, or_ci[1], or_ci[2]))
cat(sprintf("  Tjur R² = %.1f%%\n", tjur_d * 100))
cat(sprintf("  GAM deviance explained = %.1f%%\n", gam_dev))
cat(sprintf("  p %s\n", ifelse(p_val < 0.001, "< 0.001", sprintf("= %.4f", p_val))))
cat("\n")

cat("Figure 4 (Growth):\n")
if (exists("agr_r2") && exists("rgr_r2")) {
  cat(sprintf("  AGR R² = %.1f%%\n", agr_r2 * 100))
  cat(sprintf("  RGR R² = %.1f%%\n", rgr_r2 * 100))
  cat(sprintf("  Improvement = %.0fx\n", improvement))
}
cat("\n")

cat("Figure 5 (Population Model):\n")
if (exists("lambda_mean")) {
  cat(sprintf("  λ = %.3f (95%% CI: %.2f-%.2f)\n", lambda_mean, lambda_ci[1], lambda_ci[2]))
  cat(sprintf("  P(decline) = %.0f%%\n", p_decline))
  cat(sprintf("  Annual decline = %.2f%%\n", annual_decline))
}
if (exists("max_elast")) {
  cat(sprintf("  SC5 elasticity = %.1f%%\n", max_elast$elast[1] * 100))
}
cat("\n")

cat("Meta-Analysis:\n")
if (exists("i_squared")) {
  cat(sprintf("  I² = %.1f%% (considerable heterogeneity)\n", i_squared))
  cat(sprintf("  Prediction interval: (%.0f%%, %.0f%%)\n", pi_lower * 100, pi_upper * 100))
}
cat("\n")

# ==============================================================================
# FINAL RECOMMENDATIONS
# ==============================================================================

cat("═══════════════════════════════════════════════════════════════════════\n")
cat("DYNAMIC VALUE CROSS-CHECK\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

cat("Computed values (from data, not hardcoded):\n")
cat(sprintf("  Survival Tjur R² = %.1f%%\n", tjur_d * 100))
cat(sprintf("  Survival OR = %.3f\n", or_val))
if (exists("agr_r2") && exists("rgr_r2")) {
  cat(sprintf("  AGR R² = %.1f%%, RGR R² = %.1f%% (%.0fx improvement)\n",
              agr_r2 * 100, rgr_r2 * 100, improvement))
}
if (exists("lambda_mean")) {
  cat(sprintf("  Lambda = %.4f (%.2f%% annual decline)\n", lambda_mean, annual_decline))
  cat(sprintf("  P(decline) = %.1f%%\n", p_decline))
}
if (exists("i_squared")) {
  cat(sprintf("  I² = %.1f%%\n", i_squared))
}
cat("\n")

# ==============================================================================
# ASSERTION CHECKS
# ==============================================================================

cat("═══════════════════════════════════════════════════════════════════════\n")
cat("REGRESSION CHECKS (automated assertions)\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

n_failures <- 0

check <- function(condition, message) {
  if (isTRUE(condition)) {
    cat(sprintf("  PASS: %s\n", message))
  } else {
    cat(sprintf("  FAIL: %s\n", message))
    n_failures <<- n_failures + 1
  }
}

# Core data checks (natural colonies only: n~3900, 2 studies)
check(n_surv > 3500, sprintf("Survival n > 3500 (got %d)", n_surv))
check(n_studies >= 2, sprintf("Number of studies >= 2 (got %d)", n_studies))

# Survival model checks
check(or_val > 1.0 && or_val < 3.0, sprintf("Survival OR in [1.0, 3.0] (got %.3f)", or_val))
check(tjur_d > 0.01 && tjur_d < 0.30, sprintf("Tjur D in [0.01, 0.30] (got %.4f)", tjur_d))
check(p_val < 0.05, sprintf("Size-survival p < 0.05 (got %.4f)", p_val))

# Lambda checks
if (exists("lambda_mean")) {
  check(lambda_mean > 0.90 && lambda_mean < 1.05,
        sprintf("Lambda in [0.90, 1.05] (got %.4f)", lambda_mean))
  check(p_decline > 50 && p_decline < 100,
        sprintf("P(decline) in [50, 100]%% (got %.1f%%)", p_decline))
  check(length(lambda_samples) >= 500,
        sprintf("Bootstrap n >= 500 (got %d)", length(lambda_samples)))
}

# Meta-analysis checks
if (exists("i_squared")) {
  check(i_squared > 80, sprintf("I-squared > 80%% (got %.1f%%)", i_squared))
  check(k_studies == 6, sprintf("k = 6 (got %.0f)", k_studies))
  check(pooled_surv > 0.5 && pooled_surv < 1.0,
        sprintf("Pooled survival in [0.5, 1.0] (got %.3f)", pooled_surv))
}

cat(sprintf("\n  Total: %d failures\n", n_failures))
if (n_failures > 0) {
  warning(sprintf("Verification found %d assertion failures!", n_failures))
} else {
  cat("  All assertions passed.\n")
}

cat("\n")
cat("═══════════════════════════════════════════════════════════════════════\n")
if (n_failures > 0) {
  cat(sprintf("VERIFICATION COMPLETE (%d FAILURES)\n", n_failures))
} else {
  cat("VERIFICATION COMPLETE (ALL PASSED)\n")
}
cat("═══════════════════════════════════════════════════════════════════════\n\n")

cat("See 06_analysis/figures/DATA_INTEGRATION_REPORT.md for full audit details.\n\n")
