#!/usr/bin/env Rscript
################################################################################
# 47_SPATIOTEMPORAL_HIERARCHICAL_MODEL.R
# Spatiotemporal hierarchical analysis for A. palmata demographic outcomes
################################################################################
#
# PURPOSE:
#   Extend the colony-panel analysis beyond standard GLMMs by quantifying
#   spatiotemporal structure in survival and positive growth after
#   accounting for size, population type, and curated disturbance state.
#
# APPROACH:
#   - Fit baseline binomial GAMMs with size + population_type + disturbance_state
#   - Fit spatiotemporal hierarchical GAMMs adding:
#       * smooth temporal trend
#       * spatial smooth over site coordinates
#       * site random intercept
#       * study random intercept
#   - Compare model fit and summarize site-year structure
#
# INPUTS:
#   - 06_analysis/output/prepared_survival_data.rds
#   - 06_analysis/output/prepared_growth_data.rds
#
# OUTPUTS:
#   - 06_analysis/output/spatiotemporal_survival_model_comparison.csv
#   - 06_analysis/output/spatiotemporal_growth_model_comparison.csv
#   - 06_analysis/output/spatiotemporal_survival_variance_components.csv
#   - 06_analysis/output/spatiotemporal_growth_variance_components.csv
#   - 06_analysis/output/spatiotemporal_survival_kcheck.csv
#   - 06_analysis/output/spatiotemporal_growth_kcheck.csv
#   - 06_analysis/output/spatiotemporal_year_predictions.csv
#   - 06_analysis/output/spatiotemporal_site_summary.csv
#   - 06_analysis/output/spatiotemporal_site_year_summary.csv
#   - 06_analysis/output/spatiotemporal_spatial_predictions.csv
#   - 06_analysis/output/spatiotemporal_data_coverage.csv
#   - 06_analysis/figures/supplementary/spatiotemporal_hierarchical_summary.png
#   - 06_analysis/figures/supplementary/spatiotemporal_hierarchical_summary.pdf
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(mgcv)
  library(patchwork)
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

print_header("47: SPATIOTEMPORAL HIERARCHICAL MODEL")
cat("  Quantifying site-year structure beyond size + disturbance GLMMs\n\n")

disturbance_state_levels <- c(
  "No curated disturbance",
  "Context-only pressure",
  "Acute baseline-exclusion"
)

make_disturbance_state <- function(exclude_from_baseline, timeline_event_count) {
  dplyr::case_when(
    dplyr::coalesce(exclude_from_baseline, FALSE) ~ "Acute baseline-exclusion",
    !dplyr::coalesce(exclude_from_baseline, FALSE) &
      dplyr::coalesce(timeline_event_count, 0L) > 0 ~ "Context-only pressure",
    TRUE ~ "No curated disturbance"
  )
}

