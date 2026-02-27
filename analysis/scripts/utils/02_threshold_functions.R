################################################################################
# 02_threshold_functions.R - Threshold Detection Framework
################################################################################
#
# Adapted from Detmer et al. (2025) "Evaluating the robustness of nonlinear
# threshold detection in driver-response relationships" (Zenodo: 10.5281/zenodo.14210416)
# and Samhouri et al. (2017) for functional form classification.
#
# Key adaptations for coral demographic data:
#   1. LOSO (leave-one-study-out) instead of LOO (leave-one-out) jackknife
#      — our data is clustered by study
#   2. Binomial family support — survival and P(+growth) are binary
#   3. k=10 default (REML selects optimal smoothness; k=4 available as sensitivity check)
#
# Requires: mgcv, gratia, pracma
# Optional: MuMIn (for AICc), data.table (for between())
#
# Sections:
#   A. Derivative computation (gratia-based)
#   B. Threshold detection functions (4 definitions)
#   C. Nonlinearity gate (GAM vs LM AICc)
#   D. Functional form classification (Samhouri et al. 2017)
#   E. Study-level LOSO jackknife
#   F. Threshold magnitude quantification
#   G. Full threshold analysis wrapper
################################################################################

# =============================================================================
# A. DERIVATIVE COMPUTATION (adapted from jack_thresh.R lines 127-136)
# =============================================================================

#' Compute smoothed first and second derivatives of a GAM using gratia
#'
#' @param gam_model Fitted GAM object from mgcv::gam()
#' @param pred_data Data frame with predictor column matching the GAM smooth term
#' @param predictor_col Name of the predictor column (default: auto-detected)
#' @param eps_val Finite difference step for gratia::derivatives() (default: 5e-6)
#' @param span Loess smoothing span for derivatives (default: 0.1, following Detmer)
#' @return Data frame with columns: x, d1, d1_lower, d1_upper, d2, d2_lower, d2_upper
compute_derivatives <- function(gam_model, pred_data, predictor_col = NULL,
                                eps_val = 5e-6, span = 0.1,
                                smooth_derivatives = FALSE) {
  # Auto-detect predictor column from smooth terms

if (is.null(predictor_col)) {
    sm <- gam_model$smooth[[1]]
    predictor_col <- sm$term
  }

  xvals <- pred_data[[predictor_col]]

  # First derivative
  D1 <- gratia::derivatives(gam_model, data = pred_data, order = 1, eps = eps_val)
  # Second derivative
  D2 <- gratia::derivatives(gam_model, data = pred_data, order = 2, eps = eps_val)

  if (smooth_derivatives) {
    # Legacy: loess post-smoothing (Detmer et al. 2025 original implementation)
    d1_mn  <- predict(loess(d1 ~ x, data = data.frame(d1 = D1$.derivative, x = xvals), span = span))
    d1_up  <- predict(loess(d1 ~ x, data = data.frame(d1 = D1$.upper_ci,   x = xvals), span = span))
    d1_low <- predict(loess(d1 ~ x, data = data.frame(d1 = D1$.lower_ci,   x = xvals), span = span))
    d2_mn  <- predict(loess(d2 ~ x, data = data.frame(d2 = D2$.derivative, x = xvals), span = span))
    d2_up  <- predict(loess(d2 ~ x, data = data.frame(d2 = D2$.upper_ci,   x = xvals), span = span))
    d2_low <- predict(loess(d2 ~ x, data = data.frame(d2 = D2$.lower_ci,   x = xvals), span = span))
  } else {
    # Direct gratia output (preserves simultaneous CI properties)
    d1_mn  <- D1$.derivative
    d1_up  <- D1$.upper_ci
    d1_low <- D1$.lower_ci
    d2_mn  <- D2$.derivative
    d2_up  <- D2$.upper_ci
    d2_low <- D2$.lower_ci
  }

  data.frame(
    x        = xvals,
    d1       = d1_mn,
    d1_lower = d1_low,
    d1_upper = d1_up,
    d2       = d2_mn,
    d2_lower = d2_low,
    d2_upper = d2_up
  )
}

# =============================================================================
# B. THRESHOLD DETECTION FUNCTIONS (adapted from jack_thresh.R lines 580-948)
# =============================================================================

