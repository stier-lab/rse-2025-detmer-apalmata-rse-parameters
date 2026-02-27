################################################################################
# shared_utilities.R - Loader for All Shared Code
################################################################################
#
# This file sources the modular utility files in order. All existing scripts
# that call source("analysis/scripts/utils/shared_utilities.R") continue to
# work unchanged.
#
# Module load order:
#   00_libraries.R         — package loading
#   00b_color_palette.R    — color definitions
#   00c_analysis_constants.R — size classes, study metadata
#   01_functions.R         — all shared functions
################################################################################

# Resolve path to utils directory (works from project root or scripts dir)
.utils_dir <- if (file.exists("analysis/scripts/utils/00_libraries.R")) {
  "analysis/scripts/utils"
} else if (file.exists("utils/00_libraries.R")) {
  "utils"
} else if (file.exists("00_libraries.R")) {
  "."
} else {
  stop("Cannot find utils directory. Run from project root or analysis/scripts/")
}

source(file.path(.utils_dir, "00_libraries.R"))
source(file.path(.utils_dir, "00b_color_palette.R"))
source(file.path(.utils_dir, "00c_analysis_constants.R"))
source(file.path(.utils_dir, "01_functions.R"))
source(file.path(.utils_dir, "02_threshold_functions.R"))

cat("Loaded shared_utilities.R (all modules)\n")
