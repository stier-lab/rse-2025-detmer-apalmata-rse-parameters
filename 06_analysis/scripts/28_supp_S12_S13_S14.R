#!/usr/bin/env Rscript
# =============================================================================
# SUPPLEMENTARY FIGURES S12, S13, S14
# =============================================================================
# FigS12: Sensitivity analysis (2 panels)
#   (a) Multi-dimensional robustness dashboard — lambda under different
#       assumptions (leave-one-out, boundary shifts, outlier removal)
#   (b) Bootstrap confidence intervals for survival by size class
#
# FigS13: Cross-validation (2 panels)
#   (a) LOSO Brier scores by study
#   (b) Model comparison via 5-fold CV
#
# FigS14: Population projections (2 panels)
#   (a) Deterministic 20-year trajectory by size class
#   (b) Stochastic projections with 80% PI and quasi-extinction threshold
#
# Journal: Coral Reefs (Springer) — 174mm double-column, max 234mm height,
#          300 DPI, sans-serif 8-12pt, lowercase panel labels, NO titles/captions
#
# INPUTS:
#   - 06_analysis/output/sensitivity_lambda_loo.csv
#   - 06_analysis/output/sensitivity_lambda_boundaries.csv
#   - 06_analysis/output/sensitivity_lambda_outliers.csv
#   - 06_analysis/output/bootstrap_confidence_intervals.csv
#   - 06_analysis/output/cross_validation_results.csv
#   - 06_analysis/output/cv_model_comparison.csv
#   - 06_analysis/output/transition_matrix.rds
#   - 06_analysis/output/stochastic_projections.csv
#   - 06_analysis/output/population_parameters.csv
#
# OUTPUTS:
#   - 06_analysis/figures/supplementary/FigS12_sensitivity.png + .pdf
#   - 06_analysis/figures/supplementary/FigS13_cross_validation.png + .pdf
#   - 06_analysis/figures/supplementary/FigS14_population_projections.png + .pdf
#
# Author: Detmer & Stier Lab
# Date: 2026-02
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
cat("  SUPPLEMENTARY FIGURES S12, S13, S14\n")
cat("================================================================\n\n")

# =============================================================================
# LOAD DATA
# =============================================================================

cat("Loading data...\n")

# --- S12 data ---
lambda_loo <- read.csv(file.path(output_dir, "sensitivity_lambda_loo.csv"),
                       stringsAsFactors = FALSE)
lambda_boundaries <- read.csv(file.path(output_dir, "sensitivity_lambda_boundaries.csv"),
                              stringsAsFactors = FALSE)
lambda_outliers <- read.csv(file.path(output_dir, "sensitivity_lambda_outliers.csv"),
                            stringsAsFactors = FALSE)
boot_ci <- read.csv(file.path(output_dir, "bootstrap_confidence_intervals.csv"),
                    stringsAsFactors = FALSE)

# --- S13 data ---
cv_results <- read.csv(file.path(output_dir, "cross_validation_results.csv"),
                       stringsAsFactors = FALSE)
cv_model_comp <- read.csv(file.path(output_dir, "cv_model_comparison.csv"),
                          stringsAsFactors = FALSE)

# --- S14 data ---
pop_params <- read.csv(file.path(output_dir, "population_parameters.csv"),
                       stringsAsFactors = FALSE)
stoch_proj <- read.csv(file.path(output_dir, "stochastic_projections.csv"),
                       stringsAsFactors = FALSE)
tm_list <- readRDS(file.path(output_dir, "transition_matrix.rds"))
A_matrix <- tm_list$projection_matrix

# Extract key values
lambda_det <- as.numeric(pop_params$value[pop_params$parameter == "lambda"])
p_decline <- as.numeric(pop_params$value[pop_params$parameter == "p_decline"])

cat(sprintf("  Lambda = %.4f, P(decline) = %.1f%%\n", lambda_det, p_decline * 100))
cat(sprintf("  LOO studies: %d, Boundary sets: %d, Outlier criteria: %d\n",
            nrow(lambda_loo), nrow(lambda_boundaries), nrow(lambda_outliers)))
cat(sprintf("  CV results: %d rows, Model comparison: %d models\n",
            nrow(cv_results), nrow(cv_model_comp)))
cat(sprintf("  Projection data: %d years\n", nrow(stoch_proj) - 1))


# =============================================================================
# FIGURE S12: SENSITIVITY ANALYSIS
# =============================================================================

cat("\nBuilding Figure S12: Sensitivity Analysis...\n")

# --- Panel (a): Multi-dimensional sensitivity dashboard ---
# Combine all sensitivity analyses into a single dot-plot with lambda on x-axis

