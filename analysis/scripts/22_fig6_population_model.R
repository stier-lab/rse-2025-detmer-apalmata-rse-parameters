#!/usr/bin/env Rscript
# =============================================================================
# FIGURE 4: POPULATION VIABILITY ASSESSMENT (4-panel: (a | b) / (c | d))
# =============================================================================
# Panel a: 5x5 transition matrix heatmap
# Panel b: Elasticity bar chart (stasis, growth, retrogression, fragmentation)
# Panel c: Bootstrap lambda distribution (bicolor histogram)
# Panel d: Leave-one-study-out lambda sensitivity (horizontal point plot)
#
# OUTPUT: analysis/figures/manuscript/Fig4_population_model.{png,pdf}
#         174 x 180 mm (double-column), 300 DPI
#
# Author: Detmer & Stier Lab
# Date: 2026-03
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(patchwork)
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
cat("  FIGURE 4: Population Viability Assessment (a|b / c|d)\n")
cat("================================================================\n\n")

# =============================================================================
# GET DETERMINISTIC LAMBDA
# =============================================================================

det_lambda <- 0.9856  # fallback
pop_params_file <- file.path(output_dir, "population_parameters.csv")
if (file.exists(pop_params_file)) {
  pop_params <- read_csv(pop_params_file, show_col_types = FALSE)
  det_row <- pop_params %>% filter(parameter == "lambda")
  if (nrow(det_row) > 0) det_lambda <- as.numeric(det_row$value[1])
}
cat(sprintf("  Deterministic lambda: %.4f\n", det_lambda))

# =============================================================================
# PANEL A: TRANSITION MATRIX HEATMAP
# =============================================================================

cat("Panel a: Transition matrix heatmap...\n")

tmat_file <- file.path(output_dir, "transition_matrix.csv")
if (!file.exists(tmat_file)) {
  stop("Required file not found: ", tmat_file)
}

tmat <- read.csv(tmat_file, row.names = 1) %>% as.matrix()
cat(sprintf("  Transition matrix loaded (%dx%d)\n", nrow(tmat), ncol(tmat)))

# Reshape to long format for ggplot
tmat_long <- expand.grid(
  to   = factor(rownames(tmat), levels = rev(rownames(tmat))),
  from = factor(colnames(tmat), levels = colnames(tmat))
)
tmat_long$value <- as.vector(tmat[cbind(
  match(tmat_long$to, rownames(tmat)),
  match(tmat_long$from, colnames(tmat))
)])

fig4a <- ggplot(tmat_long, aes(x = from, y = to, fill = value)) +
  geom_tile(color = "white", linewidth = 0.6) +
  geom_text(aes(label = ifelse(value >= 0.005, sprintf("%.2f", value), "")),
            size = 2.5, color = ifelse(tmat_long$value > 0.5, "white", "grey20"),
            fontface = "bold") +
  scale_fill_viridis_c(
    name = "Transition\nprobability",
    option = "D", limits = c(0, 1),
    breaks = c(0, 0.25, 0.5, 0.75, 1)
  ) +
  labs(x = "From size class (t)", y = "To size class (t+1)", tag = "a") +
  coord_equal() +
  theme_manuscript() +
  theme(
    text         = element_text(family = "Helvetica"),
    axis.title   = element_text(size = 10, family = "Helvetica"),
    axis.text    = element_text(size = 9, family = "Helvetica", color = "grey30"),
    plot.margin  = margin(6, 6, 4, 6, "mm"),
    legend.position = "right",
    legend.key.height = unit(12, "mm"),
    legend.key.width = unit(3, "mm"),
    legend.text = element_text(size = 7),
    legend.title = element_text(size = 8)
  )

cat("  Panel a complete.\n")

# =============================================================================
# PANEL B: ELASTICITY BAR CHART
# =============================================================================

cat("Panel b: Elasticity decomposition...\n")

# Load elasticity matrix and vital rate elasticity
elast_matrix_file <- file.path(output_dir, "elasticity_matrix.csv")
vital_rate_file   <- file.path(output_dir, "vital_rate_elasticity.csv")

if (!file.exists(elast_matrix_file)) {
  stop("Required file not found: ", elast_matrix_file)
}

elast_mat <- read.csv(elast_matrix_file, row.names = 1) %>% as.matrix()
cat(sprintf("  Elasticity matrix loaded (%dx%d)\n", nrow(elast_mat), ncol(elast_mat)))

