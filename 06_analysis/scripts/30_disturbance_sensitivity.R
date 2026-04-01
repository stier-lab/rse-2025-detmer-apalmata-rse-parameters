#!/usr/bin/env Rscript
################################################################################
# 30_DISTURBANCE_SENSITIVITY.R
# Sensitivity Analysis: Effect of 2014 Disease Event on Survival Estimates
################################################################################
#
# PURPOSE: Assess how the catastrophic 2014 disease mortality in the Neely et al.
#   (2022) dataset influences survival estimates and meta-analytic results.
#   The `disturbance` column flags affected intervals:
#     - "disease_2014": TP4->TP5 interval (~53% survival vs ~85-90% normal)
#     - "disease_2014_aftermath": TP5->TP6 interval (~61% survival)
#     - NA: non-disturbance intervals
#
# ANALYSES:
#   1. Overall survival by study: with vs without disturbance-flagged intervals
#   2. Tier 1 meta-analysis (k=6-7) re-run excluding disturbance rows
#   3. Neely effect comparison: all intervals vs non-disturbance only
#   4. Survival-size GAM: with vs without disturbance intervals
#
# OUTPUTS:
#   CSVs:
#     - 06_analysis/output/disturbance_sensitivity_summary.csv
#     - 06_analysis/output/disturbance_interval_comparison.csv
#   Figure:
#     - 06_analysis/figures/supplementary/FigSXX_disturbance_sensitivity.png
#
# Author: Detmer & Stier Lab
# Date: 2026-03
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)
library(metafor)
library(mgcv)

set.seed(42)

print_header("30: DISTURBANCE SENSITIVITY ANALYSIS")
cat("  Assessing impact of Neely et al. 2022 disease event on survival estimates\n\n")

# Paths
dirs <- setup_output_dirs()
output_dir <- dirs$output
supp_dir <- dirs$figures_supp
dir.create(supp_dir, showWarnings = FALSE, recursive = TRUE)

pal <- MANUSCRIPT_PALETTE

# ==============================================================================
# SECTION 1: LOAD DATA
# ==============================================================================

print_subheader("Section 1: Loading Prepared Survival Data")

surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))

cat(sprintf("  Loaded %d survival observations from %d studies\n",
            nrow(surv_data), n_distinct(surv_data$study)))

# Ensure population_type exists
if (!"population_type" %in% names(surv_data)) {
  surv_data <- surv_data %>%
    mutate(
      is_fragment = (fragment == "Y"),
      population_type = ifelse(is_fragment, "Restoration fragment", "Natural colony")
    )
}

# Flag disturbance intervals
surv_data <- surv_data %>%
  mutate(
    is_disease_2014 = !is.na(disturbance) & disturbance %in% c("disease_2014", "disease_2014_aftermath"),
    disturbance_label = case_when(
      disturbance == "disease_2014" ~ "Disease 2014 (TP4-TP5)",
      disturbance == "disease_2014_aftermath" ~ "Aftermath (TP5-TP6)",
      disturbance == "storm" ~ "Storm",
      TRUE ~ "Non-disturbance"
    )
  )

neely_data <- surv_data %>% filter(study == "neely_et_al_2022")
n_disease <- sum(surv_data$is_disease_2014)
n_neely_disease <- sum(neely_data$is_disease_2014)

cat(sprintf("  Disease-flagged intervals (total): %d\n", n_disease))
cat(sprintf("  Disease-flagged intervals (Neely): %d\n", n_neely_disease))
cat(sprintf("  Non-disturbance intervals (Neely): %d\n", sum(!neely_data$is_disease_2014)))

# ==============================================================================
# SECTION 2: SURVIVAL BY STUDY — WITH VS WITHOUT DISTURBANCE INTERVALS
# ==============================================================================

print_subheader("Section 2: Overall Survival by Study (with/without disturbance)")

# Full dataset: survival by study
study_surv_full <- surv_data %>%
  group_by(study) %>%
  summarise(
    n_full = n(),
    n_survived_full = sum(survived),
    surv_rate_full = mean(survived),
    n_disease_intervals = sum(is_disease_2014),
    .groups = "drop"
  )

