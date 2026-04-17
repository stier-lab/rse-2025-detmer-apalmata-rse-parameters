#!/usr/bin/env Rscript
################################################################################
# 36_SHRINKAGE_RETROGRESSION_SUMMARY.R
# Shrinkage and Retrogression Summary for A. palmata Demography
################################################################################
#
# PURPOSE:
#   Summarize shrinkage (negative growth / tissue loss) and retrogression
#   (transitions to smaller size classes) in a standalone, manuscript-ready
#   product.
#
# INPUTS:
#   - 06_analysis/output/prepared_growth_data.rds (individual growth data)
#   - 06_analysis/output/transition_sample_sizes.csv (transition counts, if available)
#   - 06_analysis/output/transition_matrix.rds (transition matrix object, if available)
#
# OUTPUTS:
#   - 06_analysis/output/shrinkage_retrogression_subset_summary.csv
#   - 06_analysis/output/shrinkage_retrogression_size_class_summary.csv
#   - 06_analysis/output/shrinkage_retrogression_study_summary.csv
#   - 06_analysis/output/retrogression_probability_by_size_class.csv
#   - 06_analysis/figures/supplementary/shrinkage_retrogression_summary.{png,pdf}
#
# NOTES:
#   - Shrinkage is derived from the harmonized growth metric used in the
#     prepared data (growth_metric = live tissue growth preferred, raw growth
#     otherwise).
#   - Retrogression is derived from the observed transition counts underlying
#     the existing transition-matrix workflow.
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(patchwork)
  library(scales)
  library(forcats)
})

# -----------------------------------------------------------------------------
# Project root and shared utilities
# -----------------------------------------------------------------------------
if (file.exists("05_data/standardized")) {
  project_root <- "."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
} else if (file.exists("../05_data/standardized")) {
  project_root <- ".."
} else {
  stop("Cannot find project root. Run from the project directory or scripts dir.")
}

if (file.exists(file.path(project_root, "06_analysis/scripts/utils/shared_utilities.R"))) {
  source(file.path(project_root, "06_analysis/scripts/utils/shared_utilities.R"))
} else if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
}

output_dir <- file.path(project_root, "06_analysis/output")
fig_dir <- file.path(project_root, "06_analysis/figures/supplementary")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

