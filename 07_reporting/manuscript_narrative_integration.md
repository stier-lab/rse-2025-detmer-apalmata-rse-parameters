# Manuscript Narrative Draft

## Core Message

The paper’s central claim should be that *Acropora palmata* demography is strongly size structured, nonlinear, and disturbance dependent, and that those dependencies matter for population viability and restoration planning. The new analyses strengthen three linked points: partial mortality and retrogression are common enough to matter biologically, disturbance modifies size-dependent performance rather than acting as background noise, and restoration outcomes depend on subtype and context rather than one generic “fragment” effect (`06_analysis/output/shrinkage_retrogression_size_class_summary.csv`, `06_analysis/output/disturbance_size_survival_model.csv`, `06_analysis/output/restoration_subtype_sensitivity.csv`).

## Abstract-Ready Summary

We synthesized Caribbean-wide demographic data for *Acropora palmata* to estimate how survival, growth, shrinkage, and retrogression vary with colony size and what that implies for population viability and restoration. Shrinkage is common rather than exceptional: in the matrix-compatible subset, 39.4% of growth records involved tissue loss, and retrogression probabilities were 15.2% in SC2, 16.8% in SC3, 17.2% in SC4, and 9.1% in SC5 (`06_analysis/output/shrinkage_retrogression_size_class_summary.csv`, `06_analysis/output/retrogression_probability_by_size_class.csv`). Disturbance is part of the demographic regime, not residual noise: size-by-disturbance survival effects were significant (`LRT p = 6.93e-4`), and the study-window audit rebuilt 1,072 interval records with 95.1% showing some disturbance overlap (`06_analysis/output/disturbance_size_survival_model.csv`, `06_analysis/output/study_window_disturbance_summary_overall.csv`). Restoration effects are subtype-specific, with subtype-coded records averaging 0.812 survival overall but 0.600 when natural fragments are excluded (`06_analysis/output/restoration_subtype_sensitivity.csv`).

## Introduction Framing

- Frame the biological problem as a question of how size, disturbance, and restoration history jointly shape demographic performance, rather than as a single pooled estimate problem (`07_reporting/paper_scope_and_analysis_roadmap.md`).
- State early that shrinkage and retrogression are expected in *A. palmata* because partial mortality and breakage can reduce live tissue area without immediate whole-colony death (`06_analysis/output/shrinkage_retrogression_size_class_summary.csv`).
- Make disturbance explicit as Caribbean demographic regime structure: hurricanes, disease, heatwaves, and chronic pressures change the performance landscape, they do not simply add noise (`07_reporting/transferability_summary.md`, `06_analysis/output/study_window_disturbance_summary_overall.csv`).
- The 2023 marine heatwave and resulting functional extinction of *A. palmata* from Florida (Manzello et al. 2025) demonstrates that the demographic regime we characterize operated under conditions that have now been catastrophically disrupted. This motivates the synthesis: understanding baseline size-dependent vital rates is a prerequisite for designing restoration interventions that can succeed under accelerating thermal stress.
- Clarify that restoration comparisons need subtype resolution because nursery outplants, re-cemented outplants, outplanted colonies, and natural fragments are not biologically interchangeable (`06_analysis/output/restoration_subtype_sensitivity.csv`).

## Results Integration

The results section should move from simple size effects to a more complete demographic picture. The shrinkage synthesis shows that tissue loss is frequent across size classes, rising from 18.2% in SC1 to 47.5% in SC5 in the matrix-compatible subset, while retrogression occurs most often in SC3-SC4 (`15.2%`-`17.2%`) and remains present even in SC5 (`9.1%`) (`06_analysis/output/shrinkage_retrogression_size_class_summary.csv`, `06_analysis/output/retrogression_probability_by_size_class.csv`). This supports describing large colonies as demographically persistent but still vulnerable to partial mortality and backward transitions, not as purely stable end points.

