---
title: "Online Resource 1: Supporting analyses for size-dependent demography, disturbance, and transition dynamics of *Acropora palmata* across the Caribbean"
author: "Adrian C. Stier; A. Raine Detmer; Jameal F. Samhouri; Darcy Bradley; Aldo Croquer; Rita I. Sellares-Blasco"
date: ""
bibliography:
  - paper/manuscript/references.bib
  - paper/manuscript/palmata_library.bib
link-citations: true
header-includes:
  - \usepackage{pdflscape}
  - \usepackage{booktabs}
  - \usepackage[margin=0.5in]{geometry}
---

**Journal:** *Coral Reefs*  
**Corresponding author:** A. Raine Detmer, Department of Ecology, Evolution, and Marine Biology, University of California, Santa Barbara, California, USA. Contact details are provided in the manuscript title page.

## Contents

1. Studies contributing to the synthesis (Table S1)
2. Study-window disturbance audit (Table S2)
3. Growth-size diagnostics (Fig. S1)
4. Population origin is confounded with study identity (Fig. S2)
5. Shrinkage and retrogression (Fig. S3)
6. Disturbance and size-dependent survival (Fig. S4)
7. Restoration subtype sensitivity (Fig. S5)
8. Florida-scale heatwave scenarios (Fig. S6)

## Studies contributing to the synthesis

**Table S1. Eighteen studies contributed data; seventeen entered the survival synthesis.** Tier 1 studies supplied individual colony records; Tier 2 studies supplied study-level summaries. *N* is the effective annualized denominator in the survival synthesis after interval filtering and aggregation, summed across a study's effects; survival is the *N*-weighted mean of annualized effect-level survival and is shown for orientation only (Fig. 3 gives random-effects estimates). Roles: S, survival synthesis; V, size-dependent vital-rate models; M, transition matrix (natural-colony survival and growth). Fragmentation in the matrix came only from Vardi [-@vardi2011], whose summaries also entered the survival synthesis.

| Study | Tier | Region(s) | Population type | Effects | *N* | Survival (%) | Roles |
|:----------------------------|:--|:-------------------|:------------|---:|----:|-----:|:-------|
| NOAA monitoring | 1 | Florida Keys, Curaçao, Navassa | Natural | 3 | 3,874 | 87.4 | S, V, M |
| Neely et al. [-@neely2022] | 1 | Florida Keys | Natural | 1 | 2,191 | 70.2 | S, V, M |
| Pausch et al. [-@pausch2018] | 1 | Florida Keys | Restoration | 1 | 968 | 57.4 | S, V |
| Kuffner et al. [-@kuffner2020] | 1 | Florida Keys | Restoration | 1 | 53 | 81.1 | S, V |
| USGS outplant experiment (unpublished) | 1 | US Virgin Islands | Restoration | 1 | 46 | 65.5 | S, V |
| FUNDEMAR fragments (unpublished) | 1 | Dominican Republic | Restoration | 1 | 44 | 86.6 | S, V |
| Mendoza Quiroz et al. [-@mendozaquiroz2023] | 1 | Mexican Caribbean | Natural (as coded) | -- | -- | -- | V, M |
| Vardi [-@vardi2011] | 2 | Jamaica, Puerto Rico, Virgin Gorda | Natural | 3 | 245 | 86.9 | S, M |
| Bruckner and Bruckner [-@bruckner2001] | 2 | Puerto Rico | Restoration | 1 | 105 | 90.5 | S |
| Ortiz Prosper [-@ortizprosper2005] | 2 | Puerto Rico | Restoration | 1 | 207 | 78.7 | S |
| Forrester et al. [-@forrester2013] | 2 | British Virgin Islands | Restoration | 1 | 257 | 53.3 | S |
| Rosales et al. [-@rosales2024] | 2 | Florida Keys | Restoration | 1 | 58 | 79.3 | S |
| Maurer et al. [-@maurer2022] | 2 | Bahamas | Restoration | 1 | 24 | 95.8 | S |
| Williams and Miller [-@williamsmiller2010] | 2 | Florida Keys | Restoration | 1 | 18 | 77.8 | S |
| Garrison and Ward [-@garrison2008] | 2 | US Virgin Islands | Natural and restoration | 2 | 75 | 69.3 | S |
| Rogers and Muller [-@rogersmuller2012] | 2 | US Virgin Islands | Natural | 1 | 69 | 94.2 | S |
| Ramos Romero et al. [-@ramosromero2025] | 2 | Cuba | Restoration | 1 | 200 | 70.5 | S |
| Rogers et al. [-@rogers1982] | 2 | US Virgin Islands | Natural | 1 | 173 | 48.0 | S |
| **Total** | | | | **22** | **8,607** | | |