# LOO: label by study excluded
loo_df <- lambda_loo %>%
  mutate(
    category = "Leave-one-out",
    label = gsub("_", " ", excluded_study),
    label = tools::toTitleCase(label)
  ) %>%
  select(category, label, lambda)

# Boundary sets
bound_df <- lambda_boundaries %>%
  mutate(
    category = "Size boundaries",
    label = gsub("_", " ", boundary_set)
  ) %>%
  select(category, label, lambda)

# Outlier criteria
outlier_df <- lambda_outliers %>%
  mutate(
    category = "Data filtering",
    label = criterion
  ) %>%
  select(category, label, lambda)

# Combine all
sensitivity_all <- bind_rows(loo_df, bound_df, outlier_df) %>%
  mutate(
    category = factor(category,
                      levels = c("Leave-one-out", "Size boundaries", "Data filtering")),
    label = factor(label, levels = rev(unique(label)))
  )

# Color by category using MANUSCRIPT_PALETTE
cat_colors <- c(
  "Leave-one-out"  = pal$surv_mid,
  "Size boundaries" = pal$grow_mid,
  "Data filtering"  = pal$accent
)

# Number of rows for annotation positioning (use top of panel)
n_labels <- nrow(sensitivity_all)

p_s12a <- ggplot(sensitivity_all, aes(x = lambda, y = label, color = category)) +
  geom_vline(xintercept = 1.0, linetype = "solid", color = "grey70", linewidth = 0.4) +
  geom_vline(xintercept = lambda_det, linetype = "dashed", color = pal$slate_mid,
             linewidth = 0.5) +
  geom_point(size = 2.5) +
  scale_color_manual(values = cat_colors, name = NULL) +
  scale_x_continuous(
    breaks = seq(0.94, 1.01, by = 0.01),
    limits = c(NA, 1.01),
    labels = function(x) sprintf("%.2f", x)
  ) +
  labs(
    x = expression(lambda),
    y = NULL,
    tag = "a"
  ) +
  annotate("text", x = lambda_det, y = n_labels + 0.4,
           label = paste0("baseline (", sprintf("%.3f", lambda_det), ")"),
           hjust = 0.5, vjust = 0, size = 2.8, color = pal$slate_mid, fontface = "italic") +
  annotate("text", x = 1.0, y = n_labels + 0.4, label = "stable",
           hjust = 0.5, vjust = 0, size = 2.8, color = "grey50", fontface = "italic") +
  coord_cartesian(clip = "off") +
  theme_manuscript(base_size = 10) +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = 8),
    legend.key.size = unit(3, "mm"),
    axis.text.y = element_text(size = 8),
    plot.margin = margin(8, 8, 5, 5, "mm")
  )

# --- Panel (b): Bootstrap CIs by size class ---

# Compute overall mean survival from the bootstrap CI data for reference line
overall_surv <- weighted.mean(boot_ci$mean, w = rep(1, nrow(boot_ci)))

boot_ci_plot <- boot_ci %>%
  mutate(
    size_class = factor(size_class, levels = SIZE_LABELS),
    ci_upper_capped = pmin(ci_upper, 1.0)
  )

p_s12b <- ggplot(boot_ci_plot, aes(x = size_class, y = mean)) +
  geom_hline(yintercept = overall_surv, linetype = "dashed", color = pal$slate_light,
             linewidth = 0.4) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper_capped),
                width = 0.25, color = pal$surv_dark, linewidth = 0.6) +
  geom_point(size = 3, color = pal$surv_dark, fill = pal$surv_mid, shape = 21,
             stroke = 0.8) +
  scale_y_continuous(
    limits = c(0.4, 1.05),
    breaks = seq(0.4, 1.0, by = 0.1),
    labels = scales::percent_format(accuracy = 1)
  ) +
  scale_x_discrete(labels = SIZE_LABELS_DESCRIPTIVE) +
  annotate("text", x = 0.6, y = overall_surv + 0.02,
           label = sprintf("overall mean (%.0f%%)", overall_surv * 100),
           hjust = 0, size = 2.8, color = pal$slate_mid, fontface = "italic") +
  labs(
    x = "Size class",
    y = "Survival probability (95% CI)",
    tag = "b"
  ) +
  theme_manuscript(base_size = 10) +
  theme(
    axis.text.x = element_text(size = 7.5, angle = 25, hjust = 1),
    plot.margin = margin(5, 5, 5, 8, "mm")
  )

# --- Compose S12 ---
fig_s12 <- p_s12a / p_s12b +
  plot_layout(heights = c(1.3, 1)) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 12, face = "bold"))

save_manuscript_fig(fig_s12, "FigS12_sensitivity",
                    width_mm = 174, height_mm = 160, fig_dir = supp_dir)
