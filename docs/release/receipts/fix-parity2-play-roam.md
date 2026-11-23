# Receipt: fix-parity2-play-roam

Brief: `origin/design/handoff-r2:docs/briefs/fix-parity-r2.md`. Findings: `origin/audit/parity-play-roam:docs/audit/parity/play-roam.md`. Round 1: `docs/release/receipts/fix-parity-play-roam.md`.
Branch `fix/parity2-play-roam` from `origin/ui/combined-r5` @ 65eb1def4 (no newer combined-r5 commits at the last fetch).
Swift is not installed in the cloud, so nothing here was compiled. Every change follows patterns already in the files, and passes the static gates below.

## Gates

| gate | result |
|---|---|
| `python3 -B tools/check_scaffold.py` | PASS (4942 Swift files, page route table 264, 17053 bilingual keys) |
| `python3 -B tools/check_design_lint.py` | PASS. Typography lint: raw text style 1173 → **1154**, large title 11 → **10**, others unchanged (Theme.Font 63, raw size 67, back chevron 12, hidden back 7). Baseline lowered with `tools/check_typography_lint.py --update` only. |
| `python3 -B tools/contract_ratchet.py --check` | 185 failing vs baseline 184: the single "new" failure is `test_workshop_paid_professional…test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging`, which fails identically on a clean `origin/ui/combined-r5` (workshop area). **0 new from this branch.** |

Contract mirrors updated in the same commits as the changes they mirror: `docs/release/ui-strings-subpackageP3-pages-growthcenter-index-index.json` (new identifier `growthCenter.signIn`), `docs/release/ui-strings-subpackageP3-pages-badge-wall-index-index.json` (MP partial copy), `Resources/ObjectCardLocalizations.fragment.json` (藏品册), and `Tests/ContractChecks/test_object_badge_wall_layout.py`: the badge-detail byte hash. The only change there is `appNavigationTitle` → `cyPageTitle` (inline mode); lifetimes are unchanged.

## Order of work followed
1. Round-1 deferred / partial: no P0 was left actionable. RSTAMP-2, SCAM-1, SALBUM-1, JSETTLE-1 and JREPORT-1 stay owner-gated, and PLAYM-2 stays blocked on the backend (both listed below). Then the deferred P1s that fit this round.
2. Unfixed P1s, in the audit's fix-plan order (contracts → flows → chrome + copy → typography).
3. Chrome (`tools/report_chrome.py`) in area files.
4. P2s: PLAY-11, RNEAR-6, RCODE-4, RROUTES-4.

## Status by finding

"TEST account" = a signed-in China TEST account. "Signed out" = no session. Verification uses the Debug build.

