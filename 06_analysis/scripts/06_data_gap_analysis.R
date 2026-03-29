#!/usr/bin/env Rscript
################################################################################
# 06_DATA_GAP_ANALYSIS.R
# A. palmata Demographic Data Gap Identification & Prioritization
################################################################################
#
# PURPOSE: Systematically identify data gaps in the A. palmata demographic
#          database and prioritize future research needs using a structured
#          Impact × Feasibility × Urgency framework
#
# FRAMEWORK:
#   - Data coverage assessment across Size × Space × Time dimensions
#   - Certainty scoring for each parameter estimate
#   - Gap prioritization for research investment
#   - Specific recommendations for monitoring/experiments
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#
# OUTPUTS:
#   - 06_analysis/output/certainty_by_size_class.csv
#   - 06_analysis/output/certainty_by_region.csv
#   - 06_analysis/output/data_gaps_identified.csv
#   - 06_analysis/output/gap_prioritization.csv
#   - 06_analysis/output/recommended_studies.csv
#   - 06_analysis/output/certainty_matrix.csv
#   - 06_analysis/output/temporal_coverage_by_region.csv
#   - 06_analysis/output/gap_summary_counts.csv
#   - 06_analysis/figures/supplementary/exploratory/certainty_heatmap.png
#   - 06_analysis/figures/supplementary/exploratory/gap_prioritization.png
#
# Author: Detmer & Stier Lab
# Date: 2025-12-22
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)

