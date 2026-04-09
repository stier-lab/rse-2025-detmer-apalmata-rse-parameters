#!/usr/bin/env Rscript
################################################################################
# 42_JOINT_LONGITUDINAL_SURVIVAL_MODEL.R
# Two-Stage Joint Longitudinal-Survival Analysis for A. palmata
################################################################################
#
# PURPOSE:
#   Extend beyond standard GLMMs by linking colony live-size trajectories
#   (longitudinal process) to interval mortality risk (survival process).
#
# MODEL STRATEGY:
#   Stage 1: Mixed-effects longitudinal model for log(live tissue area + 1)
#   Stage 2: Discrete-time hazard model (cloglog link with interval offset)
#            using Stage-1 latent trajectory summaries:
#              - Predicted latent size at interval start
#              - Predicted latent trajectory velocity across interval
#
# NOTE:
#   JMbayes2/JM/joineR packages are not required and may be unavailable in this
#   environment. This script uses a rigorous two-stage approximation instead.
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#
# OUTPUTS (prefixed joint_longitudinal_):
#   - 06_analysis/output/joint_longitudinal_model_coefficients.csv
#   - 06_analysis/output/joint_longitudinal_fit_metrics.csv
#   - 06_analysis/output/joint_longitudinal_calibration_by_decile.csv
#   - 06_analysis/output/joint_longitudinal_key_results.csv
#   - 06_analysis/output/joint_longitudinal_interval_predictions.csv
#   - 06_analysis/figures/supplementary/joint_longitudinal_risk_curve.png
#
# Author: Detmer & Stier Lab
# Date: 2026-04-03
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(nlme)
  library(survival)
})

# Optional, preferred for clustered hazard model
has_glmmTMB <- requireNamespace("glmmTMB", quietly = TRUE)

`%||%` <- function(a, b) if (!is.null(a)) a else b

detect_project_root <- function() {
  if (file.exists("06_analysis/output/prepared_survival_data.rds")) {
    return(".")
  }
  if (file.exists("../../06_analysis/output/prepared_survival_data.rds")) {
    return("../..")
  }
  stop("Cannot find project root. Run from project root or 06_analysis/scripts/")
}

