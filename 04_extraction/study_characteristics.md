# PRISMA Characteristics of Studies

**Project:** Size-Dependent Demography of *Acropora palmata* -- Systematic Data Compilation
**Authors:** Raine Detmer, Adrian Stier
**Affiliation:** Ocean Recoveries Lab, UC Santa Barbara
**Date:** March 2026

---

## Overview of Studies Evaluated

Raine Detmer's original literature tracker (`coral_parameters_lit_review.xlsx`) documents **52 unique studies** evaluated across three parameter sheets: 38 studies assessed for survival data, 28 for growth data, and 5 for reproduction data, with substantial overlap across sheets. Many of these studies report on species other than *A. palmata* (e.g., *A. cervicornis*, *Orbicella faveolata*, *Diploria strigosa*, *Porites astreoides*) and were cataloged as comparative context or excluded at the species-level screen.

The expanded AI-assisted search (March 2026) screened an additional 80 PDFs and queried PubMed, Semantic Scholar, and NotebookLM, identifying 33 new candidate papers not in the original 52. An Elicit-based replication search across 125M+ papers confirmed search saturation: no new studies with extractable longitudinal *A. palmata* survival data were found beyond those already evaluated.

**Final disposition across both search phases:**

| Category | Count |
|----------|-------|
| Studies included in meta-analysis (survival) | 17 unique studies contributing 22 study-level effects (NOAA split into FL Keys/Curacao/Navassa; Vardi 2011 split into Jamaica/PR/Virgin Gorda; Garrison & Ward 2008 split into control/relocated; Neely et al. 2022 added April 2026 via direct data sharing) |
| Studies contributing growth data only | 2 additional (Schutter et al. 2023, Papke et al. 2021 -- growth/lab only) |
| Studies contributing fragmentation context | 3 additional (Lirman 2000, Fong & Lirman 1995, Highsmith et al. 1980) |
| Studies contributing short-term lab survival | 2 (Chamberland et al. 2015, Randall & Szmant 2009 -- also contribute other data) |
| Studies contributing reproduction/genetics context | 5 (Irwin et al. 2017, Baums et al. 2006, Japaud et al. 2015, Porto-Hannes et al. 2015, plus 1 additional reference) |
| Studies excluded -- wrong species | 6+ |
| Studies excluded -- cross-sectional/invalid proxy | 7+ |
| Studies excluded -- NOAA/USGS data overlap | 7+ |
| Studies excluded -- recruits/microfragments only | 4 |
| Studies excluded -- linear growth only | 3+ |
| Studies excluded -- no extractable demographic data | 6+ |
| Studies excluded -- settlement/recruitment only | 3+ |
| Studies excluded -- lab only (embryos/larvae) | 3+ |
| Studies removed after audit | 4 (Ramos et al. 2024, Muller et al. 2008, Sutherland et al. 2016, Roth et al. 2013) |

---

## Table 1: Characteristics of Included Studies

### 1A. Tier 1 -- Individual-Level Data (n = 7 studies)

These studies provide raw, individual-level data with colony identifiers, sizes at each census, and individual survival/growth outcomes.

| Study ID | Citation | Region | Pop. Type | Design | n (survival) | Outcome Extracted | Size Metric | Time Interval | Extractor | Key Caveats |
|----------|----------|--------|-----------|--------|--------------|-------------------|-------------|---------------|-----------|-------------|
| NOAA_survey | Southeast Fisheries Science Center (2025). NOAA NCEI Accession 0142175. | Florida Keys, Curacao, Navassa | Natural | Long-term demographic monitoring of tagged colonies, 2004--2024 | 4,025 | Survival, growth, fragmentation (via Vardi 2011 matrices) | L x W x %live = live planar area (cm^2) | Variable (selected ~annual intervals) | Detmer | Largest single study. Size = L x W x %live. Mortality = no tissue/skeleton gone. Sampling intervals vary from sub-annual to triennial (Navassa). Disturbance years from Vardi 2011 Fig. 4-2 (no info post-2011). |
| pausch_et_al_2018 | Pausch et al. (2018). *Mar Ecol Prog Ser* 592:1--12. NOAA InPort 26790. | Florida Keys | Restoration | Nursery-cultured fragments outplanted to forereef and patch reef; two experiments (size x genet, habitat x genet) | 789 | Survival, growth | L x W x %live = live planar area (cm^2) | ~1 year (assumed; dead fragments not in subsequent data) | Detmer | Survival rates matched publication only if dead fragments assumed absent from subsequent years. Two experimental designs with different treatments. |
| kuffner_et_al_2020 | Kuffner et al. (2020). *Endang Species Res* 43:293--304. USGS Data Release. | Florida Keys (Dry Tortugas, Upper Keys, Biscayne Bay) | Restoration | Nursery-raised fragments outplanted spring 2018, monitored to fall 2019 | 106 | Survival, growth | Photo tracing of planar area (cm^2); initial sizes estimated from raw photographs | ~1 year (spring 2018 to spring 2019) | Detmer | Mortality defined as >=50% tissue loss (checked photos; all looked 100% dead). Initial sizes not in dataset -- estimated from photographs. |
| USGS_USVI_exp | USGS (unpublished). Coral growth VI USA. USGS CMGDS. | USVI | Restoration | Tagged outplanted colonies, June 2019 to July 2021 | 92 | Survival, growth | Photo tracing of planar footprint area (cm^2); initial sizes estimated from June 2019 photographs and growth rates | Two ~annual intervals (Jun 2019--Jun 2020; Jun 2020--Aug 2021) | Detmer | Initial colony size not in dataset -- estimated from raw photographs. Growth given as cm^2/day normalized to days between visits. Dead = no live tissue remaining. |
| fundemar_fragments | FUNDEMAR (unpublished). Shared directly. | Dominican Republic | Restoration | Nursery fragments on PVC tables at 6 localities; sub-fragmented and monitored with regular maintenance | 156 | Survival, growth | L x W (assumed rectangular) | Only Table 1 spans a full year; Tables 2--6 span 5 months only | Detmer | Direct data sharing from restoration practitioners. Tables 4 and 5 have tag/label mismatches between timepoints. Only Table 1 used for survival (full-year data). |
| mendoza_quiroz_2023 | Mendoza-Quiroz et al. (2023). *PeerJ* 11:e15813. | Mexican Caribbean | Mixed (nursery + field) | In situ nursery juveniles and outplanted adults on two reefs; growth tracked over months to years | 45 | Survival, growth | Diameter^2 (Cuevones reef, nursery) or L x W (Picudas reef) | ~1 year (Picudas: month/year only, assumed 1 yr) | Detmer | Size from diameter only at some sites (area = diameter^2, square assumption). Picudas reef longitude corrected (-87.85 to -86.85). Exact sampling dates only for nursery and Cuevones. |
| neely_et_al_2022 | Neely KL, Lewis CL, Lunz KS, Kabay L (2022). Frontiers in Marine Science 8:799187. Data shared directly. | Florida Keys (Lower Keys, Middle Keys, Biscayne NP, Dry Tortugas) | Natural | Long-term demographic monitoring of tagged colonies at 9 reef sites, 19 plots; 7 timepoints from Winter 2010/2011 to Fall 2016 | 878 | Survival, growth | LAI = live planar tissue area (cm^2) | 6 inter-census intervals (~5-14 months each, annualized) | Direct sharing (K. Neely) | Second-largest Tier 1 dataset. No NOAA overlap (verified: all sites in Lower/Middle Keys + Dry Tortugas; NOAA monitors Upper Keys only). Includes catastrophic 2014 disease event (53% survival TP4-TP5; disturbance-flagged). Published paper focuses on *Dendrogyra*; APAL data unpublished. See `04_extraction/neely_2022_data_integration.md`. |

