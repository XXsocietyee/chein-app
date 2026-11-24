# MP Gap Inventory — `play-roam`

- **Base:** `origin/ui/combined-r6` vs MP `hengyin/chengyinhub-xcx`
- **Excluded:**
  - **Port packages P1–P5** (`port/plan-r1:docs/port/ios-port-plan.md` §2.2): cast/roles/story reading (P1), arrival/free-explore story locks/offline archive/visit-config (P2), route-detail chapter cards & 出发前 (P3), game kits/pool/wrong-reply/stage header (P4), OR-023/PG-006/MC-055/FE-G5/FE-G6/MoneyDisplay/V-23 (P5).
  - **Restyle (visual only):** `.cyText` typography roll-ups, `cyPageTitle` / `CYSheetHeader` chrome-only swaps, spacing/radius/color token swaps, unit/noun copy-only tweaks.
  - **Cursor C2:** `backend-needed` §2 items.
- **Owner-gated items** (translated UI only, action stays gated): `RSTAMP-2` / `SCAM-1` / `SALBUM-1` (`mediaUpload` / `stampExchange` / stamp image policy), `JSETTLE-1` / `JREPORT-1` (referral token `moneyOff`).
- **Backend-blocked items:** `ROAM-7` (`GET /api/roam/entry/nearby` guest access), `PLAYM-2` (`GET /api/play/nodes` `perk` field).

---

## Functional Gaps (ordered largest-first for translation)

### 1. `PLAY-2` / `PLAY-3` / `PLAY-6` / `PLAY-8` — Play map, HUD scan/chapter switch, full tools sheet & captain lead tools
- **MP page & file:line:** `pages/play/index` (`index.wxml:102, 145, 280-470, 562-567`, `index.js:281+`)
- **What it does:** Renders real `PlayRouteMapView` in `CYMapScaffold`'s `map:` slot; adds HUD `扫码到达` circle & `切换章节`; expands `PlayInPlayTools` into a full grouped sheet (人物表, 证据卡, 各站奖励, 伏笔, 本局读数, 队伍位置, 我的权益, 入场码, 背景音乐/旁白/动态效果 toggles); adds captain lead tools (`start`, `settle`, 扫成员票核销, 整团码).
- **API calls:** `POST /api/club/lead/start` (`{runId}`), `POST /api/club/lead/settle` (`{runId}`), `POST /api/registration/scan_group_member_ticket` (`{code}`)
- **App screen:** `PlayExperienceView` / `PlayHUD` / `PlayInPlayTools`
- **Type:** `NEW-SECTION`
- **Size:** `L`

### 2. `ROAM-3` / `ROAM-4` / `ROAM-8` / `ROAM-9` — Roam live sheet layout, passport photo tiles & in-session tools
- **MP page & file:line:** `pages/roam/index` (`index.wxml:142, 155, 176-196, 225-255, 727-825, 856-890`, `index.js:282-826`)
- **What it does:** Sheet presentation for `RoamBrowserView`; full-bleed map + top glass HUD pill + draggable sheet on `RoamLiveSessionView`; 154 pt photo tiles (latest track/stamp/goals) in passport; in-session `更多` sheet with `附近正在走的人` (say hi / view roam), fog toggle, map style, and clear-local-cache confirm.
- **API calls:** `GET /api/roam/nearby-runners`, `POST /api/roam/greet` (`{userId}`)
- **App screen:** `RoamLiveSessionView` / `RoamHomeTabsView` / `RoamBrowserView`
- **Type:** `NEW-SECTION`
- **Size:** `L`

### 3. `RNEAR-2` / `RNEAR-7` — Nearby teams full-bleed map + draggable sheet + avatar pins
- **MP page & file:line:** `subpackageRoam/nearby/index` (`nearby/index.wxml`, `nearby/index.js:451`)
- **What it does:** Full-bleed map with leader `CYAvatar` pins and a draggable `.sheet` (`presentationDetents([.height(64), .medium, .large])`) containing team list/cards, with range/style/我的队伍 controls as map corner glass buttons.
- **API calls:** `POST /api/team/nearby` (`{lat, lng, radiusKm}`)
- **App screen:** `NearbyTeamViews` / `NearbyTeamMapViews`
- **Type:** `NEW-SCREEN`
- **Size:** `L`

### 4. `RSTAMP-3` — Citystamp tear + scratch-off interaction & reveal gate
- **MP page & file:line:** `subpackageRoam/citystamp/index` (`index.wxml:93-136`, `index.js:278, 287, 330-423`)
- **What it does:** `DragGesture` tear on the slip + `Canvas` scratch-off mask (60% threshold; Reduce Motion → tap-to-reveal); gates `收下，出发` until revealed. Create/exchange writes remain behind `RoamExperienceCapabilities.mediaUpload`/`stampExchange` (owner-gated).
- **API calls:** `POST /api/roam/stamp/create`, `POST /api/roam/stamp/exchange` (owner-gated)
- **App screen:** `RoamSubpageParityViews` (`RoamCityStampFlowView`)
- **Type:** `NEW-SECTION`
- **Size:** `L` *(writes owner-gated)*

