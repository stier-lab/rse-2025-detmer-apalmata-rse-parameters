# Data Acquisition Plan — Florida Restoration Monitoring Programs

**Date:** 2026-04-03
**Status:** Planning
**Goal:** Acquire individual-level demographic data (colony ID, size, survival, growth) from Florida restoration monitoring programs that contributed to Manzello et al. (2025, *Science*) but whose data we do not currently have.

---

## 1. Why This Matters

Our synthesis has 7 Tier 1 (individual-level) studies with ~7,800 survival records. **76% come from two NOAA-affiliated datasets** (NOAA_survey + Neely). Florida restoration programs collectively track **tens of thousands** of individually tagged outplants with size measurements, survival outcomes, and genotype information — spanning both the chronic demographic regime (pre-2023) and the 2023 catastrophic heatwave.

These data would:
- Dramatically increase our sample size for restoration fragment vital rates (currently only Pausch 2018 + Kuffner 2020 = ~1,000 records)
- Provide size-dependent survival under the 2023 heatwave from a much larger sample than our 79 NOAA colonies
- Test whether size-dependent survival advantages collapse under extreme heat (currently assumed in Script 40)
- Strengthen the natural vs. restoration comparison with matched-size data
- Add genotype-level information relevant to assisted gene flow recommendations

---

## 2. Target Programs

### Priority 1 — Large programs with individual-level data

