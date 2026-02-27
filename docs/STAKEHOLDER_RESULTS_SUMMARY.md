# Acropora palmata Demographic Database: Key Results Summary

**Prepared for Stakeholders | February 2026**

**Authors:** Detmer, R., Stier, A.C., et al.
**Institution:** Ocean Recoveries Lab, UC Santa Barbara

---

## Executive Summary

This database synthesizes survival and growth data for *Acropora palmata* (Elkhorn Coral) across the Caribbean. The key findings indicate:

- **Population declining ~1.4% annually** (λ = 0.986)
- **87.3% probability of continued decline** based on bootstrap analysis
- **Adult survival is the most critical parameter** for population recovery (54.8% elasticity)
- **Considerable heterogeneity across studies** (I² = 97.8%), driven primarily by differences between natural colonies and restoration fragments

---

## 1. Database Overview

| Metric | Value |
|--------|-------|
| **Total survival observations** | 5,196 |
| **Total growth observations** | 4,344 |
| **Number of studies (individual-level)** | 6 |
| **Geographic regions** | 6 (individual-level); 10 (expanded meta-analysis) |
| **Temporal coverage** | 2004–2024 |
| **Primary data source** | NOAA NCRMP (78% of data) |

### Geographic Coverage

| Region | n (Survival) | Studies | Sites | Years | Mean Survival |
|--------|-------------|---------|-------|-------|---------------|
| Florida Keys | 4,072 | 3 | 16 | 2004–2024 | 79.3% |
| Curaçao | 856 | 1 | 4 | 2007–2015 | 84.6% |
| Navassa | 102 | 1 | 2 | 2009–2012 | 92.2% |
| Mexican Caribbean | 52 | 1 | 3 | 2016–2021 | 100% |
| USVI | 46 | 1 | 3 | 2020–2021 | 65.2% |
| Dominican Republic | 44 | 1 | 1 | 2021 | 86.4% |
| Dry Tortugas | 24 | 1 | 2 | 2019 | 100% |

---

## 2. Survival by Size Class

Size classes are based on **live tissue area** (cm²), which is the biologically meaningful measure.

| Size Class | Live Tissue (cm²) | n | Annual Survival | 95% CI |
|------------|-------------------|---|-----------------|--------|
| **SC1** (Recruits) | 0–25 | 366 | **72.4%** | — |
| **SC2** (Small Juveniles) | 25–100 | 1,342 | **64.4%** | — |
| **SC3** (Large Juveniles) | 100–500 | 920 | **76.8%** | — |
| **SC4** (Small Adults) | 500–2,000 | 837 | **87.6%** | — |
| **SC5** (Large Adults) | >2,000 | 1,731 | **93.7%** | — |

### Key Finding: Size-Survival Relationship
- Survival increases with size
- Threshold detected at ~44 cm² (high uncertainty: 95% CI spans 10–33,100 cm²)
- Size explains only **5.8% of variance** in survival (GAM R² = 0.058; McFadden R² = 8.6% from GLM)
- Other factors (region, year, disturbance) contribute substantially

---

## 3. Growth Rates by Size Class

*Note: 300 records (6.9%) with biologically impossible growth values were excluded—these showed tissue losses exceeding the colony's initial size, indicating measurement or data entry errors in the NOAA survey data.*

| Size Class | n | Mean Growth (cm²/yr) | Median (cm²/yr) | % Positive | % Shrinking |
|------------|---|---------------------|-----------------|------------|-------------|
| SC1 (Recruits) | 299 | **+53.3** | +32.6 | 88.6% | 7.4% |
| SC2 (Small Juv) | 890 | **+61.1** | +45.6 | 86.3% | 11.7% |
| SC3 (Large Juv) | 641 | **+91.2** | +57.6 | 68.3% | 27.3% |
| SC4 (Small Adult) | 661 | **+306.0** | +234.1 | 69.9% | 24.2% |
| SC5 (Large Adult) | 1,553 | **+356.0** | +815.2 | 71.0% | 27.6% |

### Key Finding: Growth Patterns
- **All size classes show positive mean growth** after data quality filtering
- **Absolute growth increases with size**: larger colonies add more tissue area per year
- **Relative Growth Rate (RGR) decreases with size**: SC1 = 2.6 yr⁻¹, SC5 = 0.09 yr⁻¹ (expected biological pattern)
- **~25-30% of adults experience shrinkage** annually (partial mortality)
- **75% of all corals show positive growth** overall

---

## 3b. Growth Rate Analysis: Absolute vs. Relative Growth

### Why Relative Growth Rate (RGR) Matters

