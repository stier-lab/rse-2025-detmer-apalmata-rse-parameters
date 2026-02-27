# Manuscript Figure Plan: Population Viability Assessment of *Acropora palmata*

**Detmer, R. & Stier, A.C.**
**Last Updated:** March 2026 (PVA reframe)

**New title:** *"Size-structured population demography of Acropora palmata: a Caribbean synthesis and updated population viability assessment"*

**Target Journal:** *Coral Reefs* (Springer)
- Single-column width: 84 mm | Double-column width: 174 mm | Max height: 234 mm
- Font: Helvetica/Arial, 8-12 pt | Panel labels: lowercase (a, b, c)
- No titles/captions within figures | Color: RGB, free for print+online
- Submission guidelines: https://link.springer.com/journal/338/submission-guidelines

---

## Core Thesis

We update Vardi et al.'s (2012) Lefkovitch matrix with the largest demographic dataset assembled for this species (~9,500 observations, 6 individual + 10 summary studies, 10 Caribbean regions). The updated model indicates probable decline (lambda = 0.986, P(decline) = 87.3%), with large-adult survival (SC5 stasis = 54.8% elasticity) as the most critical vital rate. Extreme heterogeneity (I^2 = 97.8%) means site-specific parameters are essential for local management.

---

## Narrative Architecture (3 Acts)

The manuscript tells a three-act story. Each act corresponds to a core question, anchored by one or two main figures. Supplementary figures provide the evidentiary depth that readers and reviewers need to trust the claims.

| Act | Question | Main Figure | Key Message |
|-----|----------|-------------|-------------|
| 1 | What are the vital rate inputs? | Fig 1 (landscape) + Fig 2 (vital rates) | Size-dependent survival and growth, validated across 15 studies |
| 2 | How uncertain are the pooled estimates? | Fig 3 (meta-analysis) | k=16 synthesis, extreme heterogeneity, regional variation |
| 3 | What does this mean for population viability? | Fig 4 (PVA) | lambda=0.986, SC5 stasis=54.8%, LOSO sensitivity |

### Story Flow Diagram

```
Fig 1 (WHERE)     Fig 2 (WHAT)          Fig 3 (HOW MUCH)     Fig 4 (SO WHAT)
Study landscape -> Size-dependent    ->  Caribbean k=16    -> PVA: lambda=0.986
+ data gaps        vital rates           synthesis             SC5 = 54.8%
                   + SC synthesis         + regional var        + LOSO sensitivity
```

### Act 1 -- "The vital rate inputs" (Introduction/Methods/Results ss 1-2 -> Fig 1 + Fig 2)

**Main text claims:** (a) We assembled the largest demographic dataset for *A. palmata* -- 9,500 observations from 6 individual-level studies across 10 Caribbean regions -- but geographic coverage is uneven (Florida/NOAA = 78%). (b) Survival increases with size but is a weak predictor (R^2 = 5.8%, no threshold). RGR declines monotonically with a threshold at ~36 cm^2. (c) The monotonic size-survival pattern is confirmed across all 15 studies (individual + summary data), with k=7-10 studies per size class.

| Main | Supports | Supplement |
|------|----------|-----------|
| **Fig 1a** (Caribbean map) | What the data looks like | **S1** (size distribution: bimodal, median 585 cm^2) |
| **Fig 1b** (data availability matrix) | Where the gaps are | **S2** (certainty heatmap: only 17% of cells adequate) |
| **Fig 2a** (survival GAM) | Model adequacy | **S3** (diagnostics: residuals, Q-Q, overdispersion) |
| | Model choice | **S4** (model selection: GAM vs GLMM comparison) |
| | Threshold methodology | **S5** (threshold detection: survival gate fails, growth gate passes) |
| **Fig 2b** (RGR GAM + threshold) | Why RGR not AGR | **S6** (AGR R^2 = 1.5% vs RGR R^2 = 33.9%) |
| | Allometric variation | **S7** (initial vs final size by study, size ranges) |
| **Fig 2c** (SC survival synthesis) | Size-survival across all data tiers | (supported by Fig 2a individual-level GAM) |

