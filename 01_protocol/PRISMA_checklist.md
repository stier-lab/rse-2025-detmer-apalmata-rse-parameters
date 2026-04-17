# PRISMA 2020 Checklist

**Project:** Size-Dependent Demography of *Acropora palmata* -- Systematic Data Compilation
**Date:** March 2026
**Authors:** Raine Detmer, Adrian Stier
**Affiliation:** Ocean Recoveries Lab, UC Santa Barbara

This checklist maps each PRISMA 2020 item (Page et al. 2021, *BMJ* 372:n71) to the specific file(s) in this repository that address it. Status: **Done** = fully addressed; **Partial** = addressed with gaps or `[TODO]` items remaining; **TODO** = not yet addressed.

> **Note:** This is a systematic vital rate compilation, not a classical treatment-effect systematic review. Several PRISMA items (e.g., GRADE certainty, publication bias tests) are adapted or noted as not applicable. See `01_protocol/systematic_review_protocol.md` Section 8 for a table of deliberate PRISMA deviations.

---

## Section I: Title and Abstract

| # | PRISMA 2020 Item | Section/Location in Repo | Status | Notes |
|---|------------------|--------------------------|--------|-------|
| 1 | **Title:** Identify the report as a systematic review | `README.md` (line 1, line 6) | Done | Title identifies this as a systematic demographic data compilation for *A. palmata*. |
| 2 | **Abstract:** See structured abstract checklist below | `07_reporting/manuscript_methods_draft.md`; manuscript abstract (not yet drafted) | TODO | Abstract not yet written. The Methods draft exists but a standalone structured abstract with the 12 PRISMA abstract items has not been prepared. |

---

## Section II: Introduction

| # | PRISMA 2020 Item | Section/Location in Repo | Status | Notes |
|---|------------------|--------------------------|--------|-------|
| 3 | **Rationale:** Describe the rationale in the context of existing knowledge | `README.md` (Key Results, Design Philosophy); `01_protocol/systematic_review_protocol.md` Section 1 (Objective) | Done | Rationale is that no comprehensive, size-stratified compilation of *A. palmata* vital rates existed; needed for population viability assessment. |
| 4 | **Objectives:** Provide an explicit statement of the questions being addressed, including PICO elements | `01_protocol/systematic_review_protocol.md` Section 1 (Objective) and Section 2 (Eligibility Criteria, specifying Population, Outcomes, Study Design) | Done | Objective clearly stated: compile all survival, growth, and fragmentation data stratified by colony size for a Lefkovitch matrix model. PICO adapted to vital rate compilation context (no Intervention/Comparison per se). |

---

## Section III: Methods

