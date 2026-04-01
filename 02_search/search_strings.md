# PRISMA Search Replication

**Date:** 2026-03-26
**Searcher:** AI (Claude), supervised by Adrian Stier
**Purpose:** Replicate the 5 original search strings from Detmer (2025) in PubMed and Semantic Scholar to assess search completeness and identify any missed studies with extractable *A. palmata* demographic data.
**Method:** WebSearch queries targeting PubMed (`site:pubmed.ncbi.nlm.nih.gov`) and Semantic Scholar (`site:semanticscholar.org`). Because the `site:` operator returned limited results for some PubMed queries, supplementary broader searches were also run (e.g., `PubMed "Acropora palmata" survival mortality...`).

---

## Search Results Summary

All searches used the base query: `("Acropora palmata" OR "elkhorn coral")`

| Search # | Additional terms | PubMed hits (approx.) | Semantic Scholar hits (approx.) | New candidates |
|---|---|---|---|---|
| 1 | `(survival OR mortality OR "hazard rate" OR "mortality rate")` | ~10 | ~10 | 4 |
| 2 | `(growth OR "linear extension" OR calcification OR "skeletal density" OR "areal growth" OR "extension rate")` | ~8 | ~10 | 0 |
| 3 | `(settlement OR settlers OR recruit OR recruitment OR spat OR larval OR fecundity OR egg OR planula)` | ~10 | ~10 | 0 |
| 4 | `(outplant OR restoration OR nursery) AND (survival OR growth OR mortality)` | ~10 | ~10 | 2 |
| 5 | `("long-term" OR "time series" OR monitoring OR "population trend")` | ~6 | ~10 | 0 |

**Note on hit counts:** WebSearch returns a maximum of ~10 results per query. The numbers above reflect the results returned by the search engine, not a formal PubMed Advanced Search hit count. A formal replication would require running Boolean queries directly in PubMed's Advanced Search interface. The approximate hit counts here should be treated as lower bounds on the number of indexed results.

---

## Detailed Results by Search

### Search 1: Survival / Mortality

**Terms:** `("Acropora palmata" OR "elkhorn coral") AND (survival OR mortality OR "hazard rate" OR "mortality rate")`

**PubMed results (notable):**
- Mendoza Quiroz et al. 2023 (PMID: 37547720) -- ALREADY INCLUDED
- Ramos Romero et al. 2025 (PMID: 41256771) -- ALREADY INCLUDED (`ramos_romero_2025`)
- Williams & Miller 2010 -- ALREADY INCLUDED
- Manzello et al. 2025, Science (PMID: 41129628) -- NEW CANDIDATE (see below)
- Neely et al. 2022, Frontiers in Marine Science -- ALREADY EXCLUDED (`Neely 2022`)

**Semantic Scholar results (notable):**
- Pausch et al. 2018, Frontiers in Marine Science -- ALREADY INCLUDED
- Manzello et al. 2025 (also surfaced here) -- NEW CANDIDATE
- TCI nursery preprint (Research Square, rs-7301952) -- NEW CANDIDATE (see below)
- Cunning et al. 2025, Coral Reefs -- NEW CANDIDATE (see below)

### Search 2: Growth

**Terms:** `("Acropora palmata" OR "elkhorn coral") AND (growth OR "linear extension" OR calcification OR "skeletal density" OR "areal growth" OR "extension rate")`

**PubMed results (notable):**
- Mendoza Quiroz et al. 2023 -- ALREADY INCLUDED
- Ramos Romero et al. 2025 -- ALREADY INCLUDED
- Growth dynamics of A. cervicornis (PMID: 32095328) -- wrong species

**Semantic Scholar results (notable):**
- Barton & Willis (coral propagation review) -- no individual-level A. palmata data
- Miller & Chiappone (population status of Acropora) -- ALREADY EXCLUDED (`Miller 2009`)
- Ware & Garfield (A. cervicornis outplanting) -- wrong species

**No new candidates from Search 2.**

### Search 3: Settlement / Recruitment

**Terms:** `("Acropora palmata" OR "elkhorn coral") AND (settlement OR settlers OR recruit OR recruitment OR spat OR larval OR fecundity OR egg OR planula)`

