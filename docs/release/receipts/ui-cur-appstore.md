# ui/cur-appstore

Handover 41, then the follow-up. Rebased onto `origin/ui/main` `9209d33cb2d7ceed6f95a1b9d90b556e531a63b0`. The previous parent was `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46`. App Store readiness only.

`App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/ReviewedAreaSwitch.swift` are unchanged. `docs/release/contract-failing-baseline.txt` is unchanged. No method was added. No Swift file was added, so `tools/generate_project.py` was not run. The completeness matrix was not imported.

`moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` stay off for `www.chengyinhub.com`. `externalGames` stays off on that production host. This branch does not turn them on. No card charge was added.

Swift was not compiled on this Linux VM. `swiftc` is absent. This receipt does not claim a typecheck. Screenshots were not taken.

## Privacy manifest

`Resources/PrivacyInfo.xcprivacy` still has the same collected types and the same required-reason APIs. Tracking is none (`NSPrivacyTracking` false, `NSPrivacyTrackingDomains` empty). A comment on Precise Location records the follow-up. No new API category was added.

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

Location, including background: Precise Location stays the declared type. `ui/wp-11` `1e48434aaa7ec692265f73e343394ff799440be8` does use background updates. `App/SessionBackgroundLocationTracker.swift` sets `allowsBackgroundLocationUpdates = true` and `showsBackgroundLocationIndicator = true` only while a roam hold is active and the location background mode is present. It requests when-in-use authorization and does not call `requestAlwaysAuthorization`. Play holds stay foreground-only. That tracker is not in `origin/ui/main` `9209d33`, so this branch's binary does not call it. Apple's manifest has no separate background-location type and no required-reason API for it. Background location is declared as the existing Precise Location row, not as a new API. Coarse Location is not declared. Contacts are not used and are not declared.

Photos or Videos are declared. Contacts are not used and are not declared.

Answers: `docs/release/app-privacy-answers.md` (en and zh-Hans).

## StoreKit sandbox

`Config/QuestifySandbox.storekit` is a local sandbox configuration. Product array is empty. It is not attached to the shared scheme and is not an app resource.

StoreKit product ids added: none. The product array stays empty.

Checked `origin/ui/main` `9209d33` and `ui/wp-11` `1e48434`. No sold StoreKit product id exists in either tree. `DIGITAL_MOD` ids come from an empty shipped `storeKitProductIDs`. The test id `mod.release` was not added. Prices were not invented. Platform-pass and marketing purchases stay unreachable. Virtual currency is not a StoreKit product. External games stay `NONE`. Detail: `docs/release/storekit-sandbox.md` (en and zh-Hans).

## Review notes and release notes

`docs/release/app-store-review-notes.md` (en and zh-Hans). Demo-account steps are —. Missing: username, phone number, SMS code, and password. The Guideline 4.7 index is described and stays off on `www.chengyinhub.com`.

`docs/release/release-notes.en.md` and `docs/release/release-notes.zh-Hans.md`. Version `0.1.0` (`1`). Support URL, privacy-policy URL, and a review password are —.

## Checks

`python3 tools/check_scaffold.py` passed (privacy manifest, design lint, appsession ratchet, page route table, structural checks). `python3 tools/check_design_lint.py` passed (1614 App Swift files, allowlist unchanged). `python3 -m unittest Tests.ContractChecks.test_privacy_manifest_contract Tests.ContractChecks.test_app_store_privacy_launch_contracts` passed (10 tests). `swiftc` was not run.
