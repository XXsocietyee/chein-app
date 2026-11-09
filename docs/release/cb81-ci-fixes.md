# CB81 — iOS CI fixes

Base: `origin/rc/20261108` `89dcba807e7e5439182ff8852d6600d1fa9fdd49`.
Branch: `cursor/cb81`.

## Status

The first `.github/workflows/ios-ci.yml` run has not reported yet. There is no CI failure list, so no code fix was made.

Checked 2026-11-09 03:00 America/Los_Angeles, against that base:

- The workflow file is on `origin/rc/20261108` in `89dcba807e7e5439182ff8852d6600d1fa9fdd49` ("Add the approved GitHub-hosted iOS CI workflow.", 2026-11-09 02:57 America/Los_Angeles). Triggers are `workflow_dispatch` and `pull_request` to `rc/**`.
- The file is not on the default branch. `gh run list --workflow=ios-ci.yml` returns HTTP 404 (workflow not found on the default branch).
- Actions runs for `branch=rc/20261108` returned `total_count` 0.
- The latest 50 repository workflow runs do not include a run named `iOS CI` or a path `.github/workflows/ios-ci.yml`. Queued runs: 0. In-progress runs: 0.

No test name, assertion, or log line from this workflow is recorded here.

## What stayed

- Production code was not changed.
- Tests were not changed. None were deleted, weakened, or renamed. No view was edited.
- Hosted accessibility failures stay baseline when a later run shows them.
- Version stays `0.1.0` (`1`): `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1` in `Config/Base.xcconfig`.
