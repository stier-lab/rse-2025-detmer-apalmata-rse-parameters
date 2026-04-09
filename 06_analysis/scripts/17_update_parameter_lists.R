################################################################################
# 17_update_parameter_lists.R - Update RSE Model Parameter Files
################################################################################
#
# PURPOSE:
#   Regenerate the parameter_lists/ files using the current analysis pipeline
#   outputs. This ensures parameters are consistent with the latest threshold
#   and transition matrix analyses. Survival parameters are derived from
#   cell-weighted estimates (prepared_survival_cells.rds), which combine
#   individual-level and summary-level data with inverse-variance weighting.
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds (individual records, for lab/growth)
#   - 06_analysis/output/prepared_survival_cells.rds (cell-level: individual + summary)
#   - 06_analysis/output/prepared_growth_data.rds
#   - 06_analysis/output/survival_thresholds.csv
#   - 06_analysis/output/growth_thresholds.csv
#   - 06_analysis/output/transition_matrix.rds
#   - 05_data/standardized/apal_surv_lab_short.csv
#
# OUTPUTS:
#   - parameter_lists/field_surv_pars.rds
#   - parameter_lists/field_growth_pars.rds
#   - parameter_lists/nurs_surv_pars.rds
#   - parameter_lists/nurs_growth_pars.rds
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
# Stage 1: Resample studies with replacement
# Stage 2: Resample cells within each study (each cell has n_initial and prop_survived)
# Returns sample-size-weighted mean survival per size class, matching script 13 methodology
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
# 1. FIELD SURVIVAL PARAMETERS
# =============================================================================

cat("Generating field survival parameters (cell-weighted, individual + summary)...\n")

# Add size class to individual survival data (still needed for nursery/lab and growth)
surv_data <- surv_data %>%
  mutate(
    size_class = cut(size_cm2,
                     breaks = size_class_breaks,
                     labels = SIZE_LABELS,
                     include.lowest = TRUE)
  )

# Filter cells to natural colonies for field survival parameters
# This matches script 13's transition matrix filter: wild populations only.
# Restoration fragments and recruits go into nursery parameters instead.
field_cells <- surv_cells %>%
  filter(population_type == "Natural colony")

cat(sprintf("  Field cells: %d (%d individual + %d summary) from %d studies, N=%s\n",
            nrow(field_cells),
            sum(field_cells$data_source == "individual"),
            sum(field_cells$data_source == "summary"),
            n_distinct(field_cells$study),
            scales::comma(sum(field_cells$n_initial))))

# Calculate survival by size class (inverse-variance weighted on logit scale)
surv_by_sc <- field_cells %>%
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
    sd = sqrt(mean * (1 - mean) / n),  # Approximate binomial SE
    .groups = "drop"
  )

cat("  Survival by size class (cell-weighted):\n")
print(surv_by_sc)
cat("\n")

# Bootstrap survival distributions (hierarchical: studies then cells)
set.seed(42)
SC_surv_results <- bootstrap_survival_cells(field_cells, n_boot = 1000, study_col = "study")

# Create field survival parameter list
field_surv_pars <- list(
  SC_surv_results = SC_surv_results,
  surv_summary = surv_by_sc,
  size_class_breaks = size_class_breaks,
  n_observations = sum(field_cells$n_initial),
  n_cells = nrow(field_cells),
  n_studies = n_distinct(field_cells$study),
  data_integration = "cell-level weighted (individual + summary data)",
  generation_date = Sys.time(),
  ci_type = "cluster_bootstrap_percentile",
  ci_interpretation = "Confidence interval for population mean, not prediction interval for individual outcome",
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

# Create field growth parameter list
field_growth_pars <- list(
  growth_trans_df = growth_trans_df,
  growth_results = SC_growth_results,
  growth_summary = growth_by_sc,
  trans_summary = trans_summary,
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

  nurs_surv_pars <- list(
    SC_surv_results = nurs_SC_surv_results,
    surv_summary = nurs_surv_by_sc,
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

  nurs_growth_pars <- list(
    growth_trans_df = nurs_growth_trans_df,
    growth_results = nurs_growth_results,
    growth_summary = nurs_growth_by_sc,
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
