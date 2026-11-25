# Acceptance CHECK hardening

Branch `cursor/acceptance-hardening`, parent `1d3f9c9e5e5114a6d8ceed780deeec1f6ac049e6` on `ci/acceptance` (`ci: check combined-r7 ebf6c160c`). Not rebased onto `ui/combined-r7`.

## Files

- `.github/workflows/acceptance.yml`
- `.github/acceptance_support.py`
- `.github/actions/acceptance-checkout/action.yml`
- `docs/release/receipts/cursor-acceptance-hardening.md`

## What changed

Push triggers are unchanged: `port/**`, `ui/combined-r7`, `ci/acceptance`, `ci/baseline-record`. No `workflow_dispatch` or pull request trigger. One self-hosted Mac label. The shared simulator lock and the one screenshot boot retry stay. Phones stay `Questify-iPhone17-Lane2` (device type `iPhone-17`) and `Questify-iPhone17-W2` (device type `iPhone-17-Pro`). `iPhone-17` does not match `iPhone-17-Pro`. The destination still comes from `simctl` by lane name, then device type. No simulator UDID is hardcoded.

(a) Checkout retries git fetch and checkout 3 times. The first two failures wait 10s, then 20s, before the next `actions/checkout` of the same pin. Record mode's `git fetch origin refs/heads/ci/acceptance` and `git checkout --detach FETCH_HEAD` use the same 3-attempt backoff in `git-retry`.

(b) Before each AppUnit shard, inside the existing simulator lock, that lane's phone is shut down, booted, and waited on with `simctl bootstatus -b`. Screenshots do the same shutdown-boot-bootstatus before the existing boot path, which still retries a failed boot once. Shutting down a phone that is already shut down (`current state: Shutdown`) is success.

(c) `simctl terminate` text `found nothing to terminate` is success. It does not fail the route and does not count as a boot timeout. A launch that only reports that message is launched again without `--terminate-running-process`.

(d) After the AppUnit shard step, including when the job times out, `materialize-shard-status` writes any missing `appunit-<shard>-status.txt` and `appunit-<shard>-failures.txt`. A finished collect is left as-is. A shard killed before collect is recorded as `timed-out`. The existing `if: always()` uploads then publish those files.

## Left as recorded

- `docs/release/baselines/core.txt` (27 names) and `docs/release/baselines/appunit.txt` (71 names) are unchanged.
- `docs/release/contract-failing-baseline.txt` still ends with the known paid-professional id `test_workshop_paid_professional.PaidProfessionalContracts.test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging` (185 names).
- `tools/current_ci_manifest.json` was not edited.

## Check

`python3 -B .github/acceptance_support.py self-check` passed (902 AppUnit classes). No workflow was started. This branch was not merged.
