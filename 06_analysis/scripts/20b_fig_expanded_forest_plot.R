#!/usr/bin/env Rscript
# =============================================================================
# FIGURE 3: CARIBBEAN SURVIVAL SYNTHESIS (2-panel: a=forest, b=regional)
# =============================================================================
# Produces a publication-quality forest plot showing Caribbean-wide annual
# survival evidence from the expanded meta-analysis (k=16 studies, N=9,208).
#
# Layout (top to bottom):
#   1. Natural colony studies (k=6) with subgroup pooled diamond
#   2. Restoration fragment studies (k=10) with subgroup pooled diamond
#   3. Overall pooled estimate diamond
#
# Each study row shows: point estimate with 95% CI, point size proportional
# to random-effects weight, and right-side annotation (survival % [CI], N).
#
# Visual elements:
#   - Vertical dashed reference line at overall pooled estimate (81.1%)
#   - Light shaded prediction interval band (43.3% - 96.0%)
#   - Bottom heterogeneity annotation line
#
# INPUT:
#   06_analysis/output/expanded_meta_analysis_study_effects.csv  (16 rows)
#   06_analysis/output/expanded_meta_analysis_results.csv        (pooled stats)
#   06_analysis/output/expanded_meta_analysis_stratified.csv     (subgroup pooled)
#
# OUTPUT:
#   06_analysis/figures/manuscript/Fig3_caribbean_synthesis.{png,pdf}
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
fig_dir     <- file.path(project_root, "06_analysis/figures/manuscript")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

print_header("FIGURE 3: CARIBBEAN SURVIVAL SYNTHESIS (forest + regional)")

# =============================================================================
# 1. LOAD DATA
# =============================================================================

print_subheader("Loading meta-analysis data")

study_effects <- read_csv(
  file.path(output_dir, "expanded_meta_analysis_study_effects.csv"),
  show_col_types = FALSE
)
cat(sprintf("  Loaded %d study effects\n", nrow(study_effects)))

results <- read_csv(
  file.path(output_dir, "expanded_meta_analysis_results.csv"),
  show_col_types = FALSE
)
# Convert to named list for easy access
results_list <- setNames(results$value, results$statistic)
cat(sprintf("  Pooled survival: %s [%s, %s]\n",
            results_list[["Pooled survival (RE)"]],
            results_list[["95% CI lower"]],
            results_list[["95% CI upper"]]))

stratified <- read_csv(
  file.path(output_dir, "expanded_meta_analysis_stratified.csv"),
  show_col_types = FALSE
)
cat(sprintf("  Subgroup strata: %d\n", nrow(stratified)))

# =============================================================================
# 2. PREPARE STUDY DATA
# =============================================================================

print_subheader("Preparing study-level data")

# Clean study names
# FIX: Added NOAA regional splits after meta-analysis restructure (critique audit 2026-03-29)
name_map <- c(
  "NOAA_survey"                = "NOAA NCRMP",
  "NOAA_survey_florida_keys"   = "NOAA - Florida Keys",
  "NOAA_survey_curacao"        = "NOAA - Curacao",
  "NOAA_survey_navassa"        = "NOAA - Navassa",
  "pausch_et_al_2018"          = "Pausch et al. 2018",
  "USGS_USVI_exp"              = "USGS USVI",
  "kuffner_et_al_2020"         = "Kuffner et al. 2020",
  "fundemar_fragments"         = "FUNDEMAR",
  "vardi_2011_jamaica"         = "Vardi 2011 - Jamaica",
  "vardi_2011_puerto_rico"     = "Vardi 2011 - Puerto Rico",
  "vardi_2011_virgin_gorda"    = "Vardi 2011 - Virgin Gorda",
  "bruckner_bruckner_2001"     = "Bruckner & Bruckner 2001",
  "ortiz_prosper_2005"         = "Ortiz-Prosper 2005",
  "forrester_et_al_2013"       = "Forrester et al. 2013",
  "rosales_et_al_2024"         = "Rosales et al. 2024",
  "maurer_et_al_2022"          = "Maurer et al. 2022",
  "williams_miller_2010"       = "Williams & Miller 2010",
  "garrison_ward_2008"         = "Garrison & Ward 2008",
  "garrison_ward_2008_control" = "Garrison & Ward 2008 - Control",
  "garrison_ward_2008_relocated" = "Garrison & Ward 2008 - Relocated",
  "mendoza_quiroz_et_al_2023"  = "Mendoza-Quiroz et al. 2023",
  "rogers_muller_2012"         = "Rogers & Muller 2012",
  "rogers_et_al_1982"          = "Rogers et al. 1982",
  "ramos_romero_et_al_2025"    = "Ramos-Romero et al. 2025",
  "chamberland_et_al_2015"     = "Chamberland et al. 2015",
  "papke_et_al_2021"           = "Papke et al. 2021",
  "sutherland_et_al_2016"      = "Sutherland et al. 2016"
)

