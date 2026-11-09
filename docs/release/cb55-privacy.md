# CB55 privacy manifest and nutrition-label draft

Checked against `origin/rc/20261108` at `88e981b3308558939e405606cd731b4b29fc9499`. Marketing version stays `0.1.0` and build stays `1` (`Config/Base.xcconfig`). This note does not sign, upload, deploy, or contact `47.103.124.64`. It does not add an ICP filing number, a privacy-policy URL, or legal copy.

`NSPrivacyTracking` stays false. `NSPrivacyTrackingDomains` stays empty. Always-location and background location stay off. Password login, bank-card withdrawal, and virtual goods stay off.

The nutrition-label section is a draft for the owner. It is not submitted to App Store Connect. Apple’s “collect” means the app transmits the data off the device in a way that lets the developer or a partner access it for longer than real-time servicing of that request. A permission string, a DTO field, or an on-device read is not treated as a declaration.

## Tracking

Draft answer: **do not declare tracking.**

- `Resources/PrivacyInfo.xcprivacy` sets `NSPrivacyTracking` to false and `NSPrivacyTrackingDomains` to an empty array. Every collected-type row in that file keeps `NSPrivacyCollectedDataTypeTracking` false.
- A search of Swift and Objective-C sources found no `ATTrackingManager`, `ASIdentifierManager`, `AdSupport`, `requestTrackingAuthorization`, or `SKAdNetwork`.
- `Vendor/GLTFKit2/GLTFKit2/PrivacyInfo.xcprivacy` also sets tracking off and leaves its collected-data and accessed-API arrays empty. No required-reason symbol from the list below was found under `Vendor/GLTFKit2`.

## Required-reason APIs

Apple’s categories are User Defaults, File Timestamp, System Boot Time, Disk Space, and Active Keyboards. The manifest was changed only where this repo contains the call.

| Category | Reason | In `Resources/PrivacyInfo.xcprivacy` | Where the call is |
|---|---|---|---|
| User Defaults | `CA92.1` | Yes, already present | App-only `UserDefaults.standard`. `App/QuestifyApp.swift` reads and writes `preferences.language`. `Core/AppPreferences.swift` and `Core/CityFairness.swift` use `UserDefaults.standard`. `App/UsageConsentGateView.swift` stores agreed document versions on `.standard`. No `com.apple.security.application-groups` entitlement and no `group.` suite were found, so `1C8F.1` is not declared. |
| File Timestamp | `C617.1` | Yes, already present | Metadata of files the app created in its own container. `App/IMVoiceDevice.swift` lists `FileManager.default.temporaryDirectory` with `contentModificationDateKey` and deletes its own stale `.m4a` takes. `App/MerchantNPCVoiceDevice.swift` (`MerchantNPCVoiceTemporaryFiles.sweep`) does the same for `merchant-voice-` files. `App/ProjectTopicMediaInspector.swift` `fstat`s a JPEG the app wrote under `temporaryDirectory` and compares `st_mtimespec`. |
| File Timestamp | `3B52.1` | **Added** | Metadata of files the person granted. `App/TemplateAudioDocumentPickerAdapter.swift` is a `UIDocumentPickerDelegate`. `AppleTemplateAudioSelectedDocumentInspector` `fstat`s the coordinated URL and compares `st_mtimespec`. `App/ProjectStoryAudioSelectedDocumentReader.swift` does the same on a selected URL. `Core/QmodArchiveInspection.swift` `QmodSecurityScopedPackage.open` takes a security-scoped URL, calls `startAccessingSecurityScopedResource`, then `fstat` and compares `st_mtimespec`. |
| System Boot Time | `35F9.1` | Yes, already present | `ProcessInfo.processInfo.systemUptime` is a monotonic clock for elapsed time inside the app. `Core/OrderPaymentVerifier.swift` subtracts it for a local deadline. `App/PlayKitTimedChallengeView.swift`, `App/TemplateTimerRehearsalView.swift`, and `Core/RoamLiveSessionController.swift` use it the same way. No `mach_absolute_time` call was found. `8FFB.1` and `3D61.1` are not declared: this audit did not find boot time copied into an absolute timestamp that is sent off the device, or into a bug report. |
| Disk Space | none | Not declared | No `statfs`, `statvfs`, `fstatfs`, `volumeAvailableCapacity`, or `NSFileSystemFreeSize` in Swift, Objective-C, or C sources. `E174.1` is not added. |
| Active Keyboards | none | Not declared | No `activeInputModes`. `3EC4.1` and `54BD.1` are not added. |

