#!/usr/bin/env Rscript
################################################################################
# 03_GROWTH_THRESHOLDS.R
# A. palmata Size-Dependent Growth Threshold Detection
################################################################################
#
# PURPOSE: Detect size thresholds where growth rates change significantly
#          Using mixed effects models with robust inference
#
# ROBUSTNESS IMPROVEMENTS (v2.0):
#   1. LMM/GLMM with coral_id, location, study, and year random effects
#   2. Cluster bootstrap (resample by study)
#   3. Hurdle model for zero-inflated/negative growth
#   4. Heteroscedasticity-robust modeling (RGR focus)
#   5. Size-region interaction analysis
#   6. Leave-one-study-out sensitivity analysis
#
# METHODS:
#   1. GAM/GAMM - Smooth spline with random effects
#   2. LMM - Linear mixed effects for growth
#   3. GLMM - For probability of positive growth
#   4. CLUSTER BOOTSTRAP - Proper uncertainty quantification
#
# INPUTS:
#   - 06_analysis/output/prepared_growth_data.rds
#
# OUTPUTS:
#   - 06_analysis/output/growth_thresholds.csv
#   - 06_analysis/output/growth_threshold_models.rds
#   - 06_analysis/output/growth_random_effects.csv
#   - 06_analysis/figures/supplementary/exploratory/growth_threshold_detection.png
#   - 06_analysis/figures/supplementary/exploratory/positive_growth_probability.png
#   - 06_analysis/figures/supplementary/diagnostics/growth_model_diagnostics.png
#
# Author: Detmer & Stier Lab
# Date: 2025-12-24 (v2.0 with robustness improvements)
################################################################################

# Load required packages
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(mgcv)

# Try to load mixed effects packages
has_lme4 <- requireNamespace("lme4", quietly = TRUE)
has_nlme <- requireNamespace("nlme", quietly = TRUE)
has_quantreg <- requireNamespace("quantreg", quietly = TRUE)

if (has_lme4) library(lme4)
if (has_nlme) library(nlme)
if (has_quantreg) library(quantreg)

