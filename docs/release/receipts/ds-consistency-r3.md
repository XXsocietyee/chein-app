# ds-consistency · round 3 receipt (2026-11-27)

Branch `design/r3-consistency` from `origin/ui/combined-r7`. Scope: OWNER RULE 2 — it is an app, so native
navigation and **one** design system on every player surface. Merchant and the story-flow theme are out of scope;
nothing deployed. No Swift compiler in this environment: edits are type-simple and mirror existing patterns.

## New gate: `tools/check_design_consistency.py`

`python3 -B tools/check_design_consistency.py` (stdlib only). Scans player-facing `App/**/*.swift` — skips paths with
`Merchant`, `Fixture`, `DesignFixtures/`, `Diagnostics`, `#Preview { … }` blocks and comments — and counts per file:

| Kind | What it catches | Use instead |
|---|---|---|
| raw font | `.system(size:` (unless the size is an `@ScaledMetric`), `.font(.custom(`, `Font.custom(`, `UIFont.systemFont(ofSize:`, `UIFont(name:` | Dynamic Type text styles / `.cyText(_:)` |
| tracking | `.tracking(` / `.kerning(` | system letter spacing |
| root title | a tab-root file without `.cyRootHeader(` / `.navigationBarTitleDisplayMode(.large)` | `cyRootHeader(_:)` |
| pushed large | `.navigationBarTitleDisplayMode(.large)` outside the tab roots / design system | inline title (`cyPageTitle`) |
| title mode | a file that sets navigation titles but never a display mode — a pushed page then inherits the tab root's large title | `.navigationBarTitleDisplayMode(.inline)` / `cyPageTitle` |
| hidden nav | `.navigationBarHidden(true)`, `.toolbar(.hidden, for: .navigationBar)`, `.toolbarBackground(.hidden, for: .navigationBar)`, `.navigationBarBackButtonHidden(true)` | system bar + system back |
| custom back | `CYNavBar(` / `CYBareBackButton(` / `CYHeroBackButton(` outside `App/DesignSystem` | system back; `cyGuardedBack(when:onBack:)` for unsaved changes |
| button style | a page-level `struct …: ButtonStyle` outside `App/DesignSystem`, or `.buttonStyle(.questifyPrimary)` | `.borderedProminent` / `.bordered` / `.borderless` or the CY styles |
| popup scrim | `Color.black.opacity(0.2…0.8).ignoresSafeArea(` outside `App/DesignSystem` (MP popup copied as a dimmed overlay) | `.sheet` + `.presentationDetents` |
| raw colour | `Color(red:` / `UIColor(red:` / `Color(hex:` / `"#RRGGBB"` / `0xRRGGBB` outside `App/DesignSystem`, `App/Theme` | semantic system colours / CY palette |
| list style (continue) | `.listStyle(…)` other than `.insetGrouped` — 190 sibling list pages use `.insetGrouped`, so `.plain` / `.grouped` / `.inset` / `.sidebar` is a mix | `.listStyle(.insetGrouped)` |
| custom sheet (continue) | hand-made MP popup / half-screen outside `App/DesignSystem`: `.accessibilityAddTraits(.isModal)`, a `CYColor.bgOverlay` / `Color.black.opacity` scrim with `.ignoresSafeArea().onTapGesture`, a drawn grabber `Capsule()…frame(width: 3x–4x, height: 4–6)` | `.sheet` + `.presentationDetents` + `.presentationDragIndicator` |
| custom tabs (continue) | hand-made tab / segment row: `ForEach` over tabs / segments whose items are `Button`s compared with the selection; `CYNightTabBar(` / `CYDomainTabBar(` outside `QuestifyApp.swift` | `Picker` + `.cyAdaptiveSegmented()`, `CYTabs`, system `TabView` |

The checker now also fails on a **stale allowed entry** (an allowed kind with no hit left in its file), so the allowed
list can only shrink as chrome is fixed; `--update` drops stale entries.

Tab roots checked (`TAB_ROOTS`): `HomeFeedView` (首页), `DiscoveryTemplateBrowserView` (发布), `ClubHomeView` (俱乐部),
`AccountView` (我的, signed in), `WelcomeView` (我的, signed out). 漫游 is the full-screen map home (allowed chrome).

Baseline `tools/design_consistency_baseline.json`:
- `allowed` = intentional chrome with a reason per file+kind (game HUDs, full-screen maps, procedural art, exported share
  images, data colours). These never fail.
- `baseline` = remaining debt counts; a count above it fails, so a new violation fails. `--update` ratchets down only.

Start of round (combined-r7 984b1a529): **raw font 42, tracking 13, root title 1 (+ Home transparent bar), pushed
large 2, hidden nav 9, raw colour 14.** Now: **0 baselined debt**, 59 allowed hits (all with reasons). Wired into
`tools/check_scaffold.py` next to the design lint. Self-test: injecting `Text("a").font(.system(size: 12)).tracking(1)`
into `AccountView.swift` fails with both kinds at that line.

## Fixes (file → change)