`Core/AppStorePrivacyManifestAndPermissionAudit.swift` has a separate in-memory default that includes Disk Space `E174.1`. That default is not the bundled manifest, and this audit did not find a disk-space call, so `E174.1` was not copied into `Resources/PrivacyInfo.xcprivacy`. `App/AppStorePrivacyManifestSectionView.swift` still names File Timestamp as `C617.1` only. That view is a presentation string. It was not edited. The bundled manifest is `Resources/PrivacyInfo.xcprivacy`.

`docs/wechat-sdk-adapter/integration.md` says a Tencent OpenSDK archive contains its own User Defaults `CA92.1` manifest. That SDK binary is not in this tree, so its declaration was not copied. The app reason above is the app’s own `UserDefaults.standard` use.

`App/ExternalGameImportView.swift` uses `fileImporter` and `Data(contentsOf:)`. That path does not call `fstat` or a timestamp key, so it is not the `3B52.1` pointer. The document-picker and security-scoped `fstat` sites above are.

Xcode’s privacy report on an archive was not run. `xcodebuild` was not run. FP-O8 remains the owner’s archive report.

## Nutrition-label draft answers

Paste only this section into App Store Connect after the owner accepts it. Tracking is No on every row. Purpose is App Functionality. Linked is Yes where the same request carries the account token or the registration is for the signed-in account.

| Data type | Linked | Tracking | Purpose | Proof |
|---|---|---|---|---|
| Phone Number | Yes | No | App Functionality | `Core/AuthChannelService.swift` `sendSMSCode` and `loginWithPhone` put the phone in the request fields. `Core/RegistrationUIForm.swift` builds `RegistrationParticipantDetails` from `realName` and `phone`. `Core/RegistrationCoordinator.swift` `confirm` passes that into `RegistrationCreateIntent`, and `Core/RegistrationService.swift` `create` POSTs it to `api/registration/create`. |
| Name | Yes | No | App Functionality | Same registration path. `RegistrationUIFormDraft` keeps `realName`, and `RegistrationCreateIntent.encode` writes `realName` on the create body. The activity sheet comment says those two fields are what the sheet collects. |
| Precise Location | Yes | No | App Functionality | `Core/PersonalLocationShareCoordinator.swift` `publishOne` builds `PersonalLocationSharePublish` with the sample’s `latitude` and `longitude`. `Core/PersonalLocationShareContracts.swift` requires datum `WGS84` and finite coordinates. `Core/PersonalLocationShareHTTPService.swift` `publish` POSTs that value to `grants/{id}/observations` and refuses a synthetic transport. `App/PersonalLocationShareHost.swift` sets `allowsBackgroundLocationUpdates = false` and requests when-in-use authorization only. |
| Photos or Videos | Yes | No | App Functionality | The proven bytes are photos. `Core/ProfileAvatarUpload.swift` `upload` appends `image.jpeg` and POSTs `multipart/form-data` as `avatar.jpg`. `Core/ProjectTopicImageUpload.swift`, `Core/ProjectStoryImageUpload.swift`, and `Core/ProjectNodeImageUpload.swift` build the same kind of JPEG body. A video-file upload was not proven. The App Store type is the combined Photos or Videos type, selected here because of the JPEG posts. |
| Audio Data | Yes | No | App Functionality | `Core/MerchantNPCVoiceUpload.swift` `upload` appends `clip.bytes` and POSTs `audio/mp4` to `api/common/uploadOSS`. The uploader is constructed with `enabled: false` and returns disabled unless `voiceCloning` is granted. The microphone purpose string also describes an on-device amplitude path that does not upload. The declared collection is the upload path, not the on-device meter. |
| Other User Content | Yes | No | App Functionality | `Core/NativeChannelMessageContracts.swift` puts message `content` on the edit body. `Core/NativeChannelMessageService.swift` POSTs that body to `api/im/message/edit`. This is in-app channel text. Email and SMS were not found. |
| Fitness | Yes | No | App Functionality | `Core/NativeStepContract.swift` `unsignedPayload` includes `cumulativeSteps` from `CMPedometer` (`App/IPhonePedometerProvider.swift`). `Core/NativePlatformService.swift` `action` POSTs that payload. `stepsEnabled` defaults to false, and the service checks `rewardEnabled == false` and status `AUDIT_ONLY` on the reply. No HealthKit usage was found. The declared type is Fitness, not Health. |
| Device ID | Yes | No | App Functionality | The same step request sends `deviceKeyId`. `App/AppAttestStepAssertionProvider.swift` calls `DCAppAttestService.generateAssertion` for an already supplied key id. The provider defaults to `enabled: false`. This is not the advertising identifier. No `identifierForVendor` or `ASIdentifierManager` call was found. |

