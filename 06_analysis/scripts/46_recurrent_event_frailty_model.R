#!/usr/bin/env Rscript
################################################################################
# 46_RECURRENT_EVENT_FRAILTY_MODEL.R
# Recurrent shrinkage and dynamic frailty survival analysis for A. palmata
################################################################################
#
# PURPOSE:
#   Extend beyond static GLMMs by fitting:
#   1) A recurrent-event hazard model for repeated shrinkage intervals
#   2) A terminal-event mortality hazard model with time-varying shrinkage history
#   Both models include disturbance-state exposure and colony-level frailty.
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#
# OUTPUTS (all prefixed recurrent_event_):
#   - 06_analysis/output/recurrent_event_panel_summary.csv
#   - 06_analysis/output/recurrent_event_colony_history.csv
#   - 06_analysis/output/recurrent_event_shrinkage_model.csv
#   - 06_analysis/output/recurrent_event_mortality_model.csv
#   - 06_analysis/output/recurrent_event_model_fit.csv
#   - 06_analysis/output/recurrent_event_dynamic_risk_profiles.csv
#   - 06_analysis/output/recurrent_event_frailty_estimates.csv (if available)
#
# NOTES:
#   - Time is represented as start-stop intervals using time_interval_yr.
#   - Disturbance state follows the curated baseline-exclusion logic:
#     no disturbance, context-only pressure, acute baseline-exclusion.
#   - If frailty optimization fails, script falls back to cluster-robust Cox models.
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(tibble)
  library(survival)
})

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

if (!exists("setup_output_dirs")) {
  stop("setup_output_dirs() not found. Run from project root or 06_analysis/scripts.")
}

dirs <- setup_output_dirs()
output_dir <- dirs$output

print_header("46: RECURRENT EVENT + DYNAMIC FRAILTY MODELS")
cat("  Modeling repeated shrinkage and terminal mortality with disturbance exposure\n\n")

surv_path <- file.path(output_dir, "prepared_survival_data.rds")
growth_path <- file.path(output_dir, "prepared_growth_data.rds")

if (!file.exists(surv_path) || !file.exists(growth_path)) {
  stop("Prepared survival/growth datasets not found. Run data prep pipeline first.")
}

surv_data <- readRDS(surv_path)
growth_data <- readRDS(growth_path)

make_disturbance_state <- function(exclude_from_baseline, timeline_event_count) {
  case_when(
    coalesce(exclude_from_baseline, FALSE) ~ "Acute baseline-exclusion",
    !coalesce(exclude_from_baseline, FALSE) & coalesce(timeline_event_count, 0L) > 0L ~ "Context-only pressure",
    TRUE ~ "No curated disturbance"
  )
}

clean_interval <- function(x) {
  x <- coalesce(as.numeric(x), 1)
  ifelse(is.na(x) | x <= 0, 1, x)
}

extract_cox_table <- function(model, outcome, model_variant) {
  beta <- stats::coef(model)
  if (is.null(beta) || length(beta) == 0) {
    return(tibble(
      outcome = outcome,
      model_variant = model_variant,
      term = NA_character_,
      estimate = NA_real_,
      std_error = NA_real_,
      hazard_ratio = NA_real_,
      ci_lower = NA_real_,
      ci_upper = NA_real_,
      z_value = NA_real_,
      p_value = NA_real_
    ))
  }

  vc <- as.matrix(stats::vcov(model))
  terms <- names(beta)
  se <- sqrt(diag(vc))[terms]
  z <- as.numeric(beta / se)

  tibble(
    outcome = outcome,
    model_variant = model_variant,
    term = terms,
    estimate = as.numeric(beta),
    std_error = as.numeric(se),
    hazard_ratio = exp(estimate),
    ci_lower = exp(estimate - 1.96 * std_error),
    ci_upper = exp(estimate + 1.96 * std_error),
    z_value = z,
    p_value = 2 * pnorm(abs(z), lower.tail = FALSE)
  )
}

