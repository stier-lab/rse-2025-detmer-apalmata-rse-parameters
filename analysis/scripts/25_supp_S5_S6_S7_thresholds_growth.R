#!/usr/bin/env Rscript
################################################################################
# 25_SUPP_S5_S6_S7_THRESHOLDS_GROWTH.R
# Supplementary Figures S5, S6, S7 for Coral Reefs manuscript
################################################################################
#
# PURPOSE: Generate journal-ready supplementary figures showing threshold
#          detection results, AGR vs RGR comparison, and allometric analysis.
#
# FIGURES:
#   FigS5_threshold_analysis.png  -- 3-panel: survival gate, P(+growth), RGR derivative
#   FigS6_agr_vs_rgr.png         -- 4-panel: AGR vs size, RGR vs size, P(+growth), heteroscedasticity
#   FigS7_allometry.png           -- 4-panel: overall, by study, nat/rest, size ranges
#
# INPUTS (pre-computed by scripts 02, 03, 04):
#   - analysis/output/survival_threshold_models.rds
#   - analysis/output/growth_threshold_models.rds
#   - analysis/output/growth_rate_analysis.rds
#   - analysis/output/prepared_survival_data.rds
#   - analysis/output/prepared_growth_data.rds
#   - analysis/output/survival_thresholds.csv
#   - analysis/output/growth_thresholds.csv
#   - analysis/output/allometry_by_study.csv
#
# OUTPUTS:
#   - analysis/figures/supplementary/FigS5_threshold_analysis.{png,pdf}
#   - analysis/figures/supplementary/FigS6_agr_vs_rgr.{png,pdf}
#   - analysis/figures/supplementary/FigS7_allometry.{png,pdf}
#
# JOURNAL: Coral Reefs (Springer)
#   Width: 174 mm (double-column), max height 234 mm, 300 DPI
#   Font: Helvetica/sans, 8-12 pt
#   Panel labels: lowercase a, b, c, d via plot_annotation(tag_levels = "a")
#
# Author: Detmer & Stier Lab
# Date: 2026-02
################################################################################

suppressPackageStartupMessages({
  library(tidyverse)
  library(patchwork)
  library(mgcv)
  library(scales)
})

# Source shared utilities
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("analysis/scripts/utils/shared_utilities.R")) {
  source("analysis/scripts/utils/shared_utilities.R")
}

pal <- MANUSCRIPT_PALETTE
project_root <- get_project_root()
output_dir   <- file.path(project_root, "analysis/output")
fig_dir      <- file.path(project_root, "analysis/figures/supplementary")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

cat("\n")
cat("================================================================\n")
cat("  SUPPLEMENTARY FIGURES S5, S6, S7\n")
cat("  Threshold Detection, AGR vs RGR, Allometry\n")
cat("================================================================\n\n")

# =============================================================================
# STUDY NAME FORMATTING
# =============================================================================

# Clean study names for publication display
format_study_name <- function(x) {
  x <- gsub("_", " ", x)
  x <- gsub("NOAA survey", "NOAA Survey", x)
  x <- gsub("USGS USVI exp", "USGS USVI", x)
  x <- gsub("fundemar fragments", "FUNDEMAR", x)
  x <- gsub("pausch et al 2018", "Pausch et al. 2018", x)
  x <- gsub("kuffner et al 2020", "Kuffner et al. 2020", x)
  x <- gsub("mendoza quiroz et al 2023", "Mendoza-Quiroz et al. 2023", x)
  x
}

# =============================================================================
# LOAD DATA
# =============================================================================

cat("Loading pre-computed results...\n")

# Survival threshold models (from script 02)
surv_models <- readRDS(file.path(output_dir, "survival_threshold_models.rds"))
surv_thresh <- read_csv(file.path(output_dir, "survival_thresholds.csv"),
                         show_col_types = FALSE)

# Growth threshold models (from script 03)
growth_models <- readRDS(file.path(output_dir, "growth_threshold_models.rds"))
growth_thresh <- read_csv(file.path(output_dir, "growth_thresholds.csv"),
                           show_col_types = FALSE)

# Growth rate analysis (from script 04)
growth_analysis <- readRDS(file.path(output_dir, "growth_rate_analysis.rds"))