**Transition to Act 2:** "Given this size-dependent variation, what does the full Caribbean evidence base say about overall survival?"

---

### Act 2 -- "Uncertainty in pooled estimates" (Results ss 3 -> Fig 3)

**Main text claims:** Pooled annual survival = 81.1% (95% CI: 73.2-87.1%) across k=16 studies. Natural colonies (85.1%, k=6) vs restoration fragments (78.3%, k=10) -- the 6.8 pp difference is not statistically significant (p = 0.30). I^2 = 97.9% -- extreme heterogeneity persists even at k=16. Region explains 39.3% of variance but is not significant at k<10/region.

| Main | Supports | Supplement |
|------|----------|-----------|
| **Fig 3a** (expanded forest plot k=16) | Natural vs restoration detail | **S8** (natural vs restoration: 12-panel comparison, DEMOTED from main) |
| | Forest plots (k=5 original) | **S9** (forest plots: I^2 = 97.8%) |
| | Heterogeneity decomposition | **S10** (I^2 decomposition, variance components) |
| **Fig 3b** (regional survival variation) | Context effects | **S11** (field vs nursery vs lab) |
| | Climate interactions | **S12** (climate-demography) |

**Transition to Act 3:** "How do these size-dependent vital rates combine to determine population trajectory?"

---

### Act 3 -- "Population viability" (Results ss 4 -> Fig 4)

**Main text claims:** lambda = 0.986 -> estimated 1.4% annual decline, P(decline) = 87.3%, but the 95% CI [0.819, 1.020] includes replacement. SC5 stasis accounts for 54.8% of elasticity -- protecting large adults is the most effective conservation lever. Results are sensitive to NOAA data dominance.

| Main | Supports | Supplement |
|------|----------|-----------|
| **Fig 4a** (transition matrix heatmap) | Transition structure | (supported by Table 4 in main text) |
| **Fig 4b** (elasticity decomposition) | Conservation priorities | **S13** (multi-dimensional sensitivity analysis) |
| **Fig 4c** (bootstrap lambda) | Sensitivity to assumptions | **S14** (cross-validation) |
| **Fig 4d** (LOSO lambda sensitivity) | Cross-validation | **S15** (population projections) |
| | Variance partitioning | **S16** (size x space x time decomposition) |

**Discussion anchor:** The data gaps (Fig 1b) from Act 1 and the expanded meta-analysis (Fig 3) from Act 2 circle back here: the most important parameter (SC5 stasis) is also the one with the least geographic coverage, and the expanded k=16 synthesis still shows extreme heterogeneity (I^2 = 97.9%).

---

### The Punchline

Size matters for both survival and growth -- a pattern confirmed across all 15 studies in the evidence base (Fig 2c). Natural colonies show 6.8 pp higher survival than fragments, but this difference is not statistically significant (p = 0.30) in the expanded k=16 meta-analysis with 6 natural colony studies across 5 regions (Fig 3a). Study-level variation exceeds the apparent natural-vs-restoration difference. The updated population model provides evidence for decline (lambda = 0.986, P(decline) = 87.3%), though the 95% CI [0.819, 1.020] includes replacement. The most critical demographic parameter (large-adult persistence, 54.8% elasticity) has the least geographic coverage. The expanded meta-analysis narrows the overall survival CI from 32.5 pp to 13.9 pp, but extreme heterogeneity (I^2 = 97.9%) persists -- the 95% prediction interval (43-96%) spans nearly the full range of possible survival. These gaps define the research agenda.

---

## Main Text Figures (4 figures)

### Figure 1: Study Landscape
**Script:** `18_fig1_study_landscape.R`
**Dimensions:** 174 x 130 mm (double-column)
**Output:** `analysis/figures/manuscript/Fig1_study_landscape.{png,pdf}`

**Panel a: Caribbean Map**
- Study sites as bubbles (size = sample size)
- `rnaturalearth` coastlines, bounding box: 90-58W, 10-28N
- Region labels with coordinate nudges and sample sizes
- Top legend: observation count bubble sizes

**Panel b: Data Availability Matrix**
- 5 SC rows (SC1-SC5) x region columns
- Fill = sample size (n), grey = missing data
- Highlights geographic gaps in coverage, especially SC5

