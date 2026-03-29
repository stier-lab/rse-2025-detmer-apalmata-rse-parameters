################################################################################
# run_all.R - Master Script for A. palmata Demographic Analysis Pipeline
################################################################################
#
# PURPOSE:
#   Execute the complete analysis pipeline in the correct order, from data
#   preparation through publication figures and population modeling.
#
# USAGE:
#   From project root:
#     Rscript analysis/scripts/run_all.R
#
#   Or from analysis/scripts directory:
#     Rscript run_all.R
#
# PIPELINE ORDER (sequential numbering):
#   01     = Data preparation
#   02-07  = Core analysis (survival, growth, variance, gaps, integration)
#   08-12  = Robustness & supplementary (climate, power, CV, context, model selection)
#   13-17  = Synthesis (matrix, meta-analysis, heterogeneity, sensitivity, parameters)
#   18-23  = Manuscript figures (6 main + supplementary)
#   24-28  = Supplementary figures (S3-S14)
#   23     = Verification
#
#   01 → 02-07 → 08-12 → 13-17 → 18-23 + 24-28 → 23_verification
#
# OUTPUTS:
#   - All files in 06_analysis/output/
#   - All figures in 06_analysis/figures/manuscript/ (PNG + PDF)
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

# =============================================================================
# DEFINE PIPELINE SCRIPTS
# =============================================================================

scripts <- c(
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
  # 18-22: Manuscript figures (6 main)
  "18_fig1_study_landscape.R",
  "19_fig2_demographic_rates.R",
  "20_fig_size_class_survival_synthesis.R",
  "20b_fig_expanded_forest_plot.R",
  "20c_fig_regional_survival.R",
  "21_fig3_natural_vs_restoration.R",
  "22_fig6_population_model.R",
  # 23: Data gaps (supplementary)
  "23_figS2_data_gaps.R",
  # 24-28: Supplementary figures (S3-S14)
  "24_supp_S3_S4.R",
  "25_supp_S5_S6_S7_thresholds_growth.R",
  "26_supp_S8_S9.R",
  "27_supp_S10_S11.R",
  "28_supp_S12_S13_S14.R",
  # Verification
  "23_verification.R"
)

script_descriptions <- c(
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
  "Expanded meta-analysis (k=16, two-tier)",
  "Heterogeneity analysis (I², Q-tests)",
  "Sensitivity analysis (LOSO, elasticity)",
  "Update parameter lists for API",
  # 18-23: Manuscript figures (6 main) + supplementary
  "Figure 1: Study landscape with map",
  "Figure 2: Demographic rates (survival + RGR)",
  "Figure 4: Size-class survival synthesis (k=15)",
  "Figure 5: Expanded forest plot (k=16)",
  "Figure S15: Regional survival variation",
  "Figure 3: Natural vs restoration comparison",
  "Figure 6: Population model & sensitivity",
  # 23: Data gaps (supplementary)
  "Figure S2: Data gaps heatmap",
  # 24-28: Supplementary figures (S3-S14)
  "Supplementary S3-S4: Model diagnostics & selection",
  "Supplementary S5-S7: Thresholds & growth",
  "Supplementary S8-S9: Forest plots & heterogeneity",
  "Supplementary S10-S11: Context & climate",
  "Supplementary S12-S14: Sensitivity & projections",
  # Verification
  "Pipeline verification"
)

# =============================================================================
# RUN PIPELINE
# =============================================================================

results <- data.frame(
  script = scripts,
  description = script_descriptions,
  status = NA_character_,
  duration_sec = NA_real_,
  stringsAsFactors = FALSE
)

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
    cat(sprintf("\n✗ FAILED after %.1f seconds (exit code %d)\n\n", duration, exit_code))
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
  status_symbol <- ifelse(results$status[i] == "SUCCESS", "✓", "✗")
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

cat(sprintf("\nResults: %d/%d scripts completed successfully\n", n_success, length(scripts)))

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

# Check key outputs
output_checks <- list(
  "Prepared data" = c(
    "06_analysis/output/prepared_survival_data.rds",
    "06_analysis/output/prepared_growth_data.rds"
  ),
  "Threshold results" = c(
    "06_analysis/output/survival_thresholds.csv",
    "06_analysis/output/growth_thresholds.csv"
  ),
  "Model outputs" = c(
    "06_analysis/output/survival_threshold_models.rds",
    "06_analysis/output/growth_threshold_models.rds"
  ),
  "Gap analysis" = c(
    "06_analysis/output/gap_prioritization.csv",
    "06_analysis/output/certainty_by_size_region.csv"
  ),
  "Transition matrix" = c(
    "06_analysis/output/transition_matrix.csv",
    "06_analysis/output/population_parameters.csv"
  ),
  "Meta-analysis" = c(
    "06_analysis/output/meta_analysis_results.csv",
    "06_analysis/output/expanded_meta_analysis_results.csv"
  ),
  "Manuscript figures" = c(
    "06_analysis/figures/manuscript/Fig1_study_landscape.png",
    "06_analysis/figures/manuscript/Fig2_demographic_rates.png",
    "06_analysis/figures/manuscript/Fig3_natural_vs_restoration.png",
    "06_analysis/figures/manuscript/Fig4_size_class_survival.png",
    "06_analysis/figures/manuscript/Fig5_expanded_forest_plot.png",
    "06_analysis/figures/manuscript/Fig6_population_model.png"
  ),
  "Supplementary figures" = c(
    "06_analysis/figures/supplementary/FigS1_size_distribution.png",
    "06_analysis/figures/supplementary/FigS2_data_gaps.png",
    "06_analysis/figures/supplementary/FigS3_model_diagnostics.png",
    "06_analysis/figures/supplementary/FigS5_threshold_analysis.png",
    "06_analysis/figures/supplementary/FigS8_forest_plots.png",
    "06_analysis/figures/supplementary/FigS10_context_comparison.png",
    "06_analysis/figures/supplementary/FigS12_sensitivity.png",
    "06_analysis/figures/supplementary/FigS15_regional_survival.png"
  )
)

for (category in names(output_checks)) {
  files <- output_checks[[category]]
  exists_count <- sum(file.exists(files))
  status <- ifelse(exists_count == length(files), "✓", "⚠")
  cat(sprintf("  %s %s: %d/%d files\n", status, category, exists_count, length(files)))
}

# =============================================================================
# SAVE PIPELINE LOG
# =============================================================================

log_file <- sprintf("06_analysis/output/pipeline_log_%s.csv",
                    format(pipeline_start, "%Y%m%d_%H%M%S"))
write.csv(results, log_file, row.names = FALSE)
cat(sprintf("\nPipeline log saved: %s\n", log_file))

# Restore working directory
setwd(original_wd)

cat(sprintf("\nPipeline finished: %s\n", format(pipeline_end, "%Y-%m-%d %H:%M:%S")))
cat(sprintf("Total runtime: %.1f minutes\n\n", total_duration))

# Return results invisibly for programmatic use
invisible(results)