# Raw data
surv_data    <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data  <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

# Allometry results
allometry_by_study <- read_csv(file.path(output_dir, "allometry_by_study.csv"),
                                show_col_types = FALSE)

cat("  All data loaded successfully.\n\n")

# =============================================================================
# DATA PREPARATION (shared across figures)
# =============================================================================

# Natural colony subset for survival
surv_natural <- surv_data %>% filter(population_type == "Natural colony")

# Clean growth data (matching script 04 filtering)
growth_clean <- growth_data %>%
  filter(!is.na(size_cm2), size_cm2 > 0, !is.na(growth_cm2_yr))

if ("impossible_growth" %in% names(growth_clean)) {
  growth_clean <- growth_clean %>% filter(!impossible_growth)
}

growth_clean <- growth_clean %>%
  mutate(
    log_size = log(size_cm2),
    agr = growth_cm2_yr,
    rgr = growth_cm2_yr / size_cm2,
    pct_change = (growth_cm2_yr / size_cm2) * 100,
    positive_growth = as.integer(growth_cm2_yr > 0),
    population_type = if ("population_type" %in% names(.)) population_type else
      case_when(
        fragment == "Y" ~ "Restoration fragment",
        fragment == "N" ~ "Natural colony",
        TRUE ~ "Unknown"
      )
  )

# RGR outlier trim (matching script 04)
rgr_bounds <- quantile(growth_clean$rgr, c(0.005, 0.995), na.rm = TRUE)
growth_clean <- growth_clean %>%
  filter(rgr >= rgr_bounds[1] & rgr <= rgr_bounds[2])

# Exclude high-variance regions (Navassa)
if ("high_variance_region" %in% names(growth_clean)) {
  growth_clean <- growth_clean %>% filter(!high_variance_region)
} else if (sum(growth_clean$region == "Navassa", na.rm = TRUE) > 0) {
  growth_clean <- growth_clean %>% filter(region != "Navassa")
}

# Add final_size for allometry
growth_clean <- growth_clean %>%
  mutate(
    final_size = pmax(size_cm2 + growth_cm2_yr, 1),
    log_final_size = log(final_size)
  )

cat(sprintf("  Survival (natural): n = %d\n", nrow(surv_natural)))
cat(sprintf("  Growth (clean):     n = %d\n", nrow(growth_clean)))

# =============================================================================
# SHARED AXIS HELPERS
# =============================================================================

# Dual x-axis: log_size with cm2 secondary
# Use well-spaced breaks that do not overlap at 174mm / 3 panels
log_size_axis <- function(sec_breaks = c(10, 1000, 100000),
                          sec_labels = c("10", "1 000", "100 000")) {
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(
      ~ exp(.),
      name = expression(paste("Colony size (cm"^2, ")")),
      breaks = sec_breaks,
      labels = sec_labels
    )
  )
}

# =============================================================================
# FIGURE S5: THRESHOLD ANALYSIS (3-panel)
# =============================================================================

cat("Generating Figure S5: Threshold analysis...\n")

# --- Panel (a): Survival gate / GAM smooth with CI ---
# The survival gate test failed (delta AICc = 0.83 < 2), meaning the GAM
# is not significantly better than a linear model. Show the GAM smooth
# with CI and annotate the gate result.

surv_gate_delta <- surv_thresh$gate_delta_aicc[1]
surv_gate_passed <- surv_thresh$gate_passed[1]

# Extract survival GAM model & prediction grid
surv_gam <- surv_models$gam_model
surv_pred <- surv_models$prediction_grid

# Build prediction with SE if not already present
if (!"gam_lower" %in% names(surv_pred)) {
  pred_se <- predict(surv_gam, newdata = surv_pred, type = "link", se.fit = TRUE)
  surv_pred$gam_lower <- plogis(pred_se$fit - 1.96 * pred_se$se.fit)
  surv_pred$gam_upper <- plogis(pred_se$fit + 1.96 * pred_se$se.fit)
  surv_pred$gam <- plogis(pred_se$fit)
}

