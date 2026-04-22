################################################################################
# 60_scenario_comparison.R - 9-scenario biological realism comparison
################################################################################
#
# PURPOSE:
#   Assemble the 9 scenarios (S0-S8) defined in biological_realism_PRD.md and
#   compute lambda, elasticity shares, and sexual-vs-asexual replacement for
#   each. Emit a single scenario-summary CSV that drives FigS29.
#
# INPUTS:
#   - 06_analysis/output/transition_matrix.rds
#       (baseline: survival_by_class, fragmentation, lambda)
#   - 06_analysis/output/sexual_fecundity_matrix.rds          (script 53)
#   - 06_analysis/output/sterility_lag_F_sex.rds              (script 54)
#   - 06_analysis/output/lesion_penalty_F_sex.rds             (script 55)
#   - 06_analysis/output/outplant_age_survival.rds            (script 56)
#   - 06_analysis/output/depensatory_corallivory.rds          (script 58)
#   - 06_analysis/output/microhabitat_depth_survival.rds      (script 59)
#   - 05_data/standardized/apal_growth_ind.csv
#   - 05_data/standardized/apal_lesion_population_fraction.csv
#
# OUTPUTS:
#   - 06_analysis/output/biological_realism_scenarios.csv
#       Columns: scenario, label, lambda, delta_lambda, sc5_elasticity,
#                sexual_contribution_pct
#
# Author: Detmer & Stier Lab
# Date: 2026-04-18
################################################################################

source("06_analysis/scripts/utils/shared_utilities.R")

print_header("Script 60: Scenario comparison (S0-S8)")

# --- Load baseline ---
tm <- readRDS("06_analysis/output/transition_matrix.rds")
# survival_by_class may be a data.frame (from script 13) — extract the vector
S_base_raw <- tm$survival_by_class
if (is.data.frame(S_base_raw)) {
  S_base <- setNames(S_base_raw$survival, S_base_raw$size_class)
} else {
  S_base <- S_base_raw
}
F_mat  <- tm$fragmentation
lambda_base <- tm$lambda
G_published <- tm$growth_transitions   # anchor to published baseline

cat(sprintf("  Baseline lambda: %.3f\n", lambda_base))
cat(sprintf("  Baseline survival: %s\n",
            paste(names(S_base), round(S_base, 3), sep = "=", collapse = ", ")))

growth_data <- read.csv("05_data/standardized/apal_growth_ind.csv",
                        stringsAsFactors = FALSE)
growth_data <- growth_data[!is.na(growth_data$size_cm2) &
                           !is.na(growth_data$growth_cm2_yr), ]

# --- Match script 13 transition-matrix filters (critical for S0 reproduction) ---
# (1) Natural colonies only (fragment == "N")
if ("fragment" %in% names(growth_data)) {
  growth_data <- growth_data[growth_data$fragment == "N" | is.na(growth_data$fragment), ]
  growth_data <- growth_data[!is.na(growth_data$fragment) & growth_data$fragment == "N", ]
}
# (2) Near-annual intervals only (0.5-1.5 yr)
if ("time_interval_yr" %in% names(growth_data)) {
  growth_data <- growth_data[!is.na(growth_data$time_interval_yr) &
                             growth_data$time_interval_yr >= 0.5 &
                             growth_data$time_interval_yr <= 1.5, ]
}
# (3) Remove top-1% absolute growth outliers (script 13 line 475)
q99 <- quantile(abs(growth_data$growth_cm2_yr), 0.99, na.rm = TRUE)
growth_data <- growth_data[abs(growth_data$growth_cm2_yr) < q99, ]
cat(sprintf("  Growth data (post-filter): %d rows\n", nrow(growth_data)))

# --- Load F_sex variants (scripts 53-55) ---
# Scripts save lists; unwrap the correct matrix member from each
.raw_fsex     <- readRDS("06_analysis/output/sexual_fecundity_matrix.rds")
.raw_sterile  <- readRDS("06_analysis/output/sterility_lag_F_sex.rds")
.raw_lesion   <- readRDS("06_analysis/output/lesion_penalty_F_sex.rds")

F_sex    <- .raw_fsex$F_sex                    # raw sexual fecundity matrix
F_sex_s2 <- .raw_sterile$conservative          # 4-yr sterility, observed disturbance fraction
F_sex_s3 <- .raw_lesion$F_sex_penalized        # 20% penalty weighted by fraction_lesioned

# --- Field-calibration scalar ---
# script 53 uses s_recruit = 0.028 (Chamberland 2015, nursery-reared larvae).
# Wild Caribbean A. palmata sexual recruitment is 2-3 orders of magnitude lower
# because of gamete dilution, predation, and failed settlement (Mueller 2018;
# Edmunds 2015). Apply settlement_efficiency to rescale F_sex to wild rates
# while preserving between-scenario contrasts (S1 vs S2 vs S3).
SETTLEMENT_EFFICIENCY <- 1e-4
F_sex    <- F_sex    * SETTLEMENT_EFFICIENCY
F_sex_s2 <- F_sex_s2 * SETTLEMENT_EFFICIENCY
F_sex_s3 <- F_sex_s3 * SETTLEMENT_EFFICIENCY