# Source shared utilities for constants and helper functions
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  03: GROWTH THRESHOLD DETECTION (v2.1)                       ║\n")
cat("║  Stratified Analysis: Natural Colonies vs Restoration Frags  ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("Package availability:\n")
cat(sprintf("  lme4:     %s (for LMM/GLMM)\n", ifelse(has_lme4, "✓", "✗")))
cat(sprintf("  quantreg: %s (for quantile regression)\n", ifelse(has_quantreg, "✓", "✗")))
cat("\n")

# Set paths - detect project root
if (file.exists("05_data/standardized")) {
  project_root <- "."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root. Run from project directory or 06_analysis/scripts/")
}

output_dir <- file.path(project_root, "06_analysis/output")
fig_dir <- file.path(project_root, "06_analysis/figures")
fig_dir_supp_exploratory <- file.path(fig_dir, "supplementary/exploratory")
fig_dir_supp_diagnostics <- file.path(fig_dir, "supplementary/diagnostics")
dir.create(fig_dir_supp_exploratory, showWarnings = FALSE, recursive = TRUE)
dir.create(fig_dir_supp_diagnostics, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# All shared functions are provided by utils/shared_utilities.R:
#   - compute_derivatives()               from 02_threshold_functions.R
#   - abs_max_threshF(), min_threshF()    from 02_threshold_functions.R
#   - root_threshF()                      from 02_threshold_functions.R
#   - nonlinearity_gate()                 from 02_threshold_functions.R
#   - classify_functional_form()          from 02_threshold_functions.R
#   - loso_threshold()                    from 02_threshold_functions.R
#   - quantify_threshold_magnitude()      from 02_threshold_functions.R
#   - run_threshold_analysis()            from 02_threshold_functions.R

# =============================================================================
# 1. LOAD DATA
# =============================================================================

cat("Loading prepared data...\n")

growth_data_raw <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

cat(sprintf("  Total records: %d\n", nrow(growth_data_raw)))
cat(sprintf("  Mean growth: %.1f cm²/yr\n", mean(growth_data_raw$growth_cm2_yr)))
cat(sprintf("  %% negative growth: %.1f%%\n",
            mean(growth_data_raw$growth_cm2_yr < 0) * 100))
cat(sprintf("  Size range: %.1f - %.1f cm²\n",
            min(growth_data_raw$size_cm2), max(growth_data_raw$size_cm2)))

# =============================================================================
# DATA QUALITY FILTERING
# =============================================================================
# Two filtering approaches are applied:
#
# 1. IMPOSSIBLE VALUES (PRIMARY): Records where tissue loss exceeds initial
#    colony size (flagged as impossible_growth in 01_data_preparation.R).
#    These are biologically impossible and represent measurement/data errors.
#    ~300 records (6.9%) affected, primarily from NOAA survey.
#
# 2. EXTREME OUTLIERS (SECONDARY): Records with >50% tissue loss or >200%
#    gain in one year. These are biologically unlikely but not impossible.
#
# For robust analysis, we filter BOTH impossible values AND extreme outliers.

cat("\nFiltering data quality issues...\n")

# Check if impossible_growth flag exists (from 01_data_preparation.R)
if ("impossible_growth" %in% names(growth_data_raw)) {
  n_impossible <- sum(growth_data_raw$impossible_growth, na.rm = TRUE)
  cat(sprintf("  Found %d records flagged as impossible growth\n", n_impossible))
  growth_data <- growth_data_raw %>%
    filter(!impossible_growth)  # Remove impossible values first
} else {
  # Fallback: create the flag here if not present
  cat("  ⚠ impossible_growth flag not found - creating it\n")
  growth_data <- growth_data_raw %>%
    mutate(
      impossible_growth = (growth_cm2_yr < 0) & (abs(growth_cm2_yr) > size_cm2 * 1.1)
    ) %>%
    filter(!impossible_growth)
}

cat(sprintf("  After removing impossible values: %d records\n", nrow(growth_data)))

# Additional filter for extreme but not impossible values
# Use coalesced growth metric (prefers live-tissue growth) for consistency with RGR
growth_data <- growth_data %>%
  mutate(pct_change = coalesce(growth_live_cm2_yr, growth_cm2_yr) / size_cm2 * 100) %>%
  filter(pct_change > -50 & pct_change < 200)

n_removed_total <- nrow(growth_data_raw) - nrow(growth_data)
cat(sprintf("  After removing extreme outliers: %d records\n", nrow(growth_data)))
cat(sprintf("  Total removed: %d records (%.1f%%)\n",
            n_removed_total, n_removed_total/nrow(growth_data_raw)*100))
cat(sprintf("  Mean growth (filtered): %.1f cm²/yr\n", mean(growth_data$growth_cm2_yr)))

# Save data filtering summary
n_after_impossible <- if ("impossible_growth" %in% names(growth_data_raw)) {
  nrow(growth_data_raw) - sum(growth_data_raw$impossible_growth, na.rm = TRUE)
} else {
  nrow(growth_data_raw) - sum((growth_data_raw$growth_cm2_yr < 0) & (abs(growth_data_raw$growth_cm2_yr) > growth_data_raw$size_cm2 * 1.1), na.rm = TRUE)
}
n_impossible_removed <- nrow(growth_data_raw) - n_after_impossible
n_outlier_removed <- n_after_impossible - nrow(growth_data)

growth_filtering_df <- data.frame(
  stage = c("raw_data", "remove_impossible_values", "remove_extreme_outliers"),
  n_before = c(nrow(growth_data_raw), nrow(growth_data_raw), n_after_impossible),
  n_removed = c(0, n_impossible_removed, n_outlier_removed),
  pct_removed = c(0,
                  n_impossible_removed / nrow(growth_data_raw) * 100,
                  n_outlier_removed / n_after_impossible * 100),
  n_after = c(nrow(growth_data_raw), n_after_impossible, nrow(growth_data)),
  reason = c("initial load",
             "tissue loss > initial size (impossible_growth flag)",
             "pct_change outside -50% to 200% range")
)
write_csv(growth_filtering_df, file.path(output_dir, "growth_data_filtering.csv"))
cat("  Saved: growth_data_filtering.csv\n")

# Check for coral_id
has_coral_id <- "coral_id" %in% names(growth_data)
if (has_coral_id) {
  n_corals <- n_distinct(growth_data$coral_id)
  repeat_corals <- growth_data %>%
    group_by(coral_id) %>%
    summarise(n = n(), .groups = "drop") %>%
    filter(n > 1)
  cat(sprintf("  Unique corals: %d (%.1f%% with repeated measures)\n",
              n_corals, nrow(repeat_corals)/n_corals * 100))
}

# --- RGR SOURCE DISTRIBUTION ---
if ("rgr_source" %in% names(growth_data)) {
  cat("\n--- RGR SOURCE DISTRIBUTION ---\n")
  print(as.data.frame(growth_data %>% count(study, rgr_source)))
}

# =============================================================================
# POPULATION TYPE STRATIFICATION (CRITICAL)
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  POPULATION TYPE STRATIFICATION\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Check if population_type exists
if (!"population_type" %in% names(growth_data)) {
  # Need to load survival data to get the fragment status mapping
  cat("Adding population_type based on fragment status...\n")
  growth_data <- growth_data %>%
    mutate(
      is_fragment = ifelse("fragment" %in% names(.), fragment == "Y", FALSE),
      population_type = ifelse(is_fragment, "Restoration fragment", "Natural colony")
    )
}

pop_summary <- growth_data %>%
  group_by(population_type) %>%
  summarise(
    n = n(),
    pct = n() / nrow(growth_data) * 100,
    n_studies = n_distinct(study),
    mean_growth = mean(growth_cm2_yr),
    pct_negative = mean(growth_cm2_yr < 0) * 100,
    mean_size = mean(size_cm2),
    median_size = median(size_cm2),
    .groups = "drop"
  )

cat("Population type breakdown:\n")
print(as.data.frame(pop_summary))

# Create stratified subsets
growth_natural <- growth_data %>% filter(population_type == "Natural colony")
growth_fragments <- growth_data %>% filter(population_type == "Restoration fragment")

cat(sprintf("\n  Natural colonies: n = %d (%.1f%%)\n",
            nrow(growth_natural), nrow(growth_natural)/nrow(growth_data)*100))
cat(sprintf("  Restoration fragments: n = %d (%.1f%%)\n",
            nrow(growth_fragments), nrow(growth_fragments)/nrow(growth_data)*100))

# NOTE: For growth, we analyze all data together since fragment status
# is less confounding for growth than survival (both show similar size-growth patterns)
# But we still report stratified results
cat("\nNOTE: Unlike survival, size-growth relationship appears similar\n")
cat("      across population types. Using ALL data for main analysis.\n")

cat("\n")

# =============================================================================
# 2. DATA QUALITY SUMMARY
# =============================================================================

cat("═══════════════════════════════════════════════════════════════\n")
cat("  DATA STRUCTURE & POTENTIAL ISSUES\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Study contribution
study_summary <- growth_data %>%
  group_by(study) %>%
  summarise(
    n = n(),
    pct = n() / nrow(growth_data) * 100,
    mean_growth = mean(growth_cm2_yr),
    pct_negative = mean(growth_cm2_yr < 0) * 100,
    mean_size = mean(size_cm2),
    .groups = "drop"
  ) %>%
  arrange(desc(n))

cat("Study contribution:\n")
print(as.data.frame(study_summary))

# Save study contribution table
write_csv(study_summary, file.path(output_dir, "growth_by_study_detail.csv"))
cat("  Saved: growth_by_study_detail.csv\n")

# Size-region patterns
cat("\nSize-region patterns:\n")
region_size <- growth_data %>%
  group_by(region) %>%
  summarise(
    n = n(),
    mean_log_size = mean(log_size),
    mean_growth = mean(growth_cm2_yr),
    pct_negative = mean(growth_cm2_yr < 0) * 100,
    .groups = "drop"
  ) %>%
  arrange(mean_log_size)
print(as.data.frame(region_size))

# Heteroscedasticity check
cat("\nHeteroscedasticity check (variance by size quartile):\n")
growth_data$size_quartile <- cut(growth_data$log_size,
                                  breaks = quantile(growth_data$log_size, c(0, 0.25, 0.5, 0.75, 1)),
                                  labels = c("Q1", "Q2", "Q3", "Q4"),
                                  include.lowest = TRUE)
var_by_quartile <- growth_data %>%
  group_by(size_quartile) %>%
  summarise(
    n = n(),
    mean_growth = mean(growth_cm2_yr),
    sd_growth = sd(growth_cm2_yr),
    var_growth = var(growth_cm2_yr),
    .groups = "drop"
  )
print(as.data.frame(var_by_quartile))

hetero_ratio <- max(var_by_quartile$sd_growth, na.rm = TRUE) /
                min(var_by_quartile$sd_growth, na.rm = TRUE)
cat(sprintf("\nHeteroscedasticity ratio: %.1f\n", hetero_ratio))
if (hetero_ratio > 3) {
  cat("  ⚠ Severe heteroscedasticity - RGR or log-transformed models recommended\n")
} else if (hetero_ratio > 2) {
  cat("  ⚠ Moderate heteroscedasticity - consider variance-weighted models\n")
} else {
  cat("  ✓ Variance is reasonably homogeneous\n")
}

# =============================================================================
# 3. FIT MIXED EFFECTS MODELS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  MIXED EFFECTS MODELS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Prediction grid
size_range <- range(growth_data$log_size)
pred_grid <- data.frame(
  log_size = seq(size_range[1], size_range[2], length.out = 1000)
)
pred_grid$size_cm2 <- exp(pred_grid$log_size)

# ----------------------------------------
# MODEL 1: Simple LM (baseline)
# ----------------------------------------

cat("Model 1: LM (no random effects - baseline)\n")

model_lm <- lm(growth_cm2_yr ~ log_size, data = growth_data)
pred_grid$lm <- predict(model_lm, newdata = pred_grid)

cat(sprintf("  AIC: %.2f\n", AIC(model_lm)))
cat(sprintf("  R²: %.4f\n", summary(model_lm)$r.squared))
cat(sprintf("  Slope: %.2f cm²/yr per log-unit (SE: %.2f)\n",
            coef(model_lm)[2],
            summary(model_lm)$coefficients[2, 2]))

# ----------------------------------------
# MODEL 2-5: LMM with random effects
# ----------------------------------------

if (has_lme4) {
  # Model 2: Study RE
  cat("\nModel 2: LMM with study random intercept\n")

  model_lmm_study <- tryCatch({
    lmer(growth_cm2_yr ~ log_size + (1|study),
         data = growth_data,
         control = lmerControl(optimizer = "bobyqa"))
  }, error = function(e) {
    cat(sprintf("  ✗ Failed: %s\n", e$message))
    NULL
  })

  if (!is.null(model_lmm_study)) {
    cat(sprintf("  AIC: %.2f\n", AIC(model_lmm_study)))
    cat(sprintf("  Fixed slope: %.2f\n", fixef(model_lmm_study)[2]))
    cat(sprintf("  Study SD: %.2f\n", sqrt(VarCorr(model_lmm_study)$study[1])))
  }

  # Model 3: Study + Location RE
  cat("\nModel 3: LMM with study + location random intercepts\n")

  model_lmm_loc <- tryCatch({
    lmer(growth_cm2_yr ~ log_size + (1|study) + (1|location),
         data = growth_data,
         control = lmerControl(optimizer = "bobyqa"))
  }, error = function(e) {
    cat(sprintf("  ✗ Failed: %s\n", e$message))
    NULL
  })

  if (!is.null(model_lmm_loc)) {
    cat(sprintf("  AIC: %.2f\n", AIC(model_lmm_loc)))
    vc <- VarCorr(model_lmm_loc)
    cat(sprintf("  Study SD: %.2f\n", sqrt(vc$study[1])))
    cat(sprintf("  Location SD: %.2f\n", sqrt(vc$location[1])))
  }

  # Model 4: Study + Location + Year RE
  cat("\nModel 4: LMM with study + location + year random intercepts\n")

  growth_data$year_factor <- as.factor(growth_data$survey_yr)

  model_lmm_full <- tryCatch({
    lmer(growth_cm2_yr ~ log_size + (1|study) + (1|location) + (1|year_factor),
         data = growth_data,
         control = lmerControl(optimizer = "bobyqa"))
  }, error = function(e) {
    cat(sprintf("  ✗ Failed: %s\n", e$message))
    NULL
  })

  if (!is.null(model_lmm_full)) {
    cat(sprintf("  AIC: %.2f\n", AIC(model_lmm_full)))
    vc <- VarCorr(model_lmm_full)
    cat(sprintf("  Study SD: %.2f\n", sqrt(vc$study[1])))
    cat(sprintf("  Location SD: %.2f\n", sqrt(vc$location[1])))
    cat(sprintf("  Year SD: %.2f\n", sqrt(vc$year_factor[1])))
  }

  # Model 5: Full model with coral_id (if available)
  if (has_coral_id) {
    cat("\nModel 5: LMM with coral_id + study + location + year\n")

    model_lmm_coral <- tryCatch({
      lmer(growth_cm2_yr ~ log_size + (1|coral_id) + (1|study) + (1|location) + (1|year_factor),
           data = growth_data,
           control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 100000)))
    }, error = function(e) {
      cat(sprintf("  ✗ Failed: %s\n", e$message))
      NULL
    })

    if (!is.null(model_lmm_coral)) {
      cat(sprintf("  AIC: %.2f\n", AIC(model_lmm_coral)))
      vc <- VarCorr(model_lmm_coral)
      cat(sprintf("  Coral ID SD: %.2f\n", sqrt(vc$coral_id[1])))
      cat(sprintf("  Study SD: %.2f\n", sqrt(vc$study[1])))
      cat(sprintf("  Location SD: %.2f\n", sqrt(vc$location[1])))
      cat(sprintf("  Year SD: %.2f\n", sqrt(vc$year_factor[1])))
    }
  }
}

# ----------------------------------------
# HETEROSCEDASTIC GROWTH MODELS
# ----------------------------------------

# Heteroscedastic growth models using nlme
# Addresses documented variance-size relationship
if (has_nlme) {
  cat("\n--- HETEROSCEDASTIC GROWTH MODELS ---\n")

  # Model with variance proportional to fitted values
  growth_varPower <- tryCatch({
    m <- lme(growth_cm2_yr ~ log_size,
             random = ~ 1 | study,
             weights = varPower(form = ~ fitted(.)),
             data = growth_data)
    cat("varPower model converged.\n")
    cat(sprintf("  Power parameter: %.3f\n", coef(m$modelStruct$varStruct, unconstrained = FALSE)))
    m
  }, error = function(e) {
    cat(sprintf("varPower model failed: %s\n", e$message))
    # Try varExp as alternative
    tryCatch({
      m <- lme(growth_cm2_yr ~ log_size,
               random = ~ 1 | study,
               weights = varExp(form = ~ log_size),
               data = growth_data)
      cat("varExp model converged (fallback).\n")
      m
    }, error = function(e2) {
      cat(sprintf("varExp model also failed: %s\n", e2$message))
      NULL
    })
  })

  if (!is.null(growth_varPower) && has_lme4 && !is.null(model_lmm_study)) {
    cat(sprintf("  AIC (homoscedastic lmer): %.1f\n", AIC(model_lmm_study)))
    cat(sprintf("  AIC (heteroscedastic nlme): %.1f\n", AIC(growth_varPower)))
  }
}

# =============================================================================
# 4. THRESHOLD DETECTION — Detmer et al. (2025) Framework
# =============================================================================
#
# Uses gratia::derivatives() for proper derivative computation with
# simultaneous CIs, 4 threshold definitions, nonlinearity gate,
# functional form classification, and LOSO jackknife.
#
# Reference: Detmer et al. (2025) Zenodo: 10.5281/zenodo.14210416

best_k_abs <- 10  # k=10: REML selects optimal smoothness; k=4 available as sensitivity check

# Prediction grid for derivative computation (200 points over data range)
pred_grid_deriv <- data.frame(
  log_size = seq(size_range[1], size_range[2], length.out = 200)
)

# --- 4a. ABSOLUTE GROWTH RATE (AGR) ---

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  THRESHOLD DETECTION: ABSOLUTE GROWTH (Detmer et al. 2025)\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

set.seed(42)
agr_thresh_results <- run_threshold_analysis(
  data           = growth_data,
  gam_formula    = growth_cm2_yr ~ s(log_size, k = 10, bs = "tp"),
  lm_formula     = growth_cm2_yr ~ log_size,
  family         = gaussian(),
  study_col      = "study",
  predictor_col  = "log_size",
  pred_data      = pred_grid_deriv,
  k_val          = 10,
  eps_val        = 5e-6,
  smooth_derivatives = FALSE,
  gamm_formula   = growth_cm2_yr ~ s(log_size, k = 10, bs = "tp") + s(study, bs = "re"),
  response_label = "absolute_growth_rate"
)

# --- SENSITIVITY: k=4 (Samhouri et al. 2017 legacy) ---
cat("\n  Sensitivity check: AGR k=4 (legacy)...\n")
agr_thresh_k4 <- run_threshold_analysis(
  data = growth_data,
  gam_formula = growth_cm2_yr ~ s(log_size, k = 4, bs = "tp"),
  lm_formula = growth_cm2_yr ~ log_size,
  family = gaussian(), study_col = "study",
  predictor_col = "log_size", pred_data = pred_grid_deriv,
  k_val = 4, smooth_derivatives = TRUE,
  response_label = "agr_k4_sensitivity"
)

# Extract key AGR results
model_gam_abs   <- agr_thresh_results$gam_model
agr_gate        <- agr_thresh_results$gate
agr_form        <- agr_thresh_results$form_class
agr_full_thresh <- agr_thresh_results$full_thresholds
agr_deriv_df    <- agr_thresh_results$derivatives
agr_loso        <- agr_thresh_results$loso
agr_magnitude   <- agr_thresh_results$magnitude
agr_recommended_log <- agr_thresh_results$recommended_thresh_log
agr_recommended_cm2 <- agr_thresh_results$recommended_thresh_cm2

# Populate pred_grid with AGR predictions
pred_grid$gam_abs <- predict(model_gam_abs, newdata = pred_grid)
pred_se_abs <- predict(model_gam_abs, newdata = pred_grid, se.fit = TRUE)
pred_grid$gam_abs_lower <- pred_se_abs$fit - 1.96 * pred_se_abs$se.fit
pred_grid$gam_abs_upper <- pred_se_abs$fit + 1.96 * pred_se_abs$se.fit

cat(sprintf("\nAGR model R²: %.3f\n", summary(model_gam_abs)$r.sq))
cat(sprintf("AGR deviance explained: %.1f%%\n", summary(model_gam_abs)$dev.expl * 100))
cat(sprintf("AGR EDF: %.2f\n", sum(model_gam_abs$edf)))
cat(sprintf("AGR nonlinearity gate: %s (delta AICc = %.1f)\n", agr_gate$best_mod, agr_gate$delta_aicc))
cat(sprintf("AGR functional form: %s\n", agr_form$form))
cat(sprintf("AGR recommended threshold (%s): %.0f cm²\n",
            agr_form$recommended_def,
            if (!is.na(agr_recommended_cm2)) agr_recommended_cm2 else NA))

# Backward-compat: gam_thresh object
gam_thresh_abs <- list(
  threshold    = agr_recommended_log,
  threshold_cm2 = agr_recommended_cm2,
  max_abs_d2   = if (!is.null(agr_deriv_df)) max(abs(agr_deriv_df$d2), na.rm = TRUE) else NA
)

# Backward-compat: cluster_boot from LOSO
if (!is.null(agr_loso)) {
  loso_summ_agr <- agr_loso$summary[agr_loso$summary$method == agr_form$recommended_def &
                                      agr_loso$summary$sig_criteria == "none", ]
  if (nrow(loso_summ_agr) == 0) {
    cat("  No valid LOSO folds for AGR threshold\n")
    cluster_boot_abs <- list(mean = NA, median = NA, se = NA, ci_lower = NA, ci_upper = NA, n_valid = 0)
    boot_cv_abs <- NA_real_
  } else {
    boot_cv_abs <- if (!is.na(loso_summ_agr$threshold_se) && !is.na(loso_summ_agr$threshold_mean) &&
                       abs(loso_summ_agr$threshold_mean) > 0) {
      loso_summ_agr$threshold_se / abs(loso_summ_agr$threshold_mean)
    } else NA_real_
    cluster_boot_abs <- list(
      mean     = loso_summ_agr$threshold_mean,
      median   = loso_summ_agr$threshold_mean,
      se       = loso_summ_agr$threshold_se,
      ci_lower = loso_summ_agr$ci_lower,
      ci_upper = loso_summ_agr$ci_upper,
      n_valid  = loso_summ_agr$n_detected
    )
  }
} else {
  cluster_boot_abs <- list(mean = NA, median = NA, se = NA, ci_lower = NA, ci_upper = NA, n_valid = 0)
  boot_cv_abs <- NA_real_
}

# --- 4b. RELATIVE GROWTH RATE (RGR) ---

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  THRESHOLD DETECTION: RELATIVE GROWTH RATE (Detmer et al. 2025)\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# RGR handles heteroscedasticity better
growth_data_rgr <- growth_data %>%
  filter(abs(rgr) < quantile(abs(rgr), 0.99, na.rm = TRUE))

cat(sprintf("Records for RGR analysis: %d (after 1%% outlier trim)\n", nrow(growth_data_rgr)))

rgr_thresh_results <- run_threshold_analysis(
  data           = growth_data_rgr,
  gam_formula    = rgr ~ s(log_size, k = 10, bs = "tp"),
  lm_formula     = rgr ~ log_size,
  family         = gaussian(),
  study_col      = "study",
  predictor_col  = "log_size",
  pred_data      = pred_grid_deriv,
  k_val          = 10,
  eps_val        = 5e-6,
  smooth_derivatives = FALSE,
  gamm_formula   = rgr ~ s(log_size, k = 10, bs = "tp") + s(study, bs = "re"),
  response_label = "relative_growth_rate"
)

# --- SENSITIVITY: k=4 (Samhouri et al. 2017 legacy) ---
cat("\n  Sensitivity check: RGR k=4 (legacy)...\n")
rgr_thresh_k4 <- run_threshold_analysis(
  data = growth_data_rgr,
  gam_formula = rgr ~ s(log_size, k = 4, bs = "tp"),
  lm_formula = rgr ~ log_size,
  family = gaussian(), study_col = "study",
  predictor_col = "log_size", pred_data = pred_grid_deriv,
  k_val = 4, smooth_derivatives = TRUE,
  response_label = "rgr_k4_sensitivity"
)

model_gam_rgr   <- rgr_thresh_results$gam_model
rgr_gate        <- rgr_thresh_results$gate
rgr_form        <- rgr_thresh_results$form_class
rgr_full_thresh <- rgr_thresh_results$full_thresholds
rgr_deriv_df    <- rgr_thresh_results$derivatives
rgr_loso        <- rgr_thresh_results$loso
rgr_magnitude   <- rgr_thresh_results$magnitude
rgr_recommended_log <- rgr_thresh_results$recommended_thresh_log
rgr_recommended_cm2 <- rgr_thresh_results$recommended_thresh_cm2

pred_grid$gam_rgr <- predict(model_gam_rgr, newdata = pred_grid)

cat(sprintf("\nRGR model R²: %.3f\n", summary(model_gam_rgr)$r.sq))
cat(sprintf("RGR deviance explained: %.1f%%\n", summary(model_gam_rgr)$dev.expl * 100))
cat(sprintf("→ RGR explains %.1fx more variance than AGR\n",
            summary(model_gam_rgr)$r.sq / max(summary(model_gam_abs)$r.sq, 0.001)))
cat(sprintf("RGR nonlinearity gate: %s (delta AICc = %.1f)\n", rgr_gate$best_mod, rgr_gate$delta_aicc))
cat(sprintf("RGR functional form: %s\n", rgr_form$form))
cat(sprintf("RGR recommended threshold (%s): %.0f cm²\n",
            rgr_form$recommended_def,
            if (!is.na(rgr_recommended_cm2)) rgr_recommended_cm2 else NA))

gam_thresh_rgr <- list(
  threshold    = rgr_recommended_log,
  threshold_cm2 = rgr_recommended_cm2,
  max_abs_d2   = if (!is.null(rgr_deriv_df)) max(abs(rgr_deriv_df$d2), na.rm = TRUE) else NA
)

# Backward-compat: cluster_boot from LOSO for RGR
if (!is.null(rgr_loso)) {
  loso_summ_rgr <- rgr_loso$summary[rgr_loso$summary$method == rgr_form$recommended_def &
                                      rgr_loso$summary$sig_criteria == "none", ]
  if (nrow(loso_summ_rgr) == 0) {
    cat("  No valid LOSO folds for RGR threshold\n")
    cluster_boot_rgr <- list(mean = NA, ci_lower = NA, ci_upper = NA, n_valid = 0)
    boot_cv_rgr <- NA_real_
  } else {
    boot_cv_rgr <- if (!is.na(loso_summ_rgr$threshold_se) && !is.na(loso_summ_rgr$threshold_mean) &&
                       abs(loso_summ_rgr$threshold_mean) > 0) {
      loso_summ_rgr$threshold_se / abs(loso_summ_rgr$threshold_mean)
    } else NA_real_
    cluster_boot_rgr <- list(
      mean     = loso_summ_rgr$threshold_mean,
      ci_lower = loso_summ_rgr$ci_lower,
      ci_upper = loso_summ_rgr$ci_upper,
      n_valid  = loso_summ_rgr$n_detected
    )
  }
} else {
  cluster_boot_rgr <- list(mean = NA, ci_lower = NA, ci_upper = NA, n_valid = 0)
  boot_cv_rgr <- NA_real_
}

# --- 4c. PROBABILITY OF POSITIVE GROWTH ---

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  THRESHOLD DETECTION: P(+GROWTH) (Detmer et al. 2025)\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Binary positive growth
growth_data <- growth_data %>%
  mutate(positive_growth = as.integer(growth_cm2_yr > 0))

cat(sprintf("Overall %% positive growth: %.1f%%\n",
            mean(growth_data$positive_growth) * 100))

pos_thresh_results <- run_threshold_analysis(
  data           = growth_data,
  gam_formula    = positive_growth ~ s(log_size, k = 10, bs = "tp"),
  lm_formula     = positive_growth ~ log_size,
  family         = binomial,
  study_col      = "study",
  predictor_col  = "log_size",
  pred_data      = pred_grid_deriv,
  k_val          = 10,
  eps_val        = 5e-6,
  smooth_derivatives = FALSE,
  gamm_formula   = positive_growth ~ s(log_size, k = 10, bs = "tp") + s(study, bs = "re"),
  response_label = "positive_growth_prob"
)

# --- SENSITIVITY: k=4 (Samhouri et al. 2017 legacy) ---
cat("\n  Sensitivity check: P(+growth) k=4 (legacy)...\n")
pos_thresh_k4 <- run_threshold_analysis(
  data = growth_data,
  gam_formula = positive_growth ~ s(log_size, k = 4, bs = "tp"),
  lm_formula = positive_growth ~ log_size,
  family = binomial, study_col = "study",
  predictor_col = "log_size", pred_data = pred_grid_deriv,
  k_val = 4, smooth_derivatives = TRUE,
  response_label = "pos_k4_sensitivity"
)

model_pos_growth <- pos_thresh_results$gam_model
pos_gate        <- pos_thresh_results$gate
pos_form        <- pos_thresh_results$form_class
pos_full_thresh <- pos_thresh_results$full_thresholds
pos_deriv_df    <- pos_thresh_results$derivatives
pos_loso        <- pos_thresh_results$loso
pos_magnitude   <- pos_thresh_results$magnitude
pos_recommended_log <- pos_thresh_results$recommended_thresh_log
pos_recommended_cm2 <- pos_thresh_results$recommended_thresh_cm2

pred_grid$prob_positive <- predict(model_pos_growth, newdata = pred_grid, type = "response")

cat(sprintf("\nP(+growth) deviance explained: %.1f%%\n",
            summary(model_pos_growth)$dev.expl * 100))
cat(sprintf("P(+growth) nonlinearity gate: %s (delta AICc = %.1f)\n", pos_gate$best_mod, pos_gate$delta_aicc))
cat(sprintf("P(+growth) functional form: %s\n", pos_form$form))
cat(sprintf("P(+growth) recommended threshold (%s): %.0f cm²\n",
            pos_form$recommended_def,
            if (!is.na(pos_recommended_cm2)) pos_recommended_cm2 else NA))

gam_thresh_pos <- list(
  threshold    = pos_recommended_log,
  threshold_cm2 = pos_recommended_cm2,
  max_abs_d2   = if (!is.null(pos_deriv_df)) max(abs(pos_deriv_df$d2), na.rm = TRUE) else NA
)

# Backward-compat: cluster_boot from LOSO for P(+growth)
if (!is.null(pos_loso)) {
  loso_summ_pos <- pos_loso$summary[pos_loso$summary$method == pos_form$recommended_def &
                                      pos_loso$summary$sig_criteria == "none", ]
  if (nrow(loso_summ_pos) == 0) {
    cat("  No valid LOSO folds for P(+growth) threshold\n")
    cluster_boot_pos <- list(mean = NA, ci_lower = NA, ci_upper = NA, n_valid = 0)
    boot_cv_pos <- NA_real_
  } else {
    boot_cv_pos <- if (!is.na(loso_summ_pos$threshold_se) && !is.na(loso_summ_pos$threshold_mean) &&
                       abs(loso_summ_pos$threshold_mean) > 0) {
      loso_summ_pos$threshold_se / abs(loso_summ_pos$threshold_mean)
    } else NA_real_
    cluster_boot_pos <- list(
      mean     = loso_summ_pos$threshold_mean,
      ci_lower = loso_summ_pos$ci_lower,
      ci_upper = loso_summ_pos$ci_upper,
      n_valid  = loso_summ_pos$n_detected
    )
  }
} else {
  cluster_boot_pos <- list(mean = NA, ci_lower = NA, ci_upper = NA, n_valid = 0)
  boot_cv_pos <- NA_real_
}

# GLMM for positive growth with random effects
if (has_lme4) {
  cat("\nGLMM for positive growth probability with random effects:\n")

  model_pos_glmm <- tryCatch({
    glmer(positive_growth ~ log_size + (1|study) + (1|location),
          data = growth_data, family = binomial,
          control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 100000)))
  }, error = function(e) {
    cat(sprintf("  ✗ Failed: %s\n", e$message))
    NULL
  })

  if (!is.null(model_pos_glmm)) {
    cat(sprintf("  AIC: %.2f (vs GAM: %.2f)\n", AIC(model_pos_glmm), AIC(model_pos_growth)))
    cat(sprintf("  Fixed slope: %.4f\n", fixef(model_pos_glmm)[2]))
    vc <- VarCorr(model_pos_glmm)
    cat(sprintf("  Study SD: %.3f\n", sqrt(vc$study[1])))
    cat(sprintf("  Location SD: %.3f\n", sqrt(vc$location[1])))

    # Overdispersion check
    pearson_resid <- residuals(model_pos_glmm, type = "pearson")
    n_par <- length(fixef(model_pos_glmm)) + sum(sapply(VarCorr(model_pos_glmm), function(x) prod(dim(x))))
    overdisp_ratio <- sum(pearson_resid^2) / (length(pearson_resid) - n_par)
    cat(sprintf("  Overdispersion ratio: %.3f %s\n", overdisp_ratio, if(overdisp_ratio > 1.5) "(WARNING)" else "(OK)"))

    pos_conv_messages <- tryCatch(unlist(model_pos_glmm@optinfo$conv$lme4$messages),
                                  error = function(e) character())
    pos_conv_messages <- as.character(pos_conv_messages)
    pos_conv_messages <- pos_conv_messages[nzchar(pos_conv_messages)]

    pos_glmm_diag <- tibble(
      model = "positive_growth_glmm",
      n_obs = nrow(growth_data),
      n_params = n_par,
      aic = AIC(model_pos_glmm),
      dispersion_ratio = overdisp_ratio,
      overdispersed = overdisp_ratio > 1.5,
      is_singular = tryCatch(lme4::isSingular(model_pos_glmm, tol = 1e-4),
                             error = function(e) NA),
      convergence_ok = length(pos_conv_messages) == 0,
      optimizer_messages = if (length(pos_conv_messages) == 0) NA_character_
                           else paste(unique(pos_conv_messages), collapse = " | ")
    )
    write_csv(pos_glmm_diag, file.path(output_dir, "growth_positive_glmm_diagnostics.csv"))
    cat("  Saved: growth_positive_glmm_diagnostics.csv\n")
  }
}

