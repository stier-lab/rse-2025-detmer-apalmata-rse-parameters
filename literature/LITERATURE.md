# Literature Library — Detmer & Stier *A. palmata* Demography

**81 PDFs** | Organized 2026-03-24 (Schopmeyer 2017 added 2026-04-24) | Gap analysis: `LITERATURE_GAPS.md`

---

## Directory Structure

```
literature/
├── LITERATURE.md          ← this file
├── LITERATURE_GAPS.md     ← acquisition tracking
├── pdfs/
│   ├── data_studies/      ← 34 PDFs: A. palmata demography & vital rates
│   │   └── supplementary/ ←  5 PDFs: supplementary materials
│   ├── methods/           ← 15 PDFs: statistics, population modeling, meta-analysis
│   ├── context/           ← 12 PDFs: Caribbean decline, climate, threats
│   ├── restoration/       ← 12 PDFs: coral restoration studies & reviews
│   └── preprints/         ←  2 PDFs: bioRxiv preprints (not yet peer-reviewed)
├── summaries/             ← 14 TXT: paper-by-paper extraction notes
└── scripts/               ← 2 PY: PDF summary extraction tools
```

---

## data_studies/ (34 papers)

Core dataset papers (7 individual-level + ~10 summary-level studies) plus A. palmata biology.

| File | Citation | Role |
|------|----------|------|
| Albright_etal_2010_OA_recruitment_Apalmata.pdf | Albright et al. 2010 *PNAS* | Short-term lab survival (Methodology Ref §7.5) |
| Bruckner_Bruckner_2001.pdf | Bruckner & Bruckner 2001 | Summary survival data |
| Chamberland_etal_2015.pdf | Chamberland et al. 2015 | Summary survival/growth (recruits) |
| Croquer_etal_2016_Acropora_recovery_LosRoques.pdf | Croquer et al. 2016 *PeerJ* | Recovery assessment, size structure, Venezuela |
| DevlinDurante_Baums_2017_Apalmata_SNPs.pdf | Devlin-Durante & Baums 2017 *PeerJ* | Population genetic structure |
| Erwin_Szmant_2010_settlement_Apalmata.pdf | Erwin & Szmant 2010 *Coral Reefs* | Settlement/survival (Methodology Ref §7.4) |
| Fong_Lirman_1995_hurricane_fragment_growth.pdf | Fong & Lirman 1995 | Hurricane fragment growth rates |
| Forrester_etal_2011.pdf | Forrester et al. 2011 | Summary survival data |
| Forrester_etal_2013.pdf | Forrester et al. 2013 | Summary survival data |
| Garrison_Ward_2008.pdf | Garrison & Ward 2008 | Summary survival data |
| Highsmith_1982_fragmentation_reproduction.pdf | Highsmith 1982 *MEPS* | Classic fragmentation as reproduction |
| Highsmith_etal_1980_fragment_survival.pdf | Highsmith et al. 1980 *Oecologia* | Size-dependent fragment survival |
| Hughes_1984_size_based_population_dynamics.pdf | Hughes 1984 *Am Nat* | **Foundational** size-based coral population model |
| Kuffner_etal_2020.pdf | Kuffner et al. 2020 | Individual survival (mortality ≥50% tissue loss) |
| Lirman_2000_fragmentation_Apalmata.pdf | Lirman 2000 *JEMBE* | Fragment survival/growth, size-dependent |
| Lirman_2000_lesion_regeneration_Apalmata.pdf | Lirman 2000 *MEPS* | Lesion regeneration, colony size effects |
| Maurer_etal_2022.pdf | Maurer et al. 2022 | Summary survival data |
| MendozaQuiroz_etal_2023.pdf | Mendoza Quiroz et al. 2023 | Individual survival/growth, Mexico |
| Miller_etal_2016_Florida_Acropora_trends.pdf | Miller et al. 2016 *PeerJ* | Decade-long FL Acropora census |
| OrtizProsper_2005.pdf | Ortiz Prosper 2005 | Summary survival data |
| Papke_etal_2021.pdf | Papke et al. 2021 | Summary survival/growth |
| Pausch_etal_2018.pdf | Pausch et al. 2018 | Individual survival/growth, FL fragments |
| PinonGonzalez_Banaszak_2018_partial_mortality_Apalmata.pdf | Pinon-Gonzalez & Banaszak 2018 *Front Mar Sci* | Partial mortality → growth/reproduction |
| Ramos_etal_2024_17yr_Cuba_reef_crests.pdf | Ramos et al. 2024 *PeerJ* | 17-year population monitoring, Cuba |
| Randall_Szmant_2009_temperature_Apalmata.pdf | Randall & Szmant 2009 *Biol Bull* | Temperature effects on early survivorship |
| RodriguezMartinez_etal_2014_Apalmata_Mesoamerican.pdf | Rodriguez-Martinez et al. 2014 *PLoS ONE* | Regional assessment, size-frequency |
| Rosales_etal_2024.pdf | Rosales et al. 2024 | Summary survival, FL Keys genotypes |
| Roth_etal_2013.pdf | Roth et al. 2013 | Summary survival data |
| Schutter_etal_2023.pdf | Schutter et al. 2023 | Summary growth data |
| Vardi_2011_dissertation.pdf | Vardi 2011 dissertation | Fragmentation data (n=13), 3 regions |
| Vardi_etal_2012.pdf | Vardi et al. 2012 | Size standardization method (L×W×%live) |
| Weil_etal_2020_growth_dynamics_PR.pdf | Weil et al. 2020 *PeerJ* | Monthly growth/mortality, Puerto Rico |
| Williams_Miller_2010.pdf | Williams & Miller 2010 | NOAA tagged colony monitoring |
| Williams_Miller_2012_mortality_attribution_Apalmata.pdf | Williams & Miller 2012 *Coral Reefs* | NOAA mortality attribution (same dataset) |

