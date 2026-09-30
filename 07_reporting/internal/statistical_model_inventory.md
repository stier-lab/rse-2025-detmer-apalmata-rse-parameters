# Statistical Model Inventory

`model_inventory.tsv` is the canonical index of fitted statistical model families in the maintained analysis pipeline. It is intentionally at the model-family level: repeated fits across size classes, leave-one-out folds, bootstrap draws, candidate models, and fallback paths are grouped when they answer the same analysis question.

## Status Labels

- `primary`: model family that supports a main manuscript claim or core quantitative result.
- `support`: supporting context, interpretation, or reference analysis.
- `sensitivity`: robustness, scenario, or biological-realism check.
- `diagnostic`: verification, model-selection, or workflow-consistency check.
- `exploratory`: advanced analysis not frozen into the numbered manuscript claims.
- `figure_only`: model fit exists to render a figure or diagnostic panel; cite the upstream durable model family when possible.

## Question IDs

- `Q1_size_dependence`: size-dependent survival, growth, thresholds, allometry, or size-by-effect interactions.
- `Q2_caribbean_synthesis`: pooled Caribbean survival, heterogeneity, or meta-analysis structure.
- `Q3_population_viability`: transition matrix, lambda, elasticity, bootstrap, or downstream population projection.
- `Q4_disturbance_regime`: disturbance state, heat stress, lagged stressor, or event-window attribution.
- `Q5_restoration_transferability`: natural/restoration/context comparisons and confounding checks.
- `Q6_diagnostics_reproducibility`: verification, cross-validation, power, model selection, and workflow diagnostics.
- `Q7_advanced_dynamics`: exploratory state-space, recurrent-event, spatiotemporal, or dynamic projection extensions.
- `Q8_biological_realism`: outplant age, winter SST, microhabitat, and related biological-realism sensitivities.

## Maintenance Rules

1. Add or update a row whenever a maintained script adds a new model family, test family, or fitted-model output.
2. Use semicolon-separated relative paths in `script`, `outputs`, `display_items`, `question_ids`, and `diagnostics`.
3. Use canonical display IDs from `07_reporting/manuscript/display_items.tsv` when a numbered figure or table is involved. For unnumbered exploratory figures, use `advanced:<stem>`.
4. Keep `disturbance_transferability_role` project-specific. It should say how the model affects attribution, disturbance interpretation, natural/restoration transferability, or the population-model bridge.
5. Keep caveats short and concrete. They should identify the assumption that most affects interpretation.
6. Run `make verify` after edits. The `check_model_inventory.py` gate validates the TSV structure, script coverage, output existence, display-item IDs, and allowed question/status labels.
