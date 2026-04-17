# Pre-Publication Audit Report

**Date:** 2026-04-16
**Repo:** Detmer-2025-coral-parameters
**Branch:** codex-pipeline-refresh-automation (50 commits ahead of Raine's March 26 baseline)
**Auditor:** Automated multi-phase audit with manual verification

---

## A. Must-Fix Before Submission (P0)

### 1. Natural vs. restoration p-value is wrong everywhere

- **Claim:** p=0.153 (README.md line 70, CLAUDE.md lines 24 and 193)
- **Actual:** p=0.238 (from `expanded_meta_analysis_moderators.csv` and `expanded_meta_analysis_stratified.csv`)
- **Source:** `Q_moderator p=0.2384` in the three-level rma.mv model
- **Impact:** The qualitative conclusion (not significant) holds, but the specific p-value is unverifiable from any current output. Likely stale from a prior model run with fewer studies.
- **Fix:** Replace all instances of `p=0.153` with `p=0.238`

### 2. Manuscript methods says publication bias "not formally assessed" — but it was

- **File:** `07_reporting/manuscript/manuscript_methods_draft.md`, line 65
- **Claim:** "Publication bias: not formally assessed via funnel plot"
- **Actual:** Funnel plot, Egger's test, and trim-and-fill were added to script 14b and produce output files and figures
- **Fix:** Update methods draft to reference the formal assessment (Egger's p=0.655 independent, trim-and-fill imputes 3 studies)

---

## B. Should-Fix Before Submission (P1)

### 3. I² = 96.6% in CLAUDE.md — should be 97.2%

- **File:** `CLAUDE.md` line 22
- **Actual:** I² = 97.2% (from `expanded_meta_analysis_results.csv`)
- **Fix:** Replace 96.6% with 97.2%

### 4. No renv.lock — package versions not pinned

- **Finding:** No `renv.lock` or `DESCRIPTION` file. Only `install_packages.R` which installs latest CRAN versions.
- **Risk:** Pipeline may produce different results with different package versions (especially metafor, lme4, mgcv)
- **Fix:** Run `renv::init()` and commit `renv.lock` before archiving to Zenodo/BCO-DMO

### 5. ~~Supplementary figure numbering collisions~~ RESOLVED

- ~~**FigS8** collision~~: `FigS8_forest_plots` renamed to `FigS21_forest_plots`; `FigS8_natural_vs_restoration` kept as S8.
- ~~**FigS15** collision~~: `FigS15_heatwave_scenarios` renamed to `FigS22_heatwave_scenarios`; `FigS15_regional_survival` kept as S15.
- ~~**FigSXX_** placeholders~~: All assigned proper numbers (FigS23--FigS28).
- All R scripts, canonical registry, and documentation updated.

### 6. Script 13 rma() does not use test="knha" (Knapp-Hartung)

- **File:** `06_analysis/scripts/13_transition_matrix.R`, lines 384, 387
- **CLAUDE.md convention:** "always use `test = "knha"` in `rma()` calls"
- **Script 14b:** Uses `test="knha"` for independent rma and `test="t"` for rma.mv (correct)
- **Script 13:** Uses neither — plain `rma(method="REML")` with no test argument
- **Judgment:** With k=2-5 per size class, Knapp-Hartung produces extremely wide CIs and may not be appropriate. But the inconsistency with the stated convention should be documented.
- **Fix:** Either add `test="knha"` or add a code comment explaining why it's omitted for small k

### 7. Egger's test discrepancy between models should be reported

- **Independent model:** z=0.45, p=0.655 (no asymmetry)
- **Three-level model:** t=3.47, p=0.002 (significant asymmetry)
- **Risk:** Reporting only the independent model result (p=0.655) while suppressing the three-level result (p=0.002) is selective. A reviewer who runs the three-level Egger's will find the discrepancy.
- **Fix:** Report both results and explain that the discrepancy likely reflects the nesting structure rather than true publication bias

### 8. Binomial GLMs without overdispersion checks in scripts 05, 16, 23

- **Script 16** (sensitivity analysis): 4 GLMs at lines 575, 588, 599, 625 — used for AIC comparison
- **Script 05** (variance partitioning): 5 GLMs at lines 623-631 — used for pseudo-R²
- **Script 23** (verification): 2 GLMs at lines 128, 146 — used for odds ratio
- **Fix:** Add `sum(residuals(m, "pearson")^2) / df.residual(m)` check after each

---

## C. Nice-to-Fix (P2)

### 9. NOAA sample size inconsistent: 4,025 vs 4,048

- **README.md** line 247 says 4,025; manuscript methods says 4,025
- **Actual data:** 4,048 rows in `apal_surv_ind.csv` for NOAA_survey
- **Fix:** Update to actual count

### 10. Pausch sample size inconsistent: 966 vs 789 vs 969

- **CLAUDE.md** line 134 says 966; **README.md** line 249 says 789
- **Actual data:** 969 survival records, 557 growth records
- **Fix:** Clarify which count refers to survival vs growth

### 11. k_studies == 17 hardcoded assertion in verification script

- **File:** `06_analysis/scripts/23_verification.R`, ~line 829
- **Risk:** If a study is added or removed, the assertion fails silently
- **Fix:** Parameterize or use `>= 15`

### 12. README total observations: "~14,100" vs actual 14,160

- **File:** `README.md` line 6
- **Fix:** Use exact count or "~14,200" (round up)

### 13. No formal power analysis for moderator tests

- Moderator analyses (natural vs restoration, region, year, log_size) are flagged as "exploratory" with k<10 per level — good. But no formal power analysis or minimum detectable effect size is reported.

---

## D. Verified (Passed)

- Lambda = 0.961 matches `population_parameters.csv` (0.9613)
- CI [0.816, 1.010] matches `population_parameters.csv`
- P(decline) = 94.3% matches `population_parameters.csv`
- SC5 stasis elasticity = 58.9% matches `elasticity_matrix.csv` (0.5887)
- k=17, 22 effects matches `expanded_meta_analysis_results.csv`
- Pooled survival = 78.0% matches output
- I² = 97.2% matches output (except CLAUDE.md which says 96.6%)
- LOSO range 0.882-0.993 matches `sensitivity_lambda_loo.csv`
- s_recruit = 0.028 matches `recruit_surv_pars.rds` (0.0282)
- Egger's p = 0.655 matches `publication_bias_assessment.csv`
- Trim-and-fill: 3 studies, -2.4 pp matches output
- Matrix construction: `G*diag(S)` column sums all ≤ 1; `A` column sums exceed 1 only for SC4/SC5 (fragmentation)
- Dominant eigenvalue is real and positive
- All bootstrap/resampling operations are seeded (`set.seed()` present)
- Mixed model convergence is checked and singular fits are handled
- Hierarchical bootstrap correctly resamples studies then observations
- No hardcoded `/Users/` paths in analysis scripts
- All RDS outputs are newer than their source scripts
- Pipeline entry point (`run_all.R`) is well-structured with error handling
- `sessionInfo()` is captured at the end of pipeline runs
- Size class boundaries are canonical (0/10/100/900/4000/Inf) everywhere
- `population_type` classification produces expected counts: Natural=1086, Fragment=140, Recruit=216
- Three-level rma.mv correctly nests effects within studies
- rma.mv uses `test="t"` (Knapp-Hartung equivalent) — correct
- Independent rma uses `test="knha"` — correct
- `escalc(measure="PLO", add=0.5, to="only0")` handles zero cells
- Annualization (`S^(1/t)`) is stated as an assumption in CLAUDE.md
- Fragmentation data (Vardi 2011, 13 rows) is single-source — prominently warned
- NOAA dominance (78% of data) — prominently warned with LOSO sensitivity
- Natural vs. restoration confounding — stated as limitation
- Disturbance handling is tiered (acute/context/none) — well-documented
- Mortality definition heterogeneity — sensitivity analysis added and lambda shifts by only 1 pp
- No namespace conflicts detected (no `library(MASS)` alongside `library(dplyr)`)
- No `.x`/`.y` column suffixes from joins
- Size class `cut()` uses `include.lowest=TRUE` — 10 cm² goes to SC1 (confirmed by test)
- Causal language is appropriately hedged throughout manuscript docs
- Figures 1-4 exist in manuscript/ directory
- FigS1-S28 exist in supplementary/ directory (numbering collisions resolved)

## E. Not Verifiable From This Pass

- **Full pipeline re-run timing:** The pipeline was not run end-to-end during this audit (estimated ~60 min). Individual scripts were run and outputs verified.
- **Cross-platform reproducibility:** Only tested on macOS (Darwin). Linux/Windows behavior of `cairo_pdf`, file paths, and R package compilation not verified.
- **Exact bootstrap reproducibility:** With `set.seed(42)`, bootstrap results should be reproducible on the same platform. Cross-platform reproducibility of R's RNG was not tested.
- **Citation accuracy:** Paper citations (Vardi 2012, Manzello 2025, Baums 2005, etc.) were not verified against the actual papers. NotebookLM/Zotero verification was not performed.
- **Growth data quality:** Growth model diagnostics were not audited in this pass (focus was on survival and meta-analysis).
- **Advanced dynamic models (scripts 41-47):** These are labeled exploratory and not in the manuscript. Not audited beyond script 43 (stochastic IPM).
- **RSE model parameter consumption:** Whether the RSE model correctly reads the updated parameter format was not tested (requires running the RSE pipeline).
