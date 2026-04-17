#!/usr/bin/env Rscript
################################################################################
# 27_SUPP_S10_S11.R
# Supplementary Figures S10 and S11 — Context Comparison and Climate-Demography
################################################################################
#
# PURPOSE:
#   Generate journal-ready supplementary figures for Coral Reefs (Springer):
#     FigS10 — Context comparison (3 panels):
#       (a) Overall survival by study context
#       (b) Survival by context x size class interaction
#       (c) Effect sizes (Cohen's h) for pairwise context comparisons
#
#     FigS11 — Climate-demography (4 panels):
#       (a) Temporal survival trend (yearly estimates + GLMM trend)
#       (b) Disturbance effects on survival
#       (c) Climate vulnerability by size class (CV of survival)
#       (d) Regional temporal variability
#
# JOURNAL SPECS (Coral Reefs, Springer):
#   Width: 174 mm (double-column)
#   Max height: 234 mm
#   DPI: 300
#   Font: sans / Helvetica, 8-12 pt
#   Panel labels: lowercase (a), (b), (c), (d) via plot_annotation(tag_levels = "a")
#   NO titles or captions within figures (no ggtitle, no labs(title = ...))
#
# INPUTS:
#   - 06_analysis/output/context_survival_comparison.csv
#   - 06_analysis/output/context_survival_by_size.csv
#   - 06_analysis/output/context_pairwise_survival.csv
#   - 06_analysis/output/yearly_survival.csv
#   - 06_analysis/output/temporal_trend_glmm.csv
#   - 06_analysis/output/disturbance_impacts.csv
#   - 06_analysis/output/size_climate_vulnerability.csv
#   - 06_analysis/output/regional_temporal_variability.csv
#
# OUTPUTS:
#   - 06_analysis/figures/supplementary/FigS10_context_comparison.png  (+ .pdf)
#   - 06_analysis/figures/supplementary/FigS11_climate_demography.png  (+ .pdf)
#
# Author: Detmer & Stier Lab
# Date: 2026-02-17
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

suppressPackageStartupMessages(library(patchwork))

set.seed(42)

dirs <- setup_output_dirs()
supp_dir <- dirs$figures_supp
dir.create(supp_dir, showWarnings = FALSE, recursive = TRUE)

print_header("27: SUPPLEMENTARY FIGURES S10 & S11 (CONTEXT + CLIMATE)")

# ==============================================================================
# LOAD PRE-COMPUTED DATA
# ==============================================================================

print_subheader("Loading pre-computed outputs")

# --- S10 data: Context comparison ---
context_survival <- read_csv(file.path(dirs$output, "context_survival_comparison.csv"),
                              show_col_types = FALSE)
context_by_size  <- read_csv(file.path(dirs$output, "context_survival_by_size.csv"),
                              show_col_types = FALSE)
pairwise_surv    <- read_csv(file.path(dirs$output, "context_pairwise_survival.csv"),
                              show_col_types = FALSE)

# --- S11 data: Climate-demography ---
yearly_survival  <- read_csv(file.path(dirs$output, "yearly_survival.csv"),
                              show_col_types = FALSE)
trend_glmm       <- read_csv(file.path(dirs$output, "temporal_trend_glmm.csv"),
                              show_col_types = FALSE)
disturbance_df   <- read_csv(file.path(dirs$output, "disturbance_impacts.csv"),
                              show_col_types = FALSE)
size_climate_vuln <- read_csv(file.path(dirs$output, "size_climate_vulnerability.csv"),
                               show_col_types = FALSE)
regional_var     <- read_csv(file.path(dirs$output, "regional_temporal_variability.csv"),
                              show_col_types = FALSE)

cat("  All data loaded successfully.\n")

# ==============================================================================
# CONTEXT LABELS AND COLORS
# ==============================================================================

# Clean context labels for display
context_labels <- c(
  "field"          = "Field",
  "nursery_insitu" = "Nursery (in situ)",
  "lab"            = "Laboratory"
)

# Okabe-Ito colors for context types (colorblind-safe)
context_colors <- c(
  "field"          = "#009E73",
  "nursery_insitu" = "#0072B2",
  "lab"            = "#D55E00"
)

