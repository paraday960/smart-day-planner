#!/usr/bin/env python3
from pathlib import Path

lcov = Path('coverage/lcov.info')
if not lcov.exists():
    print('coverage/lcov.info پیدا نشد.')
    raise SystemExit(0)

found = 0
hit = 0
for line in lcov.read_text(encoding='utf-8', errors='ignore').splitlines():
    if line.startswith('LF:'):
        found += int(line.split(':', 1)[1])
    elif line.startswith('LH:'):
        hit += int(line.split(':', 1)[1])

percent = 0.0 if found == 0 else hit / found * 100
summary = Path('coverage/coverage-summary.md')
summary.write_text(
    f'# Flutter Test Coverage\n\nدرصد پوشش تست: **{percent:.2f}%**\n\nخطوط پوشش داده‌شده: `{hit}` از `{found}`\n',
    encoding='utf-8',
)
print(summary.read_text(encoding='utf-8'))
