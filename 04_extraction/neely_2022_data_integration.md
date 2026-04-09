# Neely et al. 2022 — Data Integration Notes

**Source:** `05_data/original/Neely_et_al_2022_FKNMS_APAL.xlsx`
**Received:** 2026-04-01 (direct data sharing from K. Neely after email request)
**Publication:** Neely KL, Lewis CL, Lunz KS, Kabay L (2022) *Rapid Population Decline of the Pillar Coral Dendrogyra cylindrus along the Florida Reef Tract.* Frontiers in Marine Science 8:799187. doi: 10.3389/fmars.2021.799187

> **Note:** The Neely lab's published work focuses on *Dendrogyra cylindrus*, but they also tracked *Acropora palmata* colonies at the same sites as part of their broader FKNMS demographic monitoring program. The APAL data were shared directly and have not been published separately.

---

## Dataset Overview

| Field | Value |
|-------|-------|
| Species | *Acropora palmata* |
| Region | Florida Keys, USA |
| Location | 9 reef sites, 19 plots across Biscayne NP, Middle Keys, Lower Keys, Dry Tortugas NP |
| Population type | Natural colony |
| Data type | Individual-level (Tier 1) |
| N colonies | 878 unique tagged colonies (502 with initial size at TP1) |
| N timepoints | 7 (Winter 2010/2011 through Fall 2016) |
| Size metric | LAI (Live Area Index) = live planar tissue area (cm^2) |
| Mortality definition | LAI = 0 at a timepoint; absorbing state (once 0, always 0) |
| Fragment | N (natural colonies, not outplants) |

---

## Temporal Structure

| Timepoint | Season | Date range | Median date |
|-----------|--------|------------|-------------|
| TP1 | Winter 2010/2011 | 2010-11-15 to 2011-06-14 | ~2011-01 |
| TP2 | Spring 2012 | 2012-02-07 to 2012-06-15 | ~2012-04 |
| TP3 | Fall 2012 | 2012-09-26 to 2012-11-02 | ~2012-10 |
| TP4 | Fall 2013 | 2013-09-04 to 2013-12-04 | ~2013-09 |
| TP5 | Winter 2014-15 | 2014-09-04 to 2015-02-25 | ~2014-10 |
| TP6 | Fall 2015 | 2015-09-04 to 2015-09-14 | ~2015-09 |
| TP7 | Fall 2016 | 2016-09-25 | 2016-09-25 |

**Unequal intervals:** TP1→TP2 = ~14 months; TP2→TP3 = ~5.5 months; TP3→TP4 = ~11 months; TP4→TP5 = ~13 months; TP5→TP6 = ~11 months; TP6→TP7 = ~13 months.

---

## Site Structure

| Location | Site | Plots | N colonies | Mean LAI (TP1) |
|----------|------|-------|------------|----------------|
| Biscayne NP | Marker 3 Reef | MR-1, MR-2, MR-3 | 374 (83+175+116) | ~700 |
| Biscayne NP | Ball Buoy Reef | BB-1, BB-2 | 60 (35+25) | ~1800 |
| Middle Keys | Sombrero Reef | SR-1, SR-2, SR-3 | 28 (14+8+6) | ~3800 |
| Lower Keys | Looe Key | LK-1, LK-2, LK-3 | 147 (61+37+49) | ~3700 |
| Lower Keys | West Sambo Key | WS-1, WS-2, WS-3 | 66 (27+9+30) | ~4000 |
| Lower Keys | Rock Key | RK-1 | 11 | ~2300 |
| Lower Keys | Sand Key | SK-1, SK-2 | 61 (26+35) | ~1300 |
| Dry Tortugas NP | Palmata Patch | DT-1, DT-2 | 131 (95+36) | ~1300 |

---

## NOAA Overlap Check

**No overlap.** NOAA NCRMP monitors Upper Keys sites (Carysfort, Elbow, French, Grecian Rocks, Key Largo Dry Rocks, Molasses, Sand Island, Turtle Rocks), while Neely monitors Middle/Lower Keys and Dry Tortugas. No site-level or colony-level overlap.

---

## Disturbance Signal

### The 2014 Catastrophe

Between Fall 2013 (TP4) and Winter 2014-15 (TP5), survival plummeted:

| Interval | At risk | Survived | Died | Survival | Annualized |
|----------|---------|----------|------|----------|------------|
| TP1→TP2 | 493 | 417 | 76 | 84.6% | 86.5% |
| TP2→TP3 | 496 | 426 | 70 | 85.9% | 72.0% |
| TP3→TP4 | 555 | 525 | 30 | **94.6%** | 94.3% |
| **TP4→TP5** | **639** | **340** | **299** | **53.2%** | **55.3%** |
| TP5→TP6 | 375 | 230 | 145 | 61.3% | 59.2% |
| TP6→TP7 | 71 | 57 | 14 | 80.3% | 81.3% |

**~300 colonies died in a single year.** Sites in the Lower Keys (West Sambo: 0% final survival; Sand Key: 3-4%) were nearly completely wiped out, while Dry Tortugas (53-54%) and Sombrero Reef (61-91%) fared better.