**Key message:** Where and how much -- most data from Florida Keys (NOAA, 78%), geographically uneven coverage. SC5 has no data outside 3 regions.

**Note:** S1 (size distribution) is moved to supplement.

---

### Figure 2: Size-Dependent Vital Rates
**Script:** `19_fig2_demographic_rates.R` (combined with content from `20_fig_size_class_survival_synthesis.R`)
**Dimensions:** 174 x 220 mm (double-column)
**Output:** `analysis/figures/manuscript/Fig2_demographic_rates.{png,pdf}`

**Panel a: Survival Probability**
- GAM smooth (binomial, k=4, REML) with 95% CI ribbon on log10 x-axis
- Binned observed proportions as overlay points (25 bins, n >= 5)
- Rug marks: survived (top, blue), died (bottom, orange)
- Full range: 1-15,000 cm^2
- Natural colonies only (n = 3,926 from 2 studies)
- No survival threshold (Detmer et al. 2025 gate did NOT pass)

**Panel b: Relative Growth Rate**
- Scatter cloud (alpha = 0.08) on log10 x-axis, full range 1-15,000 cm^2
- GAM smooth (Gaussian, k=4, REML) with 95% CI ribbon
- Binned medians as overlay points (25 bins, Okabe-Ito orange)
- Zero reference line (dashed horizontal)
- Detmer et al. (2025) RGR threshold at 36 cm^2 (dashed orange vertical line)
- 95% LOSO bootstrap CI band: 33-396 cm^2 (shaded orange)
- Natural colonies only (n = 3,034)

**Panel c: Size-Class Survival Synthesis**
- SC1-SC5 survival rates across all 15 studies (individual-level + summary-level data)
- Study points colored by population type (natural vs restoration)
- Pooled line connecting size-class means
- k=7-10 studies per size class
- Survival increases from ~78% (SC2-SC3) to ~97% (SC5)

**Key message:** Survival increases with size (R^2 = 5.8%, no threshold). RGR declines monotonically with a significant threshold at ~36 cm^2. The monotonic size-survival relationship is not an artifact of NOAA dominance -- it is confirmed across 15 studies spanning both individual and summary data tiers.

---

### Figure 3: Caribbean Survival Synthesis
**Script:** `20b_fig_expanded_forest_plot.R` (combined with content from `20c_fig_regional_survival.R`)
**Dimensions:** 174 x 200 mm (double-column)
**Output:** `analysis/figures/manuscript/Fig3_caribbean_synthesis.{png,pdf}`

**Panel a: Expanded Forest Plot (k=16)**
- k=16 study meta-analysis of annual survival
- Stratified by natural (k=6) vs restoration (k=10) subgroups
- Subgroup pooled diamonds for natural and restoration
- Overall pooled diamond: 81.1% (95% CI: 73.2-87.1%)
- Prediction interval shown
- I^2 = 97.9%

**Panel b: Regional Survival Variation**
- Horizontal point-range plot showing survival across Caribbean regions
- Regions ordered by survival (lowest to highest)
- Study-level points overlaid
- Region explains 39.3% of variance (not significant at k<10/region)

**Key message:** Pooled annual survival = 81.1% (95% CI: 73.2-87.1%). Natural colonies (85.1%, k=6) survive 6.8 pp better than restoration fragments (78.3%, k=10), but this difference is not statistically significant (p = 0.30). The expanded meta-analysis narrows the CI from 32.5 pp (k=5) to 13.9 pp (k=16), but extreme heterogeneity persists. With k=6 natural colony studies, the NOAA-only confound is broken.

---

### Figure 4: Population Viability Assessment
**Script:** `22_fig6_population_model.R`
**Dimensions:** 174 x 200 mm (double-column)
**Output:** `analysis/figures/manuscript/Fig4_population_model.{png,pdf}`

**Panel a: 5x5 Transition Matrix Heatmap**
- NEW panel derived from `transition_matrix.csv`
- From-class (columns) x To-class (rows) heatmap
- Fill = transition probability, annotated with values
- Highlights dominant diagonal (stasis) and off-diagonal (growth/retrogression)
- Fragmentation visible in top rows

