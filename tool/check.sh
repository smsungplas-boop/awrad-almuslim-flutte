#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
python3 tool/validate_content.py
flutter pub get
flutter analyze --no-fatal-infos
flutter test
sh tool/bootstrap_android.sh
flutter build apk --release
