#!/usr/bin/env Rscript
################################################################################
# 39_RESTORATION_SUBTYPE_SENSITIVITY.R
# Restoration subtype decomposition for Acropora palmata demography
################################################################################
#
# PURPOSE:
#   Replace the broad "restoration fragment" bucket with a reproducible subtype
#   mapping and subtype-level sensitivity summaries.
#
# OUTPUTS:
#   - 05_data/standardized/restoration_subtype_mapping.csv
#   - 06_analysis/output/restoration_subtype_study_summary.csv
#   - 06_analysis/output/restoration_subtype_survival_summary.csv
#   - 06_analysis/output/restoration_subtype_growth_summary.csv
#   - 06_analysis/output/restoration_subtype_sensitivity.csv
#   - 06_analysis/figures/supplementary/restoration_subtype_sensitivity.{png,pdf}
#
# Author: Codex
# Date: 2026-04-03
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(patchwork)
  library(scales)
  library(tidyr)
})

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

project_root <- if (file.exists("05_data/standardized")) {
  "."
} else if (file.exists("../../05_data/standardized")) {
  "../.."
} else {
  stop("Cannot find project root. Run from project directory or 06_analysis/scripts/")
}

output_dir <- file.path(project_root, "06_analysis/output")
fig_dir <- file.path(project_root, "06_analysis/figures/supplementary")
std_dir <- file.path(project_root, "05_data/standardized")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(std_dir, showWarnings = FALSE, recursive = TRUE)

cat("\n")
cat("================================================================\n")
cat("  RESTORATION SUBTYPE SENSITIVITY\n")
cat("================================================================\n\n")

build_restoration_subtype_map <- function() {
  tibble::tribble(
    ~study, ~restoration_subtype, ~subtype_label, ~rule, ~evidence, ~confidence,
    "NOAA_survey", "natural_fragment", "Naturally occurring fragments",
    "NOAA natural survey fragments (fragment == 'Y'); not restoration outplants",
    "Wild / naturally occurring fragments retained in the NOAA survey surface.",
    "medium",

    "pausch_et_al_2018", "nursery_outplant", "Nursery outplants",
    "Nursery-cultured fragments outplanted to reef habitat",
    "Outplanted nursery-cultured fragments; size x genet and habitat x genet experiments.",
    "high",

    "USGS_USVI_exp", "outplanted_colony", "Outplanted colonies",
    "Tagged outplanted colonies tracked in the USGS USVI experiment",
    "Tagged outplanted colonies; source material not described as nursery fragments in the metadata.",
    "medium",

    "kuffner_et_al_2020", "nursery_outplant_recemented", "Nursery outplants after fragmentation / re-cementation",
    "Nursery-raised fragments outplanted after fragmentation and re-cementation",
    "Nursery-raised fragments outplanted spring 2018; survival after fragmentation and re-cementation.",
    "high",

    "fundemar_fragments", "nursery_outplant", "Nursery outplants",
    "Nursery fragments on PVC tables in a restoration nursery",
    "Direct restoration nursery fragments shared by FUNDEMAR.",
    "high"
  ) %>%
    arrange(match(study, c(
      "NOAA_survey",
      "pausch_et_al_2018",
      "USGS_USVI_exp",
      "kuffner_et_al_2020",
      "fundemar_fragments"
    )))
}

restore_mapping <- build_restoration_subtype_map()
write_csv(restore_mapping, file.path(std_dir, "restoration_subtype_mapping.csv"))

assign_restoration_subtype <- function(df, map_tbl) {
  df %>%
    left_join(map_tbl, by = "study") %>%
    mutate(
      restoration_subtype = coalesce(restoration_subtype, "unknown"),
      subtype_label = coalesce(subtype_label, "Unknown"),
      rule = coalesce(rule, "Unmapped study"),
      evidence = coalesce(evidence, "No subtype mapping available"),
      confidence = coalesce(confidence, "low")
    )
}

safe_weighted_mean <- function(x, w) {
  keep <- !is.na(x) & !is.na(w)
  if (!any(keep)) return(NA_real_)
  stats::weighted.mean(x[keep], w[keep])
}

bootstrap_weighted_mean <- function(df, value_col, weight_col = "n", B = 1000, seed = 39) {
  set.seed(seed)
  if (nrow(df) == 0) {
    return(tibble::tibble(mean = NA_real_, ci_lower = NA_real_, ci_upper = NA_real_))
  }
  vals <- df[[value_col]]
  w <- df[[weight_col]]
  if (nrow(df) == 1) {
    est <- safe_weighted_mean(vals, w)
    return(tibble::tibble(mean = est, ci_lower = est, ci_upper = est))
  }
  boot <- replicate(B, {
    idx <- sample(seq_len(nrow(df)), replace = TRUE)
    safe_weighted_mean(vals[idx], w[idx])
  })
  est <- safe_weighted_mean(vals, w)
  tibble::tibble(
    mean = est,
    ci_lower = stats::quantile(boot, 0.025, na.rm = TRUE, names = FALSE),
    ci_upper = stats::quantile(boot, 0.975, na.rm = TRUE, names = FALSE)
  )
}