# Excluding disease_2014 intervals
surv_no_disease <- surv_data %>% filter(!is_disease_2014)

study_surv_excl <- surv_no_disease %>%
  group_by(study) %>%
  summarise(
    n_excl = n(),
    n_survived_excl = sum(survived),
    surv_rate_excl = mean(survived),
    .groups = "drop"
  )

# Combine
study_comparison <- study_surv_full %>%
  left_join(study_surv_excl, by = "study") %>%
  mutate(
    surv_diff = surv_rate_excl - surv_rate_full,
    surv_diff_pct = surv_diff * 100,
    affected = n_disease_intervals > 0
  )

cat("\n  Study-level survival comparison:\n")
study_comparison %>%
  dplyr::select(study, n_full, surv_rate_full, n_excl, surv_rate_excl, surv_diff_pct, affected) %>%
  mutate(across(starts_with("surv_rate"), ~ round(., 4)),
         surv_diff_pct = round(surv_diff_pct, 2)) %>%
  print(n = 20)

# ==============================================================================
# SECTION 3: NEELY EFFECT COMPARISON (ALL VS NON-DISTURBANCE)
# ==============================================================================

print_subheader("Section 3: Neely et al. 2022 — Disturbance vs Non-Disturbance")

neely_by_disturbance <- neely_data %>%
  group_by(disturbance_label) %>%
  summarise(
    n = n(),
    n_survived = sum(survived),
    surv_rate = mean(survived),
    .groups = "drop"
  ) %>%
  mutate(
    ci = purrr::map2(n_survived, n, ~ wilson_ci(.x, .y)),
    ci_lower = purrr::map_dbl(ci, "lower"),
    ci_upper = purrr::map_dbl(ci, "upper")
  ) %>%
  dplyr::select(-ci)

# Add overall rows
neely_overall_all <- neely_data %>%
  summarise(
    disturbance_label = "All intervals (Neely)",
    n = n(),
    n_survived = sum(survived),
    surv_rate = mean(survived)
  )
neely_overall_all_ci <- wilson_ci(neely_overall_all$n_survived, neely_overall_all$n)
neely_overall_all$ci_lower <- neely_overall_all_ci$lower
neely_overall_all$ci_upper <- neely_overall_all_ci$upper

neely_overall_nondist <- neely_data %>%
  filter(!is_disease_2014) %>%
  summarise(
    disturbance_label = "Non-disturbance only (Neely)",
    n = n(),
    n_survived = sum(survived),
    surv_rate = mean(survived)
  )
neely_overall_nondist_ci <- wilson_ci(neely_overall_nondist$n_survived, neely_overall_nondist$n)
neely_overall_nondist$ci_lower <- neely_overall_nondist_ci$lower
neely_overall_nondist$ci_upper <- neely_overall_nondist_ci$upper

neely_interval_comparison <- bind_rows(neely_by_disturbance, neely_overall_all, neely_overall_nondist)

cat("\n  Neely disturbance interval breakdown:\n")
neely_interval_comparison %>%
  mutate(across(c(surv_rate, ci_lower, ci_upper), ~ round(., 4))) %>%
  print(n = 10)

# Save interval comparison
write_csv(neely_interval_comparison,
          file.path(output_dir, "disturbance_interval_comparison.csv"))
print_success("Saved: disturbance_interval_comparison.csv")

# ==============================================================================
# SECTION 4: TIER 1 META-ANALYSIS — WITH AND WITHOUT DISTURBANCE
# ==============================================================================

print_subheader("Section 4: Tier 1 Meta-Analysis Sensitivity")

