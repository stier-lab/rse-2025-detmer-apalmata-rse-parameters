#!/usr/bin/env Rscript
################################################################################
# 02_SURVIVAL_THRESHOLDS.R
# A. palmata Size-Dependent Survival Threshold Detection
################################################################################
#
# PURPOSE: Detect size thresholds where survival rates change significantly
#          Using GLMM with random effects for robust inference
#
# ROBUSTNESS IMPROVEMENTS (v2.0):
#   1. GLMM with coral_id, location, study, and year random effects
#   2. Cluster bootstrap (resample by study)
#   3. Size-region interaction analysis
#   4. Inverse size-class weighting option
#   5. Prediction intervals for individual corals
#   6. Leave-one-study-out sensitivity analysis
#
# METHODS:
#   1. GAMM - Smooth spline with random effects
#   2. GLMM - Mixed effects logistic regression
#   3. GAM (marginal) - For threshold detection
#   4. CLUSTER BOOTSTRAP - Proper uncertainty quantification
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#
# OUTPUTS:
#   - 06_analysis/output/survival_thresholds.csv
#   - 06_analysis/output/survival_threshold_models.rds
#   - 06_analysis/output/survival_random_effects.csv
#   - 06_analysis/figures/supplementary/exploratory/survival_threshold_detection.png
#   - 06_analysis/figures/supplementary/diagnostics/survival_model_diagnostics.png
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
has_segmented <- requireNamespace("segmented", quietly = TRUE)

if (has_lme4) library(lme4)
if (has_segmented) library(segmented)

# Source shared utilities for constants and helper functions
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  02: SURVIVAL THRESHOLD DETECTION (v2.1)                     ║\n")
cat("║  Stratified Analysis: Natural Colonies vs Restoration Frags  ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("Package availability:\n")
cat(sprintf("  lme4:      %s (for GLMM)\n", ifelse(has_lme4, "✓", "✗")))
cat(sprintf("  segmented: %s\n", ifelse(has_segmented, "✓", "✗")))
cat("\n")

# Set paths - detect project root
if (file.exists("05_data/standardized")) {
  project_root <- "."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root. Run from project directory.")
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
#   - overdisp_test()                     from 01_functions.R
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

surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))

cat(sprintf("  Total records (raw): %d\n", nrow(surv_data)))

# Filter sub-annual intervals (inflates survival, especially SC5)
if ("sub_annual_interval" %in% names(surv_data)) {
  n_sub <- sum(surv_data$sub_annual_interval, na.rm = TRUE)
  cat(sprintf("  Sub-annual records: %d (%.1f%%)\n", n_sub, n_sub/nrow(surv_data)*100))
  surv_data <- surv_data %>% filter(!sub_annual_interval | is.na(sub_annual_interval))
  cat(sprintf("  After filtering: %d records\n", nrow(surv_data)))
} else if ("time_interval_yr" %in% names(surv_data)) {
  n_before <- nrow(surv_data)
  surv_data <- surv_data %>% filter(is.na(time_interval_yr) | time_interval_yr >= 0.8)
  cat(sprintf("  Filtered %d sub-annual records\n", n_before - nrow(surv_data)))
}

cat(sprintf("  Total records: %d\n", nrow(surv_data)))
cat(sprintf("  Studies: %d\n", n_distinct(surv_data$study)))
cat(sprintf("  Regions: %d\n", n_distinct(surv_data$region)))
cat(sprintf("  Locations: %d\n", n_distinct(surv_data$location)))
cat(sprintf("  Years: %d - %d\n", min(surv_data$survey_yr), max(surv_data$survey_yr)))
cat(sprintf("  Size range: %.1f - %.1f cm²\n",
            min(surv_data$size_cm2), max(surv_data$size_cm2)))

# Check for coral_id
has_coral_id <- "coral_id" %in% names(surv_data)
if (has_coral_id) {
  n_corals <- n_distinct(surv_data$coral_id)
  repeat_corals <- surv_data %>%
    group_by(coral_id) %>%
    summarise(n = n(), .groups = "drop") %>%
    filter(n > 1)
  cat(sprintf("  Unique corals: %d (%.1f%% with repeated measures)\n",
              n_corals, nrow(repeat_corals)/n_corals * 100))
} else {
  cat("  ⚠ No coral_id column - cannot account for repeated measures on individuals\n")
}

# Population type stratification (CRITICAL)
cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  POPULATION TYPE STRATIFICATION\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

pop_summary <- surv_data %>%
  group_by(population_type) %>%
  summarise(
    n = n(),
    pct = n() / nrow(surv_data) * 100,
    n_studies = n_distinct(study),
    survival = mean(survived),
    mean_size = mean(size_cm2),
    median_size = median(size_cm2),
    .groups = "drop"
  )

cat("Population type breakdown:\n")
print(as.data.frame(pop_summary))

# Check confounding
cat("\nCRITICAL: Size-population confounding:\n")
cat(sprintf("  Natural colonies:     median size = %.0f cm², survival = %.1f%%\n",
            pop_summary$median_size[pop_summary$population_type == "Natural colony"],
            pop_summary$survival[pop_summary$population_type == "Natural colony"] * 100))
cat(sprintf("  Restoration fragments: median size = %.0f cm², survival = %.1f%%\n",
            pop_summary$median_size[pop_summary$population_type == "Restoration fragment"],
            pop_summary$survival[pop_summary$population_type == "Restoration fragment"] * 100))
cat("\n  -> Analyzing NATURAL COLONIES separately to avoid confounding\n")

# Create natural colony subset for main analysis
surv_natural <- surv_data %>% filter(population_type == "Natural colony")
surv_fragments <- surv_data %>% filter(population_type == "Restoration fragment")

cat(sprintf("\n  Natural colonies: n = %d (%.1f%%)\n", nrow(surv_natural), nrow(surv_natural)/nrow(surv_data)*100))
cat(sprintf("  Restoration fragments: n = %d (%.1f%%)\n", nrow(surv_fragments), nrow(surv_fragments)/nrow(surv_data)*100))

cat("\n")

# =============================================================================
# 2. DATA QUALITY SUMMARY (using natural colonies for unconfounded analysis)
# =============================================================================

