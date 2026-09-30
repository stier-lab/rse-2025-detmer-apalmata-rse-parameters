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
# During drafting we retain tables as independently auditable source files, then
# inject them immediately before the figure-legend list for a complete,
# reviewable manuscript. Each source table controls its own page breaks.
{
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "## Figure legends" ]]; then
      for table in \
        "$root/07_reporting/manuscript/tables/TableS1_disturbance_chronology_submission.md" \
        "$root/07_reporting/manuscript/tables/TableS2_study_window_disturbance_audit.md" \
        "$root/07_reporting/manuscript/tables/size_class_synthesis_table.md"; do
        sed '1s/^# /### /' "$table"
        printf '\n\n'
      done
    fi
    printf '%s\n' "$line"
  done < "$source"
} > "$output"
echo "[OK] assembled $output from the canonical manuscript source and canonical tables"
