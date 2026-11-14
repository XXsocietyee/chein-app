#!/usr/bin/env bash
set -euo pipefail

# Sequential E2E Maestro runner for Questify iOS (DEBUG app against TEST host).
# Runs all 18 journey flows sequentially on ONE simulator while keeping Mac load <= 25.
#
# Usage:
#   ./e2e/maestro/run_all.sh
# Optional env vars:
#   E2E_SIM_NAME          Simulator device name (default: Questify-iPhone17-Lane2)
#   E2E_SIM_UDID          Explicit simulator UDID (auto-resolved from E2E_SIM_NAME if unset)
#   E2E_MAX_LOAD          Wait while 1-min loadavg > N (default: 25)
#   E2E_TEST_HOST         Target TEST backend URL
#   E2E_LOCK_FILE         Host lock file (default: /private/tmp/design-build.lock)
#   E2E_USE_LOCKF         Set 0 to skip lockf wrapper (default: 1)
#   E2E_SMS_BRIDGE_PORT   Local SMS bridge port (default: 18120)
#   E2E_PHONE             Player phone (default: 13900000004)
#   E2E_MERCHANT_PHONE    Merchant phone (default: 13900000002)
#   MAESTRO_BIN           Maestro CLI binary (default: maestro or ~/.local/bin/maestro)
#   E2E_RESULTS_DIR       Output directory (default: e2e/maestro/results/<timestamp>)
#   E2E_SKIP_LOAD_CHECK   Set 1 only for diagnostics (default: 0)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SIM_NAME="${E2E_SIM_NAME:-Questify-iPhone17-Lane2}"
SIM_UDID="${E2E_SIM_UDID:-}"
MAX_LOAD="${E2E_MAX_LOAD:-25}"
LOCK_FILE="${E2E_LOCK_FILE:-/private/tmp/design-build.lock}"
USE_LOCKF="${E2E_USE_LOCKF:-1}"
BRIDGE_PORT="${E2E_SMS_BRIDGE_PORT:-18120}"
PLAYER_PHONE="${E2E_PHONE:-13900000004}"
MERCHANT_PHONE="${E2E_MERCHANT_PHONE:-13900000002}"
TEST_HOST="${E2E_TEST_HOST:-https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech}"

if [[ "${USE_LOCKF}" == "1" && -z "${_E2E_LOCKED:-}" ]]; then
  if command -v lockf >/dev/null 2>&1; then
    export _E2E_LOCKED=1
    exec lockf "${LOCK_FILE}" "$0" "$@"
  fi
fi

MAESTRO_BIN="${MAESTRO_BIN:-}"
if [[ -z "${MAESTRO_BIN}" ]]; then
  if command -v maestro >/dev/null 2>&1; then
    MAESTRO_BIN="$(command -v maestro)"
  elif [[ -x "${HOME}/.local/bin/maestro" ]]; then
    MAESTRO_BIN="${HOME}/.local/bin/maestro"
  else
    echo "ERROR: maestro CLI not found on PATH or ~/.local/bin/maestro" >&2
    exit 127
  fi
fi

resolve_sim_udid() {
  if [[ -n "${SIM_UDID}" ]]; then
    echo "${SIM_UDID}"
    return 0
  fi
  python3 - "${SIM_NAME}" <<'PY'
import json, subprocess, sys
target = sys.argv[1]
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"], text=True)
data = json.loads(raw)
fallback_booted = None
for runtime, devs in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for d in devs:
        if not d.get("isAvailable", True):
            continue
        if d.get("name") == target:
            print(d["udid"])
            sys.exit(0)
        if d.get("state") == "Booted" and fallback_booted is None:
            fallback_booted = d["udid"]
if fallback_booted:
    print(fallback_booted)
    sys.exit(0)
sys.exit(1)
PY
}

wait_while_overloaded() {
  if [[ "${E2E_SKIP_LOAD_CHECK:-0}" == "1" ]]; then
    return 0
  fi
  while true; do
    local load1
    load1="$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}' || echo "0")"
    if awk -v cur="${load1}" -v lim="${MAX_LOAD}" 'BEGIN { exit (cur + 0 > lim + 0) ? 0 : 1 }'; then
      echo "[run_all] 1-min system load is ${load1} (> ${MAX_LOAD}); waiting 10s..." >&2
      sleep 10
    else
      break
    fi
  done
}

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RESULTS_DIR="${E2E_RESULTS_DIR:-${SCRIPT_DIR}/results/${TIMESTAMP}}"
mkdir -p "${RESULTS_DIR}/screenshots" "${RESULTS_DIR}/logs" "${RESULTS_DIR}/maestro"

SIM_UDID="$(resolve_sim_udid)" || {
  echo "ERROR: Unable to locate simulator '${SIM_NAME}'. Set E2E_SIM_UDID explicitly." >&2
  exit 1
}

echo "[run_all] Using simulator ${SIM_NAME} (${SIM_UDID})"
xcrun simctl boot "${SIM_UDID}" >/dev/null 2>&1 || true
xcrun simctl bootstatus "${SIM_UDID}" -b