### 1B. Tier 2 -- Summary-Level Data, Hand-Extracted (n = 8 studies, unchanged)

These studies provide summary-level data (proportion survived, sample size, mean size) extracted by Detmer from published tables, figures, or text.

| Study ID | Citation | Region | Pop. Type | Design | n | Outcome Extracted | Size Metric | Time Interval | Extractor | Key Caveats |
|----------|----------|--------|-----------|--------|---|-------------------|-------------|---------------|-----------|-------------|
| vardi_2011 (3 regions) | Vardi, T. (2011). PhD Dissertation, University of Miami. | Jamaica, Puerto Rico, Virgin Gorda | Natural | Tagged colony monitoring; transition matrices reported for 6 Caribbean regions | 245 total (88 Jamaica, 130 PR, 27 Virgin Gorda) | Survival (by size class), fragmentation rates | Live planar area (cm^2), Vardi's 4 size classes | Variable; interpolated/extrapolated to annual | Detmer | Florida, Curacao, Navassa data overlap with NOAA_survey (same colonies) -- excluded those 3 regions. Colony counts estimated from stacked bar plots (Fig. 4-2). Time intervals sometimes >1 or <1 year. Also contributes all fragmentation data used in the transition matrix. |
| bruckner_bruckner_2001 | Bruckner, A.W. & Bruckner, R.J. (2001). *Bull Mar Sci* 69:267--277. | Puerto Rico (Mona Island) | Restoration (storm-generated fragments) | Naturally occurring fragments from ship grounding, tracked over 2 years | 105 | Survival (by size class) | Fragment length (cm); converted to area estimates | 2 years (interpolated to annual) | Detmer | All sizes and proportions estimated from stacked histogram (Fig. 3). Largest size classes excluded due to few individuals. Time interval = 2 yr, annualized. |
| ortiz_prosper_2005 | Ortiz Prosper, A.L. (2005). PhD Dissertation, University of Puerto Rico, Mayaguez. | Puerto Rico | Restoration (storm-generated fragments) | Tracked individual storm fragments; built matrix model from two time periods | 207 | Survival (by size class), transition matrices | Live surface area (cm^2): L x W of live tissue | Two time periods; annualized | Detmer | Fragment sizes from Fig. 3.4 histogram. Min size class bounded by "fragments under 10 cm long were not observed" converted to cm^2. Two separate transition matrices for two time periods. |
| forrester_et_al_2013 | Forrester, G.E. et al. (2013). *Aquatic Conserv* 23:872--882. | British Virgin Islands | Restoration (storm-generated fragments) | Storm-generated fragments tracked over multiple years; model-predicted survival by size | 257 | Survival (by size class from tables) | Surface area of live tissue (photo tracing for small; [(L+W+H)/3]^2 for large branching) | ~annual | Detmer | Published survival is model-predicted (not raw counts by size). Tables 1 and 2 used instead (size ranges ~10--1000 cm^2 not broken down further). Growth from Fig. 5 scatterplot too imprecise to extract. |
| rosales_et_al_2024 | Rosales, S. et al. (2024). *Commun Earth Environ* 5:597. | Florida Keys | Restoration | Outplanted fragments from nursery; survival by reef and genet over 18 months | 58 | Survival (by reef/genet) | Fragment length (cm); converted to cm^2 from reported initial lengths | 18 months (interpolated to annual) | Detmer | GitHub repo has partial individual data but could not match survival to Table S3 (only 1/4 genotypes matched). Used Table S3 summary values instead. Survival interpolated from 18-month values. |
| maurer_et_al_2022 | Maurer, A.S. et al. (2022). *PLoS ONE* 17:e0267034. | Bahamas | Restoration | Fragments on line nurseries at two sites, monitored over 3 years | 24 | Survival (year 1 only) | All fragments cut to ~5 x 5 cm (= 25 cm^2); no individual sizes | 1 year (year 1 only; no size data for years 2--3) | Detmer | No individual size data; all assumed 25 cm^2. Only year 1 used because subsequent years lack initial sizes. Small n per site (12 each). |
| williams_miller_2010 | Williams, D.E. & Miller, M.W. (2010). *Restor Ecol* 18:652--661. | Florida Keys (Biscayne Bay) | Restoration | Naturally occurring fragments collected, transported to nearby patch reef; 3 attachment methods | 18 | Survival | Fragment length range (7--36 cm); converted to skeletal area range using fragment W:L ratios | 44 weeks (~0.85 yr; extrapolated to annual) | Detmer | Only size information is length range and % live tissue range. Small n = 18. Time interval <1 yr, extrapolated. Attachment method was experimental variable. |
| garrison_ward_2008 | Garrison, V.H. & Ward, G. (2008). *Biol Conserv* 141:2906--2916. | USVI | Natural (intact colonies) + Restoration (transplanted fragments) | Compared survival of control colonies and transplanted fragments; included economic cost analysis | 45 (*A. palmata* only; also studied *A. cervicornis*) | Survival (by colony type) | Longest diameter of living tissue (mean/SE); converted to cm^2 using colony W:L ratios | 1 year | Detmer | Proportion surviving estimated from Fig. 4b. Size in diameter only, converted. Study also reports *A. cervicornis* data (excluded). |

