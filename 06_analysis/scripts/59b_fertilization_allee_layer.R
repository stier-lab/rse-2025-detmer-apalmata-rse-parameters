#!/usr/bin/env Rscript
################################################################################
# 59b_fertilization_allee_layer.R - Scenario S9: Fertilization Allee
################################################################################
#
# PURPOSE:
#   A. palmata is a self-incompatible broadcast spawner: realised fertilization
#   collapses when COMPATIBLE spawners are sparse (sperm dilution). This layer
#   makes the fixed fertilization rate in F_sex (script 53) density-dependent:
#       fertilization_realised = fertilization * phi(rho)
#       phi(rho) = rho / (rho + h)          [Michaelis-Menten; same form as S6]
#   rho = local density of compatible spawners (colonies/m^2); h = half-saturation.
#
# EMPIRICAL FOOTING (honest — this is an ASSUMPTION SWEEP, not a fitted rate):
#   No fitted A. palmata fertilization-vs-density curve exists (see
#   07_reporting/internal/recruitment_fecundity_scope_note.md; NotebookLM
#   "Density-Dependent Coral Biology"). The ONLY quantitative anchor is
#   Baums et al. 2006: genotypically-rich, sexually-recruiting stands averaged
#   0.30 +/- 0.21 col/m^2; depauperate/non-recruiting stands 0.13 +/- 0.08 col/m^2.
#   So phi should be near-saturated by ~0.30 and strongly suppressed below ~0.13.
#   The half-saturation h is SWEPT (h in {0.05,0.10,0.15,0.30}), never calibrated.
#   Report the reserve/recovery conclusion as "pays only if h exceeds X."
#
# INPUTS:
#   - 06_analysis/output/transition_matrix.rds        (baseline S, F_frag, G, lambda)
#   - 06_analysis/output/sexual_fecundity_matrix.rds  (script 53 F_sex)
# OUTPUTS:
#   - 06_analysis/output/fertilization_allee.rds
#   - 06_analysis/output/fertilization_allee_phi_rse.csv   (RSE-ready phi params)
#
# Author: Detmer & Stier Lab   Date: 2026-07-21
################################################################################

source("06_analysis/scripts/utils/shared_utilities.R")
print_header("Script 59b: Fertilization Allee layer (S9)")

output_dir <- "06_analysis/output"
SETTLEMENT_EFFICIENCY <- 1e-4   # matches script 60 wild-rate rescale

# --- baseline ---
tm <- readRDS(file.path(output_dir, "transition_matrix.rds"))
S_raw  <- tm$survival_by_class
S_base <- if (is.data.frame(S_raw)) setNames(S_raw$survival, S_raw$size_class) else S_raw
F_mat  <- tm$fragmentation
G_pub  <- tm$growth_transitions
lambda_base <- tm$lambda

F_sex <- readRDS(file.path(output_dir, "sexual_fecundity_matrix.rds"))$F_sex

# --- fertilization Allee ---
phi     <- function(rho, h) rho / (rho + h)
H_GRID  <- c(0.05, 0.10, 0.15, 0.30)                                        # col/m^2 (Baums-bracketed)
RHO_LVL <- c(collapsed = 0.05, sparse = 0.13, dense = 0.30, reserve = 1.00) # col/m^2
# sparse=Baums depauperate, dense=Baums rich; collapsed=post-crash reef; reserve=concentrated orchard

lam_of <- function(F_use) compute_lambda_from_survival(
  survival_by_class = S_base, growth_data = NULL, frag_matrix = F_mat,
  F_sex = F_use * SETTLEMENT_EFFICIENCY, G_override = G_pub)$lambda

phi_tab <- outer(H_GRID, RHO_LVL, function(h, r) phi(r, h))
dimnames(phi_tab) <- list(sprintf("h=%.2f", H_GRID), names(RHO_LVL))

lam_tab <- phi_tab
for (i in seq_along(H_GRID)) for (j in seq_along(RHO_LVL)) lam_tab[i, j] <- lam_of(F_sex * phi_tab[i, j])
lam_S1 <- lam_of(F_sex)   # phi=1 reference (S1 sexual, no Allee)

cat(sprintf("\n  lambda: S0 baseline = %.3f | S1 (sexual, phi=1) = %.3f\n", lambda_base, lam_S1))
cat("\n  phi(rho) by half-saturation h (cols = spawner density, col/m^2):\n"); print(round(phi_tab, 3))
cat("\n  lambda by (h, rho):\n"); print(round(lam_tab, 4))

# --- RSE-ready export: the phi parameterization the strategy model consumes ---
rse <- do.call(rbind, lapply(H_GRID, function(h) data.frame(
  half_saturation_h = h,
  density_level     = names(RHO_LVL),
  rho_col_per_m2    = as.numeric(RHO_LVL),
  phi               = round(phi(as.numeric(RHO_LVL), h), 4),
  form              = "phi(rho)=rho/(rho+h)",
  anchor            = "Baums 2006: sparse 0.13 / dense 0.30 col/m2; h SWEPT (assumption)",
  stringsAsFactors  = FALSE)))
write.csv(rse, file.path(output_dir, "fertilization_allee_phi_rse.csv"), row.names = FALSE)

saveRDS(list(phi_table = phi_tab, lambda_table = lam_tab, lambda_S1 = lam_S1,
             lambda_baseline = lambda_base, h_grid = H_GRID, rho_levels = RHO_LVL,
             form = "phi(rho)=rho/(rho+h); fertilization_realised = fertilization * phi",
             anchor = "Baums 2006 densities; h SWEPT, not fit",
             note = "S9 fertilization Allee; assumption sweep, not a calibrated rate"),
        file.path(output_dir, "fertilization_allee.rds"))
print_success("Saved fertilization_allee.rds + fertilization_allee_phi_rse.csv")
cat("\nDone.\n")
