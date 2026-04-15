# Newcomer Review: Key Issues and Questions

**Date:** 2026-04-08
**Context:** Three simulated graduate students (ecology, statistics, engineering) independently reviewed the repo as if encountering it for the first time. This document synthesizes their findings into actionable items.

---

## Priority 1: Things That Would Break or Block a New Collaborator

### No dependency management
- No `renv.lock`, `DESCRIPTION`, or `.Rprofile`. README lists 6 packages; the codebase loads ~30+. A fresh clone fails immediately with missing packages.
- `metafor` is marked optional in `00_libraries.R` but required by scripts 14, 14b, 15. `sf` is needed for the map figure. No clear list of what's truly required vs. optional.
- **Fix:** Run `renv::init()` and commit the lockfile.

### 228 uncommitted changes
- Including modified standardized data CSVs, all output files, and all figures. Risk of accidental loss; impossible to distinguish intentional changes from pipeline noise.
- Generated outputs (CSVs, RDS, PDFs, PNGs) are tracked in git, creating massive diffs on every pipeline run.
- **Fix:** Commit current work. Add `06_analysis/output/`, `06_analysis/figures/`, and `parameter_lists/*.rds` to `.gitignore` with a note to regenerate via `run_all.R`.

### 800+ MB git repo from tracked binaries
- 219 literature PDFs (including an 84 MB dissertation), 100+ figure PDFs/PNGs, and output RDS files are committed directly. No Git LFS.
- **Fix:** Migrate literature PDFs to LFS or a shared drive. Gitignore generated figures and outputs.

### Pipeline takes ~90 min with no checkpointing
- If script 37 fails (as it did in the last run), the entire pipeline must restart. Script 13 alone takes ~86 min for the bootstrap.
- No caching of intermediate results. No way to resume from a midpoint.
- **Fix:** Consider `targets` pipeline for dependency-aware caching, or at minimum add timestamp checks so scripts skip re-running if inputs haven't changed.

---

## Priority 2: Statistical Methodology Gaps

### Cell-weighted survival computes logit weights but doesn't use them
- Script 01 computes `yi` (logit) and `vi` (inverse-variance) for each cell, but script 13 uses `weighted.mean(annual_survival, w = n_initial)` — plain sample-size weighting on the probability scale.
- Inverse-variance weighting on the logit scale is the standard meta-analytic approach and would better handle cells near 0% or 100% survival.
- **Impact:** Primarily affects SC1 (low survival) and SC5 (high survival) estimates.

### Survival and growth bootstraps are independent
- The bootstrap resamples survival studies and growth studies as separate draws. This breaks within-study correlation between survival and growth.
- Joint resampling (same study draw for both) would be more appropriate if survival and growth are correlated across studies.

### No publication bias assessment
- No funnel plots, Egger's test, or trim-and-fill in the meta-analysis pipeline. With k=22 effects this is at the boundary of usefulness but should be reported.

### Tier 1 vs Tier 2 annualization inconsistency in meta-analysis
- Script 14b documents that Tier 1 effects are raw pooled proportions (not annualized) while Tier 2 effects are annualized. This systematically biases Tier 1 effects downward. The comment says the bias is "expected to be modest" but this is untested.

### Mortality definition heterogeneity is unaddressed analytically
- NOAA: no tissue AND skeleton gone (conservative). Kuffner: >=50% tissue loss (aggressive). Others: no live tissue. These are not comparable.
- No sensitivity analysis stratifying by mortality definition, and no moderator test in the meta-analysis.

### No formal model comparison for 5-class Lefkovitch structure
- The 5 size classes are borrowed from Vardi 2011 without testing whether this discretization is optimal. No comparison to 4-class, 6-class, or IPM alternatives.

### 30 summary cells spanning multiple size classes
- These are flagged but assigned to one class based on mean size. No down-weighting, splitting, or sensitivity analysis.

### Annualization assumes constant hazard
- `S_annual = S_observed^(1/t)` assumes mortality rate is constant within the observation interval. Not tested against alternatives (e.g., linear interpolation) despite seasonal mortality peaks.

---

## Priority 3: Conceptual Clarity for Newcomers

### What is the one-sentence research question?
- The README has 9 "Paper Goals." CLAUDE.md frames it differently than the README title. A newcomer cannot identify THE question for a lab meeting presentation.
- **Fix:** Add a single bolded sentence at the top of README: "This paper asks: ___"

### What is the RSE model?
- `parameter_lists/README.md` and script 17 generate parameters for a "Regional Stochastic Ecosystem model" that lives in a separate repo. It's never explained in this repo. How it relates to the Lefkovitch matrix in script 13 is unclear.

