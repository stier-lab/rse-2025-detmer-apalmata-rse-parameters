#!/usr/bin/env Rscript
################################################################################
# 37b_DISTURBANCE_TYPE_SIZE_INTERACTION.R
# Do different disturbance TYPES differentially affect different size classes?
################################################################################
#
# PURPOSE:
#   Script 37 tests size x disturbance using three generic curated STATES
#   (none / chronic-context / acute). This script asks the sharper question:
#   do the *distinct disturbance types* -- storm, disease, and heatwave --
#   each reshape the size-survival relationship of Acropora palmata in a
#   different way?
#
#   Three types, three hypothesised size signatures:
#     - STORM    : mechanical breakage of large branching colonies should
#                  FLATTEN the size-survival slope (erode the big-is-safer rule).
#     - DISEASE  : tissue-loss mortality as a downward LEVEL shift; large
#                  colonies act as partial-mortality refugia (gradient intact).
#     - HEATWAVE : gradient persists at moderate DHW but the size refuge should
#                  COLLAPSE at catastrophic DHW (Manzello et al. 2025).
#
# DESIGN / DATA FOOTING (read before interpreting):
#   - Storm & disease are attributed at the COLONY level via the `disturbance`
#     column of apal_surv_ind.csv (storm = NOAA intervals; disease = Neely 2014
#     FKNMS catastrophe + aftermath). Both studies ALSO contribute undisturbed
#     ("none") intervals, so the disturbance effect is partly identified WITHIN
#     study via the (1|study) random effect -- but type remains confounded with
#     study/region/method. State this in the manuscript.
#   - Heatwave is attributed OBSERVATIONALLY by overlapping survival study-years
#     with documented bleaching events (caribbean_disturbance_events.csv) and
#     their satellite DHW. Weaker causal footing than the colony flags:
#       (i)  DHW is recorded as ranges -> midpoint used.
#       (ii) 2014 FL Keys is BOTH the Neely disease event AND a bleaching year;
#            disease-flagged colonies are EXCLUDED from the thermal model to
#            avoid conflating the two.
#      (iii) This synthesis's 2023 FL Keys survival (~0.2-0.74) is far higher
#            than Manzello's reported 98-100% mortality -- the monitoring data
#            under-captures the true catastrophe (likely survivor-biased sites).
#
# LINK TO THE POPULATION MODEL:
#   Script 40 applies heatwave mortality as a SIZE-UNIFORM scalar multiplier.
#   The results here indicate that is defensible only at catastrophic DHW (where
#   the refuge collapses); at moderate DHW the size gradient persists, so a
#   size-uniform pulse over-kills large colonies. Flagged as a limitation; not
#   modified in this round.
#
# INPUTS:
#   - 05_data/standardized/apal_surv_ind.csv
#   - 05_data/standardized/caribbean_disturbance_events.csv
#
# OUTPUTS:
#   - 06_analysis/output/disturbance_type_size_survival_summary.csv
#   - 06_analysis/output/disturbance_type_size_model_terms.csv
#   - 06_analysis/output/disturbance_type_size_slopes.csv
#   - 06_analysis/output/disturbance_type_heatwave_dhw.csv
#   - 06_analysis/output/disturbance_type_size_summary_stats.csv
#   - 06_analysis/figures/supplementary/FigS30_disturbance_type_size.(png|pdf)
#
# Author: Detmer & Stier Lab
# Date: 2026-07-21
################################################################################

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr)
  library(ggplot2); library(patchwork); library(lme4); library(scales)
})

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

set.seed(42)
project_root <- get_project_root()
dirs <- setup_output_dirs()
output_dir <- dirs$output
fig_dir    <- dirs$figures_supp
pal <- MANUSCRIPT_PALETTE

print_header("37b: DISTURBANCE TYPE x SIZE CLASS")

## Size-class midpoints for prediction / plotting (cm^2)
SC_MID <- c(SC1 = 5, SC2 = 55, SC3 = 500, SC4 = 2450, SC5 = 8000)