| id | status | files | local verification |
|---|---|---|---|
| chrome (report_chrome, area files) | fixed | App/RoamHomeTabsView.swift, RoamLiveSessionView.swift, RoamStampViews.swift (×2), ObjectBadgeViews.swift (×2), ObjectCardViews.swift, FreeExplorationViews.swift (×2), JourneyNarrativeView.swift, JourneyLandingViews.swift | `python3 -B tools/report_chrome.py`: none of these lines is listed any more. Push 漫游 → live roam, 城市印章, 徽章详情, 物件详情, 自由探索门店, 旅程记录 and 推广 from a large-title root: each title is inline. Still listed, and justified: sheets that hide the bar for a `CYSheetHeader` (RoamHomeTabsView:310 entry sheet, RoamLiveSessionView:706 rules / :1275 check-in), the full-screen flows (RoamFinishReportView, CityRoamRootView map root), and the RoamPassportToolsViews month pager chevron. |
| JPROMO-1 | fixed | App/JourneyLandingViews.swift | Journey 推广 page: the title is inline (it was large). |
| RCODE-2 | fixed | Core/VerificationCodePresentation.swift (`failedOnNetwork`), Core/RoamSubpagePresentation.swift, App/VerificationCodeView.swift | City voucher code (`chein://mp/subpackageRoam/citynode-code/index?poiId=7`) in airplane mode → 网络异常，请稍后重试 with **重试**. A server refusal still shows 暂时无法生成核销码，请稍后重试. |
| RCODE-3 | partial | App/VerificationCodeView.swift | The desc line now uses `.cyText(.bodyCompact)`. The title / noun (据点 vs 节点) waits for the owner glossary. |
| RCODE-4 | fixed (copy) | Localizable (`roamSub.w208.voucher.desc`) | The voucher desc reads 出示给商家扫码领券 (MP short form, no ASCII comma). |
| RSESS-4 | no change needed | — | Server-only records open RoamPassportRecordView, which has no share. Local records keep 分享, which matches the MP rule `!serverFact ‖ localSupplement`. |
| RROUTE-1 | fixed | App/MPReviewedPageScreen.swift | `chein://mp/subpackageRoam/official-route/index?id=12` opens the detail. `?id=abc` or `?id=0` → unavailable (MP digit check). |
| RROUTE-2 | fixed | App/OfficialRouteViews.swift, App/E1OfficialRouteParts.swift | Route detail: the inline title is the route name once loaded (路线详情 while loading or on errors). The hero name is `.cyText(.pageTitle)` with no scale factor. |
| RROUTE-3 | fixed | App/E1OfficialRouteParts.swift, Localizable | Stop rows: the 参考停留 N 分钟 chip comes from `officialRoute.detail.stay`. 在地图中打开起点, 官方路线 and 用时 / 距离 / 站点 are now from xcstrings. Switch the language to English: all of them translate. |
| RROUTES-2 | partial | App/E1OfficialRouteParts.swift | The card chip is localized (`officialRoute.badge`). The noun 线路 vs 路线 waits for the owner glossary. |
| RROUTES-3 | no change needed | — | The card already shows the duration and distance chips over the cover. |
| RROUTES-4 (P2) | fixed | App/E1OfficialRouteParts.swift | Official route cards have no trailing chevron. |
| JLAND-6, JSEAT-7, JREPORT-5, JSETTLE-6 (missing link) | fixed | App/JourneyLandingViews.swift, App/JourneyReportViews.swift | Open a landing / seats / report / settle link with a bad id: 链接已失效 now has **返回**, which closes the page. |
| JSEAT-7 (unknown invite) | fixed | App/PlayerJourneyReadBindings.swift, Localizable `mp.seats.unconfirmed` | Seats → 邀请 against a TEST server that times out after the write: the line reads 结果还没确认，请稍后查询 (no network error). |
| JPROMO-2, JREPORT-5, JSETTLE-6 (reload after sign-in) | fixed | App/JourneyLandingViews.swift, App/JourneyReportViews.swift | Signed out → 推广 / 报告 / 结算 → 登录 → sign in with a TEST account: the sheet closes and the page reloads (it used to stay on 登录后查看). |
| JREPORT-5 (RUN_NOT_FOUND) | blocked-backend | — | The journey envelope has no `reasonCode` (only http / code / msg). A 404 already maps to `.gone`. See "Backend needed". |
| JSETTLE-6 (rate copy) | deferred | — | `mp.settle.rate.netKept` / `unavailable` were not added this round. |
| JLAND-5, JSETTLE-5 | no change needed | — | Already done in round 1: the state copy map (PlayerJourneyReadBindings:757-770) and settle tabs `[.quest, .team]`. |
| TGOALS-1 | fixed | App/RoamPassportPrivateToolsViews.swift | 探索目标 with no goals: the standard empty state (target symbol). When writes are open it has a **定一个新目标** button that opens the form. The identifier `roam.goals.empty` is kept. |
| TRECAP-2 | fixed | App/RoamPassportToolsViews.swift | 月度回顾 for a month with 0 routes / places / stamps: no share card. Pick a month with data: the card shows. |
| LEADER-2 | fixed | App/GrowthLeaderboardView.swift | VoiceOver on the podium reads 第一名, then the name and score with the unit (it used to read only 第一名). |
| GROWTH-2 | fixed | App/GrowthCenterView.swift | 成长中心 → 我的徽章: each row shows 获得于 … (or 获得时间未记录) directly, with no 查看 / 收起 toggle. The server icon image is not drawn yet: that needs the image-host policy. |
| GROWTH-3 | fixed | App/GrowthCenterComponents.swift | 成长中心 signed out: lock empty state + **登录** (switches to 我的). |
| BWALL-5 | fixed | App/ObjectBadgeViews.swift, Localizable `profile.badges.partial` | 徽章墙 signed out: **登录**. With a partial read, the line reads 部分勋章数据未到达，当前结果不完整. The tile meta date / condition is deferred. |
| B3D-2 | fixed | App/ObjectBadgeWallParityViews.swift | With Reduce Motion on: no idle spin, but dragging still turns the badge. |
| B3D-3 | fixed | same | 3D badge page: inline title 徽章. |
| B3D-4 | fixed | same, Localizable `badge3d.*` | Loading reads 正在准备 3D 徽章…. The toolbar toggle reads 静态预览 / 3D 展台 from xcstrings. The hint under the stage reads 拖动可旋转查看, or 已减少动态效果 under Reduce Motion (existing keys). |
| OCARDS-1 | fixed (copy) | Localizable, Resources/ObjectCardLocalizations.fragment.json | 我的 → 藏品册 (it was 物件卡). The inline title comes from `cyAlbumChildTitle` (only when standalone). |
| OCARDS-4 (signed out) | partial | App/ObjectCardViews.swift | 藏品册 signed out: 登录后查看你的藏品 + **登录**. Rename validation is deferred. |
| RSTAMP-4 | fixed | Core/RoamStampCaptureCoordinator.swift (`failedStep`), App/RoamStampCameraView.swift | Stamp camera with the upload approval on and the upload failing: 图没传上去，请重试一次. With the create refused: 没存上，请重试一次. The exchange failure keeps its own line. |
| RHIST-7 | fixed | App/RoamHistoryViews.swift | Corrupt the local walk file (Debug) while history rows exist: the 没能读取未结束的漫游。 line + 重试 shows above the rows (it used to show only when the list was empty). |
| PLAYM-6 (P2) | fixed | App/PlayStoreDayMerchantView.swift | Store-day page signed out: **登录** (switches to 我的) next to 重新加载 / 返回. |
| PLAY-11 (P2) | fixed | App/PlayHUD.swift | Play HUD 队伍 / 背包 circles over a light map tile: the material is dark, so the white glyph stays readable. |
| RNEAR-6 (P2) | fixed | App/NearbyTeamViews.swift | 附近的队伍 opened with no area: the range control starts at 1 km. |
| ROAM-10, PLAY-9, RSESS-5, TEXPORT-1 (typography) | partial | 10 area files (codemod) | `tools/codemod_typography.py --apply` on the area files: 16 raw `.subheadline` → `.cyText(.body)`. Hand-tuned: export read count → `.meta`. The rest of each roll-up is either pinned by contract tests (GrowthLeaderboardView, GrowthCenterView, RoamBrowserView, RoamItemDetailView, RoamPassportToolsViews:498) or SF Symbol sizing, so it is left as is. |

