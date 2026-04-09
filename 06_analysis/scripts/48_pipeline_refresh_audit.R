#!/usr/bin/env Rscript
################################################################################
# 48_PIPELINE_REFRESH_AUDIT.R
# Refresh pipeline metadata, canonical statistics, and generated reporting docs
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

cat("\n")
cat("================================================================\n")
cat("  PIPELINE REFRESH AUDIT\n")
cat("================================================================\n\n")

project_root <- get_project_root()
dirs <- setup_output_dirs(project_root)
output_dir <- dirs$output
generated_dir <- dirs$reporting_generated

context_file <- file.path(output_dir, "pipeline_context_current.csv")
run_context <- if (file.exists(context_file)) {
  read_csv(context_file, show_col_types = FALSE)
} else {
  tibble(
    run_id = format(Sys.time(), "%Y%m%d_%H%M%S"),
    pipeline_started_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    fail_fast = NA
  )
}

run_id <- run_context$run_id[1]
pipeline_started_at <- as.POSIXct(run_context$pipeline_started_at[1], tz = Sys.timezone())

registry <- read_data_registry(project_root)
inventory <- build_standardized_inventory(project_root, registry)
write_csv(inventory, file.path(output_dir, "standardized_data_inventory.csv"))

cat(sprintf("Wrote standardized inventory for %d registered tables\n", nrow(inventory)))

stats_file <- file.path(output_dir, "canonical_statistics.csv")
canonical_stats <- if (file.exists(stats_file)) {
  read_csv(stats_file, show_col_types = FALSE)
} else {
  tibble(
    section = character(),
    metric = character(),
    value = numeric(),
    display_value = character(),
    source_file = character(),
    note = character()
  )
}

add_generated_stat <- function(df, section, metric, value,
                               display_value = as.character(value),
                               source_file = NA_character_,
                               note = NA_character_) {
  bind_rows(
    df,
    tibble(
      section = section,
      metric = metric,
      value = as.numeric(value),
      display_value = as.character(display_value),
      source_file = source_file,
      note = note
    )
  )
}

disturbance_file <- file.path(output_dir, "disturbance_sensitivity_summary.csv")
if (file.exists(disturbance_file)) {
  disturbance <- read_csv(disturbance_file, show_col_types = FALSE)
  all_row <- disturbance %>% filter(scenario == "All data (including disease 2014)")
  baseline_row <- disturbance %>% filter(scenario == "Excluding baseline-exclusion events")
  if (nrow(all_row) == 1) {
    canonical_stats <- add_generated_stat(
      canonical_stats, "disturbance", "all_data_pooled_survival_pct",
      all_row$pooled_survival[1] * 100,
      sprintf("%.1f%%", all_row$pooled_survival[1] * 100),
      "06_analysis/output/disturbance_sensitivity_summary.csv"
    )
  }
  if (nrow(baseline_row) == 1) {
    canonical_stats <- add_generated_stat(
      canonical_stats, "disturbance", "baseline_exclusion_pooled_survival_pct",
      baseline_row$pooled_survival[1] * 100,
      sprintf("%.1f%%", baseline_row$pooled_survival[1] * 100),
      "06_analysis/output/disturbance_sensitivity_summary.csv"
    )
  }
  if (nrow(all_row) == 1 && nrow(baseline_row) == 1) {
    shift_pp <- (baseline_row$pooled_survival[1] - all_row$pooled_survival[1]) * 100
    canonical_stats <- add_generated_stat(
      canonical_stats, "disturbance", "baseline_exclusion_shift_pp",
      shift_pp, sprintf("%+.1f pp", shift_pp),
      "06_analysis/output/disturbance_sensitivity_summary.csv"
    )
  }
}

shrinkage_file <- file.path(output_dir, "shrinkage_retrogression_subset_summary.csv")
if (file.exists(shrinkage_file)) {
  shrinkage <- read_csv(shrinkage_file, show_col_types = FALSE) %>%
    filter(analysis_subset == "matrix_compatible")
  if (nrow(shrinkage) == 1) {
    canonical_stats <- add_generated_stat(
      canonical_stats, "shrinkage", "matrix_compatible_shrinkage_frequency_pct",
      shrinkage$shrinkage_frequency_pct[1],
      sprintf("%.1f%%", shrinkage$shrinkage_frequency_pct[1]),
      "06_analysis/output/shrinkage_retrogression_subset_summary.csv"
    )
  }
}

