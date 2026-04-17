#!/usr/bin/env Rscript
################################################################################
# 44_REGIME_SWITCHING_MODEL.R
# Hidden-state demographic regime model (background/post-disturbance/catastrophic)
################################################################################
#
# PURPOSE:
#   Estimate latent annual demographic regimes from colony-level survival panels,
#   then align latent states with disturbance overlap to label:
#     1) background regime
#     2) post-disturbance regime
#     3) catastrophic regime
#
# INPUTS:
#   - 05_data/standardized/apal_surv_ind.csv
#   - 05_data/standardized/apal_disturbance_stressor_timeline.csv
#
# OUTPUTS (prefixed regime_switching_):
#   - 06_analysis/output/regime_switching_year_effect_series.csv
#   - 06_analysis/output/regime_switching_year_classification.csv
#   - 06_analysis/output/regime_switching_state_parameters.csv
#   - 06_analysis/output/regime_switching_transition_matrix.csv
#   - 06_analysis/output/regime_switching_fit_summary.csv
#   - 06_analysis/figures/supplementary/exploratory/regime_switching_year_states.png/.pdf
################################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(ggplot2)
})

if (file.exists("06_analysis/scripts/utils/shared_utilities.R")) {
  source("06_analysis/scripts/utils/shared_utilities.R")
} else if (file.exists("utils/shared_utilities.R")) {
  source("utils/shared_utilities.R")
}

set.seed(44)

print_header("44: REGIME-SWITCHING DEMOGRAPHIC MODEL")
cat("  Estimating hidden annual demographic regimes from panel survival data\n\n")

project_root <- get_project_root()
dirs <- setup_output_dirs(project_root)
output_dir <- dirs$output
fig_dir <- dirs$figures_supp
pal <- MANUSCRIPT_PALETTE

surv_file <- file.path(project_root, "05_data/standardized/apal_surv_ind.csv")
timeline_file <- file.path(project_root, "05_data/standardized/apal_disturbance_stressor_timeline.csv")

if (!file.exists(surv_file)) stop("Missing survival panel: ", surv_file)
if (!file.exists(timeline_file)) stop("Missing disturbance timeline: ", timeline_file)

print_subheader("Section 1: Load and Prepare Data")

surv_raw <- read_csv(surv_file, show_col_types = FALSE)
timeline <- read_csv(timeline_file, show_col_types = FALSE) %>%
  mutate(
    Start_Year = as.integer(Start_Year),
    End_Year = as.integer(End_Year)
  )

surv <- surv_raw %>%
  mutate(
    survey_yr = as.integer(survey_yr),
    survived = suppressWarnings(as.numeric(survived)),
    size_cm2 = suppressWarnings(as.numeric(size_cm2)),
    size_live_cm2 = suppressWarnings(as.numeric(size_live_cm2)),
    size_for_model = coalesce(size_live_cm2, size_cm2),
    time_interval_yr = suppressWarnings(as.numeric(time_interval_yr)),
    fragment = if_else(as.character(fragment) %in% c("Y", "y", "1", "TRUE", "T"), "Y", "N")
  ) %>%
  filter(
    !is.na(survey_yr),
    !is.na(survived),
    survived %in% c(0, 1),
    !is.na(size_for_model),
    size_for_model > 0
  )

surv <- attach_disturbance_timeline(
  surv, timeline,
  region_col = "region",
  year_col = "survey_yr",
  interval_col = "time_interval_yr",
  legacy_col = "disturbance"
)

cat(sprintf("  Rows retained for modeling: %s\n", scales::comma(nrow(surv))))
cat(sprintf("  Years retained: %d-%d (%d years)\n",
            min(surv$survey_yr), max(surv$survey_yr),
            n_distinct(surv$survey_yr)))

print_subheader("Section 2: Annual Demographic Condition Series")

# Stage 1: structural covariate model without year effects.
base_model <- glm(
  survived ~ splines::ns(log1p(size_for_model), df = 3) +
    factor(region) + factor(study) + factor(fragment),
  data = surv,
  family = binomial()
)

surv <- surv %>%
  mutate(base_lp = as.numeric(predict(base_model, newdata = ., type = "link")))

# Stage 2: year-level deviations from structural baseline.
year_dev_model <- glm(
  survived ~ factor(survey_yr) - 1 + offset(base_lp),
  data = surv,
  family = binomial()
)

