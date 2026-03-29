# Data Overlap Analysis

**Version:** 1.0
**Date:** March 2026
**Authors:** Raine Detmer, Adrian Stier
**Affiliation:** Ocean Recoveries Lab, UC Santa Barbara

---

## 1. The NOAA Tagged Colony Data Overlap Problem

The NOAA Acropora Demographic Monitoring Program (operated by NOAA Southeast Fisheries Science Center, principally by M. Williams, D. Williams, and M. Miller) is the largest long-term monitoring effort for *Acropora palmata* in the Caribbean. The program has produced multiple publications, data releases, and reports that draw on the same pool of individually tagged colonies at Florida Keys reef sites plus Curacao and Navassa.

The core dataset -- `NOAA_Tagged_Colony_Data.csv` (NCEI Accession 0142175) -- contains 4,025 individually tracked colonies and represents 78% of all individual-level observations in this synthesis. Because multiple papers analyze overlapping subsets of these colonies, including any NOAA-derived publication as a separate study would double-count data.

**Resolution:** The raw tagged colony dataset is included once as `NOAA_survey`. All publications that analyze subsets of this dataset are excluded as independent studies.

---

## 2. Studies Excluded for Data Overlap

### 2.1 NOAA Acropora Demographic Monitoring Publications

| Study | Relationship to NOAA_survey | Evidence | Decision |
|-------|---------------------------|----------|----------|
| **Williams & Miller 2008** | IS the NOAA monitoring dataset. This paper describes the monitoring protocol and presents early results. | Authors and institution match; dataset description matches NCEI 0142175. | **EXCLUDED** -- this is the foundational publication for `NOAA_survey`. |
| **Williams & Miller 2012** | Analyzes tagged colony data from the same NOAA program, focusing on population trends and size-dependent survival. | Same authors, same Florida Keys sites, same tagging methodology. | **EXCLUDED** -- subset of `NOAA_survey` data. |
| **Williams et al. 2024** | Genet-level analysis of a single spawning/mortality event within the NOAA monitoring framework. | Same NOAA colonies; single-event focus not suitable for annualized survival. | **EXCLUDED** -- overlapping colony set, not independent. |
| **Bright et al. 2013** | NOAA technical memorandum presenting monitoring results from Florida Keys sites. | Same institution (NOAA SEFSC), same monitoring program, same tagged colonies. | **EXCLUDED** -- subset of `NOAA_survey`. |
| **Miller et al. 2009** | Community-level monitoring at NOAA Florida Keys sites; includes *A. palmata* as one of many species. | Same NOAA sites; data are community-level percent cover, not individual-colony tracking, but geographic overlap is complete. | **EXCLUDED** -- geographic and programmatic overlap with `NOAA_survey`. |

### 2.2 USGS/NPS St. John Monitoring Publications

| Study | Relationship | Evidence | Decision |
|-------|-------------|----------|----------|
| **Muller et al. 2014** | Analyzed tagged *A. palmata* colonies at Haulover Bay, USVI -- the same bay and likely the same colony set as Rogers & Muller 2012. | Same lead author (Muller), same location (Haulover Bay), overlapping time period (2003--2010 vs. 2003--2009). | **EXCLUDED** -- probable colony overlap with Rogers & Muller 2012. |

### 2.3 Kuffner et al. 2020 Follow-Up

| Study | Relationship | Evidence | Decision |
|-------|-------------|----------|----------|
| **Chapron et al. 2023** | Explicitly states it sampled "the surviving corals from Kuffner et al. [2020]" for genetic analysis. | Direct statement in methods; same Dry Tortugas site, same outplanted colonies. | **EXCLUDED** -- not independent; same colony set as `kuffner_et_al_2020`. |

### 2.4 Partial Overlap (Split Inclusion)

| Study | Overlapping Component | Independent Component | Decision |
|-------|----------------------|----------------------|----------|
| **Sutherland et al. 2016** | FKNMS contemporary component (2008--2014): monitored *A. palmata* at Carysfort Reef and Molasses Reef in the Florida Keys. The contemporary FKNMS-wide survey explicitly overlaps with NOAA at Carysfort and Molasses reefs (acknowledged in paper p. 11). | EDR historical dataset (1994--2004): 92 *A. palmata* tracked via permanent photostations at Eastern Dry Rocks (EDR) in the Lower Keys. Different institution, different era, pre-dates NOAA program at these sites. | **EXCLUDED (both components).** FKNMS excluded for NOAA overlap. EDR initially assessed as independent but subsequently **excluded during IRR audit** because the EDR monitoring used permanent photostations/quadrats rather than individually tagged colonies, violating the longitudinal individual-tracking inclusion criterion. See `inter_rater_reliability.md` Section 6. |

