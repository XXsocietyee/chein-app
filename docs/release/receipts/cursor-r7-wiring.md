# cursor/r7-wiring

Base: `cursor/r7-gates` `0777d2a007f7c063f4983ea1a37b342e11b381f4`
(`ui/combined-r7` `7fdfad1f177f` plus the accepted C6 gate fix).

Read before editing: `port-p1.md` (`d6967a989c6d`), `port-p2.md` (`70b89a0eeb06`), `port-p4.md` (`d18f6f1502c0`). `docs/briefs/port-packages-r1.md` and `docs/port/ios-port-plan.md` are not on this commit.

This VM has no `swiftc` or `xcodebuild`. This receipt does not claim a parse.

Every new gate below stays at its default `false`. Nothing here flips a production session.

## Cast

`PlayExperienceCoordinator` had no existing cast call, and it drops the nodes document after `load()`. The mount cannot see `castConfig` without a place to keep it. The added surface is only:

- `PlayExperienceDocument.castPayload` — `CastRuntimeFacts.payload(from:)` (`castConfig`, `playerProfile`, `trust`, `routeState`, `state`, `endingFor`, `endingCount`).
- `PlayExperienceCoordinator.castPayload` — set with the snapshot, cleared wherever the snapshot is cleared.
- `PlayExperienceCoordinator.makeCastCoordinator()` — `CastService(..., enabled: [])`. Profile, voice, and branch writes do not send.

| Mount | File | What it does |
|---|---|---|
| `CastCoordinator.adopt(raw:topicID:runID:)` | `App/PlayExperienceView.swift` | Called with `model.castPayload`, the route topic id, and the run session id. |
| `CastOpeningFlow` | `App/PlayExperienceView.swift` | Full-screen cover while `CastOpeningFlow.step` is non-nil (active run, no station done, playbill not seen). `save` calls `saveProfile`, which returns before the network while `.castProfile` is off. |
| `CastRosterButton` | `App/PlayExperienceView.swift` | Trailing toolbar item when a config exists. Reopens `CastPlaybillView`. |
| `CastEndingSection` | `App/PlayExperienceView.swift` | Sibling of the existing ending section, from `CastEndingResult(raw: model.castPayload)`. |
| `CastEndingSection` | `App/FreeExplorationViews.swift` | Same result, under the free-exploration ending text. Passed from `PlayExperienceView`. |
| `ChapterStoryView.castModel` | `App/PlayExperienceView.swift` | Both story screens (orientation list and free-exploration store) pass the adopted model. The parameter still defaults to nil. |
| `NarrationAutoplayToggle` | `App/ChapterStoryView.swift` | Already shown in `audioSelection` when the chapter is visible. Not changed. Playback is not started. |
| `TopicCastRow` | `App/TopicDetailView.swift` | `Section("topic.cast")` when `TopicDetail.castConfig` is non-empty. |
| `TopicDetail.castConfig` | `Core/TopicContracts.swift` | `CastConfig(raw:)` from the topic column. Missing or null stays nil. |
| `CastBranchEchoLabel` | `App/PlayKitQuestionForms.swift` | First row of `branchForm`, above the options. Config comes from `\.questifyCast`, set on the play host and on `ChapterStoryView`. No config draws no remembered names. |

## P4

| Mount | File | What it does |
|---|---|---|
| `PlayGameStage` / `PlayGameStageHeader` | `App/PlayExperienceView.swift` (`PlayExperienceNodeView`) | `.environment(\.playGameStage, PlayGameStage.resolve(...))` on the station. Kits that already read the environment draw the header. |
| `PlayGameStage` | `App/ChapterStoryView.swift` | Same environment on the story screen, so an inline kit sees the station. |
| `onPoolTrimmed` | `App/PlayExperienceView.swift` | The hint sheet calls `advanced?.refreshAuthoritative()`. `PlayHelpLadderModel` is still created without `poolTrimEnabled`, so the default `false` stands and `POOL_TRIM` stays hidden. |
| `letterPoolGame` | `App/ModuleFixtureSupport.swift` | `ModuleFixture.letterPoolGame` shows `PlayKitHangmanView` with the pool segment from `HangmanPoolTests`. |
| Skip text | `Tests/AppUITests/HangmanPoolFlowTests.swift` | Still skips. The host is registered; this package does not launch it. |