**Panel b: Elasticity Decomposition**
- Stacked bar chart: x = SC1-SC5, y = elasticity, fill = vital rate type
- Vital rate types: Stasis (blue), Growth (teal), Retrogression (grey), Fragmentation (coral)
- SC5 stasis highlighted with annotation arrow (54.8% of total elasticity)
- Colors from MANUSCRIPT_PALETTE

**Panel c: Bootstrap Lambda Distribution**
- Histogram of bootstrap lambda values (n = 2,000 replicates)
- Bicolor fill: decline (orange) vs growth (blue) split at lambda=1
- Vertical lines at lambda=1 (solid grey) and observed lambda (dashed blue)
- Annotations: lambda = 0.986, 95% CI, P(decline), valid/total counts

**Panel d: Leave-One-Study-Out Lambda Sensitivity**
- Horizontal point plot: lambda when each study excluded
- Vertical dashed reference line at full-model lambda (0.986)
- NOAA removal highlighted in red: lambda drops 0.986 -> 0.951
- Annotation: "NOAA = 78% of data"

**Key message:** SC5 stasis dominates elasticity (54.8%), identifying large-adult protection as the most effective conservation lever. lambda = 0.986 provides evidence for ~1.4% annual decline (P(decline) = 87.3%), though the 95% CI includes replacement. Results robust to exclusion of most studies but sensitive to NOAA data.

---

## Supplementary Figures (16 figures)

The supplement provides methodological validation, alternative analyses, and deeper explorations that support the four main figures. Natural vs restoration comparison (formerly Fig 3) is demoted to supplement (S8) because the difference is not statistically significant (p = 0.30) and is secondary to the PVA narrative.

| # | Content | Source Script | Dimensions |
|---|---------|---------------|-----------|
| S1 | Colony size distribution | `18_fig1_study_landscape.R` | 174 x 100 mm |
| S2 | Data certainty heatmap | `23_figS2_data_gaps.R` | 174 x 100 mm |
| S3 | Model diagnostics | `24_supp_S3_S4.R` | 174 x 180 mm |
| S4 | Model selection | `24_supp_S3_S4.R` | 174 x 190 mm |
| S5 | Threshold analysis | `25_supp_S5_S6_S7_thresholds_growth.R` | 174 x 80 mm |
| S6 | AGR vs RGR | `25_supp_S5_S6_S7_thresholds_growth.R` | 174 x 155 mm |
| S7 | Allometry by study | `25_supp_S5_S6_S7_thresholds_growth.R` | 174 x 160 mm |
| S8 | **Natural vs restoration** (DEMOTED from main) | `21_fig3_natural_vs_restoration.R` | 174 x 140 mm |
| S9 | Forest plots (k=5) | `26_supp_S8_S9.R` | 174 x 185 mm |
| S10 | Heterogeneity decomposition | `26_supp_S8_S9.R` | 174 x 174 mm |
| S11 | Context comparison | `27_supp_S10_S11.R` | 174 x 160 mm |
| S12 | Climate-demography | `27_supp_S10_S11.R` | 174 x 170 mm |
| S13 | Sensitivity analysis | `28_supp_S12_S13_S14.R` | 174 x 160 mm |
| S14 | Cross-validation | `28_supp_S12_S13_S14.R` | 174 x 100 mm |
| S15 | Population projections | `28_supp_S12_S13_S14.R` | 174 x 110 mm |
| S16 | Variance partitioning | New supplementary from script 05 output | TBD |

### Supplement Section Organization

**SI-1: Data Landscape (supports Fig 1)**
- S1 -- Colony size distribution (bimodal, median 585 cm^2, 4 orders of magnitude)
- S2 -- Data certainty heatmap (only 17% of size x region cells adequate; SC5 outside 3 regions = zero coverage)

**SI-2: Statistical Framework (supports Methods)**
- S3 -- Model diagnostics (survival + growth: residuals, Q-Q, overdispersion, variance)
- S4 -- Model selection (survival + growth: delta-AICc comparison across candidate models)

