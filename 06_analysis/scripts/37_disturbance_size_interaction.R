#!/usr/bin/env Rscript
################################################################################
# 37_DISTURBANCE_SIZE_INTERACTION.R
# Disturbance x Size Interaction Analysis for A. palmata Demography
################################################################################
#
# PURPOSE:
#   Quantify whether the size-dependent survival and growth patterns of
#   Acropora palmata differ across curated disturbance states:
#     - No curated disturbance
#     - Context-only chronic / biotic / framework pressure
#     - Acute baseline-exclusion events
#
#   The primary survival model is fit to natural colonies to avoid fragment
#   confounding. Growth is summarized using the same disturbance-state logic.
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#
# OUTPUTS:
#   - 06_analysis/output/disturbance_size_survival_summary.csv
#   - 06_analysis/output/disturbance_size_growth_summary.csv
#   - 06_analysis/output/disturbance_size_survival_model.csv
#   - 06_analysis/output/disturbance_size_growth_model.csv
#   - 06_analysis/output/disturbance_size_model_comparison.csv
#   - 06_analysis/output/disturbance_size_model_diagnostics.csv
#   - 06_analysis/output/disturbance_size_prediction_grid.csv
#   - 06_analysis/figures/supplementary/disturbance_size_interaction.png (+ .pdf)
#
# Author: Detmer & Stier Lab
# Date: 2026-04
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(patchwork)
  library(lme4)
  library(scales)
})

if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
} else if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
}

set.seed(42)

dirs <- setup_output_dirs()
output_dir <- dirs$output
fig_dir <- dirs$figures_supp
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

pal <- MANUSCRIPT_PALETTE

print_header("37: DISTURBANCE x SIZE INTERACTION")
cat("  Primary question: do size effects differ across acute disturbance vs chronic context?\n\n")

disturbance_state_levels <- c(
  "No curated disturbance",
  "Context-only pressure",
  "Acute baseline-exclusion"
)

make_disturbance_state <- function(exclude_from_baseline, timeline_event_count) {
  case_when(
    coalesce(exclude_from_baseline, FALSE) ~ "Acute baseline-exclusion",
    !coalesce(exclude_from_baseline, FALSE) & coalesce(timeline_event_count, 0L) > 0 ~ "Context-only pressure",
    TRUE ~ "No curated disturbance"
  )
}

factor_size_class <- function(x) {
  factor(x, levels = c("SC1", "SC2", "SC3", "SC4", "SC5"), ordered = TRUE)
}

make_model_matrix <- function(model, newdata) {
  tt <- stats::delete.response(stats::terms(model))
  model.matrix(tt, newdata)
}

predict_fixed_effects <- function(model, newdata, response = c("binomial", "gaussian")) {
  response <- match.arg(response)
  X <- make_model_matrix(model, newdata)
  beta <- fixef(model)
  beta <- beta[colnames(X)]
  beta <- beta[!is.na(beta)]
  X <- X[, names(beta), drop = FALSE]
  eta <- as.numeric(X %*% beta)
  vc <- as.matrix(vcov(model))[names(beta), names(beta), drop = FALSE]
  se <- sqrt(pmax(0, rowSums((X %*% vc) * X)))

  if (response == "binomial") {
    fit <- plogis(eta)
    lwr <- plogis(eta - 1.96 * se)
    upr <- plogis(eta + 1.96 * se)
  } else {
    fit <- eta
    lwr <- eta - 1.96 * se
    upr <- eta + 1.96 * se
  }

  dplyr::bind_cols(newdata, tibble::tibble(fit = fit, lwr = lwr, upr = upr, se = se))
}

extract_fixed_effects <- function(model, model_name) {
  s <- summary(model)
  coefs <- as.data.frame(s$coefficients)
  coefs$term <- rownames(coefs)
  rownames(coefs) <- NULL
  names(coefs)[1:4] <- c("estimate", "std_error", "statistic", "p_value")
  coefs <- coefs %>%
    mutate(
      model = model_name,
      odds_ratio = exp(estimate)
  )
  coefs
}

