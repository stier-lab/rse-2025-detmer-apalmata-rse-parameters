# Comprehensive Analysis Plan: *Acropora palmata* Demographic Parameters

## Size × Space × Time: What We Know, What We Don't, and Where to Go Next

**Lead Researcher**: Raine Detmer
**PI**: Adrian Stier
**Date**: December 2025 (original) | **Status Updated**: February 2026

> **STATUS: ANALYSIS COMPLETE.** All 23 scripts in the pipeline have been implemented and run. Results are in `analysis/output/` (107+ files). The manuscript figure plan is in `docs/MANUSCRIPT_FIGURE_PLAN.md`. The web platform is deployed on Render. This document is preserved as the original planning document for reference — actual results may differ from preliminary estimates below. See `docs/ANALYSIS_SUMMARY.md` for definitive results. **The manuscript has been reframed from a demographic parameters database to a population viability assessment (March 2026).**

---

## Executive Summary

This paper synthesizes 25,000+ demographic observations for *Acropora palmata* (Elkhorn Coral) to answer:

1. **What do we know?** How do survival and growth vary as functions of size, across space (regions), and through time?
2. **Where are the thresholds?** At what size do we see significant improvements in demographic rates? How certain are we?
3. **What don't we know?** Where are the critical data gaps that limit our understanding?
4. **What's next?** What experiments and monitoring would most effectively fill these gaps?

---

# PART I: THE DATA LANDSCAPE

## 1.1 Dataset Overview

| Metric | Individual Data | Summarized Data | Total |
|--------|----------------|-----------------|-------|
| **Survival observations** | 5,213 | ~20,000+ (from 320 records) | ~25,000 |
| **Growth observations** | 4,344 | ~500 (from 15 records) | ~5,000 |
| **Studies** | 6 | 12 additional | 18 |
| **Regions** | 7 | 5 additional | 12 |
| **Year span** | 2004-2024 | 1997-2024 | 27 years |

## 1.2 Geographic Coverage

| Region | Survival N | Growth N | Years | Studies | Data Quality |
|--------|-----------|----------|-------|---------|--------------|
| Florida Keys | 4,076 | ~3,500 | 2004-2024 | 4 | ★★★★★ Individual + long-term |
| Curacao | 868 | ~700 | 2007-2015 | 2 | ★★★★☆ Individual tracking |
| Dominican Republic | 14,316 | 45 | 2021 | 2 | ★★★☆☆ Large N, short duration |
| Puerto Rico | 1,452 | - | 1997-2008 | 3 | ★★★☆☆ Summarized data |
| British Virgin Islands | 1,198 | - | 2006-2007 | 1 | ★★☆☆☆ Single study |
| Mexican Caribbean | 1,600 | 52 | 2016-2021 | 2 | ★★★☆☆ Lab + field |
| USVI | 346 | 46 | 2002-2021 | 3 | ★★☆☆☆ Fragmented |
| Jamaica | 515 | - | 2005-2008 | 1 | ★★☆☆☆ Summarized |
| Navassa | 102 | - | 2009-2012 | 1 | ★★☆☆☆ Remote site |
| Bahamas | 112 | ~50 | 2019-2022 | 2 | ★★☆☆☆ Nursery focus |
| Dry Tortugas | 24 | - | 2019 | 1 | ★☆☆☆☆ Single year |

## 1.3 Size Distribution in Data

```
Size Class Distribution (Survival, N=5,213 individual records):

SC1 (0-10 cm²)      ████████████████████████████████████  ~25%  n≈1,303
SC2 (10-100 cm²)    ██████████████████████████████        ~22%  n≈1,147
SC3 (100-900 cm²)   ████████████████████████              ~18%  n≈938
SC4 (900-4000 cm²)  ██████████████████████████████        ~20%  n≈1,043
SC5 (>4000 cm²)     ██████████████████████                ~15%  n≈782

Median size: 1,050 cm² (SC3-SC4 boundary)
Range: 1 - 118,500 cm²
```

## 1.4 Temporal Coverage