### supplementary/ (5)
Chamberland 2015, Papke 2021, Pausch 2018, Rosales 2024, Schutter 2023

---

## methods/ (15 papers)

Statistics, population modeling, meta-analysis methodology, coral demography theory.

| File | Citation | Why Needed |
|------|----------|-----------|
| Cote_etal_2005_coral_decline_metaanalysis.pdf | Cote et al. 2005 *Phil Trans R Soc B* | Meta-analysis methodology for reef change |
| Detmer_etal_2025_GAM_threshold_detection.pdf | Detmer et al. 2025 *Ecosphere* | GAM threshold framework (our methods paper) |
| Edmunds_Riegl_2020_urgent_need_coral_demography.pdf | Edmunds & Riegl 2020 *Ecology* | Framing: why coral demography matters |
| Hartung_Knapp_2001_meta_analysis_method.pdf | Hartung & Knapp 2001 *Stat Med* | Knapp-Hartung adjustment (used in all rma() calls) |
| Kayal_etal_2018_coral_population_dynamics_models.pdf | Kayal et al. 2018 *Ecol Lett* | Multi-species coral IPM + elasticity (Mo'orea) |
| Knapp_Hartung_2003_meta_regression.pdf | Knapp & Hartung 2003 *Stat Med* | KH extension to meta-regression |
| Lasker_1991_gorgonian_population_growth.pdf | Lasker 1991 *Oecologia* | Size-dependent matrix model, elasticity |
| Lasker_MartinezQuintana_2022_octocoral_demography.pdf | Lasker & Martinez-Quintana 2022 *PeerJ* | Stage-structured matrix, size-escape threshold |
| Madin_etal_2014_size_dependent_mortality.pdf | Madin et al. 2014 *Ecol Lett* | Mechanistic size-mortality explanation |
| Madin_etal_2020_growth_partial_mortality.pdf | Madin et al. 2020 *Biol Lett* | Growth vs partial mortality decomposition |
| Pisapia_etal_2020_coral_size_structure_projections.pdf | Pisapia et al. 2020 *Adv Mar Biol* | Stage-structured matrix, extinction risk |
| Samhouri_etal_2017_ecosystem_thresholds.pdf | Samhouri et al. 2017 *Ecosphere* | Ecosystem threshold methods |
| Speare_etal_2022_size_dependent_mortality_heatwave.pdf | Speare et al. 2022 *Glob Chang Biol* | Size-dependent mortality reversal in heatwaves |
| Viechtbauer_2010_metafor_package.pdf | Viechtbauer 2010 *J Stat Softw* | metafor R package (must-cite) |
| Viechtbauer_LopezLopez_2022_location_scale_meta.pdf | Viechtbauer & Lopez-Lopez 2022 *Res Synth Methods* | Heterogeneity modeling (I²=97.8%) |

---

## context/ (12 papers)

Caribbean coral decline, climate change, threats.

| File | Citation | Why Needed |
|------|----------|-----------|
| AlvarezFilip_etal_2009_Caribbean_reef_flattening.pdf | Alvarez-Filip et al. 2009 *Proc R Soc B* | Caribbean complexity loss |
| AlvarezFilip_etal_2022_SCTLD_Caribbean.pdf | Alvarez-Filip et al. 2022 *Commun Biol* | SCTLD threat (acroporids unaffected but context changed) |
| Aronson_Precht_2001_white_band_disease.pdf | Aronson & Precht 2001 *Hydrobiologia* | WBD as primary driver of Acropora decline |
| Birkart_AlvarezFilip_2025_2023_heatwave_Apalmata.pdf | Birkart & Alvarez-Filip 2025 *iScience* | 2023 Caribbean-wide A. palmata mortality |
| Gardner_etal_2003_Caribbean_coral_decline.pdf | Gardner et al. 2003 *Science* | Foundational Caribbean 80% decline meta-analysis |
| HoeghGuldberg_etal_2007_climate_change_reefs.pdf | Hoegh-Guldberg et al. 2007 *Science* | CO2 trajectories and coral reef futures |
| Hughes_1994_Caribbean_reef_degradation.pdf | Hughes 1994 *Science* | Seminal Caribbean phase shift paper |
| Hughes_etal_2017_global_warming_mass_bleaching.pdf | Hughes et al. 2017 *Nature* | Pan-tropical bleaching drivers |
| Lessios_2016_Diadema_dieoff_review.pdf | Lessios 2016 *Annu Rev Mar Sci* | Diadema die-off and (limited) recovery |
| Levitan_etal_2023_Diadema_mass_mortality.pdf | Levitan et al. 2023 *PNAS* | Second Diadema die-off (2022) |
| Manzello_etal_2025_functional_extinction_Florida.pdf | Manzello et al. 2025 *Science* | 2023 functional extinction of FL A. palmata |
| Mumby_etal_2007_Caribbean_reef_resilience.pdf | Mumby et al. 2007 *Nature* | Alternative stable states, grazing thresholds |

---

## restoration/ (12 papers)

Coral restoration methods, reviews, sister species comparisons.

| File | Citation | Why Needed |
|------|----------|-----------|
| Banister_etal_2024_Apalmata_restoration_predictors.pdf | Banister et al. 2024 *PLoS ONE* | Environmental predictors for A. palmata outplanting |
| Bayraktarov_etal_2016_restoration_cost_feasibility.pdf | Bayraktarov et al. 2016 *Ecol Appl* | Restoration meta-analysis (64.5% survival) |
| BostromEinarsson_etal_2020_coral_restoration_review.pdf | Boström-Einarsson et al. 2020 *PLoS ONE* | Systematic review (229 spp, 60-70% survival) |
| Goergen_etal_2025_coral_restoration_guide.pdf | Goergen et al. 2025 *CRC* | Comprehensive restoration guide |
| Hagedorn_etal_2021_assisted_gene_flow_Apalmata.pdf | Hagedorn et al. 2021 *PNAS* | AGF with cryopreserved sperm, 42% survival |
| Ladd_etal_2016_density_dependence_Acervicornis.pdf | Ladd et al. 2016 *Front Mar Sci* | Density-dependent A. cervicornis survival |
| Lirman_etal_2010_Acervicornis_propagation.pdf | Lirman et al. 2010 *Coral Reefs* | Fragment propagation methods |
| Lirman_etal_2014_Acervicornis_growth.pdf | Lirman et al. 2014 *PLoS ONE* | A. cervicornis size-dependent growth |
| Muller_etal_2025_assisted_gene_flow_Apalmata_preprint.pdf | Muller et al. 2025 *bioRxiv* | AGF crosses, FL approaching regional extinction |
| Muller_etal_2025_restoration_prevents_extirpation.pdf | Muller et al. 2025 *Conserv Biol* | 2023 heatwave: gene banks prevented extirpation |
| RamosRomero_etal_2025_Apalmata_Cuba_restoration.pdf | Ramos Romero et al. 2025 *PeerJ* | Cuban reef crest restoration |
| Schopmeyer_etal_2017_regional_restoration_benchmarks_Acervicornis.pdf | Schopmeyer et al. 2017 *Coral Reefs* | Sister-species origin-effect benchmark: >80% nursery, >70% outplant, 85% donor tissue cover; "outplants behave as wild colonies" |
| Ware_etal_2020_Acervicornis_outplanting.pdf | Ware et al. 2020 *PLoS ONE* | A. cervicornis outplanting (Weibull models) |

---

## preprints/ (2 papers)

Not yet peer-reviewed.

| File | Citation | Why Needed |
|------|----------|-----------|
| Brookson_Greiner_2024_restoration_feasibility_preprint.pdf | Brookson & Greiner 2024 *bioRxiv* | Restoration feasibility under stressors |
| Madin_etal_2025_demographic_insights_restoration_preprint.pdf | Madin et al. 2025 *bioRxiv* | 28 coral matrix models; adult survival = top lever |

---

## Textbooks to Cite (not downloaded)

- **Caswell H (2001)** *Matrix Population Models*. 2nd ed. Sinauer. — Cited in script 13, §9.1.3
- **Wood SN (2017)** *Generalized Additive Models*. 2nd ed. CRC Press. — GAM methods
