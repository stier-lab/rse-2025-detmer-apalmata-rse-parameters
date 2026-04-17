#!/usr/bin/env Rscript
################################################################################
# 40_MANZELLO_HEATWAVE_SCENARIOS.R
# Catastrophic Heatwave Scenario Analysis for A. palmata Population Model
################################################################################
#
# PURPOSE:
#   Integrate Manzello et al. (2025, Science) dose-response mortality data
#   with our size-structured population model to project population dynamics
#   under recurring catastrophic heatwave scenarios. This bridges our
#   pre-collapse demographic synthesis (chronic regime vital rates) with
#   the empirical reality of extreme thermal events that overwhelm
#   size-dependent survival.
#
# BACKGROUND:
#   Manzello et al. (2025) documented the functional extinction of A. palmata
#   from Florida's Coral Reef after the 2023 marine heatwave:
#     - 97.8-100% mortality in FL Keys and Dry Tortugas
#     - ED50 = 7.8 DHW (50% mortality)
#     - ED95 = 17.6 DHW (95% mortality)
#     - Mortality onset ~3 DHW
#     - Acute heat shock at hotspot anomalies >= +2°C
#   These thresholds define the thermal ceiling for A. palmata persistence.
#
# APPROACH:
#   1. Parameterize a logistic dose-response function from Manzello's
#      ED50 and ED95 values
#   2. Define heatwave severity scenarios (moderate, severe, catastrophic)
#   3. Project population trajectories under different return intervals
#      using our Lefkovitch matrix with periodic catastrophic mortality pulses
#   4. Calculate scenario-specific lambda, quasi-extinction probability,
#      and recovery time
#
# SCENARIOS:
#   - Baseline: no heatwave (deterministic projection with our matrix)
#   - Moderate bleaching: ~8 DHW (~50% mortality) every N years
#   - Severe bleaching: ~12 DHW (~80% mortality) every N years
#   - Catastrophic (2023-scale): ~18 DHW (~98% mortality) every N years
#   Return intervals tested: 5, 10, 20, 50 years
#
# INPUTS:
#   - 06_analysis/output/transition_matrix.rds (Lefkovitch matrix A)
#   - 06_analysis/output/population_parameters.csv (lambda, elasticities)
#   - 06_analysis/output/lambda_bootstrap_samples.rds (for uncertainty)
#
# OUTPUTS:
#   - 06_analysis/output/manzello_dose_response.csv
#   - 06_analysis/output/heatwave_scenario_projections.csv
#   - 06_analysis/output/heatwave_scenario_summary.csv
#   - 06_analysis/figures/supplementary/FigS22_heatwave_scenarios.png + .pdf
#
# REFERENCES:
#   Manzello DP et al. (2025) Heat-driven functional extinction of Caribbean
#     Acropora corals from Florida's Coral Reef. Science.
#     doi: 10.1126/science.adx7825
#
# Author: Detmer & Stier Lab
# Date: 2026-04
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(patchwork)
})

set.seed(42)

print_header("40: MANZELLO HEATWAVE SCENARIO ANALYSIS")
cat("  Projecting population dynamics under recurring catastrophic heatwave scenarios\n")
cat("  Based on: Manzello et al. (2025) Science — dose-response mortality data\n\n")

# Paths
dirs <- setup_output_dirs()
output_dir <- dirs$output
supp_dir <- dirs$figures_supp
dir.create(supp_dir, showWarnings = FALSE, recursive = TRUE)

pal <- MANUSCRIPT_PALETTE

# ==============================================================================
# SECTION 1: LOAD POPULATION MODEL
# ==============================================================================

print_subheader("Section 1: Loading Population Model")

# Load transition matrix (stored as a list with named components)
tm_list <- readRDS(file.path(output_dir, "transition_matrix.rds"))
A <- tm_list$projection_matrix
pop_params <- read_csv(file.path(output_dir, "population_parameters.csv"),
                       show_col_types = FALSE)

lambda_det <- as.numeric(pop_params$value[pop_params$parameter == "lambda"])
cat(sprintf("  Deterministic lambda: %.4f\n", lambda_det))
cat(sprintf("  Matrix dimensions: %d x %d\n", nrow(A), ncol(A)))
cat("  Projection matrix:\n")
print(round(A, 4))

