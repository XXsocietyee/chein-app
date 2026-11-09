# CB98 — Swift 6 Sendable and actor-isolation annotations (batch 2)

Base: `origin/rc/20261108` `2f6d5041a57d876d3b0a953f56ecf5208089622f`.
Target: the App target (`App/` only). Marketing version stays `0.1.0`, build `1`, in `Config/Base.xcconfig`. No Core file was edited, including CB83's 42 sites. Behavior is unchanged.

`swift`, `swiftc`, `xcodebuild`, and `xcrun` are not on this machine. This note lists source annotations that were added. It is not a compiler warning count, and it does not say that these lines failed or passed a Swift 6 build.

Batch 2 uses CB83's three shapes, and only where the App target was missing the annotation: `@unchecked Sendable` on a lock-guarded class or on an immutable `URLSession` delegate (and the same immutable `UserDefaults` wrapper), and a `nonisolated` member on a `@MainActor` type, or on a nested type inside one, that stores identity or compares that identity. `@MainActor` stored `static var` values and `nonisolated static` functions that only use their parameters stay out, matching batch 1. Top-level structs that are not actor-isolated already compare identity off the actor, so they were left as they were. Mutable classes that do not already serialize their own state were not marked `Sendable`.

Every annotation below is compile-time isolation metadata. None of them adds a lock, a hop, a task, a branch, or a different value.

- `App/DesignSystem/CYCachedAsyncImage.swift:8` — `CYCachedAsyncImageStore` is now `@unchecked Sendable`. `entries` and `order` were already mutated only while `NSLock` is held, and `coversAndShelves` is still the same shared instance. The conformance adds no method and does not change what `peek`, `touch`, or `insert` return.
- `App/PlayKitGLBAssets.swift:47` — `PlayKitGLBNoRedirects` is now `@unchecked Sendable`. It stores nothing. `delegateQueue` is still `nil`, and the redirect callback still calls `completionHandler(nil)`. The session still rejects every redirect.
- `App/PlayKitSpatialAssets.swift:41` — `PlayKitSpatialRedirectGuard` is now `@unchecked Sendable`. `hosts` is still an immutable `Set<String>` captured at init. The redirect callback still allows only an approved URL and still passes that same request, or `nil`, to the completion handler.
- `App/UsageConsentGateView.swift:4` — `UserDefaultsUsageConsentStorage` is now `@unchecked Sendable`. Its only stored property is the `UserDefaults` reference. `data(forKey:)` and `set(_:forKey:)` still forward to that same object; the wrapper adds no dictionary and no lock of its own.
- `App/WorkshopCreatorConsentView.swift:5` — `WorkshopCreatorConsentSelection.id` is now `nonisolated let`. It is still a `UUID` created with the value and never written again. Equality and hashing already read only that id, and they still do.
- `App/MerchantOperationsViews.swift:401` — `MerchantDecorEditorRoute.id` is now `nonisolated let`. It is still a `UUID` created with the route. `isCurrent` and the other stored properties stay `@MainActor`. Equality and hashing still read only `id`.
- `App/MemberBenefitsReadOwner.swift:12` — `Navigation.==` is now `nonisolated`. It still returns `lhs.id == rhs.id` and still ignores `snapshot`.
- `App/MemberBenefitsReadOwner.swift:13` — `Navigation.hash(into:)` is now `nonisolated`. It still combines only `id`.
- `App/DiscoveryTemplateDetailView.swift:20` — `Adoption.==` is now `nonisolated`. It still returns `lhs.id == rhs.id` and still ignores `source` and `key`.
- `App/DiscoveryTemplateDetailView.swift:21` — `Adoption.hash(into:)` is now `nonisolated`. It still combines only `id`.
- `App/ProjectEditView.swift:147` — `SubmissionDestination.==` is now `nonisolated`. It still returns `lhs.id == rhs.id` and still ignores the receipt, session, and visit.
- `App/ProjectEditView.swift:148` — `SubmissionDestination.hash(into:)` is now `nonisolated`. It still combines only `id`.
- `App/ProjectDraftNodeOverview.swift:17` — `Destination.==` is now `nonisolated`. It still returns `a.id == b.id` and still ignores the capture and row.
- `App/ProjectDraftNodeOverview.swift:18` — `Destination.hash(into:)` is now `nonisolated`. It still combines only `id`.
- `App/ProjectOwnedContentViews.swift:14` — `Selection.==` is now `nonisolated`. It still returns `lhs.id == rhs.id` and still ignores the project, scope, decision, and merchant access.
- `App/ProjectOwnedContentViews.swift:15` — `Selection.hash(into:)` is now `nonisolated`. It still combines only `id`.

16 annotations. Nested identity equality follows the same wording already used by `ProjectEditIssueNavigation.Destination` and `CoopPerkPickerReadModel.Preview`: the comparison stays id-only, and the keyword does not change which values compare equal.
