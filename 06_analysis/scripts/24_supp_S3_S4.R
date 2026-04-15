#!/usr/bin/env Rscript
# =============================================================================
# SUPPLEMENTARY FIGURES S3 & S4 — Journal-Ready Versions
# =============================================================================
#
# PURPOSE: Generate supplementary Figures S3 (model diagnostics) and S4 (model
#          selection AICc comparison) for survival and growth models.
#
# S3: Model Diagnostics (2-panel vertical stack)
#     (a) Survival GAM: Fitted vs Pearson residuals
#     (b) Growth LM: Fitted vs residuals with LOWESS
#
# S4: Model Selection (2-panel vertical stack)
#     (a) Survival: delta-AICc for candidate models (GLM + GLMM)
#     (b) Growth: delta-AICc for candidate models (LM + LMM)
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds (individual survival data)
#   - 06_analysis/output/prepared_growth_data.rds (individual growth data)
#   - 06_analysis/output/model_selection_survival.csv (survival model AICc table)
#   - 06_analysis/output/model_selection_growth.csv (growth model AICc table)
#
# OUTPUTS:
#   - 06_analysis/figures/supplementary/FigS3_model_diagnostics.{png,pdf}
#   - 06_analysis/figures/supplementary/FigS4_model_selection.{png,pdf}
#   174 mm width, 300 DPI (Coral Reefs double-column)
#
# Author: Detmer & Stier Lab
# Date: 2026-02
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(patchwork)
  library(cowplot)
  library(scales)
  library(mgcv)
  library(lme4)
})

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

pal <- MANUSCRIPT_PALETTE
project_root <- get_project_root()
supp_dir <- file.path(project_root, "06_analysis/figures/supplementary")
dir.create(supp_dir, showWarnings = FALSE, recursive = TRUE)

cat("\n")
cat("==============================================================\n")
cat("  SUPPLEMENTARY FIGURES S3 & S4\n")
cat("==============================================================\n\n")

# =============================================================================
# LOAD DATA
# =============================================================================

cat("Loading data...\n")

surv_data <- readRDS(file.path(project_root, "06_analysis/output/prepared_survival_data.rds")) %>%
  filter(!is.na(size_class), !is.na(survived), !is.na(log_size))

growth_data <- readRDS(file.path(project_root, "06_analysis/output/prepared_growth_data.rds")) %>%
  filter(!is.na(size_class), !is.na(size_cm2), size_cm2 > 0, !is.na(growth_cm2_yr))

cat(sprintf("  Survival records: %s\n", comma(nrow(surv_data))))
cat(sprintf("  Growth records:   %s\n", comma(nrow(growth_data))))

# Load model selection tables
surv_models <- read.csv(file.path(project_root, "06_analysis/output/model_selection_survival.csv"),
                        stringsAsFactors = FALSE)
growth_models <- read.csv(file.path(project_root, "06_analysis/output/model_selection_growth.csv"),
                          stringsAsFactors = FALSE)

cat(sprintf("  Survival models: %d\n", nrow(surv_models)))
cat(sprintf("  Growth models:   %d\n", nrow(growth_models)))

# =============================================================================
# FIG S3: MODEL DIAGNOSTICS
# =============================================================================

cat("\nGenerating Figure S3: Model Diagnostics...\n")

# --- (a) Survival GAM: Fit model and extract residuals ---
cat("  Fitting survival GAM...\n")

surv_data$study_f <- as.factor(surv_data$study)
surv_gam <- gam(survived ~ s(log_size, k = 10) + s(study_f, bs = "re"),
                family = binomial, data = surv_data, method = "REML")

surv_fitted <- fitted(surv_gam)
surv_pearson <- residuals(surv_gam, type = "pearson")

surv_resid_df <- tibble(
  fitted = surv_fitted,
  residual = surv_pearson
)

# Compute LOWESS for smooth trend line
surv_lowess <- lowess(surv_resid_df$fitted, surv_resid_df$residual)
surv_lowess_df <- tibble(x = surv_lowess$x, y = surv_lowess$y)

# Overdispersion annotation
disp_ratio <- sum(surv_pearson^2) / (length(surv_pearson) - sum(surv_gam$edf))
disp_label <- sprintf("Dispersion ratio = %.2f", disp_ratio)

p_s3a <- ggplot(surv_resid_df, aes(x = fitted, y = residual)) +
  geom_point(alpha = 0.15, size = 0.6, color = pal$surv_mid) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40", linewidth = 0.4) +
  geom_line(data = surv_lowess_df, aes(x = x, y = y),
            color = pal$accent, linewidth = 0.8) +
  annotate("label", x = min(surv_resid_df$fitted) + 0.02,
           y = min(surv_resid_df$residual) * 0.85,
           label = disp_label, hjust = 0, size = 3.0, color = pal$slate_dark,
           fill = "white", label.padding = unit(2, "mm")) +
  labs(x = "Fitted values (predicted probability)",
       y = "Pearson residuals") +
  theme_manuscript() +
  theme(plot.margin = margin(8, 10, 4, 10, "mm"))

