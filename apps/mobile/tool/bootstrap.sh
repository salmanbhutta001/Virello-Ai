#!/usr/bin/env bash
# Generates android/ and ios/ native shells for the hand-written lib/.
# Requires the Flutter SDK on PATH. Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
flutter create --org com.virello --project-name virello --platforms android,ios "$TMP/virello" >/dev/null
cp -r "$TMP/virello/android" ./android
cp -r "$TMP/virello/ios" ./ios
rm -rf "$TMP"
echo "Native shells generated. Run: flutter pub get && flutter run"
