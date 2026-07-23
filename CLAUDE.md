# Project Guide

**Project:** *Acropora palmata* Size-Dependent Demography Synthesis
**Tech:** R 4.3+ | 71 analysis scripts | Target journal: *Coral Reefs* (Springer)

---

## What This Is

A synthesis of all existing *Acropora palmata* (Elkhorn Coral) demographic data across the Caribbean. The central question: **how do survival and growth vary as a function of colony size in restored vs. natural populations?**

We compiled ~12,000 individual-level observations from 7 studies (including the newly added Neely et al. 2022 FKNMS dataset: 878 colonies, FL Keys 2010-2016) plus 10 additional summary-level studies (17 unique studies contributing 22 study-level effects) across 13 Caribbean regions. The data are standardized to a common size metric (live planar tissue area, cm^2) and analyzed using GAMs, GLMMs, and random-effects meta-analysis. A Lefkovitch population projection matrix translates the size-dependent vital rates into a population growth rate (lambda) and elasticity analysis.

This repo is the **empirical parameter source** for the restoration decision-support work. The sibling repo [stier-lab/Detmer-2025-coral-RSE](https://github.com/stier-lab/Detmer-2025-coral-RSE) holds the Restoration Strategy Evaluation model and the interactive web app (`coral-app/`); its R analyses read the demographic parameters produced here and expect this repo cloned alongside it at `../Detmer-2025-coral-parameters/`. (The earlier `Detmer-2025-coral-platform` first-pass app is archived — point readers to coral-RSE, not it.)

---

## Critical Constraints

These apply to **every** analysis change:

- **I^2 = 97.2%** — extreme heterogeneity across studies. Any bootstrap must use **hierarchical resampling** (study -> observation).
- **NOAA = 78%** of individual-level data. Results may not generalize. Always check LOSO sensitivity.
- **Natural vs restoration confounded with study identity** — in individual-level data, natural colonies are mostly NOAA + Neely. The expanded meta (k=17, 22 effects) has 10 natural + 12 restoration effects; difference not significant (p=0.238).
- **Neely 2014 disturbance event** — Neely et al. 2022 includes a catastrophic mortality event (53% surv in 2014 vs 88% in non-disturbance intervals). Disturbance intervals are flagged; sensitivity analysis shows excluding them shifts pooled survival by +2.7 pp.
- **Fragmentation data from one study** (Vardi 2011, 13 rows). Cannot be improved without new data.
- **All Florida vital rates are pre-2023 collapse.** Manzello et al. (2025, *Science*) documented functional extinction of *A. palmata* from Florida after the 2023 heatwave (97.8-100% mortality at 16-20 DHW). Our transition matrix describes the chronic demographic regime that operated before this event. Heatwave scenario analysis (Script 40) layers Manzello's dose-response onto the population model.
- Any new binomial GLMM needs an **overdispersion check** (`sum(pearson_resid^2) / rdf`).
- Meta-analysis: always use `test = "knha"` in `rma()` calls (Knapp-Hartung adjustment) for independent models; three-level `rma.mv()` is the primary model. Moderator analyses are exploratory at k=17 (22 effects).
- **Size measurement varies across studies**: L x W x %live (NOAA, Pausch), photo tracing (USGS, Kuffner), diameter^2 (Mendoza-Quiroz). Pooled analyses assume comparability.
- **Mortality definitions are heterogeneous and not harmonized.** NOAA = no tissue AND skeleton gone (conservative); Kuffner = >=50% tissue loss (aggressive); others = no live tissue. No sensitivity analysis stratifying by mortality definition has been run. This is a known limitation.
- **Annualization assumes constant hazard** (`S_annual = S_observed^(1/t)`). This is the standard approach but does not account for seasonal mortality peaks (hurricane season, summer bleaching). No sensitivity to alternative annualization methods has been tested.
- **No formal publication bias assessment** (funnel plot, Egger's test) has been conducted. With k=22 effects, asymmetry tests are at the boundary of usefulness but should be included before submission.
- **Size class boundaries (0/10/100/900/4000 cm^2) follow Vardi 2011** without formal optimization for this dataset. No comparison to alternative discretizations or an IPM has been conducted.

---

## Pipeline Structure

Scripts run in order. Changes to upstream scripts affect everything downstream.

All scripts live in `06_analysis/scripts/` and read data from `05_data/`.

```
01_data_prep -> [02-07]_core -> [08-12]_robustness -> [13-17]_synthesis -> [18-22]_main_figs
                                                    -> 14b_expanded_meta  -> [24-28]_supp_figs
```

| Phase | Scripts | What they do |
|-------|---------|-------------|
| Data Prep | 01 | Load, clean, standardize, assign size classes; build `prepared_survival_cells.rds` (individual + summary, for study-level rma) |
| Core | 02-07 | Survival/growth thresholds, growth rates, variance, data gaps |
| Robustness | 08-12 | Climate, power, cross-validation, context comparison, model selection |
| Synthesis | 13-17, 14b | Transition matrix, meta-analysis (k=5 and k=17/22 effects), sensitivity |
| Main Figures | 18, 19, 20b, 22 | 4 manuscript figures (Fig 1-4) |
| Supp Figures | 18, 20c, 21, 23-28 | FigS1-S15 + S21 (disturbance/temporal/biological-realism phases below add S16-S30; FigS27 intentionally vacant) |
| Heatwave Scenarios | 40 | Manzello 2025 dose-response + catastrophic heatwave projections (FigS22) |
| Biological Realism | 50-61 | 10-scenario sensitivity framework (S0-S9): sexual fecundity, sterility lag, lesion penalty, outplant decay, winter SST, depensatory corallivory (S6, OFF by default - data-thin), depth refugia, and fertilization Allee (S9, script 59b, assumption sweep). See biological_realism_PRD.md |
| Verification | 23_verification | Pipeline integrity checks |
| Orchestrator | run_all | Runs everything in sequence |

### Figure Scripts -> Figures

| Script | Output | Content |
|--------|--------|---------|
| 18 | Fig 1 + FigS1 | Study landscape map + data availability; size distribution |
| 19 | Fig 2 | Survival GAM + RGR GAM + size-class synthesis (3 panels) |
| 20b | Fig 3 | Forest plot k=17 (22 effects) + regional survival (2 panels) |
| 22 | Fig 4 | Transition matrix + elasticity + bootstrap lambda + LOSO (4 panels) |
| 21 | FigS8 | Natural vs restoration (supplementary) |

---

## Shared Utilities

All scripts source `utils/shared_utilities.R`, which loads these modules in order:

| Module | Exports |
|--------|---------|
| `00_libraries.R` | Package loading (tidyverse, lme4, metafor, mgcv, etc.) |
| `00b_color_palette.R` | `MANUSCRIPT_PALETTE`, `OKABE_ITO`, `SIZE_CLASS_COLORS` |
| `00c_analysis_constants.R` | `SIZE_BREAKS`, `SIZE_LABELS` ("SC1"-"SC5") |
| `01_functions.R` | `get_project_root()`, `save_manuscript_fig()`, `theme_manuscript()`, `wilson_ci()`, `print_header()`, etc. |
| `02_threshold_functions.R` | Detmer et al. (2025) threshold detection framework |
| `03_matrix_functions.R` | Scenario framework helpers: `compute_lambda_from_survival()`, `build_F_sex()`, `apply_disturbance_lag()`, `apply_lesion_penalty()`, `apply_density_dep_SC12()`, `run_scenario()` |

### Size Classes (canonical — use these everywhere)

```r
SIZE_BREAKS <- c(0, 10, 100, 900, 4000, Inf)
SIZE_LABELS <- c("SC1", "SC2", "SC3", "SC4", "SC5")
```

Never use `"SC1_recruit"`, `"SC1 (0-10)"`, or other variants in analysis code.

---

## Data

### Input

| File | What | Records |
|------|------|---------|
| `05_data/standardized/apal_surv_ind.csv` | Individual survival | ~7,800 |
| `05_data/standardized/apal_growth_ind.csv` | Individual growth | ~6,300 |
| `05_data/standardized/apal_surv_summ.csv` | Summary survival (study-level) | ~30 |
| `05_data/standardized/apal_growth_summ.csv` | Summary growth | ~20 |
| `05_data/standardized/apal_fragmentation.csv` | Fragmentation (Vardi 2011) | 13 |
| `05_data/original/` | Raw source files — **DO NOT MODIFY** | 14 files |

### Key Outputs

| File | Producer | What |
|------|----------|------|
| `06_analysis/output/prepared_survival_cells.rds` | Script 01 | Cell-level survival (individual + summary, sample-size weighted) |
| `06_analysis/output/transition_matrix.csv` | Script 13 | 5x5 Lefkovitch projection matrix |
| `06_analysis/output/lambda_bootstrap_samples.rds` | Script 13 | 2000 bootstrap lambda values |
| `06_analysis/output/expanded_meta_analysis_results.csv` | Script 14b | k=17 (22 effects) meta-analysis summary |
| `06_analysis/output/expanded_meta_analysis_study_effects.csv` | Script 14b | Per-study survival estimates |
| `06_analysis/output/size_class_survival_synthesis.csv` | Script 20 | SC1-SC5 survival by study |
| `06_analysis/output/manzello_dose_response.csv` | Script 40 | Manzello 2025 dose-response curve (DHW vs mortality) |
| `06_analysis/output/heatwave_scenario_summary.csv` | Script 40 | Effective lambda and quasi-extinction by scenario |
| `06_analysis/output/heatwave_scenario_projections.csv` | Script 40 | Full 50-year projection trajectories by scenario |
| `06_analysis/output/sexual_fecundity_matrix.rds` | Script 53 | F_sex size-threshold sexual fecundity matrix (Vardi 2011 × Mendoza-Quiroz 2023) |
| `06_analysis/output/sterility_lag_F_sex.rds` | Script 54 | F_sex with Lirman 2000a 4-yr sterility applied |
| `06_analysis/output/lesion_penalty_F_sex.rds` | Script 55 | F_sex with Piñón-González 2018 20% penalty |
| `06_analysis/output/outplant_age_survival.rds` | Script 56 | Boisvert 2024 outplant-age survival GLMM predictions |
| `06_analysis/output/winter_sst_survival.rds` | Script 57 | Winter SST × size survival GLMM (ERSST v5 anomalies) |
| `06_analysis/output/depensatory_corallivory.rds` | Script 58 | Density-dependent SC1/SC2 survival (Williams 2012) |
| `06_analysis/output/microhabitat_depth_survival.rds` | Script 59 | Depth covariate survival GLMM |
| `06_analysis/output/biological_realism_scenarios.csv` | Script 60 | 10-scenario (S0-S9) summary: lambda, delta_lambda, elasticity, sexual contribution % |
| `05_data/standardized/apal_outplant_age.csv` | Script 50 | years_since_outplant per coral_id |
| `05_data/standardized/apal_lesion_state.csv` | Script 52 | Per-colony lesion flag from tissue-loss intervals |
| `05_data/standardized/winter_sst_anomalies.csv` | Script 51 | Winter SST anomalies per region × year (ERSST v5) |

---

## 7 Individual-Level Studies

| Study | Type | Region | n | Key Issue |
|-------|------|--------|---|-----------|
| NOAA_survey | Natural | FL, Curacao, Navassa | 4,048 | Largest dataset; large colonies |
| neely_et_al_2022 | Natural | FL Keys | 878 | 2014 disease catastrophe (53% surv); disturbance-flagged |
| pausch_et_al_2018 | Restoration | Florida | 969 | Fragment experiments |
| USGS_USVI_exp | Restoration | USVI | 46 | Outplanted 2019 |
| kuffner_et_al_2020 | Restoration | Florida | 52 | Mortality = >=50% tissue loss |
| mendoza_quiroz_et_al_2023 | Natural | Mexico | 52 | Some sizes from diameter only |
| fundemar_fragments | Restoration | Dominican Rep. | 43 | Nursery fragments |

10 additional studies contribute summary-level data only (17 unique studies, 22 study-level effects in expanded meta; NOAA, Vardi, and Garrison each split into sub-effects). Summary-level survival data is integrated into the transition matrix (script 13) and parameter lists (script 17) via `prepared_survival_cells.rds` — a cell-level dataset that combines individual and summary data with sample-size weighting. See `04_extraction/data_integration_issues.md` and `04_extraction/data_flow_diagram.md` for details.

---

## Statistical Conventions

### Bootstrap (hierarchical)

```r
# CORRECT
for (b in 1:n_boot) {
  boot_studies <- sample(studies, length(studies), replace = TRUE)
  boot_data <- do.call(rbind, lapply(boot_studies, function(s) {
    study_data <- data[data$study == s, ]
    study_data[sample(nrow(study_data), nrow(study_data), replace = TRUE), ]
  }))
}

# WRONG — ignores study clustering
boot_data <- data[sample(nrow(data), nrow(data), replace = TRUE), ]
```

### Models

```r
# CORRECT — mixed effects
glmer(survived ~ log_size + (1|study), family = binomial, data = surv_data)

# After every binomial GLMM:
pearson_resid <- residuals(model, type = "pearson")
ratio <- sum(pearson_resid^2) / (length(pearson_resid) - length(fixef(model)))
if (ratio > 1.5) warning("Potential overdispersion")
```

---

## Figure Standards (Coral Reefs journal)

- Double-column: **174 mm** | Single-column: **84 mm** | Max height: **234 mm**
- Font: **Helvetica**, 8-12 pt | Panel labels: **lowercase a, b, c**
- No titles/captions in figures | Color: RGB
- Export: `save_manuscript_fig(plot, filename, width_mm, height_mm)` handles PNG + PDF at 300 DPI
- Palette: `MANUSCRIPT_PALETTE` (blues for survival, teals for growth, Okabe-Ito for qualitative)
- Layout: `patchwork` with `plot_layout(guides = "collect")`
- Theme: `theme_manuscript()` from shared utilities

---

## Output Naming Convention

All outputs follow consistent naming patterns. See `06_analysis/output/README.md` and `06_analysis/figures/README.md` for full details.

### Figures

| Directory | Pattern | Use |
|-----------|---------|-----|
| `figures/manuscript/` | `Fig{N}_{snake_case}.{pdf,png}` | Main text (Fig1-Fig4) |
| `figures/supplementary/` | `FigS{N}_{snake_case}.{pdf,png}` | Numbered supplementary (FigS1-FigS30; FigS27 intentionally vacant) |
| `figures/supplementary/exploratory/` | `{snake_case}.{pdf,png}` | Unnumbered exploratory/diagnostic |
| `figures/supplementary/diagnostics/` | `{snake_case}.png` | Base R model diagnostics |
| `figures/supplementary/meta_analysis/` | `{prefix}_{snake_case}.{pdf,png}` | Meta-analysis diagnostics |

- Use `save_manuscript_fig()` for all numbered figures (saves both PDF + PNG)
- Use raw `ggsave()` for exploratory figures, always to `exploratory/` subdirectory

### Data Outputs

| Type | Pattern | Example |
|------|---------|---------|
| CSV | `{domain}_{descriptive_name}.csv` | `survival_thresholds.csv`, `meta_analysis_results.csv` |
| RDS | `{descriptive_name}.rds` | `transition_matrix.rds`, `prepared_survival_cells.rds` |
| Parameter lists | `{context}_{type}_pars.rds` | `field_surv_pars.rds`, `nurs_growth_pars.rds` |

Domain prefixes: `survival_`, `growth_`, `meta_analysis_`, `expanded_meta_`, `sensitivity_`, `transition_`, `context_`, `climate_`, `cv_`, `heterogeneity_`, `heatwave_`, `manzello_`, `multistate_`, `stochastic_ipm_`, `distributed_lag_`, `canonical_`, `pipeline_`.

### Directory Variables in Scripts

| Variable | Points to |
|----------|-----------|
| `output_dir` | `06_analysis/output/` |
| `fig_dir` | `06_analysis/figures/` |
| `fig_dir_supp` / `fig_dir_supp_exploratory` | `figures/supplementary/exploratory/` |
| `fig_dir_supp_diagnostics` | `figures/supplementary/diagnostics/` |
| `supp_dir` / `fig_supp_dir` | `figures/supplementary/` |
| `param_dir` | `parameter_lists/` |

---

## Common Pitfalls

1. **Size labels**: Use `"SC1"`-`"SC5"` everywhere. The elasticity CSV uses `SC1_recruit` format — convert on load.
2. **Non-hierarchical bootstrap**: Resample studies first, then observations within.
3. **Missing overdispersion check**: Every binomial GLMM needs one.
4. **NOAA dominance**: 78% of data. Always run LOSO to check if results hold without it.
5. **Year column**: Use `survey_yr`, not `year` (conflicts with `base::year` in dplyr context).
6. **cairo_pdf**: Fails on some systems. `save_manuscript_fig()` has a fallback PDF device.
7. **Natural vs restoration**: NOT significant (p=0.238 at k=17, 22 effects). Study identity confounded with population type. Don't overinterpret.
8. **Biological realism S0 reproduction**: Script 60 passes `G_override = tm$growth_transitions` to `compute_lambda_from_survival()` so S0 reproduces the published λ = 0.9613 exactly. Do NOT recompute G from the current growth data file — it has drifted since the validated matrix was built.
9. **F_sex calibration**: Script 60 applies `SETTLEMENT_EFFICIENCY = 1e-4` to rescale Chamberland 2015 nursery recruit survival (0.028) down to wild broadcast-spawning rates. This is the only non-literal-from-literature parameter choice in the scenario framework — mention in Methods.
10. **Winter SST**: Script 51 uses NOAA ERSST v5 (monthly, 2° grid) via `rerddap::griddap()`. The daily OISST (`ncdcOisst21Agg`) repeatedly times out at ERDDAP for multi-year windows. Do NOT switch back.

---

## Running

```bash
cd 06_analysis/scripts
Rscript run_all.R              # Full pipeline (~60-75 min with biological-realism framework)
Rscript 01_data_preparation.R  # Individual script
Rscript -e "parse('13_transition_matrix.R')"  # Syntax check

# Biological-realism scenario framework (isolated rerun ~5-10 min)
Rscript 50_derive_outplant_age.R
Rscript 51_winter_sst_anomalies.R   # ~45s via NOAA ERSST v5 ERDDAP
Rscript 52_colony_lesion_state.R
Rscript 53_sexual_fecundity_layer.R
Rscript 54_sterility_lag_layer.R
Rscript 55_lesion_fecundity_penalty.R
Rscript 56_outplant_age_model.R
Rscript 57_winter_sst_survival_model.R
Rscript 58_depensatory_corallivory_layer.R
Rscript 59_microhabitat_depth_model.R
Rscript 60_scenario_comparison.R    # Emits biological_realism_scenarios.csv
Rscript 61_fig_biological_realism.R # Emits FigS29
```

---

## Documentation

| Doc | What |
|-----|------|
| `01_protocol/systematic_review_protocol.md` | Systematic review protocol: search strings, screening, flow diagram, risk of bias |
| `04_extraction/extraction_protocol.md` | Study-by-study data provenance (inclusion/exclusion, overlap rules, audit log) |
| `04_extraction/study_characteristics.md` | Per-study characteristics table |
| `04_extraction/risk_of_bias.md` | Risk of bias assessment |
| `04_extraction/raine_working_notes/Detmer_APAL_meta_analysis_notes.docx` | Raine's original working notes: per-study extraction decisions and assumptions |
| `04_extraction/data_integration_issues.md` | Individual vs. summary data integration: issues, resolution, comparison |
| `04_extraction/data_flow_diagram.md` | Mermaid diagram of the full data pipeline (individual + summary survival) |
| `07_reporting/manuscript/figure_legends.txt` | Figure legends, methods, results text |
| `07_reporting/manuscript/figure_table_map.md` | Script → figure filename map (FigS1–FigS30) |
| `07_reporting/internal/biological_realism_PRD.md` | Biological-realism scenario framework PRD: 10 scenarios (S0-S9), hypothesis-to-citation map, acceptance criteria |
