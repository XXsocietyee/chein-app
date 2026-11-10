# CB287 page-ready — `subpackageMember/invoice-detail/index`

Base: `origin/rc/20261108` `e8299803711abd007e33731bdd534c40d6536ea2`.
Screen: 发票详情页. Native: `App/InvoiceLaunchDetailView.swift`. Map status: exists.
Source checked: public snapshot `liboyang42-cpu/hengyin` `chengyinhub-xcx/subpackageMember/invoice-detail/index.{wxml,js}`, `subpackageMember/invoice/base.js`, `utils/user-invoice.js`, `utils/wxs/money.wxs`, and `UserInvoiceServiceImpl.applicationView`.

Core wiring for that contract is already on rc. This lane does not edit a view, a string catalog, the route catalog, the Xcode project, or the CI ledger. It does not mark a route live and does not enable payment. No tax, legal, or support sentence was written.

## Already on rc

- Detail read: `InvoiceLaunchRoute.detail` is `POST api/invoice/detail`. `InvoiceLaunchService.detail(id:)` checks the id, decodes one application, and rejects a mismatched id. `InvoiceLaunchPresentation.loadDetail` is what the screen calls. The path is already live in `Core/ChinaReviewedRouteCapability.swift`. It was not touched.
- Loading: `InvoiceLaunchPresentation.busy` and `InvoiceLaunchStateSection` show the progress view with key `loading`.
- Error: `fail` sets `issue` to `loadFailed`, `unavailable`, `session`, `storage`, or `notSaved`. The detail screen passes `loadDetail` as the retry.
- UNKNOWN: a pending journal, or `outcomeUnknown` / `originalReadUnavailable` / `pendingConflict`, sets `unresolved` and issue `unknown`. The section uses keys `unknown` and `checkResult`.
- Empty: the mini-program detail page has no empty-application state. A bad id or a failed decode is an error. The in-page signed-out empty is the existing `session` issue (`请重新登录`). No second empty state was added.
- Amounts: `totalAmount` and each order `amount` stay server decimals. A JSON number `0` decodes as `0` and passes `validate`. `null`, a missing key, `""`, and `"UNKNOWN"` fail the decode and are not stored as `0`. The detail row therefore never shows `0` for an unknown amount. It also does not show an em dash for that amount, because the read fails before the row exists. `invoiceAmount` in `App/InvoiceLaunchPresentation.swift` was not edited. A present `0` still formats there as `0.00`.

## Missing keys

These source strings have no entry in `Resources/InvoiceLaunchUI.xcstrings`. They were not added.

| Source string | Where the detail page uses it | What the screen uses now |
|---|---|---|
| 登录后查看发票 | Signed-out empty title | `session` = 请重新登录 |
| 微信登录 | Signed-out empty action | No in-page login button |
| 发票功能暂未开放 | Feature-off empty | `unavailable` = 发票暂不可用 |
| 发票申请加载失败 | Load-failure title | `loadFailed` = 加载失败 |
| 撤回结果未确认 | Cancel result still unknown | `unknown` = 上次操作结果尚未确认 |
| 待确认 | Tag on that unknown card | No tag key |
| 刷新 | Button on that unknown card | `checkResult` = 查询结果 |
| 开具中 | Tag while issuing | `SUBMITTED` = 处理中 |
| 开票单位 | Issuer row label | Row not shown. Detail `applicationView` does not send an application issuer name |
| 发票号 | Invoice-number label | `invoiceNo` = 发票号码 |
| 包含订单 | Orders section title | `orders` = 订单明细 |
| 开票金额 | Total label | `amount` = 金额 |
| 撤回发票申请 | Withdraw confirm title | `withdrawConfirm` = 撤回这次申请？ |
| 撤回后，订单可重新申请开票。 | Withdraw confirm body | Dialog has no body key |
| 重新申请 | Button on a rejected application | Not shown. Apply stays gated |
| 联系客服 | Support button | Not written |
| 发票客服 | Support message-card title | Not written |
| 报名订单 | Fallback when an order title is empty | A nil title already renders as `—` in the view. This fallback was not added |
| 待配置开票主体 | Fallback issuer on an order line | Not added. It would invent an issuer name |

`发票抬头` is already the value of `titles`. The detail row is bound to `titleName` (`抬头名称`).

## Left

- The view still does not show the issuer row, the ticket name after the order title, 重新申请, or the support button.
- `reconciliationStatus` can arrive on the detail JSON (`REQUIRED`, `NO_ISSUE_CONFIRMED`, `TAX_REVIEW_REQUIRED`). This screen does not render it. The three reconciliation sentences were not copied.
- A decimal string such as `"0"` or `"14.25"` is not accepted. The server view serializes `BigDecimal` as a JSON number. A string fails the read and does not become `0`.
- An em dash on an amount row for a null amount needs an App change. This lane did not make one.
- `swift` and `xcodebuild` are not on this machine. No Swift test was run. The new lock is `Tests/CoreTests/InvoiceLaunchStatusTests.swift` `testLiteralZeroAmountStaysZeroAndUnknownDoesNotDecodeAsZero`. Existing invoice tests were not edited.
