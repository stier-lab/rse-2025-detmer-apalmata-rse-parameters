# What Changed (March 26 → April 16)

Raine — here's a quick rundown of everything I changed while you were working on the RSE side (50 commits). Your working notes and extraction decisions are untouched. Let's walk through the code together when you're ready, but this should orient you.

## The big moves

- **Added Neely et al. 2022** — 878 FL Keys colonies, 2010-2016. Includes the 2014 bleaching catastrophe. Meta-analysis is now k=17 studies, 22 effects.
- **Fixed the sample-size weighting problem you flagged** — the proportion-weighting question from our April 7 meeting turned out to matter a lot. Went through three iterations (see below) and landed on study-level `rma()` per size class, which matches the methodology in script 14b. Lambda = 0.961, very close to Vardi's 0.96.
- **FUNDEMAR recruits are now packaged for the RSE** — `recruit_surv_pars.rds` has `s_recruit = 0.028` (annualized post-settlement survival). Way lower than `s1 = 0.70` because these are microscopic settlers, not nursery fragments.
- **Script 17 field survival now reads from script 13** — no more independent computation. Same survival estimates in the matrix and the RSE parameters.
- **Added publication bias assessment** — funnel plot, Egger's test (independent model p=0.655; three-level model p=0.002 — discrepancy likely reflects nesting structure, not true bias), trim-and-fill (3 studies imputed, -2.4 pp).
- **Added mortality-definition sensitivity** — lambda shifts by only 1 pp when stratifying by how studies define "dead."
- **Built a Caribbean disturbance database** — 93 curated events, 13 regions, IBTrACS hurricane exposure (208 storms), NOAA CRW DHW for all 175 site-years.
- **PRISMA compliance** — formal PubMed, WoS, Google Scholar searches (~2,518 records), inter-rater reliability, expanded screening, 3 new summary studies added, 2 removed for overlap.
- **Standardized all script headers** — every script now has PURPOSE/INPUTS/OUTPUTS at the top so you can read any file header and know what it does.
- **Stochastic IPM re-run** — script 43, same qualitative results (lambda 0.78-0.82, 100% quasi-extinction). It fits its own GAMs so the rma() fix doesn't change it directly.

## The sample-size weighting story

Your question: *"how do we weight proportions from studies with very different sample sizes?"*

| What we tried | Lambda | Why we moved on |
|---------------|--------|-----------------|
| Individual-only (before) | 0.986 | Ignores 10 summary studies |
| Cell-weighted, your option 2 | 0.959 | No between-study heterogeneity |
| Cell-level logit IV | 0.888 | Biased — n=1 NOAA cells got treated as studies |
| **Study-level rma()** | **0.961** | **This is what we're using** |

Details in `07_reporting/methodology_critique_2026-04-14.md` if you want the full statistical argument.

## FUNDEMAR data — how it flows

- **44 fragments** → `nurs_surv_pars.rds` (Restoration fragment, alongside 10 other nursery studies)
- **14,271 recruits** → `recruit_surv_pars.rds` (Restoration recruit, separate file with `s_recruit`)
- **Neither** enters the natural-colony transition matrix or field survival parameters
- Classification logic is in script 01, Section 8b — **check if it looks right to you**

## What you need to do in the RSE repo

- Pull this branch (`codex-pipeline-refresh-automation`) in the parameters repo — parameter files are updated
- Pull main in the RSE repo — I fixed your hardcoded `/Users/rainedetmer/` paths in `rse_sensitivity.rmd`, updated `standardized_data/` → `05_data/standardized/` everywhere, and corrected the size class boundaries in QUICK_START.md. No analysis code was changed, just paths.
- Re-run your scenarios — field survival now has 2000 bootstrap samples instead of 1000, and the values come from rma() instead of the old cell-level weighting
- Consider whether `s_recruit` (0.028) is useful for recruit-based restoration scenarios in the RSE — it's a drop-in alongside `s0` and `s1`

## Things I need you to check

- [ ] Population type classification — right for all studies? Especially Garrison & Ward 2008
- [ ] Fragmentation SC1 split rule (10%/90% by range width, from your notes)
- [ ] Neely 2014 disturbance intervals included in primary analysis — ok?
- [ ] Does `s_recruit` map to anything useful in the RSE, or do you need it structured differently?

## Current numbers

Lambda = 0.961 (CI: 0.816-1.010), P(decline) = 94.3%, SC5 stasis elasticity = 58.9%, LOSO range 0.882-0.993.

## Where to look

| Question | File |
|----------|------|
| Why lambda changed | `07_reporting/methodology_critique_2026-04-14.md` |
| Data pipeline diagram | `04_extraction/data_flow_diagram.md` |
| Sample-size weighting details | `04_extraction/data_integration_issues.md` |
| RSE parameter format | `parameter_lists/RSE_COMPATIBILITY.md` |
| Your original notes | `04_extraction/raine_working_notes/` (unchanged) |