# ==============================================================================
# FIGURE S10: CONTEXT COMPARISON (3 PANELS)
# ==============================================================================

print_subheader("Building Figure S10: Context comparison")

# --- Panel (a): Overall survival by context ---

# Sort by survival rate for a logical ordering
context_survival <- context_survival %>%
  mutate(
    context_label = context_labels[context],
    context_label = factor(context_label,
                           levels = context_labels[c("nursery_insitu", "field", "lab")])
  )

p_s10a <- ggplot(context_survival,
                  aes(x = context_label, y = mean_survival)) +
  geom_col(aes(fill = context), width = 0.55, show.legend = FALSE) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper),
                width = 0.12, linewidth = 0.4) +
  geom_text(aes(label = paste0("n=", format(n, big.mark = ","))),
            vjust = -1.0, size = 2.5, color = "grey30") +
  scale_y_continuous(
    limits = c(0, 1.12),
    breaks = seq(0, 1, 0.2),
    labels = scales::percent_format(accuracy = 1),
    expand = expansion(mult = c(0, 0))
  ) +
  scale_fill_manual(values = context_colors) +
  labs(x = NULL, y = "Annual survival probability") +
  theme_manuscript(base_size = 9) +
  theme(
    axis.text.x = element_text(size = 7),
    plot.margin = margin(5, 8, 5, 5, "mm")
  )

# --- Panel (b): Survival by context x size class ---

# Ensure size_class is ordered and context has clean labels
context_by_size <- context_by_size %>%
  mutate(
    size_class = factor(size_class, levels = SIZE_LABELS),
    context_label = context_labels[context],
    context_label = factor(context_label,
                           levels = context_labels[c("nursery_insitu", "field", "lab")])
  ) %>%
  # Drop rows with 0 observations or NA survival

  filter(!is.na(mean_survival), n > 0)

p_s10b <- ggplot(context_by_size,
                  aes(x = size_class, y = mean_survival, fill = context)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.65) +
  geom_errorbar(
    aes(ymin = pmax(0, mean_survival - 1.96 * se_survival),
        ymax = pmin(1, mean_survival + 1.96 * se_survival)),
    position = position_dodge(width = 0.75),
    width = 0.2, linewidth = 0.3
  ) +
  scale_y_continuous(
    limits = c(0, 1.08),
    breaks = seq(0, 1, 0.2),
    labels = scales::percent_format(accuracy = 1),
    expand = expansion(mult = c(0, 0))
  ) +
  scale_fill_manual(
    values = context_colors,
    labels = c("field" = "Field",
               "nursery_insitu" = "Nursery (in situ)",
               "lab" = "Laboratory"),
    name = NULL
  ) +
  labs(x = "Size class", y = "Annual survival probability") +
  theme_manuscript(base_size = 9) +
  theme(
    legend.position = "bottom",
    legend.key.size = unit(3, "mm"),
    legend.text = element_text(size = 7),
    legend.margin = margin(0, 0, 0, 0),
    plot.margin = margin(5, 5, 5, 5, "mm")
  )

# --- Panel (c): Effect sizes (Cohen's h) ---

# Build comparison labels and sort by absolute effect size
pairwise_plot <- pairwise_surv %>%
  mutate(
    comparison = paste0(
      context_labels[context1], " vs.\n", context_labels[context2]
    ),
    comparison = gsub("\n\\(in situ\\)", " (in situ)", comparison),
    comparison = gsub("\n", " ", comparison),
    sig_label = case_when(
      p_adjusted < 0.001 ~ "***",
      p_adjusted < 0.01  ~ "**",
      p_adjusted < 0.05  ~ "*",
      TRUE ~ "n.s."
    ),
    bar_color = case_when(
      abs(cohens_h) >= 0.8 ~ "large",
      abs(cohens_h) >= 0.5 ~ "medium",
      abs(cohens_h) >= 0.2 ~ "small",
      TRUE                 ~ "negligible"
    )
  ) %>%
  arrange(abs(cohens_h)) %>%
  mutate(comparison = factor(comparison, levels = comparison))

effect_colors <- c(
  "negligible" = MANUSCRIPT_PALETTE$slate_light,
  "small"      = "#E69F00",
  "medium"     = "#D55E00",
  "large"      = "#CC79A7"
)

