# Data Quality Audit Report
## Acropora palmata Demographic Parameters Database

**Audit Date:** January 21, 2026
**Auditor:** Data Quality Specialist (Automated Analysis)
**Repository:** Detmer-2025-coral-parameters

---

## Executive Summary

This audit evaluates data quality across four core data categories: survival, growth, fragmentation, and output matrices. The overall data quality is **ACCEPTABLE WITH CAVEATS**. Key findings include:

- **5,213 survival records** and **4,344 growth records** from 6 studies
- **NOAA survey dominates** the dataset (78% survival, 80% growth)
- **Transition matrix column sum exceeds 1** for SC5 (Critical Issue)
- **High heterogeneity** (I-squared = 97.8%) indicates substantial between-study variation
- **Navassa growth outlier** confirmed (mean 826 cm2/yr vs. expected ~50-100 cm2/yr)
- **Very limited fragmentation data** (n=13 from single study)

---

## 1. Survival Data Quality (apal_surv_ind.csv)

### 1.1 Summary Statistics

| Metric | Value |
|--------|-------|
| Total records | 5,213 |
| Unique coral IDs | 2,101 |
| Studies | 6 |
| Regions | 7 |
| Year range | 2004-2024 |
| Data types | field (5,151), nursery (62) |

### 1.2 Missing Value Analysis

| Column | N Missing | % Missing | Severity |
|--------|-----------|-----------|----------|
| disturbance | 4,642 | 89.05% | Low (expected) |
| treatment_2 | 4,225 | 81.05% | Low (expected) |
| treatment_1 | 4,110 | 78.84% | Low (expected) |
| plot | 1,165 | 22.35% | Medium |
| depth_m | 144 | 2.76% | Low |
| size_live_cm2 | 71 | 1.36% | Low |
| study_notes | 45 | 0.86% | Low |
| size_cm2 | 16 | 0.31% | **High** (critical field) |

**ISSUE S-1: Missing Size Data (High)**
- 16 records (0.31%) have missing size_cm2 values
- Size is critical for demographic modeling
- **Recommendation:** Investigate source data; exclude or impute if appropriate

### 1.3 Survival Value Validation

| Check | Result | Status |
|-------|--------|--------|
| Unique values | 0, 1 only | PASS |
| Invalid values (not 0/1) | 0 | PASS |
| NA values | 0 | PASS |

### 1.4 Survival Rates by Study

| Study | N | Mean Survival | Status |
|-------|---|---------------|--------|
| pausch_et_al_2018 | 969 | 0.574 | Normal |
| USGS_USVI_exp | 46 | 0.652 | Normal |
| kuffner_et_al_2020 | 53 | 0.811 | Normal |
| fundemar_fragments | 45 | 0.844 | Normal |
| NOAA_survey | 4,048 | 0.860 | Normal |
| mendoza_quiroz_et_al_2023 | 52 | **1.000** | **CHECK** |

**ISSUE S-2: Perfect Survival in One Study (Medium)**
- mendoza_quiroz_et_al_2023 shows 100% survival (n=52)
- This may be accurate but warrants verification
- **Recommendation:** Verify with source data; note in analysis if correct

### 1.5 Duplicate Records

| Check | Result |
|-------|--------|
| Duplicate coral_id + survey_yr combinations | 66 records |
| Unique duplicate combinations | 66 |

**ISSUE S-3: Duplicate Records (High)**
- 66 records appear as duplicates based on coral_id and survey_yr
- Examples: CF1-t024 (2017), CF1-t028 (2005), etc.
- **Recommendation:** Investigate whether these are true duplicates or multi-year transitions; deduplicate if appropriate

### 1.6 Size Distribution (cm2)

| Statistic | Value |
|-----------|-------|
| Min | 1 |
| 1st Quartile | 78 |
| Median | 1,050 |
| Mean | 6,058 |
| 3rd Quartile | 7,840 |
| Max | 118,500 |
| 99th percentile | 48,464 |
| Records with size <= 0 | 0 |

**Status:** Size distribution appears reasonable for *A. palmata*

### 1.7 Fragment Status