study_effects <- study_effects %>%
  mutate(
    clean_name = ifelse(study %in% names(name_map), name_map[study], study),
    label = paste0(clean_name, " (", region, ")"),
    # Data tier shape: circle for Tier 1, triangle for Tier 2
    tier_shape = ifelse(grepl("Tier 1", data_tier), "Individual", "Summary"),
    # Right-side annotation: single combined string
    annot_right = sprintf("%.1f [%.1f, %.1f]  %s",
                          survival_rate * 100, surv_lower * 100, surv_upper * 100,
                          format(n_total, big.mark = ","))
  )

# Separate natural and restoration
natural_studies <- study_effects %>%
  filter(population_type == "Natural colony") %>%
  arrange(desc(survival_rate))

restoration_studies <- study_effects %>%
  filter(population_type == "Restoration fragment") %>%
  arrange(desc(survival_rate))

cat(sprintf("  Natural colony studies: %d\n", nrow(natural_studies)))
cat(sprintf("  Restoration fragment studies: %d\n", nrow(restoration_studies)))

# =============================================================================
# 3. EXTRACT POOLED ESTIMATES
# =============================================================================

print_subheader("Extracting pooled estimates")

# Overall pooled
overall_surv  <- as.numeric(results_list[["Pooled survival (RE)"]])
overall_lower <- as.numeric(results_list[["95% CI lower"]])
overall_upper <- as.numeric(results_list[["95% CI upper"]])
pi_lower      <- as.numeric(results_list[["95% PI lower"]])
pi_upper      <- as.numeric(results_list[["95% PI upper"]])
# FIX: Handle both old ("I^2 (%)") and new ("I^2 (%) [independent model]") column names
i_sq          <- as.numeric(results_list[["I^2 (%) [independent model]"]] %||% results_list[["I^2 (%)"]])
i_sq_lower    <- as.numeric(results_list[["I^2 CI lower"]])
i_sq_upper    <- as.numeric(results_list[["I^2 CI upper"]])
tau_sq        <- as.numeric(results_list[["tau^2 (total)"]] %||% results_list[["tau^2"]])
q_stat        <- as.numeric(results_list[["Cochran's Q"]])
total_n       <- as.numeric(results_list[["Total observations (N)"]])

# Validate critical stats are not NA (key name mismatch would silently corrupt annotation)
stopifnot(!is.na(overall_surv), !is.na(overall_lower), !is.na(overall_upper),
          !is.na(i_sq), !is.na(tau_sq))

cat(sprintf("  Overall: %.1f%% [%.1f, %.1f]\n",
            overall_surv * 100, overall_lower * 100, overall_upper * 100))

# Subgroup pooled
nat_row <- stratified %>% filter(population_type == "Natural colony")
res_row <- stratified %>% filter(population_type == "Restoration fragment")

nat_surv  <- nat_row$pooled_survival
nat_lower <- nat_row$ci_lower
nat_upper <- nat_row$ci_upper

