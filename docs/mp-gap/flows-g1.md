# MP Navigation Flow Graph — G1 (`player-content`, `play-roam`, `member`)

Extracted from `hengyin/chengyinhub-xcx` (`wx.navigateTo`, `wx.redirectTo`, `wx.switchTab`, `wx.reLaunch`, `wx.navigateBack`) and compared against `origin/ui/combined-r7` (`App/MPReviewedPageScreen.swift` + `App/MPGap/`).

Legend:
- `[OK]` — Edge exists in the app with equivalent destination.
- `[GAP-CLAUDE]` — Edge missing or routed differently in `App/` (outside `App/MPGap`; for Claude to wire in mounts/hosts).
- `[GAP-MPGAP]` — Edge inside `App/MPGap/` (fixed or closure-wired for mount).

## 1. `player-content`

| MP Source Page | Trigger / Outcome | MP Target (`kind: url`) | App Status & Notes |
| --- | --- | --- | --- |
| `pages/index/index` | Tap topic card | `navigateTo: /pages/topic/index/index?id=` | `[OK]` `TopicDetailView` |
| `pages/index/index` | Tap profile / mine | `switchTab: /pages/member/index/index` | `[OK]` Member tab |
| `pages/index/index` | Role home redirect (merchant) | `redirectTo / reLaunch: MERCHANT_HOME` | `[OK]` Role-gated root switch |
| `pages/template/index` | Tap search bar | `navigateTo: /pages/search2/index` | `[OK]` `UnifiedSearchView` |
| `pages/template/index` | Tap IM inbox | `navigateTo: /subpackageB/pages/im/list/index` | `[OK]` `IMConversationListView` |
| `pages/talent/list/index` | Tap square post / club / topic / play / user / IM / pass | `navigateTo` -> `square/detail`, `club/detail`, `topic/index`, `play/index`, `userinfo`, `im/list`, `market/passes` | `[OK]` |
| `pages/search2/index` | Submit keyword / open map | `navigateTo: /pages/search2/result/index?` / `/pages/searchmap/index?params=` | `[GAP-CLAUDE]` `SearchMapExplorerGapView` exists in `App/MPGap/PlayerContent/`, needs mount from search screen |
| `pages/searchmap/index` | Tap pin -> open topic; back | `navigateTo: /pages/topic/index/index?id=`, `navigateBack` / `switchTab: /pages/index/index` | `[GAP-CLAUDE]` Mount `SearchMapExplorerGapView` `onOpenTopic` -> `TopicDetailView` |
| `pages/templatedetail/shelf/index` | Tap topic preview / template detail | `navigateTo: /pages/templatedetail/topic-preview/index`, `templatedetail` | `[GAP-CLAUDE]` Mount `TopicTemplateDeckPreviewView` -> `DiscoveryTemplateDetailView` |
| `pages/templatedetail/topic-preview/index` | Tap "用这个模板" / "查看详情" / back | `navigateTo: /pages/publish/fabu/index?`, `topic-detail/index?`, `navigateBack` | `[GAP-CLAUDE]` Mount `TopicTemplateDeckPreviewView` `onUseTemplate` / `onViewDetail` |
| `pages/templatedetail/templatedetail` | Use template -> publish; after delete -> myproject; back | `navigateTo: /pages/publish/temp/index?id=`, `redirectTo: /subpackageA/pages/myproject/index?type=template`, `navigateBack` | `[OK]` |
| `pages/topic/index/index` | Start play / signup / pass / my-teams / profile / address / orderinfo | `navigateTo: /pages/play/index?topicId=`, `subpackageMember/signup/index`, `market/pass/index`, `my-teams/index`, `orderinfo/orderinfo`, `gerenziliao`, `address` | `[GAP-CLAUDE]` `TopicRouteMapAndTeamsSection` + `RegistrationGapSections` need mount in `TopicDetailView` / `RegistrationSheetView` |
| `pages/topic/merchantapply/index` | Submit success -> merchantinfo / merchant home; back | `redirectTo: /pages/topic/merchantinfo/merchantinfo?topicId=`, `reLaunch: /pages/merchant/index/index`, `navigateBack` | `[GAP-CLAUDE]` Mount `MerchantApplyPickerGapView` + `MerchantJoinContactHostButton` |
| `pages/topic/merchantinfo/merchantinfo` | Topic preview / merchant apply / coop invite / IM / ledger / pricing | `navigateTo` -> `templatedetail`, `topic/index`, `merchantapply`, `coop/invite`, `im/chat`, `merchant/ledger` | `[OK]` |
| `pages/topic/pricing/index` & `partner/index` | Save -> topic/index or merchantinfo; partner link -> club/detail | `redirectTo: /pages/topic/index/index?id=`, `navigateTo: pricing/partner/index`, `club/detail` | `[GAP-CLAUDE]` Mount `TopicPricingGapSections` |
| `pages/activity/baoming/baoming` | After signup -> `orderinfo/orderinfo?id=` (redirect) or `mycanyu` / `member` tab; address/club | `redirectTo: /subpackageMember/orderinfo/orderinfo?id=`, `navigateTo: /subpackageMember/mycanyu/mycanyu`, `address`, `club/detail` | `[OK]` |
| `pages/activity/list/index` | Tap event / mine / inbox; back | `navigateTo: official-detail`, `official-mine`, `official-inbox`, `navigateBack` | `[OK]` |
| `pages/activity/official-detail/index` | Organizer / topic / roam tab; error -> activity/list | `navigateTo: official-organizer`, `topic/index`, `switchTab: /pages/roam/index`, `redirectTo: /pages/activity/list/index` | `[GAP-CLAUDE]` Mount `OfficialLeaderboardGapSection` |
| `pages/square/detail/index` | Author / topic / play / remix; back | `navigateTo: userinfo`, `topic/index`, `play/index`, `publish/fabu/index?id=`, `navigateBack` | `[OK]` |
| `subpackageA/pages/infomation/infomation` & `infomationdetail` | Open template / settings / back to list | `navigateTo: templatedetail`, `redirectTo: shezhi`, `redirectTo: infomation` | `[GAP-CLAUDE]` Mount `InfomationArticleGapView` rich blocks |
| `subpackageB/pages/im/chat/index` | Report -> `report-mine`; signup / topic; back | `navigateTo: /subpackageMember/report-mine/index`, `signup/index`, `topic/index`, `navigateBack` | `[GAP-CLAUDE]` Mount `IMComposerPlusMenu` + peer report action |

