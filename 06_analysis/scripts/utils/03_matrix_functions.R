################################################################################
# 03_matrix_functions.R - Shared Projection Matrix Functions
################################################################################
#
# PURPOSE:
#   Reusable helpers for building Lefkovitch projection matrices and computing
#   lambda under alternative biological assumptions. Supports the scenario-
#   comparison framework (scripts 60+).
#
# EXPORTS:
#   compute_lambda_from_survival()  -- Scalar lambda from survival + growth + F_mat
#                                      (originally in script 16; refactored here)
#   build_F_sex()                   -- Size-threshold sexual fecundity row
#   apply_disturbance_lag()         -- 4-yr post-disturbance sterility modifier
#   apply_lesion_penalty()          -- 20% fecundity reduction for lesioned fraction
#   apply_density_dep_SC12()        -- Depensatory corallivory hazard for small classes
#   run_scenario()                  -- Dispatch a named scenario config to lambda
#
# DEPENDENCIES:
#   Requires SIZE_BREAKS and SIZE_LABELS (loaded by 00c_analysis_constants.R).
#
# CITATIONS (for parameters passed in by callers):
#   Vardi 2011        -- Maturity threshold 4000 cm²
#   Mendoza-Quiroz 2023 -- Oocyte density 63.6/cm², fertilization 95% wild
#   Piñón-González 2018 -- Fecundity reduction 20% for partial mortality
#   Lirman 2000a      -- Fragment sterility duration 4 years
#   Williams 2012     -- Coralliophila consumption 16 cm²/day
#   Boisvert 2024     -- Time-since-outplant decay (A. cervicornis)
#
# Author: Detmer & Stier Lab
# Date: 2026-04-17
################################################################################


# ============================================================================
# 1. compute_lambda_from_survival() — baseline lambda calculator
# ============================================================================
# Originally from 06_analysis/scripts/16_sensitivity_analysis.R:58
# Refactored here for reuse across scenario framework (scripts 60-61).
# All existing callers in script 16 continue to work via source() chain.

compute_lambda_from_survival <- function(survival_by_class, growth_data, frag_matrix,
                                         custom_breaks = NULL,
                                         full_data_survival = NULL,
                                         F_sex = NULL,
                                         G_override = NULL) {
  size_breaks <- if (!is.null(custom_breaks)) custom_breaks else SIZE_BREAKS
  size_labels <- SIZE_LABELS
  n_sc <- length(size_labels)

  # G_override short-circuits the growth-data recomputation so callers can pass
  # the canonical growth_transitions from transition_matrix.rds. This keeps the
  # scenario framework anchored to the published baseline lambda = 0.961.
  if (!is.null(G_override)) {
    G <- G_override
  } else {
    if (is.null(growth_data) || nrow(growth_data) == 0) {
      return(list(lambda = NA, note = "No growth data"))
    }
    growth_data$initial_sc <- cut(growth_data$size_cm2, breaks = size_breaks,
                                   labels = size_labels, include.lowest = TRUE)
    growth_data$final_size <- pmax(growth_data$size_cm2 + growth_data$growth_cm2_yr, 0.1)
    growth_data$final_sc <- cut(growth_data$final_size, breaks = size_breaks,
                                 labels = size_labels, include.lowest = TRUE)
    G <- matrix(0, n_sc, n_sc)
    for (i in 1:n_sc) {
      from_data <- growth_data[growth_data$initial_sc == size_labels[i], ]
      if (nrow(from_data) > 0) {
        for (j in 1:n_sc) {
          G[j, i] <- sum(from_data$final_sc == size_labels[j], na.rm = TRUE) / nrow(from_data)
        }
      } else {
        G[i, i] <- 1
      }
    }
  }

  # Survival diagonal with sensible fallbacks for missing classes
  S <- numeric(n_sc)
  for (i in 1:n_sc) {
    sc <- size_labels[i]
    if (sc %in% names(survival_by_class) &&
        !is.na(survival_by_class[sc]) && !is.nan(survival_by_class[sc])) {
      S[i] <- survival_by_class[sc]
    } else {
      if (!is.null(full_data_survival) && sc %in% names(full_data_survival) &&
          !is.na(full_data_survival[sc])) {
        S[i] <- full_data_survival[sc]
      } else {
        S[i] <- mean(survival_by_class, na.rm = TRUE)
      }
    }
  }

  # Projection matrix: A = G %*% diag(S) + F_frag + F_sex
  A <- G %*% diag(S) + frag_matrix
  if (!is.null(F_sex)) {
    # F_sex is a matrix of sexual fecundity contributions (Row = SC1 typically)
    A <- A + F_sex
  }

  lambda <- Re(eigen(A)$values[1])
  list(lambda = lambda, matrix = A, survival = S, transitions = G, F_sex = F_sex)
}


