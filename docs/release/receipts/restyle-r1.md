# Restyle R1: player front (native iOS style)

- **Branch:** `restyle/r1-player-front`, based on `origin/ui/combined-r6` (f1115875e).
- **Brief:** `design/handoff-r2:docs/briefs/restyle-native-r1.md`. `origin/design/native-ios-r1` did not exist during this run, so the brief and the port-packages native rule were the spec.
- **Scope:** visual and structural only. No contract, request, state, navigation target or copy changed. No port-owned file (plan §4: `TopicDetailView`, `TopicXcxSections`, `TopicReviewsContent`, `TopicChapterCardsSection`) and nothing under `App/DesignSystem` was touched. No new files in `App/` (no pbxproj change). No new strings.

## Files changed (63)
- `App/ActivityCoverAuthoringView.swift`
- `App/ActivityDetailView.swift`
- `App/ActivityPresentationComponents.swift`
- `App/ActivityPublishingWizardView.swift`
- `App/ActivityTemplateSelectionView.swift`
- `App/DiscoveryHomeView.swift`
- `App/DiscoveryPresentationScope.swift`
- `App/DiscoveryTemplateBrowserView+Port.swift`
- `App/DiscoveryTemplateBrowserView.swift`
- `App/DiscoveryTemplateDetailParitySections.swift`
- `App/DiscoveryTemplateDetailView.swift`
- `App/HomeCityLocationConsentCard.swift`
- `App/HomeFeedView.swift`
- `App/HomeReturnAndCityDeltaSectionView.swift`
- `App/HomeSearchTabParityViews.swift`
- `App/MapCoreEntryHubView.swift`
- `App/MapPublicLayerSectionView.swift`
- `App/MapPublicStoryNodeDetailView.swift`
- `App/MapVisualLayerControlSectionView.swift`
- `App/OfficialActionFixtureHost.swift`
- `App/OfficialActionViews.swift`
- `App/OfficialEventDetailView.swift`
- `App/OfficialOrganizerConsoleView.swift`
- `App/OfficialRouteViews.swift`
- `App/PlayerGapViews.swift`
- `App/PlayerJourneyReadBindings.swift`
- `App/PlayerJourneyViews.swift`
- `App/PlayerParityBViews.swift`
- `App/PublicCatalogViews.swift`
- `App/PublicMerchantFeaturedCard.swift`
- `App/PublicMerchantHomeFixtureView.swift`
- `App/PublicMerchantHomeView.swift`
- `App/PublicMerchantReviewEditor.swift`
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
- `App/TopicTemplateUseSection.swift`

## Before → after patterns
| Before | After | Where |
|---|---|---|
| `.font(CYTypography.x)`, `.font(c ? CYTypography.a : CYTypography.b)`, `.font(CYTypography.body.weight(...))` | `.cyText(.x)`, `.cyText(c ? .a : .b)`, `.cyText(.body, weight: ...)`; tabular numbers via `monospacedDigit:` | 30 call sites |
| `.cyText(.micro)`, `.font(.caption2.monospaced())` (text below `.caption`) | `.cyText(.meta)` (`.caption`), `.font(.caption.monospaced())` | 14 call sites |
| `.lineLimit(1)` on titles (todo row title, orient-board task title) | `.lineLimit(2)` | 2 |
| Card/tile radii 8 / 10 / 14 / 18 | 12 | 15 |
| Square cloud composer and feed: forced `.preferredColorScheme(.dark)` with `CYNight.ink0/1/2` grounds and `.white` text | follows system light/dark: `CYColor.bgPage / bgSurface / bgSurfaceSubtle`, `.primary / .secondary / .tertiary` labels, lantern text → `.orange` | 2 files |
| Detail/sheet `.navigationTitle` without a display mode | `.navigationBarTitleDisplayMode(.inline)` (tab roots already `.large`) | 11 |
| `.sheet { content }` without detents | `.cyR1Sheet(...)`: `.presentationDetents` + `.presentationDragIndicator(.visible)`; `[.medium, .large]` for review/confirm/picker/share sheets, `[.large]` for full flows (login, composer, browser). Sheets whose content already sets detents (CYSheet, `citySheet`, `CYSquareShareSheet`, `CYSquareActivityPicker`, `CYSquarePostDraftsSheet`, `ParticipationHistoryView`) are untouched | 47 sheets |
| `.cyPrimary`, `.questifyPrimary`, `CYPillButtonStyle()` / `(.primary)` | `.borderedProminent` | non-full-width only |
| `.cySecondary`, `.editorSecondary`, `CYPillButtonStyle(.secondary)` / `.cyDestructive` | `.bordered` (destructive keeps `role: .destructive`) | |
| `CYPillButtonStyle(.tertiary)` | `.borderless` | |
| 移除已保存的目的地: immediate remove | `Button(role: .destructive)` + `confirmationDialog` (same action on confirm) | `SearchRoutePreviewView` |

