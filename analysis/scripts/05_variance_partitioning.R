#!/usr/bin/env Rscript
################################################################################
# 05_VARIANCE_PARTITIONING.R
# A. palmata Demographic Variation: Size × Space × Time Framework
################################################################################
#
# PURPOSE: Analyze how demographic rates vary across:
#   - SIZE: Colony size classes
#   - SPACE: Geographic regions
#   - TIME: Temporal trends and year effects
#   Including Size × Space and Size × Time interactions
#
# METHODS:
#   1. GLMM for survival (binomial, random effects for study/site)
#   2. LMM for growth (Gaussian, random effects)
#   3. Variance partitioning
#   4. Interaction tests
#
# INPUTS:
#   - analysis/output/prepared_survival_data.rds
#   - analysis/output/prepared_growth_data.rds
#
# OUTPUTS:
#   - analysis/output/size_space_time_survival.csv
#   - analysis/output/size_space_time_growth.csv
#   - analysis/output/variance_partitioning.csv
#   - analysis/figures/supplementary/exploratory/size_space_time_panels.png
#   - analysis/figures/supplementary/exploratory/size_region_heatmap.png
#
# Author: Detmer & Stier Lab
# Date: 2025-12-22
################################################################################

# Load required packages
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(mgcv)

# Try to load lme4 for mixed models
has_lme4 <- requireNamespace("lme4", quietly = TRUE)
if (has_lme4) {
  library(lme4)
  library(lmerTest)
}

