# port-p1 receipt

Branch `port/p1-story-cast` from `origin/ui/combined-r6` `f1115875e53a3fbc03969720d44e91f01eeb5ada`.
Source: liboyang42-cpu/chengyin-ios `main` `a5c863e38b3c5f80ce1ed3207223278c19062d7f`, with cast follow-up `feat/cast-1119` `ae1753034e7fce58ac6e94c82247d76be171fbec` read before C8. Pilot kits were not ported. No cherry-pick.

## Clusters

- C8 cast: contracts, service, coordinator, views, tests. Follow-up included: empty name sent as 「你」, `identityTitle` snapshot, story `branch` picks, local trust display, ending owner fallback, voice `runId`.
- C13 story page: line margin, flat chapter colour (`ProjectChapterAtmosphere.forRead` in this package), reading reveal via `CYMotion`, station footer. App-only gate, end card, zoom, resume, locked stop, gallery, divider, cap, alt, and unsupported blocks stay.
- C4: roles A–D and SOLO 2–4 with labels; narration autoplay preference and toggle; 延伸阅读 on the story page and the journey ending chapter.

Letter pool and `PlayContentCompatibility` were not edited.

## Files copied

- `Core/CastContracts.swift` from `feat/cast-1119` (then `CastRuntimeFacts` and `CastConfig.fromTopic` added here).
- `Core/JourneyRoleView.swift` from chengyin-ios `main` (the file was byte-identical before C4; this copy is the C4 projection).

## Files adapted

- `Core/CastService.swift` new. Standalone. Gates `CastCapability.castProfile`, `.castVoice`, `.castBranch`, default empty. Voice does not share `.reads`. China production host is refused by `ChinaReviewedRouteCapability.offersFeature` even when a gate is on.
- `Core/CastCoordinator.swift` new. Cast state lifted out of `PlayExperienceCoordinator`. That file was not edited.
- `Core/ChapterStoryContracts.swift` re-implemented in place: `line`, `branch` (hidden with no cast; `.choice` until picked), `optional` reading, atmosphere, narration preference. Existing blocks kept.
- `App/CastViews.swift` new. Rewritten onto app image, audio, and motion types. System form for the character card. No `.font(.system(size:))`, no `.caption2`.
- `App/ChapterStoryView.swift` optional `castModel` (default nil, so `PlayExperienceView` need not change), margin lines, choices, optional reading, footer, atmosphere fill, reading reveal, narration toggle.
- `App/JourneyRoleViewSection.swift` role label, other-role labels, solo headings, teammates line. Existing identifiers kept.
- `App/JourneyNarrativeView.swift` ending chapter `optional: true` only.

## Tests ported

- `Tests/CoreTests/CastContractsTests.swift` new. Service and coordinator tests target `CastService` / `CastCoordinator`. Ending and topic assertions use `CastEndingResult` and `CastRuntimeFacts` / `CastConfig.fromTopic` so `PlayEndingDocument` and `TopicDetail` stay untouched. `testAdvancedStateReadsTrustChangedOnce` was not ported (P4 `PlayAdvancedState`).
- `Tests/CoreTests/ChapterStoryTests.swift` atmosphere, optional reading, narration preference.
- `Tests/CoreTests/JourneyRoleViewTests.swift` C/D, labels, SOLO 2–4, malformed other-role labels, three-view SOLO coordinator read.
- `Tests/AppUITests/JourneyRoleViewFlowTests.swift` unchanged. The two iOS UI tests (`roleSoloSingle`, `roleC`) need fixture scenarios in `App/JourneyContentFixtureSupport.swift`, which this package does not own.

## Mount hooks

In `App/CastViews.swift` unless noted:

- `CastOpeningFlow` and `CastOpeningFlow.step` for P2 (start, then playbill).
- `CastRosterButton` for P2.
- `CastEndingSection` for P2. Build it from `CastEndingResult(raw:)`; `PlayEndingDocument` has no `cast` property.
- `CastBranchEcho` stays the decoded model P4 already constructs. A second view with that name would collide, so the label is `CastBranchEchoLabel(echo:config:)`.
- `TopicCastRow` for P3. Empty cast draws nothing. Decode with `CastConfig.fromTopic`.
- `NarrationAutoplayToggle` in `App/ChapterStoryView.swift`.
- `ChapterStoryView.castModel` default nil.
- `ChapterOptionalReadingCard`.

P2 still has to pass `castModel`, call `CastCoordinator.adopt(raw:topicID:runID:)` from the nodes payload (`CastRuntimeFacts`), and present the opening flow. Until then cast stays off.

## Route rows for P2

Add these to `Core/ChinaReviewedRouteCapability.swift` as reviewed `newBackendOnly`. Do not mark `.liveInProduction`. Reads stay reviewed. Gates on `CastService` default off, and `offersFeature` keeps the China host closed until a later live admission.

| path | method | kind | mark | gate |
|---|---|---|---|---|
| `/api/topic/cast/voice` | GET | read | `newBackendOnly` | `CastCapability.castVoice` (not `.reads`) |
| `/api/play/run/profile` | POST | write | `newBackendOnly` | `CastCapability.castProfile` |
| `/api/play/run/branch` | POST | write | `newBackendOnly` | `CastCapability.castBranch` |

P2 also wires `PlayExperienceCoordinator` to `CastCoordinator` without this package editing that file. P3 adds `TopicDetail.castConfig` and mounts `TopicCastRow`. P4 shows station `trustChanged` from `PlayAdvancedState` (not ported) and can drop `CastBranchEchoLabel` under a choice. Story-line `rememberedBy` is already shown here.

## Strings

`docs/port/strings/p1.json` (zh-Hans and en). Keys match chengyin-ios. `Resources/Localizable.xcstrings` was not edited. A/B/SOLO assignment keys already exist and were not repeated.

## Accept

`docs/port/accept/p1.txt` lists real DEBUG launches only: play experience `classic`, journey content `roleA` and `roleSolo`. There is no chapter-story or cast launch argument. The file says so. No route was invented.

## Parse

`swiftc`, `swift`, and `xcodebuild` are not installed on this VM. `swiftc -parse` was not run. Pushed anyway.

## What this package could not do

- No compiler, so no parse and no test run.
- Did not edit `ChinaReviewedRouteCapability`, `PlayExperienceCoordinator`, `PlayExperienceService`, `PlayExperienceContracts`, `PlayAdvancedRuntime`, `PlayContentCompatibility`, `TopicDetail` / `TopicDetailView`, `PlayExperienceView`, `PlayKitQuestionForms`, `PlatformAudioPlayback`, `PlatformConsumerViews`, `JourneyContentFixtureSupport`, `ProjectChapterAtmosphere`, `Localizable.xcstrings`, `project.pbxproj`, or `tools/current_ci_manifest.json`.
- Narration preference key `play.narrationOn` (default on) and the toggle are ported. Starting playback (`autoplaySelectedNarration`) is not, because that method is not in an owned file.
- Station choice `trustChanged` UI is not ported (P4).
- `PlayExperienceDocument` / `PlayEndingDocument` / `TopicDetail` gained no stored cast fields.
- Xcode lists sources explicitly. New files (`App/CastViews.swift`, `Core/CastContracts.swift`, `Core/CastService.swift`, `Core/CastCoordinator.swift`, `Tests/CoreTests/CastContractsTests.swift`) are not target members until the integrator runs `tools/generate_project.py`. This package did not run it, because that rewrites `project.pbxproj`. Until then the app target will fail to compile the edited `ChapterStoryView.swift`. SPM `swift test` sees new Core sources without that rewrite.
- No pull request. No acceptance workflow run.
