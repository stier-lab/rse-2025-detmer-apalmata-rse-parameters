# Methodology Critique and Recommendations

**Date:** 2026-04-14
**Context:** Internal review of analytical approach after switching to inverse-variance logit-scale weighting (lambda shifted from 0.986 to 0.888). Three independent critiques: ecological validity, statistical methodology, and comparison to published models.

---

## 1. Ecological Validity

### Size class boundaries
- SC1 (0-10 cm^2) conflates sexually-produced recruits (<1 cm^2, near-total mortality) with small fragment chips (20-50 cm^2, moderate mortality). With zero fecundity in the model, SC1 effectively contains only tiny fragments.
- SC5 (>4000 cm^2) is defensible for reproductive maturity, though gamete production begins as small as ~500 cm^2 (Soong & Lang 1992).
- **Recommendation:** Consider an IPM to bypass boundary issues entirely — the data exist (~7,800 survival + ~6,300 growth records).

### Mortality definition heterogeneity
- NOAA (78% of data): dead = no tissue AND skeleton gone (very conservative)
- Kuffner: dead = >=50% tissue loss (aggressive)
- *A. palmata* can regrow from 80-95% tissue loss after hurricanes (Bythell et al. 1993)
- This definitional heterogeneity likely drives much of the I^2 = 96.6%
- **Recommendation:** Stratify the transition matrix by mortality definition (NOAA-definition vs non-NOAA) as a sensitivity analysis.

### Zero fecundity is likely realistic
- Most *A. palmata* stands are monoclonal (Baums et al. 2005, 2006) — gametes from clonemates are self-incompatible
- Larval settlement rates are extremely low in the field (Erwin & Szmant 2010)
- Even adding 1.0 recruit/adult/year barely raises lambda above 1.0
- The zero-fecundity assumption is not merely conservative — it reflects the biology of contemporary populations

### Fragmentation bottleneck
- 13 rows from one study (Vardi 2011), during low hurricane activity (2007-2011)
- Fragmentation is both the primary mortality source (storms) and the primary reproduction pathway — a demographic paradox the constant-rate matrix cannot capture
- In hurricane-active periods, fragmentation rates could be 2-5x higher, substantially changing lambda

### Lambda = 0.888: interpretation
- A population halving every ~6 years is roughly consistent with the >95% decline documented since the 1970s (Gardner et al. 2003, Aronson & Precht 2001)
- **But** the LOSO analysis shows removing Neely (2014 catastrophe) raises lambda to 0.993
- **Lambda = 0.888 is a time-averaged rate across the monitoring period (including catastrophic events), not a steady-state parameter**
- The species persists because lambda is not constant: years near 1.0 punctuated by catastrophic years (lambda << 1)
- Immigration from connected populations is not modeled

---

## 2. Comparison to Published Models

### Vardi et al. 2012 (the model we update)
- Mean-matrix lambda = **0.96** (N. Florida Keys, 2004-2010, 4 size classes)
- Annual range: **0.71-1.05** across 6 yearly matrices
- Stochastic (h=20 yr hurricane return): lambda_s = **0.999** (near replacement)
- Stochastic (h=6 yr): lambda_s = **0.956** (decline)

Our n-weighted estimate (0.959) matches Vardi's mean-matrix lambda almost exactly. The IV-weighted estimate (0.888) is lower because of broader geographic scope, inclusion of disturbance years (esp. Neely 2014), and the weighting shift.

### Why our lambda is lower
1. **5 size classes vs 4**: Adding the SC1 recruit class (0-10 cm^2) with high mortality pulls the eigenvalue down
2. **Geographic scope**: 7 studies across 7 regions vs. 1 site in Florida Keys
3. **Inclusion of Neely 2014**: LOSO shows removing Neely raises lambda to 0.993
4. **Retrogression**: 39.4% shrinkage frequency more thoroughly modeled than Vardi

### 100% quasi-extinction vs observed persistence
The stochastic IPM shows 100% quasi-extinction in all scenarios. This is consistent with:
- Observed functional extinction in Florida (Manzello 2025)
- ~95% Caribbean-wide decline since 1970s (Gardner et al. 2003)

The species persists because:
- **Metapopulation dynamics**: larval connectivity from distant source populations
- **Spatial heterogeneity**: catastrophic events don't affect all sites simultaneously
- **Density dependence**: reduced competition at low density (not modeled)
- **Cryptic tissue persistence**: small remnants can re-emerge
- **Clonal resilience**: genets persist across spatially distributed ramets

