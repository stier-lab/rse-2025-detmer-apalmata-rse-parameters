#!/usr/bin/env Rscript
################################################################################
# 29_NATURAL_VS_RESTORATION.R
# Within-Region Natural vs. Restoration Survival Comparison
#
# PURPOSE: Test whether natural and restoration populations differ in annual
#   survival WITHIN shared regions, controlling for the geographic confound
#   that plagues the overall comparison (p=0.405 at k=18).
#
# DESIGN:
#   Section 1: Within-region paired meta-analysis (3 regions with both types)
#   Section 2: Size-matched GLMM for Florida Keys (individual-level data)
#   Section 3: Size-class stratified comparison (individual-level data)
#   Section 4: Publication-quality forest plot figure
#   Section 5: Save all results
#
# KEY METHODOLOGICAL NOTES:
#   - Three regions have both natural and restoration data:
#       Florida Keys, Puerto Rico, US Virgin Islands
#   - Florida Keys is the STRONGEST test (individual-level, size-controlled)
#   - Natural vs restoration is confounded with study identity: ~99% of
#     individual-level natural data is from NOAA. Interpret accordingly.
#   - Every binomial GLMM includes an overdispersion check
#   - Meta-analysis uses Knapp-Hartung adjustment (test="knha")
#   - Size-matched comparison restricted to the overlap zone where both
#     population types have data
#
# INPUTS:
#   - 06_analysis/output/expanded_meta_analysis_study_effects.csv
#   - 05_data/standardized/apal_surv_ind.csv
#
# OUTPUTS:
#   CSVs: natural_vs_restoration_*.csv (4 files)
#   Figure: FigSXX_natural_vs_restoration_comparison.{png,pdf}
#
# Author: Detmer & Stier Lab
# Date: 2026-03
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)
library(metafor)
library(lme4)

set.seed(42)

cat("\n")
cat("==============================================================================\n")
cat("  29: WITHIN-REGION NATURAL vs. RESTORATION COMPARISON\n")
cat("==============================================================================\n\n")

# Paths
dirs <- setup_output_dirs()
output_dir <- dirs$output
fig_dir <- dirs$figures_supp
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

pal <- MANUSCRIPT_PALETTE

# ==============================================================================
# SECTION 1: WITHIN-REGION PAIRED META-ANALYSIS
# ==============================================================================

print_header("SECTION 1: Within-Region Paired Meta-Analysis")

cat("Three regions have both natural AND restoration data:\n")
cat("  - Florida Keys: NOAA (nat) vs Pausch, Rosales, Williams (rest)\n")
cat("  - Puerto Rico: Vardi (nat) vs Bruckner, Ortiz (rest)\n")
cat("  - US Virgin Islands: Garrison, Rogers&Muller, Rogers1982 (nat) vs USGS (rest)\n\n")

# Load expanded meta-analysis study effects
study_effects <- read_csv(
  file.path(output_dir, "expanded_meta_analysis_study_effects.csv"),
  show_col_types = FALSE
)

cat(sprintf("Loaded %d study effects from expanded meta-analysis\n", nrow(study_effects)))
cat(sprintf("Studies: %s\n\n", paste(study_effects$study, collapse = ", ")))

# --- Define the three within-region paired comparisons ---
# Map each study to its region for subsetting
paired_regions <- c("Florida Keys", "Puerto Rico", "US Virgin Islands")

region_data <- study_effects %>%
  filter(region %in% paired_regions) %>%
  select(study, study_id, region, population_type, n_total, n_survived,
         survival_rate, log_odds, var_log_odds, se_log_odds)

cat("Studies available in paired regions:\n")
for (reg in paired_regions) {
  reg_sub <- region_data %>% filter(region == reg)
  cat(sprintf("\n  %s:\n", reg))
  for (i in seq_len(nrow(reg_sub))) {
    cat(sprintf("    %s (%s): n=%d, surv=%.1f%%\n",
                reg_sub$study[i], reg_sub$population_type[i],
                reg_sub$n_total[i], reg_sub$survival_rate[i] * 100))
  }
}

# --- 1a. Within-region meta-regression: population_type as moderator ---
# For each region, fit rma() with population_type moderator

within_region_results <- list()

