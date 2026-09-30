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

Corresponding author email: [insert corresponding-author email]
ORCID iDs: Adrian C. Stier [insert ORCID]; A. Raine Detmer [insert ORCID]; Jameal F. Samhouri [insert ORCID]; Darcy Bradley [insert ORCID]; Aldo Croquer [insert ORCID]; Rita I. Sellares-Blasco [insert ORCID]

## Abstract

Restoration of the endangered elkhorn coral *Acropora palmata* depends on demographic rates that vary with colony size, location, and disturbance history, yet those rates have not been synthesized in a form that identifies which size classes and transitions limit persistence. Here, we compiled longitudinal survival, growth, and fragmentation records from 18 studies across the Caribbean, standardized colony size to live planar area, and linked size-dependent vital rates to a five-class, recruitment-free transition matrix. Pooled annual survival was 78.7% (95% CI 70.4–85.1%), but heterogeneity was extreme (I² = 97.6%) and the 95% prediction interval spanned 37.4–95.8%. Survival rose with colony size, whereas relative growth changed most sharply near 37 cm². Partial mortality was pervasive: 39.4% of surviving colonies lost live tissue during an interval, and 9–17% of colonies in each non-recruit size class moved to a smaller class. The post-settlement subsystem had a deterministic population growth rate (λ) of 0.961 (bootstrap interval 0.816–1.010), and stasis of the largest colonies accounted for 58.9% of matrix elasticity. Survival of broadly defined restoration fragments (74.5%) did not differ statistically from that of natural colonies (85.4%), but survival ranged from 58.7% to 81.1% among restoration subtypes. Recurrence of Florida-scale heatwave mortality every 5–50 years reduced effective λ to 0.36–0.85. Recovery of *A. palmata* therefore depends less on the number of corals deployed than on keeping colonies alive and intact through the transitions that produce persistent large adults.

Keywords: Caribbean coral reefs; demographic synthesis; elkhorn coral; meta-analysis; population dynamics; restoration

## Introduction

Foundation species create the structure on which ecological communities depend, but their recovery requires more than replacing individuals that have been lost. For colonial organisms, the demographic consequences of loss depend on which colonies die, which survive after partial mortality, and which transitions move colonies toward or away from reproductive size. These processes are particularly consequential for Caribbean acroporids, whose regional declines have reduced both coral cover and the three-dimensional habitat that elkhorn coral once provided [@aronsonprecht2001; @gardner2003]. Restoration programs increasingly propagate and outplant *Acropora palmata*, but the demographic information used to choose target sizes, sites, and intervention schedules remains fragmented among studies and regions [@edmundsriegl2020]. The most widely used size-structured model for the species was parameterized from tagged colonies in the northern Florida Keys [@vardi2012], a single region whose rates may not transfer to the rest of the Caribbean.

Colony size is a central axis of coral demography [@hughes1984; @hughesjackson1985]. Small colonies may grow rapidly in proportional terms but are exposed to high mortality, whereas large colonies can persist, reproduce, and fragment [@highsmith1982; @lirman2000; @madin2014]. However, colonies do not move through size structure only by growing or dying. Storm damage, disease, predation, and tissue loss can reduce the live area of colonies that remain alive, producing shrinkage and retrogression rather than immediate whole-colony mortality [@lirman1997; @madin2020]. Partial mortality can also carry a reproductive cost: *A. palmata* colonies with unhealed lesions produced smaller eggs than apparently healthy colonies, and the lesions did not regenerate over a four-month season [@pinongonzalez2018]. A demographic analysis that treats all surviving colonies as stable therefore risks obscuring the processes that determine whether individuals eventually contribute to adult population structure.

The Caribbean setting adds a second complication: demographic records were collected across populations that experienced different histories of storms, disease, bleaching, and chronic environmental stress. These events are often treated as inconvenient variation to remove before estimating a baseline vital rate. Yet disturbance is part of the regime in which *A. palmata* populations persist or decline. The 2023 marine heatwave, which caused functional extinction of *A. palmata* in Florida, makes this point especially clear: older demographic records describe an earlier chronic regime, not an enduring environmental baseline [@manzello2025]. A useful synthesis must therefore separate the question of a counterfactual low-disturbance estimate from the question of how colonies actually performed within their observed disturbance histories.

