#!/usr/bin/env bash
# Release archive + IPA export for generic iOS (arm64).
# Requires RELEASE_CONFIRM=deploy-now. Runs preflight gates first, reads the
# team ID from existing Xcode Release project settings (never hard-coded),
# generates ExportOptions.plist (app-store-connect, automatic signing), exports
# the IPA, and prints dSYM paths. Never uploads automatically.
set -euo pipefail

if [[ "${RELEASE_CONFIRM:-}" != "deploy-now" ]]; then
  echo "error: refusing to archive; set RELEASE_CONFIRM=deploy-now to confirm release archive." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT="$ROOT/Questify.xcodeproj"
SCHEME="Questify"
CONFIGURATION="Release"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is required to archive and export." >&2
  exit 1
fi

# Run all preflight gates and Release assertions before building.
"$SCRIPT_DIR/preflight.sh"

# Read DEVELOPMENT_TEAM from the existing project Release build settings.
BUILD_SETTINGS="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "generic/platform=iOS" -showBuildSettings)"
TEAM_ID="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F' = ' '/^[[:space:]]*DEVELOPMENT_TEAM = / { print $2; exit }' | tr -d '[:space:]')"
if [[ ! "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "error: invalid or missing DEVELOPMENT_TEAM in project Release settings: '$TEAM_ID'" >&2
  exit 1
fi

MARKETING_VERSION="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F' = ' '/^[[:space:]]*MARKETING_VERSION = / { print $2; exit }' | tr -d '[:space:]')"
BUILD_NUMBER="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F' = ' '/^[[:space:]]*CURRENT_PROJECT_VERSION = / { print $2; exit }' | tr -d '[:space:]')"

RELEASE_DIR="${RELEASE_OUT_DIR:-$ROOT/.build/release}"
ARCHIVE_PATH="$RELEASE_DIR/Questify.xcarchive"
EXPORT_DIR="$RELEASE_DIR/export"
EXPORT_OPTIONS_PLIST="$RELEASE_DIR/ExportOptions.plist"

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
mkdir -p "$RELEASE_DIR" "$EXPORT_DIR"

python3 -B - "$EXPORT_OPTIONS_PLIST" "$TEAM_ID" <<'PY'
import plistlib, sys
out_path, team_id = sys.argv[1], sys.argv[2]
payload = {
    "method": "app-store-connect",
    "signingStyle": "automatic",
    "teamID": team_id,
    "destination": "export",
    "uploadSymbols": True,
    "stripSwiftSymbols": True,
    "manageAppVersionAndBuildNumber": False,
}
with open(out_path, "wb") as handle:
    plistlib.dump(payload, handle)
PY

AUTH_ARGS=()
if [[ -n "${APP_STORE_CONNECT_KEY_PATH:-}" || -n "${APP_STORE_CONNECT_KEY_ID:-}" || -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  if [[ -z "${APP_STORE_CONNECT_KEY_PATH:-}" || -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
    echo "error: partial App Store Connect API key env vars set; set APP_STORE_CONNECT_KEY_PATH, APP_STORE_CONNECT_KEY_ID, and APP_STORE_CONNECT_ISSUER_ID together or none." >&2
    exit 1
  fi
  if [[ ! -f "$APP_STORE_CONNECT_KEY_PATH" ]]; then
    echo "error: APP_STORE_CONNECT_KEY_PATH does not exist: $APP_STORE_CONNECT_KEY_PATH" >&2
    exit 1
  fi
  AUTH_ARGS+=(
    -authenticationKeyPath "$APP_STORE_CONNECT_KEY_PATH"
    -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID"
    -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"
  )
fi

echo "==> Archiving $SCHEME ($CONFIGURATION, generic/platform=iOS, arm64, version=$MARKETING_VERSION ($BUILD_NUMBER), team=$TEAM_ID)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  ARCHS=arm64 \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"} \
  clean archive

echo "==> Exporting IPA with $EXPORT_OPTIONS_PLIST"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -allowProvisioningUpdates \
  ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}

IPA_PATH="$(find "$EXPORT_DIR" -maxdepth 2 -name "*.ipa" | sort | head -n 1)"
if [[ -z "$IPA_PATH" ]]; then
  echo "error: exportArchive did not produce an .ipa under $EXPORT_DIR" >&2
  exit 1
fi

DSYMS="$(find "$ARCHIVE_PATH/dSYMs" -maxdepth 2 -name "*.dSYM" | sort)"
if [[ -z "$DSYMS" ]]; then
  echo "error: no .dSYM bundles found under $ARCHIVE_PATH/dSYMs" >&2
  exit 1
fi

echo "ARCHIVE_PATH=$ARCHIVE_PATH"
echo "EXPORT_OPTIONS_PLIST=$EXPORT_OPTIONS_PLIST"
echo "IPA_PATH=$IPA_PATH"
echo "VERSION=${MARKETING_VERSION} (${BUILD_NUMBER})"
echo "DSYM_PATHS:"
printf '%s\n' "$DSYMS"
