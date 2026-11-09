# CB40 — AppUnit shard plan and five-minute smoke

Base `origin/rc/20261108` `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. Branch `cursor/cb40`.

This VM has no Swift toolchain and no simulator. `swift test` and `xcodebuild` were not run. Nothing below is a new execution. The numbers quoted from logs are earlier Mac runs, copied from the docs that already record them.

No test was deleted, renamed, weakened, or given a new `XCTSkip`. The full suites stay. Shards and the smoke lane are extra commands that still select every class they are responsible for. `tools/current_ci_manifest.json` was not refreshed. Version stays 0.1.0 (1). Password login, bank-card withdrawal, and virtual goods stay off.

## Recorded baselines

These are the last Mac totals this note is allowed to use. They are not a rerun.

AppUnit, task baseline: **7566 tests, 545 failures, 125 unexpected**.

The same executed count is the `QuestifyAppUnitTests.xctest` line cited by `docs/release/cb3-appunit-groups.md` from `origin/cursor/A2` `15067547d`:

```text
Executed 7566 tests, with 548 failures (125 unexpected) in 770.824 (772.469) seconds
```

`cb3` records 548 as Xcode's assertion total and 545 as the task failure figure. This note keeps both as published records. The duration used below is the executed figure, 770.824 seconds.

Core, from `docs/release/cb2-core-unexpected.md` (Mac L1, `swift test --disable-sandbox`, `/private/tmp/rcfinal-core.log`):

```text
Executed 15473 tests, with 78 failures (15 unexpected) in 53.331 (54.147) seconds
```

## Why the full AppUnit command does not fit the current job

`.github/workflows/native-ios.yml` runs AppUnit as one matrix cell, `partition: app-unit`, on `macos-26`, job timeout 45 minutes, `fail-fast: false`. UI is already split into `plan['ui_shards']`. AppUnit is not.

`tools/current_native.py` runs that cell as one `xcodebuild` with `-parallel-testing-enabled NO`, one simulator, `-default-test-execution-time-allowance 120`, and process budget `BUDGET['app-test'] = 660` seconds. The host build is a separate step in the same job, budget `app-build` 1200 seconds, then `test-without-building`. Boot has its own budget of 180 seconds.

770.824 seconds of recorded test time is already longer than the 660 second test budget. One full `QuestifyAppUnitTests` command cannot stay inside the budget the runner has today. The fix is more jobs, each still running its classes, with the host built once.

Leaving `-parallel-testing-enabled NO` is part of the proposal. Hosted tests share one window, the keychain, and the simulator locale. The current command already forbids parallel destinations. Shards are separate processes.

## Source inventory this plan balances on

Counted from `Tests/AppUnitTests/*.swift` on this tree (a text scan, not a compile):

| Item | Count |
|---|---:|
| Swift files | 779, flat directory |
| Types in the `XCTestCase` lineage | 855 |
| Of those, types that declare a `func test…` | 854 |
| `func test…` declarations | 7575 |
| Files that contain more than one test class | 44 |
| Classes whose body mentions `UIWindow` or `UIHostingController` | 152 (1474 methods) |
| Classes whose body mentions `Task.sleep` | 82 |
| Largest class | `MerchantBusinessAccessModelTests`, 40 methods |

`ReviewedHookWiring2Base` is the empty shared harness. Five final subclasses in `Tests/AppUnitTests/ReviewedHookWiring2Tests.swift` are the runnable suites (`ReviewedMerchantMarketingWiringTests`, `ReviewedRoamShareSnapshotWiringTests`, `ReviewedCityVoucherIssueWiringTests`, `ReviewedNearbyTeamWriteWiringTests`, `ReviewedMerchantOperationsWiringTests`). A shard key is the class name, because `-only-testing:QuestifyAppUnitTests/<Class>` selects one class even when the file holds several. `tools/run_ui_shard.py` refuses a file with two `XCTestCase` types. AppUnit cannot copy that refusal without splitting files. This plan does not split files.

Eight methods are the existing device-only ledger in `tools/current_ci.py` (`ContentDraftDeviceStorageAcceptanceTests`, five methods; `PlayRecoveryDeviceStorageAcceptanceTests`, three). They stay on that ledger, reported not run on the simulator, and they are not a simulator shard. Removing them from the simulator inventory follows that existing classification. It is not a new skip.

7575 declarations minus those 8 is 7567. The recorded simulator execution is 7566. This scan does not explain the one-declaration gap, and it is not a failure count.

`ProfileGuideReadTests` has 17 methods. `NormalHomeRuntimeRecoveryTests` has 11. `StoryWalkingFogAndWorkshopUpgradeViewTests` has 3. `ClubPostDiscussionReadTests` has 10.

## Shard proposal

Copy the UI shape already in `native-ios.yml`: one build, many `test-without-building` jobs, `fail-fast: false`, `max-parallel: 20`, then an aggregate that requires every class exactly once. The build step is the existing `tools/build_simulator_keychain_host.py` invocation. Shards download that product and pass `-xctestrun`. They do not compile.

Partition with the same greedy rule as `run_ui_shard.partition`: sort classes by descending method count, then by name, and place each class on the shard whose current method count is smallest. The weight is the source `func test` count. There is no AppUnit duration profile in the tree. `tools/ui_duration_weights.json` is the UI target, mixes measured seconds with unmeasured allowances, and is the wrong table. UI's 900 second method cap and 1500 second shard cap stay on UI. AppUnit's caps stay 120 seconds per test and 660 seconds per test command.

Do not split a class. The largest class is 40 methods. Do not drop the 65 classes in `cb3`, including the ones that fail on the recorded baseline.

### Count: 8

Eight is the smallest count from 2 through 16 for which the guardrail below is inside 660 seconds. The guardrail is not a measured shard time.

The only AppUnit class rate this note will reuse is the slowest per-test rate in `docs/parity/gap-wave-compare.md`. That comparison is 11 classes and 115 tests, not the full suite. On the pre-wave log, `RoamPassportServerHistoryHostTests` executed 8 tests in 5.394 seconds (5.397 seconds with the harness). 5.394 / 8 = 0.67425 seconds per test. Applying that rate to every method in the heaviest shard is a ceiling taken from one class. The same class was 1.099 seconds on the later log. The ceiling uses the slower of those two published lines.

Greedy balance on the 852 simulator classes (7567 source methods), and that ceiling:

| Shards | Heaviest shard, methods | Ceiling at 5.394s / 8 tests | Inside 660s test budget |
|---:|---:|---:|---|
| 2 | 3784 | 2551s | no |
| 4 | 1892 | 1276s | no |
| 7 | 1081 | 729s | no |
| 8 | 946 | 638s | yes |

A uniform split of the recorded 770.824 seconds is a different bound: the heaviest of 8 shards holds 946 / 7566 of that run, about 96 seconds. That bound is true only if every test costs the suite average (770.824 / 7566 ≈ 0.102 seconds). Hosted classes in the 11-class sample are slower than that average. The plan uses the slower ceiling to pick the count, and it does not claim a shard will take 96 seconds or 638 seconds.

Eight jobs fit in `max-parallel: 20`, so the test wave is one wave after the shared build. Each shard still boots under the existing 180 second boot budget. Boot is not part of the 638 second comparison. The 638 second figure is compared only with `BUDGET['app-test']`.

Each shard command:

- `-parallel-testing-enabled NO`
- `-maximum-concurrent-test-simulator-destinations 1`
- `-test-timeouts-enabled YES`
- `-default-test-execution-time-allowance 120`
- `-maximum-test-execution-time-allowance 120`
- one `-only-testing:QuestifyAppUnitTests/<Class>` per class on that shard
- `test-without-building`

The aggregate fails unless the union of classes is the 852 simulator classes, with no duplicate. A shard that hits 660 seconds or the 120 second method allowance stays failed. A partial xcresult is not a pass. `tools/current_native.py` already retries `simctl list devices` once. That retry stays on the device inventory. Test commands are not retried.

The 39 host-accessibility classes in `cb3` group 1 are inside the 852. On this tree those 39 classes declare 381 `func test` methods. `cb3`'s 142 is the failing-method count on the task baseline, not the size of the classes. They stay in the greedy partition. Isolating them would be a second plan. This one does not need it for the ceiling above, and it does not drop them.

## Stability list

The tree does not record a flake rate. No failure count in this section was produced here. Names come from existing docs or from the source scan above.

### Result changed with the simulator locale

`docs/parity/gap-wave-compare.md` ran the same 11 classes on two trees. `StoryWalkingFogAndWorkshopUpgradeViewTests` executed 3 tests with 0 failures in 0.040 seconds on the pre-wave simulator (`AppleLocale = zh-Hans_US`) and 3 tests with 1 failure in 0.037 seconds on the later simulator (`AppleLocale = en_US`). The one method that changed was `testWorkshopModUpgradeSheetViewInstantiatesBreakingAndCompatibleDiffWithConfirmationGate`. The doc says the test file, `App/WorkshopModUpgradeSheetView.swift`, and `Core/WorkshopModUpgradePresentation.swift` were empty in the diff between those commits. The assertion is still `pinnedExistingRunsNotice.contains("固定保持原版本")` at `Tests/AppUnitTests/StoryWalkingFogAndWorkshopUpgradeViewTests.swift:158`. The presentation initializer used there keeps the default `Locale.current`.

That is one published pass and one published failure of the same method. It is not a rate.

### Historical nondeterminism whose method is not named

`docs/LATEST_VERIFICATION.md` (2026-10-02, Run 53) says the PlayKit retry test exposed nondeterministic dictionary key order, and that JSON bodies then used sorted keys. The paragraph does not name the method and does not give that test its own failure count. The "three methods failed with four assertions" in the same section is that run's whole Core result at 2698 methods. It is not the current Core baseline of 15473 / 78 / 15. `JSONSerialization.WritingOptions.sortedKeys` is present in `Tests/CoreTests/PlayKitGLBPolicyTests.swift` and `Tests/AppUnitTests/PlayKitGLBDecoderTests.swift`. Those two mentions do not identify the unnamed retry test.

### Waits that can fail when a request never arrives

No flake count is attached to these. They are bounded so a missing request fails the test instead of holding the job.

- `Tests/AppUnitTests/ClubPostDiscussionReadTests.swift` `waitForRequests` waits 3 seconds (`ContinuousClock` plus `Task.sleep` of 5 milliseconds). `docs/parity/full-suite-triage.md` says this helper used to be unbounded, and that after the bound the class recorded 10 tests and 0 failures in `/private/tmp/gm-testc-club3.log`. The source still declares 10 test methods.
- The same triage sentence says the unbounded helper in 4 CoreTests files was bounded to 5 seconds, and it does not name the files. The 5-second `waitForRequests` helpers in the tree now are `Tests/CoreTests/ProfileServiceTests.swift`, `Tests/CoreTests/CooperationTests.swift`, `Tests/CoreTests/AccountCollectionTests.swift`, and `Tests/CoreTests/TicketWalletTests.swift`.
- `Tests/AppUnitTests/WalkingNavigationAppTests.swift` polls with `Task.sleep` (loops of up to 100 steps at 10 milliseconds, plus 30 millisecond sleeps). No doc records a failure count for those sleeps.
- `WorkshopCreatorConsentNormalFlowTests` and `WorkshopCreatorPendingNormalFlowTests` poll with `Date()` and `Task.sleep`. The pending class is also in the `cb3` copy-mismatch group (3 methods on the task baseline). That copy mismatch is a stable assertion difference. The poll is a separate source fact.
- 82 test classes contain `Task.sleep`. That is a source pattern. It is not 82 flakes.

### Stable on the recorded baseline

These fail the same way in the published triage. Treating them as flakes and retrying them would hide a real result. They stay in the 8 shards.

- `cb3` group 1, 39 classes, 142 failing methods on the task baseline: iOS 27 host accessibility (`UIWindow` / `UIHostingController`, and `AccessibilityNode` not matching `as? UIAccessibilityIdentification`). `docs/parity/full-suite-triage.md` describes the same host failure, including `InvalidTransition` and `cnt=0`.
- Keychain `-34018` on the unsigned host: `PrivateHomeSystemKeychainTests` (4), `ContentDraftSystemStorageTests` (1), `PlayRecoverySystemStorageTests` (1), from `cb3` and `full-suite-triage.md`. `PlayRecoverySystemStorageTests` calls `SecItemCopyMatching`.
- `MerchantReviewOriginalRecoveryEntryTests`: `APIConfiguration` rejects a host ending in `.invalid` (`cb3`, 11 methods). `gap-wave-compare.md` records 11 failures and 11 unexpected for that class on both of its logs.
- Copy-mismatch classes listed in `cb3` group 3 (channel appeal and pin localization, template shelf and metadata, workshop creator pending, and the other copy rows in that table).
- `OwnMediaAudioPreviewHostTests` and `OwnMediaModelPreviewHostTests`: password gate. Password login stays off.
- `MerchantOfferWithdrawalUnifiedStoreTests`: `cb2` records one `persistence` throw from the historical-root walk. The same file skips when `geteuid() == 0` (`XCTSkip`, "Root bypasses POSIX permission checks"). That skip stays as written.

`WeChatNativePaymentDriverTests` and `WeChatNativeSDKDriverTests` skip when the driver is linked, with the messages already in those files. Those skips stay. They are not a pattern for shortening the suite.

`docs/LATEST_VERIFICATION.md` also records older UI shard deadlines (Run 51 and run 54, on an inventory of about 350 UI methods). Those counts belong to that inventory. They are not the 7566 / 545 / 125 AppUnit baseline and not the 15473 / 78 / 15 Core baseline. They are the reason a shard deadline stays a failure.

## Five-minute smoke lane

This lane is additional. The 8 AppUnit shards and the existing UI shards still run every selected test. The lane does not replace them.

The recorded full AppUnit execution is 770.824 seconds, which is over 5 minutes, so the lane cannot be the full AppUnit target. The recorded full Core execution is 53.331 seconds (54.147 with the harness), which is inside 5 minutes of test time.

Cold compile is outside the lane. `BUDGET['core-build']` is 720 seconds and `BUDGET['app-build']` is 1200 seconds. A cold simulator boot is also outside it (`BUDGET['boot']` is 180 seconds). The lane starts from a Core test bundle and an app-unit host already built for the same commit, and from a simulator that is already booted. The job `timeout-minutes` is 5. A timeout fails this lane. It does not skip the shards.

Two commands, serial, `-parallel-testing-enabled NO`:

1. Whole `QuestifyCore` package, `swift test --skip-build --disable-sandbox`. Every Core test runs. The only duration on record for that command's test phase is 53.331 seconds.
2. `xcodebuild … test-without-building` with exactly these selectors:
   - `QuestifyAppUnitTests/NormalHomeRuntimeRecoveryTests/testUnconfiguredLaunchNeverReadsVaultOrDispatches` — the AppUnit identity already listed in `tools/current_ci.py` `smoke`. Its own duration is not in the published logs. The method hosts `SessionRootView` in a `UIHostingController` (`Tests/AppUnitTests/NormalHomeRuntimeRecoveryTests.swift`).
   - `QuestifyAppUnitTests/ProfileGuideReadTests` — the whole class, 17 methods. `gap-wave-compare.md` records this class as pass on both trees: 17 tests, 0 failures, 0.952 seconds pre-wave and 0.406 seconds on the later log.

The recorded pieces of this lane add to 53.331 + 0.952 seconds, plus the one AppUnit smoke method whose duration was not published separately. That is the basis for aiming the lane at under 5 minutes. It is not a measurement of the lane.

The third current smoke identity, `QuestifyUITests/EntryFlowTests/testSettingsReopensAfterRepeatedColdLaunch`, has a recorded UI weight of 59.714 seconds in `tools/ui_duration_weights.json`. It stays on the UI shard path. The UI method allowance is 900 seconds, so a UI launch does not belong in a job whose timeout is 5 minutes.

The 65 baseline-failing classes stay on the full shards. Putting them in this lane would make the lane red for the published baseline, which would hide a new Core or smoke-method failure.

`.maestro/` remains the four flows in `docs/release/smoke-flows.md` (launch, consent, welcome, sign-in). They were not timed, they were not run, and they are not this lane. They still do not type a password or tap WeChat, Apple, or a payment control.

Password login, bank-card withdrawal, and virtual goods are not added to the lane.

## Not run

- `swift test`, `swift build`, `xcodebuild`, `xcrun`, `simctl`
- The 8-shard partition as a test command
- The five-minute lane
- Maestro
- `tools/current_ci.py refresh` and any write to `tools/current_ci_manifest.json`
- A new failure count, a flake rate, or a per-shard duration
