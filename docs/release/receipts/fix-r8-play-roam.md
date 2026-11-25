# Receipt: fix/r8-play-roam (Claude App, r8 audit queue)

Brief: `origin/design/handoff-r2:docs/briefs/fix-r8.md`. Queue: `origin/audit/parity-r8-play-roam:docs/audit/parity-r8/play-roam.md` §3.
Base: `origin/ui/combined-r7` (merged again before every push). MP: `hengyin/chengyinhub-xcx` @ 1b10b25f.
No compiler in the cloud: every API used was grepped on the base first; the coordinator compiles. Strings: `docs/port/strings/fix-r8-play-roam.json` (en + zh-Hans).
New files were added to the project with `tools/generate_project.py`. Money untouched; no new gate turned on.

## Closed (Claude App rows)

| id | sev | what changed | files |
|---|---|---|---|
| BWALL-2 | P1 | Badge-wall tiles draw the server `badge.image` through the bounded `objectCardMedia` loader (no `AsyncImage`); MP `badge-demo.png` is the placeholder / fallback; locked badges desaturated. | `App/ObjectBadgeTileArtwork.swift` (new: `ObjectBadgeTileArtwork`, shared `BoundedMediaThumbnail`), `App/ObjectBadgeViews.swift` (1 line) |
| RHIST-2 | P1 | Native `RoamHistoryView` shows the MP partial-read notice 漫游记录读取失败，当前仅显示已读取记录。点此重试 when the first `GET api/roam/passport/history` page fails (401 / not configured / signed out show nothing); tap retries. Local rows stay. The parked merged list is not mounted. | `App/RoamHistoryRemoteStatusBanner.swift` (new), `App/RoamHistoryViews.swift` (2 lines) |
| ROAM-13 (live line) | P1 | Map ticket (NO.02) shows MP `introTeamsLive` 附近 N 支队伍在组队, only from the entry peek's successful team read; nil / 0 hides it. | `App/RoamHomeTabsView.swift`, `App/RoamBrowserView.swift` |
| OCARDS-2 | P1 | Object cards open on a native heap of the latest 40 (drag, fling, ✦ 聚成一团 / 让它们落下来); a tap opens the card detail. The grid stays under VoiceOver and Reduce Motion. Images only through the bounded loader; the parked `ObjectCardPileAndGridView` (CYCachedAsyncImage + foreign toolbar) is not used. `objects.card.<id>` identifiers kept on pile tiles. | `App/ObjectCardPileView.swift` (new), `App/ObjectCardViews.swift` |
| RNEAR-2 | P1 | Nearby (tab 0, map mode, with a centre) is map-first: full-bleed map with the team list in the existing in-view `CYMapScaffold` panel (compact peek = 附近的队伍 · N 支在招募, medium, large). In-view on purpose so the review / range / style / discovery sheets keep working. List mode and 我的队伍 keep the scroll page. The parked pins-only shell is not mounted. | `App/NearbyTeamViews.swift` (body split into `listContent` / `teamMap` / `mapPeek`), `App/NearbyTeamMapViews.swift` (`fillsHeight`) |
| JSEAT-r8-1 (App part) | P1 | Seats read now shows the phone-transfer recipient (`invitationChannel == PHONE`, INVITED/CLAIMED → 称呼 + `recipientPhoneMasked`, label as sub line) and computes MP `canTransfer` rows (AVAILABLE, seat > 1, `seatPhoneTransferSupported`, buyer, not read-only). 可转赠 / 转赠给同伴 rows and the 转赠第 N 席 sheet (称呼 ≤ 20, mainland mobile with +86/0086/space/dash normalisation, field errors, request id kept across an unconfirmed answer) are built; they show only when the host injects `onTransfer` (nil today). | `App/JourneySeatTransferSheet.swift` (new), `App/JourneyLandingViews.swift`, `App/PlayerJourneyReadBindings.swift` |
| RTEAMS-1 | P1 | Topic page shows the MP 组队 card under 参与品牌: up to 5 of this topic's teams from `GET /api/team/nearby` (20 km around the first stop with coordinates, signed in), 已组 N 支队伍 · 还差 M 人, per-row count / 还差. A joined city-orienteering topic (isSignUp, productType 1) taps into `OrientLobbyTeamsView` (activity owner when a team has one, else topic). Any failure hides the block. | `App/TopicTeamsCard.swift` (new), `App/AppSession+TopicTeams.swift` (new), `App/TopicDetailView.swift` (1 line), `App/PlatformConsumerSessionOwner.swift` (environment) |
| PLAY-r8-1 (L01-039) | P2 | 同队路线分享 switch starts off; the recorder and sync loop never run before the player has decided (MP `chosenShare || decided`). L01-032 (locked journal rows) n/a: the app has no 前路未知 journal rows. | `App/PlayerGapViews.swift` |

