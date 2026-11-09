# CB97 — Release payment, payout, withdrawal, and virtual-goods switches

Base: `origin/rc/20261108`. Branch: `cursor/cb97`.

Each money-moving write has its own Release switch. All four stay off. This note does not turn a switch on and does not choose a payment provider or a payment route. `tools/current_ci_manifest.json` was not refreshed. `.github/workflows/ios-ci.yml` was not edited.

## Switches

Defined on `ReleaseMoneyWriteSwitch` in `Core/ChinaReviewedRouteCapability.swift`. `isEnabled` returns that constant. `blocks` is true only for a classified write whose own switch is off.

| Switch | Constant | Release value | Writes it covers |
|---|---|---|---|
| payment | `paymentEnabled` | `false` | `/api/registration/pay`, `/api/registration/pay/app`, `/api/pay/create` |
| payout | `payoutEnabled` | `false` | `/api/club/settlement/withdraw` |
| withdrawal | `withdrawalEnabled` | `false` | `/api/withdrawal/create`, `/api/asset/withdraw`, `/api/wallet/withdraw`, `/api/fund/preflight` (preflight, confirm, reject) |
| virtual goods | `virtualGoodsEnabled` | `false` | `/api/cart/add`, `/api/cart/cart/add`, `/api/cart/update`, `/api/cart/delete`, `/api/cart/order/settlement`, `POST /api/mod-commerce/orders`, `POST .../payment`, `.../native-dispatch`, `.../native-transaction`, `/api/mod-commerce/native-transactions/restore` |

`ChinaReviewedRouteCapability.admitsChinaProductionCall` calls `ReleaseMoneyWriteSwitch.blocks` before it consults `wiredPatterns`. A classified write stays unadmitted on the China production host while its switch is off, including if the path is later added to the wired catalog. `ChinaReviewedProductionTransport.send` uses that admit function.

These older constants also stay off. They are not the Release switch, and this change does not point them at a provider:

- `CommerceClientPaymentRules.paymentEnabled` = `false`
- `MerchantAICommerceGates.paymentAndCashEnabled` returns `false`
- `BusinessRuntimeConfiguration.selfPlayPayment` and `selfPlayExternalCheckoutApproved` default `false`
- `OrderLifecycleProductionConfiguration.externalCheckoutApproved` and `devicePaymentApproved` default `false`
- `BankWithdrawalAdapter.enableReviewedWrites` and `WalletCommerceDormantAdapter.enableReviewedWrites` default `false`

Reads stay out of the switch. `/api/withdrawal/list`, `/api/wallet/stages`, `/api/club/settlement/summary`, `/api/cart/list`, and `/api/cart/settlement` are not writes. Offer exit (`/api/coop/offer/withdraw`), team application withdraw, and chapter-application withdraw are not cash withdrawal.

## Call sites checked

| Call site | Switch checked | Reachable in Release while that switch is off |
|---|---|---|
| `App/AppSession.swift` WeChat `allowed` closure (`nativeWeChatPaymentAdapter`) | `paymentEnabled` before `selfPlayPayment` or order-lifecycle approval | No. The closure returns false. |
| `App/AppSession.swift` `topicSelfPlayFlow` payment provider | `paymentEnabled` before `selfPlayPayment` and `.topicSelfPlayPay` | No. The provider is nil, so `TopicSelfPlayFlow` does not call `paymentParameters`. |
| `App/AppSession.swift` `makeOrderLifecycleDispatcher` | `paymentEnabled` around `runtimeDependencies.selfPlayPayment ?? nativeWeChatPaymentAdapter` | No. The provider passed in is nil, so `canDispatch` for `.payment` is false. |
| `App/AppCompositionRoot.swift` `sessionDependencies` | payment flags are `externalCheckoutApproved: false` and `devicePaymentApproved: false`. The business routes are IM only: no `.bankPrepare`, `.bankCreate`, or `.topicSelfPlayPay`. | No payment or withdrawal route is issued. |
| `Core/OrderLifecycleRequestContract.paymentParameters` and `Core/OrderLifecycleDormantAdapter.paymentParameters` | Dormant adapter: `isProductionDispatchEnabled` is false and `requireFixture()` throws outside DEBUG before `transport.send`. | No Release dispatch. |
| `Core/OrderLifecycleProduction.swift` `dispatch` payment branch | Session supplies no provider while `paymentEnabled` is false. China admit still blocks `/api/registration/pay/app`. | No on the Release session. |
| `Core/TopicSelfPlayHTTPClient.paymentParameters` | Only constructed from `topicSelfPlayFlow`, which installs a provider only when `paymentEnabled` is true. | No. |
| `Core/TopicSelfPlayRuntimeTransport.validates` | Allows the pay/app form only as a shape check. The Release transport underneath is `ChinaReviewedProductionTransport`. | No. Admit blocks the path. |
| `Core/BankWithdrawalAdapter` `prepare` / `submit` / `reject` | `enableReviewedWrites` defaults false. The only App construction with `enableReviewedWrites: true` is `makeBankWithdrawalContext`, which returns nil unless `withdrawalEnabled` is true. | No. |
| `Core/BusinessRuntimeConfiguration` bank and `topicSelfPlayPay` catalogs | Route tables only. `sessionDependencies` does not grant them. | No. |
| `Core/WalletCommerceSafety.swift` `WalletCommerceCommand` and `WalletCommerceDormantAdapter.execute` | `enableReviewedWrites` defaults false. `App/AppSession.swift` does not construct `WalletCommerceDormantAdapter`. | No. |
| `Core/WalletCommerceService` cart settlement and withdrawal list | Read paths. Not classified as writes. | Not a write. |
| `Core/WorkshopCommerceService.send` | `ReleaseMoneyWriteSwitch.blocks` before `session.data` for non-GET mod-commerce routes. | No. |
| `App/AppSession.swift` `makeWorkshopCommerceController` | `enableApprovedStoreKit` is `virtualGoodsEnabled && !readOnly`. `workshopCommerceApproval` is never assigned, so the controller is nil. | No StoreKit purchase and no mod-commerce order write. |
| `Core/WorkshopCommerceComposition.make` | `enableApprovedStoreKit` defaults false. The session passes the virtual-goods switch. | No. |
| `/api/club/settlement/withdraw` | `payoutEnabled`. The literal appears only in `Core/ChinaReviewedRouteCapability.swift` under `App/` and `Core/`. No sender. | No. |
| `/api/asset/withdraw`, `/api/wallet/withdraw`, `/api/pay/create` | withdrawal or payment switch, and `forcedOff` / `Adapt5HighRiskWriteSupplement` / `RegionalHighRiskWriteRoute` still name the deny list. No App or Core function both names one of these paths and calls `transport.send` or `session.data` without `ReleaseMoneyWriteSwitch`. | No. |
| `Core/WeChatSDKPaymentAdapter.pay` | `allowed` defaults to `{ false }`. The session closure also requires `paymentEnabled`. | No. |

`forcedOff` is unchanged. Registration pay remains hidden as the existing virtual-goods capability label, and bank preflight remains hidden as the existing merchant-payout label. The new switches are additional and separate: payment is not payout, payout is not withdrawal, and virtual-goods cart or mod-commerce writes are not the registration payment route.

## Result

No Release write for payment, payout, withdrawal, or virtual goods was reachable while its switch was off. The contract test `Tests/ContractChecks/test_cb97_payment_gating.py` fails if a switch constant is not `false`, if admit stops consulting `blocks` before the wired catalog, if a required path leaves `kind(for:)`, or if a sending function names a classified write without `ReleaseMoneyWriteSwitch`.