# Compute data-driven x limits so the plot doesn't have huge empty space
# when all comparisons have the same sign (e.g. all positive).
h_vals <- pairwise_plot$cohens_h
h_min  <- min(h_vals, na.rm = TRUE)
h_max  <- max(h_vals, na.rm = TRUE)
xlim_lo <- if (h_min >= 0) 0 else floor(h_min * 10) / 10 - 0.1
xlim_hi <- ceiling(h_max * 10) / 10 + 0.25  # headroom for sig stars

# Only draw Cohen's-h reference lines that fall inside the data range so
# we don't leave an orphan dashed line hanging below zero when all
# comparisons are positive.
ref_dashed <- c(-0.2, 0.2)
ref_dotted <- c(-0.8, 0.8)
ref_dashed <- ref_dashed[ref_dashed >= xlim_lo & ref_dashed <= xlim_hi]
ref_dotted <- ref_dotted[ref_dotted >= xlim_lo & ref_dotted <= xlim_hi]

p_s10c <- ggplot(pairwise_plot,
                  aes(x = comparison, y = cohens_h)) +
  geom_col(aes(fill = bar_color), width = 0.6, show.legend = TRUE) +
  geom_hline(yintercept = 0, color = "grey30", linewidth = 0.4) +
  geom_hline(yintercept = ref_dashed, linetype = "dashed",
             color = "grey60", linewidth = 0.3) +
  geom_hline(yintercept = ref_dotted, linetype = "dotted",
             color = "grey60", linewidth = 0.3) +
  geom_text(aes(label = sig_label),
            hjust = ifelse(pairwise_plot$cohens_h >= 0, -0.15, 1.15),
            size = 2.2, color = "grey30") +
  coord_flip(clip = "off", ylim = c(xlim_lo, xlim_hi)) +
  scale_y_continuous(
    breaks = seq(-1, 2, 0.5),
    expand = expansion(mult = c(0.02, 0.04))
  ) +
  scale_fill_manual(
    values = effect_colors,
    name = "Effect size",
    breaks = c("negligible", "small", "medium", "large"),
    labels = c("Neg.", "Small", "Med.", "Large"),
    drop = FALSE
  ) +
  labs(x = NULL, y = "Cohen's h") +
  theme_manuscript(base_size = 9) +
  theme(
    legend.position = "bottom",
    legend.key.size = unit(3, "mm"),
    legend.text = element_text(size = 6),
    legend.title = element_text(size = 6),
    legend.margin = margin(0, 0, 0, 0),
    axis.text.y = element_text(size = 6),
    axis.text.x = element_text(size = 7),
    plot.margin = margin(5, 8, 5, 5, "mm")
  )

# --- Assemble S10 ---
# Layout: (a | b) on top row, (c) spanning full width on bottom row.
# Collect guides so the Field/Laboratory (from panel b) and Effect-size
# (from panel c) legends are pooled at the bottom of the full figure
# rather than appearing twice under individual panels.
fig_s10 <- (p_s10a | p_s10b) / p_s10c +
  plot_layout(heights = c(1, 0.7), guides = "collect") +
  plot_annotation(tag_levels = "a") &
  theme(
    plot.tag = element_text(size = 10, face = "bold"),
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.margin = margin(0, 0, 0, 0)
  )

save_manuscript_fig(fig_s10, "FigS10_context_comparison",
                    width_mm = 174, height_mm = 140,
                    fig_dir = supp_dir)

cat("  Figure S10 assembled and saved.\n")

# ==============================================================================
# FIGURE S11: CLIMATE-DEMOGRAPHY (4 PANELS)
# ==============================================================================

print_subheader("Building Figure S11: Climate-demography")

# --- Panel (a): Temporal survival trend ---

# Extract GLMM slope for trend line
glmm_row <- trend_glmm %>% filter(term == "survey_yr")
glmm_intercept <- trend_glmm$estimate_logodds[trend_glmm$term == "(Intercept)"]
glmm_slope     <- glmm_row$estimate_logodds