| # | PRISMA 2020 Item | Section/Location in Repo | Status | Notes |
|---|------------------|--------------------------|--------|-------|
| 5 | **Protocol and registration:** Indicate whether a review protocol exists, whether and where it was registered, and provide registration information | `01_protocol/systematic_review_protocol.md` Section 8 (Deviations from Standard PRISMA), Section 9 (Protocol Changes) | Retrospective | This protocol was documented retrospectively in March 2026 during manuscript preparation. The review was **not** prospectively registered in PROSPERO or an equivalent registry. The data search began in June 2025 without a pre-registered protocol, which is typical for vital rate compilations in ecology but should be acknowledged as a limitation. |
| 6 | **Eligibility criteria:** Specify the inclusion and exclusion criteria | `01_protocol/systematic_review_protocol.md` Section 2 (Eligibility Criteria: Population, Outcomes, Study Design, Minimum Data Requirements, Independence); `04_extraction/extraction_protocol.md` Sections 1--3 | Done | Detailed criteria covering species, outcomes (survival/growth/fragmentation), study design (longitudinal with individual tracking), minimum data requirements (two tiers), independence rules, and explicit exclusion categories. |
| 7 | **Information sources:** Describe all information sources searched, with dates | `01_protocol/systematic_review_protocol.md` Section 3 (Information Sources: original search, expanded search, grey literature); `02_search/search_strings.md`; `02_search/search_summary.md` | Partial | **Original search (Jun--Dec 2025):** Google Scholar (5 search strings), NOAA NCEI, NOAA InPort, USGS CMGDS, USGS ScienceBase, forward/backward citation chaining from key studies, direct data sharing (FUNDEMAR). Web of Science and PubMed usage in the original search is unconfirmed. Exact dates and per-query hit counts were not recorded. **Expanded search (Mar 2026):** PDF library (80 papers), NotebookLM (137 papers), PubMed, Semantic Scholar. Exact expanded-search hit counts are approximate. |
| 8 | **Search strategy:** Present the full search strategy for at least one database | `01_protocol/systematic_review_protocol.md` Section 3.1 (5 Google Scholar search strings with exact Boolean terms); `02_search/search_strings.md` (replicated search strings with approximate hit counts from PubMed and Semantic Scholar); `07_reporting/manuscript_methods_draft.md` Section 2.1 (PRISMA-S reporting) | Partial | Five structured search strings are documented with exact terms. Search reporting follows PRISMA-S extension (Rethlefsen et al. 2021). Databases not searched (Scopus, BIOSIS, Zoological Record, ASFA) are acknowledged in the methods. **Remaining gaps:** Google Scholar strings rather than formal database-specific strategies (e.g., PubMed MeSH terms). No PROSPERO-style full electronic search strategy per database. Saturation analysis via Elicit (298 papers, all 16 included studies recovered) provides evidence of search completeness. |
| 9 | **Selection process:** Specify methods used to decide whether a study met inclusion criteria, including how many reviewers screened and any automation | `01_protocol/systematic_review_protocol.md` Section 4 (Screening Process: 4.1 Original, 4.2 Expanded); `03_screening/full_text_screening.csv` (complete screening log with decisions and reasons); `04_extraction/study_characteristics.md` Table 2 (excluded studies with reasons); `03_screening/inter_rater_reliability.md` (IRR assessment) | Done | Two-phase screening documented: (1) Detmer 2025 single-screener title/abstract then full-text, 52 studies evaluated; (2) expanded search, 33 new candidates assessed with independent verification; (3) formal/expanded database search (2026-03-29), 13 additional papers screened. Single-screener limitation acknowledged. Full screening CSV with 104 data rows. Inter-rater reliability (IRR) assessment now documented in `03_screening/inter_rater_reliability.md`. |
| 10 | **Data collection process:** Describe methods for collecting data, including how many reviewers collected data and any automation | `01_protocol/systematic_review_protocol.md` Section 5 (Data Extraction: variables, forms, template); `04_extraction/extraction_protocol.md` Section 1 (extraction method); `04_extraction/extraction_details.md` (per-study extraction verification); `07_reporting/manuscript_methods_draft.md` Section 2.2 | Done | Two-tier system documented. Tier 1: raw data from repositories. Tier 2: hand-extracted by Detmer or extracted from literature with independent verification. No formal dual extraction for hand-extracted data, but extracted data received independent verification. Extraction form template provided retrospectively. Post-audit data verification removed Muller et al. 2008, Sutherland et al. 2016, and Roth et al. 2013 (data overlap with Rogers & Muller 2012); added Rogers et al. 1982 (reclassified). NOAA subsequently split by region (FL Keys/Curacao/Navassa). Garrison & Ward 2008 split into control/relocated (2 treatment-group effects). Final: 17 studies, 22 effects (after April 2026 addition of Neely et al. 2022). |
| 11 | **Data items:** List and define all outcomes and other variables for which data were sought, and any assumptions made | `01_protocol/systematic_review_protocol.md` Section 5.1 (all variables listed: study-level metadata, survival data, size data, growth data); `04_extraction/extraction_protocol.md`; `05_data/standardized/README.md` (column definitions) | Done | Complete variable list with definitions: study_id, citation, region, country, lat/lon, population_type, restoration_method, monitoring_years, time_interval_yr, data_source, n_total, n_survived, prop_survived, surv_annual, mortality_definition, size_live_cm2, size_measurement_method, size_class, growth_cm2_yr, relative_growth_rate. |
| 12 | **Study risk of bias assessment:** Specify methods used for assessing risk of bias of individual studies | `04_extraction/risk_of_bias.md` (adapted Newcastle-Ottawa Scale, 5 domains, scored for all 17 studies); `01_protocol/systematic_review_protocol.md` Section 7 (Risk of Bias and Limitations) | Done | Custom 5-domain risk-of-bias tool (Selection, Measurement, Attrition, Mortality Definition, Temporal Adequacy) scored 0--2 per domain, total /10. All 17 studies scored. Acknowledged that no standard tool exists for vital rate compilations. |
| 13a | **Synthesis methods -- Eligibility:** Describe the criteria for which studies were eligible for each synthesis | `01_protocol/systematic_review_protocol.md` Section 2 (Eligibility Criteria); `07_reporting/manuscript_methods_draft.md` Section 2.1 (Inclusion criteria); `04_extraction/study_characteristics.md` (Tables 1A--1D) | Done | Survival meta-analysis: 17 studies (22 effects) with annualized survival + sample size. Growth analysis: Tier 1 studies only (individual-level). Fragmentation: Vardi 2011 only. |
| 13b | **Synthesis methods -- Data preparation:** Describe any methods required to prepare the data for synthesis | `07_reporting/manuscript_methods_draft.md` Section 2.2 (Size standardization, annualization, extraction); `06_analysis/scripts/01_data_preparation.R` (data prep code); `06_analysis/scripts/utils/00c_analysis_constants.R` (size class definitions) | Done | Size standardization to cm^2, annualization formula, size class assignment, Haldane correction for zero cells, and logit transformation for meta-analysis are documented in methods and implemented in the maintained R scripts. |
| 13c | **Synthesis methods -- Tabulation and graphical methods:** Describe methods for tabulating and displaying results | `06_analysis/scripts/18_fig1_study_landscape.R` through `06_analysis/scripts/39_restoration_subtype_sensitivity.R` (figure and table scripts); `07_reporting/figure_legends.txt`; `07_reporting/final_figure_table_set.md` | Done | 4 main figures plus the retained supplementary figures and tables are documented. Forest plot (Fig 3), nonlinear vital-rate panels (Fig 2), population viability figure (Fig 4), and disturbance/supporting figures are all mapped to scripts. |
| 13d | **Synthesis methods -- Statistical methods:** Describe the statistical synthesis methods | `06_analysis/scripts/14b_expanded_meta_analysis.R` (random-effects meta-analysis with `metafor::rma()`); `06_analysis/scripts/14_meta_analysis.R`; `07_reporting/manuscript_methods_draft.md` Section 2.3; `CLAUDE.md` (Statistical conventions) | Done | Random-effects meta-analysis using proportional log-odds (PLO) with Knapp-Hartung adjustment (`test = "knha"`). Moderator analysis for population type, region, and risk of bias. I^2 and Q statistics reported. |
| 13e | **Synthesis methods -- Sensitivity analyses:** Describe any sensitivity analyses planned | `06_analysis/scripts/16_sensitivity_analysis.R` (LOSO sensitivity, bootstrap lambda); `06_analysis/scripts/15_heterogeneity_analysis.R`; `06_analysis/scripts/10_cross_validation.R`; `06_analysis/scripts/14b_expanded_meta_analysis.R` (RoB sensitivity, classification sensitivity) | Done | Leave-one-study-out (LOSO) sensitivity analysis for meta-analysis and population model. Bootstrap lambda distribution (2000 replicates, hierarchical resampling). Cross-validation of GAMs. Risk-of-bias sensitivity analysis: meta-regression with NOS score as continuous moderator plus exclusion of studies scoring <=5. Classification sensitivity for natural vs restoration assignment of ambiguous studies. |
| 13f | **Synthesis methods -- Reporting biases:** Describe any methods for assessing reporting biases | `01_protocol/systematic_review_protocol.md` Section 7.4 (Publication Bias); `06_analysis/scripts/14b_expanded_meta_analysis.R` (trim-and-fill analysis) | Done | Narrative discussion of publication bias. Trim-and-fill analysis implemented in script 14b (output: `expanded_meta_trimfill.csv`). Formal funnel plot available. Note: publication bias logic differs for vital rate compilations vs. treatment-effect meta-analyses. |
| 14 | **Registration and protocol:** Provide registration information and where protocol can be accessed | `01_protocol/systematic_review_protocol.md` | Retrospective | Protocol documented retrospectively (March 2026) and archived in the repository. Not prospectively registered in PROSPERO or any equivalent registry. |

