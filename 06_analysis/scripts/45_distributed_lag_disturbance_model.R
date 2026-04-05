#!/usr/bin/env Rscript
################################################################################
# 45_DISTRIBUTED_LAG_DISTURBANCE_MODEL.R
# Distributed-lag disturbance models for A. palmata survival and growth
################################################################################
#
# PURPOSE:
#   Quantify delayed disturbance effects on colony-level demographic outcomes
#   using year-indexed disturbance exposure and individual panel observations.
#
#   This script constructs region-year exposure histories from the curated
#   disturbance timeline and attaches lag windows (0-3 years) to each colony
#   interval. It then compares:
#     - baseline models (size + interval controls)
#     - distributed lag window models (recent vs delayed exposure)
#     - unconstrained lag models (separate lag coefficients)
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#   - 05_data/standardized/apal_disturbance_stressor_timeline.csv
#
# OUTPUTS (all prefixed distributed_lag_):
#   - 06_analysis/output/distributed_lag_year_region_exposure.csv
#   - 06_analysis/output/distributed_lag_survival_panel.csv
#   - 06_analysis/output/distributed_lag_growth_panel.csv
#   - 06_analysis/output/distributed_lag_model_comparison.csv
#   - 06_analysis/output/distributed_lag_survival_model_terms.csv
#   - 06_analysis/output/distributed_lag_growth_model_terms.csv
#   - 06_analysis/output/distributed_lag_effect_summary.csv
#   - 06_analysis/output/distributed_lag_prediction_grid.csv
#   - 06_analysis/figures/supplementary/distributed_lag_coefficients.png (+ .pdf)
#
# AUTHOR: Detmer & Stier Lab
# DATE: 2026-04
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(lme4)
  library(ggplot2)
})

if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
} else if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
}

set.seed(42)

print_header("45: DISTRIBUTED-LAG DISTURBANCE MODELS")
cat("  Outcomes: survival, positive growth, and relative growth rate (RGR)\n")
cat("  Lag window: 0-3 years (recent: 0-1, delayed: 2-3)\n\n")

project_root <- get_project_root()
dirs <- setup_output_dirs(project_root)
output_dir <- dirs$output
fig_dir <- dirs$figures_supp
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

surv_file <- file.path(output_dir, "prepared_survival_data.rds")
growth_file <- file.path(output_dir, "prepared_growth_data.rds")
timeline_file <- file.path(project_root, "05_data/standardized/apal_disturbance_stressor_timeline.csv")

if (!file.exists(surv_file)) stop("Missing file: ", surv_file)
if (!file.exists(growth_file)) stop("Missing file: ", growth_file)
if (!file.exists(timeline_file)) stop("Missing file: ", timeline_file)

surv_data <- readRDS(surv_file)
growth_data <- readRDS(growth_file)
timeline <- read_csv(timeline_file, show_col_types = FALSE)

max_lag <- 3L

if (!"population_type" %in% names(surv_data)) {
  surv_data <- surv_data %>%
    mutate(
      is_fragment = if ("fragment" %in% names(.)) fragment == "Y" else FALSE,
      population_type = if_else(is_fragment, "Restoration fragment", "Natural colony")
    )
}

if (!"population_type" %in% names(growth_data)) {
  growth_data <- growth_data %>%
    mutate(
      is_fragment = if ("fragment" %in% names(.)) fragment == "Y" else FALSE,
      population_type = if_else(is_fragment, "Restoration fragment", "Natural colony")
    )
}

extract_glmer_terms <- function(model, outcome, model_name) {
  s <- summary(model)$coefficients
  out <- as.data.frame(s)
  out$term <- rownames(out)
  rownames(out) <- NULL
  names(out)[1:4] <- c("estimate", "std_error", "statistic", "p_value")
  out %>%
    mutate(
      outcome = outcome,
      model = model_name,
      effect_type = "odds_ratio",
      effect = exp(estimate),
      ci_lower = exp(estimate - 1.96 * std_error),
      ci_upper = exp(estimate + 1.96 * std_error)
    ) %>%
    select(outcome, model, term, estimate, std_error, statistic, p_value,
           effect_type, effect, ci_lower, ci_upper)
}

