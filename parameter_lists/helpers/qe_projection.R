################################################################################
# qe_projection.R — Portable quasi-extinction helpers for the RSE model
################################################################################
#
# PURPOSE:
#   Provide a self-contained, dependency-free (base R only) interface for the
#   RSE repository (Detmer-2025-coral-RSE / Detmer-2025-coral-platform) to
#   project a Lefkovitch matrix forward, compute quasi-extinction probability,
#   and evaluate named biological-realism scenarios using the matrices exported
#   in `parameter_lists/scenario_matrices.rds`.
#
# HOW TO USE (from the RSE repo):
#
#   source("path/to/parameter_lists/helpers/qe_projection.R")
#
#   scenarios <- readRDS("path/to/parameter_lists/scenario_matrices.rds")
#
#   # 1) Project any scenario matrix deterministically
#   traj <- project_trajectory(scenarios$S0$matrix, years = 50)
#
#   # 2) Compute quasi-extinction probability for any scenario
#   qe <- compute_qe(scenarios$S4$matrix, years = c(20, 50))
#   #   -> c(p20 = 0.97, p50 = 1.00)
#
#   # 3) Compute QE for a user-modified matrix (e.g. RSE restoration scenario)
#   A <- my_rse_matrix_function(inputs)
#   qe <- compute_qe(A, years = c(20, 50), init = c(200, 100, 50, 20, 10))
#
# CONVENTIONS:
#   - All matrices are 5x5 Lefkovitch with size classes SC1-SC5 (rows = to,
#     cols = from) bounded by 0, 10, 100, 900, 4000, Inf cm2 live tissue.
#   - Default initial population matches the Detmer-Stier synthesis baseline:
#     c(100, 50, 30, 20, 10) = 210 colonies total.
#   - Default QE threshold = 10% of initial N (matches script 13).
#   - Bootstrap / stochastic simulation uses N_QE_SIM = 2000 replicates to
#     match the synthesis parameter-uncertainty resolution.
#
# Author: Detmer & Stier Lab
# Date:   2026-04-22
################################################################################

# --- Defaults shared across helpers ------------------------------------------

.QE_DEFAULT_INIT  <- c(100, 50, 30, 20, 10)   # SC1..SC5 starting abundances
.QE_DEFAULT_FRAC  <- 0.10                      # quasi-extinction threshold
.QE_DEFAULT_SIM   <- 2000L                     # simulation replicates
.QE_DEFAULT_YEARS <- c(20, 50)                 # horizons


# --- project_trajectory() ----------------------------------------------------
# Deterministic projection of total population through time.
#
# A        5x5 Lefkovitch matrix
# init     length-5 initial abundance vector (default .QE_DEFAULT_INIT)
# years    number of forward years (default 50)
#
# Returns  data.frame(year, total, SC1, SC2, SC3, SC4, SC5)

project_trajectory <- function(A, init = .QE_DEFAULT_INIT, years = 50L) {
  stopifnot(is.matrix(A), dim(A) == c(5, 5), length(init) == 5L, years >= 1L)
  traj <- matrix(NA_real_, nrow = years + 1L, ncol = 5L,
                 dimnames = list(NULL, paste0("SC", 1:5)))
  traj[1, ] <- init
  for (t in seq_len(years)) traj[t + 1L, ] <- as.numeric(A %*% traj[t, ])
  out <- as.data.frame(traj)
  out$year  <- 0:years
  out$total <- rowSums(traj)
  out[, c("year", "total", paste0("SC", 1:5))]
}


# --- compute_qe() ------------------------------------------------------------
# Quasi-extinction probability via demographic-stochasticity Poisson simulation.
#
# Each year, each element of the expected population vector A %*% n is treated
# as the intensity of an independent Poisson draw. This captures demographic
# stochasticity (small-population noise) but NOT parameter uncertainty — for
# the latter, pass a bootstrap draw of A from the RSE's parameter machinery.
#
# A        5x5 Lefkovitch matrix
# years    horizons at which to report P(QE); defaults to c(20, 50)
# init     starting abundance vector (default .QE_DEFAULT_INIT)
# qe_frac  threshold as fraction of initial N (default 0.10 = 10%)
# n_sim    number of Monte Carlo replicates (default 2000)
# seed     optional RNG seed for reproducibility (default 42)
#
# Returns  named numeric of P(QE) for each requested horizon

compute_qe <- function(A,
                       years   = .QE_DEFAULT_YEARS,
                       init    = .QE_DEFAULT_INIT,
                       qe_frac = .QE_DEFAULT_FRAC,
                       n_sim   = .QE_DEFAULT_SIM,
                       seed    = 42L) {
  stopifnot(is.matrix(A), dim(A) == c(5, 5), length(init) == 5L,
            all(years >= 1L), qe_frac > 0, qe_frac < 1, n_sim >= 1L)

  max_year <- max(years)
  qe_thr   <- sum(init) * qe_frac
  horizons <- setNames(seq_along(years), sprintf("p%d", years))
  below    <- matrix(FALSE, nrow = n_sim, ncol = length(years),
                     dimnames = list(NULL, names(horizons)))

  if (!is.null(seed)) set.seed(seed)
  for (s in seq_len(n_sim)) {
    n <- init
    for (t in seq_len(max_year)) {
      expected <- pmax(as.numeric(A %*% n), 0)
      n <- suppressWarnings(rpois(5L, lambda = expected))
      if (t %in% years) {
        below[s, sprintf("p%d", t)] <- sum(n) < qe_thr
      }
    }
  }
  colMeans(below)
}


# --- scenario_qe() -----------------------------------------------------------
# Convenience wrapper: load scenarios file, compute QE for each scenario.
#
# scenarios  either (a) list from readRDS("scenario_matrices.rds") or
#            (b) path to that .rds file
# years      horizons (default c(20, 50))
# init       starting abundance (default .QE_DEFAULT_INIT)
# qe_frac    threshold fraction (default 0.10)
# n_sim      simulation replicates (default 2000)
#
# Returns    data.frame(scenario, label, lambda, p20, p50)

scenario_qe <- function(scenarios,
                        years   = .QE_DEFAULT_YEARS,
                        init    = .QE_DEFAULT_INIT,
                        qe_frac = .QE_DEFAULT_FRAC,
                        n_sim   = .QE_DEFAULT_SIM) {
  if (is.character(scenarios)) scenarios <- readRDS(scenarios)
  out <- lapply(scenarios, function(sc) {
    qe <- compute_qe(sc$matrix, years = years, init = init,
                     qe_frac = qe_frac, n_sim = n_sim)
    df <- data.frame(scenario = sc$name %||% sc$scenario,
                     label    = sc$label,
                     lambda   = sc$lambda,
                     stringsAsFactors = FALSE)
    for (h in names(qe)) df[[h]] <- unname(qe[h])
    df
  })
  do.call(rbind, out)
}


# Null-coalesce helper (base R has no %||%)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
}


message("qe_projection.R loaded: project_trajectory(), compute_qe(), scenario_qe()")