extract_fit_metrics <- function(model, outcome, model_variant) {
  s <- summary(model)

  concordance <- NA_real_
  concordance_se <- NA_real_
  if (!is.null(s$concordance) && length(s$concordance) >= 2) {
    concordance <- as.numeric(s$concordance[1])
    concordance_se <- as.numeric(s$concordance[2])
  }

  frailty_theta <- NA_real_
  frailty_key <- grep("frailty", names(model$history), value = TRUE)
  if (length(frailty_key) > 0) {
    hist_obj <- model$history[[frailty_key[1]]]
    if (is.list(hist_obj) && "theta" %in% names(hist_obj)) {
      frailty_theta <- as.numeric(hist_obj$theta)
    } else if (is.numeric(hist_obj) && length(hist_obj) > 0) {
      frailty_theta <- as.numeric(tail(hist_obj, 1))
    }
  }

  tibble(
    outcome = outcome,
    model_variant = model_variant,
    n_rows = model$n,
    n_events = model$nevent,
    concordance = concordance,
    concordance_se = concordance_se,
    log_likelihood = tryCatch(as.numeric(logLik(model)), error = function(e) NA_real_),
    aic = tryCatch(AIC(model), error = function(e) NA_real_),
    frailty_theta = frailty_theta
  )
}

fit_with_fallback <- function(primary_formula, fallback_formula, data, label) {
  primary <- tryCatch(
    coxph(
      primary_formula,
      data = data,
      ties = "efron",
      control = coxph.control(iter.max = 100),
      model = TRUE, x = TRUE, y = TRUE
    ),
    error = function(e) e
  )

  if (!inherits(primary, "error")) {
    return(list(model = primary, variant = "frailty", error_message = NA_character_))
  }

  cat(sprintf("  Frailty fit failed for %s; falling back to cluster-robust Cox model\n", label))
  fallback <- coxph(
    fallback_formula,
    data = data,
    ties = "efron",
    control = coxph.control(iter.max = 100),
    model = TRUE, x = TRUE, y = TRUE
  )
  list(model = fallback, variant = "cluster_robust", error_message = as.character(primary$message))
}

print_subheader("Building recurrent-event panel")

growth_join <- growth_data %>%
  transmute(
    study,
    coral_id,
    survey_yr,
    colony_uid = paste(study, coral_id, sep = "::"),
    growth_metric
  ) %>%
  group_by(colony_uid, survey_yr) %>%
  summarise(
    growth_metric = dplyr::first(growth_metric),
    .groups = "drop"
  )

panel <- surv_data %>%
  mutate(
    colony_uid = paste(study, coral_id, sep = "::"),
    interval_yr = clean_interval(time_interval_yr),
    disturbance_state = factor(
      make_disturbance_state(exclude_from_baseline, timeline_event_count),
      levels = c("No curated disturbance", "Context-only pressure", "Acute baseline-exclusion")
    )
  ) %>%
  left_join(growth_join, by = c("colony_uid", "survey_yr")) %>%
  filter(
    !is.na(colony_uid),
    !is.na(study),
    !is.na(survived),
    !is.na(size_for_class)
  ) %>%
  arrange(colony_uid, survey_yr) %>%
  group_by(colony_uid) %>%
  mutate(
    interval_end = cumsum(interval_yr),
    interval_start = interval_end - interval_yr,
    death_event_raw = as.integer(survived == 0),
    death_order = cumsum(death_event_raw),
    keep_row = death_order <= 1,
    death_event = if_else(death_event_raw == 1 & death_order == 1, 1L, 0L),
    shrink_event = case_when(
      !is.na(growth_metric) & growth_metric < 0 ~ 1L,
      !is.na(growth_metric) & growth_metric >= 0 ~ 0L,
      TRUE ~ NA_integer_
    ),
    shrink_event_filled = coalesce(shrink_event, 0L),
    shrink_observed = as.integer(!is.na(shrink_event)),
    prior_shrink_events = lag(cumsum(shrink_event_filled), default = 0L),
    prior_any_shrink = as.integer(prior_shrink_events > 0),
    recent_shrink_lag1 = lag(shrink_event_filled, default = 0L),
    cumulative_tissue_loss = lag(
      cumsum(if_else(growth_metric < 0, abs(growth_metric), 0, missing = 0)),
      default = 0
    ),
    log_size = log(pmax(size_for_class, 1))
  ) %>%
  ungroup() %>%
  filter(keep_row)

