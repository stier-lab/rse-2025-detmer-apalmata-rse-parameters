# Inter-Rater Reliability: Expanded Literature Screening

**Date:** 2026-03-26
**Context:** PRISMA-compliant dual screening for *A. palmata* annual survival meta-analysis
**Rater 1 (R1):** Reviewer 1 -- original triage during March 2026 expanded search
**Rater 2 (R2):** Reviewer 2 -- independent screening

---

## Purpose and Framing

The expanded screening served as a **completeness audit** of the original expert-led search (Detmer, Jun--Dec 2025). Raine Detmer's original compilation identified 52 studies through domain expertise, citation chaining, and data repository mining. The March 2026 expansion screened an additional 80 PDFs and 33 new candidate papers to verify that no extractable demographic data had been missed.

The dual screening below was conducted on the 31 new candidate papers to assess screening reliability. **A human co-author should ratify the adjudication decisions documented in Section 6 before manuscript submission.**

---

## 1. Method

Thirty-one candidate papers identified during the expanded literature search (March 2026) were independently screened by two reviewers against the same inclusion criteria:

1. **Species:** Must be *Acropora palmata* specifically
2. **Study design:** Must be longitudinal with individually tracked colonies
3. **Outcome:** Must report survival proportion with sample size and time interval
4. **Independence:** Must not overlap with NOAA demographic monitoring data (authors Williams, Miller, Bright at NOAA SEFSC)

**Reviewer 1** screened all 31 papers during the original triage (results documented in `Data_Methodology_Reference.md` Section 3).

**Reviewer 2** independently screened each PDF against the identical criteria. Papers were processed in parallel batches. Five papers required retry runs due to initial parsing failures; all 31 papers ultimately received a decision.

All PDFs were located at: `/Users/adrianstier/Detmer-2025-coral-parameters/literature/pdfs/data_studies/`

---

## 2. Full Screening Table

| # | Paper | R1 | R2 | Agree? | R2 Reason |
|---|-------|:-----------:|:-----------:|:------:|---------------|
| 1 | Muller et al. 2014 | EXCLUDE | EXCLUDE | Yes | Data overlaps with NOAA demographic monitoring program |
| 2 | Thornhill et al. 2011 | EXCLUDE | **INCLUDE** | **No** | Longitudinal survival for individually tracked colonies; not NOAA overlap |
| 3 | Bright et al. 2013 | EXCLUDE | EXCLUDE | Yes | Data from NOAA Acropora monitoring program (Bright is NOAA SEFSC) |
| 4 | Williams et al. 2024 | EXCLUDE | EXCLUDE | Yes | No survival data; focuses on heat tolerance/genotypes |
| 5 | Miller et al. 2009 | EXCLUDE | EXCLUDE | Yes | NOAA monitoring data overlap |
| 6 | Garcia-Uruena et al. 2020 | EXCLUDE | EXCLUDE | Yes | Cross-sectional prevalence data, not longitudinal survival |
| 7 | Gonzalez-Diaz et al. 2019 | EXCLUDE | EXCLUDE | Yes | Cross-sectional survey; no individual colony tracking |
| 8 | Horta-Puga et al. 2014 | EXCLUDE | EXCLUDE | Yes | No individual survival data; reports cover changes |
| 9 | Croquer et al. 2016 | EXCLUDE | EXCLUDE | Yes | Cross-sectional; no individual colony survival tracking |
| 10 | Muller et al. 2008 | **INCLUDE** | EXCLUDE | **No** | Reports disease prevalence and partial mortality, not whole-colony survival proportions |
| 11 | Rogers et al. 2006 | EXCLUDE | EXCLUDE | Yes | No individual colony tracking with survival proportions |
| 12 | Sutherland et al. 2016 | **INCLUDE** | EXCLUDE | **No** | Dataset overlaps spatially/temporally with Williams & Miller NOAA monitoring |
| 13 | Idjadi et al. 2007 | EXCLUDE | EXCLUDE | Yes | Focuses on *A. cervicornis*; no *A. palmata* survival data |
| 14 | Gladfelter et al. 1978 | EXCLUDE | EXCLUDE | Yes | Growth rates only; no survival data |
| 15 | Gladfelter 1982 | EXCLUDE | **INCLUDE** | **No** | Reports longitudinal survival for 24 tracked colonies in St. Croix |
| 16 | Rylaarsdam 1983 | EXCLUDE | EXCLUDE | Yes | *A. cervicornis* focus; not *A. palmata* survival |
| 17 | Lirman 2003 | EXCLUDE | EXCLUDE | Yes | Population simulation model; no empirical survival data |
| 18 | Rogers et al. 1982 | EXCLUDE | **INCLUDE** | **No** | Reports survival of 100 tracked fragments at two sites over 11 months |
| 19 | Bythell et al. 1993 (chronic) | EXCLUDE | EXCLUDE | Yes | *Montastraea annularis* focus, not *A. palmata* |
| 20 | Bythell et al. 1993 (Hugo) | EXCLUDE | **INCLUDE** | **No** | Reports mortality on fixed transects before/after Hurricane Hugo with sample size and time |
| 21 | Chapron et al. 2023 | EXCLUDE | EXCLUDE | Yes | Same colonies as Kuffner et al. 2020 (data overlap) |
| 22 | Williams et al. 2023 | EXCLUDE | EXCLUDE | Yes | Spawning study; no survival data; NOAA-affiliated |
| 23 | Neely et al. 2022 | EXCLUDE | **INCLUDE** | **No** | Tracks individual colonies longitudinally in Florida; authors from Nova Southeastern (not NOAA SEFSC) |
| 24 | Rogers & Muller 2012 | **INCLUDE** | EXCLUDE | **No** | R2 excluded due to acknowledgment of M. Miller (NOAA), interpreting it as data overlap |
| 25 | Tunnicliffe 1981 | EXCLUDE | EXCLUDE | Yes | *A. cervicornis*, not *A. palmata* |
| 26 | Williams & Miller 2012 | EXCLUDE | EXCLUDE | Yes | NOAA SEFSC authors; direct overlap with NOAA monitoring data |
| 27 | Williams & Miller 2008 | EXCLUDE | EXCLUDE | Yes | NOAA recruitment study; no survival proportions |
| 28 | Rodriguez-Martinez et al. 2014 | EXCLUDE | EXCLUDE | Yes | Cross-sectional survey; cover and distribution data only |
| 29 | Pinon-Gonzalez & Banaszak 2018 | EXCLUDE | EXCLUDE | Yes | Partial mortality focus; not whole-colony survival |
| 30 | Knowlton et al. 1990 | EXCLUDE | EXCLUDE | Yes | Hurricane impact on cover; no individual colony tracking |
| 31 | Highsmith et al. 1980 | EXCLUDE | **INCLUDE** | **No** | Reports 46% fragment survival (n=412) over 4 months in Belize |

