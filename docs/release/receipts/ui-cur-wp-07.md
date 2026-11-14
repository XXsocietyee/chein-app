# ui/cur-wp-07

HANDOVER 36, WP-07 commerce. Parent `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46` (`origin/ui/main`). Implementation commit `4a3fbac20067322b24c53a0d5850c0358726baea`. The branch tip is the commit that records this line. The WP-07 section was read from `e1969026e9469669e165937013e0e4f5c61b4252` (`docs/completeness-2`). That commit is not the base.

`docs/release/completeness-matrix.csv` is not on `ui/main`. Row status is only in this receipt. The matrix was not imported.

`App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` are unchanged. `ReviewedAreaSwitch` is not redeclared. `docs/release/contract-failing-baseline.txt` is unchanged. `wiredPatternCount` stays 677. `missingCount` stays 204.

Money, payout, and merchant writes still go through `ReviewedAreaSwitch.moneyPayments` / `payout` / `merchantWrites` and stay closed on `www.chengyinhub.com`. Create and activate are payment kinds. They are listed in both grants and stay refused. No card fields. A digital-good charge stays on StoreKit; the client throws `WP07CommerceRefusal.closed` and does not send.

`swiftc` is not on this machine. `swiftc -parse` did not run. No typecheck was invented. `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` passed.

## Screens

Group and school product detail (`PassProductKind` 5 and 6) quotes `POST /api/marketing/group-checkout/quote`. The panel shows loading, empty, error with retry, the server tier, and `quote.payAmount`. Catalog cash is not the total. Unknown is an em dash. Create stays behind `MPCommerceGate` (purchases stay off).

Activation is on the same product page. A missing topic is the empty state. The closed sentence is visible. Activate does not call the network.

Registration (`RegistrationSheetView`) shows coupon usability from `POST /api/coupon/usability`: loading, empty, error with retry, and a read-only list. `couponDeductYuan` on that section is 0. Unknown reasons render as an em dash. The existing registration quote deduction is unchanged.

Copy is in `Resources/WP07Commerce.xcstrings` (`en` and `zh-Hans`).

## Grants

Both `ReviewedProductionGateLeases.wp07CommercePaths` (on the play grant) and `ChinaReviewedRouteCapability.wp07CommerceOwnerGrant` list:

- `/api/marketing/group-checkout/quote`
- `/api/marketing/group-checkout/create`
- `/api/marketing/product/activate`
- `/api/coupon/usability`

`admitsChinaProductionCall` is true for quote and usability. It is false for create and activate. The player lease accepts a quote body of product id and quantity and an empty usability POST. A price, amount, or card is refused. Create and activate are refused while purchases and money payments are off.

## Rows

`docs/release/completeness-matrix.csv` is absent, so status is here.

Done:

- `OWN-17.1` — activate is on the product page and stays closed; no card charge
- `OWN-17.4` — group/school quote shows the server tier and total; create stays closed
- `OWN-17.6` — coupon usability is visible and read-only; deduction stays 0
- `OWN-十六-04` — group-checkout quote
- `OWN-十六-07` — quote is wired; create stays closed behind the commerce gate
- `OWN-十七` — the three open children were 17.1, 17.4, and 17.6
- `OWN-十三-08` — the two open children were 17.1 and 17.4
- `OWN-十三-09` — the open child was 17.6

Still missing:

- `OWN-十六` — 十六-12, 十六-13, and 十六-14 are outside WP-07
- `OWN-十一-16` — rollup of `OWN-十六`, which is not done

WP-01, WP-02, and WP-05 were not touched.
