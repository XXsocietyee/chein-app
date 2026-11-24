# Mount Hooks — `gap/g1-player`

All new SwiftUI views live in `App/MPGap/<Area>/` (no existing files edited). The coordinator mounts them at integration:

## 1. `player-content`
- **`App/DiscoveryTemplateBrowserView.swift`** (template row tap when preview mode is active)
  - Hook: `TopicTemplateDeckPreviewView(preview:onViewDetail:onUseTemplate:)` (`App/MPGap/PlayerContent/TopicTemplateDeckPreviewView.swift`)
- **`App/TopicXcxSections.swift`** (`routeTab` section)
  - Hook: `TopicRouteMapAndTeamsSection(pins:completedCount:totalCount:isFreeExplore:teams:merchantCards:onSelectPin:onOpenAllTeams:onSelectMerchant:)` (`App/MPGap/PlayerContent/TopicRouteMapAndTeamsSection.swift`)
- **`App/RegistrationSheetView.swift`** (inside `Form` body)
  - Hook: `ActivityRegistrationGapSections(childAgeRange:selectedChildAge:deliveryItems:merchantClosed:clubPriorityNotice:coveredByPass:hostReservation:isBusy:onRequestHost:onCancelHostWaitlist:)` (`App/MPGap/PlayerContent/RegistrationGapSections.swift`)
- **`App/OfficialEventDetailView.swift`** (after event description section)
  - Hook: `OfficialEventLeaderboardSection(rows:myRank:)` (`App/MPGap/PlayerContent/TopicAndOfficialGapSections.swift`)
- **`App/PublisherLifecycleViews.swift`** (`PublisherPricingView` form)
  - Hook: `TopicPricingGapSection(ticketFields:extraStatus:canConfirmPricing:)` (`App/MPGap/PlayerContent/TopicAndOfficialGapSections.swift`)
- **`App/MerchantContentViews.swift`** (`MerchantContentProjectView`, owner-gated)
  - Hook: `MerchantHostWorkbenchSection(writesEnabled: false, onAction:)` (`App/MPGap/PlayerContent/TopicAndOfficialGapSections.swift`)

## 2. `play-roam`
- **`App/PlayExperienceView.swift`** / `App/PlayInPlayTools.swift` (`⋯` tools sheet)
  - Hook: `PlayToolsAndLeadSheetView(...)` (`App/MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift`)
- **`App/RoamLiveSessionView.swift`** (`更多` toolbar sheet)
  - Hook: `RoamSessionToolsSheetView(...)` (`App/MPGap/PlayRoam/RoamSessionToolsSheetView.swift`)
- **`App/RoamSubpageParityViews.swift`** (`RoamCityStampFlowView` slip section)
  - Hook: `CityStampTearScratchCardView(slip:exchangeEnabled:onSaveToAlbum:onComplete:)` (`App/MPGap/PlayRoam/CityStampTearScratchCardView.swift`)
- **`App/ObjectCardViews.swift`** (category filter sheet & rename sheet)
  - Hooks: `ObjectCardCategorySheetView(...)` and `ObjectCardRenameSheetView(...)` (`App/MPGap/PlayRoam/ObjectCardCategoryAndRenameSheets.swift`)

## 3. `member`
- **`App/FreeExploreBundleLaunchView.swift`** / `App/MPReviewedPageScreen.swift` (`free-explore?requestId=`)
  - Hook: `FreeExploreBundleReceiptView(summary:onReserveUnit:onSwapMerchant:)` (`App/MPGap/Member/FreeExploreBundleGapSections.swift`)
- **`App/OrientScoreView.swift`** (leaderboard sheet, appeal sheet, owner-gated sync/settle section)
  - Hooks: `OrientScoreLeaderboardSheetView(...)`, `OrientScoreAppealSheetView(...)`, `OrientScoreSettlementGapSection(...)` (`App/MPGap/Member/OrientScoreGapViews.swift`)
- **`App/MemberReportProgressDetailView.swift`** (`提交申诉` sheet)
  - Hook: `ReportAppealSheetView(...)` (`App/MPGap/Member/ReportAppealAndCouponSummaryViews.swift`)
- **`App/CouponManagementView.swift`** (above coupon list)
  - Hook: `MerchantCouponSummaryTilesView(summary:)` (`App/MPGap/Member/ReportAppealAndCouponSummaryViews.swift`)
- **`App/PassMarketViews.swift`** (`PassOrderDetailView`, owner-gated)
  - Hook: `PlatformPassOrderCancelRefundSheetView(kind:writesEnabled: false, onSubmit:onClose:)` (`App/MPGap/Member/ReportAppealAndCouponSummaryViews.swift`)
