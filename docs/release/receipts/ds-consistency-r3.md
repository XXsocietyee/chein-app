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

## Continue run 14 (2026-11-27, after merging combined-r7 into 6cddf2d39)

Merge clean (63 files, pushed as 88481c43e). No new coordinator row for this lane after 21:20.

Run 13 Not done row (busy words). The verbs follow each screen's MP wording, so they stay; what was inconsistent is
the **form**: 21 player progress words had no `…` in one or both languages (正在加载 / Loading next to 正在加载… /
Loading… on 200+ strings), and one zh value named a different action than its en (处理中 vs Submitting…). Each key
was checked at its call site as a progress word (`ProgressView { Text }`, `CYResultButton(loading:)`, busy label);
status chips / filters / server states (`SUBMITTED`, `g6.ai.state.PROCESSING`, `score.*`, `report.filter.active`,
`cyTask.badge.submitting`, offline-write chip, webhook delivery status) keep no ellipsis on purpose.

| Area | Native view (call site) | Key(s) | Change |
|---|---|---|---|
| 套票 redeem result | `App/BundleRedeemResultView.swift:90` | `bundle.redeem.processing` | 处理中 / Processing → + `…` |
| 发布 editor kit results | `App/EditorKitResults.swift:147` | `editorKit.state.loading` | + `…` |
| 首页 glass carousel | `App/DesignSystem/CYGlassCarousel.swift:450` | `carousel.loading` | + `…` |
| 我的 项目 | `App/ProfileSelfProjectsSection.swift:60` | `creatorContent.loading` | + `…` |
| journey settle rating | `App/JourneyReportViews.swift:1243` | `mp.settle.rate.submitting` | + `…` |
| enrollment / motion reminder | `App/NativeEnrollmentView.swift:74` | `nativePlatform.working` | + `…` |
| object cards / progress privacy | `App/ObjectCardViews.swift:314` | `objects.loading` | + `…` |
| official action | `App/OfficialActionViews.swift:77` | `officialAction.working` | + `…` |
| crop | `Core/MiniCropSession.swift:151` | `pages.crop.busy` | + `…` |
| play help ladder / game hint | `App/PlayHelpLadderPanel.swift:159` | `playHelp.sending` | + `…` |
| play audio clip / POI photo | `App/PlayAudioClipView.swift:208`, `App/ChallengePOIPhotoCapture.swift:43` | `playx.audioClip.phase.uploading`, `playx.poi.photoUploading` | zh + `…` (en had it) |
| play review | `App/PlayExperienceView.swift:1528` | `playx.phase.submitting` | + `…` |
| complaint submit | `App/ProfileComplaintPreparationView.swift:312` | `profile.complaint.submit.sending` | zh 处理中 → 提交中… (matches en Submitting… and the 提交 button) |
| qmod import | `App/QmodAuthorImportView.swift:238` | `qmodImport.inspecting` | + `…` |
| wallet / bank withdrawal | `App/WalletCommerceViews.swift:413` | `wallet.loading` | + `…` |
| club group code | `App/ClubGovernanceCommandForm.swift:295` | `clubR8b.groupCode.generating` | + `…` |
| 漫游 map home | `App/NativeR2/MapHome/RoamMapHomeRoutes.swift:21` | `nativeR2.mapHome.loading` | + `…` |
| publish preview | `App/ProjectEditDetailForms.swift:688` | `publish.preview.sending` | + `…` |
| creator appeal attach | `App/PlayCreatorTailViews.swift:294` | `audit.attach.uploading` | + `…` |
| privacy page | `Core/UsageConsentPolicy.swift:178` | `privacy.page.state.loading` | + `…` |