### 1C. Tier 2 -- Summary-Level Data, AI-Extracted (n = 3 studies)

These studies were identified and/or extracted during the March 2026 expanded search. All values tagged `[AI_EXTRACTED]` in study_notes. All underwent independent audit (see Data_Methodology_Reference.md Section 8). Two originally included AI-extracted studies (Muller et al. 2008, Sutherland et al. 2016) were removed after data audit and are now listed in the excluded tables. Roth et al. 2013 (hand-extracted) was removed after an exhaustive overlap audit confirmed it uses the same Haulover Bay colony data as Rogers & Muller 2012. Rogers et al. 1982 was reclassified from excluded ("fragment survival only") to included after re-evaluation.

| Study ID | Citation | Region | Pop. Type | Design | n | Outcome Extracted | Size Metric | Time Interval | Extractor | Audit Result | Key Caveats |
|----------|----------|--------|-----------|--------|---|-------------------|-------------|---------------|-----------|--------------|-------------|
| rogers_muller_2012 | Rogers, C.S. & Muller, E.M. (2012). *Dis Aquat Org* 98:1--8. | USVI (Haulover Bay, St. John) | Natural | Tagged colony monitoring at USGS/NPS site, 2003--2009 | 69 | Survival (44/69 survived 7 yr) | Volume (cm^3) -- not convertible to area; set to NA | 7 years (annualized) | AI (Claude) | PASS | Size in volume, not area -- entered as NA. Independence from Muller et al. 2008 confirmed (different bay, 4 km apart). Fig. 7 mortality year-by-year not used (read error caught in audit). |
| ramos_romero_et_al_2025 | Ramos-Romero, S. et al. (2025). *Restor Ecol* (in press/2025). | Cuba (4 restoration sites) | Restoration | Kaplan-Meier survival of outplanted fragments at 4 sites | 200 | Survival (KM estimates from Table 2) | Not specified; set to NA | 423--453 days per site (annualized) | AI (Claude) | PASS after corrections | Time intervals initially extracted as time-of-last-KM-event (232--347 d); corrected to full monitoring duration (423--453 d). Study-level survival changed from 61.0% to 70.5% after correction. |
| rogers_et_al_1982 | Rogers, C.S. et al. (1982). *Science* 216:749--751. | USVI (St. Croix, 2 sites) | Natural | 173 individually labeled branches tracked ~11 months post-Hurricane David (1979) at Tague Bay and Butler Bay | 173 | Survival (branch-level, post-hurricane) | Branch-level; size classes not specified | ~11 months (annualized) | AI (Claude) | PASS | Reclassified from excluded ("fragment survival only, non-annual") after re-evaluation. Provides extractable annual survival data for 173 labeled branches across 2 St. Croix reef sites. Post-hurricane monitoring context. |

### 1D. Additional Data Contributions (not in survival meta-analysis)

These studies contribute data to other parts of the pipeline (growth, fragmentation, short-term lab survival) but are not independent entries in the survival meta-analysis.

| Study ID | Citation | Contribution | Outcome Extracted | Notes |
|----------|----------|-------------|-------------------|-------|
| vardi_et_al_2012 | Vardi, T. et al. (2012). *Coral Reefs* 31:795--812. | Published version of Vardi 2011 Florida Keys data | Transition matrices (survival, growth, fragmentation) for Florida Keys | Florida Keys data overlaps with NOAA_survey; not independently counted. Vardi 2011 dissertation used for non-Florida regions. |
| forrester_et_al_2011 | Forrester, G.E. et al. (2011). *Restor Ecol* 19:111--119. | Summary survival data from BVI fragment relocation experiment | Survival by relocation treatment | Enters pipeline through summary survival data combined with Forrester et al. 2013 under the `forrester_et_al_2013` study ID in the meta-analysis (both are BVI storm-fragment studies from the same research group). 4 treatments across 2 years. Growth reported as % change in LAI but initial sizes span too wide a range (~10 to >900 cm^2) to estimate absolute growth. |
| schutter_et_al_2023 | Schutter, M. et al. (2023). *Coral Reefs* 42:537--551. | Growth data for recruits in lab and outplanted nursery | Growth (lab and outplanted recruit sizes over time) | Survival reported per plug (not per individual recruit) so survival data not extractable. Growth estimated from size differences between timepoints. |
| papke_et_al_2021 | Papke, E. et al. (2021). *Front Mar Sci* 8:623963. | Growth data for lab microfragments | Growth (cm^2/day in lab over 193 days) | Microfragments (~0.57 cm^2) in lab; survival was 100% so no variance. Excluded from survival meta due to microfragment + lab conditions. Growth data extrapolated to annual. |
| chamberland_et_al_2015 | Chamberland, V.F. et al. (2015). *Coral Reefs* 34:1229--1240. | Summary survival/growth for recruits (lab vs reef); short-term lab survival | Short-term settler survival (1 month), long-term recruit survival (11 months), growth over 30 months | New settlers; excluded from survival meta as post-settlement recruits (<1 cm^2). Contributes to short-term lab survival dataset and summary growth dataset. |
| randall_szmant_2009 | Randall, C.J. & Szmant, A.M. (2009). *Biol Bull* 217:269--282. | Short-term lab settler survival | Settler survival over 4 days (88--100%) | Lab experiment on temperature effects on settlement and post-settlement survival. Contributes to short-term lab parameterization only. |
| fundemar_recruits | FUNDEMAR (unpublished). Shared directly. | Summary survival/growth for outplanted recruits | Recruit survival at 12 months; growth from size changes between timepoints | Excluded from survival meta as post-settlement recruits. Cases where recruits appeared after outplanting were removed. Youngest recruits with sizes were 5 months old. |
| lirman_2000 | Lirman, D. (2000). *J Exp Mar Biol Ecol* 251:91--110. | Fragmentation context | Fragment survival, growth rates, size-survival relationships (fragments and adults) | Found no significant relationship between fragment size and survivorship (small sample). Adult colonies: 100% survival over 4 yr. Fragment growth: 1.7--6.5 cm/yr (exponential increase). Contributes to AI-extracted fragmentation context file. |
| fong_lirman_1995 | Fong, P. & Lirman, D. (1995). *Coral Reefs* 14:131--138. | Fragmentation context | Fragment cementation rates post-Hurricane Andrew | 72% of fragments cemented to bottom by 9 months. Found no difference in cementation with fragment size. Growth: 0--0.6 cm/month protobranch growth. Contributes to AI-extracted fragmentation context file. |

