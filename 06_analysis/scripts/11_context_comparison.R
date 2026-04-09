################################################################################
# 11_context_comparison.R - Field vs Nursery vs Lab Context Comparison
################################################################################
#
# PURPOSE:
#   Compare demographic parameters across different study contexts to assess
#   transferability of nursery/lab results to field populations.
#
# METHODS:
#   1. Compare survival rates by context (field, nursery in-situ, nursery ex-situ, lab)
#   2. Compare growth rates by context
#   3. Size-dependent effects within each context
#   4. Statistical tests for context differences
#   5. Effect size calculations
#   6. Recommendations for parameter application
#
# OUTPUTS:
#   - context_survival_comparison.csv
#   - context_growth_comparison.csv
#   - context_effect_sizes.csv
#   - supplementary/exploratory/context_*.png
#
# Author: Detmer & Stier Lab
# Date: 2025-12-25
################################################################################

# ============================================================================
# IMPORTANT CAVEAT: Context (field/nursery) is nearly perfectly confounded with
# study identity, colony size, region, and era. The comparisons below are
# descriptive only and should NOT be interpreted as causal effects of context
# on survival or growth. Field data is dominated by NOAA large established
# colonies (mean ~4,500 cm²); nursery data is from small restoration fragments
# (mean ~64 cm²). See docs/Data_Methodology_Reference.md for study details.
#
# Statistical tests in this script (chi-squared, proportion tests, t-tests)
# treat observations as independent, which is invalid given I² = 97.8%
# study-level clustering. P-values are anti-conservative and should be treated
# as descriptive summaries, not confirmatory hypothesis tests.
# ============================================================================

library(dplyr)
library(tidyr)
library(ggplot2)
library(purrr)

# Source shared utilities for constants and helper functions
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

