# parity-a — deep links + dead player screens (parity-2 §1b, §2)

Branch `ui/parity-a` = `origin/ui/g-partials` (`6adbae522`) + this package. Inputs: `docs/release/parity-2.md` on
`origin/docs/parity2` (`d1a1d0e73`); mini-program `chengyinhub-xcx` at hengyin `92eda9126` (local partial checkout, plus
`/data/workspace/capgraph/hengyin/chengyinhub-xcx` on the `work` VPS, read-only, for `pages/team/detail`,
`subpackageMember/components/cy/team-report-sheet`, `subpackageMember/utils/team-up.js`,
`subpackageMember/components/cy/scene-member-order-detail`, `pages/publish/simple`, `subpackageRoam/session`).

Code only. No `xcodebuild` was run; the integrator compiles. `App/AppSession.swift` and `App/AppCompositionRoot.swift` are
unchanged. Nothing was redeclared from `origin/ui/mount-g45` or `origin/ui/cloud-g6`.

**Grants.** This package adds no request and no API path: the router only opens existing screens, and the team report sheet
uses the existing `POST /api/team/report` lease (`TeamReportSubmission`, already `.liveInProduction` in
`ChinaReviewedRouteCapability`). `ReviewedPlayerWriteLeases`, `ChinaReviewedRouteCapability` and the shipped-China
composition test are unchanged; money stays refused.

**Strings.** No new keys. Every new view reuses existing en + zh-Hans keys (`mp.route.unavailable`, `mpd.aigc.label`,
`mpfresh.teamReport.*`, `walkingAuthor.*`, `nativeNav.*`).

## 1. Deep-link router

| Item | Native file | Host / entry id | State |
|---|---|---|---|
| Core link table: every MP page with a parity screen (12 pages: video-bounty, passes, pass, gift, membership, library, reveal, journey landing / seats / promo / report / settle), allowed + required keys, canonical ids, 512-unit cap, no control chars | `Core/MiniProgramPageLink.swift` | `MiniProgramPageLink.reviewedPages` | DONE |
| `NativeEntryIntent.miniProgramPage` from internal paths, push taps and verified universal links | `Core/NativeEntryRouting.swift`, `Core/NativeNavigationCompletion.swift` (`NativeNavigationContract.parse`) | — | DONE |
| Router → `MPParityRoute(miniProgramPath:query:)` → `MPParityDestination` (bindings re-installed with `MPParityPassEnvironment`, since the root sheet sits outside the player root environment) | `App/MPParityDeepLinkEntry.swift` (`MPParityRoute(link:)`, `MPParityPageEntry`) | `NativeEntryLandingView` sheet, `mp.deepLink.page` | DONE |
| `onOpenURL`: `chein://mp/<page>?<query>` | `AppSession.receiveMiniProgramPageURL` (called first in `receiveCheinURL`, `App/AppSession+DeepLink.swift`) | root `onOpenURL` | DONE |
| Universal links (`onContinueUserActivity`) | `AppSession.receiveUniversalLink`: a path that `nativeEntryLinkPolicy` parses routes, everything else goes to the WeChat drivers as before | root `onContinueUserActivity` | PARTIAL: `nativeEntryLinkPolicy` has no verified origin yet (`verifiedHTTPSOrigins: []`), so no https link routes until the associated domain is approved. Unchanged behaviour until then. |
| Notification tap | `MPNotificationTapRouter` (`UNUserNotificationCenterDelegate.didReceive` only; `willPresent` is not implemented, so foreground presentation is unchanged). Attached in `QuestifyApp.init` so a launch tap is delivered; the session is installed on root appear and a pending intent replays then. Routes through `PushTapRouter(routeKeys: ["page"])` (source path only, never a scheme or host). | root | PARTIAL: the backend has not published a push payload key. `page` is the mini-program subscribe-message field; change `MPNotificationTapRouter.routeKeys` when the contract exists. |
| `subpackageMember/market/gift/index?token=` (§1b) | `PassGiftClaimHost` | deep link → `.gift(token:)` | DONE (receive view). Claim stays gated (`MPCommerceGate.claimsEnabled` → `passGift.claimOff`); no purchase entry. |
| `subpackageJourney/pages/landing/index` (§1b) | `JourneyLandingHost` | deep link → `.journeyLanding`; also `chein://landing?k=…` / `chein://referral|gift|seat/…`: `replayDeepLink` now calls `session.openJourneyLanding` after the intake note | DONE. Opening the landing claims, pays or starts nothing. |
| `subpackagePass/reveal/index` | `PassRevealView` | deep link takes no query | DONE with a limit: `mode=paid&count&until` from a link is rejected, because paid facts in a URL would be unverified. |
| Core test table (every mapped page, each entry, rejection rules) | `Tests/CoreTests/MiniProgramPageLinkTests.swift` | — | DONE (not run here; no new request, so no stub-transport test applies) |
| App test: every reviewed page maps to a route; gift and landing reachable; reveal carries no paid facts | `Tests/AppUnitTests/MPParityDeepLinkRouteTests.swift` | — | DONE (integrator runs) |

