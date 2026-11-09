# CB73 — T3 pages that still need more than the theme layer

Source of the 83: `docs/release/ui-tiers.md` on `origin/cursor/cb25` at `bdc0e713b517c5c58376b9cca2d99d9d6da0f275`. That note classifies every data row of `docs/parity/page-map.csv` (163 rows) on `rc/20261108`. Counts there: T1 20, T2 60, T3 83. This note does not edit a view, a Swift file, or `tools/current_ci_manifest.json`.

`origin/cursor/theme` (`cfd65e7fddcece2dc3b7e40b2cc708934188a562`) adds `CYScreenStyle` on the player root and the merchant root. The modifier sets the role color scheme, brand tint, inset-grouped lists, grouped forms, and the page background. Its UIKit walk replaces system chrome and palette-owned colors on navigation bars, collection views, and list cells. It skips `MKMapView` and `WKWebView`. It does not replace `LinearGradient`, `.regularMaterial`, `.thinMaterial`, `.ultraThinMaterial`, or `.bar`. It does not repaint a custom shape. Explicit button styles stay; the comment in `CYScreenStyle` leaves controls in place.

The finished migrations start at that theme commit and restyle T2 pages only:

| Branch | Head | What it restyled |
|---|---|---|
| `origin/cursor/ui-list` | `0765d3053ea2d29d5afa52d72ed8c0fff547f0d6` | 10 T2 list pages |
| `origin/cursor/ui-detail` | `3c8016846bdbde0533e861e563bc9d18bfd2239e` | 10 T2 detail pages |
| `origin/cursor/ui-form` | `2b957c7348d0c3b528d2d6a2f2635957c51759af` | 10 T2 form pages |
| `origin/cursor/ui-settings` | `c4109d858e6e99340fdfca20a7c9af13e3fdbee3` | 2 T2 settings pages |
| `origin/cursor/ui-chat` | `e3a173ac96b2319d8956ab30d780922f8563c35c` | the T2 chat page |
| `origin/cursor/ui-empty` | `6284f2ce7aa6403f7e665acb6048e16d01096c12` | the T2 empty page |

A T3 row is proposed below only when its own view still paints something that walk does not replace. `docs/parity/page-map.csv` has no screenshot column. A screenshot path is recorded only when that file is in this tree. A DEBUG launch argument is recorded only when a DEBUG host in this tree mounts that view.

## Already deferred T2 leftovers

These are T2, not T3. They are not in the batch below.

`origin/cursor/ui-list` migrated 10 of 27 T2 list rows. The other 17 list rows are still deferred:

| # | Mini-program path | Native file |
|---:|---|---|
| 72 | `pages/merchant/aftercare/index` | `App/MerchantBusinessViews.swift` |
| 77 | `pages/merchant/reviews/index` | `App/MerchantBusinessViews.swift` |
| 79 | `pages/merchant/relation/index` | `App/CoopRelationDiscoveryView.swift` |
| 87 | `pages/merchant/coop-center/index` | `App/MerchantCoopCenterView.swift` |
| 94 | `pages/coop/list/index` | `App/CooperationBrowserView.swift` |
| 97 | `pages/coop/nearby/index` | `App/NearbyMerchantView.swift` |
| 110 | `pages/address/address` | `App/ProfileParticipantsView.swift` |
| 117 | `pages/mylike/mylike` | `App/AccountCollectionFavoritesView.swift` |
| 128 | `subpackageMember/coupon-wallet/index` | `App/AccountCollectionCouponsView.swift` |
| 132 | `subpackageMember/mycanyu/mycanyu` | `App/PlayerJourneyViews.swift` |
| 138 | `subpackageMember/points-history/index` | `App/ProfileWeeklyPointsSection.swift` |
| 139 | `subpackageMember/report-mine/index` | `App/SquareReportProgressView.swift` |
| 144 | `subpackageMember/tixianjilu/tixianjilu` | `App/WithdrawalHistoryView.swift` |
| 146 | `subpackageRoam/history/index` | `App/RoamHistoryViews.swift` |
| 149 | `subpackageRoam/nearby/index` | `App/NearbyTeamViews.swift` |
| 151 | `subpackageRoam/my-teams/index` | `App/NearbyTeamViews.swift` |
| 152 | `subpackageRoam/official-routes/index` | `App/RoamBrowserView.swift` |

