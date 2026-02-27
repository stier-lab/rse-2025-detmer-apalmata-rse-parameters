# Comprehensive Analytical Critique — 6-Agent Review

**Date:** 2026-02-26
**Scope:** Full R analysis pipeline (33 scripts)
**Method:** 6 parallel domain-specific review agents, each reading source code and output files

---

## TIER 1: Issues That Could Invalidate Key Findings

### 1. RGR "31x better than AGR" is a statistical artifact
**Domain:** Growth Analysis | **Scripts:** 03, 04

The central claim that RGR explains 33.9% vs AGR at 1.5% conflates **spurious self-correlation** with biological signal. Since RGR = growth/size, regressing it against log(size) creates a mathematical dependency through the denominator — even random growth would produce a strong RGR~size relationship. This is a classic instance of Pearson's spurious ratio correlation.

**Recommended fix:** Simulate data with zero size-growth relationship, compute RGR, and report the null-expectation R². The biological signal is only the excess above this null. Alternatively, test whether the allometric exponent in `log(growth) ~ beta * log(size)` deviates from 1.0.

### 2. Lambda ≈ 1.0 depends almost entirely on fragmentation from 13 data points
**Domain:** Matrix Model | **Scripts:** 13, 16

Without fragmentation, λ drops from 0.986 to 0.893. The fragmentation data comes from a single study (Vardi 2011, 13 rows, 3 regions, one time period). The most policy-relevant conclusion — near-stability vs. severe decline — hinges on the least well-characterized parameter.

**Recommended fix:** Prominently disclose this dependency. Consider presenting results both with and without fragmentation as bracketing scenarios. Seek additional fragmentation data sources.

### 3. Bootstrap is effectively k=2 for survival
**Domain:** Matrix Model | **Scripts:** 13, 16

Only 2 studies contribute natural-colony survival data (NOAA and Mendoza-Quiroz). The 26% bootstrap failure rate occurs exactly when NOAA is not drawn (probability = (1/2)² = 25% ≈ observed 26.1%). Valid replicates always include NOAA, meaning the bootstrap CI [0.819, 1.020] is conditional on NOAA-like vital rates and cannot capture true structural uncertainty.

**Recommended fix:** Acknowledge this as a fundamental identifiability problem. Report the conditional nature of the CI. Consider Bayesian approaches that can incorporate prior information about vital rate plausibility.

### 4. Back-calculated counts inflate Tier 2 precision in expanded meta-analysis
**Domain:** Meta-Analysis | **Scripts:** 14b

The expanded meta (k=16) manufactures integer counts from weighted-mean proportions (`n_survived = round(survival_rate * n_total)` where n_total sums colonies across years and size classes). This treats pseudoreplicated observations as independent, giving Tier 2 studies artificially narrow SEs. The 58% CI narrowing from k=5 to k=16 may be substantially artifactual.

**Recommended fix:** Use the number of unique colonies at first census (not the sum across years) as n_total for Tier 2 studies. Or use a three-level meta-analytic model.

### 5. RGR numerator/denominator mismatch for NOAA data
**Domain:** Data Harmonization | **Script:** 01

`growth_cm2_yr` and `growth_live_cm2_yr` differ substantially for NOAA (correlation = 0.81; 48% of records differ by >50%). Yet RGR is computed as `growth_cm2_yr / size_live_cm2` — mixing total-skeleton growth with live-tissue size. This affects all RGR-based analyses for 78% of the data.

**Recommended fix:** Use `growth_live_cm2_yr / size_live_cm2` consistently for studies where both are available.

---

## TIER 2: Issues That Bias or Weaken Conclusions

### 6. Threshold detection ignores all random effects
**Domain:** Survival + Growth | **Scripts:** 02, 03, utils/02

Both survival and growth threshold analyses use marginal GAMs without study random effects, despite GLMMs being fitted separately. The core inference products (thresholds, derivatives, functional forms) treat all observations as independent, contradicting the project's hierarchical methodology.

**Recommended fix:** Use `gamm()` with study random effects for threshold detection, or at minimum report how results change with/without random effects.

### 7. Three incomparable mortality definitions pooled without harmonization
**Domain:** Data + Survival | **Scripts:** 01

NOAA (no tissue/skeleton gone), Kuffner (≥50% tissue loss), and others (no live tissue) define fundamentally different endpoints. No sensitivity analysis tests the impact. No flag column enables stratification.

**Recommended fix:** Add a `mortality_definition` column to the prepared data. Run sensitivity analyses excluding studies with non-standard definitions.

### 8. Sub-annual survivors inflating survival estimates
**Domain:** Data Harmonization | **Script:** 01

180 NOAA records with intervals <0.8 years and survived=1 are counted as annual survivors. A coral alive at 6 months could die by 12 months. No annualization adjustment is applied.

**Recommended fix:** Either exclude sub-annual survivors or adjust: `S_annual = S_observed^(1/interval)`.

### 9. SC5 is entirely single-study
**Domain:** Data + Matrix | **Scripts:** 01, 13

All SC5 (>2000 cm²) observations come from NOAA. The SC5 stasis elasticity of 54.8% — the most critical parameter — is a single-study estimate. Any "size-dependent survival" finding in the upper range is confounded with NOAA methodology.

**Recommended fix:** Disclose prominently. Present SC5 results with explicit NOAA-only caveat.

### 10. I² = 97.8% makes pooled estimates nearly uninterpretable
**Domain:** Meta-Analysis | **Scripts:** 14, 14b

The prediction interval [43%, 96%] spans most of the plausible range. The headline CI [73.2%, 87.1%] gives false precision. Stratification by population type does NOT reduce heterogeneity (within-group I² = 96.8-97.6%).