| Status | N |
|--------|---|
| N (not fragment) | 4,006 (76.8%) |
| Y (fragment) | 1,207 (23.2%) |

**Note:** Fragments show lower survival (0.63) than non-fragments (0.86), which is biologically expected.

---

## 2. Growth Data Quality (apal_growth_ind.csv)

### 2.1 Summary Statistics

| Metric | Value |
|--------|-------|
| Total records | 4,344 |
| Unique coral IDs | 1,662 |
| Studies | 6 |
| Regions | 7 |
| Year range | 2004-2024 |

### 2.2 Missing Value Analysis

| Column | N Missing | % Missing | Severity |
|--------|-----------|-----------|----------|
| disturbance | 3,856 | 88.77% | Low (expected) |
| treatment_2 | 3,768 | 86.74% | Low (expected) |
| treatment_1 | 3,679 | 84.69% | Low (expected) |
| plot | 859 | 19.77% | Medium |
| depth_m | 250 | 5.76% | Low |
| study_notes | 177 | 4.07% | Low |
| growth_live_cm2_yr | 98 | 2.26% | Low |
| size_live_cm2 | 53 | 1.22% | Low |

### 2.3 Growth Rate Distribution (cm2/yr)

| Statistic | Value |
|-----------|-------|
| Min | -119,365 |
| 1st Quartile | -16.7 |
| Median | 68.8 |
| Mean | -139.0 |
| 3rd Quartile | 570.1 |
| Max | 32,461 |
| 99th percentile | 5,484 |
| 99.9th percentile | 11,278 |

**ISSUE G-1: Extreme Negative Growth (Critical)**
- Minimum growth: -119,365 cm2/yr
- 161 records with growth < -5,000 cm2/yr
- 1,189 records (27.4%) show negative growth (partial mortality)
- **Recommendation:** Review extreme negative values; these may represent measurement error, mortality events coded as shrinkage, or legitimate partial mortality

### 2.4 Outlier Analysis (>99th percentile)

**Top 10 Extreme Growth Values:**

| Study | Region | Coral ID | Initial Size | Growth (cm2/yr) |
|-------|--------|----------|--------------|-----------------|
| NOAA_survey | Florida Keys | CF2-t042 | 2,925 | 32,461 |
| NOAA_survey | Curacao | SM2-t356 | 26,700 | 24,456 |
| NOAA_survey | Curacao | BB3-t267 | 47,150 | 12,417 |
| NOAA_survey | Curacao | BB1-t240 | 20,125 | 11,650 |
| NOAA_survey | Curacao | SQ1-t205 | 23,625 | 11,493 |
| NOAA_survey | Navassa | LB1-t230 | 39,375 | 10,866 |
| NOAA_survey | Curacao | SQ1-t205 | 37,800 | 10,860 |
| NOAA_survey | Florida Keys | CF3-t088 | 106,400 | 10,694 |
| NOAA_survey | Florida Keys | TR1-t299 | 8,700 | 10,407 |
| NOAA_survey | Florida Keys | FR1-t009 | 46,125 | 8,837 |

**ISSUE G-2: Extreme Positive Outliers (High)**
- 44 records exceed 99th percentile (>5,484 cm2/yr)
- Maximum growth (32,461 cm2/yr) is biologically implausible
- All top outliers are from NOAA_survey
- **Recommendation:** Implement outlier detection and flagging; consider winsorizing or excluding

### 2.5 Impossible Growth Flag (in prepared_growth_data.rds)

| Flag | N | % |
|------|---|---|
| FALSE (valid) | 4,044 | 93.1% |
| TRUE (flagged) | 300 | 6.9% |

**ISSUE G-3: Impossible Growth Flag Implementation (Medium)**
- 300 records flagged as impossible growth
- All flagged records show negative growth (min: -119,365, max: -27)
- Flag captures severe partial mortality but may miss implausible positive growth
- **Recommendation:** Extend flag logic to capture extreme positive outliers

### 2.6 Growth by Region