\clearpage

## Study-window disturbance audit

**Table S2. Curated disturbance overlap was pervasive across the demographic records.** The audit independently rebuilt the disturbance overlay for 1,072 prepared survival intervals from the seven Tier 1 studies. Only 53 intervals (4.9%) overlapped no curated event. "Baseline exclusion" identifies the 297 intervals removed only in the acute-event sensitivity analysis; it does not mean that other intervals were undisturbed.

| Study | Intervals | No overlap | One event | Two or more events | Baseline exclusion | Any overlap (%) |
|:--|--:|--:|--:|--:|--:|--:|
| NOAA monitoring | 842 | 50 | 59 | 733 | 228 | 94.1 |
| Neely et al. [-@neely2022] | 98 | 3 | 0 | 95 | 10 | 96.9 |
| Pausch et al. [-@pausch2018] | 70 | 0 | 0 | 70 | 46 | 100.0 |
| USGS outplant experiment | 27 | 0 | 15 | 12 | 12 | 100.0 |
| Kuffner et al. [-@kuffner2020] | 27 | 0 | 0 | 27 | 0 | 100.0 |
| Mendoza Quiroz et al. [-@mendozaquiroz2023] | 7 | 0 | 0 | 7 | 0 | 100.0 |
| FUNDEMAR fragments | 1 | 0 | 0 | 1 | 1 | 100.0 |
| **Total** | **1,072** | **53** | **74** | **945** | **297** | **95.1** |

The independent rebuild found zero field mismatches. Full disturbance chronology, interval-level assignments, and extended diagnostics are available in the project repository.

\clearpage

## Growth-size diagnostics

**Fig. S1. Survival and growth change with colony size at different points in ontogeny.** (a) Annual survival against log live planar area; the label gives the improvement of the GAM over a linear model (ΔAICc = 17.9; the pre-specified gate for reporting a threshold was 2). (b) Probability of positive growth; the dashed line marks the supported threshold (411 cm²). (c) Second derivative of the relative-growth-rate GAM; the dashed line marks the steepest change in curvature (37 cm²). (d, e) Absolute growth rate (AGR, cm² yr$^{-1}$) and relative growth rate (RGR, yr$^{-1}$) against colony size. (f) Probability of positive growth fitted with a lower-dimension smooth (*k* = 3), which captures the broad U-shaped trend but not the dome detected in panel b. (g) Standard deviation of AGR and RGR within size bins on a log scale: AGR variance rose by more than two orders of magnitude across the size range, whereas RGR variance declined. Points are binned observations, lines are GAM fits, and ribbons or error bars are 95% confidence intervals. Analyses exclude the upper and lower 0.5% of relative-growth values to limit leverage by extreme proportional changes and exclude high-variance Navassa records.

![](06_analysis/figures/supplementary/FigS1_growth_diagnostics.pdf){ width=174mm }

\clearpage

## Population origin and study identity

**Fig. S2. Natural-colony and restoration-fragment comparisons are confounded by study identity and a narrow shared size range.** Each facet shows one Tier 1 study within the size range shared by natural and restoration records. (a) Annual survival and (b) relative growth rate (yr$^{-1}$) against initial live tissue area (cm²). Points are observations, coloured lines are study-specific binomial GLM (a) or linear model (b) fits on log size, shaded bands are 95% confidence intervals, and labels give population type and sample size. The shared range (11–202 cm²) is small relative to the full 1–15,000 cm² range, and within it survival slopes differed in sign among studies, so this comparison is descriptive rather than a causal estimate of restoration origin.

