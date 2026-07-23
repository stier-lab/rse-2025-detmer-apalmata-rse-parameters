# Size-Dependence of Disturbance Survival in *Acropora palmata*

*Created: 2026-07-21 · Detmer & Stier Lab. Authoritative demographic provenance for how disturbance
reshapes the size–survival relationship, and the RSE-ready per-type size multipliers exported for the
strategy model (`Detmer-2025-coral-RSE`). Estimation lives here; the strategy model only CONSUMES the
exported table.*

## Where this is computed
- **Fit:** `06_analysis/scripts/37_disturbance_size_interaction.R` (generic none/chronic/acute) and
  `06_analysis/scripts/37b_disturbance_type_size_interaction.R` (by disturbance TYPE — the one used here).
- **Inputs:** `05_data/standardized/apal_surv_ind.csv` (n≈6,141 survival intervals, 17 studies incl. the
  Neely FKNMS *A. palmata* direct-share) + `caribbean_disturbance_events.csv` (satellite DHW bands).
- **Outputs:** `06_analysis/output/disturbance_type_size_{slopes,survival_summary,model_terms,heatwave_dhw}.csv`,
  and the RSE hand-off `disturbance_type_size_multipliers_rse.csv` (written by `37c_rse_size_multipliers.R`).

## The finding — size×disturbance is TYPE-dependent (interaction LRT χ²=18.7, df=2, p=8.7e-5)

Baseline size–survival is strongly size-increasing (slope +0.394 log-odds per log-size, p<1e-75):
`none` survival = `c(SC1 0.556, SC2 0.748, SC3 0.845, SC4 0.923, SC5 0.962)`.

Each disturbance type reshapes that gradient differently:

| Type | slope (vs none) | survival by size (SC1..SC5) | event/none multiplier | size signature |
|---|---|---|---|---|
| **none** | +0.394 | 0.556, 0.748, 0.845, 0.923, 0.962 | 1,1,1,1,1 | large safer |
| **disease/predation** | +0.446 (Δ+0.05, NS) | 0.375, 0.311, 0.493, 0.701, 0.883 | **0.68, 0.42, 0.58, 0.76, 0.92** | **gradient INTACT → large-favoring** (partial-mortality refugia; small killed outright) |
| **storm** | +0.146 (Δ−0.248, p=8e-5) | —, 0.745, 0.828, 0.838, 0.887 | **~1.0, 1.00, 0.98, 0.91, 0.92** | **FLATTENED** (branch breakage erodes big-is-safer) |
| **heatwave, moderate DHW<10** | (gradient persists) | 0.571, 0.705, 0.834, 0.919, 0.952 | **1.03, 0.94, 0.99, 0.99, 0.99 ≈ 1** | **gradient PERSISTS ≈ baseline** (large still favored) |
| **heatwave, severe DHW≥10** (small n=1–27) | (noisy, still ↑) | 0(n1), 0.214, 0.647, 0.529, 0.741 | ~0.29, 0.77, 0.57, 0.77 | survival drops; gradient roughly holds but under-sampled |
| **heatwave, catastrophic DHW>20** (external) | flat | ~0.02–0.10 across sizes | **~0.05 flat** | **refuge COLLAPSES** — Manzello 2025 (97.8–100%), size-independent |

## Interpretation (locked)
1. **Disease/predation preserves the large-colony advantage** — large colonies survive partial tissue loss;
   small colonies and remnants are killed outright (*Coralliophila abbreviata* aggregation). This is the
   dominant acute signature in the *A. palmata* record (the 2014–15 `disease_2014` compound event).
2. **Storms flatten the gradient** — mechanical breakage of large branching colonies removes their safety
   margin (survival ~flat 0.85; breakage → fragmentation, not death).
3. **Moderate thermal (DHW<10) barely dents survival and KEEPS the gradient** — in our Caribbean *A. palmata*
   data the large-colony advantage persists at moderate heat. It does NOT reverse.
4. **Only catastrophic thermal (DHW>20) is size-neutral** — and there ~everything dies (Manzello 2025). Our
   monitoring data under-captures this tail (2023 in-sample survival 0.2–0.74 is survivor-biased vs Manzello's
   ~0%), so the catastrophic multiplier is set from Manzello, not from our under-sampled severe band.

## IMPORTANT — reconciliation with external thermal studies
Some Indo-Pacific / cross-species work reports LARGER colonies as MORE thermally vulnerable at moderate heat
(Speare et al. 2022 Moorea ≥30 cm ~1.3× more likely to die; Miller/Banaszak 2024; Pausch 2018 small fragments
bleached less). **Our Caribbean *A. palmata* data does NOT reproduce a moderate-thermal large-disadvantage** —
37b finds the gradient persists at DHW<10. The large-disfavoring pattern is therefore treated as an EXTERNAL
scenario, not our in-sample finding. The RSE model should default to the 37b-fit multipliers (moderate thermal
≈ neutral, gradient persists) and may run the external large-disfavoring vector only as a labelled sensitivity.

> Note for the population model: Script 40 applies heatwave mortality as a size-UNIFORM scalar. 37b shows
> that is defensible only at catastrophic DHW; at moderate DHW a size-uniform pulse over-kills large colonies.
> Flagged as a Script-40 limitation.

## RSE hand-off
`37c_rse_size_multipliers.R` writes `output/disturbance_type_size_multipliers_rse.csv` with one size-vector
(SC1..SC5) per disturbance type. The RSE repo reads that file; it must NOT hard-code these numbers.