`PlayStageAnalyticsGate.enabled` is still `false`. `analyticsNodeID` and `analyticsKit` stay nil. `stage_enter`, `hint_open`, `stage_skip`, `stage_issue_report`, and `material_view` were not added to `AnalyticsEventClient.allowedEvents`.

## P2 leftovers

| Mount | File | What it does |
|---|---|---|
| Photo-record post | `Core/PlayKitScreenContracts.swift`, `Core/PlayAdvancedRuntime.swift`, `App/PlayExperienceView.swift` | `RECORD` is an action on the existing `photoCheck` catalog entry. `postRecord` sends `PlayPhotoRecordSubmission`'s body through `PlayAdvancedCoordinator.submit` (`api/play/advanced/action`). No new route. A non-`RECORD` segment still accepts only `SUBMIT_PHOTO_CHECK` plus an https `imageUrl`. The skip button posts `{textConfirmed: true}` after the same local check it already had. |
| 「我已到达」 | `App/PlayExperienceView.swift` | The station and the free-exploration store pass `RuntimeNativeLocationProvider(enabled: true)`. One when-in-use fix. Not `SessionTrackedRoamLocationProvider`. |
| `FreeExplorationVisitConfigView` | `App/ProjectEditView.swift`, `Core/ProjectEditCoordinator.swift`, `Core/ProjectEditHTTPService.swift` | Navigation link on a free-exploration draft when `publicationTopicID` exists and `visitConfigModel` returns a model. The factory returns nil while `PlayRuntimePortRouteGate.freeExploreVisitConfigRead` is false, so the link is absent. |

## Gates left off

- `CastCapability` (`.castProfile`, `.castVoice`, `.castBranch`) — `makeCastCoordinator()` passes `enabled: []`.
- `PlayStageAnalyticsGate.enabled` — still `{ false }`.
- `PlayHelpLadderModel.poolTrimEnabled` — default `false`. `play.help.poolTrim` / `POOL_TRIM` not turned on.
- `PlayRuntimePortRouteGate.freeExploreVisitConfigRead` — `false`.
- `PlayRuntimePortRouteGate.freeExploreVisitConfigWrite` — `false`.
- `PlayRuntimePortRouteGate.storyLockMissingCountsAsLocked` — untouched.
- `AnalyticsEventClient.allowedEvents` — the five stage names were not added.
- `RuntimeLocationProjection` — not edited. A WGS-84 fix whose accuracy is above 100 m and at most 200 m stays a local accuracy failure.

## Left unwired because the receipts marked it out of scope

- `PlatformAudioPlayback` and `autoplaySelectedNarration`. The toggle may show. Nothing calls play.
- `PlayRunStartRequest` merged into the arrive form.
- Cast route rows on `ChinaReviewedRouteCapability` (`GET /api/topic/cast/voice`, `POST /api/play/run/profile`, `POST /api/play/run/branch`). Those are the security fence. Gates stay empty, so the rows were not added and nothing is marked live.
- Station `trustChanged` UI from `PlayAdvancedState`. The branch echo is the mounted piece. `endingFor` / `endingCount` are not on `PlayEndingDocument`.
- `PlayTaskStatusPresentation.labelKey` and story facts on `FreeExplorationPresentation`.
- `role.views`, `feat/pilot-kits-1124`, `PlayHelpContracts` / `PlayHelpService` / `PlayHelpPanelView`, narration, and 延伸阅读.
- DESK/ALT on the wire.

Not edited: `App/MPGap` screen bodies, `project.pbxproj`, `tools/current_ci_manifest.json`, money movement, deletion.