coefs <- coef(year_dev_model)
coef_se <- sqrt(diag(vcov(year_dev_model)))

year_effect_df <- tibble(
  term = names(coefs),
  survey_yr = as.integer(gsub("factor\\(survey_yr\\)", "", term)),
  year_effect_logit = as.numeric(coefs),
  year_effect_se = as.numeric(coef_se)
) %>%
  filter(!is.na(survey_yr), is.finite(year_effect_logit)) %>%
  select(-term)

mode_or_na <- function(x) {
  x <- x[!is.na(x) & x != ""]
  if (length(x) == 0) return(NA_character_)
  names(which.max(table(x)))[1]
}

year_context <- surv %>%
  group_by(survey_yr) %>%
  summarise(
    n_obs = n(),
    raw_survival = mean(survived, na.rm = TRUE),
    median_size_cm2 = median(size_for_model, na.rm = TRUE),
    timeline_overlap_rate = mean(if_else(is.na(timeline_event_count), 0L, timeline_event_count) > 0, na.rm = TRUE),
    exclude_overlap_rate = mean(exclude_from_baseline %in% TRUE, na.rm = TRUE),
    catastrophic_overlap_rate = mean(is_catastrophic %in% TRUE, na.rm = TRUE),
    major_overlap_rate = mean(is_major_disturbance %in% TRUE, na.rm = TRUE),
    dominant_event = mode_or_na(Event_Name),
    dominant_regime = mode_or_na(disturbance_regime),
    .groups = "drop"
  )

year_series <- year_effect_df %>%
  left_join(year_context, by = "survey_yr") %>%
  arrange(survey_yr)

if (nrow(year_series) < 8) {
  stop("Insufficient annual points for regime-switching model (need >= 8 years).")
}

min_obs_for_hmm <- 20
year_series <- year_series %>%
  mutate(low_support_year = n_obs < min_obs_for_hmm)

year_series_fit <- year_series %>%
  filter(!low_support_year)

if (nrow(year_series_fit) < 8) {
  stop(
    "Insufficient supported annual points for HMM after low-support filter (n_obs < ",
    min_obs_for_hmm, ")."
  )
}

write_csv(
  year_series,
  file.path(output_dir, "regime_switching_year_effect_series.csv")
)

cat(sprintf("  Annual effect series built: %d years (%d used in HMM, %d low-support)\n",
            nrow(year_series), nrow(year_series_fit), sum(year_series$low_support_year)))

print_subheader("Section 3: Gaussian HMM (3-state) on Annual Effects")

safe_normalize <- function(x) {
  s <- sum(x)
  if (!is.finite(s) || s <= 0) return(rep(1 / length(x), length(x)))
  x / s
}

hmm_forward_backward <- function(y, A, mu, sigma, pi0) {
  Tn <- length(y)
  K <- length(mu)

  B <- sapply(seq_len(K), function(k) {
    dnorm(y, mean = mu[k], sd = sigma[k], log = FALSE)
  })
  if (is.vector(B)) {
    B <- matrix(B, ncol = K)
  }
  B <- pmax(B, 1e-300)

  alpha <- matrix(0, nrow = Tn, ncol = K)
  beta <- matrix(0, nrow = Tn, ncol = K)
  scales <- rep(0, Tn)

  alpha[1, ] <- pi0 * B[1, ]
  scales[1] <- sum(alpha[1, ])
  if (!is.finite(scales[1]) || scales[1] <= 0) scales[1] <- 1e-300
  alpha[1, ] <- alpha[1, ] / scales[1]

  if (Tn >= 2) {
    for (t in 2:Tn) {
      alpha[t, ] <- as.numeric((alpha[t - 1, ] %*% A) * B[t, ])
      scales[t] <- sum(alpha[t, ])
      if (!is.finite(scales[t]) || scales[t] <= 0) scales[t] <- 1e-300
      alpha[t, ] <- alpha[t, ] / scales[t]
    }
  }

  beta[Tn, ] <- rep(1, K)
  if (Tn >= 2) {
    for (t in seq(Tn - 1, 1)) {
      beta[t, ] <- as.numeric((A %*% (B[t + 1, ] * beta[t + 1, ])) / scales[t + 1])
    }
  }

  gamma <- alpha * beta
  gamma <- gamma / rowSums(gamma)

  xi <- array(0, dim = c(max(Tn - 1, 1), K, K))
  if (Tn >= 2) {
    for (t in 1:(Tn - 1)) {
      numer <- (alpha[t, ] %o% (B[t + 1, ] * beta[t + 1, ])) * A
      denom <- sum(numer)
      if (!is.finite(denom) || denom <= 0) denom <- 1e-300
      xi[t, , ] <- numer / denom
    }
  }

  list(
    gamma = gamma,
    xi = xi,
    logLik = sum(log(scales)),
    B = B
  )
}

