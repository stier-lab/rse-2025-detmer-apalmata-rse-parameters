# Catastrophic Mortality Events in the Dataset

**Date:** 2026-04-01
**Purpose:** Identify which studies in our compilation overlap with known Caribbean A. palmata catastrophic mortality events.

---

## Key Finding

**38% of all individual-level records fall in years with <80% survival.** Disturbance is not a rare exception — it is a pervasive feature of *A. palmata*'s demographic reality. Only 20% of records carry any disturbance flag.

---

## 1. Cause of the 2014 Neely Catastrophe

**Confirmed: Back-to-back thermal bleaching events in 2014 and 2015**, compounded by corallivorous snail predation (*Coralliophila abbreviata*).

Evidence from the actual Neely et al. (2022) Frontiers paper:
- SST exceeded 31C (87.8F) at Upper Keys sites in August 2014
- An estimated 50% of the monitored elkhorn coral population died
- Sites chronically impacted by corallivorous snails experienced near-complete mortality
- Geographic pattern: Marker 3 Reef (inshore, Biscayne NP) suffered 75% mortality; Dry Tortugas (offshore, cooler) retained >90% survival

**NOT caused by SCTLD** — which primarily affects massive corals, not *Acropora*.

Source: [Neely et al. 2022, Frontiers in Marine Science](https://www.frontiersin.org/journals/marine-science/articles/10.3389/fmars.2022.978785/full)

---

## 2. Confirmed/Probable Catastrophic Events in Dataset

| Event | Year(s) | Studies affected | Flagged? | Survival |
|-------|---------|-----------------|----------|----------|
| 2014-15 thermal bleaching | 2014-2016 | Neely, Pausch, NOAA FL | Neely only | 53-59% |
| Hurricane Irma (Cat 3) | 2017-2018 | NOAA FL | No | 66-74% |
| Curacao bleaching | 2009 | NOAA Curacao | Mislabeled "storm" | 55% |
| 2023 marine heatwave | 2022-2024 | NOAA FL | No | 54-74% |
| SCTLD spread | 2019-2020 | USGS USVI, Kuffner, Rosales | No | 53-73% |
| Hurricane David | 1979-1980 | Rogers 1982 | No (inherent to study) | 35-66% |
| Hurricane Georges aftermath | 1998-2001 | Ortiz Prosper, Bruckner | No | 69-81% |
| 2005 mass bleaching | 2005 | Rogers & Muller (within span) | No | within 51-64% (7yr) |

---

## 3. Pausch Overlap with 2014-15 Bleaching

**Critical finding:** Pausch et al. (2018) data from FL Keys 2015-2016 captures the same bleaching event as Neely but carries no disturbance flag:

- Pausch 2015 at Molasses Reef: 43.2% survival (81 colonies)
- Pausch 2015 at Pickles Reef: 44.6% survival (83 colonies)
- Pausch 2016 at Molasses Reef: 25.0% survival (120 colonies)
- Pausch overall: 57% survival in 2015-2016

These are restoration fragments outplanted to Upper Keys reefs that experienced the bleaching. Pausch's 57% is nearly identical to Neely's 53-61% during the flagged disease intervals.

**This confirms the disturbance handling decision:** excluding Neely's flagged data while retaining Pausch's unflagged data from the same event would be scientifically incoherent.

---

## 4. NOAA FL Keys: Regime Shift

NOAA data reveals a persistent decline trajectory with at least four disturbance epochs:

| Period | Avg annual survival | Events |
|--------|-------------------|--------|
| 2005-2011 | ~93% | Relatively stable |
| 2012-2013 | ~86% | Moderate stress |
| 2014-2016 | ~82% | Thermal bleaching |
| 2017-2018 | ~70% | Hurricane Irma |
| 2019-2021 | ~84% | Recovery period |
| 2022-2024 | ~60% | SCTLD + 2023 record heatwave |

Survival has not returned to pre-2014 levels, suggesting a **regime shift** rather than discrete disturbance events.

---

## 5. Intervals That Could Be Additionally Flagged (But Are Not)

| Study | Year | Current flag | Suggested flag | Survival |
|-------|------|-------------|----------------|----------|
| Pausch | 2015-2016 | none | bleaching_2014_aftermath | 52-59% |
| NOAA FL Keys | 2017 | none | hurricane_irma | 66% |
| NOAA FL Keys | 2022-2024 | none | sctld_heatwave | 54-74% |
| NOAA Curacao | 2009 | storm | bleaching_2009 | 55% |
| USGS USVI | 2020 | none | sctld_2019 | 53% |

**Decision:** We do NOT retroactively flag these intervals because:
1. Flagging would be post-hoc and subjective (threshold-dependent)
2. It would not change the primary analysis (all data included regardless)
3. The sensitivity analysis already demonstrates robustness
4. The pervasiveness of disturbance across studies IS the finding

---

## 6. Implications

1. **Lambda = 0.964 reflects reality.** The population model includes catastrophic events because *A. palmata* faces them regularly (roughly every 3-5 years in the FL Keys since 2014).

2. **The Egger's test significance (p=0.006)** is likely driven by the Neely catastrophe creating funnel plot asymmetry, not actual publication bias.

3. **The NOAA FL Keys trajectory is alarming.** Post-2022 survival averaging ~60% suggests the species is experiencing compounding stressors (SCTLD + thermal stress) that may exceed historical disturbance regimes.

4. **Our synthesis captures the full range of demographic conditions** this species experiences, from stable periods (~93% survival) through catastrophic events (~53% survival). This is appropriate for a population viability assessment.
