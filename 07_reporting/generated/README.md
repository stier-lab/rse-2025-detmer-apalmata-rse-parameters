# Generated Reporting Artifacts

This directory contains machine-written reporting artifacts produced by the maintained pipeline.

## Generated Files

| File | Role |
|---|---|
| [canonical_statistics.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/generated/canonical_statistics.md) | Canonical machine-readable summary of manuscript-facing numeric results |
| [canonical_artifact_status.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/generated/canonical_artifact_status.md) | Presence and same-run regeneration status for canonical outputs, figures, and tables |
| [pipeline_refresh_report.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/generated/pipeline_refresh_report.md) | Summary of the most recent pipeline refresh audit |
| [standardized_data_inventory.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/generated/standardized_data_inventory.md) | Snapshot of registered standardized inputs, row counts, hashes, and coverage metadata |

## Practical Rule

Treat this directory as generated output. Do not hand-edit these files. Rebuild them by rerunning `Rscript 06_analysis/scripts/run_all.R` or `Rscript 06_analysis/scripts/48_pipeline_refresh_audit.R`.