## 2. Dead player screens (37)

| View | Native file | Host / entry id | State |
|---|---|---|---|
| `TeamReportReasonSheet` | `App/TeamReportReasonSheet.swift` | Team detail `TeamOrientBoardSection` (`team.orient.report`, non-leader) and the nearby team card `NearbyTeamReportButton` (`nearby.team.report.<id>`, non-leader) | DONE. Ports `team-report-sheet` exactly: five fixed reasons sent verbatim. The free-text sheets it replaces (`TeamOrientBoardSection.reportSheet`, `NearbyTeamReportSheet`) were removed. |
| `TeamReportEntryButton` | same | — | OBSOLETE → `NearbyTeamReportButton` / `team.orient.report`, which keep the source `!leader` rule this button lacks |
| `NativeStoryWalkingAuthorEntry` | `App/NativeStoryWalkingAuthorView.swift` | `ProjectEditView` author entries, after `NativeRpgPassiveRulesAuthorEntry` (full edit only) | DONE |
| `SessionTeamCreateView` | `App/SessionTeamViews.swift` | — | HIDDEN. Source entry is 「和队友一起出发」 in the order detail (`scene-member-order-detail.startOrderTeam`, `teamOpen` = activity registration, status 2, not completed, `teamMode` 1/2). Natively nothing can create a team: `TeamHTTPService` is never composed, `makeTeamCoordinator` returns a `TeamReadOnlyService` (`submit` → `.notSent`), and the approved branch has no `creationLoader`. Composing the writer needs `AppSession` private members (`teamJournal`, `orderLifecycleService`, `currentTeamSession`), which this package may not grow. A nil capability hides the entry. |
| `CityNeutralTaskEntry` | `App/CityNeutralTaskView.swift` | — | OBSOLETE → `CityPlayerView` `city.neutral.entry` (`CityNeutralTaskRuntimeHostView`) |
| `CityOnsiteTaskEntry` | `App/CityOnsiteTaskView.swift` | — | OBSOLETE → `city.onsite.entry` (`CityOnsiteTaskRuntimeHostView`) |
| `CityTaskHistoryEntry` | `App/CityTaskHistoryView.swift` | — | OBSOLETE → `city.history.entry` (`CityTaskHistoryRuntimeHostView`) |
| `CityParticipationRecoveryView` | `App/CityParticipationRecoveryView.swift` | — | OBSOLETE → recovery rows inside `CityParticipationFormView` (`city.participation.entry` → `CityParticipationRuntimeHostView`) |
| `TemplateImageCropView` (MP `pages/crop`) | `App/TemplateImageCropView.swift` | — | OBSOLETE → `MiniCropView` (the `pages/crop` port) via `CreatorCropExportView` in `TemplateMediaReviewPanel`; avatar and cover use `ProfileAvatarCropView` / `ProfileLocalCoverCropView`, nodes `ProjectNodeImageCropView`. `page-map.csv` should point `pages/crop/index` at `App/MiniCropView.swift`. |
| `ProfileBadgesView`, `ProfileBadgeDetailView` | `App/ProfileBadgesView.swift` | — | OBSOLETE → `ObjectBadgeWallView` (mounted from `ProfileAccountLinks`, `ProfileSelfMedalsSection`, `RoamBadgeWallDestination`) |
| `NativeFriendSessionEntry` | `App/NativeFriendSessionEntry.swift` | — | OBSOLETE → `SessionMessagingEntry` friends toolbar → `NativeFriendSessionDestination` (same destination) |
| `ClubDetailOverviewFactsGridView` | `App/ClubDetailTabBar.swift` | — | OBSOLETE → `ClubOverviewFactsGrid` in `ClubDetailView` (主理人 / 类型 / 城市, unknown = `—`) |
| `CYOfflineBanner` | `App/DesignSystem/CYSharedStates.swift` | — | OBSOLETE → `offlineCapsule(reachability)` on the player root |
| `SearchMapOfflineBannerView` | `App/SearchMapOfflineBanner.swift` | — | OBSOLETE → root `offlineCapsule`. Gap kept: the MP bar's cache time line is not shown. |
| `DoorEntrySheet` | `App/DoorReferralViews.swift` | — | OBSOLETE → `NativeEntryLandingView` `.door` |
| `H5LaunchProducerView` | `App/H5LaunchProducerView.swift` | — | HIDDEN: no `H5LaunchProducer` is built in production (E5 fixture only); the workshop H5 launch POST is not composed |
| `GlobalSearchResultTabsBar`, `UnifiedSearchContainerView`, `UnifiedSearchModeBar` | `App/HomeSearchTabParityViews.swift` | — | OBSOLETE → `SessionGlobalSearchView` / `GlobalSearchView.kindPicker`; map mode is `SearchMapExplorerView` |
| `HomeIndexShelfHeaderView` | same | — | OBSOLETE → `HomeFeedView.sectionHeader` |
| `PublishTabFloatingButton` | same | — | OBSOLETE: Publish is not a player tab (W1-1); publishing opens from `SessionHomeFeedView.publishDestination` and `MyProjectTabViews` |
| `MessagingEmptyView` | `App/MessagingComponents.swift` | — | OBSOLETE → `CYEmptyState` in `MessagingHomeView` |
| `NativeChannelForegroundUnreadEntry` | `App/NativeChannelForegroundUnreadEntry.swift` | — | OBSOLETE → `NativeOriginalUnreadBadgeLifecycle` (root) + `notification.badge.entry` in Settings |
| `NativeChannelMessageAttachmentView` | `App/NativeChannelMessageAttachmentView.swift` | — | OBSOLETE → `NativeChannelAttachmentPreviewEntry` from `NativeChannelMessageBubbleView` |
| `NativeChannelNotificationConversationEntry` | `App/NativeChannelNotificationEntry.swift` | — | OBSOLETE → `NativeChannelNotificationChannelContextEntry` via `NativeChannelNotificationHostDestination` (club channel management) |
| `NativeChannelProgressPrivacyEntry` | `App/NativeChannelProgressPrivacyView.swift` | — | OBSOLETE → privacy link in `NativeChannelProgressEntry` → `NativeChannelProgressPrivacyView` |
| `NativeConditionAuthorProjectEntrySection`, `NativeConditionAuthorProjectDestination`, `NativeConditionAuthorCatalogDestination` | `App/NativeConditionAuthorEntry.swift`, `App/NativeConditionAuthorProjectCatalogHost.swift` | — | OBSOLETE → `NativeAttributeAuthorConditionEditor` / `NativeAttributeAuthorConditionCatalogDestination` (condition editor inside `NativeAttributeAuthorProjectEntrySection`); `nativeConditionAuthorDependencies` / `…ProjectFactory` are never injected |
| `BadgeRouteEntryView` | `App/NativeNavigationCompletionViews.swift` | — | OBSOLETE: a paste-a-path form; `/badge` links now arrive through the router (`NativeEntryLandingView` `.badge`) |
| `OfficialFlowActionBar` | `App/OfficialEventComponents.swift` | — | OBSOLETE → the official screens' current CY footers |
| `ProfileSettingsProfileEntry` | `App/ProfileSettingsProfileRoute.swift` | — | OBSOLETE → `SettingsView.accountHeader` (same `ProfileSettingsProfileRoute`) |
| `QuickPublishingCanvas`, `QuickPublishingInterestPicker` | `App/PublishingContextHandoffViews.swift` | — | OBSOLETE: MP `pages/publish/simple` dropped the bubble canvas on 2026-11-11 (grey ground, white card) and now takes interests from the tag library's 主题 preset. Gap kept: those tag chips feeding the AI prompt are not ported. |
| `ReformWorldHostWorkbenchView` | `App/ReformWorldHostWorkbenchView.swift` | — | SKIP (dev / release-audit workbench) |
| `RoamExportUnavailableView` | `App/RoamSubpageParityViews.swift` | — | OBSOLETE → `RoamExplorationExportView` shows its own unavailable state (`roam.export.open`) |

