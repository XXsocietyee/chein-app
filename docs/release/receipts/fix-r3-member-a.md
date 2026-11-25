# Receipt · fix-r3 member-a (Claude F-agent, App layer)

- **Brief:** `design/handoff-r2:docs/briefs/wave-x10.md`. Half **a** = round-1 audit pages **1–15** of `subpackageMember` (market ×6, free-explore, coupons ×3, invoices ×5).
- **Branch:** `fix/r3-member-a`, from `origin/ui/combined-r7`, with `origin/restyle/r4-me-account` merged first (it touches `AccountCollectionCouponsView`, `CouponCodeView`, `CouponManagementView`, `BundleCommerceMount`, `InvoiceLaunchApplyView`, `PassMarketViews`, `PassMembershipViews`, `MPParityKit`). The merge was clean.
- **Gap sources used:** `audit/parity-r7-member` (FIX QUEUE, newest), `review/r7-rev-{a,b,c}` (no App-layer items on pages 1–15; B-13/B-20 are Cursor), round-1 `audit/parity-member`, `fix-parity-member.md`, `fix-parity2-member.md`.
- **No compiler in the cloud.** Every API used was grepped on r7 first (`CYStateLayout`, `cyHaptic(_:trigger:where:)`, `RegistrationUIFlow.selectTicket(id:)`, `OwnedCouponCodeDestination(View)`, `OwnedCouponReadScreenModel.rows(for:)`, `InvoiceLaunchPending.Kind.saveTitle`, `FreeExploreLaunchCatalog.saleEnabled/unitsPerHolder`). The coordinator's build is the first real check.

## Fixed

| id | page | what changed | files |
|---|---|---|---|
| R7-MEM-2-1 | 2 market/pass | An in-app `pass` link with no `id` opens 商品不存在或已下架 + 返回 instead of being rejected | App/MPParityKit.swift, App/MemberMissingLinkState.swift (new) |
| R7-MEM-5-1 | 5 market/pass-order | A `pass-order` link with no `orderNo` opens 链接已失效 + 返回 (MP PG-041), with no read sent for an empty number | App/MPParityKit.swift, App/MemberMissingLinkState.swift |
| R7-MEM-12-1 | 12 invoice-detail | Missing `id` shows 链接已失效 + 返回 instead of the generic 暂不可用 placeholder | App/MPReviewedPageScreen.swift |
| MKT-3 row 1 (residual) | 3 market/gift | The missing-token state gets the MP 返回 action too (the deep-link sheet has no system back) | App/MPParityKit.swift |
| MKT-2-1 | 2 market/pass | Group/school 去报名 now opens `pages/activity/baoming?activityId&ticketId`. The native baoming route lands on the activity with the registration sheet open, and the sheet starts on the pass ticket. An unknown ticket id is ignored by `selectTicket`, so signup still asks | App/PassMarketViews.swift, App/MPReviewedPageScreen.swift, App/ActivityDetailView.swift, App/SessionRegistrationSheet.swift, App/RegistrationSheetView.swift |
| R7-MEM-7-1 (part) | 7 free-explore | Catalog card shows 暂未开售 when `saleEnabled == false`, and each chapter shows 每人N次 (次数待确认 when the count is not positive) | App/FreeExploreBundleLaunchView.swift, docs/port/strings/fix-r3-member-a.json |
| MKT-9-3 | 9 coupon-qr | Used-state glyph uses `.cyText(.pageTitle, weight: .semibold)`; redemption time uses `CYColor.textSecondary` | App/CouponCodeView.swift |
| MKT-9-4 | 9 coupon-qr | `.cyHaptic(.success)` fires once on the transition into `.used` (MP vibrates on scan) | App/CouponCodeView.swift |
| R7-MEM-9-1 | 9 coupon-qr | `coupon-qr?couponHistoryId=` (also `historyId` / `id`) lands on the wallet; once the owner's list is read and holds that coupon unused, the code screen is pushed once. Otherwise the list stays | App/AccountCollectionCouponsView.swift, App/MPReviewedPageScreen.swift |
| R7-MEM-14-1 | 14/15 invoice-titles, title-edit | The shared state section picks 上次保存结果未确认 · 确认前请勿修改抬头 when the pending write is a title save. The page's own banner shows only when the shared section is not already showing, so the 查询结果 row appears once | App/InvoiceLaunchPresentation.swift, App/InvoiceLaunchTitlesView.swift, App/InvoiceLaunchTitleEditor.swift |

New strings: `docs/port/strings/fix-r3-member-a.json` (`freeBundle.catalog.notOnSale`, `freeBundle.catalog.unitsPerHolder %lld`, `freeBundle.catalog.unitsUnknown`). The missing-link states reuse existing keys (`mp.common.linkExpired`, `g6.product.reason.PRODUCT_NOT_FOUND`, `mp.gift.linkInvalid`, `action.back`).

## Requests for Cursor (Core; not changed here)
1. **`Core/MiniProgramPageLink.swift` reviewedPages:** set `required: []` for `subpackageMember/market/pass/index`, `market/pass-order/index` and `invoice-detail/index`. Until then, external links (chein / universal / push) without the id are still refused before they reach the new App missing states. In-app paths already land on them.
2. **R7-MEM-7-1 rest:** `FreeExploreLaunchCatalog.Item.Store` has no `available`. Decode `available` (MP `store.available === true`) so the App can show 可用 / 暂不可用 per store.
3. Queue items already tagged Cursor on these pages: MKT-4-3 (`overview.terms`), R7-MEM-7-2 (`BUNDLE_LEDGER_OFF`), MKT-9-5 (not-mine phase), R7-MEM-10-1 (player scope + `is_select:0`), FIN-11-1 residual (`invoice/index?id=`), B-13 / B-20 (invoice `INVOICE_NOT_FOUND` tests and title request).

