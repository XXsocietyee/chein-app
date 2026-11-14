# Task 68 — release-config audit

Branch `ui/cur-release-config`. Base `origin/ui/main` `3ac970ec20191014b4b9a8779a3a94b961e99c9c`.

The build already reads every release key that exists. No plist, entitlement, or xcconfig file was edited. The only additions are this receipt and `docs/release/aasa.json`.

`swiftc` is not installed. No typecheck, no `swift test`, no `xcodebuild`. `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` were run. `docs/release/contract-failing-baseline.txt` was not edited. `App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, and `App/AppCompositionRoot.swift` were not edited. `ReviewedAreaSwitch` was not redeclared. `www.chengyinhub.com` was not added as an associated domain and stays closed for money.

## What the build reads

`tools/generate_project.py` sets `CODE_SIGN_ENTITLEMENTS = Config/Questify.entitlements` on the Questify target for Debug and Release. Debug's base configuration is `Config/Base.xcconfig`. Release's base configuration is `Config/Release.xcconfig`, which includes `Config/China.Production.xcconfig`. Both inherit `GENERATE_INFOPLIST_FILE = YES` and `INFOPLIST_FILE = Config/Info.plist`, so Xcode merges that file with every `INFOPLIST_KEY_*` setting.

## Info.plist keys that are used

Recorded only. Each key below is already in the file or build setting the target compiles.

| Key | Where the build reads it | Who uses it |
|---|---|---|
| `QuestifyMarket` | `Config/Info.plist` `$(QUESTIFY_MARKET)` and `INFOPLIST_KEY_QuestifyMarket` in `Config/Base.xcconfig` (CN), `Config/China.xcconfig` (CN), `Config/UnitedStates.xcconfig` (US). Release sets `QUESTIFY_MARKET = CN`. | `App/RegionalLaunchConfiguration.swift` |
| `QuestifyAPIBaseURL` | `Config/Info.plist` `$(QUESTIFY_API_BASE_URL)` and `INFOPLIST_KEY_QuestifyAPIBaseURL`. Base leaves the URL empty. `Config/China.Production.xcconfig` and `Config/Release.xcconfig` set `https://www.chengyinhub.com/prod-api/`. Development profiles set `http://127.0.0.1:8099`. Staging leaves it empty. | `App/RegionalLaunchConfiguration.swift`, `App/ReviewedAreaSwitch.swift` |
| `QuestifySessionRealm` | `Config/Info.plist` `$(QUESTIFY_SESSION_REALM)` and `INFOPLIST_KEY_QuestifySessionRealm`. Release realm is `cn-prod`. | `App/RegionalLaunchConfiguration.swift` |
| `QuestifyCityGameRegion` | `Config/Info.plist` and `INFOPLIST_KEY_QuestifyCityGameRegion`. Empty, except Debug `gaps-a-test` in `Config/Base.xcconfig`. | `App/ReviewedCityGameLease.swift` |
| `QuestifyDeploymentEnvironment` | `Config/Info.plist` and `INFOPLIST_KEY_QuestifyDeploymentEnvironment`. Values are `unconfigured`, `development`, `staging`, or `production` from the xcconfig chain. `Config/Base.xcconfig` says this is informational and cannot issue a capability. | No Swift reader. Left in place. This is not `aps-environment`. |
| `NSPhotoLibraryAddUsageDescription` | `Config/Info.plist`, English matching `Resources/InfoPlist.xcstrings` (en and zh-Hans). | System prompt and `App/RoamSharePhotoSaveModel.swift` |
| `NSCameraUsageDescription` | `INFOPLIST_KEY_NSCameraUsageDescription` in `Config/Base.xcconfig`. Same English sentence in `Resources/InfoPlist.xcstrings`, plus zh-Hans. | System prompt. `App/NativeQRScanner.swift`, `App/RoamStampCameraView.swift`, `App/PlayKitCameraPresentation.swift`, `App/PlayKitSpatialRevealView.swift`, `App/PlayNativeDeviceProvider.swift` |
| `NSMotionUsageDescription` | `INFOPLIST_KEY_NSMotionUsageDescription` in `Config/Base.xcconfig`, plus the string catalog. | `App/IPhonePedometerProvider.swift`. Play-kit acceleration checks this key in `App/PlayKitNativeSensorProvider.swift`. |
| `NSLocationWhenInUseUsageDescription` | `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` in `Config/Base.xcconfig`, plus the string catalog. | `App/RuntimeNativeLocationProvider.swift`, `App/PersonalLocationShareHost.swift`, `App/CloudB3Production.swift`. Play-kit heading checks this key. |
| `NSMicrophoneUsageDescription` | `INFOPLIST_KEY_NSMicrophoneUsageDescription` in `Config/Base.xcconfig`, plus the string catalog. | Play-kit sound peak checks this key. |
| `UIBackgroundModes` = `location` | `Config/Info.plist` only. Not an `INFOPLIST_KEY_*`. `tools/archive_unsigned.py` forbids `INFOPLIST_KEY_UIBackgroundModes` and allows exactly this one mode. | iOS background location, and `SessionBackgroundLocationTracker.declaresBackgroundLocationMode` |
| `UILaunchScreen` | `Config/Info.plist`: `UIColorName` = `LaunchBackground`, `UIImageName` = `LaunchMark`. Both assets are in `App/Assets.xcassets`. | System launch screen |
| `CFBundleDisplayName` = `Questify` | `INFOPLIST_KEY_CFBundleDisplayName` in `Config/Base.xcconfig` | Home screen. `Core/SettingsAboutContracts.swift` |
| `CFBundleShortVersionString` / `CFBundleVersion` | Generated. `MARKETING_VERSION = 0.1.0`, `CURRENT_PROJECT_VERSION = 1` in `Config/Base.xcconfig`. | `Core/PlayContentCompatibility.swift` reads the short version. Settings reads both. |
| `CFBundleIdentifier` | Debug `invalid.example.questify.ios` from `Config/Base.xcconfig`. Release `com.chengyinhub.chengyinApp` from `Config/Release.xcconfig`. Release team `DEVELOPMENT_TEAM = 9VHY8N755R`. | Signing |

