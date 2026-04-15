################################################################################
# 17_update_parameter_lists.R - Update RSE Model Parameter Files
################################################################################
#
# PURPOSE:
#   Regenerate the parameter_lists/ files using the current analysis pipeline
#   outputs. This ensures parameters are consistent with the latest threshold
#   and transition matrix analyses. Field survival parameters are read directly
#   from script 13's rma() bootstrap output (survival_bootstrap_by_sc.rds),
#   ensuring identical survival estimates as the transition matrix. Nursery
#   survival uses cell-level bootstrap from prepared_survival_cells.rds.
#
# INPUTS:
#   - 06_analysis/output/survival_bootstrap_by_sc.rds (field survival from script 13's rma bootstrap)
#   - 06_analysis/output/transition_matrix.rds (point estimates, metadata)
#   - 06_analysis/output/prepared_survival_data.rds (individual records, for lab/growth)
#   - 06_analysis/output/prepared_survival_cells.rds (cell-level, for nursery bootstrap)
#   - 06_analysis/output/prepared_growth_data.rds
#   - 06_analysis/output/survival_thresholds.csv
#   - 06_analysis/output/growth_thresholds.csv
#   - 05_data/standardized/apal_surv_lab_short.csv
#
# OUTPUTS:
#   - parameter_lists/field_surv_pars.rds
#   - parameter_lists/field_growth_pars.rds
#   - parameter_lists/nurs_surv_pars.rds
#   - parameter_lists/nurs_growth_pars.rds
#   - parameter_lists/recruit_surv_pars.rds (restoration recruit survival + s_recruit)
#   - parameter_lists/lab_surv_pars.rds
#   - parameter_lists/lab_growth_pars.rds
#
# Author: Detmer & Stier Lab
# Date: 2025-12-25
################################################################################

# Load required packages
library(dplyr)
library(tidyr)
library(readr)

# Source shared utilities for constants and helper functions
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  08: UPDATE PARAMETER LISTS                                  ║\n")
cat("║  Regenerate RSE Model Parameters from Pipeline Outputs       ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# =============================================================================
# SETUP
# =============================================================================

# Determine project root
if (file.exists("05_data/standardized")) {
  project_root <- "."
} else if (file.exists("../05_data/standardized")) {
  project_root <- ".."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root. Run from project directory or 06_analysis/scripts/")
}

output_dir <- file.path(project_root, "06_analysis/output")
param_dir <- file.path(project_root, "parameter_lists")
data_dir <- file.path(project_root, "05_data/standardized")

dir.create(param_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SIZE CLASS DEFINITIONS (from shared_utilities.R)
# =============================================================================

# Use canonical constants from shared_utilities.R
size_class_breaks <- SIZE_BREAKS
size_class_labels <- SIZE_LABELS
SC_lower <- c(0, 10, 100, 900, 4000)
SC_upper <- c(10, 100, 900, 4000, 50000)  # Upper bound for SC5

cat("Size class definitions:\n")
for (i in 1:5) {
  cat(sprintf("  SC%d: %.0f - %.0f cm²\n", i, SC_lower[i], SC_upper[i]))
}
cat("\n")

# =============================================================================
# LOAD PREPARED DATA
# =============================================================================

cat("Loading prepared data...\n")

# Survival data (individual records — still used for nursery/lab subsetting and growth)
surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
cat(sprintf("  Survival (individual): %d observations\n", nrow(surv_data)))

# Cell-level survival dataset (individual + summary, sample-size weighted)
surv_cells <- readRDS(file.path(output_dir, "prepared_survival_cells.rds"))
cat(sprintf("  Survival (cells): %d cells from %d studies, N=%s\n",
            nrow(surv_cells), n_distinct(surv_cells$study),
            scales::comma(sum(surv_cells$n_initial))))

# Growth data
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))
cat(sprintf("  Growth: %d observations\n", nrow(growth_data)))

# Lab survival data
lab_surv <- read_csv(file.path(data_dir, "apal_surv_lab_short.csv"),
                     show_col_types = FALSE)
cat(sprintf("  Lab survival: %d observations\n", nrow(lab_surv)))

# Transition matrix results
if (file.exists(file.path(output_dir, "transition_matrix.rds"))) {
  trans_results <- readRDS(file.path(output_dir, "transition_matrix.rds"))
  cat("  Transition matrix: loaded\n")
} else {
  cat("  Transition matrix: not found (will use raw calculations)\n")
  trans_results <- NULL
}

cat("\n")

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Hierarchical bootstrap resampling function for survival
# Stage 1: Resample studies with replacement (accounts for study-level clustering)
# Stage 2: Resample observations within each resampled study
# This correctly accounts for I^2=97.8% study heterogeneity
bootstrap_survival <- function(data, size_class_col = "size_class",
                                n_boot = 1000, study_col = "study") {
  size_classes <- sort(unique(data[[size_class_col]]))
  results <- list()

  for (sc in size_classes) {
    sc_data <- data[data[[size_class_col]] == sc, ]

    if (nrow(sc_data) == 0) {
      # No data for this size class - use weakly informative prior
      # Prior mean varies by size class (larger corals survive better)
      sc_num <- as.numeric(gsub("[^0-9]", "", sc))
      prior_a <- ifelse(sc_num >= 4, 7, ifelse(sc_num >= 2, 3, 1))
      prior_b <- ifelse(sc_num >= 4, 3, ifelse(sc_num >= 2, 7, 9))
      boot_samples <- rbeta(n_boot, prior_a, prior_b)
      results[[as.character(sc)]] <- list(
        mean = mean(boot_samples),
        sd = sd(boot_samples),
        ci_lower = quantile(boot_samples, 0.025),
        ci_upper = quantile(boot_samples, 0.975),
        n = 0,
        n_studies = 0,
        bootstrap_dist = boot_samples,
        note = sprintf("No data - using Beta(%d,%d) prior", prior_a, prior_b)
      )
      next
    }

    studies <- unique(sc_data[[study_col]])
    n_studies <- length(studies)
    boot_means <- numeric(n_boot)

    for (b in 1:n_boot) {
      # Stage 1: Resample studies with replacement
      boot_studies <- sample(studies, n_studies, replace = TRUE)

      # Stage 2: For each resampled study, resample observations
      boot_data <- do.call(rbind, lapply(boot_studies, function(s) {
        study_data <- sc_data[sc_data[[study_col]] == s, ]
        study_data[sample(1:nrow(study_data), nrow(study_data), replace = TRUE), ]
      }))

      boot_means[b] <- mean(boot_data$survived, na.rm = TRUE)
    }

    results[[as.character(sc)]] <- list(
      mean = mean(boot_means),
      sd = sd(boot_means),
      ci_lower = quantile(boot_means, 0.025),
      ci_upper = quantile(boot_means, 0.975),
      n = nrow(sc_data),
      n_studies = n_studies,
      bootstrap_dist = boot_means
    )
  }

  return(results)
}