# Source shared utilities for constants and helper functions
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("analysis/scripts/utils/shared_utilities.R")) {
  source("analysis/scripts/utils/shared_utilities.R")
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  05: SIZE × SPACE × TIME ANALYSIS                            ║\n")
cat("║  How Demographic Rates Vary Across Dimensions                ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# Set paths - detect project root automatically
if (file.exists("standardized_data")) {
  project_root <- "."
} else if (file.exists("../../standardized_data")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root. Run from project directory or analysis/scripts/")
}

output_dir <- file.path(project_root, "analysis/output")
fig_dir <- file.path(project_root, "analysis/figures")
fig_dir_supp_exploratory <- file.path(fig_dir, "supplementary/exploratory")
dir.create(fig_dir_supp_exploratory, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1. LOAD DATA
# =============================================================================

cat("Loading prepared data...\n")

surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

cat(sprintf("  Survival records: %d\n", nrow(surv_data)))
cat(sprintf("  Growth records: %d\n", nrow(growth_data)))
cat(sprintf("  Regions: %s\n", paste(unique(surv_data$region), collapse = ", ")))
cat(sprintf("  Year range: %d-%d\n",
            min(surv_data$survey_yr), max(surv_data$survey_yr)))
cat("\n")

# =============================================================================
# 2. SURVIVAL: SIZE × SPACE × TIME
# =============================================================================

cat("═══════════════════════════════════════════════════════════════\n")
cat("  PART A: SURVIVAL ANALYSIS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# ----------------------------------------
# 2.1 SIZE EFFECTS (within region means)
# ----------------------------------------

cat("A.1 SIZE EFFECTS:\n")

# Wilson confidence intervals (better coverage near 0 or 1)
wilson_ci <- function(x, n, alpha = 0.05) {
  z <- qnorm(1 - alpha/2)
  p_hat <- x / n
  denom <- 1 + z^2/n
  center <- (p_hat + z^2/(2*n)) / denom
  margin <- z * sqrt(p_hat*(1-p_hat)/n + z^2/(4*n^2)) / denom
  list(lower = center - margin, upper = center + margin)
}

survival_by_size <- surv_data %>%
  group_by(size_class) %>%
  summarise(
    n = n(),
    n_survived = sum(survived),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    .groups = "drop"
  ) %>%
  mutate(
    wilson = mapply(function(x, n) wilson_ci(x, n), n_survived, n, SIMPLIFY = FALSE),
    ci_lower = sapply(wilson, `[[`, "lower"),
    ci_upper = sapply(wilson, `[[`, "upper")
  ) %>%
  select(-wilson, -n_survived)

cat("\nSurvival by size class:\n")
print(as.data.frame(survival_by_size %>%
                      mutate(across(where(is.numeric), ~round(., 3)))))

# ----------------------------------------
# 2.2 SPACE EFFECTS
# ----------------------------------------

cat("\nA.2 SPACE (REGIONAL) EFFECTS:\n")

survival_by_region <- surv_data %>%
  group_by(region) %>%
  summarise(
    n = n(),
    n_survived = sum(survived),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    n_studies = n_distinct(study),
    n_sites = n_distinct(location),
    .groups = "drop"
  ) %>%
  mutate(
    wilson = mapply(function(x, n) wilson_ci(x, n), n_survived, n, SIMPLIFY = FALSE),
    ci_lower = sapply(wilson, `[[`, "lower"),
    ci_upper = sapply(wilson, `[[`, "upper")
  ) %>%
  select(-wilson, -n_survived) %>%
  arrange(desc(survival))

cat("\nSurvival by region:\n")
print(as.data.frame(survival_by_region %>%
                      mutate(across(where(is.numeric), ~round(., 3)))))

# ----------------------------------------
# 2.3 TIME EFFECTS
# ----------------------------------------

cat("\nA.3 TIME (TEMPORAL) EFFECTS:\n")

survival_by_year <- surv_data %>%
  group_by(survey_yr) %>%
  summarise(
    n = n(),
    n_survived = sum(survived),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    .groups = "drop"
  ) %>%
  mutate(
    wilson = mapply(function(x, n) wilson_ci(x, n), n_survived, n, SIMPLIFY = FALSE),
    ci_lower = sapply(wilson, `[[`, "lower"),
    ci_upper = sapply(wilson, `[[`, "upper")
  ) %>%
  select(-wilson, -n_survived)

# Unadjusted temporal trend (may be confounded with study composition)
time_model <- glm(survived ~ survey_yr, data = surv_data, family = binomial)
time_trend <- coef(time_model)[2]
time_p <- summary(time_model)$coefficients[2, 4]

# Study-adjusted temporal trend (controls for which studies were active when)
# NOTE: This disentangles true temporal change from study composition effects
time_model_adj <- glm(survived ~ survey_yr + study, data = surv_data, family = binomial)
time_trend_adj <- coef(time_model_adj)["survey_yr"]
time_p_adj <- summary(time_model_adj)$coefficients["survey_yr", 4]

cat("\nTemporal trend analysis:\n")
cat(sprintf("  Unadjusted:     coef=%.4f, OR=%.3f, p=%.4f\n",
            time_trend,
            exp(time_trend),
            time_p))
cat(sprintf("  Study-adjusted: coef=%.4f, OR=%.3f, p=%.4f\n",
            time_trend_adj,
            exp(time_trend_adj),
            time_p_adj))
cat("  NOTE: If study-adjusted effect differs substantially, temporal trend\n")
cat("        is confounded with study composition changes over time.\n")

# Mixed model with random effect for study (if lme4 available)
if (has_lme4) {
  time_model_re <- tryCatch({
    lme4::glmer(survived ~ survey_yr + (1|study),
                data = surv_data, family = binomial)
  }, error = function(e) {
    cat(sprintf("  Mixed model failed: %s\n", e$message))
    NULL
  })
  if (!is.null(time_model_re)) {
    cat(sprintf("  Mixed model:    coef=%.4f, OR=%.3f\n",
                lme4::fixef(time_model_re)["survey_yr"],
                exp(lme4::fixef(time_model_re)["survey_yr"])))

    # Overdispersion check (fixed + random effect parameters)
    pearson_resid <- residuals(time_model_re, type = "pearson")
    n_par <- length(lme4::fixef(time_model_re)) + sum(sapply(lme4::VarCorr(time_model_re), function(x) prod(dim(x))))
    overdisp_ratio <- sum(pearson_resid^2) / (length(pearson_resid) - n_par)
    cat(sprintf("  Overdispersion ratio: %.3f %s\n", overdisp_ratio, if(overdisp_ratio > 1.5) "(WARNING: potential overdispersion)" else "(OK)"))
  }
}

# --- SAVE: Temporal trend GLMM results ---
# Collect all temporal trend coefficients into one data frame
temporal_coefs <- tibble(
  model = c("unadjusted_glm", "study_adjusted_glm"),
  log_odds_slope_per_year = c(time_trend, time_trend_adj),
  std_error = c(summary(time_model)$coefficients[2, 2],
                summary(time_model_adj)$coefficients["survey_yr", 2]),
  z_value = c(summary(time_model)$coefficients[2, 3],
              summary(time_model_adj)$coefficients["survey_yr", 3]),
  p_value = c(time_p, time_p_adj),
  odds_ratio_per_year = c(exp(time_trend), exp(time_trend_adj))
)
if (has_lme4 && exists("time_model_re") && !is.null(time_model_re)) {
  re_coef <- lme4::fixef(time_model_re)["survey_yr"]
  re_se <- sqrt(vcov(time_model_re)["survey_yr", "survey_yr"])
  re_z <- re_coef / re_se
  re_p <- 2 * pnorm(abs(re_z), lower.tail = FALSE)
  temporal_coefs <- bind_rows(temporal_coefs, tibble(
    model = "mixed_model_glmer",
    log_odds_slope_per_year = re_coef,
    std_error = re_se,
    z_value = re_z,
    p_value = re_p,
    odds_ratio_per_year = exp(re_coef)
  ))
}
write_csv(temporal_coefs, file.path(output_dir, "temporal_trend_coefficients.csv"))
cat("  Saved: temporal_trend_coefficients.csv\n")

# --- Collector for overdispersion checks ---
variance_overdisp_results <- tibble(
  model_name = character(),
  n_obs = integer(),
  n_params = integer(),
  dispersion_ratio = numeric(),
  overdispersed = logical()
)

# Capture temporal GLMM overdispersion if available
if (has_lme4 && exists("time_model_re") && !is.null(time_model_re)) {
  pearson_resid_tmp <- residuals(time_model_re, type = "pearson")
  n_par_tmp <- length(lme4::fixef(time_model_re)) + sum(sapply(lme4::VarCorr(time_model_re), function(x) prod(dim(x))))
  overdisp_tmp <- sum(pearson_resid_tmp^2) / (length(pearson_resid_tmp) - n_par_tmp)
  variance_overdisp_results <- bind_rows(variance_overdisp_results, tibble(
    model_name = "temporal_trend_glmm",
    n_obs = as.integer(length(pearson_resid_tmp)),
    n_params = as.integer(n_par_tmp),
    dispersion_ratio = overdisp_tmp,
    overdispersed = overdisp_tmp > 1.5
  ))
}

cat("\n")
if (time_p < 0.05) {
  if (time_trend > 0) {
    cat("✓ SIGNIFICANT IMPROVEMENT over time (unadjusted)\n")
  } else {
    cat("⚠ SIGNIFICANT DECLINE over time (unadjusted)\n")
  }
} else {
  cat("→ No significant temporal trend (unadjusted)\n")
}

# ----------------------------------------
# 2.4 SIZE × SPACE INTERACTION
# ----------------------------------------

cat("\nA.4 SIZE × SPACE INTERACTION:\n")

survival_size_space <- surv_data %>%
  group_by(size_class, region) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    .groups = "drop"
  ) %>%
  filter(n >= 10)  # Only cells with sufficient data

# Size x region interaction (accounting for study clustering)
interaction_model <- tryCatch({
  glmer(survived ~ size_class * region + (1|study),
        data = surv_data, family = binomial,
        control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 100000)))
}, error = function(e) {
  cat(sprintf("GLMM interaction model failed: %s. Falling back to GLM.\n", e$message))
  glm(survived ~ size_class * region, data = surv_data, family = binomial)
})

if (inherits(interaction_model, "glmerMod")) {
  cat("\nInteraction test (GLMM with study RE):\n")
  # Compare with main-effects-only model
  main_effects_model <- glmer(survived ~ size_class + region + (1|study),
                               data = surv_data, family = binomial,
                               control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 100000)))
  anova_result <- anova(main_effects_model, interaction_model)
  print(anova_result)

  # --- SAVE: Size x region interaction test ---
  interaction_test_df <- tibble(
    test_type = "GLMM_LRT",
    test_statistic = anova_result[["Chisq"]][2],
    df = anova_result[["Df"]][2],
    p_value = anova_result[["Pr(>Chisq)"]][2],
    aic_main_effects = anova_result[["AIC"]][1],
    aic_interaction = anova_result[["AIC"]][2],
    significant = anova_result[["Pr(>Chisq)"]][2] < 0.05
  )
  write_csv(interaction_test_df, file.path(output_dir, "size_region_interaction.csv"))
  cat("  Saved: size_region_interaction.csv\n")

  # Overdispersion check for interaction model (fixed + random effect parameters)
  pearson_resid <- residuals(interaction_model, type = "pearson")
  n_par <- length(fixef(interaction_model)) + sum(sapply(VarCorr(interaction_model), function(x) prod(dim(x))))
  overdisp_ratio <- sum(pearson_resid^2) / (length(pearson_resid) - n_par)
  cat(sprintf("  Overdispersion ratio: %.3f %s\n", overdisp_ratio, if(overdisp_ratio > 1.5) "(WARNING: potential overdispersion)" else "(OK)"))

  # Capture overdispersion for interaction model
  variance_overdisp_results <- bind_rows(variance_overdisp_results, tibble(
    model_name = "size_region_interaction_glmm",
    n_obs = as.integer(length(pearson_resid)),
    n_params = as.integer(n_par),
    dispersion_ratio = overdisp_ratio,
    overdispersed = overdisp_ratio > 1.5
  ))
} else {
  anova_result <- anova(interaction_model, test = "Chisq")
  cat("\nInteraction test (GLM fallback - no study RE):\n")
  print(anova_result)

  # --- SAVE: Size x region interaction test (GLM fallback) ---
  # Extract the interaction row (last row of anova table)
  anova_df <- as.data.frame(anova_result)
  interaction_row <- nrow(anova_df)
  interaction_test_df <- tibble(
    test_type = "GLM_deviance",
    test_statistic = anova_df[interaction_row, "Deviance"],
    df = anova_df[interaction_row, "Df"],
    p_value = anova_df[interaction_row, "Pr(>Chi)"],
    aic_main_effects = NA_real_,
    aic_interaction = NA_real_,
    significant = anova_df[interaction_row, "Pr(>Chi)"] < 0.05
  )
  write_csv(interaction_test_df, file.path(output_dir, "size_region_interaction.csv"))
  cat("  Saved: size_region_interaction.csv\n")
}

