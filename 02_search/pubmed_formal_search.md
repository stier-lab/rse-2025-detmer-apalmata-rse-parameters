# PubMed Formal Search — PRISMA Documentation

**Date:** 2026-03-29
**Database:** PubMed (NCBI E-utilities API, esearch.fcgi)
**Searcher:** Adrian Stier
**Method:** Programmatic Boolean queries via NCBI E-utilities REST API with Title/Abstract field restriction

---

## Search Strategy

**Base query:** `("Acropora palmata"[Title/Abstract] OR "elkhorn coral"[Title/Abstract])`

| Search # | Additional terms | PubMed hits |
|----------|-----------------|-------------|
| 1 | `AND (survival[tiab] OR mortality[tiab] OR "hazard rate"[tiab] OR "mortality rate"[tiab])` | **32** |
| 2 | `AND (growth[tiab] OR "linear extension"[tiab] OR calcification[tiab] OR "areal growth"[tiab])` | **25** |
| 3 | `AND (settlement[tiab] OR recruit[tiab] OR recruitment[tiab] OR fecundity[tiab] OR larval[tiab])` | **22** |
| 4 | `AND (outplant[tiab] OR restoration[tiab] OR nursery[tiab]) AND (survival[tiab] OR growth[tiab] OR mortality[tiab])` | **13** |
| 5 | `AND ("long-term"[tiab] OR monitoring[tiab] OR "time series"[tiab] OR "population trend"[tiab])` | **16** |

**Total unique PMIDs (union across all 5 searches):** 63

---

## Cross-Reference with Existing Screening

Of 63 PubMed papers:
- ~57 already in screening list (included, excluded, or non-demographic)
- 2 already flagged as candidates (Manzello 2025, Young/Muller 2025)
- 4 new papers requiring screening:

| PMID | Authors | Year | Title | Status |
|------|---------|------|-------|--------|
| 41210959 | Birkart et al. | 2025 | 2023 global heatwave causes mass mortality of a keystone coral on shallow Western Atlantic reefs | Needs screening |
| 41454911 | Wilson et al. | 2026 | Survival, rarity, and extinction in tropical stony corals | Needs screening |
| 32426458 | Cramer et al. | 2020 | Widespread loss of Caribbean acroporid corals was underway before coral bleaching | Likely exclude (historical/paleo) |
| 38166125 | Banister et al. | 2024 | Environmental predictors for the restoration of a critically endangered coral | Needs screening |
| 41129628 | Manzello et al. | 2025 | Heat-driven functional extinction of Caribbean Acropora | Already flagged as candidate |
| 41273189 | Muller et al. | 2025 | Success of restoration strategies in preventing extirpation | Already flagged (= Young et al. 2025) |

---

## All 63 PMIDs

10958900, 11795170, 15813778, 17158464, 17631417, 19395569, 20040751, 20095241, 20361023, 20406294, 20526374, 21059900, 21798197, 21858132, 22216101, 22589399, 23227169, 23254513, 23331636, 24370863, 24375136, 24850918, 24909707, 25155714, 25469321, 25519925, 26839742, 26880837, 27194698, 27671533, 28306807, 28310039, 2871213, 28751030, 29553820, 29910975, 30993053, 31170313, 31179987, 31282031, 31797896, 32095328, 32127622, 32426458, 32710518, 34493583, 35287349, 35468162, 35789026, 36510006, 37085476, 37260163, 37443199, 37547720, 37848062, 38166125, 39604459, 41129628, 41210959, 41256771, 41273189, 41454911, 41875832

---

*Search conducted programmatically via NCBI E-utilities API (esearch.fcgi + efetch.fcgi)*
*Full reproducibility: queries above can be re-run at https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi*