**PubMed results (notable):**
- Mendoza Quiroz et al. 2023 -- ALREADY INCLUDED
- Ritson-Williams et al. (settlement preferences) -- no survival/growth tracking
- Randall & Szmant 2009 (PMID: 20040751) -- larval development; no field demographic data
- Albright et al. 2010 (PMID: 21059900) -- ocean acidification; no field survival tracking
- Miller et al. 2016 (PMID: 27703862) -- ALREADY EXCLUDED (`Muller 2014` / related NOAA work)

**Semantic Scholar results (notable):**
- Lirman 2000 (fragmentation) -- ALREADY EXCLUDED (`Lirman 2000`)
- Ritson-Williams et al. (macroalgae impact on settlement) -- no demographic data

**No new candidates from Search 3.**

### Search 4: Restoration Demography

**Terms:** `("Acropora palmata" OR "elkhorn coral") AND (outplant OR restoration OR nursery) AND (survival OR growth OR mortality)`

**PubMed results (notable):**
- Mendoza Quiroz et al. 2023 -- ALREADY INCLUDED
- Ramos Romero et al. 2025 -- ALREADY INCLUDED
- Lirman 2000 (PMID: 10958900) -- ALREADY EXCLUDED
- Maurer et al. 2022 (Bahamas line nursery, PLOS ONE) -- ALREADY INCLUDED (`maurer_2022`)
- Schutter et al. 2023 (ex-situ sexual recruits, Aquaculture) -- NEW CANDIDATE (see below)

**Semantic Scholar results (notable):**
- Rosales et al. 2024 (reef site + microbiome, Comms Earth Environ) -- ALREADY INCLUDED (`rosales_2024`)
- Young et al. 2025 (extirpation prevention, Conservation Biology) -- NEW CANDIDATE (see below)
- Nedimyer et al. (Coral tree nursery) -- no individual A. palmata survival data
- Ware & Garfield (A. cervicornis only) -- wrong species

### Search 5: Long-term Monitoring

**Terms:** `("Acropora palmata" OR "elkhorn coral") AND ("long-term" OR "time series" OR monitoring OR "population trend")`

**PubMed results:**
- Site: operator returned no results; broader searches returned:
  - Mendoza Quiroz et al. 2023 -- ALREADY INCLUDED
  - Neely et al. 2022 -- ALREADY EXCLUDED
  - NOAA demographic monitoring references -- ALREADY INCLUDED

**Semantic Scholar results (notable):**
- Gardner et al. 2003 (long-term Caribbean decline) -- regional meta-analysis, not individual A. palmata tracking
- Pandolfi et al. 2003 (global trajectories) -- not individual-level
- Ware & Garfield (A. cervicornis) -- wrong species

**No new candidates from Search 5.**

---

## New Candidate Papers

The following papers were identified as potentially meeting the inclusion criteria (longitudinal tracking of individually identified *A. palmata* colonies/fragments with survival data, sample size, and time interval). Each is evaluated against the study's eligibility criteria from `PRISMA_Systematic_Review_Protocol.md` Section 2.

### Candidate 1: Manzello et al. 2025

| Field | Value |
|---|---|
| **Title** | Heat-driven functional extinction of Caribbean *Acropora* corals from Florida's Coral Reef |
| **Authors** | Manzello DP, Cunning R, Karp RF, Baker AC, + 43 co-authors |
| **Year** | 2025 |
| **Journal** | Science, 390: 361-366 |
| **DOI** | 10.1126/science.adx7825 |
| **PMID** | 41129628 |
| **Why it might qualify** | Reports survival/mortality of 52,356 wild and restored *Acropora* colonies (both *A. palmata* and *A. cervicornis*) across ~560 km of Florida's Coral Reef before and after the 2023 marine heatwave. Reports 97.8-100% mortality in Keys/Dry Tortugas, 37.9% mortality offshore SE Florida. Enormous sample size with species-specific data. |
| **Potential issues** | (1) Combines multiple existing monitoring programs (NOAA, USGS, CRF, etc.) -- may overlap substantially with NOAA_survey data already included. (2) Reports aggregate mortality percentages rather than individual-level tracked fate data in a format extractable per colony. (3) May report total Acropora (palmata + cervicornis combined) rather than species-separated survival. (4) The mortality event (2023 heatwave) postdates the demographic monitoring period compiled in this study. |
| **Recommendation** | **Evaluate carefully.** Read the paper to determine whether A. palmata-specific survival data are reported with sample sizes separable from A. cervicornis, and whether the data overlap with the NOAA monitoring dataset already included. If separable and non-overlapping, this would represent a major new data source. However, this is an acute disturbance event, not typical demographic monitoring. |

