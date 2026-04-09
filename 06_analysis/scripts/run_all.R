################################################################################
# run_all.R - Master Script for A. palmata Demographic Analysis Pipeline
################################################################################
#
# PURPOSE:
#   Execute the maintained analysis pipeline in the correct order, from data
#   preparation through manuscript figures, disturbance/restoration extensions,
#   advanced dynamic models, and verification.
#
# USAGE:
#   From project root:
#     Rscript 06_analysis/scripts/run_all.R
#
#   Or from analysis/scripts directory:
#     Rscript run_all.R
#
# PIPELINE ORDER (sequential numbering):
#   01     = Data preparation
#   02-07  = Core analysis (survival, growth, variance, gaps, integration)
#   08-12  = Robustness & supplementary (climate, power, CV, context, model selection)
#   13-17  = Synthesis (matrix, meta-analysis, heterogeneity, sensitivity, parameters)
#   18-23  = Manuscript figures and data-gap figure
#   24-28  = Supplementary figures (S3-S14)
#   29-40  = Context, disturbance, restoration, completeness, scenario extensions
#   41-47  = Advanced dynamic model extensions
#   23     = Verification
#   48     = Pipeline refresh audit
#
#   00* → 01 → 02-07 → 08-12 → 13-17 → 18-23 + 24-28 → 29-40 → 41-47 → 23_verification → 48
#
# OUTPUTS:
#   - Generated files in 06_analysis/output/
#   - Generated figures in 06_analysis/figures/
#   - Pipeline log with timing information
#
# Author: Detmer & Stier Lab
# Date: 2025-12-25
################################################################################

# Clear environment
rm(list = ls())

# Record start time
pipeline_start <- Sys.time()

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════════════╗\n")
cat("║   A. PALMATA DEMOGRAPHIC ANALYSIS PIPELINE                           ║\n")
cat("║   Master Script - Running All Analyses                               ║\n")
cat("╚═══════════════════════════════════════════════════════════════════════╝\n")
cat("\n")
cat(sprintf("Pipeline started: %s\n\n", format(pipeline_start, "%Y-%m-%d %H:%M:%S")))

# =============================================================================
# SETUP: Determine project root
# =============================================================================

if (file.exists("05_data/standardized")) {
  project_root <- "."
  scripts_dir <- "06_analysis/scripts"
} else if (file.exists("../05_data/standardized")) {
  project_root <- ".."
  scripts_dir <- "."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
  scripts_dir <- "."
} else {
  stop("Cannot find project root. Run from project directory or 06_analysis/scripts/")
}

# Set working directory to project root for consistent paths
original_wd <- getwd()
setwd(project_root)
cat(sprintf("Working directory: %s\n\n", getwd()))

if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

dirs <- setup_output_dirs(getwd())
run_id <- format(pipeline_start, "%Y%m%d_%H%M%S")
context_df <- data.frame(
  run_id = run_id,
  pipeline_started_at = format(pipeline_start, "%Y-%m-%d %H:%M:%S"),
  fail_fast = !tolower(Sys.getenv("APAL_PIPELINE_CONTINUE_ON_ERROR", "false")) %in% c("1", "true", "yes"),
  stringsAsFactors = FALSE
)
write.csv(context_df, file.path(dirs$output, "pipeline_context_current.csv"), row.names = FALSE)
write.csv(context_df, file.path(dirs$output, sprintf("pipeline_context_%s.csv", run_id)), row.names = FALSE)

Sys.setenv(
  APAL_PIPELINE_RUN_START = format(
    as.POSIXct(format(pipeline_start, tz = "UTC", usetz = TRUE), tz = "UTC"),
    "%Y-%m-%d %H:%M:%OS6",
    tz = "UTC"
  )
)

# =============================================================================
# DEFINE PIPELINE SCRIPTS
# =============================================================================

standardization_scripts <- discover_standardization_scripts(getwd())
standardization_descriptions <- if (length(standardization_scripts) > 0) {
  paste("Standardize", vapply(standardization_scripts, label_script_name, character(1)), "data")
} else {
  character(0)
}

