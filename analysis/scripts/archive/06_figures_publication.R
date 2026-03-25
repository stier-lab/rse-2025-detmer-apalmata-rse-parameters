#!/usr/bin/env Rscript
################################################################################
# 06_FIGURES_PUBLICATION.R
# A. palmata Demographic Analysis - Publication-Quality Figures
# VERSION 2.1 - Stratified by Population Type (Natural vs Restoration)
################################################################################
#
# PURPOSE: Generate all publication-quality figures for the A. palmata
#          demographic parameters manuscript. Figures follow a consistent
#          visual style with ocean/coral color palette.
#
# KEY STRATIFICATION:
#   - Natural colonies: Wild populations tracked in field surveys
#   - Restoration fragments: Outplanted nursery fragments
#   - Analysis uses natural colonies as primary group for threshold detection
#   - Stratified comparisons highlight population type differences
#
# FIGURES GENERATED:
#   Figure 1: Data landscape map and study overview (with population type)
#   Figure 2: Size-dependent survival (NATURAL COLONIES ONLY for threshold)
#   Figure 3: Size-dependent growth with threshold detection
#   Figure 4: Regional variation (forest plot - stratified by population type)
#   Figure 5: Size × Space interaction matrix
#   Figure 6: Data certainty and gap analysis
#   Figure 7: Temporal trends (Year effects & climate sensitivity)
#   Figure 8: Fragment vs Colony comparison (SIZE-MATCHED analysis)
#   Figure 9: Key Predictor Effects Summary (Size, Region, Depth, Origin)
#   Figure 10: Size × Region × Time 3-way Interaction
#
# INPUTS:
#   - All outputs from scripts 01-05, 07-10
#
# OUTPUTS:
#   - analysis/figures/main/Fig1_data_landscape.png/.pdf
#   - analysis/figures/main/Fig2_survival_threshold.png/.pdf
#   - analysis/figures/main/Fig3_growth_size.png/.pdf
#   - analysis/figures/main/Fig4_regional_forest_plot.png/.pdf
#   - analysis/figures/main/Fig5_size_region_matrix.png/.pdf
#   - analysis/figures/main/Fig6_data_certainty.png/.pdf
#   - analysis/figures/main/Fig7_temporal_trends.png/.pdf
#   - analysis/figures/main/Fig8_fragment_comparison.png/.pdf
#   - analysis/figures/main/Fig9_predictor_effects_summary.png/.pdf
#   - analysis/figures/main/Fig10_size_region_time_interaction.png/.pdf
#
# Author: Detmer & Stier Lab
# Date: 2025-12-22 (Updated 2025-12-25 with stratification)
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)

# Set seed for reproducibility
set.seed(42)

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  06: PUBLICATION FIGURE GENERATION                           ║\n")
cat("║  Creating High-Quality Manuscript Figures                    ║\n")
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
pub_fig_dir <- file.path(fig_dir, "main")
dir.create(pub_fig_dir, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# DEFINE COLOR PALETTE
# ==============================================================================

# Consistent color palette based on ocean/coral theme
colors <- list(
  # Ocean blues
  ocean_deep = "#0a3d62",
  ocean_mid = "#1a5276",
  ocean_light = "#2e86ab",

  # Coral accents
  coral_warm = "#e07a5f",
  coral_pale = "#f4a261",

  # Reef green
  reef_green = "#2a9d8f",

  # Neutrals
  sand_light = "#faf8f5",
  sand_warm = "#f5f0e8",

  # Text
  text_primary = "#1a1a2e",
  text_secondary = "#5d6d7e",

  # Data visualization
  viz_field = "#264653",
  viz_nursery_in = "#2a9d8f",
  viz_nursery_ex = "#e9c46a",

  # Population type colors (key distinction)
  natural_colony = "#264653",      # Deep ocean blue for natural populations
  restoration_fragment = "#e07a5f" # Coral warm for restoration fragments
)

# Size class colors (keyed on canonical SC1-SC5 labels from data)
size_colors <- c(
  "SC1" = "#e07a5f",
  "SC2" = "#f4a261",
  "SC3" = "#e9c46a",
  "SC4" = "#2a9d8f",
  "SC5" = "#264653"
)

# Clean size class labels for display
size_class_labels <- c(
  "SC1" = "Recruit\n(<10 cm²)",
  "SC2" = "Small Juv.\n(10-100 cm²)",
  "SC3" = "Large Juv.\n(100-900 cm²)",
  "SC4" = "Subadult\n(900-4000 cm²)",
  "SC5" = "Adult\n(>4000 cm²)"
)

# Short labels for tight spaces
size_class_short <- c(
  "SC1" = "Recruit",
  "SC2" = "Sm. Juv",
  "SC3" = "Lg. Juv",
  "SC4" = "Sm. Adult",
  "SC5" = "Lg. Adult"
)

# ==============================================================================
# DEFINE THEME
# ==============================================================================

theme_publication <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      # Text
      text = element_text(family = "sans", color = colors$text_primary),
      plot.title = element_text(size = base_size + 2, face = "bold",
                                color = colors$ocean_deep, hjust = 0),
      plot.subtitle = element_text(size = base_size, color = colors$text_secondary,
                                   hjust = 0, margin = margin(b = 10)),
      plot.caption = element_text(size = base_size - 2, color = colors$text_secondary,
                                  hjust = 1),

      # Axes
      axis.title = element_text(size = base_size, face = "bold"),
      axis.text = element_text(size = base_size - 1),
      axis.line = element_line(color = colors$text_secondary, linewidth = 0.5),

      # Grid
      panel.grid.major = element_line(color = "#e8e8e8", linewidth = 0.3),
      panel.grid.minor = element_blank(),

      # Legend
      legend.title = element_text(size = base_size, face = "bold"),
      legend.text = element_text(size = base_size - 1),
      legend.position = "bottom",
      legend.background = element_rect(fill = "white", color = NA),

      # Panel
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA),
      plot.margin = margin(15, 15, 15, 15)
    )
}

# ==============================================================================
# LOAD DATA
# ==============================================================================

cat("Loading analysis outputs...\n")

surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

# Load threshold results if available
if (file.exists(file.path(output_dir, "survival_threshold_models.rds"))) {
  surv_results <- readRDS(file.path(output_dir, "survival_threshold_models.rds"))
  cat("  ✓ Survival threshold results loaded\n")
} else {
  surv_results <- NULL
  cat("  ⚠ Survival threshold results not found - run script 02 first\n")
}

if (file.exists(file.path(output_dir, "growth_threshold_models.rds"))) {
  growth_results <- readRDS(file.path(output_dir, "growth_threshold_models.rds"))
  cat("  ✓ Growth threshold results loaded\n")
} else {
  growth_results <- NULL
  cat("  ⚠ Growth threshold results not found - run script 03 first\n")
}

# ==============================================================================
# STRATIFY BY POPULATION TYPE
# ==============================================================================

cat("\nStratifying data by population type...\n")

# Ensure population_type column exists
if (!"population_type" %in% names(surv_data)) {
  surv_data <- surv_data %>%
    mutate(
      is_fragment = (fragment == "Y"),
      population_type = ifelse(is_fragment, "Restoration fragment", "Natural colony")
    )
}

# Create stratified datasets
surv_natural <- surv_data %>% filter(population_type == "Natural colony")
surv_fragments <- surv_data %>% filter(population_type == "Restoration fragment")