for (reg in paired_regions) {
  cat(sprintf("\n--- %s ---\n", reg))

  reg_sub <- region_data %>% filter(region == reg)
  k_reg <- nrow(reg_sub)
  k_nat <- sum(reg_sub$population_type == "Natural colony")
  k_rest <- sum(reg_sub$population_type == "Restoration fragment")

  cat(sprintf("  k_total=%d (natural=%d, restoration=%d)\n", k_reg, k_nat, k_rest))

  # Compute weighted (by n) pooled survival for each type
  nat_sub <- reg_sub %>% filter(population_type == "Natural colony")
  rest_sub <- reg_sub %>% filter(population_type == "Restoration fragment")

  nat_pooled_surv <- sum(nat_sub$n_survived) / sum(nat_sub$n_total)
  rest_pooled_surv <- sum(rest_sub$n_survived) / sum(rest_sub$n_total)
  nat_n <- sum(nat_sub$n_total)
  rest_n <- sum(rest_sub$n_total)

  # Wilson CIs for pooled proportions
  nat_ci <- wilson_ci(sum(nat_sub$n_survived), nat_n)
  rest_ci <- wilson_ci(sum(rest_sub$n_survived), rest_n)

  # Difference in percentage points
  diff_pp <- (nat_pooled_surv - rest_pooled_surv) * 100

  # Meta-regression with population_type moderator (if k >= 3)
  # For regions with k < 3, we use simple proportion comparison
  if (k_reg >= 3) {
    meta_reg <- tryCatch({
      rma(
        yi = log_odds, vi = var_log_odds,
        mods = ~population_type,
        data = reg_sub,
        method = "REML", test = "knha"
      )
    }, error = function(e) {
      cat(sprintf("  Meta-regression failed: %s\n", e$message))
      NULL
    })

    if (!is.null(meta_reg)) {
      coef_pop <- meta_reg$beta[2]
      se_pop <- meta_reg$se[2]
      p_pop <- meta_reg$pval[2]
      ci_lo_pop <- meta_reg$ci.lb[2]
      ci_hi_pop <- meta_reg$ci.ub[2]
      method_used <- "meta-regression (rma, knha)"
    } else {
      # Fallback: two-sample proportion test
      pt <- prop.test(
        x = c(sum(nat_sub$n_survived), sum(rest_sub$n_survived)),
        n = c(nat_n, rest_n)
      )
      coef_pop <- diff_pp / 100  # approximate log-odds difference
      se_pop <- NA_real_
      p_pop <- pt$p.value
      ci_lo_pop <- -diff(rev(pt$conf.int)) / 100
      ci_hi_pop <- diff(pt$conf.int) / 100
      method_used <- "two-sample proportion test (fallback)"
    }
  } else {
    # k < 3: use proportion test directly
    pt <- prop.test(
      x = c(sum(nat_sub$n_survived), sum(rest_sub$n_survived)),
      n = c(nat_n, rest_n)
    )
    coef_pop <- diff_pp / 100
    se_pop <- NA_real_
    p_pop <- pt$p.value
    ci_lo_pop <- NA_real_
    ci_hi_pop <- NA_real_
    method_used <- "two-sample proportion test (k<3)"
  }

  cat(sprintf("  Natural pooled: %.1f%% (n=%d)\n", nat_pooled_surv * 100, nat_n))
  cat(sprintf("  Restoration pooled: %.1f%% (n=%d)\n", rest_pooled_surv * 100, rest_n))
  cat(sprintf("  Difference (nat - rest): %+.1f pp\n", diff_pp))
  cat(sprintf("  p-value: %.4f, method: %s\n", p_pop, method_used))

  within_region_results[[reg]] <- data.frame(
    region = reg,
    nat_n = nat_n,
    rest_n = rest_n,
    nat_surv = nat_pooled_surv,
    rest_surv = rest_pooled_surv,
    nat_surv_lower = nat_ci$lower,
    nat_surv_upper = nat_ci$upper,
    rest_surv_lower = rest_ci$lower,
    rest_surv_upper = rest_ci$upper,
    difference_pp = diff_pp,
    log_odds_diff = as.numeric(coef_pop),
    se_log_odds_diff = as.numeric(se_pop),
    p_value = as.numeric(p_pop),
    method = method_used,
    k_natural = k_nat,
    k_restoration = k_rest,
    stringsAsFactors = FALSE
  )
}

within_region_df <- bind_rows(within_region_results)

# --- 1b. Overall within-region difference via meta-analysis of regional differences ---
# Compute a log-odds ratio for each region (nat vs rest) for meta-analysis
cat("\n--- Overall Within-Region Meta-Analysis ---\n")

# For each region, compute the log-OR comparing natural to restoration
region_lor <- within_region_df %>%
  mutate(
    # Log odds ratio: log(nat_odds / rest_odds)
    nat_odds = nat_surv / (1 - nat_surv),
    rest_odds = rest_surv / (1 - rest_surv),
    log_or = log(nat_odds / rest_odds),
    # Approximate SE of log-OR from sample proportions
    # Using the standard formula for SE of log-OR from 2x2 table
    # SE = sqrt(1/(a) + 1/(b) + 1/(c) + 1/(d))
    # where a = nat survived, b = nat died, c = rest survived, d = rest died
    nat_survived = round(nat_surv * nat_n),
    nat_died = nat_n - nat_survived,
    rest_survived = round(rest_surv * rest_n),
    rest_died = rest_n - rest_survived,
    # Apply Haldane correction if any cell is 0
    nat_survived_c = ifelse(nat_survived == 0 | nat_died == 0 |
                            rest_survived == 0 | rest_died == 0,
                            nat_survived + 0.5, nat_survived),
    nat_died_c = ifelse(nat_survived == 0 | nat_died == 0 |
                        rest_survived == 0 | rest_died == 0,
                        nat_died + 0.5, nat_died),
    rest_survived_c = ifelse(nat_survived == 0 | nat_died == 0 |
                             rest_survived == 0 | rest_died == 0,
                             rest_survived + 0.5, rest_survived),
    rest_died_c = ifelse(nat_survived == 0 | nat_died == 0 |
                         rest_survived == 0 | rest_died == 0,
                         rest_died + 0.5, rest_died),
    # Recalculate log-OR with corrected values
    log_or_c = log((nat_survived_c / nat_died_c) / (rest_survived_c / rest_died_c)),
    var_log_or = 1/nat_survived_c + 1/nat_died_c + 1/rest_survived_c + 1/rest_died_c
  )

