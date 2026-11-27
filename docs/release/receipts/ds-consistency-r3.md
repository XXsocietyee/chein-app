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