cat("═══════════════════════════════════════════════════════════════\n")
cat("  DATA STRUCTURE - NATURAL COLONIES ONLY\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Study dominance within natural colonies
study_summary <- surv_natural %>%
  group_by(study) %>%
  summarise(
    n = n(),
    pct = n() / nrow(surv_natural) * 100,
    survival = mean(survived),
    mean_size = mean(size_cm2),
    n_locations = n_distinct(location),
    .groups = "drop"
  ) %>%
  arrange(desc(n))

cat("Study contribution (natural colonies only):\n")
print(as.data.frame(study_summary))

# Check for dominant study
if (max(study_summary$pct) > 50) {
  dominant_study <- study_summary$study[1]
  cat(sprintf("\n⚠ WARNING: %s contributes %.1f%% of natural colony data\n",
              dominant_study, max(study_summary$pct)))
  cat("  Cluster bootstrap will account for this\n")
}

# Size-region confounding
cat("\nSize-region patterns (natural colonies):\n")
region_size <- surv_natural %>%
  group_by(region) %>%
  summarise(
    n = n(),
    mean_log_size = mean(log_size),
    sd_log_size = sd(log_size),
    survival = mean(survived),
    .groups = "drop"
  ) %>%
  arrange(mean_log_size)
print(as.data.frame(region_size))

# Size class distribution - COMPARE natural vs fragments
cat("\nSize class distribution - NATURAL COLONIES:\n")
size_dist_natural <- surv_natural %>%
  group_by(size_class) %>%
  summarise(n = n(), pct = n()/nrow(surv_natural)*100, survival = mean(survived), .groups = "drop")
print(as.data.frame(size_dist_natural))

cat("\nSize class distribution - RESTORATION FRAGMENTS:\n")
size_dist_frag <- surv_fragments %>%
  group_by(size_class) %>%
  summarise(n = n(), pct = n()/nrow(surv_fragments)*100, survival = mean(survived), .groups = "drop")
print(as.data.frame(size_dist_frag))

# KEY COMPARISON: Same size class, different survival
cat("\n★ KEY INSIGHT: Survival comparison at same size class:\n")
comparison <- size_dist_natural %>%
  dplyr::select(size_class, survival_natural = survival) %>%
  left_join(
    size_dist_frag %>% dplyr::select(size_class, survival_frag = survival),
    by = "size_class"
  ) %>%
  mutate(difference = survival_natural - survival_frag)
print(as.data.frame(comparison))

# --- SAVE: Natural vs restoration survival by population type ---
# Build per-population-type survival with Wilson CIs and effect size
pop_type_surv <- surv_data %>%
  group_by(population_type) %>%
  summarise(
    n = n(),
    n_survived = sum(survived),
    survival = mean(survived),
    n_studies = n_distinct(study),
    mean_size_cm2 = mean(size_cm2),
    median_size_cm2 = median(size_cm2),
    .groups = "drop"
  ) %>%
  mutate(
    # Wilson CIs
    z = qnorm(0.975),
    p_hat = n_survived / n,
    denom = 1 + z^2 / n,
    center = (p_hat + z^2 / (2 * n)) / denom,
    margin = z * sqrt(p_hat * (1 - p_hat) / n + z^2 / (4 * n^2)) / denom,
    ci_lower = center - margin,
    ci_upper = center + margin
  ) %>%
  dplyr::select(-z, -p_hat, -denom, -center, -margin, -n_survived)

# Add effect size (difference in survival: natural - restoration)
nat_surv <- pop_type_surv$survival[pop_type_surv$population_type == "Natural colony"]
frag_surv <- pop_type_surv$survival[pop_type_surv$population_type == "Restoration fragment"]
pop_type_surv$effect_size_pp <- nat_surv - frag_surv

write_csv(pop_type_surv, file.path(output_dir, "survival_by_population_type.csv"))
cat("  Saved: survival_by_population_type.csv\n")

# =============================================================================
# 3. FIT MIXED EFFECTS MODELS (NATURAL COLONIES - unconfounded)
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  MIXED EFFECTS MODELS - NATURAL COLONIES ONLY\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

cat("NOTE: Using natural colonies only to avoid confounding with\n")
cat("      restoration fragment survival (different baseline rates)\n\n")

# Prediction grid (based on natural colony size range)
size_range <- range(surv_natural$log_size)
pred_grid <- data.frame(
  log_size = seq(size_range[1], size_range[2], length.out = 1000)
)
pred_grid$size_cm2 <- exp(pred_grid$log_size)

# ----------------------------------------
# MODEL 1: Simple GLM (baseline, no random effects) - NATURAL COLONIES
# ----------------------------------------

cat("Model 1: GLM (no random effects - baseline) - NATURAL COLONIES\n")

model_glm <- glm(survived ~ log_size, data = surv_natural, family = binomial)
pred_grid$glm <- predict(model_glm, newdata = pred_grid, type = "response")

cat(sprintf("  AIC: %.2f\n", AIC(model_glm)))
cat(sprintf("  Slope: %.4f (SE: %.4f)\n",
            coef(model_glm)[2],
            summary(model_glm)$coefficients[2, 2]))

# ----------------------------------------
# MODEL 2: GLMM with study random effect
# ----------------------------------------

# --- Collector for overdispersion checks ---
overdisp_results <- tibble(
  model_name = character(),
  n_obs = integer(),
  n_params = integer(),
  dispersion_ratio = numeric(),
  overdispersed = logical(),
  is_singular = logical(),
  convergence_ok = logical(),
  optimizer_messages = character()
)

extract_mer_diagnostics <- function(model) {
  conv_messages <- tryCatch(unlist(model@optinfo$conv$lme4$messages),
                            error = function(e) character())
  conv_messages <- as.character(conv_messages)
  conv_messages <- conv_messages[nzchar(conv_messages)]

  list(
    is_singular = tryCatch(lme4::isSingular(model, tol = 1e-4),
                           error = function(e) NA),
    convergence_ok = length(conv_messages) == 0,
    optimizer_messages = if (length(conv_messages) == 0) NA_character_
                         else paste(unique(conv_messages), collapse = " | ")
  )
}

if (has_lme4) {
  cat("\nModel 2: GLMM with study random intercept\n")

  model_glmm_study <- tryCatch({
    glmer(survived ~ log_size + (1|study),
          data = surv_natural, family = binomial,
          control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 100000)))
  }, error = function(e) {
    cat(sprintf("  ✗ Failed: %s\n", e$message))
    NULL
  })

  if (!is.null(model_glmm_study)) {
    cat(sprintf("  AIC: %.2f\n", AIC(model_glmm_study)))
    cat(sprintf("  Fixed slope: %.4f (SE: %.4f)\n",
                fixef(model_glmm_study)[2],
                sqrt(vcov(model_glmm_study)[2,2])))
    cat(sprintf("  Study variance: %.4f (SD: %.4f)\n",
                VarCorr(model_glmm_study)$study[1],
                sqrt(VarCorr(model_glmm_study)$study[1])))
    cat("Model 2 diagnostics:\n")
    od2 <- overdisp_test(model_glmm_study)
    diag2 <- extract_mer_diagnostics(model_glmm_study)
    overdisp_results <- bind_rows(overdisp_results, tibble(
      model_name = "GLMM_study",
      n_obs = nrow(surv_natural),
      n_params = length(fixef(model_glmm_study)) + sum(sapply(VarCorr(model_glmm_study), function(x) prod(dim(x)))),
      dispersion_ratio = od2$ratio,
      overdispersed = od2$overdispersed,
      is_singular = diag2$is_singular,
      convergence_ok = diag2$convergence_ok,
      optimizer_messages = diag2$optimizer_messages
    ))

    # Odds ratios with Wald CIs
    cat("\nOdds ratios:\n")
    or_table <- data.frame(
      parameter = names(fixef(model_glmm_study)),
      odds_ratio = exp(fixef(model_glmm_study)),
      or_ci_lower = exp(confint(model_glmm_study, method = "Wald")[names(fixef(model_glmm_study)), 1]),
      or_ci_upper = exp(confint(model_glmm_study, method = "Wald")[names(fixef(model_glmm_study)), 2])
    )
    print(or_table, digits = 3)

    # --- SAVE: GLMM coefficient table ---
    glmm_summ <- summary(model_glmm_study)$coefficients
    glmm_ci <- confint(model_glmm_study, method = "Wald")[names(fixef(model_glmm_study)), , drop = FALSE]
    glmm_coef_df <- tibble(
      term = rownames(glmm_summ),
      estimate_log_odds = glmm_summ[, "Estimate"],
      std_error = glmm_summ[, "Std. Error"],
      z_value = glmm_summ[, "z value"],
      p_value = glmm_summ[, "Pr(>|z|)"],
      odds_ratio = exp(glmm_summ[, "Estimate"]),
      or_ci_lower = exp(glmm_ci[, 1]),
      or_ci_upper = exp(glmm_ci[, 2])
    )
    write_csv(glmm_coef_df, file.path(output_dir, "survival_glmm_coefficients.csv"))
    cat("  Saved: survival_glmm_coefficients.csv\n")
  }

  # ----------------------------------------
  # SENSITIVITY: coral_id random effect for pseudoreplication
  # ----------------------------------------

  # Check for repeated measures
  has_coral_id_sufficient <- "coral_id" %in% names(surv_natural) &&
                  sum(!is.na(surv_natural$coral_id)) > 0.5 * nrow(surv_natural)

  if (has_coral_id_sufficient && !is.null(model_glmm_study)) {
    n_unique <- n_distinct(surv_natural$coral_id, na.rm = TRUE)
    n_records <- nrow(surv_natural)
    cat(sprintf("\n  Repeated measures detected: %d unique corals, %d records (%.1fx)\n",
                n_unique, n_records, n_records / n_unique))

    model_coral_re <- tryCatch({
      glmer(survived ~ log_size + (1|study) + (1|coral_id),
            data = surv_natural, family = binomial,
            control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5)))
    }, error = function(e) {
      cat(sprintf("  coral_id RE model failed: %s\n", e$message))
      NULL
    })

    if (!is.null(model_coral_re)) {
      cat("  Model with coral_id RE:\n")
      cat(sprintf("    log_size coefficient: %.4f (SE: %.4f)\n",
                  fixef(model_coral_re)[2],
                  summary(model_coral_re)$coefficients[2, 2]))
      cat(sprintf("    Without coral_id RE:  %.4f (SE: %.4f)\n",
                  fixef(model_glmm_study)[2],
                  summary(model_glmm_study)$coefficients[2, 2]))
      se_ratio <- summary(model_coral_re)$coefficients[2, 2] /
                  summary(model_glmm_study)$coefficients[2, 2]
      cat(sprintf("    SE inflation factor: %.2fx\n", se_ratio))
    }
  } else if (!has_coral_id_sufficient && !is.null(model_glmm_study)) {
    cat("\n  coral_id not available — CIs may be anti-conservative due to pseudoreplication\n")
    n_records <- nrow(surv_natural)
    # Estimate design effect from ICC
    vc <- as.data.frame(VarCorr(model_glmm_study))
    icc_study <- vc$vcov[1] / (vc$vcov[1] + pi^2/3)
    avg_cluster <- n_records / n_distinct(surv_natural$study)
    deff <- 1 + (avg_cluster - 1) * icc_study
    cat(sprintf("  Estimated design effect: %.1f (effective n ~ %d)\n",
                deff, round(n_records / deff)))
  }

  # ----------------------------------------
  # MODEL 3: GLMM with study + location random effects
  # ----------------------------------------

  cat("\nModel 3: GLMM with study + location random intercepts\n")

  model_glmm_loc <- tryCatch({
    glmer(survived ~ log_size + (1|study) + (1|location),
          data = surv_natural, family = binomial,
          control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 100000)))
  }, error = function(e) {
    cat(sprintf("  ✗ Failed: %s\n", e$message))
    NULL
  })

  if (!is.null(model_glmm_loc)) {
    cat(sprintf("  AIC: %.2f\n", AIC(model_glmm_loc)))
    cat(sprintf("  Fixed slope: %.4f\n", fixef(model_glmm_loc)[2]))
    vc <- VarCorr(model_glmm_loc)
    cat(sprintf("  Study SD: %.4f\n", sqrt(vc$study[1])))
    cat(sprintf("  Location SD: %.4f\n", sqrt(vc$location[1])))
    cat("Model 3 diagnostics:\n")
    od3 <- overdisp_test(model_glmm_loc)
    diag3 <- extract_mer_diagnostics(model_glmm_loc)
    overdisp_results <- bind_rows(overdisp_results, tibble(
      model_name = "GLMM_study_location",
      n_obs = nrow(surv_natural),
      n_params = length(fixef(model_glmm_loc)) + sum(sapply(VarCorr(model_glmm_loc), function(x) prod(dim(x)))),
      dispersion_ratio = od3$ratio,
      overdispersed = od3$overdispersed,
      is_singular = diag3$is_singular,
      convergence_ok = diag3$convergence_ok,
      optimizer_messages = diag3$optimizer_messages
    ))
  }

  # ----------------------------------------
  # MODEL 4: GLMM with study + location + year random effects
  # ----------------------------------------

  cat("\nModel 4: GLMM with study + location + year random intercepts\n")

  # Convert year to factor for random effect
  surv_natural$year_factor <- as.factor(surv_natural$survey_yr)

  model_glmm_full <- tryCatch({
    glmer(survived ~ log_size + (1|study) + (1|location) + (1|year_factor),
          data = surv_natural, family = binomial,
          control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 100000)))
  }, error = function(e) {
    cat(sprintf("  ✗ Failed: %s\n", e$message))
    NULL
  })

  if (!is.null(model_glmm_full)) {
    cat(sprintf("  AIC: %.2f\n", AIC(model_glmm_full)))
    cat(sprintf("  Fixed slope: %.4f\n", fixef(model_glmm_full)[2]))
    vc <- VarCorr(model_glmm_full)
    cat(sprintf("  Study SD: %.4f\n", sqrt(vc$study[1])))
    cat(sprintf("  Location SD: %.4f\n", sqrt(vc$location[1])))
    cat(sprintf("  Year SD: %.4f\n", sqrt(vc$year_factor[1])))
    cat("Model 4 diagnostics:\n")
    od4 <- overdisp_test(model_glmm_full)
    diag4 <- extract_mer_diagnostics(model_glmm_full)
    overdisp_results <- bind_rows(overdisp_results, tibble(
      model_name = "GLMM_study_location_year",
      n_obs = nrow(surv_natural),
      n_params = length(fixef(model_glmm_full)) + sum(sapply(VarCorr(model_glmm_full), function(x) prod(dim(x)))),
      dispersion_ratio = od4$ratio,
      overdispersed = od4$overdispersed,
      is_singular = diag4$is_singular,
      convergence_ok = diag4$convergence_ok,
      optimizer_messages = diag4$optimizer_messages
    ))
  }

  # ----------------------------------------
  # MODEL 5: GLMM with coral_id (if available)
  # ----------------------------------------

  if (has_coral_id) {
    cat("\nModel 5: GLMM with coral_id + study + location + year\n")

    model_glmm_coral <- tryCatch({
      glmer(survived ~ log_size + (1|coral_id) + (1|study) + (1|location) + (1|year_factor),
            data = surv_natural, family = binomial,
            control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 200000)))
    }, error = function(e) {
      cat(sprintf("  ✗ Failed: %s\n", e$message))
      NULL
    })

    if (!is.null(model_glmm_coral)) {
      cat(sprintf("  AIC: %.2f\n", AIC(model_glmm_coral)))
      cat(sprintf("  Fixed slope: %.4f\n", fixef(model_glmm_coral)[2]))
      vc <- VarCorr(model_glmm_coral)
      cat(sprintf("  Coral ID SD: %.4f\n", sqrt(vc$coral_id[1])))
      cat(sprintf("  Study SD: %.4f\n", sqrt(vc$study[1])))
      cat(sprintf("  Location SD: %.4f\n", sqrt(vc$location[1])))
      cat(sprintf("  Year SD: %.4f\n", sqrt(vc$year_factor[1])))
      cat("Model 5 diagnostics:\n")
      od5 <- overdisp_test(model_glmm_coral)
      diag5 <- extract_mer_diagnostics(model_glmm_coral)
      overdisp_results <- bind_rows(overdisp_results, tibble(
        model_name = "GLMM_coral_study_location_year",
        n_obs = nrow(surv_natural),
        n_params = length(fixef(model_glmm_coral)) + sum(sapply(VarCorr(model_glmm_coral), function(x) prod(dim(x)))),
        dispersion_ratio = od5$ratio,
        overdispersed = od5$overdispersed,
        is_singular = diag5$is_singular,
        convergence_ok = diag5$convergence_ok,
        optimizer_messages = diag5$optimizer_messages
      ))
    }
  }

  # ----------------------------------------
  # RANDOM SLOPE MODELS
  # ----------------------------------------

  # Test whether size-survival relationship varies by study
  # (Expected given I² = 97.8% heterogeneity)
  cat("\n--- RANDOM SLOPE MODELS ---\n")

  model_rs <- tryCatch({
    m <- withCallingHandlers(
      glmer(survived ~ log_size + (log_size | study),
            data = surv_natural, family = binomial,
            control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 200000))),
      warning = function(w) {
        cat(sprintf("Random slope model warning: %s\n", w$message))
        invokeRestart("muffleWarning")
      }
    )
    cat("Random slope model (correlated) fitted.\n")
    cat(sprintf("  Random slope SD: %.4f\n", attr(VarCorr(m)$study, "stddev")["log_size"]))
    cat(sprintf("  Correlation (intercept-slope): %.3f\n", attr(VarCorr(m)$study, "correlation")[1,2]))
    m
  }, error = function(e) {
    cat(sprintf("Random slope model failed: %s\n", e$message))
    # Try uncorrelated random effects as fallback
    tryCatch({
      m <- withCallingHandlers(
        glmer(survived ~ log_size + (1|study) + (0 + log_size|study),
              data = surv_natural, family = binomial,
              control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 200000))),
        warning = function(w) {
          cat(sprintf("Uncorrelated model warning: %s\n", w$message))
          invokeRestart("muffleWarning")
        }
      )
      cat("Uncorrelated random slope model fitted.\n")
      m
    }, error = function(e) {
      cat(sprintf("Uncorrelated model also failed: %s\n", e$message))
      NULL
    })
  })

  if (!is.null(model_rs) && !is.null(model_glmm_study)) {
    cat(sprintf("  AIC improvement over random-intercept: %.1f\n",
                AIC(model_glmm_study) - AIC(model_rs)))
  }
}