extract_lmer_terms <- function(model, outcome, model_name) {
  s <- summary(model)$coefficients
  out <- as.data.frame(s)
  out$term <- rownames(out)
  rownames(out) <- NULL
  names(out)[1:3] <- c("estimate", "std_error", "statistic")
  out %>%
    mutate(
      p_value = NA_real_,
      outcome = outcome,
      model = model_name,
      effect_type = "additive",
      effect = estimate,
      ci_lower = estimate - 1.96 * std_error,
      ci_upper = estimate + 1.96 * std_error
    ) %>%
    select(outcome, model, term, estimate, std_error, statistic, p_value,
           effect_type, effect, ci_lower, ci_upper)
}

build_year_region_exposure <- function(timeline_df, region_universe, year_min, year_max) {
  timeline_df <- timeline_df %>%
    mutate(
      Start_Year = as.integer(Start_Year),
      End_Year = as.integer(End_Year),
      Exclude_From_Baseline = as.logical(Exclude_From_Baseline),
      Analysis_Tier = tolower(trimws(as.character(Analysis_Tier)))
    )

  expanded <- lapply(seq_len(nrow(timeline_df)), function(i) {
    event_regions <- expand_disturbance_regions(timeline_df$Region[i])
    if (length(event_regions) == 0) return(NULL)

    # Apply Caribbean-wide events to all analysis regions.
    if ("Caribbean-wide" %in% event_regions) {
      event_regions <- unique(c(setdiff(event_regions, "Caribbean-wide"), region_universe))
    }

    years <- seq(max(year_min, timeline_df$Start_Year[i]),
                 min(year_max, timeline_df$End_Year[i]))
    if (length(years) == 0) return(NULL)

    tidyr::expand_grid(
      region_group = event_regions,
      year = years
    ) %>%
      mutate(
        Event_Name = timeline_df$Event_Name[i],
        Event_Type = timeline_df$Event_Type[i],
        Intensity_Metric = timeline_df$Intensity_Metric[i],
        Intensity_Value = timeline_df$Intensity_Value[i],
        Impact_Description = timeline_df$Impact_Description[i],
        Analysis_Tier = timeline_df$Analysis_Tier[i],
        Exclude_From_Baseline = timeline_df$Exclude_From_Baseline[i]
      )
  })

  events_long <- bind_rows(expanded)
  if (nrow(events_long) == 0) stop("No disturbance events expanded for analysis years/regions.")

  events_long <- events_long %>%
    mutate(
      severity_class = classify_disturbance_severity(
        Intensity_Metric, Intensity_Value, Impact_Description
      ),
      is_acute_exclusion = coalesce(Exclude_From_Baseline, FALSE) | Analysis_Tier == "acute_event",
      is_context_pressure = !is_acute_exclusion,
      is_catastrophic = severity_class == "Catastrophic"
    )

  year_region <- events_long %>%
    group_by(region_group, year) %>%
    summarise(
      acute_exclusion_events = sum(is_acute_exclusion, na.rm = TRUE),
      context_pressure_events = sum(is_context_pressure, na.rm = TRUE),
      catastrophic_events = sum(is_catastrophic, na.rm = TRUE),
      event_names = paste(unique(Event_Name), collapse = "; "),
      .groups = "drop"
    )

  full_grid <- tidyr::expand_grid(region_group = region_universe, year = year_min:year_max) %>%
    left_join(year_region, by = c("region_group", "year")) %>%
    mutate(
      acute_exclusion_events = coalesce(acute_exclusion_events, 0L),
      context_pressure_events = coalesce(context_pressure_events, 0L),
      catastrophic_events = coalesce(catastrophic_events, 0L),
      event_names = coalesce(event_names, "")
    )

  full_grid
}

