#!/usr/bin/env Rscript
# =============================================================================
# FIGURE S8: STUDY-LEVEL COMPARISON WITHIN SHARED SIZE RANGE (Supplementary)
# =============================================================================
#
# PURPOSE: Generate supplementary Figure S8 comparing size-dependent survival
#          and growth across individual studies within the shared size range.
#
# NOTE: Script filename retains historical "fig3" label; actual output is FigS8_natural_vs_restoration.
#
# Zoomed to the overlap zone (~11-202 cm^2) where both natural colonies and
# restoration fragments have data. Per-study colors (6 Okabe-Ito) make study
# identity the primary visual channel; shape/linetype encode population type
# as a secondary channel. This prevents readers from interpreting the figure
# as a clean natural-vs-restoration comparison when study identity is
# perfectly confounded with population type.
#
# 12-panel small multiples: 6 studies x 2 metrics (survival + RGR).
# Row a: Size-dependent survival (logistic regression per study)
# Row b: Size-dependent RGR (linear regression per study)
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds (individual survival data)
#   - 06_analysis/output/prepared_growth_data.rds (individual growth data)
#
# OUTPUT: 06_analysis/figures/supplementary/FigS8_natural_vs_restoration.{png,pdf}
#         174 x 140 mm, 300 DPI (Coral Reefs double-column)
#
# Author: Detmer & Stier Lab
# Date: 2026-02
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(patchwork)
  library(scales)
  library(mgcv)
})

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

cat("\n")
cat("==============================================================\n")
cat("  FIGURE S8: Study-Level Comparison (Shared Size Range) [Supplementary]\n")
cat("==============================================================\n\n")

# =============================================================================
# LOAD DATA
# =============================================================================

project_root <- get_project_root()
surv_data <- readRDS(file.path(project_root, "06_analysis/output/prepared_survival_data.rds")) %>%
  filter(!is.na(size_cm2), size_cm2 > 0, !is.na(survived))

# Harmonize population type
if ("population_type" %in% names(surv_data)) {
  cat("  Using 'population_type' column\n")
} else if ("fragment" %in% names(surv_data)) {
  surv_data <- surv_data %>%
    mutate(population_type = ifelse(fragment == "N",
                                     "Natural colony",
                                     "Restoration fragment"))
}

# Remove NOAA "fragments" — naturally broken colonies, not outplants
# (59 of 73 unique NOAA fragment IDs also appear as natural colonies)
noaa_frags_n <- sum(surv_data$study == "NOAA_survey" &
                     surv_data$population_type == "Restoration fragment", na.rm = TRUE)
cat(sprintf("  Removing %d NOAA 'fragment' records\n", noaa_frags_n))
surv_data <- surv_data %>%
  filter(!(study == "NOAA_survey" & population_type == "Restoration fragment"))

surv_data <- surv_data %>%
  mutate(log_size = log10(size_cm2))

cat(sprintf("  Survival records (full): %s\n", comma(nrow(surv_data))))

# --- Growth data ---
growth_data <- readRDS(file.path(project_root, "06_analysis/output/prepared_growth_data.rds")) %>%
  filter(!is.na(size_cm2), size_cm2 > 0)

if ("population_type" %in% names(growth_data)) {
  # already present
} else if ("fragment" %in% names(growth_data)) {
  growth_data <- growth_data %>%
    mutate(population_type = ifelse(fragment == "N",
                                     "Natural colony",
                                     "Restoration fragment"))
}

noaa_frags_growth <- sum(growth_data$study == "NOAA_survey" &
                          growth_data$population_type == "Restoration fragment", na.rm = TRUE)
cat(sprintf("  Removing %d NOAA growth 'fragment' records\n", noaa_frags_growth))
growth_data <- growth_data %>%
  filter(!(study == "NOAA_survey" & population_type == "Restoration fragment"))

if (!"rgr" %in% names(growth_data) || all(is.na(growth_data$rgr))) {
  growth_data <- growth_data %>%
    mutate(rgr = growth_cm2_yr / size_cm2)
}

growth_data <- growth_data %>%
  filter(!is.na(rgr), is.finite(rgr), !is.na(population_type))
if ("impossible_growth" %in% names(growth_data)) {
  growth_data <- growth_data %>% filter(!impossible_growth)
}
rgr_bounds <- quantile(growth_data$rgr, c(0.005, 0.995), na.rm = TRUE)
growth_data <- growth_data %>%
  filter(rgr >= rgr_bounds[1], rgr <= rgr_bounds[2])

growth_data <- growth_data %>%
  mutate(log_size = log10(size_cm2))

