################################################################################
# 56_outplant_age_model.R - Outplant-age survival decay (Idea 4)
################################################################################
#
# PURPOSE:
#   Fit a restoration-only survival model with years_since_outplant as a
#   covariate to quantify the Boisvert-style "outplant decay" signal: a given
#   sized colony experiences elevated mortality in its first year in the field
#   and lower mortality once it has survived its first post-outplant season.
#   Produce a revised survival vector at a 2-year outplant age to feed the
#   scenario-comparison pipeline (script 60).
#
# CITATION:
#   Boisvert et al. 2024, Coral Reefs -- A. cervicornis restoration decay.
#
# HYPOTHESIS:
#   Per-size survival decays with years since outplant over the first ~2 years
#   as stress, disease, and predation accumulate before lightly-monitored
#   survivors are established.
#
# INPUTS:
#   - 05_data/standardized/apal_surv_ind.csv
#   - 05_data/standardized/apal_outplant_age.csv  (produced by script 50)
#   - 06_analysis/output/transition_matrix.rds    (baseline S vector)
#
# OUTPUT:
#   06_analysis/output/outplant_age_survival.rds
#     list(
#       baseline           -- named SC1-SC5 numeric (unchanged),
#       year_2             -- named SC1-SC5 numeric at years_since_outplant=2,
#       coef_summary       -- model coefficient table,
#       overdispersion_ratio,
#       n_used,
#       note
#     )
#
# Author: Detmer & Stier Lab
# Date:   2026-04-17
################################################################################

source("06_analysis/scripts/utils/shared_utilities.R")

print_header("Script 56: Outplant-age survival decay (Idea 4)")

output_dir <- "06_analysis/output"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# Load baseline survival vector (S0) -- reference
# =============================================================================
trans_path <- file.path(output_dir, "transition_matrix.rds")
if (!file.exists(trans_path)) {
  stop(sprintf("Missing %s. Run script 13_transition_matrix.R first.", trans_path))
}
trans <- readRDS(trans_path)
baseline_S <- trans$survival_rates
if (is.null(baseline_S) || length(baseline_S) != 5) {
  # Back-compat fallback: some object versions name this 'survival'
  baseline_S <- trans$survival
}
names(baseline_S) <- SIZE_LABELS
print_success(sprintf("Baseline S loaded: %s",
                      paste(sprintf("%.3f", baseline_S), collapse = ", ")))

# =============================================================================
# Load + join survival and outplant age
# =============================================================================
surv <- read.csv("05_data/standardized/apal_surv_ind.csv",
                 stringsAsFactors = FALSE)
outplant <- read.csv("05_data/standardized/apal_outplant_age.csv",
                     stringsAsFactors = FALSE)
cat(sprintf("  Survival rows: %d\n", nrow(surv)))
cat(sprintf("  Outplant-age rows: %d\n", nrow(outplant)))

df <- surv %>%
  dplyr::left_join(
    dplyr::select(outplant, study, coral_id, survey_yr,
                  years_since_outplant, is_restoration),
    by = c("study", "coral_id", "survey_yr")
  ) %>%
  dplyr::filter(!is.na(survived),
                !is.na(size_cm2), size_cm2 > 0,
                is_restoration %in% TRUE,
                !is.na(years_since_outplant))

cat(sprintf("  Restoration rows with outplant age + survival: %d\n", nrow(df)))

if (nrow(df) < 50) {
  warning("Too few restoration rows with outplant age to fit model; saving placeholder.")
  placeholder <- list(
    baseline = baseline_S,
    year_2 = baseline_S,
    coef_summary = NULL,
    overdispersion_ratio = NA_real_,
    n_used = nrow(df),
    note = "Insufficient restoration rows; baseline survival unchanged"
  )
  saveRDS(placeholder, file.path(output_dir, "outplant_age_survival.rds"))
  print_warn("Saved placeholder outplant_age_survival.rds")
  cat("Done.\n"); quit(save = "no", status = 0)
}

df$log_size <- log(df$size_cm2 + 1)
df$study <- as.factor(df$study)

# =============================================================================
# Fit GLMM (binomial) with fallback to GLM
# =============================================================================
print_subheader("Fit: survived ~ log(size) + years_since_outplant + (1|study)")

