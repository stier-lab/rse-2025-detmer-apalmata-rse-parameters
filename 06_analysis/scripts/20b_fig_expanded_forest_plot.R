#!/usr/bin/env Rscript
# =============================================================================
# FIGURE 3: CARIBBEAN SURVIVAL SYNTHESIS (2-panel: a=forest, b=regional)
# =============================================================================
#
# PURPOSE: Generate Figure 3 for the manuscript -- forest plot of Caribbean-wide
#          annual survival from the expanded meta-analysis (k=17, 22 effects).
#
# LAYOUT STRATEGY (Option A rebuild, 2026-04-17):
#   Panel a is a 3-column patchwork: left text (study labels), centre forest
#   (points + CIs + diamonds + reference line), right text (% [CI]  N).
#   This eliminates the annotate("text") + extreme plot.margin hack that was
#   crashing labels into the plot area when stacked with panel b.
#   Panel b is a standard ggplot with normal margins -- no more collapsed bars.
#
# INPUT:
#   06_analysis/output/expanded_meta_analysis_study_effects.csv
#   06_analysis/output/expanded_meta_analysis_results.csv
#   06_analysis/output/expanded_meta_analysis_stratified.csv
#
# OUTPUT:
#   06_analysis/figures/manuscript/Fig3_caribbean_synthesis.{png,pdf}
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(scales)
  library(patchwork)
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
results_list <- setNames(results$value, results$statistic)

stratified <- read_csv(
  file.path(output_dir, "expanded_meta_analysis_stratified.csv"),
  show_col_types = FALSE
)

# =============================================================================
# 2. PREPARE STUDY DATA
# =============================================================================

print_subheader("Preparing study-level data")

name_map <- c(
  "NOAA_survey"                = "NOAA NCRMP",
  "neely_et_al_2022"           = "Neely et al. 2022",
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
    # Normalize region spellings (USVI -> US Virgin Islands)
    region = ifelse(region == "USVI", "US Virgin Islands", region),
    # Short region abbreviation for forest labels (saves horizontal space)
    region_short = case_when(
      region == "US Virgin Islands"     ~ "USVI",
      region == "British Virgin Islands" ~ "BVI",
      region == "Dominican Republic"    ~ "Dom. Rep.",
      TRUE ~ region
    ),
    clean_name = ifelse(study %in% names(name_map), name_map[study], study),
    label = paste0(clean_name, " (", region_short, ")"),
    tier_shape = ifelse(grepl("Tier 1", data_tier), "Individual", "Summary"),
    annot_right = sprintf("%.1f [%.1f, %.1f]  %s",
                          survival_rate * 100, surv_lower * 100, surv_upper * 100,
                          format(n_total, big.mark = ","))
  )

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

overall_surv  <- as.numeric(results_list[["Pooled survival (RE)"]])
overall_lower <- as.numeric(results_list[["95% CI lower"]])
overall_upper <- as.numeric(results_list[["95% CI upper"]])
pi_lower      <- as.numeric(results_list[["95% PI lower"]])
pi_upper      <- as.numeric(results_list[["95% PI upper"]])
i_sq          <- as.numeric(results_list[["I^2 (%) [independent model]"]] %||% results_list[["I^2 (%)"]])
i_sq_lower    <- as.numeric(results_list[["I^2 CI lower"]])
i_sq_upper    <- as.numeric(results_list[["I^2 CI upper"]])
tau_sq        <- as.numeric(results_list[["tau^2 (total)"]] %||% results_list[["tau^2"]])
q_stat        <- as.numeric(results_list[["Cochran's Q"]])
total_n       <- as.numeric(results_list[["Total observations (N)"]])

stopifnot(!is.na(overall_surv), !is.na(overall_lower), !is.na(overall_upper),
          !is.na(i_sq), !is.na(tau_sq))

nat_row <- stratified %>% filter(population_type == "Natural colony")
res_row <- stratified %>% filter(population_type == "Restoration fragment")

nat_surv  <- nat_row$pooled_survival
nat_lower <- nat_row$ci_lower
nat_upper <- nat_row$ci_upper

res_surv  <- res_row$pooled_survival
res_lower <- res_row$ci_lower
res_upper <- res_row$ci_upper

# =============================================================================
# 4. BUILD Y-POSITIONS
# =============================================================================

n_nat <- nrow(natural_studies)
n_res <- nrow(restoration_studies)