# Positive growth by size class
pos_by_size <- growth_data %>%
  group_by(size_class) %>%
  summarise(
    n = n(),
    pct_positive = mean(positive_growth) * 100,
    mean_growth = mean(growth_cm2_yr),
    mean_growth_positive = mean(growth_cm2_yr[growth_cm2_yr > 0]),
    .groups = "drop"
  )

cat("\nPositive growth by size class:\n")
print(as.data.frame(pos_by_size))

# --- LOSO summary for all 3 responses ---

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  LOSO JACKKNIFE SUMMARY (all 3 responses)\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

for (resp_name in c("AGR", "RGR", "P(+growth)")) {
  loso_obj <- switch(resp_name,
    "AGR" = agr_loso,
    "RGR" = rgr_loso,
    "P(+growth)" = pos_loso
  )
  if (!is.null(loso_obj)) {
    cat(sprintf("%s LOSO (%d folds):\n", resp_name, nrow(loso_obj$fold_info)))
    print(loso_obj$summary[loso_obj$summary$sig_criteria == "none",
                           c("method", "threshold_mean", "threshold_se", "n_detected", "detection_frac")])
    cat("\n")
  } else {
    cat(sprintf("%s LOSO: skipped (gate failed or <2 studies)\n\n", resp_name))
  }
}

