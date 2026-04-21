################################################################################
# 54_sterility_lag_layer.R - Idea 2: 4-yr post-disturbance sterility lag
################################################################################
#
# PURPOSE:
#   Scale the baseline sexual-fecundity matrix F_sex (from script 53) by the
#   expected fraction of reproductive adults currently within a 4-year post-
#   disturbance sterility window. This implements scenario S2 of the PRD:
#   Lirman 2000a documented that fragmented / disturbed A. palmata colonies
#   remain reproductively inactive for ~4 yr before resuming gamete output.
#
# HYPOTHESIS:
#   Restoration cohorts and disturbance-exposed natural populations rarely
#   reach 4-year reproductive maturity without interruption, so realised
#   sexual fecundity is much lower than the size-threshold F_sex alone would
#   predict. S2 lambda should be <= S1 lambda.
#
# INPUTS:
#   - 06_analysis/output/sexual_fecundity_matrix.rds  (from script 53)
#   - 05_data/standardized/apal_surv_ind.csv
#       * fragment column == "Y"          -> colony experienced fragmentation
#       * disturbance column non-empty    -> disturbance-affected observation
#       * Neely et al. 2022: 2014 disease event; 2014-2017 intervals sterile
#
# OUTPUTS:
#   - 06_analysis/output/sterility_lag_F_sex.rds
#       list(conservative = F_sex_cons, high_impact = F_sex_high,
#            fraction_observed, fraction_high_impact, by_study)
#
# CITATIONS:
#   Lirman 2000a  -- fragment_sterility duration 4 years (LHP row 25)
#
# Author: Detmer & Stier Lab
# Date: 2026-04-17
################################################################################

source("06_analysis/scripts/utils/shared_utilities.R")

print_header("Script 54: Apply 4-yr post-disturbance sterility lag (S2)")

# --- Paths & constants ---
f_sex_path      <- file.path("06_analysis", "output", "sexual_fecundity_matrix.rds")
surv_path       <- file.path("05_data", "standardized", "apal_surv_ind.csv")
out_path        <- file.path("06_analysis", "output", "sterility_lag_F_sex.rds")

LAG_YEARS       <- 4      # Lirman 2000a
REPR_SIZE       <- 4000   # cm^2; reproductive-size cutoff (Vardi 2011)
NEELY_EVENT_YR  <- 2014   # Neely 2022 disease catastrophe
HIGH_IMPACT     <- 0.40   # PRD scenario: all of FL Keys post-2014

# --- Load baseline F_sex ---
if (!file.exists(f_sex_path)) {
  print_warn(sprintf("Missing %s - run script 53 first. Aborting.", f_sex_path))
  quit(save = "no", status = 0)
}
base <- readRDS(f_sex_path)
F_sex <- base$F_sex

# --- Load survival data ---
if (!file.exists(surv_path)) {
  print_warn(sprintf("Missing %s - cannot compute observed disturbance fraction",
                     surv_path))
  surv <- NULL
} else {
  surv <- read.csv(surv_path, stringsAsFactors = FALSE)
}

# --- Flag reproductive-size colony-year observations within lag window ---
fraction_observed <- NA_real_
by_study <- NULL

if (!is.null(surv)) {
  surv <- surv %>%
    mutate(size_use = ifelse(!is.na(size_live_cm2), size_live_cm2, size_cm2))

  repro <- surv %>% filter(!is.na(size_use), size_use >= REPR_SIZE)

  # Per-colony first disturbance / fragmentation year
  repro <- repro %>%
    mutate(
      is_fragment = toupper(as.character(fragment)) %in% c("Y", "YES", "TRUE", "T"),
      has_dist    = !is.na(disturbance) & nchar(trimws(as.character(disturbance))) > 0
    )

  dist_years <- repro %>%
    filter(is_fragment | has_dist) %>%
    group_by(study, coral_id) %>%
    summarise(first_dist_yr = min(survey_yr, na.rm = TRUE), .groups = "drop")

  repro_lag <- repro %>%
    left_join(dist_years, by = c("study", "coral_id")) %>%
    mutate(
      # Neely 2014 disease event applies to entire FL Keys post-2014
      neely_window = study == "neely_et_al_2022" &
                     survey_yr >= NEELY_EVENT_YR &
                     survey_yr < (NEELY_EVENT_YR + LAG_YEARS),
      colony_window = !is.na(first_dist_yr) &
                      survey_yr >= first_dist_yr &
                      survey_yr < (first_dist_yr + LAG_YEARS),
      within_lag = neely_window | colony_window
    )

  fraction_observed <- mean(repro_lag$within_lag, na.rm = TRUE)

  by_study <- repro_lag %>%
    group_by(study) %>%
    summarise(
      n_obs          = n(),
      n_within_lag   = sum(within_lag, na.rm = TRUE),
      fraction_lag   = mean(within_lag, na.rm = TRUE),
      .groups = "drop"
    )
}

if (is.na(fraction_observed)) fraction_observed <- 0

print_subheader("Observed fraction of reproductive-size adults within 4-yr lag")
cat(sprintf("  Overall fraction_recently_disturbed: %.3f\n", fraction_observed))
cat(sprintf("  High-impact scenario (PRD): %.3f (FL Keys post-2014)\n", HIGH_IMPACT))
if (!is.null(by_study)) {
  cat("\n  By-study contribution:\n")
  print(as.data.frame(by_study))
}

# --- Apply disturbance lag at two intensities ---
F_sex_conservative <- apply_disturbance_lag(F_sex,
                                            fraction_recently_disturbed = fraction_observed,
                                            lag_years = LAG_YEARS)
F_sex_high_impact  <- apply_disturbance_lag(F_sex,
                                            fraction_recently_disturbed = HIGH_IMPACT,
                                            lag_years = LAG_YEARS)

print_subheader("F_sex SC1 row totals before / after sterility lag")
cat(sprintf("  S1 (baseline):           %.3f\n", sum(F_sex["SC1", ])))
cat(sprintf("  S2 conservative (%.3f): %.3f\n",
            fraction_observed, sum(F_sex_conservative["SC1", ])))
cat(sprintf("  S2 high-impact  (%.3f): %.3f\n",
            HIGH_IMPACT, sum(F_sex_high_impact["SC1", ])))

# --- Package output ---
out <- list(
  conservative          = F_sex_conservative,
  high_impact           = F_sex_high_impact,
  fraction_observed     = fraction_observed,
  fraction_high_impact  = HIGH_IMPACT,
  lag_years             = LAG_YEARS,
  by_study              = by_study,
  base_F_sex            = F_sex,
  source                = "Lirman 2000a (4-yr fragment sterility)",
  generated             = Sys.time()
)

saveRDS(out, out_path)
print_success(sprintf("Saved %s", out_path))

cat("\nDone.\n")