```
Year  2004  2006  2008  2010  2012  2014  2016  2018  2020  2022  2024
      |     |     |     |     |     |     |     |     |     |     |
FL    ████████████████████████████████████████████████████████████
CUR         ██████████████████████
NAV               ████████
DR                                                  ██
MEX                                       ████████████
USVI                                              ██████
BVI         ████
PR    ██████████████
JAM       ██████
BAH                                             ████████

Observations by year:
2004-2008:  836  (early NOAA monitoring)
2009-2013:  1,658 (peak monitoring effort)
2014-2018:  1,412 (continued monitoring)
2019-2024:  1,307 (recent data + expansion)
```

---

# PART II: WHAT WE KNOW — SIZE, SPACE, TIME

## 2.1 SIZE: Demographic Thresholds

### 2.1.1 The Central Question: Size-Survival Relationship

**Hypothesis**: Larger colonies have higher survival, but is this relationship:
- Linear (on log scale)?
- Does it plateau at large sizes?
- Are there discrete "escape sizes" with rapid improvement?

### 2.1.2 Threshold Detection Analysis

**Methods**:

```r
# 1. Test for non-linearity with polynomial terms
glm(survived ~ poly(log(size_cm2), 2), family = binomial, data = surv)
# Compare AIC to linear model

# 2. Segmented regression to detect breakpoints
library(segmented)
fit_linear <- glm(survived ~ log(size_cm2), family = binomial, data = surv)
fit_seg <- segmented(fit_linear, seg.Z = ~log(size_cm2), npsi = 1)
# Estimate breakpoint and confidence interval

# 3. Changepoint analysis
library(mcp)
model <- list(
  survived | trials(1) ~ 1 + log(size_cm2),  # Before threshold
  ~ 0 + log(size_cm2)  # After threshold (different slope)
)
fit_mcp <- mcp(model, data = surv, family = binomial())

# 4. Generalized Additive Model for smooth threshold
library(mgcv)
gam(survived ~ s(log(size_cm2)), family = binomial, data = surv)
```

### 2.1.3 Expected Survival Thresholds

Based on preliminary analysis of Raine's work and literature:

| Threshold | Size | Biological Significance | Certainty |
|-----------|------|------------------------|-----------|
| **Recruit escape** | ~10 cm² | Escape from many predators, algal overgrowth | ★★★★☆ High (N>1,000) |
| **Juvenile escape** | ~100 cm² | Resist partial mortality from sedimentation | ★★★☆☆ Moderate |
| **Sub-adult transition** | ~500-900 cm² | Beginning of reproductive capacity? | ★★☆☆☆ Low (limited fecundity data) |
| **Adult plateau** | ~3,000-4,000 cm² | Survival may plateau; growth continues | ★★☆☆☆ Low (N<800 in SC5) |

### 2.1.4 Size-Survival Rate Estimates (Preliminary)

| Size Class | Expected Survival | 90% CI | N | Certainty |
|------------|------------------|--------|---|-----------|
| SC1 (0-10 cm²) | ~50% | 45-55% | ~1,300 | ★★★★☆ |
| SC2 (10-100 cm²) | ~65% | 60-70% | ~1,100 | ★★★★☆ |
| SC3 (100-900 cm²) | ~75% | 70-80% | ~950 | ★★★☆☆ |
| SC4 (900-4000 cm²) | ~82% | 77-87% | ~1,000 | ★★★☆☆ |
| SC5 (>4000 cm²) | ~85% | 78-92% | ~800 | ★★☆☆☆ |

**Key Question**: Does survival actually plateau at SC5, or do we just have insufficient data?

### 2.1.5 Growth Thresholds

| Size Class | Mean Growth (cm²/yr) | % Negative Growth | Certainty |
|------------|---------------------|-------------------|-----------|
| SC1 | +15 to +50 | ~35% | ★★★☆☆ |
| SC2 | +50 to +150 | ~30% | ★★★☆☆ |
| SC3 | +100 to +400 | ~25% | ★★★☆☆ |
| SC4 | +200 to +800 | ~25% | ★★☆☆☆ |
| SC5 | +300 to +1500 | ~22% | ★★☆☆☆ |

**Critical Finding**: 27.4% of all growth observations are negative (partial mortality or fragmentation).

---

## 2.2 SPACE: Geographic Variation

### 2.2.1 Regional Survival Analysis

**Model**:
```r
glmer(survived ~ log(size_cm2) + region + (1|study/site),
      family = binomial, data = surv_all)
```

**Expected Results** (to be confirmed):

