# Receipt: fix-parity-member (r1)

Brief: `origin/design/handoff-r2:docs/briefs/fix-parity-r1.md`. Findings: `origin/audit/parity-member:docs/audit/parity/member.md`.
Branch `fix/parity-member`, from `origin/ui/combined-r4` (base `90a5c8200` merged in). Swift is not installed in the cloud: nothing here was compiled or run on a simulator.

## Gates
- `python3 -B tools/check_scaffold.py`: PASS (page route table regenerated for the new `market/pass-order` literal).
- `python3 -B tools/check_design_lint.py`: PASS. Typography ratchet lowered with `--update`: raw text style 1181 → 1169, large title 26 → 22 (others unchanged).
- `python3 -B tools/contract_ratchet.py --check`: the base already has 11 failures not in the baseline (184 baseline, 195 on base). This branch adds none: the two my changes caused (`FPM5Pasteboard`, AppSec deep-link token guard) and one a merged fork caused (square-detail copy pin) were fixed. Contract pins that encoded the old behaviour were updated where a finding changes that behaviour (each cites its finding id).
- Unit tests updated (not run): `MPParityDeepLinkRouteTests` (gift link without token, pass-order route), invoice withdraw readback, `OwnedOrderFlowTests` amount label, orient-score load, template market plan, `TicketWalletUsableTests` (new).