## 3. Dead player components (36 listed)

| View | State |
|---|---|
| `AIGCLabel` (`App/AIGCDisclosure.swift`) | DONE → `TopicDetailView` hero, under `TopicXcxHero`, when `publishMode == ai_simple` (`aigc.label`). `TopicDetail` now decodes `publishMode` (`Core/TopicContracts.swift`, absent = nil). PARTIAL: the play title-card kicker is not added. |
| `ActivityDetailHeader`, `ActivityName`, `ActivitySummaryMetadata`, `ActivityDetailMetaSection` | OBSOLETE → the current `ActivityDetailView` header and pinned facts |
| `CityAcquisitionCard`, `CityAcquisitionMetadataRow` | OBSOLETE → `CityAcquisitionView` CY rows |
| `ClubRow`, `ClubEmptyState`, `ClubTabEmptyState` | OBSOLETE → `CYClubRowCard` / `CYClubPhotoCard` and the `clubTab.empty` state in `ClubHomeView` / `ClubDirectoryView` |
| `ClubHostApplicationMaterialsRows` | HIDDEN: the host-apply form keeps cert / material upload hidden on purpose (no reviewed upload) |
| `CYChipRow` | OBSOLETE → `DiscoveryTemplateBrowserView.filterChip` row |
| `CYUnreadBadge` | OBSOLETE → `IMUnreadBadge` / `IMUnreadEntryBadge` |
| `CYDocumentHeading` | OBSOLETE (no settings footer uses it; `SettingsAboutView` has its own section footers) |
| `CYMiniDueStrip` | SKIP (money: deposit due) |
| `DiscoveryTemplateEmptyRefresh` | OBSOLETE → `CYEmptyState(… actionTitle: "discovery.emptyRefresh")` in `DiscoveryTemplateBrowserView` |
| `PublicTemplateSilhouette` | OBSOLETE: MP `templatedetail` never reads `routeShape`; native shows the numbered stop chips |
| `IMInboxTabLabel` | OBSOLETE → `MessagingHomeView` tab picker with `badgeText` |
| `MessagingConversationKindLabel`, `MessagingOptionalRow` | OBSOLETE → `IMInboxRow` |
| `NativeChannelFlowFact`, `NativeChannelFlowReference` | OBSOLETE → the channel management screens' current CY fact rows |
| `OfficialEventTimeValue`, `OfficialFlowNotice`, `OfficialRecordValue` | OBSOLETE → official screens' current CY rows / `CYNoteBanner` |
| `PlayerJourneyCount` | OBSOLETE → `PlayerJourneyViews` current rows |
| `ProfileBadgeMedal`, `ProfileBadgeTitle` | OBSOLETE with `ProfileBadgesView` → `ObjectBadgeWallBadgeLabel` |
| `ProjectRemoteVersionRow`, `ProjectTopicMediaStageSummary` | OBSOLETE → `ProjectTopicMediaHost` (mounted in `ProjectEditView`) |
| `ClubControlLabel` | OBSOLETE (unused label helper) |
| `RoamSessionRouteNameText`, `RoamShareCardParityFooter` | OBSOLETE → `RoamHistoryShareView` `CYShareCard` (探索度 / 点亮 stats). The MP card title is `routeName` (zone / POI names); natively place names stay behind the share sheet's `includePlace` privacy toggle, so the title stays generic. |
| `TemplateImageCropControls` | OBSOLETE with `TemplateImageCropView` → `MiniCropView` |