# Decompose the 5x5 elasticity matrix into vital rate types per size class
# Diagonal = stasis (staying in same size class)
# Below diagonal = growth (moving to larger size class)
# Above diagonal = retrogression (shrinking to smaller size class)
size_classes <- paste0("SC", 1:5)
n_sc <- 5

elast_decomp <- data.frame(
  size_class = rep(size_classes, 4),
  vital_rate = rep(c("Stasis", "Growth", "Retrogression", "Fragmentation"), each = n_sc),
  elasticity = NA_real_
)

for (i in 1:n_sc) {
  # Stasis: diagonal element [i, i]
  elast_decomp$elasticity[elast_decomp$size_class == size_classes[i] &
                            elast_decomp$vital_rate == "Stasis"] <- elast_mat[i, i]

  # Growth: column i, rows below diagonal (j > i; larger size class = higher row index)
  growth_val <- sum(elast_mat[seq_len(n_sc) > i, i])
  elast_decomp$elasticity[elast_decomp$size_class == size_classes[i] &
                            elast_decomp$vital_rate == "Growth"] <- growth_val

  # Retrogression: column i, rows above diagonal (j < i; smaller size class)
  retro_val <- if (i > 1) sum(elast_mat[seq_len(i - 1), i]) else 0
  elast_decomp$elasticity[elast_decomp$size_class == size_classes[i] &
                            elast_decomp$vital_rate == "Retrogression"] <- retro_val
}

# Fragmentation elasticity from vital_rate_elasticity.csv
if (file.exists(vital_rate_file)) {
  vr_elast <- read.csv(vital_rate_file)
  for (i in 1:n_sc) {
    frag_row <- vr_elast[vr_elast$size_class == size_classes[i], ]
    frag_val <- if (nrow(frag_row) > 0) frag_row$fragmentation_elasticity[1] else 0
    elast_decomp$elasticity[elast_decomp$size_class == size_classes[i] &
                              elast_decomp$vital_rate == "Fragmentation"] <- frag_val
  }
} else {
  # Set fragmentation to 0 if file not available
  elast_decomp$elasticity[elast_decomp$vital_rate == "Fragmentation"] <- 0
}

# Remove zero/near-zero entries for cleaner plot
elast_decomp <- elast_decomp %>%
  filter(abs(elasticity) > 0.0001)

# Factor ordering
elast_decomp$size_class <- factor(elast_decomp$size_class, levels = size_classes)
elast_decomp$vital_rate <- factor(elast_decomp$vital_rate,
                                   levels = c("Stasis", "Growth", "Retrogression", "Fragmentation"))

# Colors for vital rate types
vr_colors <- c(
  "Stasis"          = pal$surv_mid,
  "Growth"          = pal$grow_mid,
  "Retrogression"   = pal$slate_light,
  "Fragmentation"   = pal$accent
)

# SC5 stasis value for annotation
sc5_stasis <- elast_decomp %>%
  filter(size_class == "SC5", vital_rate == "Stasis") %>%
  pull(elasticity)
# Matrix elasticities sum to 1.0 by definition; fragmentation is added from
# vital_rate_elasticity.csv for visual display but should not inflate the denominator
total_elast <- 1.0
sc5_pct <- sc5_stasis / total_elast * 100

cat(sprintf("  SC5 stasis elasticity: %.3f (%.1f%% of total)\n", sc5_stasis, sc5_pct))

fig4b <- ggplot(elast_decomp, aes(x = size_class, y = elasticity, fill = vital_rate)) +
  geom_col(width = 0.7, color = "white", linewidth = 0.2) +
  # SC5 stasis annotation arrow
  annotate("segment",
           x = 4.6, xend = 4.85,
           y = sc5_stasis * 0.5, yend = sc5_stasis * 0.45,
           arrow = arrow(length = unit(1.5, "mm"), type = "closed"),
           color = "grey30", linewidth = 0.4) +
  annotate("text",
           x = 4.55, y = sc5_stasis * 0.55,
           label = sprintf("SC5 stasis\n%.1f%%", sc5_pct),
           hjust = 1, size = 2.5, color = "grey30", lineheight = 0.9) +
  scale_fill_manual(values = vr_colors, name = "Vital rate") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  labs(
    x = "Size class",
    y = "Elasticity",
    tag = "b"
  ) +
  theme_manuscript() +
  theme(
    text         = element_text(family = "Helvetica"),
    axis.title   = element_text(size = 10, family = "Helvetica"),
    axis.text    = element_text(size = 9, family = "Helvetica", color = "grey30"),
    plot.margin  = margin(6, 12, 4, 6, "mm"),
    legend.position = "bottom",
    legend.key.size = unit(3, "mm"),
    legend.text = element_text(size = 8),
    legend.title = element_text(size = 8.5, face = "bold")
  )

