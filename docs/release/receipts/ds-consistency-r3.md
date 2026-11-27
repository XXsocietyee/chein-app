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

## Allowed (kept on purpose, reasons in the baseline)
- Procedural art sized from its own frame: `CYAlbum`, `CYBadgeCraft`, `CYCityBoard`, `CYCollectible`, `CYCoverArt`,
  `CYMedalStack`, `CYSignature`, `CYStarBloom`, celebration medal glyph, chapter numeral, verdict glyph, wordmark, map pin.
- `CYShareCard`: rendered to a fixed-size export image. `CYThemeLook`: per-theme game look (story-flow, out of scope).
- Full-screen maps / game HUD: `CityRoamRootView`, `NativeFreeExploreMapView`, `RoamLiveSessionView`,
  `RoamFinishReportView`, `ProjectEditOverviewKit` 地图 page; full-screen photo viewer in `SocialPublicProfileView`.
- `NativeStoryWalkingAuthorView` guarded exit (story-flow). `SquareBrowserView` large title: 广场 is a sheet root.
- Press feedback only (no button look): `CityNoticePressStyle`, `QuestifyCardButtonStyle`; `E3PressStyle` (fixtures only);
  `PlayHUDCircleButtonStyle` (game HUD); `QuestifyPrimaryButtonStyle` definition (merchant call site only).
- Data/art colours: dice faces, fog layer, map legend manifest, server `#RRGGBB` preview, camera filters, map route,
  `QuestifyPalette` (the palette definition).

## Gates (run on this branch)
- `python3 tools/generate_project.py` — PASS
- `python3 -B tools/check_scaffold.py` — PASS (now includes `check_design_consistency.py`)
- `python3 -B tools/check_a11y_lint.py` — PASS (0 new)
- `python3 -B tools/check_design_consistency.py` — PASS (0 debt, 54 allowed)
- `python3 -B tools/check_typography_lint.py` — PASS
- `python3 -B tools/contract_ratchet.py --check` — batch 1 (26bb8c423) and batch 2 (32de0d542): 52 failing, baseline 52, **new 0**