## Palette: baseline grey, disease vermillion, storm blue (Okabe-Ito)
type_cols <- c(none = "#7f7f7f", disease = "#D55E00", storm = "#0072B2")
type_labs <- c(none = "No disturbance", disease = "Disease (Neely 2014)",
               storm = "Storm (NOAA)")

# =============================================================================
# Load natural-colony survival, assign size classes and disturbance type
# =============================================================================
surv <- read_csv(file.path(project_root, "05_data/standardized/apal_surv_ind.csv"),
                 show_col_types = FALSE) %>%
  filter(is.na(fragment) | fragment != "Y") %>%                      # natural only
  mutate(size_use = ifelse(is.na(size_live_cm2), size_cm2, size_live_cm2)) %>%
  filter(!is.na(size_use), size_use > 0, !is.na(survived)) %>%
  mutate(
    log_size   = log(size_use),
    size_class = factor(cut(size_use, SIZE_BREAKS, SIZE_LABELS),
                        levels = SIZE_LABELS),
    dist_type  = factor(case_when(grepl("disease", disturbance) ~ "disease",
                                  disturbance == "storm"          ~ "storm",
                                  TRUE                            ~ "none"),
                        levels = c("none", "disease", "storm"))
  )
cat(sprintf("  Natural survival obs: %d (none=%d, disease=%d, storm=%d)\n\n",
            nrow(surv), sum(surv$dist_type == "none"),
            sum(surv$dist_type == "disease"), sum(surv$dist_type == "storm")))

# =============================================================================
# PART A -- Colony-flagged types: storm vs disease vs none
# =============================================================================
print_subheader("Part A: storm / disease / none (colony-flagged)")

## Descriptive survival by type x size class (Wilson CI)
surv_summary <- surv %>%
  group_by(dist_type, size_class) %>%
  summarise(n = n(), n_surv = sum(survived), survival = mean(survived),
            .groups = "drop") %>%
  rowwise() %>%
  mutate(ci = list(wilson_ci(n_surv, n)),
         ci_lower = ci$lower, ci_upper = ci$upper) %>%
  ungroup() %>% select(-ci)
write_csv(surv_summary,
          file.path(output_dir, "disturbance_type_size_survival_summary.csv"))

## Interaction GLMM (additive vs interaction; LRT for size x type)
m_add <- glmer(survived ~ log_size + dist_type + (1 | study), family = binomial,
               data = surv,
               control = glmerControl(optimizer = "bobyqa",
                                      optCtrl = list(maxfun = 2e5)))
m_int <- glmer(survived ~ log_size * dist_type + (1 | study), family = binomial,
               data = surv,
               control = glmerControl(optimizer = "bobyqa",
                                      optCtrl = list(maxfun = 2e5)))
lrt <- anova(m_add, m_int)
lrt_chisq <- lrt$Chisq[2]; lrt_df <- lrt$Df[2]; lrt_p <- lrt$`Pr(>Chisq)`[2]

## Required overdispersion check (CLAUDE.md)
od <- overdisp_test(m_int)
cat(sprintf("  Interaction LRT: chisq=%.2f df=%d p=%.3g | overdispersion ratio=%.3f (%s)\n",
            lrt_chisq, lrt_df, lrt_p, od$ratio,
            ifelse(od$overdispersed, "FLAG", "ok")))

## Fixed-effect terms
terms_tab <- as.data.frame(summary(m_int)$coefficients)
terms_tab$term <- rownames(terms_tab); rownames(terms_tab) <- NULL
names(terms_tab)[1:4] <- c("estimate", "std_error", "z", "p_value")
write_csv(terms_tab, file.path(output_dir, "disturbance_type_size_model_terms.csv"))

## Size-survival SLOPE per type via linear combinations of fixef + vcov
b <- fixef(m_int); V <- as.matrix(vcov(m_int)); nm <- names(b)
mkc <- function(vec) { c <- setNames(numeric(length(nm)), nm); c[names(vec)] <- vec; c }
slope_defs <- list(
  none    = mkc(c(log_size = 1)),
  disease = mkc(c(log_size = 1, "log_size:dist_typedisease" = 1)),
  storm   = mkc(c(log_size = 1, "log_size:dist_typestorm"   = 1)))