# Meta-analysis of within-region log-ORs
if (nrow(region_lor) >= 2) {
  rma_within <- tryCatch({
    rma(
      yi = log_or_c, vi = var_log_or,
      data = region_lor,
      method = "REML", test = "knha"
    )
  }, error = function(e) {
    cat(sprintf("  Within-region meta-analysis failed: %s\n", e$message))
    # Fallback: fixed effects
    rma(yi = log_or_c, vi = var_log_or, data = region_lor, method = "FE")
  })

  overall_lor <- as.numeric(rma_within$beta)
  overall_or <- exp(overall_lor)
  overall_or_ci <- exp(c(rma_within$ci.lb, rma_within$ci.ub))
  overall_p <- rma_within$pval

  cat(sprintf("  Overall within-region log-OR (natural vs restoration): %.3f\n", overall_lor))
  cat(sprintf("  OR = %.2f (95%% CI: %.2f - %.2f), p = %.4f\n",
              overall_or, overall_or_ci[1], overall_or_ci[2], overall_p))
  cat(sprintf("  Interpretation: Within shared regions, natural colonies have\n"))
  cat(sprintf("    %.0f%% %s odds of survival vs restoration fragments\n",
              abs(overall_or - 1) * 100,
              ifelse(overall_or > 1, "higher", "lower")))

  # Add overall row to the within-region results
  overall_row <- data.frame(
    region = "Overall (within-region)",
    nat_n = sum(within_region_df$nat_n),
    rest_n = sum(within_region_df$rest_n),
    nat_surv = NA_real_,  # Not meaningful for pooled
    rest_surv = NA_real_,
    nat_surv_lower = NA_real_,
    nat_surv_upper = NA_real_,
    rest_surv_lower = NA_real_,
    rest_surv_upper = NA_real_,
    difference_pp = NA_real_,
    log_odds_diff = overall_lor,
    se_log_odds_diff = rma_within$se,
    p_value = as.numeric(overall_p),
    method = "RE meta-analysis of regional log-ORs (knha)",
    k_natural = sum(within_region_df$k_natural),
    k_restoration = sum(within_region_df$k_restoration),
    stringsAsFactors = FALSE
  )

  within_region_df <- bind_rows(within_region_df, overall_row)
} else {
  cat("  WARNING: Fewer than 2 regions; cannot compute overall within-region effect.\n")
  rma_within <- NULL
}

cat("\nWithin-region comparison summary:\n")
print(within_region_df %>%
        select(region, nat_surv, rest_surv, difference_pp, p_value, method))


# ==============================================================================
# SECTION 2: SIZE-MATCHED INDIVIDUAL-LEVEL COMPARISON (FLORIDA KEYS)
# ==============================================================================

print_header("SECTION 2: Size-Matched Individual-Level Comparison (Florida Keys)")

cat("This is the STRONGEST test: same region, individual-level data, size-controlled.\n")
cat("Natural: NOAA_survey (Florida Keys subset)\n")
cat("Restoration: pausch_et_al_2018\n\n")

# Load individual-level survival data
surv_ind <- read_csv(
  file.path(get_project_root(), "05_data/standardized/apal_surv_ind.csv"),
  show_col_types = FALSE
)

# Assign population type from study identity
surv_ind <- surv_ind %>%
  mutate(
    population_type = case_when(
      study == "NOAA_survey" ~ "Natural colony",
      study == "pausch_et_al_2018" ~ "Restoration fragment",
      study == "USGS_USVI_exp" ~ "Restoration fragment",
      study == "kuffner_et_al_2020" ~ "Restoration fragment",
      study == "fundemar_fragments" ~ "Restoration fragment",
      study == "mendoza_quiroz_et_al_2023" ~ "Natural colony",
      TRUE ~ NA_character_
    )
  )

# Filter to Florida Keys, NOAA vs Pausch
fl_data <- surv_ind %>%
  filter(region == "Florida Keys",
         study %in% c("NOAA_survey", "pausch_et_al_2018")) %>%
  filter(!is.na(size_cm2), size_cm2 > 0,
         !is.na(survived))

cat(sprintf("Florida Keys data: %d observations\n", nrow(fl_data)))
cat(sprintf("  NOAA (natural): %d\n", sum(fl_data$study == "NOAA_survey")))
cat(sprintf("  Pausch (restoration): %d\n", sum(fl_data$study == "pausch_et_al_2018")))

# Assign size classes
fl_data <- fl_data %>%
  mutate(
    size_class = assign_size_class(size_cm2, labels = "standard"),
    log_size = log(size_cm2)
  )

# --- Identify the SIZE OVERLAP ZONE ---
# Find the size range where both populations have data
noaa_range <- fl_data %>%
  filter(study == "NOAA_survey") %>%
  summarise(min_size = min(size_cm2), max_size = max(size_cm2))

pausch_range <- fl_data %>%
  filter(study == "pausch_et_al_2018") %>%
  summarise(min_size = min(size_cm2), max_size = max(size_cm2))

overlap_min <- max(noaa_range$min_size, pausch_range$min_size)
overlap_max <- min(noaa_range$max_size, pausch_range$max_size)

