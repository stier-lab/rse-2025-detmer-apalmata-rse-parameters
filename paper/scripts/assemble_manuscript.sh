#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
source="$root/07_reporting/manuscript/acropora_palmata_demography_manuscript_draft.md"
output="$root/paper/manuscript/combined_manuscript.md"

test -f "$source"
test -f "$root/paper/manuscript/references.bib"
grep -q '^## Abstract$' "$source"
grep -q '^## Materials and methods$' "$source"
grep -q '^## Results$' "$source"
grep -q '^## Discussion$' "$source"
grep -q '^## References {#refs}$' "$source"
# Supplementary tables and figures are assembled into the discrete ESM_1.pdf
# package. Keep the main manuscript focused on its four primary figures.
cp "$source" "$output"
echo "[OK] assembled $output from the canonical manuscript source"