# Cell-level hierarchical bootstrap for survival (individual + summary data)
# NOTE: This function is used for NURSERY survival only (line ~623).
# Field survival now comes from script 13's rma() bootstrap output directly.
# Stage 1: Resample studies with replacement
# Stage 2: Resample cells within each study (each cell has n_initial and prop_survived)
# Returns inverse-variance-weighted mean survival per size class on logit scale
bootstrap_survival_cells <- function(cells, size_class_col = "size_class",
                                      n_boot = 1000, study_col = "study") {
  size_classes <- sort(unique(cells[[size_class_col]]))
  results <- list()

  for (sc in size_classes) {
    sc_cells <- cells[cells[[size_class_col]] == sc, ]

    if (nrow(sc_cells) == 0) {
      sc_num <- as.numeric(gsub("[^0-9]", "", sc))
      prior_a <- ifelse(sc_num >= 4, 7, ifelse(sc_num >= 2, 3, 1))
      prior_b <- ifelse(sc_num >= 4, 3, ifelse(sc_num >= 2, 7, 9))
      boot_samples <- rbeta(n_boot, prior_a, prior_b)
      results[[as.character(sc)]] <- list(
        mean = mean(boot_samples), sd = sd(boot_samples),
        ci_lower = quantile(boot_samples, 0.025),
        ci_upper = quantile(boot_samples, 0.975),
        n = 0, n_studies = 0, bootstrap_dist = boot_samples,
        note = sprintf("No data - using Beta(%d,%d) prior", prior_a, prior_b)
      )
      next
    }

    studies <- unique(sc_cells[[study_col]])
    n_studies <- length(studies)
    boot_means <- numeric(n_boot)

    for (b in 1:n_boot) {
      boot_studies <- sample(studies, n_studies, replace = TRUE)
      boot_cells <- do.call(rbind, lapply(boot_studies, function(s) {
        study_cells <- sc_cells[sc_cells[[study_col]] == s, ]
        study_cells[sample(nrow(study_cells), nrow(study_cells), replace = TRUE), ]
      }))
      # Inverse-variance weighted mean on logit scale, back-transformed (matches script 13)
      boot_cells$annual_surv <- boot_cells$prop_survived^(1 / boot_cells$time_interval_yr)
      boot_cells$ann_adj <- (boot_cells$annual_surv * boot_cells$n_initial + 0.5) / (boot_cells$n_initial + 1)
      boot_cells$yi_ann <- log(boot_cells$ann_adj / (1 - boot_cells$ann_adj))
      boot_cells$vi_ann <- 1 / (boot_cells$n_initial * boot_cells$ann_adj * (1 - boot_cells$ann_adj))
      boot_means[b] <- plogis(weighted.mean(boot_cells$yi_ann, w = 1 / boot_cells$vi_ann))
    }

    results[[as.character(sc)]] <- list(
      mean = mean(boot_means), sd = sd(boot_means),
      ci_lower = quantile(boot_means, 0.025),
      ci_upper = quantile(boot_means, 0.975),
      n = sum(sc_cells$n_initial), n_studies = n_studies,
      bootstrap_dist = boot_means
    )
  }

  return(results)
}

# Hierarchical bootstrap resampling function for growth
# Mirrors bootstrap_survival: resample studies first, then observations within studies
bootstrap_growth <- function(data, size_class_col = "size_class",
                              n_boot = 1000, study_col = "study",
                              growth_col = "growth_cm2_yr") {
  size_classes <- sort(unique(data[[size_class_col]]))
  results <- list()

  for (sc in size_classes) {
    sc_data <- data[data[[size_class_col]] == sc, ]

    if (nrow(sc_data) < 3) {
      results[[as.character(sc)]] <- list(
        mean = ifelse(nrow(sc_data) > 0, mean(sc_data[[growth_col]], na.rm = TRUE), NA),
        sd = NA, ci_lower = NA, ci_upper = NA,
        n = nrow(sc_data), n_studies = 0,
        note = "Insufficient data for bootstrap"
      )
      next
    }

    studies <- unique(sc_data[[study_col]])
    n_studies <- length(studies)
    boot_means <- numeric(n_boot)

    for (b in 1:n_boot) {
      # Stage 1: Resample studies with replacement
      boot_studies <- sample(studies, n_studies, replace = TRUE)

      # Stage 2: For each resampled study, resample observations
      boot_data <- do.call(rbind, lapply(boot_studies, function(s) {
        study_data <- sc_data[sc_data[[study_col]] == s, ]
        study_data[sample(1:nrow(study_data), nrow(study_data), replace = TRUE), ]
      }))

      boot_means[b] <- mean(boot_data[[growth_col]], na.rm = TRUE)
    }

    results[[as.character(sc)]] <- list(
      mean = mean(boot_means),
      sd = sd(boot_means),
      ci_lower = quantile(boot_means, 0.025),
      ci_upper = quantile(boot_means, 0.975),
      n = nrow(sc_data),
      n_studies = n_studies,
      bootstrap_dist = boot_means
    )
  }

  return(results)
}

