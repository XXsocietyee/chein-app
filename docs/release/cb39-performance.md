# CB39 performance static review

Base `origin/rc/20261108` `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. Branch `cursor/cb39`.

This is a source reading of launch main-thread work, large synchronous loads, and image decoding. No view was restyled. No production Swift was edited. A change was applied only when it was behavior-preserving and already locked by a test. None of the findings below met that bar: moving the work changes session order, displayed pixels, journal failure, or actor isolation, and this VM cannot compile or run the suites that would notice.

Default API URL and session realm stay empty. Version stays 0.1.0 (1). Password login, bank-card withdrawal, and virtual goods stay off.

## What was not run

- `swift`, `swiftc`, and `xcodebuild` are not on this VM. No compile, and no claim of a compile.
- `xcodebuild test`, XCTest, XCUITest, and the simulator were not run.
- `flutter`, `flutter analyze`, and `flutter test` were not run. This tree is the native iOS app.
- Instruments, a device, and any cold-start timing were not run. Nothing here is a measured launch budget.
- `tools/current_ci_manifest.json` was not refreshed.
- No network call was made to a production or staging host.

## Launch main thread

Shipped cold start, release configuration, empty API URL:

1. `QuestifyApp.init` calls `CYTabBarAppearance.install()` (`App/QuestifyApp.swift`, `App/DesignSystem/CYDomainTabBar.swift`). That writes `UITabBar.appearance()` once. It does not read a file or decode an image. Left as-is.
2. `AppSessionContainer` is `@MainActor`. Its initializer calls `RegionalLaunchConfiguration.composition.makeSession()` unless a DEBUG fixture short-circuits (`App/QuestifyApp.swift`). `shippedComposition` reads four Info.plist keys. With an empty base URL it returns `makeComposition(reviewed: nil)`, which builds an unconfigured `AppCompositionRoot`. It does not open the Keychain or a journal.
3. `AppSession.init` (`App/AppSession.swift`, around the `init(composition:)` near the end of the type) assigns that root, builds `composition.transport()`, and installs closure slots. The service block (`accountSessionService` through `messageActionService`) runs only when `storageScope`, `regional`, and `apiConfiguration` are all present. The empty-URL build takes the `else` and leaves those services nil. A reviewed China build does construct that whole graph on the main actor before the first frame. Deferring it would change when `AppSession` tests observe a live service. `ReviewedChinaLaunchCompositionTests` and `AppCompositionRootTests` were not edited and were not run. Not changed.
4. `SessionRootView` puts `.task { await session.bootstrap() }` on the root. `bootstrap()` is async, but the prefix is synchronous on the main actor: `sessionDefaults.bool`, `vault.read()` (`KeychainTokenStore.read` → `SecItemCopyMatching`), then `synchronizeSession()` on the club, profile-edit, and merchant-onboarding coordinators, then `participantCoordinator.synchronizeSession()` after a successful restore. `ParticipantMutationCoordinator.restorePending` reads one `OperationDefaultsJournal` key. The Keychain read has to stay in front of `currentAccount` so a missing or blocked token never starts the request. Tests of restore order were not run. Not changed.
5. The signed-in root is one `TabView` with home, roam, publish, club, and mine (`SessionRootView`). SwiftUI builds that body on the main thread. Home is `SessionHomeFeedView` → `HomeFeedView`. Roam starts a `.task` read. Club starts a locality `.task`. None of those bodies call `Data(contentsOf:)` or `UIImage(data:)`. Splitting the tabs would be a view-structure change. Not changed.
6. The root reads `session.personalLocationShareHost` for the environment. The first read builds `PersonalLocationShareHost`, which starts an `NWPathMonitor` on `personal-location-share-path`, and touches the application-support URL for the pending journal. `sceneChanged` only sets a foreground flag. `startUpdatingLocation()` is on `PersonalLocationShareCoreLocation`, and only after an explicit share start with capture approval. The monitor was not removed: the host is the tested share owner, and this pass did not re-run those tests.
7. DEBUG-only work stays inside `#if DEBUG`: the fixture `if` chain in `QuestifyApp.body`, language reset arguments, and `FixtureThemeDomainModifier`. Release does not compile it.