cat(sprintf("  Growth records (full, cleaned): %s\n", comma(nrow(growth_data))))

# Clean study names
study_names <- c(
  "NOAA_survey"                = "NOAA NCRMP",
  "mendoza_quiroz_et_al_2023"  = "Mend.-Quiroz",
  "pausch_et_al_2018"          = "Pausch",
  "kuffner_et_al_2020"         = "Kuffner",
  "USGS_USVI_exp"              = "USGS USVI",
  "fundemar_fragments"         = "FUNDEMAR"
)

surv_data <- surv_data %>%
  mutate(study_label = recode(study, !!!study_names))
growth_data <- growth_data %>%
  mutate(study_label = recode(study, !!!study_names))

# =============================================================================
# COMPUTE OVERLAP ZONE & FILTER
# =============================================================================

natural_range <- surv_data %>%
  filter(population_type == "Natural colony") %>%
  summarise(lo = quantile(log_size, 0.01), hi = quantile(log_size, 0.99))
restoration_range <- surv_data %>%
  filter(population_type == "Restoration fragment") %>%
  summarise(lo = quantile(log_size, 0.01), hi = quantile(log_size, 0.99))

overlap_lo <- max(natural_range$lo, restoration_range$lo)
overlap_hi <- min(natural_range$hi, restoration_range$hi)

cat(sprintf("\n  Overlap zone: %.0f - %.0f cm2 (log10: %.2f - %.2f)\n",
            10^overlap_lo, 10^overlap_hi, overlap_lo, overlap_hi))

# Add small buffer for display (10% on each side)
buffer <- 0.10 * (overlap_hi - overlap_lo)
display_lo <- overlap_lo - buffer
display_hi <- overlap_hi + buffer

cat(sprintf("  Display range: %.0f - %.0f cm2 (log10: %.2f - %.2f)\n",
            10^display_lo, 10^display_hi, display_lo, display_hi))

# Filter data to overlap zone (with buffer)
surv_overlap <- surv_data %>%
  filter(log_size >= display_lo, log_size <= display_hi)
growth_overlap <- growth_data %>%
  filter(log_size >= display_lo, log_size <= display_hi)

cat(sprintf("  Survival in overlap zone: %s\n", comma(nrow(surv_overlap))))
cat(sprintf("  Growth in overlap zone: %s\n", comma(nrow(growth_overlap))))

# =============================================================================
# PER-STUDY COLORS (Okabe-Ito, colorblind-safe)
# =============================================================================

# Cool tones = natural studies, warm tones = restoration studies
study_colors <- c(
  "NOAA NCRMP"   = "#0072B2",  # Okabe-Ito blue
  "Mend.-Quiroz" = "#56B4E9",  # Okabe-Ito sky blue
  "Pausch"       = "#D55E00",  # Okabe-Ito vermillion
  "FUNDEMAR"     = "#E69F00",  # Okabe-Ito amber
  "Kuffner"      = "#CC79A7",  # Okabe-Ito reddish purple
  "USGS USVI"    = "#009E73"   # Okabe-Ito bluish green
)

type_shapes <- c("Natural colony" = 16, "Restoration fragment" = 17)
type_lines  <- c("Natural colony" = "solid", "Restoration fragment" = "dashed")

# Study ordering: natural first, then restoration
study_order <- c("NOAA NCRMP", "Mend.-Quiroz",
                 "Pausch", "FUNDEMAR", "Kuffner", "USGS USVI")

surv_overlap <- surv_overlap %>%
  mutate(study_label = factor(study_label, levels = study_order))
growth_overlap <- growth_overlap %>%
  mutate(study_label = factor(study_label, levels = study_order))

# =============================================================================
# PANEL A: SURVIVAL — Logistic regression per study (overlap zone)
# =============================================================================

cat("\nPanel a: Fitting study-level logistic regressions (overlap zone)...\n")

surv_overlap_summary <- surv_overlap %>%
  group_by(study_label, population_type) %>%
  summarise(n = n(), surv = mean(survived), .groups = "drop")

# Logistic regression for ALL studies
# Handle degenerate case where all individuals survived (e.g., Mendoza-Quiroz)
surv_preds <- surv_overlap %>%
  group_by(study_label, population_type) %>%
  group_modify(function(df, grp) {
    newdata <- tibble(log_size = seq(min(df$log_size), max(df$log_size),
                                     length.out = 60))
    # Check for perfect separation (all survived or all died)
    if (length(unique(df$survived)) == 1) {
      flat_val <- unique(df$survived)
      newdata$surv_pred <- flat_val
      newdata$ci_lower  <- flat_val
      newdata$ci_upper  <- flat_val
      return(newdata)
    }
    fit <- glm(survived ~ log_size, family = binomial, data = df)
    pred <- predict(fit, newdata = newdata, type = "link", se.fit = TRUE)
    newdata$surv_pred <- plogis(pred$fit)
    newdata$ci_lower  <- plogis(pred$fit - 1.96 * pred$se.fit)
    newdata$ci_upper  <- plogis(pred$fit + 1.96 * pred$se.fit)
    newdata
  }) %>%
  ungroup()

