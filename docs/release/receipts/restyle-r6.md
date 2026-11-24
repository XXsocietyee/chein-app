# Receipt: native iOS restyle R6 (design system + everything else)

- **Branch:** `restyle/r6-system-rest`, cut from `origin/ui/combined-r6` (f1115875e).
- **Briefs:** `design/handoff-r2:docs/briefs/restyle-native-r1.md`. Spec: `design/native-ios-r1:docs/design/native-ios-r1.md` (P6a, DRAFT). I followed the spec where it is more specific than the brief.
- **Scope:** visual and structural only. No reader, request, model, state, navigation target, string key or accessibility identifier changed.

## 1. Shared components (pushed first, for R1–R5)

| component | before | after |
|---|---|---|
| `CYTextStyle.spec` / `CYTypography` / `Theme.Font` / `.cyText` (`CYDesignTokens.swift`) | MP rpx ÷ 2 sizes (`Theme.length("--cy-type-*")`), most not Dynamic Type | each token **is** a semantic text style (spec §2.1): display `.largeTitle` bold · pageTitle `.title` bold · sheetTitle `.title2` bold · sectionTitle `.title3` semibold · cardTitle / button `.headline` · body / bodyMedium `.body` (+0.2 em CJK leading) · bodyCompact `.subheadline` · label `.subheadline` medium · meta `.footnote` · caption `.caption` · micro `.caption` medium · numericBody `.body` semibold mono · dataXL `.largeTitle` bold rounded mono · data2XL the one fixed 42 pt, scaled with `.largeTitle`. Nothing below `.caption`. |
| radii (`Theme.Radius`, `CYRadius`) | sm 8 / md 12 / lg 16 / xl 20 / xxl 22 | one set: `CYRadius.card` 12 (`lg` aliases it), `CYRadius.hero` 20 (`xl`, `xxl` alias it), `CYRadius.inner` 8 |
| `CYCard`, `cyCardSurface`, `cyDomainCard` | radius 16, light drop shadow (8 / 6 pt blur) | radius 12, **no shadow** (spec §3.3) |
| new: `cyCard()`, `cyCardRow()` | — | the one content-card surface; a card as a `List` row (clear background, no separator, 6 pt insets) |
| `CYSheetDetent`, `cyDomainSheet`, `CYSheetContainer` | 30/60/80 % fractions, hidden drag indicator, drawn 36×4 grabber, 24 pt custom corner | half/full = system `.medium`/`.large`, **visible system drag indicator**, system corners; container close is an `xmark.circle.fill` with a 44 pt target |
| new: `cySheet(detents:selection:)` | — | the one sheet chrome (spec §3.4) |
| `CYStateLayout`, `CYStateView` (so also `CYEmptyState`, `CYErrorState`, `CYEmptyStateView`, `CYErrorStateView`) | custom art + pill buttons in a VStack | **`ContentUnavailableView`**; actions are system `.borderedProminent` (primary) / `.bordered` (retry) / `.borderless` (link), 44 pt; identifiers kept |
| new: `CYContentState` | — | `.empty(symbol)` / `.failed` / `.signedOut` / `.gated` / `.offline` on `ContentUnavailableView` (spec §3.5) |
| `cyScreenStyle` | rounded-rect system buttons, hidden list background, 12 pt section gap | capsule system buttons, system grouped list background, 24 pt section gap |
| raw `.system(size:)` in `App/DesignSystem` controls | 65 | 50. Converted: control glyphs (tab bar, field check, toast, option sheet, explore kit, pass verified, celebration book icon, business kit badges). Left: proportional art (medals, stamps, covers, cards, share card, chapter flip, play verdict) and glyphs inside fixed circles (hero back, journey nodes). |
| `tools/check_typography_lint.py` | counted every semantic style (`.font(.headline)`) as "raw text style" | counts only styles below `.caption` (spec §5.3 "below floor"); large-title, back-chevron and hidden-back kinds unchanged. Baseline file untouched (P6 owns it; all counts went down). |

## 2. R6 screens ("everything else")

Owned set: 448 top-level `App/*.swift` files not matched by R1–R5 prefixes and not in plan §4 (P1–P5), plus `App/DesignFixtures/`. Changed: 117 files in three ≤ 40-file commits.