#' T1: max|s''(x)| — location of greatest absolute second derivative
#' Adapted from Detmer et al. abs_max_threshF()
#'
#' @param deriv_i Numeric vector of second derivative values
#' @param sig_type Significance criterion: "none", "jack_quant", or "sim_int"
#' @param xvals Numeric vector of x positions
#' @param deriv_up Upper bound (quantile or simultaneous interval)
#' @param deriv_low Lower bound (quantile or simultaneous interval)
#' @param pkht Minimum peak height for findpeaks()
#' @param pkup Minimum number of increasing steps for findpeaks()
#' @return Threshold x-value, or NA if not detected
abs_max_threshF <- function(deriv_i, sig_type, xvals, deriv_up = NULL,
                            deriv_low = NULL, pkht = 0.01, pkup = 3) {
  # Find minima (peaks in negated derivative)
  mins1 <- pracma::findpeaks(-deriv_i, nups = pkup)
  mins2 <- NULL
  if (!is.null(mins1)) {
    min_heights <- mins1[, 1]
    mins2 <- matrix(mins1[min_heights >= pkht, , drop = FALSE], ncol = 4)
    if (nrow(mins2) == 0) mins2 <- NULL
  }

  # Find maxima
  maxs1 <- pracma::findpeaks(deriv_i, nups = pkup)
  maxs2 <- NULL
  if (!is.null(maxs1)) {
    max_heights <- maxs1[, 1]
    maxs2 <- matrix(maxs1[max_heights >= pkht, , drop = FALSE], ncol = 4)
    if (nrow(maxs2) == 0) maxs2 <- NULL
  }

  min_all <- if (!is.null(mins2)) mins2[, 2] else NULL
  max_all <- if (!is.null(maxs2)) maxs2[, 2] else NULL

  if (is.null(min_all) && is.null(max_all)) return(NA_real_)

  if (sig_type == "none") {
    min1 <- if (!is.null(min_all)) min_all[which.min(deriv_i[min_all])] else NULL
    max1 <- if (!is.null(max_all)) max_all[which.max(deriv_i[max_all])] else NULL
    pks <- c(min1, max1)
    pk_choice <- which.max(abs(deriv_i[pks]))[1]
    return(xvals[pks[pk_choice]])
  }

  if (sig_type %in% c("jack_quant", "sim_int")) {
    min2 <- integer(0)
    if (!is.null(min_all)) {
      min1 <- min_all[deriv_up[min_all] < max(deriv_low)]
      if (length(min1) > 0) min2 <- min1[which.min(deriv_i[min1])]
    }

    max2 <- integer(0)
    if (!is.null(max_all)) {
      max1 <- max_all[deriv_low[max_all] > min(deriv_up)]
      if (length(max1) > 0) max2 <- max1[which.max(deriv_i[max1])]
    }

    pks <- c(min2, max2)
    if (length(pks) == 0) return(NA_real_)
    pk_choice <- which.max(abs(deriv_i[pks]))[1]
    return(xvals[pks[pk_choice]])
  }

  NA_real_
}

#' T2: min(s'') — location of most negative second derivative
#' Adapted from Detmer et al. min_threshF()
min_threshF <- function(deriv_i, sig_type, xvals, deriv_up = NULL,
                        deriv_low = NULL, pkht = 0.01, pkup = 3) {
  mins1 <- pracma::findpeaks(-deriv_i, nups = pkup)
  mins2 <- NULL
  if (!is.null(mins1)) {
    min_heights <- mins1[, 1]
    mins2 <- matrix(mins1[min_heights >= pkht, , drop = FALSE], ncol = 4)
    if (nrow(mins2) == 0) mins2 <- NULL
  }

  min_all <- if (!is.null(mins2)) mins2[, 2] else NULL
  if (is.null(min_all)) return(NA_real_)

  if (sig_type == "none") {
    min_choice <- which.min(deriv_i[min_all])[1]
    return(xvals[min_all[min_choice]])
  }

  if (sig_type %in% c("jack_quant", "sim_int")) {
    min1 <- min_all[deriv_up[min_all] < max(deriv_low)]
    if (length(min1) == 0) return(NA_real_)
    min2 <- min1[which.min(deriv_i[min1])][1]
    return(xvals[min2])
  }

  NA_real_
}