| Region | Relative Survival | Sample Size | Certainty |
|--------|------------------|-------------|-----------|
| Florida Keys | Reference | 4,076 | ★★★★★ |
| Curacao | +5-10%? | 868 | ★★★★☆ |
| Dominican Republic | Unknown | ~14,000 (summ) | ★★☆☆☆ |
| Puerto Rico | -5-10%? | ~1,400 (summ) | ★★☆☆☆ |
| USVI | Unknown | ~350 | ★★☆☆☆ |

### 2.2.2 Latitude Effects

**Hypothesis**: Survival may decrease at range edges (thermal stress in south, cold in north)

**Data Gap**: Most data is from 18-27°N; southern Caribbean (10-15°N) has limited representation.

### 2.2.3 Depth Effects

Available depth data: 0.5-15m, but most observations at 2-5m.

**Analysis**:
```r
glmer(survived ~ log(size_cm2) + depth_m + (1|study/site),
      family = binomial, data = surv_with_depth)
```

**Certainty**: ★★☆☆☆ — Depth confounded with site selection bias

---

## 2.3 TIME: Temporal Variation

### 2.3.1 Interannual Variation

**Model**:
```r
# Year as random effect
glmer(survived ~ log(size_cm2) + (1|year) + (1|study/site),
      family = binomial, data = surv_all)

# Extract variance components
year_var <- VarCorr(model)$year[1]
site_var <- VarCorr(model)$site[1]
# Compare: Is year-to-year variation larger than site-to-site?
```

### 2.3.2 Disturbance Effects

**Disturbances Flagged in Data**: 571 observations (11%)

| Event | Year | Region | Effect on Survival |
|-------|------|--------|-------------------|
| Hurricane | 2004 | Florida Keys | To be quantified |
| Hurricane | 2005 | Florida Keys | To be quantified |
| Storm | 2008 | Curacao | To be quantified |

**Analysis**:
```r
# Direct effect
glmer(survived ~ log(size_cm2) * disturbance + (1|study/site),
      family = binomial, data = surv_all)

# Size-specific disturbance effects
# Do large colonies resist storms better?
```

### 2.3.3 Long-term Trends

**Question**: Is there a secular trend in survival over 2004-2024?

**Confound**: Changing study composition over time

**Certainty**: ★★☆☆☆ — Trend analysis complicated by unbalanced design

---

## 2.4 CONTEXT: Field vs. Nursery vs. Lab

### 2.4.1 Data Distribution by Context

| Context | Survival N | Growth N | Size Range | Duration |
|---------|-----------|----------|------------|----------|
| Field | 5,151 | ~4,000 | Full (1-118,500 cm²) | 1-20 yr |
| Nursery | 174 | ~50 | SC1-SC2 mostly | 6 mo-2 yr |
| Lab | ~2,100 | ~100 | SC1-SC2 | < 1 yr |

### 2.4.2 Key Comparisons

1. **Nursery → Field Transition**: Do nursery-raised corals survive as well post-outplant?
   - **Critical Gap**: Limited post-outplant tracking data

2. **Lab to Field Extrapolation**: Can lab experiments predict field performance?
   - **Certainty**: ★☆☆☆☆ — Different stressors, artificial conditions

---

# PART III: CERTAINTY AND UNCERTAINTY

## 3.1 Certainty Framework

For each demographic parameter, we assess:

| Criterion | Definition | Score |
|-----------|-----------|-------|
| Sample size | N > 1000 = High, 100-1000 = Moderate, <100 = Low | 1-3 |
| Geographic breadth | >5 regions = High, 2-5 = Moderate, 1 = Low | 1-3 |
| Temporal breadth | >5 years = High, 2-5 = Moderate, 1 = Low | 1-3 |
| Study independence | >3 studies = High, 2-3 = Moderate, 1 = Low | 1-3 |
| Data type | Individual = High, Summarized = Moderate, Estimated = Low | 1-3 |

**Total Certainty Score**: Sum / 15 × 5 stars

## 3.2 Parameter Certainty Matrix

