# CB89 — Self-hosted and Xcode Cloud fallback for iOS CI

Base: `origin/rc/20261108` at `576e869a995c280f325799ad8ea9a2729ac30781`.
Branch: `cursor/cb89`.

This note records a fallback for `.github/workflows/ios-ci.yml` while GitHub-hosted Actions is blocked by billing. The proposed workflow edit is `docs/release/cb89-ios-ci.patch`. That patch is for the owner to approve later. This branch leaves `.github/workflows/ios-ci.yml` at blob `3af977942405d29e9cae0fdafd75737f1a3408f8`. `git apply --check docs/release/cb89-ios-ci.patch` succeeded against that blob. `git apply` without `--check` was not run.

`tools/current_ci_manifest.json` stays blob `743958754af4608942e3a86019e71fa499eba78b`. `Config/Base.xcconfig` stays blob `05acfe55f73c078a9c70f1870ea4d4a7b5beb2eb`: `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1`.

This VM has no `xcodebuild` and no `swift`. Nothing here is a build, a simulator run, or a `swift test` result. Python 3.12.3 was used to read `Tests/AppUnitTests` and the committed test plans.

## Blocked run

[Run 42605481564](https://github.com/liboyang42-cpu/chengyin-app/actions/runs/42605481564) is the first `iOS CI` run. It was a `pull_request` for `cursor/cb81` at `dca94228a905a86279d92ca28e260aa46d707a4a` (“docs: CB81 note that ios-ci.yml has no failure list yet”). Attempt 1. It started at 2026-11-09 03:00:29 America/Los_Angeles and its last update is 2026-11-09 03:00:33 America/Los_Angeles. Each job started at 03:00:30 and finished at 03:00:31 or 03:00:32. Every job has an empty step list, an empty `runner_name`, and conclusion `failure`.

All eight jobs carry the same annotation:

> The job was not started because recent account payments have failed or your spending limit needs to be increased. Please check the 'Billing & plans' section in your settings

| Job | Hosted label | Check run |
|---|---|---|
| debug-build | `xcode-27` | 129120272572 |
| core-tests | `xcode-27` | 129120272817 |
| appunit (0) | `xcode-27` | 129120272937 |
| appunit (1) | `xcode-27` | 129120273040 |
| appunit (2) | `xcode-27` | 129120272838 |
| appunit (3) | `xcode-27` | 129120272929 |
| release-gate | `ubuntu-24.04` | 129120273016 |
| design-lint | `ubuntu-24.04` | 129120272962 |

This change does not rerun 42605481564. The workflow on the base still starts on `workflow_dispatch` and on `pull_request` to `rc/**`. A pull request into `rc/20261108` can queue a new run of that same file. That queue is the existing trigger. It is a different run from 42605481564.

The annotation names two causes: failed account payments, and a spending limit. This note did not open Billing & plans, so it does not say which one is set. Self-hosted runners do not consume GitHub-hosted minutes. A lock that stops Actions before a runner is assigned still stops a self-hosted job, because these eight jobs never received a runner. Xcode Cloud bills Apple team **9VHY8N755R** and does not use this GitHub Actions meter. The owner picks the path after looking at Billing & plans.

## Jobs the fallback covers

The base file has `permissions: contents: read`, concurrency group `ios-ci-${{ github.ref }}`, and `cancel-in-progress: false`. Checkout is `actions/checkout@11d5960a326750d5838078e36cf38b85af677262` with `persist-credentials: false`. The file has no `secrets` context, no `DEVELOPMENT_TEAM`, and no certificate. Both `xcodebuild` lines pass `CODE_SIGNING_ALLOWED=NO`. That setting stays. It is a build setting, not a secret.

| Job | Timeout | What the base file runs |
|---|---|---|
| debug-build | 90 min | `xcodebuild -project Questify.xcodeproj -scheme Questify -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build` |
| core-tests | 180 min | `swift test --package-path .` (`Package.swift`, target `QuestifyCoreTests`, platforms iOS 17 and macOS 14) |
| appunit | 180 min, matrix shards 0–3, `fail-fast: false` | inline Python writes `-only-testing:QuestifyAppUnitTests/<class>`, then `xcodebuild ... -scheme QuestifyAppUnitTests -configuration Debug` with the same destination, `CODE_SIGNING_ALLOWED=NO`, `ARCHS=arm64`, and `ONLY_ACTIVE_ARCH=YES` |
| release-gate | 20 min | `python3 -B tools/check_scaffold.py` then `python3 -B tools/current_ci.py check` |
| design-lint | 10 min | `test -f tools/check_design_lint.py` then `python3 -B tools/check_design_lint.py` |

`tools/check_scaffold.py` compares the project with a generator run in a temporary directory and then runs design lint itself. Its closing line says the script does not run Swift or Xcode. `tools/current_ci.py check` compares `tools/current_ci_manifest.json` with the tree and returns. The `refresh` action is the one that writes the ledger. The workflow calls `check`.

Debug and appunit cache `DerivedData` with `actions/cache@v4`. Logs and `.xcresult` bundles upload with `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02` (`if: always()`). Those actions call GitHub. The `xcodebuild` and Python lines do not need them in order to be the right commands. The patch keeps the cache and the upload.

## Self-hosted runners

The patch changes only runner labels and the AppUnit class list. Commands, timeouts, the matrix, signing, permissions, and triggers stay.

| Jobs | Proposed `runs-on` |
|---|---|
| debug-build, core-tests, appunit | `[self-hosted, macOS, ARM64, questify-xcode-27]` |
| release-gate, design-lint | `[self-hosted, questify-python]` |

GitHub’s default self-hosted labels are `self-hosted`, an OS label (`macOS`, `linux`, or `windows`), and an architecture label (`ARM64`, `x64`, or `ARM`). A job runs only on a runner that has every label in the list. `questify-xcode-27` is a custom label. It is a different label from the hosted label `xcode-27`. A restored hosted pool still matches `runs-on: xcode-27` on the unpatched file. Leave the hosted names off the self-hosted machine.

The owner registers the runner from the repository settings (Actions → Runners). The registration token is shown there once. It stays on the Mac, in the owner’s environment, and out of git. Example, with the token already in the environment and `--no-default-labels` omitted so `self-hosted`, `macOS`, and `ARM64` remain:

```sh
./config.sh --url https://github.com/liboyang42-cpu/chengyin-app --token "$REGISTRATION_TOKEN" --name questify-xcode-27 --labels questify-xcode-27,questify-python
```

`questify-python` on that same Mac lets the two Python jobs run there. A separate Linux runner needs only `questify-python` plus the defaults `self-hosted` and its OS label. The Python jobs ask for `python3` and `git`. They do not ask for Xcode.

The Mac that carries `questify-xcode-27` needs:

- Xcode 27 selected. `docs/release/xcode-cloud-setup.md` cites hosted image `20261104.0337.1` as Xcode 27.1 with the iOS 27.0 simulator and an iPhone 18 Pro. This note did not download that readme again.
- `xcrun simctl list devices available` showing `iPhone 18 Pro`. The destination string in the workflow is exact.
- `swift` on `PATH` for `swift test --package-path .`.
- `python3` on `PATH` for the shard script.
- An empty work folder. Prefer an ephemeral runner so a previous checkout and `DerivedData` do not remain. The hosted machine was new each job. The patch does not add `clean: true` to checkout.

One runner with the Mac labels runs the four shards one after another. Four runners with those labels can take the four shards at once. `fail-fast` is already false. A job that stays queued for more than 24 hours fails, per GitHub’s self-hosted runner reference. The timeout in the workflow starts when the job starts.

`liboyang42-cpu/chengyin-app` was private when read on 2026-11-09. The workflow event is `pull_request`, so the file that runs is the one on the pull request. A collaborator who can open a pull request can change those steps in the same request. The runner holds no distribution certificate, no provisioning profile, no App Store Connect API key, and no `Config/Local.xcconfig`. `CODE_SIGNING_ALLOWED=NO` on the command line is the signing rule for these jobs. A later signed archive uses a different machine and a different owner decision.

## AppUnit class list in the patch

The shard rule already in the workflow is sorted unique names, then `index % 4 == shard`. An empty shard exits with `shard <n> is empty`.

The discovery above that rule takes `split()[1]` from a line that starts with `class `, `final class `, `public class `, or `internal class ` and contains `XCTestCase`. On `final class Name: XCTestCase` the second token is the keyword `class`. A line that starts with `@MainActor` never matches those prefixes.

Read of `Tests/AppUnitTests` on this commit:

| Lines the current script can see | Count |
|---|---|
| `final class … XCTestCase` | 151, all reduced to the token `class` |
| `class ReviewedHookWiring2Base: XCTestCase` in `Tests/AppUnitTests/ReviewedHookWiring2Tests.swift` | 1 |
| lines that start with an attribute, for example `@MainActor final class VerificationPresentationAppTests: XCTestCase` | 699, skipped |
| unique tokens | `ReviewedHookWiring2Base`, `class` |

Sorted order puts `ReviewedHookWiring2Base` on shard 0 and `class` on shard 1. Shards 2 and 3 are empty, so the script exits before `xcodebuild`. `QuestifyAppUnitTests/class` is not a class. This is a reading of the script and the sources. `xcodebuild` was not run.

`tools/generate_project.py` uses one class pattern, `APP_UNIT_CLASS`, and finds 851 unique classes here. The patch uses that same pattern, refuses duplicate names, then keeps `index % 4`. On this commit the four groups are 213, 213, 213, and 212. Each of the 851 names is in one group.

The Xcode Cloud plans on this commit are a different cut of the same 851 names: `sha256(name) % 4`.

| Scheme | Classes kept | Matches `sha256(name) % 4` |
|---|---|---|
| `QuestifyAppUnitTests-Shard01` | 202 | yes |
| `QuestifyAppUnitTests-Shard02` | 208 | yes |
| `QuestifyAppUnitTests-Shard03` | 224 | yes |
| `QuestifyAppUnitTests-Shard04` | 217 | yes |

`docs/release/xcode-cloud-setup.md` still says 223 and a total of 850. The plans in this commit are the counts above. Both cuts cover every class once. They do not assign the same class to the same shard index. The patch keeps the workflow’s `index % 4` rule. The Xcode Cloud schemes keep the sha256 plans. Applying the patch makes the GitHub matrix list real classes. It does not make that list equal to Shard01–Shard04.

## Xcode Cloud

Xcode Cloud is the path that does not wait on the GitHub Actions meter. The click path, the unsigned checkout, and the warning that an Xcode 27 image was not confirmed in the team’s picker are already in `docs/release/xcode-cloud-setup.md`. This note maps the five jobs onto the scripts and schemes already on this commit. It does not create a workflow in App Store Connect, and it does not start one.

`ci_scripts/ci_post_clone.sh` runs `python3 tools/xcode_cloud_prepare.py --checkout` on the temporary checkout. That writes `CODE_SIGNING_ALLOWED = NO` and `CODE_SIGNING_REQUIRED = NO` into the app project, the GLTFKit2 subproject, `Config/Base.xcconfig`, and `Config/AppUnitTests.xcconfig`. The script refuses a missing checkout path, so it does not edit a developer tree. The owner also sets a workflow environment variable `CODE_SIGNING_ALLOWED` = `NO` and leaves the secret checkbox off. No other variable, API key, certificate, or profile.

`Questify.xcscheme` uses Debug for Launch and Test, and Release for Archive. `ci_scripts/ci_post_xcodebuild.sh` runs `swift test` from the checkout root when the action is `build` and the scheme is `Questify`. From that directory that is the same package as `swift test --package-path .`. Shard actions do not run it again.

| ios-ci job | Xcode Cloud equivalent already described for this repo |
|---|---|
| debug-build | One Build action, scheme `Questify`, platform iOS, one iPhone simulator. The GitHub command also passes `-configuration Debug`, `-sdk iphonesimulator`, the iPhone 18 Pro destination, `ARCHS=arm64`, and `ONLY_ACTIVE_ARCH=YES`. The Build action is not an Archive action. This note did not open the team’s workflow editor, so it does not record the configuration label that editor shows. |
| core-tests | `swift test` inside `ci_post_xcodebuild.sh` on that Build action. There is no `core-tests.log` artifact. |
| appunit 0–3 | Four Test actions, schemes `QuestifyAppUnitTests-Shard01` through `Shard04`, Debug test action, one simulator each, required. Counts are the sha256 table above. That is the committed four-way split. It is a different assignment from the patched `index % 4` list. |
| release-gate | The two `python3 -B` commands in the table above. They are not in `ci_scripts/` on this commit. The owner can run them on a machine that has `python3` and `git` before trusting the cloud result. Adding them to `ci_post_clone.sh` is a later change. Run them once on the build, not once on every shard. |
| design-lint | `python3 -B tools/check_design_lint.py`. Same situation: the command is the workflow’s command, and this change does not add it to `ci_scripts/`. `check_scaffold.py` already calls it, so a release-gate run on the Mac covers this scan as well. |

Public Xcode Cloud release notes, as already recorded in `docs/release/xcode-cloud-setup.md` from a read on 2026-11-08 America/Los_Angeles, list Xcode 26.2 and do not list an Xcode 27 image. That page is not this team’s environment picker. If Xcode 27 is absent, the owner keeps the newest listed version. The iPhone 18 Pro destination in the GitHub job may be absent on that image. This note did not re-read the release notes and did not open the picker. Remaining free compute hours for team 9VHY8N755R were not read.

No Archive action, no Analyze action, and no TestFlight post-action belong to this fallback.

## CB45 stays disabled

`origin/cursor/cb45` is `8f19f66ce6340fd0fb6fecf689ffab073f250f18`. Its `docs/release/xcode-cloud-unsigned-archive.workflow.json` is a draft named “CB45 unsigned archive”: `isEnabled` false, `createdInAppStoreConnect` false, `started` false, manual start only, Release Archive of `Questify`, `postActions` empty, `secrets` empty, and `CODE_SIGNING_ALLOWED` `NO`. That file is not on `rc/20261108`. This branch does not merge it, copy it into `ci_workflows/`, set `isEnabled` to true, or start it. An unsigned archive is a different action from these five jobs.

## What the owner does later

1. Read Billing & plans. If Actions can assign a self-hosted runner, register the Mac (and, if wanted, a Python runner) with the labels in the patch. Keep the registration token off git and off the workflow.
2. On that Mac, confirm Xcode 27, an available iPhone 18 Pro simulator, `swift`, and `python3`. Keep signing material off that runner.
3. From a clean tree of the workflow blob the patch was built against, run `git apply --check docs/release/cb89-ios-ci.patch`. Apply it only in a later change the owner commits. The class-discovery hunk is part of this one patch. Applying the file takes that hunk with the label hunks.
4. For Xcode Cloud, follow `docs/release/xcode-cloud-setup.md` for the Build action and the four shard Test actions. Run the release-gate and design-lint commands on a machine with `python3` and `git`. Leave `CODE_SIGNING_ALLOWED=NO` unredacted. Add no secret.
5. Leave the CB45 JSON disabled. Leave the version at 0.1.0 (1). Leave `tools/current_ci_manifest.json` unrefreshed unless a separate ledger change says otherwise.

Merging this branch adds this note and the patch file. The hosted labels in `.github/workflows/ios-ci.yml` stay until the owner applies the patch in that later change.
