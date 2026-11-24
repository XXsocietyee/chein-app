# Receipt: fix/r3-play-roam-b (Claude F-agent, play-roam half b)

- **Brief:** `origin/design/handoff-r2:docs/briefs/wave-x10.md` (wave ×10, 2026-11-24).
- **Base:** `origin/ui/combined-r7` @ 7fdfad1f1, plus `origin/restyle/r5-play-roam-city` merged first (it touches RoamStampCameraView, RoamStampViews, JourneyLandingViews, JourneyReportViews, GrowthCenterView, ObjectBadgeViews).
- **Half b = round-1 audit pages 16–30:** subpackageJourney seats / promo / settle / report; subpackageTools monthly-recap / exploration-goals / anniversary / exploration-export; subpackageP3 growthcenter / leaderboard / stamp-camera / stamp-album / badge-wall / badge-3d / object-cards.
- **Gap sources used:** `audit/parity-r7-play-roam` (fix queue + per-page appendices, newest), `review/r7-rev-{a,b,c}` (no finding in these App files), round-1 `audit/parity-play-roam`.
- **Layer:** App/ only. No Core type, no Tests file, no `Localizable.xcstrings` / `project.pbxproj` edit. New strings: `docs/port/strings/fix-r3-play-roam-b.json`.
- **Fixture routes:** `docs/port/accept/f-play-roam-b.txt` (23 routes; 4 new `r3prb-*` in `App/DesignFixtures/FixR3PlayRoamBFixtures.swift`, chained once in `DesignFixtureRegistry`).

## Fixed

| id | page | what changed | files |
|---|---|---|---|
| JPROMO-3 (P1) | promo + seats/settle/report (shared kit) | `MPSectionHeader` → `.cardTitle`, primary (MP `.jn-sec__h`); `MPRow(strong:)` value → `.bodyMedium` (MP `.jn-row__v.is-strong`). Also reaches the Pass pages that use the same kit (PassMarketViews, PassMembershipViews) | App/MPParityKit.swift |
| JPROMO-6 (P2) | promo | loading / sign-in / error fill the screen; only the ready content scrolls (native state layout) | App/JourneyLandingViews.swift |
| promo row 8 (⚠️) | promo | 成交 counts the server did not send read 未知 (MP wxml:19), not "—" | App/JourneyLandingViews.swift, strings `mp.promo.unknown` |
| JSEAT-6 (P1) | seats | new `.auth` phase: signed out or 401 → 登录后管理席位 + 登录 (shared sign-in bridge), reload when the sheet closes; 403 stays `.denied` | App/JourneyLandingViews.swift, App/PlayerJourneyReadBindings.swift, strings `mp.seats.auth` |
| JSEAT-r7-1 (P1) | seats | keep the invite answer's `invitationId`; after each seats read, drop the token once that seat is no longer INVITED (MP L09-058), so a claimed / expired link is never re-shared | App/PlayerJourneyReadBindings.swift |
| JSEAT-9 (P1) | seats | 一起玩的人 `.bodyMedium` + header trait; count `.body` secondary; 邀请 `.body`; ⋯ and how-to icons via `cyText` | App/JourneyLandingViews.swift |
| JSETTLE-4 (P1, part) | settle | 辅助完成 cell = nodes finished SKIPPED / REVEALED, shown only when > 0 (MP wxml:28). 开局 needs a Core field — see Cursor requests | App/JourneyReportViews.swift, strings `mp.settle.assisted` |
| JSETTLE-7 (P1) | settle | `.tracking(0.6)` removed; topic `.display` → `.pageTitle`. `data2XL` stats kept (hand-off owner to confirm) | App/JourneyReportViews.swift |
| JREPORT-6 (P1) | report | eyebrow tracking removed; section header via JPROMO-3. `dataXL` kept (hand-off owner to confirm) | App/JourneyReportViews.swift |
| JREPORT-4 (P1) | report | **not** turned into `CYSheetHeader`: the owner's native-iOS rule (and r5/R6) use the system inline title + one cancellation item. Aligned the 榜单 / 本局回忆 / 更多 sheets to r5's icon-only ✕ (`Label("action.close", systemImage: "xmark")`) | App/JourneyReportViews.swift |
| GROWTH-5 (P1, part) | growthcenter | person row reads the session name (env `growthSessionProfile`, set at the tab root from `session.account`) and shows even when the rank read fails; the rank nickname is the fallback. Avatar image: see Left | App/GrowthCenterView.swift, App/QuestifyApp.swift (one line) |
| GROWTH-6 (P1) | growthcenter + leaderboard | 去探索 no longer needs each entry to inject `growthExploreHomeAction`: without one it falls back to the root tab switch (首页). Covers PlayRewardBadgeViews, deep link, ProfileSelfGrowthSection (and LEADER-8) | App/GrowthCenterView.swift, App/GrowthLeaderboardView.swift |
| GROWTH-8 (P2) | growthcenter | 我的足迹 hidden when all three reads succeeded and every figure is 0 (MP `footprintEmpty`) | App/GrowthCenterView.swift |
| GROWTH-7 residue (P2) | growthcenter | two raw `.font(.caption)` → `.cyText(.meta)` | App/GrowthCenterView.swift |
| LEADER-5 (P1) | leaderboard | row rank `.cardTitle` secondary, name `.bodyMedium`, score `.label` semibold, unit `.caption`, percentage `.meta`; podium initial via `cyText(.display/.pageTitle)`; podium score `dataXL` → `numericBody` (fits a ⅓ column) | App/GrowthLeaderboardView.swift |
| SALBUM-r7-1 (P1) | stamp-album | 我的 passport 邮票 and the `stamp-album` deep link pass the session camera, so the camera item / empty CTA no longer open the disabled bare `RoamStampCameraView()` | App/AccountView.swift, App/MPReviewedPageScreen.swift |
| SALBUM-3 (P1) | stamp-album | inside 收集册 (hosted, non-accessibility sizes): 4-across image-only 4:5 perforated tiles tilted up to ±12° (0° under Reduce Motion); VoiceOver label 放大第 N 枚邮票. The MP fly-to-centre is the existing hero zoom push (native). Accessibility sizes keep the readable card grid | App/RoamStampViews.swift, strings `stampAlbum.openStamp %lld` |
| SCAM-2 (P1, part) | stamp-camera | the caption field shows only on the citystamp route (`SessionRoamStampCameraView(showsCaption: true)` from `SessionRoamCityStampFlowView`); the plain stamp camera has none, as in the MP. One round shutter was already in place | App/RoamStampCameraView.swift, App/SessionRoamMediaViews.swift |
| BWALL-5 (P1) | badge-wall | tile meta = locked → condition / unlock hint ?? 尚未点亮; lit → obtained day (YYYY-MM-DD) ?? 已点亮 (MP wxml:38); VoiceOver still hears 已点亮 / 未点亮 as the value | App/ObjectBadgeViews.swift, strings `objects.badge.meta.locked` |