### Deferred / blocked this round

| id | status | why |
|---|---|---|
| ROAM-3, ROAM-4, ROAM-8, ROAM-9, ROAM-13 | deferred | Structure work: sheet-mode browser, PL-20 live layout, photo tiles, in-session tools sheet, city strip. ROAM-3 depends on the PL-16 owner ruling. |
| ROAM-7 | blocked-backend | Needs the anonymous `/api/roam/entry/nearby` confirmation (same as round 1). |
| PLAY-2, PLAY-3, PLAY-6, PLAY-8 | deferred | Real map in the play scaffold, HUD 扫码 circle, full tools sheet, captain lead start / settle client. The HUD bar has no scan target outside a node, so a scan circle needs the node scan task to be exposed first. |
| PLAYM-2 | blocked-backend | `perk {name, redeemRule}` is not in the `api/play/nodes` row (round 1). |
| PLAYPOI-6 (P2) | deferred | ChallengePOIView has no `makeExternalMaps` / scope plumbing from its hosts. |
| RTEAMS-3 | deferred | There is no join-code entry sheet to reuse; TeamHome joins only from a known invite code. |
| RPOI-2, RPOI-3, RPOI-4, RPOI-5 | deferred | RPOI-4 needs a POI universal-link path (same domain approval as JSEAT-4). RPOI-5 waits for the glossary (节点/据点). |
| RHIST-1, RHIST-2 | deferred | Merging the server pages into the local list is structural. RHIST-2 depends on it. |
| RNEAR-2, RTEAMS-5, RSTAMP-3, SCAM-2, SALBUM-3, SALBUM-5, BWALL-2, BWALL-3, BWALL-6, B3D-1, OCARDS-2, OCARDS-3 | deferred | Structure / interaction rebuilds (map sheet, tear + scratch slip, viewfinder-first camera, collage album, medal art, pile). |
| JLAND-7, JLAND-8, JSEAT-6, JSEAT-8, JSEAT-9, JPROMO-3, JSETTLE-3, JSETTLE-4, JSETTLE-7, JREPORT-2, JREPORT-3, JREPORT-4, JREPORT-6 | deferred | Not reached this round. |
| GROWTH-5, GROWTH-6, GROWTH-7, LEADER-5, TRECAP-3, TGOALS-3, TANNIV-2 | deferred | Typography / identity fixes are mostly pinned by contract tests (GrowthLeaderboardView, GrowthCenterView). Each needs its test updated in the same commit. |
| RCODE-5, RHIST-6, RSESS-6, RNEAR-7, RROUTE-4, RROUTE-5, RPOI-7, RPOI-8, RSTAMP-6, RTEAMS-6, ROAM-14, ROAM-15, PLAYC-3 and the other P2s | deferred | Not reached. km / 公里 waits for the glossary. |