dirs <- setup_output_dirs()
output_dir <- dirs$output
data_dir <- file.path(get_project_root(), "05_data/standardized")
fig_explore_dir <- dirs$figures_exp

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  15: CONTEXT COMPARISON ANALYSIS                             ║\n")
cat("║  Field vs Nursery vs Lab Demographics                        ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# =============================================================================
# SETUP
# =============================================================================

# Load prepared data
cat("Loading prepared data...\n")
survival_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

# Also load raw summary data which may have additional contexts
cat("Loading raw summary data for context diversity...\n")
surv_summ <- tryCatch({
  read.csv(file.path(data_dir, "apal_surv_summ.csv"))
}, error = function(e) NULL)

# METHODOLOGICAL NOTE: All data aggregated to study-level summaries before
# statistical testing. This prevents mixing binary (0/1) individual records
# with pre-computed proportions, which would invalidate chi-squared tests
# and inflate effective sample sizes for summary-only studies.

# Ensure individual data has is_summary flag
if (!"is_summary" %in% names(survival_data)) {
  survival_data$is_summary <- FALSE
  survival_data$summary_n <- 1L
}

# Integrate summary data contexts if available
# NOTE: Summary records are kept SEPARATE and only merged at study-level
# aggregation below. We do NOT bind_rows() proportions with binary data.
summary_nursery_lab <- NULL
if (!is.null(surv_summ) && nrow(surv_summ) > 0) {
  nursery_lab <- surv_summ %>%
    filter(data_type %in% c("nursery", "lab")) %>%
    filter(!is.na(prop_survived)) %>%
    mutate(
      size_cm2 = ifelse(!is.na(size_cm2_mean), size_cm2_mean, 25),
      survived = prop_survived,  # Proportion (0-1), NOT binary
      is_summary = TRUE,
      summary_n = ifelse(!is.na(n_initial), n_initial, 1)
    ) %>%
    filter(!is.na(size_cm2))

  if (nrow(nursery_lab) > 0) {
    summary_nursery_lab <- nursery_lab %>%
      select(study, region, location, survey_yr, data_type, size_cm2, survived,
             is_summary, summary_n)
    cat(sprintf("  Found %d nursery/lab summary records (will aggregate at study level)\n", nrow(summary_nursery_lab)))
  }
}

# CORRECTED APPROACH: Aggregate all data to study-level summaries before testing
# This avoids mixing binary individual data with pre-computed proportions

# Standardize data_type classifications
standardize_context <- function(data) {
  data %>%
    mutate(
      context = case_when(
        grepl("field|wild|natural", data_type, ignore.case = TRUE) ~ "field",
        grepl("nursery.*in|in.*situ", data_type, ignore.case = TRUE) ~ "nursery_insitu",
        grepl("nursery.*ex|ex.*situ|outplant", data_type, ignore.case = TRUE) ~ "nursery_exsitu",
        grepl("lab|aquarium|tank", data_type, ignore.case = TRUE) ~ "lab",
        data_type == "nursery_in" ~ "nursery_insitu",
        data_type == "nursery_ex" ~ "nursery_exsitu",
        TRUE ~ "field"  # Default to field if unclear
      ),
      context = factor(context, levels = c("field", "nursery_insitu", "nursery_exsitu", "lab"))
    )
}

# Add size classes
add_size_class <- function(data) {
  data %>%
    mutate(
      size_class = case_when(
        size_cm2 <= 25 ~ "SC1",
        size_cm2 <= 100 ~ "SC2",
        size_cm2 <= 500 ~ "SC3",
        size_cm2 <= 2000 ~ "SC4",
        TRUE ~ "SC5"
      ),
      size_class = factor(size_class, levels = c("SC1", "SC2",
                                                  "SC3", "SC4",
                                                  "SC5"))
    )
}

survival_data <- standardize_context(survival_data)
growth_data <- standardize_context(growth_data)
survival_data <- add_size_class(survival_data)
growth_data <- add_size_class(growth_data)

# Also standardize summary nursery/lab records if available
if (!is.null(summary_nursery_lab)) {
  summary_nursery_lab <- standardize_context(summary_nursery_lab)
  summary_nursery_lab <- add_size_class(summary_nursery_lab)
}

# ─────────────────────────────────────────────────────────────────────────────
# STUDY-LEVEL AGGREGATION: Properly handle mixed data types
# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Aggregate individual records to study level
individual_summaries <- survival_data %>%
  filter(is.na(is_summary) | !is_summary) %>%
  group_by(study, context, region) %>%
  summarise(
    n = n(),
    n_survived = sum(survived, na.rm = TRUE),
    survival = mean(survived, na.rm = TRUE),
    se = sqrt(survival * (1 - survival) / pmax(n, 1)),
    mean_size = mean(size_cm2, na.rm = TRUE),
    .groups = "drop"
  )

# Step 2: Include pre-existing summary records (already study-level)
if (!is.null(summary_nursery_lab) && nrow(summary_nursery_lab) > 0) {
  summary_records <- summary_nursery_lab %>%
    group_by(study, context, region) %>%
    summarise(
      n = sum(summary_n, na.rm = TRUE),
      n_survived = round(weighted.mean(survived, summary_n, na.rm = TRUE) * sum(summary_n)),
      survival = weighted.mean(survived, summary_n, na.rm = TRUE),
      se = sqrt(survival * (1 - survival) / pmax(n, 1)),
      mean_size = weighted.mean(size_cm2, summary_n, na.rm = TRUE),
      .groups = "drop"
    )
  study_summaries <- bind_rows(individual_summaries, summary_records)
} else {
  study_summaries <- individual_summaries
}

cat(sprintf("  Study-level summaries: %d studies across %d contexts\n",
            nrow(study_summaries), n_distinct(study_summaries$context)))

# Also create study-level summaries by size class for section 2
individual_summaries_by_size <- survival_data %>%
  filter(is.na(is_summary) | !is_summary) %>%
  group_by(study, context, region, size_class) %>%
  summarise(
    n = n(),
    n_survived = sum(survived, na.rm = TRUE),
    survival = mean(survived, na.rm = TRUE),
    se = sqrt(survival * (1 - survival) / pmax(n, 1)),
    mean_size = mean(size_cm2, na.rm = TRUE),
    .groups = "drop"
  )

if (!is.null(summary_nursery_lab) && nrow(summary_nursery_lab) > 0) {
  summary_records_by_size <- summary_nursery_lab %>%
    group_by(study, context, region, size_class) %>%
    summarise(
      n = sum(summary_n, na.rm = TRUE),
      n_survived = round(weighted.mean(survived, summary_n, na.rm = TRUE) * sum(summary_n)),
      survival = weighted.mean(survived, summary_n, na.rm = TRUE),
      se = sqrt(survival * (1 - survival) / pmax(n, 1)),
      mean_size = weighted.mean(size_cm2, summary_n, na.rm = TRUE),
      .groups = "drop"
    )
  study_summaries_by_size <- bind_rows(individual_summaries_by_size, summary_records_by_size)
} else {
  study_summaries_by_size <- individual_summaries_by_size
}

cat("\nContext distribution (study-level summaries):\n")
cat("  SURVIVAL:\n")
print(table(study_summaries$context))
cat("\n  GROWTH:\n")
print(table(growth_data$context))

# =============================================================================
# 1. OVERALL SURVIVAL BY CONTEXT
# =============================================================================

cat("\n1. Survival Rates by Context...\n")

# Context comparison using raw aggregation (sum survived / sum total)
# This is more appropriate than inverse-variance weighting, which produces
# near-1.0 SE values when some study SEs are very small
survival_by_context <- study_summaries %>%
  group_by(context) %>%
  summarise(
    n_studies = n(),
    total_n = sum(n),
    total_survived = sum(n_survived),
    # Raw aggregation: sum(survived) / sum(total)
    weighted_survival = sum(n_survived) / sum(n),
    # SE based on total pooled counts
    se_survival = sqrt(weighted_survival * (1 - weighted_survival) / sum(n)),
    ci_lower = pmax(0, weighted_survival - 1.96 * se_survival),
    ci_upper = pmin(1, weighted_survival + 1.96 * se_survival),
    median_size = median(mean_size, na.rm = TRUE),
    mean_size = mean(mean_size, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  select(-total_survived) %>%
  rename(n = total_n, mean_survival = weighted_survival)

cat("\nOverall survival by context:\n")
print(survival_by_context)

# =============================================================================
# 2. SURVIVAL BY CONTEXT AND SIZE CLASS
# =============================================================================

cat("\n2. Survival by Context and Size Class...\n")

survival_context_size <- study_summaries_by_size %>%
  group_by(context, size_class) %>%
  summarise(
    mean_survival = weighted.mean(survival, w = n, na.rm = TRUE),
    n = sum(n),
    .groups = "drop"
  ) %>%
  mutate(
    se_survival = sqrt(mean_survival * (1 - mean_survival) / pmax(n, 1))
  ) %>%
  filter(n >= 5)  # Minimum sample size

cat("\nSurvival by context and size class:\n")
print(survival_context_size %>% pivot_wider(names_from = size_class, values_from = c(mean_survival, n)))

# =============================================================================
# 3. GROWTH RATES BY CONTEXT
# =============================================================================

cat("\n3. Growth Rates by Context...\n")

growth_by_context <- growth_data %>%
  group_by(context) %>%
  summarise(
    n = n(),
    n_studies = n_distinct(study),
    mean_growth = mean(growth_cm2_yr, na.rm = TRUE),
    se_growth = sd(growth_cm2_yr, na.rm = TRUE) / sqrt(n()),
    median_growth = median(growth_cm2_yr, na.rm = TRUE),
    pct_positive = mean(growth_cm2_yr > 0, na.rm = TRUE) * 100,
    mean_size = mean(size_cm2, na.rm = TRUE),
    .groups = "drop"
  )

cat("\nGrowth rates by context:\n")
print(growth_by_context)

# =============================================================================
# 4. STATISTICAL TESTS FOR CONTEXT DIFFERENCES
# =============================================================================

cat("\n4. Statistical Tests for Context Differences...\n")

# Use study-level aggregated counts for chi-squared test (not mixed raw data)
contexts <- unique(study_summaries$context)

if (length(unique(study_summaries$context)) > 1) {
  # Aggregate counts per context for chi-squared test
  context_counts <- study_summaries %>%
    group_by(context) %>%
    summarise(
      total_survived = sum(n_survived),
      total_n = sum(n),
      .groups = "drop"
    ) %>%
    mutate(total_died = total_n - total_survived)

  surv_table <- matrix(
    c(context_counts$total_survived, context_counts$total_died),
    nrow = nrow(context_counts), ncol = 2,
    dimnames = list(as.character(context_counts$context), c("survived", "died"))
  )
  chisq_result <- chisq.test(surv_table)

  cat("\n  Chi-square test for survival by context (study-aggregated counts):\n")
  cat(sprintf("    X² = %.2f, df = %d, p = %.4f\n",
              chisq_result$statistic, chisq_result$parameter, chisq_result$p.value))
  cat("    NOTE: This test treats observations as independent. Given study-level\n")
  cat("    clustering (I² = 97.8%), these p-values may be anti-conservative.\n")
  cat("    Interpret as descriptive, not confirmatory.\n")

  # Save omnibus chi-squared test
  context_omnibus_test <- data.frame(
    x_squared = as.numeric(chisq_result$statistic),
    df = as.numeric(chisq_result$parameter),
    p_value = chisq_result$p.value
  )
  write.csv(context_omnibus_test, file.path(output_dir, "context_omnibus_test.csv"), row.names = FALSE)
  cat("  Saved: context_omnibus_test.csv\n")
}

# Pairwise comparisons for survival using study-level aggregated counts
pairwise_survival <- data.frame()
if (length(contexts) >= 2) {
  pairwise_survival <- map_dfr(combn(contexts, 2, simplify = FALSE), function(pair) {
    data1 <- study_summaries %>% filter(context == pair[1])
    data2 <- study_summaries %>% filter(context == pair[2])

    n1_total <- sum(data1$n)
    n2_total <- sum(data2$n)
    survived1_total <- sum(data1$n_survived)
    survived2_total <- sum(data2$n_survived)

    if (n1_total >= 10 && n2_total >= 10) {
      # NOTE: prop.test assumes independent observations
      # With study-level clustering, effective sample sizes are smaller
      prop_test <- prop.test(
        c(survived1_total, survived2_total),
        c(n1_total, n2_total)
      )

      # Effect size (Cohen's h)
      p1 <- survived1_total / n1_total
      p2 <- survived2_total / n2_total
      cohens_h <- 2 * asin(sqrt(p1)) - 2 * asin(sqrt(p2))

      data.frame(
        context1 = pair[1],
        context2 = pair[2],
        survival1 = p1,
        survival2 = p2,
        difference = p1 - p2,
        chi_sq = prop_test$statistic,
        p_value = prop_test$p.value,
        cohens_h = cohens_h,
        effect_size = case_when(
          abs(cohens_h) < 0.2 ~ "negligible",
          abs(cohens_h) < 0.5 ~ "small",
          abs(cohens_h) < 0.8 ~ "medium",
          TRUE ~ "large"
        )
      )
    } else {
      NULL
    }
  })
} else {
  cat("  Only one context available - skipping pairwise comparisons\n")
}

if (nrow(pairwise_survival) > 0) {
  # Adjust for multiple comparisons
  pairwise_survival <- pairwise_survival %>%
    mutate(p_adjusted = p.adjust(p_value, method = "holm"))

  cat("\n  Pairwise survival comparisons:\n")
  print(pairwise_survival %>% select(context1, context2, survival1, survival2,
                                      difference, p_adjusted, effect_size))
}

# T-tests for growth (growth data is individual-level only, no mixing issue)
pairwise_growth <- data.frame()
if (length(contexts) >= 2) {
  pairwise_growth <- map_dfr(combn(contexts, 2, simplify = FALSE), function(pair) {
    data1 <- growth_data %>% filter(context == pair[1])
    data2 <- growth_data %>% filter(context == pair[2])

    if (nrow(data1) >= 10 && nrow(data2) >= 10) {
      t_result <- t.test(data1$growth_cm2_yr, data2$growth_cm2_yr)

      # Effect size (Cohen's d)
      pooled_sd <- sqrt(((nrow(data1)-1)*var(data1$growth_cm2_yr, na.rm=TRUE) +
                         (nrow(data2)-1)*var(data2$growth_cm2_yr, na.rm=TRUE)) /
                        (nrow(data1) + nrow(data2) - 2))
      cohens_d <- (mean(data1$growth_cm2_yr, na.rm=TRUE) -
                   mean(data2$growth_cm2_yr, na.rm=TRUE)) / pooled_sd

      data.frame(
        context1 = pair[1],
        context2 = pair[2],
        growth1 = mean(data1$growth_cm2_yr, na.rm = TRUE),
        growth2 = mean(data2$growth_cm2_yr, na.rm = TRUE),
        difference = mean(data1$growth_cm2_yr, na.rm = TRUE) -
                     mean(data2$growth_cm2_yr, na.rm = TRUE),
        t_stat = t_result$statistic,
        p_value = t_result$p.value,
        cohens_d = cohens_d,
        effect_size = case_when(
          abs(cohens_d) < 0.2 ~ "negligible",
          abs(cohens_d) < 0.5 ~ "small",
          abs(cohens_d) < 0.8 ~ "medium",
          TRUE ~ "large"
        )
      )
    } else {
      NULL
    }
  })
}

if (nrow(pairwise_growth) > 0) {
  pairwise_growth <- pairwise_growth %>%
    mutate(p_adjusted = p.adjust(p_value, method = "holm"))

  cat("\n  Pairwise growth comparisons:\n")
  print(pairwise_growth %>% select(context1, context2, growth1, growth2,
                                    difference, p_adjusted, effect_size))
}

# =============================================================================
# 4B. SIZE-RESTRICTED COMPARISON (OVERLAP ZONE) WITH STUDY RANDOM EFFECT
# =============================================================================
#
# The pooled comparisons above are heavily confounded: field data skews to large
# colonies (mean ~4,500 cm²) while nursery data is small fragments (mean ~64 cm²).
# Here we restrict to the shared size overlap zone (~11-202 cm², i.e.
# ln(size) 2.40-5.31), which is the same overlap zone used in Figure 3
# (Natural vs Restored). This makes the comparison somewhat less confounded
# (still confounded by study/region/era, but at least size-matched).
#
# We also fit a GLMM with study random effect to partially account for
# clustering, though note that with very few studies per context, the random
# effect estimate will be unstable.
# =============================================================================

cat("\n4B. Size-Restricted Comparison (Overlap Zone with Study Random Effect)...\n")

# Use individual-level data only (not summary proportions)
individual_only_for_overlap <- survival_data %>%
  filter(is.na(is_summary) | !is_summary)

# Ensure log_size column exists (natural log, consistent with all other scripts)
if (!"log_size" %in% names(individual_only_for_overlap)) {
  individual_only_for_overlap$log_size <- log(individual_only_for_overlap$size_cm2)
}

# Define overlap zone: 11-202 cm² (natural log scale)
# This matches the overlap zone from Figure 3 (natural vs restored comparison)
overlap_lo <- log(11)   # ~2.40
overlap_hi <- log(202)  # ~5.31

overlap_data <- individual_only_for_overlap %>%
  filter(log_size >= overlap_lo, log_size <= overlap_hi)

cat(sprintf("  Overlap zone: %.0f-%.0f cm² (ln %.2f-%.2f)\n",
            exp(overlap_lo), exp(overlap_hi), overlap_lo, overlap_hi))
cat(sprintf("  Records in overlap zone: %d (out of %d total = %.1f%%)\n",
            nrow(overlap_data), nrow(individual_only_for_overlap),
            100 * nrow(overlap_data) / nrow(individual_only_for_overlap)))

# Context distribution in overlap zone
cat("\n  Context distribution in overlap zone:\n")
overlap_context_table <- overlap_data %>%
  group_by(context) %>%
  summarise(
    n = n(),
    n_studies = n_distinct(study),
    mean_size_cm2 = mean(size_cm2, na.rm = TRUE),
    survival = mean(survived, na.rm = TRUE),
    .groups = "drop"
  )
print(overlap_context_table)

# Size-matched descriptive comparison
if (nrow(overlap_data) > 50 && n_distinct(overlap_data$context) >= 2) {

  cat("\n  Size-matched descriptive comparison (overlap zone):\n")
  for (ctx in unique(overlap_data$context)) {
    ctx_data <- overlap_data %>% filter(context == ctx)
    cat(sprintf("    %s: survival = %.1f%%, mean size = %.0f cm², n = %d, k = %d studies\n",
                ctx,
                mean(ctx_data$survived, na.rm = TRUE) * 100,
                mean(ctx_data$size_cm2, na.rm = TRUE),
                nrow(ctx_data),
                n_distinct(ctx_data$study)))
  }

  # GLMM with study random effect
  cat("\n  GLMM: survived ~ context + log_size + (1|study)\n")
  cat("  NOTE: With few studies per context, random effect estimates are unstable.\n")
  cat("  This is an exploratory analysis only.\n")

  glmm_result <- tryCatch({
    m <- lme4::glmer(survived ~ context + log_size + (1|study),
                     family = binomial, data = overlap_data)

    # Overdispersion check
    pearson_resid <- residuals(m, type = "pearson")
    n_obs <- nrow(overlap_data)
    n_fixef <- length(lme4::fixef(m))
    overdispersion_ratio <- sum(pearson_resid^2) / (n_obs - n_fixef)

    cat(sprintf("\n  Overdispersion ratio: %.2f", overdispersion_ratio))
    if (overdispersion_ratio > 1.5) {
      cat(" *** WARNING: potential overdispersion ***\n")
    } else {
      cat(" (OK)\n")
    }

    cat("\n  Fixed effects (context adjusted for size + study clustering):\n")
    coef_table <- summary(m)$coefficients
    print(coef_table)

    cat("\n  Random effects:\n")
    print(lme4::VarCorr(m))

    cat("\n  INTERPRETATION CAVEAT: Even with size restriction and study random\n")
    cat("  effects, context remains confounded with region, era, methodology,\n")
    cat("  and colony origin. These results are descriptive associations, not\n")
    cat("  causal effects of field vs nursery setting.\n")

    m
  }, error = function(e) {
    cat(sprintf("\n  GLMM failed: %s\n", e$message))
    cat("  This is expected when few studies contribute to each context.\n")
    NULL
  })

  if (!is.null(glmm_result)) {
    overlap_conv_messages <- tryCatch(unlist(glmm_result@optinfo$conv$lme4$messages),
                                      error = function(e) character())
    overlap_conv_messages <- as.character(overlap_conv_messages)
    overlap_conv_messages <- overlap_conv_messages[nzchar(overlap_conv_messages)]

    overlap_glmm_diag <- data.frame(
      model = "context_overlap_zone_glmm",
      n_obs = nrow(overlap_data),
      n_studies = n_distinct(overlap_data$study),
      n_contexts = n_distinct(overlap_data$context),
      dispersion_ratio = overdispersion_ratio,
      overdispersed = overdispersion_ratio > 1.5,
      is_singular = tryCatch(lme4::isSingular(glmm_result, tol = 1e-4),
                             error = function(e) NA),
      convergence_ok = length(overlap_conv_messages) == 0,
      optimizer_messages = if (length(overlap_conv_messages) == 0) NA_character_
                           else paste(unique(overlap_conv_messages), collapse = " | "),
      stringsAsFactors = FALSE
    )
    write.csv(overlap_glmm_diag,
              file.path(output_dir, "context_overlap_zone_glmm_diagnostics.csv"),
              row.names = FALSE)
    cat("  Saved: context_overlap_zone_glmm_diagnostics.csv\n")
  }

  # Save overlap zone summary
  write.csv(overlap_context_table, file.path(output_dir, "context_overlap_zone_summary.csv"), row.names = FALSE)
  cat("  Saved: context_overlap_zone_summary.csv\n")

} else {
  cat("\n  Insufficient data in overlap zone for size-matched comparison.\n")
  cat(sprintf("  (need >50 records across >=2 contexts; have %d records, %d contexts)\n",
              nrow(overlap_data), n_distinct(overlap_data$context)))
}

# =============================================================================
# 5. SIZE-DEPENDENT EFFECTS WITHIN CONTEXT
# =============================================================================

cat("\n5. Size-Dependent Effects Within Each Context...\n")

# Size-dependent models: use individual records ONLY (not summary proportions)
# Summary records have pre-computed proportions that cannot be used as binary
# response in logistic regression
individual_only <- survival_data %>%
  filter(is.na(is_summary) | !is_summary)

context_models <- individual_only %>%
  group_by(context) %>%
  filter(n() >= 30) %>%  # Need sufficient data for model
  group_modify(~ {
    tryCatch({
      model <- glm(survived ~ log(size_cm2), data = .x, family = binomial)
      coefs <- summary(model)$coefficients

      data.frame(
        n = nrow(.x),
        intercept = coefs[1, 1],
        size_effect = coefs[2, 1],
        size_se = coefs[2, 2],
        size_p = coefs[2, 4],
        significant = coefs[2, 4] < 0.05
      )
    }, error = function(e) {
      data.frame(n = nrow(.x), intercept = NA, size_effect = NA,
                 size_se = NA, size_p = NA, significant = NA)
    })
  })

cat("\nSize-survival relationship by context:\n")
print(context_models)

# =============================================================================
# 6. EFFECT SIZE SUMMARY
# =============================================================================

cat("\n6. Compiling Effect Size Summary...\n")

effect_summary <- data.frame(
  comparison = c(
    "Field vs Nursery (in-situ)",
    "Field vs Nursery (ex-situ)",
    "Nursery in-situ vs ex-situ"
  ),
  parameter = "Survival",
  stringsAsFactors = FALSE
)

if (nrow(pairwise_survival) > 0) {
  # Match each specific comparison to the correct pairwise result
  comparison_patterns <- list(
    c("field", "nursery_insitu"),       # Field vs Nursery (in-situ)
    c("field", "nursery_exsitu"),       # Field vs Nursery (ex-situ)
    c("nursery_insitu", "nursery_exsitu")  # Nursery in-situ vs ex-situ
  )

  for (i in 1:min(nrow(effect_summary), length(comparison_patterns))) {
    pat <- comparison_patterns[[i]]
    match_row <- pairwise_survival %>%
      filter(
        (context1 == pat[1] & context2 == pat[2]) |
        (context1 == pat[2] & context2 == pat[1])
      )

    if (nrow(match_row) > 0) {
      effect_summary$cohens_h[i] <- match_row$cohens_h[1]
      effect_summary$effect_size[i] <- match_row$effect_size[1]
      effect_summary$p_value[i] <- match_row$p_adjusted[1]
    }
  }
}

# Save context effect sizes
write.csv(effect_summary, file.path(output_dir, "context_effect_sizes.csv"), row.names = FALSE)
cat("  Saved: context_effect_sizes.csv\n")

# =============================================================================
# 7. CONTEXT DIFFERENCES — EXPLORATORY DESCRIPTIVE SUMMARY
# =============================================================================
#
# IMPORTANT: The "transferability" framing below is retained for backward
# compatibility of the output CSV, but ALL labels must be understood as
# OBSERVATIONAL ASSOCIATIONS ONLY. Context is nearly perfectly confounded
# with study identity, colony size, region, and era. The percentage
# differences and adjustment factors describe raw data patterns, not causal
# effects of nursery vs field settings.
# =============================================================================

cat("\n7. Context Differences — Exploratory Descriptive Summary...\n")

cat("\n  WARNING: Context (field/nursery) is confounded with study identity,\n")
cat("  colony size, region, and era. The descriptive differences below\n")
cat("  should NOT be interpreted as causal effects. See Section 4B for\n")
cat("  a size-restricted comparison that partially addresses the size\n")
cat("  confound (but not study/region/era confounds).\n\n")

# Calculate field as reference
field_survival <- survival_by_context %>%
  filter(context == "field") %>%
  pull(mean_survival)

transferability <- survival_by_context %>%
  filter(context != "field") %>%
  mutate(
    difference_from_field = mean_survival - field_survival,
    pct_difference = difference_from_field / field_survival * 100,
    # Replace actionable labels with explicitly exploratory ones
    recommendation = case_when(
      abs(pct_difference) < 10 ~ "SMALL OBSERVED DIFFERENCE (exploratory)",
      abs(pct_difference) < 20 ~ "MODERATE OBSERVED DIFFERENCE (exploratory)",
      abs(pct_difference) < 30 ~ "LARGE OBSERVED DIFFERENCE (exploratory)",
      TRUE ~ "VERY LARGE OBSERVED DIFFERENCE (exploratory)"
    ),
    adjustment_factor = field_survival / mean_survival,
    caveat = "Observational association only — confounded with study identity, size, region, era"
  )

cat("\nExploratory context summary (NOT causal transferability):\n")
print(transferability %>% select(context, mean_survival, pct_difference, recommendation, adjustment_factor))

# =============================================================================
# SAVE OUTPUTS
# =============================================================================

cat("\nSaving context comparison outputs...\n")

write.csv(survival_by_context, file.path(output_dir, "context_survival_comparison.csv"), row.names = FALSE)
cat("  ✓ Saved: context_survival_comparison.csv\n")

write.csv(growth_by_context, file.path(output_dir, "context_growth_comparison.csv"), row.names = FALSE)
cat("  ✓ Saved: context_growth_comparison.csv\n")

write.csv(survival_context_size, file.path(output_dir, "context_survival_by_size.csv"), row.names = FALSE)
cat("  ✓ Saved: context_survival_by_size.csv\n")

if (nrow(pairwise_survival) > 0) {
  write.csv(pairwise_survival, file.path(output_dir, "context_pairwise_survival.csv"), row.names = FALSE)
  cat("  ✓ Saved: context_pairwise_survival.csv\n")
}

if (nrow(pairwise_growth) > 0) {
  write.csv(pairwise_growth, file.path(output_dir, "context_pairwise_growth.csv"), row.names = FALSE)
  cat("  ✓ Saved: context_pairwise_growth.csv\n")
}

write.csv(context_models, file.path(output_dir, "context_size_models.csv"), row.names = FALSE)
cat("  ✓ Saved: context_size_models.csv\n")

write.csv(transferability, file.path(output_dir, "context_transferability.csv"), row.names = FALSE)
cat("  ✓ Saved: context_transferability.csv\n")

# =============================================================================
# VISUALIZATIONS
# =============================================================================

cat("\nCreating context comparison visualizations...\n")

# Survival by context
p1 <- survival_by_context %>%
  ggplot(aes(x = context, y = mean_survival)) +
  geom_col(aes(fill = context), width = 0.7) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2) +
  geom_text(aes(label = sprintf("n=%d", n)), vjust = -0.5, size = 3) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  scale_fill_manual(values = c("field" = "#2ECC71", "nursery_insitu" = "#3498DB",
                                "nursery_exsitu" = "#9B59B6", "lab" = "#E74C3C")) +
  labs(
    title = "Survival Rates by Study Context",
    subtitle = "Mean annual survival with 95% CI",
    x = "Context",
    y = "Survival Probability",
    fill = "Context"
  ) +
  theme_minimal() +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave(file.path(fig_explore_dir, "context_survival.png"), p1,
       width = 8, height = 6, dpi = 150)
cat("  ✓ Saved: context_survival.png\n")

# Survival by context and size class
if (nrow(survival_context_size) > 0) {
  p2 <- survival_context_size %>%
    ggplot(aes(x = size_class, y = mean_survival, fill = context)) +
    geom_col(position = position_dodge(width = 0.8), width = 0.7) +
    geom_errorbar(aes(ymin = mean_survival - se_survival,
                      ymax = mean_survival + se_survival),
                  position = position_dodge(width = 0.8), width = 0.2) +
    scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
    scale_fill_manual(values = c("field" = "#2ECC71", "nursery_insitu" = "#3498DB",
                                  "nursery_exsitu" = "#9B59B6", "lab" = "#E74C3C")) +
    labs(
      title = "Survival by Context and Size Class",
      subtitle = "Comparing demographic parameters across study types",
      x = "Size Class",
      y = "Survival Probability",
      fill = "Context"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold"),
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "bottom"
    )

  ggsave(file.path(fig_explore_dir, "context_survival_by_size.png"), p2,
         width = 10, height = 6, dpi = 150)
  cat("  ✓ Saved: context_survival_by_size.png\n")
}

# Growth by context
if (nrow(growth_by_context) > 0) {
  p3 <- growth_by_context %>%
    ggplot(aes(x = context, y = mean_growth)) +
    geom_col(aes(fill = context), width = 0.7) +
    geom_errorbar(aes(ymin = mean_growth - se_growth,
                      ymax = mean_growth + se_growth), width = 0.2) +
    geom_text(aes(label = sprintf("n=%d", n)), vjust = -0.5, size = 3) +
    scale_fill_manual(values = c("field" = "#2ECC71", "nursery_insitu" = "#3498DB",
                                  "nursery_exsitu" = "#9B59B6", "lab" = "#E74C3C")) +
    labs(
      title = "Growth Rates by Study Context",
      subtitle = "Mean annual growth (cm²/yr) with 95% CI",
      x = "Context",
      y = "Growth Rate (cm²/yr)",
      fill = "Context"
    ) +
    theme_minimal() +
    theme(
      legend.position = "none",
      plot.title = element_text(face = "bold"),
      axis.text.x = element_text(angle = 45, hjust = 1)
    )

  ggsave(file.path(fig_explore_dir, "context_growth.png"), p3,
         width = 8, height = 6, dpi = 150)
  cat("  ✓ Saved: context_growth.png\n")
}

# Effect size visualization
if (nrow(pairwise_survival) > 0) {
  p4 <- pairwise_survival %>%
    mutate(comparison = paste(context1, "vs", context2)) %>%
    ggplot(aes(x = reorder(comparison, abs(cohens_h)), y = cohens_h)) +
    geom_col(aes(fill = effect_size), width = 0.7) +
    geom_hline(yintercept = c(-0.2, 0.2), linetype = "dashed", color = "gray50", alpha = 0.5) +
    geom_hline(yintercept = c(-0.5, 0.5), linetype = "dashed", color = "gray50", alpha = 0.5) +
    geom_hline(yintercept = 0, color = "black") +
    coord_flip() +
    scale_fill_manual(values = c("negligible" = "#95A5A6", "small" = "#F39C12",
                                  "medium" = "#E67E22", "large" = "#E74C3C")) +
    labs(
      title = "Effect Sizes for Context Comparisons",
      subtitle = "Cohen's h for survival differences (dashed lines at 0.2 and 0.5)",
      x = "",
      y = "Cohen's h",
      fill = "Effect Size"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold"),
      legend.position = "bottom"
    )

  ggsave(file.path(fig_explore_dir, "context_effect_sizes.png"), p4,
         width = 9, height = 5, dpi = 150)
  cat("  ✓ Saved: context_effect_sizes.png\n")
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  CONTEXT COMPARISON COMPLETE                                 ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("KEY FINDINGS:\n")
cat("─────────────────────────────────────────────────────────────────\n")

# Print survival by context
cat("\n  SURVIVAL BY CONTEXT:\n")
for (i in 1:nrow(survival_by_context)) {
  cat(sprintf("    %s: %.1f%% (n=%d)\n",
              survival_by_context$context[i],
              survival_by_context$mean_survival[i] * 100,
              survival_by_context$n[i]))
}

# Significant differences (with confounding caveat)
if (nrow(pairwise_survival) > 0) {
  sig_diffs <- pairwise_survival %>% filter(p_adjusted < 0.05)
  if (nrow(sig_diffs) > 0) {
    cat("\n  NOMINAL DIFFERENCES (p < 0.05, ignoring clustering — interpret with caution):\n")
    for (i in 1:nrow(sig_diffs)) {
      cat(sprintf("    %s vs %s: %.1f%% difference (Cohen's h = %.2f)\n",
                  sig_diffs$context1[i], sig_diffs$context2[i],
                  sig_diffs$difference[i] * 100, sig_diffs$cohens_h[i]))
    }
    cat("    CAVEAT: P-values ignore study clustering (I2=97.8%) and are anti-conservative.\n")
    cat("    Context is confounded with size, study, region — differences are not causal.\n")
  } else {
    cat("\n  No significant differences detected between contexts.\n")
  }
}

cat("\n  EXPLORATORY CONTEXT DIFFERENCES (not causal — see caveats):\n")
if (nrow(transferability) > 0) {
  for (i in 1:nrow(transferability)) {
    cat(sprintf("    %s vs field: %s (raw ratio = %.2f)\n",
                transferability$context[i],
                transferability$recommendation[i],
                transferability$adjustment_factor[i]))
  }
  cat("    NOTE: Confounded with study, size, region, era. Not actionable.\n")
}

# Size effect comparison
cat("\n  SIZE-SURVIVAL RELATIONSHIP BY CONTEXT:\n")
for (i in 1:nrow(context_models)) {
  sig_text <- if(!is.na(context_models$significant[i]) && context_models$significant[i]) "SIGNIFICANT" else "not significant"
  cat(sprintf("    %s: coef = %.3f (%s)\n",
              context_models$context[i],
              context_models$size_effect[i],
              sig_text))
}

cat("\nINTERPRETATION NOTES:\n")
cat("─────────────────────────────────────────────────────────────────\n")
cat("  CONFOUNDING WARNING: Context is nearly perfectly confounded with\n")
cat("  study identity, colony size, region, and era. Differences reported\n")
cat("  above are descriptive only.\n")
cat("  • Field data is dominated by NOAA large established colonies (~4,500 cm2)\n")
cat("  • Nursery data is from small restoration fragments (~64 cm2)\n")
cat("  • Size-restricted comparisons (Section 4B) partially address size confound\n")
cat("  • Even size-matched, study/region/era confounds remain unresolvable\n")
cat("  • Do NOT apply 'adjustment factors' as if they were causal corrections\n")
cat("  • Consider context as a descriptor in exploratory analyses, not a predictor\n")

cat("\nOutputs:\n")
cat("  - context_survival_comparison.csv\n")
cat("  - context_growth_comparison.csv\n")
cat("  - context_survival_by_size.csv\n")
cat("  - context_pairwise_*.csv (statistical tests — descriptive only)\n")
cat("  - context_overlap_zone_summary.csv (size-restricted comparison)\n")
cat("  - context_transferability.csv (exploratory — NOT causal recommendations)\n")
cat("  - context_*.png visualizations\n")
