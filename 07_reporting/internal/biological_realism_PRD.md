# PRD: Biological Realism Integration for A. palmata Synthesis

**Status:** Approved 2026-04-17
**Owner:** Adrian Stier (astier@ucsb.edu)
**Contributors:** Raine Detmer
**Branch:** `codex-pipeline-refresh-automation`
**Planning doc:** `~/.claude-work/plans/dapper-tinkering-cerf.md`

---

## 1. Context

The current *A. palmata* synthesis (`06_analysis/scripts/13_transition_matrix.R`) uses a 5-class Lefkovitch matrix where the "fecundity" row is **fragmentation only** (lines 567–601). Sexual reproduction, despite being central to *A. palmata* population biology, is absent from the model. This was a deliberate simplification given data availability, but:

1. The life-history parameter file (`05_data/standardized/apal_life_history_parameters.csv`) already contains the parameters needed to model sexual reproduction (Vardi 2011 maturity threshold, Mendoza-Quiroz 2023 oocyte density, Piñón-González 2018 lesion penalty, Lirman 2000a sterility duration).
2. Cross-notebook queries against four NotebookLM libraries (`Acropora Palmata Restoration`, `Coral regeneration all sources`, `Density-Dependent Coral Biology`, `Acropora Restoration Success Limited by Poor Long-Term Survival`) surfaced seven additional biological mechanisms well-documented in the literature but absent from the model.
3. The restoration community has an active debate about sexual vs asexual replacement pathways. Our current model can't address this because we don't track sexual output.
4. For Coral Reefs submission, a sensitivity-of-conclusions-to-biological-assumptions analysis strengthens the paper's robustness claims.

**Design choice.** Rather than replacing the current model with a single "more realistic" version, we implement each biological extension as a toggle in a **scenario-comparison framework**. This answers the question "how sensitive is λ to each assumption?" directly, produces a tornado plot, and lets us report which assumptions matter.

## 2. Objectives

**Primary:**
- Implement 7 biological-realism extensions as composable scenario toggles
- Report λ, P(decline), quasi-extinction time, SC5 elasticity, and sexual-replacement fraction for 9 scenarios (baseline + 7 individual + 1 all-combined)
- Produce a tornado-plot supplementary figure ranking assumptions by Δλ magnitude

**Secondary:**
- Refactor `compute_lambda_from_survival()` into shared utilities for reuse across all scenario scripts
- Document every parameter-to-literature mapping in the codebase
- Preserve the current published λ = 0.961 as the baseline reference

**Non-goals:**
- Changing the primary k=17/22-effect meta-analysis results
- Replacing Fig 1-4 manuscript figures
- Implementing genotype × environment (Idea 9) or substrate-specific fragment survival (Idea 10) — these lack data and are flagged as future work in the Discussion

## 3. Hypotheses and citations

Each scenario tests a specific, pre-specified hypothesis derived from literature. Parameter values are either already in `apal_life_history_parameters.csv` (LHP CSV) or derivable from existing columns in `apal_surv_ind.csv`. No new field data, no free-parameter data-dredging.

### S0 — Baseline (current model)
No changes. Reproduces λ = 0.961 (CI: 0.816–1.010), P(decline) = 94.3%.

### S1 — Size-threshold sexual fecundity
- **Hypothesis:** Adding a sexual reproduction pathway separate from fragmentation shifts λ and reduces the dominance of SC5 stasis elasticity.
- **Citations:** Vardi et al. 2011 (maturity size 4000 cm² = 90% gamete production, LHP row 2); Mendoza-Quiroz et al. 2023 (oocyte density 63.6/cm², 5.61/polyp, LHP rows 4-5); Mendoza-Quiroz et al. 2023 (fertilization 95% wild, 15% sibling, LHP rows 32-33).
- **Implementation:** Build F_sex row where F_sex[SC1,s] = oocyte_density × area(s) × fertilization_rate × s_recruit, with area-weighted partial reproduction at SC4 and full at SC5.
- **Parameter source:** `recruit_surv_pars.rds` already holds `s_recruit = 0.028` (2.8% annualized from Chamberland 2015 et al., n=16,479).

