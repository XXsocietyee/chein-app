# IWP-2 new strings (table `BundleCommerce`, zh-Hans + en) — requested, NOT added

Builders may not edit `Resources/`. The orchestrator adds these to `Resources/BundleCommerce.xcstrings` (IWP-L).
Views reference them as `Text(LocalizedStringKey(key), tableName: "BundleCommerce")`. Unknown server statuses are shown verbatim, so no catch-all keys are needed.
Copy rule: nothing may say "paid"/"已支付"; `activation.active` must read as the server-reported state (e.g. "Active" / "已生效").

| Key | Meaning / constraint |
|---|---|
| `order.number` | label for the registration id |
| `order.status` | label for the activation line |
| `order.legacy` | order has no bundle ledger; points to the existing order screen |
| `activation.pending` | server status pair is not the active pair (do not claim unpaid/paid) |
| `activation.active` | server reported active |
| `activation.expired` | every balance flagged expired by the server |
| `activation.refunded` | every unit REFUNDED per server |
| `activation.unknown` | status missing from response |
| `order.receipt.confirming` | "Confirming your order…" (receipt polling) |
| `order.receipt.stillConfirming` | still unconfirmed after retries; must NOT say failed or "no order was created" |
| `order.receipt.failed` | definite non-retryable read error |
| `order.receipt.unavailable` | read could not be completed |
| `order.receipt.recheck` | button: check again |
| `wallet.noDetail` | per-order balance detail not available |
| `wallet.unitsTotal`, `wallet.validFrom`, `wallet.validTo`, `wallet.expired`, `wallet.entries` | wallet labels |
| `unit.status.{AVAILABLE,RESERVED,REDEEMED,FORFEITED,HELD,REFUND_PENDING,REFUNDED}` | unit status copy |
| `reservation.status.{BOOKED,CANCELLED,WAIVED,LATE_CANCELLED,NO_SHOW,FULFILLED,MERCHANT_EXITED}` | reservation status copy |
| `reservations.empty` | no reservations yet |