# Print all study summaries
surv_overlap_summary %>%
  arrange(population_type, study_label) %>%
  {for (i in seq_len(nrow(.))) {
    cat(sprintf("  %s | %s: %.1f%% survival (n=%d in overlap)\n",
                .$study_label[i], .$population_type[i],
                .$surv[i] * 100, .$n[i]))
  }}

# X-axis config (overlap zone)
x_breaks <- log10(c(10, 50, 200))
x_labels <- c("10", "50", "200")

# =============================================================================
# BUILD 12-PANEL FIGURE (6 studies x 2 metrics)
# =============================================================================

cat("\nBuilding 12-panel figure (small multiples)...\n")

# Ensure consistent factor levels on all prediction/summary datasets
surv_preds <- surv_preds %>%
  mutate(study_label = factor(study_label, levels = study_order))

# In-panel annotation: population type + n
# For studies with 100% survival, add note
surv_annot <- surv_overlap_summary %>%
  mutate(
    type_short = ifelse(population_type == "Natural colony", "Natural", "Restoration"),
    annot_text = ifelse(surv == 1.0,
                        sprintf("%s\nn = %s\n100%% survival", type_short, comma(n)),
                        sprintf("%s\nn = %s", type_short, comma(n))),
    study_label = factor(study_label, levels = study_order)
  )

# ── ROW 1: SURVIVAL (6 facets) ──────────────────────────────────────────────

surv_row <- ggplot() +
  # Individual survival observations (jittered at 0/1)
  geom_point(data = surv_overlap,
             aes(x = log_size, y = survived, color = study_label),
             position = position_jitter(width = 0, height = 0.03),
             alpha = 0.06, size = 0.2, show.legend = FALSE) +
  # Logistic regression CI ribbons (all studies)
  geom_ribbon(data = surv_preds,
              aes(x = log_size, ymin = ci_lower, ymax = ci_upper,
                  fill = study_label),
              alpha = 0.22, show.legend = FALSE) +
  # Logistic regression curves (all studies)
  geom_line(data = surv_preds,
            aes(x = log_size, y = surv_pred, color = study_label),
            linewidth = 1.0, show.legend = FALSE) +
  # Type + n annotation (bottom-right of each panel)
  geom_text(data = surv_annot,
            aes(label = annot_text),
            x = display_hi - 0.02, y = 0.12,
            hjust = 1, vjust = 0, size = 2.5,
            color = "grey40", family = "Helvetica") +
  facet_wrap(~study_label, nrow = 1) +
  scale_color_manual(values = study_colors) +
  scale_fill_manual(values = study_colors) +
  scale_x_continuous(
    breaks = x_breaks, labels = x_labels,
    limits = c(display_lo, display_hi), expand = c(0.02, 0)
  ) +
  scale_y_continuous(
    breaks = seq(0, 1.0, 0.25),
    labels = function(x) sprintf("%.0f%%", x * 100)
  ) +
  coord_cartesian(ylim = c(-0.08, 1.08)) +
  labs(x = NULL, y = "Annual survival", tag = "a") +
  theme_manuscript() +
  theme(
    text         = element_text(family = "Helvetica"),
    axis.title.y = element_text(size = 9),
    axis.text.y  = element_text(size = 7, color = "grey30"),
    axis.text.x  = element_blank(),
    axis.ticks.x = element_blank(),
    strip.text   = element_text(size = 8, face = "bold", family = "Helvetica"),
    strip.background = element_rect(fill = "grey96", color = NA),
    panel.spacing.x  = unit(1.5, "mm"),
    panel.grid.major.y = element_line(color = "grey92", linewidth = 0.25),
    plot.margin  = margin(4, 4, 0, 4, "mm")
  )

cat("  Survival row complete.\n")

# =============================================================================
# PANEL B: RGR — Linear regression per study (overlap zone)
# =============================================================================

cat("\nPanel b: Fitting study-level linear regressions for RGR (overlap zone)...\n")

growth_overlap_summary <- growth_overlap %>%
  group_by(study_label, population_type) %>%
  summarise(n = n(), med_rgr = median(rgr), .groups = "drop")