# Pivot for visualization
size_space_wide <- survival_size_space %>%
  select(size_class, region, survival) %>%
  pivot_wider(names_from = region, values_from = survival)

cat("\nSize × Region survival matrix:\n")
print(as.data.frame(size_space_wide %>%
                      mutate(across(where(is.numeric), ~round(., 2)))))

# ----------------------------------------
# 2.5 MIXED MODEL (if lme4 available)
# ----------------------------------------

if (has_lme4) {
  cat("\nA.5 MIXED EFFECTS MODEL:\n")

  # Fit GLMM with random effects for study
  surv_glmm <- tryCatch({
    glmer(survived ~ log_size + region + (1|study),
          data = surv_data, family = binomial,
          control = glmerControl(optimizer = "bobyqa"))
  }, error = function(e) {
    cat(sprintf("  GLMM failed: %s\n", e$message))
    return(NULL)
  })

  if (!is.null(surv_glmm)) {
    cat("\nFixed effects:\n")
    print(summary(surv_glmm)$coefficients)

    cat("\nRandom effects variance:\n")
    print(VarCorr(surv_glmm))

    # Check for overdispersion
    cat("\nOverdispersion check:\n")
    pearson_resid <- residuals(surv_glmm, type = "pearson")
    n_obs <- length(pearson_resid)
    n_par <- length(fixef(surv_glmm)) + sum(sapply(VarCorr(surv_glmm), function(x) prod(dim(x))))
    rdf <- n_obs - n_par
    overdisp_ratio <- sum(pearson_resid^2) / rdf
    overdisp_p <- pchisq(sum(pearson_resid^2), df = rdf, lower.tail = FALSE)
    cat(sprintf("  Overdispersion ratio: %.3f (p = %.4f)\n", overdisp_ratio, overdisp_p))
    if (overdisp_ratio > 1.5) {
      cat("  WARNING: Potential overdispersion detected. Consider observation-level random effect.\n")
    }

    # Capture overdispersion for main GLMM
    variance_overdisp_results <- bind_rows(variance_overdisp_results, tibble(
      model_name = "survival_glmm_size_region",
      n_obs = as.integer(n_obs),
      n_params = as.integer(n_par),
      dispersion_ratio = overdisp_ratio,
      overdispersed = overdisp_ratio > 1.5
    ))

    # Variance partitioning
    var_study <- as.numeric(VarCorr(surv_glmm)$study)
    var_total <- var_study + (pi^2/3)  # Residual variance for logistic
    icc_study <- var_study / var_total

    cat(sprintf("\nICC (study): %.3f (%.1f%% of variance)\n",
                icc_study, icc_study * 100))
  }
}