Scene manifest generation and the iPhone/iPad orientation keys are `INFOPLIST_KEY_UIApplicationSceneManifest_Generation` and `INFOPLIST_KEY_UISupportedInterfaceOrientations_*` in `Config/Base.xcconfig`. The system reads them. No file was changed.

Read by Swift, with no value in the file the build reads. Not added, because the repo does not contain a value to copy:

- `CYStampImageOrigins`. `App/AppSession.swift` passes `Bundle.main` into `RetainedImageOrigin.configured`. The comment in `Core/RetainedImageContracts.swift` says extra HTTPS origins are comma-separated deployment config and nothing is hardcoded. The key is absent from `Config/Info.plist` and every `Config/*.xcconfig`. The API origin is still taken from the base URL. No origin string was invented.
- `QUESTIFY_API_BASE_URL` as an Info dictionary name. `App/ExternalGameSession.swift` looks that name up only when it has no session URL. The build setting of that name is already copied into `QuestifyAPIBaseURL`. Adding the all-caps name to the plist would be a second copy, not a missing build input. It was not added, so that fallback stays empty.

Present on purpose and left out:

- `NSPhotoLibraryUsageDescription` stays out of `Config/Info.plist`. `tools/archive_unsigned.py` rejects it.
- `NSLocationAlwaysUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` are absent. When-in-use is the only location purpose string.
- `ITSAppUsesNonExemptEncryption` is unset. No export-compliance answer was invented.

## Entitlements

Recorded only. `Config/Questify.entitlements` is exactly `com.apple.developer.applesignin` = `[Default]`. Debug and Release both sign with that file. No other entitlement was added.

### Push

No `aps-environment` key. The file does not say `development` and it does not say `production`. Debug and Release share the file, so the two configurations do not differ. `registerForRemoteNotifications` is not called. Local notification code uses `UNUserNotificationCenter`. `PushTapRouter` defaults to no route keys. `MPNotificationTapRouter.routeKeys` is the payload key `page`, which is not an entitlement.