# Some scripts store these as lists; unwrap if needed
if (is.list(F_sex) && !is.matrix(F_sex))    F_sex    <- F_sex$F_sex    %||% F_sex[[1]]
if (is.list(F_sex_s2) && !is.matrix(F_sex_s2)) F_sex_s2 <- F_sex_s2$F_sex %||% F_sex_s2[[1]]
if (is.list(F_sex_s3) && !is.matrix(F_sex_s3)) F_sex_s3 <- F_sex_s3$F_sex %||% F_sex_s3[[1]]

# --- Load survival-modifier outputs (scripts 56, 58, 59) ---
outplant_obj <- readRDS("06_analysis/output/outplant_age_survival.rds")
# S4: outplant-age effect at year 0 (the "outplanting year" survival penalty)
S_outplant <- outplant_obj$year_0

dep_obj <- readRDS("06_analysis/output/depensatory_corallivory.rds")
# S6: depensatory corallivory at median density (SC1/SC2 penalized)
S_dep <- dep_obj$median_density

depth_obj <- readRDS("06_analysis/output/microhabitat_depth_survival.rds")
# S7: midpoint between shallow (2m) and deep (10m) predictions
S_depth <- (depth_obj$shallow + depth_obj$deep) / 2

# S5: winter SST mild-winter (+1 C anomaly) survival
sst_obj <- if (file.exists("06_analysis/output/winter_sst_survival.rds")) {
  readRDS("06_analysis/output/winter_sst_survival.rds")
} else NULL
S_winter_sst <- if (!is.null(sst_obj) && "mild_winter" %in% names(sst_obj)) {
  sst_obj$mild_winter
} else S_base

# Guard: ensure name order matches SIZE_LABELS
align_S <- function(s) {
  if (is.null(names(s))) { names(s) <- SIZE_LABELS; return(s) }
  s[SIZE_LABELS]
}
S_base       <- align_S(S_base)
S_outplant   <- align_S(S_outplant)
S_dep        <- align_S(S_dep)
S_depth      <- align_S(S_depth)
S_winter_sst <- align_S(S_winter_sst)

cat("\n  Loaded modifier survival vectors:\n")
for (nm in c("S_outplant", "S_dep", "S_depth", "S_winter_sst")) {
  v <- get(nm)
  cat(sprintf("    %s: %s\n", nm,
              paste(names(v), round(v, 3), sep = "=", collapse = ", ")))
}

# --- Helper: compute scenario ---
run_one <- function(name, label, S, F_sex_use = NULL) {
  res <- compute_lambda_from_survival(
    survival_by_class = S,
    growth_data       = growth_data,
    frag_matrix       = F_mat,
    F_sex             = F_sex_use,
    G_override        = G_published
  )
  list(scenario = name, label = label, result = res,
       S = S, F_sex = F_sex_use)
}

# --- Define scenarios ---
scenarios <- list(
  run_one("S0", "Baseline",                  S_base),
  run_one("S1", "+Sexual (size threshold)",  S_base,     F_sex),
  run_one("S2", "+Sterility lag",            S_base,     F_sex_s2),
  run_one("S3", "+Lesion penalty",           S_base,     F_sex_s3),
  run_one("S4", "+Outplant age",             S_outplant),
  run_one("S5", "+Winter SST",               S_winter_sst),
  run_one("S6", "+Depensatory (corallivory)", S_dep),
  run_one("S7", "+Microhabitat (depth)",     S_depth),
  run_one("S8", "All combined",              S_depth,   F_sex_s3)
)

# --- Compute per-scenario metrics ---
# Quasi-extinction probability via demographic-stochasticity Poisson simulation.
# Each year, each element of A %*% n is treated as the expectation of a Poisson
# draw, giving a demographically stochastic realisation. Returns probabilities
# at the requested horizons.
qe_probability <- function(A, n_sim = 2000, years = c(20, 50),
                            init = c(100, 50, 30, 20, 10), qe_frac = 0.10) {
  max_year <- max(years)
  qe_thr <- sum(init) * qe_frac
  below <- matrix(FALSE, nrow = n_sim, ncol = length(years))
  colnames(below) <- sprintf("p%d", years)
  year_idx <- setNames(seq_along(years), sprintf("p%d", years))

  set.seed(42)
  for (s in seq_len(n_sim)) {
    n <- init
    for (t in seq_len(max_year)) {
      expected <- as.numeric(A %*% n)
      expected[expected < 0] <- 0
      n <- suppressWarnings(rpois(length(expected), lambda = expected))
      if (t %in% years) below[s, year_idx[sprintf("p%d", t)]] <- sum(n) < qe_thr
    }
  }
  colMeans(below)
}

