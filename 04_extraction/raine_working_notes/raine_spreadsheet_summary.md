# Raine Detmer's Literature Review Spreadsheets

Three Excel files exported from Google Sheets on 2026-03-26. These are Raine's original tracking documents for the literature search and model parameterization.

---

## 1. `coral_parameters_lit_review.xlsx`

**The master literature search tracker.** Three sheets covering survival, growth, and reproduction parameters.

### Survival sheet (93 rows, 38 unique studies)

Lists every study Raine evaluated for survival parameters, with columns: Study, Species, Morphology, Location, Size class, Fragmented?, Survival value, Units, Notes.

**Studies evaluated (38 total):**
- Becker & Mueller 2001, Bruckner & Bruckner 2001, Bythell et al. 1993, Chamberland et al. 2015, Chen et al. 2020, Edmunds 2010, Erwin & Szmant 2010, Fong & Lirman 1995, Forrester et al. 2011, Forrester et al. 2013, Garrison & Ward 2008, Griffin et al. 2015, Knowlton et al. 1981, Kuffner et al. 2020, Ladd et al. 2016, Ladd et al. 2024, Lirman & Fong 1997, Lirman 2000, Marhaver et al. 2013, Maurer et al. 2022, Mendoza Quiroz et al. 2023, Miller 2014, Olsen et al. 2016, Ortiz Prosper 2005, Page et al. 2018, Pausch et al. 2018, Randall & Szmant 2009, Ritson-Williams et al. 2010, Rosales et al. 2024, Roth et al. 2012, Schutter et al. 2023, Steinberg 2021, Vardi 2011, Vardi et al. 2012, Vermeij & Sandin 2008, Williams & Miller 2010, Williams et al. 2008, Williams et al. 2017

**Key finding for PRISMA:** Raine evaluated 38 studies (not 16 as previously estimated). Many were recorded but not included in the final dataset, meaning the screening produced a larger exclusion count than documented.

### Growth sheet (69 rows, 28 unique studies)

Same structure for growth parameters. Includes linear extension studies that were ultimately excluded from the pipeline (e.g., Crabbe 2009/2010/2013, Gladfelter 1978, Bak 2009).

### Reproduction sheet (9 rows, 5 studies)

Genetics-based reproductive information (Irwin 2017, Baums 2006, Japaud 2015, Porto-Hannes 2015). Not used in demographic modeling directly.

---

## 2. `coral_model_lit_review.xlsx`

**Review of published coral population models.** 1 sheet, 38 rows, cataloging matrix population models (MPMs), integral projection models (IPMs), and simulation models for various coral species.

Key entries for A. palmata:
- Vardi et al. 2012 — MPM, Florida Keys, outplanting scenarios
- Steward 2024 (MS thesis) — IPM, Acropora spp., Saipan

Also includes models for other species (Orbicella, Porites, Agaricia, Diploria) that informed the modeling approach.

---

## 3. `rse_model_parameters.xlsx`

**Complete parameter table for the Restoration Strategy Evaluation model.** 1 sheet, 1030 rows, 41 defined parameters across 4 sections:

### Sections:
1. **Reef & orchard demographic parameters** (rows 2-26): survival rates s_1–s_5, growth transitions g_*, shrinkage h_*, fragmentation f_*, fecundity r_*
2. **Lab demographic parameters** (rows 27-34): settler survival s_0, settlement proportion
3. **Restoration parameters** (rows 35-45): reef/orchard proportions, transplant matrices, lab capacity
4. **Economic parameters** (rows 46+): costs of treatments

### Key defaults vs current pipeline:

| Parameter | Raine default | Source | Current pipeline value |
|---|---|---|---|
| s_1 (SC1 survival) | 0.01 | Fundemar tiles | ~0.69 (from GLMM) |
| s_2 (SC2 survival) | 0.76 | Vardi 2012 | ~0.81 (from GLMM) |
| s_3 (SC3 survival) | 0.87 | Vardi 2012 | ~0.87 (from GLMM) |
| s_4 (SC4 survival) | 0.95 | Vardi 2012 | ~0.93 (from GLMM) |
| s_5 (SC5 survival) | 0.99 | Vardi 2012 | ~0.95 (from GLMM) |
| g_1x (SC1 growth) | (0.5, 0, 0, 0) | "guessed" | Estimated from data |
| lab_max | 180,000 | Maria (Fundemar email) | — |
| orchard_size | 2,400 colonies | Maria (Fundemar email) | — |

Note: Several parameters are marked "guessed" — these are the weakest links in the RSE model. The current analysis pipeline estimates survival and growth from data rather than using these defaults.

---

## Implications for PRISMA Documentation

The `coral_parameters_lit_review.xlsx` survival sheet resolves a key PRISMA gap: **Raine screened 38 studies for survival, not the ~19 previously estimated.** The PRISMA flow diagram should be updated:

- Records screened at full-text: ≥38 (survival) + additional for growth/reproduction
- Records excluded at full-text: ≥22 survival studies (38 evaluated - 16 included)
- This means the original search was more thorough than documented

Studies in the tracker NOT in our current included or excluded lists (potential gaps to investigate):
- Griffin et al. 2015
- Ladd et al. 2016, 2024
- Lirman & Fong 1997
- Marhaver et al. 2013
- Olsen et al. 2016
- Page et al. 2018
- Ritson-Williams et al. 2010
- Steinberg 2021
- Vermeij & Sandin 2008
- Williams et al. 2017
- Becker & Mueller 2001
- Chen et al. 2020

These studies were evaluated by Raine but not ultimately included — likely because they didn't meet the survival/growth criteria (e.g., settlement studies, lab-only, different species).

---

*Exported from Google Drive: 2026-03-26*
*Original files: Stier Lab/People/Raine Detmer/RSE project/*