# =============================================================================
# 3. GROWTH: SIZE × SPACE × TIME
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  PART B: GROWTH ANALYSIS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# ----------------------------------------
# 3.1 SIZE EFFECTS
# ----------------------------------------

cat("B.1 SIZE EFFECTS:\n")

growth_by_size <- growth_data %>%
  group_by(size_class) %>%
  summarise(
    n = n(),
    mean_growth = mean(growth_cm2_yr, na.rm = TRUE),
    sd_growth = sd(growth_cm2_yr, na.rm = TRUE),
    se = sd_growth / sqrt(n),
    pct_positive = mean(growth_cm2_yr > 0) * 100,
    .groups = "drop"
  )

cat("\nGrowth by size class:\n")
print(as.data.frame(growth_by_size %>%
                      mutate(across(where(is.numeric), ~round(., 1)))))

# ----------------------------------------
# 3.2 SPACE EFFECTS
# ----------------------------------------

cat("\nB.2 SPACE (REGIONAL) EFFECTS:\n")

growth_by_region <- growth_data %>%
  group_by(region) %>%
  summarise(
    n = n(),
    mean_growth = mean(growth_cm2_yr, na.rm = TRUE),
    sd_growth = sd(growth_cm2_yr, na.rm = TRUE),
    pct_positive = mean(growth_cm2_yr > 0) * 100,
    .groups = "drop"
  ) %>%
  arrange(desc(mean_growth))

cat("\nGrowth by region:\n")
print(as.data.frame(growth_by_region %>%
                      mutate(across(where(is.numeric), ~round(., 1)))))

# ----------------------------------------
# 3.3 TIME EFFECTS
# ----------------------------------------

cat("\nB.3 TIME EFFECTS:\n")

growth_by_year <- growth_data %>%
  group_by(survey_yr) %>%
  summarise(
    n = n(),
    mean_growth = mean(growth_cm2_yr, na.rm = TRUE),
    .groups = "drop"
  )

# Temporal trend in growth (accounting for study clustering)
time_growth_model <- tryCatch({
  lmer(growth_cm2_yr ~ survey_yr + (1|study), data = growth_data)
}, error = function(e) {
  cat(sprintf("Mixed model failed, using OLS: %s\n", e$message))
  lm(growth_cm2_yr ~ survey_yr, data = growth_data)
})