### 2.5 Corrected: Neely et al. 2022 (No Overlap)

**CORRECTION (2026-03-26):** The original assessment that Neely et al. 2022 overlapped with NOAA monitoring was **factually incorrect**.

Detailed site comparison reveals **zero geographic overlap**:

| Neely Site | Region | NOAA Site? |
|-----------|--------|-----------|
| Dry Tortugas | Dry Tortugas | No — ~200 km west of any NOAA plot |
| Sand Key | Lower Keys | No |
| Rock Key | Lower Keys | No |
| Western Sambo | Lower Keys | No |
| Looe Key (fore + back) | Lower Keys | No |
| Sombrero | Middle Keys | No |
| Ball Buoy | Biscayne NP | No — north of NOAA Upper Keys cluster |
| Marker 3 | Biscayne NP | No |

All 22 NOAA FL Keys plots are in the **Upper Keys** (Carysfort to Molasses, lat 24.96–25.28°N). Neely's sites span Lower Keys, Middle Keys, Biscayne NP, and Dry Tortugas — entirely non-overlapping.

The false overlap impression arose from: (a) NOAA funding, (b) methods trained by Dana Williams (NOAA), (c) use of the Williams & Miller 2006 monitoring protocol. None of these indicate shared colonies or sites.

**Current exclusion reason:** The paper reports LAI trajectories and stressor prevalence, NOT whole-colony survival counts (n_initial, n_dead). Survival data cannot be extracted from the publication as written.

**Priority data request:** If raw colony-level data were obtained from the authors (Karen Neely, kneely0@nova.edu), this study would contribute 508 colonies across 5 FL sub-regions entirely absent from the current dataset, dramatically improving geographic coverage and reducing NOAA dominance (currently 78%). This is the single highest-value data request for improving the meta-analysis.

---

## 3. Independence Verification for Included Studies

### 3.1 Rogers & Muller 2012 (Haulover Bay, USVI)

**Included as:** `rogers_muller_2012` (Tier 2, AI-extracted)

**Independence evidence:**
- **Location:** Haulover Bay, St. John, USVI -- a USGS/NPS Virgin Islands monitoring site, not part of the NOAA Florida-focused program.
- **Colony set:** 69 individually mapped *A. palmata* colonies, each with unique IDs.
- **Time period:** 2003--2009 (7 years).
- **Relationship to Muller et al. 2008:** Different bay. Rogers & Muller 2012 is at Haulover Bay; Muller et al. 2008 is at Hawksnest Bay. The two bays are approximately 4 km apart on St. John. Both papers describe their colony sets explicitly, and there is no mention of shared colonies between the two studies.
- **Relationship to NOAA_survey:** NOAA's Acropora monitoring operates primarily in the Florida Keys, Curacao, and Navassa. The USVI sites are managed by USGS/NPS under a separate program. No overlap.

**Conclusion:** Independent of both Muller et al. 2008 and NOAA_survey. Included.

### 3.2 Roth et al. 2013 (Haulover Bay, USVI) -- EXCLUDED

**Excluded as:** Data overlap with `rogers_muller_2012`

**Overlap evidence:**
- **Location:** Haulover Bay, St. John, USVI -- the same bay and monitoring site as Rogers & Muller 2012.
- **Colony set:** Roth et al. 2013 reports 27 colonies averaged across 5 survey years at Haulover Bay. Rogers & Muller 2012 reports 69 individually mapped colonies at Haulover Bay, 2003--2009.
- **Citation link:** Roth et al. 2013 explicitly cites Rogers & Muller 2012 and acknowledges the same USGS/NPS Haulover Bay monitoring program. The paper's acknowledgments confirm collaboration with the same research group (C.S. Rogers, E.M. Muller) at the same site.
- **Time period overlap:** Roth et al. 2013 covers approximately 2003--2010; Rogers & Muller 2012 covers 2003--2009. The monitoring periods overlap almost entirely.
- **Colony identity:** Both studies describe tagging and photographing individual *A. palmata* colonies at Haulover Bay. The smaller colony count in Roth (27) compared to Rogers & Muller (69) reflects averaging across survey years and size-class binning, not a different colony set.

**Conclusion:** Roth et al. 2013 uses the same Haulover Bay colony dataset as Rogers & Muller 2012. Including both would double-count the same individuals. Rogers & Muller 2012 is retained as the primary source because it provides the full 7-year dataset with explicit colony fates (44/69 survived).

---

### 3.3 Muller et al. 2008 (Hawksnest Bay, USVI) -- EXCLUDED

**Final decision:** EXCLUDED (IRR audit, March 2026)

