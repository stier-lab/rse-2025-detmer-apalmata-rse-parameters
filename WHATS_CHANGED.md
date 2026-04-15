# What Changed Since March 26

**For:** Raine Detmer
**Scope:** Everything between your last commit (`cbba177`, March 26) and now — 42 commits across 3 weeks.

---

## Big picture

Three major things happened:

1. **Neely et al. 2022** was integrated (878 FL Keys colonies, 2010-2016). This is the largest new dataset since NOAA, and it includes the 2014 thermal bleaching catastrophe. The expanded meta-analysis is now k=17 studies, 22 effects.

2. **We solved the sample-size problem you flagged.** Your April 7 question — "how do we weight proportions from studies with very different sample sizes?" — led to three rounds of methodology work. The final answer: study-level random-effects meta-analysis (`metafor::rma()` per size class), matching the approach in script 14b. This treats each study as the unit of analysis instead of treating individual cells as independent observations.

3. **FUNDEMAR recruit data is now properly classified and packaged.** The ~16,700 microscopic post-settlement recruits from FUNDEMAR, Chamberland, and Mendoza-Quiroz are classified as "Restoration recruit" — excluded from the natural-colony transition matrix but available as `recruit_surv_pars.rds` with a ready-to-use `s_recruit` parameter for the RSE model.

---

## The sample-size weighting story

This started with your observation (April 7 meeting) that combining individual and summary survival data was not straightforward — a NOAA plot-year with n=50 was being treated the same as a summary record with n=200.

Your framing: *"In meta-analysis you would weight the effect size by the variance... so my gut feeling is to consider doing something like that."*

Here's what happened when we followed that through:

| Round | Method | Lambda | Problem |
|-------|--------|--------|---------|
| Before | Individual-level only, 3 studies | 0.986 | Ignores 10 summary-level studies entirely |
| Round 1 (Apr 7) | Cell-level, sample-size weighted | 0.959 | Doesn't account for between-study heterogeneity |
| Round 2 (Apr 8) | Cell-level, logit IV weighted | 0.888 | **Biased** — 32% of NOAA cells had n=1; logit transform upweights rare mortality |
| **Final (Apr 14)** | **Study-level rma() per SC** | **0.961** | Treats studies as unit of analysis; matches script 14b methodology |

The key insight: cell-level inverse-variance weighting treats each (study x size_class x interval) cell as an independent study. But many NOAA cells have n=1 — a single colony's fate treated as a study-level effect. This gave cells where a single large colony died enormous weight (high precision on logit scale near p=0), pulling SC5 survival from 0.948 down to 0.873 even though all three studies that measured SC5 agreed on ~0.94-0.95.

The fix: aggregate cells to study-level first, then let `rma()` pool the studies with proper between-study heterogeneity estimation. Full analysis in `07_reporting/methodology_critique_2026-04-14.md`.

---

## How FUNDEMAR data is integrated

The FUNDEMAR data exists in three forms in this repo, each serving a different purpose:

### 1. FUNDEMAR fragments → nursery survival parameters

44 nursery fragment observations from FUNDEMAR are classified as `population_type = "Restoration fragment"`. These flow into `nurs_surv_pars.rds` alongside 10 other restoration studies (11 studies total, N=3,277). These are SC1-SC2 sized fragments with moderate survival.

**Where:** `parameter_lists/nurs_surv_pars.rds` — used by RSE model's nursery module.

### 2. FUNDEMAR recruits → separate recruit parameter file

14,271 microscopic post-settlement recruits (~0.006 cm², SC1) from FUNDEMAR, plus 660 from Chamberland and 1,548 from Mendoza-Quiroz, are classified as `population_type = "Restoration recruit"`. These represent a fundamentally different life stage from nursery fragments — they're settlers on tiles/substrates with very low survival (~1% raw, 2.8% annualized).