# Top-down layout: higher y = higher on plot
# Row budget:
#   natural header (1) + nat studies (n_nat) + nat pooled (1) + gap (1) +
#   restoration header (1) + res studies (n_res) + res pooled (1) + gap (1) +
#   overall pooled (1) + heterogeneity line (1.5)

y_top <- n_nat + n_res + 6  # top row

y_nat_header   <- y_top
y_nat_studies  <- seq(y_top - 1, y_top - n_nat, by = -1)
y_nat_pooled   <- y_top - n_nat - 1

y_res_header   <- y_nat_pooled - 1.5
y_res_studies  <- seq(y_res_header - 1, y_res_header - n_res, by = -1)
y_res_pooled   <- y_res_header - n_res - 1

y_overall      <- y_res_pooled - 1.5
y_heterogen    <- y_overall - 1.3
y_pi           <- y_overall - 2.2
y_legend       <- y_overall - 3.4

y_min <- y_legend - 1.0
y_max <- y_nat_header + 0.8

plot_studies <- bind_rows(
  natural_studies %>%
    mutate(y = y_nat_studies, group = "Natural colony"),
  restoration_studies %>%
    mutate(y = y_res_studies, group = "Restoration fragment")
)

# Build the text-row data for left and right label panels
label_rows <- bind_rows(
  tibble(y = y_nat_header,
         left  = sprintf("Natural colony (k = %d)", n_nat),
         right = "",
         style = "header_nat"),
  plot_studies %>% transmute(y = y, left = label, right = annot_right, style = "study"),
  tibble(y = y_nat_pooled,
         left  = sprintf("Subtotal (natural): %.1f%%", nat_surv * 100),
         right = sprintf("%.1f [%.1f, %.1f]",
                         nat_surv * 100, nat_lower * 100, nat_upper * 100),
         style = "pooled_nat"),
  tibble(y = y_res_header,
         left  = sprintf("Restoration fragment (k = %d)", n_res),
         right = "",
         style = "header_res"),
  tibble(y = y_res_pooled,
         left  = sprintf("Subtotal (restoration): %.1f%%", res_surv * 100),
         right = sprintf("%.1f [%.1f, %.1f]",
                         res_surv * 100, res_lower * 100, res_upper * 100),
         style = "pooled_res"),
  tibble(y = y_overall,
         left  = sprintf("Overall pooled (k = %d)",
                         as.integer(results_list[["Number of studies (k)"]] %||% 17)),
         right = sprintf("%.1f [%.1f, %.1f]",
                         overall_surv * 100, overall_lower * 100, overall_upper * 100),
         style = "overall")
)

# Column header rows
col_header_y <- y_nat_header + 0.65
label_rows_full <- bind_rows(
  tibble(y = col_header_y, left = "Study (Region)",
         right = "% Surv [95% CI]   N", style = "col_header"),
  label_rows
)

# =============================================================================
# 5. BUILD PANEL A (3 subplots): LEFT TEXT + FOREST + RIGHT TEXT
# =============================================================================

print_subheader("Building panel a: forest plot (3-column layout)")

col_natural     <- pal$natural       # "#0072B2"
col_restoration <- pal$restoration   # "#D55E00"
col_overall     <- pal$slate_dark    # "#1e293b"

# Style dispatcher for left/right text fontface and color
style_map <- function(style) {
  list(
    header_nat = list(face = "bold", color = col_natural,     size = 2.9),
    header_res = list(face = "bold", color = col_restoration, size = 2.9),
    study      = list(face = "plain", color = "grey20",        size = 2.6),
    pooled_nat = list(face = "bold.italic", color = col_natural,     size = 2.7),
    pooled_res = list(face = "bold.italic", color = col_restoration, size = 2.7),
    overall    = list(face = "bold", color = col_overall,      size = 2.8),
    col_header = list(face = "bold", color = "grey30",         size = 2.6)
  )[[style]]
}

label_rows_full <- label_rows_full %>%
  rowwise() %>%
  mutate(
    fontface  = style_map(style)$face,
    col       = style_map(style)$color,
    tsize     = style_map(style)$size
  ) %>%
  ungroup()

# --- LEFT text column ---
p_left <- ggplot(label_rows_full, aes(x = 1, y = y)) +
  geom_text(aes(label = left, color = col, fontface = fontface, size = tsize),
            hjust = 1) +
  scale_color_identity() +
  scale_size_identity() +
  scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
  scale_y_continuous(limits = c(y_min, y_max + 0.5), expand = c(0, 0)) +
  theme_void() +
  theme(plot.margin = margin(2, 1, 2, 2, "mm"))

