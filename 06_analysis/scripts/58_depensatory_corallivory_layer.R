################################################################################
# 58_depensatory_corallivory_layer.R - Allee/density-dependent SC1-SC2 (Idea 6)
################################################################################
#
# PURPOSE:
#   Wrap apply_density_dep_SC12() (defined in utils/03_matrix_functions.R) to
#   produce three revised survival vectors under low / median / high colony
#   densities, for the scenario-comparison pipeline (script 60).
#
# STATUS (2026-07-21): OFF BY DEFAULT / data-thin. Kept as a toggleable sensitivity
#   option only. The causal link this layer encodes (low coral density -> higher
#   SC1-SC2 mortality RATE) is NOT established in the source; Williams & Miller
#   2012 show only that snails CONCENTRATE as coral declines (Fig 4, correlational)
#   and explicitly state absolute snail loss is "chronic and somewhat independent
#   of A. palmata abundance" and "could not be definitively linked to snail
#   occupation." The S(D)=S0*D/(K+D) form and K are modeling ASSUMPTIONS, not fit.
#
# CITATION:
#   Williams & Miller 2012 -- 27% of *background* live-area loss with <2 snails/
#   colony; snail-per-coral density rises as coral declines (Fig 4). Consumption
#   16 cm^2/day is Brawley & Adey 1982 (in Williams & Miller); Miller 2001 = 3.37
#   cm^2/day per occupied colony. See apal_life_history_parameters.csv rows 22-23.
#
# HYPOTHESIS:
#   Small (SC1-SC2) colony survival saturates with overall colony density
#   (Allee effect): at low densities Coralliophila concentrates on the few
#   available colonies, compounding mortality.
#
# INPUTS:
#   - 05_data/standardized/apal_surv_ind.csv (for density proxy: mean group_N)
#   - 06_analysis/output/transition_matrix.rds (baseline S)
#
# OUTPUT:
#   06_analysis/output/depensatory_corallivory.rds
#     list(baseline, low_density, median_density, high_density,
#          density_summary, density_K, note)
#
# Author: Detmer & Stier Lab
# Date:   2026-04-17
################################################################################

source("06_analysis/scripts/utils/shared_utilities.R")

print_header("Script 58: Depensatory corallivory layer (Idea 6)")

output_dir <- "06_analysis/output"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# Baseline
# =============================================================================
trans <- readRDS(file.path(output_dir, "transition_matrix.rds"))
baseline_S <- trans$survival_rates
if (is.null(baseline_S) || length(baseline_S) != 5) baseline_S <- trans$survival
names(baseline_S) <- SIZE_LABELS
print_success(sprintf("Baseline S loaded: %s",
                      paste(sprintf("%.3f", baseline_S), collapse = ", ")))

# =============================================================================
# Density proxy: mean group_N per study x year (colonies per plot)
# =============================================================================
surv <- read.csv("05_data/standardized/apal_surv_ind.csv",
                 stringsAsFactors = FALSE)
cat(sprintf("  Survival rows: %d\n", nrow(surv)))

density_df <- surv %>%
  dplyr::filter(!is.na(group_N), group_N > 0) %>%
  dplyr::group_by(study, survey_yr) %>%
  dplyr::summarise(mean_group_N = mean(group_N, na.rm = TRUE),
                   .groups = "drop")

if (nrow(density_df) < 1) {
  warning("No valid group_N data; saving placeholder.")
  placeholder <- list(
    baseline = baseline_S,
    low_density = baseline_S,
    median_density = baseline_S,
    high_density = baseline_S,
    density_summary = NULL,
    density_K = NA_real_,
    note = "No density proxy available; baseline survival unchanged"
  )
  saveRDS(placeholder, file.path(output_dir, "depensatory_corallivory.rds"))
  print_warn("Saved placeholder depensatory_corallivory.rds")
  cat("Done.\n"); quit(save = "no", status = 0)
}

density_summary <- data.frame(
  metric = c("n_study_year_cells", "min_group_N", "median_group_N",
             "mean_group_N",       "max_group_N"),
  value  = c(nrow(density_df),
             min(density_df$mean_group_N),
             median(density_df$mean_group_N),
             mean(density_df$mean_group_N),
             max(density_df$mean_group_N))
)
cat("\n  Density proxy summary (study x year mean group_N):\n")
print(density_summary)

median_density <- median(density_df$mean_group_N)

# Normalize to median = 1 so that the saturating function S(D) = S0 * D/(K+D)
# with K = 1 gives low=0.25/1.25=0.20, median=1/2=0.50, high=4/5=0.80 of S0
# for SC1-SC2, while leaving SC3-SC5 unchanged.
K_half <- 1.0
density_levels <- c(low = 0.25, median = 1.0, high = 4.0)

cat(sprintf("\n  Half-saturation K = %.2f (on density-index scale)\n", K_half))
cat("  Density-index scenarios (relative to median):\n")
for (nm in names(density_levels)) {
  cat(sprintf("    %-7s: density_index = %.2f -> modifier = %.3f\n",
              nm, density_levels[[nm]],
              density_levels[[nm]] / (K_half + density_levels[[nm]])))
}

# =============================================================================
# Apply
# =============================================================================
S_low    <- apply_density_dep_SC12(baseline_S, density_levels["low"],    K = K_half)
S_median <- apply_density_dep_SC12(baseline_S, density_levels["median"], K = K_half)
S_high   <- apply_density_dep_SC12(baseline_S, density_levels["high"],   K = K_half)

cmp <- data.frame(
  size_class = SIZE_LABELS,
  baseline        = round(baseline_S, 4),
  low_density     = round(S_low, 4),
  median_density  = round(S_median, 4),
  high_density    = round(S_high, 4)
)
cat("\n  SC1/SC2 survival across density levels (SC3-SC5 unchanged):\n")
print(cmp)

# =============================================================================
# Save
# =============================================================================
out <- list(
  baseline         = baseline_S,
  low_density      = S_low,
  median_density   = S_median,
  high_density     = S_high,
  density_summary  = density_summary,
  density_K        = K_half,
  density_levels   = density_levels,
  note             = "apply_density_dep_SC12 saturating modifier; baseline=median density / (K + median density)"
)
saveRDS(out, file.path(output_dir, "depensatory_corallivory.rds"))
print_success("Saved 06_analysis/output/depensatory_corallivory.rds")

cat("Done.\n")