### Associated domains

`com.apple.developer.associated-domains` is not in the entitlement file. `UniversalLinkConfiguration.associatedDomainEntitlements` and `verifiedHTTPSOrigins` are `[]` in `Core/UniversalLinkParser.swift`. `App/AppSession.swift` builds `NativeEntryLinkPolicy(verifiedHTTPSOrigins: [])`. No `applinks:` value was copied in. `www.chengyinhub.com` was not added.

### Location background

The capability the system reads is `UIBackgroundModes` = `location` in `Config/Info.plist`. That key is not in `Config/Questify.entitlements`. `Config/Base.xcconfig` only comments that the mode lives in Info.plist. It does not set a location entitlement, and it does not set `INFOPLIST_KEY_UIBackgroundModes`. The comment in `App/SessionBackgroundLocationTracker.swift` that says Base.xcconfig declares the mode is a comment. The declaration the build reads is the Info.plist array. The background-location entitlement was not added.

`SessionBackgroundLocationTracker` calls `requestWhenInUseAuthorization` and sets `allowsBackgroundLocationUpdates` only while a background hold exists and the Info.plist mode is present. `App/PersonalLocationShareHost.swift` sets `allowsBackgroundLocationUpdates = false`.

## ATS exceptions

Recorded only. None are installed.

`NSAppTransportSecurity`, `NSAllowsArbitraryLoads`, `NSAllowsArbitraryLoadsForMedia`, `NSAllowsArbitraryLoadsInWebContent`, `NSAllowsLocalNetworking`, and `NSExceptionDomains` are absent from `Config/Info.plist`, `Config/*.xcconfig`, `Resources/InfoPlist.xcstrings`, `Resources/PrivacyInfo.xcprivacy`, and `Vendor/GLTFKit2/GLTFKit2/Info.plist`. `Config/Base.xcconfig` says there is no ATS relaxation. `Config/China.Development.xcconfig` and `Config/UnitedStates.Development.xcconfig` set `QUESTIFY_API_BASE_URL` to `http://127.0.0.1:8099` and say that no ATS exception is installed. No exception was added for that loopback URL.

## URL schemes

Recorded only. `CFBundleURLTypes` is not in `Config/Info.plist`. `LSApplicationQueriesSchemes` is not in the plist or the xcconfigs. No scheme was registered.

`CheinDeepLink.scheme` is `chein`. `App/QuestifyApp.swift` forwards opened URLs to `receiveNativeURL`, which classifies `chein://` in process. The OS will not deliver that scheme until `CFBundleURLTypes` exists. The key is not in the tree, and `Tests/ContractChecks/test_universal_link_associated_domains.py` requires it to stay absent. It was not added.

`WeChatSDKConfiguration` accepts an app id that starts with `wx` and a callback list, and the type says no live AppID or universal-link route is supplied. No `wx` scheme was copied into the plist.

`MiniProgramPathTranslatorSnapshot` in `App/DeepLinkToMiniProgramPathTranslatorSectionView.swift` lists `/play/detail`, `/roam/stamp-album`, `/profile/badge-wall`, and `/growth/leaderboard`. Those strings are not parsed by `NativeEntryLinkPolicy` or `UniversalLinkParser`. They were not registered and they are not in `docs/release/aasa.json`.

## apple-app-site-association

Added `docs/release/aasa.json`. No other file was changed for this.

Paths are the https paths `UniversalLinkParser` forwards to `NativeEntryLinkPolicy` (`Core/UniversalLinkParser.swift`, `Core/NativeEntryRouting.swift`, `Core/NativeNavigationCompletion.swift`, `Core/PublicCatalogHost.swift`, `Core/DoorReferralContracts.swift`, `Core/MiniProgramPageLink.swift`). `UniversalLinkParser` accepts a path only when it is a single slash-separated sequence of ASCII letters, digits, hyphens, and underscores. Every path below passes that rule.

