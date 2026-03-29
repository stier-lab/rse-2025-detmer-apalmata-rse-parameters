# *Acropora palmata* — Population Viability Assessment

[![R Analysis](https://img.shields.io/badge/R-4.3+-blue.svg)](https://www.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

R analysis pipeline for a **population viability assessment** of *Acropora palmata* (Elkhorn Coral), updating the Vardi et al. (2012) Lefkovitch projection model with **~9,500 individual-level observations** from **6 studies** and **12 additional summary-level studies** (18 unique studies yielding k=18 study-level effects) across **11 Caribbean regions**. Manuscript targeting *Coral Reefs*.

> **Interactive Platform**: An interactive web tool for exploring this data is available in a [separate repository](https://github.com/stier-lab/Detmer-2025-coral-platform).

> **Design Philosophy**: Transparency over false precision. Given extreme heterogeneity across studies (I² = 96.4%), we present data stratified by study by default, always show uncertainty, and warn when pooled estimates may be misleading.

---

## Systematic Review Structure

This repository follows a **PRISMA-first layout** where top-level directories map to the stages of a systematic review and meta-analysis:

| Directory | PRISMA Stage | Contents |
|-----------|-------------|----------|
| `01_protocol/` | Registration | Pre-analysis plan, systematic review protocol |
| `02_search/` | Identification | Search strings, Elicit/Google Scholar exports |
| `03_screening/` | Screening | Full-text screening decisions (91 studies), IRR assessment |
| `04_extraction/` | Data extraction | Extraction protocol, study characteristics, risk of bias, original researcher notes |
| `05_data/` | Data | Original (14 raw files), standardized (analysis-ready CSVs), AI-extracted audit trail |
| `06_analysis/` | Analysis | 33 R scripts, generated outputs, figures |
| `07_reporting/` | Reporting | Manuscript methods draft, figure legends, tables |

This organization ensures every step from literature search to final analysis is traceable and reproducible, consistent with PRISMA 2020 guidelines.

---

## Key Results

| Finding | Value | Interpretation |
|---------|-------|----------------|
| **Population Growth Rate (λ)** | 1.001 (CI: 0.863–1.035) | Deterministic λ near-stable; bootstrap 95% CI spans decline and growth |
| **Probability of Decline** | 65.1% | Uncertain trajectory (1519 of 2000 bootstrap replicates valid) |
| **Most Critical Parameter** | SC5 Stasis | Adult survival has 74.0% elasticity |
| **Size-Survival R²** | 5.8% (GAM) | Size explains limited variance |
| **Study Heterogeneity (I²)** | 96.4% | Extreme between-study variation |
| **Expanded Meta-Analysis** | k=18, 79.2% | CI: 70.6–85.7% pooled annual survival |
| **Natural vs Restoration** | 83.5% vs 76.0% | 7.5 pp difference, p=0.405 |
| **Updates Vardi (2012)** | Lefkovitch matrix | Largest dataset for species |

> See `docs/ANALYSIS_SUMMARY.md` (archived) for the complete Q&A breakdown with all effect sizes and p-values.

---

## Repository Structure

```
Detmer-2025-coral-parameters/
├── 01_protocol/                    # PRISMA registration & pre-analysis plan
│   ├── systematic_review_protocol.md
│   └── PRISMA_TODO_resolution.md
├── 02_search/                      # Identification phase
│   ├── search_strings.md
│   ├── search_summary.md
│   └── search_results/             # Elicit + Google Scholar exports
├── 03_screening/                   # Screening phase
│   └── full_text_screening.csv       # 91 studies with decisions
├── 04_extraction/                  # Data extraction phase
│   ├── extraction_protocol.md        # Inclusion/exclusion, overlap rules, audit log
│   ├── study_characteristics.md
│   ├── extraction_details.md
│   ├── risk_of_bias.md
│   └── raine_working_notes/          # Original researcher's Excel trackers + notes
├── 05_data/                        # All data
│   ├── original/                     # 14 raw source files (DO NOT MODIFY)
│   ├── standardized/                 # Cleaned analysis-ready CSVs
│   ├── ai_extracted/                 # AI extraction audit trail
│   └── integration/                  # APAL_data_integration.rmd
├── 06_analysis/                    # Statistical analysis
│   ├── scripts/                      # 33 R scripts + utils/
│   │   ├── 01_data_preparation.R
│   │   ├── 02-07_*.R                   # Core analysis
│   │   ├── 08-12_*.R                   # Robustness & evaluation
│   │   ├── 13-17_*.R, 14b_*.R          # Synthesis (matrix, meta-analysis k=18)
│   │   ├── 18-23_*.R, 20b/c_*.R        # Manuscript figures
│   │   ├── 24-28_*.R                   # Supplementary figures
│   │   ├── run_all.R                   # Pipeline orchestrator
│   │   └── utils/                      # Shared utilities (theme, palette, constants)
│   ├── output/                       # 168+ CSV/RDS result files (generated)
│   └── figures/                      # Publication figures (generated)
├── 07_reporting/                   # Manuscript outputs
│   ├── manuscript_methods_draft.md
│   ├── figure_legends.txt
│   └── tables/
├── literature/                     # 145 PDFs organized by role
│   └── pdfs/{data_studies,context,methods,restoration,preprints}/
├── parameter_lists/                # 6 RDS model parameter outputs
├── CLAUDE.md
└── README.md
```

---

## Quick Start

### Prerequisites

- **R** (≥ 4.3) with packages: `tidyverse`, `mgcv`, `lme4`, `metafor`, `patchwork`, `gratia`

### Run the Analysis Pipeline

```bash
cd 06_analysis/scripts

# Run complete pipeline (~45-60 min)
Rscript run_all.R

# Or run individual scripts
Rscript 01_data_preparation.R
Rscript 13_transition_matrix.R
Rscript 14b_expanded_meta_analysis.R
Rscript 18_fig1_study_landscape.R
```

### Verify Script Syntax

```bash
Rscript -e "tryCatch({parse('06_analysis/scripts/01_data_preparation.R'); cat('OK\n')}, error=function(e) cat('FAIL:', e\$message, '\n'))"
```

---

## Analysis Pipeline

**33 scripts** organized in sequential series:

| Phase | Scripts | Purpose |
|-------|---------|---------|
| **Data Prep** | 01 | Load, clean, standardize, define size classes |
| **Core Analysis** | 02–07 | Survival/growth thresholds, variance partitioning, data gaps |
| **Robustness** | 08–12 | Climate, power, cross-validation, model selection |
| **Synthesis** | 13–17, 14b | Transition matrix, meta-analysis (k=18), sensitivity |
| **Main Figures** | 18–22, 20b/c | 4 manuscript figures |
| **Supp Figures** | 23–28 | Data gaps heatmap, supplementary S3–S14 |

---

## Size Classes

| Class | Range (cm²) | Description |
|-------|-------------|-------------|
| SC1 | 0–10 | Recruits/settlers |
| SC2 | 10–100 | Small juveniles |
| SC3 | 100–900 | Large juveniles |
| SC4 | 900–4,000 | Subadults |
| SC5 | >4,000 | Reproductive adults |

---

## Data Sources

### Tier 1: Individual-level data (6 studies)

| Study | Type | Region | n | Notes |
|-------|------|--------|---|-------|
| NOAA NCRMP | Natural | FL, Curacao, Navassa | 4,025 | 78% of individual data |
| Pausch et al. 2018 | Restoration | Florida | 789 | Fragment experiments |
| USGS USVI | Restoration | USVI | 92 | Outplanted 2019 |
| Kuffner et al. 2020 | Restoration | Florida | 106 | Outplanted 2018 |
| Mendoza-Quiroz et al. 2023 | Natural | Mexico | 45 | Caribbean coast |
| Fundemar | Restoration | Dominican Rep. | 156 | Nursery fragments |

### Tier 2: Summary-level data (12 additional study-level effects)

7 studies hand-extracted by Detmer (2025) + 5 studies AI-extracted (March 2026, tagged `[AI_EXTRACTED]`).

| Study | Type | Region | n | Annual Surv. | Extractor |
|-------|------|--------|---|-------------|-----------|
| Vardi 2011 (3 regions) | Natural | Jamaica, PR, V. Gorda | 245 | 76–96% | Hand |
| Bruckner & Bruckner 2001 | Restoration | Puerto Rico | 105 | 90.5% | Hand |
| Ortiz Prosper 2005 | Restoration | Puerto Rico | 207 | 78.7% | Hand |
| Forrester et al. 2013 | Restoration | BVI | 257 | 53.3% | Hand |
| Rosales et al. 2024 | Restoration | FL Keys | 58 | 79.3% | Hand |
| Maurer et al. 2022 | Restoration | Bahamas | 24 | 95.8% | Hand |
| Williams & Miller 2010 | Restoration | FL Keys | 18 | 77.8% | Hand |
| Garrison & Ward 2008 | Natural | USVI | 45 | 68.9% | Hand |
| Rogers & Muller 2012 | Natural | USVI | 69 | 94.2% | AI |
| Ramos-Romero et al. 2025 | Restoration | Cuba | 200 | 70.5% | AI |
| Rogers et al. 1982 | Natural | USVI | 12 | 75.0% | AI |

**Excluded after overlap audit:** Roth et al. 2013 (USVI, n=27) was removed because it uses the same Haulover Bay colony data as Rogers & Muller 2012, as confirmed by the paper's explicit citation and acknowledgments.

See [04_extraction/extraction_protocol.md](04_extraction/extraction_protocol.md) for inclusion/exclusion criteria, overlap decision rules, and audit log.

---

## Reproducibility

### Data provenance

All data in this repository has a documented chain of custody:

1. **Original data** (`05_data/original/`): Raw files from published data repositories (NOAA NCEI, USGS, InPort) or direct sharing. Each file has column definitions in [`05_data/original/README.md`](05_data/original/README.md). **These files must not be modified.**

2. **Standardized data** (`05_data/standardized/`): Produced by `05_data/integration/APAL_data_integration.rmd` from original data. Column definitions and size conversion methods in [`05_data/standardized/README.md`](05_data/standardized/README.md).

3. **AI-extracted data** (`05_data/ai_extracted/`): Extracted from published PDFs by AI (Claude, March 2026). Every row tagged `[AI_EXTRACTED]` in study_notes. Each value was independently audited against the source PDF by a separate verification agent. Audit results documented in [`04_extraction/extraction_protocol.md`](04_extraction/extraction_protocol.md) Section 8.

4. **Analysis outputs** (`06_analysis/output/`): Generated by the R pipeline. Regenerate with `Rscript run_all.R`.

### Inclusion/exclusion criteria

Formal criteria for which studies enter the meta-analysis are documented in [`04_extraction/extraction_protocol.md`](04_extraction/extraction_protocol.md), Sections 2–4. Key rules:

- **Longitudinal only**: Must track identified colonies over time. Cross-sectional health snapshots excluded.
- **No NOAA overlap**: Studies using the same tagged colonies as `NOAA_survey` are excluded (5 papers affected).
- **No invalid proxies**: Partial mortality prevalence ≠ whole-colony survival (1 study removed after audit).
- **Recruits excluded**: Post-settlement corals <1 cm² are a different life stage (4 studies).

### Reproducing the analysis

```bash
# Full pipeline (33 scripts, ~45-60 min)
cd 06_analysis/scripts
Rscript run_all.R

# Key individual scripts
Rscript 01_data_preparation.R      # Data cleaning
Rscript 13_transition_matrix.R      # Population model (slow: 2000 bootstrap iterations)
Rscript 14b_expanded_meta_analysis.R  # Meta-analysis k=18
```

Note: Some scripts (02, 04, 05) have a pre-existing `dplyr::select` masking issue. The key outputs (meta-analysis, transition matrix, all manuscript figures) generate successfully.

---

## Documentation

| Document | Purpose |
|----------|---------|
| [01_protocol/systematic_review_protocol.md](01_protocol/systematic_review_protocol.md) | Systematic review protocol: search strings, screening process, PRISMA flow diagram, risk of bias |
| [04_extraction/extraction_protocol.md](04_extraction/extraction_protocol.md) | Inclusion/exclusion criteria, overlap rules, audit log, file inventory |
| [04_extraction/study_characteristics.md](04_extraction/study_characteristics.md) | Per-study characteristics table |
| [04_extraction/risk_of_bias.md](04_extraction/risk_of_bias.md) | Risk of bias assessment |
| [04_extraction/raine_working_notes/](04_extraction/raine_working_notes/) | Original working notes: per-study extraction decisions, assumptions, caveats |
| [05_data/original/README.md](05_data/original/README.md) | Column definitions for all 14 raw data files |
| [05_data/standardized/README.md](05_data/standardized/README.md) | Column definitions for all standardized datasets, size conversion methods |
| [07_reporting/figure_legends.txt](07_reporting/figure_legends.txt) | Figure legends, methods, results text |
| [CLAUDE.md](CLAUDE.md) | Project conventions for AI-assisted development |

---

## Related

- **Interactive Platform**: [stier-lab/Detmer-2025-coral-platform](https://github.com/stier-lab/Detmer-2025-coral-platform) — React + R Plumber web app for exploring this data
- **Target Journal**: *Coral Reefs* (Springer)

---

## Contributors

- **Raine Detmer** — Lead Researcher, Data Integration, Population Modeling
- **Adrian Stier** — Principal Investigator

## License

MIT License

## Citation

```
Detmer, R. & Stier, A. (2025). Size-structured population demography of Acropora
palmata: a Caribbean synthesis and updated population viability assessment.
GitHub: https://github.com/stier-lab/Detmer-2025-coral-parameters
```
