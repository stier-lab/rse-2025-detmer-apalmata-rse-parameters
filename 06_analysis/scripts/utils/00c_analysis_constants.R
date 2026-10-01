################################################################################
# 00c_analysis_constants.R - Analysis Constants
################################################################################

# --- Size class break points (cm²) ---
#   SC1: 0-10      (recruits/settlers)
#   SC2: 10-100    (small juveniles)
#   SC3: 100-900   (large juveniles)
#   SC4: 900-4000  (subadults)
#   SC5: >4000     (reproductive adults)
SIZE_BREAKS <- c(0, 10, 100, 900, 4000, Inf)

# Canonical short labels — the standard used across all scripts
SIZE_LABELS <- c("SC1", "SC2", "SC3", "SC4", "SC5")

# Descriptive labels with units (for publication display)
SIZE_LABELS_DESCRIPTIVE <- c(
  "SC1 (0-10 cm\u00B2)", "SC2 (10-100 cm\u00B2)", "SC3 (100-900 cm\u00B2)",
  "SC4 (900-4000 cm\u00B2)", "SC5 (>4000 cm\u00B2)"
)

# Internal documentation labels
SIZE_LABELS_FULL <- c("SC1_recruit", "SC2_small_juv", "SC3_large_juv",
                      "SC4_subadult", "SC5_adult")

# Backward-compatible aliases
SIZE_LABELS_SHORT <- SIZE_LABELS
SIZE_LABELS_DESC  <- SIZE_LABELS_FULL

# --- Study metadata ---
# Number of unique studies contributing to the expanded meta-analysis.
# The original individual-level meta used k=5; after adding summary-level
# studies the expanded meta has k=17 unique studies (22 study-level effects,
# because NOAA, Vardi, and Garrison are each split into sub-effects).
N_STUDIES <- 17L
N_EFFECTS <- 22L   # total study-level effects in expanded meta-analysis
NOAA_DATA_FRACTION <- 0.78  # NOAA = 78% of individual-level observations

# Summary-data rows excluded by the 2026-03-26 extraction audit.  This is the
# single source of truth for analysis scripts that read the standardized
# summary survival or growth files.  The exclusions remove non-comparable
# life stages (settlers/recruits and micro-fragments), duplicate/overlapping
# records, and records that do not estimate whole-colony survival.
AUDIT_EXCLUDED_STUDIES <- c(
  "roth_et_al_2013",
  "ramos_et_al_2024",
  "muller_et_al_2008",
  "sutherland_et_al_2016",
  "fundemar_recruits",
  "chamberland_et_al_2015",
  "papke_et_al_2021",
  "mendoza_quiroz_et_al_2023"
)

# --- Population-origin classification ---
# `fragment` records physical fragmentation, not every restoration pathway.
# Mendoza-Quiroz et al. (2023) followed sexually propagated colonies through
# in-situ nursery and reef-outplant stages.  Those observations are restoration
# material, but are not asexual fragments.  Keep the detailed source class in
# prepared data and use `is_restoration_population()` whenever analyses require
# the two-level natural-versus-restoration contrast.
MENDOZA_QUIROZ_STUDY_ID <- "mendoza_quiroz_et_al_2023"
RESTORATION_POPULATION_TYPES <- c(
  "Restoration fragment",
  "Restoration outplant (sexual recruit)",
  "Restoration recruit"
)

classify_population_type <- function(study, fragment) {
  population_type <- ifelse(fragment == "Y", "Restoration fragment", "Natural colony")
  population_type[study == MENDOZA_QUIROZ_STUDY_ID] <-
    "Restoration outplant (sexual recruit)"
  population_type
}

is_restoration_population <- function(population_type) {
  population_type %in% RESTORATION_POPULATION_TYPES
}

collapse_population_type <- function(population_type) {
  ifelse(
    is_restoration_population(population_type),
    "Restoration fragment",
    population_type
  )
}

# --- Bootstrap settings ---
# Canonical number of bootstrap iterations for lambda CI, sensitivity, etc.
# Defined here for future centralisation; individual scripts may still use
# their own literal 2000L until migrated.
N_BOOT <- 2000L

cat("Loaded 00c_analysis_constants.R\n")