| Region | N | Mean Growth | Median Growth | Status |
|--------|---|-------------|---------------|--------|
| **Navassa** | 94 | **826.1** | 219.6 | **OUTLIER** |
| USVI | 30 | 101.0 | 74.5 | Normal |
| Dominican Republic | 177 | 78.3 | 71.7 | Normal |
| Dry Tortugas | 24 | 57.6 | 55.5 | Normal |
| Mexican Caribbean | 52 | 24.8 | 29.7 | Normal |
| Curacao | 710 | -0.9 | 362.0 | Check |
| Florida Keys | 3,257 | -215.0 | 58.8 | High variance |

**ISSUE G-4: Navassa Growth Outlier (Critical)**
- Navassa mean growth (826 cm2/yr) is 8-10x higher than other regions
- SD is extremely high (2,043 cm2/yr)
- Contains 14 records with |growth| > 2,000 cm2/yr
- **Recommendation:** Investigate Navassa data source; consider excluding or stratifying in analyses

### 2.7 Growth Type Distribution

| Type | N | % |
|------|---|---|
| Growth (positive) | 2,922 | 67.3% |
| Shrinkage (negative) | 1,134 | 26.1% |
| Stable (~0) | 288 | 6.6% |

---

## 3. Fragmentation Data Quality (apal_fragmentation.csv)

### 3.1 Summary Statistics

| Metric | Value |
|--------|-------|
| Total records | 13 |
| Studies | 1 (vardi_2011) |
| Regions | 4 |
| Year range | 2007-2011 |

**ISSUE F-1: Very Limited Sample Size (Critical)**
- Only 13 records from a single study
- Insufficient for robust parameter estimation
- **Recommendation:** Seek additional fragmentation data sources; clearly note uncertainty in matrix projections

### 3.2 Sample Size by Region

| Region | N Records |
|--------|-----------|
| Florida Keys | 5 |
| Curacao | 4 |
| Jamaica | 3 |
| Navassa | 1 |

### 3.3 Time Interval Consistency

| Metric | Value |
|--------|-------|
| Unique intervals | 4 (0.75, 1, 1.25, 2.5 years) |
| Min | 0.75 years |
| Max | 2.5 years |

**ISSUE F-2: Inconsistent Time Intervals (Medium)**
- Time intervals vary from 0.75 to 2.5 years
- Rates should be annualized but methodology should be verified
- **Recommendation:** Verify annualization method; document assumptions

### 3.4 Rate Plausibility

| Column | Min | Max | Mean | Concern |
|--------|-----|-----|------|---------|
| F4_SC1 | 0.000 | 0.013 | 0.004 | OK |
| F4_SC2 | 0.000 | 0.120 | 0.040 | OK |
| F4_SC3 | 0.010 | 0.227 | 0.056 | OK |
| F4_SC4 | 0.000 | 0.000 | 0.000 | OK |
| F5_SC1 | 0.001 | 0.060 | 0.022 | OK |
| F5_SC2 | 0.009 | 0.540 | 0.197 | OK |
| **F5_SC3** | 0.068 | **1.080** | 0.287 | **CHECK** |
| F5_SC4 | 0.000 | 0.180 | 0.059 | OK |
| F5_SC5 | 0.000 | 0.024 | 0.005 | OK |

**ISSUE F-3: F5_SC3 Rate Exceeds 1 (High)**
- One record shows F5_SC3 = 1.08 fragments per year
- This means >1 fragment per individual per year, which is possible but should be verified
- **Recommendation:** Verify calculation; consider if this represents exceptional fragmentation event

### 3.5 Total Fragmentation Rates

| Source | Min | Max | Mean |
|--------|-----|-----|------|
| F4 (SC4 adults) | 0.01 | 0.36 | 0.10 |
| F5 (SC5 adults) | 0.10 | 1.83 | 0.57 |

---

## 4. Output Data Integrity

### 4.1 Transition Matrix (transition_matrix.csv)

**Matrix Dimensions:** 5 x 5

**Column Sums (should be <= 1):**

| Size Class | Column Sum | Status |
|------------|------------|--------|
| SC1_recruit | 0.693 | PASS |
| SC2_small_juv | 0.707 | PASS |
| SC3_large_juv | 0.773 | PASS |
| SC4_small_adult | 0.963 | PASS |
| **SC5_large_adult** | **1.491** | **FAIL** |

