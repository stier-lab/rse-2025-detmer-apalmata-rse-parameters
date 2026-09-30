#!/usr/bin/env python3
"""Check that canonical_statistics.csv matches its declared source outputs."""
import csv
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "06_analysis" / "output"
STATS = OUT / "canonical_statistics.csv"


def read_csv(path):
    with path.open(newline="") as fh:
        return list(csv.DictReader(fh))


def as_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return math.nan


def canonical_values():
    rows = read_csv(STATS)
    return {row["metric"]: as_float(row["value"]) for row in rows}


def row_value(path, key_col, key_value, value_col):
    for row in read_csv(path):
        if row.get(key_col) == key_value:
            return as_float(row.get(value_col))
    raise KeyError(f"{path}: no row where {key_col} == {key_value!r}")


def first_value(path, value_col):
    rows = read_csv(path)
    if not rows:
        raise KeyError(f"{path}: empty file")
    return as_float(rows[0].get(value_col))


def main():
    if not STATS.exists():
        print(f"FAIL - missing {STATS.relative_to(ROOT)}")
        sys.exit(1)

    checks = {
        "all_subtypes_mean_survival_pct": 100 * row_value(
            OUT / "restoration_subtype_sensitivity.csv",
            "scenario",
            "All subtype-coded records",
            "mean_survival",
        ),
        "all_restoration_subtypes_mean_survival_pct": 100 * row_value(
            OUT / "restoration_subtype_sensitivity.csv",
            "scenario",
            "All restoration subtypes",
            "mean_survival",
        ),
        "exclude_natural_mean_survival_pct": 100 * row_value(
            OUT / "restoration_subtype_sensitivity.csv",
            "scenario",
            "Exclude natural fragments",
            "mean_survival",
        ),
        "nursery_only_mean_survival_pct": 100 * row_value(
            OUT / "restoration_subtype_sensitivity.csv",
            "scenario",
            "Nursery outplants only",
            "mean_survival",
        ),
        "matrix_compatible_shrinkage_pct": row_value(
            OUT / "shrinkage_retrogression_subset_summary.csv",
            "analysis_subset",
            "matrix_compatible",
            "shrinkage_frequency_pct",
        ),
        "disturbance_size_interaction_lrt_p": first_value(
            OUT / "disturbance_size_survival_model.csv",
            "comparison_lrt_p",
        ),
        "study_window_pct_any_overlap": first_value(
            OUT / "study_window_disturbance_summary_overall.csv",
            "pct_with_any_overlap",
        ),
    }

    got = canonical_values()
    failures = []
    for metric, expected in checks.items():
        actual = got.get(metric, math.nan)
        if math.isnan(actual):
            failures.append(f"{metric}: missing from canonical_statistics.csv")
            continue
        tol = 1e-8 if abs(expected) < 1 else 1e-6
        if abs(actual - expected) > tol:
            failures.append(f"{metric}: canonical {actual} != source {expected}")

    if failures:
        print(f"FAIL - {len(failures)} canonical statistic drift(s):")
        for failure in failures:
            print(f"  {failure}")
        sys.exit(1)

    print(f"PASS - canonical_statistics.csv matches {len(checks)} checked source values.")


if __name__ == "__main__":
    main()