# Hierarchical bootstrap resampling function for growth transitions
# Uses study-level clustering consistent with bootstrap_survival and bootstrap_growth
bootstrap_growth_transitions <- function(data, n_boot = 1000, study_col = "study") {
  results <- list()

  for (sc_idx in 1:5) {
    from_sc <- SIZE_LABELS[sc_idx]
    sc_data <- data %>% filter(size_class == from_sc)

    if (nrow(sc_data) == 0) {
      # No data - assume staying in same class
      trans_probs <- data.frame(
        from_class = from_sc,
        to_class = SIZE_LABELS,
        prob = c(0, 0, 0, 0, 0)
      )
      trans_probs$prob[sc_idx] <- 1.0

      boot_list <- lapply(1:n_boot, function(i) {
        trans_probs %>% mutate(replicate = i)
      })
    } else {
      # Calculate final size class after growth
      sc_data <- sc_data %>%
        mutate(
          final_size = pmax(size_cm2 + growth_rate, 0.01),  # Minimum 0.01 cm² (near-zero, but positive for log transforms)
          # Note: individuals with extreme negative growth (final_size near 0) likely represent
          # partial mortality events that may be better modeled as mortality
          final_class = cut(final_size,
                           breaks = size_class_breaks,
                           labels = SIZE_LABELS,
                           include.lowest = TRUE)
        )

      studies <- unique(sc_data[[study_col]])
      n_studies <- length(studies)

      boot_list <- lapply(1:n_boot, function(i) {
        # Stage 1: Resample studies with replacement
        boot_studies <- sample(studies, n_studies, replace = TRUE)

        # Stage 2: For each resampled study, resample observations
        boot_data <- do.call(rbind, lapply(boot_studies, function(s) {
          study_data <- sc_data[sc_data[[study_col]] == s, ]
          study_data[sample(1:nrow(study_data), nrow(study_data), replace = TRUE), ]
        }))

        trans_counts <- table(factor(boot_data$final_class, levels = SIZE_LABELS))
        trans_probs <- trans_counts / sum(trans_counts)

        data.frame(
          from_class = from_sc,
          to_class = SIZE_LABELS,
          prob = as.numeric(trans_probs),
          replicate = i
        )
      })
    }

    results[[sc_idx]] <- bind_rows(boot_list)
  }

  bind_rows(results)
}

# =============================================================================
# 1. FIELD SURVIVAL PARAMETERS (from script 13's study-level rma bootstrap)
# =============================================================================

cat("Generating field survival parameters (from script 13 rma bootstrap)...\n")

# Add size class to individual survival data (still needed for nursery/lab and growth)
surv_data <- surv_data %>%
  mutate(
    size_class = cut(size_cm2,
                     breaks = size_class_breaks,
                     labels = SIZE_LABELS,
                     include.lowest = TRUE)
  )

# Read script 13's per-SC bootstrap survival distributions
# These are computed via: cells -> study-level aggregation -> rma(PLO, REML) per SC
# with 2000 hierarchical bootstrap iterations (resample studies -> cells -> re-aggregate -> re-fit rma)
surv_boot_sc_path <- file.path(output_dir, "survival_bootstrap_by_sc.rds")
if (!file.exists(surv_boot_sc_path)) {
  stop("survival_bootstrap_by_sc.rds not found. Run script 13 first.")
}
boot_survival_by_sc <- readRDS(surv_boot_sc_path)

# Read point estimates from transition_matrix.rds (already loaded at top of script)
if (is.null(trans_results) || is.null(trans_results$survival_by_class)) {
  stop("transition_matrix.rds missing or lacks survival_by_class. Run script 13 first.")
}
surv_by_class <- trans_results$survival_by_class

cat(sprintf("  Loaded %d bootstrap iterations x %d size classes from script 13\n",
            nrow(boot_survival_by_sc), ncol(boot_survival_by_sc)))

# Build SC_surv_results list from rma bootstrap
SC_surv_results <- lapply(1:5, function(i) {
  sc <- SIZE_LABELS[i]
  boot_dist <- boot_survival_by_sc[, i]
  list(
    mean = mean(boot_dist),
    sd = sd(boot_dist),
    ci_lower = quantile(boot_dist, 0.025),
    ci_upper = quantile(boot_dist, 0.975),
    n = surv_by_class$n[i],
    n_studies = surv_by_class$n_studies[i],
    bootstrap_dist = boot_dist
  )
})
names(SC_surv_results) <- SIZE_LABELS

# Build surv_by_sc summary tibble
surv_by_sc <- tibble(
  size_class = factor(SIZE_LABELS, levels = SIZE_LABELS),
  n = surv_by_class$n,
  n_studies = surv_by_class$n_studies,
  mean = surv_by_class$survival,
  sd = surv_by_class$se
)

cat("  Survival by size class (study-level rma from script 13):\n")
print(surv_by_sc)
cat("\n")

