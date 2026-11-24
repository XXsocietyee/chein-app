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