restore_file <- file.path(output_dir, "restoration_subtype_sensitivity.csv")
if (file.exists(restore_file)) {
  restore <- read_csv(restore_file, show_col_types = FALSE)
  subtype_rows <- list(
    all_subtypes = "All restoration subtypes",
    exclude_natural = "Exclude natural fragments",
    nursery_only = "Nursery outplants only"
  )
  for (metric_name in names(subtype_rows)) {
    row <- restore %>% filter(scenario == subtype_rows[[metric_name]])
    if (nrow(row) == 1) {
      canonical_stats <- add_generated_stat(
        canonical_stats, "restoration", paste0(metric_name, "_mean_survival_pct"),
        row$mean_survival[1] * 100,
        sprintf("%.1f%%", row$mean_survival[1] * 100),
        "06_analysis/output/restoration_subtype_sensitivity.csv"
      )
    }
  }
}

interaction_file <- file.path(output_dir, "disturbance_size_survival_model.csv")
if (file.exists(interaction_file)) {
  interaction <- read_csv(interaction_file, show_col_types = FALSE)
  lrt_p <- suppressWarnings(as.numeric(interaction$comparison_lrt_p[1]))
  if (!is.na(lrt_p)) {
    canonical_stats <- add_generated_stat(
      canonical_stats, "disturbance", "disturbance_size_interaction_lrt_p",
      lrt_p,
      ifelse(lrt_p < 0.001, "p < 0.001", sprintf("p = %.4g", lrt_p)),
      "06_analysis/output/disturbance_size_survival_model.csv"
    )
  }
}

audit_file <- file.path(output_dir, "study_window_disturbance_summary_overall.csv")
if (file.exists(audit_file)) {
  audit <- read_csv(audit_file, show_col_types = FALSE)
  if (nrow(audit) == 1) {
    canonical_stats <- add_generated_stat(
      canonical_stats, "disturbance", "study_window_intervals_audited",
      audit$n_intervals[1], sprintf("%d", audit$n_intervals[1]),
      "06_analysis/output/study_window_disturbance_summary_overall.csv"
    )
    canonical_stats <- add_generated_stat(
      canonical_stats, "disturbance", "baseline_exclusion_intervals",
      audit$n_baseline_exclusion[1], sprintf("%d", audit$n_baseline_exclusion[1]),
      "06_analysis/output/study_window_disturbance_summary_overall.csv"
    )
  }
}

canonical_stats <- canonical_stats %>%
  group_by(section, metric) %>%
  slice_tail(n = 1) %>%
  ungroup() %>%
  arrange(section, metric)

write_csv(canonical_stats, stats_file)

artifact_registry <- canonical_artifact_registry(project_root)
write_csv(artifact_registry, file.path(output_dir, "canonical_artifact_registry.csv"))