# --- Build backward-compatible elements for RSE model consumption ---
# The RSE repo (Detmer-2025-coral-RSE) expects $SC_surv_summ_df (data.frame with
# integer size_class 1-5 and Q05/Q25/Q50/Q75/Q95 columns) and $SC_surv_df
# (data.frame with prop_survived, size_class, replicate columns).
SC_surv_summ_df <- do.call(rbind, lapply(seq_along(SC_surv_results), function(i) {
  r <- SC_surv_results[[i]]
  data.frame(
    size_class = i,
    n = r$n, n_studies = r$n_studies,
    mean = r$mean, sd = r$sd,
    Q05 = quantile(r$bootstrap_dist, 0.05),
    Q25 = quantile(r$bootstrap_dist, 0.25),
    Q50 = quantile(r$bootstrap_dist, 0.50),
    Q75 = quantile(r$bootstrap_dist, 0.75),
    Q95 = quantile(r$bootstrap_dist, 0.95),
    row.names = NULL
  )
}))

SC_surv_df <- do.call(rbind, lapply(seq_along(SC_surv_results), function(i) {
  r <- SC_surv_results[[i]]
  data.frame(
    prop_survived = r$bootstrap_dist,
    size_class = i,
    replicate = seq_along(r$bootstrap_dist)
  )
}))

# Filter cells to natural colonies (still needed for metadata and downstream nursery filtering)
field_cells <- surv_cells %>%
  filter(population_type == "Natural colony")

# Create field survival parameter list (includes both new and RSE-compatible elements)
field_surv_pars <- list(
  # New format (used by this repo's scripts)
  SC_surv_results = SC_surv_results,
  surv_summary = surv_by_sc,
  # RSE-compatible format (used by Detmer-2025-coral-RSE)
  SC_surv_summ_df = SC_surv_summ_df,
  SC_surv_df = SC_surv_df,
  # Metadata
  size_class_breaks = size_class_breaks,
  n_observations = sum(surv_by_class$n),
  n_studies = max(surv_by_class$n_studies),
  n_bootstrap = nrow(boot_survival_by_sc),
  data_integration = "study-level rma (from script 13, metafor::rma per size class)",
  generation_date = Sys.time(),
  ci_type = "rma_bootstrap_percentile",
  ci_interpretation = "Confidence interval from study-level random-effects meta-analysis bootstrap",
  note_prediction = "For individual coral predictions, combine parameter uncertainty with binomial/normal observation model"
)

saveRDS(field_surv_pars, file.path(param_dir, "field_surv_pars.rds"))
cat("  ✓ Saved: field_surv_pars.rds\n\n")

# =============================================================================
# 2. FIELD GROWTH PARAMETERS
# =============================================================================

cat("Generating field growth parameters...\n")

# Add size class to growth data
growth_data <- growth_data %>%
  mutate(
    size_class = cut(size_cm2,
                     breaks = size_class_breaks,
                     labels = SIZE_LABELS,
                     include.lowest = TRUE)
  )

# Calculate growth by size class (column is growth_cm2_yr in prepared data)
growth_data <- growth_data %>%
  mutate(growth_rate = growth_cm2_yr)  # Standardize column name

growth_by_sc <- growth_data %>%
  group_by(size_class) %>%
  summarise(
    n = n(),
    mean_growth = mean(growth_rate, na.rm = TRUE),
    sd_growth = sd(growth_rate, na.rm = TRUE),
    mean_rgr = mean(rgr, na.rm = TRUE),
    sd_rgr = sd(rgr, na.rm = TRUE),
    prop_positive = mean(growth_rate > 0, na.rm = TRUE),
    Q05 = quantile(growth_rate, 0.05, na.rm = TRUE),
    Q50 = quantile(growth_rate, 0.50, na.rm = TRUE),
    Q95 = quantile(growth_rate, 0.95, na.rm = TRUE),
    .groups = "drop"
  )

cat("  Growth by size class:\n")
print(growth_by_sc)
cat("\n")

# Bootstrap growth means (hierarchical: studies then observations)
set.seed(42)
SC_growth_results <- bootstrap_growth(growth_data, n_boot = 1000, study_col = "study",
                                       growth_col = "growth_rate")

# Bootstrap growth transition probabilities
set.seed(42)
growth_trans_df <- bootstrap_growth_transitions(growth_data, n_boot = 1000)

# Calculate transition matrix summary
trans_summary <- growth_trans_df %>%
  group_by(from_class, to_class) %>%
  summarise(
    mean_prob = mean(prob),
    sd_prob = sd(prob),
    Q05 = quantile(prob, 0.05),
    Q95 = quantile(prob, 0.95),
    .groups = "drop"
  )

# --- Build backward-compatible growth elements for RSE model ---
# RSE expects $summ_list (list of 5 data.frames, one per from-class) and
# $mat_list (list of 5 data.frames, rows = bootstrap replicates, cols = to-classes).
summ_list <- lapply(SIZE_LABELS, function(from_sc) {
  sub <- trans_summary %>% filter(from_class == from_sc)
  df <- data.frame(
    to_class = sub$to_class,
    mean = sub$mean_prob,
    Q05 = sub$Q05,
    Q95 = sub$Q95
  )
  rownames(df) <- df$to_class
  df
})
names(summ_list) <- SIZE_LABELS

mat_list <- lapply(SIZE_LABELS, function(from_sc) {
  sub <- growth_trans_df %>% filter(from_class == from_sc)
  wide <- sub %>%
    tidyr::pivot_wider(names_from = to_class, values_from = prob, id_cols = replicate) %>%
    select(-replicate)
  as.data.frame(wide)
})
names(mat_list) <- SIZE_LABELS

# Create field growth parameter list (includes both new and RSE-compatible elements)
field_growth_pars <- list(
  # New format
  growth_trans_df = growth_trans_df,
  growth_results = SC_growth_results,
  growth_summary = growth_by_sc,
  trans_summary = trans_summary,
  # RSE-compatible format
  summ_list = summ_list,
  mat_list = mat_list,
  # Metadata
  size_class_breaks = size_class_breaks,
  n_observations = nrow(growth_data),
  n_studies = n_distinct(growth_data$study),
  generation_date = Sys.time(),
  ci_type = "cluster_bootstrap_percentile",
  ci_interpretation = "Confidence interval for population mean, not prediction interval for individual outcome",
  note_prediction = "For individual coral predictions, combine parameter uncertainty with binomial/normal observation model"
)

