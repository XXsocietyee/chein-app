# Parity audit r11: play-roam

Brief: `origin/design/handoff-r2:docs/briefs/audit-r11.md`. Reviewer only: no product code was edited.

- **App audited:** `origin/ui/combined-r7` @ `b9a9d4d29` (r10 audited `82bcf2c2d`, 588 commits earlier). All 11 r10 lanes are merged.
- **MP:** `origin/mp-source:chengyinhub-xcx/` (hengyin master snapshot 2026-11-24). It was **readable this round**. r10 carried MP refs from r9 (`06a1639d`), so this is the first re-diff against a fresh MP. Most of the new rows below are MP behaviour that r9/r10 did not see or that landed in the MP after 06a1639d (D-68/D-77 2026-11-11, D-73 2026-11-11, CG-ALL-11 2026-11-17, F06 chapter video, Cast v1 2026-11-19).
- **Scope (owner 11-26):** player side. Money is ON (payment, refund, payout, withdrawal); virtual goods are OFF. Score is function + MP behaviour + "uses Apple components", not looks. No row in this area is merchant-center only (`pages/play/merchant` is the player-side store-day page).
- **Method:** every r10 §2/§5 row was re-read in code at the tip (grep + read), not taken from receipts or commit messages. Each MP page was then re-scanned for gaps: every `/api/...` path in pages/play, pages/playkit, pages/roam, subpackageRoam, subpackageJourney, subpackageTools and subpackageP3 was matched to a Core client (all of them matched), and then MP user actions and gates were compared. Every new P1 was confirmed by reading the app code. Same page list and parity formula as r10: present = ✅ + ⚠️ + 🔒 over lines.
- **Not compiled, not run** (no Swift toolchain). Runtime claims come from reading the code.

## 1. Parity table

| # | MP page | r10 | **r11** | Δ lines | note |
|---|---|---|---|---|---|
| 1 | pages/roam/index (+ free explore / live roam) | 36/36 | **36/45** | +9 missing | new MP-scan rows ROAM-r11-1…9 |
| 2 | pages/play/index (runtime) | 32/33 | **32/40** | QA table retired (−1 den), +8 missing | QA-r9-1 retired: the current MP has no `table`/`lastRule` (`pages/playkit/components/playkit-qa/index.wxml`, FEATURES in `pages/play/utils/client-capabilities.js:22`) |
| 3 | pages/play/merchant (player store-day) | 20/20 | 20/20 | — | |
| 4 | pages/play/circle | 3/3 | 3/3 | — | retired link page, kept for old share links until 2026-12-31 |
| 5 | pages/play/poi-challenge | 14/14 | 14/14 | — | |
| 6 | subpackageRoam/citynode-code | 9/9 | 9/9 | — | |
| 7 | subpackageRoam/history | 14/14 | 14/14 | — | ROAM-r11-10 (route thumb) still to verify, not counted |
| 8 | subpackageRoam/poi-detail | 19/20 | **20/20** | +1 | RPOI-4 share fixed |
| 9 | subpackageRoam/session | 15/15 | 15/15 | — | |
| 10 | subpackageRoam/nearby | 20/20 | 20/20 | — | |
| 11 | subpackageRoam/citystamp | 12/12 | 12/12 | — | |
| 12 | subpackageRoam/my-teams | 17/17 | 17/17 | — | |
| 13 | subpackageRoam/official-routes | 7/7 | 7/7 | — | |
| 14 | subpackageRoam/official-route | 9/9 | 9/9 | — | |
| 15 | subpackageJourney/landing | 23/23 | **23/25** | +2 missing | JLAND-r11-1 seat claim, JLAND-r11-2 gift claim |
| 16 | subpackageJourney/seats | 22/23 | **23/23** | +1 | seats-save fixed |
| 17 | subpackageJourney/promo | 12/12 | **12/13** | +1 missing | JPROMO-r11-1 payout footer |
| 18 | subpackageJourney/settle (+ report share) | 26/26 | **26/27** | +1 missing | JREF-r11-1 referral token |
| 19 | subpackageJourney/report | 24/24 | 24/24 | — | |
| 20–23 | subpackageTools (goals, export, anniversary, recap) | 55/55 | **55/56** | +1 missing | TGOALS-r11-1 |
| 24 | subpackageP3/growthcenter | 19/19 | 19/19 | — | |
| 25 | subpackageP3/growthcenter/leaderboard | 14/14 | 14/14 | — | |
| 26 | subpackageP3/stamp-camera | 13/13 | **13/14** | +1 missing | SCAM-r11-1 |
| 27 | subpackageP3/stamp-album | 15/15 | 15/15 | — | |
| 28 | subpackageP3/badge-wall | 14/14 | 14/14 | — | |
| 29 | subpackageP3/badge-3d | 10/10 | 10/10 | — | |
| 30 | subpackageP3/object-cards | 14/14 | **14/15** | +1 missing | OCARDS-r11-1 |
| | **Area** | **488/491 · 99.4 %** | **490/514 · 95.3 %** | +2 present, +23 den | |

