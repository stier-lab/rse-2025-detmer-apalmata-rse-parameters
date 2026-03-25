#!/usr/bin/env Rscript
# =============================================================================
# FIGURE: SIZE-CLASS SURVIVAL SYNTHESIS — ALL AVAILABLE EVIDENCE
# =============================================================================
# Produces a single-panel publication figure showing annual survival by size
# class (SC1–SC5) across ALL available data: 6 individual-level studies +
# 9 summary-level studies = up to 15 unique studies spanning the Caribbean.
#
# Core story: survival increases with colony size, and we have multi-study
# evidence across the full size spectrum.
#
# Data processing:
#   1. Individual-level data (prepared_survival_data.rds): bin each obs into
#      SC1–SC5, compute study × size_class survival rate
#   2. Summary-level data (apal_surv_summ.csv): assign SC via midpoint of
#      reported size range, annualize survival, aggregate within study × SC
#   3. Combine into unified dataset
#   4. Compute pooled means (study-level, sqrt(n)-weighted) with 95% CI
#      via logit-scale normal approximation
#
# OUTPUT:
#   analysis/figures/manuscript/Fig4_size_class_survival.{png,pdf}
#   analysis/output/size_class_survival_synthesis.csv
#
# Author: Detmer & Stier Lab
# Date: 2026-02
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(patchwork)
  library(scales)
})

set.seed(42)

# Source shared utilities
if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("analysis/scripts/utils/shared_utilities.R")) {
  source("analysis/scripts/utils/shared_utilities.R")
}

pal <- MANUSCRIPT_PALETTE
project_root <- get_project_root()
output_dir  <- file.path(project_root, "analysis/output")
fig_dir     <- file.path(project_root, "analysis/figures/manuscript")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

print_header("SIZE-CLASS SURVIVAL SYNTHESIS FIGURE")

# =============================================================================
# 1. INDIVIDUAL-LEVEL DATA
# =============================================================================

print_subheader("Processing individual-level data")

surv_ind <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
cat(sprintf("  Loaded %s individual survival records from %d studies\n",
            comma(nrow(surv_ind)), n_distinct(surv_ind$study)))

# Ensure size_class is assigned
if (!"size_class" %in% names(surv_ind)) {
  surv_ind$size_class <- assign_size_class(surv_ind$size_cm2)
}

# Map population_type to cleaner labels for the figure
surv_ind <- surv_ind %>%
  mutate(
    pop_type = case_when(
      population_type == "Natural colony"       ~ "Natural",
      population_type == "Restoration fragment"  ~ "Restoration",
      TRUE                                       ~ "Unknown"
    )
  )

# Compute study × size_class survival rate
ind_study_sc <- surv_ind %>%
  filter(!is.na(size_class), !is.na(survived)) %>%
  group_by(study, size_class, pop_type) %>%
  summarise(
    n         = n(),
    n_survived = sum(survived),
    survival_rate = mean(survived),
    .groups = "drop"
  ) %>%
  mutate(data_tier = "Individual")

cat(sprintf("  Individual-level: %d study x size-class combinations\n", nrow(ind_study_sc)))
cat(sprintf("  Studies: %s\n", paste(sort(unique(ind_study_sc$study)), collapse = ", ")))

# =============================================================================
# 2. SUMMARY-LEVEL DATA
# =============================================================================

print_subheader("Processing summary-level data")

surv_summ <- read_csv(
  file.path(project_root, "standardized_data/apal_surv_summ.csv"),
  show_col_types = FALSE
)
cat(sprintf("  Loaded %d summary survival rows\n", nrow(surv_summ)))

# Exclusions per instructions:
#   - fundemar_recruits: lab-settled recruits, microscopic sizes (< 0.02 cm²)
#   - chamberland_et_al_2015: lab study, no size data
#   - mendoza_quiroz_et_al_2023 summary: already in individual data, lab-reared
#   - papke_et_al_2021: no usable size data
exclude_studies <- c("fundemar_recruits", "chamberland_et_al_2015",
                     "mendoza_quiroz_et_al_2023", "papke_et_al_2021")
surv_summ <- surv_summ %>% filter(!study %in% exclude_studies)
cat(sprintf("  After exclusions: %d rows from %d studies\n",
            nrow(surv_summ), n_distinct(surv_summ$study)))

# Also exclude studies already fully represented in individual-level data
# (to avoid double-counting). Individual studies: NOAA_survey, pausch_et_al_2018,
# USGS_USVI_exp, kuffner_et_al_2020, mendoza_quiroz_et_al_2023, fundemar_fragments
# Only mendoza_quiroz and fundemar were in summary; already excluded above.
# The rest are not in summary data. Confirm:
ind_studies <- unique(surv_ind$study)
overlap <- intersect(ind_studies, unique(surv_summ$study))
if (length(overlap) > 0) {
  cat(sprintf("  WARNING: Removing %d overlapping studies from summary: %s\n",
              length(overlap), paste(overlap, collapse = ", ")))
  surv_summ <- surv_summ %>% filter(!study %in% overlap)
}

