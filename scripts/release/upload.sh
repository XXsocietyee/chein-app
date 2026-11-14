#!/usr/bin/env bash
# Explicit, standalone TestFlight upload script using xcrun altool and
# App Store Connect API key environment variables (never stored in the repo).
# Guarded by RELEASE_CONFIRM=deploy-now and never runs automatically.
#
# Required env vars:
#   RELEASE_CONFIRM=deploy-now
#   APP_STORE_CONNECT_KEY_ID      10-char App Store Connect API Key ID
#   APP_STORE_CONNECT_ISSUER_ID   UUID Issuer ID from App Store Connect
#
# Key file lookup (one of):
#   APP_STORE_CONNECT_KEY_PATH    Path to AuthKey_<KEY_ID>.p8 outside the repo
#   or AuthKey_<KEY_ID>.p8 in $API_PRIVATE_KEYS_DIR, ~/.appstoreconnect/private_keys,
#   ~/private_keys, ~/.private_keys, or ./private_keys
#
# Usage:
#   RELEASE_CONFIRM=deploy-now scripts/release/upload.sh [--validate-only] [path/to/Questify.ipa]
set -euo pipefail

if [[ "${RELEASE_CONFIRM:-}" != "deploy-now" ]]; then
  echo "error: refusing to upload; set RELEASE_CONFIRM=deploy-now to confirm TestFlight upload." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULT_EXPORT_DIR="${RELEASE_OUT_DIR:-$ROOT/.build/release}/export"

MODE="--upload-app"
IPA_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" >&2
      exit 0
      ;;
    --validate-only)
      MODE="--validate-app"
      shift
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      exit 2
      ;;
    *)
      if [[ -n "$IPA_ARG" ]]; then
        echo "error: unexpected extra argument: $1" >&2
        exit 2
      fi
      IPA_ARG="$1"
      shift
      ;;
  esac
done

if [[ -z "$IPA_ARG" ]]; then
  if [[ -d "$DEFAULT_EXPORT_DIR" ]]; then
    IPA_ARG="$(find "$DEFAULT_EXPORT_DIR" -maxdepth 2 -name "*.ipa" | sort | head -n 1 || true)"
  fi
fi

if [[ -z "$IPA_ARG" || ! -f "$IPA_ARG" ]]; then
  echo "error: IPA file not found (pass path as argument or run archive.sh first): ${IPA_ARG:-<none>}" >&2
  exit 1
fi

KEY_ID="${APP_STORE_CONNECT_KEY_ID:-}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-}"
KEY_PATH="${APP_STORE_CONNECT_KEY_PATH:-}"

if [[ -z "$KEY_ID" || -z "$ISSUER_ID" ]]; then
  echo "error: APP_STORE_CONNECT_KEY_ID and APP_STORE_CONNECT_ISSUER_ID must be set in environment." >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "error: xcrun is required to upload to App Store Connect." >&2
  exit 1
fi

TEMP_KEY_DIR=""
cleanup() {
  if [[ -n "$TEMP_KEY_DIR" && -d "$TEMP_KEY_DIR" ]]; then
    rm -rf "$TEMP_KEY_DIR"
  fi
}
trap cleanup EXIT

if [[ -n "$KEY_PATH" ]]; then
  if [[ ! -f "$KEY_PATH" ]]; then
    echo "error: APP_STORE_CONNECT_KEY_PATH does not exist: $KEY_PATH" >&2
    exit 1
  fi
  ABS_KEY_PATH="$(cd "$(dirname "$KEY_PATH")" && pwd)/$(basename "$KEY_PATH")"
  TEMP_KEY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/questify-asc-key.XXXXXX")"
  ln -s "$ABS_KEY_PATH" "$TEMP_KEY_DIR/AuthKey_${KEY_ID}.p8"
  export API_PRIVATE_KEYS_DIR="$TEMP_KEY_DIR"
else
  KEY_FILENAME="AuthKey_${KEY_ID}.p8"
  FOUND_KEY=""
  for dir in \
    "${API_PRIVATE_KEYS_DIR:-}" \
    "$HOME/.appstoreconnect/private_keys" \
    "$HOME/private_keys" \
    "$HOME/.private_keys" \
    "./private_keys"; do
    if [[ -n "$dir" && -f "$dir/$KEY_FILENAME" ]]; then
      FOUND_KEY="$dir/$KEY_FILENAME"
      break
    fi
  done
  if [[ -z "$FOUND_KEY" ]]; then
    echo "error: $KEY_FILENAME not found; set APP_STORE_CONNECT_KEY_PATH or place $KEY_FILENAME in ~/.appstoreconnect/private_keys." >&2
    exit 1
  fi
fi

echo "==> Running xcrun altool $MODE for $IPA_ARG"
xcrun altool "$MODE" \
  -f "$IPA_ARG" \
  -t ios \
  --api-key "$KEY_ID" \
  --api-issuer "$ISSUER_ID" \
  --verbose
