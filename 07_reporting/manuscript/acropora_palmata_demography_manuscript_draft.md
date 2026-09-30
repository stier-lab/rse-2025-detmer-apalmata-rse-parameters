---
title: "Size-dependent demography, disturbance, and transition dynamics of *Acropora palmata* across the Caribbean"
article_type: "Report"
target_journal: "Coral Reefs"
status: "Complete first manuscript draft; citations and submission metadata require final verification"
bibliography:
  - ../../paper/manuscript/references.bib
  - ../../paper/manuscript/palmata_library.bib
link-citations: true
header-includes:
  - \usepackage{pdflscape}
---

Adrian C. Stier^1^, A. Raine Detmer^1,^*, Jameal F. Samhouri^2^, Darcy Bradley^3^, Aldo Croquer^4^, and Rita I. Sellares-Blasco^5^

^1^ Department of Ecology, Evolution, and Marine Biology, University of California, Santa Barbara, California, USA  
^2^ Conservation Biology Division, Northwest Fisheries Science Center, National Marine Fisheries Service, National Oceanic and Atmospheric Administration, Seattle, Washington, USA  
^3^ California Oceans Program, The Nature Conservancy, Sacramento, California, USA  
^4^ The Nature Conservancy, Caribbean Division, Punta Cana, Dominican Republic  
^5^ Fundación Dominicana de Estudios Marinos (FUNDEMAR), Bayahibe, Dominican Republic  
^*^ Correspondence: A. Raine Detmer

## Abstract

Restoration and recovery of the endangered elkhorn coral *Acropora palmata* depend on demographic rates that vary across colony sizes, locations, and disturbance histories. Yet those rates have rarely been synthesized in a form that can identify the size classes and transitions most relevant to population persistence. We compiled Caribbean-wide longitudinal records of survival, growth, fragmentation, and size from individual-level monitoring and published study summaries. We estimated size-dependent vital rates, evaluated disturbance and restoration context, and incorporated those rates into a five-class, recruitment-free Lefkovitch transition model. Annual survival increased with colony size, whereas relative growth changed most sharply among small colonies. The harmonized survival synthesis showed substantial variation among studies and regions. Tissue loss was common among surviving colonies, and partial mortality produced backward transitions across all non-recruit size classes. The conditional post-settlement transition subsystem had a dominant eigenvalue below one, with large-adult stasis contributing most to its elasticity. Size--survival associations differed among curated exposure categories, and restoration records could not be interpreted as one biologically uniform class. These results show that *A. palmata* recovery depends not only on increasing the number of corals deployed, but on maintaining colonies through the transitions that produce persistent large adults. The synthesis provides parameter distributions and explicit uncertainty bounds for conditional transition analyses and restoration planning across a changing Caribbean.

Keywords: Caribbean coral reefs; demographic synthesis; elkhorn coral; meta-analysis; population dynamics; restoration

## Introduction

Foundation species create the structure on which ecological communities depend, but their recovery requires more than replacing individuals that have been lost. For colonial organisms, the demographic consequences of loss depend on which colonies die, which survive after partial mortality, and which transitions move colonies toward or away from reproductive size. These processes are particularly consequential for Caribbean acroporids, whose regional declines have reduced both coral cover and the three-dimensional habitat that elkhorn coral once provided [@gardner2003]. Restoration programs increasingly propagate and outplant *Acropora palmata*, but the demographic information used to choose target sizes, sites, and intervention schedules remains fragmented among studies and regions.

Colony size is a central axis of coral demography. Small colonies may grow rapidly in proportional terms but are exposed to high mortality, whereas large colonies can persist, reproduce, and fragment. However, colonies do not move through size structure only by growing or dying. Storm damage, disease, predation, and tissue loss can reduce the live area of colonies that remain alive, producing shrinkage and retrogression rather than immediate whole-colony mortality [@lirman1997; @madin2020]. A demographic analysis that treats all surviving colonies as stable therefore risks obscuring the processes that determine whether individuals eventually contribute to adult population structure.

The Caribbean setting adds a second complication: demographic records were collected across populations that experienced different histories of storms, disease, bleaching, and chronic environmental stress. These events are often treated as inconvenient variation to remove before estimating a baseline vital rate. Yet disturbance is part of the regime in which *A. palmata* populations persist or decline. The 2023 marine heatwave, which caused functional extinction of *A. palmata* in Florida, makes this point especially clear: older demographic records describe an earlier chronic regime, not an enduring environmental baseline [@manzello2025]. A useful synthesis must therefore separate the question of a counterfactual low-disturbance estimate from the question of how colonies actually performed within their observed disturbance histories.

