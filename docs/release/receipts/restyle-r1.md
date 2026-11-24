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

## Round 2 (2026-11-24)

- **Merged** `origin/restyle/r6-system-rest` (aa235bbab) first, so R1 now builds on the shared `cySheet`, `cyCard`, `CYContentState` and the re-pointed text styles and radii.
- **`origin/ci/acceptance` not merged:** it has no green run. All three of its runs (45382432691, 45382725772, 45382894882) failed on its own branch: `debug-build` failed, so no AppUnit shard ran, and the `gates` job hit the known ratchet 185 against a baseline of 184. Per coordinator decision (3), nothing was merged and no acceptance run happened on this branch.
- **Ownership audit:** 140 owned `App/` files (12 prefixes, minus the 4 P3 files). Every one was scanned for the brief/spec rules: static fonts, `.system(size:)`, text below `.caption`, off-set literal radii, forced dark, custom back chevrons or hidden bars, title mode unset, sheets without detents, player glass sheets, glass on content, `lineLimit(1)` titles, tertiary small text, unlabelled icon buttons, and destructive actions without confirmation.
  - Across both rounds, R1 has now changed **70** files.
  - The other 70 had no finding after R6's shared components landed. Their states, cards and type come from the re-pointed components.

### Files changed in round 2 (55, in 3 commits ≤ 40 App files each)
- `App/ActivityBrowserView.swift`
- `App/ActivityCoverAuthoringView.swift`
- `App/ActivityDetailView.swift`
- `App/ActivityEditingView.swift`
- `App/ActivityHostCancelView.swift`
- `App/ActivityPresentationComponents.swift`
- `App/ActivityTemplateSelectionView.swift`
- `App/DiscoveryComponents.swift`
- `App/DiscoveryHomeView.swift`
- `App/DiscoveryPlayTemplatePresentationView.swift`
- `App/DiscoveryPresentationScope.swift`
- `App/DiscoveryTemplateBrowserView+Port.swift`
- `App/DiscoveryTemplateBrowserView.swift`
- `App/DiscoveryTemplateDetailParitySections.swift`
- `App/DiscoveryTemplateDetailView.swift`
- `App/HomeFeedView.swift`
- `App/HomeSearchTabParityViews.swift`
- `App/MapCoreEntryHubView.swift`
- `App/MapPublicStoryNodeDetailView.swift`
- `App/OfficialActionViews.swift`
- `App/OfficialEventDetailView.swift`
- `App/OfficialPrivateViews.swift`
- `App/OfficialRouteViews.swift`
- `App/PlayerGapViews.swift`
- `App/PlayerJourneyReadBindings.swift`
- `App/PlayerJourneyViews.swift`
- `App/PlayerParityBViews.swift`
- `App/PublicCatalogViews.swift`
- `App/RegistrationFixtureSupport.swift`
- `App/RegistrationSheetView.swift`
- `App/SearchMapComponents.swift`
- `App/SearchMapExplorerView.swift`
- `App/SearchMapFilterSheet.swift`
- `App/SearchRoutePreviewView.swift`
- `App/SquareBrowserView.swift`
- `App/SquareDetailView.swift`
- `App/SquareFixtureSupport.swift`
- `App/SquareGovernanceViews.swift`
- `App/SquarePostLocalMediaPresentation.swift`
- `App/SquarePostVideoViews.swift`
- `App/SquareReportProgressView.swift`
- `App/SquareReportView.swift`
- `App/SquareWorkspaceView.swift`
- `App/TeamCreateView.swift`
- `App/TeamHomeView.swift`
- `App/TeamOrientBoardView.swift`
- `App/TeamPoolHintSection.swift`
- `App/TeamReformFlowViews.swift`
- `App/TeamReportReasonSheet.swift`
- `App/TeamSeatFactsViews.swift`
- `App/TopicBrowserView.swift`
- `App/TopicLocationTodosSection.swift`
- `App/TopicSelfPlaySheet.swift`
- `App/TopicTemplateUseSection.swift`
- `App/TopicThemeRecordsView.swift`

(First touched in round 2: 16 files. `App/DiscoveryPresentationScope.swift` went back to its base bytes when the local helper was removed.)

