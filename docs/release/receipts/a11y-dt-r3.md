# a11y-dt r3 receipt (branch `design/r3-a11y`)

Lane area: Dynamic Type up to AX5, VoiceOver labels/order/traits, Reduce Motion, contrast, 44 pt targets on every player screen.
Code-only, cloud-verified (no Swift compiler / simulator in the cloud). Gates per run: generate_project, check_scaffold,
check_a11y_lint (0 current), contract_ratchet --check (new 0), check_design_consistency (PASS).
No MP section added, removed or reordered by this lane (OWNER RULE): fixes are sizing, traits and labels only.

## Run 1 (2026-11-27)

Whole-tree scans done first (player files; Merchant / Fixture / Diagnostics / *SectionView skipped):
- `repeatForever` animations without a Reduce Motion check: **0**.
- `onTapGesture` without a button trait / action nearby: 17 hits reviewed; all either have an adjustable/custom
  accessibility action (journey settle step dots, medal stack), are map coordinate pickers with a text alternative,
  are tap-to-skip on a moment that also has a Done button, or are fixtures. No change needed.
- Button labels with a fixed frame < 44 pt and no min-hit wrapper: 0 real (all hits already wrap to 44).
- **Text inside a fixed-size circle/tile** (clips at AX sizes): 13 hits → fixed below.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/index/index` (Home tab root) | `HomeFeedView.swift`, `HomeSearchTabParityViews.swift` (hero) | ✓ (mp-home owns order) | Verified: rails switch to full-width rows at AX sizes, banner autoplay stops for Reduce Motion + VoiceOver, page dots hidden, avatar/city 44 pt, greeting header trait. No change needed. | Done |
| `pages/roam/index` (Roam map home) | `NativeR2/MapHome/RoamMapHomePanel.swift` | ✓ (mp-roam owns order) | Verified: panel handle is adjustable for VoiceOver (peek/medium/large value), peek height scaled for Dynamic Type and capped at 40 %. No change needed. | Done |
| `pages/member/index` (Me tab root, passport block) | `PassportView.swift` (`actions`) | ✓ (mp-mine owns order) | 票夹 / 钱包 / 消息 capsule row → `AnyLayout` VStack at AX sizes (same buttons, same order), so labels no longer break one glyph per line; stamp grid / badge rail already adapt (verified) | Done |
| City ordered run (`subpackageJourney` city route list) | `CityOrderedMapView.swift` | ✓ | Stop number circle 28 pt → `@ScaledMetric(relativeTo: .footnote)` | Done |
| `pages/activity` official route detail | `E1OfficialRouteParts.swift` | ✓ | Route node number circle 28 pt → `@ScaledMetric(relativeTo: .body)` | Done |
| Growth leaderboard (`subpackageMember` rank) | `GrowthLeaderboardView.swift` (podium) | ✓ | Podium place badge 28 pt → `@ScaledMetric(relativeTo: .caption)` | Done |
| `pages/club/*` rows | `ClubKit/ClubR1Kit.swift` (`ClubR1Row`) | ✓ | Initial tile 32 pt (`.headline`) → `@ScaledMetric(relativeTo: .headline)` | Done |
| Questo accusation (`pages/playkit`) | `PlayKitQuestoViews.swift` (`PlayKitAccusationView`) | ✓ | Suspect initial circle 52 pt → `@ScaledMetric(relativeTo: .title3)` | Done |
| `subpackageMember` participants (常用出行人) | `ProfileParticipantsView.swift` | ✓ | Name initial circle 40 pt → `@ScaledMetric(relativeTo: .headline)` | Done |
| City deed card (roam city board) | `CityKit/CityDeedCard.swift` | ✓ | Owner avatar letter 22 pt → `@ScaledMetric(relativeTo: .caption)` | Done |
| Settings › marketing consents | `AccountComplianceViews.swift` | ✓ | Merchant initial / logo tile 36 pt → `@ScaledMetric(relativeTo: .body)` (logo and initial stay the same size) | Done |
| Blind taste (`pages/playkit` legacy kit) | `PlayKitLegacyViews.swift` (`PlayKitBlindSteps`, new private view) | ✓ | Step number circle 36 pt → `@ScaledMetric(relativeTo: .body)`; three steps `ViewThatFits` HStack → VStack at AX sizes / long English; combined VoiceOver sentence kept | Done |
| Journey record (`subpackageJourney` narrative) | `JourneyNarrativeView.swift` | ✓ | Found-count ring 88 pt → `@ScaledMetric(relativeTo: .title)` capped at 132; number scales down (0.5) instead of clipping | Done |
| Club month calendar (design component) | `ClubComponents.swift` (`E3MonthGrid`) | ✓ | Seven 38 pt day circles capped at `.xxxLarge` (as Calendar's month grid); each day keeps its VoiceOver label | Done (only fixture-hosted today) |

## Run 2 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Gates as above.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| City orientation run map (`subpackageJourney`) | `NativeR2/CityOrientation/CityOrientationRunView.swift` (teammate annotation) | ✓ (mp-journey owns order) | Teammate initial 28 pt → `@ScaledMetric(relativeTo: .caption)` capped at 44 (Maps-pin size, never covers the route); `.regularMaterial` disc instead of translucent fill so the letter reads on any map tile; VoiceOver hears the team name, not the initial | Done |
| `pages/template/index` (Publish tab root, template shelf) | `DiscoveryTemplateBrowserView.swift`, `+Port.swift`, `TemplateShelfArt.swift` | ✓ (mp-publish owns order) | Row artwork (60/72 pt scaled) capped at 96 pt so the title keeps the row at AX5 (Music list artwork rule; also fixes search result rows that share `DiscoveryTopicCoverThumb`); shelf header picture capped at 240 pt (was 180 × AX5 ≈ 560 pt); featured page view 16:13 → 2:3 at accessibility sizes so title + meta are not cut off. Toolbar items, menu and sections unchanged | Done |
| `pages/member/index` passport actions (16:37 sweep `ia-passport`) | `PassportView.swift` (`action`) | ✓ | Labels `.caption` → `.footnote` medium (was "tiny"); contrast checked: brand #33363C on the bordered fill ≈ 9:1 light, #F8F8F8 ≈ 10:1 dark (≥ 4.5:1). AX stacking from run 1 kept | Done |
| `subpackageMember` ticket wallet (票夹) | `TicketWalletView.swift` (row), `TicketWalletDetailView.swift`, `TicketPassSheet.swift` | ✓ (mp-mine owns order) | Row cover 60 pt scaled → capped at 96 pt so title/date/place keep the width at AX5. Detail + pass sheet audited: QR band already shrinks at AX sizes, labels present. | Done |
| `pages/club/*` (Club tab root) | `ClubHomeView.swift` | ✓ (mp-club owns order) | Audit: system `List`/`Label` rows, no fixed sizes, no `font(.system)`, event rows wrap. No change needed | Done |

## Run 3 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Sweep 17:24 (build 070117595) a11y sheets read: `en-a11y-roam-ax5.jpg`
(peek title wraps cleanly, map controls fine), `en-a11y-badges-ax5.jpg` (single-column badges at AX5, OK),
`en-a11y-passport-ax5.jpg` renders the badge wall under a dimmed launch overlay (see For other lanes).

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| City orientation run (`subpackageJourney`) team stack | `NativeR2/CityOrientation/CityOrientationRunView.swift` (`CityOrientationTeamStack`) | ✓ | "N teams on the route" `lineLimit(1)` → 2 lines + 0.85 scale, never truncated in long English at AX5; face pile 24 pt → `@ScaledMetric(.caption)` capped 36, hidden at AX sizes (already VoiceOver-hidden; the count sentence carries the meaning) | Done |
| `pages/roam/index` (Roam map, floating controls) | `RoamBrowserView.swift` (`RoamMapGlassControl`) | ✓ (mp-roam owns order) | Rules / open-map circles scaled from 50 pt without a cap → capped at 72 pt so rules · GO · map fit 375 pt at AX5. Result rows (`RoamItemRow`, 60 pt art, combined element), search field 44 pt, peek line 44 pt + combined: audited, no change | Done (`en-a11y-roam-ax5.jpg`) |
| `subpackageMember` im list (inbox, `im/list/index`) | `IMInboxViews.swift` (`IMInboxRow`) | ✓ (mp-mine/mp-nav own order) | Audit: avatar 44 pt at AX sizes, name/time stack ≥ xxLarge, combined row, muted glyph labelled. No change | Done |
| `subpackageMember` im chat (system notice card) | `MessagingHistoryView.swift` (`MessagingBubble.noticeCard`) | ✓ | Bell tile 36 pt fixed with a `.body` glyph (clipped at AX sizes) → `@ScaledMetric(.body)` capped 60 | Done |
| Chat message cards | `MessagingMessageDetailView.swift` | ✓ | Audit: icon tile scaled + hidden at AX sizes. No change | Done |
| Club channel chat (`pages/club/*` channel, `d4-channel-chat`) | `ClubChannelMessagingView.swift` (`ChannelBurstGroupCard`, `ClubChannelMemberRosterSheet`) | ✓ (mp-club owns order) | Sender initial circle 28 pt and roster initial 32 pt (text in a fixed circle, clipped at AX sizes) → `@ScaledMetric(.subheadline)` capped 48 / 52, letter scales down instead of clipping. Send button 44 pt labelled, Reduce Motion respected on scroll: audited. `NativeChannelMessage*` (context avatar 40 pt art, no text) audited, no change | Done |

## Run 4 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Sweep index still 17:24 (build 070117595); a11y sheets unchanged since run 3.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/square/index` list (post card `cy-post-card`) | `SquareXcxPostCard.swift` | ✓ (mp-activity owns order) | Club · badge/level line: one line at normal sizes; at AX sizes it stacks (`AnyLayout` VStack) and wraps to 2 lines instead of truncating long English club names; 认证 mark 12 pt → `@ScaledMetric(.headline)` so it grows with the name | Done |
| `pages/square/detail` (post head, actions, medal pill) | `SquareComponents.swift` (`SquarePostContent`), `SquareDetailView.swift` | ✓ | Verified mark scaled as above; post like button now reads "Like / Unlike" + value "N likes" + selected trait (same as the comment-row like; before it was only the count); medal images 20 pt → `@ScaledMetric(.subheadline)` capped 40. Comment like / reply / follow badge 44 pt: audited, no change | Done |
| Club channel pins (`pages/club/*` channel) | `NativeChannelMessagePinsView.swift` | ✓ (mp-club owns order) | Pin rows get a VoiceOver hint "Shows this message in the chat." / 在聊天中显示这条消息 when they can jump; reorder via Edit, swipe Remove, `ContentUnavailableView` empty/failed states, Done in the cancellation slot: audited | Done |
| Club channel search | `NativeChannelMessageSearchView.swift` | ✓ | Same hint on result rows; day section headers already `.isHeader`, chevron hidden, fields labelled, empty state native: audited | Done |
| `pages/team/*` (team home, seats, create, nearby, session team) | `TeamHomeView.swift`, `TeamPageParityViews.swift`, `TeamSeatFactsViews.swift`, `SessionTeamViews.swift`, `NearbyTeamViews.swift`, `TeamCreateView.swift`, `TeamComponents.swift` | ✓ (mp-activity owns order) | Audit: no fixed text frames, no `lineLimit(1)`, no tap gestures without traits, no unbounded animations; member avatar 32 pt is an image beside wrapping text (fine at AX5). No change | Done |
| `pages/square/*` cloud feed (kudos, completed activities) | `SquareCloudFeedViews.swift` | ✓ | Audit: face pile VoiceOver-hidden inside a combined element, kudos text wraps to 2 lines, 56 pt cover is an image beside wrapping text. No change | Done |
| `pages/coop/list`, `pages/coop/invite` (player cooperation invites) | `CooperationFlowWorkbench.swift` (`CoopInviteCardLabel`) | ✓ (mp-activity owns order) | Cover scaled without a cap (56 → ≈170 pt at AX5) → capped 96 pt; partner · status line stacks without the "·" at AX sizes and the partner wraps to 2 lines instead of truncating | Done |
| `pages/coop/nearby` (nearby venue card) | `CoopListCardExtras.swift` (`NearbyMerchantCardChrome`, `NearbyMerchantAddressLine`) | ✓ | Default cover capped at 96 pt (was unbounded); pin 12 pt → `@ScaledMetric(.footnote)`, chevron 14 pt → `@ScaledMetric(.body)` so glyphs track the text | Done |
| `pages/coop/finance`, `pages/coop/settlement-detail`, `pages/coop/invite-detail` | `CoopFinanceProfitView.swift`, `CoopFinanceSummarySection.swift`, `CoopSettlementDetailView.swift`, `CooperationInviteDetailView.swift` | ✓ | Audit: system `LabeledContent` rows (stack at AX sizes), monetary values `monospacedDigit`, timeline dot decorative + hidden, 44 pt minimum on finance actions, hero cover fixed 150 pt is an image. No change | Done |
| `subpackagePass/reveal` (pass / object reveal) | `RevealChoreographer.swift`, `PlayObjectCardRevealView.swift`, `PlayKitSpatialRevealView.swift`, `TopicPurchaseRevealMount.swift` | ✓ (mp-activity owns order) | Audit: choreographer takes Reduce Motion + Low Power, card flip jumps to the final frame, AR decorative motion finishes immediately under Reduce Motion. No change | Done |

## Run 5 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Sweep index still 18:06 (build 070117595); a11y sheets unchanged.
`.lineLimit(1)` audit (132 hits in player files): tab-root rows and their direct rows first.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/index/index` feed (`v2-fcard` tags, `v3-reco-club`) | `HomeFeedView.swift` (`HomeFeedCard`, `HomeFeedFeaturedFacts`) | ✓ (mp-home owns order) | The two MP category chips sit side by side at normal sizes and stack (`AnyLayout` VStack) at AX sizes, 2 lines each, instead of truncating; featured club line 1 → 2 lines at AX sizes | Done |
| P21 running-session mini bar (all tab roots) | `ActiveSessionMiniBar.swift` | ✓ | Icon tile fixed 36 pt with a `.body` glyph (clipped at AX sizes) → `@ScaledMetric(.body)` capped 52 pt; title/value stay one line (Music mini-player pattern), combined element + hint already present | Done |
| `pages/roam/index` 附近 list | `NativeR2/MapHome/RoamMapHomeSheet.swift` (`RoamMapHomePinRow`) | ✓ (mp-roam owns order) | Title 1 → 2 lines and kind · distance stacks at AX sizes (separator dropped and VoiceOver-hidden) instead of truncating | Done |
| `pages/topic/index` route stops | `TopicXcxSections.swift` (`TopicXcxRouteSection`) | ✓ (mp-publish owns order) | Stop address (Maps link) 1 → 3 lines at AX sizes | Done |
| `pages/member/index` card buttons | `MemberHomeHeader.swift` | ✓ | Left to mp-mine (18:15 sweep: they own the `ViewThatFits` fix for 开始探索 / 票夹); asset values `lineLimit(1)` + scale are numbers, fine | Skipped (other lane) |
| Club fixtures `E3PostCard` | `ClubComponents.swift` | — | Fixture-only (`DesignFixtures/E3Fixtures.swift`), skipped | Skipped |
| `pages/topic/index` 章节卡片 rail | `TopicChapterCardsSection.swift` (`TopicChapterCardView`) | ✓ (mp-publish owns order) | 156 pt rail card: title and meta 1 → 3 lines at AX sizes (one AX5 line held ~4 glyphs) | Done |
| `pages/topic/index` 附近组队 card | `TopicTeamsCard.swift` | ✓ | Team name and meeting place 1 → 2 lines at AX sizes | Done |
| Journey report / roam live stats / play lead bar | `JourneyReportViews.swift`, `RoamLiveSessionView.swift`, `MPGap/PlayRoam/PlayLeadBar.swift` | ✓ | Audit: `lineLimit(1)` hits are numbers with `minimumScaleFactor` (score, stop count, live values) or a short role tag beside a spacer; Reduce Motion already gates numeric transitions. No change | Done |

## Run 6 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Sweep index still 18:06 (build 070117595); a11y sheets unchanged.
`.lineLimit(1)` audit continued (receipt Not done list, then single-hit files A–I).

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| City deed board (roam city) mini deed | `CityKit/CityDeedCard.swift` (`mini`) | ✓ (mp-roam owns order) | 160 pt AX card: district band and place title 1 → 2 lines at AX sizes instead of truncating; compact/large photo title keeps 1 line + scale (fixed-height photo), sheet header already `ViewThatFits` | Done |
| People pile / invite card | `NativeR2/Social/CYPeopleComponents.swift` | ✓ | Audit: "+N" is a number with min 44-ish capsule; "Later" is short; buttons `ViewThatFits` HStack → VStack. No change | Done |
| Step checklists (first roam, ticket wallet, club create, publish wizard, city) | `NativeR2/Components/CYStepChecklist.swift` (`doneRow`) | ✓ | Done-step row: title + summary side by side, 1 line each → at AX sizes `AnyLayout` VStack, title 3 lines, summary 2; thumbnail 28 pt → `@ScaledMetric(.body)` capped 44. Header ring numbers already scale 0.5 | Done |
| Story reader | `NativeR2/Story/NR2StoryReaderParts.swift` | — | Story-flow is on hold (brief), skipped | Skipped |
| `pages/club/*` rows (`ClubR1Row`) | `ClubKit/ClubR1Kit.swift` | ✓ (mp-club owns order) | Row subtitle 1 → 2 lines at AX sizes | Done |
| Club home pinned notices | `ClubCommunityViews.swift` (`ClubCommunityFeedView` notice row) | ✓ | Notice summary 1 → 2 lines at AX sizes | Done |
| Club detail inline leaderboard | `ClubDetailR8Mounts.swift` (`ClubInlineLeaderboardRows`) | ✓ | Nickname 1 → 2 lines at AX sizes (meta line already wraps) | Done |
| In-game channel entry (`pages/play` chat row) | `InGameChannelEntryViews.swift` (`InGameChannelRowButton`) | ✓ (mp-journey owns order) | Last-message preview 1 → 2 lines at AX sizes (Messages pattern) | Done |
| Single-hit files A–G (`ActivityPublishingWizardView`, `BundleShelfView`, `CastViews`, `CityArrivalEvidenceView`, `CityGamePanel`, `CityDiceKit`, `CityLiveOnMap`, `ClubEnrollmentView`, `ClubOperationsViews`, `ClubPostImagePicker`, `E1CommerceComponents`, `FreeExplorationViews`, `GlobalSearchView`, `GrowthLeaderboardView`) | — | ✓ | Audit: hits are prices / codes / counts with `minimumScaleFactor`, monograms in scaled circles, short button labels, or the search capsule that must stay one line (16:37 sweep fix). No change | Done |
| Play tools › journal (`pages/play` lead sheet) | `MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift` (`PlayJournalListView`) | ✓ (mp-journey owns order) | Entry excerpt 1 → 3 lines at AX sizes | Done |
| Object card collection tile | `ObjectCardViews.swift` (`ObjectCardTile`) | ✓ | Place line 1 → 2 lines at AX sizes (grid already single-column there) | Done |
| `pages/templatedetail` head | `TemplateDetailXbChrome.swift` (`TemplateXbHead`) | ✓ (mp-publish owns order) | Publisher 1 → 2 lines at AX sizes (head already stacks) | Done |
| Object card pile / grid (`pages/playkit`) | `MPGap/PlayRoam/PlayRoamRound4Views.swift` (`ObjectCardPileAndGridView`) | ✓ | Grid tile title 1 → 2 lines at AX sizes | Done |
| Club detail member strip (MP `buildMemberStrip`) | `MPGap/Club/ClubGapManageExtensions.swift` (`ClubGapMemberAvatarStrip`) | ✓ (mp-club owns order) | Four names under avatars 1 → 2 lines at AX sizes (each slot ≈ 70 pt) | Done |
| Single-hit files M–T (`ClubGapRemainingViews`, `PlayNavBubbleOverlay`, `PlayRoamRound2Views`, `MPPassEntries`, `CityOrientationFinishSummaryView`, `CityOrientationNavComponents`, `NativeFreeExploreMapView`, `PlayKitQuestionForms`, `ProjectEditFlowParity`, `RequestReferenceRow`, `RoamExplorationExportView`, `RoamFinishReportView`) | — | ✓ | Audit: numbers/ETA/dates/reference codes with `minimumScaleFactor`, a map bubble (short by design), cover chips, file name with middle truncation, picker ticks. No change | Done |

## Run 7 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Sweep 18:54 (build 1300a48db) a11y sheet read: `en-a11y-badges-ax5.jpg` /
`en-a11y-passport-ax5.jpg` show the "3/6" ring at 56 pt beside an AX5 title (count glyphs ~8 pt); `en-a11y-roam-ax5.jpg` OK.
Not done list from run 6 worked.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `subpackageMember` 徽章墙 / 收集册 progress (`en-a11y-badges-ax5.jpg`) | `DesignSystem/CYCollectible.swift` (`CYCountRing`), `DesignSystem/CYAlbum.swift` (`CYAlbumProgressRing`, real badge wall + stamp album) | ✓ (mp-mine owns order) | Ring grows at accessibility sizes (1.6x / 1.4x capped 140 pt) so the count tracks the large title beside it; Reduce Motion + labels unchanged | Done |
| Event / activity join rows (P2 "Starts in", club + home event cards) | `NativeR2/Components/CYJoinCountdownRow.swift` | ✓ | At AX sizes `AnyLayout` VStack: Join button moves under title · countdown · subtitle (same order) so the title keeps the width; subtitle 1 → 2 lines at AX sizes | Done |
| Medal deck (成就 medals) | `DesignSystem/CYMedalStack.swift` (`CYMedalDeck`) | ✓ | Medal subtitle 1 → 2 lines, centered (name already 2) | Done |
| Pass verified face (`subpackagePass`) | `DesignSystem/CYPassVerified.swift` | ✓ (mp-activity owns order) | Activity title 1 → 2 lines centered, 0.85 scale, instead of truncating long English | Done |
| `pages/square` publish › pick activity | `DesignSystem/CYSquareActivityPicker.swift` | ✓ | Activity name 1 → 2 lines | Done |
| Remaining DesignSystem / Components / NativeR2 single hits (`CYTicketPass`, `CYClubCards`, `CYMapChrome`, `CYPurchaseMotion`, `CYScan`, `CYOnboarding`, `CYCelebrationViews`, `CYSharedStates`, `CYShareCard`, `CYLoadingChoreography`, `CYChapterFlip`, `CYInPlaceResult`, `CYBalanceHero`, `CYGlassCarousel`, `CYStepChecklist` ring, `CYRecordStatGrid`, `CYCountdown`, `CYRing`, `CYLiveCounter`, `CYStatPill`, `PassportView` action, `QuestifyMotionComponents`, `MotionR2Metrics`, `IslandOverlay` compact, `NativeGameTimedKit`) | — | ✓ | Audit: numbers / timers / prices with `minimumScaleFactor`, a redacted skeleton, share-card renders (fixed image), the island compact one-liner (system pattern), and the passport action already `ViewThatFits` with a 2-line fallback. No change | Done |

## Run 8 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Sweep 19:36 (build 3568fe51b) a11y sheets read: `en-a11y-badges-ax5.jpg` still shows the
small 3/6 ring because the build predates run 7's ring fix (not yet in combined-r7); `en-a11y-roam-ax5.jpg` OK.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `.lineLimit(1)` audit, files with 2+ hits | `PlayKitTimedChallengeView.swift`, `JourneyNarrativeView.swift` (+ files already audited in runs 5–7) | ✓ | Audit: clock / result value / found count are numbers with `minimumScaleFactor`. No change | Done |
| City board status tags + district chips (roam city, `subpackageJourney` city) | `CityKit/CityTokens.swift` (`CityStatusTag`, `CityDistrictChip`) | ✓ (mp-roam / mp-journey own order) | Chip text truncated at AX sizes → wraps (status 3 lines, district 2) and the outline turns from a capsule into a `CYRadius.md` rounded rect so wrapped text is not clipped by the oval | Done |
| `pages/roam/index` map tab root + every `CYMapScaffold` screen (city run, free explore, nearby teams…) | `DesignSystem/CYMapChrome.swift` (`CYMapScaffold`) | ✓ | VoiceOver order: top controls, floating actions and the panel are now `.contain` groups ranked 3 / 2 / 1 above the map, so the reading order is controls → GO · rules · open map → list panel → map pins (before: rules / open-map sorted in with the map pins by position, only GO was lifted). Layout and hit-testing unchanged | Done (`en-a11y-roam-ax5.jpg`) |
| `pages/index/index` (Home: banner vs greeting row) | `HomeFeedView.swift`, `HomeSearchTabParityViews.swift` | ✓ (mp-home owns order) | Audit: banner, greeting and feed sit in one scroll in MP order with no floating overlay, so VoiceOver follows the visual order; banner art hidden, title read. No change | Done |
| Chapter flip gate (`pages/play` chapter transition) | `DesignSystem/CYChapterFlip.swift` | ✓ (mp-journey owns order) | Contrast audit of white-opacity text on the ink0 → indigo #1B1E4A ground (worst case, bottom): "tap to continue" 0.5 → 4.9:1, chapter meta 0.6 → 6.5:1, subtitle 0.72 → 8.7:1 (all ≥ 4.5:1). Only other low-opacity text hit is the DEBUG ART fixture label. No change | Done |

## Run 9 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (clean). Sweep 20:11 (build a250afd77) a11y sheets read: still predate runs 7–8 (ring 3/6 small at AX5,
roam OK), so the re-read stays open. 44 pt pass on icon-only `.plain` / `.borderless` buttons (scripted: Button label = SF Symbol only,
no ≥ 44 frame): 16 hits, 8 real (glyph-sized hit area); the rest are full rows with `contentShape` or already use `editorHitTarget` / 78 pt tiles.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `subpackageMember` member-area popup (chat / export sheet header) | `MemberAreaPopupSurfaces.swift` | ✓ (mp-mine owns order) | Close ⓧ glyph (`.title2`, ~28 pt) → 44 × 44 hit area, same glyph | Done |
| `pages/roam/*` official arrival overlay header | `RoamOfficialArrivalSection.swift` | ✓ (mp-roam owns order) | Close ⓧ → 44 × 44 hit area | Done |
| `pages/roam/*` nearby place sources | `RoamNearbyParityExtras.swift` | ✓ | Copy-source-link glyph → 44 × 44 hit area | Done |
| `pages/square/*` cloud feed card + composer | `SquareCloudFeedViews.swift`, `SquareCloudComposerView.swift` | ✓ (mp-activity owns order) | Post actions ⋯ and composer chip clear ⓧ → 44 × 44 hit area | Done |
| Club channel voice message (`pages/club/*` channel) | `NativeChannelInlineMediaViews.swift` | ✓ (mp-club owns order) | Play/stop glyph (`.largeTitle`) → min 44 × 44 so it never drops under at small sizes | Done |
| `pages/club/*` apply (proof images) | `MPGap/Club/ClubGapRound4Views.swift` | ✓ | Delete-proof trash glyph → 44 × 44 hit area | Done |
| `pages/publishkit` hint ladder editor | `TemplateHintLadderFields.swift` | ✓ (mp-publish owns order) | Remove-layer ⊖ glyph → 44 × 44 hit area | Done |

## Run 10 (2026-11-27, half-hourly)

Rebased on `origin/design/r3-a11y`. Coordinator 20:55 finding for this lane worked first; 16:37 `ia-passport` capsule contrast
re-checked (already `.footnote.weight(.medium)`, brand on bordered fill ~9:1, stacks at AX sizes): no change.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/member/*` passport (sweep fixture) | `DesignFixtures/E5bFixtures.swift`, `DesignFixtureRegistry.swift` | ✓ (mp-mine owns order) | `a11y-passport-ax5` now mounts the passport page (`IAPassportFixture`: stamp ring, badge rail 2 of 6, action capsules) at AX5; the badge wall at AX5 moved to its own `A11yBadgesAX5Fixture` under `a11y-badges-ax5` (release-exclusion audit + view map updated) | Done (next sweep: `a11y-passport-ax5`) |
| `pages/club/*` calendar (month prev / next) | `ClubCalendarSessionRows.swift` | ✓ (mp-club owns order) | Borderless chevrons in a `List` row had a glyph-sized hit area → label min 44 × 44 + `contentShape` | Done |
| `pages/club/*` channel poll composer | `GroupPollViews.swift` | ✓ | Remove-option ⊖ → 44 × 44 hit area | Done |
| `pages/publishkit` condition value editor | `NativeConditionAuthorFieldForm.swift` | ✓ (mp-publish owns order) | Remove ⊖ and move-up ↑ (adjacent, borderless) → 44 × 44 each, so they no longer share one small target | Done |
| Contrast, multi-line `.opacity(` foregrounds | `CYOnboarding.swift`, `CYShareCard.swift`, `CYChapterFlip.swift`, `CYDesignedCover.swift`, `CYSignature.swift` | — | Audit: onboarding body white 0.6 on indigo/ink ≈ 6.5:1; share-card brand black 0.55 on light ≈ 5:1; chapter meta 0.66 ≈ 7:1; cover watermark + DEBUG ART label decorative / debug only, hidden. No `textSecondary.opacity(<0.75)` on text. No change | Done |
| Reduce Motion, looping / symbol effects | `FogOverlayLayer.swift` (+ `RoamFogMapView`), `GrowthCenterView`, `ChanceKits`, `RoamStampCameraView`, `PassMarketViews` | — | Audit: every `repeatForever` file reads Reduce Motion; fog shimmer and wipes are off under Reduce Motion (caller passes `shimmer: !reduceMotion`, crossfade instead); remaining `symbolEffect` / `.contentTransition(.symbolEffect)` are system effects that follow Reduce Motion. No change | Done |

| `pages/member/*` settings account card | `SettingsView.swift` (`SettingsAccountCard`) | ✓ (mp-mine owns order) | Initial is `.title` inside a fixed 60 pt circle (clips at AX sizes) → `@ScaledMetric(relativeTo: .title)` circle | Done |
| `pages/playkit` accusation confirm panel | `PlayKitQuestoViews.swift` (`confirmPanel`) | ✓ (mp-journey owns order) | Suspect initial `.pageTitle` in a fixed 72 pt circle → `@ScaledMetric(relativeTo: .largeTitle)` circle (same as the 52 pt list initial) | Done |
| VoiceOver, `.onTapGesture` without button trait | `JourneyReportViews`, `CityMomentView`, `SettingsAboutView`, `CYMedalStack`, `CYPlayerKit`, `IMExpandedViews`, `E1TicketCard` | — | Audit: every hit carries `.isButton` / `accessibilityAction` / adjustable action, is a skip-animation tap with a real button beside it, or is a map with `.allowsDirectInteraction` + a VoiceOver button (use map centre). No change | Done |

## Run 11 (2026-11-27, hourly)

Merged `origin/ui/combined-r7` (405948d58). Sweep 21:09 (build 405948d58) a11y sheets read: build predates run 10, so
`a11y-passport-ax5` still shows the badge wall. `en-a11y-badges-ax5.jpg`: ring grows (run 7 visible) but its unfilled track is
invisible on the grouped background (bgRaised ≈ page). `en-a11y-roam-ax5.jpg`: large title, ··· / i / Go / map controls ≥ 44 pt, OK.
Fixed-height scan, multi-line: `.frame(height:)` closing an H/V/ZStack that holds unlimited `Text` (10 hits; 4 real, the rest are
cover/photo boxes with a centred glyph, a 168 pt QR, a 240 × 150 video thumb or already `lineLimit(1)` + scale).

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `subpackageMember` 徽章墙 / 收集册 progress (`en-a11y-badges-ax5.jpg`) | `DesignSystem/CYCollectible.swift` (`CYCountRing`), `DesignSystem/CYAlbum.swift` (`CYAlbumProgressRing`) | ✓ (mp-mine owns order) | Ring track `bgRaised` → system `.quaternary` so the "remaining" half is visible (non-text contrast) in light and dark | Done |
| `pages/roam/*` roam-runner sheet head | `MPGap/PlayRoam/RoamRunnerDetailView.swift` | ✓ (mp-roam owns order) | Initial `.headline` in a fixed 52 pt circle → `@ScaledMetric(relativeTo: .headline)` circle, capped 96 | Done |
| Scratch-card prizes (motion r2 games) | `NativeR2/Motion/MotionR2Games.swift` | ✓ | Three tiles fixed 96 pt high clipped wrapped `.headline` prizes at AX sizes → min 96 pt, grows with text (`fixedSize` vertical), prize scales to 0.7 before wrapping | Done |
| City dice (`pages/roam` city game) | `DesignSystem/CYCityBoard.swift` (`CYCityDie`) | ✓ | Non-pip value / em dash `.dataXL` in a 56 pt die → one line, scales to 0.4 instead of clipping | Done |
| Onboarding long-press GO | `DesignSystem/CYOnboarding.swift` | ✓ | "GO" `.cardTitle` in a 52 pt circle → one line, scales to 0.5 at AX sizes | Done |
| `pages/play` seat lobby (invited / transferable seats) | `JourneyLandingViews.swift` | ✓ (mp-journey owns order) | Seat number `.cardTitle` in a fixed 28 pt column truncated to "…" at AX sizes for 2 digits → `minWidth: 28` | Done |
| `pages/play` report leaderboard | `JourneyReportViews.swift` | ✓ (mp-journey owns order) | Rank `.cardTitle` fixed 32 pt → `minWidth: 32` | Done |
| `pages/team` orient board ranking | `TeamOrientBoardView.swift` | ✓ (mp-activity owns order) | "#rank" fixed 32 pt → `minWidth: 32` (name column already wraps) | Done |
| `subpackageMember` orient score board | `MPGap/Member/OrientScoreGapViews.swift` | ✓ (mp-mine owns order) | Rank fixed 32 pt → `minWidth: 32` | Done |

## Run 12 (2026-11-27, half-hourly)

Merged `origin/ui/combined-r7` (46ebaf0b6, carries runs 7–11 incl. cb788fd86). Latest sweep is still build 405948d58 (read in
run 11), so the a11y sheets re-read waits for the next sweep. Not done item 3: `.fixedSize()` (both axes) scan, 23 player hits;
most are short chips, segmented pickers, switches or one-line numbers. 3 real overflows at AX sizes fixed:

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/club/*` club directory, Discover rows | `ClubDirectoryView.swift` (`ClubDirectoryCard`) | ✓ (mp-club owns order) | Fixed-size "Apply to join" / "Join club" button squeezed the club name to a sliver at AX sizes → row stacks (name, then button) at accessibility sizes via `AnyLayout` | Done |
| `pages/activity` registration sheet header | `RegistrationSheetView.swift` (`RegistrationPlayerSheetHeader`) | ✓ (mp-activity owns order) | Fixed-size bar title "Activity registration" pushed the ✕ off screen at AX5 → capped at `.xxxLarge` like the system inline title, plus Large Content Viewer | Done |
| `pages/coop/*` cooperation invites strip (inbox) | `IMCoopInviteStripView.swift` (header) | ✓ (mp-activity owns order) | Title + fixed-size "Invite alerts" switch + Received/Sent picker in one row → stacks at AX sizes | Done |

Fixed-width scan (`.frame(width: N)` on stacks / text, 19 player hits; the rest are icons, a 260 pt iPad sidebar, a 240 pt
share preview, progress bars and art tiles):

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/topic/*` 角色 cast rail | `CastViews.swift` (`TopicCastRow`) | ✓ (mp-publish owns order) | Column fixed 72 pt cut names to 2–3 letters at AX sizes → `@ScaledMetric(relativeTo: .footnote)` width (rail scrolls) | Done |
| `pages/play` story route cast rail | `NativeR2/Story/NR2StoryRouteSections.swift` | ✓ (mp-journey owns order) | Column fixed 64 pt → scaled `NR2CastColumn` (`relativeTo: .caption`) | Done |
| `pages/play` city-run finish leaderboard | `NativeR2/CityOrientation/CityOrientationFinishSummaryView.swift` | ✓ (mp-journey owns order) | Rank fixed 32 pt → `minWidth: 32` (same as run 11 leaderboards) | Done |

## Run 13 (2026-11-27, hourly)
Merged `origin/ui/combined-r7` (8fa84e4d3). Not done item 1: re-read the a11y sheets of sweep 8fa84e4d3 (22:11Z,
`docs/sweeps/latest/a11y-dt/sheet-en.jpg`, `sheet-zh-Hans.jpg`). `a11y-passport-ax5` now mounts the passport ✓ (20:55 note
closed); badge wall stacks one column ✓; roam chrome readable ✓. Fixed what the shots still showed:

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `subpackageMember` badge wall (`zh-Hans-a11y-badges-ax5.jpg`) | `DesignFixtures/E5bFixtures.swift` (`E5bBadgeWallFixture`) | ✓ (mp-mine owns order) | Heading beside the ring broke as "已收集 3 / 6" over two lines at AX5 → ring above heading at AX sizes (`AnyLayout`), count one token "3/6", heading trait | Done |
| `pages/member` passport actions (`en-a11y-passport-ax5.jpg`) | `PassportView.swift` (`PassportOverviewContent.action`) | ✓ (票夹 / 账户收益 / 消息, MP order) | Stacked AX capsules kept symbol-over-label (two tall lines each) → symbol leads the label on one line at AX sizes; default sizes unchanged | Done |
| `pages/roam` map chrome (`en-a11y-roam-ax5.jpg`) | `DesignFixtures/E5bFixtures.swift` (`A11yRoamAX5Fixture`) | ✓ (mp-roam owns order) | Peek showed a bare "—" as data → count "2" (P29) with a VoiceOver label; forced `.dark` removed (18:15 rule), title `textPrimary` so it reads on the light and dark map | Done |

Not done item 2 (fixed-width rails at AX5):

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/template/index` 精选 banner rail | `DiscoveryHomeView.swift` (`DiscoveryHomeBannerCard`) | ✓ (mp-publish owns order) | 260 pt tile + `lineLimit(2)` cut captions to 2–3 words at AX sizes → 300 pt and 4 lines at AX sizes; VoiceOver label = the highlight's own caption (was always "Open highlight n") | Done |
| (scan) other horizontal rails with fixed widths ≥ 120 pt | `DiscoveryTemplateDetailView` mosaic, `JourneyLandingViews` share render, `CYAlbum`, `CYShareCard`, `ClubChannelMessagingView` iPad sidebar | — | Image-only tiles, off-screen share renders or iPad sidebar: no text to clip; no change | Done (no fix needed) |
| `pages/templatedetail` 节点 rail | `DiscoveryTemplateDetailView.swift` (`DiscoveryTopicTemplatePreview`) | ✓ (mp-publish owns order) | 150 pt column broke node names letter by letter at AX sizes → 260 pt column at AX sizes (rail scrolls), cover follows the column | Done |
| `pages/templatedetail` image mosaic + node images | `DiscoveryTemplateDetailView.swift` | ✓ (mp-publish owns order) | VoiceOver heard "Open photo" for every tile → `accessibilityValue` "2 of 5" / "第 2 个，共 5 个" (existing `carousel.position` key) | Done |
| every MP image strip (shared gallery) | `NativeMediaGallery.swift` | ✓ | Value "1 / 5" was read as "one slash five" → `carousel.position` ("1 of 5" / "第 1 个，共 5 个") | Done |

## Run 14 (2026-11-27, half-hourly)
Merged `origin/ui/combined-r7` (a2baf94fa). Sweep index is still build 8fa84e4d3, so Not done item 1 (re-read sheets) waits.
Not done item 2: VoiceOver "n / N" values read as "slash" on player screens.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| review photo strip (retained images) | `RetainedPublicReviewImages.swift` | ✓ | "1 / 9" → `carousel.position` ("1 of 9" / "第 1 个，共 9 个") | Done |
| project draft story preview chapter picker | `ProjectDraftStoryPreviewView.swift` | ✓ (mp-publish owns order) | chapter "2 / 5" → `carousel.position` | Done |
| object card rotation frames | `ObjectCardViews.swift` | ✓ | frame "3 / 8" → `carousel.position` | Done |
| `playkit` question tries left (还能错) | `PlayKitQuestionForms.swift` | ✓ (mp-journey owns order) | "2 / 3" → new `a11y.value.ofTotal` ("2 of 3" / "2，共 3") | Done |
| character sheet attribute row | `CharacterSheetDetailView.swift` | ✓ | "7 / 10, level" → `a11y.value.ofTotal` + level | Done |
| group poll result bar | `GroupPollViews.swift` | ✓ (mp-club owns order) | votes "4 / 12" → `a11y.value.ofTotal` | Done |
| bundle review compose character counter | `BundleReviewComposeView.swift` | ✓ | "12/500" read as "twelve slash five hundred" → "12 of 500 characters" / "已输入 12 字，最多 500 字" | Done |

## Run 15 (2026-11-27, hourly)
Merged `origin/ui/combined-r7`. Not done item 1: re-read the a11y sheets of sweep **b3b03703a** (23:07Z, contains run 13).
`en-a11y-passport-ax5.jpg`: action capsules are symbol + label on one line at AX5 ✓, "3 of 12" stamps ✓.
`en-a11y-badges-ax5.jpg`: ring above the "3 of 6 collected" heading ✓, one-column wall ✓, localized date ✓.
`en-a11y-roam-ax5.jpg`: still wrong → fixed below.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/roam/index` collapsed sheet (`en-a11y-roam-ax5.jpg`) | `DesignFixtures/E5bFixtures.swift` (`A11yRoamAX5Fixture`) | ✓ (mp-roam owns order) | Title was `textPrimary` (black) on the black map panel in light mode (invisible) and "2" grey on black (< 3:1) → same `.regularMaterial` line + `.primary` foregrounds + chevron as the real `RoamBrowserView.peekLine` | Done |

Not done item 2: VoiceOver values built as `"\(a) / \(b)"` (read "slash" / "斜杠"). New catalog key
`a11y.value.characters` ("12 of 500 characters" / "已输入 12 字，最多 500 字"); positions use `carousel.position`, progress `a11y.value.ofTotal`.

| MP page / surface | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| image viewers (shared gallery, club post images, profile media ×2, album photo removal) | `NativeMediaGallery.swift:100`, `ClubPostImageGallery.swift:202`, `ProfileCurrentMediaPreview.swift:107,331`, `ProjectAlbumPhotoRemovalButton.swift:78` | ✓ | position "2 / 5" → `carousel.position` | Done |
| progress fractions (free-explore ring, journey discoveries, advanced team, explore completion, review photos) | `FreeExplorationViews.swift:157`, `JourneyNarrativeView.swift:112`, `PlayAdvancedTeamViews.swift:13`, `ExploreCompletionView.swift:155`, `ContextualReviewComposer.swift:118` | ✓ | → `a11y.value.ofTotal` | Done |
| character counters (playkit note + short message, trust report, creator text field + rehearsal, orient/report appeals ×3, object-card rename, player content ×2, stamp slip caption, member report, contextual review, journey review) | `PlayKitPersonalForms.swift`, `CommunityTrustPlayerViews.swift`, `TemplateCreatorConfigurationView.swift`, `TemplateCreatorRehearsalView.swift`, `MPGap/Member/OrientScoreGapViews.swift`, `MPGap/Member/ReportAppealAndCouponSummaryViews.swift`, `MPGap/PlayRoam/ObjectCardCategoryAndRenameSheets.swift`, `MPGap/PlayerContent/PlayerContentRound2Views.swift`, `MPGap/PlayerContent/PlayerContentRound4Views.swift`, `RoamSubpageParityViews.swift`, `CommunityMemberReportSheet.swift`, `ContextualReviewComposer.swift`, `JourneyReportViews.swift` | ✓ | → `a11y.value.characters` | Done |
| badge wall ring (zh) | `ObjectBadgeWallParityViews.swift:57` | ✓ (mp-mine owns order) | "已点亮 3 / 6 枚徽章" → "已点亮 3 枚徽章，共 6 枚" | Done |

## Run 16 (2026-11-28, half-hourly)
Merged `origin/ui/combined-r7` (793c3190b). Sweep 23:37Z (build 793c3190b) a11y sheets read: build predates run 15 (d926759a1 not
an ancestor), so `a11y-roam-ax5` still shows the black panel; re-read stays open. Badge wall ring-above-heading ✓, passport capsules ✓.
Not done item 2 (VoiceOver slash scan, rest): types checked against Core contracts; integer pairs → `a11y.value.ofTotal`.

| MP page / surface | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `subpackageMember` attributes (AXP progress, today / soft cap) | `MemberAttributesSection.swift:68,74` | ✓ (mp-mine owns order) | "120 / 500" → "120 of 500" / "120，共 500" | Done |
| Home return-account row | `HomeReturnSection.swift:23`, `NativeHomeReturnSection.swift:28` | ✓ (mp-home owns order) | same (Int64 pair) | Done |
| Club channel progress meter + team rows | `NativeChannelProgressBoardView.swift:327`, `NativeChannelProgressEntry.swift:150` | ✓ (mp-club owns order) | same | Done |
| `pages/play` lead sheet arrived / play lead arrived | `PlayToolsAndLeadSheetView.swift:264`, `PlayExperienceView.swift:1986` | ✓ (mp-journey owns order) | same | Done |
| `pages/topic` route progress | `TopicRouteMapAndTeamsSection.swift:45` | ✓ (mp-publish owns order) | same | Done |
| Creator rehearsal hotspots, rule-step count, editor add-row limit, prefab check score / DC | `TemplateCreatorRehearsalView.swift:117`, `TemplateAuthoringRuleFields.swift:58`, `EditorKitLists.swift:135`, `PlayPrefabRuntimeView.swift:50` | ✓ | same | Done |

## Run 17 (2026-11-28, hourly)
Merged `origin/ui/combined-r7`. Not done item 1: sweep **283dd3b52** (00:10Z, contains d926759a1) a11y sheets read.
`en-a11y-roam-ax5.jpg` / `zh-Hans-a11y-roam-ax5.jpg`: peek line "Nearby activities 2 ^" / "附近活动 2 ^" now reads on a
material bar above the panel at AX5 ✓ (two lines in en, one in zh, chevron visible). Closed.
Not done item 2 (slash scan leftovers): types verified in Core (`BallShake.hits/goal`, `owner.finalUsed/capacity`,
`NearbyTeamMapPin.memberCount/capacity`, walk `todaySteps/goal` all `Int`).

| MP page / surface | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `playkit` ball-shake sensor board (hits / goal) | `PlayKitSensorChallengeView.swift:139` | ✓ (mp-journey owns order) | "3 / 10" → `a11y.value.ofTotal` | Done |
| `pages/play` gameplay backpack capacity | `PlayRuntimeGapViews.swift:397` | ✓ (mp-journey owns order) | same | Done |
| `subpackageRoam` nearby teams sheet (members / capacity) | `MPGap/PlayRoam/NearbyAndHistoryGapViews.swift:91` | ✓ (mp-roam owns order) | "3/6" → `a11y.value.ofTotal`; literal no longer a catalog key (`Text(verbatim:)`) | Done |
| free-explore bundle booking step header (选章节 → 选商家 → 定时间) | `FreeExploreBundleLaunchView.swift:157` | ✓ (mp-activity owns order) | "1/3 · Chapter" → "1 of 3, Chapter" | Done |
| `playkit` walk challenge steps + percent | `PlayKitDecisionProgressViews.swift:122` | ✓ (mp-journey owns order) | "4,000 / 6,000 · 66%" → "4000 of 6000, 66%" | Done |

Home tab root code read (`pages/index/index` → `HomeFeedView.swift`): rail cards are one button element with a spoken
label (`pageTemplateGroupedCard(label:traits: .isButton)`, :386), each rail is a labelled container (:318), place row
is a separate 44 pt link with an "Open in Maps" action, 即将上线 countdown is plain text under the card. No change needed.

## Run 18 (2026-11-28, half-hourly)
Merged `origin/ui/combined-r7` (f8574edab). Coordinator 00:50 sweep (build f8574edab, roam + a11y-dt zh-Hans) finding for this lane first.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/roam/index` "附近活动" panel over the map (`zh-Hans-a11y-roam-ax5.jpg`, 00:50) + every `CYMapScaffold` / `CYRoamNearbySheet` map screen (nearby teams, play session map, density map) | `DesignSystem/CYMapChrome.swift` (`cyMapPanelColor`, grabber), `DesignSystem/CYRoamKit.swift`, `RoamBrowserView.swift` (map-mode list) | ✓ (mp-roam owns order) | Panel fill `Color.black` → system `.regularMaterial` (follows light / dark like the map, as `RoamMapHomePanel` already does with the system background); panel content already uses semantic colors, so it was dark text on black in light mode before. Grabber white 0.3–0.5 (invisible on a light sheet) → `.tertiary`; panel shadow 0.4 → 0.18 | Done (next sweep: `a11y-roam-ax5`) |
| `subpackageRoam` 集章册 cover (stamp album, not-done ring row) | `RoamStampViews.swift` (`RoamStampAlbumCover`), `DesignSystem/CYAlbum.swift` (`CYAlbumProgressRing`), `CYCollectible.swift` (`CYCountRing`) | ✓ (mp-roam owns order) | Ring numerals sized from the ring (which grows 1.4x / 1.6x at AX sizes): fine. Album cover put the 123 pt AX ring beside a `.display` title in one HStack → `AnyLayout` VStack at AX sizes (ring above title, same order); ring VoiceOver-hidden because the sentence under the title is the same text (was read twice). Badge wall header already `ViewThatFits`, `CYCountRing` hidden with the heading carrying the count: no change | Done |

## Run 19 (2026-11-28, hourly)
Merged `origin/ui/combined-r7` (conflict in the map panel fill: took ds-consistency's `CYColor.bgElevated` over run 18's
`.regularMaterial`, both follow the system appearance; `RoamBrowserView` background back to the plain `Color` form).
Not done item: sweep **907570051** (01:10Z) `en-a11y-roam-ax5.jpg`: the "Nearby activities 2 ^" panel is light under the
light map at AX5, black text, chevron visible ✓. Closed. `zh-Hans-a11y-passport-ax5.jpg`: 票夹 / 账户收益 / 消息 stack as full
lines, 印章 3 / 12 grid ✓. Then pages in the area without a row (largest player views first):

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `subpackageMember` cy-profile (other player's public profile) | `SocialPublicProfileView.swift` (identity head, 关注 / 发消息 row) | ✓ (mp-mine owns order) | Identity head avatar + name `HStack` → `AnyLayout` VStack at AX sizes (name under the 64 pt avatar, Contacts card); 关注 / 发消息 pills stacked full width at AX sizes (same order) instead of two truncated halves. Counters already wrap + combine | Done |
| `pages/topic/index` no-cover hero | `TopicDetailView.swift:294` | ✓ (mp-publish owns order) | Hero intro 1 → 3 lines at AX sizes (one line stays the MP look at regular sizes) | Done |
| `subpackageMember` 我的订单 (order card meta) | `ProfileOrdersView.swift` (`ProfileOrderRow.meta`) | ✓ (mp-mine owns order) | MP time / address icons fixed 16 pt → `@ScaledMetric(relativeTo: .subheadline)` so they keep pace with the text; footer AX stacking already present | Done |
| `pages/activity` detail, `pages/club` detail | `ActivityDetailView.swift`, `ClubDetailView.swift` | ✓ | Audit: no fixed frames, raw sizes, tap gestures or 1-line limits. No change | Done |
| `pages/publish/activity` 选择时间段 row | `PublishingModesViews.swift` (`ActivityPublishingView`) | ✓ (mp-publish owns order) | MP `icon_date3` fixed 12 pt → `@ScaledMetric(relativeTo: .body)` | Done |
| `subpackageTools` monthly recap week bars | `RoamPassportToolsViews.swift` (`RoamRecapWeekChart`) | ✓ (mp-roam owns order) | Non-max bars `.secondary.opacity(0.4)` (≈ 1.6:1) → `.secondary` (≥ 3:1 non-text contrast); each bar keeps its spoken week + count. Prev / next month chevrons already 44 pt | Done |
| `subpackageRoam` passport tiles, `pages/roam` home intro rows | `RoamHomeTabsView.swift` | ✓ | Audit: 36 pt list-row icons (Settings-style, not text), entry covers decorative. No change | Done |
| Reward pledge, wallet commerce, pass membership, profile edit | `RewardPledgeViews.swift`, `WalletCommerceViews.swift`, `PassMembershipViews.swift`, `ProfileEditView.swift` | ✓ | Audit: system Form / List rows, no fixed text frames, raw sizes or tap gestures. No change | Done |
| Chapter story artwork zoom | `ChapterStoryView.swift` | ✓ (mp-journey owns order) | Audit: double-tap zoom animates with `CYMotion.reduced`; image has its alt text; Close in the toolbar. No change | Done |

## Run 20 (2026-11-28, half-hourly)
Merged `origin/ui/combined-r7` (a32387e9b): map panel conflict → took mp-roam's follows-appearance panel, kept the grabber
`tertiaryLabel` in both modes (the panel is never black now, a white 50 % grabber vanished on the light `bgElevated` fill).
Sweep **a32387e9b** (01:40Z) a11y sheets read: `en/zh-Hans-a11y-badges-ax5` badge rows stack, localized date ✓;
`a11y-passport-ax5` 票夹 / 账户收益 / 消息 full-width lines, 印章 grid ✓; `a11y-roam-ax5` "Nearby activities 2 ^" panel
light under the light map, wraps at AX5 ✓. No open coordinator finding. Then Not done pages:

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/publishkit` project editor | `ProjectEditView.swift:607-609` | ✓ (mp-publish owns order) | Chapter / ticket insert-delete and canvas changes animated with `.default` regardless of Reduce Motion → `EditorKitMotion.move(reduceMotion:)` (spring; cross-fade under Reduce Motion), same as the editor's explicit moves | Done |
| `pages/template` authoring outline | `TemplateAuthoringView.swift` (`jump(to:)`) | ✓ (mp-publish owns order) | Outline / first-error jump scroll animated always → no animation under Reduce Motion | Done |
| `subpackageJourney` 已完成 (mycanyu history) | `PlayerJourneyViews.swift` (`CompletedPlayHistoryView`) | ✓ (mp-journey owns order) | Progress "3 / 5" read "3 slash 5" → `a11y.value.ofTotal` ("3 of 5" / "第 3 项，共 5 项" key from run 15); unknown count keeps "— / N". Rule figure 36 pt decorative, hidden | Done |
| Mod install, passport private tools, cooperation contextual | `ModInstallationView.swift`, `RoamPassportPrivateToolsViews.swift`, `CooperationContextualViews.swift` | ✓ | Audit: system List / Form rows, no raw sizes, fixed text frames, tap gestures, 1-line limits or unguarded animations. No change | Done |
| `subpackageJourney` profile question (MP `pf__count`) | `NativeR2/Games/NativeGameAnswerKits.swift:623` | ✓ (mp-journey owns order) | Counter "12 / 200" read "slash" → `a11y.value.characters` ("12 of 200 characters"), same key as `PlayKitPersonalForms`. Camera placeholder 120 × 90 decorative, hidden | Done |
| `pages/mylike` rows, search map explorer, roam item detail | `PlayerGapViews.swift`, `SearchMapExplorerView.swift`, `RoamItemDetailView.swift` | ✓ | Audit: 56 pt cover decorative + hidden, name wraps; no raw sizes, tap gestures or 1-line limits. No change | Done |
| Native game kits C (true/false, jigsaw, scratch, compare, accusation) | `NativeR2/Games/NativeGameKitsC.swift` | ✓ (mp-journey owns order) | Audit: options are Buttons with `.isSelected`, jigsaw tiles labelled with piece + position, swaps / reveals / suspect push gated on Reduce Motion (opacity fallback). No change | Done |

## Run 21 (2026-11-28, hourly)
Merged `origin/ui/combined-r7` (41374363f): `CYMapChrome.swift` conflict → took combined-r7's version as-is (coordinator
02:05: map panel settled, this lane no longer edits `CYMapChrome.swift` / the Roam panel). Sweep index still 41374363f with the
same a11y fixtures read in run 20 (passport / badges / roam AX5 clean), no open coordinator finding. Pages without a row:

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/club` 创建你自己的俱乐部 / 管理 entry (club tab, club detail manage tab) | `ClubOperationsViews.swift` (`ClubOperationsEntryButton`) | ✓ (mp-club owns order) | Label `.lineLimit(1)` at every size → no limit at AX sizes (the club tab already stacks the prompt and button there), so "Create a club" / 创建俱乐部 wraps instead of truncating in the detail list row | Done |
| `pages/club/create` 俱乐部方向 (pick up to 3) | `ClubOperationsViews.swift` (`checkRow`) | ✓ (mp-club owns order) | MP direction icon fixed 22 pt → `@ScaledMetric(relativeTo: .body)`; row already a Button with `.isSelected` and a hidden checkmark | Done |
| `subpackagePass` pass market cards + seal, club topic sheet, IM location picker | `PassMarketViews.swift`, `ClubGovernanceViews.swift:1634`, `IMExpandedViews.swift:961` | ✓ | Audit: price stacks at AX sizes, 44 pt seal / logo decorative or labelled; map tap has the "use map center" button alternative. No change | Done |
| Club governance command form, bundle commerce, channel management, external game import, publisher lifecycle, series schedule editor | `ClubGovernanceCommandForm.swift`, `BundleCommerceMount.swift`, `NativeChannelManagementViews.swift`, `ExternalGameImportView.swift`, `PublisherLifecycleViews.swift`, `ClubSeriesScheduleEditor.swift` | ✓ | Audit: system Form / List rows; only zero-size anchors and 44 pt / 24 pt icon frames; no raw sizes or 1-line limits. No change | Done |
| Timed game clock, exploration export file row, club post image row, parity kit glow | `NativeR2/Games/NativeGameTimedKit.swift:209`, `RoamExplorationExportView.swift:351`, `ClubPostImagePicker.swift:321`, `MPParityKit.swift:355` | ✓ | Audit: clock digits are one number (scale factor keeps it on one line, VoiceOver reads the value); file name / image URL middle-truncate under a wrapping title; glow decorative. No change | Done |

## Run 22 (2026-11-28, half-hourly)
Merged `origin/ui/combined-r7` (ad55acd94), clean. Sweep index still 41374363f (a11y fixtures read in run 20, clean), no
open coordinator finding for this lane. Pages without a row (largest player views):

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/club` 管理 → 入会申请 list | `ClubManagementView.swift:176` | ✓ (mp-club owns order) | Handled request card slide-out `.easeOut` always → no animation under Reduce Motion | Done |
| `pages/publishkit` 发布预览 查看将提交的全部内容 | `ProjectEditDetailForms.swift:593` (`ProjectEditReviewView`) | ✓ (mp-publish owns order) | Expand/collapse `withAnimation` always → none under Reduce Motion (chevron flips, value read "expanded/collapsed") | Done |
| `subpackageJourney` free-explore store map | `NativeR2/FreeExplore/NativeFreeExploreMapView.swift:559` | ✓ (mp-journey owns order) | Camera fly to the focused store animated always → jumps under Reduce Motion (draw-on already gated) | Done |
| `pages/club` 报名名单 per-session money (owner) | `ClubEnrollmentView.swift:341` | ✓ (mp-club owns order) | Session label `.lineLimit(1)` → wraps at AX sizes | Done |
| MP reviewed page screen, UGC safety, cooperation flow editors, play-area popups, story rule editor, mod upgrade | `MPReviewedPageScreen.swift`, `UGCSafetyComponents.swift`, `CooperationFlowEditors.swift`, `PlayAreaPopupCloseSurfaces.swift`, `StoryRuleEditorView.swift`, `ModUpgradeView.swift` | ✓ | Audit: no raw sizes, tap gestures, 1-line limits or unguarded animations; ModUpgrade "a / b" facts are id pairs (not counts, read as text). No change | Done |
| `subpackageJourney` 背包 (team + theme) | `PlayTeamBackpackView.swift:72`, `PlayThemeBackpackView.swift:115,461` | ✓ (mp-journey owns order) | Value "8 / 10" read "slash" → new key `a11y.value.ofTotalText %@ %@` ("8 of 10" / "8，共 10"; values are server number strings); zero-HP recovery progress → `a11y.value.ofTotal` | Done |
| `subpackageTools` 摇球 (ball shake) board | `NativeR2/Games/NativeGameSensorKit.swift:148` | ✓ (mp-journey owns order) | Big "hits / goal" combined read "3 slash 10, hits" → label "Hits", value `a11y.value.ofTotal` | Done |
| Account publish float cards, game shell score, chance kits DC gauge, G6 / NPC chat / official event thumbs | `AccountPublishR8Mounts.swift:839`, `NativeGameShell.swift:371`, `ChanceKits.swift:350`, `G6CapabilityViews.swift`, `NPCChatDataView.swift`, `OfficialEventDetailView.swift` | ✓ | Audit: float and score count-up already gated on Reduce Motion; DC gauge has its own label; fixed thumbs decorative + hidden. No change | Done |

## Run 23 (2026-11-28, hourly)
Merged `origin/ui/combined-r7` (already up to date). Sweep **ad55acd94** (03:04Z) a11y sheets read, en + zh-Hans:
`a11y-badges-ax5` rows stack, ring and localized date ✓; `a11y-passport-ax5` 票夹 / 账户收益 / 消息 full-width, stamp grid ✓;
`a11y-roam-ax5` "Nearby activities 2 ^" wraps on the light panel, rules · Go · map fit ✓. No open coordinator finding. Pages without a row:

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| Roam city board 护盾 / 升级 sheets (`subpackageJourney` city) | `CityKit/CityChallengeFlow.swift` (`CityShieldSheet`, `CityUpgradeSheet`) | ✓ (mp-roam / mp-journey own order) | Shield-on swap and failed-phase reset used springs regardless of Reduce Motion → `CYMotion.resolve(…, reduceMotion:)` (cross-fade under Reduce Motion) | Done |
| City claim checks (到达 / 拍照 checks) | `CityKit/CityClaimFlow.swift` (`CityCheckRow`) | ✓ | Status glyph (`.sectionTitle` = title3) in a fixed 28 pt slot clipped at AX sizes → `@ScaledMetric(relativeTo: .title3)` capped 56 | Done |
| `pages/playkit` 每日一签 (daily sign scratch) | `NativeR2/Games/ChoiceKits.swift` (`ChoiceDailySignKit`) | ✓ (mp-journey owns order) | Scratch reveal advanced the stage with a spring always → resolved through Reduce Motion | Done |
| Player kit header circles, sheet modal close, camera card reveal, sort kits, club ops event, payout receiver, player parity B, CYTilt | `DesignSystem/CYPlayerKit.swift`, `DesignSystem/CYSheetModal.swift`, `NativeR2/Games/CameraKits.swift`, `NativeR2/Games/NativeGameSortKits.swift`, `ClubOpsEventView.swift`, `ClubPayoutReceiverView.swift`, `PlayerParityBViews.swift`, `DesignSystem/CYTilt.swift` | ✓ | Audit: 36 / 28 / 32 pt circles sit inside 44 pt hit frames and are labelled; camera reveal is an opacity fade (the Reduce Motion fallback itself); tilt consumers (`MotionR2`, `CYFoil`, onboarding light) already gate on Reduce Motion; no 1-line limits or raw sizes. `CYTeamMemberRow` seat badge text in a 32 pt circle is fixture-only today (note for when it is mounted). No change | Done |

## Run 24 (2026-11-28, half-hourly)
Branch up to date with `origin/ui/combined-r7` (733bfb368). Sweep **733bfb368** (03:49Z) a11y sheets read, en + zh-Hans:
passport capsules full-width ✓, roam peek wraps on the light panel ✓; `a11y-badges-ax5` ring count "3/6" stayed ~23 pt under
~40 pt AX5 headings. No open coordinator finding for this lane.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/badge-wall` (fixture `a11y-badges-ax5`) | `DesignFixtures/E5bFixtures.swift` → `ObjectBadgeWallParityViews.swift` | ✓ (mp-mine owns order) | Fixture drew the fixture-only `CYCountRing`; now the shipped `CYAlbumProgressRing` (size 84, grows 1.4x at AX sizes, labelled "3 of 6 badges unlocked") so the sweep checks the real ring. Screenshot: `a11y-dt/sheet-en.jpg` tile 1 | Done |
| Stamp slam celebration (passport book tile) | `DesignSystem/CYCelebrationViews.swift` (`CYStampSlamView`) | ✓ | `.title2` book glyph in a fixed 48 pt tile overflowed at AX sizes → `@ScaledMetric(relativeTo: .title2)` capped 88 | Done |
| `subpackageJourney` route stops (play detail route list) | `DesignSystem/CYBusinessComponents.swift` (`CYRouteNodeRow`, used by `PlayExperienceView.swift:385`) | ✓ (mp-journey owns order) | Stop number / check / lock (`.caption`) in a fixed 28 pt node and 28 pt rail clipped at AX sizes → `@ScaledMetric(relativeTo: .caption)` capped 56 for node and rail | Done |
| `pages/roam` finish report (漫游总结) | `RoamFinishReportView.swift` (`bottomBar`) | ✓ (mp-roam owns order) | Share + Done half-width capsules with `lineLimit(1)` cut the labels at AX sizes → `AnyLayout` stacks them full-width at accessibility sizes (Share above the primary Done, order kept) | Done |

## Run 25 (2026-11-28, hourly)
Merged `origin/ui/combined-r7` (93bff6dcd). Sweep index still **733bfb368** (03:49Z), so the sheet re-read waits.
No open coordinator finding for this lane. Not done pages first:

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| Shared components (section header, CY buttons, empty/error, unread badge, avatar) | `DesignSystem/CYDesignComponents.swift` | ✓ | Audit: header `.headline` + `.isHeader` with `ViewThatFits` stacking, system button styles, unread dot/count and avatar labelled and localized (en + zh), avatar scale capped 1.35x. No change | Done |
| Native gallery screens | `NativeGallery/NativeGalleryScreens.swift` | — | Fixture-only (mounted from `DesignFixtureRegistry` only), skipped | Skipped |
| `pages/activity` official organizer console | `OfficialOrganizerConsoleView.swift` | ✓ (mp-activity owns order) | Audit: text styles only, every action ≥ 44 pt, pause fields labelled, the n/200 counter reads a localized sentence, denied/error states `ContentUnavailableView`. No change | Done |
| Roam city board 附近 drawer (`subpackageJourney` city roam) | `CityKit/CityRoamRootView.swift` (`CityNearbyDrawer.grabber`) | ✓ (mp-roam / mp-journey own order) | VoiceOver could only toggle peek ↔ medium and heard "Expanded" for both medium and large → adjustable handle (swipe up/down steps peek → half → full, Roam map panel pattern), value names all three heights, hint added; double-tap toggle kept | Done |
| `pages/roam` territory (领地 nearby spaces) | `RoamTerritoryView.swift` (nearby card) | ✓ (mp-roam owns order) | Up to six status chips (status · tile · distance · tier · level · decay) sat in one HStack and ran off the card in English / at AX sizes → `ClubR1WrapLayout` wraps them; Claim · Check in · Deed card row → `AnyLayout` VStack at accessibility sizes (same order) | Done |

## Run 26 (2026-11-28, half-hourly)
Merged `origin/ui/combined-r7`. Sweep **13a6690eb** (04:46Z, contains runs 24-25) a11y sheets read, en + zh-Hans:
`a11y-badges-ax5` ring now the shipped `CYAlbumProgressRing` at ~118 pt (grew 1.4x) ✓; `a11y-passport-ax5` capsules
full-width, "Ticket wallet" wraps inside its capsule ✓; `a11y-roam-ax5` peek "Nearby activities 2" wraps on the light
panel ✓. No open coordinator finding for this lane. Not done pages:

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| Shared tabs (项目/推文/成就/关于 etc.) | `DesignSystem/CYTabs.swift` | ✓ | Audit: system segmented `Picker` with `cyAdaptiveSegmented` (menu when a segment would truncate in en / AX sizes), badge read as "Title n". No change | Done |
| `pages/club` detail join / apply bar | `ClubActionPanel.swift` (inline + floating bar) | ✓ (mp-club owns order) | Settled 待审核 / 已加入 status painted its text `.orange` / `.green` (~2:1 on the bar) → text primary, only the glyph tinted (both placements) | Done |
| `pages/coop/list` invitation cards | `CooperationBrowserView.swift` | ✓ (mp-activity owns order) | Status chip + Spacer + "From X" squeezed one line at AX sizes, 拒绝 / 接受合作 pair side by side → `axStack` (`AnyLayout`) stacks both leading at accessibility sizes, same order | Done |
| `pages/play` orienteering score timeline | `OrientScoreView.swift` | ✓ (mp-journey owns order) | 申诉中 footnote in `.orange` (~2:1) → secondary text with an orange hourglass glyph; VoiceOver label unchanged | Done |
| `subpackageMember` participant form | `ParticipantFormView.swift` | ✓ | Audit: system `Form`, required marker hidden with a spoken hint, readback row wraps. No change | Done |
| Search links / template lanes | `GlobalSearchLinksAndTemplates.swift` | — | Data / routing only, no UI | Skipped |
| Status text contrast batch (activity countdown, 免费 price, club lead picker, payout receiver, media review state, channel onboarding 必填, organizer console applied, roam official paused) | `ParticipationParityViews.swift:74`, `ActivityPresentationComponents.swift:88`, `ClubSeriesLeadPicker.swift:105`, `ClubPayoutReceiverView.swift:152`, `SettingsPrivacyLocationView.swift:287-289`, `NativeChannelOnboardingView.swift:183`, `OfficialOrganizerConsoleView.swift:293`, `RoamOfficialArrivalSection.swift:105-107` | ✓ (owning lanes keep order) | System `.orange` / `.green` / `.red` text (~2:1 to 3.5:1 on white) → design-system `CYColor.warningText` / `successText` / `dangerText` (light `#96610A` / `#0B7A57`, ≥ 4.5:1; dark variants legible) | Done |
| `pages/activity` detail reviews + club event payment notice + search map offline | `ActivityReviewsSection.swift:88`, `SearchMapOfflineBanner.swift:67` | ✓ | Review stars VoiceOver read "4 slash 5" → `a11y.value.ofTotal` ("4 of 5" / "4，共 5"); orange notice / "still offline" text → `CYColor.warningText` | Done |

## Run 27 (2026-11-28, hourly)
Merged `origin/ui/combined-r7`. Sweep **a4142df0d** (05:15Z; predates run 26) a11y sheets read, en: `a11y-badges-ax5` ring
"3/6" + Collected / Locked rows stack, localized date ✓; `a11y-passport-ax5` Ticket wallet / Earnings / Messages full-width,
stamp grid ✓; `a11y-roam-ax5` "Nearby activities 2" wraps on the light panel, i · Go · map fit ✓. No open coordinator finding.
Not done list (multi-line status text contrast):

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/club` 活动运营 occurrences / series, club tab quota, governance series receipt, topic card 剧情就绪, settlement unverified | `ClubOpsEventView.swift:432,436,438,477,565`, `ClubTabParityViews.swift:50`, `ClubGovernanceCommandForm.swift:432`, `ClubTopicDetailRows.swift:185`, `ClubOpsSettlementViews.swift:26` | ✓ (mp-club owns order) | Label text + glyph in system `.orange` / `.green` / `.red` (~2:1 to 3.5:1 on white) → `CYColor.warningText` / `successText` / `dangerText` (≥ 4.5:1 light, legible dark) | Done |
| `pages/topic` owner review 审核中, `pages/publishkit` condition author / atmosphere / node play saved / context publish result, channel progress privacy | `TopicXcxSections.swift:107`, `NativeConditionAuthorView.swift:51,75`, `ProjectChapterAtmosphereFields.swift:138`, `TemplateAuthoringView.swift:379`, `PublishingContextHandoffViews.swift:171,206`, `NativeChannelProgressPrivacyView.swift:93,144` | ✓ (mp-publish / mp-club own order) | Same token swap (warning / success text) | Done |
| `pages/index` search tab disabled reason, reward ledger reversal line | `HomeSearchTabParityViews.swift:1578`, `EnvironmentBranchAndRewardLedgerSectionView.swift:244` | ✓ | Same token swap (warning text) | Done |
| Status text contrast sweep, 83 lines in 56 player files (team, club home/detail/directory, IM voice, square card lifecycle + upcoming kicker, publish AI / pricing, playkit games, free explore, roam POI, social, creator studio …) | AccountPublishR8Mounts, ChoiceKits, ClubContextualViews, ClubDetailView, ClubDirectoryView, ClubHomeView, ClubLeadProgressView, ClubProjectLaunchView, ClubSessionQuickStartView, CreatorContentViews, CreatorMaintenanceViews, CreatorPostGameOutcomeView, DiscoveryTemplateDetailParitySections, GroupPollOriginalResultView, IMDriftEntries, IMVoiceViews, MemberTemplateDetailView, NativeAttributeAuthorViews, NativeBlacklistView, NativeChannelChainView, NativeFreeExploreArrivalSheet, NativeFreeExploreMapView, NativeFriendMetadataView, NativeGameAnswerKits, NativeGameKitsB, NativeGameSensorKit, NativeGameTimedKit, NativeMotionReminderViews, NativeStampCaptureView, NativeWebhookManagementEntry, OfficialEventComponents, OfficialOrganizerConsoleView, PlayKitPersonalForms, ProfileComplaintPreparationView, ProfileOrdersView, PublisherLifecycleViews, PublishingAIDraftSheet, PublishingAIQuotaSection, RegistrationSheetView, RoamOfficialArrivalSection, RoamPOIActions, SocialActionViews, SocialInviteHistoryView, SquarePostLocalMediaPresentation, SquareXcxPostCard, TeamHomeView, TeamPageParityViews, TeamReformFlowViews, TeamSeatFactsViews, TemplateAdditionalSampleBrowserView, TemplateAdoptionViews, TemplateLegacyQuestionRehearsalView, TopicPublicationViews, TopicXcxSections, WithdrawalSupportContactView, WorkshopCreatorPendingView | ✓ (owning lanes keep order) | Scripted pass: every `Text` / `Label` (same line or the next modifier line) coloured with system `.orange` / `.yellow` / `.green` → `CYColor.warningText` / `successText` (≥ 4.5:1 light, legible dark). Glyph-only hits (an `Image` on the line or the line before, large result symbols) left as they are (non-text 3:1 holds) | Done |
| `pages/club` 入群欢迎语 editor (owner) | `ClubWelcomeNoteEditor.swift:71` | ✓ (mp-club owns order) | Over-limit counter `.red` → `CYColor.dangerText`; VoiceOver read "12 slash 200" → `a11y.value.characters` ("12 of 200 characters"). Other ternary `? .green : .red` hits are internal `*SectionView` screens (out of scope) | Done |

### Run 28 (2026-11-28)
Merged `origin/ui/combined-r7` (135f87720). Sweep **7a7d2708a** (05:38Z) a11y sheets read, zh-Hans: `a11y-badges-ax5` ring 3/6 +
已收集 / 未解锁 rows stack ✓; `a11y-passport-ax5` 票夹 / 账户收益 / 消息 full-width, 印章 3/12 grid ✓; `a11y-roam-ax5` 附近活动 2 on the
light panel, i · 走起 · map fit ✓. No open coordinator finding. Not done item: `.red` text contrast.

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| Error / validation / warning text on every player page (login error, club governance + ops forms, channel moderation/roles/mention, publish validation + refusal footers, square delete failed, IM voice play failed, pass refund, enrollment issue, team join code, games notices, profile save failed, shared error state …) | 187 lines in 128 player files (Merchant / Fixture / Diagnostics / Debug skipped; `WorkshopModUpgradeSheetView.swift` left: its source is sha256-pinned by `test_workshop_paid_reentry_closure`) | ✓ (layout untouched) | `.foregroundStyle(.red)` / `.foregroundColor(.red)` on text → `CYColor.dangerText` (system red #FF3B30 on white is ~3.6:1, below 4.5:1). Image-only glyph lines and ternaries left (3:1 graphics rule) | Done |
| Two-state status text (seat facts warning, report / complaint / club ops / host cancel counters, friend removal + blacklist result, channel banners, publish wizard chips, topic publication + location todos, login / auth channel issue, invoice notice, AI quota, team invite copy, game answer marks, sensor loudness, preview pager) | 37 ternaries in 29 player files (`*SectionView` readiness panels = internal diagnostics, skipped; club like heart = glyph, left) | ✓ (layout untouched) | `cond ? Color.red : …` → `CYColor.dangerText`, paired `Color.green` / `Color.orange` → `CYColor.successText` / `warningText` (system green ~2.2:1, red ~3.6:1 on white) | Done |

### Run 29 (2026-11-28)
Merged `origin/ui/combined-r7`. Sweep index still **7a7d2708a** (05:38Z, read in run 28), so the sheets re-read waits. No open
coordinator finding. Not done item: `.lineLimit(1)` in HStacks with two texts (scripted scan of player views, 15 hits; share cards,
medal stack night cells, ring numerals and live HUD numbers left: fixed-size art or a single big number).

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `subpackageJourney/pages/settle` 结算 facts (分数 / 站点 / 桌面完成 / 开局) | `JourneyReportViews.swift:1089` (`JourneySettleView`) | ✓ (mp-journey owns order) | Up to four data2XL cells in one `HStack(spacing: xxxl)` clipped off both sides at AX5 → `settleFactsLayout` (`AnyLayout`): same row at standard sizes, a centred column in the same order at accessibility sizes. Level A motion untouched | Done |
| Error / unknown-result states (OWN-OPT-072 request reference, every player page that shows it) | `RequestReferenceRow.swift` | ✓ | Reference shrank to 70 % and cut to one line → wraps up to 3 lines at full size; the Copy button moves under the reference at accessibility sizes (P: stack, never shrink) | Done |
| `pages/club` post card author meta, post-ref chip | `ClubComponents.swift:437`, `MPGap/Club/ClubGapRemainingViews.swift:24` | ✓ (mp-club owns order) | "Club · time" and the picked post title were one line (truncated at AX sizes) → up to 2 lines | Done |
| `pages/topic` publisher row | `TopicXcxSections.swift:97` | ✓ (mp-publish owns order) | Publisher name one line beside fixed "posted" → up to 2 lines (outer row already stacks at AX) | Done |
| Shared status badge (reference tasks, play / journey state chips) | `QuestifyMotionComponents.swift:61` (`QuestifyStatusBadge`) | ✓ | Status words shrank to 75 % on one line → wrap to 2 lines at full size (badge already `fixedSize(vertical:)`). `.minimumScaleFactor` scan: the other 73 player hits are big numerals / ring counts / ticket codes (one number, allowed) | Done |

### Run 30 (2026-11-28)
(Twin run 29 already took the status badge; this run takes the other body / caption hits.)
Merged `origin/ui/combined-r7` (ffeef67c7). Sweep **ffeef67c7** (06:48Z) a11y sheets read, en: `a11y-badges-ax5` ring 3/6 +
Collected / Locked rows stack ✓; `a11y-passport-ax5` Ticket wallet / Earnings / Messages full-width, Stamps 3 of 12 ✓;
`a11y-roam-ax5` Nearby activities 2 wraps on the light panel, i · Go · map ✓ (runs 28-29 not yet in this build). No open
coordinator finding. Not done item: `.minimumScaleFactor` on body / caption text (74 player hits read; big numerals, avatar
monograms, share / ticket art, HUD and ring numbers left as they are).

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/publishkit` project schedule start / end | `ProjectEditFlowParity.swift:48` | ✓ (mp-publish owns order) | Date shrank to 70 % in a half-width column → 2 lines, no shrink | Done |
| Story cast lines (margin speaker name) | `CastViews.swift:83` | ✓ | Caption name shrank to 80 % in the fixed margin → up to 3 lines, full size | Done |
| `pages/roam` city orientation ETA (预计 12分钟 · 14:32 到达), teams on route | `CityOrientationNavComponents.swift:57`, `CityOrientationRunView.swift:635` | ✓ (mp-roam owns order) | ETA one line shrunk to 80 % → 2 lines; teams-on-route footnote 2 lines + shrink → 3 lines, no shrink. Map panel files untouched (coordinator 02:05) | Done |
| `pages/roam` city orientation paused tag + stop cleared, platform reminder 已开放 | `CityOrientationNavComponents.swift:69,124`, `NativeMotionReminderViews.swift:254` | ✓ (mp-roam owns order) | Label text in `Color.orange` / `Color.green` (~2.2:1 to 3:1 on white) → `CYColor.warningText` / `successText`. Remaining `Color.green` / `Color.yellow` hits are glyph-only (medal, checkmark; 3:1 graphics rule) | Done |

### Run 31 (2026-11-28)
Merged `origin/ui/combined-r7`. Sweep index still **ffeef67c7** (read in run 30), so the sheets re-read waits. No open coordinator
finding. Not done item: Reduce Motion — `withAnimation` / `.animation` with `.spring` / `.bouncy` / `.snappy` (23 player hits without
"reduce" on the line read with their context).

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/roam/index` map home bottom panel (detents) | `NativeR2/MapHome/RoamMapHomePanel.swift` | ✓ (mp-roam owns order) | The only file with a spring and no Reduce Motion read: drag release, VoiceOver adjust and the detent `.animation` used `.snappy` → `settle` = `CYMotion.reduced` (short ease, no overshoot) under Reduce Motion, `.snappy` otherwise. Not the settled `CYMapChrome` / `RoamBrowserView` panel (coordinator 02:05) | Done |
| Other spring hits (club welcome, free-explore pack, games HUD, night tab bar, section reveal, signature, progress ring, purchase / scan failure nudge, roam kit, onboarding, collectible, object card pile, chat send, live stat roll) | `ClubMemberWelcomeSheet`, `FreeExplorationViews`, `NativeGameHUD`, `CYNightTabBar`, `CYExploreKit`, `CYSignature`, `CYCoverArt`, `CYPurchaseMotion`, `CYRoamKit`, `CYScan`, `CYOnboarding*`, `CYCollectible`, `PlayRoamRound4Views`, `MessageActionComposer`, `RoamLiveSessionView` | ✓ | Audit: each is behind an earlier `reduceMotion` guard / else, renders its final state when Reduce Motion is on (opacity / trim forced to 1), swaps to the grid layout (object card pile), or is a colour fill / numeric roll. `.transition(.move / .slide / .asymmetric)` scan: every hit gated. No change | Done |
| `pages/club` post card 赞, channel sidebar (current channel) | `ClubCommunityViews.swift:769`, `ClubChannelMessagingView.swift:505` | ✓ (mp-club owns order) | VoiceOver selected-state scan (custom buttons whose selected state shows only by colour / glyph, no `.isSelected`): liked heart and the open channel row now add `.isSelected` (Square like already does, run 4) | Done |
| `pages/playkit` hangman (active letter cell), `pages/publishkit` wizard step bar, creator studio feedback picker | `PlayKitQuestoViews.swift:208`, `DesignSystem/CYBusinessComponents.swift:1249` (`CYPublishStatusBar`), `CreatorMaintenanceViews.swift:170` | ✓ (mp-journey / mp-publish own order) | Same: the typing cell, the current wizard step and each picked feedback row add `.isSelected`. Other hits are menus with checkmarks (system), rows with their own `accessibilityValue` (step checklist), or merchant (`MerchantRootModeSwitchBannerView`, skipped); `CYMapChrome` left (settled, coordinator 02:05) | Done |
| Hold-to-start buttons (roam GO pill, city hold) and long-press / context-menu actions | `DesignSystem/CYPlayerKit.swift:788`, `CityKit/CityHoldButton.swift:40` | ✓ | Audit: every player `.onLongPressGesture` has an `accessibilityAction` that commits (VoiceOver / Switch Control get a plain activation; city hold drops to 0 s under Reduce Motion); `.contextMenu` / `.swipeActions` are exposed to VoiceOver by the system as actions. No change | Done |

### Run 32 (2026-11-28)
Merged `origin/ui/combined-r7`. Sweep **3348aa51f** (07:26Z, contains runs 28-30) a11y sheets read: `en-a11y-badges-ax5` ring +
Collected / Locked rows wrap, `en-a11y-passport-ax5` Ticket wallet / Earnings / Messages capsules wrap in blue on tint, stamps
"3 of 12" ✓, `en-a11y-roam-ax5` Nearby activities 2 wraps on the light panel, i · Go · map ✓. No open coordinator finding.
Not done item: meaningful images with no label (scripted scan of status / verified / lock / warning / offline / muted symbols
outside `Label` icons, buttons and combined / hidden parents: 10 hits, 7 already hidden inside a labelled parent).

| MP page | Native view file | MP sections present | Optimization applied (a11y-dt) | Status |
|---|---|---|---|---|
| `pages/club` channel sidebar (muted channel) | `ClubChannelMessagingView.swift:498` | ✓ (mp-club owns order) | The muted bell was the only cue that a channel is muted; VoiceOver now hears "Muted" / "免打扰" (existing `messaging.muted`) | Done |
| Offline banner (all player lists) | `DesignSystem/CYStatusOfflineBanner.swift:53` | ✓ | `wifi.slash` beside the offline message hidden (the banner already speaks its label + message) | Done |
| `pages/publishkit` wizard issue list | `DesignSystem/CYBusinessComponents.swift:1291` | ✓ (mp-publish owns order) | Issue rows (jump to step) were 32 pt tall → 44 pt target; the warning and arrow glyphs are hidden so VoiceOver reads only "Step n: message" | Done |
| `pages/city` roam root: City Monopoly stat link, Fog / Territory chips | `CityKit/CityRoamRootView.swift:257,297` | ✓ (mp-roam owns order) | 44 pt targets scan: the board link was 32 pt tall → 44; the layer chips keep their 36 pt capsule look inside a 44 pt hit area | Done |
| In-game channel entry (play HUD chat button) | `InGameChannelEntryViews.swift:155` | ✓ (mp-journey owns order) | 32 × 32 icon button → 44 × 44 hit area (`CYSpacing.minTouchTarget`), glyph size unchanged | Done |
| Stamp created, journey settle seal, ticket verified, pass verified, collectible / cover lock, in-place result, city claim step | `RoamStampCameraView`, `JourneyReportViews`, `E1TicketCard`, `CYPassVerified`, `CYCollectible`, `CYCoverArt`, `CYInPlaceResult`, `CityClaimFlow` | ✓ | Audit: each glyph is inside an `.ignore` / hidden parent whose text or label says the state. No change | Done |

## Not done (next run starts here)
- Re-read the a11y sheets after the next sweep (newer than 3348aa51f, to see runs 31-32).
- Next pages without a row: 44 pt targets, second half — buttons whose label is sized by padding only (no frame) with
  `.caption` / `.footnote` text, e.g. inline chips and "more" links. (Run 32: `.frame(min)Height` < 44 on buttons fixed:
  publish issue rows, city board link + layer chips, in-game channel button; the rest are decorative or already wrapped in 44.)

## For other lanes
- en-layout: `RoamTerritoryView.swift` nearby/mine cards format "\(Int(dist))m" and "\(n) pts" by hand; use `Measurement`/`.formatted` and a localized points string.
- **mp-home / mp-mine** (sweep 17:24, `a11y-passport-ax5`): the screen is still dimmed under the grey launch
  overlay with the logo watermark at capture time (same symptom as the 16:53 `d2-home` note) — it must never dim a
  tab root. Also the `a11y-passport-ax5` fixture opens the badge wall, not the passport.
- Release-exclusion audit (`tools/check_design_fixture_release_exclusion.py`) fails on combined-r7 independent of this lane:
  `CityDiceFixture`, `CityKitFixture*`, `D2MeFixture`, `E3PressStyle`, `FixR3PlayRoamBFixtures`, `R3InPlaceKitFixture`, `R4*` are
  declared under `App/DesignFixtures` but missing from `DesignFixtureReleaseExclusionAudit.symbols` (ds-consistency / owning lanes).
- i18n-r3: `ClubComponents.swift:357` video play glyph `.accessibilityLabel(Text(verbatim: "Play"))` is English-only.
- i18n-r3: `MPGap/Club/ClubGapRound4Views.swift` accessibility label `"删除凭证图片 \(index + 1)"` is a Chinese literal key (no en).
- mp-roam: `cyMapPanelColor` is now `CYColor.bgElevated` (ds-consistency, kept in run 19); re-check any map panel content you own that assumed a black panel (white text / white strokes).