### 5. `OCARDS-2` / `OCARDS-3` / `OCARDS-4` — Object cards pile physics, category sheet & sheet-based rename
- **MP page & file:line:** `subpackageP3/object-cards/index` (`index.wxml:1-5, 14-24, 45-52, 90-99`, `index.js:415-470`)
- **What it does:** Hosted 2D pile of latest 40 thumbnails with drag/fling + `✦` gather toggle (grid kept for VoiceOver/Reduce Motion); toolbar filter chip opening 3-column category icon sheet; rename converted from `.alert` to a sheet with 64-char counter, inline error, and signed-out login CTA.
- **API calls:** `POST /api/object-card/rename` (`{id, name}`)
- **App screen:** `ObjectCardViews` / `PlayerGapViews`
- **Type:** `NEW-SECTION`
- **Size:** `L`

### 6. `RHIST-1` / `RHIST-2` — Merged server + local roam history with partial-failure banner
- **MP page & file:line:** `subpackageRoam/history/index` (`scene-roam-history/index.js:92-127`, `index.wxml:6`)
- **What it does:** Merges `RoamPassportHistoryCoordinator.items` into `RoamHistoryView` (deduped by timestamp/sessionId) with bottom `加载更多` paging and an inline retry banner when server fails while local rows exist.
- **API calls:** `GET /api/roam/history/list` (`{pageNum, pageSize}`)
- **App screen:** `RoamHistoryViews` / `RoamPassportHistoryView`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 7. `RPOI-2` / `RPOI-3` / `RPOI-4` / `RPOI-7` / `RPOI-8` — POI detail unified actions, pending check-in recovery, share, review delete & inline gallery
- **MP page & file:line:** `subpackageRoam/poi-detail/index` (`index.wxml:12-19, 47-53, 72, 77-82, 103-108`, `index.js:60-74, 134-148, 618-633`)
- **What it does:** Consolidates actions into one row (`收藏 / 导航 / 投一张`) + pinned footer (`导航` + primary CTA); persists uncertain check-in attempt for `查询当前状态` / `重新现场核验`; adds `ShareLink` in toolbar; adds swipe-to-delete on own reviews; renders inline 4:3 `TabView(.page)` gallery.
- **API calls:** `POST /api/comment/delete` (`{id}`)
- **App screen:** `RoamItemDetailView` / `RoamPOIActions`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 8. `SCAM-2` — Stamp camera viewfinder-first flow
- **MP page & file:line:** `subpackageP3/stamp-camera/index` (`index.wxml:9-34`, `index.js:341-413`)
- **What it does:** Opens framing camera directly on appear (after primer), removes intermediate consent toggle, uses single 62 pt shutter, and shows inline error card on photo with MP retry titles. Create write remains owner-gated (`mediaUpload`).
- **API calls:** `POST /api/common/uploadOSS`, `POST /api/roam/stamp/create` (owner-gated)
- **App screen:** `RoamStampCameraView` / `RoamStampFramingCamera`
- **Type:** `NEW-SECTION`
- **Size:** `M` *(create owner-gated)*

### 9. `BWALL-2` / `BWALL-3` — Badge wall server medal art & 2-column 已点亮/未解锁 grid
- **MP page & file:line:** `subpackageP3/badge-wall/index` (`index.wxml:45-63, 97`, `index.js:21-23`)
- **What it does:** Loads `badge.image` into `CYFoilMedal` with glyph fallback and desaturated locked state; drops list/wall toggle in favor of 2-column grid grouped by `已点亮` / `未解锁`.
- **API calls:** `GET /api/badge/wall`
- **App screen:** `ObjectBadgeViews`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 10. `B3D-1` — 3D showroom support for identity (`pin`) badges
- **MP page & file:line:** `subpackageP3/badge-3d/index` (`badge-wall/index.js:419-424`, `badge-3d/index.wxml:22-24`)
- **What it does:** Extends 3D medallion parameters to `.identity` (`pin`) badges using badge code glyph and category rarity.
- **API calls:** None
- **App screen:** `ObjectBadgeWallParityViews`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 11. `JREPORT-2` / `JREPORT-3` — Journey report node photos viewer & full leaderboard scopes
- **MP page & file:line:** `subpackageJourney/pages/report/index` (`report/index.wxml:53-54`, `report/index.js:178-197`, `journey-view.js:395-405`)
- **What it does:** Adds 44 pt node photo thumbnails that open a full-screen paged photo viewer, and threads `teamId`/`cityCode`/`countryCode`/`clubId` from choices into `/api/rank/list` so all board scopes populate.
- **API calls:** `GET /api/rank/list` (`{scope, topicId, activityId, teamId, cityCode, countryCode, clubId}`)
- **App screen:** `JourneyReportViews` / `PlayerJourneyReadBindings`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 12. `JSETTLE-3` / `JSETTLE-4` — Journey settle topic name fetch & 辅助完成/开局 overview cells
- **MP page & file:line:** `subpackageJourney/pages/settle/index` (`settle/index.wxml:28-29`, `settle/index.js:84, 88-97, 121`)
- **What it does:** Fetches `POST /api/topic/info-to-user {id}` when link lacks `topicName`, and displays `assistedCount` (`SKIPPED`/`REVEALED`) and `startModeText` in overview when present.
- **API calls:** `POST /api/topic/info-to-user` (`{id}`)
- **App screen:** `JourneyReportViews` / `PlayerJourneyReadBindings`
- **Type:** `NEW-SECTION`
- **Size:** `S`