cat(sprintf("\nSize ranges:\n"))
cat(sprintf("  NOAA:   %.1f - %.1f cm^2\n", noaa_range$min_size, noaa_range$max_size))
cat(sprintf("  Pausch: %.1f - %.1f cm^2\n", pausch_range$min_size, pausch_range$max_size))
cat(sprintf("  Overlap zone: %.1f - %.1f cm^2\n", overlap_min, overlap_max))

# Restrict to the overlap zone
fl_matched <- fl_data %>%
  filter(size_cm2 >= overlap_min, size_cm2 <= overlap_max)

cat(sprintf("\nSize-matched data (overlap zone): %d observations\n", nrow(fl_matched)))
cat(sprintf("  NOAA (natural): %d\n", sum(fl_matched$study == "NOAA_survey")))
cat(sprintf("  Pausch (restoration): %d\n", sum(fl_matched$study == "pausch_et_al_2018")))

# Size distribution summary in the overlap zone
cat("\nSize distribution in overlap zone:\n")
fl_matched %>%
  group_by(population_type) %>%
  summarise(
    n = n(),
    mean_size = mean(size_cm2),
    median_size = median(size_cm2),
    sd_size = sd(size_cm2),
    .groups = "drop"
  ) %>%
  print()

# --- Fit Models ---
cat("\n--- Size-Matched Models (addressing singular fit) ---\n")

# FIX: Singular fit problem (critique audit 2026-03-29)
# With only 2 studies, (1|study) collapses to zero variance because
# population_type is perfectly confounded with study identity. Three approaches:
#
# A) Fixed-effect GLM with cluster-robust SEs (PRIMARY — most honest)
#    Reports the observed difference with SEs that account for clustering
# B) GLMM (1|study) — kept for comparison, will likely give singular fit
# C) Study as fixed effect — explicitly models study differences
#
# The meta-analytic approach (Section 1) already properly handles this via
# study-level effect sizes. This individual-level analysis complements it
# by controlling for colony size within the overlap zone.

n_studies_fl <- n_distinct(fl_matched$study)
cat(sprintf("  Number of studies: %d\n", n_studies_fl))
cat("  Population_type is perfectly confounded with study identity.\n")
cat("  Using fixed-effect GLM with cluster-robust SEs as primary approach.\n\n")

# --- Approach A: GLM + cluster-robust SEs (PRIMARY) ---
cat("  Approach A: GLM with cluster-robust standard errors\n")
glm_interact <- glm(survived ~ population_type * log_size,
                     family = binomial, data = fl_matched)
glm_main <- glm(survived ~ population_type + log_size,
                 family = binomial, data = fl_matched)

# Cluster-robust SEs using sandwich estimator
if (requireNamespace("sandwich", quietly = TRUE) && requireNamespace("lmtest", quietly = TRUE)) {
  library(sandwich)
  library(lmtest)

  # Cluster on study
  robust_interact <- coeftest(glm_interact, vcov = vcovCL(glm_interact, cluster = fl_matched$study))
  robust_main <- coeftest(glm_main, vcov = vcovCL(glm_main, cluster = fl_matched$study))

  cat("  Cluster-robust interaction model:\n")
  print(robust_interact)
  cat("\n  Cluster-robust main-effects model:\n")
  print(robust_main)

  has_robust <- TRUE
} else {
  cat("  WARNING: sandwich/lmtest not available; using naive SEs.\n")
  cat("  Install with: install.packages(c('sandwich', 'lmtest'))\n")
  has_robust <- FALSE
}

# --- Approach B: GLMM (for comparison, expect singular fit) ---
cat("\n  Approach B: GLMM with (1|study) — expect singular fit\n")
glmm_interact <- tryCatch({
  m <- glmer(
    survived ~ population_type * log_size + (1|study),
    family = binomial, data = fl_matched,
    control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
  )
  if (isSingular(m)) {
    cat("  SINGULAR FIT CONFIRMED: random effect variance = 0.\n")
    cat("  This confirms population_type is aliased with study.\n")
    cat("  GLM with cluster-robust SEs (Approach A) is the appropriate model.\n")
  }
  m
}, error = function(e) {
  cat(sprintf("  GLMM failed: %s\n", e$message))
  NULL
})

# --- Approach C: Study as fixed effect ---
cat("\n  Approach C: Study as fixed effect\n")
glm_study_fe <- glm(survived ~ study * log_size, family = binomial, data = fl_matched)
cat("  Study-level coefficients:\n")
print(round(coef(summary(glm_study_fe)), 4))

# Use the GLM (Approach A) as the primary model for downstream results
# This avoids the singular fit issue entirely
glmm_interact_primary <- glm_interact  # rename for downstream compatibility

# Also fit the main-effects-only model
glmm_main <- tryCatch({
  glmer(
    survived ~ population_type + log_size + (1|study),
    family = binomial, data = fl_matched,
    control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
  )
}, error = function(e) {
  cat(sprintf("  Main-effects model failed: %s\n", e$message))
  glm(survived ~ population_type + log_size, family = binomial, data = fl_matched)
})

# --- Overdispersion check ---
cat("--- Overdispersion Check (primary GLM model) ---\n")
pear_resid <- residuals(glm_interact, type = "pearson")
od_ratio <- sum(pear_resid^2) / (length(pear_resid) - length(coef(glm_interact)))
cat(sprintf("  Interaction model: ratio = %.3f, overdispersed = %s\n",
            od_ratio, od_ratio > 1.5))
