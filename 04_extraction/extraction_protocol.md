# Data Methodology Reference

## 1. Literature Search and Study Selection

> **Full systematic review protocol:** See [systematic_review_protocol.md](/Users/adrianstier/Detmer-2025-coral-parameters/01_protocol/systematic_review_protocol.md) for the active PRISMA-style documentation including eligibility criteria, search strategy, screening process, data extraction variables, flow diagram, and risk of bias assessment. Historical gap-resolution notes live in [PRISMA_TODO_resolution.md](/Users/adrianstier/Detmer-2025-coral-parameters/01_protocol/PRISMA_TODO_resolution.md).

### 1.1 Original Search (Detmer, 2025)

The initial literature compilation was conducted by R. Detmer (Jun–Dec 2025) as part of a Restoration Strategy Evaluation (RSE) framework for *Acropora palmata*. The search targeted studies reporting size-dependent vital rates (survival, growth, fragmentation) for *A. palmata* across the Caribbean.

**Search strategy:** Studies were identified through:

1. **Data repository mining:** NOAA NCEI, NOAA InPort, USGS CMGDS, USGS ScienceBase
2. **Bibliographic database search:** Google Scholar, using 5 structured search strings combining `("Acropora palmata" OR "elkhorn coral")` with terms targeting survival, growth, recruitment, restoration, and long-term monitoring (full strings in [systematic_review_protocol.md](/Users/adrianstier/Detmer-2025-coral-parameters/01_protocol/systematic_review_protocol.md))
3. **Citation chaining:** Forward and backward citations from Vardi 2011, Williams & Miller 2012, Lirman 2003
4. **Direct data sharing:** FUNDEMAR (Dominican Republic) provided nursery fragment data

The search was tracked in `coral_parameters_lit_review.gsheet` (Google Drive). Detailed per-study extraction notes, including assumptions, size conversions, and caveats for each dataset, are retained under `04_extraction/raine_working_notes/`.

**Reproducibility note:** Exact database-specific query dates and hit counts per search string were not formally recorded. Those historical gaps are summarized in [PRISMA_TODO_resolution.md](/Users/adrianstier/Detmer-2025-coral-parameters/01_protocol/PRISMA_TODO_resolution.md).

**52 unique studies were evaluated** across three parameter categories (38 survival, 28 growth, 5 reproduction, with overlap), yielding:
- 7 studies with individual-level raw data (Tier 1)
- 9 studies with summary-level data hand-extracted from tables/figures (Tier 2)
- 4 studies excluded (recruits/micro-fragments)
- ~33 studies excluded for other reasons (cross-sectional only, data overlap, wrong species, no demographic data, linear growth only, etc.)

### 1.2 Expanded Search (March 2026)

A comprehensive literature audit was conducted to ensure no extractable *A. palmata* demographic data was missed. This involved:

1. **NotebookLM library** of 137 papers queried for candidate studies
2. **Systematic PDF reading** of ~80 papers in `literature/pdfs/data_studies/`
3. **Parallel triage agents** reviewing 33 papers against explicit criteria (below)
4. **PubMed, Semantic Scholar, and Unpaywall** searches for additional studies
5. **Critical audit** of all extracted data by independent verification