panel_summary <- tibble(
  n_rows = nrow(panel),
  n_colonies = n_distinct(panel$colony_uid),
  n_studies = n_distinct(panel$study),
  n_regions = n_distinct(panel$region),
  death_events = sum(panel$death_event, na.rm = TRUE),
  shrinkage_intervals_observed = sum(panel$shrink_observed, na.rm = TRUE),
  shrinkage_events = sum(panel$shrink_event_filled, na.rm = TRUE),
  pct_intervals_with_shrinkage = mean(panel$shrink_event_filled[panel$shrink_observed == 1], na.rm = TRUE) * 100,
  mean_followup_years = mean(panel$interval_end, na.rm = TRUE),
  median_followup_years = median(panel$interval_end, na.rm = TRUE)
)

colony_history <- panel %>%
  group_by(colony_uid, study, region, population_type) %>%
  summarise(
    n_intervals = n(),
    followup_years = max(interval_end, na.rm = TRUE),
    death_event = max(death_event, na.rm = TRUE),
    shrink_events = sum(shrink_event_filled, na.rm = TRUE),
    ever_shrunk = as.integer(shrink_events > 0),
    mean_timeline_events = mean(timeline_event_count, na.rm = TRUE),
    prop_acute_exposure = mean(coalesce(exclude_from_baseline, FALSE), na.rm = TRUE),
    .groups = "drop"
  )

write_csv(panel_summary, file.path(output_dir, "recurrent_event_panel_summary.csv"))
write_csv(colony_history, file.path(output_dir, "recurrent_event_colony_history.csv"))
print_success("Saved recurrent_event_panel_summary.csv")
print_success("Saved recurrent_event_colony_history.csv")

print_subheader("Fitting recurrent shrinkage frailty model")

shrink_panel <- panel %>%
  filter(
    shrink_observed == 1,
    interval_end > interval_start,
    !is.na(disturbance_state),
    !is.na(population_type),
    !is.na(log_size)
  )

if (sum(shrink_panel$shrink_event_filled, na.rm = TRUE) < 20) {
  stop("Too few shrinkage events after filtering to fit recurrent model.")
}

shrink_formula_frailty <- as.formula(
  "Surv(interval_start, interval_end, shrink_event_filled) ~
   log_size + disturbance_state + prior_shrink_events + population_type +
   frailty(colony_uid, distribution = 'gamma') + strata(study)"
)

shrink_formula_cluster <- as.formula(
  "Surv(interval_start, interval_end, shrink_event_filled) ~
   log_size + disturbance_state + prior_shrink_events + population_type +
   cluster(colony_uid) + strata(study)"
)

shrink_fit <- fit_with_fallback(
  primary_formula = shrink_formula_frailty,
  fallback_formula = shrink_formula_cluster,
  data = shrink_panel,
  label = "recurrent shrinkage"
)

print_subheader("Fitting mortality frailty model with dynamic shrinkage history")

mortality_panel <- panel %>%
  filter(
    interval_end > interval_start,
    !is.na(disturbance_state),
    !is.na(population_type),
    !is.na(log_size)
  )

if (sum(mortality_panel$death_event, na.rm = TRUE) < 20) {
  stop("Too few mortality events after filtering to fit hazard model.")
}

mortality_formula_frailty <- as.formula(
  "Surv(interval_start, interval_end, death_event) ~
   log_size + disturbance_state + prior_shrink_events +
   recent_shrink_lag1 + prior_any_shrink +
   frailty(colony_uid, distribution = 'gamma') + strata(study)"
)

mortality_formula_cluster <- as.formula(
  "Surv(interval_start, interval_end, death_event) ~
   log_size + disturbance_state + prior_shrink_events +
   recent_shrink_lag1 + prior_any_shrink +
   cluster(colony_uid) + strata(study)"
)

mortality_fit <- fit_with_fallback(
  primary_formula = mortality_formula_frailty,
  fallback_formula = mortality_formula_cluster,
  data = mortality_panel,
  label = "terminal mortality"
)

shrink_table <- extract_cox_table(shrink_fit$model, "recurrent_shrinkage", shrink_fit$variant)
mortality_table <- extract_cox_table(mortality_fit$model, "terminal_mortality", mortality_fit$variant)

