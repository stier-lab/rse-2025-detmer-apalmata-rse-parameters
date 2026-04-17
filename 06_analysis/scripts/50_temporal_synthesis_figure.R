#!/usr/bin/env Rscript
# =============================================================================
# SUPPLEMENTARY FIGURE: TEMPORAL SYNTHESIS (3-panel)
# =============================================================================
# Panel a: Stochastic population projections (50-year) — median trajectory with
#          5th-95th percentile envelope for IID, Markov, and none-only scenarios
# Panel b: Regime classifications (2004-2024) — year-by-year regime state as
#          colored tiles (background, post-disturbance, catastrophic)
# Panel c: Heatwave scenario effective lambda — dot plot by scenario with
#          horizontal reference line at lambda = 1
#
# Journal: Coral Reefs (Springer) — 174mm double-column, max 234mm height,
#          300 DPI, sans-serif 8-12pt, lowercase panel labels, NO titles/captions
#
# INPUTS:
#   - 06_analysis/output/stochastic_ipm_projection_quantiles.csv
#   - 06_analysis/output/regime_switching_year_classification.csv
#   - 06_analysis/output/heatwave_scenario_summary.csv
#
# OUTPUTS:
#   - 06_analysis/figures/supplementary/FigS28_temporal_synthesis.png + .pdf
#
# Author: Detmer & Stier Lab
# Date: 2026-04
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(patchwork)
})

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

pal <- MANUSCRIPT_PALETTE
project_root <- get_project_root()
output_dir <- file.path(project_root, "06_analysis/output")
supp_dir <- file.path(project_root, "06_analysis/figures/supplementary")
dir.create(supp_dir, showWarnings = FALSE, recursive = TRUE)

cat("\n")
cat("================================================================\n")
cat("  SUPPLEMENTARY FIGURE: TEMPORAL SYNTHESIS\n")
cat("================================================================\n\n")

# =============================================================================
# LOAD DATA
# =============================================================================

cat("Loading data...\n")

# --- Panel A: Stochastic projections ---
proj_file <- file.path(output_dir, "stochastic_ipm_projection_quantiles.csv")
if (!file.exists(proj_file)) stop("Missing: ", proj_file)
proj_data <- read.csv(proj_file, stringsAsFactors = FALSE)
cat("  Projections:", nrow(proj_data), "rows |",
    n_distinct(proj_data$scenario), "scenarios |",
    n_distinct(proj_data$recruitment_scenario), "recruitment scenarios\n")

# --- Panel B: Regime classifications ---
regime_file <- file.path(output_dir, "regime_switching_year_classification.csv")
if (!file.exists(regime_file)) stop("Missing: ", regime_file)
regime_data <- read.csv(regime_file, stringsAsFactors = FALSE)
cat("  Regime classifications:", nrow(regime_data), "years (",
    min(regime_data$survey_yr), "-", max(regime_data$survey_yr), ")\n")

# --- Panel C: Heatwave scenario summary ---
hw_file <- file.path(output_dir, "heatwave_scenario_summary.csv")
if (!file.exists(hw_file)) stop("Missing: ", hw_file)
hw_data <- read.csv(hw_file, stringsAsFactors = FALSE)
cat("  Heatwave scenarios:", nrow(hw_data), "scenarios\n")

# =============================================================================
# PANEL A: STOCHASTIC POPULATION PROJECTIONS (50-YEAR)
# =============================================================================

cat("\nPanel a: Stochastic population projections...\n")

# Use conservative recruitment scenario for the primary display
proj_cons <- proj_data %>%
  filter(recruitment_scenario == "conservative") %>%
  mutate(
    # Normalize to proportion of starting population
    median_pct = median_population / 1000 * 100,
    q05_pct    = q05 / 1000 * 100,
    q95_pct    = q95 / 1000 * 100,
    scenario_label = case_when(
      scenario == "iid"       ~ "IID",
      scenario == "markov"    ~ "Markov",
      scenario == "none_only" ~ "No disturbance",
      TRUE ~ scenario
    )
  )

# Colors for the three scenarios
scenario_colors <- c(
  "IID"             = pal$surv_mid,
  "Markov"          = pal$accent,
  "No disturbance"  = pal$grow_mid
)

panel_a <- ggplot(proj_cons, aes(x = year)) +
  # Ribbons (5th-95th percentile envelopes)
  geom_ribbon(aes(ymin = q05_pct, ymax = q95_pct, fill = scenario_label),
              alpha = 0.15) +
  # Median trajectories
  geom_line(aes(y = median_pct, color = scenario_label), linewidth = 0.7) +
  scale_color_manual(values = scenario_colors, name = NULL) +
  scale_fill_manual(values = scenario_colors, name = NULL) +
  scale_y_continuous(labels = scales::label_number(suffix = "%")) +
  labs(x = "Projection year", y = "Population (% of initial)") +
  theme_manuscript(base_size = 10) +
  theme(
    legend.position = "bottom",
    legend.key.width = unit(8, "mm"),
    legend.margin = margin(0, 0, 0, 0),
    plot.margin = margin(5, 10, 2, 10, "mm")
  )

