#!/usr/bin/env bash
set -euo pipefail

# Reads the latest SMS OTP code for a TEST account from TEST Redis DB 9.
# Usage:
#   read_test_sms_code.sh [--clear-limit] [phone]
# Env:
#   E2E_REDIS_SSH_HOST  SSH host running container be-int-redis (default: work)
#   E2E_REDIS_CONTAINER Docker container name (default: be-int-redis)
#   E2E_REDIS_DB        Redis DB index (default: 9)

CLEAR_LIMIT=0
if [[ "${1:-}" == "--clear-limit" ]]; then
  CLEAR_LIMIT=1
  shift
fi

PHONE="${1:-13900000004}"
SSH_HOST="${E2E_REDIS_SSH_HOST:-work}"
CONTAINER="${E2E_REDIS_CONTAINER:-be-int-redis}"
REDIS_DB="${E2E_REDIS_DB:-9}"

if [[ ! "${PHONE}" =~ ^[0-9]{6,20}$ ]]; then
  echo "Invalid phone number: ${PHONE}" >&2
  exit 2
fi

if [[ "${CLEAR_LIMIT}" -eq 1 ]]; then
  ssh "${SSH_HOST}" "docker exec ${CONTAINER} redis-cli -n ${REDIS_DB} DEL sms_limit_phone_${PHONE} sms_send_phone_day_${PHONE}" >/dev/null
  echo "Cleared SMS rate-limit keys for ${PHONE}" >&2
  exit 0
fi

RAW_CODE="$(ssh "${SSH_HOST}" "docker exec ${CONTAINER} redis-cli -n ${REDIS_DB} GET sms_${PHONE}_code" | tr -d '\r\n')"
# Redis stores JSON-encoded or quoted string values such as "123456"
CODE="${RAW_CODE//\"/}"

if [[ -z "${CODE}" || "${CODE}" == "(nil)" ]]; then
  echo "No SMS code in Redis DB ${REDIS_DB} for phone ${PHONE}" >&2
  exit 1
fi

printf '%s\n' "${CODE}"
