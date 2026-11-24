# Receipt: `gap/g1-player`

- **Branch:** `gap/g1-player` (based on `origin/ui/combined-r6` at `f1115875e`)
- **Areas:** `player-content` (30 MP pages), `play-roam` (30 MP pages), `member` (29 MP pages)
- **Strings:** [`docs/port/strings/gap-g1-player.json`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag3/docs/port/strings/gap-g1-player.json)
- **Mount hooks:** [`docs/mp-gap/mounts-g1-player.md`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag3/docs/mp-gap/mounts-g1-player.md)

## Verification
- **Local macOS:** No Xcode build, simulator, or test run executed (disk nearly full, per brief).
- **Syntax check:** `swiftc -parse` passed with exit code 0 on all new Swift files in `Core/MPGap/**`, `App/MPGap/**`, and `Tests/CoreTests/MPGap/**`.
- **Design/typography lint:** `python3 -B tools/check_design_lint.py` passed with 0 new violations.
- **Cloud acceptance (`acceptance.yml`):** Checked `origin/ci/acceptance` (`gh run list --branch ci/acceptance`): all runs on `ci/acceptance` are currently failing (`X`), so `origin/ci/acceptance` was not merged into `gap/g1-player` yet. Ready to merge and run once `ci/acceptance` turns green.

## Coverage Sweep (89 MP Pages in `hengyin-mp/chengyinhub-xcx/app.json`)
Walked all 30 `player-content` pages, 30 `play-roam` pages, and 29 `member` pages in `app.json` (plus verified `pages/playkit/index/index` is a redirect placeholder and `pages/member/index/index` + `pages/talent/list/index` are already routed in `MPReviewedPageScreen.swift`). Every user-visible MP function is either present on `origin/ui/combined-r6`, covered by `port/plan-r1` §2.2 / `origin/cursor/core-wiring-r6`, or inventoried and translated below.

## Round 1 + Round 2 Summary

### `player-content` (`docs/mp-gap/player-content.md`)
- **Translated (Core + SwiftUI + Tests):**
  - Round 1: `PC-A-7-2` (`TopicTemplateDeckPreviewView`), `PC-B-1-5` (`TopicRouteMapAndTeamsSection`), `PC-C-2-3/4/6` (`ActivityRegistrationGapSections`), `PC-C-4-2` (`OfficialEventLeaderboardSection`), `PC-B-4-2/4` (`TopicPricingGapSection`), `PC-B-2-3` (`MerchantHostWorkbenchSection`, owner-gated), `PC-B-1-4` / `PC-C-6-2` (`PlayerContentGapService`).
  - Round 2: `PC-A-5-1/2/3/4/5` (`SearchMapExplorerGapView`, `SearchMapPlaceItem`, `SearchMapCategoryChip`), `PC-A-2-1/5` (`TemplateShelfPagination`, `fetchTemplateShelfPage`), `PC-A-3-3` / `PC-A-4-2` (`UnifiedSearchValidator`, `UnifiedSearchResultRow`, `searchUnified`), `PC-A-6-2` (`TemplateDetailQueryScope`, `fetchMyTemplateDetail`), `PC-B-1-6` / `PC-C-1-7` (`ContextualReviewStarAndPhotoComposerView`), `PC-B-1-11` (`TopicOwnerReviewChipState`), `PC-B-3-2/3` (`MerchantApplySuccessSummaryView`, `fetchMerchantPrefillInfo`), `PC-C-1-1/6` (`ActivityCancelledStateView`, `ActivityTicketWindowInfo`), `PC-D-1-3/6` (`fetchActivityCancelPreview`, `fetchMerchantRegistrations`, `fetchMerchantChapterApplications`), `PC-D-3-2` (`SocialArticleRichBlocksView`), `PC-D-4-2` (`fetchCoopFinance`), `PC-D-6-2` (`WalletAnalysisPagingPolicy`), `PC-D-9-1/3/4` (`IMComposerPlusMenuButton`, `markConversationRead`, `reportPeerMember`).
- **Owner-gated (UI translated or left gated):** `PC-B-1-2` (topic like), `PC-B-2-2/3` (merchant writes), `PC-B-3-1` (merchant apply write), `PC-B-4-1` (pricing confirm), `PC-D-5-1` (withdrawal payout).