fit_gaussian_hmm <- function(y, K = 3, n_starts = 30, max_iter = 500, tol = 1e-7) {
  y <- as.numeric(y)
  y_sd <- sd(y, na.rm = TRUE)
  if (!is.finite(y_sd) || y_sd <= 0) y_sd <- 0.1

  best <- NULL

  for (s in seq_len(n_starts)) {
    q <- quantile(y, probs = seq(0.15, 0.85, length.out = K), na.rm = TRUE)
    mu <- sort(as.numeric(q) + rnorm(K, 0, y_sd * 0.08))
    sigma <- rep(max(y_sd * 0.5, 0.05), K)
    pi0 <- rep(1 / K, K)
    A <- matrix((1 - 0.85) / (K - 1), nrow = K, ncol = K)
    diag(A) <- 0.85

    prev_ll <- -Inf
    ll <- -Inf
    iter <- 0

    for (iter in seq_len(max_iter)) {
      fb <- hmm_forward_backward(y, A, mu, sigma, pi0)
      gamma <- fb$gamma
      xi <- fb$xi
      ll <- fb$logLik

      pi0 <- safe_normalize(gamma[1, ])

      if (length(y) >= 2) {
        for (i in seq_len(K)) {
          denom <- sum(gamma[1:(nrow(gamma) - 1), i])
          if (!is.finite(denom) || denom <= 0) {
            A[i, ] <- rep(1 / K, K)
          } else {
            A[i, ] <- colSums(xi[, i, , drop = FALSE]) / denom
            A[i, ] <- safe_normalize(A[i, ])
          }
        }
      }

      for (k in seq_len(K)) {
        w <- gamma[, k]
        sw <- sum(w)
        if (!is.finite(sw) || sw <= 0) next
        mu[k] <- sum(w * y) / sw
        var_k <- sum(w * (y - mu[k])^2) / sw
        sigma[k] <- sqrt(max(var_k, 1e-4))
      }

      if (abs(ll - prev_ll) < tol) break
      prev_ll <- ll
    }

    if (is.null(best) || ll > best$logLik) {
      best <- list(
        pi0 = pi0,
        A = A,
        mu = mu,
        sigma = sigma,
        gamma = gamma,
        logLik = ll,
        iter = iter,
        start = s
      )
    }
  }

  ord <- order(best$mu)
  best$mu <- best$mu[ord]
  best$sigma <- best$sigma[ord]
  best$pi0 <- safe_normalize(best$pi0[ord])
  best$A <- best$A[ord, ord, drop = FALSE]
  best$gamma <- best$gamma[, ord, drop = FALSE]
  best
}

viterbi_decode <- function(y, A, mu, sigma, pi0) {
  Tn <- length(y)
  K <- length(mu)
  logB <- sapply(seq_len(K), function(k) dnorm(y, mu[k], sigma[k], log = TRUE))
  if (is.vector(logB)) logB <- matrix(logB, ncol = K)

  delta <- matrix(-Inf, nrow = Tn, ncol = K)
  psi <- matrix(0L, nrow = Tn, ncol = K)

  delta[1, ] <- log(pi0 + 1e-300) + logB[1, ]
  if (Tn >= 2) {
    for (t in 2:Tn) {
      for (j in seq_len(K)) {
        vals <- delta[t - 1, ] + log(A[, j] + 1e-300)
        psi[t, j] <- which.max(vals)
        delta[t, j] <- max(vals) + logB[t, j]
      }
    }
  }

  states <- integer(Tn)
  states[Tn] <- which.max(delta[Tn, ])
  if (Tn >= 2) {
    for (t in seq(Tn - 1, 1)) {
      states[t] <- psi[t + 1, states[t + 1]]
    }
  }
  states
}

