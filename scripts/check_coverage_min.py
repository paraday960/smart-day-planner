#!/usr/bin/env python3
from pathlib import Path
import sys

min_percent = float(sys.argv[1]) if len(sys.argv) > 1 else 20.0
lcov = Path('coverage/lcov.info')
if not lcov.exists():
    raise SystemExit('coverage/lcov.info پیدا نشد. اول flutter test --coverage را اجرا کن.')

found = 0
hit = 0
for line in lcov.read_text(encoding='utf-8', errors='ignore').splitlines():
    if line.startswith('LF:'):
        found += int(line.split(':', 1)[1])
    elif line.startswith('LH:'):
        hit += int(line.split(':', 1)[1])

percent = 0.0 if found == 0 else (hit / found) * 100
print(f'Coverage: {percent:.2f}% ({hit}/{found})')
if percent < min_percent:
    raise SystemExit(f'Coverage کمتر از حداقل مجاز است: {min_percent:.2f}%')
