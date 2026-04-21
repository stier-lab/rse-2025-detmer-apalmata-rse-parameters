################################################################################
# 55_lesion_fecundity_penalty.R - Idea 3: Partial-mortality fecundity penalty
################################################################################
#
# PURPOSE:
#   Apply the Pinon-Gonzalez 2018 fecundity penalty (20% reduction per lesioned
#   reproductive adult) to the baseline sexual-fecundity matrix F_sex from
#   script 53. This implements scenario S3 of the PRD. The penalty is scaled
#   by the population-level fraction of reproductive-size colonies (SC4+SC5)
#   currently in a lesioned state, derived in script 52 from tissue-loss
#   tracking of individual colonies.
#
# HYPOTHESIS:
#   A substantial fraction of surviving adult tissue is post-lesion, reducing
#   effective sexual output by 10-30%. S3 lambda should be <= S2 lambda.
#
# INPUTS:
#   - 06_analysis/output/sexual_fecundity_matrix.rds        (from script 53)
#   - 05_data/standardized/apal_lesion_population_fraction.csv  (from script 52)
#       Columns: study, size_class, n_intervals, n_lesioned, fraction_lesioned
#
# OUTPUTS:
#   - 06_analysis/output/lesion_penalty_F_sex.rds
#       list(F_sex_penalized, fraction_lesioned, penalty, by_size_class)
#
# CITATIONS:
#   Pinon-Gonzalez 2018 -- fecundity_reduction 20% for lesioned colonies
#                          (LHP row 3; Mexico, egg volume)
#   Lirman 2000b        -- lesions >20 cm^2 rarely recover (LHP rows 15-18)
#
# Author: Detmer & Stier Lab
# Date: 2026-04-17
################################################################################

source("06_analysis/scripts/utils/shared_utilities.R")

print_header("Script 55: Apply lesion fecundity penalty (S3)")

# --- Paths & constants ---
f_sex_path   <- file.path("06_analysis", "output",
                          "sexual_fecundity_matrix.rds")
lesion_path  <- file.path("05_data", "standardized",
                          "apal_lesion_population_fraction.csv")
out_path     <- file.path("06_analysis", "output",
                          "lesion_penalty_F_sex.rds")

PENALTY            <- 0.20                     # Pinon-Gonzalez 2018
REPRODUCTIVE_SCS   <- c("SC4", "SC5")          # Reproductive-size classes

# --- Load baseline F_sex ---
if (!file.exists(f_sex_path)) {
  print_warn(sprintf("Missing %s - run script 53 first. Aborting.", f_sex_path))
  quit(save = "no", status = 0)
}
base <- readRDS(f_sex_path)
F_sex <- base$F_sex

# --- Load lesion fractions (script 52 output) ---
fraction_lesioned <- 0
by_size_class     <- NULL
by_study_repr     <- NULL

if (!file.exists(lesion_path)) {
  print_warn(sprintf("Missing %s - run script 52 first. Using fraction=0.",
                     lesion_path))
} else {
  lesion <- read.csv(lesion_path, stringsAsFactors = FALSE)
  cat(sprintf("  Loaded %d study x size-class rows from %s\n",
              nrow(lesion), basename(lesion_path)))

  repr <- lesion %>%
    filter(size_class %in% REPRODUCTIVE_SCS)

  if (nrow(repr) == 0) {
    print_warn("No reproductive-size classes (SC4/SC5) in lesion data - fraction=0")
  } else {
    # n_intervals-weighted fraction across reproductive adults
    fraction_lesioned <- with(repr, sum(n_lesioned) / sum(n_intervals))

    by_size_class <- repr %>%
      group_by(size_class) %>%
      summarise(
        n_intervals       = sum(n_intervals),
        n_lesioned        = sum(n_lesioned),
        fraction_lesioned = sum(n_lesioned) / sum(n_intervals),
        .groups = "drop"
      )

    by_study_repr <- repr %>%
      group_by(study) %>%
      summarise(
        n_intervals       = sum(n_intervals),
        n_lesioned        = sum(n_lesioned),
        fraction_lesioned = sum(n_lesioned) / sum(n_intervals),
        .groups = "drop"
      )
  }
}

print_subheader("Lesion fraction (reproductive-size adults, SC4+SC5)")
cat(sprintf("  Overall fraction_lesioned: %.3f\n", fraction_lesioned))
cat(sprintf("  Penalty per lesioned colony: %.2f (Pinon-Gonzalez 2018)\n", PENALTY))
cat(sprintf("  Effective multiplier on F_sex: %.4f\n",
            1 - PENALTY * fraction_lesioned))

if (!is.null(by_size_class)) {
  cat("\n  By size class:\n")
  print(as.data.frame(by_size_class))
}
if (!is.null(by_study_repr)) {
  cat("\n  By study:\n")
  print(as.data.frame(by_study_repr))
}

# --- Apply penalty via shared helper ---
F_sex_penalized <- apply_lesion_penalty(F_sex,
                                        fraction_lesioned = fraction_lesioned,
                                        penalty = PENALTY)

print_subheader("SC1 row totals before / after lesion penalty")
cat(sprintf("  Baseline (S1): %.3f\n", sum(F_sex["SC1", ])))
cat(sprintf("  Penalised (S3): %.3f\n", sum(F_sex_penalized["SC1", ])))
cat(sprintf("  Reduction: %.2f%%\n",
            100 * (1 - sum(F_sex_penalized["SC1", ]) / sum(F_sex["SC1", ]))))

# --- Package output ---
out <- list(
  F_sex_penalized   = F_sex_penalized,
  fraction_lesioned = fraction_lesioned,
  penalty           = PENALTY,
  by_size_class     = by_size_class,
  by_study          = by_study_repr,
  base_F_sex        = F_sex,
  source            = "Pinon-Gonzalez 2018 (20% egg-volume reduction, lesioned colonies)",
  generated         = Sys.time()
)

saveRDS(out, out_path)
print_success(sprintf("Saved %s", out_path))

cat("\nDone.\n")