Restoration introduces a third source of heterogeneity. Nursery outplants, colonies re-cemented after fragmentation, direct outplants, and naturally fragmented colonies differ in size, handling, environment, and likely mortality processes [@forrester2012; @ramosromero2025; @banister2024]. Treating these materials as one "restoration fragment" category can yield a pooled comparison that is statistically convenient but biologically ambiguous. This distinction matters because early survival bottlenecks and later outplant performance need not be governed by the same processes [@williams2008; @williams2023].

Here, we synthesized the available longitudinal demographic evidence for *A. palmata* across the Caribbean. We asked: (1) how do survival and growth vary with colony size; (2) how common are shrinkage and retrogression among surviving colonies; (3) how do disturbance histories and restoration subtypes change demographic interpretation; and (4) what do these vital rates imply for a recruitment-free post-settlement transition subsystem? We combined individual-level observations from seven studies with summary-level effects from eleven additional studies, standardized colony size to live planar area, and linked the resulting vital rates to a five-class transition model that updates the structure of Vardi et al. [-@vardi2012]. We expected size to structure both survival and growth, size--survival associations to differ among observed exposure categories, and large-adult persistence to exert disproportionate influence on conditional transition dynamics. Our goal was not to produce a universal Caribbean rate for a heterogeneous species, but to identify the patterns that are robust across the available evidence and the uncertainties that should bound restoration decisions.

## Materials and methods

### Literature search and study selection

We conducted a systematic compilation of published *A. palmata* demographic data. The original search was conducted from June through December 2025 and drew on four sources: repositories maintained by NOAA and the US Geological Survey, structured Google Scholar searches, backward and forward citation searching from focal demographic studies, and data shared by restoration practitioners. We then completed an expanded audit in March 2026 using PubMed, Web of Science, Semantic Scholar/Elicit, targeted citation searches, and the project literature library. Search terms combined *Acropora palmata* or elkhorn coral with survival, mortality, growth, recruitment, restoration, and long-term monitoring terms. Detailed search strings, screening logic, and study-level exclusions are retained with the project documentation.

We included studies that reported longitudinal observations of identified *A. palmata* colonies or fragments, survival or areal growth over a defined interval, and sufficient information to annualize survival or estimate a size-dependent vital rate. We excluded cross-sectional condition surveys, studies that reported only branch extension, laboratory micro-fragment experiments smaller than 1 cm², and overlapping analyses of the same tagged-colony datasets. Titles and abstracts were screened first, followed by full-text evaluation. A second reviewer independently evaluated a subset of expanded-search candidates; disagreements were adjudicated by a third review. Across all sources, we identified approximately 2,500 records, assessed 101 full texts or data repositories, and excluded 82 with documented reasons; the most common reasons were a different species, overlap with an included dataset, and cross-sectional designs.

The final dataset comprised 18 studies. Seven supplied individual colony records: NOAA long-term monitoring of tagged colonies in the Florida Keys, Curaçao, and Navassa; Neely et al. [-@neely2022]; Pausch et al. [-@pausch2018]; Kuffner et al. [-@kuffner2020]; a USGS outplant experiment in the US Virgin Islands; FUNDEMAR nursery fragments in the Dominican Republic; and Mendoza Quiroz et al. [-@mendozaquiroz2023]. Eleven supplied study-level summaries [@rogers1982; @bruckner2001; @ortizprosper2005; @garrison2008; @williamsmiller2010; @vardi2011; @rogersmuller2012; @forrester2013; @maurer2022; @rosales2024; @ramosromero2025]. Seventeen of these studies, contributing 22 study-region effects, entered the survival synthesis. Mendoza Quiroz et al. [-@mendozaquiroz2023] contributed only to the size-dependent and transition analyses (Online Resource 1, Table S1).

### Data extraction and standardization

We organized retained records into two tiers. Tier 1 studies supplied individual colony identifiers, repeated sizes, and survival fates; these records supported analyses of survival, growth, shrinkage, and size-class transitions. Tier 2 studies supplied study-level survival proportions, sample sizes, and where available mean colony size. The survival and growth files contained 7,842 and 6,318 raw interval records, respectively. The current meta-analysis uses an effective denominator of 8,607 after interval filtering and study-level aggregation; it is not an individual-observation count. The study landscape and size coverage are shown in Fig. 1.