size_class_levels <- c("SC1", "SC2", "SC3", "SC4", "SC5")

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  36: SHRINKAGE / RETROGRESSION SUMMARY                       ║\n")
cat("║  Shrinkage, tissue loss, and observed retrogression          ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
binom_ci <- function(successes, trials) {
  if (is.na(successes) || is.na(trials) || trials == 0) {
    return(c(NA_real_, NA_real_))
  }
  bt <- binom.test(successes, trials)
  as.numeric(bt$conf.int)
}

summarise_shrinkage <- function(df, subset_name) {
  df %>%
    filter(!is.na(size_class), size_class %in% size_class_levels) %>%
    mutate(
      size_class = factor(as.character(size_class), levels = size_class_levels),
      tissue_loss_cm2_yr = if_else(growth_metric < 0, abs(growth_metric), 0)
    ) %>%
    group_by(size_class) %>%
    summarise(
      analysis_subset = subset_name,
      n_records = n(),
      n_studies = n_distinct(study),
      n_regions = n_distinct(region),
      n_shrinkage = sum(growth_metric < 0, na.rm = TRUE),
      shrinkage_frequency = n_shrinkage / n_records,
      shrinkage_ci_lower = binom_ci(n_shrinkage, n_records)[1],
      shrinkage_ci_upper = binom_ci(n_shrinkage, n_records)[2],
      mean_tissue_loss_cm2_yr = ifelse(n_shrinkage > 0,
        mean(tissue_loss_cm2_yr[growth_metric < 0], na.rm = TRUE),
        NA_real_
      ),
      median_tissue_loss_cm2_yr = ifelse(n_shrinkage > 0,
        median(tissue_loss_cm2_yr[growth_metric < 0], na.rm = TRUE),
        NA_real_
      ),
      mean_net_growth_cm2_yr = mean(growth_metric, na.rm = TRUE),
      median_net_growth_cm2_yr = median(growth_metric, na.rm = TRUE),
      pct_positive_growth = mean(growth_metric > 0, na.rm = TRUE) * 100,
      .groups = "drop"
    ) %>%
    mutate(
      shrinkage_frequency_pct = shrinkage_frequency * 100,
      size_class = as.character(size_class)
    )
}

summarise_studies <- function(df, subset_name) {
  df %>%
    filter(!is.na(growth_metric)) %>%
    group_by(study) %>%
    summarise(
      analysis_subset = subset_name,
      region = paste(sort(unique(region)), collapse = "; "),
      n_records = n(),
      n_size_classes = n_distinct(size_class),
      n_shrinkage = sum(growth_metric < 0, na.rm = TRUE),
      shrinkage_frequency = n_shrinkage / n_records,
      shrinkage_ci_lower = binom_ci(n_shrinkage, n_records)[1],
      shrinkage_ci_upper = binom_ci(n_shrinkage, n_records)[2],
      mean_tissue_loss_cm2_yr = ifelse(n_shrinkage > 0,
        mean(abs(growth_metric[growth_metric < 0]), na.rm = TRUE),
        NA_real_
      ),
      median_tissue_loss_cm2_yr = ifelse(n_shrinkage > 0,
        median(abs(growth_metric[growth_metric < 0]), na.rm = TRUE),
        NA_real_
      ),
      mean_net_growth_cm2_yr = mean(growth_metric, na.rm = TRUE),
      median_size_cm2 = median(size_cm2, na.rm = TRUE),
      mean_size_cm2 = mean(size_cm2, na.rm = TRUE),
      pct_positive_growth = mean(growth_metric > 0, na.rm = TRUE) * 100,
      pct_live_tissue_growth_source = mean(rgr_source == "growth_live_cm2_yr", na.rm = TRUE) * 100,
      .groups = "drop"
    ) %>%
    mutate(
      shrinkage_frequency_pct = shrinkage_frequency * 100
    )
}

# -----------------------------------------------------------------------------
# Load data
# -----------------------------------------------------------------------------
cat("Loading prepared data...\n")
growth_raw <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

transition_sample_sizes_file <- file.path(output_dir, "transition_sample_sizes.csv")
if (file.exists(transition_sample_sizes_file)) {
  transition_samples <- read_csv(transition_sample_sizes_file, show_col_types = FALSE)
} else {
  transition_samples <- NULL
}

transition_rds_file <- file.path(output_dir, "transition_matrix.rds")
transition_rds <- if (file.exists(transition_rds_file)) readRDS(transition_rds_file) else NULL

cat(sprintf("  Growth records available: %s\n", comma(nrow(growth_raw))))

# -----------------------------------------------------------------------------
# Define analysis subsets
# -----------------------------------------------------------------------------
growth_natural <- growth_raw
if ("population_type" %in% names(growth_natural)) {
  growth_natural <- growth_natural %>% filter(population_type == "Natural colony")
}
growth_natural <- growth_natural %>%
  filter(!is.na(growth_metric), !is.na(size_class), size_class %in% size_class_levels) %>%
  mutate(size_class = factor(as.character(size_class), levels = size_class_levels))

growth_matrix_compatible <- growth_natural %>%
  { if ("impossible_growth" %in% names(.)) filter(., !impossible_growth) else . } %>%
  { if ("time_interval_yr" %in% names(.)) filter(., time_interval_yr >= 0.5 & time_interval_yr <= 1.5) else . }

growth_all_clean <- growth_natural %>%
  { if ("impossible_growth" %in% names(.)) filter(., !impossible_growth) else . }

subset_summary <- bind_rows(
  growth_matrix_compatible %>%
    summarise(
      analysis_subset = "matrix_compatible",
      n_records = n(),
      n_studies = n_distinct(study),
      n_regions = n_distinct(region),
      n_locations = n_distinct(location),
      n_shrinkage = sum(growth_metric < 0, na.rm = TRUE),
      shrinkage_frequency = n_shrinkage / n_records,
      mean_tissue_loss_cm2_yr = ifelse(n_shrinkage > 0, mean(abs(growth_metric[growth_metric < 0]), na.rm = TRUE), NA_real_),
      median_tissue_loss_cm2_yr = ifelse(n_shrinkage > 0, median(abs(growth_metric[growth_metric < 0]), na.rm = TRUE), NA_real_),
      .groups = "drop"
    ),
  growth_all_clean %>%
    summarise(
      analysis_subset = "all_clean",
      n_records = n(),
      n_studies = n_distinct(study),
      n_regions = n_distinct(region),
      n_locations = n_distinct(location),
      n_shrinkage = sum(growth_metric < 0, na.rm = TRUE),
      shrinkage_frequency = n_shrinkage / n_records,
      mean_tissue_loss_cm2_yr = ifelse(n_shrinkage > 0, mean(abs(growth_metric[growth_metric < 0]), na.rm = TRUE), NA_real_),
      median_tissue_loss_cm2_yr = ifelse(n_shrinkage > 0, median(abs(growth_metric[growth_metric < 0]), na.rm = TRUE), NA_real_),
      .groups = "drop"
    )
) %>%
  mutate(
    shrinkage_frequency_pct = shrinkage_frequency * 100,
    shrinkage_ci_lower = ifelse(analysis_subset == "matrix_compatible", binom_ci(n_shrinkage[analysis_subset == "matrix_compatible"], n_records[analysis_subset == "matrix_compatible"])[1], binom_ci(n_shrinkage[analysis_subset == "all_clean"], n_records[analysis_subset == "all_clean"])[1]),
    shrinkage_ci_upper = ifelse(analysis_subset == "matrix_compatible", binom_ci(n_shrinkage[analysis_subset == "matrix_compatible"], n_records[analysis_subset == "matrix_compatible"])[2], binom_ci(n_shrinkage[analysis_subset == "all_clean"], n_records[analysis_subset == "all_clean"])[2])
  )

# -----------------------------------------------------------------------------
# Summaries
# -----------------------------------------------------------------------------
size_class_summary <- bind_rows(
  summarise_shrinkage(growth_matrix_compatible, "matrix_compatible"),
  summarise_shrinkage(growth_all_clean, "all_clean")
) %>%
  arrange(analysis_subset, size_class)

study_summary <- bind_rows(
  summarise_studies(growth_matrix_compatible, "matrix_compatible"),
  summarise_studies(growth_all_clean, "all_clean")
) %>%
  arrange(analysis_subset, desc(shrinkage_frequency), study)

# -----------------------------------------------------------------------------
# Retrogression probabilities from observed transitions
# -----------------------------------------------------------------------------
if (is.null(transition_samples)) {
  stop("transition_sample_sizes.csv is required for retrogression probabilities.")
}

retrogression_summary <- transition_samples %>%
  mutate(
    from_class = factor(from_class, levels = size_class_levels),
    to_class = factor(to_class, levels = size_class_levels)
  ) %>%
  group_by(from_class) %>%
  summarise(
    n_transitions = sum(n_observations, na.rm = TRUE),
    retrogression_n = sum(n_observations[as.integer(to_class) < as.integer(from_class)], na.rm = TRUE),
    stasis_n = sum(n_observations[to_class == from_class], na.rm = TRUE),
    growth_n = sum(n_observations[as.integer(to_class) > as.integer(from_class)], na.rm = TRUE),
    retrogression_probability = retrogression_n / n_transitions,
    stasis_probability = stasis_n / n_transitions,
    growth_probability = growth_n / n_transitions,
    retrogression_among_nonstasis = ifelse(n_transitions - stasis_n > 0,
      retrogression_n / (n_transitions - stasis_n),
      NA_real_
    ),
    .groups = "drop"
  ) %>%
  mutate(
    from_class = as.character(from_class),
    retrogression_probability_pct = retrogression_probability * 100,
    stasis_probability_pct = stasis_probability * 100,
    growth_probability_pct = growth_probability * 100
  )

transition_cell_summary <- transition_samples %>%
  mutate(
    from_class = factor(from_class, levels = size_class_levels),
    to_class = factor(to_class, levels = size_class_levels),
    transition_state = case_when(
      as.integer(to_class) < as.integer(from_class) ~ "Retrogression",
      to_class == from_class ~ "Stasis",
      as.integer(to_class) > as.integer(from_class) ~ "Growth",
      TRUE ~ NA_character_
    )
  ) %>%
  group_by(from_class, transition_state) %>%
  summarise(
    n_observations = sum(n_observations, na.rm = TRUE),
    transition_prob = sum(transition_prob * n_observations, na.rm = TRUE) / sum(n_observations, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(from_class = as.character(from_class))

# -----------------------------------------------------------------------------
# Write outputs
# -----------------------------------------------------------------------------
subset_file <- file.path(output_dir, "shrinkage_retrogression_subset_summary.csv")
size_file <- file.path(output_dir, "shrinkage_retrogression_size_class_summary.csv")
study_file <- file.path(output_dir, "shrinkage_retrogression_study_summary.csv")
retro_file <- file.path(output_dir, "retrogression_probability_by_size_class.csv")
cell_file <- file.path(output_dir, "shrinkage_retrogression_transition_components.csv")

write_csv(subset_summary, subset_file)
write_csv(size_class_summary, size_file)
write_csv(study_summary, study_file)
write_csv(retrogression_summary, retro_file)
write_csv(transition_cell_summary, cell_file)

# -----------------------------------------------------------------------------
# Figure
# -----------------------------------------------------------------------------
plot_size <- size_class_summary %>%
  filter(analysis_subset == "matrix_compatible") %>%
  mutate(size_class = factor(size_class, levels = size_class_levels))

# Humanize raw snake_case study names for display in Panel D
humanize_study <- function(x) {
  dplyr::recode(x,
    "NOAA_survey"              = "NOAA survey",
    "neely_et_al_2022"         = "Neely et al. 2022",
    "fundemar_fragments"       = "FUNDEMAR fragments",
    "mendoza_quiroz_et_al_2023" = "Mendoza-Quiroz et al. 2023",
    "pausch_et_al_2018"        = "Pausch et al. 2018",
    "kuffner_et_al_2020"       = "Kuffner et al. 2020",
    "USGS_USVI_exp"            = "USGS USVI",
    .default = x
  )
}

plot_studies <- study_summary %>%
  filter(analysis_subset == "matrix_compatible") %>%
  mutate(
    study_label = humanize_study(study),
    study_label = fct_reorder(study_label, shrinkage_frequency)
  )

plot_transitions <- transition_cell_summary %>%
  mutate(
    from_class = factor(from_class, levels = size_class_levels),
    transition_state = factor(transition_state, levels = c("Retrogression", "Stasis", "Growth"))
  )

pal <- if (exists("MANUSCRIPT_PALETTE")) MANUSCRIPT_PALETTE else list(
  surv_dark = "#0a3d62",
  grow_dark = "#004d40",
  slate_mid = "#6C757D",
  natural = "#1F78B4",
  restoration = "#E67E22"
)

p_a <- ggplot(plot_size, aes(x = size_class, y = shrinkage_frequency_pct)) +
  geom_col(fill = pal$surv_dark, width = 0.72) +
  geom_text(aes(label = sprintf("%.1f%%", shrinkage_frequency_pct)),
            vjust = -0.4, size = 2.6, color = "grey20") +
  scale_y_continuous(labels = label_number(suffix = "%"),
                     expand = expansion(mult = c(0, 0.14))) +
  labs(x = NULL, y = "Shrinkage frequency") +
  theme_manuscript(base_size = 9) +
  theme(plot.margin = margin(3, 4, 3, 4, "mm"))

p_b <- ggplot(plot_size, aes(x = size_class, y = mean_tissue_loss_cm2_yr)) +
  geom_col(fill = pal$grow_dark, width = 0.72) +
  geom_text(aes(label = ifelse(is.na(mean_tissue_loss_cm2_yr), "",
                               comma(round(mean_tissue_loss_cm2_yr, 0)))),
            vjust = -0.4, size = 2.6, color = "grey20") +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.14))) +
  labs(x = NULL, y = expression(paste("Mean tissue loss (cm"^2, " yr"^-1, ")"))) +
  theme_manuscript(base_size = 9) +
  theme(plot.margin = margin(3, 4, 3, 4, "mm"))