# Source shared utilities for constants and helper functions
# find_project_root() is defined here, along with SIZE_BREAKS, SIZE_LABELS, etc.
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  05: DATA GAP ANALYSIS & PRIORITIZATION                      ║\n")
cat("║  Identifying Uncertainty & Research Priorities               ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# Set paths - detect project root automatically
if (file.exists("05_data/standardized")) {
  project_root <- "."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root. Run from project directory or 06_analysis/scripts/")
}

output_dir <- file.path(project_root, "06_analysis/output")
fig_dir <- file.path(project_root, "06_analysis/figures")
fig_dir_supp_exploratory <- file.path(fig_dir, "supplementary/exploratory")
dir.create(fig_dir_supp_exploratory, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# 1. LOAD DATA
# ==============================================================================

cat("Loading prepared data...\n\n")

surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

# ==============================================================================
# 2. DEFINE CERTAINTY SCORING FRAMEWORK
# ==============================================================================

cat("═══════════════════════════════════════════════════════════════\n")
cat("  CERTAINTY SCORING FRAMEWORK\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Certainty criteria (5-point scale for each):
# 1. Sample size (n)
# 2. Geographic breadth (number of regions)
# 3. Temporal breadth (years of data)
# 4. Study independence (number of studies)
# 5. Data type diversity (field vs nursery coverage)

calc_certainty_score <- function(n, n_regions, n_years, n_studies, has_field, has_nursery) {

  # Sample size score (0-5)
  n_score <- case_when(
    n < 30 ~ 1,
    n < 100 ~ 2,
    n < 300 ~ 3,
    n < 1000 ~ 4,
    TRUE ~ 5
  )

  # Geographic breadth score (0-5)
  geo_score <- case_when(
    n_regions < 2 ~ 1,
    n_regions < 3 ~ 2,
    n_regions < 4 ~ 3,
    n_regions < 5 ~ 4,
    TRUE ~ 5
  )

  # Temporal breadth score (0-5)
  time_score <- case_when(
    n_years < 2 ~ 1,
    n_years < 4 ~ 2,
    n_years < 7 ~ 3,
    n_years < 10 ~ 4,
    TRUE ~ 5
  )

  # Study independence score (0-5)
  study_score <- case_when(
    n_studies < 2 ~ 1,
    n_studies < 3 ~ 2,
    n_studies < 4 ~ 3,
    n_studies < 5 ~ 4,
    TRUE ~ 5
  )

  # Data type diversity score (0-5)
  dtype_score <- case_when(
    has_field & has_nursery ~ 5,
    has_field ~ 3,
    has_nursery ~ 2,
    TRUE ~ 1
  )

  # Total score (max 25)
  total <- n_score + geo_score + time_score + study_score + dtype_score

  # Certainty level
  level <- case_when(
    total >= 20 ~ "HIGH",
    total >= 15 ~ "MODERATE",
    total >= 10 ~ "LOW",
    TRUE ~ "VERY LOW"
  )

  return(list(
    n_score = n_score,
    geo_score = geo_score,
    time_score = time_score,
    study_score = study_score,
    dtype_score = dtype_score,
    total = total,
    level = level
  ))
}

cat("Certainty scoring criteria:\n")
cat("  1. Sample size: n<30=1, n<100=2, n<300=3, n<1000=4, n>=1000=5\n")
cat("  2. Geographic breadth: regions (1-5 scale)\n")
cat("  3. Temporal breadth: years of data (1-5 scale)\n")
cat("  4. Study independence: number of studies (1-5 scale)\n")
cat("  5. Data type coverage: field + nursery = 5, field only = 3\n")
cat("\nCertainty levels: HIGH (>=20), MODERATE (15-19), LOW (10-14), VERY LOW (<10)\n\n")

# ==============================================================================
# 3. CALCULATE CERTAINTY BY SIZE CLASS
# ==============================================================================

cat("═══════════════════════════════════════════════════════════════\n")
cat("  SIZE CLASS CERTAINTY ASSESSMENT\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

size_certainty <- surv_data %>%
  group_by(size_class) %>%
  summarise(
    n = n(),
    n_regions = n_distinct(region),
    n_years = n_distinct(survey_yr),
    n_studies = n_distinct(study),
    has_field = any(data_type == "field"),
    has_nursery = any(fragment == "Y", na.rm = TRUE),
    survival = mean(survived),
    .groups = "drop"
  )

cat("  Actual data_type levels in data:", paste(unique(surv_data$data_type), collapse=", "), "\n")

# Apply certainty scoring
size_certainty <- size_certainty %>%
  rowwise() %>%
  mutate(
    certainty = list(calc_certainty_score(n, n_regions, n_years, n_studies,
                                          has_field, has_nursery))
  ) %>%
  ungroup() %>%
  mutate(
    certainty_score = sapply(certainty, function(x) x$total),
    certainty_level = sapply(certainty, function(x) x$level)
  ) %>%
  select(-certainty)

cat("Survival certainty by size class:\n")
print(as.data.frame(size_certainty %>%
                      select(size_class, n, n_regions, n_studies, survival,
                             certainty_score, certainty_level) %>%
                      mutate(across(where(is.numeric), ~round(., 2)))))

# ==============================================================================
# 4. CALCULATE CERTAINTY BY REGION
# ==============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  REGIONAL CERTAINTY ASSESSMENT\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

region_certainty <- surv_data %>%
  group_by(region) %>%
  summarise(
    n = n(),
    n_size_classes = n_distinct(size_class),
    n_years = n_distinct(survey_yr),
    n_studies = n_distinct(study),
    has_field = any(data_type == "field"),
    has_nursery = any(fragment == "Y", na.rm = TRUE),
    survival = mean(survived),
    .groups = "drop"
  ) %>%
  mutate(
    # Simplified scoring for regions
    n_score = case_when(n < 100 ~ 1, n < 300 ~ 2, n < 500 ~ 3, n < 1000 ~ 4, TRUE ~ 5),
    size_coverage = case_when(n_size_classes < 3 ~ 1, n_size_classes < 4 ~ 2,
                              n_size_classes < 5 ~ 3, TRUE ~ 5),
    time_score = case_when(n_years < 3 ~ 1, n_years < 5 ~ 2, n_years < 8 ~ 3, TRUE ~ 5),
    certainty_score = n_score + size_coverage + time_score,
    certainty_level = case_when(
      certainty_score >= 12 ~ "HIGH",
      certainty_score >= 9 ~ "MODERATE",
      certainty_score >= 6 ~ "LOW",
      TRUE ~ "VERY LOW"
    )
  )

cat("Survival certainty by region:\n")
print(as.data.frame(region_certainty %>%
                      select(region, n, n_size_classes, n_years, n_studies,
                             certainty_score, certainty_level) %>%
                      mutate(across(where(is.numeric), ~round(., 0)))))

# ==============================================================================
# 5. IDENTIFY SPECIFIC DATA GAPS
# ==============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SPECIFIC DATA GAPS IDENTIFIED\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Size × Region coverage matrix
size_region_n <- surv_data %>%
  group_by(size_class, region) %>%
  summarise(n = n(), .groups = "drop") %>%
  complete(size_class, region, fill = list(n = 0))

# Identify gaps (n < 30 or n = 0)
gaps_identified <- size_region_n %>%
  mutate(
    gap_status = case_when(
      n == 0 ~ "NO DATA",
      n < 10 ~ "CRITICAL GAP",
      n < 30 ~ "MODERATE GAP",
      n < 100 ~ "MINOR GAP",
      TRUE ~ "ADEQUATE"
    )
  ) %>%
  filter(gap_status != "ADEQUATE")

cat("Size × Region gaps:\n")
print(as.data.frame(gaps_identified %>% arrange(n)))

# Pivot for visualization
gap_matrix <- size_region_n %>%
  mutate(gap_level = case_when(
    n == 0 ~ 0,
    n < 10 ~ 1,
    n < 30 ~ 2,
    n < 100 ~ 3,
    TRUE ~ 4
  )) %>%
  select(size_class, region, n, gap_level)

# Count gap types
cat("\nGap summary:\n")
cat(sprintf("  NO DATA cells: %d\n", sum(gap_matrix$gap_level == 0)))
cat(sprintf("  CRITICAL gaps (n<10): %d\n", sum(gap_matrix$gap_level == 1)))
cat(sprintf("  MODERATE gaps (n<30): %d\n", sum(gap_matrix$gap_level == 2)))
cat(sprintf("  MINOR gaps (n<100): %d\n", sum(gap_matrix$gap_level == 3)))
cat(sprintf("  ADEQUATE (n>=100): %d\n", sum(gap_matrix$gap_level == 4)))

# Save gap summary counts
gap_summary_counts <- data.frame(
  gap_status = c("NO DATA", "CRITICAL", "MODERATE", "MINOR", "ADEQUATE"),
  count = c(sum(gap_matrix$gap_level == 0),
            sum(gap_matrix$gap_level == 1),
            sum(gap_matrix$gap_level == 2),
            sum(gap_matrix$gap_level == 3),
            sum(gap_matrix$gap_level == 4))
)
write_csv(gap_summary_counts, file.path(output_dir, "gap_summary_counts.csv"))

# ==============================================================================
# 6. TEMPORAL GAPS
# ==============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  TEMPORAL COVERAGE GAPS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Year × Region coverage
year_region <- surv_data %>%
  group_by(survey_yr, region) %>%
  summarise(n = n(), .groups = "drop") %>%
  complete(survey_yr = min(survey_yr):max(survey_yr), region, fill = list(n = 0))

# Find years with no data
year_gaps <- year_region %>%
  group_by(region) %>%
  summarise(
    years_with_data = sum(n > 0),
    total_years = n_distinct(survey_yr),
    pct_coverage = years_with_data / total_years * 100,
    .groups = "drop"
  )

cat("Temporal coverage by region:\n")
print(as.data.frame(year_gaps))

# Save temporal coverage by region
write_csv(year_gaps, file.path(output_dir, "temporal_coverage_by_region.csv"))

# ==============================================================================
# 7. GAP PRIORITIZATION
# ==============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  GAP PRIORITIZATION (IMPACT × FEASIBILITY × URGENCY)\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Data-driven gap prioritization (replaces hardcoded scores)
# Priority score based on three dimensions:
#   1. Sample deficit: how far below adequate sample size (100 obs)
#   2. Geographic deficit: how many regions are missing data for that size class
#   3. Temporal deficit: how many years have data gaps

all_regions <- unique(surv_data$region)
all_years <- min(surv_data$survey_yr):max(surv_data$survey_yr)
n_all_regions <- length(all_regions)
n_all_years <- length(all_years)

# Build the size class x region grid with computed scores
priority_gaps <- size_region_n %>%
  group_by(size_class) %>%
  mutate(
    # 1. Sample deficit: 0 = adequate (>=100), 1 = no data
    sample_score = 1 - pmin(1, n / 100),
    # 2. Geographic deficit: fraction of regions without data for this size class
    geographic_score = sum(n == 0) / n_all_regions
  ) %>%
  ungroup()

# Temporal deficit per size class: fraction of years without data
temporal_by_size <- surv_data %>%
  group_by(size_class, survey_yr) %>%
  summarise(n = n(), .groups = "drop") %>%
  complete(size_class, survey_yr = all_years, fill = list(n = 0)) %>%
  group_by(size_class) %>%
  summarise(
    temporal_score = sum(n == 0) / n_all_years,
    .groups = "drop"
  )

priority_gaps <- priority_gaps %>%
  left_join(temporal_by_size, by = "size_class") %>%
  mutate(
    priority_score = (sample_score + geographic_score + temporal_score) / 3,
    gap_description = paste0(size_class, " - ", region)
  ) %>%
  arrange(desc(priority_score)) %>%
  mutate(priority_rank = row_number())

# --- Original hardcoded priorities (retained for reference) ---
# priority_gaps_hardcoded <- tibble(
#   gap_description = c(
#     "Large adult survival (SC5) - All regions",
#     "Field data for SC1 recruits",
#     "Long-term monitoring (>5 yr tracking)",
#     "Bahamas/Jamaica regional coverage",
#     "Climate event survival data",
#     "Nursery-to-field transition survival",
#     "Density-dependent growth data",
#     "Pre-2010 historical data"
#   ),
#   impact = c(5, 4, 5, 3, 5, 4, 4, 3),
#   feasibility = c(2, 4, 3, 3, 3, 4, 3, 1),
#   urgency = c(3, 4, 4, 3, 5, 4, 3, 2),
#   current_n = c(
#     sum(surv_data$size_class == "SC5_large_adult"),
#     sum(surv_data$size_class == "SC1_recruit" & surv_data$data_type == "field"),
#     NA,
#     sum(surv_data$region %in% c("Bahamas", "Jamaica")),
#     NA, NA, NA,
#     sum(surv_data$survey_yr < 2010)
#   )
# ) %>%
#   mutate(
#     priority_score = impact * feasibility * urgency / 25,
#     priority_rank = rank(-priority_score)
#   ) %>%
#   arrange(priority_rank)
# --- End original hardcoded priorities ---

cat("Gap prioritization (ranked by data-driven priority score):\n\n")
print(as.data.frame(priority_gaps %>%
                      select(priority_rank, gap_description, n,
                             sample_score, geographic_score, temporal_score,
                             priority_score) %>%
                      mutate(across(where(is.numeric) & !c(n, priority_rank), ~round(., 3)))))

# ==============================================================================
# 8. RECOMMENDED STUDIES
# ==============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  RECOMMENDED FUTURE STUDIES\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

recommendations <- tibble(
  priority = 1:5,
  study_type = c(
    "Transplant experiment: nursery-to-field transitions",
    "Long-term monitoring: 5+ year individual tracking",
    "Climate response study: pre/post-bleaching survival",
    "Regional expansion: Bahamas/Jamaica/BVI surveys",
    "Recruit survival experiment: fragment vs natural"
  ),
  addresses_gap = c(
    "Nursery-to-field transition, size thresholds",
    "Long-term demographic rates, growth trajectories",
    "Climate sensitivity, disturbance response",
    "Regional variation, genetic connectivity",
    "Recruit survival, propagation efficiency"
  ),
  suggested_design = c(
    "Transplant fragments at 5 sizes to 3+ field sites, track 2 years",
    "Establish permanent plots at 5+ sites, annual surveys",
    "Document survival before/during/after thermal events",
    "Partner with local groups for standardized surveys",
    "Split fragments vs outplanted recruits, compare survival"
  ),
  estimated_n = c(500, 1000, 200, 300, 200)
)

cat("Recommended studies to address gaps:\n\n")
for (i in 1:nrow(recommendations)) {
  cat(sprintf("%d. %s\n", recommendations$priority[i], recommendations$study_type[i]))
  cat(sprintf("   Addresses: %s\n", recommendations$addresses_gap[i]))
  cat(sprintf("   Design: %s\n", recommendations$suggested_design[i]))
  cat(sprintf("   Target n: %d\n\n", recommendations$estimated_n[i]))
}

# ==============================================================================
# 9. SAVE RESULTS
# ==============================================================================

cat("═══════════════════════════════════════════════════════════════\n")
cat("  SAVING RESULTS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

write_csv(size_certainty, file.path(output_dir, "certainty_by_size_class.csv"))
write_csv(region_certainty, file.path(output_dir, "certainty_by_region.csv"))
write_csv(gaps_identified, file.path(output_dir, "data_gaps_identified.csv"))
write_csv(priority_gaps, file.path(output_dir, "gap_prioritization.csv"))
write_csv(recommendations, file.path(output_dir, "recommended_studies.csv"))

cat("✓ Saved: certainty_by_size_class.csv\n")
cat("✓ Saved: certainty_by_region.csv\n")
cat("✓ Saved: data_gaps_identified.csv\n")
cat("✓ Saved: gap_prioritization.csv\n")
cat("✓ Saved: recommended_studies.csv\n")
cat("✓ Saved: gap_summary_counts.csv\n")
cat("✓ Saved: temporal_coverage_by_region.csv\n")

# ==============================================================================
# 10. VISUALIZATION
# ==============================================================================

cat("\nGenerating visualizations...\n")

# Certainty heatmap (Size × Region)
certainty_matrix <- surv_data %>%
  group_by(size_class, region) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    .groups = "drop"
  ) %>%
  complete(size_class, region, fill = list(n = 0, survival = NA)) %>%
  mutate(
    certainty = case_when(
      n == 0 ~ "No Data",
      n < 30 ~ "Very Low",
      n < 100 ~ "Low",
      n < 300 ~ "Moderate",
      TRUE ~ "High"
    ),
    certainty = factor(certainty, levels = c("No Data", "Very Low", "Low",
                                             "Moderate", "High"))
  )

# Save certainty matrix (size x region)
write_csv(certainty_matrix, file.path(output_dir, "certainty_matrix.csv"))

p_certainty <- ggplot(certainty_matrix, aes(x = region, y = size_class, fill = certainty)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = ifelse(n > 0, n, "")), size = 3) +
  scale_fill_manual(
    values = c("No Data" = "#d3d3d3", "Very Low" = "#e07a5f",
               "Low" = "#f4a261", "Moderate" = "#e9c46a", "High" = "#2a9d8f"),
    name = "Data\nCertainty"
  ) +
  labs(
    title = "Data Coverage & Certainty Matrix",
    subtitle = "Size Class × Region (cell values = sample size)",
    x = "Region",
    y = "Size Class"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid = element_blank()
  )

ggsave(file.path(fig_dir_supp_exploratory, "certainty_heatmap.png"),
       p_certainty, width = 10, height = 6, dpi = 300)
cat("✓ Saved: supplementary/exploratory/certainty_heatmap.png\n")
cat("✓ Saved: certainty_matrix.csv\n")

# Priority gaps bar chart (top 20 for readability)
priority_gaps_top <- priority_gaps %>% slice_head(n = 20)
p_priority <- ggplot(priority_gaps_top, aes(x = reorder(gap_description, priority_score),
                                             y = priority_score)) +
  geom_col(aes(fill = priority_score), show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.2f", priority_score)), hjust = -0.1, size = 3) +
  scale_fill_gradient(low = "#f4a261", high = "#e07a5f") +
  coord_flip() +
  labs(
    title = "Data Gap Prioritization (Top 20)",
    subtitle = "Data-driven: (Sample Deficit + Geographic Deficit + Temporal Deficit) / 3",
    x = "",
    y = "Priority Score"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank())

ggsave(file.path(fig_dir_supp_exploratory, "gap_prioritization.png"),
       p_priority, width = 10, height = 6, dpi = 300)
cat("✓ Saved: supplementary/exploratory/gap_prioritization.png\n")

# ==============================================================================
# 11. SUMMARY
# ==============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  ANALYSIS COMPLETE                                           ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("KEY DATA GAP FINDINGS:\n\n")

# Size class gaps
low_cert_size <- size_certainty %>% filter(certainty_level %in% c("LOW", "VERY LOW"))
if (nrow(low_cert_size) > 0) {
  cat("Size classes with low certainty:\n")
  for (i in 1:nrow(low_cert_size)) {
    cat(sprintf("  ⚠ %s (n=%d, %s)\n",
                low_cert_size$size_class[i],
                low_cert_size$n[i],
                low_cert_size$certainty_level[i]))
  }
}

# Regional gaps
low_cert_region <- region_certainty %>% filter(certainty_level %in% c("LOW", "VERY LOW"))
if (nrow(low_cert_region) > 0) {
  cat("\nRegions with low certainty:\n")
  for (i in 1:nrow(low_cert_region)) {
    cat(sprintf("  ⚠ %s (n=%d, %s)\n",
                low_cert_region$region[i],
                low_cert_region$n[i],
                low_cert_region$certainty_level[i]))
  }
}

cat("\nTOP 3 PRIORITY GAPS:\n")
top3 <- priority_gaps %>% slice_head(n = 3)
for (i in 1:nrow(top3)) {
  cat(sprintf("  %d. %s (n=%d, score=%.3f)\n", i,
              top3$gap_description[i],
              top3$n[i],
              top3$priority_score[i]))
}

cat("\nNext step: Run 06_figures_publication.R\n\n")