`SettingsBundledLegalReader` is not opened at launch. `AppSession.init` only sets `defaultPrivacyPolicyApproved`. `SettingsSourceLegalCatalog` is static Swift text, read when Settings asks for a document.

## Large synchronous loads

These read whole files or the whole defaults dictionary on whatever actor called them. None of them run from `QuestifyApp.init` or `bootstrap()`.

| Site | What it does | Why it was not changed |
|---|---|---|
| `ExternalGameStore.init` → `loadRegistryFromDisk` / `loadBlocklistFromDisk` (`Core/ExternalGameImport.swift`) | `Data(contentsOf:)` on `registry.json`, then one progress JSON per installed game, with no byte cap. `@MainActor`. Created as `@State` in `PlayThemeBackpackView`, not from the app entry. | `ExternalGameImportTests` expects games and progress to be present immediately after `init` (`relaunched`). A cap or a deferred load changes that contract. |
| `OperationDefaultsJournal.pendingRecords` (`Core/OperationAdapterSafety.swift`) | `UserDefaults.dictionaryRepresentation()` then decode each matching key. Callers include `AppSession.makeNativeFriendProgressCard`, native friend/blacklist/progress flows, and `ClubProfileMediaUpload`. | `OperationPendingListingCompatibilityTests` locks the returned set. An index would be a new persistence format. |
| `CityFairnessQueryStore.clearOtherAccounts` / `clearAll` (`Core/CityFairness.swift`) | Same full defaults scan, then deletes `cityFairness.query.*`. Not on the launch path. | `CityAcquisitionIdentityJournalTests` and the fairness tests compare the defaults dictionary before and after. |
| `IMFileJournal` / `IMVideoJournal` | `Data(contentsOf:)` of the sealed draft. | The read is the draft. A new ceiling changes which drafts still open. |
| `RewardPledge` catalog and `RewardPledgeViews` supply memory | `Data(contentsOf:)` then `JSONDecoder`. | Failure today is a decode error. A size error is a different branch. |
| `OfficialActionCoordinator`, `MerchantEngagementCoordinator`, `MerchantBusinessCoordinator`, `MerchantContentService`, `DoorReferralCoordinator`, `CooperationFlowCoordinator`, `MerchantOfferWithdrawalCoordinator` | Uncapped `Data(contentsOf:)` of one journal, then decode. | Each file is one record. Tests assert the decoded value, not a byte ceiling. |
| `ProfileLocalCoverFileStore.read` | Already refuses a file outside `1...(maximumBytes + 16384)` before `Data(contentsOf:options: .mappedIfSafe)`. | Already bounded. |
| `NativeChannelProgressPrivacyJournal` | Refuses above 16 KiB. | Already bounded. |
| `CityActionBudgetRecovery` | Refuses above 2_000_000 bytes, then reads again to compare. | The second read is the integrity check. |
| `RetainedNativeImagePicker` file callback | Size-checks, then `Data(contentsOf:options: .mappedIfSafe)` up to `RetainedSelectedImage.maximumInputBytes` (20 MiB), then `Task { @MainActor in RetainedImageSanitizer.sanitize }`. | The callback has to finish before the provider deletes the temp URL. Sanitize uses UIKit (`UIGraphicsImageRenderer`) and is `@MainActor`. `RetainedImageSanitizerTests` locks the JPEG, not the queue. |

`PlayKitSpatialAssets.loadImage` is an `@MainActor` async function. It appends the download one byte at a time, up to 10 MiB, then creates an image source and a 4096-pixel thumbnail on the main actor. There is no test that calls `PlayKitSpatialAssets`. Moving the loop off the main actor was not done.

## Image decoding

Already off the main-thread body, and left alone:

- `ProgressiveArtworkRenderer` is an actor. It refuses more than 32 megapixels, thumbnails to the card size (max side 2048), and caches at most two entries or 16 MiB (`App/QuestifyProgressiveBlurArtwork.swift`). `QuestifyImageEntityCard` uses it when a blur identity and an approved origin exist.
- `RetainedImageSanitizer.sanitize` refuses non-singleton sources, dimensions above 30000, and input above 20 MiB, then thumbnails to `RetainedSelectedImage.maximumDimension` (4096) and re-encodes JPEG. `RetainedImageSanitizerTests` checks that JPEG.
- `SquarePostLocalMediaInspector.decodeImage` sets `kCGImageSourceShouldCache` false and thumbnails to 512. `SquarePostLocalMediaPresentationTests` locks the owned bytes and the preview, not a full-size bitmap.
- `PlayKitGLBPreparation` texture check reads type and dimensions only (`kCGImageSourceShouldCache: false`) and does not call `CGImageSourceCreateImageAtIndex`.
- `ProjectTopicMediaInspector.inspect` decodes the full sanitized JPEG on purpose (`kCGImageSourceShouldCacheImmediately`) and checks `CGImageSourceGetStatus == .statusComplete`. That is an inspection, not a list thumbnail. Not changed.

Full `UIImage(data:)` after a dimension check, still on the main actor, because the following `.task` / `Task { @MainActor }` is on an `@MainActor` type. The property read uses a separate `CGImageSource`, then `UIImage(data:)` decodes the whole bitmap again (cap 32 megapixels, about 128 MiB of RGBA). Replacing that with a thumbnail changes the image the screen shows. No unit test asserts pixel size for these views.

- `App/SocialMessageMediaView.swift` `load`
- `App/ObjectCardViews.swift` `load`
- `App/NativeChannelAttachmentPreviewEntry.swift` `updateImage`
- `App/IMVideoViews.swift` cover inside `load`
- `App/ChapterStoryView.swift`, `App/RetainedPublicReviewImages.swift`, `App/NativeMediaGallery.swift`, `App/ProfileCurrentAvatarView.swift`, `App/ProfileCurrentMediaPreview.swift`: `RetainedImageSanitizer.sanitize` (already a 4096 thumbnail and a UIKit render) and then `UIImage(data:)` of that JPEG again. `MemberIdentityAvatarView` does the same in its default `decode` closure. Returning the sanitizer's `UIImage` would change the `@MainActor` API. The sanitizer tests lock JPEG bytes and orientation.

`UIImage(data:)` inside `body`, so a parent update decodes again. Caching into `@State` is a view update change. Not done. The coupon QR is the sharp case: `CouponCodeView` decodes `model.imageBytes` in `content` while `remainingSeconds` is in the same body, so a countdown tick can decode again. `CouponCodePresentationTests` locks `imageBytes` on the coordinator, not the view decode.

- `App/CouponCodeView.swift`
- `App/ClubGroupCodePresentation.swift`
- `App/ClubHostApplicationMaterials.swift`
- `App/ClubPostImagePicker.swift`
- `App/ClubProfileMediaEditor.swift`
- `App/ProfileAvatarDraftSection.swift`
- `App/MerchantEvidenceSelectionView.swift`
- `App/MerchantGalleryBatchView.swift`
- `App/MerchantOnboardingBrandImagesView.swift`
- `App/MerchantOnboardingView.swift`
- `App/MerchantAftercareEvidenceFlow.swift`
- `App/OwnedTopicCoverAuthorView.swift` local preview
- `App/PlayerTaskEvidenceReview.swift`
- `App/PlayerTaskEvidenceView.swift`
- `App/PlayDeviceTaskViews.swift`
- `App/PlayKitPersonalForms.swift`
- `App/RetainedImageSelectionView.swift`
- `App/RoamStampCameraView.swift`

`AsyncImage` decodes at the source size and publishes the image to the main thread. It is the home hero avatar (`HomeHeroAvatar` in `App/HomeSearchTabParityViews.swift`), roam entry covers (`RoamEntryCover` in `App/RoamHomeTabsView.swift`), and the non-blur branch of `QuestifyImageEntityCard`. Other `AsyncImage` call sites are in discovery, square, club, merchant, profile badge, play-kit, and template editors. Swapping them for the progressive-blur loader would change placeholders and loading. Not done.

`Vendor/GLTFKit2/GLTFKit2/GLTFAsset.m` decodes embedded images with `CGImageSourceCreateImageAtIndex` and no thumbnail cap. That is vendor code on the asset-load thread. Not changed.

## Not in this pass

CB26–CB31 view migrations were not started. No deployment. No new API host string. No legal copy. No test was deleted, weakened, or renamed.
