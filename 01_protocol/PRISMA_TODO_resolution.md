# PRISMA TODO Resolution

Historical note cross-referencing earlier protocol `[TODO]` items against Raine Detmer's original working notes. This file is retained for auditability; the active protocol is [systematic_review_protocol.md](/Users/adrianstier/Detmer-2025-coral-parameters/01_protocol/systematic_review_protocol.md).

---

## Resolved from Raine's Notes

| TODO item | Location in PRISMA | Answer | Source in notes |
|---|---|---|---|
| Google Scholar search strings | Lines 89-97 (§3.1 search table) | Already correctly transcribed in the PRISMA doc. The 5 search strings match Raine's notes exactly: base query `("Acropora palmata" OR "elkhorn coral")` combined with 5 term sets for survival, growth, recruitment, restoration, and long-term monitoring. | Notes lines 14 (under "Literature search methods") |
| Screening procedure details | Lines 103-112 (§3.1) | Already correctly transcribed. Two-stage screening: (1) title/abstract skim for A. palmata growth/survival + colony size info; (2) full-text assessment against specific criteria for survival (initial number/size + number surviving ~1 year) and growth (initial/final sizes or initial sizes + growth rate; excluded linear extension only). | Notes lines 16-19 |
| Databases searched (WoS, PubMed) | Line 81-82 (§3.1 table) | Raine's notes mention ONLY Google Scholar for bibliographic searching. No mention of Web of Science or PubMed in the original search. These were **not used** in the original 2025 search. | Notes line 14: "using google scholar, searched for..." -- no other databases mentioned |
| Who screened (single vs. dual) | Line 148 (§4.1 table) | Raine Detmer alone. The notes are written entirely in first person ("I went through papers", "I then skimmed through them", "I then went through and read them more carefully"). No mention of co-screening or discussion with Adrian Stier. | Notes lines 15-17, and all study notes written in first person singular |
| Screening method | Line 148 (§4.1 table) | Sequential by single screener (not independent dual screening). For each search string, Raine reviewed results pages sequentially "stopping once they all seemed irrelevant" (saturation-based stopping). | Notes line 15 |
| Full-text assessment screener | Line 149 (§4.1 table) | Raine Detmer alone. | Notes lines 17-19, all first-person |
| Full-text assessment method | Line 149 (§4.1 table) | Careful reading against two specific criteria: (1) survival criterion -- study must report initial number + size of colonies and number surviving ~1 year; (2) growth criterion -- study must record initial/final sizes or initial sizes + growth rate (linear extension only excluded). | Notes lines 18-19 |
| Size standardization method | §5.1 (implicit) | Live planar area (cm^2) following Vardi et al. 2012: length x width x %live tissue. For recruits, assumed circular. For studies with only length/diameter, used empirically estimated width:length ratios from available datasets to convert. | Notes lines 22-25 |
| Mortality definition variability | §5.1 (implicit) | Varies by study: NOAA = no tissue + skeleton gone or absent; Kuffner = >=50% tissue loss (though photos showed 100% dead); USGS = no live tissue remaining; others variable. This is documented in Raine's per-study notes. | Notes lines 153-154, 174, 184 |
| Vardi 2011 overlap with NOAA | §2.5 / §6.1 | Raine explicitly identified and handled the overlap: "the sampling years and plot locations in Florida, Curacao, Navassa are all included in the large NOAA survey data set...so assumed they covered the same corals and didn't include them again here, so only used the survival estimates from Jamaica, Puerto Rico, and Virgin Gorda." | Notes lines 280-281 |
| Data extraction form | Line 220 (§5.2) | Confirmed: no formal extraction form was used. Raine extracted data directly into standardized CSV format with per-study notes documenting all assumptions and caveats in the docx. The PRISMA doc already correctly states this. | Notes lines 6-8 ("put all the notes/caveats/assumptions for each study in the 'Study/Dataset notes' section below") |
| Studies with figure-derived values | Line 393 (§7.3) | Confirmed from notes: Bruckner & Bruckner 2001 (Fig. 3 stacked histogram), Garrison & Ward 2008 (Fig. 4b), Chamberland et al. 2015 (Fig. 2), Roth et al. 2013 (Fig. 5 histograms), Vardi 2011 (Fig. 4-2 stacked bar plots), Ortiz Prosper 2005 (Fig. 3.4), Schutter et al. 2023 (Fig. 6). No digitization software used -- all visually estimated. | Multiple locations throughout notes (lines 247, 255, 197, 269, 275, 282, 260) |

