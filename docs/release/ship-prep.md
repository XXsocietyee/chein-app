# Ship prep

Checked against `origin/rc/20261108` at `a6871477c497c6440ce06417035572d7278ea830` (2026-11-08 PT). This continues the tree record from `origin/train/ui` at `6ba614a5dab10e00988d0bf83145fcf4b84e10a1`. It does not add legal copy, a signing identity, or a route that deletes an account.

Archive signing and App Store upload are owner-only. This branch does not sign and does not upload. `RegionalLaunchConfiguration.composition` calls `shippedComposition(build: .current)`. An empty URL or realm still uses `makeComposition(reviewed: nil, build: .current)` and calls no backend. The default target stays on `Config/Base.xcconfig`, whose URL and realm are empty.

## Present

| Item | Where | What is in the tree |
|---|---|---|
| Privacy manifest | `Resources/PrivacyInfo.xcprivacy` | App resource. `tools/generate_project.py` includes it, and the Questify target resources phase copies it (`D04AF157FB143F17000DA183` in `41D311A605520FC7B8B9A980`). `NSPrivacyTracking` is false and `NSPrivacyTrackingDomains` is empty. Collected types, each linked, not used for tracking, purpose App Functionality: Phone Number, User ID, Precise Location, Photos or Videos, Audio Data, Other User Content, Name, Email Address, Physical Address, Purchase History, Fitness, Device ID. Required-reason APIs: UserDefaults `CA92.1`, File Timestamp `C617.1` and `3B52.1`, System Boot Time `35F9.1`. The code pointers are in `docs/release/cb55-privacy.md`. |
| Vendored privacy manifest | `Vendor/GLTFKit2/GLTFKit2/PrivacyInfo.xcprivacy` | Bundled with GLTFKit2. Tracking off. Collected-data and accessed-API arrays are empty. |
| Photo-library add usage string | `Config/Info.plist` | `NSPhotoLibraryAddUsageDescription` is the only usage string in that file. The same English sentence, plus zh-Hans, is in `Resources/InfoPlist.xcstrings`. |
| Other usage strings | `Config/Base.xcconfig` | `GENERATE_INFOPLIST_FILE = YES` and `INFOPLIST_FILE = Config/Info.plist`, so these `INFOPLIST_KEY_*` values merge into the built Info.plist. Keys: `NSCameraUsageDescription`, `NSMotionUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSMicrophoneUsageDescription`. English text matches `Resources/InfoPlist.xcstrings`, which also has zh-Hans for each. |
| ATS | `Config/Info.plist` and `Config/*.xcconfig` | No `NSAppTransportSecurity`, `NSAllowsArbitraryLoads`, `NSAllowsLocalNetworking`, or `NSExceptionDomains`. `Config/Base.xcconfig` says there is no ATS relaxation. |
| Sign in with Apple entitlement | `Config/Questify.entitlements` | The app target already has the capability slot: Questify Debug and Release set `CODE_SIGN_ENTITLEMENTS = Config/Questify.entitlements` (`6C7EFF6369083C8E1F2B1994` and `DD75E2CB1C510A828AC72D96`). `tools/generate_project.py` sets the same key on the app target. The file is `com.apple.developer.applesignin` = `[Default]` and nothing else. The App ID switch in the developer portal is still owner-only. |
| Account-deletion path check | `tools/check_account_deletion_path.py` | Reads source and exits 0 when the blocked settings row is the unconfigured path. It does not open a socket and does not call apply. |
| Unsigned archive | `tools/archive_unsigned.py` | Preflight covers the manifest, English and zh-Hans usage strings, ATS, the existing Sign in with Apple slot, and the deletion-path check. It does not run `xcodebuild` unless `--archive` is passed. That command sets `CODE_SIGNING_ALLOWED=NO` and does not export or upload. |
| App Store metadata checklist | `docs/release/app-store-metadata-checklist.md` | Owner checklist. Nothing in it is submitted. |
| Placeholder bundle id and empty API URL | `Config/Base.xcconfig` | `PRODUCT_BUNDLE_IDENTIFIER = invalid.example.questify.ios`. `QUESTIFY_API_BASE_URL` is empty. `QUESTIFY_SESSION_REALM` is empty. |

The Questify target's base configuration, Debug and Release, is `Config/Base.xcconfig` (`CAE662172FD450BB0CD710A7`). `tools/generate_project.py` wires that file only. `Config/China.Production.xcconfig` is not the target base configuration.

## Missing

