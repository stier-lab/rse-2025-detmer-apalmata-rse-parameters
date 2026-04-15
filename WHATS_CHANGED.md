# What Changed (April 7-15, 2026)

**For:** Raine Detmer
**Context:** After our April 7 meeting where you flagged the data integration issues, I worked through the full implications. This document summarizes everything that changed, why, and what you need to know for the RSE model.

---

## The short version

Your instinct about the data integration was right — the way we were combining individual and summary data mattered more than we expected. Working through it properly led to three rounds of methodology changes:

1. **Cell-level weighted** (your option 2, implemented April 7): lambda = 0.959
2. **Cell-level logit IV** (meta-analytic standard, April 8): lambda = 0.888 — but this turned out to be biased
3. **Study-level rma() per size class** (final, April 14): **lambda = 0.961**

The final approach uses `metafor::rma()` per size class, treating each study as the unit of analysis — the same methodology as the expanded meta-analysis in script 14b. Lambda = 0.961 matches Vardi 2012's mean-matrix lambda (0.96) closely.

---

## What changed in the code

### Script 13 (transition matrix) — methodology change

**Before:** Survival computed from individual-level data only (3 studies, sample-size weighted).

**Now:** Survival computed via study-level random-effects meta-analysis. Cells from `prepared_survival_cells.rds` are aggregated to (study x size_class) effects, then pooled via `rma(measure="PLO", method="REML")` per size class.

| Size class | Before (ind-only) | Now (rma) |
|---|---|---|
| SC1 | 0.612 | 0.507 |
| SC2 | 0.676 | 0.731 |
| SC3 | 0.777 | 0.786 |
| SC4 | 0.884 | 0.881 |
| SC5 | 0.944 | 0.948 |
| **Lambda** | **0.986** | **0.961** |
| **95% CI** | [0.876, 1.005] | **[0.816, 1.010]** |
| **P(decline)** | — | **94.3%** |

The bootstrap (2000 iterations) also uses rma(): resample studies → resample cells within studies → re-aggregate to study-level → re-fit rma() per iteration.

### Script 17 (parameter lists) — field survival now reads from script 13

**Before:** Script 17 independently computed field survival using `bootstrap_survival_cells()` (cell-level logit IV).

**Now:** Script 17 reads `survival_bootstrap_by_sc.rds` (the per-SC bootstrap matrix from script 13). This ensures the RSE model uses **identical** survival estimates as the transition matrix.

Nursery and lab parameters are unchanged — still computed independently by script 17.

### New file: `recruit_surv_pars.rds`

The FUNDEMAR, Chamberland, and Mendoza-Quiroz restoration recruit data (16,479 microscopic post-settlement recruits) is now packaged in `parameter_lists/recruit_surv_pars.rds`. This includes:

- **`s_recruit = 0.028`** (annualized, 95% CI: 0.009-0.104) — a drop-in alternative to the RSE model's `s1` for recruit-based restoration scenarios
- Full bootstrap distribution (1000 iterations)
- Fecundity decomposition: if an adult produces 1000 larvae with 15% settlement and 2.8% recruit survival, net fecundity = 4.2 recruits/adult/yr

**Important:** `s_recruit` is for microscopic settlers (~0.006 cm²). The RSE model's `s1 = 0.70` is for nursery fragments (SC2-sized). The 25x difference reflects the size-survival relationship. You'd want a separate parameter or a size-dependent s1, not a direct replacement.

### Script 01 (data preparation) — new cell-level dataset

`prepared_survival_cells.rds` is a new output that combines individual and summary survival data at the cell level (study x size_class x interval). Each cell has sample size, proportion survived, and population_type classification. This is what feeds into script 13's rma() and script 17's nursery bootstrap.

---

## What changed in files/directories