### Which scripts actually matter for the manuscript?
- 54 scripts is overwhelming. Scripts 41-47 (advanced models) are "exploratory" but there's no quick-start guide saying "read scripts 01, 13, 14b, 19, 22 to understand the paper."
- **Fix:** Add a "Core manuscript pipeline" section to the scripts README listing the ~8 scripts that produce the 4 manuscript figures.

### Where does standardization actually happen?
- `05_data/integration/APAL_data_integration.rmd` is mentioned as the source of standardized data, but it's not called by `run_all.R`. The relationship between this RMarkdown and script 01 is unclear.

### Fecundity = 0 is the biggest assumption but it's buried
- Lambda = 0.961 with zero sexual reproduction. This means the species is declining without any recruitment. The fecundity sensitivity analysis exists but the zero-fecundity baseline deserves prominent discussion in the README.

### Pre-2023 caveat should be in Key Results
- The functional extinction of A. palmata from Florida after the 2023 heatwave (Manzello et al. 2025) fundamentally recontextualizes every number in the paper. This is mentioned in CLAUDE.md but not in the README Key Results table.

---

## Priority 4: Data Integrity and Code Quality

### Raw data files are not write-protected
- `05_data/original/*.csv` have normal read-write permissions. `chmod 444` would prevent accidental modification.

### No checksums on raw inputs
- No `manifest.csv` or `checksums.txt` for the 14 original data files. No way to verify they haven't been tampered with.

### Stale docker-compose.yml
- References `./standardized_data` and `./analysis/output` — paths that no longer exist after the PRISMA restructure. Dead code that would confuse anyone trying to use it.

### Row-order instability in standardized CSVs
- `00_standardize_neely.R` rewrites the entire CSV on every run, changing row order. Git sees the full file as changed even when nothing meaningful changed.

### Giant script files
- `14b_expanded_meta_analysis.R` (2,708 lines), `13_transition_matrix.R` (2,274 lines), `04_growth_rate_comparison.R` (2,326 lines). Hard to review, hard to maintain, hard to test.

### No test suite
- Zero `test_that()` calls. One `stopifnot` in the entire codebase. `23_verification.R` has 9 coarse range checks (e.g., "lambda in [0.80, 1.05]"). A regression that shifts lambda from 0.961 to 0.940 would pass silently.

### No `sessionInfo()` captured
- The pipeline never records which package versions produced a given set of results. No way to diagnose version-dependent discrepancies.

### `N_STUDIES <- 5L` is stale
- Defined in `00c_analysis_constants.R`. The meta-analysis now has k=17 (22 effects). Not referenced downstream but misleading as documentation-in-code.

---

## Priority 5: Smaller Issues Worth Noting

### Record counts disagree across docs
- NOAA: 4,031 (CLAUDE.md) vs 4,025 (extraction_protocol) vs 3,968 (extraction_details). Annotated as "varies by filtering stage" but the specific definitions of each number are unclear.

### I-squared reported as both 96.6% and 97.2%
- These come from different meta-analysis models (k=5 vs k=17). The distinction is not clearly labeled in the README.

### Three different random seeds in script 13
- `set.seed(42)`, `set.seed(123)`, `set.seed(456)` for different random processes. Rationale not documented.

### Script 07 uses wrong size class bins
- Bins of 25/100/500/2000 cm^2 instead of canonical SIZE_BREAKS. Flagged in data_integration_issues.md but not fixed. Diagnostic-only, but confusing.

### Fragmentation data from single study (13 rows)
- No programmatic guard — if the CSV is accidentally deleted, the transition matrix silently omits fragmentation rather than erroring.

### Generation time estimation unresolved
- Set to NA/0 in the code, flagged as "not applicable." Important for interpreting population dynamics timescales.

---

## Questions a New Grad Student Would Ask Adrian

1. "What is the one-sentence version of this paper, and which 5 scripts produce the evidence?"
2. "Lambda = 0.961 with zero fecundity — is the paper arguing the species was already declining before 2023, or that it was marginally viable?"
3. "How much of this repo was written by Raine vs by you?"
4. "If I wanted to add a new study from Bonaire, what's the actual step-by-step?"
5. "Scripts 41-47 — should I read them? Are any going in the paper?"
6. "Why is fragmentation from only one study? Shouldn't storm fragmentation be commonly observed?"
7. "The mortality definition problem (NOAA vs Kuffner vs others) — has anyone tested what happens if you harmonize definitions?"
8. "What's my role on this project — reviewer, contributor, learner?"