## Left open (with reasons)

| id | reason |
|---|---|
| ROAM-13 (city strip) | `RoamCityStripTabView` has nothing to mount on: the MP strip is the local city-guide catalog (`subpackageRoam/utils/roam-city-guide.js` `nearestCity` / `stripFor`), and there is no `fetchCityStrip` or catalog in Core. The parked view also has hard-coded Chinese strings. → Cursor (below). |
| BWALL-3 | Blocked by `Tests/ContractChecks/test_object_badge_wall_layout.py` (pins the list default, the layout switch and the three sections). Waiting for the Cursor un-pin. |
| OCARDS-3 | Blocked by `test_native_ui_accessibility_semantics` (`Menu {` pin). Waiting for the Cursor un-pin; then mount `ObjectCardCategorySheetView`. |
| ROAM-9 / PLAY-6 | Needs Core preference state (BGM, 旁白, reduce-motion, fog, map style) and runner / greet wiring first. `CastRosterButton` is already mounted (`App/PlayExperienceView.swift:139`). |
| JSEAT-r8-1 (write) | No `transfer-phone` contract in Core / route admission. The sheet is ready; the host passes `onTransfer` once Core lands. |
| Owner rows | RSTAMP-2, SCAM-1, SALBUM-1, JPROMO-3, JSEAT-8, JLAND-r7-1, ROAM-7, RPOI-4, RPOI-5/RROUTES-2, SCAM-2, GROWTH-5 — owner decisions, not taken. |
| Cursor rows | ROAM-8, RTEAMS-3b, RTEAMS-5, JSETTLE-r8-1 — Cursor Core, not taken. |

## For Cursor
1. **JSEAT-r8-1:** `POST /api/play/seat-invitations/transfer-phone {registrationId, seatNo, name, phone, requestId}` contract + route admission (player write, request-id idempotent), then wire `JourneySeatsView(onTransfer:)` in `JourneySeatsHost` (`(seatNo, name, phone, requestId) async -> JourneySeatTransferOutcome`; a lost answer → `.unconfirmed`, business error → `.failed(msg)`), re-read on success. Receiver side (`claim-phone`, `mine`) if ported.
2. **ROAM-13:** port the MP city-guide catalog (`roam-city-guide.js`: `nearestCity`, `stripFor`, `defaultCity`, items with seed / catLabel / reason) to Core, then I mount the 本城推荐 tab in `RoamEntryPeekView`.
3. **BWALL-3:** un-pin `test_object_badge_wall_layout` (list default, layout switch, three sections) so the 2-col 已点亮 / 未解锁 grid can replace them.
4. **OCARDS-3:** drop the `Menu {` pin in `test_native_ui_accessibility_semantics`.
5. **ROAM-9 / PLAY-6:** play + live-roam preference state and `PlayRoamGapService` runner / greet wiring.
6. **TeamTrailModel.canRun** (Core/PlayerGapRoutes.swift:460) should also require `state.decided` (MP L01-039); the App now guards it, Core should too.
7. **RTEAMS-1 polish:** `NearbyTeam` has no `startDate` (MP row sub line `M/D HH:mm · address`, scope `… · X月X日 HH:mm 场`) and decodes `memberAvatars`, while the MP topic card reads `memberAvatarsJoined` (CSV). Add both and I will show the time and faces.

## Checks run (Python contract checks, no Swift)
- OK: `test_object_badge_wall_layout`, `test_roam_history_live_entry`, `test_roam_share_photo_save`, `test_native_ui_accessibility_semantics`, `test_native_repair_batch_integration`, `test_nearby_*` (4), `test_ui_workbench_navigation`, `test_global_chrome_domain_contract`, and the 18 topic / platform-consumer checks that read `TopicDetailView.swift` / `PlatformConsumerSessionOwner.swift`.
- Already failing on the base, unchanged by this branch: `test_topic_creator_attribution` (`umsMember`), `test_wallet_ui_first_current_bindings` (workflow hash), `test_category_roam_registration`.
- Not verified at runtime: no simulator here. Please compile and run `ObjectCardFlowTests` (pile tiles keep `objects.card.<id>`; a tap pushes the detail) and the nearby map flow.

## Skipped because another branch covers it
- `restyle/*` (visual only), `cursor/*`, `gap/*`, `port/*`: not touched.