Disturbance-by-size effects are strong enough to discuss as a main result, but the growth-side interpretation should remain more cautious than the survival-side interpretation. The survival interaction model shows that size relationships differ by disturbance state, with the acute baseline-exclusion term and the context-only term both interacting positively with size and the overall interaction test significant (`comparison_lrt_p = 6.93e-4`) (`06_analysis/output/disturbance_size_survival_model.csv`). By contrast, the growth-side model is supportive but less decisive, so it should be framed as suggestive rather than definitive if retained.

Disturbance assignment is now auditable. The rebuilt study-window summary covers 1,072 intervals across 7 studies, with 297 baseline-exclusion intervals, 904 timeline-overlay-supported intervals, 115 intervals supported by both sources, and 95.1% of intervals overlapping at least one curated disturbance (`06_analysis/output/study_window_disturbance_summary_overall.csv`). That audit can be used to explain how the disturbance layer was attached to the demographic record.

Restoration results should be reported as subtype-specific, not as a single pooled restoration effect. The subtype-coded set includes 5,079 records across 5 studies, but excluding natural fragments reduces the mean survival estimate from 0.812 to 0.600, while nursery outplants and outplanted colonies retain distinct survival profiles (`06_analysis/output/restoration_subtype_sensitivity.csv`).

## Plain-Language Disturbance Logic

- Local metadata were retained when studies directly documented storms, disease, bleaching, or other interval-specific disturbances in the original monitoring record.
- Timeline overlay was then used to attach curated Caribbean events to study windows that matched in region and time, so disturbance context was not limited to locally annotated catastrophes.
- Baseline-exclusion events are the acute events used for the counterfactual sensitivity analysis; context-only events remain attached as real demographic regime context rather than being filtered away.
- The analytical point is not that every interval should be treated as “clean” or “disturbed” in a binary sense, but that *A. palmata* demography is observed within a shifting disturbance regime that has to be represented explicitly.

## Discussion Integration

The discussion should emphasize that *A. palmata* is not a simple survival-vs-growth system. Shrinkage and retrogression are part of the species’ core demographic mechanism because disturbance often reduces live tissue without immediate mortality, which can still move colonies into smaller size classes and reduce future viability (`06_analysis/output/shrinkage_retrogression_size_class_summary.csv`).

Disturbance should be interpreted as a regime that reshapes size structure and demographic trajectories through time and space. The study-window audit and the disturbance-by-size interaction together support a narrative in which regional event histories alter not just mean survival, but the way size mediates survival under stress (`06_analysis/output/study_window_disturbance_summary_overall.csv`, `06_analysis/output/disturbance_size_survival_model.csv`).

Restoration implications should be subtype-aware. The new decomposition shows that broad “fragment” language hides biologically important differences among nursery outplants, re-cemented outplants, outplanted colonies, and natural fragments, so the most defensible restoration claim is about which subtype and context perform best rather than about restoration in the abstract (`06_analysis/output/restoration_subtype_sensitivity.csv`).

The discussion should also separate transferable biological patterns from conditional numerical estimates. The transferable layer is that demography is nonlinear, size structured, disturbance sensitive, and heterogeneous; the conditional layer is the exact threshold values, lambda estimates, and regional recovery magnitudes, which remain study-composition dependent and Florida-weighted (`07_reporting/transferability_summary.md`).

## Known-Unknowns

The paper should state plainly that recruitment and fecundity remain constrained supporting evidence rather than fully estimated demographic modules. The current synthesis supports a maturity threshold, some evidence of reduced reproductive output under partial mortality, and early-life bottlenecks, but it does not yet support a Caribbean-wide fecundity schedule, a robust recruitment rate by region, or a disturbance-adjusted reproductive output model (`07_reporting/recruitment_fecundity_scope_note.md`).

## Transferability

The manuscript should say that the broad direction of the results is transferable, but the exact values are not. Size dependence, nonlinearity, disturbance relevance, and the importance of large adults are robust; the precise thresholds, lambda values, and recovery timings are conditional on the current study mix and are disproportionately informed by Florida and a few large monitoring datasets (`07_reporting/transferability_summary.md`). The safest wording is that the synthesis identifies general Caribbean patterns and then reports numerical estimates as conditional summaries, not universal constants.
