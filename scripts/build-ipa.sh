#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

xcodegen generate

xcodebuild \
  build-for-testing \
  -project Evernight.xcodeproj \
  -scheme Evernight \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO

ARCHIVE_PATH="build/Evernight.xcarchive"
ARTIFACTS_DIR="artifacts"
mkdir -p "$ARTIFACTS_DIR"
rm -rf "$ARCHIVE_PATH"

IPA_NAME="Evernight-v0.1-Fall-Asleep-Beta-unsigned.ipa"

xcodebuild \
  archive \
  -project Evernight.xcodeproj \
  -scheme Evernight \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM=""

APP_PATH="$ARCHIVE_PATH/Products/Applications/Evernight.app"
PAYLOAD_DIR="build/Payload"
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"

(
  cd build
  zip -qry "../$ARTIFACTS_DIR/$IPA_NAME" Payload
)

echo "Built $ARTIFACTS_DIR/$IPA_NAME"