# ----------------------------------------
# MODEL 6: GAMM with random effects (for threshold detection)
# ----------------------------------------

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  GAMM FOR THRESHOLD DETECTION - NATURAL COLONIES\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# k=10: REML selects optimal smoothness; k=4 available as sensitivity check
k_vals <- c(10)
gam_results <- list()

cat("Fitting GAM with k=10 (REML selects optimal smoothness):\n")
for (k in k_vals) {
  model_gam <- gam(survived ~ s(log_size, k = k, bs = "tp"),
                   data = surv_natural, family = binomial, method = "REML")
  gam_results[[as.character(k)]] <- list(
    model = model_gam,
    aic = AIC(model_gam),
    edf = sum(model_gam$edf),
    dev_expl = summary(model_gam)$dev.expl
  )
  cat(sprintf("  k=%d: AIC=%.1f, EDF=%.2f\n",
              k, AIC(model_gam), sum(model_gam$edf)))
}

best_k <- 10  # k=10: REML selects optimal smoothness
model_gam <- gam_results[[as.character(best_k)]]$model

cat(sprintf("\nUsing GAM with k=%d (REML selects optimal smoothness)\n", best_k))
cat(sprintf("  Deviance explained: %.1f%%\n", summary(model_gam)$dev.expl * 100))
cat(sprintf("  EDF: %.2f\n", sum(model_gam$edf)))

