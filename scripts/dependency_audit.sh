#!/usr/bin/env bash
set -euo pipefail

mkdir -p diagnostics

echo "== Dependency audit ==" | tee diagnostics/dependency_audit.txt
flutter pub get | tee -a diagnostics/dependency_audit.txt
flutter pub outdated | tee -a diagnostics/dependency_audit.txt || true
flutter pub deps --style=compact | tee diagnostics/pub_deps_compact.txt

echo "گزارش dependency در diagnostics/dependency_audit.txt ذخیره شد."