**SI-3: Nonlinearity and Thresholds (supports Fig 2a-b)**
- S5 -- Threshold analysis (survival gate fails, delta-AICc = 0.83; RGR gate passes, delta-AICc = 58.4; P(+growth) dome at 435 cm^2)

**SI-4: Growth Metrics and Allometry (supports Fig 2b)**
- S6 -- AGR vs RGR comparison (AGR R^2 = 1.5% vs RGR R^2 = 33.9%)
- S7 -- Allometry by study (overall scaling slope = 0.907; by-study slopes 0.25-0.92; size ranges)

**SI-5: Natural vs Restoration (supports Fig 3, formerly main text)**
- S8 -- Natural vs restoration comparison (12-panel faceted GLM/LM; 6.8 pp survival difference, p = 0.30; within-restoration heterogeneity = 31 pp)

**SI-6: Meta-Analysis and Heterogeneity (supports Fig 3a)**
- S9 -- Forest plots (k=5 original meta-analysis, I^2 = 97.8%)
- S10 -- Heterogeneity decomposition (I^2 gauge, variance components, CI vs PI, moderator effects)

**SI-7: Contextual Variation (supports Fig 3b)**
- S11 -- Context comparison (field vs nursery vs lab: survival by context and context x size class)
- S12 -- Climate-demography (temporal trends, disturbance effects, climate vulnerability by size)

**SI-8: Population Model Robustness (supports Fig 4)**
- S13 -- Sensitivity analysis (multi-dimensional robustness dashboard, bootstrap CIs by size class)
- S14 -- Cross-validation (LOSO Brier scores, 5-fold CV model comparison)
- S15 -- Population projections (deterministic 20-year trajectory, stochastic with 80% PI and quasi-extinction risk)
- S16 -- Variance partitioning (size x space x time decomposition of demographic variance)

---

## How the Supplement Answers Reviewer Questions

| Likely reviewer question | Where to point them |
|-------------------------|-------------------|
| "How do you know the GAM is appropriate?" | SI-2 (S3 diagnostics, S4 model selection) |
| "Why not use AGR?" | SI-4 (S6 AGR vs RGR: 22x more variance explained) |
| "The threshold CI is wide -- how reliable is it?" | SI-3 (S5 threshold analysis with gate tests) |
| "Can you really pool across studies with I^2 = 98%?" | SI-6 (S9 forest plots, S10 heterogeneity decomposition) |
| "What about publication bias?" | Text: Egger's p = 0.78 (k=5 too few for funnel plot) |
| "How sensitive is lambda to your assumptions?" | SI-8 (S13 sensitivity, S14 cross-validation) |
| "What happens to the population long-term?" | SI-8 (S15 population projections) |
| "Where should future studies focus?" | SI-1 (S2 certainty heatmap) + Discussion |
| "How does climate affect these patterns?" | SI-7 (S12 climate-demography) |
| "Are nursery results comparable to field?" | SI-7 (S11 context comparison) |
| "Is the size-survival pattern robust beyond 6 studies?" | Fig 2c (SC synthesis across all 15 studies) |
| "How generalizable is the meta-analysis with only k=5?" | Fig 3a (expanded to k=16; CI narrows from 32.5 to 13.9 pp) |
| "Is the natural vs restoration difference real?" | Fig 3a (6.8 pp, p = 0.30, not significant) + SI-5 (S8 detail) |
| "Does survival vary by region?" | Fig 3b (regional survival, 9+ regions) |
| "What is the transition matrix structure?" | Fig 4a (heatmap) + Table 4 (values with CIs) |
| "Why is SC5 so important?" | Fig 4b (elasticity decomposition: 54.8%) |

---

## Tables

### Main Text Tables (5)

| Table | Content | Supports |
|-------|---------|----------|
| **Table 1** | Study metadata (16 studies: region, years, n, methods, population type) | Fig 1, Act 1 |
| **Table 2** | Survival by size class (mean, CI, n, k) | Fig 2a + 2c, Act 1 |
| **Table 3** | Growth by size class (RGR, AGR, % positive, CIs) | Fig 2b, Act 1 |
| **Table 4** | 5x5 Transition matrix with bootstrap CIs | Fig 4a, Act 3 |
| **Table 5** | Elasticity summary with Vardi (2012) comparison | Fig 4b, Act 3 |

