#!/usr/bin/env python3
import re
import sys
from pathlib import Path

if len(sys.argv) < 3:
    raise SystemExit('usage: check_citations.py MANUSCRIPT BIBLIOGRAPHY [BIBLIOGRAPHY ...]')

manuscript = Path(sys.argv[1]).read_text()
bibliography = '\n'.join(Path(path).read_text() for path in sys.argv[2:])
used = set(re.findall(r'@([A-Za-z0-9_:-]+)', manuscript))
defined = set(re.findall(r'^@[A-Za-z]+\{([^,]+),', bibliography, flags=re.M))
missing = sorted(used - defined)
if missing:
    raise SystemExit('FAIL — unresolved citation keys: ' + ', '.join(missing))
print(f'PASS — {len(used)} Pandoc citation keys resolve in {len(sys.argv) - 2} bibliography file(s).')
