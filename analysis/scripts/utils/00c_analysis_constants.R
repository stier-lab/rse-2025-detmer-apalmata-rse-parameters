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
N_STUDIES <- 5L   # k in meta-analysis
NOAA_DATA_FRACTION <- 0.78  # NOAA = 78% of observations

cat("Loaded 00c_analysis_constants.R\n")
