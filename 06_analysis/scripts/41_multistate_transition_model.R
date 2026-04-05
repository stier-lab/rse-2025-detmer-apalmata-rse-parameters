#!/usr/bin/env Rscript
################################################################################
# 41_MULTISTATE_TRANSITION_MODEL.R
# First-pass multistate transition analysis for Acropora palmata
################################################################################
#
# PURPOSE
#   Build a reproducible multistate demographic model that extends beyond
#   static transition counts by:
#     1) modeling interval-adjusted death hazard from survival panel data, and
#     2) modeling alive-state transitions among SC1-SC5 from growth-linked data.
#
#   The model explicitly handles irregular interval lengths via:
#     - complementary log-log hazard with log(interval) offset (death process)
#     - log(interval) covariate in conditional alive transition model
#
# INPUTS
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#
# OUTPUTS (all prefixed `multistate_`)
#   - 06_analysis/output/multistate_dataset_summary.csv
#   - 06_analysis/output/multistate_survival_model_coefficients.csv
#   - 06_analysis/output/multistate_alive_transition_model_coefficients.csv
#   - 06_analysis/output/multistate_survival_state_predictions.csv
#   - 06_analysis/output/multistate_alive_transition_predictions.csv
#   - 06_analysis/output/multistate_transition_matrix_annual.csv
#   - 06_analysis/output/multistate_transition_matrix_annual_wide.csv
#   - 06_analysis/output/multistate_retrogression_metrics.csv
#   - 06_analysis/output/multistate_observed_alive_transition_counts.csv
#   - 06_analysis/output/multistate_observed_death_by_state.csv
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(lme4)
  library(nnet)
})

# ------------------------------------------------------------------------------
# Shared utilities and paths
# ------------------------------------------------------------------------------
if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
} else if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else {
  stop("Cannot locate shared_utilities.R")
}