if (inherits(time_growth_model, "lmerMod")) {
  time_growth_trend <- fixef(time_growth_model)["survey_yr"]
  # Use lmerTest for p-value if available
  if (requireNamespace("lmerTest", quietly = TRUE)) {
    time_growth_lt <- lmerTest::lmer(growth_cm2_yr ~ survey_yr + (1|study), data = growth_data)
    time_growth_p <- summary(time_growth_lt)$coefficients["survey_yr", "Pr(>|t|)"]
  } else {
    time_growth_p <- NA
  }
  cat(sprintf("\nTemporal trend (mixed model): %.2f cm²/yr per year (p=%.4f)\n",
              time_growth_trend, time_growth_p))
} else {
  time_growth_trend <- coef(time_growth_model)[2]
  time_growth_p <- summary(time_growth_model)$coefficients[2, 4]
  cat(sprintf("\nTemporal trend (OLS fallback): %.2f cm²/yr per year (p=%.4f)\n",
              time_growth_trend, time_growth_p))
}

# ----------------------------------------
# 3.4 SIZE × SPACE INTERACTION
# ----------------------------------------

cat("\nB.4 SIZE × SPACE INTERACTION:\n")

growth_size_space <- growth_data %>%
  group_by(size_class, region) %>%
  summarise(
    n = n(),
    mean_growth = mean(growth_cm2_yr, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(n >= 10)

# Pivot
growth_space_wide <- growth_size_space %>%
  select(size_class, region, mean_growth) %>%
  pivot_wider(names_from = region, values_from = mean_growth)

cat("\nSize × Region mean growth matrix:\n")
print(as.data.frame(growth_space_wide %>%
                      mutate(across(where(is.numeric), ~round(., 0)))))

# =============================================================================
# 4. DATA TYPE EFFECTS (FIELD VS NURSERY)
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  PART C: DATA TYPE COMPARISON (FIELD vs NURSERY)\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Survival by data type
survival_by_dtype <- surv_data %>%
  group_by(data_type) %>%
  summarise(
    n = n(),
    n_survived = sum(survived),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    .groups = "drop"
  ) %>%
  mutate(
    wilson = mapply(function(x, n) wilson_ci(x, n), n_survived, n, SIMPLIFY = FALSE),
    ci_lower = sapply(wilson, `[[`, "lower"),
    ci_upper = sapply(wilson, `[[`, "upper")
  ) %>%
  select(-wilson, -n_survived)

cat("Survival by data type:\n")
print(as.data.frame(survival_by_dtype %>%
                      mutate(across(where(is.numeric), ~round(., 3)))))

# Size × Data Type interaction
survival_size_dtype <- surv_data %>%
  group_by(size_class, data_type) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    .groups = "drop"
  ) %>%
  filter(n >= 10)

cat("\nSize × Data Type survival:\n")
print(as.data.frame(survival_size_dtype %>%
                      pivot_wider(names_from = data_type, values_from = survival) %>%
                      mutate(across(where(is.numeric), ~round(., 3)))))

# =============================================================================
# 5. INDIVIDUAL PREDICTOR IMPORTANCE (McFadden pseudo-R²)
# =============================================================================

# METHODOLOGICAL NOTE: These are INDIVIDUAL predictor McFadden pseudo-R² values
# from separate single-predictor models. They measure each predictor's marginal
# importance but are NOT additive — values do not sum to a meaningful total.
# Correlated predictors (e.g., region and study) may show overlapping explanatory
# power. This is NOT a formal variance decomposition.

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  INDIVIDUAL PREDICTOR IMPORTANCE (McFadden pseudo-R²)\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

cat("NOTE: These are marginal pseudo-R² values from separate single-predictor\n")
cat("models. They are NOT additive and do NOT represent a formal variance\n")
cat("decomposition. Correlated predictors may show overlapping explanatory power.\n\n")

# Calculate R² for different models
# Size only
m_size <- glm(survived ~ log_size, data = surv_data, family = binomial)
# Region only
m_region <- glm(survived ~ region, data = surv_data, family = binomial)
# Year only
m_year <- glm(survived ~ survey_yr, data = surv_data, family = binomial)
# Size + Region
m_size_region <- glm(survived ~ log_size + region, data = surv_data, family = binomial)
# Full model
m_full <- glm(survived ~ log_size + region + survey_yr, data = surv_data, family = binomial)

# Multicollinearity assessment
if (requireNamespace("car", quietly = TRUE)) {
  cat("\n--- MULTICOLLINEARITY CHECK (VIF) ---\n")
  vif_values <- car::vif(m_full)
  # car::vif returns a matrix for models with factor predictors (GVIF, Df, GVIF^(1/(2*Df)))
  # Extract the comparable column for threshold checking
  if (is.matrix(vif_values)) {
    cat("  (Generalized VIF for factor predictors)\n")
    print(vif_values)
    vif_check <- vif_values[, "GVIF^(1/(2*Df))"]
  } else {
    print(vif_values)
    vif_check <- vif_values
  }
  if (any(vif_check > 5)) {
    cat("WARNING: VIF > 5 detected. Predictor estimates may be unstable.\n")
  } else {
    cat("All VIF values < 5. No multicollinearity concerns.\n")
  }
}

# Calculate pseudo-R² (McFadden)
null_ll <- logLik(glm(survived ~ 1, data = surv_data, family = binomial))

calc_pseudo_r2 <- function(model) {
  1 - (logLik(model) / null_ll)
}

variance_partition <- tibble(
  model = c("Size only", "Region only", "Year only",
            "Size + Region", "Full (Size + Region + Year)"),
  marginal_pseudo_r2 = c(calc_pseudo_r2(m_size), calc_pseudo_r2(m_region),
                calc_pseudo_r2(m_year), calc_pseudo_r2(m_size_region),
                calc_pseudo_r2(m_full)),
  aic = c(AIC(m_size), AIC(m_region), AIC(m_year),
          AIC(m_size_region), AIC(m_full))
)

cat("Predictor importance (McFadden pseudo-R²) — NOT additive:\n")
print(as.data.frame(variance_partition %>%
                      mutate(across(where(is.numeric), ~round(., 4)))))

# --- McFADDEN PSEUDO-R² INTERPRETATION ---
cat("\n--- INTERPRETATION CONTEXT ---\n")
cat("  McFadden (1979) pseudo-R² values of 0.2-0.4 represent 'excellent fit'.\n")
cat("  Unlike OLS R², McFadden values are systematically lower because binary\n")
cat("  outcomes have inherent irreducible variance (Bernoulli noise).\n")
cat("  McFadden R² is NOT directly comparable to:\n")
cat("    - OLS R² (continuous outcomes, different scale)\n")
cat("    - GAM deviance explained (different computation)\n")
cat("    - Nakagawa-Schielzeth R² (variance-based, includes random effects)\n\n")
cat("  PRIMARY RECOMMENDATION: Use Nakagawa-Schielzeth marginal/conditional R²\n")
cat("  (Section below) for cross-model comparisons.\n")

# =============================================================================
# 5B. GLMM-BASED R² (Nakagawa & Schielzeth 2013)
# =============================================================================

# METHODOLOGICAL NOTE: These R² values properly account for the hierarchical
# data structure (colonies nested within studies) using random-effects GLMMs.
# Marginal R² = variance explained by fixed effects only.
# Conditional R² = variance explained by fixed + random effects.
# ICC = proportion of variance attributable to study-level clustering.

cat("\n")
cat("===================================================================\n")
cat("  PRIMARY METRIC: NAKAGAWA-SCHIELZETH R² (GLMM-based)\n")
cat("===================================================================\n")
cat("  These R² values properly account for random effects and are the\n")
cat("  recommended metrics for comparing variance explained across models.\n\n")

if (has_lme4 && requireNamespace("MuMIn", quietly = TRUE)) {

  # Intercept-only GLMM to compute ICC
  m0_glmm <- glmer(survived ~ 1 + (1|study), data = surv_data, family = binomial)
  icc_var <- as.data.frame(VarCorr(m0_glmm))
  icc_study <- icc_var$vcov[1] / (icc_var$vcov[1] + pi^2/3)
  cat(sprintf("ICC (study): %.4f (%.1f%% of variance is between-study)\n\n", icc_study, icc_study * 100))

  # Fit 4 predictor GLMMs with (1|study) random effects
  m_size_glmm <- glmer(survived ~ log_size + (1|study), data = surv_data, family = binomial)
  m_region_glmm <- glmer(survived ~ region + (1|study), data = surv_data, family = binomial)
  m_year_glmm <- glmer(survived ~ survey_yr + (1|study), data = surv_data, family = binomial)
  m_full_glmm <- glmer(survived ~ log_size + region + survey_yr + (1|study),
                         data = surv_data, family = binomial)

  # Compute R² (marginal and conditional) using MuMIn
  glmm_models <- list(
    "Intercept only" = m0_glmm,
    "Size only" = m_size_glmm,
    "Region only" = m_region_glmm,
    "Year only" = m_year_glmm,
    "Full (Size + Region + Year)" = m_full_glmm
  )

  glmm_r2_list <- lapply(names(glmm_models), function(nm) {
    r2 <- MuMIn::r.squaredGLMM(glmm_models[[nm]])
    data.frame(
      model = nm,
      R2_marginal = r2[1, "R2m"],
      R2_conditional = r2[1, "R2c"],
      stringsAsFactors = FALSE
    )
  })
  glmm_r2 <- do.call(rbind, glmm_r2_list)
  glmm_r2$ICC_study <- icc_study

  cat("GLMM R² (Nakagawa & Schielzeth):\n")
  print(as.data.frame(glmm_r2 %>% mutate(across(where(is.numeric), ~round(., 4)))))

  # Overdispersion checks for each GLMM
  cat("\n--- OVERDISPERSION CHECKS (GLMM) ---\n")
  glmm_overdisp <- lapply(names(glmm_models)[-1], function(nm) {  # skip intercept-only
    mod <- glmm_models[[nm]]
    pearson_resid <- residuals(mod, type = "pearson")
    n_obs <- length(pearson_resid)
    n_params <- length(fixef(mod)) + sum(sapply(VarCorr(mod), function(x) prod(dim(x))))
    ratio <- sum(pearson_resid^2) / (n_obs - n_params)
    flag <- ifelse(ratio > 1.5, "WARNING: potential overdispersion", "OK")
    cat(sprintf("  %s: dispersion ratio = %.3f [%s]\n", nm, ratio, flag))
    data.frame(model = nm, dispersion_ratio = ratio, flag = flag, stringsAsFactors = FALSE)
  })
  glmm_overdisp_df <- do.call(rbind, glmm_overdisp)

  # Save GLMM R² results
  write_csv(glmm_r2, file.path(output_dir, "variance_partitioning_glmm_r2.csv"))
  cat("\n✓ Saved: variance_partitioning_glmm_r2.csv\n")

} else {
  cat("SKIPPED: lme4 or MuMIn not available. Install with install.packages(c('lme4', 'MuMIn'))\n")
}

# =============================================================================
# 5C. CORAL_ID PSEUDOREPLICATION CHECK
# =============================================================================

cat("\n")
cat("===================================================================\n")
cat("  PSEUDOREPLICATION CHECK: coral_id random effect\n")
cat("===================================================================\n\n")

has_coral_id_surv <- "coral_id" %in% names(surv_data) &&
                     sum(!is.na(surv_data$coral_id)) > 0.5 * nrow(surv_data)

if (has_coral_id_surv && has_lme4) {
  n_unique_corals <- n_distinct(surv_data$coral_id, na.rm = TRUE)
  n_records_total <- nrow(surv_data)
  cat(sprintf("  Unique corals: %d, Total records: %d (%.1fx replication)\n",
              n_unique_corals, n_records_total, n_records_total / n_unique_corals))

  # Fit model with coral_id RE for comparison
  m_coral_re <- tryCatch({
    glmer(survived ~ log_size + (1|study) + (1|coral_id),
          data = surv_data, family = binomial,
          control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5)))
  }, error = function(e) {
    cat(sprintf("  coral_id RE model failed: %s\n", e$message))
    NULL
  })

  if (!is.null(m_coral_re) && exists("m_size_glmm")) {
    cat("  Comparing models with and without coral_id RE:\n")
    cat(sprintf("    Without coral_id: log_size coef = %.4f (SE: %.4f)\n",
                fixef(m_size_glmm)[2],
                summary(m_size_glmm)$coefficients[2, 2]))
    cat(sprintf("    With coral_id:    log_size coef = %.4f (SE: %.4f)\n",
                fixef(m_coral_re)[2],
                summary(m_coral_re)$coefficients[2, 2]))
    se_ratio <- summary(m_coral_re)$coefficients[2, 2] /
                summary(m_size_glmm)$coefficients[2, 2]
    cat(sprintf("    SE inflation factor: %.2fx\n", se_ratio))

    # Variance decomposition with coral_id
    vc_coral <- as.data.frame(VarCorr(m_coral_re))
    cat("\n  Variance components with coral_id:\n")
    for (i in seq_len(nrow(vc_coral))) {
      cat(sprintf("    %s: %.4f (SD: %.4f)\n",
                  vc_coral$grp[i], vc_coral$vcov[i], vc_coral$sdcor[i]))
    }
  }
} else {
  cat("  coral_id not available or insufficient coverage — pseudoreplication check skipped\n")
  if (has_lme4 && exists("m_size_glmm")) {
    vc_tmp <- as.data.frame(VarCorr(m_size_glmm))
    icc_tmp <- vc_tmp$vcov[1] / (vc_tmp$vcov[1] + pi^2/3)
    avg_cluster_tmp <- nrow(surv_data) / n_distinct(surv_data$study)
    deff_tmp <- 1 + (avg_cluster_tmp - 1) * icc_tmp
    cat(sprintf("  Estimated design effect: %.1f (effective n ~ %d)\n",
                deff_tmp, round(nrow(surv_data) / deff_tmp)))
  }
}