We standardized colony size as live planar tissue area in cm². For records containing perpendicular dimensions and live-tissue proportion, we calculated area as length × width × proportion live tissue, following the convention used in previous *A. palmata* matrix models [@vardi2012]. For diameter-only records, we estimated area from a circular footprint. Where a study reported a single linear measure, we applied study-informed width-to-length ratios; records for which size could not be defensibly converted were retained for survival synthesis but not size-dependent analyses. We annualized non-annual survival as $S_{\mathrm{annual}} = S_{\mathrm{observed}}^{1/t}$, where $t$ is the monitoring interval in years. This transformation assumes a constant hazard within each interval and therefore does not represent seasonal mortality peaks. Mortality definitions also differed among studies, from loss of both tissue and skeleton in NOAA monitoring to loss of at least half of live tissue in Kuffner et al. [-@kuffner2020]. We retained each study's definition rather than imposing a common one, so part of the among-study variation reflects measurement rather than biology.

We assigned colonies to five size classes: SC1, 0–10 cm²; SC2, 10–100 cm²; SC3, 100–900 cm²; SC4, 900–4,000 cm²; and SC5, >4,000 cm². These boundaries retain the structure of the published *A. palmata* Lefkovitch model while separating recruits from small juveniles [@vardi2011]. Shrinkage was negative annual change in live tissue area among colonies that survived an interval. Retrogression was an observed transition from a larger to a smaller size class.

### Disturbance and restoration classification

We retained all intervals in primary analyses because observed storms, disease, bleaching, cold events, and chronic stressors comprise the demographic context experienced by the study populations. We then linked each interval to a curated Caribbean disturbance timeline. The timeline distinguished acute events used in baseline-exclusion sensitivity analyses from chronic or indirect pressures retained as contextual exposure. We independently rebuilt the interval-to-event linkage and summarized it as a study-window audit (Online Resource 1, Table S2). We fitted size-by-disturbance interaction models to natural-colony records, thereby avoiding the confounding of disturbance context with restoration material and handling history.

For restoration analyses, we used study metadata to classify records as natural fragments, nursery outplants, nursery outplants re-cemented after fragmentation, or outplanted colonies. This subtype analysis was an interpretive sensitivity analysis, not a causal comparison of interventions. It was designed to test whether the broad label "restoration fragment" concealed demographic differences among biologically distinct materials.

### Vital-rate, meta-analytic, and population analyses

We modeled annual survival as a function of log-transformed colony size using binomial generalized additive models and modeled relative growth rate with Gaussian generalized additive models. These main-figure curves are unadjusted descriptive GAMs; mixed-effect models accounting for study were used as diagnostics and sensitivity analyses rather than as the source of their displayed intervals. We used a pre-specified GAM threshold analysis [@detmer2025] to evaluate nonlinear functional form and identify supported inflection points. A threshold was reported only when the GAM outperformed a linear model by at least 2 AICc units, and was located from the derivatives of the fitted curve. We interpreted thresholds as data- and study-composition-dependent features rather than fixed biological boundaries. We assessed model diagnostics and study dependence with the pre-specified verification and leave-one-study-out procedures documented in the project repository.

For the expanded survival synthesis, we annualized interval-level survival using a constant-hazard transformation, $S_{\mathrm{annual}} = S_{\mathrm{observed}}^{1/t}$, before aggregating study-region effects. We transformed those annualized proportions to proportional log-odds effect sizes and applied a 0.5 continuity correction to zero cells. The primary random-effects model was a three-level REML model with study and within-study effect structure and *t*-based inference; an independent-effect model with Knapp–Hartung inference was a sensitivity analysis [@knapp2003; @viechtbauer2010]. We report pooled survival, 95% confidence intervals, prediction intervals, and heterogeneity statistics. We evaluated population type, colony size, year, and region as exploratory moderators because the number of effects was limited. We also performed leave-one-out, classification, and risk-of-bias sensitivity analyses. We assessed small-study effects with Egger-type regression tests on the independent-effect and three-level models and with trim-and-fill on the independent-effect model. Funnel-plot methods were designed for comparative effect sizes, so we treat these tests as diagnostics of asymmetry among single-proportion effects rather than as direct tests of publication bias.

