# Parity audit r11 · member (`subpackageMember/`, player side)

Brief: `design/handoff-r2:docs/briefs/audit-r11.md`. Previous report: `design/handoff-r2:docs/audit/parity-r10/member.md`.

Reviewer run on 2026-11-26. This was a code read only. No product code was edited, nothing was compiled, and no screenshots were taken.

- **App:** `origin/ui/combined-r7` @ `b9a9d4d29`, which includes all 11 r10 lanes. That is 588 commits after the r10 base `82bcf2c2d`.
- **MP:** `origin/mp-source:chengyinhub-xcx/` (snapshot 2026-11-24, commit `07c636418`). The r10 MP line refs still hold.
- **Method:** the same 30 pages, 484 rows and formula as r7 to r10. Only ✅ counts.
  - Every r10 §3 and §4 row was re-checked in code on the tip. The receipt `fix-r10-member.md` claims every row is closed; each claim was grepped and not taken on trust.
  - Every MP page's `bindtap` / `bind:` handlers were then listed again and matched to the app to find rows that r10 missed.
- **Scope (owner 11-26):**
  - Money is ON in Release: payment, refund, host-cancel refund, payout and withdrawal. This closes r10's MONEY-GOV-1.
  - Virtual goods stay off. Platform passes and membership are digital content, so their buy, pay, cancel and refund rows are marked **VG-off**. They still count as missing under the unchanged formula, but they are not queued.
  - No merchant-only rows exist in this area.
- **Native column:** same scale as r10 (native = 1, partly = ½, custom = 0). It uses a marker sweep over each page's view files: ScrollView card pages, `CYNight`, gradients, `.shadow`, Capsule / RoundedRectangle chrome, CYCard / CYInfoCard / CYListRow / CYFooterBar / CYTabs / CYSheetHeader and `preferredColorScheme`.
  - The shared components were re-read, and they are now Apple-backed:
    - `CYEmptyState` is backed by `ContentUnavailableView` (`App/DesignSystem/CYStates.swift:54`).
    - `CYStatusChip` draws footnote text or a `Label`, with no capsule (`App/DesignSystem/CYStatusChip.swift:42-58`).
    - `CYPillButton` maps to `.borderedProminent` / `.bordered` / `.borderless` (`App/DesignSystem/CYPillButton.swift:108-115`).
    - `CYSkeleton` uses `.redacted(reason: .placeholder)` (`App/DesignSystem/CYSkeleton.swift:59`).
  - None of these four is counted as a violation any more.

## 1. Scores

| | r10 | r11 | Δ |
|---|---|---|---|
| Functions present | 451 / 484 | **466 / 484** | **+15** |
| Parity | 93 % | **96 %** (96.3) | **+3 pts** |
| Excluding page 26 (MP-retired; now a redirect) | 431/462 (93 %) | 446/462 (96.5 %) | +15 |
| Of the 18 missing: VG-off (not queued) | n/a | 10 | |
| Of the 18 missing: queued below | n/a | 3 (page 17) | |
| Of the 18 missing: carried, un-itemised in r10 (pages 19, 25, 26) | n/a | 5 | |
| **Native** (pages 1-25, 27-30; page 26 retired) | 9.5/30 (32 %) | **28 / 29 (97 %)** | **+65 pts** |
| Fully native pages | 0 / 30 | **27 / 29** | +27 |

### Per page