fig_s5a <- ggplot() +
  stat_summary_bin(
    data = surv_natural,
    aes(x = log_size, y = survived),
    fun = mean,
    fun.min = function(x) mean(x) - 1.96 * sqrt(mean(x) * (1 - mean(x)) / max(length(x), 1)),
    fun.max = function(x) min(1, mean(x) + 1.96 * sqrt(mean(x) * (1 - mean(x)) / max(length(x), 1))),
    geom = "pointrange",
    bins = 20,
    alpha = 0.6,
    size = 0.3,
    color = pal$slate_mid
  ) +
  geom_ribbon(
    data = surv_pred,
    aes(x = log_size, ymin = gam_lower, ymax = gam_upper),
    alpha = 0.2, fill = pal$surv_mid
  ) +
  geom_line(
    data = surv_pred,
    aes(x = log_size, y = gam),
    color = pal$surv_mid, linewidth = 0.9
  ) +
  # GLM (linear) line for comparison
  geom_line(
    data = surv_pred,
    aes(x = log_size, y = glm),
    color = pal$slate_mid, linewidth = 0.6, linetype = "dotted"
  ) +
  # Annotate gate result
  annotate(
    "label",
    x = min(surv_pred$log_size) + 0.3,
    y = 0.15,
    label = sprintf("Gate: \u0394AICc = %.2f\n(threshold = 2)", surv_gate_delta),
    size = 2.5, hjust = 0, vjust = 0,
    fill = "white", alpha = 0.85,
    label.r = unit(1, "mm"),
    color = pal$slate_dark, family = "sans"
  ) +
  log_size_axis() +
  scale_y_continuous(
    name = "Annual survival probability",
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2)
  ) +
  theme_manuscript(base_size = 9) +
  theme(
    axis.title.x.top = element_text(size = 7),
    plot.margin = margin(5, 8, 5, 5, "mm")
  )

# --- Panel (b): P(positive growth) vs size with dome-shape threshold ---

# Extract P(+growth) results from growth models
pos_thresh_row <- growth_thresh %>% filter(response == "positive_growth_prob")
pos_thresh_cm2 <- pos_thresh_row$recommended_threshold_cm2[1]
pos_thresh_log <- pos_thresh_row$recommended_threshold_log[1]

# Get GAM model for P(+growth) from growth_models
pos_gam <- growth_models$model_pos_growth
pos_pred_grid <- growth_models$prediction_grid

# Build prediction with SE if needed
if (!"prob_pos_lower" %in% names(pos_pred_grid)) {
  pos_se <- predict(pos_gam, newdata = pos_pred_grid, type = "link", se.fit = TRUE)
  pos_pred_grid$prob_pos_lower <- plogis(pos_se$fit - 1.96 * pos_se$se.fit)
  pos_pred_grid$prob_pos_upper <- plogis(pos_se$fit + 1.96 * pos_se$se.fit)
  if (!"prob_positive" %in% names(pos_pred_grid)) {
    pos_pred_grid$prob_positive <- plogis(pos_se$fit)
  }
}

fig_s5b <- ggplot() +
  stat_summary_bin(
    data = growth_clean,
    aes(x = log_size, y = positive_growth),
    fun = mean,
    fun.min = function(x) mean(x) - 1.96 * sqrt(mean(x) * (1 - mean(x)) / max(length(x), 1)),
    fun.max = function(x) min(1, mean(x) + 1.96 * sqrt(mean(x) * (1 - mean(x)) / max(length(x), 1))),
    geom = "pointrange",
    bins = 20,
    alpha = 0.6,
    size = 0.3,
    color = pal$slate_mid
  ) +
  geom_ribbon(
    data = pos_pred_grid,
    aes(x = log_size,
        ymin = prob_pos_lower,
        ymax = prob_pos_upper),
    alpha = 0.2, fill = pal$grow_mid
  ) +
  geom_line(
    data = pos_pred_grid,
    aes(x = log_size, y = prob_positive),
    color = pal$grow_mid, linewidth = 0.9
  ) +
  {
    if (!is.na(pos_thresh_log))
      geom_vline(xintercept = pos_thresh_log, linetype = "dashed",
                 color = pal$accent, linewidth = 0.6)
  } +
  {
    if (!is.na(pos_thresh_cm2))
      annotate("label",
               x = pos_thresh_log + 0.2,
               y = 0.10,
               label = sprintf("T = %.0f cm\u00B2", pos_thresh_cm2),
               size = 2.5, hjust = 0,
               fill = "white", alpha = 0.85,
               label.r = unit(1, "mm"),
               color = pal$accent, family = "sans")
  } +
  log_size_axis() +
  scale_y_continuous(
    name = "P(positive growth)",
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2)
  ) +
  theme_manuscript(base_size = 9) +
  theme(
    axis.title.x.top = element_text(size = 7),
    plot.margin = margin(5, 8, 5, 5, "mm")
  )

