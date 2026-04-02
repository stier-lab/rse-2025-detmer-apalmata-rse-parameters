# Environmental Data Provenance

**Purpose:** Document the source, access method, resolution, and limitations of all environmental and disturbance data used in this synthesis.

---

## 1. Thermal Stress: NOAA Coral Reef Watch Degree Heating Weeks (DHW)

### Source
**NOAA Coral Reef Watch (CRW) 5km Daily Global Satellite Coral Bleaching Monitoring Product, Version 3.1**

### Access
- **Primary endpoint:** `https://coastwatch.noaa.gov/erddap/griddap/noaacrwdhwDaily`
- **Variable:** `degree_heating_week` (degree-C weeks)
- **Alternative endpoint:** `https://oceanwatch.pifsc.noaa.gov/erddap/griddap/CRW_dhw_v1_0`
- **Data portal:** https://coralreefwatch.noaa.gov/product/5km/index_5km_dhw.php
- **ERDDAP access tutorial:** https://coralreefwatch.noaa.gov/instructions/Accessing_Coral_Reef_Watch_Data_via_Data_Servers_at_CoastWatch_20240403.pdf

### Specifications
| Parameter | Value |
|-----------|-------|
| Spatial resolution | 5 km (0.05 degree) |
| Temporal resolution | Daily |
| Coverage | Global, 60S-60N |
| Time range | 1985-03-25 to present |
| Input SST source | NOAA/NESDIS operational nighttime-only SST (CoralTemp v3.1) |
| Climatology | 1985-2012 monthly mean SST (CRW climatology) |
| DHW calculation | Accumulation of HotSpot values > 1C over a rolling 12-week window |

### How we queried it
- Script: `06_analysis/scripts/31_heat_stress_overlay.R`
- For each unique study site (lat/lon rounded to 0.1 degree) and survey year, we queried the maximum DHW during the warm season (June 1 - December 1)
- Query method: `httr::GET()` against ERDDAP REST API with rate limiting (0.5s between requests)
- Fallback: Literature lookup table for years/regions where ERDDAP returned no data

### Verification
- Script: `06_analysis/scripts/31b_verify_dhw.R`
- All 156 successfully queried site-years verified against the authoritative `noaacrwdhwDaily` dataset
- **Discrepancy: 0.000 DHW, Correlation: 1.0000** — values are perfectly accurate

### Classification thresholds (NOAA CRW standard)
| DHW | Category | Expected impact |
|-----|----------|----------------|
| 0 | No stress | — |
| 0-4 | Watch/Warning (minor) | Possible bleaching |
| 4-8 | Alert Level 1 (moderate) | Bleaching likely |
| >= 8 | Alert Level 2 (major) | Mass bleaching and mortality expected |

### Known limitations
1. **Satellite underestimates inshore heat stress by 1.5-2x.** Williams et al. (2017) showed in-situ DHW at Cheeca Rocks FL was 7.7 vs satellite 5.3 in 2014 (1.45x) and 10.9 vs 5.4 in 2015 (2.0x). Our values are conservative.
2. **5km pixel averages across reef and open water.** Shallow inshore reefs experience more extreme temperatures than the pixel average.
3. **Pre-1985 data unavailable.** Rogers et al. (1982) study years have no CRW data.
4. **16 site-years have no data** — mostly Curacao coastal cells that fall on the land mask of the 5km grid.

### Output files
| File | Description |
|------|-------------|
| `06_analysis/output/heat_stress_by_site_year.csv` | DHW for all 175 site-years |
| `06_analysis/output/heat_stress_by_site_year_verified.csv` | Same, verified against authoritative endpoint |
| `06_analysis/output/dhw_verification_log.csv` | Old vs new comparison with discrepancy flags |
| `06_analysis/output/dhw_verification_summary.csv` | Per-study DHW summary |
| `06_analysis/output/heat_stress_survival_analysis.csv` | Survival by heat stress category |
| `04_extraction/dhw_reference_table.md` | Published DHW values for major bleaching years |