# =============================================================================
# 6. SAVE RESULTS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SAVING RESULTS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

write_csv(survival_by_size, file.path(output_dir, "survival_by_size.csv"))
write_csv(survival_by_region, file.path(output_dir, "survival_by_region.csv"))
write_csv(survival_by_year, file.path(output_dir, "survival_by_year.csv"))
write_csv(survival_size_space, file.path(output_dir, "survival_size_space.csv"))

write_csv(growth_by_size, file.path(output_dir, "growth_by_size.csv"))
write_csv(growth_by_region, file.path(output_dir, "growth_by_region.csv"))
write_csv(growth_by_year, file.path(output_dir, "growth_by_year.csv"))

write_csv(variance_partition, file.path(output_dir, "variance_partitioning.csv"))

# --- SAVE: Overdispersion check results ---
if (nrow(variance_overdisp_results) > 0) {
  write_csv(variance_overdisp_results, file.path(output_dir, "variance_overdispersion_checks.csv"))
  cat("✓ Saved: variance_overdispersion_checks.csv\n")
}

cat("✓ Saved all summary tables\n")

# =============================================================================
# 7. VISUALIZATION
# =============================================================================

cat("\nGenerating visualizations...\n")

# Panel A: Survival by size class
p1 <- ggplot(survival_by_size, aes(x = size_class, y = survival)) +
  geom_col(fill = "#2a9d8f", alpha = 0.8) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2) +
  geom_text(aes(label = sprintf("n=%d", n)), vjust = -0.5, size = 3) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(title = "A. Survival by Size Class",
       x = "Size Class", y = "Survival Rate") +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Panel B: Survival by region
