# Receipt: native r2, story flow (`native-r2/flow-story`)

- **Brief:** `docs/briefs/native-r2.md` (branch `design/handoff-r2`), "EVERYTHING native".
- **Spec:** `docs/design/native-r2/story-flow.md` (branch `design/native-r2-story-flow`, 0d789d6e7).
- **Base:** `origin/ui/combined-r7` 2446657fb. Held until owner approval; not merged into `ui/*`.
- **Switch:** `NativeR2Flags.storyFlow` (default `true`) in `App/NativeR2/NativeR2Flags.swift`. Off renders the r1 views unchanged.

## What changed
| Screen (spec) | Native r2 | File |
|---|---|---|
| Route page (S4/S5) | The first sections of the play list: cover (`AsyncImage`, 16:9), title, AI tag, `ProgressView` of chapters done, one `.borderedProminent` Start/Continue, a chapter `List` with done (`checkmark.circle.fill`), current (`circle.inset.filled`), open and locked (`lock`, disabled) states, and a horizontal cast row with an "All Characters" button that opens the existing roster sheet. Replaces the r1 "chapterStory.title" link list and the full-screen title-card overlay. | `App/NativeR2/Story/NR2StoryRouteSections.swift`, `App/PlayExperienceView.swift` |
| Reader (S6) | The same `ChapterStoryView` logic. The opener sits at the top of the scroll (no gate overlay). Narration is `.body` text with line spacing. Role lines show a 32 pt avatar button (opens the existing cast card), the name and the line, with a context menu. Voice is italic secondary text. Dividers are `Divider`. No theme edge, no reveal motion, no atmosphere fill or forced dark scheme: the reader follows system Light/Dark. Loading is `ProgressView`; errors use `ContentUnavailableView` with Retry. | `App/ChapterStoryView.swift`, `App/NativeR2/Story/NR2StoryReaderParts.swift` |
| Mini audio player (S6) | `.safeAreaInset(edge: .bottom)` on `.bar`: title, state, play/pause, next clip. It drives the existing `PlatformAudioPlayback` (same factory `makeAudio`). The per-source consent review (`platform.audio.review`) is the same as `PlatformAudioConsumerView`. Selection still goes through the reader's guarded `scopedAudioSelection`, so only this chapter's clips can play. The queue is narration, then guide, then the audio blocks in reading order. | `NR2StoryReaderParts.swift` (`NR2MiniAudioPlayer`) |
| 延伸阅读 | Unchanged `ChapterOptionalReadingCard` (already a `DisclosureGroup`). | — |
| Chapter end / next-stage row (S10) | Closing line, `LabeledContent` stops done, a "Next" row with the next chapter's name, and one `.borderedProminent` Next Chapter / Done button (same `leave()` as r1). | `NR2ChapterFooter` |
| Stage result (S9) | After this screen's own submission settles as completed, a `.sheet` with `.presentationDetents([.medium])`: result icon, then `LabeledContent` score (`xp`/`score`), stamp (medal, drop or badge), unlock (next stop name or the continuation), and one prominent Continue. Continue opens the next stop through the same `openNode` callback as `playTaskOutcome.openNext`, or just closes. `.sensoryFeedback(.success)`. The r1 outcome section stays under it. | `App/NativeR2/Story/NR2StageResultSheet.swift`, `PlayExperienceNodeView` |
| Play stage (S8) | Stays on `ThemeDomain.game`. The HUD bar (提示 / 队伍 / 背包) uses `.bordered` buttons with `.buttonBorderShape(.circle)` instead of `CYPillButton` and the glass circle style. | `App/PlayHUD.swift` |

## Behaviour and requests
- No new request. Every load, arrive, submit, cast, thought-claim and audio path is the existing coordinator call.
- Reading-position resume, the unsaved-answer guard, the cast card, image zoom, inline games and choices are unchanged.

## Identifiers kept or moved
- `chapterStory.open.<id>` → route-page chapter rows.
- `play.titleCard`, `play.titleCard.aigc` and `play.titleCard.start` → route header.
- `chapterFlip.gate` → reader opener; `chapterFlip.end` and `chapterFlip.end.continue` → chapter footer; `chapterStory.closingLine` → footer.
- `chapterStory.loading`, `chapterStory.error`, `chapterStory.lockedStop`, `platform.audio.state` and `platform.audio.toggle` are kept.
- `playVerdict.word`, `playVerdict.text` and `playVerdict.continue` → result sheet.
- `playHUD.hint` and `playHUD.backpack` are kept.
- New: `play.nr2.*`.

## Strings
35 keys in `docs/port/strings/native-r2-story-flow.json`, merged into `Resources/Localizable.xcstrings` with `tools/merge_localization_fragments.py` (added 35, overridden 0).

## Gates
- `tools/generate_project.py` now also globs `App/NativeR2/**/*.swift`.
- `python3 tools/check_scaffold.py` → `PASS structural checks`.
- No compiler in the cloud. Each SwiftUI API used was checked by grep or against the iOS 17 SDK surface: `ContentUnavailableView`, `.sensoryFeedback`, `.buttonBorderShape(.circle)`, `.presentationDetents`, `navigationDestination(item:)`, `ProgressView(value:total:label:currentValueLabel:)` and `AsyncImage`.
- Compile traps checked:
  - property shadowing uses `self.` (`rows`, `outcome`);
  - ternary shape styles are typed;
  - memberwise argument order matches the declarations;
  - no `String(localized:)` and no interpolated `LocalizedStringKey`.

## Not done / notes for the coordinator
- **Not done in this pass:** Books-style toolbar hiding, the Themes menu, the Contents sheet, the Now Playing sheet and the inline stop card (S7). They are left for the next pass.
- **Audio controls:** "Skip" moves to the next clip. `PlatformAudioPlayback` has no seek, so ±15 s is not offered rather than faked.
- **Cast avatars:** `NR2CastAvatar` loads only `https` avatars with `AsyncImage`. `media-asset:N` avatars show the system person glyph here and keep loading through the retained reader in the cast card.
- **Flags type:** `NativeR2Flags` is a new shared type. Other lanes should add their switch to the same file so the type is declared only once.
