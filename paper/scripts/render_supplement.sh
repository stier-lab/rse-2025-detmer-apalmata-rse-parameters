#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
input="$root/paper/submission/supplement/ESM_1.md"
output="$root/paper/submission/supplement/ESM_1.pdf"

pandoc "$input" --citeproc --csl="$root/paper/springer-basic-author-date.csl" --resource-path="$root" \
  --pdf-engine=tectonic --output="$output"
python3 "$root/tools/check_manuscript_pdf.py" "$output"
echo "[OK] rendered $output"