## 2. `play-roam`

| MP Source Page | Trigger / Outcome | MP Target (`kind: url`) | App Status & Notes |
| --- | --- | --- | --- |
| `pages/roam/index` | Citystamp sign/sticker / camera / goals / official-routes / anniversary / monthly-recap / export / nearby / my-teams / im/chat / userinfo / poi-challenge / searchmap / history / badge-wall / activity/list | `navigateTo` to each subpage; `switchTab: /pages/member/index/index` | `[GAP-CLAUDE]` Mount `RoamSessionToolsSheetView` & `RoamCityStripTabView` in `RoamBrowserView` / `RoamLiveSessionView` |
| `pages/play/circle/index` | Resolve invite -> `redirectTo: /pages/play/index?`; fallback -> home / back | `redirectTo: /pages/play/index?`, `reLaunch: /pages/index/index`, `navigateBack` | `[OK]` |
| `pages/play/index` | Merchant guide / badge-3d / topic / badge-wall / official-detail / citystamp / stamp-camera / settle / report; orient finish -> `orient-score` | `navigateTo: play/merchant`, `badge-3d`, `topic/index`, `badge-wall`, `citystamp`, `stamp-camera`, `settle/index`, `report/index`, `orient-score` | `[GAP-CLAUDE]` Mount `PlayToolsAndLeadSheetView` in `PlayExperienceView` |
| `pages/play/poi-challenge/index` | Sign stamp / badge-wall / nearby | `redirectTo: citystamp`, `badge-wall`, `nearby`, `navigateBack` | `[OK]` |
| `pages/team/detail/index` & `join/index` | Invite -> `team/join?code=`; after join -> `team/detail?teamId=`; signup -> `activity/baoming` | `navigateTo: team/join`, `activity/baoming`, `redirectTo: my-teams` / `team/detail` | `[OK]` |
| `subpackageRoam/nearby/index` | My teams / team detail / activity / topic / citystamp / poi-challenge | `navigateTo: my-teams`, `team/detail`, `activity/detail`, `topic/index`, `citystamp`, `poi-challenge` | `[GAP-CLAUDE]` Mount `NearbyTeamsMapAndSheetView` |
| `subpackageRoam/official-routes/index` & `official-route/index` | Route list -> route detail; back / roam tab | `navigateTo: official-route?id=`, `navigateBack`, `switchTab: /pages/roam/index` | `[OK]` |
| `subpackageRoam/history/index` & `session/index` | History item -> session replay / topic; back / roam tab | `navigateTo`, `navigateBack`, `switchTab: /pages/roam/index` | `[GAP-CLAUDE]` Feed `RoamHistoryGapView` from `RoamPassportHistoryReadRoute` |
| `subpackageP3/pages/badge-wall/index/index` | Tap badge -> `badge-3d?name=` or `?style=pin&glyph=` | `navigateTo: /subpackageP3/pages/badge-3d/index` | `[GAP-CLAUDE]` Mount `BadgeWallGridGapView` + `IdentityPinBadge3DParameters` |
| `subpackageP3/pages/stamp-album/index/index` & `stamp-camera` | Open camera / back to album | `navigateTo: stamp-camera`, `redirectTo: stamp-album` | `[OK]` (`SALBUM-r7-1` camera disabled intentionally) |
| `subpackageP3/pages/object-cards/index/index` | Category sheet / rename sheet / pile gather | In-page sheets (`onClose` back) | `[GAP-CLAUDE]` Mount `ObjectCardCategorySheetView`, `ObjectCardRenameSheetView`, `ObjectCardPileAndGridView` |
| `subpackageJourney/pages/landing/index` | Open play / activity / home | `navigateTo: play/index`, `activity/detail`, `switchTab: /pages/index/index` | `[OK]` |
| `subpackageJourney/pages/report/index` | Go settle / seats / home | `navigateTo: settle/index`, `seats/index`, `switchTab: /pages/index/index` | `[OK]` |
| `subpackageJourney/pages/seats/index` | Profile edit / play | `navigateTo: gerenziliao`, `play/index` | `[OK]` |
| `subpackageJourney/pages/settle/index` | Finish offer -> pass/product (`offer.url`); back / ticket wallet | `navigateTo: offer.url`, `reLaunch: ticketWalletUrl`, `navigateBack` | `[GAP-CLAUDE]` Mount `JourneyFinishOfferCardView` in `JourneySettleView` |