# Linear regression for ALL studies
growth_preds <- growth_overlap %>%
  group_by(study_label, population_type) %>%
  group_modify(function(df, grp) {
    newdata <- tibble(log_size = seq(min(df$log_size), max(df$log_size),
                                     length.out = 60))
    fit <- lm(rgr ~ log_size, data = df)
    pred <- predict(fit, newdata = newdata, se.fit = TRUE)
    newdata$rgr_pred <- pred$fit
    newdata$ci_lower <- pred$fit - 1.96 * pred$se.fit
    newdata$ci_upper <- pred$fit + 1.96 * pred$se.fit
    newdata
  }) %>%
  ungroup()

growth_overlap_summary %>%
  arrange(population_type, study_label) %>%
  {for (i in seq_len(nrow(.))) {
    cat(sprintf("  %s | %s: median RGR=%.2f (n=%d in overlap)\n",
                .$study_label[i], .$population_type[i],
                .$med_rgr[i], .$n[i]))
  }}

# Ensure consistent factor levels on growth datasets
growth_preds <- growth_preds %>%
  mutate(study_label = factor(study_label, levels = study_order))
growth_overlap <- growth_overlap %>%
  mutate(study_label = factor(study_label, levels = study_order))

growth_annot <- growth_overlap_summary %>%
  mutate(
    type_short = ifelse(population_type == "Natural colony", "Natural", "Restoration"),
    annot_text = sprintf("%s\nn = %s", type_short, comma(n)),
    study_label = factor(study_label, levels = study_order)
  )

# ── ROW 2: RGR (6 facets) ───────────────────────────────────────────────────

rgr_row <- ggplot() +
  # Zero reference
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey60",
             linewidth = 0.3) +
  # Scatter (all studies — each auto-routed to its facet)
  geom_point(data = growth_overlap,
             aes(x = log_size, y = rgr, color = study_label),
             alpha = 0.12, size = 0.25, show.legend = FALSE) +
  # Linear regression CI ribbons (all studies)
  geom_ribbon(data = growth_preds,
              aes(x = log_size, ymin = ci_lower, ymax = ci_upper,
                  fill = study_label),
              alpha = 0.22, show.legend = FALSE) +
  # Linear regression lines (all studies)
  geom_line(data = growth_preds,
            aes(x = log_size, y = rgr_pred, color = study_label),
            linewidth = 1.0, show.legend = FALSE) +
  # n annotation (top-left)
  geom_text(data = growth_annot,
            aes(label = annot_text),
            x = display_lo + 0.02, y = 2.9,
            hjust = 0, vjust = 1, size = 2.5,
            color = "grey40", family = "Helvetica") +
  facet_wrap(~study_label, nrow = 1) +
  scale_color_manual(values = study_colors) +
  scale_fill_manual(values = study_colors) +
  scale_x_continuous(
    breaks = x_breaks, labels = x_labels,
    limits = c(display_lo, display_hi), expand = c(0.02, 0)
  ) +
  coord_cartesian(ylim = c(-0.5, 3.0)) +
  labs(x = expression(paste("Colony live tissue area (cm"^2, ")")),
       y = expression(paste("RGR (yr"^-1, ")")),
       tag = "b") +
  theme_manuscript() +
  theme(
    text         = element_text(family = "Helvetica"),
    axis.title   = element_text(size = 9),
    axis.text    = element_text(size = 7, color = "grey30"),
    strip.text   = element_blank(),
    panel.spacing.x  = unit(1.5, "mm"),
    panel.grid.major.y = element_line(color = "grey92", linewidth = 0.25),
    plot.margin  = margin(2, 4, 4, 4, "mm")
  )

cat("  RGR row complete.\n")

# =============================================================================
# COMBINE: 2 x 6 grid (survival row + RGR row)
# =============================================================================

cat("\nCombining 12-panel figure...\n")

fig3 <- surv_row / rgr_row +
  plot_layout(heights = c(1, 1)) +
  plot_annotation(
    caption = "Study identity confounded with population type. Shared size range: 11\u2013202 cm\u00B2 of ~1\u201315,000 cm\u00B2.",
    theme = theme(
      plot.caption = element_text(size = 8, color = "grey40", hjust = 0.5,
                                   face = "italic", family = "Helvetica")
    )
  )

supp_dir <- file.path(get_project_root(), "06_analysis/figures/supplementary")
dir.create(supp_dir, showWarnings = FALSE, recursive = TRUE)
save_manuscript_fig(fig3, "FigS8_natural_vs_restoration", 174, 140, fig_dir = supp_dir)

cat("\nDone: Figure S8 — 12-Panel Study-Level Comparison (Supplementary)\n")