---

## Table 2: Characteristics of Excluded Studies

Studies are grouped by primary exclusion reason. Each study was evaluated against the inclusion criteria defined in Data_Methodology_Reference.md Sections 2--3.

### 2A. Wrong Species (not *Acropora palmata*)

These studies were cataloged in Raine's tracker because they report coral demographic data relevant to the broader project context, but they study species other than *A. palmata* and were appropriately excluded from the *A. palmata* meta-analysis.

| Study ID | Citation | Species Studied | What It Reports | Why Excluded |
|----------|----------|----------------|-----------------|--------------|
| Edmunds 2010 | Edmunds, P.J. (2010). *Mar Ecol Prog Ser* 419:139--151. | *Diploria strigosa*, *Porites astreoides* | Size-dependent survival and growth with transition matrices; 5--8 yr monitoring in USVI | Wrong species. Reports *Diploria* and *Porites* demography. No *A. palmata* data. |
| Steinberg 2021 | Steinberg, R. (2021). Dissertation/thesis. | *Orbicella faveolata*, *Diploria labyrinthiformis*, *Siderastrea siderea*, *Pseudodiploria clivosa* | Survival and growth of microfragments in land-based and offshore nurseries in Florida | Wrong species. Reports 4 massive coral species, none *A. palmata*. |
| Page et al. 2018 | Page, C.A. et al. (2018). *Coral Reefs* 37:1167--1179. | *Orbicella faveolata*, *Montastraea cavernosa* | Size-dependent survival and growth of fragments at nearshore vs. offshore sites | Wrong species. Reports *O. faveolata* and *M. cavernosa*. No *A. palmata*. |
| Ladd et al. 2024 | Ladd, M.C. et al. (2024). | *Diploria labyrinthiformis* | Demographic data for brain coral in Florida | Wrong species. Not *A. palmata*. Incomplete entry in tracker. |
| Marhaver et al. 2013 | Marhaver, K.L. et al. (2013). *PNAS* 110:9188--9193. | *Orbicella faveolata* | Settler survival over 6 days; effects of distance from adult colonies | Wrong species. *O. faveolata* settlers in Curacao. |
| Vermeij & Sandin 2008 | Vermeij, M.J.A. & Sandin, S.A. (2008). *Oecologia* 156:519--526. | *Siderastrea radians* | Settler survival over 3 months in Florida Keys | Wrong species. *S. radians* settlement study. |
| Bythell et al. 1993 | Bythell, J.C. et al. (1993). *Mar Ecol Prog Ser* 98:11--17. | *Diploria strigosa* (survival data in tracker) | Size-dependent survival over 26 months in USVI; hurricane mortality | Wrong species for the entries in the tracker (*Diploria*). Note: the paper may also discuss *M. annularis* chronic mortality, which was excluded separately. |
| Garrison & Ward 2008 (*A. cervicornis* component) | Garrison, V.H. & Ward, G. (2008). *Biol Conserv* 141:2906--2916. | *Acropora cervicornis* | Survival of *A. cervicornis* colonies and fragments in USVI | Wrong species. The *A. palmata* component of this study IS included; the *A. cervicornis* rows were excluded. |
| Becker & Mueller 2001 (*A. cervicornis* component) | Becker, L.C. & Mueller, E. (2001). *Bull Mar Sci* 68:163--170. | *Acropora cervicornis* (fragments in lab and field) | Fragment survival and growth in aquarium and reef settings | Wrong species for *A. cervicornis* entries. The study also reports *A. palmata* fragment growth (see fragmentation context section), but the *A. cervicornis* survival data are excluded. |
| Ladd et al. 2016 | Ladd, M.C. et al. (2016). *Bull Mar Sci* 92:1--13. | *Acropora cervicornis* | Fragment survival and growth by density treatment in Florida Keys | Wrong species. *A. cervicornis* restoration study. |
| Griffin et al. 2015 | Griffin, S.P. et al. (2015). *Bull Mar Sci* 91:271--282. | *Acropora cervicornis* | Fragment survival and growth over 3 months in USVI | Wrong species. *A. cervicornis* fragment experiment. |
| Knowlton et al. 1981 | Knowlton, N. et al. (1981). *Nature* 294:251--252. | *Acropora cervicornis* | Fragment survival over 5 months post-hurricane in Jamaica | Wrong species. *A. cervicornis* post-hurricane fragment dynamics. Near-zero survival. |

### 2B. Linear Growth Only (no areal growth or survival)

These studies report *A. palmata* growth exclusively as linear extension (mm/yr or cm/yr) of branches, which cannot be converted to areal growth (cm^2/yr) without additional morphological assumptions. They do not report survival.