# Panel c: retrogression percentage placed INSIDE the retrogression segment
# (top of stack) to avoid the overlapping mess above the bars. For classes
# where the retrogression slice is too small, label is omitted (NA).
retro_labels <- retrogression_summary %>%
  mutate(
    from_class = factor(from_class, levels = size_class_levels),
    # position label inside retrogression segment (top portion of bar)
    label_y = 1 - (retrogression_probability / 2),
    label   = ifelse(retrogression_probability >= 0.03,
                     sprintf("%.1f%%", retrogression_probability_pct),
                     NA_character_)
  )

p_c <- ggplot(plot_transitions, aes(x = from_class, y = transition_prob,
                                     fill = transition_state)) +
  geom_col(width = 0.72, color = "white", linewidth = 0.3) +
  geom_text(
    data = retro_labels,
    aes(x = from_class, y = label_y, label = label),
    inherit.aes = FALSE,
    size = 2.4, color = "white", fontface = "bold",
    na.rm = TRUE
  ) +
  scale_y_continuous(labels = label_percent(accuracy = 1),
                     limits = c(0, 1.001),
                     expand = expansion(mult = c(0, 0.02))) +
  scale_fill_manual(
    values = c(
      "Retrogression" = pal$restoration,
      "Stasis"        = pal$slate_mid,
      "Growth"        = pal$surv_dark
    ),
    name = "Transition"
  ) +
  labs(x = "From size class", y = "Transition probability") +
  theme_manuscript(base_size = 9) +
  theme(
    plot.margin = margin(3, 4, 3, 4, "mm"),
    legend.position = "bottom",
    legend.key.size = unit(3.5, "mm")
  )

