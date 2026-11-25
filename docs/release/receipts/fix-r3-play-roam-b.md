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

## Round 2 (2026-11-24)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round2.md` + `owner-decisions-1124.md`.
- **Sync:** merged `origin/ui/combined-r7` at the start (Cursor K1–K10, W1, C7 assets; one conflict in `tools/check_typography_lint.py`, taken from r7) and again before the final push.
- **Layer:** App/ only, plus one contract-check hash re-pin (below). Strings in `docs/port/strings/fix-r3-play-roam-b.json` (en + zh-Hans).

### Round-1 leftovers now closed (Core landed in r7)

| id | what changed | files |
|---|---|---|
| JSEAT-6 | seats read goes through Core `JourneySeatsSessionGate`: no session → 登录; 403 → denied; 401 answer → 登录; every other non-OK → 加载失败 (a bare 404 is no longer 链接已失效) | App/PlayerJourneyReadBindings.swift |
| JSEAT-r7-1 | Core `JourneyHeldSeatInviteRule`: the invite answer keeps `{invitationId, token}` only when both are valid; after every seats read the hold is replaced by `afterRead`, and the share link is dropped with it. An answer without both reads 链接生成失败 | App/PlayerJourneyReadBindings.swift |
| JREPORT-5 | report and settle use Core `JourneyReportRead.reject` (report: RUN_NOT_FOUND / RUN_SCOPE_MISMATCH → gone, 403 → denied; settle: RUN_NOT_FOUND only) and `runDisagrees`; every other non-OK is 暂未加载 + 重新加载 | App/PlayerJourneyReadBindings.swift |
| JSETTLE-4 开局 | `JourneyReport.startModeText` from Core; settle shows the 开局 cell only when set (桌面完成 / 替代站开局, catalog keys for both) | App/JourneyReportViews.swift, App/PlayerJourneyReadBindings.swift |
| JREPORT-3 | `JourneyRunScope` carries `cityCode` / `countryCode` / `clubID` from the link (Core `LinkCodes.parse`); tabs and 更多 come from Core `JourneyRankBoardContract.menu`; city / country / club boards read `GET /api/rank/list` with `scope`, `scopeId`, `period` only; a report without `teamId` reads choices and opens 队内 from `JourneyRankBoardContract.teamID` (MP `_loadTeam`) | App/MPParityKit.swift, App/PlayerJourneyReadBindings.swift |
| JREPORT-2 | `JourneyNodeRow.photoURL` (Core `Node.photoURL`, https only); 44 pt thumb on the node row, tap opens a paged full-screen preview over all node photos of the run (system close item) | App/JourneyReportViews.swift |

### P2s closed this round