Restoration introduces a third source of heterogeneity. Nursery outplants, colonies re-cemented after fragmentation, direct outplants, and naturally fragmented colonies differ in size, handling, environment, and likely mortality processes [@forrester2012; @ramosromero2025; @banister2024]. Treating these materials as one "restoration fragment" category can yield a pooled comparison that is statistically convenient but biologically ambiguous. This distinction matters because early survival bottlenecks and later outplant performance need not be governed by the same processes [@williams2008; @williams2023].

Here, we synthesized the available longitudinal demographic evidence for *A. palmata* across the Caribbean. We asked: (1) how do survival and growth vary with colony size; (2) how common are shrinkage and retrogression among surviving colonies; (3) how do disturbance histories and restoration subtypes change demographic interpretation; and (4) what do these vital rates imply for a recruitment-free post-settlement transition subsystem? We combined individual-level observations from seven studies with summary-level effects from ten additional studies, standardized colony size to live planar area, and linked the resulting vital rates to a five-class transition model. We expected size to structure both survival and growth, size--survival associations to differ among observed exposure categories, and large-adult persistence to exert disproportionate influence on conditional transition dynamics. Our goal was not to produce a universal Caribbean rate for a heterogeneous species, but to identify the patterns that are robust across the available evidence and the uncertainties that should bound restoration decisions.

## Materials and methods

### Literature search and study selection

We conducted a systematic compilation of published *A. palmata* demographic data. The original search was conducted from June through December 2025 and drew on four sources: repositories maintained by NOAA and the US Geological Survey, structured Google Scholar searches, backward and forward citation searching from focal demographic studies, and data shared by restoration practitioners. We then completed an expanded audit in March 2026 using PubMed, Web of Science, Semantic Scholar/Elicit, targeted citation searches, and the project literature library. Search terms combined *Acropora palmata* or elkhorn coral with survival, mortality, growth, recruitment, restoration, and long-term monitoring terms. Detailed search strings, screening logic, and study-level exclusions are retained with the project documentation.

We included studies that reported longitudinal observations of identified *A. palmata* colonies or fragments, survival or areal growth over a defined interval, and sufficient information to annualize survival or estimate a size-dependent vital rate. We excluded cross-sectional condition surveys, studies that reported only branch extension, laboratory micro-fragment experiments smaller than 1 cm², and overlapping analyses of the same tagged-colony datasets. Titles and abstracts were screened first, followed by full-text evaluation. A second reviewer independently evaluated a subset of expanded-search candidates; disagreements were adjudicated by a third review. The final survival synthesis included 17 studies contributing 22 study-level effects.

### Data extraction and standardization

We organized retained records into two tiers. Tier 1 studies supplied individual colony identifiers, repeated sizes, and survival fates; these records supported analyses of survival, growth, shrinkage, and size-class transitions. Tier 2 studies supplied study-level survival proportions, sample sizes, and where available mean colony size. The survival and growth files contained 7,842 and 6,318 raw interval records, respectively. The current meta-analysis uses an effective denominator of 8,607 after interval filtering and study-level aggregation; it is not an individual-observation count. The study landscape and size coverage are shown in Fig. 1.

We standardized colony size as live planar tissue area in cm². For records containing perpendicular dimensions and live-tissue proportion, we calculated area as length × width × proportion live tissue, following the convention used in previous *A. palmata* matrix models (Vardi et al. 2012). For diameter-only records, we estimated area from a circular footprint. Where a study reported a single linear measure, we applied study-informed width-to-length ratios; records for which size could not be defensibly converted were retained for survival synthesis but not size-dependent analyses. We annualized non-annual survival as $S_{\mathrm{annual}} = S_{\mathrm{observed}}^{1/t}$, where $t$ is the monitoring interval in years.

We assigned colonies to five size classes: SC1, 0–10 cm²; SC2, 10–100 cm²; SC3, 100–900 cm²; SC4, 900–4,000 cm²; and SC5, >4,000 cm². These boundaries retain the structure of the published *A. palmata* Lefkovitch model while separating recruits from small juveniles [@vardi2011]. Shrinkage was negative annual change in live tissue area among colonies that survived an interval. Retrogression was an observed transition from a larger to a smaller size class.

### Disturbance and restoration classification