# --- RIGHT text column ---
p_right <- ggplot(label_rows_full, aes(x = 0, y = y)) +
  geom_text(aes(label = right, color = col, fontface = fontface, size = tsize),
            hjust = 0) +
  scale_color_identity() +
  scale_size_identity() +
  scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
  scale_y_continuous(limits = c(y_min, y_max + 0.5), expand = c(0, 0)) +
  theme_void() +
  theme(plot.margin = margin(2, 2, 2, 1, "mm"))

# --- CENTRE forest plot ---
x_plot_min <- 0.35
x_plot_max <- 1.00

# Legend positions at bottom of forest
x_leg_indiv_point <- 0.50
x_leg_indiv_text  <- 0.52
x_leg_summ_point  <- 0.72
x_leg_summ_text   <- 0.74

# Scale weights to point sizes
wt_range <- range(plot_studies$weight_re_pct, na.rm = TRUE)
plot_studies <- plot_studies %>%
  mutate(
    pt_size = 1.5 + 2.8 * (weight_re_pct - wt_range[1]) / (wt_range[2] - wt_range[1])
  )

p_forest <- ggplot() +
  # Prediction interval band
  annotate("rect",
           xmin = max(pi_lower, x_plot_min), xmax = min(pi_upper, x_plot_max),
           ymin = y_overall - 0.6, ymax = y_nat_header + 0.4,
           fill = col_natural, alpha = 0.05) +
  # Reference line at overall pooled
  geom_vline(xintercept = overall_surv, linetype = "dashed",
             color = "grey60", linewidth = 0.4) +
  # Subgroup separator lines
  annotate("segment",
           x = x_plot_min, xend = x_plot_max,
           y = y_nat_header + 0.45, yend = y_nat_header + 0.45,
           color = "grey85", linewidth = 0.3) +
  annotate("segment",
           x = x_plot_min, xend = x_plot_max,
           y = y_res_header + 0.45, yend = y_res_header + 0.45,
           color = "grey85", linewidth = 0.3) +
  # Study CIs
  geom_segment(
    data = plot_studies,
    aes(x = pmax(surv_lower, x_plot_min), xend = pmin(surv_upper, x_plot_max),
        y = y, yend = y, color = group),
    linewidth = 0.5
  ) +
  # Study points
  geom_point(
    data = plot_studies,
    aes(x = survival_rate, y = y, color = group,
        shape = tier_shape, size = pt_size)
  ) +
  # Natural pooled diamond
  annotate("polygon",
           x = c(nat_lower, nat_surv, nat_upper, nat_surv),
           y = c(y_nat_pooled, y_nat_pooled + 0.30,
                 y_nat_pooled, y_nat_pooled - 0.30),
           fill = col_natural, color = col_natural, linewidth = 0.4) +
  # Restoration pooled diamond
  annotate("polygon",
           x = c(res_lower, res_surv, res_upper, res_surv),
           y = c(y_res_pooled, y_res_pooled + 0.30,
                 y_res_pooled, y_res_pooled - 0.30),
           fill = col_restoration, color = col_restoration, linewidth = 0.4) +
  # Overall pooled diamond
  annotate("polygon",
           x = c(overall_lower, overall_surv, overall_upper, overall_surv),
           y = c(y_overall, y_overall + 0.35,
                 y_overall, y_overall - 0.35),
           fill = col_overall, color = col_overall, linewidth = 0.5) +
  # Heterogeneity annotation (short, fits inside forest x-range)
  annotate("text",
           x = (x_plot_min + x_plot_max) / 2, y = y_heterogen,
           label = sprintf(
             "I^2 = %.0f%%, tau^2 = %.2f, Q = %.0f (p<0.001)",
             i_sq, tau_sq, q_stat
           ),
           hjust = 0.5, size = 2.2, color = "grey40") +
  # Prediction interval
  annotate("text",
           x = (x_plot_min + x_plot_max) / 2, y = y_pi,
           label = sprintf("95%% PI: %.0f-%.0f%% (k=%s, N=%s)",
                           pi_lower * 100, pi_upper * 100,
                           results_list[["Number of studies (k)"]] %||% "17",
                           format(as.integer(total_n), big.mark = ",")),
           hjust = 0.5, size = 2.1, color = "grey50", fontface = "italic") +
  # Data type legend
  annotate("point", x = x_leg_indiv_point, y = y_legend,
           shape = 16, size = 2.2, color = "grey40") +
  annotate("text", x = x_leg_indiv_text, y = y_legend,
           label = "Individual data", hjust = 0, size = 2.3, color = "grey40") +
  annotate("point", x = x_leg_summ_point, y = y_legend,
           shape = 17, size = 2.2, color = "grey40") +
  annotate("text", x = x_leg_summ_text, y = y_legend,
           label = "Summary data", hjust = 0, size = 2.3, color = "grey40") +
  scale_x_continuous(
    name = "Annual survival probability",
    breaks = seq(0.4, 1.0, by = 0.1),
    labels = percent_format(accuracy = 1),
    limits = c(x_plot_min, x_plot_max),
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  scale_y_continuous(
    limits = c(y_min, y_max + 0.5),
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
  theme_manuscript(base_size = 9) +
  theme(
    axis.title.y       = element_blank(),
    axis.text.y        = element_blank(),
    axis.ticks.y       = element_blank(),
    axis.line.y        = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = "grey92", linewidth = 0.3),
    panel.grid.minor   = element_blank(),
    panel.border       = element_blank(),
    plot.margin        = margin(2, 2, 2, 2, "mm"),
    axis.title.x       = element_text(size = 8, margin = margin(t = 3)),
    axis.text.x        = element_text(size = 7)
  )

# Combine panel a pieces: left text | forest | right text
# widths chosen so study labels fit without truncation at 174mm canvas
panel_a <- p_left + p_forest + p_right +
  plot_layout(widths = c(1.75, 1.55, 0.85)) +
  plot_annotation(tag_levels = list(c("a", "", "")))

# =============================================================================
# 6. PANEL B: REGIONAL SURVIVAL VARIATION
# =============================================================================

print_subheader("Building panel b: Regional survival")

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
  annotate("text", x = overall_surv + 0.01, y = length(region_order_b) + 0.55,
           label = sprintf("Overall pooled: %.1f%%", overall_surv * 100),
           hjust = 0, vjust = 0.5, size = 2.6, color = pal$slate_mid, fontface = "italic") +
  scale_x_continuous(
    name = "Annual survival rate",
    limits = c(0.40, 1.0),
    breaks = seq(0.4, 1.0, 0.1),
    labels = scales::percent_format(accuracy = 1),
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  scale_y_continuous(
    name = NULL,
    breaks = seq_along(region_order_b),
    labels = region_label_map_b[region_order_b],
    expand = expansion(mult = c(0.06, 0.12))
  ) +
  scale_color_manual(name = "Population type", values = pop_colors_b,
                     guide = guide_legend(override.aes = list(size = 3, alpha = 1))) +
  scale_size_continuous(name = "Sample size (n)", range = c(1.5, 5.0),
                        breaks = c(50, 500, 2000), labels = scales::comma) +
  labs(tag = "b") +
  theme_manuscript(base_size = 9) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = pal$grid, linewidth = 0.3),
    panel.grid.minor   = element_blank(),
    axis.ticks.y       = element_blank(),
    axis.text.y        = element_text(size = 7.5),
    axis.text.x        = element_text(size = 7.5),
    axis.title.x       = element_text(size = 8.5, margin = margin(t = 3)),
    legend.position    = "bottom",
    legend.box         = "horizontal",
    legend.margin      = margin(t = 2, b = 0),
    legend.text        = element_text(size = 7.5),
    legend.title       = element_text(size = 8),
    plot.margin        = margin(4, 4, 2, 4, "mm")
  ) +
  guides(
    color = guide_legend(order = 1, title.position = "top"),
    size  = guide_legend(order = 2, title.position = "top")
  )

# =============================================================================
# 7. COMBINE AND SAVE
# =============================================================================

print_subheader("Combining panels and saving")

# Wrap panel_a so it stacks as a single "panel" with pb below
fig3 <- wrap_elements(full = panel_a) / pb +
  plot_layout(heights = c(1.75, 1))

save_manuscript_fig(
  plot = fig3,
  filename = "Fig3_caribbean_synthesis",
  width_mm = 174,
  height_mm = 230,
  fig_dir = fig_dir
)

print_success("Figure 3 (Caribbean synthesis) complete!")
cat(sprintf("  Output: %s/Fig3_caribbean_synthesis.{png,pdf}\n", fig_dir))
