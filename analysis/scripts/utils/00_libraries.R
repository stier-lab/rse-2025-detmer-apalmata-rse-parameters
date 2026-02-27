################################################################################
# 00_libraries.R - Centralized Package Loading
################################################################################
#
# All packages used across the analysis pipeline. Source this once at the top
# of any script to ensure all dependencies are available.
#
# Packages are loaded silently to keep console output clean.
################################################################################

suppressPackageStartupMessages({
  # --- Core tidyverse ---
  library(dplyr)
  library(tidyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(ggplot2)
  library(scales)
  library(tibble)

  # --- Modeling ---
  library(mgcv)       # GAMs
  library(lme4)       # mixed-effects models (GLMMs)
  library(gratia)     # GAM derivatives with simultaneous CIs (Detmer et al. 2025)
  library(pracma)     # findpeaks() for peak detection in derivatives

  # --- Figures ---
  library(patchwork)  # multi-panel layouts
  library(ggrepel)    # non-overlapping text labels
})

# --- Optional packages (not on all machines) ---
# These are loaded quietly; scripts that need them check has_* flags

has_nlme      <- requireNamespace("nlme",      quietly = TRUE)
has_segmented <- requireNamespace("segmented", quietly = TRUE)
has_quantreg  <- requireNamespace("quantreg",  quietly = TRUE)
has_lmerTest  <- requireNamespace("lmerTest",  quietly = TRUE)
has_metafor   <- requireNamespace("metafor",   quietly = TRUE)
has_sf        <- requireNamespace("sf",        quietly = TRUE)
has_MuMIn     <- requireNamespace("MuMIn",     quietly = TRUE)
has_data.table <- requireNamespace("data.table", quietly = TRUE)

cat("Loaded 00_libraries.R\n")