extract_glmer_diagnostics <- function(model, model_name, response_name) {
  fit <- model
  od <- tryCatch(overdisp_test(model), error = function(e) NULL)
  singular_fit <- tryCatch(lme4::isSingular(model, tol = 1e-4), error = function(e) NA)
  conv_msg <- tryCatch({
    msgs <- model@optinfo$conv$lme4$messages
    if (length(msgs) == 0) NA_character_ else paste(unique(unlist(msgs)), collapse = "; ")
  }, error = function(e) NA_character_)

  tibble::tibble(
    response = response_name,
    model = model_name,
    n_obs = stats::nobs(fit),
    aic = stats::AIC(fit),
    bic = stats::BIC(fit),
    logLik = as.numeric(stats::logLik(fit)),
    overdispersion_ratio = if (is.null(od)) NA_real_ else od$ratio,
    overdispersed = if (is.null(od)) NA else od$overdispersed,
    singular_fit = singular_fit,
    convergence_message = conv_msg
  )
}

summarise_rate <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(tibble::tibble(mean = NA_real_, median = NA_real_, se = NA_real_,
                          lower = NA_real_, upper = NA_real_))
  }
  tibble::tibble(
    mean = mean(x),
    median = stats::median(x),
    se = stats::sd(x) / sqrt(length(x)),
    lower = stats::quantile(x, 0.25, names = FALSE),
    upper = stats::quantile(x, 0.75, names = FALSE)
  )
}

add_disturbance_state <- function(df) {
  has_fragment <- "fragment" %in% names(df)
  if (!"population_type" %in% names(df)) {
    df <- df %>%
      mutate(
        is_fragment = if (has_fragment) fragment == "Y" else FALSE,
        population_type = if_else(is_fragment, "Restoration fragment", "Natural colony")
      )
  }

  df %>%
    mutate(
      exclude_from_baseline = coalesce(exclude_from_baseline, FALSE),
      timeline_event_count = coalesce(timeline_event_count, 0L),
      disturbance_state = factor(
        make_disturbance_state(exclude_from_baseline, timeline_event_count),
        levels = disturbance_state_levels
      ),
      size_class = factor_size_class(size_class),
      log_size = if ("log_size" %in% names(.)) log_size else log(size_for_class)
    )
}

cat("Loading prepared datasets...\n")
surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds")) %>%
  add_disturbance_state()
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds")) %>%
  add_disturbance_state() %>%
  mutate(
    positive_growth = as.integer(growth_metric > 0),
    rgr_value = rgr
  )

surv_natural <- surv_data %>% filter(population_type == "Natural colony")
growth_natural <- growth_data %>% filter(population_type == "Natural colony")

cat(sprintf("  Survival rows: %d total, %d natural colonies\n", nrow(surv_data), nrow(surv_natural)))
cat(sprintf("  Growth rows:   %d total, %d natural colonies\n", nrow(growth_data), nrow(growth_natural)))
cat(sprintf("  Survival disturbance states: %s\n", paste(names(table(surv_natural$disturbance_state)), collapse = ", ")))

print_subheader("Observed size x disturbance summaries")

surv_summary <- surv_natural %>%
  group_by(size_class, disturbance_state) %>%
  summarise(
    n = n(),
    n_survived = sum(survived, na.rm = TRUE),
    survival_rate = mean(survived, na.rm = TRUE),
    ci = list(wilson_ci(n_survived, n)),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = purrr::map_dbl(ci, "lower"),
    ci_upper = purrr::map_dbl(ci, "upper")
  ) %>%
  select(-ci) %>%
  arrange(size_class, disturbance_state)