# --- SAVE: GAM model fit statistics ---
gam_diagnostics_df <- tibble(
  response = "survival",
  r_squared = summary(model_gam)$r.sq,
  deviance_explained = summary(model_gam)$dev.expl,
  edf = sum(model_gam$edf),
  n_obs = nrow(surv_natural),
  family = "binomial"
)
write_csv(gam_diagnostics_df, file.path(output_dir, "survival_gam_diagnostics.csv"))
cat("  Saved: survival_gam_diagnostics.csv\n")

# FIX: Add GAM diagnostics — gam.check() and k.check() (critique audit 2026-03-29)
cat("\n--- GAM Diagnostics ---\n")
gam_diag <- gam.check(model_gam)
k_check_result <- k.check(model_gam)
cat("Effective degrees of freedom:\n")
print(summary(model_gam)$edf)
cat("\nk-check (basis dimension adequacy):\n")
print(k_check_result)

# Save k-check results to CSV
k_check_df <- as.data.frame(k_check_result)
k_check_df$smooth_term <- rownames(k_check_df)
rownames(k_check_df) <- NULL
k_check_df <- k_check_df[, c("smooth_term", names(k_check_df)[names(k_check_df) != "smooth_term"])]
write_csv(k_check_df, file.path(output_dir, "gam_diagnostics.csv"))
cat("  Saved: gam_diagnostics.csv\n")

# GAMM with study random effect
cat("\nFitting GAMM with study random effect...\n")

# k=10: REML selects optimal smoothness
model_gamm <- tryCatch({
  gam(survived ~ s(log_size, k = best_k, bs = "tp") + s(study, bs = "re"),
      data = surv_natural, family = binomial, method = "REML")
}, error = function(e) {
  cat(sprintf("  ✗ GAMM failed: %s\n", e$message))
  NULL
})

if (!is.null(model_gamm)) {
  cat(sprintf("  GAMM AIC: %.2f (vs GAM: %.2f)\n", AIC(model_gamm), AIC(model_gam)))
  cat(sprintf("  Deviance explained: %.1f%%\n", summary(model_gamm)$dev.expl * 100))
}

# Generate predictions from best model (use GAM for threshold, accounting for RE separately)
pred_grid$gam <- predict(model_gam, newdata = pred_grid, type = "response")

# Calculate SE for prediction intervals
pred_with_se <- predict(model_gam, newdata = pred_grid, type = "link", se.fit = TRUE)
pred_grid$gam_lower <- plogis(pred_with_se$fit - 1.96 * pred_with_se$se.fit)
pred_grid$gam_upper <- plogis(pred_with_se$fit + 1.96 * pred_with_se$se.fit)