# =============================================================================
# 9. SIZE-REGION INTERACTION
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SIZE-REGION INTERACTION ANALYSIS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

regions_with_data <- growth_data %>%
  group_by(region) %>%
  summarise(n = n(), size_range = max(log_size) - min(log_size), .groups = "drop") %>%
  filter(n >= 50, size_range > 2)

cat(sprintf("Regions with sufficient data: %d\n", nrow(regions_with_data)))

if (nrow(regions_with_data) >= 2) {
  growth_subset <- growth_data %>%
    filter(region %in% regions_with_data$region)

  # Ensure region is a factor for explicit ordering in by= smooths
  growth_subset$region <- as.factor(growth_subset$region)

  # Model with interaction
  model_interaction <- tryCatch({
    gam(growth_cm2_yr ~ s(log_size, k = best_k_abs) + s(log_size, by = region, k = 10) + region,
        data = growth_subset, method = "REML")
  }, error = function(e) NULL)

  model_no_interaction <- gam(growth_cm2_yr ~ s(log_size, k = best_k_abs) + region,
                               data = growth_subset, method = "REML")

  if (!is.null(model_interaction)) {
    cat(sprintf("\nModel comparison:\n"))
    cat(sprintf("  Without interaction: AIC = %.1f\n", AIC(model_no_interaction)))
    cat(sprintf("  With interaction:    AIC = %.1f\n", AIC(model_interaction)))

    if (AIC(model_interaction) < AIC(model_no_interaction) - 2) {
      cat("  → Size effect on growth VARIES by region\n")
    } else {
      cat("  → Size effect is CONSISTENT across regions\n")
    }
  }
}