safe_modal <- function(x) {
  x <- x[!is.na(x) & x != ""]
  if (length(x) == 0) {
    return(NA_character_)
  }
  tab <- sort(table(x), decreasing = TRUE)
  names(tab)[1]
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

extract_model_metrics <- function(model, label, outcome) {
  if (is.null(model) || !inherits(model, c("gam", "bam", "glm", "lm"))) {
    return(tibble::tibble(
      outcome = outcome,
      model = label,
      family = NA_character_,
      n = NA_integer_,
      aic = NA_real_,
      logLik = NA_real_,
      deviance_explained = NA_real_,
      r_squared = NA_real_,
      scale_est = NA_real_
    ))
  }
  sm <- summary(model)
  fam <- model$family$family
  n_rows <- nrow(model$model)
  aic_val <- tryCatch(AIC(model), error = function(e) NA_real_)
  ll_val <- tryCatch(as.numeric(logLik(model)), error = function(e) NA_real_)
  dev_expl <- sm$dev.expl %||% NA_real_
  r_sq <- sm$r.sq %||% NA_real_
  scale_val <- sm$scale %||% NA_real_
  tibble::tibble(
    outcome = outcome,
    model = label,
    family = fam,
    n = n_rows,
    aic = aic_val,
    logLik = ll_val,
    deviance_explained = dev_expl,
    r_squared = r_sq,
    scale_est = scale_val
  )
}

extract_vcomp <- function(model, outcome, model_label) {
  vc <- tryCatch(mgcv::gam.vcomp(model), error = function(e) NULL)
  if (is.null(vc)) {
    return(tibble::tibble(
      outcome = outcome,
      model = model_label,
      component = NA_character_,
      std_dev = NA_real_,
      variance = NA_real_
    ))
  }

  vc_df <- as.data.frame(vc)
  vc_df$component <- rownames(vc_df)
  rownames(vc_df) <- NULL

  if ("std.dev" %in% names(vc_df)) {
    vc_df <- vc_df %>% rename(std_dev = `std.dev`)
  } else if ("std.dev." %in% names(vc_df)) {
    vc_df <- vc_df %>% rename(std_dev = `std.dev.`)
  } else if ("sd" %in% names(vc_df)) {
    vc_df <- vc_df %>% rename(std_dev = sd)
  } else {
    vc_df$std_dev <- NA_real_
  }

  vc_df %>%
    transmute(
      outcome = outcome,
      model = model_label,
      component = component,
      std_dev = std_dev,
      variance = std_dev^2
    )
}

extract_k_checks <- function(model, outcome, model_label) {
  kc <- tryCatch(mgcv::k.check(model), error = function(e) NULL)
  if (is.null(kc)) {
    return(tibble::tibble(
      outcome = outcome,
      model = model_label,
      smooth = NA_character_,
      k_index = NA_real_,
      k_prime = NA_real_,
      edf = NA_real_,
      p_value = NA_real_
    ))
  }

  kc_df <- as.data.frame(kc)
  kc_df$smooth <- rownames(kc_df)
  rownames(kc_df) <- NULL

  pick_col <- function(df, candidates) {
    found <- candidates[candidates %in% names(df)]
    if (length(found) == 0) return(rep(NA_real_, nrow(df)))
    df[[found[1]]]
  }

  tibble::tibble(
    outcome = outcome,
    model = model_label,
    smooth = kc_df$smooth,
    k_index = pick_col(kc_df, c("k.index", "k-index", "k_index")),
    k_prime = pick_col(kc_df, c("k.prime", "k.", "k_prime")),
    edf = pick_col(kc_df, c("edf", "edf.")),
    p_value = pick_col(kc_df, c("p.value", "p-value", "p_value"))
  )
}

calc_binary_metrics <- function(actual, predicted_prob) {
  predicted_prob <- pmin(pmax(predicted_prob, 1e-6), 1 - 1e-6)
  pred_class <- as.integer(predicted_prob >= 0.5)
  tp <- sum(pred_class == 1 & actual == 1, na.rm = TRUE)
  fp <- sum(pred_class == 1 & actual == 0, na.rm = TRUE)
  fn <- sum(pred_class == 0 & actual == 1, na.rm = TRUE)
  tn <- sum(pred_class == 0 & actual == 0, na.rm = TRUE)

  auc <- NA_real_
  if (length(unique(actual[!is.na(actual)])) == 2) {
    pred_1 <- predicted_prob[actual == 1]
    pred_0 <- predicted_prob[actual == 0]
    if (length(pred_1) > 0 && length(pred_0) > 0) {
      auc <- mean(outer(pred_1, pred_0, ">")) + 0.5 * mean(outer(pred_1, pred_0, "=="))
    }
  }

  tibble::tibble(
    brier_score = mean((predicted_prob - actual)^2, na.rm = TRUE),
    log_loss = -mean(actual * log(predicted_prob) + (1 - actual) * log(1 - predicted_prob), na.rm = TRUE),
    auc = auc,
    accuracy = mean(pred_class == actual, na.rm = TRUE),
    sensitivity = if ((tp + fn) > 0) tp / (tp + fn) else NA_real_,
    specificity = if ((tn + fp) > 0) tn / (tn + fp) else NA_real_
  )
}

haversine_km <- function(lat1, lon1, lat2, lon2) {
  to_rad <- pi / 180
  dlat <- (lat2 - lat1) * to_rad
  dlon <- (lon2 - lon1) * to_rad
  a <- sin(dlat / 2)^2 +
    cos(lat1 * to_rad) * cos(lat2 * to_rad) * sin(dlon / 2)^2
  6371 * 2 * atan2(sqrt(a), sqrt(pmax(0, 1 - a)))
}

align_factor_to_levels <- function(values, levels_target, fallback_level) {
  values_chr <- as.character(values)
  if (length(levels_target) == 0) {
    return(factor(values_chr))
  }
  values_chr[is.na(values_chr) | !values_chr %in% levels_target] <- fallback_level
  factor(values_chr, levels = levels_target)
}

prepare_region_holdout_newdata <- function(test_data, train_data) {
  ref_row <- train_data %>% slice(1)
  out <- test_data

  if ("study" %in% names(train_data)) {
    out$study <- factor(as.character(ref_row$study[[1]]), levels = levels(train_data$study))
  }
  if ("site_id" %in% names(train_data)) {
    out$site_id <- factor(as.character(ref_row$site_id[[1]]), levels = levels(train_data$site_id))
  }
  if ("survey_year_factor" %in% names(train_data) && "survey_year_factor" %in% names(out)) {
    year_levels <- levels(train_data$survey_year_factor)
    fallback_year <- as.character(ref_row$survey_year_factor[[1]])
    out$survey_year_factor <- align_factor_to_levels(out$survey_year_factor, year_levels, fallback_year)
  }
  if ("population_type" %in% names(train_data) && "population_type" %in% names(out)) {
    out$population_type <- align_factor_to_levels(
      out$population_type,
      levels(train_data$population_type),
      as.character(ref_row$population_type[[1]])
    )
  }
  if ("disturbance_state" %in% names(train_data) && "disturbance_state" %in% names(out)) {
    out$disturbance_state <- align_factor_to_levels(
      out$disturbance_state,
      levels(train_data$disturbance_state),
      as.character(ref_row$disturbance_state[[1]])
    )
  }

  out
}

extract_spatial_residual_check <- function(model, data, outcome, model_label) {
  model_data <- tryCatch(as_tibble(model$model), error = function(e) NULL)
  pearson_resid <- tryCatch(residuals(model, type = "pearson"), error = function(e) NULL)
  if (is.null(model_data) ||
      !"site_id" %in% names(model_data) ||
      !"latitude" %in% names(model_data) ||
      !"longitude" %in% names(model_data) ||
      is.null(pearson_resid) ||
      length(pearson_resid) != nrow(model_data)) {
    return(tibble::tibble(
      outcome = outcome,
      model = model_label,
      n_sites = NA_integer_,
      mean_abs_site_residual = NA_real_,
      mean_nearest_neighbor_km = NA_real_,
      nearest_neighbor_residual_correlation = NA_real_,
      moran_like_inverse_distance = NA_real_
    ))
  }

  site_resid <- model_data %>%
    mutate(pearson_residual = pearson_resid) %>%
    group_by(site_id, latitude, longitude) %>%
    summarise(
      mean_residual = mean(pearson_residual, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    filter(!is.na(latitude), !is.na(longitude))

  if (nrow(site_resid) < 3) {
    return(tibble::tibble(
      outcome = outcome,
      model = model_label,
      n_sites = nrow(site_resid),
      mean_abs_site_residual = mean(abs(site_resid$mean_residual), na.rm = TRUE),
      mean_nearest_neighbor_km = NA_real_,
      nearest_neighbor_residual_correlation = NA_real_,
      moran_like_inverse_distance = NA_real_
    ))
  }

  dist_mat <- outer(
    seq_len(nrow(site_resid)),
    seq_len(nrow(site_resid)),
    Vectorize(function(i, j) {
      haversine_km(
        site_resid$latitude[i],
        site_resid$longitude[i],
        site_resid$latitude[j],
        site_resid$longitude[j]
      )
    })
  )
  diag(dist_mat) <- Inf
  nearest_idx <- apply(dist_mat, 1, which.min)
  nearest_dist <- dist_mat[cbind(seq_len(nrow(site_resid)), nearest_idx)]
  nearest_resid <- site_resid$mean_residual[nearest_idx]

  inv_dist <- 1 / dist_mat
  inv_dist[!is.finite(inv_dist)] <- 0
  diag(inv_dist) <- 0
  centered_resid <- site_resid$mean_residual - mean(site_resid$mean_residual, na.rm = TRUE)
  denom <- sum(centered_resid^2, na.rm = TRUE)
  moran_like <- if (denom > 0 && sum(inv_dist) > 0) {
    (nrow(site_resid) / sum(inv_dist)) *
      sum(inv_dist * tcrossprod(centered_resid), na.rm = TRUE) / denom
  } else {
    NA_real_
  }

  tibble::tibble(
    outcome = outcome,
    model = model_label,
    n_sites = nrow(site_resid),
    mean_abs_site_residual = mean(abs(site_resid$mean_residual), na.rm = TRUE),
    mean_nearest_neighbor_km = mean(nearest_dist, na.rm = TRUE),
    nearest_neighbor_residual_correlation = suppressWarnings(cor(site_resid$mean_residual, nearest_resid, use = "complete.obs")),
    moran_like_inverse_distance = moran_like
  )
}

run_region_blocked_cv <- function(data, response_col, outcome_label, pred_exclude) {
  regions <- sort(unique(as.character(data$region)))

  purrr::map_dfr(regions, function(holdout_region) {
    train <- data %>% filter(region != holdout_region) %>% droplevels()
    test <- data %>% filter(region == holdout_region)

    if (nrow(train) < 200 || nrow(test) < 25) {
      return(tibble::tibble(
        outcome = outcome_label,
        holdout_region = holdout_region,
        n_train = nrow(train),
        n_test = nrow(test),
        brier_score = NA_real_,
        log_loss = NA_real_,
        auc = NA_real_,
        accuracy = NA_real_,
        sensitivity = NA_real_,
        specificity = NA_real_
      ))
    }

    fit <- fit_gam_safe(
      build_formula(response_col, train, spatiotemporal = TRUE),
      data = train,
      family = binomial(),
      model_name = paste0(outcome_label, "_region_holdout_", gsub("[^A-Za-z0-9]+", "_", holdout_region))
    )

    if (is.null(fit)) {
      return(tibble::tibble(
        outcome = outcome_label,
        holdout_region = holdout_region,
        n_train = nrow(train),
        n_test = nrow(test),
        brier_score = NA_real_,
        log_loss = NA_real_,
        auc = NA_real_,
        accuracy = NA_real_,
        sensitivity = NA_real_,
        specificity = NA_real_
      ))
    }

    newdata <- prepare_region_holdout_newdata(test, as_tibble(fit$model))
    preds <- tryCatch(
      predict(fit, newdata = newdata, type = "response", exclude = pred_exclude),
      error = function(e) rep(mean(train[[response_col]], na.rm = TRUE), nrow(newdata))
    )

    bind_cols(
      tibble::tibble(
        outcome = outcome_label,
        holdout_region = holdout_region,
        n_train = nrow(train),
        n_test = nrow(test)
      ),
      calc_binary_metrics(test[[response_col]], as.numeric(preds))
    )
  })
}

predict_ci <- function(model, newdata, type = c("response", "link"), exclude = NULL) {
  type <- match.arg(type)
  if (!is.null(model$model)) {
    factor_cols <- intersect(
      c("survey_year_factor", "study", "site_id", "population_type", "disturbance_state"),
      intersect(names(newdata), names(model$model))
    )

    for (col in factor_cols) {
      model_levels <- levels(model$model[[col]])
      if (length(model_levels) == 0) {
        next
      }

      new_vals <- as.character(newdata[[col]])
      if (identical(col, "survey_year_factor")) {
        unmatched <- !is.na(new_vals) & !new_vals %in% model_levels
        if (any(unmatched)) {
          model_years <- suppressWarnings(as.numeric(model_levels))
          for (idx in which(unmatched)) {
            year_num <- suppressWarnings(as.numeric(new_vals[idx]))
            if (is.finite(year_num) && any(is.finite(model_years))) {
              new_vals[idx] <- model_levels[which.min(abs(model_years - year_num))]
            } else {
              new_vals[idx] <- model_levels[1]
            }
          }
        }
      } else {
        new_vals[is.na(new_vals) | !new_vals %in% model_levels] <- model_levels[1]
      }
      newdata[[col]] <- factor(new_vals, levels = model_levels)
    }
  }

  pr <- predict(model, newdata = newdata, type = type, se.fit = TRUE, exclude = exclude)
  fit_vals <- as.numeric(pr$fit)
  se_vals <- as.numeric(pr$se.fit)
  tibble::as_tibble(newdata) %>%
    mutate(
      fit_link = if (type == "link") fit_vals else qlogis(pmin(pmax(fit_vals, 1e-6), 1 - 1e-6)),
      se_link = if (type == "link") se_vals else se_vals /
        (pmin(pmax(fit_vals, 1e-6), 1 - 1e-6) * (1 - pmin(pmax(fit_vals, 1e-6), 1 - 1e-6))),
      fit = if (type == "response") fit_vals else plogis(fit_vals),
      lwr = plogis(fit_link - 1.96 * se_link),
      upr = plogis(fit_link + 1.96 * se_link)
    )
}

fit_gam_safe <- function(formula, data, family, model_name) {
  cat(sprintf("  Fitting %s ...\n", model_name))
  tryCatch(
    mgcv::gam(
      formula = formula,
      data = data,
      family = family,
      method = "REML",
      select = TRUE
    ),
    error = function(e) {
      cat(sprintf("    WARNING: %s failed: %s\n", model_name, e$message))
      NULL
    }
  )
}

build_formula <- function(outcome, data, spatiotemporal = FALSE) {
  terms <- c("s(log_size, k = 5)")

  if ("population_type" %in% names(data) &&
      is.factor(data$population_type) &&
      nlevels(droplevels(data$population_type)) > 1) {
    terms <- c(terms, "population_type")
  }

  if ("disturbance_state" %in% names(data) &&
      is.factor(data$disturbance_state) &&
      nlevels(droplevels(data$disturbance_state)) > 1) {
    terms <- c(terms, "disturbance_state")
  }

  if (spatiotemporal) {
    if (identical(outcome, "survived")) {
      terms <- c(terms, "s(survey_year_num, k = 10)")
    }
    terms <- c(
      terms,
      "s(survey_year_factor, bs = \"re\")",
      "s(longitude, latitude, k = 20)",
      "s(site_id, bs = \"re\")"
    )
  }

  terms <- c(terms, "s(study, bs = \"re\")")
  stats::as.formula(paste(outcome, "~", paste(terms, collapse = " + ")))
}

cat("Loading prepared panel data...\n")
surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

if (!"population_type" %in% names(surv_data)) {
  surv_data <- surv_data %>%
    mutate(
      is_fragment = ifelse("fragment" %in% names(.), fragment == "Y", FALSE),
      population_type = ifelse(is_fragment, "Restoration fragment", "Natural colony")
    )
}

if (!"population_type" %in% names(growth_data)) {
  growth_data <- growth_data %>%
    mutate(
      is_fragment = ifelse("fragment" %in% names(.), fragment == "Y", FALSE),
      population_type = ifelse(is_fragment, "Restoration fragment", "Natural colony")
    )
}

surv_panel <- surv_data %>%
  mutate(
    survey_year_num = as.numeric(survey_yr),
    survey_year_factor = factor(survey_yr),
    site_id = factor(interaction(region, location, plot, drop = TRUE, lex.order = TRUE)),
    site_year = factor(interaction(site_id, survey_yr, drop = TRUE, lex.order = TRUE)),
    study = factor(study),
    disturbance_state = factor(
      make_disturbance_state(exclude_from_baseline, timeline_event_count),
      levels = disturbance_state_levels
    ),
    population_type = factor(population_type)
  ) %>%
  filter(
    !is.na(survived),
    !is.na(log_size),
    !is.na(latitude),
    !is.na(longitude),
    !is.na(survey_year_num)
  ) %>%
  droplevels()

growth_panel <- growth_data %>%
  mutate(
    survey_year_num = as.numeric(survey_yr),
    survey_year_factor = factor(survey_yr),
    site_id = factor(interaction(region, location, plot, drop = TRUE, lex.order = TRUE)),
    site_year = factor(interaction(site_id, survey_yr, drop = TRUE, lex.order = TRUE)),
    study = factor(study),
    disturbance_state = factor(
      make_disturbance_state(exclude_from_baseline, timeline_event_count),
      levels = disturbance_state_levels
    ),
    population_type = factor(population_type),
    positive_growth = as.integer(growth_metric > 0)
  ) %>%
  filter(
    !is.na(positive_growth),
    !is.na(log_size),
    !is.na(latitude),
    !is.na(longitude),
    !is.na(survey_year_num),
    !coalesce(impossible_growth, FALSE)
  ) %>%
  droplevels()

coverage_summary <- tibble::tibble(
  dataset = c("survival_panel", "growth_panel"),
  n_rows = c(nrow(surv_panel), nrow(growth_panel)),
  n_studies = c(dplyr::n_distinct(surv_panel$study), dplyr::n_distinct(growth_panel$study)),
  n_sites = c(dplyr::n_distinct(surv_panel$site_id), dplyr::n_distinct(growth_panel$site_id)),
  n_site_years = c(dplyr::n_distinct(surv_panel$site_year), dplyr::n_distinct(growth_panel$site_year)),
  year_min = c(min(surv_panel$survey_year_num), min(growth_panel$survey_year_num)),
  year_max = c(max(surv_panel$survey_year_num), max(growth_panel$survey_year_num)),
  pct_florida_keys = c(
    mean(surv_panel$region == "Florida Keys") * 100,
    mean(growth_panel$region == "Florida Keys") * 100
  )
)

write_csv(coverage_summary, file.path(output_dir, "spatiotemporal_data_coverage.csv"))

cat(sprintf("  Survival panel: %d rows, %d sites, %d site-years\n",
            nrow(surv_panel), n_distinct(surv_panel$site_id), n_distinct(surv_panel$site_year)))
cat(sprintf("  Growth panel:   %d rows, %d sites, %d site-years\n\n",
            nrow(growth_panel), n_distinct(growth_panel$site_id), n_distinct(growth_panel$site_year)))

print_subheader("Fitting spatiotemporal survival models")

surv_base_formula <- build_formula("survived", surv_panel, spatiotemporal = FALSE)
surv_spacetime_formula <- build_formula("survived", surv_panel, spatiotemporal = TRUE)

surv_base <- fit_gam_safe(
  surv_base_formula,
  data = surv_panel,
  family = binomial(),
  model_name = "survival_base"
)

surv_spacetime <- fit_gam_safe(
  surv_spacetime_formula,
  data = surv_panel,
  family = binomial(),
  model_name = "survival_spatiotemporal"
)

print_subheader("Fitting spatiotemporal positive-growth models")

growth_base_formula <- build_formula("positive_growth", growth_panel, spatiotemporal = FALSE)
growth_spacetime_formula <- build_formula("positive_growth", growth_panel, spatiotemporal = TRUE)

growth_base <- fit_gam_safe(
  growth_base_formula,
  data = growth_panel,
  family = binomial(),
  model_name = "growth_base"
)

growth_spacetime <- fit_gam_safe(
  growth_spacetime_formula,
  data = growth_panel,
  family = binomial(),
  model_name = "growth_spatiotemporal"
)

surv_comp <- bind_rows(
  extract_model_metrics(surv_base, "baseline", "survival"),
  extract_model_metrics(surv_spacetime, "spatiotemporal", "survival")
) %>%
  mutate(delta_aic_vs_best = aic - min(aic, na.rm = TRUE))

growth_comp <- bind_rows(
  extract_model_metrics(growth_base, "baseline", "positive_growth"),
  extract_model_metrics(growth_spacetime, "spatiotemporal", "positive_growth")
) %>%
  mutate(delta_aic_vs_best = aic - min(aic, na.rm = TRUE))

write_csv(surv_comp, file.path(output_dir, "spatiotemporal_survival_model_comparison.csv"))
write_csv(growth_comp, file.path(output_dir, "spatiotemporal_growth_model_comparison.csv"))

surv_vcomp <- bind_rows(
  extract_vcomp(surv_base, "survival", "baseline"),
  extract_vcomp(surv_spacetime, "survival", "spatiotemporal")
)
growth_vcomp <- bind_rows(
  extract_vcomp(growth_base, "positive_growth", "baseline"),
  extract_vcomp(growth_spacetime, "positive_growth", "spatiotemporal")
)
surv_kcheck <- bind_rows(
  extract_k_checks(surv_base, "survival", "baseline"),
  extract_k_checks(surv_spacetime, "survival", "spatiotemporal")
)
growth_kcheck <- bind_rows(
  extract_k_checks(growth_base, "positive_growth", "baseline"),
  extract_k_checks(growth_spacetime, "positive_growth", "spatiotemporal")
)

write_csv(surv_vcomp, file.path(output_dir, "spatiotemporal_survival_variance_components.csv"))
write_csv(growth_vcomp, file.path(output_dir, "spatiotemporal_growth_variance_components.csv"))
write_csv(surv_kcheck, file.path(output_dir, "spatiotemporal_survival_kcheck.csv"))
write_csv(growth_kcheck, file.path(output_dir, "spatiotemporal_growth_kcheck.csv"))

spatial_residual_checks <- bind_rows(
  extract_spatial_residual_check(surv_spacetime, surv_panel, "survival", "spatiotemporal"),
  extract_spatial_residual_check(growth_spacetime, growth_panel, "positive_growth", "spatiotemporal")
)

region_blocked_cv <- bind_rows(
  run_region_blocked_cv(surv_panel, "survived", "survival", pred_exclude = c("s(study)", "s(site_id)")),
  run_region_blocked_cv(growth_panel, "positive_growth", "positive_growth", pred_exclude = c("s(study)", "s(site_id)"))
)

write_csv(spatial_residual_checks, file.path(output_dir, "spatiotemporal_spatial_residual_check.csv"))
write_csv(region_blocked_cv, file.path(output_dir, "spatiotemporal_region_blocked_cv.csv"))

print_subheader("Building spatiotemporal summaries")

site_year_summary <- surv_panel %>%
  group_by(region, location, plot, site_id, site_year, latitude, longitude, survey_year_num) %>%
  summarise(
    n_survival = n(),
    survival_rate = mean(survived, na.rm = TRUE),
    median_size_cm2 = median(size_for_class, na.rm = TRUE),
    disturbance_state = safe_modal(as.character(disturbance_state)),
    population_type = safe_modal(as.character(population_type)),
    .groups = "drop"
  ) %>%
  left_join(
    growth_panel %>%
      group_by(site_id, site_year) %>%
      summarise(
        n_growth = n(),
        positive_growth_rate = mean(positive_growth, na.rm = TRUE),
        .groups = "drop"
      ),
    by = c("site_id", "site_year")
  ) %>%
  arrange(region, location, plot, survey_year_num)

site_summary <- site_year_summary %>%
  group_by(region, location, plot, site_id, latitude, longitude) %>%
  summarise(
    n_site_years = n(),
    total_survival_obs = sum(n_survival, na.rm = TRUE),
    mean_survival_rate = weighted.mean(survival_rate, n_survival, na.rm = TRUE),
    mean_positive_growth_rate = weighted.mean(positive_growth_rate, n_growth, na.rm = TRUE),
    first_year = min(survey_year_num, na.rm = TRUE),
    last_year = max(survey_year_num, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(total_survival_obs))

write_csv(site_year_summary, file.path(output_dir, "spatiotemporal_site_year_summary.csv"))
write_csv(site_summary, file.path(output_dir, "spatiotemporal_site_summary.csv"))

print_subheader("Generating prediction surfaces")

pred_exclude <- c("s(study)", "s(site_id)")
surv_reference_year <- sort(unique(surv_panel$survey_year_num))[which.min(abs(sort(unique(surv_panel$survey_year_num)) - stats::median(surv_panel$survey_year_num, na.rm = TRUE)))]
growth_reference_year <- sort(unique(growth_panel$survey_year_num))[which.min(abs(sort(unique(growth_panel$survey_year_num)) - stats::median(growth_panel$survey_year_num, na.rm = TRUE)))]

ref_surv <- surv_panel %>%
  slice(1) %>%
  transmute(
    study = study,
    site_id = site_id,
    site_year = site_year,
    longitude = median(surv_panel$longitude, na.rm = TRUE),
    latitude = median(surv_panel$latitude, na.rm = TRUE),
    log_size = median(surv_panel$log_size, na.rm = TRUE),
    population_type = factor("Natural colony", levels = levels(surv_panel$population_type)),
    disturbance_state = factor("No curated disturbance", levels = disturbance_state_levels)
  )

year_pred <- tibble::tibble(
  survey_year_num = sort(unique(surv_panel$survey_year_num))
) %>%
  mutate(
    survey_year_factor = factor(as.character(survey_year_num), levels = levels(surv_panel$survey_year_factor))
  ) %>%
  tidyr::crossing(ref_surv)

surv_year_predictions <- predict_ci(
  surv_spacetime,
  newdata = year_pred,
  type = "link",
  exclude = pred_exclude
) %>%
  mutate(outcome = "survival") %>%
  select(outcome, survey_year_num, fit, lwr, upr)

ref_growth <- growth_panel %>%
  slice(1) %>%
  transmute(
    study = study,
    site_id = site_id,
    longitude = median(growth_panel$longitude, na.rm = TRUE),
    latitude = median(growth_panel$latitude, na.rm = TRUE),
    log_size = median(growth_panel$log_size, na.rm = TRUE),
    population_type = factor(as.character(population_type), levels = levels(growth_panel$population_type)),
    disturbance_state = factor("No curated disturbance", levels = disturbance_state_levels)
  )

growth_year_predictions <- predict_ci(
  growth_spacetime,
  newdata = tibble::tibble(
    survey_year_num = sort(unique(growth_panel$survey_year_num))
  ) %>%
    mutate(
      survey_year_factor = factor(as.character(survey_year_num), levels = levels(growth_panel$survey_year_factor))
    ) %>%
    tidyr::crossing(ref_growth),
  type = "link",
  exclude = pred_exclude
) %>%
  mutate(outcome = "positive_growth") %>%
  select(outcome, survey_year_num, fit, lwr, upr)

year_predictions <- bind_rows(surv_year_predictions, growth_year_predictions)

spatial_pred <- site_summary %>%
  select(region, location, plot, site_id, latitude, longitude) %>%
  distinct() %>%
  mutate(
    survey_year_num = surv_reference_year,
    survey_year_factor = factor(as.character(surv_reference_year), levels = levels(surv_panel$survey_year_factor)),
    pred_study = factor(as.character(ref_surv$study), levels = levels(surv_panel$study)),
    pred_site_id = factor(as.character(ref_surv$site_id), levels = levels(surv_panel$site_id)),
    pred_site_year = factor(as.character(ref_surv$site_year), levels = levels(surv_panel$site_year)),
    log_size = median(surv_panel$log_size, na.rm = TRUE),
    population_type = factor("Natural colony", levels = levels(surv_panel$population_type)),
    disturbance_state = factor("No curated disturbance", levels = disturbance_state_levels)
  )

surv_spatial_newdata <- spatial_pred %>%
  mutate(
    study = pred_study,
    site_id = pred_site_id,
    site_year = pred_site_year
  )

growth_spatial_newdata <- spatial_pred %>%
  transmute(
    region,
    location,
    plot,
    site_id,
    latitude,
    longitude,
    survey_year_num = growth_reference_year,
    survey_year_factor = factor(as.character(growth_reference_year), levels = levels(growth_panel$survey_year_factor)),
    study = factor(as.character(ref_growth$study), levels = levels(growth_panel$study)),
    site_id_pred = factor(as.character(ref_growth$site_id), levels = levels(growth_panel$site_id)),
    log_size = median(growth_panel$log_size, na.rm = TRUE),
    disturbance_state = factor("No curated disturbance", levels = disturbance_state_levels)
  )

survival_spatial_predictions <- predict_ci(
  surv_spacetime,
  newdata = surv_spatial_newdata,
  type = "link",
  exclude = pred_exclude
) %>%
  mutate(outcome = "survival") %>%
  select(outcome, fit, lwr, upr)

growth_spatial_predictions <- predict_ci(
  growth_spacetime,
  newdata = growth_spatial_newdata %>%
    mutate(
      study = study,
      site_id = site_id_pred
    ),
  type = "link",
  exclude = pred_exclude
) %>%
  mutate(outcome = "positive_growth") %>%
  select(outcome, fit, lwr, upr)

spatial_predictions <- bind_rows(
  bind_cols(
    spatial_pred %>% select(region, location, plot, site_id, latitude, longitude),
    survival_spatial_predictions
  ),
  bind_cols(
    spatial_pred %>% select(region, location, plot, site_id, latitude, longitude),
    growth_spatial_predictions
  )
) %>%
  mutate(
    site_id = as.character(site_id),
    site_id = if_else(
      is.na(site_id) | site_id == "NA" | site_id == "",
      if_else(
        is.na(plot) | plot == "",
        paste(region, location, sep = "."),
        paste(region, location, plot, sep = ".")
      ),
      site_id
    )
  ) %>%
  select(outcome, region, location, plot, site_id, latitude, longitude, fit, lwr, upr)

write_csv(year_predictions, file.path(output_dir, "spatiotemporal_year_predictions.csv"))
write_csv(spatial_predictions, file.path(output_dir, "spatiotemporal_spatial_predictions.csv"))

print_subheader("Creating summary figure")

p_year <- ggplot(year_predictions, aes(survey_year_num, fit)) +
  geom_ribbon(aes(ymin = lwr, ymax = upr), fill = pal$coral_warm, alpha = 0.18) +
  geom_line(color = pal$ocean_deep, linewidth = 0.9) +
  facet_wrap(~ outcome, scales = "free_y") +
  scale_x_continuous(breaks = pretty_breaks(6)) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Temporal components from the spatiotemporal demographic models",
    x = "Survey year",
    y = "Predicted probability"
  ) +
  theme_manuscript()

p_space <- site_summary %>%
  ggplot(aes(longitude, latitude)) +
  geom_point(aes(size = total_survival_obs, color = mean_survival_rate), alpha = 0.85) +
  scale_color_gradientn(
    colours = c(pal$surv_light, pal$coral_warm, pal$ocean_deep),
    labels = percent_format(accuracy = 1),
    name = "Observed\nmean survival"
  ) +
  scale_size_continuous(name = "Survival obs", range = c(2.5, 10)) +
  coord_equal() +
  labs(
    title = "Site-level survival structure across the Caribbean panel",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_manuscript()

spatiotemporal_fig <- p_year / p_space +
  patchwork::plot_annotation(
    title = "Spatiotemporal hierarchical structure in A. palmata demography",
    subtitle = "Models account for size, disturbance state, population type, and study clustering"
  )

ggsave(
  filename = file.path(fig_dir, "spatiotemporal_hierarchical_summary.png"),
  plot = spatiotemporal_fig,
  width = 13,
  height = 10,
  dpi = 300
)
ggsave(
  filename = file.path(fig_dir, "spatiotemporal_hierarchical_summary.pdf"),
  plot = spatiotemporal_fig,
  width = 13,
  height = 10
)

cat("\nModel comparison summary:\n")
print(surv_comp)
print(growth_comp)

cat("\nSaved outputs:\n")
cat("  - spatiotemporal_survival_model_comparison.csv\n")
cat("  - spatiotemporal_growth_model_comparison.csv\n")
cat("  - spatiotemporal_survival_variance_components.csv\n")
cat("  - spatiotemporal_growth_variance_components.csv\n")
cat("  - spatiotemporal_survival_kcheck.csv\n")
cat("  - spatiotemporal_growth_kcheck.csv\n")
cat("  - spatiotemporal_year_predictions.csv\n")
cat("  - spatiotemporal_site_summary.csv\n")
cat("  - spatiotemporal_site_year_summary.csv\n")
cat("  - spatiotemporal_spatial_predictions.csv\n")
cat("  - spatiotemporal_spatial_residual_check.csv\n")
cat("  - spatiotemporal_region_blocked_cv.csv\n")
cat("  - spatiotemporal_data_coverage.csv\n")
cat("  - figures/supplementary/spatiotemporal_hierarchical_summary.png/.pdf\n")