scripts <- c(
  standardization_scripts,
  # 01: Data preparation
  "01_data_preparation.R",
  # 02-07: Core analysis
  "02_survival_thresholds.R",
  "03_growth_thresholds.R",
  "04_growth_rate_comparison.R",
  "05_variance_partitioning.R",
  "06_data_gap_analysis.R",
  "07_integrate_summary_data.R",
  # 08-12: Robustness & supplementary
  "08_climate_demography.R",
  "09_power_analysis.R",
  "10_cross_validation.R",
  "11_context_comparison.R",
  "12_model_selection.R",
  # 13-17: Synthesis
  "13_transition_matrix.R",
  "14_meta_analysis.R",
  "14b_expanded_meta_analysis.R",
  "15_heterogeneity_analysis.R",
  "16_sensitivity_analysis.R",
  "17_update_parameter_lists.R",
  # 18-22: Manuscript figures and manuscript-candidate support figures
  "18_fig1_study_landscape.R",
  "19_fig2_demographic_rates.R",
  "20_fig_size_class_survival_synthesis.R",
  "20b_fig_expanded_forest_plot.R",
  "20c_fig_regional_survival.R",
  "21_fig3_natural_vs_restoration.R",
  "22_fig6_population_model.R",
  # 23: Data gaps figure
  "23_figS2_data_gaps.R",
  # 24-28: Supplementary figures (S3-S14)
  "24_supp_S3_S4.R",
  "25_supp_S5_S6_S7_thresholds_growth.R",
  "26_supp_S8_S9.R",
  "27_supp_S10_S11.R",
  "28_supp_S12_S13_S14.R",
  # 29-40: Context, disturbance, completeness, and scenario extensions
  "29_natural_vs_restoration.R",
  "30_disturbance_sensitivity.R",
  "31_heat_stress_overlay.R",
  "31b_verify_dhw.R",
  "32_disturbance_survival_analysis.R",
  "33_hurricane_exposure.R",
  "34_disturbance_summaries.R",
  "35_curate_literature_scope.R",
  "36_shrinkage_retrogression_summary.R",
  "37_disturbance_size_interaction.R",
  "38_study_window_disturbance_audit.R",
  "39_restoration_subtype_sensitivity.R",
  # 40: Heatwave scenarios (Manzello 2025)
  "40_manzello_heatwave_scenarios.R",
  # 41-47: Advanced dynamic model extensions
  "41_multistate_transition_model.R",
  "42_joint_longitudinal_survival_model.R",
  "43_stochastic_ipm_disturbance_model.R",
  "44_regime_switching_model.R",
  "45_distributed_lag_disturbance_model.R",
  "46_recurrent_event_frailty_model.R",
  "47_spatiotemporal_hierarchical_model.R",
  # Verification
  "23_verification.R",
  # Reporting refresh
  "48_pipeline_refresh_audit.R"
)

