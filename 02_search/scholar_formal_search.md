# Google Scholar Formal Search — PRISMA Documentation

**Date:** 2026-03-29
**Database:** Google Scholar (scholar.google.com)
**Searcher:** Adrian Stier
**Method:** Programmatic queries via Chrome DevTools Protocol connected to authenticated Chrome session. Top 20 results per query extracted to CSV.

---

## Search Strategy

**Base query:** `"Acropora palmata" OR "elkhorn coral"`

| Search # | Full query | Scholar hits |
|----------|-----------|-------------|
| 1 | `"Acropora palmata" OR "elkhorn coral" AND survival OR mortality` | **~7,870** |
| 2 | `"Acropora palmata" OR "elkhorn coral" AND growth OR "linear extension" OR calcification` | **~9,730** |
| 3 | `"Acropora palmata" OR "elkhorn coral" AND settlement OR recruitment OR fecundity` | **~6,310** |
| 4 | `"Acropora palmata" OR "elkhorn coral" AND restoration OR nursery OR outplant AND survival OR mortality` | **~6,150** |
| 5 | `"Acropora palmata" OR "elkhorn coral" AND monitoring OR "long-term" OR "population trend"` | **~8,100** |

**Note on hit counts:** Google Scholar searches full text (not just title/abstract), does not support rigorous Boolean logic, and includes books, theses, patents, and conference abstracts. The ~6,000-10,000 hit counts are therefore much larger than PubMed (63) or WoS (207-216) and include many irrelevant results. Scholar hit counts are approximate ("About N results").

---

## Comparison Across Three Databases

| Search # | Topic | PubMed | WoS | Scholar |
|----------|-------|--------|-----|---------|
| 1 | Survival/mortality | 32 | 207 | ~7,870 |
| 2 | Growth | 25 | 216 | ~9,730 |
| 3 | Recruitment | 22 | 154 | ~6,310 |
| 4 | Restoration | 13 | 78 | ~6,150 |
| 5 | Monitoring | 16 | 116 | ~8,100 |

Scholar returns 30-100x more hits than WoS because it searches full text, includes grey literature, and has less precise Boolean handling.

---

## Cross-Reference with Included Studies

Of the top 20 results per search (100 total extracted), the following included studies appeared:

- Vardi 2011 (dissertation) — appeared in 4/5 searches
- Vardi et al. 2012 (ESR) — appeared in 4/5 searches
- Forrester et al. 2013/2014 — appeared in 4/5 searches
- Chamberland et al. 2015 — appeared in 5/5 searches
- Kuffner et al. 2020 — appeared in 4/5 searches
- Pausch et al. 2018 — appeared in 1/5 searches
- Maurer et al. 2022 — appeared in 1/5 searches
- Williams & Miller (various) — appeared in 4/5 searches

**No new includable studies** were identified in the top 20 results that are not already in the screening list. The Scholar results confirm that the high-visibility A. palmata demographic literature is well-captured.

---

## Output Files

Per-search CSVs with title, authors, year, journal, URL, citation count:
- `02_search/search_results/scholar/scholar_1_survival_mortality.csv` (20 records)
- `02_search/search_results/scholar/scholar_2_growth.csv` (20 records)
- `02_search/search_results/scholar/scholar_3_recruitment.csv` (20 records)
- `02_search/search_results/scholar/scholar_4_restoration.csv` (20 records)
- `02_search/search_results/scholar/scholar_5_monitoring.csv` (20 records)

---

## Limitations

1. Google Scholar does not support formal Boolean operators reliably — OR is treated as implicit, AND is default
2. Hit counts are approximate and non-reproducible (Scholar results vary by user, location, and time)
3. Only top 20 results per query were extracted (of thousands); however, relevance ranking means the most-cited and most-relevant studies appear first
4. Scholar includes non-peer-reviewed content (theses, book chapters, reports)
5. No formal deduplication across Scholar searches was performed

---

*Search conducted programmatically via Playwright CDP (Chrome DevTools Protocol)*
*Scholar is not a bibliographic database in the PRISMA sense — it supplements PubMed and WoS*