#' T3/T4: Zero-crossing in first or second derivative
#' Adapted from Detmer et al. root_threshF()
root_threshF <- function(deriv_i, sig_type, xvals, deriv_up = NULL,
                         deriv_low = NULL) {
  # Find sign changes
  droots <- which(diff(sign(deriv_i)) != 0)
  if (length(droots) == 0) return(NA_real_)

  if (sig_type == "none") {
    if (length(droots) == 1) {
      return((xvals[droots] + xvals[droots + 1]) / 2)
    }
    # Multiple roots: pick the one with most room on both sides
    min_dist <- numeric(length(droots))
    max_dist <- numeric(length(droots))
    for (rr in seq_along(droots)) {
      n_left  <- if (rr == 1) droots[rr] - 1 else droots[rr] - droots[rr - 1]
      n_right <- if (rr == length(droots)) length(deriv_i) - droots[rr] else droots[rr + 1] - droots[rr]
      min_dist[rr] <- min(n_left, n_right)
      max_dist[rr] <- max(n_left, n_right)
    }
    root_idx <- droots[which.max(min_dist)]
    if (sum(min_dist == max(min_dist)) > 1) {
      tied <- which(min_dist == max(min_dist))
      root_idx <- droots[tied[which.max(max_dist[tied])]][1]
    }
    return((xvals[root_idx] + xvals[root_idx + 1]) / 2)
  }

  if (sig_type %in% c("jack_quant", "sim_int")) {
    d_low_roots <- which(diff(sign(deriv_low)) != 0)
    d_up_roots  <- which(diff(sign(deriv_up)) != 0)

    if (length(d_low_roots) == 0 || length(d_up_roots) == 0) return(NA_real_)

    # Find roots that fall between interval zero-crossings
    sig_roots <- c()
    for (lr in d_low_roots) {
      for (ur in d_up_roots) {
        lo <- min(lr, ur); hi <- max(lr, ur)
        in_range <- droots[droots >= lo & droots <= hi]
        sig_roots <- c(sig_roots, in_range)
      }
    }
    sig_roots <- unique(sig_roots[!is.na(sig_roots)])

    if (length(sig_roots) == 0) return(NA_real_)
    if (length(sig_roots) == 1) return((xvals[sig_roots] + xvals[sig_roots + 1]) / 2)

    # Multiple significant roots: pick the most isolated
    min_dist <- numeric(length(sig_roots))
    max_dist <- numeric(length(sig_roots))
    for (rr in seq_along(sig_roots)) {
      n_left  <- if (rr == 1) sig_roots[rr] - 1 else sig_roots[rr] - sig_roots[rr - 1]
      n_right <- if (rr == length(sig_roots)) length(deriv_i) - sig_roots[rr] else sig_roots[rr + 1] - sig_roots[rr]
      min_dist[rr] <- min(n_left, n_right)
      max_dist[rr] <- max(n_left, n_right)
    }
    root_idx <- sig_roots[which.max(min_dist)]
    if (sum(min_dist == max(min_dist)) > 1) {
      tied <- which(min_dist == max(min_dist))
      root_idx <- sig_roots[tied[which.max(max_dist[tied])]][1]
    }
    return((xvals[root_idx] + xvals[root_idx + 1]) / 2)
  }

  NA_real_
}

# =============================================================================
# C. NONLINEARITY GATE (adapted from lin_check.R)
# =============================================================================

#' Test whether GAM provides significantly better fit than linear model
#' Following Detmer et al. (2025): delta_AICc >= 2 for significance
#'
#' @param data Data frame
#' @param gam_formula Formula for GAM (e.g., survived ~ s(log_size, k=4))
#' @param lm_formula Formula for linear model (e.g., survived ~ log_size)
#' @param family GLM family (default: gaussian())
#' @param k_gam Number of knots for GAM (default: 10)
#' @param aicc_size Use AICc instead of AIC when n < aicc_size (default: 40)
#' @return List with delta_aicc, edf, best_mod, passes_gate
nonlinearity_gate <- function(data, gam_formula, lm_formula,
                              family = gaussian(), k_gam = 10,
                              aicc_size = 40) {
  # Fit GAM
  gam_fit <- mgcv::gam(gam_formula, data = data, family = family, method = "REML")
  edf <- sum(gam_fit$edf)

  # Fit linear model (GLM for non-Gaussian families)
  if (identical(family, gaussian()) || (is.character(family) && family == "gaussian")) {
    lm_fit <- lm(lm_formula, data = data)
  } else {
    lm_fit <- glm(lm_formula, data = data, family = family)
  }

  # Compute AIC/AICc
  n <- nrow(data)
  has_MuMIn <- requireNamespace("MuMIn", quietly = TRUE)
  if (n < aicc_size && has_MuMIn) {
    gam_aic <- MuMIn::AICc(gam_fit)
    lm_aic  <- MuMIn::AICc(lm_fit)
  } else {
    gam_aic <- AIC(gam_fit)
    lm_aic  <- AIC(lm_fit)
  }

  delta_aicc <- lm_aic - gam_aic  # positive = GAM better

  # Classification following Detmer et al.
  if (gam_aic < lm_aic) {
    best_mod <- if (abs(delta_aicc) >= 2) "gam" else "gam_ns"
  } else {
    best_mod <- if (abs(delta_aicc) >= 2) "lm" else "lm_ns"
  }

  list(
    delta_aicc  = delta_aicc,
    edf         = edf,
    gam_aic     = gam_aic,
    lm_aic      = lm_aic,
    best_mod    = best_mod,
    passes_gate = best_mod == "gam"
  )
}

# =============================================================================
# D. FUNCTIONAL FORM CLASSIFICATION (inspired by Samhouri et al. 2017)
# =============================================================================

