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

## Left
- Acceptance run + screenshot check against the MP once the workflow lands.
- Sheet kinds that should be `[.medium, .large]` (pickers/filters) per spec §3.4: kept at `[.large]` for now to avoid behaviour change; revisit with screenshots.
- `RoamFinishReportView` keeps its in-content ✕ (full-bleed report); revisit if the owner wants the system bar there.
