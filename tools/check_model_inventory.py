#!/usr/bin/env python3
"""Validate the statistical model inventory against maintained scripts and outputs."""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INVENTORY = ROOT / "07_reporting/internal/model_inventory.tsv"
DISPLAY_ITEMS = ROOT / "07_reporting/manuscript/display_items.tsv"
SCRIPT_DIR = ROOT / "06_analysis/scripts"

REQUIRED_COLUMNS = [
    "model_id",
    "status",
    "scope",
    "script",
    "instances",
    "model_family",
    "response",
    "predictors_or_structure",
    "outputs",
    "display_items",
    "question_ids",
    "disturbance_transferability_role",
    "caveat",
    "diagnostics",
]

ALLOWED_STATUS = {
    "primary",
    "support",
    "sensitivity",
    "diagnostic",
    "exploratory",
    "figure_only",
}

ALLOWED_SCOPE = {"core", "supporting", "exploratory_advanced"}

ALLOWED_QUESTIONS = {
    "Q1_size_dependence",
    "Q2_caribbean_synthesis",
    "Q3_population_viability",
    "Q4_disturbance_regime",
    "Q5_restoration_transferability",
    "Q6_diagnostics_reproducibility",
    "Q7_advanced_dynamics",
    "Q8_biological_realism",
}

MODEL_CALL_PATTERN = re.compile(
    r"(?<![A-Za-z0-9_.])"
    r"(?:rma\.mv|glmer|lmer|gamm|glm|gam|rma|coxph|lme|lm|anova|"
    r"chisq\.test|wilcox\.test|kruskal\.test)"
    r"\s*\("
)


def fail(errors: list[str]) -> None:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)


def uncomment_r(source: str) -> str:
    """Drop comments without trying to fully parse R strings."""
    cleaned: list[str] = []
    for line in source.splitlines():
        in_single = False
        in_double = False
        escaped = False
        out = []
        for char in line:
            if escaped:
                out.append(char)
                escaped = False
                continue
            if char == "\\" and (in_single or in_double):
                out.append(char)
                escaped = True
                continue
            if char == "'" and not in_double:
                in_single = not in_single
                out.append(char)
                continue
            if char == '"' and not in_single:
                in_double = not in_double
                out.append(char)
                continue
            if char == "#" and not in_single and not in_double:
                break
            out.append(char)
        cleaned.append("".join(out))
    return "\n".join(cleaned)


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        lines = [line for line in handle if line.strip() and not line.startswith("#")]
    reader = csv.DictReader(lines, delimiter="\t")
    return list(reader)


def split_cell(value: str) -> list[str]:
    value = (value or "").strip()
    if not value or value == "-":
        return []
    return [item.strip() for item in value.split(";") if item.strip()]


def is_ignored_script(path: Path) -> bool:
    parts = set(path.relative_to(SCRIPT_DIR).parts)
    return path.name.endswith("_DARK.R") or bool(parts & {"archive", "utils"})


def maintained_model_scripts() -> set[str]:
    scripts: set[str] = set()
    for path in SCRIPT_DIR.rglob("*.R"):
        if is_ignored_script(path):
            continue
        code = uncomment_r(path.read_text(encoding="utf-8", errors="ignore"))
        if MODEL_CALL_PATTERN.search(code):
            scripts.add(path.relative_to(ROOT).as_posix())
    return scripts


def path_matches(relative: str) -> list[Path]:
    path = ROOT / relative
    if any(char in relative for char in "*?[]"):
        return [match for match in ROOT.glob(relative) if match.exists()]
    return [path] if path.exists() else []


def validate_paths(
    row: dict[str, str], column: str, errors: list[str], check_size: bool = True
) -> int:
    checked = 0
    for value in split_cell(row[column]):
        if value.startswith("advanced:"):
            continue
        matches = path_matches(value)
        if not matches:
            errors.append(f"{row['model_id']}: {column} path does not exist: {value}")
            continue
        checked += len(matches)
        if check_size:
            for match in matches:
                if match.is_file() and match.stat().st_size == 0:
                    errors.append(
                        f"{row['model_id']}: {column} path is empty: "
                        f"{match.relative_to(ROOT).as_posix()}"
                    )
    return checked


def main() -> int:
    errors: list[str] = []

    if not INVENTORY.exists():
        fail([f"Missing model inventory: {INVENTORY.relative_to(ROOT)}"])
    if not DISPLAY_ITEMS.exists():
        fail([f"Missing display item index: {DISPLAY_ITEMS.relative_to(ROOT)}"])

    rows = read_tsv(INVENTORY)
    header = rows[0].keys() if rows else []
    missing_cols = [col for col in REQUIRED_COLUMNS if col not in header]
    if missing_cols:
        errors.append(f"Inventory missing columns: {', '.join(missing_cols)}")

    display_rows = read_tsv(DISPLAY_ITEMS)
    display_ids = {row["id"] for row in display_rows}

    seen_ids: set[str] = set()
    listed_scripts: set[str] = set()
    output_checks = 0

    for row_number, row in enumerate(rows, start=2):
        model_id = row.get("model_id", "").strip()
        if not model_id:
            errors.append(f"row {row_number}: missing model_id")
            continue
        if model_id in seen_ids:
            errors.append(f"{model_id}: duplicated model_id")
        seen_ids.add(model_id)
        if not re.match(r"^m\d{2}_[a-z0-9_]+$", model_id):
            errors.append(f"{model_id}: model_id must match mNN_slug")

        for column in REQUIRED_COLUMNS:
            if column not in row:
                continue
            if not row[column].strip():
                errors.append(f"{model_id}: empty {column}")

        status = row.get("status", "").strip()
        if status not in ALLOWED_STATUS:
            errors.append(f"{model_id}: invalid status {status!r}")

        scope = row.get("scope", "").strip()
        if scope not in ALLOWED_SCOPE:
            errors.append(f"{model_id}: invalid scope {scope!r}")

        scripts = split_cell(row.get("script", ""))
        if not scripts:
            errors.append(f"{model_id}: at least one script is required")
        for script in scripts:
            path = ROOT / script
            if not path.exists():
                errors.append(f"{model_id}: script does not exist: {script}")
                continue
            if not script.startswith("06_analysis/scripts/") or not script.endswith(".R"):
                errors.append(f"{model_id}: script must be a maintained R script: {script}")
            if path.name.endswith("_DARK.R"):
                errors.append(f"{model_id}: _DARK.R scripts are not part of the maintained inventory")
            listed_scripts.add(script)

        output_checks += validate_paths(row, "outputs", errors)
        output_checks += validate_paths(row, "diagnostics", errors)

        for display_item in split_cell(row.get("display_items", "")):
            if display_item.startswith("advanced:"):
                continue
            if display_item not in display_ids:
                errors.append(f"{model_id}: unknown display item id {display_item!r}")

        questions = split_cell(row.get("question_ids", ""))
        if not questions:
            errors.append(f"{model_id}: at least one question_id is required")
        for question in questions:
            if question not in ALLOWED_QUESTIONS:
                errors.append(f"{model_id}: invalid question_id {question!r}")

    detected_scripts = maintained_model_scripts()
    missing_from_inventory = sorted(detected_scripts - listed_scripts)
    if missing_from_inventory:
        errors.append(
            "Maintained model-bearing scripts missing from model_inventory.tsv: "
            + ", ".join(missing_from_inventory)
        )

    if errors:
        fail(errors)

    print(
        "OK - model inventory: "
        f"{len(rows)} rows, {len(listed_scripts)} scripts listed, "
        f"{len(detected_scripts)} model-bearing scripts covered, "
        f"{output_checks} paths checked."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
