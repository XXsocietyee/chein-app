# Restyle R1: player front (native iOS style)

- **Branch:** `restyle/r1-player-front`, based on `origin/ui/combined-r6` (f1115875e).
- **Brief:** `design/handoff-r2:docs/briefs/restyle-native-r1.md`. `origin/design/native-ios-r1` (087b3a9ad, DRAFT spec) landed during the run. It was read before the last commits, and the work was aligned with it where it is more specific: radius snapping, the `micro` token, label contrast, and leaving button styles to the R0 re-point.
- **Scope:** visual and structural only. No contract, request, state, navigation target or copy changed. No port-owned file (plan §4: `TopicDetailView`, `TopicXcxSections`, `TopicReviewsContent`, `TopicChapterCardsSection`) and nothing under `App/DesignSystem` was touched. No new files in `App/` (no pbxproj change). No new strings.

## Files changed (55)
- `App/ActivityDetailView.swift`
- `App/ActivityPresentationComponents.swift`
- `App/ActivityPublishingWizardView.swift`
- `App/ActivityTemplateSelectionView.swift`
- `App/DiscoveryHomeView.swift`
- `App/DiscoveryPresentationScope.swift`
- `App/DiscoveryTemplateBrowserView+Port.swift`
- `App/DiscoveryTemplateBrowserView.swift`
- `App/DiscoveryTemplateDetailParitySections.swift`
- `App/HomeFeedView.swift`
- `App/HomeSearchTabParityViews.swift`
- `App/MapCoreEntryHubView.swift`
- `App/MapPublicLayerSectionView.swift`
- `App/MapPublicStoryNodeDetailView.swift`
- `App/MapVisualLayerControlSectionView.swift`
- `App/OfficialActionFixtureHost.swift`
- `App/OfficialActionViews.swift`
- `App/OfficialRouteViews.swift`
- `App/PlayerGapViews.swift`
- `App/PlayerJourneyReadBindings.swift`
- `App/PlayerJourneyViews.swift`
- `App/PlayerParityBViews.swift`
- `App/PublicCatalogViews.swift`
- `App/PublicMerchantFeaturedCard.swift`
- `App/PublicMerchantHomeFixtureView.swift`
- `App/PublicMerchantHomeView.swift`
- `App/RegistrationFixtureSupport.swift`
- `App/RegistrationSheetView.swift`
- `App/SearchMapCanvas.swift`
- `App/SearchMapExplorerView.swift`
- `App/SearchMapFilterSheet.swift`
- `App/SearchMapResultsCapsule.swift`
- `App/SearchRoutePreviewView.swift`
- `App/SquareBrowserView.swift`
- `App/SquareCloudComposerView.swift`
- `App/SquareCloudFeedViews.swift`
- `App/SquareDetailView.swift`
- `App/SquareGovernanceViews.swift`
- `App/SquarePostLocalMediaPresentation.swift`
- `App/SquareReportProgressView.swift`
- `App/SquareReportView.swift`
- `App/SquareWorkspaceView.swift`
- `App/SquareXcxPostCard.swift`
- `App/TeamComponents.swift`
- `App/TeamCreateView.swift`
- `App/TeamHomeView.swift`
- `App/TeamMeetingHandshakeSectionView.swift`
- `App/TeamOrientBoardView.swift`
- `App/TeamPoolHintSection.swift`
- `App/TeamReportReasonSheet.swift`
- `App/TeamSeatFactsViews.swift`
- `App/TopicCreatorToolsView.swift`
- `App/TopicLocationTodosSection.swift`
- `App/TopicPublicationViews.swift`
- `App/TopicSelfPlaySheet.swift`

## Before → after patterns
| Before | After | Where |
|---|---|---|
| `.font(CYTypography.x)`, `.font(c ? CYTypography.a : CYTypography.b)`, `.font(CYTypography.body.weight(...))` | `.cyText(.x)`, `.cyText(c ? .a : .b)`, `.cyText(.body, weight: ...)`; tabular numbers via `monospacedDigit:` | 30 call sites |
| `.font(.caption2.monospaced())` (text below `.caption`) | `.font(.caption.monospaced())` | 3 call sites. `.cyText(.micro)` / `.cyText(.caption)` stay; spec §2.1 re-points those tokens to `.caption` in R0 |
| `.lineLimit(1)` on titles (todo row title, orient-board task title) | `.lineLimit(2)` | 2 |
| Literal radii 10 / 14 / 18 | snapped per spec §2.3: 10 → 8 (inner), 14 → 12 (card), 18 → 20 (hero); 8 kept | 11 |
| Square cloud composer and feed: forced `.preferredColorScheme(.dark)` with `CYNight.ink0/1/2` grounds and `.white` text | semantic colours that render in both appearances (spec §3.9 option A: the role theme decides the appearance): `CYColor.bgPage / bgSurface / bgSurfaceSubtle`, `.primary / .secondary` labels (no `.tertiary` on small text), lantern text → `.orange` | 2 files |
| Detail/sheet `.navigationTitle` without a display mode | `.navigationBarTitleDisplayMode(.inline)` (tab roots already `.large`) | 11 |
| `.sheet { content }` without detents | `.cyR1Sheet(...)`: `.presentationDetents` + `.presentationDragIndicator(.visible)`; `[.medium, .large]` for review/confirm/picker/share sheets, `[.large]` for full flows (login, composer, browser). Sheets whose content already sets detents (CYSheet, `citySheet`, `CYSquareShareSheet`, `CYSquareActivityPicker`, `CYSquarePostDraftsSheet`, `ParticipationHistoryView`) are untouched | 46 sheets |
| 移除已保存的目的地: immediate remove | `Button(role: .destructive)` + `confirmationDialog` (same action on confirm) | `SearchRoutePreviewView` |

