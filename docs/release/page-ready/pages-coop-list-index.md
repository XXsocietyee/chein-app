# pages/coop/list/index

CB259 page-ready evidence. Map status stays `exists` (`App/CooperationBrowserView.swift`). No view was edited.

Already on `rc/20261108`: `CooperationService.inbox` reads `api/coop/list`, `api/coop/pool/mine`, `api/coop/pool/received`, and `api/coop/candidates/received`. Those routes are already `.liveInProduction` in `ChinaReviewedRouteCapability`. This lane does not add a route and does not change that mark. Official invites and chapter applications stay on the existing flow reads. `CooperationReadModel` already tracks loading and failure. `CooperationOccupancy` still returns nil when a slot number is missing, and a game slot still does not fall through to a topic slot.

Added `CoopListPage` / `CoopListPageCoordinator` in `Core/CoopListParity.swift`. Phases are loading, empty, error, unknown, and ready. A missing read capability keeps the page hidden. Unknown counts are an em dash (`—`) and are not stored as 0. A known empty list stays `0`. A literal JSON 0 stays `0`. A numeric string and `UNKNOWN` still fail the existing invite decode and project as unknown, not as 0. The existing new-invite control, official invites, and chapter applications stay hidden unless that flow reader is already present. Share stays hidden. Merchant choice, payment, payout, withdrawal, and virtual goods stay off.

## Missing keys

These keys are not in `Resources/Localizable.xcstrings`. This lane does not add them to the catalog or to a ui-strings file.

- pages.coop.list.index.loading
- pages.coop.list.index.empty
- pages.coop.list.index.error
- pages.coop.list.index.unknown
- pages.coop.list.index.ready
- pages.coop.list.index.invitationCount
- pages.coop.list.index.applicationCount
- pages.coop.list.index.registrationCount
- pages.coop.list.index.slotCount
- pages.coop.list.index.slotCapacity
- pages.coop.list.index.share
- pages.coop.list.index.countdown
- pages.coop.list.index.subscribe

Contract names that are not defined, so they are not invented:

- Countdown day count (`邀约剩 N 天有效`). Wall time stays `CooperationSourceTime`.
- Share payload. No share surface is added.
- WeChat subscribe template `coopInvited`.
- Deposit payment and refund retry. Both stay unwired.

## Tests

- `Tests/CoreTests/CoopListPageReadyTests.swift`
- `Tests/ContractChecks/test_coop_list_page_ready.py`

## Left

- `CooperationBrowserView` still draws `CooperationReadScreen` and does not read `CoopListPage`.
- Detail occupancy is unchanged: a missing slot number stays nil there.
- The missing keys above are not in the catalog.
- No Xcode run. `xcodebuild` was not used.
