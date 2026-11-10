# pages/activity/official-detail/index

Map status on `rc/20261108`: exists. Native screen: `App/OfficialEventDetailView.swift`. This pass does not edit that view.

Already on the branch: `OfficialEventService.detail` reads `api/official/events/{id}`, and `OfficialSessionReader.detail` calls it. `OfficialDetailLoadFailure` classifies unavailable, network, and other failures. `OfficialEventDetailPresentation.countText` renders a missing participant or progress count as `—` and a literal `0` as `0`. `OfficialEventDetailPresentationTests` and `Tests/ContractChecks/test_official_detail_parity_w2_06.py` lock that behavior. `OfficialEventSyntheticFixtures` is already DEBUG-only.

Added because the read model had no loading, empty, error, or unknown phase: `OfficialEventDetailPageState` in `Core/OfficialEventDetailPresentation.swift`. Loading stays blank. Empty, error, and unknown counts stay `—`, never `0`. DEBUG `OfficialEventDetailFixtureData` holds the content, empty, unknown, and literal-zero payloads. EN and zh-Hans keys plus accessibility identifiers are in `docs/release/ui-strings-pages-activity-official-detail-index.json`.

Share stays hidden. No share route exists on `OfficialEventService`. `showsMerchantChoice`, `paymentEnabled`, `payoutEnabled`, `withdrawalEnabled`, and `virtualGoodsEnabled` stay false. Collective progress still prints `--` for a missing percent; `testIntroStoryEligibilityPauseAndCollectiveCopy` locks that text, and the view was not changed.