cat("  Panel b complete.\n")

# =============================================================================
# PANEL C: BOOTSTRAP LAMBDA DISTRIBUTION
# =============================================================================

cat("Panel c: Bootstrap lambda distribution...\n")

boot_rds_file <- file.path(output_dir, "lambda_bootstrap_samples.rds")

if (!file.exists(boot_rds_file)) {
  stop("Required file not found: ", boot_rds_file)
}

boot_obj <- readRDS(boot_rds_file)

# Handle various formats
if (is.data.frame(boot_obj)) {
  lambda_col <- intersect(names(boot_obj), c("lambda", "Lambda", "value"))
  boot_vals <- if (length(lambda_col) > 0) boot_obj[[lambda_col[1]]] else boot_obj[[1]]
} else if (is.list(boot_obj)) {
  boot_vals <- unlist(boot_obj)
} else {
  boot_vals <- as.numeric(boot_obj)
}
boot_vals <- boot_vals[is.finite(boot_vals)]

ci_95 <- quantile(boot_vals, c(0.025, 0.975), na.rm = TRUE)
p_decline <- mean(boot_vals < 1, na.rm = TRUE)

# Get total bootstrap count from pop_params
n_boot_total <- length(boot_vals)  # fallback
if (exists("pop_params")) {
  total_row <- pop_params %>% filter(parameter == "n_boot_total")
  valid_row <- pop_params %>% filter(parameter == "n_boot_valid")
  if (nrow(total_row) > 0) n_boot_total <- as.numeric(total_row$value[1])
  if (nrow(valid_row) > 0) n_boot_valid_from_params <- as.numeric(valid_row$value[1])
}

cat(sprintf("  Bootstrap: n = %d valid, median = %.3f\n", length(boot_vals), median(boot_vals)))
cat(sprintf("  95%% CI: [%.3f, %.3f]\n", ci_95[1], ci_95[2]))
cat(sprintf("  P(decline): %.1f%%\n", p_decline * 100))

# Bicolor fill: decline vs growth
boot_df <- data.frame(lambda = boot_vals) %>%
  mutate(status = ifelse(lambda < 1, "decline", "growth"))

fig4c <- ggplot(boot_df, aes(x = lambda, fill = status)) +
  geom_histogram(bins = 40, color = "white", linewidth = 0.2,
                 boundary = 1) +
  # Replacement line (lambda = 1)
  geom_vline(xintercept = 1, linetype = "solid",
             color = "grey40", linewidth = 0.8) +
  # Deterministic lambda
  geom_vline(xintercept = det_lambda, linetype = "dashed",
             color = pal$surv_dark, linewidth = 0.8) +
  scale_fill_manual(
    values = c("decline" = pal$accent, "growth" = pal$surv_mid),
    labels = c("decline" = expression(lambda < 1 ~ "(decline)"),
                "growth" = expression(lambda >= 1 ~ "(growth)")),
    name = NULL
  ) +
  annotate("label", x = min(boot_vals) + 0.01, y = Inf,
           label = sprintf("\u03BB = %.3f (NOAA-conditional)\n95%% CI: [%.3f, %.3f]\nP(decline) = %.1f%%\n%s of %s valid",
                           det_lambda, ci_95[1], ci_95[2], p_decline * 100,
                           comma(length(boot_vals)), comma(n_boot_total)),
           vjust = 1.2, hjust = 0, size = 2.3,
           fill = alpha("white", 0.9), color = pal$slate_dark,
           label.padding = unit(0.4, "lines")) +
  annotate("text", x = 1.02, y = Inf,
           label = "Replacement", vjust = 1.5, hjust = 0,
           size = 2.0, color = "grey40", fontface = "italic") +
  labs(x = expression(lambda ~ "(population growth rate)"),
       y = "Bootstrap replicates", tag = "c") +
  coord_cartesian(clip = "off") +
  theme_manuscript() +
  theme(
    text         = element_text(family = "Helvetica"),
    axis.title   = element_text(size = 9, family = "Helvetica"),
    axis.text    = element_text(size = 8, family = "Helvetica", color = "grey30"),
    plot.margin  = margin(6, 10, 4, 6, "mm"),
    legend.position = "bottom",
    legend.key.size = unit(3, "mm"),
    legend.text = element_text(size = 7)
  )

