#!/usr/bin/env Rscript
################################################################################
# 26_SUPP_S8_S9.R
# Supplementary Figures S8 and S9 — Meta-Analysis Forest Plots and
# Heterogeneity Decomposition
################################################################################
#
# PURPOSE:
#   Generate journal-ready supplementary figures for Coral Reefs (Springer):
#     FigS8 — Forest plots: (a) overall, (b) stratified by natural vs restoration
#     FigS9 — Heterogeneity: (a) I-squared gauge, (b) variance decomposition,
#              (c) CI vs PI comparison, (d) moderator effects
#
# JOURNAL SPECS (Coral Reefs, Springer):
#   Width: 174 mm (double-column)
#   Max height: 234 mm
#   DPI: 300
#   Font: sans / Helvetica, 8-12 pt
#   Panel labels: lowercase (a), (b), (c), (d) via patchwork tag_levels
#   NO titles or captions within figures
#   RGB color
#
# INPUTS:
#   - analysis/output/meta_analysis_study_effects.csv
#   - analysis/output/meta_analysis_results.csv
#   - analysis/output/meta_analysis_stratified.csv
#   - analysis/output/meta_analysis_moderators.csv
#
# OUTPUTS:
#   - analysis/figures/supplementary/FigS8_forest_plots.png  (+ .pdf)
#   - analysis/figures/supplementary/FigS9_heterogeneity.png (+ .pdf)
#
# Author: Detmer & Stier Lab
# Date: 2026-02
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("analysis/scripts/utils/shared_utilities.R")) {
  source("analysis/scripts/utils/shared_utilities.R")
}

suppressPackageStartupMessages(library(patchwork))

set.seed(42)

dirs <- setup_output_dirs()
supp_dir <- dirs$figures_supp
dir.create(supp_dir, showWarnings = FALSE, recursive = TRUE)

print_header("26: SUPPLEMENTARY FIGURES S8 & S9 (META-ANALYSIS)")

# ==============================================================================
# LOAD PRE-COMPUTED DATA
# ==============================================================================

print_subheader("Loading pre-computed meta-analysis outputs")

study_effects <- read_csv(file.path(dirs$output, "expanded_meta_analysis_study_effects.csv"),
                          show_col_types = FALSE)
meta_results  <- read_csv(file.path(dirs$output, "expanded_meta_analysis_results.csv"),
                          show_col_types = FALSE)
meta_strat    <- read_csv(file.path(dirs$output, "expanded_meta_analysis_stratified.csv"),
                          show_col_types = FALSE)
moderator_df  <- read_csv(file.path(dirs$output, "meta_analysis_moderators.csv"),
                          show_col_types = FALSE)

# Extract key statistics from meta_results
get_meta_val <- function(stat) {
  val <- meta_results$value[meta_results$statistic == stat]
  as.numeric(val)
}

pooled_surv       <- get_meta_val("Pooled survival (RE)")
pooled_surv_lower <- get_meta_val("95% CI lower")
pooled_surv_upper <- get_meta_val("95% CI upper")
pred_surv_lower   <- get_meta_val("95% PI lower")
pred_surv_upper   <- get_meta_val("95% PI upper")
I_sq              <- get_meta_val("I^2 (%)")
I_sq_lower        <- get_meta_val("I^2 CI lower")
I_sq_upper        <- get_meta_val("I^2 CI upper")
tau_sq            <- get_meta_val("tau^2")
tau_val           <- get_meta_val("tau")
Q_stat            <- get_meta_val("Cochran's Q")
k_studies         <- get_meta_val("Number of studies (k)")

cat(sprintf("  k = %d studies, I^2 = %.1f%%, pooled survival = %.1f%%\n",
            k_studies, I_sq, pooled_surv * 100))

# ==============================================================================
# STUDY NAME MAPPING (code names -> proper citations)
# ==============================================================================

study_name_map <- c(
  "NOAA_survey"         = "NOAA NCRMP",
  "kuffner_et_al_2020"  = "Kuffner et al. (2020)",
  "pausch_et_al_2018"   = "Pausch et al. (2018)",
  "fundemar_fragments"  = "FUNDEMAR",
  "USGS_USVI_exp"       = "USGS USVI"
)

study_effects <- study_effects %>%
  mutate(
    study_cite = ifelse(study %in% names(study_name_map),
                        study_name_map[study], study)
  )