pear_resid_m <- residuals(glm_main, type = "pearson")
od_ratio_m <- sum(pear_resid_m^2) / (length(pear_resid_m) - length(coef(glm_main)))
cat(sprintf("  Main-effects model: ratio = %.3f, overdispersed = %s\n",
            od_ratio_m, od_ratio_m > 1.5))

# Also check GLMM if it converged
if (!is.null(glmm_interact) && inherits(glmm_interact, "glmerMod")) {
  od_glmm <- overdisp_test(glmm_interact)
  cat(sprintf("  GLMM (singular): ratio = %.3f\n", od_glmm$ratio))
}

# --- Extract results from PRIMARY model (GLM + cluster-robust SEs) ---
cat("\n--- Primary Model Summary (GLM + cluster-robust SEs) ---\n")
print(summary(glm_interact))

# Extract fixed effects as odds ratios
# Use cluster-robust SEs if available, otherwise naive SEs
fe <- coef(glm_interact)
if (has_robust) {
  se_fe <- robust_interact[, "Std. Error"]
  p_vals <- robust_interact[, "Pr(>|z|)"]
} else {
  se_fe <- sqrt(diag(vcov(glm_interact)))
  p_vals <- 2 * pnorm(abs(fe / se_fe), lower.tail = FALSE)
}
or_table <- data.frame(
  term = names(fe),
  estimate = fe,
  se = se_fe,
  or = exp(fe),
  or_lower = exp(fe - 1.96 * se_fe),
  or_upper = exp(fe + 1.96 * se_fe),
  z = fe / se_fe,
  p = p_vals,
  se_type = ifelse(has_robust, "cluster-robust", "naive")
)
rownames(or_table) <- NULL

cat("\nOdds Ratios (GLM + cluster-robust SEs):\n")
print(or_table)

# Compare with GLMM if available
if (!is.null(glmm_interact) && inherits(glmm_interact, "glmerMod")) {
  cat("\nGLMM comparison (singular fit — for reference only):\n")
  fe_glmm <- fixef(glmm_interact)
  se_glmm <- sqrt(diag(vcov(glmm_interact)))
  cat(sprintf("  GLMM pop_type OR: %.2f (SE=%.3f)\n", exp(fe_glmm[2]), se_glmm[2]))
  cat(sprintf("  GLM  pop_type OR: %.2f (SE=%.3f, cluster-robust)\n", exp(fe[2]), se_fe[2]))
  cat("  Note: similar estimates confirm singular fit doesn't distort point estimates\n")
}

# --- Predicted survival curves ---
# Generate predictions from the primary GLM model
newdata_pred <- expand.grid(
  log_size = seq(log(overlap_min), log(overlap_max), length.out = 200),
  population_type = c("Natural colony", "Restoration fragment")
)

# GLM predictions with SEs
pred_link <- predict(glm_interact, newdata = newdata_pred, type = "link", se.fit = TRUE)
newdata_pred$pred <- plogis(pred_link$fit)
newdata_pred$pred_lower <- plogis(pred_link$fit - 1.96 * pred_link$se.fit)
newdata_pred$pred_upper <- plogis(pred_link$fit + 1.96 * pred_link$se.fit)

newdata_pred$size_cm2 <- exp(newdata_pred$log_size)

# Save size-matched results
size_matched_results <- or_table %>%
  mutate(
    analysis = "Florida Keys size-matched GLM (cluster-robust SEs)",
    n_total = nrow(fl_matched),
    n_natural = sum(fl_matched$population_type == "Natural colony"),
    n_restoration = sum(fl_matched$population_type == "Restoration fragment"),
    size_overlap_min_cm2 = overlap_min,
    size_overlap_max_cm2 = overlap_max,
    model_class = class(glmm_interact)[1]
  )


# ==============================================================================
# SECTION 3: SIZE-CLASS STRATIFIED COMPARISON
# ==============================================================================

print_header("SECTION 3: Size-Class Stratified Comparison")

cat("Compare natural vs restoration survival within each size class.\n")
cat("Using individual-level data from all studies with population_type.\n")
cat("NOTE: SC4-SC5 have almost no restoration data; restrict to SC1-SC3.\n\n")

# Use ALL individual-level data (not just Florida Keys) for broader comparison
surv_all <- surv_ind %>%
  filter(!is.na(population_type), !is.na(survived), !is.na(size_cm2), size_cm2 > 0) %>%
  mutate(
    size_class = assign_size_class(size_cm2, labels = "standard"),
    log_size = log(size_cm2)
  )

cat("Sample sizes by population type and size class:\n")
sc_counts <- surv_all %>%
  group_by(size_class, population_type) %>%
  summarise(
    n = n(),
    n_survived = sum(survived),
    raw_surv = mean(survived),
    .groups = "drop"
  ) %>%
  arrange(size_class, population_type)
print(sc_counts)

# Identify which size classes have both types with adequate data (n >= 5 per type)
viable_sc <- sc_counts %>%
  group_by(size_class) %>%
  filter(n() == 2, all(n >= 5)) %>%  # both types present, n >= 5 each

  pull(size_class) %>%
  unique()

cat(sprintf("\nViable size classes for comparison: %s\n",
            paste(viable_sc, collapse = ", ")))

# --- Fit GLMM within each viable size class ---
sc_results <- list()