| Path | Parser |
|---|---|
| `/door` | `DoorLinkPolicy` |
| `/team/join` | `NativeNavigationContract` |
| `/pages/team/join/index` | `NativeNavigationContract` |
| `/badge` | `NativeNavigationContract` |
| `/merchant/team` | `NativeEntryLinkPolicy`, one `invite` query item |
| `/merchant/public-home/<id>` | `NativeEntryLinkPolicy`, one positive canonical integer, no query |
| `/merchant/public-home/member/<id>` | `NativeEntryLinkPolicy`, one positive canonical integer, no query |
| `/catalog`, `/catalog/list`, `/catalog/filters`, `/catalog/info` | `PublicCatalogLink` |
| `/pages/activity/detail/index` | `NativeContentTarget.activity`, one `id` |
| `/pages/club/detail/index` | `NativeContentTarget.club`, one `id` |
| `/pages/topic/index/index` | `NativeContentTarget.topic`, one `id` |
| `/pages/templatedetail/templatedetail` | `NativeContentTarget.template`, one `id` |
| `/pages/square/detail/index` | `NativeContentTarget.post`, one `id` |
| `/subpackageRoam/poi-detail/index` | `NativeContentTarget.poi`, one `id` |
| `/subpackageRoam/session/index` | `NativeContentTarget.roamSession`, one `id` |
| `/subpackageA/pages/video-bounty/index` | `MiniProgramPageLink.reviewedPages` |
| `/subpackageMember/market/passes/index` | same |
| `/subpackageMember/market/pass/index` | same |
| `/subpackageMember/market/gift/index` | same |
| `/subpackageMember/market/membership/index` | same |
| `/subpackageMember/market/library/index` | same |
| `/subpackagePass/reveal/index` | same |
| `/subpackageJourney/pages/landing/index` | same |
| `/subpackageJourney/pages/seats/index` | same |
| `/subpackageJourney/pages/promo/index` | same |
| `/subpackageJourney/pages/report/index` | same |
| `/subpackageJourney/pages/settle/index` | same |

The two merchant id shapes are the only `*` patterns. AASA cannot require a positive canonical integer. The parser still rejects every other segment. Query rules stay in the parser. A path-only component is used so a handled query is not dropped. `/pages/team/join/index` is included because both the `code` form and the retired `teamId` form return an intent.

Not in the file, because the parser does not type them:

- `/pages/templatedetail/topic-detail/index`. `PublicContentShareLink.topicTemplate` stays nil and the copy text is the path only.
- `/play/detail`, `/roam/stamp-album`, `/profile/badge-wall`, `/growth/leaderboard`.
- Any `chein://` path. A custom scheme is not a universal link.
- WeChat callback paths. No concrete host or path is configured.

`appIDs` is `9VHY8N755R.com.chengyinhub.chengyinApp`, the Release team and bundle id in `Config/Release.xcconfig`. The Debug placeholder `invalid.example.questify.ios` is not written as an app id.

### Where to host it

Do not host this file yet. The app claims no associated domain, so there is no host that iOS will check.

When an owner later supplies one host, serve this document at `https://<that-host>/.well-known/apple-app-site-association` with `Content-Type: application/json` and no redirect. That host is not in the repo. `UniversalLinkConfiguration.verifiedHTTPSOrigins` is empty, and `receiveUniversalLink` uses `nativeEntryLinkPolicy`, which accepts no origin.

Do not host it on `www.chengyinhub.com`. That host is the China production API host (`Config/Release.xcconfig`, `ReviewedAreaSwitch.productionHost`). It is not an associated domain. `PublicContentShareLink` can format `https://www.chengyinhub.com` plus a path the parser already types, and it does not write the allowlist. The running policy still accepts nothing on that host. This audit does not open it.

## Push entitlement environments

Recorded only.

| Configuration | Entitlements file | `aps-environment` |
|---|---|---|
| Debug | `Config/Questify.entitlements` | absent |
| Release | `Config/Questify.entitlements` | absent |

Neither `development` nor `production` is set. No push environment was added.
