# CB38 — Keychain, ATS, token storage, deep links, pasteboard

Base: `origin/rc/20261108` `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`.
Reviewed 2026-11-09 PT. Source inspection only. This note does not claim a Swift compile, a test run, a simulator run, or a device Keychain check.

Password login, bank-card withdrawal, and virtual goods were not switched on. `Config/Base.xcconfig` still has an empty `QUESTIFY_API_BASE_URL`, an empty `QUESTIFY_SESSION_REALM`, and version `0.1.0` (`1`). No US API URL, payment route, or legal sentence was added. ATS was not disabled. No secret was printed or committed.

## Fixed here

These are local and do not change authentication, the origin allowlist, or Keychain accessibility class.

| Finding | Change |
|---|---|
| Team invite copy wrote `UIPasteboard` with `localOnly` and no expiry. `tools/check_team_native.py` also forbids the `UIPasteboard` token in `App/*Team*.swift`. | `App/TeamComponents.swift` now calls `LocalPasteboard.copy`, which is `localOnly` and expires after 120 seconds. The unused UIKit import went with it. |
| Approved-media link copy was `localOnly` with no expiry. | `App/OwnMediaApprovedLinkCopyButton.swift` uses the same helper. Cancel still does not clear a value that was already copied. |
| Club AI promo copy was `localOnly` with no expiry, and success required `UIPasteboard.hasStrings`. That property reads pasteboard content and can raise the system paste notice. | `App/ClubAIDesignFeedbackViews.swift` writes through `LocalPasteboard` and treats a `changeCount` change as success. `changeCount` is not pasteboard content. `hasStrings` is no longer read. |
| Search-history Keychain queries and inserts did not set `kSecAttrSynchronizable`. The default is already non-sync, but the attribute was implicit on both lookup and `SecItemAdd`. | `App/SearchMapComponents.swift` sets `kSecAttrSynchronizable` to false on the shared query, so read, update, delete, and insert all name it. Existing non-sync items still match. |

`LocalPasteboard` (`App/LocalPasteboard.swift`) was already the shared copy path: UTF-8 plain text, `localOnly: true`, default lifetime 120 seconds. `Tests/AppUnitTests/AccessibilityHardeningWaveTests.swift` locks that helper. Those tests were not executed here.

## Keychain — reviewed, not changed

Session token store `App/KeychainTokenStore.swift`:

- Generic password, service from `RegionalSessionStorageScope`, account `session-token`.
- `kSecAttrSynchronizable` false.
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` on write.
- No access-group override. `Config/Questify.entitlements` has only Sign in with Apple, so there is no shared keychain group.
- Read failure (other than not-found) throws. Unauthorized restore sets the UserDefaults flag `restoreBlockedKey` and clears the item. The flag is a boolean, not the token.
- `kSecUseDataProtectionKeychain` is not set. On iOS the data-protection keychain is the app keychain. The query was not edited, because a new attribute could miss an item already stored for a signed-in user. That needs a device check.

Other writers that already use `WhenUnlockedThisDeviceOnly` and `synchronizable == false`, and that were not edited:

- `App/TemplateAuthoringSecureStorage.swift`
- `App/SquareWorkspaceSecureStorage.swift`
- `App/RoamHistoryKeychainStorage.swift`
- `App/ProjectEditSecureStorage.swift`
- `App/PrivateHomeKeychainJournal.swift` (read rejects a different accessibility class or a synchronizable item)
- `App/NativeWalkingNavigationFactory.swift` (same rejection on read)
- `App/NativeEnrollmentKeychainStore.swift`
- `App/ImageUploadSecureStorage.swift`
- `Core/ClubProfileLocalDraftStore.swift` (same rejection on read)
- `Core/ContentDraftSystemStorage.swift` (same rejection on read)

`App/NativeChannelReportJournalKeys.swift` returns attributes only, with `synchronizable == false`, and does not read secret bytes.

Not changed, and why:

- Search history still inserts `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. `tools/check_search_map.py` requires that symbol in `App/*Search*.swift`. The class is still this-device-only, and it stays readable after first unlock while the device is locked. This change does not migrate an existing row to `WhenUnlockedThisDeviceOnly`. A migration is a real Keychain update and was not run.
- Search history does not reject a row whose accessibility class differs, and it does not cap the blob before `JSONDecoder`. `SearchHistoryPolicy` keeps ten strings and does not cap each string. Failing closed on a large blob could hide a real history the user typed. Left as-is.
- No biometric ACL (`kSecAccessControl`) was added to the session token. That would change restore and could lock out a user. The diagnostic screen `App/KeychainAndBiometricSessionSecuritySectionView.swift` describes controls; it is not the store.
- No Keychain item was deleted, and no access group was added.