saveRDS(field_growth_pars, file.path(param_dir, "field_growth_pars.rds"))
cat("  ✓ Saved: field_growth_pars.rds\n\n")

# =============================================================================
# 3. NURSERY SURVIVAL PARAMETERS
# =============================================================================

cat("Generating nursery survival parameters (cell-weighted)...\n")

# Filter cells to nursery/restoration data
nurs_cells <- surv_cells %>%
  filter(grepl("nursery", data_type, ignore.case = TRUE) |
         population_type == "Restoration fragment" |
         grepl("nursery|Nursery", study, ignore.case = TRUE))

if (nrow(nurs_cells) > 0) {
  nurs_surv_by_sc <- nurs_cells %>%
    filter(!is.na(size_class)) %>%
    mutate(
      annual_survival = prop_survived^(1 / time_interval_yr),
      ann_adj = (annual_survival * n_initial + 0.5) / (n_initial + 1),
      yi_annual = log(ann_adj / (1 - ann_adj)),
      vi_annual = 1 / (n_initial * ann_adj * (1 - ann_adj))
    ) %>%
    group_by(size_class) %>%
    summarise(
      n = sum(n_initial),
      n_cells = n(),
      n_studies = n_distinct(study),
      mean = plogis(weighted.mean(yi_annual, w = 1 / vi_annual)),
      sd = sqrt(mean * (1 - mean) / n),
      .groups = "drop"
    )

  set.seed(42)
  nurs_SC_surv_results <- bootstrap_survival_cells(nurs_cells, n_boot = 500, study_col = "study")

  # RSE-compatible elements for nursery survival
  nurs_SC_surv_summ_df <- do.call(rbind, lapply(seq_along(nurs_SC_surv_results), function(i) {
    r <- nurs_SC_surv_results[[i]]
    data.frame(
      size_class = i, n = r$n, n_studies = r$n_studies,
      mean = r$mean, sd = r$sd,
      Q05 = quantile(r$bootstrap_dist, 0.05),
      Q25 = quantile(r$bootstrap_dist, 0.25),
      Q50 = quantile(r$bootstrap_dist, 0.50),
      Q75 = quantile(r$bootstrap_dist, 0.75),
      Q95 = quantile(r$bootstrap_dist, 0.95),
      row.names = NULL
    )
  }))
  nurs_SC_surv_df <- do.call(rbind, lapply(seq_along(nurs_SC_surv_results), function(i) {
    r <- nurs_SC_surv_results[[i]]
    data.frame(prop_survived = r$bootstrap_dist, size_class = i,
               replicate = seq_along(r$bootstrap_dist))
  }))

  nurs_surv_pars <- list(
    SC_surv_results = nurs_SC_surv_results,
    surv_summary = nurs_surv_by_sc,
    SC_surv_summ_df = nurs_SC_surv_summ_df,
    SC_surv_df = nurs_SC_surv_df,
    n_observations = sum(nurs_cells$n_initial),
    n_cells = nrow(nurs_cells),
    n_studies = n_distinct(nurs_cells$study),
    data_integration = "cell-level weighted (individual + summary data)",
    generation_date = Sys.time(),
    ci_type = "cluster_bootstrap_percentile",
    ci_interpretation = "Confidence interval for population mean, not prediction interval for individual outcome",
    note_prediction = "For individual coral predictions, combine parameter uncertainty with binomial/normal observation model"
  )

  cat(sprintf("  %d nursery cells, N=%s from %d studies\n",
              nrow(nurs_cells), scales::comma(sum(nurs_cells$n_initial)),
              n_distinct(nurs_cells$study)))
} else {
  # Create placeholder with field data priors
  cat("  No nursery-specific survival data, using field data priors\n")
  nurs_surv_pars <- list(
    SC_surv_results = field_surv_pars$SC_surv_results,
    surv_summary = surv_by_sc,
    n_observations = 0,
    n_studies = 0,
    note = "No nursery-specific data; using field survival as prior",
    data_source = "field_prior",
    generation_date = Sys.time(),
    ci_type = "cluster_bootstrap_percentile",
    ci_interpretation = "Confidence interval for population mean, not prediction interval for individual outcome",
    note_prediction = "For individual coral predictions, combine parameter uncertainty with binomial/normal observation model"
  )
}

saveRDS(nurs_surv_pars, file.path(param_dir, "nurs_surv_pars.rds"))
cat("  ✓ Saved: nurs_surv_pars.rds\n\n")

# =============================================================================
# 4. NURSERY GROWTH PARAMETERS
# =============================================================================

cat("Generating nursery growth parameters...\n")

# Filter for nursery growth data (data_type values are "nursery_in" and "nursery_ex", not "nursery")
nurs_growth_data <- growth_data %>%
  filter(grepl("nursery", data_type) | grepl("nursery|Nursery", study, ignore.case = TRUE))