### 13. Small (`S`) items
| ID | MP page & file:line | Function | API calls | App screen | Type |
|---|---|---|---|---|---|
| `ROAM-7` | `pages/roam/index` (`index.wxml:194-196`) | Guest read of `/api/roam/entry/nearby` (backend confirmation needed) | `GET /api/roam/entry/nearby` | `RoamHomeTabsView` | `NEW-ACTION` |
| `ROAM-13` | `pages/roam/index` (`index.wxml:142, 155, 176-192`) | City strip segmented header & live ticket count lines | `GET /api/roam/city-strip` | `RoamEntryPeekView` | `NEW-SECTION` |
| `PLAYM-2` | `pages/play/merchant/index` (`wxml:52-55`) | 本店权益 (`perk.name` + `perk.redeemRule`) card (blocked on backend field) | `GET /api/play/nodes` | `PlayStoreDayMerchantView` | `NEW-SECTION` |
| `PLAYPOI-4` / `5` / `6` | `pages/play/poi-challenge/index` (`wxml:7-10`) | Medal primary → citystamp `sign`, secondary → badge wall; error `返回地图`; `PlatformExternalMapHost` | None | `ChallengePOIView` | `NEW-ACTION` |
| `RTEAMS-3` / `6` | `subpackageRoam/my-teams/index` (`wxml:11, 16, 44`, `js:139-155, 240`) | Join-code toolbar button, leader pending applicant count, command recovery panel | `GET /api/team/applications` | `NearbyTeamViews` | `NEW-ACTION` |
| `RROUTE-4` | `subpackageRoam/official-route/index` (`wxml:107`) | 56 pt node thumbnail (`imgUrl`) on official route stops | None | `E1OfficialRouteParts` | `NEW-SECTION` |
| `JLAND-7` / `10` | `subpackageJourney/pages/landing/index` (`index.js:147`, `journey-view.js:319, 335`) | Formatted expiry date (`M月d日 HH:mm 前有效/领取`) & `先逛逛` fallback | None | `JourneyLandingViews` | `NEW-ACTION` |
| `JSEAT-6` | `subpackageJourney/pages/seats/index` (`index.js:120-122`) | Signed-out `.auth` phase with `登录` CTA instead of permission error | None | `PlayerJourneyReadBindings` | `NEW-ACTION` |
| `JSETTLE-1` / `JREPORT-1` | `subpackageJourney/pages/{settle,report}/index` (`js:228-245`) | Personal referral link share via `/api/marketing/referral/token` (owner-gated `moneyOff`) | `POST /api/marketing/referral/token` | `JourneyReportViews` | `NEW-ACTION` |
| `GROWTH-5` / `6` / `8` | `subpackageP3/growthcenter/index` (`wxml:17-22, 63`, `js:175-181, 507-525`) | Person row from session profile independent of rank; wire `growthExploreHomeAction`; hide `我的足迹` when all-zero | None | `GrowthCenterView` | `NEW-SECTION` |
| `LEADER-6` / `8` | `subpackageP3/growthcenter/leaderboard/index` (`wxml:59, 71-77`) | Leader avatars via `CYAvatar` + podium crown/rings; pass `growthExploreHomeAction` | None | `GrowthLeaderboardView` | `NEW-SECTION` |
| `SALBUM-6` | `subpackageP3/stamp-album/index` (`js:163, 176`) | Infinite scroll on last tile + `pageSize: 50` | `GET /api/roam/stamp/album` | `RoamStampViews` | `NEW-ACTION` |
| `TGOALS-4` | `subpackageTools/exploration-goals/index` (`js:74-76`) | Optional `progress: Int?` hiding bar when nil | None | `RoamExplorationGoals` | `NEW-ACTION` |
| `TANNIV-3` / `4` | `subpackageTools/anniversary/index` (`wxml:19`) | Confetti only when ≥1 row & not Reduce Motion; pass `routeDestination` in deep link | None | `RoamPassportToolsViews` | `NEW-ACTION` |