cat("  Panel (a) survival diagnostics built\n")

# --- (b) Growth LM: Fit model and extract residuals ---
cat("  Fitting growth model...\n")

growth_lm <- lm(growth_cm2_yr ~ poly(log_size, 2), data = growth_data)

growth_fitted <- fitted(growth_lm)
growth_resid <- residuals(growth_lm)

growth_resid_df <- tibble(
  fitted = growth_fitted,
  residual = growth_resid
)

# Trim extreme outliers for display (show 1st-99th percentile range)
y_lower <- quantile(growth_resid_df$residual, 0.005)
y_upper <- quantile(growth_resid_df$residual, 0.995)
x_lower <- quantile(growth_resid_df$fitted, 0.005)
x_upper <- quantile(growth_resid_df$fitted, 0.995)

# Count trimmed points for annotation
n_trimmed <- sum(growth_resid_df$residual < y_lower | growth_resid_df$residual > y_upper |
                 growth_resid_df$fitted < x_lower | growth_resid_df$fitted > x_upper)

# Filter to display range for LOWESS computation
growth_display_df <- growth_resid_df %>%
  filter(residual >= y_lower, residual <= y_upper,
         fitted >= x_lower, fitted <= x_upper)

growth_lowess <- lowess(growth_display_df$fitted, growth_display_df$residual)
growth_lowess_df <- tibble(x = growth_lowess$x, y = growth_lowess$y)

# R-squared annotation
growth_r2 <- summary(growth_lm)$r.squared
r2_label <- sprintf("R\u00B2 = %.3f", growth_r2)
trim_label <- sprintf("%d extreme points not shown", n_trimmed)

p_s3b <- ggplot(growth_display_df, aes(x = fitted, y = residual)) +
  geom_point(alpha = 0.12, size = 0.6, color = pal$grow_mid) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40", linewidth = 0.4) +
  geom_line(data = growth_lowess_df, aes(x = x, y = y),
            color = pal$accent, linewidth = 0.8) +
  annotate("text", x = min(growth_display_df$fitted) + diff(range(growth_display_df$fitted)) * 0.02,
           y = y_upper * 0.95,
           label = r2_label, hjust = 0, size = 3.0, color = pal$slate_mid) +
  annotate("text", x = max(growth_display_df$fitted) - diff(range(growth_display_df$fitted)) * 0.02,
           y = y_lower * 0.95,
           label = trim_label, hjust = 1, size = 2.5, color = pal$slate_light,
           fontface = "italic") +
  labs(x = expression(paste("Fitted values (", cm^2, "/yr)")),
       y = "Residuals") +
  theme_manuscript() +
  theme(plot.margin = margin(4, 10, 8, 10, "mm"))

cat("  Panel (b) growth diagnostics built\n")

# --- Combine S3 ---
p_s3 <- p_s3a / p_s3b +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 12, face = "bold", family = "sans"))

save_manuscript_fig(p_s3, "FigS3_model_diagnostics",
                    width_mm = 174, height_mm = 180, fig_dir = supp_dir)

cat("  Figure S3 saved.\n")

# =============================================================================
# FIG S4: MODEL SELECTION
# =============================================================================

cat("\nGenerating Figure S4: Model Selection...\n")

# --- Lookup table for clean model display names ---
surv_name_lookup <- c(
  "S1_null"           = "Null",
  "S2_linear"         = "Linear (log size)",
  "S3_quadratic"      = "Quadratic (log size)",
  "S4_threshold"      = "Threshold (100 cm\u00B2)",
  "S5_categorical"    = "Categorical (5 classes)",
  "S6_size_region"    = "Size + Region",
  "S7_interaction"    = "Size \u00D7 Region",
  "S_ME1_null"        = "RE Null",
  "S_ME2_linear"      = "RE Linear",
  "S_ME3_categorical" = "RE Categorical",
  "S_ME4_random_slope" = "RE Random slope"
)

growth_name_lookup <- c(
  "G1_null"           = "Null",
  "G2_linear"         = "Linear (log size)",
  "G3_quadratic"      = "Quadratic (log size)",
  "G4_categorical"    = "Categorical (5 classes)",
  "G5_size_region"    = "Size + Region",
  "G_ME1_null"        = "RE Null",
  "G_ME2_linear"      = "RE Linear",
  "G_ME3_categorical" = "RE Categorical",
  "G_ME4_random_slope" = "RE Random slope"
)

# --- (a) Survival model comparison ---
surv_plot_df <- surv_models %>%
  mutate(
    display_name = ifelse(model %in% names(surv_name_lookup),
                          surv_name_lookup[model], model),
    is_best = (delta_aic == 0),
    model_type = ifelse(grepl("^S_ME", model), "GLMM", "GLM")
  ) %>%
  arrange(delta_aic) %>%
  mutate(display_name = factor(display_name, levels = rev(display_name)))

