#!/usr/bin/env python3
"""Fail when retired project framing reappears in manuscript-facing sources."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Keep this deliberately small at first. Add phrases here in the same change
# that retires a framing, with a note explaining the replacement.
RETIRED = {
    r"\bFigSXX\b|\bFig\. SXX\b|\bFigure SXX\b":
        "retired placeholder numbering; assign a real supplementary number before citing",
    r"\bFig2_vital_rates\b|\bFig3_natural_vs_restoration\b|\bFig5_expanded_forest_plot\b|\bFig6_population_model\b":
        "retired pre-normalization figure names; use figure_table_map.md stems",
    r"\bsupport_size_class_survival\b":
        "retired support figure stem; use Fig2 panel c or the exploratory support path explicitly",
}

SCAN = [
    ROOT / "README.md",
    ROOT / "ORIENTATION.md",
    ROOT / "CLAUDE.md",
    ROOT / "07_reporting" / "manuscript",
    ROOT / "06_analysis" / "scripts",
]

SKIP_NAMES = {
    "display_items.tsv",
    "check_vocabulary.py",
}


def iter_files():
    for path in SCAN:
        if path.is_file():
            yield path
        elif path.is_dir():
            for child in path.rglob("*"):
                if child.is_file() and child.suffix in {".md", ".txt", ".R", ".tsv"}:
                    if child.name in SKIP_NAMES or child.name.endswith("_DARK.R"):
                        continue
                    yield child


def main():
    hits = []
    files = list(iter_files())
    for path in files:
        try:
            text = path.read_text()
        except UnicodeDecodeError:
            continue
        for line_no, line in enumerate(text.splitlines(), 1):
            if "vocab-ok" in line:
                continue
            for pattern, why in RETIRED.items():
                if re.search(pattern, line, re.I):
                    hits.append((path.relative_to(ROOT), line_no, line.strip()[:100], why))

    if hits:
        print(f"FAIL - {len(hits)} retired vocabulary hit(s):")
        for path, line_no, snippet, why in hits:
            print(f"  {path}:{line_no}")
            print(f"    {snippet}")
            print(f"    -> {why}")
        sys.exit(1)

    print(f"PASS - no retired framing in {len(files)} manuscript/code files.")


if __name__ == "__main__":
    main()
