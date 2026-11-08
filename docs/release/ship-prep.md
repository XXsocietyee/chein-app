# Ship prep

Checked on `origin/train/ui` at `6ba614a5dab10e00988d0bf83145fcf4b84e10a1` (2026-11-08 11:50 AM PT). This note records what is in the tree. It does not add legal copy, a US API URL, a signing identity, or a route that deletes an account.

Archive signing is owner-only. This branch does not sign.

## Present

| Item | Where | What is in the tree |
|---|---|---|
| Privacy manifest | `Resources/PrivacyInfo.xcprivacy` | App resource. `tools/generate_project.py` includes it, and the Questify target resources phase copies it (`D04AF157FB143F17000DA183` in `41D311A605520FC7B8B9A980`). `NSPrivacyTracking` is false and `NSPrivacyTrackingDomains` is empty. Collected types, each linked, not used for tracking, purpose App Functionality: Phone Number, User ID, Precise Location, Photos or Videos, Audio Data, Other User Content, Name, Email Address, Physical Address, Purchase History, Fitness, Device ID. Required-reason APIs: UserDefaults `CA92.1`, File Timestamp `C617.1`, System Boot Time `35F9.1`. |
| Vendored privacy manifest | `Vendor/GLTFKit2/GLTFKit2/PrivacyInfo.xcprivacy` | Bundled with GLTFKit2. Tracking off. Collected-data and accessed-API arrays are empty. |
| Photo-library add usage string | `Config/Info.plist` | `NSPhotoLibraryAddUsageDescription` is the only usage string in that file. The same English sentence, plus zh-Hans, is in `Resources/InfoPlist.xcstrings`. |
| Other usage strings | `Config/Base.xcconfig` | `GENERATE_INFOPLIST_FILE = YES` and `INFOPLIST_FILE = Config/Info.plist`, so these `INFOPLIST_KEY_*` values merge into the built Info.plist. Keys: `NSCameraUsageDescription`, `NSMotionUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSMicrophoneUsageDescription`. English text matches `Resources/InfoPlist.xcstrings`, which also has zh-Hans for each. |
| Sign in with Apple entitlement | `Config/Questify.entitlements` | `com.apple.developer.applesignin` = `[Default]`. Questify Debug and Release set `CODE_SIGN_ENTITLEMENTS = Config/Questify.entitlements`. `tools/generate_project.py` sets the same key on the app target. |
| Account-deletion row | Settings | The row may exist. With no API configuration the compliance coordinator is nil, and Settings shows the blocked row `settingsNative.blocked.accountDeletion` (账号注销 / Account cancellation). That row opens an unavailable explanation and the cancellation notice. It does not delete an account. |
| Placeholder bundle id and empty API URL | `Config/Base.xcconfig` | `PRODUCT_BUNDLE_IDENTIFIER = invalid.example.questify.ios`. `QUESTIFY_API_BASE_URL` is empty. `QUESTIFY_SESSION_REALM` is empty. |

The Questify target's base configuration, Debug and Release, is `Config/Base.xcconfig`. `tools/generate_project.py` wires that file only. `Config/China.Production.xcconfig` is not the target base configuration.

## Missing

- Bundle id `com.chengyinhub.chengyinApp`. It is not set on `Config/China.Production.xcconfig`. A search of the tree finds no occurrence. It is not set only on that file; it is unset.
- Team `9VHY8N755R`. It is not set on `Config/China.Production.xcconfig`. A search of the tree finds no occurrence. No committed xcconfig sets `DEVELOPMENT_TEAM`. `Config/Local.xcconfig.example` leaves the team and bundle id as comments. `Config/Local.xcconfig` and `Config/Local.*.xcconfig` are gitignored and are not in this checkout.
- `Config/China.Production.xcconfig` does not assign `PRODUCT_BUNDLE_IDENTIFIER` or `DEVELOPMENT_TEAM`. It includes `China.xcconfig`, clears `QUESTIFY_API_BASE_URL` and `QUESTIFY_SESSION_REALM`, optionally includes the gitignored local file, then sets `QUESTIFY_DEPLOYMENT_ENVIRONMENT = production` and `QUESTIFY_MARKET = CN`.
- Production API URL. `Config/Base.xcconfig` leaves `QUESTIFY_API_BASE_URL` empty. `Config/China.Production.xcconfig`, `Config/UnitedStates.xcconfig`, and `Config/UnitedStates.Production.xcconfig` also leave it empty. No US API URL is recorded here.
- `NSPhotoLibraryUsageDescription` is not in `Config/Info.plist` and is not an `INFOPLIST_KEY`. The add-only key above is the installed photo permission. This note does not add a read-library sentence. `Tests/ContractChecks/test_roam_share_photo_save.py` asserts the read key stays out of `Config/Info.plist`.
- ATS exceptions. `Config/Info.plist` and the xcconfig files contain no `NSAppTransportSecurity`, `NSAllowsArbitraryLoads`, `NSAllowsLocalNetworking`, or `NSExceptionDomains`. `Config/Base.xcconfig` says there is no ATS relaxation. The China and United States development profiles set a loopback test address and say that no ATS exception is installed.
- Always-location and background-mode keys. `NSLocationAlwaysUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, and `UIBackgroundModes` are not in `Config/Base.xcconfig`, `Config/Info.plist`, `Resources/InfoPlist.xcstrings`, or `Resources/PrivacyInfo.xcprivacy`.
- Archive signing. No distribution certificate, provisioning profile, or team is in the tree. Device and US compiles in `.github/workflows/native-ios.yml` pass `CODE_SIGNING_ALLOWED=NO`. `Config/Base.xcconfig` sets `CODE_SIGN_STYLE = Automatic` and does not set `CODE_SIGNING_ALLOWED`, `DEVELOPMENT_TEAM`, or a signing identity.

Other committed bundle ids stay placeholders: `invalid.example.questify.ios.appunittests` in `Config/AppUnitTests.xcconfig`, and `invalid.example.questify.ios.uitests` on the UI-test target. GLTFKit2 uses `com.metalbyexample.gltfkit2` with an empty `DEVELOPMENT_TEAM` in its own project.

## Account deletion

Whether account deletion ships is an owner decision.

The settings row may exist. On the unconfigured composition (`RegionalLaunchConfiguration.composition` uses `reviewed: nil`) an empty `QUESTIFY_API_BASE_URL` leaves `apiConfiguration` nil, so `AppSession.accountComplianceCoordinator` is nil. Settings then shows the blocked 账号注销 row. Its destination does not call apply.

No navigation route deletes an account. `NativeNavigationContract` accepts team join, the content source paths, `/badge`, `/door`, and the merchant public-home and team-invite paths. None of those delete an account.

`POST api/user/deregister/apply` exists in the compliance client. `AccountComplianceCompositionRoute` accepts it only when a reviewed deployment has `productionGatesEnabled` and the market is China. `isAccountComplianceEnabled` is that same China production-gate condition. The shipped composition is unconfigured, so that allowlist is off. This branch does not add a route that deletes an account.

## Signing

Archive signing is owner-only. This branch does not sign.