#' Classify the functional form of a driver-response relationship
#' based on derivative profiles
#'
#' @param deriv_df Data frame from compute_derivatives()
#' @return List with form, description, recommended_threshold_def
classify_functional_form <- function(deriv_df) {
  d1 <- deriv_df$d1
  d2 <- deriv_df$d2
  x  <- deriv_df$x

  # Check for sign changes
  d1_sign_changes <- sum(diff(sign(d1[!is.na(d1)])) != 0)
  d2_sign_changes <- sum(diff(sign(d2[!is.na(d2)])) != 0)

  # Check if d1 crosses zero (dome/trough = non-monotonic)
  has_d1_root <- d1_sign_changes > 0

  # Check if d2 crosses zero (inflection point)
  has_d2_root <- d2_sign_changes > 0

  # Monotonicity of d1
  d1_mostly_positive <- mean(d1 > 0, na.rm = TRUE) > 0.7
  d1_mostly_negative <- mean(d1 < 0, na.rm = TRUE) > 0.7
  is_monotone <- d1_mostly_positive || d1_mostly_negative

  # Curvature dominance
  d2_mostly_negative <- mean(d2 < 0, na.rm = TRUE) > 0.7
  d2_mostly_positive <- mean(d2 > 0, na.rm = TRUE) > 0.7

  # Classify

  if (!is_monotone && has_d1_root) {
    form <- "dome_shaped"
    description <- "Non-monotonic with peak/trough"
    recommended_def <- "zero_d1"
  } else if (has_d2_root && is_monotone) {
    form <- "sigmoidal"
    description <- "Monotonic with inflection point"
    recommended_def <- "min_d2"
  } else if (is_monotone && (d2_mostly_negative || d2_mostly_positive) && !has_d2_root) {
    form <- "hockey_stick"
    description <- "Monotonic with accelerating/decelerating change"
    recommended_def <- "abs_max_d2"
  } else {
    form <- "linear"
    description <- "Approximately linear (no clear threshold)"
    recommended_def <- "abs_max_d2"
  }

  list(
    form            = form,
    description     = description,
    recommended_def = recommended_def,
    d1_sign_changes = d1_sign_changes,
    d2_sign_changes = d2_sign_changes
  )
}

# =============================================================================
# E. STUDY-LEVEL LOSO JACKKNIFE (adapted from jack_thresh.R)
# =============================================================================

