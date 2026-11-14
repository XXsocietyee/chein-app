# ui-cur-states

Handover 51. Branch `ui/cur-states`. Parent `9209d33cb2d7ceed6f95a1b9d90b556e531a63b0` (`origin/ui/main`).

Player screens named in `docs/parity/page-map.csv` were the scope. A screen was checked only when its view was opened. States were added only on those views, and only where the view itself showed a gap. Existing `CYEmptyState`, `CYLoadingState`, `CYSkeleton`, and the screen's own read wrapper were reused. `ReviewedAreaSwitch` was not redeclared. `RegionalLaunchConfiguration`, `AppSession`, and `AppCompositionRoot` were not edited. No new Swift file was added, so `tools/generate_project.py` was not required. Money stays closed: wallet, withdrawal, invoice, settlement, pricing, and order screens were not opened.

Unknown values that the opened view printed as `0` or as a blank string now use an em dash (`—`). A decoded `0` stays `0`.

`python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` passed. `swiftc` is not installed, so nothing was type-checked.

## Screens fixed

| Screen | What changed |
|---|---|
| `App/OfficialEventDetailView.swift` | Checked and fixed. An unknown collective percent or count is an em dash. The progress bar is drawn only when the fraction is known, so a missing fraction is no longer a 0 bar. |
| `App/PlayKitTimedChallengeView.swift` | Checked and fixed. Missing seconds, the type-in prompt, attempts, the try cap, and stopwatch tolerance show an em dash. A literal 0 stays 0. Missing seconds no longer pass the type-in start check as 0. Reaction rounds still fall back to 3 because the view says to keep that fallback. |
| `App/NearbyTeamViews.swift` | Checked and fixed. The review title was a blank string and now uses the existing untitled label. NearbyMineMembersText, which this screen draws, no longer prints a missing joined count as 0. Recruiting already has loading, empty, and retry. |
| `App/PlayExperienceView.swift` | Checked and fixed. The chapter filter appended a blank name. It now uses an em dash. This screen is a live session, not a fetched list. |
| `App/PlayerJourneyViews.swift` | Checked and fixed. On completed history, a missing done count or total is an em dash, and a real 0 stays 0. A missing done count is not treated as finished. The participation list and detail already have loading, empty, and retry. |
| `App/RoamPassportToolsViews.swift` | Checked and fixed. An anniversary row with no title was blank and now shows an em dash. Loading, denied, error plus retry, and the offline example were already on the page. |
| `App/RoamPassportPrivateToolsViews.swift` | Checked and fixed. An opened capsule with no body, and a seal date that was missing, were blank and now show an em dash. Issue plus retry, sign-in, and not-configured were already on the page. |
| `App/SquareReportProgressView.swift` | Checked and fixed. A failure now uses CYEmptyState with retry. The skeleton and the empty state were already there. |
| `App/MemberReportProgressDetailView.swift` | Checked and fixed. The failure state now retries from CYEmptyState. The skeleton and the empty timeline were already there. |
| `App/SocialPublicProfileView.swift` | Checked and fixed. A missing level is an em dash, the same as the identity card. Counters already use an em dash. SocialReadScreen covers loading and error plus retry. A bad link is the empty state. |

## Every page-map screen

