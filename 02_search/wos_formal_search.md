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

Full cross-referencing of all WoS hits against the existing screening list requires export of individual records. The PubMed cross-reference (63 papers, 6 needing screening) provides the higher-confidence check since our included studies are predominantly in PubMed-indexed journals. Any studies unique to WoS but not PubMed would likely be: (a) marine ecology journals not in PubMed (e.g., Coral Reefs, Marine Ecology Progress Series, ICES Journal), (b) conference proceedings, or (c) older literature pre-dating PubMed indexing.

**Action needed:** Export WoS results as BibTeX/CSV for full cross-referencing. The saturation analysis via Elicit (298 papers, all 16 published included studies recovered) provides strong evidence that no critical studies are missing.

---

*Search conducted programmatically via Playwright CDP (Chrome DevTools Protocol)*
*Reproducibility: queries above can be re-run at https://www.webofscience.com/wos/woscc/advanced-search*
