# RSE Model Compatibility Notes

**Updated:** 2026-04-14
**RSE repo:** `Detmer-2025-coral-RSE`

---

## Parameter Format

The parameter RDS files now include **both** the new analysis format and the RSE-compatible format:

### Survival parameters (`field_surv_pars.rds`, `nurs_surv_pars.rds`)

| Element | Format | Consumer |
|---------|--------|----------|
| `$SC_surv_results` | Named list of 5 (mean, sd, ci, bootstrap_dist) | This repo (scripts 13, 17) |
| `$surv_summary` | Tibble with character size_class ("SC1"-"SC5") | This repo |
| `$SC_surv_summ_df` | Data.frame with integer size_class (1-5), Q05/Q25/Q50/Q75/Q95 | **RSE model** (`default_pars_fun`) |
| `$SC_surv_df` | Data.frame with prop_survived, size_class (int), replicate | **RSE model** (`rand_pars_fun`) |

### Growth parameters (`field_growth_pars.rds`, `nurs_growth_pars.rds`)

| Element | Format | Consumer |
|---------|--------|----------|
| `$growth_trans_df` | Long tibble (from_class, to_class, prob, replicate) | This repo |
| `$trans_summary` | Summary tibble (from_class, to_class, mean_prob, Q05, Q95) | This repo |
| `$summ_list` | List of 5 data.frames (one per from-class, rows=to-classes, cols=mean/Q05/Q95) | **RSE model** (`default_pars_fun`) |
| `$mat_list` | List of 5 data.frames (rows=bootstrap replicates, cols=to-class probs) | **RSE model** (`rand_pars_fun`) |

---

## Path Compatibility

A symlink `standardized_data/ -> 05_data/standardized/` exists at the repo root for backward compatibility with RSE scripts that reference `standardized_data/`.

---

## Key Parameter Changes (April 2026)

The following changes affect RSE model outputs:

### 1. Survival estimates shifted (study-level rma)

| Size class | Old (individual-only) | New (study-level rma, REML) |
|------------|----------------------|-------------------------------|
| SC1 | 0.61 | 0.51 |
| SC2 | 0.68 | 0.73 |
| SC3 | 0.78 | 0.79 |
| SC4 | 0.88 | 0.88 |
| SC5 | 0.94 | 0.95 |

**Why:** Switched from individual-level sample-size weighting to study-level random-effects meta-analysis (`metafor::rma()` per size class with REML estimation). Cells are first aggregated to (study × size_class) effects, then pooled via rma(). This treats studies as the unit of analysis and avoids the n=1 cell pathology of the earlier logit IV approach. Summary-level data from 10 more studies is integrated via cell-level aggregation.

**Impact on RSE:** Lambda shifted from 0.986 to 0.961 in the deterministic Lefkovitch matrix. SC2-SC5 survival is similar to the old individual-only estimates; SC1 is lower due to proper weighting of small studies.

**Parameter pipeline (2026-04-15):** Field survival parameters now flow directly from script 13's rma() bootstrap output (`survival_bootstrap_by_sc.rds`), ensuring the RSE model uses identical survival estimates as the transition matrix. Script 17 no longer independently computes field survival — it reads and reformats script 13's results. Nursery and lab parameters are still computed independently by script 17.

### 2. Field parameters now represent natural colonies only

