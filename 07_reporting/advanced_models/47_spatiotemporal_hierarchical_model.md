# 47. Spatiotemporal Hierarchical Model

This track extends the colony-panel analysis beyond standard GLMMs by explicitly modeling temporal smooths, spatial structure over site coordinates, and hierarchical site clustering.

## Target question

How much additional demographic structure is explained when colony outcomes are modeled with:

- nonlinear size dependence
- curated disturbance state
- population type
- study clustering
- temporal smoothing
- spatial smoothing
- site random effects

## Inputs

- `06_analysis/output/prepared_survival_data.rds`
- `06_analysis/output/prepared_growth_data.rds`

## Script

- `06_analysis/scripts/47_spatiotemporal_hierarchical_model.R`

## Outputs

- `spatiotemporal_survival_model_comparison.csv`
- `spatiotemporal_growth_model_comparison.csv`
- `spatiotemporal_survival_variance_components.csv`
- `spatiotemporal_growth_variance_components.csv`
- `spatiotemporal_year_predictions.csv`
- `spatiotemporal_site_summary.csv`
- `spatiotemporal_site_year_summary.csv`
- `spatiotemporal_spatial_predictions.csv`
- `spatiotemporal_data_coverage.csv`
- `spatiotemporal_hierarchical_summary.png/.pdf`

## Run status

- `Rscript 06_analysis/scripts/47_spatiotemporal_hierarchical_model.R` completed successfully.
- Both the survival and positive-growth spatiotemporal models ran successfully.
- The final implementation uses dynamic fixed-effect formulas so single-level factors in a given panel do not break the growth-side fit.

## Key results

- Survival panel coverage: `7,335` rows, `67` sites, `516` site-years, `84.7%` Florida Keys.
- Positive-growth panel coverage: `5,637` rows, `66` sites, `489` site-years, `83.1%` Florida Keys.
- Baseline survival model: AIC `6637.5`, deviance explained `0.135`.
- Spatiotemporal survival model: AIC `4753.9`, deviance explained `0.215`.
- Baseline positive-growth model: AIC `7244.0`, deviance explained `0.044`.
- Spatiotemporal positive-growth model: AIC `6343.9`, deviance explained `0.074`.
- The fitted spatiotemporal structure retained non-trivial site-level variance in both outcomes, with survival `s(site_id)` SD about `0.676` and positive-growth `s(site_id)` SD about `0.568`.

## Notes

- This is a first-pass hierarchical extension, not a full latent Gaussian spatiotemporal field.
- The analysis is Florida-heavy because the prepared panel is dominated by `NOAA_survey` and `neely_et_al_2022`.
- The growth-side fit is still weaker than the survival-side fit, so it should be interpreted as supportive rather than equally definitive.
