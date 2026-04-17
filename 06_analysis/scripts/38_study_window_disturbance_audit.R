#!/usr/bin/env Rscript
################################################################################
# 38_STUDY_WINDOW_DISTURBANCE_AUDIT.R
# Study-window audit for curated disturbance-event overlap
################################################################################
#
# PURPOSE:
#   Rebuild the curated disturbance overlap on prepared survival intervals and
#   summarize which study windows overlap which disturbance events.
#
# INPUTS:
#   - 05_data/standardized/apal_disturbance_stressor_timeline.csv (curated timeline)
#   - 06_analysis/output/prepared_survival_data.rds (individual survival intervals)
#
# OUTPUTS:
#   - 06_analysis/output/study_window_disturbance_audit.csv
#   - 06_analysis/output/study_window_disturbance_summary_by_study.csv
#   - 06_analysis/output/study_window_disturbance_summary_overall.csv
#   - 06_analysis/output/study_window_disturbance_rebuild_check.csv
#   - 07_reporting/manuscript/tables/study_window_disturbance_audit.md
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(stringr)
})

if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
} else if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
}

project_root <- get_project_root()
dirs <- setup_output_dirs(project_root)
output_dir <- dirs$output
tables_dir <- file.path(project_root, "07_reporting/manuscript/tables")
dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

print_header("38: STUDY-WINDOW DISTURBANCE COVERAGE AUDIT")
cat("  Rebuilding curated disturbance overlaps on prepared survival intervals\n\n")

timeline_file <- file.path(project_root, "05_data/standardized/apal_disturbance_stressor_timeline.csv")
surv_file <- file.path(output_dir, "prepared_survival_data.rds")

if (!file.exists(timeline_file)) {
  stop("Missing curated disturbance timeline: ", timeline_file)
}
if (!file.exists(surv_file)) {
  stop("Missing prepared survival data: ", surv_file)
}

timeline <- read_csv(timeline_file, show_col_types = FALSE)
surv_data <- readRDS(surv_file)

if (!"population_type" %in% names(surv_data)) {
  surv_data <- surv_data %>%
    mutate(
      is_fragment = ifelse("fragment" %in% names(.), fragment == "Y", FALSE),
      population_type = if_else(is_fragment, "Restoration fragment", "Natural colony")
    )
}

base_drop <- c(
  "timeline_interval_end_year",
  "timeline_event_count",
  "timeline_event_names",
  "timeline_event_types",
  "timeline_sources",
  "timeline_spatial_scales",
  "timeline_analysis_tiers",
  "Event_Name",
  "Event_Type",
  "Intensity_Value",
  "Impact_Description",
  "disturbance_regime",
  "exclude_from_baseline",
  "is_catastrophic",
  "is_major_disturbance"
)

audit_base <- surv_data %>%
  select(-any_of(base_drop))

rebuilt <- attach_disturbance_timeline(
  audit_base,
  timeline,
  region_col = "region",
  year_col = "survey_yr",
  interval_col = "time_interval_yr",
  legacy_col = "disturbance"
)

required_cols <- c(
  "study", "region", "location", "plot", "treatment_1", "treatment_2",
  "data_type", "population_type", "survey_yr", "time_interval_yr",
  "timeline_interval_end_year", "timeline_event_count", "timeline_event_names",
  "timeline_event_types", "timeline_sources", "timeline_spatial_scales",
  "timeline_analysis_tiers", "Event_Name", "Event_Type", "Intensity_Value",
  "Impact_Description", "disturbance_regime", "exclude_from_baseline",
  "is_catastrophic", "is_major_disturbance", "disturbance"
)

missing_cols <- setdiff(required_cols, names(rebuilt))
if (length(missing_cols) > 0) {
  stop("Rebuilt audit data missing columns: ", paste(missing_cols, collapse = ", "))
}