**Independence assessment:**
- **Location:** Hawksnest Bay, St. John, USVI.
- **Colony set:** 60 individually tagged *A. palmata* colonies.
- **Time period:** 2004--2006 (31 months = 2.583 years). Includes the 2005 mass bleaching event.
- **Relationship to Rogers & Muller 2012:** Different bay (Hawksnest vs. Haulover, 4 km apart). Cross-referencing both publications confirms distinct colony populations. No data overlap.
- **Relationship to NOAA_survey:** USGS/NPS program in USVI, separate from NOAA's Florida/Curacao/Navassa monitoring. No overlap.

**Conclusion:** Geographically independent of all other included studies, but excluded during the IRR audit (see `inter_rater_reliability.md` Section 6) for imprecise survival data (exact death count ambiguous from text: "17% of 60"), absence of colony size data, and bleaching-confounded mortality during the 2005 Caribbean event.

### 3.3 Sutherland et al. 2016 (EDR Historical, Florida Keys) -- EXCLUDED

**Final decision:** EXCLUDED (IRR audit, March 2026)

**Background:** The EDR historical dataset (1994--2004) at Eastern Dry Rocks, Lower Florida Keys, was initially assessed as geographically independent of NOAA_survey (different institution, site, era). However, during the IRR audit (see `inter_rater_reliability.md` Section 6), the independent adjudicator determined that the EDR monitoring used permanent photostations/quadrats rather than individually tagged colonies, violating the longitudinal individual-tracking inclusion criterion. Additionally, the FKNMS contemporary component (2008--2014) overlapped spatially with NOAA monitoring at Carysfort and Molasses reefs.

**Conclusion:** Both components excluded. EDR excluded for photostation design (not individually tagged colonies); FKNMS excluded for NOAA spatial overlap.

---

## 4. Summary of Overlap Decisions

| Study | # Colonies | Decision | Reason |
|-------|-----------|----------|--------|
| NOAA_survey (Williams et al.) | 4,025 | **INCLUDED** (Tier 1) | Primary dataset |
| Williams & Miller 2008 | -- | EXCLUDED (E4) | IS the NOAA dataset |
| Williams & Miller 2012 | -- | EXCLUDED (E4) | IS the NOAA dataset |
| Williams et al. 2024 | -- | EXCLUDED (E4) | Same NOAA colonies |
| Bright et al. 2013 | -- | EXCLUDED (E4) | NOAA tech memo, same data |
| Miller et al. 2009 | -- | EXCLUDED (E4) | NOAA community monitoring overlap |
| Muller et al. 2014 | -- | EXCLUDED (E4) | Same Haulover Bay colonies as Rogers & Muller 2012 |
| Chapron et al. 2023 | -- | EXCLUDED (E4) | Same colonies as Kuffner et al. 2020 |
| Neely et al. 2022 | 508 | EXCLUDED (no extractable data) | **No overlap** (Lower/Middle Keys + Biscayne + Dry Tortugas). Excluded because paper reports LAI only, not survival counts. **Priority data request.** |
| Sutherland et al. 2016 (FKNMS) | 126 | EXCLUDED (E4) | Carysfort/Molasses overlap with NOAA (paper acknowledges p. 11) |
| Sutherland et al. 2016 (EDR) | 92 | EXCLUDED (IRR audit) | Photostation design, not tagged colonies; TKO ambiguity; catastrophic WPX decline |
| Lirman 2003 | -- | EXCLUDED (E4) | Model re-parameterization of Lirman 2000 data |
| Rogers & Muller 2012 | 69 | **INCLUDED** (Tier 2) | Haulover Bay, independent of NOAA and Muller 2008 |
| Roth et al. 2013 | 27 | EXCLUDED (overlap audit) | Same Haulover Bay colony data as Rogers & Muller 2012; confirmed from paper's citation and acknowledgments |
| Muller et al. 2008 | 60 | EXCLUDED (IRR audit) | Independent of NOAA but imprecise survival, no sizes, bleaching-confounded |

---

## 5. Cross-References

- **Screening criteria and exclusion codes:** [`screening_criteria.md`](screening_criteria.md)
- **Extraction protocol (Section 4):** [`../04_extraction/extraction_protocol.md`](../04_extraction/extraction_protocol.md)
- **Full-text screening results:** [`full_text_screening.csv`](full_text_screening.csv)
- **Systematic review protocol:** [`../01_protocol/systematic_review_protocol.md`](../01_protocol/systematic_review_protocol.md)
- **Audit log:** [`../04_extraction/extraction_protocol.md` Section 8](../04_extraction/extraction_protocol.md)

---

*Document prepared: March 2026*
*Ocean Recoveries Lab, UC Santa Barbara*
