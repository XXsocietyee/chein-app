# Receipt: fix/1128c-ai-npc-guide (AI NPCs, AI guide / companion, story hooks)

Branch `fix/1128c-ai-npc-guide` from `origin/ui/combined-r7` (`70917c058`). Not deployed; `main` untouched; no secrets,
no SQL. No Swift compiler in this cloud session: the code is written type-simple and the gates below are static.

## What is ON in Release now (proved by `Tests/AppUnitTests/Fix1128cAINPCReleaseCompositionTests.swift`)

| Inventory row | Feature | Release switch | Wire (exact backend method + fields) | Test |
|---|---|---|---|---|
| 6 | In-store NPC chat, text | `playConfiguration` `shopNPCWrites: true`; `sessionDependencies` `shopNPCGrants` text grants; `playPaths` ∪ `aiNPCPlayPaths` | POST `api/ai/npc/shop-chat` JSON `{requestId,nodeId,message}` (BE `ApiAiNpcController.java:266`) | `testReleaseCompositionSwitchesOnShopNPCTextVoiceAndHints`, `testShippedShopNPCAdapterSendsTextAndVoiceToTheWire` |
| 7 | In-store NPC chat, voice | voice grants + `ShopNPCVoiceCaptureFactory` → `ShopNPCPermissionedCapture` (system prompt only after the mic tap) | POST multipart `api/ai/npc/voice-chat` `file,nodeId,requestId` (BE `:338`) | same two tests |
| 9 | Not-open / safety / quota / retry states | server `code 403` → `ShopNPCFailure.server` renders the server's own message (「店铺分身对话还没开放」); `NpcChatResp` outcome fields already rendered | — | via the adapter test (business code path) |
| 10 | Voice out | `AIVoiceOut` (`AVSpeechSynthesizer`) read-aloud on NPC replies and guide lines; `audioUrl` playback stays off (deferred merchant voice clone) | none (on device) | `playback` asserted false |
| 11 | 「AI 对话记录」 view / export / delete | `AppSession.ensureReleaseNPCChatDataApproval()` issues the read lease (Settings `.task`, before a tap); `NPCChatDataReader.makeCoordinator(deletion:)` + `releaseNPCChatLogDeletion(for:)` | GET `api/ai/npc/chat/data/export`; POST `api/ai/npc/chat/data/delete` body `{}` → `{deleted:n}` (BE `:496,507`) | `testReleaseCompositionIssuesNPCChatDataReadAndDeletion` |
| 14 | AI guide / roam companion | `AIGuideToolbarButton` + `AIGuideSheet` on live roam (`RoamLiveSessionView`, presented from the persistent session sheet) and play (`PlayExperienceView`) | reuses rows 1-3 + the same `api/map/weather` cell read (no extra request) | content test below |
| 15 | Hint ladder + hint unlock | `playPaths` | POST `api/play/puzzle/hint`, POST `api/play/hint/unlock` | `testReleaseCompositionSwitchesOnShopNPCTextVoiceAndHints` |
| 18 | Data-driven script | `Resources/Story/StoryGuide.json` via `StoryContentCatalog` / `AIStoryContent` | — | `testStoryContentBundleHasEnglishAndSimplifiedChinese` |

Stays closed on purpose: `api/ai/npc/chat` (roam free chat; backend `chatOn()` hard false, owner 07-22) is asserted
absent from the Release play configuration, and `journeyAsks` stays false.

## OWNER RULE 1-3 rows (screens touched)

| MP page | Native view | MP sections present | Optimizations | Level |
|---|---|---|---|---|
| `pages/play/index.js` shop NPC (店铺分身对话) | `App/ShopNPCView.swift` | identity + AI disclosure ✓, greeting ✓, messages ✓, voice ✓ (now live), server not-open message ✓ | presence ring on the NPC avatar while thinking / speaking; typing reveal of the newest reply (server text is already reviewed); light haptic when a line lands; read-aloud; identity chip + fallback greeting from the script file; Reduce Motion: static avatar, full text | A |
| `pages/roam/index.wxml:438-443` 漫游提示 prompt slot (+ `paceCard` meaning, settle `routeStory`) | `App/AIGuide/AIGuideSheet.swift` from `App/RoamLiveSessionView.swift` toolbar | 漫游提示 label ✓ (neutral, no avatar / name), reviewed line ✓, place meaning ✓, route story ✓ | one native toolbar button (sparkles bounces + light haptic when a new reviewed line arrives); half sheet with "now" (place, cell weather), the visit's lines, the owner's prompts by weather; read-aloud; disclosure footer | A |
| `pages/play/index.js` (no MP guide; the play surface's own notes) | `App/AIGuide/AIGuideSheet.swift` from `App/PlayExperienceView.swift` toolbar | n/a (app-side companion asked by the owner 11-28) | current stop, its NPC greeting, prompts by weather / shop stop, read-aloud | A |
| `pages/shezhi/shezhi.wxml:24,57` AI 对话记录 | `App/NPCChatDataReadSettingsEntry.swift` | row ✓, option sheet (查看 / 导出 / 清除) ✓ — now reach the server | no visual change | C |

Screenshot sweep: no sweep of these surfaces exists yet (`docs/sweeps/latest` has no AI guide shots); the coordinator's
next sweep should add `roam-live` with the guide sheet open and the shop NPC conversation.

## Gates

- `python3 tools/generate_project.py` ✓ (adds `App/AIGuide/*.swift` and `Resources/Story/*.json` to the target)
- `python3 tools/check_scaffold.py` ✓
- `python3 tools/contract_ratchet.py --check` ✓ (52 failing = baseline 52, new 0). One pin updated deliberately: `Tests/ContractChecks/test_shop_npc_interruption.py` now expects the voice capture to be injected (commented)
- `python3 tools/check_design_consistency.py` ✓ (0 new)
- `python3 -B tools/check_a11y_lint.py` ✓ (0 new)
- `python3 tools/check_appsession_ratchet.py` ✓ (AppSession.swift unchanged in length; one line edited)

## Not done / owner decisions

- **Footprint hint** (inventory row 4): needs the local last-walk end point and adjacent unlit tiles on the live map;
  copy is ready (`guide.footprint`). The map circle is mp-roam's.
- **Store-homepage NPC chat** (`merchant-chat`, row 13): merchant is out of the first release.
- **Story narration** (row 16): the story-flow theme is paused by the owner; the script layer is now data-driven.
- **Roam free chat / "ask the guide"** (row 12): needs a new backend compliance gate first; the guide shows reviewed
  text and the owner's prompts only.
- **Humanoid figure stage** (row 20): waits for the P3 avatar vendor decision; the presence ring is the interim.
- Backend flags and keys the owner sets: `docs/release/owner-values.md` → "fix/1128c-ai-npc-guide".
- Planning conflict to confirm: the 07-22 decision says roam AI has no page / FAB / sheet; the owner's 11-28 ask is an
  always-available guide. This build keeps the guide formless (no avatar / name / chat) and puts it behind one native
  toolbar button + sheet; if the owner prefers the 07-22 shape, remove the two toolbar items and keep the journal.
