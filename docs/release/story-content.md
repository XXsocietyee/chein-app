# Story content: the owner-editable script for NPC and guide moments

Owner, 11-28: "We'll be revising the script later to enrich the story; this needs to be included."
So no NPC line, guide prompt or story text is written in a SwiftUI view. Text comes from one of two places:

1. **The server (always wins).** Reviewed NPC lines (`GET api/ai/npc/event` → `line`), the NPC greeting
   (`PlayNode.npc.greeting`, `api/ai/npc/profile` → `greeting`), place meaning (`POST api/roam/poi/discover` →
   `meaning`), the route story (`POST api/roam/finish` → `routeStory`), NPC replies (`NpcChatResp.safeText`) and the
   journey narration (`api/play/journey/stage-end|casebook|ending`, story-flow theme paused). These are edited in the
   admin console and pass the backend review (`audit_status`) before they reach a player.
2. **The bundled content file** `Resources/Story/StoryGuide.json`, for the lines the app itself says: the NPC identity
   chip, the NPC fallback greeting, the guide's neutral identity, the quiet line and the guide prompts.

## Editing the content file

- Every text has `en` and `zh-Hans`. A missing or blank language rejects the whole file (`StoryContentCatalog.decode`),
  and the views then stay quiet rather than show half a script. A unit test
  (`Fix1128cAINPCReleaseCompositionTests.testStoryContentBundleHasEnglishAndSimplifiedChinese`) fails the build when
  a key is missing.
- Bump `revision` (free text, e.g. `2026-12-05.1`) on every edit so a build can be traced to its script.
- Keep lines short (one or two sentences). The guide never states facts about a place; place facts come only from the
  server's reviewed `meaning` (planning 漫游AI基座 §6-7: "无来源即不显示").
- No persona in roam: no name, no avatar, no "I" voice for the roam guide (planning §7.1 人设残留为零).

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
| `strings` | map key → text | keys below; unknown keys are ignored |
| `guidePrompts[].id` | string | unique; a duplicate rejects the file |
| `guidePrompts[].surface` | `roam` \| `play` | where the prompt may appear |
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

Adding a key: add a case to `StoryContentKey` (`Core/StoryContent.swift`), add the key with both languages to the
file, and read it with `AIStoryContent.text(.key, locale:)`.

## Screen chrome is not script

Section headers, button labels, weather names and the disclosure ("Notes come from reviewed content…") are ordinary UI
strings in `Resources/Localizable.xcstrings` (`aiGuide.*`), translated like every other string.