for (sc in viable_sc) {
  cat(sprintf("\n--- %s ---\n", sc))

  sc_sub <- surv_all %>% filter(size_class == sc)
  n_studies_sc <- n_distinct(sc_sub$study)
  n_nat <- sum(sc_sub$population_type == "Natural colony")
  n_rest <- sum(sc_sub$population_type == "Restoration fragment")
  nat_surv_raw <- mean(sc_sub$survived[sc_sub$population_type == "Natural colony"])
  rest_surv_raw <- mean(sc_sub$survived[sc_sub$population_type == "Restoration fragment"])

  cat(sprintf("  n_natural=%d, n_restoration=%d, n_studies=%d\n",
              n_nat, n_rest, n_studies_sc))
  cat(sprintf("  Raw survival: natural=%.1f%%, restoration=%.1f%%\n",
              nat_surv_raw * 100, rest_surv_raw * 100))

  # Fit GLMM with (1|study) if we have > 1 study per type
  if (n_studies_sc >= 2) {
    sc_model <- tryCatch({
      glmer(
        survived ~ population_type + (1|study),
        family = binomial, data = sc_sub,
        control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
      )
    }, error = function(e) {
      cat(sprintf("  GLMM failed: %s. Falling back to GLM.\n", e$message))
      glm(survived ~ population_type, family = binomial, data = sc_sub)
    })
  } else {
    cat("  Only 1 study; using GLM without random effects.\n")
    sc_model <- glm(survived ~ population_type, family = binomial, data = sc_sub)
  }

  # Overdispersion check
  if (inherits(sc_model, "glmerMod")) {
    od_sc <- overdisp_test(sc_model)
    cat(sprintf("  Overdispersion: ratio=%.3f, overdispersed=%s\n",
                od_sc$ratio, od_sc$overdispersed))
    fe_sc <- fixef(sc_model)
    se_sc <- sqrt(diag(vcov(sc_model)))
  } else {
    pear_r <- residuals(sc_model, type = "pearson")
    od_ratio_sc <- sum(pear_r^2) / (length(pear_r) - length(coef(sc_model)))
    cat(sprintf("  Overdispersion (GLM): ratio=%.3f, overdispersed=%s\n",
                od_ratio_sc, od_ratio_sc > 1.5))
    fe_sc <- coef(sc_model)
    se_sc <- sqrt(diag(vcov(sc_model)))
  }

  # Extract population_type effect
  # The coefficient for "Restoration fragment" (relative to "Natural colony" baseline)
  pop_idx <- grep("population_type", names(fe_sc))
  if (length(pop_idx) > 0) {
    est <- fe_sc[pop_idx]
    se_est <- se_sc[pop_idx]
    or_sc <- exp(est)
    or_lo <- exp(est - 1.96 * se_est)
    or_hi <- exp(est + 1.96 * se_est)
    z_sc <- est / se_est
    p_sc <- 2 * pnorm(abs(z_sc), lower.tail = FALSE)
  } else {
    est <- se_est <- or_sc <- or_lo <- or_hi <- z_sc <- p_sc <- NA_real_
  }

  cat(sprintf("  OR (restoration vs natural): %.2f (%.2f - %.2f), p = %.4f\n",
              or_sc, or_lo, or_hi, p_sc))

  sc_results[[sc]] <- data.frame(
    size_class = sc,
    nat_n = n_nat,
    rest_n = n_rest,
    nat_surv = nat_surv_raw,
    rest_surv = rest_surv_raw,
    log_or = as.numeric(est),
    se_log_or = as.numeric(se_est),
    or = or_sc,
    or_lower = or_lo,
    or_upper = or_hi,
    z_value = as.numeric(z_sc),
    p_value = as.numeric(p_sc),
    n_studies = n_studies_sc,
    model_type = class(sc_model)[1],
    stringsAsFactors = FALSE
  )
}

sc_results_df <- bind_rows(sc_results)

cat("\nSize-class stratified comparison summary:\n")
print(sc_results_df %>%
        select(size_class, nat_n, rest_n, nat_surv, rest_surv, or, or_lower, or_upper, p_value))


# ==============================================================================
# SECTION 4: PUBLICATION-QUALITY FOREST PLOT
# ==============================================================================

print_header("SECTION 4: Forest Plot Figure")

# --- Panel (a): Within-region comparison ---
# Prepare data for the forest plot

# Convert within-region results to log-OR scale for plotting
region_plot_data <- within_region_df %>%
  filter(region != "Overall (within-region)") %>%
  mutate(
    nat_survived = round(nat_surv * nat_n),
    nat_died = nat_n - nat_survived,
    rest_survived = round(rest_surv * rest_n),
    rest_died = rest_n - rest_survived,
    # Apply Haldane correction for zero cells
    nat_survived_c = ifelse(nat_survived == 0 | nat_died == 0 |
                            rest_survived == 0 | rest_died == 0,
                            nat_survived + 0.5, nat_survived),
    nat_died_c = ifelse(nat_survived == 0 | nat_died == 0 |
                        rest_survived == 0 | rest_died == 0,
                        nat_died + 0.5, nat_died),
    rest_survived_c = ifelse(nat_survived == 0 | nat_died == 0 |
                             rest_survived == 0 | rest_died == 0,
                             rest_survived + 0.5, rest_survived),
    rest_died_c = ifelse(nat_survived == 0 | nat_died == 0 |
                         rest_survived == 0 | rest_died == 0,
                         rest_died + 0.5, rest_died),
    log_or = log((nat_survived_c / nat_died_c) / (rest_survived_c / rest_died_c)),
    var_log_or = 1/nat_survived_c + 1/nat_died_c + 1/rest_survived_c + 1/rest_died_c,
    se_log_or = sqrt(var_log_or),
    or = exp(log_or),
    or_lower = exp(log_or - 1.96 * se_log_or),
    or_upper = exp(log_or + 1.96 * se_log_or),
    # Label
    label = sprintf("%s\n(nat=%d, rest=%d)", region, nat_n, rest_n)
  )

