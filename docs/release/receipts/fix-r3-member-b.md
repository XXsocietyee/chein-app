# Receipt: fix/r3-member-b (Claude F-agent, member area, half b)

- **Brief:** `design/handoff-r2:docs/briefs/wave-x10.md`.
- **Base:** `origin/ui/combined-r7` @ 7fdfad1f1, with `origin/restyle/r4-me-account` merged first (the member restyle branch touches the same files).
- **Scope:** round-1 audit pages 16–30 (`subpackageMember/order` … `appeal-mine`).
- **Gap sources used:**
  - `audit/parity-r7-member:docs/audit/parity-r7/member.md`, the Claude-owned FIX-QUEUE lines for pages 16–30;
  - `review/r7-rev-{a,b,c}`: no Claude App-layer finding on these pages. B-16 and B-21 belong to P5, and F-C* to Gemini's parked views.
- **Layer:** App/ only. No Core types, no tests, no `Localizable.xcstrings`, no pbxproj.
- **Strings:** new keys and overrides are in `docs/port/strings/fix-r3-member-b.json` (xcstrings format).
- **Acceptance fixtures:** `docs/port/accept/f-member-b.txt`.

## Fixed

| id | page | what changed | files |
|---|---|---|---|
| R7-MEM-17-1 (P1) | 17 订单详情 | The `orderinfo?id=` / `order?detailId=` deep link now mounts `SessionOwnedOrderDetailView`. It shares the lifecycle coordinator factory with 我的订单 (`OwnedOrdersLifecycleHost(detailID:)`, one `production:` site) and gets the session ticket reader, so 取消订单 / 申请退款 and 查看票 appear, with 登录 when signed out. | App/OwnedOrderComposition.swift, App/MPReviewedPageScreen.swift, App/ProfileReadScreen.swift |
| FIN-17-6 (P2) | 17 | `orderinfo?outTradeNo=` opens `OrderCenterEntryView` prefilled when the G2 order-center grant exists. Without the grant it falls back to 我的订单. | App/MPReviewedPageScreen.swift |
| R7-MEM-16-2 (P2) | 16 我的订单 | A merchant-role session is sent to 我的项目 (MP M-25, order.js:20-23), both from the deep link and from the `.playerOrderList` notification route. | App/MPReviewedPageScreen.swift, App/SubscribeMessageTapScreens.swift |
| FIN-16-7 (P2, partial) | 16 | Card: 已下架 when neither the activity nor the topic reads back (OR-034). The address opens Apple Maps as a separate 44 pt borderless control with a VO label 在地图中打开 …. `.manualRefund` shows 查看处理进度. | App/ProfileOrdersView.swift |
| FIN-16-8 (P2) | 16/17 | The toolbar ↻ is gone on the 我的订单 list and on the detail; pull-to-refresh remains. Pages opt out through `\.profileReadShowsRefreshButton` (default true, so other Profile pages are unchanged). The card amount already uses the `dataXL` display token. | App/ProfileReadScreen.swift, App/ProfileOrdersView.swift |
| R7-MEM-16-3 (P2) | 16 | zh copy is now 当前身份不能查看订单 and 订单加载失败. | strings fragment |
| FIN-17-7 (P2) | 17 | The state notice uses `.cyText(.cardTitle)`, `CYStatusChip` and `CYSpacing` instead of raw fonts and a hand-made capsule. | App/ProfileOrdersView.swift |
| R7-MEM-17-2 (P2, partial) | 17 | The refund policy text (`refundDeadlineDisplay` or the MP default sentence) and 本单未收取费用… for free orders now sit in 退款与客服, replacing the bare 退款截止 row. | App/ProfileOrdersView.swift |
| FIN-18-2 (P1) | 18 积分明细 | Pull-to-refresh reads into a fresh `WalletLedgerPager` and swaps it in only on success. A retryable failure keeps the rows and toasts 刷新失败，稍后再试. Sign-in and unavailable failures still retire the rows. | App/WalletCommerceViews.swift |
| FIN-18-6 (P2) | 18 | Point rows show `M月D日 HH:MM` (MP rows.js `shortTimeText`). Unparseable times stay verbatim. | App/WalletCommerceViews.swift (`WalletPointsShortTime`) |
| FIN-18-8 (P2) | 18 | Rows are revealed 20 at a time with 加载更多. 已经到底了 shows only once the list was longer than 20. Income deltas use the brand colour on 积分明细. | App/WalletCommerceViews.swift |
| FIN-19-4 (P2) | 19 提现记录 | The `.login` state offers 登录 when the host passes `onSignIn`; the deep link passes the 我的-tab sign-in. | App/WithdrawalHistoryView.swift, App/MPReviewedPageScreen.swift |
| R7-MEM-19-1 (P2) | 19 | `pages/coop/withdraw/records/index` mounts with merchant chrome. | same |
| FIN-19-5 (P2) | 19 | Row spacings use `CYSpacing.md/.xs/.sm`. | App/WithdrawalHistoryView.swift |
| FIN-20-4 (P2) | 20 邀请记录 | While no row is loaded, `ProfileInviteHistoryIssueView` renders the full-page failure state (`CYEmptyState(kind: .failure)`) with 登录 (from the host's `onSignIn`) or 重试. With rows it stays inline. This is environment-driven, so the pinned call sites are unchanged. | App/ProfileInviteHistoryIssueView.swift, App/SocialInviteHistoryView.swift, App/MPReviewedPageScreen.swift |
| FIN-20-5 (P2) | 20 | Rows pass `url: member.avatar` to `CYAvatarView`. The 待解锁 / 待同步 neutral pill was already present. | App/SocialInviteHistoryView.swift |
| R7-MEM-20-1 (P2) | 20 | Latest-earn card above the list (avatar, +N 积分 in brand, nickname · 首购奖励已到账, short time), static with no scan animation. | App/ProfileInviteHistoryIssueView.swift (`ProfileInviteLatestEarnCard`), App/SocialInviteHistoryView.swift |
| PLY-21-3 (P2) | 21 票夹 | `TicketPassSheet` shows 开始游戏 under the pass when the play provider is injected and the ticket is ready, openable and not locked. It pushes `TicketWalletDetailView(autoStartsPlay: true)`, which re-reads `registration/info` and starts only when the fresh read allows it. | App/TicketPassSheet.swift, App/TicketWalletDetailView.swift |
| PLY-21-4 (P1, label part) | 21 | A cleared ticket's play button reads 查看记录, both in the detail and in the pass sheet. | App/TicketWalletDetailView.swift, App/TicketPassSheet.swift |
| PLY-21-15 (P2) | 21 | Card art uses token colours only (brandStrong / gameAccent / rare / coverFallback over bgSurfaceStrong). The decorative QR glyph is dropped. | App/TicketWalletView.swift |
| PLY-22-4 (P2) | 22 我的参与 | The first load shows `CYSkeleton` instead of `ProgressView`. | App/PlayerJourneyViews.swift |
| R7-MEM-22-1 (P2) | 22 | A quiet reload on return from a pushed route keeps the rows and shows no 正在更新 pill. The `.task(id:)` re-run no longer clears loaded rows for the same scope. | App/PlayerJourneyViews.swift |
| PLY-23-8 (P2) | 23 参与详情 | When the orient/character entry cannot be bound, an inline 角色卡与成绩入口暂不可用 + 重新加载 row replaces the hidden entry. | App/OrphanScreenMounts.swift |
| PLY-24-5 (P2) | 24 角色卡 | The header title uses `.cardTitle`. | App/CharacterSheetDetailView.swift |
| PLY-24-6 (P2) | 24 | A secondary 刷新角色卡 button at the end of the ready card, driven by the host's `.refreshable` action (`@Environment(\.refresh)`). `CharacterCardReadbackView.swift` is untouched because it is SHA-pinned by c02. | App/CharacterSheetDetailView.swift |
| PLY-24-7 (P2) | 24 | The dice button drops `accessibilityValue` and `accessibilityHint`. | App/CharacterSheetDetailView.swift |
| PLY-25-9 (P2) | 25 本局计分 | The submitting `ProgressView` is labelled 正在提交申诉…, and the status icon and text are combined for VoiceOver. | App/OrientScoreReviewSection.swift |
| R7-MEM-27-1 (P1) | 27 投诉与建议 | Signed-out topic read: a 登录 button presents `LoginView(intent: .player)`, and the session revision rebuilds and reloads the page. | App/ProfileComplaintPreparationView.swift |
| PLY-27-5 (P2) | 27 | The two `.font(.subheadline)` → `.cyText(.bodyCompact)`. | same |
| PLY-27-6 (P2) | 27 | 提交投诉 is disabled until a topic is chosen and the reason has ≥5 characters, using the Core `validation` (`.topic` / `.reasonShort`). Over-limit text still reaches the inline message. | same |
| R7-MEM-28-1 (P2) | 28 我的举报 | The skeleton shows only on the first load (no rows). A refresh failure over kept rows toasts instead of drawing the empty-state block. | App/SquareReportProgressView.swift |
| PLY-28-6 (P2) | 28 | Each row is one VoiceOver element with the hint 查看进度, plus a disclosure chevron. | same |
| PLY-29-6 (P2) | 29 举报进度 | 申诉已提交 / 申诉结果未确认… / 申诉没有提交成功… move to catalog keys (`report.appeal.*`). | App/CommunityTrustPlayerViews.swift, strings fragment |
| R7-MEM-29-1 (P2) | 29 | A 查看我的全部举报 row pushes `SquareReportProgressView`. | App/MemberReportProgressDetailView.swift |
| PLY-30-5 (P2) | 30 我的申诉 | The appeal detail has an 打开本局计分 row to `OrientScoreDeepLinkScreen(topicID:sessionID:)`. | App/MemberScoreAppealDetailView.swift |
| PLY-30-6 (P2) | 30 | The title comes first and the status chip trails, in both layouts. The chevron uses `.cyText(.meta)`. | App/MemberScoreAppealListView.swift |
| R7-MEM-30-1 (P2) | 30 | 已经到底了 when the list is loaded and there is no more. | same |
| R7-MEM-30-2 (P2) | 30 | `score.detail.boundary` developer copy and the 刷新 pill are removed; pull-to-refresh was added on the detail. | App/MemberScoreAppealDetailView.swift |

## Left, with reasons

| id | why |
|---|---|
| PLY-21-6 (P1) | **Blocked by a pinned contract.** `Tests/ContractChecks/test_ticket_wallet_team.py:16` asserts the wallet-wide `TeamHomeView(...)` link exists. Removing it is a new ratchet failure. Request for Cursor (`cursor/core-member` or the test burn-down): retire that assertion (owner rule: team follows the current ticket). After that, the App change is a 10-line deletion in `TicketWalletView.swift:112-122`. |
| PLY-26-2 (P1) | **Blocked by pinned contracts.** `test_owned_template_pagination.py` (two tests, which split on `if !keyword.isEmpty {` / `templateAuthor.shelf.clearSearch`) and `Tests/AppUITests/TemplateOwnShelfFlowTests.swift` (four tests) pin the keyword field and 清除 pill. Request for Cursor: retire them per the owner ruling. The App change is the removal of `TemplateAuthoringMineView.swift:34-45`. |
| PLY-21-4 (rest) | "Open a no-game session ticket straight on its code" needs MP `activityHasGame(cmsActivity)` facts on `TicketWalletTicket`. **Core request (Cursor):** decode the activity game flag (`wNoGame`). |
| FIN-16-7 (rest) | The cover image needs `cmsActivity.imgUrl` / `cmsTopic.imgArr[0]` on `ProfileOrder`; Core does not decode them. **Core request (Cursor):** add `coverURL` to `ProfileOrder`. The tile stays as the placeholder. |
| R7-MEM-17-2 (rest) | The settle-stage 退款进度 block (MP `settleView`: stage, tone, rows) needs refund-settlement fields that `ProfileOrder` does not decode. **Core request (Cursor).** The policy text is done. |
| FIN-17-4, FIN-17-8, PLY-21-13, PLY-23-3/4/6, PLY-25-3/5, PLY-26-4, PLY-29-4 | Gemini (parked `App/MPGap` views). Not touched. |
| FIN-16-2, PLY-21-2, PLY-21-5, R7-MEM-21-1/2/3, PLY-21-14, PLY-25-4, PLY-26-5, R7-MEM-23-1, R7-MEM-24-1 | Cursor (Core contracts). Not touched. |
| FIN-19-1, FIN-20-6, R7-MEM-16-1, PLY-21-8, R7-MEM-24-2, PLY-25-2, R7-MEM-26-1 | Owner decisions. |
| MP-asset consistency | No `cursor/mp-assets` branch or `MPAsset` accessors exist yet. The MP order card icons (`d_orderIcon.png` / `d_orderIcon2.png`) still use SF Symbols `clock` / `mappin.and.ellipse`. Swap them once `MPAsset` lands. |

**In flight, skipped:**
- `restyle/r4-me-account` is merged here as the base.
- `gap/g1-player` and `gap/g2-ops` own the parked member views.
- No `cursor/*` or `port/*` branch touches these App files.

## Verification
- No compiler in the cloud; every API used was grepped on the base. The coordinator should compile.
- `python3 tools/contract_ratchet.py --check`: see the acceptance section below.

## Acceptance (cloud, contract layer only)
- `tools/contract_ratchet.py --check` on this branch: 196 failing against a baseline of 184, so **11 new**. Every one of the 11 also fails on untouched `origin/ui/combined-r7` (checked by running the same tests in a worktree of the base). **0 are introduced by this branch.** The 11:
  - app_store_privacy usage strings
  - appsec_review 5
  - design_system raw colour/radius
  - violet 7a5cff
  - journey_role_view ×2
  - localization_key_catalog
  - ops_safety audit catalog
  - play_gameplay_mode bilingual
  - view_literal_localization
  - workshop_paid_professional
- Contract modules touching the edited files all pass: pkg05, w2_04_orders, w2_04_member_tools, social_invitation_lifetime, ticket_wallet_team, native_design_motion, c02, owned_template_pagination (87 tests).
- **Not run here:** the Xcode build, the Core `swift test`, AppUnit and the screenshots. There is no macOS runner in this session, so they need the coordinator or the Acceptance workflow. Fixture routes are in `docs/port/accept/f-member-b.txt`.

## Round 2 (2026-11-24)

- **Brief:** `design/handoff-r2:docs/briefs/fix-r3-round2.md` plus `owner-decisions-1124.md`.
- **Sync:** merged `origin/ui/combined-r7` @ 82388e4a5 (Cursor K1–K10, W1, C7 MP assets). The only conflict was `tools/check_typography_lint.py`; I took the r7 side (the newer `BELOW_CAPTION` rule). The lint passes.
- **Cursor W1 call sites:** none of them touch a member-b App file. The only exception is `CouponCodeView` `.notMine`, which is half a and was already wired by the integrator.

### MP assets (`docs/mp-assets/mapping.md` rows applied)

| mapping row | page | where | files |
|---|---|---|---|
| [x] `MPAsset.FeatureIcon.dOrderIcon` | 16 我的订单 | Time-range and date line on the order card (was SF `clock` / `calendar`) | App/ProfileOrdersView.swift |
| [x] `MPAsset.FeatureIcon.dOrderIcon2` | 16 | Address line, both the Maps button and the plain text (was SF `mappin.and.ellipse`) | App/ProfileOrdersView.swift |
| [x] `MPAsset.EmptyState.iconTicketEmpty` | 17 订单详情 | Hero tile fallback when there is no cover (MP `resolveHeroImage` fallback). `OrderCoverTile` gained an optional `fallback:` image; the default is unchanged for the other callers. | App/OrderCardComponents.swift, App/OrderLifecycleView.swift |
| [x] `MPAsset.FeatureIcon.iconGo` | 21 票夹 | Round tinted `wc__go` badge, top-trailing on each wallet card (decorative) | App/TicketWalletView.swift |
| [x] `MPAsset.BannerCover.coverRoute` | 21 | Replaces the SF `ticket.fill` watermark with the MP no-cover illustration (`wc__im--illus`, cover-route.svg) | App/TicketWalletView.swift |
| [x] `MPAsset.FeatureIcon.iconPlay` | 21 | Icon of 开始游戏 / 查看记录, in both the detail and the pass sheet (was SF `play.fill` / `clock.arrow.circlepath`). It uses the template imageset, so it tints with the button. | App/TicketWalletDetailView.swift, App/TicketPassSheet.swift (`TicketWalletPlayGlyph`) |
| [x] `MPAsset.BrandLogo.dCyIcon` / `dCyIcon2` | 22 我的参与 | Row date and mode · place icons (was SF `clock` / `mappin.and.ellipse`) | App/PlayerJourneyViews.swift (`ParticipationMPGlyph`) |
| [x] `MPAsset.FeatureIcon.dCyinfo1` / `dCyinfo2` | 23 参与详情 | 最终分配节点 and 接待时间 label icons | App/PlayerJourneyViews.swift |
| [x] `MPAsset.FeatureIcon.dCyinfo4` | 23 | Figure beside the fixed 退出与暂停规则 text | App/PlayerJourneyViews.swift |
| [ ] `MPAsset.EmptyState.emptyStateBg` / `emptyStateFigure` | 16, 21, 22, 28, 30 empty states | **Not mine.** `CYEmptyState` / `CYStates` is the shared design-system component (mapping says `App/DesignSystem/CYStates.swift (shared)`). Request for the DS/restyle owner: draw the MP art there, and every member empty state picks it up. | — |
| [ ] `MPAsset.AvatarDefault.dProfile` | 20 邀请记录 | **Not mine.** The avatar placeholder lives in the shared `CYAvatarView`; same request. | — |

System-control glyphs (chevrons, close, share, search, ellipsis) and generic action icons with no MP artwork (`list.bullet.rectangle`, `arrow.clockwise`, `info.circle`, the status-chip state symbols) stay SF Symbols.

### Review findings (r7-rev-a/b/c, Claude-owned, member pages 16–30)

| id | what changed | files |
|---|---|---|
| B-16 (P1) | The 已含 / 需消费 / 需预约 lines are removed from the ticket-wallet entitlement row. The backend never sends those fields on that payload. The Core fields are left alone (Cursor's layer). Porting FE-G5 to the route-detail perk card is a play/topic-area gap, not member. | App/TicketWalletDetailView.swift |
| B-21 (P2) | An empty server `statusLabel` now shows no text, like MP `{{statusLabel \|\| ''}}`. The state glyph stays and carries the local state name as its VoiceOver label. The row font is `.cyText(.bodyCompact)` instead of `.font(.subheadline)`. | App/TicketWalletDetailView.swift |

r7-rev-a covers play runtime only. In r7-rev-c, the F-C* rows on parked `App/MPGap/Member` views belong to Gemini. Nothing else is Claude-owned on these pages.

### Owner decisions

- **#9 two-decimal money:** the 我的订单 card amount, the 订单详情 hero amount and `ProfileOrderAmountLabel` now go through `ProfileOrderYuan.text` = `"¥" + MoneyDisplay.text(OwnedOrderMoneyText.string(amount))`, so ¥12.5 shows as ¥12.50. This is lexical, with no Double. The pinned `OwnedOrderMoneyText.string(amount)` call is kept. 提现记录 `amountText` was already two decimals (Core). 积分 and 邀请 numbers are points, not money.
- **#3, #6, #12 money TEST-only:** nothing on these pages adds a money write. 立即支付 is still behind `ReleaseMoneyWriteSwitch`.
- **#7 cast, #8 arrival lock, #10 game-kit pilot gate:** no surface on member pages 16–30.

### Still left (round 2)

| id | why |
|---|---|
| PLY-21-6, PLY-26-2 (P1) | Still blocked by the pinned tests named in round 1. Neither `test_ticket_wallet_team.py:16` nor `test_owned_template_pagination.py` / `TemplateOwnShelfFlowTests` was retired on r7. |
| PLY-21-4 (rest), FIN-16-7 (rest), R7-MEM-17-2 (rest) | Same Core requests as round 1: no game flag, no `ProfileOrder` cover, no settle fields. `cursor/core-member` added `TicketWalletTicket.coverURL` only. |
| Cursor's App wiring list (`cursor-core-member.md` "F-agent (App)") | Not touched, per brief item 6: those call sites are being wired by Cursor. They are `ProfileOrdersView` → `orderHistory` paging (FIN-16-2), `TicketWalletView` → `ticket.coverURL` and the `focusId` `ticketDetail` fallback (R7-MEM-21-3, PLY-21-2), `TemplateAuthoringMineView` → `operationScope = "MERCHANT"` (PLY-26-5), and `MPReviewedPageScreen` invoice `?id=`. **If the coordinator wants member-b to do them instead, say so and they are small.** The wallet-card illustration above is the no-cover fallback, so `coverURL` can be layered on top without moving it. |

### Round 2 verification (cloud, contract layer only)
- I ran every ContractChecks module that names a round-2 file (34 modules) on this branch and on the pre-round-2 merge (b7f978cc5, which is r7 + round 1). Both runs: 15 failures and 5 errors, with the same test ids. **0 new.** The pre-existing ones are r7-wide (for example `test_ticket_wallet_read_lifetime` and the SHA projections).
- A first run caught one regression, now fixed: the B-16 comment quoted the `api/…` path, which the forbidden-literal guards in `test_ticket_wallet_play_entry` and `test_ticket_wallet_read_lifetime` reject. The comment no longer quotes it.
- `tools/check_typography_lint.py` passes.
- Not run here: Xcode build, `swift test`, AppUnit, screenshots. All APIs used were grepped on r7: `MPAsset.*` accessors, `MoneyDisplay.text`, `cyText(.bodyCompact)`, `CYColor.bgSurfaceStrong`, `CYSpacing.md`. The coordinator should compile.
- `origin/ui/combined-r7` was re-fetched before the final push and is still 82388e4a5, already merged.

## Round 3 (2026-11-24 evening)

- **Brief:** `design/handoff-r2:docs/briefs/fix-r3-round3.md`.
- **Sync:** merged `origin/ui/combined-r7` @ b0ac0108d. This branch was already an ancestor, so the merge was a fast-forward.

### Round 3 · re-applied

I checked each round-1 and round-2 commit hunk against the new base (`git diff <c>^ <c>` compared with `git diff 9d39dc1dc HEAD`). Only one file on the "restored to Cursor's side" list carried member-b work: `TicketWalletView`. `SettingsView` held only a restyle hunk, which isn't mine.

| hunk | state on b0ac0108d | action |
|---|---|---|
| c9a2e1ddb `TicketWalletView`: `MPAsset.BannerCover.coverRoute` no-cover illustration (MP `wc__im--illus`) | **dropped.** Cursor's `coverIllustration` brought back the SF `ticket.fill` watermark. | Re-applied **inside Cursor's `coverIllustration`**, so it still shows only when `httpsCover` is nil. Cursor's `coverURL` / `AsyncImage` path is unchanged. |
| c9a2e1ddb `TicketWalletView`: `MPAsset.FeatureIcon.iconGo` tinted badge (MP `wc__go`) | **dropped** | Re-applied as the same top-trailing overlay, placed after the cover `ZStack` and before Cursor's `TicketTopHeightKey` background. `tint` is split back out of `art`. |
| 189a2b989 PLY-21-15 token tints, no QR glyph | present | none |
| c9a2e1ddb / 9d39dc1dc: OrderCardComponents, OrderLifecycleView, PlayerJourneyViews (MP glyphs), ProfileOrdersView (MP icons, `ProfileOrderYuan`), TicketPassSheet, TicketWalletDetailView (B-16/B-21) | present. Cursor only added code on top (FIN-16-2 `orderHistory` paging, the `ParticipationCoverPlaceholder` restyle, `.cySheet` on login). | none |

### Flow gaps (`docs/mp-gap/flows-g1.md` §3 member, edges marked `[GAP-CLAUDE]`, pages 16–30)

`App/MPGap/**` is now compiled (`tools/generate_project.py`), so Gemini's parked views are mounted. They're wired to the r7 services, not to `Core/MPGap` services, which use wrong paths (r7-rev-c F-C04).

| id / edge | what changed | files |
|---|---|---|
| PLY-23-6 (P1) · mycanyuinfo cover | `ParticipationDetailGapSections(coverURL:)` above the header. It uses `record.cover`, which is MP `picUrl` = `imgUrl \|\| imgArr`, and only https (`QuestifyCardArtwork.safeURL`). Nothing shows when the cover is absent. | App/PlayerJourneyViews.swift |
| PLY-23-3 (P1) · mycanyuinfo → `free-explore?registrationId=` | 自由探索权益 sits under the info card when `record.isFreeExplore` matches MP `_bundleEntry` (ownerType 1, cmsTopic, purchaseKind 3 or productType 2). It's gated like MP `features.freeExploreBundle`: the session's `freeExploreBundleReadProvider` must be non-nil (new environment flag `participationBundleEntryEnabled`, default **off**). New route `.freeExploreBundle(registrationID:)` pushes `SessionOwnedOrderDetailView`, which carries the bundle provider. The flag is passed into the 我的参与 sheet explicitly. | App/PlayerJourneyViews.swift |
| PLY-21-13 (P2) · signup pass pager | `TicketPassSheet` with more than one openable ticket pages them with `StackedPassHorizontalPager`. The page in view becomes the current ticket, and 开始游戏 follows it. A `n/N` line (`ticketPass.pager.position`) sits below. The overflow 切换票券 picker stays as the non-gesture/VoiceOver path. | App/TicketPassSheet.swift |
| PLY-25-3 (P1) · orient-score leaderboard | New 本场榜单 card: 看本场榜单 / 榜单加载中 / 榜单没加载出来，再点一次试试. It reads `OrientSessionService.leaderboard` (c6 `…/session/{id}/leaderboard`) with the live session token (`OrientScoreBoardRead`, same construction as `CloudB3SessionBridge.orientLoader`). The result opens `OrientScoreLeaderboardSheetView`. ROUTE mode shows 已到结局/未到结局 and SCORE mode the two-decimal `OrientScoreFormat.centi`. Elapsed is `N 毫秒` or 用时待确认, as in MP `orient-score-view.js` `leaderboard`. The read is read-only. | App/OrientScoreView.swift |
| PLY-25-5 (P1) · per-row appeal / 漏记任务 / dispute | The inline segmented form is replaced by MP's entries: 申诉这一条 (a menu of ledger rows, without rows whose appeal is pending), 申诉漏记任务, and 成绩争议. 成绩争议 shows only once the round has ended (status 1/2, which the writer also enforces). Each entry opens `OrientScoreAppealSheetView`, which has the 节点编号 field and the n/500 limit. On 提交 the sheet closes, and the existing `OrientScoreReviewModel` confirm sheet plus offline opt-in take over unchanged. The 漏记任务 node id now reaches the writer: `OrientScoreReviewContext.nodeID` (default `{ nil }`) feeds `writer.submit(…, nodeID:)`, which was already allowed by `ReviewedOrientScoreReviewLease`. | App/OrientScoreReviewSection.swift, App/OrientScoreReviewProduction.swift |
| PLY-29-4 (P1) · report-detail appeal | `ReportAppealSection` now runs the appeal in `ReportAppealSheetView` (form → confirm → busy → ok / fail / unknown). It still sends through `CommunityTrustPlayerService.appeal` (`community-trust/reports/appeal`), with the same request-id reuse rule. In the unknown phase 重试 resends the same id. Swipe-to-dismiss is disabled while busy. | App/CommunityTrustPlayerViews.swift |

Fixtures were added to `MemberAreaPopupFixtures` (DEBUG): `member-popup-orient-board`, `-orient-appeal-row`, `-orient-appeal-missing`, `-orient-dispute`, `-report-appeal-form`, `-report-appeal-confirm`, `-report-appeal-unknown`. They are listed in `docs/port/accept/f-member-b.txt`.

Strings: `ticketPass.pager.position`, `orientScore.board.{open,loading,failed,reached,notReached,elapsedMs,elapsedUnknown}` and `orientScore.review.{appealEntry,appealMissing}` are in `docs/port/strings/fix-r3-member-b.json`, with en and zh-Hans.

### MP assets (round 3)
- The new mapping rows are the template-detail shelf tabs (`DiscoveryTemplate*`), the leaderboard memojis (`GrowthLeaderboardView`, the growth center) and the journey laurel (`PlayExperienceView`). **None of them is on member pages 16–30**, so there's nothing to apply here.
- Every member-b row in `mapping.md` (`dOrderIcon`/`2`, `iconTicketEmpty`, `iconGo`, `iconPlay`, `coverRoute`, `dCyIcon`/`2`, `dCyinfo1`/`2`/`4`) is applied on this branch. The shared `CYEmptyState` and `CYAvatarView` rows are still with the DS owner (round 2).

### Review / audit rows
- r7-rev-a, -b and -c have not changed since round 2. The F-C* rows in rev-c sit on Gemini's views and services. The views mounted above are the r7-rev-c-fixed versions: the F-C01 `Section` initializers are already `header:` / `footer:`. The mounts don't use any `Core/MPGap` service (F-C04/F-C06).
- **Left for Gemini, on the mounted views:**
  - hard-coded Chinese `"本人"` / `"参赛玩家"` in `OrientScoreLeaderboardSheetView.rowView`;
  - `OrientReviewSheetKind.title` and `ReportAppealSheetView.sheetTitle` return raw Chinese strings;
  - `.buttonStyle(.borderedProminent)` instead of `.cyPrimary`.

  The flows work; the copy is zh-only until those are keyed.

### Still left (round 3)

| id | why |
|---|---|
| FIN-17-4 (P1) · `OrderDetailTeamSeatsClubSections` | **Core request (Cursor).** `ProfileOrder` decodes no team, seat, club or merchant-consent fields, so `OrderDetailExtraActionsModel` cannot be filled from the order read. Mounting it empty would show nothing. |
| FIN-17-8 (P2) | Same: no 亲子票 party text or 票夹已过期 flag on `ProfileOrder`. |
| PLY-23-4 (P1) | There is still no native merchant-apply editor in edit mode (MP `merchantapply?mode=1`). It stays a known gap, as the audit allows. |
| PLY-26-2, PLY-26-4, PLY-26-5 · page 26 我的节点玩法 | **MP deleted the page.** `subpackageMember/mytemplate/mytemplate` was removed from `app.json` in xcx 910de033 ("删孤儿页", owner defaults 1122). There is no MP source left to match. The app page stays as is; whether to retire it is the coordinator's or owner's call. The pinned tests (`test_owned_template_pagination.py`, `TemplateOwnShelfFlowTests`) would also have to go. |
| PLY-21-6 (P1) | Still blocked by `test_ticket_wallet_team.py:16`, which was not retired on r7. |
| PLY-21-4 (rest), FIN-16-7 (rest), R7-MEM-17-2 (rest) | The same Core requests as before: the game flag, the `ProfileOrder` cover and the settle fields. |
| MP free-explore deep link (member-a's page 7) | `MPReviewedPageScreen.freeExplore` `?registrationId=` mounts a bare `ProfileOrderDetailView`, without `SessionOwnedOrderDetailView`'s bundle environment, so its 自由探索权益 entry can't read. It isn't changed here because page 7 is half a. The fix is a one-line swap to `SessionOwnedOrderDetailView(session:id:)`. |

### Round 3 verification (cloud, contract layer only)
- **`tools/contract_ratchet.py --check`:** 218 failing against a baseline of 184, so 34 new. I ran all 34 on an untouched `b0ac0108d` worktree, and 33 of them fail there too: they are r7-wide (search map, settings, merchant, club and so on).
  - The one this branch adds is `test_localization_key_catalog_contract…test_no_looked_up_key_is_missing_from_every_catalog`. It flags the round-3 keys that so far exist only in `docs/port/strings/fix-r3-member-b.json`.
  - It goes green once the coordinator runs `tools/merge_localization_fragments.py`, the same as earlier rounds.
- **The 21 ContractChecks modules that name an edited file:** 18 pass. The other 3 (`test_category_roam_registration`, `test_merchant_project_workspace_entry` and `test_design_system_component_contracts`) fail identically on the base.
- `tools/check_player_journey_screens.py` and `tools/check_typography_lint.py` pass.
- **Not run here:** the Xcode build, `swift test`, AppUnit and screenshots, because there is no compiler in the cloud.
  - Every API was grepped on r7: `OrientSessionService.leaderboard`, `OrientScoreFormat.centi`, `squareGovernanceAccess().token`, `AuthRequestBuilder.isValidToken`, `writer.submit(…nodeID:)`, `CommunityTrustPlayerService.appeal`, `SessionOwnedOrderDetailView(session:id:)`, `QuestifyCardArtwork.safeURL`, and the MPGap view initializers.
  - The coordinator should compile.
- `origin/ui/combined-r7` was re-fetched before the final push. It is still b0ac0108d, which is already merged.