## Left open, with reasons
| id | reason |
|---|---|
| MKT-3-1 (P0, gated) | Gift claim is a money write; owner decision. |
| MKT-7-1 (P0), MKT-7-3, MKT-10-1 | Gemini: parked `App/MPGap/Member` views must compile and be mounted (`gap/*` in flight). |
| MKT-4-1, MKT-4-6, MKT-5-3, MKT-9-2 | Owner rulings (month-only plans, footer pill, pass-order cancel/refund, coupon confirm step). |
| MKT-8-2, MKT-10-2 | Copy alignment waits for owner confirmation, as the queue says (优惠券 vs 我的优惠券; 我发布的优惠券 / 还没有优惠券). |
| MKT-10-3 | Recorded as an accepted native-iOS deviation: the coupon detail stays a pushed page (system navigation, owner's native rule of 11-24) rather than a bottom sheet. |
| MKT-10-5 | Gemini; only matters after R7-MEM-10-1. |
| MKT-1-6/1-7, 2-7/2-8, 3-5, 4-7/4-8, 6-4/6-5, 7-4/7-8, 8-6, 9-7, 10-6/10-7 | Visual only, covered by `restyle/r1…r6` (skip rule). |
| MP-asset consistency | Done in Round 2 (see below). |

## Skipped because in flight
- `restyle/*` (visual), `cursor/*`, `gap/g1-player`, `gap/g2-ops`, `port/*`. `cursor/cb1142` must not be merged (r7 audit warning).

## Accessibility / native checks on pages 1–15
- Swept the page files for raw `.font(.…)`, icon-only buttons without labels, tap gestures on controls, and sub-44 pt targets. The only finding was MKT-9-3 (fixed). The remaining `onTapGesture` (reveal stage) is decorative and `accessibilityHidden`, with the real CTA a button.
- The new missing states use the system `ContentUnavailableView` (through `CYStateLayout`) with one 返回 button, so they get Dynamic Type and VoiceOver by default.

## Acceptance
- Fixture routes: `docs/port/accept/f-member-a.txt`.
- Run: pending. The coordinator compiles and sends back exact errors. Fixtures for the new missing-link states do not exist yet; they are reachable via `chein://mp/subpackageMember/market/gift/index` today, and via the other three paths once Cursor request 1 lands.

## Round 2 (2026-11-24)

Brief: `design/handoff-r2:docs/briefs/fix-r3-round2.md`, with `wave-x10.md` and `owner-decisions-1124.md`.

- **Sync.** Merged `origin/ui/combined-r7` (Core K1–K10, W1 wiring, C7 MP assets). One conflict, `tools/check_typography_lint.py`, was resolved in favour of r7; the lint passes. r7 was merged again before the final push.
- **No compiler in the cloud.** Every API used was grepped on r7 first: `MPAsset.Other.glassKey`, `MPAsset.BannerCover.routeCityCover`, `MPAsset.FeatureIcon.pin/dOrderIcon/dOrderIcon2`, `CYCachedAsyncImageRole.cover.aspectRatio`, `MoneyDisplay.yuan/plain/text/minimumFractionDigits/maximumFractionDigits`, `PlatformPassOverview.terms`, `PlatformPassTermFacts(period:renewal:refund:seat:coverage:)`, `CouponManagementCoordinator.publishListScope`, `CouponPublishListScope.player/.merchant`, `CYStateLayout(kind:title:primary:primaryIdentifier:)`, `InvoiceLaunchDetailView(model:applicationID:onSignIn:)`.

### Fixed in Round 2

| id | page | what changed | files |
|---|---|---|---|
| R7-MEM-10-1 (App half) | 10 coupon/coupon | The reviewed page link reads `scope`. `coupon/coupon?scope=MERCHANT` lists the shop's coupons and the bare link lists the player's own coupons (MP `coupon.js:101`). The merchant marketing entries keep `.merchant`. The scope is set on the coordinator before every `load()`, including pull to refresh | App/CouponManagementView.swift, App/SessionCouponManagementView.swift, App/MPReviewedPageScreen.swift |
| FIN-11-1 (App half) | 11 invoice | `subpackageMember/invoice/index?id=` mounts `InvoiceLaunchDetailView`. The bare path stays the history list | App/MPReviewedPageScreen.swift |
| MKT-4-3 (App half) | 4 membership | 购买须知 follows `platform-pass.js` `factRows`. 可玩主题 is the library count, else `terms.coverage`. 适用范围 shows `terms.seat`. 有效期 is `terms.period`, else the plan days. 续费 and 退款规则 use the server text when it was sent, else the fixed OR-024 lines | App/PassMembershipViews.swift, App/MPParityPassSession.swift, docs/port/strings/fix-r3-member-a.json (`mp.member.fact.seat`) |
| MKT-9-5 (App half) | 9 coupon-qr | The `.notMine` state gets the MP 返回 action (`coupon-qr/index.wxml:28`), using Cursor's `couponCode.notMine.back` key | App/CouponCodeView.swift |
| Owner decision 9 | 1, 2, 4, 5, 10, 11–15 | All money uses the shared `MoneyDisplay` rule (two decimals). Pass prices and plan prices used to drop `.00`: `MPParityBindings.yuan/yuanFixed/yuanFen` now go through `MoneyDisplay.yuan`. Server money text on pass orders and refunds (`¥12.5`) goes through `MoneyDisplay.text`. `invoiceAmount` reads `MoneyDisplay` fraction digits. The coupon settings amount uses `MoneyDisplay.plain` | App/MPParityPassSession.swift, App/PassMarketViews.swift, App/InvoiceLaunchPresentation.swift, App/CouponManagementView.swift |
| Fixture | 4 membership | `t5-membership` shows two-decimal prices and server terms (适用范围, server refund text, period) | App/DesignFixtures/DesignFixtureRegistry.swift |

### MP assets (mapping rows applied on pages 1–15)

- [x] `MPAsset.Other.glassKey` (`subpackageMember/market/membership/index.wxml:27`): the membership card draws the MP `cy-frames` sprite. The sheet is 6 × 4 cells, 24 frames at 10 fps, looping after a 500 ms delay. With Reduce Motion it holds frame 0, as cy-frames `still` does for `loop`. New view: `PassGlassKeyFrames` (App/PassMembershipViews.swift).
- [x] `MPAsset.BannerCover.routeCityCover` (`market/library/index.wxml:15`): a library card with no cover shows the MP default cover instead of the grey placeholder.
- [x] `MPAsset.FeatureIcon.pin` (`market/library/index.wxml:22`): the city tag icon on library cards replaces SF `mappin`, scaled with Dynamic Type.
- [x] `MPAsset.FeatureIcon.dOrderIcon` / `dOrderIcon2` (`invoice/index.wxml:40-41`): invoice history rows show the MP icons before 申请于 and before the issuer / N 笔订单 line, scaled with Dynamic Type.
- [x] `MPAsset.FeatureIcon.subpackageMemberImagesDClose` (`invoice-titles/index.wxml:27`): kept as SF `xmark`, as the mapping says (system close glyph).
- [x] `MPAsset.FeatureIcon.chevron` (`market/library/index.wxml:30`): kept as SF `chevron.right` (disclosure glyph).
- Not an asset: the MP 城 mark on library cards is text (`<text>城</text>`), and the app already draws it as text. `cy-icon` glyphs (coupon, gift, check, chevron-right) are CSS icon-font glyphs with no shipped image. `cy-illus name="seal"` on the membership library row is drawn by code (`subpackageMember/components/cy-illus/art.js`) and has no catalog asset, so SF `seal.fill` stays.
- Not on my pages: `MPAsset.Other.keyIntro*/keyIdle*` belong to `subpackagePass/reveal`. The reveal stage still uses `PassKeyEmblem` and should move to those frames in whichever half owns the reveal page. The `cy-empty` illustrations (`MPAsset.EmptyState.emptyStateBg/emptyStateFigure`) live in the shared `App/DesignSystem/CYStates.swift`, which is not a page file in this half.

### Review findings (step 4)

- `review/r7-rev-a`, `-b`, `-c`: there are no Claude-owned rows for pages 1–15. B-16 and B-21 are member pages 21+ (half b). B-13 and B-20 are Cursor's and closed in `cursor-core-member`. The F-C rows are Gemini's parked `App/MPGap` files.
- `audit/parity-r7-member` P1: every Claude P1 row is on pages 16–30 (half b). Pages 1–15 have no open Claude P1. The P0/P1 rows still open there belong to Gemini (MKT-7-1, MKT-7-3, MKT-10-1) or the owner (MKT-3-1, MKT-4-1, MKT-4-6, MKT-9-2).

### Owner decisions (step 5)

- 9 (two decimals): applied, see above.
- 3 / 6 / 12 (money stays TEST-only): no money write was added. Pass purchase, quote, order, claim and pass-order cancel / refund stay refused by `PlatformPassReadOnlyTransport`. MKT-5-3 is now ruled money, so it is TEST-only. Mounting it needs Gemini's parked sheet to compile, plus a TEST-only Core gate that defaults off. That is listed below for Cursor.
- 7, 8, 10 (cast fixtures, GPS arrival lock, pilot gate for game kits): not on member pages 1–15.

### Requests for Cursor (Round 2)

1. Still open from Round 1: set `required: []` on `MiniProgramPageLink` reviewedPages for `market/pass`, `market/pass-order` and `invoice-detail`. `coupon/coupon` must also accept the optional `scope` key, or external `?scope=MERCHANT` links are refused.
2. **R7-MEM-7-2:** the free-explore read has to surface `businessCode == "BUNDLE_LEDGER_OFF"` as its own error case, for example `.error(.ledgerOff)`. Today it is folded into `.error(.load)`, so the App cannot hide 刷新. The App change is small once that case exists.
3. **Two decimals in Core:** `PlatformPassSubscriptionOrder.yuanFen` (Core/PlatformPass.swift:707) and `PlatformPassNumber.plain` still trim `.00` / `.x0`. The App re-formats that text through `MoneyDisplay.text` for display, but Core should use `MoneyDisplay` directly. `CouponInfoAmount.displayText` should do the same.
4. **MKT-5-3:** add a TEST-only, default-off gate for pass-order cancel / refund-apply (owner decision 3), so the App can mount the sheet in TEST builds.

### Not touched (Cursor wiring)

- No `cursor/wire-*` branch on r7 touches the files changed here, and `cursor-core-member.md` asks the F-agent for exactly these App call sites (coupon scope, invoice `?id=`, membership terms, notMine). The ProfileOrders, TemplateAuthoring and TicketWallet items in that list are pages 16+ (half b).

### Still left (with reasons)

- R7-MEM-7-1 store 可用 / 暂不可用: waits for Cursor to decode `store.available` (Round 1 request 2).
- R7-MEM-7-2: Cursor request 2 above.
- MKT-3-1, MKT-4-1, MKT-4-6, MKT-9-2: owner rulings that are not in the 11-24 list.
- MKT-5-3: Cursor request 4, plus Gemini's parked sheet.
- MKT-7-1, MKT-7-3, MKT-10-1, MKT-10-5: Gemini (`gap/*`).

### Acceptance

- `docs/port/accept/f-member-a.txt`: no new routes; the existing ones now note what they cover. `t5-membership` covers the glass key and server terms, and `t5-library` covers the default cover and the pin, since both fixture cards have no cover. `e5-invoice-history` covers the order icons, and `member-popup-coupon-code` covers coupon-qr.
- Run: pending. The coordinator compiles and sends back exact errors.

## Round 3 (2026-11-24 evening)

Brief: `design/handoff-r2:docs/briefs/fix-r3-round3.md`. Base: `origin/ui/combined-r7` `b0ac0108d` (the merge was a fast-forward of this branch).

### Round 3 · re-applied

Every hunk of my round-1 and round-2 commits was checked against the new base (`git diff <c>^ <c> | git apply --check -R`, then by hand for the files that differed).

- **Nothing had to be re-applied.** `MPParityPassSession` was restored to my side, and none of my round-2 files were in the "Cursor side" list.
- **MKT-2-1 (pass 去报名 preselects the ticket):** my `preselectedTicketID` plumbing was replaced by Cursor's `ActivityDetailView(registrationTicketID:)` and the environment `registrationPreselectedTicketID`. The effect is present: `PassMarketViews.openActivitySignup` opens `pages/activity/baoming/baoming?activityId&ticketId`, and that route passes `positiveID(query["ticketId"])`. No second implementation was added.
- Still present as written: `MemberMissingLinkState` (pass, pass-order, gift, invoice-detail), the coupon-qr focus, the free-explore catalog facts, the invoice-titles banner, the coupon scope, `invoice/index?id=`, membership terms, two-decimal money, and the MP assets (glass key, default cover, pin, order icons).

### Fixed in Round 3

| id | page | what changed | files |
|---|---|---|---|
| MKT-10-1 / flows-g1 | 10 coupon/coupon | With `scope=MERCHANT`, the page reads `POST /api/merchant/coupon-summary` once (and on pull to refresh) and mounts Gemini's `MerchantCouponSummaryTilesView` (累计领取 / 累计核销) above the list. The reply is shaped by the MP rule (`coupon-summary.js`): `couponTotal` must be a positive integer and `received` / `verified` non-negative integers, else no tiles. A failed or stale read hides the tiles and never blocks the list | App/CouponPageSummary.swift (new), App/CouponManagementView.swift, App/SessionCouponManagementView.swift, App/CouponManagementFixtureSupport.swift |
| MKT-10-5 / flows-g1 | 10 coupon/coupon | The refused state keeps one CTA, as in MP `merchant-no-permission.js`: 返回 for a merchant member (merchant scope, or a merchant account), 申请入驻 (pushes `pages/merchant/apply/index`) for anyone else | App/CouponManagementView.swift, App/SessionCouponManagementView.swift |
| MKT-7-1 / flows-g1 | 7 free-explore `?topicId=` | The link used to open the topic page. It now reads the bundle catalog through `FreeExploreLaunchService.catalog(topicID:)` and mounts Gemini's `FreeExploreCatalogBundleView` (one row per store, `章节 · 每人N次`), with the topic name and 暂未开售 above it. 查看主题详情 pushes the topic. Signed out shows 请登录后查看 + 登录; a failed read shows 加载失败，请稍后重试 + 刷新, with 刷新 hidden on `BUNDLE_LEDGER_OFF` | App/FreeExploreTopicCatalogScreen.swift (new), App/MPReviewedPageScreen.swift |
| MKT-7-1 / flows-g1 | 7 free-explore `?requestId=` | The link used to open 我的订单. It now reads `GET /api/free-explore/bundle/order/receipt` (validated `requestId`, MP `^[A-Za-z0-9_-]{1,64}$`). A reply with the same `requestId` and `receipt == FOUND` lands on that order's detail, which hosts the bundle (what the MP does by switching to `registrationId`). Any other receipt shows 购买结果确认中，请稍后刷新; a failed or mismatched reply shows 购买结果暂时读不到，请刷新. Both have 刷新 | App/FreeExploreReceiptResolveScreen.swift (new), App/MPReviewedPageScreen.swift |
| free-explore missing param | 7 free-explore | No usable id is the MP `missing-param` state (链接已失效 + 返回) through `MemberMissingLinkState`, not a bare text | App/MPReviewedPageScreen.swift |
| R7-MEM-7-2 | 7 free-explore (bundle detail) | `FreeExploreBundleLaunchModel.failure` already keeps `.response(…, businessCode:)`, so the App hides 刷新 when it is `BUNDLE_LEDGER_OFF` (MP `featureOff`). Round 2 Cursor request 2 is no longer needed | App/FreeExploreBundleLaunchView.swift |

New strings in `docs/port/strings/fix-r3-member-a.json` (en + zh-Hans): `freeBundle.catalog.signIn`, `freeBundle.catalog.loadFailed`, `freeBundle.receipt.pending`, `freeBundle.receipt.unreadable`. Reused keys: `couponManagement.forbidden.applyMerchant`, `couponSummary.claimed/redeemed`, `bundle.catalog.*`, `bundle.receipt.title`, `mp.common.signIn`, `刷新`, `mp.common.linkExpired`, `action.back`.

APIs grepped on the new base before use: `MemberGapService(baseURL:token:transport:)`, `.fetchMerchantCouponSummary()`, `.fetchFreeExploreReceipt(requestID:)`, `PlayerGapReply`, `MerchantCouponSummary(totalClaimed:totalRedeemed:)`, `MerchantCouponSummaryTilesView(summary:)`, `FreeExploreCatalogBundleView(topicTitle:items:onOpenTopic:)`, `FreeExploreCatalogMerchantItem(id:merchantName:chapterName:perkSummary:)`, `FreeExploreLaunchSession(baseURL:accountID:market:namespace:role:epoch:token:)`, `FreeExploreLaunchService(session:transport:currentSession:)`, `FreeExploreLaunchFailure.response`, `AppSession.currentRuntimeDependencyContext/runtimeHTTPTransport`, `CYStateLayout` (memberwise order), `CYLoadingStateView(rows:)`, `ProfileOrderDetailView(id:reader:)`, `SessionTopicDetailView(id:session:)`. Both new paths are on the reviewed route list (`ChinaReviewedRouteCapability`). New files are under `App/*.swift`, which `tools/generate_project.py` already globs.

### Not mounted, with reasons
- **`CouponForbiddenPlayerActionView`** (Gemini): it shows 申请入驻 and 返回 together, but the MP shows exactly one CTA. The existing `CYStateLayout` deny state now switches its single CTA instead.
- **`FreeExploreBundleReceiptView`** (Gemini): `FreeExploreReceiptSummary` has no decoder, and the order detail already renders the bundle from the owned-order read. A second order renderer would duplicate that, so a found receipt lands on the order detail.

### MP assets (Round 3 rows)
- [x] `MPAsset.Other.keyIntro*/keyIdle*` (`subpackagePass/reveal/frames.js`, mapped to `App/PassMembershipViews.swift`): already applied on the base. `PassRevealStage` draws the MP frame sheets.
- Template-detail shelf tabs, leaderboard memojis (`GrowthLeaderboardView`) and member-journey icons (`PlayerJourneyViews`, mycanyu / participation detail) are not on member pages 1–15. They belong to other areas or to half b.

### Review / audit rows
- `review/r7-rev-a/b/c` and `audit/parity-r7-member` have no new commits since Round 2. The open Claude P1 rows (R7-MEM-17-1, FIN-18-2, R7-MEM-27-1) are pages 17, 18 and 27 (half b).
- flows-g2 `talent/list → market/passes` and `subpackagePass/reveal redirectTo ?` are not on my pages: talent list is another area, and reveal is not in pages 1–15.

### Requests for Cursor (Round 3)
1. Still open: `MiniProgramPageLink` reviewedPages `required: []` for `market/pass`, `market/pass-order` and `invoice-detail`, plus the optional `scope` key on `coupon/coupon`.
2. Still open: `FreeExploreLaunchCatalog.Item.Store.available`, for 可用 / 暂不可用 per store (MP `index.wxml:22`). The catalog screen shows store names only until then.
3. `MerchantCouponSummary.fromWire` reads `totalClaimed/claimedCount`, but the MP contract is `{couponTotal, received, verified}` with the `couponTotal > 0` gate. The App uses its own `CouponPageSummary.shape` until Core is fixed.
4. Still open: Core two decimals (`PlatformPassSubscriptionOrder.yuanFen`, `PlatformPassNumber.plain`, `CouponInfoAmount.displayText`), and the TEST-only, default-off gate for MKT-5-3.
5. `FreeExploreLaunchFailure.response` drops the server `msg`. The MP shows `res.msg` first on catalog, receipt and order read failures; the App shows the fixed fallback copy.
6. `FreeExploreLaunchService.catalog` rejects a catalog where any `unitsPerHolder` is 0. The MP shows such a chapter with 次数待确认.

### Still left
- MKT-3-1, MKT-4-1, MKT-4-6, MKT-9-2, MKT-8-2, MKT-10-2: owner rulings.
- MKT-5-3: needs Cursor request 4.
- Fixture routes for the two new free-explore screens: they read the live session, and adding one needs an injectable transport. They are reachable by `chein://` link on a signed-in build.

### Checks
- `tools/check_typography_lint.py` and `tools/check_design_lint.py` pass.
- `tools/check_a11y_lint.py` fails with the same 17 findings with and without this round's changes. They are pre-existing and none is in my files.
- `tools/check_missing_string_keys.py` lists only this round's four new keys, which are in the fragment file.
- No compiler in the cloud; the coordinator's build is the first real check.

## Round 4 (2026-11-25)

Brief: `design/handoff-r2:docs/briefs/fix-r3-round4.md`, with `wave-x10.md` and `owner-decisions-1124.md`. Base: `origin/ui/combined-r7` `4ef0a2840` merged into this branch (clean). Gemini is out of quota, so this round also covers Gemini's MP-alignment work for pages 1–15.

APIs grepped on the base before use: `ChannelRedeemSource(configuration:transport:)`, `.redeem(code:token:)`, `ChannelRedeemEnvelope.ok/confirmed/reasonCode/dataJSON`, `ChannelRedeemRefusal.invalidRequest/notAdmitted`, `APIConfiguration(baseURL:)`, `AuthRequestBuilder.isValidToken`, `AppSession.token/currentRuntimeDependencyContext/composition.makeTransport()`, `CYMorphButton(_:state:action:)`, `CYPillButton(_:action:)`, `SessionTopicDetailView(id:session:)`, `MPParityDestination(route:)`, `MPAsset.BrandLogo.cyLogoMark`, `MPAsset.EmptyState.noData`, `CYEmptyIllustration.kind(matching:)` (`"tray"` → MP empty art), `CYStateKind.generic`, `MemberMissingLinkState(identifier:)`, `QuestifyMetadataLine(label:value:systemImage:)`. New names (`PassRedeemCodeView`, `PassRedeemCodeOutcome`, `PassSealMark`, `CouponQRLogoMark`, `CouponQRRenderFailed`, `MPParityRoute.passRedeemCode`, `MPParityBindings.passRedeemEnabled`) were grepped first and are not declared elsewhere. The new file is `App/PassRedeemCodeView.swift`, which `tools/generate_project.py` already globs.

### 1. Flows (flows-g1 / flows-g2 edges for pages 1–15)

Every `navigateTo` / `redirectTo` / `navigateBack` / `switchTab` in `market/*`, `free-explore`, `coupon*`, `invoice*` was listed from the MP and checked against the app.

| edge | MP | app | status |
|---|---|---|---|
| flows-g1 free-explore `?topicId=` / `?requestId=` | catalog / receipt | `FreeExploreTopicCatalogScreen` / `FreeExploreReceiptResolveScreen` (round 3) | OK |
| flows-g1 coupon/coupon forbidden CTA + summary tiles | `merchant/apply`, tiles | round 3 (`denyAction`, `CouponPageSummary`) | OK |
| flows-g2 `talent/list:122 → market/passes` (MISSING-ROUTE for Claude) | `goStore` | Already present: `MPPassExploreCard` (`App/MPPassEntries.swift:42`) pushes `MPParityDestination(route: .passes(tab: .shop))`. The audit tool missed the App mount | OK, no change |
| passes `goRedeem` → `gift?mode=code` | 兑换码 row | **was missing**. Added (see 4) | fixed |
| passes → gift / reveal / points-history / pass / pass-order / library | navigateTo | `PassMarketHost` routes | OK |
| membership → pass-order / reveal / topic / library | navigateTo / redirectTo | `PassMembershipViews` routes | OK |
| pass → seats / passes?tab=orders / baoming / passes?tab=gifts | redirectTo / navigateTo | round 1–3 | OK |
| pass-order → im/list (联系城瘾小助手) | navigateTo | `PassOrderDetailView` → `MPReviewedPageScreen("subpackageB/pages/im/list/index")` | OK |
| gift (claim) → orderinfo / passes?tab=gifts; code mode → topic / library | redirectTo | claim: round 2; code mode: `PassRedeemCodeView.play()` | OK |
| coupon-qr back → member tab | navigateBack / reLaunch | system back; missing link has 返回 | OK |
| invoice list → apply / detail / titles → title-edit; after save back | navigateTo / navigateBack | `InvoiceLaunch*` | OK |
| all pages: back with no stack → member tab | switchTab | system back (pushed) / 返回 on deep-link sheets | OK |

### 2. Image parity (MP image slots on pages 1–15)

| page | MP slot | MP source | app | status |
|---|---|---|---|---|
| 1 passes | empty (shop / orders / gifts) | `cy-empty kind="empty"` → `/images/empty_state_bg.svg` + `empty_state_figure.svg` | `CYEmptyState(systemImage: "tray")` → `MPAsset.EmptyState.emptyStateBg/Figure` | **fixed** (was ticket / doc / gift art) |
| 1 passes | 通行证 member card | text only (`mk-member`) | SF `key.fill` emblem removed | **fixed** |
| 1 passes | row chevrons, error | `cy-icon chevron-right`, `cy-error` glyph | SF `chevron.right`, `exclamationmark` | system glyph |
| 2 pass | hero seal | `cy-pass-object` `po__mark` `/images/cy_logo_mark.png` (sepia, dark gold) | `PassSealMark` (`MPAsset.BrandLogo.cyLogoMark` template, ember tint, gold disc + ring) | **fixed** (was SF `key.fill`) |
| 2 pass | unlock dial core | `cy-pass-unlock` `pu__core-mark` `/images/cy_logo_mark.png` | `PassUnlockStepsView` uses `PassTicketHero` → `PassSealMark` | **fixed** |
| 3 gift | hero icon | `cy-icon gift` / `check` (icon font) | SF `gift.fill` / `checkmark` | system glyph |
| 3 gift | missing link | `cy-empty kind="missing-param"` → glyph `info` | `MemberMissingLinkState` (SF) | system glyph |
| 4 membership | glass key | `cy-frames` `/subpackageMember/images/frames/glass-key.webp` | `MPAsset.Other.glassKey` (round 2) | OK |
| 4 membership | library row seal | `cy-illus name="seal"` (SVG drawn in `art.js`, no catalog file) | SF `seal.fill` | no asset to map |
| 4 membership | merchant / off states | `cy-empty kind="empty"` art | `"tray"` → MP art | **fixed** (was SF key) |
| 5 pass-order | missing / error | `missing-param` / `cy-error` glyphs | SF | system glyph |
| 6 library | cover default | `/images/route_city_cover.png` | `MPAsset.BannerCover.routeCityCover` (round 2) | OK |
| 6 library | city pin | `/images/cards/pin.svg` | `MPAsset.FeatureIcon.pin` (round 2) | OK |
| 6 library | chevron | `/images/cards/chevron.svg` | SF `chevron.right` (mapping: disclosure glyph) | system glyph |
| 6 library | empty | `cy-empty kind="empty"` art | `"tray"` → MP art | **fixed** (was SF map) |
| 7 free-explore | missing / legacy / reservations empty | `missing-param` glyph; `kind="empty"` art | `MemberMissingLinkState`; bundle empty already `"tray"` | OK |
| 8 coupon-wallet | empty / filtered empty | `cy-empty kind="empty"` art | `"tray"`, `.generic` → MP art | **fixed** (was ticket / filter art) |
| 8 coupon-wallet | shop pin, row arrow | `cy-icon pin` / `arrow-right` (icon font) | SF | system glyph |
| 9 coupon-qr | QR centre mark | `cy-qr-voucher` `qr__logo` `/images/cy_logo_mark.png`, `brightness(0)` on a white disc | `CouponQRLogoMark` (`cyLogoMark` black template, 48 pt white disc). Local QR error correction raised M → H for the covered centre | **fixed** |
| 9 coupon-qr | QR error | `/images/no_data.svg` + 二维码未加载 | `CouponQRRenderFailed` (`MPAsset.EmptyState.noData`) | **fixed** (was text only) |
| 9 coupon-qr | used check | `cy-icon check` | SF `checkmark.circle` | system glyph |
| 10 coupon | empty | `cy-empty kind="empty"` art | `"tray"` → MP art | **fixed** |
| 10 coupon | detail icon | `cy-icon coupon` (icon font) | none on a pushed page | system glyph slot |
| 11 invoice | row icons | `/subpackageMember/images/d_orderIcon.png`, `d_orderIcon2.png` | `MPAsset.FeatureIcon.dOrderIcon/dOrderIcon2` (round 2) | OK |
| 11 invoice | empty | `kind="empty"` art | `"tray"` → MP art | **fixed** |
| 12 invoice-detail | missing / login / off | glyphs | SF via `CYStateLayout` | system glyph |
| 13 invoice-apply | title chevron | `cy-icon arrow-right` | SF | system glyph |
| 13 invoice-apply | no-titles sheet empty | `kind="empty"` art | `"tray"` → MP art | **fixed** |
| 14 invoice-titles | delete | `/subpackageMember/images/d_close.png` | SF `xmark` (mapping: system close glyph) | system glyph |
| 14 invoice-titles | empty | `kind="empty"` art | `"tray"` → MP art | **fixed** |
| 15 invoice-title-edit | — | no image slot | — | — |

### 3. Copy (zh-Hans = MP)

A script compared each zh-Hans value used by the page files (Localizable + the `InvoiceLaunchUI` / `FreeExploreBundleLaunch` tables + all fragments) with the Chinese text of the matching MP wxml/js/json. Changed:

| key | was | now (MP) | MP source |
|---|---|---|---|
| `mp.member.plan.month` | 月卡 · 随时停 | 30天·不自动续费 | `utils/platform-pass.js:80` |
| `mp.member.buy.device` | 当前设备暂不可开通 | 当前设备暂不支持开通 | `platform-pass.js:68` |
| `mp.member.buy.renew` | 续期通行证 | 续买30天 | `platform-pass.js:138` |
| `mp.reveal.linePaid %@` | 到 %@ · 价格都是 ¥0 | 到 %@ | `subpackagePass/reveal/index.js:100` |
| `accountCollection.coupons.title` (MKT-8-2) | 我的优惠券 | 优惠券 | `coupon-wallet/index.json:3` |
| `accountCollection.coupon.validUntil` | 截止日期 | 有效期至 | `scene-game-coupon-wallet/index.js:49` |
| `accountCollection.coupon.startsLater` | 尚未到使用日期 | 还没到可用时间 | `coupon-qr/index.wxml:48` |
| `couponCode.show` | 出示券码 | 出示核销码 | `scene-game-coupon-wallet/index.wxml:16` |
| new `couponWallet.validFrom %@` / `.validUntil %@` | (date only) | %@ 起可用 / 有效期至 %@ | `scene-game-coupon-wallet/index.js:48-49`, `coupon-qr/index.wxml:49` |
| `couponCode.title` | 优惠券码 | 优惠券出示 | `coupon-qr/index.json` |
| `couponCode.renderFailed` | 券码暂时无法显示，请更新后再出示。 | 二维码未加载 | `coupon-qr/index.wxml:66` |
| `couponCode.waiting` | 此优惠券尚未到可使用时间。 | 还没到可用时间 | `coupon-qr/index.wxml:48` |
| `couponCode.expired` / `.invalid` | 优惠券已过期 / 优惠券已失效 | 该券已过期 / 该券已失效 | `coupon-qr/index.wxml:98,102` |
| `couponCode.unavailable` | 此优惠券已不可用。 | 优惠券已撤销或不存在 | `coupon-qr/index.js:292` |
| `couponCode.serviceDisabled` (+ `.detail`) | 优惠券出示码暂未开放 | 优惠券出示码暂不可用（，请联系管理员） | `coupon-qr/index.js:301` |
| `couponCode.login` | 请重新登录后出示此优惠券。 | 登录已过期，请重新进入 | `coupon-qr/index.js:149` |
| `couponCode.pollDelayed` | 核销状态暂时更新延迟，稍后会再次检查。 | 核销状态暂未更新 | `coupon-qr/index.wxml:77` |
| `couponManagement.title` (MKT-10-2) | 我发布的券 | 我发布的优惠券 | `coupon/coupon.json` |
| `couponManagement.empty` (MKT-10-2) | 暂无已发布优惠券 | 还没有优惠券 | `coupon.wxml:42` |
| `couponManagement.remaining` | 库存 | 库存数 | `coupon.wxml:34` |
| `couponManagement.stopPolicy` | 停发不可撤销。停发后不能再被领取、发放；… | 停发后不可领取，已领券仍可用 | `coupon.wxml:69` |
| `couponManagement.reviewStop` | 确认停发 | 停发该券 | `coupon.wxml:68` |
| `InvoiceLaunchUI` `taxInvalid` | 请填写完整税号：15～20 位数字或大写字母，不能使用掩码 | 请重新填写完整税号，不能使用掩码 | `utils/user-invoice.js:53` |
| `InvoiceLaunchUI` `invoiceNo` | 发票号码 | 发票号 | `invoice-detail/index.wxml:42` |
| `FreeExploreBundleLaunch` `legacy` | 此记录没有套票账本，仅可查看。 | 这笔订单没有套票权益 | `free-explore/index.wxml:37` |
| `FreeExploreBundleLaunch` `unknown` | 原预约结果尚未确定，回读核实前不能新建预约。 | 预约结果确认中 | `free-explore/index.wxml:62` |
| new `mp.redeem.*` (11 keys) | — | 兑换码 / 输入兑换码 / 兑换 / 兑换成功 / 你已兑换过这个码 / 去玩 / 兑换码无效 / 兑换码已过期 / 兑换码已被他人使用 / 该兑换码不属于当前账号 / 兑换码暂不可用 | `market/gift/index.{wxml,js}` |

Code-side copy changes: the title-edit page title is 发票抬头 for new and edit (`invoice-title-edit/index.wxml:8`, was 新增抬头 / 编辑抬头); the apply page title row reads 选择发票抬头 to VoiceOver (`invoice-apply/index.wxml:16`); the no-orders section lost its 订单明细 header (MP shows only 暂无可开票订单); the wallet empty states lost the two detail lines the MP does not have; the coupon-qr missing link is the MP 链接已失效 · 返回 (`MemberMissingLinkState`) instead of 缺少券信息.

Fragment: `docs/port/strings/fix-r3-member-a.json` (Localizable keys, en + zh-Hans). Table keys (`InvoiceLaunchUI`, `FreeExploreBundleLaunch`) cannot be overridden by a Localizable fragment, so those four values were edited in place in `Resources/*.xcstrings` (one line each). `tools/check_missing_string_keys.py` lists only the new keys, which are all in the fragment.

Kept, with reasons: app-only safety lines with no MP counterpart (`couponCode.authority`, `couponCode.paused`, `couponCode.stale`, `couponManagement.chinaTime`, the TEST-only gate notes `mp.gate.*`, `mp.passOrder.gated`); `mp.member.plan.year` (the MP sells month only, MKT-4-1 owner ruling); `mp.member.toLibrary` on the active footer (MKT-4-6 owner ruling; MP shows 续买30天 there); free-explore reservation / swap / review copy belongs to MP features the app does not have (MKT-7-3, Gemini).

### 4. P2 / P1 rows

- All Claude P2 rows for pages 1–15 in `audit/parity-r7-member` were closed in rounds 1–3, except MKT-8-2 and MKT-10-2, which waited on copy. The round-4 brief says copy must equal the MP, so both are now closed (see 3).
- MKT-10-3 (detail as a sheet) stays the recorded native-iOS deviation.
- New gap found and fixed: **passes 兑换码 / `gift?mode=code`** (MP `passes/index.wxml:47`, `gift/index.js:35-98`). `PassRedeemCodeView` posts through the existing `ChannelRedeemSource` (no money; the body holds only `code` + `requestId`), keeps one source per code so a network-unknown retry resends the same request id, maps the MP six results, and 去玩 opens the one topic or the theme library. The row shows only for a signed-in player when `MPParityBindings.passRedeemEnabled` returns true; that binding is nil by default, so the feature is off until Cursor wires the status read (request 1 below). The route `MPParityRoute.passRedeemCode` comes from `gift/index?mode=code`.
- No open P1 on pages 1–15 (the open member P1s are pages 16–30, half b).

### 5. Accessibility lint

`python3 -B tools/check_a11y_lint.py` was failing on the base with 1 finding outside this area (`App/ClubKit/ClubWorkbenchKit.swift:261`, the club share glyph). The glyph sits inside a `ShareLink` / button that already carries `r4club.header.share`, so it now has `.accessibilityHidden(true)` (after the frame / content-shape modifiers). The lint is at **0**. Typography and design lints pass.

### Requests for Cursor (Round 4)
1. **Redeem status read:** `GET /api/channel/redeem/status` → `data.platformCodeEnabled === true` (signed-in only; closed or unreadable is false). Fill `MPParityBindings.passRedeemEnabled` with it at the player root (`MPParityPassSession`).
2. **`MiniProgramPageLink` gift/index:** allow `mode` (value `code`) so external links open the redeem page.
3. `ChannelRedeemSource.presentation` decodes an OTA receipt; the platform code reply is `{topicIds, replayed}`. The App decodes those two fields itself (`PassRedeemCodeOutcome.from`); a Core decoder would be cleaner.
4. Still open from Round 3: reviewedPages `required: []` for `market/pass`, `market/pass-order`, `invoice-detail` plus `scope` on `coupon/coupon`; `FreeExploreLaunchCatalog.Item.Store.available`; `MerchantCouponSummary.fromWire` shape; Core two decimals; MKT-5-3 TEST-only gate; `FreeExploreLaunchFailure.response` message; zero `unitsPerHolder`.

### Tests to check (Cursor / coordinator)
- `Tests/AppUITests/AccountCollectionFlowTests.swift:190-214` reads `accountCollection.coupon.futureStart`; the element and its en text (Not yet started) are unchanged, only zh-Hans moved to 还没到可用时间.
- Any snapshot of `couponCode.missing` should now expect the 链接已失效 · 返回 state.

### Still left
- MKT-3-1, MKT-4-1, MKT-4-6, MKT-9-2: owner rulings. MKT-5-3: Cursor gate. MKT-7-3 (free-explore reservation / swap / reviews / refund quote): Gemini feature.
- 首发价 ¥39 on the month plan card (`platform-pass.js:85`) waits on MKT-4-1.

### Checks
- `tools/check_a11y_lint.py` 0, `tools/check_typography_lint.py` PASS, `tools/check_design_lint.py` PASS.
- No compiler in the cloud; the coordinator's build is the first real check.