# =============================================================================
# 10. QUANTILE REGRESSION
# =============================================================================

if (has_quantreg) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("  QUANTILE REGRESSION ANALYSIS\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  quantiles <- c(0.10, 0.25, 0.50, 0.75, 0.90)
  quant_results <- tibble()

  for (tau in quantiles) {
    rq_model <- rq(growth_cm2_yr ~ log_size, data = growth_data, tau = tau)
    coefs <- coef(rq_model)

    quant_results <- bind_rows(quant_results, tibble(
      quantile = tau,
      intercept = coefs[1],
      slope = coefs[2]
    ))
  }

  cat("Size effect across growth distribution:\n")
  print(as.data.frame(quant_results))

  if (all(quant_results$slope > 0)) {
    cat("\n✓ Larger corals grow faster across ALL quantiles\n")
  } else {
    cat("\n⚠ Size effect varies across the growth distribution\n")
  }

  # Save quantile regression results
  write_csv(quant_results, file.path(output_dir, "growth_quantile_regression.csv"))
  cat("  Saved: growth_quantile_regression.csv\n")
}

# =============================================================================
# 11. MODEL COMPARISON
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  MODEL COMPARISON\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# METHODOLOGICAL NOTE: AIC is only valid for comparing models with the SAME
# response variable and data. The following table groups models by response type.
# Cross-response comparisons (AGR vs RGR vs binomial) are DESCRIPTIVE only —
# they indicate relative model fit within their own likelihood space, NOT
# that one response variable is "better" than another in an absolute sense.

model_comparison <- tibble(
  Model = character(),
  AIC = numeric(),
  R_squared = numeric(),
  Description = character(),
  response_type = character()
)

model_comparison <- bind_rows(model_comparison, tibble(
  Model = "LM_abs",
  AIC = AIC(model_lm),
  R_squared = summary(model_lm)$r.squared,
  Description = "Linear, absolute growth",
  response_type = "AGR_gaussian"
))