load_survival_data <- function() {
  readRDS(file.path(output_dir, "prepared_survival_data.rds"))
}

load_growth_data <- function() {
  readRDS(file.path(output_dir, "prepared_growth_data.rds"))
}

surv_data <- load_survival_data()
growth_data <- load_growth_data()

surv_rest <- surv_data %>%
  filter(fragment == "Y" | population_type == "Restoration fragment" | study %in% restore_mapping$study) %>%
  assign_restoration_subtype(restore_mapping)

growth_rest <- growth_data %>%
  filter(
    fragment == "Y" | study %in% restore_mapping$study |
      ("population_type" %in% names(growth_data) && population_type == "Restoration fragment")
  ) %>%
  assign_restoration_subtype(restore_mapping)

unknown_survival <- sum(surv_rest$restoration_subtype == "unknown", na.rm = TRUE)
unknown_growth <- sum(growth_rest$restoration_subtype == "unknown", na.rm = TRUE)

if (unknown_survival > 0 || unknown_growth > 0) {
  cat(sprintf("  WARNING: unmapped restoration rows detected (survival=%d, growth=%d)\n",
              unknown_survival, unknown_growth))
}

surv_study_summary <- surv_rest %>%
  group_by(restoration_subtype, subtype_label, study, region) %>%
  summarise(
    n = n(),
    mean_survival = mean(surv_annualized, na.rm = TRUE),
    mean_size_cm2 = mean(size_live_cm2, na.rm = TRUE),
    baseline_excluded = sum(exclude_from_baseline, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(restoration_subtype, study, region)

growth_study_summary <- growth_rest %>%
  group_by(restoration_subtype, subtype_label, study, region) %>%
  summarise(
    n = n(),
    mean_growth_cm2_yr = mean(growth_cm2_yr, na.rm = TRUE),
    mean_rgr = mean(rgr, na.rm = TRUE),
    pct_positive = mean(growth_cm2_yr > 0, na.rm = TRUE) * 100,
    mean_size_cm2 = mean(size_live_cm2, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(restoration_subtype, study, region)

surv_summary <- surv_study_summary %>%
  group_by(restoration_subtype, subtype_label) %>%
  group_modify(~{
    boot <- bootstrap_weighted_mean(.x, "mean_survival", "n")
    tibble::tibble(
      n_records = sum(.x$n),
      n_studies = n_distinct(.x$study),
      n_regions = n_distinct(.x$region),
      weighted_survival = boot$mean,
      ci_lower = boot$ci_lower,
      ci_upper = boot$ci_upper,
      mean_of_study_means = mean(.x$mean_survival, na.rm = TRUE),
      median_of_study_means = median(.x$mean_survival, na.rm = TRUE),
      weighted_mean_size_cm2 = safe_weighted_mean(.x$mean_size_cm2, .x$n),
      baseline_excluded = sum(.x$baseline_excluded, na.rm = TRUE)
    )
  }) %>%
  ungroup() %>%
  arrange(desc(n_records))

growth_summary <- growth_study_summary %>%
  group_by(restoration_subtype, subtype_label) %>%
  summarise(
    n_records = sum(n),
    n_studies = n_distinct(study),
    n_regions = n_distinct(region),
    weighted_mean_growth_cm2_yr = safe_weighted_mean(mean_growth_cm2_yr, n),
    weighted_mean_rgr = safe_weighted_mean(mean_rgr, n),
    weighted_pct_positive = safe_weighted_mean(pct_positive, n),
    mean_of_study_means = mean(mean_growth_cm2_yr, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(n_records))

write_csv(surv_study_summary, file.path(output_dir, "restoration_subtype_study_summary.csv"))
write_csv(surv_summary, file.path(output_dir, "restoration_subtype_survival_summary.csv"))
write_csv(growth_summary, file.path(output_dir, "restoration_subtype_growth_summary.csv"))

scenario_summary <- function(df, scenario_name) {
  study_level <- df %>%
    group_by(study, restoration_subtype, subtype_label) %>%
    summarise(
      n = n(),
      surv = mean(surv_annualized, na.rm = TRUE),
      .groups = "drop"
    )

  tibble::tibble(
    scenario = scenario_name,
    n_records = nrow(df),
    n_studies = n_distinct(df$study),
    mean_survival = safe_weighted_mean(study_level$surv, study_level$n)
  )
}

surv_sensitivity <- bind_rows(
  scenario_summary(surv_rest, "All subtype-coded records"),
  scenario_summary(filter(surv_rest, restoration_subtype != "natural_fragment"), "Exclude natural fragments"),
  scenario_summary(filter(surv_rest, restoration_subtype %in% c("nursery_outplant", "nursery_outplant_recemented")), "Nursery outplants only"),
  scenario_summary(filter(surv_rest, restoration_subtype %in% c("nursery_outplant", "nursery_outplant_recemented", "outplanted_colony")), "All restoration subtypes"),
  scenario_summary(filter(surv_rest, restoration_subtype == "outplanted_colony"), "Outplanted colonies only")
)

write_csv(surv_sensitivity, file.path(output_dir, "restoration_subtype_sensitivity.csv"))

plot_survival <- surv_summary %>%
  mutate(subtype_label = factor(subtype_label, levels = subtype_label[order(n_records)]))

plot_growth <- growth_summary %>%
  mutate(subtype_label = factor(subtype_label, levels = unique(plot_survival$subtype_label)))

surv_points <- surv_study_summary %>%
  mutate(subtype_label = factor(subtype_label, levels = levels(plot_survival$subtype_label)))

growth_points <- growth_study_summary %>%
  mutate(subtype_label = factor(subtype_label, levels = levels(plot_survival$subtype_label)))

p_surv <- ggplot() +
  geom_segment(
    data = plot_survival,
    aes(x = weighted_survival, xend = weighted_survival, y = subtype_label, yend = subtype_label),
    linewidth = 3.2,
    color = "#1F4E79"
  ) +
  geom_segment(
    data = plot_survival,
    aes(x = ci_lower, xend = ci_upper, y = subtype_label, yend = subtype_label),
    linewidth = 1.0,
    color = "#1F4E79"
  ) +
  geom_point(
    data = surv_points,
    aes(x = mean_survival, y = subtype_label, size = n),
    shape = 21,
    fill = "white",
    color = "#D95F02",
    stroke = 0.8,
    alpha = 0.9,
    position = position_jitter(height = 0.08, width = 0)
  ) +
  scale_size_continuous(name = "Study-level n", range = c(1.5, 5)) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1)) +
  labs(
    title = "Restoration subtype survival comparison",
    subtitle = "Points are study-level means; bars show bootstrap-weighted subtype means",
    x = "Annual survival",
    y = NULL
  ) +
  theme_manuscript() +
  theme(legend.position = "bottom")

p_growth <- ggplot() +
  geom_segment(
    data = plot_growth,
    aes(x = weighted_mean_rgr, xend = weighted_mean_rgr, y = subtype_label, yend = subtype_label),
    linewidth = 3.2,
    color = "#2C7FB8"
  ) +
  geom_point(
    data = growth_points,
    aes(x = mean_rgr, y = subtype_label, size = n),
    shape = 21,
    fill = "white",
    color = "#238B45",
    stroke = 0.8,
    alpha = 0.9,
    position = position_jitter(height = 0.08, width = 0)
  ) +
  scale_size_continuous(name = "Study-level n", range = c(1.5, 5)) +
  labs(
    title = "Restoration subtype relative growth comparison",
    subtitle = "Study-level means of relative growth rate (RGR)",
    x = "Mean RGR (yr^-1)",
    y = NULL
  ) +
  theme_manuscript() +
  theme(legend.position = "bottom")

p <- p_surv / p_growth + plot_layout(guides = "collect")

ggsave(
  file.path(fig_dir, "FigS19_restoration_subtype_sensitivity.png"),
  p,
  width = 180,
  height = 180,
  units = "mm",
  dpi = 300
)
ggsave(
  file.path(fig_dir, "FigS19_restoration_subtype_sensitivity.pdf"),
  p,
  width = 180,
  height = 180,
  units = "mm"
)

cat("\nSubtype mapping written to:\n")
cat(sprintf("  - %s\n", file.path(std_dir, "restoration_subtype_mapping.csv")))
cat("\nSurvival summary:\n")
print(surv_summary)
cat("\nGrowth summary:\n")
print(growth_summary)
cat("\nSensitivity table:\n")
print(surv_sensitivity)

cat("\nSaved outputs:\n")
cat("  - restoration_subtype_mapping.csv\n")
cat("  - restoration_subtype_study_summary.csv\n")
cat("  - restoration_subtype_survival_summary.csv\n")
cat("  - restoration_subtype_growth_summary.csv\n")
cat("  - restoration_subtype_sensitivity.csv\n")
cat("  - restoration_subtype_sensitivity.png/pdf\n")