p2 <- ggplot(survival_by_region, aes(x = reorder(region, -survival), y = survival)) +
  geom_col(fill = "#264653", alpha = 0.8) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(title = "B. Survival by Region",
       x = "Region", y = "Survival Rate") +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Panel C: Growth by size class
p3 <- ggplot(growth_by_size, aes(x = size_class, y = mean_growth)) +
  geom_col(fill = "#e07a5f", alpha = 0.8) +
  geom_errorbar(aes(ymin = mean_growth - se, ymax = mean_growth + se), width = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  labs(title = "C. Growth by Size Class",
       x = "Size Class", y = expression(paste("Mean Growth (cm"^2, "/yr)"))) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Panel D: Temporal trend
p4 <- ggplot(survival_by_year, aes(x = survey_yr, y = survival)) +
  geom_point(aes(size = n), alpha = 0.6) +
  geom_smooth(method = "lm", se = TRUE, color = "#2a9d8f") +
  scale_size_continuous(name = "n", range = c(2, 8)) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(title = "D. Temporal Trend in Survival",
       x = "Year", y = "Survival Rate") +
  theme_minimal(base_size = 11)

# Combine panels
library(patchwork)
combined <- (p1 | p2) / (p3 | p4) +
  plot_annotation(
    title = "A. palmata Demographics: Size × Space × Time",
    theme = theme(plot.title = element_text(size = 14, face = "bold"))
  )

ggsave(file.path(fig_dir_supp_exploratory, "size_space_time_panels.png"),
       combined, width = 14, height = 10, dpi = 300)
cat("✓ Saved: supplementary/exploratory/size_space_time_panels.png\n")

# Heatmap: Size × Region survival
p_heat <- ggplot(survival_size_space, aes(x = region, y = size_class, fill = survival)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.0f%%", survival * 100)), size = 3) +
  scale_fill_gradient2(
    low = "#e07a5f", mid = "#f4a261", high = "#2a9d8f",
    midpoint = 0.7, limits = c(0, 1),
    labels = scales::percent, name = "Survival"
  ) +
  labs(title = "Size × Region Survival Matrix",
       x = "Region", y = "Size Class") +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid = element_blank())

ggsave(file.path(fig_dir_supp_exploratory, "size_region_heatmap.png"),
       p_heat, width = 10, height = 6, dpi = 300)
cat("✓ Saved: supplementary/exploratory/size_region_heatmap.png\n")

# =============================================================================
# 8. SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  ANALYSIS COMPLETE                                           ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("KEY FINDINGS:\n\n")

cat("SIZE EFFECTS:\n")
min_surv <- survival_by_size$size_class[which.min(survival_by_size$survival)]
max_surv <- survival_by_size$size_class[which.max(survival_by_size$survival)]
cat(sprintf("  Lowest survival: %s (%.0f%%)\n", min_surv,
            min(survival_by_size$survival) * 100))
cat(sprintf("  Highest survival: %s (%.0f%%)\n", max_surv,
            max(survival_by_size$survival) * 100))

cat("\nSPATIAL VARIATION:\n")
cat(sprintf("  Best region: %s (%.0f%% survival)\n",
            survival_by_region$region[1],
            survival_by_region$survival[1] * 100))
cat(sprintf("  Regional range: %.0f%% to %.0f%%\n",
            min(survival_by_region$survival) * 100,
            max(survival_by_region$survival) * 100))

cat("\nTEMPORAL PATTERN:\n")
if (time_p < 0.05) {
  or <- exp(time_trend)  # Odds ratio per year
  cat(sprintf("  Significant trend: %s (OR = %.3f per year, p = %.4f)\n",
              ifelse(time_trend > 0, "improving", "declining"),
              or, time_p))
} else {
  cat("  No significant temporal trend detected\n")
}

cat("\nPREDICTOR IMPORTANCE (marginal pseudo-R², NOT additive):\n")
cat(sprintf("  Size: %.1f%%\n", variance_partition$marginal_pseudo_r2[1] * 100))
cat(sprintf("  Region: %.1f%%\n", variance_partition$marginal_pseudo_r2[2] * 100))
cat(sprintf("  Time: %.1f%%\n", variance_partition$marginal_pseudo_r2[3] * 100))

cat("\nNext step: Run 06_data_gap_analysis.R\n\n")
