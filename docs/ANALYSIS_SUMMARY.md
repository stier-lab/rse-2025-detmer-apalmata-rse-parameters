# *Acropora palmata* Population Viability Assessment: Structured Results

**Database:** 5,196 survival + 4,344 growth observations | 6 studies | 6 regions | 2004–2024

This document summarizes the complete R analysis pipeline (33 scripts) in **Question → Approach → Answer** format with effect sizes and p-values.

---

## Executive Summary

| Question | Key Result | Effect Size | Confidence |
|----------|------------|-------------|------------|
| Is population growing? | **Declining ~1.4%/yr** | λ = 0.986 | P(decline) = 87.3% |
| What matters most? | **Adult survival (SC5)** | 54.8% elasticity | — |
| Does size predict survival? | Yes, but weakly | OR = 1.41, R² = 5.8% (GAM) | p < 0.0001 |
| Can we pool across studies? | **No** | I² = 97.8% | p < 0.0001; expanded k=16 I² = 97.9% |
| Expanded meta-analysis | Pooled 81.1%, CI narrowed 58% | k=16, N=9,208 | I² = 97.9% |
| Natural vs fragments? | 6.8 pp survival difference (p = 0.30) | 85.1% vs 78.3% | NOT significant; confounded with study; within-restoration heterogeneity (31 pp) exceeds this difference |
| NOAA data dominance | 78% of observations | Results may not generalize | LOSO λ drops 0.035 when NOAA excluded |

---

---

### **Population Model Results** (Sections 1-2)

## 1. Population Trajectory

### Is the population growing or declining?

| | |
|---|---|
| **Approach** | Size-structured Lefkovitch projection matrix; 1,000 bootstrap replicates |
| **Answer** | Population **declining ~1.4%/year** |
| **λ (lambda)** | **0.986** deterministic (95% CI: 0.819–1.020; 1,479 valid of 2,000 bootstrap replicates) |
| **P(decline)** | **87.3%** — bootstrap replicates below replacement |

**Note:** The 95% CI includes replacement (lambda = 1.0), so population decline cannot be confirmed at the 95% level, though 87.3% of bootstrap replicates indicate decline.

---

## 2. Critical Vital Rates

### Which demographic parameter matters most for recovery?

| | |
|---|---|
| **Approach** | Elasticity analysis of projection matrix |
| **Answer** | **Large adult survival (SC5 stasis)** is most critical |
| **Interpretation** | 1% improvement in SC5 survival has 4× more impact than other parameters |

| Vital Rate | Elasticity | Priority |
|------------|------------|----------|
| SC5 stasis (large adult survival) | **54.8%** | Highest |
| SC4 stasis (small adult survival) | 11.4% | High |
| Growth transitions | 14.5% | Medium |
| Retrogression (shrinkage) | 1.0% | Low |
| Fragmentation | 7.8% | Low |

---

---

### **Vital Rate Estimation — Model Inputs** (Sections 3-5)

## 3. Size-Survival Relationship

### Does survival increase with colony size?

| | |
|---|---|
| **Approach** | GLMM with random effects (study, site, year); cluster bootstrap |
| **Answer** | **Yes**, but size explains limited variance |
| **Effect** | OR = **1.41** per log(cm²) (95% CI: 1.36–1.46) |
| **R²** | **5.8%** (GAM deviance explained); McFadden R² = 8.6% (GLM) — size alone explains little |
| **p-value** | p < 0.0001 |

| Size Class | Range (cm²) | Survival | n |
|------------|-------------|----------|---|
| SC1 (Recruits) | 0–25 | 72.4% | 366 |
| SC2 (Small juveniles) | 25–100 | 64.4% | 1,342 |
| SC3 (Large juveniles) | 100–500 | 76.8% | 920 |
| SC4 (Small adults) | 500–2,000 | 87.6% | 837 |
| SC5 (Large adults) | >2,000 | 93.7% | 1,731 |

**Effect size (SC5 vs SC1)**: Cohen's h = **0.46** (small-to-medium)

---

## 4. Size Threshold Detection

### Is there a size threshold where survival changes?

| | |
|---|---|
| **Approach** | GAM second derivative; cluster bootstrap; leave-one-study-out |
| **Answer** | Threshold detected but **highly uncertain** |
| **Estimate** | ~44 cm² live tissue |
| **95% CI** | **10–33,100 cm²** (spans 3 orders of magnitude) |
| **CV** | 47% |
| **Conclusion** | Threshold not reliably detectable — do not use single-value thresholds |

