#!/usr/bin/env Rscript
# =============================================================================
# FIGURE: GEOGRAPHIC VARIATION IN A. PALMATA SURVIVAL ACROSS THE CARIBBEAN
# =============================================================================
#
# PURPOSE: Generate supplementary figure showing regional variation in annual
#          survival across the Caribbean from the expanded meta-analysis.
#
# Produces a single-panel horizontal point-range plot (174 x 100 mm) showing
# annual survival estimates by Caribbean region from the expanded meta-analysis
# (10 regions, 16 studies).
#
# Design:
#   - Y-axis: regions ordered by survival (lowest at bottom)
#   - X-axis: annual survival rate (0.4 to 1.0)
#   - Individual study points colored by population_type (natural/restoration)
#   - Regional pooled estimates (diamonds) for regions with k >= 2 studies
#   - Vertical dashed line at overall pooled mean (78.0%)
#
# INPUTS:
#   - 06_analysis/output/expanded_meta_analysis_study_effects.csv (22 study effects)
#
# OUTPUTS:
#   - 06_analysis/figures/supplementary/FigS15_regional_survival.{png,pdf}
#   - 06_analysis/output/regional_survival_summary.csv
#
# Author: Detmer & Stier Lab
# Date: 2026-02
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(scales)
})

set.seed(42)

# Source shared utilities
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

pal <- MANUSCRIPT_PALETTE
project_root <- get_project_root()
output_dir  <- file.path(project_root, "06_analysis/output")
fig_dir     <- file.path(project_root, "06_analysis/figures/supplementary")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

print_header("GEOGRAPHIC VARIATION IN SURVIVAL — FIGURE")

# =============================================================================
# 1. LOAD DATA
# =============================================================================

print_subheader("Loading expanded meta-analysis data")

data_path <- file.path(output_dir, "expanded_meta_analysis_study_effects.csv")
if (!file.exists(data_path)) {
  stop("Cannot find: ", data_path)
}

study_data <- read_csv(data_path, show_col_types = FALSE)
cat(sprintf("  Loaded %d study-level estimates across %d regions\n",
            nrow(study_data), n_distinct(study_data$region)))

# =============================================================================
# 2. COMPUTE REGIONAL SUMMARIES
# =============================================================================

print_subheader("Computing regional summaries")

# Regional-level aggregation: count studies, total N, pooled survival
region_summary <- study_data %>%
  group_by(region) %>%
  summarise(
    k_studies     = n(),
    n_total       = sum(n_total),
    n_survived    = sum(n_survived),
    # Inverse-variance weighted pooled survival (on log-odds scale)
    # Use simple N-weighted average for the regional pooled estimate
    pooled_surv   = sum(n_survived) / sum(n_total),
    min_surv      = min(survival_rate),
    max_surv      = max(survival_rate),
    has_natural   = any(population_type == "Natural colony"),
    has_restoration = any(population_type == "Restoration fragment"),
    .groups = "drop"
  ) %>%
  arrange(pooled_surv)

# Add Wilson CIs row-wise
region_summary <- region_summary %>%
  rowwise() %>%
  mutate(
    pooled_lower = wilson_ci(n_survived, n_total)$lower,
    pooled_upper = wilson_ci(n_survived, n_total)$upper
  ) %>%
  ungroup()

# Create ordered factor for plotting (lowest survival at bottom)
region_order <- region_summary$region
region_labels <- paste0(region_summary$region, " (N=",
                        trimws(format(region_summary$n_total, big.mark = ",")), ")")

study_data <- study_data %>%
  mutate(
    region_f = factor(region, levels = region_order)
  )

region_summary <- region_summary %>%
  mutate(
    region_f = factor(region, levels = region_order),
    region_label = region_labels
  )

# Create the label mapping for y-axis
region_label_map <- setNames(region_labels, region_order)

cat(sprintf("  %d regions, survival range: %.1f%% to %.1f%%\n",
            nrow(region_summary),
            min(region_summary$pooled_surv) * 100,
            max(region_summary$pooled_surv) * 100))

# Overall pooled survival (meta-analytic RE estimate from 14_meta_analysis.R)
# The N-weighted raw pooled is ~78.2%, but the random-effects meta-analytic
# estimate is 78.0% — use the meta-analytic value for the reference line
overall_pooled_raw <- sum(study_data$n_survived) / sum(study_data$n_total)
# Read RE meta-analytic pooled estimate from expanded meta-analysis results
meta_results_path <- file.path(output_dir, "expanded_meta_analysis_results.csv")
if (file.exists(meta_results_path)) {
  meta_res <- read_csv(meta_results_path, show_col_types = FALSE)
  overall_pooled <- as.numeric(meta_res$value[meta_res$statistic == "Pooled survival (RE)"])
} else {
  overall_pooled <- 0.811  # fallback if file not found
  warning("Using hardcoded pooled survival fallback (expanded_meta_analysis_results.csv not found)")
}
cat(sprintf("  Overall pooled survival (meta-analytic RE): %.1f%%\n", overall_pooled * 100))
cat(sprintf("  Overall pooled survival (N-weighted raw):   %.1f%%\n", overall_pooled_raw * 100))