We retained all intervals in primary analyses because observed storms, disease, bleaching, cold events, and chronic stressors comprise the demographic context experienced by the study populations. We then linked each interval to a curated Caribbean disturbance timeline. The timeline distinguished acute events used in baseline-exclusion sensitivity analyses from chronic or indirect pressures retained as contextual exposure. We independently rebuilt the interval-to-event linkage and summarized it as a study-window audit (Table S2). We fitted size-by-disturbance interaction models to natural-colony records, thereby avoiding the confounding of disturbance context with restoration material and handling history.

For restoration analyses, we used study metadata to classify records as natural fragments, nursery outplants, nursery outplants re-cemented after fragmentation, or outplanted colonies. This subtype analysis was an interpretive sensitivity analysis, not a causal comparison of interventions. It was designed to test whether the broad label "restoration fragment" concealed demographic differences among biologically distinct materials.

### Vital-rate, meta-analytic, and population analyses

We modeled annual survival as a function of log-transformed colony size using binomial generalized additive models and modeled relative growth rate with Gaussian generalized additive models. These main-figure curves are unadjusted descriptive GAMs; mixed-effect models accounting for study were used as diagnostics and sensitivity analyses rather than as the source of their displayed intervals. We used a pre-specified threshold analysis to evaluate nonlinear functional form and identify supported inflection points. We interpreted thresholds as data- and study-composition-dependent features rather than fixed biological boundaries. We assessed model diagnostics and study dependence with the pre-specified verification and leave-one-study-out procedures documented in the project repository.

For the expanded survival synthesis, we annualized interval-level survival using a constant-hazard transformation, $S_{\mathrm{annual}} = S_{\mathrm{observed}}^{1/t}$, before aggregating study-region effects. We transformed those annualized proportions to proportional log-odds effect sizes and applied a 0.5 continuity correction to zero cells. The primary random-effects model was a three-level REML model with study and within-study effect structure and *t*-based inference; an independent-effect model with Knapp–Hartung inference was a sensitivity analysis [@knapp2003; @viechtbauer2010]. We report pooled survival, 95% confidence intervals, prediction intervals, and heterogeneity statistics. We evaluated population type, colony size, year, and region as exploratory moderators because the number of effects was limited. We also performed leave-one-out, classification, and risk-of-bias sensitivity analyses.

We constructed a five-class, recruitment-free Lefkovitch transition matrix from the prepared natural-colony transition data. The dominant eigenvalue (lambda) represented conditional annual growth of the observed post-settlement transition subsystem, not a full population forecast. Matrix support was uneven: five studies contributed survival, three contributed growth, SC5 survival was predominantly supported by NOAA records, and fragmentation was represented by Vardi (2011). We quantified the elasticity of lambda to stasis, growth, retrogression, and fragmentation transitions, and propagated sampling uncertainty through hierarchical bootstrap resampling: studies were resampled first, then observations within sampled studies. We used 2,000 valid bootstrap replicates and leave-one-study-out analyses to characterize dependence on the contributing datasets; 43 bootstrap replicates imputed at least one missing size-class survival value, and the resampling did not propagate survival–growth covariance.

### Reproducibility

All data processing, analysis, figures, and manuscript-facing tables are maintained in the accompanying public repository. The analysis workflow, canonical output inventory, claim-to-output crosswalk, and figure map identify the script and output underlying each main-text claim (Data availability statement below). A versioned archival release will be deposited upon acceptance.

## Results

### The available evidence is Caribbean-wide but unevenly distributed

The synthesis combined individual-level monitoring with study-level records across 13 Caribbean regions (Fig. 1). Coverage was geographically uneven: Florida supplied the largest share of observations, whereas several non-Florida regions contributed data from only a subset of size classes. Large adults outside Florida, Curaçao, and Navassa were particularly sparse. This imbalance matters because large colonies have the greatest demographic leverage in the projection model, while the regional settings in which they are best represented do not encompass the full Caribbean range.

### Survival and growth were nonlinear functions of colony size

Survival increased with colony size, although the fitted relationship explained a modest share of individual survival variation (Fig. 2a). The survival model identified a high-size inflection near 7,498 cm², but leave-one-study-out estimates were broad, indicating that the exact location of this threshold was not stable across the study mix. Relative growth rate showed a sharper early ontogenetic transition: the estimated inflection occurred near 37 cm², while the probability of positive growth crossed its threshold near 411 cm² (Fig. 2b; Fig. S5). Relative growth captured size dependence more effectively than absolute growth rate, whose variance increased strongly with colony size (Fig. S6).