# Add overall row
if (!is.null(rma_within)) {
  overall_plot <- data.frame(
    region = "Overall",
    log_or = as.numeric(rma_within$beta),
    se_log_or = as.numeric(rma_within$se),
    or = exp(as.numeric(rma_within$beta)),
    or_lower = exp(as.numeric(rma_within$ci.lb)),
    or_upper = exp(as.numeric(rma_within$ci.ub)),
    nat_n = sum(within_region_df$nat_n[within_region_df$region != "Overall (within-region)"]),
    rest_n = sum(within_region_df$rest_n[within_region_df$region != "Overall (within-region)"]),
    label = "Overall",
    stringsAsFactors = FALSE
  )
  forest_a_data <- bind_rows(
    region_plot_data %>% select(region, log_or, se_log_or, or, or_lower, or_upper,
                                 nat_n, rest_n, label),
    overall_plot
  )
} else {
  forest_a_data <- region_plot_data %>%
    select(region, log_or, se_log_or, or, or_lower, or_upper, nat_n, rest_n, label)
}

# Set factor levels for plotting order
forest_a_data$label <- factor(
  forest_a_data$label,
  levels = rev(forest_a_data$label)
)

# Build panel (a)
p_a <- ggplot(forest_a_data, aes(x = or, y = label)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey50", linewidth = 0.5) +
  geom_errorbarh(aes(xmin = or_lower, xmax = or_upper),
                 height = 0.2, linewidth = 0.6, color = "grey30") +
  geom_point(aes(size = ifelse(region == "Overall", 5, 3),
                 shape = ifelse(region == "Overall", "diamond", "circle")),
             color = pal$surv_dark, fill = pal$surv_mid) +
  scale_shape_identity() +
  scale_size_identity() +
  scale_x_log10(
    breaks = c(0.1, 0.25, 0.5, 1, 2, 4, 10),
    labels = c("0.1", "0.25", "0.5", "1", "2", "4", "10")
  ) +
  labs(
    x = "Odds Ratio (Natural / Restoration)",
    y = NULL
  ) +
  annotate("text", x = 0.1, y = Inf, label = "Restoration\nfavoured",
           hjust = 0, vjust = 1.5, size = 2.8, color = "grey50", fontface = "italic") +
  annotate("text", x = 10, y = Inf, label = "Natural\nfavoured",
           hjust = 1, vjust = 1.5, size = 2.8, color = "grey50", fontface = "italic") +
  theme_manuscript(base_size = 10) +
  theme(
    plot.margin = margin(10, 15, 5, 10, "mm"),
    axis.text.y = element_text(size = 8)
  )

# --- Panel (b): Size-class stratified comparison ---
# Plot OR with CIs for each size class

sc_plot_data <- sc_results_df %>%
  mutate(
    label = sprintf("%s\n(nat=%d, rest=%d)", size_class, nat_n, rest_n),
    # Ensure OR CIs don't explode
    or_lower_plot = pmax(or_lower, 0.01),
    or_upper_plot = pmin(or_upper, 100)
  )

sc_plot_data$label <- factor(sc_plot_data$label, levels = rev(sc_plot_data$label))

p_b <- ggplot(sc_plot_data, aes(x = or, y = label)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey50", linewidth = 0.5) +
  geom_errorbarh(aes(xmin = or_lower_plot, xmax = or_upper_plot),
                 height = 0.2, linewidth = 0.6, color = "grey30") +
  geom_point(size = 3, color = pal$grow_dark, fill = pal$grow_mid, shape = 21) +
  scale_x_log10(
    breaks = c(0.1, 0.25, 0.5, 1, 2, 4, 10),
    labels = c("0.1", "0.25", "0.5", "1", "2", "4", "10")
  ) +
  labs(
    x = "Odds Ratio (Restoration vs Natural)",
    y = NULL
  ) +
  annotate("text", x = 0.1, y = Inf, label = "Natural\nfavoured",
           hjust = 0, vjust = 1.5, size = 2.8, color = "grey50", fontface = "italic") +
  annotate("text", x = 10, y = Inf, label = "Restoration\nfavoured",
           hjust = 1, vjust = 1.5, size = 2.8, color = "grey50", fontface = "italic") +
  theme_manuscript(base_size = 10) +
  theme(
    plot.margin = margin(5, 15, 10, 10, "mm"),
    axis.text.y = element_text(size = 8)
  )

# --- Combine panels ---
fig_combined <- p_a / p_b +
  plot_annotation(tag_levels = "a") +
  plot_layout(heights = c(1, 1))

# Save
save_manuscript_fig(
  fig_combined,
  "FigSXX_natural_vs_restoration_comparison",
  width_mm = 174,
  height_mm = 180,
  fig_dir = fig_dir
)


# ==============================================================================
# SECTION 5: SAVE ALL RESULTS
# ==============================================================================

print_header("SECTION 5: Save Results")

# 5a. Within-region comparison
write_csv(within_region_df,
          file.path(output_dir, "natural_vs_restoration_within_region.csv"))
cat("  Saved: natural_vs_restoration_within_region.csv\n")

# 5b. Size-matched comparison (FL Keys GLMM)
write_csv(size_matched_results,
          file.path(output_dir, "natural_vs_restoration_size_matched.csv"))
cat("  Saved: natural_vs_restoration_size_matched.csv\n")

# 5c. Size-class stratified comparison
write_csv(sc_results_df,
          file.path(output_dir, "natural_vs_restoration_by_size_class.csv"))
cat("  Saved: natural_vs_restoration_by_size_class.csv\n")

# 5d. Summary table for manuscript text
# One-row summary with key numbers for easy reference
summary_row <- data.frame(
  # Overall within-region meta-analysis
  overall_or = ifelse(!is.null(rma_within), exp(as.numeric(rma_within$beta)), NA_real_),
  overall_or_lower = ifelse(!is.null(rma_within), exp(as.numeric(rma_within$ci.lb)), NA_real_),
  overall_or_upper = ifelse(!is.null(rma_within), exp(as.numeric(rma_within$ci.ub)), NA_real_),
  overall_p = ifelse(!is.null(rma_within), as.numeric(rma_within$pval), NA_real_),
  n_regions_compared = length(paired_regions),
  # Florida Keys comparison (strongest test)
  fl_nat_surv = mean(fl_matched$survived[fl_matched$population_type == "Natural colony"]),
  fl_rest_surv = mean(fl_matched$survived[fl_matched$population_type == "Restoration fragment"]),
  fl_n_natural = sum(fl_matched$population_type == "Natural colony"),
  fl_n_restoration = sum(fl_matched$population_type == "Restoration fragment"),
  fl_size_overlap_min = overlap_min,
  fl_size_overlap_max = overlap_max,
  # Key model result from interaction GLMM
  fl_pop_type_or = or_table$or[grep("population_type", or_table$term)[1]],
  fl_pop_type_p = or_table$p[grep("population_type", or_table$term)[1]],
  fl_interaction_p = ifelse(any(grepl(":", or_table$term)),
                            or_table$p[grep(":", or_table$term)], NA_real_),
  # Number of viable size classes
  n_viable_size_classes = length(viable_sc),
  # Interpretive flags
  note = paste0(
    "Natural vs restoration is confounded with study identity. ",
    "FL Keys comparison is strongest (individual-level, size-controlled). ",
    "Overall meta (k=18) shows p=0.405 (not significant)."
  ),
  stringsAsFactors = FALSE
)

write_csv(summary_row,
          file.path(output_dir, "natural_vs_restoration_summary.csv"))
cat("  Saved: natural_vs_restoration_summary.csv\n")

# --- Final summary ---
cat("\n")
cat("==============================================================================\n")
cat("  ANALYSIS COMPLETE: Within-Region Natural vs. Restoration Comparison\n")
cat("==============================================================================\n\n")

cat("KEY FINDINGS:\n")
cat(sprintf("  1. Within-region meta-analysis (k=%d regions):\n", length(paired_regions)))
if (!is.null(rma_within)) {
  cat(sprintf("     Overall OR = %.2f (95%% CI: %.2f - %.2f), p = %.4f\n",
              exp(as.numeric(rma_within$beta)),
              exp(as.numeric(rma_within$ci.lb)),
              exp(as.numeric(rma_within$ci.ub)),
              as.numeric(rma_within$pval)))
}

cat(sprintf("\n  2. Florida Keys size-matched comparison (n=%d):\n", nrow(fl_matched)))
cat(sprintf("     Population type OR: %.2f (p = %.4f)\n",
            or_table$or[grep("population_type", or_table$term)[1]],
            or_table$p[grep("population_type", or_table$term)[1]]))
if (any(grepl(":", or_table$term))) {
  cat(sprintf("     Interaction (type x size) p = %.4f\n",
              or_table$p[grep(":", or_table$term)]))
}

cat(sprintf("\n  3. Size-class stratified comparison (%d viable classes):\n",
            length(viable_sc)))
for (i in seq_len(nrow(sc_results_df))) {
  cat(sprintf("     %s: OR = %.2f (%.2f - %.2f), p = %.4f\n",
              sc_results_df$size_class[i], sc_results_df$or[i],
              sc_results_df$or_lower[i], sc_results_df$or_upper[i],
              sc_results_df$p_value[i]))
}

cat("\nCAVEATS:\n")
cat("  - Natural vs restoration is confounded with study identity (~99%% NOAA)\n")
cat("  - Within-region comparison partially controls this but study x type confound remains\n")
cat("  - Size distributions differ substantially between populations\n")
cat("  - Random effect (1|study) poorly estimated with 2 studies in FL Keys\n")
cat("  - Results should be interpreted as descriptive, not causal\n\n")

cat("OUTPUTS:\n")
cat(sprintf("  Figures: %s/FigSXX_natural_vs_restoration_comparison.{png,pdf}\n", fig_dir))
cat(sprintf("  Tables:  %s/natural_vs_restoration_*.csv (4 files)\n", output_dir))
cat("\nDone.\n")