---

## 5. Growth Patterns

### How does growth scale with colony size?

| | |
|---|---|
| **Approach** | Compare Absolute Growth Rate (AGR) vs Relative Growth Rate (RGR) |
| **Answer** | **RGR is 22× better predictor** than AGR |

| Metric | R² | Interpretation |
|--------|-----|----------------|
| AGR (cm²/yr) | **1.5%** | Size explains almost nothing |
| RGR (yr⁻¹) | **33.9%** | Size explains ~34% of variance |

### Relative Growth Rate by Size Class

| Size Class | Mean RGR (yr⁻¹) | Interpretation |
|------------|-----------------|----------------|
| SC1 | 2.58 | Can double size annually |
| SC2 | 1.15 | ~100% size increase/yr |
| SC3 | 0.46 | ~30–45% increase/yr |
| SC4 | 0.30 | ~25–30% increase/yr |
| SC5 | 0.09 | ~10% increase/yr |

---

---

### **Meta-Analysis — Input Validation** (Sections 6-6b)

## 6. Study Heterogeneity

### Can we pool estimates across studies?

| | |
|---|---|
| **Approach** | Random-effects meta-analysis; I², Q-test; Egger's test |
| **Answer** | **No** — considerable heterogeneity; pooling is inappropriate |

| Statistic | Value | p-value |
|-----------|-------|---------|
| **I²** | **97.8%** (95% CI: 93.0–99.7%) | — |
| Cochran's Q | 407.43 (df = 4) | **p < 0.0001** |
| τ² (between-study variance) | 0.515 | — |
| τ (SD of true effects) | 0.718 | — |
| Egger's test (publication bias) | intercept = −2.34 | p = 0.78 (no bias) |

**Pooled survival (random effects)**: 76.9% (95% CI: 56.9–89.4%)
**Prediction interval**: 27.0–96.8% — wide expected range for any new study

---

## 6b. Expanded Meta-Analysis (Two-Tier)

### What happens when we incorporate all available Caribbean survival data?

| | |
|---|---|
| **Approach** | Two-tier meta-analysis: Tier 1 = 5 studies with individual data; Tier 2 = 11 additional study-level estimates from summary data (k=16 total, N=9,208) |
| **Answer** | Pooled survival = 81.1% (95% CI: 73.2-87.1%). I² = 97.9% — heterogeneity persists |

| Metric | Tier 1 only (k=5) | Expanded (k=16) |
|--------|-------------------|-----------------|
| Pooled survival | 76.9% | 81.1% |
| 95% CI | 56.9%-89.4% (32.5 pp) | 73.2%-87.1% (13.9 pp) |
| 95% PI | 27.0%-96.8% | 43.3%-96.0% |
| I² | 97.8% | 97.9% |
| Natural colony studies | k=1 | k=6 |
| Regions | 6 | 10 |

**Natural vs Restoration (expanded):**
- Natural colony (k=6): 85.1% (CI: 70.3-93.2%)
- Restoration fragment (k=10): 78.3% (CI: 66.4-86.8%)
- Difference: 6.8 pp (Q-moderator p = 0.30) — **NOT significant**
- Note: The 13-17 pp difference from individual data shrinks to 6.8 pp when multiple natural colony studies (beyond NOAA) are included

**Moderators (now with k≥10 for defensible analysis):**
- Population type: p = 0.30, R² = 0.6%
- Log colony size: p = 0.40, R² = 0.0%
- Study year: p = 0.99, R² = 0.0%
- Region (categorical): p = 0.14, R² = 39.3% (exploratory, k<10/level)

**New regions added:** Jamaica, Puerto Rico, British Virgin Islands, Bahamas, Virgin Gorda

**Script:** `14b_expanded_meta_analysis.R`

---

---

### **Study-Level Variation — Model Uncertainty** (Sections 7-8)

## 7. Allometric Differences

### Do growth patterns differ across studies?

| | |
|---|---|
| **Approach** | ANCOVA with study × size interaction; size-matched pair comparisons |
| **Answer** | **Yes**, but partially confounded by different size ranges |

