# Receipt: fix-parity-play-roam

Brief: `origin/design/handoff-r2:docs/briefs/fix-parity-r1.md`. Findings: `origin/audit/parity-play-roam:docs/audit/parity/play-roam.md`.
Branch `fix/parity-play-roam` from `origin/ui/combined-r4` @ 0443305c8 (no newer combined-r4 commits at the last fetch).
Swift is not installed in the cloud, so nothing here was compiled; every change follows existing patterns and passes the static gates below.

## Gates

| gate | result |
|---|---|
| `python3 -B tools/check_scaffold.py` | PASS (4934 Swift files, page route table 263, appsession ratchet unchanged: AppSession.swift still 8171 lines) |
| `python3 -B tools/check_design_lint.py` | PASS. Typography lint: raw text style 1181 (=), Theme.Font 63 (=), raw size 67 (=), back chevron 15 → 14, hidden back 15 → 13, large title 26 → 21 |
| `python3 -B tools/contract_ratchet.py --check` | 195 failing vs baseline 184: the same 11 "new" failures as a clean `origin/ui/combined-r4` (workshop / merchant-station / project-editor / object-badge-wall, not in this area); **0 new from this branch**. Contract mirrors (ui-string docs, fragments) were updated for the copy changes; two contract tests were updated for adopted endpoints (store-day `api/play/arrive`, share-snapshot publisher behind its approval). |

## Status by finding

Verification uses the Debug build. "TEST account" = a signed-in China TEST account with the reviewed write gates on; without those gates every write below stays off and the page shows its dormant/unavailable line (that is the expected production state).

### P0

