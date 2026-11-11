#!/bin/sh
# Contract ratchet: WARNING only (never fails the Xcode Cloud build). Runs on the
# Build action for the Questify scheme once, prints new failures / stale baseline
# entries from Tests/ContractChecks. See docs/release/receipts/contract-ratchet.md.
set +e
if [ "${CI_XCODE_SCHEME}" = "Questify" ] && [ "${CI_XCODEBUILD_ACTION:-build}" = "build" ]; then
  cd "${CI_PRIMARY_REPOSITORY_PATH:-.}" || exit 0
  if ! python3 tools/contract_ratchet.py --check; then
    echo "warning: contract ratchet drift (non-blocking); see diff above"
  fi
fi
exit 0