cat("  Panel a complete.\n")

# =============================================================================
# PANEL B: REGIME CLASSIFICATIONS (2004-2024)
# =============================================================================

cat("Panel b: Regime classifications...\n")

regime_plot <- regime_data %>%
  mutate(
    regime = factor(regime_label,
                    levels = c("background", "post_disturbance", "catastrophic"),
                    labels = c("Background", "Post-disturbance", "Catastrophic"))
  )

regime_colors <- c(
  "Background"       = pal$grow_mid,
  "Post-disturbance" = "#F0E442",
  "Catastrophic"     = pal$accent
)

panel_b <- ggplot(regime_plot, aes(x = survey_yr, y = 1, fill = regime)) +
  geom_tile(height = 0.8, color = "white", linewidth = 0.3) +
  # Overlay sample size as points below tiles
  geom_point(aes(y = 0.35, size = n_obs), shape = 21, fill = "white",
             color = pal$slate_dark, stroke = 0.4, alpha = 0.8) +
  scale_fill_manual(values = regime_colors, name = NULL) +
  scale_size_continuous(name = "n obs", range = c(0.5, 3),
                        breaks = c(50, 200, 500, 1000)) +
  scale_x_continuous(breaks = seq(2004, 2024, by = 2)) +
  labs(x = "Year", y = NULL) +
  theme_manuscript(base_size = 10) +
  theme(
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_blank(),
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.margin = margin(0, 0, 0, 0),
    plot.margin = margin(2, 10, 2, 10, "mm")
  ) +
  guides(
    fill = guide_legend(order = 1, override.aes = list(color = NA)),
    size = guide_legend(order = 2)
  )

cat("  Panel b complete.\n")

# =============================================================================
# PANEL C: HEATWAVE SCENARIO EFFECTIVE LAMBDA
# =============================================================================

cat("Panel c: Heatwave scenario lambda...\n")

hw_plot <- hw_data %>%
  filter(!is.na(effective_lambda)) %>%
  mutate(
    # Build clean labels
    label = case_when(
      scenario == "baseline" ~ "Baseline\n(no heatwave)",
      TRUE ~ paste0(dhw, " DHW\nevery ", return_interval_yr, " yr")
    ),
    # Order: baseline first, then by DHW ascending + return interval descending
    # (most frequent heatwaves last within each DHW group)
    sort_key = case_when(
      scenario == "baseline" ~ 0,
      TRUE ~ dhw * 100 + (100 - return_interval_yr)
    )
  ) %>%
  arrange(sort_key) %>%
  mutate(label = fct_inorder(label))

# Color by DHW intensity
dhw_colors <- c(
  "0"  = pal$slate_mid,
  "8"  = "#F0E442",
  "12" = pal$accent,
  "18" = "#CC0000"
)

panel_c <- ggplot(hw_plot, aes(x = label, y = effective_lambda)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = pal$slate_light,
             linewidth = 0.5) +
  geom_point(aes(color = factor(dhw)), size = 2.5) +
  geom_segment(aes(x = label, xend = label,
                   y = 1, yend = effective_lambda,
                   color = factor(dhw)),
               linewidth = 0.5) +
  scale_color_manual(values = dhw_colors, name = "DHW") +
  scale_y_continuous(limits = c(0.4, 1.05), breaks = seq(0.4, 1.0, by = 0.1)) +
  labs(x = NULL, y = expression("Effective " * lambda)) +
  annotate("text", x = Inf, y = 1.02, label = expression(lambda * " = 1"),
           hjust = 1.1, vjust = 0, size = 3, color = pal$slate_mid) +
  theme_manuscript(base_size = 10) +
  theme(
    axis.text.x = element_text(size = 7, lineheight = 0.9, angle = 40, hjust = 1),
    legend.position = "bottom",
    legend.margin = margin(0, 0, 0, 0),
    plot.margin = margin(2, 10, 5, 10, "mm")
  )

cat("  Panel c complete.\n")

# =============================================================================
# COMBINE PANELS
# =============================================================================

cat("\nAssembling 3-panel figure...\n")

fig_temporal <- panel_a / panel_b / panel_c +
  plot_layout(heights = c(3, 1.2, 2.5)) +
  plot_annotation(tag_levels = "a") &
  theme(
    plot.tag = element_text(size = 12, face = "bold", color = pal$slate_dark)
  )

# =============================================================================
# SAVE
# =============================================================================

save_manuscript_fig(fig_temporal, "FigS28_temporal_synthesis",
                    width_mm = 174, height_mm = 210, fig_dir = supp_dir)

cat("\nDone. Temporal synthesis figure saved to:\n")
cat("  ", file.path(supp_dir, "FigS28_temporal_synthesis.png"), "\n")
cat("  ", file.path(supp_dir, "FigS28_temporal_synthesis.pdf"), "\n")
cat("================================================================\n")
