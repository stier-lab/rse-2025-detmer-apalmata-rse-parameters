#!/usr/bin/env bash
# Assemble Coral Reefs-ready figure delivery assets from the canonical outputs.
# The PDF files are primary (vector line art). TIFF files are 600-dpi fallbacks
# for editorial systems that request raster combination figures.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_dir="$root_dir/06_analysis/figures/manuscript"
destination_dir="$root_dir/paper/submission/figures"

mkdir -p "$destination_dir"

for number in 1 2 3 4; do
  case "$number" in
    1) stem="Fig1_study_landscape" ;;
    2) stem="Fig2_demographic_rates" ;;
    3) stem="Fig3_caribbean_synthesis" ;;
    4) stem="Fig4_population_model" ;;
  esac

  pdf="$source_dir/$stem.pdf"
  if [[ ! -f "$pdf" ]]; then
    echo "Missing canonical figure: $pdf" >&2
    exit 1
  fi

  cp "$pdf" "$destination_dir/Fig${number}.pdf"
  pdftocairo -tiff -singlefile -r 600 -tiffcompression lzw \
    "$pdf" "$destination_dir/Fig${number}"
done

echo "[OK] packaged Coral Reefs figure assets in $destination_dir"