### S2 — Post-disturbance sterility lag
- **Hypothesis:** Restoration cohorts rarely reach 4-year reproductive maturity without interruption, so effective sexual fecundity is near-zero in high-disturbance regions.
- **Citation:** Lirman 2000a (4-year sterility after fragmentation; LHP row 25).
- **Implementation:** For each colony-year, if `fragment == TRUE` in any year or `disturbance != NA` within past 4 years, F_sex = 0. Applied in stochastic projection (not single-year matrix).

### S3 — Partial-mortality fecundity penalty
- **Hypothesis:** A substantial fraction of surviving adult tissue is post-lesion, reducing effective sexual output by 10–30%.
- **Citations:** Piñón-González 2018 (20% egg volume reduction in lesioned colonies; LHP row 3); Lirman 2000b (lesions >20 cm² do not recover; LHP rows 20-22).
- **Implementation:** F_sex × (1 − 0.20 × fraction_lesioned), where fraction_lesioned derives from `shrinkage_frequency_by_sc.csv` (script 36 output).

### S4 — Time-since-outplanting decay
- **Hypothesis:** Restoration outplants show a temporal decay in survival independent of size, consistent with Boisvert et al. 2024 (A. cervicornis showing restoration-site survival drops to near-zero after ~4 yr without supplementation).
- **Citation:** Boisvert et al. 2024, Coral Reefs.
- **Implementation:** Derive `years_since_outplant` per coral_id as `survey_yr - min(survey_yr[coral_id])` for restoration studies. Fit GLM: survival ~ log_size + years_since_outplant + (1|study). Refit survival vector for restoration studies only; blend with natural vector by population-type weighting.

### S5 — Winter SST anomaly for disease risk
- **Hypothesis:** Mild winters (high winter SST anomalies) predict size-biased disease epizootics better than summer DHW alone; large colonies bear the disease burden (Rodriguez-Martinez 2014 showed 48% WPx prevalence in colonies >75 cm vs 0% in <5 cm).
- **Citations:** Rosales et al. 2024 (microbiome stability threshold 31°C; LHP row 34); Rodriguez-Martinez 2014 (disease prevalence by size; LHP rows 19-20).
- **Implementation:** Extract Jan-Mar monthly mean SST per region centroid from NOAA OI SST v2, compute anomaly vs 1981-2010 baseline. Fit GLM: survival ~ log_size × winter_anomaly + (1|study), using data from 2004-2023. Refit survival vector for disease-epizootic years.

### S6 — Depensatory corallivory (Allee effect)
- **Hypothesis:** Small-colony survival is density-dependent; at low population densities, *Coralliophila* snails and corallivorous fish concentrate on remaining colonies, driving depensatory mortality that creates a hidden extinction threshold.
- **Citations:** Williams 2012 (Coralliophila 16 cm²/day consumption; 27% background loss with <2 snails; LHP rows 22-23).
- **Implementation:** Density-dependent hazard for SC1-SC2: S(D) = S₀ × D/(K+D), where D is local coral density (study × year × group_N proxy) and K is fit via profile-likelihood on SC1-SC2 survival variance across studies. Sensitivity reported over K ∈ {0.5, 1, 2, 4} × observed median.

### S7 — Microhabitat / depth / flow
- **Hypothesis:** Depth and wave-exposure modulate size-survival; high-flow/shallow forereef refugia dissipate heat stress and buffer disturbance (Ramos-Romero 2025 Cuba, Kuffner 2020 Dry Tortugas).
- **Citations:** Ramos-Romero 2025 (growth +7.3 vs -1.5 cm/yr by flow; LHP rows 29-30); Kuffner 2020 (calcification 7.9 vs 4.2 mg/cm²/day; LHP rows 6-7).
- **Implementation:** GLM: survival ~ log_size + depth_m + (1|study) using the `depth_m` column in `apal_surv_ind.csv`. Report heterogeneity reduction (ΔI²) after including depth.