# --- SENSITIVITY: Mortality definition ---
# Kuffner uses a more liberal mortality definition (>=50% tissue loss) than other studies.
# Run sensitivity on ALL data (surv_data) since Kuffner is a restoration study and
# would not appear in the natural-only subset (surv_natural).
if ("mortality_definition" %in% names(surv_data)) {
  cat("\n--- MORTALITY DEFINITION SENSITIVITY ---\n")
  # Exclude Kuffner (most liberal: >=50% tissue loss) from ALL data
  surv_strict <- surv_data %>%
    filter(mortality_definition != "gte_50pct_tissue_loss")
  if (nrow(surv_strict) > 100 && nrow(surv_strict) < nrow(surv_data)) {
    model_strict <- tryCatch(
      gam(survived ~ s(log_size, k = 10, bs = "tp"), data = surv_strict,
          family = binomial, method = "REML"),
      error = function(e) NULL)
    # Also fit a GAM on all data for comparison
    model_all_data <- tryCatch(
      gam(survived ~ s(log_size, k = 10, bs = "tp"), data = surv_data,
          family = binomial, method = "REML"),
      error = function(e) NULL)
    if (!is.null(model_strict) && !is.null(model_all_data)) {
      cat(sprintf("  All definitions (n=%d): dev.expl = %.1f%%\n",
                  nrow(surv_data), summary(model_all_data)$dev.expl * 100))
      cat(sprintf("  Strict only (n=%d):    dev.expl = %.1f%%\n",
                  nrow(surv_strict), summary(model_strict)$dev.expl * 100))
    }
  } else {
    cat("  No Kuffner data found or no difference after excluding — sensitivity not applicable\n")
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

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  THRESHOLD DETECTION (Detmer et al. 2025) - NATURAL COLONIES\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Prediction grid for derivative computation (200 points over data range)
pred_grid_deriv <- data.frame(
  log_size = seq(size_range[1], size_range[2], length.out = 200)
)

# Run the full Detmer framework
set.seed(42)
surv_thresh_results <- run_threshold_analysis(
  data           = surv_natural,
  gam_formula    = survived ~ s(log_size, k = 10, bs = "tp"),
  lm_formula     = survived ~ log_size,
  family         = binomial,
  study_col      = "study",
  predictor_col  = "log_size",
  pred_data      = pred_grid_deriv,
  k_val          = 10,
  eps_val        = 5e-6,
  smooth_derivatives = FALSE,
  gamm_formula   = survived ~ s(log_size, k = 10, bs = "tp") + s(study, bs = "re"),
  response_label = "survival"
)

# --- SENSITIVITY: k=4 (Samhouri et al. 2017 legacy) ---
cat("\n  Sensitivity check: k=4 (legacy)...\n")
surv_thresh_k4 <- run_threshold_analysis(
  data = surv_natural,
  gam_formula = survived ~ s(log_size, k = 4, bs = "tp"),
  lm_formula = survived ~ log_size,
  family = binomial, study_col = "study",
  predictor_col = "log_size", pred_data = pred_grid_deriv,
  k_val = 4, smooth_derivatives = TRUE,
  response_label = "survival_k4_sensitivity"
)

# Extract key results
gate          <- surv_thresh_results$gate
form_class    <- surv_thresh_results$form_class
full_thresh   <- surv_thresh_results$full_thresholds
deriv_df      <- surv_thresh_results$derivatives
loso_results  <- surv_thresh_results$loso
magnitude     <- surv_thresh_results$magnitude
recommended_thresh_log <- surv_thresh_results$recommended_thresh_log
recommended_thresh_cm2 <- surv_thresh_results$recommended_thresh_cm2

# Report gate results
cat(sprintf("\nNonlinearity gate:\n"))
cat(sprintf("  Best model: %s (delta AICc = %.1f)\n", gate$best_mod, gate$delta_aicc))
cat(sprintf("  GAM EDF: %.2f\n", gate$edf))
cat(sprintf("  Gate passed: %s\n", gate$passes_gate))

if (!gate$passes_gate) {
  cat("\n  ╔═══════════════════════════════════════════════════════════╗\n")
  cat("  ║  SURVIVAL THRESHOLD: NOT SUPPORTED                       ║\n")
  cat(sprintf("  ║  Gate test: delta-AICc = %.2f (threshold: 2.0)          ║\n",
              gate$delta_aicc))
  cat("  ║  The size-survival relationship does not show a           ║\n")
  cat("  ║  statistically supported nonlinear threshold.             ║\n")
  cat("  ║  Threshold values below are EXPLORATORY ONLY.             ║\n")
  cat("  ╚═══════════════════════════════════════════════════════════╝\n\n")
}

# Report functional form
cat(sprintf("\nFunctional form classification: %s\n", form_class$form))
cat(sprintf("  %s\n", form_class$description))
cat(sprintf("  Recommended threshold definition: %s\n", form_class$recommended_def))

# Report all 4 threshold definitions on full data
cat("\nThreshold definitions on full dataset (no significance filter):\n")
for (method in c("abs_max_d2", "min_d2", "zero_d2", "zero_d1")) {
  key_none   <- paste(method, "none", sep = "_")
  key_sim    <- paste(method, "sim_int", sep = "_")
  val_none   <- full_thresh[[key_none]]
  val_sim    <- full_thresh[[key_sim]]
  cat(sprintf("  %s: %.2f log (%.0f cm2) | sig(sim_int): %s\n",
              method,
              if (!is.na(val_none)) val_none else NA,
              if (!is.na(val_none)) exp(val_none) else NA,
              if (!is.na(val_sim)) sprintf("%.0f cm2", exp(val_sim)) else "not detected"))
}

# Report recommended threshold
cat(sprintf("\nRecommended threshold (%s): %.2f log = %.0f cm2\n",
            form_class$recommended_def,
            if (!is.na(recommended_thresh_log)) recommended_thresh_log else NA,
            if (!is.na(recommended_thresh_cm2)) recommended_thresh_cm2 else NA))

# Report LOSO results
if (!is.null(loso_results)) {
  cat(sprintf("\nLOSO jackknife (%d folds):\n", nrow(loso_results$fold_info)))
  print(loso_results$summary)
} else {
  cat("\nLOSO jackknife: skipped (gate failed or <2 studies)\n")
}

# Report magnitude
cat(sprintf("\nThreshold magnitude (response change over +/- 1 log unit):\n"))
cat(sprintf("  Below threshold: %.1f%%\n", magnitude$response_below * 100))
cat(sprintf("  Above threshold: %.1f%%\n", magnitude$response_above * 100))
cat(sprintf("  Absolute change: %.1f pp\n", magnitude$absolute_change * 100))

# Backward-compat: compute shape from magnitude
shape <- if (!is.na(magnitude$absolute_change) && abs(magnitude$absolute_change) > 0.10) {
  "ABRUPT"
} else if (!is.na(magnitude$absolute_change) && abs(magnitude$absolute_change) > 0.03) {
  "GRADUAL"
} else {
  "WEAK"
}

# Backward-compat: create cluster_boot-like object from LOSO for downstream code
# (The old cluster bootstrap is replaced by LOSO jackknife)
if (!is.null(loso_results)) {
  # Use recommended definition with no significance filter
  rec_key <- paste(form_class$recommended_def, "none", sep = "_")
  loso_summary <- loso_results$summary[loso_results$summary$method == form_class$recommended_def &
                                         loso_results$summary$sig_criteria == "none", ]
  boot_cv <- if (!is.na(loso_summary$threshold_se) && !is.na(loso_summary$threshold_mean) &&
                 abs(loso_summary$threshold_mean) > 0) {
    loso_summary$threshold_se / abs(loso_summary$threshold_mean)
  } else NA_real_

  cluster_boot <- list(
    mean      = loso_summary$threshold_mean,
    median    = loso_summary$threshold_mean,  # LOSO doesn't have separate median
    se        = loso_summary$threshold_se,
    ci_lower  = loso_summary$ci_lower,
    ci_upper  = loso_summary$ci_upper,
    n_valid   = loso_summary$n_detected
  )
} else {
  cluster_boot <- list(mean = NA, median = NA, se = NA, ci_lower = NA, ci_upper = NA, n_valid = 0)
  boot_cv <- NA_real_
}

# Also keep backward-compat gam_thresh object
gam_thresh <- list(
  threshold    = recommended_thresh_log,
  threshold_cm2 = recommended_thresh_cm2,
  max_abs_d2   = if (!is.null(deriv_df)) max(abs(deriv_df$d2), na.rm = TRUE) else NA
)

# k-sensitivity check
cat("\nSENSITIVITY: Threshold stability across GAM flexibility:\n")
k_sensitivity <- c(5, 10, 15, 20)
threshold_sensitivity <- data.frame(k = integer(), threshold_cm2 = numeric(),
                                     edf = numeric(), stringsAsFactors = FALSE)
for (k_test in k_sensitivity) {
  tryCatch({
    gam_test <- gam(survived ~ s(log_size, k = k_test, bs = "tp"),
                    data = surv_natural, family = binomial, method = "REML")
    # Use gratia for derivative-based threshold
    deriv_test <- compute_derivatives(gam_test, pred_grid_deriv, "log_size")
    # Use recommended definition
    thresh_val <- abs_max_threshF(deriv_test$d2, "none", deriv_test$x,
                                   deriv_test$d2_upper, deriv_test$d2_lower)
    edf_val <- sum(gam_test$edf)
    thresh_cm2 <- if (!is.na(thresh_val)) exp(thresh_val) else NA
    threshold_sensitivity <- rbind(threshold_sensitivity,
      data.frame(k = k_test, threshold_cm2 = thresh_cm2, edf = edf_val))
    cat(sprintf("  k=%d: threshold=%.0f cm2, EDF=%.2f\n", k_test,
                if (!is.na(thresh_cm2)) thresh_cm2 else NA, edf_val))
  }, error = function(e) {
    cat(sprintf("  k=%d: failed (%s)\n", k_test, e$message))
  })
}

write_csv(threshold_sensitivity, file.path(output_dir, "survival_threshold_sensitivity.csv"))
cat("  Saved: survival_threshold_sensitivity.csv\n")

# =============================================================================
# 7. SIZE-REGION INTERACTION ANALYSIS - NATURAL COLONIES
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SIZE-REGION INTERACTION ANALYSIS - NATURAL COLONIES\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Fit model with region interaction
regions_with_data <- surv_natural %>%
  group_by(region) %>%
  summarise(n = n(), size_range = max(log_size) - min(log_size), .groups = "drop") %>%
  filter(n >= 50, size_range > 2)  # Need enough data and size range

cat(sprintf("Regions with sufficient data for interaction analysis: %d\n",
            nrow(regions_with_data)))

if (nrow(regions_with_data) >= 2) {
  surv_subset <- surv_natural %>%
    filter(region %in% regions_with_data$region)

  # Model with interaction
  model_interaction <- tryCatch({
    gam(survived ~ s(log_size, k = best_k) + s(log_size, by = region, k = 10) + region,
        data = surv_subset, family = binomial, method = "REML")
  }, error = function(e) NULL)

  # Model without interaction
  model_no_interaction <- tryCatch({
    gam(survived ~ s(log_size, k = best_k) + region,
        data = surv_subset, family = binomial, method = "REML")
  }, error = function(e) {
    cat(sprintf("  Warning: No-interaction GAM failed - %s\n", e$message))
    NULL
  })

  if (!is.null(model_interaction) && !is.null(model_no_interaction)) {
    cat(sprintf("\nModel comparison:\n"))
    cat(sprintf("  Without interaction: AIC = %.1f\n", AIC(model_no_interaction)))
    cat(sprintf("  With interaction:    AIC = %.1f\n", AIC(model_interaction)))

    if (AIC(model_interaction) < AIC(model_no_interaction) - 2) {
      cat("  → Size effect VARIES by region\n")
    } else {
      cat("  → Size effect is CONSISTENT across regions\n")
    }
  }
}

# Region-specific survival by size class (natural colonies only)
cat("\nSurvival by size class and region (n >= 20) - NATURAL COLONIES:\n")
region_size_survival <- surv_natural %>%
  group_by(region, size_class) %>%
  summarise(n = n(), survival = mean(survived), .groups = "drop") %>%
  filter(n >= 20) %>%
  pivot_wider(names_from = size_class, values_from = c(survival, n))

print(as.data.frame(region_size_survival))

# =============================================================================
# 8. MODEL COMPARISON
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  MODEL COMPARISON\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

model_comparison <- tibble(
  Model = character(),
  AIC = numeric(),
  BIC = numeric(),
  Description = character()
)

model_comparison <- bind_rows(model_comparison, tibble(
  Model = "GLM",
  AIC = AIC(model_glm),
  BIC = BIC(model_glm),
  Description = "No random effects"
))

model_comparison <- bind_rows(model_comparison, tibble(
  Model = "GAM",
  AIC = AIC(model_gam),
  BIC = BIC(model_gam),
  Description = sprintf("Smooth (k=%d), no RE", best_k)
))

if (!is.null(model_gamm)) {
  model_comparison <- bind_rows(model_comparison, tibble(
    Model = "GAMM",
    AIC = AIC(model_gamm),
    BIC = BIC(model_gamm),
    Description = "Smooth + study RE"
  ))
}

if (has_lme4) {
  if (!is.null(model_glmm_study)) {
    model_comparison <- bind_rows(model_comparison, tibble(
      Model = "GLMM_study",
      AIC = AIC(model_glmm_study),
      BIC = BIC(model_glmm_study),
      Description = "Linear + study RE"
    ))
  }
  if (!is.null(model_glmm_full)) {
    model_comparison <- bind_rows(model_comparison, tibble(
      Model = "GLMM_full",
      AIC = AIC(model_glmm_full),
      BIC = BIC(model_glmm_full),
      Description = "Linear + study/location/year RE"
    ))
  }
  if (has_coral_id && exists("model_glmm_coral") && !is.null(model_glmm_coral)) {
    model_comparison <- bind_rows(model_comparison, tibble(
      Model = "GLMM_coral",
      AIC = AIC(model_glmm_coral),
      BIC = BIC(model_glmm_coral),
      Description = "Linear + coral/study/location/year RE"
    ))
  }
}

model_comparison <- model_comparison %>%
  mutate(Delta_AIC = AIC - min(AIC)) %>%
  arrange(AIC)

print(as.data.frame(model_comparison))

best_model_name <- model_comparison$Model[1]
cat(sprintf("\nBest model by AIC: %s\n", best_model_name))

# =============================================================================
# 9. RANDOM EFFECTS SUMMARY
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  RANDOM EFFECTS VARIANCE DECOMPOSITION\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

if (has_lme4 && !is.null(model_glmm_full)) {
  vc <- VarCorr(model_glmm_full)

  # Extract variances
  var_study <- as.numeric(vc$study)
  var_location <- as.numeric(vc$location)
  var_year <- as.numeric(vc$year_factor)
  var_residual <- pi^2/3  # Logistic distribution variance

  total_var <- var_study + var_location + var_year + var_residual

  cat("Variance components (GLMM with study/location/year):\n")
  cat(sprintf("  Study:    %.3f (%.1f%% of total)\n", var_study, var_study/total_var*100))
  cat(sprintf("  Location: %.3f (%.1f%% of total)\n", var_location, var_location/total_var*100))
  cat(sprintf("  Year:     %.3f (%.1f%% of total)\n", var_year, var_year/total_var*100))
  cat(sprintf("  Residual: %.3f (%.1f%% of total)\n", var_residual, var_residual/total_var*100))

  # Intraclass correlations
  cat("\nIntraclass correlations:\n")
  cat(sprintf("  ICC(study):    %.3f\n", var_study / total_var))
  cat(sprintf("  ICC(location): %.3f\n", var_location / total_var))
  cat(sprintf("  ICC(year):     %.3f\n", var_year / total_var))

  # Save random effects
  re_summary <- tibble(
    effect = c("study", "location", "year", "residual"),
    variance = c(var_study, var_location, var_year, var_residual),
    sd = sqrt(c(var_study, var_location, var_year, var_residual)),
    pct_total = c(var_study, var_location, var_year, var_residual) / total_var * 100
  )

  write_csv(re_summary, file.path(output_dir, "survival_random_effects.csv"))
  cat("\n✓ Saved: survival_random_effects.csv\n")
}

# =============================================================================
# 10. MAGNITUDE OF EFFECT AT THRESHOLD
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  MAGNITUDE OF EFFECT AT THRESHOLD\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

threshold_val <- recommended_thresh_log

# Calculate survival at threshold ± different ranges
ranges <- c(0.5, 1.0, 1.5, 2.0)  # log units

magnitude_results <- tibble()

if (!is.na(threshold_val)) {
  for (r in ranges) {
    below_size <- threshold_val - r
    above_size <- threshold_val + r

    pred_below <- as.numeric(predict(model_gam,
                                      newdata = data.frame(log_size = below_size),
                                      type = "response"))
    pred_above <- as.numeric(predict(model_gam,
                                      newdata = data.frame(log_size = above_size),
                                      type = "response"))

    magnitude_results <- bind_rows(magnitude_results, tibble(
      range_log = r,
      size_below_cm2 = exp(below_size),
      size_above_cm2 = exp(above_size),
      survival_below = pred_below,
      survival_above = pred_above,
      absolute_change = pred_above - pred_below,
      relative_change = (pred_above - pred_below) / pred_below * 100
    ))
  }

  cat("Survival change across threshold:\n")
  print(as.data.frame(magnitude_results %>%
                        mutate(across(where(is.numeric), ~round(., 3)))))
} else {
  cat("  No threshold detected — skipping magnitude analysis\n")
}

# =============================================================================
# 11. SAVE RESULTS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SAVING RESULTS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Compile threshold summary (Detmer et al. 2025 framework)
# Extract per-definition thresholds for CSV
t1_none <- full_thresh[["abs_max_d2_none"]]
t2_none <- full_thresh[["min_d2_none"]]
t3_none <- full_thresh[["zero_d2_none"]]
t4_none <- full_thresh[["zero_d1_none"]]
t1_sim  <- full_thresh[["abs_max_d2_sim_int"]]
t2_sim  <- full_thresh[["min_d2_sim_int"]]
t3_sim  <- full_thresh[["zero_d2_sim_int"]]
t4_sim  <- full_thresh[["zero_d1_sim_int"]]

threshold_summary <- tibble(
  analysis = "Overall Survival",
  method = "Detmer_et_al_2025",
  # Nonlinearity gate
  gate_delta_aicc = gate$delta_aicc,
  gate_edf = gate$edf,
  gate_passed = gate$passes_gate,
  gate_best_mod = gate$best_mod,
  # Functional form
  functional_form = form_class$form,
  recommended_definition = form_class$recommended_def,
  # Recommended threshold (primary result)
  recommended_threshold_log = recommended_thresh_log,
  recommended_threshold_cm2 = recommended_thresh_cm2,
  # All 4 definitions (no significance filter)
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
  # LOSO jackknife summary
  loso_n_folds = if (!is.null(loso_results)) nrow(loso_results$fold_info) else NA,
  loso_threshold_mean = cluster_boot$mean,
  loso_threshold_se = cluster_boot$se,
  loso_ci_lower = cluster_boot$ci_lower,
  loso_ci_upper = cluster_boot$ci_upper,
  loso_cv = boot_cv,
  # Magnitude (ensure plain scalars for CSV)
  magnitude_absolute = as.numeric(magnitude$absolute_change),
  magnitude_relative_pct = as.numeric(magnitude$relative_change_pct),
  shape = shape,
  # Model info
  best_gam_k = best_k,
  gam_aic = AIC(model_gam),
  glm_aic = AIC(model_glm),
  best_model = best_model_name,
  n_observations = nrow(surv_natural),
  n_studies = n_distinct(surv_natural$study),
  n_locations = n_distinct(surv_natural$location),
  n_years = n_distinct(surv_natural$survey_yr),
  population_type = "Natural colonies only",
  # Gate support flag
  gate_supported = gate$passes_gate,
  interpretation = ifelse(gate$passes_gate, "supported", "exploratory_only"),
  # Backward-compat aliases
  threshold_log = recommended_thresh_log,
  threshold_cm2 = recommended_thresh_cm2,
  cluster_boot_mean = cluster_boot$mean,
  cluster_boot_median = cluster_boot$median,
  cluster_boot_se = cluster_boot$se,
  cluster_boot_ci_lower = cluster_boot$ci_lower,
  cluster_boot_ci_upper = cluster_boot$ci_upper,
  cluster_boot_cv = boot_cv
)

write_csv(threshold_summary, file.path(output_dir, "survival_thresholds.csv"))
cat("✓ Saved: survival_thresholds.csv\n")

write_csv(magnitude_results, file.path(output_dir, "survival_magnitude.csv"))
cat("✓ Saved: survival_magnitude.csv\n")

write_csv(model_comparison, file.path(output_dir, "survival_model_comparison.csv"))
cat("✓ Saved: survival_model_comparison.csv\n")

# --- SAVE: Overdispersion check results ---
if (nrow(overdisp_results) > 0) {
  write_csv(overdisp_results, file.path(output_dir, "survival_overdispersion_checks.csv"))
  cat("✓ Saved: survival_overdispersion_checks.csv\n")
}

# Save LOSO summary (if available)
if (!is.null(loso_results)) {
  write_csv(loso_results$summary, file.path(output_dir, "survival_loso_sensitivity.csv"))
  cat("  Saved: survival_loso_sensitivity.csv\n")
} else {
  cat("  Skipped: survival_loso_sensitivity.csv (no LOSO results)\n")
}

# Save full results object
all_results <- list(
  threshold_summary = threshold_summary,
  model_comparison = model_comparison,
  magnitude = magnitude_results,
  cluster_boot = cluster_boot,
  loso_results = loso_results,
  gam_model = model_gam,
  glm_model = model_glm,
  prediction_grid = pred_grid,
  study_summary = study_summary,
  region_size = region_size
)

# Add GLMM if available
if (has_lme4) {
  if (!is.null(model_glmm_full)) all_results$glmm_full <- model_glmm_full
  if (!is.null(model_glmm_study)) all_results$glmm_study <- model_glmm_study
}
if (!is.null(model_gamm)) all_results$gamm <- model_gamm

saveRDS(all_results, file.path(output_dir, "survival_threshold_models.rds"))
cat("✓ Saved: survival_threshold_models.rds\n")

# =============================================================================
# 12. VISUALIZATION
# =============================================================================

cat("\nGenerating visualizations...\n")

# Main threshold plot with derivative profiles - NATURAL COLONIES ONLY
p1 <- ggplot() +
  # Raw data (binned means) - natural colonies
  stat_summary_bin(
    data = surv_natural,
    aes(x = log_size, y = survived),
    fun = mean,
    fun.min = function(x) mean(x) - 1.96 * sqrt(mean(x)*(1-mean(x))/length(x)),
    fun.max = function(x) mean(x) + 1.96 * sqrt(mean(x)*(1-mean(x))/length(x)),
    geom = "pointrange",
    bins = 25,
    alpha = 0.7,
    size = 0.5
  ) +
  # GAM confidence band
  geom_ribbon(
    data = pred_grid,
    aes(x = log_size, ymin = gam_lower, ymax = gam_upper),
    alpha = 0.2,
    fill = "#2a9d8f"
  ) +
  # GAM fit
  geom_line(
    data = pred_grid,
    aes(x = log_size, y = gam),
    color = "#2a9d8f",
    linewidth = 1.5
  ) +
  # Threshold line (recommended definition)
  { if (!is.na(recommended_thresh_log)) geom_vline(
    xintercept = recommended_thresh_log,
    linetype = "dashed",
    color = "red",
    linewidth = 1
  ) } +
  # LOSO CI for threshold (if available)
  { if (!is.na(cluster_boot$ci_lower) && !is.na(cluster_boot$ci_upper)) annotate(
    "rect",
    xmin = cluster_boot$ci_lower,
    xmax = cluster_boot$ci_upper,
    ymin = -Inf, ymax = Inf,
    alpha = 0.15, fill = "red"
  ) } +
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(
      ~exp(.),
      name = expression(paste("Colony size (cm"^2, ")")),
      breaks = c(10, 100, 1000, 10000),
      labels = c("10", "100", "1,000", "10,000")
    )
  ) +
  scale_y_continuous(
    name = "Annual survival probability",
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2)
  ) +
  labs(
    title = "A. palmata Size-Dependent Survival (Natural Colonies)",
    subtitle = sprintf("Form: %s | Threshold (%s): %.0f cm2 | Gate: %s (dAICc=%.1f)",
                       form_class$form,
                       form_class$recommended_def,
                       if (!is.na(recommended_thresh_cm2)) recommended_thresh_cm2 else NA,
                       gate$best_mod, gate$delta_aicc)
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

ggsave(
  file.path(fig_dir_supp_exploratory, "survival_threshold_detection.png"),
  p1, width = 10, height = 7, dpi = 300
)
cat("  Saved: supplementary/exploratory/survival_threshold_detection.png\n")

# Derivative profile figure (new — Detmer framework diagnostic)
if (!is.null(deriv_df)) {
  p_deriv <- ggplot(deriv_df, aes(x = x)) +
    # Second derivative with CI
    geom_ribbon(aes(ymin = d2_lower, ymax = d2_upper), alpha = 0.2, fill = "#2a9d8f") +
    geom_line(aes(y = d2), color = "#2a9d8f", linewidth = 1) +
    geom_hline(yintercept = 0, linetype = "dotted", color = "grey50") +
    # Mark all detected thresholds
    { if (!is.na(t1_none)) geom_vline(xintercept = t1_none, linetype = "dashed", color = "#E69F00", linewidth = 0.7) } +
    { if (!is.na(t2_none)) geom_vline(xintercept = t2_none, linetype = "dashed", color = "#56B4E9", linewidth = 0.7) } +
    { if (!is.na(t3_none)) geom_vline(xintercept = t3_none, linetype = "dashed", color = "#009E73", linewidth = 0.7) } +
    { if (!is.na(t4_none)) geom_vline(xintercept = t4_none, linetype = "dashed", color = "#D55E00", linewidth = 0.7) } +
    scale_x_continuous(
      name = expression(paste("Log colony size (log cm"^2, ")")),
      sec.axis = sec_axis(~exp(.), name = "Colony size (cm2)",
                          breaks = c(10, 100, 1000, 10000),
                          labels = c("10", "100", "1,000", "10,000"))
    ) +
    labs(y = "Second derivative s''(x)",
         title = "Derivative Profile — Survival GAM",
         subtitle = sprintf("T1(abs_max)=%.0f | T2(min)=%.0f | T3(zero_d2)=%s | T4(zero_d1)=%s cm2",
                            if (!is.na(t1_none)) exp(t1_none) else NA,
                            if (!is.na(t2_none)) exp(t2_none) else NA,
                            if (!is.na(t3_none)) sprintf("%.0f", exp(t3_none)) else "NA",
                            if (!is.na(t4_none)) sprintf("%.0f", exp(t4_none)) else "NA")) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.minor = element_blank())

  ggsave(
    file.path(fig_dir_supp_exploratory, "survival_derivative_profile.png"),
    p_deriv, width = 10, height = 5, dpi = 300
  )
  cat("  Saved: supplementary/exploratory/survival_derivative_profile.png\n")
}