String-manifest pins updated to the new values (stale copy pins, one-line reason: the progress word now ends in `…`):
14 JSON manifests / fragments (`Resources/NativePlatformLocalizations.fragment.json`, `ObjectCardLocalizations.fragment.json`,
`docs/*-localizations.json`, `docs/port/strings/*`, `docs/release/ui-strings-*.json`).

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(status capsule 29 baselined — all in internal release-checklist `*SectionView` screens, not player surfaces),
`contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
| Item | Why not now |
|---|---|
| zh/en verb mismatches left (`playHelp.sending` 提交中… / Sending…, `audit.attach.uploading` key vs 提交中…) | Needs the MP page wording per screen; next run checks each against `mp-source`. |

## Continue run 15 (2026-11-27, after merging combined-r7 into f0affde33)

Merge clean. No new coordinator row for this lane after 21:20 (22:20 sweep rows are mp-activity / mp-roam).

Run 14 Not done row (zh/en verb mismatches) — checked each against `mp-source`:

| MP page | Native view (call site) | Key | Before | After |
|---|---|---|---|---|
| `pages/play/play-help.wxml` + `utils/play-help-panel.js:24` (busyLevel = 「正在解锁」的那一层) | `App/PlayHelpLadderPanel.swift:159`, `App/NativeR2/Games/NativeGameHintSheet.swift:123` (spinner a11y label) | `playHelp.sending` | 提交中… / Sending… (two different verbs) | 正在解锁… / Unlocking… |
| MP image upload (`pages/play/index.js:8487`, `poi-challenge/index.js:90`, `subpackageRoam/nearby/index.js:1012`: 正在上传) | `App/PlayCreatorTailViews.swift:294` (appeal attachments) | `audit.attach.uploading` | 提交中… / Submitting… (key says uploading) | 正在上传… / Uploading… (same as the 5 other 正在上传… / Uploading… keys) |

No string-manifest JSON pins these two keys (grep clean).

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS (status capsule 29 baselined, 76 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

Sweep 22:11 checked (`mp-club/sheet-en.jpg`, `mp-mine/sheet-zh-Hans.jpg`): titles, toolbar buttons and segmented pickers
match the one pattern; no new design-system kind to add this run.

### For other lanes
| Lane | Item |
|---|---|
| mp-mine | `e4-wallet-balance` (余额流水): row dates show raw `2026-11-06 18:20:00` (seconds) while 订单查询 shows `2026-11-14 10:00` and 票夹 `2030年4月20日`. MP `subpackageA/components/scene-asset-income-detail/index.js:15` shows 今天 / 昨天 / M月D日. `LocaleDisplay.civil` passes zh through unchanged on purpose (pinned by `LocaleDisplayTests.swift:47`), so fix at the ledger row, not in the formatter. |

### Not done (next run)
None from this run.

## Continue run 16 (2026-11-27, after merging combined-r7 into 0e008c085)

Merge clean (54 files). Sweep in `docs/sweeps/latest` is still build 8fa84e4d3 (22:11, already checked in run 14); no
coordinator row for this lane since 16:37 (answered in run 4). Run 15 Not done: none; status capsule 29 is internal
`*SectionView` / ledger screens (out of player scope).

Scan: one separator and one text case (OWNER RULE 2 "one list/card pattern", "fonts, letter spacing … consistent").
Shadows (9 sites: map pins, map controls, reward motion, drag lift, persistent map sheet) and `.roundedBorder` fields
(15, all in card `VStack`s, none inside a `List` row) are already one pattern — no change.

| MP page / area | Native view (file:line) | MP sections | Change |
|---|---|---|---|
| 章节故事 divider block | `App/ChapterStoryView.swift:386` | unchanged | non-story-flow branch drew a 1 pt `Rectangle` in `borderSubtle`; the story-flow branch already used `Divider()` → one `case .divider: Divider()` |
| 发布 editor kit insert seam (+ / × circle on the line) | `App/EditorKitResults.swift:185` | unchanged | 0.5 pt `Rectangle` → `Divider()` behind the circle |
| 漫游 monthly recap share face (month eyebrow) | `App/RoamPassportToolsViews.swift:891` | unchanged | `.textCase(.uppercase)` removed: the only all-caps text on a player surface ("NOVEMBER 2026"); sentence case like every eyebrow (zh unaffected) |

New checker kind **hand divider**: `Rectangle()` (optionally `.fill(colour)`, not `.clear`) with `.frame(height: 0.5 / 1)`
outside App/DesignSystem and App/Theme. Vertical timeline connectors (`width: 2`) and clear spacers do not match.
Baseline 0. Self-test: the pre-fix tree fails in exactly the two files above.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(hand divider 0, status capsule 29 baselined debt, 76 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
None from this run.

## Continue run 17 (2026-11-27, after merging combined-r7 into 028eee08a)

Merge clean (46 files). Run 16 Not done: none. New sweep `docs/sweeps/latest` = build b3b03703a (23:07); sheets read:
`mp-journey/sheet-en.jpg`, `mp-home/sheet-zh-Hans.jpg`, `mp-nav/sheet-en.jpg`, `mp-activity/sheet-en.jpg`.

Scan: one text case (OWNER RULE 2 "fonts, letter spacing … consistent"). Run 16 made eyebrows sentence case outside the
design system, but `mp-nav/sheet-en.jpg` (`onboarding-1`) still shows an all-caps **WELCOME** above "The city is
waiting": the shared components in App/DesignSystem forced `.textCase(.uppercase)`. Every en string is already in
sentence case ("New badge", "This walk", …), so the capitals were styling only; zh is unaffected.

| MP page / area | Native view (file:line) | MP sections | Change |
|---|---|---|---|
| 引导页 eyebrow (`onboarding-1`) | `App/DesignSystem/CYOnboarding.swift:326` | unchanged | WELCOME → Welcome |
| 新徽章 / 这一趟 celebration titles | `App/DesignSystem/CYCelebrationViews.swift:552`, `:616` | unchanged | NEW BADGE / THIS WALK → sentence case |
| 已获得 n 枚 medal deck caption | `App/DesignSystem/CYMedalStack.swift:170` | unchanged | sentence case |
| 章节 n / 共 m, 序章, 第 n 章完成 | `App/DesignSystem/CYChapterFlip.swift:33`, `:115` | unchanged | sentence case |
| 收集册 NEW pulse badge | `App/DesignSystem/CYAlbum.swift:251` | unchanged | sentence case |
| 票夹 pass ribbon (已使用 / 已过期 …) | `App/DesignSystem/CYTicketPass.swift:126` | unchanged | sentence case |
| — | `App/DesignSystem/CYExploreKit.swift` `cyEyebrow(isChinese:)` | — | deleted: 0 call sites, and it documented the all-caps eyebrow as the pattern |

Not changed on purpose: italic bold numerals on the roam finish record, play-kit index numbers and the GO wordmark —
the MP marks them `ds-ok` owner P-34 (NRC 粗斜体, `pages/roam/index.wxss:657`, playkit wxss), an owner-approved style.
`.textCase(nil)` on `Section` headers (36 sites) keeps long header sentences as written; no change.

New checker kind **all caps**: `.textCase(.uppercase)` anywhere in player `App/` (design system included). Baseline 0.
Self-test: the pre-fix tree fails in exactly the seven files above.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(all caps 0, status capsule 29 baselined, 76 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
None from this run.

## Continue run 18 (2026-11-28, after merging combined-r7 into 230b6f219)

Merge clean (45 files). Run 17 Not done: none. No new coordinator row for this lane (latest sweep still build
793c3190b). Sheets read: `mp-mine/sheet-en.jpg`, `mp-club/sheet-zh-Hans.jpg`.

Scan: one grid pattern. `mp-club/sheet-zh-Hans.jpg` (`zh-Hans-d4-badges`, 我的徽章) shows a **stray `>` chevron beside
every badge tile** (示例城市勋章 › 示例成就 ›): each grid cell was a `NavigationLink` inside a `List` row, and List draws
its disclosure indicator next to every link in the row. The same wall in a `ScrollView` (stamps, 集邮册) has none.

| MP page | Native view (file:line) | MP sections | Change |
|---|---|---|---|
| `subpackageP3/badge-wall` (已点亮 → 未解锁 grid) | `App/ObjectBadgeViews.swift` `link(...)` / `destination(...)` | unchanged (header, partial, empty + 去探索, 已点亮, 未解锁; identifiers `profile.badge.*` kept, still buttons for UI tests) | cell `NavigationLink` → plain `Button` setting `openSlot`; one `.navigationDestination(item: $openSlot)` on the List opens the same `ObjectBadgeDetailView` (3D entry + hero zoom kept). No chevrons in the grid. |
| `subpackageP3/object-cards` (VoiceOver / Reduce Motion grid) | `App/ObjectCardViews.swift` collection grid | unchanged (pile, grid, empty title; `objects.card.<id>` kept) | same fix, reusing the existing `pileSelection` destination (`fromGrid: true` keeps the hero zoom). |

New checker kind **grid link**: a `NavigationLink` in a `LazyVGrid` / `LazyHGrid` / `Grid` cell (directly, or through a
same-file helper the cell calls) whose nearest container is a `List`. Grids in a `ScrollView` are fine. Baseline 0.
Self-test: the pre-fix tree fails in exactly the two files above.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(grid link 0, status capsule 29 baselined, 76 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**
(`test_object_badge_wall_layout` passes unchanged). Simulator check of d4-badges still needed (next sweep).

### Not done (next run)
None from this run.

## Continue run 19 (2026-11-28, after merging combined-r7 into 0ca14c667)

Merge clean (73 files). Run 18 Not done: none. No new coordinator row for this lane. New sweep `docs/sweeps/latest` =
build 283dd3b52 (00:10Z, light mode); sheets read: `mp-roam/sheet-en.jpg`, `mp-activity/sheet-zh-Hans.jpg`.

Scan: one appearance. `mp-roam/sheet-en.jpg` (`en-d2-roam`) shows the 漫游 map home in light mode with a **black panel**
under the "Nearby activities 2" peek line: `cyMapPanelColor` (the fill of every map scaffold panel) was `Color.black`,
so every map page drew a dark slab under a light map, while the 城市 nearby drawer and all system sheets follow the
system appearance. Contents already use semantic colours (the peek line even carried a comment working around the
black panel), so only the surface changes.

| MP page | Native view (file:line) | MP sections | Change |
|---|---|---|---|
| `pages/roam/index` map home panel (`en-d2-roam`) + nearby teams map, play map, play session (same scaffold) | `App/DesignSystem/CYMapChrome.swift:391` `cyMapPanelColor` (used by `CYMapScaffold`, `CYRoamKit` sheet, `RoamBrowserView:604`) | unchanged | fixed `Color.black` → `CYColor.bgElevated` (light: white elevated surface, dark: system elevated grey). |
| — (panel grabbers) | `CYMapChrome.swift:499`, `CYRoamKit.swift:365` | — | `Color.white.opacity(0.5 / 0.3)` (invisible on a light panel) → system `tertiaryLabel`, the sheet-grabber colour. |
| — | `App/RoamBrowserView.swift:380` | — | stale "black panel" comment updated. |

New checker kind **fixed surface**: a shared colour token `let x = Color.black` / `.white` (design system included).
Baseline 0, nothing allowed. Self-test: the pre-fix `CYMapChrome.swift` fails at line 391. Other `Color.black` fills
(image caption backing with `.colorScheme(.dark)`, Island overlay, route thumbnail art, a `#Preview`) are local art
surfaces, not shared tokens, and stay.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(fixed surface 0, status capsule 29 baselined, 76 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.
Simulator check of d2-roam / d6-roam panel in light and dark still needed (next sweep).

### Not done (next run)
None from this run.

## Continue run 20 (2026-11-28, after merging combined-r7 f8574edab)

Merge clean (61 files). Run 19 Not done: none. Coordinator 00:50 row (mp-roam / a11y-dt: "附近活动 sheet is solid black
over the light map", `a11y-dt/sheet-zh-Hans.jpg` tile `a11y-roam-ax5`): the sweep build f8574edab predates run 19
(ff2548a23 is not in it); that black panel is `cyMapPanelColor`, already `CYColor.bgElevated` on this branch — answered,
next sweep should show it light.

Scan: the same appearance bug one level smaller. Two map chips drew a fixed `Color.black.opacity(0.5)` layer under an
`.ultraThinMaterial`, then put semantic text on it: in light mode that is black text on a dark-grey capsule.

| MP page | Native view (file:line) | MP sections | Change |
|---|---|---|---|
| `pages/roam/index` fog coverage chip (已探索 37% · 4 待确认) | `App/DesignSystem/CYFogEngine.swift:43` `CYFogCoverageBadge` | unchanged | black layer removed; `.regularMaterial` capsule (follows light / dark) |
| `pages/roam/index` "new area revealed" toast | `App/DesignSystem/CYRoamKit.swift:288` `CYRevealToast` | unchanged | black layer removed; `.regularMaterial`; white 16 % hairline → `CYColor.borderSubtle` |

New checker kind **dark backing**: `.background(Color.black.opacity(…))` on the same or the line after a material
`.background` (design system included). Baseline 0, nothing allowed. Self-test: the pre-fix tree fails in exactly the
two files above.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(dark backing 0, status capsule 29 baselined, 76 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.
Simulator check of d6-roam chips in light and dark still needed (next sweep).

### Not done (next run)
None from this run.

## Continue run 21 (2026-11-28, after merging combined-r7 907570051)

Merge clean (59 files). Run 20 Not done: none. No new coordinator row for this lane since 00:50 (answered in run 20).
Sweep `docs/sweeps/latest` = build 907570051 (01:10Z, light); sheets read: `mp-mine/sheet-en.jpg`,
`mp-journey/sheet-en.jpg`.

Scan: one money label. `mp-mine/sheet-en.jpg` shows three ways to write the same CNY amount in English:
`en-d2-me` balance **CN¥0.00**, `en-t5-order-center` **CN¥168.00**, but `en-e4-wallet-balance` (余额流水) **¥128.50** /
**+¥58.00**. The shared rule (`LocaleDisplay.money`, used by Me balance, orders, coop, topic, E1 commerce) is `¥` in
Chinese and `CN¥` in other languages; the wallet screens had their own currency table (`WalletCurrencySymbol`) that
returned a bare `¥` in every language. zh is unchanged (`¥128.50`).

| MP page | Native view (file:line) | MP sections | Change |
|---|---|---|---|
| `subpackageA/components/scene-asset-income-detail` 余额流水 hero + rows (`e4-wallet-balance`) | `App/WalletCommerceViews.swift:668` hero glyph, `App/WalletNumberLocalization.swift:48` `symbolMoney` (row delta + after-balance) | unchanged | currency glyph through the new `WalletCurrencySymbol.symbol(_:locale:)` → `CN¥128.50` / `+CN¥58.00` in en; the one-character check became `isGlyph` (a drawn symbol, not an ISO code) so `CN¥` is still drawn before the number instead of falling back to `128.50 CNY`. |
| 我的资产 / 账户收益 hero, income rows, asset rows | `App/WalletCommerceViews.swift:182`, `:292`, `:343` | unchanged | same locale-aware symbol. |
| — | `App/WalletCommerceViews.swift` `WalletCurrencySymbol` | — | `symbol(_:locale:)` (CNY → `LocaleDisplay.currencySymbol`, other codes as before) + `isGlyph(_:)`. |

New checker kind **locale money**: `WalletCurrencySymbol.symbol(…)` without `locale:`, or a `Text("¥…")` literal.
Baseline 0; allowed: DEBUG native gallery sample prices (reason in the baseline). Self-test: the pre-fix
`WalletCommerceViews.swift` fails at lines 182, 292, 343, 668.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(locale money 0, status capsule 29 baselined, 79 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.
Simulator check of `en-e4-wallet-balance` / `en-d2-me` (CN¥ everywhere in English) still needed (next sweep).

### Not done (next run)
None from this run.

## Continue run 22 (2026-11-28, after merging combined-r7 a32387e9b)

Merge clean. Run 21 Not done: none. No new coordinator row for this lane (01:50 sweep row is mp-activity's 票种价格
dash). Sweep `docs/sweeps/latest` = build a32387e9b (01:40Z, light); sheets read: `mp-activity/sheet-zh-Hans.jpg`,
`mp-roam/sheet-en.jpg`.

Scan: the run-21 money rule, one level up. Price / amount strings built with a bare `¥` (server text or
`String(format: "¥%.2f")`) were drawn as-is, so English showed `¥` next to `CN¥` elsewhere. Each now goes through
`LocaleDisplay.yuanAmounts(in:locale:)` (idempotent: zh unchanged, an already `CN¥` string unchanged).

| MP page | Native view (file:line) | MP sections | Change |
|---|---|---|---|
| `pages/play/*` 完局优惠卡 (JSETTLE-r7-1) price + VoiceOver label | `App/MPGap/PlayRoam/PlayRoamRound4Views.swift:46`, `:61` | unchanged | `Text(offer.priceText)` → locale money; `@Environment(\.locale)` added |
| promo summary buckets (`mp.promo`) | `App/JourneyLandingViews.swift:1034` `JourneyPromoView` | unchanged | bucket `amountText` (`¥12.30`) → locale money |
| 视频悬赏 accrual rows | `App/VideoBountyView.swift:308` | unchanged | `amountText` (`¥12.30`, `USD 3.00` kept) → locale money |
| 通行证 explore card + checkout rows | `App/MPPassEntries.swift:75`, `:121` | unchanged | `priceText` / pass price → locale money |
| bundle detail / order summary / native free-explore bundle / launch paid amount | `App/BundleDetailView.swift:57`, `App/BundleOrderSummarySheet.swift:34,75`, `App/NativeR2/FreeExplore/NativeFreeExploreBundleDetailView.swift:156`, `App/FreeExploreBundleLaunchView.swift:217` | unchanged | same (no-op where the source was already `E1Money`) |

Checker kind **locale money** widened: `Text(verbatim: x.priceText / amountText)` shown bare. Baselined 9 (re-baseline
reviewed; only locale money rose): club / coop settlement + `CYBusinessComponents` order totals (host/business side,
source formatter not yet audited) and `RegistrationPaySection` (already `RegistrationUIMoney.display(locale:)`).

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(locale money 9 baselined, status capsule 29 baselined, 79 allowed), `contract_ratchet --check` 52 failing, baseline 52,
**new 0**. Simulator check of an en finish-offer / pass card (CN¥) still needed (next sweep).

### For other lanes
- en-layout: `Core/MPGap/PlayRoam/PlayRoamRound4Models.swift:141` builds the points price as `"\(pts) 积分"` — Chinese
  in English; use the `mp.pass.points.amount` key.

### Not done (next run)
- Audit the 9 baselined locale-money sites' source formatters (club settlement, coop settlement, `CYBusinessComponents`
  order totals); wrap or move to allowed with a reason.

## Continue run 23 (2026-11-28, after merging combined-r7 41374363f)

Merge clean (56 files). No new coordinator row for this lane (02:05 map-panel note and 02:20 sweep are other lanes;
this lane never edited `CYMapChrome.swift` / `RoamBrowserView.swift`). Run 22 Not done row worked:

Audit of the 9 baselined locale-money sites. Each source is server text (`¥…` from the club / coop settlement reads,
`FEReferenceSettlementItem.amountText`, the caller-supplied registration summary strings), none passes through the
shared money rule, so English showed a bare `¥` beside `CN¥` elsewhere. All now go through
`LocaleDisplay.yuanAmounts(in:locale:)` (idempotent; zh unchanged; non-¥ text such as `USD 3.00` or `—` unchanged).

| MP page | Native view (file:line) | MP sections | Change |
|---|---|---|---|
| `pages/club/*` 俱乐部分润 结算详情 (hero amount + 原始 / 调整 / 实得) | `App/ClubSettlementDetail.swift:304`, `:313-315` | unchanged | locale money on amount, original, adjustment, net; `@Environment(\.locale)` |
| `pages/coop/*` 合作结算详情 (club perspective) | `App/CoopSettlementDetailView.swift:286` hero, `:310` `line(_:_:)` rows | unchanged | hero + every breakdown line through locale money |
| `pages/activity/*` 报名确认 summary card (原价 / 优惠 / 合计) | `App/DesignSystem/CYBusinessComponents.swift:972`, `:984`, `:994` `CYRegistrationSummaryCard` | unchanged | original, discount, total through locale money |
| `pages/club/detail` 设置 · 俱乐部财务 | `App/MPGap/Club/ClubGapManageExtensions.swift:282` | unchanged | settled amount through locale money |
| 自由探索结算（参考） rows | `App/MPGap/Club/ClubGapReferenceSettlementView.swift:52` | unchanged | row amount through locale money |
| 报名支付 待支付金额 | `App/RegistrationPaySection.swift:157`, `:163` | unchanged | no change: already `RegistrationUIMoney.display(_:locale:currencyCode:)`; moved to **allowed** with that reason |

Checker: locale money **0** baselined (was 9), ratcheted with `--update` (baseline now 29 hits, all status capsule).

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(locale money 0, status capsule 29 baselined, 81 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.
Simulator check of an en club settlement detail / registration summary (CN¥) still needed (next sweep).

### Not done (next run)
None from this run.

## Continue run 24 (2026-11-28, after merging combined-r7 ad55acd94)

Merge clean (58 files). Run 23 Not done: none. No new coordinator row for this lane (latest sweep build 41374363f,
02:20 rows are other lanes). Status capsule 29 stays baselined (internal release-checklist `*SectionView` screens).

Scan: one sheet-dismiss placement (OWNER RULE 2 "toolbar items in the standard places"). The `done leading` kind only
matched `Button("….done")`; three Done-only sheets put their single Done in the leading (Cancel) slot through a label
closure or a helper, while 30+ sibling sheets put Done trailing (`.confirmationAction`). MP content unchanged (the MP
popups close with the same 完成 action).

| MP page | Native view (file:line) | MP sections | Change |
|---|---|---|---|
| channel progress boards (in-game channel 进度) | `App/NativeChannelProgressEntry.swift:177` | unchanged | Done `.topBarLeading` → `.confirmationAction` |
| club channel webhook management | `App/NativeWebhookManagementEntry.swift:246` | unchanged | Done `.cancellationAction` → `.confirmationAction` |
| `pages/topic/*` 地点待办 sheet | `App/TopicLocationTodosSection.swift:58` | unchanged | Done `.cancellationAction` → `.confirmationAction` (still disabled while a slot is busy) |

Checker `done leading` widened: also a Done label through a helper call (`Button(loc("x.done"))`), a label closure
(`Button { … } label: { Text("done", …) }`) and `W8Text.t("完成", "Done")`. Self-test: the pre-fix files fail at the
three lines above; baseline stays 0.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(done leading 0, status capsule 29 baselined), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
None from this run.

## Continue run 25 (2026-11-28, combined-r7 ad55acd94 already merged)

Merge: already up to date. Run 24 Not done: none. No new coordinator row for this lane (latest sweep still build
ad55acd94, 03:15 rows are mp-club / mp-home).

Scan: one refresh pattern (OWNER RULE 2 "consistent logic and patterns"). 22 player pages pair the toolbar
`arrow.clockwise` refresh with `.refreshable` (pull-to-refresh, the MP `onPullDownRefresh`); six had only the button.
Two of them are MP pages with `"enablePullDownRefresh": true` and `onPullDownRefresh` (re-reads overview + rank / the
board), so they could not be pulled down like the MP or their siblings. MP content unchanged.

| MP page | Native view (file:line) | MP sections | Change |
|---|---|---|---|
| `subpackageP3/pages/growthcenter/index` (成长中心; `onPullDownRefresh` index.js:215) | `App/GrowthCenterView.swift:96` | unchanged (score card → 足迹 → 我的徽章) | `.refreshable { await load() }` on the List (same read as the toolbar refresh and the lifecycle) |
| `subpackageP3/pages/growthcenter/leaderboard` (排行榜; `enablePullDownRefresh`) | `App/GrowthLeaderboardView.swift:107` | unchanged (周榜/总榜 → podium → 积分榜/成长榜 → rows → 我) | `.refreshable { await load() }` on the List |

New checker kind **refresh no pull**: a toolbar `"arrow.clockwise"` button (within 8 lines of `.toolbar` /
`ToolbarItem`) in a file with a `List` / `Form` / `ScrollView` and no `.refreshable`. Baseline 0. Allowed with reasons
(MP page has no pull-down refresh, or the button carries a guard a pull cannot): `CityPlayerView` (read-failure retry
that also cancels the place selection), `GroupPollViews` (refresh drops the unsent option and runs the poll command),
`GroupPollOriginalResultView` (in-chat poll result), `ParticipantManagementDetailView` (disabled while a delete awaits
confirmation). Self-test: the pre-fix growth files fail at `GrowthCenterView.swift:100` and
`GrowthLeaderboardView.swift:111`.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(refresh no pull 0, status capsule 29 baselined, 85 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
None from this run. Simulator check: pull down on growth center / leaderboard (no design fixture yet; next sweep).

## Continue run 26 (2026-11-28, after merging combined-r7 733bfb368)

Merge clean. Run 25 Not done: none. No new coordinator row for this lane (03:15 / 04:00 sweeps: no new findings).

Scan: one list rhythm (OWNER RULE 2 "one list/card pattern"). `CYScreenStyle` gives every player list 24 pt between
sections (`CYSpacing.xxl`); three player pages re-set the spacing by hand (20 / 20 / 16), so their sections sat closer
than every sibling list. MP content unchanged.

| MP page | Native view (file:line) | MP sections | Change |
|---|---|---|---|
| `subpackageActivity` 活动详情 | `App/ActivityDetailView.swift:518` | unchanged | dropped `.listSectionSpacing(CYSpacing.xl)` (inherits 24 pt) |
| `pages/signup/index` 票夹 | `App/TicketWalletView.swift:123` | unchanged | dropped `.listSectionSpacing(20)` (raw literal) |
| club co-op 收益 / 结算 | `App/CoopFinanceSummarySection.swift:46` (`CoopOperationListPresentation`) | unchanged | dropped `.listSectionSpacing(Theme.Space.s4)` |

New checker kind **section spacing**: a `.listSectionSpacing(…)` other than `.compact` / `.default` outside
App/DesignSystem and App/Theme. Baseline 0. Self-test: the pre-fix files fail at the three lines above. Contract pin
`test_activity_design_structure` updated (asserts no per-page spacing, reason in the test).

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(section spacing 0, status capsule 29 baselined), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
None from this run.

## Continue run 27 (2026-11-28, after merging combined-r7)

Merge: one conflict in `tools/check_design_consistency.py` (this lane's `section spacing` kind next to the
coordinator's new `untyped haptic` kind, 04:20); kept both. Run 26 Not done: none. No new coordinator row for this
lane (latest sweep build 733bfb368 has no ds-consistency fixtures; 04:00 sweep: no new findings).

Scan: one haptic pattern (coordinator 04:20 compile rule; OWNER RULE 2 "consistent logic and patterns"). The new
`untyped haptic` kind landed with 103 baselined hits. Shared typed transitions added to the motion tokens
(`App/DesignSystem/CYMotion.swift` `CYHapticTransition.turnedOn / isOn / turnedOff`, Bool) and 55 single-line Bool
closures across 38 files now pass a named function (`where:` for `cyHaptic`, `condition:` for `sensoryFeedback`);
`{ old, new in !old && new }` → `turnedOn`, `{ _, new in new }` → `isOn`, `{ _, now in !now }` → `turnedOff`. Same
transitions, same haptics; no view content touched, MP sections unchanged. `CYInPlaceResult.swift` (shared result
button, toast, streak row, moment seal) gets typed `private static func` conditions for its non-Bool triggers
(`CYResultPhase`, `CYResultToastState.Phase`, `Int`).

| Area | Files | Change |
|---|---|---|
| App/DesignSystem (result, ticket pass, signature, pass card, onboarding, collectible) | 7 files | closures → `CYHapticTransition` / `Self.becameDone` etc. |
| App/NativeR2 games, motion, city orientation, free explore | 17 files | closures → `CYHapticTransition` |
| other player views (roam subpages, login, editor results, bundles, club, publishing …) | 14 files | closures → `CYHapticTransition` |

Checker: untyped haptic **48** baselined (was 103), ratcheted with `--update`. The 48 left are multi-line or
non-Bool conditions (`new > old`, enum compares) that need a per-view typed func; next run.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(untyped haptic 48, status capsule 29 baselined), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.
No compiler in the cloud: every replaced trigger is a Bool expression (checked line by line); next integration build
confirms.

Batch 2 (same run): `CYHapticTransition` gains generic `isSet` (any change ending non-nil), `becameSet` (nil → value)
and `increased` (Int up). 11 more sites: `EditorKitLists:203`, `NativeStampCaptureView:58`, `CameraKits:264`,
`CityOrientationPunchSheet:110`, `NativeGameShell:446`, `ClubGovernanceViews:799`, `ClubLeadPrimaryActionView:115`
(isSet); `BankWithdrawalView:79`, `QuestifyApp:500` (becameSet); `ExternalGameImportView:121` (increased);
`CouponCodeView:64` (inline `where:` closure → turnedOn). Per-view typed statics: `ClubContextualViews:139-140`
(`ClubOpsTimeState` acknowledged / rejected), `CYScan:451` (`CYScanMarkKind.success`). Untyped haptic **34** baselined.
Gates as above, `contract_ratchet` new 0.

### Not done (next run)
- untyped haptic: the remaining 34 read view state inside the condition (`presentation`, `visible`, `kind`,
  `isEnabled`, `nodeID`) or span lines → move each into a small typed `ViewModifier` (pattern
  `RegistrationSelectionHaptics`), largest files first (`ChanceKits`, `NativeGameSensorKit`, `RoamFogMapView`).

## Continue run 28 (2026-11-28, after merging combined-r7, 38 commits)

Run 27 Not done row: the last 34 untyped haptic conditions → **0** (gate kind `untyped haptic` now baselines 0 hits).

| Pattern | Sites | Change |
|---|---|---|
| `{ _, new in new == .x }` / `old != .x && new == .x` / `old < 1 && new >= 1` | `ChallengePOIView:81`, `IMConversationReadAllView:101`, `PlayInPlayTools:99`, `TemplateQuestionMediaPickers:221`, `BundleTransferClaimView:43`, `NativeGameShell:447`, `ChoiceKits:148`, `ChanceKits:336-337`, `ClubManagementView:561` | Bool trigger (`state == .x`) + `CYHapticTransition.turnedOn` |
| condition mixes a constant (`let presentation`, `let kind`, `nodeID`, `isEnabled`) | `BundlePayResultView:117-118`, `NativeGameSensorKit:140-141`, `CityOrientationPunchSheet:109`, `CYPurchaseMotion:190`, `EditorKitResults:71` | constant folded into the Bool trigger + `turnedOn` |
| `if case .x = new` (associated-value enums) | `BundleReviewComposeView`, `BundleTransferSendView`, `BundleTransferClaimView`, `ChapterReplacementInvitationView`, `IMConversationRowActionsView`, `IMSafetyReviewView` | per-view typed `static func` in a `private extension` |
| `!next.isEmpty && old != next`, `old != nil && new != nil && old != new`, `new != nil && old != new` | `ChanceKits:61/153/231`, `CYGlassCarousel:129`, `PublishingAIDraftSheet:145` | new shared `CYHapticTransition.nonEmpty` / `bothSet`, existing `isSet` |
| condition reads view state, or returns the feedback | `RoamFogMapView:139-140`, `CYSegmentedContent` (`CYLoadingChoreography:173`), `NativeGameTimedKit:240`, `PlayKitTimedChallengeView:134`, `TeamInvitePreview` (`TeamComponents:379`) | named instance func in a `private extension` (`revealAdvanced`, `playsSelectionHaptic`, `measuredFeedback`, `copyFeedback`) |

Semantics: every Bool trigger fires on the same transitions as the closure it replaces (the folded terms are `let`
properties or stable for the view's life); `onChange` only fires on a change, so `old != new` terms were redundant.
No compiler in the cloud: the next integration build confirms.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(untyped haptic 0, status capsule 29 baselined), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
- status capsule (29 baselined): move per-page soft-tint capsules to `CYStatusChip`, largest files first.

## Continue run 29 (2026-11-28, after merging combined-r7)

Run 28 Not done row (status capsule, 29 baselined in 18 files). Checked every file before converting: **none is a player
surface.** Each is an internal release-checklist status page (`AssetPointsAndOrderCancellationSectionView`,
`CloudCIShardStatusSectionView`, `FinalReleaseSignoff…`, `ReleaseArchiveChecklistSectionView`, `Wave3HandoffStatus…`, …)
whose `struct …: View` has **no call site in `App/`** (one, `FinalThreeDocumentAndSevenDayGoalCompletionView`, is mounted
only by `DesignFixtures/CurFixtures8.swift`). Their copy is internal Chinese QA wording (`MASTER_OK`, `I04_OK`), so a
restyle changes nothing a player sees; the brief also scopes `*SectionView` internal screens out of the native lanes.

| Change | Where |
|---|---|
| 29 `status capsule` hits moved from `baseline` (debt) to `allowed` with reason `unmounted internal screen: …` | `tools/design_consistency_baseline.json` (18 files) |
| New guard: an allowed entry whose reason starts `unmounted internal screen` **fails** as soon as the file's `struct …: View` (any access level) is called from an `App/` file outside `DesignFixtures` / `*Fixture*` — mounting it for players means converting its capsules to `CYStatusChip` first | `tools/check_design_consistency.py` (`mounted_unmounted`, docstring) |

Self-test: appending `CloudCIShardStatusSectionView()` to `App/GrowthCenterView.swift` fails the gate with
"CloudCIShardStatusSectionView is now called from App/GrowthCenterView.swift"; reverted. All 18 files resolve a view name.

Result: **0 baselined debt in every kind** (status capsule 0), 114 allowed hits, each with a reason.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(0 debt), `contract_ratchet --check` 52 failing, baseline 52, **new 0** (both batches).

### Batch 2 — one section-header pattern (sweep build a4142df0d, `mp-home/en-rep3-activity-detail`)
The activity detail showed two header looks in one list: "About this activity" as the system section header
(footnote, secondary) and "Tickets" as a bold `.sectionTitle` heading with an icon. Same mix in the registration sheet
(Activity / Participant / Ticket / Price details bold; host reservation / waitlist system headers).

| MP page → native | Change |
|---|---|
| `pages/activity/detail` → `ActivityDetailView:459`; `pages/activity/baoming` → `RegistrationSheetView:453/763/865/1070` | shared `E1IconHeader` (`E1CommerceComponents.swift`) drops the custom `.cyText(.sectionTitle, .semibold)` + primary colour + secondary icon tint and inherits the List's system section-header style (`Label` with the SF Symbol kept, `.textCase(nil)`, `.isHeader`). Call sites, MP sections and order unchanged; contract pins on `E1IconHeader(systemImage: "ticket"` still hold. |

### Batch 3 — gate kind `header font`
Brace-balanced scan of every `header: { … }` closure on player files: 6 set a font; 5 are footnote/meta trailing
accessories (fine, header size), 1 was a heading: `NPCChatDataView:325` (AI chat records → delete section) used
`.cyText(.sectionTitle)` + primary colour → plain system header text. New checker kind **header font**
(`header_font_hits`): heading text styles / `.bold()` / `.fontWeight(.bold…)` inside a header closure fail; baseline 0.
Self-test: the pre-fix `NPCChatDataView` fails at line 327. Gates: `generate_project` PASS, `check_scaffold` PASS,
`check_a11y_lint` PASS (0 new), `check_design_consistency` PASS (header font 0), `contract_ratchet --check` 52 failing,
baseline 52, **new 0**.

### For other lanes
- mp-mine / debt-r3 (run 30): `test_object_badge_wall_layout` byte pin blocks matching the badge detail name weight
  (`.title2.weight(.semibold)`) to the other hero names (`.title2.bold()`).
- debt-r3: the 18 unmounted `*SectionView` release-checklist pages above (plus their unit tests) are dead code in the
  player target; deleting them would shrink the app and the allowed list.

### Not done (next run)
- Shared header components outside `header:` closures (`E1IconHeader`-like wrappers in page files) are not seen by
  `header font`; scan for `View` structs used only as section headers and fold them into the system header.

## Continue run 30 (2026-11-28, after merging combined-r7 135f87720)

Merge clean. No new coordinator row for this lane (05:35 / 05:50 sweeps: mp-mine, mp-club, mp-roam, mp-journey only).
Run 29 Not done row worked: header wrappers outside the `header:` closure.

| Page (MP → native) | Before | Change |
|---|---|---|
| AI chat record detail (`NPCChatDataView:358/367/379`) | private `NPCChatSectionTitle` set `.cyText(.sectionTitle)` + primary colour in three Form headers (问题 / 回复 / 来源时间) | plain system header text (`.textCase(nil)`, `.isHeader` kept) |
| AI chat records list (`NPCChatDataView:171/189`), co-op finance topics (`CoopFinanceProfitView:136`), MOD creator income (`ModCreatorIncomeViews:81/196/235`), MOD rehearsal (`ModInstallationSavedRehearsalView:137/159`), MOD action receipt (`ModInstallationNativeActionReceiptView:70`), H5 session (`H5DeclaredSessionView:22`) | `CYSectionHeader` (the `.headline` header meant for scroll pages) inside List/Form `header:` closures: 10 headers bigger and darker than every other list header | `Text(title).accessibilityAddTraits(.isHeader)`, same copy and keys; the list header now matches the rest of the app |

Gate `header font` extended (`tools/check_design_consistency.py`): (1) `header: { Wrapper(…) }` resolves `Wrapper`'s
`struct …: View` body (same file first, then any player file) and fails when it sets a heading font; (2)
`CYSectionHeader(` inside a `header:` closure fails. Baseline stays 0. Self-tests: the pre-fix `NPCChatDataView` fails
at 358/367/379 ("NPCChatSectionTitle (line 402): .cyText(.sectionTitle)"); the pre-fix `H5DeclaredSessionView` fails at 22.
Other wrappers checked and clean: `DiscoverySectionHeader`, `NativeChannelSectionTitle`, `TemplateXbSectionTitle`,
`ClubOpsCustomerHeading`, `ChannelNotifyHeading`, `ClubStoryChapterHeader`, `E1IconHeader`.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(0 debt, header font 0, 114 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Batch 2 — scroll-page section titles
Scanned every player file that uses `CYSectionHeader` for a hand-built `.cyText(.sectionTitle)` title on the same page:
4 hits, none a section title (dice check result line `PlayRPGComponents:130`, MOD content title `ModInstallationView:540`,
role title `JourneyRoleViewSection:128`, pack art name `FreeExplorationViews:39`): no change. Header-named wrapper
structs with their own font: `MPSectionHeader` (`MPParityKit.swift`, `.meta` secondary + padding, a second list-header
look) had **0 call sites** → deleted. `E3SectionTitle` is used only by `DesignFixtures/E3Fixtures.swift` (left).
Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS,
`contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Batch 3 — one hero-name weight
Object/person hero names: 54 use `.title2.bold()` (activity, club, team, public profile, co-op invite …), 9 use
`.title2.weight(.semibold)`. Of the 9, five are numbers/codes/glyphs (ticket number, invite code, progress, stats, quiz
character: left), two are person names:

| MP page → native | Change |
|---|---|
| `subpackageMember/components/cy/profile` (Me card name) → `MemberHomeHeader:60` | `.title2.weight(.semibold)` → `.title2.bold()`, same as the public profile name (`SocialPublicProfileView:137`) |
| `pages/member/gerenziliao` `.rv-name` → `ProfileCurrentAvatarView:86` | same |

Kept: badge detail names (`ObjectBadgeViews:258`, `ProfileBadgesView:107`) stay semibold together —
`test_object_badge_wall_layout…byte_identical` pins the detail; changing one alone would split the two badge views.
Gates: `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS, `contract_ratchet --check`
52 failing, baseline 52, **new 0**.

### Not done (next run)
- Badge detail name weight (needs the byte pin re-pinned by mp-mine / debt-r3, then `.title2.bold()` in both views).
- Next scan: `.font(.title.bold())` (9) vs `.cyText(.pageTitle)` (38, same spec) — fold raw spellings into the token.

## Continue run 31 (2026-11-28, rebased onto run 30) — OWNER RULE 3 shared effect kit (ds-consistency goes first)

Took OWNER RULE 3 (11-28 06:10) before the run 29 Not done row: "ds-consistency goes first so the others call it".

| Component (`App/DesignSystem`) | Restored from `89e71d61d^` | Reduce Motion / Low Power gating |
|---|---|---|
| `CYBurst` (particles) | Canvas + TimelineView body | draws only when `!reduceMotion && CYLightBudget.particlesAllowed` (unchanged) |
| `CYConfettiBurst` (`CYSignature`) | Canvas confetti body | `fire()` now also requires `CYLightBudget.particlesAllowed` (was Reduce Motion only) |
| `CYStarBloom` | horizon / glow / silhouette / orbit | callers pass `phase: 1` under Reduce Motion and `cheap` under Low Power (`CYCelebrationViews:536`) |
| `CYFogLayer` (`CYRoamKit`) | drifting fog Canvas + reveal spring | drift now also requires `CYLightBudget.shadersAllowed`; static frame otherwise |
| `CYEdgeGlow` + `.cyEdgeGlow(trigger:)` | comet sweep + ring | Reduce Motion: ring fade only; Low Power: `cheap` (no blur layers); Reduce Transparency: solid ring |
| `CYFoil` / `.cyFoil` | live foil + tilt hold | live only with `!reduceMotion && gyroAllowed`; static highlight otherwise |

Not restored on purpose: `CYMapChrome` and the Roam panel (coordinator 02:05: settled, do not edit), `CYNightGlass`
(map buttons; part of the settled map chrome), `CYGlassCarousel` / `CYGlassSliver` / `CYGlassGroup` /
`CYCarouselBackdrop` (only mounted by `DesignFixtures/CarouselFixtures`; no distinctive surface uses it yet).

Clean-page calls removed (the effect would now be live there):

| MP page → native | Call removed | Why clean |
|---|---|---|
| `subpackageMember` ticket wallet → `App/E1TicketCard.swift:38` | `.cyFoilSheen(trigger: sheen + autoSheen)` | wallet list (OWNER RULE 3 clean list); tap keeps its selection haptic, the pass foil edge stays |
| roam stamp album → `App/RoamStampViews.swift:439` (`RoamStampAlbumPage`) | `.cyFoilSheen(trigger:)` on flip | album grid = collection list (P24); the stamp-collected moment keeps `cyStampSlam` / celebrations |

Gate: new kind **effect on clean page** (`tools/check_design_consistency.py`, `EFFECT_PATTERN`): any call to the kit
above outside the distinctive surfaces fails. Allowed: `EFFECT_SURFACE_DIRS` (`NativeR2/Games`, `Story`,
`FreeExplore`, `CityOrientation`, `MapHome`, `Motion`), `EFFECT_SURFACE_NAME` (play / game / chapter / story /
pay / checkout / journey report / roam live, finish, fog / city roam / stamp capture / celebration / reward files),
and `EFFECT_KIT_FILES` (the kit and its celebration / album / medal hosts). One allowed entry with reason:
`CYTicketPass` `cyCodeReveal` (pass reveal after payment, no clean call site). Celebration overlays
(`.cyCelebrations`, `.cyStampSlam`) are the allowed moments themselves and are not flagged on their host pages.
Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS (0 debt, 115 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.
Current hits: 0. Self-test: re-adding `.cyFoilSheen(trigger: sheen)` to `E1TicketCard` fails at line 39; reverted.

Callers for the other lanes (OWNER RULE 3 owners): mp-roam `CYFogLayer` (only a fixture mounts it today) and stamp
burst; mp-journey games / story / run finish; mp-activity payment moment; mp-mine badges / level (`CYStarBloom` via
`CYCelebrationViews`); mp-club `CYJoinReward`. All of them pass the gate when called from their surface files.

No compiler in the cloud: the restored bodies are the exact pre-11-26 code; helpers they call (`draw`, `CYFogCanvas`,
`CYFoilLive`, `cyTiltHold`, `horizon` …) were never removed. Next integration build confirms.

### Not done (next run)
- Page-hero headers (`ActivityDetailHeader`, `ClubDetailHeader`, `TeamPageHeader`: `.title2.bold()`) vs
  `cyPageTitle`: one hero title style (run 30 row).
- Effect kit: reduce-motion fallback for `CYBurst` / `CYConfettiBurst` is "draw nothing" (callers pair a haptic);
  check each celebration caller also shows the static state (opacity fade) per OWNER RULE 3.

### Run 30 batch 4 — `docs/design/levels.md` (OWNER RULE 3 clarified, 06:20)
The brief asks ds-consistency for a map of every screen to A · Signature / B · Crafted / C · Utility. Written from the
function audit's screen list (`origin/audit/1128-functions`, 5 tabs + cross-tab payment) plus the play/game/story
screens (not in that audit): each row = screen → native view → level → owner-lane note (P-principle where it applies).
Level rules and the "never" column per level match the brief; the gate kind `effect on clean page` (run 31) enforces A
effects off B/C files. Lanes add a row for any screen not listed, at its closest sibling's level.

## Continue run 32 (2026-11-28, rebased onto run 30 batch 4, merged combined-r7)

Merge clean. No new coordinator row for this lane. Run 31 / run 30 Not done rows:

- **Page-hero headers (run 31 row): closed, no change.** Run 30 batch 3 settled the in-content object/person name on
  `.title2.bold()` (54 sites, incl. `ActivityDetailHeader`, `ClubDetailHeader`, `TeamPageHeader`); `cyPageTitle` is
  the navigation-bar inline title, not an in-content style, so the two do not compete. (A draft of this run moved 7
  heroes to `.title`; dropped on rebase so the 54 stay one style.)
- **Effect kit Reduce Motion fallback (run 31 row): checked, no change.** Every celebration caller shows the static end
  state: stamp celebration (`CYCelebrationViews`: timeline jumps to the final frame, `play()` returns early),
  collectible result (`CYCollectible`: `landed = true`), club joined (`CYJoinReward`: status chip, no seal / burst),
  album unlock (`CYAlbum.cyUnlockCelebration`: content static + success haptic), play reward badge
  (`PlayRewardBadgeRows`: static medal, `cyStampSlam` gated).
- **`.font(.title.bold())` vs `.cyText(.pageTitle)` (run 30 row):** same spec, two spellings. Headings folded into the
  token (MP content and order unchanged):

| Page (MP → native) · level | Line | Change |
|---|---|---|
| shared hero (`CYHeroHeader`, city board / neutral task) · B | `App/DesignSystem/CYHeroHeader.swift:42` | `.font(.title.bold())` → `.cyText(.pageTitle)` |
| sign-in headline (`pages/login`) · C | `App/LoginView.swift:70` | same |
| cast start identity question · A | `App/CastViews.swift:260` | same |
| template timer / reaction rehearsal (publish preview) · C | `TemplateTimerRehearsalView:149`, `TemplateReactionRehearsalView:132` | same |

Kept raw on purpose (numbers / glyphs, not headings): wallet currency glyph (`WalletCommerceViews:675, 1318`), event
collective percent (`OfficialEventDetailView:118`, monospaced digit), dice face (`ChanceKits:47`).

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(0 debt), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
- Badge detail name weight (run 30 row; needs mp-mine / debt-r3 to re-pin `test_object_badge_wall_layout…byte_identical`).
- Number styles: big numbers outside the `.dataXL`/data tokens (`.font(.title.bold())` glyph/percent above, other
  `.largeTitle` counts) → one count style (ADA audit cross-screen section).

## Continue run 33 (2026-11-28, merged combined-r7)

Merge clean (1 file). No new coordinator row for this lane (07:05 sweep: mp-states, mp-activity). Run 32 Not done rows:
badge detail weight still waits for the byte re-pin (mp-mine / debt-r3); **one count style** worked here.

Big numbers drew in two faces: `.cyText(.dataXL)` / `CYLiveCounter(style: .dataXL)` (largeTitle, bold, rounded,
monospaced) on passport, balance, city board, medals; raw `.font(.largeTitle.bold|semibold)` + `.monospacedDigit()`
(default face, mixed weights) on 20 other count sites. All folded into `.cyText(.dataXL)` (copy, MP sections, order,
`contentTransition` and identifiers unchanged):

| Page (MP → native) · level | Lines |
|---|---|
| Me points (`subpackageMember/components/cy/profile`) · B | `MemberHomeHeader:393, 714` |
| passport stamp/badge placeholder "—" (now same face as the counter beside it) · B | `PassportView:189, 401` |
| order paid amount · C | `ProfileOrdersView:794`, `OrderCardComponents:126` |
| invite rewards total · C | `ProfileInviteRewardReviewSection:18` |
| pass points (`subpackagePass`) · B | `PassMarketViews:286` |
| bundle units / refund quote / transfer code · C | `BundleWalletView:75`, `BundleRefundQuoteView:66`, `BundleTransferSendView:139, 149` |
| income month amount · C | `WalletIncomeAnalysisView:123, 128` |
| template rating · B | `DiscoveryTemplateDetailParitySections:78` |
| publisher price floor · C | `PublisherLifecycleViews:120` |
| channel check-in streak · B | `NativeChannelCheckinView:103` |
| orienteering score · A (number only) | `OrientScoreView:225` |
| live-session mini HUD time · A (number only) | `ActiveSessionMiniBar:217` |
| team gathering "n/m" · A (number only) | `PlayExperienceView:1984` |
| motion reminder steps / walk left · B | `NativeMotionReminderViews:31, 106, 366` |
| template timer / dice sample preview · C | `TemplateTimerRehearsalView:214`, `TemplateAdditionalSampleBrowserView:197` |

Kept: game HUD numerals in `NativeR2/Games` (`ChanceKits:140`, `NativeGameKitsB:332`, level A, own look); headings
(`CastViews`, `WelcomeView`, story reader) are display text, not counts.

Gate: new kind **raw count** (`RAW_COUNT`): `.font(.largeTitle…)` with `.monospacedDigit()` on the same or next line,
outside `App/DesignSystem` and the OWNER RULE 3 effect surfaces; baseline 0. Self-test: before the second batch it
failed on `BundleTransferSendView`, `NativeMotionReminderViews:106`, `TemplateAdditionalSampleBrowserView:197`.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(0 debt, raw count 0), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Batch 2 — mid-size counts: token `numericTitle`
No token sat between `numericBody` (row number) and `dataXL` (hero): 18 card prices / stats used `.title3` with three
weights (semibold 13, bold 4, regular 2). New token **`numericTitle`** = `.title3`, semibold, monospaced digits
(`CYDesignTokens.swift`, `tools/typography_scale.py`, rule card `docs/design/type-and-chrome.md`). Folded:

| Page (MP → native) · level | Lines |
|---|---|
| topic detail / self-play price (`pages/topic/*`) · B | `TopicDetailView:568`, `TopicXcxSections:159, 301, 314`, `TopicSelfPlaySheet:115` |
| workshop offer price · B | `WorkshopCommerceView:92` |
| pass plan price (`subpackagePass`) · B | `PassMembershipViews:268` (bold → semibold) |
| bundle order total · C | `BundleOrderSummarySheet:89` |
| Me card stats / balance · B | `MemberHomeHeader:338, 430` (balance regular → semibold) |
| order card amount · C | `ProfileOrdersView:465` |
| withdrawal application number · C | `BankWithdrawalView:186` |
| club customer paid total / day · C | `ClubOpsCustomerViews:261, 380` |
| roam runner / subpage stat · B | `RoamRunnerDetailView:121`, `RoamSubpageParityViews:23` (bold → semibold) |
| bingo step number · C | `ProjectEditBingoPage:84` |
| native gallery sample | `NativeGalleryScreens:453` |

Gate `raw count` now also covers `.font(.title3…)`, with `.monospacedDigit()` on the same chain (same line or a
following `.monospacedDigit()` line, so a title above a number is not flagged). Baseline 0. Kept: play surfaces
(`PlayExperienceView:1018`, `PlayAreaPopupCloseSurfaces:540`, CityOrientation `.title2` HUD) — level A.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_typography_lint` PASS, `check_a11y_lint` PASS (0 new),
`check_design_consistency` PASS (raw count 0), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
- Badge detail name weight (run 30 row; needs the `test_object_badge_wall_layout…byte_identical` re-pin).
- `.title2` counts (`BundleDetailView:58`, `OfficialEventDetailView:118` percent) — decide numericTitle vs dataXL.

## Continue run 34 (2026-11-28, merged combined-r7)

Merge clean. No new coordinator row for this lane (latest: 07:05 sweep, mp-states / mp-activity). Run 33 Not done:
badge detail weight still waits for the `test_object_badge_wall_layout…byte_identical` re-pin (mp-mine / debt-r3);
**`.title2` / `.title` counts: decided.** A stat or price inside a list row or metric tile is `numericTitle`; the one
section hero figure is `dataXL`. Folded (copy, MP sections, order, a11y labels and identifiers unchanged):

| Page (MP → native) · level | Line | Change |
|---|---|---|
| bundle detail price (`subpackagePass` bundle) · B | `App/BundleDetailView.swift:58` | `.title2` semibold digits → `.cyText(.numericTitle)` |
| official event collective "lit %" · B | `App/OfficialEventDetailView.swift:118` | `.title.bold()` digits → `.cyText(.dataXL)` (section hero) |
| channel progress "done/required" · B | `App/NativeChannelProgressBoardView.swift:328` | `.title2` semibold digits → `numericTitle` |
| club stats metric tiles (club admin) · C | `App/ClubStatsOverviewView.swift:218` | same |
| member score appeal total · C | `App/MemberScoreAppealDetailView.swift:35` | `.title2.bold()` digits → `numericTitle` |
| game shell record stats (shared `CYRecordStatGrid`) · A | `App/NativeR2/Components/CYRecordStatGrid.swift:40` | `.title2.bold()` digits → `numericTitle` |

Gate `raw count` now covers `.font(.title…)` and `.font(.title2…)` too (largeTitle / title / title2 / title3 with
`.monospacedDigit()` on the chain), outside `App/DesignSystem` and the effect surfaces. Self-test: with the font
widened it failed on `CYRecordStatGrid:40` before that fold. Kept: `TicketPassSheet:348` (`.monospaced()` pass code,
not a count), `PlayKitTimedChallengeView:100` (type-in prompt), CityOrientation / Games HUD numerals (level A).

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(0 debt, raw count 0, 115 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
- Badge detail name weight (needs the `test_object_badge_wall_layout…byte_identical` re-pin).

## Continue run 35 (2026-11-28, merged combined-r7 8952067e9)

Merge clean. No new coordinator row for this lane (07:45 sweep: mp-nav, mp-activity). Run 34 Not done: badge detail
weight still waits for the `test_object_badge_wall_layout…byte_identical` re-pin. Next cross-screen row from the ADA
audit §3 **Role / level** ("Lv.3 City explorer" vs "Level 3 · City explorer"): one player-level string, the MP's
`Lv.N` (`components/cy/level-progress/index.wxml:12`, `post-card/index.wxml:26`, `pages/club/detail/index.wxml:298`,
`subpackageMember/components/cy/profile/index.wxml:69`), in both languages.

| Page (MP → native) · level | Key / line | Before → after |
|---|---|---|
| growth centre (`level-progress`) → `GrowthCenterView:229` · B | `growth.level.value %lld` | en "Level %lld" → "Lv.%lld" (zh already Lv.) |
| settings account row → `SettingsView:422` · C | `settings.account.subtitle %lld` | en "Level %lld · City explorer" → "Lv.%lld · City explorer" |
| club members (`pages/club/detail` member-meta) → `ClubMembersView:279`, `ClubPublicRosterView:138` · B | `club.memberLevel %lld` | en "Level %lld" / zh "等级 %lld" → "Lv.%lld" both |

Already `Lv.N`: Me header (`MemberHomeHeader:239`), public profile (`SocialPublicProfileView:146`), square post badge.
Not touched (different concepts): territory property level (`CityMonopolyLevel`, game, level A), attribute levels
(`MemberAttributesSection`). Pins updated with the change: `test_club_member_display.py` (catalog values, UI-test
tokens) and `ModuleFlowTests.swift:137–143` ("Level 7/4/0" → "Lv.7/4/0"), string snapshots
`docs/release/ui-strings-e4.json:12`, `ui-strings-subpackageP3-pages-growthcenter-index-index.json:46`.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS,
`contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Batch 2 — one badge state pair (ADA audit §3 **State words**)
ZH badge "locked" had three words (未点亮 / 未解锁 / 尚未点亮) for one state. MP badge wall sections are
已点亮 / 未解锁 (`subpackageP3/pages/badge-wall/index/index.js:22–23`), so the pair is **已点亮 · 未解锁** / Unlocked · Locked.

| Page (MP → native) · level | Key | Before → after |
|---|---|---|
| badge wall cell state + detail label → `ObjectBadgeViews:182, 263`, `ProfileBadgesView:144` · B | `profile.badges.locked` | zh 未点亮 → 未解锁 |
| badge wall locked meta → `ObjectBadgeViews:213` · B | `objects.badge.meta.locked` | zh 尚未点亮 → 未解锁 |

Section titles (`profile.badges.unlocked` 已点亮, `profile.badges.notUnlocked` 未解锁) unchanged; EN already Unlocked ·
Locked. Snapshot `docs/release/ui-strings-subpackageP3-pages-badge-wall-index-index.json:111` follows. Gates: generate_project,
check_scaffold, check_design_consistency PASS; `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
- Badge detail name weight (needs the `test_object_badge_wall_layout…byte_identical` re-pin).

## Continue run 36 (2026-11-28, merged combined-r7)

Merge clean (22 files). No new coordinator row for this lane (latest: 07:45 sweep, mp-nav / mp-activity). Run 35 Not
done: badge detail weight still waits for the `test_object_badge_wall_layout…byte_identical` re-pin. Next cross-screen
row from the ADA audit §3 **Count format** ("3 of 12" EN passport vs "3 / 12" ZH vs "3 / 6" ring): the collection
ring denominator. MP badge wall ring = big number over **共 N** (`subpackageP3/pages/badge-wall/index/index.wxml:41`
`bw-ring__t`), same word as the stamp album total (`scene-roam-stamp-album/index.wxml:7` 共 N 枚).

| Page (MP → native) · level | Line / key | Before → after |
|---|---|---|
| badge wall ring + roam stamp album ring (shared `CYAlbumProgressRing`) · B | `App/DesignSystem/CYAlbum.swift:119` | verbatim "/ N" (no EN word) → new key `collection.ofTotal %lld` en "of N" / zh "共 N" |
| passport stamp / badge counters (number over denominator) · B | `passport.stamps.ofTotal %lld` (`PassportView:187, 398`) | zh "/ N" → "共 N" (en "of N" unchanged) |

So every number-over-denominator collection count now reads N · of M / N · 共 M. Inline sentences keep the existing
key `passport.stamps.count` (en "N of M", zh "N / M"). Kept compact "n/m" on purpose: per-badge progress
(`ClubBadgeArtKit:182`), HUD clues, character limits, team seats (counters, not collection totals). `CYCountRing` has
no call site. Snapshot `docs/release/ui-strings-ia.json:45` follows.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS (0 debt, 114 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
- Badge detail name weight (needs the `test_object_badge_wall_layout…byte_identical` re-pin).
- Roam stamp album ring passes `value: total ?? 0, total: total` (`RoamStampViews:358`), so it always reads full;
  ADA "3 stamps in total while showing 2" — for mp-roam (data), see For other lanes.

### For other lanes
- mp-roam: `RoamStampViews.swift:358` ring value = total (always full); pass the collected count once the album reader
  returns it (MP shows only 共 N 枚 there, so a plain total line may be the MP-faithful choice).

## Continue run 36 (2026-11-28, combined-r7 70917c058 already merged)

Merge: up to date. No new coordinator row for this lane (latest: 07:45 sweep mp-nav / mp-activity; 12:25 AI items go
to `fix/1128c-*`). Run 35 Not done row worked: **badge detail name weight.** The two badge detail heroes drew the
name in `.title2` semibold while the other 54 in-content object names use `.title2.bold()` (run 30 batch 3). The byte pin
`test_existing_detail_and_route_lifetimes_are_byte_identical` was re-pinned here with a one-line reason (this lane
re-pinned it in runs 9 and 10 the same way); detail content, MP sections and route lifetimes unchanged.

| Page (MP → native) · level | Line | Change |
|---|---|---|
| badge detail (`subpackageP3/pages/badge-3d`) → `ObjectBadgeDetailView` · B | `App/ObjectBadgeViews.swift:258` | `.title2.weight(.semibold)` → `.title2.bold()` |
| profile badge detail → `ProfileBadgesView` · B | `App/ProfileBadgesView.swift:107` | same |

Pin: `Tests/ContractChecks/test_object_badge_wall_layout.py` sha256 → `c2de7c1d…` (8 tests OK).
Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency` PASS
(0 debt, 114 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
- none. Scan of the other `.title2.weight(.semibold)` sites: `TicketPassSheet:348` pass code, `TeamComponents:344` invite
  code (monospaced codes) and `PlayKitQuestoViews:330` crossword letter (level A) are not names; kept.

## Continue run 37 (2026-11-28, merged combined-r7 0446d1c4f)

Merge clean. No new coordinator row for this lane (latest: 12:25 AI items → `fix/1128c-*`). Run 36 Not done: none.
Next cross-screen row from the ADA audit §3 **Dates** ("ZH raw `2026-11-06 18:20:00` on the wallet, order, chat and
free-explore screens"): the shared civil-date formatter. MP never shows seconds (`utils/datetime.js`
`formatMinuteDots`, ledger `scene-asset-income-detail/index.js:15` 今天 / 昨天 / M月d日); the app's own zh day-time
shape is `yyyy-MM-dd HH:mm` (`LocaleDisplay.dayTime`).

| Page (MP → native) · level | Line | Before → after |
|---|---|---|
| every `LocaleDisplay.civil` caller (~70: 余额流水 `WalletCommerceViews:641,736,1144` · C, withdrawal history · C, order lifecycle · C, club join / request times · B/C, free-explore visited-on · B, ticket participate date · B, topic sessions · B) | `Core/LocaleDisplay.swift` `civil` + `civilChineseMinutes` | zh `2026-11-06 18:20:00` / `…T18:20:00` → `2026-11-06 18:20`; date-only and other zh text unchanged; en unchanged |

Pin: `Tests/CoreTests/LocaleDisplayTests.swift:47` zh expectation follows (seconds dropped, `T` form, date-only kept).
Display only: every caller renders the result (checked: none feeds it back into a wire value). Call sites that trim
`prefix(16)` by hand (`ClubActivityListContent:132`, `ClubManagedProjectsSection:35`, `SettingsPostGovernanceView:53`)
keep working.

### Batch 2 — one avatar fallback (ADA audit §3 **Avatars**: memoji vs grey glyph vs "S"/"F" monograms)
`CYAvatarView`, `ClubMPAvatar`, `SquareAuthorAvatar` and `SettingsAccountAvatar` already fall back to the MP default
face `/images/d_profile.png` (`MPAsset.AvatarDefault.dProfile`; 38 MP wxml/js uses). `MPAvatar` was the last one
drawing a per-screen initial monogram on a grey disc.

| Page (MP → native) · level | Line | Before → after |
|---|---|---|
| journey landing inviter (72 pt) + circle cards (56 pt) → `JourneyLandingViews:407, 813` · B; journey leaderboard rows (32 pt) → `JourneyReportViews:339` · B | `App/MPParityKit.swift` `MPAvatar` | initial monogram on `.fill.secondary` → MP default face under the remote photo, clipped circle |

`initial:` kept on the API so the 3 callers are unchanged; VoiceOver stays hidden (the name is next to it in every
row). `CYAvatarView` labels `用户头像` / `%@的头像` are catalog keys with en values (checked). `E3Avatar` (seeded art, no
URL, club kit fixtures/cards) is a different object and stays.

### Not done (next run)
- ADA §3 Dates, second half (twin run 37 note): hand-built month-day rows `WalletPointsShortTime`
  (`WalletCommerceViews.swift:1336`) and `WalletIncomeDayText` (`WalletEarningsParity.swift:4`) print `11/6 18:20` / `11/6`
  in en instead of a localized form; route the en path through `LocaleDisplay.monthDayTime` (zh 11月6日 unchanged).

## Continue run 38 (2026-11-28, merged combined-r7 882fca768)

Merge clean. No new coordinator row for this lane (13:15 sweep: mp-mine / mp-activity / mp-club; K11–K16 to Cursor).
Run 37 Not done row worked: **ADA §3 Dates, second half** — hand-built English month-day text.

| Page (MP → native) · level | Line | Before → after |
|---|---|---|
| 积分明细 points rows (`rows.js shortTimeText`) → `App/WalletCommerceViews.swift` `WalletPointsShortTime` · C; invite history latest earn (`ir-earn`) → `App/ProfileInviteHistoryIssueView.swift` · B | `WalletPointsShortTime.text(_:locale:)` | en `11/6 18:20` → `Nov 6, 6:20 PM` (locale template `MMMdjmm`); zh `11月6日 18:20` unchanged; non-date text verbatim |
| 收益明细 income day header (`scene-asset-income-detail/index.js:15`) → `App/WalletEarningsParity.swift` `WalletIncomeDayText` · C | `.monthDay` case | en `11/6` → `Nov 6`; zh `11月6日` unchanged; 今天 / 昨天 unchanged |
| — (shared) | `Core/LocaleDisplay.swift` | new `monthDay(_:locale:)` (zh `M月d日` / en `MMMd`) and `monthDay(month:day:year:hour:minute:locale:)` for server wall-clock parts (fixed UTC, never shifted; nil for an invalid date) |

Test: `Tests/CoreTests/LocaleDisplayTests.swift` `testMonthDayPartsAreLocalizedWithoutShifting` (zh exact, en contains,
Feb 29, invalid date → nil). The `isEnglish:` parameter is gone (the one caller passes the locale); the second caller
(invite card) now reads `\.locale` instead of defaulting to Chinese in English.

Gates: `generate_project` PASS, `check_scaffold` PASS, `check_a11y_lint` PASS (0 new), `check_design_consistency`
PASS (0 debt, 114 allowed), `contract_ratchet --check` 52 failing, baseline 52, **new 0**.

### Not done (next run)
- ADA §3 Dates: 漫游 history run card date `RoamRunCardPresentation.dateShort` (`Core/RoamSubpagePresentation.swift:24`,
  shown by `App/RoamHistoryViews+Port.swift:8`) prints the MP `M/D/YY` (`10/19/25`) in both languages; zh elsewhere
  is `yyyy-MM-dd` / `M月d日`. Route through `LocaleDisplay.day` / `monthDay` and re-pin
  `Tests/CoreTests/RoamSubpageParityTests.swift:17` with a one-line reason (display only).

## Continue run 39 (2026-11-28, merged combined-r7)

Merge clean. No new coordinator row for this lane (latest: 13:15 sweep, K11–K16 to Cursor, B lanes for mp areas).
Run 38 Not done row worked: **漫游 history run card date.** Checked first: the visible card date
(`RoamRunCardDateText`, `RoamSubpageParityViews.swift:58`) is already `.dateTime.month().day().weekday()` in the
locale; `RoamRunCardPresentation.dateShort` (MP `M/D/YY`) only fed the VoiceOver label, so VoiceOver read `10/19/25`
in both languages while the card showed 10月19日 / Oct 19.

| Page (MP → native) · level | Line | Before → after |
|---|---|---|
| `subpackageRoam/history` RunCard aria-label → `App/RoamHistoryViews.swift:109` · B | `App/RoamHistoryViews+Port.swift` `portRunCardAccessibilityLabel(locale:)` | spoken `10/19/25 West Lake, 2.5 km` → zh `10月19日 …` / en `Oct 19 …` via `LocaleDisplay.monthDay` (view `\.locale`) |

`RoamRunCardPresentation.dateShort` stays as the pinned MP projection (`RoamSubpageParityTests:17`, no other caller),
so no test re-pin was needed.

### Batch 2 — one owner role word (ADA audit §3 **Role / level**: "Owner vs Creator")
MP club pages never say 创建者: the owner is 主理人 everywhere (`pages/club/detail/index.wxml:233` Facts 主理人,
`:222`, `:255`; `pages/club/apply`, `create`, `enroll`). The app had 主理人 / Owner on the strip and ops screens
(`club.strip.owner`, `club.ops.owner`) but 创建者 / Creator on the role pill and the roster card.

| Page (MP → native) · level | Line | Before → after |
|---|---|---|
| club detail role pill / members list / action panel / club card (`ClubDetailView:819`, `ClubMembersView:270`, `ClubActionPanel:253`, `ClubComponents:97`) · C | `Resources/Localizable.xcstrings` `club.role.creator` | 创建者 / Creator → 主理人 / Owner |
| club roster card (`ClubRosterCardKit:69,78`) · B | `Resources/DesignR1Club.xcstrings` `r1club.roster.members.roles` (+ generator `tools/build_design_r1_localizations.py:63`) | zh 创建者 %ld → 主理人 %ld (en was already Owner) |

Pin: `Tests/AppUnitTests/DesignR1ClubKitTests.swift:114` zh expectation follows (copy only). Level label: already one
shape (`Lv.N` on Me header `MemberHomeHeader:239` and public profile `SocialPublicProfileView:146`); no "Level 3 ·"
string remains in the catalogs (checked), so nothing to change there.

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
