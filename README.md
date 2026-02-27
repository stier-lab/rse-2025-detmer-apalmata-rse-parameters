# *Acropora palmata* — Population Viability Assessment

[![R Analysis](https://img.shields.io/badge/R-4.3+-blue.svg)](https://www.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

R analysis pipeline for a **population viability assessment** of *Acropora palmata* (Elkhorn Coral), updating the Vardi et al. (2012) Lefkovitch projection model with **~9,500 individual-level observations** from **6 studies** and **~10 additional summary-level studies** across the Caribbean. Manuscript submitted to *Coral Reefs*.

> **Interactive Platform**: An interactive web tool for exploring this data is available in a [separate repository](https://github.com/stier-lab/Detmer-2025-coral-platform).

> **Design Philosophy**: Transparency over false precision. Given extreme heterogeneity across studies (I² = 97.8%), we present data stratified by study by default, always show uncertainty, and warn when pooled estimates may be misleading.

---

## Key Results

| Finding | Value | Interpretation |
|---------|-------|----------------|
| **Population Growth Rate (λ)** | 0.986 | Declining ~1.4% annually |
| **Probability of Decline** | 87.3% | Evidence of population decline |
| **Most Critical Parameter** | SC5 Stasis | Adult survival has 54.8% elasticity |
| **Size-Survival R²** | 5.8% (GAM) | Size explains limited variance |
| **Study Heterogeneity (I²)** | 97.8% | Extreme between-study variation |
| **Expanded Meta-Analysis** | k=16, 81.1% | CI: 73.2–87.1% pooled survival |
| **Natural vs Restoration** | 85.1% vs 78.3% | p=0.30, NOT significant |
| **Updates Vardi (2012)** | Lefkovitch matrix | Largest dataset for species |

> See [docs/ANALYSIS_SUMMARY.md](docs/ANALYSIS_SUMMARY.md) for the complete Q&A breakdown with all effect sizes and p-values.

---

## Repository Structure

```
Detmer-2025-coral-parameters/
├── analysis/
│   ├── scripts/                 # 33 analysis scripts + orchestrator
│   │   ├── 01_data_preparation.R
│   │   ├── 02-07_*.R              # Core analysis
│   │   ├── 08-12_*.R              # Robustness & evaluation
│   │   ├── 13-17_*.R, 14b_*.R     # Synthesis (matrix, meta-analysis)
│   │   ├── 18-23_*.R, 20b/c_*.R   # Manuscript figures
│   │   ├── 24-28_*.R              # Supplementary figures
│   │   ├── run_all.R              # Pipeline orchestrator
│   │   └── utils/                 # Shared utilities
│   ├── output/                  # 168+ CSV/RDS result files (generated)
│   └── figures/                 # Publication figures (generated)
├── original_data/               # 14 raw source datasets (DO NOT MODIFY)
├── standardized_data/           # 7 cleaned, harmonized datasets
├── parameter_lists/             # 6 RDS model parameter outputs
├── literature/                  # 22 PDFs + 17 text summaries
└── docs/                        # Analysis documentation
```

---

## Quick Start

### Prerequisites

- **R** (≥ 4.3) with packages: `tidyverse`, `mgcv`, `lme4`, `metafor`, `patchwork`, `gratia`

### Run the Analysis Pipeline

```bash
cd analysis/scripts

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
Rscript -e "tryCatch({parse('analysis/scripts/01_data_preparation.R'); cat('OK\n')}, error=function(e) cat('FAIL:', e\$message, '\n'))"
```

---

## Analysis Pipeline

**33 scripts** organized in sequential series:

| Phase | Scripts | Purpose |
|-------|---------|---------|
| **Data Prep** | 01 | Load, clean, standardize, define size classes |
| **Core Analysis** | 02–07 | Survival/growth thresholds, variance partitioning, data gaps |
| **Robustness** | 08–12 | Climate, power, cross-validation, model selection |
| **Synthesis** | 13–17, 14b | Transition matrix, meta-analysis (k=16), sensitivity |
| **Main Figures** | 18–22, 20b/c | 4 manuscript figures |
| **Supp Figures** | 23–28 | Data gaps heatmap, supplementary S3–S14 |

---

## Size Classes

| Class | Range (cm²) | Description | Survival | n |
|-------|-------------|-------------|----------|---|
| SC1 | 0–25 | Recruits/fragments | 72.4% | 366 |
| SC2 | 25–100 | Small juveniles | 64.4% | 1,342 |
| SC3 | 100–500 | Large juveniles | 76.8% | 920 |
| SC4 | 500–2,000 | Small adults | 87.6% | 837 |
| SC5 | >2,000 | Large adults | 93.7% | 1,731 |

---

## Data Sources

6 individual-level studies (primary analysis) + ~10 summary-level studies (expanded meta-analysis):

| Study | Type | Region | n | Notes |
|-------|------|--------|---|-------|
| NOAA NCRMP | Natural | FL, Curacao, Navassa | 4,031 | 78% of data |
| Pausch et al. 2018 | Restoration | Florida | 966 | Fragment experiments |
| USGS USVI | Restoration | USVI | 46 | Outplanted 2019 |
| Kuffner et al. 2020 | Restoration | Florida | 52 | Outplanted 2018 |
| Mendoza-Quiroz et al. 2023 | Natural | Mexico | 52 | Caribbean coast |
| Fundemar | Restoration | Dominican Rep. | 43 | Nursery fragments |

See [docs/Data_Methodology_Reference.md](docs/Data_Methodology_Reference.md) for complete study-by-study methodology.

---

## Documentation

| Document | Purpose |
|----------|---------|
| [ANALYSIS_SUMMARY.md](docs/ANALYSIS_SUMMARY.md) | Complete results with effect sizes and p-values |
| [MANUSCRIPT_FIGURE_PLAN.md](docs/MANUSCRIPT_FIGURE_PLAN.md) | Main + supplementary figure designs |
| [Data_Methodology_Reference.md](docs/Data_Methodology_Reference.md) | Study-by-study data provenance |
| [STAKEHOLDER_RESULTS_SUMMARY.md](docs/STAKEHOLDER_RESULTS_SUMMARY.md) | Key findings for practitioners |

---

## Related

- **Interactive Platform**: [stier-lab/Detmer-2025-coral-platform](https://github.com/stier-lab/Detmer-2025-coral-platform) — React + R Plumber web app for exploring this data
- **Target Journal**: *Coral Reefs* (Springer)

---

## Contributors

- **Raine Detmer** — Lead Researcher, Data Integration
- **Adrian Stier** — Principal Investigator

## License

MIT License

## Citation

```
Detmer, R. & Stier, A. (2025). Size-structured population demography of Acropora
palmata: a Caribbean synthesis and updated population viability assessment.
GitHub: https://github.com/stier-lab/Detmer-2025-coral-parameters
```