res_surv  <- res_row$pooled_survival
res_lower <- res_row$ci_lower
res_upper <- res_row$ci_upper

cat(sprintf("  Natural pooled: %.1f%% [%.1f, %.1f]\n",
            nat_surv * 100, nat_lower * 100, nat_upper * 100))
cat(sprintf("  Restoration pooled: %.1f%% [%.1f, %.1f]\n",
            res_surv * 100, res_lower * 100, res_upper * 100))

# =============================================================================
# 4. BUILD PLOTTING DATA FRAME
# =============================================================================

print_subheader("Building plot data")

n_nat <- nrow(natural_studies)
n_res <- nrow(restoration_studies)

# Y positions (top = highest number so top studies appear at top of plot)
y_current <- n_nat + n_res + 7  # start high

# Natural header
y_nat_header <- y_current
y_current <- y_current - 1

# Natural studies
y_nat_studies <- seq(y_current, y_current - n_nat + 1, by = -1)
y_current <- y_current - n_nat

# Natural pooled diamond
y_nat_pooled <- y_current
y_current <- y_current - 1

# Spacer
y_current <- y_current - 0.5

# Restoration header
y_res_header <- y_current
y_current <- y_current - 1

# Restoration studies
y_res_studies <- seq(y_current, y_current - n_res + 1, by = -1)
y_current <- y_current - n_res

# Restoration pooled diamond
y_res_pooled <- y_current
y_current <- y_current - 1

# Spacer
y_current <- y_current - 0.5

# Overall pooled diamond
y_overall <- y_current

# Combine study data
plot_studies <- bind_rows(
  natural_studies %>%
    mutate(y = y_nat_studies, group = "Natural colony"),
  restoration_studies %>%
    mutate(y = y_res_studies, group = "Restoration fragment")
)

cat(sprintf("  Total y-range: %.1f to %.1f\n", y_overall, y_nat_header))

# =============================================================================
# 5. BUILD THE FOREST PLOT
# =============================================================================

print_subheader("Building forest plot")

# Color assignments
col_natural     <- pal$natural       # "#0072B2"
col_restoration <- pal$restoration   # "#D55E00"
col_overall     <- pal$slate_dark    # "#1e293b"

# Scale weight for point sizes (range 1.5 to 5)
wt_range <- range(plot_studies$weight_re_pct, na.rm = TRUE)
plot_studies <- plot_studies %>%
  mutate(
    pt_size = 1.5 + 3.5 * (weight_re_pct - wt_range[1]) / (wt_range[2] - wt_range[1])
  )

# X-axis: the forest plot portion spans 0.40 to 1.02 (survival range)
# We use coord_cartesian with clip="off" so annotations can extend outside
x_plot_min <- 0.40
x_plot_max <- 1.01

# Position for left-side study labels (in data coords, outside plot area)
x_label <- 0.39

# Position for right-side annotations (single column, outside plot area)
x_annot <- 1.035

