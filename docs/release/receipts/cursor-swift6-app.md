# Receipt: cursor/swift6-app (Q6)

Base: `origin/ui/combined-r7` at `aee32a61f0f69b880bc9e33811463ccc73351bbe`.
Warnings were read from Acceptance run `45420309627` (`ci/baseline-record` `516f1deae996`), artifact `debug-build` (`debug-build.log`). The cited declarations are still the ones in this tree. This VM did not run `swiftc` or `xcodebuild`. Nothing here was parsed or compiled.

No navigation, request body, or gate predicate changed. Path strings stay the same. Bounce and reduce-motion conditions stay the same. `ReviewedPlayerWriteLeases` admit functions stay nonisolated. `Tests/ContractChecks/test_profile_avatar.py` records the new bytes of `Core/ProjectStoryImageUpload.swift` after `nonisolated` was added to `path`.

## Sites

- `App/CloudB3Production.swift:149` `PlayEmergencyLocationConformer`: `@preconcurrency CLLocationManagerDelegate`
- `App/PersonalLocationShareHost.swift:99` `PersonalLocationShareCoreLocationDriver`: `@preconcurrency CLLocationManagerDelegate`
- `App/PlayHUD.swift:69` `PlayHUDHeadingSource`: `@preconcurrency CLLocationManagerDelegate`
- `App/PlayKitNativeSensorProvider.swift:9` `PlayKitNativeSensorProvider`: `@preconcurrency CLLocationManagerDelegate`
- `App/PlayNativeDeviceProvider.swift:12` `PlayNativeDeviceProvider`: `@preconcurrency CLLocationManagerDelegate`
- `App/RuntimeNativeLocationProvider.swift:6` `RuntimeNativeLocationProvider`: `@preconcurrency CLLocationManagerDelegate`
- `App/SessionBackgroundLocationTracker.swift:10` `SessionBackgroundLocationTracker`: `@preconcurrency CLLocationManagerDelegate`
- `App/TeamTrailForegroundRecorder.swift:9` `TeamTrailForegroundRecorder`: `@preconcurrency CLLocationManagerDelegate`
- `App/WalkingForegroundLocationProvider.swift:7` `WalkingForegroundLocationProvider`: `@preconcurrency CLLocationManagerDelegate`
- `App/ClubManagementReviewOwner.swift:6` `ClubManagementReviewOwner`: `@preconcurrency ObservableObject`
- `App/PlayAnswerReview.swift:53` `PlayAnswerReviewPresentation`: `@preconcurrency ObservableObject`
- `App/PlayPlayerActionReviewHost.swift:5` `PlayPlayerActionReviewController`: `@preconcurrency ObservableObject`
- `App/PlayerTaskEvidenceReview.swift:5` `PlayerTaskEvidenceReviewController`: `@preconcurrency ObservableObject`
- `App/PublishingModesViews.swift:876` `ActivityPublishingTimeRangeOwner`: `@preconcurrency ObservableObject`
- `App/RoamExplorationExportView.swift:371` `RoamExportReadPresentation`: `@preconcurrency ObservableObject`
- `App/RoamLiveSessionView.swift:1045` `RoamPausedBrowsePresentation`: `@preconcurrency ObservableObject`
- `App/NativeEnrollmentComposition.swift:16` reads `NativeEnrollmentService.statusPath`: `nonisolated` on the static
- `App/NativeEnrollmentComposition.swift:17` reads `NativeEnrollmentService.challengePath`: `nonisolated` on the static
- `App/NativeEnrollmentComposition.swift:17` reads `NativeEnrollmentService.enrollPath`: `nonisolated` on the static
- `App/NativeEnrollmentComposition.swift:18` reads `NativeEnrollmentService.revokePath`: `nonisolated` on the static
- `App/ReviewedPlayerWriteLeases.swift:204` reads `ReviewedProductionGateLeases.externalGamePaths`: `nonisolated` on the static
- `App/ReviewedPlayerWriteLeases.swift:216` reads `ReviewedProductionGateLeases.externalGamePaths`: same `nonisolated` static
- `App/ReviewedPlayerWriteLeases.swift:300` reads `ReviewedProductionGateLeases.capabilityReadPaths`: `nonisolated` on the static
- `App/ReviewedPlayerWriteLeases.swift:322` reads `ReviewedProductionGateLeases.rewardPledgePaths`: `nonisolated` on the static
- `App/ReviewedPlayerWriteLeases.swift:323` reads `ReviewedProductionGateLeases.rewardPledgePaths`: same `nonisolated` static
- `App/ProjectNodeImageCompositionRoute.swift:6` reads `ProjectNodeImageUploadClient.path`: route keeps the same `api/common/uploadOSS` literal in a nonisolated `path` (`Core/ProjectNodeImageUpload.swift` stays byte-frozen)
- `App/ProjectStoryAudioCompositionRoute.swift:6` reads `ProjectStoryAudioUploadClient.path`: `nonisolated` on the static
- `App/ProjectStoryImageCompositionRoute.swift:6` reads `ProjectStoryImageUploadClient.path`: `nonisolated` on the static
- `App/OwnedTopicCoverCompositionRoute.swift:12` reads `OwnedTopicCoverClient.currentPath`: `nonisolated` on the static
- `App/OwnedTopicCoverCompositionRoute.swift:25` reads `OwnedTopicCoverClient.uploadPath`: `nonisolated` on the static
- `App/OwnedTopicCoverCompositionRoute.swift:37` reads `OwnedTopicCoverClient.selectPath`: `nonisolated` on the static
- `App/OwnedTopicCoverCompositionRoute.swift:38` reads `OwnedTopicCoverClient.statusPath`: `nonisolated` on the static
- `App/DesignSystem/CYGlassCarousel.swift:162` `slideView` `scrollTransition`: `reduceMotion` copied to a `Bool` before the Sendable closure
- `App/DesignSystem/CYGlassCarousel.swift:243` `CYCarouselArt`: `reduceMotion` copied to a `Bool` before the Sendable closure
- `App/DesignSystem/CYGlassCarousel.swift:274` `CYCarouselCaption` offset: same captured `Bool`
- `App/DesignSystem/CYGlassCarousel.swift:275` `CYCarouselCaption` opacity: same captured `Bool`
- `App/DesignSystem/CYGlassCarousel.swift:290` `CYGlassSliver`: `reduceMotion` copied to a `Bool` before the Sendable closure
- `App/DesignSystem/CYHeroBanner.swift:67` `card` scale: `reduceMotion` copied to a `Bool` before the Sendable closure
- `App/DesignSystem/CYHeroBanner.swift:68` `card` opacity: same captured `Bool`
- `App/DesignSystem/CYHeroBanner.swift:96` `cover` offset: `reduceMotion` copied to a `Bool` before the Sendable closure
- `App/SquareDetailView.swift:246` like `BounceSymbolEffect`: `if #available(iOS 18.0, *)` around `.symbolEffect(.bounce, isActive:)`
- `App/SquareDetailView.swift:263` bookmark `BounceSymbolEffect`: `if #available(iOS 18.0, *)` around `.symbolEffect(.bounce, isActive:)`
- `App/E1TicketCard.swift:127` seal `BounceSymbolEffect`: `if #available(iOS 18.0, *)` around `.symbolEffect(.bounce, isActive:)`
- `App/DesignSystem/CYPassVerified.swift:86` check `BounceSymbolEffect`: `if #available(iOS 18.0, *)` around `.symbolEffect(.bounce, isActive:)`