### Supplementary Tables (3)

| Table | Content | Supports |
|-------|---------|----------|
| **Table S1** | Regional sample sizes (Region x Size Class x Population Type) | Fig 1, Fig 3b |
| **Table S2** | Meta-analysis results (effect sizes, CIs, weights, prediction intervals) | Fig 3a |
| **Table S3** | Data gap priority rankings (Impact x Feasibility x Urgency scores) | Discussion |

---

## Manuscript Section Outline

### Introduction (~800 words)
1. Historical decline of *A. palmata* (ESA listing, >95% loss since 1980s)
2. The need for PVA: restoration programs need vital rate targets, but current estimates come from single regions
3. Vardi et al. (2012): first Lefkovitch matrix for this species, one region, no uncertainty quantification
4. This paper: update PVA with largest demographic dataset, quantify uncertainty, identify critical vital rates and data gaps

### Methods (~1500 words)
1. Data compilation and standardization (6 individual + 10 summary studies, 10 Caribbean regions)
2. Size class definitions (SC1-SC5: 0-25, 25-100, 100-500, 500-2000, 2000+ cm^2)
3. Size-dependent vital rate estimation (GAMs, GLMMs, Detmer et al. 2025 threshold detection)
4. Meta-analysis (two-tier: individual-level k=5, expanded k=16, Knapp-Hartung adjustment)
5. Population projection matrix (5x5 Lefkovitch, transition estimation, fragmentation from Vardi 2011)
6. Uncertainty propagation (hierarchical bootstrap, elasticity analysis, LOSO sensitivity)

### Results (~1500 words)
1. Data landscape -- brief paragraph (~150 words) -> Fig 1
2. Size-dependent vital rates (~400 words) -> Fig 2
3. Caribbean survival synthesis (~350 words) -> Fig 3
4. Population viability assessment (~600 words) -> Fig 4

### Discussion (~2000 words)
1. Population viability and the conservation imperative (lambda = 0.986, SC5 stasis = 54.8%, comparison to Vardi 2012)
2. Heterogeneity as a practical constraint (I^2 = 97.8%, prediction interval 43-96%, NOAA dominance)
3. Data limitations (mortality definitions, size measurement heterogeneity, bootstrap failure rate = 26%)
4. Natural vs restoration (6.8 pp, p = 0.30, within-study heterogeneity exceeds between-type difference)
5. Priority data gaps (SC5 beyond 3 NOAA regions, climate integration, standardized monitoring protocols)
6. Conclusions (protect large adults, collect site-specific data, standardize methods across programs)

---

## Script Mapping

### Main Figures

| Figure | Script | Dimensions |
|--------|--------|------------|
| Fig 1 | `18_fig1_study_landscape.R` | 174 x 130 mm (double) |
| Fig 2 | `19_fig2_demographic_rates.R` + content from `20_fig_size_class_survival_synthesis.R` | 174 x 220 mm (double) |
| Fig 3 | `20b_fig_expanded_forest_plot.R` + content from `20c_fig_regional_survival.R` | 174 x 200 mm (double) |
| Fig 4 | `22_fig6_population_model.R` | 174 x 200 mm (double) |

### Supplementary Figures

