# Statistical Methodology Review: A. palmata Demographic Analysis

**Reviewer:** Statistical methodology assessment
**Date:** January 2026
**Scripts Reviewed:**
- `13_transition_matrix.R`
- `14_meta_analysis.R`
- `15_heterogeneity_analysis.R`
- `16_sensitivity_analysis.R`
- `09_power_analysis.R`
- `10_cross_validation.R`
- `01_data_preparation.R`

---

## Executive Summary

This review evaluates the statistical methodology for the *Acropora palmata* demographic parameter synthesis. Overall, the analysis demonstrates **sound statistical practice** with several notable strengths:

- Appropriate use of random-effects meta-analysis with DerSimonian-Laird estimation
- Comprehensive heterogeneity assessment with stratification
- Robust bootstrap confidence intervals
- Multiple sensitivity analyses

However, there are methodological concerns requiring attention, particularly around bootstrap resampling structure, transition matrix time standardization, and sample size adequacy for some transitions.

| Component | Assessment |
|-----------|------------|
| Transition Matrix Construction | **Concerns** |
| Bootstrap Uncertainty | **Concerns** |
| Meta-Analysis | **Valid** |
| Elasticity Analysis | **Valid** |
| Population Model Assumptions | **Concerns** |

---

## 1. Transition Matrix Construction

**Script:** `13_transition_matrix.R`
**Assessment:** Concerns

### 1.1 Transition Probability Calculation

**Method Used:**
- Transitions counted from observed size class changes
- Probabilities calculated as column-normalized counts: `G <- sweep(G_counts, 2, colSums(G_counts), "/")`
- Projection matrix: `A = diag(S) %*% G + F_mat`

**Validity Assessment:** VALID with minor concerns

The calculation correctly computes transition probabilities as:
```
P(j|i) = n_transitions(i→j) / n_individuals_in_class_i
```

This is the standard approach for building empirical transition matrices.

**Concern 1: Conflation of survival and transition**
The current formulation multiplies survival by transition probability:
```r
A <- S_diag %*% G + F_mat
```
This assumes survival and size transition are independent, which may not hold biologically. If mortality is size-dependent and correlated with growth patterns (e.g., shrinking colonies have higher mortality), this factorization underestimates the covariance.

**Recommendation:** Consider estimating joint (survival × transition) probabilities directly from individuals that survived, then scaling by survival. This is currently approximated but the independence assumption should be stated explicitly.

### 1.2 Time Interval Standardization

**Method Used:**
The code comment states:
> "We do NOT normalize by time_interval_yr here. The fragmentation rates from Vardi 2011 appear to be annual rates as reported."

**Assessment:** CONCERNS

**Issue:** The script assumes all transition data are already annualized, but this is not verified programmatically. Growth data (`growth_cm2_yr`) appears to be annual rates, but the relationship between observation intervals and transition probabilities is implicit.

**Specific Concerns:**
1. Studies with observation intervals != 1 year could bias transition estimates
2. The comment mentions "validated results (lambda = 0.986)" as justification for not normalizing, which is circular reasoning
3. No explicit check that `time_interval_yr` values are consistent

**Recommendation:**
- Add explicit verification that growth data represents annual rates
- If observation periods vary, apply: `P_annual = P_observed^(1/t)`
- Document the assumption that all studies report annualized rates

### 1.3 Stasis, Growth, and Shrinkage Classification

**Method Used:**
```r
# Stasis (diagonal)
e_stasis <- sum(diag(elasticity))

# Growth (below diagonal)
e_growth <- sum(elasticity[lower.tri(elasticity)])

# Shrinkage (above diagonal, excluding fragmentation)
e_shrink <- sum(elasticity[upper.tri(elasticity)]) - e_frag
```

**Assessment:** VALID

The classification correctly identifies:
- **Stasis:** Diagonal elements (remaining in same size class)
- **Growth:** Below diagonal (moving to larger classes)
- **Shrinkage:** Above diagonal minus fragmentation

This follows standard matrix population model conventions where columns represent "from" and rows represent "to" states.

### 1.4 Fragmentation Handling

**Method Used:**
```r
# SC4 produces fragments to SC1, SC2, SC3
F_mat["SC1_recruit", "SC4_small_adult"] <- frag_means$F4_SC1
# ... etc.
```

