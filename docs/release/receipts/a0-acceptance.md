# A0 acceptance workflow

Branch `ci/acceptance`, from `origin/ui/combined-r6` `f1115875e53a3fbc03969720d44e91f01eeb5ada`.

- Workflow: `.github/workflows/acceptance.yml` (name: Acceptance)
- Helper: `.github/acceptance_support.py`

## What ios-ci.yml supplied

Read `.github/workflows/ios-ci.yml` on this base. That file was not modified.

- Debug build of scheme `Questify`, configuration Debug, `sdk iphonesimulator`, `CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`, `-derivedDataPath DerivedData`, log via `tee`, artifact upload.
- Core tests: `swift test --package-path .`
- AppUnit: scheme `QuestifyAppUnitTests`, matrix shards `0, 1, 2, 3`, `fail-fast: false`, `-resultBundlePath appunit-${SHARD}.xcresult`, the same signing and architecture settings, and `-only-testing:QuestifyAppUnitTests/<Class>` from a sorted unique class list with `index % 4`.
- Checkout `actions/checkout@11d5960a326750d5838078e36cf38b85af677262` and upload `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02`.
- Destination string in ios-ci: `platform=iOS Simulator,name=iPhone 18 Pro`, on runner label `xcode-27`.

## What this workflow changes, and why

- Xcode jobs use `runs-on: macos-26`. Scaffold, typography, contract ratchet, the baseline pre-check, the AppUnit name merge, and the screenshot plan use `ubuntu-24.04`. Both labels are GitHub-hosted. There is no self-hosted runner and no `pull_request` trigger. Push branches are `port/**`, `ui/combined-r7`, and `ci/acceptance`, plus `workflow_dispatch` input `mode` (`check` default, `record`).
- Each macOS job selects the newest `/Applications/Xcode_*.app` with `xcode-select` and prints `xcodebuild -version`. The current macos-26 image's newest preinstalled Xcode is 26.6, whose simulators are iPhone 17 Pro (iOS 26.2, 26.4, and 26.5), not iPhone 18 Pro. The destination prefers an available `iPhone 18 Pro`, then `iPhone 17 Pro`, on the newest runtime, as `platform=iOS Simulator,id=<udid>` so the three runtimes are not an ambiguous name.
- ios-ci's splitter keeps only lines that start with `class `, `final class `, `public class `, or `internal class `, then uses `split()[1]` as the class name. On this tree almost every suite is `@MainActor final class` (skipped) or `final class` (the second token is the word `class`). That yields two names and empty shards 2 and 3, so the tests would never run. Acceptance keeps the sorted `index % 4` split, the `QuestifyAppUnitTests` scheme, and `-only-testing:QuestifyAppUnitTests/<Class>`, and takes the identifier after `class`. That is 897 classes.
- Failing names are one per line, `Target.Class/testMethod`, from `Test Case '-[Target.Class testMethod]' failed` (ANSI stripped). A baseline name that now passes does not fail the run. `check` fails when `docs/release/baselines/core.txt` or `appunit.txt` is missing, and Core/AppUnit do not start in that case. `record` runs the tests, uploads artifacts `baseline-core.txt` and `baseline-appunit.txt`, and does not fail on those test names. A build that never executes tests, scaffold failure, and typography-lint failure still fail `record`. `python3 -B tools/contract_ratchet.py --check` is a hard failure in both modes. The contract baseline was not edited.
- Screenshots read `docs/port/accept/*.txt` only. Blank lines and lines whose first non-whitespace character is `#` are ignored. If the directory is missing, there is no package file, or no route lines remain, screenshots are skipped and that job succeeds. A route that does not start with `--` is launched with the existing DEBUG hook `--design-fixture <line>` (`fixtureArgument` and `DesignFixtureRegistry` in `App/QuestifyApp.swift`). A line that already starts with `--` is split with `shlex` and passed as the app's existing launch arguments. No fixture routes were invented. `docs/port/accept` is not on this branch, so screenshots are skipped.

## Contract ratchet

Local command, baseline file left untouched:

```
python3 -B tools/contract_ratchet.py --check
```

```
NEW FAILURE (not in baseline): test_workshop_paid_professional.PaidProfessionalContracts.test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging
contract ratchet: 185 failing, baseline 184, new 1, fixed 0
```

Exit 1. Same 185 against 184 named in the handbook. Not "fixed".

Local `python3 -B tools/check_scaffold.py` and `python3 -B tools/check_typography_lint.py` both exited 0.

## Run

`gh workflow run acceptance.yml --ref ci/acceptance -f mode=record` did not start a run:

```
could not create workflow dispatch event: HTTP 403: Resource not accessible by integration
```

The workflow is visible (Actions workflow id 428944264, state active). This environment's gh credential cannot create a `workflow_dispatch`. There is no record run, so `baseline-core.txt` and `baseline-appunit.txt` were not committed and the 27 / 70 counts were not observed here.

The push of `af82caddd1e2a9d3d6693af51a208dbac04fc2ac` did start check mode (3:15 AM PT):

https://github.com/liboyang42-cpu/chengyin-app/actions/runs/45382432691

While that run was in progress: `baselines` failed because both baseline files are missing; `core-tests`, `appunit`, and `appunit-baseline` were skipped; `screenshot-plan` succeeded and `screenshots` was skipped; `debug-build` and `gates` were still running. No baseline artifacts.

## Not done

- No pull request.
- Did not push `main`, `master`, `ui/main`, or any `ui/combined-*` branch. No force-push.
- Did not edit `ios-ci.yml`, `native-ios.yml`, `native-targeted.yml`, `project.pbxproj`, `tools/current_ci_manifest.json`, or `docs/release/contract-failing-baseline.txt`.
- Did not add a self-hosted workflow.
- Did not commit baseline name lists.
- Did not launch the simulator or take screenshots.
- Did not wait out the macOS debug build. Core and AppUnit did not execute on the check run.