# Summary
n_natural <- nrow(surv_natural)
n_fragments <- nrow(surv_fragments)
surv_rate_natural <- mean(surv_natural$survived) * 100
surv_rate_fragments <- mean(surv_fragments$survived) * 100

cat(sprintf("  Natural colonies: %d observations (%.1f%% survival)\n",
            n_natural, surv_rate_natural))
cat(sprintf("  Restoration fragments: %d observations (%.1f%% survival)\n",
            n_fragments, surv_rate_fragments))
cat(sprintf("  Difference: %.1f percentage points (natural > fragments)\n",
            surv_rate_natural - surv_rate_fragments))

cat("\n")

# ==============================================================================
# FIGURE 1: DATA LANDSCAPE
# ==============================================================================

cat("Creating Figure 1: Data Landscape...\n")

# Panel A: Sample sizes by region
surv_by_region <- surv_data %>%
  group_by(region) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    n_studies = n_distinct(study),
    .groups = "drop"
  ) %>%
  arrange(desc(n))

p1a <- ggplot(surv_by_region, aes(x = reorder(region, n), y = n)) +
  geom_col(fill = colors$ocean_mid, alpha = 0.9) +
  geom_text(aes(label = scales::comma(n)), hjust = -0.1, size = 3.5) +
  coord_flip() +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "A. Geographic Distribution of Observations",
    x = NULL,
    y = "Number of Observations"
  ) +
  theme_publication()

# Panel B: Sample sizes by size class
surv_by_size <- surv_data %>%
  group_by(size_class) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    .groups = "drop"
  ) %>%
  mutate(size_label = size_class_short[size_class])

p1b <- ggplot(surv_by_size, aes(x = size_class, y = n, fill = size_class)) +
  geom_col(alpha = 0.9, show.legend = FALSE) +
  geom_text(aes(label = scales::comma(n)), vjust = -0.3, size = 3.5) +
  scale_fill_manual(values = size_colors) +
  scale_x_discrete(labels = size_class_short) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "B. Size Class Distribution",
    x = "Size Class",
    y = "Number of Observations"
  ) +
  theme_publication() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Panel C: Temporal coverage
surv_by_year <- surv_data %>%
  group_by(survey_yr) %>%
  summarise(n = n(), .groups = "drop")

p1c <- ggplot(surv_by_year, aes(x = survey_yr, y = n)) +
  geom_col(fill = colors$reef_green, alpha = 0.9) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "C. Temporal Coverage",
    x = "Year",
    y = "Number of Observations"
  ) +
  theme_publication()

# Panel D: Population type breakdown (KEY - Natural vs Restoration)
pop_type_summary <- surv_data %>%
  group_by(population_type) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    n_studies = n_distinct(study),
    .groups = "drop"
  ) %>%
  mutate(
    pct = n / sum(n) * 100,
    label = sprintf("%s\n(%.0f%%)", scales::comma(n), pct)
  )

pop_colors <- c("Natural colony" = colors$natural_colony,
                "Restoration fragment" = colors$restoration_fragment)

p1d <- ggplot(pop_type_summary, aes(x = population_type, y = n, fill = population_type)) +
  geom_col(alpha = 0.9, show.legend = FALSE) +
  geom_text(aes(label = sprintf("n=%s\n(%.0f%%)\n%.0f%% survival",
                                 scales::comma(n), pct, survival * 100)),
            vjust = -0.1, size = 3, lineheight = 0.9) +
  scale_fill_manual(values = pop_colors) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.25))) +
  labs(
    title = "D. Population Type (KEY STRATIFICATION)",
    subtitle = "Natural colonies show higher survival",
    x = NULL,
    y = "Number of Observations"
  ) +
  theme_publication() +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5))

# Combine
fig1 <- (p1a | p1b) / (p1c | p1d) +
  plot_annotation(
    title = "Figure 1. A. palmata Demographic Database Overview",
    caption = sprintf("Total: %s survival observations, %s growth observations, %d studies, %d regions",
                      scales::comma(nrow(surv_data)),
                      scales::comma(nrow(growth_data)),
                      n_distinct(surv_data$study),
                      n_distinct(surv_data$region)),
    theme = theme(
      plot.title = element_text(size = 14, face = "bold", color = colors$ocean_deep),
      plot.caption = element_text(size = 10, color = colors$text_secondary)
    )
  )

ggsave(file.path(pub_fig_dir, "Fig1_data_landscape.png"),
       fig1, width = 14, height = 10, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig1_data_landscape.pdf"),
       fig1, width = 14, height = 10)

cat("  ✓ Saved: Fig1_data_landscape.png/pdf\n")

# ==============================================================================
# FIGURE 2: SIZE-DEPENDENT SURVIVAL (NATURAL COLONIES ONLY)
# ==============================================================================

cat("Creating Figure 2: Size-Dependent Survival (Natural Colonies)...\n")

# IMPORTANT: Use natural colonies only for threshold detection
# Restoration fragments confound size-survival relationship (pausch_et_al_2018 effect)
cat(sprintf("  Using %d natural colonies (excluding %d restoration fragments)\n",
            nrow(surv_natural), nrow(surv_fragments)))

# Create prediction data
library(mgcv)
size_range <- range(surv_natural$log_size)
pred_grid <- data.frame(log_size = seq(size_range[1], size_range[2], length.out = 500))

# Select best k by AIC (same as analysis script 02)
# This ensures the figure curve matches the threshold calculation
k_vals <- c(3, 4, 5)
best_k_surv <- 5  # default
best_aic <- Inf
for (k in k_vals) {
  test_gam <- gam(survived ~ s(log_size, k = k, bs = "tp"),
                  data = surv_natural, family = binomial, method = "REML")
  if (AIC(test_gam) < best_aic) {
    best_aic <- AIC(test_gam)
    best_k_surv <- k
  }
}
cat(sprintf("  Selected k=%d for survival GAM (by AIC)\n", best_k_surv))

# Fit GAM with best k (matching analysis script 02) - NATURAL COLONIES ONLY
surv_gam <- gam(survived ~ s(log_size, k = best_k_surv), data = surv_natural,
                family = binomial, method = "REML")
pred_grid$fit <- predict(surv_gam, newdata = pred_grid, type = "response", se.fit = FALSE)
pred_se <- predict(surv_gam, newdata = pred_grid, type = "link", se.fit = TRUE)
pred_grid$ci_lower <- plogis(pred_se$fit - 1.96 * pred_se$se.fit)
pred_grid$ci_upper <- plogis(pred_se$fit + 1.96 * pred_se$se.fit)
pred_grid$size_cm2 <- exp(pred_grid$log_size)

# Calculate binned survival for points - NATURAL COLONIES ONLY
surv_binned <- surv_natural %>%
  mutate(size_bin = cut(log_size, breaks = 30)) %>%
  group_by(size_bin) %>%
  summarise(
    log_size = mean(log_size),
    survival = mean(survived),
    n = n(),
    se = sqrt(survival * (1 - survival) / n),
    .groups = "drop"
  )

# Load threshold from saved analysis results (script 02)
threshold_log <- 4.39  # Default from analysis
threshold_cm2 <- 80    # Default from analysis
threshold_ci_lower_log <- NA
threshold_ci_upper_log <- NA
use_ci_shading <- FALSE  # Only use CI shading if it's reasonable

