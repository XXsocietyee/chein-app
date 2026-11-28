# Receipt: K29 story-data

Branch `cursor/1128-story-data` from `origin/ui/combined-r7`. Not deployed. `main` not pushed. No secrets.

The owner script is `Resources/Story/StoryGuide.json`, checked by `docs/release/story-content.schema.json` and
`python3 -B tools/check_story_content.py`. `tools/check_scaffold.py` runs that validator with the other Python gates.
How to swap a revised script: `docs/release/story-content.md`.

Production views that show the script (`App/ShopNPCView.swift`, `App/AIGuide/`) already read it through
`AIStoryContent` / `StoryContentCatalog`. This change does not rewrite those screens and does not add a
`String(localized:)` literal. `App/AppSession.swift` stays 7977 lines.

## Hardcoded story strings still in views: 6

These are narrative lines compiled into a view. They are not the owner script, and they sit in screens this lane does
not own (DEBUG fixtures, a SwiftUI preview, and the NPC safety sample). The validator checks the six strings are still
exactly these, and fails if a `Resources/Story` line is copied into an `App/` or `Core/` string literal. They were not
rewritten.

| # | Where | Story string | Why it stays |
|---|---|---|---|
| 1 | `App/ShopNPCFixtureView.swift` (`#if DEBUG` transport) | Ah, a fellow wanderer! The tea house has stood here since 1920. Look for the third red lantern near the courtyard: the stamp is tucked behind it. 欢迎来到老茶馆，印章就在第三盏红灯笼后面。 | UI-test NPC `safeText` behind `--e2-npc-chat`. Shop NPC flow tests assert the other fixture reply on this same line. |
| 2 | `App/ShopNPCFixtureView.swift` | Welcome, traveller! Ask me anything about this place. | DEBUG fixture greeting passed into `ShopNPCView`. |
| 3 | `App/ClubStoryFixtureHost.swift` | Follow the lanterns through the courtyard. This synthetic chapter has a longer story to exercise expansion and independent chapter selection. The second chapter has another story and a different play. No walk-time estimate is provided. | Club-story fixture chapter description inside one JSON blob. Club lane / tests. |
| 4 | `App/ClubStoryFixtureHost.swift` | A separate synthetic chapter story. | Second chapter in that same fixture blob. |
| 5 | `App/StoryRuleEditorView.swift` (`#Preview`) | A quiet corner of the square. | Preview node description (`Old clock tower` on the same line is a place name, not counted). |
| 6 | `App/NPCAISceneGuardSectionView.swift` | Tea is still warm. Keep your voice low near the window. | Sample `safeText` for the safety-section default. Workbench lane (`ReformWorldHostWorkbenchView`). |

Not counted: localization keys (`chapterStory.*`, `club.story.*`, `aiGuide.*`), upload instructions in the project-story
author screens, fixture harness labels (`Fixture reply / 测试回答`), and server text that views render with
`Text(verbatim:)` from a decoded field.
