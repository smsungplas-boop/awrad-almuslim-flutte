#!/usr/bin/env bash
# GitHub Actions/Linux: accept licenses without an interactive terminal and
# install only the Android packages used by this app and Flutter 3.32.8.
set -euo pipefail

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$SDK_ROOT" ]]; then
  echo 'ANDROID_HOME or ANDROID_SDK_ROOT must point to the Android SDK.' >&2
  exit 1
fi
if [[ -n "${ANDROID_HOME:-}" && -n "${ANDROID_SDK_ROOT:-}" && "$ANDROID_HOME" != "$ANDROID_SDK_ROOT" ]]; then
  echo 'ANDROID_HOME and ANDROID_SDK_ROOT must refer to the same SDK.' >&2
  exit 1
fi
SDK_MANAGER="$(command -v sdkmanager || true)"
if [[ -z "$SDK_MANAGER" || ! -x "$SDK_MANAGER" ]]; then
  echo 'sdkmanager is missing; run setup-android with command-line tools first.' >&2
  exit 1
fi
export ANDROID_HOME="$SDK_ROOT" ANDROID_SDK_ROOT="$SDK_ROOT" LC_ALL=C

SETUP_TMP="$(mktemp -d)"
trap 'rm -rf "$SETUP_TMP"' EXIT
# A finite input file avoids both interactive prompts and `yes | sdkmanager`
# reporting SIGPIPE (141) under Actions' bash -o pipefail after early closure.
printf 'y\n%.0s' {1..256} > "$SETUP_TMP/answers"

timeout 180s "$SDK_MANAGER" --sdk_root="$SDK_ROOT" --licenses \
  < "$SETUP_TMP/answers" > "$SETUP_TMP/accept.log" 2>&1 || {
    cat "$SETUP_TMP/accept.log" >&2
    exit 1
  }
# --licenses may exit zero even if the user declined. Verify the outcome with
# stdin closed, rather than relying only on that exit code.
verify_licenses() {
  timeout 180s "$SDK_MANAGER" --sdk_root="$SDK_ROOT" --licenses \
    < /dev/null > "$SETUP_TMP/verify.log" 2>&1 || {
      cat "$SETUP_TMP/verify.log" >&2
      return 1
    }
  if ! grep -Fq 'All SDK package licenses accepted' "$SETUP_TMP/verify.log"; then
    cat "$SETUP_TMP/verify.log" >&2
    echo 'Android SDK licenses remain unaccepted; refusing to continue.' >&2
    return 1
  fi
}
verify_licenses

# No obsolete `tools`, add-ons, emulator, system images, or sdkmanager --update.
# NDK matches flutter.ndkVersion in the pinned Flutter 3.32.8 SDK.
timeout 420s "$SDK_MANAGER" --sdk_root="$SDK_ROOT" \
  'platform-tools' 'platforms;android-35' 'build-tools;35.0.0' \
  'ndk;26.3.11579264' < "$SETUP_TMP/answers"
verify_licenses

for component in platform-tools platforms/android-35 build-tools/35.0.0 ndk/26.3.11579264; do
  if [[ ! -f "$SDK_ROOT/$component/source.properties" ]]; then
    echo "Required Android SDK component is missing: $component" >&2
    exit 1
  fi
done
echo 'Android SDK ready: licenses accepted and required packages installed.'