### Key references
- Liu G, Heron SF, Eakin CM, et al. (2014) Reef-scale thermal stress monitoring of coral ecosystems: New 5-km global products from NOAA Coral Reef Watch. *Remote Sensing* 6:11579-11606.
- Skirving WJ, Heron SF, Marsh BL, et al. (2019) The relentless march of mass coral bleaching: a global assessment of changing heat stress. *Coral Reefs* 38:547-557.
- Williams DE, Miller MW, Bright AJ (2017) Thermal stress exposure, bleaching response, and mortality in the threatened coral *Acropora palmata*. *Marine Pollution Bulletin* 124:189-197.

---

## 2. Hurricane Exposure: NOAA IBTrACS

### Source
**International Best Track Archive for Climate Stewardship (IBTrACS), Version 4, Revision 01**
Maintained by NOAA National Centers for Environmental Information (NCEI)

### Access
- **Direct CSV download (Atlantic basin):** `https://www.ncei.noaa.gov/data/international-best-track-archive-for-climate-stewardship-ibtracs/v04r01/access/csv/ibtracs.NA.list.v04r01.csv`
- **Data portal:** https://www.ncei.noaa.gov/products/international-best-track-archive
- **Historical hurricane tracks viewer:** https://coast.noaa.gov/hurricanes/
- **NHC data archive:** https://www.nhc.noaa.gov/data/

### Specifications
| Parameter | Value |
|-----------|-------|
| Spatial resolution | 6-hourly track positions (lat/lon) |
| Temporal resolution | 6-hourly (with 3-hourly interpolation available) |
| Coverage | All global tropical cyclones |
| Time range | 1842 to present (Atlantic basin) |
| Variables used | SID, NAME, SEASON, ISO_TIME, LAT, LON, USA_WIND (kt), USA_SSHS (Saffir-Simpson category), USA_R34 (34-kt wind radii) |

### How we queried it
- Script: `06_analysis/scripts/33_hurricane_exposure.R`
- Downloaded full Atlantic basin CSV (~150MB)
- Computed Haversine great-circle distances from every 6-hourly track position to every study site
- Filtered to storms within 200 km of any study site, from 1979 onward
- Extracted: closest approach distance, category at closest approach, maximum wind speed

### Classification (reef impact severity)
| Distance + Category | Severity | Rationale |
|-------------------|----------|-----------|
| Direct hit (<50 km), Cat 3+ | Major | Severe structural damage, colony fragmentation/dislodgement |
| Within 100 km, Cat 1-2 | Moderate | Wave damage, breakage of branching corals |
| Within 200 km, TS | Minor | Elevated turbidity, minor wave stress |
| >200 km | None | No significant reef impact expected |

### Output files
| File | Description |
|------|-------------|
| `05_data/standardized/ibtracs_storm_exposure.csv` | All storms within 200km of study sites |
| `06_analysis/output/hurricane_exposure_summary.csv` | Per-region storm counts by category |

### Key references
- Knapp KR, Kruk MC, Levinson DH, Diamond HJ, Neumann CJ (2010) The International Best Track Archive for Climate Stewardship (IBTrACS). *Bulletin of the American Meteorological Society* 91:363-376.
- Knapp KR, Diamond HJ, Kossin JP, Kruk MC, Schreck CJ (2018) International Best Track Archive for Climate Stewardship (IBTrACS) Project, Version 4. NOAA NCEI. doi:10.25921/82ty-9e16.

---

## 3. Disturbance Event Database: Literature Compilation

### Source
Compiled from peer-reviewed literature, NOAA reports, and NHC records.

### Access
- File: `05_data/standardized/caribbean_disturbance_events.csv`
- Documentation: `04_extraction/disturbance_database_notes.md`

### Compilation method
1. **Web searches** for documented coral disturbance events at each of our 13 study regions during the years our studies were active
2. **Cross-referencing** study publications for mentions of hurricanes, bleaching, disease, and other disturbances
3. **NOAA Coral Reef Watch** bleaching alerts and reports
4. **NHC tropical cyclone reports** for hurricane impacts
5. **Published Caribbean coral health assessments** (e.g., GCRMN Status of Caribbean Coral Reefs reports)