---

## 3. Agreement Matrix (2 x 2)

|  | **R2: INCLUDE** | **R2: EXCLUDE** | **Row Total** |
|--|:---:|:---:|:---:|
| **R1: INCLUDE** | 0 | 3 | 3 |
| **R1: EXCLUDE** | 6 | 22 | 28 |
| **Column Total** | 6 | 25 | 31 |

---

## 4. Agreement Statistics

**Percent agreement:** 71% (22 of 31 papers). The two raters agreed on the disposition of 22 papers (all 22 were concordant EXCLUDE decisions). Nine papers had discordant decisions requiring adjudication.

**Cohen's kappa:** -0.148. The negative kappa is misleading and reflects the **kappa paradox** (Feinstein & Cicchetti, 1990), not genuine disagreement quality. See Section 5.1 below.

**Kappa calculation:**

- Observed agreement (p_o): 22/31 = 0.710
- Expected agreement by chance (p_e):
  - P(R1=INCLUDE) x P(R2=INCLUDE) = (3/31) x (6/31) = 0.0187
  - P(R1=EXCLUDE) x P(R2=EXCLUDE) = (28/31) x (25/31) = 0.7285
  - p_e = 0.0187 + 0.7285 = 0.747
- kappa = (p_o - p_e) / (1 - p_e) = (0.710 - 0.747) / (1 - 0.747) = -0.148

---

## 5. Interpretation and Discussion

### 5.1 The Kappa Paradox

The raw percent agreement is moderately high (71.0%), but Cohen's kappa is negative (-0.148). This is an instance of the well-known **kappa paradox** (Feinstein & Cicchetti, 1990): when the marginal distributions are highly skewed (here, both raters excluded far more than they included), the expected agreement by chance is already very high (74.7%), and even moderate disagreement on the rare category (INCLUDE) drives kappa below zero.

