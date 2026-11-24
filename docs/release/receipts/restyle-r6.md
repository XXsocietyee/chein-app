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

## 4. Component requests and items left (for the coordinator / R0 owner)

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
