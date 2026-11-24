# cursor-mp-cov-player-content

Base `aee32a61f0f69b880bc9e33811463ccc73351bbe` (`origin/ui/combined-r7`). Branch `cursor/mp-cov-player-content`. No pull request.

Coverage table and receipt: `origin/cursor/mp-contract-coverage` at `569fca24195166bfb70cba51a8e2aedff27da2a3`. Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

Slice: player-content topic, template, activity browse (`pages/activity/list`), catalog, and search. Table of rows: `docs/mp-contract-coverage/player-content.md`.

## Counts

| count | value |
|---|---|
| pinning tests | 41 |
| wire contracts that build a request | 38 |
| money contracts that refuse | 3 |
| paths that had no Core literal | 4 |
| App files edited | 0 |
| `swiftc` | not run |

The three refused contracts are `POST api/registration/quote`, `POST api/registration/create`, and `POST api/topic/pricing/confirm`. `PlayerContentMPContract.moneyEnabled` is false. `PlayerContentMPContract.pricingGrantEnabled` is false. `PublisherLifecycleGrants.dormant.pricing` is nil. `TopicPricingXcx.showsConfirm` with `pricingGrantPresent: false` stays false. `TopicLikeHostController().likeGrantEnabled` stays false.

The four paths that had no Core string literal are `api/fe/reference-settlement/note`, `api/topic/recruit-slot-qrcode`, `api/coop/offer/display-terms`, and `api/merchant/chapter-application/offer/remove`.

`TopicClubShareLink` still assigns `clubCode` with `Self.clubCode(trimmed)`.

## App call sites (not edited)

The new contract is not referenced from `App/`. Existing screens keep their current services:

- `App/AppSession.swift` builds `RegistrationService` (`registrationBackend`), `OfficialEventService`, `SearchMapService`, `DiscoveryService`, and `ActivityService`.
- `App/PublisherLifecycleViews.swift` reads `TopicPricingXcx`. Confirm stays behind `pricingGrantPresent`.
- `App/PublisherLifecycleHostHooks.swift` passes `PublisherLifecycleGrants` through. `App/PublisherLifecycleFixtureSupport.swift` passes a reads grant only.
- `App/FreeExploreBundleLaunchView.swift` reads `FreeExploreBundlePageReady` for the catalog screen.
- `App/PlayRuntimeGapViews.swift` calls `PlayTopicSetup.read`.
- `App/RoamPlaceExtrasProduction.swift` calls `RoamPlaceCommentClient` for comment add and list.
- `App/MapSearchPlayerViews.swift` calls `MapSearchPlayerService.unifiedSearch`. That unified row was already pinned on the coverage branch and was not redone.
- `App/SocialRoamMounts.swift` uses `MapSearchPlayerService.Place`.

`SearchMapService.listFields` still adds `is_my` on topic list. The mini-program topic search lane does not. `PlayerContentMPContract.searchTopicList` matches the mini program. `SearchMapService` was not changed.

`TopicLikeOperationFactory` still builds a multipart body. The mini program sends urlencoded `id` and `type`. `PlayerContentMPContract.like` matches the mini program. The factory was not changed, and App does not call it.

## Not claimed

No `swiftc` run. No App screen change. No money write was enabled. The coverage tool still ignores `sendRequest(`, so these rows stay out of `docs/mp-contract-coverage.md` until that tool counts them. `pages/topic/catalog/index.js` has no request. `subscribe.request`, the voice-enrollment `request` predicate, and `recordsRequest` have no `/api` path.