BRIDGE_PID=""
LOG_PID=""
cleanup() {
  xcrun simctl location "${SIM_UDID}" clear >/dev/null 2>&1 || true
  if [[ -n "${LOG_PID}" ]]; then
    kill "${LOG_PID}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${BRIDGE_PID}" ]]; then
    kill "${BRIDGE_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# Start SMS Redis HTTP bridge (used by scripts/get_sms_code.js in login/merchant flows).
export E2E_SMS_BRIDGE_PORT="${BRIDGE_PORT}"
python3 "${SCRIPT_DIR}/scripts/sms_code_server.py" >"${RESULTS_DIR}/logs/sms_bridge.log" 2>&1 &
BRIDGE_PID=$!

# Start compact [E2E] simulator log capture.
xcrun simctl spawn "${SIM_UDID}" log stream --style compact --predicate 'eventMessage CONTAINS "[E2E]"' \
  >"${RESULTS_DIR}/logs/e2e_app.log" 2>&1 &
LOG_PID=$!

REPORT_MD="${RESULTS_DIR}/RESULTS.md"
cp "${SCRIPT_DIR}/RESULTS_TEMPLATE.md" "${REPORT_MD}"

FLOWS=(
  "permissions"
  "account-export-deletion"
  "login"
  "discover-activity-signup"
  "play-session"
  "roam"
  "city-game"
  "club"
  "im-dm-preview"
  "community-post"
  "creator-publish-review-appeal"
  "external-game"
  "rewards-store"
  "workshop-purchased-install"
  "wallet"
  "search-filters"
  "offline-banner"
  "merchant-ops-payout"
)

PASS_COUNT=0
FAIL_COUNT=0
SUMMARY_ROWS="${RESULTS_DIR}/summary_rows.txt"
: > "${SUMMARY_ROWS}"

for journey in "${FLOWS[@]}"; do
  flow_file="${SCRIPT_DIR}/${journey}.yaml"
  if [[ ! -f "${flow_file}" ]]; then
    echo "ERROR: Missing flow file ${flow_file}" >&2
    exit 2
  fi

  wait_while_overloaded

  # Clear TEST SMS rate-limit before login / merchant auth flows if Redis bridge is reachable.
  if [[ "${journey}" == "login" ]]; then
    "${SCRIPT_DIR}/scripts/read_test_sms_code.sh" --clear-limit "${PLAYER_PHONE}" || true
  elif [[ "${journey}" == "merchant-ops-payout" ]]; then
    "${SCRIPT_DIR}/scripts/read_test_sms_code.sh" --clear-limit "${MERCHANT_PHONE}" || true
  fi

  # For Roam flow, stream simulated GPX walk in parallel with Maestro test.
  if [[ "${journey}" == "roam" ]]; then
    xcrun simctl location "${SIM_UDID}" start --speed=5 --interval=2 \
      "${SCRIPT_DIR}/fixtures/roam_shanghai_walk.gpx" >/dev/null 2>&1 || true
  fi

  echo "[run_all] === Running ${journey}.yaml ==="
  start_ts="$(date +%s)"
  set +e
  "${MAESTRO_BIN}" \
    --udid "${SIM_UDID}" \
    test "${flow_file}" \
    --debug-output "${RESULTS_DIR}/maestro/${journey}" \
    --format junit \
    --output "${RESULTS_DIR}/maestro/${journey}-junit.xml" \
    -e "E2E_PHONE=${PLAYER_PHONE}" \
    -e "E2E_MERCHANT_PHONE=${MERCHANT_PHONE}" \
    -e "E2E_SMS_BRIDGE_PORT=${BRIDGE_PORT}" \
    >"${RESULTS_DIR}/logs/${journey}.log" 2>&1
  rc=$?
  set -e
  end_ts="$(date +%s)"
  dur="$((end_ts - start_ts))"

  if [[ "${journey}" == "roam" ]]; then
    xcrun simctl location "${SIM_UDID}" clear >/dev/null 2>&1 || true
  fi

  if [[ ${rc} -eq 0 ]]; then
    status="PASS"
    PASS_COUNT="$((PASS_COUNT + 1))"
  else
    status="FAIL (exit ${rc})"
    FAIL_COUNT="$((FAIL_COUNT + 1))"
    xcrun simctl io "${SIM_UDID}" screenshot "${RESULTS_DIR}/screenshots/${journey}-failure.png" >/dev/null 2>&1 || true
  fi

  printf '%s\t%s\t%ss\n' "${journey}" "${status}" "${dur}" >> "${SUMMARY_ROWS}"
  echo "[run_all] === ${journey}: ${status} (${dur}s) ==="
done

{
  echo ""
  echo "## Automated Run Summary (${TIMESTAMP})"
  echo "- Simulator: \`${SIM_NAME}\` (\`${SIM_UDID}\`)"
  echo "- Host: \`${TEST_HOST}\`"
  echo "- Total Passed: ${PASS_COUNT} / ${#FLOWS[@]}, Failed: ${FAIL_COUNT}"
  echo ""
  echo "| Journey | Status | Duration |"
  echo "|---|---|---|"
  while IFS=$'\t' read -r j s d; do
    echo "| \`${j}\` | ${s} | ${d} |"
  done < "${SUMMARY_ROWS}"
} >> "${REPORT_MD}"

echo "[run_all] Finished: ${PASS_COUNT} passed, ${FAIL_COUNT} failed. Results: ${REPORT_MD}"
[[ ${FAIL_COUNT} -eq 0 ]]
