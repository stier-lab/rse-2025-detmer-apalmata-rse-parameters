# Screening Criteria: Size-Dependent Demography of *Acropora palmata*

**Version:** 1.0
**Date:** March 2026
**Authors:** Raine Detmer, Adrian Stier
**Affiliation:** Ocean Recoveries Lab, UC Santa Barbara

---

## 1. PICO Framework

This systematic data compilation adapts the PICO framework to a vital rate synthesis (not a treatment-effect review).

| Element | Definition |
|---------|-----------|
| **Population** | *Acropora palmata* (elkhorn coral) colonies and fragments in Caribbean reef environments. Excludes other *Acropora* species (*A. cervicornis*, *A. prolifera*) unless *A. palmata*-specific data are reported separately. |
| **Intervention / Exposure** | Colony size (live planar tissue area, cm^2) and time (longitudinal tracking over defined intervals). Both natural and restored populations are eligible. |
| **Comparison** | Size classes (SC1: 0--10 cm^2, SC2: 10--100 cm^2, SC3: 100--900 cm^2, SC4: 900--4000 cm^2, SC5: >4000 cm^2). Secondary comparisons: natural vs. restoration populations, Caribbean regions, monitoring periods. |
| **Outcome** | Whole-colony survival rate (proportion alive after a defined interval), areal growth rate (change in live planar tissue area, cm^2/yr), and/or fragmentation rate (colony breakage producing viable fragments). |

---

## 2. Inclusion Criteria

A study was included if it met **all** of the following:

- **Species:** *Acropora palmata* only. Studies must report *A. palmata*-specific demographic data; mixed-species results are excluded unless *A. palmata* values are reported separately.

- **Study design:** Longitudinal -- individually tagged, photographically tracked, or GPS-mapped colonies/fragments with known fates over a defined observation period. Both natural monitoring and restoration experiments are eligible.

- **Outcome measures:** Reports at least one of:
  - Whole-colony survival (proportion of tracked colonies alive at interval end, where death = no remaining live tissue or skeleton gone)
  - Areal growth (change in live planar tissue area, cm^2/yr, or convertible to it from L x W x %live at two time points)
  - Fragmentation rate (colony breakage producing viable fragments, with fragment sizes and fates if available)

- **Sample size:** Known n (number of individually tracked colonies or fragments). Studies reporting only density, percent cover, or population-level metrics without individual tracking are excluded.

- **Time interval:** Defined observation period allowing annualization of survival rates (i.e., start and end dates, or monitoring duration, must be specified or derivable).

- **Size metric:** Colony size reported in planar area (cm^2) or convertible to it (L x W x %live, diameter with circular assumption, photo tracing). Studies reporting only volume (cm^3) or linear extension (cm/yr) may still contribute survival data if size is set to NA.

- **Independence:** Data must not overlap with an existing study already in the dataset. See [`overlap_analysis.md`](overlap_analysis.md) for the full adjudication.

- **Geographic scope:** Caribbean basin (the native range of *A. palmata*). No geographic restriction within the Caribbean.

- **No restrictions on:**
  - Publication date
  - Language (all identified studies were in English or Spanish)
  - Publication type (peer-reviewed journals, dissertations, government reports, data repositories, personal communications)
  - Population type (natural or restored)

### 2.1 Tier 1 (Individual-Level) Additional Criteria

- Raw data available (CSV, XLSX, or published data repository)
- Individual colony identifiers allowing size-specific survival and growth tracking
- Colony size measured at each observation interval

### 2.2 Tier 2 (Summary-Level) Additional Criteria

- Proportion survived and sample size reported or derivable from tables/figures
- Time interval specified
- Single study-level effect acceptable (no individual colony data required)

---

## 3. Exclusion Criteria

