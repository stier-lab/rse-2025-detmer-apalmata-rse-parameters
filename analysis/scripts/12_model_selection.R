################################################################################
# 12_model_selection.R - Complete Model Selection and Comparison
################################################################################
#
# PURPOSE:
#   Generate comprehensive model selection tables comparing all candidate
#   models for survival and growth analyses, following best practices for
#   meta-analysis and GLMM reporting.
#
# METHODS:
#   1. Fit multiple model specifications (null, linear, threshold, categorical)
#   2. Calculate AIC, BIC, log-likelihood, deviance
#   3. Compute R² (marginal and conditional for mixed models)
#   4. Generate coefficient tables with confidence intervals
#   5. Create publication-ready summary tables
#
# OUTPUTS:
#   - model_selection_survival.csv: AIC/BIC comparison for survival models
#   - model_selection_growth.csv: AIC/BIC comparison for growth models
#   - model_coefficients.csv: Full coefficient table
#   - model_summary_table.csv: Publication-ready summary
#
# Author: Detmer & Stier Lab
# Date: 2025-12-25
################################################################################

library(dplyr)
library(tidyr)
library(ggplot2)
library(lme4)

# Source shared utilities for constants and helper functions
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("analysis/scripts/utils/shared_utilities.R")) {
  source("analysis/scripts/utils/shared_utilities.R")
}

