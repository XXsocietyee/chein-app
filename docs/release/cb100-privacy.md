# CB100 — Privacy manifest, required-reason APIs, and permission strings

Checked against `origin/rc/20261108` at `576e869a995c280f325799ad8ea9a2729ac30781` (2026-11-09 PT). Source inspection only. This note does not sign, upload, or open a socket.

`Resources/PrivacyInfo.xcprivacy` is unchanged. One permission sentence was wrong, and that sentence is the only string this change edits.

## Installed photo-add sentence

`NSPhotoLibraryAddUsageDescription` is the only photo-library usage key. It lives in `Config/Info.plist` (English) and in both locales of `Resources/InfoPlist.xcstrings`. `NSPhotoLibraryUsageDescription` stays out of `Config/Info.plist`. Library picks go through `PHPickerViewController` or `PhotosPicker` and do not call `PHPhotoLibrary.requestAuthorization`.

The previous sentence named only a walk card. Chinese said the add happened only for a roam walk card (`仅在你选择“保存到相册”时，将漫游足迹卡添加到相册。`). The only add-only writer is `RoamSharePhotoLibraryWriter` in `App/RoamSharePhotoSaveModel.swift` (`PHPhotoLibrary.requestAuthorization(for: .addOnly)` and `PHAssetCreationRequest`). Three screens call it, and each waits for the button whose catalog key is `roam.share.savePhotos` (“Save to Photos” / “保存到相册”):

| Screen | What is written | Reachable from |
|---|---|---|
| `App/RoamHistoryShareView.swift` | Rendered walk card | History share |
| `App/RoamMedalShareView.swift` | Rendered medal card (`roam.medalShare.title` is “Medal card” / “勋章卡”) | `App/RoamHistoryViews.swift` pushes `RoamMedalShareView` |
| `App/RoamStampSlipPhotoSaver.swift` | The city-stamp slip picture at `pictureURL`, after the slip is torn | `RoamStampSlipSaveRow` in `App/RoamSubpageParityViews.swift` |

The product names are the catalog strings already in `Resources/Localizable.xcstrings`: walk card / 足迹卡 (`roam.share.title`), medal card / 勋章卡, City stamp / 城市签 (`roam.experience.cityStamp`), and slip / 小票 (`roamSub.w208.stamp.tear`). The saver writes the picture bytes, not a second rendered card.

English in `Config/Info.plist` and `Resources/InfoPlist.xcstrings`, and zh-Hans in the catalog, now say the app saves a walk card, a medal card, or a city stamp slip picture to Photos when that button is chosen. The Chinese sentence still uses 仅, because those three writes are the only `PHPhotoLibrary` add calls and they all start from that button.

`docs/roam-share-photo-save-registration.json` still records the old fragment. It is the registration of an earlier merge (`central_files_edited` is false). It is not the installed string. `Tests/CoreTests/AppStoreSubmissionReadinessAuditTests.swift` still uses the old sentence as an in-memory non-blank sample. That sample is not read from `Config/Info.plist`.

## Permission strings that stay

English in `Config/Base.xcconfig` matches `Resources/InfoPlist.xcstrings` for the four `INFOPLIST_KEY_*` usage keys. zh-Hans is in the same catalog. This pass did not rewrite them. A named use below is a call that can raise the system prompt. An extra call that the sentence does not name is listed only when the sentence does not claim to be the complete set.

| Key | Sentence matches these calls | Not rewritten |
|---|---|---|
| `NSCameraUsageDescription` | `App/NativeQRScanner.swift` calls `AVCaptureDevice.requestAccess(for: .video)` for a QR scan. `App/MerchantEvidenceSelectionView.swift` can present `UIImagePickerController` with `sourceType = .camera` for an aftercare evidence photo. | The evidence button stays disabled unless `cameraSelectionEnabled` is true. The two production call sites leave that default false. `App/RoamStampCameraView.swift` also calls `requestAccess(for: .video)`, and only when `stampCameraEnabled` and the in-app consent toggle are both true. `App/PlayNativeDeviceProvider.swift`, `App/PlayKitCameraPresentation.swift`, and `App/PlayKitSpatialRevealView.swift` call the same camera request behind their own grants. `App/ClubProfileMediaEditor.swift` can present the evidence camera only when `permitsCamera` is true. The installed sentence does not say those are the only camera uses, and it does not deny them. |
| `NSLocationWhenInUseUsageDescription` | `App/RuntimeNativeLocationProvider.swift` calls `requestWhenInUseAuthorization()` for roam, a location play device, and nearby lookup (`App/AppSession.swift` enables it for nearby location). `App/PlayNativeDeviceProvider.swift` requests when-in-use for a location play device. `App/PersonalLocationShareHost.swift` requests when-in-use and sets `allowsBackgroundLocationUpdates = false`. | `App/PlayKitNativeSensorProvider.swift` can request when-in-use for heading and does not start a coordinate stream. `App/WalkingForegroundLocationProvider.swift` calls `requestLocation()` only after authorization already exists and does not request permission. No `requestAlwaysAuthorization` and no `UIBackgroundModes` are in `Config/Base.xcconfig`, `Config/Info.plist`, `Resources/InfoPlist.xcstrings`, or `Resources/PrivacyInfo.xcprivacy`. |
| `NSMicrophoneUsageDescription` | `App/IMVoiceDevice.swift` calls `requestRecordPermission` for an IM voice take. `Core/IMVoiceCoordinator.swift` keeps `confirmUpload()` separate from recording. `App/MerchantNPCVoiceDevice.swift` calls `requestRecordPermission` for NPC voice. `App/PlayKitNativeSensorProvider.swift` calls `requestRecordPermission` for `.soundPeak`, then `installTap` yields a peak amplitude and does not keep PCM. | `App/ShopNPCVoiceProvider.swift` (`ShopNPCAVCapture`) records only when `recordPermission` is already `.granted`. It does not request permission itself. |
| `NSMotionUsageDescription` | `App/IPhonePedometerProvider.swift` is the `CMPedometer.queryPedometerData` call. Its own comment says that query is the Motion and Fitness prompt. `Core/NativeStepCoordinator.swift` reads steps only after the service reply has `rewardEnabled == false` and status `AUDIT_ONLY`. | `CMMotionManager.startAccelerometerUpdates` in `App/PlayNativeDeviceProvider.swift` and `App/PlayKitNativeSensorProvider.swift` does not call `queryPedometerData`. The sentence is about step counts. |