p_d <- ggplot(plot_studies, aes(x = shrinkage_frequency_pct, y = study_label)) +
  geom_segment(aes(x = 0, xend = shrinkage_frequency_pct,
                   y = study_label, yend = study_label),
               linewidth = 0.6, color = "grey80") +
  geom_point(aes(size = n_records, color = mean_tissue_loss_cm2_yr)) +
  geom_text(aes(label = sprintf("%.1f%%", shrinkage_frequency_pct)),
            hjust = -0.25, size = 2.4, color = "grey20") +
  scale_x_continuous(labels = label_number(suffix = "%"),
                     expand = expansion(mult = c(0, 0.32)),
                     breaks = c(0, 20, 40)) +
  scale_size_continuous(name = "Records",
                        range = c(2.5, 5.5),
                        breaks = c(500, 1500),
                        guide = guide_legend(order = 2,
                                             title.position = "top",
                                             title.hjust = 0,
                                             nrow = 1,
                                             override.aes = list(color = "grey40"))) +
  scale_color_gradient(
    low = pal$natural,
    high = pal$restoration,
    name = expression(paste("Mean loss (cm"^2, " yr"^-1, ")")),
    guide = guide_colorbar(barwidth = unit(22, "mm"),
                           barheight = unit(2.5, "mm"),
                           title.position = "top",
                           title.hjust = 0,
                           order = 1)
  ) +
  labs(x = "Shrinkage frequency", y = NULL) +
  theme_manuscript(base_size = 9) +
  theme(
    plot.margin      = margin(3, 4, 3, 4, "mm"),
    legend.position  = "bottom",
    legend.box       = "horizontal",
    legend.spacing.x = unit(3, "mm"),
    legend.title     = element_text(size = 7),
    legend.text      = element_text(size = 7),
    legend.margin    = margin(t = 0, r = 0, b = 0, l = 0),
    legend.box.margin = margin(t = -4, r = 0, b = 0, l = 0)
  )