growth_summary <- growth_natural %>%
  group_by(size_class, disturbance_state) %>%
  summarise(
    n = n(),
    pct_positive_growth = mean(positive_growth, na.rm = TRUE),
    median_rgr = median(rgr_value, na.rm = TRUE),
    mean_rgr = mean(rgr_value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(size_class, disturbance_state)

write_csv(surv_summary, file.path(output_dir, "disturbance_size_survival_summary.csv"))
write_csv(growth_summary, file.path(output_dir, "disturbance_size_growth_summary.csv"))
print_success("Saved: disturbance_size_survival_summary.csv")
print_success("Saved: disturbance_size_growth_summary.csv")

print_subheader("Primary survival interaction model")

surv_add <- glmer(
  survived ~ log_size + disturbance_state + (1 | study),
  data = surv_natural,
  family = binomial,
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

surv_int <- glmer(
  survived ~ log_size * disturbance_state + (1 | study),
  data = surv_natural,
  family = binomial,
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

surv_comp <- anova(surv_add, surv_int)
surv_lrt_p <- surv_comp$`Pr(>Chisq)`[2]

surv_terms <- extract_fixed_effects(surv_int, "survival_interaction")
surv_terms$metric <- "survival"
surv_terms$comparison_lrt_p <- surv_lrt_p

print(surv_terms %>% select(term, estimate, std_error, statistic, p_value, odds_ratio))
cat(sprintf("  Survival interaction LRT p = %.4f\n", surv_lrt_p))

print_subheader("Growth-side summary model")

growth_add <- glmer(
  positive_growth ~ log_size + disturbance_state + (1 | study),
  data = growth_natural,
  family = binomial,
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

growth_int <- glmer(
  positive_growth ~ log_size * disturbance_state + (1 | study),
  data = growth_natural,
  family = binomial,
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

growth_comp <- anova(growth_add, growth_int)
growth_lrt_p <- growth_comp$`Pr(>Chisq)`[2]

growth_terms <- extract_fixed_effects(growth_int, "growth_positive_interaction")
growth_terms$metric <- "positive_growth"
growth_terms$comparison_lrt_p <- growth_lrt_p

print(growth_terms %>% select(term, estimate, std_error, statistic, p_value, odds_ratio))
cat(sprintf("  Growth interaction LRT p = %.4f\n", growth_lrt_p))

model_comparison <- bind_rows(
  tibble(
    response = "survival",
    model = c("additive", "interaction"),
    aic = c(AIC(surv_add), AIC(surv_int)),
    lrt_p = c(NA_real_, surv_lrt_p)
  ),
  tibble(
    response = "positive_growth",
    model = c("additive", "interaction"),
    aic = c(AIC(growth_add), AIC(growth_int)),
    lrt_p = c(NA_real_, growth_lrt_p)
  )
)
model_diagnostics <- bind_rows(
  extract_glmer_diagnostics(surv_add, "additive", "survival"),
  extract_glmer_diagnostics(surv_int, "interaction", "survival"),
  extract_glmer_diagnostics(growth_add, "additive", "positive_growth"),
  extract_glmer_diagnostics(growth_int, "interaction", "positive_growth")
)
write_csv(model_comparison, file.path(output_dir, "disturbance_size_model_comparison.csv"))
write_csv(model_diagnostics, file.path(output_dir, "disturbance_size_model_diagnostics.csv"))
write_csv(surv_terms, file.path(output_dir, "disturbance_size_survival_model.csv"))
write_csv(growth_terms, file.path(output_dir, "disturbance_size_growth_model.csv"))
print_success("Saved: disturbance_size_model_comparison.csv")
print_success("Saved: disturbance_size_model_diagnostics.csv")
print_success("Saved: disturbance_size_survival_model.csv")
print_success("Saved: disturbance_size_growth_model.csv")

print_subheader("Prediction grid")

size_grid <- tibble(
  size_for_class = exp(seq(log(min(surv_natural$size_for_class, na.rm = TRUE)),
                           log(max(surv_natural$size_for_class, na.rm = TRUE)),
                           length.out = 120))
) %>%
  mutate(log_size = log(size_for_class))

pred_grid_surv_newdata <- expand_grid(
  size_for_class = size_grid$size_for_class,
  log_size = size_grid$log_size,
  disturbance_state = factor(disturbance_state_levels, levels = disturbance_state_levels)
) %>%
  mutate(study = sort(unique(surv_natural$study))[1])

pred_grid_surv <- predict_fixed_effects(
  model = surv_int,
  newdata = pred_grid_surv_newdata,
  response = "binomial"
) %>%
  mutate(response = "survival")

pred_grid_growth_newdata <- expand_grid(
  size_for_class = size_grid$size_for_class,
  log_size = size_grid$log_size,
  disturbance_state = factor(disturbance_state_levels, levels = disturbance_state_levels)
) %>%
  mutate(study = sort(unique(growth_natural$study))[1])

pred_grid_growth <- predict_fixed_effects(
  model = growth_int,
  newdata = pred_grid_growth_newdata,
  response = "binomial"
) %>%
  mutate(response = "positive_growth")

prediction_grid <- bind_rows(pred_grid_surv, pred_grid_growth)
write_csv(prediction_grid, file.path(output_dir, "disturbance_size_prediction_grid.csv"))
print_success("Saved: disturbance_size_prediction_grid.csv")

print_subheader("Figure generation")

plot_surv <- surv_summary %>%
  mutate(
    size_label = as.character(size_class),
    fill_label = sprintf("%.0f%%", survival_rate * 100),
    text_col = if_else(survival_rate > 0.78, "white", pal$slate_dark)
  ) %>%
  ggplot(aes(x = disturbance_state, y = size_class, fill = survival_rate)) +
  geom_tile(color = "white", linewidth = 0.6) +
  geom_text(aes(label = fill_label, color = text_col), size = 3.1, fontface = "bold") +
  scale_color_identity() +
  scale_fill_gradient(low = "#dbeafe", high = pal$surv_dark, limits = c(0, 1), labels = label_percent(accuracy = 1)) +
  labs(
    title = "Survival",
    subtitle = "Natural colonies only",
    x = NULL,
    y = "Size class",
    fill = "Annual survival"
  ) +
  theme_manuscript() +
  theme(
    axis.text.x = element_text(angle = 20, hjust = 1),
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(size = 9),
    legend.position = "right"
  )

plot_growth <- growth_summary %>%
  mutate(
    fill_label = sprintf("%.0f%%", pct_positive_growth * 100),
    text_col = if_else(pct_positive_growth > 0.72, "white", pal$slate_dark)
  ) %>%
  ggplot(aes(x = disturbance_state, y = size_class, fill = pct_positive_growth)) +
  geom_tile(color = "white", linewidth = 0.6) +
  geom_text(aes(label = fill_label, color = text_col), size = 3.1, fontface = "bold") +
  scale_color_identity() +
  scale_fill_gradient(low = "#fef3c7", high = pal$accent, limits = c(0, 1), labels = label_percent(accuracy = 1)) +
  labs(
    title = "Positive growth",
    subtitle = "Natural colonies only; growth-side summary",
    x = NULL,
    y = "Size class",
    fill = "P(growth > 0)"
  ) +
  theme_manuscript() +
  theme(
    axis.text.x = element_text(angle = 20, hjust = 1),
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(size = 9),
    legend.position = "right"
  )

interaction_fig <- plot_surv / plot_growth +
  plot_annotation(
    title = "Disturbance-by-size interaction",
    subtitle = "Natural colonies only; acute baseline-exclusion events are separated from context-only pressure.",
    caption = "Observed size-class summaries are shown here. Model coefficients, contrasts, and predictions are saved separately."
  )

ggsave(
  file.path(fig_dir, "FigS17_disturbance_size_interaction.png"),
  interaction_fig,
  width = 190,
  height = 190,
  units = "mm",
  dpi = 300
)
ggsave(
  file.path(fig_dir, "FigS17_disturbance_size_interaction.pdf"),
  interaction_fig,
  width = 190,
  height = 190,
  units = "mm"
)

print_success("Saved: FigS17_disturbance_size_interaction.png")
print_success("Saved: FigS17_disturbance_size_interaction.pdf")

cat("\nSUMMARY:\n")
cat(sprintf("  Survival interaction LRT p = %.4f\n", surv_lrt_p))
cat(sprintf("  Growth interaction LRT p = %.4f\n", growth_lrt_p))
cat(sprintf("  Natural-colony survival rows analyzed: %d\n", nrow(surv_natural)))
cat(sprintf("  Natural-colony growth rows analyzed: %d\n", nrow(growth_natural)))
cat("\nCompleted disturbance-by-size interaction analysis.\n")
