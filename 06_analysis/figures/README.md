# A. palmata Demographic Analysis Figures

All figures for the *Acropora palmata* demographic parameters manuscript and supplementary materials.

## Manuscript Figures (`manuscript/`)

| File | Script | Description |
|------|--------|-------------|
| `Fig1_study_landscape.png` | `18_fig1_study_landscape.R` | Study sites map + size distributions |
| `Fig2_demographic_rates.png` | `19_fig2_demographic_rates.R` | Survival + RGR by size |
| `Fig3_natural_vs_restoration.png` | `21_fig3_natural_vs_restoration.R` | Natural vs. restoration comparison (12-panel) |
| `Fig4_size_class_survival.png` | `20_fig_size_class_survival_synthesis.R` | Size-class survival synthesis across studies |
| `Fig5_expanded_forest_plot.png` | `20b_fig_expanded_forest_plot.R` | Expanded forest plot (k=16 Caribbean meta-analysis) |
| `Fig6_population_model.png` | `22_fig6_population_model.R` | Lambda bootstrap distribution + LOSO sensitivity |
| `figure_legends.txt` | -- | Figure legends, methods, and results text |

## Supplementary Figures (`supplementary/`)

| File | Script | Description |
|------|--------|-------------|
| `FigS1_size_distribution.png` | `18_fig1_study_landscape.R` | Size frequency distributions |
| `FigS2_data_gaps.png` | `23_figS2_data_gaps.R` | Data gaps certainty heatmap |
| `FigS3_survival_threshold.png` | `24_supp_S3_S4.R` | Survival threshold analysis |
| `FigS4_survival_gam.png` | `24_supp_S3_S4.R` | Survival GAM fit |
| `FigS5_growth_threshold.png` | `25_supp_S5_S6_S7_thresholds_growth.R` | Growth threshold analysis |
| `FigS6_rgr_threshold.png` | `25_supp_S5_S6_S7_thresholds_growth.R` | RGR threshold analysis |
| `FigS7_growth_gam.png` | `25_supp_S5_S6_S7_thresholds_growth.R` | Growth GAM fit |
| `FigS8_variance_partitioning.png` | `26_supp_S8_S9.R` | Variance partitioning |
| `FigS9_climate_effects.png` | `26_supp_S8_S9.R` | Climate-demography relationships |
| `FigS10_cross_validation.png` | `27_supp_S10_S11.R` | Cross-validation results |
| `FigS11_power_analysis.png` | `27_supp_S10_S11.R` | Power analysis curves |
| `FigS12_heterogeneity.png` | `28_supp_S12_S13_S14.R` | Heterogeneity decomposition |
| `FigS13_sensitivity.png` | `28_supp_S12_S13_S14.R` | Sensitivity analysis |
| `FigS14_context_comparison.png` | `28_supp_S12_S13_S14.R` | Context comparison |
| `FigS15_regional_survival.png` | `20c_fig_regional_survival.R` | Regional survival variation |

### Subdirectories

- `diagnostics/` -- Model diagnostic plots (`survival_model_diagnostics.png`, `growth_model_diagnostics.png`)
- `meta_analysis/` -- Meta-analysis figures (expanded forest plot, funnel plot, regional summary, etc.)
- `exploratory/` -- ~34 exploratory analysis plots

## Other

- `publication/` -- `allometry_analysis.png`

## Output Format

PNG at 300 DPI, 170 mm width. No PDFs currently generated for manuscript or supplementary figures. Font and palette defined in `theme_manuscript()` and `MANUSCRIPT_PALETTE` from `analysis/scripts/utils/shared_utilities.R`.

## Regenerating Figures

```bash
# Main figures
Rscript analysis/scripts/18_fig1_study_landscape.R
Rscript analysis/scripts/19_fig2_demographic_rates.R
Rscript analysis/scripts/20_fig_size_class_survival_synthesis.R
Rscript analysis/scripts/20b_fig_expanded_forest_plot.R
Rscript analysis/scripts/20c_fig_regional_survival.R
Rscript analysis/scripts/21_fig3_natural_vs_restoration.R
Rscript analysis/scripts/22_fig6_population_model.R

# Supplementary figures
Rscript analysis/scripts/23_figS2_data_gaps.R
Rscript analysis/scripts/24_supp_S3_S4.R
Rscript analysis/scripts/25_supp_S5_S6_S7_thresholds_growth.R
Rscript analysis/scripts/26_supp_S8_S9.R
Rscript analysis/scripts/27_supp_S10_S11.R
Rscript analysis/scripts/28_supp_S12_S13_S14.R
```

*Last updated: 2026-02-23*