# Load bootstrap lambda samples (numeric vector of 2000 values)
boot_file <- file.path(output_dir, "lambda_bootstrap_samples.rds")
boot_lambdas <- NULL
if (file.exists(boot_file)) {
  boot_lambdas <- readRDS(boot_file)
  # Handle both list and vector formats
  if (is.list(boot_lambdas) && "lambda" %in% names(boot_lambdas)) {
    boot_lambdas <- boot_lambdas$lambda
  }
  boot_lambdas <- boot_lambdas[is.finite(boot_lambdas) & boot_lambdas > 0]
  cat(sprintf("  Bootstrap lambda samples loaded: %d valid values\n", length(boot_lambdas)))
  cat(sprintf("  Bootstrap lambda range: %.4f - %.4f\n",
              min(boot_lambdas), max(boot_lambdas)))
}

# ==============================================================================
# SECTION 2: MANZELLO DOSE-RESPONSE PARAMETERIZATION
# ==============================================================================

print_subheader("Section 2: Dose-Response Function (Manzello et al. 2025)")

# Manzello et al. (2025) report:
#   ED50 = 7.8 DHW (A. palmata)
#   ED95 = 17.6 DHW (A. palmata)
#   Mortality onset ~3 DHW
#
# We fit a 2-parameter logistic: mortality = 1 / (1 + exp(-b * (DHW - ED50)))
# Solving for b using ED95:
#   0.95 = 1 / (1 + exp(-b * (17.6 - 7.8)))
#   exp(-9.8 * b) = 1/0.95 - 1 = 0.05263
#   b = -ln(0.05263) / 9.8 = 0.3004

ED50 <- 7.8   # DHW at 50% mortality
ED95 <- 17.6  # DHW at 95% mortality
b <- -log(1/0.95 - 1) / (ED95 - ED50)

cat(sprintf("  ED50 = %.1f DHW\n", ED50))
cat(sprintf("  ED95 = %.1f DHW\n", ED95))
cat(sprintf("  Logistic slope (b) = %.4f\n", b))

# Define dose-response function
manzello_mortality <- function(dhw) {
  1 / (1 + exp(-b * (dhw - ED50)))
}

# Validate against known points
cat("\n  Validation against Manzello et al. (2025) reported values:\n")
test_dhw <- c(0, 3, 7.8, 12, 17.6, 18)
for (d in test_dhw) {
  cat(sprintf("    DHW = %5.1f -> Mortality = %.3f (Survival = %.3f)\n",
              d, manzello_mortality(d), 1 - manzello_mortality(d)))
}

# Generate full dose-response curve for export
dose_response_df <- data.frame(
  dhw = seq(0, 25, by = 0.5),
  mortality = manzello_mortality(seq(0, 25, by = 0.5))
) %>%
  mutate(
    survival = 1 - mortality,
    source = "Manzello_et_al_2025",
    species = "Acropora_palmata",
    ED50_dhw = ED50,
    ED95_dhw = ED95,
    logistic_slope = b
  )

write_csv(dose_response_df, file.path(output_dir, "manzello_dose_response.csv"))
cat(sprintf("\n  Dose-response curve saved: %d rows\n", nrow(dose_response_df)))

# ==============================================================================
# SECTION 3: DEFINE HEATWAVE SCENARIOS
# ==============================================================================

print_subheader("Section 3: Heatwave Scenarios")

# Scenario definitions based on DHW severity
scenarios <- tibble(
  scenario = c("baseline", "moderate_bleaching", "severe_bleaching", "catastrophic_2023"),
  dhw = c(0, 8, 12, 18),
  description = c(
    "No heatwave (chronic regime only)",
    "Moderate bleaching (~8 DHW, ~ED50)",
    "Severe bleaching (~12 DHW)",
    "Catastrophic 2023-scale (~18 DHW, ~ED95)"
  )
) %>%
  mutate(
    heatwave_mortality = manzello_mortality(dhw),
    heatwave_survival_multiplier = 1 - heatwave_mortality
  )

# Return intervals to test (years between catastrophic events)
return_intervals <- c(5, 10, 20, 50)

cat("  Heatwave severity scenarios:\n")
for (i in 1:nrow(scenarios)) {
  cat(sprintf("    %s: DHW=%.0f, mortality=%.1f%%, survival multiplier=%.3f\n",
              scenarios$scenario[i], scenarios$dhw[i],
              scenarios$heatwave_mortality[i] * 100,
              scenarios$heatwave_survival_multiplier[i]))
}