**ISSUE O-1: Transition Matrix Column Sum Exceeds 1 (Critical)**
- SC5_large_adult column sums to 1.491 (should be <= 1)
- This implies impossible transition probabilities (149% of individuals accounted for)
- May be due to fragmentation being added to survival/growth transitions
- **Recommendation:** Review matrix construction; ensure fragmentation is incorporated correctly without double-counting

**Value Range:**
- Minimum: 0 (OK)
- Maximum: 0.863 (OK)
- No negative values (OK)
- No values > 1 in individual cells (OK)

### 4.2 Elasticity Matrix (elasticity_matrix.csv)

**Matrix Dimensions:** 5 x 5

| Check | Value | Status |
|-------|-------|--------|
| Total sum | 1.000 | PASS |
| Min value | 0 | PASS |
| Max value | 0.548 | PASS |
| Negative values | None | PASS |

**Largest Elasticity:** SC5_large_adult to SC5_large_adult (stasis) = 0.548

**Status:** Elasticity matrix passes all validation checks

### 4.3 Diagnostic Metrics

**Survival Model Diagnostics:**

| Metric | Value | Status |
|--------|-------|--------|
| Deviance explained | 8.64% | OK |
| Mean residual | 0.159 | CHECK |
| High influence % | 6.81% | **HIGH** |
| Method agreement range | 1.15 | **HIGH** |

**ISSUE O-2: High Influence Points (Medium)**
- 6.8% of observations are high-influence points
- May disproportionately affect model results
- **Recommendation:** Perform sensitivity analysis excluding high-influence points

**Growth Model Diagnostics:**

| Metric | Value | Status |
|--------|-------|--------|
| R2 (absolute) | 1.1% | **LOW** |
| R2 (RGR) | 31.7% | OK |
| R2 (positive growth) | 3.2% | **LOW** |
| Heteroscedasticity ratio | 87.9 | **HIGH** |
| Outlier % | 10.2% | **HIGH** |

**ISSUE O-3: Low Explanatory Power for Growth (High)**
- Absolute growth R2 is only 1.1%
- Indicates size explains very little variance in growth
- High heteroscedasticity (ratio = 88) indicates variance increases with size
- **Recommendation:** Consider alternative model specifications; report uncertainty prominently

### 4.4 Meta-Analysis Results

| Statistic | Value |
|-----------|-------|
| Number of studies (k) | 5 |
| Total observations | 5,145 |
| Pooled survival (RE) | 0.769 |
| 95% CI | 0.569 - 0.894 |
| 95% PI | 0.124 - 0.987 |
| **I-squared** | **97.8%** |
| Cochran's Q | 376.6 (p < 0.001) |

**ISSUE O-4: Extreme Heterogeneity (Critical)**
- I-squared of 97.8% indicates almost all variance is between-study
- Prediction interval (0.12 - 0.99) spans nearly the entire possible range
- Pooled estimates may be misleading
- **Recommendation:** Prioritize stratified analyses; avoid presenting pooled estimates without heterogeneity context

---

## 5. Cross-Dataset Consistency

### 5.1 Coral ID Overlap

| Metric | Value |
|--------|-------|
| IDs in survival | 2,101 |
| IDs in growth | 1,662 |
| IDs in both | 1,523 (72.5% of survival) |
| IDs only in survival | 578 |
| IDs only in growth | 139 |

**Status:** Good overlap between datasets; 139 corals have growth but no survival data (expected for surviving individuals)

### 5.2 Study and Region Coverage

| Check | Result |
|-------|--------|
| Studies match | Yes (all 6 studies in both) |
| Regions match | Yes (all 7 regions in both) |
| Year range match | Yes (2004-2024 in both) |

### 5.3 Data Source Dominance

| Dataset | NOAA % | Other Studies % |
|---------|--------|-----------------|
| Survival | 77.6% | 22.4% |
| Growth | 80.2% | 19.8% |

**ISSUE C-1: NOAA Dominance (High)**
- NOAA survey contributes ~80% of all data
- Results may not generalize to other populations or monitoring contexts
- **Recommendation:** Perform leave-one-study-out sensitivity analysis; note NOAA dominance in results

---

## 6. Issue Summary and Prioritization