#' Leave-one-study-out threshold detection
#'
#' Adapts Detmer et al. observation-level LOO to study-level LOSO
#' for clustered demographic data.
#'
#' @param data Data frame with response and predictor
#' @param gam_formula GAM formula
#' @param family GLM family
#' @param study_col Column name for study grouping
#' @param pred_data Data frame for predictions (must have predictor column)
#' @param predictor_col Name of predictor column (auto-detected if NULL)
#' @param k_val Number of knots (default: 10; k=4 for legacy sensitivity)
#' @param eps_val Finite difference for derivatives (default: 5e-6)
#' @param span Loess smoothing span (default: 0.1)
#' @param smooth_derivatives If TRUE, apply loess post-smoothing (legacy); FALSE preserves gratia CIs
#' @param thresh_methods Character vector of methods
#' @param sig_criteria Character vector of significance criteria
#' @param pk_height Min peak height for findpeaks
#' @param pk_ups Min increasing steps for findpeaks
#' @return List with per-fold results, summary statistics, derivative matrices
loso_threshold <- function(data, gam_formula, family = gaussian(),
                           study_col = "study", pred_data,
                           predictor_col = NULL, k_val = 10,
                           eps_val = 5e-6, span = 0.1,
                           smooth_derivatives = FALSE,
                           gamm_formula = NULL,
                           thresh_methods = c("abs_max_d2", "min_d2", "zero_d2", "zero_d1"),
                           sig_criteria = c("none", "sim_int"),
                           pk_height = 0.01, pk_ups = 3) {
  studies <- unique(data[[study_col]])
  n_studies <- length(studies)
  # Auto-detect predictor column from GAM smooth term if not provided
  if (is.null(predictor_col)) {
    sm <- mgcv::gam(gam_formula, data = data, family = family, method = "REML")$smooth[[1]]
    predictor_col <- sm$term
  }
  xvals <- pred_data[[predictor_col]]

  n_x <- length(xvals)

  # Storage matrices for derivatives across folds
  D1_mat     <- matrix(NA, n_studies, n_x)
  D1_up_mat  <- matrix(NA, n_studies, n_x)
  D1_low_mat <- matrix(NA, n_studies, n_x)
  D2_mat     <- matrix(NA, n_studies, n_x)
  D2_up_mat  <- matrix(NA, n_studies, n_x)
  D2_low_mat <- matrix(NA, n_studies, n_x)

  # Storage for threshold results: one list per method
  thresh_results <- vector("list", length(thresh_methods))
  names(thresh_results) <- thresh_methods
  for (mm in seq_along(thresh_methods)) {
    thresh_results[[mm]] <- matrix(NA, n_studies, length(sig_criteria))
    colnames(thresh_results[[mm]]) <- sig_criteria
  }

  fold_info <- data.frame(
    fold = seq_len(n_studies),
    excluded_study = studies,
    n_remaining = NA_integer_,
    gam_converged = NA,
    stringsAsFactors = FALSE
  )

  # --- LOSO loop ---
  for (f in seq_len(n_studies)) {
    fold_data <- data[data[[study_col]] != studies[f], ]
    fold_info$n_remaining[f] <- nrow(fold_data)

    # Try GAMM first (with study RE), fall back to marginal GAM
    gam_f <- NULL
    if (!is.null(gamm_formula) && length(unique(fold_data[[study_col]])) >= 2) {
      gam_f <- tryCatch({
        mgcv::gam(gamm_formula, data = fold_data, family = family, method = "REML")
      }, error = function(e) NULL)
    }
    if (is.null(gam_f)) {
      gam_f <- tryCatch({
        mgcv::gam(gam_formula, data = fold_data, family = family, method = "REML")
      }, error = function(e) NULL)
    }

    if (is.null(gam_f)) {
      fold_info$gam_converged[f] <- FALSE
      next
    }
    fold_info$gam_converged[f] <- TRUE

    # Build prediction data for this fold's model
    # If the model includes a study RE (GAMM), pred_data needs the study column
    fold_pred_data <- pred_data
    model_vars <- all.vars(formula(gam_f))
    re_var <- setdiff(model_vars, c(all.vars(gam_formula)))
    if (length(re_var) > 0 && !re_var[1] %in% names(fold_pred_data)) {
      ref_level <- levels(factor(fold_data[[re_var[1]]]))[1]
      fold_pred_data[[re_var[1]]] <- factor(ref_level,
                                             levels = levels(factor(fold_data[[re_var[1]]])))
    }

    # Compute derivatives with error handling
    derivs <- tryCatch({
      D1f <- gratia::derivatives(gam_f, data = fold_pred_data, order = 1, eps = eps_val)
      D2f <- gratia::derivatives(gam_f, data = fold_pred_data, order = 2, eps = eps_val)
      list(D1 = D1f, D2 = D2f)
    }, error = function(e) NULL)

    if (is.null(derivs)) next

    # Process derivatives (smooth or direct)
    if (smooth_derivatives) {
      # Legacy: loess post-smoothing (Detmer et al. 2025 original implementation)
      D1_mat[f, ]     <- predict(loess(d1 ~ x, data = data.frame(d1 = derivs$D1$.derivative, x = xvals), span = span))
      D1_up_mat[f, ]  <- predict(loess(d1 ~ x, data = data.frame(d1 = derivs$D1$.upper_ci, x = xvals), span = span))
      D1_low_mat[f, ] <- predict(loess(d1 ~ x, data = data.frame(d1 = derivs$D1$.lower_ci, x = xvals), span = span))
      D2_mat[f, ]     <- predict(loess(d2 ~ x, data = data.frame(d2 = derivs$D2$.derivative, x = xvals), span = span))
      D2_up_mat[f, ]  <- predict(loess(d2 ~ x, data = data.frame(d2 = derivs$D2$.upper_ci, x = xvals), span = span))
      D2_low_mat[f, ] <- predict(loess(d2 ~ x, data = data.frame(d2 = derivs$D2$.lower_ci, x = xvals), span = span))
    } else {
      # Direct gratia output (preserves simultaneous CI properties)
      D1_mat[f, ]     <- derivs$D1$.derivative
      D1_up_mat[f, ]  <- derivs$D1$.upper_ci
      D1_low_mat[f, ] <- derivs$D1$.lower_ci
      D2_mat[f, ]     <- derivs$D2$.derivative
      D2_up_mat[f, ]  <- derivs$D2$.upper_ci
      D2_low_mat[f, ] <- derivs$D2$.lower_ci
    }
  }

  # Compute jackknife quantile bounds (for jack_quant criterion)
  valid_folds <- which(fold_info$gam_converged)
  if (length(valid_folds) >= 2) {
    d2_q_low <- apply(D2_mat[valid_folds, , drop = FALSE], 2, quantile, probs = 0.025, na.rm = TRUE)
    d2_q_up  <- apply(D2_mat[valid_folds, , drop = FALSE], 2, quantile, probs = 0.975, na.rm = TRUE)
    d1_q_low <- apply(D1_mat[valid_folds, , drop = FALSE], 2, quantile, probs = 0.025, na.rm = TRUE)
    d1_q_up  <- apply(D1_mat[valid_folds, , drop = FALSE], 2, quantile, probs = 0.975, na.rm = TRUE)
  } else {
    d2_q_low <- d2_q_up <- d1_q_low <- d1_q_up <- rep(NA, n_x)
  }

  # --- Detect thresholds in each fold ---
  for (f in valid_folds) {
    d2_f    <- D2_mat[f, ]
    d2_up_f <- D2_up_mat[f, ]
    d2_low_f <- D2_low_mat[f, ]
    d1_f    <- D1_mat[f, ]
    d1_up_f <- D1_up_mat[f, ]
    d1_low_f <- D1_low_mat[f, ]

    for (mm in seq_along(thresh_methods)) {
      method <- thresh_methods[mm]

      for (ss in seq_along(sig_criteria)) {
        sig <- sig_criteria[ss]

        # Choose appropriate bounds based on significance criterion
        if (sig == "jack_quant") {
          d2_up_use  <- d2_q_up
          d2_low_use <- d2_q_low
          d1_up_use  <- d1_q_up
          d1_low_use <- d1_q_low
        } else if (sig == "sim_int") {
          d2_up_use  <- d2_up_f
          d2_low_use <- d2_low_f
          d1_up_use  <- d1_up_f
          d1_low_use <- d1_low_f
        } else {
          d2_up_use  <- NULL
          d2_low_use <- NULL
          d1_up_use  <- NULL
          d1_low_use <- NULL
        }

        thresh_val <- tryCatch({
          if (method == "abs_max_d2") {
            abs_max_threshF(d2_f, sig, xvals, d2_up_use, d2_low_use, pk_height, pk_ups)
          } else if (method == "min_d2") {
            min_threshF(d2_f, sig, xvals, d2_up_use, d2_low_use, pk_height, pk_ups)
          } else if (method == "zero_d2") {
            root_threshF(d2_f, sig, xvals, d2_up_use, d2_low_use)
          } else if (method == "zero_d1") {
            root_threshF(d1_f, sig, xvals, d1_up_use, d1_low_use)
          } else NA_real_
        }, error = function(e) NA_real_)

        thresh_results[[mm]][f, ss] <- thresh_val
      }
    }
  }

  # --- Summarize results ---
  summary_list <- list()
  for (mm in seq_along(thresh_methods)) {
    for (ss in seq_along(sig_criteria)) {
      vals <- thresh_results[[mm]][, ss]
      valid <- vals[!is.na(vals)]
      n_detected <- length(valid)
      detection_frac <- n_detected / length(valid_folds)

      summary_list[[paste(thresh_methods[mm], sig_criteria[ss], sep = "_")]] <- data.frame(
        method         = thresh_methods[mm],
        sig_criteria   = sig_criteria[ss],
        threshold_mean = if (n_detected > 0) mean(valid) else NA_real_,
        threshold_se   = if (n_detected > 2) sd(valid) / sqrt(n_detected) else NA_real_,
        ci_lower       = if (n_detected > 1) quantile(valid, 0.025) else NA_real_,
        ci_upper       = if (n_detected > 1) quantile(valid, 0.975) else NA_real_,
        n_detected     = n_detected,
        n_folds        = length(valid_folds),
        detection_frac = detection_frac,
        stringsAsFactors = FALSE
      )
    }
  }
  summary_df <- do.call(rbind, summary_list)
  rownames(summary_df) <- NULL

  list(
    summary       = summary_df,
    fold_info     = fold_info,
    thresh_by_fold = thresh_results,
    deriv_matrices = list(
      D1 = D1_mat, D1_up = D1_up_mat, D1_low = D1_low_mat,
      D2 = D2_mat, D2_up = D2_up_mat, D2_low = D2_low_mat
    ),
    xvals          = xvals
  )
}

