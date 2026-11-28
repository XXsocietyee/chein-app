# K40 · publish and create (`cursor/1128-k40-publish`)

Base `origin/ui/combined-r7` @ `a7c956335`. Scope: publish and create rows from `docs/briefs/round3-1127.md` (handoff `design/handoff-r2`) and audits `1128-functions`, `1128-plan`, `1128-ada`. No restyle. The create menu in `App/PublishingModesViews.swift` still leads with the AI row (`publishModes.ai`), then 自由探索 / 城市定向 / 互动.

`App/AppSession.swift` stays 7977. `App/AppCompositionRoot.swift` stays 4175. Init order in `playConfiguration` stays devices, sensors, artworkHosts. `PlayerLaunch.merchantCenterEnabled` stays false in Release. No money switch flipped. No `String(localized:)`. No secrets, deploys, or SQL.

hengyin `XXsocietyee/hengyin` returned **404** to this run (repo and `us/r3-functional`). No backend branch. The routes these rows call are already marked `liveInProduction` on the app side, so there is no backend diff.

## Closed here

P1-26 / H-10 leftover: 用这个模板 copied the topic, then pushed a blank page everywhere except the 发布 tab and the topic-preview deep link. The copy already succeeded (`TopicTemplateAdoptionFactory.install` in `makeSession`).

| Surface | Wiring |
|---|---|
| Player root (home search, create sheet, square) | `App/QuestifyApp.swift` sets `topicEditorDestination` to `PublishTabRootView.topicEditorDestination` |
| Session template shelf, including a sheet | `SessionShelfTopicEditor` in `App/DiscoveryTemplateBrowserView.swift` (fixture readers are not sessions) |
| Search topic-template result | `App/GlobalSearchLinksAndTemplates.swift` sets the same destination on the deck |
| Square 看看模板 | `SquareDetailPlayCard` falls back to that destination when no host override is set (`App/SquareDetailView.swift`) |

The editor query is unchanged: `id`, plus `scope` only when it is non-empty and not `MERCHANT` while merchant center is off (`PublishTabRootView.topicEditorQuery`).

Proof: `Tests/ContractChecks/test_k40_publish_create.py`.

## Already fixed (re-checked on `a7c956335`)

| Row | Verdict |
|---|---|
| P0-7 互动 authoring `api/template/draft` / `publish` | Fixed @ `41635a1ace67a5c2e36f095dfc6f2ecfc842dd7d`. `MPFirstPublishApprovals` issues the original-request read and submit for a reviewed China player with writes on. `makeTemplateAuthoringRequestService` passes those approvals. |
| P1-26 发布 tab 用这个模板 | Fixed @ `8dc8f98f56eb2927432f8cbfaf0b0988098e8249`. The tab shelf sets the destination. Off-tab surfaces are the row above. |
| P1-27 story image, story audio, node photo, owned cover | Fixed @ `41635a1ace67a5c2e36f095dfc6f2ecfc842dd7d`. |
| P1-29 我的项目 → 模板 shelf | Fixed @ `41635a1ace67a5c2e36f095dfc6f2ecfc842dd7d`. |
| P2-6a `publish-status` and `edit-requests/*` | Fixed @ `f85a43975424226c832bb5a4f43335c3eb9b3110`. Both are in `creatorEditorAndOrderCenterOwnerGrant` and `.liveInProduction`, so `projectEditorRoutes` grants them on the production host. |
| P2-6b signed-out "+" | Fixed @ `743c6c6f85d25dacce8cadabb2b22254d5cf74f7`. The "+" opens `LoginView(intent: .player)`. |
| P2-6c content drafts | List and restore on @ `837ba4d05c5106f2353b8a1829c9e86255956319` (`ownerDrafts`). The 我的 row shows only when a browser is composed @ `1f9e833477a89e7bddcb361365724868cc3415a2`. Save and delete stay off: the MP has no content-draft page. |
| P2-6d 互动 template intro | Checked, no change. `startsInEditor` is false, so the steps are intro → name → edit. |
| H-06a / H-13a 发布 "+" and club 发布活动 | Fixed @ `535af06ecacdacb5a8e127e78523c4907a5dfde6`. `.publishingRead` / `.publishingWrite` are in the Release business config for player and club. Merchant gets neither. |
| H-07 place pickers | Fixed @ `309b28d7d2cdd7d8df372252c424bb4976efce95`. `PublishingMapKitAdapter.playerPublishing` searches with MapKit and a tap drops a pin. Merchant pickers stay on the off adapter. |
| H-08a AI template fill | Fixed for club hosts @ `cc8990f8687594ef9e0b6009633a9d40218ebb2b` / `f2dbd449ac6680df4a179bf864686e49c56f1c0b` (`.publishingAITemplate`). Players do not get it: the backend `gateRole` blocks them, and the hub hides the row. |
| H-08b AI safety precheck | Fixed @ `cc8990f8687594ef9e0b6009633a9d40218ebb2b`. Club hosts POST `api/ai/safety/precheck` with `{title, subtitle, description, nodes[]}`. Players degrade to pass, matching that same gate. |
| H-08c club 策划 | Fixed @ `f2dbd449ac6680df4a179bf864686e49c56f1c0b` (`.publishingAIClub`). |
| H-11 选择玩法 sheet | Fixed @ `087ef827639560dca4169f881c1966bd3478e632`. |
| H-13b activity 编辑 | Fixed @ `9ee19bd5ab8f095c9dd1071c7c525325546fac1d`. |
| H-15 stale cast clues | Fixed @ `1c52b17fb6155f0af7972c6f5c1fba298970445a`. |
| Create menu AI row | Kept @ `cc8990f8687594ef9e0b6009633a9d40218ebb2b`. First section of `PublishingModesView`, and the first item of the 发布 tab "+". |
| H-06b 开放范围 | Superseded. The MP treats it as the club-pool toggle, not a required range. |

## Left

| Row | Why |
|---|---|
| Approved-topic-release sheets (function-audit row 269) | No mini-program caller. The player publish path is `api/topic/v2/create` / `update` plus `publish-check`. These grants stay empty. |
| 我的项目 取消活动 (row 275) | Refund. `ReviewedAreaSwitch.moneyPayments` was not flipped. |
| 我的项目 topic row → `api/project/home` (row 277) | `merchantinfo` is a merchant-center page. Release opens the player topic (`PlayerLaunch.merchantCenterEnabled` is false). |

ADA `1128-ada` has no publish or create screen row. The generic publish tab glyph is an mp-nav note, not this lane.

## Gates

On this tree, after the wiring above:

| Gate | Result |
|---|---|
| `python3 tools/generate_project.py` | 4200 native sources, 927 app-unit classes |
| `python3 tools/check_scaffold.py` | PASS (AppSession 7977, AppCompositionRoot 4175) |
| `python3 tools/check_appsession_ratchet.py` | PASS |
| `python3 -B tools/check_a11y_lint.py` | PASS, 0 new |
| `python3 tools/check_design_consistency.py` | PASS |
| `python3 -B tools/contract_ratchet.py --check` | 46 failing, baseline 46, **new 0** |
| `python3 -B Tests/ContractChecks/test_k40_publish_create.py` | 5 tests OK |

No Swift compiler on this machine. The new test is source-level.