| # | MP page | r10 | r11 | Δ | native r11 | note / residual non-Apple elements |
|---|---|---|---|---|---|---|
| 1 | market/passes | 16/16 | 16/16 | 0 | native | `List`. 0 `CYNight` / gradient / `.shadow` in `App/PassMarketViews.swift`. `CYOfflineStrip` is a `Label` row (:229). |
| 2 | market/pass | 13/15 | 13/15 | 0 | native | 2 missing = `onBuy` / `goCheckout`: **VG-off** (`App/MPParityPassSession.swift:10,651`). |
| 3 | market/gift | 7/8 | **8/8** | +1 | partly | MKT-3-1b fixed. Residual: `.background(CYNight.ink0)` `App/MPParityPassSession.swift:477` (NAT-R11-1). |
| 4 | market/membership | 12/16 | 12/16 | 0 | native | 4 missing = `onPlan` / `onAgree` / `onBuy` / `goOrder` buy flow: **VG-off**. |
| 5 | market/pass-order | 7/11 | 7/11 | 0 | native | 4 missing = resume-pay, cancel, refund apply and refund submit (`market/pass-order/index.wxml:36-41`): **VG-off**. `PassOrderRefusedWrites` holds them. See DEC-1. |
| 6 | market/library | 9/9 | 9/9 | 0 | native | |
| 7 | free-explore | 10/16 | **16/16** | +6 | native | MKT-7-3b, R7-MEM-7-1 and R8-MEM-7-3 fixed. The page is a `List` (NAT-9). |
| 8 | coupon-wallet | 12/12 | 12/12 | 0 | native | MKT-8-2 fixed with STR-1. |
| 9 | coupon-qr | 13/14 | **14/14** | +1 | native | MKT-9-2 fixed. `List` (`App/CouponCodeView.swift:26`). |
| 10 | coupon/coupon | 11/12 | **12/12** | +1 | native | MKT-10-3 fixed. |
| 11 | invoice | 17/17 | 17/17 | 0 | native | segmented `Picker` (`App/InvoiceLaunchHistoryView.swift:34`) |
| 12 | invoice-detail | 15/15 | 15/15 | 0 | native | |
| 13 | invoice-apply | 20/20 | 20/20 | 0 | native | no `CYSheetContainer` / `CYFooterBar` left |
| 14 | invoice-titles | 12/12 | 12/12 | 0 | native | |
| 15 | invoice-title-edit | 14/14 | 14/14 | 0 | native | |
| 16 | order/order | 16/18 | **18/18** | +2 | native | R7-MEM-16-1 fixed, including 立即支付 / 取消并退款 under money ON. NIT-R11-1 (swipe-only). |
| 17 | orderinfo | 20/25 | **22/25** | +2 | native | FIN-17-4b and R9-MEM-17-2 fixed. 3 open: R11-MEM-17-1/2/3 (completion block never mounted, 下次再来, 查看记录). |
| 18 | points-history | 14/14 | 14/14 | 0 | native | |
| 19 | tixianjilu | 11/12 | 11/12 | 0 | native | The r10 gap was not itemised. The re-scan found 加载更多, the error, login and denied states and the status text all present. **Carried** for r12 to re-baseline. |
| 20 | myinvite | 15/15 | 15/15 | 0 | native | |
| 21 | signup 票夹 | 27/27 | 27/27 | 0 | native | `List` rows (NAT-12). The pass sheet is a system-grouped card in a `ScrollView`, with no forced dark or tear shape (`App/TicketPassSheet.swift:255-263`). |
| 22 | mycanyu | 16/16 | 16/16 | 0 | native | |
| 23 | mycanyuinfo | 20/21 | **21/21** | +1 | native | PLY-23-6 fixed (two slots). |
| 24 | character | 16/17 | **17/17** | +1 | native | R7-MEM-24-2 fixed. `List` (NAT-11). |
| 25 | orient-score | 22/24 | 22/24 | 0 | partly | All 17 MP handlers have app code. The 2 r10 gaps were not itemised, so they are **carried**. Residual: custom `CYSheetHeader` `App/MPGap/Member/OrientScoreGapViews.swift:22,88` (NAT-R11-2). |
| 26 | mytemplate (MP-retired) | 20/22 | 20/22 | 0 | n/a | R8-MEM-26-1b fixed. Only the redirect remains (`Core/MiniProgramPageLink.swift:289-294`). Drop this page from the denominator in r12. |
| 27 | complaint | 19/19 | 19/19 | 0 | native | |
| 28 | report-mine | 15/15 | 15/15 | 0 | native | |
| 29 | report-detail | 17/17 | 17/17 | 0 | native | |
| 30 | appeal-mine | 15/15 | 15/15 | 0 | native | segmented `Picker` (`App/MemberScoreAppealListView.swift:67`) |
| | **Total** | **451 (93 %)** | **466 (96 %)** | **+15** | **28/29** | |

## 2. Open counts

| | r10 open | fixed in r11 | partly | still open | new in r11 | **r11 open** |
|---|---|---|---|---|---|---|
| P0 | 1 | 1 (MKT-3-1b) | 0 | 0 | 0 | **0** |
| P1 | 9 | 9 | 0 | 0 | 1 (R11-MEM-17-1) | **1** |
| P2 | 25 | 25 | 0 | 0 | 4 (R11-MEM-17-2, R11-MEM-17-3, NAT-R11-1, NAT-R11-2) | **4** |
| nit | 1 | 1 | 0 | 0 | 1 (NIT-R11-1) | **1** |

There is also one owner decision (DEC-1). It is not counted.

