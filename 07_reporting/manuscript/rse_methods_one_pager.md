# Methods — Restoration Scenario Explorer (RSE) Modeling Paper

This Methods section describes the population model, the parameters that fill it, the curated literature search behind those parameters, and the scenario framework that together comprise the *Acropora palmata* Restoration Scenario Explorer. It is a companion to the synthesis Methods that document the systematic literature search, data extraction, and meta-analysis (`manuscript_methods_draft.md`, sections 2.1–2.4); the synthesis produces the vital-rate distributions that this paper turns into a population model. We first present the matrix structure (§Population model), then enumerate every parameter the matrix consumes (§Model parameterization), then describe the curated literature search that supplied the biological-mechanism parameters not present in the synthesis dataset (§Literature search for biological-realism parameters), then specify the scenario framework, the projection metrics, the software, and the deployed web platform. Anyone with the public repository (`github.com/stier-lab/Detmer-2025-coral-parameters`) and the standardized data tables can reproduce every number we report.

## Population model

We project *Acropora palmata* populations with a 5-class size-structured Lefkovitch matrix bounded by 0, 10, 100, 900, 4 000 cm², and ∞ live planar tissue area (Vardi et al. 2012). The classes — SC1 (recruits, 0–10 cm²), SC2 (small juveniles), SC3 (large juveniles), SC4 (subadults), and SC5 (mature adults, > 4 000 cm²) — match the published *A. palmata* matrix structure of Vardi (2011) with the smallest class subdivided to separate post-settlement recruits from small juveniles. At each annual time step the population vector **n**(*t*+1) = **A n**(*t*), where

> **A = G · diag(S) + F_frag + F_sex.**

**G** is the 5 × 5 size-class transition matrix (probability of moving from class *j* to class *i* conditional on survival), **S** is the size-specific annual survival vector, **F_frag** is the asexual recruitment matrix from colony fragmentation, and **F_sex** is the size-threshold sexual fecundity matrix. **F_sex** is set to zero in the published baseline (Vardi 2011) and activated in scenario comparisons. Each matrix component is estimated separately and then assembled into **A** so that scenario perturbations of one mechanism can be attributed cleanly to that mechanism rather than to an alternative fit of the core data.

## Model parameterization

The matrix draws parameters from three sources. Vital rates pooled from the synthesis dataset supply **S**, **G**, and post-settlement recruit survival. The Vardi (2011) fragmentation dataset supplies **F_frag**. Literature-derived biological-mechanism parameters held in the life-history-parameter file (LHP CSV; `05_data/standardized/apal_life_history_parameters.csv`, 43 rows) supply the terms in **F_sex** and the scenario survival modifiers; the curated search behind the LHP CSV is detailed in §Literature search. All vital-rate fits use the same statistical conventions as the synthesis — Knapp–Hartung adjustment for random-effects meta-analyses, hierarchical bootstrap for parameter uncertainty, and overdispersion checks (∑ Pearson² ÷ residual df) for binomial GLMMs.

### Annual survival (S)

