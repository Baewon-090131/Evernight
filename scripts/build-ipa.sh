#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

xcodegen generate

BUILD_LOG="build/build.log"
mkdir -p build
: > "$BUILD_LOG"

run_xcodebuild() {
  set +e
  xcodebuild "$@" 2>&1 | tee -a "$BUILD_LOG"
  local status=${PIPESTATUS[0]}
  set -e

  if [[ $status -ne 0 ]]; then
    grep -E "(: error:|fatal error:|BUILD FAILED|The following build commands failed)" "$BUILD_LOG" \
      | head -n 12 \
      | while IFS= read -r line; do
          echo "::error::$line"
        done
    exit "$status"
  fi
}

run_xcodebuild \
  test \
  -project Evernight.xcodeproj \
  -scheme Evernight \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$(
    xcrun simctl list devices available -j \
      | python3 -c 'import json,sys; data=json.load(sys.stdin); print(next(device["udid"] for devices in data["devices"].values() for device in devices if device.get("isAvailable") and "iPhone" in device.get("name", "")))'
  )" \
  -derivedDataPath build/TestDerivedData \
  CODE_SIGNING_ALLOWED=NO

ARCHIVE_PATH="build/Evernight.xcarchive"
ARTIFACTS_DIR="artifacts"
mkdir -p "$ARTIFACTS_DIR"
rm -rf "$ARCHIVE_PATH"

IPA_NAME="Evernight-v0.1-Fall-Asleep-Beta-unsigned.ipa"

run_xcodebuild \
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
