# Comprehensive Project Critique Synthesis
## Detmer & Stier — *A. palmata* Size-Dependent Demography Synthesis
**Date:** 2026-03-29 | **Method:** 6 parallel specialist agents reviewed all code, data, and documentation

---

## EXECUTIVE SUMMARY

The pipeline is methodologically sound at its core — no fatal flaws. The PRISMA documentation, hierarchical bootstrap, Knapp-Hartung meta-analysis, and systematic sensitivity analyses are well above the standard for *Coral Reefs*. The data compilation is the most complete *A. palmata* demographic dataset ever assembled.

**The three structural weaknesses are:**
1. **Narrative identity** — the paper tries to be 4 papers at once
2. **NOAA dominance** — 78% of individual data, 100% of SC5, making the matrix model effectively single-study
3. **Fragmentation dependence** — lambda hinges on 13 rows from one dissertation

---

## TIER 1: MUST FIX BEFORE SUBMISSION

### 1.1 Internal inconsistencies (data bugs)
- **Lambda discrepancy**: README says λ=1.001 (65.1% decline) vs figure legends say λ=0.986 (87.3% decline)
- **Figure legends stale**: Fig 3 legend says k=16, I²=97.9%; data says k=18, I²=96.4%
- **Maurer depth field contains latitude**: 26.093889 stored as depth_m in apal_surv_summ.csv row 14
- **Region coding bug**: "USVI" vs "US Virgin Islands" are separate factor levels in meta-analysis
- **Forest plot shape bug**: `[AI_EXTRACTED]` tier labels don't match shape mapping — 3 points get NA shapes
- **Fragmentation value >1.0**: F5_SC3 = 1.08 in Vardi Jamaica 2008 — impossible for probability
- **PRISMA protocol has 8+ [TODO] items** unfilled (search dates, hit counts, exact strings)
- **Excluded studies remain in data files**: roth, muller, sutherland, ramos rows in CSVs with only text flags
- **Rogers 1982 still listed as excluded example** in screening_criteria.md (contradicts inclusion)
- **Neely 2022 contradiction**: extraction_protocol.md says "overlap" while overlap_analysis.md says "no overlap"
- **Neely colony count**: 508 in overlap analysis vs 608 in extraction protocol
- **Roth year**: screening CSV says 2012, all other docs say 2013

### 1.2 Search strategy gap
- **No confirmed Web of Science or PubMed search** — Google Scholar + Elicit is the backbone
- A reviewer seeing "systematic review" without database searches will immediately question rigor
- **Action**: Run formal WoS + PubMed Boolean searches before submission, even if no new studies found

### 1.3 Narrative focus
- The paper tries to answer a question the data cannot answer (natural vs. restoration, p=0.405)
- **Reframe** around: "What do we know about *A. palmata* demography, what don't we know, and where are gaps most dangerous for management?"
- Move natural-vs-restoration to supplementary; elevate data gap analysis (Fig S2) to main text

---

## TIER 2: SHOULD FIX TO STRENGTHEN THE PAPER

### 2.1 Meta-analysis methodology
| Issue | Detail | Recommendation |
|-------|--------|---------------|
| Vardi non-independence | 3 effects from 1 study treated as independent in primary model | Make three-level model primary, or report k=16 studies with 18 effects |
| NOAA vs Vardi asymmetry | Vardi split by region (3 effects) but NOAA collapsed (1 effect spanning FL/Curacao/Navassa) | Split NOAA by region for consistency |
| Tier 1/Tier 2 annualization | NOAA pools raw survival across variable intervals; Tier 2 uses S^(1/t) | Document expected direction of bias, or annualize Tier 1 consistently |
| PLO back-transformation | plogis() gives conditional median, not mean, at I²=96.4% | Note distinction or report both |
| Missing trim-and-fill | Publication bias incompletely assessed | Add trimfill() even with caveats |
| Missing tau² estimator sensitivity | Only REML tested | Report DL alongside for comparison |

### 2.2 Population model
| Issue | Detail | Recommendation |
|-------|--------|---------------|
| Lambda depends on 13 fragmentation rows | λ=1.001 with fragmentation, λ=0.908 without | Present bracketed scenarios prominently |
| No sexual reproduction | Fecundity = 0; only clonal fragmentation | Present fecundity sensitivity scenarios in main text |
| 24% bootstrap failure rate | Iterations missing SC5 discarded, biasing CI | Impute SC5 from point estimate instead of discarding |
| Elasticity has no CIs | Point estimates only | Compute bootstrap elasticity distributions |
| SC5 column sum = 1.58 | Each large colony produces 0.58 fragment-equivalents/yr — depends on Vardi rates | Flag as assumption-dependent |
| Stochastic lambda mislabeled | Uses between-study variance, not environmental stochasticity | Rename and caveat |
| Transition matrix uses raw proportions | GLMM random-slope model won model selection but isn't used for matrix | Consider model-based predictions for partial pooling |