# ============================================================================
# 2. build_F_sex() — Size-threshold sexual fecundity row (Idea 1)
# ============================================================================
# Implements Vardi 2011 maturity threshold (4000 cm²) and Mendoza-Quiroz 2023
# oocyte density and fertilization rate. Returns 5x5 matrix where row 1 (SC1)
# is the sexual recruit contribution from each adult size class column.
#
# Arguments:
#   s_recruit          -- Per-egg→SC1 survival probability (from recruit_surv_pars.rds)
#   oocyte_per_cm2     -- Oocyte density (Mendoza-Quiroz 2023 = 63.6)
#   fertilization_rate -- (Mendoza-Quiroz 2023: 0.95 wild, 0.15 sibling)
#   maturity_size      -- Size at which 90% reproductive (Vardi 2011 = 4000 cm²)
#   size_breaks        -- Size class boundaries
#   sc5_repr_frac      -- Fraction reproductive in SC5 (default 0.9, Vardi 2011)
#   sc4_repr_frac      -- Fraction reproductive in SC4 (default 0.3, linear interpolation)

build_F_sex <- function(s_recruit = 0.028,
                        oocyte_per_cm2 = 63.6,
                        fertilization_rate = 0.95,
                        maturity_size = 4000,
                        size_breaks = SIZE_BREAKS,
                        sc5_repr_frac = 0.9,
                        sc4_repr_frac = 0.3) {
  n_sc <- length(SIZE_LABELS)
  F_sex <- matrix(0, nrow = n_sc, ncol = n_sc,
                  dimnames = list(SIZE_LABELS, SIZE_LABELS))

  # Representative colony size (live tissue) per size class (geometric mean of bounds)
  rep_sizes <- numeric(n_sc)
  rep_sizes[1] <- sqrt(size_breaks[1] + 1) * sqrt(size_breaks[2])     # SC1
  rep_sizes[2] <- sqrt(size_breaks[2] * size_breaks[3])                # SC2
  rep_sizes[3] <- sqrt(size_breaks[3] * size_breaks[4])                # SC3
  rep_sizes[4] <- sqrt(size_breaks[4] * size_breaks[5])                # SC4
  rep_sizes[5] <- size_breaks[5] * 2                                    # SC5 (open-ended, 2x lower bound)

  # Fraction reproductive by size class
  repr_frac <- c(0, 0, 0, sc4_repr_frac, sc5_repr_frac)

  # Sexual recruits contributed to SC1 per adult colony per year
  # = oocyte_density × colony_area × fertilization × settlement × post-settlement survival
  # (s_recruit bundles settlement × post-settlement; Chamberland 2015 calibrated)
  sexual_recruits <- oocyte_per_cm2 * rep_sizes * fertilization_rate *
                     repr_frac * s_recruit

  # All sexual offspring land in SC1
  F_sex["SC1", ] <- sexual_recruits

  F_sex
}


# ============================================================================
# 3. apply_disturbance_lag() — 4-year post-disturbance sterility (Idea 2)
# ============================================================================
# Applies Lirman 2000a fragment sterility to reduce effective F_sex by the
# expected fraction of adults within 4 years of most recent disturbance.
#
# Arguments:
#   F_sex                    -- F_sex matrix from build_F_sex()
#   fraction_recently_disturbed -- Fraction of population within 4-yr disturbance window
#   lag_years                -- Sterility duration (Lirman 2000a default = 4)
#
# Returns:
#   F_sex scaled by (1 - fraction_sterile). If all adults recently disturbed,
#   F_sex approaches 0.

apply_disturbance_lag <- function(F_sex, fraction_recently_disturbed, lag_years = 4) {
  effective_fraction_reproducing <- 1 - fraction_recently_disturbed
  F_sex * effective_fraction_reproducing
}


