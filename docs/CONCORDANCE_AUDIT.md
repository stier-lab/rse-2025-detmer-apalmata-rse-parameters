# Reviewer-readiness concordance audit

**Audit date:** 2026-09-28  
**Scope:** Current working tree, with the manuscript source at
`07_reporting/manuscript/acropora_palmata_demography_manuscript_draft.md`.
**Status:** **Not ready for reviewer or archive release.** The analysis and
manuscript corrections below have been made in the working tree, but the
release and clean-clone gates remain open.

## Gate 1 — Code hygiene and repository navigation: FAIL (25/40)

The numbered project layout, focused READMEs, and the fresh-subprocess
`run_all.R` runner make the repository navigable. However, a reviewer cannot
reproduce the advertised working-tree workflow from the current Git revision.

### Red

- The active verification and manuscript surfaces are untracked: `Makefile`,
  `tools/`, `paper/`, `claims.tsv`, `display_items.tsv`, and model-inventory
  artifacts. A clone of `HEAD` cannot run the advertised `make verify`,
  `make display-check`, or `make submit-check` gates.
- The working tree contains extensive modified generated data, figures,
  outputs, and reporting files. It is not a shareable release snapshot.

### Yellow

- The tracked repository is approximately 569 MiB and contains 276 PDFs,
  including duplicate literature files. Archive or document the required
  in-repository binaries before release.
- `renv.lock` is unsynchronized with the local library and was created under
  R 4.5.2; the current environment reports R 4.6.1. `tools/check_r_version.R`
  now fails fast with an actionable message, but a successful locked restore
  and rerun remain required.
- The public-facing README and manuscript-rendering script no longer depend on
  local absolute paths. Remaining absolute links in historical/internal notes
  should be made relative before a public archive snapshot.
- `LICENSE`, `CITATION.cff`, a source-data use statement, and a portable
  manuscript PDF check are now present. A tagged release and archival DOI are
  still required.

## Gate 2 — Statistics, biology, and manuscript concordance: FAIL

### Red — resolve before submission

1. **The primary 78.0% estimate was not consistently annualized — repaired and rerun.**
   `06_analysis/scripts/14b_expanded_meta_analysis.R` now constructs Tier 1
   effects from interval-level survival proportions annualized as \(S^{1/t}\),
   on the same scale as Tier 2. The manuscript removes the pre-harmonization
   78.0% result. The rerun retained the pre-specified 17-study/22-effect
   structure and yielded 78.7% pooled annual survival (95% CI: 70.4–85.1%;
   95% prediction interval: 37.4–95.8%; I² = 97.6%). Figure 3 was regenerated.
   A clean locked-environment rerun is still required before release.

2. **The primary meta-analysis model is misdescribed.** The manuscript says the
   expanded primary model uses Knapp–Hartung inference. The active primary model
   is a three-level `metafor::rma.mv` REML model with `test = "t"`
   (`14b_expanded_meta_analysis.R`, lines 810–818); Knapp–Hartung belongs only
   to an independent-effect sensitivity model (lines 825–832). Correct the
   Methods and any matching figure legend.

3. **The matrix result was framed as full population viability — prose repaired.** The five-class matrix
   fixes sexual reproduction and external recruitment at zero
   (`13_transition_matrix.R`, lines 1794–1847). Its deterministic lambda is a
   conditional recruitment-free, post-settlement transition result—not a
   forecast of whole-population viability or recovery. The title, Abstract,
   Methods, Results, Discussion, and Fig. 4 legend now identify it as a
   conditional, recruitment-free post-settlement transition subsystem.

4. **Bootstrap frequency is not real-world probability — prose repaired.** The 94.3% statistic is
   the fraction of 2,000 hierarchical bootstrap resamples with lambda below one
   (`22_fig6_population_model.R`, lines 268–296). Report it as “94.3% of
   bootstrap replicates had lambda below one,” not as a probability that the
   population will decline in nature. The Results and Fig. 4 legend now report
   the bootstrap frequency explicitly and reject that real-world interpretation.

5. **Embedded Table S3 had stale and mislabeled elasticities — table repaired.** It labelled
   0.005, 0.023, 0.109, 0.217, and 0.588 as survival elasticities. Current
   `vital_rate_elasticity.csv` gives 0.00399, 0.02358, 0.10567, 0.20843, and
   0.60207; 0.58867 is specifically the SC5-to-SC5 *matrix-cell* elasticity.
   The embedded table now reports aggregated survival elasticities, identifies
   0.589 as the SC5-to-SC5 matrix-cell elasticity, and reports the 0.051
   fragmentation elasticity separately.

6. **Methods conflated individual-level and meta-analytic sample sizes — prose repaired.** The
   manuscript attributes 8,805 observations to seven individual-level studies,
   but 8,805 is the combined meta-analysis total for 17 studies and 22 effects.
   Methods now report the analysis-specific input counts (7,842 survival and
   6,318 growth rows before subsequent filtering) and identify 8,805 as the
   earlier meta-analytic effective sample size.

### Yellow — clarify before submission

- The transition matrix has uneven provenance: 83.2% of SC5 survival support is
  from NOAA and all fragmentation support is Vardi 2011. The manuscript now
  states this limitation, the 43 of 2,000 replicate imputations, and the absent
  survival-growth covariance.
- Fig. 2 threshold curves are unadjusted GAM estimates; random-effect GAMM/GLMM
  fits are diagnostics or sensitivity analyses. The Methods and Fig. 2 legend
  now state that the displayed intervals are unadjusted descriptive intervals.
- The disturbance model is observational:
  `survived ~ log_size * disturbance_state + (1 | study)`. Describe it as a
  difference among curated exposure categories, not evidence that disturbance
  causally altered survival.
- Restoration subtype contrasts are descriptive and highly unbalanced (natural
  fragments: 3,968 records; re-cemented: 53; outplanted: 46). The Results now
  report all subtype record counts, study count, and the descriptive limitation.

### Green — numbers that agreed with their canonical outputs

- The post-harmonization meta-analysis: 78.7% pooled survival, 70.4–85.1%
  confidence interval, 37.4–95.8% prediction interval, 17 studies, 22 effects,
  and I² = 97.6%.
- Survival threshold near 7,498 cm²; relative-growth threshold near 37 cm²;
  positive-growth threshold near 411 cm².
- Matrix lambda 0.961, percentile interval 0.816–1.010, and 58.9% SC5-to-SC5
  matrix-cell elasticity, subject to the red qualifications above.
- Shrinkage, study-window disturbance audit, and restoration-subtype values.

## Gate 3 — Clone-to-figure reproducibility: FAIL

The affected analysis and figures run in the available R 4.6.1 installation,
but the lockfile requires R 4.5.2 and a locked restore has not succeeded on
this host. Therefore no clean-clone or end-to-end reproduction can be claimed.
Required next step: restore and validate the intended lockfile under R 4.5.2,
then perform a fresh-clone pipeline-to-figure run and record the commands and
outputs.

## Gate 4 — Archive packaging: NOT STARTED

Do not archive until Gates 1–3 pass. The release snapshot needs committed
verification/manuscript assets, a clean Git state, and a tagged archive
release. `LICENSE`, `CITATION.cff`, and a code-versus-source-data use statement
are now supplied.

## Release decision

**Hold submission and reviewer sharing.** Resolve the six red concordance items,
restore and test the computational environment, then rerun this audit against a
committed release candidate.