| Analysis | p-value | Interpretation |
|----------|---------|----------------|
| ANCOVA (all data) | **p < 0.0001** | Slopes differ, BUT different size ranges |
| Restricted ANCOVA (25–500 cm² only) | **p < 0.001** | TRUE differences within comparable sizes |
| Size-matched pairs (n = 480) | **p < 0.0001** | Biological differences confirmed |

### Allometric Slopes by Study

| Study | Slope | 95% CI | Size Range (cm²) |
|-------|-------|--------|------------------|
| NOAA Survey | 0.918 | 0.901–0.935 | 1–85,120 |
| Pausch et al. | 0.500 | 0.411–0.590 | 5–231 |
| Fundemar | 0.249 | 0.091–0.407 | 7–54 |

**Common size range across ALL studies**: 13.5–38.5 cm² (only 11.4% of data)

---

## 8. Natural Colonies vs Restoration Fragments

> **CONFOUNDING WARNING:** In the individual-level data, natural colony records derive almost exclusively from NOAA NCRMP (99%). Population type is nearly perfectly confounded with study identity, region, methodology, and era. Within-restoration heterogeneity (31 pp between Pausch 57.5% and FUNDEMAR 88.4%) exceeds the between-type difference. The expanded meta-analysis (k=16) includes k=6 natural colony studies and finds the 6.8 pp difference is NOT significant (p = 0.30).

### Do natural colonies differ from restoration fragments?

| | |
|---|---|
| **Approach** | Stratified meta-analysis; size-matched paired comparisons |
| **Answer** | Descriptive difference exists but is **confounded with study identity** |

### Survival Comparison

| Population | Survival | 95% CI | n |
|------------|----------|--------|---|
| Natural colonies | **87.1%** | — | 4,033 |
| Restoration fragments | **72.8%** | 56.6–84.6% | 1,112 |

**Difference**: 14 percentage points lower survival for fragments (descriptive only; see confounding warning above)

**Mendoza-Quiroz natural colonies** (n=35 in size overlap zone) show 100% survival and median RGR of 1.05/yr, falling within the restoration range -- consistent with confounding rather than a true type effect.

### Growth Comparison (Size-Matched)

| Population | Allometric Slope | p-value |
|------------|------------------|---------|
| Natural colonies | 0.941 | — |
| Restoration fragments | 0.776 | **p < 0.0001** |

**Interpretation**: Fragments show shallower allometry but achieve greater final size relative to initial size (paired t-test **p < 0.0001**). However, allometric differences are also confounded with study methodology and size range.

---

---

### **Covariate Effects** (Sections 9-11)

## 9. Variance Partitioning

### How much variance does each factor explain?

| | |
|---|---|
| **Approach** | Nested GLMMs; pseudo-R² comparison |
| **Answer** | Full model explains ~13%; size is the strongest predictor |

| Model | Pseudo-R² | ΔAIC vs null |
|-------|-----------|--------------|
| Size only | **9.7%** | −413 |
| Region only | 1.0% | −1 |
| Year only | 3.9% | −154 |
| Size + Region | 10.4% | −476 |
| Full (Size + Region + Year) | **12.6%** | −547 |

---

## 10. Temporal Trends

### Is there a temporal trend in survival?

| | |
|---|---|
| **Approach** | GLMM with year as continuous predictor |
| **Answer** | **Yes** — survival is declining over time |
| **Effect** | OR = **0.88** per year (95% CI: 0.87–0.90) |
| **Interpretation** | **11.6% decline per year** in survival odds |
| **p-value** | p < 0.0001 |

---

## 11. Regional Variation

### Do demographics vary by region?

| | |
|---|---|
| **Approach** | GLMM with region as fixed effect (Curaçao as baseline) |
| **Answer** | **Yes** — substantial regional variation |

| Region | Survival | OR vs Baseline | 95% CI | n |
|--------|----------|----------------|--------|---|
| Curaçao (baseline) | 84.6% | 1.00 | — | 856 |
| Florida Keys | 79.3% | **1.27** | 1.02–1.58 | 4,072 |
| Navassa | 92.2% | **2.84** | 1.33–6.11 | 102 |
| Dominican Republic | 86.4% | **6.04** | 2.46–14.80 | 44 |
| USVI | 65.2% | 1.40 | 0.73–2.70 | 46 |

---

---

### **Robustness and Cross-Validation** (Sections 12-15)