#### A. Coral Restoration Foundation (CRF)
- **Contact:** Jessica Levy, Director of Global Restoration Strategy (Ken Nedimyer has left CRF; see [staff page](https://coralrestoration.org/staff/jessica-levy/))
- **Location:** Key Largo, FL
- **What they likely have:** Tens of thousands of nursery-reared fragments tracked from outplanting through 2023. CRF is the largest *A. palmata* restoration program in FL. Fragments are tagged, sized at outplanting, and monitored periodically. Genotype tracked for all outplants.
- **Manzello provider code:** "crf"
- **Overlap with our data:** Pausch et al. 2018 used CRF fragments for their experiment (same nursery source), but Pausch's published data covers only 2014-2016 at two reef sites. CRF's full monitoring database is far larger and extends through 2023.
- **What we need:** Colony/fragment ID, outplant date, site, genotype (if available), size at each census (L, W, %live or planar area), alive/dead status at each census, census dates.
- **Manzello co-authors from CRF:** Erich Bartels, Ken Nedimyer

#### B. Mote Marine Laboratory
- **Contact:** Erinn Muller (coral program director)
- **Location:** Sarasota, FL (field sites throughout Keys)
- **What they likely have:** Individually tracked outplants at multiple reef sites, with size and survival monitoring. Mote runs one of the largest coral nursery programs in FL alongside CRF.
- **Manzello provider code:** "mml"
- **Overlap with our data:** None. We have no Mote-sourced data.
- **What we need:** Same as CRF above.
- **Manzello co-authors from Mote:** Hanna R. Koch
- **Note:** Muller et al. 2025 (excluded as E8/E4) is a review of 20-year FL restoration; the underlying data from Mote's program may be extractable.

#### C. Mission: Iconic Reefs (MIR) / NOAA Restoration Center
- **Contact:** Jennifer Moore or Jason Spadaro (NOAA)
- **Location:** FL Keys (7 focal reef sites)
- **What they likely have:** Systematically designed monitoring of outplanted corals at 7 reef sites since ~2021. This is the most structured and recent restoration monitoring program in FL, designed with demographic tracking in mind. Multiple nursery sources (CRF, Mote, others).
- **Manzello provider code:** "mir"
- **Overlap with our data:** None directly. Some MIR colonies may originate from CRF/Mote nurseries, but the monitoring is independent.
- **What we need:** Same as CRF above. MIR's data standards may be the most analysis-ready given the program's systematic design.
- **Manzello co-authors from MIR partners:** Jennifer Moore, Jason Spadaro, Lindsay Huebner, Cailin Harrell

### Priority 2 — Smaller programs or less certain data availability

#### D. Nova Southeastern University (NSU) / Gilliam Lab
- **Contact:** David Gilliam
- **Location:** Dania Beach, FL (field sites in SE FL)
- **What they likely have:** Southeast Florida reef monitoring data. NSU runs the Southeast Florida Coral Reef Evaluation and Monitoring Project (SECREMP). May have individual-level *A. palmata* tracking, particularly in the Broward-Miami region where Manzello reported 37.9% mortality (the lowest).
- **Manzello provider code:** "nsu"
- **Overlap with our data:** None.
- **Value:** Broward-Miami data is especially interesting — these corals experienced lower DHW and had higher survival, providing within-event variation for the dose-response.

#### E. University of Miami / Lirman Lab
- **Contact:** Diego Lirman
- **Location:** Miami, FL
- **What they likely have:** Tagged outplant monitoring in the Upper Keys and possibly Biscayne area. Lirman's lab has published extensively on *A. cervicornis* and *A. palmata* restoration. Maurer et al. 2022 (already in our Tier 2 data) came from this lab.
- **Manzello provider code:** "um"
- **Overlap with our data:** Maurer 2022 is already included as Tier 2 (summary-level). The full UM monitoring database may have individual-level records that supersede this.
- **Manzello co-authors from UM:** Diego Lirman, Dalton Hesley

#### F. FWC (Florida Fish & Wildlife Conservation Commission)
- **Contact:** Rob Ruzicka
- **Location:** St. Petersburg, FL
- **What they likely have:** FWC runs the Coral Reef Evaluation and Monitoring Project (CREMP) and manages state-level coral monitoring. May have *A. palmata* tracking records, though CREMP is primarily community-level transect monitoring.
- **Manzello provider code:** "fwc"
- **Overlap with our data:** None.
- **Caveat:** FWC's data may be more community-level (% cover) than individual-colony tracking. Lower priority unless they confirm individual-level data exist.

#### G. Biscayne National Park (BNP) / NPS
- **Contact:** Amanda Bourque
- **Location:** Homestead, FL
- **What they likely have:** Tagged *A. palmata* monitoring within Biscayne National Park, which is in the northern range of FL's reef tract. Small program but unique geography — these are among the northernmost populations.
- **Manzello provider code:** "bnp"
- **Overlap with our data:** None.
- **Manzello co-authors from BNP:** Amanda Bourque

---

## 3. What We're Asking For

**Minimum useful dataset per program:**

| Field | Description | Required? |
|-------|------------|-----------|
| colony_id | Unique identifier | Yes |
| site | Reef site or location name | Yes |
| lat, lon | Coordinates | Yes |
| date | Census/survey date | Yes |
| alive | Alive (1) or dead (0) at this census | Yes |
| size_cm2 | Live planar tissue area (cm²) | Yes |
| size_method | How size was measured (L×W×%live, photo tracing, etc.) | Preferred |
| genotype | Genet identifier | Preferred |
| origin | Wild, nursery outplant, natural fragment, etc. | Yes |
| outplant_date | Date originally outplanted (restoration only) | Preferred |
| nursery_source | Which nursery (CRF, Mote, etc.) | Preferred |
| notes | Any disturbance, disease, or event notes | Preferred |

**Key: we need size at each census, not just alive/dead.** The Manzello data already gave us alive/dead; the value-add is individual sizes that enable size-dependent vital rate estimation.

---

## 4. Outreach Strategy

### 4.1 Gateway-first approach

Rather than cold-emailing every program simultaneously, start with the people who already compiled data across programs:

**Phase 0 — Gateway contacts:**
- **Derek Manzello** (corresponding author, NOAA Coral Reef Watch): derek.manzello@noaa.gov — coordinated the entire 2023 response; knows all the program leads personally; an introduction from him carries weight.
- **Ross Cunning** (first author on data/code repo, Perry Institute for Marine Science): rcunning@perryinstitute.org (verify) — literally handled the raw data from each program for the GitHub repo; knows exactly which programs track individual colony sizes vs. just site-level counts.

A single email to Manzello or Cunning explaining what we need and asking "which of your contributing programs actually tracks individual colony sizes?" could save weeks of misdirected outreach. If they're willing to make introductions, subsequent emails arrive pre-warmed.

**Phase 1 — Priority programs** (after gateway response or in parallel if no response within 1 week):
Direct emails to CRF, Mote, and Mission: Iconic Reefs — the three largest programs most likely to have individual-level data with sizes.

**Phase 2 — Secondary programs:**
NSU/Gilliam, UM/Lirman, BNP. These are smaller programs where data availability is less certain, but each fills a unique niche (SE Florida low-DHW sites, Biscayne northernmost populations).

### 4.2 What we offer in return

- **Co-authorship** on the synthesis paper (*Coral Reefs*). Not "co-authorship or citation" — genuine collaboration. Anyone who contributes data and engages with the analysis is a co-author.
- **Site-specific population viability analyses** — our Lefkovitch model + heatwave scenario framework (Script 40) applied to their sites. This gives restoration managers actionable outputs: target outplant size, minimum planting density, projected time to self-sustaining population, and quasi-extinction probability under different climate scenarios.
- **Full access** to the compiled Caribbean-wide dataset and analysis pipeline (open GitHub repo).
- **Transparent data handling** — PRISMA-documented inclusion criteria, standardization pipeline, and no redistribution of raw data without permission.

### 4.3 Sequencing

| Phase | Timeline | Action |
|-------|----------|--------|
| 0 | Week of April 7 | Gateway email to Manzello and/or Cunning |
| 1 | April 7-14 | If gateway responds: follow introductions. If not: send direct emails to CRF, Mote, MIR |
| 2 | April 14-21 | Send emails to NSU, UM, BNP |
| 3 | April 21 - May 5 | Follow up on non-responses; schedule video calls |
| 4 | May - June | Receive data, standardize (new 00_standardize scripts), integrate into pipeline |
| 5 | June - July | Re-run full analysis pipeline with expanded dataset; assess impact on results |
| 6 | July | Circulate updated manuscript draft to new co-authors for input |

### 4.4 Email template structure

Based on the successful Neely outreach (sent 2026-03-28, data received 2026-04-01), each email should:
1. **Personal connection** — find any prior interaction, shared colleague, or conference overlap
2. **Specific praise** — name their work and why it matters to us specifically
3. **Clear ask** — exactly what data fields we need (the table above)
4. **What they get** — co-authorship/citation + access to synthesis + site-specific PVA
5. **Low friction** — "any format you already have is fine; we handle standardization"
6. **Brief** — under 300 words; offer a call for more detail

### 4.5 Key talking points by program

**CRF:** "Your fragments represent the largest restoration population in the Caribbean. Understanding how size at outplanting predicts long-term survival — and how the 2023 event interacted with colony size — is directly relevant to optimizing future outplanting strategy."

**Mote:** "Mote's monitoring data would add a second independent restoration program to our vital rate estimates. Combined with CRF data, this would let us test whether survival patterns are program-specific or generalizable across FL restoration efforts."

**MIR:** "Mission: Iconic Reefs represents the most systematic restoration monitoring design in the Caribbean. Your data would set the standard for how restoration monitoring data should be integrated into demographic models."

**NSU/Gilliam:** "Your Broward-Miami monitoring fills a unique niche — these populations experienced the lowest DHW during 2023 and had the highest survival. This within-event variation is critical for understanding the dose-response relationship between heat stress and colony survival."

---

## 5. Potential Issues

- **Data sharing restrictions:** Some programs (especially federal: NOAA, NPS, FWC) may require formal data sharing agreements or have embargo periods. Budget time for this.
- **Data format heterogeneity:** Each program uses different size measurement methods, census intervals, and database structures. Our standardization pipeline (Script 01) can handle this but will need per-source customization.
- **Overlap between programs:** Some colonies may appear in multiple programs' databases (e.g., a CRF-reared fragment outplanted at an MIR reef site and monitored by both). Need to deduplicate on colony ID and site.
- **Publication priority:** Some groups may be sitting on unpublished analyses of their 2023 data. Frame our synthesis as complementary, not competitive — we're estimating vital rates across the Caribbean, not analyzing the 2023 FL event per se. Emphasize that their 2023 story is theirs to tell; we're building a general demographic framework.
- **Genotype sensitivity:** Coral genotype information may be sensitive (genetic rescue, intellectual property around heat-tolerant strains). Make clear we only need genotype as a random effect for statistical purposes, not for genetic analysis. Offer to anonymize genotype IDs if needed.
- **Timeline pressure:** Our manuscript is close to submission but not locked. New data can be integrated without major restructuring — the pipeline is designed for it. But communicate this honestly: "We're hoping to include your data in the current round, but we can also integrate it in a revision or follow-up paper if the timing doesn't work."

---

## 6. Impact Assessment

If we acquire individual-level data from even 2-3 of these programs, the synthesis would grow from:
- **Current:** ~7,800 survival records from 7 Tier 1 studies (76% NOAA-affiliated)
- **Potential:** ~15,000-50,000+ survival records from 10+ Tier 1 studies

This would:
- Reduce NOAA dominance from 78% to potentially <30%
- Enable robust size-dependent survival estimation under the 2023 heatwave (currently n=79)
- Support genotype-level analysis of thermal tolerance
- Test whether restoration fragment vital rates are program-specific or generalizable
- Make this the definitive *A. palmata* demographic dataset for the Caribbean
- Directly address the question Manzello 2025 couldn't: does colony size still matter under extreme heat?

---

## 7. Tracking

| Program | Email sent | Response | Data received | Notes |
|---------|-----------|----------|---------------|-------|
| Neely (template) | 2026-03-28 | 2026-03-29 | 2026-04-01 | 878 colonies. Integrated as Tier 1. |
| Manzello/Cunning (gateway) | — | — | — | |
| CRF | — | — | — | |
| Mote | — | — | — | |
| MIR | — | — | — | |
| NSU/Gilliam | — | — | — | |
| UM/Lirman | — | — | — | |
| BNP/Bourque | — | — | — | |

---

*Plan prepared: 2026-04-03, updated 2026-04-04*
*Ocean Recoveries Lab, UC Santa Barbara*
*See `email_drafts_data_requests.md` for complete email drafts.*
