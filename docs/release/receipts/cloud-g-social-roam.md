# cloud-g-social-roam: capability gaps G4 + G5 (community square, roam, templates, map/search)

Source: `ui/capgraph` c2202dbe3 `docs/release/capability-graph.md` section (1); mini-program `chengyinhub-xcx` at hengyin 92eda912.
Base: `origin/ui/main` ec2e42ba8.

## Grants (both places)
- `App/ReviewedPlayerWriteLeases.swift`: new routes added to `playPaths`; GET reads listed in `capabilityReadPaths`
  (the play grant admits a GET only for these, empty body). `api/roam/share/revoke` may have an empty form body (mini-program `data: {}`).
- `Core/ChinaReviewedRouteCapability.swift`: `socialRoamOwnerGrant` (owner approval, non-money) checked in `admitsChinaProductionCall`.
- Tests: `ReviewedChinaLaunchCompositionTests.testShippedChinaAdmitsSocialRoamTemplateMapRoutesAndKeepsMoneyClosed`
  (shipped China composition sends each route; pay/withdraw stay refused), `PlayerCapabilityRoutesTests.testChinaGateAdmitsTheNewRoutesAndKeepsMoneyClosed`.

## Rows

| Path | Verb | Native file(s) | Status |
|---|---|---|---|
| /api/community-trust/contributions/submit | POST | Core/CommunityTrustPlayerService.swift, App/CommunityTrustPlayerViews.swift (`MerchantCorrectionSheet`) | PARTIAL: service + sheet + grant done; sheet not yet mounted on the public merchant home (its context is built in AppSession, which is at its line ratchet) |
| /api/community-trust/contributions/taxonomy | GET | same | PARTIAL: as above |
| /api/community-trust/reports/appeal | POST | CommunityTrustPlayerService, `ReportAppealSection` mounted in App/MemberReportProgressDetailView.swift (RESOLVED/CLOSED) | DONE |
| /api/community-trust/safety/merchants/{} | GET | CommunityTrustPlayerService, `MerchantSafetySummaryRow` | PARTIAL: view not mounted (same reason as correction) |
| /api/community-trust/safety/ratings | POST | CommunityTrustPlayerService, `MerchantSafetyRatingSheet` | PARTIAL: sheet takes `mms_merchant.id`; not mounted on the play merchant card |
| /api/community-trust/safety/taxonomy | GET | same | PARTIAL: as above |
| /api/v1/community/comments/{}/actions/LIKE | DELETE | Core/SocialActionContracts.swift (pre-existing `communityCommentLike`) | DONE (code pre-existed; gate grant added here) |
| /api/v1/community/me/bookmarks | GET | Core/SquareService.swift `mine(.bookmarks)`, App `SquareMineListView` | PARTIAL: view not mounted in the member page |
| /api/v1/community/me/posts | GET | Core/SquareService.swift `mine(.posts)`, App `SquareMineListView` | PARTIAL: as above |
| /api/v1/community/posts/{}/actions/{} | DELETE | Core/SocialActionContracts.swift `postAction` (pre-existing) | DONE (gate grant added: LIKE, BOOKMARK) |
| /api/free-explore/bundle/exit-decision | POST | Core/BundleAPIClient.swift (pre-existing), App/BundleExitSwapView.swift (`BundleExitSwapTransport`, SWAP_CONSENTED only), mounted as `BundleCommerceEntry.exitSwap` | DONE |
| /api/free-explore/bundle/exit-options | GET | same | DONE |
| /api/free-explore/bundle/order/receipt | GET | Core/BundleAPIClient.swift `orderReceipt` (pre-existing) | PARTIAL: the purchase-result read follows a purchase, which stays unmounted (money) |
| /api/free-explore/bundle/reservation/receipt | GET | Core/FreeExploreLaunchService.swift, App/FreeExploreBundleReadHost.swift (pre-existing) | DONE (pre-existing) |
| /api/free-explore/bundle/reservation/{} | GET | App/BundleCancelTransport.swift (pre-existing) | DONE: the graph row is `reservation/{id}/cancel-quote` + `/cancel` truncated by string concatenation |
| /api/roam/passport/history | GET | Core/RoamPassportHistoryReading.swift, App/RoamPassportHistoryView.swift (pre-existing) | DONE (pre-existing; extractor missed the prefix concatenation) |
| /api/roam/passport/summary | GET | same | DONE (pre-existing) |
| /api/roam/session/records | POST | Core/RoamPlayerExtrasService.swift `archive`, App `RoamSessionArchive.flush` | PARTIAL: not yet called from the live-roam finish recovery |
| /api/roam/share/revoke | POST | RoamPlayerExtrasService `revokeShareSnapshots`, App `RoamShareRevokeRow` (per-account pending mark) | PARTIAL: row not mounted in the share settings |
| /api/roam/shop/visitors | POST | RoamPlayerExtrasService `visitors`, App `RoamShopVisitorsModel` / `RoamShopVisitorsStack` | PARTIAL: not mounted on the roam merchant strip |
| /api/template/adopt-draft | POST | Core/TemplateAdoptionService.swift `adopt` (journaled resume), App `TemplateAdoptButton` + `TemplateAdoptionJournal` | PARTIAL: button not mounted in the template detail |
| /api/template/adoption-detail | GET | same | PARTIAL: as above |
| /api/template/adoption-receipt | GET | same | PARTIAL: as above |
| /api/template/adoption-source | GET | same | PARTIAL: as above |
| /api/template/author-info | POST | TemplateAdoptionService `authorDetail(myScope: nil)` | PARTIAL: no caller in the editor yet |
| /api/template/author-myinfo | POST | TemplateAdoptionService `authorDetail(myScope:)` | PARTIAL: as above |
| /api/template/topic-template/binding | POST | TemplateAdoptionService `bind`, App `TemplateLocationTodosSection` | PARTIAL: section not mounted in the topic editor |
| /api/template/topic-template/binding-status | POST | TemplateAdoptionService `bindingStatus`, same section | PARTIAL: as above |
| /api/template/topic-template/save-as | POST | TemplateAdoptionService `saveAsTemplate`, App `TemplateProjectActions(.topic)` | PARTIAL: not mounted in my projects |
| /api/template/{}/market-submit | POST | TemplateAdoptionService `submitToMarket`, App `TemplateProjectActions(.template)` | PARTIAL: not mounted; the own-shelf screens keep their contract that they never dispatch market-submit |
| /api/map/geocode | POST | Core/MapSearchPlayerService.swift `geocode`, App `GeocodedAddressButton` | PARTIAL: button not mounted |
| /api/map/place-search | POST | MapSearchPlayerService `placeSearch`, App `MapPlaceSearchModel` | PARTIAL: not wired into the map search field |
| /api/map/weather | GET | MapSearchPlayerService `weather` (cell centre only), App `MapWeatherModel` / `MapWeatherOverlay` | PARTIAL: overlay not mounted on the roam map |
| /api/search/unified | POST | MapSearchPlayerService `unifiedSearch`, App `UnifiedSearchResultsView` | PARTIAL: not mounted in the search result page |

## Gates
- generate_project: 3518 sources regenerated. check_scaffold PASS. check_design_lint PASS. appsession ratchet PASS (AppSession line count unchanged; `compositionTransport` made internal on its own line).
- `swiftc -parse` clean on every changed Swift file.
- Core: `PlayerCapabilityRoutesTests` 13/13 pass (QuestifyCore + that file in an isolated package; the full `swift test` target has a pre-existing compile error in `ClubCheckinRailTests.swift`).
- App unit tests (`ReviewedChinaLaunchCompositionTests`, `BundleCommerceMountTests` China list now includes `.exitSwap`) and App views were not compiled here (integrator compiles).
- Contract checks: test_player_write_grant OK; template shelf contracts OK except `test_template_shelf_state_projection`, which fails on base too (`.github/workflows/native-ios.yml` digest).