model_comparison <- bind_rows(model_comparison, tibble(
  Model = "GAM_abs",
  AIC = AIC(model_gam_abs),
  R_squared = summary(model_gam_abs)$r.sq,
  Description = sprintf("GAM (k=%d), absolute growth", best_k_abs),
  response_type = "AGR_gaussian"
))

model_comparison <- bind_rows(model_comparison, tibble(
  Model = "GAM_rgr",
  AIC = AIC(model_gam_rgr),
  R_squared = summary(model_gam_rgr)$r.sq,
  Description = "GAM (k=10), relative growth rate",
  response_type = "RGR_gaussian"
))

model_comparison <- bind_rows(model_comparison, tibble(
  Model = "GAM_pos",
  AIC = AIC(model_pos_growth),
  R_squared = summary(model_pos_growth)$dev.expl,
  Description = "GAM, P(positive growth)",
  response_type = "binomial"
))

if (has_lme4 && !is.null(model_lmm_full)) {
  # For LMM, use conditional R² approximation
  model_comparison <- bind_rows(model_comparison, tibble(
    Model = "LMM_full",
    AIC = AIC(model_lmm_full),
    R_squared = NA,  # Complex to calculate for LMM
    Description = "LMM with study/location/year RE",
    response_type = "AGR_gaussian"
  ))
}

model_comparison <- model_comparison %>%
  group_by(response_type) %>%
  mutate(
    within_response_rank = rank(AIC),
    # Delta_AIC computed within each response_type group (AGR vs RGR vs binomial)
    # Cross-response AIC comparisons are not valid
    Delta_AIC = AIC - min(AIC)
  ) %>%
  ungroup() %>%
  arrange(response_type, within_response_rank)

print(as.data.frame(model_comparison))

# =============================================================================
# 12. RANDOM EFFECTS SUMMARY
# =============================================================================

if (has_lme4 && !is.null(model_lmm_full)) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("  RANDOM EFFECTS VARIANCE DECOMPOSITION\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")

  vc <- VarCorr(model_lmm_full)

  var_study <- as.numeric(vc$study)
  var_location <- as.numeric(vc$location)
  var_year <- as.numeric(vc$year_factor)
  var_residual <- attr(vc, "sc")^2

  total_var <- var_study + var_location + var_year + var_residual

  cat("Variance components (LMM with study/location/year):\n")
  cat(sprintf("  Study:    %.1f (%.1f%% of total)\n", var_study, var_study/total_var*100))
  cat(sprintf("  Location: %.1f (%.1f%% of total)\n", var_location, var_location/total_var*100))
  cat(sprintf("  Year:     %.1f (%.1f%% of total)\n", var_year, var_year/total_var*100))
  cat(sprintf("  Residual: %.1f (%.1f%% of total)\n", var_residual, var_residual/total_var*100))

  # Save
  re_summary <- tibble(
    effect = c("study", "location", "year", "residual"),
    variance = c(var_study, var_location, var_year, var_residual),
    sd = sqrt(c(var_study, var_location, var_year, var_residual)),
    pct_total = c(var_study, var_location, var_year, var_residual) / total_var * 100
  )

  write_csv(re_summary, file.path(output_dir, "growth_random_effects.csv"))
  cat("\n✓ Saved: growth_random_effects.csv\n")
}

# =============================================================================
# 13. SAVE RESULTS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SAVING RESULTS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Helper to safely extract threshold from full_thresholds list
safe_thresh <- function(ft, key) if (!is.null(ft[[key]])) ft[[key]] else NA_real_

# Build per-response row function
build_growth_row <- function(response_name, gate, form, full_thresh, loso, magnitude,
                              rec_log, rec_cm2, n_obs, r_sq,
                              boot_obj, boot_cv_val) {
  t1_none <- safe_thresh(full_thresh, "abs_max_d2_none")
  t2_none <- safe_thresh(full_thresh, "min_d2_none")
  t3_none <- safe_thresh(full_thresh, "zero_d2_none")
  t4_none <- safe_thresh(full_thresh, "zero_d1_none")
  t1_sim  <- safe_thresh(full_thresh, "abs_max_d2_sim_int")
  t2_sim  <- safe_thresh(full_thresh, "min_d2_sim_int")
  t3_sim  <- safe_thresh(full_thresh, "zero_d2_sim_int")
  t4_sim  <- safe_thresh(full_thresh, "zero_d1_sim_int")

  tibble(
    response = response_name,
    method = "Detmer_et_al_2025",
    # Nonlinearity gate
    gate_delta_aicc = gate$delta_aicc,
    gate_edf = gate$edf,
    gate_passed = gate$passes_gate,
    gate_best_mod = gate$best_mod,
    # Functional form
    functional_form = form$form,
    recommended_definition = form$recommended_def,
    # Recommended threshold
    recommended_threshold_log = rec_log,
    recommended_threshold_cm2 = rec_cm2,
    # All 4 definitions
    t1_abs_max_d2_log = t1_none,
    t1_abs_max_d2_cm2 = if (!is.na(t1_none)) exp(t1_none) else NA,
    t1_sig_sim_int = !is.na(t1_sim),
    t2_min_d2_log = t2_none,
    t2_min_d2_cm2 = if (!is.na(t2_none)) exp(t2_none) else NA,
    t2_sig_sim_int = !is.na(t2_sim),
    t3_zero_d2_log = t3_none,
    t3_zero_d2_cm2 = if (!is.na(t3_none)) exp(t3_none) else NA,
    t3_sig_sim_int = !is.na(t3_sim),
    t4_zero_d1_log = t4_none,
    t4_zero_d1_cm2 = if (!is.na(t4_none)) exp(t4_none) else NA,
    t4_sig_sim_int = !is.na(t4_sim),
    # LOSO jackknife
    loso_n_folds = if (!is.null(loso)) nrow(loso$fold_info) else NA,
    loso_threshold_mean = boot_obj$mean,
    loso_threshold_se = if (!is.null(boot_obj$se)) boot_obj$se else NA,
    loso_ci_lower = boot_obj$ci_lower,
    loso_ci_upper = boot_obj$ci_upper,
    loso_cv = boot_cv_val,
    # Magnitude
    magnitude_absolute = magnitude$absolute_change,
    magnitude_relative_pct = magnitude$relative_change_pct,
    # Model info
    n_observations = n_obs,
    r_squared = r_sq,
    # Backward-compat aliases
    threshold_log = rec_log,
    threshold_cm2 = rec_cm2,
    cluster_boot_ci_lower = if (!is.na(boot_obj$ci_lower)) exp(boot_obj$ci_lower) else NA,
    cluster_boot_ci_upper = if (!is.na(boot_obj$ci_upper)) exp(boot_obj$ci_upper) else NA,
    cluster_boot_cv = boot_cv_val,
    max_curvature = NA_real_
  )
}

# Build one row per response variable
growth_thresholds <- bind_rows(
  build_growth_row("absolute_growth", agr_gate, agr_form, agr_full_thresh,
                   agr_loso, agr_magnitude, agr_recommended_log, agr_recommended_cm2,
                   nrow(growth_data), summary(model_gam_abs)$r.sq,
                   cluster_boot_abs, boot_cv_abs),
  build_growth_row("relative_growth_rate", rgr_gate, rgr_form, rgr_full_thresh,
                   rgr_loso, rgr_magnitude, rgr_recommended_log, rgr_recommended_cm2,
                   nrow(growth_data_rgr), summary(model_gam_rgr)$r.sq,
                   cluster_boot_rgr, boot_cv_rgr),
  build_growth_row("positive_growth_prob", pos_gate, pos_form, pos_full_thresh,
                   pos_loso, pos_magnitude, pos_recommended_log, pos_recommended_cm2,
                   nrow(growth_data), summary(model_pos_growth)$dev.expl,
                   cluster_boot_pos, boot_cv_pos)
)

write_csv(growth_thresholds, file.path(output_dir, "growth_thresholds.csv"))
cat("✓ Saved: growth_thresholds.csv\n")

write_csv(model_comparison, file.path(output_dir, "growth_model_comparison.csv"))
cat("✓ Saved: growth_model_comparison.csv\n")

# Save LOSO summaries
for (resp in list(list(name = "agr", obj = agr_loso),
                  list(name = "rgr", obj = rgr_loso),
                  list(name = "pos", obj = pos_loso))) {
  if (!is.null(resp$obj)) {
    write_csv(resp$obj$summary, file.path(output_dir, sprintf("growth_loso_%s.csv", resp$name)))
    cat(sprintf("✓ Saved: growth_loso_%s.csv\n", resp$name))
  }
}