## ATS — reviewed, not changed

`Config/Info.plist` has no `NSAppTransportSecurity` dictionary. `Config/Base.xcconfig` says there is no ATS relaxation, and no `Config/*.xcconfig` sets `NSAllowsArbitraryLoads`, `NSAllowsArbitraryLoadsForMedia`, `NSAllowsArbitraryLoadsInWebContent`, `NSAllowsLocalNetworking`, or `NSExceptionDomains`. `Questify.xcodeproj` does not contain those keys. `Vendor/` has none of them. `tools/check_scaffold.py`, `tools/check_l2_environment_configs.py`, and `tools/archive_unsigned.py` reject the exception keys.

With the key absent, the system ATS default applies: app connections must be HTTPS. This change does not add an exception and does not set `NSAllowsArbitraryLoads` to false as a new key. Adding the dictionary was unnecessary and was avoided so a later edit cannot turn the switch the wrong way inside a new block.

`App/ReferenceMapCardFixtureView.swift` contains the literal `http://invalid.example/image.png` as a fixture image source. It is not an ATS exception and was not edited.

## Token storage — reviewed, not changed

- The session token is written only through `KeychainTokenStore.write` (`App/AppSession.swift` login and channel commit). It is not written to `UserDefaults`, `@AppStorage`, or a plist.
- UserDefaults in the session path stores language, reduced-motion, consent versions, and the restore-blocked boolean. `App/UsageConsentGateView.swift` states that consent storage does not hold tokens.
- `AuthRequestBuilder` sends the token in the `Authorization` header, refuses a token that is empty or outside printable ASCII, and sets `reloadIgnoringLocalCacheData` on that request. The header value was not logged here, and this change does not add logging.
- Release builds compile out password login: `AppSession.passwordLoginCompiledIn` is true only under `#if DEBUG`. `login(username:password:)` returns `auth.notConfigured` otherwise. Not changed.
- `RegionalLaunchConfiguration.reviewedMarketDeployment` keeps `productionGatesEnabled: false`. The comment there already says password login, bank withdrawal, and virtual goods stay off. Not changed.
- `Config/China.Production.xcconfig` already has the reviewed China host and realm. `Config/UnitedStates.Production.xcconfig` leaves the API URL and realm empty. Neither file was edited. No US host was invented.
- WeChat and payment configuration on the shipping session stay nil (`weChatSDKConfiguration` is nil). Token commit for WeChat still goes through the existing coordinator. Not changed.

## Deep links — reviewed, not changed

`App/QuestifyApp.swift` sends `onOpenURL` to `AppSession.receiveNativeURL` and browsing-web user activities to `receiveWeChatUserActivity`.

`receiveNativeURL` offers the URL to the WeChat payment driver and the WeChat auth driver first. Both adapters accept a URL only while a pending attempt's configuration matches that exact callback. The shipping auth configuration is nil, and payment configuration is not mounted as an approved live grant in this review. Unmatched URLs fall through.

The fall-through parser is `NativeEntryLinkPolicy(verifiedHTTPSOrigins: [])` in `AppSession`. `Core/NativeEntryRouting.swift` requires all of the following before any route is returned: length at most 8192 bytes, `https`, a non-empty host, no user, no password, no port, no fragment, and `https://` + lowercased host present in the allowlist. The allowlist is empty, so every inbound URL becomes `.routeError(.unsupported)`. `tools/check_native_navigation_completion.py` and `tools/check_door_referral.py` require that empty default. Filling it would name a host. No host was added.

`DoorLinkPolicy` has the same empty default and only accepts `/door` with `scene`, `inviter`, or `id`. `DoorReferralQueue.capture` still requires `DoorParsing.inviter` (a positive integer) before it stores anything. Scan and binding stay disabled in the door check manifest.