cat("  Panel c complete.\n")

# =============================================================================
# PANEL D: LEAVE-ONE-STUDY-OUT LAMBDA SENSITIVITY
# =============================================================================

cat("Panel d: LOSO lambda sensitivity...\n")

loso_file <- file.path(output_dir, "sensitivity_lambda_loo.csv")

if (!file.exists(loso_file)) {
  stop("Required file not found: ", loso_file)
}

loso_data <- read_csv(loso_file, show_col_types = FALSE)

# Clean study names
loso_data <- loso_data %>%
  mutate(
    study_label = gsub("_", " ", excluded_study) %>%
      str_to_title() %>%
      str_replace_all("Usgs", "USGS") %>%
      str_replace_all("Usvi", "USVI") %>%
      str_replace_all("Noaa", "NOAA") %>%
      str_replace_all("Et Al", "et al."),
    is_noaa = grepl("noaa|NOAA", excluded_study, ignore.case = TRUE),
    point_color = ifelse(is_noaa, pal$accent, pal$surv_mid)
  ) %>%
  arrange(lambda)

loso_data$study_label <- factor(loso_data$study_label,
                                 levels = loso_data$study_label)

noaa_lambda <- loso_data$lambda[loso_data$is_noaa]
if (length(noaa_lambda) == 0) noaa_lambda <- NA_real_

# Build NOAA annotation conditionally
noaa_annotation <- if (!is.na(noaa_lambda)) {
  annotate("label", x = 0.69, y = 1.7,
           label = sprintf("NOAA = 78%% of data\n\u03BB drops %.3f \u2192 %.3f\nEstimate is NOAA-conditional",
                           det_lambda, noaa_lambda),
           size = 2.1, color = pal$accent, fontface = "italic",
           hjust = 0, vjust = 0, fill = alpha("white", 0.85), linewidth = 0)
} else {
  NULL
}

fig4d <- ggplot(loso_data, aes(x = lambda, y = study_label)) +
  # Full-model reference line
  geom_vline(xintercept = det_lambda, linetype = "dashed",
             color = pal$slate_light, linewidth = 0.4) +
  # Replacement line
  geom_vline(xintercept = 1, linetype = "dotted",
             color = "grey60", linewidth = 0.3) +
  # Points
  geom_point(aes(color = is_noaa), size = 3) +
  scale_color_manual(values = c("FALSE" = pal$surv_mid, "TRUE" = pal$accent),
                     guide = "none") +
  # Lambda value labels
  geom_text(aes(label = sprintf("%.3f", lambda)),
            hjust = -0.3, size = 2.1, color = pal$slate_mid) +
  # NOAA callout — highlights NOAA-conditional nature of lambda estimate
  noaa_annotation +
  scale_x_continuous(limits = c(0.68, 1.05),
                     breaks = seq(0.7, 1.0, 0.1),
                     name = expression("Population growth rate (" * lambda * ")")) +
  labs(y = "Study excluded", tag = "d") +
  theme_manuscript() +
  theme(
    text         = element_text(family = "Helvetica"),
    axis.title   = element_text(size = 9, family = "Helvetica"),
    axis.text    = element_text(size = 8, family = "Helvetica", color = "grey30"),
    plot.margin  = margin(6, 10, 4, 6, "mm"),
    panel.grid.major.y = element_blank()
  )

cat("  Panel d complete.\n")

# =============================================================================
# COMBINE — (transition matrix | elasticity) / (lambda | LOSO) at 174 x 180 mm
# =============================================================================

cat("Combining panels (a | b) / (c | d)...\n")

fig4 <- (fig4a | fig4b) / (fig4c | fig4d) +
  plot_layout(heights = c(1, 1), guides = "collect") +
  plot_annotation(theme = theme(plot.background = element_rect(fill = "white", color = NA))) &
  theme(legend.position = "bottom")

save_manuscript_fig(fig4, "Fig4_population_model", width_mm = 174, height_mm = 180)

cat("\nDone: Figure 4 — Population Viability Assessment (4-panel)\n")