slopes <- do.call(rbind, lapply(names(slope_defs), function(t) {
  cv <- slope_defs[[t]]; est <- sum(cv * b); se <- sqrt(as.numeric(t(cv) %*% V %*% cv))
  data.frame(dist_type = t, slope = est, se = se,
             ci_lower = est - 1.96 * se, ci_upper = est + 1.96 * se,
             p_value = 2 * pnorm(-abs(est / se)))
}))
## Pairwise slope contrasts (difference in size-survival slope)
pair_defs <- list(
  `disease-none`  = mkc(c("log_size:dist_typedisease" = 1)),
  `storm-none`    = mkc(c("log_size:dist_typestorm"   = 1)),
  `disease-storm` = mkc(c("log_size:dist_typedisease" = 1,
                          "log_size:dist_typestorm"   = -1)))
slope_pairs <- do.call(rbind, lapply(names(pair_defs), function(t) {
  cv <- pair_defs[[t]]; est <- sum(cv * b); se <- sqrt(as.numeric(t(cv) %*% V %*% cv))
  data.frame(contrast = t, diff = est, se = se, z = est / se,
             p_value = 2 * pnorm(-abs(est / se)))
}))
write_csv(bind_rows(slopes %>% mutate(kind = "slope"),
                    slope_pairs %>% rename(dist_type = contrast, slope = diff) %>%
                      mutate(kind = "contrast", ci_lower = NA, ci_upper = NA) %>%
                      select(dist_type, slope, se, ci_lower, ci_upper, p_value, kind)),
          file.path(output_dir, "disturbance_type_size_slopes.csv"))
cat("  Size-survival slopes (log-odds / log cm^2):\n")
print(slopes %>% mutate(across(where(is.numeric), ~round(., 3))), row.names = FALSE)
cat("  Pairwise slope contrasts:\n")
print(slope_pairs %>% mutate(across(where(is.numeric), ~round(., 3))), row.names = FALSE)

## Predicted survival curves (each type over its observed size range)
type_ranges <- surv %>% group_by(dist_type) %>%
  summarise(lo = min(size_use), hi = max(size_use), .groups = "drop")
pred_A <- do.call(rbind, lapply(levels(surv$dist_type), function(t) {
  rg <- type_ranges %>% filter(dist_type == t)
  xs <- exp(seq(log(rg$lo), log(rg$hi), length.out = 160))
  nd <- data.frame(size_use = xs, log_size = log(xs),
                   dist_type = factor(t, levels = levels(surv$dist_type)))
  X <- model.matrix(delete.response(terms(m_int)), nd)
  eta <- as.numeric(X %*% b); se <- sqrt(rowSums((X %*% V) * X))
  nd %>% mutate(pred = plogis(eta),
                lo = plogis(eta - 1.96 * se), hi = plogis(eta + 1.96 * se))
}))

# =============================================================================
# PART B -- Heatwave: observational bleaching-year DHW x size
# =============================================================================
print_subheader("Part B: heatwave / DHW (observational overlap)")

## Robust DHW-range midpoint (handles "16-24", "7.7", "8-12")
dhw_mid <- function(x) {
  nums <- as.numeric(unlist(regmatches(x, gregexpr("[0-9.]+", x))))
  if (length(nums) == 0) NA_real_ else mean(nums)
}
bleach <- read_csv(file.path(project_root,
                             "05_data/standardized/caribbean_disturbance_events.csv"),
                   show_col_types = FALSE) %>%
  filter(event_type == "bleaching") %>%
  mutate(dhw = vapply(dhw_satellite, dhw_mid, numeric(1))) %>%
  transmute(region, survey_yr = year, dhw, severity)