### Round 2 before → after
| Before | After | Count |
|---|---|---|
| local `.cyR1Sheet([.large])` / `.cyR1Sheet([.medium, .large])` | shared `.cySheet(detents: [.large])` / `.cySheet()` (R6); helper deleted | 46 sheets |
| `.cyPlayerSheetGlass()` (+ `.cyDomainSheet` / raw detents) on R1 sheets | `.themeDomain(.player)` + `.cySheet(…)`: system sheet background and corners, player tokens kept | 11 |
| report sheet with `.presentationDetents([.large])` only | `.cySheet(detents: [.large])` (drag indicator) | 1 |
| pushed/sheet title with no display mode | `.navigationBarTitleDisplayMode(.inline)` / `cyPageTitle` | 10 |
| `CYHeroHeader("key")` row + `.cyHeroScreen()` (empty bar title) on Form/List pages | the system inline title `cyPageTitle("key")` (or `.navigationTitle(Text(key, tableName:))`); a hero subtitle stays as secondary text | 15 pages in 10 files |
| Square governance in-list 刷新 pill | `.refreshable` with the same `reload()` | 1 |
| sticky CTA on `.ultraThinMaterial` | `.bar` | 1 |
| `.caption2` (tab labels, chevron glyph) | `.caption` | 2 |
| small text (meta/caption/micro/label/bodyCompact) in `textTertiary` | `textSecondary` (spec §2.2, 4.5:1) | 64 |

Kept on purpose: object-name heroes over artwork (official event, public merchant, map nodes, story node with cover, route preview, search map detail); map-floating glass controls and the heart over a card image; white text on hero scrims; `team.refresh` buttons (UI-test anchors, and `.refreshable` already exists); `square.video.remove`, which removes an un-uploaded local attachment, so a confirm is not needed and the UI test taps it directly.

### Contract pins updated (presentation only; coordinator decision 1)
- `test_global_search_category_recovery.py`, `test_reviewed_helper_sheet_services_and_remote_explorer_are_pinned`: SHA-256 re-pinned for `App/SearchMapFilterSheet.swift` and `App/SearchMapExplorerView.swift`. This was also a new failure left by round 1. The historical floors and inverses are untouched.
- `test_global_chrome_domain_contract.py`: `ActivityDetailView` and `RegistrationSheetView` moved out of the "must use `cyPlayerSheetGlass`" list. A new assertion requires them to use `.themeDomain(.player)` and `.cySheet(`, and to have no player glass.
- `test_square_busy_scroll.py`: the expected text now has `.cyPageTitle("squareWorkspace.title")` instead of the hero row and `.cyHeroScreen()`. The busy rule is unchanged: the disabled group is inside the Form, never on the scroll container.
- `test_accessibility_hardening_wave.py` FPA4: ActivityDetail sheets may get detents and the indicator via `cySheet`. The test also asserts that `cySheet` itself applies `.presentationDragIndicator(.visible)`.

### Round 2 verification (no Swift compiler here)
- `tools/contract_ratchet.py --check` on b2f5502ca: **185 failing, baseline 184, new 1, fixed 0**. The one new failure is the known pre-existing `test_workshop_paid_professional…bounded_paging`, the same as `ui/combined-r6` and R6.
- `check_typography_lint.py` PASS (raw text style 33, Theme.Font 40, raw size 53, back chevron 10, hidden back 3, large title 7). `check_design_lint.py` PASS. `check_scaffold.py` PASS.
- Swift tests that read the changed sources as text (`OfficialActionPresentationModelTests`, `OfficialSourceInvalidationViewTests`, `OPTTriageClosureTests`, `OwnerDecisionGuardTests`, `ConditionPackageClosureTests`, `FreeExploreBundlePageReadyTests`, `MiniProgram99PageParityRegistryTests`): their asserted strings were checked by hand and are still present.
- UI tests were checked for the removed hero title texts. Only "Review" matches, and that is an unrelated social sheet nav bar.
- The acceptance routes in `docs/port/accept/r1.txt` are unchanged (20).

## Left
- **Compile and screenshots:** nothing has been compiled. `acceptance.yml` exists only on `ci/acceptance` and is not green there yet. Merge it once it is green, then iterate on this branch.
- **Component gates (R6 / owner):**
  - the `CYPillButton` / named button styles re-point to the system styles (request 1);
  - the colour re-point (request 5);
  - the system tab bar (`HomeSearchTabParityViews`' custom role tab bar is R1 chrome, but it waits on the spec §3.8 / owner Q4).
- **Search empties:** they keep their MP copy and identifiers through `CYEmptyState` (now `ContentUnavailableView`) rather than `ContentUnavailableView.search`.

DONE-ROUND-2