- Bundle id `com.chengyinhub.chengyinApp`. It is not set on `Config/China.Production.xcconfig`. A search of the tree finds no occurrence. It is not set only on that file; it is unset.
- Team `9VHY8N755R`. It is not set on `Config/China.Production.xcconfig`. A search of the tree finds no occurrence. No committed xcconfig sets `DEVELOPMENT_TEAM`. `Config/Local.xcconfig.example` leaves the team and bundle id as comments. `Config/Local.xcconfig` and `Config/Local.*.xcconfig` are gitignored and are not in this checkout.
- `Config/China.Production.xcconfig` does not assign `PRODUCT_BUNDLE_IDENTIFIER` or `DEVELOPMENT_TEAM`. It includes `China.xcconfig`, clears `QUESTIFY_API_BASE_URL` and `QUESTIFY_SESSION_REALM`, then sets the reviewed China URL `https://www.chengyinhub.com/prod-api/` (written `https:/$()/www.chengyinhub.com/prod-api/` so xcconfig does not treat `//` as a comment) and `QUESTIFY_SESSION_REALM = cn-prod`. It optionally includes the gitignored local file, then sets `QUESTIFY_DEPLOYMENT_ENVIRONMENT = production` and `QUESTIFY_MARKET = CN`. `shippedComposition` selects that host only when the market is China and the bundle and realm form a storage scope. Password login, bank withdrawal, virtual goods, and the US market stay off.
- US API URL. `Config/Base.xcconfig`, `Config/UnitedStates.xcconfig`, and `Config/UnitedStates.Production.xcconfig` leave `QUESTIFY_API_BASE_URL` empty. No US API URL is recorded here.
- `NSPhotoLibraryUsageDescription` is not in `Config/Info.plist` and is not an `INFOPLIST_KEY`. The add-only key above is the installed photo permission. This note does not add a read-library sentence. `Tests/ContractChecks/test_roam_share_photo_save.py` asserts the read key stays out of `Config/Info.plist`.
- `ITSAppUsesNonExemptEncryption` is not set. Export compliance stays an owner decision (`docs/parity/fix-plan.md` FP-M2). This note does not set it.
- Always-location and background-mode keys. `NSLocationAlwaysUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, and `UIBackgroundModes` are not in `Config/Base.xcconfig`, `Config/Info.plist`, `Resources/InfoPlist.xcstrings`, or `Resources/PrivacyInfo.xcprivacy`.
- Archive signing. No distribution certificate, provisioning profile, or team is in the tree. Device and US compiles in `.github/workflows/native-ios.yml` pass `CODE_SIGNING_ALLOWED=NO`. `Config/Base.xcconfig` sets `CODE_SIGN_STYLE = Automatic` and does not set `CODE_SIGNING_ALLOWED`, `DEVELOPMENT_TEAM`, or a signing identity.

Other committed bundle ids stay placeholders: `invalid.example.questify.ios.appunittests` in `Config/AppUnitTests.xcconfig`, and `invalid.example.questify.ios.uitests` on the UI-test target. GLTFKit2 uses `com.metalbyexample.gltfkit2` with an empty `DEVELOPMENT_TEAM` in its own project.

## Account deletion

Whether account deletion ships is an owner decision.

`python3 -B tools/check_account_deletion_path.py` reads the path and prints `deleted an account: no`. It refuses extra arguments. It does not send `POST api/user/deregister/apply`.

The settings row may exist. On the unconfigured composition an empty `QUESTIFY_API_BASE_URL` leaves `apiConfiguration` nil (`Core/RegionalConfiguration.swift`), so `AppSession.accountComplianceCoordinator` is nil. Settings then shows the blocked 账号注销 row (`settingsNative.blocked.accountDeletion`). Its destination opens the cancellation notice. The English blocked message says the request cannot be made in the app yet. That row does not delete an account.

Inbound parsers do not delete an account. `NativeNavigationContract` accepts team join, the content source paths, and `/badge`. `NativeEntryLinkPolicy` also accepts `/door`, merchant public-home, and the merchant team-invite path. None of those paths name deregistration.

`POST api/user/deregister/apply` exists in the compliance client. `AccountComplianceCompositionRoute` is accepted in `CompositionHTTPTransport.send` only when a reviewed deployment has `productionGatesEnabled` and the market is China. `isAccountComplianceEnabled` is that same China production-gate condition. The default build's composition is unconfigured, so that allowlist is off. This branch does not add a route that deletes an account. A lost apply response is recovered by reading `GET api/user/deregister/status` for the same request id. That read does not post apply again.

## Unsigned archive

`python3 -B tools/archive_unsigned.py` runs the preflight and does not invoke `xcodebuild`.

`python3 -B tools/archive_unsigned.py --archive` is the only archive command. It passes `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, an empty `CODE_SIGN_IDENTITY`, and `AD_HOC_CODE_SIGNING_ALLOWED=NO`. The archive path is `.build/unsigned-archive/Questify.xcarchive`, which `.gitignore` already covers via `.build/`. The script rejects upload and signing arguments, including a team, a profile, `altool`, `notarytool`, and Transporter. It does not export an IPA.

This workspace did not run `--archive`.

## Signing

Archive signing is owner-only. This branch does not sign and does not upload.

## Maestro

Smoke flows for launch, consent, sign-in, and welcome are in `.maestro/` and are described in `docs/release/smoke-flows.md`. They were not executed here. This workspace has no iOS Simulator or Maestro install.