p_s4a <- ggplot(surv_plot_df, aes(x = display_name, y = delta_aic)) +
  geom_col(aes(fill = model_type, alpha = is_best), width = 0.7) +
  geom_hline(yintercept = 2, linetype = "dashed", color = "grey50", linewidth = 0.3) +
  geom_hline(yintercept = 10, linetype = "dashed", color = "grey50", linewidth = 0.3) +
  geom_text(aes(label = ifelse(delta_aic > 100, sprintf("%.0f", delta_aic), "")),
            hjust = -0.1, size = 2.3, color = pal$slate_mid) +
  scale_fill_manual(
    values = c("GLM" = pal$surv_mid, "GLMM" = pal$grow_mid),
    name = NULL
  ) +
  scale_alpha_manual(values = c("FALSE" = 0.55, "TRUE" = 1), guide = "none") +
  coord_flip(clip = "off") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(x = NULL, y = expression(paste(Delta, "AIC"))) +
  theme_manuscript() +
  theme(
    legend.position = "none",
    plot.margin = margin(8, 14, 4, 10, "mm"),
    axis.text.y = element_text(size = 8)
  )

cat("  Panel (a) survival model selection built\n")

# --- (b) Growth model comparison ---
growth_plot_df <- growth_models %>%
  mutate(
    display_name = ifelse(model %in% names(growth_name_lookup),
                          growth_name_lookup[model], model),
    is_best = (delta_aic == 0),
    model_type = ifelse(grepl("^G_ME", model), "LMM", "LM")
  ) %>%
  arrange(delta_aic) %>%
  mutate(display_name = factor(display_name, levels = rev(display_name)))

p_s4b <- ggplot(growth_plot_df, aes(x = display_name, y = delta_aic)) +
  geom_col(aes(fill = model_type, alpha = is_best), width = 0.7) +
  geom_hline(yintercept = 2, linetype = "dashed", color = "grey50", linewidth = 0.3) +
  geom_hline(yintercept = 10, linetype = "dashed", color = "grey50", linewidth = 0.3) +
  scale_fill_manual(
    values = c("LM" = pal$surv_mid, "LMM" = pal$grow_mid),
    name = NULL
  ) +
  scale_alpha_manual(values = c("FALSE" = 0.55, "TRUE" = 1), guide = "none") +
  coord_flip(clip = "off") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
  labs(x = NULL, y = expression(paste(Delta, "AIC"))) +
  theme_manuscript() +
  theme(
    legend.position = "none",
    plot.margin = margin(4, 14, 4, 10, "mm"),
    axis.text.y = element_text(size = 8)
  )

cat("  Panel (b) growth model selection built\n")

# --- Shared legend ---
# Build a guide plot to extract the combined legend (fill only, no opacity legend)
legend_df <- tibble(
  type = factor(c("Fixed effects (GLM/LM)", "Random effects (GLMM/LMM)"),
                levels = c("Fixed effects (GLM/LM)", "Random effects (GLMM/LMM)")),
  y = 1
)

p_legend_src <- ggplot(legend_df, aes(x = type, y = y, fill = type)) +
  geom_col() +
  scale_fill_manual(
    values = c("Fixed effects (GLM/LM)" = pal$surv_mid,
               "Random effects (GLMM/LMM)" = pal$grow_mid),
    name = NULL
  ) +
  theme_manuscript() +
  theme(legend.position = "bottom",
        legend.key.size = unit(4, "mm"),
        legend.text = element_text(size = 8))

shared_legend <- cowplot::get_legend(p_legend_src)

# --- Combine S4 with shared legend ---
p_s4_panels <- (p_s4a / p_s4b) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(size = 12, face = "bold", family = "sans"))

p_s4_final <- cowplot::plot_grid(
  p_s4_panels,
  shared_legend,
  ncol = 1,
  rel_heights = c(1, 0.06)
)

# Save S4
png_path_s4 <- file.path(supp_dir, "FigS4_model_selection.png")
pdf_path_s4 <- file.path(supp_dir, "FigS4_model_selection.pdf")

ggsave(png_path_s4, plot = p_s4_final,
       width = 174, height = 190, units = "mm", dpi = 300, bg = "white")

pdf_device <- tryCatch(
  { grDevices::cairo_pdf; cairo_pdf },
  error = function(e) "pdf"
)
ggsave(pdf_path_s4, plot = p_s4_final,
       width = 174, height = 190, units = "mm", bg = "white", device = pdf_device)

cat(sprintf("  Saved: FigS4_model_selection (.png + .pdf) -- 174 x 190 mm\n"))

# =============================================================================
# SUMMARY
# =============================================================================

cat("\n")
cat("==============================================================\n")
cat("  SUPPLEMENTARY FIGURES S3 & S4 COMPLETE\n")
cat("==============================================================\n")
cat(sprintf("  S3: %s\n", file.path(supp_dir, "FigS3_model_diagnostics.png")))
cat(sprintf("  S4: %s\n", file.path(supp_dir, "FigS4_model_selection.png")))
cat("==============================================================\n\n")
