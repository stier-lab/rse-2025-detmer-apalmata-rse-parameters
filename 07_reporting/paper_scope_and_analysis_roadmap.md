# Paper Scope and Analysis Roadmap

This document defines the hierarchy of goals for the *Acropora palmata* demography synthesis and records the main opportunities to make the analysis more comprehensive, more complete, and better documented.

---

## 1. Parent Goal

Build a Caribbean-wide, size-structured understanding of *Acropora palmata* demography that is strong enough to support defensible inference about population viability, disturbance exposure, and restoration decision-making.

---

## 2. Paper Goals

1. Quantify how demographic rates vary across colony size, including survival, growth, shrinkage, and fragmentation.
2. Test whether those size relationships are nonlinear, with thresholds or inflection points rather than simple linear scaling.
3. Translate size-structured demographic rates into population-viability consequences, especially the size classes and transitions that drive `lambda`, decline risk, and recovery potential.
4. Treat disturbance as part of the demographic regime facing *A. palmata*, including hurricanes, disease, heatwaves, cold events, predators, and chronic stressors.
5. Map disturbance through Caribbean time and space, then connect disturbance windows to observed demographic performance.
6. Compare natural-colony and restoration-fragment demography, including when differences persist after accounting for size.
7. Evaluate what the synthesis implies for restoration: target sizes, habitats, regions, and disturbance windows that are more or less favorable for persistence.
8. Quantify heterogeneity and transferability across studies, regions, and years so pooled estimates are interpreted with appropriate caution.
9. Make uncertainty and data gaps explicit, especially for recruitment, fecundity, chronic stress, and large-adult dynamics outside Florida.

---

## 3. Goal-to-Analysis Mapping

| Goal | Current analytical coverage | Primary scripts / data | Status | Main next step |
|---|---|---|---|---|
| Size-dependent demography | Survival and growth modeled against size; fragmentation included in synthesis and matrix workflow | `02`, `03`, `04`, `13`, `apal_fragmentation*.csv` | Strong | Elevate shrinkage and fragmentation into clearer standalone reporting products |
| Nonlinearities and thresholds | Survival and growth threshold workflow with GAM derivatives, LOSO, and figure set | `02`, `03`, `04`, `25`, `utils/02_threshold_functions.R` | Strong | Add a concise manuscript crosswalk from threshold output to figure and claim |
| Population viability | Lefkovitch matrix, elasticity, stochastic projections, sensitivity | `13`, `22`, output `transition_matrix*`, `elasticity*` | Strong | Tie viability interpretation more directly to disturbance and restoration sections |
| Disturbance as demographic regime | Timeline, event catalog, sensitivity contrasts, disturbance-survival overlays | `30`, `32`, `34`, `apal_disturbance_stressor_timeline.csv` | Moderate to strong | Add interval-by-interval disturbance coverage audit and size-by-disturbance interaction summaries |
| Caribbean disturbance mapping | Curated event catalog with region, timing, severity, and baseline role | `34`, output `disturbance_event_catalog.csv` | Strong | Add explicit study-window overlap table so readers can see where event assignment is observed vs inferred |
| Natural vs restoration comparison | Meta-analysis moderator, within-region comparisons, size-matched growth comparisons | `14b`, `21`, `29`, `04` | Moderate to strong | Break restoration into biologically distinct subtypes where possible |
| Restoration implications | Present but distributed across context, disturbance, growth, and matrix scripts | `11`, `21`, `29`, `30`, `32` | Moderate | Create a single manuscript-facing synthesis table of restoration-relevant findings |
| Heterogeneity and transferability | I-squared, moderator analyses, LOSO, cross-validation, power and gaps | `10`, `12`, `14`, `14b`, `15`, `16` | Strong | Add a short "what transfers / what does not" summary table for manuscript discussion |
| Uncertainty and data gaps | Certainty scoring, gap prioritization, power analysis, scope-screened literature tables | `06`, `09`, `23`, `35` | Strong | Explicitly separate "known unknowns" from "not estimable with current data" |

---

## 4. Current Strengths

- The repo already has a coherent size-threshold workflow rather than only linear size models.
- Population viability is linked to observed size-structured vital rates rather than generic literature values.
- Disturbance is now represented as a Caribbean event layer with explicit analytical roles instead of an ad hoc note field.
- The natural-versus-restoration question is treated as a biological comparison, not just a pooled moderator.
- Data gaps and uncertainty are already quantified, which is unusual and valuable for an ecology synthesis.