`origin/cursor/ui-detail` migrated 10 of 18 T2 detail rows and skipped `pages/team/join/index` because `App/TeamHomeView.swift` is a T1 file. Those 8 detail rows are still deferred:

| # | Mini-program path | Native file |
|---:|---|---|
| 10 | `pages/team/join/index` | `App/TeamHomeView.swift` |
| 103 | `pages/square/detail/index` | `App/SquareDetailView.swift` |
| 107 | `pages/templatedetail/templatedetail` | `App/DiscoveryTemplateDetailView.swift` |
| 116 | `pages/userinfo/userinfo` | `App/SocialPublicProfileView.swift` |
| 129 | `subpackageMember/coupon-qr/index` | `App/CouponCodeView.swift` |
| 133 | `subpackageMember/mycanyuinfo/mycanyuinfo` | `App/PlayerJourneyViews.swift` |
| 148 | `subpackageRoam/session/index` | `App/RoamSubpageParityViews.swift` |
| 153 | `subpackageRoam/official-route/index` | `App/RoamSubpageParityViews.swift` |

`origin/cursor/ui-form` also left the T2 form row `subpackageMember/tixian/tixian` (`App/WithdrawalSupportLandingView.swift`) unmigrated. That row is T2, not T3.

Settings (2), chat (1), and empty/error (1) have no T2 leftover.

## Not proposed

- 14 `merged-into:` rows. They have no screen of their own. The canonical row keeps its tier. That includes `pages/searchmap/index` (`App/SearchMapExplorerView.swift`), which still paints `.regularMaterial`, and `pages/publish/topicadd/topicadd`, which is the same screen as `pages/publish/fabu/index`.
- T1 files. No proposed row uses one. `pages/search2/result/index` and `pages/talent/search/index` point at `App/GlobalSearchView.swift`. `subpackageMember/signupInfo/signupInfo` and `subpackageMember/signupInfo2/signupInfo2` point at `App/TicketWalletView.swift`. All four are `merged-into:` a T1 row.
- `pages/merchant/marketing/ai-insight/index`. `origin/cursor/ui-detail` already restyled `MerchantMarketingView`, including the insight facts, empty state, and suggestion buttons.
- `subpackageRoam/citynode-code/index` (`App/VerificationCodeView.swift`). The only paint the walk does not replace is `.background(.white)` on `VerificationLocalQRCode`, the QR quiet zone. It stays white so the code can be scanned.
- `pages/coop/settlement-detail/index` (`App/CoopSettlementDetailView.swift`). The screen is a system `List`. The only fixed size is `.font(.system(size: 7))` on the timeline dot. The theme layer covers the list.
- The other T3 screens. After the theme layer they are system lists, forms, or scroll views, plus palette colors and button styles `CYScreenStyle` leaves in place. `PublishingPlacePicker` in `App/PublishingModesViews.swift` contains a `Map`, and the walk skips maps. That picker is the T2 activity wizard, not the T3 page `pages/publish/simple/index` (`QuickPublishingView`).

## Batch 1 of 1 — seven pages

Later PR. At most 10 pages. Do not edit a T1 file.

