# CB83 — Swift 6 Sendable and actor-isolation candidates (batch 1)

Base: `origin/rc/20261108` `89dcba807e7e5439182ff8852d6600d1fa9fdd49`.
Package: `QuestifyCore` (`Core/` only). Marketing version stays `0.1.0`, build `1`, in `Config/Base.xcconfig`. No Core or App Swift file was edited, and behavior is unchanged.

`swift`, `swiftc`, `xcodebuild`, and `xcrun` are not on this machine. This note is a source reading. It is not a compiler warning count, and it does not say that these lines fail a Swift 6 build.

Batch 1 is three shapes: `nonisolated(unsafe)` mutable static storage, `@unchecked Sendable` or the same lock-guarded mutable class without that conformance, and a `nonisolated` member on a `@MainActor` type that stores identity, compares the class, or is the initializer. `@MainActor` stored `static var` values and `nonisolated static` functions that only use their parameters are not in this batch.

- `Core/AppPreferences.swift:40` — `AppLanguageRuntime.active` is mutable static storage on a non-actor enum, marked `nonisolated(unsafe)`.
- `Core/BundleShelfClient.swift:37` — `UnavailableBundleShelfClient` is a `@MainActor` class whose initializer is explicitly `nonisolated`.
- `Core/BundleVoucherClient.swift:128` — `UnavailableBundleVoucherClient` conforms to `@MainActor` `BundleVoucherServing`, and its initializer is explicitly `nonisolated`.
- `Core/ChannelDiscordMessaging.swift:1738` — `UserDefaultsChannelRulesAcceptanceStore` is `@unchecked Sendable` and writes `UserDefaults` under `NSLock`.
- `Core/ChannelDiscordMessaging.swift:1775` — `InMemoryChannelRulesAcceptanceStore` is `@unchecked Sendable` and mutates a dictionary under `NSLock`.
- `Core/ChannelDiscordMessaging.swift:1818` — `UserDefaultsChannelBlockedUsersStore` is `@unchecked Sendable` and writes `UserDefaults` under `NSLock`.
- `Core/ChannelDiscordMessaging.swift:1861` — `InMemoryChannelBlockedUsersStore` is `@unchecked Sendable` and mutates a dictionary under `NSLock`.
- `Core/ChannelRevokeIsolation.swift:103` — `ChannelRevokePurgeDispatcher` is `@unchecked Sendable` and mutates its delivered-key set under `NSLock`.
- `Core/ClientOperationID.swift:43` — `InMemoryClientOperationIDStore` keeps a mutable id map and an escaping factory behind `NSLock`, and the class is not `Sendable`.
- `Core/ClientOperationID.swift:74` — `FileClientOperationIDStore` keeps a mutable journal and an escaping factory behind `NSLock`, and the class is not `Sendable`.
- `Core/H5OriginalInstallReader.swift:5` — `H5OriginalInstallReader` is `@unchecked Sendable` and stores `@MainActor` `ModInstallationService`.
- `Core/MemberIdentityAvatarTransport.swift:64` — `MemberIdentityAvatarExchange` is an `URLSessionDataDelegate` marked `@unchecked Sendable`, with its continuation and buffer under `NSLock`.
- `Core/MerchantGameNodeCoordinator.swift:29` — nested `Once` is `@unchecked Sendable` and stores mutable `done` plus a `Task` inside `@MainActor` `MerchantGameNodeCoordinator`.
- `Core/NativeChannelProgressNetworkForward.swift:14` — `NativeChannelProgressNetworkExchange` is `@unchecked Sendable` and shares its continuation, task, and terminal result under `NSRecursiveLock`.
- `Core/NativeChannelProgressNetworkForward.swift:39` — `resume` is `@MainActor` on that unchecked class and takes the same lock before starting the task.
- `Core/ObjectCardMedia.swift:40` — `ObjectCardImageTransfer` is an `URLSessionDataDelegate` marked `@unchecked Sendable`, with its continuation and buffer under `NSLock`.
- `Core/OwnMediaApprovedLinkTransport.swift:31` — `OwnMediaApprovedLinkExchange` is an `URLSessionDataDelegate` marked `@unchecked Sendable`, with its continuation and buffer under `NSLock`.
- `Core/OwnMediaPrivateAudioReader.swift:50` — `OwnMediaPrivateAudioExchange` is an `URLSessionDataDelegate` marked `@unchecked Sendable`, with its continuation and buffer under `NSLock`.
- `Core/OwnMediaPrivateImageReader.swift:50` — `OwnMediaPrivateExchange` is an `URLSessionDataDelegate` marked `@unchecked Sendable`, with its continuation and buffer under `NSLock`.
- `Core/OwnMediaPrivateModelReader.swift:50` — `OwnMediaPrivateModelExchange` is an `URLSessionDataDelegate` marked `@unchecked Sendable`, with its continuation and buffer under `NSLock`.
- `Core/PersonalLocationShareHTTPService.swift:11` — `NoRedirect` is an `URLSessionTaskDelegate` marked `@unchecked Sendable` inside `@MainActor` `PersonalLocationShareURLTransport`, and the session delegate queue is nil.
- `Core/ProfileCurrentReview.swift:32` — `==` is `nonisolated` on `@MainActor` `ProfileCurrentReviewReadApproval` and compares the two class instances.
- `Core/ProfileCurrentReview.swift:255` — `ProfileCurrentReviewExchange` is an `URLSessionDataDelegate` marked `@unchecked Sendable`, with its continuation and buffer under `NSLock`.
- `Core/ProfileEditCoordinator.swift:8` — `==` is `nonisolated` on `@MainActor` `ProfileAvatarSaveValidity` and compares the two class instances.
- `Core/ProfileFavoriteTopicRead.swift:43` — `ProfileFavoriteTopicSelection` is `@MainActor` and stores `nonisolated let id`.
- `Core/ProfileFavoriteTopicRead.swift:58` — `==` is `nonisolated` on that `@MainActor` class and reads `id`.
- `Core/ProfileFavoriteTopicRead.swift:59` — `hash(into:)` is `nonisolated` on that `@MainActor` class and reads `id`.
- `Core/ProfileFavoritesReader.swift:7` — `ProfileFavoritePostSelection` is `@MainActor` and stores `nonisolated let id`.
- `Core/ProfileFavoritesReader.swift:31` — `==` is `nonisolated` on that `@MainActor` class and reads `id`.
- `Core/ProfileFavoritesReader.swift:32` — `hash(into:)` is `nonisolated` on that `@MainActor` class and reads `id`.
- `Core/ProfileNicknameAvailabilityService.swift:190` — `ProfileNicknameExchange` is an `URLSessionDataDelegate` marked `@unchecked Sendable`, with its continuation and buffer under `NSLock`.
- `Core/ProfileSavedMediaTransport.swift:64` — `ProfileSavedMediaExchange` is an `URLSessionDataDelegate` marked `@unchecked Sendable`, with its continuation and buffer under `NSLock`.
- `Core/ProjectNodeImageUpload.swift:173` — `ProjectNodeImageAuthorizedTask` is `@unchecked Sendable` and guards `cancelled` with `NSLock` while holding a `URLSession` task.
- `Core/ProjectNodeImageUpload.swift:185` — `resume` captures that unchecked task in a `@MainActor` task and then takes the lock in `startExactTask`.
- `Core/ProjectTopicMediaContracts.swift:154` — `ProjectTopicMediaInspectionBudget` mutates its count, started set, and failure under `NSLock`, and the class is not `Sendable`.
- `Core/ResponseLimitedHTTPTransport.swift:20` — `ResponseLimitedHTTPTransport` is `@unchecked Sendable`, conforms to non-`Sendable` `HTTPTransport`, and stores a task factory that is not `@Sendable`.
- `Core/ResponseLimitedHTTPTransport.swift:109` — `ResponseLimitedHTTPExchange` is an `URLSessionDataDelegate` marked `@unchecked Sendable`, with its continuation and buffer under `NSLock`.
- `Core/RetainedPublicImageReader.swift:27` — `RetainedBoundedImageDownload` is an `URLSessionDataDelegate` marked `@unchecked Sendable`, with its continuation and buffer under `NSLock`.
- `Core/RoamExportDeliveryLease.swift:10` — `RoamExportDeliveryLease` is `@unchecked Sendable` and mutates `revoked` under `NSLock`.
- `Core/RoamExportDeliveryLease.swift:55` — `RoamExportDeliveryContext` is `@unchecked Sendable` and stores `@MainActor` closures plus mutable hand-off state under `NSLock`.
- `Core/SquarePostLocalMediaContracts.swift:127` — nested `Lifecycle` mutates the hasher, count, failure, and finished flag under `NSLock`, and the class is not `Sendable`.
- `Core/W8Text.swift:7` — `W8Text.languageOverride` is mutable static storage on a non-actor enum, marked `nonisolated(unsafe)`.