# Create prediction line on probability scale
yr_range <- range(yearly_survival$survey_yr)
pred_yrs <- seq(yr_range[1], yr_range[2], by = 0.5)
pred_logodds <- glmm_intercept + glmm_slope * pred_yrs
pred_prob <- plogis(pred_logodds)
trend_line <- data.frame(survey_yr = pred_yrs, predicted = pred_prob)

p_s11a <- ggplot(yearly_survival, aes(x = survey_yr, y = survival_rate)) +
  geom_hline(yintercept = mean(yearly_survival$survival_rate),
             linetype = "dotted", color = "grey60", linewidth = 0.3) +
  geom_line(data = trend_line, aes(x = survey_yr, y = predicted),
            color = MANUSCRIPT_PALETTE$accent, linewidth = 0.7,
            linetype = "dashed") +
  geom_errorbar(
    aes(ymin = pmax(0, survival_rate - 1.96 * se),
        ymax = pmin(1, survival_rate + 1.96 * se)),
    width = 0.3, linewidth = 0.3, color = "grey50"
  ) +
  geom_point(aes(size = n), color = MANUSCRIPT_PALETTE$surv_mid,
             alpha = 0.85) +
  scale_y_continuous(
    limits = c(0.35, 1.05),
    breaks = seq(0.4, 1.0, 0.2),
    labels = scales::percent_format(accuracy = 1)
  ) +
  scale_x_continuous(breaks = seq(2005, 2025, 5)) +
  scale_size_continuous(
    range = c(1, 4),
    name = "n obs.",
    breaks = c(100, 300, 600, 900)
  ) +
  labs(x = "Year", y = "Annual survival probability") +
  theme_manuscript(base_size = 9) +
  theme(
    legend.position = "right",
    legend.key.size = unit(3, "mm"),
    legend.text = element_text(size = 7),
    legend.title = element_text(size = 7),
    legend.margin = margin(0, 0, 0, 0),
    plot.margin = margin(5, 8, 5, 5, "mm")
  )

# --- Panel (b): Disturbance effects ---

disturbance_df <- disturbance_df %>%
  mutate(
    dist_label = case_when(
      disturbance_cat == "None recorded" ~ "No\ndisturbance",
      TRUE ~ stringr::str_wrap(disturbance_cat, width = 10)
    ),
    dist_label = factor(dist_label, levels = dist_label)
  )

# Color: baseline vs disturbance
dist_colors <- c(MANUSCRIPT_PALETTE$surv_mid, MANUSCRIPT_PALETTE$accent)
if (nrow(disturbance_df) > 2) {
  dist_colors <- c(dist_colors,
                   rep(MANUSCRIPT_PALETTE$slate_mid, nrow(disturbance_df) - 2))
}

p_s11b <- ggplot(disturbance_df,
                  aes(x = dist_label, y = survival_rate)) +
  geom_col(fill = dist_colors, width = 0.55) +
  geom_errorbar(
    aes(ymin = pmax(0, ci_lower), ymax = pmin(1, ci_upper)),
    width = 0.15, linewidth = 0.4
  ) +
  # Place n/k labels ABOVE the error-bar caps so they are never
  # clipped by the plotting area.
  geom_text(aes(y = pmin(1, ci_upper) + 0.04,
                label = paste0("n = ", format(n, big.mark = ","))),
            size = 2.4, color = "grey25", fontface = "bold") +
  geom_text(aes(y = pmin(1, ci_upper) + 0.10,
                label = paste0("k = ", n_studies)),
            size = 2.3, color = "grey40") +
  scale_y_continuous(
    limits = c(0, 1.18),
    breaks = seq(0, 1, 0.2),
    labels = scales::percent_format(accuracy = 1),
    expand = expansion(mult = c(0, 0.02))
  ) +
  labs(x = "Disturbance category", y = "Annual survival probability") +
  theme_manuscript(base_size = 9) +
  theme(
    axis.text.x = element_text(size = 7, lineheight = 0.9),
    plot.margin = margin(5, 5, 5, 5, "mm")
  )

# --- Panel (c): Climate vulnerability by size class (CV) ---

size_climate_vuln <- size_climate_vuln %>%
  mutate(size_class = factor(size_class, levels = SIZE_LABELS))