# ============================================================================
# 4. apply_lesion_penalty() — Partial mortality fecundity penalty (Idea 3)
# ============================================================================
# Piñón-González 2018: lesioned colonies produce ~20% less egg volume.
# Applied as population-weighted scalar: F_sex * (1 - penalty * fraction_lesioned).
#
# Arguments:
#   F_sex             -- F_sex matrix from build_F_sex()
#   fraction_lesioned -- Fraction of reproductive-size adults with active lesions
#                        (derived from shrinkage data in script 52)
#   penalty           -- Per-colony fecundity reduction (default 0.20, Piñón-González 2018)

apply_lesion_penalty <- function(F_sex, fraction_lesioned, penalty = 0.20) {
  F_sex * (1 - penalty * fraction_lesioned)
}


# ============================================================================
# 5. apply_density_dep_SC12() — Depensatory corallivory (Idea 6)
# ============================================================================
# Williams 2012: Coralliophila aggregation on low-density stands drives
# disproportionate SC1-SC2 mortality. Saturating response S(D) = S₀ × D/(K+D).
#
# Arguments:
#   S              -- Baseline survival vector (named SC1-SC5)
#   density_proxy  -- Scalar density index (e.g., mean colonies per plot)
#   K              -- Half-saturation constant (calibrated; default 1.0 on density index)
#   apply_to       -- Which classes (default c("SC1", "SC2"))
#
# Returns:
#   Modified survival vector with depensatory mortality for small classes.

apply_density_dep_SC12 <- function(S, density_proxy, K = 1.0,
                                    apply_to = c("SC1", "SC2")) {
  S_new <- S
  modifier <- density_proxy / (K + density_proxy)
  for (sc in apply_to) {
    if (sc %in% names(S_new)) {
      S_new[sc] <- S[sc] * modifier
    }
  }
  S_new
}


# ============================================================================
# 6. run_scenario() — Dispatch a named scenario config to lambda
# ============================================================================
# Takes a scenario config list and runs the appropriate pipeline.
#
# Config structure:
#   list(
#     name = "S1",
#     survival = S_vector,             # Named SC1-SC5
#     growth = growth_data,             # Data frame with size_cm2 + growth_cm2_yr
#     F_mat = frag_matrix,              # 5x5 fragmentation matrix (from script 13)
#     F_sex = NULL | F_sex_matrix,      # Idea 1: sexual fecundity row
#     disturbance_lag_frac = 0,         # Idea 2: fraction recently disturbed
#     lesion_fraction = 0,              # Idea 3: fraction lesioned
#     density_proxy = NULL,             # Idea 6: density index (NULL = no DD)
#     density_K = 1.0                   # Idea 6: half-saturation
#   )
#
# Returns:
#   list(lambda = ..., matrix = ..., config = ...)

run_scenario <- function(config) {
  S <- config$survival
  F_sex <- config$F_sex

  # Apply lesion penalty if specified (Idea 3)
  if (!is.null(F_sex) && !is.null(config$lesion_fraction) && config$lesion_fraction > 0) {
    F_sex <- apply_lesion_penalty(F_sex, config$lesion_fraction)
  }

  # Apply disturbance sterility lag if specified (Idea 2)
  if (!is.null(F_sex) && !is.null(config$disturbance_lag_frac) &&
      config$disturbance_lag_frac > 0) {
    F_sex <- apply_disturbance_lag(F_sex, config$disturbance_lag_frac)
  }

  # Apply depensatory corallivory if specified (Idea 6)
  if (!is.null(config$density_proxy)) {
    S <- apply_density_dep_SC12(S, config$density_proxy,
                                 K = config$density_K %||% 1.0)
  }

  result <- compute_lambda_from_survival(
    survival_by_class = S,
    growth_data = config$growth,
    frag_matrix = config$F_mat,
    F_sex = F_sex,
    G_override = config$G_override
  )

  result$scenario <- config$name
  result$config <- config
  result
}


# Helper: null-coalescing operator (R doesn't have one built-in)
`%||%` <- function(a, b) if (is.null(a)) b else a


cat("Loaded 03_matrix_functions.R (scenario framework helpers)\n")
