# Restyle R5: play, roam & city (non-port files): receipt

- Branch: `restyle/r5-play-roam-city`, based on `origin/ui/combined-r6` (f1115875e).
- Brief: `design/handoff-r2:docs/briefs/restyle-native-r1.md`; spec: `design/native-ios-r1:docs/design/native-ios-r1.md` (read before the last commit; it overrides the brief where more specific).
- Scope: 197 owned files (`Roam*`, `City*`, `CityKit/`, `Free*`, `Play*`, `Journey*`, `Guest*`), minus every file plan §4 gives to P1 (`JourneyRoleViewSection`, `JourneyNarrativeView`), P2 (`PlayExperienceView`, `PlayExperienceView+Port`, `FreeExplorationViews`, `PlayNodeDetailView`, `PlayThemePresentation`) and P4 (`PlayKitScreen`, `PlayKit{Question,Reasoning,Personal}Forms`, `PlayKitDecisionProgressViews`, `PlayKitTimedChallengeView`, `PlayKitSensorChallengeView`, `PlayKitLegacyViews`, `PlayKitQuestoViews`, `PlayAdvancedView`, `PlayCompareView`, `PlayHelpLadderPanel`), and minus `Player*` (R1's prefix). No `App/DesignSystem`, App, strings, pbxproj or manifest edits.

## Before → after
| pattern | before | after | sites |
|---|---|---|---:|
| static type on text | `.font(CYTypography.x)` (fixed size unless the token has a native style) | `.cyText(.x)` (Dynamic Type via `@ScaledMetric`), weight folded into `weight:`; `CYTypography.caption.monospaced()` → `.cyText(.caption).monospaced()` | 21 |
| text below the floor | `.font(.system(.caption2, design: .monospaced))` | `.caption` | 1 |
| pushed-page title mode | `.navigationTitle(…)` with the mode unset (inherits large) | `+ .navigationBarTitleDisplayMode(.inline)` (City arrival evidence ×2, snapshot, merchant ops, merchant value, neutral task ×2, onsite task ×2) | 9 |
| large title on pushed pages | `CityBoardView`, `CityMyPropertiesView` `.large` | `.inline` (both are pushed from the roam map root); lint "large title" 7 → 5 | 2 |
| card radius | 16 / 14 on content cards (City deed compact + rows, board menu rows, roam audit section, passport track) | 12 (`CYRadius.card`) | 8 |
| heavy shadows | roam home cards r10 @25 %, album photo r16 | r4 @12 %, r6 @50 % of overlay | 2 |
| sheets | plain `.sheet { … }` with no detents | `Group { … }.presentationDetents([.large]).presentationDragIndicator(.visible)` (height unchanged). Skipped: share / camera / picker sheets, `cyDomainSheet` users, and views that set their own detents | 24 |
| destructive without confirm | 隐藏这张印章 hid the received stamp at once (permanent) | `confirmationDialog` with the existing `roam.stamp.hide` / `.footer` strings | 1 |

- Reverted during the run: a `.cyText(.caption/.micro)` → `.meta/.label` lift (126 sites). Spec §2.1 keeps `caption` as the `.caption` floor and fixes `micro` centrally in R0, so it is not done per call site.
- Kept on purpose (spec §3.10, exempt surfaces): hidden nav bars on the roam/city map roots, live roam session and the roam finish report (full-bleed visual); map/camera glass overlays with Reduce Transparency fallbacks; `CityPropertySheet` custom detents/background; dice/pin shadows; `lineLimit(1)` on chips, pills, numeric values and the one-line arm of `ViewThatFits` (the wrapping arm already exists).

## Files changed
     App/CityAcquisitionView.swift                 |  2 +-
     App/CityArrivalEvidenceView.swift             |  8 ++++----
     App/CityCurrentSnapshotView.swift             |  2 +-
     App/CityKit/CityBoardScreens.swift            |  8 ++++----
     App/CityKit/CityDeedCard.swift                | 10 +++++-----
     App/CityKit/CityRoamRootView.swift            |  2 +-
     App/CityMerchantOperationsView.swift          |  2 +-
     App/CityMerchantValueView.swift               |  6 +++---
     App/CityNeutralTaskView.swift                 |  8 ++++----
     App/CityOnsiteTaskView.swift                  |  8 ++++----
     App/CityPlayerValuePanel.swift                |  4 ++--
     App/CityPlayerView.swift                      |  4 ++--
     App/JourneyLandingViews.swift                 |  2 +-
     App/JourneyReportViews.swift                  |  6 +++---
     App/PlayAdvancedTeamViews.swift               |  4 ++--
     App/PlayAnswerReview.swift                    |  4 ++--
     App/PlayCreatorTailViews.swift                |  6 +++---
     App/PlayHUD.swift                             |  2 +-
     App/PlayInPlayTools.swift                     |  2 +-
     App/PlayJourneyContentViews.swift             |  6 +++---
     App/PlayKitAlbumView.swift                    |  2 +-
     App/PlayRPGComponents.swift                   |  4 ++--
     App/PlayRecoveryViews.swift                   | 10 +++++-----
     App/PlayRuntimeGapViews.swift                 |  2 +-
     App/PlayTaskSummaryView.swift                 |  4 ++--
     App/PlayThemeRecordsView.swift                |  4 ++--
     App/RoamAndExplorationParitySectionView.swift |  2 +-
     App/RoamBrowserView.swift                     |  4 ++--
     App/RoamHomeTabsView.swift                    |  4 ++--
     App/RoamLiveSessionView.swift                 | 10 +++++-----
     App/RoamNearbyParityExtras.swift              |  4 ++--
     App/RoamPOIActions.swift                      |  4 ++--
     App/RoamPassportHistoryView.swift             |  6 +++---
     App/RoamPassportToolsViews.swift              |  6 +++---
     App/RoamReceivedStampMetadataView.swift       |  7 ++++++-
     App/RoamStampCameraView.swift                 |  4 ++--
     App/RoamStampViews.swift                      |  6 +++---
     37 files changed, 92 insertions(+), 87 deletions(-)

## Verification (cloud, no Mac)
- `.github/workflows/acceptance.yml` is not on combined-r6 yet, so the acceptance run has not happened. No compiler in the cloud; every edit reuses existing API (`cyText`, `presentationDetents`, `confirmationDialog`, iOS 17 target).
- `python3 -m unittest discover -s Tests/ContractChecks`: 6,064 tests, failures 85 + errors 100 both before and after. **0 new failures** (sorted failure lists compared).
- `tools/check_typography_lint.py`: PASS (large title 7 → 5; nothing increased).

## Screens for acceptance
`docs/port/accept/r5.txt` (19 `--design-fixture` IDs): City board / empty / mine / ledger / home rail / live-on-map / property open + mine / claim / challenge / notice, the E2 city screen, roam go / walking / paused / half sheet / reveal, the roam-finish popup and the plan-fallback close sheet.

## Component requests (R6 / R0)
1. `cyPrimary`, `questifyPrimary`, `CYPrimaryButtonStyle`, `CYSecondaryButtonStyle`, `CYPillButtonStyle`, `CYDestructiveButtonStyle` → system `.borderedProminent` / `.bordered` / `.borderless` (spec §3.6). R5 has ~40 call sites; switching them per call site would lose full-width/loading, so they stay on the wrappers.
2. `cyDomainSheet`: `.presentationDragIndicator(.visible)`, no corner radius or glass (spec §3.4). Then R5's `[.large]` wrappers can become `cySheet`.
3. `CYEmptyState` / `CYErrorState` → `ContentUnavailableView` (spec §3.5). R5 has ~117 call sites that will follow automatically.
4. `CYTypography` statics on icons (`JourneyLandingViews`, `JourneyReportViews`, `JourneyFeedbackSheet`, `CityTerritoryNoticeCard`, `PlayInPlayTools`) are icon sizing; left until R0 re-points the tokens.

## Round 2 (2026-11-24)
- Merged `origin/restyle/r6-system-rest` (aa235bbab) first; clean merge.
- `origin/ci/acceptance`: **not merged**. It has no green run (runs 1–3 all fail: the debug build fails on the base and the contract ratchet already reports 1 new failure, `test_workshop_paid_professional…bounded_paging`, outside R5). Coordinator rule (3) only merges it once green.
- Every one of the 197 owned files was scanned against the brief/spec checklist (title mode, sheet chrome, static type, sub-caption text, card radius, shadows, glass on content, custom back, destructive confirm, state views, toggles). After this round all non-exempt hits are 0; 53 owned files are changed across both rounds, the other 144 already passed the checklist (they route through `cyText` / `CYColor` / `CYRadius` / `CYEmptyState`, which R6 re-pointed centrally).

| pattern | before | after | sites |
|---|---|---|---:|
| sheet chrome | R5's own `.presentationDetents([.large]).presentationDragIndicator(.visible)` wrappers, `[.medium, .large]` with or without the indicator, bare `[.medium]` | R6's `cySheet(detents:)` (system detents, visible indicator, role appearance) | 24 + 7 + 5 |
| share sheets without detents | roam finish / history share and medal share `NavigationStack` sheets | `Group { … }.cySheet(detents: [.large])` | 3 |
| custom sheet header | `CYSheetHeader` in `safeAreaInset` + `.toolbar(.hidden, for: .navigationBar)` (roam event card, live rules, check-in) | system `.navigationTitle` + `.inline` + one `xmark` cancellation item (`roam.home.sheet.close` kept) | 3 |
| title mode unset | city rent ledger, bundle review, journey check fixture, play OS, POI fixture, roam session | `+ .navigationBarTitleDisplayMode(.inline)`; owned files now have 0 unset | 6 |
| state view | `PlayIssueView` = `CYEmptyState` + extra text + `CYPillButton` in a VStack | one `ContentUnavailableView` (label, description, `.bordered` capsule retry, 44 pt, `play.retry` kept) | 1 |
| toggles | default tint (near-white accent reads as off on black) | `.tint(.green)` (spec §2.2) | 8 |
| sheet corner | `CitySheetHost` `.presentationCornerRadius(28)` | system corners | 1 |
| static type | `CYTypography.dataXL.italic()` on the roam finish stat | `.cyText(.dataXL).italic()` | 1 |

Round 2 files (2 commits, 41 files): CityAcquisitionView, CityArrivalEvidenceView, CityKit/{CityBoardScreens, CityPropertySheet}, CityMerchantValueView, CityNeutralTaskView, CityOnsiteTaskView, CityPlayerValuePanel, CityPlayerView, FreeExploreBundleLaunchView, JourneyContentFixtureSupport, JourneyFeedbackSheet, JourneyLandingViews, JourneyReportViews, PlayAdvancedTeamViews, PlayAnswerReview, PlayComponents, PlayCreatorTailViews, PlayDirectorView, PlayInPlayTools, PlayJourneyContentViews, PlayPreferenceViews, PlayRPGComponents, PlaySharedPlanLifecycleView, PlayTaskSummaryView, PlayTeamBackpackView, PlayThemeRecordsView, RoamBrowserView, RoamExperienceHubView, RoamFinishReportView, RoamHistoryShareView, RoamHistoryViews, RoamHomeTabsView, RoamLiveSessionView, RoamPOIActions, RoamPassportHistoryView, RoamPassportToolsViews, RoamPosterScanView, RoamStampCameraView, RoamSubpageFixtureSupport, RoamSubpageParityViews.

Contract pins updated: **none needed**. Full `python3 -m unittest discover -s Tests/ContractChecks` after the r6 merge: 186 failures+errors before and after, identical sorted lists (0 new). `tools/check_typography_lint.py`: PASS.

Component requests, status after R6:
1. Button wrappers → system styles: still open (R6 receipt §4.2 gates it on the colour tests).
2. `cyDomainSheet` drag indicator / `cySheet`: **done by R6**; R5 adopted `cySheet`.
3. `CYEmptyState` / `CYErrorState` → `ContentUnavailableView`: **done by R6** centrally (covers R5's ~117 sites).
4. `cyPlayerSheetGlass()` (6 R5 sites) still sets a 24 pt corner and glass background; spec §3.4 retires it, but `test_global_chrome_domain_contract` pins it on `JourneyLandingViews` / `PlayStoreDayMerchantView`. Re-point it centrally in `App/Theme/RoleTheme.swift` (R6) to `.themeDomain(.player)` only.
5. `CYTypography` statics on SF Symbol icons (5 files): icon sizing; leave until R0 re-points the tokens.

## Left
- Acceptance run once `ci/acceptance` is green and merged; then screenshots against the MP for `docs/port/accept/r5.txt`.
- Pickers/filters that should be `[.medium, .large]` per spec §3.4 are still `[.large]` (no behaviour change without screenshots).
- In-page reload buttons on error states (CityFairness, CityActionBudget, CityAcquisition, Play refresh…) stay: they are the retry of an error state, not a toolbar 刷新, and removing them would change behaviour.
- Exempt on purpose (spec §3.10): map/live/finish-report hidden bars, map and camera glass with Reduce Transparency fallbacks, dice/pin/moment shadows, the City moment stamp (radius 14), the property sheet's custom detents and material.

DONE-ROUND-2