## P0 status (26)
| P0 | status |
|---|---|
| MKT-1-1, MKT-2-1, MKT-2-2, MKT-5-1, MKT-6-1, MKT-6-2 | fixed |
| MKT-3-1 | blocked (owner money gate, gift claim stays off) |
| MKT-7-1 | partial (requestId receipt has no reader; lands on 我的订单) |
| MKT-7-2 | blocked (client work; contract below) |
| FIN-12-1, FIN-13-1, FIN-13-2, FIN-16-1, FIN-17-1 | fixed (FIN-16-1/17-1 dispatch only when the deployment's `allowsReviewedCancellationAndRefund` is on; otherwise 如需取消或退款，请联系客服) |
| PLY-21-1, PLY-21-2, PLY-21-3, PLY-22-1, PLY-23-1, PLY-23-2, PLY-24-1, PLY-25-1, PLY-26-1, PLY-27-1, PLY-29-1 | fixed |
| PLY-25-2 | deferred (owner decision: sync / settle deliberately left out) |

## Backend / gate needed
- **Platform-pass reads in China production.** `/api/platform-pass`, `/library`, `/orders` and `/orders/{orderNo}` are not in `ChinaReviewedRouteCapability`, so the production route gate refuses them (as it already did for the overview and library). Left as is per the owner rule; to ship 通行证订单 the owner adds `GET /api/platform-pass/orders` and `GET /api/platform-pass/orders/{}` to a reviewed grant. No backend change: both exist in `ApiPlatformPassController`.
- **Pass-order writes (MKT-5-3).** `POST /api/platform-pass/orders/{orderNo}/cancel` and `/refund-apply {reason}` exist; whether they count as money under the gate is an owner decision. The transport refuses every non-GET child today.
- **Free-explore reviews (MKT-7-2).** The backend has no `/api/free-explore/bundle/review`; the app never sends it (stub client). Needed client: `POST /api/merchant/public-home {memberId}` → `merchantRowId`; `POST /api/merchant/reviews/public?merchantRowId&registrationId&pageNum&pageSize=20`; `POST /api/merchant/reviews/create {merchantRowId, registrationId, rating, content, imageUrls: [], requestId}` (all live in the route table).
- **Invoice not-found (FIN-11-4).** Core maps `INVOICE_NOT_FOUND` on the original-request read to "unknown"; needs a Core change, not backend.

## Shared changes outside the member views
- `Core/MiniProgramPageLink.swift`: rules for `market/pass-order (orderNo)`, `market/gift (token optional)`, `free-explore (registrationId/topicId/requestId)`, `invoice-detail (id)`, `coupon-qr (couponHistoryId/historyId/id)`, `signup (focusId/topicId/arrive)`, `mycanyuinfo (id)`, `character (topicId)`, `orient-score (topicId/activityId/sessionId)`, `report-detail (reportId)`, `order/order (detailId)`, `orderinfo (id/outTradeNo)`; those pages left `openPages`.
- `Core/MiniProgramPages.swift` regenerated. `App/MPParityKit.swift`: `.passOrder` route, `passOrder` / `isSignedIn` bindings, gift states, `detailId` → order detail.
- `App/ProfileReadScreen.swift` (orders fork): every profile read page now keeps content on a failed pull-to-refresh and toasts.
- `playerJourney.start` now reads 开始游戏 everywhere it is used.
- No DesignSystem file changed.

## Owner decisions still open
MKT-3-1 (gift claim gate), MKT-4-1 (month-card-only plans), MKT-5-3 (pass-order cancel / refund), MKT-9-2 (coupon code confirm step), FIN-19-2 (提现记录 shown in Release independently of the withdrawal switch — done, needs sign-off), PLY-21-6 / 21-8 (wallet team row, filter menu), PLY-25-2 (orient sync / settle), PLY-26-2 (template search; MP page deleted 2026-11-22).

## Findings
| finding | status | files | local verification |
|---|---|---|---|
| MKT-1-1 | fixed | Core/PlatformPass.swift (`passOrders`, `PlatformPassSubscriptionOrder`), App/MPParityPassSession.swift (transport: GET list allowed, POST and children refused), App/PassMarketViews.swift | TEST account with a platform-pass order: 我的 → 通行证 → 我的订单 shows the 城瘾30天通行证 row (status / 退款进度 / ¥) above catalog orders; tap opens 通行证订单. |
| MKT-1-2 | fixed | App/MPParityPassSession.swift | Make `/api/user/info` fail (fixture): products, orders and gifts still render; balance card hidden. |
| MKT-1-3 | fixed | Core/PlatformPass.swift (optional token), App/MPParityPassSession.swift, App/PassMarketViews.swift | Signed out → 通行证: 可购买 lists products; 我的订单 / 礼品 show 登录后查看自己的订单和礼品 + 登录. |
| MKT-1-4 | fixed | App/PassMarketViews.swift | Pushed page: inline 通行证 title, tab bar hidden (`cyPushedChrome` + `cyPageTitle`). |
| MKT-1-5 | fixed | App/MPParityPassSession.swift | Merchant account deep link: products listed; member card and balance hidden. |
| MKT-1-6 / 1-7 | deferred (P2) | — | — |
| MKT-2-1 | fixed | App/PassMarketViews.swift (`PassDetailHost.openActivitySignup`) | Group / school product → 去报名 pushes the activity page (signup there). The ticket id is not preselected (no native baoming page). |
| MKT-2-2 | fixed | Core/PlatformPass.swift (`product(id:)`), App/MPParityPassSession.swift | `chein://mp/subpackageMember/market/pass/index?id=<off-sale id>` opens the product (GET api/marketing/product/{id}); ids like `order`/`list` are refused before sending. |
| MKT-2-3 | fixed | App/MPParityPassSession.swift | Extra-seat product: bar reads 加座需从原订单发起，暂不可直接购买; extra seats also left out of 可购买. |
| MKT-2-4 | fixed | App/MPParityPassSession.swift | Gift-only product: 使用人 reads 领取礼品的好友. |
| MKT-2-5 | fixed | App/MPParityPassSession.swift | 结算 shows one 价格 row "¥x / y 积分". |
| MKT-2-6 | fixed | App/MPParityPassSession.swift, App/PassMarketViews.swift | Signed out → product opens; bar shows 购买 → login sheet. |
| MKT-2-7 / 2-8 | deferred (P2) | — | — |
| MKT-3-1 | blocked (owner gate) | — | Gift claim stays behind `MPCommerceGate.claimsEnabled = false`. |
| MKT-3-2 | fixed | App/MPParityKit.swift, Core/MiniProgramPageLink.swift, Tests/AppUnitTests/MPParityDeepLinkRouteTests.swift | `chein://mp/subpackageMember/market/gift/index` (no token) shows 链接已失效. |
| MKT-3-3 | fixed | App/MPParityKit.swift, App/MPParityPassSession.swift (`isSignedIn`) | Signed out gift link → 登录后领取礼品 + 登录. |
| MKT-3-4 | fixed | App/PassMarketViews.swift | Gift hero title uses `.sectionTitle` (18 pt). |
| MKT-3-5 | deferred (P2) | — | — |
| MKT-3-6 | fixed | Resources/Localizable.xcstrings | Unknown claim state reads 还在确认结果，再点一次看看. |
| MKT-4-1 | deferred (owner decision) | — | Month-card-only filter not applied; audit asks to confirm the 2026-11-13 ruling first. |
| MKT-4-2 | fixed | App/MPParityPassSession.swift | One plan on the server → no 最划算 tag. |
| MKT-4-3 | fixed | App/PassMembershipViews.swift, App/MPParityPassSession.swift | 城瘾30天通行证 page shows 购买须知: 可玩主题 N 个主题 / 有效期 N 天 / 续费 不自动续费 / 退款规则 退款为整单. |
| MKT-4-4 | deferred | — | Plan tag, 即将到期, days-left bar need `holding.planLabel/daysRemaining/daysTotal/badge` decoded in Core `PlatformPassHolding` (server sends them). |
| MKT-4-5 | fixed | Resources/Localizable.xcstrings | Title / eyebrow 城瘾30天通行证; library row 查看包含主题 · N 个主题. |
| MKT-4-6 | deferred | — | Footer restructure waits for MKT-4-1. |
| MKT-4-7 / 4-8 | deferred (P2) | — | — |
| MKT-5-1 | fixed | Core/PlatformPass.swift (`passOrderDetail`), App/PassMarketViews.swift (`PassOrderDetailView`), App/MPParityKit.swift (`.passOrder`), App/MPParityPassSession.swift (`MPParityPassOrderModel`), Core/MiniProgramPageLink.swift, Core/MiniProgramPages.swift | `chein://mp/subpackageMember/market/pass-order/index?orderNo=<no>`: rows 订单状态 / 退款进度 / 退款金额·时间 / 未通过原因 / 有效期至 / 支付时间 / 订单号 (复制订单号 → 已复制). Pay / cancel / refund show the gate note. |
| MKT-5-2 | fixed | App/PassMarketViews.swift | Rejected refund → 申请复核 · 联系城瘾小助手 opens the IM list. |
| MKT-5-3 | blocked (owner) | — | Cancel / refund-apply on `/api/platform-pass/orders/{no}/…` not wired; transport refuses every non-GET child. |
| MKT-6-1 | fixed | Core/PlatformPass.swift (`publicLibrary`, `PlatformPassLibraryCard.catalog`), App/MPParityPassSession.swift | Guest / merchant / pass off → 游戏主题库 lists the public catalog (POST api/public-catalog/list, pageSize 100, product_type 1/2); ¥0 可玩 only on `passCovered: true`. |
| MKT-6-2 | fixed | App/PassMembershipViews.swift (`PassLibraryHost.openTopic`) | Tap a library card → topic detail. |
| MKT-6-3 | fixed | App/PassMembershipViews.swift | Inline title. |
| MKT-6-4 / 6-5 | deferred (P2) | — | — |
| MKT-7-1 | partial | App/MPReviewedPageScreen.swift, Core/MiniProgramPageLink.swift | `free-explore?registrationId=` → that order (自由探索权益 entry); `?topicId=` → topic; `?requestId=` → 我的订单 (no receipt reader); none → 链接缺少必要参数. |
| MKT-7-2 | blocked (needs client work, no backend change) | — | Verified: backend has no `/api/free-explore/bundle/review`; the app never calls it (`UnavailableBundleReviewClient`). Needed: a client on `POST /api/merchant/public-home {memberId}` → `POST /api/merchant/reviews/public?merchantRowId&registrationId&pageNum&pageSize` and `POST /api/merchant/reviews/create {merchantRowId, registrationId, rating, content, imageUrls:[], requestId}` (all `.liveInProduction` in the route table). |
| MKT-7-3 / 7-6 / 7-7 | deferred | — | Bundle page restructure. |
| MKT-7-4 / 7-5 | fixed | Resources/FreeExploreBundleLaunch.xcstrings | Title 自由探索权益; MP copy 权益加载失败，请重试 / 重新确认 / 确认预约. |
| MKT-7-9 | fixed | App/FreeExploreBundleLaunchView.swift | Date picker starts at now. |
| MKT-8-1 | deferred | — | One-tap code needs the detail push removed for unused coupons. |
| MKT-8-2 / 8-5 / 8-6 | fixed | App/AccountCollectionCouponsView.swift, App/MPReviewedPageScreen.swift | Inline title, single domain modifier, spacing token; `coupon-wallet` deep link opens the wallet. |
| MKT-8-3 | fixed | App/AccountCollectionCouponsView.swift | Invalid coupon shows 该券已被平台手动失效. |
| MKT-8-4 | deferred | — | Shop navigation pill. |
| MKT-9-1 / 9-3 / 9-6 | fixed | App/CouponCodeView.swift, xcstrings | Inline title, `.cyText` tokens, 请返回优惠券重新进入. |
| MKT-9-2 | deferred (owner) | — | Confirm step kept until a ruling. |
| MKT-10-2 / 10-4 | fixed | App/CouponManagementView.swift | Inline titles; 已失效 / 已停发 chips in danger tone. |
| MKT-10-1 / 10-3 / 10-5 | deferred | — | Summary read, detail as sheet, 403 CTA. |
| FIN-11-1 | fixed (routing, main branch) | App/MPReviewedPageScreen.swift | Open `chein://mp/subpackageMember/invoice/index`: 我的发票 list, not "unavailable". |
| FIN-11-2 | fixed | InvoiceLaunchPresentation, InvoiceLaunchHistoryView | TEST account, 我的发票: make a withdraw fail (fixture cancel not confirmed). List stays, toast 撤回结果未确认，请刷新查看. |
| FIN-11-3 | fixed | InvoiceLaunchHistoryView | SUBMITTED card shows a visible 撤回申请 button; swipe and VoiceOver action also work. |
| FIN-11-4 | partial | InvoiceLaunchPresentation | 查询结果 with no result: 暂未查到这次申请 · 再查一次. Core maps INVOICE_NOT_FOUND to "unknown" (needs Core/InvoiceLaunchService change). |
| FIN-11-5 | fixed | InvoiceLaunchHistoryView | Card shows 单位/个人, masked tax number or 个人抬头, 申请于 time, issuer · N 笔订单, 开票金额. |
| FIN-11-6 | fixed | InvoiceLaunchUI.xcstrings | zh copy 还没有发票申请 / 发票功能暂未开放 / 发票记录加载失败 / 撤回发票申请. |
| FIN-11-7 | partial | InvoiceLaunchPresentation, MPReviewedPageScreen | Signed out via a deep link: 微信登录 shown; the 我的 / 设置 entries do not pass `onSignIn` yet. "unavailable" has no 重试. |
| FIN-11-8..11 (P2) | fixed | InvoiceLaunchHistoryView, Presentation | Chip filter, pinned 管理抬头 / 申请开票 footer, pushed chrome + inline title, 「10月27日 10:30」 dates. |
| FIN-12-1 | fixed | InvoiceLaunchDetailView | Rejected application → 重新申请 opens 申请开票 (needs the apply grant). |
| FIN-12-2 | fixed | InvoiceLaunchDetailView | 联系客服 opens ParticipationSupportView. |
| FIN-12-3 | fixed | InvoiceLaunchDetailView, xcstrings | 开票单位 row, 订单名 · 票种 rows, 包含订单 / 开票金额 sections. |
| FIN-12-4 | fixed | InvoiceLaunchDetailView | Pending cancel: 待确认 chip + 撤回结果未确认 + 刷新. |
| FIN-12-5 | deferred (intended, MC-35) | — | — |
| FIN-12-6 / 12-7 | fixed | InvoiceLaunchDetailView | 开具时间 hidden when absent; inline title + pushed chrome. |
| FIN-13-1 | fixed | InvoiceLaunchApplyView | Selecting orders updates 已选订单 / 总计 in the list and footer (display only). |
| FIN-13-2 | fixed | InvoiceLaunchPresentation, InvoiceLaunchApplyView | Fixture rejects INVOICE_ORDER_NOT_ELIGIBLE → form and still-eligible selection stay; 申请未提交 · 订单有变化，请重新选择. |
| FIN-13-3..8 | fixed | InvoiceLaunchApplyView | Default title preselected; 新增抬头; 全选本单位; checkbox rows; 开票单位 groups + 暂不可申请 group; 50-order notice; 选择发票抬头 sheet. |
| FIN-13-9 (P2) | fixed | InvoiceLaunchApplyView | Row spacing token, tabular amounts. |
| FIN-14-1..5 | fixed | InvoiceLaunchTitlesView, xcstrings | One row per title, labelled trash + swipe delete, no request id, 还没有发票抬头, failed delete keeps the list. |
| FIN-14-6 (P2) | fixed | InvoiceLaunchTitlesView | Pushed chrome + inline title. |
| FIN-15-1..3 | fixed | InvoiceLaunchTitleEditor | Backgrounding clears only the tax number; pending shows 确认前请勿重复保存; refusal keeps form with 发票抬头未保存 + reason. |
| FIN-15-4..6 (P2) | fixed | InvoiceLaunchTitleEditor | Length limits, 重新填写完整税号 placeholder, danger token, 设为默认, * 必填 markers. |
| FIN-16-1 | fixed (behind the owner's `allowsReviewedCancellationAndRefund` config) | App/OwnedOrderComposition.swift, App/AppSession.swift, Core/OrderLifecycleCoordinator.swift, App/ProfileOrdersView.swift | TEST account with cancel/refund enabled: 我的 → 我的订单 → unpaid order → 取消订单 → review sheet → confirm. Release config: "如需取消或退款，请联系客服" under 联系客服. |
| FIN-17-1 | fixed | App/ProfileOrdersView.swift | Detail action by state: unpaid → 取消订单, paid free → 取消报名, paid refundable → 申请退款; verified order shows none. |
| FIN-16-2 | deferred | — | Owned-order reader needs the full list in one response; paging needs a reader protocol change. |
| FIN-16-3 | fixed | App/ProfileReadScreen.swift | Orders list → network off → pull: rows stay, toast 刷新失败，稍后再试 (shared by all profile read pages). |
| FIN-16-4 | fixed | App/SubscribeMessageTapScreens.swift | `chein://mp/subpackageMember/order/order` opens the same host as the 我的 row. |
| FIN-16-5 | fixed | App/ProfileOrdersView.swift | 待付款 row shows 请在小程序完成支付 while payment is off. |
| FIN-16-6 | fixed | Core/MiniProgramPageLink.swift | `order/order?detailId=` accepted. |
| FIN-16 sign-in | fixed | ProfileReadScreen, ProfileOrdersView, OwnedOrderComposition | Signed out → 我的订单 → 登录 opens login. |
| FIN-16-7, 16-8 | deferred (P2) | — | — |
| FIN-17-2 | fixed | App/ProfileOrdersView.swift | Detail amounts read ¥x, no 「币种待确认」. |
| FIN-17-3, 17-4, 17-5 | deferred | — | Session-level screens on the detail. |
| FIN-17-6 | fixed | Core/MiniProgramPageLink.swift | `orderinfo?outTradeNo=` accepted (opens by id when present). |
| FIN-17-7, 17-8 | deferred (P2) | — | — |
| FIN-18-1 | fixed | App/WalletCommerceViews.swift | 钱包 → 积分 uses `api/points/list`; totals match 资产 → 积分明细. |
| FIN-18-2 | deferred | — | Pager reset lives in Core `WalletLedgerPager`. |
| FIN-18-3 | partial | App/WalletCommerceViews.swift, Core/WalletPointsLedgerEmptyState.swift | Empty account: 还没有积分记录 with no picker; failure copy still shared. |
| FIN-18-4 | fixed | App/WalletCommerceViews.swift | Points rows not tappable, no chevron. |
| FIN-18-5 | fixed | App/MPReviewedPageScreen.swift | `chein://mp/subpackageMember/points-history/index` opens 积分明细. |
| FIN-18-6/7/8 | deferred (P2) | — | — |
| FIN-19-1 | deferred | — | Paging needs a Core service change. |
| FIN-19-2 | fixed (owner sign-off needed) | App/WalletCommerceViews.swift | Release: 钱包 shows 提现记录; 提现 apply stays hidden. |
| FIN-19-3 | fixed | App/WithdrawalHistoryView.swift | Inline title 提现记录, no hero header. |
| FIN-19-4 | partial | xcstrings | zh copy aligned; no 登录 button (view has no session). |
| FIN-20-1 | fixed | App/SocialInviteHistoryView.swift | Load-more reads 加载更多. |
| FIN-20-2 | deferred | — | Duplicate total row required by `test_w2_04_p2_member_tools`. |
| FIN-20-3 | fixed | App/SocialInviteHistoryView.swift | Inline title 邀请记录. |
| FIN-19-5, 20-4/5/6 | deferred (P2) | — | — |
| PLY-21-1 | fixed | Core/TicketWalletContracts.swift, App/TicketWalletView.swift, App/TicketPassSheet.swift, Tests/CoreTests/TicketWalletUsableTests.swift | TEST account with unpaid, cancelled, expired and refunded registrations: 票夹 lists only usable ones, soonest expiry first; `TicketWalletUsableTests`. |
| PLY-21-2 | fixed | App/TicketWalletView.swift, App/SessionTicketWalletHost.swift, App/MPReviewedPageScreen.swift, Core/MiniProgramPageLink.swift | `chein://mp/subpackageMember/signup/index?focusId=<id>` opens that ticket; unknown id → 未定位到原报名凭证 + 重试 (no registration/info fallback read). |
| PLY-21-3 | fixed | App/SessionTicketWalletHost.swift + 6 hosts | Open 票夹 from home, a topic, an activity, a deep link and the pass sheet → ticket detail shows 开始游戏. |
| PLY-21-4 | fixed | App/TicketPassSheet.swift, App/TicketWalletDetailView.swift | Cleared or upcoming ticket: no QR, no 出示票券. |
| PLY-21-5 | partial | App/TicketWalletView.swift | Card shows M月D日开始 / 退款中 / 已通关 tag and 类型 · 剩 N 天; cover, party line deferred. |
| PLY-21-6 | deferred (owner) | — | Wallet-wide 我的队伍 row kept pending owner. |
| PLY-21-7 | partial | App/SessionTicketWalletHost.swift | Signed out: 登录 opens login; 去探索主题 deferred (no tab-switch API). |
| PLY-21-8 | deferred (owner) | — | MP F13 vs handoff conflict on the filter menu. |
| PLY-21-9 | fixed | App/TicketWalletView.swift | Pushed wallet: one bar, inline 票夹 title. |
| PLY-21-10 | fixed | App/TicketWalletView.swift | One lane failing: other lane's tickets plus a footnote. |
| PLY-21-11 | fixed | App/TicketWalletView.swift, App/TicketPassSheet.swift, xcstrings | Empty wallet and pass sheet read 还没有票. |
| PLY-21-12 | fixed | App/TicketWalletView.swift | Typography lint counts down. |
| PLY-21-13/14/15 | deferred (P2) | — | — |
| PLY-22-1 | fixed | App/PlayerJourneyViews.swift | 我的参与 row → 查看报名凭证 → wallet focused on that registration. |
| PLY-22-2 / 22-3 / 22-5 / 22-6 / 22-7 | fixed | App/PlayerJourneyViews.swift, App/ParticipationParityViews.swift | 已核销/未核销 chip, meta-size lines, CYStatusChip tags, one VoiceOver element, 2-line name. |
| PLY-22-4 | partial | xcstrings | MP loading / sign-in copy; skeleton deferred. |
| PLY-23-1 | fixed | App/PlayerJourneyViews.swift, App/MPReviewedPageScreen.swift, Core/MiniProgramPageLink.swift | `chein://mp/subpackageMember/mycanyuinfo/mycanyuinfo?id=<id>` pushes 参与详情. |
| PLY-23-2 | fixed (no probe) | App/PlayerJourneyViews.swift | Topic registration detail → 我的角色卡 → card page. |
| PLY-23-3 / 23-4 / 23-6 / 23-8 | deferred | — | Free-explore entry, merchant-apply editor, cover images, P2. |
| PLY-23-5 | fixed | xcstrings | 退出与暂停规则 copy. |
| PLY-23-7 | partial | App/PlayerJourneyViews.swift | cyPageTitle applied; Theme.Space remains. |
| PLY-24-1 | fixed | App/MPReviewedPageScreen.swift, Core/MiniProgramPageLink.swift | `chein://mp/subpackageMember/character/index?topicId=<id>` opens 我的角色卡. |
| PLY-24-2 / 24-3 | fixed | App/CharacterCardReadbackView.swift | Inline title; signed out → 登录 → reload. |
| PLY-24-4 | partial | xcstrings | Loading / sign-in copy; traits header deferred. |
| PLY-24-5/6/7 | deferred (P2) | — | — |
| PLY-25-1 | fixed | Core/CloudB3Readers.swift, App/CloudB3Production.swift, App/OrientScoreView.swift, App/OrientScoreEntryProduction.swift, App/OrphanScreenMounts.swift, App/ActivityDetailView.swift | TEST account with 2+ current rounds on one topic: 定向成绩 shows 选择要查看的本人对局 + 查看此局计分; then toolbar 选择其他对局. Unit test `OrientScoreModelLoadTests`. |
| PLY-25-2 | deferred (owner decision) | — | Sync and settle stay off (audit: deliberately left out). |
| PLY-25-3 / 25-4 / 25-5 | deferred | — | Leaderboard UI, node-id appeal, per-row appeal sheet. |
| PLY-25-6 | fixed | App/OrientScoreView.swift | Signed out: 请登录本人账号查看对局 + 登录 → reload. |
| PLY-25-7, X11 | fixed | App/OrientScoreView.swift, App/MPReviewedPageScreen.swift | Inline 本局计分; `orientScore.readOnly` gone; `chein://mp/subpackageMember/orient-score/index?topicId=<id>` opens it. |
| PLY-26-1 | fixed | Core/TemplateAuthoring{Contract,Coordinator,Shelf,WireRequestBuilder}.swift, Core/TemplateOwnShelfMarketPlan.swift, App/TemplateAuthoringMineView.swift | 我的节点玩法: approved row with no square record → 提交广场审核 (POST /api/template/{id}/market-submit); pending → 撤回广场审核 (updateLibraryStatus status 2); online → 从广场下架 (3, destructive confirm); delisted → 上架广场 (1). Backend `updateLibraryStatus` reads `status`, not `publish_status`. |
| PLY-26-2 | deferred (owner) | — | MP page deleted 2026-11-22 (now myproject?type=template); search kept pending owner. |
| PLY-26-3 / 26-6 / 26-7 | fixed | App/TemplateAuthoringMineView.swift | Inline title, no hero header / 刷新 pill, `.cyText` review sheet. |
| PLY-26-4 | partial | App/TemplateAuthoringMineView.swift | Library toggle replaced by the square action; ⋯ menu and cover not done. |
| PLY-26-5 | deferred | — | Merchant scope. |
| PLY-27-1 | fixed | App/ProfileComplaintPreparationView.swift, App/MPReviewedPageScreen.swift | `chein://mp/subpackageMember/complaint/index` opens 投诉与建议. |
| PLY-27-2 / 27-4 | fixed | App/ProfileComplaintPreparationView.swift | Inline title, no 关闭 or ↻; after submit toast 投诉已提交 and back after 1.2 s. |
| PLY-27-3 | deferred | — | Three-step submit kept. |
| PLY-28-1..4 | fixed | App/SquareReportProgressView.swift, MemberReportProgress strings | 我的举报: no boundary line or 刷新 pill, inline title, per-filter empty copy, signed out → 登录. |
| PLY-29-1 | fixed | App/MemberReportProgressDetailView.swift, Core/MemberReportProgressCoordinator.swift, App/MPReviewedPageScreen.swift, Core/MiniProgramPageLink.swift | `chein://mp/subpackageMember/report-detail/index?reportId=<id>` opens 举报进度 for the user's own report; others → 暂时不能查看这条举报. |
| PLY-29-2 / 29-3 / 29-5 | fixed | App/MemberReportProgressDetailView.swift | No boundary footer, stage hint, APPEALED note, inline title, pull-to-refresh. |
| PLY-29-4 | deferred | — | Appeal sheet flow. |
| PLY-30-1..4 | fixed | App/MemberScoreAppealListView.swift, MemberScoreAppealList strings | 我的申诉: 账号信誉 sheet, per-filter empty copy, 申诉记录加载失败 + 重试, signed out → 登录; boundary rows and refresh pill gone. |
| P2s (25-8/9, 27-5/6, 28-5/6, 29-6, 30-5/6) | deferred (29-6 partly: spacing tokens) | — | — |

Findings not listed above (remaining P1s on pages 7–10 not named here, and P2s) are deferred to the next round.