# --- Panel (c): RGR second derivative profile ---

rgr_thresh_row <- growth_thresh %>% filter(response == "relative_growth_rate")
rgr_thresh_log <- rgr_thresh_row$recommended_threshold_log[1]
rgr_thresh_cm2 <- rgr_thresh_row$recommended_threshold_cm2[1]

# Extract derivative data from growth_models
rgr_deriv_df <- growth_models$rgr_results$derivatives

fig_s5c <- if (!is.null(rgr_deriv_df)) {
  ggplot(rgr_deriv_df, aes(x = x)) +
    geom_ribbon(aes(ymin = d2_lower, ymax = d2_upper),
                alpha = 0.2, fill = pal$grow_mid) +
    geom_line(aes(y = d2), color = pal$grow_mid, linewidth = 0.9) +
    geom_hline(yintercept = 0, linetype = "dotted", color = "grey60", linewidth = 0.4) +
    {
      if (!is.na(rgr_thresh_log))
        geom_vline(xintercept = rgr_thresh_log, linetype = "dashed",
                   color = pal$accent, linewidth = 0.6)
    } +
    {
      if (!is.na(rgr_thresh_cm2))
        annotate("label",
                 x = rgr_thresh_log + 0.15,
                 y = max(rgr_deriv_df$d2, na.rm = TRUE) * 0.85,
                 label = sprintf("T\u2082 = %.0f cm\u00B2", rgr_thresh_cm2),
                 size = 2.5, hjust = 0,
                 fill = "white", alpha = 0.85,
                 label.r = unit(1, "mm"),
                 color = pal$accent, family = "sans")
    } +
    log_size_axis() +
    scale_y_continuous(name = expression("Second derivative s''(x)")) +
    theme_manuscript(base_size = 9) +
    theme(
      axis.title.x.top = element_text(size = 7),
      plot.margin = margin(5, 8, 5, 5, "mm")
    )
} else {
  ggplot() +
    annotate("text", x = 0.5, y = 0.5, label = "RGR derivatives unavailable",
             size = 4) +
    theme_void()
}

# Combine S5 with lowercase panel labels
fig_s5 <- fig_s5a + fig_s5b + fig_s5c +
  plot_layout(ncol = 3, widths = c(1, 1, 1)) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 11, face = "bold", family = "sans"))

save_manuscript_fig(fig_s5, "FigS5_threshold_analysis",
                    width_mm = 174, height_mm = 80,
                    fig_dir = fig_dir)
cat("  Done: FigS5_threshold_analysis\n")

# =============================================================================
# FIGURE S6: AGR vs RGR COMPARISON (2x2)
# =============================================================================

cat("Generating Figure S6: AGR vs RGR comparison...\n")

# Build prediction grids from GAMs (refit from clean data to ensure consistency)
pred_grid_s6 <- data.frame(
  log_size = seq(min(growth_clean$log_size), max(growth_clean$log_size),
                 length.out = 200)
)

# AGR GAM
agr_gam <- gam(agr ~ s(log_size, k = 3), data = growth_clean, method = "REML")
agr_se <- predict(agr_gam, newdata = pred_grid_s6, se.fit = TRUE)
pred_grid_s6$agr_fit      <- agr_se$fit
pred_grid_s6$agr_ci_lower <- agr_se$fit - 1.96 * agr_se$se.fit
pred_grid_s6$agr_ci_upper <- agr_se$fit + 1.96 * agr_se$se.fit
agr_r2 <- summary(agr_gam)$r.sq