### `play-roam` (`docs/mp-gap/play-roam.md`)
- **Translated (Core + SwiftUI + Tests):**
  - Round 1: `PLAY-6/8` (`PlayToolsAndLeadSheetView`, `PlayRoamGapService`), `ROAM-9` (`RoamSessionToolsSheetView`), `RSTAMP-3` (`CityStampTearScratchCardView`, writes owner-gated), `OCARDS-3/4` (`ObjectCardCategorySheetView`, `ObjectCardRenameSheetView`), `RPOI-7` / `JSETTLE-3` (`deleteComment`, `fetchTopicInfo`).
  - Round 2: `RNEAR-2/7` (`NearbyTeamsMapSheetView`, `NearbyTeamMapPin`), `RHIST-1/2` (`RoamMergedHistoryListView`, `MergedRoamHistoryRow.merge`, `fetchRoamHistory`), `RPOI-2/3/8` (`RoamPOIDetailGapSections`, `RoamPendingCheckInContext`), `BWALL-2/3` / `B3D-1` (`BadgeWallTwoColumnGridView`, `BadgeWallMedalItem`, `BadgeWallGrouping`), `JREPORT-2/3` (`JourneyReportNodePhotoViewerSheet`, `JourneyLeaderboardScopeQuery`, `fetchLeaderboard`), `ROAM-13` (`fetchCityStrip`), `RTEAMS-3` (`fetchTeamApplications`), `SALBUM-6` (`fetchStampAlbum`), `JLAND-7` (`JourneyDateFormatterHelper`), `TGOALS-4` (`ExplorationGoalProgressItem`).
- **Owner-gated / Backend-blocked (left):** `RSTAMP-2` / `SCAM-1` / `SALBUM-1` (owner-gated media/image policy), `JSETTLE-1` / `JREPORT-1` (owner-gated referral token), `ROAM-7` (backend-blocked guest nearby read), `PLAYM-2` (backend-blocked `perk` field).

### `member` (`docs/mp-gap/member.md`)
- **Translated (Core + SwiftUI + Tests):**
  - Round 1: `MKT-7-1/3` (`FreeExploreBundleReceiptView`, `MemberGapService`), `PLY-25-2/3/4/5` (`OrientScoreLeaderboardSheetView`, `OrientScoreAppealSheetView`, `OrientScoreSettlementGapSection` owner-gated), `PLY-29-4` (`ReportAppealSheetView`), `MKT-10-1` (`MerchantCouponSummaryTilesView`), `MKT-5-3` (`PlatformPassOrderCancelRefundSheetView`, owner-gated), `FIN-17-3` (`checkInvoiceOrderEligible`).
  - Round 2: `FIN-16-2` / `FIN-18-2` / `FIN-19-1` (`PagedKeepOnRefreshBuffer`, `fetchOrdersPage`, `fetchPointsPage`, `fetchWithdrawalsPage`), `FIN-17-4/8` (`OrderDetailTeamSeatsClubSections`, `OrderDetailExtraActionsModel`), `PLY-23-3/4/6` (`ParticipationDetailGapSections`), `PLY-21-5/13` (`TicketWalletCardSubline`, `StackedPassHorizontalPager`), `PLY-26-5` (`TemplateShelfOperationScope`, `fetchMyTemplates`).
- **Owner-gated (left):** `MKT-3-1` (gift claim), `MKT-4-1/6` (month-card ruling), `MKT-5-3` (pass cancel/refund), `MKT-9-2` (coupon confirm step), `FIN-19-2` (withdrawal apply), `PLY-21-6/8` (wallet team/filter rulings), `PLY-25-2` (orient sync/settle).

## Core Unit Tests (`Tests/CoreTests/MPGap/`)
- `MPGapG1Tests.swift`: `TopicTemplatePreviewData`, `ObjectCardRenameValidator`, `OrientAppealValidator`, `ReportAppealValidator`, `MerchantCouponSummary`, `PlayerContentGapService`, `PlayRoamGapService`, `MemberGapService`.
- `MPGapG1Round2Tests.swift`: tests for all round-1 and round-2 `Core/MPGap` models, validators, helpers, and `PlayerContentRound2Service`, `PlayRoamRound2Service`, `MemberRound2Service` endpoint paths.

## Round 3: Copy & Contract Alignment vs `origin/ui/combined-r7`
- **Copy alignment:** [`docs/mp-gap/copy-g1-player.md`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag3/docs/mp-gap/copy-g1-player.md) (89 MP pages vs `Resources/Localizable.xcstrings` on `origin/ui/combined-r7` + `docs/port/strings/gap-g1-player.json`).
  - Fixed in `gap-g1-player.json`: `objects.category` (`"分类"`), `roamTools.clearCache.confirmTitle` (`"确认清空本机缓存"`).
  - Remaining shared/app-level copy items listed in `copy-g1-player.md` for the coordinator.
