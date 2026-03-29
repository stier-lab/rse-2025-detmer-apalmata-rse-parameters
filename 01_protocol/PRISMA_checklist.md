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
| 5 | **Protocol and registration:** Indicate whether a review protocol exists, whether and where it was registered, and provide registration information | `01_protocol/systematic_review_protocol.md` Section 8 (Deviations from Standard PRISMA), Section 9 (Protocol Changes) | Partial | Protocol exists and is thorough, but was written retrospectively (March 2026). **Not registered** in PROSPERO or any registry. The protocol document acknowledges this. |
| 6 | **Eligibility criteria:** Specify the inclusion and exclusion criteria | `01_protocol/systematic_review_protocol.md` Section 2 (Eligibility Criteria: Population, Outcomes, Study Design, Minimum Data Requirements, Independence); `04_extraction/extraction_protocol.md` Sections 1--3 | Done | Detailed criteria covering species, outcomes (survival/growth/fragmentation), study design (longitudinal with individual tracking), minimum data requirements (two tiers), independence rules, and explicit exclusion categories. |
| 7 | **Information sources:** Describe all information sources searched, with dates | `01_protocol/systematic_review_protocol.md` Section 3 (Information Sources: original search, expanded search, grey literature); `02_search/search_strings.md`; `02_search/search_summary.md` | Partial | Sources well documented (NOAA NCEI, NOAA InPort, USGS CMGDS, USGS ScienceBase, Google Scholar, citation chaining, direct data sharing, NotebookLM, PubMed, Semantic Scholar). **Gaps:** Exact dates and hit counts for the original Detmer 2025 search are `[TODO]`. Web of Science and PubMed usage in the original search is unconfirmed. |
| 8 | **Search strategy:** Present the full search strategy for at least one database | `01_protocol/systematic_review_protocol.md` Section 3.1 (5 Google Scholar search strings with exact Boolean terms); `02_search/search_strings.md` (replicated search strings with approximate hit counts from PubMed and Semantic Scholar) | Partial | Five structured search strings are documented with exact terms. **Gaps:** These are Google Scholar strings, not formal database-specific strategies (e.g., PubMed MeSH terms). The expanded search strings for PubMed/Semantic Scholar are approximate (WebSearch limitations). No PROSPERO-style full electronic search strategy per database. |
| 9 | **Selection process:** Specify methods used to decide whether a study met inclusion criteria, including how many reviewers screened and any automation | `01_protocol/systematic_review_protocol.md` Section 4 (Screening Process: 4.1 Original, 4.2 Expanded); `03_screening/full_text_screening.csv` (complete screening log with decisions and reasons); `04_extraction/study_characteristics.md` Table 2 (excluded studies with reasons); `03_screening/inter_rater_reliability.md` (IRR assessment) | Done | Two-phase screening documented: (1) Detmer 2025 single-screener title/abstract then full-text, 52 studies evaluated; (2) AI-assisted expansion, 33 new candidates assessed with independent audit. Single-screener limitation acknowledged. Full screening CSV with 87 entries. Inter-rater reliability (IRR) assessment now documented in `03_screening/inter_rater_reliability.md`. |
| 10 | **Data collection process:** Describe methods for collecting data, including how many reviewers collected data and any automation | `01_protocol/systematic_review_protocol.md` Section 5 (Data Extraction: variables, forms, template); `04_extraction/extraction_protocol.md` Section 1 (AI extraction method); `04_extraction/extraction_details.md` (per-study extraction verification); `07_reporting/manuscript_methods_draft.md` Section 2.2 | Done | Two-tier system documented. Tier 1: raw data from repositories. Tier 2: hand-extracted by Detmer or AI-extracted by Claude with independent audit. No formal dual extraction for hand-extracted data, but AI-extracted data received independent audit. Extraction form template provided retrospectively. Post-audit data verification removed Muller et al. 2008, Sutherland et al. 2016, and Roth et al. 2013 (data overlap with Rogers & Muller 2012); added Rogers et al. 1982 (reclassified). Final k=18. |
| 11 | **Data items:** List and define all outcomes and other variables for which data were sought, and any assumptions made | `01_protocol/systematic_review_protocol.md` Section 5.1 (all variables listed: study-level metadata, survival data, size data, growth data); `04_extraction/extraction_protocol.md`; `05_data/standardized/README.md` (column definitions) | Done | Complete variable list with definitions: study_id, citation, region, country, lat/lon, population_type, restoration_method, monitoring_years, time_interval_yr, data_source, n_total, n_survived, prop_survived, surv_annual, mortality_definition, size_live_cm2, size_measurement_method, size_class, growth_cm2_yr, relative_growth_rate. |
| 12 | **Study risk of bias assessment:** Specify methods used for assessing risk of bias of individual studies | `04_extraction/risk_of_bias.md` (adapted Newcastle-Ottawa Scale, 5 domains, scored for all 18 studies); `01_protocol/systematic_review_protocol.md` Section 7 (Risk of Bias and Limitations) | Done | Custom 5-domain risk-of-bias tool (Selection, Measurement, Attrition, Mortality Definition, Temporal Adequacy) scored 0--2 per domain, total /10. All 18 studies scored. Acknowledged that no standard tool exists for vital rate compilations. |
| 13a | **Synthesis methods -- Eligibility:** Describe the criteria for which studies were eligible for each synthesis | `01_protocol/systematic_review_protocol.md` Section 2 (Eligibility Criteria); `07_reporting/manuscript_methods_draft.md` Section 2.1 (Inclusion criteria); `04_extraction/study_characteristics.md` (Tables 1A--1D) | Done | Survival meta-analysis: 18 studies with annualized survival + sample size. Growth analysis: Tier 1 studies only (individual-level). Fragmentation: Vardi 2011 only. |
| 13b | **Synthesis methods -- Data preparation:** Describe any methods required to prepare the data for synthesis | `07_reporting/manuscript_methods_draft.md` Section 2.2 (Size standardization, Annualization, AI-assisted extraction); `06_analysis/scripts/analysis/` and `analysis/scripts/01_data_preparation.R` (data prep code); `06_analysis/scripts/utils/00c_analysis_constants.R` (size class definitions) | Done | Size standardization to cm^2, annualization formula, size class assignment, Haldane correction for zero cells, logit transformation for meta-analysis. All documented in methods and implemented in R scripts. |
| 13c | **Synthesis methods -- Tabulation and graphical methods:** Describe methods for tabulating and displaying results | `analysis/scripts/18_fig1_study_landscape.R` through `analysis/scripts/28_supp_S12_S13_S14.R` (figure scripts); `07_reporting/figure_legends.txt`; `CLAUDE.md` (Figure Standards section) | Done | 4 main figures + 16 supplementary figures documented. Forest plot (Fig 3), GAM panels (Fig 2), transition matrix heatmap (Fig 4), study landscape map (Fig 1). All exported at Coral Reefs journal specifications. |
| 13d | **Synthesis methods -- Statistical methods:** Describe the statistical synthesis methods | `analysis/scripts/14b_expanded_meta_analysis.R` (random-effects meta-analysis with `metafor::rma()`); `analysis/scripts/14_meta_analysis.R` (k=5 meta); `07_reporting/manuscript_methods_draft.md` Section 2.3; `CLAUDE.md` (Statistical Conventions) | Done | Random-effects meta-analysis using proportional log-odds (PLO) with Knapp-Hartung adjustment (`test = "knha"`). Moderator analysis for population type, region, risk of bias. I^2 and Q statistics reported. |
| 13e | **Synthesis methods -- Sensitivity analyses:** Describe any sensitivity analyses planned | `analysis/scripts/16_sensitivity_analysis.R` (LOSO sensitivity, bootstrap lambda); `analysis/scripts/15_heterogeneity_analysis.R`; `analysis/scripts/10_cross_validation.R` | Done | Leave-one-study-out (LOSO) sensitivity analysis for meta-analysis and population model. Bootstrap lambda distribution (2000 replicates, hierarchical resampling). Cross-validation of GAMs. |
| 13f | **Synthesis methods -- Reporting biases:** Describe any methods for assessing reporting biases | `01_protocol/systematic_review_protocol.md` Section 7.4 (Publication Bias) | Partial | Narrative discussion of publication bias. **No formal funnel plot or Egger's test conducted.** Justified because this is a vital rate compilation, not a treatment-effect meta-analysis. |
| 14 | **Registration and protocol:** Provide registration information and where protocol can be accessed | `01_protocol/systematic_review_protocol.md` | Partial | Protocol document exists in repo. **Not registered** in PROSPERO. Retrospective documentation acknowledged. |

