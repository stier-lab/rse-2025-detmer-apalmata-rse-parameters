#!/usr/bin/env python3
"""Verify qualitative manuscript claims against canonical statistics."""
import csv
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MSRC = ROOT / "07_reporting" / "manuscript"
CLAIMS = MSRC / "claims.tsv"
STATS = ROOT / "06_analysis" / "output" / "canonical_statistics.csv"


def load_stats():
    with STATS.open(newline="") as fh:
        rows = csv.DictReader(fh)
        out = {}
        for row in rows:
            try:
                out[row["metric"]] = float(row["value"])
            except (TypeError, ValueError):
                out[row["metric"]] = math.nan
        return out


def read_claims():
    with CLAIMS.open(newline="") as fh:
        lines = (line for line in fh if line.strip() and not line.startswith("#"))
        return list(csv.DictReader(lines, delimiter="\t"))


def main():
    stats = load_stats()
    failures = []
    checked = 0

    for claim in read_claims():
        checked += 1
        claim_id = claim["id"]
        prose_file = MSRC / claim["file"]
        if not prose_file.exists():
            failures.append(f"{claim_id}: missing prose file {prose_file.relative_to(ROOT)}")
            continue
        text = prose_file.read_text()
        if claim["sentence_contains"] not in text:
            failures.append(
                f"{claim_id}: sentence not found in {claim['file']} - "
                f"looked for {claim['sentence_contains']!r}"
            )
            continue

        metric_a = claim["metric_a"]
        if metric_a not in stats:
            failures.append(f"{claim_id}: missing metric {metric_a}")
            continue
        env = {"a": stats[metric_a]}
        metric_b = claim.get("metric_b", "-")
        if metric_b not in ("", "-"):
            if metric_b not in stats:
                failures.append(f"{claim_id}: missing metric {metric_b}")
                continue
            env["b"] = stats[metric_b]

        try:
            ok = bool(eval(claim["predicate"], {"__builtins__": {}}, env))
        except Exception as exc:
            failures.append(f"{claim_id}: predicate error: {exc}")
            continue
        if not ok:
            vals = ", ".join(f"{key}={value}" for key, value in env.items())
            failures.append(
                f"{claim_id}: claim no longer holds: {claim['claim']} "
                f"({claim['predicate']}; {vals})"
            )

    if failures:
        print(f"FAIL - {len(failures)} of {checked} claims failed:")
        for failure in failures:
            print(f"  {failure}")
        sys.exit(1)

    print(f"PASS - all {checked} qualitative claims hold against canonical statistics.")


if __name__ == "__main__":
    main()
