#!/usr/bin/env Rscript
# =============================================================================
# SUPPLEMENTARY FIGURE: DATA GAPS — CERTAINTY HEATMAP (Size Class x Region)
# =============================================================================
# Heatmap showing data coverage and certainty across size classes and regions.
# Cell values show sample sizes; fill color indicates certainty level.
#
# OUTPUT: analysis/figures/supplementary/FigS2_data_gaps.{png,pdf}
#         174 x 100 mm (double-column), 300 DPI
#
# Author: Detmer & Stier Lab
# Date: 2026-02
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(scales)
})

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("analysis/scripts/utils/shared_utilities.R")) {
  source("analysis/scripts/utils/shared_utilities.R")
}

pal <- MANUSCRIPT_PALETTE
project_root <- get_project_root()
output_dir <- file.path(project_root, "analysis/output")

cat("\n")
cat("================================================================\n")
cat("  SUPPLEMENTARY: Data Gaps — Certainty Heatmap\n")
cat("================================================================\n\n")

# =============================================================================
# LOAD DATA
# =============================================================================

# Try pre-computed certainty matrix first, fall back to raw data
cert_file <- file.path(output_dir, "certainty_matrix.csv")

if (file.exists(cert_file)) {
  cat("  Loading pre-computed certainty matrix...\n")
  certainty_matrix <- read_csv(cert_file, show_col_types = FALSE)
} else {
  cat("  Computing certainty matrix from raw data...\n")
  surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))

  certainty_matrix <- surv_data %>%
    filter(!is.na(size_class)) %>%
    group_by(size_class, region) %>%
    summarise(
      n = n(),
      survival = mean(survived, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    complete(size_class, region, fill = list(n = 0, survival = NA))
}

# Assign certainty levels
certainty_matrix <- certainty_matrix %>%
  mutate(
    certainty = case_when(
      n == 0   ~ "No data",
      n < 30   ~ "Very low",
      n < 100  ~ "Low",
      n < 300  ~ "Moderate",
      TRUE     ~ "High"
    ),
    certainty = factor(certainty,
                       levels = c("No data", "Very low", "Low", "Moderate", "High"))
  )

# Ensure consistent factor levels for size classes
certainty_matrix <- certainty_matrix %>%
  mutate(size_class = factor(size_class, levels = SIZE_LABELS))

# Order regions by total sample size (descending)
region_order <- certainty_matrix %>%
  group_by(region) %>%
  summarise(total_n = sum(n), .groups = "drop") %>%
  arrange(desc(total_n)) %>%
  pull(region)

certainty_matrix <- certainty_matrix %>%
  mutate(region = factor(region, levels = region_order))

cat(sprintf("  Matrix: %d size classes x %d regions\n",
            n_distinct(certainty_matrix$size_class),
            n_distinct(certainty_matrix$region)))

# Summary
cert_summary <- certainty_matrix %>%
  count(certainty) %>%
  arrange(certainty)
for (i in seq_len(nrow(cert_summary))) {
  cat(sprintf("    %s: %d cells\n", cert_summary$certainty[i], cert_summary$n[i]))
}

# =============================================================================
# BUILD FIGURE
# =============================================================================

cat("Building figure...\n")

# Define size class labels with ranges for readability
sc_labels <- c(
  "SC1" = expression("SC1 (0-25 cm"^2*")"),
  "SC2" = expression("SC2 (25-100 cm"^2*")"),
  "SC3" = expression("SC3 (100-500 cm"^2*")"),
  "SC4" = expression("SC4 (500-2k cm"^2*")"),
  "SC5" = expression("SC5 (>2,000 cm"^2*")")
)

# Colors: warm to cool gradient matching certainty
cert_colors <- c(
  "No data"  = "#d9d9d9",
  "Very low"  = "#e07a5f",
  "Low"       = "#f4a261",
  "Moderate"  = "#e9c46a",
  "High"      = "#2a9d8f"
)

fig5 <- ggplot(certainty_matrix,
               aes(x = region, y = size_class, fill = certainty)) +
  geom_tile(color = "white", linewidth = 0.8) +
  # Sample size labels in cells
  geom_text(aes(label = ifelse(n > 0, comma(n), "\u2014")),
            size = 3.0, color = "grey20", family = "Helvetica") +
  scale_fill_manual(
    values = cert_colors,
    name = "Data certainty",
    drop = FALSE
  ) +
  scale_y_discrete(labels = sc_labels) +
  labs(
    x = NULL,
    y = NULL
  ) +
  theme_manuscript() +
  theme(
    text            = element_text(family = "Helvetica"),
    axis.text.x     = element_text(size = 9, angle = 35, hjust = 1,
                                    family = "Helvetica", color = "grey30"),
    axis.text.y     = element_text(size = 9, family = "Helvetica", color = "grey30"),
    axis.ticks      = element_blank(),
    panel.grid      = element_blank(),
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.title    = element_text(size = 9, face = "bold"),
    legend.text     = element_text(size = 8),
    legend.key.size = unit(4, "mm"),
    plot.margin     = margin(6, 8, 4, 6, "mm")
  ) +
  guides(fill = guide_legend(nrow = 1))

# =============================================================================
# SAVE
# =============================================================================

supp_dir <- file.path(project_root, "analysis/figures/supplementary")
dir.create(supp_dir, showWarnings = FALSE, recursive = TRUE)
save_manuscript_fig(fig5, "FigS2_data_gaps", width_mm = 174, height_mm = 100,
                    fig_dir = supp_dir)

cat("\nDone: Fig S2 — Data Gaps Certainty Heatmap\n")