inventory_lines <- c(
  "# Standardized Data Inventory",
  "",
  sprintf("Generated from pipeline run `%s` on %s.", run_id, format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  "| File | Role | Rows | Studies | Regions | Year Range | Duplicate Keys |",
  "|---|---:|---:|---:|---:|---|---:|"
)

for (i in seq_len(nrow(inventory))) {
  year_range <- if (is.na(inventory$min_year[i]) || is.na(inventory$max_year[i])) {
    ""
  } else {
    sprintf("%s-%s", inventory$min_year[i], inventory$max_year[i])
  }
  inventory_lines <- c(
    inventory_lines,
    sprintf(
      "| `%s` | %s | %s | %s | %s | %s | %s |",
      inventory$file_name[i],
      inventory$file_role[i],
      ifelse(is.na(inventory$n_rows[i]), "", format(inventory$n_rows[i], big.mark = ",")),
      ifelse(is.na(inventory$n_studies[i]), "", inventory$n_studies[i]),
      ifelse(is.na(inventory$n_regions[i]), "", inventory$n_regions[i]),
      year_range,
      ifelse(is.na(inventory$duplicate_key_rows[i]), "", inventory$duplicate_key_rows[i])
    )
  )
}

stats_lines <- c(
  "# Canonical Statistics",
  "",
  sprintf("Generated from pipeline run `%s` on %s.", run_id, format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  ""
)

for (section_name in unique(canonical_stats$section)) {
  section_stats <- canonical_stats %>% filter(section == section_name)
  stats_lines <- c(stats_lines, paste0("## ", tools::toTitleCase(gsub("_", " ", section_name))), "")
  stats_lines <- c(stats_lines, "| Metric | Value | Source |")
  stats_lines <- c(stats_lines, "|---|---|---|")
  for (i in seq_len(nrow(section_stats))) {
    stats_lines <- c(
      stats_lines,
      sprintf(
        "| `%s` | %s | `%s` |",
        section_stats$metric[i],
        section_stats$display_value[i],
        section_stats$source_file[i]
      )
    )
  }
  stats_lines <- c(stats_lines, "")
}

write_markdown_lines(inventory_lines, file.path(generated_dir, "standardized_data_inventory.md"))
write_markdown_lines(stats_lines, file.path(generated_dir, "canonical_statistics.md"))

status_csv <- file.path(output_dir, "canonical_artifact_status.csv")
freshness_csv <- file.path(output_dir, "pipeline_artifact_freshness.csv")
summary_md_path <- file.path(generated_dir, "pipeline_refresh_report.md")
artifact_md_path <- file.path(generated_dir, "canonical_artifact_status.md")

render_summary_lines <- function(artifact_status) {
  fresh_summary <- artifact_status %>%
    mutate(status = case_when(
      !exists ~ "missing",
      generated_this_run %in% TRUE ~ "fresh",
      generated_this_run %in% FALSE ~ "stale",
      TRUE ~ "unknown"
    )) %>%
    count(category, status, name = "n")

  summary_lines <- c(
    "# Pipeline Refresh Report",
    "",
    sprintf("- Run ID: `%s`", run_id),
    sprintf("- Pipeline start: `%s`", run_context$pipeline_started_at[1]),
    sprintf("- Generated: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "",
    "## Artifact Freshness",
    "",
    "| Category | Status | Count |",
    "|---|---|---:|"
  )

  for (i in seq_len(nrow(fresh_summary))) {
    summary_lines <- c(
      summary_lines,
      sprintf("| %s | %s | %d |", fresh_summary$category[i], fresh_summary$status[i], fresh_summary$n[i])
    )
  }

  stale_artifacts <- artifact_status %>%
    filter(exists, generated_this_run %in% FALSE) %>%
    arrange(category, artifact) %>%
    transmute(line = sprintf("- `%s` (%s)", artifact, path))

  missing_artifacts <- artifact_status %>%
    filter(!exists) %>%
    arrange(category, artifact) %>%
    transmute(line = sprintf("- `%s` (%s)", artifact, path))

  c(
    summary_lines,
    "",
    "## Notes",
    "",
    "- `canonical_statistics.csv` is the machine-readable summary of manuscript-facing numeric results.",
    "- `standardized_data_inventory.csv` snapshots current registered inputs, their row counts, hashes, and key-level integrity metadata.",
    "- `canonical_artifact_status.csv` and `pipeline_artifact_freshness.csv` mark whether canonical outputs were regenerated during the current run.",
    "",
    "## Stale Artifacts",
    "",
    if (nrow(stale_artifacts) > 0) stale_artifacts$line else "- None.",
    "",
    "## Missing Artifacts",
    "",
    if (nrow(missing_artifacts) > 0) missing_artifacts$line else "- None."
  )
}

render_artifact_table <- function(artifact_status) {
  artifact_status %>%
    mutate(
      exists = ifelse(exists, "yes", "no"),
      generated_this_run = ifelse(is.na(generated_this_run), "", ifelse(generated_this_run, "yes", "no"))
    ) %>%
    select(category, artifact, script, path, exists, generated_this_run, modified_time)
}

build_status <- function() {
  build_artifact_status(
    artifact_registry,
    run_start = pipeline_started_at,
    project_root = project_root
  )
}

# First pass after inventory/statistics docs exist.
artifact_status <- build_status()
write_csv(artifact_status, status_csv)
write_csv(artifact_status, freshness_csv)

# Second pass after status CSVs exist; use this to build generated markdown.
artifact_status <- build_status()
write_markdown_lines(render_summary_lines(artifact_status), summary_md_path)
write_markdown_table(
  render_artifact_table(artifact_status),
  artifact_md_path,
  title = "Canonical Artifact Status",
  intro = "Canonical outputs, figures, and reporting artifacts with presence and same-run regeneration status."
)

# Final pass after all generated markdown exists.
artifact_status <- build_status()
write_csv(artifact_status, status_csv)
write_csv(artifact_status, freshness_csv)
write_markdown_lines(render_summary_lines(artifact_status), summary_md_path)
write_markdown_table(
  render_artifact_table(artifact_status),
  artifact_md_path,
  title = "Canonical Artifact Status",
  intro = "Canonical outputs, figures, and reporting artifacts with presence and same-run regeneration status."
)

cat("Saved:\n")
cat("  - 06_analysis/output/canonical_artifact_registry.csv\n")
cat("  - 06_analysis/output/standardized_data_inventory.csv\n")
cat("  - 06_analysis/output/canonical_statistics.csv\n")
cat("  - 06_analysis/output/canonical_artifact_status.csv\n")
cat("  - 06_analysis/output/pipeline_artifact_freshness.csv\n")
cat("  - 07_reporting/generated/standardized_data_inventory.md\n")
cat("  - 07_reporting/generated/canonical_statistics.md\n")
cat("  - 07_reporting/generated/canonical_artifact_status.md\n")
cat("  - 07_reporting/generated/pipeline_refresh_report.md\n\n")