| Change | Details |
|--------|---------|
| `05_data/ai_extracted/` | Renamed to `05_data/expanded_search/` |
| `parameter_lists/recruit_surv_pars.rds` | New file (restoration recruit survival for RSE) |
| `06_analysis/output/survival_bootstrap_by_sc.rds` | New file (script 13 → script 17 bridge) |
| `07_reporting/methodology_critique_2026-04-14.md` | Documents why logit IV was biased and the rma() fix |
| `04_extraction/data_integration_issues.md` | Updated with lambda comparison table (all 4 approaches) |
| `04_extraction/data_flow_diagram.md` | Updated mermaid diagram |

---

## What you need to do in the RSE repo

### 1. Re-run with new parameters

The parameter files in `parameter_lists/` are updated. After pulling this branch, re-run your RSE scenarios. Expected changes:
- Field survival is slightly different from the old individual-only estimates (most SCs within 1-2 pp)
- Lambda is now 0.961 vs 0.986 — restoration effectiveness comparisons may shift
- Bootstrap distributions now have 2000 samples instead of 1000 for field survival

### 2. Consider using `recruit_surv_pars.rds`

If you want to model recruit-based restoration (larval propagation), `s_recruit` is available. You might add it as a new parameter in the RSE model alongside `s0` and `s1`:
- `s0` = lab survival (settlement to outplant-ready): 0.95
- `s1` = post-outplant survival for nursery fragments: 0.70
- `s_recruit` = post-settlement recruit survival on reef: 0.028

### 3. Update QUICK_START.md

The RSE repo's QUICK_START.md still documents the old size class boundaries (1-20, 20-100, etc.). The correct boundaries are 0-10, 10-100, 100-900, 900-4000, >4000 cm².

### 4. Remove hardcoded paths

`rse_sensitivity.rmd` has paths to `/Users/rainedetmer/Desktop/...`. These should be relative.

---

## Decisions I made that you should review

These are judgment calls I made while working through the analysis. If any feel wrong, we can revisit:

1. **Population type classification.** I classified FUNDEMAR recruits and Chamberland lab data as "Restoration recruit" (not "Natural colony"). This means they're excluded from the transition matrix but available via `recruit_surv_pars.rds`. The classification rules are in script 01, Section 8b.

2. **Study-level rma() as the methodology.** This treats each study as the unit of analysis and pools via random-effects meta-analysis. The alternative (cell-level logit IV) was biased because 32% of NOAA cells had n=1. See `07_reporting/methodology_critique_2026-04-14.md` for the full analysis.

3. **Fragmentation SC1 split rule.** Fragments from SC4/SC5 breakage that land in SC1 vs SC2 are split by range width (10% to SC1, 90% to SC2). This was flagged in your working notes and is documented in `04_extraction/extraction_details.md`.

4. **Neely 2014 disturbance intervals** are included in the primary analysis (not excluded). LOSO shows removing Neely shifts lambda to 0.993. This is consistent with our April 7 discussion about including all data and being transparent.

5. **Zero fecundity remains the baseline.** The fecundity sensitivity analysis now includes a data-informed decomposition using actual recruit survival, but the base model still has F=0.

---

## Questions for our next meeting

1. Does the population_type classification look right? Especially: should Garrison & Ward 2008 restoration fragments be in nursery or field?
2. Should we run an rma()-based approach for nursery survival too (11 studies, 140 cells), or is the cell-level bootstrap fine?
3. For the RSE model: is `s_recruit` useful as-is, or do you need it decomposed differently?
4. The methodology critique recommends a mortality-definition sensitivity analysis (NOAA conservative vs Kuffner aggressive). Is that worth doing before submission?

---

## Where to find things

| Question | File |
|----------|------|
| Why did lambda change? | `07_reporting/methodology_critique_2026-04-14.md` |
| How does data flow through the pipeline? | `04_extraction/data_flow_diagram.md` |
| What survival values does each approach give? | `04_extraction/data_integration_issues.md` (Lambda comparison table) |
| What does the RSE model need? | `parameter_lists/RSE_COMPATIBILITY.md` |
| Per-study extraction decisions | `04_extraction/extraction_protocol.md` |
| Your original working notes | `04_extraction/raine_working_notes/` (unchanged) |