if (nrow(nurs_growth_data) > 0) {
  nurs_growth_by_sc <- nurs_growth_data %>%
    group_by(size_class) %>%
    summarise(
      n = n(),
      mean_growth = mean(growth_rate),
      sd_growth = sd(growth_rate),
      .groups = "drop"
    )

  set.seed(42)
  nurs_growth_trans_df <- bootstrap_growth_transitions(nurs_growth_data, n_boot = 500)

  # Also bootstrap nursery growth means
  set.seed(42)
  nurs_growth_results <- bootstrap_growth(nurs_growth_data, n_boot = 500,
                                           study_col = "study", growth_col = "growth_rate")

  # RSE-compatible growth elements
  nurs_trans_summary <- nurs_growth_trans_df %>%
    group_by(from_class, to_class) %>%
    summarise(mean_prob = mean(prob), Q05 = quantile(prob, 0.05),
              Q95 = quantile(prob, 0.95), .groups = "drop")
  nurs_summ_list <- lapply(SIZE_LABELS, function(from_sc) {
    sub <- nurs_trans_summary %>% filter(from_class == from_sc)
    df <- data.frame(to_class = sub$to_class, mean = sub$mean_prob,
                     Q05 = sub$Q05, Q95 = sub$Q95)
    rownames(df) <- df$to_class; df
  }); names(nurs_summ_list) <- SIZE_LABELS
  nurs_mat_list <- lapply(SIZE_LABELS, function(from_sc) {
    sub <- nurs_growth_trans_df %>% filter(from_class == from_sc)
    wide <- sub %>% tidyr::pivot_wider(names_from = to_class, values_from = prob,
                                        id_cols = replicate) %>% select(-replicate)
    as.data.frame(wide)
  }); names(nurs_mat_list) <- SIZE_LABELS

  nurs_growth_pars <- list(
    growth_trans_df = nurs_growth_trans_df,
    growth_results = nurs_growth_results,
    growth_summary = nurs_growth_by_sc,
    trans_summary = nurs_trans_summary,
    summ_list = nurs_summ_list,
    mat_list = nurs_mat_list,
    n_observations = nrow(nurs_growth_data),
    n_studies = n_distinct(nurs_growth_data$study),
    generation_date = Sys.time(),
    ci_type = "cluster_bootstrap_percentile",
    ci_interpretation = "Confidence interval for population mean, not prediction interval for individual outcome",
    note_prediction = "For individual coral predictions, combine parameter uncertainty with binomial/normal observation model"
  )

  cat(sprintf("  %d nursery growth observations\n", nrow(nurs_growth_data)))
} else {
  cat("  No nursery-specific growth data, using field data priors\n")
  nurs_growth_pars <- list(
    growth_trans_df = field_growth_pars$growth_trans_df,
    growth_results = field_growth_pars$growth_results,
    growth_summary = growth_by_sc,
    summ_list = field_growth_pars$summ_list,
    mat_list = field_growth_pars$mat_list,
    n_observations = 0,
    n_studies = 0,
    note = "No nursery-specific data; using field growth as prior",
    data_source = "field_prior",
    generation_date = Sys.time(),
    ci_type = "cluster_bootstrap_percentile",
    ci_interpretation = "Confidence interval for population mean, not prediction interval for individual outcome",
    note_prediction = "For individual coral predictions, combine parameter uncertainty with binomial/normal observation model"
  )
}

saveRDS(nurs_growth_pars, file.path(param_dir, "nurs_growth_pars.rds"))
cat("  ✓ Saved: nurs_growth_pars.rds\n\n")

# =============================================================================
# 5. LAB SURVIVAL PARAMETERS
# =============================================================================

cat("Generating lab survival parameters...\n")

if (nrow(lab_surv) > 0) {
  # Lab data is typically short-term settler/recruit survival
  lab_surv_summary <- lab_surv %>%
    summarise(
      n = n(),
      mean_survival = mean(prop_survived, na.rm = TRUE),
      sd_survival = sd(prop_survived, na.rm = TRUE),
      min_survival = min(prop_survived, na.rm = TRUE),
      max_survival = max(prop_survived, na.rm = TRUE)
    )

  cat("  Lab survival summary:\n")
  print(lab_surv_summary)

  # Hierarchical bootstrap lab survival (resample studies, then observations)
  set.seed(42)
  n_boot <- 500
  lab_studies <- unique(lab_surv$study)
  n_lab_studies <- length(lab_studies)

  lab_boot <- replicate(n_boot, {
    # Stage 1: Resample studies
    boot_studies <- sample(lab_studies, n_lab_studies, replace = TRUE)
    # Stage 2: Resample observations within studies
    boot_data <- do.call(rbind, lapply(boot_studies, function(s) {
      study_data <- lab_surv[lab_surv$study == s, ]
      study_data[sample(1:nrow(study_data), nrow(study_data), replace = TRUE), ]
    }))
    mean(boot_data$prop_survived, na.rm = TRUE)
  })

  lab_surv_pars <- list(
    survival_boot = lab_boot,
    survival_summary = lab_surv_summary,
    raw_data = lab_surv,
    n_observations = nrow(lab_surv),
    n_studies = n_lab_studies,
    note = "Short-term lab/settler survival rates",
    generation_date = Sys.time(),
    ci_type = "cluster_bootstrap_percentile",
    ci_interpretation = "Confidence interval for population mean, not prediction interval for individual outcome",
    note_prediction = "For individual coral predictions, combine parameter uncertainty with binomial/normal observation model"
  )

  cat(sprintf("  %d lab survival records\n", nrow(lab_surv)))
} else {
  cat("  No lab survival data\n")
  lab_surv_pars <- list(
    survival_boot = rep(0.5, 500),  # Uninformative prior
    n_observations = 0,
    n_studies = 0,
    note = "No lab survival data; using uninformative prior",
    generation_date = Sys.time(),
    ci_type = "cluster_bootstrap_percentile",
    ci_interpretation = "Confidence interval for population mean, not prediction interval for individual outcome",
    note_prediction = "For individual coral predictions, combine parameter uncertainty with binomial/normal observation model"
  )
}

saveRDS(lab_surv_pars, file.path(param_dir, "lab_surv_pars.rds"))
cat("  ✓ Saved: lab_surv_pars.rds\n\n")

# =============================================================================
# 6. LAB GROWTH PARAMETERS
# =============================================================================

cat("Generating lab growth parameters...\n")