# ==============================================================================
# FIGURE S8: FOREST PLOTS (2-panel vertical stack)
# ==============================================================================

print_subheader("Creating Figure S8: Forest Plots")

pal <- MANUSCRIPT_PALETTE

# Compute RE weights from pre-computed data
study_effects <- study_effects %>%
  mutate(
    weight_re     = 1 / (var_log_odds + tau_sq),
    weight_re_pct = weight_re / sum(weight_re) * 100,
    surv_lower_p  = surv_lower,
    surv_upper_p  = surv_upper
  )

# --- Panel (a): Overall forest plot ---

forest_a <- study_effects %>%
  arrange(desc(survival_rate)) %>%
  mutate(
    study_label = sprintf("%s (n = %s)", study_cite, trimws(format(n_total, big.mark = ","))),
    study_label = factor(study_label, levels = rev(study_label))
  )

n_studies <- nrow(forest_a)

p_forest_a <- ggplot(forest_a, aes(y = study_label)) +
  # Prediction interval shading (behind everything)
  annotate("rect",
           xmin = pred_surv_lower, xmax = pred_surv_upper,
           ymin = 0.4, ymax = n_studies + 0.6,
           fill = pal$surv_light, alpha = 0.12) +
  # Pooled estimate vertical line
  geom_vline(xintercept = pooled_surv, linetype = "dashed",
             color = pal$slate_mid, linewidth = 0.5) +
  # Study confidence intervals
  geom_errorbar(aes(xmin = surv_lower_p, xmax = surv_upper_p),
                width = 0.2, color = pal$slate_mid, linewidth = 0.5,
                orientation = "y") +
  # Study point estimates (sized by RE weight)
  geom_point(aes(x = survival_rate, size = weight_re_pct),
             color = pal$surv_mid, shape = 15) +
  # Separator line above pooled row
  annotate("segment", x = 0.15, xend = 0.95, y = 0.6, yend = 0.6,
           color = pal$slate_light, linewidth = 0.3) +
  # Pooled diamond below study rows
  annotate("point", x = pooled_surv, y = 0.3,
           shape = 23, size = 3.5, fill = pal$accent, color = pal$accent) +
  annotate("errorbar", xmin = pooled_surv_lower, xmax = pooled_surv_upper,
           y = 0.3, width = 0.12, color = pal$accent, linewidth = 0.7,
           orientation = "y") +
  # Pooled label above the diamond
  annotate("text", x = pooled_surv, y = 0.05,
           label = sprintf("Pooled: %.0f%% [%.0f, %.0f]",
                           pooled_surv * 100,
                           pooled_surv_lower * 100,
                           pooled_surv_upper * 100),
           size = 2.3, color = pal$accent, fontface = "bold", hjust = 0.5) +
  # Scales
  scale_x_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2),
    labels = scales::percent_format(accuracy = 1),
    expand = c(0.02, 0)
  ) +
  scale_size_continuous(range = c(2.5, 7), guide = "none") +
  coord_cartesian(clip = "off") +
  labs(x = "Annual survival", y = NULL) +
  theme_manuscript() +
  theme(
    axis.text.y  = element_text(size = 9),
    panel.grid.major.y = element_blank(),
    plot.margin = margin(8, 12, 14, 4, "mm")
  )

# --- Panel (b): Stratified forest plot (natural vs restoration) ---

pop_colors <- c("Natural colony" = pal$natural, "Restoration fragment" = pal$restoration)

# Stratified pooled estimates (exclude difference row)
strat_pooled <- meta_strat %>%
  filter(!is.na(k)) %>%
  filter(population_type %in% c("Natural colony", "Restoration fragment"))

# Order: natural first (top), then restoration studies sorted by survival
forest_b <- study_effects %>%
  arrange(desc(population_type == "Natural colony"), desc(survival_rate)) %>%
  mutate(
    study_label = sprintf("%s (n = %s)", study_cite, trimws(format(n_total, big.mark = ","))),
    study_label = factor(study_label, levels = rev(study_label))
  )