figure <- (p_a | p_b) / (p_c | p_d) +
  plot_layout(heights = c(1, 1.15)) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(face = "bold", size = 10,
                                 color = MANUSCRIPT_PALETTE$slate_dark))

png_file <- file.path(fig_dir, "FigS16_shrinkage_retrogression_summary.png")
pdf_file <- file.path(fig_dir, "FigS16_shrinkage_retrogression_summary.pdf")

ggsave(png_file, figure, width = 174, height = 170, units = "mm",
       dpi = 320, bg = "white")
pdf_device <- if (capabilities("cairo")) grDevices::cairo_pdf else "pdf"
ggsave(pdf_file, figure, width = 174, height = 170, units = "mm",
       device = pdf_device, bg = "white")

# -----------------------------------------------------------------------------
# Console summary
# -----------------------------------------------------------------------------
cat("\nSaved outputs:\n")
cat(sprintf("  - %s\n", basename(subset_file)))
cat(sprintf("  - %s\n", basename(size_file)))
cat(sprintf("  - %s\n", basename(study_file)))
cat(sprintf("  - %s\n", basename(retro_file)))
cat(sprintf("  - %s\n", basename(cell_file)))
cat(sprintf("  - %s\n", basename(png_file)))
cat(sprintf("  - %s\n", basename(pdf_file)))

cat("\nKey results:\n")
cat(sprintf(
  "  Matrix-compatible shrinkage frequency: %.1f%% across %d records from %d studies\n",
  subset_summary$shrinkage_frequency_pct[subset_summary$analysis_subset == "matrix_compatible"],
  subset_summary$n_records[subset_summary$analysis_subset == "matrix_compatible"],
  subset_summary$n_studies[subset_summary$analysis_subset == "matrix_compatible"]
))
cat(sprintf(
  "  All-clean shrinkage frequency: %.1f%% across %d records from %d studies\n",
  subset_summary$shrinkage_frequency_pct[subset_summary$analysis_subset == "all_clean"],
  subset_summary$n_records[subset_summary$analysis_subset == "all_clean"],
  subset_summary$n_studies[subset_summary$analysis_subset == "all_clean"]
))
cat(sprintf(
  "  Retrogression probabilities: SC2 %.1f%%, SC3 %.1f%%, SC4 %.1f%%, SC5 %.1f%%\n",
  retrogression_summary$retrogression_probability_pct[retrogression_summary$from_class == "SC2"],
  retrogression_summary$retrogression_probability_pct[retrogression_summary$from_class == "SC3"],
  retrogression_summary$retrogression_probability_pct[retrogression_summary$from_class == "SC4"],
  retrogression_summary$retrogression_probability_pct[retrogression_summary$from_class == "SC5"]
))

cat("\nDone.\n")
