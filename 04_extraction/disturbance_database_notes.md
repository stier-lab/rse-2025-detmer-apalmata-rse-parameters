# Caribbean Disturbance Events Database

**File:** `05_data/standardized/caribbean_disturbance_events.csv`
**Created:** March 2026
**Purpose:** Comprehensive record of documented disturbance events at study regions during active study periods for the *Acropora palmata* size-dependent demography synthesis.

---

## How the Database Was Compiled

### Approach

The database was constructed through systematic web searches for documented disturbance events at each of the 12 study regions during the years when studies in our meta-analysis were actively collecting data. Searches targeted five categories of disturbance: hurricanes, bleaching events, disease outbreaks, cold snaps, and other events (sargassum influx, pandemic disruptions, sedimentation).

### Search Strategy

For each region and time period, the following search terms were used:
- `"[region] coral bleaching [year]"`
- `"[region] hurricane damage reef [year range]"`
- `"Acropora palmata mortality [region]"`
- `"SCTLD [region] arrival date"`
- `"coral reef disturbance Caribbean timeline"`
- `"[region] white band disease white pox"`
- `"[region] degree heating weeks DHW"`

### Sources Consulted

**Primary sources:**
- NOAA Coral Reef Watch (CRW) -- DHW satellite products and bleaching alerts
- NOAA National Hurricane Center (NHC) -- storm tracks, categories, dates
- NOAA Florida Keys National Marine Sanctuary (FKNMS) -- regional assessments
- USGS publications on coral disease and hurricane impacts
- Florida Department of Environmental Protection -- SCTLD response data

**Peer-reviewed literature:**
- Eakin et al. 2010 (*PLoS ONE*) -- Caribbean corals in crisis: 2005 thermal stress
- Miller et al. 2009 (*Coral Reefs*) -- Disease following 2005 bleaching in USVI
- Rogers & Muller 2012 (*Coral Reefs* 31:807-819) -- A. palmata bleaching/disease/recovery in St. John 2003-2010
- Lirman et al. 2011 (*PLoS ONE*) -- 2010 cold-water event mortality in FL
- Colella et al. 2012 (*Coral Reefs*) -- Cold-water event catastrophic benthic mortality
- Kemp et al. 2016 (*Ecosphere*) -- Life after cold death in FL Keys
- Weil et al. 2009 -- Temporal variability and impact of coral diseases in La Parguera, PR 2003-2007
- Sutherland et al. 2016 (*Phil Trans R Soc B*) -- Shifting white pox aetiologies in FL Keys 1994-2014
- Neely et al. 2022 (*Front Mar Sci*) -- Population trajectory and stressors of A. palmata in FL Keys
- Alvarez-Filip et al. 2019 (*PeerJ*) -- Rapid spread of SCTLD in Mexican Caribbean
- Cunning et al. 2025 (*Science*) -- Functional extinction of FL reef-building corals after 2023 heatwave
- Meiling et al. 2021 (*Front Mar Sci*) -- SCTLD emergence in USVI
- Dahlgren et al. 2021 (*Front Mar Sci*) -- SCTLD outbreak patterns in Bahamas
- Rogers et al. 1982 (*Science*) -- Hurricane David effects on A. palmata at St. Croix

**Regional monitoring programs:**
- AGRRA (Atlantic and Gulf Rapid Reef Assessment)
- DCNA (Dutch Caribbean Nature Alliance) -- SCTLD monitoring in Dutch Caribbean
- VI-CDAC (Virgin Islands Coral Disease Advisory Committee)
- FUNDEMAR (Dominican Republic)
- Carmabi (Curacao)
- ANGARI Foundation (Bahamas post-Dorian assessments)

---

## Database Structure