We constructed a five-class, recruitment-free Lefkovitch transition matrix from the prepared natural-colony transition data. The dominant eigenvalue (lambda) represented conditional annual growth of the observed post-settlement transition subsystem, not a full population forecast. Matrix support was uneven: five studies contributed survival, three contributed growth, SC5 survival was predominantly supported by NOAA records, and fragmentation was represented only by Vardi [-@vardi2011]. We quantified the elasticity of lambda to stasis, growth, retrogression, and fragmentation transitions, and propagated sampling uncertainty through hierarchical bootstrap resampling: studies were resampled first, then observations within sampled studies. We used 2,000 valid bootstrap replicates and leave-one-study-out analyses to characterize dependence on the contributing datasets; 43 bootstrap replicates imputed at least one missing size-class survival value, and the resampling did not propagate survival–growth covariance.

We treated the 2023 Florida heatwave as an episodic, Florida-specific survival pulse rather than as a replacement for the chronic-regime matrix. We first used the *A. palmata* dose-response thresholds reported by Manzello et al. [@manzello2025] (ED50 = 7.8 degree-heating weeks [DHW], ED95 = 17.6 DHW) to define 8-, 12-, and 18-DHW sensitivity scenarios. We then added an observed-2023 Florida endpoint: 97.8--100% mortality, represented by a 0--2.2% heatwave-year survival multiplier. The deterministic projection used the midpoint of that range; because the published study reports bounds rather than a colony-level sampling distribution, Monte Carlo projections sampled uniformly across the reported range at each prescribed event. Heatwave pulses were applied after the annual matrix transition to all size classes, consistent with the reported absence of size refuge during the Florida event. We report the geometric mean of annual abundance ratios as effective lambda under recurrence intervals of 5, 10, 20, and 50 years, and the probability that total abundance fell below 10% of its initial value within 50 years (quasi-extinction). These intervals span frequent to rare recurrence and are sensitivity values, not estimates of future return periods. The scenarios are stress tests for a Florida-like event sequence, not estimates of a Caribbean-wide thermal mortality rate or full population viability.

### Reproducibility

All data processing, analysis, figures, and manuscript-facing tables are maintained in the accompanying public repository. The analysis workflow, canonical output inventory, claim-to-output crosswalk, and figure map identify the script and output underlying each main-text claim (Data availability statement below). A versioned archival release will be deposited upon acceptance.

## Results

### The available evidence is Caribbean-wide but unevenly distributed

The synthesis combined individual-level monitoring with study-level records across 13 Caribbean regions (Fig. 1). Coverage was geographically uneven: the Florida Keys supplied 6,222 observations, more than all other regions combined, whereas several non-Florida regions contributed data from only a subset of size classes. Large adults outside Florida, Curaçao, and Navassa were particularly sparse. This imbalance matters because large colonies have the greatest demographic leverage in the projection model, while the regional settings in which they are best represented do not encompass the full Caribbean range.

### Survival and growth were nonlinear functions of colony size

Survival increased with colony size, from roughly 60% below 10 cm² to above 90% beyond 4,000 cm², although size explained less than 10% of the deviance in individual fate (Fig. 2a). The survival GAM outperformed a linear model (ΔAICc = 17.9) and identified a high-size inflection near 7,498 cm², but leave-one-study-out estimates were broad, indicating that the exact location of this threshold was not stable across the study mix. Relative growth rate showed a sharper early ontogenetic transition: the estimated inflection occurred near 37 cm², while the probability of positive growth crossed its threshold near 411 cm² (Online Resource 1, Fig. S1). Relative growth captured size dependence more effectively than absolute growth rate, whose variance increased strongly with colony size.

Study-level survival estimates by size class showed that the size effect was concentrated in the largest classes (Fig. 2c). Pooled survival was nearly flat from SC1 to SC3 (77.3%, 75.1%, and 76.6%) and then rose to 90.9% in SC4 and 94.7% in SC5, where every study estimate exceeded 82%. Among-study spread was widest in SC1–SC3, where individual estimates ranged from about 40% to 100% and where study context, disturbance history, and population type varied most strongly. Size therefore structured demographic performance, but it did not supply a region- or disturbance-independent prediction of fate.

