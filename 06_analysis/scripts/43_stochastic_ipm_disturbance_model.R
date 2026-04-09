#!/usr/bin/env Rscript
################################################################################
# 43_STOCHASTIC_IPM_DISTURBANCE_MODEL.R
# Disturbance-driven stochastic IPM approximation for A. palmata
################################################################################
#
# PURPOSE:
#   Extend viability analysis beyond the static matrix by building a stochastic
#   size-structured IPM approximation where annual kernels are conditioned on
#   disturbance regime (none, context, baseline-exclusion, catastrophic).
#
# APPROACH:
#   1. Fit regime-aware survival and growth vital-rate models on natural colonies
#   2. Add explicit recruitment/fecundity scenarios anchored to retained life-history
#      parameters (maturity threshold, settlement success, post-settlement survival)
#   3. Convert fitted vital rates into regime-specific IPM kernels
#   3. Estimate deterministic lambda for each regime-specific kernel
#   4. Simulate 50-year trajectories with environmental stochasticity:
#      - Markov regime switching from observed year-to-year transitions
#      - IID regime draws from empirical frequencies
#      - No-disturbance counterfactual (none kernel only)
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#
# OUTPUTS (prefix: stochastic_ipm_):
#   - 06_analysis/output/stochastic_ipm_model_diagnostics.csv
#   - 06_analysis/output/stochastic_ipm_recruitment_scenarios.csv
#   - 06_analysis/output/stochastic_ipm_regime_kernel_lambdas.csv
#   - 06_analysis/output/stochastic_ipm_regime_transition_matrix.csv
#   - 06_analysis/output/stochastic_ipm_year_regime_series.csv
#   - 06_analysis/output/stochastic_ipm_projection_quantiles.csv
#   - 06_analysis/output/stochastic_ipm_simulation_summary.csv
#   - 06_analysis/figures/supplementary/stochastic_ipm_projection_trajectories.png
#   - 06_analysis/figures/supplementary/stochastic_ipm_projection_trajectories.pdf
################################################################################

if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
} else if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else {
  stop("Cannot locate shared utilities.")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(mgcv)
})

set.seed(43)

print_header("43: STOCHASTIC DISTURBANCE-DRIVEN IPM")
cat("  Building regime-conditioned IPM kernels and stochastic projections\n\n")

project_root <- get_project_root()
dirs <- setup_output_dirs(project_root)
output_dir <- dirs$output
supp_dir <- dirs$figures_supp
dir.create(supp_dir, showWarnings = FALSE, recursive = TRUE)
pal <- MANUSCRIPT_PALETTE

surv_file <- file.path(output_dir, "prepared_survival_data.rds")
growth_file <- file.path(output_dir, "prepared_growth_data.rds")
life_history_file <- file.path(project_root, "05_data/standardized/apal_life_history_parameters_analysis.csv")

if (!file.exists(surv_file)) stop("Missing file: ", surv_file)
if (!file.exists(growth_file)) stop("Missing file: ", growth_file)

surv_raw <- readRDS(surv_file)
growth_raw <- readRDS(growth_file)

life_history <- if (file.exists(life_history_file)) {
  readr::read_csv(life_history_file, show_col_types = FALSE)
} else {
  tibble::tibble()
}

# ==============================================================================
# 1) PREPARE NATURAL-COLONY PANEL DATA
# ==============================================================================

print_subheader("Section 1: Preparing panel data")

derive_regime_class <- function(df) {
  df %>%
    mutate(
      regime_class = case_when(
        isTRUE(is_catastrophic) | (!is.na(is_catastrophic) & is_catastrophic) ~ "catastrophic",
        isTRUE(exclude_from_baseline) | (!is.na(exclude_from_baseline) & exclude_from_baseline) ~ "baseline_exclusion",
        !is.na(timeline_event_count) & timeline_event_count > 0 ~ "context_only",
        TRUE ~ "none"
      )
    )
}

surv_nat <- surv_raw %>%
  filter(population_type == "Natural colony") %>%
  filter(is.finite(size_for_class), size_for_class > 0) %>%
  filter(is.finite(survived)) %>%
  filter(is.finite(time_interval_yr), time_interval_yr >= 0.5, time_interval_yr <= 1.5) %>%
  derive_regime_class() %>%
  mutate(
    regime_class = as.character(regime_class),
    log_size = log(size_for_class)
  )

