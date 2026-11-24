# P4 receipt — game kits

Base: `origin/ui/combined-r6` `f1115875e53a3fbc03969720d44e91f01eeb5ada`.
Source: chengyin-ios `main` `a5c863e38b3c5f80ce1ed3207223278c19062d7f`, plus `fix/games-polish-1121` `8c447a6ead9af33823bc3e51f7be0ef6401b58af`.
Not ported: `feat/pilot-kits-1124`. qx-* branches were not used as input.

## Clusters

- C3. Kept `PlayHelpLadder`. Added wrong-answer reply under the typed answer (`PlayKitWrongReply`, input kept), 「已记录」 for a choice question with no right answer (`PlayKitNoRightAnswer` → story key `playkit.story.recorded`), and `POOL_TRIM` as a requestable ladder layer. The layer is hidden while the gate is off. A successful use does not require hint text; it bumps `poolTrimGeneration` so the host can re-read the trimmed pool. Did not port `PlayHelpContracts`, `PlayHelpService`, or `PlayHelpPanelView`.
- C4 pool. Their hangman is `inputMode: .pool` on the existing Questo hangman (`PlayKitHangmanView`). No second hangman screen and no `PlayKitScreenKind.hangman`. `LetterPoolState` is pure Core, retargeted to `PlayKitHangmanProjection`. Capability keys are one list on `PlayClientCapabilities`, still `platform = "ios-native"`, and `api/play/advanced/start` now sends `supportedCapabilities`. Added `hangman.pool`, `qa.letterPool`, `answer.estimate`, `answer.pricePair`, `answer.hiddenObject`. Did not add `role.views` or `sensor.filter_shot`.
- C12. Kept `CYPlayVerdict` / `CYInPlaceResult` (they live outside these files). Took the stage header model, story-voice copy, per-kit empty states, the fixed-ratio image placeholder, and the number-with-unit formatter. Dropped their `playGamePrimaryButton`; submits stay on `CYPillButton`.
- C7. `howTo` under hangman, TYPE questions, and type-in. Reference image (`referenceImage` / `referenceImageUrl`) with alt text and retry. Stage events `stage_enter`, `hint_open`, `stage_skip`, `stage_issue_report`, `material_view` go through the existing `AnalyticsEventClient`. No new analytics client. `PlayStageAnalyticsGate.enabled` is false, so nothing is sent and the issue menu stays hidden.
- games-polish-1121. Compass needle uses `CYMotion.Duration.quick` (0.20) and still respects Reduce Motion. Image loads use a 4:3 placeholder. Result fade is driven from `PlayKitScreen`. Timed units were already localized in `PlayTimedDisplayLocalization`; that clock was not rewritten. Sensor and walk copy updates are in `docs/port/strings/p4.json` only.

## Files copied

- `Core/LetterPoolState.swift` (adapted types: `PlayKitHangmanProjection`, empty character is `""`)
- `Core/PlayKitWrongReply.swift`
- `Core/PlayGameStage.swift` (stage model copied; stage analytics added here instead of their uploader)
- `App/PlayGameStageViews.swift` (header, result line, image placeholder, howTo, reference, issue menu, match diagram; no primary-button modifier)

## Files adapted

- `Core/PlayKitQuestoContracts.swift` — pool fields, strict `init(validated:)`, pool `validate`
- `Core/PlayKitScreenContracts.swift` — pool hangman and question letter-pool checks, `PlayKitReferenceImage`
- `Core/PlayContentCompatibility.swift` — one capability list, `startFields()`
- `Core/PlayAdvancedRuntime.swift` — `supportedCapabilities` on advanced start
- `Core/PlayHelpLadder.swift` — `POOL_TRIM`, defaulted `poolTrimEnabled: false`
- `App/PlayKitQuestoViews.swift` — pool mode inside the existing hangman, shared letter-pool controls, question letter pool
- `App/PlayKitQuestionForms.swift` — wrong reply, letter pool, branch empty state, hidden-object placeholder, estimate numbers
- `App/PlayKitScreen.swift` — stage header, reference, issue menu, story result, image retry, stage_enter
- `App/PlayKitDecisionProgressViews.swift` — dice and empty-deck empty states
- `App/PlayKitReasoningForms.swift` — match lines above the pickers
- `App/PlayKitTimedChallengeView.swift` — howTo and wrong reply under type-in; invalid config uses `ContentUnavailableView`
- `App/PlayKitSensorChallengeView.swift` — compass motion token
- `App/PlayAdvancedView.swift` — passes the raw hangman segment through
- `App/PlayHelpLadderPanel.swift` — `onPoolTrimmed`, hint_open, stage_skip
- `Tests/CoreTests/PlayFullStoryH3Tests.swift` — the declaration test now expects `answer.estimate`, `hangman.pool`, and `qa.letterPool` (the branch block stays omitted)
- `Tests/CoreTests/PlayHelpLadderTests.swift` — POOL_TRIM and wrong-reply cases