cat("  Done: FigS12_sensitivity\n")


# =============================================================================
# FIGURE S13: CROSS-VALIDATION
# =============================================================================

cat("\nBuilding Figure S13: Cross-Validation...\n")

# --- Panel (a): LOSO Brier scores by study ---

loso_data <- cv_results %>%
  filter(cv_method == "LOSO", !is.na(brier_score)) %>%
  mutate(
    fold_label = gsub("_", " ", fold),
    fold_label = tools::toTitleCase(fold_label),
    fold_label = reorder(fold_label, brier_score)
  )

# Color by whether Brier > 0.25 (relatively poor prediction)
p_s13a <- ggplot(loso_data, aes(x = fold_label, y = brier_score)) +
  geom_hline(yintercept = 0.25, linetype = "dashed", color = pal$slate_light,
             linewidth = 0.4) +
  geom_segment(aes(xend = fold_label, y = 0, yend = brier_score),
               color = pal$surv_mid, linewidth = 0.8) +
  geom_point(aes(size = n_test), color = pal$surv_dark, fill = pal$surv_mid,
             shape = 21, stroke = 0.6) +
  scale_size_continuous(range = c(2, 5), name = "n (test set)",
                        breaks = c(50, 500, 2000, 4000)) +
  scale_y_continuous(limits = c(0, 0.45), breaks = seq(0, 0.4, by = 0.1)) +
  coord_flip(clip = "off") +
  labs(
    x = NULL,
    y = "Brier score",
    tag = "a"
  ) +
  annotate("text", y = 0.26, x = nrow(loso_data) + 0.3, label = "poor prediction",
           hjust = 0.1, size = 2.5, color = pal$slate_mid, fontface = "italic") +
  theme_manuscript(base_size = 10) +
  theme(
    legend.position = c(0.85, 0.3),
    legend.background = element_rect(fill = "white", color = NA),
    legend.key.size = unit(3, "mm"),
    legend.text = element_text(size = 7),
    legend.title = element_text(size = 8),
    axis.text.y = element_text(size = 8),
    plot.margin = margin(8, 10, 5, 5, "mm")
  )

# --- Panel (b): Model comparison via K-fold CV ---

model_comp_plot <- cv_model_comp %>%
  mutate(
    model = factor(model, levels = model[order(mean_brier, decreasing = TRUE)])
  )

p_s13b <- ggplot(model_comp_plot, aes(x = model, y = mean_brier)) +
  geom_segment(aes(xend = model, y = mean_brier - sd_brier, yend = mean_brier + sd_brier),
               color = pal$grow_mid, linewidth = 0.8) +
  geom_point(size = 3, color = pal$grow_dark, fill = pal$grow_mid, shape = 21,
             stroke = 0.8) +
  coord_flip() +
  scale_y_continuous(limits = c(0, 0.45), breaks = seq(0, 0.4, by = 0.1)) +
  labs(
    x = NULL,
    y = expression("Mean Brier score (" %+-% " SD)"),
    tag = "b"
  ) +
  theme_manuscript(base_size = 10) +
  theme(
    axis.text.y = element_text(size = 8),
    plot.margin = margin(5, 5, 5, 8, "mm")
  )

# --- Compose S13 ---
fig_s13 <- p_s13a + p_s13b +
  plot_layout(widths = c(1, 1)) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 12, face = "bold"))

save_manuscript_fig(fig_s13, "FigS13_cross_validation",
                    width_mm = 174, height_mm = 100, fig_dir = supp_dir)
cat("  Done: FigS13_cross_validation\n")


# =============================================================================
# FIGURE S14: POPULATION PROJECTIONS
# =============================================================================

cat("\nBuilding Figure S14: Population Projections...\n")

# --- Panel (a): Deterministic 20-year trajectory by size class ---

# Reconstruct deterministic projections from transition matrix
n_years <- 20
initial_pop <- c(100, 50, 30, 20, 10)
names(initial_pop) <- SIZE_LABELS

projections <- matrix(0, nrow = n_years + 1, ncol = 5)
projections[1, ] <- initial_pop
colnames(projections) <- SIZE_LABELS

for (t in 2:(n_years + 1)) {
  projections[t, ] <- A_matrix %*% projections[t - 1, ]
}

proj_df <- as.data.frame(projections) %>%
  mutate(year = 0:n_years) %>%
  pivot_longer(cols = all_of(SIZE_LABELS),
               names_to = "size_class", values_to = "n") %>%
  mutate(size_class = factor(size_class, levels = rev(SIZE_LABELS)))

# Also compute total
proj_total <- proj_df %>%
  group_by(year) %>%
  summarise(total = sum(n), .groups = "drop")