# Build the plot
p <- ggplot() +
  # --- Prediction interval band ---
  annotate("rect",
           xmin = pi_lower, xmax = min(pi_upper, x_plot_max),
           ymin = y_overall - 0.8, ymax = y_nat_header + 0.5,
           fill = col_natural, alpha = 0.06) +

  # --- Reference line at overall pooled estimate ---
  geom_vline(xintercept = overall_surv, linetype = "dashed",
             color = "grey50", linewidth = 0.4) +

  # --- Study-level CIs (error bars) ---
  geom_segment(
    data = plot_studies,
    aes(x = surv_lower, xend = surv_upper, y = y, yend = y,
        color = group),
    linewidth = 0.5
  ) +

  # --- Study-level point estimates ---
  geom_point(
    data = plot_studies,
    aes(x = survival_rate, y = y, color = group,
        shape = tier_shape, size = pt_size)
  ) +

  # --- Natural pooled diamond ---
  annotate("polygon",
           x = c(nat_lower, nat_surv, nat_upper, nat_surv),
           y = c(y_nat_pooled, y_nat_pooled + 0.3, y_nat_pooled, y_nat_pooled - 0.3),
           fill = col_natural, color = col_natural, linewidth = 0.4) +

  # --- Restoration pooled diamond ---
  annotate("polygon",
           x = c(res_lower, res_surv, res_upper, res_surv),
           y = c(y_res_pooled, y_res_pooled + 0.3, y_res_pooled, y_res_pooled - 0.3),
           fill = col_restoration, color = col_restoration, linewidth = 0.4) +

  # --- Overall pooled diamond ---
  annotate("polygon",
           x = c(overall_lower, overall_surv, overall_upper, overall_surv),
           y = c(y_overall, y_overall + 0.35, y_overall, y_overall - 0.35),
           fill = col_overall, color = col_overall, linewidth = 0.5) +

  # --- Subgroup headers (left side, outside plot) ---
  annotate("text",
           x = x_label, y = y_nat_header,
           label = sprintf("Natural colony (k = %d)", n_nat),
           hjust = 1, fontface = "bold", size = 3.0, color = col_natural) +

  annotate("text",
           x = x_label, y = y_res_header,
           label = sprintf("Restoration fragment (k = %d)", n_res),
           hjust = 1, fontface = "bold", size = 3.0, color = col_restoration) +

  # --- Study labels (left side, outside plot) ---
  geom_text(
    data = plot_studies,
    aes(x = x_label, y = y, label = label),
    hjust = 1, size = 2.9, color = "grey20"
  ) +

  # --- Pooled estimate labels (left side) ---
  annotate("text",
           x = x_label, y = y_nat_pooled,
           label = sprintf("Pooled: %.1f%%", nat_surv * 100),
           hjust = 1, fontface = "bold.italic", size = 2.9, color = col_natural) +

  annotate("text",
           x = x_label, y = y_res_pooled,
           label = sprintf("Pooled: %.1f%%", res_surv * 100),
           hjust = 1, fontface = "bold.italic", size = 2.9, color = col_restoration) +

  annotate("text",
           x = x_label, y = y_overall,
           label = sprintf("Overall: %.1f%%", overall_surv * 100),
           hjust = 1, fontface = "bold", size = 2.7, color = col_overall) +

  # --- Right-side annotations: combined survival [CI] + N ---
  geom_text(
    data = plot_studies,
    aes(x = x_annot, y = y, label = annot_right),
    hjust = 0, size = 2.5, color = "grey30"
  ) +

  # Right-side annotations for pooled estimates
  annotate("text",
           x = x_annot, y = y_nat_pooled,
           label = sprintf("%.1f [%.1f, %.1f]",
                           nat_surv * 100, nat_lower * 100, nat_upper * 100),
           hjust = 0, size = 2.5, color = col_natural, fontface = "bold") +

  annotate("text",
           x = x_annot, y = y_res_pooled,
           label = sprintf("%.1f [%.1f, %.1f]",
                           res_surv * 100, res_lower * 100, res_upper * 100),
           hjust = 0, size = 2.5, color = col_restoration, fontface = "bold") +

  annotate("text",
           x = x_annot, y = y_overall,
           label = sprintf("%.1f [%.1f, %.1f]",
                           overall_surv * 100, overall_lower * 100, overall_upper * 100),
           hjust = 0, size = 2.5, color = col_overall, fontface = "bold") +

  # --- Column headers ---
  annotate("text",
           x = x_annot, y = y_nat_header + 0.8,
           label = "% Surv [95% CI]   N",
           hjust = 0, fontface = "bold", size = 2.7, color = "grey30") +

  annotate("text",
           x = x_label, y = y_nat_header + 0.8,
           label = "Study (Region)",
           hjust = 1, fontface = "bold", size = 2.7, color = "grey30") +

  # --- Thin horizontal separator lines for subgroups ---
  annotate("segment",
           x = x_plot_min, xend = x_plot_max,
           y = y_nat_header - 0.5, yend = y_nat_header - 0.5,
           color = "grey85", linewidth = 0.3) +

  annotate("segment",
           x = x_plot_min, xend = x_plot_max,
           y = y_res_header - 0.5, yend = y_res_header - 0.5,
           color = "grey85", linewidth = 0.3) +

  # --- Bottom heterogeneity annotation ---
  annotate("text",
           x = 0.70, y = y_overall - 1.0,
           label = sprintf(
             "I^2 = %.1f%% [%.1f%%, %.1f%%],  tau^2 = %.3f,  Q = %.1f (p < 0.001),  k = %s,  N = %s",
             i_sq, i_sq_lower, i_sq_upper, tau_sq, q_stat,
             results_list[["Number of studies (k)"]] %||% "18",
             format(as.integer(total_n), big.mark = ",")
           ),
           hjust = 0.5, size = 2.7, color = "grey40") +

  # --- Prediction interval label (below heterogeneity line) ---
  annotate("text",
           x = 0.70, y = y_overall - 1.5,
           label = sprintf("95%% prediction interval: %.1f%% to %.1f%%",
                           pi_lower * 100, pi_upper * 100),
           hjust = 0.5, size = 2.5, color = "grey50", fontface = "italic") +

  # --- Data type legend as manual annotation (bottom, centered row) ---
  # Circle = Individual data
  annotate("point", x = 0.56, y = y_overall - 2.1,
           shape = 16, size = 2.5, color = "grey40") +
  annotate("text", x = 0.575, y = y_overall - 2.1,
           label = "Individual data", hjust = 0, size = 2.0, color = "grey40") +
  # Triangle = Summary data
  annotate("point", x = 0.77, y = y_overall - 2.1,
           shape = 17, size = 2.5, color = "grey40") +
  annotate("text", x = 0.785, y = y_overall - 2.1,
           label = "Summary data", hjust = 0, size = 2.0, color = "grey40") +

  # --- Scales ---
  scale_x_continuous(
    name = "Annual survival probability",
    breaks = seq(0.4, 1.0, by = 0.1),
    labels = percent_format(accuracy = 1),
    expand = expansion(mult = c(0.01, 0.02))
  ) +

  scale_y_continuous(
    limits = c(y_overall - 2.5, y_nat_header + 1.2),
    expand = c(0, 0)
  ) +

  scale_color_manual(
    values = c("Natural colony" = col_natural,
               "Restoration fragment" = col_restoration),
    guide = "none"
  ) +

  scale_shape_manual(
    values = c("Individual" = 16, "Summary" = 17),
    guide = "none"
  ) +

  scale_size_identity() +

  # Use coord_cartesian with clip="off" so text annotations extend outside
  coord_cartesian(xlim = c(x_plot_min, x_plot_max), clip = "off") +

  # --- Theme ---
  theme_manuscript(base_size = 10) +
  theme(
    axis.title.y       = element_blank(),
    axis.text.y        = element_blank(),
    axis.ticks.y       = element_blank(),
    axis.line.y        = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = "grey92", linewidth = 0.3),
    legend.position    = "none",
    plot.margin        = margin(5, 52, 10, 72, "mm"),
    panel.border       = element_blank()
  )