We pooled annual survival per size class through a study-level random-effects meta-analysis on cell-aggregated effects (`prepared_survival_cells.rds`), where each cell contributes one survival proportion and an effective sample size after annualization under a constant-hazard assumption (S_annual = S_observed^(1/*t*); see synthesis Methods §2.2). For natural colonies, we fit `metafor::rma()` with REML and the Knapp–Hartung adjustment (`test = "knha"`) on cells drawn from 17 studies and 22 study-level effects — the same input that produces the published pooled annual survival of 78.0% (95% CI 70.1–84.3%, I² = 97.2%; synthesis Methods §2.3). For nursery and outplanted fragments, we fit the same model on 3 277 cell-level observations from 11 studies that contributed restoration-fragment data. We restrict survival inputs to colonies with size assignable to SC1–SC5, retain all observation intervals regardless of disturbance exposure (matching the synthesis's primary analysis), and re-estimate parameter uncertainty with a 2 000-iteration cluster bootstrap in which studies are resampled with replacement before observations within studies. The hierarchical bootstrap is required because between-study heterogeneity (I² = 97.2%) dwarfs within-study variance, and a flat resample of observations would understate uncertainty by an order of magnitude.

### Growth transitions (G)

We estimated annual size-class transition probabilities from individual-level growth observations using the binned-transition method that Vardi (2011) developed for this matrix structure. For natural colonies, we used 4 915 growth records (NOAA Acropora Demographic Monitoring, n = 3 188; K. Neely, unpublished data 2022, n = 1 675; Mendoza-Quiroz et al. 2023, n = 52) restricted to non-fragmenting colony intervals (`fragment == "N"`); fragmentation events are excluded here because they enter the matrix through **F_frag** and would otherwise be double-counted. For fragments, we used 901 fragment-origin records (`fragment == "Y"`) from five studies (FUNDEMAR fragments, Kuffner et al. 2020, the NOAA fragment subset, Pausch et al. 2018, USGS USVI experiment). Within each pathway, we computed the empirical size-transition matrix (probability of being in class *i* in year *t*+1 conditional on being in class *j* and alive in year *t*) by binning observed annual size pairs.

The deterministic baseline (S0) reproduces the published λ = 0.9613 exactly. Achieving this requires anchoring **G** to the validated transition matrix shipped with the synthesis (`transition_matrix.rds`) rather than recomputing **G** live from the growth CSV, because post-publication data accretion has shifted the empirical transitions slightly. We pass the canonical `growth_transitions` matrix to `compute_lambda_from_survival()` (utils/03_matrix_functions.R) through its `G_override` argument, which substitutes the validated **G** while leaving every other element of the projection algorithm unchanged. This is the only deviation from a literal re-fit of the current data, and we flag it explicitly so that readers can evaluate the choice. Removing the override changes baseline λ by < 1 × 10⁻³ (i.e., the override is precision anchoring, not a substantive parameter change).

### Post-settlement recruit survival

A separate parameter object (`recruit_surv_pars.rds`) carries annualized recruit survival from oocyte settlement to SC1 (live planar area > 0 cm² and detectable on a permanent quadrat). We estimated it from 16 479 recruit-tracked observations in three studies (Chamberland et al. 2015 outplanted larval cohorts; FUNDEMAR recruit cohort; Mendoza-Quiroz et al. 2023). The cell-weighted pooled estimate is s_recruit = 0.027 yr⁻¹ (95% CI 0.009–0.104). This estimate is necessary for the sexual-fecundity matrix (next subsection); it is not used in the deterministic **A** because Vardi's published matrix encodes recruitment through fragmentation only.

### Asexual recruitment matrix (F_frag)

The published baseline matrix uses **F_frag** as its only fecundity source. We assemble **F_frag** in `06_analysis/scripts/13_transition_matrix.R` from the Vardi (2011) fragmentation dataset (13 colony-years; the only individual-level fragmentation-rate data available for the species). For each parent size class *s*, we compute the per-capita probability of producing a fragment that recruits into class *i* in the following year as the empirical fragment-production rate × the size-conditional probability that a fragment falls into class *i*. Because **F_frag** is built from a single dataset, it is held constant across all scenarios; sensitivity to fragmentation parameters is reported in the synthesis (Fig. S20) and is not relitigated here.

### Sexual fecundity matrix (F_sex)

Sexual reproduction is absent from the published baseline. To represent it, we built **F_sex** as a size-threshold matrix with the form

> **F_sex[SC1, *s*] = ρ_oocyte × A(*s*) × p_mature(*s*) × f_fert × s_recruit × ε_settle**,

implemented in `53_sexual_fecundity_layer.R`. Here ρ_oocyte is colony-area-specific oocyte density, A(*s*) is the mean live planar area of size class *s*, p_mature(*s*) is the size-conditional probability that a colony is reproductively mature, f_fert is wild fertilization success, s_recruit is the post-settlement recruit survival from the previous subsection, and ε_settle is a settlement-efficiency rescaling factor. Five of the six terms come directly from the curated literature search (§Literature search); the sixth (ε_settle) is calibrated as described below.

The five literature-derived parameters are: ρ_oocyte = 63.6 oocytes · cm⁻² (Mendoza-Quiroz et al. 2023; LHP row 4); A(*s*) = the geometric-mean live planar area of size class *s* in the standardized synthesis dataset; p_mature(*s*) = 0 for SC1–SC3, 0.5 (area-weighted) at SC4, and 0.9 at SC5, anchored on the Vardi (2011) maturity threshold of 4 000 cm² (LHP row 2); f_fert = 0.95 wild fertilization success (Mendoza-Quiroz et al. 2023; LHP row 32); and s_recruit = 0.027 yr⁻¹ from the synthesis recruit-survival pool (above).

The sixth term, ε_settle, is the only parameter in the framework that we did not transcribe directly from the literature. ε_settle rescales Chamberland et al. (2015) controlled-nursery recruit survival to wild Caribbean broadcast-spawning rates, where settlement and early post-settlement losses are orders of magnitude higher than under nursery conditions. We calibrate ε_settle once so that S1 produces a sexual-recruitment fraction (proportion of new SC1 individuals from **F_sex** rather than **F_frag**) within 0.05–0.15 — the range reported across published Caribbean *A. palmata* monitoring (Williams and Miller 2012; Mendoza-Quiroz et al. 2023). The calibrated value is ε_settle = 1 × 10⁻⁴. Because this is the framework's only non-literal-from-literature choice, we report sensitivity of λ to ε_settle ∈ {1 × 10⁻⁵, 1 × 10⁻⁴, 1 × 10⁻³} alongside the main results, and we flag the calibration in figure captions and in the supplementary parameter table.

### External environmental covariates

Two scenario layers require time-resolved environmental data not held in the LHP CSV. Winter sea-surface temperature anomalies feed the S5 disease-risk model (described below), and a degree-heating-week (DHW) dose–response curve feeds the acute heatwave overlay. We queried winter SST from the NOAA ERSST v5 monthly 2° product through the `rerddap` R package (`51_winter_sst_anomalies.R`), restricting to January–March means at each region centroid and expressing each value as an anomaly against the 1981–2010 climatology. We attempted the higher-resolution daily OISST v2 product first; multi-year ERDDAP requests timed out repeatedly, so we fell back to ERSST v5 and document the fallback in the script header. The DHW × mortality dose–response was digitized from Manzello et al. (2025, *Science*), Figure 2, and is implemented as a multiplicative survival modifier in `40_heatwave_scenario.R`. All Florida vital rates that feed the matrix come from observations before the 2023 Florida heatwave collapse, so the deterministic **A** describes the chronic demographic regime that operated before that event, and the heatwave overlay layers Manzello's acute response on top.

### Parameter packaging

All vital rates and their bootstrap distributions are written to `parameter_lists/*.rds` by `06_analysis/scripts/17_update_parameter_lists.R`. The web platform consumes these objects directly, so any rerun of script 17 propagates to the deployed RSE without manual handoff.

## Literature search for biological-realism parameters

Six scenarios in the framework (S1, S2, S3, S5, S6, S7) require parameters that the synthesis dataset does not contain — sexual fecundity, sterility lag, partial-mortality penalties, winter-temperature disease responses, density-dependent corallivory, and depth-conditional survival. We sourced these through a curated, two-stage literature search distinct from the systematic survival/growth review of synthesis Methods §2.1. External environmental covariates (NOAA ERSST v5 winter SST; Manzello 2025 DHW dose–response) were sourced separately as data products and are described in §Model parameterization (External environmental covariates).

### Stage 1 — Topical mechanism review

We assembled four topical reading lists from the included papers of the systematic review plus targeted forward and backward citation chaining on the central restoration-demography literature (Lirman 2000a,b; Williams and Miller 2012; Vardi 2011; Boisvert et al. 2024): (i) *A. palmata* restoration, (ii) coral regeneration and partial mortality, (iii) density-dependent coral biology, and (iv) long-term survival of restoration outplants. We reviewed each list for quantitative parameter values relevant to seven mechanisms: sexual fecundity, post-fragmentation sterility, partial-mortality fecundity penalty, time-since-outplanting decay, winter-SST disease anomalies, depensatory corallivory, and depth/microhabitat survival modifiers. For each candidate value we recorded the species, region, sample size, and reporting interval, and we retained only values traceable to a specific table, figure, or paragraph in the source paper.

### Stage 2 — Parameter extraction into the LHP CSV

We transcribed verified values into the LHP CSV (`05_data/standardized/apal_life_history_parameters.csv`; 43 rows). One row holds one parameter; columns capture value, unit, region, source paper, scope note, and two screening flags: `analysis_include` (Boolean — is the value defensible without sensitivity bracketing?) and `relevance_class` (`direct_apal`, `congener_apal`, or `genus_only`). We preferred direct *A. palmata* values, retained congeneric values (e.g., *A. cervicornis* in Boisvert et al. 2024) only when no *A. palmata* equivalent existed and the mechanism is documented across the genus, and rejected genus-only values that lacked species-level resolution. Each scenario's parameters reference specific LHP rows (maturity threshold, row 2; oocyte density, row 4; lesion fecundity penalty, row 3; sterility lag, row 25; corallivory rates, rows 22–23). The scripts that assemble each scenario layer (`53_sexual_fecundity_layer.R` through `59_microhabitat_depth_model.R`) cite their LHP source rows in the script header so that every model coefficient is traceable to a specific paragraph in a specific paper.

### Pre-registration

All nine scenarios, their hypothesized direction of λ change, their literature anchors, and their LHP row mapping are pre-specified in `07_reporting/internal/biological_realism_PRD.md` (PRD §3 "Hypotheses and citations"; PRD §4 "Scenario comparison matrix"). We added no scenario after results were inspected and adjusted no parameter to alter λ.

## Scenario framework

Each scenario applies a defined transformation to one or more elements of {**S**, **G**, **F_frag**, **F_sex**}. All scenarios share the same baseline **S** vector and **G** matrix from §Model parameterization so that any λ shift is attributable to the toggled mechanism rather than to a re-fit of core data. We describe the nine scenarios in the order they appear in Results (S0 → S8) and report one acute-heatwave overlay that can be applied on top of any S0–S8 baseline.

**S0 — Baseline.** **F_sex** = **0**; **F_frag** as in §Model parameterization. λ_S0 = 0.9613 (within 1 × 10⁻³ of the published Vardi 2011 value). S0 anchors all Δλ comparisons.

**S1 — Size-threshold sexual fecundity.** We construct **F_sex** as in §Model parameterization (Sexual fecundity matrix) and add it to **A**. S1 isolates the population-level effect of recognizing sexual reproduction as a distinct demographic pathway from fragmentation.

**S2 — Post-disturbance sterility lag.** Lirman (2000a; LHP row 26) demonstrates that *A. palmata* colonies remain sexually sterile for approximately four years after fragmentation. In `54_sterility_lag_layer.R` we apply

> **F_sex^(S2)[SC1, *s*] = F_sex^(S1)[SC1, *s*] × (1 − π_recent_disturb(*s*))**,

where π_recent_disturb(*s*) is the fraction of size-class-*s* colony-years within the four-year sterility window of either fragmentation (`fragment == "Y"`) or a curated Caribbean disturbance event (synthesis Methods §2.2 timeline; 18 events). Because π depends on rolling colony history, we apply S2 within stochastic projection (50-year horizon, 1 000 trajectories) rather than to the deterministic single-year matrix.

**S3 — Partial-mortality fecundity penalty.** Piñón-González and Banaszak (2018; LHP row 3) report a 20% reduction in oocyte volume in colonies with old or permanent partial-mortality lesions (regeneration has stopped and the lesion margin has been colonized by algae or sediment), and Lirman (2000b; LHP rows 15–18) shows lesions larger than ~20 cm² fail to regenerate. We compute the fraction of lesioned colony-years per size class (`apal_lesion_state.csv`, generated by `52_colony_lesion_state.R` from per-colony tissue-loss intervals) and apply

> **F_sex^(S3)[SC1, *s*] = F_sex^(S2)[SC1, *s*] × (1 − 0.20 × π_lesion(*s*))**.

**S4 — Time-since-outplanting decay.** We derive `years_since_outplant` per coral_id as elapsed years from each colony's first observation in `50_derive_outplant_age.R` and fit a binomial GLMM in `56_outplant_age_model.R`:

> **logit(S_ij) = β₀ + β₁ log(area_ij) + β₂ years_outplant_ij + u_j**, &nbsp;&nbsp; *u_j* ∼ N(0, σ²_study).

The fitted age coefficient β₂ replaces the pooled restoration-survival vector in restoration-weighted scenarios. Boisvert et al. (2024, *Restoration Ecology* 32:e14129) — which reports near-zero *A. cervicornis* restoration-site survival approximately two-to-four years post-outplanting in the absence of supplementation — anchors the functional form. We use the *A. cervicornis* trajectory only as a prior shape; the fitted coefficient comes from *A. palmata* data (n = 1 207 restoration colony-years across five studies: NOAA Acropora Demographic Monitoring, Kuffner et al. 2020, Pausch et al. 2018, USGS USVI experiment, and FUNDEMAR fragments). The overdispersion ratio is 0.958 (∑ Pearson² / residual df; p = 0.849), and we report the diagnostic with the model in Fig. S29.

**S5 — Winter-SST × size disease interaction.** Region- and year-specific January–March SST anomalies from §Model parameterization (External environmental covariates) are joined to the synthesis colony-year survival table. In `57_winter_sst_survival_model.R` we fit

> **logit(S_ij) = β₀ + β₁ log(area_ij) + β₂ winter_anom_ij + β₃ log(area_ij) × winter_anom_ij + u_j**.

The interaction term captures the size-biased disease-mortality pattern documented by Rodriguez-Martinez et al. (2014; LHP rows 19–20: 48% white-pox prevalence in colonies > 75 cm versus 0% in colonies < 5 cm). The fitted model produces a multiplicative survival modifier applied to the baseline **S** vector for each region-year. Sample sizes per region-year are reported in Table S\_RSE1 and the overdispersion check is reported with the model.

**S6 — Depensatory corallivory (Allee).** Williams and Miller (2012; LHP rows 22–23) report that *Coralliophila abbreviata* corallivory consumes 16 cm² per snail-day and produces approximately 27% background loss when fewer than two snails occupy a colony. In `58_depensatory_corallivory_layer.R` we model SC1 and SC2 survival as Beverton–Holt density-dependent:

> **S(D) = S₀ × D / (K + D)**,

where D is local *A. palmata* density (proxied by `group_N` per study × year) and K is fit by profile likelihood on SC1–SC2 between-study survival variance. K is poorly constrained at the available study counts, so we report sensitivity of λ to K ∈ {0.5, 1, 2, 4} × observed median D alongside the central fit.

**S7 — Microhabitat / depth refugia.** Using the `depth_m` column in `apal_surv_ind.csv`, we fit in `59_microhabitat_depth_model.R`:

> **logit(S_ij) = β₀ + β₁ log(area_ij) + β₂ depth_ij + u_j**

and report the reduction in residual heterogeneity (ΔI²) attributable to depth, with the overdispersion check. Ramos-Romero et al. (2025; Cuba; LHP rows 30–31: growth +7.3 versus −1.5 cm yr⁻¹ across flow regimes) and Kuffner et al. (2020; Dry Tortugas; LHP rows 6–7) anchor the interpretation.

**S8 — All combined.** All six modifiers (S1–S3 fecundity; S4–S7 survival) stack in a single projection matrix to test for super-additive interactions among mechanisms. We compare the S8 Δλ against the sum of individual scenario Δλ values and flag interactions with |residual| ≥ 0.02 as super-additive.

**Acute heatwave overlay (script 40).** This is a separate layer applicable on top of any S0–S8 baseline. The Manzello et al. (2025, *Science*) DHW × mortality dose–response is implemented as a multiplicative survival modifier S_DHW(*s*) = S(*s*) × (1 − M_Manzello(DHW)). The fitted overlay reaches modeled mortalities of 0.92–0.97 at 16–20 DHW, anchored on the Manzello observed values of 0.978–1.000 at those exposures (`manzello_dose_response.csv`). The overlay reproduces the 2023 Florida functional-extinction signal under prescribed DHW exposure trajectories; results are reported in Fig. S22.

`60_scenario_comparison.R` assembles all scenarios; `61_fig_biological_realism.R` renders the tornado plot of |Δλ| versus S0 (Fig. S29).

## Projection metrics and uncertainty

For each scenario we compute (i) the deterministic population growth rate λ = |Re(eigen(**A**)$values[1])|; (ii) stage-structured elasticity ∂ log λ / ∂ log a_ij from base `eigen()`-based left and right eigenvector decomposition (the same algorithm `popbio::eigen.analysis()` implements; we did not depend on `popbio` because the routine is short enough to write directly and avoids a package load), with particular attention to the SC5 stasis cell that dominates the published baseline; (iii) the sexual-replacement fraction (proportion of new SC1 individuals from **F_sex** versus **F_frag**); (iv) bootstrap 95% confidence intervals on λ from the 2 000-iteration hierarchical bootstrap of §Model parameterization (Annual survival); (v) probability of decline P(λ < 1) from the bootstrap distribution; and (vi) quasi-extinction time QE_t (median years until **n**(*t*) sums to fewer than 10 colonies starting from a stage-stable distribution of 100 colonies, computed across 1 000 stochastic 50-year trajectories with year-to-year resampling of survival from the bootstrap pool). We also report the Tuljapurkar small-noise approximation to the stochastic growth rate λ_s ≈ λ − σ²/(2 λ) for direct comparison with the deterministic value.

For each scenario, Results tabulate Δλ (= λ_scenario − λ_S0), P(decline), QE_t, sexual-replacement fraction, and the SC5 stasis elasticity, in this order, so the Methods order above maps one-to-one onto the Results table.

## Software and reproducibility

All analyses use R ≥ 4.3 with `metafor` (meta-analysis), `mgcv` (size-dependent GAMs), `lme4` and `lmerTest` (binomial GLMMs), `rerddap` (NOAA ERSST v5 queries), and `patchwork` and `ggplot2` (figures). Eigen-decomposition and elasticity are implemented with base R `eigen()` rather than a population-biology helper package. The full pipeline is orchestrated by `06_analysis/scripts/run_all.R`; biological-realism scenario regeneration alone takes ~15 min on a 2023-era laptop. Code, data, derived parameter distributions, and a manifest of every output file are archived at `github.com/stier-lab/Detmer-2025-coral-parameters` (this repo); the interactive web application is at `github.com/stier-lab/Detmer-2025-coral-RSE` (`coral-app/` directory). Anyone with the repository, the standardized data tables, and the LHP CSV can reproduce every λ, every Δλ, and every figure reported here.

## Web platform

The interactive front end lives in the `coral-app/` directory of the modeling repository (`stier-lab/Detmer-2025-coral-RSE`) as a React + TypeScript + Vite application. Core model logic is ported to TypeScript in `coral-app/src/lib/model/` and kept in sync with the R implementations of `compute_lambda_from_survival()` and `run_scenario()` (utils/03_matrix_functions.R), so the front end runs the same projection algorithm and consumes the same `parameter_lists/*.rds` distributions written by script 17. An earlier prototype platform (`stier-lab/Detmer-2025-coral-platform`) has been archived; the current `coral-app/` supersedes it.
