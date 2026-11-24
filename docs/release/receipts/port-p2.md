# P2 receipt — play runtime

Branch `port/p2-play-runtime` from `origin/ui/combined-r6` (`f1115875e53a3fbc03969720d44e91f01eeb5ada`).
Source: `liboyang42-cpu/chengyin-ios` `a5c863e38b3c5f80ce1ed3207223278c19062d7f`, with `origin/fix/verify-1119-ios` (`69fa5223`) and `origin/feat/code-a3-visit-config` (`91898697`) read as reference. Cast (P1) and the game-kit stage header (P4) are not in this push.

## Clusters

- **C1** Arrival precheck (`PlayArrivalPolicy`) and free-explore unlock. `PlayArrivalService` calls the existing `review` + `submit` channel. A located start or visit sends `PlayCompletionEvidence.location`. A station tap sends `PlayCompletionEvidence.stationArrival` on the same `POST /api/play/arrive` builder. There is no second arrive client and no `.arrival(PlayArrivalReading)` evidence (that name is already the durable receipt).
- **C2** Offline chapters in the existing encrypted journal slot `key + ":fe-story"`. Visit-config `GET`/`POST /api/topic/free-explore/visit-config` is reviewed and default off.
- **C11** Station image chain: station `imgUrl` → chapter `imgArr` → route `topicCover` → `CYCoverArt`. `imgHidden` or a null `imgUrl` does not reveal the hidden photo.
- **C7** `runStartMode`, `altStations`, `perk` / `perkOnly`, `addressHidden`, photo-record validation, finished-node `feedbackText` and `picUrl`. DESK/ALT stay run-level. ASSISTED maps to `playx.completion.assisted`.

## Files copied, then adapted

- `Core/PlayArrivalPolicy.swift`
- `Core/PlayStationImage.swift` (`imgHidden` suppresses the station photo)
- `Core/FreeExplorationStoryArchive.swift`
- `Core/FreeExplorationVisitConfig.swift` (read and write default off; China production still refused)
- `App/FreeExplorationVisitConfigView.swift` (system List/Form; not mounted on the author editor)
- `Tests/CoreTests/PlayArrivalPolicyTests.swift`
- `Tests/CoreTests/PlayStationImageTests.swift`
- `Tests/Fixtures/ArrivalPolicy/arrival-policy.v2.json` and `README.md`

## Files adapted in place

- `Core/PlayContracts.swift` — additive node/chapter/result fields, visit/start/perk/completion types
- `Core/PlayProgression.swift` — gated `isStoryLocked`, `isVisited`, `FreeExplorationStoryFacts`
- `Core/PlayExperienceService.swift` — `stationArrival`, `freeExplorationHistory`
- `Core/PlayRecoveryStorage.swift` — journal codec for `stationArrival`
- `Core/PlayDurableRecovery.swift` — `:fe-story` slot; existing completion/paused/game/tag slots kept
- `Core/PlayExperienceCoordinator.swift` — archive on load, arrival review cases, `canSubmitArrival`
- `Core/PlayExperienceContracts.swift` — photo-record model, evidence cards, run photos, `photoCheckMode`
- `Core/ChinaReviewedRouteCapability.swift` — `PlayRuntimePortRouteGate` only
- `App/FreeExplorationViews.swift` — lock chip, archive cards, 「我已到达」 on the existing card/store layout
- `App/PlayExperienceView.swift` — arrival control, artwork, perk, completion mode, evidence, photos, RECORD skip
- `App/PlayNodeDetailView.swift` — artwork, hidden address, perk, completion mode, locked story
- `App/PlayThemePresentation.swift` — `PlayThemeCoverResolver` uses the same chain
- `Resources/InfoPlist.xcstrings` — when-in-use location string only; roam sentences kept, 「我已到达」 once-read merged in

## Files added

- `Core/PlayArrivalService.swift`
- `App/PlayStationArtwork.swift`
- `Tests/CoreTests/PlayRuntimePortTests.swift`
- `docs/port/strings/p2.json`
- `docs/port/accept/p2.txt`

## Route rows added

Outside `marks` and `wiredPatterns`, so `callSiteCount` stays 995 and `wiredPatternCount` stays 679.