### Caribbean-wide survival was heterogeneous

The expanded synthesis estimated pooled annual survival at 78.7% (95% CI: 70.4--85.1%; 95% prediction interval: 37.4--95.8%) across 17 studies and 22 study-region effects (Fig. 3a). Tier 1 and Tier 2 effects were both annualized before aggregation. Heterogeneity was high (I² = 97.6%; τ² = 0.72, of which 0.29 was between studies and 0.44 within studies), so the pooled value summarizes the assembled evidence rather than a Caribbean-wide constant. No single study moved the independent-effect estimate by more than 2.6 percentage points in leave-one-out analyses, and restricting the synthesis to the 13 studies with the highest methodological-quality scores changed it by less than 1 point. Evidence for small-study asymmetry was mixed: the Egger-type test was not significant for the independent-effect model (*p* = 0.55) but was significant for the three-level model (*p* = 0.001), and trim-and-fill imputed three effects and lowered the independent-effect estimate from 80.1% to 77.3%.

Natural-colony effects had higher pooled survival than restoration-fragment effects (85.4%, 95% CI 72.9–92.7%, *k* = 10, versus 74.5%, 63.9–82.9%, *k* = 12), but population type was not a supported moderator (*p* = 0.20). With 22 effects, the minimum detectable difference at 80% power was about 20 percentage points, so the analysis could not have reliably detected the observed 10.9-point difference. Regional variation remained substantial within population types (Fig. 3b). The overlap-zone comparison likewise showed that study identity and sampling context could not be separated cleanly from population origin (Online Resource 1, Fig. S2). These analyses do not support a single general survival penalty or benefit of restoration origin.

### Shrinkage and retrogression were common components of demographic performance

Colonies often survived while losing tissue. In the matrix-compatible growth dataset, 39.4% of records showed shrinkage (Online Resource 1, Fig. S3). Shrinkage frequency increased from 18.2% in SC1 to 47.5% in SC5, demonstrating that large colonies were not simply stable endpoints. Retrogression probabilities were 15.2% in SC2, 16.8% in SC3, 17.2% in SC4, and 9.1% in SC5. Thus, large colonies persisted more reliably than small colonies, but partial mortality still moved a measurable fraction of survivors backward through the size structure.

### Size--survival associations differed among exposure categories

The study-window audit covered 1,072 demographic intervals, 95.1% of which overlapped at least one curated disturbance or chronic-pressure record (Online Resource 1, Table S2). Only 353 of 6,141 natural-colony survival records came from intervals with no curated disturbance, and 193 of those were SC5 colonies. The survival relationship with colony size differed among intervals with no curated disturbance, context-only pressure, and acute baseline-exclusion exposure (likelihood-ratio test, *p* < 0.001; Online Resource 1, Fig. S4), but not in the direction a simple disturbance penalty would predict. Large colonies survived better in intervals flagged for acute events (SC5: 98.0%, *n* = 409; SC4: 90.4%, *n* = 250) than in intervals with no curated event (SC5: 83.9%, *n* = 193; SC4: 79.1%, *n* = 91), whereas survival of SC2 and SC3 colonies differed by less than 6 percentage points among states. The size-by-exposure interaction for the probability of positive growth was weaker (*p* = 0.010). Excluding all acute baseline-exclusion intervals from the individual-level synthesis (six studies) changed its pooled survival from 75.9% to 75.6%, indicating that the pooled result was not driven by locally identified acute events. Disturbance exposure was instead pervasive across the monitored demographic regime.

### Restoration performance depended on subtype

The subtype-coded dataset contained 5,079 records from five studies (Online Resource 1, Fig. S5): 3,968 natural fragments from one study, 1,012 nursery outplants from two studies, 53 re-cemented nursery outplants from one study, and 46 direct outplants from one study. Natural fragments had weighted survival of 87.1%, compared with 58.7% for nursery outplants, 81.1% for nursery outplants re-cemented after fragmentation, and 65.2% for outplanted colonies. Excluding natural fragments reduced mean survival across subtype-coded records from 81.2% to 60.0%. These contrasts show why a broad restoration-fragment category is not an adequate biological description of the material represented in the synthesis; they are descriptive because the subtype groups are highly unbalanced.