---

## Section IV: Results

| # | PRISMA 2020 Item | Section/Location in Repo | Status | Notes |
|---|------------------|--------------------------|--------|-------|
| 15 | **Study selection:** Describe results of the search and selection process, with flow diagram | `03_screening/full_text_screening.csv` (87 entries with decisions); `01_protocol/systematic_review_protocol.md` Section 6 (flow diagram in ASCII + Mermaid); `07_reporting/prisma_flow_diagram.md` (dedicated flow diagram document) | Done | Full screening CSV. Flow diagram with counts at each stage (85 assessed at full text, 69 excluded with categorized reasons, 22 initially extracted, 4 removed after audit, 18 included = k=18 effects). |
| 16 | **Study characteristics:** Present characteristics of each included study | `04_extraction/study_characteristics.md` Tables 1A (Tier 1, 6 studies), 1B (Tier 2 hand, 9 studies), 1C (Tier 2 AI, 4 studies), 1D (additional contributions); Table 2 (excluded studies by reason); `04_extraction/extraction_details.md` (per-study extraction verification) | Done | Comprehensive tables with study ID, citation, region, population type, design, sample size, outcomes, size metric, time interval, extractor, audit result, and key caveats for all 19 included studies. Excluded studies similarly detailed in Table 2. |
| 17 | **Risk of bias in studies:** Present risk-of-bias assessments for each included study | `04_extraction/risk_of_bias.md` (all 18 studies scored on 5 domains with summary statistics) | Done | All 18 studies scored. Range: 4--10 out of 10. Low risk: 7 studies; Low-Moderate: 4; Moderate: 5; Moderate-High: 1; High: 1. |
| 18 | **Results of individual studies:** Present results of each individual study, including estimates and CIs | `analysis/output/expanded_meta_analysis_study_effects.csv` (per-study survival estimates with CIs); `analysis/output/expanded_meta_analysis_results.csv` (summary); `06_analysis/output/` (analysis outputs) | Done | Per-study annualized survival with 95% Wilson CIs. Forest plot (Fig 3, Script 20b) shows point estimates and CIs for all k=18 effects. |
| 19 | **Results of syntheses:** Present results of each synthesis, including CIs and measures of statistical heterogeneity | `analysis/output/expanded_meta_analysis_results.csv`; `07_reporting/manuscript_methods_draft.md` Section 2.3; `analysis/scripts/14b_expanded_meta_analysis.R` | Done | Pooled survival: 79.2% (CI: 70.6--85.7%). I^2 = 96.4%. Moderator analysis: natural vs restoration p = 0.405. Regional analysis exploratory. |
| 20 | **Reporting biases:** Present assessments of risk of reporting biases | `01_protocol/systematic_review_protocol.md` Section 7.4 | Partial | Narrative assessment only. No funnel plot, Egger's test, or formal reporting bias assessment. Rationale: not a treatment-effect review. |
| 21 | **Certainty of evidence:** Present assessments of certainty of evidence for each outcome | Not addressed | TODO | GRADE or equivalent certainty assessment not performed. Justified in protocol Section 8 (GRADE designed for treatment-effect evidence, not vital rate compilations). Should add a brief narrative certainty assessment or explicitly state why GRADE is inapplicable. |