attach_lag_history <- function(df, exposure_df, max_lag_years = 3L) {
  out <- df %>%
    mutate(
      region_group = canonical_region_group(region),
      survey_year_num = as.integer(survey_yr)
    )

  for (lag_i in 0:max_lag_years) {
    lag_tbl <- exposure_df %>%
      transmute(
        region_group,
        survey_year_num = year + lag_i,
        !!paste0("acute_l", lag_i) := acute_exclusion_events,
        !!paste0("context_l", lag_i) := context_pressure_events,
        !!paste0("catastrophic_l", lag_i) := catastrophic_events
      )

    out <- out %>% left_join(lag_tbl, by = c("region_group", "survey_year_num"))
  }

  for (lag_i in 0:max_lag_years) {
    out[[paste0("acute_l", lag_i)]] <- coalesce(out[[paste0("acute_l", lag_i)]], 0L)
    out[[paste0("context_l", lag_i)]] <- coalesce(out[[paste0("context_l", lag_i)]], 0L)
    out[[paste0("catastrophic_l", lag_i)]] <- coalesce(out[[paste0("catastrophic_l", lag_i)]], 0L)
  }

  out %>%
    mutate(
      acute_recent = acute_l0 + acute_l1,
      acute_delayed = acute_l2 + acute_l3,
      context_recent = context_l0 + context_l1,
      context_delayed = context_l2 + context_l3,
      catastrophic_recent = catastrophic_l0 + catastrophic_l1,
      catastrophic_delayed = catastrophic_l2 + catastrophic_l3,
      log_interval = log(pmax(as.numeric(time_interval_yr), 0.25))
    )
}

region_universe <- sort(unique(c(
  canonical_region_group(surv_data$region),
  canonical_region_group(growth_data$region)
)))
region_universe <- region_universe[!is.na(region_universe)]

year_min <- min(c(as.integer(surv_data$survey_yr), as.integer(growth_data$survey_yr)), na.rm = TRUE) - max_lag
year_max <- max(c(as.integer(surv_data$survey_yr), as.integer(growth_data$survey_yr)), na.rm = TRUE)

year_region_exposure <- build_year_region_exposure(timeline, region_universe, year_min, year_max)
write_csv(year_region_exposure, file.path(output_dir, "distributed_lag_year_region_exposure.csv"))

surv_panel <- attach_lag_history(surv_data, year_region_exposure, max_lag_years = max_lag)
growth_panel <- attach_lag_history(growth_data, year_region_exposure, max_lag_years = max_lag) %>%
  mutate(positive_growth = as.integer(growth_metric > 0))

write_csv(surv_panel, file.path(output_dir, "distributed_lag_survival_panel.csv"))
write_csv(growth_panel, file.path(output_dir, "distributed_lag_growth_panel.csv"))

cat("Panel sizes after lag attachment:\n")
cat(sprintf("  Survival: %d rows\n", nrow(surv_panel)))
cat(sprintf("  Growth:   %d rows\n\n", nrow(growth_panel)))

surv_model_df <- surv_panel %>%
  filter(
    population_type == "Natural colony",
    !is.na(survived),
    !is.na(log_size),
    !is.na(log_interval),
    !is.na(study)
  )

growth_model_df <- growth_panel %>%
  filter(
    population_type == "Natural colony",
    !is.na(log_size),
    !is.na(log_interval),
    !is.na(study)
  )

rgr_model_df <- growth_model_df %>%
  filter(!is.na(rgr), is.finite(rgr))

print_subheader("Model fitting")