run_tier1_meta <- function(data, label) {
  # Calculate study-level statistics
  study_stats <- data %>%
    group_by(study) %>%
    summarise(
      region = first(region),
      n = n(),
      n_survived = sum(survived),
      n_died = n - n_survived,
      survival_rate = mean(survived),
      mean_size_cm2 = mean(size_cm2, na.rm = TRUE),
      pct_fragment = mean(fragment == "Y", na.rm = TRUE) * 100,
      population_type = ifelse(mean(fragment == "Y", na.rm = TRUE) > 0.5,
                               "Restoration fragment", "Natural colony"),
      .groups = "drop"
    ) %>%
    # Filter for valid meta-analysis inclusion (need both events and non-events)
    filter(n >= 10, n_survived > 0, n_died > 0)

  k <- nrow(study_stats)

  if (k < 2) {
    cat(sprintf("  [%s] Only k=%d studies — cannot run meta-analysis\n", label, k))
    return(NULL)
  }

  # Compute effect sizes (PLO = proportional log-odds)
  study_effects <- escalc(measure = "PLO",
                          xi = study_stats$n_survived,
                          ni = study_stats$n,
                          data = study_stats,
                          add = 0.5, to = "only0")

  study_effects <- study_effects %>%
    mutate(
      log_odds = as.numeric(yi),
      var_log_odds = as.numeric(vi),
      se_log_odds = sqrt(var_log_odds),
      surv_lower = plogis(log_odds - 1.96 * se_log_odds),
      surv_upper = plogis(log_odds + 1.96 * se_log_odds)
    )

  # REML with Knapp-Hartung
  rma_fit <- tryCatch(
    rma(yi = study_effects$log_odds,
        vi = study_effects$var_log_odds,
        method = "REML", test = "knha"),
    error = function(e) {
      cat(sprintf("  [%s] rma() failed: %s\n", label, e$message))
      return(NULL)
    }
  )

  if (is.null(rma_fit)) return(NULL)

  # Random effects weights
  tau_sq <- rma_fit$tau2
  study_effects <- study_effects %>%
    mutate(
      weight_re = 1 / (var_log_odds + tau_sq),
      weight_re_pct = weight_re / sum(weight_re) * 100
    )

  pooled_surv <- plogis(as.numeric(rma_fit$beta))
  pooled_lower <- plogis(rma_fit$ci.lb)
  pooled_upper <- plogis(rma_fit$ci.ub)

  # Prediction interval
  rma_pred <- predict(rma_fit)
  pi_lower <- plogis(rma_pred$pi.lb)
  pi_upper <- plogis(rma_pred$pi.ub)

  cat(sprintf("  [%s] k=%d, N=%d\n", label, k, sum(study_effects$n)))
  cat(sprintf("  [%s] Pooled survival: %.1f%% (95%% CI: %.1f%% - %.1f%%)\n",
              label, pooled_surv * 100, pooled_lower * 100, pooled_upper * 100))
  cat(sprintf("  [%s] I2 = %.1f%%, tau2 = %.4f\n", label, rma_fit$I2, tau_sq))
  cat(sprintf("  [%s] Prediction interval: %.1f%% - %.1f%%\n",
              label, pi_lower * 100, pi_upper * 100))

  list(
    label = label,
    rma = rma_fit,
    study_effects = study_effects,
    k = k,
    n_total = sum(study_effects$n),
    pooled_surv = pooled_surv,
    pooled_lower = pooled_lower,
    pooled_upper = pooled_upper,
    I2 = rma_fit$I2,
    tau2 = tau_sq,
    pi_lower = pi_lower,
    pi_upper = pi_upper
  )
}

# Run with ALL data
meta_full <- run_tier1_meta(surv_data, "All data")

# Run EXCLUDING disease_2014 intervals
meta_no_disease <- run_tier1_meta(surv_no_disease, "Excl. disease 2014")

# ==============================================================================
# SECTION 5: COMPILE SENSITIVITY SUMMARY
# ==============================================================================

print_subheader("Section 5: Sensitivity Summary")

sensitivity_rows <- list()

if (!is.null(meta_full)) {
  sensitivity_rows[["full"]] <- data.frame(
    scenario = "All data (including disease 2014)",
    k = meta_full$k,
    n_total = meta_full$n_total,
    pooled_survival = round(meta_full$pooled_surv, 4),
    ci_lower = round(meta_full$pooled_lower, 4),
    ci_upper = round(meta_full$pooled_upper, 4),
    I2 = round(meta_full$I2, 1),
    tau2 = round(meta_full$tau2, 4),
    pi_lower = round(meta_full$pi_lower, 4),
    pi_upper = round(meta_full$pi_upper, 4),
    neely_survival = round(mean(neely_data$survived), 4),
    neely_n = nrow(neely_data),
    stringsAsFactors = FALSE
  )
}

