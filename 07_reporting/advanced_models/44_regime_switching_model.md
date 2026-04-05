# 44: Regime-Switching Demographic Model

## Scope
This analysis formalizes latent annual demographic regimes for *Acropora palmata* using the observed colony survival panel and the curated disturbance timeline.

Goal: estimate whether annual demographic conditions cluster into distinct hidden regimes compatible with:
- `background`
- `post_disturbance`
- `catastrophic`

## Data Used
- Survival panel: `05_data/standardized/apal_surv_ind.csv`
- Disturbance timeline: `05_data/standardized/apal_disturbance_stressor_timeline.csv`

After filtering invalid rows:
- Colony-level rows modeled: `7,814`
- Calendar years represented: `2004-2024` (`21` years)
- Years used directly in HMM fit: `19` (years with `n_obs >= 20`)
- Low-support years classified by emissions only: `2` (`2004`, `2024`)

## Model Design
The pipeline is intentionally two-stage to separate structural size/study effects from annual regime signal.

1. Structural survival baseline (`glm`, binomial):
`survived ~ ns(log1p(size), 3) + factor(region) + factor(study) + factor(fragment)`

2. Annual deviations from baseline (`glm`, binomial with offset):
`survived ~ factor(survey_yr) - 1 + offset(base_lp)`

3. Hidden-state model on annual deviation series:
- 3-state Gaussian HMM
- EM fitting with multiple random starts
- Viterbi decoding for annual most-likely states
- Posterior probabilities from forward-backward algorithm

State labels are assigned after fitting using overlap diagnostics from disturbance attachment:
- high catastrophic/exclusion overlap + low annual effect -> `catastrophic`
- high annual effect + low disturbance overlap -> `background`
- remaining state -> `post_disturbance`

## Key Outputs
- `06_analysis/output/regime_switching_year_effect_series.csv`
- `06_analysis/output/regime_switching_year_classification.csv`
- `06_analysis/output/regime_switching_state_parameters.csv`
- `06_analysis/output/regime_switching_transition_matrix.csv`
- `06_analysis/output/regime_switching_fit_summary.csv`
- `06_analysis/figures/supplementary/regime_switching_year_states.png`
- `06_analysis/figures/supplementary/regime_switching_year_states.pdf`

## Main Results
From `regime_switching_fit_summary.csv`:
- HMM logLik: `-11.848`
- AIC: `51.70`
- BIC: `64.92`
- Mean posterior certainty: `0.993`

From `regime_switching_state_parameters.csv`:
- `background` state mean annual effect: `0.847` (4 years)
- `post_disturbance` state mean annual effect: `0.211` (6 years)
- `catastrophic` state mean annual effect: `-0.726` (9 years)

Notable year assignments from `regime_switching_year_classification.csv`:
- Background cluster: `2007-2008`, `2011-2012`
- Post-disturbance cluster: `2005-2006`, `2010`, `2016`, `2019`, `2021`
- Catastrophic cluster includes `2017`, `2022`, `2023`, plus several low-survival years (`2009`, `2013-2015`, `2018`, `2020`)

## What Is Estimable Now
- A reproducible hidden-state partition of annual demographic condition beyond GLMM fixed effects
- A regime-labeled annual series that can be joined into viability projections
- Quantitative transition tendencies between hidden regimes

## What Is Not Reliably Estimable Yet
- A stable mechanistic transition model from disturbance covariates alone (sample is only 19 modeled years)
- Precise regime persistence for rare catastrophic states under broader Caribbean generalization
- Strongly identified Markov transition probabilities for all state-to-state pathways

## Practical Interpretation
The data support a latent regime structure, but annual support is limited for fully mechanistic state transitions. The strongest use of this model now is as a regime-classification layer for synthesis and sensitivity analysis, not as a definitive long-horizon forecasting engine.

## Iteration Priorities
- Fit a non-homogeneous HMM where transition probabilities are explicit functions of disturbance indicators
- Move to Bayesian state-space formulation to propagate uncertainty from annual effect estimation into regime assignment
- Expand high-support year coverage outside Florida-dominant panels to stabilize transition estimation