### Large-adult persistence dominated conditional transition dynamics

The recruitment-free transition matrix estimated a deterministic lambda of 0.961 (95% bootstrap interval: 0.816–1.010; Fig. 4). In 94.3% of hierarchical-bootstrap replicates, lambda was below one. This resampling fraction characterizes uncertainty in the compiled transition rates; it is not a probability of real-world population decline. Stasis dominated the transition matrix, and SC5-to-SC5 stasis accounted for 58.9% of matrix-cell elasticity. Leave-one-study-out estimates of lambda ranged from 0.882 (excluding NOAA monitoring) to 0.993 (excluding Neely et al. [-@neely2022]), indicating substantial dependence on the three natural-colony transition datasets. Removing fragmentation altogether lowered lambda to 0.892, so asexual fragment production, estimated from a single study, contributed about 0.07 to the deterministic growth rate. Within this conditional, recruitment-free subsystem, persistence of large adults had more influence on lambda than marginal changes in any single early transition.

### Florida-scale heatwaves sharply reduced effective lambda

The thermal-event layer did not alter the chronic-regime matrix lambda; it estimated the conditional consequence of recurrent survival pulses. Under the observed 2023 Florida endpoint, effective lambda was 0.355, 0.576, 0.769, and 0.846 when a Florida-like event recurred every 5, 10, 20, and 50 years, respectively (Online Resource 1, Fig. S6). Every observed-endpoint scenario reached quasi-extinction within 50 years in all simulations. The baseline was already precarious: without heatwaves, the stochastic projections had an effective lambda of 0.933, lower than the deterministic 0.961 because the simulations drew from bootstrap-resampled matrices, and a 70.8% probability of quasi-extinction within 50 years. The 18-DHW dose-response sensitivity scenario was less severe than the observed endpoint because its fitted mortality was 95.5%, rather than the 97.8--100% mortality reported from the Florida Keys and Dry Tortugas. These results should not be extrapolated as a Caribbean-wide forecast: they show that recovery trajectories conditional on the compiled post-settlement matrix are highly vulnerable to recurrence of an event of the observed Florida magnitude.

## Discussion

Our synthesis shows that *A. palmata* demography is structured not only by whether colonies survive, but by how colony size, partial mortality, and disturbance determine the transitions that survivors make. Three conclusions follow. First, survival and growth change nonlinearly with size, with early growth transitions and large-adult persistence playing different demographic roles. Second, shrinkage and retrogression are common enough that a live/dead framing misses a central route by which colonies lose future reproductive and structural value. Third, the heterogeneity among studies is not a nuisance to average away: it defines the limits of any regional estimate and the conditions under which restoration comparisons can be interpreted.

Large colonies carried the greatest leverage for population growth because their stasis had the highest elasticity. This result is consistent with size-structured coral demography, in which large colonies combine higher survival, reproductive potential, and the capacity to produce fragments [@lirman2000; @vardi2012; @madin2025]. It also matches the earlier Florida matrix, in which stasis of the largest class had the highest elasticity [@vardi2012]. That matrix drew on the same northern Florida Keys monitoring that dominates our SC5 data, however, so the agreement is expected rather than independent confirmation. However, large colonies were not invulnerable. Tissue loss was frequent even in the largest class, and colonies in every non-recruit class sometimes retrogressed. The implication is not simply that restoration should make colonies larger. Rather, strategies should be evaluated by whether they keep colonies alive and prevent the backward transitions that erode the adult size structure.

The nonlinear growth pattern clarifies why size-based restoration targets cannot be inferred from a single average growth rate. Relative growth changed most rapidly at small sizes, while survival increased across a much larger size range. Those patterns create a demographic tradeoff: retaining corals through early size classes may yield large proportional gains, but maintaining existing adults can contribute more directly to persistence. The exact size thresholds should not be treated as universal biological cutoffs because they varied with the study composition and measurement context. Their value is instead diagnostic: they identify where marginal improvements in growth or survival could have the largest demographic consequences in the current evidence base.