# RGR GAM
rgr_gam <- gam(rgr ~ s(log_size, k = 3), data = growth_clean, method = "REML")
rgr_se <- predict(rgr_gam, newdata = pred_grid_s6, se.fit = TRUE)
pred_grid_s6$rgr_fit      <- rgr_se$fit
pred_grid_s6$rgr_ci_lower <- rgr_se$fit - 1.96 * rgr_se$se.fit
pred_grid_s6$rgr_ci_upper <- rgr_se$fit + 1.96 * rgr_se$se.fit
rgr_r2 <- summary(rgr_gam)$r.sq

# P(+growth) GAM
pos_gam_s6 <- gam(positive_growth ~ s(log_size, k = 3),
                   data = growth_clean, family = binomial, method = "REML")
pos_link_se <- predict(pos_gam_s6, newdata = pred_grid_s6, type = "link", se.fit = TRUE)
pred_grid_s6$pos_fit      <- plogis(pos_link_se$fit) * 100
pred_grid_s6$pos_ci_lower <- plogis(pos_link_se$fit - 1.96 * pos_link_se$se.fit) * 100
pred_grid_s6$pos_ci_upper <- plogis(pos_link_se$fit + 1.96 * pos_link_se$se.fit) * 100
pos_dev <- summary(pos_gam_s6)$dev.expl

# --- Panel (a): AGR vs size ---
fig_s6a <- ggplot() +
  geom_point(data = growth_clean, aes(x = log_size, y = agr),
             alpha = 0.08, size = 0.3, color = pal$slate_light) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey60", linewidth = 0.3) +
  geom_ribbon(data = pred_grid_s6,
              aes(x = log_size, ymin = agr_ci_lower, ymax = agr_ci_upper),
              alpha = 0.2, fill = pal$surv_mid) +
  geom_line(data = pred_grid_s6,
            aes(x = log_size, y = agr_fit),
            color = pal$surv_mid, linewidth = 0.8) +
  annotate("label",
           x = max(pred_grid_s6$log_size) - 0.3,
           y = quantile(growth_clean$agr, 0.02, na.rm = TRUE),
           label = sprintf("R\u00B2 = %.1f%%", agr_r2 * 100),
           size = 2.8, hjust = 1,
           fill = "white", alpha = 0.85,
           label.r = unit(1, "mm"),
           color = pal$slate_dark, family = "sans") +
  log_size_axis() +
  coord_cartesian(ylim = quantile(growth_clean$agr, c(0.01, 0.99), na.rm = TRUE)) +
  scale_y_continuous(name = expression(paste("AGR (cm"^2, " yr"^-1, ")"))) +
  theme_manuscript(base_size = 9) +
  theme(
    axis.title.x.top = element_text(size = 7),
    plot.margin = margin(5, 6, 3, 5, "mm")
  )

# --- Panel (b): RGR vs size ---
fig_s6b <- ggplot() +
  geom_point(data = growth_clean, aes(x = log_size, y = rgr),
             alpha = 0.08, size = 0.3, color = pal$slate_light) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey60", linewidth = 0.3) +
  geom_ribbon(data = pred_grid_s6,
              aes(x = log_size, ymin = rgr_ci_lower, ymax = rgr_ci_upper),
              alpha = 0.2, fill = pal$grow_mid) +
  geom_line(data = pred_grid_s6,
            aes(x = log_size, y = rgr_fit),
            color = pal$grow_mid, linewidth = 0.8) +
  annotate("label",
           x = max(pred_grid_s6$log_size) - 0.3,
           y = quantile(growth_clean$rgr, 0.02, na.rm = TRUE),
           label = sprintf("R\u00B2 = %.1f%%", rgr_r2 * 100),
           size = 2.8, hjust = 1,
           fill = "white", alpha = 0.85,
           label.r = unit(1, "mm"),
           color = pal$slate_dark, family = "sans") +
  log_size_axis() +
  coord_cartesian(ylim = quantile(growth_clean$rgr, c(0.01, 0.99), na.rm = TRUE)) +
  scale_y_continuous(name = expression(paste("RGR (yr"^-1, ")"))) +
  theme_manuscript(base_size = 9) +
  theme(
    axis.title.x.top = element_text(size = 7),
    plot.margin = margin(5, 6, 3, 5, "mm")
  )