script_descriptions <- c(
  standardization_descriptions,
  # 01: Data preparation
  "Data preparation and cleaning",
  # 02-07: Core analysis
  "Survival threshold analysis",
  "Growth threshold analysis",
  "Growth rate analysis (AGR vs RGR)",
  "Variance partitioning (size/space/time)",
  "Data gap analysis and certainty scoring",
  "Integrate summary data",
  # 08-12: Robustness & supplementary
  "Climate-demography integration",
  "Power analysis for future studies",
  "Cross-validation framework",
  "Context comparison (field/nursery/lab)",
  "Model selection tables",
  # 13-17: Synthesis
  "Transition matrix population model",
  "Formal meta-analysis (k=5, random effects)",
  "Expanded meta-analysis (k=17, two-tier)",
  "Heterogeneity analysis (I², Q-tests)",
  "Sensitivity analysis (LOSO, elasticity)",
  "Update parameter lists for API",
  # 18-23: Manuscript figures and manuscript-candidate support figures
  "Figure 1: Study landscape with map",
  "Figure 2: Demographic rates (survival + RGR)",
  "Manuscript-support size-class survival synthesis",
  "Figure 3: Caribbean survival synthesis",
  "Figure S15: Regional survival variation",
  "Figure S8: Shared-range natural vs restoration comparison",
  "Figure 4: Population model & sensitivity",
  # 23: Data gaps figure
  "Figure S2: Data gaps heatmap",
  # 24-28: Supplementary figures (S3-S14)
  "Supplementary S3-S4: Model diagnostics & selection",
  "Supplementary S5-S7: Thresholds & growth",
  "Supplementary S8-S9: Heterogeneity and comparison layer",
  "Supplementary S10-S11: Context and climate layer",
  "Supplementary S12-S14: Sensitivity and projections",
  # 29-40: Context, disturbance, completeness, and scenario extensions
  "Natural vs restoration (within-region + size-matched)",
  "Disturbance sensitivity analysis",
  "Heat stress overlay",
  "DHW/site-year verification",
  "Disturbance survival analysis",
  "Hurricane exposure summary",
  "Disturbance catalogs and summary figures",
  "Literature scope curation",
  "Shrinkage and retrogression synthesis",
  "Disturbance-by-size interaction analysis",
  "Study-window disturbance audit",
  "Restoration subtype sensitivity analysis",
  # 40: Heatwave scenarios
  "Manzello 2025 heatwave scenario projections",
  # 41-47: Advanced dynamic model extensions
  "Advanced multistate transition model",
  "Advanced joint longitudinal-survival model",
  "Advanced stochastic disturbance-driven IPM",
  "Advanced regime-switching hidden-state model",
  "Advanced distributed-lag disturbance model",
  "Advanced recurrent-event frailty model",
  "Advanced spatiotemporal hierarchical model",
  # Verification
  "Pipeline verification",
  # Reporting refresh
  "Refresh pipeline manifests and generated reporting artifacts"
)

# =============================================================================
# RUN PIPELINE
# =============================================================================

results <- data.frame(
  script = scripts,
  description = script_descriptions,
  status = rep("NOT_RUN", length(scripts)),
  duration_sec = NA_real_,
  stringsAsFactors = FALSE
)

fail_fast <- context_df$fail_fast[1]
pipeline_failed <- FALSE

for (i in seq_along(scripts)) {
  script_path <- file.path("06_analysis/scripts", scripts[i])

  cat("─────────────────────────────────────────────────────────────────────────\n")
  cat(sprintf("STEP %d/%d: %s\n", i, length(scripts), script_descriptions[i]))
  cat(sprintf("Script: %s\n", scripts[i]))
  cat("─────────────────────────────────────────────────────────────────────────\n\n")

  script_start <- Sys.time()

  # Run each script as a subprocess to prevent search path pollution
  # (library() calls in one script can mask functions needed by later scripts)
  exit_code <- system2("Rscript", args = script_path, stdout = "", stderr = "")
  script_end <- Sys.time()
  duration <- as.numeric(difftime(script_end, script_start, units = "secs"))
  results$duration_sec[i] <- round(duration, 1)

  if (exit_code == 0) {
    results$status[i] <- "SUCCESS"
    cat(sprintf("\n✓ Completed in %.1f seconds\n\n", duration))
  } else {
    results$status[i] <- "FAILED"
    pipeline_failed <- TRUE
    cat(sprintf("\n✗ FAILED after %.1f seconds (exit code %d)\n\n", duration, exit_code))
    if (fail_fast) {
      cat("Fail-fast mode enabled: stopping pipeline after first failure.\n\n")
      if (i < length(scripts)) {
        results$status[(i + 1):length(scripts)] <- "SKIPPED"
      }
      break
    }
  }
}

# =============================================================================
# PIPELINE SUMMARY
# =============================================================================

pipeline_end <- Sys.time()
total_duration <- as.numeric(difftime(pipeline_end, pipeline_start, units = "mins"))

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════════════╗\n")
cat("║   PIPELINE COMPLETE                                                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════════════╝\n\n")

# Print results table
cat("EXECUTION SUMMARY:\n")
cat("─────────────────────────────────────────────────────────────────────────\n")
cat(sprintf("%-40s %-10s %10s\n", "Script", "Status", "Duration"))
cat("─────────────────────────────────────────────────────────────────────────\n")