## 12. Power Analysis

### What sample sizes are needed for future studies?

| | |
|---|---|
| **Approach** | Simulation-based power analysis using observed variance components |
| **Answer** | 80% power requires ~150–400 corals per group |

| Effect Size | Required n (per group) | Power |
|-------------|------------------------|-------|
| Large (OR = 2.0) | ~150 | 80% |
| Medium (OR = 1.5) | ~300 | 80% |
| Small (OR = 1.25) | ~700 | 80% |

---

## 13. Robustness Checks

### How robust are results to individual studies?

| | |
|---|---|
| **Approach** | Leave-one-study-out (LOSO) sensitivity analysis |
| **Answer** | Results are sensitive to NOAA data dominance |

- **λ range across LOSO**: 0.951–0.992
- **Removing NOAA (78% of data)**: λ drops from 0.986 to 0.951, the largest shift (0.035)
- **All other removals**: λ = 0.975–0.992 (cluster tightly)
- **Key finding**: λ is robust to exclusion of most studies, but sensitive to NOAA exclusion (shift of 0.035), reflecting NOAA's dominance (78% of observations)

---

## 14. Context Comparison

### How do field vs nursery demographics compare?

| | |
|---|---|
| **Approach** | Context stratification; effect size calculation |
| **Answer** | Nursery fragments have different dynamics than field populations |

| Context | Survival | Notes |
|---------|----------|-------|
| Field (natural) | 87.1% | Long-term monitoring |
| Nursery in-situ | 72.8% | First-year fragments |
| Nursery ex-situ | — | Insufficient data |

**Caution**: Nursery results may not generalize to field conditions.

---

## 15. Cross-Validation

### How well do models generalize?

| | |
|---|---|
| **Approach** | Leave-one-study-out CV (LOSO-CV), Leave-one-region-out CV (LORO-CV), K-fold CV |
| **Answer** | Models show moderate generalization; study effects are substantial |

| CV Method | Mean AUC | SD |
|-----------|----------|-----|
| LOSO-CV | 0.68 | 0.12 |
| LORO-CV | 0.71 | 0.09 |
| 5-fold CV | 0.72 | 0.03 |

---

---

### **Research Priorities** (Section 16)

## 16. Research Priorities

### What data gaps should be prioritized?

| | |
|---|---|
| **Approach** | Impact × Feasibility × Urgency framework |
| **Answer** | Climate event survival data is the #1 priority |

| Priority | Data Gap | Impact | Feasibility |
|----------|----------|--------|-------------|
| **1** | Climate event survival | Very High | Medium |
| **2** | SC1 recruit field data | High | High |
| **2** | Nursery-to-field transition | High | High |
| **4** | Long-term monitoring (>5 yr) | Very High | Low |
| **5** | SC5 survival across all regions | Very High | Low |

---

## 17. Methodological Limitations

### Size Measurement Heterogeneity
Studies use different size measurement methods: length x width x %live tissue (NOAA), photographic tracing (Pausch), and diameter-squared estimates (others). These are standardized to cm² live tissue but residual measurement error varies by method.

### Mortality Definition Variation
- **NOAA**: Complete tissue mortality or colony disappeared
- **Kuffner**: >=50% tissue loss classified as dead
- **Pausch**: Lost to follow-up = presumed dead

These differences inflate apparent heterogeneity (I² = 97.8%) and complicate cross-study pooling.

### Time Interval Variation
Most monitoring intervals are ~1 year, but Navassa intervals are 2.5-3 years and some Florida intervals exceed 2 years. Annualized rates assume constant hazard, which may not hold over longer intervals.

### SC5 Data Coverage
SC5 stasis (54.8% of total elasticity) is estimated primarily from NOAA data across Florida (n=1,193), Curacao (n=467), and Navassa (n=50). No non-NOAA study contributes SC5 data -- this is a critical single-source dependency for the most influential vital rate.

### Bootstrap Convergence
The population model bootstrap had a 26.1% failure rate (1,479 of 2,000 replicates produced valid results). The reported 95% CI (0.819-1.020) and P(decline) = 87.3% are conditional on successful replicates. Failed replicates may be non-randomly distributed.

---

## Quick Reference: All Effect Sizes & P-values

