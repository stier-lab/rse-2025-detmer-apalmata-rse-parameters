# Data Integration Issues — Individual vs. Summarized Survival

**Flagged by:** Raine Detmer (1-on-1 meeting, 2026-04-07)
**Source:** `raine_working_notes/2026-04-07_APAL_data_integration_issues.pdf`
**Status:** Implemented (2026-04-07) — cell-level sample-size weighting in scripts 01, 13, 17

---

## Background

The synthesis combines two qualitatively different kinds of survival data, and how we splice them together affects every downstream parameter, the transition matrix, and the RSE model parameter sets.

| Data type | What we have per record | Studies |
|---|---|---|
| **Individual (Tier 1)** | Initial size + 0/1 fate over an interval | NOAA, Neely 2022, Pausch, USGS USVI, Kuffner, Mendoza-Quiroz, FUNDEMAR |
| **Summarized (Tier 2)** | Size *range* + N initial + proportion surviving | 10 additional studies (e.g., Vardi, Garrison subsets, others contributing to k=17 / 22 effects) |

The summary data is currently in `05_data/standardized/apal_surv_summ.csv` and `apal_growth_summ.csv`. The naming is a known source of confusion — "summarized" can read as "rolled-up version of the individual data," but it actually means *a different set of studies that only ever reported aggregates*.

---

## Issue 1 — The current "draw individuals from proportions" workflow has two flaws

Raine's existing pipeline (in her own model parameter scripts; see PDF page 2, "option 1 (current)") integrates the two streams as follows:

```
Summarized prop. surviving  ──┐
       │                      │ random draw of sizes within range
       │                      │ random draw of survival fates
       ▼                      ▼
Estimated individual data (multiple replicates)
       │
       ▼
Combined with real individual data
       │
       │ randomly draw n=20 individuals per model size class
       │ calculate proportion that survived
       │ repeat 100 times
       ▼
Parameter sets for the population model
```

**Two problems with this approach:**

1. **Size-class span uncertainty.** When the size range reported in a summary record straddles two or more model size classes (e.g., a study reports 0–50 cm² but our SC1 is 0–10 and SC2 is 10–100), the random draw arbitrarily assigns survivors and dead colonies to size classes. Survival is then attributed to whichever class the random draw happened to land in, which is not what the original study measured.

2. **Sample-size mismatch (small *n* propagated as a model parameter applied to large *N*).** Drawing only n = 20 individuals to estimate a survival proportion produces excess zeros for size classes where true survival is low but realistic outplant cohorts are large. Example: FUNDEMAR outplants ~10,000 baby corals with ~3% survival. With true *N* = 10,000, you essentially never see complete-zero survival; with random draws of n = 20 from a 3% probability, complete zeros are common and dominate the parameter set. The model then bifurcates between "extinction" trajectories driven by these spurious zeros and trajectories where any survival occurs at all. This is a binomial sampling-variance artifact, not a biological signal.

The mismatch is asymmetric across size classes: large-colony classes really do have small sample sizes, so n = 20 is appropriate; small-colony classes have large outplant cohorts, so n = 20 dramatically inflates parameter variance.

---

## Issue 2 — (RESOLVED) Summary data was previously orphaned from the parameter pipeline

I checked the scripts in `06_analysis/scripts/`:

| Script | Reads summary data? | What it does with it |
|---|---|---|
| `01_data_preparation.R` | Reads `apal_surv_summ.csv` (line 187) | **Only reports row counts.** Does not merge into `prepared_survival_data.rds`. |
| `07_integrate_summary_data.R` | Yes — full processing | Produces `survival_by_study_combined.csv`, `growth_by_study_combined.csv`, `regional_estimates_combined.csv`, `summary_data_contribution.csv`, `fragment_survival_summary.csv`, `data_source_overlap.csv`, `size_class_reliability.csv`. **No downstream script reads any of these outputs** (verified by repo-wide grep). |
| `13_transition_matrix.R` | No — reads only `prepared_survival_data.rds` | Builds the Lefkovitch matrix from individual-level data only. |
| `17_update_parameter_lists.R` | No — reads only `prepared_survival_data.rds`, `prepared_growth_data.rds`, `survival_thresholds.csv`, `growth_thresholds.csv`, `transition_matrix.rds` | Writes `parameter_lists/{field,nurs,lab}_{surv,growth}_pars.rds` for the RSE model. **Sees no summary data.** |