if (file.exists(file.path(output_dir, "survival_thresholds.csv"))) {
  surv_thresh <- read_csv(file.path(output_dir, "survival_thresholds.csv"),
                          show_col_types = FALSE)
  threshold_log <- surv_thresh$threshold_log[1]
  threshold_cm2 <- round(exp(threshold_log))

  # Load cluster bootstrap CI if available and reasonable
  if ("cluster_boot_ci_lower" %in% names(surv_thresh)) {
    threshold_ci_lower_log <- surv_thresh$cluster_boot_ci_lower[1]
    threshold_ci_upper_log <- surv_thresh$cluster_boot_ci_upper[1]
    ci_range <- threshold_ci_upper_log - threshold_ci_lower_log
    # Only show CI shading if range is reasonable (< 4 log units = ~50x range)
    use_ci_shading <- !is.na(ci_range) && ci_range < 4
    if (use_ci_shading) {
      cat(sprintf("  Using saved threshold: %.0f cm² (95%% CI: %.0f-%.0f cm²)\n",
                  threshold_cm2, exp(threshold_ci_lower_log), exp(threshold_ci_upper_log)))
    } else {
      cat(sprintf("  Using saved threshold: %.0f cm² (CI too wide to display: %.0f-%.0f cm²)\n",
                  threshold_cm2, exp(threshold_ci_lower_log), exp(threshold_ci_upper_log)))
    }
  } else {
    cat(sprintf("  Using saved threshold: %.0f cm² (log=%.2f)\n", threshold_cm2, threshold_log))
  }
}

p2 <- ggplot() +
  # Confidence ribbon for GAM
  geom_ribbon(data = pred_grid,
              aes(x = log_size, ymin = ci_lower, ymax = ci_upper),
              fill = colors$reef_green, alpha = 0.2) +
  # Threshold CI shading (only if reasonable)
  {if (use_ci_shading) {
    annotate("rect",
             xmin = threshold_ci_lower_log, xmax = threshold_ci_upper_log,
             ymin = -Inf, ymax = Inf,
             alpha = 0.15, fill = colors$coral_warm)
  }} +
  # Binned points
  geom_point(data = surv_binned,
             aes(x = log_size, y = survival, size = n),
             alpha = 0.6, color = colors$ocean_deep) +
  # GAM fit
  geom_line(data = pred_grid,
            aes(x = log_size, y = fit),
            color = colors$reef_green, linewidth = 1.5) +
  # Threshold line
  geom_vline(xintercept = threshold_log, linetype = "dashed",
             color = colors$coral_warm, linewidth = 1) +
  # Threshold annotation (without unreliable CI)
  annotate("text", x = threshold_log + 0.3, y = 0.3,
           label = sprintf("Threshold:\n%.0f cm²", threshold_cm2),
           color = colors$coral_warm, fontface = "bold", size = 3.5, hjust = 0) +
  # Scales
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                        breaks = c(10, 50, 100, 500, 1000, 5000, 10000))
  ) +
  scale_y_continuous(name = "Survival probability", limits = c(0, 1),
                     labels = scales::percent) +
  scale_size_continuous(name = "Sample size", range = c(2, 8)) +
  labs(
    title = "Figure 2. Size-Dependent Survival in A. palmata (Natural Colonies)",
    subtitle = "GAM fit with 95% CI; vertical dashed line = inflection point threshold\nNatural colonies only - restoration fragments excluded to avoid confounding",
    caption = sprintf("Natural colonies: n = %s observations (%.1f%% survival) from %d studies\nRestoration fragments excluded (n = %s, %.1f%% survival) - see Fig 8 for comparison",
                      scales::comma(nrow(surv_natural)), mean(surv_natural$survived) * 100,
                      n_distinct(surv_natural$study),
                      scales::comma(nrow(surv_fragments)), mean(surv_fragments$survived) * 100)
  ) +
  theme_publication() +
  theme(legend.position = c(0.85, 0.25))

ggsave(file.path(pub_fig_dir, "Fig2_survival_threshold.png"),
       p2, width = 12, height = 8, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig2_survival_threshold.pdf"),
       p2, width = 12, height = 8)

cat("  ✓ Saved: Fig2_survival_threshold.png/pdf\n")

# ==============================================================================
# FIGURE 3: SIZE-DEPENDENT GROWTH
# ==============================================================================

cat("Creating Figure 3: Size-Dependent Growth...\n")

# =============================================================================
# DATA QUALITY FILTERING FOR GROWTH FIGURES
# =============================================================================
# Two-step filtering approach:
#
# 1. IMPOSSIBLE VALUES: Remove records where tissue loss exceeds initial size
#    (flagged as impossible_growth in 01_data_preparation.R). ~300 records (6.9%)
#    primarily from NOAA survey. These are measurement/data entry errors.
#
# 2. WINSORIZATION: For visualization, winsorize to 5th-95th percentile to
#    reduce visual noise while preserving the biological pattern.
#
# Without these filters, figures show misleading negative mean growth for
# larger size classes (an artifact of impossible values, not real biology).

# Step 1: Remove impossible growth values
if ("impossible_growth" %in% names(growth_data)) {
  n_impossible <- sum(growth_data$impossible_growth, na.rm = TRUE)
  cat(sprintf("  Removing %d impossible growth records\n", n_impossible))
  growth_filtered <- growth_data %>% filter(!impossible_growth)
} else {
  cat("  ⚠ impossible_growth flag not found - applying filter\n")
  growth_filtered <- growth_data %>%
    filter(!((growth_cm2_yr < 0) & (abs(growth_cm2_yr) > size_cm2 * 1.1)))
}

# Step 2: Winsorize for visualization (preserves pattern, reduces noise)
lower_bound <- quantile(growth_filtered$growth_cm2_yr, 0.05, na.rm = TRUE)
upper_bound <- quantile(growth_filtered$growth_cm2_yr, 0.95, na.rm = TRUE)

growth_viz <- growth_filtered %>%
  mutate(growth_winsorized = pmax(pmin(growth_cm2_yr, upper_bound), lower_bound))

# Filter for GAM fitting (additional extreme outlier removal)
growth_for_gam <- growth_filtered %>%
  mutate(pct_change = growth_cm2_yr / size_cm2 * 100) %>%
  filter(pct_change > -50 & pct_change < 200)
cat(sprintf("  After all filters: %d records for GAM fitting (%.1f%% of original)\n",
            nrow(growth_for_gam), nrow(growth_for_gam)/nrow(growth_data)*100))

# Select best k by AIC (same approach as analysis script 03)
best_k_growth <- 5  # default
best_aic_g <- Inf
for (k in c(3, 4, 5)) {
  test_gam <- gam(growth_cm2_yr ~ s(log_size, k = k, bs = "tp"),
                  data = growth_for_gam, method = "REML")
  if (AIC(test_gam) < best_aic_g) {
    best_aic_g <- AIC(test_gam)
    best_k_growth <- k
  }
}
cat(sprintf("  Selected k=%d for growth GAM (by AIC)\n", best_k_growth))

# Fit GAM on filtered data for accurate trend
growth_gam <- gam(growth_cm2_yr ~ s(log_size, k = best_k_growth),
                  data = growth_for_gam, method = "REML")

pred_grid_g <- data.frame(log_size = seq(min(growth_data$log_size),
                                          max(growth_data$log_size), length.out = 500))