The helper `cyR1Sheet` lives in `App/DiscoveryPresentationScope.swift` (an R1 file) so no new file is needed.

## Screens for acceptance
`docs/port/accept/r1.txt` (20 design-fixture routes): home (+offline), discovery, topics, activities, activity detail, registration, official (+empty), square (+empty, posts, delete), search results, search map (+failed), team, team report, public merchant home, team pool.

## Local verification (no Swift compiler in the cloud session)
- `tools/check_typography_lint.py`: PASS, same counts as the base (raw text style 1143, raw size 67, back chevron 10).
- `tools/check_scaffold.py`: PASS.
- The 116 Python contract checks that reference a changed file or a button style: same result as the base (5 pre-existing failures, 0 new: `check_public_merchant_home`, `test_category_roam_registration`, `test_global_search_category_recovery`, `test_merchant_project_workspace_entry`, `test_social_guide_templates`). A first pass added `Color(uiColor:)` calls, which tripped the raw-colour ratchet in `test_design_system_component_contracts`; they were replaced with `CYColor` tokens and it now passes.
- Swift tests that read the changed sources (`OfficialActionPresentationModelTests`, `OfficialSourceInvalidationViewTests`, owner-decision and closure tests): asserted strings checked by hand. None was changed.
- **Cloud acceptance:** `.github/workflows/acceptance.yml` did not exist on the base or in this run, so no acceptance run has happened. The compile and screenshots are still open. Re-run when Cursor lands the workflow.

## Component requests (for R6/R0, `App/DesignSystem`)
1. **Buttons:** R1 call sites were converted to `.borderedProminent` / `.bordered` and then reverted, because a raw `.borderedProminent` under the near-white player tint draws white text on a white fill (spec §2.2 gotcha). R1 relies on the R0 re-point of `CYPillButtonStyle` (spec §3.6). Please re-point the named styles too: `.cyPrimary`, `.cySecondary`, `.questifyPrimary`, `.cyDestructive`, `.editorSecondary`, `CYPrimary/Secondary/Ghost/DestructiveButtonStyle` and their `fullWidth` variants (about 100 R1 uses).
2. **`CYTextStyle` tokens:** `.caption` and `.micro` → `.caption` (spec §2.1). R1 left about 70 call sites on those tokens.
3. **`CYHeroHeader`** repeats the navigation title on about 25 R1 pages (Official actions, Square governance, report, workspace, Map hub, Team create/reform). Please make it a quiet header, or confirm that R1 should drop it for `.navigationTitle`. Accessibility identifiers such as `mapPublicLayers.storyNode.title` hang on it.
4. **States:** `CYEmptyState` / `CYErrorState` / `CYLoadingStateView` (62 R1 uses). R1 relies on the R0 `CYContentState` / `ContentUnavailableView` move (spec §3.5).
5. **Colours:** system grouped-background tokens. The raw-colour ratchet forbids `Color(uiColor:)` outside DesignSystem, so R1 used `CYColor.bgPage / bgSurface / bgSurfaceSubtle` and relies on spec §2.2 re-pointing them.
6. **Sheets:** `cyPlayerSheetGlass()` still wraps the Square sheet in `SessionHomeFeedView` (not R1). R1 sheets use the local `cyR1Sheet` helper. Once the R0 `cySheet` lands, `cyR1Sheet` can become a call to it, or be deleted.

## Left
- Button styles (request 1) and the in-content `CYHeroHeader`s (request 3).
- Structural List/Form conversions of custom-stack pages, `.refreshable` instead of 刷新 buttons, and toolbar `Menu` merges (spec §3.1–3.2). These go to a follow-up R1 batch once R0 lands, so they build on the new `cyCard`, `CYContentState` and `cySheet`.
- `HomeSearchTabParityViews`' custom role tab bar keeps its `.caption2` tab labels. They match the system tab bar's label size.
- Text shadows over hero artwork in `HomeSearchTabParityViews` (legibility on images) and the floating publish button's shadow are kept.
- The Square cloud route map keeps its indigo/ember art, because it is visual content.
- Compile check and acceptance screenshots: waiting for `acceptance.yml`.
