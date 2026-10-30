#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TARGET="$ROOT/android/gradle/wrapper/gradle-wrapper.jar"
if [ -s "$TARGET" ]; then exit 0; fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl --fail --location --retry 3 https://raw.githubusercontent.com/gradle/gradle/v8.10.2/gradle/wrapper/gradle-wrapper.jar --output "$TMP/gradle-wrapper.jar"
curl --fail --location --retry 3 https://services.gradle.org/distributions/gradle-8.10.2-wrapper.jar.sha256 --output "$TMP/checksum"
EXPECTED=$(tr -d '[:space:]' < "$TMP/checksum")
[ "${#EXPECTED}" -eq 64 ] || { echo 'Invalid upstream checksum' >&2; exit 1; }
(cd "$TMP" && printf '%s  gradle-wrapper.jar\n' "$EXPECTED" | sha256sum -c -)
cp "$TMP/gradle-wrapper.jar" "$TARGET"
