# Final Integration & Regression Report (`wip/gm-final`)

## 1. Integrated Branches (Merged in Order onto `origin/wip/gm-rc` `19a5ec2a`)
1. `origin/wip/gm-hook2` (`19a5ec2a`) — already at `origin/wip/gm-rc` tip.
2. `origin/wip/gm-fix1` (`857215c0`) — merged cleanly; updated `tools/generate_project.py` to emit `CODE_SIGN_ENTITLEMENTS = "Config/Questify.entitlements"` on the `Questify` target so `generate_project.py`, `check_scaffold.py`, and `test_entitlements_contract.py` agree.
3. `origin/wip/gm-fix2` (`9baaf775`) — merged cleanly; added `Localizable.xcstrings` bilingual entries for the two `SettingsSupportSafetyEntry` labels introduced in `gm-fix1` so `localization_usage_audit.py` and `test_localization_key_catalog_contract.py` pass with 0 findings.
4. `origin/wip/gm-fix3` (`bae67a50`) — merged cleanly; `lint_no_release_print.py` and `test_accessibility_hardening_wave.py` pass.
5. `origin/wip/gm-fix4` (`5d95a55a`) — resolved `App/QuestifyApp.swift` language environment modifier conflict using `.modifier(AppLanguageEnvironment(stored: storedLanguage))`.

## 2. Scaffold, Contract Checks, and App Build
- `python3 tools/generate_project.py`:
  - `Generated Questify.xcodeproj: 3151 native sources, 196 catalogs`
  - `Included 760 app-unit sources in the separate QuestifyAppUnitTests scheme`
- `python3 tools/check_scaffold.py`:
  - `PASS structural checks: 4188 Swift source files, 14229 bilingual keys, references, scheme, read-only expected project equivalence`
- Contract checks across `gm-fix1..gm-fix4` (`71` unit tests + `localization_usage_audit.py` + `lint_no_release_print.py`): **PASS (71/71 OK, 0 audit findings)**.
- App build via `/private/tmp/rc1-build.sh /Users/fanning/orca/workspaces/native-ios/TC-G /private/tmp/gmfinal-build.log`:
  - `** BUILD SUCCEEDED **` (`BUILD_EXIT=0`).

## 3. Simulator Locale Normalization
All three simulators (`Questify-iPhone17`, `Questify-iPhone17-Lane2`, `Questify-iPhone17-W2`) were set to `AppleLocale = zh-Hans_US` and `AppleLanguages = ("zh-Hans-US")` before running the regression batches.

## 4. Final `Executed` Lines

### Core (`swift test --disable-sandbox`, `/private/tmp/gmfinal-core.log`)
```text
Test Suite 'QuestifyCoreTests.xctest' failed at 2026-11-07 23:09:56.819.
	 Executed 15238 tests, with 78 failures (15 unexpected) in 62.537 (64.683) seconds
Test Suite 'All tests' failed at 2026-11-07 23:09:56.819.
	 Executed 15238 tests, with 78 failures (15 unexpected) in 62.537 (64.687) seconds
```

### AppUnit (`835` classes split round-robin into 3 parallel `/private/tmp/rc1-ptest.sh` batches)
- **Batch 1 (`Questify-iPhone17`, 279 classes, `/private/tmp/gmfinal-app-1.log`)**:
  ```text
  Test Suite 'QuestifyAppUnitTests.xctest' failed at 2026-11-07 23:11:14.192.
  	 Executed 2459 tests, with 134 failures (28 unexpected) in 148.204 (149.107) seconds
  Test Suite 'Selected tests' failed at 2026-11-07 23:11:14.193.
  	 Executed 2459 tests, with 134 failures (28 unexpected) in 148.204 (149.112) seconds
  ```
- **Batch 2 (`Questify-iPhone17-Lane2`, 278 classes, `/private/tmp/gmfinal-app-2.log`)**:
  ```text
  Test Suite 'QuestifyAppUnitTests.xctest' failed at 2026-11-07 23:13:12.326.
  	 Executed 2390 tests, with 227 failures (57 unexpected) in 244.999 (245.964) seconds
  Test Suite 'Selected tests' failed at 2026-11-07 23:13:12.327.
  	 Executed 2390 tests, with 227 failures (57 unexpected) in 244.999 (245.967) seconds
  ```
- **Batch 3 (`Questify-iPhone17-W2`, 278 classes, `/private/tmp/gmfinal-app-3.log`)**:
  ```text
  Test Suite 'QuestifyAppUnitTests.xctest' failed at 2026-11-07 23:18:30.730.
  	 Executed 2608 tests, with 163 failures (30 unexpected) in 405.003 (405.698) seconds
  Test Suite 'Selected tests' failed at 2026-11-07 23:18:30.731.
  	 Executed 2608 tests, with 163 failures (30 unexpected) in 405.003 (405.700) seconds
  ```

## 5. Comparison Against `docs/parity/full-suite-triage.md` and `docs/parity/gap-wave-compare.md` — NEW Failures Only

- **Core (`QuestifyCoreTests`)**: **None (0 new failures)**. All 36 unique failing tests across 21 classes are pre-existing baseline failures listed in `docs/parity/full-suite-triage.md` (down from 39; `InvoiceLaunchCoordinatorTests`, `ParticipantCoordinatorTests`, and `ParticipantCoordinatorSnapshotLifetimeTests` now pass, and `InvoiceLaunchServiceTests` passes).
- **AppUnit (`QuestifyAppUnitTests`)**: **None (0 new persistent failures)**.
  - Previously failing `ClubOrdinaryAdmissionCompositionTests` (fixed by `gm-fix1` FP-C5), `StoryWalkingFogAndWorkshopUpgradeViewTests` (resolved by normalizing `Questify-iPhone17-W2` to `zh-Hans_US`), and `RoamPassportServerHistoryHostTests` all **PASS** (`0` failures).
  - All other failing classes in Batches 1–3 are accounted for in `docs/parity/full-suite-triage.md` and `docs/parity/gap-wave-compare.md`, with two notes:
    1. `RoamPassportHomeScopeRecoveryTests` had 3 transient SwiftUI AX settle timeouts in Batch 2 under 3-simulator + Core load, and passed **7/7 (`0` failures)** on re-run via `/private/tmp/rc1-ptest.sh` (`/private/tmp/gmfinal-recheck.log`: `Executed 7 tests, with 0 failures (0 unexpected) in 0.892 (0.894) seconds`).
    2. `ProfileGuideReadTests.testOrdinaryConfiguredGuideLoadsOriginalListAndRefreshesWithoutWrites` (1 test, included in `gap-wave-compare.md` where it passed on `en_US`) fails on `zh-Hans_US` (`XCTAssertEqual failed: ("["infomation_list"]") is not equal to ("["infomation_list", "infomation_list"]")`, same failure recorded in `full-suite-gap-wave.md`).