### Specifications
| Parameter | Value |
|-----------|-------|
| Events catalogued | 93 |
| Regions covered | 13 |
| Year range | 1979-2024 |
| Event types | Hurricane (29), bleaching (29), disease (31), cold snap (1), other (3) |
| Severity levels | Minor (24), moderate (30), major (23), catastrophic (16) |

### Known limitations
1. **Literature bias toward documented events.** Smaller disturbances or those at unmonitored sites may be missing.
2. **Severity classification is semi-quantitative.** Based on published reports, not standardized metrics.
3. **Temporal precision varies.** Some events are dated to the month; others only to the year or season.
4. **SCTLD entries note that *A. palmata* is immune** to this disease, but the disease is included because it affects reef community structure.

### Key references (primary sources for database)
- Eakin CM, Morgan JA, Heron SF, et al. (2010) Caribbean corals in crisis: Record thermal stress, bleaching, and mortality in 2005. *PLoS ONE* 5:e13969.
- Lirman D, Schopmeyer S, Manzello D, et al. (2011) Severe 2010 cold-water event caused unprecedented mortality to corals of the Florida reef tract. *PLoS ONE* 6:e23047.
- Williams DE, Miller MW (2012) Attributing mortality among drivers of population decline in *Acropora palmata* in the Florida Keys. *Coral Reefs* 31:369-382.
- Precht WF, Gintert BE, Fura R, et al. (2025) Functional extinction of *Acropora* from Florida's Coral Reef. *Science* (in press).
- Neely KL, Lewis CL, Lunz KS, Kabay L (2022) Rapid population decline of the pillar coral *Dendrogyra cylindrus* along the Florida Reef Tract. *Frontiers in Marine Science* 8:799187.

---

## 4. Integration with Survival Data

### How environmental data is merged with demographic records

Each individual survival record in `apal_surv_ind.csv` is characterized by:
- `survey_yr`: the year at the START of the observation interval
- `region`: Caribbean region
- `latitude`, `longitude`: site coordinates

Environmental data is merged by:
1. **DHW:** Matched by rounded lat/lon (0.1 degree) and survey_yr. Each colony gets the maximum DHW experienced during the warm season of its observation interval.
2. **Disturbance events:** Matched by region and survey_yr. A colony observed in 2014 may have been exposed to disturbances that occurred between its survey date and the next survey (~1 year later).
3. **Hurricane exposure:** Matched by region and year. Storms that passed within 200 km during the observation interval are flagged.

### Temporal alignment caveat
The `survey_yr` represents when a colony was last measured ALIVE, not when it died. A colony surveyed alive in Fall 2013 and found dead in Fall 2014 (coded as survey_yr=2013, survived=0) was killed sometime during that interval. The disturbance causing death may have occurred in 2014 (e.g., the thermal bleaching), but the record is associated with survey_yr=2013. This is a fundamental limitation of interval-censored survival data.

### Scripts that perform the integration
| Script | What it merges |
|--------|---------------|
| `31_heat_stress_overlay.R` | DHW → survival data by lat/lon/year |
| `32_disturbance_survival_analysis.R` | Disturbance events → survival data by region/year |
| `33_hurricane_exposure.R` | IBTrACS storms → study sites by distance/year |

---

## 5. Data NOT included (and why)

| Data source | Why not included |
|-------------|-----------------|
| NOAA OISST (daily SST) | DHW is the standard metric for bleaching stress; raw SST adds complexity without additional insight |
| Chlorophyll-a (ocean color) | Not directly relevant to coral thermal stress or hurricane damage |
| Wave height / swell data | Would complement hurricane damage assessment but adds substantial complexity; damage severity is better captured by IBTrACS wind speed + distance |
| Sedimentation / turbidity | Locally important but no pan-Caribbean satellite product at reef-relevant resolution |
| Ocean acidification (pH/aragonite) | Changes too slowly to explain inter-annual survival variation; chronic stressor, not acute |
| SCTLD surveillance data | *A. palmata* is immune to SCTLD; included in disturbance database for context only |