## Exclude disease-flagged colonies to avoid the 2014 disease/thermal confound
heat <- surv %>%
  filter(dist_type != "disease") %>%
  inner_join(bleach, by = c("region", "survey_yr")) %>%
  filter(!is.na(dhw)) %>%
  mutate(dhw_band = cut(dhw, c(0, 10, Inf),
                        labels = c("Moderate (DHW<10)", "Severe (DHW>=10)")))
cat(sprintf("  Natural, non-disease obs in bleaching years: %d (DHW %.1f-%.1f)\n",
            nrow(heat), min(heat$dhw), max(heat$dhw)))

heat_summary <- heat %>%
  group_by(dhw_band, size_class) %>%
  summarise(n = n(), n_surv = sum(survived), survival = mean(survived),
            .groups = "drop") %>%
  rowwise() %>%
  mutate(ci = list(wilson_ci(n_surv, n)),
         ci_lower = ci$lower, ci_upper = ci$upper) %>%
  ungroup() %>% select(-ci)
write_csv(heat_summary,
          file.path(output_dir, "disturbance_type_heatwave_dhw.csv"))
cat("  Survival by DHW band x size class:\n")
print(heat_summary %>% mutate(across(where(is.numeric), ~round(., 3))),
      row.names = FALSE)

## DHW x size interaction GLMM (continuous, scaled DHW)
heat <- heat %>% mutate(dhw_c = as.numeric(scale(dhw)))
heat_lrt_p <- NA_real_; heat_int_beta <- NA_real_; heat_int_p <- NA_real_
if (dplyr::n_distinct(heat$study) >= 2 && nrow(heat) > 50) {
  hm_add <- glmer(survived ~ log_size + dhw_c + (1 | study), family = binomial,
                  data = heat, control = glmerControl(optimizer = "bobyqa",
                                                      optCtrl = list(maxfun = 2e5)))
  hm_int <- glmer(survived ~ log_size * dhw_c + (1 | study), family = binomial,
                  data = heat, control = glmerControl(optimizer = "bobyqa",
                                                      optCtrl = list(maxfun = 2e5)))
  h_lrt <- anova(hm_add, hm_int)
  heat_lrt_p <- h_lrt$`Pr(>Chisq)`[2]
  ic <- summary(hm_int)$coefficients
  heat_int_beta <- ic["log_size:dhw_c", "Estimate"]
  heat_int_p    <- ic["log_size:dhw_c", "Pr(>|z|)"]
  cat(sprintf("  DHW x size interaction: beta=%.3f p=%.3g (LRT p=%.3g)\n",
              heat_int_beta, heat_int_p, heat_lrt_p))
  cat("    (negative beta = size advantage erodes as DHW rises)\n")
}

# =============================================================================
# Summary-stats CSV (single row of headline numbers)
# =============================================================================
summary_stats <- tibble::tibble(
  interaction_lrt_chisq = lrt_chisq, interaction_lrt_df = lrt_df,
  interaction_lrt_p = lrt_p, overdispersion_ratio = od$ratio,
  slope_none = slopes$slope[slopes$dist_type == "none"],
  slope_disease = slopes$slope[slopes$dist_type == "disease"],
  slope_storm = slopes$slope[slopes$dist_type == "storm"],
  storm_vs_none_slope_p = slope_pairs$p_value[slope_pairs$contrast == "storm-none"],
  disease_vs_none_slope_p = slope_pairs$p_value[slope_pairs$contrast == "disease-none"],
  heatwave_dhwXsize_beta = heat_int_beta, heatwave_dhwXsize_p = heat_int_p,
  n_natural = nrow(surv), n_heatwave = nrow(heat))
write_csv(summary_stats,
          file.path(output_dir, "disturbance_type_size_summary_stats.csv"))

# =============================================================================
# FIGURE FigS30 -- three-panel size differential by disturbance type
# =============================================================================
print_subheader("Figure FigS30")

obs_pts <- surv_summary %>%
  mutate(mid = SC_MID[as.character(size_class)])