# =============================================================================
# 3. SAVE REGIONAL SUMMARY CSV
# =============================================================================

print_subheader("Saving regional summary")

summary_out <- region_summary %>%
  select(region, k_studies, n_total, pooled_surv, pooled_lower, pooled_upper,
         min_surv, max_surv, has_natural, has_restoration) %>%
  arrange(desc(pooled_surv))

write_csv(summary_out, file.path(output_dir, "regional_survival_summary.csv"))
cat("  Saved: regional_survival_summary.csv\n")

# =============================================================================
# 4. BUILD FIGURE
# =============================================================================

print_subheader("Building figure")

# Prepare study-level data for plotting with jitter offset for overlapping points
study_plot <- study_data %>%
  group_by(region) %>%
  mutate(
    n_in_region = n(),
    # Vertical jitter for regions with multiple studies (wider for 3+ studies)
    jitter_offset = if (n() > 1) seq(-0.22, 0.22, length.out = n()) else 0
  ) %>%
  ungroup() %>%
  mutate(
    region_f = factor(region, levels = region_order),
    region_num = as.numeric(region_f) + jitter_offset,
    pop_label = ifelse(population_type == "Natural colony", "Natural", "Restoration")
  )

# Prepare regional pooled estimates (only for k >= 2)
pooled_plot <- region_summary %>%
  filter(k_studies >= 2) %>%
  mutate(region_num = as.numeric(region_f))

# Color mapping
pop_colors <- c("Natural" = pal$natural, "Restoration" = pal$restoration)

# Build the plot
p <- ggplot() +
  # Vertical dashed line at overall pooled survival
  geom_vline(xintercept = overall_pooled, linetype = "dashed",
             color = pal$slate_mid, linewidth = 0.5) +
  # Study-level point-ranges (CI whiskers + colored dots)
  geom_segment(data = study_plot,
               aes(x = surv_lower, xend = surv_upper,
                   y = region_num, yend = region_num,
                   color = pop_label),
               linewidth = 0.4, alpha = 0.6) +
  geom_point(data = study_plot,
             aes(x = survival_rate, y = region_num,
                 color = pop_label,
                 size = n_total),
             alpha = 0.85) +
  # Regional pooled diamonds (k >= 2 only)
  geom_point(data = pooled_plot,
             aes(x = pooled_surv, y = region_num),
             shape = 18, size = 4.5, color = pal$slate_dark) +
  geom_segment(data = pooled_plot,
               aes(x = pooled_lower, xend = pooled_upper,
                   y = region_num, yend = region_num),
               linewidth = 0.8, color = pal$slate_dark) +
  # Scales
  scale_x_continuous(
    name = "Annual survival rate",
    limits = c(0.40, 1.0),
    breaks = seq(0.4, 1.0, 0.1),
    labels = scales::percent_format(accuracy = 1)
  ) +
  scale_y_continuous(
    name = NULL,
    breaks = seq_along(region_order),
    labels = region_label_map[region_order],
    expand = expansion(mult = c(0.06, 0.10))
  ) +
  scale_color_manual(
    name = "Population type",
    values = pop_colors,
    guide = guide_legend(override.aes = list(size = 3, alpha = 1))
  ) +
  scale_size_continuous(
    name = "Sample size (n)",
    range = c(1.5, 5.5),
    breaks = c(50, 500, 2000),
    labels = scales::comma
  ) +
  # Annotation: overall pooled label
  annotate("text",
           x = overall_pooled + 0.015, y = length(region_order) + 0.6,
           label = sprintf("Overall pooled: %.1f%%", overall_pooled * 100),
           hjust = 0, vjust = 0.5, size = 3.0, color = pal$slate_mid,
           fontface = "italic") +
  # Theme

  theme_manuscript(base_size = 11) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = pal$grid, linewidth = 0.3),
    axis.ticks.y = element_blank(),
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.margin = margin(t = 2, b = 0),
    plot.margin = margin(8, 12, 6, 8, "mm")
  ) +
  guides(
    color = guide_legend(order = 1, title.position = "top"),
    size = guide_legend(order = 2, title.position = "top")
  )

# =============================================================================
# 5. SAVE FIGURE
# =============================================================================

print_subheader("Saving figure")

save_manuscript_fig(p, "FigS15_regional_survival",
                    width_mm = 174, height_mm = 110, fig_dir = fig_dir)

print_header("DONE")
cat("  Figure: FigS15_regional_survival.{png,pdf}\n")
cat("  Data:   regional_survival_summary.csv\n")