---

## Section V: Discussion

| # | PRISMA 2020 Item | Section/Location in Repo | Status | Notes |
|---|------------------|--------------------------|--------|-------|
| 22 | **Discussion -- Interpretation:** Provide a general interpretation of results in the context of other evidence | Manuscript Discussion (not yet drafted) | TODO | Full Discussion section not yet written. Key interpretive elements exist in `README.md` (Key Results) and `docs/ANALYSIS_SUMMARY.md` but not formatted as a Discussion. |
| 23 | **Discussion -- Limitations:** Discuss limitations of the evidence and the review process | `01_protocol/systematic_review_protocol.md` Section 7 (5 subsections: Search Completeness, Single-Screener Bias, Data Extraction Reliability, Publication Bias, NOAA Data Dominance); `04_extraction/risk_of_bias.md`; `CLAUDE.md` (Critical Constraints) | Done | Thorough limitations documented: single screener, retrospective protocol, NOAA dominance (78%), figure-derived values, no dual screening, I^2 = 94.8% heterogeneity, natural vs restoration confounding. |
| 24 | **Discussion -- Implications:** Discuss implications of results for practice, policy, and future research | Manuscript Discussion (not yet drafted) | TODO | Not yet written as formal manuscript prose. Some implications scattered across `README.md` and `docs/ANALYSIS_SUMMARY.md`. |