1. `pages/play/merchant/index` — `App/PlayStoreDayMerchantView.swift` — screenshot: none. `docs/parity/page-map.csv` has no screenshot column. `docs/release/ui-report-ui-f03.md` names `chengyinhub-xcx/docs/audit-e2e-202609/shots/play-merchant-index.png`, and that file is not in this tree. The only PNGs under `docs/release/` are the D2 home, search, square, and roam shots and the kit gallery. — fixture: `--uitesting-module merchant-city-npc --w2-19-page playMerchant --w2-19-scenario normal`. `ModuleFixture.merchantCityNPC` mounts `MerchantCityNPCParityFixtureHost`, and page `playMerchant` mounts `PlayStoreDayMerchantFixtureHost`, whose body is `PlayStoreDayMerchantView`. The hero vignette is `LinearGradient` of black, and the bottom dock is `.background(.bar)`.
2. `pages/publish/fabu/index` — `App/ProjectEditView.swift` — screenshot: none. The page-map CSV has no screenshot column. `docs/release/ui-report-ui-f06.md` names `docs/xcx-wechat-review-board-shots/shell-topicadd.png`, and that directory is not in this checkout. — fixture: `--uitesting-module projectEdit`. `ModuleFixture.projectEdit` mounts `ProjectEditFixtureHostView`, whose `NavigationStack` body is `ProjectEditView`. Do not add `--project-owned-flow`; that argument mounts `ProjectOwnedContentFixtureHost` instead. The review bar is `.background(.regularMaterial)`.
3. `pages/topic/merchantinfo/merchantinfo` — `App/MerchantContentViews.swift` — screenshot: none. The page-map CSV has no screenshot column. `docs/release/ui-report-ui-f07.md` records this page's screenshot cell as none. — fixture: none. No DEBUG host mounts `MerchantContentDocumentView`. `--uitesting-merchant-content-fixture` mounts `MerchantContentFixtureScenarioView`, whose stack is `MerchantContentHomeView`. The chapters document is a `NavigationLink` from that home, not the mounted view. The page is `MerchantContentDocumentView` with query `.chapters`, and `MerchantContentRecruitView` paints chapter cards with `.regularMaterial` in a `RoundedRectangle`. `Tests/CoreTests/MerchantInfoChaptersReadTests.swift` names that query and does not show the view.
4. `pages/merchant/citynode/index` — `App/MerchantCityNodeHubView.swift` — screenshot: none. The page-map CSV has no screenshot column. `docs/release/ui-report-ui-f05.md` says this repo has no merchant-page screenshot, and `docs/xcx-wechat-review-board-shots/` is not in this checkout. — fixture: `--uitesting-module merchant-city-npc --w2-19-page cityNode --w2-19-scenario normal`. Page `cityNode` mounts `MerchantCityNodeHubFixtureHost`, whose stack is `MerchantCityNodeHubView`. Application and node cards use `.regularMaterial` in a `RoundedRectangle`.
5. `pages/merchant/citynode/create/index` — `App/MerchantCityNodeCreateView.swift` — screenshot: none. Same as the city-node hub: the page-map CSV has no screenshot column, and this repo has no merchant-page screenshot. — fixture: `--uitesting-module merchant-city-npc --w2-19-page cityNodeCreate --w2-19-scenario normal`. `MerchantCityNodeCreateFixtureHost` starts its `NavigationStack` path at `[1]`, and that destination is `MerchantCityNodeCreateView`. The template card is `.regularMaterial` in a `RoundedRectangle`, and the bottom bar is `.background(.bar)`.
6. `pages/merchant/game-node/index` — `App/MerchantGameNodeView.swift` — screenshot: none. Same as the city-node hub: the page-map CSV has no screenshot column, and this repo has no merchant-page screenshot. — fixture: `--uitesting-module merchant-city-npc --w2-19-page gameNode --w2-19-scenario running`. `MerchantGameNodeFixtureHost` mounts `MerchantGameNodeView` for every scenario other than `entries`. `running` is the scenario the host comment names for that view. The toast is `.regularMaterial` in a `Capsule`. The check-in QR pad is `.background(.white)` and stays white.
7. `subpackageRoam/citystamp/index` — `App/RoamSubpageParityViews.swift` — screenshot: none. The page-map CSV has no screenshot column, and no report in `docs/release/` names a screenshot file that exists in this tree for this page. — fixture: `--roam-subpage-fixture stampExchanged`. `RoamSubpageFixtureHost.selected` is that flag, and `QuestifyApp` presents the host. The `stampExchanged` case mounts `RoamCityStampFlowView`. The slip fill that the walk does not replace is `Color(uiColor: .secondarySystemGroupedBackground)` on a `RoundedRectangle` inside `RoamStampSlipView`, which that flow builds after send copies `fixtureReceipt`.

Batch count: 1. Page count in that batch: 7.