cat(sprintf("\n  Return intervals tested: %s years\n",
            paste(return_intervals, collapse = ", ")))

# ==============================================================================
# SECTION 4: POPULATION PROJECTIONS WITH HEATWAVE PULSES
# ==============================================================================

print_subheader("Section 4: Population Projections Under Heatwave Scenarios")

n_years <- 50
n_sims <- 500  # Monte Carlo replicates for uncertainty
initial_pop <- c(100, 50, 30, 20, 10)  # Starting population by size class
names(initial_pop) <- SIZE_LABELS

# Storage for all projection results
all_projections <- list()

# For each severity x return interval combination
for (s in 1:nrow(scenarios)) {
  scenario_name <- scenarios$scenario[s]
  surv_mult <- scenarios$heatwave_survival_multiplier[s]

  if (scenario_name == "baseline") {
    # Baseline: single deterministic projection, no heatwave pulse
    intervals_to_run <- 0  # placeholder
  } else {
    intervals_to_run <- return_intervals
  }

  for (ri in intervals_to_run) {
    label <- if (scenario_name == "baseline") {
      "baseline_no_heatwave"
    } else {
      paste0(scenario_name, "_every_", ri, "yr")
    }

    cat(sprintf("  Projecting: %s\n", label))

    # Deterministic projection
    pop_det <- matrix(0, nrow = n_years + 1, ncol = 5)
    pop_det[1, ] <- initial_pop

    for (t in 2:(n_years + 1)) {
      year <- t - 1
      pop_det[t, ] <- A %*% pop_det[t - 1, ]

      # Apply heatwave mortality pulse at return intervals
      if (scenario_name != "baseline" && ri > 0 && year %% ri == 0) {
        # Heatwave kills a fraction of all colonies regardless of size
        # Manzello 2023 data: 97.8-100% mortality across ALL size classes
        pop_det[t, ] <- pop_det[t, ] * surv_mult
      }
      pop_det[t, ] <- pmax(pop_det[t, ], 0)
    }

    # Store deterministic trajectory
    det_df <- data.frame(
      year = 0:n_years,
      total = rowSums(pop_det),
      pct_initial = rowSums(pop_det) / sum(initial_pop) * 100,
      scenario = scenario_name,
      return_interval = ri,
      label = label,
      sim_type = "deterministic"
    )

    # Monte Carlo with parametric uncertainty
    # Scale the transition matrix by bootstrapped lambda values
    sim_totals <- matrix(NA, nrow = n_sims, ncol = n_years + 1)

    for (sim in 1:n_sims) {
      pop_sim <- initial_pop
      sim_totals[sim, 1] <- sum(pop_sim)

      # Scale matrix by a bootstrapped lambda to propagate parametric uncertainty
      if (!is.null(boot_lambdas) && length(boot_lambdas) > 0) {
        lambda_sim <- sample(boot_lambdas, 1)
        A_sim <- A * (lambda_sim / lambda_det)
      } else {
        A_sim <- A
      }

      for (t in 2:(n_years + 1)) {
        year <- t - 1
        pop_sim <- as.numeric(A_sim %*% pop_sim)

        # Apply heatwave pulse
        if (scenario_name != "baseline" && ri > 0 && year %% ri == 0) {
          pop_sim <- pop_sim * surv_mult
        }
        pop_sim <- pmax(pop_sim, 0)
        sim_totals[sim, t] <- sum(pop_sim)
      }
    }

    # Compute summary statistics across simulations
    sim_summary <- data.frame(
      year = 0:n_years,
      median = apply(sim_totals, 2, median),
      mean = colMeans(sim_totals),
      ci_lower = apply(sim_totals, 2, quantile, probs = 0.025),
      ci_upper = apply(sim_totals, 2, quantile, probs = 0.975),
      pi_lower = apply(sim_totals, 2, quantile, probs = 0.1),
      pi_upper = apply(sim_totals, 2, quantile, probs = 0.9),
      scenario = scenario_name,
      return_interval = ri,
      label = label,
      sim_type = "monte_carlo"
    ) %>%
      mutate(
        pct_initial_median = median / sum(initial_pop) * 100,
        pct_initial_mean = mean / sum(initial_pop) * 100
      )

    # Quasi-extinction probability
    quasi_thresh <- sum(initial_pop) * 0.1  # 10% of initial
    p_quasi <- mean(sim_totals[, n_years + 1] < quasi_thresh)

    # Effective stochastic lambda under this scenario
    # log-lambda = mean of log(N_t+1/N_t) across years
    log_lambdas <- numeric(n_sims)
    for (sim in 1:n_sims) {
      ratios <- sim_totals[sim, -1] / sim_totals[sim, -(n_years + 1)]
      ratios <- ratios[ratios > 0 & is.finite(ratios)]
      log_lambdas[sim] <- mean(log(ratios))
    }
    effective_lambda <- exp(mean(log_lambdas[is.finite(log_lambdas)]))

    cat(sprintf("    Effective lambda: %.4f | P(quasi-extinction at yr %d): %.1f%%\n",
                effective_lambda, n_years, p_quasi * 100))

    all_projections[[label]] <- list(
      deterministic = det_df,
      monte_carlo = sim_summary,
      effective_lambda = effective_lambda,
      p_quasi_extinction = p_quasi,
      scenario = scenario_name,
      return_interval = ri
    )

    # Only run baseline once
    if (scenario_name == "baseline") break
  }
}

