# cloud-h3 full play (§五 U04-01..04)

Branch `ui/cloud-h3-claude` from `origin/ui/main` 469e525f0. Code only: no xcodebuild, simulator or live backend on this Mac. The integrator compiles and runs the tests.

Sources read:
- Owner pack `origin/ui/owner-handover` `docs/owner-handover/app-ai-pack-20261108/`: `先读我-给App端AI.md`, `UI优化施工清单.md` §五 + §十一 + §十三, `docs/contracts/content-schema.v1.json` (`capabilityDeclaration`, `capabilityCompatibility`, `x-cy-derivedCapabilityKeys`).
- Backend `liboyang42-cpu/hengyin` `integration/backend-app-20261112` @ c96d345ff: `ContentCapabilityRequirements.java`, `PlayNodeQueryApplication.java` (`compatibility`, `contentSnapshotVersion`, `publishedConfigVersion` on `/api/play/nodes`), `ApiPlayProgressController.nodes` (`clientPlatform` / `clientVersion` / `capabilities` query), `PlayEntryApplication` + `TopicRouteRuntimeServiceImpl.state(…, Declaration)`, `ChapterFlowCompiler` block types, `TopicDeliveryMetadataProjection`.
- Mini-program, same repo, `chengyinhub-xcx` @ d5ac70e57 (2026-11-13; the checkout path named in the brief did not exist, so a same-day checkout was read without changes): `pages/play/index.js` `openChapterFull` block loop, `_saveReadingPos` / `_resumeStory`, `utils/story-resume.js`, `utils/client-capabilities.js`, `utils/chapter-blocks-health.js`, `publish/utils/publish/pro-editor-story.js` (cap / gallery shape).

## Card → native files → status

| Card | Native files | Status | Reason |
|---|---|---|---|
| U04-01 Story in order | `Core/ChapterStoryContracts.swift`, `App/ChapterStoryView.swift` | DONE (code) / NOT_RUN | The runtime chapter decoder and spoiler-truncating renderer already existed. Added the blocks the mini-program renders that iOS dropped: text `who` prefix and per-block `level`, `gallery`, `divider`, `cap` open/end lines (gate subtitle and the end of the chapter), image/audio `altText`. A block with no native renderer (including `branch`) now shows an in-place "needs another version" line and never its content, instead of disappearing silently. The legacy path (`description` + earned notes) is unchanged. |
| U04-02 Choices, evidence, endings | existing `PlayBranchHistoryView`, `PlayThemeBackpackView`, `PlayExperienceView` ending/reward, `ChapterStoryProjection.lockedStop` + `App/ChapterStoryView.swift` | PARTIAL | Existing: branch decision log (choice → consequence), backpack items / clues / pending with used state, lock reasons in the stop list, ending fragments, reward from the receipt only. Added: when the chapter flow stops at a locked stop, the server's lock reason (or a neutral "continues when the next stop unlocks") is shown instead of a silent end. Not done: an in-flow player branch-choice sheet for the l-editor `branch` block. The mini-program does not render it either (`l-play` pending), so iOS does not declare `chapter.blocks.branch` and shows the placeholder. |
| U04-03 Capability check before buying / starting | `Core/PlayContentCompatibility.swift`, `Core/PlayExperienceService.swift` (`.capabilityDeclaration`), `Core/PlayExperienceContracts.swift`, `Core/PlayExperienceCoordinator.swift`, `App/PlayExperienceView.swift` (`PlayCompatibilitySection`) | PARTIAL / BLOCKED(backend) for purchase | Decodes `compatibility{requiredCapabilities, declared, supported, source, missingCapabilities}`. `supported:null` (UNDECLARED) shows nothing and blocks nothing; MALFORMED / DECLARED_MALFORMED show "not confirmed", never "supported"; DECLARED + false lists the missing keys before play. The server's start/first-entry refusal (`CONTENT_CAPABILITY_UNSUPPORTED` or the server sentence) gets an "update the app, nothing was started" line. Purchase side: no activity/registration read carries a capability verdict (only template `/info` `deliveryMetadata.requiredCapabilities`, with `platformExecution=UNKNOWN`), so the pre-payment notice is BLOCKED(backend). |
| U04-04 Rich media + reading resume | `Core/ChapterReadingPosition.swift`, `App/ChapterStoryView.swift` | DONE (code) / NOT_RUN | Image: tap to open full screen (pinch / double-tap zoom, Close), alt text as the VoiceOver label, loading state, failure shows alt text plus Retry. Audio: the author's `altText` is offered as a transcript under the Listen button, so muted / interrupted / slow audio still gives the text; no audio URL means no button. Text uses `CYTypography` (Dynamic Type). Reading resume: the segment at the top of the viewport is stored per run identity + content version + chapter and restored once per visit; a segment that is no longer rendered, or the first one, leaves the reader at the top. It is local only and never counts as progress. |