## Left, with reasons

| id | why it is left |
|---|---|
| SCAM-1, SALBUM-1 (P0) | owner decisions (`mediaUpload`; stamp image policy). Unchanged. |
| SCAM-2 rest (consent toggle, auto-open) | the consent toggle is the app-wide `purposeAccepted` privacy gate (also on poster scan, nearby, live roam; pinned by `test_native_presentation_reuse`). Dropping it, and opening the camera on appear, needs an owner yes. |
| GROWTH-5 avatar | `test_growth_source_contract` forbids `AsyncImage` (third-party media) in `Growth*.swift`; the session avatar is often a WeChat CDN URL. `GrowthSessionProfile.avatar` is carried, not drawn. Owner: allow, or keep the initial disc. MP default avatar `d_profile.png` waits for `cursor/mp-assets` (not on origin yet). |
| JSETTLE-4 开局 | needs `runStartMode` decoded in Core `PostGameRunReport` (Cursor). |
| JREPORT-3, JREPORT-5 | Core `JourneyEnvelope.reasonCode`, `/api/rank/list` scopes, `JourneyRunScope` fields (Cursor). |
| JSETTLE-r7-1 完局优惠卡 | Gemini (whole feature), money-adjacent. |
| BWALL-2 / BWALL-3, B3D-1, OCARDS-2 | Gemini queue (art on tiles, 2-col grid, identity-pin scene, card pile). |
| OCARDS-3 / OCARDS-4 | mount the category / rename sheets after `gap/g1-player` merges (in flight; skipped per brief). |
| JREPORT-2 | node-photo viewer in flight (`gap/g1-player`), needs a Cursor photo field. |
| JSEAT-8 | owner ruling (empty bar title + 开局大厅 eyebrow vs `cyPageTitle`). |
| Tools pages (20–23) | no P0/P1 in r7. P2 left: TEXPORT pending retry is Core semantics (`.outcomeUnknown` hides retry by design); TANNIV-4 reviewed route has no destination (MPReviewedPageScreen, shared). |
| SALBUM-6 paging, SALBUM-7 FAB, B3D-4/5/6, OCARDS-5/6/7, LEADER-6/7, GROWTH-9 | P2, not reached this round. |

## Requests for Cursor (Core)
- `PostGameRunReport`: decode `runStartMode` (MP `RUN_START_MODE_LABEL`, journey-view.js) so settle can show 开局 (JSETTLE-4).
- `JourneyEnvelope.reasonCode` + RUN_NOT_FOUND / RUN_SCOPE_MISMATCH mapping (JREPORT-5), `/api/rank/list` city / country / club scopes (JREPORT-3).

## Covered in flight (not touched)
- `restyle/r5-play-roam-city`: merged as the base (visual only).
- `gap/g1-player`: OCARDS-3/4 sheets, JREPORT-2 viewer, BWALL grid (parked App/MPGap).
- `cursor/*`, `port/*`: none open for these pages.

## Checks run here (no compiler in the cloud)
- `python3 -m unittest discover -s Tests/ContractChecks`: 196 FAIL/ERROR on the base (combined-r7 + r5) and the same 196 on this branch: **0 new failures**. The two growth checks that first flagged this work (`test_growth_center_index_page_ready`, `test_growth_source_contract`) pass after the fix; `test_object_badge_wall_layout`, `test_cb224_stamp_camera_page_ready`, `test_native_presentation_reuse` pass.
- `tools/check_typography_lint.py`: PASS, same counts as the base.
- `tools/check_scaffold.py`: fails identically on the base (project file is regenerated by the integrator).
- Every API used was grepped on the base: `PlayerJourneySignInBridge.shared.request()/presented`, `RootTabSwitch.isAvailable/callAsFunction`, `cyText(_:weight:monospacedDigit:)`, `appLocalized(_:locale:)`, `CYCoverArt(seed:symbol:cornerRadius:)`, `QuestifyCardArtwork.safeURL`, `collectionAlbumHosted`, `SessionRoamStampCameraView`.

## Acceptance
- Run: none yet. `ui/combined-r7` has no `acceptance.yml` (only ios-ci / native-ios / native-targeted), so the coordinator compiles and runs the routes in `docs/port/accept/f-play-roam-b.txt`.
