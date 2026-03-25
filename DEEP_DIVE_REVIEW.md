# Deep Dive Review: *Acropora palmata* Population Viability Assessment

**Reviewer:** Claude (independent code + methodology review)
**Date:** 2026-02-27
**Scope:** Full project — code, data, methodology, documentation, reproducibility

---

## Executive Summary

This is a well-organized, ambitious analysis pipeline that synthesizes ~9,500 individual-level observations from 6 studies into a Lefkovitch projection matrix for *A. palmata*. The central result — λ = 0.986, indicating ~1.4% annual decline with 87.3% probability of negative growth — is ecologically important and policy-relevant. The codebase is unusually mature for an academic project: 33 scripts with a master runner, modular utilities, comprehensive documentation, and complete figure outputs.

However, several structural issues threaten the validity of the headline numbers. The most serious are not bugs but design choices that propagate through the analysis. I'll organize these by what they mean for the manuscript rather than by technical category.

---

## What Works Well

**Pipeline engineering.** The `run_all.R` orchestrator with timing, error handling, and output verification is rare in academic R projects. The modular `shared_utilities.R` loader and consistent sourcing pattern across 33 scripts means the pipeline is genuinely reproducible from a single command. The filtering audit trail in `01_data_preparation.R` is a good practice that most projects skip.

**Self-awareness.** The existing critique documents (ANALYTICAL_CRITIQUE.md, DATA_QUALITY_AUDIT.md, METHODOLOGY_REVIEW.md) are unusually honest. The project already identifies most of its own weaknesses — the fragmentation data bottleneck, I² = 97.8%, the SC5 single-study dependency. This is a strength, but the manuscript needs to reflect this self-awareness more explicitly.

**Data standardization.** The `standardized_data/` directory with its README data dictionary, the `coalesce(size_live_cm2, size_cm2)` logic for biologically meaningful size, and the clear size class definitions (SC1 < 25, SC2 25–100, SC3 100–500, SC4 500–2000, SC5 > 2000 cm²) show careful thought about harmonizing heterogeneous data sources.

**Visualization.** All 21 figures (6 manuscript + 15 supplementary) are present and the pipeline generates them end-to-end. The study landscape figure and population model figure bracket the analysis well.

---

## Critical Issues (Would Raise in Peer Review)

### 1. The matrix model rests on 13 fragmentation observations

The fragmentation sub-matrix comes entirely from Vardi 2011, contributing just 13 data points. Since fragmentation feeds the recruitment column of the projection matrix, λ is sensitive to this single study's estimates. The bootstrap resamples these 13 points, but resampling a small, single-source dataset doesn't create real uncertainty — it just reshuffles the same bias.

**What to do:** Run λ with fragmentation zeroed out and report the difference. If λ changes meaningfully, this must be a prominent caveat. Consider whether published fragmentation rates from other *Acropora* species could serve as informative priors or at least bounding estimates.

### 2. Transition matrix column sums exceed 1.0

The DATA_QUALITY_AUDIT flags SC5's column sum at 1.491. A Lefkovitch matrix column represents the fate of individuals in a size class — survival × (stay + grow + shrink) + fragmentation. Column sums > 1.0 mean the model creates individuals from nothing. This is the single most consequential numerical issue in the project.

The likely cause: survival and transition probabilities are estimated separately, then combined as `A = diag(S) %*% G + F_mat`. If G rows don't sum to exactly 1.0 for each column (after accounting for mortality), or if fragmentation is added on top of a transition matrix that already accounts for all fates, you get phantom individuals.

**What to do:** Trace exactly where the SC5 column picks up the extra 0.491. If it's fragmentation stacked on top of transitions that already implicitly include fragmentation, the fix is structural. If it's a normalization issue in G, renormalize. Either way, this needs to be resolved before the λ estimate is trustworthy.

### 3. RGR spurious self-correlation

The project computes Relative Growth Rate as `growth / size_for_class`, where `size_for_class` is the same measurement used to assign size classes and appears in the denominator. When you then model RGR as a function of initial size, you're regressing Y/X against X — a classic spurious correlation that inflates apparent size-growth relationships. The ANALYTICAL_CRITIQUE already flags this.

**What to do:** Report AGR results alongside RGR. The project already shows RGR fits 22× better than AGR (by R²), but that comparison is inflated by the mathematical coupling. The manuscript should acknowledge this and present both, letting readers assess the biological signal.

### 4. I² = 97.8% makes the pooled estimate hard to interpret

Extreme heterogeneity isn't just a statistical nuisance — it means the studies aren't estimating the same quantity. The expanded meta-analysis (k=16) uses REML with Knapp-Hartung, which is methodologically appropriate, but the pooled λ or survival estimate across studies with I² this high is closer to an average of different things than an estimate of one thing.

**What to do:** The prediction interval is more informative than the confidence interval here. If the manuscript already reports it, emphasize it. If not, add it. Consider whether the narrative should shift from "the population is declining at rate X" to "across diverse conditions, most populations are declining, with the rate depending heavily on local context."

### 5. NOAA data dominance (78% of observations)

