# Receipt: fix-parity2-member (r2)

Brief: `origin/design/handoff-r2:docs/briefs/fix-parity-r2.md`. Findings: `origin/audit/parity-member:docs/audit/parity/member.md`. Round 1: `docs/release/receipts/fix-parity-member.md`.
Branch `fix/parity2-member`, from `origin/ui/combined-r5` @ `65eb1def4` (rebased; no newer base commits at the end of the run). Swift is not installed in the cloud: nothing here was compiled or run on a simulator. Every change copies an existing pattern in the same file or a sibling file.

## Gates
- `python3 -B tools/check_scaffold.py`: PASS (264 pages, 4942 Swift files, bilingual keys complete).
- `python3 -B tools/check_design_lint.py`: PASS. Typography ratchet lowered with `--update`: raw text style 1173 → 1170 (AccountCollectionCouponDetailView, CouponManagementView, PlayerJourneyViews). Other counts unchanged.
- `python3 -B tools/contract_ratchet.py --check`: no new failures from this branch. The base `ui/combined-r5` already fails one test that is not in the baseline (`test_workshop_paid_professional…test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging`: 185 on base, baseline 184), and this branch ends at the same 185. Mid-run, my changes had broken 9 pins; each was fixed by restoring the pinned code shape or by updating a pin whose behaviour the finding changes (C02 sha manifest for CharacterCardReadbackView → PLY-24-4; couponManagement key count 95 → 97 → MKT-10-5).
- Contract pins updated because a finding changes the behaviour they encoded (each cites its id): `Tests/ContractChecks/test_w2_04_p2_member_tools.py` and `test_social_invitation_lifetime.py` (FIN-20-2), `test_coupon_management_integration.py` and `docs/issue5-hunks/C02-ios-pbx.rnhunk.md` (MKT-10-5, PLY-24-4), `Tests/AppUnitTests/BundleCommerceMountTests.swift` (MKT-7-2: 评价 now shows in China because it reads the live merchant-review route).
- New unit test (not run): `MPParityPassBindingTests.testMembershipCardFactsFollowHolding` (MKT-4-4).
- UI tests that need a follow-up (authored NOT_RUN, not run here): `TemplateOwnShelfFlowTests` taps `templateAuthor.shelf.delete.901` directly; after PLY-26-4 it must open `templateAuthor.shelf.more.901` first (this file already referenced controls round 1 removed). `ProfileComplaintPreparationFlowTests` taps `profile.complaint.review`; with a configured sender that button now opens the confirm sheet (PLY-27-3).
- Chrome (`tools/report_chrome.py`): no custom back chevron, hidden system back, `cyHeroPushedChrome` or title-mode-unset hit is in a member file, so step 3 of the brief had nothing to change. New pushed pages use `cyPageTitle`.

## P0 status (round-1 carry-overs)
| P0 | status |
|---|---|
| MKT-7-2 | fixed this round (contract). See the row below for the gate caveat. |
| MKT-7-1 | partial (unchanged: registrationId and topicId entries work; requestId still lands on 我的订单) |
| MKT-3-1, PLY-25-2 | owner decision (unchanged) |
| all other P0s | fixed in round 1 |

## Backend needed
None new. Every endpoint used here is already served and in the route table: `POST /api/merchant/public-home`, `POST /api/merchant/reviews/public`, `POST /api/merchant/reviews/create`, `GET /api/free-explore/bundle/order/receipt`, `POST /api/invoice/orders/eligible`, `GET /api/platform-pass` (holding card facts come from `PlatformPassService.putCardFacts`), and the registration fields `invoiceStatus` / `invoiceApplicationId` / `invoiceNo` (`CmsRegistration`). Round 1's gate note still applies: `/api/platform-pass/orders*` must be added to a reviewed grant before 通行证订单 can ship in China production.

## Shared changes outside the member views
- No DesignSystem file changed.
- `Core/ProfileContracts.swift`: `ProfileOrder` decodes `invoiceStatus`, `invoiceApplicationId`, `invoiceNo` leniently (a bad value never fails the order read); adds `ProfileOrderInvoiceState` / `invoiceState`.
- `Core/PlatformPass.swift`: `PlatformPassHolding` gains `planLabel`, `daysTotal`, `daysRemaining`, `teammateBenefit`, `expiring` (defaulted init, so existing call sites still compile).
- `Core/ProfileInviteRewardReview.swift`: `earnedCount` (only when the ledger is complete).
- `App/OwnedOrderComposition.swift`: the 我的订单 host sets two environment values: the public-merchant context (MKT-7-2) and the invoice presentation (FIN-17-3). `App/MPReviewedPageScreen.swift`: the `orderinfo?id=` deep link sets the invoice value too.
- `App/AccountView.swift` (1 line) and `App/SettingsInvoiceEntry.swift`: the 我的发票 links go through `InvoiceLaunchSessionHistory` (FIN-11-7).
- `App/SessionTicketWalletHost.swift`: reads `rootTabSwitch` (PLY-21-7).