| pattern | before → after | count |
|---|---|---:|
| static fonts | `.font(CYTypography.x)` / `.font(Theme.Font.x)` → `.cyText(.x)` | 100 |
| below floor | `.caption2` → `.caption` | 67 |
| literal radii | `cornerRadius: 14/16` → `CYRadius.card`, `22/26` → `CYRadius.hero` | 24 |
| title mode unset | pushed `navigationTitle` / `appNavigationTitle` → `+ .navigationBarTitleDisplayMode(.inline)` | 48 in 39 files (R6 now has 0 unset; 134 remain in R1–R5 / port files) |
| sheets | `cySheet()` on the search filter sheet, other sign-in methods; `cySheet(detents: [.large])` on legal documents | 3 |
| title truncation | H5 shell title `lineLimit(1)` → `cyWrapText()` | 1 |

The remaining `lineLimit(1)` in R6 files are chips, meta lines and message previews, not titles.

## 3. Acceptance

- Screens: `docs/port/accept/r6.txt` (20 fixture routes: design kit, kit player/merchant, welcome, login, consent, onboarding, global search results/offline, NPC, growth center + failure/offline, leaderboard, badge wall + empty/error, nearby merchants + empty).
- **Cloud acceptance: NOT RUN.** `.github/workflows/acceptance.yml` does not exist on any branch yet (checked 11-24), there is no `gh` CLI or Swift compiler in this environment, and the acceptance workflow triggers only on `port/**`. **Nothing here has been compiled.** I kept expressions short and reused existing types. The first acceptance run is the compiler.
- Local gates run:
  - `python3 tools/check_typography_lint.py`: PASS (raw text style 38, Theme.Font 40, raw size 53, back chevron 10, hidden back 3, large title 7; all at or below the baseline).
  - `python3 tools/check_design_lint.py`: PASS.
  - `python3 tools/contract_ratchet.py --check`: see §5.
- Tests updated to the new design: `Tests/ContractChecks/test_design_token_unification_contract.py` (type table now asserts the semantic styles), `Tests/AppUnitTests/DesignSystemSharedComponentsTests.swift` (sheet detents `.medium` / `.large`).

## 4. Component requests and items left after round 1 (superseded by §6–§8)

1. **Colour re-point (spec §2.2) not done.** `CYColor` names still resolve to the MP hex values. The spec is still a DRAFT awaiting the owner (Q1 dark/light, Q3 accent), and `DesignSystemTokenMappingTests` pins those hex values. Do it once the owner approves.
2. **`CYPillButton` re-point to system styles (spec §3.6) not done.** It is already a 44 pt capsule; switching to `.borderedProminent` changes the colour tests above. Same gate as 1.
3. **`appNavigationTitle` default `.inline` not done.** It would conflict with call sites that set `.large` after it. R1–R5 should use `cyPageTitle(_:)` / `cyRootHeader(_:)`.
4. **System tab bar (spec §3.8)**: `QuestifyApp.swift` / `CYNightTabBar` untouched. It is R1-chrome work in the spec and needs owner Q4.
5. **`CYStateArt` illustrations** are no longer drawn by `CYStateLayout` (the system symbol is used). Hero empties that want the art back should pass it as the `ContentUnavailableView` label.
6. **Text growth:** body goes 14 → 17 pt. Check the acceptance screenshots for clipped rows with a fixed `frame(height:)`.
7. R6 long tail still to do by hand: List/Form conversions of hand-built VStack settings pages, `LabeledContent` for key/value rows, detents and a drag indicator on the remaining R6 `.sheet(` sites (116 `.sheet(` in R6 files, 27 set detents), the `NativeStoryWalkingAuthorView` custom back (already an unsaved-edit guard; its identifier `walkingAuthor.back` is pinned by a test, so it was left).

## 5. Contract ratchet

- `python3 tools/contract_ratchet.py --check` on the final tree: **185 failing, baseline 184, new 1, fixed 0**. This is the same as `ui/combined-r6` before this branch. The one "new" failure is the known pre-existing `test_workshop_paid_professional…test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging` (handbook §2: "185 against a baseline of 184").
- The restyle broke four source-pinned contract tests. I updated them in the same way earlier presentation-only changes did, each with a comment:
  - `test_accessibility_hardening_wave` FPA5: Growth now spells the token `.cyText(.data2XL)`.
  - `test_global_search_category_recovery`: `CURRENT_VIEW_SHA256` re-pinned (filter sheet `.cySheet()`, chevron `.caption2` → `.caption`; category recovery untouched). Its frozen inverse `VIEW_SHA256` is unchanged.
  - `test_object_badge_wall_layout`: the detail hash is re-pinned (`CYTypography` → `.cyText` only).
  - `test_p04_publication_presentation_closeout`: expects `.cyText(.body)`.