![](06_analysis/figures/supplementary/FigS8_natural_vs_restoration.pdf){ width=174mm }

\clearpage

## Shrinkage and retrogression

**Fig. S3. Large colonies commonly survived while losing tissue, and every non-recruit class moved backward through the size structure.** (a) Shrinkage frequency among surviving colonies by size class, rising from 18.2% in SC1 to 47.5% in SC5. (b) Mean annual tissue loss among shrinking colonies (cm² yr$^{-1}$). (c) Observed annual transition probabilities (growth, stasis, retrogression) by initial size class; labels give retrogression probabilities. (d) Shrinkage frequency by study; point colour gives mean tissue loss and point size the number of records. The analysis uses matrix-compatible records of surviving colonies with paired size observations.

![](06_analysis/figures/supplementary/FigS16_shrinkage_retrogression_summary.pdf){ width=174mm }

\clearpage

## Disturbance and size-dependent survival

**Fig. S4. The relationship between size and survival differed among curated disturbance states, but not as a simple disturbance penalty.** Tiles give observed (a) annual survival and (b) probability of positive growth by size class and disturbance state for natural colonies (*n* = 6,141 survival records). Tile labels are percentages. The size-by-state interaction was supported for survival (likelihood-ratio test, *p* < 0.001) and weaker for positive growth (*p* = 0.010). Large colonies survived better in intervals flagged for acute events (SC5, 98.0%, *n* = 409) than in intervals with no curated event (SC5, 83.9%, *n* = 193). The no-disturbance category contained only 353 records, including a single SC1 colony, so its SC1 tile is not interpretable. Disturbance states are observational and confounded with study, site, and survey period.

![](06_analysis/figures/supplementary/FigS17_disturbance_size_interaction.pdf){ width=174mm }

\clearpage

## Restoration subtype sensitivity

**Fig. S5. Apparent restoration performance depends on the biological material grouped under that label.** (a) Annual survival and (b) mean relative growth rate (yr$^{-1}$) for naturally occurring fragments (3,968 records, one study), nursery outplants (1,012 records, two studies), nursery outplants re-cemented after fragmentation (53 records, one study), and outplanted colonies (46 records, one study). Open circles are study summaries, with symbol size proportional to records; filled diamonds are record-weighted subtype means, and horizontal lines span the study summaries. These contrasts are descriptive because subtype, study, site, handling, and sample size are not independently balanced.

![](06_analysis/figures/supplementary/FigS19_restoration_subtype_sensitivity.pdf){ width=174mm }

\clearpage

## Florida-scale heatwave scenarios

**Fig. S6. Recurrence of Florida-scale heatwave mortality drives effective lambda far below one in the recruitment-free transition subsystem.** (a) Logistic mortality curve parameterized from the *A. palmata* DHW thresholds reported by Manzello et al. [-@manzello2025] (ED50 = 7.8 DHW; ED95 = 17.6 DHW); the shaded range marks the 16–20 DHW exposure in the Florida Keys in 2023. (b) Median 50-year trajectories and 95% simulation intervals without heatwaves and for the observed 2023 Florida endpoint (97.8–100% mortality) at four return intervals; the dashed line marks the quasi-extinction threshold of 10% of initial abundance. (c) Effective lambda across dose-response and observed-endpoint scenarios; bars are geometric means from the bootstrap-based simulations, and the dotted line is the unperturbed deterministic lambda (0.961). Without heatwaves, the simulations had an effective lambda of 0.933 and a 70.8% probability of quasi-extinction within 50 years; every observed-endpoint scenario reached quasi-extinction in all simulations. The 5-, 10-, 20-, and 50-year intervals span frequent to rare recurrence and are sensitivity values, not estimated return periods. These are Florida-like event stress tests, not Caribbean-wide forecasts.

![](06_analysis/figures/supplementary/FigS22_heatwave_scenarios.pdf){ width=174mm }

## References