fit <- tryCatch({
  lme4::glmer(survived ~ log_size + years_since_outplant + (1 | study),
              data = df, family = binomial,
              control = lme4::glmerControl(optimizer = "bobyqa",
                                           optCtrl = list(maxfun = 2e5)))
}, warning = function(w) {
  message(sprintf("  GLMM warning: %s", conditionMessage(w)))
  suppressWarnings(
    lme4::glmer(survived ~ log_size + years_since_outplant + (1 | study),
                data = df, family = binomial,
                control = lme4::glmerControl(optimizer = "bobyqa",
                                             optCtrl = list(maxfun = 2e5))))
}, error = function(e) {
  message(sprintf("  GLMM failed (%s); falling back to GLM.", conditionMessage(e)))
  glm(survived ~ log_size + years_since_outplant, data = df, family = binomial)
})

is_glmm <- inherits(fit, "merMod")
cat(sprintf("  Fit class: %s\n", paste(class(fit), collapse = ", ")))

# =============================================================================
# Overdispersion check
# =============================================================================
od_ratio <- NA_real_
if (is_glmm) {
  od <- tryCatch(overdisp_test(fit), error = function(e) NULL)
  if (!is.null(od)) {
    od_ratio <- od$ratio
    cat(sprintf("  Overdispersion ratio: %.3f (p=%.3g)\n",
                od$ratio, od$p_value))
    if (isTRUE(od$overdispersed)) {
      print_warn(sprintf("Potential overdispersion (ratio=%.2f > 1.5)", od$ratio))
    }
  }
} else {
  pr <- residuals(fit, type = "pearson")
  od_ratio <- sum(pr^2) / (length(pr) - length(coef(fit)))
  cat(sprintf("  GLM pseudo-overdispersion ratio: %.3f\n", od_ratio))
  if (od_ratio > 1.5) print_warn("Potential overdispersion")
}

# =============================================================================
# Coefficient summary
# =============================================================================
coef_mat <- if (is_glmm) summary(fit)$coefficients else summary(fit)$coefficients
coef_summary <- as.data.frame(coef_mat)
coef_summary$term <- rownames(coef_summary)
print(coef_summary)

# =============================================================================
# Predict per-size-class survival at years_since_outplant = 0 and 2
# =============================================================================
print_subheader("Predict revised survival vector at years_since_outplant = 0 and 2")

# Representative within-SC sizes (geometric means of SIZE_BREAKS)
sc_mid <- c(SC1 = sqrt(1 * 10),
            SC2 = sqrt(10 * 100),
            SC3 = sqrt(100 * 900),
            SC4 = sqrt(900 * 4000),
            SC5 = sqrt(4000 * 20000))  # cap SC5 at 20000 cm^2 for prediction

predict_S <- function(years) {
  newd <- data.frame(log_size = log(sc_mid + 1),
                     years_since_outplant = years,
                     study = df$study[1])
  if (is_glmm) {
    lp <- predict(fit, newdata = newd, re.form = NA, type = "link")
  } else {
    lp <- predict(fit, newdata = newd, type = "link")
  }
  p <- plogis(lp)
  names(p) <- SIZE_LABELS
  p
}

S_year0 <- predict_S(0)
S_year2 <- predict_S(2)

# Comparison table: baseline (rma-pooled) vs model at y=0 vs model at y=2
cmp <- data.frame(
  size_class   = SIZE_LABELS,
  baseline     = round(baseline_S, 4),
  model_year_0 = round(S_year0, 4),
  model_year_2 = round(S_year2, 4),
  delta_y2_vs_baseline = round(S_year2 - baseline_S, 4)
)
print(cmp)

# =============================================================================
# Save
# =============================================================================
out <- list(
  baseline = baseline_S,
  year_0   = S_year0,
  year_2   = S_year2,
  coef_summary = coef_summary,
  overdispersion_ratio = od_ratio,
  n_used = nrow(df),
  note   = if (is_glmm) "GLMM fit" else "GLM fallback (no random effect)"
)
saveRDS(out, file.path(output_dir, "outplant_age_survival.rds"))
print_success("Saved 06_analysis/output/outplant_age_survival.rds")

cat("Done.\n")
