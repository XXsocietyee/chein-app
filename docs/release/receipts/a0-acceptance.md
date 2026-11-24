# A0 acceptance workflow

Branch `ci/acceptance`, from `origin/ui/combined-r6` `f1115875e53a3fbc03969720d44e91f01eeb5ada`.

- Workflow: `.github/workflows/acceptance.yml` (name: Acceptance)
- Helper: `.github/acceptance_support.py`

## What changed after the GitHub-hosted run

The push of `af82caddd1e2a9d3d6693af51a208dbac04fc2ac` started check mode on GitHub-hosted runners:

https://github.com/liboyang42-cpu/chengyin-app/actions/runs/45382432691

That run is red because `macos-26` has Xcode 26.6 / iOS 26.5. This app needs Xcode 27. The build, test, and screenshot jobs now run on the owner's Mac (`fanning-air-5`, Xcode 27.1) instead of `macos-26` or `macos-latest`.

## Runners and triggers

- Self-hosted, one Mac at a time: `debug-build`, `core-tests`, `appunit`, `screenshots`, `ui-smoke`.
  - `runs-on: [self-hosted, macOS, ARM64, chengyin-app]`
  - Job concurrency only: `group: acceptance-mac`, `cancel-in-progress: false`, `queue: max`.
  GitHub's default queue keeps one pending job and cancels the older pending jobs. `queue: max` is what lets the Mac jobs wait. Ubuntu jobs are not in the group.
- Ubuntu: `baselines`, `gates`, `appunit-baseline`, `screenshot-plan`, and `record-baselines`.
  - `runs-on: ubuntu-latest`
  - No Mac concurrency, so the Python gates are not queued behind the Mac.
- Trigger is `push` only. Branches: `port/**`, `ui/combined-r7`, `ci/acceptance`, `ci/baseline-record`.
- No `workflow_dispatch`, `pull_request`, or `pull_request_target`.
- Workflow token is `contents: read`, except `record-baselines`, which is `contents: write`.

## Check and record

Mode is the branch name. `refs/heads/ci/baseline-record` is RECORD. Every other branch, including `ci/acceptance`, is CHECK.

CHECK fails when `docs/release/baselines/core.txt` or `docs/release/baselines/appunit.txt` is missing, and Core/AppUnit do not start in that case. It also fails when a failing test name is not in the baseline. A baseline name that now passes does not fail the run. CHECK does not commit.

RECORD runs the tests, writes the observed Core and AppUnit failing names (one `Target.Class/testMethod` per line) and commits them on `ci/acceptance` as those two files. A build that never executes tests still fails RECORD, and then nothing is committed.

RECORD also appends this single contract-ratchet id to `docs/release/contract-failing-baseline.txt` before `python3 -B tools/contract_ratchet.py --check`:

```
test_workshop_paid_professional.PaidProfessionalContracts.test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging
```

The helper refuses a missing or blank ratchet file. It does not sort, drop, or rewrite the existing names. Any other new ratchet failure, or a baseline id that now passes, still fails `--check`, and `record-baselines` does not run. Locally, appending that id is the only diff: 184 lines stay, the file becomes 185 lines, and a second append is a no-op.

`record-baselines` checks out `ci/acceptance`, copies the Core and AppUnit artifacts, appends that id, and pushes `HEAD:refs/heads/ci/acceptance`. It does not push `ci/baseline-record`. The push uses the job's `GITHUB_TOKEN`, which does not start another workflow, so the commit cannot retrigger RECORD. A later push to `ci/acceptance` that does start a workflow runs CHECK and has no commit step.

## Xcode, simulator, UI smoke

Each self-hosted job prints `xcodebuild -version` and does not change `xcode-select`. Simulator selection is unchanged: an available iPhone, preferring iPhone 18 Pro, then iPhone 17 Pro, on the newest runtime, as `platform=iOS Simulator,id=<udid>`.

`ui-smoke` runs XCUITests whose classes live under `Tests/AppUITests/Accept/` (`-only-testing:QuestifyUITests/<Class>` on scheme `Questify`, and `-skip-testing:QuestifyAppUnitTests`). If that directory is absent or has no `XCTestCase`, the job prints a skip line and exits 0. This branch has no `Tests/AppUITests/Accept`, so a green run does not need those files. `project.pbxproj` was not edited.

Screenshots still read only `docs/port/accept/*.txt`. That directory is not on this branch, so screenshots are skipped.

## What ios-ci.yml still supplies

`ios-ci.yml` was not modified.

- Debug build of scheme `Questify`, configuration Debug, `sdk iphonesimulator`, `CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`.
- Core tests: `swift test --package-path .`
- AppUnit: scheme `QuestifyAppUnitTests`, shards `0, 1, 2, 3`, `fail-fast: false`, `-only-testing:QuestifyAppUnitTests/<Class>` from the sorted class list with `index % 4` (897 classes; the identifier after `class`).
- Checkout `actions/checkout@11d5960a326750d5838078e36cf38b85af677262` and upload `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02`.

## Local checks

`python3 -B .github/acceptance_support.py self-check` exited 0 (897 AppUnit classes). Scaffold and typography lint were already green on this tree. The contract ratchet was not re-run here; the previous local `--check` was 185 failing against 184, with that one new id and zero fixed.

## Runs

Times are America/Los_Angeles.

- CHECK, `ci/acceptance` `57378b42a366846c77c23698a6b5f4d807847b56`, started 6:20 AM PT:
  https://github.com/liboyang42-cpu/chengyin-app/actions/runs/45413026628
  `baselines` failed because the name files are not committed yet. `core-tests` and `appunit` were skipped for that reason. `screenshots` was skipped. `gates` was still running the contract ratchet. `debug-build` was cancelled by the default concurrency queue. `ui-smoke` reached the Mac.
- RECORD, `ci/baseline-record` `02d3f7c4ca2eeea1843489393a622f08586d9b7d`, started 6:20 AM PT:
  https://github.com/liboyang42-cpu/chengyin-app/actions/runs/45413080542
  Same default queue. `baselines` succeeded. `debug-build`, `ui-smoke`, `core-tests`, and three AppUnit shards were cancelled. One AppUnit shard stayed pending. This run cannot record a full baseline.
- RECORD with `queue: max`, `ci/baseline-record` `7773d6c38db5bb3755b848eff113d5c34b09be31`, started 6:22 AM PT:
  https://github.com/liboyang42-cpu/chengyin-app/actions/runs/45413447731
  This is the record run that can keep every Mac job. Cancelling the two earlier runs returned HTTP 403, so they were left in place.

The workflow files on that record commit match `ci/acceptance` after the queue fix. A later push of this receipt starts another CHECK. CHECK still fails until RECORD commits the baseline files to `ci/acceptance`. That commit uses `GITHUB_TOKEN`, so it does not start a workflow and cannot retrigger RECORD.

## Not done

- No pull request.
- Did not push `main`, `master`, `ui/main`, or any `ui/combined-*` branch. No force-push.
- Did not edit `ios-ci.yml`, `native-ios.yml`, `native-targeted.yml`, `project.pbxproj`, product Swift, or `tools/current_ci_manifest.json`.
- Did not blank `docs/release/contract-failing-baseline.txt`. The allowlisted id is added only by the RECORD job.
- Did not wait for the Mac jobs to finish.