**Gates run on the tip:** `python3 tools/merge_localization_fragments.py --check-member` reports `{"status": "MATCH", "checked": 6}`, so STR-1a and STR-1b are closed.

## 3. r10 rows: status in code on `b9a9d4d29`

| id | r11 status | SHA | evidence (app file:line) |
|---|---|---|---|
| MKT-3-1b | **fixed** | 9251fd891 | `Core/ChinaReviewedRouteCapability.swift:113,121-123` adds `memberGiftClaimOwnerGrant`, read inside `admitsChinaProductionCall` (:61). `Core/PlayerJourneyProductionLease.swift:28` `refused = [.issueReferral]`. The claim goes through `refuseUnwiredChinaProduction` (`Core/PlatformPassGiftClaimSource.swift:57`), which now admits it. |
| R9-MEM-STR-1a | **fixed** | (r9 round 3, cf1e31ccb) | `--check-member` MATCH |
| R9-MEM-STR-1b | **fixed** | same | same |
| MKT-8-2 | **fixed** | same | closed with STR-1a |
| R8-MEM-26-1b | **fixed** | 95ac49a6c | `Core/MiniProgramPageLink.swift:289-294` keeps the redirect to `pages/activity/official-mine/index` only. No `mytemplate` / `TemplateAuthoringMine` remains in `App/MPReviewedPageScreen.swift`. |
| MKT-7-3b | **fixed** | eb5e7a73e, fa230d1b6 | `App/FreeExploreBundleLaunchView.swift:268` (`startAtText` :397), 取消预约 :276, 商家评价 :292-295, 更换商家 per :6 |
| FIN-17-4b | **fixed** | 5043b2ced | `App/ProfileOrderSourceDetailSections.swift:144` `followClubOwner` → `/api/user/follow/action` (admitted `Core/ChinaReviewedRouteCapability.swift:1798`) |
| MKT-9-2 | **fixed** | ec9c8a528 | `App/CouponCodeView.swift:64-76,97-102`: issued on appear, with no confirm sheet |
| R8-MEM-21-1 | **fixed** | 8b7cf1bb8 | `App/TicketWalletView.swift:99-106`; `App/TicketWalletCompanionCard.swift:21-40`: 同伴席位 row, no entry code, 开始游戏 → `SessionPlayRuntimeView(.journey(scope))` |
| NAT-1 | **fixed** | 87ee71b9d | `App/DesignSystem/CYStates.swift:51-54` `ContentUnavailableView` |
| NAT-2 | **fixed** | (base) | 0 `preferredColorScheme` in `App/TicketPass*.swift` |
| NAT-3 | **fixed** | (base) | 0 `CYNight` / gradient / `.shadow` in `App/PassMarketViews.swift` and `App/PassMembershipViews.swift` |
| PLY-23-6 | **fixed** | 6a51c25aa | `App/PlayerJourneyViews.swift:499-501` cover; :560-566 template banner |
| R7-MEM-7-1 | **fixed** | a5e9d9842 | `App/FreeExploreTopicCatalogScreen.swift:113-115` 可用 / 暂不可用 per store |
| R8-MEM-7-3 | **fixed** | e4beeb88a | `App/FreeExploreReceiptResolveScreen.swift:58-62,112-113` server `msg` first. `App/FreeExploreBundleLaunchModel.swift:111` is only the untyped-error fallback. |
| MKT-10-3 | **fixed** | 597ef5d4e | `App/CouponManagementView.swift:83-86` button → `detailItem` sheet |
| R7-MEM-16-1 | **fixed** | c225362bd, 29d4bf6ee | `App/ProfileOrdersView.swift:44-60` (buttons), :133-134 (mounted), :868-882 (`cardExitKey`, `cardPayNowShown`). See NIT-R11-1. |
| R7-MEM-24-2 | **fixed** | 7e1a04954 | `App/CharacterSheetDetailView.swift:36`: no 此刻环境 / 掷骰 |
| R9-MEM-17-2 | **fixed** | 9458684d8 | `App/ProfileOrderSourceDetailSections.swift:48,203` `ProfileOrderSettlementCopy`; `App/ProfileOrdersView.swift:532`. The only `Text(verbatim:)` literal left is `"—"` (:836). |
| R9-MEM-5-1 | **fixed** (TEST path) | 100a5a2a7 | `App/PassMarketViews.swift:1203-1206`: the notice shows on refusal only |
| R9-MEM-3-1 | **fixed** | 5a93bbe0c | `App/PassRedeemCodeView.swift` deleted; `App/MPParityKit.swift:113,295` routes to `PlatformCodeRedeemPage` |
| NAT-4 | **fixed** | (base) | `App/DesignSystem/CYStatusChip.swift:42-58` |
| NAT-5 | **fixed** | (base) | `App/DesignSystem/CYPillButton.swift:108-115` |
| NAT-6 | **fixed** | 8c9408404 | 0 `CYFooterBar` in `App/InvoiceLaunch*.swift` and `App/CouponManagementView.swift` |
| NAT-7 | **fixed** | (base) | `App/DesignSystem/CYSkeleton.swift:59` |
| NAT-8 | **fixed** | (base) | `App/InvoiceLaunchHistoryView.swift:34`; `App/MemberScoreAppealListView.swift:67` |
| NAT-9 | **fixed** | 1b868d8e6 | `App/FreeExploreBundleLaunchView.swift:57` `List` |
| NAT-10 | **fixed** | f7f5d0670 | 0 ScrollView / CYCard in `App/OrientScore*.swift` (residual header: NAT-R11-2) |
| NAT-11 | **fixed** | ce2c6feb5 | `App/CharacterSheetDetailView.swift:21` `List` |
| NAT-12 | **fixed** | 8c9408404 | `App/TicketWalletView.swift:70-97,113` `.insetGrouped` rows, no carousel or gradient |
| NAT-13 | **fixed** | 8c9408404 | `App/TicketPassSheet.swift:255-263`: Divider and system-grouped background; no tear, flip or shape |
| NAT-14 | **fixed** | (base) | `App/PassMarketViews.swift`: 0 `cyDomainCard` / `CYMorphButton` / Capsule |
| NAT-15 | **fixed** | (base) | `App/PassMembershipViews.swift`: 0 markers |
| NAT-16 | **fixed** | ec9c8a528 | `App/CouponCodeView.swift:26` `List`, 0 `CYRadius` |
| NAT-17 | **fixed** | 8c9408404 | 0 markers in `InvoiceLaunchApplyView`, `MemberReportProgressDetailView` and `SocialInviteHistoryView`. Two `.cyPrimary` / `.cySecondary` remain at `App/PlayerJourneyViews.swift:603,610`; they go through `CYSystemButtonHost`, so they are not counted. |
| R9-MEM-NIT-1 | **fixed** | bd9469fe3 | `App/TicketWalletView.swift:68-69`: no filter |
| MONEY-GOV-1 | **closed** | n/a | `audit-r11.md` scope: the owner set money ON in Release on 11-26 |