## Owner decisions still open (unchanged)
MKT-3-1 (gift claim gate), MKT-4-1 (month-card-only plans; MKT-4-6 waits on it), MKT-5-3 (pass-order cancel / refund), MKT-9-2 (coupon code confirm step), FIN-19-2 (提现记录 in Release), PLY-21-6 / 21-8 (wallet team row, filter menu), PLY-25-2 (orient sync / settle), PLY-26-2 (template search).

## Findings (this round)
| finding | status | files | local verification |
|---|---|---|---|
| MKT-7-2 (P0) | fixed (contract); the writes stay behind the existing gate | App/BundleCommerceMount.swift, App/OwnedOrderComposition.swift, Tests/AppUnitTests/BundleCommerceMountTests.swift | TEST account with a free-explore bundle order that has a reservation: 我的 → 我的订单 → the order → 套餐 → 评价 lists 评价本次预约的商家 (one row per reserved merchant) and opens that merchant's public page. The review list and editor there use `merchant/reviews/public` and `reviews/create {merchantRowId, registrationId, rating, content, imageUrls, requestId}`. **Caveat:** `RetainedPublicMerchantReviewHost` still builds its reader and writer with `enabled: false` (not a member file), so until that gate opens the page shows its not-configured note instead of reviews. With no reservation: 完成预约后可评价商家. |
| MKT-7-6 | fixed | App/FreeExploreBundleLaunchView.swift, Resources/FreeExploreBundleLaunch.xcstrings | Bundle with no reservations: the 订单 card still shows the order number and 实付金额, with 暂无预约记录. |
| MKT-7-7 | fixed | App/FreeExploreBundleLaunchView.swift | Pick a chapter, store and time → 复核: rows show the order number, chapter name and store name (— when unknown), never raw ids. |
| MKT-7-8 (P2) | fixed | App/FreeExploreBundleLaunchView.swift | Cover badge uses `.cyText(.meta, weight: .semibold)` and `CYColor.bgOverlay`. |
| MKT-8-1 | fixed | App/AccountCollectionCouponsView.swift | 优惠券: tap an unused coupon → the code screen opens directly (footer 出示核销码, or 查看可用时间 before the start day). Used, expired and invalid coupons still open the detail. |
| MKT-8-4 | fixed | App/AccountCollectionCouponsView.swift | Coupon with both shop coordinates: a 44 pt 导航 capsule sits bottom-right of the card and opens Maps; tapping elsewhere still pushes. No coordinates: no capsule. |
| MKT-10-3 | partial | App/CouponManagementView.swift | Batch code uses `.cyText(.body).monospaced()`. The detail is still a pushed page, not a sheet. |
| MKT-10-5 | partial | App/CouponManagementView.swift, Localizable | Account that gets 403 on the published list: 当前身份不能查看优惠券 + 返回. The MP's 申请入驻 for players is not wired. |
| MKT-4-4 | fixed | Core/PlatformPass.swift, App/MPParityPassSession.swift, App/PassMembershipViews.swift, Localizable, MPParityPassBindingTests | Active pass whose holding has `planLabel: 月卡, daysTotal: 30, daysRemaining: 4, badge: EXPIRING`: the card shows 月卡 / 即将到期 chips and 剩余 4 天 / 共 30 天 with a bar. `teammateBenefit: true` adds 同行可用. Inactive: none of these. |
| FIN-17-3 | partial | Core/ProfileContracts.swift, App/ProfileOrdersView.swift, App/OwnedOrderComposition.swift, App/MPReviewedPageScreen.swift, Localizable | Paid, non-free order with `invoiceStatus`: a 发票 section shows 开票状态 (未申请 / 开具中 / 已开具 / 退款核对中), 发票号 when issued, then 申请开票 (NONE) or 发票申请 → 发票详情 (issuing or issued with an application id). Free, unpaid or no-status orders show no section. Gap: for NONE the MP first checks `POST /api/invoice/orders/eligible` and shows 暂不可申请 for ineligible orders; the app links straight to 申请开票, where the order lands in the 暂不可申请 group. |
| FIN-17-5 | fixed | App/ProfileOrdersView.swift | Order detail opens with the paid amount (`.dataXL`, — when unknown), the order name and a status chip, above the notice and rows. |
| FIN-11-7 | fixed | App/SettingsInvoiceEntry.swift, App/AccountView.swift | 我的 → 我的发票, then let the token expire (TEST): the signed-out state offers 微信登录 and opens login. Same path from 设置. |
| FIN-11-4 | partial (unchanged code) | — | Re-checked: a manual 再查一次 that still finds nothing reads 暂未查到这次申请 and keeps the pending request, as the MP does. Gap: a network failure during that re-check reads the same. |
| FIN-18-3 | fixed | App/WalletCommerceViews.swift, Localizable | 积分明细 with the read failing: 积分明细加载失败 + 重试 (other ledgers keep their copy). The empty state was fixed in round 1. |
| FIN-20-2 | fixed | App/ProfileInviteRewardReviewSection.swift, App/SocialInviteHistoryView.swift, Core/ProfileInviteRewardReview.swift, 2 contract pins | 邀请记录: one hero section with 首购奖励积分, +N (待同步 while the ledger is incomplete) and 已邀请 N 人 · 已到账 M 人 (已到账 only on a complete ledger). No second 累计邀请 line or row. |
| PLY-21-7 | fixed | App/SessionTicketWalletHost.swift | Signed-in empty 票夹 from 我的: 「+ 去探索主题」 shows and switches to the home tab; a sheet-hosted wallet closes first. Outside the root TabView (fixtures) the button stays hidden. |
| PLY-22-4 | partial | Localizable | 我的参与: 正在加载参与记录… and 登录后查看参与记录. Skeleton rows still deferred. |
| PLY-23-7 | fixed | App/ParticipationParityViews.swift, App/PlayerJourneyViews.swift | Participation card spacing uses `CYSpacing`; the cover placeholder no longer uses a raw font (typography count down by 1). |
| PLY-24-4 | fixed | App/CharacterSheetDetailView.swift, App/CharacterCardReadbackView.swift, Localizable | 我的角色卡: attributes sit under the header card with no 本局特质 group title. A card with nothing to show reads 链接已失效 + 返回 (pops). |
| PLY-26-4 | partial | App/TemplateAuthoringMineView.swift, Localizable | 我的节点玩法: each card has one 44 pt ⋯ menu (square action, then 删除节点玩法 in red); each item still opens its review sheet. Cover image not added. |
| PLY-27-3 | fixed | App/ProfileComplaintPreparationView.swift | 投诉与建议 with a configured sender: fill the form → 提交投诉 opens the confirm sheet in one tap. Cancelling it leaves the review section as a fallback. Without a sender the button still reads 确认内容. |

