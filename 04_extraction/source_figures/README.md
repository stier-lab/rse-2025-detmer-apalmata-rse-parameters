# Source Figures Used for Data Extraction

This folder contains cropped pages from published papers where data was extracted visually from figures rather than from tables or raw data files. Each PDF contains the page(s) with the relevant figure(s).

For the full extraction methodology, values extracted, and assumptions made, see [extraction_details.md](../extraction_details.md).

## Inventory

| File | Study | Figure | What was extracted | Values |
|------|-------|--------|-------------------|--------|
| `vardi_2011_fig4-2_colony_counts.pdf` | Vardi 2011 (Jamaica, PR, Virgin Gorda) | Fig. 4-2 stacked bar plots | Colony counts per size class for 3 regions | Jamaica: SC1=16, SC2=46, SC3=17, SC4=21; PR: SC1=73, SC2=130, SC3=97, SC4=106; VG: SC1=9, SC2=27, SC3=12, SC4=10 |
| `bruckner_bruckner_2001_fig3_histogram.pdf` | Bruckner & Bruckner 2001 | Fig. 3 stacked histogram | Initial sizes and proportions surviving per size bin | 11 size bins (0-10 cm through 100-110 cm); survival range 0.655-0.920 over 2 years; interpolated to annual |
| `garrison_ward_2008_fig4b_survival.pdf` | Garrison & Ward 2008 | Fig. 4b | Proportion surviving by treatment | Control colonies: 0.80; transplanted fragments: 0.55 |
| `ortiz_prosper_2005_fig3-4_size_distribution.pdf` | Ortiz Prosper 2005 | Fig. 3.4 | Fragment counts per 200 cm^2 size bin | Used to estimate mean fragment size in largest class (>600 cm^2); survival from matrix tables, not figure |
| `roth_etal_2013_fig5_histograms_EXCLUDED.pdf` | Roth et al. 2013 (EXCLUDED) | Fig. 5 histograms | Colony counts per size class | Estimated from histogram bars; study excluded for data overlap with Rogers & Muller 2012 |

## Studies with table/text-based extraction (no figure needed)

These studies had data extracted from published tables, paper text, or raw data files — no visual figure reading was required:

- **All 7 Tier 1 studies** (NOAA, Pausch, USGS, Kuffner, Mendoza-Quiroz, FUNDEMAR, Neely): raw data files
- **Forrester et al. 2013**: Tables 1 and 2
- **Rosales et al. 2024**: Table S3 + GitHub
- **Maurer et al. 2022**: Published tables
- **Williams & Miller 2010**: Published tables
- **Ramos-Romero et al. 2025**: Table 2 (KM survival)
- **Rogers et al. 1982**: Table 5
- **Rogers & Muller 2012**: Paper text ("44 of 69 survived 7 years")

## Notes

- Vardi 2011 is a PhD dissertation (161 pages). The extracted pages include all Chapter 4 panels of Fig. 4-2 showing colony size distributions by region and year. The full dissertation is at `literature/pdfs/data_studies/Vardi_2011_dissertation.pdf`.
- Bruckner & Bruckner 2001 is a 9-page paper. Multiple pages extracted because the figure may span page boundaries in the scanned PDF.
- The Chamberland et al. 2015 survival estimate (from Fig. 2 bar plot) is not archived here because Chamberland is classified as "Restoration recruit" and excluded from the survival meta-analysis. The source PDF is at `literature/pdfs/data_studies/Chamberland_etal_2015.pdf`.

## Source PDFs

All original source papers are in `literature/pdfs/data_studies/`. The files here are page extracts for convenience — the full papers are the authoritative source.
