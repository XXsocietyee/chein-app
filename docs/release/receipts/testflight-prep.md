# Receipt: Lane T testflight-prep

Branch `claude/testflight-prep` from `origin/ui/combined-r7` `2446657fb`. Brief: `origin/design/handoff-r2:docs/briefs/player-launch-lanes.md` Lane T. 2026-11-26.

## Changed

| Area | Change | Files |
|---|---|---|
| Version | `MARKETING_VERSION` 0.1.0 → **1.0.0**, `CURRENT_PROJECT_VERSION` 1 → **2** (via `tools/bump_version.py --apply`; build 2 so build 1 is never reused, per `version-scheme.md`). Tests that pin the pair updated. | `Config/Base.xcconfig`; `Tests/ContractChecks/test_{sign_in_with_apple_flow,universal_link_associated_domains,cb51_diagnostics,cb36_offline,cb50_error_catalog}.py`; `Tests/CoreTests/SignInWithAppleFlowTests.swift` |
| Bundle id | Unchanged: Release `com.chengyinhub.chengyinApp`, Debug placeholder. | `Config/Release.xcconfig` |
| Signing | Unchanged: `CODE_SIGN_STYLE = Automatic`. No team id, certificate or profile added. See "Not done". | — |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` (HTTPS + Apple CryptoKit for local data only). | `Config/Info.plist` |
| Usage strings | Camera text widened to every camera use in the code (QR, play-task photo, city stamp, post/profile photo, AR scene, merchant aftercare evidence); en + zh-Hans kept identical across the xcconfig, the InfoPlist catalog, its fragment and the camera primer. All five usage keys (camera, location when-in-use, microphone, motion, photo-library add) verified en == xcconfig and zh-Hans present. No contacts, Bluetooth, Face ID, speech, HealthKit, calendar, tracking or Always-location API in `App/`/`Core/`, so no other key is needed. | `Config/Base.xcconfig`, `Resources/InfoPlist.xcstrings`, `Resources/MerchantEngagementInfoPlist.fragment.json`, `App/DesignSystem/CYPermissionPrimer.swift` |
| Privacy manifest | Added Search History, Gameplay Content, Customer Support, Other Data Types (ID number). Required-reason APIs re-grepped (UserDefaults, file timestamps, `systemUptime`; no disk space / keyboards) and already correct. Evidence pinned in the contract test. | `Resources/PrivacyInfo.xcprivacy`, `Tests/ContractChecks/test_privacy_manifest_contract.py`, `docs/release/app-privacy-answers.md` |
| StoreKit | Owner table of every digital good the MP sells (11 payment call sites traced in `hengyin` `7e524aa0`), proposed product ids, types, tiers, non-IAP list, open questions. Virtual goods **not** enabled; `QuestifySandbox.storekit` untouched. | `docs/release/storekit-products.md` |
| Checklist | Owner archive → sign → upload → export compliance → internal group → first test list. | `docs/release/testflight-upload-checklist.md` |

`tools/generate_project.py` produces the project, but versions, bundle id and Info.plist keys live in the xcconfigs / `Config/Info.plist`, so no generator or `project.pbxproj` change was needed.

## Reused from Cursor lanes

`cursor/a5-testflight` (`testflight-internal.md`), `a9-release-pack` (`app-store-pack.md`) and the `tools/check_privacy_manifest.py` gate from `a8-l10n-privacy` are already in the base; the new checklist links to them instead of copying. `a8`'s `docs/release/a8-l10n-privacy.md` is not in the base and was not needed.

## Checks

- `python3 tools/check_scaffold.py`: exit 0, all PASS.
- `python3 tools/check_privacy_manifest.py`: PASS, 16 collected types, 3 required-reason categories match source.
- `python3 tools/check_release_config.py`: passed.
- Contract tests touching Info.plist / manifest / version (10 files): OK.
- `python3 tools/contract_ratchet.py --check`: 247 failing, 63 new vs baseline — **the identical 63 fail on untouched `origin/ui/combined-r7`** (diffed); this lane adds none. Those are Lane A1/A2's.
- Pre-existing, unchanged by this lane: `tools/archive_unsigned.py` prints `FAIL: UIBackgroundModes is present` (the roam background-location mode the owner approved, OWN-D-07; the script predates it); five `tools/tests` files fail the same way on the base.
- No Swift compiler in the cloud: the one Swift test edit is a string literal.

## Not done / for the owner

- `Config/Release.xcconfig` already carries `DEVELOPMENT_TEAM` (owner-approved earlier, pinned by `tools/check_release_config.py` and `tools/tests/test_release_prep.py`). This lane did not add or change it. If you want no team id in the public repo, say so and a follow-up removes it and moves it to a gitignored `Config/Local.xcconfig` plus the Xcode team picker.
- Version 1.0.0 (2) is a proposal matching the 1.0 listing; change with `tools/bump_version.py` if you want another pair.
- StoreKit open questions in `storekit-products.md` section 3.