| Study ID | Citation | What It Reports | Why Excluded |
|----------|----------|-----------------|--------------|
| Crabbe 2009 | Crabbe, M.J.C. (2009). *Mar Environ Res* 67:189--192. | *A. palmata* linear extension rate: 71.0 mm/yr (range 50--90) in Jamaica | Reports only linear extension of branches. Not convertible to areal growth. No survival data. |
| Crabbe 2010 | Crabbe, M.J.C. (2010). *J Environ Monit* 12:170--176. | *A. palmata* linear extension rate: 65.0 mm/yr in Jamaica | Same as above; linear extension only. |
| Crabbe 2013 | Crabbe, M.J.C. (2013). *SpringerPlus* 2:153. | *A. palmata* linear extension rate: 62.5 mm/yr (range 50--90) in Jamaica | Same as above; linear extension only. |
| Gladfelter et al. 1978 | Gladfelter, E.H. et al. (1978). *Ann Mtg Assoc Island Mar Labs Caribb* 13:12. | *A. palmata* linear extension rate: 47--99 mm/yr across USVI locations | Reports only linear extension. No survival. Range of location-specific means available. |
| Bak et al. 2009 | Bak, R.P.M. et al. (2009). *Bull Mar Sci* 84:221--231. | *A. palmata* linear extension: 6.2--8.1 mm/month in Curacao | Monthly linear extension rates. No areal growth. No survival. |

### 2C. Cross-Sectional Design / Invalid Survival Proxy

These studies report colony condition at a single time point or use partial mortality metrics that do not constitute longitudinal whole-colony survival tracking.

| Study ID | Citation | What It Reports | Why Excluded |
|----------|----------|-----------------|--------------|
| Ramos et al. 2024 | Ramos, J. et al. (2024). *Coral Reefs* 43:927--939. | Recent mortality (RM) prevalence at sites in Jardines de la Reina and Parque Baconao, Cuba | **Initially included, then removed after audit.** RM prevalence measures the fraction of colonies showing ANY recent tissue loss -- a partial mortality metric, not whole-colony death. A colony with RM is still alive. The study's own density data (89% decline at one site) contradicts the 92% "survival" derived from RM proxy. The n = 246 was fictional (density x area estimate, not a tracked cohort). |
| Gonzalez-Diaz et al. 2019 | Gonzalez-Diaz, P. et al. (2019). | Partial mortality prevalence for *A. palmata* in Cuba | Cross-sectional survey of colony condition. Partial tissue loss prevalence is not whole-colony mortality. No individual tracking over time. |
| Garcia-Uruena 2020 | Garcia-Uruena, R.P. (2020). | Transplant/regeneration study, Colombia | Cross-sectional assessment. No longitudinal tracking of individual colonies. |
| Caballero-Aragon et al. 2019 | Caballero-Aragon, H. et al. (2019). | Colony condition assessment, likely Cuba/Caribbean | Cross-sectional survey. Partial mortality metrics, not whole-colony survival over defined intervals. |
| Zubillaga et al. 2008 | Zubillaga, A.L. et al. (2008). | *A. palmata* population assessment, Venezuela | Cross-sectional. AI-extracted data shows colony condition snapshots, not longitudinal survival. Appears in AI triage results as excluded. |
| Croquer 2016 | Croquer, A. et al. (2016). | Disease/mortality assessment in Caribbean | Cross-sectional colony condition survey. Reports prevalence of disease or tissue loss, not tracked cohort survival. |
| Rogers 2006 | Rogers, C.S. et al. (2006). | *A. palmata* monitoring in USVI | Reports colony counts/condition at census points. Uncertain whether individual tracking was performed; excluded pending verification. |

### 2D. NOAA/USGS Data Overlap

These studies analyze data from the same monitoring programs or tagged colonies already included in the meta-analysis under a different study ID. Including them would double-count the same individuals.

| Study ID | Citation | What It Reports | Overlap With | Why Excluded |
|----------|----------|-----------------|-------------|--------------|
| Williams & Miller 2012 | Williams, D.E. & Miller, M.W. (2012). *PLoS ONE* 7:e38906. | *A. palmata* demographic analysis, Florida Keys | NOAA_survey | Analyzes a subset of the NOAA Acropora Demographic Monitoring Program data, which is included as NOAA_survey (full dataset). |
| Bright 2013 | Bright, A.J. et al. (2013). | *A. palmata* monitoring analysis, Florida | NOAA_survey | Another analysis of NOAA SEFSC monitoring data, same tagged colony program. |
| Muller 2014 / Miller 2009 | Muller, E.M. et al. (2014) / Miller, M.W. et al. (2009). | *A. palmata* disease or monitoring in Florida Keys | NOAA_survey | Publications analyzing NOAA monitoring data subsets. Same colony sets. |
| Neely et al. 2022 | Neely, K.L. et al. (2022). | 878 *A. palmata* colonies at 9 Florida Keys sites (Lower Keys, Middle Keys, Biscayne NP, Dry Tortugas) | No NOAA overlap | **No geographic overlap** with NOAA monitoring (see `03_screening/overlap_analysis.md` Section 2.5 for site-by-site verification). All 22 NOAA FL Keys plots are in the Upper Keys; Neely's sites are in entirely non-overlapping sub-regions. **Now INCLUDED (April 2026):** raw colony-level data shared directly by K. Neely. See Table 1A and `04_extraction/neely_2022_data_integration.md`. |
| Sutherland et al. 2016 (both components) | Sutherland, K.P. et al. (2016). *PLoS Pathog* 12:e1005904. | FKNMS contemporary monitoring (2008--2014), Carysfort and Molasses reefs; EDR historical (1994--2004), 92 colonies | NOAA_survey (FKNMS); photostation design (EDR) | **Both components excluded.** FKNMS excluded for spatial overlap at Carysfort and Molasses with NOAA monitoring. EDR excluded during IRR audit because the monitoring used permanent photostations/quadrats rather than individually tagged colonies. |
| Chapron et al. 2023 | Chapron, L. et al. (2023). | Follow-up monitoring of outplanted *A. palmata* | kuffner_et_al_2020 | Explicitly sampled "the surviving corals from Kuffner et al." -- same individuals. Only Kuffner included. |
| Chen et al. 2020 | Chen, T. et al. (2020). | Spatio-temporal dynamics of *A. palmata* in USVI | Vardi 2011 / NOAA_survey | Uses Bayesian estimation with strong beta priors based on Vardi et al. 2012 data. Same size classes and sites. NOAA reef-level data, not independent tracking. |
| Vardi 2011 (FL, Curacao, Navassa regions) | Vardi, T. (2011). PhD Dissertation. | Transition matrices for FL, Curacao, Navassa | NOAA_survey | Vardi surveyed the same sites and colonies as the NOAA dataset for these 3 regions. Only the Jamaica, Puerto Rico, and Virgin Gorda data from Vardi 2011 are included as independent. |
| Roth et al. 2013 | Roth, L. et al. (2013). *Ecol Modelling* 269:98--109. | Tagged colony monitoring and matrix model parameterization at Haulover Bay, USVI; 27 colonies averaged across 5 survey years | Rogers & Muller 2012 | **Removed during overlap audit.** Roth et al. 2013 explicitly cites Rogers & Muller 2012 and acknowledges the same USGS/NPS Haulover Bay monitoring program. The colony dataset (Haulover Bay, St. John, ~2003--2010) is the same as Rogers & Muller 2012 (Haulover Bay, 69 colonies, 2003--2009). Including both would double-count individuals. Rogers & Muller 2012 retained as the primary source. |

