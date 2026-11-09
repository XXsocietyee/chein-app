# CB103 merge queue

Base: `origin/rc/20261108` `027e4985c53164127fd7bfd2b4845efbfc4c9e0b`.

Each lane below was merged with `git merge --no-ff`, one merge commit, in this order. No lane was squashed. `origin/ui/d7` `03f4569f595b955112fc606d2cda193e4f599de2` was not merged. `.github/workflows/ios-ci.yml` and `tools/current_ci_manifest.json` are byte-identical to the base (`3af977942405d29e9cae0fdafd75737f1a3408f8` and `743958754af4608942e3a86019e71fa499eba78b`). No test path was deleted. `Resources/Localizable.xcstrings` was not reformatted: its blob is `b98c30322b805df096ee401dd84c7764318d315b`, the same object as `origin/cursor/cb96`. No United States API URL was added. `ReviewedMarketLaunch.chinaProductionBaseURL` is still `https://www.chengyinhub.com/prod-api/`, and `approvedBaseURLs` still has no United States entry. This VM has no Xcode and no Swift toolchain. Nothing here is a build or an XCTest run.

`python3 -m unittest Tests.ContractChecks.test_cb97_payment_gating Tests.ContractChecks.test_view_literal_localization` reported 8 tests OK. Those tests read source. They do not compile Swift.

## Lanes

| Order | Lane | Tip | Merge commit | Result |
|---|---|---|---|---|
| 1 | `origin/cursor/cb94` | `01215d6547547bcf3461cd9d0e0d6e50f396e1fa` | `bed6c0e53390de1713112dc470a3ded38ab12f12` | Clean. Parent of the tip is the base. |
| 2 | `origin/cursor/cb95` | `e581fdceea0f55f44544518f4ed3e4b76bf3e497` | `0a39eb17bad9133c9e201d360a247a60e3b07ea2` | Clean. No path overlap with CB94. |
| 3 | `origin/cursor/cb96` | `8c829c401b07865ed37ec5808251dc76aab92e2e` | `f5b1a1e2b31f81cde94bd4fcc8f10935a733cd8a` | Clean. Tip parent is `576e869a995c280f325799ad8ea9a2729ac30781`. Every path in that diff was unchanged on the base since that parent. |
| 4 | `origin/cursor/cb97` | `3f9afa676dc751d0cc85b32c9f576ddb14cb881b` | `c2ad11d14b444cb7bd09c32b91563db13137b8e5` | Clean auto-merge. Tip parent is `2f6d5041a57d876d3b0a953f56ecf5208089622f`. The two shared files are recorded below. |
| 5 | `origin/cursor/cb98` | `814592f35d941387abbaf40f0c96fddd9cd4b36d` | `754408f1f6dde48b14032de5b79f0796e290361c` | Clean. No path overlap with CB94–CB97. Those App files were unchanged on the base since `2f6d5041a57d876d3b0a953f56ecf5208089622f`. |

## Shared files

CB94 and CB97 both edit `Core/ChinaReviewedRouteCapability.swift` and `App/AppSession.swift`. The ort merge did not leave conflict markers. The hunks sit in different regions, and the one function both sides edit kept both conditions. No switch was turned on. No payment route was chosen.

### `Core/ChinaReviewedRouteCapability.swift`

Kept CB94's `offersFeature(_:baseURL:)`. A nil base returns false. The China production host returns `admitsChinaProductionCall`. Any other host stays a fixture and returns true. The function does not invent a United States API URL.

Kept CB97's `ReleaseMoneyWriteSwitch`. All four constants stay false:

- `paymentEnabled = false`
- `payoutEnabled = false`
- `withdrawalEnabled = false`
- `virtualGoodsEnabled = false`

`admitsChinaProductionCall` calls `ReleaseMoneyWriteSwitch.blocks` before `forcedOff` and before `wiredPatterns.contains`. A classified money-moving write stays unadmitted on the China host while its own switch is false, including if that path is later added to the wired catalog. `offersFeature` reaches that check for the China host, so the two gates compose. `ChinaReviewedProductionTransport.send` still goes through `refuseUnwiredChinaProduction`.

`ReleaseMoneyWriteKind` and `ReleaseMoneyWriteSwitch` sit after `wiredPatterns` and before `ChinaReviewedProductionTransport`, which is the shape the CB97 source contract reads.

### `Core/RegionalConfiguration.swift`

CB97 does not edit this file. CB94's `showsRoute` is unchanged: it calls `offersFeature` first, then `hidingCapability` / `isFeatureShown` for password login, bank withdrawal, and virtual goods. Verifying one of those capabilities on the China host still does not show the route, because `offersFeature` is false first.

### `App/AppSession.swift`

CB94's public-layer gate stayed. `mapPublicLayerService` is built only when the deployment grants the read and `showsRoute("/api/map/public-layers")` is true. `searchMapPublicLayerCoordinator` is nil unless that service exists and the same route is shown, so the explorer section is not mounted for a hidden route.

CB97's call-site gates stayed, and each money write is still unreachable while its switch is false:

- WeChat `allowed` returns false unless `paymentEnabled` is true, and that check is before `selfPlayPayment`.
- `topicSelfPlayFlow` builds a payment provider only when `paymentEnabled` is true, before `selfPlayPayment` and `.topicSelfPlayPay`. Otherwise the provider is nil.
- `makeOrderLifecycleDispatcher` passes that same provider only when `paymentEnabled` is true. Otherwise it passes nil.
- `makeWorkshopCommerceController` sets `enableApprovedStoreKit` to `ReleaseMoneyWriteSwitch.virtualGoodsEnabled && !readOnly`.

`makeBankWithdrawalContext` is the function both sides edited. The merged guard is both checks, with the switch first:

```swift
guard ReleaseMoneyWriteSwitch.withdrawalEnabled,
      let factory = businessRuntimeFactory, factory.permits(.bankPrepare), factory.permits(.bankConsentRead),
      let provider = runtimeDependencies.bankDocument, let scope = walletCommerceScope,
      let configuration = regionalConfiguration?.apiConfiguration,
      ChinaReviewedRouteCapability.offersFeature("/api/withdrawal/create", baseURL: configuration.baseURL) else { return nil }
```

`withdrawalEnabled` is false, so the function returns nil before `BankWithdrawalAdapter` and before `enableReviewedWrites: true`. The factory permit alone does not build the context. `offersFeature("/api/withdrawal/create")` remains required for any later case in which the switch is true.

`Core/WorkshopCommerceService.send` still throws `WorkshopCommerceIssue.disabled` when a non-GET route is blocked by `ReleaseMoneyWriteSwitch.blocks`, and that check stays before `session.data`.