### 2.3 Data quality
| Issue | Detail | Recommendation |
|-------|--------|---------------|
| SC4 is 99.6% NOAA, SC5 is 100% NOAA | Size-survival curve above 900 cm² is single-program | State prominently: "matrix represents NOAA-monitored populations" |
| Measurement method heterogeneity | L×W overestimates area by 30-60% vs photo tracing | Sensitivity analysis with different size-conversion assumptions |
| Mendoza-Quiroz 100% survival | 52 records, all survived — biologically implausible | Flag as potential reporting artifact |
| Mortality definitions incommensurable | NOAA (no tissue/skeleton gone) vs Kuffner (≥50% tissue loss) | Test mortality definition as meta-analysis moderator |
| 80 NOAA filtered records discrepancy | Extraction protocol says 80, filtering audit shows 16 | Reconcile |

### 2.4 PRISMA/screening
| Issue | Detail | Recommendation |
|-------|--------|---------------|
| AI screening zero INCLUDE agreement | Claude and Gemini never agreed on a single inclusion | Frame as "completeness audit," not primary screening |
| Kappa = -0.148 optics | Paradox is real but looks terrible | Lead with 71% agreement, explain paradox |
| Muller 2008 ROB contradiction | Scored 8/10 (Low Risk) but excluded for data quality | Acknowledge inconsistency or reconsider |
| Manzello 2025 / Cunning 2025 unresolved | Identified as candidates but never screened | Evaluate before submission |
| No PRISMA-EcoEvo citation | Should reference O'Dea et al. 2021 | Add citation |
| Protocol not registered | PROSPERO or OSF equivalent needed, or acknowledge as limitation | Acknowledge honestly as retrospective |
| Vardi double-entry in screening CSV | Vardi 2011 and Vardi et al. 2012 both INCLUDED | Clarify as single study contribution |
| Forrester 2011 data folded into 2013 | Data pooling across publications not documented in flow diagram | Document in PRISMA flow |

---

## TIER 3: WOULD STRENGTHEN BUT NOT REQUIRED

### 3.1 Analytical enhancements
- Report `gam.check()` / `k.check()` diagnostics for survival GAM
- Add influence diagnostics (`influence()`) to meta-analysis alongside LOO
- Apply FDR correction to 4 meta-regression moderators
- Weight LOSO-CV metrics by held-out sample size
- Increase bootstrap to 5,000 iterations for better tail stability
- Compute GLMM marginal/conditional R² (Nakagawa-Schielzeth) instead of GLM pseudo-R²
- Add meta-regression of survival on study year (temporal trend)
- Test mortality definition as heterogeneity moderator

### 3.2 Framing enhancements
- **The 5.8% R² finding** (size explains almost nothing about individual survival) challenges size-structured models — deserves prominent discussion
- **Comparison to Vardi 2012**: If lambda hasn't changed in 14 years despite 10× more data, frame as "confirmation under expanded data" — the uncertainty is real and persistent
- **Prediction interval (39-96%)** is the honest management number — present it as the take-home
- Present LOSO lambda range as primary PVA result rather than single pooled lambda
- Add "recommendations for future monitoring" section based on data gap analysis

### 3.3 Reproducibility
- Archive Detmer's Google Sheet tracker in repository
- Remove excluded study rows from data files (or add structural exclusion flags, not just text notes)
- Document per-study n_total aggregation logic (sum vs max) explicitly

---

## WHAT'S DONE WELL (cite-worthy practices)

1. **Hierarchical bootstrap** (study→colony→observation) correctly implemented
2. **Overdispersion checks** on every binomial GLMM
3. **Knapp-Hartung adjustment** for small-k meta-analysis
4. **Prediction intervals** reported alongside CIs (rare in ecology)
5. **Classification sensitivity** (4 scenarios for ambiguous natural/restoration)
6. **Minimum detectable difference** analysis showing moderators are underpowered
7. **Prospective power analysis** (correctly avoids retrospective power)
8. **Five CV strategies** with study-grouped folds
9. **Size boundary sensitivity** testing across 4 alternative schemes
10. **Overlap analysis** thoroughness (NOAA, Roth discovery, Neely correction)
11. **Extraction verification** (AI vs manual — zero errors in hand-extracted data)
12. **Three-level meta-analytic model** as sensitivity for Vardi non-independence

---

## THE STRONGEST VERSION OF THIS PAPER

> "We compiled everything that exists on *A. palmata* demography. Here is what we know, here is what we do not know, and here is where the gaps are most dangerous for management."

- **Central finding**: The largest-ever demographic compilation for *A. palmata* confirms Vardi's (2012) finding of near-replacement population growth, with extreme regional heterogeneity (I²=96.4%, prediction interval 39-96%). Fourteen years of additional data have not reduced the fundamental uncertainty.
- **Novel contribution**: The data gap analysis showing SC4-SC5 data exists only from NOAA monitoring — the species' most critical life stages are parameterized from a single program
- **Actionable output**: Regional data gap prioritization for ESA recovery planning + the compiled dataset as a living resource
- **Honest framing**: The matrix model is an NOAA-anchored PVA; the meta-analysis provides Caribbean-wide context; the natural-vs-restoration comparison is exploratory and underpowered