### 2E. Recruits, Settlers, and Microfragments Only

These studies track post-settlement recruits (<1 cm^2) or lab-cultivated microfragments under conditions not comparable to juvenile/adult field demography. Their near-zero survival rates and artificial conditions make them inappropriate for the survival meta-analysis, though some contribute to growth or short-term lab datasets.

| Study ID | Citation | What It Reports | Why Excluded from Survival Meta |
|----------|----------|-----------------|-------------------------------|
| fundemar_recruits | FUNDEMAR (unpublished). | Outplanted recruit survival over 12 months; recruit sizes | Post-settlement recruits (<1 cm^2). Different life stage with near-zero survival. Contributes to summary growth data. |
| chamberland_et_al_2015 | Chamberland, V.F. et al. (2015). *Coral Reefs* 34:1229--1240. | Settler survival in lab (~81% at 1 month) and reef (~11% at 11 months) | New settlers (<1 cm^2). Contributes to short-term lab survival and summary growth datasets, but excluded from the main survival meta. |
| mendoza_quiroz_2023 (ex situ nursery component) | Mendoza-Quiroz et al. (2023). *PeerJ* 11:e15813. | Ex situ nursery recruit survival: 1.2% (2011 cohort), 11% (2012 cohort) over 1 yr | New settlers in lab; near-zero survival under aquaculture conditions. The in situ nursery and field components ARE included. |
| papke_et_al_2021 | Papke, E. et al. (2021). *Front Mar Sci* 8:623963. | Microfragment growth on ceramic vs. cement substrate in lab; 100% survival over 193 days | Microfragments (~0.57 cm^2) in lab conditions. 100% survival = no variance. Contributes growth data only. |
| Schutter et al. 2023 (settler component) | Schutter, M. et al. (2023). *Coral Reefs* 42:537--551. | Settler survival on plugs in lab and after outplanting; recruit growth | Survival reported per plug (proportion with >=1 live recruit), not per individual. Cannot extract individual survival. Contributes to summary growth data only. |

### 2F. Settlement, Recruitment, and Larval Studies Only

These studies focus on pre-settlement or settlement processes without tracking subsequent colony survival or growth in a way usable for demographic parameterization.

| Study ID | Citation | What It Reports | Why Excluded |
|----------|----------|-----------------|--------------|
| Albright et al. 2010 | Albright, R. et al. (2010). *PNAS* 107:20400--20404. | Effects of ocean acidification on *A. palmata* settlement in lab; ~65% settlement in control; post-settlement growth ~1.5 micrometers/day | Settlement/recruitment study in lab. Growth measured in micrometers/day over 50 days post-settlement. Not applicable to field demographic parameterization. |
| Miller 2014 | Miller, M.W. (2014). *Bull Mar Sci* 90:991--1005. | Settler survival over 6--9 weeks (12--49%) in Florida Keys; polyp budding rates | Short-term settler experiment. Time intervals (6--9 weeks) too short for annualization. Different life stage. Also reports *O. faveolata* (excluded as wrong species). |
| Olsen et al. 2016 | Olsen, K. et al. (2016). | *A. palmata* larval survival over 48 hours in in situ chambers, Belize | Larval (pre-settlement) survival over 48 hours. Not colony survival. Lab/chamber conditions. |
| Ritson-Williams et al. 2010 | Ritson-Williams, R. et al. (2010). *PLoS ONE* 5:e9801. | Settler survival over 6 weeks (~15%) in Belize; CCA substrate preferences | Short-term settler survival in field. 6-week time interval; post-settlement recruits. Also reports *A. cervicornis* (excluded). |
| Erwin & Szmant 2010 | Erwin, P.M. & Szmant, A.M. (2010). *Coral Reefs* 29:597--607. | *A. palmata* settler survival after 12 and 36 days on tiles in Puerto Rico | Short-term settler experiment on porcelain tiles. 0--17% attachment depending on tile conditioning. Contributes to understanding settlement substrate preferences but not to demographic parameterization. |
| Randall & Szmant 2009 (settler component) | Randall, C.J. & Szmant, A.M. (2009). *Biol Bull* 217:269--282. | Embryo/larval survival (34--64% after 160 hours) and settler survival (88--100% after 4 days) | Pre-settlement larval survival and very short-term (4-day) post-settlement survival. Contributes to short-term lab survival dataset only. |

### 2G. No Extractable Demographic Data