| id | status | files | local verification |
|---|---|---|---|
| ROAM-1 | fixed | Core/RoamPassportOverview.swift, App/RoamHomeTabsView.swift | Roam tab → 漫游护照与工具 → 漫游护照: with a TEST account the four readings match `GET /api/roam/passport/summary` (km = distanceM÷1000, 1 dp); break the network → 漫游护照读取失败 + 重试. Signed out / no server reader → local history fallback as before. |
| ROAM-2 | fixed | App/RoamLiveSessionView.swift, App/SessionRoamMediaViews.swift, App/RoamItemDetailView.swift | Live roam → confirm a place (探索 / 到店) → half sheet with the place name, 已打卡 HH:mm · 在这儿留下点什么, rows 城市贴纸 / 今日城市签 → push the citystamp flow with kind sticker / sign. Same two rows in a POI sheet's 你的状态 section. |
| RSTAMP-1 | fixed | same + App/MPReviewedPageScreen.swift, Core/MiniProgramPageLink.swift | As ROAM-2; also `chein://mp/subpackageRoam/citystamp/index?kind=sign&place=外滩` opens the flow titled 今日城市签 with the place. |
| RSTAMP-2 | blocked-owner | — | `RoamExperienceCapabilities.mediaUpload` / `stampExchange` stay `false` (owner ruling). The flow shows its dormant line (暂时无法从这里投递，留言没有发送。) instead of sending. |
| SCAM-1 | partial (owner) | App/RoamStampCameraView.swift | Stamp camera with `stampCameraEnabled`: after a shot, 存入集邮册 is disabled and the line 存入集邮册暂未开放，照片只留在本机，不会上传。 shows while create is gated, so no orphan upload and no "点「完成存入」" dead end. Enabling create is the owner's `mediaUpload` ruling. |
| SALBUM-1 | partial (owner) | App/RoamStampViews.swift, App/RoamHomeTabsView.swift, App/RoamExperienceHubView.swift | Passport → 集邮册 (metadata scope): the 打开集邮相机 entry / FAB now appear when the host passes the session camera. Remote stamp images in the metadata scope still need the owner's image-policy ruling (unchanged: 图片不可用). |
| PLAYC-1 | fixed | App/MPReviewedPageScreen.swift, Core/MiniProgramPageLink.swift | `chein://mp/pages/play/circle/index?topicId=12&inviteCode=AB12` → play runtime for topic 12; without topicId → 探索链接不完整 + 返回首页. (inviteCode / registrationId are validated but the runtime entry has no slot for them yet — the play page's own invite flow applies.) |
| PLAY-10 | fixed | same | `chein://mp/pages/play/index?topicId=12` / `?activityId=34` open the play runtime. play/merchant deep link: not routed (needs a run scope the MP link does not carry). |
| PLAY-1 | fixed | App/PlayExperienceView.swift | Fixture/TEST run: finish the last place of a chapter while on the play screen → medium sheet with the `journey/stage-end` narrative and 继续 at the bottom. 旅程手记 thought claims already run through ChapterStoryView (`journey/thought/sync`). |
| PLAYM-1 | fixed | Core/PlayStoreDayService.swift, Core/PlayStoreDayPresentation.swift, Core/PlayStoreDayCoordinator.swift, App/PlayStoreDayMerchantView.swift, tools/build_play_store_day_catalog.py, Resources/PlayStoreDay.xcstrings, Tests/CoreTests/PlayStoreDayTests.swift | Store-day page (free exploration store card): primary is 我已到店 → purpose prompt once → one GCJ-02 fix → `POST api/play/arrive` (behind the store-day proof gate and the route allow-list). Refusals: ARRIVE_TOO_FAR → 离这里还有约 N 米 + 重新定位; VISIT_SCAN_REQUIRED → 扫码解锁. 扫描门店码 / 拍摄到店凭证 live under ⋯ 更多. |
| PLAYPOI-1 | fixed (gated) | App/ChallengePOIPhotoCapture.swift (new), App/ChallengePOIView.swift, App/QuestifyApp.swift (1 env line) | POI sheet → 地点挑战 on a photo node: the URL text field is gone; 拍照 opens the camera, uploads through the scoped uploadOSS uploader (same live-write approval as the stamp, only when the challenge writer is live), then shows 照片已保存. Without the approval: disabled + 拍照打卡暂未开放，照片不会上传。 |
| PLAYPOI-2 | fixed | Core/RoamContracts.swift, Core/ChallengePOI.swift, App/ChallengePOIView.swift | The host reads `GET /api/city/nodes/{id}`; a validationMethod 3 node shows questionName + A–D and submits the letter; status ≠ 1 → 这个地点的挑战暂未开放; no photo / quiz → 这个地点还没有配置挑战; completed → 这枚勋章已经收藏过. `chein://mp/pages/play/poi-challenge/index?poiId=7` opens it. |
| RPOI-1 | fixed | App/RoamPOIActions.swift, App/AppSession.swift (closure signature only, line count unchanged), Tests/AppUnitTests/RoamPOIActionTests.swift | POI sheet 打卡 with a TEST account: method 1 → 完成互动 alert (输入答案 / 暗号); 3 → A–D option sheet (sends the letter); 2 → camera + upload; 4 → QR scanner (sends `code`); photoRequired shoots first; 重试 resends the same evidence. |
| RSESS-1 | fixed | App/MPReviewedPageScreen.swift, Core/MiniProgramPageLink.swift | `chein://mp/subpackageRoam/session/index?shareToken=<32 hex>` → RoamSharedFootprintView (anonymous reader, approval-gated); `?sessionId=` → the owner's record. |
| RSESS-2 | fixed (gated) | Core/RoamShareSnapshotPublisher.swift (new), App/RoamShareLinkRow.swift (new), App/RoamHistoryShareView.swift, App/QuestifyApp.swift (1 env line) | History → a walk → 分享: with the roam live-write approval for `api/roam/share/snapshot`, the sheet publishes (clientTs, sessionId, snapshot; route only when 路线 is on) and shows 发送足迹链接; failure → 足迹链接没生成 + 重试; no approval → the dormant line as before. |
| RNEAR-1 | fixed | App/NearbyTeamViews.swift | 附近的队伍 without a roam area: 使用当前位置 (one foreground fix, GCJ-02) then search; already-authorized location locates on open; denied → 定位没有开启…; lat/lng fields only in DEBUG. |
| RTEAMS-1 | fixed | Core/OrientSessionService.swift, Core/OrientSessionContracts.swift, App/OrientLobbyTeamsView.swift (new), App/MPReviewedPageScreen.swift, Core/MiniProgramPageLink.swift | `chein://mp/subpackageRoam/my-teams/index?tab=open&ownerType=1&ownerId=12&scope=…` → 本场招募 list from `/api/orient/team/lobby` (full teams hidden; row → the team on the map with 申请加入). Hand-off: the topic page's team card (topic area) should push `OrientLobbyTeamsView(ownerType:ownerID:scopeTitle:)`. |
| BWALL-1 | fixed | App/PlayRewardBadgeViews.swift | Play reward → 徽章收藏 → 查看收藏 opens the badge wall focused on that badge code; 成长中心 stays secondary. |
| JLAND-1 | fixed | App/PlayerJourneyReadBindings.swift, App/JourneyLandingViews.swift | `chein://mp/subpackageJourney/pages/landing/index?k=r&t=<token>`: 去看看 shows only for `nextAction == VIEW_TARGET` and opens the activity (type 2) or topic page. |
| JLAND-2 | fixed | Core/JourneyLoopSource.swift, bindings | Same link signed out: the landing renders (referral / gift reads are `@Anonymous`; no Authorization sent). Mode choices still need a session and are skipped when signed out. |
| JLAND-3 | fixed | bindings, JourneyLandingViews | 怎么玩 tiles from `SHARED_TEAM` / `INDEPENDENT` + `competition`, with rules / team size / unavailable reason; dropped when the run config is unavailable. Unit test `testChoicesTilesReadServerKeys`. |
| JLAND-4 | fixed | bindings | Title from `target.title` (gift `product.topicTitle ‖ productName`), claim-by from `claimExpiresAt`, 报名 已关闭, gift primary only for `CLAIM_GIFT` (claim stays gated). Also JLAND-5 / JLAND-7. Test `testLandingReadsTargetAndNextAction`. |
| JSEAT-1 | fixed | bindings, JourneyLandingViews | Lobby seats: BUYER → 我, AVAILABLE → open (tappable only when you can invite), unknown states hidden. Test `testSeatsReadServerStatesAndFlags`. |
| JSEAT-2 | fixed | bindings | Invite / taken count / invited list / 撤回 (only when the server says cancel is supported) / 去起点 follow seats + lobby view logic. |
| JSEAT-3 | fixed (gap) | bindings, App/MPReviewedPageScreen.swift (`pages/gerenziliao/gerenziliao` → profile editor) | 去起点 / hold-to-start open play with topic / activity; 编辑 opens the profile editor. The native play entry ignores registrationId. |
| JSEAT-4 | fixed | Core/PublicContentShareLink.swift, bindings | Invite sheet 发给好友 shares the landing link built from the server `token` (+aid/tid); a failed build shows 邀请链接暂未生成，请重试 instead of an endless spinner. The https landing link opens the app only once the universal-link domain is approved. |
| JSEAT-5 | fixed | Core/JourneyLoopSource.swift (`topicInfo`), bindings | Topic name / cover (absolute https only), tiles and own profile load after seats; a failed read hides only its block. |
| JSETTLE-1 | partial (owner) | App/JourneyReportViews.swift, bindings | Settle share step: 分享 always visible with the public topic link and the rendered card as preview. The personal referral (`/api/marketing/referral/token`) is a money-gated write (`moneyOff`), left gated; the code tries it first once enabled. |
| JSETTLE-2 | fixed | bindings | Rating owner = activity (type 2) when the run has one, else topic (1), never the run id. Test `testRatingOwnerPrefersActivity`. |
| JREPORT-1 | partial (owner) | same as JSETTLE-1 | Report: 分享 visible with the topic link; referral gated as above. Also JSETTLE-3, JSETTLE-5, JSETTLE-6 wording. |

### P1 / chrome / P2 done

| id | status | files | local verification |
|---|---|---|---|
| ROAM-5 | fixed | App/RoamHomeTabsView.swift | 漫游护照 官方活动: one open event → its detail and the card names it; several → the official task list. |
| ROAM-6 | fixed | Resources/Localizable.xcstrings, App/RoamHomeTabsView.swift | Copy: 附近暂无活动, 上次漫游需要确认 / 确认漫游记录, N 次已完成旅程, N 张本机邮票; the 已找回 banner is gone (an unfinished walk shows 继续漫游). |
| ROAM-11 | fixed | App/RoamHomeTabsView.swift, App/RoamLiveSessionView.swift, App/RoamPreflightRulesView.swift | Entry activity sheet and live rules sheet: CYSheetHeader (22 pt + ✕); preflight rules inline title. |
| ROAM-12 | fixed | App/RoamBrowserView.swift, App/RoamLiveSessionView.swift | VoiceOver: GO reads 走起; the hold pill has a 走起 accessibility action. |
| PLAY-4, PLAY-5 | fixed | App/PlayHUD.swift, Localizable | HUD caption / VoiceOver from `playHUD.*` keys; the HUD no longer repeats 用时 under the header clock. |
| PLAY-7 | fixed | Localizable, Tests/AppUITests (2 nav-bar asserts) | Play screens titled 城市定向. |
| PLAYM-3, PLAYM-4, PLAYM-5 | fixed | App/PlayStoreDayMerchantView.swift, tools/build_play_store_day_catalog.py | No 到店体验 over the hero (store name inline after scrolling); 链接已失效 + 重新加载 / 返回; 预计等待（分）; tracking 0; headers bodyMedium, stats sectionTitle tabular. |
| PLAYC-2, PLAYC-3 | fixed | App/PlayCircleRetiredLinkView.swift, App/PlayPlayerAndCircleViews.swift | Retired circle link: inline 自由探索 title, triangle symbol. |
| PLAYPOI-3, -4, -5 | fixed | App/ChallengePOIView.swift | Inline title = place name; strings in the catalog; medal 写一张城市签 → citystamp sign, 查看徽章墙 focused; error 挑战暂时打不开 + 重试 + 返回地图. |
| RHIST-3, RHIST-4 | fixed | App/RoamHistoryViews.swift | Empty → 还没有漫游记录 + 出发第一次漫游; unfinished → 回到地图; inline title. |
| RSESS-3 | fixed | App/RoamHistoryViews.swift | Inline title. |
| RNEAR-3, RTEAMS-2 | fixed | App/NearbyTeamViews.swift | No CYHeroHeader; inline 附近的队伍 / 我的队伍 by tab. |
| RNEAR-5, RTEAMS-4 | fixed | App/MPReviewedPageScreen.swift, App/QuestifyApp.swift (1 arg), App/NearbyTeamViews.swift | Signed out: 我的队伍 shows 登录后查看我的队伍 + 登录 (opens 我的) on the roam tab and deep-link hosts. |
| RCODE-1 | fixed | App/VerificationCodeView.swift | Signed-out voucher code: 登录 button. |
| RROUTES-1, GROWTH-1, LEADER-3, SALBUM-2 | fixed | OfficialRouteViews, GrowthCenterView, GrowthLeaderboardView, RoamStampViews, ObjectBadgeViews, ObjectCardViews, CollectionAlbumViews | No large titles on pushed pages; 收集册 children set no title when hosted (`cyAlbumChildTitle`). |
| SCAM-3 | fixed | App/RoamStampCameraView.swift | Inline 集邮相机 title, no hero header in the Form. |
| LEADER-1, LEADER-4 | fixed | App/GrowthLeaderboardView.swift | A viewer in the top list is highlighted there and not appended twice; 这张榜还没有人上榜 / 完成一次城市探索即可累计{unit}; EXP. |
| GROWTH-4 | fixed | App/GrowthCenterView.swift | 累计距离 · 3.2 km (one unit). |
| TRECAP-1, TANNIV-1 | fixed | App/RoamPassportToolsViews.swift | No second page-type title under the bar. |
| SALBUM-4 | fixed | Localizable | 还没有邮票. |
| TGOALS-2 | fixed | App/RoamPassportPrivateToolsViews.swift | Inline title. |
| chrome (report_chrome, my files) | fixed | 29 files (title mode), App/ChapterStoryView.swift, App/PlayKitScreen.swift | 38 pushed pages now inline; ChapterStory exit guard and pushed PlayKit screens use `cyGuardedBack` (sheets keep 关闭). Left as justified: CityRoamRootView (map root), RoamFinishReportView / RoamLiveSessionView full-screen flows, RoamPassportToolsViews month pager chevrons. |

### Deferred / not done this round

| id | status | why |
|---|---|---|
| ROAM-3, ROAM-4, ROAM-8, ROAM-9, ROAM-13 | deferred | Structure work (sheet-mode browser, PL-20 live layout, photo tiles, in-session tools, city strip); PL-16 (one roam home) is an owner ruling. |
| ROAM-7 | deferred | Guest read of `/api/roam/entry/nearby` needs an anonymous reader through the reviewed route gate (backend confirms the GET is public). |
| ROAM-10, PLAY-9, RHIST-5, RSESS-5, RNEAR-4, RTEAMS-5, RSTAMP-5, SCAM-4, SALBUM-5, LEADER-5, GROWTH-7, TRECAP-3, TGOALS-3, TANNIV-2, TEXPORT-1 | deferred | Typography roll-ups: combined-r4 already ran the type sweep; hand-fixes of hero numbers not done. |
| PLAY-2, PLAY-3, PLAY-6, PLAY-8 | deferred | Play map in the scaffold, HUD scan / chapter, full tools sheet, captain lead start / settle client. |
| PLAYM-2 | blocked-backend | `perk {name, redeemRule}` is not in the `api/play/nodes` row the app decodes; needs the field confirmed. |
| GROWTH refresh / LEADER-7 | deferred | Toolbar refresh buttons are pinned by UI tests (GrowthCenterFlowTests, GrowthNormalEntryPresentationTests, GrowthBadgeStampParityFlowTests). |
| RSESS-4 | deferred | The share CTA lives on the local record page; server-only records use RoamPassportRecordView, which has no share. |
| Others (RPOI-2..6, RCODE-2/3, RHIST-1/2, RNEAR-2, RSTAMP-3/4, RTEAMS-3, RROUTES-2/3, RROUTE-2/3, TRECAP-2, TGOALS-1, GROWTH-2/3/5/6, LEADER-2, SCAM-2, SALBUM-3, BWALL-2..7, B3D-*, OCARDS-*) | deferred | Not reached this round. Copy nouns (节点/据点/地点, 线路/路线, km/公里) wait for the owner glossary. |

## Owner decisions needed
- Referral token issue (`/api/marketing/referral/token`) is money-gated (`moneyOff`): enabling it gives report / settle their personal referral link (JSETTLE-1, JREPORT-1).
- Universal-link domain approval so shared https landing links open the app (JSEAT-4).
- `RoamExperienceCapabilities.mediaUpload` / `stampExchange` (Core/RoamExperienceContracts.swift:187-188): enable through the reviewed approval or keep dormant (SCAM-1, RSTAMP-2).
- Stamp-album image policy in the metadata scope (SALBUM-1).
- PL-16 one roam home; glossary 节点/据点/地点, 线路/路线, km/公里.

## Backend needed
- PLAYM-2: `GET /api/play/nodes` row `perk: { name, redeemRule }` (or confirm the field name).
- ROAM-7: confirm `GET /api/roam/entry/nearby` accepts no Authorization (MP 2026-11-14 guest rule) so the app can read it signed out.

## Shared files touched (minimal)
- App/QuestifyApp.swift: two `.environment` lines at the root (`challengePOIPhotoUploader`, `roamShareSnapshotPublisher`) and `onSignIn` on the roam nearby destination.
- App/AppSession.swift: `makeRoamPOIActions` complete closure takes the evidence (same line count, 8171).
- App/CollectionAlbumViews.swift: `cyAlbumChildTitle` modifier next to the `collectionAlbumHosted` key.
- Core/MiniProgramPageLink.swift: query rules for the play / roam pages listed above (were open / id-only).
- Core/JourneyLoopSource.swift: referral / gift take an optional session; new `topicInfo`. Core/PublicContentShareLink.swift: `journeyLanding`.
- Questify.xcodeproj regenerated with `tools/generate_project.py` for the 5 new files.
- No DesignSystem files changed. `tools/typography_lint_baseline.json` lowered with `--update` only (counts went down).
