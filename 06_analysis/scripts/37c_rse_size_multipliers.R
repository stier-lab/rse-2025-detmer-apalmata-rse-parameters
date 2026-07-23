#!/usr/bin/env Rscript
################################################################################
# 37c_RSE_SIZE_MULTIPLIERS.R
# Export RSE-ready per-type size-survival multipliers from the 37b type x size fit.
################################################################################
#
# PURPOSE:
#   Turn the by-disturbance-type size-survival tables (script 37b) into a single
#   tidy table of size-vector multipliers (event survival / baseline survival)
#   that the strategy model (Detmer-2025-coral-RSE) consumes directly. The RSE
#   repo must NOT hard-code these numbers -- it reads this file.
#
#   Multiplier(type, size) = survival(type, size) / survival(none, size).
#   - disease/predation : gradient intact  -> large-favoring
#   - storm             : flattened        -> breakage erodes big-is-safer
#   - thermal_moderate  : DHW<10, gradient persists ~ baseline (near-neutral)
#   - thermal_catastrophic : DHW>20, refuge collapses -> flat, set from Manzello
#                            2025 (our monitoring under-captures this tail).
#
# INPUTS:
#   - 06_analysis/output/disturbance_type_size_survival_summary.csv  (none/disease/storm)
#   - 06_analysis/output/disturbance_type_heatwave_dhw.csv           (moderate/severe DHW bands)
# OUTPUT:
#   - 06_analysis/output/disturbance_type_size_multipliers_rse.csv
#
# See 06_analysis/DISTURBANCE_SIZE_DEPENDENCE.md for interpretation and provenance.
# Author: Detmer & Stier Lab   Date: 2026-07-21
################################################################################

# --- locate output dir (run from repo root, or anywhere under it) -------------
find_output <- function() {
  d <- normalizePath(".", mustWork = FALSE)
  for (i in 1:6) {
    cand <- file.path(d, "06_analysis", "output")
    if (dir.exists(cand)) return(cand)
    d <- dirname(d)
  }
  stop("Could not locate 06_analysis/output from ", getwd())
}
out_dir <- find_output()

SC <- c("SC1","SC2","SC3","SC4","SC5")
MANZELLO_CATASTROPHIC <- 0.05   # DHW>20 flat survival (Manzello et al. 2025, 97.8-100% mortality)

by_size <- function(df, key_col, key_val, val = "survival") {
  s <- setNames(rep(NA_real_, 5), SC)
  sub <- df[df[[key_col]] == key_val, ]
  for (k in SC) { r <- sub[sub$size_class == k, ]; if (nrow(r)) s[k] <- r[[val]][1] }
  s
}
mult <- function(ev, base) {
  m <- ev / base
  m[!is.finite(m)] <- NA_real_
  round(pmin(m, 1.20), 3)   # cap tiny-n ratios that exceed baseline (curation noise)
}

surv <- read.csv(file.path(out_dir, "disturbance_type_size_survival_summary.csv"), stringsAsFactors = FALSE)
hw   <- read.csv(file.path(out_dir, "disturbance_type_heatwave_dhw.csv"),          stringsAsFactors = FALSE)

base_none <- by_size(surv, "dist_type", "none")
m_disease <- mult(by_size(surv, "dist_type", "disease"), base_none)
m_storm   <- mult(by_size(surv, "dist_type", "storm"),   base_none)
# storm SC1 rests on n=2 (survival=1.0) -> unreliable; set to flat 1.0 for the
# "storm flattens the gradient" signature rather than a noisy >1 ratio
m_storm["SC1"] <- 1.00
m_therm_mod <- mult(by_size(hw, "dhw_band", "Moderate (DHW<10)"), base_none)
m_therm_cat <- round(rep(MANZELLO_CATASTROPHIC, 5), 3); names(m_therm_cat) <- SC

types <- list(disease = m_disease, storm = m_storm,
              thermal_moderate = m_therm_mod, thermal_catastrophic = m_therm_cat)
prov  <- c(disease = "37b disease/predation (Neely 2014-15 compound); large-favoring",
           storm = "37b storm; flattened (branch breakage)",
           thermal_moderate = "37b heatwave DHW<10; gradient persists ~ baseline",
           thermal_catastrophic = "Manzello 2025 Science; DHW>20 flat collapse (external)")

res <- do.call(rbind, lapply(names(types), function(ty) data.frame(
  disturbance_type = ty, size_class = SC,
  survival_multiplier = as.numeric(types[[ty]]),
  provenance = prov[[ty]], stringsAsFactors = FALSE)))

outfile <- file.path(out_dir, "disturbance_type_size_multipliers_rse.csv")
write.csv(res, outfile, row.names = FALSE)
cat("baseline (none) survival:", paste(round(base_none,3), collapse=", "), "\n")
for (ty in names(types)) cat(sprintf("%-22s %s\n", ty, paste(sprintf("%.2f", types[[ty]]), collapse=", ")))
cat("wrote", outfile, "\n")