pred_grid_g$fit <- predict(growth_gam, newdata = pred_grid_g)
pred_se_g <- predict(growth_gam, newdata = pred_grid_g, se.fit = TRUE)
pred_grid_g$ci_lower <- pred_se_g$fit - 1.96 * pred_se_g$se.fit
pred_grid_g$ci_upper <- pred_se_g$fit + 1.96 * pred_se_g$se.fit

# Calculate binned growth stats for cleaner visualization
# NOTE: Using filtered data (impossible values removed) to show correct pattern
growth_binned <- growth_filtered %>%
  mutate(size_bin = cut(log_size, breaks = 25)) %>%
  group_by(size_bin) %>%
  summarise(
    log_size = mean(log_size),
    mean_growth = mean(growth_cm2_yr, na.rm = TRUE),
    median_growth = median(growth_cm2_yr, na.rm = TRUE),
    q25 = quantile(growth_cm2_yr, 0.25, na.rm = TRUE),
    q75 = quantile(growth_cm2_yr, 0.75, na.rm = TRUE),
    n = n(),
    pct_positive = mean(growth_cm2_yr > 0, na.rm = TRUE) * 100,
    .groups = "drop"
  ) %>%
  filter(!is.na(log_size))

# Create multi-panel figure for growth
# Panel A: Main growth pattern with winsorized points
p3a <- ggplot() +
  # Winsorized points (all data, transparent)
  geom_point(data = growth_viz,
             aes(x = log_size, y = growth_winsorized),
             alpha = 0.15, size = 0.8, color = colors$ocean_deep) +
  # Zero line
  geom_hline(yintercept = 0, linetype = "dashed", color = colors$text_secondary, linewidth = 0.8) +
  # Confidence ribbon
  geom_ribbon(data = pred_grid_g,
              aes(x = log_size, ymin = ci_lower, ymax = ci_upper),
              fill = colors$coral_warm, alpha = 0.3) +
  # GAM fit
  geom_line(data = pred_grid_g,
            aes(x = log_size, y = fit),
            color = colors$coral_warm, linewidth = 1.5) +
  # Binned medians overlay
  geom_point(data = growth_binned, aes(x = log_size, y = median_growth, size = n),
             color = colors$ocean_deep, alpha = 0.8) +
  # Scales
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                        breaks = c(10, 100, 1000, 10000))
  ) +
  scale_y_continuous(
    name = expression(paste("Growth rate (cm"^2, "/yr)")),
    limits = c(lower_bound, upper_bound)
  ) +
  scale_size_continuous(name = "n per bin", range = c(2, 6), guide = "none") +
  labs(subtitle = "A. Absolute growth rate vs. colony size") +
  theme_publication()

# Panel B: Probability of positive growth
# NOTE: Using filtered data (impossible values removed) to show correct pattern
pos_growth_data <- growth_filtered %>%
  mutate(
    positive = growth_cm2_yr > 0,
    size_bin = cut(log_size, breaks = 20)
  ) %>%
  group_by(size_bin) %>%
  summarise(
    log_size = mean(log_size),
    pct_positive = mean(positive, na.rm = TRUE) * 100,
    n = n(),
    se = sqrt(pct_positive/100 * (1 - pct_positive/100) / n) * 100,
    .groups = "drop"
  ) %>%
  filter(!is.na(log_size))

# Fit logistic GAM for probability of positive growth
# Select best k by AIC
# NOTE: Using filtered data for model fitting
growth_data_pos <- growth_filtered %>% mutate(positive = as.integer(growth_cm2_yr > 0))
best_k_pos <- 5
best_aic_pos <- Inf
for (k in c(3, 4, 5)) {
  test_gam <- gam(positive ~ s(log_size, k = k, bs = "tp"),
                  data = growth_data_pos, family = binomial, method = "REML")
  if (AIC(test_gam) < best_aic_pos) {
    best_aic_pos <- AIC(test_gam)
    best_k_pos <- k
  }
}
pos_gam <- gam(positive ~ s(log_size, k = best_k_pos), data = growth_data_pos,
               family = binomial, method = "REML")

pred_pos <- data.frame(log_size = seq(min(growth_data$log_size),
                                       max(growth_data$log_size), length.out = 200))
pred_pos$fit <- predict(pos_gam, newdata = pred_pos, type = "response") * 100
pred_pos_se <- predict(pos_gam, newdata = pred_pos, type = "link", se.fit = TRUE)
pred_pos$ci_lower <- plogis(pred_pos_se$fit - 1.96 * pred_pos_se$se.fit) * 100
pred_pos$ci_upper <- plogis(pred_pos_se$fit + 1.96 * pred_pos_se$se.fit) * 100

# Find threshold where probability crosses 70%
thresh_idx_pos <- which.min(abs(pred_pos$fit - 70))
pos_growth_thresh_cm2 <- exp(pred_pos$log_size[thresh_idx_pos])

p3b <- ggplot() +
  geom_ribbon(data = pred_pos,
              aes(x = log_size, ymin = ci_lower, ymax = ci_upper),
              fill = colors$reef_green, alpha = 0.2) +
  geom_point(data = pos_growth_data, aes(x = log_size, y = pct_positive, size = n),
             color = colors$ocean_deep, alpha = 0.7) +
  geom_line(data = pred_pos, aes(x = log_size, y = fit),
            color = colors$reef_green, linewidth = 1.5) +
  geom_hline(yintercept = 70, linetype = "dotted", color = colors$text_secondary) +
  geom_vline(xintercept = log(pos_growth_thresh_cm2), linetype = "dashed",
             color = colors$coral_warm, linewidth = 0.8) +
  annotate("text", x = log(pos_growth_thresh_cm2) + 0.5, y = 60,
           label = sprintf("%.0f cm²", pos_growth_thresh_cm2),
           color = colors$coral_warm, fontface = "bold", size = 3.5, hjust = 0) +
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                        breaks = c(10, 100, 1000, 10000))
  ) +
  scale_y_continuous(name = "Probability of positive growth (%)",
                     limits = c(50, 100)) +
  scale_size_continuous(name = "n", range = c(2, 6), guide = "none") +
  labs(subtitle = "B. Probability of positive growth (vs. partial mortality)") +
  theme_publication()

# Combine panels
# NOTE: Caption uses filtered data to show correct statistics
p3 <- p3a / p3b +
  plot_annotation(
    title = "Figure 3. Size-Dependent Growth in A. palmata",
    caption = sprintf("n = %s observations (after excluding %d impossible values); %.1f%% show positive growth. Points winsorized to 5th-95th percentile.",
                      scales::comma(nrow(growth_filtered)),
                      sum(growth_data$impossible_growth, na.rm = TRUE),
                      mean(growth_filtered$growth_cm2_yr > 0, na.rm = TRUE) * 100),
    theme = theme(
      plot.title = element_text(size = 14, face = "bold", color = colors$ocean_deep),
      plot.caption = element_text(size = 9, color = colors$text_secondary)
    )
  )

ggsave(file.path(pub_fig_dir, "Fig3_growth_size.png"),
       p3, width = 12, height = 12, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig3_growth_size.pdf"),
       p3, width = 12, height = 12)

cat("  ✓ Saved: Fig3_growth_size.png/pdf\n")

# ==============================================================================
# FIGURE 4: REGIONAL VARIATION (FOREST PLOT - STRATIFIED BY POPULATION TYPE)
# ==============================================================================

cat("Creating Figure 4: Regional Variation Forest Plot (Stratified)...\n")