| Parameter | N | Regions | Years | Studies | Data Type | Certainty |
|-----------|---|---------|-------|---------|-----------|-----------|
| SC1 survival | 1,300+ | 5+ | 10+ | 5+ | Individual | ★★★★☆ |
| SC2 survival | 1,100+ | 5+ | 10+ | 5+ | Individual | ★★★★☆ |
| SC3 survival | 950 | 4 | 10+ | 4 | Individual | ★★★☆☆ |
| SC4 survival | 1,000 | 4 | 10+ | 4 | Individual | ★★★☆☆ |
| SC5 survival | 800 | 3 | 10+ | 3 | Individual | ★★☆☆☆ |
| SC1 growth | 1,000+ | 4 | 10+ | 4 | Individual | ★★★☆☆ |
| SC5 growth | 500 | 3 | 8 | 3 | Individual | ★★☆☆☆ |
| Regional differences | Varies | Limited | Varies | Limited | Mixed | ★★☆☆☆ |
| Disturbance effects | 571 | 2 | 3 | 2 | Individual | ★★☆☆☆ |
| Temporal trends | 5,200 | 7 | 20 | 6 | Individual | ★★★☆☆ |
| Nursery performance | 174 | 3 | 4 | 3 | Individual | ★★☆☆☆ |
| Transition probabilities | 4,344 | 4 | 15 | 4 | Individual | ★★★☆☆ |

## 3.3 Sources of Uncertainty

### 3.3.1 Statistical Uncertainty (Quantifiable)

- **Sampling error**: Addressed via bootstrapping/resampling
- **Model uncertainty**: Compare GLM vs GLMM vs GAM
- **Heterogeneity**: Random effects capture study/site variation

### 3.3.2 Structural Uncertainty (Harder to Quantify)

| Source | Impact | Mitigation |
|--------|--------|-----------|
| Non-annual intervals | Moderate | Convert to annual rates |
| Size measurement error | Low-Moderate | Affects small sizes more |
| Survival definition varies | Moderate | Standardize "dead" criteria |
| Missing dead colonies | High | Potential survival overestimation |
| Genotype confounds | Unknown | No genotype data available |

### 3.3.3 Extrapolation Uncertainty

| Extrapolation | Risk Level | Reason |
|---------------|-----------|--------|
| SC5 to larger sizes | High | Limited data above 10,000 cm² |
| Florida to other regions | Moderate | Florida dominates dataset |
| Field to nursery predictions | High | Different stressor regimes |
| 2004-2024 to future | High | Climate change effects unknown |

---

# PART IV: WHAT WE DON'T KNOW — CRITICAL DATA GAPS

## 4.1 Gap Prioritization Framework

| Criterion | Weight | Description |
|-----------|--------|-------------|
| **Impact** | 40% | How much would filling this gap improve predictions? |
| **Feasibility** | 30% | How difficult/expensive is it to collect this data? |
| **Urgency** | 30% | How time-sensitive is this gap (restoration needs, climate)? |

## 4.2 SIZE-Related Gaps

| Gap | Impact | Feasibility | Urgency | Priority Score |
|-----|--------|-------------|---------|----------------|
| **Large adult (SC5) survival** | 5 | 3 | 4 | **4.1** |
| **SC5 growth and reproduction** | 5 | 3 | 4 | **4.1** |
| **Size threshold precision** | 4 | 4 | 3 | **3.7** |
| **Fragment vs intact dynamics** | 3 | 4 | 4 | **3.6** |
| **Recruit survival mechanisms** | 4 | 3 | 3 | **3.4** |

### Recommended Experiment 1: Large Colony Tracking

**Objective**: Improve SC5 survival and growth estimates

**Design**:
- Select 200+ colonies >4,000 cm² across 5+ sites
- Stratify by region (FL, Caribbean, Mexico)
- Annual measurements for 5 years
- Record: size (L×W×H), % live tissue, condition, growth form

**Expected Outcome**: Reduce SC5 survival CI from ±14% to ±5%

### Recommended Experiment 2: Size Threshold Study

**Objective**: Identify discrete "escape sizes" with improved survival

**Design**:
- Track 100 colonies in each 10-cm² bin from 0-200 cm²
- Monthly survival checks for 2 years
- Record mortality causes

**Expected Outcome**: Identify threshold(s) where survival jumps significantly

## 4.3 SPACE-Related Gaps

| Gap | Impact | Feasibility | Urgency | Priority Score |
|-----|--------|-------------|---------|----------------|
| **Eastern Caribbean (Jamaica, Hispaniola, PR)** | 4 | 3 | 4 | **3.7** |
| **Central America (Belize, Honduras)** | 4 | 2 | 3 | **3.0** |
| **Southern Caribbean (Venezuela, Colombia)** | 3 | 2 | 2 | **2.4** |
| **Within-region microhabitat effects** | 3 | 4 | 3 | **3.3** |
| **Depth gradient (>5m)** | 3 | 4 | 3 | **3.3** |

