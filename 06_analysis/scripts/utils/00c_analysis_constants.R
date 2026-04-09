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

# --- Bootstrap settings ---
# Canonical number of bootstrap iterations for lambda CI, sensitivity, etc.
# Defined here for future centralisation; individual scripts may still use
# their own literal 2000L until migrated.
N_BOOT <- 2000L

cat("Loaded 00c_analysis_constants.R\n")
