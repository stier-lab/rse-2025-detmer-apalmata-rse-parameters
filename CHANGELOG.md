# Changelog

_Newest first._

## 2026-07-21
- **Added scenario S9 `59b_fertilization_allee_layer.R` (fertilization Allee).** Density-dependent
  fertilization `φ(ρ)=ρ/(ρ+h)` on F_sex — self-incompatible broadcast-spawner sperm limitation.
  **Assumption sweep, NOT a fitted rate:** no *A. palmata* fertilization-density curve exists; only
  anchor is Baums 2006 (sparse 0.13 / dense 0.30 col/m²), so `h` is SWEPT {0.05,0.10,0.15,0.30}.
  Effect on λ is small (0.972→0.963 at the strongest Allee) because sexual recruitment is a minor λ
  contributor; the real lever is larval output for reseeding (RSE reserve question). Wired into script 60
  (S9 at sparse-reef representative point) and `run_all.R`; exports `fertilization_allee.rds` +
  `fertilization_allee_phi_rse.csv` (RSE-consumable). See PRD §S9.
- **Parked scenario S6 (depensatory corallivory) OFF by default (data-thin).** Verified against
  Williams & Miller 2012: the paper shows only that snails *concentrate* as coral declines (Fig 4,
  correlational) and explicitly states snail loss is "somewhat independent of abundance" and "could not
  be definitively linked to snail occupation." The causal low-density→higher-mortality claim is NOT
  established, so S6 is a discussion/sensitivity option only. (Also: 16 cm²/day is Brawley & Adey 1982,
  not a Williams measurement.) PRD §S6, script 58 header updated.
- **Added `37c_rse_size_multipliers.R` + `06_analysis/DISTURBANCE_SIZE_DEPENDENCE.md`.** Exports the
  37b type×size fit as RSE-ready per-type size-survival multipliers
  (`output/disturbance_type_size_multipliers_rse.csv`) consumed by the `Detmer-2025-coral-RSE` strategy
  model; the doc is the authoritative provenance for how disturbance reshapes size-survival. Multipliers
  (SC1–SC5): disease `0.68,0.42,0.58,0.76,0.92` (large-favoring); storm `1.00,1.00,0.98,0.91,0.92`
  (flattened); thermal_moderate `1.03,0.94,0.99,0.99,0.99` (gradient persists ≈ baseline);
  thermal_catastrophic `0.05` flat (Manzello 2025). The demographic estimation now lives fully in this
  repo; the RSE repo only consumes the CSV (no hard-coded rates).
- **Added `37b_disturbance_type_size_interaction.R` → FigS30.** New analysis of how the three
  disturbance *types* differentially reshape the size–survival relationship of *A. palmata*,
  extending script 37 (which used generic curated disturbance *states*) to the typed
  storm/disease/heatwave contrast.
  - Storm significantly flattens the size–survival slope (0.39→0.15 log-odds/log-cm², p=1e-4):
    large branching colonies lose their survival advantage (mechanical breakage).
  - Disease acts as a steep downward level shift (intercept −2.26, p<1e-4; slope unchanged):
    absolute losses concentrate at SC2–SC3 (−44, −35 pp); large colonies are relative refugia.
  - Size × type interaction significant (LRT χ²=18.7, df=2, p=8.7e-4; overdispersion ratio 0.97).
  - Heatwave (observational bleaching-year DHW overlap, disease-flagged colonies excluded):
    size gradient persists at moderate DHW, compresses at severe; DHW×size interaction
    marginal (β=−0.042, p=0.09). Flags that script 40's size-uniform heatwave pulse is only
    justified at catastrophic DHW.
  - Wired into `run_all.R`; outputs `disturbance_type_size_*.csv`; legend added to
    `figure_legends.txt`; `figure_table_map.md`, `CLAUDE.md`, `ORIENTATION.md` updated to
    the FigS1–FigS30 set.
- **Added `ORIENTATION.md`** at repo root (repo-onboarding artifact).