The helper `cyR1Sheet` lives in `App/DiscoveryPresentationScope.swift` (an R1 file) so no new file is needed.

## Screens for acceptance
`docs/port/accept/r1.txt` (20 design-fixture routes): home (+offline), discovery, topics, activities, activity detail, registration, official (+empty), square (+empty, posts, delete), search results, search map (+failed), team, team report, public merchant home, team pool.

## Local verification (no Swift compiler in the cloud session)
- `tools/check_typography_lint.py`: PASS, same counts as the base (raw text style 1143, raw size 67, back chevron 10).
- `tools/check_scaffold.py`: PASS.
- The 116 Python contract checks that reference a changed file or a replaced button style: same result as the base (5 pre-existing failures, 0 new). A first pass added `Color(uiColor:)` calls, which tripped the raw-colour ratchet in `test_design_system_component_contracts`; they were replaced with `CYColor` tokens and it now passes.
- Swift tests that read the changed sources (`OfficialActionPresentationModelTests`, `OfficialSourceInvalidationViewTests`, owner-decision and closure tests): asserted strings checked by hand. None was changed.
- **Cloud acceptance:** `.github/workflows/acceptance.yml` did not exist on the base or in this run, so no acceptance run has happened. The compile and screenshots are still open. Re-run when Cursor lands the workflow.

## Component requests (for R6, `App/DesignSystem`)
1. Map `CYTextStyle.caption` (now `.caption2`, 11 pt) to `.caption`. R1 has about 60 `.cyText(.caption)` uses left as they are, so the rule "nothing below `.caption`" depends on that token.
2. Full-width system button: `.cyPrimary(fullWidth: true)`, `.cySecondary(fullWidth: true)`, `CYPillButtonStyle(..., fullWidth: true)`, `CYPrimary/Secondary/Ghost/DestructiveButtonStyle(isFullWidth: true)` are still used in R1. A native `.borderedProminent` + `.controlSize(.large)` full-width variant inside those styles would convert all of them at once.
3. `CYHeroHeader` repeats the navigation title on about 25 R1 pages. Please make it a quiet large-title-like header, or say if R1 should drop it in favour of `.navigationTitle` with `.large`. Accessibility identifiers such as `mapPublicLayers.storyNode.title` hang on it.
4. `CYEmptyState` / `CYErrorState` / `CYLoadingStateView` (62 R1 uses): R1 relies on the R6 move to `ContentUnavailableView` with a retry `Button`.
5. System grouped-background tokens (for example `CYColor.groupedBackground` → `.systemGroupedBackground`). The raw-colour ratchet forbids `Color(uiColor:)` outside DesignSystem.

## Left
- Full-width custom button styles (see request 2), `CYPillButton` component call sites, and the in-content `CYHeroHeader`s (request 3).
- `HomeSearchTabParityViews`' custom role tab bar keeps its `.caption2` tab labels. They match the system tab bar's label size.
- Text shadows over hero artwork in `HomeSearchTabParityViews` (legibility on images) and the floating publish button's shadow are kept.
- The Square cloud route map keeps its indigo/ember art, because it is visual content.
- Compile check and acceptance screenshots: waiting for `acceptance.yml`.