growth_metric_vec <- if ("growth_live_cm2_yr" %in% names(growth_raw)) {
  dplyr::coalesce(growth_raw$growth_live_cm2_yr, growth_raw$growth_metric, growth_raw$growth_cm2_yr)
} else {
  dplyr::coalesce(growth_raw$growth_metric, growth_raw$growth_cm2_yr)
}

growth_nat <- growth_raw %>%
  mutate(growth_for_ipm = growth_metric_vec) %>%
  filter(fragment == "N") %>%
  filter(is.finite(size_for_class), size_for_class > 0) %>%
  filter(is.finite(growth_for_ipm)) %>%
  filter(is.finite(time_interval_yr), time_interval_yr >= 0.5, time_interval_yr <= 1.5) %>%
  filter(!ifelse("impossible_growth" %in% names(.), impossible_growth, FALSE)) %>%
  derive_regime_class() %>%
  mutate(
    regime_class = as.character(regime_class),
    size_next_cm2 = pmax(size_for_class + growth_for_ipm, 0.1),
    log_size = log(size_for_class),
    log_size_next = log(size_next_cm2),
    delta_log_size = log_size_next - log_size
  )

cat(sprintf("  Survival rows (natural, near-annual): %s\n", scales::comma(nrow(surv_nat))))
cat(sprintf("  Growth rows (natural, near-annual): %s\n", scales::comma(nrow(growth_nat))))

# Keep regime levels represented in both survival and growth data
surv_regimes <- sort(unique(surv_nat$regime_class))
growth_regimes <- sort(unique(growth_nat$regime_class))
regime_levels <- intersect(surv_regimes, growth_regimes)

if (length(regime_levels) < 2) {
  stop("Insufficient common regime levels in natural survival and growth data.")
}

surv_nat <- surv_nat %>%
  filter(regime_class %in% regime_levels) %>%
  mutate(regime_class = factor(regime_class, levels = regime_levels))

growth_nat <- growth_nat %>%
  filter(regime_class %in% regime_levels) %>%
  mutate(regime_class = factor(regime_class, levels = regime_levels))

surv_regime_counts <- table(surv_nat$regime_class)
growth_regime_counts <- table(growth_nat$regime_class)

cat("  Regime counts in survival data:\n")
print(surv_regime_counts)
cat("  Regime counts in growth data:\n")
print(growth_regime_counts)

# Recruitment/fecundity scenarios are explicitly scenario-based rather than fully
# empirically calibrated. They use retained life-history anchors to avoid a
# zero-recruitment viability model while keeping assumptions transparent.
maturity_threshold_cm2 <- life_history %>%
  filter(Parameter == "maturity_threshold") %>%
  pull(Value) %>%
  .[1]
maturity_threshold_cm2 <- suppressWarnings(as.numeric(maturity_threshold_cm2))
if (!is.finite(maturity_threshold_cm2)) maturity_threshold_cm2 <- 4000

settlement_baseline <- life_history %>%
  filter(Parameter == "settlement_success", Sub_Category == "thermal_baseline") %>%
  pull(Value) %>%
  .[1]
settlement_baseline <- suppressWarnings(as.numeric(settlement_baseline))
settlement_baseline <- settlement_baseline / 100
if (!is.finite(settlement_baseline)) settlement_baseline <- 0.62

settlement_stress <- life_history %>%
  filter(Parameter == "settlement_success", Sub_Category == "thermal_stress") %>%
  pull(Value) %>%
  .[1]
settlement_stress <- suppressWarnings(as.numeric(settlement_stress))
settlement_stress <- settlement_stress / 100
if (!is.finite(settlement_stress)) settlement_stress <- 0.37

post_settlement_survival <- life_history %>%
  filter(Parameter == "post_settlement_mortality") %>%
  pull(Value) %>%
  .[1]
post_settlement_survival <- suppressWarnings(as.numeric(post_settlement_survival))
post_settlement_survival <- if (is.finite(post_settlement_survival)) 1 - post_settlement_survival / 100 else 0.14

