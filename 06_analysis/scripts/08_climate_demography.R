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
#   1. Use regional annual mean SST anomalies as a proxy for thermal stress
#   2. Assess survival correlation with disturbance flags (MHW, storm, disease)
#   3. Calculate bleaching-corrected survival estimates
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
# NOTE: Full DHW integration would require external data (NOAA Coral Reef Watch).
#       This script uses available disturbance flags and temporal patterns.
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
# 2. TEMPORAL ANALYSIS (Yearly Survival Trends)
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

temporal_glmm <- tryCatch({
  glmer(survived ~ survey_yr + (1|study) + (1|region),
        data = surv_data, family = binomial)
}, error = function(e) {
  cat(sprintf("GLMM failed: %s. Trying simpler model.\n", e$message))
  tryCatch(
    glmer(survived ~ survey_yr + (1|study), data = surv_data, family = binomial),
    error = function(e2) NULL
  )
})

if (!is.null(temporal_glmm)) {
  glmm_coef <- fixef(temporal_glmm)["survey_yr"]
  glmm_se <- summary(temporal_glmm)$coefficients["survey_yr", "Std. Error"]
  glmm_z <- summary(temporal_glmm)$coefficients["survey_yr", "z value"]
  glmm_p <- summary(temporal_glmm)$coefficients["survey_yr", "Pr(>|z|)"]

  cat(sprintf("  Year effect (log-odds): %.4f (SE: %.4f)\n", glmm_coef, glmm_se))
  cat(sprintf("  Odds ratio per year: %.4f\n", exp(glmm_coef)))
  cat(sprintf("  z = %.3f, p = %.4f\n", glmm_z, glmm_p))

  # Overdispersion check (fixed + random effect parameters)
  pearson_resid <- residuals(temporal_glmm, type = "pearson")
  n_par <- length(fixef(temporal_glmm)) + sum(sapply(VarCorr(temporal_glmm), function(x) prod(dim(x))))
  overdisp_ratio <- sum(pearson_resid^2) / (length(pearson_resid) - n_par)
  cat(sprintf("  Overdispersion ratio: %.3f %s\n", overdisp_ratio, if(overdisp_ratio > 1.5) "(WARNING: potential overdispersion)" else "(OK)"))

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
      odds_ratio = exp(estimate_logodds),
      or_ci_lower = exp(estimate_logodds - 1.96 * std_error),
      or_ci_upper = exp(estimate_logodds + 1.96 * std_error),
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
  re_terms <- lme4::findbars(temporal_linear_re)
  re_string <- paste(sapply(re_terms, function(x) paste0("(", deparse(x), ")")), collapse = " + ")
  quad_formula <- as.formula(paste("survived ~ poly(survey_yr, 2) +", re_string))

  temporal_quad <- tryCatch({
    glmer(quad_formula, data = surv_data, family = binomial)
  }, error = function(e) NULL)

  # Also refit linear model with same RE structure to guarantee matching
  linear_formula <- as.formula(paste("survived ~ survey_yr +", re_string))
  temporal_linear_for_lrt <- tryCatch({
    glmer(linear_formula, data = surv_data, family = binomial)
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
# 3. DEGREE HEATING WEEKS (DHW) INTEGRATION
# =============================================================================

print_subheader("DHW/SST Integration")

dhw_file <- file.path(project_root, "05_data/original", "noaa_dhw_caribbean.csv")

if (file.exists(dhw_file)) {
  cat("  Loading NOAA Coral Reef Watch DHW data...\n")
  dhw_data <- read_csv(dhw_file, show_col_types = FALSE)

  surv_with_dhw <- surv_data %>%
    left_join(dhw_data, by = c("region", "survey_yr" = "year"))

  n_matched <- sum(!is.na(surv_with_dhw$dhw_max))
  cat(sprintf("  Matched %d/%d records (%.1f%%) with DHW data\n",
              n_matched, nrow(surv_with_dhw), n_matched / nrow(surv_with_dhw) * 100))

  if (n_matched > 100) {
    dhw_model <- tryCatch({
      glmer(survived ~ log_size + dhw_max + (1|study),
            data = surv_with_dhw %>% filter(!is.na(dhw_max)),
            family = binomial)
    }, error = function(e) {
      cat(sprintf("  DHW GLMM failed: %s\n", e$message))
      NULL
    })

    if (!is.null(dhw_model)) {
      cat("  DHW model results:\n")
      print(summary(dhw_model)$coefficients)

      dhw_results <- as.data.frame(summary(dhw_model)$coefficients)
      dhw_results$term <- rownames(dhw_results)
      write_csv(dhw_results, file.path(output_dir, "climate_dhw_model.csv"))
      cat("  Saved: climate_dhw_model.csv\n")
    }
  }
} else {
  cat("  DHW data not available at: ", dhw_file, "\n")
  cat("  To enable DHW integration:\n")
  cat("    1. Download from https://coralreefwatch.noaa.gov/product/vs/data.php\n")
  cat("    2. Format as CSV with columns: region, year, dhw_max, sst_mean\n")
  cat("    3. Save to: 05_data/original/noaa_dhw_caribbean.csv\n")
}

# =============================================================================
# 4. TEMPORAL CONFOUNDING TEST
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

m_year <- tryCatch({
  glmer(survived ~ survey_yr + (1|study), data = surv_data, family = binomial)
}, error = function(e) NULL)

m_year_cohort <- tryCatch({
  glmer(survived ~ survey_yr + study_start_year + (1|study),
        data = surv_data, family = binomial)
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
    lrt_p = c(NA, lrt_p)
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

if (nrow(size_climate_vulnerability) > 0) {
  most_vuln <- size_climate_vulnerability %>%
    filter(cv_survival == max(cv_survival, na.rm = TRUE))
  cat(sprintf("\n  Most climate-vulnerable size class: %s (CV=%.2f)\n",
              most_vuln$size_class, most_vuln$cv_survival))
}

cat("\nOutputs:\n")
cat("  - climate_survival_effects.csv\n")
cat("  - disturbance_impacts.csv\n")
cat("  - supplementary/exploratory/climate_demography.png\n")

cat("\nNOTE: Full DHW integration requires external NOAA Coral Reef Watch data.\n")
cat("      This analysis uses available disturbance flags and temporal patterns.\n\n")
