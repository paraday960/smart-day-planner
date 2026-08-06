#!/usr/bin/env bash
set -euo pipefail

echo "[1/6] Flutter version"
flutter --version

echo "[2/6] Flutter doctor"
flutter doctor

echo "[3/6] Get dependencies"
flutter pub get

echo "[4/6] Format check"
dart format --set-exit-if-changed lib test

echo "[5/6] Static analysis"
flutter analyze

echo "[6/6] Tests"
flutter test

echo "Phase 11 checks passed."