### Candidate 2: TCI Nursery Mortality Study (Preprint)

| Field | Value |
|---|---|
| **Title** | Mortality and recovery rates of *Acropora* fragments on in-situ nurseries after the 2023 bleaching event in the Turks and Caicos Islands |
| **Authors** | Not fully identified from search results |
| **Year** | 2025 (preprint) |
| **Journal** | Research Square (preprint, not peer-reviewed) |
| **DOI** | 10.21203/rs.3.rs-7301952/v1 |
| **Why it might qualify** | Reports survival/mortality of *A. palmata* and *A. cervicornis* fragments in nurseries during the 2023 bleaching event in Turks and Caicos Islands. A. palmata mortality = 74.7%. Deepest nursery (12.1 m) had lowest mortality (54.8%). Binary logistic regression predicted fragment survival with 87.1% accuracy based on site, species, and structure type. |
| **Potential issues** | (1) Preprint -- not peer-reviewed. The project's grey literature policy (Section 3.3) allows dissertations and government reports but does not explicitly address preprints. (2) Reports nursery fragment survival, not outplanted colony survival. (3) New geographic region (TCI) not currently represented. (4) Acute disturbance event. |
| **Recommendation** | **Monitor for publication.** If published in peer review, evaluate for inclusion. Would add a new region (TCI) and nursery-specific mortality data during thermal stress. Note: the PRISMA protocol already lists bioRxiv preprints as "cited for context but not included in meta-analysis pending peer review." |

### Candidate 3: Cunning et al. 2025

| Field | Value |
|---|---|
| **Title** | Heat-tolerant algal symbionts may prevent extirpation of the threatened elkhorn coral, *Acropora palmata*, in Florida during intensifying marine heatwaves |
| **Authors** | Cunning R, and others (University of Miami / NOAA) |
| **Year** | 2025 |
| **Journal** | Coral Reefs (Springer) |
| **DOI** | 10.1007/s00338-025-02652-7 |
| **Why it might qualify** | Tracked survival of outplanted *A. palmata* colonies at multiple Florida reef sites; algal symbiont type was the strongest predictor of thermal performance. Colonies hosting *Durusdinium* were ~1.9 degrees C more thermally tolerant. Likely reports colony-level survival with sample sizes. |
| **Potential issues** | (1) May overlap with NOAA restoration monitoring data already included. (2) Focus is on symbiont identity as a predictor, not size-dependent survival. (3) May not report colony sizes. (4) Published in the target journal (Coral Reefs), so would be known to the editorial team. |
| **Recommendation** | **Evaluate.** Read to determine whether colony-level survival with sample sizes and time intervals is reported, and whether colony sizes are recorded. If so, could contribute to the meta-analysis as a Florida restoration study with genotype-level data. |

### Candidate 4: Schutter et al. 2023

| Field | Value |
|---|---|
| **Title** | Enhancing survival of ex-situ reared sexual recruits of *Acropora palmata* for reef rehabilitation |
| **Authors** | Schutter M, and others |
| **Year** | 2023 |
| **Journal** | Aquaculture (Elsevier) |
| **DOI** | 10.1016/j.aquaculture.2023.739401 (estimated from ScienceDirect URL: S092585742300071X) |
| **Why it might qualify** | Reports survival of ex-situ reared *A. palmata* sexual recruits under different aquaculture regimes. Coral spawn collected August 2016 in Bahamas, cross-fertilized, reared in mobile lab. Best treatment doubled survival and recruit size at 10 months post-settlement compared to ambient. |
| **Potential issues** | (1) Ex-situ aquaculture study (lab/tank conditions), not field demographic data. The inclusion criteria require "Caribbean reef environments." (2) Reports recruits at settlement/micro-colony stage -- likely below the size range relevant to the Lefkovitch matrix (SC1 = 0-10 cm2). (3) May be an aquaculture optimization study rather than demographic monitoring. |
| **Recommendation** | **Likely exclude.** The study appears to focus on laboratory aquaculture conditions and very early life stages, not field survival of trackable colonies. However, if any outplanting or field monitoring component with size data exists, it could qualify. |

### Candidate 5: Young et al. 2025