### Recommended Study 3: Pan-Caribbean Standardized Survey

**Objective**: Enable robust regional comparisons

**Design**:
- 10 sites across Caribbean (2 per major region)
- Same protocol: 100 tagged colonies per site, stratified by size
- Annual measurements for 3+ years
- Regions: FL, Eastern Caribbean, Central America, Southern Caribbean

**Expected Outcome**: Quantify regional survival differences with ★★★★☆ certainty

## 4.4 TIME-Related Gaps

| Gap | Impact | Feasibility | Urgency | Priority Score |
|-----|--------|-------------|---------|----------------|
| **Post-disturbance recovery trajectories** | 5 | 3 | 5 | **4.4** |
| **Climate-demography integration** | 5 | 4 | 5 | **4.7** |
| **Disease-specific mortality** | 5 | 3 | 5 | **4.4** |
| **Seasonal survival patterns** | 3 | 3 | 2 | **2.7** |
| **Multi-decadal trends** | 4 | 2 | 3 | **3.0** |

### Recommended Study 4: Climate-Demography Integration

**Objective**: Link demographic rates to thermal stress metrics

**Design**:
- Overlay demographic data with:
  - Degree Heating Weeks (NOAA Coral Reef Watch)
  - Bleaching Alert Area data
  - SST anomalies
- Build predictive models: survival ~ f(size, DHW, region)
- Project under RCP 4.5 and 8.5 scenarios

**Expected Outcome**: Predict survival under future climate scenarios

### Recommended Study 5: Disease Monitoring Integration

**Objective**: Attribute mortality to specific causes

**Design**:
- Add disease assessment to all demographic surveys
- Categories: healthy, bleaching (mild/severe), SCTLD, white band, predation, unknown
- Quarterly surveys to catch disease progression
- Tissue sampling for pathogen identification

**Expected Outcome**: Separate disease-driven mortality from other sources

## 4.5 MECHANISM-Related Gaps

| Gap | Impact | Feasibility | Urgency | Priority Score |
|-----|--------|-------------|---------|----------------|
| **Mortality cause attribution** | 5 | 3 | 5 | **4.4** |
| **Density dependence** | 4 | 4 | 3 | **3.7** |
| **Genotype × environment** | 4 | 2 | 3 | **3.0** |
| **Partial mortality processes** | 4 | 4 | 3 | **3.7** |
| **Competition effects (algae, other corals)** | 3 | 4 | 3 | **3.3** |

### Recommended Experiment 6: Density Manipulation

**Objective**: Test for density-dependent survival

**Design**:
- Establish 30 plots across 3 sites
- Treatments: Low (1 colony/m²), Medium (5/m²), High (10/m²) A. palmata density
- Monitor survival for 2+ years
- Include algal cover as covariate

**Expected Outcome**: Quantify whether local density affects survival/growth

## 4.6 Gap Summary: What Data Would Most Improve Predictions?

### Priority 1 (Highest Impact)
1. **Climate-demography integration** — Enables future projections
2. **Post-disturbance trajectories** — Critical for restoration timing
3. **Disease-specific mortality** — Major mortality source poorly quantified

### Priority 2 (High Impact)
4. **Large adult (SC5) data** — Key for population models
5. **Pan-Caribbean standardization** — Enable regional comparisons
6. **Density dependence** — Critical for restoration density planning

### Priority 3 (Moderate Impact)
7. **Size threshold precision** — Improve outplant size recommendations
8. **Depth effects** — Inform site selection
9. **Fragment vs intact dynamics** — Inform fragment collection practices

---

# PART V: INTEGRATED DEMOGRAPHIC PARAMETERS

## 5.1 Size-Structured Population Model

### Projection Matrix Structure