---

## Still Requires Raine's Input

| TODO item | Location in PRISMA | What's needed | Why it can't be inferred |
|---|---|---|---|
| Date(s) Google Scholar searches were run | Line 80, 101 (§3.1) | Exact date(s) or at minimum month/year when each of the 5 search strings was run. | Notes say "Jun-Dec 2025" as the overall period but do not specify when individual searches were executed. Google Scholar does not have a search history feature. May be recoverable from browser history or the Google Sheet tracker. |
| Hit counts per Google Scholar search | Line 80, 101 (§3.1) | Approximate number of results returned for each of the 5 search strings. | Not recorded in Raine's notes. Google Scholar does show total hit counts on the results page, but these were not documented. Since Raine used a saturation stopping rule ("stopping once they all seemed irrelevant"), the number of results *reviewed* per search would also be informative. |
| Total number of papers screened at title/abstract | Line 148 (§4.1 table) | The total number of papers that Raine skimmed across all 5 search strings before narrowing to the ~16-19 evaluated in detail. | Not recorded. Raine notes the process but not the counts. |
| Date NOAA NCEI was searched | Line 76 (§3.1 table) | When the NOAA Accession 0142175 dataset was first accessed/downloaded. | Not in notes. May be in download records or Google Sheet. |
| Date NOAA InPort was searched | Line 77 (§3.1 table) | When the Pausch et al. 2018 data (Catalog 26790) was first accessed. | Not in notes. |
| Date USGS CMGDS was searched | Line 78 (§3.1 table) | When the USGS USVI data was first accessed. | Not in notes. |
| Date USGS ScienceBase was searched | Line 79 (§3.1 table) | When the Kuffner et al. 2020 data was first accessed. | Not in notes. |
| Number of records from data repositories | Lines 76-79 (§3.1 table) | How many datasets were found/evaluated from each repository before selecting the ones used. | Not in notes. Raine appears to have gone directly to specific datasets (targeted retrieval), so "n" may be 1 per repository, but this should be confirmed. |
| Date FUNDEMAR data was received | Line 84 (§3.1 table) | When the personal communication / data sharing from Maria at FUNDEMAR occurred. | Not in notes; only the data files are referenced. |
| Total entries in Google Sheet tracker | Line 85 (§3.1 table) | Number of rows/studies logged in `coral_parameters_lit_review.gsheet`. | The Google Sheet is referenced but its contents are not reproduced in the notes. |
| Number of citation chaining records | Line 276 (§6.1 flow diagram) | How many papers were identified through forward/backward citation chaining from Vardi 2011, Williams & Miller 2012, Lirman 2003. | Not recorded. The notes reference specific studies that were found but do not tally how many were screened through citation chaining. |
| PubMed/Semantic Scholar hit counts (March 2026 expansion) | Lines 122-123 (§3.2 table) | Number of hits from the AI-assisted expanded search. | These searches were run by Claude in a separate session; not in Raine's notes. Recoverable from Claude session logs. |
| Exact search strings for March 2026 expansion | Line 128 (§3.2) | The PubMed and Semantic Scholar query strings used during the expanded search. | Run by Claude, not by Raine. Recoverable from session logs. |
| Verify k counts (k=17 studies, 22 effects) | Line 345 (§6.1 note) | Cross-check the final study count against the actual output of `14b_expanded_meta_analysis.R`. Roth et al. 2013 removed for data overlap with Rogers & Muller 2012. NOAA split by region (FL Keys/Curacao/Navassa). Garrison & Ward 2008 split into control/relocated (2 effects). Neely et al. 2022 added April 2026 (direct data sharing). | This is a code verification task, not in the notes. Requires running or inspecting the R script output. |

---

## Recommended Edits to PRISMA Protocol

The following edits can be made now based on what Raine's notes confirm.

### Edit 1: Confirm WoS and PubMed were NOT used in original search (Lines 81-82)