## Decisions where the docs were silent or differ

1. **Declaration is dormant.** `PlayExperienceCapability.capabilityDeclaration` is in no production capability set. When enabled, `/api/play/nodes` gets `clientPlatform=ios-native`, `clientVersion` (bundle short version if it matches the server pattern), `capabilities=key@1,…`. Reason: the backend does not treat this declaration as a read-only hint. `TopicRouteRuntimeServiceImpl.state(…, Declaration)` asserts it before creating a first run, so one key missing from the iOS list would stop players from entering content iOS can actually play. Turn it on after the key list is checked against device play (`ReviewedPlayerWriteLeases.playCapabilities`). Until then the server answers UNDECLARED and the UI shows nothing, which is the documented old-client behaviour.
2. **iOS key list** (`PlayClientCapabilities.keys`) declares only what has a native renderer: base keys, `chapter.blocks.*` for node/text/image/audio/dream/mood/reveal/odd/voice/thought/divider/gallery/cap, `answer.*` for validation methods 0–7, sensors still / steps / audio_clip, and `game.*` for every `PlayKitScreenKind` plus hangman. Not declared: `chapter.blocks.branch` (no renderer anywhere), `answer.estimate|pricePair|hiddenObject` (iOS node screen resolves methods 8–10 as unsupported), `role.views` (not verified). The mini-program declares `branch` and `cap` without rendering them; iOS does not follow that for `branch`.
3. **Start endpoints do not declare.** The mini-program also declares on orient prepare/start and advanced/start. iOS has no orient prepare/start call, and advanced/start is left undeclared for the same reason as decision 1.
4. **Reading position identity** uses `contentSnapshotVersion` (else `publishedConfigVersion`) so a new revision never jumps an old run to a moved paragraph. With neither, nothing is stored.
5. **Unknown blocks** follow card U04-01 ("unknown required structure is blocked clearly") rather than the mini-program's silent skip.

## Strings

`Resources/PlayFullStory.xcstrings` (new table, EN + zh-Hans, 11 keys). Existing `chapterStory.*` keys are reused from `Localizable`.

## Accessibility ids

`chapterStory.image`, `chapterStory.image.retry`, `chapterStory.zoom.image`, `chapterStory.zoom.close`, `chapterStory.transcript.<segment>`, `chapterStory.unsupported`, `chapterStory.lockedStop`, `chapterStory.closingLine`, `playCompat.unsupported`, `playCompat.missing`, `playCompat.unconfirmed`, `playCompat.refused`.

## Rules held

No money, merchant or password surface touched. Unknown / unconfirmed is never shown as supported or as 0. No write was added, so there is no new requestId; existing receipt re-read paths are unchanged.

## Checks run here

- `tools/generate_project.py`: regenerated (3 new sources, 1 catalog, 1 test file).
- `tools/check_scaffold.py`: PASS.
- `tools/check_design_lint.py`: PASS.
- `xcrun swiftc -parse` on every changed and new Swift file: PASS (syntax only, not type-checked).

## Tests (written, not run)

`Tests/CoreTests/PlayFullStoryH3Tests.swift`: verdict mapping (UNDECLARED / MALFORMED / DECLARED_MALFORMED / unsupported with `declaredVersion:null`), document identity, declaration format and omissions, refusal detection, new block order + alt text + placeholder, locked stop, reading-position key and resume target. Existing `ChapterStoryTests` expectations are unchanged.
