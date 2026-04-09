#!/usr/bin/env Rscript
# =============================================================================
# FIGURE 2: SIZE-DEPENDENT VITAL RATES (3-panel: a / b / c)
# =============================================================================
# Panel a: Survival probability vs colony size (GAM smooth, binned proportions)
# Panel b: Relative growth rate vs colony size (GAM smooth, Detmer threshold)
# Panel c: Size-class survival synthesis across 15 studies
#
# Both panels: natural colonies only, shared log10 x-axis (1-15,000 cm²),
#   GAM (k=4, REML), 25-bin overlays, rug marks / scatter cloud.
#
# OUTPUT: 06_analysis/figures/manuscript/Fig2_demographic_rates.{png,pdf}
#         174 x 220 mm (double-column, vertical stack), 300 DPI
#
# Author: Detmer & Stier Lab
# Date: 2026-02
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(mgcv)
  library(patchwork)
  library(scales)
})

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

pal <- MANUSCRIPT_PALETTE
project_root <- get_project_root()
output_dir <- file.path(project_root, "06_analysis/output")

require_output <- function(path) {
  if (!file.exists(path)) stop("Required file not found: ", path)
  path
}

survival_models <- readRDS(require_output(file.path(output_dir, "survival_threshold_models.rds")))
growth_models <- readRDS(require_output(file.path(output_dir, "growth_threshold_models.rds")))

if (!inherits(survival_models$gam_model, "gam")) {
  stop("survival_threshold_models.rds is missing canonical gam_model")
}
if (!inherits(growth_models$model_gam_rgr, "gam")) {
  stop("growth_threshold_models.rds is missing canonical model_gam_rgr")
}

cat("\n")
cat("================================================================\n")
cat("  FIGURE 2: Size-Dependent Vital Rates (a|b|c)\n")
cat("================================================================\n\n")

# =============================================================================
# PANEL A: SURVIVAL PROBABILITY
# =============================================================================

cat("Panel a: Survival probability...\n")

surv_all <- readRDS(require_output(file.path(output_dir, "prepared_survival_data.rds")))

# Harmonize population type column
if (!"population_type" %in% names(surv_all) && "source_type" %in% names(surv_all)) {
  surv_all <- surv_all %>% rename(population_type = source_type)
}

# Filter to natural corals
if ("population_type" %in% names(surv_all)) {
  surv_nat <- surv_all %>% filter(population_type == "Natural colony")
} else if ("fragment" %in% names(surv_all)) {
  surv_nat <- surv_all %>% filter(fragment == "N")
} else {
  stop("Cannot identify natural corals")
}

surv_nat <- surv_nat %>%
  filter(!is.na(size_class), !is.na(survived)) %>%
  mutate(log_size = log(size_cm2))

cat(sprintf("  Natural survival records: %s\n", comma(nrow(surv_nat))))

surv_gam <- survival_models$gam_model
surv_r2 <- summary(surv_gam)$r.sq
cat(sprintf("  Survival GAM R² = %.1f%%\n", surv_r2 * 100))

surv_pred <- survival_models$prediction_grid %>%
  as_tibble() %>%
  transmute(
    log_size = log_size,
    size_cm2 = size_cm2,
    fit = gam,
    ci_lower = gam_lower,
    ci_upper = gam_upper
  ) %>%
  filter(size_cm2 >= 1, size_cm2 <= 15000)

# Binned proportions
surv_binned <- surv_nat %>%
  mutate(log_size_bin = cut(log_size, breaks = 25)) %>%
  group_by(log_size_bin) %>%
  summarise(
    mean_log_size = mean(log_size, na.rm = TRUE),
    surv_prop     = mean(survived, na.rm = TRUE),
    n             = n(),
    .groups       = "drop"
  ) %>%
  filter(n >= 5) %>%
  mutate(size_cm2 = exp(mean_log_size))

# Rug data
rug_survived <- surv_nat %>% filter(survived == 1)
rug_died     <- surv_nat %>% filter(survived == 0)

