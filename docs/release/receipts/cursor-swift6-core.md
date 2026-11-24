# Receipt: cursor/swift6-core (Q1)

Base: `origin/ui/combined-r7` at `82388e4a5e7391e0c5a286735d6b30613a860ae8`.
Warnings were read from Acceptance run `45420309627` (`ci/baseline-record` `516f1deae996`), artifacts `debug-build` (`debug-build.log`) and `core-tests-log` (`core-tests.log`). The cited lines match this tree. This VM did not run `swiftc` or `xcodebuild`. Nothing here was parsed or compiled.

No App screen was edited. Request bodies, route gates, and money behavior are unchanged. `PlatformPass.moneyEnabled` stays false. The module was not marked `@unchecked`.

## Annotations

| Site | Log warning | Annotation |
|---|---|---|
| `PlatformPass` | `Core/PlatformPass.swift:41` and `:42`: stored properties `configuration` (`APIConfiguration`) and `transport` (`any HTTPTransport`) of `Sendable` struct `PlatformPass` are non-Sendable | `public struct PlatformPass: @unchecked Sendable` |
| `UGCContentSafetyHTTPService` | `Core/UGCContentSafetyService.swift:135` and `:136`: same two stored properties on the `Sendable` struct | `public struct UGCContentSafetyHTTPService: UGCContentSafetyServing, @unchecked Sendable` |
| `PlayWireValue` payloads | `Core/PlayThemeGameplay.swift:817` (`PlayThemeManualCommandOption.payload`) and `:1471` (`PendingTeamCommand.payload`): `Sendable` struct property contains non-Sendable `PlayWireValue`. Note: make `PlayWireValue` conform to `Sendable` | `public indirect enum PlayWireValue: Codable, Equatable, Sendable` |
| `ChannelCatalogEntry` | `Core/ChannelGovernanceProjection.swift:95`: stored property `kind` has non-Sendable type `MessagingConversationKind` | `public enum MessagingConversationKind: Equatable, Sendable` |
| `RegionalMarket` | `Core/RegionalEndpointAllowlistAudit.swift:3`: `Sendable` conformance must be in the same source file as enum `RegionalMarket` (retroactive `@unchecked Sendable` is the other-file escape) | `public enum RegionalMarket: String, CaseIterable, Hashable, Sendable` in `Core/RegionalConfiguration.swift`. The other-file `extension RegionalMarket: Sendable {}` was removed so the conformance is not retroactive |
| `HapticsService` | `Core/HapticsService.swift:157`: main actor-isolated static property `minimumCooldownSeconds` cannot be referenced from a nonisolated context | `nonisolated public static let minimumCooldownSeconds: TimeInterval = 0.12` |
| `ReadRetryHTTPTransport` | `Core/ReadRetryHTTPTransport.swift:187`: converting non-Sendable function value `Date.init` to `@Sendable () -> Date` may introduce data races | `now: @escaping @Sendable () -> Date = { Date() }` |

`@unchecked Sendable` is only on `PlatformPass` and `UGCContentSafetyHTTPService`. Both stay immutable stored clients. `HTTPTransport` was not marked `Sendable`, so other transports are unchanged. `MessagingConversationKind` and `PlayWireValue` keep their names; App already uses both.

## Q1b

Parent: `aee32a61f0f69b880bc9e33811463ccc73351bbe`. The seven rows above stay. Remaining warnings were read from the same Acceptance run `45420309627` `core-tests.log`, except `InFlightReadCoalescer.join`: that `NSLock` sits in an `async` function on this tree (`Core/PlayerFeedJSON.swift` join) and was not in the `516f1deae996` log. This VM did not run `swiftc` or `xcodebuild`. Nothing here was parsed or compiled.

No App screen was edited. Request bodies, route gates, and money behavior are unchanged. `PlatformPass.moneyEnabled` stays false. No new `@unchecked Sendable`. Names App already uses were not renamed (`ProjectEditJSON`, `MessagingMessage`, `ChannelTranscriptMessage`, `WalkingTargetReference`, `ShopNPCPublicRead`, `MapDistanceBand`, `ProjectTopicMediaKind`, `ClubOperationsWriteAvailability`).