| Analysis | Key Statistic | Effect Size | p-value |
|----------|---------------|-------------|---------|
| Population trend | λ = 0.986 | ~1.4% decline/yr | P(decline) = 87.3% |
| Most critical parameter | SC5 elasticity | 54.8% | — |
| Size-survival relationship | OR = 1.41 per log(cm²) | R² = 5.8% (GAM); McFadden R² = 8.6% | p < 0.0001 |
| Size threshold | 44 cm² | 95% CI: 10–33,100 | High uncertainty |
| RGR vs AGR predictive power | RGR 22× better | R² = 33.9% vs 1.5% | — |
| Study heterogeneity | I² = 97.8% | Q = 407 | p < 0.0001 |
| Natural vs fragment survival | 85.1% vs 78.3% (expanded k=16) | Δ = 6.8 pp, p = 0.30 | Confounded with study; k=6 natural in expanded meta |
| Natural vs fragment allometry | 0.94 vs 0.78 | Δ = 0.16 | p < 0.0001 |
| Temporal trend | OR = 0.88/yr | 11.6% decline/yr | p < 0.0001 |
| Size-matched pair differences | — | — | p < 0.0001 |

---

## Methods Summary

### R Scripts (33 total)

| Script | Analysis |
|--------|----------|
| `01_data_preparation.R` | Data loading, size class assignment, quality filtering |
| `02_survival_thresholds.R` | GAM, GLMM, cluster bootstrap for threshold detection |
| `03_growth_thresholds.R` | Growth threshold, probability of positive growth |
| `04_growth_rate_comparison.R` | AGR vs RGR, allometry, size-range confound analysis |
| `05_variance_partitioning.R` | Variance partitioning, GLMM interactions |
| `06_data_gap_analysis.R` | Research priority framework |
| `07_integrate_summary_data.R` | Integrate summary data |
| `08_climate_demography.R` | Climate-demography linkages, disturbance effects |
| `09_power_analysis.R` | Sample size recommendations |
| `10_cross_validation.R` | LOSO-CV, LORO-CV, K-fold, temporal holdout |
| `11_context_comparison.R` | Field vs nursery vs lab |
| `12_model_selection.R` | AIC/BIC model comparison |
| `13_transition_matrix.R` | Lefkovitch matrix, λ, elasticity, stochastic projections |
| `14_meta_analysis.R` | Random-effects meta-analysis (k=5, Tier 1) |
| `14b_expanded_meta_analysis.R` | Expanded meta-analysis (k=16, two-tier) |
| `15_heterogeneity_analysis.R` | I², Q-tests, moderator analysis |
| `16_sensitivity_analysis.R` | Leave-one-out, boundary sensitivity, outliers |
| `17_update_parameter_lists.R` | Update RSE parameter lists |
| `18_fig1_study_landscape.R` | Figure 1: Study landscape with map (16 studies) |
| `19_fig2_demographic_rates.R` | Figure 2: Demographic rates (survival + RGR) |
| `20_fig_size_class_survival_synthesis.R` | Figure 4: Size-class survival synthesis |
| `20b_fig_expanded_forest_plot.R` | Figure 5: Expanded forest plot (k=16) |
| `20c_fig_regional_survival.R` | Figure S15: Regional survival variation |
| `21_fig3_natural_vs_restoration.R` | Figure 3: Natural vs restoration comparison |
| `22_fig6_population_model.R` | Figure 6: Population model & sensitivity |
| `23_figS2_data_gaps.R` | Figure S2: Data gaps heatmap |
| `23_verification.R` | Pipeline verification checks |
| `24_supp_S3_S4.R` | Figures S3-S4: Model diagnostics & selection |
| `25_supp_S5_S6_S7_thresholds_growth.R` | Figures S5-S7: Thresholds, AGR vs RGR, allometry |
| `26_supp_S8_S9.R` | Figures S8-S9: Forest plots & heterogeneity |
| `27_supp_S10_S11.R` | Figures S10-S11: Context comparison & climate |
| `28_supp_S12_S13_S14.R` | Figures S12-S14: Sensitivity, CV, projections |

---

## Citation

```
Detmer, R. & Stier, A.C. (2025). Size-structured population demography of Acropora
palmata: a Caribbean synthesis and updated population viability assessment.
GitHub: https://github.com/stier-lab/Detmer-2025-coral-parameters
```

---

*Last updated: February 2026*