# ==============================================================================
# SECTION 5: COMPILE RESULTS
# ==============================================================================

print_subheader("Section 5: Compiling Results")

# Summary table
scenario_summary <- bind_rows(lapply(all_projections, function(x) {
  mc <- x$monte_carlo
  tibble(
    scenario = x$scenario,
    return_interval_yr = x$return_interval,
    effective_lambda = x$effective_lambda,
    p_quasi_extinction_50yr = x$p_quasi_extinction,
    pop_yr10_median_pct = mc$pct_initial_median[mc$year == 10],
    pop_yr20_median_pct = mc$pct_initial_median[mc$year == 20],
    pop_yr50_median_pct = mc$pct_initial_median[mc$year == 50],
    pop_yr50_ci_lower = mc$ci_lower[mc$year == 50],
    pop_yr50_ci_upper = mc$ci_upper[mc$year == 50]
  )
}))

# Add description
scenario_summary <- scenario_summary %>%
  left_join(scenarios %>% select(scenario, dhw, description, heatwave_mortality),
            by = "scenario")

write_csv(scenario_summary, file.path(output_dir, "heatwave_scenario_summary.csv"))
cat(sprintf("  Summary saved: %d scenario combinations\n", nrow(scenario_summary)))

# Full projection trajectories
projection_trajectories <- bind_rows(lapply(all_projections, function(x) {
  x$monte_carlo
}))

write_csv(projection_trajectories,
          file.path(output_dir, "heatwave_scenario_projections.csv"))
cat(sprintf("  Trajectories saved: %d rows\n", nrow(projection_trajectories)))

# Print summary table
cat("\n  ╔═══════════════════════════════════════════════════════════════╗\n")
cat("  ║  HEATWAVE SCENARIO RESULTS                                   ║\n")
cat("  ╚═══════════════════════════════════════════════════════════════╝\n\n")

cat(sprintf("  %-35s %8s %8s %10s %10s\n",
            "Scenario", "Lambda", "P(QE)", "Pop@20yr", "Pop@50yr"))
cat(sprintf("  %-35s %8s %8s %10s %10s\n",
            "-----------------------------------", "--------", "--------",
            "----------", "----------"))

for (i in 1:nrow(scenario_summary)) {
  ri_label <- if (scenario_summary$return_interval_yr[i] == 0) {
    ""
  } else {
    sprintf(" (every %d yr)", scenario_summary$return_interval_yr[i])
  }
  cat(sprintf("  %-35s %8.4f %7.1f%% %9.1f%% %9.1f%%\n",
              paste0(scenario_summary$scenario[i], ri_label),
              scenario_summary$effective_lambda[i],
              scenario_summary$p_quasi_extinction_50yr[i] * 100,
              scenario_summary$pop_yr20_median_pct[i],
              scenario_summary$pop_yr50_median_pct[i]))
}

# ==============================================================================
# SECTION 6: SUPPLEMENTARY FIGURE S22 — HEATWAVE SCENARIOS
# ==============================================================================

