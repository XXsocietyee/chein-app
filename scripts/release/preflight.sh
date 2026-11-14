#!/usr/bin/env bash
# Release preflight gate runner. Exits non-zero if any existing gate or release
# production/switch/fixture assertion fails. Does not run xcodebuild or upload.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$ROOT"

FAILURES=()

run_gate() {
  local label="$1"
  shift
  echo "==> [$label]"
  if "$@"; then
    echo "PASS [$label]"
  else
    echo "FAIL [$label]" >&2
    FAILURES+=("$label")
  fi
}

run_gate "check_scaffold" python3 -B "$ROOT/tools/check_scaffold.py"
run_gate "design_lint" python3 -B "$ROOT/tools/check_design_lint.py"
run_gate "appsession_ratchet" python3 -B "$ROOT/tools/check_appsession_ratchet.py"
run_gate "check_release_config" python3 -B "$ROOT/tools/check_release_config.py"
run_gate "fixture_exclusion" python3 -B "$ROOT/tools/check_design_fixture_release_exclusion.py"
run_gate "client_ops_audit" python3 -B "$ROOT/tools/audit_client_ops_surfaces.py" --check
run_gate "lint_no_release_print" python3 -B "$ROOT/tools/lint_no_release_print.py"
run_gate "l2_environment_configs" python3 -B "$ROOT/tools/check_l2_environment_configs.py"
run_gate "release_preflight_assertions" python3 -B "$ROOT/tools/check_release_preflight.py"
run_gate "contract_ratchet" python3 -B "$ROOT/tools/contract_ratchet.py" --check

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo "error: release preflight failed (${#FAILURES[@]} gate(s)): ${FAILURES[*]}" >&2
  exit 1
fi

echo "PASS: all release preflight gates succeeded."
