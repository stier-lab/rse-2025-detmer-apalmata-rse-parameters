################################################################################
# 10_cross_validation.R - Expanded Cross-Validation Framework
################################################################################
#
# PURPOSE:
#   Implement comprehensive cross-validation to assess model predictive
#   performance and generalizability across studies, regions, and time periods.
#
# METHODS:
#   1. Leave-one-study-out cross-validation (LOSO-CV)
#   2. Leave-one-region-out cross-validation (LORO-CV)
#   3. K-fold cross-validation
#   4. Temporal holdout validation
#   5. Spatial blocking cross-validation
#   6. Model performance metrics
#
# OUTPUTS:
#   - cross_validation_results.csv: All CV results
#   - cv_performance_summary.csv: Performance metrics by method
#   - supplementary/exploratory/cv_*.png: Visualizations
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

dirs <- setup_output_dirs()
output_dir <- dirs$output
fig_explore_dir <- file.path(dirs$figures_supp, "exploratory")
dir.create(fig_explore_dir, showWarnings = FALSE, recursive = TRUE)

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  14: EXPANDED CROSS-VALIDATION FRAMEWORK                     ║\n")
cat("║  Assessing Model Generalizability                            ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# =============================================================================
# SETUP
# =============================================================================

# Load prepared data
cat("Loading prepared data...\n")
survival_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

# Add size classes
survival_data <- survival_data %>%
  mutate(
    size_class = case_when(
      size_cm2 <= 25 ~ "SC1",
      size_cm2 <= 100 ~ "SC2",
      size_cm2 <= 500 ~ "SC3",
      size_cm2 <= 2000 ~ "SC4",
      TRUE ~ "SC5"
    ),
    log_size = log(size_cm2)
  )

cat(sprintf("  Survival data: %d observations, %d studies, %d regions\n",
            nrow(survival_data),
            length(unique(survival_data$study)),
            length(unique(survival_data$region))))

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

#' Calculate performance metrics for binary classification
calc_metrics <- function(actual, predicted_prob, threshold = 0.5) {
  # Brier score (lower is better)
  brier <- mean((predicted_prob - actual)^2, na.rm = TRUE)

  # Log loss / cross-entropy (lower is better)
  eps <- 1e-10
  predicted_prob <- pmax(pmin(predicted_prob, 1 - eps), eps)
  logloss <- -mean(actual * log(predicted_prob) +
                   (1 - actual) * log(1 - predicted_prob), na.rm = TRUE)

  # AUC approximation using Mann-Whitney U statistic
  if (length(unique(actual)) == 2) {
    pred_1 <- predicted_prob[actual == 1]
    pred_0 <- predicted_prob[actual == 0]
    if (length(pred_1) > 0 && length(pred_0) > 0) {
      auc <- mean(outer(pred_1, pred_0, ">")) + 0.5 * mean(outer(pred_1, pred_0, "=="))
    } else {
      auc <- NA
    }
  } else {
    auc <- NA
  }

  # Classification metrics at threshold
  predicted_class <- as.numeric(predicted_prob >= threshold)
  accuracy <- mean(predicted_class == actual, na.rm = TRUE)

  tp <- sum(predicted_class == 1 & actual == 1, na.rm = TRUE)
  fp <- sum(predicted_class == 1 & actual == 0, na.rm = TRUE)
  fn <- sum(predicted_class == 0 & actual == 1, na.rm = TRUE)
  tn <- sum(predicted_class == 0 & actual == 0, na.rm = TRUE)

  sensitivity <- if ((tp + fn) > 0) tp / (tp + fn) else NA
  specificity <- if ((tn + fp) > 0) tn / (tn + fp) else NA

  data.frame(
    brier_score = brier,
    log_loss = logloss,
    auc = auc,
    accuracy = accuracy,
    sensitivity = sensitivity,
    specificity = specificity,
    n_test = length(actual)
  )
}

#' Calculate calibration metrics for predicted probabilities
calc_calibration <- function(predicted, observed, n_bins = 10) {
  if (length(predicted) < n_bins * 2) {
    return(list(ece = NA, mce = NA, calibration_table = NULL))
  }

  bins <- cut(predicted, breaks = seq(0, 1, length.out = n_bins + 1), include.lowest = TRUE)
  cal_table <- data.frame(
    bin = levels(bins),
    n = as.numeric(table(bins)),
    mean_predicted = tapply(predicted, bins, mean),
    mean_observed = tapply(observed, bins, mean)
  )
  cal_table <- cal_table[cal_table$n > 0, ]

  # Expected Calibration Error (weighted by bin size)
  ece <- sum(cal_table$n * abs(cal_table$mean_predicted - cal_table$mean_observed), na.rm = TRUE) /
         sum(cal_table$n, na.rm = TRUE)

  # Maximum Calibration Error
  mce <- max(abs(cal_table$mean_predicted - cal_table$mean_observed), na.rm = TRUE)

  return(list(ece = ece, mce = mce, calibration_table = cal_table))
}

#' Fit survival model and predict (GLMM with GLM fallback)
fit_and_predict <- function(train_data, test_data) {
  tryCatch({
    # Try GLMM first (matches manuscript model) — requires >= 2 studies in training data
    if (length(unique(train_data$study)) >= 2) {
      model <- lme4::glmer(survived ~ log_size + (1|study),
                           data = train_data, family = binomial)
      # Population-level prediction (no study random effect for new/held-out study)
      predictions <- predict(model, newdata = test_data, re.form = NA, type = "response")
    } else {
      # Single study in training fold: fall back to GLM
      model <- glm(survived ~ log_size, data = train_data, family = binomial)
      predictions <- predict(model, newdata = test_data, type = "response")
    }
    predictions
  }, error = function(e) {
    # Fallback: try GLM if GLMM fails (convergence issues)
    tryCatch({
      model <- glm(survived ~ log_size, data = train_data, family = binomial)
      predict(model, newdata = test_data, type = "response")
    }, error = function(e2) {
      rep(mean(train_data$survived, na.rm = TRUE), nrow(test_data))
    })
  })
}

# =============================================================================
# 1. LEAVE-ONE-STUDY-OUT CROSS-VALIDATION (LOSO-CV)
# =============================================================================

cat("\n1. Leave-One-Study-Out Cross-Validation...\n")

studies <- unique(survival_data$study)
loso_results <- map_dfr(studies, function(holdout_study) {
  train <- survival_data %>% filter(study != holdout_study)
  test <- survival_data %>% filter(study == holdout_study)

  if (nrow(test) < 5) {
    return(data.frame(
      cv_method = "LOSO",
      fold = holdout_study,
      n_train = nrow(train),
      n_test = nrow(test),
      brier_score = NA,
      log_loss = NA,
      auc = NA,
      accuracy = NA,
      sensitivity = NA,
      specificity = NA,
      ece = NA,
      mce = NA
    ))
  }

  predictions <- fit_and_predict(train, test)
  metrics <- calc_metrics(test$survived, predictions)
  cal <- calc_calibration(predictions, test$survived)

  data.frame(
    cv_method = "LOSO",
    fold = holdout_study,
    n_train = nrow(train),
    metrics,
    ece = cal$ece,
    mce = cal$mce
  )
})

cat(sprintf("  Studies tested: %d\n", length(studies)))
cat(sprintf("  Mean Brier score: %.4f\n", mean(loso_results$brier_score, na.rm = TRUE)))
cat(sprintf("  Mean AUC: %.3f\n", mean(loso_results$auc, na.rm = TRUE)))
cat(sprintf("  Mean ECE: %.4f\n", mean(loso_results$ece, na.rm = TRUE)))
cat(sprintf("  Mean MCE: %.4f\n", mean(loso_results$mce, na.rm = TRUE)))

# FIX: Weight LOSO-CV by held-out sample size (critique audit 2026-03-29)
# Unweighted means give equal voice to each study regardless of size.
# Sample-size-weighted means better reflect overall predictive performance.
loso_valid <- loso_results %>% filter(!is.na(brier_score) & !is.na(n_test) & n_test > 0)
if (nrow(loso_valid) > 0) {
  loso_valid$weight <- loso_valid$n_test
  weighted_brier <- weighted.mean(loso_valid$brier_score, loso_valid$weight)
  weighted_auc <- weighted.mean(loso_valid$auc, loso_valid$weight, na.rm = TRUE)
  weighted_logloss <- weighted.mean(loso_valid$log_loss, loso_valid$weight, na.rm = TRUE)
  cat(sprintf("  Weighted mean Brier (by n_test): %.4f\n", weighted_brier))
  cat(sprintf("  Weighted mean AUC (by n_test): %.4f\n", weighted_auc))
  cat(sprintf("  Weighted mean log-loss (by n_test): %.4f\n", weighted_logloss))
  cat("  NOTE: Weighted means account for unequal study sizes (NOAA = 78%% of data).\n")
}

# =============================================================================
# 2. LEAVE-ONE-REGION-OUT CROSS-VALIDATION (LORO-CV)
# =============================================================================

cat("\n2. Leave-One-Region-Out Cross-Validation...\n")

regions <- unique(survival_data$region)
loro_results <- map_dfr(regions, function(holdout_region) {
  train <- survival_data %>% filter(region != holdout_region)
  test <- survival_data %>% filter(region == holdout_region)

  if (nrow(test) < 5 || nrow(train) < 20) {
    return(data.frame(
      cv_method = "LORO",
      fold = holdout_region,
      n_train = nrow(train),
      n_test = nrow(test),
      brier_score = NA,
      log_loss = NA,
      auc = NA,
      accuracy = NA,
      sensitivity = NA,
      specificity = NA,
      ece = NA,
      mce = NA
    ))
  }

  predictions <- fit_and_predict(train, test)
  metrics <- calc_metrics(test$survived, predictions)
  cal <- calc_calibration(predictions, test$survived)

  data.frame(
    cv_method = "LORO",
    fold = holdout_region,
    n_train = nrow(train),
    metrics,
    ece = cal$ece,
    mce = cal$mce
  )
})

cat(sprintf("  Regions tested: %d\n", length(regions)))
valid_loro <- loro_results %>% filter(!is.na(brier_score))
cat(sprintf("  Regions with valid results: %d\n", nrow(valid_loro)))
cat(sprintf("  Mean Brier score: %.4f\n", mean(valid_loro$brier_score, na.rm = TRUE)))
cat(sprintf("  Mean AUC: %.3f\n", mean(valid_loro$auc, na.rm = TRUE)))

# =============================================================================
# 3. K-FOLD CROSS-VALIDATION
# =============================================================================

cat("\n3. K-Fold Cross-Validation (k=5, grouped by study)...\n")

set.seed(42)
k <- 5  # Match number of studies to avoid empty folds
# NOTE: Standard k-fold (random observation assignment) would allow the same
# study to appear in both train and test, inflating performance metrics.
# We use grouped k-fold (study-level assignment) for honest evaluation.
# Compare with LOSO results — the gap should be smaller with grouped folds.

# Grouped k-fold: assign STUDIES (not observations) to folds
# This prevents data leakage from within-study correlation
# Note: fold sizes may be unequal due to varying study sizes
study_folds <- survival_data %>%
  distinct(study) %>%
  mutate(fold = sample(rep_len(1:k, n())))

survival_data <- survival_data %>%
  select(-any_of("fold")) %>%  # Remove old fold assignment if exists
  left_join(study_folds, by = "study")

cat(sprintf("  Grouped k-fold: %d studies assigned to %d folds\n",
            nrow(study_folds), k))
cat("  (observations from the same study always in the same fold)\n")

kfold_results <- map_dfr(1:k, function(fold_num) {
  train <- survival_data %>% filter(fold != fold_num)
  test <- survival_data %>% filter(fold == fold_num)

  predictions <- fit_and_predict(train, test)
  metrics <- calc_metrics(test$survived, predictions)
  cal <- calc_calibration(predictions, test$survived)

  data.frame(
    cv_method = "K-fold",
    fold = as.character(fold_num),
    n_train = nrow(train),
    metrics,
    ece = cal$ece,
    mce = cal$mce
  )
})

cat(sprintf("  Folds: %d\n", k))
cat(sprintf("  Mean Brier score: %.4f (SD: %.4f)\n",
            mean(kfold_results$brier_score), sd(kfold_results$brier_score)))
cat(sprintf("  Mean AUC: %.3f (SD: %.3f)\n",
            mean(kfold_results$auc, na.rm = TRUE), sd(kfold_results$auc, na.rm = TRUE)))

# =============================================================================
# 4. TEMPORAL HOLDOUT VALIDATION
# =============================================================================

cat("\n4. Temporal Holdout Validation...\n")

# Train on earlier years, test on recent years
year_splits <- list(
  "Train≤2015, Test>2015" = list(train_max = 2015, test_min = 2016),
  "Train≤2018, Test>2018" = list(train_max = 2018, test_min = 2019),
  "Train≤2020, Test>2020" = list(train_max = 2020, test_min = 2021)
)

temporal_results <- map_dfr(names(year_splits), function(split_name) {
  split <- year_splits[[split_name]]

  train <- survival_data %>% filter(survey_yr <= split$train_max)
  test <- survival_data %>% filter(survey_yr >= split$test_min)

  if (nrow(test) < 10 || nrow(train) < 50) {
    return(data.frame(
      cv_method = "Temporal",
      fold = split_name,
      n_train = nrow(train),
      n_test = nrow(test),
      brier_score = NA,
      log_loss = NA,
      auc = NA,
      accuracy = NA,
      sensitivity = NA,
      specificity = NA,
      ece = NA,
      mce = NA
    ))
  }

  predictions <- fit_and_predict(train, test)
  metrics <- calc_metrics(test$survived, predictions)
  cal <- calc_calibration(predictions, test$survived)

  data.frame(
    cv_method = "Temporal",
    fold = split_name,
    n_train = nrow(train),
    metrics,
    ece = cal$ece,
    mce = cal$mce
  )
})

cat("  Temporal splits tested:\n")
for (i in 1:nrow(temporal_results)) {
  if (!is.na(temporal_results$brier_score[i])) {
    cat(sprintf("    • %s: AUC=%.3f, Brier=%.4f (n_test=%d)\n",
                temporal_results$fold[i],
                temporal_results$auc[i],
                temporal_results$brier_score[i],
                temporal_results$n_test[i]))
  }
}

# =============================================================================
# 5. LEAVE-ONE-SIZE-CLASS-OUT CROSS-VALIDATION (LOSCO-CV)
# =============================================================================
# Tests model extrapolation to unseen size ranges
# This is more aggressive than stratified CV and tests generalizability

cat("\n5. Leave-One-Size-Class-Out Cross-Validation (LOSCO-CV)...\n")

size_classes <- unique(survival_data$size_class)
stratified_results <- map_dfr(size_classes, function(holdout_class) {
  train <- survival_data %>% filter(size_class != holdout_class)
  test <- survival_data %>% filter(size_class == holdout_class)

  if (nrow(test) < 10) {
    return(data.frame(
      cv_method = "LOSCO",
      fold = holdout_class,
      n_train = nrow(train),
      n_test = nrow(test),
      brier_score = NA,
      log_loss = NA,
      auc = NA,
      accuracy = NA,
      sensitivity = NA,
      specificity = NA,
      ece = NA,
      mce = NA
    ))
  }

  predictions <- fit_and_predict(train, test)
  metrics <- calc_metrics(test$survived, predictions)
  cal <- calc_calibration(predictions, test$survived)

  data.frame(
    cv_method = "LOSCO",
    fold = holdout_class,
    n_train = nrow(train),
    metrics,
    ece = cal$ece,
    mce = cal$mce
  )
})

cat("  Size classes held out:\n")
for (i in 1:nrow(stratified_results)) {
  cat(sprintf("    • %s: AUC=%.3f, Brier=%.4f\n",
              stratified_results$fold[i],
              stratified_results$auc[i],
              stratified_results$brier_score[i]))
}

# =============================================================================
# 6. NESTED CROSS-VALIDATION FOR MODEL SELECTION
# =============================================================================

cat("\n6. Model Comparison via Cross-Validation...\n")

# Compare different model specifications
models <- list(
  "Null (intercept only)" = function(d) glm(survived ~ 1, data = d, family = binomial),
  "Linear (log size)" = function(d) glm(survived ~ log_size, data = d, family = binomial),
  "Size class (categorical)" = function(d) glm(survived ~ size_class, data = d, family = binomial)
)

# Use k-fold CV to compare models
model_comparison <- map_dfr(names(models), function(model_name) {
  model_fn <- models[[model_name]]

  fold_metrics <- map_dfr(1:k, function(fold_num) {
    train <- survival_data %>% filter(fold != fold_num)
    test <- survival_data %>% filter(fold == fold_num)

    tryCatch({
      model <- model_fn(train)
      predictions <- predict(model, newdata = test, type = "response")
      metrics <- calc_metrics(test$survived, predictions)
      metrics$model = model_name
      metrics$fold = fold_num
      metrics
    }, error = function(e) {
      data.frame(model = model_name, fold = fold_num,
                 brier_score = NA, log_loss = NA, auc = NA,
                 accuracy = NA, sensitivity = NA, specificity = NA, n_test = NA)
    })
  })

  fold_metrics
})

model_summary <- model_comparison %>%
  group_by(model) %>%
  summarise(
    mean_brier = mean(brier_score, na.rm = TRUE),
    sd_brier = sd(brier_score, na.rm = TRUE),
    mean_auc = mean(auc, na.rm = TRUE),
    sd_auc = sd(auc, na.rm = TRUE),
    mean_accuracy = mean(accuracy, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(mean_brier)

cat("\n  Model comparison (by Brier score):\n")
print(model_summary)

# ============================================================
# SECTION 7: GROWTH MODEL CROSS-VALIDATION
# ============================================================
cat("\n\n======================================\n")
cat("GROWTH MODEL CROSS-VALIDATION\n")
cat("======================================\n\n")

# Metrics for continuous outcomes
calc_growth_metrics <- function(predicted, observed) {
  residuals <- observed - predicted
  list(
    rmse = sqrt(mean(residuals^2, na.rm = TRUE)),
    mae = mean(abs(residuals), na.rm = TRUE),
    r_squared = 1 - sum(residuals^2, na.rm = TRUE) /
                    sum((observed - mean(observed, na.rm = TRUE))^2, na.rm = TRUE),
    n = length(observed)
  )
}

# Add size class to growth data if needed
if (!is.null(growth_data) && nrow(growth_data) > 0) {
  if (!"log_size" %in% names(growth_data)) {
    growth_data$log_size <- log(pmax(growth_data$size_cm2, 0.01))
  }
}

# LOSO-CV for growth
if (!is.null(growth_data) && nrow(growth_data) > 0 && "study" %in% names(growth_data)) {
  growth_studies <- unique(growth_data$study)
  cat(sprintf("Growth LOSO-CV across %d studies\n", length(growth_studies)))

  growth_cv_results <- data.frame()

  for (study_name in growth_studies) {
    train <- growth_data[growth_data$study != study_name, ]
    test <- growth_data[growth_data$study == study_name, ]

    if (nrow(test) < 5 || nrow(train) < 20) next

    # Fit model on training data
    growth_model <- tryCatch(
      lm(growth_cm2_yr ~ log(pmax(size_cm2, 1)), data = train),
      error = function(e) NULL
    )

    if (!is.null(growth_model)) {
      preds <- predict(growth_model, newdata = test)
      metrics <- calc_growth_metrics(preds, test$growth_cm2_yr)
      growth_cv_results <- rbind(growth_cv_results, data.frame(
        excluded_study = study_name,
        n_test = metrics$n,
        rmse = metrics$rmse,
        mae = metrics$mae,
        r_squared = metrics$r_squared
      ))
    }
  }

  if (nrow(growth_cv_results) > 0) {
    cat("\nGrowth LOSO-CV Results:\n")
    print(growth_cv_results, digits = 3)
    cat(sprintf("\nMean RMSE: %.2f, Mean MAE: %.2f, Mean R-squared: %.3f\n",
                mean(growth_cv_results$rmse), mean(growth_cv_results$mae),
                mean(growth_cv_results$r_squared)))

    write.csv(growth_cv_results, file.path(output_dir, "cv_growth_loso_results.csv"),
              row.names = FALSE)
    cat("  Saved: cv_growth_loso_results.csv\n")

    # Save growth CV summary
    cv_growth_summary <- data.frame(
      mean_rmse = mean(growth_cv_results$rmse, na.rm = TRUE),
      mean_mae = mean(growth_cv_results$mae, na.rm = TRUE),
      mean_r_squared = mean(growth_cv_results$r_squared, na.rm = TRUE),
      sd_rmse = sd(growth_cv_results$rmse, na.rm = TRUE),
      n_folds = nrow(growth_cv_results)
    )
    write.csv(cv_growth_summary, file.path(output_dir, "cv_growth_summary.csv"),
              row.names = FALSE)
    cat("  Saved: cv_growth_summary.csv\n")
  } else {
    cat("  No valid growth CV folds (insufficient data per study).\n")
  }
} else {
  cat("  Growth data not available or missing study column.\n")
}

# =============================================================================
# COMPILE ALL RESULTS
# =============================================================================

cat("\n8. Compiling Cross-Validation Results...\n")

all_cv_results <- bind_rows(
  loso_results,
  loro_results,
  kfold_results,
  temporal_results,
  stratified_results
)

cv_performance_summary <- all_cv_results %>%
  group_by(cv_method) %>%
  summarise(
    n_folds = n(),
    mean_brier = mean(brier_score, na.rm = TRUE),
    sd_brier = sd(brier_score, na.rm = TRUE),
    mean_auc = mean(auc, na.rm = TRUE),
    sd_auc = sd(auc, na.rm = TRUE),
    mean_accuracy = mean(accuracy, na.rm = TRUE),
    mean_sensitivity = mean(sensitivity, na.rm = TRUE),
    mean_specificity = mean(specificity, na.rm = TRUE),
    mean_ece = mean(ece, na.rm = TRUE),
    mean_mce = mean(mce, na.rm = TRUE),
    # FIX: Add sample-size-weighted means to CV summary (critique audit 2026-03-29)
    weighted_mean_brier = if (all(is.na(n_test) | is.na(brier_score))) NA_real_
                          else weighted.mean(brier_score[!is.na(brier_score)],
                                             n_test[!is.na(brier_score)]),
    weighted_mean_auc = if (all(is.na(n_test) | is.na(auc))) NA_real_
                        else weighted.mean(auc[!is.na(auc)],
                                           n_test[!is.na(auc)]),
    total_n_test = sum(n_test, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(mean_brier)

cat("\n  Performance summary by CV method:\n")
print(cv_performance_summary)

# =============================================================================
# CALIBRATION SUMMARY
# =============================================================================

cat("\n=== CALIBRATION SUMMARY ===\n")
cat("Expected Calibration Error (ECE) by CV scheme:\n")
cal_summary <- cv_performance_summary %>%
  select(cv_method, mean_ece, mean_mce) %>%
  arrange(mean_ece)
print(cal_summary)

cat("\nNote: Calibration matters for practitioner tools (OutplantingWizard, SurvivalTool)\n")
cat("that provide probability estimates. Poor calibration means predicted 80% survival\n")
cat("may actually correspond to 60% or 95% observed survival.\n")

if (any(!is.na(cal_summary$mean_ece))) {
  best_cal <- cal_summary %>% filter(!is.na(mean_ece)) %>% filter(mean_ece == min(mean_ece))
  worst_cal <- cal_summary %>% filter(!is.na(mean_ece)) %>% filter(mean_ece == max(mean_ece))
  cat(sprintf("\n  Best calibrated CV: %s (ECE = %.4f)\n", best_cal$cv_method[1], best_cal$mean_ece[1]))
  cat(sprintf("  Worst calibrated CV: %s (ECE = %.4f)\n", worst_cal$cv_method[1], worst_cal$mean_ece[1]))

  if (max(cal_summary$mean_ece, na.rm = TRUE) > 0.10) {
    cat("  WARNING: ECE > 0.10 indicates substantial miscalibration in some CV schemes.\n")
    cat("  Consider probability calibration (Platt scaling or isotonic regression).\n")
  }
}

# =============================================================================
# SAVE OUTPUTS
# =============================================================================

cat("\nSaving cross-validation outputs...\n")

write.csv(all_cv_results, file.path(output_dir, "cross_validation_results.csv"), row.names = FALSE)
cat("  ✓ Saved: cross_validation_results.csv\n")

write.csv(cv_performance_summary, file.path(output_dir, "cv_performance_summary.csv"), row.names = FALSE)
cat("  ✓ Saved: cv_performance_summary.csv\n")

write.csv(model_summary, file.path(output_dir, "cv_model_comparison.csv"), row.names = FALSE)
cat("  ✓ Saved: cv_model_comparison.csv\n")

# =============================================================================
# VISUALIZATIONS
# =============================================================================

cat("\nCreating cross-validation visualizations...\n")

# CV method comparison
p1 <- cv_performance_summary %>%
  ggplot(aes(x = reorder(cv_method, mean_brier), y = mean_brier)) +
  geom_col(fill = "#3498DB", width = 0.7) +
  geom_errorbar(aes(ymin = mean_brier - sd_brier, ymax = mean_brier + sd_brier),
                width = 0.2) +
  coord_flip() +
  labs(
    title = "Cross-Validation Performance by Method",
    subtitle = "Lower Brier score indicates better predictive accuracy",
    x = "CV Method",
    y = "Mean Brier Score (± SD)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

ggsave(file.path(fig_explore_dir, "cv_method_comparison.png"), p1,
       width = 8, height = 5, dpi = 150)
cat("  ✓ Saved: cv_method_comparison.png\n")

# LOSO results
p2 <- loso_results %>%
  filter(!is.na(brier_score)) %>%
  mutate(fold = reorder(fold, brier_score)) %>%
  ggplot(aes(x = fold, y = brier_score)) +
  geom_col(aes(fill = brier_score), width = 0.7) +
  scale_fill_viridis_c(option = "plasma", direction = -1) +
  coord_flip() +
  labs(
    title = "Leave-One-Study-Out Cross-Validation",
    subtitle = "Model performance when each study is held out",
    x = "Held-Out Study",
    y = "Brier Score",
    fill = "Brier\nScore"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "right"
  )

ggsave(file.path(fig_explore_dir, "cv_loso_results.png"), p2,
       width = 8, height = 5, dpi = 150)
cat("  ✓ Saved: cv_loso_results.png\n")

# Model comparison
p3 <- model_comparison %>%
  filter(!is.na(brier_score)) %>%
  ggplot(aes(x = model, y = brier_score)) +
  geom_boxplot(fill = "#2ECC71", alpha = 0.7) +
  coord_flip() +
  labs(
    title = sprintf("Model Comparison via %d-Fold Cross-Validation", k),
    subtitle = "Distribution of Brier scores across folds",
    x = "Model",
    y = "Brier Score"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

ggsave(file.path(fig_explore_dir, "cv_model_comparison.png"), p3,
       width = 8, height = 5, dpi = 150)
cat("  ✓ Saved: cv_model_comparison.png\n")

# AUC by method
p4 <- cv_performance_summary %>%
  filter(!is.na(mean_auc)) %>%
  ggplot(aes(x = reorder(cv_method, mean_auc), y = mean_auc)) +
  geom_col(fill = "#9B59B6", width = 0.7) +
  geom_errorbar(aes(ymin = pmax(0, mean_auc - sd_auc),
                    ymax = pmin(1, mean_auc + sd_auc)),
                width = 0.2) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "gray50") +
  annotate("text", x = 0.5, y = 0.52, label = "Random guessing",
           hjust = 0, size = 3, color = "gray50") +
  coord_flip() +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    title = "AUC by Cross-Validation Method",
    subtitle = "Higher AUC indicates better discrimination",
    x = "CV Method",
    y = "Mean AUC (± SD)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

ggsave(file.path(fig_explore_dir, "cv_auc_comparison.png"), p4,
       width = 8, height = 5, dpi = 150)
cat("  ✓ Saved: cv_auc_comparison.png\n")

# =============================================================================
# FINAL SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  CROSS-VALIDATION COMPLETE                                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("PERFORMANCE SUMMARY:\n")
cat("─────────────────────────────────────────────────────────────────\n")

# Best CV method
best_method <- cv_performance_summary %>% filter(mean_brier == min(mean_brier, na.rm = TRUE))
cat(sprintf("  Best performing CV: %s (Brier = %.4f)\n",
            best_method$cv_method[1], best_method$mean_brier[1]))

# Worst (most challenging)
worst_method <- cv_performance_summary %>% filter(mean_brier == max(mean_brier, na.rm = TRUE))
cat(sprintf("  Most challenging CV: %s (Brier = %.4f)\n",
            worst_method$cv_method[1], worst_method$mean_brier[1]))

# Overall performance
overall_brier <- mean(all_cv_results$brier_score, na.rm = TRUE)
overall_auc <- mean(all_cv_results$auc, na.rm = TRUE)
cat(sprintf("\n  Overall mean Brier score: %.4f\n", overall_brier))
cat(sprintf("  Overall mean AUC: %.3f\n", overall_auc))

# Generalizability assessment
cat("\nGENERALIZABILITY ASSESSMENT:\n")
cat("─────────────────────────────────────────────────────────────────\n")

loso_vs_kfold <- loso_results %>%
  summarise(mean_brier = mean(brier_score, na.rm = TRUE)) %>%
  pull(mean_brier) -
  kfold_results %>%
  summarise(mean_brier = mean(brier_score, na.rm = TRUE)) %>%
  pull(mean_brier)

if (abs(loso_vs_kfold) < 0.02) {
  cat("  ✓ GOOD: Model generalizes well across studies\n")
  cat(sprintf("    (LOSO vs K-fold difference: %.4f)\n", loso_vs_kfold))
} else if (loso_vs_kfold > 0) {
  cat("  ⚠ MODERATE: Some loss of performance across studies\n")
  cat(sprintf("    (LOSO performs %.4f worse than K-fold)\n", loso_vs_kfold))
} else {
  cat("  ✓ GOOD: Model may actually benefit from study diversity\n")
}

# Temporal generalization
valid_temporal <- temporal_results %>% filter(!is.na(brier_score))
if (nrow(valid_temporal) > 0) {
  temporal_brier <- mean(valid_temporal$brier_score, na.rm = TRUE)
  if (temporal_brier < 0.20) {
    cat("  ✓ GOOD: Model generalizes well to future years\n")
  } else {
    cat("  ⚠ CAUTION: Performance may degrade for future predictions\n")
  }
  cat(sprintf("    (Temporal holdout Brier: %.4f)\n", temporal_brier))
}

# Best model
best_model <- model_summary %>% filter(mean_brier == min(mean_brier, na.rm = TRUE))
cat(sprintf("\n  Best model: %s\n", best_model$model[1]))
cat(sprintf("    Brier: %.4f, AUC: %.3f\n", best_model$mean_brier[1], best_model$mean_auc[1]))

cat("\nOutputs:\n")
cat("  - cross_validation_results.csv (all CV results)\n")
cat("  - cv_performance_summary.csv (summary by method)\n")
cat("  - cv_model_comparison.csv (model selection results)\n")
cat("  - cv_*.png visualizations\n")