**Why the score dropped:** there are no regressions. 2 r10 gaps closed and 1 MP line retired, but the fresh MP snapshot adds 24 lines that r10 never measured: 11 P1 + 13 P2 counted (RPOI-5 title and ROAM-r11-10 are not counted as lines). Measured against r10's line set only, r11 is 490/490 = **100 %**.

**Apple components (not scored, per the r11 brief):** roam-b's finding holds. `CYPillButton` (App/DesignSystem/CYPillButton.swift:97-117 → `.borderedProminent`/`.bordered`/`.borderless`), `CYStatusChip` (`Label`), `CYEmptyState` (`ContentUnavailableView`, App/DesignSystem/CYStates.swift:54), `CYSkeleton` (`.redacted`), `CYHeroHeader`, `CYNoteBanner`, `CYStepIndicator` (`ProgressView`) and `CYChoiceRow` now render system controls. The r10 grep counts of these overstated the custom chrome. The hand-drawn chrome still left is listed as P2 rows N-r11-* in §3.

## 2. r10 rows → r11 status (code-checked at `b9a9d4d29`)

| r10 id | sev | **r11** | evidence |
|---|---|---|---|
| PLAY-6a | P1 | **partly** | Sheet mounted as `NavigationStack { Form }` with `Toggle`s, App/MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift:74-107; menu row App/PlayInPlayTools.swift:222-223; mount App/PlayExperienceView.swift:687-696 (`aa2cd85b9`, `3e34211e2`). **But** the BGM toggle only stores `play.bgmOn`: no theme/station music is played anywhere (grep `topicAudio`/`numberOfLoops`/`isLooping` = 0). MP plays theme BGM (`pages/play/index.js:4119-4127`) and station BGM (`:4174-4199`). Split out as PLAY-r11-1. |
| QA-r9-1a/b | P1 | **retired** | Current MP FEATURES = `hangman.pool`, `qa.letterPool`, `role.views` (`pages/play/utils/client-capabilities.js:22`); no `lastRule`/`table` in `pages/playkit`. Replaced by CAP-r11-1. |
| OCARDS-3b | P1 | **fixed** `3739e5d99` | toolbar `Menu` App/ObjectCardViews.swift:33-41, `.toolbar` :116 |
| BWALL-3b | P1 | **fixed** `d9d0bd767` | no `Picker`; `LazyVGrid` App/ObjectBadgeViews.swift:94; 已点亮/未解锁 Sections :77, :83; `.grayscale` :153 |
| JSEAT-8 | P1 | **fixed** `46f07b3d5` | `.navigationTitle("mp.seats.title")` (开局大厅) App/JourneyLandingViews.swift:594 |
| RPOI-5 / RROUTES-2 | P1 | **fixed** (P2 residue) `70850364e`, `4c4b0d4e3` | `roam.detail` = 据点; 0 `officialRoute.*` zh values still say 路线. Residue: MP title is 据点详情 (`subpackageRoam/poi-detail/index.json:3`) → RPOI-r11-1 (P2). |
| GROWTH-5 | P1 | **fixed** `26d69ef0a` | `GrowthProfileDisc` App/GrowthCenterView.swift:152, :314-326 (`CYAvatarView`, `d_profile` fallback, no ring) |
| RPOI-4 | P1 | **fixed** `ee3be0e5c` | `poiShareButton` App/RoamItemDetailView.swift:58-63; `PublicContentShareLink.poi` Core/PublicContentShareLink.swift:56; AASA docs/release/aasa.json:23 |
| N-PLAY-DARK | P1 | **fixed** `de785d659` | `screenDomain` `.player` App/PlayExperienceView.swift:731, :142-144; App/PlaySessionView.swift:45-46 |
| N-KIT-DARK | P1 | **fixed** `621abbdde` | App/PlayKitScreen.swift:424-425; `.confirmationDialog` :88 |
| N-KIT-FORMS | P1 | **partly → P2** | system controls now (`8e72b2f05`, `5b6c197b3`, `748805cc2`); not a `Form` because the shared kit container also hosts inline kits. Accepted under r11 (Apple components, not layout). |
| N-PLAY-MAP | P1 | **partly → P2** | `3d8015537`; `CYMapScaffold` in-view panel App/PlayExperienceView.swift:860; flag-off fallback only (default run is `CityOrientationRunView`). Custom overlay modal `cyModalConfirm` :186, :1260, :1279, :1896 → N-r11-1. |
| N-ROAM-MAP | P1 | **partly → P2 / owner** | `d0bbdd3ca`; `CYMapScaffold` App/RoamBrowserView.swift:494. `MapUserLocationButton` blocked by pinned privacy contract `test_map_camera_controls` → owner decision. |
| N-ROAM-LIVE | P1 | **fixed** | `Map` + `MapUserLocationButton` App/RoamLiveSessionView.swift:241-244. Behaviour gap behind it → ROAM-r11-3. |
| N-ORIENT | P1 | **fixed** `617ec496a`, `cbab1268b`, `2283c7b3b` | CityGamePanel system buttons/GroupBox; OrientScore on `.player` |
| N-RHIST | P1 | **fixed** `66a5a4794` | `List` … `.insetGrouped` App/RoamHistoryViews.swift:28-111 |
| N-RNEAR | P1 | **partly → P2** | no net change (`b19eaae37` reverted in `22b296055`); `CYMapScaffold` App/NearbyTeamMapViews.swift:68 |
| N-RTEAMS | P1 | **fixed** (ScrollView kept) | `02ed74614`, `ae971c82f`, `dea0efdb2`; `CYMapScaffold` App/NearbyTeamViews.swift:85 is the shared map header → folded into N-r11-2 |
| N-JOURNEY-1 | P1 | **fixed** (P2 residue) `9a56ff29f` | GroupBox + LabeledContent App/JourneyLandingViews.swift:337-345; residue `MPNightGround` :316, `MPBottomBar`/`CYMorphButton` :352-357, `MPSectionHeader` :91 → N-r11-3 |
| N-JOURNEY-2 | P1 | **fixed** `7e195e7cc` | `.borderedProminent` + `confirmationDialog` |
| N-JOURNEY-3 | P1 | **fixed** (P2 residue) `4b806af1c` | report `List` App/JourneyReportViews.swift:539-603; residue rank sheet `MPCard`/`MPDivider` :320-353, `CYResultPhase` :985 → N-r11-3 |
| N-ALBUM | P1 | **fixed** `ad2afa80e` | default `NativeStampAlbumView` (App/RoamStampViews.swift:34-36, flag default on App/NativeR2/NativeR2Flags.swift:8-14); flip/foil only on the flag-off legacy path :387-427 |
| N-KIT-CHOICE | P2 | **fixed** `e611c53c2` | |
| N-KIT-BUTTONS | P2 | **fixed** (wrapper is system) | CYPillButton.swift:97-117 |
| N-KIT-QUESTO | P2 | **fixed** `5237cfd2b` | 0 `rotation3DEffect` in App/PlayKitQuestoViews.swift |
| N-ROAM-HOME | P2 | **fixed** `88410130d` | 0 `Color(red:)`/`.shadow` in App/RoamHomeTabsView.swift; `CYImageCard` :251 remains (P2, in N-r11-4) |
| N-RCODE | P2 | **fixed** `cc9769c52`, `0fb9ec786` | ScrollView kept for the QR |
| N-RPOI | P2 | **fixed** `36212f053` | |
| N-RSESS | P2 | **open (blocked)** | `CYShareComposer` App/RoamHistoryShareView.swift:49; design-system follow-up |
| N-ROUTES | P2 | **fixed** | |
| N-RSTAMP | P2 | **partly** `093085f95` | stamp slip `RoundedRectangle` ×5 App/RoamSubpageParityViews.swift:563-625, `cyNightGlass` :145 → N-r11-4 |
| N-MERCHANT | P2 | **fixed** `2a4c08ef8`, `acc950285` | |
| N-POICH | P2 | **fixed** `277a0e081` | |
| N-OCARDS | P2 | **fixed** `53c20f5b4` | |
| N-GROWTH | P2 | **fixed** `efc9a3667` | segmented `Picker` App/GrowthLeaderboardView.swift:270-275 |
| N-TOOLS | P2 | **fixed, needs compile** `5c697bf2e`, `d9224d027`, `3b8720fcc` | `BarMark` + `.chartXSelection` App/RoamPassportToolsViews.swift:828-838 (receipt flags the `Binding<String?>` selection) |
| N-B3D | P2 | **partly** `6d6cb47d3` | turntable gone, but the badge detail stage is still `CYFlipCard` + `CYFoilMedal` + `LinearGradient` App/ObjectBadgeViews.swift:283-295 → N-r11-5 |
| seats-save | P2 | **fixed** `375835507`, `e0f6324ca` | `ShareLink` of the rendered image App/JourneyLandingViews.swift:869-872 |
| ROAM-7, JSEAT-r8-1b, RTEAMS-3c, ROAM-8b, ROAM-9a/b, SALBUM-r9-1 (r10 fixed) | — | **still fixed** | transfer App/JourneyLandingViews.swift:529-536; `leaderApplicantFact` App/NearbyTeamViews.swift:534; tile thumbs App/RoamHomeTabsView.swift:606-608; 45 s / 3000 m App/RoamLiveSessionView.swift:221-231; tools sheet :154; `allowsRemoteImages` App/RoamReceivedStampMetadataView.swift:225, :290 |
| other carried P2 (SALBUM-6, TGOALS-4/-6, TANNIV-4, TEXPORT retry, GROWTH-9/LEADER-7, official-route #7, B3D-1, RTEAMS-1 polish, `TeamTrailModel.canRun`) | P2 | **not re-verified** | r10 carried them without file:line, and their detail lives only in the r9 report. The fresh MP scan of these pages (tools, P3) found no gap under these ids. Treat them as closed unless r12 re-opens one with a citation. |

## 3. Open counts

| | parity | Apple-components | **total** |
|---|---|---|---|
| **P0** | 0 | 0 | **0** |
| **P1** | 11 | 0 | **11** |
| **P2** | 15 | 6 | **21** |

## 4. Fix queue (P0 first; no P0)

Size: S ≤ 1 agent-hour, M ≈ 2–3 h, L = split across lanes.

| id | sev | MP file:line | app file:line | what to change | size |
|---|---|---|---|---|---|
| JLAND-r11-1 | P1 | subpackageJourney/pages/landing/index.js:144-157, 171-199 (`_claimSeat` 领取席位 → 进入本局) | App/MPParityKit.swift:12 (`claimsEnabled = false`); App/JourneyLandingViews.swift:354 (`MPGatedNote("mp.gate.claim")`); App/PlayerJourneyReadBindings.swift:89-97 | Seat claim isn't money or virtual goods (Core/JourneyLoopSource.swift:644 `seatClaim … money: false`). The app sends seat invites, but an invited friend can't claim one. Split the gate: add `MPCommerceGate.seatClaimsEnabled = true` and use it for `.claimSeat` and the seat claim-result check. Gift claims stay on `claimsEnabled`. | S |
| JREF-r11-1 | P1 (money ON) | subpackageJourney/pages/settle/index.js:264-279; report/index.js:132-147 (`onShareAppMessage` → `issueReferral` → `landing?k=r&t=`) | Core/JourneyLoopSource.swift:229-232 (`issueReferral` throws `moneyOff`); App/PlayerJourneyReadBindings.swift:1379-1393 (plain topic link), :522, :724 | Money is ON for this release, so implement `issueReferral` (`POST /api/marketing/referral/token`, Core/JourneyLoopSource.swift:640). Call it only when the player taps share, as the MP does (点分享才签发), not on load, and append `k=r&t=<token>` to the landing link. | M |
| CAP-r11-1 | P1 | pages/play/utils/client-capabilities.js:20-22 (STORY_BLOCKS includes `branch`, `line`; FEATURES includes `role.views`) | Core/PlayContentCompatibility.swift:93-94 (storyBlocks has no `branch`/`line`), :103 (features has no `role.views`); Tests/CoreTests/PlayClientCapabilitiesTests.swift:29, :63; Tests/CoreTests/HangmanPoolTests.swift:188 | The app renders `line` (Core/ChapterStoryContracts.swift:251, App/ChapterStoryView.swift:416-430), `branch` (:261, hidden without cast as in the MP) and the role card (App/JourneyRoleViewSection.swift via App/PlayJourneyContentViews.swift:9). Because they're undeclared, the server returns 409 CONTENT_CAPABILITY_UNSUPPORTED before any run whose content uses Cast lines or role views. Add the three keys, update the stale "branch is not listed" comment, and flip the three tests to assert presence. | S |
| PLAY-r11-1 | P1 | pages/play/index.js:4117-4127 (`_startThemeBgm`, `topicAudioUrl`, loop, low volume, ducked under narration), :4174-4199 (`_syncStationBgm`), wxml:456 | App/PlayExperienceView.swift:696 (`$playBGMOn` stored only); Core/ChapterStoryContracts.swift:113-119 (`PlatformBGMPreference`) | Decode the theme `audioUrl` (topic) and the station `music.audioUrl`. Add a looping `AVAudioPlayer`/`AVPlayer` at low volume, started on 开始游戏 and following `PlatformBGMPreference`. Duck it under narration, switch to the station track when it differs (compare the file URL without the query) and stop on exit. | M |
| START-r11-1 | P1 | pages/play/utils/run-start-mode.js:1-40 (CG-ALL-11); play-help.wxml:70 (换个方式开局); index.js:6371, :7601 (`_startModeParams` merged into `/api/play/arrive`) | Core/PlayContracts.swift:494-516 (`PlayRunStartRequest` built, not sent); `altStations` decoded :323, :364; no UI | City orientation, before the first station is done: add a 换个方式开局 `.confirmationDialog` with 改在「X」开局 per alt station and 桌面完成, and the note 不用到现场，这一局只得探索值与徽章. Send `startMode` / `altStationId` on the first arrive. Today a player who can't reach the start (300 m) can't begin. | M |
| BGPAUSE-r11-1 | P1 | pages/play/index.js:1210-1217 (D-68/D-77: going to the background doesn't pause; the clock keeps wall time and audio keeps playing) | App/PlayExperienceView.swift:298-301 (`pauseRun` on any `scenePhase != .active`) | Remove the scenePhase pause for city orientation, or keep it only for preview/mock. Pause only on real page exit (`onDisappear` with the run not started or disposed). Elapsed time then matches the MP/server. Check that `PlaySessionLocationHold` (:296) still holds. | S |
| ZEROHP-r11-1 | P1 | pages/play/theme-backpack.wxml:17-30; pages/play/utils/theme-backpack.js:100-158 (同步恢复状态 → `ZERO_HP_SYNC`; `deadlineAt` countdown auto-syncs; 同步微信运动 → `ZERO_HP_STEPS`) | App/PlayThemeBackpackView.swift:450-460 (read-only) | When `availableActions` has `ZERO_HP_SYNC`, add a 同步恢复状态 `Button` that sends the gameplay command, plus a `TimelineView` countdown to `deadlineAt` that auto-syncs at 0. STEPS policy: owner/server decision (WeRun is WeChat-only), so show the policy text until then. | M |
| VIDEO-r11-1 | P1 | pages/play/index.wxml:2072-2077; pages/play/chapter-video.js:1-3 (F06 muted autoplay, 跳过 / 开声音); index.js:4062, :4505, :4911 (`videoUrl`, `videoPosterUrl`) | none (grep `videoUrl` in Core = node audio only, Core/PlayExperienceContracts.swift:164) | Decode chapter `videoUrl` / `videoPosterUrl`. On chapter open, show a full-screen muted `VideoPlayer` (AVKit) with 跳过 and a sound toggle; BGM/narration keep going until sound is on. Close on end or after a 5 s load timeout, then start chapter audio. | M |
| ROAM-r11-1 | P1 | pages/roam/index.wxml:335-349; index.js:920, :1927-1975 (`POST /api/official/events/{id}/arrivals` with `sessionId` + GCJ-02 fix), :4884-4890 (V1 `/complete`) | App/OfficialActionViews.swift:356 (`arrival` always nil; 0 `OfficialArrivalEvidence(` constructions); App/OfficialOrganizerConsoleView.swift:539-543 (`rootTabSwitch(.roam)` drops the event id) | Carry `eventId`/`missionCode` into the live roam. Add the in-roam 官方活动 · 到达验证 list that builds `OfficialArrivalEvidence` from the live session id + `RuntimeLocationProjection.gcj02(fix)`, and call `/complete` after finish for roam-bound V1 events. Split: routing (S) + in-roam list/submit (M). | L |
| ROAM-r11-2 | P1 | subpackageRoam/components/cy/scene-roam-task-list/index.js:62-66 (D-73: `GET /api/official/active-for-roam`, guests included) | Core/RoamOfficialTasks.swift:73 (`official.events(city: nil)`, login required); the route exists, Core/PlayerGapRoutes.swift:35, :130 | 全部 tab: read `active-for-roam` (reuse the PlayerGapRoutes reader), admitted for guests; keep `myEvents()` for 我的. | S |
| ROAM-r11-3 | P1 | pages/roam/index.wxml:301-433 (POI markers, photo pins, 附近 N 个地点); photo-pins.js; node-level-style.js; index.js:2575, :2827-2842 | App/RoamLiveSessionView.swift:236-244 (`PersonalFogFeature.liveRevealEnabled = false`, Core/PersonalFogLedger.swift:11, so the map is `Map { UserAnnotation() }`; `onSelect: { _ in }`); Core/RoamContracts.swift:203 (`nodeLevel` has 0 readers) | In the non-fog branch, add `Marker`s for the session's nearby places, tinted by `nodeLevel` (普通 / 精选 / 官方合作). Tapping one opens the existing place card, and photo pins become `Annotation`s. Keep it independent of the fog flag. | M |
| PLAY-r11-2 | P2 | pages/play/index.wxml:325; pages/play/utils/evidence-cards.js:1-15 (证据卡 = `passText` of finished stations) | App/MPGap/PlayRoam/PlayToolsAndLeadSheetView.swift:146-150 (count only) | Add a 证据卡 `Section`/`List` (station name + `passText`) reachable from the 游玩工具 menu. | S |
| PLAY-r11-3 | P2 | pages/play/play-help.wxml:47, :68; utils/stage-events.js:36-50 (这一站有问题, 4 categories, `stage_issue_report`, toast 已记录) | Core/PlayGameStage.swift:111 (`PlayStageAnalyticsGate.enabled = false`); menu App/PlayGameStageViews.swift:166 | Enable the gate (reviewed-route lease for the analytics write) so the report menu shows. | S |
| ROAM-r11-4 | P2 | pages/roam/index.wxml:831-832; index.js:2914-2933 (打个招呼 → `POST /api/im/start`; 看 TA 的漫游) | App/MPGap/PlayRoam/RoamSessionToolsSheetView.swift:4-5 (wrong comment), :66-94 (rows not tappable); key `roamTools.runners.greet` unused | Make runner rows a `Menu`/`NavigationLink`: greet via Core/SocialMemberActionFactory.swift:10 path, then open chat; profile link. Fix the doc comment. | S |
| ROAM-r11-5 | P2 | pages/roam/index.wxml:743; index.js:5593-5616 (mid-session presence toggle + 单独同意位置分享 consent, `POST /api/roam/presence-visibility`) | App/RoamLiveSessionView.swift:323 (pre-start only), :342 (read-only label) | Add a `Toggle` in the tools sheet; turning on shows the consent `.confirmationDialog`, then posts presence-visibility. | S |
| ROAM-r11-6 | P2 | pages/roam/index.wxml:701-709, :766; index.js:5637-5651 (清空本机缓存 + revoke shared footprint links) | none; keys `roamTools.clearCache`, `roamTools.clearCache.confirmTitle` unused; Core/RoamPlayerExtrasService.swift:59 `revokeShareSnapshots()` | Destructive row + `.confirmationDialog` in the tools sheet: wipe the local roam journal, then call `revokeShareSnapshots()`. | S |
| ROAM-r11-7 | P2 | pages/roam/index.wxml:960-990; index.js:4643-4675 (首次发现 sheet: 领优惠券 / 做微任务 / explore-day via `GET /api/roam/nearby-exploreday`) | Core/RoamLiveSessionController.swift:444 (first discovery); Core/RoamReading.swift:87 `roamExploreDay()` 0 callers | After the first shop discovery, present a `.sheet` with the 3 options routed to coupon wallet, task list and explore-day activity. | M |
| ROAM-r11-8 | P2 | pages/roam/index.wxml:59-63, :401-405 (资料来源 + copy links + credit); subpackageRoam/nearby/index.js:956-957, :1033, :1066 (`quotesJson`, photo credit) | App/RoamPlaceExtrasProduction.swift:270, :274 (`quotes: []`, `photoCredit: nil`); App/RoamCityGuideCatalog.swift (no `sources`) | Decode `quotesJson` / `photoCredit` from the node detail; add `sources` to the city catalog; show a `DisclosureGroup` with `Link` / copy rows. | M |
| ROAM-r11-9 | P2 | pages/roam/index.wxml:1031-1048; index.js:5045-5100 (谁能看到 公开/仅好友/仅自己 gates channels; 发到广场 → `/api/creativesquare/action`) | App/RoamHistoryShareView.swift:138-169, :278 | Add a visibility `Picker` that gates save/share and a 发到广场 action through the existing compose path (Core/SocialActionContracts.swift). | M |
| ROAM-r11-10 | P2 (verify) | subpackageRoam/components/cy/route-thumb/index.js:1-8 (real basemap in the chosen map style; schematic only without coords) | App/RoamHistoryViews.swift (trip rows) | Verify on a device. If the rows show only the schematic, use `MKMapSnapshotter` with the track polyline in the chosen style. Not counted. | S |
| JLAND-r11-2 | P2 | subpackageJourney/pages/landing/index.js:201-215 (`_claimGift` 领取 → 礼物已领取 → 去看看) | Core/JourneyLoopSource.swift:234-237 (`giftClaim` throws `moneyOff`); App/JourneyLandingViews.swift:354; live path App/MPParityPassSession.swift:693-711 (`PlatformPassGiftClaimSource`, "not a money write, owner rule 2026-11-25") | Route the journey gift claim through `PlatformPassGiftClaimSource` (same `/api/marketing/product/gifts/claim`, same requestId reuse). P1 if the owner rules gifts are not virtual goods. | S |
| JPROMO-r11-1 | P2 | subpackageJourney/pages/promo/index.wxml:6-13 (no payout copy; `canPayout` journey-view.js:391 never rendered) | App/JourneyLandingViews.swift:1025 (`MPGatedNote("mp.gate.payout")` "Record only. Payouts aren't open.") | Remove the footer (wrong now that money is ON, and the MP has none). | S |
| OCARDS-r11-1 | P2 | subpackageP3/pages/object-cards/index/index.js:450-458 (rename updates the cached card, toast 已改名) | App/ObjectCardViews.swift:145, :176 (`@State renamedTitle` local to detail) | Write the saved title back to the list model (or a shared store) so grid/pile show it; toast 已改名 (add key). | S |
| SCAM-r11-1 | P2 | subpackageP3/pages/stamp-camera/index/index.js:376-388 (toast 已入册, `redirectTo` stamp-album after 600 ms) | App/RoamStampCameraView.swift:130-140 (created mark + manual open) | On the P3 camera route (no exchange step), replace the stack top with the album after success. | S |
| TGOALS-r11-1 | P2 | subpackageTools/exploration-goals/index.js:35 (create writes at once) | App/RoamPassportPrivateToolsViews.swift:729-741 (extra 创建这个目标？ dialog) | Drop the create confirmation. Keep the cancel dialog, with the MP wording 此操作不可撤销. | S |
| RPOI-r11-1 | P2 | subpackageRoam/poi-detail/index.json:3 (据点详情) | Resources/Localizable.xcstrings `roam.detail` (据点) | zh-Hans 据点详情 for the pre-load nav title (en "Spot details"). | S |
| N-r11-1 | P2 | pages/play/index.wxml (wx.showModal) | App/PlayExperienceView.swift:186, :1260, :1279, :1896 (`cyModalConfirm` = custom overlay, App/MerchantAreaPopupSurfaces.swift:58-93) | → `.alert` / `.confirmationDialog`. Keep the identifiers. | S |
| N-r11-2 | P2 / owner | pages/roam/index.wxml (map), subpackageRoam/nearby, my-teams | App/RoamBrowserView.swift:494; App/NearbyTeamMapViews.swift:68; App/NearbyTeamViews.swift:85; App/PlayExperienceView.swift:860 (`CYMapScaffold` in-view panel) | Owner decision: allow `MapUserLocationButton` (pinned `test_map_camera_controls`) and accept detached-sheet navigation. Otherwise accept the panel as-is. | M |
| N-r11-3 | P2 | subpackageJourney/pages/landing, settle, report | App/JourneyLandingViews.swift:91, :316, :352-357; App/JourneyReportViews.swift:320-353, :491, :985 | `MPNightGround` → system grouped background; `MPSectionHeader` → `Section` header; rank sheet `MPCard`/`MPDivider` → `List`; `CYMorphButton` → `.borderedProminent` + `ProgressView`. | S |
| N-r11-4 | P2 | subpackageRoam/citystamp; pages/roam/index | App/RoamSubpageParityViews.swift:145, :563-625; App/RoamHomeTabsView.swift:251; App/RoamCityGuide.swift:92 (`CYImageCard`) | Remove `cyNightGlass` and the slip shapes (keep the stamp image); `CYImageCard` → `NavigationLink` `Label` with `MPAsset` art. | S |
| N-r11-5 | P2 | subpackageP3/pages/badge-3d | App/ObjectBadgeViews.swift:283-295 (`CYFlipCard`, `CYFoilMedal`, `LinearGradient`), :262 `cyCelebrations` | Badge detail: image row + `LabeledContent` facts in a `List`, no flip/foil; keep `.sensoryFeedback(.success)`. | S |
| N-RSESS | P2 (blocked) | subpackageRoam/session | App/RoamHistoryShareView.swift:49 | Design-system follow-up for `CYShareComposer` (coordinator). Do together with ROAM-r11-9. | M |

## 5. Regressions

**None found.**
- Every r10-fixed row (§2) is still present at the tip.
- Scripted check over the 42 r10 lane commits in the roam-a/roam-b receipts: every `accessibilityIdentifier` removed by those commits was looked up at the tip. All 5 hits were false positives: interpolated ids that still exist (`cityGame.action.\(kind).\(property)` App/CityGamePanel.swift:145, `objects.category.\(…)` App/ObjectCardViews.swift:41) or ids retired on purpose with their tests updated (`objects.badge.layout`, `objects.badge.turntableHint`, `playx.answer.options` → per-option `playx.answer.option.<key>` App/PlayExperienceView.swift:1407).
- Not compiled. `fix(build)` commits on the branch (e.g. `49af0d3ad`) show earlier compile misses, so the N-TOOLS `chartXSelection` binding should go through a compiler before release.

## 6. Go-live blockers
**P0: none.** The 11 P1s are player-facing behaviour gaps. The ones most likely to stop a player outright are JLAND-r11-1 (an invited friend can't claim a seat), CAP-r11-1 (409 before Cast/role-view content), START-r11-1 (no way to start away from the start point) and ROAM-r11-1 (official-event arrival can't be verified). Owner decisions needed: N-r11-2 (map location button), ZEROHP STEPS policy on iOS, JLAND-r11-2 (are gifts virtual goods?).
