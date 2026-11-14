# StoreKit sandbox configuration

`Config/QuestifySandbox.storekit` is a local StoreKit configuration for sandbox testing in Xcode. It is not an App Store Connect product record, it is not bundled as an app resource, and it does not call the scheme generator.

It does not turn on `moneyPayments`, `payout`, `merchantWrites`, or `passwordLogin`. It does not redeclare `ReviewedAreaSwitch`. It does not add a card charge. `www.chengyinhub.com` stays closed for those four switches.

`Core/WorkshopStoreKitLauncher.swift` still requires `storeKitEnvironment == "PRODUCTION"` and `transaction.environment == .production` before it can purchase. This file does not change that gate. `ReleaseMoneyWriteSwitch` virtual goods stay off: `ReviewedAreaSwitch.releaseMoneyDerivation` returns false for `.virtualGoods`.

The product array is empty. No digital good in this tree has a StoreKit product id the app sells.

## English

| Digital good | Sold in this build | StoreKit product id |
|---|---|---|
| Workshop `DIGITAL_MOD`, non-consumable, channel `APPLE_STOREKIT` | No. The launcher returns nil unless a reviewed approval sets a non-empty `storeKitProductIDs`, a bundle id, and `PRODUCTION`. The shipped approval list is empty. | — |
| Unit-test id `mod.release` | No. It appears only in `Tests/AppUnitTests/WorkshopCommerceNativeContractsTests.swift` with bundle `test.bundle`. It is not a sold product. | — |
| Platform pass (`Core/PlatformPass.swift` plan codes and marketing products, kinds 1–8) | No. `moneyEnabled` is false. `purchase`, `quote`, `order`, and `claim` throw `unreachable` and do not build a payment body. | — |
| `VIRTUAL_CURRENCY` | No. `WorkshopDigitalChannelPolicyTests` rejects that product type on the StoreKit approval. | — |
| External HTML games | No. Monetization is `NONE`. A body that carries a price, `iap`, or `StoreKit` is refused. | — |
| Activity tickets and merchant SKUs | Not a digital good on this path. This file does not add a card charge for them. | — |

Team id, App Store application internal id, and a live price are —. The configuration leaves `_developerTeamID` and `_applicationInternalID` empty. Storefront `CHN` follows the China market in `Config/Base.xcconfig` (`QUESTIFY_MARKET = CN`) and the launcher’s China storefront code. Locale is `zh_Hans`.

## 简体中文

| 数字商品 | 此构建是否在售 | StoreKit 产品 ID |
|---|---|---|
| 工坊 `DIGITAL_MOD`，非消耗型，渠道 `APPLE_STOREKIT` | 否。除非已审核的批准写入非空 `storeKitProductIDs`、套装 ID 和 `PRODUCTION`，否则启动器返回 nil。随构建发布的批准列表为空。 | — |
| 单元测试 ID `mod.release` | 否。它只出现在 `Tests/AppUnitTests/WorkshopCommerceNativeContractsTests.swift`，套装为 `test.bundle`。不是在售商品。 | — |
| 平台通行证（`Core/PlatformPass.swift` 的方案代码与营销商品，种类 1–8） | 否。`moneyEnabled` 为 false。`purchase`、`quote`、`order` 和 `claim` 抛出 `unreachable`，不构造支付正文。 | — |
| `VIRTUAL_CURRENCY` | 否。`WorkshopDigitalChannelPolicyTests` 拒绝把该商品类型放进 StoreKit 批准。 | — |
| 外部 HTML 游戏 | 否。变现为 `NONE`。正文若带价格、`iap` 或 `StoreKit` 会被拒绝。 | — |
| 活动门票与商家 SKU | 不走这条数字商品路径。本文件不为它们增加银行卡扣款。 | — |

Team ID、App Store 应用内部 ID 和真实价格均为 —。配置中的 `_developerTeamID` 与 `_applicationInternalID` 留空。店面 `CHN` 对应 `Config/Base.xcconfig` 的中国市场（`QUESTIFY_MARKET = CN`）以及启动器的中国店面代码。语言为 `zh_Hans`。