No `ATTrackingManager`, `ASIdentifierManager`, `AdSupport`, `SKAdNetwork`, or `NSUserTrackingUsageDescription` is in the Swift, Objective-C, plist, or xcconfig sources searched for this note. Tracking stays off. This note does not add a tracking SDK and does not add an App Tracking Transparency prompt.

## Required-reason APIs

`Resources/PrivacyInfo.xcprivacy` declares:

| Category | Reason |
|---|---|
| User Defaults | `CA92.1` |
| File Timestamp | `C617.1` |
| System Boot Time | `35F9.1` |

`NSPrivacyTracking` is false. `NSPrivacyTrackingDomains` is empty. Collected types are unchanged: each is linked, tracking is false, and the purpose is App Functionality. This note does not add or remove a collected type. `Vendor/GLTFKit2/GLTFKit2/PrivacyInfo.xcprivacy` still has tracking off and empty collected-data and accessed-API arrays.

User Defaults `CA92.1` matches app-scoped `UserDefaults.standard` and `@AppStorage` (`App/QuestifyApp.swift` `preferences.language`, `App/SettingsView.swift`, `App/RoamExperienceHubView.swift`). No application-group entitlement is in the tree. `UserDefaults(suiteName:)` under `App/` is limited to fixture suites, not an app group.

System Boot Time `35F9.1` matches `ProcessInfo.processInfo.systemUptime` used as a local elapsed clock (play timers, `Core/OrderPaymentVerifier.swift` deadlines, `Core/PersonalLocationShareCoordinator.swift` local deadlines). This pass did not find `systemUptime` assigned into an outbound field. `8FFB.1` and `3D61.1` stay undeclared.

File Timestamp `C617.1` matches metadata of files the app creates in its container or temporary directory. Examples: `App/ProjectTopicMediaInspector.swift` (`fstat` and `st_mtimespec` on `temporaryDirectory`), `App/IMVoiceDevice.swift` and `App/MerchantNPCVoiceDevice.swift` (`contentModificationDateKey` on those temporary recordings), `Core/ParticipantFileJournal.swift` (Application Support), and `Core/ContentDraftSystemStorage.swift` (the sandbox home plus Application Support). `fstat` and `lstat` in `Core/ClubOrdinaryAdmissionFileJournal.swift`, `Core/MerchantOfferWithdrawalOriginalJournal.swift`, and `Core/MerchantOfferWithdrawalUnifiedStore.swift` are the same kind of app-owned journal file.

`3B52.1` is the Apple reason for timestamps or other metadata of a file the person granted, such as through a document picker. These calls read `st_mtimespec` on that kind of file and are not covered by `C617.1`:

- `App/TemplateAudioDocumentPickerAdapter.swift`, after file coordination of the selected URL
- `App/ProjectStoryAudioSelectedDocumentReader.swift`, on the same coordinated URL
- `Core/QmodArchiveInspection.swift` (`QmodSecurityScopedPackage`), after `startAccessingSecurityScopedResource()`

The declared code `C617.1` is still the right code for the container files. The manifest does not also list `3B52.1`. This note does not add it. `Tests/ContractChecks/test_app_store_privacy_launch_contracts.py` and `tools/archive_unsigned.py` pin the accessed-API dictionary to the three reasons above, and `App/AppStorePrivacyManifestSectionView.swift` repeats that same list. Adding a reason would be a new declaration, not a correction of a reason code that the container calls disprove. Disk space and active keyboards stay undeclared: this pass found no `statfs`, `statvfs`, `volumeAvailableCapacity`, `NSFileSystemFreeSize`, or `activeInputModes` in App, Core, or Vendor sources. `Core/AppStorePrivacyManifestAndPermissionAudit.swift` still has an in-memory default that names Disk Space `E174.1`. That default is not the bundled manifest.

## Not filled in

This note does not write legal text, a support contact, or an ICP number. The China privacy-policy document in `Core/SettingsSourceLegalCatalog.swift` is returned only when `privacyPolicyApproved` is true. The function argument defaults to false, and the unapproved result is `.missing(.pendingSourceText)`. No privacy-policy URL, support URL, or filing number is recorded here.
