#!/bin/sh
# Builds the shareable release APKs (one per ABI, obfuscated) and uploads
# their debug symbols to Sentry so crash reports show real file and line
# names. Share build/app/outputs/flutter-apk/app-arm64-v8a-release.apk.
#
#   SENTRY_AUTH_TOKEN=... tool/release_apk.sh
set -e
cd "$(dirname "$0")/.."

if [ -z "$SENTRY_AUTH_TOKEN" ]; then
  echo "Set SENTRY_AUTH_TOKEN (Sentry > Settings > Auth Tokens)." >&2
  exit 1
fi

rm -rf build/symbols
rm -f build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release --split-per-abi --obfuscate \
  --split-debug-info=build/symbols \
  --extra-gen-snapshot-options=--save-obfuscation-map=build/symbols/obfuscation.map.json

# Match the release name the app reports: <application id>@<version>.
version=$(sed -n 's/^version: //p' pubspec.yaml)
SENTRY_RELEASE="com.prepwisely.team@$version" dart run sentry_dart_plugin