---

## Section VI: Other Information

| # | PRISMA 2020 Item | Section/Location in Repo | Status | Notes |
|---|------------------|--------------------------|--------|-------|
| 25 | **Registration and protocol:** Provide registration information, name of registry, registration number | `01_protocol/systematic_review_protocol.md` Section 8 | Partial | Protocol exists. **Not registered.** Protocol was written retrospectively. This should be stated clearly in the manuscript methods. |
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
| A7 | **Results -- Included studies:** Report the number of studies and participants | TODO | Numbers available: 18 studies, k=18 effects, ~9,500 individuals |
| A8 | **Results -- Synthesis:** Present the main results of the synthesis | TODO | Numbers available: pooled survival 79.2%, lambda 1.001, I^2 = 96.4% |
| A9 | **Results -- Risk of bias:** Present results of risk-of-bias assessment | TODO | Numbers available: mean 6.8/10 |
| A10 | **Discussion -- Limitations:** Discuss limitations of the evidence | TODO | |
| A11 | **Discussion -- Interpretation:** Provide a general interpretation of results | TODO | |
| A12 | **Funding:** Provide funding information | TODO | |

---

## Summary

| Status | Count (Main Items 1--27) | Count (Abstract Items A1--A12) |
|--------|--------------------------|-------------------------------|
| **Done** | 16 | 0 |
| **Partial** | 6 | 0 |
| **TODO** | 5 | 12 |

**Key gaps to address before submission:**

1. **Protocol registration (Items 5, 14, 25):** Not registered in PROSPERO. State this explicitly in manuscript methods with justification (retrospective documentation of a vital rate compilation).
2. **Search dates and hit counts (Items 7, 8):** Original search dates and database-specific hit counts remain `[TODO]` -- recoverable from Raine's Google Sheet tracker.
3. **Reporting bias assessment (Items 13f, 20):** Consider adding a funnel plot for the k=18 meta-analysis even though publication bias logic differs for vital rate compilations.
4. **Certainty of evidence (Item 21):** Add a brief narrative statement on evidence certainty or explicitly justify why GRADE is inapplicable.
5. **Manuscript sections (Items 2, 22, 24, 26, 27):** Abstract, Discussion, Funding, and Competing Interests not yet drafted.

---

**Reference:** Page MJ, McKenzie JE, Bossuyt PM, et al. The PRISMA 2020 statement: an updated guideline for reporting systematic reviews. *BMJ*. 2021;372:n71. doi:10.1136/bmj.n71