## Panel a (full width): predicted survival vs size, storm/disease/none
pa <- ggplot(pred_A, aes(size_use, pred, color = dist_type, fill = dist_type)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, color = NA) +
  geom_line(linewidth = 0.9) +
  geom_point(data = obs_pts, aes(mid, survival, size = n),
             alpha = 0.75, inherit.aes = TRUE) +
  scale_x_log10(breaks = c(10, 100, 1000, 10000),
                labels = c("10", "100", "1,000", "10,000")) +
  scale_color_manual(values = type_cols, labels = type_labs, name = NULL) +
  scale_fill_manual(values = type_cols, guide = "none") +
  scale_size_area(max_size = 4.5, name = "n colonies") +
  coord_cartesian(ylim = c(0, 1)) +
  labs(x = expression("Colony size (cm"^2*", log scale)"),
       y = "Annual survival") +
  guides(color = guide_legend(order = 1, nrow = 1),
         size  = guide_legend(order = 2, nrow = 1)) +
  theme_manuscript(base_size = 9) +
  theme(legend.position = "top", legend.box = "horizontal",
        legend.key.size = unit(3.5, "mm"), legend.margin = margin(0, 0, 0, 0))

## Panel b: survival differential from baseline by size class
base_sc <- surv_summary %>% filter(dist_type == "none") %>%
  select(size_class, base = survival)
diff_b <- surv_summary %>% filter(dist_type != "none") %>%
  left_join(base_sc, by = "size_class") %>%
  mutate(delta = (survival - base) * 100,
         dist_type = factor(dist_type, levels = c("disease", "storm")),
         reliable = n >= 10)
pb <- ggplot(diff_b, aes(size_class, delta, fill = dist_type, alpha = reliable)) +
  geom_hline(yintercept = 0, color = "grey40", linewidth = 0.4) +
  geom_col(position = position_dodge(width = 0.7), width = 0.62) +
  geom_text(aes(label = sprintf("%+.0f", delta),
                vjust = ifelse(delta >= 0, -0.3, 1.2)),
            position = position_dodge(width = 0.7), size = 2.4, alpha = 1) +
  scale_fill_manual(values = unname(type_cols[c("disease", "storm")]),
                    labels = c("Disease", "Storm"), name = NULL) +
  scale_alpha_manual(values = c(`TRUE` = 1, `FALSE` = 0.3), guide = "none") +
  coord_cartesian(ylim = c(-50, 12)) +
  labs(x = "Size class", y = "Survival vs\nbaseline (pp)") +
  theme_manuscript(base_size = 9) +
  theme(legend.position = "top", legend.key.size = unit(3.5, "mm"))

## Panel c: heatwave -- survival by size across DHW bands
pc <- ggplot(heat_summary,
             aes(size_class, survival, color = dhw_band, group = dhw_band)) +
  geom_line(linewidth = 0.8) +
  geom_pointrange(aes(ymin = ci_lower, ymax = ci_upper), size = 0.3) +
  scale_color_manual(values = c("Moderate (DHW<10)" = "#E69F00",
                                "Severe (DHW>=10)" = "#7A0403"), name = NULL) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(x = "Size class", y = "Annual survival") +
  theme_manuscript(base_size = 9) +
  theme(legend.position = "top", legend.key.size = unit(3.5, "mm"))

fig <- (pa / (pb | pc)) + plot_layout(heights = c(1, 1)) +
  plot_annotation(tag_levels = "a") &
  theme(plot.tag = element_text(face = "bold"))

save_manuscript_fig(fig, "FigS30_disturbance_type_size",
                    width_mm = 174, height_mm = 150, fig_dir = fig_dir)

cat("\nSUMMARY:\n")
cat(sprintf("  Interaction LRT p = %.3g | storm-none slope p = %.3g | disease-none slope p = %.3g\n",
            lrt_p, slope_pairs$p_value[slope_pairs$contrast == "storm-none"],
            slope_pairs$p_value[slope_pairs$contrast == "disease-none"]))
cat(sprintf("  Heatwave DHWxsize beta = %.3f (p = %.3g)\n", heat_int_beta, heat_int_p))
cat("Completed disturbance-TYPE x size-class analysis.\n")