# Lab growth is typically for small settlers/recruits
# Use SC1 growth from field data as proxy
lab_growth_by_sc <- growth_by_sc %>%
  filter(size_class == "SC1")

if (nrow(lab_growth_by_sc) > 0) {
  # Use SC1 (recruit) growth rates with hierarchical bootstrap
  sc1_growth <- growth_data %>% filter(size_class == "SC1")

  set.seed(42)
  n_boot <- 500
  sc1_studies <- unique(sc1_growth$study)
  n_sc1_studies <- length(sc1_studies)

  if (n_sc1_studies > 0 && nrow(sc1_growth) > 0) {
    lab_growth_boot <- replicate(n_boot, {
      # Stage 1: Resample studies
      boot_studies <- sample(sc1_studies, n_sc1_studies, replace = TRUE)
      # Stage 2: Resample observations within studies
      boot_data <- do.call(rbind, lapply(boot_studies, function(s) {
        study_data <- sc1_growth[sc1_growth$study == s, ]
        study_data[sample(1:nrow(study_data), nrow(study_data), replace = TRUE), ]
      }))
      mean(boot_data$growth_rate, na.rm = TRUE)
    })
  } else {
    lab_growth_boot <- rnorm(n_boot, 10, 5)  # Prior for small coral growth
  }

  lab_growth_pars <- list(
    growth_boot = lab_growth_boot,
    growth_summary = lab_growth_by_sc,
    n_observations = nrow(sc1_growth),
    n_studies = n_sc1_studies,
    note = "Lab growth estimated from SC1 (recruit) field growth rates",
    generation_date = Sys.time(),
    ci_type = "cluster_bootstrap_percentile",
    ci_interpretation = "Confidence interval for population mean, not prediction interval for individual outcome",
    note_prediction = "For individual coral predictions, combine parameter uncertainty with binomial/normal observation model"
  )

  cat(sprintf("  Using %d SC1 observations from %d studies as lab growth proxy\n",
              nrow(sc1_growth), n_sc1_studies))
} else {
  cat("  No SC1 growth data, using prior\n")
  lab_growth_pars <- list(
    growth_boot = rnorm(500, 10, 5),
    n_observations = 0,
    n_studies = 0,
    note = "No SC1 data; using prior (mean=10, sd=5 cm²/yr)",
    generation_date = Sys.time(),
    ci_type = "cluster_bootstrap_percentile",
    ci_interpretation = "Confidence interval for population mean, not prediction interval for individual outcome",
    note_prediction = "For individual coral predictions, combine parameter uncertainty with binomial/normal observation model"
  )
}

saveRDS(lab_growth_pars, file.path(param_dir, "lab_growth_pars.rds"))
cat("  ✓ Saved: lab_growth_pars.rds\n\n")

# =============================================================================
# 7. RESTORATION RECRUIT SURVIVAL PARAMETERS (for RSE model only)
# =============================================================================
# These are post-settlement recruit survival rates from restoration programs
# (FUNDEMAR, Chamberland, Mendoza-Quiroz). They represent a fundamentally
# different life stage than nursery fragments (SC1 microscopic recruits, ~0.006 cm²)
# with very low survival (~1.7%).
#
# NOT USED in this repo's transition matrix or natural-colony analyses.
# Packaged separately for the RSE model's lab/early-life module, where they
# can inform the s1 (post-outplant first-year survival) parameter for
# recruit-based restoration scenarios.

cat("Generating restoration recruit survival parameters (RSE only)...\n")

recruit_cells <- surv_cells %>%
  filter(population_type == "Restoration recruit")