The r10 §6 "closed" rows (PLY-25-2, STR-2, FIN-19-1, PLY-21-5, PLY-23-4, R8-MEM-21-2, FIN-20-6, NIT-2) were re-grepped and are still present. Examples: `App/OrientScoreSettlementControls.swift:6`, `App/WithdrawalHistoryView.swift:40-53`, `App/SocialInviteHistoryView.swift:15`, `App/PlayerJourneyViews.swift:34`.

## 4. Fix queue (input for fix round r11)

Owner: Claude App unless noted. Nothing is P0.

| id | sev | MP file:line | app file:line | what to change | size |
|---|---|---|---|---|---|
| R11-MEM-17-1 | **P1** | `subpackageMember/components/cy/scene-member-order-detail/index.wxml:289-311` (探店图鉴 stamps and 通关奖励 awards); `index.js:363-386,833-835` (completion read) | `App/ExploreCompletionView.swift:3-13,42-60`; `App/ProfileOrdersView.swift:559`; `App/OwnedOrderComposition.swift:11,58`; pattern: `App/AppSession.swift:6713-6737` (`freeExploreBundleReadProvider`) | **Gap:** `ExploreCompletionEntry` reads `@Environment(\.exploreCompletionProvider)`, but nothing in App/ or Core/ ever sets it (`grep -rn "exploreCompletionProvider" App` finds only the key and the reader). The stamps and awards block therefore never shows. The Core reader `ExploreCompletionSessionReader` (`Core/ExploreCompletionRead.swift:80`, path `api/registration/explore-completion`) exists, and the route is admitted (`Core/ChinaReviewedRouteCapability.swift:1634`). **Fix:** add `var exploreCompletionProvider: ExploreCompletionProvider?` on `AppSession`, modelled on `freeExploreBundleReadProvider`. Build `ExploreCompletionSessionReader` for `currentRuntimeDependencyContext`, then call `ExploreCompletionProvider(origin: ownedOrderReader, originSession: currentOwnedOrderSession, currentOrigin: { self.currentOwnedOrderSession }, reader:)`. Install it with `.environment(\.exploreCompletionProvider, session.exploreCompletionProvider)` next to the two `freeExploreBundleReadProvider` lines in `App/OwnedOrderComposition.swift`. | M |
| R11-MEM-17-2 | P2 | `scene-member-order-detail/index.wxml:358-360` (`primaryCta === 'record'` → 查看记录); `index.js:559-569` (`startPlay`: `/pages/play/index?…&registrationId=<id>&entry=ticket`) | `App/ProfileOrdersView.swift:540-560` (order detail sections) | **Gap:** the order detail has no 查看记录 for a played or completed order. **Fix:** add a `Section` with a `NavigationLink` to `SessionPlayRuntimeView(session:destination: .journey(scope))`, as `App/TicketWalletCompanionCard.swift:31-37` does, built from the order's topic or activity id. Show it only when the MP's `primaryCta == 'record'` holds (paid or free, registered, and not awaiting payment). Label: key `playerJourney.viewRecord` = 查看记录. | S |
| R11-MEM-17-3 | P2 | `scene-member-order-detail/index.wxml:314-327` (下次再来: 关注 / 加入俱乐部 / next edition); `index.js:880-940` (`joinClub` → `POST /api/club/join`; `goNextEdition` → `/pages/topic/index/index?id=nextTopicId`) | `App/ExploreCompletionView.swift:155-195` (after the awards section); data `Core/ExploreCompletionContracts.swift:105-121` (`Revisit`: clubID, clubLeaderMemberID, followed, joined, nextEdition) | **Gap:** the `revisit` payload is decoded but never shown. **Fix:** after R11-MEM-17-1, add a 下次再来 `Section` to `ExploreCompletionView` with the club name and these items: 关注主办俱乐部 (reuse `followClubOwner`, as `App/ProfileOrderSourceDetailSections.swift:144` does); 加入俱乐部 (open the club page, which sends join through `ClubActionCoordinator`, as at :64-65); the join state text (已加入俱乐部 / 申请已提交，等待主理人审核); and the next edition as a `NavigationLink` to the topic page, shown only when `nextEdition.topicId` is present. | M |
| NAT-R11-1 | P2 · native | `market/gift` (no dark page) | `App/MPParityPassSession.swift:476-477` | Remove `.background(CYNight.ink0.ignoresSafeArea())` from the order-missing fallback. `CYEmptyState` is already a `ContentUnavailableView`. | S |
| NAT-R11-2 | P2 · native | `orient-score/index.wxml` (cy-sheet forms) | `App/MPGap/Member/OrientScoreGapViews.swift:22,88,132` | Replace the two custom `CYSheetHeader`s (`App/DesignSystem/CYPlayerKit.swift:333`, which draws its own ✕ and 完成 pill) with `NavigationStack { … }.navigationTitle(...)` plus `ToolbarItem(placement: .cancellationAction) { Button("action.close", action: onClose) }`. Change `.buttonStyle(.cyPrimary)` :132 to `.borderedProminent`. | S |
| NIT-R11-1 | nit | `scene-member-order-history/index.wxml:84-90` (visible buttons on the card) | `App/ProfileOrdersView.swift:133-134` | 立即支付 / 取消订单 / 取消报名 / 取消并退款 are reachable only by swipe or long-press. Add one visible trailing inline control, such as a `Menu` with an `ellipsis.circle` label that holds `cardExitButton(order)`, so the action can be discovered as it can in the MP. | S |

### DEC-1 (owner decision, not queued)

`market/pass-order` cancel, refund-apply and resume (`index.wxml:36-41`) stay TEST-only in Release (`App/PassMarketViews.swift:1206`). The fix-r10 lane classed platform passes as virtual goods. Two of these actions, cancel of an unpaid order and refund of an order paid in the MP, do not sell anything in the app.

The owner should say whether "virtual goods off" also blocks **refund and cancel** of a pass order that was bought in the MP. If it does not, re-open these as P1. That reverses part of the VG-off count for page 5 (+3).

## 5. Regressions

None found. Every row closed in r10 and r11 was re-grepped on `b9a9d4d29` and is still present. No r10 ✅ row was found missing.

## 6. Notes for r12

- Pages 19 (1 row) and 25 (2 rows) carry gaps that r10 never itemised. The handler re-scan in r11 found app code for every MP handler on both pages. r12 should either name these rows or credit them.
- Page 26 is now a redirect only. r12 should remove it from the denominator (the new total would be 462).