JREPORT-8 (stat value one line, scales to 0.6), JREPORT-9 (rank row hint; memory photo described), TRECAP-4 (44 pt round month buttons), TRECAP-5 (share copy key), TRECAP-6 (28 pt bars; one VoiceOver summary of every week), TANNIV-5 (two card skeletons), TEXPORT-2 (探索记录 · range title, middle-truncated filename), TEXPORT-4 (expired state with 重新准备), TGOALS-5 (cancel copy adds 此操作不可撤销 — fragment overrides the catalog value), GROWTH-9 (hand-made chevron removed), LEADER-6 (gold / pale gold / bronze rings, star above #1), LEADER-7 (`CYTabs(variant: .chip)`), SALBUM-7 (52 pt FAB, shadow, press state), B3D-5 (name bold, sub caption), B3D-6 (full-bleed stage), OCARDS-5 (glyph via `cyText`, ChannelCopy → `objects.flip` / `objects.tapToTurnBack`), OCARDS-6 (total row removed), OCARDS-7 (style / status / source rows off the detail; source moved to the card back). JPROMO-5: the MP `dateText` is now `YYYY.MM.DD`, which the app already shows — no change.

### MP assets (`docs/mp-assets/mapping.md`)

| row | applied | where |
|---|---|---|
| ✅ `MPAsset.AvatarDefault.memoji1/2/3` | leaderboard podium + list rows + pinned 我 row (MP `toRow` index rotation, 我 = first). Remote avatars stay undrawn on Growth screens (`test_growth_source_contract` forbids `AsyncImage`), so the MP's second fallback is what shows | App/GrowthLeaderboardView.swift |
| ✅ `MPAsset.AvatarDefault.dProfile` | growth score-card avatar (MP `avatarUrl || d_profile.png`) | App/GrowthCenterView.swift |
| ✅ `MPAsset.BadgeMedal.laurel` | rank-board hero wreath, right branch mirrored (was SF `laurel.*`) | App/JourneyReportViews.swift |
| ✅ `MPAsset.BadgeMedal.badgeDemo` | default badge art on the wall tile, album page front and badge detail stage (was SF `medal.fill`) | App/ObjectBadgeViews.swift |
| ✅ `MPAsset.FeatureIcon.all/electronics/clothing/bags/…Food/books/toys/daily/…Other` | object-card filter row shows the selected category's icon (MP `oc-filter__ic`). Not in the `Menu` items: UIMenu does not scale non-symbol images | App/ObjectCardViews.swift |
| ⏭ `MPAsset.FeatureIcon.iconCloseSm` | mapping says keep SF `xmark` (system control) | — |
| ⏭ `MPAsset.BadgeMedal.medal/stamp`, `FeatureIcon.object` (album-intro) | the app has no 收集册 opening transition (album-intro ring stack); nothing to put them on | — |
| ⏭ `MPAsset.BadgeMedal.goldMatcap` | WebGL matcap texture of the MP `xr-badge`; the SceneKit showroom has its own material | — |
| ⏭ `MPAsset.EmptyState.*` | empty states on these pages are the shared `CYEmptyState` (App/DesignSystem/CYStates.swift, SF only); the swap belongs in that shared component | — |
| — | small status glyphs (lock / medal beside 已点亮 on card backs) stay SF as state indicators | — |

### Owner decisions (1124)

- #9 two-decimal money: the only money figure on these pages (promo net amounts) already prints `¥x.xx` (`PlayerJourneyPromoBinding.yuan`). No shared formatter exists on r7 yet; switch when one lands.
- #3 / #6 / #12 money TEST-only: nothing here writes money (gift claim / referral token stay `moneyOff`).
- #8 arrival lock, #10 pilot kits, #7 cast: not on half-b pages.

### Review findings

`review/r7-rev-a/-b/-c`: no row owned by Claude for half-b pages (B-15 is P5 Core; F-C21 is club). `audit/parity-r7-play-roam` P1 for half b: all closed except the Gemini / owner rows below.

### Still left

| id | why |
|---|---|
| SCAM-1, SALBUM-1 (P0) | owner (`mediaUpload`, stamp image policy) |
| SCAM-2 rest | owner (consent toggle is the app-wide privacy gate) |
| JSEAT-8 | owner (bar title) |
| JSETTLE-r7-1, BWALL-2/3, B3D-1, OCARDS-2 | Gemini |
| OCARDS-3/4 | Gemini's sheets stay parked in App/MPGap (not mounted, per Cursor) |
| SALBUM-6 | MP is POST `api/roam/stamp/list`; the parked GET helper is wrong — Cursor |
| TGOALS-4 | Core `RoamExplorationGoal.progress` is non-optional `Int`; needs `Int?` (Cursor) |
| TGOALS-6 | owner (keep the extra create confirmation or not) |
| TANNIV-4 | shared reviewed route (MPReviewedPageScreen) has no destination |
| TEXPORT pending retry | Core semantics (`.outcomeUnknown`) |
| GROWTH-9 / LEADER-7 toolbar refresh | `growth.refresh` is driven by AppUITests and `growth.board.refresh` is pinned by `test_growth_leaderboard_page_ready`; Cursor to drop both with the tests |
| B3D-4 | already done in r7 (keys + hint) |

### Requests for Cursor

- `RoamExplorationGoal.progress: Int?` (TGOALS-4).
- Drop the two Growth toolbar refresh buttons together with their UI test / contract pins (GROWTH-9, LEADER-7).
- A shared money formatter (owner #9) so Journey promo can switch to it.

### Fixtures / acceptance

- New routes `r3prb-settle-startmode`, `r3prb-report-nodephotos` (App/DesignFixtures/FixR3PlayRoamBFixtures.swift), added to `docs/port/accept/f-play-roam-b.txt` (25 routes).

### Checks run here (no compiler in the cloud)

- Contract checks: full run before the P2 batch — 1 new failure from the badge-art swap (`test_object_badge_wall_layout` hashes `ObjectBadgeDetailView`); re-pinned with a comment line in that test (`Tests/ContractChecks/test_object_badge_wall_layout.py`). Targeted reruns (growth, roam, object, journey, export, a11y-hardening, native semantics): no new failures.
- `tools/check_typography_lint.py`, `tools/check_design_lint.py`: PASS. `tools/check_a11y_lint.py`: same 3 findings as the base (not in these files). `tools/check_roam_private_tools.py`: PASS.
- `tools/check_missing_string_keys.py` lists the 13 new keys as missing from `Localizable.xcstrings`; they are in the fragment for the integrator to merge.
- APIs grepped on r7: `JourneySeatsSessionGate.phase`, `JourneyHeldSeatInviteRule.hold/afterRead/Seat`, `JourneyHeldSeatInvite`, `JourneyReportRead.reject/runDisagrees/Surface`, `PostGameRunReport.startModeText/Node.photoURL`, `JourneyRankBoardContract.menu/LinkCodes.parse/teamID/Menu/Tab.Kind`, `JourneyLoopSource.choices/rank`, `MPAsset.*` (each accessor name), `CYTabs(items:selection:variant:)`, `CYTabItem(id:title:)`, `CYSkeletonBlock(height:)`, `CYEmptyState(systemImage:_:actionTitle:actionIdentifier:action:)`, `CYFactRow(label:value:)`, `.cyPressable`.

## Round 3 (2026-11-24 evening)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round3.md` (+ `wave-x10.md`, `fix-r3-round2.md`, `owner-decisions-1124.md`).
- **Sync:** merged `origin/ui/combined-r7` @ `b0ac0108d` (fast-forward: my round-2 tip was its merge base), and again before the final push.
- **Layer:** App/ only (plus App/MPGap mounts). No Core, Tests, `Localizable.xcstrings` or project edits. New strings in `docs/port/strings/fix-r3-play-roam-b.json` (en + zh-Hans).

### Round 3 · re-applied

Of my round-2 files only `App/JourneyReportViews.swift` was restored to Cursor's side. Each hunk was checked against the new base; the missing ones were re-applied **on Cursor's wiring** (its `JourneyNodePhoto`, `assistedCount` / `showsAssistedCount`, `showsStartMode`, `JourneyRankScope(tab)`), with no second implementation:

| id | re-applied | how |
|---|---|---|
| MP asset laurel | rank-board hero wreath back on `MPAsset.BadgeMedal.laurel` (right branch mirrored), replacing SF `laurel.*` | JourneyReportViews |
| JREPORT-8 | 战报 stat value one line, scales to 0.6 (Cursor's `cyWrapText` wrapped it) | JourneyReportViews |
| JREPORT-9 | 排名 row hint `mp.report.rank.hint`; memory photo labelled `mp.report.memory.photo %@` instead of hidden | JourneyReportViews |
| JSETTLE-4 开局 | Cursor's `showsStartMode` cell now reads the catalog words (`mp.settle.startMode.desk/alt`, else as sent) with the 开局 caption, combined for VoiceOver | JourneyReportViews |
| JREPORT-2 | Cursor's row button + `JourneyNodePhoto` kept; added the 44 pt leading thumb (MP wxml:53) and turned the single-photo sheet into `JourneyNodePhotoPages`, a paged viewer over every https node photo opened on the tapped one (MP `wx.previewImage` urls). VoiceOver label per node | JourneyReportViews |

Not re-applied, on purpose: `MPSectionHeader` / `MPRow` styles (JPROMO-3) — r7 moved the shared kit to the native inset-grouped look (native-ios-r1 §3.2), which wins over the MP `.jn-sec__h` weight. Seats / report bindings: Cursor's versions cover JSEAT-6, JSEAT-r7-1, JREPORT-3, JREPORT-5 (a 401 with a live session is now `.failed`, per Core `JourneySeatsSessionGate`). SALBUM-r7-1 camera, GROWTH-5 session profile, and every other round-2 file survived the merge unchanged.

### New this round

| id | what changed | files |
|---|---|---|
| JSETTLE-r7-1 (flows-g1 `[GAP-CLAUDE]`) | 完局优惠卡 mounted under the settle overview. Settle model reads Core `PlatformPass.overview` + `productList` (both on the read-only transport, merchants ask nothing, one read per page, a failed read = none), maps them into Core `JourneyFinishOfferResolver`; nil hides the card. Tap → `.membership` (month pass) or `.pass(productID:)` (MP `offer.url`). Purchase stays gated (`PlatformPass.writesReachable` false → gated note; money TEST-only, owner #3/#12). Prices are two-decimal from the resolver (owner #9) | App/PlayerJourneyReadBindings.swift, App/JourneyReportViews.swift |
| JSETTLE-r7-1 card | Gemini's `JourneyFinishOfferCardView`: MP `cy-icon coupon` → `MPAsset.FeatureIcon.coupon`, trailing chevron, 44 pt minimum, VoiceOver = name + price (MP aria-label) | App/MPGap/PlayRoam/PlayRoamRound4Views.swift |
| BWALL → badge-3d (flows-g1 `[GAP-CLAUDE]`), B3D-1 (part) | the 3D entry now also opens for every **unlocked identity** badge, as MP `goBadge3d`: `style=pin`, `glyph` from MP `CODE_TO_GLYPH` (+ `ROAM_POI_<id>` → citylit), `rarity` = Core `ObjectBadgePresentation.track(category:)`. The stage shows the pin hint `objects.badge3d.hint.pin` | App/ObjectBadgeWallParityViews.swift |
| OCARDS-4 (flows-g1 `[GAP-CLAUDE]`) | rename is now Gemini's `ObjectCardRenameSheetView` (MP 改名 sheet: name field with catalog label / placeholder, 64-char clamp + count, inline server error, 保存) instead of an alert; the sheet was rebuilt to the native structure (inline title, ✕ cancellation, 保存 confirmation item, spinner while saving, no swipe-dismiss mid-save). Pencil target 44 pt | App/PlayerGapViews.swift, App/MPGap/PlayRoam/ObjectCardCategoryAndRenameSheets.swift |
| OCARDS-3 sheet (prep) | `ObjectCardCategorySheetView` also rebuilt native, with optional MP `cat/*.png` icons, selected trait and caller identifiers — ready to mount (see Left) | App/MPGap/PlayRoam/ObjectCardCategoryAndRenameSheets.swift |

Fixture: `r3prb-settle-offer` (App/DesignFixtures/FixR3PlayRoamBFixtures.swift), added to `docs/port/accept/f-play-roam-b.txt` (26 routes).

### MP assets (mapping.md, my pages)

All rows for half-b files were applied in round 2 or are recorded as skipped there. New this round: `MPAsset.FeatureIcon.coupon` on the 完局优惠卡; laurel re-applied. Template-detail shelf tabs and member-journey icons (`dCyIcon*`, `dCyinfo*`, PlayerJourneyViews / mycanyu) are not on half-b pages. `laurel` in `App/PlayExperienceView.swift` (shared play page) is half a.

### Review / audit rows

`review/r7-rev-a/-b/-c`: still no Claude row for half-b pages. `audit/parity-r7-play-roam` P1 for half b: closed, except the rows below.

### Still left

| id | why |
|---|---|
| SCAM-1, SALBUM-1 (P0) | owner (`mediaUpload`, stamp image policy) |
| SCAM-2 rest, JSEAT-8, TGOALS-6 | owner |
| OCARDS-3 mount | `test_native_ui_accessibility_semantics.test_object_menu_keeps_native_action…` pins the native `Menu {` filter. The sheet is ready (keeps the `objects.category.<key>` ids `ObjectCardFlowTests` taps); Cursor to drop the `Menu {` pin, then it is a five-line swap in ObjectCardsView |
| BWALL-2 / BWALL-3 | Gemini's `BadgeWallTwoColumnGridView` draws remote art with `CYCachedAsyncImage` (bypasses the bounded `ObjectCardImageLoading` policy the wall uses) and drops the list/wall switch that `test_object_badge_wall_layout` pins; the shared `ObjectCardArtwork` shows loading / no-image text that does not fit a 76 pt tile. Needs a compact artwork state (Gemini) and the test un-pinned (Cursor) |
| B3D-1 scene | the pin opens on the existing medallion showroom; a procedural glyph scene (MP `glyphs.js` / `enamel-pin.js`) is Gemini |
| OCARDS-2 pile | Gemini's `ObjectCardPileAndGridView` uses `CYCachedAsyncImage` (same media-policy issue) and puts its gather toggle in a toolbar it does not own; not mounted |
| finish-offer analytics | `finish_offer_shown` / `finish_offer_click` are not in Core `AnalyticsEventClient.allowedEvents` (Cursor) |
| SALBUM-6, TGOALS-4, TEXPORT pending retry, GROWTH-9 / LEADER-7 refresh pins | Cursor (unchanged from round 2) |
| TANNIV-4 | shared reviewed route has no destination |

### Requests for Cursor

- Add `finish_offer_shown` / `finish_offer_click` to `AnalyticsEventClient.allowedEvents` (payload: MP `trackPayload`, bizType `platform_pass` / `marketing_product`).
- Drop the `Menu {` pin in `test_native_ui_accessibility_semantics` so the OCARDS-3 sheet can mount; un-pin the list/wall switch in `test_object_badge_wall_layout` for BWALL-3.
- Round-2 requests still open: `RoamExplorationGoal.progress: Int?`, the Growth refresh pins.

### Checks run here (no compiler in the cloud)

- Full `python3 -m unittest discover -s Tests/ContractChecks`: 218 FAIL/ERROR on `origin/ui/combined-r7` (clean worktree) and the same 218 on this branch — **0 new**. (One interim new failure, `test_localization_key_catalog_contract`, came from two fragment-only rename keys; the sheet now uses the catalog keys `playerGap.card.renamePlaceholder` 卡片名称 and `objects.rename.placeholder`, and those fragment entries were removed.)
- Targeted (every Journey / PlayerGap / ObjectBadge / MPGap test file, 277 tests): same 4 failures + 2 errors as the base. `test_object_badge_3d_preview`, `test_object_badge_wall_layout`, `test_native_ui_accessibility_semantics`, `test_native_repair_batch_integration`: pass.
- `tools/check_typography_lint.py`, `tools/check_design_lint.py`: PASS. `tools/check_a11y_lint.py`: no finding in these files.
- APIs grepped on r7 before use: `PlatformPass.overview(token:viewerIsMerchant:)`, `productList(token:)`, `writesReachable`, `PlatformPassOverview.enabled/holding.active/libraryCount/plans`, `PlatformPassPlan.code/title/priceFen`, `PlatformPassProduct.id/name/productKind/cashPrice/pointsPrice/topicIDs`, `JourneyFinishOfferResolver.resolve`, `JourneyFinishOffer(kind:id:name:priceText:)`, `JourneyFinishOfferPassInput/ProductInput` inits, `AppSession.makePlatformPassReader()/mpViewerIsMerchant`, `MPParityRoute.membership/.pass(productID:)`, `mpParityRouteDestination`, `JourneyNodePhoto.url`, `MPRow(leading:)`, `ObjectBadgePresentation.track(category:)`, `ObjectBadgeDetailParameters(query:fallbackName:)`, `ObjectCardRenameValidator`, `CYColor.dangerText`, `MPAsset.FeatureIcon.coupon`, `MPAsset.BadgeMedal.laurel`.

## Round 4 (2026-11-25)

- **Brief:** `origin/design/handoff-r2:docs/briefs/fix-r3-round4.md` (+ `wave-x10.md`, `owner-decisions-1124.md`). Gemini is out of quota, so this round also covers its MP-alignment work for half-b pages.
- **Sync:** merged `origin/ui/combined-r7` @ `0e1cf578a` (Cursor round 4: W2 wiring, a11y zero baseline, Swift 6; Gemini round 7) at the start, no conflicts.
- **Layer:** App/ only. No Core, Tests, `Localizable.xcstrings` or project edits. New / overridden strings in `docs/port/strings/fix-r3-play-roam-b.json` (en + zh-Hans).

### 1 · Flows (`flows-g1.md` / `flows-g2.md`, half-b pages)

Every `navigateTo` / `redirectTo` / `switchTab` / `reLaunch` / `navigateBack` in the half-b MP pages was listed from the MP source and checked against the app.

| MP page | edge | app | status |
|---|---|---|---|
| seats | 编辑 → gerenziliao; 去起点 → play; missing ids → back / index | as in r7 | ✅ |
| report | 结算 → settle; 同行席位 → seats; missing → back / index | as in r7 | ✅ |
| settle | 完局优惠卡 → `offer.url` (membership / pass detail) | round 3 | ✅ |
| settle | 完成 / 返回: navigateBack, or reLaunch 票夹 when the page stack is empty | the app always pushes settle onto a stack (report, play end, deep link host), so `dismiss()` always has a page to return to; no 票夹 fallback needed | ✅ (native) |
| promo | none (reached from 我的 / shezhi 邀请与收益, flows-g2 shezhi.js:167) | `SettingsView` row (account-publish, r7) + 我的 | ✅ |
| monthly-recap / goals / anniversary / export | no page navigation (in-page only); anniversary 查看当前路线 | as in r7; TANNIV-4 shared reviewed route still has no destination | ✅ / see Left |
| growthcenter | row → leaderboard (metric, period); 去探索 → switchTab index | GROWTH-6 fallback (round 1) | ✅ |
| leaderboard | 去探索 → switchTab index | same fallback | ✅ |
| stamp-album | 打开集邮相机 → stamp-camera | session camera (SALBUM-r7-1) | ✅ |
| stamp-camera | after 已入册 → redirectTo stamp-album | the created stamp opens in the album (`RoamCreatedStampView`) instead of a timed redirect | ✅ (native) |
| badge-wall | tap → badge-3d `?name=` / `?style=pin&glyph=` | round 3 | ✅ |
| badge-wall | empty 去探索 → switchTab index | **new:** the empty wall's CTA now falls back to the root tab switch (首页) when no explore action was injected (same `growthExploreFallback` as GROWTH-6); the duplicate header CTA was removed (MP has one) | ✅ |
| badge-3d | back, else switchTab roam | system back (pushed page) | ✅ (native) |
| object-cards | category / rename sheets, pile gather | rename mounted (round 3); category sheet + pile still blocked (see Left) | ⚠️ |

### 2 · Image parity (MP image slots → app)

MP `cy-icon` names are the coolicons line-glyph font (`components/cy/icon/icons.wxss`, generated, no PNG); they have no `MPAsset` and stay SF Symbols, like the system-control glyphs. `cy-empty kind="empty"` / `icon="empty-state"` is the two-layer illustration `empty_state_bg` + `empty_state_figure`, which the app draws through `CYEmptyIllustration(.generic)` when a `CYEmptyState` uses the `tray` symbol.

| MP page | MP slot | app | status |
|---|---|---|---|
| seats | `head.cover` (server) | `CYCachedAsyncImage(headCoverURL)` | ✅ |
| seats | seat `avatar` (server) / initial | `MPAvatar(url:initial:)` | ✅ |
| seats | 怎么玩 tiles `cy-icon {{item.icon}}` | SF line glyphs | ✅ (cy-icon) |
| seats | state `cy-empty kind=…` (glyph kinds) | `CYEmptyState` glyph | ✅ |
| promo | `cy-empty kind="empty"` 暂无可核实记录 | **new:** `tray` → MP empty art | ✅ |
| settle | `cy-icon coupon` / `chevron-right` (finish offer) | `MPAsset.FeatureIcon.coupon` (round 3) / SF chevron | ✅ |
| settle | `cy-icon star / star-filled` (rating) | SF star | ✅ (cy-icon) |
| settle | trophy `cy-illus` | `CYMomentSeal` (owner-approved r7 row 12) | ✅ (intended) |
| settle | share card image (canvas) | `ImageRenderer` card | ✅ |
| report | node `photoUrl` thumb + preview | 44 pt thumb + paged viewer (round 3) | ✅ |
| report | memory `item.pic` | **new:** `CYCachedAsyncImage` (JREPORT-7) | ✅ |
| report | memory `cy-empty kind="empty"` 这一局还没有回忆 | **new:** `tray` → MP empty art | ✅ |
| report | rank-board laurel | `MPAsset.BadgeMedal.laurel` (round 3) | ✅ |
| report | `cy-icon arrow-right` rows | SF chevron (disclosure) | ✅ |
| monthly-recap | `cy-icon back / chevron-right` month arrows | SF chevrons (system control) | ✅ |
| goals | `cy-empty kind="empty"` 还没有探索目标 | **new:** `tray` → MP empty art | ✅ |
| goals | `cy-icon plus` (FAB / new) | SF plus | ✅ (cy-icon) |
| anniversary / export | no image slot | — | ✅ |
| growthcenter | avatar `avatarUrl \|\| d_profile.png` | `MPAsset.AvatarDefault.dProfile` (round 2); remote avatar not drawn (`test_growth_source_contract` forbids AsyncImage) | ⚠️ owner |
| growthcenter | badge `iconUrl` else initial | initial disc (same test) | ⚠️ owner |
| growthcenter | `cy-icon star / chevron-right` | SF | ✅ (cy-icon) |
| leaderboard | `avatarUrl` else memoji 1/2/3 | `MPAsset.AvatarDefault.memoji1/2/3` (round 2) | ✅ |
| leaderboard | `cy-empty kind="empty"` 这张榜还没有人上榜 | **new:** `tray` → MP empty art | ✅ |
| leaderboard | crown `cy-icon star` | SF star (round 2) | ✅ (cy-icon) |
| stamp-camera | live camera / shot; `cy-icon close-sm` | AVFoundation preview; SF xmark (mapping: keep) | ✅ |
| stamp-album | stamp `picUrl` | `RoamStampImage` (https only); **new:** VoiceOver 城市签图片 (SALBUM-8) | ✅ |
| stamp-album | signed-out `icon="empty-state"` | shared `RoamExperienceIssue` (half a / shared roam component, text + SF) | ⚠️ shared |
| stamp-album | 还没有邮票 (no kind → no art) | `rectangle.stack` themed glyph | ✅ |
| stamp-album | `cy-icon plus` FAB | SF plus | ✅ (cy-icon) |
| badge-wall | `iconUrl` → generated pin → `cy-icon star` | `MPAsset.BadgeMedal.badgeDemo` stand-in (remote art is BWALL-2, Gemini/Cursor) | ⚠️ (see Left) |
| badge-wall | empty `icon="empty-state"` | `CYEmptyState(systemImage: "medal")` — `test_object_badge_wall_layout` pins that exact line; needs `"tray"` (Cursor) | ⚠️ Cursor |
| badge-wall | `icon_close_sm.png`, `icon_right.png` | SF xmark / chevron (mapping: keep) | ✅ |
| badge-3d | `fallbackSrc` → `badge-demo.png` | `MPAsset.BadgeMedal.badgeDemo` (round 2) | ✅ |
| badge-3d | WebGL matcap `gold_matcap` | SceneKit material (no texture slot) | ⏭ |
| object-cards | `catIcon[filter]` / sheet `catIcon[key]` | `MPAsset.FeatureIcon.*` (round 2; sheet ready in round 3) | ✅ |
| object-cards | `cutoutUrl` | `ObjectCardArtwork` (bounded media policy) | ✅ |
| object-cards | `cy-icon edit / list / gps` | SF pencil / list / location | ✅ (cy-icon) |
| object-cards | error `icon="empty-state"` 藏品册无法打开 | inline error text (no full-page error state on this screen) | ⚠️ |

### 3 · Copy (MP text → app)

All MP Chinese literals of the 15 half-b pages were extracted (wxml + js, comments stripped) and matched against the catalog. Fixed this round (fragment keys, en + zh-Hans; existing keys overridden where the key is page-specific):

| page | MP text | key |
|---|---|---|
| seats | 邀请失败 (OK answer without a token, or no server message) / 撤销失败 | new `mp.seats.invite.failed`, `mp.seats.cancel.failed` |
| settle | 分数 (overview cell; report keeps 解谜分) | new `mp.settle.score` |
| settle | 评价暂时无法提交 (non-OK without a message) | new `mp.settle.rate.failed` |
| growthcenter | 登录后查看成长记录 / 当前身份不能查看成长记录 | new `mp.growth.signInRequired`, `mp.growth.denied` (see note) |
| growthcenter | 排行榜加载失败 (score card) / 部分成长数据暂时不可用 (足迹) / 成长数据没有加载出来 (徽章) | new `mp.growth.boardFailed`, `mp.growth.overviewFailed`, `mp.growth.badgesFailed` |
| leaderboard | 排行榜加载失败 / 当前内容无法查看 | `mp.growth.boardFailed`, new `mp.growth.boardDenied` |
| monthly-recap | 读取下一页记录 (VoiceOver) | new `roam.tools.recap.nextPage.a11y` |
| anniversary | 读取更早的回忆, 查看当前路线 {title} (VoiceOver) | new `roam.tools.anniversary.more.a11y`, `roam.tools.anniversary.openRoute.a11y %@` |
| goals | 读取更多目标 (VoiceOver) | new `roam.goals.more.a11y` |
| export | 分享完整文件 / 保存完整文件 (VoiceOver) | new `roam.export.share.a11y`, `roam.export.save.a11y` |
| badge-wall | 登录后查看我的勋章, 勋章数据没有到达, tile meta 还没点亮 | override `badgeWall.state.signIn`, `badgeWall.state.error`, `objects.badge.meta.locked` |

Note: the growth keys use an `mp.growth.` prefix on purpose. `test_growth_center_index_page_ready` and `test_growth_source_contract` compare every `"growth.…"` literal in the Growth sources with `docs/growth-center-localizations.json` and the catalog, so overriding `growth.signInRequired` / `growth.denied` / `growth.badges.empty` in a fragment would break those pins after the merge. `growth.badges.empty` (MP 还没有点亮任何徽章) is therefore left; see Left. For the same reason, overrides of keys pinned elsewhere were **not** made (or were removed): `roam.goals.retryOriginal` (以原操作重试), `roam.goals.cancelMessage` (round-2 TGOALS-5, …此操作不可撤销。) and `roam.export.sourceChanged` (来源已变化…) are pinned by `tools/build_roam_private_tools_localizations.py` (`test_roam_private_tools`); `objects.login` (登录后查看自己的册子) and `objects.failed` (藏品册无法打开) by `Resources/ObjectCardLocalizations.fragment.json` (`test_native_repair_batch_integration`); `stampAlbum.denied` (当前身份不能查看) by `Resources/W210GrowthBadgeStampLocalizations.fragment.json`.

Already equal before this round (spot-checked): seats / promo / report / settle state titles, tools page titles and empty lines, leaderboard empty + hint, stamp-album 还没有邮票 / 打开集邮相机, badge-wall 还没有点亮勋章 / 去探索, object-cards category names.

### 4 · P2 rows (audit/parity-r7-play-roam, Claude)

| id | change | files |
|---|---|---|
| JSETTLE-8 | an earlier progress dot steps back (MP onBack = previous step), 44 pt targets; VoiceOver adjustable (swipe down = previous step); the system back still leaves 结算 | App/JourneyReportViews.swift |
| JSETTLE-9 | rank-step heading `.cardTitle` + header trait (MP `st-h`) | App/JourneyReportViews.swift |
| JSETTLE-10 | overview numbers one line, scale to 0.7 (SE / AX sizes) | App/JourneyReportViews.swift |
| settle row 25 (L09-059) | an accepted rating is never sent twice (提交 again shows thanks); a different draft after a failed submit drops the kept `request_id` | App/PlayerJourneyReadBindings.swift |
| JREPORT-7 | memory photos on `CYCachedAsyncImage` (cache, placeholder, failure tile), 16:10 instead of a fixed 180 pt crop | App/JourneyReportViews.swift |
| JSEAT-10 (part) | invite sheet `[.medium, .large]` for large Dynamic Type. Save-image stays out (photo-library write; privacy gate) | App/JourneyLandingViews.swift |
| JSEAT-11 (part) | only the expired circle dims; the 已过期 label keeps `textSecondary` contrast | App/JourneyLandingViews.swift |
| SALBUM-8 | real stamps read 城市签图片; 城市示例插图 only for the offline example | App/RoamStampViews.swift |
| TRECAP-3 / GROWTH-7 / SALBUM-5 residue | `.font(Theme.Font.body)` ×2, `.font(.headline)`, `.font(.caption.monospaced())` → `cyText` | App/RoamPassportToolsViews.swift, App/RoamMonthlyRecapDetailView.swift, App/GrowthCenterView.swift, App/RoamStampViews.swift |
| LEADER-4 residue | error title 排行榜加载失败 (above) | App/GrowthLeaderboardView.swift, App/GrowthCenterComponents.swift |

Open P1 for half b: none owned by Claude (SCAM-2 rest, JSEAT-8 are owner rulings).

### 5 · Accessibility lint

`python3 -B tools/check_a11y_lint.py`: **no finding in half-b files.** The one current finding is `App/ClubKit/ClubWorkbenchKit.swift:261` (club area, present on `origin/ui/combined-r7` before this branch); left to the club owner to avoid a cross-area edit.

### Still left (round 4)

| id | why |
|---|---|
| SCAM-1, SALBUM-1 (P0); SCAM-2 rest, JSEAT-8, TGOALS-6 | owner (unchanged) |
| seats 可转赠 / 转赠第 N 席 sheet (MP DEC-F12 B, `api.seatTransferPhone`, `lobby.transferable`) | new MP feature; Core has no seat-transfer contract or `transferable` field — Cursor first, then the App sheet |
| growth `growth.badges.empty` → 还没有点亮任何徽章 | the value is pinned by the growth catalog tests (`docs/growth-center-localizations.json`); Cursor to re-pin, then a one-value fragment override |
| goals 以原操作重试 / cancel …此操作不可撤销。, export 来源已变化…, objects 登录后查看自己的册子 / 藏品册无法打开, stamp-album 当前身份不能查看 | catalog values pinned by `tools/build_roam_private_tools_localizations.py`, `Resources/ObjectCardLocalizations.fragment.json`, `Resources/W210GrowthBadgeStampLocalizations.fragment.json`; Cursor to update those sources, then the overrides go in (the round-2 `roam.goals.cancelMessage` override was removed from my fragment for this reason) |
| growth remote avatar / badge icon | `test_growth_source_contract` forbids `AsyncImage` in Growth*.swift (owner) |
| badge-wall empty art (`"medal"` → `"tray"`) | `test_object_badge_wall_layout` pins `CYEmptyState(systemImage: "medal", "badgeWall.empty"` (Cursor) |
| OCARDS-3 category sheet, OCARDS-2 pile, BWALL-2/3 grid | still blocked by the `Menu {` pin and the media-policy issues listed in round 3 |
| stamp-album / badge-wall signed-out empty art, roam `RoamExperienceIssue` copy (登录后查看自己的册子, 集邮册无法打开) | shared roam / profile components used by half-a pages too |
| JSEAT-10 save image | photo-library write behind the privacy gate (owner) |
| SALBUM-6, TGOALS-4, TEXPORT pending retry, GROWTH-9 / LEADER-7 refresh pins, finish-offer analytics | Cursor (unchanged) |
| TANNIV-4 | shared reviewed route has no destination |

### Requests for Cursor (round 4)

- Seat transfer by phone: `seatTransferPhone(registrationId, seatNo, name, phone, requestId)` contract and `lobby.transferable` decode (MP `subpackageJourney/pages/seats/index.js:150-178`, DEC-F12 B).
- Update the pinned copy sources above (roam private tools generator, ObjectCard and W210 fragments) to the MP text.
- Re-pin `growth.badges.empty` in the growth catalog tests to 还没有点亮任何徽章 (MP growthcenter wxml:62).
- Allow `CYEmptyState(systemImage: "tray", "badgeWall.empty"` in `test_object_badge_wall_layout` (MP badge-wall `icon="empty-state"`).
- Round 2/3 requests still open (`RoamExplorationGoal.progress: Int?`, Growth refresh pins, `Menu {` pin, finish-offer analytics).

### Checks run here (no compiler in the cloud)

- Full `python3 -m unittest discover -s Tests/ContractChecks`: `origin/ui/combined-r7` (clean worktree) 223 FAIL/ERROR. This branch as pushed: the same set plus two that only read the merged catalog (`test_no_looked_up_key_is_missing_from_every_catalog`, `test_roam_private_tools.test_reviewed_source_contracts_all_pass`: the new fragment keys are not in `Localizable.xcstrings` yet). With the fragment merged into the catalog (simulated, then reverted): **0 new failures** against the base.
- Targeted growth / badge / object / stamp / journey / roam checks: pass (same as base) with the fragment merged.
- `tools/check_typography_lint.py` PASS (Theme.Font 7 → 5), `tools/check_design_lint.py` PASS, `tools/check_a11y_lint.py`: no finding in half-b files (the one finding is club, see §5).
- APIs grepped on r7 before use: `RootTabSwitch.growthExploreFallback(_:)`, `CYEmptyIllustration.kind(matching:)` (`tray` → generic MP art), `CYCachedAsyncImage(_:role:)`, `CYSpacing.minTouchTarget`, `cySheet(detents:)`, `JourneyEnvelope.message/unconfirmed`, `appLocalized(_:locale:)`, `cyText(_:weight:monospacedDigit:)` on `View` and `Text`, `@ObservationIgnored` (used in App already).

### Fixtures / acceptance

No new screen or state this round; the 26 routes in `docs/port/accept/f-play-roam-b.txt` cover the changed pages (settle, report, seats, promo, growth, leaderboard, stamp album, badge wall, tools).