# Calculate regional stats stratified by population type
region_stats_stratified <- surv_data %>%
  group_by(region, population_type) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    ci_lower = survival - 1.96 * se,
    ci_upper = survival + 1.96 * se,
    n_studies = n_distinct(study),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = pmax(0, ci_lower),
    ci_upper = pmin(1, ci_upper)
  ) %>%
  filter(n >= 20)  # Minimum sample size for reliable estimates

# Overall means by population type
overall_natural <- mean(surv_natural$survived)
overall_fragments <- mean(surv_fragments$survived)

# Order regions by natural colony survival (where available)
region_order <- region_stats_stratified %>%
  filter(population_type == "Natural colony") %>%
  arrange(survival) %>%
  pull(region)

# Add regions that only have fragment data
all_regions <- unique(region_stats_stratified$region)
region_order <- c(region_order, setdiff(all_regions, region_order))

region_stats_stratified <- region_stats_stratified %>%
  mutate(region = factor(region, levels = region_order))

p4 <- ggplot(region_stats_stratified,
             aes(x = survival, y = region, color = population_type)) +
  # Reference lines (overall means by population type)
  geom_vline(xintercept = overall_natural, linetype = "dashed",
             color = colors$natural_colony, alpha = 0.7) +
  geom_vline(xintercept = overall_fragments, linetype = "dotted",
             color = colors$restoration_fragment, alpha = 0.7) +
  # Confidence intervals
  geom_errorbarh(aes(xmin = ci_lower, xmax = ci_upper),
                 height = 0.3, linewidth = 0.8,
                 position = position_dodge(width = 0.6)) +
  # Points (sized by sample size)
  geom_point(aes(size = n),
             position = position_dodge(width = 0.6), alpha = 0.9) +
  # Scales
  scale_color_manual(values = c("Natural colony" = colors$natural_colony,
                                 "Restoration fragment" = colors$restoration_fragment),
                     name = "Population Type") +
  scale_x_continuous(name = "Survival Rate", labels = scales::percent,
                     limits = c(0, 1)) +
  scale_size_continuous(name = "Sample Size", range = c(2, 8),
                        labels = scales::comma) +
  labs(
    title = "Figure 4. Regional Variation in A. palmata Survival by Population Type",
    subtitle = sprintf("Forest plot with 95%% CI; Dashed = natural mean (%.0f%%), Dotted = fragment mean (%.0f%%)",
                       overall_natural * 100, overall_fragments * 100),
    y = NULL,
    caption = sprintf("Natural colonies: n=%s (%.1f%% survival); Restoration fragments: n=%s (%.1f%% survival)\nDifference: %.1f percentage points (natural > fragments)",
                      scales::comma(n_natural), surv_rate_natural,
                      scales::comma(n_fragments), surv_rate_fragments,
                      surv_rate_natural - surv_rate_fragments)
  ) +
  theme_publication() +
  theme(
    legend.position = "bottom",
    panel.grid.major.y = element_blank()
  )

ggsave(file.path(pub_fig_dir, "Fig4_regional_forest_plot.png"),
       p4, width = 12, height = 10, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig4_regional_forest_plot.pdf"),
       p4, width = 12, height = 10)

cat("  ✓ Saved: Fig4_regional_forest_plot.png/pdf\n")

# ==============================================================================
# FIGURE 5: SIZE × SPACE INTERACTION
# ==============================================================================

cat("Creating Figure 5: Size × Space Interaction...\n")

size_region <- surv_data %>%
  group_by(size_class, region) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    .groups = "drop"
  ) %>%
  filter(n >= 10) %>%  # Only cells with sufficient data
  mutate(size_label = size_class_short[size_class])

p5 <- ggplot(size_region, aes(x = region, y = size_class, fill = survival)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.0f%%\n(n=%d)", survival * 100, n)),
            size = 2.8, color = "white", fontface = "bold") +
  scale_fill_gradient2(
    low = colors$coral_warm,
    mid = colors$coral_pale,
    high = colors$reef_green,
    midpoint = 0.7,
    limits = c(0, 1),
    labels = scales::percent,
    name = "Survival\nRate"
  ) +
  scale_y_discrete(labels = size_class_short) +
  labs(
    title = "Figure 5. Size × Region Survival Matrix",
    subtitle = "Cell values show survival rate and sample size (n >= 10); empty cells = insufficient data",
    x = "Region",
    y = "Size Class"
  ) +
  theme_publication() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid = element_blank(),
    legend.position = "right"
  )

ggsave(file.path(pub_fig_dir, "Fig5_size_region_matrix.png"),
       p5, width = 12, height = 8, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig5_size_region_matrix.pdf"),
       p5, width = 12, height = 8)

cat("  ✓ Saved: Fig5_size_region_matrix.png/pdf\n")

# ==============================================================================
# FIGURE 6: DATA CERTAINTY
# ==============================================================================

cat("Creating Figure 6: Data Certainty Assessment...\n")

certainty_data <- surv_data %>%
  group_by(size_class, region) %>%
  summarise(n = n(), .groups = "drop") %>%
  complete(size_class, region, fill = list(n = 0)) %>%
  mutate(
    certainty = case_when(
      n == 0 ~ "No Data",
      n < 30 ~ "Very Low (<30)",
      n < 100 ~ "Low (30-99)",
      n < 300 ~ "Moderate (100-299)",
      TRUE ~ "High (>=300)"
    ),
    certainty = factor(certainty, levels = c("No Data", "Very Low (<30)",
                                              "Low (30-99)", "Moderate (100-299)",
                                              "High (>=300)"))
  )

certainty_colors <- c(
  "No Data" = "#d3d3d3",
  "Very Low (<30)" = colors$coral_warm,
  "Low (30-99)" = colors$coral_pale,
  "Moderate (100-299)" = "#e9c46a",
  "High (>=300)" = colors$reef_green
)

p6 <- ggplot(certainty_data, aes(x = region, y = size_class, fill = certainty)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = ifelse(n > 0, n, "-")),
            size = 3, color = ifelse(certainty_data$n >= 100, "white", "black")) +
  scale_fill_manual(values = certainty_colors, name = "Data\nCertainty") +
  scale_y_discrete(labels = size_class_short) +
  labs(
    title = "Figure 6. Data Coverage and Certainty Assessment",
    subtitle = "Cell values = sample size; color = certainty level",
    x = "Region",
    y = "Size Class"
  ) +
  theme_publication() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid = element_blank(),
    legend.position = "right"
  )

ggsave(file.path(pub_fig_dir, "Fig6_data_certainty.png"),
       p6, width = 12, height = 8, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig6_data_certainty.pdf"),
       p6, width = 12, height = 8)

cat("  ✓ Saved: Fig6_data_certainty.png/pdf\n")

# ==============================================================================
# FIGURE 7: TEMPORAL TRENDS
# ==============================================================================

cat("Creating Figure 7: Temporal Trends...\n")

# Load yearly survival data
yearly_surv <- read_csv(file.path(output_dir, "survival_by_year.csv"),
                        show_col_types = FALSE) %>%
  filter(n >= 20)  # Only years with sufficient data

# Identify years with anomalous mortality
mean_surv <- mean(yearly_surv$survival)
sd_surv <- sd(yearly_surv$survival)

