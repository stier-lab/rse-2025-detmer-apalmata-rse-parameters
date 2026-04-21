################################################################################
# 59_microhabitat_depth_model.R - Depth covariate on survival (Idea 8)
################################################################################
#
# PURPOSE:
#   Fit a survival GLMM with depth_m as a covariate to quantify the shallow /
#   deep microhabitat contrast, then produce revised survival vectors for
#   "shallow" (2 m, high flow) vs "deep" (10 m) conditions to feed the
#   scenario-comparison pipeline (script 60).
#
# CITATIONS:
#   Ramos-Romero 2025 -- flow-driven growth (+7.3 vs -1.5 cm/yr).
#   Kuffner et al. 2020 -- calcification 7.9 vs 4.2 g/m^2/day.
#
# HYPOTHESIS:
#   Shallow high-flow microhabitats favour A. palmata survival (reduced
#   disease/sediment stress, elevated calcification). Deeper sites trend
#   toward lower survival at a given size.
#
# INPUTS:
#   - 05_data/standardized/apal_surv_ind.csv (must contain depth_m)
#   - 06_analysis/output/transition_matrix.rds (baseline S)
#
# OUTPUT:
#   06_analysis/output/microhabitat_depth_survival.rds
#     list(baseline, shallow, deep, coef_summary,
#          overdispersion_ratio, n_used, note)
#
# Author: Detmer & Stier Lab
# Date:   2026-04-17
################################################################################

source("06_analysis/scripts/utils/shared_utilities.R")

print_header("Script 59: Microhabitat (depth) survival model (Idea 8)")

output_dir <- "06_analysis/output"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# Baseline
# =============================================================================
trans <- readRDS(file.path(output_dir, "transition_matrix.rds"))
baseline_S <- trans$survival_rates
if (is.null(baseline_S) || length(baseline_S) != 5) baseline_S <- trans$survival
names(baseline_S) <- SIZE_LABELS
print_success(sprintf("Baseline S loaded: %s",
                      paste(sprintf("%.3f", baseline_S), collapse = ", ")))

# =============================================================================
# Load survival data with depth
# =============================================================================
surv <- read.csv("05_data/standardized/apal_surv_ind.csv",
                 stringsAsFactors = FALSE)
cat(sprintf("  Survival rows: %d\n", nrow(surv)))

df <- surv %>%
  dplyr::filter(!is.na(survived),
                !is.na(size_cm2), size_cm2 > 0,
                !is.na(depth_m))
cat(sprintf("  Rows retained with valid depth_m: %d\n", nrow(df)))
cat(sprintf("  Depth range: %.2f to %.2f m (median = %.2f m)\n",
            min(df$depth_m), max(df$depth_m), median(df$depth_m)))

if (nrow(df) < 50 || length(unique(df$depth_m)) < 3) {
  warning("Too few rows or depth levels; saving placeholder.")
  placeholder <- list(
    baseline = baseline_S, shallow = baseline_S, deep = baseline_S,
    coef_summary = NULL, overdispersion_ratio = NA_real_,
    n_used = nrow(df),
    note = "Insufficient depth data; baseline survival unchanged"
  )
  saveRDS(placeholder, file.path(output_dir, "microhabitat_depth_survival.rds"))
  print_warn("Saved placeholder microhabitat_depth_survival.rds")
  cat("Done.\n"); quit(save = "no", status = 0)
}

df$log_size <- log(df$size_cm2 + 1)
df$study <- as.factor(df$study)

# =============================================================================
# Fit GLMM with GLM fallback
# =============================================================================
print_subheader("Fit: survived ~ log(size) + depth_m + (1|study)")

fit <- tryCatch({
  lme4::glmer(survived ~ log_size + depth_m + (1 | study),
              data = df, family = binomial,
              control = lme4::glmerControl(optimizer = "bobyqa",
                                           optCtrl = list(maxfun = 2e5)))
}, error = function(e) {
  message(sprintf("  GLMM failed (%s); falling back to GLM.", conditionMessage(e)))
  glm(survived ~ log_size + depth_m, data = df, family = binomial)
})

is_glmm <- inherits(fit, "merMod")
cat(sprintf("  Fit class: %s\n", paste(class(fit), collapse = ", ")))

# Overdispersion
od_ratio <- NA_real_
if (is_glmm) {
  od <- tryCatch(overdisp_test(fit), error = function(e) NULL)
  if (!is.null(od)) {
    od_ratio <- od$ratio
    cat(sprintf("  Overdispersion ratio: %.3f (p=%.3g)\n",
                od$ratio, od$p_value))
    if (isTRUE(od$overdispersed)) print_warn("Potential overdispersion (>1.5)")
  }
} else {
  pr <- residuals(fit, type = "pearson")
  od_ratio <- sum(pr^2) / (length(pr) - length(coef(fit)))
  cat(sprintf("  GLM pseudo-overdispersion ratio: %.3f\n", od_ratio))
}

coef_summary <- as.data.frame(summary(fit)$coefficients)
coef_summary$term <- rownames(coef_summary)
print(coef_summary)

# =============================================================================
# Predict: shallow (2 m) vs deep (10 m)
# =============================================================================
sc_mid <- c(SC1 = sqrt(1 * 10),
            SC2 = sqrt(10 * 100),
            SC3 = sqrt(100 * 900),
            SC4 = sqrt(900 * 4000),
            SC5 = sqrt(4000 * 20000))

predict_S <- function(depth) {
  newd <- data.frame(log_size = log(sc_mid + 1),
                     depth_m = depth,
                     study = df$study[1])
  lp <- if (is_glmm) predict(fit, newdata = newd, re.form = NA, type = "link") else
    predict(fit, newdata = newd, type = "link")
  p <- plogis(lp); names(p) <- SIZE_LABELS; p
}

S_shallow <- predict_S(2)
S_deep    <- predict_S(10)

cmp <- data.frame(
  size_class     = SIZE_LABELS,
  baseline       = round(baseline_S, 4),
  shallow_2m     = round(S_shallow, 4),
  deep_10m       = round(S_deep, 4),
  delta_shallow_deep = round(S_shallow - S_deep, 4)
)
cat("\n  Survival by size class: baseline vs shallow (2 m) vs deep (10 m):\n")
print(cmp)

# =============================================================================
# Save
# =============================================================================
out <- list(
  baseline       = baseline_S,
  shallow        = S_shallow,
  deep           = S_deep,
  coef_summary   = coef_summary,
  overdispersion_ratio = od_ratio,
  n_used         = nrow(df),
  note           = if (is_glmm) "GLMM fit with depth covariate" else
                   "GLM fallback (no random effect)"
)
saveRDS(out, file.path(output_dir, "microhabitat_depth_survival.rds"))
print_success("Saved 06_analysis/output/microhabitat_depth_survival.rds")

cat("Done.\n")