| Column | Description | Values |
|--------|-------------|--------|
| `region` | Study region matching the `region` column in `apal_surv_ind.csv` and `apal_surv_summ.csv` | Florida Keys, Dry Tortugas, Curacao, Navassa, US Virgin Islands, Puerto Rico, Jamaica, British Virgin Islands, Virgin Gorda, Dominican Republic, Mexican Caribbean, Cuba, Bahamas |
| `year` | Year of the disturbance event | 1979--2024 |
| `event_type` | Category of disturbance | hurricane, bleaching, disease, cold_snap, other |
| `event_name` | Specific name/identifier of the event | e.g., "Hurricane Irma (Cat 3-4 at Keys)", "2005 Caribbean mass bleaching", "SCTLD arrival" |
| `severity` | Qualitative severity rating | minor, moderate, major, catastrophic |
| `dhw_satellite` | Degree Heating Weeks from NOAA CRW where available | Numeric range (e.g., "8-12") or NA |
| `documented_mortality` | Description of documented coral mortality | Free text |
| `source` | Citation(s) for the event documentation | Author-year or agency abbreviation |
| `studies_affected` | Which of our 17 studies were collecting data at this location and time | Study IDs separated by semicolons |
| `notes` | Additional context | Free text |

### Severity Definitions

| Rating | Criteria |
|--------|----------|
| **minor** | Localized/minimal impacts; below mass disturbance thresholds; no documented colony-level mortality |
| **moderate** | Widespread but recoverable impacts; partial bleaching; disease prevalence elevated but not causing mass mortality; hurricane Cat 1-2 with moderate reef damage |
| **major** | Significant mortality or habitat damage; mass bleaching (DHW 6-12); disease outbreaks causing >20% colony-level mortality; hurricane Cat 3+ with documented reef damage |
| **catastrophic** | Unprecedented or extreme impacts; mass mortality (DHW >12); >50% colony mortality; functional extinction of local populations; Cat 5 hurricanes with severe reef damage |

---

## Summary Statistics

- **Total events:** 93
- **Regions covered:** 13
- **Year range:** 1979--2024
- **Events by type:** disease (31), bleaching (29), hurricane (29), other (3), cold_snap (1)
- **Events by severity:** moderate (30), minor (24), major (23), catastrophic (16)
- **Most-documented region:** Florida Keys (26 events)

---

## Events by Region and Type

### Florida Keys (2004-2024) -- 26 events
Active studies: NOAA_survey, neely_et_al_2022, pausch_et_al_2018, kuffner_et_al_2020, rosales_et_al_2024, williams_miller_2010

Key disturbances:
- **2005 hurricane season** (Dennis, Katrina, Rita, Wilma): 4 storms; Wilma most damaging (52% A. palmata tissue loss)
- **January 2010 cold snap**: Catastrophic; worst cold mortality on record; min temp 9.5C
- **2014-2015 bleaching**: Part of 3rd global event; 7.7 DHW; 38% bleached + 37% paled
- **2014 disease event**: Catastrophic disease in Neely monitoring (53% survival TP4-TP5)
- **2017 Hurricane Irma**: Cat 3-4; severe A. palmata damage
- **2018 SCTLD arrival**: A. palmata IMMUNE but reef community altered
- **2023 marine heatwave**: Functional extinction; 98-100% of A. palmata died; <150 individuals remain

### Curacao (2007-2015) -- 5 events
Active study: NOAA_survey

Key disturbances:
- **2008 Hurricane Omar**: 70% of reef at <10m damaged, but most reef is deeper
- **2010 bleaching**: Moderate; southern Caribbean hit harder than in 2005
- **2014 bleaching**: Part of 3rd global event

### Navassa (2009-2012) -- 3 events
Active study: NOAA_survey

Key disturbances:
- **Chronic disease**: White disease documented at high prevalence since 2004
- **2010 bleaching**: Expected moderate stress based on regional patterns
- **2012 recovery**: No active bleaching or disease found -- possible refuge

### US Virgin Islands (1979-2021) -- 16 events
Active studies: USGS_USVI_exp, garrison_ward_2008, rogers_muller_2012, rogers_et_al_1982