if (!is.null(meta_no_disease)) {
  neely_no_disease <- neely_data %>% filter(!is_disease_2014)
  sensitivity_rows[["no_disease"]] <- data.frame(
    scenario = "Excluding disease 2014 intervals",
    k = meta_no_disease$k,
    n_total = meta_no_disease$n_total,
    pooled_survival = round(meta_no_disease$pooled_surv, 4),
    ci_lower = round(meta_no_disease$pooled_lower, 4),
    ci_upper = round(meta_no_disease$pooled_upper, 4),
    I2 = round(meta_no_disease$I2, 1),
    tau2 = round(meta_no_disease$tau2, 4),
    pi_lower = round(meta_no_disease$pi_lower, 4),
    pi_upper = round(meta_no_disease$pi_upper, 4),
    neely_survival = round(mean(neely_no_disease$survived), 4),
    neely_n = nrow(neely_no_disease),
    stringsAsFactors = FALSE
  )
}

sensitivity_summary <- bind_rows(sensitivity_rows)

# Add the study-level comparison
sensitivity_summary_full <- bind_rows(
  sensitivity_summary,
  data.frame(
    scenario = "Neely: disease_2014 intervals only",
    k = NA, n_total = sum(neely_data$disturbance == "disease_2014", na.rm = TRUE),
    pooled_survival = round(mean(neely_data$survived[neely_data$disturbance == "disease_2014" & !is.na(neely_data$disturbance)]), 4),
    ci_lower = NA, ci_upper = NA, I2 = NA, tau2 = NA, pi_lower = NA, pi_upper = NA,
    neely_survival = NA, neely_n = NA, stringsAsFactors = FALSE
  ),
  data.frame(
    scenario = "Neely: aftermath intervals only",
    k = NA, n_total = sum(neely_data$disturbance == "disease_2014_aftermath", na.rm = TRUE),
    pooled_survival = round(mean(neely_data$survived[neely_data$disturbance == "disease_2014_aftermath" & !is.na(neely_data$disturbance)]), 4),
    ci_lower = NA, ci_upper = NA, I2 = NA, tau2 = NA, pi_lower = NA, pi_upper = NA,
    neely_survival = NA, neely_n = NA, stringsAsFactors = FALSE
  )
)

write_csv(sensitivity_summary_full,
          file.path(output_dir, "disturbance_sensitivity_summary.csv"))
print_success("Saved: disturbance_sensitivity_summary.csv")

cat("\n  Sensitivity summary:\n")
print(sensitivity_summary_full)

# ==============================================================================
# SECTION 6: SURVIVAL-SIZE GAM — WITH VS WITHOUT DISTURBANCE
# ==============================================================================

print_subheader("Section 6: Survival-Size GAM Comparison")

# Filter to natural colonies (consistent with manuscript Fig 2)
surv_natural <- surv_data %>%
  filter(population_type == "Natural colony") %>%
  filter(!is.na(size_cm2), !is.na(survived)) %>%
  mutate(log_size = log(size_cm2))

surv_natural_no_disease <- surv_natural %>% filter(!is_disease_2014)

cat(sprintf("  Natural colony records (all): %d\n", nrow(surv_natural)))
cat(sprintf("  Natural colony records (excl. disease): %d\n", nrow(surv_natural_no_disease)))

# Fit GAMs
gam_full <- gam(survived ~ s(log_size, k = 4),
                data = surv_natural, family = binomial, method = "REML")
gam_no_disease <- gam(survived ~ s(log_size, k = 4),
                      data = surv_natural_no_disease, family = binomial, method = "REML")

cat(sprintf("  GAM (all data) R2 = %.3f, deviance explained = %.1f%%\n",
            summary(gam_full)$r.sq, summary(gam_full)$dev.expl * 100))
cat(sprintf("  GAM (excl. disease) R2 = %.3f, deviance explained = %.1f%%\n",
            summary(gam_no_disease)$r.sq, summary(gam_no_disease)$dev.expl * 100))

# Generate predictions over shared size range
pred_grid <- data.frame(
  log_size = seq(log(1), log(15000), length.out = 500)
)

