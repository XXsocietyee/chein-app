# pages/club/detail/index

CB242 page-ready on `rc/20261108`. `App/ClubDetailView.swift` is unchanged, so the player-visible club home stays. Management tabs still come from `ClubDetailTabPolicy` and `ClubDetailEntryGate`. `WelcomeView.showsMerchantChoice` stays false. `paymentEnabled`, `payoutEnabled`, `withdrawalEnabled`, and `virtualGoodsEnabled` stay false.

`Core/ClubDetailTabs.swift` `ClubDetailPageModel` projects the existing `api/club/detail` payload and an existing `/api/club/access/me` grant. It does not open a route. `/api/club/channels` stays `.missing` and hidden. Loading, empty, and error are separate states. An omitted or null count is U+2014 (`—`); a literal member count of `0` stays `0`; level `0` is unknown, not `L0`.

Evidence: `Tests/CoreTests/ClubDetailPageReadyTests.swift`, `Tests/ContractChecks/test_club_detail_page_ready.py`, `docs/release/ui-strings-pages-club-detail-index.json` (catalog EN and zh-Hans, plus accessibility identifiers), and DEBUG-only `ClubDetailPageFixtureData`.

Left: the view still decodes `ClubRecord`, which stores a missing `memberCount` or `level` as `0`, and it does not call `ClubDetailPageModel`. No Xcode build was run.