y <- year_series_fit$year_effect_logit
K <- 3
hmm_fit <- fit_gaussian_hmm(y, K = K, n_starts = 40, max_iter = 800)
decoded_states <- viterbi_decode(y, hmm_fit$A, hmm_fit$mu, hmm_fit$sigma, hmm_fit$pi0)
post_max <- apply(hmm_fit$gamma, 1, max)

year_states_fit <- year_series_fit %>%
  mutate(
    state_id = decoded_states,
    posterior_max = post_max
  )

rescale01 <- function(x) {
  x <- as.numeric(x)
  r <- range(x, na.rm = TRUE)
  if (!is.finite(r[1]) || !is.finite(r[2]) || (r[2] - r[1]) == 0) {
    return(rep(0.5, length(x)))
  }
  (x - r[1]) / (r[2] - r[1])
}

state_profiles <- year_states_fit %>%
  group_by(state_id) %>%
  summarise(
    n_years = n(),
    year_effect_mean = mean(year_effect_logit, na.rm = TRUE),
    year_effect_sd = sd(year_effect_logit, na.rm = TRUE),
    exclude_overlap = mean(exclude_overlap_rate, na.rm = TRUE),
    catastrophic_overlap = mean(catastrophic_overlap_rate, na.rm = TRUE),
    major_overlap = mean(major_overlap_rate, na.rm = TRUE),
    mean_posterior = mean(posterior_max, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    persistence = diag(hmm_fit$A)[state_id]
  )

cat_score <- 0.55 * rescale01(state_profiles$catastrophic_overlap) +
  0.30 * rescale01(state_profiles$exclude_overlap) +
  0.15 * (1 - rescale01(state_profiles$year_effect_mean))

cat_state <- state_profiles$state_id[which.max(cat_score)]
remaining <- setdiff(state_profiles$state_id, cat_state)

bg_score <- 0.60 * rescale01(state_profiles$year_effect_mean) +
  0.25 * (1 - rescale01(state_profiles$catastrophic_overlap)) +
  0.15 * (1 - rescale01(state_profiles$exclude_overlap))

bg_candidates <- state_profiles %>%
  mutate(bg_score = bg_score) %>%
  filter(state_id %in% remaining) %>%
  arrange(desc(bg_score))
bg_state <- bg_candidates$state_id[1]

post_state <- setdiff(state_profiles$state_id, c(cat_state, bg_state))
if (length(post_state) == 0) post_state <- remaining[1]
post_state <- post_state[1]

state_label_map <- tibble(
  state_id = c(bg_state, post_state, cat_state),
  regime_label = c("background", "post_disturbance", "catastrophic")
)

state_parameters <- state_profiles %>%
  left_join(
    tibble(
      state_id = seq_len(K),
      mu = hmm_fit$mu,
      sigma = hmm_fit$sigma,
      initial_prob = hmm_fit$pi0
    ),
    by = "state_id"
  ) %>%
  left_join(state_label_map, by = "state_id") %>%
  arrange(state_id)

year_states <- year_series %>%
  left_join(
    year_states_fit %>%
      select(survey_yr, state_id, posterior_max),
    by = "survey_yr"
  ) %>%
  mutate(
    emission_weight_sum = rowSums(
      sapply(seq_len(K), function(k) dnorm(year_effect_logit, hmm_fit$mu[k], hmm_fit$sigma[k]))
    ),
    state_id = if_else(
      is.na(state_id),
      as.integer(
        apply(
          sapply(seq_len(K), function(k) dnorm(year_effect_logit, hmm_fit$mu[k], hmm_fit$sigma[k])),
          1, which.max
        )
      ),
      state_id
    ),
    posterior_max = if_else(
      is.na(posterior_max),
      apply(
        sapply(seq_len(K), function(k) dnorm(year_effect_logit, hmm_fit$mu[k], hmm_fit$sigma[k])),
        1,
        function(v) {
          s <- sum(v)
          if (!is.finite(s) || s <= 0) return(NA_real_)
          max(v / s)
        }
      ),
      posterior_max
    )
  ) %>%
  select(-emission_weight_sum) %>%
  left_join(state_label_map, by = "state_id") %>%
  mutate(regime_label = if_else(is.na(regime_label), paste0("state_", state_id), regime_label))

transition_long <- expand.grid(
  from_state = seq_len(K),
  to_state = seq_len(K),
  KEEP.OUT.ATTRS = FALSE
) %>%
  mutate(
    transition_prob = as.numeric(hmm_fit$A[cbind(from_state, to_state)])
  ) %>%
  left_join(state_label_map %>% rename(from_state = state_id, from_label = regime_label), by = "from_state") %>%
  left_join(state_label_map %>% rename(to_state = state_id, to_label = regime_label), by = "to_state") %>%
  arrange(from_state, to_state)

n_params <- (K - 1) + K * (K - 1) + 2 * K
fit_summary <- tibble(
  model = "gaussian_hmm_3state_on_annual_logit_deviation",
  n_years = nrow(year_series),
  n_years_modeled = nrow(year_series_fit),
  n_years_low_support = sum(year_series$low_support_year),
  low_support_threshold_n = min_obs_for_hmm,
  n_states = K,
  logLik = hmm_fit$logLik,
  AIC = -2 * hmm_fit$logLik + 2 * n_params,
  BIC = -2 * hmm_fit$logLik + log(nrow(year_series_fit)) * n_params,
  best_start = hmm_fit$start,
  em_iterations = hmm_fit$iter,
  catastrophic_state = cat_state,
  background_state = bg_state,
  post_disturbance_state = post_state
)

write_csv(year_states, file.path(output_dir, "regime_switching_year_classification.csv"))
write_csv(state_parameters, file.path(output_dir, "regime_switching_state_parameters.csv"))
write_csv(transition_long, file.path(output_dir, "regime_switching_transition_matrix.csv"))
write_csv(fit_summary, file.path(output_dir, "regime_switching_fit_summary.csv"))

print_subheader("Section 4: Visualization")

p <- ggplot(year_states, aes(x = survey_yr, y = year_effect_logit)) +
  geom_hline(yintercept = 0, linewidth = 0.35, color = "grey55", linetype = "dashed") +
  geom_ribbon(
    aes(ymin = year_effect_logit - 1.96 * year_effect_se,
        ymax = year_effect_logit + 1.96 * year_effect_se),
    fill = "grey85",
    alpha = 0.5
  ) +
  geom_line(linewidth = 0.6, color = pal$slate_dark) +
  geom_point(
    aes(color = regime_label, shape = catastrophic_overlap_rate > 0),
    size = 2.8,
    stroke = 0.2
  ) +
  scale_color_manual(
    values = c(
      background = pal$ocean_deep,
      post_disturbance = pal$coral_warm,
      catastrophic = "#A50026"
    )
  ) +
  scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 17), name = "Catastrophic overlap") +
  scale_x_continuous(breaks = scales::pretty_breaks(n = 8)) +
  labs(
    title = "Annual hidden-state demographic regime classification",
    subtitle = "HMM fit to year-level survival-condition deviations (adjusted for size, study, region, fragment)",
    x = "Survey year",
    y = "Annual log-odds deviation from structural baseline",
    color = "Latent regime"
  ) +
  theme_manuscript()

