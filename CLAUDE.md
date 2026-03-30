# Project Guide

**Project:** *Acropora palmata* Size-Dependent Demography Synthesis
**Tech:** R 4.3+ | 33 analysis scripts | Target journal: *Coral Reefs* (Springer)

---

## What This Is

A synthesis of all existing *Acropora palmata* (Elkhorn Coral) demographic data across the Caribbean. The central question: **how do survival and growth vary as a function of colony size in restored vs. natural populations?**

We compiled ~9,500 individual-level observations from 6 studies plus 10 additional summary-level studies (16 unique studies contributing 21 study-level effects; NOAA split into FL Keys/Curacao/Navassa = 3 effects, Vardi 2011 split into Jamaica/PR/Virgin Gorda = 3 effects, Garrison & Ward 2008 split into control/relocated = 2 effects) across 11 Caribbean regions. The data are standardized to a common size metric (live planar tissue area, cm^2) and analyzed using GAMs, GLMMs, and random-effects meta-analysis. A Lefkovitch population projection matrix translates the size-dependent vital rates into a population growth rate (lambda) and elasticity analysis.

The web platform lives in a separate repo: [stier-lab/Detmer-2025-coral-platform](https://github.com/stier-lab/Detmer-2025-coral-platform).

---

## Critical Constraints

These apply to **every** analysis change:

- **I^2 = 96.3%** — extreme heterogeneity across studies. Any bootstrap must use **hierarchical resampling** (study -> observation).
- **NOAA = 78%** of individual-level data. Results may not generalize. Always check LOSO sensitivity.
- **Natural vs restoration confounded with study identity** — in individual-level data, natural colonies are ~99% NOAA. The expanded meta (k=16, 21 effects) has 9 natural + 12 restoration effects; difference not significant (p=0.110).
- **Fragmentation data from one study** (Vardi 2011, 13 rows). Cannot be improved without new data.
- Any new binomial GLMM needs an **overdispersion check** (`sum(pearson_resid^2) / rdf`).
- Meta-analysis: always use `test = "knha"` in `rma()` calls (Knapp-Hartung adjustment) for independent models; three-level `rma.mv()` is the primary model. Moderator analyses are exploratory at k=16 (21 effects).
- **Size measurement varies across studies**: L x W x %live (NOAA, Pausch), photo tracing (USGS, Kuffner), diameter^2 (Mendoza-Quiroz). Pooled analyses assume comparability.
- **Mortality definitions vary**: NOAA = no tissue/skeleton gone; Kuffner = >=50% tissue loss; others = no live tissue at interval end.

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
| Data Prep | 01 | Load, clean, standardize, assign size classes |
| Core | 02-07 | Survival/growth thresholds, growth rates, variance, data gaps |
| Robustness | 08-12 | Climate, power, cross-validation, context comparison, model selection |
| Synthesis | 13-17, 14b | Transition matrix, meta-analysis (k=5 and k=16/21 effects), sensitivity |
| Main Figures | 18, 19, 20b, 22 | 4 manuscript figures (Fig 1-4) |
| Supp Figures | 20, 20c, 21, 23-28 | FigS1-S16 |
| Verification | 23_verification | Pipeline integrity checks |
| Orchestrator | run_all | Runs everything in sequence |

### Figure Scripts -> Figures

| Script | Output | Content |
|--------|--------|---------|
| 18 | Fig 1 + FigS1 | Study landscape map + data availability; size distribution |
| 19 | Fig 2 | Survival GAM + RGR GAM + size-class synthesis (3 panels) |
| 20b | Fig 3 | Forest plot k=16 (21 effects) + regional survival (2 panels) |
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
| `05_data/standardized/apal_surv_ind.csv` | Individual survival | ~5,200 |
| `05_data/standardized/apal_growth_ind.csv` | Individual growth | ~4,300 |
| `05_data/standardized/apal_surv_summ.csv` | Summary survival (study-level) | ~30 |
| `05_data/standardized/apal_growth_summ.csv` | Summary growth | ~20 |
| `05_data/standardized/apal_fragmentation.csv` | Fragmentation (Vardi 2011) | 13 |
| `05_data/original/` | Raw source files — **DO NOT MODIFY** | 14 files |

### Key Outputs

| File | Producer | What |
|------|----------|------|
| `06_analysis/output/transition_matrix.csv` | Script 13 | 5x5 Lefkovitch projection matrix |
| `06_analysis/output/lambda_bootstrap_samples.rds` | Script 16 | 2000 bootstrap lambda values (1519 valid) |
| `06_analysis/output/expanded_meta_analysis_results.csv` | Script 14b | k=16 (21 effects) meta-analysis summary |
| `06_analysis/output/expanded_meta_analysis_study_effects.csv` | Script 14b | Per-study survival estimates |
| `06_analysis/output/size_class_survival_synthesis.csv` | Script 20 | SC1-SC5 survival by study |

---

## 6 Individual-Level Studies

| Study | Type | Region | n | Key Issue |
|-------|------|--------|---|-----------|
| NOAA_survey | Natural | FL, Curacao, Navassa | 4,031 | 78% of data; large colonies |
| pausch_et_al_2018 | Restoration | Florida | 966 | Fragment experiments |
| USGS_USVI_exp | Restoration | USVI | 46 | Outplanted 2019 |
| kuffner_et_al_2020 | Restoration | Florida | 52 | Mortality = >=50% tissue loss |
| mendoza_quiroz_et_al_2023 | Natural | Mexico | 52 | Some sizes from diameter only |
| fundemar_fragments | Restoration | Dominican Rep. | 43 | Nursery fragments |

10 additional studies contribute summary-level data only (16 unique studies, 21 study-level effects in expanded meta; NOAA, Vardi, and Garrison each split into sub-effects).

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

## Common Pitfalls

1. **Size labels**: Use `"SC1"`-`"SC5"` everywhere. The elasticity CSV uses `SC1_recruit` format — convert on load.
2. **Non-hierarchical bootstrap**: Resample studies first, then observations within.
3. **Missing overdispersion check**: Every binomial GLMM needs one.
4. **NOAA dominance**: 78% of data. Always run LOSO to check if results hold without it.
5. **Year column**: Use `survey_yr`, not `year` (conflicts with `base::year` in dplyr context).
6. **cairo_pdf**: Fails on some systems. `save_manuscript_fig()` has a fallback PDF device.
7. **Natural vs restoration**: NOT significant (p=0.110 at k=16, 21 effects). Study identity confounded with population type. Don't overinterpret.

---

## Running

```bash
cd 06_analysis/scripts
Rscript run_all.R              # Full pipeline (~45-60 min)
Rscript 01_data_preparation.R  # Individual script
Rscript -e "parse('13_transition_matrix.R')"  # Syntax check
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
| `07_reporting/figure_legends.txt` | Figure legends, methods, results text |
