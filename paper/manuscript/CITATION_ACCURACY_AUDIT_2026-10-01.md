# Citation accuracy audit — 2026-10-01

## Scope and method

This is a claim-to-source pass of the canonical manuscript and its supporting
material. I read the manuscript top to bottom, extracted Pandoc citation keys
from both files, checked every key against the two bibliography files, and
re-read the local full text for the citation clusters revised in this pass.
The audit distinguishes direct evidence from manuscript synthesis: numerical
results from the compiled dataset are reported as this study's results and are
not padded with background citations.

| File | Citation clusters | Citation occurrences | Unique keys |
|---|---:|---:|---:|
| `07_reporting/manuscript/acropora_palmata_demography_manuscript_draft.md` | 36 | 62 | 45 |
| `paper/submission/supplement/ESM_1.md` | 21 | 21 | 16 |

The complete package resolves 48 unique keys across
`references.bib` and `palmata_library.bib`. The supplement's 16 keys are all
also used in the main-text bibliography, so its rendered references remain
complete without a separate bibliography list.

## Claim-level adjudications and revisions

| Location | Atomic claim | Source and verification | Verdict and action |
|---|---|---|---|
| Introduction, paragraph 1 | White-band disease can remove live tissue and alter shallow-reef structure. | Gladfelter 1982; local PDF `literature/pdfs/data_studies/Gladfelter_1982_white_band_disease.pdf`, abstract, quadrat results, and discussion. | Supports; retained. |
| Introduction, paragraph 1 | Storm damage, snail predation, disease, and fragmentation/chronic tissue loss affected Florida *A. palmata* from 2004–2010. | Williams & Miller 2012; local PDF `literature/pdfs/data_studies/Williams_Miller_2012_mortality_attribution_Apalmata.pdf`, abstract. | Supports; retained. |
| Introduction, paragraph 1 | St. John colonies experienced disease, physical damage, and predation over long-term monitoring. | Rogers & Muller 2012; local PDF `literature/pdfs/data_studies/Rogers_Muller_2012_Apalmata_USVI_recovery.pdf`, abstract and methods. | Supports; replaced the less-direct outbreak-spatial-analysis citation. |
| Introduction, paragraph 3 | Storm intensity and recurrence can alter *A. palmata* population trajectories. | Lirman 2003; local PDF `literature/pdfs/data_studies/Lirman_2003_population_simulation.pdf`, abstract. | Supports; moved from restoration heterogeneity to the disturbance claim it directly supports. |
| Introduction, paragraph 3 | Temperature affects larval development, survival, and settlement. | Randall & Szmant 2009; local PDF `literature/pdfs/data_studies/Randall_Szmant_2009_temperature_Apalmata.pdf`, abstract. | Supports; retained. |
| Introduction, paragraph 3 and heatwave analysis | The 2023 Florida event caused 97.8–100% *A. palmata* mortality in the Keys and Dry Tortugas; Florida Acropora became functionally extinct. | Manzello et al. 2025; local PDF `literature/pdfs/context/Manzello_etal_2025_functional_extinction_Florida.pdf`, abstract and results. | Supports; retained. |
| Discussion, restoration paragraph | Sexual-propagation cohorts have high early mortality; later stages can differ materially. | Chamberland et al. 2015 and Mendoza Quiroz et al. 2023; local PDFs `literature/pdfs/data_studies/Chamberland_etal_2015.pdf` and `literature/pdfs/data_studies/MendozaQuiroz_etal_2023.pdf`, abstracts and survival results. | Supports; retained. |
| Discussion, restoration paragraph | Settlement response varies among red algae, and algae/cyanobacteria can change larval survival or settlement. | Ritson-Williams et al. 2014 and 2020; verified against publisher/institutional abstract records and bibliographic metadata. | Supports the carefully limited wording; retained. |
| Discussion, restoration paragraph | Many coral-restoration projects monitor for less than 18 months. | Boström-Einarsson et al. 2020; local PDF `literature/pdfs/restoration/BostromEinarsson_etal_2020_coral_restoration_review.pdf`, results. | Supports; retained. |
| Introduction, paragraph 1 | White-band disease can be spatially clustered within a local *A. palmata* population. | Lentz et al. 2011; source title and abstract, verified against the publisher record. | Supports; added. |
| Methods, data standardization | Demographic observations do not by themselves identify sexual versus clonal origin; demographic and genetic evidence answer complementary recovery questions. | Grober-Dunsmore et al. 2007; source abstract. | Supports the deliberately limited wording; added. |
| Discussion, large-adult persistence | Disease and corallivore stress can be concentrated on large colonies and impede recovery. | Grober-Dunsmore et al. 2006; local PDF `literature/pdfs/data_studies/GroberDunsmore_etal_2006_Apalmata_recovery_inhibitors.pdf`, abstract. | Supports; added. |

## Metadata repairs

- Corrected `ritsonwilliams2013` to the published record: 2014, *Coral Reefs*
  33(1):59–66. The citekey is retained for stable manuscript history.
- Corrected `ritsonwilliams2020` to article 31 in *Marine Biology* 167(3),
  rather than page 8.
- Repaired the citation checker so its email safeguard does not skip narrative
  Pandoc citations such as `[-@vardi2011]`.

## Boundaries of this pass

The ledger gives source-text evidence for every new, moved, or corrected
claim-source link. The inherited source-data and methods citations were
structurally checked and retained in their data/method locations; an
exhaustive full-text adjudication of every inherited claim-source pair remains
a separate pre-submission task because some source PDFs are not locally held.