---

# Round 2 (11-24): the spec mapping in App/DesignSystem + Theme, the R1–R5 component requests, and the rest of the R6 files

- **Commits on `restyle/r6-system-rest`:** `f829a50e1` (design system), `c5849b2f4` (b1), `713d6e072` (b2), `e2ecbcb0e` (b3), plus this receipt. 88 App files and 6 tests changed since round 1.
- **Scope held:** `App/DesignSystem/*`, `App/Theme/*`, `App/DesignFixtures/*` and the R6 App files only. No P1–P5 file, no strings, no `project.pbxproj`, no lint baseline.

## 6. Design-system mapping (spec §2–§3), commit `f829a50e1`

| spec | before | after |
|---|---|---|
| §2.2 colour | `CYDomainPalette` page/surface/label tokens were MP hex values | `bgPage` → `systemGroupedBackground`; `bgSurface`, `bgElevated`, `cardFill` → `secondarySystemGroupedBackground`; `bgRaised` → `tertiarySystemGroupedBackground`; `bgSurfaceSubtle` → `tertiarySystemFill`; `bgInteractive` → `secondarySystemFill`; `textPrimary` → `label`; `textSecondary` and `textTertiary` → `secondaryLabel`; `textPlaceholder` → `placeholderText`; `textDisabled` → `quaternaryLabel`; `borderSubtle` → `separator`; `sheetGlass` → `systemBackground`. Each colour resolves in the role's appearance (player dark, merchant light) and keeps the Increase Contrast and elevation traits (`UITraitCollection.modifyingTraits`). The MP hex values stay as the non-UIKit fallback. |
| §2.2 kept on purpose | | `brand`, `actionPrimary*`, status hues, `rare`/`medal`/`game` accents, `textInverse`, `sheetCard`. `textTertiary` maps to `secondaryLabel` rather than `tertiaryLabel`, because most call sites are small meta text (spec: "small meta text uses `.secondary`"). `borderStrong` keeps the owner-adopted 3:1 boundary value, because `opaqueSeparator` is about 1.7:1. The tab ink keeps the MP `#F8F8F8` / `#000`. |
| §3.6 buttons | `CYPillButton` drew its own fill | **`CYPillButton` is the system button**: `.borderedProminent` / `.bordered` / `.borderless`, `.controlSize(.large)` (`.extraLarge` for moments), `.buttonBorderShape(.capsule)`. The monochrome tint is `actionPrimaryBg` and the label colour is set explicitly (the white-on-white gotcha). No second press animation. |
| §3.6 named styles (R1/R3/R4/R5 request) | `CYPillButtonStyle`, `.cyPrimary`/`.cySecondary`/`.cyGhost`/`.cyDestructive`/`.cyFooterPill`, `CYDomain*ButtonStyle`, `.questifyPrimary`, `.editorPrimary`/`.editorSecondary` (via `CYPillButtonStyle`) | Every one is a capsule with a `.headline` label and the system press highlight (opacity, no scale). `.questifyPrimary` always keeps the 44 pt target. They stay `ButtonStyle`s, because `AnyButtonStyle`, `NavigationLink` labels and R3's `ButtonStyle where Self == CYPillButtonStyle` extension need that type. |
| §3.4 sheets | `roleThemedPresentation`, `cyDomainSheet`, `cyPlayerSheetGlass`, `CYResizableSheet`, the fit-sheet modifier and `CYConfirmSheet` set `presentationCornerRadius(24)` and/or a glass background; two hid the drag indicator | System corners and background everywhere, and the drag indicator is always visible. `cyPlayerSheetGlass()` is now `themeDomain(.player)` only, so its ~10 R4 and other call sites follow without edits (R4 request 2). |
| §3.7 segmented (R2 request 1) | `CYTabs(.segmented)`: inverse label on a black pill | Drawn like `UISegmentedControl`: fill track, raised `segmentThumb` (white / `#636366`), label ink, `.subheadline` medium/semibold, inner radii. It **keeps one accessibility identifier per segment** (`club.detail.tab.<key>`), which `Picker(.segmented)` cannot do. R2 can use `CYTabs(variant: .segmented)` as the `CYSegmentedPicker`. |
| §3.3 cards | dark cards drew a 0.5 pt top highlight | Elevation comes from the grouped surface colour. Increase Contrast adds a 1 pt `borderStrong` edge (`CYIncreaseContrastEdge`). |
| §2.4 spacing | half-steps 2/6/10/14 | They snap to 4/8/12/16 (`xxs`, `s1_5`, `s2_5`, `s3_5` keep their names). |