Study-level survival estimates by size class reinforced this pattern but also showed substantial overlap among classes and studies (Fig. 2c). Size therefore structured demographic performance, but it did not supply a region- or disturbance-independent prediction of fate. The widest variability occurred among the smaller and intermediate classes, where study context, disturbance history, and population type varied most strongly.

### Caribbean-wide survival was heterogeneous

The expanded synthesis estimated pooled annual survival at 78.7% (95% CI: 70.4--85.1%; 95% prediction interval: 37.4--95.8%) across 17 studies and 22 study-region effects (Fig. 3a). Tier 1 and Tier 2 effects were both annualized before aggregation. Heterogeneity was high (I² = 97.6%), so the pooled value summarizes the assembled evidence rather than a Caribbean-wide constant.

Natural-colony effects had higher pooled survival than restoration-fragment effects (84.1% versus 74.5%), but the difference was not statistically supported in the expanded meta-analysis. Regional variation remained substantial within population types (Fig. 3b; Fig. S15). The overlap-zone comparison likewise showed that study identity and sampling context could not be separated cleanly from population origin (Fig. S8). These analyses do not support a single general survival penalty or benefit of restoration origin.

### Shrinkage and retrogression were common components of demographic performance

Colonies often survived while losing tissue. In the matrix-compatible growth dataset, 39.4% of records showed shrinkage (Fig. S16). Shrinkage frequency increased from 18.2% in SC1 to 47.5% in SC5, demonstrating that large colonies were not simply stable endpoints. Retrogression probabilities were 15.2% in SC2, 16.8% in SC3, 17.2% in SC4, and 9.1% in SC5. Thus, large colonies persisted more reliably than small colonies, but partial mortality still moved a measurable fraction of survivors backward through the size structure.

### Size--survival associations differed among exposure categories

The study-window audit covered 1,072 demographic intervals, 95.1% of which overlapped at least one curated disturbance or chronic-pressure record (Table S2). The survival relationship with colony size differed among intervals with no curated disturbance, context-only pressure, and acute baseline-exclusion exposure (likelihood-ratio test, \(p<0.001\); Fig. S17). Growth-side interaction evidence was weaker and is therefore treated as supportive rather than definitive. Excluding all acute baseline-exclusion intervals changed the pooled survival estimate by only −0.3 percentage points, indicating that the main pooled result was not driven solely by locally identified acute events. Instead, disturbance exposure was pervasive across the monitored demographic regime.

### Restoration performance depended on subtype

The subtype-coded dataset contained 5,079 records from five studies (Fig. S19): 3,968 natural fragments from one study, 1,012 nursery outplants from two studies, 53 re-cemented nursery outplants from one study, and 46 direct outplants from one study. Natural fragments had weighted survival of 87.1%, compared with 58.7% for nursery outplants, 81.1% for nursery outplants re-cemented after fragmentation, and 65.2% for outplanted colonies. Excluding natural fragments reduced mean survival across subtype-coded records from 81.2% to 60.0%. These contrasts show why a broad restoration-fragment category is not an adequate biological description of the material represented in the synthesis; they are descriptive because the subtype groups are highly unbalanced.

### Large-adult persistence dominated conditional transition dynamics

The recruitment-free transition matrix estimated a deterministic lambda of 0.961 (95% bootstrap interval: 0.816–1.010; Fig. 4). In 94.3% of hierarchical-bootstrap replicates, lambda was below one. This resampling fraction characterizes uncertainty in the compiled transition rates; it is not a probability of real-world population decline. Stasis dominated the transition matrix, and SC5-to-SC5 stasis accounted for 58.9% of matrix-cell elasticity. Leave-one-study-out estimates of lambda ranged from 0.882 to 0.993, indicating substantial dependence on the small number of natural-colony transition datasets. Within this conditional, recruitment-free subsystem, persistence of large adults had more influence on lambda than marginal changes in any single early transition.

## Discussion

Our synthesis shows that *A. palmata* demography is structured not only by whether colonies survive, but by how colony size, partial mortality, and disturbance determine the transitions that survivors make. Three conclusions follow. First, survival and growth change nonlinearly with size, with early growth transitions and large-adult persistence playing different demographic roles. Second, shrinkage and retrogression are common enough that a live/dead framing misses a central route by which colonies lose future reproductive and structural value. Third, the heterogeneity among studies is not a nuisance to average away: it defines the limits of any regional estimate and the conditions under which restoration comparisons can be interpreted.