**Conclusion.** The summarized studies in this repo currently feed into descriptive forest plots and regional contribution counts only. They do **not** flow into the transition matrix, the elasticity analysis, the bootstrap λ, or the RSE model parameter sets. The "option 1 (current)" workflow Raine drew in her PDF lives in her own scripts (likely in the coral-platform / RSE repo), not here.

This explained the `pct_summary` column in `summary_data_contribution.csv` and the fact that script 07 was previously a dead end as far as the population model was concerned. **This issue has been resolved:** summary data is now integrated via cell-level stacking with sample-size weights in `prepared_survival_cells.rds` (Script 01), which feeds into the transition matrix (Script 13) and parameter estimation (Script 17).

A separate (smaller) inconsistency: script 07 uses size cutoffs of 25 / 100 / 500 / 2000 cm² to bin summary records (lines 154–161), which do **not** match the canonical `SIZE_BREAKS = c(0, 10, 100, 900, 4000, Inf)` from `00c_analysis_constants.R`. Even where summary data is binned for forest plots, it's binned into a different size-class definition than the rest of the pipeline.

---

## Issue 3 — Option 2 (proportion-only pipeline) has its own problem

Raine's alternative (PDF page 3) flips the direction: convert individual data into proportions by location/year/size class, then combine with already-proportional summary data, then resample rows.

**Problem:** The sample sizes underlying the proportions vary by 2–3 orders of magnitude across studies. A NOAA plot-year with n = 50 and 50 % survival is treated identically to a NOAA plot-year with n = 2 and 100 % survival. Bare row resampling does not respect this.

This is a different shape of the same fundamental issue: sample-size variation is real and has to be propagated, regardless of which direction we flow the data.

---

## Agreed direction (2026-04-07 meeting)

**Sample-size / variance weighting, meta-analysis style.** Adrian's gut call:

> "In meta-analysis you would weight the effect size by the variance… so my gut feeling is to consider doing something like that so that you include all the data but that it's weighted somehow in proportion to sample size or and/or variance."

Practical translation:
- Move toward Raine's option 2 (proportion-of-survival pipeline), where each row is `(study, location/year, size_class, prop_surviving, n)`.
- Compute parameter sets by weighted resampling (or by directly using inverse-variance weights), where `var_i = p_i (1 - p_i) / n_i` for binomial proportions.
- A study-year with n = 100 and 50 % survival contributes substantially more to the parameter than a study-year with n = 2 and 100 % survival.
- This keeps **all** the data (no sacrifice of small studies) while preventing tiny-*n* records from punching above their weight.

Adrian's framing: "I think it's good to be inclusive if we can as long as we're honest about it and transparent."

Raine's reaction: "I like that idea. And it seems easy to explain to when writing down methods."

### Open implementation questions

1. **What level of aggregation for individual data?** Some NOAA plot-years have n ≈ 50 (fine to use as-is); others have n = 2 (too noisy on its own). Options:
   - Fixed minimum n (e.g., drop any plot-year-size-class cell with n < 10) — sacrifices data.
   - Aggregate at a coarser unit (region × year rather than plot × year) when local n is small.
   - Use the weighting itself to handle this — keep the n = 2 cells, but their inverse-variance weight is so small that they don't move the answer.

2. **What variance to weight by?** Binomial `p(1-p)/n` is the obvious choice for survival. For comparability with `metafor::rma()` we could use `escalc(measure = "PLO", ...)` (logit-transformed proportions), which is what `14b_expanded_meta_analysis.R` already uses for the meta-analysis.

3. **Do we wire this into *this* repo or only the RSE / coral-platform repo?** Currently the parameter pipeline that matters for the RSE model lives outside this repo. If we want the transition matrix in `13_transition_matrix.R` and the RSE parameter lists in `17_update_parameter_lists.R` to use the weighted approach too, we need to (a) merge the summary data into `prepared_survival_data.rds` upstream or (b) build a new "weighted parameter set" pathway.

4. **Sensitivity check.** Adrian's prediction: "I suspect if we weight versus drop, it'll probably give us similar answers just because the data so it dominates things so much." Worth coding both and confirming.

---

## Implementation (2026-04-07)

### What was built

| Script | Change |
|---|---|
| `01_data_preparation.R` | New Section 8b: aggregates individual data to (study × size_class × time_interval_yr) cells, assigns size classes to summary records using canonical `SIZE_BREAKS`, stacks into `prepared_survival_cells.rds` with `data_source` flag, sample size, and inverse-variance weights (logit scale). |
| `13_transition_matrix.R` | Section 3: survival rates now computed from cell-weighted data (natural colonies, 1,302 cells from 7 studies, N=23,644). Section 9: bootstrap resamples cells within studies instead of individual colonies. |
| `17_update_parameter_lists.R` | Field and nursery survival parameters now computed from cell-weighted data via `bootstrap_survival_cells()`. Growth remains individual-level. |