calc_auc <- function(y, p) {
  keep <- is.finite(y) & is.finite(p)
  y <- y[keep]
  p <- p[keep]
  n1 <- sum(y == 1)
  n0 <- sum(y == 0)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  r <- rank(p, ties.method = "average")
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

cat("\n")
cat("====================================================================\n")
cat(" 42: JOINT LONGITUDINAL-SURVIVAL MODEL (TWO-STAGE)\n")
cat("====================================================================\n\n")

project_root <- detect_project_root()
output_dir <- file.path(project_root, "06_analysis/output")
fig_dir <- file.path(project_root, "06_analysis/figures/supplementary")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

surv_path <- file.path(output_dir, "prepared_survival_data.rds")
growth_path <- file.path(output_dir, "prepared_growth_data.rds")

if (!file.exists(surv_path) || !file.exists(growth_path)) {
  stop("Prepared data files not found. Run 01_data_preparation.R first.")
}

surv_data <- readRDS(surv_path)
growth_data <- readRDS(growth_path)

key_cols <- c("study", "region", "location", "plot", "coral_id", "survey_yr")
missing_surv <- setdiff(key_cols, names(surv_data))
missing_growth <- setdiff(key_cols, names(growth_data))
if (length(missing_surv) > 0 || length(missing_growth) > 0) {
  stop("Missing key columns in prepared data.")
}

growth_join <- growth_data %>%
  select(
    all_of(key_cols),
    growth_cm2_yr,
    growth_live_cm2_yr,
    rgr
  )

analysis_df <- surv_data %>%
  left_join(growth_join, by = key_cols) %>%
  mutate(
    survey_yr = as.numeric(survey_yr),
    time_interval_yr = as.numeric(time_interval_yr),
    year_start = survey_yr,
    year_end = survey_yr + time_interval_yr,
    dead = as.integer(survived == 0),
    log_live_size = log1p(pmax(size_live_cm2, 0)),
    pop_type = population_type %||% ifelse(fragment == "Y", "Restoration fragment", "Natural colony"),
    disturbance_state = disturbance_regime %||% "none",
    disturbance_state = ifelse(is.na(disturbance_state) | disturbance_state == "", "none", disturbance_state),
    disturbance_state = factor(disturbance_state),
    pop_type = factor(pop_type)
  ) %>%
  filter(
    is.finite(log_live_size),
    is.finite(time_interval_yr),
    time_interval_yr > 0,
    time_interval_yr <= 5,
    !is.na(dead),
    !is.na(coral_id),
    !is.na(study),
    !is.na(region)
  )

min_year <- min(analysis_df$year_start, na.rm = TRUE)
analysis_df <- analysis_df %>%
  mutate(
    year_center = year_start - min_year,
    year_center_end = year_end - min_year
  )

cat(sprintf("Prepared intervals: %d\n", nrow(analysis_df)))
cat(sprintf("Unique colonies: %d\n", n_distinct(analysis_df$coral_id)))
cat(sprintf("Deaths: %d (%.1f%%)\n\n", sum(analysis_df$dead), 100 * mean(analysis_df$dead)))

# ============================================================================
# Stage 1: Longitudinal model
# ============================================================================
cat("Fitting Stage 1 longitudinal model...\n")

longitudinal_formula <- log_live_size ~ year_center + I(year_center^2) + disturbance_state + pop_type

fit_longitudinal <- function(df) {
  # Try random intercept + slope first, but downgrade if numerically unstable
  slope_warnings <- character(0)
  m1 <- withCallingHandlers(
    try(
      nlme::lme(
        fixed = longitudinal_formula,
        random = ~ year_center | coral_id,
        data = df,
        method = "REML",
        na.action = na.omit,
        control = nlme::lmeControl(msMaxIter = 200, opt = "optim")
      ),
      silent = TRUE
    ),
    warning = function(w) {
      slope_warnings <<- c(slope_warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  slope_unstable <- any(grepl("singular precision matrix", slope_warnings, ignore.case = TRUE))
  if (!inherits(m1, "try-error") && !slope_unstable) {
    return(list(
      model = m1,
      random_structure = "random_intercept_slope",
      downgrade_reason = NA_character_
    ))
  }

  m2 <- nlme::lme(
    fixed = longitudinal_formula,
    random = ~ 1 | coral_id,
    data = df,
    method = "REML",
    na.action = na.omit,
    control = nlme::lmeControl(msMaxIter = 200, opt = "optim")
  )
  reason <- if (inherits(m1, "try-error")) {
    "slope_model_failed_to_converge"
  } else {
    "slope_model_singular_precision_matrix"
  }
  list(model = m2, random_structure = "random_intercept_only", downgrade_reason = reason)
}

long_fit <- fit_longitudinal(analysis_df)
long_model <- long_fit$model

cat(sprintf("Longitudinal random structure: %s\n", long_fit$random_structure))
if (!is.na(long_fit$downgrade_reason)) {
  cat(sprintf("Longitudinal downgrade reason: %s\n", long_fit$downgrade_reason))
}

analysis_df$pred_log_live_start <- as.numeric(
  predict(long_model, newdata = analysis_df, level = 1)
)

pred_end_df <- analysis_df %>% mutate(year_center = year_center_end)
analysis_df$pred_log_live_end <- as.numeric(
  predict(long_model, newdata = pred_end_df, level = 1)
)

analysis_df <- analysis_df %>%
  mutate(
    pred_log_live_velocity = (pred_log_live_end - pred_log_live_start) / time_interval_yr,
    z_pred_log_live = as.numeric(scale(pred_log_live_start)),
    z_pred_velocity = as.numeric(scale(pred_log_live_velocity)),
    z_year = as.numeric(scale(year_start)),
    log_dt = log(time_interval_yr)
  )

# ============================================================================
# Stage 2: Hazard model
# ============================================================================
cat("Fitting Stage 2 hazard model...\n")

haz_formula_fixed <- dead ~ z_pred_log_live + z_pred_velocity +
  disturbance_state + pop_type + z_year + region + offset(log_dt)

hazard_model <- NULL
hazard_engine <- NULL

if (has_glmmTMB) {
  hazard_try <- try(
    glmmTMB::glmmTMB(
      formula = dead ~ z_pred_log_live + z_pred_velocity +
        disturbance_state + pop_type + z_year + region +
        offset(log_dt) + (1 | coral_id) + (1 | study),
      data = analysis_df,
      family = binomial(link = "cloglog")
    ),
    silent = TRUE
  )

  if (!inherits(hazard_try, "try-error")) {
    hazard_model <- hazard_try
    hazard_engine <- "glmmTMB"
  }
}

if (is.null(hazard_model)) {
  hazard_model <- glm(
    formula = haz_formula_fixed,
    data = analysis_df,
    family = binomial(link = "cloglog")
  )
  hazard_engine <- "glm"
}

cat(sprintf("Hazard engine: %s\n", hazard_engine))

analysis_df$p_dead_hat <- as.numeric(predict(hazard_model, type = "response"))
analysis_df$p_dead_hat <- pmin(pmax(analysis_df$p_dead_hat, 1e-8), 1 - 1e-8)

# ============================================================================
# Outputs: coefficients and fit metrics
# ============================================================================

long_tt <- as.data.frame(summary(long_model)$tTable)
long_tt$term <- rownames(long_tt)
rownames(long_tt) <- NULL

long_coef_out <- long_tt %>%
  transmute(
    model = "longitudinal_lme",
    term = term,
    estimate = Value,
    std_error = `Std.Error`,
    statistic = `t-value`,
    p_value = `p-value`,
    effect_type = "mean_log_live_size",
    hazard_ratio = NA_real_
  )

if (hazard_engine == "glmmTMB") {
  hz <- as.data.frame(summary(hazard_model)$coefficients$cond)
  hz$term <- rownames(hz)
  rownames(hz) <- NULL
  hazard_coef_out <- hz %>%
    transmute(
      model = "hazard_cloglog_glmmTMB",
      term = term,
      estimate = Estimate,
      std_error = `Std. Error`,
      statistic = `z value`,
      p_value = `Pr(>|z|)`,
      effect_type = "log_hazard_ratio",
      hazard_ratio = exp(Estimate)
    )
} else {
  hz <- as.data.frame(summary(hazard_model)$coefficients)
  hz$term <- rownames(hz)
  rownames(hz) <- NULL
  hazard_coef_out <- hz %>%
    transmute(
      model = "hazard_cloglog_glm",
      term = term,
      estimate = Estimate,
      std_error = `Std. Error`,
      statistic = `z value`,
      p_value = `Pr(>|z|)`,
      effect_type = "log_hazard_ratio",
      hazard_ratio = exp(Estimate)
    )
}

coef_out <- bind_rows(long_coef_out, hazard_coef_out)
write_csv(coef_out, file.path(output_dir, "joint_longitudinal_model_coefficients.csv"))

brier <- mean((analysis_df$dead - analysis_df$p_dead_hat)^2, na.rm = TRUE)
auc <- calc_auc(analysis_df$dead, analysis_df$p_dead_hat)

fit_metrics <- tibble(
  metric = c(
    "n_intervals",
    "n_colonies",
    "n_studies",
    "event_rate",
    "brier_score",
    "auc",
    "longitudinal_aic",
    "longitudinal_bic",
    "longitudinal_logLik",
    "longitudinal_downgrade_reason",
    "longitudinal_random_structure",
    "hazard_aic",
    "hazard_bic",
    "hazard_logLik",
    "hazard_engine",
    "hazard_model_class"
  ),
  value = c(
    nrow(analysis_df),
    n_distinct(analysis_df$coral_id),
    n_distinct(analysis_df$study),
    mean(analysis_df$dead),
    brier,
    auc,
    AIC(long_model),
    BIC(long_model),
    as.numeric(logLik(long_model)),
    long_fit$downgrade_reason %||% NA_character_,
    long_fit$random_structure,
    AIC(hazard_model),
    BIC(hazard_model),
    as.numeric(logLik(hazard_model)),
    hazard_engine,
    class(hazard_model)[1]
  )
)
write_csv(fit_metrics, file.path(output_dir, "joint_longitudinal_fit_metrics.csv"))

calibration <- analysis_df %>%
  mutate(risk_decile = ntile(p_dead_hat, 10L)) %>%
  group_by(risk_decile) %>%
  summarise(
    n = n(),
    observed_dead_rate = mean(dead),
    predicted_dead_rate = mean(p_dead_hat),
    .groups = "drop"
  )
write_csv(calibration, file.path(output_dir, "joint_longitudinal_calibration_by_decile.csv"))

key_terms <- hazard_coef_out %>%
  filter(term %in% c("z_pred_log_live", "z_pred_velocity")) %>%
  mutate(
    interpretation = case_when(
      term == "z_pred_log_live" ~ "1 SD higher latent live size at interval start",
      term == "z_pred_velocity" ~ "1 SD higher latent live-size velocity (log-scale per year)",
      TRUE ~ term
    )
  ) %>%
  select(term, interpretation, estimate, std_error, statistic, p_value, hazard_ratio)
write_csv(key_terms, file.path(output_dir, "joint_longitudinal_key_results.csv"))

pred_export <- analysis_df %>%
  select(
    study, region, location, plot, coral_id, survey_yr,
    time_interval_yr, dead, survived,
    pred_log_live_start, pred_log_live_velocity, p_dead_hat,
    disturbance_state, pop_type
  )
write_csv(pred_export, file.path(output_dir, "joint_longitudinal_interval_predictions.csv"))

# ============================================================================
# Visualization
# ============================================================================
cat("Building risk-curve visualization...\n")

ref_disturbance <- levels(analysis_df$disturbance_state)
if (length(ref_disturbance) == 0) ref_disturbance <- "none"

region_mode <- names(sort(table(analysis_df$region), decreasing = TRUE))[1]
study_mode <- names(sort(table(analysis_df$study), decreasing = TRUE))[1]
coral_mode <- analysis_df$coral_id[which.max(tabulate(match(analysis_df$coral_id, unique(analysis_df$coral_id))))]

risk_grid <- expand.grid(
  z_pred_log_live = seq(-2.5, 2.5, length.out = 100),
  disturbance_state = ref_disturbance,
  stringsAsFactors = FALSE
) %>%
  mutate(
    z_pred_velocity = 0,
    z_year = 0,
    pop_type = levels(analysis_df$pop_type)[1],
    region = region_mode,
    log_dt = log(1),
    time_interval_yr = 1,
    coral_id = coral_mode,
    study = study_mode
  )

risk_grid$disturbance_state <- factor(
  risk_grid$disturbance_state,
  levels = levels(analysis_df$disturbance_state)
)
risk_grid$pop_type <- factor(risk_grid$pop_type, levels = levels(analysis_df$pop_type))
risk_grid$region <- factor(risk_grid$region, levels = levels(factor(analysis_df$region)))
risk_grid$study <- factor(risk_grid$study, levels = levels(factor(analysis_df$study)))

if (hazard_engine == "glmmTMB") {
  risk_grid$pred_dead <- as.numeric(
    predict(hazard_model, newdata = risk_grid, type = "response", re.form = NA, allow.new.levels = TRUE)
  )
} else {
  risk_grid$pred_dead <- as.numeric(
    predict(hazard_model, newdata = risk_grid, type = "response")
  )
}

p <- ggplot(risk_grid, aes(x = z_pred_log_live, y = pred_dead, color = disturbance_state)) +
  geom_line(linewidth = 1) +
  labs(
    title = "Joint Longitudinal-Survival Risk Curve",
    subtitle = "Predicted interval mortality vs latent live-size state (velocity fixed at mean)",
    x = "Latent live-size state (z-score, Stage 1 prediction)",
    y = "Predicted probability of death over 1-year interval",
    color = "Disturbance regime"
  ) +
  theme_bw(base_size = 12)

ggsave(
  filename = file.path(fig_dir, "joint_longitudinal_risk_curve.png"),
  plot = p,
  width = 9,
  height = 5.5,
  dpi = 300
)

cat("\nSaved outputs:\n")
cat("  - joint_longitudinal_model_coefficients.csv\n")
cat("  - joint_longitudinal_fit_metrics.csv\n")
cat("  - joint_longitudinal_calibration_by_decile.csv\n")
cat("  - joint_longitudinal_key_results.csv\n")
cat("  - joint_longitudinal_interval_predictions.csv\n")
cat("  - joint_longitudinal_risk_curve.png\n")
cat("\nDone.\n")