p_s14a <- ggplot(proj_df, aes(x = year, y = n, fill = size_class)) +
  geom_area(alpha = 0.85, color = "white", linewidth = 0.2) +
  scale_fill_manual(values = SIZE_CLASS_COLORS, name = "Size class") +
  scale_x_continuous(breaks = seq(0, 20, by = 5), expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  annotate("text", x = 18, y = proj_total$total[proj_total$year == 20] + 5,
           label = sprintf("%.0f", proj_total$total[proj_total$year == 20]),
           size = 2.8, color = pal$slate_mid, fontface = "italic") +
  annotate("text", x = 1, y = sum(initial_pop) + 5,
           label = sprintf("n = %d", sum(initial_pop)),
           size = 2.8, color = pal$slate_mid, fontface = "italic", hjust = 0) +
  labs(
    x = "Year",
    y = "Number of individuals",
    tag = "a"
  ) +
  theme_manuscript(base_size = 10) +
  theme(
    legend.position = "bottom",
    legend.key.size = unit(3.5, "mm"),
    legend.text = element_text(size = 7.5),
    legend.title = element_text(size = 8),
    plot.margin = margin(5, 8, 5, 5, "mm")
  )

# --- Panel (b): Stochastic projections with 80% PI ---

# Quasi-extinction threshold at 10% of initial population
qe_threshold <- sum(initial_pop) * 0.1

p_s14b <- ggplot(stoch_proj, aes(x = year)) +
  # 95% CI ribbon (lighter)
  geom_ribbon(aes(ymin = ci_lower_95, ymax = ci_upper_95),
              fill = pal$surv_light, alpha = 0.3) +
  # 80% PI ribbon (darker)
  geom_ribbon(aes(ymin = pi_lower_80, ymax = pi_upper_80),
              fill = pal$surv_mid, alpha = 0.35) +
  # Deterministic trajectory
  geom_line(aes(y = deterministic, linetype = "Deterministic"),
            color = pal$accent, linewidth = 0.7) +
  # Median parametric uncertainty trajectory
  geom_line(aes(y = stochastic_median, linetype = "Median (parametric uncertainty)"),
            color = pal$surv_dark, linewidth = 0.8) +
  # Quasi-extinction threshold
  geom_hline(yintercept = qe_threshold, linetype = "dotted",
             color = "#c62828", linewidth = 0.5) +
  annotate("text", x = 20, y = qe_threshold,
           label = sprintf("quasi-extinction (%.0f)", qe_threshold),
           hjust = 1, vjust = -0.6, size = 2.5, color = "#c62828", fontface = "italic") +
  # Lambda annotation
  annotate("text", x = 1, y = max(stoch_proj$ci_upper_95) * 0.95,
           label = sprintf("lambda == %.3f", lambda_det),
           parse = TRUE, hjust = 0, size = 3, color = pal$slate_mid) +
  scale_linetype_manual(
    values = c("Deterministic" = "dashed",
               "Median (parametric uncertainty)" = "solid"),
    name = NULL
  ) +
  scale_x_continuous(breaks = seq(0, 20, by = 5), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  labs(
    x = "Year",
    y = "Total population",
    tag = "b"
  ) +
  theme_manuscript(base_size = 10) +
  theme(
    legend.position = "bottom",
    legend.key.size = unit(4, "mm"),
    legend.key.width = unit(10, "mm"),
    legend.text = element_text(size = 7.5),
    plot.margin = margin(5, 5, 5, 8, "mm")
  )

# --- Compose S14 ---
fig_s14 <- p_s14a + p_s14b +
  plot_layout(widths = c(1, 1), guides = "collect") +
  plot_annotation(tag_levels = "a") &
  theme(
    plot.tag = element_text(size = 12, face = "bold"),
    legend.position = "bottom"
  )

save_manuscript_fig(fig_s14, "FigS14_population_projections",
                    width_mm = 174, height_mm = 110, fig_dir = supp_dir)
cat("  Done: FigS14_population_projections\n")


# =============================================================================
# SUMMARY
# =============================================================================

cat("\n")
cat("================================================================\n")
cat("  SUPPLEMENTARY FIGURES S12-S14 COMPLETE\n")
cat("================================================================\n")
cat("  FigS12_sensitivity       -- 174 x 160 mm (2 panels: dashboard + bootstrap CIs)\n")
cat("  FigS13_cross_validation  -- 174 x 100 mm (2 panels: LOSO + model comparison)\n")
cat("  FigS14_population_projections -- 174 x 110 mm (2 panels: deterministic + stochastic)\n")
cat("  All saved to: 06_analysis/figures/supplementary/\n")
cat("================================================================\n")