| Code | Criterion | Definition | Example Studies Excluded |
|------|-----------|-----------|--------------------------|
| **E1** | Wrong species | Not *A. palmata*. Studies of *A. cervicornis*, *A. prolifera*, *Diploria*, *Orbicella*, *Siderastrea*, or other species. | Tunnicliffe 1981, Becker & Mueller 2001, Bythell et al. 1993 (chronic), Knowlton et al. 1981, Griffin et al. 2015, Ladd et al. 2016, Ladd et al. 2024, Marhaver et al. 2013, Edmunds 2010, Page et al. 2018, Steinberg 2021, Vermeij & Sandin 2008, Rylaarsdam 1983, Idjadi et al. 2007, Knowlton et al. 1990 |
| **E2** | Cross-sectional only | Single time-point surveys of colony condition, tissue condition snapshots, or partial mortality prevalence assessments. These conflate sub-lethal tissue loss with whole-colony death and do not track individual fates over time. | Gonzalez-Diaz et al. 2019, Garcia-Uruena et al. 2020, Croquer et al. 2016, Rogers et al. 2006, Horta-Puga et al. 2014, Rodriguez-Martinez et al. 2014, Zubillaga 2008 |
| **E3** | No extractable survival/growth | Paper reports genetics, physiology, spawning, disease etiology, or ecological interactions without survival or growth outcomes. Also applies to studies where survival/growth data cannot be extracted (e.g., only Bayesian posterior distributions with strong priors, only density-based estimates, insufficient detail). | Williams et al. 2023, Thornhill et al. 2011, Baums et al. 2006, Irwin et al. 2017, Japaud et al. 2015, Porto-Hannes et al. 2015, Bythell et al. 1993 (Hugo), Chen et al. 2020 |
| **E4** | NOAA data overlap | Same colonies, sites, and/or monitoring program as the NOAA Acropora Demographic Monitoring dataset already included as `NOAA_survey`. Also applies to overlapping USGS/NPS monitoring. | Williams & Miller 2008, Williams & Miller 2012, Bright et al. 2013, Miller et al. 2009, Muller et al. 2014, Neely et al. 2022, Williams et al. 2024, Chapron et al. 2023 (= Kuffner 2020 colonies), Lirman 2003 (= Lirman 2000 data) |
| **E5** | Recruits only (<1 cm^2) | Studies tracking post-settlement recruits or micro-fragments below 1 cm^2. Different life stage with near-zero survival not comparable to juvenile/adult demography. | Chamberland et al. 2015, fundemar_recruits, Mendoza-Quiroz et al. 2023 (summary component) |
| **E6** | Settlement/recruitment only | Studies of larval settlement, substrate attachment, or fragment cementation without subsequent survival/growth tracking of established colonies. | Albright et al. 2010, Fong & Lirman 1995, Williams et al. 2008 |
| **E7** | Lab only | Exclusively laboratory or aquarium experiments with observation periods too short (<1 week) or conditions too artificial to represent field demography. | Papke et al. 2021 (lab micro-fragments), Olsen et al. 2016 (48h in situ chamber), Randall & Szmant 2009 (160h lab), Erwin & Szmant 2010 (36d tiles), Ritson-Williams et al. 2010 (6 weeks) |
| **E8** | Linear growth only | Studies reporting only linear extension (mm/yr or cm/yr) of branches without areal measurements convertible to planar tissue area. | Gladfelter et al. 1978, Gladfelter 1982, Pinon-Gonzalez & Banaszak 2018 (branch-tip cm^2/day) |
| **E9** | Invalid mortality proxy | "Recent mortality" (RM) prevalence measures the fraction of colonies showing ANY recent tissue loss, not whole-colony death. A colony with RM is still alive. Using RM prevalence as a survival rate systematically overestimates survival. | Ramos et al. 2024 (initially included, removed after audit) |
| **E10** | Fragment dynamics only | Studies reporting only fragment production, dispersal, or short-term fragment survival (<6 months) without annual demographic tracking. Fragment data were extracted to a separate fragmentation file where applicable. | Highsmith et al. 1980, Forrester et al. 2011 |

**Note on Rogers et al. 1982:** This study was originally classified under E10 (fragment dynamics only) but was reclassified as INCLUDED after re-evaluation during the IRR audit (March 2026). The study tracked 173 individually labeled storm-damaged branches at 2 St. Croix sites for ~11 months post-Hurricane David (1979), providing extractable annual survival data comparable to existing fragment survival studies in the meta-analysis.

### 3.1 Exclusion Codes Not Used but Considered

- **Data quality:** No study was excluded solely for low sample size, though small-n studies receive wider confidence intervals in the meta-analysis.
- **Publication bias:** No study was excluded for being grey literature, a dissertation, or a data repository. All publication types were eligible.

---

## 4. Size Measurement Standardization

All colony sizes were standardized to **live planar tissue area (cm^2)**. The following conversion rules were applied:

| Original Metric | Studies Using It | Conversion Method |
|----------------|-----------------|-------------------|
| L x W x %live tissue | NOAA_survey, pausch_et_al_2018 | Direct: `size_live_cm2 = Length x Width x (%Live / 100)` |
| Photo tracing (planar area) | kuffner_et_al_2020, USGS_USVI_exp | Direct: planar area from traced photo outlines |
| Maximum diameter only | mendoza_quiroz_et_al_2023 | Circular assumption: `size_live_cm2 = pi x (d/2)^2` |
| Volume (cm^3) | rogers_muller_2012 | Not convertible without morphological assumptions. Size set to `NA`; survival data used without size stratification. |
| Linear extension (cm/yr) | Gladfelter et al. 1978 | Not convertible to planar area. Study excluded from growth analysis (E8). |
| Surface area of live tissue | forrester_et_al_2013 | Used as reported (surface area approximates planar area for plating morphology). |
| Fragment dimensions (L x W) | fundemar_fragments, williams_miller_2010 | Direct: `size_live_cm2 = L x W` (fragments assumed 100% live tissue). |