mean_cv <- mean(size_climate_vuln$cv_survival, na.rm = TRUE)

# Place n-year labels above the TALLER of (bar top, mean-CV reference line)
# so they never sit on top of the red dashed line. Also annotate the
# reference line directly so the reader knows what it represents.
cv_max    <- max(size_climate_vuln$cv_survival, na.rm = TRUE)
cv_offset <- cv_max * 0.05

# Give every n-label enough vertical headroom above BOTH its own bar and
# the mean-CV line; ensures SC3-SC5 labels (below the line) don't sit on
# the red dashed reference. Label the reference line at the far left, well
# clear of the size-class bars.
size_climate_vuln <- size_climate_vuln %>%
  mutate(label_y = pmax(cv_survival, mean_cv) + cv_offset * 2)

p_s11c <- ggplot(size_climate_vuln,
                  aes(x = size_class, y = cv_survival)) +
  geom_col(aes(fill = size_class), width = 0.6, show.legend = FALSE) +
  geom_hline(yintercept = mean_cv, linetype = "dashed",
             color = MANUSCRIPT_PALETTE$accent, linewidth = 0.4) +
  geom_text(aes(y = label_y,
                label = paste0("n = ", n_years, " yr")),
            size = 2.3, color = "grey30") +
  annotate("text",
           x = 0.55,
           y = mean_cv,
           label = "mean",
           hjust = 0, vjust = -0.5,
           size = 2.3, color = MANUSCRIPT_PALETTE$accent,
           fontface = "italic") +
  scale_y_continuous(
    limits = c(0, cv_max * 1.35),
    expand = expansion(mult = c(0, 0.02))
  ) +
  scale_fill_manual(values = SIZE_CLASS_COLORS) +
  labs(x = "Size class", y = "CV of annual survival") +
  coord_cartesian(clip = "off") +
  theme_manuscript(base_size = 9) +
  theme(plot.margin = margin(5, 5, 5, 5, "mm"))

# --- Panel (d): Regional temporal variability ---

regional_var <- regional_var %>%
  arrange(cv_survival) %>%
  mutate(
    region = factor(region, levels = region),
    region_wrap = stringr::str_wrap(region, width = 12)
  )

reg_max <- max(regional_var$cv_survival, na.rm = TRUE)

p_s11d <- ggplot(regional_var,
                  aes(x = reorder(region_wrap, cv_survival), y = cv_survival)) +
  geom_col(fill = MANUSCRIPT_PALETTE$surv_mid, width = 0.55) +
  geom_text(aes(label = paste0("n = ", n_years, " yr")),
            hjust = -0.15, size = 2.3, color = "grey40") +
  coord_flip(clip = "off", ylim = c(0, reg_max * 1.18)) +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0))
  ) +
  labs(x = NULL, y = "CV of annual survival") +
  theme_manuscript(base_size = 9) +
  theme(
    axis.text.y = element_text(size = 8),
    plot.margin = margin(5, 5, 5, 5, "mm")
  )

# --- Assemble S11 (2x2 grid) ---

fig_s11 <- (p_s11a | p_s11b) / (p_s11c | p_s11d) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 10, face = "bold"))

save_manuscript_fig(fig_s11, "FigS11_climate_demography",
                    width_mm = 174, height_mm = 170,
                    fig_dir = supp_dir)

cat("  Figure S11 assembled and saved.\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n")
cat("================================================================\n")
cat("  SUPPLEMENTARY FIGURES S10 & S11 COMPLETE\n")
cat("================================================================\n\n")
cat("Outputs:\n")
cat(sprintf("  - %s/FigS10_context_comparison.png  (174 x 140 mm)\n", supp_dir))
cat(sprintf("  - %s/FigS10_context_comparison.pdf\n", supp_dir))
cat(sprintf("  - %s/FigS11_climate_demography.png  (174 x 170 mm)\n", supp_dir))
cat(sprintf("  - %s/FigS11_climate_demography.pdf\n", supp_dir))
cat("\nS10 panels: (a) survival by context, (b) context x size, (c) effect sizes\n")
cat("S11 panels: (a) temporal trend, (b) disturbance, (c) size vulnerability, (d) regional CV\n")