## Still deferred (reason)
| finding | reason |
|---|---|
| MKT-7-1 (P0, partial) | The `requestId` receipt read (`GET /api/free-explore/bundle/order/receipt`, in the route table) needs a session-level `FreeExploreLaunchService` outside an order; today it is only built from an owned-order row. |
| MKT-7-3 | Folding the hub into the bundle page is a restructure of two screens. |
| MKT-4-6 | Waits on MKT-4-1 (owner). |
| MKT-10-1 | 累计领取 / 核销 needs a new read on `CouponManagementAdapter` and all its implementations. |
| FIN-16-2, FIN-19-1, FIN-18-2 | Paging and keep-on-refresh live in the Core readers / `WalletLedgerPager` (protocol changes). |
| FIN-17-4 | Team, seats, consent and club rows on order detail: each needs its own host. |
| PLY-21-5 | Card copy needs new wallet fields; unchanged from round 1 (partial). |
| PLY-23-3, 23-4, 23-6 | Bundle entry from participation, merchant-apply editor and cover images need new mounts. |
| PLY-25-3, 25-4, 25-5 | Leaderboard and node appeals need a loader threaded through the three orient mount sites, plus a sheet flow. |
| PLY-26-5 | Merchant scope on the shelf requests is a Core contract change. |
| PLY-29-4 | The appeal sheet lives in `CommunityTrustPlayerViews` (shared). |
| P2s | Not reached, except MKT-7-8. |