| Path | Mark | Read | Write |
|---|---|---|---|
| `/api/topic/free-explore/visit-config` | `live-in-production` (`PlayRuntimePortRouteGate.visitConfigMark`) | default off | default off |

`mark(for:)` still returns nil for this path. A caller that forces the flags on is still blocked by `refuseUnwiredChinaProduction` on a China production host.

`/api/play/arrive`, `/api/play/history`, and `/api/play/nodes` were already live. No new rows for them.

`PlayRuntimePortRouteGate.storyLockMissingCountsAsLocked` is false. Missing `storyLocked` is locked only while that gate is on. City mode never uses it. A missing flag is not treated as visited.

## Strings

`docs/port/strings/p2.json`. Keys taken from chengyin-ios `Localizable.xcstrings` for arrival, visit-config, story lock, archive, completion mode, and `playkit.photo.continueWithout`. Extra keys this package's views reference (`playx.evidence.title`, `playx.photos.title`, perk, revealed/skipped, start label) are included. `Localizable.xcstrings` was not edited.

VoiceOver for a locked story: `playFree.story.locked.a11y` = 未解锁，到访后可读.
Unlock reveal uses `CYMotion.reduced` (or no animation when Reduce Motion is on).

## Accept routes

Real DEBUG fixtures only, in `docs/port/accept/p2.txt`:

- `--design-fixture t5-free-explore`
- `--design-fixture t5-free-explore-error`
- `--uitesting-module playExperience`

## Tests

- `PlayArrivalPolicyTests` against `Tests/Fixtures/ArrivalPolicy/arrival-policy.v2.json`
- `PlayStationImageTests`
- `PlayRuntimePortTests` — story-lock gate, #866 fields, photo-record, hidden station photo, visit-config default off, `stationArrival` on `/api/play/arrive`

`swiftc` is not installed on this VM, so `swiftc -parse` was not run.

## Mount hooks still needed

- **P1 cast** — do not mount here. Later wiring: opening, roster, and ending on `PlayExperienceView` (`CastOpeningFlow`, `CastRosterButton`, `CastEndingSection`). Those types are not on this base.
- **P4 stage header** — do not mount here. Later wiring: `PlayExperienceView` / kit host environment `playGameStage`. Not added.
- **P4 photo kit** — `PlayPhotoRecordSubmission` decides the RECORD body (`{textConfirmed:true}` or an https `imageUrl` ≤ 512) and rejects `SUBMIT_PHOTO_CHECK` on RECORD. The 「不拍照，继续」 button stores that body locally. `PlayKitInputContract` still has to post it.
- **P4 completion label** — `PlayTaskStatusPresentation.labelKey(completionMode:)` was not added. `PlayTaskSummaryPresentation.swift` is not owned. Owned views use `PlayCompletionModePresentation`.
- **DESK/ALT on the wire** — `PlayRunStartRequest.fields` is built and tested. It is not merged into the arrive form until the durable journal can store the start mode. Merging it only in memory would drop it on replay.
- **Author editor** — `FreeExplorationVisitConfigView` is not pushed from `ProjectEditView` (not owned). Open it when `freeExploreVisitConfigRead` is granted.
- **One-shot location** — `PlayArrivalService` takes `RoamDeviceLocationProviding`. The play and store screens pass nil, so a GPS 「我已到达」 reports location unavailable until a when-in-use provider is passed. `SessionTrackedRoamLocationProvider` was not used; it records a roam walk.
- **`RuntimeLocationProjection.gcj02`** is not owned and rejects accuracy above 100 m. A fix already marked GCJ-02 and no older than 30 s is used up to the policy's 200 m. A WGS-84 fix in the 100–200 m band cannot be projected here and is a local accuracy failure.
- **Story facts on `FreeExplorationPresentation`** — `PlayGameplayMode.swift` is not owned. Counts, all-visited, and perk-only live on `FreeExplorationStoryFacts`.

## What this VM could not do

- No Swift toolchain (`swiftc` missing). Nothing was parsed or tested by the compiler.
- `project.pbxproj` and `tools/current_ci_manifest.json` were not edited. New files compile after the integrator regenerates the project.
