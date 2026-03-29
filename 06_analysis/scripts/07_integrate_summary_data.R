################################################################################
# 07_integrate_summary_data.R - Integrate Summary Survival/Growth Data
################################################################################
#
# PURPOSE:
#   Integrate summary-level data (apal_surv_summ.csv, apal_growth_summ.csv)
#   into the analysis pipeline. Summary data provides aggregate statistics
#   where individual-level data was not available from the original studies.
#
# METHODOLOGY:
#   Summary data cannot be used in individual-level threshold analyses but
#   can be incorporated into:
#   1. Regional survival/growth estimates (weighted by sample size)
#   2. Expanded study-level forest plots
#   3. Size class estimates where mean sizes are provided
#   4. Data coverage maps
#
# CRITICAL SIZE VARIABLE NOTES:
# -----------------------------
# Summary data has a different structure than individual data:
#   - size_cm2_mean: Mean colony size (could be total OR live tissue)
#   - size_live:     Categorical flag indicating what size_cm2_mean represents
#                    Values: "Y" (live tissue), "N" (total), "both", "unknown"
#
# For consistency with individual data (which uses live tissue area):
#   - Records with size_live == "Y" can be directly compared
#   - Records with size_live == "N" may overestimate biological size class
#   - Records with size_live == "unknown" should be flagged as uncertain
#
# This script adds a 'size_type_reliable' flag to indicate confidence in
# size class assignments from summary data.
#
# INPUTS:
#   - 05_data/standardized/apal_surv_summ.csv
#   - 05_data/standardized/apal_growth_summ.csv
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#
# OUTPUTS:
#   - 06_analysis/output/survival_by_study_combined.csv
#   - 06_analysis/output/growth_by_study_combined.csv
#   - 06_analysis/output/regional_estimates_combined.csv
#   - 06_analysis/output/summary_data_contribution.csv
#   - 06_analysis/output/fragment_survival_summary.csv
#   - 06_analysis/output/data_source_overlap.csv
#   - 06_analysis/output/size_class_reliability.csv
#
# Author: Detmer & Stier Lab
# Date: 2025-12-25
# Updated: 2025-12-28 (added size_live handling and reliability flags)
################################################################################

# Load required packages
library(dplyr)
library(tidyr)
library(readr)