**Current text (line 81):**
```
| Web of Science | Bibliographic database | `[TODO: confirm if searched]` | `[TODO: n]` | `[TODO: confirm whether WoS was used]` |
```

**Recommended replacement:**
```
| Web of Science | Bibliographic database | Not searched | — | Not used in original search; Google Scholar was the sole bibliographic database |
```

**Current text (line 82):**
```
| PubMed | Bibliographic database | `[TODO: confirm if searched]` | `[TODO: n]` | `[TODO: confirm whether PubMed was used in original search]` |
```

**Recommended replacement:**
```
| PubMed | Bibliographic database | Not searched | — | Not used in original search; only used in March 2026 expanded search |
```

### Edit 2: Fill in screening process details (Lines 144-149)

**Current text (lines 144-149):**
```
`[TODO: Raine to confirm details of the screening process]`

| Stage | Screener(s) | Method | Records |
|---|---|---|---|
| Title/abstract screening | `[TODO: Raine Detmer alone, or with Adrian Stier?]` | `[TODO: independent? discussed?]` | `[TODO: n screened]` |
| Full-text assessment | `[TODO]` | `[TODO]` | 16 papers evaluated |
```

**Recommended replacement:**
```
| Stage | Screener(s) | Method | Records |
|---|---|---|---|
| Title/abstract screening | Raine Detmer (sole screener) | Sequential review of Google Scholar results pages per search string; saturation-based stopping rule (stopped when all results on a page appeared irrelevant) | `[TODO: n screened — not recorded; ask Raine for estimate]` |
| Full-text assessment | Raine Detmer (sole screener) | Read each paper against two criteria: (1) survival — must report initial number + size and number surviving ~1 yr; (2) growth — must record initial/final sizes or initial sizes + growth rate (linear extension only excluded) | ≥19 papers evaluated (16 included + ≥3 excluded) |
| Data extraction | Raine Detmer | Manual reading of papers + data file download; per-study assumptions documented in working notes | 15 included (6 Tier 1 + 9 Tier 2) |
```

### Edit 3: Clarify that data repository searches were targeted retrievals (Lines 76-79)

Add a note after line 85 or in the Notes column:

**Add after the table (approximately line 86):**
```
> **Note on data repository searches:** The NOAA and USGS repository searches were targeted retrievals of specific known datasets, not broad keyword searches across the repository catalogs. The hit counts are therefore N/A (1 dataset retrieved per repository). The exact access dates should be recoverable from download timestamps or the Google Sheet tracker.
```

### Edit 4: Simplify the extraction form TODO (Line 220)

**Current text (line 220):**
```
`[TODO: A formal, fillable data extraction form (spreadsheet template) should be created and archived with the project...]`
```

**Recommended replacement:**
```
> **Note:** No formal extraction form was used prospectively. Data were extracted directly into standardized CSV files (`05_data/standardized/`) with assumptions and caveats documented in per-study notes retained under `04_extraction/raine_working_notes/`. The template in §5.3 below reconstructs the extraction protocol retrospectively.
```

### Edit 5: Update the PRISMA deviations table (Line 412)

**Current text (line 412):**
```
| Search strings | Exact Boolean strings per database | Partially reconstructed; `[TODO]` items remain | Original search used expert-driven repository mining + citation chaining. Exact strings not recorded at the time. |
```

**Recommended replacement:**
```
| Search strings | Exact Boolean strings per database | Google Scholar strings fully reconstructed from working notes; data repository searches were targeted retrievals; dates and hit counts not recorded | Original search used Google Scholar (sole bibliographic database) + targeted data repository mining + citation chaining. |
```

---

## Summary

- **11 items resolved** from Raine's notes, including the most substantive ones (screening procedure, who screened, WoS/PubMed not used, extraction method, overlap handling).
- **14 items still need Raine's input**, mostly dates and hit counts that were not recorded in the working notes. The most critical are the Google Scholar search dates and approximate number of papers screened, which a reviewer would expect to see.
- **5 edits can be made now** to the PRISMA protocol based on confirmed information from the notes.
- The Google Sheet tracker (`coral_parameters_lit_review.gsheet`) is the most likely source for resolving the remaining date/count TODOs.
