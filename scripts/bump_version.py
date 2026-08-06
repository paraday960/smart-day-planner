#!/usr/bin/env python3
from pathlib import Path
import re
import sys

pubspec = Path('pubspec.yaml')
if not pubspec.exists():
    raise SystemExit('pubspec.yaml پیدا نشد. اسکریپت را از ریشه پروژه اجرا کن.')

mode = sys.argv[1] if len(sys.argv) > 1 else 'patch'
text = pubspec.read_text(encoding='utf-8')
match = re.search(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$', text, re.M)
if not match:
    raise SystemExit('فرمت version در pubspec.yaml شناخته نشد.')

major, minor, patch, build = map(int, match.groups())
if mode == 'major':
    major += 1; minor = 0; patch = 0
elif mode == 'minor':
    minor += 1; patch = 0
else:
    patch += 1
build += 1
new_version = f'{major}.{minor}.{patch}+{build}'
text = re.sub(r'^version:\s*.*$', f'version: {new_version}', text, flags=re.M)
pubspec.write_text(text, encoding='utf-8')
print(new_version)