# Build panel a
fig2a <- ggplot() +
  geom_ribbon(data = surv_pred,
              aes(x = size_cm2, ymin = ci_lower, ymax = ci_upper),
              fill = pal$surv_light, alpha = 0.3) +
  geom_line(data = surv_pred,
            aes(x = size_cm2, y = fit),
            color = pal$surv_mid, linewidth = 1.3) +
  geom_point(data = surv_binned,
             aes(x = size_cm2, y = surv_prop),
             fill = pal$surv_mid, color = "white",
             shape = 21, size = 2.5, stroke = 0.4) +
  geom_rug(data = rug_survived,
           aes(x = size_cm2), sides = "t",
           alpha = 0.05, linewidth = 0.4,
           length = unit(0.02, "npc"), color = pal$surv_mid) +
  geom_rug(data = rug_died,
           aes(x = size_cm2), sides = "b",
           alpha = 0.05, linewidth = 0.4,
           length = unit(0.02, "npc"), color = pal$accent) +
  scale_x_log10(
    breaks = c(1, 10, 100, 1000, 10000),
    labels = comma,
    limits = c(1, 15000)
  ) +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2),
    labels = function(x) sprintf("%.0f%%", x * 100)
  ) +
  labs(
    x = NULL,
    y = "Survival probability",
    tag = "a"
  ) +
  annotate("text", x = 1.5, y = 0.95,
           label = sprintf("R\u00B2 = %.1f%%", surv_r2 * 100),
           hjust = 0, size = 2.5, color = "grey50") +
  theme_manuscript() +
  theme(
    text         = element_text(family = "Helvetica"),
    axis.title   = element_text(size = 10, family = "Helvetica"),
    axis.text    = element_text(size = 9, family = "Helvetica", color = "grey30"),
    axis.text.x  = element_blank(),
    axis.ticks.x = element_blank(),
    plot.margin  = margin(6, 8, 2, 6, "mm")
  )

cat("  Panel a complete.\n")

# =============================================================================
# PANEL B: RELATIVE GROWTH RATE
# =============================================================================

cat("Panel b: Relative growth rate...\n")

growth_data <- readRDS(require_output(file.path(output_dir, "prepared_growth_data.rds")))

# Filter to natural corals
if ("population_type" %in% names(growth_data)) {
  growth_natural <- growth_data %>% filter(population_type == "Natural colony")
} else if ("fragment" %in% names(growth_data)) {
  growth_natural <- growth_data %>% filter(fragment == "N")
} else {
  growth_natural <- growth_data
}

# Clean and compute RGR
growth_clean <- growth_natural %>%
  filter(!is.na(size_cm2), size_cm2 > 0, !is.na(growth_cm2_yr)) %>%
  mutate(
    rgr = growth_cm2_yr / size_cm2,
    log_size = log(size_cm2)
  )

# Remove impossible growth
if ("impossible_growth" %in% names(growth_clean)) {
  growth_clean <- growth_clean %>% filter(!impossible_growth)
} else {
  growth_clean <- growth_clean %>%
    filter(!((growth_cm2_yr < 0) & (abs(growth_cm2_yr) > size_cm2 * 1.1)))
}

# Trim top/bottom 0.5% RGR outliers
rgr_bounds <- quantile(growth_clean$rgr, c(0.005, 0.995), na.rm = TRUE)
growth_rgr <- growth_clean %>%
  filter(rgr >= rgr_bounds[1], rgr <= rgr_bounds[2], is.finite(rgr))

cat(sprintf("  Natural growth records: %s\n", comma(nrow(growth_rgr))))

rgr_gam <- growth_models$model_gam_rgr
rgr_r2 <- summary(rgr_gam)$r.sq
cat(sprintf("  RGR GAM R² = %.1f%%\n", rgr_r2 * 100))

rgr_pred <- growth_models$prediction_grid %>%
  as_tibble() %>%
  transmute(log_size = log_size, size_cm2 = size_cm2, fit = gam_rgr) %>%
  filter(size_cm2 >= 1, size_cm2 <= 15000)
rgr_se <- predict(rgr_gam, newdata = rgr_pred %>% select(log_size), se.fit = TRUE)
rgr_pred <- rgr_pred %>%
  mutate(
    ci_lower = fit - 1.96 * rgr_se$se.fit,
    ci_upper = fit + 1.96 * rgr_se$se.fit
  )

