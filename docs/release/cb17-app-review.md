# CB17 — App Store review checklist

Checked against `origin/rc/20261108` at `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` (2026-11-08 PT).

This file is a checklist. It does not submit a build, sign an archive, deploy a backend, restyle a screen, or refresh `tools/current_ci_manifest.json`. `RegionalLaunchConfiguration.shippedComposition` stays `makeComposition(reviewed: nil, build: .current)` unless the build already matches the reviewed China host, bundle, and realm. The base configuration does not: `Config/Base.xcconfig` has an empty `QUESTIFY_API_BASE_URL`, an empty `QUESTIFY_SESSION_REALM`, and `PRODUCT_BUNDLE_IDENTIFIER = invalid.example.questify.ios`.

Status words are only `present`, `gap`, or `owner decision`.

## Account deletion — Guideline 5.1.1(v)

| Item | Status | Evidence |
|---|---|---|
| Settings row on the unconfigured composition | present | `App/SettingsSupportSections.swift` shows `SettingsUnavailableFeature` when `AccountComplianceCoordinator` is nil. The account-deletion row opens `SettingsUnavailableFeatureView`, which shows the blocked message and the cancellation notice. `tools/check_account_deletion_path.py` reads that path and does not call apply. |
| Completing deletion on that composition | gap | `AppCompositionRoot.isAccountComplianceEnabled` is true only when a reviewed deployment has `productionGatesEnabled` and the market is China. The unconfigured composition leaves the coordinator nil, so the row does not send `POST api/user/deregister/apply`. |
| Whether the blocked row is enough to ship | owner decision | `docs/release/ship-prep.md` already leaves that call open. This file does not close it. |

## UGC report and block — Guideline 1.2

| Item | Status | Evidence |
|---|---|---|
| Square post and comment report | present | `App/SquareDetailView.swift` opens `SquareReportView` for a post and for a comment. |
| Square post and comment block | gap | The same menu has a block button. It only presents `square.block.notAvailable`: nothing is blocked, and the copy points the person to chat. |
| IM report, block, and unblock | present | `App/MessagingHistoryView.swift` offers report, block, and unblock. `Core/ChannelDiscordMessaging.swift` names `api/im/report`, `api/im/block`, and `api/im/unblock`. `App/IMConversationSafetyViews.swift` confirms block and unblock before the write. |
| Club channel report | present | `App/ClubChannelMessagingView.swift` reports a channel and a message. The channel report uses `api/club/governance/cases/report`. |
| Club channel block that survives without a permitted IM writer | gap | `blockUser` calls `api/im/block` only when an IM safety writer permits the action; otherwise it throws `serviceUnavailable`. `App/ClubSafetyComposition.swift` still installs `UserDefaultsChannelBlockedUsersStore`. |
| Team report | present | `App/TeamOrientBoardView.swift` has a reason picker and a submit action. |
| External game report and block | present | `App/ExternalGameImportView.swift` reports the package and blocks the package and its creator. |
| Friend blacklist | present | `App/NativeFriendHomeView.swift` opens `NativeBlacklistView`. `Core/NativeBlacklistService.swift` names `api/native/blacklist/list`, `current`, `receipt`, `unblock`, and `settle`. |
| Topic detail, activity reviews, club post discussion comments, member avatars | gap | Those four files have no report or block entry (`App/TopicDetailView.swift`, `App/ActivityReviewsSection.swift`, `App/ClubPostDiscussion.swift`, `App/MemberIdentityAvatarView.swift`). `docs/parity/fix1-ugc-report-gaps.md` still matches that reading. |
| Purchased-mod report that submits on the shipped composition | gap | `App/ModOwnedContentReportView.swift` is a screen. Its own copy says an unconfigured write approval can only read, and it does not send the report. |
| Settings “Support and safety” row | present | `App/SettingsView.swift` inserts `SettingsSupportSafetyEntry`. The clause in `SettingsSupportSafetyCopy` is draft copy. |
| UGC policy | owner decision | See the owner-decision lines. This file does not set what is objectionable, the moderation SLA, or who acts on a report. |