dirs <- setup_output_dirs()
output_dir <- dirs$output

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  41: MULTISTATE TRANSITION MODEL                             ║\n")
cat("║  SC1-SC5 alive transitions + absorbing death state           ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

size_states <- SIZE_LABELS
all_states <- c(size_states, "Dead")

# ------------------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------------------
pick_reference_level <- function(x, preferred = NULL) {
  lv <- unique(as.character(x[!is.na(x)]))
  if (length(lv) == 0) return(NA_character_)
  if (!is.null(preferred) && preferred %in% lv) return(preferred)
  lv[1]
}

safe_factor <- function(x, levels = NULL) {
  x <- as.character(x)
  if (!is.null(levels)) {
    factor(x, levels = levels)
  } else {
    factor(x)
  }
}

normalize_row <- function(x) {
  s <- sum(x, na.rm = TRUE)
  if (!is.finite(s) || s <= 0) return(rep(0, length(x)))
  as.numeric(x / s)
}

flatten_multinom_coef <- function(m) {
  sm <- summary(m)
  cf <- sm$coefficients
  se <- sm$standard.errors
  out <- list()
  for (k in seq_len(nrow(cf))) {
    outcome <- rownames(cf)[k]
    tmp <- data.frame(
      outcome_state = outcome,
      term = colnames(cf),
      estimate = as.numeric(cf[k, ]),
      std_error = as.numeric(se[k, ]),
      stringsAsFactors = FALSE
    )
    tmp$z_value <- tmp$estimate / tmp$std_error
    tmp$p_value <- 2 * pnorm(abs(tmp$z_value), lower.tail = FALSE)
    out[[k]] <- tmp
  }
  bind_rows(out)
}

# ------------------------------------------------------------------------------
# Load prepared data
# ------------------------------------------------------------------------------
surv_path <- file.path(output_dir, "prepared_survival_data.rds")
growth_path <- file.path(output_dir, "prepared_growth_data.rds")

if (!file.exists(surv_path) || !file.exists(growth_path)) {
  stop("Required prepared data RDS files not found in 06_analysis/output/")
}

surv_raw <- readRDS(surv_path)
growth_raw <- readRDS(growth_path)

cat(sprintf("Loaded survival records: %s\n", scales::comma(nrow(surv_raw))))
cat(sprintf("Loaded growth records:   %s\n\n", scales::comma(nrow(growth_raw))))

# ------------------------------------------------------------------------------
# Survival panel preparation (for death hazard)
# ------------------------------------------------------------------------------
surv <- surv_raw %>%
  filter(
    !is.na(survived),
    !is.na(size_for_class),
    !is.na(time_interval_yr),
    time_interval_yr > 0
  ) %>%
  mutate(
    state_from = assign_size_class(size_for_class, labels = "standard"),
    dead = 1L - as.integer(survived)
  ) %>%
  filter(!is.na(state_from))

# Restrict to natural colonies where possible, matching core matrix logic
if ("population_type" %in% names(surv)) {
  surv <- surv %>% filter(population_type == "Natural colony")
} else if ("fragment" %in% names(surv)) {
  surv <- surv %>% filter(fragment == "N")
}

# Keep near-annual intervals to reduce interval extrapolation bias
surv <- surv %>%
  filter(time_interval_yr >= 0.5, time_interval_yr <= 1.5)

# Harmonize covariates for stable first-pass model
surv <- surv %>%
  mutate(
    disturbance_regime = if_else(is.na(disturbance_regime), "none", disturbance_regime),
    disturbance_regime = str_to_lower(disturbance_regime),
    disturbance_regime = if_else(disturbance_regime %in% c("none", "storm", "sargassum", "pollution", "compound"),
                                 disturbance_regime, "compound"),
    disturbance_any = if_else(disturbance_regime == "none", "none", "any"),
    geo_domain = if_else(region_group == "Florida", "Florida", "NonFlorida"),
    log_interval = log(time_interval_yr),
    state_from = safe_factor(state_from, levels = size_states),
    disturbance_any = factor(disturbance_any, levels = c("none", "any")),
    geo_domain = safe_factor(geo_domain),
    study = safe_factor(study)
  ) %>%
  filter(!is.na(state_from), !is.na(study))

cat(sprintf("Survival analysis rows (post-filter): %s\n", scales::comma(nrow(surv))))
cat("Survival rows by state_from:\n")
print(as.data.frame(table(surv$state_from)))
cat("\n")

# ------------------------------------------------------------------------------
# Growth-linked alive transition panel
# ------------------------------------------------------------------------------
growth <- growth_raw %>%
  filter(
    !is.na(size_for_class),
    !is.na(growth_metric),
    !is.na(time_interval_yr),
    time_interval_yr > 0
  )

if ("population_type" %in% names(growth)) {
  growth <- growth %>% filter(population_type == "Natural colony")
} else if ("fragment" %in% names(growth)) {
  growth <- growth %>% filter(fragment == "N")
}

if ("impossible_growth" %in% names(growth)) {
  growth <- growth %>% filter(!impossible_growth)
}

growth <- growth %>%
  filter(time_interval_yr >= 0.5, time_interval_yr <= 1.5) %>%
  mutate(
    state_from = assign_size_class(size_for_class, labels = "standard"),
    size_final_cm2 = pmax(size_for_class + growth_metric * time_interval_yr, 0.1),
    state_to_alive = assign_size_class(size_final_cm2, labels = "standard")
  ) %>%
  filter(!is.na(state_from), !is.na(state_to_alive))

# Join to survival endpoint; keep only intervals where colony survived
join_keys <- c("study", "coral_id", "survey_yr")
join_keys <- join_keys[join_keys %in% names(growth) & join_keys %in% names(surv)]

if (length(join_keys) < 3) {
  stop("Could not build robust growth-survival join keys (study/coral_id/survey_yr).")
}

transition_alive <- growth %>%
  inner_join(
    surv %>% select(all_of(join_keys), survived, disturbance_regime, geo_domain),
    by = join_keys,
    suffix = c("", "_surv")
  ) %>%
  filter(survived == 1) %>%
  mutate(
    disturbance_regime = if ("disturbance_regime_surv" %in% names(.)) disturbance_regime_surv else disturbance_regime,
    disturbance_any = if_else(disturbance_regime == "none", "none", "any"),
    geo_domain = geo_domain
  ) %>%
  select(-matches("^disturbance_regime_surv$"), -survived) %>%
  mutate(
    log_interval = log(time_interval_yr),
    state_from = safe_factor(state_from, levels = size_states),
    state_to_alive = safe_factor(state_to_alive, levels = size_states),
    disturbance_any = factor(disturbance_any, levels = c("none", "any")),
    geo_domain = safe_factor(geo_domain)
  )

cat(sprintf("Alive-transition rows (growth linked): %s\n", scales::comma(nrow(transition_alive))))
cat("Alive-transition rows by state_from:\n")
print(as.data.frame(table(transition_alive$state_from)))
cat("\n")

# ------------------------------------------------------------------------------
# Dataset summary
# ------------------------------------------------------------------------------
dataset_summary <- bind_rows(
  surv %>%
    summarise(
      dataset = "survival_panel",
      n_rows = n(),
      n_studies = n_distinct(study),
      n_regions = n_distinct(region),
      interval_min = min(time_interval_yr, na.rm = TRUE),
      interval_median = median(time_interval_yr, na.rm = TRUE),
      interval_max = max(time_interval_yr, na.rm = TRUE)
    ),
  transition_alive %>%
    summarise(
      dataset = "alive_transition_panel",
      n_rows = n(),
      n_studies = n_distinct(study),
      n_regions = n_distinct(region),
      interval_min = min(time_interval_yr, na.rm = TRUE),
      interval_median = median(time_interval_yr, na.rm = TRUE),
      interval_max = max(time_interval_yr, na.rm = TRUE)
    )
)

write_csv(dataset_summary, file.path(output_dir, "multistate_dataset_summary.csv"))

# ------------------------------------------------------------------------------
# Model 1: Interval-adjusted death hazard (complementary log-log)
# ------------------------------------------------------------------------------
cat("Fitting death hazard model...\n")

surv_fit <- tryCatch(
  glmer(
    dead ~ state_from + disturbance_any + geo_domain +
      offset(log(time_interval_yr)) + (1 | study),
    family = binomial(link = "cloglog"),
    data = surv,
    control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
  ),
  error = function(e) {
    message("glmer failed; falling back to fixed-effect cloglog glm: ", e$message)
    glm(
      dead ~ state_from + disturbance_any + geo_domain + study +
        offset(log(time_interval_yr)),
      family = binomial(link = "cloglog"),
      data = surv
    )
  }
)

surv_coef <- as.data.frame(coef(summary(surv_fit)))
surv_coef$term <- rownames(surv_coef)
rownames(surv_coef) <- NULL
names(surv_coef) <- c("estimate", "std_error", "z_value", "p_value", "term")
surv_coef <- surv_coef %>% select(term, estimate, std_error, z_value, p_value)
write_csv(surv_coef, file.path(output_dir, "multistate_survival_model_coefficients.csv"))

ref_dist <- pick_reference_level(surv$disturbance_any, preferred = "none")
ref_geo <- pick_reference_level(surv$geo_domain, preferred = "Florida")

new_surv <- data.frame(
  state_from = factor(size_states, levels = levels(surv$state_from)),
  disturbance_any = factor(rep(ref_dist, length(size_states)), levels = levels(surv$disturbance_any)),
  geo_domain = factor(rep(ref_geo, length(size_states)), levels = levels(surv$geo_domain)),
  time_interval_yr = 1
)

dead_prob_annual <- as.numeric(
  predict(surv_fit, newdata = new_surv, type = "response", re.form = NA)
)

surv_pred <- data.frame(
  state_from = size_states,
  reference_disturbance = ref_dist,
  reference_geodomain = ref_geo,
  annual_dead_probability = dead_prob_annual,
  annual_survival_probability = 1 - dead_prob_annual
)
write_csv(surv_pred, file.path(output_dir, "multistate_survival_state_predictions.csv"))

# ------------------------------------------------------------------------------
# Model 2: Conditional alive-state transitions (multinomial)
# ------------------------------------------------------------------------------
cat("Fitting conditional alive-state multinomial model...\n")

trans_fit <- tryCatch(
  nnet::multinom(
    state_to_alive ~ state_from + disturbance_any + geo_domain + log_interval,
    data = transition_alive,
    trace = FALSE,
    MaxNWts = 5000,
    decay = 1e-3
  ),
  error = function(e) {
    message("Full multinom failed; falling back to reduced formula: ", e$message)
    nnet::multinom(
      state_to_alive ~ state_from + log_interval,
      data = transition_alive,
      trace = FALSE,
      MaxNWts = 5000,
      decay = 1e-3
    )
  }
)

trans_coef <- flatten_multinom_coef(trans_fit)
write_csv(trans_coef, file.path(output_dir, "multistate_alive_transition_model_coefficients.csv"))

new_trans <- data.frame(
  state_from = factor(size_states, levels = levels(transition_alive$state_from)),
  disturbance_any = factor(rep(ref_dist, length(size_states)),
                           levels = levels(transition_alive$disturbance_any)),
  geo_domain = factor(rep(ref_geo, length(size_states)),
                      levels = levels(transition_alive$geo_domain)),
  log_interval = 0
)

# If reduced model was used, remove extraneous columns from newdata for predict
needed_terms <- attr(terms(trans_fit), "term.labels")
if (!"disturbance_any" %in% needed_terms) new_trans$disturbance_any <- NULL
if (!"geo_domain" %in% needed_terms) new_trans$geo_domain <- NULL
if (!"log_interval" %in% needed_terms) new_trans$log_interval <- NULL

alive_probs <- predict(trans_fit, newdata = new_trans, type = "probs")
if (is.vector(alive_probs)) {
  alive_probs <- matrix(alive_probs, nrow = 1)
}
alive_probs <- as.data.frame(alive_probs)

# Ensure all alive destination states are present
for (st in size_states) {
  if (!st %in% names(alive_probs)) alive_probs[[st]] <- 0
}
alive_probs <- alive_probs[, size_states, drop = FALSE]
alive_probs[] <- lapply(alive_probs, as.numeric)
alive_probs <- as.data.frame(t(apply(alive_probs, 1, normalize_row)))
names(alive_probs) <- size_states

alive_pred <- bind_cols(
  data.frame(
    state_from = size_states,
    reference_disturbance = ref_dist,
    reference_geodomain = ref_geo
  ),
  alive_probs
)

write_csv(alive_pred, file.path(output_dir, "multistate_alive_transition_predictions.csv"))

# ------------------------------------------------------------------------------
# Compose annual multistate transition matrix (SC1-SC5 + Dead)
# ------------------------------------------------------------------------------
cat("Composing annual multistate transition matrix...\n")

P <- matrix(0, nrow = length(all_states), ncol = length(all_states),
            dimnames = list(to_state = all_states, from_state = all_states))

for (i in seq_along(size_states)) {
  st <- size_states[i]
  s_prob <- surv_pred$annual_survival_probability[surv_pred$state_from == st]
  dest_vec <- as.numeric(alive_probs[i, size_states, drop = TRUE])
  dest_vec <- normalize_row(dest_vec)

  P[size_states, st] <- s_prob * dest_vec
  P["Dead", st] <- 1 - s_prob
}
P["Dead", "Dead"] <- 1

P_long <- as.data.frame(as.table(P)) %>%
  rename(to_state = to_state, from_state = from_state, probability = Freq) %>%
  mutate(
    from_state = as.character(from_state),
    to_state = as.character(to_state)
  )

write_csv(P_long, file.path(output_dir, "multistate_transition_matrix_annual.csv"))
write_csv(
  as.data.frame(P, row.names = TRUE) %>% mutate(to_state = rownames(P), .before = 1),
  file.path(output_dir, "multistate_transition_matrix_annual_wide.csv")
)

# ------------------------------------------------------------------------------
# Retrogression/progression metrics from composed annual matrix
# ------------------------------------------------------------------------------
cat("Computing retrogression metrics...\n")

retro_metrics <- lapply(seq_along(size_states), function(i) {
  st <- size_states[i]
  s_prob <- surv_pred$annual_survival_probability[surv_pred$state_from == st]
  alive_row <- as.numeric(alive_probs[i, size_states, drop = TRUE])

  idx_back <- seq_len(i - 1)
  idx_same <- i
  idx_forward <- if (i < length(size_states)) (i + 1):length(size_states) else integer(0)

  p_back_cond <- if (length(idx_back) > 0) sum(alive_row[idx_back]) else 0
  p_same_cond <- alive_row[idx_same]
  p_forward_cond <- if (length(idx_forward) > 0) sum(alive_row[idx_forward]) else 0

  data.frame(
    state_from = st,
    annual_survival_probability = s_prob,
    annual_death_probability = 1 - s_prob,
    p_backward_given_alive = p_back_cond,
    p_stasis_given_alive = p_same_cond,
    p_forward_given_alive = p_forward_cond,
    p_backward_unconditional = s_prob * p_back_cond,
    p_stasis_unconditional = s_prob * p_same_cond,
    p_forward_unconditional = s_prob * p_forward_cond,
    stringsAsFactors = FALSE
  )
})

retro_metrics <- bind_rows(retro_metrics)
write_csv(retro_metrics, file.path(output_dir, "multistate_retrogression_metrics.csv"))

# ------------------------------------------------------------------------------
# Observed data summaries for interpretation
# ------------------------------------------------------------------------------
obs_alive <- transition_alive %>%
  count(state_from, state_to_alive, name = "n") %>%
  group_by(state_from) %>%
  mutate(
    row_total = sum(n),
    p_observed = n / row_total
  ) %>%
  ungroup()

write_csv(obs_alive, file.path(output_dir, "multistate_observed_alive_transition_counts.csv"))

obs_death <- surv %>%
  group_by(state_from) %>%
  summarise(
    n_intervals = n(),
    n_deaths = sum(dead, na.rm = TRUE),
    raw_interval_death_rate = n_deaths / n_intervals,
    median_interval_years = median(time_interval_yr, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(obs_death, file.path(output_dir, "multistate_observed_death_by_state.csv"))

# ------------------------------------------------------------------------------
# Basic diagnostics table
# ------------------------------------------------------------------------------
diag_tbl <- data.frame(
  metric = c(
    "survival_model_class",
    "transition_model_class",
    "AIC_survival_model",
    "AIC_transition_model",
    "reference_disturbance",
    "reference_geodomain"
  ),
  value = c(
    class(surv_fit)[1],
    class(trans_fit)[1],
    as.character(AIC(surv_fit)),
    as.character(AIC(trans_fit)),
    ref_dist,
    ref_geo
  )
)
write_csv(diag_tbl, file.path(output_dir, "multistate_model_diagnostics.csv"))

cat("\nSaved multistate outputs:\n")
cat("  - multistate_dataset_summary.csv\n")
cat("  - multistate_survival_model_coefficients.csv\n")
cat("  - multistate_alive_transition_model_coefficients.csv\n")
cat("  - multistate_survival_state_predictions.csv\n")
cat("  - multistate_alive_transition_predictions.csv\n")
cat("  - multistate_transition_matrix_annual.csv\n")
cat("  - multistate_transition_matrix_annual_wide.csv\n")
cat("  - multistate_retrogression_metrics.csv\n")
cat("  - multistate_observed_alive_transition_counts.csv\n")
cat("  - multistate_observed_death_by_state.csv\n")
cat("  - multistate_model_diagnostics.csv\n\n")

cat("41_multistate_transition_model.R completed.\n")