# Add tag to forest plot
p <- p + labs(tag = "a")

# =============================================================================
# 6. PANEL B: REGIONAL SURVIVAL VARIATION
# =============================================================================

print_subheader("Building panel b: Regional survival")

library(patchwork)

# Compute regional summaries from study_effects
region_summary <- study_effects %>%
  group_by(region) %>%
  summarise(
    k_studies = n(),
    n_total_reg = sum(n_total),
    n_survived_reg = sum(n_survived),
    pooled_surv = sum(n_survived) / sum(n_total),
    .groups = "drop"
  ) %>%
  arrange(pooled_surv)

# Wilson CIs
region_summary <- region_summary %>%
  rowwise() %>%
  mutate(
    pooled_lower = wilson_ci(n_survived_reg, n_total_reg)$lower,
    pooled_upper = wilson_ci(n_survived_reg, n_total_reg)$upper
  ) %>%
  ungroup()

region_order_b <- region_summary$region
region_labels_b <- paste0(region_summary$region, " (N=",
                          trimws(format(region_summary$n_total_reg, big.mark = ",")), ")")

study_effects_b <- study_effects %>%
  mutate(region_f = factor(region, levels = region_order_b))

region_summary <- region_summary %>%
  mutate(region_f = factor(region, levels = region_order_b))