# Local eigen-based sensitivity matrix (fallback since popbio may not be loaded)
sensitivity_local <- function(A) {
  ev <- eigen(A)
  w <- Re(ev$vectors[, 1])
  v <- tryCatch(Re(solve(ev$vectors))[1, ], error = function(e) rep(1, nrow(A)))
  outer(v, w) / sum(v * w)
}

metric_row <- function(sc) {
  A <- sc$result$matrix
  lam <- sc$result$lambda

  # Sexual vs asexual contribution: share of SC1 inflow from F_sex vs F_frag
  sex_row  <- if (!is.null(sc$F_sex)) sc$F_sex["SC1", ] else rep(0, length(SIZE_LABELS))
  frag_row <- F_mat["SC1", ]
  # Weight by stable stage distribution if available
  w <- tryCatch({
    ev <- eigen(A)
    abs(Re(ev$vectors[, 1])) / sum(abs(Re(ev$vectors[, 1])))
  }, error = function(e) rep(1 / length(SIZE_LABELS), length(SIZE_LABELS)))
  sex_flow  <- sum(sex_row  * w)
  frag_flow <- sum(frag_row * w)
  total_flow <- sex_flow + frag_flow
  sex_pct <- if (total_flow > 0) 100 * sex_flow / total_flow else 0

  # SC5 stasis elasticity (crude — eigen-based elasticity to A[SC5, SC5])
  e_sc5 <- tryCatch({
    s_mat <- sensitivity_local(A)
    e_mat <- s_mat * A / lam
    e_mat[length(SIZE_LABELS), length(SIZE_LABELS)]
  }, error = function(e) NA_real_)

  # Quasi-extinction probability via demographic-stochasticity simulation.
  # Initial population matches script 13: c(100, 50, 30, 20, 10) = 210 total.
  # QE threshold = 10% of initial (= 21 colonies). Simulate 2000 replicates
  # drawing Poisson realizations from expected transition flows each year.
  qe <- qe_probability(A, n_sim = 2000, years = c(20, 50),
                       init = c(100, 50, 30, 20, 10), qe_frac = 0.10)

  data.frame(
    scenario = sc$scenario,
    label    = sc$label,
    lambda   = round(lam, 4),
    delta_lambda = round(lam - lambda_base, 4),
    sc5_elasticity = round(e_sc5, 4),
    sexual_contribution_pct = round(sex_pct, 2),
    p_quasi_ext_20yr = round(qe["p20"], 3),
    p_quasi_ext_50yr = round(qe["p50"], 3)
  )
}

rows <- do.call(rbind, lapply(scenarios, metric_row))
rownames(rows) <- NULL

print_subheader("Scenario summary")
print(rows)

# --- S0 reproduction check ---
s0_lam <- rows$lambda[rows$scenario == "S0"]
if (abs(s0_lam - lambda_base) > 0.01) {
  warning(sprintf("S0 lambda=%.3f diverges from published %.3f. Check pipeline.",
                  s0_lam, lambda_base))
} else {
  cat(sprintf("\n  S0 reproduces baseline lambda: %.3f (expected %.3f)\n",
              s0_lam, lambda_base))
}

# --- Save outputs ---
out_path <- "06_analysis/output/biological_realism_scenarios.csv"
write.csv(rows, out_path, row.names = FALSE)
print_success(sprintf("Saved %s (%d scenarios)", out_path, nrow(rows)))

# Also save scenario list (matrices) for figure script
saveRDS(scenarios, "06_analysis/output/biological_realism_scenarios.rds")
print_success("Saved biological_realism_scenarios.rds (full matrix objects)")

# --- RSE-consumable scenario export -----------------------------------------
# Consolidated, trimmed scenario matrices for the RSE repo to load directly.
# Structure: named list $S0..$S8, each $matrix (5x5), $lambda, $label, $name.
# Consumed by parameter_lists/helpers/qe_projection.R.
scenario_matrices <- setNames(
  lapply(scenarios, function(sc) {
    list(
      name    = sc$scenario,
      label   = sc$label,
      lambda  = sc$result$lambda,
      matrix  = sc$result$matrix,
      F_sex   = sc$F_sex,
      survival = sc$S
    )
  }),
  sapply(scenarios, function(sc) sc$scenario)
)
attr(scenario_matrices, "source")     <- "60_scenario_comparison.R"
attr(scenario_matrices, "generated")  <- Sys.time()
attr(scenario_matrices, "size_class_breaks") <- SIZE_BREAKS
attr(scenario_matrices, "size_class_labels") <- SIZE_LABELS
attr(scenario_matrices, "note")       <- paste(
  "9-scenario biological-realism framework (S0-S8). Each element has a 5x5",
  "Lefkovitch matrix ready for project_trajectory() / compute_qe() from",
  "parameter_lists/helpers/qe_projection.R. Size classes SC1-SC5 bounded by",
  "0, 10, 100, 900, 4000, Inf cm2."
)

scenario_export_path <- "parameter_lists/scenario_matrices.rds"
saveRDS(scenario_matrices, scenario_export_path)
print_success(sprintf("Saved %s (RSE-consumable export)", scenario_export_path))

cat("\nDone.\n")
