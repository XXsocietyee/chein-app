# ui/cur-appstore

Handover 41. Parent `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46` (`origin/ui/main`). App Store readiness only.

`App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/ReviewedAreaSwitch.swift` are unchanged. `docs/release/contract-failing-baseline.txt` is unchanged. No method was added. No Swift file was added, so `tools/generate_project.py` was not run. The completeness matrix was not imported.

`moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` stay off for `www.chengyinhub.com`. `externalGames` stays off on that production host. This branch does not turn them on. No card charge was added.

Swift was not compiled on this Linux VM. `swiftc` is absent. This receipt does not claim a typecheck. Screenshots were not taken.

## Privacy manifest

`Resources/PrivacyInfo.xcprivacy` already matched the grep of `App/` and `Core/`. This handover does not edit it. Tracking is none (`NSPrivacyTracking` false, `NSPrivacyTrackingDomains` empty).

Declared required-reason APIs:

- User Defaults `CA92.1`
- File Timestamp `C617.1` and `3B52.1`
- System Boot Time `35F9.1`

Left out:

- Disk Space (`85F4.1`, `E174.1`, `7D9E.1`, `B728.1`)
- Active Keyboards (`3EC4.1`, `54BD.1`)
- User Defaults `1C8F.1`, `C56D.1`, `AC6B.1`
- File Timestamp `DDA9.1`, `0A2A.1`
- System Boot Time `8FFB.1`, `3D61.1`

Collected types that stay: Phone Number, Name, Email Address, Physical Address, Precise Location, Photos or Videos, Audio Data, Other User Content, Fitness, User ID, Device ID, Purchase History. Each is linked, not used for tracking, purpose App Functionality.

Location, including background: Precise Location is declared. Background location is not used (`allowsBackgroundLocationUpdates = false`; no Always usage string; no `UIBackgroundModes`), so it is not declared. Coarse Location is not declared.

Photos or Videos are declared. Contacts are not used and are not declared.

Answers: `docs/release/app-privacy-answers.md` (en and zh-Hans).

## StoreKit sandbox

`Config/QuestifySandbox.storekit` is a local sandbox configuration. Product array is empty. It is not attached to the shared scheme and is not an app resource.

StoreKit product ids: —

No digital good in this tree has a product id the app sells. `DIGITAL_MOD` ids come from an empty shipped `storeKitProductIDs`. The test id `mod.release` is not a sold product. Platform-pass and marketing purchases stay unreachable. Virtual currency is not a StoreKit product. External games stay `NONE`. Detail: `docs/release/storekit-sandbox.md`.

## Review notes and release notes

`docs/release/app-store-review-notes.md` (en and zh-Hans). Demo-account steps are —. Missing: username, phone number, SMS code, and password. The Guideline 4.7 index is described and stays off on `www.chengyinhub.com`.

`docs/release/release-notes.en.md` and `docs/release/release-notes.zh-Hans.md`. Version `0.1.0` (`1`). Support URL, privacy-policy URL, and a review password are —.

## Checks

`python3 tools/check_scaffold.py` passed (privacy manifest, design lint, appsession ratchet, page route table, structural checks). `python3 tools/check_design_lint.py` passed (1613 App Swift files, allowlist unchanged). `python3 -m unittest Tests.ContractChecks.test_privacy_manifest_contract Tests.ContractChecks.test_app_store_privacy_launch_contracts` passed (10 tests). `swiftc` was not run.