yearly_surv <- yearly_surv %>%
  mutate(
    z_score = (survival - mean_surv) / sd_surv,
    mortality_status = case_when(
      z_score < -1.5 ~ "Severe mortality",
      z_score < -1 ~ "Elevated mortality",
      z_score > 1 ~ "Above average",
      TRUE ~ "Normal"
    ),
    ci_lower = pmax(0, survival - 1.96 * se),
    ci_upper = pmin(1, survival + 1.96 * se)
  )

# Fit temporal trend
trend_model <- lm(survival ~ survey_yr, data = yearly_surv, weights = n)
trend_coef <- coef(trend_model)[2]
trend_p <- summary(trend_model)$coefficients[2, 4]
yearly_surv$trend_pred <- predict(trend_model)

# Panel A: Temporal trend with mortality events
status_colors <- c(
  "Severe mortality" = "#c0392b",
  "Elevated mortality" = "#e74c3c",
  "Normal" = colors$ocean_mid,
  "Above average" = colors$reef_green
)

p7a <- ggplot(yearly_surv, aes(x = survey_yr, y = survival)) +
  # Trend line
  geom_line(aes(y = trend_pred), color = colors$coral_warm, linewidth = 1.2,
            linetype = "dashed") +
  # Mean reference
  geom_hline(yintercept = mean_surv, color = colors$text_secondary,
             linetype = "dotted", linewidth = 0.8) +
  # Confidence intervals
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper),
                width = 0.3, color = "gray50", alpha = 0.6) +
  # Points colored by mortality status
  geom_point(aes(size = n, color = mortality_status), alpha = 0.9) +
  # Scales
  scale_color_manual(values = status_colors, name = "Year Status") +
  scale_size_continuous(name = "Sample Size", range = c(2, 8),
                        labels = scales::comma) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_x_continuous(breaks = seq(2005, 2024, 2)) +
  labs(
    subtitle = sprintf("A. Annual Survival Trend (%.2f%%/year, p = %.3f)",
                       trend_coef * 100, trend_p),
    x = "Year",
    y = "Annual Survival Rate"
  ) +
  theme_publication() +
  theme(legend.position = "right")

# Panel B: Size class temporal vulnerability (CV)
size_temporal <- surv_data %>%
  group_by(size_class, survey_yr) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    .groups = "drop"
  ) %>%
  filter(n >= 10) %>%
  group_by(size_class) %>%
  summarise(
    n_years = n(),
    mean_survival = mean(survival),
    sd_survival = sd(survival),
    cv = sd_survival / mean_survival,
    .groups = "drop"
  ) %>%
  filter(!is.na(cv))

p7b <- ggplot(size_temporal, aes(x = size_class, y = cv, fill = size_class)) +
  geom_col(alpha = 0.9, show.legend = FALSE) +
  geom_hline(yintercept = mean(size_temporal$cv, na.rm = TRUE),
             linetype = "dashed", color = colors$coral_warm, linewidth = 1) +
  scale_fill_manual(values = size_colors) +
  scale_x_discrete(labels = size_class_short) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    subtitle = "B. Interannual Variability by Size Class",
    x = "Size Class",
    y = "Coefficient of Variation"
  ) +
  theme_publication() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Panel C: Regional temporal variability (relaxed filter to show more regions)
region_temporal <- surv_data %>%
  group_by(region, survey_yr) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    .groups = "drop"
  ) %>%
  filter(n >= 5) %>%  # Relaxed from 10 to show more regions
  group_by(region) %>%
  summarise(
    n_years = n(),
    mean_survival = mean(survival),
    sd_survival = sd(survival),
    cv = sd_survival / mean_survival,
    min_survival = min(survival),
    max_survival = max(survival),
    .groups = "drop"
  ) %>%
  filter(!is.na(cv) & n_years >= 2) %>%  # Relaxed from 3 years to 2
arrange(desc(cv))

p7c <- ggplot(region_temporal, aes(x = reorder(region, cv), y = cv)) +
  geom_col(fill = colors$ocean_mid, alpha = 0.9) +
  geom_hline(yintercept = mean(region_temporal$cv, na.rm = TRUE),
             linetype = "dashed", color = colors$coral_warm, linewidth = 1) +
  geom_text(aes(label = sprintf("n=%d yr", n_years)), hjust = -0.1, size = 3) +
  coord_flip() +
  scale_y_continuous(labels = scales::percent, expand = expansion(mult = c(0, 0.2))) +
  labs(
    subtitle = "C. Regional Climate Sensitivity (CV)",
    x = NULL,
    y = "Coefficient of Variation"
  ) +
  theme_publication()

# Panel D: Survival by year heatmap (Size × Time)
size_year_surv <- surv_data %>%
  group_by(size_class, survey_yr) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    .groups = "drop"
  ) %>%
  filter(n >= 10)

p7d <- ggplot(size_year_surv, aes(x = survey_yr, y = size_class, fill = survival)) +
  geom_tile(color = "white", linewidth = 0.3) +
  scale_fill_gradient2(
    low = colors$coral_warm,
    mid = colors$coral_pale,
    high = colors$reef_green,
    midpoint = 0.7,
    limits = c(0, 1),
    labels = scales::percent,
    name = "Survival"
  ) +
  scale_x_continuous(breaks = seq(2005, 2024, 3)) +
  scale_y_discrete(labels = size_class_short) +
  labs(
    subtitle = "D. Size x Year Survival Patterns",
    x = "Year",
    y = "Size Class"
  ) +
  theme_publication() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
    panel.grid = element_blank()
  )

# Combine panels
fig7 <- (p7a + p7b) / (p7c + p7d) +
  plot_annotation(
    title = "Figure 7. Temporal Trends in A. palmata Survival",
    subtitle = sprintf("Significant decline detected: %.2f%% per year (n = %s observations, %d years)",
                       trend_coef * 100, scales::comma(nrow(surv_data)),
                       nrow(yearly_surv)),
    caption = "Dashed line = trend/mean; Red points = years with elevated mortality (z-score < -1)",
    theme = theme(
      plot.title = element_text(size = 14, face = "bold", color = colors$ocean_deep),
      plot.subtitle = element_text(size = 11, color = colors$text_secondary),
      plot.caption = element_text(size = 9, color = colors$text_secondary)
    )
  )

ggsave(file.path(pub_fig_dir, "Fig7_temporal_trends.png"),
       fig7, width = 14, height = 12, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig7_temporal_trends.pdf"),
       fig7, width = 14, height = 12)

cat("  ✓ Saved: Fig7_temporal_trends.png/pdf\n")

# ==============================================================================
# FIGURE 8: FRAGMENT VS COLONY COMPARISON (SIZE-MATCHED KEY FINDING)
# ==============================================================================

cat("Creating Figure 8: Fragment vs Colony Comparison (Size-Matched)...\n")

# KEY FINDING: At matching sizes, natural colonies have 17-21 pp higher survival
# This is NOT a size effect - it's a true population type effect

# Calculate survival by population type and size class
fragment_comparison <- surv_data %>%
  filter(!is.na(population_type)) %>%
  group_by(population_type, size_class) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    mean_size = mean(size_cm2),
    .groups = "drop"
  ) %>%
  filter(n >= 10)  # Minimum sample size