fit_table <- bind_rows(
  extract_fit_metrics(shrink_fit$model, "recurrent_shrinkage", shrink_fit$variant),
  extract_fit_metrics(mortality_fit$model, "terminal_mortality", mortality_fit$variant)
) %>%
  mutate(
    frailty_error_message = case_when(
      outcome == "recurrent_shrinkage" ~ shrink_fit$error_message,
      outcome == "terminal_mortality" ~ mortality_fit$error_message,
      TRUE ~ NA_character_
    )
  )

write_csv(shrink_table, file.path(output_dir, "recurrent_event_shrinkage_model.csv"))
write_csv(mortality_table, file.path(output_dir, "recurrent_event_mortality_model.csv"))
write_csv(fit_table, file.path(output_dir, "recurrent_event_model_fit.csv"))
print_success("Saved recurrent_event_shrinkage_model.csv")
print_success("Saved recurrent_event_mortality_model.csv")
print_success("Saved recurrent_event_model_fit.csv")

print_subheader("Summarizing dynamic risk profiles")

risk_profiles <- mortality_panel %>%
  mutate(
    prior_shrink_bin = case_when(
      prior_shrink_events <= 0 ~ "0",
      prior_shrink_events == 1 ~ "1",
      prior_shrink_events == 2 ~ "2",
      prior_shrink_events >= 3 ~ "3+",
      TRUE ~ NA_character_
    )
  ) %>%
  group_by(disturbance_state, prior_shrink_bin, population_type) %>%
  summarise(
    n_intervals = n(),
    deaths = sum(death_event, na.rm = TRUE),
    death_rate = deaths / n_intervals,
    .groups = "drop"
  ) %>%
  arrange(population_type, disturbance_state, prior_shrink_bin)

write_csv(risk_profiles, file.path(output_dir, "recurrent_event_dynamic_risk_profiles.csv"))
print_success("Saved recurrent_event_dynamic_risk_profiles.csv")

make_frailty_df <- function(f, outcome) {
  if (is.null(f) || length(f) == 0) {
    return(tibble())
  }

  vals <- as.numeric(f)
  ids <- names(f)

  if ((is.null(ids) || length(ids) == 0 || all(ids == "")) &&
      !is.null(dimnames(f)) && length(dimnames(f)) > 0) {
    ids <- dimnames(f)[[1]]
  }

  if (is.null(ids) || length(ids) != length(vals)) {
    return(tibble())
  }

  tibble(
    colony_uid = ids,
    outcome = outcome,
    frailty_effect = vals
  )
}

frailty_estimates <- bind_rows(
  make_frailty_df(shrink_fit$model$frail, "recurrent_shrinkage"),
  make_frailty_df(mortality_fit$model$frail, "terminal_mortality")
)

if (nrow(frailty_estimates) > 0 && "colony_uid" %in% names(frailty_estimates)) {
  frailty_estimates <- frailty_estimates %>%
    left_join(
      colony_history %>% select(colony_uid, study, region, population_type, n_intervals, shrink_events, death_event),
      by = "colony_uid"
    )
}

if (nrow(frailty_estimates) == 0) {
  frailty_estimates <- tibble(
    colony_uid = character(),
    outcome = character(),
    frailty_effect = numeric(),
    study = character(),
    region = character(),
    population_type = character(),
    n_intervals = integer(),
    shrink_events = integer(),
    death_event = integer()
  )
}

write_csv(frailty_estimates, file.path(output_dir, "recurrent_event_frailty_estimates.csv"))
print_success("Saved recurrent_event_frailty_estimates.csv")

cat("\nModel overview:\n")
cat(sprintf("  Recurrent shrinkage rows: %d | events: %d | variant: %s\n",
            nrow(shrink_panel), sum(shrink_panel$shrink_event_filled, na.rm = TRUE), shrink_fit$variant))
cat(sprintf("  Mortality rows: %d | deaths: %d | variant: %s\n",
            nrow(mortality_panel), sum(mortality_panel$death_event, na.rm = TRUE), mortality_fit$variant))

cat("\nDone.\n")