for (i in seq_len(nrow(results))) {
  status_symbol <- dplyr::case_when(
    results$status[i] == "SUCCESS" ~ "✓",
    results$status[i] == "FAILED" ~ "✗",
    results$status[i] == "SKIPPED" ~ "•",
    TRUE ~ "·"
  )
  cat(sprintf("%-40s %s %-8s %8.1fs\n",
              results$description[i],
              status_symbol,
              results$status[i],
              results$duration_sec[i]))
}

cat("─────────────────────────────────────────────────────────────────────────\n")
cat(sprintf("%-40s %-10s %8.1fm\n", "TOTAL", "", total_duration))
cat("─────────────────────────────────────────────────────────────────────────\n")

# Summary statistics
n_success <- sum(results$status == "SUCCESS")
n_failed <- sum(results$status == "FAILED")
n_skipped <- sum(results$status == "SKIPPED")
n_not_run <- sum(results$status == "NOT_RUN")

cat(sprintf("\nResults: %d/%d scripts completed successfully\n", n_success, length(scripts)))
if (n_skipped > 0) {
  cat(sprintf("Skipped: %d script(s)\n", n_skipped))
}
if (n_not_run > 0) {
  cat(sprintf("Not run: %d script(s)\n", n_not_run))
}

if (n_failed > 0) {
  cat("\nFAILED SCRIPTS:\n")
  failed <- results[results$status == "FAILED", ]
  for (i in seq_len(nrow(failed))) {
    cat(sprintf("  - %s\n", failed$script[i]))
  }
}

# =============================================================================
# OUTPUT VERIFICATION
# =============================================================================

cat("\n")
cat("OUTPUT VERIFICATION:\n")
cat("─────────────────────────────────────────────────────────────────────────\n")

artifact_status_file <- "06_analysis/output/canonical_artifact_status.csv"
if (file.exists(artifact_status_file)) {
  artifact_status <- read.csv(artifact_status_file, stringsAsFactors = FALSE)
  categories <- split(artifact_status, artifact_status$category)
  for (category in names(categories)) {
    category_df <- categories[[category]]
    exists_count <- sum(category_df$exists %in% TRUE, na.rm = TRUE)
    generated_count <- sum(category_df$generated_this_run %in% TRUE, na.rm = TRUE)
    status <- ifelse(exists_count == nrow(category_df), "✓", "⚠")
    cat(sprintf("  %s %s: %d/%d files present, %d regenerated this run\n",
                status, category, exists_count, nrow(category_df), generated_count))
  }
} else {
  registry <- canonical_artifact_registry(getwd())
  categories <- split(registry, registry$category)
  for (category in names(categories)) {
    category_df <- categories[[category]]
    exists_count <- sum(file.exists(category_df$path))
    status <- ifelse(exists_count == nrow(category_df), "✓", "⚠")
    cat(sprintf("  %s %s: %d/%d files present\n",
                status, category, exists_count, nrow(category_df)))
  }
}

# =============================================================================
# SAVE PIPELINE LOG
# =============================================================================

log_file <- sprintf("06_analysis/output/pipeline_log_%s.csv",
                    format(pipeline_start, "%Y%m%d_%H%M%S"))
write.csv(results, log_file, row.names = FALSE)
cat(sprintf("\nPipeline log saved: %s\n", log_file))

# =============================================================================
# CAPTURE SESSION INFO
# =============================================================================

session_info_file <- "06_analysis/output/session_info.txt"
tryCatch({
  si <- utils::capture.output(utils::sessionInfo())
  writeLines(c(
    sprintf("Session info captured: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    sprintf("Pipeline run ID: %s", run_id),
    "",
    si
  ), con = session_info_file)
  cat(sprintf("Session info saved: %s\n", session_info_file))
}, error = function(e) {
  cat(sprintf("Warning: could not save session info: %s\n", conditionMessage(e)))
})

# Restore working directory
setwd(original_wd)
Sys.unsetenv("APAL_PIPELINE_RUN_START")

cat(sprintf("\nPipeline finished: %s\n", format(pipeline_end, "%Y-%m-%d %H:%M:%S")))
cat(sprintf("Total runtime: %.1f minutes\n\n", total_duration))

# Return results invisibly for programmatic use
invisible(results)