| Metric | R² (Variance Explained) | Interpretation |
|--------|------------------------|----------------|
| **Absolute Growth Rate (AGR)** | 1.5% | Size explains almost nothing |
| **Relative Growth Rate (RGR)** | **33.9%** | Size explains ~34% of variance |

**RGR is 22× more predictive than AGR for understanding size-growth relationships.**

### RGR by Size Class

| Size Class | Mean RGR (yr⁻¹) | Median RGR | Interpretation |
|------------|-----------------|------------|----------------|
| SC1 (Recruits) | 2.58 | 1.94 | Can more than double size annually |
| SC2 (Small Juv) | 1.15 | 0.93 | ~100% size increase per year |
| SC3 (Large Juv) | 0.46 | 0.32 | ~30-45% size increase per year |
| SC4 (Small Adult) | 0.30 | 0.23 | ~25-30% size increase per year |
| SC5 (Large Adult) | 0.09 | 0.12 | ~10% size increase per year |

### Heteroscedasticity Analysis

- **AGR variance scales with size^1.4** — larger colonies have much higher variance in absolute growth
- **RGR variance scales with size^−0.6** — more homogeneous variance across sizes
- **Implication**: RGR is more suitable for statistical modeling

### Size Threshold for Growth

| Metric | Threshold | Interpretation |
|--------|-----------|----------------|
| **RGR** | ~36 cm² | Where relative growth rate changes most rapidly |
| AGR | ~6,534 cm² | Less meaningful due to low R² |
| P(Positive Growth) | ~435 cm² | Where probability of positive growth stabilizes |

### Allometry Analysis: Initial vs Final Size

**Overall Allometric Relationship:**
- log(Final Size) = 1.084 + 0.865 × log(Initial Size)
- R² = 82.1% (strong predictive relationship)
- Slope = 0.865 → **Negative allometry** (small colonies grow proportionally faster)

**⚠️ CRITICAL: Size Range Confound**

| Study | Size Range (cm²) | n | Notes |
|-------|-----------------|---|-------|
| Kuffner et al. | 8–38 | 43 | Smallest fragments |
| Fundemar | 7–54 | 172 | Small fragments |
| Pausch et al. | 5–231 | 557 | Fragment study |
| USGS USVI | 14–207 | 30 | Small sample |
| Mendoza-Quiroz | 3–1,672 | 52 | Wide range |
| NOAA Survey | 1–85,120 | 3,148 | Large natural colonies |

**Common size range across ALL studies: 13.5–38.5 cm² (only 11.4% of data)**

Different slopes across studies may reflect **different portions of a single underlying allometric curve**, NOT truly different biology. ANCOVA results must be interpreted with caution.

**Allometric Slopes by Study (Full Data):**

| Study | n | Slope | 95% CI | Size Range |
|-------|---|-------|--------|------------|
| NOAA Survey | 3,148 | 0.918 | 0.901–0.935 | 1–85,120 cm² |
| USGS USVI | 30 | 0.794 | 0.684–0.905 | 14–207 cm² |
| Mendoza-Quiroz | 52 | 0.651 | 0.525–0.777 | 3–1,672 cm² |
| Pausch et al. | 557 | 0.500 | 0.411–0.590 | 5–231 cm² |
| Fundemar | 172 | 0.249 | 0.091–0.407 | 7–54 cm² |

**Restricted Analysis (25–500 cm² only, n=1,522):**
- ANCOVA still significant (p < 0.001) → **TRUE allometric differences exist**
- When comparing only comparable sizes, NOAA slope = 0.87, Pausch slope = 0.52

**Natural vs Restored Allometry:**
- Natural Colonies: Slope = 0.911 (size range: 1–85,120 cm²)
- Restoration Fragments: Slope = 0.751 (size range: 5–47,970 cm²)
- **Restricted ANCOVA (overlapping sizes): p < 0.0001**
- **Key Finding**: TRUE difference persists even when comparing comparable sizes

### Allometric Assumptions (Important Caveat)

Size is measured as **2D planar area** (Length × Width × % Live), following Vardi et al. 2012.

**For *A. palmata* (branching coral):**
- Small colonies (<100 cm²): Plate-like, 2D is reasonable proxy
- Large colonies (>1000 cm²): Complex 3D branching, 2D underestimates tissue area

**Impact on growth metrics:**
- AGR underestimates true tissue gain for large colonies
- RGR partially corrects because both numerator and denominator use same measurement

**Recommendation**: Use RGR for size-growth comparisons; interpret absolute growth with caution across size classes.

### Natural vs. Restored Population Growth

| Population Type | n | Mean RGR | Median RGR | % Positive |
|-----------------|---|----------|------------|------------|
| Natural Colonies | 3,111 | 0.31 yr⁻¹ | 0.17 yr⁻¹ | 70.7% |
| Restoration Fragments | 891 | 1.59 yr⁻¹ | 1.19 yr⁻¹ | 91.6% |

