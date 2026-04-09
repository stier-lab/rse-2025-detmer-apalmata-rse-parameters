# *Acropora palmata* — Population Viability Assessment

[![R Analysis](https://img.shields.io/badge/R-4.3+-blue.svg)](https://www.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

R analysis pipeline for a **population viability assessment** of *Acropora palmata* (Elkhorn Coral), updating the Vardi et al. (2012) Lefkovitch projection model with **~14,100 individual-level observations** from **7 studies** (including the Neely et al. 2022 FKNMS dataset) and **10 additional summary-level studies** (17 unique studies contributing 22 study-level effects; NOAA split into FL Keys/Curacao/Navassa, Vardi 2011 split into Jamaica/Puerto Rico/Virgin Gorda, Garrison & Ward 2008 split into control/relocated, and Neely 2022 as a single FL Keys effect) across **13 Caribbean regions**. The analytical focus is size-dependent demography, population viability, disturbance regime context, and restoration implications. Manuscript targeting *Coral Reefs*.

**Central question:** How do *Acropora palmata* survival and growth vary with colony size across the Caribbean, and what does this mean for population viability under chronic disturbance and restoration?

> **Interactive Platform**: An interactive web tool for exploring this data is available in a [separate repository](https://github.com/stier-lab/Detmer-2025-coral-platform).

> **Design Philosophy**: Transparency over false precision. Given extreme heterogeneity across studies, the repo defaults to stratified views, explicit uncertainty, and clear separation between canonical manuscript outputs, supporting analyses, and exploratory extensions.

> **Navigation**: Start with [06_analysis/README.md](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/README.md) for the analysis surface and [07_reporting/README.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/README.md) for manuscript-facing documents.

---

## Parent Goal and Paper Goals

### Parent Goal

Build a Caribbean-wide, size-structured understanding of *Acropora palmata* demography that is good enough to support defensible inference about population viability, disturbance exposure, and restoration decision-making.

### Paper Goals

1. Quantify how demographic rates vary across colony size, including survival, growth, shrinkage, and fragmentation.
2. Test whether those size relationships are nonlinear, with thresholds or inflection points rather than simple linear scaling.
3. Translate size-structured demographic rates into population-viability consequences, especially the size classes and transitions that drive `λ`, decline risk, and recovery potential.
4. Treat disturbance as part of the demographic regime facing *A. palmata*, including hurricanes, disease, heatwaves, cold events, predators, and chronic stressors.
5. Map disturbance through Caribbean time and space, then connect disturbance windows to observed demographic performance.
6. Compare natural-colony and restoration-fragment demography, including when differences persist after accounting for size.
7. Evaluate what the synthesis implies for restoration: target sizes, habitats, regions, and disturbance windows that are more or less favorable for persistence.
8. Quantify heterogeneity and transferability across studies, regions, and years so pooled estimates are interpreted with appropriate caution.
9. Make uncertainty and data gaps explicit, especially for recruitment, fecundity, chronic stress, and large-adult dynamics outside Florida.

For a more detailed goal-to-analysis roadmap, see [07_reporting/paper_scope_and_analysis_roadmap.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/paper_scope_and_analysis_roadmap.md).

---

## Systematic Review Structure

This repository follows a **PRISMA-first layout** where top-level directories map to the stages of a systematic review and meta-analysis:

| Directory | PRISMA Stage | Contents |
|-----------|-------------|----------|
| `01_protocol/` | Registration | Pre-analysis plan, systematic review protocol |
| `02_search/` | Identification | Search strings, Elicit/Google Scholar exports |
| `03_screening/` | Screening | Full-text screening decisions (104 data rows, 101 unique assessments), IRR assessment |
| `04_extraction/` | Data extraction | Extraction protocol, study characteristics, risk of bias, original researcher notes |
| `05_data/` | Data | Original (14 raw files), standardized (analysis-ready CSVs), integration artifacts, and AI-extracted audit trail |
| `06_analysis/` | Analysis | 54 top-level R scripts, generated outputs, figures, and directory indexes |
| `07_reporting/` | Reporting | Manuscript methods + narrative drafts, figure legends, build maps, crosswalks, advanced-model reports, and support tables |

This organization ensures every step from literature search to final analysis is traceable and reproducible, consistent with PRISMA 2020 guidelines. For data-surface navigation, start with [05_data/README.md](/Users/adrianstier/Detmer-2025-coral-parameters/05_data/README.md).

---

## Key Results

| Finding | Value | Interpretation |
|---------|-------|----------------|
| **Population Growth Rate (λ)** | 0.888 (CI: 0.740–0.959) | Deterministic λ is well below replacement; bootstrap CI excludes 1.0, indicating consistent decline |
| **Most Critical Parameter** | SC5 Stasis | Large-adult persistence contributes 58.6% of matrix-cell elasticity |
| **Survival Nonlinearity** | Threshold ~7,498 cm² | Supported sigmoidal survival response, but weakly stable across study folds |
| **Core Growth Nonlinearity** | RGR threshold at 36.9 cm² | The steepest proportional-growth shift occurs early in ontogeny |
| **Shrinkage Frequency** | 39.4% | Matrix-compatible growth records frequently show tissue loss rather than simple positive growth |
| **Disturbance × Size** | Survival interaction `p = 6.93e-4` | Disturbance modifies the size-survival relationship rather than acting as background noise |
| **Study Heterogeneity (I²)** | 97.2% (expanded meta-analysis, k=17) | Extreme between-study variation |
| **Expanded Meta-Analysis** | k=17 (22 effects), 78.0% | CI: 70.1–84.3% pooled annual survival |
| **Natural vs Restoration** | 84.1% vs 74.5% | 9.5 pp difference, p=0.153 |
| **Updates Vardi (2012)** | Lefkovitch matrix | Largest dataset for species |
| **Pre-2023 baseline** | All vital rates pre-date the 2023 Florida heatwave | Manzello et al. (2025, *Science*) documented functional extinction of *A. palmata* from Florida at 16-20 DHW. This matrix describes the chronic regime before that event. |
| **Zero fecundity assumption** | λ = 0.888 assumes no sexual recruitment | Fragmentation is the only reproduction pathway in the model. Even minimal fecundity (1 recruit/adult/yr) would push λ closer to or above 1.0. |

> For manuscript-facing interpretation, use [07_reporting/manuscript_narrative_integration.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/manuscript_narrative_integration.md), [07_reporting/claim_output_crosswalk.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/claim_output_crosswalk.md), and [07_reporting/final_figure_table_set.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/final_figure_table_set.md).

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
│   └── full_text_screening.csv       # 104 data rows (101 unique assessments)
├── 04_extraction/                  # Data extraction phase
│   ├── extraction_protocol.md        # Inclusion/exclusion, overlap rules, audit log
│   ├── study_characteristics.md
│   ├── extraction_details.md
│   ├── risk_of_bias.md
│   ├── data_integration_issues.md    # Individual vs summary data integration
│   ├── data_flow_diagram.md          # Mermaid pipeline diagram
│   └── raine_working_notes/          # Original researcher's Excel trackers + notes
├── 05_data/                        # All data
│   ├── original/                     # 14 raw source files (DO NOT MODIFY)
│   ├── standardized/                 # Cleaned analysis-ready CSVs
│   ├── ai_extracted/                 # AI extraction audit trail
│   └── integration/                  # APAL_data_integration.rmd
├── 06_analysis/                    # Statistical analysis
│   ├── scripts/                      # 54 top-level R scripts + utils/
│   │   ├── 01_data_preparation.R
│   │   ├── 02-07_*.R                   # Core analysis
│   │   ├── 08-12_*.R                   # Robustness & evaluation
│   │   ├── 13-17_*.R, 14b_*.R          # Synthesis (matrix, meta-analysis k=17/22 effects)
│   │   ├── 18-23_*.R, 20b/c_*.R        # Manuscript figures
│   │   ├── 24-28_*.R                   # Supplementary figures
│   │   ├── run_all.R                   # Pipeline orchestrator
│   │   └── utils/                      # Shared utilities (theme, palette, constants)
│   ├── output/                       # 286 generated CSV/RDS result files
│   └── figures/                      # Publication figures (generated)
├── 07_reporting/                   # Manuscript outputs
│   ├── README.md
│   ├── manuscript_methods_draft.md
│   ├── manuscript_narrative_integration.md
│   ├── figure_legends.txt
│   ├── paper_scope_and_analysis_roadmap.md
│   ├── claim_output_crosswalk.md
│   ├── consistency_audit.md
│   ├── figure_table_build_map.md
│   ├── final_figure_table_set.md
│   ├── final_filename_normalization_plan.md
│   ├── analysis_inventory_labels.md
│   ├── transferability_summary.md
│   ├── recruitment_fecundity_scope_note.md
│   ├── conceptual_summary_figure.md
│   ├── conceptual_summary.svg
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

# Run the complete maintained pipeline
# Long-running; matrix bootstrap and advanced models dominate runtime.
# This is the canonical refresh path after adding or updating site data.
Rscript run_all.R

# Or run individual scripts
Rscript 01_data_preparation.R
Rscript 13_transition_matrix.R
Rscript 14b_expanded_meta_analysis.R
Rscript 18_fig1_study_landscape.R
```

### Run the Nonlinearity Workflow Only

```bash
Rscript 06_analysis/scripts/01_data_preparation.R
Rscript 06_analysis/scripts/02_survival_thresholds.R
Rscript 06_analysis/scripts/03_growth_thresholds.R
Rscript 06_analysis/scripts/04_growth_rate_comparison.R
Rscript 06_analysis/scripts/25_supp_S5_S6_S7_thresholds_growth.R
```

### Add New Site Data and Rebuild Everything

The maintained pipeline is now set up so that new site data can flow through the same refresh path, rather than requiring manual edits to downstream tables.

1. Add or update raw source files under `05_data/original/`.
2. Standardize them in a dedicated `06_analysis/scripts/00_standardize_<site>.R` script that appends or rebuilds the canonical standardized tables.
3. Register any new or changed standardized table in [data_registry.csv](/Users/adrianstier/Detmer-2025-coral-parameters/05_data/standardized/data_registry.csv).
4. Rerun `Rscript 06_analysis/scripts/run_all.R`.

After rerun, check these canonical refresh artifacts:

- [standardized_data_inventory.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/standardized_data_inventory.csv)
- [canonical_statistics.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/canonical_statistics.csv)
- [pipeline_assertion_checks.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/pipeline_assertion_checks.csv)
- [canonical_artifact_status.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/canonical_artifact_status.csv)
- [pipeline_refresh_report.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/generated/pipeline_refresh_report.md)

### Verify Script Syntax

```bash
Rscript -e "tryCatch({parse('06_analysis/scripts/01_data_preparation.R'); cat('OK\n')}, error=function(e) cat('FAIL:', e\$message, '\n'))"
```

---

## Analysis Pipeline

The maintained analysis surface currently contains **54 top-level R scripts** in `06_analysis/scripts/`, including standardization helpers, numbered analyses, advanced dynamic extensions, and verification utilities.

| Phase | Scripts | Purpose |
|-------|---------|---------|
| **Data Prep** | 01 | Load, clean, standardize, define size classes |
| **Core Analysis** | 02–07 | Survival/growth thresholds, variance partitioning, data gaps |
| **Robustness** | 08–12 | Climate, power, cross-validation, model selection |
| **Synthesis** | 13–17, 14b | Transition matrix, meta-analysis (k=17, 22 effects), sensitivity |
| **Main Figures** | 18–22, 20b/c | 4 manuscript figures |
| **Supp Figures** | 23–28 | Data gaps heatmap, supplementary S3–S14 |
| **Context & Disturbance** | 29–40, 31b | Natural/restoration sensitivity, disturbance overlays, audits, subtype decomposition, completeness products, and scenario extensions |
| **Advanced Dynamic Models** | 41–47 | Multistate, joint, stochastic-IPM, regime-switching, distributed-lag, frailty, and spatiotemporal extensions |

### Core Nonlinearity Analyses Retained

The nonlinear size-dependent analyses are a core part of the project and remain in the repo:

- `06_analysis/scripts/02_survival_thresholds.R` tests whether survival departs from a simple linear size effect using GAMs, second derivatives, segmented fits, and leave-one-study-out sensitivity.
- `06_analysis/scripts/03_growth_thresholds.R` detects nonlinear thresholds for absolute growth, relative growth rate, and probability of positive growth using the Detmer et al. (2025) threshold framework.
- `06_analysis/scripts/04_growth_rate_comparison.R` compares AGR vs RGR scaling and allometry to make the curvature biologically interpretable.
- `06_analysis/scripts/25_supp_S5_S6_S7_thresholds_growth.R` turns those threshold and allometry results into the manuscript-ready supplementary figures.

What was removed in cleanup was the ad hoc thresholding that had been bolted onto climate and matrix scripts. The size-threshold framework above remains part of the main analytical story.

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

### Tier 1: Individual-level data (7 studies)

| Study | Type | Region | n | Notes |
|-------|------|--------|---|-------|
| NOAA NCRMP | Natural | FL, Curacao, Navassa | 4,025 | Largest dataset |
| Neely et al. 2022 | Natural | FL Keys | 878 | 2014 disease catastrophe flagged |
| Pausch et al. 2018 | Restoration | Florida | 789 | Fragment experiments |
| USGS USVI | Restoration | USVI | 92 | Outplanted 2019 |
| Kuffner et al. 2020 | Restoration | Florida | 106 | Outplanted 2018 |
| Mendoza-Quiroz et al. 2023 | Natural | Mexico | 45 | Caribbean coast |
| Fundemar | Restoration | Dominican Rep. | 156 | Nursery fragments |

### Tier 2: Summary-level data (10 additional studies)

7 studies hand-extracted by Detmer (2025) + 3 studies AI-extracted (March 2026, tagged `[AI_EXTRACTED]`).

| Study | Type | Region | n | Annual Surv. | Extractor |
|-------|------|--------|---|-------------|-----------|
| Vardi 2011 (3 regions) | Natural | Jamaica, PR, V. Gorda | 245 | 76–96% | Hand |
| Bruckner & Bruckner 2001 | Restoration | Puerto Rico | 105 | 90.5% | Hand |
| Ortiz Prosper 2005 | Restoration | Puerto Rico | 207 | 78.7% | Hand |
| Forrester et al. 2013 | Restoration | BVI | 257 | 53.3% | Hand |
| Rosales et al. 2024 | Restoration | FL Keys | 58 | 79.3% | Hand |
| Maurer et al. 2022 | Restoration | Bahamas | 24 | 95.8% | Hand |
| Williams & Miller 2010 | Restoration | FL Keys | 18 | 77.8% | Hand |
| Garrison & Ward 2008 (2 effects) | Natural + Restoration | USVI | 75 | 80% / 55% | Hand |
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

2. **Standardized data** (`05_data/standardized/`): Produced by `05_data/integration/APAL_data_integration.rmd` from original data. Column definitions and size conversion methods in [`05_data/standardized/README.md`](05_data/standardized/README.md). The standardization step (`05_data/integration/APAL_data_integration.rmd`) is a one-time process run outside the main pipeline -- it converts the 14 raw source files into the 6 canonical CSVs. Script 01 then loads these CSVs and builds the analysis-ready RDS files.

3. **AI-extracted data** (`05_data/ai_extracted/`): Extracted from published PDFs by AI (Claude, March 2026). Every row tagged `[AI_EXTRACTED]` in study_notes. Each value was independently audited against the source PDF by a separate verification agent. Audit results documented in [`04_extraction/extraction_protocol.md`](04_extraction/extraction_protocol.md) Section 8.

4. **Analysis outputs** (`06_analysis/output/`): Generated by the R pipeline. Regenerate with `Rscript run_all.R`. Use [06_analysis/output/README.md](06_analysis/output/README.md) to distinguish canonical manuscript outputs from support-only and exploratory files.

### Inclusion/exclusion criteria

Formal criteria for which studies enter the meta-analysis are documented in [`04_extraction/extraction_protocol.md`](04_extraction/extraction_protocol.md), Sections 2–4. Key rules:

- **Longitudinal only**: Must track identified colonies over time. Cross-sectional health snapshots excluded.
- **No NOAA overlap**: Studies using the same tagged colonies as `NOAA_survey` are excluded (5 papers affected).
- **No invalid proxies**: Partial mortality prevalence ≠ whole-colony survival (1 study removed after audit).
- **Recruits excluded**: Post-settlement corals <1 cm² are a different life stage (4 studies).

### Reproducing the analysis

```bash
# Full pipeline
cd 06_analysis/scripts
Rscript run_all.R

# Key individual scripts
Rscript 01_data_preparation.R      # Data cleaning
Rscript 13_transition_matrix.R      # Population model (slow: 2000 bootstrap iterations)
Rscript 14b_expanded_meta_analysis.R  # Meta-analysis k=17 (22 effects)
```

For figure numbering and manuscript-facing build targets, use [07_reporting/figure_table_build_map.md](07_reporting/figure_table_build_map.md) and [07_reporting/final_figure_table_set.md](07_reporting/final_figure_table_set.md).

---

## Documentation

| Document | Purpose |
|----------|---------|
| [01_protocol/systematic_review_protocol.md](01_protocol/systematic_review_protocol.md) | Systematic review protocol: search strings, screening process, PRISMA flow diagram, risk of bias |
| [04_extraction/extraction_protocol.md](04_extraction/extraction_protocol.md) | Inclusion/exclusion criteria, overlap rules, audit log, file inventory |
| [04_extraction/study_characteristics.md](04_extraction/study_characteristics.md) | Per-study characteristics table |
| [04_extraction/risk_of_bias.md](04_extraction/risk_of_bias.md) | Risk of bias assessment |
| [04_extraction/raine_working_notes/](04_extraction/raine_working_notes/) | Original working notes: per-study extraction decisions, assumptions, caveats |
| [04_extraction/data_integration_issues.md](04_extraction/data_integration_issues.md) | Individual vs. summary data integration: issues, resolution, survival comparison |
| [04_extraction/data_flow_diagram.md](04_extraction/data_flow_diagram.md) | Mermaid diagram of the full data pipeline |
| [06_analysis/README.md](06_analysis/README.md) | Analysis directory index: scripts, outputs, figures, and how to navigate them |
| [06_analysis/scripts/README.md](06_analysis/scripts/README.md) | Script-by-script map of the maintained analysis surface |
| [06_analysis/output/README.md](06_analysis/output/README.md) | Output prefixes, canonical result files, and interpretation notes |
| [06_analysis/figures/README.md](06_analysis/figures/README.md) | Canonical manuscript/supplement figure set plus support-only figure variants |
| [05_data/original/README.md](05_data/original/README.md) | Column definitions for all 14 raw data files |
| [05_data/standardized/README.md](05_data/standardized/README.md) | Column definitions for all standardized datasets, size conversion methods |
| [07_reporting/README.md](07_reporting/README.md) | Reporting directory index: active manuscript docs, build maps, and support notes |
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
