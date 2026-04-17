# Data Flow: Individual + Summary Survival Integration

How individual-level (0/1 per colony) and summary-level (proportion per cohort) survival data flow through the analysis pipeline.

## Full Pipeline

```mermaid
flowchart TB
    subgraph raw["Raw Data (05_data/original)"]
        NOAA["NOAA survey<br/>4,031 colonies"]
        Neely["Neely et al. 2022<br/>878 colonies"]
        Pausch["Pausch et al. 2018<br/>969 colonies"]
        USGS["USGS USVI<br/>46 colonies"]
        Kuffner["Kuffner et al. 2020<br/>52 colonies"]
        Mendoza["Mendoza-Quiroz 2023<br/>52 colonies"]
        Fundemar["FUNDEMAR fragments<br/>43 colonies"]
        SummStudies["10 summary-only studies<br/>(Rosales, Maurer, Vardi,<br/>Garrison, Bruckner, etc.)"]
    end

    subgraph standardized["Standardized Data (05_data/standardized)"]
        IndCSV["apal_surv_ind.csv<br/>~7,800 individual records<br/>(colony_id, size_cm2, survived 0/1)"]
        SummCSV["apal_surv_summ.csv<br/>332 summary records<br/>(study, n_initial, prop_survived, size range)"]
        GrowthCSV["apal_growth_ind.csv<br/>~6,300 individual records"]
        FragCSV["apal_fragmentation.csv<br/>13 records (Vardi 2011)"]
    end

    NOAA & Neely & Pausch & USGS & Kuffner & Mendoza & Fundemar --> IndCSV
    SummStudies --> SummCSV
    NOAA & Neely & Pausch & USGS & Kuffner & Mendoza & Fundemar --> GrowthCSV

    subgraph prep["01_data_preparation.R"]
        direction TB
        Clean["Clean & filter<br/>assign size classes<br/>flag sub-annual intervals"]
        Aggregate["Aggregate individual records<br/>to cells: study × size_class × interval"]
        AssignSC["Assign size class to<br/>summary records using<br/>canonical SIZE_BREAKS"]
        Stack["Stack individual cells<br/>+ summary cells<br/>compute inv-variance weights"]
    end

    IndCSV --> Clean
    Clean --> PrepSurv["prepared_survival_data.rds<br/>7,346 individual records<br/>(0/1 per colony)"]
    Clean --> Aggregate
    SummCSV --> AssignSC
    Aggregate & AssignSC --> Stack
    Stack --> PrepCells["prepared_survival_cells.rds<br/>~1,442 cells from 16 studies<br/>(n, prop_survived, yi, vi per cell)"]
    GrowthCSV --> Clean
    Clean --> PrepGrowth["prepared_growth_data.rds<br/>5,895 individual records"]

    subgraph consumers["Downstream Scripts"]
        direction TB
        Script02["02-06: Thresholds, GAMs,<br/>growth rates, variance, data gaps"]
        Script07["07: Summary data diagnostics<br/>(forest plots, regional estimates)"]
        Script08["08-12: Robustness checks<br/>(climate, power, CV, model selection)"]
        Script13["13: Transition matrix<br/>Survival: study-level rma()<br/>Growth: individual-level<br/>Bootstrap: study-level rma()"]
        Script14["14, 14b: Meta-analysis<br/>(independent rma.mv pipeline)"]
        Script17["17: RSE parameter lists<br/>field/nursery/lab survival + growth"]
        Script18["18-28: Manuscript figures"]
        Script40["40: Heatwave scenarios"]
    end

    PrepSurv --> Script02
    PrepSurv --> Script07
    PrepSurv --> Script08
    PrepSurv --> Script18
    PrepCells --> Script13
    PrepCells --> Script17
    PrepGrowth --> Script13
    PrepGrowth --> Script17
    PrepGrowth --> Script18
    FragCSV --> Script13

    subgraph outputs["Key Outputs"]
        Matrix["transition_matrix.rds<br/>5×5 Lefkovitch matrix"]
        Lambda["lambda_bootstrap_samples.rds<br/>2,000 bootstrap λ values"]
        ParamLists["parameter_lists/<br/>field/nurs/lab × surv/growth"]
    end

    Script13 --> Matrix
    Script13 --> Lambda
    Script17 --> ParamLists
```

## Cell-Level Weighting Detail

```mermaid
flowchart LR
    subgraph ind["Individual Data (7 studies)"]
        IndRaw["colony_id, size_cm2,<br/>survived (0/1)"]
        IndAgg["Aggregate to cells:<br/>group_by(study, size_class,<br/>time_interval_yr)"]
        IndCell["Cell: n=50, prop=0.82,<br/>data_source='individual'"]
    end

    subgraph summ["Summary Data (10 studies)"]
        SummRaw["study, n_initial,<br/>prop_survived, size_range"]
        SummSC["Assign size_class<br/>from size_cm2_mean"]
        SummCell["Cell: n=36, prop=0.61,<br/>data_source='summary'"]
    end

    IndRaw --> IndAgg --> IndCell
    SummRaw --> SummSC --> SummCell

    subgraph combine["Combined Cells Dataset"]
        AllCells["1,442 cells<br/>16 studies, N=26,921"]
        Annualize["Annualize each cell:<br/>S_annual = prop^(1/t)"]
        Weight["Weighted mean per size class:<br/>w_i = n_initial<br/>S_sc = Σ(w_i × S_i) / Σ(w_i)"]
    end

    IndCell & SummCell --> AllCells --> Annualize --> Weight

    subgraph result["Survival Vector"]
        SurvVec["S = (S_SC1, S_SC2, ..., S_SC5)<br/>Sample-size-weighted,<br/>all data contributing"]
    end

    Weight --> SurvVec
```

## What Changed (2026-04-07)

| Before | After |
|--------|-------|
| `prepared_survival_data.rds` (individual 0/1) fed survival in scripts 13 & 17 | `prepared_survival_cells.rds` (cell-level, weighted) feeds survival in 13 & 17 |
| 7 studies, ~7,300 colonies in survival parameter estimation | 16 studies, ~26,900 colonies |
| Summary data orphaned (script 07 outputs read by no one) | Summary data integrated via cell stacking with sample-size weights |
| Bootstrap resampled individual colonies within studies | Bootstrap resamples cells within studies (same hierarchical structure, respects variable n) |
| `prepared_survival_data.rds` unchanged — still used by 40+ scripts for thresholds, GAMs, and figures | |

---

## Related Files

- [data_integration_issues.md](data_integration_issues.md) -- Individual + summary data combination method
- [extraction_protocol.md](extraction_protocol.md) -- Inclusion/exclusion criteria and size conversion rules
- [extraction_details.md](extraction_details.md) -- Per-study verification table with audit status
- [study_characteristics.md](study_characteristics.md) -- PRISMA-style study characteristics table
- [risk_of_bias.md](risk_of_bias.md) -- Newcastle-Ottawa bias assessment per study
- [disturbance_handling_decision.md](disturbance_handling_decision.md) -- Disturbance classification and inclusion rules
- [neely_2022_data_integration.md](neely_2022_data_integration.md) -- Neely et al. 2022 integration notes