**Key Finding**: Restoration fragments have significantly higher RGR (Wilcoxon p < 0.0001), but this is expected because fragments are smaller and smaller corals have higher RGR.

### Advanced Analyses to Address Size Range Confound

Given that different studies sample different size ranges, we employed multiple analytical approaches to determine whether allometric differences are real or artifacts:

**1. Mixed-Effects Model (Study as Random Effect)**
- Fixed effect slope = 0.866 (accounting for study-level variation)
- Intraclass correlation (ICC) shows substantial between-study variance
- Random slopes significantly improve fit → allometry DOES differ by study

**2. Piecewise/Segmented Regression**
- GAM outperforms linear model by 44 AIC units → substantial nonlinearity detected
- Relationship is NOT simply log-linear across all sizes

**3. Within-Size-Class ANCOVA**
- 0/3 size classes with sufficient data show significant slope differences within class
- When comparing ONLY within comparable size ranges, study differences diminish
- → Suggests apparent slope differences are partly driven by size range confound

**4. Bootstrap Confidence Intervals**
- NOAA slope = 0.918 vs Fragment slope = 0.617
- Difference = 0.301, 95% CI: [0.230, 0.373]
- ⚠️ BUT: This comparison is still confounded by non-overlapping size ranges

**5. Size-Matched Comparisons (Nearest Neighbor Matching)**
- Created 480 size-matched pairs between Natural and Restored populations
- Matched-pair ANCOVA: p < 0.0001 → slopes DIFFER even at equivalent sizes!
- Natural slope = 0.941 vs Restored slope = 0.776 in matched data
- **Key Finding: TRUE biological differences persist after size matching**
- Paired t-test: Restored fragments have systematically higher final size controlling for initial size

**Summary of Advanced Analyses:**
| Method | Result | Interpretation |
|--------|--------|----------------|
| Within-size-class ANCOVA | p > 0.05 in all classes | No difference within comparable sizes |
| Size-matched pairs ANCOVA | p < 0.0001 | TRUE slope differences exist |
| Paired t-test on residuals | p < 0.0001 | Restored have higher final size at same initial size |

**Conclusion:** While apparent slope differences between studies are partly confounded by size range, size-matched analyses confirm TRUE biological differences between natural colonies and restoration fragments. Fragments show shallower allometry (slope = 0.78 vs 0.94) but achieve greater final size relative to initial size than natural colonies.

---

## 4. Population Projection Matrix Results

### Lambda (Population Growth Rate)

| Parameter | Value | 95% CI |
|-----------|-------|--------|
| **λ (lambda)** | **0.986** | 0.819–1.020 |
| Annual decline rate | −1.4% | — |
| **P(decline)** | **87.3%** | — |

**Interpretation:** The population is declining at approximately 1.4% per year, with 87.3% of bootstrap replicates showing λ < 1, indicating evidence of population decline under current conditions.

### Elasticity Analysis (Sensitivity of λ)

| Vital Rate | Elasticity | Interpretation |
|------------|------------|----------------|
| **SC5 stasis (adult survival)** | **54.8%** | Most critical parameter |
| SC4 stasis (small adult survival) | 11.6% | Second priority |
| Growth transitions | 14.7% | Important but secondary |
| Retrogression | 7.7% | Partial mortality transitions |
| Other (SC1-3 stasis + reproduction) | 8.4% | Minor contributions |

**Key Implication:** Protecting large adult colonies (SC5) is the most effective conservation strategy. A 1% improvement in SC5 survival has 4× more impact on λ than equivalent improvements to other parameters.

### Size Class Transition Matrix (Annual Probabilities)

|From → To | SC1 | SC2 | SC3 | SC4 | SC5 |
|----------|-----|-----|-----|-----|-----|
| **SC1** | 41.4% | 19.1% | 12.5% | 11.0% | 6.0% |
| **SC2** | 26.8% | 33.6% | 4.6% | 4.8% | 21.3% |
| **SC3** | 2.3% | 23.6% | 49.5% | 10.9% | 32.6% |
| **SC4** | 1.8% | 0.5% | 14.7% | 57.6% | 9.7% |
| **SC5** | 0% | 0.5% | 0% | 15.1% | 87.2% |

---

## 5. Meta-Analysis Results

### Individual-Level Meta-Analysis (k=5)

| Statistic | Value | Interpretation |
|-----------|-------|----------------|
| **I²** | **97.8%** | Considerable heterogeneity |
| τ² (between-study variance) | 0.515 | — |
| Cochran's Q | 407.43 (p < 0.0001) | Significant |
| **Pooled survival (RE)** | **76.9%** | 95% CI: 56.9–89.4% |
| Prediction interval | 36.3–96.1% | Wide range expected |