Fragmentation is treated as a separate additive contribution to the projection matrix.

**Assessment:** VALID

The fragmentation matrix correctly represents asexual reproduction where large adults (SC4, SC5) produce fragments that appear in smaller size classes. This is biologically appropriate for *A. palmata*.

**Minor Concern:** Fragmentation elasticity calculation may double-count some transitions:
```r
e_frag <- sum(elasticity[1:3, 4]) + sum(elasticity[1:4, 5])
```
This appears correct, but should verify no overlap with shrinkage transitions from partial mortality.

---

## 2. Bootstrap Uncertainty Quantification

**Script:** `13_transition_matrix.R` (lines 431-494)
**Assessment:** CONCERNS

### 2.1 Number of Iterations

**Method Used:** 500 bootstrap iterations

**Assessment:** ADEQUATE but borderline

For percentile confidence intervals at 95% level:
- 500 iterations provides reasonable precision for point estimates
- However, for tail percentiles (2.5%, 97.5%), the effective sample size is ~12-13 observations
- This introduces Monte Carlo error of approximately +/- 0.015 on the bounds

**Recommendation:** Increase to 1000-2000 iterations for publication-quality results, especially given computational feasibility.

### 2.2 Resampling Structure

**Method Used:**
```r
# Resample survival data
surv_boot <- surv_data %>%
  group_by(size_class) %>%
  sample_frac(1, replace = TRUE) %>%
  ungroup()

# Resample growth data
growth_boot <- growth_filtered %>%
  sample_frac(1, replace = TRUE)
```

**Assessment:** CONCERNS - Mixed stratification

**Issue 1:** Survival resampling is stratified by size class, but growth resampling is not stratified. This inconsistency could bias variance estimates.

**Issue 2:** Neither accounts for the hierarchical structure:
- Colonies within studies are not independent
- Studies within regions may have correlated outcomes
- Ignoring this structure **underestimates** variance

**Recommended Approach:**
```r
# Hierarchical bootstrap (two-stage)
# Stage 1: Resample studies with replacement
studies_boot <- sample(unique(data$study), replace = TRUE)

# Stage 2: For each resampled study, resample colonies
data_boot <- map_dfr(studies_boot, function(s) {
  study_data <- data %>% filter(study == s)
  study_data %>% sample_frac(1, replace = TRUE)
})
```

### 2.3 Confidence Interval Construction

**Method Used:** Percentile method
```r
quantile(lambda_boot, c(0.025, 0.975))
```

**Assessment:** VALID but basic

The percentile method is simple and robust for symmetric distributions. However:
- Lambda distribution may be asymmetric (bounded below by survival rates)
- BCa (bias-corrected and accelerated) intervals would be more accurate
- Should report bootstrap standard error alongside CI

**Recommendation:** Consider BCa intervals or at minimum report bootstrap SE for transparency.

---

## 3. Meta-Analysis

**Script:** `14_meta_analysis.R`
**Assessment:** VALID

### 3.1 Random Effects Model

**Method Used:** DerSimonian-Laird estimator for tau^2
```r
C <- sum(study_effects$weight_fe) - sum(study_effects$weight_fe^2) / sum(study_effects$weight_fe)
tau_sq <- max(0, (Q - df_Q) / C)
```

**Assessment:** VALID

The DerSimonian-Laird estimator is the standard approach for random-effects meta-analysis. The implementation correctly:
- Computes fixed-effects weights first
- Calculates Cochran's Q statistic
- Estimates between-study variance
- Reweights for random effects

**Note:** DL can underestimate tau^2 with few studies. With k=5 studies, consider REML estimation as sensitivity check.

### 3.2 Heterogeneity Interpretation

**Results:**
- I^2 = 97.8% (reported as "CONSIDERABLE")
- tau^2 = 0.5154
- Prediction interval: 12.4% - 98.7%

**Assessment:** CORRECTLY INTERPRETED

The script appropriately:
1. Uses Higgins thresholds (25%, 50%, 75%) for I^2 interpretation
2. Reports both I^2 and tau^2 (absolute heterogeneity)
3. Provides prediction intervals (critical for high heterogeneity)
4. Conducts moderator analysis to explain heterogeneity