---

## Section IV: Results

| # | PRISMA 2020 Item | Section/Location in Repo | Status | Notes |
|---|------------------|--------------------------|--------|-------|
| 15 | **Study selection:** Describe results of the search and selection process, with flow diagram | `03_screening/full_text_screening.csv` (104 data rows with decisions); `01_protocol/systematic_review_protocol.md` Section 6 (flow diagram in ASCII + Mermaid); `07_reporting/prisma_flow_diagram.md` (dedicated flow diagram document) | Done | Full screening CSV. ~2,518 total records identified. Flow diagram with counts at each stage (101 assessed at full text, 82 unique excluded with categorized reasons, 22 initially extracted, 4 removed after audit, 17 studies included contributing 22 effects after NOAA regional split, Garrison & Ward treatment split, and addition of Neely et al. 2022). |
| 16 | **Study characteristics:** Present characteristics of each included study | `04_extraction/study_characteristics.md` Tables 1A (Tier 1, 7 studies), 1B (Tier 2 hand, 8 studies), 1C (Tier 2 extracted, 3 studies), 1D (additional contributions); Table 2 (excluded studies by reason, 82 unique); `04_extraction/extraction_details.md` (per-study extraction verification) | Done | Comprehensive tables with study ID, citation, region, population type, design, sample size, outcomes, size metric, time interval, extractor, audit result, and key caveats for all included studies. Excluded studies (82 unique, 86 CSV rows) similarly detailed in Table 2. |
| 17 | **Risk of bias in studies:** Present risk-of-bias assessments for each included study | `04_extraction/risk_of_bias.md` (all 17 studies scored on 5 domains with summary statistics) | Done | All 17 studies scored. Range: 4--10 out of 10. Low risk: 7 studies; Low-Moderate: 4; Moderate: 5; Moderate-High: 1; High: 1. |
| 18 | **Results of individual studies:** Present results of each individual study, including estimates and CIs | `06_analysis/output/expanded_meta_analysis_study_effects.csv` (per-study survival estimates with CIs); `06_analysis/output/expanded_meta_analysis_results.csv` (summary); `06_analysis/output/` (analysis outputs) | Done | Per-study annualized survival with 95% Wilson CIs. Forest plot (Fig 3, Script 20b) shows point estimates and CIs for all 22 study-level effects. |
| 19 | **Results of syntheses:** Present results of each synthesis, including CIs and measures of statistical heterogeneity | `06_analysis/output/expanded_meta_analysis_results.csv`; `07_reporting/manuscript_methods_draft.md` Section 2.3; `06_analysis/scripts/14b_expanded_meta_analysis.R` | Done | Pooled survival: 78.0% (CI: 70.1--84.3%). I^2 = 97.2%. Moderator analysis: natural vs restoration p = 0.238. Regional analysis exploratory. |
| 20 | **Reporting biases:** Present assessments of risk of reporting biases | `01_protocol/systematic_review_protocol.md` Section 7.4; `06_analysis/output/expanded_meta_trimfill.csv` (trim-and-fill results) | Done | Narrative assessment plus trim-and-fill analysis (script 14b). Funnel plot available in supplementary figures. Rationale for limited formal testing: vital rate compilation, not a treatment-effect review. |
| 21 | **Certainty of evidence:** Present assessments of certainty of evidence for each outcome | `07_reporting/manuscript_methods_draft.md` Section 2.4; `01_protocol/systematic_review_protocol.md` Section 8 | Done | Narrative certainty assessment addressing all 5 GRADE domains (risk of bias, inconsistency, indirectness, imprecision, publication bias) added to methods draft Section 2.4. Formal GRADE not applied (vital rate compilation, not treatment-effect review), but each domain is explicitly addressed with quantitative indicators (mean NOS 6.9/10, I^2 = 97.2%, prediction interval 39.5--95.1%). RoB sensitivity analysis added to script 14b (output: `expanded_meta_rob_sensitivity.csv`). |