### S8 — All combined
- **Implementation:** Apply all of S1-S7 simultaneously to a single projection matrix. This scenario tests for multiplicative interactions (e.g., does density-dependence × sterility-lag produce greater-than-additive effects?).

### Flagged but not implemented (Discussion only)

**Idea 7** — Pre-restoration benthic baselines (Boisvert 2024): needs site-level historical cover data we don't have. Discussed as future collaboration with CRF/Mote.

**Idea 9** — Genotype × environment: AGF work at Curaçao vs FL shows dramatic heat-tolerance differences. Needs genotype metadata from CRF/Mote/FUNDEMAR — requested via pending Spadaro email (2026-04-17).

**Idea 10** — Substrate-specific fragment survival: fragments on sand die 58%/month vs ~0% on live tissue. Would need substrate metadata per colony.

## 4. Scenario comparison matrix

| Scenario | F_mat (frag) | F_sex (sexual) | S modifiers | λ prediction | Key reference |
|---|---|---|---|---|---|
| S0 Baseline | ✓ | — | — | 0.961 | Current manuscript |
| S1 +Sexual | ✓ | ✓ (1) | — | Slightly higher; SC5 elasticity drops | Vardi 2011, Mendoza-Quiroz 2023 |
| S2 +Sterility lag | ✓ | ✓ (1+2) | — | Lower than S1; close to baseline | Lirman 2000a |
| S3 +Lesion penalty | ✓ | ✓ (1+2+3) | — | Lower than S2 | Piñón-González 2018 |
| S4 +Outplant age | ✓ | — | age covariate | Lower for restoration-weighted studies | Boisvert et al. 2024 |
| S5 +Winter SST | ✓ | — | winter anomaly | Increased variance; size-biased | Rosales 2024, Rodriguez-Martinez 2014 |
| S6 +Depensatory | ✓ | — | density-dep SC1-2 | Nonlinear; larger CI | Williams 2012 |
| S7 +Microhabitat | ✓ | — | depth covariate | Reduced heterogeneity | Ramos-Romero 2025 |
| S8 All combined | ✓ | ✓ (1+2+3) | all modifiers | Maximal realism | — |

## 5. Acceptance criteria

**Technical:**
- [ ] `Rscript 06_analysis/scripts/run_all.R` completes without error
- [ ] S0 reproduces current published λ = 0.961 within 1e-3 tolerance
- [ ] All 9 scenarios produce numeric λ, CI, P(decline), QE_time
- [ ] `biological_realism_scenarios.csv` has 9 rows × 8 columns
- [ ] FigS29 renders at 174 mm (submission-ready)
- [ ] Every new script passes `Rscript -e "parse('...')"` syntax check
- [ ] No new warnings introduced in existing scripts (Fig 1-4 outputs unchanged)

**Biological:**
- [ ] S1 elasticity: SC5 stasis < baseline SC5 stasis (alternative replacement exists)
- [ ] S2 λ ≤ S1 λ (sterility reduces effective sexual output)
- [ ] S3 λ ≤ S2 λ (lesion penalty further reduces)
- [ ] Directional priors hold for S4-S7 (none are increases)
- [ ] Tornado plot shows at least one assumption with |Δλ| > 0.02 (otherwise sensitivity analysis is uninformative)

**Documentation:**
- [ ] Every script cites its parameter source (LHP CSV row or derivation formula)
- [ ] `CLAUDE.md` lists all new scripts and their parameter dependencies
- [ ] `figure_table_map.md` has FigS29 entry
- [ ] PRD closed with `Status: Complete`

## 6. Out of scope / explicit exclusions