### Critical Issues (Require Immediate Attention)

| ID | Issue | Impact | Recommendation |
|----|-------|--------|----------------|
| O-1 | Transition matrix SC5 column sum > 1 | Invalid population projections | Review matrix construction |
| G-4 | Navassa growth outlier (826 cm2/yr) | Biased regional estimates | Investigate/exclude |
| O-4 | Extreme heterogeneity (I2 = 97.8%) | Misleading pooled estimates | Prioritize stratified analysis |
| F-1 | Limited fragmentation data (n=13) | High uncertainty in fecundity | Seek additional data |

### High Priority Issues

| ID | Issue | Impact | Recommendation |
|----|-------|--------|----------------|
| G-1 | Extreme negative growth (-119,365) | Outlier influence | Review/exclude extremes |
| G-2 | Extreme positive outliers (32,461) | Biased growth estimates | Implement outlier detection |
| S-1 | Missing size data (n=16) | Loss of observations | Investigate source |
| S-3 | Duplicate records (n=66) | Double-counting | Deduplicate |
| C-1 | NOAA dominance (80%) | Generalizability | Sensitivity analysis |
| O-3 | Low growth R2 (1.1%) | Poor predictions | Alternative models |

### Medium Priority Issues

| ID | Issue | Impact | Recommendation |
|----|-------|--------|----------------|
| S-2 | Perfect survival in one study | May skew estimates | Verify data |
| G-3 | Impossible growth flag incomplete | Missed outliers | Extend flagging logic |
| F-2 | Inconsistent time intervals | Rate accuracy | Verify annualization |
| F-3 | F5_SC3 rate > 1 | Unusual fragmentation | Verify calculation |
| O-2 | High influence points (6.8%) | Model sensitivity | Sensitivity analysis |

### Low Priority Issues

| ID | Issue | Impact | Recommendation |
|----|-------|--------|----------------|
| - | Missing treatment/disturbance data | Context loss | Expected for field data |
| - | Missing depth data (2.8%) | Minor | Low impact |

---

## 7. Recommendations

### Immediate Actions

1. **Fix Transition Matrix:** Review the matrix construction code to ensure SC5 column sums to <= 1. Check if fragmentation rates are being added incorrectly.

2. **Investigate Navassa Data:** The 826 cm2/yr mean growth is implausible. Review original data source, check for data entry errors or measurement issues.

3. **Implement Outlier Protocol:** Add flags for extreme positive growth (>99th percentile or >5,000 cm2/yr). Consider sensitivity analyses with and without outliers.

### Short-term Actions (1-2 weeks)

4. **Address Duplicates:** Review 66 duplicate survival records. Determine if these are true duplicates or legitimate multi-interval observations.

5. **Stratified Reporting:** Given I2 = 97.8%, prioritize study-stratified and region-stratified results over pooled estimates.

6. **Document Uncertainty:** Create uncertainty flags for estimates derived from limited data (especially fragmentation).

### Long-term Actions (1-3 months)

7. **Seek Fragmentation Data:** With only 13 records from one study, fragmentation parameters have high uncertainty. Literature review or collaborator outreach recommended.

8. **Alternative Growth Models:** Given low R2, explore non-linear models, size-varying variance structures, or Bayesian hierarchical approaches.

9. **Validation Study:** If possible, validate key estimates against independent datasets or expert opinion.

---

## 8. Data Quality Metrics Summary

| Dataset | Records | Quality Score | Major Issues |
|---------|---------|---------------|--------------|
| Survival (individual) | 5,213 | **B+** | Duplicates, missing size |
| Growth (individual) | 4,344 | **B-** | Extreme outliers, Navassa |
| Fragmentation | 13 | **C** | Sample size, single study |
| Transition Matrix | 5x5 | **D** | Column sum > 1 |
| Elasticity Matrix | 5x5 | **A** | No issues |

**Overall Data Quality Grade: B-**

The dataset is suitable for analysis with appropriate caveats and quality controls. The transition matrix issue must be resolved before population projections are valid. The extreme heterogeneity means users should focus on stratified estimates rather than pooled values.

---

*Report generated: January 21, 2026*
*Analysis performed using R with dplyr package*