# Full data predictions
link_full <- predict(gam_full, newdata = pred_grid, type = "link", se.fit = TRUE)
pred_full <- pred_grid %>%
  mutate(
    size_cm2 = exp(log_size),
    fit = plogis(link_full$fit),
    lower = plogis(link_full$fit - 1.96 * link_full$se.fit),
    upper = plogis(link_full$fit + 1.96 * link_full$se.fit),
    scenario = "All data"
  )

# Excluding disease predictions
link_excl <- predict(gam_no_disease, newdata = pred_grid, type = "link", se.fit = TRUE)
pred_excl <- pred_grid %>%
  mutate(
    size_cm2 = exp(log_size),
    fit = plogis(link_excl$fit),
    lower = plogis(link_excl$fit - 1.96 * link_excl$se.fit),
    upper = plogis(link_excl$fit + 1.96 * link_excl$se.fit),
    scenario = "Excluding disease 2014"
  )

pred_combined <- bind_rows(pred_full, pred_excl)

# ==============================================================================
# SECTION 7: TWO-PANEL FIGURE
# ==============================================================================

print_subheader("Section 7: Creating Figure")

# --------------------------------------------------------------------------
# Panel a: Forest plot comparing study effects with/without Neely 2014 disease
# --------------------------------------------------------------------------

