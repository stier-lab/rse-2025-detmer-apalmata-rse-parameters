# Orientation — Detmer-2025-coral-parameters

_Last updated: 2026-07-21 · branch `codex-pipeline-refresh-automation` · clean tree_

## What this is
Raine Detmer's PRISMA-structured systematic review + meta-analysis of **size-dependent demography in the Caribbean elkhorn coral *Acropora palmata***, targeting *Coral Reefs*. It re-parameterizes a Vardi et al. (2012) 5×5 Lefkovitch projection matrix from ~14,100 individual-level observations (7 studies) plus summary-level data (17 unique studies / 22 study-level effects across 13 Caribbean regions). Headline results: pooled annual survival **0.780 (95% CI 0.701–0.843)** under extreme heterogeneity (**I² = 97.2%**); deterministic **λ = 0.9613** (P(λ<1) = 0.94); baseline quasi-extinction P = 0.82 over 50 yr; every modeled heatwave regime drives near-certain quasi-extinction. This repo is the **empirical parameter source** for the sibling restoration model [Detmer-2025-coral-RSE](https://github.com/stier-lab/Detmer-2025-coral-RSE) (expects this repo cloned at `../Detmer-2025-coral-parameters/`).

## Data
| Dataset | Location | Range / sites | Notes |
|---|---|---|---|
| `05_data/standardized/apal_surv_ind.csv` | in-repo | ~7,842 obs, 7 studies | Individual survival; `disturbance` col flags disease_2014 (639), disease_2014_aftermath (375), storm (571) |
| `apal_growth_ind.csv` | in-repo | ~6,300 obs | Individual growth (AGR + RGR) |
| `apal_surv_summ.csv` / `apal_growth_summ.csv` | in-repo | ~30 / ~20 | Study-level summary rates (Tier 2) |
| `apal_fragmentation.csv` | in-repo | 13 rows | Vardi 2011 only — asexual fecundity F4/F5 by size class |
| `apal_life_history_parameters.csv` | in-repo | ~30 params | Fecundity (oocyte density 63.6/cm², fertilization 95% wild / 15% sibling), maturity threshold 4000 cm², settlement, recruit survival |
| `caribbean_disturbance_events.csv` | in-repo | event-level | Typed events: bleaching 29, disease 31, hurricane 29, cold_snap 1 (region × year) |
| `05_data/original/` | in-repo | 14 raw files | **DO NOT MODIFY** — NOAA, Neely 2022 FKNMS, Kuffner 2020, Fundemar, USGS, Mendoza-Quiroz |
| NOAA = 78% of individual data | — | FL/Curaçao/Navassa | Generalizability caveat — always run LOSO |

## Pipeline (run order — `06_analysis/scripts/`, all wired into `run_all.R`)
1. **01** data prep → cell-level survival backbone (`prepared_survival_cells.rds`)
2. **02–07** core: survival/growth thresholds (GAM+GLMM), growth AGR/RGR, variance partitioning (**size dominates**, R²≈0.09), data gaps, summary integration
3. **08–12** robustness (climate, power, cross-validation, context, model selection) — exploratory/supplementary
4. **13** transition matrix + 2000-iter hierarchical bootstrap λ ← **headline population model**
5. **14 / 14b** meta-analysis: Tier-1 `rma()` (k=6) and expanded three-level `rma.mv()` (k=17, 22 effects) ← **headline meta**
6. **15–17** heterogeneity, sensitivity (LOSO λ 0.882–0.993), parameter-list regeneration
7. **18, 19, 20b, 22** → **Fig 1–4** (main text)
8. **20c, 21, 23–39, 49/49b** → supplementary figs S1–S28 (disturbance, temporal, regional)
9. **40** Manzello heatwave dose-response scenarios (FigS22)
10. **41–47** advanced dynamic models (multistate, joint longitudinal, stochastic IPM, regime-switching, distributed-lag, frailty, spatiotemporal) — **exploratory robustness only**; only 43/44 reach the supplement via FigS28
11. **50–61** biological-realism 10-scenario framework (S0–S9) → **FigS29**
12. **23_verification**, **48** audit; **run_all.R** orchestrates (~60–75 min)

- **Entry point:** `06_analysis/scripts/run_all.R`
- **Headline outputs:** `output/transition_matrix.csv`, `output/population_parameters.csv` (λ=0.9613), `output/expanded_meta_analysis_results.csv` (survival 0.780, I²=97.2%), `output/biological_realism_scenarios.csv`

## Current state
- **Done:** full pipeline runs; 4 main figs + S1–S30 (S27 vacant); expanded meta, heatwave, and 10-scenario biological-realism framework all integrated. Recent commits fixed SC1 survival mean (use rma point estimate), SC5 midpoint, and figure-legend sync.
- **New (2026-07-21):** `37b_disturbance_type_size_interaction.R` → FigS30 — disturbance *type* × size class (storm/disease/heatwave). Finding: storm flattens the size–survival slope (0.39→0.15, p=1e-4), disease is a steep level shift (SC2–SC3 hit hardest), heatwave gradient persists at moderate DHW but compresses at catastrophic. Flags that script 40's size-uniform heatwave pulse is only justified at catastrophic DHW.
- **In progress / open threads (from memory):** RSE parameter reconciliations with Raine — inflation 5.63% vs code 0.056; lab survival s_l 0.98 vs 0.95/0.70; data-integration rework (inverse-variance weighting of summary data).
- **Broken/uncommitted:** none; `output/elasticity_vital_rates.csv` is present but empty (cosmetic). renv reports out-of-sync (non-blocking).

## Key architecture facts for analysis work
- **Density-dependence** exists only on **survival** (SC1–SC2 depensatory corallivory, `apply_density_dep_SC12()`, script 58, Williams 2012). **Fecundity is density-INdependent** — `build_F_sex()` uses a fixed 95% fertilization rate. No colony-density × fertilization dataset exists in-repo; the only Allee proxy is the 95%-outcrossed-vs-15%-sibling fertilization contrast (Mendoza-Quiroz 2023).
- **Disturbance × size** currently collapses to 3 generic *states* (script 37), NOT by type. Colony-level survival data is typed only for **disease** and **storm** (both confounded with single studies: Neely FL Keys / NOAA). Storm mortality concentrates in large SC4/SC5 (248 SC5 obs); disease is more size-even. Bleaching/cold-snap exist only at event level.

## Stack & reproduction
R 4.3+; `renv.lock` present (renv out-of-sync, run `renv::restore()`). All scripts `source("utils/shared_utilities.R")`. Reproduce: `cd 06_analysis/scripts && Rscript run_all.R`. Constants (`SIZE_BREAKS`, palette) and matrix helpers live in `utils/00c_*`, `utils/03_matrix_functions.R`.

## Related
- Sibling model + web app: [Detmer-2025-coral-RSE](https://github.com/stier-lab/Detmer-2025-coral-RSE) + `coral-app/`
- Catalog: `~/repo-catalog/repos/stier-lab__Detmer-2025-coral-parameters.md`
- PRD: `07_reporting/internal/biological_realism_PRD.md`; figure map: `07_reporting/manuscript/figure_table_map.md`
- Memory: `project_rse_param_reconciliations`, `project_data_integration_rework`, `project_neely_data_request`