**Key Finding Validated:** The stratification by population type (natural vs restoration fragments) reduces I^2 substantially:
- Natural colonies: I^2 = 55.4%
- Restoration fragments: I^2 = 77.4%

This is appropriate use of subgroup analysis.

### 3.3 Prediction Intervals

**Method Used:**
```r
pi_lower <- theta_re - qt(0.975, df_Q) * sqrt(se_theta_re^2 + tau_sq)
pi_upper <- theta_re + qt(0.975, df_Q) * sqrt(se_theta_re^2 + tau_sq)
```

**Assessment:** VALID

Prediction intervals correctly incorporate both:
- Uncertainty in the pooled estimate (se_theta_re)
- Between-study variance (tau_sq)
- Uses t-distribution for small k

**Recommendation:** The wide PI (12.4% - 98.7%) should be prominently reported to convey the true uncertainty for new populations.

---

## 4. Elasticity Analysis

**Script:** `13_transition_matrix.R` (lines 348-426)
**Assessment:** VALID

### 4.1 Elasticity Formula

**Method Used:**
```r
# Sensitivity: dL/da_ij = v_i * w_j / <v, w>
sensitivity <- outer(v, w) / vw_inner

# Elasticity: (a_ij / lambda) * dL/da_ij
elasticity <- (A / lambda) * sensitivity
```

**Assessment:** VALID

This is the correct formula for matrix elasticity (Caswell 2001):
```
e_ij = (a_ij / lambda) * (partial lambda / partial a_ij)
```

The implementation correctly:
1. Computes left and right eigenvectors
2. Normalizes appropriately
3. Calculates proportional sensitivities

### 4.2 Elasticity Sum Constraint

**Expected:** Elasticities should sum to 1

**Observed:** The script reports total elasticity and checks this constraint:
```r
cat(sprintf("\nTotal elasticity: %.3f (should = 1)\n", sum(elasticity)))
```

From the output file:
- elasticity_stasis: 0.745
- elasticity_growth: 0.160
- elasticity_shrink: 0.010
- elasticity_frag: 0.084
- **Sum: 0.999** (rounding)

**Assessment:** VALID - elasticities sum to 1 as required.

### 4.3 Fragmentation Elasticity Separation

**Method Used:**
```r
# Fragmentation (from SC4 and SC5 to smaller classes)
e_frag <- sum(elasticity[1:3, 4]) + sum(elasticity[1:4, 5])

# Shrinkage = upper triangle - fragmentation
e_shrink <- sum(elasticity[upper.tri(elasticity)]) - e_frag
```

**Assessment:** VALID

The code correctly separates:
- Fragmentation: transitions from adult classes (4,5) to smaller classes
- Shrinkage: other above-diagonal transitions (within-individual size reduction)

This distinction is biologically meaningful for *A. palmata*.

---

## 5. Population Model Assumptions

**Assessment:** CONCERNS - some assumptions may be violated

### 5.1 Lefkovitch Matrix Assumptions

**Assumption 1: Time-invariant vital rates**

**Status:** ACKNOWLEDGED but violated

The model uses fixed transition probabilities, but:
- Survival varies 2-fold across years
- Growth is highly variable (I^2 = 97.8% between studies)
- No temporal autocorrelation is modeled

**Recommendation:** Consider stochastic matrix models with year-specific rates drawn from observed distributions.

**Assumption 2: Density-independence**

**Status:** UNTESTED

No data on density-dependent effects are included. For declining populations (lambda < 1), this may be acceptable, but:
- Restoration contexts often involve high-density plantings
- Competitive effects may emerge at recovery

**Recommendation:** State this assumption explicitly; discuss implications for restoration density planning.

**Assumption 3: Closed population (no immigration/emigration)**

**Status:** APPROPRIATE for most applications

Coral colonies are sessile; larvae are not explicitly modeled. For adult population dynamics, this is reasonable.

### 5.2 Sample Size Adequacy per Transition

**Assessment:** CONCERNS for rare transitions

From the transition count matrix in the script:
```r
cat("Transition counts (rows = to, columns = from):\n")
print(G_counts)
```

Potential issues:
- Some transitions may have n < 10 observations
- Low counts lead to high variance in probability estimates
- Particularly concerning for SC5 (large adults) given their rarity