| Site | Log warning | Annotation |
|---|---|---|
| `InFlightReadCoalescer.join` | `Core/PlayerFeedJSON.swift:92-106`: `NSLock.lock` / `unlock` in an `async` function. Unavailable from asynchronous contexts; use scoped locking | `private let lock = OSAllocatedUnfairLock()`. `join`, `isInFlight`, and `finish` use `withLock`. The await of `task.value` stays outside the lock. The early-finish slot is unchanged |
| `ClubCommunityCoordinator.confirm` | `Core/ClubCommunityService.swift:353`: converting `@MainActor () throws -> ()` to `() throws -> Void` loses global actor `MainActor` | `ClubCommunityService.submit` takes `check: @MainActor () throws -> Void` and calls `try await check()`. The request is still built before the check. The same `checkSubmission` is passed |
| `ApprovedTopicSelectedCover.rawFields` | `Core/ApprovedTopicSelectedCover.swift:13`: stored property `rawFields` has non-Sendable type `ProjectEditJSON`. Note: make `ProjectEditJSON` conform to `Sendable` | `public enum ProjectEditJSON: Codable, Equatable, Sendable` |
| `ClubChannelWorkspacePayload` | `Core/ChannelDiscordMessaging.swift:1905`: stored property `initialMessagesByChannelID` contains non-Sendable `ChannelTranscriptMessage`. Note: make `ChannelTranscriptMessage` conform to `Sendable` | `public struct ChannelTranscriptMessage: Equatable, Identifiable, Sendable`. Its `wireMessage` required `public struct MessagingMessage: Decodable, Equatable, Identifiable, Sendable` and `public enum MessagingMessageStatus: Equatable, Sendable` |
| `ClubCreationGate.writeAvailability` | `Core/ClubOperationsContracts.swift:277`: stored property `writeAvailability` has non-Sendable type `ClubOperationsWriteAvailability` | `public enum ClubOperationsWriteAvailability: Equatable, Sendable` |
| `MerchantAuthoringOutcome.release` | `Core/MerchantAuthoringService.swift:123`: associated value `release` has non-Sendable type `ShopNPCPublicRead` | `public struct ShopNPCPublicRead: Equatable, Sendable` |
| `InAppNavigationDestination.reference` | `Core/NavigationDestinationConsent.swift:18`: stored property `reference` has non-Sendable type `WalkingTargetReference` | `public struct WalkingTargetReference: Codable, Hashable, Sendable` and `public enum Kind: String, Codable, Sendable` |
| `PersonalLocationShareBandedDistance.band` | `Core/PersonalLocationShareDistanceBand.swift:8`: stored property `band` has non-Sendable type `MapDistanceBand` | `public enum MapDistanceBand: String, CaseIterable, Sendable` |
| `ProjectTopicMediaUploadRequest.kinds` | `Core/ProjectTopicMediaUploadPlan.swift:29`: stored property `kinds` contains non-Sendable `ProjectTopicMediaKind` | `public enum ProjectTopicMediaKind: String, Codable, Equatable, Hashable, Sendable` |
| `MerchantMarketingConsentOriginalApproval.init` | `Core/MerchantMarketingConsentOriginal.swift:16`: main actor-isolated static properties `path` and `resultPath` cannot be referenced from a nonisolated context | `public nonisolated static let path=..., resultPath=path+"/result"` |
| `AccountDeregistrationOriginalApproval.init` | `Core/AccountDeregistrationOriginal.swift:13`: main actor-isolated static properties `readPaths` and `writePaths` cannot be referenced from a nonisolated context | `public nonisolated static let` on `base`, `readPaths`, and `writePaths`. `base` is nonisolated because the two sets are built from it |
| `RewardPledgeClient.fetch` | `Core/RewardPledge.swift:1060`: passing non-Sendable parameter `still` to a function expecting a `@Sendable` closure. Note: parameter `still` is implicitly non-Sendable | every `still` on `RewardPledgeClient` is `still: @MainActor @Sendable () -> Bool`. `MainActor.run(body: still)` is unchanged. Call-site closures are the same expressions |
| `ContentContractV1` hangman / accusation | `Core/ContentContractV1.swift:148` and `:185`: left side of `??` has non-optional type `PlayWireValue`, so the right side is never used | `text(payload["input"])` and `text(submission["submitted"])`. `PlayWireValue`'s subscript already yields `.null` when the key is missing |

`Tests/CoreTests/RewardPledgeTests.swift` passes `{ true }` then `{ false }` into `still`. That is the same accept-then-stale result as the previous `{ !moved }` flag, without capturing a mutable local in a `@Sendable` closure.