# Source shared utilities for constants and helper functions
# find_project_root() is defined here, along with SIZE_BREAKS, SIZE_LABELS, etc.
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  09: INTEGRATE SUMMARY DATA                                  ║\n")
cat("║  Incorporating Aggregate Studies into Analysis               ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# =============================================================================
# SETUP
# =============================================================================

if (file.exists("05_data/standardized")) {
  project_root <- "."
} else if (file.exists("../05_data/standardized")) {
  project_root <- ".."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root.")
}

data_dir <- file.path(project_root, "05_data/standardized")
output_dir <- file.path(project_root, "06_analysis/output")

# Size class definitions from shared_utilities.R (SIZE_BREAKS, SIZE_LABELS)

# =============================================================================
# 1. LOAD DATA
# =============================================================================

cat("Loading data files...\n")

# Individual data (already processed)
surv_ind <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_ind <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

cat(sprintf("  Individual survival: %d records from %d studies\n",
            nrow(surv_ind), n_distinct(surv_ind$study)))
cat(sprintf("  Individual growth: %d records from %d studies\n",
            nrow(growth_ind), n_distinct(growth_ind$study)))

# Summary data
surv_summ <- read_csv(file.path(data_dir, "apal_surv_summ.csv"),
                      show_col_types = FALSE) %>%
  select(-1)  # Remove row number

growth_summ <- read_csv(file.path(data_dir, "apal_growth_summ.csv"),
                        show_col_types = FALSE) %>%
  select(-1)

cat(sprintf("  Summary survival: %d records from %d studies\n",
            nrow(surv_summ), n_distinct(surv_summ$study)))
cat(sprintf("  Summary growth: %d records from %d studies\n",
            nrow(growth_summ), n_distinct(growth_summ$study)))

cat("\n")

# =============================================================================
# 2. PROCESS SUMMARY SURVIVAL DATA
# =============================================================================

cat("Processing summary survival data...\n")

# Report on size_live distribution
cat("\n  Size measurement type in summary data (size_live column):\n")
print(table(surv_summ$size_live, useNA = "ifany"))
cat("\n")

# Assign size classes based on mean size WITH reliability flag
surv_summ_processed <- surv_summ %>%
  filter(!is.na(prop_survived), !is.na(n_initial), n_initial > 0) %>%
  mutate(
    # Flag indicating whether size_cm2_mean represents live tissue
    # This is critical for accurate size class assignment
    size_type = case_when(
      size_live == "Y" ~ "live_tissue",
      size_live == "N" ~ "total_colony",
      size_live == "both" ~ "both_reported",
      TRUE ~ "unknown"
    ),
    # Reliability flag for size class assignment
    # TRUE = size represents live tissue (consistent with individual data)
    # FALSE = size may be total colony (could overestimate biological size class)
    size_class_reliable = size_live %in% c("Y", "both"),

    # Determine size class from mean size if available
    # NOTE: For records with size_live != "Y", this may OVERESTIMATE the
    # biological size class (e.g., a partially dead colony might be SC5 by
    # total size but SC3 by live tissue)
    size_class = case_when(
      !is.na(size_cm2_mean) & size_cm2_mean <= 25 ~ "SC1",
      !is.na(size_cm2_mean) & size_cm2_mean <= 100 ~ "SC2",
      !is.na(size_cm2_mean) & size_cm2_mean <= 500 ~ "SC3",
      !is.na(size_cm2_mean) & size_cm2_mean <= 2000 ~ "SC4",
      !is.na(size_cm2_mean) & size_cm2_mean > 2000 ~ "SC5",
      TRUE ~ "Unknown"
    ),
    # Data source flag
    data_source = "summary",
    # Effective sample size (for weighting)
    n_effective = n_initial,
    # Convert to survived count
    n_survived = round(prop_survived * n_initial),
    # Fragment flag
    is_fragment = fragment == "Y"
  )

cat(sprintf("  Valid summary records: %d\n", nrow(surv_summ_processed)))
cat(sprintf("  Total effective N: %d observations\n", sum(surv_summ_processed$n_initial)))

# Report on size class reliability
reliable_n <- sum(surv_summ_processed$size_class_reliable)
total_n <- nrow(surv_summ_processed)
cat(sprintf("\n  Size class reliability:\n"))
cat(sprintf("    Reliable (live tissue): %d records (%.1f%%)\n",
            reliable_n, 100 * reliable_n / total_n))
cat(sprintf("    Uncertain (total/unknown): %d records (%.1f%%)\n",
            total_n - reliable_n, 100 * (total_n - reliable_n) / total_n))

# Size class distribution
sc_dist <- surv_summ_processed %>%
  group_by(size_class, size_class_reliable) %>%
  summarise(
    n_records = n(),
    total_n = sum(n_initial),
    .groups = "drop"
  )

cat("\n  Size class distribution (by reliability):\n")
print(as.data.frame(sc_dist))
cat("\n")

# =============================================================================
# 3. STUDY-LEVEL SURVIVAL ESTIMATES (COMBINED)
# =============================================================================

cat("Calculating study-level survival estimates...\n")

# Individual data - study level
surv_ind_study <- surv_ind %>%
  group_by(study, region, data_type) %>%
  summarise(
    n = n(),
    mean_survival = mean(survived),
    sd_survival = sd(survived),
    se_survival = sd(survived) / sqrt(n()),
    ci_lower = mean(survived) - 1.96 * se_survival,
    ci_upper = mean(survived) + 1.96 * se_survival,
    mean_size = mean(size_cm2),
    data_source = "individual",
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = pmax(0, ci_lower),
    ci_upper = pmin(1, ci_upper)
  )

# Summary data - study level
surv_summ_study <- surv_summ_processed %>%
  group_by(study, region, data_type) %>%
  summarise(
    n = sum(n_initial),
    mean_survival = weighted.mean(prop_survived, n_initial),
    # Correct SE for pooled proportion using inverse-variance weighting
    pooled_survival = sum(prop_survived * n_initial) / sum(n_initial),
    # Within-study variances
    # var_i = p_i * (1 - p_i) / n_i for each study's proportion
    # SE of weighted mean: 1 / sqrt(sum(1/var_i))
    se_survival = if(n() > 1) {
      study_vars <- prop_survived * (1 - prop_survived) / pmax(n_initial, 1)
      # Inverse-variance weighted SE
      1 / sqrt(sum(1 / pmax(study_vars, 1e-10)))
    } else {
      sqrt(pooled_survival * (1 - pooled_survival) / sum(n_initial))
    },
    ci_lower = mean_survival - 1.96 * se_survival,
    ci_upper = mean_survival + 1.96 * se_survival,
    mean_size = weighted.mean(size_cm2_mean, n_initial, na.rm = TRUE),
    data_source = "summary",
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = pmax(0, ci_lower),
    ci_upper = pmin(1, ci_upper)
  )

# Check for overlapping studies between individual and summary data
overlap_studies <- intersect(
  unique(surv_ind_study$study),
  unique(surv_summ_study$study)
)
if (length(overlap_studies) > 0) {
  warning(sprintf("WARNING: %d studies appear in both individual and summary data: %s\n",
                  length(overlap_studies), paste(overlap_studies, collapse = ", ")))
  cat("  These studies will have duplicate entries in the combined output.\n")
  cat("  Consider removing summary-level data for these studies.\n")
}

# Save data source overlap table
all_ind_studies <- unique(surv_ind_study$study)
all_summ_studies <- unique(surv_summ_study$study)
all_study_names <- sort(union(all_ind_studies, all_summ_studies))
data_source_overlap <- data.frame(
  study = all_study_names,
  in_individual = all_study_names %in% all_ind_studies,
  in_summary = all_study_names %in% all_summ_studies,
  resolution_method = ifelse(
    all_study_names %in% intersect(all_ind_studies, all_summ_studies),
    "both_kept_as_separate_rows",
    "single_source"
  ),
  stringsAsFactors = FALSE
)
write_csv(data_source_overlap, file.path(output_dir, "data_source_overlap.csv"))
cat(sprintf("  ✓ Saved: data_source_overlap.csv (%d studies)\n", nrow(data_source_overlap)))

# Combine
surv_by_study <- bind_rows(surv_ind_study, surv_summ_study) %>%
  arrange(region, study)

cat(sprintf("  Individual data studies: %d\n", nrow(surv_ind_study)))
cat(sprintf("  Summary data studies: %d\n", nrow(surv_summ_study)))
cat(sprintf("  Combined total: %d study-region combinations\n", nrow(surv_by_study)))

write_csv(surv_by_study, file.path(output_dir, "survival_by_study_combined.csv"))
cat("  ✓ Saved: survival_by_study_combined.csv\n\n")

# =============================================================================
# 4. PROCESS SUMMARY GROWTH DATA
# =============================================================================

cat("Processing summary growth data...\n")

# Report on size_live distribution for growth data
cat("\n  Size measurement type in growth summary data:\n")
print(table(growth_summ$size_live, useNA = "ifany"))
cat("\n")

growth_summ_processed <- growth_summ %>%
  filter(!is.na(growth_cm2_yr_mean), !is.na(n_final), n_final > 0) %>%
  mutate(
    # Flag indicating whether size_cm2_mean represents live tissue
    size_type = case_when(
      size_live == "Y" ~ "live_tissue",
      size_live == "N" ~ "total_colony",
      size_live == "both" ~ "both_reported",
      TRUE ~ "unknown"
    ),
    # Reliability flag for size class assignment
    size_class_reliable = size_live %in% c("Y", "both"),

    # Size class assignment (see reliability caveat above)
    size_class = case_when(
      !is.na(size_cm2_mean) & size_cm2_mean <= 25 ~ "SC1",
      !is.na(size_cm2_mean) & size_cm2_mean <= 100 ~ "SC2",
      !is.na(size_cm2_mean) & size_cm2_mean <= 500 ~ "SC3",
      !is.na(size_cm2_mean) & size_cm2_mean <= 2000 ~ "SC4",
      !is.na(size_cm2_mean) & size_cm2_mean > 2000 ~ "SC5",
      TRUE ~ "Unknown"
    ),
    data_source = "summary",
    n_effective = n_final,
    is_fragment = fragment == "Y"
  )

cat(sprintf("  Valid summary records: %d\n", nrow(growth_summ_processed)))
cat(sprintf("  Total effective N: %d observations\n", sum(growth_summ_processed$n_final)))

# Report on size class reliability for growth
reliable_n <- sum(growth_summ_processed$size_class_reliable)
total_n <- nrow(growth_summ_processed)
cat(sprintf("\n  Size class reliability:\n"))
cat(sprintf("    Reliable (live tissue): %d records (%.1f%%)\n",
            reliable_n, 100 * reliable_n / total_n))
cat(sprintf("    Uncertain (total/unknown): %d records (%.1f%%)\n",
            total_n - reliable_n, 100 * (total_n - reliable_n) / total_n))

# Save size class reliability for both survival and growth summary data
surv_reliability <- surv_summ_processed %>%
  group_by(size_class) %>%
  summarise(
    data_type = "survival",
    n_reliable = sum(size_class_reliable),
    n_uncertain = sum(!size_class_reliable),
    pct_reliable = round(n_reliable / n() * 100, 2),
    .groups = "drop"
  )
growth_reliability <- growth_summ_processed %>%
  group_by(size_class) %>%
  summarise(
    data_type = "growth",
    n_reliable = sum(size_class_reliable),
    n_uncertain = sum(!size_class_reliable),
    pct_reliable = round(n_reliable / n() * 100, 2),
    .groups = "drop"
  )
size_class_reliability <- bind_rows(surv_reliability, growth_reliability)
write_csv(size_class_reliability, file.path(output_dir, "size_class_reliability.csv"))
cat(sprintf("  ✓ Saved: size_class_reliability.csv (%d rows)\n", nrow(size_class_reliability)))

# Growth study level
growth_ind_study <- growth_ind %>%
  group_by(study, region, data_type) %>%
  summarise(
    n = n(),
    mean_growth = mean(growth_cm2_yr, na.rm = TRUE),
    sd_growth = sd(growth_cm2_yr, na.rm = TRUE),
    se_growth = sd_growth / sqrt(n()),
    ci_lower = mean_growth - 1.96 * se_growth,
    ci_upper = mean_growth + 1.96 * se_growth,
    mean_size = mean(size_cm2),
    data_source = "individual",
    .groups = "drop"
  )

growth_summ_study <- growth_summ_processed %>%
  group_by(study, region, data_type) %>%
  summarise(
    n = sum(n_final),
    mean_growth = weighted.mean(growth_cm2_yr_mean, n_final, na.rm = TRUE),
    # Weighted SE accounting for within-study sample sizes
    se_growth = if(n() > 1 && any(!is.na(n_final))) {
      # Use study sample sizes as weights
      weights <- pmax(n_final, 1, na.rm = TRUE)
      weighted_mean <- sum(growth_cm2_yr_mean * weights, na.rm = TRUE) / sum(weights, na.rm = TRUE)
      # Weighted standard error
      sqrt(sum(weights * (growth_cm2_yr_mean - weighted_mean)^2, na.rm = TRUE) /
           ((n() - 1) * sum(weights, na.rm = TRUE)))
    } else if(n() > 1) {
      sd(growth_cm2_yr_mean, na.rm = TRUE) / sqrt(n())
    } else {
      NA_real_
    },
    ci_lower = mean_growth - 1.96 * se_growth,
    ci_upper = mean_growth + 1.96 * se_growth,
    mean_size = weighted.mean(size_cm2_mean, n_final, na.rm = TRUE),
    data_source = "summary",
    .groups = "drop"
  )

growth_by_study <- bind_rows(growth_ind_study, growth_summ_study) %>%
  arrange(region, study)

cat(sprintf("  Individual data studies: %d\n", nrow(growth_ind_study)))
cat(sprintf("  Summary data studies: %d\n", nrow(growth_summ_study)))
cat(sprintf("  Combined total: %d study-region combinations\n", nrow(growth_by_study)))

write_csv(growth_by_study, file.path(output_dir, "growth_by_study_combined.csv"))
cat("  ✓ Saved: growth_by_study_combined.csv\n\n")

# =============================================================================
# 5. REGIONAL ESTIMATES (WEIGHTED COMBINATION)
# =============================================================================

cat("Calculating regional estimates (combined data)...\n")

# Individual data regional
surv_ind_region <- surv_ind %>%
  group_by(region) %>%
  summarise(
    n_ind = n(),
    survival_ind = mean(survived),
    n_studies_ind = n_distinct(study),
    .groups = "drop"
  )

# Summary data regional
surv_summ_region <- surv_summ_processed %>%
  group_by(region) %>%
  summarise(
    n_summ = sum(n_initial),
    survival_summ = weighted.mean(prop_survived, n_initial),
    n_studies_summ = n_distinct(study),
    .groups = "drop"
  )

# Combined regional estimates
regional_combined <- full_join(surv_ind_region, surv_summ_region, by = "region") %>%
  mutate(
    n_ind = replace_na(n_ind, 0),
    n_summ = replace_na(n_summ, 0),
    n_total = n_ind + n_summ,
    # Weighted average
    survival_combined = case_when(
      n_ind > 0 & n_summ > 0 ~ (survival_ind * n_ind + survival_summ * n_summ) / n_total,
      n_ind > 0 ~ survival_ind,
      n_summ > 0 ~ survival_summ,
      TRUE ~ NA_real_
    ),
    n_studies_ind = replace_na(n_studies_ind, 0),
    n_studies_summ = replace_na(n_studies_summ, 0),
    n_studies_total = n_studies_ind + n_studies_summ,
    pct_from_summary = n_summ / n_total * 100
  ) %>%
  arrange(desc(n_total))

cat("\nRegional estimates (combined):\n")
print(as.data.frame(regional_combined %>%
                      select(region, n_total, survival_combined, n_studies_total, pct_from_summary)))

write_csv(regional_combined, file.path(output_dir, "regional_estimates_combined.csv"))
cat("\n  ✓ Saved: regional_estimates_combined.csv\n\n")

# =============================================================================
# 6. SUMMARY DATA CONTRIBUTION ANALYSIS
# =============================================================================

cat("Analyzing summary data contribution...\n")

contribution <- data.frame(
  data_type = c("Survival", "Growth"),
  n_individual = c(nrow(surv_ind), nrow(growth_ind)),
  n_summary_effective = c(sum(surv_summ_processed$n_initial),
                          sum(growth_summ_processed$n_final)),
  n_summary_records = c(nrow(surv_summ_processed), nrow(growth_summ_processed)),
  studies_individual = c(n_distinct(surv_ind$study), n_distinct(growth_ind$study)),
  studies_summary = c(n_distinct(surv_summ_processed$study),
                      n_distinct(growth_summ_processed$study))
) %>%
  mutate(
    n_total = n_individual + n_summary_effective,
    pct_individual = round(n_individual / n_total * 100, 1),
    pct_summary = round(n_summary_effective / n_total * 100, 1)
  )

cat("\nData contribution summary:\n")
print(contribution)

write_csv(contribution, file.path(output_dir, "summary_data_contribution.csv"))
cat("\n  ✓ Saved: summary_data_contribution.csv\n")

# =============================================================================
# 7. FRAGMENT VS COLONY COMPARISON (from summary data)
# =============================================================================

cat("\nAnalyzing fragment vs colony patterns (summary data)...\n")

frag_analysis <- surv_summ_processed %>%
  group_by(is_fragment, size_class) %>%
  summarise(
    n_records = n(),
    total_n = sum(n_initial),
    mean_survival = weighted.mean(prop_survived, n_initial),
    se = sqrt(mean_survival * (1 - mean_survival) / total_n),
    .groups = "drop"
  ) %>%
  mutate(
    type = ifelse(is_fragment, "Fragment", "Colony")
  )

cat("\nSurvival by fragment status (summary data):\n")
print(as.data.frame(frag_analysis %>% select(type, size_class, total_n, mean_survival)))

write_csv(frag_analysis, file.path(output_dir, "fragment_survival_summary.csv"))
cat("\n  ✓ Saved: fragment_survival_summary.csv\n")

# =============================================================================
# FINAL SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  SUMMARY DATA INTEGRATION COMPLETE                           ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("Data integration results:\n")
cat(sprintf("  Survival: %d individual + %d summary = %d total observations\n",
            nrow(surv_ind), sum(surv_summ_processed$n_initial),
            nrow(surv_ind) + sum(surv_summ_processed$n_initial)))
cat(sprintf("  Growth: %d individual + %d summary = %d total observations\n",
            nrow(growth_ind), sum(growth_summ_processed$n_final),
            nrow(growth_ind) + sum(growth_summ_processed$n_final)))
cat(sprintf("  Studies: %d individual + %d summary-only\n",
            n_distinct(surv_ind$study),
            length(setdiff(unique(surv_summ_processed$study), unique(surv_ind$study)))))

cat("\nOutputs generated:\n")
cat("  - survival_by_study_combined.csv\n")
cat("  - growth_by_study_combined.csv\n")
cat("  - regional_estimates_combined.csv\n")
cat("  - summary_data_contribution.csv\n")
cat("  - fragment_survival_summary.csv\n")
cat("  - data_source_overlap.csv\n")
cat("  - size_class_reliability.csv\n")

cat("\nNOTE: Summary data is integrated for forest plots and regional estimates.\n")
cat("      Threshold detection continues to use individual-level data only.\n\n")
