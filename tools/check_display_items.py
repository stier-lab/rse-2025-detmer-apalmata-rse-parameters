#!/usr/bin/env python3
"""Validate display_items.tsv against rendered files, legends, and tables."""
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MSRC = ROOT / "07_reporting" / "manuscript"
INDEX = MSRC / "display_items.tsv"
FIG_DIRS = {
    "manuscript": ROOT / "06_analysis" / "figures" / "manuscript",
    "supplementary": ROOT / "06_analysis" / "figures" / "supplementary",
}
TABLE_DIR = MSRC / "tables"
ESM = ROOT / "paper" / "submission" / "supplement" / "ESM_1.md"
ALLOW_SUPP_GAP = {27}


def load_index():
    with INDEX.open(newline="") as fh:
        lines = (line for line in fh if line.strip() and not line.startswith("#"))
        return list(csv.DictReader(lines, delimiter="\t"))


def main():
    items = load_index()
    errors = []
    figure_legends = (MSRC / "figure_legends.txt").read_text()
    figure_map = (MSRC / "figure_table_map.md").read_text()
    table_readme = (TABLE_DIR / "README.md").read_text() if (TABLE_DIR / "README.md").exists() else ""
    esm_text = ESM.read_text()

    indexed_figures = set()
    for item in items:
        tier = item["tier"]
        stem = item["stem"]
        render_dir = item["render_dir"]

        if tier in {"main", "supplementary"}:
            fig_dir = FIG_DIRS[render_dir]
            indexed_figures.add((render_dir, stem))
            for ext in ("png", "pdf"):
                path = fig_dir / f"{stem}.{ext}"
                if not path.exists():
                    errors.append(f"{item['id']}: missing {path.relative_to(ROOT)}")
            if item["cite"] not in figure_legends:
                errors.append(f"{item['id']}: {item['cite']} missing from figure_legends.txt")
            if stem not in figure_map:
                errors.append(f"{item['id']}: {stem} missing from figure_table_map.md")

        if tier in {"supp_table", "support_table"}:
            if stem != "-":
                candidates = [TABLE_DIR / f"{stem}.md", TABLE_DIR / f"{stem}.csv"]
                if not any(path.exists() for path in candidates):
                    errors.append(f"{item['id']}: missing table source for {stem}")
            if item["cite"] not in figure_map and item["cite"] not in table_readme:
                errors.append(f"{item['id']}: {item['cite']} missing from table docs")

    for render_dir, fig_dir in FIG_DIRS.items():
        if not fig_dir.exists():
            continue
        for path in fig_dir.glob("Fig*.png"):
            if (render_dir, path.stem) not in indexed_figures:
                errors.append(f"orphan figure: {path.relative_to(ROOT)} is not indexed")

    main_nums = sorted(int(item["number"]) for item in items if item["tier"] == "main")
    if main_nums != list(range(1, len(main_nums) + 1)):
        errors.append(f"main figure numbering is {main_nums}, expected dense 1..{len(main_nums)}")

    supp_nums = sorted({int(item["number"]) for item in items if item["tier"] == "supplementary"})
    expected_supp = [n for n in range(1, max(supp_nums) + 1) if n not in ALLOW_SUPP_GAP]
    if supp_nums != expected_supp:
        errors.append(
            f"supplementary numbering is {supp_nums}, expected {expected_supp} "
            f"with allowed gap(s) {sorted(ALLOW_SUPP_GAP)}"
        )
    if "FigS27" in figure_legends or re.search(r"Fig\. S27\b", figure_legends):
        errors.append("Fig. S27 is intentionally vacant but appears in figure_legends.txt")
    if "FigS27" not in figure_map:
        errors.append("figure_table_map.md should document the intentional FigS27 gap")

    # The concise uploaded ESM is deliberately numbered independently from the
    # repository's extended diagnostic series.  Keep that crosswalk explicit.
    expected_esm = {
        "FigS1_growth_diagnostics": "S1",
        "FigS8_natural_vs_restoration": "S2",
        "FigS16_shrinkage_retrogression_summary": "S3",
        "FigS17_disturbance_size_interaction": "S4",
        "FigS19_restoration_subtype_sensitivity": "S5",
        "FigS22_heatwave_scenarios": "S6",
        "Studies contributing to the synthesis": "S1",
        "TableS2_study_window_disturbance_audit": "S2",
    }
    actual_esm = {item["stem"] if item["stem"] != "-" else item["short_title"]: item.get("esm_number", "")
                  for item in items if item.get("esm_number", "")}
    if actual_esm != expected_esm:
        errors.append(f"ESM mapping is {actual_esm}, expected {expected_esm}")
    for stem, number in expected_esm.items():
        if stem.startswith("Fig") and stem not in esm_text:
            errors.append(f"ESM Fig. {number} does not embed {stem}")

    if errors:
        print(f"FAIL - {len(errors)} display-item issue(s):")
        for error in errors:
            print(f"  {error}")
        sys.exit(1)

    print(f"PASS - {len(items)} display items match rendered files and reporting docs.")


if __name__ == "__main__":
    main()