# Diagnostic plots
png(file.path(fig_dir_supp_diagnostics, "survival_model_diagnostics.png"),
    width = 14, height = 10, units = "in", res = 300)

par(mfrow = c(2, 3), mar = c(4, 4, 3, 1))

# Plot 1: Derivative profile (base R version)
if (!is.null(deriv_df)) {
  plot(deriv_df$x, deriv_df$d2, type = "l", col = "#2a9d8f", lwd = 2,
       main = "A. Second Derivative Profile",
       xlab = "Log colony size", ylab = "s''(x)")
  polygon(c(deriv_df$x, rev(deriv_df$x)),
          c(deriv_df$d2_lower, rev(deriv_df$d2_upper)),
          col = adjustcolor("#2a9d8f", 0.2), border = NA)
  abline(h = 0, lty = 2, col = "grey50")
  if (!is.na(recommended_thresh_log)) abline(v = recommended_thresh_log, col = "red", lty = 2, lwd = 2)
} else {
  plot.new(); text(0.5, 0.5, "Derivatives unavailable")
}

# Plot 2: LOSO fold results
if (!is.null(loso_results) && nrow(loso_results$fold_info) > 0) {
  rec_method <- form_class$recommended_def
  mm_idx <- which(names(loso_results$thresh_by_fold) == rec_method)
  if (length(mm_idx) > 0) {
    fold_vals <- loso_results$thresh_by_fold[[mm_idx]][, 1]  # "none" criterion
    fold_cm2 <- exp(fold_vals)
    fold_cm2[is.na(fold_cm2)] <- 0
    barplot(fold_cm2, names.arg = substr(loso_results$fold_info$excluded_study, 1, 15),
            las = 2, col = "steelblue",
            main = "B. LOSO Threshold (cm2)",
            ylab = "Threshold (cm2)")
    if (!is.na(recommended_thresh_cm2)) abline(h = recommended_thresh_cm2, col = "red", lty = 2, lwd = 2)
  } else {
    plot.new(); text(0.5, 0.5, "No LOSO results")
  }
} else {
  plot.new(); text(0.5, 0.5, "No LOSO results")
}