---

## Section V: Discussion

| # | PRISMA 2020 Item | Section/Location in Repo | Status | Notes |
|---|------------------|--------------------------|--------|-------|
| 22 | **Discussion -- Interpretation:** Provide a general interpretation of results in the context of other evidence | Manuscript Discussion (not yet drafted) | TODO | Full Discussion section not yet written. Key interpretive elements now exist in `07_reporting/manuscript_narrative_integration.md`, `07_reporting/transferability_summary.md`, and `README.md` (Key Results), but they are not yet collapsed into final manuscript prose. |
| 23 | **Discussion -- Limitations:** Discuss limitations of the evidence and the review process | `01_protocol/systematic_review_protocol.md` Section 7 (5 subsections: Search Completeness, Single-Screener Bias, Data Extraction Reliability, Publication Bias, NOAA Data Dominance); `04_extraction/risk_of_bias.md`; `CLAUDE.md` (Critical Constraints) | Done | Thorough limitations documented: single screener, retrospective protocol, NOAA dominance, figure-derived values, no dual screening, I^2 = 97.2% heterogeneity, natural vs restoration confounding. |
| 24 | **Discussion -- Implications:** Discuss implications of results for practice, policy, and future research | Manuscript Discussion (not yet drafted) | TODO | Not yet written as formal manuscript prose. Current ingredients are distributed across `07_reporting/manuscript_narrative_integration.md`, `07_reporting/tables/size_class_synthesis_table.md`, `07_reporting/transferability_summary.md`, and `README.md`. |

---

## Section VI: Other Information