**Recommended fix:** Report prediction intervals as the primary interval. De-emphasize the pooled point estimate.

### 11. Loess post-smoothing corrupts derivative CIs
**Domain:** Survival | **Script:** utils/02

The `compute_derivatives()` function adds a loess smooth (span=0.1) on top of `gratia::derivatives()` simultaneous CIs. This invalidates the statistical properties of the confidence bands used for threshold detection.

**Recommended fix:** Remove the loess smoothing layer and use `gratia` derivatives directly, or justify the span choice with sensitivity analysis.

### 12. GAM basis dimension k=4 is overly restrictive
**Domain:** Survival + Growth | **Scripts:** 02, 03

With 4,000+ observations, k=4 limits the smooth to ~3 EDF, potentially suppressing real nonlinear structure. REML with k=10-20 would be more appropriate.

**Recommended fix:** Use k=10 or k=20 and let REML choose the effective complexity. Report k=4 as a sensitivity check.

---

## TIER 3: Methodological Gaps

### 13. No survival-time analysis
**Domain:** Survival

Standard ecological methods (Cox PH, Kaplan-Meier) are absent. These would naturally handle variable observation intervals, staggered entry, and provide hazard ratios.

### 14. Climate confounding analysis is superficial
**Domain:** Robustness | **Script:** 08

Script 08 describes temporal patterns but tests no confounding hypothesis. No external climate data (SST, DHW) is integrated despite being freely available from NOAA Coral Reef Watch.

### 15. Post-hoc power analysis
**Domain:** Robustness | **Script:** 09

Power computed after seeing results is uninformative (Hoenig & Heisey 2001). The simulation also uses GLM instead of the actual GLMM specification.

### 16. McFadden R² vs deviance-explained R² comparison is misleading
**Domain:** Survival

The 8.6% McFadden and 5.8% GAM deviance-explained are different metrics with different scales. McFadden values of 0.2-0.4 indicate "excellent fit" — presenting both without context is misleading.

### 17. No sexual reproduction in the matrix model
**Domain:** Matrix Model | **Script:** 13

The model only includes clonal fragmentation. λ = 0.986 means "declining without sexual recruitment" — a different statement than "population declining."

### 18. Elasticity decomposition sums to 1.069
**Domain:** Matrix Model | **Script:** 16

Fragmentation elasticity appears double-counted alongside stasis/growth/shrinkage (which already sum to 1.0). This is a reporting error.

### 19. Sensitivity script uses different data filtering than main analysis
**Domain:** Matrix Model | **Script:** 16

Script 16 uses ALL growth data for boundary-sensitivity lambdas while script 13 restricts to natural colonies with 0.5-1.5 year intervals. The sensitivity values are not directly comparable.

### 20. Vardi 2011 triple-counted as 3 independent effects
**Domain:** Meta-Analysis | **Script:** 14b

Splitting by region gives one publication 19% of the k=16 effects. A three-level model (`rma.mv()` with `~1|study/region`) would be more appropriate.

---

## What the Analysis Does Well

- **Hierarchical bootstrap design** (3-stage with colony-level resampling) is state-of-the-art
- **Grouped k-fold CV** correctly prevents data leakage across studies
- **Honest uncertainty reporting**: I²=97.8%, wide CIs, weak R², non-significant nat-vs-rest (p=0.30)
- **Size boundary sensitivity analysis** is a genuine robustness check
- **Fragmentation sensitivity analysis** directly tests single-source dependency
- **Knapp-Hartung adjustment** consistently applied for small-k meta-analysis
- **Prediction intervals** reported alongside confidence intervals
- **Bootstrap failure characterization** is an unusual and valuable diagnostic
- **DEFF-adjusted power calculations** correctly account for clustering

---

## Recommended Priority Actions

| Priority | Action | Impact |
|----------|--------|--------|
| 1 | Test RGR spurious correlation via null simulation | Validates or invalidates key growth finding |
| 2 | Fix RGR numerator to use `growth_live_cm2_yr` for NOAA | Corrects 78% of growth data |
| 3 | Correct Tier 2 sample sizes to first-census counts | Honest expanded meta CIs |
| 4 | Run threshold analysis with GAMM (study random effect) | Proper threshold uncertainty |
| 5 | Add mortality-definition sensitivity analysis | Addresses major heterogeneity source |
| 6 | Annualize sub-annual survivors | Removes ~1-2pp survival inflation |
| 7 | Report prediction intervals as primary for meta-analysis | Honest uncertainty communication |
| 8 | Integrate DHW/SST data from NOAA Coral Reef Watch | Address climate confounding gap |
| 9 | Fix elasticity double-count in reporting | Correct summation |
| 10 | Add "what would change our conclusions" section to manuscript | Transparency |

---

## Agent Details

| Agent | Domain | Scripts Reviewed | Top Finding |
|-------|--------|-----------------|-------------|
| Survival | GLMM, GAM, thresholds | 02, 05, utils/01, utils/02 | Threshold detection ignores random effects |
| Growth | RGR/AGR, growth models | 03, 04, utils/02 | RGR comparison is spurious self-correlation |
| Meta-Analysis | metafor, expanded meta | 14, 14b, 15, 11 | Back-calculated counts inflate Tier 2 precision |
| Matrix Model | Lefkovitch, elasticity | 13, 16, 17, 22 | Lambda depends on 13-row fragmentation data |
| Data Harmonization | Data prep, QC | 01, standardized_data/ | RGR numerator/denominator mismatch |
| Robustness | Model selection, CV, bootstrap | 08, 09, 10, 12, 15, 16 | Climate analysis is descriptive, not causal |
