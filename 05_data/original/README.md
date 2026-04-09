# Original Data Sources

<!-- READ-ONLY: All .csv and .xlsx files in this directory are chmod 444.
     Do NOT modify raw data. If corrections are needed, apply them in
     06_analysis/scripts/01_data_preparation.R and document the change. -->

This directory contains raw data files from published studies and monitoring programs used to parameterize the *Acropora palmata* (Elkhorn Coral) demographic model.

## Overview

| Source | Files | Records | Data Types |
|--------|-------|---------|------------|
| NOAA Demographic Survey | 3 files | ~12,000 | Colony tracking, locations, survey dates |
| Pausch et al. 2018 | 2 files | ~6,400 | Fragment survival experiments |
| Rosales et al. 2024 | 1 file | ~9,000 | Fragment restoration tracking |
| Kuffner et al. 2020 | 2 files | ~220 | Outplant growth measurements |
| USGS USVI | 1 file | 120 | Fragment growth rates |
| Maurer et al. 2022 | 1 file | 740 | Nursery survival |
| Mendoza Quiroz et al. 2023 | 1 file (xlsx) | Variable | Nursery and outplant data |
| Fundemar | 3 files (xlsx) | Variable | Fragment and recruit monitoring |

---

## CSV Files

### NOAA_Tagged_Colony_Data.csv
**Source:** [NOAA NCEI Accession 0142175](https://www.fisheries.noaa.gov/inport/item/22436)

Long-term demographic monitoring of tagged *A. palmata* colonies in Florida Keys, Curacao, and Navassa from 2004-2024.

| Column | Description | Units |
|--------|-------------|-------|
| Region | Geographic region (Florida Keys, Curacao, Navassa) | - |
| Reef | Name of reef | - |
| Plot | Sampling plot identifier | - |
| TagID | Unique colony identifier | - |
| Q | Survey quarter (1-68) | - |
| L | Colony length | cm |
| W | Colony width | cm |
| H | Colony height | cm |
| % Live | Percentage of live tissue | % |
| Colony Type | BC (branching colony), JC (juvenile colony), etc. | - |
| RM Rank | Recent mortality rank (0-3) | - |
| RM1-3 | Recent mortality causes (WBD, FS, PFB, etc.) | - |
| Bleach Rank | Bleaching severity (0-3) | - |
| Dmsl Rank | Disease rank | - |
| Snail Count | Coralliophila abbreviata count | count |

**Notes:**
- Colonies considered dead if skeleton found with no tissue OR no skeleton/tissue remaining
- Size measured as live planar area = L × W × (% Live / 100)
- Largest single data source for the database

---

### NOAA_Plot_Locations_Survey_Coverage.csv
**Source:** NOAA demographic monitoring metadata

Plot-level information including coordinates, depth, and survey coverage across quarters.

| Column | Description | Units |
|--------|-------------|-------|
| Region | Geographic region | - |
| Reef | Reef name | - |
| Plot | Plot identifier | - |
| Latitude | Plot latitude | °N |
| Longitude | Plot longitude | °W |
| Depth(m) | Site depth | m |
| TotalSurveys | Number of surveys conducted | count |
| Q01-Q68 | Survey coverage codes per quarter | codes |

---

### NOAA_Dem_Survey_Dates.csv
**Source:** NOAA demographic monitoring metadata

Maps survey quarters (Q) to calendar dates for each region/reef/plot.

| Column | Description |
|--------|-------------|
| Region | Geographic region |
| Reef | Reef name |
| Plot | Plot identifier |
| Q | Survey quarter number |
| Date | Survey date (M/D/YYYY) |

---

### Pausch_2018_Data_Table_Genet.csv
**Source:** [Pausch et al. 2018](https://www.int-res.com/abstracts/meps/v592/meps12488), [NOAA InPort 26790](https://www.fisheries.noaa.gov/inport/item/26790)

Genet experiment comparing fragment performance on forereef vs. nearshore patch reefs.

| Column | Description | Units |
|--------|-------------|-------|
| Survey Date | Date of survey | M/D/YYYY |
| Reef | Reef name | - |
| Latitude | Site latitude | °N |
| Longitude | Site longitude | °W |
| Habitat | Offshore or Nearshore | - |
| Full_Genet_Name | Genet source identifier | - |
| TagID | Fragment identifier | - |
| Depth | Depth | ft |
| Status | OK, Dead, Missing | - |
| Proportion_Live | Live tissue proportion | 0-1 |
| Length, Width, Height | Fragment dimensions | cm |
| Snails | Predatory snail count | count |

---

### Pausch_2018_Data_Table_Size.csv
**Source:** [Pausch et al. 2018](https://www.int-res.com/abstracts/meps/v592/meps12488)

Size experiment comparing large vs. small fragment survival while controlling for genet.

| Column | Description | Units |
|--------|-------------|-------|
| Survey Date | Date of survey | M/D/YYYY |
| Reef | Reef name | - |
| Latitude | Site latitude | °N |
| Longitude | Site longitude | °W |
| Full Genet Name | Genet source | - |
| TagID | Fragment identifier | - |
| Treatment | Lg (large) or Sm (small) | - |
| Depth | Depth | ft |
| Status | OK, Dead, Missing | - |
| Proportion_Live | Live tissue proportion | 0-1 |
| Length, Width, Height | Fragment dimensions | cm |

---

### Rosales_et_al_2024.csv
**Source:** [Rosales et al. 2024](https://www.nature.com/articles/s43247-024-01816-7)

Fragment tracking data from Florida Keys restoration study.

| Column | Description | Units |
|--------|-------------|-------|
| reef | Reef identifier | - |
| Genotype | Genet identifier | - |
| Fragment_num | Fragment number within genet | - |
| collection_date | Date collected | D-Mon-YY |
| day, Month, Year | Date components | - |
| Survey# | Survey number | - |
| Fragment_number | Fragment identifier | - |
| LiveFrag | Alive (1) or dead (0) | 0/1 |
| ColType | Colony type (L = large, S = small) | - |
| L, W, H | Dimensions (if available) | cm |
| live_per | Percent live tissue | % |
| Adjusted Area | Live planar area estimate | cm² |

---

### Kuffner_et_al_2020_Palmata_growth_FL_USA.csv
**Source:** [Kuffner et al. 2020](https://www.int-res.com/abstracts/esr/v43/esr01083), [USGS Data Release](https://coastal.er.usgs.gov/data-release/doi-P9KZEGXY/)

Growth measurements for outplanted *A. palmata* fragments in Florida.

| Column | Description | Units |
|--------|-------------|-------|
| Coral_ID | Fragment identifier | - |
| Genet_ID | Genet source | - |
| Site_ID | Site identifier | - |
| Time_interval | Measurement interval (1-3) | - |
| Condition | live, dead | - |
| Calcif_mg_cm2_d | Calcification rate | mg/cm²/day |
| del_SA_mm2_d | Surface area change rate | mm²/day |
| del_height_mm_d | Height change rate | mm/day |

---

### Kuffner_et_al_2020_sizes.csv
**Source:** [Kuffner et al. 2020](https://www.int-res.com/abstracts/esr/v43/esr01083)

Initial fragment sizes for the growth study.

| Column | Description | Units |
|--------|-------------|-------|
| Coral_ID | Fragment identifier | - |
| Site_ID | Site identifier | - |
| Length_cm | Fragment length | cm |
| Width_cm | Fragment width | cm |
| Prop_alive | Proportion alive (all = 1) | 0-1 |

---

### USGS_Palmata_growth_VI_USA.csv
**Source:** [USGS Coral Growth VI USA](https://cmgds.marine.usgs.gov/catalog/spcmsc/Coral_growth_VI_USA_metadata.faq.html)

Growth data for outplanted *A. palmata* fragments in USVI (2019-2021).

| Column | Description | Units |
|--------|-------------|-------|
| Site_ID | Site identifier (SFR, NER, NWR) | - |
| Latitude | Site latitude | °N |
| Longitude | Site longitude | °W |
| Coral_ID | Fragment identifier | - |
| Genet_ID | Genet source | - |
| Time_interval | Measurement interval (1-4) | - |
| Calcif_mg_cm2_d | Calcification rate | mg/cm²/day |
| Calcif_del_SA_cm2_hy | Surface area change | cm²/half-year |
| Calcif_del_ht_mm_hy | Height change | mm/half-year |
| Condition | alive, dead | - |

**Time intervals:**
- 1: June 2019 - November 2019
- 2: November 2019 - June 2020
- 3: June 2020 - February 2021
- 4: February 2021 - August 2021

---

### Maurer2022_SurvivalData.csv
**Source:** [Maurer et al. 2022](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0267034)

Survival data from coral fragments on line nurseries in the Bahamas.

| Column | Description | Units |
|--------|-------------|-------|
| treatment | Treatment × Year combination | - |
| nursery | Nursery name | - |
| line | Line number | - |
| species | Coral species (ACER, APAL) | - |
| depth | Depth | ft |
| coral.id | Fragment identifier | - |
| colony | Colony/genet ID | - |
| harvest.year | Year harvested | - |
| year | Survey year (Year 1, 2, 3) | - |
| survival | Survived (1) or died (0) | 0/1 |

**Notes:**
- Initial fragment size assumed ~5×5 cm
- Only Year 1 data used (no size info for Years 2-3)

---

## Excel Files

### MendozaQuiroz2023Data.xlsx
**Source:** [Mendoza Quiroz et al. 2023](https://peerj.com/articles/15813/)

*A. palmata* restoration data from Mexican Caribbean including in situ nursery and outplanting experiments.

**Sheets:**
- Nursery growth data with diameter measurements
- Cuevones reef outplant data
- Picudas reef outplant data (length × width)

**Notes:**
- Nursery/Cuevones: size = diameter² (assumed square)
- Picudas: size = length × width

---

### Fundemar_Crecimiento_Fragmentos_APAL.xlsx
**Source:** Fundemar (Dominican Republic), shared by Maria

Fragment growth data from in situ nursery tables near Sombrero restoration site.

**Structure:**
- 6 source localities (Reef Balls, El Play, Catalina, Minitas, Coralina, Majagual)
- Fragments sub-fragmented and placed in PVC table structures
- Regular maintenance with algal scrubbing

**Notes:**
- Only Table 1 has full annual data
- Tables 2-6 span only 5 months

---

### Fundemar_Matriz_Supervivencia_Reclutas_Unificada.xlsx
**Source:** Fundemar (Dominican Republic)

Survival tracking of outplanted recruits over time.

**Notes:**
- Focused on 12-month survival
- Removed cases where recruits appeared after outplanting
- Youngest recruits with size data were 5 months old

---

### Fundemar_Matriz_area_reclutas.xlsx
**Source:** Fundemar (Dominican Republic)

Size measurements of outplanted recruits.

**Notes:**
- Data do not track individuals over time
- Growth estimated from change in mean size between time points
- 2020 cohort: 5-12 months; 2019 cohort: 10-16 months

---

## Data Processing Notes

### Size Standardization
All sizes are standardized to **live planar area (cm²)** following Vardi et al. 2012:

```
Live Planar Area = Length × Width × (% Live / 100)
```

For studies reporting only length/diameter:
- **Fragments**: Used average width:length ratio from datasets with both measurements
- **Colonies**: Used interquartile range of width:length ratios from colony datasets
- **Recruits**: Assumed circular shape (area = π × diameter²/4)

### Time Interval Adjustments
Survival rates adjusted to annual rates when sampling intervals ≠ 1 year:
- **< 1 year, died**: Annual survival = 0 (known)
- **> 1 year, survived**: Annual survival = 1 (known)
- **Other cases**: Interpolated/extrapolated using regional proportions

---

## References

- Kuffner, I.B. et al. (2020). Restoration of staghorn coral (*Acropora palmata*) outplant survival and growth in relation to a marine heatwave. *Endangered Species Research* 43: 417-428.
- Maurer, A.S. et al. (2022). Three years of coral fragment growth and survival at line nurseries in the Bahamas. *PLOS ONE* 17(5): e0267034.
- Mendoza Quiroz, S. et al. (2023). A multi-step approach to restoration of *Acropora palmata*. *PeerJ* 11: e15813.
- Pausch, R.E. et al. (2018). Restoration of staghorn coral: assessing fragment condition and outplant success. *Marine Ecology Progress Series* 592: 95-106.
- Rosales, S.M. et al. (2024). Genotype-dependent coral resilience to disease and thermal stress. *Communications Earth & Environment* 5: 634.
- USGS (2021). Experimental growth data for *Acropora palmata* in USVI.
- Williams, D.E. et al. (2025). NOAA Elkhorn coral demographic monitoring 2004-2024. NCEI Accession 0142175.

---

*Last updated: 2025-12-28*
