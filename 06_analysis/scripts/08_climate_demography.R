################################################################################
# 08_climate_demography.R - Climate-Demography Integration
################################################################################
#
# PURPOSE:
#   Link demographic parameters to climate conditions (temperature anomalies,
#   degree heating weeks) to understand climate impacts on A. palmata survival
#   and growth.
#
# APPROACH:
#   1. Merge maintained site-year DHW overlays when available
#   2. Assess survival correlation with disturbance flags (MHW, storm, disease)
#   3. Fit sparse-support DHW survival models with explicit coverage diagnostics
#   4. Identify climate-sensitive size classes and regions
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#   - Disturbance flags within data (storm, MHW, disease)
#
# OUTPUTS:
#   - 06_analysis/output/climate_survival_effects.csv
#   - 06_analysis/output/disturbance_impacts.csv
#   - 06_analysis/figures/supplementary/exploratory/climate_demography.png
#
# NOTE:
#   DHW support is limited by site-year overlay availability. When the verified
#   overlay exists, this script prefers it, but the current file is still sparse
#   and largely literature-LUT backed. Interpret DHW terms as supportive, not
#   definitive, climate inference.
#
# Author: Detmer & Stier Lab
# Date: 2025-12-25
################################################################################

# Load required packages
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(lme4)
library(tibble)