## Sign in with Apple — Guideline 4.8

| Item | Status | Evidence |
|---|---|---|
| Entitlement on the app target | present | `Config/Questify.entitlements` is `com.apple.developer.applesignin` = `[Default]` and nothing else. Questify Debug and Release set `CODE_SIGN_ENTITLEMENTS` to that file. |
| Visible Sign in with Apple control on the shipped composition | gap | `App/AuthChannelView.swift` shows `AuthChannelAppleButton` only when `appleConfigurationVerified` is true. `Core/AuthChannelCoordinator.swift` defaults that flag to false, and `start` rejects `.appleNotConfigured` until it is true. |
| WeChat login beside that control | gap | `App/LoginView.swift` shows `WeChatAppAuthSection` for the China market after consent. `Core/WeChatAppAuth.swift` keeps `canStart` false unless the gate, the session, an adapter, and a service all permit it, and the section then shows `auth.wechat.notConfigured`. Phone sign-in sits behind the other-channels sheet. A live third-party login without a visible Apple control is not what this composition shows, and the Apple control is not visible either. |
| App ID capability | owner decision | The entitlement file does not enable Sign in with Apple on the App ID. That switch is App Store signing. |

## Payments and IAP — Guideline 3.1.1

| Item | Status | Evidence |
|---|---|---|
| StoreKit launcher for a digital mod | present | `Core/WorkshopStoreKitLauncher.swift` returns a purchaser only for `APPLE_STOREKIT`, `PRODUCTION`, a matching bundle id, and a non-empty product list. Otherwise it returns nil. The purchase path asks for a non-consumable product. |
| WeChat Pay driver | present | `Core/WeChatSDKPaymentAdapter.swift` installs no App ID, merchant id, or SDK by default. `allowed` defaults to false, and `isConfigured` also requires the China market and a player or club role. |
| Shipped composition payment writes | gap | `App/RegionalLaunchConfiguration.swift` says password login, bank withdrawal, virtual goods, and payment or payout writes are not switched on by `shippedComposition`. |
| Digital-mod wire that also accepts WeChat | present | `Core/ModReleaseApplicationContracts.swift` treats a priced `DIGITAL_MOD` as valid on `APPLE_STOREKIT`, and on `WECHAT_APP` when the market is CN and the currency is CNY. |
| Payment route confirmation | owner decision | See the owner-decision lines. This file does not choose StoreKit, WeChat Pay, or another route for a digital good, a wallet top-up, or an offline charge. |

## Privacy manifest and nutrition labels

| Item | Status | Evidence |
|---|---|---|
| App privacy manifest | present | `Resources/PrivacyInfo.xcprivacy`. `NSPrivacyTracking` is false and `NSPrivacyTrackingDomains` is empty. |
| Vendored GLTFKit2 manifest | present | `Vendor/GLTFKit2/GLTFKit2/PrivacyInfo.xcprivacy`. Tracking is off. Collected-data and accessed-API arrays are empty. |
| Nutrition-label draft | present | The draft below copies the app manifest. It is not filed in App Store Connect. |
| Nutrition labels filed in App Store Connect | gap | No Connect answer is in this repo. This file does not file one. |

Draft, tracking off. Each collected type is linked to the user, not used for tracking, and the purpose is App Functionality:

| Manifest type | Draft label |
|---|---|
| `NSPrivacyCollectedDataTypePhoneNumber` | Phone Number |
| `NSPrivacyCollectedDataTypeUserID` | User ID |
| `NSPrivacyCollectedDataTypePreciseLocation` | Precise Location |
| `NSPrivacyCollectedDataTypePhotosorVideos` | Photos or Videos |
| `NSPrivacyCollectedDataTypeAudioData` | Audio Data |
| `NSPrivacyCollectedDataTypeOtherUserContent` | Other User Content |
| `NSPrivacyCollectedDataTypeName` | Name |
| `NSPrivacyCollectedDataTypeEmailAddress` | Email Address |
| `NSPrivacyCollectedDataTypePhysicalAddress` | Physical Address |
| `NSPrivacyCollectedDataTypePurchaseHistory` | Purchase History |
| `NSPrivacyCollectedDataTypeFitness` | Fitness |
| `NSPrivacyCollectedDataTypeDeviceID` | Device ID |

Required-reason APIs in the same manifest: UserDefaults `CA92.1`, File Timestamp `C617.1`, System Boot Time `35F9.1`.

The draft does not add a type the manifest omits, and it does not remove one. It is not a privacy-policy URL.

## Age rating

| Item | Status | Evidence |
|---|---|---|
| App Store age-rating questionnaire | gap | No questionnaire answer is committed. This file does not pick 4+, 9+, 12+, 17+, or an adult rating. |
| External-game package rating gate | present | `Core/ExternalGameImport.swift` accepts only `4+`, `9+`, `12+`, and `17+`. Any other string, including `18+`, fails `ExternalGameContentRating` and throws `invalidContentRating`. That gate is not the app’s age rating. |
| “Not for users under 18” in the bundled agreement | owner decision | That sentence is legal text. This file does not adopt it as the age rating. |

## Review demo account — Guideline 2.1

| Item | Status | Evidence |
|---|---|---|
| Reviewer-scenario audit | present | `Core/AppStoreReviewDemoAccountAndFixtureReadinessAudit.swift` names four scenarios: guest browse, authenticated player, merchant, and club admin. It is an in-memory check. It does not create a login. |
| Demo username, password, and seeded account | gap | No review username, password, or seeded backend fixture is in the tree. `docs/owner-plan/gap-pl-3.md` records the same limit for CT13.g. |
| Creating that account on a server | owner decision | Seeding it is a backend deploy. This file does not create the account and does not invent credentials. |

## Owner decisions

These lines are open. This file does not decide them.

- US API URL — owner decision. `Config/Base.xcconfig`, `Config/UnitedStates.xcconfig`, and `Config/UnitedStates.Production.xcconfig` leave `QUESTIFY_API_BASE_URL` empty. No US host is written here.
- Payment route confirmation — owner decision. The digital-mod contract accepts `APPLE_STOREKIT` and, for CN/CNY, `WECHAT_APP`. The StoreKit launcher and the WeChat Pay driver stay off unless a reviewed approval turns them on. This file does not confirm the route.
- Legal text — owner decision. `Core/SettingsSourceLegalCatalog.swift` can show the China user agreement and the cancellation notice. The privacy policy stays `.pendingSourceText` until `privacyPolicyApproved` is true. A non-China market returns `.regionalTextNotProvided`. This file does not approve, rewrite, or publish that text.
- Support contact — owner decision. `App/WithdrawalSupportContactView.swift` shows `withdrawal.support.unconfigured` when no reviewed reader is supplied. This file does not invent an address, a phone number, or a URL.
- UGC policy — owner decision. `SettingsSupportSafetyCopy.clause` is draft copy. This file does not set the objectionable-content rules, the moderation SLA, or who staffs the queue.
- China ICP number — owner decision. `Core/VersionedLocaleDisplay.swift` keeps `LegalGate.icpFiling` on the `NOT_RUN` legal-gate line. No ICP number is in the tree. This file does not write one.
- Backend deploy — owner decision. This file does not deploy.
- A further CI ledger refresh — owner decision. `tools/current_ci_manifest.json` is not refreshed.
- App Store signing — owner decision. This file does not sign, upload, set a team, replace the placeholder bundle id, or add a certificate or profile.
- Deleting anything outside /private/tmp — owner decision. This file deletes nothing.

## Not done here

Not submitted. Not signed. Not deployed. No visual restyle. No CI ledger refresh.