row_check <- tibble(
  field = c("timeline_interval_end_year", "timeline_event_count", "timeline_event_names",
            "timeline_event_types", "timeline_sources", "timeline_analysis_tiers",
            "Event_Name", "Event_Type", "Intensity_Value", "Impact_Description",
            "disturbance_regime", "exclude_from_baseline", "is_catastrophic",
            "is_major_disturbance"),
  mismatch_n = c(
    sum(rebuilt$timeline_interval_end_year != surv_data$timeline_interval_end_year, na.rm = TRUE),
    sum(rebuilt$timeline_event_count != surv_data$timeline_event_count, na.rm = TRUE),
    sum(replace_na(rebuilt$timeline_event_names, "") != replace_na(surv_data$timeline_event_names, "")),
    sum(replace_na(rebuilt$timeline_event_types, "") != replace_na(surv_data$timeline_event_types, "")),
    sum(replace_na(rebuilt$timeline_sources, "") != replace_na(surv_data$timeline_sources, "")),
    sum(replace_na(rebuilt$timeline_analysis_tiers, "") != replace_na(surv_data$timeline_analysis_tiers, "")),
    sum(replace_na(rebuilt$Event_Name, "") != replace_na(surv_data$Event_Name, "")),
    sum(replace_na(rebuilt$Event_Type, "") != replace_na(surv_data$Event_Type, "")),
    sum(replace_na(rebuilt$Intensity_Value, "") != replace_na(surv_data$Intensity_Value, "")),
    sum(replace_na(rebuilt$Impact_Description, "") != replace_na(surv_data$Impact_Description, "")),
    sum(replace_na(rebuilt$disturbance_regime, "") != replace_na(surv_data$disturbance_regime, "")),
    sum(rebuilt$exclude_from_baseline != surv_data$exclude_from_baseline, na.rm = TRUE),
    sum(rebuilt$is_catastrophic != surv_data$is_catastrophic, na.rm = TRUE),
    sum(rebuilt$is_major_disturbance != surv_data$is_major_disturbance, na.rm = TRUE)
  ),
  checked_n = nrow(surv_data)
)