| # | PRISMA 2020 Item | Section/Location in Repo | Status | Notes |
|---|------------------|--------------------------|--------|-------|
| 25 | **Registration and protocol:** Provide registration information, name of registry, registration number | `01_protocol/systematic_review_protocol.md` Section 8 | Retrospective | This protocol was documented retrospectively in March 2026. The review was not prospectively registered in PROSPERO or an equivalent registry. This is stated in the protocol (Section 8) and should be stated in the manuscript methods. |
| 26 | **Support:** Describe sources of financial or non-financial support and the role of funders | Not addressed | TODO | Funding sources and funder roles not documented in the systematic review protocol. Should be added to the manuscript. |
| 27 | **Competing interests:** Declare any competing interests of review authors | Not addressed | TODO | No competing interests statement in the review documentation. Should be added to the manuscript. |

---

## PRISMA 2020 Abstract Checklist (12 items)

These items apply to the structured abstract, which has not yet been drafted.

| # | Abstract Item | Status | Notes |
|---|---------------|--------|-------|
| A1 | **Title:** Identify the report as a systematic review | TODO | Abstract not yet written |
| A2 | **Objectives:** State the review question | TODO | |
| A3 | **Eligibility criteria:** Specify inclusion criteria | TODO | |
| A4 | **Information sources:** List the databases and other sources searched | TODO | |
| A5 | **Risk of bias:** Specify methods for assessing risk of bias | TODO | |
| A6 | **Synthesis methods:** Specify the methods used for synthesis | TODO | |
| A7 | **Results -- Included studies:** Report the number of studies and participants | TODO | Numbers available: 17 studies, 22 effects, N = 8,805 |
| A8 | **Results -- Synthesis:** Present the main results of the synthesis | TODO | Numbers available: pooled survival 78.0% (CI: 70.1--84.3%), lambda 0.961 (CI: 0.816--1.010), I^2 = 97.2% |
| A9 | **Results -- Risk of bias:** Present results of risk-of-bias assessment | TODO | Numbers available: mean 6.8/10 |
| A10 | **Discussion -- Limitations:** Discuss limitations of the evidence | TODO | |
| A11 | **Discussion -- Interpretation:** Provide a general interpretation of results | TODO | |
| A12 | **Funding:** Provide funding information | TODO | |

---

## Summary

| Status | Count (Main Items 1--27, incl. 13a--f) | Count (Abstract Items A1--A12) |
|--------|------------------------------------------|-------------------------------|
| **Done** | 22 | 0 |
| **Partial** | 2 (Items 7, 8) | 0 |
| **Retrospective** | 3 (Items 5, 14, 25) | 0 |
| **Not assessed** | 0 | 0 |
| **TODO** | 5 (Items 2, 22, 24, 26, 27) | 12 |

**Changes from PRISMA audit (2026-03-29):**

- **Item 13f/20 (Reporting biases):** Upgraded Partial -> Done. Trim-and-fill analysis already implemented in script 14b (`expanded_meta_trimfill.csv`). Funnel plot available in supplementary figures.
- **Item 21 (Certainty of evidence):** Upgraded Not assessed -> Done. Narrative certainty assessment addressing all 5 GRADE domains added to `07_reporting/manuscript_methods_draft.md` Section 2.4.
- **Item 13e (Sensitivity analyses):** RoB sensitivity analysis added to script 14b (meta-regression with NOS score + exclusion of low-quality studies; output: `expanded_meta_rob_sensitivity.csv`).
- **Item 8 (Search strategy):** PRISMA-S citation (Rethlefsen et al. 2021) and missing-database acknowledgment added to methods draft Section 2.1.
- **Flow diagram:** Rewritten to PRISMA 2020 two-column layout (Page et al. 2021, Figure 1) with approximate counts honestly noted.

**Remaining gaps to address before submission:**

1. **Protocol registration (Items 5, 14, 25):** Documented retrospectively (March 2026). Not registered in PROSPERO. This is now explicitly stated in the protocol and should be stated in the manuscript methods.
2. **Search dates and hit counts (Items 7, 8):** Original search dates and database-specific hit counts remain approximate -- recoverable from Raine's Google Sheet tracker. PRISMA-S reporting added.
3. **Manuscript sections (Items 2, 22, 24, 26, 27):** Abstract, Discussion, Funding, and Competing Interests not yet drafted.

---

**References:**
- Page MJ, McKenzie JE, Bossuyt PM, et al. The PRISMA 2020 statement: an updated guideline for reporting systematic reviews. *BMJ*. 2021;372:n71. doi:10.1136/bmj.n71
- Rethlefsen ML, Kirtley S, Waffenschmidt S, et al. PRISMA-S: an extension to the PRISMA statement for reporting literature searches in systematic reviews. *Syst Rev*. 2021;10:39. doi:10.1186/s13643-020-01542-z