### What was NOT changed

- `prepared_survival_data.rds` — schema unchanged, still 7,346 individual records. Used by 40+ scripts.
- `07_integrate_summary_data.R` — still exists for diagnostic forest plots. Size-class bin mismatch with canonical `SIZE_BREAKS` flagged but not yet fixed.
- `14b_expanded_meta_analysis.R` — independent meta-analytic pipeline, already uses `escalc(measure="PLO")`. Not modified.

### Key numbers

- Total cells: 1,442 (1,166 individual + 276 summary) from 16 studies, N=26,921
- Natural colony cells (for script 13): 1,086 (1,065 individual + 21 summary) from 5 studies, N=7,165
- Restoration studies properly classified: fundemar_recruits, chamberland (both lab and field rows), mendoza_quiroz (lab) now "Restoration recruit" — not in the natural-colony matrix
- 30 summary cells have size ranges spanning multiple size classes (flagged via `size_range_spans_classes` column)
- Nursery/restoration parameters (script 17): 140 cells from 11 studies, N=3,277

### Survival comparison (individual-only vs cell-weighted, natural colonies)

| Size class | Individual-only (old) | Cell-weighted (new) | Delta | New studies |
|---|---|---|---|---|
| SC1 | 0.612 | 0.524 | -0.088 | +0 (cell-level aggregation changes weighting) |
| SC2 | 0.676 | 0.662 | -0.014 | +1 |
| SC3 | 0.777 | 0.773 | -0.004 | +2 |
| SC4 | 0.884 | 0.883 | -0.002 | +1 |
| SC5 | 0.944 | 0.949 | +0.005 | same |

SC1 shifted modestly because cell-level aggregation weights NOAA plot-years by sample size rather than treating all colonies as exchangeable. SC2-SC5 barely moved, confirming Adrian's prediction. Note: Chamberland et al. 2015 (larval settlement study) was reclassified from "Natural colony" to "Restoration recruit" during audit — settlement/outplant studies are not wild natural colonies.

### Lambda comparison

| Metric | Individual-only (old) | Cell-weighted, sample-size | Cell-weighted, logit IV (current) |
|---|---|---|---|
| Deterministic λ | 0.986 | 0.959 | 0.888 |
| 95% Bootstrap CI | [0.876, 1.005] | [0.801, 1.012] | [0.740, 0.959] |
| Survival studies in bootstrap | 3 | 5 | 5 |

### Diagram

See `04_extraction/data_flow_diagram.md` for the full mermaid diagram of the data pipeline.

### Still open

- [ ] Adrian: reach out to Jason at Mote and Florida Fish & Wildlife re: additional individual-level data referenced in Manzello et al. 2025
- [ ] Fix script 07 size-class bins to match canonical `SIZE_BREAKS`
- [x] Sensitivity comparison: individual-only vs cell-weighted λ (see comparison tables above)
- [ ] Raine: review the code changes and verify they match her expectations
- [ ] Both: revisit at next meeting

---

## Related files

- `04_extraction/raine_working_notes/2026-04-07_APAL_data_integration_issues.pdf` — original PDF Raine sent
- `04_extraction/data_flow_diagram.md` — mermaid diagram of the full data pipeline
- `04_extraction/raine_working_notes/Detmer_APAL_meta_analysis_notes.docx` — Raine's per-study extraction notes (assumptions, sample-size estimation from histograms, etc.)
- `04_extraction/extraction_protocol.md` — broader extraction methodology (size conversion rules, inclusion/exclusion criteria)
- `04_extraction/extraction_details.md` — per-study verification table with assumptions and audit status
- `04_extraction/study_characteristics.md` — per-study characteristics and key caveats
- `04_extraction/risk_of_bias.md` — Newcastle-Ottawa bias assessment per study
- `04_extraction/disturbance_handling_decision.md` — disturbance classification and inclusion rules
- `04_extraction/neely_2022_data_integration.md` — Neely et al. 2022 integration notes
- `06_analysis/scripts/07_integrate_summary_data.R` — diagnostic integration code (summary data now integrated via cell-level approach in Script 01)
- `06_analysis/scripts/14b_expanded_meta_analysis.R` — already does inverse-variance weighting on logit-transformed proportions; methodologically aligned with the cell-level approach
