# CB101 — next Codex picks

Base: `origin/rc/20261108` `2f6d5041a57d876d3b0a953f56ecf5208089622f`.
Branch: `cursor/cb101`.
Probe: 2026-11-09 04:00 America/Los_Angeles, `git ls-remote origin refs/heads/<name>` against `liboyang42-cpu/chengyin-app`.

## Result

The next ten names in the CB19 needs-change table are absent from this repo. No ref existed, so no compile fix was taken and no code was invented.

The walk starts after the first ten needs-change rows (CB87). It then skips the ten names listed below, and it does not touch `codex/ui-owner-20261103-*`. `codex/l11-package-safety` is the only skip-list name inside this stretch, so the tenth checked name is the following row, `codex/l4-invoice-followup-20261105`.

## Checked (10)

| branch | exists |
|---|---|
| `codex/l10-city-receipt-recovery` | no |
| `codex/l12-business-time-20261104` | no |
| `codex/l12-official-device-dates-20261104` | no |
| `codex/l2-environment-inputs-eec-20261104` | no |
| `codex/l3-arb-import-safety-20261104` | no |
| `codex/l3-localization-fragment-validation` | no |
| `codex/l4-free-explore-integration-20261105` | no |
| `codex/l4-free-explore-recovery-20261104` | no |
| `codex/l4-invoice-c6-recovery-20261105` | no |
| `codex/l4-invoice-followup-20261105` | no |

Existed: none.

## Left with CB87 (not this batch)

First ten needs-change rows. A same-day `git ls-remote` still returned no `refs/heads` for them. They were not checked out.

| branch | exists |
|---|---|
| `codex/b03-workshop-localization-20261105` | no |
| `codex/claude-review-61cfe710-20261104` | no |
| `codex/commerce-order-summary-20261108` | no |
| `codex/ios-ci-repairs-20261105` | no |
| `codex/ios-ci-strings-20261105` | no |
| `codex/ios-core-failure-diagnostics-20261105` | no |
| `codex/ios-gitleaks-exact-20261105` | no |
| `codex/ios-route-map-a11y-20261105` | no |
| `codex/l1-channel-test-symbols-20261104` | no |
| `codex/l1-string-reconcile-20261105` | no |

## Skipped by name

Not checked out, not merged:

- `codex/owned-order-auth-correlation-20261108`
- `codex/owned-order-read-recovery-20261108`
- `codex/l4-order-readback-owner-20261104`
- `codex/l4-ticket-owner-readback-20261104`
- `codex/points-entry-recovery-20261108`
- `codex/withdrawal-support-recovery-20261108`
- `codex/withdrawal-history-recovery-20261108`
- `codex/story-audio-review-boundary-20261108`
- `codex/l11-package-safety`
- `codex/qa-text-input-20261108`
- every `codex/ui-owner-20261103-*` ref

## Not done

- No source edit. No Swift edit. No invented patch.
- No test deleted, skipped, or loosened.
- `tools/current_ci_manifest.json` was not refreshed.
- Nothing was pushed to `main`, `master`, `rc/20261108`, or any `codex/*` branch.
- No deploy.
- Version stays `0.1.0` (`1`) in `Config/Base.xcconfig`.