# --- Panel (c): P(positive growth) vs size ---
fig_s6c <- ggplot() +
  stat_summary_bin(
    data = growth_clean,
    aes(x = log_size, y = positive_growth * 100),
    fun = mean,
    fun.min = function(x) {
      p <- mean(x) / 100
      (p - 1.96 * sqrt(p * (1 - p) / max(length(x), 1))) * 100
    },
    fun.max = function(x) {
      p <- mean(x) / 100
      min(100, (p + 1.96 * sqrt(p * (1 - p) / max(length(x), 1))) * 100)
    },
    geom = "pointrange",
    bins = 20,
    alpha = 0.5,
    size = 0.25,
    color = pal$slate_mid
  ) +
  geom_ribbon(data = pred_grid_s6,
              aes(x = log_size, ymin = pos_ci_lower, ymax = pos_ci_upper),
              alpha = 0.2, fill = pal$grow_mid) +
  geom_line(data = pred_grid_s6,
            aes(x = log_size, y = pos_fit),
            color = pal$grow_mid, linewidth = 0.8) +
  annotate("label",
           x = min(pred_grid_s6$log_size) + 0.3,
           y = 20,
           label = sprintf("Dev. expl. = %.1f%%", pos_dev * 100),
           size = 2.8, hjust = 0,
           fill = "white", alpha = 0.85,
           label.r = unit(1, "mm"),
           color = pal$slate_dark, family = "sans") +
  log_size_axis() +
  scale_y_continuous(name = "P(positive growth) (%)",
                     limits = c(0, 100), breaks = seq(0, 100, 20)) +
  theme_manuscript(base_size = 9) +
  theme(
    axis.title.x.top = element_text(size = 7),
    plot.margin = margin(5, 6, 3, 5, "mm")
  )

# --- Panel (d): Residual heteroscedasticity comparison ---
# Show AGR vs RGR variance by size bin

# Compute binned variance
var_comparison <- growth_clean %>%
  mutate(size_bin_idx = ntile(log_size, 10)) %>%
  group_by(size_bin_idx) %>%
  summarise(
    log_size_mid = mean(log_size, na.rm = TRUE),
    agr_sd = sd(agr, na.rm = TRUE),
    rgr_sd = sd(rgr, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  filter(!is.na(log_size_mid))

# Pivot for plotting
var_long <- var_comparison %>%
  pivot_longer(
    cols = c(agr_sd, rgr_sd),
    names_to = "metric",
    values_to = "sd"
  ) %>%
  mutate(
    metric = recode(metric,
                    "agr_sd" = "AGR",
                    "rgr_sd" = "RGR")
  )

fig_s6d <- ggplot(var_long, aes(x = log_size_mid, y = sd, color = metric)) +
  geom_point(size = 1.5, alpha = 0.8) +
  geom_line(linewidth = 0.7, alpha = 0.8) +
  scale_color_manual(
    values = c("AGR" = pal$surv_mid, "RGR" = pal$grow_mid),
    name = NULL
  ) +
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(
      ~ exp(.),
      name = expression(paste("Colony size (cm"^2, ")")),
      breaks = c(100, 10000),
      labels = c("100", "10 000")
    )
  ) +
  scale_y_log10(
    name = "SD by size bin (log scale)",
    labels = label_comma()
  ) +
  theme_manuscript(base_size = 9) +
  theme(
    axis.title.x.top = element_text(size = 7),
    legend.position = c(0.15, 0.15),
    legend.background = element_rect(fill = "white", color = NA),
    legend.key.size = unit(3, "mm"),
    legend.text = element_text(size = 8),
    plot.margin = margin(5, 6, 3, 5, "mm")
  )

# Combine S6 (2x2) with lowercase panel labels
fig_s6 <- (fig_s6a + fig_s6b) / (fig_s6c + fig_s6d) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 11, face = "bold", family = "sans"))

save_manuscript_fig(fig_s6, "FigS6_agr_vs_rgr",
                    width_mm = 174, height_mm = 155,
                    fig_dir = fig_dir)
cat("  Done: FigS6_agr_vs_rgr\n")

# =============================================================================
# FIGURE S7: ALLOMETRY (2x2)
# =============================================================================

cat("Generating Figure S7: Allometry...\n")

# --- Panel (a): Overall allometric scaling (log-log) ---
allometry_model <- lm(log_final_size ~ log_size, data = growth_clean)
allom_slope <- coef(allometry_model)[2]
allom_r2 <- summary(allometry_model)$r.squared
allom_intercept <- coef(allometry_model)[1]

