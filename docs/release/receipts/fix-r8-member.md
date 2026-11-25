# Receipt: fix-r8 member (Claude App)

Branch `fix/r8-member`, from `origin/ui/combined-r7` (merged again before each push). Queue: `origin/audit/parity-r8-member:docs/audit/parity-r8/member.md`. MP: `hengyin/chengyinhub-xcx/subpackageMember/`.
Nothing was compiled here (no compiler in the cloud). Every API used was grepped on the base first. The strings fragment is `docs/port/strings/fix-r8-member.json`, and the same keys were written into `Resources/Localizable.xcstrings` (en + zh-Hans).

## Closed (Claude App rows)

| id | what changed | files |
|---|---|---|
| MKT-7-1 (P1) | `free-explore?requestId=` FOUND now mounts `SessionOwnedOrderDetailView`, which carries `freeExploreBundleReadProvider`, so 自由探索权益 shows. | App/FreeExploreReceiptResolveScreen.swift |
| R8-MEM-7-1 (P1) | `free-explore?registrationId=` mounts the same session-owned detail. | App/MPReviewedPageScreen.swift |
| MKT-7-3 (P1, app part) | Every unit now shows with its MP status (`{chapter} · 可用/已预约/…`, fallback `权益 N`). The order card has 支付：… · 报名：… from `paymentStatus` / `registrationStatus`. Reservation rows show the keyed MP status, not the raw enum. | App/FreeExploreBundleLaunchView.swift |
| R8-MEM-7-2 (P2) | Catalog rows use `freeBundle.catalog.unitsPerHolder %lld` / `unitsUnknown`, and `章节` as the chapter fallback. No raw Chinese remains. | App/FreeExploreTopicCatalogScreen.swift |
| R7-MEM-16-3 (P2) | zh `profile.orderParity.forbidden.title` = 当前身份不能查看订单 (en "Your current role can’t view orders") and `.error.title` = 订单加载失败 are now in the catalog. All member fragment keys now match the catalog. | Resources/Localizable.xcstrings |
| R7-MEM-21-2 (P1) | The carousel `openable` filter excludes `isWalletLocked`, and `TicketWalletPlayEntry.entry` returns nil for locked tickets. | App/TicketWalletView.swift, App/TicketWalletDetailView.swift |
| R8-MEM-21-2 (P2) | The `focusId` fallback also needs `registrationStatus == 2` and `ownerType` 1/2; anything else is 未定位到原报名凭证. The `memberId` check needs Core (see below). | App/TicketWalletView.swift |
| R8-MEM-21-3 (P2) | The pass-sheet header uses `coverURL` (https-only, through a shared `TicketWalletTicket.walletHTTPSCoverURL`), with the `MPAsset.BannerCover.coverRoute` fallback. `E1CoverArt` is gone. | App/TicketPassSheet.swift, App/TicketWalletView.swift |
| PLY-21-5 (P1, app part) | The status chip is removed from the pass card in both layouts. The party line and 已核销 x/y 家 need Core fields (see below). | App/TicketPassSheet.swift |
| R8-MEM-5-1 (P2) | A refused 继续付款 / 取消订单 / 申请退款 now shows a warning notice (`mp.passOrder.refused`) instead of doing nothing. | App/PassMarketViews.swift |
| R8-MEM-5-2 (P2) | All pass-order write copy is keyed (`mp.passOrder.resume/cancel/refundApply[.reason/.placeholder/.submit]`) with `.cyText`. The MP OR-024 terms (续费 / 退款规则, MP defaults) sit above the reason. Buttons are 44 pt. | App/PassMarketViews.swift |
| R8-MEM-10-2 (P2) | The player-scope coupon list uses `.cyDomainScreen(.player)`; merchant stays merchant. | App/CouponManagementView.swift |
| FIN-20-4 (P2, rest) | A next-page failure now renders below the rows (where 加载更多 is). The full-page state stays at the top only when there are no rows. | App/SocialInviteHistoryView.swift |
| R7-MEM-23-1 (P2) | 我的角色卡 on 参与详情 is gated on a silent `GET /api/play/character?topicId=` probe through `AppSession.probeCharacterCard` (MP `_probeCharacter`: created or has attributes), passed in as an environment closure. Fixtures without the probe keep the old gate. | App/PlayerJourneyViews.swift |
| R7-MEM-24-1 (P2) | 角色卡 failures are split into the MP states: 登录, 无权查看, 暂时无法查看该主题 (404, no action), 链接已失效 (400, 返回), 登录状态已变更 (staleSession, 重新加载), 请更新 App (426/unsupported, no action), and generic error. | App/CharacterCardReadbackView.swift |
| PLY-26-5 (P1/owner) | The merchant scope uses merchant chrome; dark is forced only for the player scope. | App/TemplateAuthoringMineView.swift |
| PLY-26-4 (P1/owner, app part) | The card cover is `imgUrl` with a title-initial gradient fallback, plus the `N 次引用` overlay. ★ rating needs Core. | App/TemplateAuthoringMineView.swift |