A single data source contributing 78% of observations means the pooled estimates are effectively NOAA estimates with modest corrections from smaller studies. The leave-one-study-out analysis should show this — if removing NOAA shifts λ substantially, the headline number is really a Florida Keys number, not a species-wide number.

**What to do:** Report LOSO results prominently. If NOAA removal changes the story, the manuscript framing needs to match the inferential scope.

---

## Moderate Issues (Worth Addressing Before Publication)

### 6. Annualized survival computation

Sub-annual survival is annualized as `survived^(1/time_interval_yr)`. For a binary outcome (0/1), this is problematic: `0^(1/0.5) = 0` and `1^(1/0.5) = 1`, so it doesn't actually change individual records. The annualization only matters at the aggregate level, and it assumes constant hazard rate within the interval. This is a standard assumption but should be stated explicitly, and the sensitivity to it should be checked.

### 7. Mortality definition inconsistency across studies

Different studies define mortality differently (whole-colony death vs. partial mortality thresholds vs. disappearance). The `mortality_definition` column is added in data prep, which is good bookkeeping, but the analysis then pools these as if they measure the same thing. A study that counts partial mortality will show higher "death" rates than one requiring complete colony loss.

### 8. SC5 vital rates from a single study

The largest size class (>4000 cm²) drives 54.8% of population elasticity, but its vital rates come from limited data. If SC5 stasis, growth, and survival estimates are dominated by one study, the most influential part of the model is the least well-estimated. This compounds the fragmentation issue (#1).

### 9. No sexual reproduction in the matrix

The matrix includes fragmentation but not sexual recruitment. For a species where sexual reproduction is increasingly recognized as important for genetic diversity and adaptation, this is a notable omission. It's defensible for short-term projections (sexual recruitment rates are very low for *A. palmata* in most populations), but should be discussed as a limitation that biases λ downward.

### 10. GAM k=4 may be too restrictive

The threshold detection uses a GAM with k=4 basis functions, which constrains the fitted relationship to be nearly linear or have at most one inflection point. If the real survival-size relationship has more structure (e.g., a plateau at intermediate sizes), k=4 won't capture it. The ANALYTICAL_CRITIQUE already flags this.

---

## Minor Issues and Suggestions

- **Bootstrap iterations.** The analysis uses 2,000 replicates with 1,479 valid — a 26% failure rate. Understanding why 521 replicates fail (singular matrices? extreme resamples?) would strengthen confidence in the bootstrap distribution.
- **Git history.** A single commit means the development history is opaque. For reproducibility and review, incremental commits help reconstruct analytical decisions.
- **Navassa growth outlier.** Mean growth of 826 cm²/yr at Navassa is flagged but retained. The manuscript should justify inclusion or exclusion with a clear decision rule, not just a flag.
- **Power analysis.** Post-hoc power analysis (computing power from observed effect sizes) is widely regarded as uninformative. If included, it should be reframed as a prospective design tool for future studies, not as validation of current results.
- **Duplicate records.** 66 duplicates found and removed is fine, but the deduplication rule (`study + coral_id + survey_yr + location`) should be documented in the methods, not just the code.

---

## Reproducibility Assessment

| Criterion | Rating | Notes |
|---|---|---|
| Single-command execution | ✅ Strong | `run_all.R` with full orchestration |
| Dependencies documented | ⚠️ Partial | Libraries loaded in `00_libraries.R` but no `renv.lock` or explicit version pinning |
| Data included | ✅ Strong | All standardized data files present with data dictionary |
| Figures regenerated | ✅ Strong | All 21 figures present in output directories |
| Intermediate outputs | ✅ Strong | 80+ CSV outputs with descriptive names |
| Random seed management | ❓ Unknown | Not verified across all bootstrap scripts |
| Environment isolation | ⚠️ Partial | No containerization or `renv`; depends on system R installation |

---

## Priority Action List

Ordered by impact on manuscript credibility:

1. **Fix SC5 column sum > 1.0** — This is a numerical error that directly affects λ. Must resolve before any other interpretation.
2. **Quantify fragmentation sensitivity** — Run λ with and without fragmentation. Report the range.
3. **Report LOSO results for NOAA** — Show what happens to λ when the dominant data source is removed.
4. **Add prediction interval to meta-analysis** — With I² = 97.8%, the CI is misleading about the range of plausible population trajectories.
5. **Acknowledge RGR self-correlation** — Present AGR alongside RGR; discuss the mathematical coupling.
6. **Add `renv.lock`** — Low effort, high reproducibility payoff.
7. **State annualization and mortality-definition assumptions in methods** — Currently implicit.
8. **Discuss absence of sexual reproduction** — Frame as a conservative (downward-biased) estimate of λ.

---

## Bottom Line

The analysis is substantive, the pipeline is well-engineered, and the ecological conclusions (large colonies matter most, populations are likely declining, restoration should target SC5 growth) are well-supported directionally. The quantitative precision of the headline numbers (λ = 0.986, 87.3% decline probability) is overstated given the data limitations — particularly the SC5 column sum issue, the 13-point fragmentation dependency, and the extreme inter-study heterogeneity. Fixing issue #1 (column sums) is non-negotiable; issues #2–5 are about honest framing rather than fatal flaws.

This is a publishable analysis. It needs targeted fixes, not a redesign.