dirs <- setup_output_dirs()
output_dir <- dirs$output
fig_supp_dir <- dirs$figures_supp

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  16: MODEL SELECTION TABLE                                   ║\n")
cat("║  Comprehensive Model Comparison for Publication              ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# =============================================================================
# SETUP
# =============================================================================

# Load prepared data
cat("Loading prepared data...\n")
survival_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

# Add variables needed for models
survival_data <- survival_data %>%
  mutate(
    log_size = log(size_cm2),
    log_size_sq = log_size^2,
    size_class = case_when(
      size_cm2 <= 25 ~ "SC1",
      size_cm2 <= 100 ~ "SC2",
      size_cm2 <= 500 ~ "SC3",
      size_cm2 <= 2000 ~ "SC4",
      TRUE ~ "SC5"
    ),
    size_class = factor(size_class, levels = c("SC1", "SC2",
                                                "SC3", "SC4",
                                                "SC5")),
    # Threshold variable (data-driven from survival threshold detection)
    above_threshold = {
      thresh_file <- file.path(output_dir, "survival_thresholds.csv")
      thresh_log <- log(100)  # default fallback
      if (file.exists(thresh_file)) {
        surv_thresh <- read_csv(thresh_file, show_col_types = FALSE)
        if ("recommended_threshold_log" %in% names(surv_thresh) && !is.na(surv_thresh$recommended_threshold_log[1])) {
          thresh_log <- surv_thresh$recommended_threshold_log[1]
          cat(sprintf("  Using data-driven survival threshold: %.0f cm2 (log=%.2f)\n", exp(thresh_log), thresh_log))
        } else if ("threshold_log" %in% names(surv_thresh) && !is.na(surv_thresh$threshold_log[1])) {
          thresh_log <- surv_thresh$threshold_log[1]
          cat(sprintf("  Using backward-compat survival threshold: %.0f cm2\n", exp(thresh_log)))
        } else {
          warning("survival_thresholds.csv exists but no valid threshold found; using default 100 cm2")
        }
      } else {
        warning("survival_thresholds.csv not found; using default 100 cm2 threshold")
      }
      pmax(0, log_size - thresh_log)
    }
  )

growth_data <- growth_data %>%
  mutate(
    log_size = log(size_cm2),
    log_size_sq = log_size^2,
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

cat(sprintf("  Survival data: %d observations\n", nrow(survival_data)))
cat(sprintf("  Growth data: %d observations\n", nrow(growth_data)))

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

#' Extract model statistics
get_model_stats <- function(model, model_name, model_type = "glm") {
  tryCatch({
    summ <- summary(model)

    # Basic statistics - use model.frame for n
    n <- nrow(model.frame(model))
    ll <- logLik(model)[1]
    aic <- AIC(model)
    bic <- BIC(model)

    # Handle mixed-effects models (lme4)
    if (inherits(model, "merMod")) {
      k <- length(fixef(model)) + length(getME(model, "theta"))  # fixed + RE params
      deviance_val <- deviance(model)
      # Marginal R² (fixed effects only) for GLMMs
      pseudo_r2 <- tryCatch({
        var_f <- var(predict(model, re.form = NA))  # fixed effects variance
        if (inherits(model, "glmerMod")) {
          # For binomial GLMM, use latent scale (pi²/3 for logistic)
          var_f / (var_f + sum(as.data.frame(VarCorr(model))$vcov) + pi^2/3)
        } else {
          # For LMM
          var_f / (var_f + sum(as.data.frame(VarCorr(model))$vcov) + sigma(model)^2)
        }
      }, error = function(e) NA)
    } else {
      k <- length(coef(model))  # Number of parameters
      deviance_val <- if (model_type == "lm") sum(residuals(model)^2) else deviance(model)

      # Calculate pseudo R² for GLM
      if (model_type == "glm" && family(model)$family == "binomial") {
        null_dev <- model$null.deviance
        resid_dev <- model$deviance
        pseudo_r2 <- 1 - (resid_dev / null_dev)
      } else if (model_type == "lm") {
        pseudo_r2 <- summary(model)$r.squared
      } else {
        pseudo_r2 <- NA
      }
    }

    data.frame(
      model = model_name,
      n_obs = n,
      n_params = k,
      log_lik = ll,
      deviance = deviance_val,
      aic = aic,
      bic = bic,
      pseudo_r2 = pseudo_r2
    )
  }, error = function(e) {
    data.frame(
      model = model_name,
      n_obs = NA, n_params = NA, log_lik = NA,
      deviance = NA, aic = NA, bic = NA, pseudo_r2 = NA
    )
  })
}

#' Extract coefficients with confidence intervals
get_model_coefs <- function(model, model_name) {
  tryCatch({
    if (inherits(model, "merMod")) {
      coefs <- summary(model)$coefficients
      ci <- tryCatch(confint(model, parm = "beta_", level = 0.95, method = "Wald"),
                     error = function(e) {
                       # Fallback: compute Wald CIs manually
                       est <- coefs[, 1]
                       se <- coefs[, 2]
                       cbind("2.5 %" = est - 1.96 * se, "97.5 %" = est + 1.96 * se)
                     })
      # Column layout differs between glmerMod and lmerMod (with/without lmerTest):
      #   glmerMod:                Estimate, Std. Error, z value,           Pr(>|z|)
      #   lmerMod (no lmerTest):   Estimate, Std. Error, t value            (no p-value)
      #   lmerMod (with lmerTest): Estimate, Std. Error, df, t value,       Pr(>|t|)
      # Use column names to extract the right values.
      col_names <- colnames(coefs)
      stat_col <- grep("^(t value|z value)$", col_names)
      p_col <- grep("^Pr\\(", col_names)
      data.frame(
        model = model_name,
        term = rownames(coefs),
        estimate = coefs[, "Estimate"],
        std_error = coefs[, "Std. Error"],
        statistic = if (length(stat_col) == 1) coefs[, stat_col] else NA_real_,
        p_value = if (length(p_col) == 1) coefs[, p_col] else NA_real_,
        ci_lower = ci[, 1],
        ci_upper = ci[, 2],
        row.names = NULL
      )
    } else {
      coefs <- summary(model)$coefficients
      ci <- tryCatch(
        confint(model, level = 0.95),
        error = function(e) {
          # Fallback to Wald CIs (estimate +/- 1.96*SE) if confint fails
          est <- coefs[, 1]
          se <- coefs[, 2]
          cbind("2.5 %" = est - 1.96 * se, "97.5 %" = est + 1.96 * se)
        }
      )

      data.frame(
        model = model_name,
        term = rownames(coefs),
        estimate = coefs[, 1],
        std_error = coefs[, 2],
        statistic = coefs[, 3],
        p_value = coefs[, 4],
        ci_lower = ci[, 1],
        ci_upper = ci[, 2],
        row.names = NULL
      )
    }
  }, error = function(e) {
    data.frame(
      model = model_name,
      term = NA, estimate = NA, std_error = NA,
      statistic = NA, p_value = NA, ci_lower = NA, ci_upper = NA
    )
  })
}

# =============================================================================
# SURVIVAL MODELS
# =============================================================================

cat("\n1. Fitting Survival Models...\n")

survival_models <- list()

# Model S1: Null (intercept only)
cat("  Fitting M1: Null model\n")
survival_models$S1_null <- glm(survived ~ 1,
                                data = survival_data, family = binomial)

# Model S2: Linear log-size
cat("  Fitting M2: Linear log-size\n")
survival_models$S2_linear <- glm(survived ~ log_size,
                                  data = survival_data, family = binomial)

# Model S3: Quadratic log-size
cat("  Fitting M3: Quadratic log-size\n")
survival_models$S3_quadratic <- glm(survived ~ log_size + log_size_sq,
                                     data = survival_data, family = binomial)

# Model S4: Threshold (data-driven from script 02)
cat("  Fitting M4: Threshold (data-driven)\n")
survival_models$S4_threshold <- glm(survived ~ log_size + above_threshold,
                                     data = survival_data, family = binomial)

# Model S5: Categorical size classes
cat("  Fitting M5: Categorical size classes\n")
survival_models$S5_categorical <- glm(survived ~ size_class,
                                       data = survival_data, family = binomial)

# Model S6: Size + Region
cat("  Fitting M6: Size + Region\n")
survival_models$S6_size_region <- glm(survived ~ log_size + region,
                                       data = survival_data, family = binomial)

# Model S7: Size × Region interaction
cat("  Fitting M7: Size × Region interaction\n")
survival_models$S7_interaction <- tryCatch({
  glm(survived ~ log_size * region, data = survival_data, family = binomial)
}, error = function(e) NULL)

# Mixed-effects models accounting for study-level clustering
# These are the methodologically appropriate models given I² = 97.8%
cat("\n--- MIXED-EFFECTS SURVIVAL MODELS ---\n")
tryCatch({
  cat("  Fitting S_ME1: Mixed null model\n")
  survival_models$S_ME1_null <- glmer(survived ~ 1 + (1|study),
                                       data = survival_data, family = binomial)
  cat("  Fitting S_ME2: Mixed linear log-size\n")
  survival_models$S_ME2_linear <- glmer(survived ~ log_size + (1|study),
                                         data = survival_data, family = binomial)
  cat("  Fitting S_ME3: Mixed categorical size class\n")
  survival_models$S_ME3_categorical <- glmer(survived ~ size_class + (1|study),
                                              data = survival_data, family = binomial)
  # Attempt random slope model
  cat("  Fitting S_ME4: Mixed random slope\n")
  survival_models$S_ME4_random_slope <- tryCatch(
    glmer(survived ~ log_size + (log_size|study),
          data = survival_data, family = binomial),
    error = function(e) {
      cat("  Random slope model failed to converge, trying uncorrelated RE:\n")
      glmer(survived ~ log_size + (1|study) + (0 + log_size|study),
            data = survival_data, family = binomial)
    }
  )
}, error = function(e) {
  cat(sprintf("  Mixed model fitting error: %s\n", e$message))
})

# Overdispersion checks for mixed-effects survival models
cat("\n--- OVERDISPERSION CHECKS (Mixed-effects survival models) ---\n")
overdispersion_results <- list()
for (me_name in c("S_ME1_null", "S_ME2_linear", "S_ME3_categorical", "S_ME4_random_slope")) {
  if (!is.null(survival_models[[me_name]])) {
    pearson_resid <- residuals(survival_models[[me_name]], type = "pearson")
    n_par <- length(fixef(survival_models[[me_name]])) + sum(sapply(VarCorr(survival_models[[me_name]]), function(x) prod(dim(x))))
    overdisp_ratio <- sum(pearson_resid^2) / (length(pearson_resid) - n_par)
    cat(sprintf("  %s overdispersion ratio: %.3f %s\n", me_name, overdisp_ratio, if(overdisp_ratio > 1.5) "(WARNING: potential overdispersion)" else "(OK)"))
    overdispersion_results[[length(overdispersion_results) + 1]] <- data.frame(
      model = me_name,
      dispersion_ratio = overdisp_ratio,
      n_obs = length(pearson_resid),
      n_params = n_par,
      overdispersed = overdisp_ratio > 1.5
    )
  }
}
if (length(overdispersion_results) > 0) {
  overdispersion_df <- bind_rows(overdispersion_results)
  write.csv(overdispersion_df, file.path(output_dir, "model_selection_overdispersion.csv"), row.names = FALSE)
  cat("  Saved: model_selection_overdispersion.csv\n")
}

# Extract random effects variance components for all mixed-effects models
random_effects_list <- list()
for (me_name in names(survival_models)) {
  if (!is.null(survival_models[[me_name]]) && inherits(survival_models[[me_name]], "merMod")) {
    vc <- as.data.frame(VarCorr(survival_models[[me_name]]))
    random_effects_list[[length(random_effects_list) + 1]] <- data.frame(
      model = me_name,
      group = vc$grp,
      variance = vc$vcov,
      std_dev = vc$sdcor
    )
  }
}

# Compile survival model statistics
survival_stats <- bind_rows(lapply(names(survival_models), function(name) {
  if (!is.null(survival_models[[name]])) {
    model_type <- if (inherits(survival_models[[name]], "merMod")) "glmm" else "glm"
    get_model_stats(survival_models[[name]], name, model_type)
  }
}))

# Separate GLM and GLMM for AIC comparison (AIC not comparable across classes)
survival_stats <- survival_stats %>%
  mutate(
    model_class = ifelse(grepl("^S_ME", model), "GLMM", "GLM")
  ) %>%
  group_by(model_class) %>%
  mutate(
    delta_aic = aic - min(aic, na.rm = TRUE),
    aic_weight = exp(-0.5 * delta_aic) / sum(exp(-0.5 * delta_aic), na.rm = TRUE),
    delta_bic = bic - min(bic, na.rm = TRUE),
    evidence_ratio = exp(-0.5 * delta_aic) / max(exp(-0.5 * delta_aic))
  ) %>%
  ungroup() %>%
  arrange(model_class, delta_aic)

cat("\n  NOTE: AIC compared within model class (GLM vs GLMM separately)\n")
cat("\n  Survival model comparison:\n")
print(survival_stats %>% select(model, n_params, aic, delta_aic, aic_weight, pseudo_r2))

# Extract coefficients for all models (fixed-effects and mixed-effects)
survival_coefs <- bind_rows(lapply(names(survival_models), function(name) {
  if (!is.null(survival_models[[name]])) {
    get_model_coefs(survival_models[[name]], name)
  }
}))

# =============================================================================
# GROWTH MODELS
# =============================================================================

cat("\n2. Fitting Growth Models...\n")

growth_models <- list()

# Model G1: Null
cat("  Fitting G1: Null model\n")
growth_models$G1_null <- lm(growth_cm2_yr ~ 1, data = growth_data)

# Model G2: Linear log-size
cat("  Fitting G2: Linear log-size\n")
growth_models$G2_linear <- lm(growth_cm2_yr ~ log_size, data = growth_data)

# Model G3: Quadratic
cat("  Fitting G3: Quadratic log-size\n")
growth_models$G3_quadratic <- lm(growth_cm2_yr ~ log_size + log_size_sq,
                                  data = growth_data)

# Model G4: Categorical
cat("  Fitting G4: Categorical size classes\n")
growth_models$G4_categorical <- lm(growth_cm2_yr ~ size_class, data = growth_data)

# Model G5: Size + Region
cat("  Fitting G5: Size + Region\n")
growth_models$G5_size_region <- lm(growth_cm2_yr ~ log_size + region,
                                    data = growth_data)

# Mixed-effects growth models accounting for study-level clustering
cat("\n--- MIXED-EFFECTS GROWTH MODELS ---\n")
tryCatch({
  cat("  Fitting G_ME1: Mixed null model\n")
  growth_models$G_ME1_null <- lmer(growth_cm2_yr ~ 1 + (1|study),
                                    data = growth_data)
  cat("  Fitting G_ME2: Mixed linear log-size\n")
  growth_models$G_ME2_linear <- lmer(growth_cm2_yr ~ log_size + (1|study),
                                      data = growth_data)
  cat("  Fitting G_ME3: Mixed categorical size class\n")
  growth_models$G_ME3_categorical <- lmer(growth_cm2_yr ~ size_class + (1|study),
                                           data = growth_data)
  # Attempt random slope model
  cat("  Fitting G_ME4: Mixed random slope\n")
  growth_models$G_ME4_random_slope <- tryCatch(
    lmer(growth_cm2_yr ~ log_size + (log_size|study),
         data = growth_data),
    error = function(e) {
      cat("  Random slope model failed to converge, trying uncorrelated RE:\n")
      lmer(growth_cm2_yr ~ log_size + (1|study) + (0 + log_size|study),
           data = growth_data)
    }
  )
}, error = function(e) {
  cat(sprintf("  Mixed model fitting error: %s\n", e$message))
})

# Compile growth model statistics
growth_stats <- bind_rows(lapply(names(growth_models), function(name) {
  if (!is.null(growth_models[[name]])) {
    model_type <- if (inherits(growth_models[[name]], "merMod")) "lmm" else "lm"
    get_model_stats(growth_models[[name]], name, model_type)
  }
}))

# Separate LM and LMM for AIC comparison (AIC not comparable across classes)
growth_stats <- growth_stats %>%
  mutate(
    model_class = ifelse(grepl("^G_ME", model), "LMM", "LM")
  ) %>%
  group_by(model_class) %>%
  mutate(
    delta_aic = aic - min(aic, na.rm = TRUE),
    aic_weight = exp(-0.5 * delta_aic) / sum(exp(-0.5 * delta_aic), na.rm = TRUE),
    delta_bic = bic - min(bic, na.rm = TRUE),
    evidence_ratio = exp(-0.5 * delta_aic) / max(exp(-0.5 * delta_aic))
  ) %>%
  ungroup() %>%
  arrange(model_class, delta_aic)

cat("\n  NOTE: AIC compared within model class (LM vs LMM separately)\n")
cat("\n  Growth model comparison:\n")
print(growth_stats %>% select(model, n_params, aic, delta_aic, aic_weight, pseudo_r2))

# Extract coefficients for all models (fixed-effects and mixed-effects)
growth_coefs <- bind_rows(lapply(names(growth_models), function(name) {
  if (!is.null(growth_models[[name]])) {
    get_model_coefs(growth_models[[name]], name)
  }
}))

# Extract random effects variance components for growth mixed-effects models
for (me_name in names(growth_models)) {
  if (!is.null(growth_models[[me_name]]) && inherits(growth_models[[me_name]], "merMod")) {
    vc <- as.data.frame(VarCorr(growth_models[[me_name]]))
    random_effects_list[[length(random_effects_list) + 1]] <- data.frame(
      model = me_name,
      group = vc$grp,
      variance = vc$vcov,
      std_dev = vc$sdcor
    )
  }
}

# Save all random effects variance components
if (length(random_effects_list) > 0) {
  random_effects_df <- bind_rows(random_effects_list)
  write.csv(random_effects_df, file.path(output_dir, "model_random_effects.csv"), row.names = FALSE)
  cat("  Saved: model_random_effects.csv\n")
}

# =============================================================================
# PUBLICATION-READY SUMMARY TABLE
# =============================================================================

cat("\n3. Creating Publication Summary Table...\n")

# Best survival model — prefer GLMM (methodologically appropriate)
best_surv <- survival_stats %>% filter(delta_aic == 0, model_class == "GLMM")
if (nrow(best_surv) == 0) {
  best_surv <- survival_stats %>% filter(delta_aic == 0, model_class == "GLM")
}
best_surv_name <- best_surv$model[1]

# Best growth model — prefer LMM over LM
best_growth <- growth_stats %>% filter(delta_aic == 0)
best_growth_lmm <- best_growth %>% filter(model_class == "LMM")
if (nrow(best_growth_lmm) > 0) best_growth <- best_growth_lmm
best_growth_name <- best_growth$model[1]

# Create summary
publication_summary <- data.frame(
  Response = c("Annual Survival", "Annual Survival", "Annual Survival",
               "Annual Growth", "Annual Growth", "Annual Growth"),
  Model = c(
    "Null (intercept only)",
    "Linear (log size)",
    "Threshold (100 cm²)",
    "Null (intercept only)",
    "Linear (log size)",
    "Categorical (5 classes)"
  ),
  df = c(
    survival_stats$n_params[survival_stats$model == "S1_null"],
    survival_stats$n_params[survival_stats$model == "S2_linear"],
    survival_stats$n_params[survival_stats$model == "S4_threshold"],
    growth_stats$n_params[growth_stats$model == "G1_null"],
    growth_stats$n_params[growth_stats$model == "G2_linear"],
    growth_stats$n_params[growth_stats$model == "G4_categorical"]
  ),
  AIC = c(
    survival_stats$aic[survival_stats$model == "S1_null"],
    survival_stats$aic[survival_stats$model == "S2_linear"],
    survival_stats$aic[survival_stats$model == "S4_threshold"],
    growth_stats$aic[growth_stats$model == "G1_null"],
    growth_stats$aic[growth_stats$model == "G2_linear"],
    growth_stats$aic[growth_stats$model == "G4_categorical"]
  ),
  stringsAsFactors = FALSE
)

publication_summary <- publication_summary %>%
  group_by(Response) %>%
  mutate(
    Delta_AIC = AIC - min(AIC),
    Best = ifelse(Delta_AIC == 0, "✓", "")
  ) %>%
  ungroup()

cat("\n  Publication summary table:\n")
print(publication_summary)

# =============================================================================
# COEFFICIENT SUMMARY FOR BEST MODELS
# =============================================================================

cat("\n4. Extracting Best Model Coefficients...\n")

# Best survival model coefficients
best_surv_coefs <- get_model_coefs(survival_models[[best_surv_name]], "Survival (best)")

# Convert to interpretable scale for logistic regression
best_surv_coefs <- best_surv_coefs %>%
  mutate(
    odds_ratio = exp(estimate),
    or_ci_lower = exp(ci_lower),
    or_ci_upper = exp(ci_upper)
  )

cat("\n  Best survival model coefficients:\n")
print(best_surv_coefs %>% select(term, estimate, odds_ratio, p_value))

# Best growth model coefficients
best_growth_coefs <- get_model_coefs(growth_models[[best_growth_name]], "Growth (best)")

cat("\n  Best growth model coefficients:\n")
print(best_growth_coefs %>% select(term, estimate, std_error, p_value))

# =============================================================================
# MODEL DIAGNOSTICS SUMMARY
# =============================================================================

cat("\n5. Model Diagnostics Summary...\n")

diagnostics_summary <- data.frame(
  Model_Type = c("Survival (Threshold)", "Growth (Linear)"),
  N_Observations = c(nrow(survival_data), nrow(growth_data)),
  Pseudo_R2 = c(
    survival_stats$pseudo_r2[survival_stats$model == best_surv_name],
    growth_stats$pseudo_r2[growth_stats$model == best_growth_name]
  ),
  AIC = c(
    survival_stats$aic[survival_stats$model == best_surv_name],
    growth_stats$aic[growth_stats$model == best_growth_name]
  ),
  stringsAsFactors = FALSE
)

cat("\n  Diagnostics summary:\n")
print(diagnostics_summary)

# =============================================================================
# SAVE OUTPUTS
# =============================================================================

cat("\n6. Saving Model Selection Outputs...\n")

# Survival model comparison
write.csv(survival_stats, file.path(output_dir, "model_selection_survival.csv"),
          row.names = FALSE)
cat("  ✓ Saved: model_selection_survival.csv\n")

# Growth model comparison
write.csv(growth_stats, file.path(output_dir, "model_selection_growth.csv"),
          row.names = FALSE)
cat("  ✓ Saved: model_selection_growth.csv\n")

# All coefficients
all_coefs <- bind_rows(
  survival_coefs %>% mutate(response = "survival"),
  growth_coefs %>% mutate(response = "growth")
)
write.csv(all_coefs, file.path(output_dir, "model_coefficients.csv"), row.names = FALSE)
cat("  ✓ Saved: model_coefficients.csv\n")

# Publication summary
write.csv(publication_summary, file.path(output_dir, "model_summary_table.csv"),
          row.names = FALSE)
cat("  ✓ Saved: model_summary_table.csv\n")

# Best model coefficients
best_coefs <- bind_rows(
  best_surv_coefs %>% mutate(response = "survival"),
  best_growth_coefs %>% mutate(response = "growth")
)
write.csv(best_coefs, file.path(output_dir, "best_model_coefficients.csv"),
          row.names = FALSE)
cat("  ✓ Saved: best_model_coefficients.csv\n")

# =============================================================================
# VISUALIZATIONS
# =============================================================================

cat("\n7. Creating Model Selection Visualizations...\n")

# AIC comparison plot - Survival
p1 <- survival_stats %>%
  mutate(model = reorder(model, -delta_aic)) %>%
  ggplot(aes(x = model, y = delta_aic)) +
  geom_col(aes(fill = delta_aic == 0), width = 0.7) +
  geom_hline(yintercept = 2, linetype = "dashed", color = "gray50") +
  geom_hline(yintercept = 10, linetype = "dashed", color = "gray50") +
  annotate("text", x = 0.5, y = 3, label = "Substantial support (<2)",
           hjust = 0, size = 2.5, color = "gray50") +
  annotate("text", x = 0.5, y = 11, label = "No support (>10)",
           hjust = 0, size = 2.5, color = "gray50") +
  scale_fill_manual(values = c("FALSE" = "#3498DB", "TRUE" = "#27AE60"),
                    guide = "none") +
  coord_flip() +
  labs(
    title = "Survival Model Selection",
    subtitle = "Lower ΔAIC indicates better model fit",
    x = "Model",
    y = "ΔAIC"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

ggsave(file.path(fig_supp_dir, "model_selection_survival.png"), p1,
       width = 8, height = 5, dpi = 150)
cat("  ✓ Saved: model_selection_survival.png\n")

# AIC comparison plot - Growth
p2 <- growth_stats %>%
  mutate(model = reorder(model, -delta_aic)) %>%
  ggplot(aes(x = model, y = delta_aic)) +
  geom_col(aes(fill = delta_aic == 0), width = 0.7) +
  geom_hline(yintercept = 2, linetype = "dashed", color = "gray50") +
  scale_fill_manual(values = c("FALSE" = "#9B59B6", "TRUE" = "#27AE60"),
                    guide = "none") +
  coord_flip() +
  labs(
    title = "Growth Model Selection",
    subtitle = "Lower ΔAIC indicates better model fit",
    x = "Model",
    y = "ΔAIC"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

ggsave(file.path(fig_supp_dir, "model_selection_growth.png"), p2,
       width = 8, height = 5, dpi = 150)
cat("  ✓ Saved: model_selection_growth.png\n")

# Coefficient plot for best survival model
if (nrow(best_surv_coefs) > 1) {
  p3 <- best_surv_coefs %>%
    filter(term != "(Intercept)") %>%
    ggplot(aes(x = term, y = odds_ratio)) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = or_ci_lower, ymax = or_ci_upper), width = 0.2) +
    geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
    coord_flip() +
    labs(
      title = "Survival Model: Effect Sizes (Odds Ratios)",
      subtitle = "95% Confidence Intervals; OR=1 indicates no effect",
      x = "Predictor",
      y = "Odds Ratio"
    ) +
    theme_minimal() +
    theme(plot.title = element_text(face = "bold"))

  ggsave(file.path(fig_supp_dir, "survival_coefficients.png"), p3,
         width = 8, height = 5, dpi = 150)
  cat("  ✓ Saved: survival_coefficients.png\n")
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  MODEL SELECTION COMPLETE                                    ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("MODEL SELECTION RESULTS:\n")
cat("─────────────────────────────────────────────────────────────────\n")

cat("\n  SURVIVAL MODELS:\n")
cat(sprintf("    Best model: %s (AIC = %.1f)\n",
            best_surv_name, best_surv$aic[1]))
cat(sprintf("    Pseudo R²: %.3f\n", best_surv$pseudo_r2[1]))

# Model ranking
cat("\n    Model ranking (by AIC):\n")
for (i in 1:min(5, nrow(survival_stats))) {
  support <- case_when(
    survival_stats$delta_aic[i] == 0 ~ "BEST",
    survival_stats$delta_aic[i] < 2 ~ "substantial support",
    survival_stats$delta_aic[i] < 10 ~ "some support",
    TRUE ~ "no support"
  )
  cat(sprintf("      %d. %s (ΔAIC=%.1f, %s)\n",
              i, survival_stats$model[i],
              survival_stats$delta_aic[i], support))
}

cat("\n  GROWTH MODELS:\n")
cat(sprintf("    Best model: %s (AIC = %.1f)\n",
            best_growth_name, best_growth$aic[1]))
cat(sprintf("    R²: %.3f\n", best_growth$pseudo_r2[1]))

cat("\n    Model ranking (by AIC):\n")
for (i in 1:min(5, nrow(growth_stats))) {
  support <- case_when(
    growth_stats$delta_aic[i] == 0 ~ "BEST",
    growth_stats$delta_aic[i] < 2 ~ "substantial support",
    growth_stats$delta_aic[i] < 10 ~ "some support",
    TRUE ~ "no support"
  )
  cat(sprintf("      %d. %s (ΔAIC=%.1f, %s)\n",
              i, growth_stats$model[i],
              growth_stats$delta_aic[i], support))
}

cat("\nKEY INTERPRETATIONS:\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat("  • ΔAIC < 2: Substantial support (models essentially equivalent)\n")
cat("  • ΔAIC 2-10: Some support (model less likely but possible)\n")
cat("  • ΔAIC > 10: No support (model should be rejected)\n")

cat("\nOutputs:\n")
cat("  - model_selection_survival.csv (survival model comparison)\n")
cat("  - model_selection_growth.csv (growth model comparison)\n")
cat("  - model_coefficients.csv (all model coefficients)\n")
cat("  - model_summary_table.csv (publication summary)\n")
cat("  - best_model_coefficients.csv (best model details)\n")
cat("  - model_selection_*.png (visualizations)\n")