| Figure | Script | Dimensions | File |
|--------|--------|-----------|------|
| S1 | `18_fig1_study_landscape.R` | 174 x 100 mm | `FigS1_size_distribution.png` |
| S2 | `23_figS2_data_gaps.R` | 174 x 100 mm | `FigS2_data_gaps.png` |
| S3 | `24_supp_S3_S4.R` | 174 x 180 mm | `FigS3_model_diagnostics.png` |
| S4 | `24_supp_S3_S4.R` | 174 x 190 mm | `FigS4_model_selection.png` |
| S5 | `25_supp_S5_S6_S7_thresholds_growth.R` | 174 x 80 mm | `FigS5_threshold_analysis.png` |
| S6 | `25_supp_S5_S6_S7_thresholds_growth.R` | 174 x 155 mm | `FigS6_agr_vs_rgr.png` |
| S7 | `25_supp_S5_S6_S7_thresholds_growth.R` | 174 x 160 mm | `FigS7_allometry.png` |
| S8 | `21_fig3_natural_vs_restoration.R` | 174 x 140 mm | `FigS8_natural_vs_restoration.png` |
| S9 | `26_supp_S8_S9.R` | 174 x 185 mm | `FigS9_forest_plots.png` |
| S10 | `26_supp_S8_S9.R` | 174 x 174 mm | `FigS10_heterogeneity.png` |
| S11 | `27_supp_S10_S11.R` | 174 x 160 mm | `FigS11_context_comparison.png` |
| S12 | `27_supp_S10_S11.R` | 174 x 170 mm | `FigS12_climate_demography.png` |
| S13 | `28_supp_S12_S13_S14.R` | 174 x 160 mm | `FigS13_sensitivity.png` |
| S14 | `28_supp_S12_S13_S14.R` | 174 x 100 mm | `FigS14_cross_validation.png` |
| S15 | `28_supp_S12_S13_S14.R` | 174 x 110 mm | `FigS15_population_projections.png` |
| S16 | New supplementary from script 05 output | TBD | `FigS16_variance_partitioning.png` |

---

## Figure Design Standards

### Journal: Coral Reefs (Springer)
- Single-column: **84 mm** | Double-column: **174 mm** | Max height: **234 mm**
- Formats: EPS (vector) or TIFF (raster); pipeline produces PNG (300 DPI). PDF outputs use fallback device (cairo_pdf not available on this machine).
- Line weight minimum: 0.1 mm (0.3 pt)
- Lettering contrast ratio: 4.5:1 minimum

### Palette
All figures use `MANUSCRIPT_PALETTE` from `shared_utilities.R`:
- Survival: `surv_light`/`surv_mid`/`surv_dark` (ocean blue tones)
- Growth: `grow_light`/`grow_mid`/`grow_dark` (teal/green tones)
- Natural: `natural` (#0072B2, Okabe-Ito blue)
- Restoration: `restoration` (#D55E00, Okabe-Ito vermillion)
- Accent: warm coral (#d84315)
- Threshold: #D55E00 (Okabe-Ito vermillion)
- Sequential heatmaps: `viridis` options "D" or "G"

### Typography
- Base: `theme_manuscript()` from `shared_utilities.R` (Helvetica/sans, 8-12 pt)
- Panel labels: lowercase via `labs(tag = "a")` -- plot.tag size = 12 pt
- SC boundaries: `geom_sc_boundaries()` helper
- No titles or captions within figures (per journal spec)

### Export
```r
save_manuscript_fig(plot, "filename", width_mm = 174, height_mm = H)
# Outputs PNG (300 DPI) + PDF to analysis/figures/manuscript/
# Use width_mm = 84 for single-column figures
```

### Legends
Figure legends, methods text, and results text are in:
`analysis/figures/manuscript/figure_legends.txt`

---

## Key Stats Reference

| Statistic | Value | Context |
|-----------|-------|---------|
| lambda | 0.986 | P(decline) = 87.3%, 95% CI [0.819, 1.020] |
| SC5 stasis elasticity | 54.8% | Most critical vital rate for conservation |
| I^2 (individual-level) | 97.8% | Extreme heterogeneity |
| I^2 (expanded meta) | 97.9% | Persists at k=16 |
| Expanded meta k | 16 studies | Pooled survival 81.1% (CI 73.2-87.1%) |
| Natural vs restoration | 85.1% vs 78.3% | p = 0.30, NOT significant |
| Size-survival R^2 (GAM) | 5.8% | Deviance explained |
| Size-survival R^2 (GLM) | 8.6% | McFadden pseudo-R^2 |
| RGR R^2 | 33.9% | Deviance explained |
| RGR threshold | 36 cm^2 | Detmer et al. (2025) framework |
| Bootstrap lambda samples | 2,000 total | 1,479 valid (26% failure rate) |
| LOSO lambda range | 0.951 - 0.992 | Excl NOAA = 0.951; excl Pausch = 0.992 |

---

*Last updated: 2026-03*