| MP page | Native view | MP sections | Change (owner rule 2) |
|---|---|---|---|
| `pages/index/index` | `App/HomeFeedView.swift` (`HomeFeedHeroChrome`, `HomeFeedHeroEdge`) | unchanged, MP order kept (banner → greeting/city → location card → 编辑精选 → 附近活动 → 即将上线 → feed tabs) | Restored the standard large top-left title 首页: removed the transparent inline bar, the banner bleeding under the status bar/nav bar and the MP-style logo in the bar (brief: "lanes that moved a banner under a transparent nav bar must restore the standard large title"). The banner is the first row under the title. |
| `pages/member/index/index` (signed out: `cy-empty` 登录后查看我的主页 + 登录) | `App/WelcomeView.swift` | unchanged | The signed-out 我的 tab root was inline with no title; now `cyRootHeader(.mine)` like the signed-in root. The welcome flow (`onBrowse != nil`) keeps its inline bar. |
| `subpackageA/pages/myproject/index` (我的项目, pushed) | `App/PublishingManagementViews.swift:107` | unchanged | Pushed page forced `.large` → inline title. |
| — (design kit) | `App/DesignSystem/CYScreenStyle.swift` `cyHeroPushedChrome` | — | Hand-made back chevron + hidden system back → standard `cyPushedChrome` (system back). No call site used it. |
| — (design kit) | `CYCelebrationViews`, `CYChapterFlip`, `CYExploreKit` (`cyEyebrow`), `CYOnboarding`, `CYMedalStack`, `CYShareCard`, `CYTicketPass`, `PlayThemePresentation`, `RoamNearbyParityExtras` | — | Removed all custom `.tracking` / `.kerning` (10 sites). |
| IM / channel / template pushed pages | `IMVoiceViews` (2), `TemplateAuthoringLaunchView`, `NativeWebhookInboundLogView`, `NativeWebhookDeliveryLogView`, `NativeChannelMessageContextView`, `TemplateRootRehearsalView` (2), `NativeChannelProgressPrivacyView` (2), `NativeZeroHPAuthorView`, `NativeChannelMessagePinsView`, `NativeChannelCheckinView` (2), `NativeChannelMessageRevisionView`, `NativeChannelMessageAttachmentView`, `NativeChannelMessageSearchView`, `NativeChannelNotificationConversationView`, `NativeChannelManagementViews` (4), `NativeChannelOnboardingView` (2), `CityOrientationFinishSummaryView`, `ProjectEditLaunchView`, `NativeChannelChainView`, `NativeChannelProgressOwnHistoryView`, `TemplateSampleBrowserView`, `TemplateAdvancedGameConfigurationView`, `FreeExplorationVisitConfigView` | unchanged | 31 pushed titles had no display mode, so they inherited the tab root's large title; now `.inline` like every pushed page. |
| play / roam / NPC / registration actions | 20 files: `NativeFriendTeamInviteEntry`, `NativeFriendChannelInviteEntry`, `PlayDeviceTaskViews`, `PlayKitQuestionForms`, `PlayKitScreen` (2), `ShopNPCView` (2), `WithdrawalApplyParitySection`, `RoamPassportPrivateToolsViews`, `RoamSubpageParityViews` (3), `PlayExperienceView` (2), `MapPublicLayerSectionView`, `RoamStampViews`, `TemplateAuthoringPublishResultPresentation`, `PlayComponents`, `PlayOpeningCompletionSection`, … | unchanged | Parallel primary style `.questifyPrimary` (28 player sites) → system `.borderedProminent`. `NPCQuickPillStyle` → `.bordered` + `.buttonBorderShape(.capsule)`; `RegistrationRoundCloseStyle` → `.bordered` + `.buttonBorderShape(.circle)`; both page styles deleted. Merchant call site (`PublicMerchantReviewEditor`) left as is (out of scope). |
| MP settle `st-pop` (journey 谢谢 popup) | `App/JourneyReportViews.swift` `thanksCard` | unchanged (star · 谢谢 · 去分享; mask does not close it) | Hand-made dimmed overlay + floating card → native `.sheet` with `.medium` detent and `.interactiveDismissDisabled()`. |
| 漫游 history / run cards | `App/RoamSubpageParityViews.swift:23, 115` | unchanged | Rounded heavy *italic* stat numerals → `.title3.bold()` / `.headline` with monospaced digits, matching `CYRecordStatGrid`. |
| — (legacy type tokens) | `PlayComponents`, `PlaySharedPlanLifecycleView`, `PlayTaskOutcomeSection`, `CityAcquisitionPresentationStyle` (2) | — | `.font(Theme.Font.body)` → shared `.cyText(.body)` (one type system). |
| — (design kit) | `CYChromeBars` (back glyphs → `.body`/`.title3`), `CYBusinessComponents` (fallback cover `.largeTitle`, step node glyphs `.caption`, stepper `.footnote`), `CYSheetModal` (close `.footnote`), `CYGoHold` (`.title3`), `CYCelebrationViews` (name `.system(.largeTitle, design:weight:)`, empty glyph `.largeTitle`), `CYPassVerified` (`.title`) | — | Fixed-point glyph/text sizes → Dynamic Type text styles (11 sites). |

## Continue run (2026-11-27, after merging combined-r7 007558f9f)

Ratchet: allowed hits that were not game / map chrome were fixed, stale allowed entries removed
(`SquareBrowserView` pushed large, `RoamFinishReportView` hidden nav — no hit left on the merged tree).

| MP page | Native view | MP sections | Change (owner rule 2) |
|---|---|---|---|
| 城市 notice card (首页 / 漫游 territory notice) | `App/CityKit/CityTerritoryNoticeCard.swift:42` | unchanged | Page-level `CityNoticePressStyle` deleted; the card uses the shared `QuestifyCardButtonStyle` like every other tappable card (one press feedback). |
| — (DEBUG design fixtures) | `App/ClubComponents.swift` → `App/DesignFixtures/E3Fixtures.swift` | — | `E3PressStyle` moved into the DEBUG-only fixtures file that is its only user; shipped code has no page-level button style left. |
| `pages/playkit/components/playkit-accusation` `ac-cf` confirm / `ac-cl` clue popups | `App/PlayKitQuestoViews.swift` `PlayKitCenteredPanel`, `confirmPanel`, `cluePanel` | unchanged: confirm (initial · 你确定是 X 吗 · identity · final note · unavailable note · 确认 / 再想想), clue (label · image · name · text · 收起) | Dimmed `bgOverlay` scrim + floating card (`.isModal`) → native `.sheet` with `.medium` / `.large` detents and the system grabber; swipe down does what 再想想 / 收起 does (closes, no write; the MP mask itself is inert, the explicit buttons stay). |
| 收集册 `album-head` (勋章 / 邮票 / 藏品) | `App/CollectionAlbumViews.swift` `CollectionAlbumHead` | unchanged: same three segments in MP order, segments without a destination still hidden | Hand-drawn capsule chip row with a matched-geometry pill → system segmented `Picker` (`.cyAdaptiveSegmented()`: menu at accessibility sizes), selection haptic, ids kept. |
| — | `App/MPParityKit.swift` `MPChipTabs` | — | Unused hand-made chip tab bar deleted (0 call sites), so no page can pick it up again. |

New allowed (with reasons): 漫游 City board place sheet / nearby drawer (Maps-style persistent sheets over the live
map), 首页 shelf feed `.grouped` (edge-to-edge App Store-style rails), channel chat transcript `.plain`, 漫游 browser
map-mode results panel `.plain`, two unreferenced internal command hubs, merchant root mode switch (merchant out of
scope).

## Continue run 2 (2026-11-27, after merging combined-r7)

Receipt had no Not done rows. TASKS:

### Build-break guards in `tools/check_design_consistency.py`
App/ + Core/ compile into one Swift module, so these two kinds scan **every** `App/**` and `Core/**` Swift file
(merchant and fixtures included) and fail like any other new violation (baseline 0, nothing baselined):

| Kind | What it catches | Today's incident it would have stopped |
|---|---|---|
| duplicate type | the same top-level `struct` / `class` / `enum` / `protocol` / `actor` / `typealias` name in two places. `private` / `fileprivate` top-level types only clash inside their own file; declarations in different branches of one `#if … #else` are not a clash (an `#if DEBUG` copy next to an unconditional one is). | f17bc6663: a second `PlayRouteNotice` (Core/PlayExperienceContracts.swift vs Core/PlayCommandRefusal.swift) |
| undeclared state | in a SwiftUI `View` struct (its body + every `extension Name` in the module): a `$name` binding or an assignment `name = …` / `self.name = …` / `name += …` whose name is never declared (`var` / `let` incl. `let a = x, b = y` lists, `inout` params, enum cases, `{ $row in` bindings, `[x = y] in` capture lists, module globals). String literals are blanked first. | 73c6432b1: `governanceMemberCount = $0` with no `@State private var governanceMemberCount` |