---

## 5. Recently Completed Additions

The following additions are now implemented in the repo:

1. **Dedicated shrinkage / retrogression synthesis**
   Delivered via `36_shrinkage_retrogression_summary.R` with size-class, study-level, and transition-component outputs plus a summary figure.

2. **Disturbance × size interaction analysis**
   Delivered via `37_disturbance_size_interaction.R`, with explicit survival and positive-growth interaction outputs.

3. **Study-window disturbance coverage audit**
   Delivered via `38_study_window_disturbance_audit.R`, with rebuilt overlap tables, per-study summaries, and a manuscript-facing audit table.

4. **Restoration subtype decomposition**
   Delivered via `39_restoration_subtype_sensitivity.R` and `restoration_subtype_mapping.csv`, replacing the single broad restoration-fragment grouping with defensible subtypes.

5. **Manuscript claim-to-output crosswalk and build map**
   Delivered via `claim_output_crosswalk.md` and `figure_table_build_map.md`.

6. **Transferability summary and recruitment/fecundity scope note**
   Delivered via `transferability_summary.md` and `recruitment_fecundity_scope_note.md`.

---

## 6. Remaining Priority Additions

### High Priority

1. **End-to-end rerun and freeze**
   Current state:
   The manuscript-facing docs, figure numbering plan, and canonical filenames have been updated, but the repo still needs one clean regeneration pass so outputs and text are synchronized.
   Why it matters:
   This is the final consistency step before treating the repo state as submission-ready.
   Concrete addition:
   Re-run the full pipeline, verify the regenerated canonical figures/tables, and update any stale values revealed by that pass.

2. **Growth-side disturbance interpretation note**
   Current state:
   The disturbance × size analysis shows a strong survival interaction and a weaker growth-side signal.
   Why it matters:
   The manuscript should continue to distinguish strong evidence from suggestive evidence.
   Concrete addition:
   Keep the survival interaction as a main finding and present the growth-side result as supportive but not equally definitive.

3. **Archive or relocate internal figure variants**
   Current state:
   The repo still contains useful but non-final files such as `FigSXX_*`, `Fig6_population_model.png`, `Fig4_size_class_survival.*`, and other manuscript-candidate variants.
   Why it matters:
   The numbering is now clarified in reporting docs, but the figure directories still contain historical clutter.
   Concrete addition:
   In a later cleanup pass, archive or relocate clearly non-final figure variants without removing traceability.

### Medium Priority

4. **Manuscript assembly**
   Current state:
   The repo now contains a methods draft, a narrative draft, updated legends, a figure/table plan, and supporting synthesis notes.
   Why it matters:
   These pieces still need to be collapsed into the final manuscript file used for submission.
   Concrete addition:
   Merge the current draft components into a single abstract-introduction-methods-results-discussion manuscript draft.

5. **Submission supplement packaging**
   Current state:
   Table S1, Table S2, Fig. S16-S19, the transferability note, the known-unknowns note, and the conceptual summary are all present as separate artifacts.
   Why it matters:
   The paper will be clearer if these are packaged as a deliberate supplement rather than a loose set of support files.
   Concrete addition:
   Create a submission-facing supplement outline or appendix document that points to the retained supporting products.

---

## 7. Priority Additions for Better Documentation

1. **Methods-update pass**
   Update manuscript methods whenever analytical logic changes materially, especially disturbance handling, sensitivity definitions, and study counts.

2. **Figure and table build map**
   Keep a single source listing which script builds each manuscript figure and table.

3. **Output provenance notes**
   Key CSV outputs should state which script created them and what role they play in the manuscript.

4. **Scope-screening discipline**
   Continue using analysis-ready screened literature tables rather than unscreened synthesis tables in downstream scripts.

---

## 8. Suggested Near-Term Work Sequence

1. Re-run the full pipeline with the canonical figure/table names now in place.
2. Verify regenerated numerical values against `figure_legends.txt`, `README.md`, and the reporting notes.
3. Decide whether to archive clearly non-final figure variants out of the main figure directories.
4. Collapse the current manuscript-facing pieces into a single submission draft.

---

## 9. Boundary Conditions

The paper does **not** need to become a general review of all *A. palmata* biology. The focus should remain on:

- demographic rates across size
- nonlinear size dependence
- population viability
- disturbance as demographic regime
- restoration relevance
- heterogeneity, uncertainty, and data gaps

Anything outside those threads should only be retained if it directly strengthens one of them.