p_forest_b <- ggplot(forest_b, aes(y = study_label)) +
  # Overall pooled reference line
  geom_vline(xintercept = pooled_surv, linetype = "dotted",
             color = pal$slate_light, linewidth = 0.4) +
  # Stratified pooled lines
  geom_vline(data = strat_pooled,
             aes(xintercept = pooled_survival, color = population_type),
             linetype = "dashed", linewidth = 0.6, show.legend = FALSE) +
  # Study confidence intervals
  geom_errorbar(aes(xmin = surv_lower_p, xmax = surv_upper_p),
                width = 0.2, color = pal$slate_mid, linewidth = 0.5,
                orientation = "y") +
  # Study point estimates colored by population type
  geom_point(aes(x = survival_rate, size = weight_re_pct,
                 color = population_type),
             shape = 15) +
  # Scales
  scale_color_manual(values = pop_colors, name = NULL) +
  scale_x_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2),
    labels = scales::percent_format(accuracy = 1),
    expand = c(0.02, 0)
  ) +
  scale_size_continuous(range = c(2.5, 7), guide = "none") +
  labs(x = "Annual survival", y = NULL) +
  theme_manuscript() +
  theme(
    axis.text.y  = element_text(size = 9),
    panel.grid.major.y = element_blank(),
    legend.position = "bottom",
    legend.text = element_text(size = 9),
    legend.margin = margin(0, 0, 0, 0),
    plot.margin = margin(4, 12, 8, 4, "mm")
  )

# --- Combine S8 panels vertically ---

p_S8 <- p_forest_a / p_forest_b +
  plot_layout(heights = c(1, 1.1)) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 12, face = "bold"))

# Save FigS8
save_manuscript_fig(p_S8, "FigS8_forest_plots",
                    width_mm = 174, height_mm = 185,
                    fig_dir = supp_dir)

# ==============================================================================
# FIGURE S9: HETEROGENEITY DECOMPOSITION (2x2 grid)
# ==============================================================================

print_subheader("Creating Figure S9: Heterogeneity Decomposition")

# --- Panel (a): I-squared gauge/bar ---

i_sq_bars <- data.frame(
  category = factor(c("Low", "Moderate", "Substantial", "Considerable"),
                    levels = c("Low", "Moderate", "Substantial", "Considerable")),
  start = c(0, 25, 50, 75),
  end   = c(25, 50, 75, 100),
  fill  = c("#27AE60", "#F1C40F", "#E67E22", "#E74C3C")
)

p_a <- ggplot(i_sq_bars) +
  geom_rect(aes(xmin = start, xmax = end, ymin = 0, ymax = 1, fill = fill),
            alpha = 0.7) +
  # Observed I-squared marker
  geom_vline(xintercept = I_sq, color = pal$slate_dark, linewidth = 1.3) +
  # CI bracket
  annotate("errorbar",
           xmin = I_sq_lower, xmax = I_sq_upper, y = 0.5,
           width = 0.25, color = pal$slate_dark, linewidth = 0.5,
           orientation = "y") +
  # Label
  annotate("label",
           x = I_sq, y = 0.5,
           label = sprintf("%.1f%%", I_sq),
           fill = "white", size = 3.5, fontface = "bold",
           label.padding = unit(0.2, "lines")) +
  # Category labels at bottom
  annotate("text",
           x = c(12.5, 37.5, 62.5, 87.5), y = -0.22,
           label = c("Low", "Moderate", "Substantial", "Consid."),
           size = 2.2, color = pal$slate_mid) +
  scale_fill_identity() +
  scale_x_continuous(breaks = c(0, 25, 50, 75, 100),
                     labels = paste0(c(0, 25, 50, 75, 100), "%"),
                     limits = c(0, 100), expand = c(0, 0)) +
  scale_y_continuous(limits = c(-0.38, 1.1), expand = c(0, 0)) +
  coord_cartesian(clip = "off") +
  labs(
    x = expression(I^2 ~ "(%)"),
    y = NULL
  ) +
  theme_manuscript() +
  theme(
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    panel.grid   = element_blank(),
    plot.margin  = margin(8, 8, 14, 8, "mm")
  )

# --- Panel (b): Variance decomposition ---

mean_within_var <- mean(study_effects$var_log_odds)
total_var <- tau_sq + mean_within_var

var_data <- data.frame(
  component = factor(c("Between-study", "Within-study"),
                     levels = c("Between-study", "Within-study")),
  variance  = c(tau_sq, mean_within_var),
  pct       = c(tau_sq / total_var * 100, mean_within_var / total_var * 100),
  fill_col  = c(pal$accent, pal$surv_mid)
)