| Field | Value |
|---|---|
| **Title** | Success of restoration strategies in preventing extirpation of 2 critically endangered coral species |
| **Authors** | Young BD, and others |
| **Year** | 2025 |
| **Journal** | Conservation Biology (Wiley) |
| **DOI** | 10.1111/cobi.70168 |
| **Why it might qualify** | Reviews two decades of Acropora restoration in Florida; documents survival of nursery-reared and outplanted colonies across multiple programs. May synthesize survival data with sample sizes across restoration efforts. |
| **Potential issues** | (1) May be a review/synthesis paper that cites primary data already included (NOAA, USGS, CRF data). (2) May not report new primary survival data with individual colony tracking. (3) Survival percentages may be aggregated across species (A. palmata + A. cervicornis). |
| **Recommendation** | **Evaluate.** Read to determine if new primary survival data for A. palmata are reported that do not overlap with already-included studies. If it is purely a review of previously published data, it would not contribute new data points but could be cited for context. |

### Candidate 6: Rosales et al. 2024 (Reef site + microbiome)

| Field | Value |
|---|---|
| **Title** | Reef site and habitat influence effectiveness of *Acropora palmata* restoration and its microbiome in the Florida Keys |
| **Authors** | Rosales SM, Young BD, Bright AJ, Montes E, Zhang JZ, Traylor-Knowles N, Williams DE |
| **Year** | 2024 |
| **Journal** | Communications Earth & Environment, 5: 689 |
| **DOI** | 10.1038/s43247-024-01816-7 |
| **Status** | **ALREADY INCLUDED** as `rosales_2024` -- confirmed by author name overlap and subject matter. |

---

## Papers Confirmed Already Included or Excluded

The following papers surfaced in the searches and were confirmed as already accounted for:

**Already included (17 studies, 22 effects):**
- Mendoza Quiroz et al. 2023 (PeerJ) -- `mendoza_quiroz_2023`
- Ramos Romero et al. 2025 (PeerJ) -- `ramos_romero_2025`
- Pausch et al. 2018 -- `pausch_2018`
- Kuffner et al. 2020 -- `kuffner_2020`
- Maurer et al. 2022 -- `maurer_2022`
- Williams & Miller 2010 -- `williams_miller_2010`
- Rosales et al. 2024 -- `rosales_2024`
- Vardi 2011 -- `vardi_2011`
- Forrester et al. 2013 -- `forrester_2013`

**Already excluded:**
- Neely et al. 2022 (population trajectory, Florida Keys) -- NOW INCLUDED (April 2026, direct data sharing; 878 colonies)
- Lirman 2000 (fragmentation) -- excluded per protocol
- Miller 2009 / Muller 2014 -- excluded per protocol
- Garcia-Uruena 2020 -- excluded per protocol

---

## Conclusion

The original search by Detmer (2025) appears **reasonably comprehensive** for the specialized literature on *A. palmata* size-dependent demography. The replication identified **5 new candidate papers** not in the included or excluded lists, but most are unlikely to contribute extractable size-dependent survival data:

1. **Manzello et al. 2025 (Science)** -- The most significant potential addition. Reports massive dataset (52,356 colonies) but likely overlaps with NOAA monitoring data already included, and documents an acute heatwave event rather than baseline demography. **Priority: evaluate for overlap and species-specific data availability.**

2. **TCI nursery preprint (2025)** -- New region but preprint; monitor for peer-reviewed publication.

3. **Cunning et al. 2025 (Coral Reefs)** -- Potential survival data with colony tracking, but likely overlaps with existing Florida restoration datasets. **Priority: evaluate for new data.**

4. **Schutter et al. 2023 (Aquaculture)** -- Likely excludable as ex-situ aquaculture optimization, not field demography.

5. **Young et al. 2025 (Conservation Biology)** -- Likely a review paper synthesizing existing data rather than reporting new primary data.

**Overall assessment:** The search gap is small. The main risk is that Manzello et al. 2025 and Cunning et al. 2025 contain Florida restoration survival data that partially overlap with but extend beyond the existing NOAA dataset. These two papers should be read in full to determine whether they contain non-overlapping, species-specific survival data with sample sizes and time intervals that would qualify for inclusion.

**Limitation of this replication:** WebSearch returns a maximum of ~10 results per query, making precise hit counts impossible. A formal replication should run these exact Boolean strings in PubMed Advanced Search and Semantic Scholar's search interface to obtain true hit counts. The strings should also be run in Web of Science and Google Scholar for completeness.

---

*Replication conducted: 2026-03-26*
*Ocean Recoveries Lab, UC Santa Barbara*