## Gates

- `tools/generate_project.py`: regenerated (4 new files: `Core/MiniProgramPageLink.swift`, `App/MPParityDeepLinkEntry.swift`,
  `Tests/CoreTests/MiniProgramPageLinkTests.swift`, `Tests/AppUnitTests/MPParityDeepLinkRouteTests.swift`).
- `tools/check_scaffold.py`: PASS. `tools/check_design_lint.py`: PASS. `tools/check_appsession_ratchet.py`: PASS.
- `swiftc -parse` on every changed Swift file: OK. `swiftc -typecheck` of `MiniProgramPageLink` with `CheinDeepLink` + `RootTab`: OK,
  plus a throwaway run of the parser on the landing, report, repeated-key, paid-reveal, non-canonical-id and chein cases.
- Not run: `swift test`, `xcodebuild`, simulator. No new request, so no stub-transport test applies.

## Left for later

- Team create: compose `TeamHTTPService` with the owned registration's `teamCreationSource` and a write lease, then mount
  `SessionTeamCreateView` from the order detail (`teamOpen` rule above).
- Associated domains + `verifiedHTTPSOrigins`, and the push payload key, to turn the PARTIAL entry rows on.
- `page-map.csv`: `pages/crop/index` → `App/MiniCropView.swift`; `subpackageMember/market/gift/index` and
  `subpackageJourney/pages/landing/index` → reachable through the router.
