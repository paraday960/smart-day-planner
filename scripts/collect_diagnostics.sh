#!/usr/bin/env bash
set -euo pipefail

mkdir -p diagnostics

{
  echo "# Diagnostics"
  echo
  echo "## Date"
  date || true
  echo
  echo "## Flutter version"
  flutter --version || true
  echo
  echo "## Flutter doctor"
  flutter doctor -v || true
  echo
  echo "## Dart version"
  dart --version || true
  echo
  echo "## Pub deps"
  flutter pub deps || true
} > diagnostics/diagnostics.md

flutter analyze > diagnostics/flutter_analyze.txt 2>&1 || true
flutter test --coverage > diagnostics/flutter_test.txt 2>&1 || true

if [ -f coverage/lcov.info ]; then
  cp coverage/lcov.info diagnostics/lcov.info
  python scripts/coverage_summary.py > diagnostics/coverage_summary.txt || true
fi

echo "Diagnostics collected in diagnostics/"