- **Contract alignment:** [`docs/mp-gap/contracts-g1-player.md`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag3/docs/mp-gap/contracts-g1-player.md) (476 unique MP endpoint references across `player-content` 174, `play-roam` 167, `member` 135 vs `Core/` on `origin/ui/combined-r7` + `Core/MPGap/`).
  - Fixed in `Core/MPGap/PlayerContent/PlayerContentGapService.swift`: aligned `fetchTopicNearbyTeams` (`GET /api/team/nearby?lat=&lng=&radius=`) and `fetchFreeExploreCatalog` (`GET /api/free-explore/bundle/catalog?topicId=`) to MP GET contracts.
  - Fixed in `Core/MPGap/Member/MemberRound2Service.swift`: added `fetchOrientScoring(sessionID:)` (`GET /api/orient/scoring?sessionId=`).
  - Remaining shared/app-level contract items (`Core/NearbyTeamService.swift`, `Core/PlayerJourneyService.swift`, and un-wired endpoints) listed in `contracts-g1-player.md` for the coordinator.
- **External Swift symbol audit (post-coordinator note):**
  - Checked every external type/case/method/initializer in `Core/MPGap/`, `App/MPGap/`, and `Tests/CoreTests/MPGap/` (`APIError`, `AuthRequestBuilder.isValidToken`, `HTTPTransport`, `PlayWireValue`, `PlayerGapReply`, `CYCachedAsyncImage`, `CYSheetHeader`, `CYColor`, `CYRadius`, `CYSpacing`, `cyPageTitle`, `cyText`) against `Core/` and `App/DesignSystem/`.
  - `APIError`: verified `APIError.invalidRequest` matches `Core/APIConfiguration.swift:3-5` (`APIError.serverMessage` was not used in G1).
  - Fixed `CYCachedAsyncImage`: changed `CYCachedAsyncImage(url: url, role: .cover/.thumbnail)` to `CYCachedAsyncImage(sourceString, role: .cover/.shelf)` matching `App/DesignSystem/CYCachedAsyncImage.swift:61-64, 169-174` (across `TopicTemplateDeckPreviewView`, `PlayerContentRound2Views`, `CityStampTearScratchCardView`, `PlayRoamRound2Views`, `MemberRound2Views`).
  - Fixed `CYSheetHeader`: changed `title: "..."` / `LocalizedStringKey(...)` to `title: Text(...)` matching `App/DesignSystem/CYPlayerKit.swift:346-356` (across `SearchMapExplorerGapView`, `PlayerContentRound2Views`, `PlayToolsAndLeadSheetView`, `RoamSessionToolsSheetView`, `ObjectCardCategoryAndRenameSheets`, `PlayRoamRound2Views`, `OrientScoreGapViews`, `ReportAppealAndCouponSummaryViews`).

## Compile Fix (`docs/mp-gap/compile-errors-r7.md` after merging `origin/ui/combined-r7`)
- Merged `origin/ui/combined-r7` into `gap/g1-player` and resolved `TopicTemplateDeckPreviewView.swift` conflict.
- Verified all 12 G1 errors listed in `docs/mp-gap/compile-errors-r7.md` (`MemberRound2Views.swift:112`, `OrientScoreGapViews.swift:22,88`, `ReportAppealAndCouponSummaryViews.swift:32,184`, `CityStampTearScratchCardView.swift:113`, `ObjectCardCategoryAndRenameSheets.swift:27,82`, `PlayRoamRound2Views.swift:49,125,184`) are fixed.
- `swiftc -parse` and `python3 -B tools/check_design_lint.py` passed with 0 errors.

## Round 4: `audit/parity-r7` Gemini Queue + Audit Contract Fixes
- **Audit sources:** `origin/audit/parity-r7-{player-content,play-roam,member}:docs/audit/parity-r7/<area>.md`.
- **Contract fixes from r7 audits:**
  - `Core/MPGap/PlayRoam/PlayRoamRound2Service.swift`: deleted `fetchRoamHistory` (`RHIST-r7-1`); switched `fetchStampAlbum` to `POST /api/roam/stamp/list` (`SALBUM-6`); switched `fetchTeamApplications` to `POST /api/team/applications` (`RTEAMS-3`).
  - Removed redundant `App/MPGap/PlayRoam/CityStampTearScratchCardView.swift` (`RSTAMP-3`, already native in `RoamStampSlipView`).
  - `Core/MPGap/Member/MemberGapService.swift`: switched `fetchMerchantCouponSummary` to `POST /api/merchant/coupon-summary` (`MKT-10-1`); switched `submitReportAppeal` to `POST /api/community-trust/reports/appeal` (`PLY-29-4`).
  - `Core/MPGap/Member/MemberRound2Service.swift`: switched `fetchOrdersPage` to `POST /api/registration/list` (`FIN-16-2`), `followClubOwner` to `POST /api/user/follow/action` (`FIN-17-4`), `fetchMyTemplates` to `POST /api/template/my-list` (`PLY-26-5`), and `fetchPointsList` to `POST /api/points/list {}` (`FIN-18-2`).
  - `App/MPGap/Member/MemberRound2Views.swift`: replaced hard-coded Chinese literals with localization keys.
