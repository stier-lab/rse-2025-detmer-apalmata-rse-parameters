################################################################################
# 52_colony_lesion_state.R - Derive per-colony partial mortality state
################################################################################
#
# PURPOSE:
#   Compute whether each colony-interval shows evidence of active partial
#   mortality (lesioned state), used as input to the sexual-fecundity lesion
#   penalty layer (script 55).
#
# HYPOTHESIS:
#   Population-level sexual output is reduced 10-30% relative to naive
#   size-scaled estimate because a substantial fraction of surviving adult
#   tissue is post-lesion. Lesioned colonies produce ~20% less egg volume
#   (Piñón-González 2018), and lesions >20 cm² do not recover (Lirman 2000b).
#
# METHOD:
#   For each coral_id with size_live_cm2 tracked across intervals, flag as
#   lesioned if relative tissue loss between consecutive surveys exceeds a
#   threshold (default 10%, interpreted as meaningful partial mortality).
#   Aggregate to (study × size_class × year) to produce a fraction_lesioned
#   population summary.
#
# INPUTS:
#   - 05_data/standardized/apal_surv_ind.csv
#   - 06_analysis/output/shrinkage_frequency_by_sc.csv  (optional cross-check)
#
# OUTPUTS:
#   - 05_data/standardized/apal_lesion_state.csv
#       Columns: study, region, coral_id, survey_yr, size_live_cm2,
#                prev_size_live_cm2, tissue_loss_frac, is_lesioned
#   - 05_data/standardized/apal_lesion_population_fraction.csv
#       Summary: study × size_class → fraction_lesioned (reproductive adults only)
#
# CITATIONS:
#   Piñón-González 2018   -- fecundity_reduction 20% for lesioned colonies
#                            (apal_life_history_parameters.csv row 3)
#   Lirman 2000b          -- critical lesion threshold 20 cm²
#                            (apal_life_history_parameters.csv row 19)
#
# Author: Detmer & Stier Lab
# Date: 2026-04-18
################################################################################

source("06_analysis/scripts/utils/shared_utilities.R")

print_header("Script 52: Derive colony lesion state")

# --- Parameters ---
LESION_THRESHOLD <- 0.10  # 10% relative tissue loss flags lesioned state
REPR_SIZE_CUTOFF <- 900   # Analyse reproductive adults (SC4+) for population penalty

# --- Load ---
surv <- read.csv("05_data/standardized/apal_surv_ind.csv", stringsAsFactors = FALSE)
cat(sprintf("  Loaded %d observations from %s\n", nrow(surv),
            "apal_surv_ind.csv"))

# --- Compute per-interval tissue loss ---
# Prefer size_live_cm2 (live tissue area); fall back to size_cm2 if missing
surv <- surv %>%
  mutate(size_use = ifelse(!is.na(size_live_cm2), size_live_cm2, size_cm2))

surv_lag <- surv %>%
  arrange(study, coral_id, survey_yr) %>%
  group_by(study, coral_id) %>%
  mutate(
    prev_size_live_cm2 = lag(size_use),
    tissue_loss_frac = ifelse(!is.na(prev_size_live_cm2) & prev_size_live_cm2 > 0,
                              (prev_size_live_cm2 - size_use) / prev_size_live_cm2,
                              NA_real_),
    is_lesioned = !is.na(tissue_loss_frac) & tissue_loss_frac > LESION_THRESHOLD
  ) %>%
  ungroup()

print_subheader("Tissue loss distribution")
tl_valid <- surv_lag$tissue_loss_frac[!is.na(surv_lag$tissue_loss_frac)]
cat(sprintf("  Valid tissue-loss intervals: %d\n", length(tl_valid)))
cat(sprintf("  Mean tissue loss: %.3f\n", mean(tl_valid)))
cat(sprintf("  Median tissue loss: %.3f\n", median(tl_valid)))
cat(sprintf("  %% showing >%.0f%% loss (lesioned): %.1f%%\n",
            LESION_THRESHOLD * 100,
            100 * mean(tl_valid > LESION_THRESHOLD)))

# --- Aggregate: reproductive-adult fraction lesioned per study × size class ---
# Focus on colonies ≥ REPR_SIZE_CUTOFF (SC4 and SC5)
print_subheader(sprintf("Population fraction lesioned (size ≥ %.0f cm²)",
                        REPR_SIZE_CUTOFF))

surv_lag$size_class <- cut(surv_lag$size_use,
                            breaks = SIZE_BREAKS, labels = SIZE_LABELS,
                            include.lowest = TRUE)

popfrac <- surv_lag %>%
  filter(!is.na(is_lesioned),
         size_use >= REPR_SIZE_CUTOFF) %>%
  group_by(study, size_class) %>%
  summarise(
    n_intervals = n(),
    n_lesioned = sum(is_lesioned),
    fraction_lesioned = n_lesioned / n_intervals,
    .groups = "drop"
  )

print(as.data.frame(popfrac))

# --- Overall reproductive-adult lesion fraction (for scenario framework) ---
overall_fraction <- popfrac %>%
  summarise(
    n_intervals_total = sum(n_intervals),
    n_lesioned_total = sum(n_lesioned),
    fraction_lesioned_overall = n_lesioned_total / n_intervals_total
  )

cat(sprintf("\n  OVERALL: %d/%d reproductive-adult intervals lesioned = %.1f%%\n",
            overall_fraction$n_lesioned_total,
            overall_fraction$n_intervals_total,
            100 * overall_fraction$fraction_lesioned_overall))

# --- Write outputs ---
colony_cols <- c("study", "region", "coral_id", "survey_yr",
                 "size_live_cm2", "size_cm2", "size_use",
                 "prev_size_live_cm2", "tissue_loss_frac", "is_lesioned",
                 "size_class")

lesion_path <- "05_data/standardized/apal_lesion_state.csv"
write.csv(surv_lag[, colony_cols], lesion_path, row.names = FALSE)
print_success(sprintf("Saved %s (%d rows)", lesion_path, nrow(surv_lag)))

pop_path <- "05_data/standardized/apal_lesion_population_fraction.csv"
write.csv(popfrac, pop_path, row.names = FALSE)
print_success(sprintf("Saved %s (%d study × SC summaries)",
                      pop_path, nrow(popfrac)))

cat(sprintf("\n  FRACTION_LESIONED for scenario framework: %.3f\n",
            overall_fraction$fraction_lesioned_overall))
cat("  (Use this value in script 60 scenario S3 config.)\n\n")

cat("Done.\n")