These studies report on *A. palmata* but focus on genetics, physiology, spawning, disease etiology, or population trends without reporting individual-level survival or growth data extractable for demographic parameterization.

| Study ID | Citation | What It Reports | Why Excluded |
|----------|----------|-----------------|--------------|
| Williams et al. 2017 | Williams, D.E. et al. (2017). *Ecosphere* 8:e01863. | Population trends for *A. palmata* in Florida Keys; survival estimated at ~10--70% over 2 yr from figures; 3 bleaching events | Survival estimates available from figures but no individual-level data and no size-specific survival. Average colony size trends reported but not individual tracking. Could potentially be extracted but population-level trends overlap with NOAA dataset. |
| Irwin et al. 2017 | Irwin, A. et al. (2017). | Genetic data suggesting high clonality in Belize *A. palmata*; recruitment primarily through fragmentation | Genetics/clonality study. No survival or growth data. Relevant to understanding fragmentation-driven recruitment. |
| Baums et al. 2006 | Baums, I.B. et al. (2006). *Mol Ecol* 15:3735--3749. | Genetic structure of *A. palmata* across Caribbean; sexual recruitment more prevalent in eastern Caribbean | Population genetics. No demographic data. Contextual for understanding recruitment patterns. |
| Japaud et al. 2015 | Japaud, A. et al. (2015). | Genetic data for *A. palmata* and *A. cervicornis* in Guadeloupe; mostly asexual reproduction | Population genetics. No survival or growth data. |
| Porto-Hannes et al. 2015 | Porto-Hannes, I. et al. (2015). | Genetic diversity and clonality of *A. palmata* across Caribbean | Population genetics. No demographic data. Found high genetic diversity and low clonality. |
| Pinon-Gonzalez & Banaszak 2018 | Pinon-Gonzalez, H. & Banaszak, A.T. (2018). | Surface growth rates of colony branches in Mexican Caribbean (0.01--0.7 cm^2/day); colonies 80--100 cm diameter | Reports growth as branch surface growth rates. Colonies measured cross-sectionally. No survival data. Growth metric (branch surface rates) not directly convertible to whole-colony areal growth. |

### 2H. Fragment Dynamics Studies (contextual, not in survival meta)

These studies report on fragment fate, cementation, or fragmentation processes. They provide context for the fragmentation submodel but do not contribute to the survival meta-analysis because they either lack size-specific survival over defined intervals, or their data are used only in the fragmentation context files.

| Study ID | Citation | What It Reports | Why Not in Survival Meta |
|----------|----------|-----------------|-------------------------|
| Lirman 2000 | Lirman, D. (2000). *J Exp Mar Biol Ecol* 251:91--110. | Fragment survival (no size-dependent relationship found), adult survival (100% over 4 yr), fragment growth (1.7--6.5 cm/yr) in Florida | Found no significant size-survival relationship for fragments (small n). Adult survival = 100% (no variance, no mortality). Fragment growth is linear extension. Contributes to AI-extracted fragmentation context. |
| Fong & Lirman 1995 | Fong, P. & Lirman, D. (1995). *Coral Reefs* 14:131--138. | Fragment cementation rates (72% recruited to substrate by 9 months post-Hurricane Andrew); no size-dependent cementation | Reports fragment "recruitment" (cementation to substrate), not colony survival. Fragment growth in cm/month for protobranches. Size-independent cementation. Contributes to fragmentation context. |
| Lirman & Fong 1997 | Lirman, D. & Fong, P. (1997). *Coral Reefs* 16:223--229. | Fragment survival in Florida; no evidence for size-dependent survival above 5 cm threshold | Fragment survival study but found no size-dependent relationship. Most fragments 5--20 cm. No specific size-class survival rates extractable. |
| Williams et al. 2008 | Williams, D.E. et al. (2008). *Proc 11th Int Coral Reef Symp* 1:640--643. | Storm-generated fragment cementation (~5% of 2005 hurricane fragments recruited to substrate); very low sexual recruitment in 2,250 m^2 monitored area | Reports fragment "recruitment" (cementation), not survival per se. Very low success rate. Also reports near-zero sexual recruitment. Not individual-level survival tracking. |
| Highsmith et al. 1980 | Highsmith, R.C. et al. (1980). *Science* 207:1096--1098. | Fragmentation as a reproductive mechanism in branching corals | Classic fragmentation ecology paper. Context for fragmentation biology. No size-specific survival rates. Contributes to AI-extracted fragmentation context file. |

### 2I. Lab-Only Studies (embryo/larval survival under experimental conditions)

| Study ID | Citation | What It Reports | Why Excluded |
|----------|----------|-----------------|--------------|
| Randall & Szmant 2009 (embryo/larval component) | Randall, C.J. & Szmant, A.M. (2009). *Biol Bull* 217:269--282. | Embryo/larval survival: 34% (2007) and 64% (2008) after 160 hours; decreased with increasing temperature | Pre-settlement embryo/larval survival under controlled lab conditions. Not applicable to field colony demography. Temperature effects on larvae only. |
| Becker & Mueller 2001 (*A. palmata* component) | Becker, L.C. & Mueller, E. (2001). *Bull Mar Sci* 68:163--170. | *A. palmata* fragment growth in open seawater tank and reef (Bahamas): 16.2 mm vertical + 84.4 mm basal in tank; 40.7 mm vert + 44.4 mm basal on reef over 10 months | Growth data from aquarium and reef, but growth reported as linear extension (mm), not areal. Small sample (2 donor colonies). *A. cervicornis* component also excluded (wrong species). |

### 2J. Expanded Search -- Additional Excluded Studies

These studies were identified during the March 2026 AI-assisted expanded search and excluded after full-text assessment.