# Source shared utilities for constants and helper functions
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  08: CLIMATE-DEMOGRAPHY INTEGRATION                         ║\n")
cat("║  Analyzing Climate Impacts on A. palmata Demographics        ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# =============================================================================
# SETUP
# =============================================================================

if (file.exists("05_data/standardized")) {
  project_root <- "."
} else if (file.exists("../05_data/standardized")) {
  project_root <- ".."
} else if (file.exists("../../05_data/standardized")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root.")
}

output_dir <- file.path(project_root, "06_analysis/output")
fig_dir <- file.path(project_root, "06_analysis/figures/supplementary/exploratory")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# LOAD DATA
# =============================================================================

cat("Loading prepared data...\n")

surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

cat(sprintf("  Survival: %d observations\n", nrow(surv_data)))
cat(sprintf("  Growth: %d observations\n", nrow(growth_data)))

if (!"log_size" %in% colnames(surv_data)) {
  surv_data <- surv_data %>%
    mutate(
      log_size = log(pmax(coalesce(size_for_class, size_cm2, 0.1), 0.1))
    )
}

survey_year_center <- mean(surv_data$survey_yr, na.rm = TRUE)
surv_data <- surv_data %>%
  mutate(
    survey_yr_centered = survey_yr - survey_year_center
  )

dhw_candidates <- c(
  file.path(output_dir, "heat_stress_by_site_year_verified.csv"),
  file.path(output_dir, "heat_stress_by_site_year.csv")
)
dhw_file <- dhw_candidates[file.exists(dhw_candidates)][1]
has_dhw_file <- length(dhw_file) == 1 && !is.na(dhw_file)

dominant_nonmissing <- function(x) {
  x <- x[!is.na(x) & nzchar(as.character(x))]
  if (length(x) == 0) return(NA_character_)
  names(sort(table(x), decreasing = TRUE))[1]
}

classify_dhw_support <- function(n_rows, n_studies, n_regions, n_study_years) {
  if (!is.finite(n_rows) || n_rows <= 0) return("none")
  if (!is.finite(n_studies) || !is.finite(n_regions) || !is.finite(n_study_years)) {
    return("sparse")
  }
  if (n_studies < 3 || n_regions < 3 || n_study_years < 12) return("sparse")
  if (n_rows >= 500 && n_studies >= 5 && n_regions >= 5 && n_study_years >= 20) {
    return("moderate")
  }
  if (n_rows >= 100) return("limited")
  "sparse"
}

findbars_safe <- function(formula_obj) {
  if (requireNamespace("reformulas", quietly = TRUE)) {
    reformulas::findbars(formula_obj)
  } else {
    lme4::findbars(formula_obj)
  }
}

if (has_dhw_file) {
  dhw_data <- read_csv(dhw_file, show_col_types = FALSE)
  dhw_file_name <- basename(dhw_file)
  has_query_status <- "query_status" %in% names(dhw_data)
  has_dhw_source <- "dhw_source" %in% names(dhw_data)
  cat(sprintf("  DHW overlay file: %s (%d site-year rows)\n", dhw_file_name, nrow(dhw_data)))

  dhw_study_year <- dhw_data %>%
    group_by(study, region, survey_yr) %>%
    summarise(
      max_dhw = if (all(is.na(max_dhw))) NA_real_ else max(max_dhw, na.rm = TRUE),
      n_site_rows = n(),
      n_nonmissing_dhw = sum(!is.na(max_dhw)),
      any_query_error = if (has_query_status) any(query_status == "error", na.rm = TRUE) else NA,
      dominant_query_status = if (has_query_status) dominant_nonmissing(query_status) else NA_character_,
      dominant_dhw_source = if (has_dhw_source) dominant_nonmissing(dhw_source) else NA_character_,
      .groups = "drop"
    )

  surv_data <- surv_data %>%
    left_join(
      dhw_study_year %>%
        select(study, region, survey_yr, max_dhw, dominant_query_status, dominant_dhw_source),
      by = c("study", "region", "survey_yr")
    )

  dhw_supported_rows <- sum(!is.na(surv_data$max_dhw))
  dhw_supported_study_years <- n_distinct(
    surv_data %>%
      filter(!is.na(max_dhw)) %>%
      select(study, region, survey_yr)
  )
  dhw_supported_studies <- n_distinct(surv_data$study[!is.na(surv_data$max_dhw)])
  dhw_supported_regions <- n_distinct(surv_data$region[!is.na(surv_data$max_dhw)])
  dhw_support_label <- classify_dhw_support(
    dhw_supported_rows,
    dhw_supported_studies,
    dhw_supported_regions,
    dhw_supported_study_years
  )

  dhw_coverage <- tibble(
    dhw_file = dhw_file_name,
    n_site_year_rows = nrow(dhw_data),
    n_study_region_year_rows = nrow(dhw_study_year),
    n_nonmissing_site_year_rows = sum(!is.na(dhw_data$max_dhw)),
    n_nonmissing_study_region_year_rows = sum(!is.na(dhw_study_year$max_dhw)),
    n_survival_rows = nrow(surv_data),
    n_survival_rows_with_dhw = dhw_supported_rows,
    pct_survival_rows_with_dhw = dhw_supported_rows / nrow(surv_data) * 100,
    n_unique_study_years_with_dhw = dhw_supported_study_years,
    n_query_error_rows = if ("query_status" %in% names(dhw_data)) sum(dhw_data$query_status == "error", na.rm = TRUE) else NA_integer_,
    n_no_data_rows = if ("query_status" %in% names(dhw_data)) sum(dhw_data$query_status == "no_data", na.rm = TRUE) else NA_integer_,
    inference_support = dhw_support_label,
    caveat = sprintf(
      "Verified overlay preferred when present, but current DHW coverage is often literature-LUT backed and is supported here by %d studies, %d regions, and %d study-years.",
      dhw_supported_studies,
      dhw_supported_regions,
      dhw_supported_study_years
    )
  )
  write_csv(dhw_coverage, file.path(output_dir, "climate_dhw_coverage.csv"))
  cat("  Saved: climate_dhw_coverage.csv\n")
} else {
  dhw_data <- NULL
  dhw_file_name <- NA_character_
  dhw_coverage <- tibble(
    dhw_file = NA_character_,
    n_site_year_rows = 0L,
    n_study_region_year_rows = 0L,
    n_nonmissing_site_year_rows = 0L,
    n_nonmissing_study_region_year_rows = 0L,
    n_survival_rows = nrow(surv_data),
    n_survival_rows_with_dhw = 0L,
    pct_survival_rows_with_dhw = 0,
    n_unique_study_years_with_dhw = 0L,
    n_query_error_rows = NA_integer_,
    n_no_data_rows = NA_integer_,
    inference_support = "none",
    caveat = "No DHW overlay file available."
  )
}

# Check for disturbance column
has_disturbance <- "disturbance" %in% colnames(surv_data)
cat(sprintf("  Has disturbance data: %s\n\n", has_disturbance))

# =============================================================================
# 1. DISTURBANCE IMPACT ANALYSIS
# =============================================================================

cat("Analyzing disturbance impacts on survival...\n")

if (has_disturbance) {
  # Categorize disturbance types
  surv_data <- surv_data %>%
    mutate(
      disturbance_cat = case_when(
        is.na(disturbance) | disturbance == "" ~ "None recorded",
        grepl("MHW|heat|bleach", disturbance, ignore.case = TRUE) ~ "Marine heatwave",
        grepl("storm|hurricane|cyclone", disturbance, ignore.case = TRUE) ~ "Storm",
        grepl("disease|SCTLD|WP", disturbance, ignore.case = TRUE) ~ "Disease",
        TRUE ~ "Other"
      )
    )

  # Survival by disturbance category
  disturbance_survival <- surv_data %>%
    group_by(disturbance_cat) %>%
    summarise(
      n = n(),
      n_survived = sum(survived),
      survival_rate = mean(survived),
      se = sqrt(survival_rate * (1 - survival_rate) / n()),
      ci_lower = survival_rate - 1.96 * se,
      ci_upper = survival_rate + 1.96 * se,
      n_studies = n_distinct(study),
      .groups = "drop"
    ) %>%
    mutate(
      ci_lower = pmax(0, ci_lower),
      ci_upper = pmin(1, ci_upper)
    ) %>%
    arrange(desc(n))

  cat("\nSurvival by disturbance category:\n")
  print(as.data.frame(disturbance_survival))

  # Size class × disturbance interaction
  size_disturbance <- surv_data %>%
    group_by(size_class, disturbance_cat) %>%
    summarise(
      n = n(),
      survival_rate = mean(survived),
      se = sqrt(survival_rate * (1 - survival_rate) / n()),
      .groups = "drop"
    ) %>%
    filter(n >= 10)  # Minimum sample size

  write_csv(disturbance_survival, file.path(output_dir, "disturbance_impacts.csv"))
  cat("\n  ✓ Saved: disturbance_impacts.csv\n")

} else {
  cat("  No disturbance data available in dataset.\n")
  disturbance_survival <- data.frame(
    disturbance_cat = "No data",
    n = nrow(surv_data),
    survival_rate = mean(surv_data$survived)
  )
}

# =============================================================================
# 2. DHW ANALYSIS
# =============================================================================

cat("\nAnalyzing DHW impacts on survival...\n")

dhw_support_n <- sum(!is.na(surv_data$max_dhw))
cat(sprintf("  Survival rows with DHW support: %d (%.1f%%)\n",
            dhw_support_n, 100 * dhw_support_n / nrow(surv_data)))

dhw_glmm_results <- NULL
if (dhw_support_n >= 50) {
  dhw_model <- tryCatch({
    glmer(
      survived ~ log_size + max_dhw + (1 | study) + (1 | region),
      data = surv_data %>% filter(!is.na(max_dhw), !is.na(log_size)),
      family = binomial,
      control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
    )
  }, error = function(e) {
    cat(sprintf("  DHW GLMM failed with study+region RE: %s\n", e$message))
    tryCatch(
      glmer(
        survived ~ log_size + max_dhw + (1 | study),
        data = surv_data %>% filter(!is.na(max_dhw), !is.na(log_size)),
        family = binomial,
        control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
      ),
      error = function(e2) NULL
    )
  })

  if (!is.null(dhw_model)) {
    pearson_resid_dhw <- residuals(dhw_model, type = "pearson")
    n_par_dhw <- length(fixef(dhw_model)) +
      sum(sapply(VarCorr(dhw_model), function(x) prod(dim(x))))
    overdisp_ratio_dhw <- sum(pearson_resid_dhw^2) / (length(pearson_resid_dhw) - n_par_dhw)

    dhw_coef <- summary(dhw_model)$coefficients
    dhw_glmm_results <- tibble(
      term = rownames(dhw_coef),
      estimate_logodds = dhw_coef[, "Estimate"],
      std_error = dhw_coef[, "Std. Error"],
      z_value = dhw_coef[, "z value"],
      p_value = if (identical(dhw_coverage$inference_support[1], "sparse")) {
        rep(NA_real_, nrow(dhw_coef))
      } else {
        dhw_coef[, "Pr(>|z|)"]
      }
    ) %>%
      mutate(
        odds_ratio = exp(estimate_logodds),
        or_ci_lower = exp(estimate_logodds - 1.96 * std_error),
        or_ci_upper = exp(estimate_logodds + 1.96 * std_error),
        n_obs = nrow(model.frame(dhw_model)),
        n_studies = n_distinct(model.frame(dhw_model)$study),
        n_regions = if ("region" %in% names(model.frame(dhw_model))) n_distinct(model.frame(dhw_model)$region) else NA_integer_,
        dhw_file = dhw_file_name,
        inference_support = dhw_coverage$inference_support[1],
        dispersion_ratio = overdisp_ratio_dhw,
        is_singular = tryCatch(isSingular(dhw_model, tol = 1e-4), error = function(e) NA),
        interpretation = case_when(
          term == "(Intercept)" ~ "Baseline log-odds of survival in DHW-supported subset",
          term == "max_dhw" & dhw_coverage$inference_support[1] == "sparse" ~ "Descriptive association only; DHW support is too thin for inferential interpretation",
          term == "max_dhw" & p_value < 0.05 & estimate_logodds < 0 ~ "Higher DHW associated with lower survival odds",
          term == "max_dhw" & p_value < 0.05 & estimate_logodds > 0 ~ "Higher DHW associated with higher survival odds",
          term == "max_dhw" ~ "No statistically clear DHW effect in sparse-support subset",
          TRUE ~ "Adjustment term"
        )
      )
  } else {
    cat("  DHW GLMM could not be fit after fallback.\n")
    dhw_glmm_results <- tibble(
      term = "max_dhw",
      estimate_logodds = NA_real_,
      std_error = NA_real_,
      z_value = NA_real_,
      p_value = NA_real_,
      odds_ratio = NA_real_,
      or_ci_lower = NA_real_,
      or_ci_upper = NA_real_,
      n_obs = dhw_support_n,
      n_studies = n_distinct(surv_data$study[!is.na(surv_data$max_dhw)]),
      n_regions = n_distinct(surv_data$region[!is.na(surv_data$max_dhw)]),
      dhw_file = dhw_file_name,
      inference_support = dhw_coverage$inference_support[1],
      dispersion_ratio = NA_real_,
      is_singular = NA,
      interpretation = "Model failed after fallback fits."
    )
  }
} else {
  cat("  DHW support too sparse for GLMM inference (< 50 rows).\n")
  dhw_glmm_results <- tibble(
    term = "max_dhw",
    estimate_logodds = NA_real_,
    std_error = NA_real_,
    z_value = NA_real_,
    p_value = NA_real_,
    odds_ratio = NA_real_,
    or_ci_lower = NA_real_,
    or_ci_upper = NA_real_,
    n_obs = dhw_support_n,
    n_studies = n_distinct(surv_data$study[!is.na(surv_data$max_dhw)]),
    n_regions = n_distinct(surv_data$region[!is.na(surv_data$max_dhw)]),
    dhw_file = dhw_file_name,
    inference_support = dhw_coverage$inference_support[1],
    dispersion_ratio = NA_real_,
    is_singular = NA,
    interpretation = "Too few DHW-supported rows for GLMM inference."
  )
}

write_csv(dhw_glmm_results, file.path(output_dir, "climate_dhw_glmm.csv"))
cat("  Saved: climate_dhw_glmm.csv\n")

# =============================================================================
# 3. TEMPORAL ANALYSIS (Yearly Survival Trends)
# =============================================================================

cat("\nAnalyzing temporal patterns...\n")

# Survival by year
yearly_survival <- surv_data %>%
  group_by(survey_yr) %>%
  summarise(
    n = n(),
    survival_rate = mean(survived),
    se = sqrt(survival_rate * (1 - survival_rate) / n()),
    n_studies = n_distinct(study),
    mean_size = mean(size_cm2, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(n >= 20) %>%  # Minimum sample size
  arrange(survey_yr)

cat(sprintf("  Years with sufficient data: %d (%d-%d)\n",
            nrow(yearly_survival),
            min(yearly_survival$survey_yr),
            max(yearly_survival$survey_yr)))

write_csv(yearly_survival, file.path(output_dir, "yearly_survival.csv"))
cat("  Saved: yearly_survival.csv\n")

# Temporal trend using GLMM on individual data (avoids ecological fallacy)
cat("\n--- TEMPORAL SURVIVAL TREND (Individual-level GLMM) ---\n")

temporal_control <- glmerControl(
  optimizer = "bobyqa",
  optCtrl = list(maxfun = 1e5)
)

temporal_glmm <- tryCatch({
  glmer(
    survived ~ survey_yr_centered + (1 | study) + (1 | region),
    data = surv_data,
    family = binomial,
    control = temporal_control
  )
}, error = function(e) {
  cat(sprintf("GLMM failed: %s. Trying simpler model.\n", e$message))
  tryCatch(
    glmer(
      survived ~ survey_yr_centered + (1 | study),
      data = surv_data,
      family = binomial,
      control = temporal_control
    ),
    error = function(e2) NULL
  )
})

if (!is.null(temporal_glmm)) {
  glmm_coef <- fixef(temporal_glmm)["survey_yr_centered"]
  glmm_se <- summary(temporal_glmm)$coefficients["survey_yr_centered", "Std. Error"]
  glmm_z <- summary(temporal_glmm)$coefficients["survey_yr_centered", "z value"]
  glmm_p <- summary(temporal_glmm)$coefficients["survey_yr_centered", "Pr(>|z|)"]

  cat(sprintf("  Year effect (log-odds): %.4f (SE: %.4f)\n", glmm_coef, glmm_se))
  cat(sprintf("  Odds ratio per year: %.4f\n", exp(glmm_coef)))
  cat(sprintf("  z = %.3f, p = %.4f\n", glmm_z, glmm_p))

  # Overdispersion check (fixed + random effect parameters)
  pearson_resid <- residuals(temporal_glmm, type = "pearson")
  n_par <- length(fixef(temporal_glmm)) + sum(sapply(VarCorr(temporal_glmm), function(x) prod(dim(x))))
  overdisp_ratio <- sum(pearson_resid^2) / (length(pearson_resid) - n_par)
  cat(sprintf("  Overdispersion ratio: %.3f %s\n", overdisp_ratio, if(overdisp_ratio > 1.5) "(WARNING: potential overdispersion)" else "(OK)"))
  conv_messages <- tryCatch(unlist(temporal_glmm@optinfo$conv$lme4$messages),
                            error = function(e) character())
  conv_messages <- as.character(conv_messages)
  conv_messages <- conv_messages[nzchar(conv_messages)]
  re_terms <- findbars_safe(formula(temporal_glmm))
  temporal_glmm_diag <- tibble(
    model = "temporal_survival_glmm",
    n_obs = nrow(model.frame(temporal_glmm)),
    n_studies = n_distinct(model.frame(temporal_glmm)$study),
    n_regions = if ("region" %in% names(model.frame(temporal_glmm))) n_distinct(model.frame(temporal_glmm)$region) else NA_integer_,
    survey_year_center = survey_year_center,
    random_effects = paste(vapply(re_terms, function(x) paste(deparse(x), collapse = ""),
                                  character(1)), collapse = " + "),
    dispersion_ratio = overdisp_ratio,
    overdispersed = overdisp_ratio > 1.5,
    is_singular = tryCatch(lme4::isSingular(temporal_glmm, tol = 1e-4),
                           error = function(e) NA),
    convergence_ok = length(conv_messages) == 0,
    optimizer_messages = if (length(conv_messages) == 0) NA_character_
                         else paste(unique(conv_messages), collapse = " | ")
  )
  write_csv(temporal_glmm_diag, file.path(output_dir, "temporal_trend_glmm_diagnostics.csv"))
  cat("  Saved: temporal_trend_glmm_diagnostics.csv\n")

  # Save GLMM temporal trend coefficients
  glmm_summary <- summary(temporal_glmm)$coefficients
  temporal_trend_df <- data.frame(
    term = rownames(glmm_summary),
    estimate_logodds = glmm_summary[, "Estimate"],
    std_error = glmm_summary[, "Std. Error"],
    z_value = glmm_summary[, "z value"],
    p_value = glmm_summary[, "Pr(>|z|)"],
    row.names = NULL
  ) %>%
    mutate(
      term = dplyr::recode(term, survey_yr_centered = "survey_yr"),
      odds_ratio = exp(estimate_logodds),
      or_ci_lower = exp(estimate_logodds - 1.96 * std_error),
      or_ci_upper = exp(estimate_logodds + 1.96 * std_error),
      n_obs = temporal_glmm_diag$n_obs[1],
      dispersion_ratio = temporal_glmm_diag$dispersion_ratio[1],
      is_singular = temporal_glmm_diag$is_singular[1],
      convergence_ok = temporal_glmm_diag$convergence_ok[1],
      interpretation = case_when(
        term == "(Intercept)" ~ "Baseline log-odds of survival",
        p_value < 0.05 & estimate_logodds > 0 ~ "Significant positive temporal trend",
        p_value < 0.05 & estimate_logodds < 0 ~ "Significant negative temporal trend",
        TRUE ~ "No significant temporal trend"
      )
    )
  write_csv(temporal_trend_df, file.path(output_dir, "temporal_trend_glmm.csv"))
  cat("  Saved: temporal_trend_glmm.csv\n")

  # Store for downstream use
  trend_coef_glmm <- glmm_coef
  trend_p_glmm <- glmm_p

  # Test for nonlinear temporal trend
  # Use the same RE structure as the linear model for a valid LRT
  temporal_linear_re <- formula(temporal_glmm)
  re_terms <- findbars_safe(temporal_linear_re)
  re_string <- paste(sapply(re_terms, function(x) paste0("(", deparse(x), ")")), collapse = " + ")
  quad_formula <- as.formula(paste("survived ~ poly(survey_yr_centered, 2, raw = TRUE) +", re_string))

  temporal_quad <- tryCatch({
    glmer(
      quad_formula,
      data = surv_data,
      family = binomial,
      control = temporal_control
    )
  }, error = function(e) NULL)

  # Also refit linear model with same RE structure to guarantee matching
  linear_formula <- as.formula(paste("survived ~ survey_yr_centered +", re_string))
  temporal_linear_for_lrt <- tryCatch({
    glmer(
      linear_formula,
      data = surv_data,
      family = binomial,
      control = temporal_control
    )
  }, error = function(e) temporal_glmm)

  if (!is.null(temporal_quad)) {
    lrt_result <- tryCatch(anova(temporal_linear_for_lrt, temporal_quad), error = function(e) NULL)
    nonlinear_p <- if (!is.null(lrt_result)) lrt_result$`Pr(>Chisq)`[2] else NA
    if (!is.na(nonlinear_p)) {
      cat(sprintf("  Nonlinear trend test (LRT): p = %.4f\n", nonlinear_p))
    }
    # Save nonlinear trend LRT
    nonlinearity_test <- data.frame(
      linear_aic = AIC(temporal_glmm),
      quadratic_aic = AIC(temporal_quad),
      lrt_chisq = if (!is.null(lrt_result) && length(lrt_result$Chisq) >= 2) lrt_result$Chisq[2] else NA,
      lrt_df = if (!is.null(lrt_result) && "Df" %in% names(lrt_result) && length(lrt_result$Df) >= 2) lrt_result$Df[2] else NA,
      lrt_p = nonlinear_p
    )
    write_csv(nonlinearity_test, file.path(output_dir, "temporal_nonlinearity_test.csv"))
    cat("  Saved: temporal_nonlinearity_test.csv\n")
  }
}

# Keep aggregated analysis for visualization but note its limitations
cat("\nAggregated trend (for visualization only - subject to ecological fallacy):\n")

if (nrow(yearly_survival) >= 5) {
  trend_model <- lm(survival_rate ~ survey_yr, data = yearly_survival,
                    weights = yearly_survival$n)
  trend_coef <- coef(trend_model)[2]
  trend_p <- summary(trend_model)$coefficients[2, 4]

  cat(sprintf("  Aggregated trend: %.4f per year (p = %.3f)\n",
              trend_coef, trend_p))
  cat("  NOTE: This aggregated estimate is subject to ecological fallacy.\n")
  cat("  Use the GLMM estimate above for inference.\n")

  # Add to yearly data for plotting
  yearly_survival$trend_predicted <- predict(trend_model)

  # If GLMM was successful, store GLMM estimates separately for downstream reporting
  # NOTE: GLMM coefficient is on LOG-ODDS scale, NOT probability scale
  # The WLS trend_coef above is on probability scale (change per year)
  # We store both and label clearly; do NOT overwrite trend_p (WLS p-value)
  if (exists("trend_coef_glmm")) {
    trend_coef_logodds <- trend_coef_glmm
    trend_p_report <- trend_p_glmm
    cat(sprintf("  Using GLMM estimate for reporting (log-odds scale: %.4f, p = %.4f)\n",
                trend_coef_logodds, trend_p_report))
  } else {
    trend_coef_logodds <- NA
    trend_p_report <- NA
  }
}

# =============================================================================
# 3. TEMPORAL CONFOUNDING TEST
# =============================================================================

print_subheader("Temporal Confounding Test")

cat("  Testing whether survey_yr effect is confounded with study cohort timing...\n")

# Add study_start_year if not present
if (!"study_start_year" %in% names(surv_data)) {
  surv_data <- surv_data %>%
    group_by(study) %>%
    mutate(study_start_year = min(survey_yr, na.rm = TRUE)) %>%
    ungroup()
}

study_start_year_center <- mean(surv_data$study_start_year, na.rm = TRUE)
surv_data <- surv_data %>%
  mutate(
    study_start_year_centered = study_start_year - study_start_year_center
  )

m_year <- tryCatch({
  glmer(
    survived ~ survey_yr_centered + (1 | study),
    data = surv_data,
    family = binomial,
    control = temporal_control
  )
}, error = function(e) NULL)

m_year_cohort <- tryCatch({
  glmer(
    survived ~ survey_yr_centered + study_start_year_centered + (1 | study),
    data = surv_data,
    family = binomial,
    control = temporal_control
  )
}, error = function(e) NULL)

if (!is.null(m_year) && !is.null(m_year_cohort)) {
  lrt <- anova(m_year, m_year_cohort)
  lrt_p <- lrt$`Pr(>Chisq)`[2]

  cat(sprintf("  Model 1 (survey_yr only):       AIC = %.1f\n", AIC(m_year)))
  cat(sprintf("  Model 2 (+ study_start_year):   AIC = %.1f\n", AIC(m_year_cohort)))
  cat(sprintf("  LRT p-value: %.4f\n", lrt_p))

  if (!is.na(lrt_p) && lrt_p < 0.05) {
    cat("  -> Study cohort timing significantly contributes beyond year effect.\n")
    cat("  -> Temporal trend may be confounded with which studies were active.\n")
  } else {
    cat("  -> No evidence of study-cohort confounding.\n")
  }

  confound_results <- data.frame(
    model = c("survey_yr_only", "survey_yr_plus_cohort"),
    aic = c(AIC(m_year), AIC(m_year_cohort)),
    lrt_p = c(NA, lrt_p),
    survey_year_center = c(survey_year_center, survey_year_center),
    study_start_year_center = c(study_start_year_center, study_start_year_center)
  )
  write_csv(confound_results, file.path(output_dir, "temporal_confounding_test.csv"))
  cat("  Saved: temporal_confounding_test.csv\n")
} else {
  cat("  Could not fit temporal confounding models.\n")
}

# =============================================================================
# 5. REGIONAL CLIMATE SENSITIVITY
# =============================================================================

cat("\nAnalyzing regional climate sensitivity...\n")

# Calculate survival coefficient of variation by region (proxy for climate sensitivity)
regional_variability <- surv_data %>%
  group_by(region, survey_yr) %>%
  summarise(
    n = n(),
    survival_rate = mean(survived),
    .groups = "drop"
  ) %>%
  filter(n >= 10) %>%
  group_by(region) %>%
  summarise(
    n_years = n(),
    mean_survival = mean(survival_rate),
    sd_survival = sd(survival_rate),
    cv_survival = sd_survival / mean_survival,
    min_survival = min(survival_rate),
    max_survival = max(survival_rate),
    survival_range = max_survival - min_survival,
    total_n = sum(n),
    .groups = "drop"
  ) %>%
  filter(n_years >= 3) %>%
  arrange(desc(cv_survival))

cat("\nRegional survival variability (CV = climate sensitivity proxy):\n")
print(as.data.frame(regional_variability %>%
                      select(region, n_years, mean_survival, cv_survival, survival_range)))

write_csv(regional_variability, file.path(output_dir, "regional_temporal_variability.csv"))
cat("  Saved: regional_temporal_variability.csv\n")

# =============================================================================
# 6. SIZE-DEPENDENT CLIMATE VULNERABILITY
# =============================================================================

cat("\nAnalyzing size-dependent climate vulnerability...\n")

# Calculate survival variability by size class over time
size_climate_vulnerability <- surv_data %>%
  group_by(size_class, survey_yr) %>%
  summarise(
    n = n(),
    survival_rate = mean(survived),
    .groups = "drop"
  ) %>%
  filter(n >= 10) %>%
  group_by(size_class) %>%
  summarise(
    n_years = n(),
    mean_survival = mean(survival_rate),
    sd_survival = sd(survival_rate),
    cv_survival = sd_survival / mean_survival,
    min_survival = min(survival_rate),
    max_survival = max(survival_rate),
    .groups = "drop"
  ) %>%
  arrange(size_class)

cat("\nSize class climate vulnerability:\n")
print(as.data.frame(size_climate_vulnerability))

write_csv(size_climate_vulnerability, file.path(output_dir, "size_climate_vulnerability.csv"))
cat("  Saved: size_climate_vulnerability.csv\n")

# =============================================================================
# 7. BLEACHING YEAR DETECTION
# =============================================================================

cat("\nIdentifying potential bleaching years...\n")

# Look for years with anomalously low survival
if (nrow(yearly_survival) >= 5) {
  mean_surv <- mean(yearly_survival$survival_rate)
  sd_surv <- sd(yearly_survival$survival_rate)

  bleaching_years <- yearly_survival %>%
    mutate(
      z_score = (survival_rate - mean_surv) / sd_surv,
      anomaly = case_when(
        z_score < -1.5 ~ "Severe mortality",
        z_score < -1 ~ "Elevated mortality",
        z_score > 1 ~ "Above average",
        TRUE ~ "Normal"
      )
    ) %>%
    filter(z_score < -1)

  if (nrow(bleaching_years) > 0) {
    cat("\nYears with elevated mortality (z < -1):\n")
    print(as.data.frame(bleaching_years %>%
                          select(survey_yr, survival_rate, z_score, n, n_studies)))
  } else {
    cat("  No years with significantly elevated mortality detected.\n")
  }
}

# =============================================================================
# 8. COMPILE CLIMATE EFFECTS SUMMARY
# =============================================================================

cat("\nCompiling climate effects summary...\n")

climate_effects <- list(
  temporal_trend = if (exists("trend_coef")) {
    data.frame(
      effect = c("Temporal trend (WLS, probability scale)",
                 "Temporal trend (GLMM, log-odds scale)"),
      coefficient = c(trend_coef,
                      if (exists("trend_coef_logodds")) trend_coef_logodds else NA),
      p_value = c(summary(trend_model)$coefficients[2, 4],
                   if (exists("trend_p_report")) trend_p_report else NA),
      interpretation = c(
        sprintf("WLS: %.4f change in survival per year (probability scale)", trend_coef),
        ifelse(!is.na(if (exists("trend_p_report")) trend_p_report else NA) &&
               (if (exists("trend_p_report")) trend_p_report else 1) < 0.05,
               "GLMM: Significant temporal trend detected (log-odds scale)",
               "GLMM: No significant temporal trend (log-odds scale)")
      )
    )
  } else {
    data.frame(effect = "Temporal trend", coefficient = NA, p_value = NA,
               interpretation = "Insufficient data")
  },

  disturbance_impact = if (has_disturbance && nrow(disturbance_survival) > 1) {
    baseline <- disturbance_survival$survival_rate[disturbance_survival$disturbance_cat == "None recorded"]
    if (length(baseline) > 0) {
      disturbance_survival %>%
        filter(disturbance_cat != "None recorded") %>%
        mutate(
          effect = paste0("Disturbance: ", disturbance_cat),
          coefficient = survival_rate - baseline,
          p_value = NA,
          interpretation = sprintf("%.1f%% change vs baseline", (survival_rate - baseline) * 100)
        ) %>%
        select(effect, coefficient, p_value, interpretation)
    } else {
      data.frame(effect = "Disturbance", coefficient = NA, p_value = NA,
                 interpretation = "No baseline available")
    }
  } else {
    data.frame(effect = "Disturbance", coefficient = NA, p_value = NA,
               interpretation = "No disturbance data")
  },

  dhw_effect = if (!is.null(dhw_glmm_results) && any(dhw_glmm_results$term == "max_dhw")) {
    dhw_row <- dhw_glmm_results %>% filter(term == "max_dhw")
    data.frame(
      effect = "DHW effect (GLMM)",
      coefficient = dhw_row$estimate_logodds[1],
      p_value = dhw_row$p_value[1],
      interpretation = sprintf(
        "OR %.3f (95%% CI %.3f-%.3f) from %d DHW-supported rows; support=%s; file=%s",
        dhw_row$odds_ratio[1],
        dhw_row$or_ci_lower[1],
        dhw_row$or_ci_upper[1],
        dhw_row$n_obs[1],
        dhw_row$inference_support[1],
        dhw_row$dhw_file[1]
      )
    )
  } else {
    data.frame(
      effect = "DHW effect (GLMM)",
      coefficient = NA,
      p_value = NA,
      interpretation = sprintf(
        "Not estimated or too sparse; %d survival rows with DHW support (%s)",
        dhw_coverage$n_survival_rows_with_dhw[1],
        dhw_coverage$inference_support[1]
      )
    )
  },

  most_vulnerable_size = data.frame(
    effect = "Most climate-vulnerable size class",
    coefficient = NA,
    p_value = NA,
    interpretation = if (nrow(size_climate_vulnerability) > 0) {
      most_vuln <- size_climate_vulnerability$size_class[which.max(size_climate_vulnerability$cv_survival)]
      sprintf("%s (CV = %.2f)", most_vuln,
              max(size_climate_vulnerability$cv_survival, na.rm = TRUE))
    } else {
      "Insufficient data"
    }
  ),

  most_variable_region = data.frame(
    effect = "Most climate-variable region",
    coefficient = NA,
    p_value = NA,
    interpretation = if (nrow(regional_variability) > 0) {
      most_var <- regional_variability$region[which.max(regional_variability$cv_survival)]
      sprintf("%s (CV = %.2f)", most_var,
              max(regional_variability$cv_survival, na.rm = TRUE))
    } else {
      "Insufficient data"
    }
  )
)

climate_effects_df <- bind_rows(climate_effects)

write_csv(climate_effects_df, file.path(output_dir, "climate_survival_effects.csv"))
cat("  ✓ Saved: climate_survival_effects.csv\n")

# =============================================================================
# 9. CREATE CLIMATE-DEMOGRAPHY FIGURE
# =============================================================================

cat("\nCreating climate-demography visualization...\n")

# Set up multi-panel figure
png(file.path(fig_dir, "climate_demography.png"),
    width = 14, height = 10, units = "in", res = 300)

par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))

# Panel A: Temporal survival trend
if (nrow(yearly_survival) >= 3) {
  plot(yearly_survival$survey_yr, yearly_survival$survival_rate,
       pch = 16, col = "steelblue", cex = sqrt(yearly_survival$n) / 10,
       xlim = range(yearly_survival$survey_yr),
       ylim = c(0, 1),
       xlab = "Year", ylab = "Annual survival rate",
       main = "A. Temporal Survival Trend",
       las = 1)

  # Add error bars
  arrows(yearly_survival$survey_yr,
         pmax(0, yearly_survival$survival_rate - 1.96 * yearly_survival$se),
         yearly_survival$survey_yr,
         pmin(1, yearly_survival$survival_rate + 1.96 * yearly_survival$se),
         code = 3, angle = 90, length = 0.02, col = "gray60")

  # Add trend line if significant
  if (exists("trend_coef") && trend_p < 0.1) {
    abline(trend_model, col = "coral", lwd = 2, lty = 2)
    legend("bottomleft", legend = sprintf("Trend: %.3f/yr", trend_coef),
           col = "coral", lty = 2, lwd = 2, bty = "n")
  }

  # Add mean line
  abline(h = mean(yearly_survival$survival_rate), col = "gray50", lty = 3)
} else {
  plot(1, 1, type = "n", axes = FALSE, xlab = "", ylab = "", main = "A. Temporal Trend")
  text(1, 1, "Insufficient temporal data", cex = 1.2)
}

# Panel B: Disturbance effects
if (has_disturbance && nrow(disturbance_survival) > 1) {
  barplot(disturbance_survival$survival_rate,
          names.arg = disturbance_survival$disturbance_cat,
          col = c("seagreen", "coral", "steelblue", "goldenrod", "gray"),
          ylim = c(0, 1),
          las = 2,
          ylab = "Survival rate",
          main = "B. Disturbance Impacts")

  # Add error bars
  x_pos <- barplot(disturbance_survival$survival_rate, plot = FALSE)
  arrows(x_pos,
         pmax(0, disturbance_survival$survival_rate - 1.96 * disturbance_survival$se),
         x_pos,
         pmin(1, disturbance_survival$survival_rate + 1.96 * disturbance_survival$se),
         code = 3, angle = 90, length = 0.05)

  # Add sample sizes
  text(x_pos, 0.05, paste0("n=", disturbance_survival$n), cex = 0.7)
} else {
  plot(1, 1, type = "n", axes = FALSE, xlab = "", ylab = "", main = "B. Disturbance Impacts")
  text(1, 1, "No disturbance data available", cex = 1.2)
}

# Panel C: Size class vulnerability (CV)
if (nrow(size_climate_vulnerability) > 0 && any(!is.na(size_climate_vulnerability$cv_survival))) {
  bar_colors <- if (requireNamespace("RColorBrewer", quietly = TRUE)) {
    RColorBrewer::brewer.pal(5, "Blues")
  } else {
    c("#EFF3FF", "#BDD7E7", "#6BAED6", "#3182BD", "#08519C")
  }
  barplot(size_climate_vulnerability$cv_survival,
          names.arg = size_climate_vulnerability$size_class,
          col = bar_colors,
          ylim = c(0, max(size_climate_vulnerability$cv_survival, na.rm = TRUE) * 1.2),
          ylab = "Coefficient of Variation",
          main = "C. Climate Vulnerability by Size Class",
          las = 1)

  # Higher CV = more variable = potentially more climate sensitive
  abline(h = mean(size_climate_vulnerability$cv_survival, na.rm = TRUE),
         col = "red", lty = 2, lwd = 2)
  legend("topright", legend = "Mean CV", col = "red", lty = 2, lwd = 2, bty = "n")
} else {
  plot(1, 1, type = "n", axes = FALSE, xlab = "", ylab = "", main = "C. Size Class Vulnerability")
  text(1, 1, "Insufficient size class data", cex = 1.2)
}

# Panel D: Regional variability
if (nrow(regional_variability) > 0 && any(!is.na(regional_variability$cv_survival))) {
  # Order by CV
  regional_variability <- regional_variability %>%
    arrange(cv_survival) %>%
    mutate(region = factor(region, levels = region))

  barplot(regional_variability$cv_survival,
          names.arg = regional_variability$region,
          col = "steelblue",
          horiz = TRUE,
          las = 1,
          xlab = "Coefficient of Variation",
          main = "D. Regional Climate Sensitivity")

  # Higher CV = more interannual variability = potentially more climate sensitive
} else {
  plot(1, 1, type = "n", axes = FALSE, xlab = "", ylab = "", main = "D. Regional Variability")
  text(1, 1, "Insufficient regional data", cex = 1.2)
}

dev.off()
cat("  ✓ Saved: supplementary/exploratory/climate_demography.png\n")

# =============================================================================
# SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  CLIMATE-DEMOGRAPHY ANALYSIS COMPLETE                        ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("KEY FINDINGS:\n")

if (exists("trend_coef")) {
  cat(sprintf("  WLS temporal trend (probability scale): %.4f per year\n", trend_coef))
  if (exists("trend_coef_logodds") && !is.na(trend_coef_logodds)) {
    cat(sprintf("  GLMM temporal trend (log-odds scale): %.4f (p = %.3f)\n",
                trend_coef_logodds, if (exists("trend_p_report") && !is.na(trend_p_report)) trend_p_report else NA))
  }
  # Use GLMM p-value for significance reporting if available, otherwise WLS
  report_p <- if (exists("trend_p_report") && !is.na(trend_p_report)) trend_p_report else trend_p
  if (report_p < 0.05) {
    if (exists("trend_coef_logodds") && !is.na(trend_coef_logodds) && trend_coef_logodds < 0) {
      cat("    → Significant DECLINE in survival over time\n")
    } else if (exists("trend_coef_logodds") && !is.na(trend_coef_logodds) && trend_coef_logodds > 0) {
      cat("    → Significant INCREASE in survival over time\n")
    } else {
      cat("    → Significant temporal trend detected\n")
    }
  } else {
    cat("    → No significant temporal trend\n")
  }
}

if (has_disturbance && nrow(disturbance_survival) > 1) {
  cat("\n  Disturbance impacts:\n")
  for (i in 1:nrow(disturbance_survival)) {
    cat(sprintf("    %s: %.1f%% survival (n=%d)\n",
                disturbance_survival$disturbance_cat[i],
                disturbance_survival$survival_rate[i] * 100,
                disturbance_survival$n[i]))
  }
}

cat(sprintf("\n  DHW coverage: %d supported survival rows (%.1f%%), support=%s\n",
            dhw_coverage$n_survival_rows_with_dhw[1],
            dhw_coverage$pct_survival_rows_with_dhw[1],
            dhw_coverage$inference_support[1]))
if (!is.null(dhw_glmm_results) && any(dhw_glmm_results$term == "max_dhw")) {
  dhw_row <- dhw_glmm_results %>% filter(term == "max_dhw")
  cat(sprintf("    DHW GLMM OR = %.3f (95%% CI: %.3f - %.3f), p = %.4f\n",
              dhw_row$odds_ratio[1], dhw_row$or_ci_lower[1],
              dhw_row$or_ci_upper[1], dhw_row$p_value[1]))
}

if (nrow(size_climate_vulnerability) > 0) {
  most_vuln <- size_climate_vulnerability %>%
    filter(cv_survival == max(cv_survival, na.rm = TRUE))
  cat(sprintf("\n  Most climate-vulnerable size class: %s (CV=%.2f)\n",
              most_vuln$size_class, most_vuln$cv_survival))
}

cat("\nOutputs:\n")
cat("  - climate_survival_effects.csv\n")
cat("  - climate_dhw_coverage.csv\n")
cat("  - climate_dhw_glmm.csv\n")
cat("  - disturbance_impacts.csv\n")
cat("  - supplementary/exploratory/climate_demography.png\n")

cat("\nNOTE: DHW terms now use the maintained site-year overlay when available,\n")
cat("      but current support is still sparse and mostly literature-LUT backed.\n")
cat("      Treat DHW estimates as supportive climate context, not strong attribution.\n\n")
