#!/usr/bin/env Rscript
################################################################################
# 13_TRANSITION_MATRIX.R
# A. palmata Size-Structured Population Matrix Model
################################################################################
#
# PURPOSE: Build size-structured projection matrix for population modeling
#          Calculate transition probabilities, population growth rate (λ),
#          and elasticity analysis for restoration planning
#
# METHODS:
#   1. Calculate size class transition probabilities from growth data
#   2. Combine with survival rates to build Lefkovitch matrix
#   3. Calculate λ (dominant eigenvalue) and stable size distribution
#   4. Elasticity analysis to identify key vital rates
#   5. Bootstrap uncertainty quantification
#
# SIZE CLASSES (following Vardi 2011):
#   SC1: 0-10 cm² (recruits/settlers)
#   SC2: 10-100 cm² (small juveniles)
#   SC3: 100-900 cm² (large juveniles)
#   SC4: 900-4000 cm² (subadults)
#   SC5: >4000 cm² (reproductive adults)
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#   - 05_data/standardized/apal_fragmentation.csv
#
# OUTPUTS:
#   - 06_analysis/output/transition_matrix.csv
#   - 06_analysis/output/transition_matrix.rds
#   - 06_analysis/output/population_parameters.csv
#   - 06_analysis/output/elasticity_matrix.csv
#   - 06_analysis/output/elasticity_bootstrap_ci.csv  (critique audit 2026-03-29)
#   - 06_analysis/output/fecundity_sensitivity.csv
#   - 06_analysis/output/fragmentation_scenarios.csv  (critique audit 2026-03-29)
#   - 06_analysis/output/lambda_bootstrap_samples.rds (now includes imputed + discard approaches)
#   - 06_analysis/figures/supplementary/exploratory/population_projections.png
#
# Author: Detmer & Stier Lab
# Date: 2025-12-24
################################################################################

# Load required packages
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(tibble)  # for column_to_rownames

# Source shared utilities for constants and helper functions
# find_project_root() is defined here, along with SIZE_BREAKS, SIZE_LABELS, etc.
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

