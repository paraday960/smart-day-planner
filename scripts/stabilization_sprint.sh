#!/usr/bin/env bash
set -euo pipefail

echo "== Smart Day Planner Stabilization Sprint =="
echo "1) Flutter doctor"
flutter doctor -v

echo "2) Dependencies"
flutter pub get
flutter pub outdated || true

echo "3) Formatting"
dart format lib test

echo "4) Static analysis"
flutter analyze

echo "5) Tests with coverage"
flutter test --coverage
python scripts/check_coverage_min.py 30
python scripts/coverage_summary.py

echo "6) Debug APK build"
flutter build apk --debug

echo "Done. APK: build/app/outputs/flutter-apk/app-debug.apk"
