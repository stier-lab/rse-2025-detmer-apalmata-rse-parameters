# Disturbance Handling Decision

**Decision date:** 2026-04-01
**Decision:** Include all observation intervals in the primary analysis regardless of disturbance exposure. Report sensitivity analysis excluding flagged intervals.

---

## The Problem

Three categories of disturbance are present in the data:

| Study | Flag | N records | Survival | Context |
|-------|------|-----------|----------|---------|
| NOAA_survey | `storm` | 571 | 85.1% | FL Keys (91%) + Curacao (55%); storms are part of normal FL Keys regime |
| neely_et_al_2022 | `disease_2014` | 639 | 53.2% | 2014-2015 thermal bleaching + *Coralliophila* predation (Williams et al. 2017; flag name is a misnomer) |
| neely_et_al_2022 | `disease_2014_aftermath` | 375 | 61.3% | Continued post-bleaching mortality |
| pausch_et_al_2018 | *none* | 969 | 57.4% | FL Keys 2015-2016; same bleaching event as Neely but unflagged |
| All others | *none* | varies | varies | Many span hurricane/disease years but disturbance not recorded |

Only 2 of 17 studies have any disturbance flagging. The remaining 15 studies almost certainly include disturbance-affected intervals but lack metadata to identify them.

---

## Decision Rationale

### 1. Asymmetric flagging makes selective exclusion incoherent

Excluding Neely's flagged disease intervals (53% survival) while retaining Pausch's unflagged data from the same time and place (57% survival, FL Keys 2015-2016) creates a systematic bias: we'd clean the data we can see while leaving equivalent noise in the data we can't. This is worse than either including or excluding everything.

### 2. Disturbance IS the demographic regime

*A. palmata* faces disease outbreaks (white band, white pox, SCTLD), hurricanes, bleaching, and cold snaps as recurring threats. A population viability assessment that excludes these events produces an optimistic baseline that no real population will experience. The question is not "what is survival under ideal conditions?" but "what is survival under the conditions this species actually faces?"

### 3. NOAA storms are negligible

NOAA storm-flagged intervals show 85.1% survival vs 86.2% non-storm — a 1.1 pp difference. Storms in the Florida Keys are a normal part of the ecological regime and do not warrant exclusion.

### 4. The sensitivity analysis demonstrates robustness

Excluding all flagged disturbance intervals shifts the Tier 1 pooled survival by +2.7 pp (75.9% → 78.6%). This is small relative to:
- The 95% prediction interval (39-95%)
- Between-study heterogeneity (I² = 96.6%)
- The confidence interval width (~15 pp)

The synthesis is robust to the inclusion or exclusion of known disturbance events.

### 5. Historical precedent

Published *A. palmata* population models (Vardi et al. 2012) do not exclude disturbance years. The NOAA monitoring program includes all years in its published vital rates. Our approach is consistent with established practice.

---

## Implementation

1. **Primary analysis**: ALL intervals included. No data excluded based on disturbance.
2. **Disturbance column**: Retained in the data as metadata. Values: `storm` (NOAA), `disease_2014` (Neely), `disease_2014_aftermath` (Neely), `NA` (unknown/none).
3. **Sensitivity analysis** (script 30): Tests four scenarios:
   - All data (primary)
   - Excluding Neely disease intervals only
   - Excluding all flagged disturbance (Neely disease + NOAA storm)
   - Neely non-disturbance intervals only
4. **Methods text**: "All observation intervals were included regardless of disturbance exposure, as catastrophic events (disease, storms) are an integral component of the demographic regime. Disturbance-flagged intervals are identified in the data and a sensitivity analysis excluding them is provided (Supplementary Fig. SXX)."
5. **Discussion text**: Note that estimates represent average conditions including disturbance events, not baseline conditions, and that this is appropriate for population viability assessment.

---

## What This Means for the Population Model

The transition matrix (script 13) uses ALL individual-level data to estimate size-specific survival and growth transition probabilities. With the 2014 disease event included:

- SC2-SC3 survival estimates are ~3-6 pp lower than without disturbance
- This propagates through to a slightly lower lambda
- The bootstrap confidence interval already captures the disturbance variance (study-level resampling includes/excludes Neely iterations)
- Stochastic lambda (Tuljapurkar approximation) explicitly models between-study variance, which now includes the Neely catastrophe contribution

The population model thus represents a realistic assessment of population trajectory under the historical disturbance regime, not an idealized baseline.

---

## Related Files

- [neely_2022_data_integration.md](neely_2022_data_integration.md) -- Neely et al. 2022 integration (includes 2014 catastrophe details)
- [extraction_protocol.md](extraction_protocol.md) -- Inclusion/exclusion criteria and size conversion rules
- [extraction_details.md](extraction_details.md) -- Per-study verification table with audit status
- [study_characteristics.md](study_characteristics.md) -- PRISMA-style study characteristics table
- [data_integration_issues.md](data_integration_issues.md) -- Individual + summary data combination method
- [data_flow_diagram.md](data_flow_diagram.md) -- Mermaid diagram of the full data pipeline
- [risk_of_bias.md](risk_of_bias.md) -- Newcastle-Ottawa bias assessment per study