print_subheader("Section 6: Figure S22 — Heatwave Scenario Projections")

# Panel (a): Dose-response curve from Manzello et al. (2025)
p_dose <- ggplot(dose_response_df, aes(x = dhw, y = mortality * 100)) +
  # Mark the 2023 FL Keys DHW range first (background)
  annotate("rect", xmin = 16, xmax = 20.5, ymin = 0, ymax = 100,
           alpha = 0.15, fill = "red") +
  geom_line(linewidth = 1.2, color = pal$surv_dark) +
  geom_vline(xintercept = ED50, linetype = "dashed", color = "grey50") +
  geom_vline(xintercept = ED95, linetype = "dashed", color = "grey50") +
  geom_hline(yintercept = 50, linetype = "dotted", color = "grey70") +
  geom_hline(yintercept = 95, linetype = "dotted", color = "grey70") +
  # Separate y-positions to prevent overlap
  annotate("text", x = ED50 + 0.4, y = 42,
           label = paste0("ED50 = ", ED50, " DHW"),
           hjust = 0, size = 2.6, color = "grey30") +
  annotate("text", x = ED95 + 0.4, y = 88,
           label = paste0("ED95 = ", ED95, " DHW"),
           hjust = 0, size = 2.6, color = "grey30") +
  annotate("text", x = 18.2, y = 22,
           label = "2023 FL Keys\n(16-20 DHW)",
           size = 2.4, color = "red4", lineheight = 0.9) +
  scale_x_continuous(breaks = seq(0, 25, 5)) +
  scale_y_continuous(breaks = seq(0, 100, 25)) +
  labs(x = "Degree Heating Weeks (DHW, °C-weeks)",
       y = "Mortality (%)") +
  coord_cartesian(xlim = c(0, 25), ylim = c(0, 100)) +
  theme_manuscript()

# Panel (b): Population trajectories under catastrophic scenario at different
# return intervals
catastrophic_data <- projection_trajectories %>%
  filter(scenario %in% c("baseline", "catastrophic_2023")) %>%
  mutate(
    label_short = case_when(
      scenario == "baseline" ~ "No heatwave",
      return_interval == 5 ~ "5 yr",
      return_interval == 10 ~ "10 yr",
      return_interval == 20 ~ "20 yr",
      return_interval == 50 ~ "50 yr"
    ),
    label_short = factor(label_short,
                         levels = c("No heatwave", "50 yr", "20 yr",
                                    "10 yr", "5 yr"))
  )

# Color palette for return intervals
ri_colors <- c(
  "No heatwave" = "grey40",
  "50 yr" = "#56B4E9",
  "20 yr" = "#E69F00",
  "10 yr" = "#D55E00",
  "5 yr"  = "#CC79A7"
)

p_traj <- ggplot(catastrophic_data, aes(x = year, y = pct_initial_median,
                                         color = label_short, fill = label_short)) +
  geom_ribbon(aes(ymin = ci_lower / sum(initial_pop) * 100,
                  ymax = ci_upper / sum(initial_pop) * 100),
              alpha = 0.15, color = NA) +
  geom_line(linewidth = 0.8) +
  geom_hline(yintercept = 10, linetype = "dashed", color = "grey60") +
  annotate("text", x = 48, y = 12, label = "Quasi-extinction",
           hjust = 1, size = 2.5, color = "grey50") +
  scale_color_manual(values = ri_colors) +
  scale_fill_manual(values = ri_colors) +
  scale_y_continuous(breaks = seq(0, 200, 25)) +
  labs(x = "Year",
       y = "Population (% of initial)",
       color = "Heatwave return interval",
       fill = "Heatwave return interval") +
  coord_cartesian(ylim = c(0, max(catastrophic_data$ci_upper / sum(initial_pop) * 100,
                                   na.rm = TRUE) * 1.05)) +
  guides(color = guide_legend(nrow = 2, byrow = TRUE),
         fill = guide_legend(nrow = 2, byrow = TRUE)) +
  theme_manuscript() +
  theme(legend.position = "bottom",
        legend.title = element_text(size = 8),
        legend.text = element_text(size = 7.5),
        legend.key.width = unit(5, "mm"),
        legend.key.height = unit(3, "mm"),
        legend.box.margin = margin(0, 0, 0, 0, "mm"))