### Expanded Meta-Analysis (k=16)

| Statistic | Value | Interpretation |
|-----------|-------|----------------|
| **k (studies)** | **16** | 6 individual-level + 10 summary-level |
| **N (observations)** | **9,208** | — |
| **Pooled survival (RE)** | **81.1%** | 95% CI: 73.2–87.1% |
| **I²** | **97.9%** | Extreme heterogeneity persists |
| CI width | 13.9 pp | Narrowed 58% vs k=5 (32.5 pp) |

### Stratified Results: Natural vs. Restoration (Expanded k=16)

| Population Type | k | Pooled Survival | 95% CI |
|-----------------|---|-----------------|--------|
| **Natural colonies** | 6 | **85.1%** | 70.3–93.2% |
| **Restoration fragments** | 10 | **78.3%** | 66.4–86.8% |

**Key Finding:** The 6.8 percentage point difference between natural colonies and restoration fragments is NOT statistically significant (p = 0.30). Within-restoration heterogeneity (31 pp) exceeds the between-type difference. The expanded meta-analysis includes k=6 natural colony studies (up from k=1), breaking the previous NOAA-only confound.

### Publication Bias Assessment
- Egger's test: p = 0.76 (no significant asymmetry detected)
- No evidence of publication bias

---

## 6. Natural Colonies vs. Restoration Fragments

### Survival Comparison by Size Class

| Size Class | Natural Colonies | Restoration Fragments | Difference |
|------------|-----------------|----------------------|------------|
| SC1 | 1.7% (n=16,479*) | 100% (n=221) | +98.3 pp |
| SC2 | 62.5% (n=158) | 68.1% (n=750) | +5.6 pp |
| SC3 | 75.1% (n=417) | 55.6% (n=1,030) | −19.5 pp |
| SC4 | 86.5% (n=240) | 91.4% (n=71) | +4.9 pp |
| SC5 | 91.8% (n=209) | — | — |

*SC1 natural colonies include settlers with high mortality.

**Key Finding:** Size-matched comparisons needed. The SC3 size class shows fragments underperforming natural colonies by ~20 percentage points.

---

## 7. Data Gaps & Research Priorities

### Priority Rankings for Future Data Collection

| Priority | Data Gap | Impact | Feasibility | Current n |
|----------|----------|--------|-------------|-----------|
| **1** | Climate event survival data | Very High | Medium | — |
| **2** | Field data for SC1 recruits | High | High | — |
| **2** | Nursery-to-field transition survival | High | High | — |
| **4** | Long-term monitoring (>5 yr) | Very High | Low | — |
| **5** | Density-dependent growth data | High | Medium | — |
| **6** | Large adult survival (SC5) all regions | Very High | Low | 2,230 |
| **7** | Bahamas/Jamaica regional coverage | Medium | Medium | 0 |
| **8** | Pre-2010 historical data | Medium | Very Low | 1,110 |

---

## 8. Key Takeaways for Management

### For Restoration Practitioners

1. **Fragment survival appears lower than natural colonies** (~78% vs ~85% in expanded meta-analysis, but the 6.8 pp difference is NOT statistically significant, p = 0.30). This comparison is confounded with study identity — within-restoration heterogeneity (31 pp) exceeds the between-type difference
2. **Target outplant sizes >100 cm² live tissue** when possible
3. **Monitor first-year survival closely**—most mortality occurs early
4. **Site selection matters**—regional variation is substantial

### For Conservation Managers

1. **Protect large adults (SC5)**—they have highest elasticity for population growth
2. **λ = 0.986 means ~1.4% annual decline** under current conditions
3. **87.3% probability of continued decline** without intervention
4. **Florida Keys have most data** but other regions need monitoring

### For Researchers

1. **Use `size_live_cm2` for analyses**—not total colony size
2. **Stratify by fragment status**—natural vs. restored populations differ
3. **Account for heterogeneity**—I² = 97.8% across studies
4. **Climate event data is the #1 priority gap**
5. **Filter impossible growth values**—6.9% of NOAA records show tissue losses exceeding colony size

---

## 9. Citation

If you use these data, please cite:

> Detmer, R., Stier, A.C., et al. (2025). Caribbean Coral Demographic Database: Survival and growth data for *Acropora palmata*. Ocean Recoveries Lab, University of California Santa Barbara. DOI: 10.xxxx/xxxxx

---

## 10. Contact

For questions about this database:
- **Email:** [contact info]
- **GitHub:** https://github.com/stier-lab/Detmer-2025-coral-parameters

---

*Document generated: February 2026*
*Data version: 2026-02 (with live tissue area, growth data corrections, and updated population model)*