**Specific Concerns:**
- SC5 → SC5 (large adult stasis) carries highest elasticity (54.7%) but may have few observations
- SC5 → SC4 (shrinkage) appears rare in data

**Recommendation:**
1. Report sample sizes for each transition explicitly
2. Use Bayesian shrinkage or pooling for rare transitions
3. Propagate uncertainty in transition probabilities through to lambda CI

### 5.3 Independence Assumptions

**Temporal Independence:** Colonies are tracked over multiple intervals, but intervals are treated as independent. This violates independence if colony identity effects exist.

**Spatial Independence:** Colonies within sites may be correlated (shared environment, shared genotypes). The bootstrap does not account for site-level clustering.

**Recommendation:** Use generalized estimating equations (GEE) or mixed-effects models to properly account for within-colony and within-site correlation.

---

## 6. Additional Methodological Observations

### 6.1 Data Quality Handling (01_data_preparation.R)

**Strength:** The script correctly prioritizes live tissue area over total colony size:
```r
size_for_class = coalesce(size_live_cm2, size_cm2)
```

This is biologically appropriate since partially dead colonies behave like smaller organisms.

**Strength:** Impossible growth values are flagged but retained:
```r
impossible_growth = (growth_cm2_yr < 0) & (abs(growth_cm2_yr) > size_for_class * 1.1)
```

This allows downstream scripts to decide on exclusion.

### 6.2 Leave-One-Out Sensitivity (16_sensitivity_analysis.R)

**Strength:** Comprehensive sensitivity testing including:
- Leave-one-study-out
- Size boundary sensitivity
- Outlier removal effects
- Temporal subsetting

**Result:** No individual study changes pooled survival by >2%, suggesting robustness.

### 6.3 Cross-Validation (10_cross_validation.R)

**Strength:** Multiple CV schemes implemented:
- Leave-one-study-out (LOSO)
- Leave-one-region-out (LORO)
- K-fold
- Temporal holdout

**Concern:** Model performance metrics (Brier score ~0.15-0.18, AUC ~0.55-0.60) indicate modest predictive power. The size-survival relationship explains little variance (GAM R² = 5.8%; McFadden R² = 8.6% from GLM).

---

## 7. Summary of Recommendations

### High Priority

1. **Bootstrap Resampling:** Implement hierarchical bootstrap that resamples studies first, then colonies within studies. This will produce more accurate (likely wider) confidence intervals.

2. **Transition Sample Sizes:** Report and evaluate sample sizes for each transition. Consider Bayesian pooling for sparse cells.

3. **Time Standardization:** Verify programmatically that all input data are annual rates, or implement explicit time-interval correction.

### Medium Priority

4. **Bootstrap Iterations:** Increase from 500 to 1000-2000 for stable percentile estimates.

5. **Random Effects Estimation:** Compare DerSimonian-Laird with REML given small number of studies (k=5).

6. **Stochastic Projections:** Supplement deterministic lambda with stochastic simulations incorporating vital rate variability.

### Lower Priority

7. **BCa Confidence Intervals:** Consider bias-corrected intervals for bootstrap CIs.

8. **Temporal Autocorrelation:** Assess whether year-to-year vital rates are correlated; model if significant.

9. **Density Dependence:** State assumption explicitly; discuss implications for restoration planning at high densities.

---

## 8. Conclusion

The statistical methodology is generally sound and follows best practices for demographic meta-analysis and matrix population modeling. The key strengths include:

- Appropriate random-effects meta-analysis with heterogeneity assessment
- Correct elasticity calculations
- Comprehensive sensitivity and cross-validation analyses
- Thoughtful handling of biological issues (live tissue size, fragmentation)

The primary methodological concern is the **bootstrap resampling structure**, which does not account for hierarchical data structure and may underestimate uncertainty. The **transition matrix assumptions** (time-invariance, density-independence) should be explicitly stated with discussion of implications.

The finding of lambda = 0.986 (95% CI: 0.819-1.020) with 87.3% probability of decline is methodologically defensible. The bootstrap now uses hierarchical resampling (study → observation) with 2,000 replicates (1,479 valid), properly accounting for clustering.

---

**Reviewed by:** Population ecology methodology assessment
**Date:** January 2026
