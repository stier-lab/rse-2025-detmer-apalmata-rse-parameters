################################################################################
# 57_winter_sst_survival_model.R - Winter SST driver on survival (Idea 5)
################################################################################
#
# PURPOSE:
#   Layer winter SST anomaly (proxy for over-winter disease pressure) as a
#   size-interacting covariate on survival. Produces a revised survival
#   vector under a "mild winter" regime (+1 C anomaly) to feed the scenario
#   pipeline (script 60).
#
# CITATIONS:
#   Rosales 2024             -- microbiome disruption above 31 C.
#   Rodriguez-Martinez 2014  -- disease prevalence 0% small vs 48% large.
#
# HYPOTHESIS:
#   Warmer winters suppress over-winter microbiome recovery and elevate disease
#   prevalence in larger colonies; survival declines with positive winter
#   anomalies, and the effect is stronger for large size classes.
#
# INPUTS:
#   - 05_data/standardized/apal_surv_ind.csv
#   - 05_data/standardized/winter_sst_anomalies.csv
#   - 06_analysis/output/transition_matrix.rds (baseline S)
#
# GRACEFUL DEGRADATION:
#   winter_sst_anomalies.csv currently contains data_source ==
#   "synthetic_placeholder" rows with NA anomalies (pending NOAA API refresh).
#   If >=80% of joined rows have NA winter_anomaly_c, the analysis is
#   non-informative; we save a placeholder RDS with baseline unchanged.
#
# OUTPUT:
#   06_analysis/output/winter_sst_survival.rds
#     list(baseline, mild_winter, coef_summary, n_used, note)
#
# Author: Detmer & Stier Lab
# Date:   2026-04-17
################################################################################

source("06_analysis/scripts/utils/shared_utilities.R")

print_header("Script 57: Winter SST survival model (Idea 5)")

output_dir <- "06_analysis/output"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# Load baseline survival
# =============================================================================
trans <- readRDS(file.path(output_dir, "transition_matrix.rds"))
baseline_S <- trans$survival_rates
if (is.null(baseline_S) || length(baseline_S) != 5) baseline_S <- trans$survival
names(baseline_S) <- SIZE_LABELS
print_success(sprintf("Baseline S loaded: %s",
                      paste(sprintf("%.3f", baseline_S), collapse = ", ")))

# =============================================================================
# Load + join survival and winter SST
# =============================================================================
surv <- read.csv("05_data/standardized/apal_surv_ind.csv",
                 stringsAsFactors = FALSE)
wsst <- read.csv("05_data/standardized/winter_sst_anomalies.csv",
                 stringsAsFactors = FALSE)

cat(sprintf("  Survival rows: %d\n", nrow(surv)))
cat(sprintf("  Winter-SST rows: %d (sources: %s)\n",
            nrow(wsst),
            paste(unique(wsst$data_source), collapse = ", ")))

df <- surv %>%
  dplyr::filter(!is.na(survived), !is.na(size_cm2), size_cm2 > 0) %>%
  dplyr::left_join(
    dplyr::select(wsst, region, year, winter_anomaly_c, data_source),
    by = c("region" = "region", "survey_yr" = "year")
  )

n_total <- nrow(df)
n_na    <- sum(is.na(df$winter_anomaly_c))
frac_na <- if (n_total > 0) n_na / n_total else 1
cat(sprintf("  Joined rows: %d; rows missing winter anomaly: %d (%.1f%%)\n",
            n_total, n_na, 100 * frac_na))

save_placeholder <- function(note_text) {
  out <- list(
    baseline     = baseline_S,
    mild_winter  = baseline_S,
    coef_summary = NULL,
    n_used       = 0L,
    note         = note_text
  )
  saveRDS(out, file.path(output_dir, "winter_sst_survival.rds"))
  print_warn(sprintf("Saved placeholder: %s", note_text))
}

# =============================================================================
# Placeholder branch: too much missing SST data
# =============================================================================
if (frac_na >= 0.80 || n_total - n_na < 50) {
  print_warn(sprintf(
    "%.1f%% of joined rows missing winter_anomaly_c. Analysis is non-informative.",
    100 * frac_na))
  save_placeholder("Winter SST data unavailable; using baseline")
  cat("Done.\n"); quit(save = "no", status = 0)
}

# =============================================================================
# Real fit (only reached when SST data exist)
# =============================================================================
df_fit <- df %>% dplyr::filter(!is.na(winter_anomaly_c))
df_fit$log_size <- log(df_fit$size_cm2 + 1)
df_fit$study    <- as.factor(df_fit$study)
cat(sprintf("  Rows used for model: %d\n", nrow(df_fit)))

print_subheader("Fit: survived ~ log(size) * winter_anomaly_c + (1|study)")
fit <- tryCatch({
  lme4::glmer(survived ~ log_size * winter_anomaly_c + (1 | study),
              data = df_fit, family = binomial,
              control = lme4::glmerControl(optimizer = "bobyqa",
                                           optCtrl = list(maxfun = 2e5)))
}, error = function(e) {
  message(sprintf("  GLMM failed (%s); falling back to GLM.", conditionMessage(e)))
  glm(survived ~ log_size * winter_anomaly_c, data = df_fit, family = binomial)
})

is_glmm <- inherits(fit, "merMod")

# Overdispersion
od_ratio <- NA_real_
if (is_glmm) {
  od <- tryCatch(overdisp_test(fit), error = function(e) NULL)
  if (!is.null(od)) {
    od_ratio <- od$ratio
    cat(sprintf("  Overdispersion ratio: %.3f\n", od$ratio))
    if (isTRUE(od$overdispersed)) print_warn("Potential overdispersion")
  }
}

coef_mat <- summary(fit)$coefficients
coef_summary <- as.data.frame(coef_mat)
coef_summary$term <- rownames(coef_summary)
print(coef_summary)

# Predict at baseline (0 C anomaly) vs mild winter (+1 C anomaly)
sc_mid <- c(SC1 = sqrt(1 * 10),
            SC2 = sqrt(10 * 100),
            SC3 = sqrt(100 * 900),
            SC4 = sqrt(900 * 4000),
            SC5 = sqrt(4000 * 20000))

predict_S <- function(anom) {
  newd <- data.frame(log_size = log(sc_mid + 1),
                     winter_anomaly_c = anom,
                     study = df_fit$study[1])
  lp <- if (is_glmm) predict(fit, newdata = newd, re.form = NA, type = "link") else
    predict(fit, newdata = newd, type = "link")
  p <- plogis(lp); names(p) <- SIZE_LABELS; p
}

S_zero <- predict_S(0)
S_mild <- predict_S(1)

cmp <- data.frame(
  size_class    = SIZE_LABELS,
  baseline      = round(baseline_S, 4),
  model_anom_0  = round(S_zero, 4),
  mild_winter_plus1 = round(S_mild, 4),
  delta_mild_vs_baseline = round(S_mild - baseline_S, 4)
)
print(cmp)

out <- list(
  baseline     = baseline_S,
  mild_winter  = S_mild,
  anom_0       = S_zero,
  coef_summary = coef_summary,
  overdispersion_ratio = od_ratio,
  n_used       = nrow(df_fit),
  note         = if (is_glmm) "GLMM fit with real SST data" else
                 "GLM fallback with real SST data"
)
saveRDS(out, file.path(output_dir, "winter_sst_survival.rds"))
print_success("Saved 06_analysis/output/winter_sst_survival.rds")
cat("Done.\n")