Key disturbances:
- **1979 Hurricanes David + Frederic**: A. palmata stands reduced by half at St. Croix
- **1989 Hurricane Hugo**: A. palmata at Buck Island reduced from 5% to 0.8%
- **2005 bleaching + disease**: Most severe event in region; 60% coral cover decline; A. palmata bleached for first time
- **2003-2009 chronic white pox**: 89.9% of A. palmata colonies showed disease
- **2017 Irma + Maria**: Two Cat 5 hurricanes within 2 weeks
- **2019 SCTLD arrival**: Spread to all islands by Sept 2020; A. palmata immune

### Puerto Rico (1999-2008) -- 8 events
Active studies: vardi_2011, bruckner_bruckner_2001, ortiz_prosper_2005

Key disturbances:
- **1999 Hurricane Lenny**: Unusual track; leeward damage
- **Chronic disease 1999-2007**: White band, white pox, white plague, yellow band all documented
- **2005 bleaching + disease**: >80% bleached; massive disease outbreak

### Jamaica (2003-2008) -- 5 events
Active study: vardi_2011

Key disturbances:
- **2005 bleaching + disease**: Significant but less severe than eastern Caribbean
- **2007 Hurricane Dean**: Cat 4 near Jamaica; physical damage to reefs

### British Virgin Islands (2006-2012) -- 6 events
Active study: forrester_et_al_2013

Key disturbances:
- **2005 bleaching aftermath**: >90% bleached; preceded study start
- **2010 bleaching + Hurricane Earl**: Compound disturbance

### Virgin Gorda (2003-2008) -- 3 events
Active study: vardi_2011

Key disturbances:
- **2005 bleaching + disease**: Catastrophic; same as BVI/USVI regional event

### Dominican Republic (2020-2021) -- 4 events
Active studies: fundemar_fragments, fundemar_recruits

Key disturbances:
- **SCTLD spreading since 2019**: Major disease pressure on non-Acropora species
- **COVID-19 disruptions**: Possible effects on nursery maintenance

### Mexican Caribbean (2016-2021) -- 8 events
Active study: mendoza_quiroz_et_al_2023

Key disturbances:
- **2018 SCTLD arrival**: Rapid spread; 30% of affected species killed
- **2018-2019 sargassum influx**: Massive; 78-species die-off from hypoxia
- **2020 Hurricanes Delta + Zeta**: Two hurricanes within 3 weeks; 1200 corals displaced
- **2021 Hurricane Grace**: Third hurricane in 12 months

### Cuba (2020-2023) -- 3 events
Active study: ramos_romero_et_al_2025

Key disturbances:
- **2022 Hurricane Ian**: Cat 3 at western Cuba
- **2023 marine heatwave**: All elkhorn at Guanahacabibes died; 60-80% bleaching

### Bahamas (2017) -- 4 events
Active study: maurer_et_al_2022

Key disturbances:
- **2015 bleaching**: Part of 3rd global event (preceded 2017 study)
- **2016 Hurricane Matthew aftermath**: Possible residual effects during study

---

## Known Gaps and Limitations

### Data gaps

1. **DHW values**: Satellite-derived DHW values are provided as ranges for most bleaching events, sourced from NOAA CRW summaries. Precise pixel-level DHW for each study site would require querying CRW's virtual station data (available at `coralreefwatch.noaa.gov/product/vs/gauges/`).

2. **Navassa**: Extremely limited monitoring data due to remoteness. Only 3-4 expedition-based surveys during our study period (2004, 2006, 2008, 2012). Bleaching and disease events between surveys are inferred from regional patterns.

3. **Jamaica**: Limited reef monitoring data during Vardi study period (2003-2008). Hurricane Dean damage to Jamaican reefs specifically (vs. Chinchorro Bank) is poorly documented.

4. **Cuba**: Limited access to Cuban reef monitoring data; most information from WCS and Ocean Foundation reports. Hurricane Ian's specific impacts on coral restoration sites not documented.

