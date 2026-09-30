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

1. Study-window disturbance audit (Table S1)
2. Growth-size diagnostics (Fig. S1)
3. Population origin is confounded with study identity (Fig. S2)
4. Shrinkage and retrogression (Fig. S3)
5. Disturbance changes size-dependent performance (Fig. S4)
6. Restoration subtype sensitivity (Fig. S5)
7. Florida-scale heatwave scenarios (Fig. S6)

## Study-window disturbance audit

**Table S1. Curated disturbance overlap was pervasive across the demographic records.** The audit independently rebuilt the disturbance overlay for 1,072 prepared survival intervals from seven studies. “Baseline exclusion” identifies intervals removed only in the acute-event sensitivity analysis; it does not mean that other intervals were undisturbed.

| Study | Intervals | No overlap | One event | Two or more events | Baseline exclusion | Any overlap (%) |
|:--|--:|--:|--:|--:|--:|--:|
| NOAA survey | 842 | 50 | 59 | 733 | 228 | 94.1 |
| Neely et al. 2022 | 98 | 3 | 0 | 95 | 10 | 96.9 |
| Pausch et al. 2018 | 70 | 0 | 0 | 70 | 46 | 100.0 |
| USGS USVI experiment | 27 | 0 | 15 | 12 | 12 | 100.0 |
| Kuffner et al. 2020 | 27 | 0 | 0 | 27 | 0 | 100.0 |
| Mendoza-Quiroz et al. 2023 | 7 | 0 | 0 | 7 | 0 | 100.0 |
| FUNDEMAR fragments | 1 | 0 | 0 | 1 | 1 | 100.0 |

The independent rebuild found zero field mismatches. Full disturbance chronology, interval-level assignments, and extended diagnostics are available in the project repository.

\clearpage

## Growth-size diagnostics

**Fig. S1. Growth changes most sharply at small colony sizes, whereas absolute-growth variance increases with size.** Panels (a–c) show annual survival, probability of positive growth, and the second derivative of relative growth rate against log live planar area (cm²). Points are binned observations, lines are generalized additive model fits, and ribbons or error bars are 95% confidence intervals. Dashed lines identify supported threshold estimates. Panels (d–g) compare absolute and relative annual growth-rate representations and show the increasing variance of absolute growth with colony size. Analyses exclude the upper and lower 0.5% of relative-growth values to limit leverage by extreme proportional changes and exclude high-variance Navassa records; sample sizes and model specifications are reported in the figure panels.

![](06_analysis/figures/supplementary/FigS1_growth_diagnostics.pdf){ width=174mm }

\clearpage

## Population origin and study identity

**Fig. S2. Natural-colony and restoration-fragment comparisons are confounded by study identity and limited shared size range.** Each facet shows the study-specific relationship between initial live tissue area (cm²) and annual survival (top) or relative growth rate (yr$^{-1}$; bottom). Points are observations, coloured lines are study-specific linear fits, and shaded bands are 95% confidence intervals. The displayed common size range (11–202 cm²) is small relative to the full 1–15,000 cm² range, so this comparison is descriptive rather than a causal estimate of restoration origin.

![](06_analysis/figures/supplementary/FigS8_natural_vs_restoration.pdf){ width=174mm }

\clearpage

## Shrinkage and retrogression

**Fig. S3. Large colonies commonly survived while losing tissue and sometimes moved backward through the size structure.** Panels show shrinkage frequency, mean annual tissue loss (cm² yr$^{-1}$), observed size-class transition probabilities, and study-level shrinkage summaries. Colours and symbols identify the population type or size class specified in each panel; displayed bars and intervals represent the plotted empirical summaries. The analysis includes surviving colonies with paired size observations.

![](06_analysis/figures/supplementary/FigS16_shrinkage_retrogression_summary.pdf){ width=174mm }

\clearpage

## Disturbance and size-dependent performance

**Fig. S4. The relationship between size and survival differed among curated disturbance states.** Tiles give observed survival probability (top) and probability of positive growth (bottom) by size class and disturbance state for natural colonies. Tile labels are percentages; colour scales encode the same quantities. The survival interaction was supported by a likelihood-ratio test (P < 0.001); growth-side evidence is shown as supporting context rather than a definitive interaction estimate.

![](06_analysis/figures/supplementary/FigS17_disturbance_size_interaction.pdf){ width=174mm }

\clearpage

## Restoration subtype sensitivity

**Fig. S5. Apparent restoration performance depends on the biological material grouped under that label.** Panel (a) summarizes annual survival and panel (b) mean relative growth rate (yr$^{-1}$) for natural fragments, nursery outplants, re-cemented nursery outplants, and direct outplants. Points are study summaries, larger symbols indicate more observations, and colours identify subtype. These contrasts are descriptive because subtype, study, site, handling, and sample size are not independently balanced.

![](06_analysis/figures/supplementary/FigS19_restoration_subtype_sensitivity.pdf){ width=174mm }

\clearpage

## Florida-scale heatwave scenarios

**Fig. S6. Recurrence of Florida-scale heatwave mortality drives effective lambda below one in the recruitment-free transition subsystem.** Panel (a) shows the logistic mortality curve parameterized from the *A. palmata* DHW thresholds reported by Manzello et al. [@manzello2025]; the shaded range marks the 2023 Florida Keys exposure. Panel (b) gives median 50-year trajectories and 95% simulation intervals for the observed 2023 Florida endpoint (97.8–100% mortality) at four return intervals. Panel (c) compares effective lambda across dose-response and observed-endpoint scenarios; bars are geometric means from the bootstrap-based simulations, whereas the dotted line is the unperturbed chronic-regime deterministic lambda (0.961). The 5-, 10-, 20-, and 50-year intervals span frequent to rare recurrence and are sensitivity values, not estimated return periods. These are Florida-like event stress tests, not Caribbean-wide forecasts.

![](06_analysis/figures/supplementary/FigS22_heatwave_scenarios.pdf){ width=174mm }

## References