Script 17 now filters field survival to `population_type == "Natural colony"` (matching script 13's transition matrix). Previously, field parameters included all data types. Restoration fragments and recruits go to nursery parameters instead.

### 3. Nursery parameters expanded

Nursery survival now uses cell-weighted data from 11 studies (N=3,277), including summary-level restoration studies that were previously orphaned from the pipeline.

### 4. SC1 recruit data — now available as `recruit_surv_pars.rds`

~16,700 restoration recruit observations (FUNDEMAR, Chamberland, Mendoza-Quiroz) exist in `prepared_survival_cells.rds` classified as "Restoration recruit". These are microscopic post-settlement recruits (~0.006 cm², ~1% raw survival) representing a fundamentally different life stage from nursery fragments.

These are now packaged separately in `recruit_surv_pars.rds` with:
- Annualized survival: **2.8%** (95% CI: 0.9%-10.4%) from 3 studies, N=16,479
- 1000-iteration hierarchical bootstrap distribution (field survival uses 2000 iterations from script 13's rma() bootstrap)
- Per-study breakdown and summary statistics

**NOT used** in this repo's transition matrix or natural-colony analyses. Available for the RSE model's lab/early-life module. Note that the RSE model currently uses hardcoded `s1 = 0.70` for post-outplant survival — that applies to larger nursery fragments, not microscopic recruits. The recruit data would need a separate parameter (e.g., `s_recruit`) or a size-dependent s1.

---

## RSE Repo Status

Already fixed (pushed to RSE main, April 15):

1. ~~**Path references**~~: `standardized_data/` → `05_data/standardized/` in 4 Rmd files
2. ~~**Hardcoded paths**~~: 9 `/Users/rainedetmer/Desktop/...` paths replaced with relative `DATA_PATH` in `rse_sensitivity.rmd`
3. ~~**QUICK_START.md**~~: Size class boundaries corrected to 0-10/10-100/100-900/900-4000/>4000

Still needed:

4. **Re-run all scenarios**: Field survival values changed (rma-based, 2000 bootstrap samples). Lambda shifted from 0.986 to 0.961. Restoration effectiveness comparisons may shift.
5. **Consider `recruit_surv_pars.rds`**: The new `s_recruit = 0.028` parameter is available for recruit-based restoration scenarios. It's a potential alternative to or supplement for the hardcoded `s1 = 0.70` (which applies to nursery fragments, not microscopic settlers).
6. **Consider whether lab survival parameters need updating**: The RSE model uses hardcoded `lab_pars$s0 = 0.95` and `lab_pars$s1 = 0.70`. The synthesis repo has `apal_surv_lab_short.csv` (6 rows, 4-30 day intervals) but these are too short-term to directly inform annual lab survival. The current hardcoded values may still be the best available estimates.

---

## Biological-Realism Scenario Framework (April 2026)

A 9-scenario sensitivity analysis (S0–S8) layering literature-sourced biological mechanisms onto the baseline matrix is now available as **drop-in inputs for the RSE model**. The main demography synthesis paper uses all nine; Raine's RSE paper will likely select a subset but the full set is exported so that decision can be made downstream.

### Files added

| File | What |
|------|------|
| `parameter_lists/scenario_matrices.rds` | Named list `S0..S8` of trimmed 5×5 Lefkovitch matrices, each with `$matrix`, `$lambda`, `$label`, `$F_sex`, `$survival`. Metadata on size-class breaks in `attr(x, "size_class_breaks")`. |
| `parameter_lists/helpers/qe_projection.R` | Base-R (no dependencies) helper functions for the RSE: `project_trajectory()`, `compute_qe()`, `scenario_qe()`. |

### Scenario menu

| Scenario | Description | Source |
|----------|-------------|--------|
| **S0** Baseline | Current published λ = 0.961 | This synthesis |
| **S1** +Sexual fecundity | Size-threshold F_sex (SC5 fully reproductive ≥4000 cm²) | Vardi 2011 × Mendoza-Quiroz 2023 |
| **S2** +Sterility lag | 4-yr post-disturbance reproductive silence | Lirman 2000a |
| **S3** +Lesion penalty | 20% fecundity penalty for partial-mortality colonies | Piñón-González 2018 |
| **S4** +Outplant age decay | Year-0 survival penalty for restoration cohorts | Boisvert 2024 (A. cervicornis) |
| **S5** +Winter SST | Mild-winter × size disease interaction | Rodriguez-Martinez 2014 |
| **S6** +Depensatory | Low-density SC1/SC2 Allee penalty (snail predation) | Williams 2012 |
| **S7** +Microhabitat (depth) | Depth covariate survival refugia | Ramos-Romero 2025 |
| **S8** All combined | S1 + S3 + S7 (realistic refugia scenario) | Framework |

### Usage from the RSE repo

```r
# Anywhere in RSE scripts (paths relative to the RSE repo root)
source("path/to/Detmer-2025-coral-parameters/parameter_lists/helpers/qe_projection.R")
scenarios <- readRDS("path/to/Detmer-2025-coral-parameters/parameter_lists/scenario_matrices.rds")

# 1. Project baseline 50 years deterministically
traj <- project_trajectory(scenarios$S0$matrix, years = 50)

# 2. Quasi-extinction probability for one scenario
qe <- compute_qe(scenarios$S4$matrix, years = c(20, 50))
# -> c(p20 = 0.97, p50 = 1.00)

# 3. QE table across all 9 scenarios
qe_table <- scenario_qe(scenarios)

# 4. QE for an RSE-specific matrix (e.g. restoration scenario you build)
A_rse <- build_rse_scenario_matrix(inputs)   # your RSE function
qe <- compute_qe(A_rse, years = c(20, 50), init = c(200, 100, 50, 20, 10))
```

### Reproduction of published λ

`scenarios$S0$matrix` reproduces the published λ = 0.961 exactly because script 60 overrides the growth-transition block with the canonical `growth_transitions` from `transition_matrix.rds`. Rebuilding the matrix from current CSVs alone gives λ ≈ 0.982 — use the scenario matrices, not a fresh recompute, to stay anchored to the manuscript's baseline.

### Defaults used in `compute_qe()`

- Initial population: `c(100, 50, 30, 20, 10)` (SC1..SC5, total 210) — matches script 13
- Quasi-extinction threshold: 10% of initial N (= 21 colonies)
- Simulation: 2,000 Poisson-stochastic replicates per scenario
- Captures **demographic** stochasticity only. For **parameter** uncertainty, pass a single bootstrap draw of A from the RSE's resampler into `compute_qe()` and loop externally.

### Calibration notes

- **F_sex** (scenarios S1–S3, S8) uses `SETTLEMENT_EFFICIENCY = 1e-4` to rescale Chamberland 2015 nursery recruit survival (0.028) to wild Caribbean broadcast-spawning rates. This is the only non-literal-from-literature parameter in the framework — mention in RSE Methods if the paper uses F_sex scenarios.
- **Depth** (S7) uses the midpoint of shallow (2 m) and deep (10 m) GLMM predictions.
- **Winter SST** (S5) uses the +1 °C anomaly prediction from a `survival ~ log_size × winter_anomaly + (1|study)` GLMM fit on NOAA ERSST v5 region-year data 1982–2024.
