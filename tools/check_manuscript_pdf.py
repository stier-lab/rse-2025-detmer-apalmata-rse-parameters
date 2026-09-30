#!/usr/bin/env python3
"""Minimal, portable post-render integrity check for the manuscript PDF."""
from pathlib import Path
import shutil
import subprocess
import sys


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: check_manuscript_pdf.py PATH_TO_PDF")
    pdf = Path(sys.argv[1])
    if not pdf.is_file() or pdf.stat().st_size == 0:
        raise SystemExit(f"FAIL - missing or empty PDF: {pdf}")
    pdfinfo = shutil.which("pdfinfo")
    if not pdfinfo:
        print(f"WARN - PDF exists ({pdf.stat().st_size} bytes); pdfinfo unavailable.")
        return
    result = subprocess.run([pdfinfo, str(pdf)], check=True, capture_output=True, text=True)
    fields = dict(
        line.split(":", 1) for line in result.stdout.splitlines() if ":" in line
    )
    pages = int(fields.get("Pages", "0").strip())
    if pages < 1:
        raise SystemExit("FAIL - rendered PDF has no pages")
    print(f"PASS - rendered PDF has {pages} page(s) and is non-empty.")


if __name__ == "__main__":
    main()