## 3. Statistical Methodology

### Lambda = 0.888 is downward-biased (CRITICAL finding)

The stats review identified three compounding errors in the logit IV weighting:

**Error 1: Cell-level granularity creates n=1 pathology.** Individual NOAA data is aggregated by `study x region x size_class x time_interval_yr`. Because NOAA has 162 unique interval lengths for SC5 alone, this creates many cells with n=1 (32.4% of NOAA cells). These are individual colony fates treated as if they were independent studies. IV weighting at this level is a category error.

**Error 2: Logit transformation upweights rare mortality events.** The logit-scale variance formula `vi = 1/(n*p*(1-p))` assigns maximum precision to cells near p=0.5 and minimum precision near p=0 or p=1. For SC5 (true survival ~0.95), the rare cells where large colonies died (p < 0.5) get 10x the weight of typical cells (p=1.0). SC5 drops from 0.949 (n-weighted) to 0.873 (logit IV) even though all three studies agree on ~0.93-0.95 survival.

**Error 3: Wrong variance formula for annualized survival.** The code applies `vi = 1/(n * p_ann * (1-p_ann))` where p_ann is the annualized rate. The correct variance of logit(p_raw^(1/t)) requires the delta method, which gives a different result. For a 2-year interval (p=0.64, n=50), the ad-hoc formula overestimates variance by 1.78x. Since 46.6% of cells have non-annual intervals, this affects nearly half the data, systematically downweighting high-survival studies.

### The proper approach: rma() per size class

Using `rma()` (random-effects meta-analysis with REML) at the study level per size class gives:

| Size class | Logit IV (old) | N-weighted | rma() per SC (implemented) |
|---|---|---|---|
| SC1 | 0.506 | 0.524 | **0.507** |
| SC2 | 0.628 | 0.662 | **0.731** |
| SC3 | 0.720 | 0.773 | **0.786** |
| SC4 | 0.811 | 0.883 | **0.881** |
| SC5 | 0.873 | 0.949 | **0.948** |
| **Lambda** | **0.888** | **0.959** | **0.961** |
| **95% CI** | [0.740, 0.959] | [0.801, 1.012] | **[0.816, 1.010]** |
| **P(decline)** | — | — | **94.3%** |

The rma() estimate (lambda = 0.961) is methodologically consistent with script 14b's meta-analysis approach and eliminates the n=1 cell pathology. It matches Vardi 2012's mean-matrix lambda (0.96) closely.

### Implementation (2026-04-14): switched to rma() per size class
Script 13's survival estimation now uses `metafor::rma()` per size class, treating each study as the unit of analysis with proper random-effects pooling (REML). Both the point estimate and the 2000-iteration bootstrap use study-level rma(). The ad-hoc cell-level IV weighting has been replaced.

### Bootstrap independence concern
- Survival uses 5 natural-colony studies; growth uses 7 studies (only 3 overlap)
- Independent resampling inflates the CI width (conservative) but doesn't bias the point estimate much
- The structural concern is that growth is estimated partly from restoration studies while survival is natural-colony only

---

## 4. Recommendations (ranked by impact and feasibility)

1. ~~**Present both weighting approaches as a sensitivity range**~~ **RESOLVED (2026-04-14):** Switched to study-level rma() per size class. Lambda = 0.961 (95% CI: 0.816-1.010). The logit IV bias has been eliminated. Report LOSO range (0.882-0.993) alongside.
2. **Separate catastrophe-year vs non-catastrophe-year lambdas** — the time-averaged estimate conflates chronic decline with discrete catastrophic events
3. **Run the mortality-definition sensitivity analysis** — stratify by NOAA vs non-NOAA mortality definitions
4. **Contextualize against Vardi 2012** explicitly: our n-weighted estimate falls within their annual range (0.71-1.05) and matches their mean-matrix lambda
5. **Expand the fecundity discussion** — cite Baums on clonality, Levitan on density-dependent fertilization, Erwin & Szmant on settlement failure
6. **Acknowledge the fragmentation bottleneck** — 13 rows, one study, low-hurricane period, sole reproductive pathway
7. **Frame quasi-extinction results** as consistent with regional extinction (Florida) while acknowledging metapopulation dynamics explain Caribbean-wide persistence
8. **Consider an IPM** as a future extension to bypass size class boundary issues