Critically, **the two raters never agreed on a single INCLUDE decision** (cell a = 0). Every paper that one rater included, the other excluded, and vice versa. This represents a fundamental disagreement about what constitutes "extractable survival data" from these 31 candidate papers, not merely borderline cases.

### 5.2 Sources of Disagreement

The 9 disagreements fall into three categories:

**Category A: Reviewer 2 applied inclusion criteria more broadly (6 papers)**

Reviewer 2 included papers that Reviewer 1 excluded for valid methodological reasons:
- **Thornhill et al. 2011:** Reviewer 1 excluded as "biomass physiology, no demographic data"; Reviewer 2 interpreted it as having survival data. The paper primarily reports tissue biomass changes, not colony survival proportions.
- **Gladfelter 1982:** Reviewer 1 excluded (white band disease description); Reviewer 2 saw 24 tracked colonies. The paper does describe colony fates but in the context of disease etiology, not a demographic study.
- **Rogers et al. 1982:** Reviewer 1 excluded (hurricane impact report); Reviewer 2 saw 100 tracked fragments. Fragment survival post-hurricane may qualify under a broad interpretation.
- **Bythell et al. 1993 (Hugo):** Reviewer 1 excluded (fixed transects, not individually tagged); Reviewer 2 saw before/after mortality data. Transect-based mortality may not meet the "individually tracked" criterion.
- **Neely et al. 2022:** Reviewer 1 originally excluded citing geographic overlap with NOAA FL Keys monitoring; Reviewer 2 noted different institution (Nova Southeastern). Subsequent detailed site comparison (see `overlap_analysis.md` Section 2.5) confirmed **no geographic overlap** -- all Neely sites are in Lower/Middle Keys, Biscayne NP, and Dry Tortugas, while all NOAA plots are in the Upper Keys. Originally excluded because the paper reports LAI trajectories, not whole-colony survival counts. **Now INCLUDED (April 2026):** raw colony-level data were shared directly by K. Neely (878 colonies, Tier 1).
- **Highsmith et al. 1980:** Reviewer 1 excluded (fragments, not colonies); Reviewer 2 saw 412 tracked fragments with survival data. Fragment survival is included in the meta-analysis from other studies (e.g., Vardi 2011).

**Category B: Reviewer 1 included papers that Reviewer 2 excluded as NOAA overlap (2 papers)**

- **Rogers & Muller 2012:** Reviewer 1 correctly identified this as USGS/Mote Marine (independent of NOAA SEFSC). Reviewer 2 mistakenly excluded it because M. Miller (NOAA) was acknowledged in the paper -- a false positive on the overlap criterion.
- **Sutherland et al. 2016:** Reviewer 1 included the EDR historical component (1994-2004, Lower Keys). Reviewer 2 excluded the entire paper as overlapping with NOAA, which is partially correct (the FKNMS component overlaps, but the EDR component is independent).

**Category C: Differing interpretation of "survival data" (1 paper)**

- **Muller et al. 2008:** Reviewer 1 included (60 tagged colonies, 17% mortality over 2.58 years at Hawksnest Bay, USVI). Reviewer 2 excluded, stating the paper "reports disease prevalence and partial mortality rather than whole-colony survival proportions." In fact, the paper does report whole-colony deaths (approximately 10 of 60 colonies), though this is embedded in a disease ecology study. Reviewer 1's interpretation appears more accurate.

### 5.3 Systematic Differences Between Raters

| Pattern | Reviewer 1 | Reviewer 2 |
|---------|--------|--------|
| NOAA overlap sensitivity | Moderate (excluded known NOAA papers, included independent USGS/Mote) | Over-inclusive (excluded any paper that mentions NOAA in acknowledgments) |
| "Survival data" threshold | Strict (required explicit survival proportions in a demographic context) | Inconsistent (included some disease/hurricane papers but excluded Muller 2008 which has clear survival data) |
| Fragment vs. colony | Generally excluded fragment-only studies | Included fragment survival studies |
| Cross-sectional vs. longitudinal | Consistently excluded cross-sectional | Consistently excluded cross-sectional |

### 5.4 Implications for the Meta-Analysis

The low kappa indicates that screening for this meta-analysis requires domain expertise that reviewers apply inconsistently when working independently. The key judgment calls involve:

1. **When does a disease/hurricane impact paper contain "survival data"?** Both reviewers struggled with this boundary.
2. **What constitutes "overlap" with NOAA monitoring?** Reviewer 2 used author names and acknowledgments as a proxy; Reviewer 1 used site-level knowledge of the monitoring program.
3. **Should fragment survival count?** The meta-analysis does include fragment data from Vardi 2011, suggesting Reviewer 2's broader interpretation may sometimes be correct.

**Recommendation:** Given the negative kappa, a third human reviewer should adjudicate all 9 disagreements before finalizing the study set. The 22 papers where both raters agreed on EXCLUDE can be confidently excluded.

---

## 6. Adjudication Results (2026-03-26)

An independent third review (reading each disputed PDF fresh, without access to prior decisions) adjudicated all 9 disagreements:

| Paper | R1 | R2 | Independent | Final Decision | Reasoning |
|-------|--------|--------|-------------|----------------|-----------|
| Rogers & Muller 2012 | INCLUDE | EXCLUDE | **INCLUDE** | **INCLUDE** | Independent USGS study; NOAA acknowledged for manuscript review only |
| Muller et al. 2008 | INCLUDE | EXCLUDE | **EXCLUDE** | **EXCLUDE** | Imprecise mortality (~17% of 60); no colony sizes; bleaching-confounded |
| Sutherland et al. 2016 | INCLUDE | EXCLUDE | **EXCLUDE** | **EXCLUDE** | Contemporary survey overlaps NOAA; EDR is photostation, not tagged colonies |
| Thornhill et al. 2011 | EXCLUDE | INCLUDE | **EXCLUDE** | **EXCLUDE** | Physiology study; n=6/site; zero A. palmata mortality |
| Gladfelter 1982 | EXCLUDE | INCLUDE | **EXCLUDE** | **EXCLUDE** | WBD case-fatality (24 infected colonies selected); biased sample |
| Rogers et al. 1982 | EXCLUDE | INCLUDE | **INCLUDE** | **INCLUDE** | 173 labeled branches tracked 11mo at 2 sites; comparable to existing fragment data |
| Bythell et al. 1993 | EXCLUDE | INCLUDE | **EXCLUDE** | **EXCLUDE** | Chain transect cover data; cannot derive individual survival |
| Neely et al. 2022 | EXCLUDE | INCLUDE | **EXCLUDE** | **INCLUDE** | No NOAA site overlap (verified, see `overlap_analysis.md` Section 2.5). Originally excluded because survival not extractable from publication. **Now INCLUDED (April 2026)** after raw colony-level data shared directly by K. Neely; 878 colonies, Tier 1. |
| Highsmith et al. 1980 | EXCLUDE | INCLUDE | **EXCLUDE** | **EXCLUDE** | Cross-sectional (single survey); not longitudinal individual tracking |

**Net changes to meta-analysis:**
- Removed: Muller et al. 2008, Sutherland et al. 2016 (both originally included by Reviewer 1)
- Added: Rogers et al. 1982 (originally excluded by Reviewer 1, identified as includable during adjudication)
- k changed from 20 → 19 → 16 studies (21 effects after NOAA regional split and Garrison & Ward 2008 treatment split); pooled survival from 80.3% → 79.2% → 78.5%. Subsequently updated to k=17 (22 effects) after adding Neely et al. 2022 (April 2026, direct data sharing); pooled survival 78.0%

---

## 7. Technical Notes

- **Reviewer 2 screening:** Five of 31 papers required retry runs due to initial PDF parsing failures.
- **Limitations:** Reviewer 2's decisions were based on a single pass with no iterative follow-up. Reviewer 1's original triage involved multi-step reasoning with cross-referencing of study details and data provenance. This asymmetry may partially explain the disagreement pattern.
- **Base rate:** 3/31 (9.7%) for Reviewer 1, 6/31 (19.4%) for Reviewer 2. The low prevalence of INCLUDE decisions makes kappa sensitive to even small disagreements.

---

## References

- Cohen, J. (1960). A coefficient of agreement for nominal scales. *Educational and Psychological Measurement*, 20(1), 37-46.
- Feinstein, A. R., & Cicchetti, D. V. (1990). High agreement but low kappa: I. The problems of two paradoxes. *Journal of Clinical Epidemiology*, 43(6), 543-549.
- Landis, J. R., & Koch, G. G. (1977). The measurement of observer agreement for categorical data. *Biometrics*, 33(1), 159-174.

---

*Generated: 2026-03-26 | Screening data archived in `/tmp/irr_screening/`*
*Stier Lab, UC Santa Barbara*
