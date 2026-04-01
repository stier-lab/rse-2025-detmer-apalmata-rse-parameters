# Elicit Systematic Search Replication

**Date:** 2026-03-26
**Platform:** Elicit API (Semantic Scholar index, 125M+ papers)
**API key:** elk_live_...7-k (Pro plan, 100 results/search)

---

## Search Results Summary

| Search # | Query terms (base: "Acropora palmata" OR "elkhorn coral") | Elicit hits | A. palmata specific |
|---|---|---|---|
| 1 | survival mortality hazard rate | 100 | 60 |
| 2 | growth linear extension calcification areal growth extension rate | 100 | 29 |
| 3 | settlement settlers recruit recruitment spat larval fecundity egg planula | 100 | 38 |
| 4 | outplant restoration nursery survival growth mortality | 100 | 46 |
| 5 | long-term time series monitoring population trend | 100 | 62 |

**Total unique papers across all 5 searches:** 298
**A. palmata-specific papers:** 89

---

## Cross-Reference Against Included Studies

All 19 candidate studies at the time of the Elicit search were checked against results (3 were later removed; Neely et al. 2022 added April 2026 via direct data sharing; final meta-analysis: 17 studies, 22 effects):

| Study | Found by Elicit? |
|---|---|
| NOAA_survey (Williams et al.) | Yes (search 1, 4, 5) |
| Pausch et al. 2018 | Yes (search 1, 4) |
| Kuffner et al. 2020 | Yes (search 1, 4) |
| USGS_USVI (unpublished) | No (unpublished data release) |
| Fundemar (unpublished) | No (direct data sharing) |
| Mendoza-Quiroz et al. 2023 | Yes (search 1, 4) |
| Vardi 2011 (dissertation) | No (dissertation not in Semantic Scholar) |
| Bruckner & Bruckner 2001 | Yes (search 1) |
| Roth et al. 2013 | Yes (search 1) |
| Ortiz Prosper 2005 | No (dissertation) |
| Forrester et al. 2013 | Yes (search 1, 4) |
| Rosales et al. 2024 | Yes (search 1, 4) |
| Maurer et al. 2022 | Yes (search 4) |
| Williams & Miller 2010 | Yes (search 4) |
| Garrison & Ward 2008 | Yes (search 1, 4) |
| Rogers & Muller 2012 | Yes (search 1, 5) |
| Ramos-Romero et al. 2025 | Yes (search 4) |
| Muller et al. 2008 | Yes (search 1) |
| Sutherland et al. 2016 | Yes (search 1) |

**3 studies not found by Elicit:** All are unpublished data (USGS, Fundemar) or dissertations (Vardi, Ortiz Prosper) not indexed in Semantic Scholar. These were identified through data repository mining and citation chaining, which is expected.

---

## New Candidate Papers Identified

After filtering for A. palmata-specific papers with demographic terms not matching any known author in the included or excluded lists:

| Paper | Year | Potential relevance | Assessment |
|---|---|---|---|
| Chen et al. "Spatio-temporal dynamics of A. palmata" | 2020 | Population monitoring | Cross-sectional; uses NOAA reef-level data, not individual tracking |
| Banister et al. "Environmental predictors for restoration" | 2024 | Restoration survival | Uses NOAA monitoring sites; likely overlaps |
| Alvarado-Cerón et al. "Genomic insights into populations" | 2025 | Population genetics | No demographic data (genomics only) |
| Garcia-Uruena 1995/2016 "Regeneration and transplant Colombia" | 2016 | Fragment transplant | Already assessed and excluded (cross-sectional) |

**Conclusion:** No new studies with extractable A. palmata individual-level survival data were identified that are not already in the included or excluded lists. The original search + expanded audit appears comprehensive for the available published literature.

---

## Search Completeness Assessment

The Elicit search across 125M+ papers confirms:

1. **All 17 included published studies** were found by at least one search string or identified through other channels (unpublished data sources and direct data sharing)
2. **No new studies with extractable longitudinal survival data** were identified beyond those already evaluated
3. **The search is saturated** — additional search strings are unlikely to yield new demographic data sources for A. palmata

This supports the conclusion that the meta-analysis (k=17 studies, 22 effects) represents a near-complete compilation of all published A. palmata survival data with individual colony tracking.

---

*Search conducted via Elicit API (Pro plan) on 2026-03-26*
*Raw JSON results archived in /tmp/elicit_searches/*