## Not taken (with reason)
- **R8-MEM-17-1, R8-MEM-25-1, R8-MEM-29-1:** already done on the in-flight `fix/r3-member-b` round 4 (commits e836711d2, c89a52f62), not yet in combined-r7. Not duplicated, to avoid conflicts.
- **R8-MEM-1-1 / R8-MEM-3-1:** the app side is on the in-flight `fix/r3-member-a` round 4 (94a78e18a), and it waits for the Cursor contract.
- **PLY-23-4:** kept as a known gap, as the audit says (no native merchant-apply editor yet).
- **Owner-decision and Cursor-only rows** were left untouched.

## For Cursor (Core pieces my App work needs)
1. **MKT-7-3:** decode on `FreeExploreLaunchOrder.Bundle`:
   - unit `validTo`, `unitCode` and chapter `content` (for 有效期至 and the content line);
   - `refundHold { state, refundId }` (the refund-hold card);
   - `exitCases[] { decision }` (售后记录);
   - `fulfilledMerchants`, and the reservation `shopName` / `merchantId` / `canCancel` (for 取消预约 / 商家评价).

   Also the `balance.expired` flag (当前不在有效期内). The App will then render these in `FreeExploreBundleLaunchView`.
2. **PLY-21-5:** decode `party { adultCount, childCount }` and `exploreProgress { redeemed, required }` on `TicketWalletTicket`. The App adds ` · N 大 M 小同享` and ` · 已核销 x/y 家` to the pass sub-line.
3. **R8-MEM-21-2:** decode `memberId` on `TicketWalletTicket` so the focus fallback can require `memberId == owner`.
4. **PLY-26-4:** decode `rating` on `DiscoveryPlayTemplate` (the ★ overlay uses `MPAsset…iconStar`).
5. **R8-MEM-5-2:** an optional overview-terms read on the pass-order page, so the refund terms can show the server `terms.renewal` / `terms.refund` instead of the MP defaults.
6. **Strings merge tool (audit cross-cutting 3):** other fragments still carry zh values that the catalog skipped:
   - gap-g1-copy: 21
   - gap-g2-copy: 20
   - fix-r3-club-a: 10
   - fix-r3-account-publish-a: 5
   - fix-r3-club-b: 3
   - fix-r3-player-content-b: 2
   - fix-r3-merchant-coop-a: 1
   - fix-r3-play-roam-b: 1

   Member fragments are clean.

## Notes for the coordinator compile
- New types: `CharacterCardFailure` (enum, App/CharacterCardReadbackView.swift) and `TemplateMineCover` (private). New extensions: `TicketWalletTicket.walletHTTPSCoverURL`, `AppSession.probeCharacterCard(topicID:)`, and `EnvironmentValues.participationCharacterProbe`.
- Status keys are built at runtime with `String.LocalizationValue("freeBundle.status." + raw)` (a concatenated String, so no `%@` interpolation).