pred_allom <- data.frame(
  log_size = seq(min(growth_clean$log_size),
                 max(growth_clean$log_size), length.out = 200)
)
pred_allom$fit <- predict(allometry_model, newdata = pred_allom)

fig_s7a <- ggplot(growth_clean, aes(x = log_size, y = log_final_size)) +
  geom_point(alpha = 0.06, size = 0.3, color = pal$slate_light) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed",
              color = "grey60", linewidth = 0.4) +
  geom_line(data = pred_allom, aes(x = log_size, y = fit),
            color = pal$surv_dark, linewidth = 0.8) +
  annotate("label",
           x = min(growth_clean$log_size) + 0.3,
           y = max(growth_clean$log_final_size, na.rm = TRUE) - 0.5,
           label = sprintf("slope = %.3f\nR\u00B2 = %.1f%%", allom_slope, allom_r2 * 100),
           size = 2.8, hjust = 0, vjust = 1,
           fill = "white", alpha = 0.85,
           label.r = unit(1, "mm"),
           color = pal$slate_dark, family = "sans") +
  coord_equal(ratio = 1) +
  scale_x_continuous(name = expression(paste("Log initial size (log cm"^2, ")"))) +
  scale_y_continuous(name = expression(paste("Log final size (log cm"^2, ")"))) +
  theme_manuscript(base_size = 9) +
  theme(
    plot.margin = margin(5, 6, 3, 5, "mm")
  )

# --- Panel (b): Scaling by study ---
study_colors <- OKABE_ITO[seq_len(min(nrow(allometry_by_study), 7))]
names(study_colors) <- allometry_by_study$study[seq_len(min(nrow(allometry_by_study), 7))]

# Clean study names for display
allometry_display <- allometry_by_study %>%
  mutate(study_label = format_study_name(study))

# Plot allometric slopes with CIs as forest-style
fig_s7b <- ggplot(allometry_display,
                  aes(x = slope, y = reorder(study_label, slope))) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey60", linewidth = 0.4) +
  geom_vline(xintercept = allom_slope, linetype = "solid",
             color = pal$surv_dark, linewidth = 0.5) +
  geom_linerange(
    aes(xmin = ci_lower, xmax = ci_upper),
    linewidth = 0.5, color = pal$slate_mid
  ) +
  geom_point(aes(size = n), color = pal$surv_dark, shape = 16) +
  scale_size_continuous(range = c(1.5, 4), name = "n",
                        guide = guide_legend(override.aes = list(alpha = 1))) +
  scale_x_continuous(name = "Allometric slope (log-log)") +
  scale_y_discrete(name = NULL) +
  theme_manuscript(base_size = 9) +
  theme(
    legend.position = c(0.88, 0.25),
    legend.background = element_rect(fill = "white", color = NA, linewidth = 0),
    legend.key.size = unit(3, "mm"),
    legend.text = element_text(size = 7),
    legend.title = element_text(size = 7),
    axis.text.y = element_text(size = 8),
    plot.margin = margin(5, 6, 3, 5, "mm")
  )

# --- Panel (c): Natural vs restored allometry ---
allometry_by_type <- growth_clean %>%
  group_by(population_type) %>%
  filter(n() >= 30) %>%
  nest() %>%
  mutate(result = map(data, function(d) {
    mod <- lm(log_final_size ~ log_size, data = d)
    pred_df <- data.frame(
      log_size = seq(min(d$log_size), max(d$log_size), length.out = 100)
    )
    pred_df$fit <- predict(mod, newdata = pred_df)
    list(
      slope = coef(mod)[2],
      intercept = coef(mod)[1],
      r_squared = summary(mod)$r.squared,
      n = nrow(d),
      predictions = pred_df
    )
  })) %>%
  select(-data)

# Extract predictions for overlay
type_preds <- allometry_by_type %>%
  mutate(preds = map(result, ~ .x$predictions)) %>%
  select(population_type, preds) %>%
  unnest(preds)

type_stats <- allometry_by_type %>%
  mutate(
    slope = map_dbl(result, ~ .x$slope),
    r2 = map_dbl(result, ~ .x$r_squared),
    n = map_int(result, ~ .x$n)
  ) %>%
  select(population_type, slope, r2, n)