## 7. Component requests from R1–R5: status

| from | request | status |
|---|---|---|
| R1 1, R3, R4 3, R5 1 | re-point `CYPillButton` and the named button styles | **done** (§6) |
| R1 2, R3 | `caption` / `micro` to `.caption` | **done in round 1** (`caption` = `.caption`, `micro` = `.caption` medium; nothing below the floor) |
| R1 3 | `CYHeroHeader` repeats the bar title | **Answer (no code change):** `CYHeroHeader` already blanks the bar title (`cyHeroScreen()`: an empty inline title), so the in-content header is the one visible title. Where an R1 page also sets its own `.navigationTitle`, drop one of the two. Keep `CYHeroHeader` when the page needs the `titleIdentifier` anchor (for example `mapPublicLayers.storyNode.title`). |
| R1 4, R2 3, R3, R4 4, R5 3 | state kit → `ContentUnavailableView` | **done in round 1** (`CYStateLayout`/`CYStateView`, so also `CYEmptyState`/`CYErrorState`/`CYEmptyStateView`/`CYErrorStateView`). `MPLoadSwitch` failures use it too. Loading stays a skeleton (allowed). |
| R1 5, R4 1 | system grouped backgrounds via `CYColor` | **done** (§6); `cyScreenStyle` already shows the system grouped list background (round 1) |
| R1 6, R5 2 | `cySheet`; `cyDomainSheet` without glass; visible indicator | **done** (`cySheet` in round 1; glass and corner radius removed in §6). `cyR1Sheet` / R5's `[.large]` wrappers can now call `cySheet(detents:)`. |
| R2 1 | segmented control with per-segment ids | **done** (§6, `CYTabs(.segmented)`) |
| R2 2 | detents on ~60 R2 sheets | **R2's call sites**: `cySheet(detents:)` is the one-line fix; the kit cannot add detents to a plain `.sheet` |
| R4 2 | retire `cyPlayerSheetGlass` | **done** (§6, call sites unchanged) |
| R4 5 | `appNavigationTitle` default `.inline` | **Not done, on purpose.** Its call sites already set an explicit mode (R6 now has 0 unset). A default inside the modifier could override or fight the explicit `.large` on tab roots, and that cannot be verified without a compiler. |
| R4 6 | `CYRadius.card/.hero/.inner` | **done in round 1** |
| R5 4 | `CYTypography` statics on icons | They follow the tokens (each token is a semantic text style since round 1), so there is nothing per call site. |

## 8. The rest of the R6 files (505 files: 448 App + 57 fixtures)

Each file was scanned for literal radii, static `CYTypography`/`Theme.Font` text, `.caption2`, raw sizes, unset title modes, sheets without detents, custom back chevrons, hidden bars, duplicate refresh buttons, destructive actions without a role, icon-only buttons without a label, and hand-built `ScrollView` settings pages.

| batch | change | sites / files |
|---|---|---|
| b1 `c5849b2f4` | literal `cornerRadius:` → `CYRadius.inner/card/hero` (≤ 10 / 11–16 / ≥ 18, text fields → card), every `RoundedRectangle` continuous | 73 sites, 41 files |
| b1 | remaining static `.font(CYTypography.x)` → `.cyText(.x)`; icon glyphs → `.footnote` | 7 |
| b2 `713d6e072` | sheets whose content set no detents anywhere → `Group { … }.presentationDetents(…).presentationDragIndicator(.visible)`; `[.large]` keeps the old height, `[.medium, .large]` for the area picker, age gate and fixture | 27 sites, 18 files |
| b2 | unset title mode → `.navigationBarTitleDisplayMode(.inline)` | 26 sites |
| b3 `e2ecbcb0e` | `MPParityKit` rows and section headers in native row type (pass market, orders, gifts); `HostTipConfigScreen` → `Form` with header and footer; the duplicate toolbar refresh in `NearbyTeamViews` removed (pull-to-refresh calls the same `refresh()`) | 3 files |

After round 2, the scan finds **0** R6 hits for: static fonts, `.caption2`, raw sizes on text, unset title modes, sheets without detents, sheet glass and corner radius, and duplicate refresh. The destructive actions in R6 already carry `role: .destructive`.