p_b <- ggplot(var_data, aes(x = pct, y = component, fill = fill_col)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = sprintf("%.1f%%\n(var = %.3f)", pct, variance)),
            hjust = -0.05, size = 2.4, color = pal$slate_dark, lineheight = 0.9) +
  scale_fill_identity() +
  scale_x_continuous(limits = c(0, 130), breaks = seq(0, 100, 25),
                     labels = paste0(seq(0, 100, 25), "%"),
                     expand = c(0, 0)) +
  labs(
    x = "Proportion of total variance",
    y = NULL
  ) +
  theme_manuscript() +
  theme(
    panel.grid.major.y = element_blank(),
    axis.text.y = element_text(size = 9),
    plot.margin = margin(8, 8, 8, 8, "mm")
  )

# --- Panel (c): CI vs PI comparison ---

interval_data <- data.frame(
  type = factor(c("95% CI", "95% PI"),
                levels = c("95% CI", "95% PI")),
  estimate = pooled_surv,
  lower    = c(pooled_surv_lower, pred_surv_lower),
  upper    = c(pooled_surv_upper, pred_surv_upper),
  fill_col = c(pal$surv_mid, pal$accent),
  stringsAsFactors = FALSE
)

# Compute widths for annotation
ci_width <- round((pooled_surv_upper - pooled_surv_lower) * 100)
pi_width <- round((pred_surv_upper - pred_surv_lower) * 100)

p_c <- ggplot(interval_data, aes(y = type)) +
  # Interval bars
  geom_errorbar(aes(xmin = lower, xmax = upper, color = fill_col),
                width = 0.2, linewidth = 1.0, orientation = "y") +
  # Point estimate
  geom_point(aes(x = estimate), size = 3, color = pal$slate_dark, shape = 16) +
  # Width annotation
  geom_text(aes(x = (lower + upper) / 2,
                label = sprintf("Width: %d pp", round((upper - lower) * 100))),
            vjust = -1.4, size = 2.6, color = pal$slate_mid) +
  scale_color_identity() +
  scale_x_continuous(limits = c(0, 1),
                     breaks = seq(0, 1, 0.25),
                     labels = scales::percent_format(accuracy = 1)) +
  coord_cartesian(clip = "off") +
  labs(
    x = "Annual survival",
    y = NULL
  ) +
  theme_manuscript() +
  theme(
    panel.grid.major.y = element_blank(),
    axis.text.y = element_text(size = 9),
    plot.margin = margin(10, 8, 8, 8, "mm")
  )

# --- Panel (d): Moderator effects ---

mod_plot <- moderator_df %>%
  mutate(
    significant = p_value < 0.05,
    moderator = factor(moderator, levels = rev(moderator)),
    point_col = ifelse(significant, pal$accent, pal$slate_light)
  )

p_d <- ggplot(mod_plot, aes(y = moderator)) +
  # Null reference
  geom_vline(xintercept = 0, linetype = "dashed", color = pal$slate_light,
             linewidth = 0.4) +
  # CI bars
  geom_errorbar(aes(xmin = ci_lower, xmax = ci_upper),
                width = 0.15, color = pal$slate_mid, linewidth = 0.5,
                orientation = "y") +
  # Point estimates
  geom_point(aes(x = coefficient, color = point_col), size = 3, shape = 16) +
  scale_color_identity() +
  labs(
    x = "Regression coefficient\n(log-odds scale)",
    y = NULL
  ) +
  theme_manuscript() +
  theme(
    panel.grid.major.y = element_blank(),
    axis.text.y = element_text(size = 8),
    plot.margin = margin(10, 10, 8, 8, "mm")
  )

# --- Combine S9 panels in 2x2 grid ---

p_S9 <- (p_a + p_b) / (p_c + p_d) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 12, face = "bold"))

# Save FigS9
save_manuscript_fig(p_S9, "FigS9_heterogeneity",
                    width_mm = 174, height_mm = 174,
                    fig_dir = supp_dir)

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n")
print_header("SUPPLEMENTARY FIGURES S8 & S9 COMPLETE")
cat("  FigS8_forest_plots -- 2 panels: (a) overall, (b) stratified\n")
cat("  FigS9_heterogeneity -- 4 panels: (a) I-squared, (b) variance,\n")
cat("                         (c) CI vs PI, (d) moderators\n")
cat(sprintf("  Journal specs: 174 mm width, 300 DPI, sans font\n"))
cat(sprintf("  Output directory: %s\n\n", supp_dir))