# Panel (c): Effective lambda by severity and return interval
# Exclude baseline from this panel
lambda_data <- scenario_summary %>%
  filter(scenario != "baseline", return_interval_yr > 0) %>%
  mutate(
    severity = factor(scenario,
                      levels = c("moderate_bleaching", "severe_bleaching", "catastrophic_2023"),
                      labels = c("Moderate\n(~8 DHW)", "Severe\n(~12 DHW)",
                                 "Catastrophic\n(~18 DHW)")),
    return_interval_yr = factor(return_interval_yr)
  )

p_lambda <- ggplot(lambda_data, aes(x = severity, y = effective_lambda,
                                     fill = return_interval_yr)) +
  geom_col(position = position_dodge(0.8), width = 0.7) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey50") +
  geom_hline(yintercept = lambda_det, linetype = "dotted", color = pal$surv_dark) +
  annotate("text", x = 0.55, y = lambda_det,
           label = sprintf("Baseline lambda = %.3f", lambda_det),
           hjust = 0, vjust = -0.6, size = 2.5, color = pal$surv_dark,
           fontface = "italic") +
  annotate("text", x = 3.45, y = 1,
           label = "stable",
           hjust = 1, vjust = -0.6, size = 2.5, color = "grey40",
           fontface = "italic") +
  scale_fill_manual(
    values = c("5" = "#CC79A7", "10" = "#D55E00", "20" = "#E69F00", "50" = "#56B4E9"),
    name = "Heatwave return interval (yr)"
  ) +
  labs(x = "Heatwave severity",
       y = expression("Effective " * lambda)) +
  coord_cartesian(ylim = c(
    min(lambda_data$effective_lambda, na.rm = TRUE) * 0.95,
    1.03
  )) +
  theme_manuscript() +
  theme(legend.position = "bottom",
        legend.title = element_text(size = 8),
        legend.text = element_text(size = 7.5),
        legend.key.size = unit(3.5, "mm"),
        plot.margin = margin(6, 6, 4, 6, "mm"))

# Combine panels: pull panel b legend to the bottom of the top row (shared)
top_row <- (p_dose + p_traj) +
  plot_layout(widths = c(1, 1.15), guides = "collect") &
  theme(legend.position = "bottom")

fig_s22 <- top_row / p_lambda +
  plot_layout(heights = c(1, 1)) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 10, face = "bold"))

# Save
save_manuscript_fig(
  fig_s22,
  "FigS22_heatwave_scenarios",
  width_mm = 174,
  height_mm = 180,
  fig_dir = supp_dir
)

cat("  FigS22 saved to supplementary/\n")

# ==============================================================================
# SECTION 7: KEY FINDINGS SUMMARY
# ==============================================================================

print_subheader("Section 7: Key Findings")

cat("\n  INTERPRETATION:\n")
cat("  Our Lefkovitch matrix captures the chronic demographic regime (pre-2023),\n")
cat("  under which A. palmata populations were already declining (lambda = ",
    sprintf("%.3f", lambda_det), ").\n", sep = "")
cat("  Manzello et al. (2025) shows that extreme heatwaves overwhelm size-dependent\n")
cat("  survival advantages: 97.8-100% mortality across ALL size classes at 18 DHW.\n\n")

cat("  KEY RESULT: Under recurring catastrophic heatwaves (2023-scale):\n")

cat_result <- scenario_summary %>% filter(scenario == "catastrophic_2023")
for (i in 1:nrow(cat_result)) {
  cat(sprintf("    Every %d yr: effective lambda = %.4f, P(quasi-extinction) = %.1f%%\n",
              cat_result$return_interval_yr[i],
              cat_result$effective_lambda[i],
              cat_result$p_quasi_extinction_50yr[i] * 100))
}

cat("\n  IMPLICATION: Our elasticity analysis shows that SC5 stasis is the most\n")
cat("  important vital rate for population viability. However, this only holds\n")
cat("  under the chronic disturbance regime. Under 2023-scale events, thermal\n")
cat("  tolerance — not colony size — becomes the binding constraint on persistence.\n")
cat("  Restoration must target BOTH demographic size (grow to SC4-SC5) AND thermal\n")
cat("  tolerance (assisted gene flow, symbiont manipulation) to be viable.\n")

cat("\n  ✓ Script 40 complete\n")