Most intervals in the synthesis overlapped a documented event or chronic pressure, and the size--survival relationship differed among disturbance states. The direction of that difference is the more instructive result. Large colonies survived better in intervals flagged for acute events than in the few intervals with no curated event, which is the opposite of a disturbance penalty. We interpret this as evidence that exposure categories track study, site, and survey period at least as closely as they track realized disturbance intensity: the undisturbed category was small and drawn from a narrow set of studies and years. The disturbance layer therefore does not identify a causal effect of storms, disease, or heat, because the underlying studies were not designed as a common experiment and their event histories differed. The evidence supports a narrower conclusion: transition analyses should retain disturbance history as part of the context in which observed size-dependent rates were generated. The 2023 heatwave makes this boundary especially important. Our chronic-regime matrix is not a forecast under severe contemporary thermal stress; the separate Florida event-pulse scenarios show how quickly its conditional trajectories deteriorate when Florida-scale mortality recurs [@manzello2025].

The restoration comparison likewise requires a constrained interpretation. Natural-colony and broad restoration-fragment effects overlapped in the expanded meta-analysis, but the subtype decomposition showed marked variation among nursery outplants, re-cemented colonies, direct outplants, and natural fragments. These materials differ in handling, age, size, substrate, and exposure; the present data do not isolate any one of those mechanisms. However, the result does show that average restoration survival is not a transferable property of a generic fragment. This is an important distinction for programs that use benchmarks from related species or later life stages, such as the first-year survival targets developed for *Acropora cervicornis* [@schopmeyer2017]. A target that is realistic for established outplants may be inappropriate for the earliest steps of sexual propagation, when survival of settlers and recruits is typically far lower [@chamberland2015; @mendozaquiroz2023]. Monitoring windows compound the problem: 60% of coral restoration projects reported less than 18 months of monitoring [@bostromeinarsson2020], too short to observe the adult transitions that carried the most weight in our matrix.

Extreme heterogeneity is the central limitation and the central contribution of this synthesis. The prediction interval spanned most of the probability scale, mortality definitions and monitoring intervals varied among source studies, NOAA monitoring supplied 78% of the individual-level records, and the three-level model showed evidence of small-study asymmetry. Large adults outside a few regions remained poorly represented, even though they had the greatest elasticity. These limitations constrain the precision of absolute regional estimates and the generality of the projected lambda. However, they do not erase the recurring patterns: size dependence, frequent partial mortality, large-adult leverage, and the importance of disturbance and intervention context. By retaining study identity, reporting prediction intervals, and distinguishing material subtypes, the synthesis makes these limitations visible rather than embedding them in an apparently precise pooled rate.

The next empirical priority is therefore not another undifferentiated estimate of average survival. Three gaps limit inference most. (1) Survival and retrogression of large adults outside Florida: SC5 carried 60% of the aggregated survival elasticity but was supported mainly by NOAA monitoring, and excluding that one dataset lowered lambda from 0.961 to 0.882. (2) Early post-outplant survival for defined restoration materials, reported by subtype, size at outplanting, and time since outplanting, so that nursery outplants, re-cemented fragments, and sexual recruits are no longer pooled. (3) Fragmentation and sexual recruitment: fragment production rested on a single study yet contributed about 0.07 to lambda, and sexual recruitment was fixed at zero, so a full Caribbean population model still requires field estimates of both. Across all three, comparable measurements of live area, mortality definition, monitoring interval, colony origin, and disturbance exposure would allow future syntheses to separate biological variation from measurement variation.

Recovery of a foundation species depends on rebuilding the demographic pathways that create durable ecological structure. For *A. palmata*, that pathway cannot be represented by outplant counts or average survival alone. It is shaped by the size of colonies, the tissue they retain after disturbance, and the environmental and restoration contexts in which they move through the population. A transparent synthesis of those processes provides a defensible starting point for conditional transition analysis and for restoration strategies that seek persistent coral habitat rather than short-lived planting records.

## Acknowledgements

We thank the NOAA Southeast Fisheries Science Center, K. Neely, the US Geological Survey, and FUNDEMAR for sharing monitoring data, and the authors of the published studies whose summaries made this synthesis possible. [Authors to confirm the individuals and programs to acknowledge.]

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

## Online resources

**Online Resource 1 (ESM_1.pdf).** Concise supporting analyses for the *Acropora palmata* demographic synthesis: a table of contributing studies, the study-window disturbance audit, and six supplementary figures. Extended diagnostics and source outputs remain available in the public repository.