fig_s7c <- ggplot() +
  geom_point(data = growth_clean,
             aes(x = log_size, y = log_final_size, color = population_type),
             alpha = 0.04, size = 0.3) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed",
              color = "grey60", linewidth = 0.4) +
  geom_line(data = type_preds,
            aes(x = log_size, y = fit, color = population_type),
            linewidth = 0.8) +
  scale_color_manual(
    values = c("Natural colony" = pal$natural,
               "Restoration fragment" = pal$restoration),
    labels = c("Natural colony" = "Natural",
               "Restoration fragment" = "Restoration"),
    name = NULL
  ) +
  coord_equal(ratio = 1) +
  scale_x_continuous(name = expression(paste("Log initial size (log cm"^2, ")"))) +
  scale_y_continuous(name = expression(paste("Log final size (log cm"^2, ")"))) +
  theme_manuscript(base_size = 9) +
  theme(
    legend.position = c(0.25, 0.88),
    legend.background = element_rect(fill = "white", color = NA),
    legend.key.size = unit(3, "mm"),
    legend.text = element_text(size = 8),
    plot.margin = margin(5, 6, 3, 5, "mm")
  )

# --- Panel (d): Size ranges by study ---
size_ranges <- growth_clean %>%
  group_by(study) %>%
  summarise(
    n = n(),
    min_size = min(size_cm2, na.rm = TRUE),
    max_size = max(size_cm2, na.rm = TRUE),
    median_size = median(size_cm2, na.rm = TRUE),
    q25 = quantile(size_cm2, 0.25, na.rm = TRUE),
    q75 = quantile(size_cm2, 0.75, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(study_label = format_study_name(study)) %>%
  arrange(median_size)

fig_s7d <- ggplot(size_ranges,
                  aes(y = reorder(study_label, median_size))) +
  geom_segment(aes(x = min_size, xend = max_size,
                   yend = reorder(study_label, median_size)),
               linewidth = 0.6, color = pal$slate_light) +
  geom_linerange(aes(xmin = q25, xmax = q75),
                 linewidth = 0.8, color = pal$slate_mid) +
  geom_point(aes(x = median_size, size = n),
             color = pal$surv_dark, shape = 16) +
  scale_x_log10(
    name = expression(paste("Colony size (cm"^2, ")")),
    breaks = c(1, 100, 10000),
    labels = c("1", "100", "10 000"),
    limits = c(1, 200000)
  ) +
  scale_y_discrete(name = NULL) +
  scale_size_continuous(range = c(1.5, 4), name = "n",
                        guide = guide_legend(override.aes = list(alpha = 1))) +
  theme_manuscript(base_size = 9) +
  theme(
    legend.position = c(0.88, 0.25),
    legend.background = element_rect(fill = "white", color = NA, linewidth = 0),
    legend.key.size = unit(3, "mm"),
    legend.text = element_text(size = 7),
    legend.title = element_text(size = 7),
    axis.text.y = element_text(size = 8),
    plot.margin = margin(5, 6, 3, 5, "mm")
  )

# Combine S7 (2x2) with lowercase panel labels
fig_s7 <- (fig_s7a + fig_s7b) / (fig_s7c + fig_s7d) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 11, face = "bold", family = "sans"))

save_manuscript_fig(fig_s7, "FigS7_allometry",
                    width_mm = 174, height_mm = 160,
                    fig_dir = fig_dir)
cat("  Done: FigS7_allometry\n")

# =============================================================================
# SUMMARY
# =============================================================================

cat("\n")
cat("================================================================\n")
cat("  FIGURE GENERATION COMPLETE\n")
cat("================================================================\n")
cat("  FigS5_threshold_analysis  -- 174 x 80 mm  (3-panel horizontal)\n")
cat("  FigS6_agr_vs_rgr          -- 174 x 155 mm (2x2 grid)\n")
cat("  FigS7_allometry            -- 174 x 160 mm (2x2 grid)\n")
cat("  All at 300 DPI, PNG + PDF\n")
cat("  Panel labels: lowercase a, b, c, d\n")
cat("================================================================\n\n")
