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
| MP-asset consistency | `cursor/mp-assets` does not exist yet, so there are no `MPAsset` accessors or `docs/mp-assets/mapping.md`. The 城 mark on library cards (`PassMembershipViews` `mp.library.cityMark`) and the `PassKeyEmblem` should move to MP assets when that branch lands. |

## Skipped because in flight
- `restyle/*` (visual), `cursor/*`, `gap/g1-player`, `gap/g2-ops`, `port/*`. `cursor/cb1142` must not be merged (r7 audit warning).

## Accessibility / native checks on pages 1–15
- Swept the page files for raw `.font(.…)`, icon-only buttons without labels, tap gestures on controls, and sub-44 pt targets. The only finding was MKT-9-3 (fixed). The remaining `onTapGesture` (reveal stage) is decorative and `accessibilityHidden`, with the real CTA a button.
- The new missing states use the system `ContentUnavailableView` (through `CYStateLayout`) with one 返回 button, so they get Dynamic Type and VoiceOver by default.

## Acceptance
- Fixture routes: `docs/port/accept/f-member-a.txt`.
- Run: pending. The coordinator compiles and sends back exact errors. Fixtures for the new missing-link states do not exist yet; they are reachable via `chein://mp/subpackageMember/market/gift/index` today, and via the other three paths once Cursor request 1 lands.