if (!is.null(meta_full) && !is.null(meta_no_disease)) {

  # Build forest data for both scenarios
  build_forest_df <- function(meta_result, scenario_label) {
    se <- meta_result$study_effects
    se %>%
      arrange(desc(survival_rate)) %>%
      mutate(
        study_label = paste0(study, " (", region, ")"),
        scenario = scenario_label,
        surv_text = sprintf("%.1f%% [%.1f, %.1f]",
                            survival_rate * 100, surv_lower * 100, surv_upper * 100)
      )
  }

  forest_full <- build_forest_df(meta_full, "All data")
  forest_excl <- build_forest_df(meta_no_disease, "Excl. disease 2014")

  # Combine into a single plot-ready data frame
  # Use study as the y-axis, dodged by scenario
  all_studies <- union(forest_full$study, forest_excl$study)

  forest_combined <- bind_rows(forest_full, forest_excl) %>%
    mutate(
      study_label = paste0(study, " (", region, ")"),
      study_label = factor(study_label,
                           levels = rev(sort(unique(study_label)))),
      scenario = factor(scenario, levels = c("All data", "Excl. disease 2014"))
    )

  # Pooled estimates as summary rows
  pooled_df <- data.frame(
    scenario = factor(c("All data", "Excl. disease 2014"),
                      levels = c("All data", "Excl. disease 2014")),
    pooled_surv = c(meta_full$pooled_surv, meta_no_disease$pooled_surv),
    pooled_lower = c(meta_full$pooled_lower, meta_no_disease$pooled_lower),
    pooled_upper = c(meta_full$pooled_upper, meta_no_disease$pooled_upper)
  )

  p_forest <- ggplot(forest_combined,
                     aes(x = survival_rate, y = study_label, color = scenario)) +
    # Reference line at 50%
    geom_vline(xintercept = 0.5, linetype = "dotted", color = "gray60", linewidth = 0.4) +
    # Study CIs
    geom_linerange(aes(xmin = surv_lower, xmax = surv_upper),
                   linewidth = 0.5, orientation = "y",
                   position = position_dodge(width = 0.5)) +
    # Study point estimates
    geom_point(aes(size = n), alpha = 0.9,
               position = position_dodge(width = 0.5)) +
    # Pooled estimates as diamonds at bottom
    geom_point(data = pooled_df,
               aes(x = pooled_surv, y = 0.3, color = scenario),
               shape = 23, size = 4, fill = NA, stroke = 1.2,
               position = position_dodge(width = 0.4),
               inherit.aes = FALSE) +
    geom_linerange(data = pooled_df,
                   aes(xmin = pooled_lower, xmax = pooled_upper, y = 0.3,
                       color = scenario),
                   linewidth = 0.7, orientation = "y",
                   position = position_dodge(width = 0.4),
                   inherit.aes = FALSE) +
    # Scales
    scale_x_continuous(
      limits = c(0, 1),
      breaks = seq(0, 1, 0.2),
      labels = scales::percent_format(accuracy = 1),
      expand = c(0.02, 0)
    ) +
    scale_color_manual(
      values = c("All data" = pal$surv_dark, "Excl. disease 2014" = pal$accent),
      name = NULL
    ) +
    scale_size_continuous(range = c(2, 6), guide = "none") +
    labs(x = "Annual survival", y = NULL) +
    theme_manuscript(base_size = 10) +
    theme(
      panel.grid.major.y = element_blank(),
      legend.position = "bottom",
      legend.margin = margin(0, 0, 0, 0),
      plot.tag = element_text(size = 12, face = "bold")
    )

  # --------------------------------------------------------------------------
  # Panel b: Survival ~ size GAM curves
  # --------------------------------------------------------------------------

  # Binned proportions for visual reference
  n_bins <- 25
  make_bins <- function(data, scenario_label) {
    data %>%
      mutate(size_bin = cut(log_size, breaks = n_bins)) %>%
      group_by(size_bin) %>%
      summarise(
        log_size = mean(log_size),
        size_cm2 = exp(mean(log_size)),
        surv_rate = mean(survived),
        n = n(),
        .groups = "drop"
      ) %>%
      filter(n >= 5) %>%
      mutate(scenario = scenario_label)
  }

  bins_full <- make_bins(surv_natural, "All data")
  bins_excl <- make_bins(surv_natural_no_disease, "Excluding disease 2014")
  bins_combined <- bind_rows(bins_full, bins_excl)

  p_gam <- ggplot() +
    # Size class boundaries
    geom_vline(xintercept = c(10, 100, 900, 4000),
               linetype = "dotted", color = pal$slate_light, linewidth = 0.4, alpha = 0.7) +
    # GAM confidence ribbons
    geom_ribbon(data = pred_combined,
                aes(x = size_cm2, ymin = lower, ymax = upper, fill = scenario),
                alpha = 0.2) +
    # GAM fitted curves
    geom_line(data = pred_combined,
              aes(x = size_cm2, y = fit, color = scenario),
              linewidth = 1) +
    # Binned proportions
    geom_point(data = bins_combined,
               aes(x = size_cm2, y = surv_rate, color = scenario, size = n),
               alpha = 0.5, shape = 16) +
    # Size class labels at top
    annotate("text",
             x = c(3, 35, 300, 1900, 8000), y = 1.02,
             label = SIZE_LABELS,
             size = 3.0, color = pal$slate_mid, fontface = "bold") +
    # Scales
    scale_x_log10(
      breaks = c(1, 10, 100, 1000, 10000),
      labels = scales::comma,
      limits = c(1, 15000)
    ) +
    scale_y_continuous(
      limits = c(0, 1.05),
      breaks = seq(0, 1, 0.2),
      labels = scales::percent_format(accuracy = 1)
    ) +
    scale_color_manual(
      values = c("All data" = pal$surv_dark, "Excluding disease 2014" = pal$accent),
      name = NULL
    ) +
    scale_fill_manual(
      values = c("All data" = pal$surv_dark, "Excluding disease 2014" = pal$accent),
      name = NULL
    ) +
    scale_size_continuous(range = c(1, 4), guide = "none") +
    labs(
      x = expression("Colony size (cm"^2*")"),
      y = "Survival probability"
    ) +
    theme_manuscript(base_size = 10) +
    theme(
      legend.position = "bottom",
      legend.margin = margin(0, 0, 0, 0),
      plot.tag = element_text(size = 12, face = "bold")
    )

  # --------------------------------------------------------------------------
  # Combine panels
  # --------------------------------------------------------------------------

  p_combined <- (p_forest + labs(tag = "a")) /
    (p_gam + labs(tag = "b")) +
    plot_layout(heights = c(1, 1), guides = "collect") &
    theme(legend.position = "bottom")

  # Save figure
  fig_path_png <- file.path(supp_dir, "FigSXX_disturbance_sensitivity.png")
  fig_path_pdf <- file.path(supp_dir, "FigSXX_disturbance_sensitivity.pdf")

  ggsave(fig_path_png, plot = p_combined,
         width = 174, height = 200, units = "mm", dpi = 300, bg = "white")

  pdf_device <- if (capabilities("cairo")) cairo_pdf else "pdf"
  ggsave(fig_path_pdf, plot = p_combined,
         width = 174, height = 200, units = "mm",
         bg = "white", device = pdf_device)

  print_success(sprintf("Saved: FigSXX_disturbance_sensitivity.png/pdf (%d x %d mm)", 174, 200))

} else {
  print_warn("Could not create figure — one or both meta-analyses failed")
}