Self-test: reverting f17bc6663 (rename back to `PlayRouteNotice`) fails with both files and lines; deleting the
`governanceMemberCount` declaration fails at `App/ClubGovernanceViews.swift:1596`; a `private struct HomeFeedView` in
another file and an `#if DEBUG struct Bar / #else struct Bar` pair pass. Merged tree: 0 hits for both kinds. Runtime
~12 s (fast paths for lines without quotes / slashes).

### New kind `font design` + fixes
`design: .rounded` / `.serif` or `.fontDesign(.rounded/.serif)` outside App/DesignSystem + App/Theme (a per-page
numeral face). `.monospaced` code editors (condition author, preference JSON) are fine.

| MP page | Native view | MP sections | Change (owner rule 2) |
|---|---|---|---|
| playkit games (dice / chance total, walk steps, silent timer, timed clock, compass, sensor value) | `App/NativeR2/Games/ChanceKits.swift:106, 240`, `NativeGameSortKits.swift:284, 290, 395`, `NativeGameTimedKit.swift:158`, `NativeGameSensorKit.swift:189, 224` | unchanged | Five ad-hoc variants of `.system(.largeTitle, design: .rounded).weight(.bold / .semibold)` → the one stat numeral token `.cyText(.dataXL)` (largeTitle, bold, rounded, monospaced digits). |
| motion metrics (run HUD value) | `App/NativeR2/Motion/MotionR2Metrics.swift:76` | unchanged | `.heavy` rounded largeTitle → `.cyText(.dataXL)`. |
| challenge value row | `App/NativeR2/Games/NativeGameTimedKit.swift:270` | unchanged | rounded `.title` → `.cyText(.pageTitle, weight: .semibold, monospacedDigit: true)`. |
| 城市 game panel stat tiles | `App/CityGamePanel.swift:203` | unchanged | rounded `.title3` → `.cyText(.sectionTitle, weight: .bold, monospacedDigit: true)` (matches `CYRecordStatGrid` / roam stats). |

Allowed (reasons in baseline): crossword grid letters (`PlayKitQuestoViews` puzzle face), coin sparkle glyph
(`CityTokens` procedural art).

### Not done (next run)
| Item | Why not now |
|---|---|
| `App/RoamOfficialTasksView.swift:131` 官方任务 keyword field is a `.roundedBorder` `TextField` in the first List section → should be `.searchable(text: $keyword, prompt:)` on the List (brief: custom search fields → `.searchable`). | `Tests/AppUITests/RoamOfficialTasksFlowTests.swift:37` drives it as `app.textFields["roam.tasks.search"]` and the test file is hash-pinned in `tools/current_ci_manifest.json`; change together with the test + manifest review. |
| 14 other player `.textFieldStyle(.roundedBorder)` fields inside List / Form rows (PlayKit forms, roam stamp / subpage notes, nearby team lat/lng, journey, channel composer) — native Form rows use the plain field. | Needs a per-screen look at whether each sits in a List row or on a card; not a safe text rewrite. |

## Continue run 3 (2026-11-27, after merging combined-r7 into 1a8f38d59)

Not done rows from run 2:

| MP page | Native view | MP sections | Change (owner rule 2) / status |
|---|---|---|---|
| `subpackageRoam/components/scene-roam-task-list` (官方任务: `task-search` → `task-tabs` → `task-summary` → stale/refreshing → list / `cy-empty`) | `App/RoamOfficialTasksView.swift` | all present, MP order (search first, always visible, then 进行中/即将/我的 segmented, summary, states, list) | Done. Hand-made `.roundedBorder` keyword `TextField` in the first List row → system `.searchable(text:placement: .navigationBarDrawer(displayMode: .always), prompt:)` on the List (same keyword binding, same filtering, cleared on owner change). UI test `RoamOfficialTasksFlowTests.testSourceKeywordHasRealNoResultsState` retargeted from `app.textFields["roam.tasks.search"]` to `app.searchFields.firstMatch`; its sha256 row in `tools/current_ci_manifest.json` updated (only that row; `current_ci.py check` already fails on the base for other lanes' unaudited test edits). Simulator run still needed. |
| 14 player `.textFieldStyle(.roundedBorder)` fields | `PlayKitPersonalForms` (2), `PlayKitNewGameForms`, `PlayKitDecisionProgressViews`, `PlayKitLegacyViews`, `PlayKitTimedChallengeView`, `JourneyReportViews`, `RoamSubpageParityViews`, `RoamStampViews`, `NearbyTeamViews` (DEBUG lat/lng), `CommunityTrustPlayerViews`, `ClubChannelMessagingView` composer, `AccountDeregistrationImpactSection`, `StoryRuleEditorView` (story-flow, out) | unchanged | Closed, no change: each sits on a card / VStack / ScrollView, not in a List or Form row, and `.roundedBorder` is exactly what the design-system field `CYField` draws — consistent already. |

Next scan (hand-made search fields → `.searchable` / one filter-row pattern):

| MP page | Native view | MP sections | Change |
|---|---|---|---|
| `pages/coop/invite` target filter | `App/CooperationContextualViews.swift:461` | unchanged (kind segmented → filter → loading / retry / empty + 刷新合作对象 → targets) | Bare `TextField` in a Form row → the same filter row the friend picker uses (`Label` with the `magnifyingglass` symbol, `.submitLabel(.search)`, no autocorrect/caps); `.searchable` not used because the Form is a row inside a host navigation container (same reason as `NativeFriendPickerView`). |
| 漫游 browser map-mode search | `App/RoamBrowserView.swift:350` | — | Kept: Maps-style pinned field inside the persistent results sheet; list mode already uses system `.searchable` (`RoamBrowserView.swift:720`). |
| — (design kit) | `App/DesignSystem/CYField.swift` `CYFormSearchRow` | — | New shared row for a search filter that is one row of a Form / List section (`.searchable` belongs to a whole page): `Label` with `magnifyingglass` + system `TextField`, `.submitLabel(.search)`, no autocorrect / caps, optional `onSubmit`, identifier on the field. |
| `pages/coop/invite`, friend picker (d7), activity template picker (`ActivityTemplateSelection`) | `CooperationContextualViews.swift`, `NativeFriendPickerView.swift:26`, `ActivityTemplateSelectionView.swift:111` | unchanged (fields, order, identifiers `context.coop.search` / `activityTemplate.search` kept; activity template still reads on submit) | Three hand-built Form search rows in two layouts (`Label` vs `HStack`, different keyboard options) → one `CYFormSearchRow`. |

New checker kind **custom search**: `Image(systemName: "magnifyingglass")` with a `TextField(` within 3 lines, outside
App/DesignSystem → use `.searchable` or `CYFormSearchRow`. Baseline 0; allowed: `RoamBrowserView` map-mode sheet field
(reason in the baseline). Self-test: the pre-fix `ActivityTemplateSelectionView.swift` fails at line 113.

## Continue run 4 (2026-11-27, after merging combined-r7 f043090ce)

Receipt had no Not done rows. Took the 16:37 sweep row addressed to mp-nav + ds-consistency (`d2-city`).

| MP page | Native view | MP sections | Change (owner rule 2) |
|---|---|---|---|
| 城市 board (`CityPlayerView`, reached from 漫游 → 城市 and 领地; not a tab root) | `App/CityPlayerView.swift:93` | unchanged (city title → season / membership chips → rules → arrival / onsite / neutral entries → game slot → points / empty) | The city name was drawn **on** the generated `CYCoverArt` gradient (`.background`), hard to read in both languages. Now the standard hero: `CYHeroHeader { Cloud07Cover(...) }` — 16:9 cover above, title in `.title.bold()` on the system background, same as `CityNeutralTaskRuntimeHostView`. |
| — | 16:37 "no large top-left title" on `d2-city` | — | Not a defect for this lane: `CityPlayerView` is a pushed page (inline title per owner rule 2); the fixture hosts it in its own `NavigationStack` so it looks like a root. The bar title is empty on purpose because the hero header carries the one visible title (`cyHeroScreen`). Tab roots are already enforced by the `root title` kind (0). |

New checker kind **text on art**: `.background` whose content (same or next line) is `CYCoverArt(` outside
App/DesignSystem → put the cover above the text as the hero illustration. Baseline 0, nothing allowed. Self-test: the
pre-fix `CityPlayerView.swift` fails at line 95.

## Continue run 5 (2026-11-27, after merging combined-r7)

Receipt had no Not done rows. Scan: one segmented-control pattern (85 pickers use `.cyAdaptiveSegmented()`, 8 used a
bare `.pickerStyle(.segmented)` that truncates in English / at accessibility sizes where the siblings switch to the
system menu).

| MP page | Native view | MP sections | Change (owner rule 2) |
|---|---|---|---|
| `subpackageRoam/components/scene-roam-task-list` `task-tabs` (进行中 / 即将 / 我的) | `App/RoamOfficialTasksView.swift:134` | unchanged | `.pickerStyle(.segmented)` → `.cyAdaptiveSegmented()` (identifier kept). |
| 漫游 home peek near / city strip tabs | `App/RoamHomeTabsView.swift:137` | unchanged | same (city name can be long in English). |
| 漫游 stamp album 我的 / 收到的 | `App/NativeR2/FreeExplore/NativeStampAlbumView.swift:40` | unchanged | same. |
| 漫游 领地 附近格子 / 我的领地 / 赛季排行 | `App/RoamTerritoryView.swift:174` | unchanged | same ("Leaderboard" is the long one). |
| workshop installed text 原文 / 已安装 | `App/WorkshopPaidInstalledTextView.swift:71` | unchanged | same; hash pin in `test_workshop_protected_text_lifecycle.py` updated with a one-line reason (presentation only). |
| — (DEBUG native gallery) | `App/NativeGallery/NativeGalleryScreens.swift:228, 392` | — | same. |
| 附近队伍 地图 / 列表 toolbar switch | `App/NearbyTeamMapViews.swift:33` | — | Kept (allowed, reason in baseline): a `.fixedSize()` toolbar control with two short titles; the adaptive swap is for in-content pickers. |

New checker kind **raw segmented**: `.pickerStyle(.segmented)` outside App/DesignSystem → `.cyAdaptiveSegmented()`.
Baseline 0; 1 allowed. Self-test: restoring the old `RoamOfficialTasksView.swift:134` line fails at that line.

Gates (merged tree + this batch): `generate_project` PASS, `check_scaffold` PASS (design consistency: 0 debt, 65
allowed, raw segmented 0), `check_a11y_lint` PASS (0 new), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

## Continue run 6 (2026-11-27, after merging combined-r7 into 75f53bd9e)

Receipt had no Not done rows. Scan: legacy APIs (`NavigationView`, `ActionSheet`, `.foregroundColor`) — 0 real hits
on player screens. Scan: toolbar placement (owner rule 2 "toolbar items in the standard places"; P16 "share + save at
the top bar, one Done"). 17 leading toolbar items on player screens: Close / Cancel / back / `EditButton` / merchant
switch / the documented 消息 tab-root 全部已读 are standard; three result sheets put Share / Replay in the **leading**
slot (where every other sheet has Cancel / Close) while `SocialInviteHistoryView` and `ExternalGameImportView` share
trailing.

| MP page | Native view | MP sections | Change (owner rule 2) |
|---|---|---|---|
| city orientation finish (medal / 城市定向 完成) | `App/NativeR2/CityOrientation/CityOrientationFinishSummaryView.swift:162` | unchanged | `ShareLink` `.topBarLeading` → `.primaryAction` (trailing, next to 完成). Identifier `medalScreen.share` kept. |
| playkit game result sheet (passed) | `App/NativeR2/Games/NativeGameShell.swift:282` | unchanged | same; identifier `nativeGames.result.share` kept. |
| motion route replay result | `App/NativeR2/Motion/NativeR2RouteReplay.swift:242` | unchanged | 再看一遍 replay `.topBarLeading` → `.primaryAction`; identifier kept. |

New checker kind **leading action**: a `.topBarLeading` / `.navigationBarLeading` toolbar item whose content (same or
next 2 lines) is a `ShareLink(` or a share / replay glyph, outside App/DesignSystem → trailing `.primaryAction`.
Baseline 0, nothing allowed. Self-test: the pre-fix `NativeGameShell.swift` fails at line 282.

Gates: `generate_project` PASS, `check_scaffold` PASS (design consistency: 0 debt, 65 allowed, leading action 0),
`check_a11y_lint` PASS (0 new), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Batch 2 — one place for Done
Sheets whose only dismiss is Done put it trailing in 30 places (`.confirmationAction`, Apple default) and leading in
15 (`.cancellationAction`, the Cancel slot). Cancel + Done pairs (`ContextualPickers`, `NativeConditionAuthorFieldForm`,
`PublishingModesViews`) and the keyboard Done in `CooperationContextualViews` are correct and unchanged.

| MP page | Native view | MP sections | Change (owner rule 2) |
|---|---|---|---|
| 漫游 bundle action / coupon detail / order lifecycle (sheets) | `FreeExploreBundleLaunchView.swift:142`, `CouponManagementView.swift:158`, `ProfileOrdersView.swift:217` | unchanged | Done `.cancellationAction` → `.confirmationAction` (trailing); identifiers kept. |
| channel message context / pins / revision / search | `NativeChannelMessageContextView.swift:76`, `NativeChannelMessagePinsView.swift:67`, `NativeChannelMessageRevisionView.swift:55`, `NativeChannelMessageSearchView.swift:135` | unchanged | same. |
| NPC chat data + read settings, avatar draft, club media editor | `NPCChatDataView.swift:232`, `NPCChatDataReadSettingsEntry.swift:120`, `ProfileAvatarDraftSection.swift:193`, `ClubProfileMediaEditor.swift:92` | unchanged | same (club media keeps `.disabled` while uploading). |
| topic self play (2 sheets), free exploration ending letter, play tools sheet | `TopicSelfPlaySheet.swift:143, 193`, `MPGap/PlayRoam/FreeExplorationEndingLetter.swift:45`, `MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift:202` | unchanged | same. |

New checker kind **done leading**: a `Button("….done")` in a `.cancellationAction` / leading toolbar item (window cut
at the next `ToolbarItem`) with no `.confirmationAction` within 8 lines. Baseline 0, nothing allowed. Self-test: the
pre-fix `TopicSelfPlaySheet.swift` fails at lines 143 and 193.

Gates (batch 2): `generate_project` PASS, `check_scaffold` PASS (design consistency 0 debt, 65 allowed, done leading 0),
`check_a11y_lint` PASS (0 new), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

## Continue run 7 (2026-11-27, after merging combined-r7 into 31ce3e369)

Receipt had no Not done rows. Scan: one card / radius pattern (OWNER RULE 2 "one list/card pattern"; native restyle r1
"one card radius 12, one hero radius 20"). 94 player call sites wrote a literal `cornerRadius:` — 13 different radii
(2, 3, 4, 6, 7, 8, 9, 10, 12, 12.5, 14, 16, 18, 20, 22, 24, 48) next to the `CYRadius` scale, so sibling cards,
thumbnails and icon tiles had different corners. Content, order and identifiers unchanged on every screen (MP decides
content; this is look only).

| Pattern | Native views (file:line on this branch) | Change |
|---|---|---|
| cards 12 / 14 / 16 / 10 (material, grouped fill, dice tile, placeholder) | `PlayExperienceView.swift:2302`, `CityOrientationRunView.swift:308`, `PlayGameStageViews.swift:79`, `PlayKitDecisionProgressViews.swift:42`, `PlayKitCameraPresentation.swift:127`, `ObjectBadgeViews.swift:240`, `ChapterStoryView.swift:754` (18), `RoamAndExplorationParitySectionView.swift:294` (10) + every literal 12 (CityKit deed / board / claim, ticket pass, route map stops, roam passport / stamps, map layer, playkit forms, welcome route map, motion games, route replay …) | → `CYRadius.card` (12) |
| thumbnails / covers inside a card 8 / 10 | `HomeFeedView.swift:545`, `TemplateShelfArt.swift:161, 183`, `ClubStoryViews.swift:139, 241, 303`, `ClubActivityListContent.swift:67`, `RoamRunnerDetailView.swift:87-88`, `DiscoveryTemplateDetailView.swift:498`, `RoamSubpageParityViews.swift:538, 720`, `BundleShelfView`, `TicketWalletView`, `ClubComponents`, `ClubBadgeManagementView`, `RoamCityGuide`, `RoamHomeTabsView`, `RoamMapHomeRoutes`, `RoamMapHomePlaceCard`, `SocialGuideTemplateSection`, `ProjectEditDetailForms`, `AccountComplianceViews:732` | → `CYRadius.inner` (8, concentric with the 12 card) |
| icon tiles / chips 7 / 9 / 10 / 6 | `SettingsSupportSections.swift:202` (Settings icon tile), `MessagingMessageDetailView.swift:293`, `CYPeopleComponents.swift:106, 135`, `CityBoardScreens.swift:153`, `MapPublicLayerSectionView.swift:148`, `AccountComplianceViews.swift:719` | → `CYRadius.sm` (8): every icon tile in a row now has the same corner |
| Messages-style bubbles 16 / 18 / 22 | `MessagingHistoryView.swift:660` (notice), `IMStaticLocationCardView.swift:21` (location bubble), `ClubPostDiscussion.swift:121` (comment bubble, was 16), `NativeChannelTextComposer.swift:82-83` (composer field, was 22) | → new token `CYRadius.bubble` (18) in `App/DesignSystem/CYDesignTokens.swift` |
| heroes 20 / 22, sheet frame 24 | `MotionR2Metrics.swift:87` (22), `CityDeedCard`, `CityBoardScreens:74, 203`, `MapPublicLayerSectionView:59`, `PlayKitDecisionProgressViews:90`, `MotionR2Rewards:194-200`; `MotionR2Flows.swift:157` (24) | → `CYRadius.hero` (20) / `CYRadius.sheet` (24) |

New checker kind **raw radius**: a literal non-zero `cornerRadius: N` outside App/DesignSystem and App/Theme. Baseline 0;
allowed with reasons (procedural art drawn to its own frame): `CityMomentView` coin ticket, `MotionR2Rewards` postage
stamp perforation, `ProfileBadgesView` holo sheen on the round medal, `RoamSubpageParityViews` MP stamp printer art and
scratch foil. Self-test: the pre-fix `SettingsSupportSections.swift` fails at line 202.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_typography_lint` PASS,
`check_design_consistency` PASS (0 debt, 74 allowed, raw radius 0), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

Stale pin updated: `Tests/ContractChecks/test_object_badge_wall_layout.py` detail hash (artwork clip 16 →
`CYRadius.card`, look only; one-line reason in the test).

## Continue run 8 (2026-11-27, after merging combined-r7 into f3aeebd42)

Receipt had no Not done rows. Scan: one type system, line height (OWNER RULE 2 "fonts, letter spacing … consistent").
`.cyText(.body)` already applies the one reading leading (CYTypeSpec lineHeight 1.6, scaled with Dynamic Type), but 7
reading paragraphs set 4 / 5 / 6 / 8 pt by hand on top of it — fixed points that do not scale and differ page to page.
Content, order, identifiers and text selection unchanged (look only).

| MP page | Native view | MP sections | Change (owner rule 2) |
|---|---|---|---|
| 角色 / cast line | `App/CastViews.swift:76` | unchanged | `.font(italic ? .body.italic() : .body).lineSpacing(8)` → `.italic(italic).cyText(.body)` |
| chapter story text block | `App/ChapterStoryView.swift:369` | unchanged | `.cyText(.body)…lineSpacing(8)` → `.cyText(.body)` only |
| story reader narration | `App/NativeR2/Story/NR2StoryReaderParts.swift:39` | unchanged | `.font(.body).lineSpacing(6)` → `.cyText(.body)` |
| play theme intro line | `App/PlayThemePresentation.swift:101` | unchanged | dropped `.lineSpacing(6)` after `.cyText(.body)` |
| shop NPC guide rules / materials | `App/ShopNPCScriptedGuideView.swift:24, 28` | unchanged | dropped `.lineSpacing(4)` after `.cyText(.body)` |
| project edit story field | `App/ProjectStoryTextField.swift:93` | unchanged | dropped `.lineSpacing(5)` after `.cyText(.body)` |

New checker kind **line spacing**: a literal `.lineSpacing(N)` outside App/DesignSystem and App/Theme. Baseline 0,
nothing allowed. Self-test: the pre-fix tree fails in all six files (ShopNPC 2).

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_typography_lint` PASS,
`check_design_consistency` PASS (0 debt, 74 allowed, line spacing 0), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

## Continue run 9 (2026-11-27, after merging combined-r7 3568fe51b)

Receipt had no Not done rows. Scan: one status-word pattern (OWNER RULE 2 "one list/card/empty/loading pattern").
Native r2 status words are `CYStatusChip` (footnote `Label`, system tone colour, **no capsule**; 249 call sites), but
player pages still drew their own soft-tint capsule chips (opacity 0.12–0.15, padding 6–8 / 1–2). Content, order,
keys and identifiers unchanged (look only).

| MP page | Native view | MP sections | Change (owner rule 2) |
|---|---|---|---|
| 漫游 passport private tools (tile 新 tag) | `App/RoamPassportPrivateToolsViews.swift:99` | unchanged | accent soft capsule → `CYStatusChip("roam.private.new", tone: .info).singleLine()` |
| 漫游 live topic sheet (免费 / 城市 tag above the title) | `App/RoamLiveTopicSheet.swift:104` | unchanged | `.tint` soft capsule → `CYStatusChip(…, tone: .info)` |
| map public layer row (marker state) | `App/MapPublicLayerSectionView.swift:196` (in 搜索 map explorer) | unchanged | secondary soft capsule → `CYStatusChip(…)` (neutral) |
| `pages/play` rank board 更多 scope button | `App/JourneyReportViews.swift:224` | unchanged (scope picker → 更多 → hero → period picker) | hand-drawn capsule (`CYNight.ink2` / selection 0.2 fill, `.plain`) → system `.bordered` + `.buttonBorderShape(.capsule)`, secondary tint until a more-scope is chosen; identifier `rankBoard.more` and 44 pt height kept |

New checker kind **status capsule**: a `Capsule` filled with a colour at opacity 0.05–0.29 (`.fill` or
`.background(…, in: Capsule())`; stroked rings are not counted) outside App/DesignSystem and App/Theme. Allowed:
`PlayJourneyContentViews` difficulty scale (three tiers, one lit; a read-only scale, not a status word). Baselined debt
29, all in internal `*SectionView` / release-ledger diagnostic screens (out of player scope; story-flow
`StoryWalkingAndFogSectionView` on hold). Self-test: the pre-fix tree fails in the four player files above.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_typography_lint` PASS,
`check_design_consistency` PASS (status capsule 29 baselined debt, 75 allowed), `contract_ratchet --check` 52 failing,
baseline 52, **new 0**.

Not done (run 9) → done in run 10 below.

## Continue run 10 (2026-11-27, after merging combined-r7 into eb141b5c1)

Run 9 Not done row: `.buttonStyle(.plain)` buttons whose label draws its own filled capsule / rounded background.
Scanned all player files (26 plain buttons with a drawn background in the 14 lines above). Per site: game cells
(hangman letters, jigsaw tiles, accusation clue pins, preference options, journey mode tiles), map controls on a
material (`CityRoamRootView`, `CityMapLayer`, `RoamFinishReportView`, `SearchMapCanvas`, `PlayRouteMapView`) and card
rows are not button looks and stay. `CityHoldButton` is hold-to-confirm (custom gesture, allowed). Two real primary
actions drew their own capsule; one unused helper did too. Content, order, copy and identifiers unchanged (look only).

| MP page | Native view | MP sections | Change (owner rule 2) |
|---|---|---|---|
| 城市地盘 live run (继续 / 正在定位… / 正在结束… bottom action) | `App/CityKit/CityLiveOnMap.swift:149` | unchanged | `.plain` + hand-drawn `actionPrimaryBg` capsule, 52 pt → `.borderedProminent` + `.buttonBorderShape(.capsule)` + `.controlSize(.large)`, palette tint kept; identifiers `city.live.*` kept |
| `subpackageP3/badge-3d` badge detail 分享徽章 | `App/ObjectBadgeViews.swift:274` | unchanged | ShareLink label drawn as a 56 pt capsule on a 96 % page-colour strip → `.borderedProminent` capsule `.large` on the standard `.bar` material; `.cardTitle` → `.button` text style (same as every primary button) |
| search map (dead code) | `App/SearchMapComponents.swift` `searchNightPill` | n/a | unused hand-drawn pill helper removed (0 call sites) |

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(status capsule 29 baselined debt, 75 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0** (badge detail
hash pin in `test_object_badge_wall_layout` updated with a one-line reason).

### Not done (next run)
| Item | Why not now |
|---|---|
| — | Receipt empty; next run picks the next design-system scan (candidate: one empty-state pattern — hand-built `VStack { Image; Text }` empty states vs `ContentUnavailableView` / `CYStateView`). |

## Continue run 11 (2026-11-27, after merging combined-r7 into f8d340832)

Run 10 lead (empty states): scanned every player `VStack { Image(.largeTitle); Text }` and `Label … icon:` empty
block — all already sit inside `ContentUnavailableView` / `CYEmptyState`; the eight hand-built candidates are a
store tile, a friend header, a reward card, the gift-code hero, the stamp draft card and the player-code placeholder,
none an empty state. Closed, no change. Sweep sheets (a250afd77, mp-club / mp-mine zh-Hans) re-checked for
button / title mixes: club invite is system `.bordered`, passport actions are `.bordered`; the passport large title and
the dark badge wall are mp-mine fixture rows (already in the 20:25 sweep). Next scan: one loading pattern (P10 "never a
spinner alone"). 11 player loaders were a bare `ProgressView()` stretched full width (some with a VoiceOver-only
label), next to `CYLoadingState` (system `ProgressView` + the MP loading words 加载中… / Loading…). Content, order,
identifiers unchanged; the label that VoiceOver already heard is now also visible.

| MP page | Native view | MP sections | Change (owner rule 2 / P10) |
|---|---|---|---|
| 漫游 bundle launch (free-explore pass) | `App/FreeExploreBundleLaunchView.swift:66` | unchanged | silent spinner → `CYLoadingState(messageIdentifier: "freeBundle.loading")` |
| channel redeem sheet | `App/ChannelRedeemSheet.swift:61` | unchanged | → `CYLoadingState(messageIdentifier: "channelRedeem.loading")` |
| 俱乐部 calendar | `App/ClubEventCalendarView.swift:94` | unchanged | → `CYLoadingState(messageIdentifier: "club.calendar.loading")` |
| 俱乐部 governance / topic story | `App/ClubGovernanceViews.swift:654, 2441` | unchanged | VoiceOver-only `club.loading` / `club.story.loading` → visible `CYLoadingState(…)` (ids kept) |
| 俱乐部 invitation feedback list + detail | `App/ClubInvitationFeedbackView.swift:232, 357` | unchanged | → `CYLoadingState("club.loading")`; pin in `test_club_invitation_terms` updated (one-line reason) |
| 俱乐部 manage coop pool | `App/MPGap/Club/ClubGapManageExtensions.swift:77` | unchanged | → `CYLoadingState()` |
| 会员 membership / pass library | `App/PassMembershipViews.swift:98, 437` | unchanged | → `CYLoadingState(messageIdentifier:)` (`membership.loading` keeps the full-height frame) |
| bundle reviews (unmounted) | `App/BundleReviewListView.swift:10` | unchanged | → `CYLoadingState()` |

New checker kind **silent spinner**: a bare `ProgressView()` line followed by `.frame(maxWidth: .infinity` outside
App/DesignSystem. Baseline 0; allowed: merchant-only locality status in `ClubHomeView`, story-flow chapter rule editor
(`ProjectEditChapterRulesSection`). Self-test: the pre-fix `FreeExploreBundleLaunchView.swift` fails at line 67.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(silent spinner 0, status capsule 29 baselined debt, 77 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0** (span hash in `test_club_leaderboard_member_navigation` updated with a one-line reason).

### Not done (next run)
| Item | Why not now |
|---|---|
| — | Next scan candidate: inline row spinners `ProgressView().controlSize(.small)` without words inside buttons that also change their title (one busy-button pattern). |

## Continue run 12 (2026-11-27, after merging combined-r7 bb76e327c)

Merge: five conflicts where combined-r7 (mp-states) wrote `ProgressView { Text("cy.state.loading") }.frame(maxWidth:)`
and this branch `CYLoadingState(…)` at the same lines (`BundleReviewListView`, `ChannelRedeemSheet`,
`ClubEventCalendarView`, `FreeExploreBundleLaunchView`, `ClubGapManageExtensions`) → kept `CYLoadingState` (same words,
one component). Stale allowed entry dropped: `ClubHomeView` silent spinner (combined-r7 gave it words).
No coordinator finding for this lane in the 20:55 sweep.

Run 11 lead (busy spinners): the run-11 checker only caught `ProgressView()` with `.frame(maxWidth: .infinity)` on
the **next** line; 36 player sites write both on **one** line — a wordless spinner stretched as the page / section
loader or the form "working" row (P10 "never a spinner alone"). All → `CYLoadingState()` (system `ProgressView` + 加载中… /
Loading…); identifiers that followed directly became `messageIdentifier:`; extra frames kept (`maxHeight: .infinity`,
`minHeight: 120`). Content, order, conditions and identifiers unchanged (look only).

| MP page / area | Native views (file) | Change |
|---|---|---|
| 广场 report / report progress / post video | `SquareReportView` (`squareReport.loading`), `SquareReportProgressView`, `SquarePostVideoViews` | → `CYLoadingState` |
| 我的 profile edit, wallet income, coupons, member report progress | `ProfileEditView` (`profile.edit.busy`), `WalletIncomeAnalysisView`, `CouponManagementView`, `MemberReportProgressDetailView` | same |
| 俱乐部 payout receiver (4), FE settlement | `ClubPayoutReceiverView`, `ClubFEReferenceSettlementHost` | same (`payoutReceiver.loading` stays on the Section) |
| channel role / moderation (2) / onboarding / audit / webhook / friend invite + source / notification log (2) + nudge | `NativeChannelRoleEntry`, `NativeChannelModerationEntry`, `NativeChannelOnboardingView`, `NativeChannelAuditEntry`, `NativeChannelManagementWebhookEntry`, `NativeFriendTeamInviteEntry`, `NativeFriendChannelInviteEntry`, `NativeFriendChannelSourceEntry`, `NativeNotificationDeliveryLogView`, `NativeNotificationPermissionNudgeView` | same |
| 发布 publishing management / modes (2), story image / audio upload | `PublishingManagementViews`, `PublishingModesViews`, `ProjectStoryImageAuthorView` (`projectStoryImage.busy`), `ProjectStoryAudioAuthorView` (`projectStoryAudio.uploading`) | same |
| play help ladder receipt, game hint sheet, sensor kit authorizing, city game panel, topic story participation, bundle pay result, workshop paid text | `PlayHelpLadderPanel`, `NativeR2/Games/NativeGameHintSheet`, `NativeR2/Games/NativeGameSensorKit`, `CityGamePanel`, `TopicStoryParticipationHost`, `BundlePayResultView`, `WorkshopPaidInstalledTextView` (VoiceOver label kept) | same |

Checker kind **silent spinner** widened: also `ProgressView().frame(maxWidth: .infinity…` on one line. Baseline 0.
Self-test: the pre-fix tree fails in all 30 files above.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(silent spinner 0, status capsule 29 baselined debt, 76 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0** (look-only hash pins in `test_activity_publishing_wizard` / `test_workshop_protected_text_lifecycle` updated with one-line reasons; neither is pinned in `tools/current_ci_manifest.json`).

### Not done (next run)
| Item | Why not now |
|---|---|
| Inline busy indicators inside buttons / rows (`if busy { ProgressView() }` next to a title, ~40 sites) | Different pattern (a small spinner beside the action's own title is the system idiom); next run decides one busy-button pattern per site. |

## Continue run 13 (2026-11-27, after merging combined-r7 into 20b1cb37f)

Merge clean (57 files from mp-nav / mp-roam / mp-states / mp-publish). No sweep row for this lane in the 21:20 sweep
(no ds-consistency sheet in `docs/sweeps/latest`).

Run 12 Not done row (busy indicators in buttons): ~40 `ProgressView()` sites beside a title. Most already keep their
words (`HStack { ProgressView(); Text(busy words) }`, the system idiom). The inconsistent group: **10 button labels that
swap their title for a bare spinner** while the action runs, so the button shrinks and the words vanish (P10). New shared
`CYBusyLabel(busy:) { title }` in `App/DesignSystem/CYStates.swift` (small system `ProgressView` before the kept title).
Content, order, conditions, `.disabled`, identifiers and VoiceOver labels unchanged.

| MP page / area | Native view (file:line) | MP sections | Change |
|---|---|---|---|
| 发布 editor kit card primary | `App/EditorKitCards.swift:280` | unchanged | `if primaryBusy { ProgressView() } else { primaryTitle }` → `CYBusyLabel` |
| 漫游 nearby / history 加载更多 | `App/MPGap/PlayRoam/NearbyAndHistoryGapViews.swift:178` | unchanged | same |
| 俱乐部 customer tag/remark 保存 | `App/ClubCustomerInlineEditor.swift:50` | unchanged | same |
| 我的 privacy · media 更早 | `App/SettingsPrivacyLocationView.swift:231` | unchanged | same |
| play team help levels + trade preview | `App/PlayTeamBackpackView.swift:223, 343` | unchanged | same |
| journey seat transfer 确认 | `App/JourneySeatTransferSheet.swift:74` | unchanged | same |
| city orientation 到达打卡 | `App/NativeR2/CityOrientation/CityOrientationPunchSheet.swift:369` | unchanged | same |
| native game submit bar | `App/NativeR2/Games/NativeGameShell.swift:227` | unchanged | same (G-006 comment updated) |
| theme backpack zero-HP sync | `App/PlayThemeBackpackView.swift:494` | unchanged | same |

Kept (system idiom, checker exempts): toolbar confirmation item that becomes a spinner (`TopicDetailView`,
`TopicSelfSupplySheet`, `ObjectCardCategoryAndRenameSheets`); `LabeledContent` value spinner with the label kept
(`RoamMapHomeSheet` 搜索地图); a row's trailing join button replaced by a spinner (`ClubHomeView`); placeholder image
swap with its caption kept (`PlayGameStageViews`).

New checker kind **busy swap**: `ProgressView()` followed by `} else {` (or the one-line `{ ProgressView() } else {`)
with a `Button` / `label:` in the 4 lines above and no `ToolbarItem` / `LabeledContent`. Baseline 0. Self-test: the
pre-fix tree fails in exactly the 9 files / 10 sites above.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS (busy swap 0, silent spinner 0, status capsule 29 baselined debt, 76 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
| Item | Why not now |
|---|---|
| Busy-word verbs: the same state reads 正在提交… / 提交中… / 处理中 and Sending… / 正在提交… (en and zh name different verbs) across catalogs | Copy choice per screen (MP wording), shared with i18n-r3; next run maps each to its MP page before unifying. |

### Batch 2 — one ellipsis, sentence case in busy words
Player-visible busy / placeholder words used ASCII `...` next to the `…` used by 200+ strings, and one button said
lowercase "processing". → `…` and sentence case; wording unchanged.

| Area | File | Change |
|---|---|---|
| 套票 detail + order summary pay button | `App/BundleDetailView.swift:157`, `App/BundleOrderSummarySheet.swift:31` | 处理中 / processing → 处理中… / Processing… |
| external game submit / launch buttons | `App/ExternalGameImportView.swift:568`, `App/PlayNodeDetailView.swift:159` | `...` → `…` (zh + en) |
| play area join note placeholder | `App/PlayAreaPopupCloseSurfaces.swift:42` | en `...` → `…` |
| catalogs | `Resources/Localizable.xcstrings` (map layers loading, scratch reveal, audio clip recording / uploading, review placeholder), `MapPublicLayers`, `PayoutReceiver` (检查支付服务…), `ClubOpsCustomer` (加载中… / Loading…) | 10 values `...` → `…` |

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS,
`contract_ratchet --check` 52 failing, baseline 52, **new 0**.

## Allowed (kept on purpose, reasons in the baseline)
- Procedural art sized from its own frame: `CYAlbum`, `CYBadgeCraft`, `CYCityBoard`, `CYCollectible`, `CYCoverArt`,
  `CYMedalStack`, `CYSignature`, `CYStarBloom`, celebration medal glyph, chapter numeral, verdict glyph, wordmark, map pin.
- `CYShareCard`: rendered to a fixed-size export image. `CYThemeLook`: per-theme game look (story-flow, out of scope).
- Full-screen maps / game HUD: `CityRoamRootView`, `NativeFreeExploreMapView`, `RoamLiveSessionView`,
  `RoamFinishReportView`, `ProjectEditOverviewKit` 地图 page; full-screen photo viewer in `SocialPublicProfileView`.
- `NativeStoryWalkingAuthorView` guarded exit (story-flow). `SquareBrowserView` large title: 广场 is a sheet root.
- Press feedback only (no button look): `QuestifyCardButtonStyle` (the shared card press);
  `PlayHUDCircleButtonStyle` (game HUD); `QuestifyPrimaryButtonStyle` definition (merchant call site only).
- Lists / sheets / tabs: see "Continue run" above.
- Data/art colours: dice faces, fog layer, map legend manifest, server `#RRGGBB` preview, camera filters, map route,
  `QuestifyPalette` (the palette definition).

## Gates (run on this branch)
- `python3 tools/generate_project.py` — PASS
- `python3 -B tools/check_scaffold.py` — PASS (now includes `check_design_consistency.py`)
- `python3 -B tools/check_a11y_lint.py` — PASS (0 new)
- `python3 -B tools/check_design_consistency.py` — PASS (0 debt, 54 allowed)
- `python3 -B tools/check_typography_lint.py` — PASS
- `python3 -B tools/contract_ratchet.py --check` — batch 1 (26bb8c423), batch 2 (32de0d542) and the merged tree after combined-r7 32e6d8ebd (batches 3–4 included): 52 failing, baseline 52, **new 0**
- Continue run (c14786a0f, merged combined-r7 007558f9f): `generate_project` PASS, `check_scaffold` PASS,
  `check_a11y_lint` PASS (0 new), `check_typography_lint` PASS, `check_design_consistency` PASS (0 debt, 64 allowed,
  list style / custom sheet / custom tabs 0), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.
  Self-test: the pre-fix `PlayKitQuestoViews` (scrim + `.isModal`), `CollectionAlbumViews` and `MPParityKit` (chip tab
  rows) and `CityTerritoryNoticeCard` (page button style) each fail the checker at the replaced lines.
- Continue run 2 (00867f18f, merged combined-r7): `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint`
  PASS (0 new), `check_design_consistency` PASS (0 debt, 63 allowed; duplicate type 0, undeclared state 0, font design
  0), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.
- Continue run 3 (e0bd7724b, merged combined-r7): `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint`
  PASS (0 new), `check_design_consistency` PASS (0 debt, 63 allowed), `contract_ratchet --check` 52 failing, baseline
  52, **new 0**.
- Continue run 3, batch 2 (d8d04c09e): `generate_project` PASS, `check_scaffold` PASS (includes design consistency:
  0 debt, 64 allowed, custom search 0), `check_a11y_lint` PASS (0 new), `contract_ratchet --check` 52 failing,
  baseline 52, **new 0**.
- Continue run 4 (8576daddc, merged combined-r7 f043090ce): `generate_project` PASS, `check_scaffold` PASS (includes design
  consistency: 0 debt, 64 allowed, text on art 0), `check_a11y_lint` PASS (0 new), `contract_ratchet --check` 52 failing,
  baseline 52, **new 0**.