```
     To:  SC1    SC2    SC3    SC4    SC5
From:
SC1  [S₁G₁₁  S₂G₂₁  S₃G₃₁  S₄G₄₁  S₅G₅₁]   ← Survival × Pr(shrink to SC1)
SC2  [S₁G₁₂  S₂G₂₂  S₃G₃₂  S₄G₄₂  S₅G₅₂]   ← Survival × Pr(transition to SC2)
SC3  [S₁G₁₃  S₂G₂₃  S₃G₃₃  S₄G₄₃  S₅G₅₃]
SC4  [S₁G₁₄  S₂G₂₄  S₃G₃₄  S₄G₄₄  S₅G₅₄]
SC5  [S₁G₁₅  S₂G₂₅  S₃G₃₅  S₄G₄₅  S₅G₅₅]   ← Survival × Pr(grow to SC5)

Where:
- Sᵢ = Survival probability for size class i
- Gᵢⱼ = Pr(individual in class i transitions to class j | survived)
- Column sums = survival for that class (Σⱼ Sᵢ × Gᵢⱼ = Sᵢ)
```

### Parameter Tables (To Be Estimated)

**Survival by Size Class** *(completed — from analysis pipeline)*:

| Class | Mean | 95% CI | N | Regions | Certainty |
|-------|------|--------|---|---------|-----------|
| SC1 | 0.724 | — | 366 | 5+ | High |
| SC2 | 0.644 | — | 1,342 | 5+ | High |
| SC3 | 0.768 | — | 920 | 4 | Moderate |
| SC4 | 0.876 | — | 837 | 4 | Moderate |
| SC5 | 0.937 | — | 1,731 | 3 | Low-Moderate |

**Transition Matrix** *(completed — from script 13)* (row = from, col = to):

| From\To | SC1 | SC2 | SC3 | SC4 | SC5 |
|---------|-----|-----|-----|-----|-----|
| SC1 | 20.1% | 35.7% | 12.4% | 0.3% | 0% |
| SC2 | 2.4% | 31.3% | 35.2% | 0.3% | 0% |
| SC3 | 1.5% | 6.1% | 52.8% | 14.7% | 0.2% |
| SC4 | 2.7% | 5.1% | 10.7% | 60.0% | 15.3% |
| SC5 | 2.6% | 19.9% | 29.6% | 8.8% | 86.6% |

## 5.2 Context-Specific Parameters

Provide separate parameter sets for:

1. **Field (baseline)** — Most data, highest certainty
2. **Nursery** — Limited to SC1-SC2, short duration
3. **Post-disturbance** — Hurricane years flagged
4. **Projected (climate scenarios)** — Model-derived

## 5.3 Sensitivity Analysis

**Question**: Which parameters most affect population growth rate (λ)?

**Method**: Elasticity analysis
```r
# Proportional change in λ for proportional change in each matrix element
elasticity <- sensitivity(A) * A / lambda(A)
```

**Expected Result**: Large adult survival (SC4, SC5) likely has highest elasticity — but we have lower certainty for these classes.

---

# PART VI: PUBLICATION PLAN

## 6.1 Main Figures (6) *(Updated Feb 2026 — see `docs/MANUSCRIPT_FIGURE_PLAN.md` for full details)*

| # | Figure | Purpose | Key Message |
|---|--------|---------|-------------|
| 1 | Caribbean map + temporal + size distribution | Data landscape | Where, when, and what — NOAA dominance, geographic bias |
| 2 | Survival~size + small-colony threshold + RGR~size + P(+growth) | Size-dependent demography & nonlinearities (4 panels) | Nonlinear relationships; opposing threshold patterns in natural vs. restored |
| 3 | Regional forest plot + size × region heatmap | Geographic variation | Substantial variation but confounded with methodology |
| 4 | Natural vs. restoration (3 panels) | Population type comparison | 13-17 pp survival advantage for natural colonies at matched sizes |
| 5 | Transition matrix + elasticity + lambda bootstrap | Population model | λ=0.986, SC5 stasis=54.8% elasticity, P(decline)=87.3% |
| 6 | Certainty heatmap + gap priorities | Data gaps | High certainty for SC1-3 but low for SC5 (most critical) |

## 6.2 Supplementary Figures (10) *(Updated Feb 2026)*

1. Model diagnostics (survival GLMM, growth LMM)
2. Meta-analysis forest plot + funnel plot
3. Absolute growth rate (AGR) by size
4. Temporal trends (annual survival, size × year heatmap)
5. Leave-one-study-out sensitivity (NOAA removal drops λ 26%)
6. Cross-validation performance (LOSO-CV, LORO-CV)
7. Allometric scaling (log-log, size-matched ANCOVA)
8. Climate-demography relationship
9. Context comparison (field vs. nursery vs. lab)
10. Power analysis and sample size recommendations