5. **Bahamas**: Maurer study was in 2017; post-Dorian (2019) and post-SCTLD impacts documented but after the study period.

6. **Subsurface cold events**: The 2010 cold snap was well documented for Florida, but cold stress at other regions during the same period is not captured.

### Methodological limitations

1. **Severity ratings are qualitative** and based on reported impacts from literature, not a standardized rubric. Different studies report impacts at different scales (colony-level, reef-level, region-level).

2. **SCTLD and A. palmata**: While Acropora palmata is immune to SCTLD, the disease drastically alters reef community composition. Indirect effects on A. palmata (e.g., loss of competitive species, altered herbivore communities) are not captured by the "immune" designation.

3. **Compound events**: Some years had multiple overlapping disturbances (e.g., USVI 2005 = bleaching + disease; Mexican Caribbean 2018 = SCTLD + sargassum). The database records these as separate events, but their compound effects are greater than the sum of parts.

4. **Pre-study disturbances**: Some catastrophic events occurred before a study's monitoring period but strongly influence initial conditions (e.g., 2005 bleaching preceded Forrester's 2006-2012 BVI study; historical white band disease preceded all studies).

5. **Chronic stressors not well captured**: Ocean acidification, sedimentation from land-based sources, nutrient pollution, and overfishing are chronic stressors not included as discrete events. These affect baseline survival and growth but are not episodic.

---

## How to Use This Database in Analysis

### Merging with survival/growth data

The database can be joined to the individual-level and summary-level datasets by matching on `region` and `year` (using `survey_yr` from the demographic data). Example in R:

```r
# Load disturbance database
disturbances <- read.csv("05_data/standardized/caribbean_disturbance_events.csv",
                         stringsAsFactors = FALSE)

# Create a binary disturbance flag per region-year
disturbance_flags <- disturbances %>%
  group_by(region, year) %>%
  summarise(
    n_disturbances = n(),
    max_severity = max(factor(severity,
      levels = c("minor", "moderate", "major", "catastrophic"),
      ordered = TRUE)),
    had_hurricane = any(event_type == "hurricane"),
    had_bleaching = any(event_type == "bleaching"),
    had_disease = any(event_type == "disease"),
    had_cold = any(event_type == "cold_snap"),
    max_dhw = max(as.numeric(gsub("-.*", "", dhw_satellite)), na.rm = TRUE),
    .groups = "drop"
  )

# Merge with survival data
surv_data <- surv_data %>%
  left_join(disturbance_flags, by = c("region" = "region", "survey_yr" = "year"))

# Observations without a matching disturbance event get NA (= no documented disturbance)
surv_data$n_disturbances[is.na(surv_data$n_disturbances)] <- 0
```

### Analytical applications

1. **Disturbance as a moderator in meta-analysis**: Test whether studies/regions with documented catastrophic disturbances during the monitoring period show lower survival estimates.

2. **Temporal context for LOSO sensitivity**: When removing NOAA (78% of data), compare whether non-NOAA studies experienced different disturbance regimes.

3. **Survival threshold analysis**: Examine whether low-survival intervals correspond to documented disturbances (Script 02).

4. **Population model context**: Discuss whether the transition matrix represents "average" or "disturbance-influenced" conditions based on the disturbance history during contributing studies.

5. **Natural vs. restoration comparison**: Test whether the non-significant difference (p=0.110) between population types could be confounded by differential disturbance exposure.

### Important caveats for analysis

- **A. palmata is immune to SCTLD**: Do not treat SCTLD events as direct mortality drivers for A. palmata. Include only as potential indirect/community-level effects.
- **Time-interval mismatch**: Some survival intervals span multiple years. A disturbance in any year of the interval should be flagged.
- **Severity is relative**: A "moderate" bleaching event in the Florida Keys and a "moderate" event in Curacao may represent very different absolute impacts due to different reef conditions and species composition.
