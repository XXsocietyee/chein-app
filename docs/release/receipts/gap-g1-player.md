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

DONE-ROUND-2