surv_base <- glmer(
  survived ~ log_size + log_interval + (1 | study),
  data = surv_model_df,
  family = binomial,
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

surv_window <- glmer(
  survived ~ log_size + log_interval +
    acute_recent + acute_delayed +
    context_recent + context_delayed +
    catastrophic_recent + catastrophic_delayed +
    (1 | study),
  data = surv_model_df,
  family = binomial,
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

surv_unconstrained <- glmer(
  survived ~ log_size + log_interval +
    acute_l0 + acute_l1 + acute_l2 + acute_l3 +
    context_l0 + context_l1 + context_l2 + context_l3 +
    catastrophic_l0 + catastrophic_l1 + catastrophic_l2 + catastrophic_l3 +
    (1 | study),
  data = surv_model_df,
  family = binomial,
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

growth_base <- glmer(
  positive_growth ~ log_size + log_interval + (1 | study),
  data = growth_model_df,
  family = binomial,
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

growth_window <- glmer(
  positive_growth ~ log_size + log_interval +
    acute_recent + acute_delayed +
    context_recent + context_delayed +
    catastrophic_recent + catastrophic_delayed +
    (1 | study),
  data = growth_model_df,
  family = binomial,
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

growth_unconstrained <- glmer(
  positive_growth ~ log_size + log_interval +
    acute_l0 + acute_l1 + acute_l2 + acute_l3 +
    context_l0 + context_l1 + context_l2 + context_l3 +
    catastrophic_l0 + catastrophic_l1 + catastrophic_l2 + catastrophic_l3 +
    (1 | study),
  data = growth_model_df,
  family = binomial,
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

rgr_base <- lmer(
  rgr ~ log_size + log_interval + (1 | study),
  data = rgr_model_df,
  REML = FALSE
)

rgr_window <- lmer(
  rgr ~ log_size + log_interval +
    acute_recent + acute_delayed +
    context_recent + context_delayed +
    catastrophic_recent + catastrophic_delayed +
    (1 | study),
  data = rgr_model_df,
  REML = FALSE
)

rgr_unconstrained <- lmer(
  rgr ~ log_size + log_interval +
    acute_l0 + acute_l1 + acute_l2 + acute_l3 +
    context_l0 + context_l1 + context_l2 + context_l3 +
    catastrophic_l0 + catastrophic_l1 + catastrophic_l2 + catastrophic_l3 +
    (1 | study),
  data = rgr_model_df,
  REML = FALSE
)

model_comparison <- bind_rows(
  tibble(
    outcome = "survival",
    model = c("base", "window", "unconstrained"),
    aic = c(AIC(surv_base), AIC(surv_window), AIC(surv_unconstrained)),
    bic = c(BIC(surv_base), BIC(surv_window), BIC(surv_unconstrained)),
    n = nobs(surv_base)
  ),
  tibble(
    outcome = "positive_growth",
    model = c("base", "window", "unconstrained"),
    aic = c(AIC(growth_base), AIC(growth_window), AIC(growth_unconstrained)),
    bic = c(BIC(growth_base), BIC(growth_window), BIC(growth_unconstrained)),
    n = nobs(growth_base)
  ),
  tibble(
    outcome = "rgr",
    model = c("base", "window", "unconstrained"),
    aic = c(AIC(rgr_base), AIC(rgr_window), AIC(rgr_unconstrained)),
    bic = c(BIC(rgr_base), BIC(rgr_window), BIC(rgr_unconstrained)),
    n = nobs(rgr_base)
  )
) %>%
  group_by(outcome) %>%
  mutate(delta_aic = aic - min(aic, na.rm = TRUE)) %>%
  ungroup()

surv_terms <- bind_rows(
  extract_glmer_terms(surv_window, "survival", "window"),
  extract_glmer_terms(surv_unconstrained, "survival", "unconstrained")
)

growth_terms <- bind_rows(
  extract_glmer_terms(growth_window, "positive_growth", "window"),
  extract_glmer_terms(growth_unconstrained, "positive_growth", "unconstrained"),
  extract_lmer_terms(rgr_window, "rgr", "window"),
  extract_lmer_terms(rgr_unconstrained, "rgr", "unconstrained")
)

effect_summary <- bind_rows(
  surv_terms %>% mutate(domain = "survival"),
  growth_terms %>% mutate(domain = "growth")
) %>%
  filter(grepl("acute_|context_|catastrophic_", term)) %>%
  mutate(
    lag_family = case_when(
      grepl("^acute_", term) ~ "acute_exclusion",
      grepl("^context_", term) ~ "context_pressure",
      grepl("^catastrophic_", term) ~ "catastrophic",
      TRUE ~ "other"
    ),
    lag_window = case_when(
      grepl("recent", term) ~ "recent_0_1",
      grepl("delayed", term) ~ "delayed_2_3",
      grepl("l0", term) ~ "lag0",
      grepl("l1", term) ~ "lag1",
      grepl("l2", term) ~ "lag2",
      grepl("l3", term) ~ "lag3",
      TRUE ~ "other"
    )
  )

# Fixed-effects prediction grid for the survival window model
pred_grid <- tidyr::expand_grid(
  log_size = quantile(surv_model_df$log_size, probs = c(0.2, 0.5, 0.8), na.rm = TRUE),
  acute_recent = 0:2,
  acute_delayed = 0:2,
  context_recent = 0:3,
  context_delayed = 0:3,
  catastrophic_recent = 0:1,
  catastrophic_delayed = 0:1
) %>%
  mutate(log_interval = median(surv_model_df$log_interval, na.rm = TRUE))

X <- model.matrix(delete.response(terms(surv_window)), pred_grid)
beta <- fixef(surv_window)
beta <- beta[colnames(X)]
eta <- as.numeric(X %*% beta)
pred_grid <- pred_grid %>%
  mutate(pred_survival = plogis(eta))

write_csv(model_comparison, file.path(output_dir, "distributed_lag_model_comparison.csv"))
write_csv(surv_terms, file.path(output_dir, "distributed_lag_survival_model_terms.csv"))
write_csv(growth_terms, file.path(output_dir, "distributed_lag_growth_model_terms.csv"))
write_csv(effect_summary, file.path(output_dir, "distributed_lag_effect_summary.csv"))
write_csv(pred_grid, file.path(output_dir, "distributed_lag_prediction_grid.csv"))

# Coefficient plot (window models only for readability)
plot_terms <- bind_rows(
  surv_terms %>% filter(model == "window") %>% mutate(outcome_label = "Survival"),
  growth_terms %>% filter(model == "window", outcome == "positive_growth") %>%
    mutate(outcome_label = "Positive Growth")
) %>%
  filter(grepl("acute_|context_|catastrophic_", term))

p <- ggplot(plot_terms, aes(x = term, y = estimate, ymin = estimate - 1.96 * std_error,
                            ymax = estimate + 1.96 * std_error, color = outcome_label)) +
  geom_hline(yintercept = 0, color = "grey75", linewidth = 0.4) +
  geom_pointrange(position = position_dodge(width = 0.4), linewidth = 0.5) +
  coord_flip() +
  scale_color_manual(values = c("Survival" = MANUSCRIPT_PALETTE$surv_dark,
                                "Positive Growth" = MANUSCRIPT_PALETTE$growth_dark)) +
  labs(
    title = "Distributed-lag disturbance coefficients (window model)",
    x = NULL,
    y = "Log-odds coefficient (95% CI)",
    color = NULL
  ) +
  theme_manuscript() +
  theme(legend.position = "bottom")

ggsave(file.path(fig_dir, "distributed_lag_coefficients.png"), p,
       width = 200, height = 130, units = "mm", dpi = 300)
ggsave(file.path(fig_dir, "distributed_lag_coefficients.pdf"), p,
       width = 200, height = 130, units = "mm")

cat("\nModel comparison (lower AIC is better):\n")
print(model_comparison %>% arrange(outcome, delta_aic))

cat("\nSaved outputs:\n")
cat("  - distributed_lag_year_region_exposure.csv\n")
cat("  - distributed_lag_survival_panel.csv\n")
cat("  - distributed_lag_growth_panel.csv\n")
cat("  - distributed_lag_model_comparison.csv\n")
cat("  - distributed_lag_survival_model_terms.csv\n")
cat("  - distributed_lag_growth_model_terms.csv\n")
cat("  - distributed_lag_effect_summary.csv\n")
cat("  - distributed_lag_prediction_grid.csv\n")
cat("  - figures/supplementary/distributed_lag_coefficients.{png,pdf}\n\n")