## 3. `member`

| MP Source Page | Trigger / Outcome | MP Target (`kind: url`) | App Status & Notes |
| --- | --- | --- | --- |
| `pages/member/index/index` (`cy-profile`) | Orders / mycanyu / signup / points / passes / growthcenter / badge-wall / stamp-album / object-cards / myproject / settings / gerenziliao / im/chat / club/detail | `navigateTo` to each subpackage page | `[OK]` |
| `subpackageMember/free-explore/index` | Back / member tab; `?topicId=` catalog -> topic detail | `navigateBack`, `switchTab: /pages/member/index/index`, `topic/index` | `[GAP-CLAUDE]` Mount `FreeExploreBundleReceiptView` (`?requestId=`) and `FreeExploreCatalogBundleView` (`?topicId=`) |
| `subpackageMember/orient-score/index` | Leaderboard sheet / per-row appeal sheet; back / member tab | In-page sheets; `navigateBack`, `switchTab: /pages/member/index/index` | `[GAP-CLAUDE]` Mount `OrientScoreLeaderboardSheetView` + `OrientScoreAppealSheetView` |
| `subpackageMember/coupon/coupon` | Forbidden player CTA -> merchant apply; summary tiles | `navigateTo: /pages/merchant/apply/index`, `navigateBack` | `[GAP-CLAUDE]` Mount `CouponSummaryTilesSection` + `CouponForbiddenPlayerActionView` |
| `subpackageMember/coupon-qr/index` | Back / member tab | `navigateBack`, `reLaunch: /pages/member/index/index` | `[OK]` |
| `subpackageMember/order/order` & `orderinfo/orderinfo` | Order detail -> `order/order`; merchant scope -> `myproject`; club/seats/invite | `redirectTo: /subpackageMember/order/order`, `myproject?scope=MERCHANT`, `seats`, `club/detail` | `[GAP-CLAUDE]` Mount `OrderDetailTeamSeatsClubSections` |
| `subpackageMember/mycanyu/mycanyu` & `mycanyuinfo` | Focus ticket -> `signup?focusId=`; detail -> `mycanyu` | `navigateTo: signup`, `redirectTo: mycanyu` | `[GAP-CLAUDE]` Mount `ParticipationDetailGapSections` (`MKT-7-1` / `PLY-23-3`) |
| `subpackageMember/signup/index` | Team detail / member tab / home | `navigateTo: team/detail`, `switchTab: member` / `index` | `[GAP-CLAUDE]` Mount `StackedPassHorizontalPager` in `TicketPassSheet` |
| `subpackageMember/report-mine/index` & `report-detail/index` | List -> detail; appeal submit -> `redirectTo: report-mine` | `navigateTo: report-detail?reportId=`, `redirectTo: report-mine` | `[GAP-CLAUDE]` Mount `ReportAppealSheetView` in `CommunityTrustPlayerViews` |
| `subpackageMember/appeal-mine/index` | Tap item -> `play/index?topicId=`; back | `navigateTo: play/index?topicId=`, `navigateBack` | `[OK]` |
| `subpackageMember/points-history/index`, `tixianjilu`, `myinvite`, `complaint`, `character` | Back / redirect to `earnings` or `mycanyu` | `navigateBack`, `redirectTo: earnings` / `mycanyu` | `[OK]` |
| `subpackageMember/invoice/*` | List -> apply / detail / titles -> title-edit; after save -> `redirectTo` back to list/titles | `navigateTo` / `redirectTo` | `[OK]` |
| `subpackageMember/market/{passes,pass,gift,membership,pass-order,library}` & `subpackagePass/reveal` | Passes hub -> gift / reveal / points / pass / pass-order / library; pass -> seats / baoming / passes?tab=orders; after-success redirects | `navigateTo` / `redirectTo` | `[OK]` |