Large colonies carried the greatest leverage for population growth because their stasis had the highest elasticity. This result is consistent with size-structured coral demography, in which large colonies combine higher survival, reproductive potential, and the capacity to produce fragments (Vardi et al. 2012; Madin et al. 2025). However, large colonies were not invulnerable. Tissue loss was frequent even in the largest class, and colonies in every non-recruit class sometimes retrogressed. The implication is not simply that restoration should make colonies larger. Rather, strategies should be evaluated by whether they keep colonies alive and prevent the backward transitions that erode the adult size structure.

The nonlinear growth pattern clarifies why size-based restoration targets cannot be inferred from a single average growth rate. Relative growth changed most rapidly at small sizes, while survival increased across a much larger size range. Those patterns create a demographic tradeoff: retaining corals through early size classes may yield large proportional gains, but maintaining existing adults can contribute more directly to persistence. The exact size thresholds should not be treated as universal biological cutoffs because they varied with the study composition and measurement context. Their value is instead diagnostic: they identify where marginal improvements in growth or survival could have the largest demographic consequences in the current evidence base.

Most intervals in the synthesis overlapped a documented event or chronic pressure, and the size--survival relationship differed among disturbance states. The disturbance layer does not identify a single causal effect of storms, disease, or heat because the underlying studies were not designed as a common experiment and their event histories differed. The evidence therefore supports a narrower conclusion: transition analyses should retain disturbance history as part of the context in which observed size-dependent rates were generated. The 2023 heatwave makes this boundary especially important. Our estimates describe a chronic regime preceding the recent Florida collapse, and they should not be interpreted as forecasts under severe contemporary thermal stress (Manzello et al. 2025).

The restoration comparison likewise requires a constrained interpretation. Natural-colony and broad restoration-fragment effects overlapped in the expanded meta-analysis, but the subtype decomposition showed marked variation among nursery outplants, re-cemented colonies, direct outplants, and natural fragments. These materials differ in handling, age, size, substrate, and exposure; the present data do not isolate any one of those mechanisms. However, the result does show that average restoration survival is not a transferable property of a generic fragment. This is an important distinction for programs that use benchmarks from related species or later life stages. A target that is realistic for established outplants may be inappropriate for the earliest steps of sexual propagation, when survival bottlenecks are likely to be different.

Extreme heterogeneity is the central limitation and the central contribution of this synthesis. The prediction interval spanned most of the probability scale, mortality definitions varied among source studies, and the individual-level dataset was heavily weighted toward Florida. Large adults outside a few regions remained poorly represented, even though they had the greatest elasticity. These limitations constrain the precision of absolute regional estimates and the generality of the projected lambda. However, they do not erase the recurring patterns: size dependence, frequent partial mortality, large-adult leverage, and the importance of disturbance and intervention context. By retaining study identity, reporting prediction intervals, and distinguishing material subtypes, the synthesis makes these limitations visible rather than embedding them in an apparently precise pooled rate.

The next empirical priority is therefore not another undifferentiated estimate of average survival. Longitudinal monitoring should target the transitions that most limit inference: survival and retrogression of large adults outside Florida, early post-outplant survival for defined restoration materials, and the responses of those transitions to heat, disease, and storms. Comparable measurements of live area, mortality definition, monitoring interval, colony origin, and disturbance exposure would allow future synthesis to distinguish biological variation from measurement variation. Recruitment and fecundity remain less well estimated than survival and growth, so a fully Caribbean-wide demographic model still requires better information on early-life and reproductive transitions.

Recovery of a foundation species depends on rebuilding the demographic pathways that create durable ecological structure. For *A. palmata*, that pathway cannot be represented by outplant counts or average survival alone. It is shaped by the size of colonies, the tissue they retain after disturbance, and the environmental and restoration contexts in which they move through the population. A transparent synthesis of those processes provides a defensible starting point for conditional transition analysis and for restoration strategies that seek persistent coral habitat rather than short-lived planting records.

## Statements and Declarations

### Funding

This work was supported by The Nature Conservancy.

### Competing interests

The authors declare no competing interests.

### Ethics approval and permits

Not applicable. This study synthesized existing observations and published
study summaries and involved no new human-participant research, animal use, or
field collection requiring ethical approval or permits.

### Consent to participate

Not applicable.

### Consent to publish

Not applicable.

### Data availability