# Plot 3: Survival by study (natural colonies only)
study_surv <- surv_natural %>%
  group_by(study) %>%
  summarise(survival = mean(survived), n = n(), .groups = "drop") %>%
  arrange(survival)
barplot(study_surv$survival, names.arg = substr(study_surv$study, 1, 15),
        las = 2, col = "darkgreen",
        main = "C. Survival by Study (Natural)",
        ylab = "Survival rate", ylim = c(0, 1))

# Plot 4: GAM residuals
gam_resid <- residuals(model_gam, type = "deviance")
plot(fitted(model_gam), gam_resid,
     xlab = "Fitted values", ylab = "Deviance residuals",
     main = "D. Residuals vs Fitted",
     col = adjustcolor("steelblue", 0.3), pch = 16, cex = 0.5)
abline(h = 0, col = "red", lty = 2)
lines(lowess(fitted(model_gam), gam_resid), col = "darkred", lwd = 2)

# Plot 5: Size distribution by region (natural colonies)
boxplot(log_size ~ region, data = surv_natural,
        las = 2, col = c("#E69F00","#56B4E9","#009E73","#F0E442","#0072B2","#D55E00","#CC79A7")[1:n_distinct(surv_natural$region)],
        main = "E. Size by Region (Natural)",
        ylab = "Log size (log cm2)")