## 6.3 Key Tables

| # | Table | Content |
|---|-------|---------|
| 1 | Study metadata | 18 studies, N, years, methods |
| 2 | Regional sample sizes | Region × size class matrix |
| 3 | Survival parameters | By size class with CIs |
| 4 | Growth parameters | By size class with variance |
| 5 | Transition matrix | 5×5 with uncertainty |
| 6 | **Gap priorities** | Ranked recommendations |
| 7 | **Certainty scores** | By parameter |

---

# PART VII: STATISTICAL METHODS

## 7.1 Primary Models

### Survival
```r
# Hierarchical binomial model
glmer(survived ~ log(size_cm2) + region + (1|study/site) + (1|year),
      family = binomial, data = surv)

# Threshold detection
segmented(glm(...), seg.Z = ~log(size_cm2))
```

### Growth
```r
# Mixed model for growth rate
lmer(growth_cm2_yr ~ log(size_cm2) * region + (1|study/site),
     data = growth)
```

## 7.2 Uncertainty Quantification

1. **Bootstrap** for parameter CIs (1000 iterations)
2. **Resampling** for summarized data (50 replicates, per Raine's approach)
3. **Model comparison** via AIC/LOO-CV
4. **Sensitivity analysis** for key predictions

## 7.3 Handling Heterogeneous Data

| Issue | Solution |
|-------|----------|
| Individual vs. summarized | Pseudo-individual conversion + resampling |
| Non-annual intervals | Convert to annual rates |
| Missing covariates | Multiple imputation or exclude |
| Zero-inflation (survival) | Standard binomial adequate |

---

# PART VIII: IMPLEMENTATION STATUS

> All analysis phases are complete as of February 2026. Remaining work: manuscript writing and figure polish.

## Phase 1: Data Finalization — COMPLETE
- [x] Complete QA/QC (script 01, DATA_QUALITY_AUDIT.md)
- [x] Standardize size class definitions (utils/shared_utilities.R)
- [x] Create analysis-ready datasets (prepared_survival_data.rds, prepared_growth_data.rds)
- [x] Document exclusions (Data_Methodology_Reference.md)

## Phase 2: Descriptive Analysis — COMPLETE
- [x] Generate all summary statistics (data_summary_statistics.csv)
- [x] Create data landscape figures (18_fig1_study_landscape.R)
- [x] Map study coverage (Caribbean map with site bubbles)
- [x] Document sample sizes by region × size × year

## Phase 3: Core Modeling — COMPLETE
- [x] Fit survival models (02_survival_thresholds.R)
- [x] Fit growth models (03_growth_thresholds.R, 04_growth_rate_comparison.R)
- [x] Threshold analyses (GAM inflection, segmented regression)
- [x] Certainty scoring (06_data_gap_analysis.R)
- [x] Calculate transition matrices (13_transition_matrix.R)

## Phase 4: Gap Analysis — COMPLETE
- [x] Quantify all gaps (gap_prioritization.csv)
- [x] Priority ranking (certainty_by_size_class.csv)
- [x] Power analysis (09_power_analysis.R)
- [x] Sample size recommendations (sample_size_recommendations.csv)

## Phase 5: Figures & Tables — COMPLETE (polish in progress)
- [x] Publication-quality figures (scripts 06, 18, 19, 20)
- [x] Supplementary materials (scripts 02-16 generate exploratory figures)
- [x] Parameter tables with uncertainty (analysis/output/*.csv)
- [ ] Final figure polish per MANUSCRIPT_FIGURE_PLAN.md

## Phase 6: Writing — IN PROGRESS
- [ ] Introduction: Why this synthesis matters
- [ ] Methods: Standardization + modeling approach
- [ ] Results: What we know (with certainty levels)
- [ ] Discussion: What we don't know + recommendations

## Phase 7: Review & Submit
- [ ] Internal review
- [ ] Revisions
- [ ] Submit

---

# APPENDICES

## Appendix A: Size Class Definitions

| Class | Range (cm²) | Approx. Diameter | Stage | Notes |
|-------|-------------|------------------|-------|-------|
| SC1 | 0-10 | <3.5 cm | Recruit/fragment | High mortality, high uncertainty |
| SC2 | 10-100 | 3.5-11 cm | Juvenile | Rapid growth possible |
| SC3 | 100-900 | 11-34 cm | Sub-adult | Transition to maturity |
| SC4 | 900-4000 | 34-71 cm | Adult | Reproductive, key for population |
| SC5 | >4000 | >71 cm | Large adult | Highest survival, lowest certainty |

## Appendix B: Study Summary

| Study | Region | Years | N (surv) | N (growth) | Type |
|-------|--------|-------|----------|------------|------|
| NOAA Survey | Multi | 2004-2024 | ~3,000 | ~2,500 | Field |
| Kuffner 2020 | FL | 2010-2020 | ~800 | ~700 | Field |
| FUNDEMAR | DR | 2021 | ~14,000 | 45 | Field |
| Pausch 2018 | FL | 2014-2015 | ~200 | ~180 | Field |
| ... | ... | ... | ... | ... | ... |

## Appendix C: R Code Repository *(Updated Feb 2026)*

```
Detmer-2025-coral-parameters/
├── analysis/
│   ├── scripts/                        # 23 analysis scripts
│   │   ├── 01_data_preparation.R       # Data loading, size classes, QC
│   │   ├── 02_survival_thresholds.R    # GAM/GLMM thresholds
│   │   ├── 03_growth_thresholds.R      # Growth thresholds
│   │   ├── 04_growth_rate_comparison.R # AGR vs RGR, allometry
│   │   ├── 05_variance_partitioning.R  # Variance partitioning
│   │   ├── 06_data_gap_analysis.R      # Certainty scoring, priorities
│   │   ├── 07_integrate_summary_data.R # Summary data integration
│   │   ├── 08_climate_demography.R     # Climate-demography
│   │   ├── 09_power_analysis.R         # Sample size recommendations
│   │   ├── 10_cross_validation.R       # LOSO-CV, LORO-CV
│   │   ├── 11_context_comparison.R     # Field vs nursery vs lab
│   │   ├── 12_model_selection.R        # AIC/BIC comparison
│   │   ├── 13_transition_matrix.R      # Lefkovitch matrix, λ, elasticity
│   │   ├── 14_meta_analysis.R          # Random-effects meta-analysis
│   │   ├── 15_heterogeneity_analysis.R # I², Q-tests
│   │   ├── 16_sensitivity_analysis.R   # Leave-one-out, robustness
│   │   ├── 17_update_parameter_lists.R # Parameter list generation
│   │   ├── 18_fig1_study_landscape.R   # Fig 1: Caribbean map (16 studies)
│   │   ├── 19_fig2_demographic_rates.R # Fig 2: Demographic rates
│   │   ├── 20_fig_size_class_survival_synthesis.R # Fig 4: Size-class survival
│   │   ├── 20b_fig_expanded_forest_plot.R # Fig 5: Forest plot (k=16)
│   │   ├── 20c_fig_regional_survival.R # Fig S15: Regional survival
│   │   ├── 21_fig3_natural_vs_restoration.R # Fig 3: Natural vs restoration
│   │   ├── 22_fig6_population_model.R  # Fig 6: Population model
│   │   ├── 23_figS2_data_gaps.R        # Fig S2: Data gaps heatmap
│   │   ├── 24-28_supp_*.R              # Supplementary figures S3-S14
│   │   ├── 23_verification.R           # End-to-end verification checks
│   │   ├── run_all.R                   # Full pipeline runner
│   │   └── utils/shared_utilities.R    # Canonical constants + helpers
│   ├── rmarkdown/                      # R Markdown documents
│   ├── output/                         # 107+ CSV/RDS result files
│   └── figures/                        # Publication figures
│       ├── main/                       # Main figures
│       ├── publication/                # Publication-ready
│       └── supplementary/              # Supporting visualizations
├── web-platform/                # Web application
│   ├── frontend/                       # React + TypeScript + D3
│   └── backend/                        # R Plumber REST API
├── standardized_data/                  # 8 cleaned datasets
├── parameter_lists/                    # 7 RDS parameter files
├── docs/                               # Documentation
└── original_data/                      # 15 raw source datasets
```

---

*This plan provided the roadmap for synthesizing what we know about A. palmata demographics. Analysis is now complete — see `docs/ANALYSIS_SUMMARY.md` for definitive results and `docs/MANUSCRIPT_FIGURE_PLAN.md` for the figure design.*

**Original**: December 2025 | **Status updated**: February 2026