This expanded search, combined with the subsequent inter-rater reliability audit (Section 1.5), overlap audit, NOAA regional split, Garrison & Ward treatment split, and the April 2026 addition of Neely et al. 2022 (direct data sharing), resulted in a final count of k=17 unique studies contributing 22 study-level effects: three new studies were added during the March 2026 expansion (Rogers 1982, Rogers & Muller 2012, Ramos-Romero et al. 2025), two previously included studies were removed during IRR audit (Muller et al. 2008, Sutherland et al. 2016; see Section 1.5), one candidate study (Ramos et al. 2024) was removed after audit due to misinterpretation of partial mortality prevalence as whole-colony survival, Roth et al. 2013 was removed after an exhaustive overlap audit confirmed it uses the same Haulover Bay colony data as Rogers & Muller 2012, NOAA was split into FL Keys/Curacao/Navassa regional effects (3 effects from 1 study, paralleling Vardi 2011's 3 regional effects), Garrison & Ward 2008 was split into 2 treatment-group effects (control = Natural colony, n=45, 80% survival; relocated = Restoration fragment, n=30, 55% survival), and Neely et al. 2022 was added as a Tier 1 individual-level study (878 colonies, FL Keys, natural colonies) after raw data were shared directly by the authors.

### 1.2b Formal Database Searches and Expanded Screening (2026-03-29)

To complete PRISMA-required database search documentation, formal Boolean searches were executed against PubMed (351 unique PMIDs across base + 6 expanded queries) and Web of Science (1,095 records across 3 query sets: base 628, broader *Acropora*+Caribbean 409, threatened coral 58). The expanded PubMed queries added genus-level, MeSH, abbreviated name, ESA, and restoration search terms. The majority of results were already present in the screening list from earlier search phases. Thirteen new papers were identified and screened at full text (6 from PubMed formal search + 7 from expanded search); all were excluded (Manzello et al. 2025, Muller et al. 2025, Birkart & Alvarez-Filip 2025, Wilson & Edmunds 2026, Cramer et al. 2020, Banister et al. 2024, Young et al. 2024, Yuen et al. 2023, Souza et al. 2023, Forrester et al. 2012, Miller & Williams 2015, Hernandez-Delgado et al. 2024, Bak 1983). See `03_screening/screening_criteria.md` Section 8 for details.

Total records identified across all databases: ~2,518 (PubMed 351 + WoS 1,095 + Elicit 298 + citation chaining 381 + Google Scholar ~150 + bioRxiv/EuropePMC 23 + data repositories 5). Scopus was not accessible and is documented as a limitation. Estimated unique after deduplication: ~1,200--1,400.

**Conclusion:** No additional extractable studies exist beyond the 17 already included in the meta-analysis (the 16th was added via the March 2026 search; the 17th, Neely et al. 2022, was added in April 2026 via direct data sharing after outreach to the authors). The formal database searches confirm the completeness of the original search strategy (Google Scholar + citation chaining + data repositories + expanded search).

### 1.3 Expanded Data Extraction Method

Data from the expanded search studies were extracted by reading source PDFs directly. The process was **manual interpretation, not automated extraction**:

1. **PDF reading**: Each page was read for text, tables, and figures.

2. **Text and table extraction**: Quantitative values stated in the paper text (e.g., "25 of 69 colonies died") or in formatted tables (e.g., Table 2 survival probabilities) were transcribed directly. These are generally reliable.

3. **Figure reading**: For data reported only in figures (e.g., bar charts of annual mortality, line plots of prevalence over time), values were **visually estimated from the figure image**. This is inherently imprecise, introducing reading error of ±1–5% depending on axis resolution and figure quality. No digitization software (e.g., WebPlotDigitizer) was used.

4. **Arithmetic**: Unit conversions (diameter → area: `π(d/2)²`), annualization (`surv^(1/t)`), and averaging were computed during extraction. These are verifiable but were found to contain occasional arithmetic errors (e.g., 0.75^(1/2.67) stated as 0.892 when the correct value is 0.898).

5. **Interpretation**: Deciding what a paper's reported metric means for demographic analysis requires judgment. This is where the most consequential errors occurred — specifically, interpreting "recent mortality prevalence" (a partial tissue loss metric) as "whole-colony mortality rate" (Ramos et al. 2024). This conceptual error was caught by the audit.

**Known limitations of this approach:**
- Figure-derived values are approximate (±1–5%), not precise digitizations
- Conceptual interpretation errors are possible when a paper's metric does not map cleanly onto the pipeline's definition of survival
- Arithmetic annotations in CSV notes occasionally contain errors, though the pipeline recomputes all values from the stored raw inputs

**Mitigation:** Every expanded-search extracted value was independently verified by re-reading the source PDF and comparing each extracted number against the paper. The audit caught errors in 3 of 5 studies (see Section 8). Values that flow into the analysis pipeline are recomputed from stored `prop_survived` and `time_interval_yr` by the R script, so annotation errors in CSV notes do not propagate.

**Comparison to hand extraction:** Detmer's hand-extracted data (Tier 2, 9 studies) followed the same basic process — reading papers and transcribing values — but with domain expertise that reduces conceptual interpretation errors. The expanded extraction extends this to papers Detmer did not process, at the cost of requiring a verification step.

### 1.4 Extraction Verification

All 9 hand-extracted Tier 2 studies were verified against source PDFs by an independent reviewer. Results:

| Verification category | Studies | Outcome |
|-----------------------|---------|---------|
| **Tabulated data — exact match** | Rosales et al. 2024, Forrester et al. 2013, Ortiz Prosper 2005, Maurer et al. 2022 | All extracted values matched published tables exactly |
| **Figure-estimated data — internally consistent** | Garrison & Ward 2008, Williams & Miller 2010, Bruckner & Bruckner 2001 | Figure-derived values are approximate (±1–5%) but internally consistent with the source figures |
| **Dissertation data — verified** | Vardi 2011 (20 rows, 3 regions: Jamaica, Puerto Rico, Virgin Gorda) | All values verified correct against dissertation Tables 4-1, 4-2, and 4-A3 |

**Zero extraction errors were found** across all hand-extracted studies.

**NOAA pipeline filtering:** The NOAA individual-level dataset (Tier 1) applies a size-based quality filter that removes 80 records with zero live tissue area. This shifts the NOAA study-level survival estimate from 86.0% (raw) to 87.1% (filtered). This is a data-cleaning decision, not an extraction error, and is documented in the pipeline code.

### 1.5 Inter-Rater Reliability

To assess screening reliability and reduce single-rater bias, 31 candidate papers identified during the expanded search were subjected to dual screening.

**Protocol:**
1. Two independent reviewers each screened all 31 papers against the inclusion criteria in Section 2
2. Screening decisions (include/exclude with rationale) were recorded independently
3. All disagreements were adjudicated by an independent third review

**Agreement statistics:**
- Raw agreement: 71% (22/31 papers)
- Cohen's kappa: −0.148
- The negative kappa reflects the **kappa paradox**: both raters excluded the large majority of papers, producing highly skewed marginal distributions where chance agreement is already high and kappa becomes unreliable as a measure of agreement quality

**Disagreement adjudication:** Nine disagreements were resolved by independent third review. The adjudication resulted in:

| Change | Study | Reason |
|--------|-------|--------|
| **Removed** | Muller et al. 2008 | Imprecise survival data (exact death counts ambiguous from text), no colony sizes reported, bleaching-confounded mortality during 2005 event |
| **Removed** | Sutherland et al. 2016 | Contemporary survey component overlaps NOAA monitoring; EDR historical dataset (1994–2004) tracked permanent photostations/quadrats rather than individually tagged colonies, violating the longitudinal individual-tracking criterion |
| **Added** | Rogers 1982 | 173 individually labeled storm-damaged branches tracked for 11 months at 2 St. Croix sites (Buck Island: 66% survival; Tague Bay: 35% survival); meets all inclusion criteria |

**Consensus excludes retained:** 22 papers excluded by both raters remained excluded after adjudication.

**Net effect on meta-analysis:** k changed from 20 to 18 (via IRR audit to k=19, then overlap audit removing Roth et al. 2013 to k=18), then NOAA was split by region (FL Keys, Curacao, Navassa) and Garrison & Ward 2008 was split into control (Natural, n=45, 80% survival) and relocated (Restoration, n=30, 55% survival) treatment-group effects, yielding 16 unique studies contributing 21 study-level effects. Subsequently, Neely et al. 2022 was added (April 2026, direct data sharing) as a Tier 1 study with 878 FL Keys natural colonies, bringing the final count to 17 unique studies contributing 22 study-level effects. Pooled annual survival is 78.0% (95% CI: 70.1–84.3%, I² = 96.6%). Natural vs. restoration subgroup composition is 10 natural + 12 restoration effects, with a non-significant difference (p = 0.153).

---

## 2. Inclusion Criteria

A study was included in the meta-analysis if it met ALL of the following:

| Criterion | Requirement |
|-----------|-------------|
| **Species** | *Acropora palmata* (elkhorn coral) only. Studies of *A. cervicornis* or mixed *Acropora* spp. excluded. |
| **Vital rate** | Reports survival (proportion alive/dead) OR areal growth (cm²/yr) OR fragmentation rates |
| **Study design** | Longitudinal — individually tagged or photographically tracked colonies/fragments with known fates over a defined time interval. Cross-sectional snapshots of tissue condition (e.g., partial mortality prevalence) do NOT qualify as survival data. |
| **Sample size** | Known n (number of colonies or fragments tracked). Studies reporting only density or percent cover without individual tracking are excluded. |
| **Time interval** | Defined observation period allowing annualization of survival rates |
| **Size metric** | Colony size reported in planar area (cm²) or convertible to it (L × W × %live, or diameter with assumptions). Studies reporting only volume (cm³) or linear extension (cm/yr) have size set to NA but can still contribute survival data. |
| **Independence** | Data must not overlap with existing studies in the dataset. See Section 3 for overlap rules. |

### 2.1 Additional criteria for Tier 1 (individual-level)

- Raw data available (CSV, XLSX, or published data repository)
- Individual colony identifiers allowing size-specific survival and growth tracking
- Colony size measured at each observation interval

### 2.2 Additional criteria for Tier 2 (summary-level)

- Proportion survived and sample size reported or derivable from tables/figures
- Time interval specified
- Can be a single study-level effect (no individual colony data required)

---

## 3. Exclusion Criteria

| Criterion | Reason | Studies affected |
|-----------|--------|-----------------|
| **Post-settlement recruits** (<1 cm²) | Different life stage; near-zero survival not comparable to juvenile/adult demography | fundemar_recruits, chamberland_2015, mendoza_quiroz_2023 (summary) |
| **Lab/nursery micro-fragments** (<1 cm²) | Artificial conditions; not representative of field demography | papke_2021 |
| **Cross-sectional only** | Tissue condition snapshots (% showing partial mortality) ≠ whole-colony survival rates. Partial mortality prevalence conflates sub-lethal tissue loss with colony death. | Gonzalez-Diaz 2019, Garcia-Uruena 2020, Caballero-Aragon 2019, Zubillaga 2008, Croquer 2016, Rogers 2006 |
| **NOAA/USGS data overlap** | Same colonies, sites, and/or monitoring program as existing NOAA_survey individual-level data | Bright 2013, Williams & Miller 2012, Muller 2014, Miller 2009, Sutherland 2016 FKNMS component, Chapron 2023 (= Kuffner 2020 colonies) |
| **Imprecise/confounded data** | Survival data too imprecise for meta-analysis, or confounded by acute event | Muller et al. 2008 (exact death count ambiguous, no colony sizes, 2005 bleaching-confounded) |
| **Not individually tracked** | Monitoring units are photostations/quadrats, not individually tagged colonies | Sutherland et al. 2016 EDR component (permanent photostations 1994–2004) |
| **Wrong species** | Not *A. palmata* | Tunnicliffe 1981 (*A. cervicornis*), Bythell 1993 chronic (*M. annularis*), Rylaarsdam 1983 (*A. cervicornis* zone) |
| **No demographic data** | Paper reports genetics, physiology, spawning, or disease etiology without survival/growth outcomes | Williams 2023 (spawning), Thornhill 2011 (biomass physiology), Idjadi 2007 (*A. cervicornis* focus) |
| **Invalid survival proxy** | Recent mortality (RM) prevalence measures the fraction of colonies showing ANY recent tissue loss, not whole-colony death. A colony with RM is still alive. | Ramos et al. 2024 — initially included, removed after audit (see Section 8) |

---

## 4. Data Overlap Decision Rules

Because multiple studies from the same monitoring programs exist, the following rules prevent double-counting:

1. **NOAA Acropora Demographic Monitoring Program** (Williams, Miller, Bright; NOAA SEFSC): Individual-level data from this program is included once as `NOAA_survey`. Papers analyzing subsets of this data (Williams & Miller 2012, Bright 2013, Miller 2009) are excluded as independent studies.

2. **USGS/NPS St. John Monitoring** (Rogers, Muller, Roth): Rogers & Muller 2012 (Haulover Bay, 69 colonies, 2003–2009) is included. Muller et al. 2008 (Hawksnest Bay, 60 colonies, 2004–2006) was initially included as an independent dataset (4 km apart, different colony sets) but was removed during the IRR audit (Section 1.5) due to imprecise survival data, absence of colony sizes, and bleaching-confounded mortality. Roth et al. 2013 (Haulover Bay, 27 colonies averaged across 5 survey years) was removed after an exhaustive overlap audit confirmed it uses the same Haulover Bay colony data as Rogers & Muller 2012, as evidenced by the paper's explicit citation and acknowledgments.

3. **Kuffner et al. 2020 and Chapron et al. 2023**: Chapron explicitly sampled "the surviving corals from Kuffner et al." Only Kuffner is included.

4. **Sutherland et al. 2016**: Excluded during the IRR audit (Section 1.5). The contemporary survey component (FKNMS, 2008–2014) overlapped spatially with NOAA monitoring. The EDR historical dataset (1994–2004, Lower Keys) tracked permanent photostations/quadrats rather than individually tagged colonies, violating the longitudinal individual-tracking inclusion criterion.

5. **Neely et al. 2022**: 878 colonies at 9 FL Keys sites. Detailed site comparison reveals **no geographic overlap** with NOAA monitoring (see `03_screening/overlap_analysis.md` Section 2.5 for site-by-site verification). Originally excluded because the published paper reports LAI trajectories and stressor prevalence, not whole-colony survival counts. **Now included (April 2026):** raw colony-level data were shared directly by K. Neely. See `04_extraction/neely_2022_data_integration.md` for full integration notes.

---

## 5. Individual-Level Data Sources (Tier 1)

| Study | Source | n | Region | Data Type | Raw Data |
|-------|--------|---|--------|-----------|----------|
| NOAA_survey | NOAA NCEI 0142175 | 4,025 | FL Keys, Curacao, Navassa | field | `NOAA_Tagged_Colony_Data.csv` |
| pausch_et_al_2018 | NOAA InPort 26790 | 789 | FL Keys | nursery_in | `Pausch_2018_Data_Table_*.csv` |
| kuffner_et_al_2020 | USGS Data Release | 106 | FL Keys | field | `Kuffner_et_al_2020_*.csv` |
| USGS_USVI_exp | USGS CMGDS | 92 | USVI | field | `USGS_Palmata_growth_VI_USA.csv` |
| fundemar_fragments | Fundemar (shared) | 156 | Dominican Republic | nursery_in | `Fundemar_*.xlsx` |
| mendoza_quiroz_2023 | PeerJ 15813 | 52 | Mexican Caribbean | nursery_in/field | `MendozaQuiroz2023Data.xlsx` |
| neely_et_al_2022 | Direct sharing (Apr 2026) | 878 | FL Keys | field | `neely_apal_data.csv` |

**Note on sample sizes:** The n column shows colony-intervals after quality filtering (matching the values used in analysis). Raw CSV row counts may be higher before removing missing sizes, sub-annual intervals, or duplicate colony-years.

---

## 6. Summary-Level Data Sources (Tier 2) — Hand-Extracted

| Study | Region | Type | n | Survival | Extractor | Source |
|-------|--------|------|---|----------|-----------|--------|
| vardi_2011 (3 regions) | Jamaica, PR, Virgin Gorda | Natural | 245 | 76–96% | Detmer | Dissertation tables |
| bruckner_bruckner_2001 | Puerto Rico | Restoration | 105 | 90.5% | Detmer | Published tables |
| ortiz_prosper_2005 | Puerto Rico | Restoration | 207 | 78.7% | Detmer | Published tables |
| forrester_et_al_2013 | BVI | Restoration | 257 | 53.3% | Detmer | Published tables |
| rosales_et_al_2024 | FL Keys | Restoration | 58 | 79.3% | Detmer | Published tables |
| maurer_et_al_2022 | Bahamas | Restoration | 24 | 95.8% | Detmer | Published tables |
| williams_miller_2010 | FL Keys | Restoration | 18 | 77.8% | Detmer | Published tables |
| garrison_ward_2008 (control) | USVI | Natural | 45 | 80.0% | Detmer | Fig. 4b |
| garrison_ward_2008 (relocated) | USVI | Restoration | 30 | 55.0% | Detmer | Fig. 4b |

---

## 7. Summary-Level Data Sources (Tier 2) — Expanded Search (March 2026)

All expanded-search data tagged with `[EXPANDED]` in study_notes and `data_tier` fields.

| Study | Region | Type | n | Annual Survival | Source | Key Caveats |
|-------|--------|------|---|----------------|--------|-------------|
| rogers_muller_2012 | USVI | Natural | 69 | 94.2% | Paper text: 44/69 survived 7yr | Size in volume (cm³) not area; set to NA |
| ramos_romero_et_al_2025 | Cuba | Restoration | 200 | 70.5% | Table 2 KM survival | Time intervals corrected to full monitoring duration (not last KM event) |
| rogers_et_al_1982 | USVI | Natural | 173 | ~48% | Table 5 | Storm-damaged branches (Hurricanes David/Frederic 1979); annualized from 11-month interval |

### Excluded after audit, IRR review, or overlap audit:

| Study | Reason for exclusion |
|-------|---------------------|
| ramos_et_al_2024 | RM prevalence (partial tissue loss) ≠ whole-colony mortality. Study's own density data (89% decline at PB) contradicts the 92% "survival" derived from RM proxy. n=246 is fictional (density × area, not tracked cohort). |
| muller_et_al_2008 | Removed during IRR audit (Section 1.5). Imprecise survival data (exact death count ambiguous from text: "17% ≈ 10 of 60"), no colony sizes reported, bleaching-confounded mortality during 2005 Caribbean event. |
| sutherland_et_al_2016 | Removed during IRR audit (Section 1.5). Contemporary FKNMS component overlaps NOAA monitoring. EDR historical dataset (1994–2004) tracked permanent photostations/quadrats rather than individually tagged colonies. |
| roth_et_al_2013 | Removed during overlap audit. Uses the same Haulover Bay (St. John, USVI) colony data as Rogers & Muller 2012, confirmed from the paper's explicit citation and acknowledgments. Rogers & Muller 2012 retained as the primary source. |

---

## 8. Audit Log (March 2026)

All expanded-search extracted data underwent independent verification by re-reading the source PDFs and comparing every extracted value against the paper. Key findings:

| Study | Audit Result | Issues Found |
|-------|-------------|--------------|
| Rogers & Muller 2012 | PASS | 2003 Fig 7 mortality read wrong (13% should be ~7%); not used in meta. Fragment survival (44%) is 6-month threshold, not cumulative. |
| Ramos et al. 2024 | **FAIL — REMOVED** | RM prevalence proxy fundamentally flawed (see Section 3). RG coordinates were wrong by 25 km. n=246 fictional. |
| Ramos-Romero et al. 2025 | PASS after corrections | Time intervals for 3/4 sites corrected from last KM event (232–347d) to full monitoring duration (423–453d). Study-level survival changed 61.0% → 70.5%. |
| Muller et al. 2008 | **REMOVED (IRR audit)** | Data extraction passed (time interval corrected 2.67 → 2.583yr), but study removed during IRR audit for imprecise survival data, absent colony sizes, and bleaching confounding. See Section 1.5. |
| Sutherland et al. 2016 | **REMOVED (IRR audit)** | Data extraction passed (all values verified), but study removed during IRR audit because EDR tracked photostations not tagged colonies. See Section 1.5. |

### Systemic issue: Integer rounding

The pipeline's `round(survival_rate × n_total)` → `n_survived / n_total` pattern introduces discretization error bounded by ±1/(2n). Worst cases: williams_miller_2010 (n=18, ±2.8pp), vardi_virgin_gorda (n=27, ±1.9pp). This is inherent to the PLO effect size computation requiring integer counts and is within confidence intervals for all studies.

---

## 9. Size Standardization

All sizes converted to **live planar tissue area (cm²)**:

```
size_live_cm2 = Length × Width × (%Live / 100)
```

| Measurement type | Conversion |
|-----------------|------------|
| L × W × %live (NOAA, Pausch) | Direct |
| Photo tracing (Kuffner, USGS) | Direct planar area |
| Diameter only (Mendoza-Quiroz nursery/Cuevones) | d² × W:L ratio (W:L estimated from Picudas reef data with both L and W measurements) |
| Volume cm³ (Rogers & Muller 2012) | Set to NA; survival data used without size |
| Linear extension cm/yr (Gladfelter) | Not convertible; excluded from pipeline |

---

## 10. Annualization

Non-annual survival rates annualized assuming constant hazard:

```
surv_annual = surv_raw^(1/time_interval_yr)
```

For Kaplan-Meier survival estimates, `time_interval_yr` is the **full monitoring duration** (not the time of the last mortality event), because KM survival is sustained through the censoring period.

---

## 11. File Inventory

### Curated by Detmer (hand-extracted):
- `05_data/standardized/apal_surv_ind.csv` — 7,842 individual survival records in the current standardized table
- `05_data/standardized/apal_growth_ind.csv` — 6,318 individual growth records in the current standardized table
- `05_data/standardized/apal_surv_summ.csv` — 332 summary survival rows
- `05_data/standardized/apal_growth_summ.csv` — 15 summary growth rows
- `05_data/standardized/apal_fragmentation.csv` — 13 fragmentation rows (Vardi 2011)

### Added by expanded search extraction (March 2026):
- `05_data/standardized/apal_surv_summ.csv` rows 321–330 — 10 new summary survival rows tagged [EXPANDED]
- `05_data/expanded_search/` — Extraction audit trail

### Processing:
- `05_data/integration/APAL_data_integration.rmd` — Original data standardization pipeline
- `06_analysis/scripts/14b_expanded_meta_analysis.R` — Meta-analysis with expanded Tier 2 processing blocks

### Search and extraction documentation:
- `01_protocol/systematic_review_protocol.md` — Full PRISMA-style systematic review protocol with search strings, screening process, flow diagram, and risk of bias assessment
- `04_extraction/raine_working_notes/` — Raine Detmer's original working notes and supporting materials with per-study extraction decisions, assumptions, and caveats
- `literature/summaries/*.txt` — 17 per-study summary files documenting key findings and extraction notes

---

---

## Related Files

- [extraction_details.md](extraction_details.md) -- Per-study verification table with audit status
- [study_characteristics.md](study_characteristics.md) -- PRISMA-style study characteristics table
- [data_integration_issues.md](data_integration_issues.md) -- Individual + summary data combination method
- [data_flow_diagram.md](data_flow_diagram.md) -- Mermaid diagram of the full data pipeline
- [risk_of_bias.md](risk_of_bias.md) -- Newcastle-Ottawa bias assessment per study
- [disturbance_handling_decision.md](disturbance_handling_decision.md) -- Disturbance classification and inclusion rules
- [neely_2022_data_integration.md](neely_2022_data_integration.md) -- Neely et al. 2022 integration notes
- `raine_working_notes/` -- Original per-study extraction decisions

---

*Document prepared by: Raine Detmer & Adrian Stier*
*Ocean Recoveries Lab, UC Santa Barbara*
*Original: December 2025 | Updated: April 2026 (added Neely, Rogers 1982, sample size note, fragmentation split rule)*