## Figure legends

```{=latex}
\footnotesize
```

**Fig. 1** Study landscape for the *Acropora palmata* demographic synthesis. (a) Study locations across the Caribbean. Circles identify individual-level (Tier 1) studies and triangles summary-level (Tier 2) studies; regions with both are shown with both symbols. Symbol area is proportional to the number of observations, and labels give regional totals. Locations are regional centroids. (b) Availability of individual-level observations by canonical size class and region; cell labels are sample sizes, and darker cells indicate more observations. Empty cells indicate no available observations. Size classes are SC1, 0–10 cm²; SC2, 10–100 cm²; SC3, 100–900 cm²; SC4, 900–4,000 cm²; and SC5, >4,000 cm².

**Fig. 2** Size-dependent demographic rates for *Acropora palmata*. (a) Annual survival probability as a function of live tissue area for natural colonies. The line and shaded band are an unadjusted binomial generalized additive model (GAM) and its 95% confidence interval; points are binned observed proportions. Upper and lower rugs identify survival and mortality observations, respectively. (b) Relative growth rate (yr$^{-1}$) for natural colonies. The line and band are the unadjusted Gaussian GAM estimate and 95% confidence interval; pale points are individual observations, gold points are binned medians, and the dashed vertical line and band show the supported threshold and its cluster-bootstrap interval. (c) Study-level annual survival by size class. Colour indicates population type, shape identifies data tier, and point area is proportional to sample size; diamonds and error bars are pooled estimates and 95% confidence intervals. *k* gives the number of contributing effects.

**Fig. 3** Caribbean-wide survival synthesis for *Acropora palmata*. (a) Random-effects annual-survival estimates from 17 studies contributing 22 effects. Points and horizontal lines are study estimates and 95% confidence intervals; point area is proportional to random-effects weight. Circles represent individual-level data and triangles summary-level data. Coloured diamonds are population-type pooled estimates, the dark diamond is the overall pooled estimate, the dashed line marks that estimate, and the shaded interval is its 95% prediction interval. (b) Regional study estimates and 95% confidence intervals. Colour identifies population type, point area is proportional to sample size, and dark diamonds identify regional pooled estimates where at least two effects were available. The dashed line marks overall pooled annual survival.

**Fig. 4** Conditional transition dynamics for *Acropora palmata*. (a) Five-class, recruitment-free Lefkovitch transition matrix. Cells give annual transition probabilities from size class at time *t* to size class at time *t* + 1; colour encodes probability. The SC5 column sums to more than one because it includes fragments produced by surviving colonies [@vardi2011]. (b) Elasticity decomposition by source size class. Stacked bars show stasis, growth, and retrogression; orange points show fragmentation elasticity, which is displayed separately because it is a component of retrogression rather than an additional transition class. (c) Distribution of lambda from 2,000 hierarchical-bootstrap replicates. Orange bars denote replicates with lambda < 1 and blue bars replicates with lambda at least 1; the distribution characterizes uncertainty in the compiled transition rates, not the probability of real-world decline. The dashed line is the deterministic estimate and the solid line marks replacement. (d) Leave-one-study-out lambda estimates. The dashed and dotted lines mark the full-data estimate and replacement, respectively; orange identifies exclusion of the NOAA survey.

```{=latex}
\normalsize
\clearpage
```

## Figures

![](06_analysis/figures/manuscript/Fig1_study_landscape.pdf){ width=160mm }

**Figure 1. Study landscape and size-class coverage for the *Acropora palmata* demographic synthesis.**

\clearpage


![](06_analysis/figures/manuscript/Fig2_demographic_rates.pdf){ width=160mm }

**Figure 2. Size-dependent survival and growth rates for *Acropora palmata*.**

\clearpage


![](06_analysis/figures/manuscript/Fig3_caribbean_synthesis.pdf){ width=160mm }

**Figure 3. Caribbean-wide annual-survival synthesis for *Acropora palmata*.**

\clearpage


![](06_analysis/figures/manuscript/Fig4_population_model.pdf){ width=160mm }

**Figure 4. Conditional recruitment-free transition dynamics for *Acropora palmata*.**

```{=latex}
\clearpage
```

## References {#refs}
