#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
input="$root/paper/manuscript/combined_manuscript.md"
out="$root/paper/output/acropora_palmata_demography_manuscript"
word_input="$root/paper/manuscript/combined_manuscript_word.md"

test -f "$input"
# Word does not reliably display embedded vector-PDF figures.  Build a
# Word-specific source that uses the matching high-resolution PNGs, while the
# PDF manuscript continues to use the vector originals.
sed 's|06_analysis/figures/manuscript/\([^)]*\)\.pdf|06_analysis/figures/manuscript/\1.png|g' \
  "$input" > "$word_input"
pandoc "$word_input" --citeproc --resource-path="$root:$root/07_reporting/manuscript" \
  --output="$out.docx"
pandoc "$input" --citeproc --resource-path="$root:$root/07_reporting/manuscript" \
  --pdf-engine=tectonic --output="$out.pdf"
python3 "$root/paper/scripts/check_citations.py" "$input" \
  "$root/paper/manuscript/references.bib" \
  "$root/paper/manuscript/palmata_library.bib"
python3 "$root/tools/check_manuscript_pdf.py" "$out.pdf"
echo "[OK] rendered $out.{docx,pdf}"