### 4.1 Caveats

- **L x W overestimates planar area** for non-rectangular colonies. The NOAA %live correction partially compensates, but the bounding-box product inherently overestimates area for irregularly shaped colonies.
- **Circular assumption for diameter** (Mendoza-Quiroz et al. 2023) overestimates area for non-circular colonies but provides a reasonable approximation given the branching plate morphology of *A. palmata*.
- **Pooled analyses assume comparability** across measurement methods. This heterogeneity in size measurement is acknowledged as a source of noise but is unlikely to systematically bias survival or growth estimates in one direction.

---

## 5. Decision Rules for Edge Cases

### 5.1 Studies with both natural and outplanted data

Include both components as long as each meets inclusion criteria independently. Assign separate `population_type` labels (Natural vs. Restoration). Example: Mendoza-Quiroz et al. 2023 tracked both nursery-reared and wild colonies; both components are included.

### 5.2 Studies spanning multiple regions

If a study reports data from geographically distinct regions (>100 km apart or different island groups), each region may be treated as an independent effect in the meta-analysis. Example: Vardi 2011 reports data from Jamaica, Puerto Rico, and Virgin Gorda as three independent regional effects.

### 5.3 Studies with overlapping time periods but different sites

Include both if they track different colony sets at different locations, even within the same monitoring program. Independence must be verified by cross-referencing colony IDs, site names, or GPS coordinates. Example: Rogers & Muller 2012 (Haulover Bay) and Muller et al. 2008 (Hawksnest Bay) -- 4 km apart, different colonies, initially both assessed as independent. (Note: Muller et al. 2008 was later excluded during IRR audit for imprecise survival data, absent colony sizes, and bleaching-confounded mortality; see `overlap_analysis.md`.)

### 5.4 Studies with partial NOAA overlap

If a study uses some NOAA monitoring sites but also includes independent sites, only the non-overlapping component is assessed for inclusion. Example: Sutherland et al. 2016 -- the FKNMS contemporary component (2008--2014, Carysfort/Molasses reefs) was excluded due to spatial overlap with NOAA. The EDR historical dataset (Lower Keys, 1994--2004) was initially assessed as independent but was subsequently excluded during IRR audit because the EDR monitoring used permanent photostations rather than individually tagged colonies (see `overlap_analysis.md` Section 3.3).

### 5.5 Disease/disturbance events

Studies covering disease outbreaks (e.g., white pox) or bleaching events are not excluded on the basis of the disturbance event alone. The survival rate during the event period is a valid demographic parameter. Example: Garrison & Ward 2008 spans a 5-year period including multiple hurricane/disease events. (Note: Sutherland et al. 2016 and Muller et al. 2008, which also covered disease/bleaching periods, were excluded for other reasons -- photostation design and imprecise survival data, respectively -- not because of the disturbance events.)

### 5.6 Short observation periods

Studies with observation periods <6 months are generally excluded (E7/E10) unless they can be annualized and represent field conditions. The minimum acceptable interval for annualization is approximately 6 months. Example: Williams & Miller 2010 (44 weeks, approximately 10 months) is included; Miller 2014 (6--9 weeks) is excluded.

### 5.7 Figure-derived vs. text-derived values

Values read from figures are accepted but flagged as lower confidence than values stated in text or tables. Figure-derived values carry an estimated imprecision of +/-1--5% depending on axis resolution and figure quality. No digitization software was used; all values were visually estimated.

### 5.8 Mortality definition discrepancies

Different studies define "death" differently:
- NOAA: no tissue remaining and/or skeleton gone
- Kuffner et al. 2020: >=50% tissue loss
- Others: no live tissue at interval end

These definitions are recorded in `mortality_definition` for each study. The meta-analysis pools across definitions, which may introduce heterogeneity. The Kuffner definition is the most conservative (classifying colonies as dead that other studies would count as alive).

---

## 6. Cross-References

- **Overlap adjudication:** [`overlap_analysis.md`](overlap_analysis.md)
- **Extraction protocol:** [`../04_extraction/extraction_protocol.md`](../04_extraction/extraction_protocol.md)
- **Systematic review protocol:** [`../01_protocol/systematic_review_protocol.md`](../01_protocol/systematic_review_protocol.md)
- **Full-text screening results:** [`full_text_screening.csv`](full_text_screening.csv)

---

## Extraction Verification

All hand-extracted values were verified against source PDFs during an inter-rater reliability (IRR) audit conducted in March 2026.

**Exact match to tabulated data (4 studies):** Rosales et al. 2024 (Table S3 + GitHub), Forrester et al. 2013 (Tables 1 and 2), Ortiz Prosper 2005 (matrix tables + Fig. 3.4), and Maurer et al. 2022 (published supplementary tables). Extracted values matched source tables exactly with no discrepancies.

