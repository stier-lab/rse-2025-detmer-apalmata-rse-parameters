#!/usr/bin/env Rscript
################################################################################
# install_packages.R - Install all packages required by the analysis pipeline
################################################################################
#
# USAGE:
#   Rscript install_packages.R
#
# Installs all packages listed in DESCRIPTION (Imports + Suggests).
# Packages already installed at a sufficient version are skipped.
################################################################################

cat("Installing packages for A. palmata Demographic Analysis Pipeline\n")
cat("================================================================\n\n")

# --- Required packages (from library() calls in scripts) ---------------------
required <- c(
  "cowplot",
  "dplyr",
  "forcats",
  "ggplot2",
  "ggrepel",
  "gratia",
  "httr",
  "lme4",
  "lmerTest",
  "lmtest",
  "lubridate",
  "metafor",
  "mgcv",
  "nlme",
  "nnet",
  "patchwork",
  "pracma",
  "purrr",
  "readr",
  "readxl",
  "rnaturalearth",
  "rnaturalearthdata",
  "sandwich",
  "scales",
  "sf",
  "stringr",
  "survival",
  "tibble",
  "tidyr",
  "tidyverse"
)

# --- Optional packages (used via requireNamespace() in some scripts) ---------
optional <- c(
  "car",
  "data.table",
  "glmmTMB",
  "MuMIn",
  "quantreg",
  "RColorBrewer",
  "reformulas",
  "rerddap",
  "segmented"
)

# --- Install function --------------------------------------------------------
install_if_missing <- function(pkgs, label = "required") {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) == 0) {
    cat(sprintf("All %d %s packages already installed.\n", length(pkgs), label))
  } else {
    cat(sprintf("Installing %d %s package(s): %s\n",
                length(missing), label, paste(missing, collapse = ", ")))
    install.packages(missing, repos = "https://cloud.r-project.org")
  }
}

# --- Run installation --------------------------------------------------------
install_if_missing(required, "required")
cat("\n")
install_if_missing(optional, "optional")

cat("\nDone. Run 'Rscript 06_analysis/scripts/run_all.R' to execute the pipeline.\n")
