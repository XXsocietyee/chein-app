# cloud-stubs-affiliate

Branch `ui/cloud-stubs-affiliate`. Parent `origin/ui/next` `11e7c2c4559ee3a210fdcfacf8abee717c312ff9`.

Handover 14, ledger row 25. Read only: `GET /api/marketing/affiliate/summary?limit=20`. `MPParityBindings.journeyPromo` is filled on the bindings value `fillingPlayerJourneyReads` already returns for the shipped China composition (player writes on, China market, base URL `https://www.chengyinhub.com/prod-api/`). `App/AppSession.swift` and `App/AppCompositionRoot.swift` are unchanged (8176 and 4307 lines). `App/ReviewedPlayerWriteLeases.swift` and `App/RegionalLaunchConfiguration.swift` were not edited. The contract-failing baseline is not raised. `tools/check_scaffold.py` and `tools/check_design_lint.py` pass. This VM has no Swift compiler, so the new tests were not executed.

## What the summary read shows

`JourneyProductionLease.refused` no longer includes `.affiliate`, so that one GET is sent. `.issueReferral` and `.giftClaim` stay refused, and those methods still throw `moneyOff` without a request. `PWaveReader.affiliateSummary` still throws `productionEndpoint` under the production lease. `PWaveProductionReadLease` still does not grant `.affiliateCenter`. Withdraw, payout, and virtual goods stay off (`ReleaseMoneyWriteSwitch`, `MPCommerceGate.payoutEnabled`). There is no withdraw button.

`ChinaReviewedRouteCapability` admits only this extra GET, `/api/marketing/affiliate/summary`, on the existing owner-grant set. The route mark stays `.missing`. `wiredPatternCount` stays 672. Points, bounty, and orient paths were not edited.

The page projects the mini-program `affiliateView` fields and nothing else:

| Server fact | Shown |
|---|---|
| `allocations.{pending,confirmed,paid,reversed}.netAmount` number | `¥` plus two fraction digits |
| missing, null, a numeric string, or any other non-number | em dash (`—`) |
| `amountUnavailableReason` `MULTIPLE_CURRENCIES` | “Not summed across currencies” / “多币种暂不合计”. The number is not shown. |
| `allocationCount` integral and greater than 0 on any bucket | all four buckets |
| `held.orders` integral and greater than 0 | 待核算 count |
| `held.amountFen`, including null | not a balance, not a count |
| `campaigns[]` `attributedOrders` / `paidOrders` / `refundedOrders` | those integers, or an em dash when the field is not an integer |
| `credentials[]` `targetTitle`, `active` (JSON true only), `expiresAt` date | invite link row |
| `token`, `phone`, and any other credential body | not stored and not drawn |
| an array of `amountFen` | not summed |

`payout.available` and `payout.endpoint` do not change the screen. Links alone still show 暂无可核实记录 / “No verifiable records yet”.

## Copy

No new strings. The page uses the existing `mp.promo.*` keys (EN + zh-Hans), including the em dash from `MPText.unknown`.

## Files

- Added: `App/PlayerJourneyPromoBinding.swift`, `Tests/AppUnitTests/PlayerJourneyPromoTests.swift`.
- Changed: `Core/PlayerJourneyProductionLease.swift` (drop `.affiliate` from `refused`), `Core/JourneyLoopSource.swift` (comment), `Core/ChinaReviewedRouteCapability.swift` (one grant path), `App/PlayerJourneyReadBindings.swift` (one closure), the two production tests, `docs/release/launch-readiness.md`, `docs/release/launch-scope-matrix.md`, `Questify.xcodeproj/project.pbxproj` (regenerated).
- Not touched: `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `App/ReviewedPlayerWriteLeases.swift`, `App/RegionalLaunchConfiguration.swift`, `docs/release/contract-failing-baseline.txt`.

## 中文

交接 14，账本第 25 行。只读 `GET /api/marketing/affiliate/summary?limit=20`，填到已有绑定的 `journeyPromo`。只对已出货的中国组合开放（玩家写开启、中国市场、基址 `https://www.chengyinhub.com/prod-api/`）。推荐令牌签发、礼物领取、提现、打款仍然拒绝，没有提现按钮。未知金额是破折号「—」，不把 `held.amountFen` 或分配数组里的金额加成余额。`AppSession` 与 `AppCompositionRoot` 没有加行。合同失败基线没有上调。