**Where:** `parameter_lists/recruit_surv_pars.rds` — new file with:
- `s_recruit = 0.028` (annualized, 95% CI: 0.009-0.104)
- Full 1000-iteration bootstrap distribution
- Fecundity decomposition example (1000 larvae x 15% settlement x 2.8% s_recruit = 4.2 net recruits/adult/yr)
- Comparison to RSE model's current `s1 = 0.70` (for nursery fragments — 25x higher because fragments are much larger)

**NOT in:** the natural-colony transition matrix, the field survival parameters, or the expanded meta-analysis.

### 3. What's NOT included

FUNDEMAR data does NOT enter:
- `field_surv_pars.rds` (natural colonies only, from script 13's rma)
- The Lefkovitch transition matrix (script 13)
- The expanded meta-analysis (script 14b) — those use only natural-colony and restoration-fragment survival at the study level

### Classification logic

The `population_type` assignment is in script 01, Section 8b. The rules:

```
"Natural colony"       ← fragment == "N" AND not a known restoration/lab study
"Restoration fragment" ← fragment == "Y" OR known nursery/outplant study
"Restoration recruit"  ← lab data (data_type == "lab") OR known recruit studies
                         (FUNDEMAR recruits, Chamberland, Mendoza-Quiroz lab)
```

**Decision you should review:** Is this classification right for all studies? Especially Garrison & Ward 2008 (has both natural and relocated groups — currently split into two effects in the meta-analysis).

---

## What changed in the code

### New outputs from script 13

Script 13 now saves two new files:
- `survival_bootstrap_by_sc.rds` — 2000 x 5 matrix of per-size-class survival from each bootstrap iteration. Script 17 reads this for field parameters.
- Updated `transition_matrix.rds` — includes `survival_bootstrap_by_sc` and `survival_by_class` (rma point estimates with I², tau²)

### Script 17 field survival reads from script 13

Script 17 no longer computes field survival independently. It reads `survival_bootstrap_by_sc.rds` and reformats for the RSE model. This means:
- Field survival in the RSE model is **identical** to the transition matrix
- The `bootstrap_survival_cells()` function still exists but is used only for nursery survival
- Bootstrap iterations went from 1000 to 2000 for field survival

### Fecundity sensitivity now uses actual recruit survival

Script 13's fecundity analysis now includes a data-informed decomposition: given the actual s_recruit (0.028), how many larvae per adult are needed for lambda > 1? This connects the recruit data back to the population model even though fecundity is zero in the base case.

### Script 01 produces `prepared_survival_cells.rds`

New cell-level dataset (Section 8b) that:
- Aggregates individual data to (study x size_class x interval) cells
- Assigns size classes to summary records
- Stacks everything with sample sizes, proportions, and `population_type`
- This is the input for script 13's rma() and script 17's nursery bootstrap

---

## Everything else that changed (March 26 → April 15)

### New data
- **Neely et al. 2022**: 878 FL Keys colonies (2010-2016), including 2014 thermal bleaching catastrophe
- **3 new summary studies** from expanded literature search: Rogers 1982, Rogers & Muller 2012, Ramos-Romero et al. 2025
- **2 studies removed**: Muller et al. 2008 (imprecise), Sutherland et al. 2016 (NOAA overlap)
- **Caribbean disturbance database**: 93 curated events, 13 regions, IBTrACS hurricane exposure (208 storms)
- **NOAA CRW DHW overlay**: Degree Heating Weeks for all 175 site-years

### Repo organization
- `05_data/ai_extracted/` renamed to `05_data/expanded_search/`
- PRISMA-compliant directory structure (01-07)
- Formal database searches documented (PubMed, WoS, Google Scholar, ~2,518 records)
- Inter-rater reliability assessment (71% agreement, kappa=-0.148 due to skew)

### New scripts
- 30-40: Disturbance analysis suite (heat stress, hurricanes, size-disturbance interaction)
- 41-47: Advanced dynamic models (stochastic IPM, regime-switching, etc.) — exploratory, not in manuscript
- 48: Pipeline refresh audit
- 49-50: Temporal synthesis figures

### Documentation
- `WHATS_CHANGED.md` — this file
- `parameter_lists/RSE_COMPATIBILITY.md` — documents dual parameter format for RSE model
- `04_extraction/data_integration_issues.md` — the sample-size weighting analysis
- `04_extraction/data_flow_diagram.md` — mermaid diagram of full pipeline
- `07_reporting/methodology_critique_2026-04-14.md` — statistical review of the rma fix

---

## Current key numbers

| Metric | Value |
|--------|-------|
| Lambda (deterministic) | 0.961 |
| Lambda 95% CI | [0.816, 1.010] |
| P(decline) | 94.3% |
| SC5 stasis elasticity | 58.9% |
| Meta-analysis | k=17, 22 effects, pooled survival 78.0%, I²=97.2% |
| LOSO lambda range | 0.882-0.993 |
| s_recruit (FUNDEMAR etc.) | 0.028 (annualized) |
| Fragmentation contribution | 7.2% of lambda |

---

## What you need to do in the RSE repo

### 1. Pull and re-run

Pull `codex-pipeline-refresh-automation`. The parameter files in `parameter_lists/` are updated. Re-run RSE scenarios — field survival shifts slightly, bootstrap distributions now have 2000 samples.

### 2. Consider `recruit_surv_pars.rds`

For recruit-based restoration scenarios, `s_recruit` is available as a new parameter alongside `s0` and `s1`:

| Parameter | Value | What it represents |
|-----------|-------|--------------------|
| `s0` | 0.95 (hardcoded) | Lab survival, settlement to outplant-ready |
| `s1` | 0.70 (hardcoded) | Post-outplant 1st year, nursery fragments (SC2-sized) |
| `s_recruit` | 0.028 (data-derived) | Post-settlement recruit survival on reef (~0.006 cm²) |

The 25x difference between `s1` and `s_recruit` reflects the size-survival relationship — larger fragments survive dramatically better than microscopic settlers.

### 3. Housekeeping

- `rse_sensitivity.rmd` has hardcoded paths to `/Users/rainedetmer/Desktop/...`
- QUICK_START.md documents wrong size class boundaries (1-20, 20-100 vs 0-10, 10-100)
- `standardized_data/` symlink works but paths should be `05_data/standardized/`

---

## Decisions for you to review

1. **Population type classification** — FUNDEMAR recruits as "Restoration recruit", Chamberland as "Restoration recruit". Right? (Script 01, Section 8b)
2. **Study-level rma()** — matches script 14b methodology. Alternatives in `07_reporting/methodology_critique_2026-04-14.md`
3. **Neely 2014 in primary analysis** — disturbance intervals flagged but included. LOSO shows removing Neely → lambda = 0.993
4. **Fragmentation SC1 split** — 10%/90% by range width (from your working notes)
5. **Zero fecundity baseline** — fecundity sensitivity now uses actual s_recruit data

---

## Where to find things

| Question | File |
|----------|------|
| How does data flow through the pipeline? | `04_extraction/data_flow_diagram.md` |
| How did we solve the sample-size problem? | `04_extraction/data_integration_issues.md` |
| Why did lambda go 0.986 → 0.888 → 0.961? | `07_reporting/methodology_critique_2026-04-14.md` |
| What does the RSE model need from this repo? | `parameter_lists/RSE_COMPATIBILITY.md` |
| Per-study extraction decisions | `04_extraction/extraction_protocol.md` |
| Your original working notes | `04_extraction/raine_working_notes/` (unchanged) |
| How is FUNDEMAR classified? | Script 01 Section 8b (`population_type` logic) |
| What went into the recruit parameter? | `parameter_lists/recruit_surv_pars.rds` (see `$note`, `$comparison`) |
