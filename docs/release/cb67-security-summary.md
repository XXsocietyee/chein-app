# CB67 — Security summary

Checked against `origin/rc/20261108` at `88e981b3308558939e405606cd731b4b29fc9499` (2026-11-09 PT). Marketing version stays `0.1.0`. Build stays `1` (`Config/Base.xcconfig`: `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`). Source inspection only. This note does not sign, upload, deploy, or open a socket.

Companion notes in this branch:

- Threat model: `docs/release/cb67-threat-model.md`
- Privacy data-flow map: `docs/release/cb67-privacy-data-flow.md`

Prior notes, read and not contradicted:

- `origin/cursor/cb38` `daef60be85ec2748587e774c4311192d22308120` (`docs/release/cb38-security.md`), written against `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. Its four code edits are not in this tree.
- `origin/cursor/cb55` `b75bdd223396844fcc6592e185b18c9d0cad68aa` (`docs/release/cb55-privacy.md`), whose parent is this same base. Its manifest edit (`3B52.1`) is not in this tree.

## Posture

The target base configuration is unconfigured. `QUESTIFY_API_BASE_URL` and `QUESTIFY_SESSION_REALM` are empty, and the bundle id is `invalid.example.questify.ios`. `ReviewedMarketLaunch.admitsShippedChina` is false for that empty URL, so `RegionalLaunchConfiguration.composition` is `makeComposition(reviewed: nil, build: .current)`. Password login, bank-card withdrawal, and virtual goods stay off. `reviewedMarketDeployment` keeps `productionGatesEnabled: false`.

`Resources/PrivacyInfo.xcprivacy` sets `NSPrivacyTracking` to false and `NSPrivacyTrackingDomains` to an empty array. Every collected-type row keeps tracking false and purpose App Functionality. No tracking SDK is declared or added here. A source search of Swift, Objective-C, and plist files found no `ATTrackingManager`, `ASIdentifierManager`, `AdSupport`, `SKAdNetwork`, `identifierForVendor`, Firebase, Crashlytics, Sentry, Amplitude, Mixpanel, or Bugsnag.

MetricKit is not subscribed. `Core/CrashResilienceAndMetricKitDiagnosticsAudit.swift` and `App/CrashResilienceAndMetricKitDiagnosticsSectionView.swift` are local descriptors and a SwiftUI section. This tree has no `import MetricKit` and no `MXMetricManager`. No crash-log or performance-metric upload was proven. The section title is not a subscription.

No privacy-policy URL is recorded. `https://www.chengyinhub.com/prod-api/` in `Config/China.Production.xcconfig` and `ReviewedMarketLaunch.chinaProductionBaseURL` is an API build input, not a privacy policy. That xcconfig is not the target base configuration (`docs/release/ship-prep.md`).

## Controls already in this tree

