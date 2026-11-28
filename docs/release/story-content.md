# Story content: how the owner swaps in the revised script

Owner, 11-28: "We'll be revising the script later to enrich the story; this needs to be included."
No NPC line, guide prompt, or story text is written in a SwiftUI view. Text comes from one of two places:

1. **The server (always wins).** Reviewed NPC lines (`GET api/ai/npc/event` → `line`), the NPC greeting
   (`PlayNode.npc.greeting`, `api/ai/npc/profile` → `greeting`), place meaning (`POST api/roam/poi/discover` →
   `meaning`), the route story (`POST api/roam/finish` → `routeStory`), NPC replies (`NpcChatResp.safeText`) and the
   journey narration (`api/play/journey/stage-end|casebook|ending`, story-flow theme paused). These are edited in the
   admin console and pass the backend review (`audit_status`) before they reach a player.
2. **The bundled content file** `Resources/Story/StoryGuide.json`, for the lines the app itself says: the NPC identity
   chip, the NPC fallback greeting, the guide's neutral identity, the quiet line and the guide prompts.

## Swapping in a revised script

The owner edits the JSON. No view, no `String(localized:)` literal, and no new Swift key is required for a wording change.

1. Edit `Resources/Story/StoryGuide.json`. Keep every text as `{ "en": "…", "zh-Hans": "…" }`. A missing or blank
   language rejects the whole file (`StoryContentCatalog.decode`), and the views then stay quiet rather than show half
   a script.
2. Bump `revision` (free text, e.g. `2026-12-05.1`) on every edit so a build can be traced to its script. The player
   never sees `revision` or `note`.
3. Keep lines short (one or two sentences). The guide never states facts about a place; place facts come only from the
   server's reviewed `meaning` (planning 漫游AI基座 §6-7: "无来源即不显示"). No persona in roam: no name, no avatar, no
   "I" voice for the roam guide (planning §7.1 人设残留为零).
4. Run the validator. It is the gate for this file, and `tools/check_scaffold.py` runs it with the other Python gates:

   ```sh
   python3 -B tools/check_story_content.py
   ```

   The machine schema is `docs/release/story-content.schema.json`. The checker reads required keys and the
   surface/weather enums from that schema and from `StoryContentKey` / `StoryGuideSurface` / `StoryGuideWeather` in
   `Core/StoryContent.swift`. They have to match. A duplicate prompt id, an unknown schema version, a blank line, or a
   script line pasted back into an `App/` or `Core/` string literal fails the gate.
5. Ship the edited JSON in the app bundle. `tools/generate_project.py` already packages every `Resources/Story/*.json`.
   A new file in that folder needs one `python3 tools/generate_project.py` so the Xcode project picks it up. The app
   loads `StoryGuide.json` only (`StoryContentCatalog`). Another JSON in the folder is validated the same way and is
   not shown until a catalog change names it.

Adding a new key (rare; a wording change does not need this): add a case to `StoryContentKey`, add the key to the
schema's `strings.required`, add both languages to the file, and read it with `AIStoryContent.text(.key, locale:)`.

## Schema (version 1)

```json
{
  "schemaVersion": 1,
  "revision": "2026-11-28.1",
  "note": "free text, ignored",
  "strings": {
    "<key>": { "en": "…", "zh-Hans": "…" }
  },
  "guidePrompts": [
    { "id": "roam.rain", "surface": "roam", "weather": "rain", "node": "shop", "text": { "en": "…", "zh-Hans": "…" } }
  ]
}
```

| Field | Type | Rule |
|---|---|---|
| `schemaVersion` | int | must be `1`; anything else rejects the file |
| `revision` | string | shown nowhere; for tracing |
| `strings` | map key → text | keys below; unknown keys are ignored by the app but must still be bilingual |
| `guidePrompts[].id` | string | unique; a duplicate rejects the file |
| `guidePrompts[].surface` | `roam` \| `play` | where the prompt may appear. `StoryGuide.json` needs at least one of each |
| `guidePrompts[].weather` | `any` \| `clear` \| `cloudy` \| `rain` \| `snow` \| `wind` \| `hot` \| `cold` \| `night` | `any` always matches; the rest match the guide's weather (map cell weather `rain` / `snow` / `fog`→`cloudy`, else `night` 19:00-06:00). Weather-specific prompts list first |
| `guidePrompts[].node` | optional `shop` | play only: the current stop has an in-store NPC |
| `guidePrompts[].text` | `{en, zh-Hans}` | both required, non-blank |

### String keys (`StoryContentKey`)

| Key | Used in | Today |
|---|---|---|
| `npc.aiBadge` | shop NPC header chip (`App/ShopNPCView.swift`) | AI guide / AI 向导 |
| `npc.fallbackGreeting` | shop NPC first bubble when the server sent no greeting | Hi! Tap a question… / 你好，想了解什么？… |
| `guide.roam.identity` | roam guide button + sheet title (`App/AIGuide/AIGuideSheet.swift`) | Roam notes / 漫游提示 (MP `pages/roam/index.wxml:443`) |
| `guide.play.identity` | play guide button + sheet title | Play notes / 游玩提示 |
| `guide.quiet` | guide sheet when nothing has arrived and no prompt matches | Keep walking… / 继续走走… |
| `guide.footprint` | reserved for the footprint hint (MP `utils/roam-footprint-hint.js:36` copy) | The edge of your last walk… |

## Screen chrome is not script

Section headers, button labels, weather names and the disclosure ("Notes come from reviewed content…") are ordinary UI
strings in `Resources/Localizable.xcstrings` (`aiGuide.*`), translated like every other string.

Lines that are still compiled into a view, and why this lane left them there, are listed in
`docs/release/receipts/k29-story-data.md`.