recruitment_scenarios <- tibble(
  recruitment_scenario = c("zero", "conservative", "optimistic"),
  annual_recruits_per_mature_colony = c(
    0,
    0.02 * settlement_stress * post_settlement_survival,
    0.05 * settlement_baseline * post_settlement_survival
  ),
  settlement_success = c(0, settlement_stress, settlement_baseline),
  post_settlement_survival = c(0, post_settlement_survival, post_settlement_survival),
  maturity_threshold_cm2 = maturity_threshold_cm2,
  calibration_basis = c(
    "No recruitment term; survival+growth only baseline",
    "Scenario-scaled direct recruitment under thermal-stress settlement conditions",
    "Scenario-scaled direct recruitment under baseline settlement conditions"
  )
)

write_csv(
  recruitment_scenarios,
  file.path(output_dir, "stochastic_ipm_recruitment_scenarios.csv")
)

# ==============================================================================
# 2) FIT REGIME-CONDITIONED VITAL RATE MODELS
# ==============================================================================

print_subheader("Section 2: Fitting vital rate models")

surv_formula_full <- survived ~ regime_class + s(log_size, k = 7) + s(log_size, by = regime_class, k = 5)
surv_formula_add <- survived ~ regime_class + s(log_size, k = 7)

surv_model <- tryCatch(
  gam(surv_formula_full, data = surv_nat, family = binomial(link = "logit"),
      method = "REML", select = TRUE),
  error = function(e) {
    print_warn("Full interaction survival GAM failed; falling back to additive smooth.")
    gam(surv_formula_add, data = surv_nat, family = binomial(link = "logit"),
        method = "REML", select = TRUE)
  }
)

growth_formula_full <- delta_log_size ~ regime_class + s(log_size, k = 7) + s(log_size, by = regime_class, k = 5)
growth_formula_add <- delta_log_size ~ regime_class + s(log_size, k = 7)

growth_model <- tryCatch(
  gam(growth_formula_full, data = growth_nat, family = gaussian(),
      method = "REML", select = TRUE),
  error = function(e) {
    print_warn("Full interaction growth GAM failed; falling back to additive smooth.")
    gam(growth_formula_add, data = growth_nat, family = gaussian(),
        method = "REML", select = TRUE)
  }
)