| Control | Where |
|---|---|
| Session token in the Keychain | `App/KeychainTokenStore.swift`. Generic password, service from `RegionalSessionStorageScope`, account `session-token`, `kSecAttrSynchronizable` false, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` on write. No access-group override. `Config/Questify.entitlements` is Sign in with Apple only. |
| Token stays out of defaults | Session `UserDefaults` holds language, reduced motion, consent versions, and the boolean `restoreBlockedKey`. The flag is not the token. |
| Authorization header | `Core/AuthRequestBuilder.swift` sends the token only when it is non-empty printable ASCII, and sets `reloadIgnoringLocalCacheData`. |
| ATS default | `Config/Info.plist` has no `NSAppTransportSecurity` dictionary. No xcconfig sets `NSAllowsArbitraryLoads`, `NSAllowsArbitraryLoadsForMedia`, `NSAllowsArbitraryLoadsInWebContent`, `NSAllowsLocalNetworking`, or `NSExceptionDomains`. |
| Inbound links fail closed | `AppSession` builds `NativeEntryLinkPolicy(verifiedHTTPSOrigins: [])`. No associated-domains entitlement and no `CFBundleURLTypes`. `PushTapRouter()` defaults to no route keys. |
| Location is when-in-use | `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` only. `App/PersonalLocationShareHost.swift` sets `allowsBackgroundLocationUpdates = false` and requests when-in-use authorization. No `UIBackgroundModes`. |
| Pasteboard helper | `App/LocalPasteboard.swift` writes UTF-8 plain text, `localOnly: true`, lifetime 120 seconds. |
| WeChat pasteboard grant | `WeChatSDKConfiguration.pasteboardReadApproved` defaults to false. `AppSession.weChatSDKConfiguration` is nil. |
| Account deletion on this composition | The settings row is the blocked cancellation notice. It does not call `POST api/user/deregister/apply`. See `docs/release/ship-prep.md`. |
| Vendored model kit | `Vendor/GLTFKit2/GLTFKit2/PrivacyInfo.xcprivacy` has tracking off and empty collected-data and accessed-API arrays. |

## Residuals on this tree

These match what CB38 found before its edits, or what CB38 left unchanged. This branch does not apply the CB38 edits.

| Residual | This tree | Recorded fix, not merged here |
|---|---|---|
| Team invite copy is `localOnly` with no expiry. | `App/TeamComponents.swift` | `origin/cursor/cb38` routes it through `LocalPasteboard`. |
| Approved-media link copy is `localOnly` with no expiry. | `App/OwnMediaApprovedLinkCopyButton.swift` | Same branch. |
| Club AI promo copy is `localOnly` with no expiry, and success reads `UIPasteboard.hasStrings`. | `App/ClubAIDesignFeedbackViews.swift`. That is the only `hasStrings` hit in Swift sources. | Same branch. `hasStrings` reads pasteboard content and can raise the system paste notice. |
| Search-history Keychain queries do not set `kSecAttrSynchronizable`. Insert uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. | `App/SearchMapComponents.swift` | Same branch sets `synchronizable` false. It does not migrate the accessibility class. |
| Team invite `ShareLink(item: code)` can hand the code to another app. | `App/TeamComponents.swift` | CB38 left this. It is a product cut. |
| Selectable text uses the system copy command. | `.textSelection(.enabled)` on body text, including contact text in `App/CooperationInviteDetailView.swift`. | CB38 left this. |
| Session token has no biometric ACL. `kSecUseDataProtectionKeychain` is not set on that store. | `App/KeychainTokenStore.swift` | CB38 left both. A new query attribute could miss an item already stored for a signed-in user. |
| File Timestamp reason `3B52.1` is not in this tree's manifest. | `Resources/PrivacyInfo.xcprivacy` lists `C617.1` only. The document-picker and security-scoped `fstat` sites CB55 names are in this tree. | `origin/cursor/cb55` adds `3B52.1`. This branch does not edit the manifest. |

Search history still does not cap each string before `JSONDecoder`. `SearchHistoryPolicy` keeps ten strings. CB38 left that.

## Placeholders

This note does not print a legal sentence, a support address, or a filing number.

| Item | Token in this note | What the tree does |
|---|---|---|
| Legal text | `[LEGAL_TEXT_PENDING]` | `SettingsSourceLegalCatalog.document` returns `.missing(.pendingSourceText)` for the China privacy policy while `privacyPolicyApproved` is false. `SettingsBundledLegalReader.defaultPrivacyPolicyApproved` is false. A document constant in that file is returned only when the flag is true. This note does not quote it. |
| Support contact | `[SUPPORT_CONTACT_PENDING]` | `docs/withdrawal-support-configuration.md` says the withdrawal reader embeds no production contact. This note does not copy a telephone number or street address out of the legal catalog. |
| China ICP number | `[ICP_FILING_NUMBER_PENDING]` | `VersionedLocaleDisplay.legalGateStatus(.icpFiling)` is `NOT_RUN`. No filing number is written here. |

`Tests/CoreTests/SettingsNativeTests.swift` expects the China privacy-policy document to be `.missing(.pendingSourceText)`.

## Gates left as they are

- Password login: `AppSession.passwordLoginCompiledIn` is true only under `#if DEBUG`. `login(username:password:)` returns `auth.notConfigured` otherwise.
- Bank-card withdrawal: `makeBankWithdrawalContext` stays behind `.bankPrepare` and `.bankConsentRead`.
- Virtual goods: empty `storeKitBundleID` and `storeKitProductIDs` keep native StoreKit launch off (`Core/WorkshopCommerceContracts.swift`).
- US API URL: `Config/UnitedStates.Production.xcconfig` leaves the URL and realm empty. No US host is invented.
- Version: `0.1.0` (`1`).

## What this note does not claim

- A Swift compile, a test run, a simulator run, a device Keychain check, or an Xcode privacy report. FP-O8 in `docs/parity/fix-plan.md` stays with the owner.
- A certificate pin.
- A full audit of every log call.
- That the nutrition-label draft in CB55 has been submitted. Tracking stays No on that draft. Types CB55 left unverified stay unverified here.
- That MetricKit is subscribed, that a tracking SDK is present, or that a privacy-policy URL exists.
- `tools/current_ci_manifest.json` was not refreshed. No Swift, privacy manifest, xcconfig, or workflow file was edited.