ggsave(
  file.path(fig_dir, "exploratory", "regime_switching_year_states.png"),
  p, width = 180, height = 110, units = "mm", dpi = 300
)
pdf_device <- if (capabilities("cairo")) cairo_pdf else "pdf"
ggsave(
  file.path(fig_dir, "exploratory", "regime_switching_year_states.pdf"),
  p, width = 180, height = 110, units = "mm", device = pdf_device
)

cat("  Saved: exploratory/regime_switching_year_states.png/.pdf\n")

print_subheader("Section 5: Key Diagnostics")
cat(sprintf("  HMM logLik: %.3f | AIC: %.2f | BIC: %.2f\n",
            fit_summary$logLik, fit_summary$AIC, fit_summary$BIC))
cat(sprintf("  Mean posterior certainty: %.3f\n", mean(year_states$posterior_max, na.rm = TRUE)))
cat(sprintf("  Low-support years classified by emissions only: %d\n", sum(year_states$low_support_year)))
cat(sprintf("  State means (low to high): %s\n",
            paste(sprintf("%.3f", hmm_fit$mu), collapse = ", ")))
cat(sprintf("  Regime labels -> state IDs: background=%d, post_disturbance=%d, catastrophic=%d\n",
            bg_state, post_state, cat_state))

cat("\nDone. Outputs written with `regime_switching_` prefix.\n")