- No changes to Figure 1-4 or the primary meta-analytic result (78.0% pooled survival, k=17, 22 effects)
- No new field data collection or new-study integration (Mote/CRF requests are separate workflows)
- No re-fitting of the growth GAMs beyond adding covariates
- No changes to `parameter_lists/*.rds` files used by the RSE model; only the synthesis pipeline is affected

## 7. Risks and mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| NOAA OI SST API unavailable or slow | Medium | Cache locally to `05_data/external/noaa_oi_sst/`; script 51 checks cache first |
| `years_since_outplant` derivation wrong when first-observation ≠ true outplant date | Medium | Cross-check against study metadata (Pausch 2018 documented outplant date); add per-study overrides |
| Depensatory K calibration arbitrary | High | Report sensitivity across K ∈ {0.5, 1, 2, 4} × median in FigS29; do not commit to single value |
| 9-scenario table looks like p-hacking | Medium | Every parameter is pre-specified from literature; no free parameters fit to our data. Include "pre-registration"-style note in the Results |
| Adding 12 scripts pushes pipeline past 90 min | Low | Scripts 50-59 are independent; run_all.R can parallelize |
| S8 combined reveals interaction larger than each individual effect | High (interpretively) | Report explicitly; this is a finding not a bug |

## 8. Key files modified or added

**New files (12 R scripts + 1 PRD):**
- `07_reporting/internal/biological_realism_PRD.md` (this file)
- `06_analysis/scripts/utils/02_matrix_functions.R`
- `06_analysis/scripts/50_derive_outplant_age.R`
- `06_analysis/scripts/51_winter_sst_anomalies.R`
- `06_analysis/scripts/52_colony_lesion_state.R`
- `06_analysis/scripts/53_sexual_fecundity_layer.R`
- `06_analysis/scripts/54_sterility_lag_layer.R`
- `06_analysis/scripts/55_lesion_fecundity_penalty.R`
- `06_analysis/scripts/56_outplant_age_model.R`
- `06_analysis/scripts/57_winter_sst_survival_model.R`
- `06_analysis/scripts/58_depensatory_corallivory_layer.R`
- `06_analysis/scripts/59_microhabitat_depth_model.R`
- `06_analysis/scripts/60_scenario_comparison.R`
- `06_analysis/scripts/61_fig_biological_realism.R`

**Edited files:**
- `06_analysis/scripts/16_sensitivity_analysis.R` (remove compute_lambda — now imported)
- `06_analysis/scripts/utils/shared_utilities.R` (source new module)
- `06_analysis/scripts/run_all.R` (orchestrate new scripts)
- `CLAUDE.md` (document new scripts + LHP-driven parameters)
- `07_reporting/manuscript/figure_table_map.md` (add FigS29)
- `06_analysis/figures/README.md` (add FigS29)

## 9. Verification commands

```bash
# Full pipeline
cd /Users/adrianstier/Detmer-2025-coral-parameters
Rscript 06_analysis/scripts/run_all.R 2>&1 | tee /tmp/run_all.log
grep -i "error\|warning" /tmp/run_all.log | head -20

# Baseline preservation
Rscript -e "m <- readRDS('06_analysis/output/transition_matrix.rds'); cat('λ =', round(m\$lambda, 3))"
# expect: λ = 0.961

# Scenario output check
Rscript -e "s <- read.csv('06_analysis/output/biological_realism_scenarios.csv'); print(s[, c('scenario','lambda','p_decline','sc5_elasticity')])"
# expect 9 rows with monotone shifts

# Figure render
ls -la 06_analysis/figures/supplementary/FigS29_biological_realism.{png,pdf}
```

## 10. Changelog

| Date | Change | Author |
|---|---|---|
| 2026-04-17 | PRD drafted and approved | Adrian Stier (via Claude) |

---

*This PRD is linked to the planning document at `~/.claude-work/plans/dapper-tinkering-cerf.md` and will be updated as implementation progresses. Status line at top must be updated before closing.*