# Binned medians
rgr_binned <- growth_rgr %>%
  mutate(size_bin = cut(log_size, breaks = 25)) %>%
  group_by(size_bin) %>%
  summarise(
    size_cm2 = exp(mean(log_size)),
    median_rgr = median(rgr, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  filter(!is.na(size_cm2), n >= 5)

# Y-axis range
rgr_y_lower <- max(-1.5, quantile(growth_rgr$rgr, 0.005, na.rm = TRUE))
rgr_y_upper <- min(3.5, quantile(growth_rgr$rgr, 0.995, na.rm = TRUE))

thresh_cm2 <- NA
rgr_row <- growth_models$thresholds %>%
  as_tibble() %>%
  filter(response == "relative_growth_rate")
if (nrow(rgr_row) == 1 && isTRUE(rgr_row$gate_passed[[1]])) {
  thresh_cm2 <- rgr_row$recommended_threshold_cm2[[1]]
  ci_lo_cm2  <- rgr_row$cluster_boot_ci_lower[[1]]
  ci_hi_cm2  <- rgr_row$cluster_boot_ci_upper[[1]]
  if (is.na(thresh_cm2) && !is.na(ci_lo_cm2)) {
    thresh_cm2 <- ci_lo_cm2
    cat(sprintf("  RGR threshold (from CI lower): %.1f cm² (95%% CI: %.1f-%.1f)\n",
                thresh_cm2, ci_lo_cm2, ci_hi_cm2))
  } else {
    cat(sprintf("  RGR threshold: %.1f cm² (95%% CI: %.1f-%.1f)\n",
                thresh_cm2, ci_lo_cm2, ci_hi_cm2))
  }
}

# Build panel b
fig2b <- ggplot() +
  # Threshold CI band
  { if (!is.na(thresh_cm2))
    annotate("rect",
             xmin = ci_lo_cm2, xmax = ci_hi_cm2,
             ymin = -Inf, ymax = Inf,
             fill = "#D55E00", alpha = 0.08) } +
  # Threshold point estimate
  { if (!is.na(thresh_cm2))
    geom_vline(xintercept = thresh_cm2,
               linetype = "dashed", color = "#D55E00", linewidth = 0.7) } +
  # Scatter cloud
  geom_point(data = growth_rgr,
             aes(x = size_cm2, y = rgr),
             color = pal$slate_light, alpha = 0.05, size = 0.8) +
  # Zero reference line
  geom_hline(yintercept = 0, linetype = "dotted",
             color = pal$slate_light, linewidth = 0.4) +
  # CI ribbon
  geom_ribbon(data = rgr_pred,
              aes(x = size_cm2, ymin = ci_lower, ymax = ci_upper),
              fill = pal$grow_light, alpha = 0.3) +
  # GAM line
  geom_line(data = rgr_pred, aes(x = size_cm2, y = fit),
            color = pal$grow_mid, linewidth = 1.3) +
  # Binned medians
  geom_point(data = rgr_binned,
             aes(x = size_cm2, y = median_rgr),
             fill = "#E69F00", color = "white", size = 2.5,
             shape = 21, stroke = 0.4, alpha = 0.85) +
  scale_x_log10(
    breaks = c(1, 10, 100, 1000, 10000),
    labels = comma, limits = c(1, 15000)
  ) +
  coord_cartesian(ylim = c(rgr_y_lower, rgr_y_upper)) +
  annotate("text", x = 1.5, y = rgr_y_upper * 0.92,
           label = sprintf("R\u00B2 = %.1f%%", rgr_r2 * 100),
           hjust = 0, size = 2.5, color = "grey50") +
  labs(x = expression("Colony size (cm"^2*")"),
       y = expression("Relative growth rate (yr"^-1*")"),
       tag = "b") +
  theme_manuscript() +
  theme(
    text         = element_text(family = "Helvetica"),
    axis.title   = element_text(size = 10, family = "Helvetica"),
    axis.text    = element_text(size = 9, family = "Helvetica", color = "grey30"),
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    plot.margin  = margin(6, 8, 4, 6, "mm")
  )

cat("  Panel b complete.\n")

# =============================================================================
# PANEL C: SIZE-CLASS SURVIVAL SYNTHESIS (from script 20 data)
# =============================================================================

cat("Panel c: Size-class survival synthesis...\n")

# Read pre-computed synthesis data
synth_file <- file.path(output_dir, "size_class_survival_synthesis.csv")
pooled_file <- file.path(output_dir, "size_class_survival_synthesis_pooled.csv")

if (file.exists(synth_file) && file.exists(pooled_file)) {
  synth_data <- read.csv(synth_file)
  pooled_data <- read.csv(pooled_file)

  synth_data$size_class <- factor(synth_data$size_class, levels = SIZE_LABELS)
  pooled_data$size_class <- factor(pooled_data$size_class, levels = SIZE_LABELS)

  synth_data$x_num <- as.numeric(synth_data$size_class)
  pooled_data$x_num <- as.numeric(pooled_data$size_class)

  # Point size from sample size
  synth_data$pt_size <- sqrt(synth_data$n)

  # Colors
  pop_colors <- c("Natural" = pal$natural, "Restoration" = pal$restoration)
  tier_shapes <- c("Individual" = 16, "Summary" = 17)

  # Dodge by population type
  dodge_w <- 0.35
  synth_data$x_dodge <- synth_data$x_num +
    ifelse(synth_data$pop_type == "Natural", -dodge_w / 2, dodge_w / 2)

  # Small y-jitter for overlapping points
  set.seed(42)
  synth_data$y_jitter <- synth_data$survival_rate + runif(nrow(synth_data), -0.008, 0.008)
  synth_data$y_jitter <- pmin(pmax(synth_data$y_jitter, 0), 1)

  # Clamp CIs
  y_min_c <- 0.35
  y_max_c <- 1.06
  pooled_data$ci_lo_clamp <- pmax(pooled_data$ci_lo, y_min_c)
  pooled_data$ci_hi_clamp <- pmin(pooled_data$ci_hi, y_max_c)

  # Size class labels
  sc_labels_expr <- c(
    expression(atop("SC1", "0\u201325")),
    expression(atop("SC2", "25\u2013100")),
    expression(atop("SC3", "100\u2013500")),
    expression(atop("SC4", "500\u20132k")),
    expression(atop("SC5", ">2k cm"^2))
  )

  fig2c <- ggplot() +
    # Pooled CI error bars
    geom_errorbar(data = pooled_data,
                  aes(x = x_num, ymin = ci_lo_clamp, ymax = ci_hi_clamp),
                  width = 0.15, linewidth = 0.55, color = "grey55") +
    # Study-level points
    geom_point(data = synth_data,
               aes(x = x_dodge, y = y_jitter,
                   color = pop_type, shape = data_tier, size = pt_size),
               alpha = 0.72) +
    # Pooled line
    geom_line(data = pooled_data,
              aes(x = x_num, y = pooled_surv),
              color = "black", linewidth = 1.1) +
    # Pooled diamonds
    geom_point(data = pooled_data,
               aes(x = x_num, y = pooled_surv),
               color = "black", fill = "white", size = 3.5, shape = 23, stroke = 1.0) +
    # k annotations
    annotate("text",
             x = pooled_data$x_num,
             y = rep(y_max_c - 0.005, nrow(pooled_data)),
             label = paste0("italic(k)==", pooled_data$k),
             parse = TRUE, size = 2.5, color = "grey30", vjust = 1) +
    scale_size_continuous(name = "Sample size", range = c(1.2, 6),
                          breaks = sqrt(c(50, 500)), labels = c("50", "500")) +
    scale_color_manual(name = "Population type", values = pop_colors) +
    scale_shape_manual(name = "Data tier", values = tier_shapes) +
    scale_x_continuous(breaks = 1:5, labels = sc_labels_expr,
                       expand = expansion(mult = 0.08)) +
    scale_y_continuous(limits = c(y_min_c, y_max_c),
                       breaks = seq(0.4, 1.0, 0.1),
                       labels = scales::label_number(accuracy = 0.1)) +
    labs(x = expression("Size class (cm"^2*")"), y = "Annual survival rate", tag = "c") +
    theme_manuscript() +
    theme(
      text = element_text(family = "Helvetica"),
      axis.title = element_text(size = 10, family = "Helvetica"),
      axis.text = element_text(size = 8, family = "Helvetica", color = "grey30"),
      axis.text.x = element_text(lineheight = 0.85),
      legend.position = "bottom",
      legend.box = "horizontal",
      legend.text = element_text(size = 7),
      legend.title = element_text(size = 8, face = "bold"),
      legend.key.size = unit(3, "mm"),
      panel.grid.major.x = element_blank(),
      plot.margin = margin(6, 8, 4, 6, "mm")
    ) +
    guides(
      color = guide_legend(order = 1, override.aes = list(size = 3, alpha = 1)),
      shape = guide_legend(order = 2, override.aes = list(size = 3, alpha = 1)),
      size = guide_legend(order = 3, override.aes = list(shape = 16, color = "grey40"))
    )

  cat(sprintf("  Panel c: %d study x SC records, %d studies\n",
              nrow(synth_data), length(unique(synth_data$study))))
} else {
  cat("  WARNING: Synthesis data not found, skipping panel c\n")
  fig2c <- ggplot() + theme_void() +
    annotate("text", x = 0.5, y = 0.5, label = "Run script 20 first", size = 4)
}

# =============================================================================
# COMBINE — VERTICAL STACK (a / b / c) at 174 x 220 mm
# =============================================================================

cat("Combining panels a / b / c...\n")

fig2 <- (fig2a / fig2b / fig2c) +
  plot_layout(heights = c(1, 1, 1.2), guides = "collect") &
  theme(legend.position = "bottom")

save_manuscript_fig(fig2, "Fig2_demographic_rates", width_mm = 174, height_mm = 220)

cat(sprintf("\n  Survival: R² = %.1f%% (n = %s)\n", surv_r2 * 100, comma(nrow(surv_nat))))
cat(sprintf("  RGR: R² = %.1f%% (n = %s)\n", rgr_r2 * 100, comma(nrow(growth_rgr))))
cat("\nDone: Figure 2 — Size-Dependent Vital Rates (3-panel)\n")
