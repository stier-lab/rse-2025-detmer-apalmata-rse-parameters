# Transferability Summary

This synthesis supports a narrow set of findings that appear broadly transferable across the Caribbean, and a larger set of estimates that are study-, region-, or event-specific. The distinction matters because the dataset is strong on size-structured demography and disturbance context, but still uneven across geography, size range, and disturbance history.

## Broadly transferable findings

- Survival increases with colony size, but the relationship is not well described by a simple linear effect.
- Growth is strongly size dependent, and relative growth rate is the more transferable metric than absolute growth because it reduces some of the scale confounding seen across studies.
- Large adults remain demographically important across settings: SC5 stasis dominates elasticity, so persistence of large colonies is a general viability lever.
- Disturbance should be treated as part of the demographic regime, not as statistical noise. Hurricanes, disease, bleaching, cold events, and chronic pressures all alter demographic performance in ways that are biologically coherent across the Caribbean.
- Natural-versus-restoration differences are real enough to matter, but they are often entangled with size-range differences and study design, so the general direction is more transferable than the exact magnitude.
- Heterogeneity is itself a robust result: high between-study variation means that any pooled estimate should be treated as conditional, not universal.

## Study- or region-specific findings

- The exact threshold values are not fully transferable. The current survival inflection, growth thresholds, and positive-growth turning point are shaped by the available study mix, which is heavily weighted toward Florida and a few large monitoring datasets.
- Exact `lambda` values and elasticity decompositions are context dependent because they are dominated by specific study compositions, especially NOAA-derived size structure and SC5 survival.
- Disturbance timing is highly local even when the disturbance type is general. The 2005 thermal anomaly, 2014 disease event, 2023 heatwave, and major hurricanes are all Caribbean-relevant, but their demographic consequences depend on where and when they occurred.
- Restoration recovery timelines are site-specific. The difference between faster- and slower-recovering sites is useful for restoration planning, but those numbers should not be generalized beyond the study regions without caution.
- Recruitment and fecundity remain weakly transferable because the current synthesis contains direct life-history evidence for thresholds and bottlenecks, not a full Caribbean fecundity schedule.

## How to use this in the manuscript

- State the direction of the main biological relationships as general Caribbean patterns.
- Report threshold values, `lambda`, and regional recovery differences as estimates conditional on the current study mix.
- Use disturbance summaries to explain mechanism and timing, not to imply universal event effects.
- Treat Florida-dominant results as informative but not fully representative of the whole Caribbean.
- Avoid overgeneralizing restoration-specific contrasts unless they are supported by matched-size or subtype analyses.

## Catastrophic heatwave regime (post-Manzello 2025)

The 2023 marine heatwave and functional extinction of *A. palmata* from Florida (Manzello et al. 2025, *Science*) introduces a third layer to the transferability framework: the **catastrophic override regime**.

- Under the chronic disturbance regime captured by our synthesis (storms, moderate bleaching, disease, chronic stress), size-dependent vital rates operate as described by our GAMs, GLMMs, and transition matrix. Lambda = 0.967 and SC5 stasis dominates elasticity.
- Under extreme thermal events (DHW >= 17.6), the Manzello dose-response shows that mortality approaches 95-100% regardless of colony size. Size-dependent survival advantages effectively collapse.
- The chronic-regime vital rates remain transferable as a description of inter-event demography: how populations behave between catastrophic events and what recovery potential exists. But forward projections must layer catastrophic pulses onto the chronic matrix.
- Heatwave scenario analysis (Script 40) shows that even rare catastrophic events (every 20-50 years) substantially reduce effective lambda and increase quasi-extinction probability relative to the chronic-regime baseline. Frequent catastrophic events (every 5-10 years) drive populations to near-certain quasi-extinction within decades.
- The Manzello dose-response parameters (ED50 = 7.8 DHW, ED95 = 17.6 DHW) are themselves transferable as an upper thermal sensitivity bound for *A. palmata* across the Caribbean, pending confirmation from non-Florida populations.

**Restoration implication:** Our synthesis identifies the demographic targets (grow to SC4-SC5, protect large colonies). Manzello identifies the thermal constraint (colonies must also tolerate extreme heat). Neither is sufficient alone. Restoration planning must integrate both: size-structured demography to set numerical targets, and thermal tolerance interventions (assisted gene flow, symbiont manipulation) to keep colonies alive through increasingly frequent extreme events.

## Short version

The transferable claim is that *A. palmata* demography is strongly size structured, nonlinear, disturbance sensitive, and heterogeneous across the Caribbean. The non-transferable layer is the exact numerical threshold, viability, and recovery estimates, which remain conditional on study composition, region, and disturbance history. Post-Manzello (2025), a third claim is transferable: extreme heatwaves (DHW >= 17.6) override size-dependent survival, making thermal tolerance as important as colony size for population persistence.