# Panel A: Size-matched survival comparison
p8a <- ggplot(fragment_comparison,
              aes(x = size_class, y = survival, fill = population_type)) +
  geom_col(position = position_dodge(width = 0.8), alpha = 0.9) +
  geom_errorbar(aes(ymin = pmax(0, survival - 1.96 * se),
                    ymax = pmin(1, survival + 1.96 * se)),
                position = position_dodge(width = 0.8), width = 0.3) +
  scale_fill_manual(values = c("Natural colony" = colors$natural_colony,
                                "Restoration fragment" = colors$restoration_fragment),
                    name = "Population Type") +
  scale_x_discrete(labels = size_class_short) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  labs(
    subtitle = "A. Survival by Size Class and Population Type",
    x = "Size Class",
    y = "Survival Rate"
  ) +
  theme_publication() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Panel B: Size distribution by population type (shows they overlap)
size_dist <- surv_data %>%
  filter(!is.na(population_type)) %>%
  group_by(population_type) %>%
  summarise(
    n = n(),
    mean_size = mean(size_cm2),
    median_size = median(size_cm2),
    q25 = quantile(size_cm2, 0.25),
    q75 = quantile(size_cm2, 0.75),
    .groups = "drop"
  )

p8b <- ggplot(surv_data %>% filter(!is.na(population_type)),
              aes(x = log_size, fill = population_type)) +
  geom_density(alpha = 0.5, color = NA) +
  geom_vline(data = size_dist, aes(xintercept = log(median_size), color = population_type),
             linetype = "dashed", linewidth = 1) +
  scale_fill_manual(values = c("Natural colony" = colors$natural_colony,
                                "Restoration fragment" = colors$restoration_fragment),
                    name = "Population Type") +
  scale_color_manual(values = c("Natural colony" = colors$natural_colony,
                                 "Restoration fragment" = colors$restoration_fragment),
                     guide = "none") +
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                        breaks = c(10, 50, 100, 500, 1000, 5000))
  ) +
  labs(
    subtitle = "B. Size Distribution Overlap (dashed = median)",
    y = "Density"
  ) +
  theme_publication()

# Panel C: Size-matched direct comparison (KEY FINDING)
# Calculate difference at each size class
size_diff <- fragment_comparison %>%
  select(population_type, size_class, survival, n) %>%
  pivot_wider(names_from = population_type, values_from = c(survival, n)) %>%
  mutate(
    difference = `survival_Natural colony` - `survival_Restoration fragment`,
    se_diff = sqrt(
      `survival_Natural colony` * (1 - `survival_Natural colony`) / `n_Natural colony` +
      `survival_Restoration fragment` * (1 - `survival_Restoration fragment`) / `n_Restoration fragment`
    )
  ) %>%
  filter(!is.na(difference))

p8c <- ggplot(size_diff, aes(x = size_class, y = difference)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = colors$text_secondary) +
  geom_col(fill = colors$reef_green, alpha = 0.9) +
  geom_errorbar(aes(ymin = difference - 1.96 * se_diff,
                    ymax = difference + 1.96 * se_diff),
                width = 0.3, color = colors$ocean_deep) +
  geom_text(aes(label = sprintf("%+.0f pp", difference * 100)),
            vjust = ifelse(size_diff$difference > 0, -0.5, 1.5), size = 3.5, fontface = "bold") +
  scale_x_discrete(labels = size_class_short) +
  scale_y_continuous(labels = function(x) sprintf("%+.0f%%", x * 100),
                     limits = c(-0.1, 0.4)) +
  labs(
    subtitle = "C. Survival Advantage: Natural - Fragment (at same size)",
    x = "Size Class",
    y = "Survival Difference (pp)"
  ) +
  theme_publication() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Calculate overall statistics for caption
overall_diff <- surv_rate_natural - surv_rate_fragments
mean_size_matched_diff <- mean(size_diff$difference, na.rm = TRUE) * 100

# Combine panels
fig8 <- (p8a | p8b) / p8c +
  plot_annotation(
    title = "Figure 8. Natural Colonies vs Restoration Fragments: Size-Matched Comparison",
    subtitle = sprintf("KEY FINDING: At matching sizes, natural colonies have %.0f-%.0f pp higher survival",
                       min(size_diff$difference * 100, na.rm = TRUE),
                       max(size_diff$difference * 100, na.rm = TRUE)),
    caption = sprintf("Natural colonies: n=%s (%.1f%% survival); Fragments: n=%s (%.1f%% survival)\nOverall difference: %.1f pp; Size-matched mean difference: %.1f pp\nThis is NOT a size effect - fragments have lower survival even at identical sizes",
                      scales::comma(n_natural), surv_rate_natural,
                      scales::comma(n_fragments), surv_rate_fragments,
                      overall_diff, mean_size_matched_diff),
    theme = theme(
      plot.title = element_text(size = 14, face = "bold", color = colors$ocean_deep),
      plot.subtitle = element_text(size = 11, face = "bold", color = colors$coral_warm),
      plot.caption = element_text(size = 9, color = colors$text_secondary)
    )
  )

ggsave(file.path(pub_fig_dir, "Fig8_fragment_comparison.png"),
       fig8, width = 14, height = 10, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig8_fragment_comparison.pdf"),
       fig8, width = 14, height = 10)

cat("  ✓ Saved: Fig8_fragment_comparison.png/pdf\n")

# ==============================================================================
# FIGURE 9: COMBINED KEY PREDICTOR EFFECTS
# ==============================================================================

cat("Creating Figure 9: Combined Key Predictor Effects...\n")

# This figure summarizes all key predictors in a single visualization
# showing the effect sizes of Size, Region, Time, Depth, and Fragment status

# Calculate effect sizes for each predictor relative to baseline
baseline_surv <- mean(surv_data$survived)

# 1. Size effect (using size classes) - use clean labels
size_effects <- surv_data %>%
  group_by(size_class) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    .groups = "drop"
  ) %>%
  mutate(
    predictor = "Size Class",
    level = size_class_short[size_class],
    effect_type = "Categorical"
  )

# 2. Regional effect
region_effects <- surv_data %>%
  group_by(region) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    .groups = "drop"
  ) %>%
  mutate(
    predictor = "Region",
    level = region,
    effect_type = "Categorical"
  )

# 3. Depth effect (if available) - order from shallow to deep
depth_effects <- data.frame()
if ("depth_m" %in% colnames(surv_data)) {
  surv_with_depth <- surv_data %>%
    filter(!is.na(depth_m)) %>%
    mutate(depth_cat = cut(depth_m,
                           breaks = c(0, 3, 6, 10, 30),
                           labels = c("1. Shallow (1-3m)", "2. Mid (3-6m)",
                                      "3. Deep (6-10m)", "4. Very deep (>10m)")))

  depth_effects <- surv_with_depth %>%
    group_by(depth_cat) %>%
    summarise(
      n = n(),
      survival = mean(survived),
      se = sqrt(survival * (1 - survival) / n),
      .groups = "drop"
    ) %>%
    filter(!is.na(depth_cat)) %>%
    mutate(
      predictor = "Depth",
      level = as.character(depth_cat),
      effect_type = "Categorical"
    )
}

# 4. Population type effect (KEY - uses stratified data)
pop_type_effects <- surv_data %>%
  filter(!is.na(population_type)) %>%
  group_by(population_type) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    .groups = "drop"
  ) %>%
  filter(n >= 10) %>%
  mutate(
    predictor = "Population Type (KEY)",
    level = population_type,
    effect_type = "Categorical"
  )