if (nrow(recruit_cells) > 0) {
  recruit_studies <- unique(recruit_cells$study)
  n_recruit_studies <- length(recruit_studies)

  # Study-level summary
  recruit_by_study <- recruit_cells %>%
    group_by(study) %>%
    summarise(
      n = sum(n_initial),
      n_cells = n(),
      mean_survival = weighted.mean(prop_survived, w = n_initial),
      .groups = "drop"
    )

  cat(sprintf("  %d cells from %d studies, N=%s\n",
              nrow(recruit_cells), n_recruit_studies,
              scales::comma(sum(recruit_cells$n_initial))))
  print(recruit_by_study)

  # Annualize and compute study-level survival
  recruit_ann <- recruit_cells %>%
    mutate(annual_survival = prop_survived^(1 / time_interval_yr)) %>%
    group_by(study) %>%
    summarise(
      n = sum(n_initial),
      survival = weighted.mean(annual_survival, w = n_initial),
      .groups = "drop"
    )

  # Hierarchical bootstrap (resample studies, then cells within studies)
  set.seed(42)
  n_boot_recruit <- 1000
  recruit_boot <- numeric(n_boot_recruit)

  for (b in 1:n_boot_recruit) {
    boot_studies <- sample(recruit_studies, n_recruit_studies, replace = TRUE)
    boot_cells <- do.call(rbind, lapply(boot_studies, function(s) {
      study_cells <- recruit_cells[recruit_cells$study == s, ]
      study_cells[sample(nrow(study_cells), nrow(study_cells), replace = TRUE), ]
    }))
    boot_cells$annual_surv <- boot_cells$prop_survived^(1 / boot_cells$time_interval_yr)
    recruit_boot[b] <- weighted.mean(boot_cells$annual_surv, w = boot_cells$n_initial)
  }

  # --- Build s_recruit: a ready-to-use RSE parameter ---
  # The RSE model currently has:
  #   s0 = lab survival (settlement to outplant-ready): 0.95
  #   s1 = post-outplant first-year survival (nursery fragments): 0.70
  # s_recruit is a NEW alternative for recruit-based restoration scenarios,
  # representing post-settlement survival of microscopic recruits on the reef.
  # Raine can use s_recruit instead of s1 when modeling larval propagation pathways.
  s_recruit_mean <- mean(recruit_boot)
  s_recruit_boot <- recruit_boot  # Full bootstrap distribution

  # --- Fecundity decomposition for transition matrix sensitivity ---
  # In the Lefkovitch matrix, F[1,j] = net recruits surviving to next census per adult.
  # For sexual reproduction: F[1,j] = eggs × fertilization × settlement × s_recruit
  # Literature values (from methodology critique):
  #   Settlement rate: ~15% (FUNDEMAR 2025 data, rest_pars.rmd)
  #   Fertilization success: highly variable, density-dependent (Levitan)
  #   Eggs per adult: unknown for most populations
  # We provide the s_recruit piece; the RSE model or fecundity analysis supplies the rest.
  #
  # Example: if an SC5 adult produces 1000 larvae, 15% settle, 2.8% survive year 1:
  #   net_fecundity = 1000 * 0.15 * 0.028 = 4.2 recruits/adult/yr entering SC1
  # Compare to script 13's min fecundity for lambda > 1: ~1.0 recruit/adult/yr

  recruit_surv_pars <- list(
    # --- Primary: bootstrap distribution ---
    survival_boot = recruit_boot,
    survival_summary = tibble(
      n = sum(recruit_cells$n_initial),
      n_studies = n_recruit_studies,
      mean_survival = mean(recruit_boot),
      sd_survival = sd(recruit_boot),
      ci_lower = quantile(recruit_boot, 0.025),
      ci_upper = quantile(recruit_boot, 0.975),
      Q05 = quantile(recruit_boot, 0.05),
      Q25 = quantile(recruit_boot, 0.25),
      Q50 = quantile(recruit_boot, 0.50),
      Q75 = quantile(recruit_boot, 0.75),
      Q95 = quantile(recruit_boot, 0.95)
    ),
    by_study = recruit_by_study,
    by_study_annualized = recruit_ann,

    # --- RSE model parameter: s_recruit ---
    # Drop-in alternative to s1 for recruit-based restoration scenarios
    s_recruit = s_recruit_mean,
    s_recruit_boot = s_recruit_boot,
    s_recruit_ci = quantile(recruit_boot, c(0.025, 0.975)),

    # --- Context for fecundity decomposition ---
    # settlement_rate is from FUNDEMAR 2025 data (rest_pars.rmd in RSE repo)
    settlement_rate_fundemar = 0.15,
    fecundity_example = list(
      description = "Example: net fecundity = larvae_per_adult * settlement_rate * s_recruit",
      larvae_per_adult = 1000,
      settlement_rate = 0.15,
      s_recruit = s_recruit_mean,
      net_fecundity = 1000 * 0.15 * s_recruit_mean
    ),

    # --- Metadata ---
    n_observations = sum(recruit_cells$n_initial),
    n_studies = n_recruit_studies,
    note = paste0(
      "Post-settlement recruit survival from restoration programs. ",
      "These are microscopic recruits (~0.006 cm^2, SC1) with very low survival. ",
      "NOT used in the transition matrix or natural-colony analyses. ",
      "s_recruit is a ready-to-use alternative to the RSE model's s1 (0.70) ",
      "for recruit-based restoration scenarios. ",
      "s1=0.70 applies to larger nursery fragments; ",
      "s_recruit applies to microscopic post-settlement recruits."
    ),
    comparison = list(
      s1_current = 0.70,
      s_recruit = s_recruit_mean,
      interpretation = paste0(
        "s1=0.70 is for nursery fragments (SC2-sized, ~10-100 cm^2). ",
        "s_recruit=", round(s_recruit_mean, 4), " is for microscopic settlers (~0.006 cm^2). ",
        "The 25x difference reflects the size-survival relationship: ",
        "larger fragments have dramatically higher survival."
      )
    ),
    data_integration = "cell-level n-weighted (restoration recruits only)",
    generation_date = Sys.time()
  )

  cat(sprintf("  s_recruit (annualized): %.4f (95%% CI: %.4f-%.4f)\n",
              s_recruit_mean,
              quantile(recruit_boot, 0.025),
              quantile(recruit_boot, 0.975)))
  cat(sprintf("  Compare to RSE s1 (nursery fragments): 0.70\n"))
  cat(sprintf("  Example net fecundity (1000 larvae × 0.15 settlement × %.4f s_recruit): %.1f recruits/adult/yr\n",
              s_recruit_mean, 1000 * 0.15 * s_recruit_mean))
} else {
  cat("  No restoration recruit data found\n")
  recruit_surv_pars <- list(
    survival_boot = rep(NA, 1000),
    n_observations = 0,
    n_studies = 0,
    note = "No restoration recruit data available",
    generation_date = Sys.time()
  )
}

saveRDS(recruit_surv_pars, file.path(param_dir, "recruit_surv_pars.rds"))
cat("  ✓ Saved: recruit_surv_pars.rds\n\n")

# =============================================================================
# SUMMARY
# =============================================================================

cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  PARAMETER UPDATE COMPLETE                                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# List generated files
param_files <- list.files(param_dir, pattern = "\\.rds$", full.names = TRUE)
cat("Generated parameter files:\n")
for (f in param_files) {
  info <- file.info(f)
  cat(sprintf("  %s (%.1f KB, %s)\n",
              basename(f),
              info$size / 1024,
              format(info$mtime, "%Y-%m-%d %H:%M")))
}

cat("\n")
cat("Data sources:\n")
cat(sprintf("  Field survival: %d observations from %d studies\n",
            nrow(surv_data), n_distinct(surv_data$study)))
cat(sprintf("  Field growth: %d observations from %d studies\n",
            nrow(growth_data), n_distinct(growth_data$study)))
cat(sprintf("  Lab survival: %d records\n", nrow(lab_surv)))

cat("\nParameter lists are now synchronized with analysis pipeline.\n\n")