## Unverified, not a draft answer

These names appear in `Resources/PrivacyInfo.xcprivacy` or in nearby code. They are not answers in the table above. The manifest’s collected-type array was left as it already was. This draft does not treat that array as proof.

| Data type | Why it stays unverified |
|---|---|
| User ID | `Core/Account.swift` decodes `id` or `userId` into `Account`, and `LoginResult` holds that account. The id is assigned by the service and returned to the app. This audit did not find the client generating that id or placing it in an outbound body as a collected identifier distinct from the session token. |
| Email Address | `RegistrationCreateIntent` can encode `email` when a caller passes one. `Core/RegistrationUIForm.swift` `details` passes `realName` and `phone` only. No screen that asks for an email address was tied to that field. |
| Physical Address | `Core/ParticipantForm.swift` says the visible fields are `fullName` and `mobilePhone`. `detailAddress` is copied from a loaded `/info` participant and written back only when that loaded value is non-empty. A field where the person types a street address was not found. |
| Purchase History | `Core/OrderLifecycleDormantAdapter.swift` and `OrderLifecycleRequestContract.paymentParameters` build `api/registration/pay/app` with a registration id. The file says constructing the request does not send it. No completed purchase record was proven to leave the device. |
| Payment Info | The pay body above is a registration id, not a card number. `App/AppSession.swift` `makeBankWithdrawalContext` returns nil unless the runtime factory permits `.bankPrepare` and `.bankConsentRead`. This note does not permit those routes. Bank-card withdrawal stays off. |
| Coarse Location | `Core/PersonalLocationSharePolicy.swift` can render a coarse cell for display. The proven publish body is the sample’s latitude and longitude, which is Precise Location. A transmitted coarse value was not proven. |
| Health | `App/IPhonePedometerProvider.swift` says it uses `CMPedometer` only. No HealthKit, clinical-record, or medical-data send was found. |
| Contacts | No address-book or `CNContact` collection was found. |
| Emails or Text Messages | The proven message text is the in-app channel edit above, drafted as Other User Content. An email or SMS body was not found. |
| Gameplay Content, Customer Support, Browsing History, Search History | No send of saved-game content, a support transcript, off-app browsing, or a stored search query was proven. |
| Product Interaction, Advertising Data, Other Usage Data | No analytics or advertising SDK send was proven. |
| Crash Data, Performance Data, Other Diagnostic Data | No crash-log or performance-metric upload was proven. System boot time stays a local clock under `35F9.1`. |
| Sensitive Info, Credit Info, Other Financial Info, Other User Contact Info, Environment Scanning, Hands, Head, Other Data | No matching collection was proven. |

`Core/WorkshopCommerceContracts.swift` says empty `storeKitBundleID` and `storeKitProductIDs` keep native StoreKit launch off. Virtual goods stay off. That is why Purchase History is not an answer.

## Location, background, and legal text

- When-in-use location remains the usage string already in `Config/Base.xcconfig` and `Resources/InfoPlist.xcstrings`. This note does not add `NSLocationAlwaysUsageDescription` or `NSLocationAlwaysAndWhenInUseUsageDescription`.
- `UIBackgroundModes` is not added. `App/PersonalLocationShareHost.swift` sets `allowsBackgroundLocationUpdates = false` on init and again on stop.
- `Tests/ContractChecks/test_app_store_privacy_launch_contracts.py` and `tools/archive_unsigned.py` still reject those always-location and background-mode keys.
- No ICP filing number is written here. `Tests/CoreTests/SettingsNativeTests.swift` expects the China privacy-policy document to be `.missing(.pendingSourceText)`. A policy URL is not invented. `https://www.chengyinhub.com/prod-api/` in `Config/China.Production.xcconfig` is an API build input, not a privacy policy.

## Gates left as they are

- Password login: `App/AppSession.swift` `passwordLoginCompiledIn` and `canUsePassword` are false outside `DEBUG`.
- Bank-card withdrawal: `makeBankWithdrawalContext` stays behind `.bankPrepare` and `.bankConsentRead`.
- Virtual goods: empty StoreKit product identity keeps the launch off, as cited above.
- Version: `MARKETING_VERSION = 0.1.0`, `CURRENT_PROJECT_VERSION = 1`.

## What this branch did not do

No `xcodebuild`, no archive privacy report, no App Store Connect submission, no deploy, and no request to `47.103.124.64`. `tools/current_ci_manifest.json` was not refreshed. The final nutrition label and the archive privacy report stay with the owner (FP-O4 and FP-O8 in `docs/parity/fix-plan.md`).