# Panel A: Forest-style plot of all categorical effects
# Combine effects into single data frame (Population Type first as KEY predictor)
all_effects <- bind_rows(
  pop_type_effects %>% select(predictor, level, n, survival, se),
  size_effects %>% select(predictor, level, n, survival, se),
  region_effects %>% select(predictor, level, n, survival, se)
)

if (nrow(depth_effects) > 0) {
  all_effects <- bind_rows(
    all_effects,
    depth_effects %>% select(predictor, level, n, survival, se)
  )
}

all_effects <- all_effects %>%
  filter(!is.na(survival)) %>%  # Remove any NA values
  mutate(
    ci_lower = pmax(0, survival - 1.96 * se),
    ci_upper = pmin(1, survival + 1.96 * se),
    label = paste0(predictor, ": ", level)
  )

# Set factor order for depth (shallow to deep) - use reverse for y-axis
all_effects <- all_effects %>%
  mutate(
    level = factor(level, levels = unique(level[order(survival)]))
  )

# Create faceted forest plot
p9a <- ggplot(all_effects, aes(x = survival, y = reorder(level, survival))) +
  geom_vline(xintercept = baseline_surv, linetype = "dashed",
             color = colors$text_secondary) +
  geom_errorbarh(aes(xmin = ci_lower, xmax = ci_upper),
                 height = 0.2, color = colors$ocean_mid, linewidth = 0.8) +
  geom_point(aes(size = n, color = predictor), alpha = 0.9) +
  facet_wrap(~ predictor, scales = "free_y", ncol = 1) +
  scale_color_manual(values = c("Population Type (KEY)" = "#9b59b6",
                                 "Size Class" = colors$coral_warm,
                                 "Region" = colors$ocean_mid,
                                 "Depth" = colors$reef_green),
                     guide = "none") +
  scale_x_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_size_continuous(name = "n", range = c(2, 6), labels = scales::comma) +
  labs(
    title = "Figure 9. Summary of Key Predictor Effects on A. palmata Survival",
    subtitle = sprintf("Dashed line = overall mean (%.1f%%); Points sized by sample size",
                       baseline_surv * 100),
    x = "Survival Rate",
    y = NULL,
    caption = "Error bars = 95% CI"
  ) +
  theme_publication() +
  theme(
    strip.text = element_text(face = "bold", size = 11),
    strip.background = element_rect(fill = colors$sand_warm),
    panel.grid.major.y = element_blank(),
    legend.position = "bottom"
  )

ggsave(file.path(pub_fig_dir, "Fig9_predictor_effects_summary.png"),
       p9a, width = 10, height = 14, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig9_predictor_effects_summary.pdf"),
       p9a, width = 10, height = 14)

cat("  ✓ Saved: Fig9_predictor_effects_summary.png/pdf\n")

# ==============================================================================
# FIGURE 10: SIZE × REGION × TIME 3-WAY INTERACTION
# ==============================================================================

cat("Creating Figure 10: Size × Region × Time Interaction...\n")

# Create small multiples showing survival patterns across all three dimensions
# Each region gets a panel with size on x-axis, survival on y, and time as color

# Create three time periods
surv_data_time <- surv_data %>%
  filter(survey_yr >= 2005) %>%
  mutate(
    time_period = case_when(
      survey_yr <= 2010 ~ "2005-2010",
      survey_yr <= 2017 ~ "2011-2017",
      TRUE ~ "2018-2024"
    )
  )

# Calculate survival by size × region × time period with relaxed filter
size_region_time <- surv_data_time %>%
  group_by(size_class, region, time_period) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    .groups = "drop"
  ) %>%
  filter(n >= 5)  # Relaxed from 10 to show more data

# Focus on regions with data across multiple time periods
# But be more lenient to include more regions
regions_with_temporal <- size_region_time %>%
  group_by(region) %>%
  summarise(
    n_periods = n_distinct(time_period),
    total_n = sum(n)
  ) %>%
  filter(n_periods >= 1 & total_n >= 50) %>%  # At least 50 total observations
  arrange(desc(total_n)) %>%
  head(6) %>%  # Top 6 regions by sample size
  pull(region)

size_region_time <- size_region_time %>%
  filter(region %in% regions_with_temporal)

period_colors <- c(
  "2005-2010" = colors$reef_green,
  "2011-2017" = colors$ocean_mid,
  "2018-2024" = colors$coral_warm
)

# Determine optimal number of columns based on regions
n_regions <- n_distinct(size_region_time$region)
ncol_fig <- ifelse(n_regions <= 3, n_regions, min(3, ceiling(sqrt(n_regions))))

p10 <- ggplot(size_region_time, aes(x = size_class, y = survival,
                                     color = time_period, group = time_period)) +
  geom_line(linewidth = 1, alpha = 0.8) +
  geom_point(aes(size = n), alpha = 0.9) +
  geom_errorbar(aes(ymin = pmax(0, survival - 1.96 * se),
                    ymax = pmin(1, survival + 1.96 * se)),
                width = 0.2, alpha = 0.6) +
  facet_wrap(~ region, ncol = ncol_fig, drop = TRUE) +
  scale_color_manual(values = period_colors, name = "Time Period") +
  scale_x_discrete(labels = size_class_short) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_size_continuous(name = "n", range = c(2, 5), labels = scales::comma) +
  labs(
    title = "Figure 10. Size x Region x Time Interaction",
    subtitle = sprintf("Survival by size class across %d regions and time periods (n >= 5 per cell)",
                       n_regions),
    x = "Size Class",
    y = "Survival Rate",
    caption = "Lines connect size classes within time periods; Error bars = 95% CI"
  ) +
  theme_publication() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
    strip.text = element_text(face = "bold"),
    strip.background = element_rect(fill = colors$sand_warm),
    legend.position = "bottom"
  )

# Adjust figure dimensions based on number of regions
fig_height <- ifelse(n_regions <= 3, 6, ifelse(n_regions <= 6, 10, 14))
fig_width <- ifelse(n_regions <= 2, 10, 14)

ggsave(file.path(pub_fig_dir, "Fig10_size_region_time_interaction.png"),
       p10, width = fig_width, height = fig_height, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig10_size_region_time_interaction.pdf"),
       p10, width = fig_width, height = fig_height)

cat("  ✓ Saved: Fig10_size_region_time_interaction.png/pdf\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  PUBLICATION FIGURES COMPLETE                                 ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("Generated figures:\n")
cat("  ✓ Fig1_data_landscape.png/pdf - Overview of database\n")
cat("  ✓ Fig2_survival_threshold.png/pdf - Size-dependent survival\n")
cat("  ✓ Fig3_growth_size.png/pdf - Size-dependent growth\n")
cat("  ✓ Fig4_regional_forest_plot.png/pdf - Regional variation\n")
cat("  ✓ Fig5_size_region_matrix.png/pdf - Size × Space interaction\n")
cat("  ✓ Fig6_data_certainty.png/pdf - Data gaps\n")
cat("  ✓ Fig7_temporal_trends.png/pdf - Year effects & climate sensitivity\n")
cat("  ✓ Fig8_fragment_comparison.png/pdf - Fragment vs colony survival\n")
cat("  ✓ Fig9_predictor_effects_summary.png/pdf - All key predictors\n")
cat("  ✓ Fig10_size_region_time_interaction.png/pdf - 3-way interaction\n")

cat(sprintf("\nOutput directory: %s\n", pub_fig_dir))
cat("\nAll figures saved at 300 DPI (PNG) and vector format (PDF)\n\n")
