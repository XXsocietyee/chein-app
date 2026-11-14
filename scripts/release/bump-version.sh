#!/usr/bin/env bash
# Set CFBundleShortVersionString (MARKETING_VERSION) and CFBundleVersion (CURRENT_PROJECT_VERSION)
# in Config/Base.xcconfig, which GENERATE_INFOPLIST_FILE=YES compiles into the app's Info.plist.
# Never modifies Config/Info.plist or project.pbxproj directly (those must stay clean for
# tools/archive_unsigned.py and tools/check_scaffold.py).
#
# Usage:
#   scripts/release/bump-version.sh                     # print current pair without modifying
#   scripts/release/bump-version.sh --print             # print current pair without modifying
#   scripts/release/bump-version.sh <short> <build>     # e.g. 0.1.0 2
#   scripts/release/bump-version.sh --short-version <X.Y.Z> --build <N>
#   scripts/release/bump-version.sh --build <N>         # keep current CFBundleShortVersionString
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUMP_PY="$ROOT/tools/bump_version.py"
BASE_XCCONFIG="$ROOT/Config/Base.xcconfig"
INFO_PLIST="$ROOT/Config/Info.plist"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/release/bump-version.sh [--print]
  scripts/release/bump-version.sh <CFBundleShortVersionString> <CFBundleVersion>
  scripts/release/bump-version.sh [--short-version <X.Y.Z>] --build <N>

Examples:
  scripts/release/bump-version.sh 0.1.0 2
  scripts/release/bump-version.sh --short-version 0.2.0 --build 3
  scripts/release/bump-version.sh --build 4
EOF
}

if [[ ! -f "$BUMP_PY" || ! -f "$BASE_XCCONFIG" ]]; then
  echo "error: expected tools/bump_version.py and Config/Base.xcconfig under $ROOT" >&2
  exit 1
fi

read_current() {
  python3 -B "$BUMP_PY"
}

if [[ $# -eq 0 ]]; then
  read_current
  exit 0
fi

SHORT_VERSION=""
BUILD_NUMBER=""
PRINT_ONLY=0
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --print|--dry-run)
      PRINT_ONLY=1
      shift
      ;;
    --short-version|--marketing|--version)
      [[ $# -ge 2 ]] || { echo "error: $1 requires a value" >&2; usage; exit 2; }
      SHORT_VERSION="$2"
      shift 2
      ;;
    --build)
      [[ $# -ge 2 ]] || { echo "error: $1 requires a value" >&2; usage; exit 2; }
      BUILD_NUMBER="$2"
      shift 2
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage
      exit 2
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [[ "$PRINT_ONLY" -eq 1 ]]; then
  if [[ -n "$SHORT_VERSION" || -n "$BUILD_NUMBER" || ${#POSITIONAL[@]} -gt 0 ]]; then
    echo "error: --print takes no version arguments" >&2
    exit 2
  fi
  read_current
  exit 0
fi

if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  if [[ -n "$SHORT_VERSION" || -n "$BUILD_NUMBER" || ${#POSITIONAL[@]} -ne 2 ]]; then
    echo "error: provide either <short-version> <build> or --short-version/--build flags" >&2
    usage
    exit 2
  fi
  SHORT_VERSION="${POSITIONAL[0]}"
  BUILD_NUMBER="${POSITIONAL[1]}"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  echo "error: CFBundleVersion (--build) is required when updating versions" >&2
  usage
  exit 2
fi

if [[ -z "$SHORT_VERSION" ]]; then
  SHORT_VERSION="$(python3 -B "$BUMP_PY" | awk -F= '/^MARKETING_VERSION=/ { print $2; exit }')"
  if [[ -z "$SHORT_VERSION" ]]; then
    echo "error: failed to read current MARKETING_VERSION from Config/Base.xcconfig" >&2
    exit 1
  fi
fi

# Guard against accidental direct Info.plist version keys that violate archive_unsigned.py rules.
if [[ -f "$INFO_PLIST" ]] && grep -Eq 'CFBundleShortVersionString|CFBundleVersion' "$INFO_PLIST"; then
  echo "error: Config/Info.plist must not define CFBundleShortVersionString or CFBundleVersion directly (GENERATE_INFOPLIST_FILE=YES reads Config/Base.xcconfig)." >&2
  exit 1
fi

python3 -B "$BUMP_PY" --apply --marketing "$SHORT_VERSION" --build "$BUILD_NUMBER"
echo "CFBundleShortVersionString=$SHORT_VERSION"
echo "CFBundleVersion=$BUILD_NUMBER"