growth_resid <- growth_nat %>%
  mutate(resid = residuals(growth_model, type = "response")) %>%
  group_by(regime_class) %>%
  summarise(
    sigma_resid = sd(resid, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  mutate(sigma_resid = ifelse(!is.finite(sigma_resid) | sigma_resid < 0.05, 0.05, sigma_resid))

sigma_lookup <- stats::setNames(growth_resid$sigma_resid, growth_resid$regime_class)

diag_tbl <- tibble(
  row_type = "model",
  model = c("survival_gam", "growth_gam"),
  formula = c(
    paste(deparse(formula(surv_model)), collapse = " "),
    paste(deparse(formula(growth_model)), collapse = " ")
  ),
  n = c(nrow(surv_nat), nrow(growth_nat)),
  aic = c(AIC(surv_model), AIC(growth_model)),
  deviance_explained = c(
    ifelse(!is.null(summary(surv_model)$dev.expl), summary(surv_model)$dev.expl, NA_real_),
    ifelse(!is.null(summary(growth_model)$dev.expl), summary(growth_model)$dev.expl, NA_real_)
  ),
  annual_recruits_per_mature_colony = NA_real_,
  settlement_post_survival_product = NA_real_
)

diag_tbl <- bind_rows(
  diag_tbl,
  tibble(
    row_type = "recruitment_scenario",
    model = paste0("recruitment_scenario:", recruitment_scenarios$recruitment_scenario),
    formula = recruitment_scenarios$calibration_basis,
    n = NA_real_,
    aic = NA_real_,
    deviance_explained = NA_real_,
    annual_recruits_per_mature_colony = recruitment_scenarios$annual_recruits_per_mature_colony,
    settlement_post_survival_product = recruitment_scenarios$settlement_success * recruitment_scenarios$post_settlement_survival
  )
)

write_csv(diag_tbl, file.path(output_dir, "stochastic_ipm_model_diagnostics.csv"))

# ==============================================================================
# 3) BUILD REGIME-SPECIFIC IPM KERNELS
# ==============================================================================

print_subheader("Section 3: Building IPM kernels")

z_all <- c(surv_nat$log_size, growth_nat$log_size, growth_nat$log_size_next)
z_min <- as.numeric(stats::quantile(z_all, 0.01, na.rm = TRUE)) - 0.25
z_max <- as.numeric(stats::quantile(z_all, 0.99, na.rm = TRUE)) + 0.25
n_mesh <- 140L
z_mesh <- seq(z_min, z_max, length.out = n_mesh)
dz <- z_mesh[2] - z_mesh[1]

build_kernel <- function(regime_label) {
  pred_df <- data.frame(
    log_size = z_mesh,
    regime_class = factor(regime_label, levels = regime_levels)
  )

  surv_pred <- predict(surv_model, newdata = pred_df, type = "response")
  surv_pred <- pmin(pmax(surv_pred, 1e-4), 0.9999)
  delta_pred <- predict(growth_model, newdata = pred_df, type = "response")
  sigma <- sigma_lookup[[as.character(regime_label)]]
  if (!is.finite(sigma)) sigma <- stats::sd(residuals(growth_model), na.rm = TRUE)
  if (!is.finite(sigma) || sigma < 0.05) sigma <- 0.05

  P <- matrix(0, nrow = n_mesh, ncol = n_mesh)
  for (i in seq_len(n_mesh)) {
    mu_next <- z_mesh[i] + delta_pred[i]
    dens <- dnorm(z_mesh, mean = mu_next, sd = sigma)
    mass <- sum(dens) * dz
    if (is.finite(mass) && mass > 0) {
      dens <- dens / mass
    }
    P[, i] <- surv_pred[i] * dens * dz
  }

  mature_prob <- plogis((z_mesh - log(maturity_threshold_cm2)) / 0.25)
  recruit_density <- dnorm(z_mesh, mean = max(z_min + 0.15, log(1)), sd = 0.35)
  recruit_mass <- sum(recruit_density) * dz
  recruit_density <- recruit_density / recruit_mass

  lapply(seq_len(nrow(recruitment_scenarios)), function(idx) {
    recruitment_scalar <- recruitment_scenarios$annual_recruits_per_mature_colony[idx]
    fecundity_vec <- recruitment_scalar * mature_prob
    F <- outer(recruit_density * dz, fecundity_vec)
    P + F
  }) |>
    stats::setNames(recruitment_scenarios$recruitment_scenario)
}

dominant_lambda <- function(K) {
  vals <- eigen(K, only.values = TRUE)$values
  Re(vals[which.max(Mod(vals))])
}

stable_distribution <- function(K) {
  eig <- eigen(K)
  idx <- which.max(Mod(eig$values))
  w <- Re(eig$vectors[, idx])
  w[w < 0] <- 0
  if (sum(w) == 0) {
    w <- rep(1 / length(w), length(w))
  } else {
    w <- w / sum(w)
  }
  w
}

kernel_nested <- lapply(regime_levels, build_kernel)
names(kernel_nested) <- regime_levels
kernel_grid <- expand.grid(
  regime_class = regime_levels,
  recruitment_scenario = recruitment_scenarios$recruitment_scenario,
  stringsAsFactors = FALSE
)

kernel_list <- lapply(seq_len(nrow(kernel_grid)), function(i) {
  kernel_nested[[kernel_grid$regime_class[i]]][[kernel_grid$recruitment_scenario[i]]]
})
names(kernel_list) <- paste(kernel_grid$regime_class, kernel_grid$recruitment_scenario, sep = "__")

lambda_tbl <- kernel_grid %>%
  mutate(
    kernel_key = paste(regime_class, recruitment_scenario, sep = "__"),
    lambda_kernel = vapply(kernel_key, function(k) dominant_lambda(kernel_list[[k]]), numeric(1)),
    sigma_growth = unname(sigma_lookup[regime_class]),
    n_survival = as.integer(surv_regime_counts[regime_class]),
    n_growth = as.integer(growth_regime_counts[regime_class]),
    annual_recruits_per_mature_colony = recruitment_scenarios$annual_recruits_per_mature_colony[
      match(recruitment_scenario, recruitment_scenarios$recruitment_scenario)
    ]
  )

write_csv(lambda_tbl, file.path(output_dir, "stochastic_ipm_regime_kernel_lambdas.csv"))

# ==============================================================================
# 4) YEAR-LEVEL REGIME PROCESS (MARKOV CHAIN)
# ==============================================================================

print_subheader("Section 4: Regime process and transition matrix")

regime_priority <- c("none" = 1, "context_only" = 2, "baseline_exclusion" = 3, "catastrophic" = 4)

year_regime <- surv_nat %>%
  count(survey_yr, regime_class, name = "n") %>%
  group_by(survey_yr) %>%
  arrange(desc(n), desc(regime_priority[as.character(regime_class)]), .by_group = TRUE) %>%
  slice(1) %>%
  ungroup() %>%
  arrange(survey_yr) %>%
  mutate(regime_class = as.character(regime_class))

write_csv(year_regime, file.path(output_dir, "stochastic_ipm_year_regime_series.csv"))

state_levels <- regime_levels
alpha <- 0.5
trans_counts <- matrix(alpha, nrow = length(state_levels), ncol = length(state_levels),
                       dimnames = list(state_levels, state_levels))

if (nrow(year_regime) >= 2) {
  from_states <- year_regime$regime_class[-nrow(year_regime)]
  to_states <- year_regime$regime_class[-1]
  for (k in seq_along(from_states)) {
    trans_counts[from_states[k], to_states[k]] <- trans_counts[from_states[k], to_states[k]] + 1
  }
}

trans_probs <- trans_counts / rowSums(trans_counts)

trans_tbl <- as.data.frame(trans_probs) %>%
  tibble::rownames_to_column("from_regime") %>%
  pivot_longer(-from_regime, names_to = "to_regime", values_to = "transition_prob")

write_csv(trans_tbl, file.path(output_dir, "stochastic_ipm_regime_transition_matrix.csv"))

# ==============================================================================
# 5) STOCHASTIC PROJECTIONS
# ==============================================================================

print_subheader("Section 5: Stochastic projections")

n_years <- 50L
n_sims <- 800L
n0_total <- 1000
qext_threshold <- 0.05 * n0_total

start_regime <- if ("none" %in% state_levels) "none" else year_regime$regime_class[1]
n0_dist <- stable_distribution(kernel_list[[paste(start_regime, "zero", sep = "__")]])
n0_vec <- n0_dist * n0_total

simulate_path <- function(mode = c("markov", "iid", "none_only"),
                          recruitment_scenario = "zero") {
  mode <- match.arg(mode)
  N <- numeric(n_years + 1)
  N[1] <- sum(n0_vec)
  pop_vec <- n0_vec
  state <- start_regime
  states_used <- character(n_years)

  empirical_weights <- as.numeric(table(factor(year_regime$regime_class, levels = state_levels)))
  if (sum(empirical_weights) > 0) empirical_weights <- empirical_weights / sum(empirical_weights)

  for (t in seq_len(n_years)) {
    if (mode == "none_only") {
      state <- if ("none" %in% state_levels) "none" else state_levels[1]
    } else if (mode == "iid") {
      state <- sample(state_levels, size = 1, prob = empirical_weights)
    } else {
      state <- sample(state_levels, size = 1, prob = trans_probs[state, ])
    }

    states_used[t] <- state
    kernel_key <- paste(state, recruitment_scenario, sep = "__")
    pop_vec <- as.vector(kernel_list[[kernel_key]] %*% pop_vec)
    N[t + 1] <- sum(pop_vec)
  }

  data.frame(
    year = 0:n_years,
    total_population = N,
    scenario = mode,
    recruitment_scenario = recruitment_scenario,
    path_regime_start = start_regime,
    stringsAsFactors = FALSE
  ) %>%
    mutate(
      effective_lambda = ifelse(year == 0, NA_real_, (total_population / total_population[1])^(1 / year)),
      final_regime = tail(states_used, 1)
    )
}

sim_modes <- c("markov", "iid", "none_only")
all_paths <- vector("list", length(sim_modes))
names(all_paths) <- sim_modes

for (m in sim_modes) {
  mode_paths <- vector("list", n_sims * nrow(recruitment_scenarios))
  idx <- 1L
  for (r in recruitment_scenarios$recruitment_scenario) {
    for (s in seq_len(n_sims)) {
      mode_paths[[idx]] <- simulate_path(m, recruitment_scenario = r) %>% mutate(sim = s)
      idx <- idx + 1L
    }
  }
  all_paths[[m]] <- bind_rows(mode_paths)
}

projection_paths <- bind_rows(all_paths)

quantiles_tbl <- projection_paths %>%
  group_by(scenario, recruitment_scenario, year) %>%
  summarise(
    n = n(),
    mean_population = mean(total_population, na.rm = TRUE),
    median_population = median(total_population, na.rm = TRUE),
    q05 = quantile(total_population, 0.05, na.rm = TRUE),
    q25 = quantile(total_population, 0.25, na.rm = TRUE),
    q75 = quantile(total_population, 0.75, na.rm = TRUE),
    q95 = quantile(total_population, 0.95, na.rm = TRUE),
    .groups = "drop"
  )

summary_tbl <- projection_paths %>%
  filter(year == n_years) %>%
  group_by(scenario, recruitment_scenario) %>%
  summarise(
    n_sims = n(),
    final_mean = mean(total_population, na.rm = TRUE),
    final_median = median(total_population, na.rm = TRUE),
    final_q05 = quantile(total_population, 0.05, na.rm = TRUE),
    final_q95 = quantile(total_population, 0.95, na.rm = TRUE),
    p_quasi_extinction = mean(total_population <= qext_threshold, na.rm = TRUE),
    lambda_stochastic = mean((total_population / n0_total)^(1 / n_years), na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    qext_threshold = qext_threshold,
    start_population = n0_total,
    annual_recruits_per_mature_colony = recruitment_scenarios$annual_recruits_per_mature_colony[
      match(recruitment_scenario, recruitment_scenarios$recruitment_scenario)
    ]
  )

write_csv(quantiles_tbl, file.path(output_dir, "stochastic_ipm_projection_quantiles.csv"))
write_csv(summary_tbl, file.path(output_dir, "stochastic_ipm_simulation_summary.csv"))

# ==============================================================================
# 6) FIGURE
# ==============================================================================

print_subheader("Section 6: Figure export")

scenario_labels <- c(
  markov = "Observed Markov Regime Switching",
  iid = "IID Regime Draws (Empirical Frequencies)",
  none_only = "No-Disturbance Counterfactual"
)

recruitment_labels <- c(
  zero = "Zero Recruitment",
  conservative = "Conservative Recruitment",
  optimistic = "Optimistic Recruitment"
)

plot_df <- quantiles_tbl %>%
  mutate(
    scenario_label = scenario_labels[scenario],
    scenario_label = factor(scenario_label, levels = unname(scenario_labels)),
    recruitment_label = recruitment_labels[recruitment_scenario],
    recruitment_label = factor(recruitment_label, levels = unname(recruitment_labels))
  )

p <- ggplot(plot_df, aes(x = year, y = median_population, color = scenario_label, fill = scenario_label)) +
  geom_ribbon(aes(ymin = q05, ymax = q95), alpha = 0.14, linewidth = 0, show.legend = FALSE) +
  geom_line(linewidth = 1.0) +
  scale_color_manual(values = c(pal$surv_dark, pal$grow_mid, pal$accent)) +
  scale_fill_manual(values = c(pal$surv_dark, pal$grow_mid, pal$accent)) +
  labs(
    title = "Stochastic IPM Projections Under Disturbance Regimes",
    subtitle = "Regime-conditioned kernels with explicit recruitment scenarios",
    x = "Projection year",
    y = "Total abundance index (N)",
    color = "Scenario"
  ) +
  facet_wrap(~ recruitment_label) +
  theme_manuscript()

ggsave(
  file.path(supp_dir, "stochastic_ipm_projection_trajectories.png"),
  plot = p, width = 180, height = 120, units = "mm", dpi = 300
)
ggsave(
  file.path(supp_dir, "stochastic_ipm_projection_trajectories.pdf"),
  plot = p, width = 180, height = 120, units = "mm"
)

# ==============================================================================
# 7) CONSOLE SUMMARY
# ==============================================================================

print_subheader("Section 7: Summary")
print(summary_tbl)

cat("\nSaved outputs:\n")
cat("  - stochastic_ipm_model_diagnostics.csv\n")
cat("  - stochastic_ipm_recruitment_scenarios.csv\n")
cat("  - stochastic_ipm_regime_kernel_lambdas.csv\n")
cat("  - stochastic_ipm_regime_transition_matrix.csv\n")
cat("  - stochastic_ipm_year_regime_series.csv\n")
cat("  - stochastic_ipm_projection_quantiles.csv\n")
cat("  - stochastic_ipm_simulation_summary.csv\n")
cat("  - stochastic_ipm_projection_trajectories.png/.pdf\n\n")

cat("Done.\n")