# =============================================================================
# F. THRESHOLD MAGNITUDE (inspired by Samhouri et al. 2017)
# =============================================================================

#' Quantify the magnitude of response change across a threshold
#'
#' @param gam_model Fitted GAM
#' @param threshold_x Threshold x-value (on predictor scale)
#' @param pred_data Data frame for predictions
#' @param predictor_col Predictor column name
#' @param delta_range Range on each side of threshold for response change (default: 1.0 log units)
#' @param response_type "link" or "response" scale
#' @return List with absolute change, relative change, etc.
quantify_threshold_magnitude <- function(gam_model, threshold_x, pred_data,
                                         predictor_col = NULL,
                                         delta_range = 1.0,
                                         response_type = "response") {
  if (is.na(threshold_x)) {
    return(list(absolute_change = NA, relative_change_pct = NA, response_below = NA, response_above = NA))
  }

  if (is.null(predictor_col)) {
    predictor_col <- gam_model$smooth[[1]]$term
  }

  # Predict at threshold +/- delta
  below_data <- data.frame(x = threshold_x - delta_range)
  above_data <- data.frame(x = threshold_x + delta_range)
  names(below_data) <- predictor_col
  names(above_data) <- predictor_col

  # If model has extra variables (e.g., study RE from GAMM), add them using
  # the first factor level from the model's training data
  response_col <- all.vars(formula(gam_model))[1]
  model_vars <- all.vars(formula(gam_model))
  extra_vars <- setdiff(model_vars, c(response_col, predictor_col))
  if (length(extra_vars) > 0) {
    model_data <- gam_model$model
    for (ev in extra_vars) {
      if (ev %in% names(model_data)) {
        ref_level <- levels(factor(model_data[[ev]]))[1]
        below_data[[ev]] <- factor(ref_level, levels = levels(factor(model_data[[ev]])))
        above_data[[ev]] <- factor(ref_level, levels = levels(factor(model_data[[ev]])))
      }
    }
  }

  # If model includes a study random effect s(study, bs="re"), exclude it
  # from predictions to get population-average (not study-specific) estimates
  model_smooth_labels <- sapply(gam_model$smooth, function(s) s$label)
  has_study_re <- any(grepl("^s\\(study\\)$", model_smooth_labels))
  exclude_terms <- if (has_study_re) "s(study)" else NULL

  pred_below <- as.numeric(predict(gam_model, newdata = below_data, type = response_type,
                                   exclude = exclude_terms))
  pred_above <- as.numeric(predict(gam_model, newdata = above_data, type = response_type,
                                   exclude = exclude_terms))

  abs_change <- pred_above - pred_below
  rel_change <- if (abs(pred_below) > 1e-10) as.numeric(abs_change / abs(pred_below) * 100) else NA_real_

  list(
    absolute_change     = abs_change,
    relative_change_pct = rel_change,
    response_below      = pred_below,
    response_above      = pred_above
  )
}

