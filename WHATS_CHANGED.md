# What Changed (March 26 → April 16)

Raine — I got into a groove working on this while you were on the RSE side and made a lot of changes (50 commits). Nothing touches your working notes or extraction decisions — those are exactly where you left them. I want to walk through all of this together whenever works for you, but here's the overview so you're not flying blind.

## The big moves

- **Added Neely et al. 2022** — 878 FL Keys colonies, 2010-2016, including the 2014 bleaching event. Meta-analysis is now k=17 studies, 22 effects. This was a big add.

- **Solved the sample-size weighting question you raised** — remember our April 7 conversation about how to combine proportions from studies with really different sample sizes? That turned out to be more important than either of us expected. I went through a few iterations and landed on study-level `rma()` per size class, which uses the same methodology as the expanded meta-analysis in script 14b. Lambda = 0.961 now, right in line with Vardi's 0.96. The full story is below if you're curious.

- **Packaged the FUNDEMAR recruit data for you** — the ~16,700 microscopic settlers from FUNDEMAR, Chamberland, and Mendoza-Quiroz are now in `recruit_surv_pars.rds` with an `s_recruit` parameter (0.028 annualized) you can plug into the RSE. It's way lower than s1 = 0.70 because these are tiny settlers, not nursery fragments — which makes sense given the size-survival relationship we're seeing.

- **Wired script 17 to read directly from script 13** — field survival parameters for the RSE now come from the same bootstrap as the transition matrix. No more two different estimates of the same thing.

- **Cleaned up a bunch of other things** — publication bias assessment (funnel plot, Egger's test, trim-and-fill), mortality-definition sensitivity analysis, Caribbean disturbance database (93 events, 13 regions), PRISMA compliance, standardized all the script headers so every file has PURPOSE/INPUTS/OUTPUTS at the top. Also re-ran the stochastic IPM.

## The sample-size weighting story

Your question from April 7: *"how do we weight proportions from studies with very different sample sizes?"*

| What we tried | Lambda | What happened |
|---------------|--------|---------------|
| Individual-only (before) | 0.986 | Only used 3 studies, ignored the rest |
| Cell-weighted, your option 2 | 0.959 | Better, but didn't handle between-study heterogeneity |
| Cell-level logit IV | 0.888 | Turned out to be biased — lots of NOAA cells had n=1 |
| **Study-level rma()** | **0.961** | **This is what we're using** |

The details are in `07_reporting/internal/methodology_critique_2026-04-14.md` if you want the full argument. Short version: aggregating to study-level first and then pooling with rma() avoids treating individual colony fates as if they were independent studies.

## How the FUNDEMAR data flows

- **44 fragments** go into `nurs_surv_pars.rds` as "Restoration fragment" alongside 10 other nursery studies
- **14,271 recruits** go into their own file `recruit_surv_pars.rds` as "Restoration recruit" with `s_recruit`
- **Neither** enters the natural-colony transition matrix or field survival parameters
- The classification logic is in script 01, Section 8b — I'd love your eyes on whether I got it right

## What you need to do

**In the parameters repo:**
- Pull the `codex-pipeline-refresh-automation` branch — all parameter files are updated

**In the RSE repo:**
- Pull main — I already fixed the hardcoded paths in `rse_sensitivity.rmd` (replaced your `/Users/rainedetmer/Desktop/...` paths with relative ones), updated `standardized_data/` to `05_data/standardized/` everywhere, and corrected the size class boundaries in QUICK_START.md. I only touched paths, nothing else.
- Re-run your scenarios — field survival now has 2000 bootstrap samples (was 1000) and comes from rma() instead of the old cell-level weighting

**For us to discuss:**
- Whether `s_recruit` (0.028) maps onto anything useful in the RSE — could it replace or supplement `s1` for recruit-based scenarios?

## Things I need your input on

These are decisions I made that I want you to sanity-check. None of them are urgent but I want to make sure I didn't get anything wrong:

- [ ] Population type classification — does the Natural/Fragment/Recruit split look right for all studies? I'm least sure about Garrison & Ward 2008.
- [ ] Fragmentation SC1 split rule — I used 10%/90% by range width based on your notes. Does that match what you intended?
- [ ] Neely 2014 disturbance intervals are included in the primary analysis (not excluded). LOSO shows removing Neely pushes lambda to 0.993. Does that seem right to you?
- [ ] Is there anything about the RSE parameter format that doesn't work with the new structure? The column names and element names should be the same.

## Current numbers

| | |
|--|--|
| Lambda | 0.961 (CI: 0.816–1.010) |
| P(decline) | 94.3% |
| SC5 stasis elasticity | 58.9% |
| Meta-analysis | k=17, 22 effects, pooled 78.0%, I²=97.2% |
| LOSO range | 0.882–0.993 |
| s_recruit | 0.028 (annualized) |

## Where to find things

| If you're wondering about... | Look here |
|------------------------------|-----------|
| Why lambda changed | `07_reporting/internal/methodology_critique_2026-04-14.md` |
| How data flows through the pipeline | `04_extraction/data_flow_diagram.md` |
| The sample-size weighting details | `04_extraction/data_integration_issues.md` |
| What the RSE model needs from this repo | `parameter_lists/RSE_COMPATIBILITY.md` |
| Your original extraction notes | `04_extraction/raine_working_notes/` (unchanged) |
| How FUNDEMAR recruits are classified | Script 01, Section 8b |
| The recruit parameter details | `parameter_lists/recruit_surv_pars.rds` (check `$note` and `$comparison`) |
