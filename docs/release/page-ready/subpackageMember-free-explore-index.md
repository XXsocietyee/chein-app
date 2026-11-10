# CB283 page-ready — `subpackageMember/free-explore/index`

自由探索权益包购买与退订. Native screen `App/FreeExploreBundleLaunchView.swift`. Map status on `rc/20261108`: partial. This pass does not change that status.

Base `rc/20261108` (`e8299803711abd007e33731bdd534c40d6536ea2`). Branch `cursor/cb283`. Core and tests only. Views, ui-strings JSON, `Resources/*.xcstrings`, the Xcode project, and `tools/current_ci_manifest.json` were not edited. No route was added and none was marked live. Payment, payout, withdrawal, and virtual goods stay off (`ReleaseMoneyWriteSwitch` is unchanged). `WelcomeView.showsMerchantChoice` stays `false`. This page is not on the player-first entry. Welcome, home, and the account tab do not name it. The existing order-detail row (`FreeExploreBundleReadEntry`) is unchanged.

`swift` is not on this machine. No Swift run is claimed. `xcodebuild` was not run. Existing free-explore tests were not deleted or weakened.

## What rc already had

- Catalog, order, reservation receipt, and refund-quote reads in `Core/FreeExploreLaunchService.swift`. Reservation dispatch defaults off. `cancellationQuote` still throws `cancellationQuoteUnavailable` and does not send HTTP.
- `FreeExploreLaunchCoordinator` states `idle`, `loading`, `outcomeUnknown`, `confirmed`, `staleSession`, plus `readRefundQuote`. A quote is cleared when a reservation outcome is unknown.
- `FreeExploreBundleLaunchModel` loads catalog and order, recovers an unknown reservation with GET only, and does not call `readRefundQuote`. The launch view already shows loading, error, unknown, and an empty catalog. It does not show a price or a refund amount.
- `BundleRefundQuotePresentation` still passes the server amount through verbatim, including a literal `0.00`. `BundleDetailContent.showsPurchase` is still the server `saleEnabled` flag. Neither type was changed. The detail and quote views are not mounted.
- `GatedFreeExploreReservationCanceler` still returns `.unavailable`. Cancel and refund apply stay off.

## What this pass adds

`FreeExploreBundlePageReady` classifies one read of the existing catalog, order, and refund-quote contracts:

| State | When |
|---|---|
| `loading` | A read is in flight and no record is kept. A refresh over a kept record stays `ready` with `refreshing`. |
| `empty` | The link has no topic and no registration, or the finished read has no catalog items, no order, and no quote. Not an error and not a zero price. |
| `error(.load)` | The read failed and nothing is kept. |
| `error(.stale)` | The session is no longer current. The previous amount is not kept on screen. |
| `unknown` | Nothing has arrived yet, or the original reservation result is not known. A kept price does not turn this into a settled amount. |
| `ready` | A catalog item, an order, a quote, or a literal amount is present. A later failure keeps that amount (`refreshFailed`) instead of substituting `0`. |

Unknown money uses `—` (U+2014). A literal `0` stays `"0"`. A literal `"0.00"` stays `"0.00"`. A blank, `UNKNOWN`, a minus sign, or a missing amount is `—`, never `0`. A JSON `null` amount still fails `FreeExploreLaunchRefundQuote` decode. A missing catalog leaves `saleEnabled` nil; it is not stored as `false`. A literal `saleEnabled == false` stays false. A legacy order (`bundle == nil`) is a record, not an empty shelf, and its missing amounts stay `—`.

`showsPage` is false for a nil base and for `playerFirstEntry: true`. `showsPurchase` and `showsUnsubscribe` are false even when the page is shown and the server says the bundle is on sale. Those functions do not create a grant and do not flip `ReleaseMoneyWriteSwitch`.

## Missing catalog keys

The launch view's keys (`title`, `stale`, `loading`, `error`, `unknown`, `recover`, `retry`, `empty`, `catalog`, `order`, `choose`, `unit`, `offer`, `date`, `review`, `legacy`, `disabled`, `confirmed`, `notice`, `confirm`, `cancel`) are already translated in `Resources/FreeExploreBundleLaunch.xcstrings`. The catalog was not edited.

These two keys are absent from every `Resources/*.xcstrings` table. No source string was copied: the mini-program checkout has no `subpackageMember/free-explore/index` page to quote.

| Key | What the row is | Nearby key that was not reused |
|---|---|---|
| `freeExploreBundle.paidAmount` | Label for the server paid amount on this page. | `merchant.order.amount` ("Paid amount" / "实付金额") is the merchant order row. |
| `freeExploreBundle.saleUnknown` | The catalog did not arrive, so the sale flag is unknown. | `detail.notOnSale` ("This bundle is not on sale right now." / "该套餐当前不在售。") is only `saleEnabled == false`. |

Already translated on other tables, and not copied onto the launch table: `detail.price`, `detail.purchase`, and `detail.notOnSale` in `BundleCommerce.xcstrings`; `amountLabel`, `remainingValueLabel`, `totalValueLabel`, `remainingRatioLabel`, and `quoteOnlyNotice` in `BundleRefundQuote.xcstrings`. `detail.purchase` stays unused by this model.

## Left

- `FreeExploreBundleLaunchView` still draws loading, error, unknown, and empty catalog copy on its own. It does not read `FreeExploreBundlePageReady`. A nil price is omitted there, not drawn as `—`.
- `FreeExploreBundleLaunchModel` still does not call `readRefundQuote`.
- `BundleDetailView` still shows a purchase button when the caller passes `onPurchase` and `saleEnabled` is true. That view is not mounted. This model does not turn that button on.
- `BundleRefundQuoteView` still shows the server amount verbatim and has no apply button. It is not mounted.
- The two keys above are absent from the catalog.
- Reservation dispatch, cancel, refund apply, payment, payout, withdrawal, and virtual goods stay off. Map status stays partial.
- No simulator pass and no `xcodebuild`.