## Tests

- `Tests/CoreTests/HangmanPoolTests.swift`
- `Tests/CoreTests/PlayGameStageTests.swift`
- `Tests/CoreTests/PlayClientCapabilitiesTests.swift` rewritten against this build's list (`ios-native`; `role.views` absent)
- `Tests/CoreTests/Verify1119PlayKitTests.swift` — howTo, reference image, the five stage events. Photo RECORD, completion mode, run start, and quote cases were left out (other packages).
- `Tests/AppUITests/HangmanPoolFlowTests.swift` — `XCTSkip`. The `letterPoolGame` module lives in `ModuleFixtureSupport`, which this package does not own.

## Mount hooks

- `EnvironmentValues.playGameStage`. P2 sets it on the play host. Kits draw `PlayGameStageHeader` only when it is set. `PlayExperienceView` was not edited.
- `PlayHelpLadderPanel.onPoolTrimmed` and `PlayHelpLadderModel.poolTrimGeneration`. P2 passes a reload from `PlayExperienceView` (panel call around the existing `PlayHelpLadderPanel(...)`, model init around `PlayHelpLadderModel(client:store:)`). Both parameters default so that file still compiles. Gate: pass `poolTrimEnabled: true` only when `play.help.poolTrim` is on.
- `PlayHelpLadderPanel.analyticsNodeID` / `analyticsKit`. Defaults nil. P2 fills them when the stage-analytics allow-list is open.
- CastBranchEcho. Not mounted. The type is not on this base. The mount point is the top of `PlayKitQuestionForms.branchForm`, above the branch options. A comment marks it. `JourneyRoleView` and narration / 延伸阅读 were not edited.
- `AnalyticsEventClient.allowedEvents` does not include the five stage names. This package does not edit that client. Calls go through `PlayStageAnalytics.track`, which also returns false while `PlayStageAnalyticsGate.enabled` is false. The integrator adds `stage_enter`, `hint_open`, `stage_skip`, `stage_issue_report`, `material_view` to the allow-list, then P2 turns the gate on.

## Route rows for P2

No new path. Do not edit `ChinaReviewedRouteCapability.swift` from this branch.

| Gate (default off) | Existing route | Note |
| --- | --- | --- |
| `play.help.poolTrim` | `POST /api/play/help/use` (already `.liveInProduction`) | `POOL_TRIM` is a layer type on the current help body, not a new URL. UI hides the row while the gate is off. |
| stage analytics | `POST /api/analytics/events/batch` (already in `playerParityBOwnerGrant`) | No new route. Blocked on the event allow-list inside `AnalyticsEventClient`, not on a route row. |

`api/play/advanced/start` already exists. `supportedCapabilities` is an extra field on that body and is not gated: it describes what this build renders.

## Strings

`docs/port/strings/p4.json` (fragment shape, source keys kept). Includes `PlayGameStageLocalizations` keys, letter-pool / howTo / reference / issue / story copy, `playHelp.type.pool_trim`, and the games-polish sensor and walk copy. `Localizable.xcstrings` was not edited. Timed unit strings stay in `Resources/PlayTimedDisplayLocalization.xcstrings`.

## What this could not do

- This VM has no `swiftc` and no `swift`. Nothing was parsed or tested here.
- Letter-pool UI flow (`letterPoolGame`) cannot be registered without editing `ModuleFixtureSupport`.
- `role.views` is not declared. Journey role cards are P1.
- Narration autoplay and 延伸阅读 were not touched (`JourneyNarrativeView`, `ChapterStoryContracts`).
- `feat/pilot-kits-1124` was not ported.
- Stage events will not leave the device until the allow-list and `PlayStageAnalyticsGate` are opened.
- CastBranchEcho is not on this base, so the branch echo is not mounted.
- `project.pbxproj` and `tools/current_ci_manifest.json` were not edited. New Swift files sit on disk for the integrator's project generation. `Tests/AppUITests/HangmanPoolFlowTests.swift` is outside the SPM `QuestifyCoreTests` target (`Tests/CoreTests`).