# ==============================================================================
# SECTION 8: BINOMIAL GLMM OVERDISPERSION CHECK (disease as fixed effect)
# ==============================================================================

print_subheader("Section 8: GLMM Overdispersion Check — Disease as Fixed Effect")

# Fit a GLMM including a binary disturbance predictor for Neely data
# to formally test the disease effect magnitude
if (requireNamespace("lme4", quietly = TRUE)) {
  library(lme4)

  neely_for_glmm <- neely_data %>%
    filter(!is.na(size_cm2), !is.na(survived)) %>%
    mutate(log_size = log(size_cm2))

  glmm_neely <- glmer(
    survived ~ log_size + is_disease_2014 + (1 | coral_id),
    data = neely_for_glmm,
    family = binomial,
    control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 20000))
  )

  # Overdispersion check
  od <- overdisp_test(glmm_neely)
  cat(sprintf("  GLMM overdispersion ratio: %.3f (p = %.4f) — %s\n",
              od$ratio, od$p_value,
              ifelse(od$overdispersed, "OVERDISPERSED", "OK")))

  cat("\n  GLMM fixed effects:\n")
  print(summary(glmm_neely)$coefficients)

  # Disease effect on probability scale
  coefs <- fixef(glmm_neely)
  disease_logodds <- coefs["is_disease_2014TRUE"]
  disease_or <- exp(disease_logodds)
  cat(sprintf("\n  Disease 2014 effect: log-odds = %.3f, OR = %.3f\n",
              disease_logodds, disease_or))
  cat(sprintf("  Interpretation: disease reduces odds of survival by %.1f%%\n",
              (1 - disease_or) * 100))
} else {
  print_warn("lme4 not available — skipping GLMM check")
}

# ==============================================================================
# SUMMARY
# ==============================================================================

print_header("DISTURBANCE SENSITIVITY ANALYSIS COMPLETE")

cat("  Key findings:\n")
if (!is.null(meta_full) && !is.null(meta_no_disease)) {
  delta_pooled <- (meta_no_disease$pooled_surv - meta_full$pooled_surv) * 100
  cat(sprintf("  - Excluding disease intervals shifts pooled survival by %+.1f pp\n",
              delta_pooled))
  cat(sprintf("  - Full data pooled: %.1f%% vs Excl. disease: %.1f%%\n",
              meta_full$pooled_surv * 100, meta_no_disease$pooled_surv * 100))
  cat(sprintf("  - I2 change: %.1f%% -> %.1f%%\n", meta_full$I2, meta_no_disease$I2))
}
cat(sprintf("  - Neely all intervals: %.1f%% survival (n=%d)\n",
            mean(neely_data$survived) * 100, nrow(neely_data)))
cat(sprintf("  - Neely non-disturbance: %.1f%% survival (n=%d)\n",
            mean(neely_data$survived[!neely_data$is_disease_2014]) * 100,
            sum(!neely_data$is_disease_2014)))
cat(sprintf("  - Disease 2014 intervals: %.1f%% survival (n=%d)\n",
            mean(neely_data$survived[neely_data$disturbance == "disease_2014" & !is.na(neely_data$disturbance)]) * 100,
            sum(neely_data$disturbance == "disease_2014", na.rm = TRUE)))

cat("\n  Outputs saved to 06_analysis/output/:\n")
cat("    - disturbance_sensitivity_summary.csv\n")
cat("    - disturbance_interval_comparison.csv\n")
cat("  Figure saved to 06_analysis/figures/supplementary/:\n")
cat("    - FigSXX_disturbance_sensitivity.png/pdf\n\n")
