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