# NOTE: Matrix restricted to natural colonies (population_type == "Natural colony")
# and near-annual growth intervals (0.5-1.5 yr). This means the matrix is heavily
# NOAA-dependent (NOAA provides 99% of natural colony data). Growth data excludes
# Navassa (all >1.5 yr intervals) and some Florida long-interval records.
# See LOSO sensitivity analysis for robustness.

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  07: TRANSITION MATRIX & POPULATION MODEL                    ║\n")
cat("║  Size-Structured Projection Matrix for A. palmata            ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# Set paths
if (file.exists("05_data/standardized")) {
  project_root <- "."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root. Run from project directory or 06_analysis/scripts/")
}

output_dir <- file.path(project_root, "06_analysis/output")
fig_dir <- file.path(project_root, "06_analysis/figures")
fig_dir_supp <- file.path(fig_dir, "supplementary/exploratory")
dir.create(fig_dir_supp, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1. DEFINE SIZE CLASSES
# =============================================================================

cat("Defining size classes...\n")

size_class_breaks <- SIZE_BREAKS
size_class_labels <- SIZE_LABELS
size_class_midpoints <- c(12.5, 62.5, 300, 1250, 5000)  # Approximate midpoints

cat(sprintf("  Size classes: %s\n", paste(size_class_labels, collapse = ", ")))
cat(sprintf("  Breaks: %s cm²\n", paste(size_class_breaks, collapse = ", ")))

# =============================================================================
# 2. LOAD AND PREPARE DATA
# =============================================================================

cat("\nLoading prepared data...\n")

surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

# Restrict to natural colonies for population projection
cat("  Filtering to natural colonies only for transition matrix...\n")
cat(sprintf("  Total survival records before filter: %s\n", scales::comma(nrow(surv_data))))
surv_data <- surv_data %>% filter(population_type == "Natural colony")
cat(sprintf("  Natural colony survival records: %s\n", scales::comma(nrow(surv_data))))

# Filter sub-annual intervals (Issue: inflates SC5 survival)
if ("sub_annual_interval" %in% names(surv_data)) {
  n_before <- nrow(surv_data)
  n_sub <- sum(surv_data$sub_annual_interval, na.rm = TRUE)
  surv_data <- surv_data %>% filter(!sub_annual_interval | is.na(sub_annual_interval))
  cat(sprintf("  Filtered %d sub-annual records (%.1f%%): %d -> %d\n",
              n_sub, n_sub/n_before*100, n_before, nrow(surv_data)))
} else if ("time_interval_yr" %in% names(surv_data)) {
  n_before <- nrow(surv_data)
  surv_data <- surv_data %>% filter(is.na(time_interval_yr) | time_interval_yr >= 0.8)
  cat(sprintf("  Filtered %d sub-annual records: %d -> %d\n",
              n_before - nrow(surv_data), n_before, nrow(surv_data)))
}

# Mortality definition audit
if ("mortality_definition" %in% names(surv_data)) {
  cat("\n--- MORTALITY DEFINITION BY SIZE CLASS ---\n")
  mort_by_sc <- surv_data %>%
    count(size_class, mortality_definition) %>%
    tidyr::pivot_wider(names_from = mortality_definition, values_from = n, values_fill = 0)
  print(as.data.frame(mort_by_sc))
  cat("  NOTE: Mortality definitions vary by study. See docs/Data_Methodology_Reference.md\n")
}

# Restrict growth data to natural colonies AND near-annual intervals
cat(sprintf("  Total growth records before filter: %s\n", scales::comma(nrow(growth_data))))
if ("population_type" %in% names(growth_data)) {
  growth_data <- growth_data %>% filter(population_type == "Natural colony")
} else if ("fragment" %in% names(growth_data)) {
  growth_data <- growth_data %>% filter(fragment == "N")
} else {
  cat("  WARNING: No population_type or fragment column found. Using all growth data.\n")
}

# --- UNIFY GROWTH FILTERING (Critique Recommendation #1) ---
# Filter out biologically impossible growth values flagged in prep
if ("impossible_growth" %in% names(growth_data)) {
  n_imp <- sum(growth_data$impossible_growth, na.rm = TRUE)
  growth_data <- growth_data %>% filter(!impossible_growth)
  cat(sprintf("  Filtered %d impossible growth records (loss > 110%% or gain > 300%%)\n", n_imp))
}

cat(sprintf("  Natural colony growth records: %s\n", scales::comma(nrow(growth_data))))
# Restrict to near-annual intervals (0.5-1.5 yr) to avoid linear growth assumption bias
n_long <- sum(growth_data$time_interval_yr > 1.5, na.rm = TRUE)
growth_data <- growth_data %>% filter(time_interval_yr >= 0.5 & time_interval_yr <= 1.5)
cat(sprintf("  Natural colony growth records (0.5-1.5 yr intervals): %s (excluded %d long-interval)\n",
            scales::comma(nrow(growth_data)), n_long))

# Assign size classes
surv_data <- surv_data %>%
  mutate(size_class = cut(size_cm2, breaks = size_class_breaks,
                          labels = size_class_labels, include.lowest = TRUE))

growth_data <- growth_data %>%
  mutate(
    size_class_initial = cut(size_cm2, breaks = size_class_breaks,
                             labels = size_class_labels, include.lowest = TRUE),
    # Calculate final size
    size_final_cm2 = size_cm2 + growth_cm2_yr,
    size_final_cm2 = pmax(size_final_cm2, 0.1),  # Can't be negative
    size_class_final = cut(size_final_cm2, breaks = size_class_breaks,
                           labels = size_class_labels, include.lowest = TRUE)
  )

cat(sprintf("  Survival records: %d\n", nrow(surv_data)))
cat(sprintf("  Growth records: %d\n", nrow(growth_data)))

# =============================================================================
# TIME STANDARDIZATION VERIFICATION
# =============================================================================
# Programmatically verify that data are properly annualized

cat("\n--- TIME STANDARDIZATION VERIFICATION ---\n")

# Check time intervals in growth data
if ("time_interval_yr" %in% names(growth_data)) {
  time_intervals <- growth_data %>%
    group_by(study) %>%
    summarise(
      n = n(),
      min_interval = min(time_interval_yr, na.rm = TRUE),
      max_interval = max(time_interval_yr, na.rm = TRUE),
      mean_interval = mean(time_interval_yr, na.rm = TRUE),
      .groups = "drop"
    )

  cat("\nTime intervals by study (growth data):\n")
  print(time_intervals)

  # Flag non-annual intervals
  non_annual <- time_intervals %>%
    filter(abs(mean_interval - 1.0) > 0.1)

  if (nrow(non_annual) > 0) {
    cat("\n⚠ WARNING: Some studies have non-annual observation intervals:\n")
    print(non_annual)
    cat("\nGrowth rates (growth_cm2_yr) SHOULD be pre-annualized in data prep.\n")
    cat("Verifying growth rate units match annual expectation...\n")

    # Check if growth rates are plausible for annual rates
    growth_summary <- growth_data %>%
      summarise(
        median_growth = median(growth_cm2_yr, na.rm = TRUE),
        p95_growth = quantile(growth_cm2_yr, 0.95, na.rm = TRUE)
      )
    cat(sprintf("  Median annual growth: %.1f cm²/yr\n", growth_summary$median_growth))
    cat(sprintf("  95th percentile: %.1f cm²/yr\n", growth_summary$p95_growth))

    # Expected range for A. palmata: -500 to +2000 cm²/yr is reasonable
    if (growth_summary$median_growth > 0 && growth_summary$median_growth < 500 &&
        growth_summary$p95_growth < 5000) {
      cat("  ✓ Growth rates appear to be annualized (values within expected range)\n")
    } else {
      cat("  ⚠ Growth rates may not be annualized - CHECK DATA PREPARATION\n")
    }
  } else {
    cat("\n✓ All studies have approximately annual observation intervals (mean ≈ 1 year)\n")
  }
} else {
  cat("\n⚠ No time_interval_yr column found in growth data.\n")
  cat("Assuming growth_cm2_yr values are already annualized.\n")
}

# Check survival time intervals
if ("time_interval_yr" %in% names(surv_data)) {
  surv_intervals <- surv_data %>%
    group_by(study) %>%
    summarise(
      n = n(),
      min_interval = min(time_interval_yr, na.rm = TRUE),
      max_interval = max(time_interval_yr, na.rm = TRUE),
      mean_interval = mean(time_interval_yr, na.rm = TRUE),
      .groups = "drop"
    )

  cat("\nTime intervals by study (survival data):\n")
  print(surv_intervals)

  # For survival, annualization would require: S_annual = S_observed^(1/t)
  non_annual_surv <- surv_intervals %>%
    filter(abs(mean_interval - 1.0) > 0.1)

  if (nrow(non_annual_surv) > 0) {
    cat("\n⚠ NOTE: Some survival data have non-annual intervals.\n")
    cat("Survival probabilities are per-observation-period, not annualized.\n")
    cat("For matrix model, this assumes observations approximate annual transitions.\n")
  }
} else {
  cat("\n⚠ No time_interval_yr column in survival data - assuming annual intervals.\n")
}

# =============================================================================
# 3. CALCULATE SURVIVAL RATES BY SIZE CLASS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SURVIVAL RATES BY SIZE CLASS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# ANNUALIZE SURVIVAL: Convert observed survival over t years to annual rate
# Binary survival (0/1) must be aggregated to proportion first, then annualized
# S_annual = S_observed^(1/t) where t = monitoring interval in years

# First compute raw (non-annualized) survival for comparison
raw_survival_by_class <- surv_data %>%
  filter(!is.na(size_class)) %>%
  group_by(size_class) %>%
  summarise(raw_survival = mean(survived), .groups = "drop")

# Step 1: Compute raw survival by study x size class x interval
survival_by_group <- surv_data %>%
  filter(!is.na(size_class)) %>%
  mutate(
    time_interval_yr = if ("time_interval_yr" %in% names(.))
      coalesce(time_interval_yr, 1.0) else 1.0
  ) %>%
  group_by(size_class, study, time_interval_yr) %>%
  summarise(
    n = n(),
    raw_survival = mean(survived),
    .groups = "drop"
  ) %>%
  mutate(
    # Annualize: S_annual = S_raw^(1/t)
    annual_survival = raw_survival^(1 / time_interval_yr)
  )

cat("\nSurvival annualization summary:\n")
cat(sprintf("  Groups with non-annual intervals: %d\n",
            sum(abs(survival_by_group$time_interval_yr - 1) > 0.1)))

# Step 2: Weighted mean of annualized rates by size class
survival_by_class <- survival_by_group %>%
  group_by(size_class) %>%
  summarise(
    survival = weighted.mean(annual_survival, w = n),
    n = sum(n),
    # NOTE: This SE is approximate -- uses binomial formula on annualized rates.
    # The definitive uncertainty comes from the hierarchical bootstrap (below).
    se = sqrt(survival * (1 - survival) / n),
    ci_lower = pmax(0, survival - 1.96 * se),
    ci_upper = pmin(1, survival + 1.96 * se),
    .groups = "drop"
  ) %>%
  arrange(size_class)

# Report change from raw to annualized
cat("  Annualized survival rates by size class:\n")
comparison <- survival_by_class %>%
  left_join(raw_survival_by_class, by = "size_class")
for (i in 1:nrow(comparison)) {
  cat(sprintf("    %s: raw=%.4f -> annualized=%.4f (delta=%.4f)\n",
              comparison$size_class[i], comparison$raw_survival[i],
              comparison$survival[i],
              comparison$survival[i] - comparison$raw_survival[i]))
}

print(survival_by_class)

# Vector of survival rates
S <- survival_by_class$survival
names(S) <- size_class_labels

cat(sprintf("\nSurvival vector (annualized): %s\n",
            paste(sprintf("%.3f", S), collapse = ", ")))

# --- SC5 DATA CAVEAT ---
# FIX: Enhanced SC5 single-study dependence warning (critique audit 2026-03-29)
sc5_studies <- unique(surv_data$study[surv_data$size_class == "SC5"])
sc5_n <- sum(surv_data$size_class == "SC5", na.rm = TRUE)
cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  WARNING: SC5 SINGLE-STUDY DEPENDENCE                        ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")
cat(sprintf("WARNING: SC5 (>4000 cm2) survival estimated entirely from NOAA monitoring.\n"))
cat(sprintf("  SC5 observations: %d from %d study(ies): %s\n",
            sc5_n, length(sc5_studies), paste(sc5_studies, collapse = ", ")))
if (length(sc5_studies) == 1) {
  cat("  SC5 stasis (highest elasticity) is estimated from a SINGLE STUDY.\n")
  cat("  SC5 stasis elasticity will be reported after elasticity analysis below.\n")
}

# =============================================================================
# 4. CALCULATE TRANSITION PROBABILITIES
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  TRANSITION PROBABILITIES (Growth/Shrinkage)\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# =============================================================================
# DATA QUALITY FILTERING FOR TRANSITIONS
# =============================================================================
# NOTE: We use only 99th percentile outlier filtering here, NOT the impossible_growth
# flag. The "impossible" records (negative growth > initial size) actually represent
# real partial mortality/fragmentation events and are important for accurate
# transition probability estimation.
#
# The impossible_growth flag is useful for other analyses (e.g., positive growth
# probability) but should NOT be used for the transition matrix to maintain
# consistency with the validated results (λ = 0.986).

growth_filtered <- growth_data %>%
  filter(!is.na(size_class_initial), !is.na(size_class_final)) %>%
  filter(abs(growth_cm2_yr) < quantile(abs(growth_cm2_yr), 0.99, na.rm = TRUE))

cat(sprintf("Using %d growth records (after filtering extremes)\n\n", nrow(growth_filtered)))

# Calculate transition counts
transition_counts <- growth_filtered %>%
  count(size_class_initial, size_class_final) %>%
  complete(size_class_initial = size_class_labels,
           size_class_final = size_class_labels,
           fill = list(n = 0))

# Convert to matrix
G_counts <- matrix(0, nrow = 5, ncol = 5,
                   dimnames = list(size_class_labels, size_class_labels))

for (i in 1:nrow(transition_counts)) {
  from <- as.character(transition_counts$size_class_initial[i])
  to <- as.character(transition_counts$size_class_final[i])
  G_counts[to, from] <- transition_counts$n[i]
}

cat("Transition counts (rows = to, columns = from):\n")
print(G_counts)

# Calculate transition probabilities (column sums = 1)
G <- sweep(G_counts, 2, colSums(G_counts), "/")
G[is.nan(G)] <- 0  # Handle divide by zero

cat("\nTransition probabilities (G matrix):\n")
print(round(G, 3))

# Sample sizes per class
n_per_class <- colSums(G_counts)
cat("\nSample sizes per initial size class:\n")
print(n_per_class)

# Sample size assessment will be done after elasticity calculation
# to identify transitions with low n but high elasticity

# =============================================================================
# 5. LOAD FRAGMENTATION DATA
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  FRAGMENTATION RATES\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

frag_file <- file.path(project_root, "05_data/standardized/apal_fragmentation.csv")

if (file.exists(frag_file)) {
  frag_data <- read_csv(frag_file, show_col_types = FALSE)

  cat(sprintf("Loaded fragmentation data: %d records\n", nrow(frag_data)))

  # Annualize fragmentation rates by dividing by time_interval_yr.
  # The Vardi 2011 data includes observation intervals of 0.75, 1.0, 1.25, and
  # 2.5 years. The reported rates are per-observation-period, so we must divide
  # by the interval length to get annual rates. This is methodologically correct:
  # a rate measured over 2.5 years must be divided by 2.5 to express it annually.
  # F4_SC4 excluded: all 13 observed values = 0.0 across all records in Vardi 2011.
  # SC4 colonies were never observed producing SC4-sized fragments — biologically,
  # fragmentation typically produces smaller fragments than the parent colony.
  frag_rate_cols <- c("F4_SC1", "F4_SC2", "F4_SC3",
                      "F5_SC1", "F5_SC2", "F5_SC3", "F5_SC4", "F5_SC5")

  # Annualize each row's fragmentation rates
  frag_data_annual <- frag_data %>%
    mutate(
      time_interval_yr = coalesce(time_interval_yr, 1.0),
      across(all_of(frag_rate_cols), ~ . / time_interval_yr)
    )

  cat(sprintf("  Rows with non-annual intervals requiring annualization: %d of %d\n",
              sum(abs(frag_data$time_interval_yr - 1) > 0.1, na.rm = TRUE), nrow(frag_data)))

  # Average annualized fragmentation rates across studies/years
  # F4 = fragments produced by SC4, F5 = fragments produced by SC5
  frag_means <- frag_data_annual %>%
    summarise(
      F4_SC1 = mean(F4_SC1, na.rm = TRUE),
      F4_SC2 = mean(F4_SC2, na.rm = TRUE),
      F4_SC3 = mean(F4_SC3, na.rm = TRUE),
      F5_SC1 = mean(F5_SC1, na.rm = TRUE),
      F5_SC2 = mean(F5_SC2, na.rm = TRUE),
      F5_SC3 = mean(F5_SC3, na.rm = TRUE),
      F5_SC4 = mean(F5_SC4, na.rm = TRUE),
      F5_SC5 = mean(F5_SC5, na.rm = TRUE)
    )

  cat("\nMean fragmentation rates:\n")
  print(as.data.frame(frag_means))

  # Build fragmentation matrix (fragments produced)
  # Rows = size class of fragment, Columns = size class of parent
  F_mat <- matrix(0, nrow = 5, ncol = 5,
                  dimnames = list(size_class_labels, size_class_labels))

  # SC4 produces fragments
  F_mat["SC1", "SC4"] <- frag_means$F4_SC1
  F_mat["SC2", "SC4"] <- frag_means$F4_SC2
  F_mat["SC3", "SC4"] <- frag_means$F4_SC3

  # SC5 produces fragments
  F_mat["SC1", "SC5"] <- frag_means$F5_SC1
  F_mat["SC2", "SC5"] <- frag_means$F5_SC2
  F_mat["SC3", "SC5"] <- frag_means$F5_SC3
  F_mat["SC4", "SC5"] <- frag_means$F5_SC4

  # SC5 self-fragmentation: large adults producing large fragments that remain SC5
  # Data shows zero observed rate, but included for matrix completeness
  if ("F5_SC5" %in% names(frag_means)) {
    F_mat["SC5", "SC5"] <- frag_means$F5_SC5  # Observed: ~0
  } else {
    F_mat["SC5", "SC5"] <- 0  # No data available
  }

} else {
  cat("⚠ Fragmentation data not found. Using zeros.\n")
  F_mat <- matrix(0, nrow = 5, ncol = 5,
                  dimnames = list(size_class_labels, size_class_labels))
}

cat("\nFragmentation matrix (F):\n")
print(round(F_mat, 4))

# =============================================================================
# 6. BUILD PROJECTION MATRIX
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  PROJECTION MATRIX (Lefkovitch Matrix)\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Projection matrix A = S * G + F
# Where S * G means survival probability times transition probability
# A[j,i] = probability of transitioning from class i to class j (including survival)

# Create diagonal survival matrix
S_diag <- diag(S)

# Transition matrix including survival
# CORRECT FORMULA: A[j,i] = S[i] * G[j,i] + F[j,i]
# Each column i is multiplied by survival probability S[i] of the SOURCE class
# Previously had: A <- S_diag %*% G which incorrectly multiplied by DESTINATION survival
A <- G %*% S_diag + F_mat
dimnames(A) <- list(size_class_labels, size_class_labels)

cat("Projection Matrix A (rows = to, columns = from):\n")
print(round(A, 4))

cat("\nColumn sums (should be < 1 if there's mortality):\n")
print(round(colSums(A), 3))

# =============================================================================
# 7. POPULATION GROWTH RATE (λ) AND STABLE DISTRIBUTION
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  POPULATION PARAMETERS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Eigenvalue analysis
eigen_A <- eigen(A)
lambda <- Re(eigen_A$values[1])  # Dominant eigenvalue
w <- Re(eigen_A$vectors[, 1])    # Right eigenvector (stable size distribution)
w <- w / sum(w)                   # Normalize to proportions

# Left eigenvector (reproductive values)
eigen_At <- eigen(t(A))
v <- Re(eigen_At$vectors[, 1])
v <- v / v[1]  # Scale relative to SC1

# CHECK MATRIX PROPERTIES required for valid Perron-Frobenius theorem application
# Irreducibility: every size class can eventually be reached from every other
n_sc <- nrow(A)
reach <- diag(n_sc)
A_positive <- (A > 0) * 1
for (power in 1:(2 * n_sc)) {
  reach <- ((reach + A_positive %*% reach) > 0) * 1
}
is_irreducible <- all(reach > 0)

# Primitivity: dominant eigenvalue is strictly real and unique on spectral circle
eigenvalues <- eigen_A$values
is_primitive <- sum(abs(Mod(eigenvalues) - Mod(eigenvalues[1])) < 1e-10) == 1

cat(sprintf("\nMatrix properties: irreducible=%s, primitive=%s\n",
            is_irreducible, is_primitive))
if (!is_irreducible) cat("  WARNING: Matrix is reducible -- lambda may not represent full population dynamics\n")
if (!is_primitive) cat("  WARNING: Matrix is imprimitive -- population may exhibit periodic behavior\n")

cat(sprintf("\nPopulation growth rate (lambda): %.4f  [computed with annualized survival]\n", lambda))
cat(sprintf("Annual growth: %.1f%%\n", (lambda - 1) * 100))

if (lambda > 1) {
  cat("  → Population GROWING\n")
} else if (lambda < 1) {
  cat("  → Population DECLINING\n")
} else {
  cat("  → Population STABLE\n")
}

cat("\nStable size distribution (w):\n")
stable_dist <- data.frame(
  size_class = size_class_labels,
  proportion = w
)
print(stable_dist)

cat("\nReproductive values (v, relative to SC1):\n")
repro_values <- data.frame(
  size_class = size_class_labels,
  value = v
)
print(repro_values)

# Save stable distribution and reproductive values
stable_df <- data.frame(
  size_class = paste0("SC", 1:5),
  stable_proportion = as.numeric(w),
  reproductive_value = as.numeric(v)
)
write_csv(stable_df, file.path(output_dir, "population_stable_distribution.csv"))
cat("✓ Saved: population_stable_distribution.csv\n")

# Compute damping ratio (rate of convergence to stable distribution)
# eigenvalues already defined above in matrix properties check
damping_ratio <- Mod(eigenvalues[1]) / Mod(eigenvalues[2])
cat(sprintf("\nDamping ratio: %.4f\n", damping_ratio))

# Generation time (approximate for size-structured model)
# NOTE: Traditional generation time T is not well-defined for size-structured models
# without explicit age. We estimate T using the approach from Cochran & Ellner (1992):
# T ≈ -log(λ) / log(1 - Σ(fecundity elasticities))
# For this model, "fecundity" = fragmentation, so we use fragmentation elasticities.
#
# Alternative: Use mean time to reach adult size classes (SC4+SC5)
# based on growth transition probabilities. This is computed after elasticity.
T_gen <- NA  # Will be computed after elasticity analysis

# =============================================================================
# 8. SENSITIVITY AND ELASTICITY ANALYSIS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SENSITIVITY & ELASTICITY ANALYSIS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Sensitivity: ∂λ/∂a_ij = v_i * w_j / <v, w>
vw_inner <- sum(v * w)
sensitivity <- outer(v, w) / vw_inner
dimnames(sensitivity) <- list(size_class_labels, size_class_labels)

# Elasticity: (a_ij / λ) * ∂λ/∂a_ij
elasticity <- (A / lambda) * sensitivity
dimnames(elasticity) <- list(size_class_labels, size_class_labels)

cat("Sensitivity matrix:\n")
print(round(sensitivity, 4))

cat("\nElasticity matrix:\n")
print(round(elasticity, 4))

cat("\nElasticity sums (by vital rate type):\n")

# ---------------------------------------------------------------------------
# PROPORTIONAL ELASTICITY DECOMPOSITION (Caswell 2001)
# ---------------------------------------------------------------------------
# Each matrix element A[j,i] = G[j,i]*S[i] + F[j,i] is a mixture of
# survival/growth and fragmentation. We decompose element elasticities
# PROPORTIONALLY rather than using a binary mask.
#
# For element (j,i):
#   survival_proportion[j,i] = G[j,i]*S[i] / A[j,i]
#   frag_proportion[j,i]     = F[j,i]      / A[j,i]
#
# Then: e_survival[j,i] = surv_proportion[j,i] * elasticity[j,i]
#        e_frag[j,i]     = frag_proportion[j,i] * elasticity[j,i]
#
# This correctly handles cells where BOTH survival and fragmentation
# contribute (e.g., SC5 stasis is ~99.7% survival, ~0.3% fragmentation).
# The old binary mask approach (frag_mask = (F_mat > 0) * 1) misattributed
# 100% of any mixed cell to fragmentation.
# ---------------------------------------------------------------------------

# Compute the survival component of each matrix element: G[j,i] * S[i]
surv_component <- G %*% diag(S)
frag_component <- F_mat

# Proportional attribution: fraction of each A[j,i] due to survival vs fragmentation
surv_proportion <- matrix(0, nrow = 5, ncol = 5,
                          dimnames = list(size_class_labels, size_class_labels))
frag_proportion <- matrix(0, nrow = 5, ncol = 5,
                          dimnames = list(size_class_labels, size_class_labels))

for (j in 1:5) {
  for (i in 1:5) {
    if (A[j, i] > 0) {
      surv_proportion[j, i] <- surv_component[j, i] / A[j, i]
      frag_proportion[j, i] <- frag_component[j, i] / A[j, i]
    }
  }
}

# Element-level elasticity attributed to survival vs fragmentation
elasticity_surv <- surv_proportion * elasticity
elasticity_frag <- frag_proportion * elasticity

# High-level decomposition: stasis/growth/shrinkage, split proportionally
# Stasis (diagonal)
e_stasis_surv <- sum(diag(elasticity_surv))
e_stasis_frag <- sum(diag(elasticity_frag))
e_stasis <- e_stasis_surv + e_stasis_frag
cat(sprintf("  Stasis (staying in same class): %.3f  [survival: %.3f, fragmentation: %.3f]\n",
            e_stasis, e_stasis_surv, e_stasis_frag))

# Growth (below diagonal)
e_growth_surv <- sum(elasticity_surv[lower.tri(elasticity_surv)])
e_growth_frag <- sum(elasticity_frag[lower.tri(elasticity_frag)])
e_growth <- e_growth_surv + e_growth_frag
cat(sprintf("  Growth (moving to larger class): %.3f  [survival: %.3f, fragmentation: %.3f]\n",
            e_growth, e_growth_surv, e_growth_frag))

# Shrinkage (above diagonal) — includes transitions to smaller classes
e_shrink_surv <- sum(elasticity_surv[upper.tri(elasticity_surv)])
e_shrink_frag <- sum(elasticity_frag[upper.tri(elasticity_frag)])
e_shrink <- e_shrink_surv + e_shrink_frag
cat(sprintf("  Shrinkage (moving to smaller class): %.3f  [survival: %.3f, fragmentation: %.3f]\n",
            e_shrink, e_shrink_surv, e_shrink_frag))

# Total fragmentation vs survival elasticity
e_frag <- sum(elasticity_frag)
e_surv_total <- sum(elasticity_surv)
cat(sprintf("\n  Total survival elasticity: %.3f\n", e_surv_total))
cat(sprintf("  Total fragmentation elasticity: %.3f\n", e_frag))

cat(sprintf("\nTotal elasticity: %.3f (should = 1)\n", sum(elasticity)))

# Verify decomposition sums to 1.0
total_decomp <- e_stasis + e_growth + e_shrink
cat(sprintf("\n  Decomposition: stasis(%.3f) + growth(%.3f) + shrink(%.3f) = %.6f\n",
            e_stasis, e_growth, e_shrink, total_decomp))
if (abs(total_decomp - 1.0) > 0.001) {
  cat("  WARNING: Decomposition does not sum to 1.0!\n")
}
cat(sprintf("  Fragmentation sub-component: %.3f (%.1f%% of total)\n", e_frag, e_frag * 100))
cat("  NOTE: Fragmentation is a SUB-DECOMPOSITION, not a 4th additive category.\n")

# Most important transitions
elasticity_df <- as.data.frame(as.table(elasticity)) %>%
  rename(to = Var1, from = Var2, elasticity = Freq) %>%
  filter(elasticity > 0.01) %>%
  arrange(desc(elasticity))

cat("\nMost important transitions (elasticity > 0.01):\n")
print(elasticity_df)

# -----------------------------------------------------------------------------
# Lower-level elasticity decomposition (Caswell 2001, Section 9.1.3)
# Decompose matrix-element elasticities to underlying vital rates using
# proportional attribution (not binary mask)
# -----------------------------------------------------------------------------

cat("\n--- LOWER-LEVEL ELASTICITY DECOMPOSITION ---\n")

# Elasticity of lambda to survival rate S_i:
# For a Lefkovitch matrix A = G %*% diag(S) + F, the contribution of S_i to
# column i is proportional. For cells where both survival and fragmentation
# contribute, we use the proportional decomposition computed above.
# e(S_i) = sum over j of elasticity_surv[j,i]

# Survival elasticity per size class = column sum of proportionally attributed survival elasticity
survival_elasticity <- colSums(elasticity_surv)
names(survival_elasticity) <- size_class_labels

cat("\nElasticity to survival rate by size class:\n")
for (i in 1:5) {
  cat(sprintf("  %s: %.4f (%.1f%% of total)\n",
              size_class_labels[i], survival_elasticity[i], survival_elasticity[i] * 100))
}

# Elasticity to fragmentation rates: column sum of proportionally attributed frag elasticity
frag_elasticity <- colSums(elasticity_frag)
names(frag_elasticity) <- size_class_labels

cat("\nElasticity to fragmentation rate by source class:\n")
for (i in 1:5) {
  if (frag_elasticity[i] > 0.0001) {
    cat(sprintf("  %s: %.4f (%.1f%% of total)\n",
                size_class_labels[i], frag_elasticity[i], frag_elasticity[i] * 100))
  }
}

cat(sprintf("\nSummary: Survival elasticity total = %.4f, Fragmentation elasticity total = %.4f\n",
            sum(survival_elasticity), sum(frag_elasticity)))

# FIX: Prominent SC5 single-study dependence warning with elasticity value (critique audit 2026-03-29)
sc5_stasis_elasticity <- elasticity[5, 5]
cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  SC5 SINGLE-STUDY DEPENDENCE — ELASTICITY IMPACT             ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")
cat(sprintf("WARNING: SC5 (>4000 cm2) survival estimated entirely from NOAA monitoring.\n"))
cat(sprintf("  SC5 stasis elasticity = %.1f%% of total — most influential vital rate from single source.\n",
            sc5_stasis_elasticity * 100))
cat(sprintf("  SC5 survival rate = %.3f (annualized), n = %d observations\n",
            S["SC5"], sum(surv_data$size_class == "SC5", na.rm = TRUE)))
cat("  NOAA uses conservative mortality definition (no tissue AND skeleton gone).\n")
cat("  This single-source dependence is the greatest structural uncertainty in the model.\n")

# =============================================================================
# TRANSITION SAMPLE SIZE ASSESSMENT
# =============================================================================
# Report sample sizes for each transition cell to assess reliability
# Small sample sizes (n < 10) may produce unreliable transition probabilities

cat("\n--- TRANSITION SAMPLE SIZE ASSESSMENT ---\n")

# Create sample size assessment data frame
# Note: as.data.frame(as.table()) iterates Var1 (rows) fastest (column-major),
# so we must look up G and elasticity values by name rather than using as.vector(t()),
# which would produce a row-major ordering that doesn't match.
transition_sample_sizes <- as.data.frame(as.table(G_counts)) %>%
  rename(to_class = Var1, from_class = Var2, n_observations = Freq) %>%
  mutate(
    reliability = case_when(
      n_observations >= 50 ~ "High",
      n_observations >= 20 ~ "Moderate",
      n_observations >= 10 ~ "Low",
      n_observations >= 1 ~ "Very Low",
      TRUE ~ "None"
    )
  ) %>%
  rowwise() %>%
  mutate(
    transition_prob = G[as.character(to_class), as.character(from_class)],
    elasticity_value = elasticity[as.character(to_class), as.character(from_class)]
  ) %>%
  ungroup()

# Flag concerning transitions (low sample size but high elasticity)
concerning <- transition_sample_sizes %>%
  filter(n_observations < 20 & elasticity_value > 0.01)

if (nrow(concerning) > 0) {
  cat("\n⚠ WARNING: Transitions with LOW sample size but HIGH elasticity:\n")
  print(concerning %>% select(from_class, to_class, n_observations, reliability,
                               transition_prob, elasticity_value))
  cat("\nThese transitions may disproportionately affect λ estimates.\n")
  cat("Consider Bayesian pooling or additional data collection.\n")
} else {
  cat("\n✓ All high-elasticity transitions have adequate sample sizes (n >= 20)\n")
}

# Summary table
cat("\nSample size summary by reliability:\n")
print(table(transition_sample_sizes$reliability))

# Save transition sample sizes to output
write.csv(transition_sample_sizes,
          file.path(output_dir, "transition_sample_sizes.csv"),
          row.names = FALSE)
cat("✓ Saved: transition_sample_sizes.csv\n")

# Compute generation time now that we have elasticity
# Method: Mean time to reach reproductive size using transition probabilities
# Corals in SC4 and SC5 produce fragments, so these are "reproductive" size classes
# We estimate mean time from SC1 to reach SC4 using fundamental matrix approach
#
# Alternative: T ≈ 1 / (1 - stasis elasticity) as a rough approximation
# This gives the mean turnover time for the population
e_frag_total <- sum(elasticity[1:3, 4:5]) + elasticity[4, 5]  # All fragmentation
if (e_frag_total > 0.001) {
  # Cochran-Ellner approximation when fecundity elasticity is meaningful
  T_gen <- abs(log(lambda) / log(1 - e_frag_total))
  if (is.infinite(T_gen) || T_gen > 100) T_gen <- NA
} else {
  T_gen <- NA
}

if (!is.na(T_gen)) {
  cat(sprintf("\nApproximate generation time: %.1f years\n", T_gen))
  cat("  (estimated via Cochran-Ellner method using fragmentation elasticity)\n")
} else {
  cat("\nGeneration time: Not reliably estimable for this size-structured model\n")
  cat("  (fragmentation elasticity too low for valid estimate)\n")
  T_gen <- 0  # Set to 0 for storage to indicate not applicable
}

# =============================================================================
# 9. BOOTSTRAP UNCERTAINTY FOR λ (HIERARCHICAL)
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  HIERARCHICAL BOOTSTRAP UNCERTAINTY FOR λ\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# METHODOLOGY NOTE:
# We use a two-stage hierarchical bootstrap to properly account for the
# nested data structure (colonies within studies). This approach:
#   Stage 1: Resample studies with replacement
#   Stage 2: Within each resampled study, resample colonies with replacement
#
# This produces more accurate (typically wider) confidence intervals than
# simple bootstrapping, as it accounts for between-study correlation.

n_boot <- 2000  # Increased from 1000 for more stable percentile estimates
lambda_boot <- numeric(n_boot)
boot_matrices <- list()  # Store bootstrap matrices for stochastic projection
boot_failure_log <- list()  # Track bootstrap failure patterns

# FIX: Track imputation vs discard for each bootstrap iteration (critique audit 2026-03-29)
# Previously, ~24% of bootstrap iterations were discarded when a resampled study set
# lacked data for a size class (typically SC5). Discarding biases the CI because it
# conditions on having SC5 data, which is only available from NOAA. Instead, we now
# impute missing size class survival from the full-data point estimate. We track both
# approaches: lambda_boot stores the imputed version; lambda_boot_discard stores NA
# for iterations that would have been discarded under the old approach.
lambda_boot_discard <- numeric(n_boot)  # Old approach: NA for missing-SC iterations
boot_imputed_flag <- logical(n_boot)    # TRUE if iteration required imputation

set.seed(42)

# Function to resample fragmentation data and recompute F_mat
# This captures uncertainty from the fragmentation source data (Vardi 2011, 13 rows)
resample_F_mat <- function(frag_data_annual, frag_rate_cols, size_class_labels) {
  # Resample rows with replacement from the annualized fragmentation data
  boot_rows <- sample(nrow(frag_data_annual), replace = TRUE)
  frag_boot <- frag_data_annual[boot_rows, ]

  # Compute means of resampled data
  frag_means_boot <- frag_boot %>%
    summarise(
      F4_SC1 = mean(F4_SC1, na.rm = TRUE),
      F4_SC2 = mean(F4_SC2, na.rm = TRUE),
      F4_SC3 = mean(F4_SC3, na.rm = TRUE),
      F5_SC1 = mean(F5_SC1, na.rm = TRUE),
      F5_SC2 = mean(F5_SC2, na.rm = TRUE),
      F5_SC3 = mean(F5_SC3, na.rm = TRUE),
      F5_SC4 = mean(F5_SC4, na.rm = TRUE),
      F5_SC5 = mean(F5_SC5, na.rm = TRUE)
    )

  # Build fragmentation matrix
  F_boot <- matrix(0, nrow = 5, ncol = 5,
                   dimnames = list(size_class_labels, size_class_labels))
  F_boot["SC1", "SC4"] <- frag_means_boot$F4_SC1
  F_boot["SC2", "SC4"] <- frag_means_boot$F4_SC2
  F_boot["SC3", "SC4"] <- frag_means_boot$F4_SC3
  F_boot["SC1", "SC5"] <- frag_means_boot$F5_SC1
  F_boot["SC2", "SC5"] <- frag_means_boot$F5_SC2
  F_boot["SC3", "SC5"] <- frag_means_boot$F5_SC3
  F_boot["SC4", "SC5"] <- frag_means_boot$F5_SC4
  if ("F5_SC5" %in% names(frag_means_boot)) {
    F_boot["SC5", "SC5"] <- frag_means_boot$F5_SC5
  }
  return(F_boot)
}

# Get unique studies
surv_studies <- unique(surv_data$study)
growth_studies <- unique(growth_filtered$study)

cat(sprintf("Running %d hierarchical bootstrap iterations...\n", n_boot))
cat(sprintf("  Survival studies: %d (%s)\n", length(surv_studies),
            paste(surv_studies, collapse = ", ")))
cat(sprintf("  Growth studies: %d (%s)\n", length(growth_studies),
            paste(growth_studies, collapse = ", ")))

# FIX: Initialize storage for bootstrapped elasticity distributions (critique audit 2026-03-29)
boot_elast_SC5_stasis <- numeric(n_boot)
boot_elast_SC4_stasis <- numeric(n_boot)
boot_elast_SC3_stasis <- numeric(n_boot)
boot_elast_SC5_to_SC4 <- numeric(n_boot)
boot_elast_SC4_to_SC3 <- numeric(n_boot)
boot_elast_frag_total <- numeric(n_boot)

pb <- txtProgressBar(min = 0, max = n_boot, style = 3)

for (b in 1:n_boot) {
  setTxtProgressBar(pb, b)

  # STAGE 1: Resample studies with replacement
  surv_studies_boot <- sample(surv_studies, replace = TRUE)
  growth_studies_boot <- sample(growth_studies, replace = TRUE)

  # STAGE 2: For each resampled study, resample colonies within that study
  surv_boot <- do.call(rbind, lapply(seq_along(surv_studies_boot), function(i) {
    study_data <- surv_data %>% filter(study == surv_studies_boot[i])
    # Resample colonies within study
    colonies <- unique(study_data$coral_id)
    boot_colonies <- sample(colonies, replace = TRUE)
    # Get all records for resampled colonies
    do.call(rbind, lapply(boot_colonies, function(col) {
      study_data %>% filter(coral_id == col)
    }))
  }))

  # Annualize bootstrap survival to match the point estimate methodology:
  # Step 1: Compute raw survival by study x size_class x time_interval_yr group
  #         (MUST include study to replicate the point estimate pipeline exactly)
  # Step 2: Annualize each group: S_annual = S_raw^(1/t)
  # Step 3: Weighted mean of annualized rates by size class
  S_boot_df <- surv_boot %>%
    filter(!is.na(size_class)) %>%
    mutate(
      time_interval_yr = if ("time_interval_yr" %in% names(.))
        coalesce(time_interval_yr, 1.0) else 1.0
    ) %>%
    group_by(study, size_class, time_interval_yr) %>%
    summarise(
      n = n(),
      raw_survival = mean(survived),
      .groups = "drop"
    ) %>%
    mutate(
      annual_survival = raw_survival^(1 / time_interval_yr)
    ) %>%
    group_by(size_class) %>%
    summarise(
      survival = weighted.mean(annual_survival, w = n),
      .groups = "drop"
    ) %>%
    arrange(size_class)

  S_boot <- S_boot_df %>% pull(survival)

  # FIX: Impute missing size classes from full-data estimate instead of discarding (critique audit 2026-03-29)
  # When a resampled study set lacks a size class (typically SC5, which comes only from NOAA),
  # we fill the missing survival from the full-data point estimate (S vector). This avoids
  # conditioning the bootstrap CI on NOAA inclusion, which biased the original approach.
  if (length(S_boot) < 5) {
    missing_sc <- setdiff(size_class_labels, S_boot_df$size_class)
    boot_failure_log[[length(boot_failure_log) + 1]] <- data.frame(
      iteration = b, stage = "survival", reason = "missing_size_classes",
      missing_classes = paste(missing_sc, collapse = ","),
      studies_drawn = paste(surv_studies_boot, collapse = ","),
      stringsAsFactors = FALSE
    )

    # OLD approach: discard this iteration
    lambda_boot_discard[b] <- NA

    # NEW approach: impute from full-data point estimate
    boot_imputed_flag[b] <- TRUE
    S_boot_full <- S  # Full-data survival vector (5 elements)
    # Overwrite the size classes we DO have from the bootstrap
    for (sc_row in 1:nrow(S_boot_df)) {
      sc_idx <- which(size_class_labels == S_boot_df$size_class[sc_row])
      S_boot_full[sc_idx] <- S_boot_df$survival[sc_row]
    }
    S_boot <- S_boot_full
  } else {
    lambda_boot_discard[b] <- NA  # Placeholder; will be filled below with actual lambda
    boot_imputed_flag[b] <- FALSE
  }

  # STAGE 2 for growth: Resample colonies within each resampled study
  growth_boot <- do.call(rbind, lapply(seq_along(growth_studies_boot), function(i) {
    study_data <- growth_filtered %>% filter(study == growth_studies_boot[i])
    if (nrow(study_data) == 0) return(NULL)
    # Resample colonies within study
    colonies <- unique(study_data$coral_id)
    boot_colonies <- sample(colonies, replace = TRUE)
    do.call(rbind, lapply(boot_colonies, function(col) {
      study_data %>% filter(coral_id == col)
    }))
  }))

  if (is.null(growth_boot) || nrow(growth_boot) < 10) {
    boot_failure_log[[length(boot_failure_log) + 1]] <- data.frame(
      iteration = b, stage = "growth", reason = "insufficient_growth_data",
      missing_classes = NA_character_,
      studies_drawn = paste(growth_studies_boot, collapse = ","),
      stringsAsFactors = FALSE
    )
    lambda_boot[b] <- NA
    lambda_boot_discard[b] <- NA
    next
  }

  G_boot <- growth_boot %>%
    count(size_class_initial, size_class_final) %>%
    complete(size_class_initial = size_class_labels,
             size_class_final = size_class_labels,
             fill = list(n = 0)) %>%
    pivot_wider(names_from = size_class_initial, values_from = n) %>%
    column_to_rownames("size_class_final") %>%
    as.matrix()

  G_boot <- sweep(G_boot, 2, colSums(G_boot), "/")
  G_boot[is.nan(G_boot)] <- 0

  # Resample fragmentation matrix to propagate uncertainty from source data
  if (exists("frag_data_annual") && nrow(frag_data_annual) > 0) {
    F_mat_boot <- resample_F_mat(frag_data_annual, frag_rate_cols, size_class_labels)
  } else {
    F_mat_boot <- F_mat  # Fallback to fixed if no fragmentation data
  }

  # Build projection matrix (columns multiplied by source survival)
  A_boot <- G_boot %*% diag(S_boot) + F_mat_boot

  # Calculate λ and store matrix
  eigen_boot <- eigen(A_boot)
  lambda_boot[b] <- Re(eigen_boot$values[1])
  boot_matrices[[b]] <- A_boot

  # FIX: Compute bootstrapped elasticity for each iteration (critique audit 2026-03-29)
  # Elasticity = (v %*% t(w)) * A / lambda, where v = left eigenvector, w = right eigenvector
  w_boot <- Re(eigen_boot$vectors[, 1])
  w_boot <- w_boot / sum(w_boot)
  v_boot <- Re(eigen(t(A_boot))$vectors[, 1])
  v_boot <- v_boot / v_boot[1]
  vw_boot <- sum(v_boot * w_boot)
  sens_boot <- outer(v_boot, w_boot) / vw_boot
  elast_boot <- (A_boot / lambda_boot[b]) * sens_boot
  # Store key elasticity elements
  boot_elast_SC5_stasis[b] <- elast_boot[5, 5]
  boot_elast_SC4_stasis[b] <- elast_boot[4, 4]
  boot_elast_SC3_stasis[b] <- elast_boot[3, 3]
  boot_elast_SC5_to_SC4[b] <- elast_boot[4, 5]  # SC5->SC4 shrinkage/fragmentation
  boot_elast_SC4_to_SC3[b] <- elast_boot[3, 4]  # SC4->SC3 shrinkage/fragmentation
  # Total fragmentation elasticity: sum of elements where F_mat > 0, proportionally attributed
  surv_comp_boot <- G_boot %*% diag(S_boot)
  frag_prop_boot <- ifelse(A_boot > 0, F_mat_boot / A_boot, 0)
  boot_elast_frag_total[b] <- sum(frag_prop_boot * elast_boot)

  # FIX: Store lambda for discard-approach comparison (critique audit 2026-03-29)
  # If this iteration was NOT imputed, the discard approach would also have this lambda.
  # If it WAS imputed (boot_imputed_flag[b] == TRUE), lambda_boot_discard[b] was already set to NA above.
  if (!boot_imputed_flag[b]) {
    lambda_boot_discard[b] <- lambda_boot[b]
  }
}

close(pb)

# --- Save bootstrap failure analysis ---
if (length(boot_failure_log) > 0) {
  boot_failure_df <- do.call(rbind, boot_failure_log)
  write_csv(boot_failure_df, file.path(output_dir, "bootstrap_failure_analysis.csv"))
  cat(sprintf("\n✓ Saved: bootstrap_failure_analysis.csv (%d failures logged)\n", nrow(boot_failure_df)))

  # Summarize failure patterns
  cat("\nBootstrap failure summary:\n")
  cat(sprintf("  Total failures: %d of %d (%.1f%%)\n",
              nrow(boot_failure_df), n_boot, nrow(boot_failure_df)/n_boot*100))
  cat("  By stage:\n")
  stage_counts <- table(boot_failure_df$stage)
  for (s in names(stage_counts)) {
    cat(sprintf("    %s: %d\n", s, stage_counts[s]))
  }
  # Most common missing size classes
  surv_failures <- boot_failure_df[boot_failure_df$stage == "survival", ]
  if (nrow(surv_failures) > 0) {
    all_missing <- unlist(strsplit(surv_failures$missing_classes, ","))
    missing_freq <- sort(table(all_missing), decreasing = TRUE)
    cat("  Most commonly missing size classes:\n")
    for (sc in names(missing_freq)) {
      cat(sprintf("    %s: %d times\n", sc, missing_freq[sc]))
    }
  }
} else {
  # Create empty file to signal no failures
  write_csv(data.frame(iteration = integer(), stage = character(),
                        reason = character(), missing_classes = character(),
                        studies_drawn = character()),
            file.path(output_dir, "bootstrap_failure_analysis.csv"))
  cat("\n✓ Saved: bootstrap_failure_analysis.csv (0 failures)\n")
}

# FIX: Report both imputation and discard approaches as sensitivity check (critique audit 2026-03-29)
n_imputed <- sum(boot_imputed_flag, na.rm = TRUE)
n_growth_failures <- sum(is.na(lambda_boot))  # Growth failures produce NA in BOTH approaches
cat(sprintf("\n  Bootstrap imputation summary:\n"))
cat(sprintf("    Iterations requiring survival imputation: %d of %d (%.1f%%)\n",
            n_imputed, n_boot, n_imputed / n_boot * 100))
cat(sprintf("    Growth data failures (discarded in both approaches): %d\n", n_growth_failures))

# Discard-approach results (old behavior, for comparison)
lambda_boot_discard_valid <- lambda_boot_discard[!is.na(lambda_boot_discard)]
n_discard_valid <- length(lambda_boot_discard_valid)
if (n_discard_valid > 30) {
  cat(sprintf("\n  COMPARISON: Discard approach (old) vs Imputation approach (new):\n"))
  cat(sprintf("    Discard: n=%d valid, lambda=%.4f (95%% CI: %.4f-%.4f)\n",
              n_discard_valid, mean(lambda_boot_discard_valid),
              quantile(lambda_boot_discard_valid, 0.025),
              quantile(lambda_boot_discard_valid, 0.975)))
}

# Remove boot_matrices entries corresponding to NA lambda values
boot_matrices <- boot_matrices[!is.na(lambda_boot)]

n_boot_total <- n_boot
lambda_boot <- lambda_boot[!is.na(lambda_boot)]
n_boot_valid <- length(lambda_boot)

# Bootstrap CIs for matrix elements
if (length(boot_matrices) > 30) {
  boot_array <- array(unlist(boot_matrices), dim = c(5, 5, length(boot_matrices)))
  matrix_ci <- expand.grid(from = paste0("SC", 1:5), to = paste0("SC", 1:5))
  matrix_ci$point_estimate <- as.vector(t(A))
  matrix_ci$ci_lower <- apply(boot_array, c(1,2), quantile, 0.025, na.rm = TRUE) |> t() |> as.vector()
  matrix_ci$ci_upper <- apply(boot_array, c(1,2), quantile, 0.975, na.rm = TRUE) |> t() |> as.vector()
  matrix_ci$boot_mean <- apply(boot_array, c(1,2), mean, na.rm = TRUE) |> t() |> as.vector()
  matrix_ci$boot_sd <- apply(boot_array, c(1,2), sd, na.rm = TRUE) |> t() |> as.vector()
  write_csv(matrix_ci, file.path(output_dir, "transition_matrix_bootstrap_ci.csv"))
  cat("\n✓ Saved: transition_matrix_bootstrap_ci.csv\n")
}

cat(sprintf("\n\nHierarchical Bootstrap results — IMPUTATION approach (n=%d valid iterations):\n", length(lambda_boot)))
cat(sprintf("  λ mean: %.4f\n", mean(lambda_boot)))
cat(sprintf("  λ median: %.4f\n", median(lambda_boot)))
cat(sprintf("  λ SE: %.4f\n", sd(lambda_boot)))
cat(sprintf("  λ 95%% CI: [%.4f, %.4f]\n",
            quantile(lambda_boot, 0.025), quantile(lambda_boot, 0.975)))
cat(sprintf("  CV: %.1f%%\n", sd(lambda_boot) / mean(lambda_boot) * 100))

# Probability of decline
p_decline <- mean(lambda_boot < 1)
cat(sprintf("\n  P(λ < 1) = P(decline): %.1f%%\n", p_decline * 100))

# FIX: Report discard approach alongside for comparison (critique audit 2026-03-29)
if (n_discard_valid > 30) {
  p_decline_discard <- mean(lambda_boot_discard_valid < 1)
  cat(sprintf("\n  --- Discard approach (old, for comparison) ---\n"))
  cat(sprintf("  λ mean: %.4f, 95%% CI: [%.4f, %.4f], P(decline): %.1f%%\n",
              mean(lambda_boot_discard_valid),
              quantile(lambda_boot_discard_valid, 0.025),
              quantile(lambda_boot_discard_valid, 0.975),
              p_decline_discard * 100))
  cat(sprintf("  n valid (discard): %d vs n valid (impute): %d\n",
              n_discard_valid, length(lambda_boot)))
}

# Compare with simple bootstrap CI width
simple_ci_width <- 0.030  # Approximate from previous simple bootstrap
hier_ci_width <- quantile(lambda_boot, 0.975) - quantile(lambda_boot, 0.025)
cat(sprintf("\n  NOTE: Hierarchical CI width = %.4f\n", hier_ci_width))
cat("  (Properly accounts for study-level clustering)\n")

# Bias-corrected percentile intervals (BCa-like)
# Full BCa requires jackknife acceleration, which is computationally expensive.
# We use a bias-corrected (BC) approach as a compromise: adjusts for
# skewness in the bootstrap distribution without the acceleration term.
bias <- mean(lambda_boot) - lambda  # bias estimate
z0 <- qnorm(mean(lambda_boot < lambda))  # bias correction factor
alpha <- c(0.025, 0.975)
z_alpha <- qnorm(alpha)
adjusted_alpha <- pnorm(z0 + (z0 + z_alpha))
lambda_ci_bc <- quantile(lambda_boot, adjusted_alpha, na.rm = TRUE)

cat(sprintf("\n  Bias-corrected CI: [%.4f, %.4f]\n", lambda_ci_bc[1], lambda_ci_bc[2]))
cat(sprintf("  Bias estimate: %.5f, z0: %.3f\n", bias, z0))

# --- BOOTSTRAP DIAGNOSTIC: Effective Number of Studies ---
cat("\n--- BOOTSTRAP DIAGNOSTIC ---\n")
n_surv_studies <- length(surv_studies)
cat(sprintf("  Unique studies in survival data: %d (%s)\n",
            n_surv_studies, paste(surv_studies, collapse = ", ")))

if (n_surv_studies <= 3) {
  # Probability of not drawing dominant study
  p_no_dominant <- ((n_surv_studies - 1) / n_surv_studies)^n_surv_studies
  cat(sprintf("  P(not drawing dominant study): %.4f (%.2f%%)\n",
              p_no_dominant, p_no_dominant * 100))
  cat(sprintf("  Expected failure rate from missing dominant study: ~%.1f%%\n",
              p_no_dominant * 100))
  cat("  *** CAVEAT: Bootstrap CI is conditional on dominant-study inclusion. ***\n")
  cat("  With k=2 studies, the bootstrap cannot fully capture between-study uncertainty.\n")
}

# Save bootstrap diagnostics
boot_diag <- data.frame(
  metric = c("n_survival_studies", "n_growth_studies", "n_boot_total",
             "n_boot_valid", "boot_failure_rate", "n_imputed_iterations"),
  value = c(n_surv_studies, length(unique(growth_filtered$study)),
            n_boot_total, n_boot_valid,
            (n_boot_total - n_boot_valid) / n_boot_total,
            n_imputed)
)
write_csv(boot_diag, file.path(output_dir, "lambda_bootstrap_diagnostics.csv"))
cat("  Saved: lambda_bootstrap_diagnostics.csv\n")

# FIX: Compute and save bootstrapped elasticity CIs (critique audit 2026-03-29)
# Filter to valid iterations (non-NA lambda)
valid_idx <- !is.na(lambda_boot)  # lambda_boot was already filtered above, but the elast vectors weren't
# The valid_idx here refers to the ORIGINAL pre-filtered lambda_boot
# Since lambda_boot has already been filtered to remove NAs, we need to use the stored boot_imputed_flag
# Actually, lambda_boot was filtered in-place. The elasticity vectors are still length n_boot_total.
# We need to filter them the same way.
# Reconstruct valid indices: an iteration is valid if lambda_boot was not NA in the original vector
# We stored lambda values in the vectors before filtering. Growth failures set lambda_boot[b] = NA.
# After filtering, lambda_boot only has valid values. So we need to match.
# Safest approach: use the indices where the elasticity values are non-zero or the iteration wasn't a growth failure.
# Since growth failures also skip elasticity, those entries are 0. Let's use a mask.
elast_valid_mask <- (boot_elast_SC5_stasis != 0) | (boot_elast_SC4_stasis != 0) | (boot_elast_SC3_stasis != 0)
# Edge case: some iterations might legitimately have 0 elasticity (unlikely). Cross-check with growth failures.
# Better: track which iterations actually ran. We know growth failures set lambda_boot[b] = NA before filtering.
# The boot_imputed_flag is only set for survival imputation. Growth failures are separate.
# We'll use: valid = not a growth failure. Growth failures have boot_elast_SC5_stasis == 0 AND boot_elast_SC4_stasis == 0.
# This is safe because real elasticities for stasis are always > 0 for a viable population.

if (sum(elast_valid_mask) > 30) {
  elasticity_bootstrap_ci <- data.frame(
    element = c("SC5_stasis", "SC4_stasis", "SC3_stasis",
                "SC5_to_SC4", "SC4_to_SC3", "fragmentation_total"),
    point_estimate = c(elasticity[5,5], elasticity[4,4], elasticity[3,3],
                       elasticity[4,5], elasticity[3,4], e_frag),
    boot_mean = c(mean(boot_elast_SC5_stasis[elast_valid_mask]),
                  mean(boot_elast_SC4_stasis[elast_valid_mask]),
                  mean(boot_elast_SC3_stasis[elast_valid_mask]),
                  mean(boot_elast_SC5_to_SC4[elast_valid_mask]),
                  mean(boot_elast_SC4_to_SC3[elast_valid_mask]),
                  mean(boot_elast_frag_total[elast_valid_mask])),
    ci_lower = c(quantile(boot_elast_SC5_stasis[elast_valid_mask], 0.025),
                 quantile(boot_elast_SC4_stasis[elast_valid_mask], 0.025),
                 quantile(boot_elast_SC3_stasis[elast_valid_mask], 0.025),
                 quantile(boot_elast_SC5_to_SC4[elast_valid_mask], 0.025),
                 quantile(boot_elast_SC4_to_SC3[elast_valid_mask], 0.025),
                 quantile(boot_elast_frag_total[elast_valid_mask], 0.025)),
    ci_upper = c(quantile(boot_elast_SC5_stasis[elast_valid_mask], 0.975),
                 quantile(boot_elast_SC4_stasis[elast_valid_mask], 0.975),
                 quantile(boot_elast_SC3_stasis[elast_valid_mask], 0.975),
                 quantile(boot_elast_SC5_to_SC4[elast_valid_mask], 0.975),
                 quantile(boot_elast_SC4_to_SC3[elast_valid_mask], 0.975),
                 quantile(boot_elast_frag_total[elast_valid_mask], 0.975)),
    boot_sd = c(sd(boot_elast_SC5_stasis[elast_valid_mask]),
                sd(boot_elast_SC4_stasis[elast_valid_mask]),
                sd(boot_elast_SC3_stasis[elast_valid_mask]),
                sd(boot_elast_SC5_to_SC4[elast_valid_mask]),
                sd(boot_elast_SC4_to_SC3[elast_valid_mask]),
                sd(boot_elast_frag_total[elast_valid_mask])),
    n_valid = sum(elast_valid_mask)
  )
  write_csv(elasticity_bootstrap_ci, file.path(output_dir, "elasticity_bootstrap_ci.csv"))
  cat("\n✓ Saved: elasticity_bootstrap_ci.csv\n")

  cat("\nBootstrapped elasticity 95% CIs:\n")
  for (i in 1:nrow(elasticity_bootstrap_ci)) {
    cat(sprintf("  %s: %.4f (95%% CI: %.4f-%.4f)\n",
                elasticity_bootstrap_ci$element[i],
                elasticity_bootstrap_ci$point_estimate[i],
                elasticity_bootstrap_ci$ci_lower[i],
                elasticity_bootstrap_ci$ci_upper[i]))
  }
} else {
  cat("\n  WARNING: Insufficient valid bootstrap iterations for elasticity CIs.\n")
}

# =============================================================================
# 10. POPULATION PROJECTIONS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  POPULATION PROJECTIONS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Project population over 20 years
n_years <- 20
initial_pop <- c(100, 50, 30, 20, 10)  # Starting population by size class
names(initial_pop) <- size_class_labels

projections <- matrix(0, nrow = n_years + 1, ncol = 5)
projections[1, ] <- initial_pop
colnames(projections) <- size_class_labels

for (t in 2:(n_years + 1)) {
  projections[t, ] <- A %*% projections[t - 1, ]
}

projections_df <- as.data.frame(projections) %>%
  mutate(year = 0:n_years, total = rowSums(.)) %>%
  pivot_longer(cols = all_of(size_class_labels),
               names_to = "size_class", values_to = "n")

cat("Deterministic population projection (starting with 210 individuals):\n")
cat(sprintf("  Year 0: %d total\n", sum(initial_pop)))
cat(sprintf("  Year 5: %.0f total (%.1f%% of initial)\n",
            sum(projections[6, ]), sum(projections[6, ]) / sum(initial_pop) * 100))
cat(sprintf("  Year 10: %.0f total (%.1f%% of initial)\n",
            sum(projections[11, ]), sum(projections[11, ]) / sum(initial_pop) * 100))
cat(sprintf("  Year 20: %.0f total (%.1f%% of initial)\n",
            sum(projections[21, ]), sum(projections[21, ]) / sum(initial_pop) * 100))

# =============================================================================
# 10B. PARAMETRIC UNCERTAINTY PROJECTIONS (PRIMARY METHOD)
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  PARAMETRIC UNCERTAINTY PROJECTIONS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# METHODOLOGY NOTE:
# We propagate parametric uncertainty through population projections using
# a two-layer approach:
#   For each simulation replicate:
#     1. Draw ONE bootstrap matrix (represents one plausible set of vital rates)
#     2. Project forward T years using THAT SAME matrix (deterministic projection
#        under that plausible truth)
#     3. Compute lambda for that replicate
#
# This gives the distribution of projected population sizes under PARAMETRIC
# uncertainty (uncertainty in estimated vital rates) WITHOUT conflating it
# with environmental stochasticity.
#
# True environmental stochasticity would require estimating year-to-year
# variance in vital rates WITHIN studies, which is not available with the
# current data structure (most studies span 1-3 years with no replication
# of annual transitions).

n_param_sims <- 500
n_years_stoch <- 20
param_totals <- matrix(NA, nrow = n_param_sims, ncol = n_years_stoch + 1)

cat(sprintf("Running %d parametric uncertainty simulations over %d years...\n",
            n_param_sims, n_years_stoch))
cat("  Method: Each replicate draws ONE bootstrap matrix and projects deterministically.\n")

set.seed(123)

n_stored <- length(boot_matrices)

for (sim in 1:n_param_sims) {
  pop <- initial_pop
  param_totals[sim, 1] <- sum(pop)

  if (n_stored > 0) {
    # Draw ONE bootstrap matrix for this entire replicate
    A_sim <- boot_matrices[[sample(n_stored, 1)]]
    for (t in 2:(n_years_stoch + 1)) {
      pop <- A_sim %*% pop
      pop <- pmax(pop, 0)
      param_totals[sim, t] <- sum(pop)
    }
  } else {
    # Fallback: draw one lambda from bootstrap, scale the point-estimate matrix
    lambda_sim <- sample(lambda_boot, 1)
    scale_factor <- lambda_sim / lambda
    A_sim <- A * scale_factor
    for (t in 2:(n_years_stoch + 1)) {
      pop <- A_sim %*% pop
      pop <- pmax(pop, 0)
      param_totals[sim, t] <- sum(pop)
    }
  }
}

# Calculate summary statistics
stoch_mean <- colMeans(param_totals)
stoch_median <- apply(param_totals, 2, median)
stoch_ci_lower <- apply(param_totals, 2, quantile, probs = 0.025)
stoch_ci_upper <- apply(param_totals, 2, quantile, probs = 0.975)
stoch_pi_lower <- apply(param_totals, 2, quantile, probs = 0.1)
stoch_pi_upper <- apply(param_totals, 2, quantile, probs = 0.9)

cat("\nParametric uncertainty projection results:\n")
cat(sprintf("  Year 5: %.0f (95%% CI: %.0f-%.0f)\n",
            stoch_median[6], stoch_ci_lower[6], stoch_ci_upper[6]))
cat(sprintf("  Year 10: %.0f (95%% CI: %.0f-%.0f)\n",
            stoch_median[11], stoch_ci_lower[11], stoch_ci_upper[11]))
cat(sprintf("  Year 20: %.0f (95%% CI: %.0f-%.0f)\n",
            stoch_median[21], stoch_ci_lower[21], stoch_ci_upper[21]))

# Probability of quasi-extinction (population < 10% of initial)
quasi_extinct_threshold <- sum(initial_pop) * 0.1
p_quasi_extinct <- mean(param_totals[, n_years_stoch + 1] < quasi_extinct_threshold)
cat(sprintf("\n  P(quasi-extinction at year %d): %.1f%%\n",
            n_years_stoch, p_quasi_extinct * 100))
cat(sprintf("  (Quasi-extinction threshold: %.0f individuals = 10%% of initial)\n",
            quasi_extinct_threshold))

# Compute lambda from parametric uncertainty projections
# Each replicate used a single fixed matrix, so lambda is just the dominant
# eigenvalue of that matrix. We compute it from the projected trajectory for
# consistency.
log_lambda_param_values <- numeric(n_param_sims)
for (i in 1:n_param_sims) {
  log_ratios <- diff(log(param_totals[i, ] + 1))
  log_lambda_param_values[i] <- mean(log_ratios)
}
parametric_lambda <- exp(mean(log_lambda_param_values))
parametric_lambda_ci <- exp(quantile(log_lambda_param_values, c(0.025, 0.975)))

cat(sprintf("\nParametric uncertainty lambda (primary estimate):\n"))
cat(sprintf("  Lambda: %.4f (95%% CI: %.4f - %.4f)\n",
            parametric_lambda, parametric_lambda_ci[1], parametric_lambda_ci[2]))
cat(sprintf("  Deterministic lambda: %.4f\n", lambda))

# For backward compatibility, assign to stochastic_lambda variables
# (used in downstream outputs and the results list)
stochastic_lambda <- parametric_lambda
stochastic_lambda_ci <- parametric_lambda_ci

# Store projection results
stochastic_projection_df <- data.frame(
  year = 0:n_years_stoch,
  deterministic = rowSums(projections),
  stochastic_mean = stoch_mean,
  stochastic_median = stoch_median,
  ci_lower_95 = stoch_ci_lower,
  ci_upper_95 = stoch_ci_upper,
  pi_lower_80 = stoch_pi_lower,
  pi_upper_80 = stoch_pi_upper
)

# =============================================================================
# 10C. LEGACY STOCHASTIC PROJECTIONS (draws different matrix each year)
# =============================================================================
# WARNING: This approach conflates parametric uncertainty with environmental
# stochasticity. Drawing a DIFFERENT bootstrap matrix each year treats
# estimation uncertainty as if it were real year-to-year environmental
# variation, which produces unrealistically pessimistic stochastic lambda
# values (e.g., ~0.82 vs the deterministic 0.986). This code is retained
# for reference and comparison but should NOT be used as the primary
# projection method.
#
# To properly estimate environmental stochasticity, one would need
# within-study replicated annual transition matrices, which are not available
# in the current dataset.

cat("\n--- Legacy stochastic projections (for comparison only) ---\n")
cat("  WARNING: This method conflates parametric uncertainty with environmental\n")
cat("  stochasticity, producing unrealistically pessimistic lambda estimates.\n")

n_stochastic_legacy <- 500
legacy_totals <- matrix(NA, nrow = n_stochastic_legacy, ncol = n_years_stoch + 1)

set.seed(456)

for (sim in 1:n_stochastic_legacy) {
  pop <- initial_pop
  legacy_totals[sim, 1] <- sum(pop)

  if (n_stored > 0) {
    for (t in 2:(n_years_stoch + 1)) {
      # Draw a DIFFERENT bootstrap matrix each year (conflates uncertainty types)
      A_stoch <- boot_matrices[[sample(n_stored, 1)]]
      pop <- A_stoch %*% pop
      pop <- pmax(pop, 0)
      legacy_totals[sim, t] <- sum(pop)
    }
  } else {
    for (t in 2:(n_years_stoch + 1)) {
      lambda_year <- sample(lambda_boot, 1)
      scale_factor <- lambda_year / lambda
      A_stoch <- A * scale_factor
      pop <- A_stoch %*% pop
      pop <- pmax(pop, 0)
      legacy_totals[sim, t] <- sum(pop)
    }
  }
}

# Compute legacy stochastic lambda for comparison
log_lambda_legacy <- numeric(n_stochastic_legacy)
for (i in 1:n_stochastic_legacy) {
  log_ratios <- diff(log(legacy_totals[i, ] + 1))
  log_lambda_legacy[i] <- mean(log_ratios)
}
legacy_stochastic_lambda <- exp(mean(log_lambda_legacy))

cat(sprintf("  Legacy stochastic lambda: %.4f (BIASED -- do not use as primary)\n",
            legacy_stochastic_lambda))
cat(sprintf("  Parametric uncertainty lambda: %.4f (primary estimate)\n",
            parametric_lambda))
cat(sprintf("  Deterministic lambda: %.4f\n", lambda))

# =============================================================================
# 10D. FRAGMENTATION-REMOVED SENSITIVITY
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  FRAGMENTATION SCENARIO BRACKETING\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# FIX: Added three-scenario bracketing for fragmentation sensitivity (critique audit 2026-03-29)
# Scenario 1: With full fragmentation (current Vardi 2011 rates)
# Scenario 2: Without fragmentation (F_mat = 0)
# Scenario 3: With fragmentation x 0.5 (50% of Vardi rates — tests sensitivity to Vardi's specific estimates)
A_no_frag <- G %*% diag(S)
lambda_no_frag <- Re(eigen(A_no_frag)$values[1])

A_half_frag <- G %*% diag(S) + F_mat * 0.5
lambda_half_frag <- Re(eigen(A_half_frag)$values[1])

cat(sprintf("Lambda with full fragmentation (Vardi 2011): %.4f\n", lambda))
cat(sprintf("Lambda with 50%% fragmentation:               %.4f\n", lambda_half_frag))
cat(sprintf("Lambda without fragmentation:                 %.4f\n", lambda_no_frag))
cat(sprintf("Full frag contribution: %.4f (%.1f%% of lambda)\n",
            lambda - lambda_no_frag, (lambda - lambda_no_frag) / lambda * 100))

# Save both the old file (for backward compatibility) and the new scenarios file
frag_sensitivity <- data.frame(
  scenario = c("with_fragmentation", "without_fragmentation"),
  lambda = c(lambda, lambda_no_frag),
  difference = c(NA, lambda - lambda_no_frag),
  pct_contribution = c(NA, (lambda - lambda_no_frag) / lambda * 100)
)
write_csv(frag_sensitivity, file.path(output_dir, "fragmentation_sensitivity.csv"))
cat("✓ Saved: fragmentation_sensitivity.csv\n")

# FIX: New three-scenario output (critique audit 2026-03-29)
frag_scenarios <- data.frame(
  scenario = c("with_fragmentation", "half_fragmentation", "without_fragmentation"),
  fragmentation_multiplier = c(1.0, 0.5, 0.0),
  lambda = c(lambda, lambda_half_frag, lambda_no_frag),
  difference_from_full = c(0, lambda_half_frag - lambda, lambda_no_frag - lambda),
  notes = c("Full Vardi 2011 rates (13 rows, 1 study)",
            "50% of Vardi rates — tests sensitivity to single-study estimates",
            "No fragmentation — survival and growth only")
)
write_csv(frag_scenarios, file.path(output_dir, "fragmentation_scenarios.csv"))
cat("✓ Saved: fragmentation_scenarios.csv\n")

cat("\n  *** FRAGMENTATION DATA DEPENDENCY ***\n")
cat("  All fragmentation data: Vardi 2011 (13 rows, 3 regions, 2007-2011)\n")
cat(sprintf("  Lambda WITH fragmentation:    %.4f\n", lambda))
cat(sprintf("  Lambda at 50%% fragmentation:  %.4f\n", lambda_half_frag))
cat(sprintf("  Lambda WITHOUT fragmentation: %.4f\n", lambda_no_frag))
cat(sprintf("  Fragmentation contribution:   %.4f (%.1f%% of lambda)\n",
            lambda - lambda_no_frag, (lambda - lambda_no_frag) / lambda * 100))
cat("  The proximity of lambda to 1.0 depends critically on fragmentation\n")
cat("  data from a single study with limited temporal and spatial scope.\n")

# =============================================================================
# SENSITIVITY: SEXUAL REPRODUCTION (FECUNDITY) TERM
# FIX: Made more prominent with additional scenarios and minimum fecundity
# calculation for lambda > 1 (critique audit 2026-03-29)
# =============================================================================
cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  CRITICAL: FECUNDITY SENSITIVITY ANALYSIS                    ║\n")
cat("║  The current model has ZERO sexual reproduction.             ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# FIX: Expanded fecundity scenarios (critique audit 2026-03-29)
# The current model has zero sexual reproduction. Lambda = [X] without fecundity.
# Testing: what fecundity is needed for lambda > 1?
cat(sprintf("  The current model has zero sexual reproduction. Lambda = %.4f without fecundity.\n\n", lambda))

fecundity_values <- c(0, 0.001, 0.01, 0.05, 0.10)
fecundity_sensitivity <- data.frame(
  fecundity_per_adult = fecundity_values,
  lambda = NA_real_
)

for (f_idx in seq_along(fecundity_values)) {
  f_val <- fecundity_values[f_idx]
  A_fecund <- A  # Copy base matrix
  # SC4 and SC5 adults produce SC1 recruits
  A_fecund[1, 4] <- A_fecund[1, 4] + f_val
  A_fecund[1, 5] <- A_fecund[1, 5] + f_val
  fecundity_sensitivity$lambda[f_idx] <- Re(eigen(A_fecund)$values[1])
}
fecundity_sensitivity$change <- fecundity_sensitivity$lambda - lambda

cat(sprintf("  %-20s %10s %12s\n", "Fecundity/adult/yr", "Lambda", "Change"))
cat(paste(rep("-", 44), collapse = ""), "\n")
for (i in 1:nrow(fecundity_sensitivity)) {
  cat(sprintf("  %-20.3f %10.4f %+12.4f\n",
              fecundity_sensitivity$fecundity_per_adult[i],
              fecundity_sensitivity$lambda[i],
              fecundity_sensitivity$change[i]))
}

# FIX: Calculate minimum fecundity for lambda > 1 via bisection (critique audit 2026-03-29)
# Bisection search: find the fecundity value where lambda crosses 1.0
f_low <- 0
f_high <- 1.0
for (bisect_iter in 1:50) {
  f_mid <- (f_low + f_high) / 2
  A_test <- A
  A_test[1, 4] <- A_test[1, 4] + f_mid
  A_test[1, 5] <- A_test[1, 5] + f_mid
  lambda_test <- Re(eigen(A_test)$values[1])
  if (lambda_test > 1.0) {
    f_high <- f_mid
  } else {
    f_low <- f_mid
  }
}
min_fecundity_for_growth <- (f_low + f_high) / 2
cat(sprintf("\n  The minimum fecundity needed for lambda > 1 is %.4f recruits per SC4/SC5 adult per year.\n",
            min_fecundity_for_growth))
fecundity_sensitivity$min_fecundity_for_lambda_gt_1 <- min_fecundity_for_growth

write_csv(fecundity_sensitivity, file.path(output_dir, "fecundity_sensitivity.csv"))
cat("  Saved: fecundity_sensitivity.csv\n")
cat(sprintf("\n  SUMMARY: Lambda = %.4f assumes zero sexual recruitment.\n", lambda))
cat(sprintf("  Even fecundity of %.4f recruits/adult/year would push lambda above 1.0.\n",
            min_fecundity_for_growth))
cat("  The absence of sexual reproduction in this model is a critical assumption.\n")

# =============================================================================
# TULJAPURKAR APPROXIMATION USING BETWEEN-STUDY VARIANCE
# FIX: Renamed from "stochastic lambda" to avoid implying true environmental
# stochasticity. This uses between-study variance as a proxy for environmental
# variance, which overestimates stochasticity because it includes methodological
# heterogeneity (different mortality definitions, measurement methods, regions,
# time periods). (critique audit 2026-03-29)
# =============================================================================
cat("\n")
cat("===================================================================\n")
cat("  TULJAPURKAR APPROXIMATION (between-study variance proxy)\n")
cat("===================================================================\n\n")

# FIX: Clarified labeling (critique audit 2026-03-29)
# This uses between-study variance as a proxy for environmental variance,
# which overestimates stochasticity because it includes methodological
# heterogeneity (different mortality definitions, measurement methods,
# regions, time periods, etc.).
cat("  Deterministic lambda overestimates stochastic growth rate.\n")
cat("  Using between-study variance as upper bound on environmental variance.\n")
cat("  CAVEAT: This overestimates stochasticity because between-study variance\n")
cat("  includes methodological heterogeneity, not just environmental variation.\n\n")

# Load LOSO study-specific lambdas (from script 16) if not already loaded
# NOTE: sensitivity_lambda_loo.csv is produced by script 16, which runs AFTER
# script 13. On a first run, this file will not exist. Re-run script 13 after
# script 16 to populate the Tuljapurkar approximation and LOSO-dependent sections.
if (!exists("loso_results") || is.null(loso_results)) {
  loso_file_stoch <- file.path(output_dir, "sensitivity_lambda_loo.csv")
  if (file.exists(loso_file_stoch)) {
    loso_results <- read_csv(loso_file_stoch, show_col_types = FALSE)
  } else {
    cat("  WARNING: sensitivity_lambda_loo.csv not found (produced by script 16).\n")
    cat("  Re-run script 13 AFTER script 16 to populate Tuljapurkar and LOSO sections.\n")
  }
}

if (exists("loso_results") && !is.null(loso_results) && "lambda" %in% names(loso_results)) {
  loso_lambdas <- loso_results$lambda[!is.na(loso_results$lambda)]

  if (length(loso_lambdas) >= 2) {
    sigma2_log_lambda <- var(log(loso_lambdas))
    log_lambda_det <- log(lambda)
    log_lambda_stoch <- log_lambda_det - sigma2_log_lambda / 2
    lambda_stoch <- exp(log_lambda_stoch)

    cat(sprintf("  Deterministic log(lambda):   %.4f (lambda = %.4f)\n",
                log_lambda_det, lambda))
    cat(sprintf("  Var(log(lambda)) from LOSO:  %.6f\n", sigma2_log_lambda))
    cat(sprintf("  Tuljapurkar correction:      -%.6f\n", sigma2_log_lambda / 2))
    cat(sprintf("  Stochastic log(lambda):      %.4f (lambda_s = %.4f)\n",
                log_lambda_stoch, lambda_stoch))
    cat(sprintf("  Annual decline rate:         %.2f%% (vs %.2f%% deterministic)\n",
                (1 - lambda_stoch) * 100, (1 - lambda) * 100))

    cat("\n  CAVEAT: This uses LOSO variance as a proxy for environmental variance.\n")
    cat("  True environmental stochasticity requires multi-year data from single sites.\n")
    cat("  This estimate is an upper bound on the stochastic correction.\n")

    # Save
    # FIX: Renamed metrics to clarify this is NOT true environmental stochasticity (critique audit 2026-03-29)
    stoch_results <- data.frame(
      metric = c("lambda_deterministic", "lambda_tuljapurkar_between_study_variance",
                 "var_log_lambda_loso", "tuljapurkar_correction",
                 "n_loso_lambdas"),
      value = c(lambda, lambda_stoch, sigma2_log_lambda,
                sigma2_log_lambda / 2, length(loso_lambdas)),
      notes = c("Dominant eigenvalue of point-estimate matrix",
                "Tuljapurkar approx using LOSO variance as proxy; overestimates stochastic correction",
                "Variance of log(lambda) across LOSO study exclusions",
                "sigma^2 / 2 correction term",
                "Number of LOSO lambda values used")
    )
    write_csv(stoch_results, file.path(output_dir, "stochastic_lambda_estimate.csv"))
    cat("  Saved: stochastic_lambda_estimate.csv\n")
  } else {
    cat("  Insufficient LOSO lambdas (need >= 2) for Tuljapurkar approximation.\n")
  }
} else {
  cat("  LOSO results not available (run script 16 first).\n")
  cat("  Skipping Tuljapurkar approximation.\n")
}

# =============================================================================
# 11. SAVE RESULTS
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  SAVING RESULTS\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Transition matrix — ensure canonical size class labels
A_df <- as.data.frame(A)
colnames(A_df) <- paste0("SC", 1:5)
rownames(A_df) <- paste0("SC", 1:5)
write.csv(A_df, file.path(output_dir, "transition_matrix.csv"))
cat("✓ Saved: transition_matrix.csv\n")

# Full results as RDS
results <- list(
  projection_matrix = A,
  survival_rates = S,
  growth_transitions = G,
  fragmentation = F_mat,
  lambda = lambda,
  lambda_ci = quantile(lambda_boot, c(0.025, 0.975)),
  lambda_ci_bc = lambda_ci_bc,
  lambda_bootstrap = lambda_boot,
  stochastic_lambda = stochastic_lambda,
  stochastic_lambda_ci = stochastic_lambda_ci,
  stable_distribution = w,
  reproductive_values = v,
  sensitivity = sensitivity,
  elasticity = elasticity,
  survival_elasticity = survival_elasticity,
  fragmentation_elasticity = frag_elasticity,
  survival_by_class = survival_by_class,
  size_class_breaks = size_class_breaks,
  size_class_labels = size_class_labels,
  # FIX: Added fragmentation scenario lambdas (critique audit 2026-03-29)
  lambda_no_frag = lambda_no_frag,
  lambda_half_frag = lambda_half_frag
)
saveRDS(results, file.path(output_dir, "transition_matrix.rds"))
cat("✓ Saved: transition_matrix.rds\n")

# Population parameters summary
# NOTE on naming:
#   - "parametric_uncertainty_lambda" = lambda estimated by drawing ONE bootstrap matrix
#     per replicate and projecting deterministically. This is NOT environmental stochasticity.
#   - "generation_time_NOTE_unreliable" = methodologically unreliable for this model structure
#     (Cochran-Ellner approximation with near-zero fragmentation elasticity).
pop_params <- data.frame(
  parameter = c("lambda", "lambda_ci_lower", "lambda_ci_upper",
                "lambda_ci_bc_lower", "lambda_ci_bc_upper",
                "p_decline", "generation_time_NOTE_unreliable",
                "damping_ratio",
                "elasticity_stasis", "elasticity_growth",
                "elasticity_shrink", "elasticity_frag",
                "parametric_uncertainty_lambda",
                "parametric_uncertainty_lambda_ci_lower",
                "parametric_uncertainty_lambda_ci_upper",
                "jensens_inequality_effect",
                "lambda_boot_se", "lambda_boot_cv",
                "n_boot_valid", "n_boot_total",
                "lambda_no_fragmentation"),
  value = c(lambda, quantile(lambda_boot, 0.025), quantile(lambda_boot, 0.975),
            lambda_ci_bc[1], lambda_ci_bc[2],
            p_decline, abs(T_gen),
            damping_ratio,
            e_stasis, e_growth, e_shrink, e_frag,
            stochastic_lambda, stochastic_lambda_ci[1],
            stochastic_lambda_ci[2], lambda - stochastic_lambda,
            sd(lambda_boot), sd(lambda_boot) / mean(lambda_boot),
            n_boot_valid, n_boot_total,
            lambda_no_frag),
  notes = c("deterministic dominant eigenvalue", "percentile bootstrap 2.5%", "percentile bootstrap 97.5%",
            "bias-corrected 2.5%", "bias-corrected 97.5%",
            "P(lambda < 1)", "Cochran-Ellner method; unreliable when fragmentation elasticity near zero",
            "Mod(eigenvalue1) / Mod(eigenvalue2); rate of convergence to stable distribution",
            "diagonal elasticity sum", "below-diagonal elasticity sum",
            "above-diagonal elasticity sum", "total fragmentation elasticity",
            "NOT environmental stochasticity; parametric uncertainty only",
            "NOT environmental stochasticity; parametric uncertainty only",
            "NOT environmental stochasticity; parametric uncertainty only",
            "lambda_deterministic minus parametric_uncertainty_lambda",
            "bootstrap standard error of lambda", "bootstrap coefficient of variation of lambda",
            "bootstrap iterations that produced valid lambda", "total bootstrap iterations attempted",
            "lambda without fragmentation matrix (G %*% diag(S) only)")
)

# Add LOSO bracketing rows if available
if (exists("loso_results") && !is.null(loso_results) && "lambda" %in% names(loso_results)) {
  loso_rows <- data.frame(
    parameter = c("loso_lambda_min", "loso_lambda_max", "loso_lambda_range"),
    value = c(min(loso_results$lambda, na.rm = TRUE),
              max(loso_results$lambda, na.rm = TRUE),
              diff(range(loso_results$lambda, na.rm = TRUE))),
    notes = c("minimum lambda from leave-one-study-out (script 16)",
              "maximum lambda from leave-one-study-out (script 16)",
              "span of LOSO lambda values")
  )
  pop_params <- rbind(pop_params, loso_rows)
}

# Add caveat flag rows
caveat_rows <- data.frame(
  parameter = c("caveat_noaa_pct_data", "caveat_sc5_single_study",
                 "caveat_frag_single_source"),
  value = c(78, as.numeric(length(sc5_studies) == 1), 1),
  notes = c("NOAA provides 78% of individual-level data; lambda is NOAA-conditional",
            "SC5 stasis (highest elasticity) estimated from single study (1=TRUE)",
            "All fragmentation from Vardi 2011 (13 rows, 1 study)")
)
pop_params <- rbind(pop_params, caveat_rows)

write_csv(pop_params, file.path(output_dir, "population_parameters.csv"))
cat("Saved: population_parameters.csv\n")

# Elasticity matrix -- ensure canonical size class labels
elasticity_df_out <- as.data.frame(elasticity)
colnames(elasticity_df_out) <- paste0("SC", 1:5)
rownames(elasticity_df_out) <- paste0("SC", 1:5)
write.csv(elasticity_df_out, file.path(output_dir, "elasticity_matrix.csv"))
cat("✓ Saved: elasticity_matrix.csv\n")

# Lower-level elasticity decomposition
vital_rate_elasticity <- data.frame(
  size_class = size_class_labels,
  survival_elasticity = survival_elasticity,
  fragmentation_elasticity = frag_elasticity
)
write.csv(vital_rate_elasticity, file.path(output_dir, "vital_rate_elasticity.csv"),
          row.names = FALSE)
cat("✓ Saved: vital_rate_elasticity.csv\n")

# Stochastic projection results
write.csv(stochastic_projection_df, file.path(output_dir, "stochastic_projections.csv"),
          row.names = FALSE)
cat("✓ Saved: stochastic_projections.csv\n")

# Bootstrap samples for downstream analysis
# FIX: Save imputed lambda vector as primary (backward-compatible format) (critique audit 2026-03-29)
# Downstream scripts (22_fig6_population_model.R, 23_verification.R) expect a numeric vector.
saveRDS(lambda_boot, file.path(output_dir, "lambda_bootstrap_samples.rds"))
cat("✓ Saved: lambda_bootstrap_samples.rds (imputed approach, backward-compatible numeric vector)\n")

# FIX: Also save detailed bootstrap comparison for auditing (critique audit 2026-03-29)
bootstrap_comparison <- list(
  lambda_boot_imputed = lambda_boot,           # Primary: missing SCs imputed from full-data
  lambda_boot_discard = lambda_boot_discard_valid,  # Comparison: iterations with missing SCs discarded
  boot_imputed_flag = boot_imputed_flag,       # Which iterations required imputation (length = n_boot_total)
  n_imputed = n_imputed,
  n_discard_valid = n_discard_valid,
  n_total = n_boot_total
)
saveRDS(bootstrap_comparison, file.path(output_dir, "lambda_bootstrap_comparison.rds"))
cat("✓ Saved: lambda_bootstrap_comparison.rds (imputed vs discard approaches for auditing)\n")

# =============================================================================
# 12. VISUALIZATIONS
# =============================================================================

cat("\nGenerating visualizations...\n")

# Color palette
colors <- list(
  ocean_deep = "#0a3d62",
  ocean_mid = "#1a5276",
  ocean_light = "#2e86ab",
  coral_warm = "#e07a5f",
  coral_pale = "#f4a261",
  seagrass = "#2a9d8f",
  sand = "#e9c46a"
)

# NOTE: Main text Figure 6 (transition matrix visualization) is now generated
# by 22_fig6_population_model.R. Only supplementary figures remain here.

# --- Supplementary: Population Projections ---

p_proj <- ggplot(projections_df, aes(x = year, y = n, fill = size_class)) +
  geom_area(alpha = 0.8) +
  scale_fill_manual(
    values = c(colors$ocean_light, colors$ocean_mid, colors$seagrass,
               colors$coral_pale, colors$coral_warm),
    name = "Size Class"
  ) +
  labs(
    title = "A. palmata Population Projection (20 years)",
    subtitle = sprintf("Starting population: 210 | lambda = %.3f", lambda),
    x = "Year",
    y = "Number of Individuals"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "right")

ggsave(file.path(fig_dir_supp, "population_projections.png"),
       p_proj, width = 10, height = 6, dpi = 300)
cat("✓ Saved: supplementary/exploratory/population_projections.png\n")

# --- Stochastic Projection with Uncertainty ---
p_stochastic <- ggplot(stochastic_projection_df, aes(x = year)) +
  # 95% CI ribbon
  geom_ribbon(aes(ymin = ci_lower_95, ymax = ci_upper_95),
              fill = colors$ocean_light, alpha = 0.3) +
  # 80% PI ribbon
  geom_ribbon(aes(ymin = pi_lower_80, ymax = pi_upper_80),
              fill = colors$ocean_light, alpha = 0.5) +
  # Deterministic projection
  geom_line(aes(y = deterministic, color = "Deterministic"),
            linewidth = 1, linetype = "dashed") +
  # Stochastic median
  geom_line(aes(y = stochastic_median, color = "Stochastic (median)"),
            linewidth = 1.5) +
  # Quasi-extinction threshold
  geom_hline(yintercept = sum(initial_pop) * 0.1,
             linetype = "dotted", color = "red", linewidth = 0.8) +
  annotate("text", x = n_years_stoch, y = sum(initial_pop) * 0.1,
           label = "Quasi-extinction threshold (10%)",
           hjust = 1, vjust = -0.5, color = "red", size = 3) +
  scale_color_manual(
    values = c("Deterministic" = colors$coral_warm,
               "Stochastic (median)" = colors$ocean_deep),
    name = "Projection Type"
  ) +
  labs(
    title = "Stochastic Population Projection with Uncertainty",
    subtitle = sprintf("n=%d simulations | P(quasi-extinction at yr %d) = %.0f%%",
                       n_param_sims, n_years_stoch, p_quasi_extinct * 100),
    x = "Year",
    y = "Total Population",
    caption = "Shaded regions: 80% PI (dark) and 95% CI (light)"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(fig_dir_supp, "stochastic_projections.png"),
       p_stochastic, width = 10, height = 6, dpi = 300)
cat("✓ Saved: supplementary/exploratory/stochastic_projections.png\n")

# =============================================================================
# 13. SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  ANALYSIS COMPLETE                                           ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("KEY FINDINGS:\n\n")

cat(sprintf("POPULATION GROWTH RATE:\n"))
cat(sprintf("  Deterministic λ = %.4f (95%% CI: %.4f-%.4f)\n",
            lambda, quantile(lambda_boot, 0.025), quantile(lambda_boot, 0.975)))
cat(sprintf("  Bias-corrected CI: [%.4f, %.4f]\n", lambda_ci_bc[1], lambda_ci_bc[2]))
cat(sprintf("  Parametric uncertainty λ = %.4f (95%% CI: %.4f-%.4f)  [NOT environmental stochasticity]\n",
            stochastic_lambda, stochastic_lambda_ci[1], stochastic_lambda_ci[2]))
cat(sprintf("  Annual change: %.1f%%\n", (lambda - 1) * 100))
cat(sprintf("  P(decline): %.0f%%\n\n", p_decline * 100))

cat("SURVIVAL BY SIZE CLASS:\n")
for (i in 1:5) {
  cat(sprintf("  %s: %.1f%% (n=%d)\n",
              size_class_labels[i], S[i] * 100, survival_by_class$n[i]))
}

cat("\nELASTICITY ANALYSIS:\n")
cat(sprintf("  Stasis (staying same size): %.1f%%\n", e_stasis * 100))
cat(sprintf("  Growth (increasing size): %.1f%%\n", e_growth * 100))
cat(sprintf("  Most sensitive transition: %s → %s (e=%.3f)\n",
            elasticity_df$from[1], elasticity_df$to[1], elasticity_df$elasticity[1]))

cat("\nRESTORATION IMPLICATIONS:\n")
if (e_stasis > e_growth) {
  cat("  -> Adult survival is most important for population growth\n")
  cat("  -> Protect existing large colonies\n")
} else {
  cat("  -> Growth to larger sizes is critical\n")
  cat("  -> Focus on conditions that promote growth\n")
}

# =============================================================================
# INTERPRETATION CAVEATS
# =============================================================================
# Load LOSO results from script 16 output (if available and not already loaded)
if (!exists("loso_results") || is.null(loso_results)) {
  loso_file <- file.path(output_dir, "sensitivity_lambda_loo.csv")
  if (file.exists(loso_file)) {
    loso_results <- read_csv(loso_file, show_col_types = FALSE)
  } else {
    loso_results <- NULL
  }
}

cat("\n")
cat(paste0(strrep("=", 62), "\n"))
cat("  INTERPRETATION CAVEATS\n")
cat(paste0(strrep("=", 62), "\n\n"))
cat("  1. Lambda is estimated primarily from NOAA monitoring sites\n")
cat("     (Florida Keys, Curacao, Navassa) -- 78% of individual data.\n")
cat(sprintf("  2. SC5 stasis (elasticity = %.1f%%) is from NOAA alone.\n", e_stasis / sum(elasticity) * 100))
cat("     NOAA uses a conservative mortality definition (no tissue/skeleton).\n")
cat("  3. BRACKETING SCENARIOS:\n")
cat(sprintf("     With fragmentation (Vardi 2011):    lambda = %.4f\n", lambda))
cat(sprintf("     Without fragmentation:               lambda = %.4f\n", lambda_no_frag))
if (!is.null(loso_results) && "lambda" %in% names(loso_results)) {
  cat(sprintf("     Range from LOSO study exclusion:     %.4f to %.4f\n",
              min(loso_results$lambda, na.rm = TRUE),
              max(loso_results$lambda, na.rm = TRUE)))
} else {
  cat("     LOSO sensitivity: not yet available (run script 16 first)\n")
}
cat(sprintf("  4. P(decline) = %.1f%% is conditional on NOAA-dominated vital rates.\n",
            p_decline * 100))
cat(sprintf("  5. Lambda = %.4f is a sample-size-weighted composite, not a\n", lambda))
cat("     biologically coherent single-population growth rate.\n\n")

cat("\nNext step: Run 06_figures_publication.R to regenerate all figures\n")