region_label_map_b <- setNames(region_labels_b, region_order_b)

# Jitter study points within regions
study_plot_b <- study_effects_b %>%
  group_by(region) %>%
  mutate(
    jitter_offset = if (n() > 1) seq(-0.22, 0.22, length.out = n()) else 0
  ) %>%
  ungroup() %>%
  mutate(
    region_num = as.numeric(region_f) + jitter_offset,
    pop_label = ifelse(population_type == "Natural colony", "Natural", "Restoration")
  )

pooled_plot_b <- region_summary %>%
  filter(k_studies >= 2) %>%
  mutate(region_num = as.numeric(region_f))

pop_colors_b <- c("Natural" = pal$natural, "Restoration" = pal$restoration)

pb <- ggplot() +
  geom_vline(xintercept = overall_surv, linetype = "dashed",
             color = pal$slate_mid, linewidth = 0.5) +
  geom_segment(data = study_plot_b,
               aes(x = surv_lower, xend = surv_upper,
                   y = region_num, yend = region_num, color = pop_label),
               linewidth = 0.4, alpha = 0.6) +
  geom_point(data = study_plot_b,
             aes(x = survival_rate, y = region_num,
                 color = pop_label, size = n_total),
             alpha = 0.85) +
  geom_point(data = pooled_plot_b,
             aes(x = pooled_surv, y = region_num),
             shape = 18, size = 4.5, color = pal$slate_dark) +
  geom_segment(data = pooled_plot_b,
               aes(x = pooled_lower, xend = pooled_upper,
                   y = region_num, yend = region_num),
               linewidth = 0.8, color = pal$slate_dark) +
  scale_x_continuous(
    name = "Annual survival rate",
    limits = c(0.40, 1.0),
    breaks = seq(0.4, 1.0, 0.1),
    labels = scales::percent_format(accuracy = 1)
  ) +
  scale_y_continuous(
    name = NULL,
    breaks = seq_along(region_order_b),
    labels = region_label_map_b[region_order_b],
    expand = expansion(mult = c(0.06, 0.10))
  ) +
  scale_color_manual(name = "Population type", values = pop_colors_b,
                     guide = guide_legend(override.aes = list(size = 3, alpha = 1))) +
  scale_size_continuous(name = "Sample size (n)", range = c(1.5, 5.5),
                        breaks = c(50, 500, 2000), labels = scales::comma) +
  annotate("text", x = overall_surv + 0.015, y = length(region_order_b) + 0.6,
           label = sprintf("Overall pooled: %.1f%%", overall_surv * 100),
           hjust = 0, vjust = 0.5, size = 2.8, color = pal$slate_mid, fontface = "italic") +
  labs(tag = "b") +
  theme_manuscript(base_size = 10) +
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
# 7. COMBINE AND SAVE
# =============================================================================

print_subheader("Combining panels and saving")

fig3 <- p / pb +
  plot_layout(heights = c(1.4, 1), guides = "collect") &
  theme(legend.position = "bottom")

save_manuscript_fig(
  plot = fig3,
  filename = "Fig3_caribbean_synthesis",
  width_mm = 174,
  height_mm = 260,
  fig_dir = fig_dir
)

print_success("Figure 3 (Caribbean synthesis) complete!")
cat(sprintf("  Output: %s/Fig3_caribbean_synthesis.{png,pdf}\n", fig_dir))