# =============================================================================
# G. FULL THRESHOLD ANALYSIS WRAPPER
# =============================================================================

#' Run complete threshold analysis for a single response variable
#'
#' Combines: nonlinearity gate, derivative computation, 4 threshold definitions,
#' functional form classification, LOSO jackknife, and magnitude quantification.
#'
#' @param data Data frame with response and predictor
#' @param gam_formula Formula for GAM
#' @param lm_formula Formula for linear model
#' @param family GLM family
#' @param study_col Study grouping column
#' @param predictor_col Predictor column name
#' @param pred_data Data frame for predictions (if NULL, auto-generated)
#' @param k_val Number of knots
#' @param eps_val Finite difference
#' @param span Loess span
#' @param response_label Label for output (e.g., "survival", "AGR")
#' @return List with all results
run_threshold_analysis <- function(data, gam_formula, lm_formula,
                                   family = gaussian(),
                                   study_col = "study",
                                   predictor_col = NULL,
                                   pred_data = NULL,
                                   k_val = 10, eps_val = 5e-6, span = 0.1,
                                   smooth_derivatives = FALSE,
                                   gamm_formula = NULL,
                                   response_label = "response") {
  cat(sprintf("  Running threshold analysis for %s...\n", response_label))

  # Auto-detect predictor column
  if (is.null(predictor_col)) {
    predictor_col <- all.vars(gam_formula[[3]])[1]  # first RHS variable
  }

  # Generate prediction grid if not provided
  if (is.null(pred_data)) {
    x_range <- range(data[[predictor_col]], na.rm = TRUE)
    pred_data <- data.frame(x = seq(x_range[1], x_range[2], length.out = 200))
    names(pred_data) <- predictor_col
  }

  # 1. Nonlinearity gate
  cat("    Nonlinearity gate...\n")
  gate <- nonlinearity_gate(data, gam_formula, lm_formula, family = family, k_gam = k_val)
  cat(sprintf("    Gate: best_mod=%s, delta_AICc=%.1f, passes=%s\n",
              gate$best_mod, gate$delta_aicc, gate$passes_gate))

  # 2. Fit full GAM
  gam_full <- mgcv::gam(gam_formula, data = data, family = family, method = "REML")

  # Fit GAMM with random effects (sensitivity comparison)
  gam_full_re <- NULL
  if (!is.null(gamm_formula)) {
    cat("    Fitting GAMM with random effects...\n")
    gam_full_re <- tryCatch({
      mgcv::gam(gamm_formula, data = data, family = family, method = "REML")
    }, error = function(e) {
      cat(sprintf("    GAMM failed: %s (using GAM only)\n", e$message))
      NULL
    })
    if (!is.null(gam_full_re)) {
      cat(sprintf("    GAMM dev.expl: %.1f%% (vs GAM: %.1f%%)\n",
                  summary(gam_full_re)$dev.expl * 100,
                  summary(gam_full)$dev.expl * 100))
    }
  }

  # 3. Compute derivatives on full data
  #    If GAMM fitted successfully, use it for derivative computation
  #    (derivatives of the size smooth are computed correctly; the RE smooth is ignored)
  #    Add study column to pred_data for GAMM (gratia::derivatives needs all model vars)
  gamm_pred_data <- pred_data
  if (!is.null(gam_full_re)) {
    gamm_model_vars <- all.vars(gamm_formula)
    study_var <- setdiff(gamm_model_vars, c(all.vars(gam_formula)))
    if (length(study_var) > 0 && !study_var[1] %in% names(gamm_pred_data)) {
      ref_level <- levels(factor(data[[study_var[1]]]))[1]
      gamm_pred_data[[study_var[1]]] <- factor(ref_level,
                                                levels = levels(factor(data[[study_var[1]]])))
    }
  }

  cat("    Computing derivatives (gratia)...\n")
  if (!is.null(gam_full_re)) {
    cat("    Using GAMM (with study RE) for derivative computation\n")
    deriv_df <- tryCatch(
      compute_derivatives(gam_full_re, gamm_pred_data, predictor_col, eps_val, span,
                          smooth_derivatives = smooth_derivatives),
      error = function(e) {
        cat(sprintf("    ! GAMM derivative computation failed: %s\n", e$message))
        cat("    Falling back to marginal GAM for derivatives\n")
        NULL
      }
    )
    # If GAMM derivatives failed, fall back to marginal GAM
    if (is.null(deriv_df)) {
      deriv_df <- tryCatch(
        compute_derivatives(gam_full, pred_data, predictor_col, eps_val, span,
                            smooth_derivatives = smooth_derivatives),
        error = function(e) {
          cat(sprintf("    ! Derivative computation failed: %s\n", e$message))
          NULL
        }
      )
    } else {
      cat(sprintf("    GAMM deviance explained: %.1f%% vs GAM: %.1f%%\n",
                  summary(gam_full_re)$dev.expl * 100, summary(gam_full)$dev.expl * 100))
    }
  } else {
    cat("    Using marginal GAM for derivative computation\n")
    deriv_df <- tryCatch(
      compute_derivatives(gam_full, pred_data, predictor_col, eps_val, span,
                          smooth_derivatives = smooth_derivatives),
      error = function(e) {
        cat(sprintf("    ! Derivative computation failed: %s\n", e$message))
        NULL
      }
    )
  }

  # 4. Classify functional form
  form_class <- if (!is.null(deriv_df)) classify_functional_form(deriv_df) else
    list(form = "unknown", description = "Derivatives unavailable", recommended_def = NA)
  cat(sprintf("    Functional form: %s (%s)\n", form_class$form, form_class$description))

  # 5. Detect thresholds on full data (4 definitions x relevant sig criteria)
  full_thresholds <- list()
  if (!is.null(deriv_df)) {
    xvals <- deriv_df$x
    for (method in c("abs_max_d2", "min_d2", "zero_d2", "zero_d1")) {
      for (sig in c("none", "sim_int")) {
        d_use <- if (grepl("d1$", method)) "d1" else "d2"
        deriv_vals <- deriv_df[[d_use]]
        d_up  <- deriv_df[[paste0(d_use, "_upper")]]
        d_low <- deriv_df[[paste0(d_use, "_lower")]]

        thresh_val <- tryCatch({
          if (method %in% c("abs_max_d2")) {
            abs_max_threshF(deriv_vals, sig, xvals, d_up, d_low)
          } else if (method == "min_d2") {
            min_threshF(deriv_vals, sig, xvals, d_up, d_low)
          } else {
            root_threshF(deriv_vals, sig, xvals, d_up, d_low)
          }
        }, error = function(e) NA_real_)

        full_thresholds[[paste(method, sig, sep = "_")]] <- thresh_val
      }
    }
  }

  # 6. LOSO jackknife (only if gate passes and >1 study)
  n_studies <- length(unique(data[[study_col]]))
  loso_results <- NULL
  if (gate$passes_gate && n_studies >= 2 && !is.null(deriv_df)) {
    cat(sprintf("    LOSO jackknife (%d folds)...\n", n_studies))
    loso_results <- tryCatch(
      loso_threshold(data, gam_formula, family, study_col, pred_data,
                     predictor_col, k_val, eps_val, span,
                     smooth_derivatives = smooth_derivatives,
                     gamm_formula = gamm_formula,
                     sig_criteria = c("none", "sim_int")),
      error = function(e) {
        cat(sprintf("    ! LOSO failed: %s\n", e$message))
        NULL
      }
    )
  }

  # 7. Threshold magnitude for recommended definition
  recommended_thresh_log <- NA_real_
  if (!is.null(form_class$recommended_def)) {
    key <- paste(form_class$recommended_def, "none", sep = "_")
    recommended_thresh_log <- full_thresholds[[key]]
  }

  # Use GAMM for magnitude if available, otherwise marginal GAM
  magnitude_model <- if (!is.null(gam_full_re)) gam_full_re else gam_full
  magnitude <- quantify_threshold_magnitude(
    magnitude_model, recommended_thresh_log, pred_data, predictor_col
  )

  cat(sprintf("    Recommended threshold (log): %.3f (exp: %.0f cm2)\n",
              if (!is.na(recommended_thresh_log)) recommended_thresh_log else NA,
              if (!is.na(recommended_thresh_log)) exp(recommended_thresh_log) else NA))

  # Compile results
  list(
    response_label     = response_label,
    gate               = gate,
    gam_model          = gam_full,
    gam_model_re       = gam_full_re,
    derivatives        = deriv_df,
    form_class         = form_class,
    full_thresholds    = full_thresholds,
    loso               = loso_results,
    magnitude          = magnitude,
    recommended_thresh_log = recommended_thresh_log,
    recommended_thresh_cm2 = if (!is.na(recommended_thresh_log)) exp(recommended_thresh_log) else NA_real_,
    n_studies          = n_studies,
    n_obs              = nrow(data)
  )
}

# =============================================================================
# INITIALIZATION
# =============================================================================

cat("Loaded 02_threshold_functions.R (Detmer et al. 2025 framework)\n")
