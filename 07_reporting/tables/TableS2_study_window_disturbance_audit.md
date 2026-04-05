# Study-Window Disturbance Coverage Audit

This audit rebuilds the curated disturbance overlay on prepared survival intervals and summarizes overlap by study window.

## Overall

- Intervals audited: 1,072
- Studies represented: 7
- Zero-overlap intervals: 53
- One-event intervals: 74
- Multi-event intervals: 945
- Baseline-exclusion intervals: 297

## By Study

| study | n_intervals | n_zero_overlap | n_one_overlap | n_multi_overlap | n_local_metadata_only | n_timeline_overlay | n_both_sources | n_baseline_exclusion | pct_with_any_overlap |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| NOAA_survey | 842 | 50 | 59 | 733 | 12 | 716 | 76 | 228 | 94.1 |
| neely_et_al_2022 | 98 | 3 | 0 | 95 | 0 | 56 | 39 | 10 | 96.9 |
| pausch_et_al_2018 | 70 | 0 | 0 | 70 | 0 | 70 | 0 | 46 | 100.0 |
| USGS_USVI_exp | 27 | 0 | 15 | 12 | 0 | 27 | 0 | 12 | 100.0 |
| kuffner_et_al_2020 | 27 | 0 | 0 | 27 | 0 | 27 | 0 | 0 | 100.0 |
| mendoza_quiroz_et_al_2023 | 7 | 0 | 0 | 7 | 0 | 7 | 0 | 0 | 100.0 |
| fundemar_fragments | 1 | 0 | 0 | 1 | 0 | 1 | 0 | 1 | 100.0 |

## Rebuild Check

- Exact field mismatches found: 0