`PushTapRouter()` defaults to no route keys, so a push payload does not become a route. `NativeNavigationContract.parseInternal` accepts only scheme-less, host-less source paths.

`Config/Questify.entitlements` has no associated-domains entry. A contract check forbids `CFBundleURLTypes`, `AssociatedDomains`, and `applinks:` on the project root (`Tests/ContractChecks/test_account_marketing_entry_integration.py`). No custom scheme was registered. Strings such as `questify://im/session/{conversationId}` in `App/PushNotificationAndLiveActivitySectionView.swift` are diagnostic copy, not a registered scheme, and were not turned into a parser.

Not changed, and why:

- The empty allowlist is fail-closed. Putting a host in it would be a product and Universal Link decision, and it would fight the source checks.
- Route parsers were not loosened. Content targets still require one positive `id`. Team join still goes through `TeamInvitationRoute`. Badge query values are length-capped. None of that was weakened.
- QR scan (`App/NativeQRScanner.swift`) returns one raw string to the caller and opens only `UIApplication.openSettingsURLString` for the Settings button. The file says the caller must validate the payload. No new validator was added, because each caller owns a different payload and a shared reject-all parser would drop legitimate scans. Call-site validation was not re-certified on a device.

## Pasteboard — reviewed, not all changed

Writes that already set `localOnly` and an expiry were left alone:

- `App/WithdrawalSupportContactView.swift` (120s)
- `App/ProfileOrderNumberCopySection.swift` (120s)
- `App/NativeWebhookOneTimeCredentialView.swift` (120s, `UTType.plainText`, selection disabled, `.privacySensitive()`)
- `App/MerchantSettlementProgressView.swift` (120s)
- `App/MerchantEngagementPlatformAdapters.swift` (60s)
- `App/MerchantBusinessRecordViews.swift` (120s)
- `App/CooperationInviteDetailView.swift` (120s)
- Settings, play recap, native copy button, platform adapter, and merchant aftercare refund number, which already call `LocalPasteboard.copy`

Not changed, and why:

- `App/TeamComponents.swift` still has `ShareLink(item: code)` for the invite code. The system share sheet can hand that code to another app. `tools/check_team_native.py` forbids `ShareLink(` in `App/*Team*.swift`, so that check does not match this file. The control was not removed: that is a product cut, and the UI test that would show it was not run. The check file was not edited.
- Selectable text (`.textSelection(.enabled)`) uses the system copy command. That path is not `LocalPasteboard`, so it is not forced local-only or expiring. It appears on contact phones, addresses, order numbers, and other body text (for example `App/ProfileParticipantsView.swift` and `App/CooperationInviteDetailView.swift` contact text). Turning selection off across those screens is a broad UX change and was not done. Webhook secrets already disable selection.
- WeChat pasteboard grant: `App/QFWeChatSDKBridge.m` and `App/QFWeChatPaymentBridge.m` call the vendor completion only on the main thread, for the current attempt, when `pasteboardReadApproved` is true and the URL is the routed URL. Otherwise they return without calling the completion. The shipping flag stays false unless a configuration says otherwise, and `WeChatSDKConfiguration.pasteboardReadApproved` defaults to false. The bridges were not edited. Granting or reworking the vendor callback needs the WeChat SDK and a device.
- No pasteboard read of `string`, `strings`, `url`, `items`, or `hasStrings` remains under `App/` or `Core/` after the club-AI change. This was a source search, not a runtime trace.

## What this run did not do

- `swift`, `swiftc`, `swift test`, `xcodebuild`, `xcrun`, and simulator or device runs. Those tools are not available here. No compile and no test pass is claimed.
- No Keychain, pasteboard, Universal Link, or ATS runtime check.
- No call to the host named in the task constraints, and no deploy.
- `tools/current_ci_manifest.json` was not refreshed.
- No branch other than `cursor/cb38` was pushed. `rc/20261108`, `main`, `master`, `train/ui`, `ui/*`, and `codex/*` were not pushed.
- CB26–CB31 view migrations were not done.
- Password login, bank-card withdrawal, and virtual goods were not enabled.
