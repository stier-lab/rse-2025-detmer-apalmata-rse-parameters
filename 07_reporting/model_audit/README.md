# Model Audit

This directory records the statistical QA pass across the maintained analysis
surface.

- [repo_wide_priorities.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/model_audit/repo_wide_priorities.md):
  condensed cross-script priorities and interpretive guardrails
- [01_early_models.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/model_audit/01_early_models.md):
  threshold, growth, variance, gap, power, CV, context, and model-selection scripts
- [02_synthesis_models.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/model_audit/02_synthesis_models.md):
  matrix, meta-analysis, heterogeneity, sensitivity, figure, and restoration scripts
- [03_disturbance_advanced_models.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/model_audit/03_disturbance_advanced_models.md):
  disturbance, restoration subtype, and advanced model scripts
- [04_spawn_review_2026-04-06.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/model_audit/04_spawn_review_2026-04-06.md):
  repo-wide coordinated review of current code, diagnostics, figures, and reporting drift
- [05_consolidated_review_2026-04-06.md](/Users/adrianstier/Detmer-2025-coral-parameters/07_reporting/model_audit/05_consolidated_review_2026-04-06.md):
  current-state integrated audit after the targeted fixes and reruns from the spawn review

## Repo-Wide Priorities

1. Keep figure scripts downstream of canonical model outputs rather than refitting models inline.
2. Treat weakly identified or confounded analyses as descriptive, not inferential.
3. Expand diagnostics for the advanced layer where coverage is sparse, strata are thin, or state-space assumptions are strong.
4. Preserve artifact provenance so audit tables, figures, and manuscript claims all point to the same maintained outputs.