| Mini-program path | Native screen | Result |
|---|---|---|
| `pages/index/index` | `App/HomeFeedView.swift` | Checked. Loading skeleton, empty, stream retry, and the offline unavailable state are in the view. Unknown price and time are already an em dash. No change. |
| `pages/template/index` | `App/DiscoveryTemplateBrowserView.swift` | Left. Not opened. |
| `pages/talent/list/index` | `App/ClubHomeView.swift` | Checked. ClubReadScreen covers loading, error plus retry, and the unconfigured offline state. Empty clubs, empty events, and locality offline plus retry are on the page. An omitted count is already an em dash. No change. |
| `pages/member/index/index` | `App/AccountView.swift` | Checked. The identity card has loading, failed plus retry, and an em dash for an unknown level, city, counts, and balance. The rest of the page is navigation. No change. |
| `pages/roam/index` | `App/RoamBrowserView.swift` | Checked. Skeleton, RoamStatusView with retry, empty plus retry, and the offline example. An unknown peek count is already an em dash. No change. |
| `pages/privacy/index` | `App/PrivacyProtectionView.swift` | Checked. Bundled privacy text and document links. It does not load a remote list. No change. |
| `pages/agreement/index` | `App/SettingsLegalDocumentView.swift` | Left. Not opened. |
| `pages/deregister/index` | `App/AccountComplianceViews.swift` | Left. Not opened. |
| `pages/team/detail/index` | `App/TeamHomeView.swift` | Checked. Loading, empty, refresh, and TeamNotice for a failure. Detail uses TeamPageStateView. No change. |
| `pages/team/join/index` | `App/TeamHomeView.swift` | Checked. Loading, empty, refresh, and TeamNotice for a failure. Detail uses TeamPageStateView. No change. |
| `pages/play/index` | `App/PlayExperienceView.swift` | Checked and fixed. The chapter filter appended a blank name. It now uses an em dash. This screen is a live session, not a fetched list. |
| `pages/play/merchant/index` | `App/PlayStoreDayMerchantView.swift` | Left. Not opened. |
| `pages/play/circle/index` | `App/PlayPlayerAndCircleViews.swift` | Left. Not opened. |
| `pages/play/poi-challenge/index` | `App/PlayKitTimedChallengeView.swift` | Checked and fixed. Missing seconds, the type-in prompt, attempts, the try cap, and stopwatch tolerance show an em dash. A literal 0 stays 0. Missing seconds no longer pass the type-in start check as 0. Reaction rounds still fall back to 3 because the view says to keep that fallback. |
| `pages/activity/detail/index` | `App/ActivityDetailView.swift` | Checked. CYPhase covers loading and failed plus retry. An unknown meeting point and registration count are already an em dash. No change. |
| `pages/activity/baoming/baoming` | `App/RegistrationSheetView.swift` | Left. Money stays closed. Not opened. |
| `pages/activity/list/index` | `App/OfficialEventsBrowserView.swift` | Checked. OfficialReadScreen supplies loading and error plus retry. Each tab has an empty state, and the list shows the offline-example notice. A missing participant count is already not 0. No change. |
| `pages/activity/official-detail/index` | `App/OfficialEventDetailView.swift` | Checked and fixed. An unknown collective percent or count is an em dash. The progress bar is drawn only when the fraction is known, so a missing fraction is no longer a 0 bar. |
| `pages/activity/official-inbox/index` | `App/OfficialPrivateViews.swift` | Left. Not opened. |
| `pages/activity/official-mine/index` | `App/OfficialPrivateViews.swift` | Left. Not opened. |
| `pages/activity/official-organizer/index` | `App/OfficialOrganizerConsoleView.swift` | Left. Not opened. |
| `subpackageA/pages/myproject/index` | `App/CreatorContentViews.swift` | Left. Not opened. |
| `subpackageA/pages/infomation/infomation` | `App/SocialGuideViews.swift` | Checked. SocialReadScreen covers loading, error plus retry, and the offline example. The document list and the detail page have empty phases. No change. |
| `subpackageA/pages/infomationdetail/infomationdetail` | `App/SocialGuideViews.swift` | Checked. SocialReadScreen covers loading, error plus retry, and the offline example. The document list and the detail page have empty phases. No change. |
| `subpackageA/pages/assetcenter/income-detail/income-detail` | `App/WalletCommerceViews.swift` | Left. Money stays closed. Not opened. |
| `subpackageA/pages/assetcenter/earnings/index` | `App/WalletCommerceViews.swift` | Left. Money stays closed. Not opened. |
| `subpackageA/pages/assetcenter/analysis/index` | `App/WalletCommerceViews.swift` | Left. Money stays closed. Not opened. |
| `subpackageP3/pages/growthcenter/index/index` | `App/GrowthCenterView.swift` | Checked. Skeleton, GrowthCenterIssueView with retry, the offline example, and growth.unknown for a missing number. No change. |
| `subpackageP3/pages/growthcenter/leaderboard/index` | `App/GrowthLeaderboardView.swift` | Checked. Skeleton, issue with retry, empty, and the offline example. Scores go through GrowthCenterInteger. No change. |
| `subpackageP3/pages/stamp-camera/index/index` | `App/RoamStampCameraView.swift` | Left. Not opened. |
| `subpackageP3/pages/stamp-album/index/index` | `App/RoamStampViews.swift` | Left. Not opened. |
| `subpackageP3/pages/badge-wall/index/index` | `App/ObjectBadgeViews.swift` | Checked. ProfileReadScreen covers loading, sign-in, unavailable, and error plus retry. The wall has an empty state. No change. |
| `subpackageP3/pages/badge-3d/index` | `App/ObjectBadgeViews.swift` | Checked. ProfileReadScreen covers loading, sign-in, unavailable, and error plus retry. The wall has an empty state. No change. |
| `subpackageP3/pages/object-cards/index/index` | `App/ObjectCardViews.swift` | Left. Not opened. |
| `subpackageB/pages/im/list/index` | `App/MessagingHomeView.swift` | Checked. MessagingReadScreen covers loading and error plus retry. The list has an empty segment and a no-match empty state. A failed read is the offline path. No change. |
| `subpackageB/pages/im/chat/index` | `App/MessagingHistoryView.swift` | Left. Not opened. |
| `pages/publish/fabu/index` | `App/ProjectEditView.swift` | Left. Not opened. |
| `pages/publish/simple/index` | `App/PublishingModesViews.swift` | Left. Not opened. |
| `pages/publish/temp/index` | `App/TemplateAuthoringView.swift` | Left. Not opened. |
| `pages/publish/activity/index` | `App/PublishingModesViews.swift` | Left. Not opened. |
| `pages/publish/topicadd/topicadd` | `App/ProjectEditView.swift` | Left. Not opened. |
| `pages/publish/template-intro/index` | `App/TemplateAuthoringIntroExperience.swift` | Left. Not opened. |
| `pages/club/apply/index` | `App/ClubGovernanceViews.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/badges/index` | `App/ClubBadgeManagementView.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/create/index` | `App/ClubOperationsViews.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/customer-detail/index` | `App/ClubOpsCustomerViews.swift` | Left. Not opened. |
| `pages/club/customers/index` | `App/ClubOpsCustomerViews.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/detail/index` | `App/ClubDetailView.swift` | Checked. ClubReadScreen covers loading and error plus retry. Posts and events have empty states. The member line already uses an em dash. No change. |
| `pages/club/edit/index` | `App/ClubOperationsViews.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/enroll/index` | `App/ClubEnrollmentView.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/checkin-detail/index` | `App/ClubGovernanceViews.swift` | Left. Not opened. |
| `pages/club/event-ops/index` | `App/ClubOpsEventView.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/governance/index` | `App/ClubOpsGovernanceSections.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/group-code/index` | `App/ClubGovernanceViews.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/join-requests/index` | `App/ClubManagementView.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/notify/index` | `App/ClubOpsNotifySections.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/roles/index` | `App/ClubOpsGovernanceSections.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/settlement/index` | `App/ClubOpsSettlementViews.swift` | Left. Money stays closed. Not opened. |
| `pages/club/topic-detail/index` | `App/ClubGovernanceViews.swift` | Left. Not opened. |
| `pages/club/topic-story/index` | `App/ClubGovernanceViews.swift` | Left. Club operations, not the player club tab. Not opened. |
| `pages/club/workbench/index` | `App/ClubDetailView.swift` | Checked. ClubReadScreen covers loading and error plus retry. Posts and events have empty states. The member line already uses an em dash. No change. |
| `pages/topic/index/index` | `App/TopicDetailView.swift` | Left. Not opened. |
| `pages/topic/merchantinfo/merchantinfo` | `App/MerchantContentViews.swift` | Left. Not opened. |
| `pages/topic/merchantapply/index` | `App/MerchantContentEditor.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/topic/pricing/index` | `App/PublisherLifecycleViews.swift` | Left. Money stays closed. Not opened. |
| `pages/topic/pricing/partner/index` | `App/PublisherLifecycleViews.swift` | Left. Money stays closed. Not opened. |
| `pages/merchant/index/index` | `App/MerchantHomeView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/apply/index` | `App/MerchantOnboardingView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/ledger/index` | `App/MerchantBusinessViews.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/ledger/order-detail/index` | `App/MerchantBusinessViews.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/ledger/batch-detail/index` | `App/MerchantSettlementProgressView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/aftercare/index` | `App/MerchantBusinessViews.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/predict/index` | `App/MerchantPredictionInboxView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/aftercare/detail/index` | `App/MerchantAftercareProgressView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/profile/index` | `App/PublicMerchantHomeView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/marketing/index` | `App/MerchantMarketingView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/reviews/index` | `App/MerchantBusinessViews.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/marketing/ai-insight/index` | `App/MerchantMarketingView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/relation/index` | `App/CoopRelationDiscoveryView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/citynode/index` | `App/MerchantCityNodeHubView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/citynode/create/index` | `App/MerchantCityNodeCreateView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/decor/index` | `App/MerchantOperationsViews.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/decor/ai-npc/index` | `App/MerchantStoreCharacterView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/decor/coop-setting/index` | `App/MerchantOperationsViews.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/decor/gallery/index` | `App/MerchantOperationsViews.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/decor/perks/index` | `App/MerchantOperationsViews.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/coop-center/index` | `App/MerchantCoopCenterView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/customer/index` | `App/MerchantBusinessViews.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/game-node/index` | `App/MerchantGameNodeView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/customer/detail/index` | `App/MerchantCustomerDetailSections.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/verify-records/index` | `App/MerchantBusinessViews.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/crm-campaigns/index` | `App/MerchantEngagementViews.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/merchant/team/index` | `App/MerchantBusinessViews.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `pages/coop/list/index` | `App/CooperationBrowserView.swift` | Left. Not opened. |
| `pages/coop/invite-detail/index` | `App/CooperationInviteDetailView.swift` | Left. Not opened. |
| `pages/coop/invite/index` | `App/CooperationContextualViews.swift` | Left. Not opened. |
| `pages/coop/nearby/index` | `App/NearbyMerchantView.swift` | Left. Not opened. |
| `pages/coop/finance/index` | `App/CoopFinanceProfitView.swift` | Left. Not opened. |
| `pages/coop/settlement-detail/index` | `App/CoopSettlementDetailView.swift` | Left. Money stays closed. Not opened. |
| `pages/coop/withdraw/index` | `App/CoopWithdrawShellViews.swift` | Left. Money stays closed. Not opened. |
| `pages/coop/withdraw/records/index` | `App/CoopWithdrawShellViews.swift` | Left. Money stays closed. Not opened. |
| `pages/square/list/index` | `App/SquareBrowserView.swift` | Left. Not opened. |
| `pages/square/detail/index` | `App/SquareDetailView.swift` | Left. Not opened. |
| `pages/search2/index` | `App/GlobalSearchView.swift` | Left. Not opened. |
| `pages/search2/result/index` | `App/GlobalSearchView.swift` | Left. Not opened. |
| `pages/searchmap/index` | `App/SearchMapExplorerView.swift` | Left. Not opened. |
| `pages/templatedetail/templatedetail` | `App/DiscoveryTemplateDetailView.swift` | Checked. The play detail and the topic preview use a skeleton, DiscoveryErrorView with retry, and an unconfigured state. No change. |
| `pages/templatedetail/topic-preview/index` | `App/DiscoveryTemplateDetailView.swift` | Checked. The play detail and the topic preview use a skeleton, DiscoveryErrorView with retry, and an unconfigured state. No change. |
| `pages/templatedetail/topic-detail/index` | `App/DiscoveryTemplateDetailView.swift` | Checked. The play detail and the topic preview use a skeleton, DiscoveryErrorView with retry, and an unconfigured state. No change. |
| `pages/address/address` | `App/ProfileParticipantsView.swift` | Left. Not opened. |
| `pages/addressinfo/addressinfo` | `App/ParticipantFormView.swift` | Left. Not opened. |
| `pages/shezhi/shezhi` | `App/SettingsView.swift` | Checked. Loading, error, and an unknown role are a status line. The home fact passes failed as false, so there is no remote failure to retry. No change. |
| `pages/shezhi/about/index` | `App/SettingsAboutView.swift` | Left. Not opened. |
| `pages/shezhi/marketing/index` | `App/MarketingConsentOriginalPresentation.swift` | Left. Not opened. |
| `pages/gerenziliao/gerenziliao` | `App/ProfileEditView.swift` | Left. Not opened. |
| `pages/userinfo/userinfo` | `App/SocialPublicProfileView.swift` | Checked and fixed. A missing level is an em dash, the same as the identity card. Counters already use an em dash. SocialReadScreen covers loading and error plus retry. A bad link is the empty state. |
| `pages/mylike/mylike` | `App/AccountCollectionFavoritesView.swift` | Left. Not opened. |
| `pages/crop/index` | `App/TemplateImageCropView.swift` | Left. Not opened. |
| `subpackageMember/free-explore/index` | `App/FreeExploreBundleLaunchView.swift` | Left. Not opened. |
| `subpackageMember/character/index` | `App/CharacterCardReadbackView.swift` | Left. Not opened. |
| `subpackageMember/orient-score/index` | `App/OrientScoreView.swift` | Left. Not opened. |
| `subpackageMember/invoice/index` | `App/InvoiceLaunchHistoryView.swift` | Left. Money stays closed. Not opened. |
| `subpackageMember/invoice-detail/index` | `App/InvoiceLaunchDetailView.swift` | Left. Money stays closed. Not opened. |
| `subpackageMember/invoice-apply/index` | `App/InvoiceLaunchApplyView.swift` | Left. Money stays closed. Not opened. |
| `subpackageMember/invoice-titles/index` | `App/InvoiceLaunchTitlesView.swift` | Left. Money stays closed. Not opened. |
| `subpackageMember/invoice-title-edit/index` | `App/InvoiceLaunchTitleEditor.swift` | Left. Money stays closed. Not opened. |
| `subpackageMember/complaint/index` | `App/ProfileComplaintPreparationView.swift` | Left. Not opened. |
| `subpackageMember/coupon-wallet/index` | `App/AccountCollectionCouponsView.swift` | Left. Not opened. |
| `subpackageMember/coupon-qr/index` | `App/CouponCodeView.swift` | Left. Not opened. |
| `subpackageMember/coupon/coupon` | `App/CouponManagementView.swift` | Left. Merchant screen, not a player screen. Not opened. |
| `subpackageMember/couponInfo/couponInfo` | `App/CouponManagementView.swift` | Left. Not opened. |
| `subpackageMember/mycanyu/mycanyu` | `App/PlayerJourneyViews.swift` | Checked and fixed. On completed history, a missing done count or total is an em dash, and a real 0 stays 0. A missing done count is not treated as finished. The participation list and detail already have loading, empty, and retry. |
| `subpackageMember/mycanyuinfo/mycanyuinfo` | `App/PlayerJourneyViews.swift` | Checked and fixed. On completed history, a missing done count or total is an em dash, and a real 0 stays 0. A missing done count is not treated as finished. The participation list and detail already have loading, empty, and retry. |
| `subpackageMember/myinvite/myinvite` | `App/SocialInviteHistoryView.swift` | Left. Not opened. |
| `subpackageMember/mytemplate/mytemplate` | `App/TemplateAuthoringMineView.swift` | Left. Not opened. |
| `subpackageMember/order/order` | `App/ProfileOrdersView.swift` | Left. Money stays closed. Not opened. |
| `subpackageMember/orderinfo/orderinfo` | `App/OrderLifecycleView.swift` | Left. Money stays closed. Not opened. |
| `subpackageMember/points-history/index` | `App/ProfileWeeklyPointsSection.swift` | Left. Not opened. |
| `subpackageMember/report-mine/index` | `App/SquareReportProgressView.swift` | Checked and fixed. A failure now uses CYEmptyState with retry. The skeleton and the empty state were already there. |
| `subpackageMember/report-detail/index` | `App/MemberReportProgressDetailView.swift` | Checked and fixed. The failure state now retries from CYEmptyState. The skeleton and the empty timeline were already there. |
| `subpackageMember/appeal-mine/index` | `App/MemberScoreAppealListView.swift` | Left. Not opened. |
| `subpackageMember/signup/index` | `App/TicketWalletView.swift` | Checked. Login, not configured, skeleton, issue plus retry, and empty or filtered-empty copy. No change. |
| `subpackageMember/tixian/tixian` | `App/WithdrawalSupportLandingView.swift` | Left. Money stays closed. Not opened. |
| `subpackageMember/tixianjilu/tixianjilu` | `App/WithdrawalHistoryView.swift` | Left. Money stays closed. Not opened. |
| `subpackageRoam/citynode-code/index` | `App/VerificationCodeView.swift` | Checked. A skeleton while loading. Review, expired, paused, failed, and invalid offer retry. It shows one code, not a list. No change. |
| `subpackageRoam/history/index` | `App/RoamHistoryViews.swift` | Left. Not opened. |
| `subpackageRoam/poi-detail/index` | `App/RoamItemDetailView.swift` | Left. Not opened. |
| `subpackageRoam/session/index` | `App/RoamSubpageParityViews.swift` | Left. Not opened. |
| `subpackageRoam/nearby/index` | `App/NearbyTeamViews.swift` | Checked and fixed. The review title was a blank string and now uses the existing untitled label. NearbyMineMembersText, which this screen draws, no longer prints a missing joined count as 0. Recruiting already has loading, empty, and retry. |
| `subpackageRoam/citystamp/index` | `App/RoamSubpageParityViews.swift` | Left. Not opened. |
| `subpackageRoam/my-teams/index` | `App/NearbyTeamViews.swift` | Checked and fixed. The review title was a blank string and now uses the existing untitled label. NearbyMineMembersText, which this screen draws, no longer prints a missing joined count as 0. Recruiting already has loading, empty, and retry. |
| `subpackageRoam/official-routes/index` | `App/RoamBrowserView.swift` | Checked. Skeleton, RoamStatusView with retry, empty plus retry, and the offline example. An unknown peek count is already an em dash. No change. |
| `subpackageRoam/official-route/index` | `App/RoamSubpageParityViews.swift` | Left. Not opened. |
| `subpackageTools/capsule/index` | `App/RoamPassportPrivateToolsViews.swift` | Checked and fixed. An opened capsule with no body, and a seal date that was missing, were blank and now show an em dash. Issue plus retry, sign-in, and not-configured were already on the page. |
| `subpackageTools/monthly-recap/index` | `App/RoamPassportToolsViews.swift` | Checked and fixed. An anniversary row with no title was blank and now shows an em dash. Loading, denied, error plus retry, and the offline example were already on the page. |
| `subpackageTools/exploration-goals/index` | `App/RoamPassportPrivateToolsViews.swift` | Checked and fixed. An opened capsule with no body, and a seal date that was missing, were blank and now show an em dash. Issue plus retry, sign-in, and not-configured were already on the page. |
| `subpackageTools/anniversary/index` | `App/RoamPassportToolsViews.swift` | Checked and fixed. An anniversary row with no title was blank and now shows an em dash. Loading, denied, error plus retry, and the offline example were already on the page. |
| `subpackageTools/exploration-export/index` | `App/RoamExplorationExportView.swift` | Left. Not opened. |
| `pages/templatedetail2/templatedetail2` | `App/DiscoveryTemplateDetailView.swift` | Checked. The play detail and the topic preview use a skeleton, DiscoveryErrorView with retry, and an unconfigured state. No change. |
| `subpackageMember/signupInfo/signupInfo` | `App/TicketWalletView.swift` | Checked. Login, not configured, skeleton, issue plus retry, and empty or filtered-empty copy. No change. |
| `subpackageMember/signupInfo2/signupInfo2` | `App/TicketWalletView.swift` | Checked. Login, not configured, skeleton, issue plus retry, and empty or filtered-empty copy. No change. |
| `pages/topic/settlement/index` | `App/CoopSettlementDetailView.swift` | Left. Money stays closed. Not opened. |
| `pages/talent/search/index` | `App/GlobalSearchView.swift` | Left. Not opened. |

## 中文

只改了打开过的玩家页。未知数字或标题不再显示成 0 或空白，改为破折号；服务器给出的 0 仍是 0。加载、空、失败重试、离线沿用页面里已有的空态和错误态。商家页、俱乐部运营页和资金页没有打开。本机没有 swiftc，没有做编译。