| Study ID | Citation | Assessment | Why Excluded |
|----------|----------|-----------|--------------|
| Muller et al. 2008 | Muller, E.M. et al. (2008). *Dis Aquat Org* 81:65--75. | Tagged colony monitoring at USGS/NPS Hawksnest Bay, St. John, USVI, 2004--2006; 60 colonies | **Initially included (Tier 2 AI-extracted), then removed after data audit.** Imprecise survival counts (17% of 60 ~ 10 deaths, but exact count ambiguous from text). No colony size data reported. Monitoring period includes 2005 mass bleaching event, confounding survival estimates. Independent from Rogers & Muller 2012 (different bay, 4 km apart). |
| Sutherland et al. 2016 | Sutherland, K.P. et al. (2016). *PLoS Pathog* 12:e1005904. | Long-term monitoring during WPX epidemic at EDR site, Florida Keys, 1994--2004; 92 colonies | **Initially included (Tier 2 AI-extracted), then removed after data audit.** EDR historical dataset has potential spatial overlap with NOAA monitoring at nearby Florida Keys sites. Photostation design (fixed quadrats) not suited for individual-level colony tracking -- colonies enter/exit frames due to growth and framework collapse, biasing survival estimates. Extreme mortality event (WPX epidemic) further limits generalizability. |
| Banister et al. 2024 | Banister, R.B. et al. (2024). | Environmental predictors for *A. palmata* restoration survival | Uses NOAA monitoring sites; likely overlaps with NOAA_survey data. |
| Alvarado-Ceron et al. 2025 | Alvarado-Ceron, J.E. et al. (2025). | Genomic insights into *A. palmata* populations | Population genetics only. No demographic data. |
| Garcia-Uruena 1995/2016 | Garcia-Uruena, R.P. (1995/2016). | Regeneration and transplant study, Colombia | Cross-sectional assessment. Already assessed and excluded in original search. |

---

## Reconciliation Notes

### Study count reconciliation

Raine Detmer's tracking spreadsheet (`coral_parameters_lit_review.xlsx`) contains entries for **52 unique studies** across three sheets (survival: 38 rows of study-level entries, growth: 28 rows, reproduction: 5 rows, with overlap). This count is larger than the 17 studies (22 effects) that entered the final meta-analysis because the tracker served as a comprehensive catalog of all Caribbean coral demographic literature examined, including:

- Studies of other species (*A. cervicornis*, *Orbicella*, *Diploria*, *Porites*, *Siderastrea*, *Montastraea*, *Pseudodiploria*) documented for comparative context
- Settlement and recruitment studies that report pre-demographic-stage data
- Studies reporting only linear extension (not convertible to areal growth)
- Fragment dynamics studies contributing context rather than survival rates
- Studies whose data overlap with existing entries (especially the large NOAA monitoring program)

The expanded March 2026 search screened an additional ~33 candidate papers (from 80 PDFs + database searches), yielding 5 initial extractions and 3 removals after audit (Ramos et al. 2024: invalid survival proxy; Muller et al. 2008: imprecise survival, no sizes, bleaching-confounded; Sutherland et al. 2016: NOAA overlap + photostation design). Rogers et al. 1982 was reclassified from excluded to included. Roth et al. 2013 was subsequently removed after an exhaustive overlap audit confirmed it uses the same Haulover Bay colony data as Rogers & Muller 2012. Search saturation confirmed via Elicit replication across 298 papers. Final (March 2026): 16 studies, 21 effects (after NOAA regional split and Garrison & Ward 2008 treatment split). Subsequently updated to 17 studies, 22 effects after adding Neely et al. 2022 (April 2026, direct data sharing).

### Species exclusions in Raine's tracker

Six distinct non-*A. palmata* study entries in the tracker warrant explicit documentation:

1. **Crabbe 2009, 2010, 2013** -- These are *A. palmata* studies but report only linear extension rates (mm/yr). They were appropriately excluded because linear extension cannot be converted to areal growth (cm^2/yr) without branch-level morphological data that these studies do not provide.

2. **Edmunds 2010** -- Reports *Diploria strigosa* and *Porites astreoides* size-dependent survival and transition matrices in USVI. Valuable comparative data for massive corals but not *A. palmata*.

3. **Steinberg 2021** -- Reports *Orbicella faveolata*, *Diploria labyrinthiformis*, *Siderastrea siderea*, and *Pseudodiploria clivosa* microfragment survival and growth in Florida nurseries. Wrong species (4 massive coral species, no *A. palmata*).

4. **Page et al. 2018, Marhaver et al. 2013, Vermeij & Sandin 2008, Bythell et al. 1993** -- Various non-*A. palmata* species (*Orbicella*, *Montastraea*, *Siderastrea*, *Diploria*).

5. **Ladd et al. 2016, 2024; Griffin et al. 2015; Knowlton et al. 1981** -- *Acropora cervicornis* or *Diploria* studies.

These entries demonstrate that the literature search was broad enough to capture relevant coral demographic studies across species, with appropriate species-level filtering applied during the inclusion/exclusion assessment.

### Data tier summary for included studies

| Data Tier | Description | Studies | Total n (survival) |
|-----------|-------------|---------|---------------------|
| Tier 1: Individual-level | Raw data with colony IDs | 7 (NOAA, Neely, Pausch, Kuffner, USGS, Fundemar, Mendoza-Quiroz) | ~7,800 |
| Tier 2: Hand-extracted summary | Detmer reading tables/figures | 8 (Vardi 2011, Bruckner, Ortiz Prosper, Forrester 2013, Rosales, Maurer, Williams-Miller, Garrison-Ward) | ~961 |
| Tier 2: AI-extracted summary | Claude reading PDFs, audited | 3 (Rogers-Muller 2012, Ramos-Romero 2025, Rogers 1982; Muller 2008 & Sutherland 2016 removed after data audit) | ~442 |
| **Total** | | **17 unique studies, 22 study-level effects** | **~8,805** |

---

*Document prepared: March 2026*
*Ocean Recoveries Lab, UC Santa Barbara*
*Sources: coral_parameters_lit_review.xlsx, Detmer_APAL_meta_analysis_notes.docx, Data_Methodology_Reference.md, PRISMA_Systematic_Review_Protocol.md, standardized_data/README.md, expanded_meta_analysis_study_effects.csv*