The data and code underlying this study are maintained at
<https://github.com/stier-lab/Detmer-2025-coral-parameters>. A versioned
archival release will be deposited upon acceptance.

### Author contributions

A.C.S. conceived the study and led manuscript development. A.R.D. led data
curation and analyses. J.F.S., D.B., A.C., and R.I.S.-B. contributed domain
expertise, data resources, and interpretation. All authors reviewed and
approved the manuscript.

## Figure legends

```{=latex}
\footnotesize
```

**Fig. 1** Study landscape for the *Acropora palmata* demographic synthesis. (a) Study locations across the Caribbean. Circle symbols identify regions represented by individual-level observations; triangles identify regions represented only by summary-level studies. Symbol area is proportional to the number of observations, and labels give regional totals. Locations are regional centroids. (b) Availability of individual-level observations by canonical size class and region; cell labels are sample sizes, and darker cells indicate more observations. Empty cells indicate no available observations. Size classes are SC1, 0–10 cm²; SC2, 10–100 cm²; SC3, 100–900 cm²; SC4, 900–4,000 cm²; and SC5, >4,000 cm².

**Fig. 2** Size-dependent demographic rates for *Acropora palmata*. (a) Annual survival probability as a function of live tissue area for natural colonies. The line and shaded band are an unadjusted binomial generalized additive model (GAM) and its 95% confidence interval; points are binned observed proportions. Upper and lower rugs identify survival and mortality observations, respectively. (b) Relative growth rate (yr$^{-1}$) for natural colonies. The line and band are the unadjusted Gaussian GAM estimate and 95% confidence interval; pale points are individual observations, gold points are binned medians, and the dashed vertical line and band show the supported threshold and its cluster-bootstrap interval. (c) Study-level annual survival by size class. Colour indicates population type, shape identifies data tier, and point area is proportional to sample size; diamonds and error bars are pooled estimates and 95% confidence intervals. *k* gives the number of contributing effects.

**Fig. 3** Caribbean-wide survival synthesis for *Acropora palmata*. (a) Random-effects annual-survival estimates from 17 studies contributing 22 effects. Points and horizontal lines are study estimates and 95% confidence intervals; point area is proportional to random-effects weight. Circles represent individual-level data and triangles summary-level data. Coloured diamonds are population-type pooled estimates, the dark diamond is the overall pooled estimate, the dashed line marks that estimate, and the shaded interval is its 95% prediction interval. (b) Regional study estimates and 95% confidence intervals. Colour identifies population type, point area is proportional to sample size, and dark diamonds identify regional pooled estimates where at least two effects were available. The dashed line marks overall pooled annual survival.

**Fig. 4** Conditional transition dynamics for *Acropora palmata*. (a) Five-class, recruitment-free Lefkovitch transition matrix. Cells give annual transition probabilities from size class at time *t* to size class at time *t* + 1; colour encodes probability. (b) Elasticity decomposition by source size class. Stacked bars show stasis, growth, and retrogression; orange points show fragmentation elasticity, which is displayed separately because it is a component of retrogression rather than an additional transition class. (c) Distribution of lambda from 2,000 hierarchical-bootstrap replicates. Orange bars denote replicates with lambda < 1 and blue bars replicates with lambda at least 1; the distribution characterizes uncertainty in the compiled transition rates, not the probability of real-world decline. The dashed line is the deterministic estimate and the solid line marks replacement. (d) Leave-one-study-out lambda estimates. The dashed and dotted lines mark the full-data estimate and replacement, respectively; orange identifies exclusion of the NOAA survey.

```{=latex}
\normalsize
\clearpage
```

## Figures

![](06_analysis/figures/manuscript/Fig1_study_landscape.pdf){ width=160mm }

**Figure 1. Study landscape and size-class coverage for the *Acropora palmata* demographic synthesis.**

![](06_analysis/figures/manuscript/Fig2_demographic_rates.pdf){ width=160mm }

**Figure 2. Size-dependent survival and growth rates for *Acropora palmata*.**

![](06_analysis/figures/manuscript/Fig3_caribbean_synthesis.pdf){ width=160mm }

**Figure 3. Caribbean-wide annual-survival synthesis for *Acropora palmata*.**

![](06_analysis/figures/manuscript/Fig4_population_model.pdf){ width=160mm }

**Figure 4. Conditional recruitment-free transition dynamics for *Acropora palmata*.**

```{=latex}
\clearpage
```

## References {#refs}