# Assign size class to each summary row using best available size info
# Priority: size_cm2_mean > midpoint of (min, max) > skip
surv_summ <- surv_summ %>%
  mutate(
    size_midpoint = case_when(
      !is.na(size_cm2_mean) & size_cm2_mean > 0.1 ~ size_cm2_mean,
      !is.na(size_cm2_min) & !is.na(size_cm2_max) ~ (size_cm2_min + size_cm2_max) / 2,
      TRUE ~ NA_real_
    )
  )

# Drop rows where we can't determine size class
n_before <- nrow(surv_summ)
surv_summ <- surv_summ %>% filter(!is.na(size_midpoint))
cat(sprintf("  Dropped %d rows with no usable size info\n", n_before - nrow(surv_summ)))

# Assign size class
surv_summ$size_class <- assign_size_class(surv_summ$size_midpoint)

# Annualize survival: surv_annual = prop_survived^(1/time_interval_yr)
# Edge cases: if prop_survived = 0, annual = 0; if prop_survived = 1, annual = 1
surv_summ <- surv_summ %>%
  mutate(
    surv_annual = case_when(
      prop_survived <= 0  ~ 0,
      prop_survived >= 1  ~ 1,
      abs(time_interval_yr - 1) < 0.05 ~ prop_survived,  # already ~annual
      TRUE ~ prop_survived^(1 / time_interval_yr)
    )
  )

# Map population type: fragment=Y -> Restoration, fragment=N -> Natural
surv_summ <- surv_summ %>%
  mutate(
    pop_type = case_when(
      fragment == "Y" ~ "Restoration",
      fragment == "N" ~ "Natural",
      TRUE            ~ "Unknown"
    )
  )

