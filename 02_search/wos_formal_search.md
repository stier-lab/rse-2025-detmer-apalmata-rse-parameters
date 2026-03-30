# Web of Science Formal Search — PRISMA Documentation

**Date:** 2026-03-29
**Database:** Web of Science Core Collection (Clarivate), All Editions
**Institution:** University of California Santa Barbara (authenticated via institutional access)
**Searcher:** AI (Claude Opus 4.6) via Playwright CDP, supervised by Adrian Stier
**Method:** Programmatic Boolean queries via Chrome DevTools Protocol connected to authenticated WoS session. Advanced Search interface with TS= (Topic) field tags.

---

## Search Strategy

**Base query:** `TS=("Acropora palmata" OR "elkhorn coral")`

| Search # | Full query | WoS hits |
|----------|-----------|----------|
| 1 | `TS=("Acropora palmata" OR "elkhorn coral") AND TS=(survival OR mortality OR "hazard rate" OR "mortality rate")` | **207** |
| 2 | `TS=("Acropora palmata" OR "elkhorn coral") AND TS=(growth OR "linear extension" OR calcification OR "areal growth")` | **216** |
| 3 | `TS=("Acropora palmata" OR "elkhorn coral") AND TS=(settlement OR recruit OR recruitment OR fecundity OR larval)` | **154** |
| 4 | `TS=("Acropora palmata" OR "elkhorn coral") AND TS=(outplant OR restoration OR nursery) AND TS=(survival OR growth OR mortality)` | **78** |
| 5 | `TS=("Acropora palmata" OR "elkhorn coral") AND TS=("long-term" OR monitoring OR "time series" OR "population trend")` | **116** |

**Note:** Hit counts reflect the full Web of Science Core Collection (SCI-EXPANDED, SSCI, AHCI, CPCI-S, CPCI-SSH, ESCI). The TS= (Topic) field searches titles, abstracts, author keywords, and Keywords Plus.

---

## Comparison with PubMed

| Search # | Topic | PubMed | WoS | Ratio |
|----------|-------|--------|-----|-------|
| 1 | Survival/mortality | 32 | 207 | 6.5x |
| 2 | Growth | 25 | 216 | 8.6x |
| 3 | Recruitment | 22 | 154 | 7.0x |
| 4 | Restoration | 13 | 78 | 6.0x |
| 5 | Monitoring | 16 | 116 | 7.3x |

WoS returns substantially more hits because: (1) WoS indexes marine ecology journals more comprehensively than PubMed (which focuses on biomedical literature), (2) WoS Topic search includes Keywords Plus (algorithmically derived terms), and (3) WoS includes conference proceedings.

---

## Cross-Reference Status

### Export Completed (2026-03-28)

Search 1 (survival/mortality, 207 hits) exported via Playwright CDP scraping of the WoS results page. Virtual scrolling required slow-scroll triggering to render all records.

**Output:** `02_search/search_results/wos/wos_search1_survival_mortality.csv`
- **206 unique records** (1 duplicate removed across page boundaries)
- Fields: title, authors, year, journal, doi, wos_id
- Year range: 1979-2026
- Completeness: 206/206 have title + authors + year + WoS ID; 203/206 have journal; DOI extraction not available from rendered DOM
- Script: `02_search/search_results/wos/extract_wos_results.mjs`

### Prior Notes

The PubMed cross-reference (63 papers, 6 needing screening) provides the higher-confidence check since our included studies are predominantly in PubMed-indexed journals. Any studies unique to WoS but not PubMed would likely be: (a) marine ecology journals not in PubMed (e.g., Coral Reefs, Marine Ecology Progress Series, ICES Journal), (b) conference proceedings, or (c) older literature pre-dating PubMed indexing. The saturation analysis via Elicit (298 papers, all 16 published included studies recovered) provides strong evidence that no critical studies are missing.

---

## Broader WoS Queries (2026-03-28)

Additional queries to expand beyond species-specific searches and capture related Caribbean coral demographic literature.

| Search # | Full query | WoS hits | Records extracted |
|----------|-----------|----------|-------------------|
| 6 | `TS=("Acropora" AND "Caribbean") AND TS=(survival OR mortality OR growth OR recruitment OR restoration)` | **409** | 344 |
| 7 | `TS=("threatened coral" OR "endangered coral" OR "ESA" OR "critically endangered") AND TS=("Caribbean" AND (survival OR mortality))` | **58** | 50 |

**Rationale:** Search 6 broadens the taxon from *A. palmata* specifically to all *Acropora* spp. in the Caribbean, capturing *A. cervicornis* and hybrid studies that may contain comparable demographic methodology or overlapping datasets. Search 7 uses ESA/conservation status terminology to capture papers framed around threatened species management rather than species-specific taxonomy.

**Output files:**
- `02_search/search_results/wos/wos_broader_acropora_caribbean.csv` (344 records)
- `02_search/search_results/wos/wos_threatened_coral_caribbean.csv` (50 records)
- Fields: title, authors, year, journal, doi, wos_id
- Extraction via virtual scroll + DOM parsing (same method as Search 1)
- Note: Virtual scrolling yields ~85% capture from 409 total due to rendering gaps; the missing ~65 records are distributed across pages

**Comparison with base query:**
- Base query `TS=("Acropora palmata" OR "elkhorn coral")` = 628 hits (per original search)
- Search 6 (all *Acropora* + Caribbean demographics) = 409 hits -- a subset filtered by demographic terms
- Search 7 (threatened/endangered + Caribbean survival) = 58 hits -- mostly *A. palmata* and *A. cervicornis* studies framed in conservation terms
- These broader queries provide additional cross-reference material but are not expected to yield new *A. palmata*-specific demographic studies beyond those already identified

---

*Search conducted programmatically via Playwright CDP (Chrome DevTools Protocol)*
*Reproducibility: queries above can be re-run at https://www.webofscience.com/wos/woscc/advanced-search*