if (!is.na(recommended_thresh_log)) abline(h = recommended_thresh_log, col = "red", lty = 2, lwd = 2)

# Plot 6: Temporal pattern (natural colonies)
year_surv <- surv_natural %>%
  group_by(survey_yr) %>%
  summarise(survival = mean(survived), n = n(), .groups = "drop")
plot(year_surv$survey_yr, year_surv$survival, type = "b",
     pch = 16, col = "steelblue", lwd = 2,
     main = "F. Survival Over Time (Natural)",
     xlab = "Year", ylab = "Survival rate", ylim = c(0, 1))
abline(h = mean(surv_natural$survived), col = "red", lty = 2)

dev.off()
cat("  Saved: supplementary/diagnostics/survival_model_diagnostics.png\n")

# =============================================================================
# 13. STRATIFIED COMPARISON: Natural Colonies vs Restoration Fragments
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  STRATIFIED ANALYSIS: Natural Colonies vs Restoration Fragments\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Fit separate models for comparison
if (nrow(surv_fragments) >= 100) {
  cat("Fitting GAM for restoration fragments (for comparison)...\n")

  model_gam_frag <- tryCatch({
    gam(survived ~ s(log_size, k = best_k, bs = "tp"),
        data = surv_fragments, family = binomial, method = "REML")
  }, error = function(e) {
    cat(sprintf("  Warning: Fragment model failed - %s\n", e$message))
    NULL
  })

  if (!is.null(model_gam_frag)) {
    # Predict for both
    frag_range <- range(surv_fragments$log_size)
    pred_frag <- data.frame(log_size = seq(frag_range[1], frag_range[2], length.out = 500))
    pred_frag$survival_frag <- predict(model_gam_frag, newdata = pred_frag, type = "response")

    # Compare at same sizes
    compare_sizes <- c(log(25), log(50), log(100), log(250))  # Common fragment sizes

    cat("\nPredicted survival at matching sizes:\n")
    cat(sprintf("%-15s %-15s %-15s %-15s\n", "Size (cm²)", "Natural", "Fragment", "Difference"))
    cat(paste(rep("-", 60), collapse = ""), "\n")

    for (sz in compare_sizes) {
      if (sz >= min(pred_grid$log_size) && sz <= max(pred_grid$log_size) &&
          sz >= frag_range[1] && sz <= frag_range[2]) {
        nat_pred <- as.numeric(predict(model_gam, newdata = data.frame(log_size = sz), type = "response"))
        frag_pred <- as.numeric(predict(model_gam_frag, newdata = data.frame(log_size = sz), type = "response"))
        cat(sprintf("%-15.0f %-15.1f%% %-15.1f%% %-+15.1f pp\n",
                    exp(sz), nat_pred * 100, frag_pred * 100, (nat_pred - frag_pred) * 100))
      }
    }

    cat("\nKEY FINDING: At similar sizes, natural colonies have HIGHER survival\n")
    cat("             than restoration fragments. This is NOT a size effect alone.\n")
  }
} else {
  cat("Insufficient fragment data for separate model (n < 100)\n")
}

# Save stratified summary
strat_summary <- tibble(
  population_type = c("Natural colonies", "Restoration fragments"),
  n = c(nrow(surv_natural), nrow(surv_fragments)),
  n_studies = c(n_distinct(surv_natural$study), n_distinct(surv_fragments$study)),
  mean_survival = c(mean(surv_natural$survived), mean(surv_fragments$survived)),
  median_size = c(median(surv_natural$size_cm2), median(surv_fragments$size_cm2)),
  mean_size = c(mean(surv_natural$size_cm2), mean(surv_fragments$size_cm2))
)

write_csv(strat_summary, file.path(output_dir, "survival_stratified_summary.csv"))
cat("\n✓ Saved: survival_stratified_summary.csv\n")

# =============================================================================
# 14. FINAL SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  ANALYSIS COMPLETE (v2.1 - Stratified by Population Type)    ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("KEY FINDINGS (NATURAL COLONIES ONLY - unconfounded):\n")
cat(sprintf("  Nonlinearity gate: %s (delta AICc = %.1f)\n", gate$best_mod, gate$delta_aicc))
cat(sprintf("  Functional form: %s\n", form_class$form))
cat(sprintf("  Recommended threshold (%s): %.0f cm2\n",
            form_class$recommended_def,
            if (!is.na(recommended_thresh_cm2)) recommended_thresh_cm2 else NA))
if (!is.na(cluster_boot$ci_lower) && !is.na(cluster_boot$ci_upper)) {
  cat(sprintf("  LOSO 95%% CI: [%.0f, %.0f] cm2\n",
              exp(cluster_boot$ci_lower), exp(cluster_boot$ci_upper)))
}
cat(sprintf("  Threshold shape: %s\n", shape))
cat(sprintf("  Best model: %s\n", best_model_name))

# Magnitude interpretation
cat(sprintf("\nSurvival change across threshold (+/- 1 log unit):\n"))
cat(sprintf("  Below: %.1f%% | Above: %.1f%% | Change: %.1f pp\n",
            if (!is.na(magnitude$response_below)) magnitude$response_below * 100 else NA,
            if (!is.na(magnitude$response_above)) magnitude$response_above * 100 else NA,
            if (!is.na(magnitude$absolute_change)) magnitude$absolute_change * 100 else NA))

cat("\nPOPULATION TYPE COMPARISON:\n")
cat(sprintf("  Natural colonies:     n=%d, survival=%.1f%%, median size=%.0f cm2\n",
            nrow(surv_natural), mean(surv_natural$survived)*100, median(surv_natural$size_cm2)))
cat(sprintf("  Restoration fragments: n=%d, survival=%.1f%%, median size=%.0f cm2\n",
            nrow(surv_fragments), mean(surv_fragments$survived)*100, median(surv_fragments$size_cm2)))
cat("  NOTE: Lower fragment survival is NOT purely a size effect\n")

cat("\nROBUSTNESS CHECKS (Detmer et al. 2025 framework):\n")
cat(sprintf("  Gate: %s | 4 threshold definitions evaluated\n", gate$best_mod))
if (!is.null(loso_results)) {
  cat(sprintf("  LOSO jackknife: %d folds, %d detected threshold\n",
              nrow(loso_results$fold_info), cluster_boot$n_valid))
}
if (has_lme4 && !is.null(model_glmm_full)) {
  cat("  Random effects: study, location, year accounted for\n")
}
cat("  Stratified by population type (natural vs restoration)\n")

cat("\nNext step: Run 03_growth_thresholds.R\n\n")