audit_rows <- rebuilt %>%
  mutate(
    has_local_metadata = !is.na(disturbance) & disturbance != "" & disturbance != "none",
    has_timeline_overlap = !is.na(timeline_event_count) & timeline_event_count > 0,
    overlap_source = case_when(
      has_local_metadata & has_timeline_overlap ~ "local_metadata_plus_timeline",
      has_local_metadata ~ "local_metadata_only",
      has_timeline_overlap ~ "timeline_overlay",
      TRUE ~ "none"
    ),
    overlap_category = case_when(
      timeline_event_count == 0 ~ "zero",
      timeline_event_count == 1 ~ "one",
      timeline_event_count >= 2 ~ "multiple",
      TRUE ~ NA_character_
    ),
    interval_end_year = timeline_interval_end_year
  ) %>%
  group_by(
    study, region, location, plot, treatment_1, treatment_2, data_type,
    population_type, survey_yr, time_interval_yr, interval_end_year, disturbance,
    disturbance_regime, exclude_from_baseline, is_catastrophic,
    is_major_disturbance, has_local_metadata, has_timeline_overlap,
    overlap_source, overlap_category, timeline_event_count, timeline_event_names,
    timeline_event_types, timeline_sources, timeline_spatial_scales,
    timeline_analysis_tiers, Event_Name, Event_Type, Intensity_Value,
    Impact_Description
  ) %>%
  summarise(
    n_records = n(),
    n_corals = n_distinct(coral_id),
    min_size_cm2 = min(size_cm2, na.rm = TRUE),
    median_size_cm2 = median(size_cm2, na.rm = TRUE),
    max_size_cm2 = max(size_cm2, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(study, region, survey_yr, interval_end_year, location, plot)

study_summary <- audit_rows %>%
  group_by(study) %>%
  summarise(
    n_intervals = n(),
    n_zero_overlap = sum(overlap_category == "zero", na.rm = TRUE),
    n_one_overlap = sum(overlap_category == "one", na.rm = TRUE),
    n_multi_overlap = sum(overlap_category == "multiple", na.rm = TRUE),
    n_local_metadata_only = sum(overlap_source == "local_metadata_only", na.rm = TRUE),
    n_timeline_overlay = sum(overlap_source == "timeline_overlay", na.rm = TRUE),
    n_both_sources = sum(overlap_source == "local_metadata_plus_timeline", na.rm = TRUE),
    n_baseline_exclusion = sum(exclude_from_baseline, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    pct_with_any_overlap = round((n_one_overlap + n_multi_overlap) / n_intervals * 100, 1)
  ) %>%
  arrange(desc(n_intervals), study)

overall_summary <- tibble(
  n_intervals = nrow(audit_rows),
  n_studies = n_distinct(audit_rows$study),
  n_zero_overlap = sum(audit_rows$overlap_category == "zero", na.rm = TRUE),
  n_one_overlap = sum(audit_rows$overlap_category == "one", na.rm = TRUE),
  n_multi_overlap = sum(audit_rows$overlap_category == "multiple", na.rm = TRUE),
  n_local_metadata_only = sum(audit_rows$overlap_source == "local_metadata_only", na.rm = TRUE),
  n_timeline_overlay = sum(audit_rows$overlap_source == "timeline_overlay", na.rm = TRUE),
  n_both_sources = sum(audit_rows$overlap_source == "local_metadata_plus_timeline", na.rm = TRUE),
  n_baseline_exclusion = sum(audit_rows$exclude_from_baseline, na.rm = TRUE),
  pct_with_any_overlap = round((sum(audit_rows$overlap_category != "zero", na.rm = TRUE) / nrow(audit_rows)) * 100, 1)
)

write_csv(audit_rows, file.path(output_dir, "study_window_disturbance_audit.csv"))
write_csv(study_summary, file.path(output_dir, "study_window_disturbance_summary_by_study.csv"))
write_csv(overall_summary, file.path(output_dir, "study_window_disturbance_summary_overall.csv"))
write_csv(row_check, file.path(output_dir, "study_window_disturbance_rebuild_check.csv"))

md_lines <- c(
  "# Study-Window Disturbance Coverage Audit",
  "",
  "This audit rebuilds the curated disturbance overlay on prepared survival intervals and summarizes overlap by study window.",
  "",
  "## Overall",
  "",
  sprintf("- Intervals audited: %s", format(overall_summary$n_intervals, big.mark = ",")),
  sprintf("- Studies represented: %s", overall_summary$n_studies),
  sprintf("- Zero-overlap intervals: %s", format(overall_summary$n_zero_overlap, big.mark = ",")),
  sprintf("- One-event intervals: %s", format(overall_summary$n_one_overlap, big.mark = ",")),
  sprintf("- Multi-event intervals: %s", format(overall_summary$n_multi_overlap, big.mark = ",")),
  sprintf("- Baseline-exclusion intervals: %s", format(overall_summary$n_baseline_exclusion, big.mark = ",")),
  "",
  "## By Study",
  ""
)

study_table <- study_summary %>%
  mutate(across(where(is.numeric), ~ format(.x, trim = TRUE, scientific = FALSE))) %>%
  as.data.frame()

study_md <- c(
  paste0("| ", paste(names(study_table), collapse = " | "), " |"),
  paste0("|", paste(rep(" --- ", ncol(study_table)), collapse = "|"), "|"),
  vapply(seq_len(nrow(study_table)), function(i) {
    paste0("| ", paste(study_table[i, ], collapse = " | "), " |")
  }, character(1))
)

writeLines(c(md_lines, study_md, "", "## Rebuild Check", "",
             paste0("- Exact field mismatches found: ",
                    sum(row_check$mismatch_n, na.rm = TRUE))),
           file.path(tables_dir, "TableS2_study_window_disturbance_audit.md"))

cat("Audit summary:\n")
cat(sprintf("  Intervals audited: %s\n", format(overall_summary$n_intervals, big.mark = ",")))
cat(sprintf("  Studies represented: %d\n", overall_summary$n_studies))
cat(sprintf("  Zero-overlap intervals: %s\n", format(overall_summary$n_zero_overlap, big.mark = ",")))
cat(sprintf("  One-event intervals: %s\n", format(overall_summary$n_one_overlap, big.mark = ",")))
cat(sprintf("  Multi-event intervals: %s\n", format(overall_summary$n_multi_overlap, big.mark = ",")))
cat(sprintf("  Local-metadata-only intervals: %s\n", format(overall_summary$n_local_metadata_only, big.mark = ",")))
cat(sprintf("  Timeline-overlay intervals: %s\n", format(overall_summary$n_timeline_overlay, big.mark = ",")))
cat(sprintf("  Both-source intervals: %s\n", format(overall_summary$n_both_sources, big.mark = ",")))
cat(sprintf("  Baseline-exclusion intervals: %s\n", format(overall_summary$n_baseline_exclusion, big.mark = ",")))
cat(sprintf("  Rebuild mismatches: %s\n", format(sum(row_check$mismatch_n, na.rm = TRUE), big.mark = ",")))
cat("\nSaved:\n")
cat("  - 06_analysis/output/study_window_disturbance_audit.csv\n")
cat("  - 06_analysis/output/study_window_disturbance_summary_by_study.csv\n")
cat("  - 06_analysis/output/study_window_disturbance_summary_overall.csv\n")
cat("  - 06_analysis/output/study_window_disturbance_rebuild_check.csv\n")
cat("  - 07_reporting/manuscript/tables/TableS2_study_window_disturbance_audit.md\n")
