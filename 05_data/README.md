# Data Directory

This directory contains the data surface for the *Acropora palmata* demography project, from raw source files to analysis-ready tables and integration artifacts.

## How To Navigate

- [original/README.md](/Users/adrianstier/Detmer-2025-coral-parameters/05_data/original/README.md)
  Raw source files and provenance rules.
- [standardized/README.md](/Users/adrianstier/Detmer-2025-coral-parameters/05_data/standardized/README.md)
  Canonical analysis-ready datasets, record counts, and column guidance.
- [integration/README.md](/Users/adrianstier/Detmer-2025-coral-parameters/05_data/integration/README.md)
  Integration workflow, harmonization notes, and collaborator-facing materials.

## Directory Roles

| Path | Role |
|---|---|
| `original/` | Immutable raw source files and exports used during integration |
| `standardized/` | Cleaned tables used directly by the maintained analytical pipeline |
| `integration/` | Integration scripts, notebooks, and supporting documentation for assembly and QA |
| `ai_extracted/` | AI-assisted extraction audit trail retained for transparency, not as canonical analysis input |

## Practical Rule

Use `standardized/` for analysis. Use `original/` and `integration/` when you need provenance, harmonization details, or to rebuild standardized tables. Treat `ai_extracted/` as supporting audit material rather than a source of truth.

## New Data Onboarding

When new site data arrives, the expected flow is:

1. Preserve the raw source in `original/`.
2. Standardize it into the canonical tables in `standardized/` via a dedicated `00_standardize_<site>.R` helper under `06_analysis/scripts/`.
3. Update the standardized-table registry in [data_registry.csv](/Users/adrianstier/Detmer-2025-coral-parameters/05_data/standardized/data_registry.csv) if a new maintained table is added or an existing table’s schema changes.
4. Rerun the full pipeline with `Rscript 06_analysis/scripts/run_all.R`.

The registry-backed inventory written to [standardized_data_inventory.csv](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/standardized_data_inventory.csv) is the first place to confirm that the maintained inputs still match the expected schema.
