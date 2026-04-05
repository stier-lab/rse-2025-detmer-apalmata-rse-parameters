# Analysis Directory

This directory contains the maintained analytical surface for the *Acropora palmata* demography project.

## How To Navigate

- [scripts/README.md](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/scripts/README.md)
  Script map, numbering scheme, and execution order.
- [output/README.md](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/output/README.md)
  Generated result files, canonical prefixes, and interpretation notes.
- [figures/README.md](/Users/adrianstier/Detmer-2025-coral-parameters/06_analysis/figures/README.md)
  Canonical manuscript and supplementary figures plus support-only variants.

## Directory Roles

| Path | Role |
|---|---|
| `scripts/` | Source R scripts for data preparation, modeling, figure generation, scenario analyses, and verification |
| `output/` | Generated CSV and RDS outputs from the scripts |
| `figures/` | Generated manuscript, supplementary, diagnostic, and exploratory figures |

## Practical Rule

Use `scripts/` to understand what was run, `output/` to inspect numerical results, and `figures/` only after checking whether a given file is part of the canonical manuscript-facing build in [07_reporting/final_figure_table_set.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/final_figure_table_set.md).
