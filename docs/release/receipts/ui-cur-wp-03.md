# ui-cur-wp-03

HANDOVER 33, WP-03 merchant operations. Branch `ui/cur-wp-03` from `origin/ui/main` `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46`. Only this branch is pushed. `ui/main` was not pushed.

The WP-03 section was read from `e1969026e9469669e165937013e0e4f5c61b4252` (`docs/completeness-2`). That commit is not the base. WP-01, WP-02, and WP-05 were not implemented.

`docs/release/completeness-matrix.csv` is not on `ui/main`, so it was not imported.

`App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` were not edited. `ReviewedAreaSwitch` was not redeclared. `docs/release/contract-failing-baseline.txt` was not edited.

## Rows

| row | status |
|---|---|
| `PAGE-pages/merchant/decor/index` | WIRED |
| `PAGE-pages/merchant/decor/ai-npc/index` | WIRED |
| `PAGE-pages/merchant/team/index` | WIRED |
| `PAGE-subpackageMember/coupon/coupon` | WIRED |
| `PAGE-pages/topic/merchantinfo/merchantinfo` | WIRED |
| `API-/api/merchant/claims/status` | WIRED |
| `API-/api/merchant/claims/submit` | WIRED |
| `API-/api/merchant/commerce/order` | WIRED |
| `API-/api/merchant/commerce/order/status` | WIRED |
| `API-/api/merchant/coupon-summary` | WIRED |
| `API-/api/merchant/npc/review` | WIRED |
| `API-/api/merchant/operators/invite/preview` | WIRED |
| `API-/api/merchant/share-code` | WIRED |
| `API-/api/merchant/chapter-application/invite/revoke` | WIRED |

Rows still missing: none.

## What the screens do

Each named page shows its routes in English and zh-Hans (`Resources/MerchantOpsWp03.xcstrings`), with loading, empty, error plus retry, signed-out, and withheld states. Unknown values are an em dash. The sections are on the page, not behind a hidden flag.

- Decor (`MerchantOperationsViews`): commerce order, commerce order status, share code, claim status, claim submit.
- AI NPC (`MerchantStoreCharacterView`): `GET /api/merchant/npc/review`.
- Team (`MerchantBusinessViews`, home and the operators page): invite preview.
- Coupons (`CouponManagementView`): coupon summary.
- Merchant info (`MerchantContentViews` home and the chapter recruit view): chapter invite revoke.

The root installs `merchantOpsWp03Bridge` from the existing session base URL, token, and transport. Fixture hosts that do not set that bridge show the signed-out state and do not send.

## Grants

`merchantOpsWp03OwnerGrant` is appended after `beGapMerchantOwnerGrant` in `ChinaReviewedRouteCapability`. `MerchantOpsWp03Lease` is appended after `WorkshopModRouteGrant` in `ReviewedPlayerWriteLeases`.

Reads (`claims/status`, `npc/review`, `coupon-summary`, `operators/invite/preview`) are admitted. `POST /api/merchant/commerce/order` and `POST /api/merchant/commerce/order/status` are payment writes on `ReleaseMoneyWriteSwitch`. The client sends them only when `ReviewedAreaSwitch.moneyPayments` is on. That switch stays false for host `www.chengyinhub.com`. `admitsChinaProductionCall` does not admit those two paths.

Claim submit, share code, and chapter invite revoke are merchant writes. The client sends them only when `ReviewedAreaSwitch.merchantWrites` is on. That switch stays false for `www.chengyinhub.com`, and those three paths are not admitted on the China production host. Payout and password login were not opened.

## Checks

`python3 tools/generate_project.py` registered the new Swift files. `python3 tools/check_scaffold.py` PASS. `python3 tools/check_design_lint.py` PASS. `python3 -m unittest Tests.ContractChecks.test_cb97_payment_gating` OK (7 tests).

`swiftc` is not on this machine, so `swiftc -parse` did not run. No Swift typecheck was run. Merchant 9002 on TEST 8120 was not signed in, and no request log was collected. A 200 from those nine routes was not observed here.