- **New Round-4 translations:**
  - `player-content` (`PlayerContentRound4Models.swift`, `PlayerContentRound4Views.swift`): `R7-PC-B3-2` (`MerchantApplyPickerGapView`), `R7-PC-B1-12` (`TopicPostPurchaseRevealView` + `submitMarketingConsent`), `R7-PC-B2-2` (`MerchantJoinContactHostButton` + `contactHost`), `R7-PC-B1-22` (`TopicSharePosterCardView`).
  - `play-roam` (`PlayRoamRound4Models.swift`, `PlayRoamRound4Views.swift`): `JSETTLE-r7-1` (`JourneyFinishOfferResolver`, `JourneyFinishOfferCardView`), `ROAM-13` (`RoamCityStripTabView`), `B3D-1` (`IdentityPinBadge3DParameters`), `OCARDS-2` (`ObjectCardPileAndGridView`).
  - `member` (`MemberRound4Views.swift`): `MKT-7-1` (`FreeExploreCatalogBundleView`), `PLY-26-4` (`TemplateMineCardCoverView`), `MKT-10-5` (`CouponForbiddenPlayerActionView`).
- **Tests:** added `Tests/CoreTests/MPGap/MPGapG1Round4Tests.swift` and updated `MPGapG1Tests.swift` + `MPGapG1Round2Tests.swift`.
- **Merged `origin/ui/combined-r7` (`97ee2bc9e`):** pulled coordinator `Section` header/footer fixes, fixed `PlayerContentRound4Views.swift` `Section { } header: { Text(...) } footer: { ... }`, and added missing `roamHistory.title` to `docs/port/strings/gap-g1-player.json`.

DONE-ROUND-4

## Round 5: `r7-rev-c` Findings + Owner Decisions + MPAsset Annotations
- **Report:** [`docs/mp-gap/round5-g1.md`](file:///Users/fanning/orca/workspaces/native-ios/DES-ag3/docs/mp-gap/round5-g1.md)
- **Closed `origin/review/r7-rev-c:docs/review/r7-rev-c.md` (`owner=Gemini`, G1):**
  - P0s: `F-C01`, `F-C03` (form-encoded POSTs), `F-C04` (`api/im/report`, `api/orient/scoring/appeal`, `api/registration/my-joined`, `api/orient/scoring/session/<id>`), `F-C05` (removed invented `recoverOfficialBroadcast`, `fetchMyTemplateDetail`, `greetRunner`, `fetchCityStrip`), `F-C06` (GET -> POST across merchant/coop/nearby/team/withdrawal endpoints), `F-C07` (param keys `latitude`/`longitude`/`radius`, `activityId`, `teamId`), `F-C26` (removed `URLComponents!` force-unwraps, switched integer IDs to `.integer(Int64(id))`).
  - P2s: `F-C12` (`OrientScoreGapViews` `.confirmationDialog` for `onSync`/`onSettle`), `F-C13` (`.cyText(.micro/.caption)` -> `.cyText(.meta)` across 9 files), `F-C14`/`F-C25` (`NearbyAndHistoryGapViews` `CYAvatarView` replacing monogram), `F-C15` (wired `MPAsset.BannerCover.homeRouteCityPlaceholder`, `MPAsset.BadgeMedal.medalGold`, `MPAsset.MapMarker.dSmapicon`, `MPAsset.BrandLogo.cyLogoMark` after merging `origin/ui/combined-r7` `82388e4a5`).
- **Owner decisions (`owner-decisions-1124.md`):** two-decimal money (`¥39.00`, `¥68.00`) in `JourneyFinishOfferResolver`; GPS arrival lock and TEST-only money writes preserved.
- **Localization & tests:** added `orientScore.syncTasks.confirmTitle`, `orientScore.settleRun.confirmTitle`, `common.cancel` (`zh-Hans` + `en`) to `docs/port/strings/gap-g1-player.json`; updated `MPGapG1Round2Tests.swift` and `MPGapG1Round4Tests.swift`.

DONE-ROUND-5