**Figure-estimated values -- internally consistent, documented judgment calls (3 included studies):** Garrison & Ward 2008 (Fig. 4b + text), Williams & Miller 2010 (published tables), and Bruckner & Bruckner 2001 (Fig. 3 histogram). These studies required visual estimation from figures. Extracted values were internally consistent with reported text descriptions and fell within the expected imprecision range for figure-derived data (+/-1--5%). Note: Roth et al. 2013 (Fig. 5 histograms) was also figure-estimated and internally consistent, but was subsequently excluded due to data overlap with Rogers & Muller 2012.

**Vardi 2011 (20 rows across 3 regions):** All values verified correct against dissertation tables (Figs. 4-2, 4-3). Jamaica (n=88), Puerto Rico (n=130), and Virgin Gorda (n=27) survival rates and size-class breakdowns matched source data exactly.

**AI-extracted studies (4 studies):** Rogers & Muller 2012, Ramos Romero et al. 2025, Muller et al. 2008, and Sutherland et al. 2016 were independently audited by a separate AI agent that re-read each source PDF and compared every extracted number. Three of four required minor corrections during initial audit (documented in extraction details). The fifth AI-extracted study, Ramos et al. 2024, was removed entirely due to a fundamental conceptual error (recent mortality prevalence misinterpreted as whole-colony survival).

**Zero extraction errors found across all included studies** after corrections were applied.

---

## 8. Formal Database Search Screening (2026-03-29)

To complete the PRISMA-required database search documentation, formal Boolean searches were executed against PubMed and Web of Science on 2026-03-29.

### 8.1 PubMed Results

Five Boolean queries (combining `"Acropora palmata"` OR `"elkhorn coral"` with terms targeting survival, growth, restoration, demography, and population dynamics) returned **63 unique PMIDs**. Of these, approximately 57 were already present in the screening list (from the original Detmer 2025 search or the AI expansion March 2026). Six papers were identified as new and screened at full text. **All 6 were excluded.**

### 8.2 Web of Science Results

The same five query structures were run in Web of Science, returning 207/216/154/78/116 hits across the five queries. WoS provided broader coverage than PubMed but saturation was confirmed independently by Elicit, which recovered all 16 published included studies in the meta-analysis.

### 8.3 Outcome

The formal database searches identified **zero new includable studies**, validating the completeness of the original search strategy (Google Scholar + citation chaining + data repositories + AI-assisted expanded search).

### 8.4 Six Newly Screened Papers

| Study | PMID | Exclusion Code | Reason |
|-------|------|----------------|--------|
| Manzello et al. 2025 | 41129628 | E4 | Data overlap -- compiles 52,356 colonies from NOAA + CRF + Mote + USGS programs already included; combined *Acropora* spp. (*palmata* + *cervicornis* not separable); acute 2023 heatwave event |
| Muller et al. 2025 | 41273189 | E8 + E4 | Review/synthesis of 20-year FL *Acropora* restoration programs; data from NOAA + CRF + Mote already included; no new primary demographic data |
| Birkart & Alvarez-Filip 2025 | 41210959 | E2 | Cross-sectional drone aerial imagery assessment of reef-scale mortality; no individual colony tracking; 100% mortality at Puerto Morelos from 2023 heatwave |
| Wilson & Edmunds 2026 | 41454911 | E8 | Review/conceptual paper on coral rarity; multi-species; *A. palmata* mentioned as one example; no primary demographic data |
| Cramer et al. 2020 | 32426458 | E2 + E8 | Historical/paleoecological synthesis; cross-sectional surveys + fossil reef cores; combined *Acropora* spp.; no individual colony tracking |
| Banister et al. 2024 | 38166125 | E2 + E3 | Cross-sectional BRT habitat suitability model; occurrence data not demographic rates; no survival or growth tracking |

### 8.5 Exclusion Code Definitions (Complete Reference)

| Code | Definition |
|------|-----------|
| **E1** | Wrong species (not *A. palmata*) |
| **E2** | Cross-sectional only (no longitudinal tracking of individual colonies) |
| **E3** | No extractable survival or growth data |
| **E4** | Data overlap with an already-included study |
| **E5** | Recruits/microfragments only (<1 cm^2) |
| **E6** | Laboratory only (or settlement/recruitment stage only) |
| **E7** | Incompatible metric (not convertible to planar area or annual survival) |
| **E8** | Review, model, or synthesis paper (no primary demographic data) |
| **E9** | Grey literature / preprint (not used in this review) |
| **E10** | Other (specify in notes) |

---

*Document prepared: March 2026*
*Ocean Recoveries Lab, UC Santa Barbara*