**Kept on purpose** (spec §3.10 or behaviour):
- art radii (0, 1, 4, 25, 32: avatar circles, bubble tail, foil sheen);
- the drag-lift shadow in `ConfigR4Kit` and the ticket-card shadows (ticket pass art);
- the hidden bars on `WelcomeView` (root), `UsageConsentGateView` (consent gate) and the in-page search host (documented frame fix);
- `NativeStoryWalkingAuthorView`'s guarded back (`walkingAuthor.back` is pinned by a test);
- the `checkVersion` toolbar action in `NativeChannelProgressBoardView` (a different action from refresh);
- `HostTipPlayerScreen`: its amount shortcut buttons share one row, and inside a `Form` row a tap could fire all of them;
- engineering and readiness dashboards (`*SectionView`, `MasterReleaseSignoff…`, `ReformWorldHost…`) stay card pages;
- `CharacterSheetDetailView`, `GroupPollOriginalResultView` and `BankWithdrawalView` stay card/form pages, because their headers and fields are custom content.

## 9. Pins updated (decision 1). No behavioural assertion was weakened.

- `Tests/AppUnitTests/DesignSystemTokenMappingTests.swift`: page/surface/label/disabled colours are now asserted against the UIKit semantic colours (`assertSameColor(…, Color(uiColor: .systemGroupedBackground))` etc., plus hex `#F2F2F7` / `#1C1C1E` / `#FFFFFF`). The segmented selected state is label ink on `segmentThumb`.
- `Tests/AppUnitTests/DesignR1FoundationTests.swift`: the player secondary and tertiary pill labels are white (`label`), not `#F8F8F8`. Fills are unchanged.
- `Tests/ContractChecks/test_design_token_unification_contract.py`: the spacing half-steps alias the grid steps.
- `Tests/ContractChecks/test_global_chrome_domain_contract.py`: `cyPlayerSheetGlass` is `themeDomain(.player)` with no `presentationCornerRadius`. `CYConfirmSheet` has no corner radius and still uses `CYColor.sheetGlass` for its bar. The 12 call-site assertions are unchanged.
- `Tests/ContractChecks/test_reference_map_layouts.py`: `QuestifyImageEntityCard` uses `cornerRadius: CYRadius.hero` (was the literal 24). The full-bleed, scrim and text assertions are unchanged.
- `Tests/ContractChecks/test_global_search_category_recovery.py`: `CURRENT_VIEW_SHA256` re-pinned (inline title only). The frozen `VIEW_SHA256` is unchanged, and the test fails the same 9 pre-existing cases as before.

## 10. Gates

- `python3 tools/check_typography_lint.py`: PASS (raw text style 38, Theme.Font 40, raw size 53, back chevron 10, hidden back 3, large title 7; nothing above the baseline).
- `python3 tools/check_design_lint.py`: PASS. `python3 tools/check_scaffold.py`: PASS.
- `python3 tools/contract_ratchet.py --check` on the final tree: **185 failing, baseline 184, new 1, fixed 0**. That is the same as round 1 and `ui/combined-r6`: the one "new" failure is the known pre-existing `test_workshop_paid_professional…bounded_paging`.
- For each batch, every contract test that names a changed file was run before and after the change (against a clean worktree of the parent commit). The only differences were the pins listed in §9, and each was updated in the same commit.
- **Acceptance (decision 2): not merged, not run.** `origin/ci/acceptance` has **no green run**. Runs 1–3 failed. Runs 4, 5 and 7 were cancelled while Cursor moved the Mac jobs to the owner's Xcode 27 runner. Run 6 (`ci/baseline-record`) is pending. The workflow triggers on `port/**`, `ui/combined-r7` and `ci/acceptance`, not `restyle/**`. **Nothing in round 2 has been compiled.** The Swift uses only iOS 17 API (`modifyingTraits`, `ControlSize.extraLarge`, `buttonBorderShape`, `presentationDetents`) and existing types.

## 11. Left

1. **System tab bar (spec §3.8)**: `CYNightTabBar` / `QuestifyApp` are untouched. Replacing the root bar changes every tab's chrome and the `rootTabBar.tab.player.N` anchors. It waits on owner Q4 and a green acceptance run, because a compile error there would break the whole app.
2. **Accent asset / contrast token test (spec §2.2 R0)**: there is no `AccentColor` asset yet. The tint is still applied through `CYColor.brand` by the existing chrome. Adding an asset changes `project.pbxproj` resources.
3. **`appNavigationTitle` default `.inline`**: see §7 (R4 5).
4. **When acceptance is green:** merge `ci/acceptance`, run it on this branch, and check the AX3 screenshots for clipped rows (17 pt body) and for any sheet whose content now sets its own detents beside the new outer ones.

DONE-ROUND-2