## Owner decisions needed (carried over)
- `RoamExperienceCapabilities.mediaUpload` / `stampExchange` (SCAM-1, RSTAMP-2). Stamp-album image policy (SALBUM-1, and the GROWTH-2 icon).
- Referral token `/api/marketing/referral/token`, which is money-gated (JSETTLE-1, JREPORT-1). Universal-link domain (JSEAT-4, RPOI-4).
- PL-16: one roam home (ROAM-3).
- Glossary: 节点/据点/地点 (RPOI-5, RCODE-3/4 noun), 线路/路线 (RROUTES-2), km/公里 (RHIST-6, RSESS-6).
- 藏品册 was applied from the MP (OCARDS-1). Revert `objects.title` if the owner prefers 物件卡.

## Backend needed
- PLAYM-2: `GET /api/play/nodes` row `perk: { name, redeemRule }`, or confirm the field name.
- ROAM-7: confirm that `GET /api/roam/entry/nearby` accepts no Authorization (guest read).
- JREPORT-5: the journey report read (`GET /api/play/player-journey/report`) should return `reasonCode: "RUN_NOT_FOUND"` (or HTTP 404 consistently) for a deleted or unknown run, so the app can tell 本局已不存在 apart from a network failure.

## Shared files touched (minimal)
- Core/VerificationCodePresentation.swift: one read-only flag, `failedOnNetwork` (set only on the `.failed` default branch). Every other caller is unchanged.
- Core/RoamStampCaptureCoordinator.swift: one read-only `failedStep` (upload / create).
- No DesignSystem files changed.
- `tools/typography_lint_baseline.json` lowered with `--update` only.
- New: `tools/add_fix_parity2_play_roam_localizations.py`. It is the single source of this branch's strings and is idempotent; for an existing key it replaces only the values.