### Confirmed cause: 2014-2015 thermal bleaching

Published evidence (Williams et al. 2017, Marine Pollution Bulletin; Neely et al. 2022, Frontiers in Marine Science) confirms this was caused by **back-to-back thermal bleaching events in 2014 and 2015**, compounded by chronic corallivorous snail predation (*Coralliophila abbreviata*):

- SST exceeded 31C (87.8F) at FL Keys sites in August 2014; DHW reached 7.5-10.9
- Up to 100% of *A. palmata* colonies were bleached at NOAA Upper Keys sites
- Sites with chronic *Coralliophila* predation experienced near-total mortality
- Geographic pattern: inshore/forereef sites (Marker 3, Sand Key, West Sambo) hit hardest; offshore backreef (Dry Tortugas) largely spared — consistent with thermal stress refugia

**Ruled out:** SCTLD (does not affect *Acropora* spp.); cold stress (no cold snap in 2014); hurricanes (none in 2013-2014). White pox may have contributed secondarily (bleaching increases disease susceptibility) but was not the primary driver.

Note: The disturbance flag `disease_2014` is a misnomer; `bleaching_2014` would be more accurate but is retained for pipeline compatibility.

### Implications for analysis

**Critical question:** Should disturbance-driven mortality be included in "baseline" vital rates for population modeling?

**Our approach:**
1. **Include all intervals** in the primary analysis — disturbance is part of the demographic reality *A. palmata* faces
2. **Flag the TP4→TP5 and TP5→TP6 intervals** as potentially disturbance-affected
3. **Run sensitivity analysis** excluding 2014-2015 intervals to estimate "non-catastrophe" vital rates
4. **Report both** — the population model with and without the disturbance event represents the range of plausible futures

This is consistent with our treatment of NOAA data, which includes all years (including bleaching/disease years) without exclusion.

---

## Data Format Notes

### Sheet 1 (colony data)
- **Wide format:** 878 rows x 16 columns (Site, Coral#, then 7 pairs of Date + LAI)
- **Merged header row:** Row 1 has season names (Winter 2010/2011, Spring 2012, etc.); Row 2 has column labels
- **Dates:** Excel serial numbers; actual dates span weeks within each "timepoint" (different sites surveyed on different days)
- **LAI columns:** Numeric live tissue area (cm^2). `0` = dead. `NA` = not yet monitored at that site/not measured
- **Some LAI columns read as character** (R coercion issue with mixed data) — need explicit `as.numeric()` conversion
- **376 of 878 colonies** have NA at TP1 — these colonies were tagged at later timepoints as new sites were added

### Sheet 2 (site locations)
- **27 rows** with Location, Site, Plot, Latitude, Longitude
- Coordinates in DMS-like format (e.g., "N25.37320", "W80.16032") — need parsing
- Some rows have multiple longitudes (e.g., "W80.16032 W80.16089") — likely plot corners

---

## Standardization Plan

1. **Pivot wide → long:** Create one row per colony per interval (consecutive timepoint pair)
2. **Compute survival:** `survived = LAI_next > 0` for colonies alive at current timepoint (`LAI_current > 0`)
3. **Compute growth:** `delta_size = LAI_next - LAI_current` for survivors; RGR = `(LAI_next - LAI_current) / LAI_current`
4. **Assign size classes:** Using standard breaks (0, 10, 100, 900, 4000, Inf)
5. **Tag disturbance:** Flag intervals crossing the 2014 catastrophe (TP4→TP5, TP5→TP6)
6. **Compute interval:** Exact days between per-colony survey dates
7. **Study identifier:** `neely_et_al_2022`
8. **Region:** `Florida Keys`
9. **Population type:** `Natural colony`

---

## Impact on Meta-Analysis

Adding Neely with **all intervals** (including catastrophe):
- N increases from ~5,200 to ~7,800 individual survival records
- Becomes second-largest Tier 1 study after NOAA
- Mean survival likely **decreases** substantially (overall 33.9% across 5 years)
- **Breaks the NOAA dominance** — first independent large-scale FL Keys dataset
- Natural colony representation increases (previously ~99% NOAA)
- Strengthens inference on geographic variation within FL Keys

Adding Neely **excluding catastrophe intervals** (TP4→TP5, TP5→TP6):
- Non-catastrophe intervals show ~85-95% annual survival
- More consistent with other studies' estimates
- Still contributes ~1,000+ survival records

**Recommended:** Run both and report the sensitivity.

---

## Related Files

- [disturbance_handling_decision.md](disturbance_handling_decision.md) -- Disturbance classification and inclusion rules
- [extraction_protocol.md](extraction_protocol.md) -- Inclusion/exclusion criteria and size conversion rules
- [extraction_details.md](extraction_details.md) -- Per-study verification table with audit status
- [study_characteristics.md](study_characteristics.md) -- PRISMA-style study characteristics table
- [data_integration_issues.md](data_integration_issues.md) -- Individual + summary data combination method
- [data_flow_diagram.md](data_flow_diagram.md) -- Mermaid diagram of the full data pipeline
- [risk_of_bias.md](risk_of_bias.md) -- Newcastle-Ottawa bias assessment per study