# Aggregate within study × size_class: n-weighted mean survival, total n
# Some studies have multiple rows per size class (different sites, years, treatments)
summ_study_sc <- surv_summ %>%
  group_by(study, size_class, pop_type) %>%
  summarise(
    n             = sum(n_initial, na.rm = TRUE),
    n_survived    = sum(round(surv_annual * n_initial), na.rm = TRUE),
    survival_rate = weighted.mean(surv_annual, w = n_initial, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(data_tier = "Summary")

# Clamp survival_rate to [0, 1] (rounding can push slightly above)
summ_study_sc <- summ_study_sc %>%
  mutate(survival_rate = pmin(pmax(survival_rate, 0), 1))

cat(sprintf("  Summary-level: %d study x size-class combinations\n", nrow(summ_study_sc)))
cat(sprintf("  Studies: %s\n", paste(sort(unique(summ_study_sc$study)), collapse = ", ")))

# =============================================================================
# 3. COMBINE INTO UNIFIED DATASET
# =============================================================================

print_subheader("Combining data sources")

combined <- bind_rows(ind_study_sc, summ_study_sc) %>%
  # Ensure size_class is ordered factor
  mutate(size_class = factor(size_class, levels = SIZE_LABELS, ordered = TRUE))

cat(sprintf("  Combined dataset: %d study x size-class records\n", nrow(combined)))
cat(sprintf("  Total unique studies: %d\n", n_distinct(combined$study)))
cat(sprintf("  Studies: %s\n", paste(sort(unique(combined$study)), collapse = ", ")))

# Print coverage summary
coverage <- combined %>%
  group_by(size_class) %>%
  summarise(
    n_studies = n_distinct(study),
    total_n   = sum(n),
    .groups   = "drop"
  )
cat("\n  Size-class coverage:\n")
for (i in 1:nrow(coverage)) {
  cat(sprintf("    %s: k=%d studies, N=%s\n",
              coverage$size_class[i], coverage$n_studies[i], comma(coverage$total_n[i])))
}

# =============================================================================
# 4. POOLED ESTIMATES PER SIZE CLASS
# =============================================================================

print_subheader("Computing pooled size-class estimates")

# Use study-level estimates (not raw obs) to avoid NOAA dominating.
# Weight by sqrt(n) -- a compromise between equal weighting and n-weighting
# that gives smaller studies more voice without ignoring sample size entirely.
# When a study contributes multiple rows per SC (e.g., Natural + Restoration),
# we first average within study before pooling across studies.
# Compute 95% CI via normal approximation on logit scale, back-transform.

# First collapse to one estimate per study x size_class (average across pop_type)
study_sc_means <- combined %>%
  group_by(study, size_class) %>%
  summarise(
    survival_rate = weighted.mean(survival_rate, w = n),
    n = sum(n),
    .groups = "drop"
  )

pooled <- study_sc_means %>%
  group_by(size_class) %>%
  summarise(
    k         = n_distinct(study),
    n_points  = n(),
    total_n   = sum(n),
    # sqrt(n)-weighted mean
    pooled_surv = weighted.mean(survival_rate, w = sqrt(n)),
    .groups = "drop"
  )

# Compute CI via logit-scale sqrt(n)-weighted mean and SE
compute_logit_ci <- function(df) {
  eps <- 1e-4
  surv <- pmin(pmax(df$survival_rate, eps), 1 - eps)
  logit_surv <- log(surv / (1 - surv))
  wts <- sqrt(df$n)
  wts <- wts / sum(wts)

  logit_mean <- sum(logit_surv * wts)
  # Weighted SE on logit scale
  logit_var <- sum(wts * (logit_surv - logit_mean)^2)
  # Use effective sample size for SE
  n_eff <- length(surv)
  logit_se <- sqrt(logit_var / max(n_eff - 1, 1))

  # Back-transform
  ci_lo <- plogis(logit_mean - 1.96 * logit_se)
  ci_hi <- plogis(logit_mean + 1.96 * logit_se)
  mean_bt <- plogis(logit_mean)

  data.frame(pooled_surv_logit = mean_bt, ci_lo = ci_lo, ci_hi = ci_hi)
}

pooled_ci <- study_sc_means %>%
  group_by(size_class) %>%
  group_modify(~ compute_logit_ci(.x)) %>%
  ungroup()

pooled <- pooled %>%
  left_join(pooled_ci, by = "size_class") %>%
  mutate(
    # Use logit-transformed estimate as primary (more robust for proportions)
    pooled_surv = pooled_surv_logit
  ) %>%
  select(-pooled_surv_logit)

cat("\n  Pooled estimates:\n")
for (i in 1:nrow(pooled)) {
  cat(sprintf("    %s: survival = %.3f [%.3f, %.3f], k=%d, N=%s\n",
              pooled$size_class[i], pooled$pooled_surv[i],
              pooled$ci_lo[i], pooled$ci_hi[i],
              pooled$k[i], comma(pooled$total_n[i])))
}

# =============================================================================
# 5. SAVE UNDERLYING DATA
# =============================================================================

print_subheader("Saving output data")

# Full study-level data
write_csv(combined, file.path(output_dir, "size_class_survival_synthesis.csv"))
cat(sprintf("  Saved: size_class_survival_synthesis.csv (%d rows)\n", nrow(combined)))

# Pooled summary
write_csv(pooled, file.path(output_dir, "size_class_survival_synthesis_pooled.csv"))
cat(sprintf("  Saved: size_class_survival_synthesis_pooled.csv (%d rows)\n", nrow(pooled)))

# =============================================================================
# 6. BUILD FIGURE
# =============================================================================

print_subheader("Building figure")

# X-axis labels with size ranges using expression() for superscript cm^2
# We use bquote-style labels via scale_x_continuous with a label function
sc_labels_expr <- c(
  expression(atop("SC1", "0\u201310 cm"^2)),
  expression(atop("SC2", "10\u2013100 cm"^2)),
  expression(atop("SC3", "100\u2013900 cm"^2)),
  expression(atop("SC4", "900\u20134000 cm"^2)),
  expression(atop("SC5", ">4000 cm"^2))
)

# Prepare numeric x positions for pooled line (1-5)
pooled <- pooled %>%
  mutate(x_num = as.numeric(size_class))

combined <- combined %>%
  mutate(x_num = as.numeric(size_class))

# Point size scaling: sqrt(n) mapped to a reasonable range
combined <- combined %>%
  mutate(pt_size = sqrt(n))

# Color and shape mappings
pop_colors <- c("Natural" = pal$natural, "Restoration" = pal$restoration)
tier_shapes <- c("Individual" = 16, "Summary" = 17)  # circle, triangle

# Dodge offset for natural vs restoration within each size class
dodge_width <- 0.35

# Compute dodge positions: Natural gets -dodge/2, Restoration gets +dodge/2
combined <- combined %>%
  mutate(
    x_dodge = x_num + ifelse(pop_type == "Natural", -dodge_width / 2, dodge_width / 2)
  )

# Alternating background bands for size classes (grey/white)
band_data <- data.frame(
  xmin = seq(0.5, 4.5, by = 1),
  xmax = seq(1.5, 5.5, by = 1),
  fill = c("a", "b", "a", "b", "a")  # alternating
)

# Y-axis range: data is all above ~0.4, start at 0.35 to avoid wasted space
y_min <- 0.35
y_max <- 1.06

# Clamp error bar CIs to visible y range so they don't extend below the axis
pooled <- pooled %>%
  mutate(
    ci_lo_clamp = pmax(ci_lo, y_min),
    ci_hi_clamp = pmin(ci_hi, y_max)
  )

# Add small vertical jitter to separate overlapping points (esp. survival = 1.0)
set.seed(42)
combined <- combined %>%
  mutate(
    y_jitter = survival_rate + runif(n(), -0.008, 0.008)
  ) %>%
  # Clamp to [0, 1] range
  mutate(y_jitter = pmin(pmax(y_jitter, 0), 1.0))

# Build the plot -- layer order: bands -> error bars -> study points -> pooled line
p <- ggplot() +
  # Alternating background bands (lowest layer)
  geom_rect(
    data = band_data,
    aes(xmin = xmin, xmax = xmax, ymin = y_min, ymax = y_max, fill = fill),
    alpha = 0.45, show.legend = FALSE
  ) +
  scale_fill_manual(values = c("a" = "grey93", "b" = "white")) +
  # Pooled CI as error bars (subtle, behind the line)
  geom_errorbar(
    data = pooled,
    aes(x = x_num, ymin = ci_lo_clamp, ymax = ci_hi_clamp),
    width = 0.15, linewidth = 0.55, color = "grey55"
  ) +
  # Study-level points (dodged by population type, with tiny y-jitter)
  geom_point(
    data = combined,
    aes(x = x_dodge, y = y_jitter,
        color = pop_type, shape = data_tier, size = pt_size),
    alpha = 0.72
  ) +
  # Bold pooled mean line (top layer)
  geom_line(
    data = pooled,
    aes(x = x_num, y = pooled_surv),
    color = "black", linewidth = 1.1
  ) +
  # Pooled mean diamonds (top layer, prominent)
  geom_point(
    data = pooled,
    aes(x = x_num, y = pooled_surv),
    color = "black", fill = "white", size = 3.5, shape = 23,
    stroke = 1.0
  ) +
  # Size scale: map sqrt(n) to point area with meaningful breaks
  scale_size_continuous(
    name = "Sample size",
    range = c(1.2, 6),
    breaks = sqrt(c(50, 500)),
    labels = c("50", "500")
  ) +
  # Color scale
  scale_color_manual(
    name = "Population type",
    values = pop_colors
  ) +
  # Shape scale
  scale_shape_manual(
    name = "Data tier",
    values = tier_shapes
  ) +
  # X-axis: size classes with expression labels
  scale_x_continuous(
    breaks = 1:5,
    labels = sc_labels_expr,
    expand = expansion(mult = 0.08)
  ) +
  # Y-axis: start at y_min to focus on data range
  scale_y_continuous(
    limits = c(y_min, y_max),
    breaks = seq(0.4, 1.0, 0.1),
    labels = label_number(accuracy = 0.1),
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  # Labels
  labs(
    x = "Size class",
    y = "Annual survival rate"
  ) +
  # Annotations: k= at top of each size class
  annotate(
    "text",
    x = pooled$x_num,
    y = rep(y_max - 0.005, nrow(pooled)),
    label = paste0("italic(k)==", pooled$k),
    parse = TRUE,
    size = 3.0, color = "grey30", vjust = 1
  ) +
  # Annotation: SC1-SC2 non-monotonicity note
  annotate(
    "text",
    x = 1.5, y = y_min + 0.02,
    label = "SC1 > SC2: fewer studies\nand restoration-dominated",
    size = 2.2, color = "grey50", hjust = 0.5, vjust = 0,
    lineheight = 0.9, fontface = "italic"
  ) +
  # Theme
  theme_manuscript(base_size = 11) +
  theme(
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.spacing.x = unit(6, "mm"),
    legend.margin = margin(t = 2, b = 2),
    legend.text = element_text(size = 8),
    legend.title = element_text(size = 8.5, face = "bold"),
    legend.key.size = unit(3.5, "mm"),
    axis.text.x = element_text(size = 8, lineheight = 0.85),
    plot.margin = margin(8, 14, 5, 10, "mm"),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(color = "grey88", linewidth = 0.3)
  ) +
  # Combine legends
  guides(
    color = guide_legend(order = 1, override.aes = list(size = 3, alpha = 1)),
    shape = guide_legend(order = 2, override.aes = list(size = 3, alpha = 1)),
    size  = guide_legend(order = 3, override.aes = list(shape = 16, color = "grey40"))
  )

# Save figure
cat("  Generating figure...\n")
save_manuscript_fig(p, "Fig4_size_class_survival",
                    width_mm = 174, height_mm = 115)

cat("\nDone.\n")
