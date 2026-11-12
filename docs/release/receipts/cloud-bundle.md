# Cloud bundle (U4 / L7)

Branch `ui/cloud-bundle` from `ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`.

The existing bundle screens are mounted from the order detail, behind the free-explore read capability and `ChinaReviewedRouteCapability`. Nothing here redesigns those screens. `App/RegionalLaunchConfiguration.swift` grants are unchanged. `ReleaseMoneyWriteSwitch` stays off for payment, payout, withdrawal, and virtual goods. The shipped read approval still returns nil, so the hub is absent until a reviewed approval exists.

`python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` passed on this tree. This machine has no Swift compiler, so these screens were not built in Xcode.

## Entry → native file

| Entry | Native file | What is mounted | Hidden on China production |
|---|---|---|---|
| Shelf | `App/BundleShelfView.swift` | `UnavailableBundleShelfClient`, `onSelect` nil. No cards and no purchase. | Yes. `/api/free-explore/bundle/shelf` is not offered. |
| Order → status | `App/BundleOrderStatusView.swift` via `App/BundleCommerceMount.swift` | The order already read by `FreeExploreBundleReadHost`. No receipt poller. An unknown reservation stays on `recover()` of the saved request id and shows —. | No, when the read capability is on. |
| Voucher | `App/BundleVoucherView.swift` | `UnavailableBundleVoucherClient`. No sample codes. | Yes. `/api/free-explore/bundle/voucher` is not offered. |
| Refund quote | `App/BundleRefundQuoteView.swift` | One GET of `order/refund-quote` through `BundleCommerceReadTransport`. The quote view has no apply button. Amounts stay the server text; a blank value is —. | No, when the read capability is on. |
| Cancel | `App/BundleCancelView.swift`, `App/BundleCancelCanceler.swift` | Cancel-quote GET only. `writeAllowed` is false and the transport has no cancel POST, so confirm cannot report a cancelled reservation. | No, when the read capability is on. |
| Transfer | `App/BundleTransferSendView.swift`, `App/BundleTransferClaimView.swift` | `BundleTransferUnavailableClient` and a separate in-memory pending store for send and for claim. | Yes. `/api/free-explore/bundle/transfer` is missing. |
| Review | `App/BundleReviewListView.swift`, `App/BundleReviewComposeView.swift` | `UnavailableBundleReviewClient`. Compose keeps no pending store. | Yes. `/api/free-explore/bundle/review` is not offered. |
| Renewal | `App/BundleRenewalIntentView.swift` | `BundleRenewalUnavailableService`. `permitsWrites` stays false. Intent only, no price and no charge. | Yes. `/api/free-explore/bundle/renewal-intent` is not offered. |
| Appeal | `App/BundleAppealView.swift` | `UnavailableBundleAppealService` and an in-memory pending store. A disabled call cannot clear a production command. | Yes. `/api/free-explore/bundle/voucher/appeal` is missing. |

On a non-China base URL, with the read capability on, all nine entries are listed. A nil base URL, or a capability that is off, lists none. The order-detail row is omitted in that case.

## Money actions that stay hidden

These stay unmounted and are not granted by this change:

- Payment: `App/BundlePayResultView.swift`, `App/BundleDetailView.swift` (its purchase bar only exists when `onPurchase` is set), and `App/BundleOrderSummarySheet.swift`.
- Refund apply. The quote screen is read-only.
- Cancel POST. The quote can be read. The write is not sent.
- Payout and withdrawal. `WalletPayoutCapability` is untouched. No withdrawal screen is mounted.
- Virtual goods. No cart, product, or pay route is mounted.
- `App/BundleWalletView.swift`, `App/BundleRedeemResultView.swift`, `App/BundleMerchantStallView.swift`, and `App/BundleReserveWindowView.swift` stay unmounted.

Unknown results use — and stay on the saved request id. A write is never reported as successful unless the server says so. These mounts do not invent that success: the write clients are the unavailable ones, or `writeAllowed` is false.

Copy on the new hub is English and zh-Hans. Loading, empty, error, permission, and offline states are on the new screens. Each of those screens keeps one inline navigation title, and at most one primary button. No new sheet is presented.