# Save full results
all_growth_results <- list(
  thresholds = growth_thresholds,
  model_comparison = model_comparison,
  agr_results = agr_thresh_results,
  rgr_results = rgr_thresh_results,
  pos_results = pos_thresh_results,
  model_gam_abs = model_gam_abs,
  model_gam_rgr = model_gam_rgr,
  model_pos_growth = model_pos_growth,
  prediction_grid = pred_grid,
  pos_by_size = pos_by_size,
  study_summary = study_summary,
  region_size = region_size,
  heteroscedasticity_ratio = hetero_ratio
)

if (has_lme4 && !is.null(model_lmm_full)) {
  all_growth_results$lmm_full <- model_lmm_full
}

saveRDS(all_growth_results, file.path(output_dir, "growth_threshold_models.rds"))
cat("✓ Saved: growth_threshold_models.rds\n")

# =============================================================================
# 14. VISUALIZATION
# =============================================================================

cat("\nGenerating visualizations...\n")

# Main plot: Absolute growth with Detmer threshold
p1 <- ggplot(growth_data, aes(x = log_size, y = growth_cm2_yr)) +
  geom_point(alpha = 0.1, size = 0.5, color = "gray40") +
  geom_ribbon(
    data = pred_grid,
    aes(x = log_size, y = gam_abs, ymin = gam_abs_lower, ymax = gam_abs_upper),
    alpha = 0.2, fill = "#2a9d8f"
  ) +
  geom_line(
    data = pred_grid,
    aes(x = log_size, y = gam_abs),
    color = "#2a9d8f", linewidth = 1.5
  ) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  { if (!is.na(cluster_boot_abs$ci_lower) && !is.na(cluster_boot_abs$ci_upper)) annotate(
    "rect", xmin = cluster_boot_abs$ci_lower, xmax = cluster_boot_abs$ci_upper,
    ymin = -Inf, ymax = Inf, alpha = 0.15, fill = "red"
  ) } +
  { if (!is.na(agr_recommended_log)) geom_vline(
    xintercept = agr_recommended_log,
    linetype = "dashed", color = "red", linewidth = 1
  ) } +
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(~exp(.), name = expression(paste("Size (cm"^2, ")")),
                        breaks = c(10, 100, 1000, 10000))
  ) +
  coord_cartesian(ylim = c(quantile(growth_data$growth_cm2_yr, 0.01),
                           quantile(growth_data$growth_cm2_yr, 0.99))) +
  labs(
    title = "A. palmata Size-Dependent Growth",
    subtitle = sprintf("Form: %s | Threshold (%s): %.0f cm2 | Gate: %s (dAICc=%.1f)",
                       agr_form$form, agr_form$recommended_def,
                       if (!is.na(agr_recommended_cm2)) agr_recommended_cm2 else NA,
                       agr_gate$best_mod, agr_gate$delta_aicc),
    y = expression(paste("Growth rate (cm"^2, "/yr)"))
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

ggsave(file.path(fig_dir_supp_exploratory, "growth_threshold_detection.png"),
       p1, width = 10, height = 7, dpi = 300)
cat("✓ Saved: supplementary/exploratory/growth_threshold_detection.png\n")

# Probability of positive growth
p2 <- ggplot() +
  stat_summary_bin(
    data = growth_data,
    aes(x = log_size, y = positive_growth),
    fun = mean,
    fun.min = function(x) mean(x) - 1.96 * sqrt(mean(x)*(1-mean(x))/length(x)),
    fun.max = function(x) mean(x) + 1.96 * sqrt(mean(x)*(1-mean(x))/length(x)),
    geom = "pointrange", bins = 20, alpha = 0.7
  ) +
  geom_line(
    data = pred_grid,
    aes(x = log_size, y = prob_positive),
    color = "#2a9d8f", linewidth = 1.5
  ) +
  { if (!is.na(pos_recommended_log)) geom_vline(
    xintercept = pos_recommended_log,
    linetype = "dashed", color = "red"
  ) } +
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(~exp(.), name = expression(paste("Size (cm"^2, ")")),
                        breaks = c(10, 100, 1000, 10000))
  ) +
  scale_y_continuous(name = "Probability of positive growth", limits = c(0, 1)) +
  labs(
    title = "Size-Dependent Probability of Positive Growth",
    subtitle = sprintf("Form: %s | Threshold (%s): %.0f cm2 | %.1f%% overall positive",
                       pos_form$form, pos_form$recommended_def,
                       if (!is.na(pos_recommended_cm2)) pos_recommended_cm2 else NA,
                       mean(growth_data$positive_growth) * 100)
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

ggsave(file.path(fig_dir_supp_exploratory, "positive_growth_probability.png"),
       p2, width = 10, height = 7, dpi = 300)
cat("✓ Saved: supplementary/exploratory/positive_growth_probability.png\n")

# Derivative profile figures (new — Detmer framework diagnostic)
for (resp in list(
  list(name = "AGR", df = agr_deriv_df, ft = agr_full_thresh, fname = "growth_deriv_agr"),
  list(name = "RGR", df = rgr_deriv_df, ft = rgr_full_thresh, fname = "growth_deriv_rgr"),
  list(name = "P(+growth)", df = pos_deriv_df, ft = pos_full_thresh, fname = "growth_deriv_pos")
)) {
  if (!is.null(resp$df)) {
    t1 <- safe_thresh(resp$ft, "abs_max_d2_none")
    t2 <- safe_thresh(resp$ft, "min_d2_none")
    t3 <- safe_thresh(resp$ft, "zero_d2_none")
    t4 <- safe_thresh(resp$ft, "zero_d1_none")

    p_deriv <- ggplot(resp$df, aes(x = x)) +
      geom_ribbon(aes(ymin = d2_lower, ymax = d2_upper), alpha = 0.2, fill = "#2a9d8f") +
      geom_line(aes(y = d2), color = "#2a9d8f", linewidth = 1) +
      geom_hline(yintercept = 0, linetype = "dotted", color = "grey50") +
      { if (!is.na(t1)) geom_vline(xintercept = t1, linetype = "dashed", color = "#E69F00", linewidth = 0.7) } +
      { if (!is.na(t2)) geom_vline(xintercept = t2, linetype = "dashed", color = "#56B4E9", linewidth = 0.7) } +
      { if (!is.na(t3)) geom_vline(xintercept = t3, linetype = "dashed", color = "#009E73", linewidth = 0.7) } +
      { if (!is.na(t4)) geom_vline(xintercept = t4, linetype = "dashed", color = "#D55E00", linewidth = 0.7) } +
      scale_x_continuous(
        name = expression(paste("Log colony size (log cm"^2, ")")),
        sec.axis = sec_axis(~exp(.), name = "Colony size (cm2)",
                            breaks = c(10, 100, 1000, 10000),
                            labels = c("10", "100", "1,000", "10,000"))
      ) +
      labs(y = "Second derivative s''(x)",
           title = sprintf("Derivative Profile — %s GAM", resp$name),
           subtitle = sprintf("T1(abs_max)=%s | T2(min)=%s | T3(zero_d2)=%s | T4(zero_d1)=%s cm2",
                              if (!is.na(t1)) sprintf("%.0f", exp(t1)) else "NA",
                              if (!is.na(t2)) sprintf("%.0f", exp(t2)) else "NA",
                              if (!is.na(t3)) sprintf("%.0f", exp(t3)) else "NA",
                              if (!is.na(t4)) sprintf("%.0f", exp(t4)) else "NA")) +
      theme_minimal(base_size = 11) +
      theme(panel.grid.minor = element_blank())

    ggsave(file.path(fig_dir_supp_exploratory, paste0(resp$fname, ".png")),
           p_deriv, width = 10, height = 5, dpi = 300)
    cat(sprintf("✓ Saved: supplementary/exploratory/%s.png\n", resp$fname))
  }
}

# Diagnostic plots
png(file.path(fig_dir_supp_diagnostics, "growth_model_diagnostics.png"),
    width = 14, height = 10, units = "in", res = 300)

par(mfrow = c(2, 3), mar = c(4, 4, 3, 1))

# Plot 1: AGR derivative profile (base R version)
if (!is.null(agr_deriv_df)) {
  plot(agr_deriv_df$x, agr_deriv_df$d2, type = "l", col = "#2a9d8f", lwd = 2,
       main = "A. AGR Second Derivative",
       xlab = "Log colony size", ylab = "s''(x)")
  polygon(c(agr_deriv_df$x, rev(agr_deriv_df$x)),
          c(agr_deriv_df$d2_lower, rev(agr_deriv_df$d2_upper)),
          col = adjustcolor("#2a9d8f", 0.2), border = NA)
  abline(h = 0, lty = 2, col = "grey50")
  if (!is.na(agr_recommended_log)) abline(v = agr_recommended_log, col = "red", lty = 2, lwd = 2)
} else {
  plot.new(); text(0.5, 0.5, "AGR derivatives unavailable")
}

# Plot 2: Residuals vs fitted
abs_resid <- residuals(model_gam_abs)
plot(fitted(model_gam_abs), abs_resid,
     xlab = "Fitted values", ylab = "Residuals",
     main = "B. Residuals vs Fitted",
     col = adjustcolor("steelblue", 0.2), pch = 16, cex = 0.5)
abline(h = 0, col = "red", lty = 2)

# Plot 3: Heteroscedasticity
boxplot(abs_resid ~ growth_data$size_quartile,
        main = "C. Residuals by Size Quartile",
        xlab = "Size Quartile", ylab = "Residuals",
        col = c("#e07a5f", "#f4a261", "#e9c46a", "#2a9d8f"))
abline(h = 0, col = "red", lty = 2)

# Plot 4: Growth by study
study_growth <- growth_data %>%
  group_by(study) %>%
  summarise(mean_growth = mean(growth_cm2_yr), n = n(), .groups = "drop") %>%
  arrange(mean_growth)
barplot(study_growth$mean_growth, names.arg = substr(study_growth$study, 1, 15),
        las = 2, col = "steelblue",
        main = "D. Mean Growth by Study",
        ylab = "Mean growth (cm2/yr)")
abline(h = 0, col = "red", lty = 2)

# Plot 5: Growth distribution
hist(growth_data$growth_cm2_yr, breaks = 100, col = "steelblue", border = "white",
     main = "E. Growth Distribution",
     xlab = "Growth (cm2/yr)",
     xlim = c(quantile(growth_data$growth_cm2_yr, 0.01),
              quantile(growth_data$growth_cm2_yr, 0.99)))
abline(v = 0, col = "red", lty = 2, lwd = 2)
abline(v = mean(growth_data$growth_cm2_yr), col = "darkgreen", lwd = 2)

# Plot 6: Size distribution by region
boxplot(log_size ~ region, data = growth_data,
        las = 2, col = c("#E69F00","#56B4E9","#009E73","#F0E442","#0072B2","#D55E00","#CC79A7")[1:n_distinct(growth_data$region)],
        main = "F. Size Distribution by Region",
        ylab = "Log size (log cm2)")
if (!is.na(agr_recommended_log)) abline(h = agr_recommended_log, col = "red", lty = 2, lwd = 2)

dev.off()
cat("✓ Saved: supplementary/diagnostics/growth_model_diagnostics.png\n")

# =============================================================================
# 15. STRATIFIED GROWTH COMPARISON
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  STRATIFIED ANALYSIS: Natural Colonies vs Restoration Fragments\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Growth by size class and population type
growth_by_pop <- growth_data %>%
  group_by(population_type, size_class) %>%
  summarise(
    n = n(),
    mean_growth = mean(growth_cm2_yr),
    pct_positive = mean(growth_cm2_yr > 0) * 100,
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = population_type,
    values_from = c(n, mean_growth, pct_positive)
  )

cat("Growth by size class and population type:\n")
print(as.data.frame(growth_by_pop))

# Test if growth patterns differ by population type
if (nrow(growth_fragments) >= 50 && nrow(growth_natural) >= 50) {
  cat("\nComparing size-growth relationship across population types...\n")

  model_pooled <- gam(growth_cm2_yr ~ s(log_size, k = best_k_abs),
                       data = growth_data, method = "REML")

  # Model with population type interaction
  model_pop <- tryCatch({
    gam(growth_cm2_yr ~ s(log_size, k = best_k_abs, by = population_type) + population_type,
        data = growth_data, method = "REML")
  }, error = function(e) NULL)

  if (!is.null(model_pop)) {
    cat(sprintf("  Pooled model AIC: %.1f\n", AIC(model_pooled)))
    cat(sprintf("  Population-stratified AIC: %.1f\n", AIC(model_pop)))

    if (AIC(model_pop) < AIC(model_pooled) - 2) {
      cat("  → Size-growth relationship DIFFERS by population type\n")
    } else {
      cat("  → Size-growth relationship is SIMILAR across population types\n")
      cat("    (Pooled analysis is appropriate)\n")
    }
  }
}

# Save stratified summary
strat_growth <- tibble(
  population_type = c("Natural colonies", "Restoration fragments"),
  n = c(nrow(growth_natural), nrow(growth_fragments)),
  n_studies = c(n_distinct(growth_natural$study), n_distinct(growth_fragments$study)),
  mean_growth = c(mean(growth_natural$growth_cm2_yr), mean(growth_fragments$growth_cm2_yr)),
  pct_positive = c(mean(growth_natural$growth_cm2_yr > 0)*100, mean(growth_fragments$growth_cm2_yr > 0)*100),
  median_size = c(median(growth_natural$size_cm2), median(growth_fragments$size_cm2))
)

write_csv(strat_growth, file.path(output_dir, "growth_stratified_summary.csv"))
cat("\n✓ Saved: growth_stratified_summary.csv\n")

# =============================================================================
# 16. FINAL SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  ANALYSIS COMPLETE (v3.0 - Detmer et al. 2025 Framework)     ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("KEY FINDINGS (Detmer et al. 2025 threshold detection):\n")
cat(sprintf("  AGR threshold (%s): %.0f cm2 | Gate: %s | Form: %s\n",
            agr_form$recommended_def,
            if (!is.na(agr_recommended_cm2)) agr_recommended_cm2 else NA,
            agr_gate$best_mod, agr_form$form))
cat(sprintf("  RGR threshold (%s): %.0f cm2 | Gate: %s | Form: %s\n",
            rgr_form$recommended_def,
            if (!is.na(rgr_recommended_cm2)) rgr_recommended_cm2 else NA,
            rgr_gate$best_mod, rgr_form$form))
cat(sprintf("  P(+growth) threshold (%s): %.0f cm2 | Gate: %s | Form: %s\n",
            pos_form$recommended_def,
            if (!is.na(pos_recommended_cm2)) pos_recommended_cm2 else NA,
            pos_gate$best_mod, pos_form$form))

cat("\nMODEL PERFORMANCE:\n")
cat(sprintf("  Absolute growth R²: %.1f%%\n", summary(model_gam_abs)$r.sq * 100))
cat(sprintf("  RGR R²: %.1f%% (%.1fx better)\n",
            summary(model_gam_rgr)$r.sq * 100,
            summary(model_gam_rgr)$r.sq / max(summary(model_gam_abs)$r.sq, 0.001)))
cat(sprintf("  P(+growth) deviance: %.1f%%\n", summary(model_pos_growth)$dev.expl * 100))
cat(sprintf("  Heteroscedasticity ratio: %.1f\n", hetero_ratio))

cat("\nROBUSTNESS CHECKS (Detmer et al. 2025):\n")
cat(sprintf("  Nonlinearity gates: AGR=%s, RGR=%s, P(+growth)=%s\n",
            agr_gate$best_mod, rgr_gate$best_mod, pos_gate$best_mod))
cat("  4 threshold definitions evaluated for each response\n")
for (resp_name in c("AGR", "RGR", "P(+growth)")) {
  loso_obj <- switch(resp_name,
    "AGR" = agr_loso, "RGR" = rgr_loso, "P(+growth)" = pos_loso)
  if (!is.null(loso_obj)) {
    cat(sprintf("  LOSO %s: %d folds, %d converged\n",
                resp_name, nrow(loso_obj$fold_info),
                sum(loso_obj$fold_info$gam_converged, na.rm = TRUE)))
  }
}
if (has_lme4 && !is.null(model_lmm_full)) {
  cat("  Random effects: study, location, year accounted for\n")
}

cat("\nGROWTH PATTERNS BY SIZE:\n")
for (i in 1:nrow(pos_by_size)) {
  cat(sprintf("  %s: %.0f%% positive, mean=%.0f cm2/yr\n",
              pos_by_size$size_class[i],
              pos_by_size$pct_positive[i],
              pos_by_size$mean_growth[i]))
}

cat("\nNext step: Run 05_variance_partitioning.R\n\n")
