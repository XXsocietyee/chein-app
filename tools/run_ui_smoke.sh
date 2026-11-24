#!/usr/bin/env bash
# Acceptance ui-smoke runner for the six DEBUG fixture Maestro flows.
# Call this from the ui-smoke job. It does not build the app and it does not
# need a Mac: without the Maestro CLI, or on any OS other than macOS, it
# prints a reason and exits 0.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

flows=(
  .maestro/ui-flows/member.yaml
  .maestro/ui-flows/account-publish.yaml
  .maestro/ui-flows/merchant-coop.yaml
  .maestro/ui-flows/club.yaml
  .maestro/ui-flows/player-content.yaml
  .maestro/ui-flows/play-roam.yaml
)

if ! command -v maestro >/dev/null 2>&1; then
  echo "ui-smoke: Maestro CLI is not installed. Skipping the six DEBUG fixture flows (member, account-publish, merchant-coop, club, player-content, play-roam)."
  exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ui-smoke: Maestro iOS flows need a Mac simulator. Skipping on $(uname -s)."
  exit 0
fi

for flow in "${flows[@]}"; do
  if [[ ! -f "$flow" ]]; then
    echo "ui-smoke: missing flow ${flow}" >&2
    exit 1
  fi
  echo "ui-smoke: maestro test ${flow}"
  maestro test "$flow"
done
