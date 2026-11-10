# CB289 subpackageMember/invoice-titles/index

PAGE-READY model on rc/20261108. Native screen `App/InvoiceLaunchTitlesView.swift`. Map status stays exists. No route was invented and none was marked live. `InvoiceLaunchTitlesPage.routeMarkedLive` is false. The list read stays the existing `InvoiceLaunchRoute.titles` (`api/invoice/titles`). This type does not send it.

`InvoiceLaunchTitlesPage` projects a decoded `[InvoiceLaunchTitle]`. Loading is `loading` with no list yet (`loading`). Empty is a confirmed `[]` (`noTitles`). Error is feature off (`unavailable`) or a failed read with no list (`loadFailed`). UNKNOWN is a nil list, or a pending title save (`unknown`) even when the list is already known. Ready is a signed-in list with rows and no pending save (`titles`). Signed out is empty with copy `invoice.titles.signIn`, and a passed-in list is not shown. Writes stay off unless the caller passes the existing save or delete permit. Both default to false.

A missing count, a numeric string, and an unmasked tax echo display as `—` (U+2014). A literal integer 0 stays `0`, including a confirmed empty list. A pending save does not turn a known count into an em dash. An empty tax stays omitted. A contract mask is kept. `******` is that mask, not a tax number. No tax number, phone, or email was added.

The view still uses `InvoiceLaunchPresentation` and `InvoiceLaunchStateSection`. It does not read this projection. `auth.wechat.signIn` already has en and zh-Hans (`微信登录`) and the titles view does not call it.

Missing EN+zh-Hans keys:

- `invoice.titles.signIn` — 登录后管理发票抬头
- `invoice.titles.pendingHold` — 确认前请勿修改抬头
- `invoice.titles.saveNotFound` — 暂未查到这次保存
- `invoice.titles.deleteUnknown` — 删除结果未确认，请刷新查看
- `invoice.titles.deleteFailed` — 删除未完成
- `invoice.titles.deleteTitle` — 删除发票抬头

`loading`, `noTitles`, `loadFailed`, `unknown`, `unavailable`, `titles`, `titlesReadOnly`, `checkResult`, `retry`, `addTitle`, `edit`, `delete`, `deleteConfirm`, `keep`, `defaultTitle`, `PERSONAL`, and `COMPANY` already have translated en and zh-Hans in `Resources/InvoiceLaunchUI.xcstrings`.

Left: `InvoiceLaunchTitlesView` does not read `InvoiceLaunchTitlesPage`. On an unknown failure, `InvoiceLaunchPresentation.fail` still clears `overview`; this projection keeps a list that was already passed in. Wording that already has a key and is not the mini sentence: `noTitles` is 暂无发票抬头 (还没有发票抬头), `unavailable` is 发票暂不可用 (发票功能暂未开放), `loadFailed` is 加载失败 (发票抬头加载失败), `unknown` is 上次操作结果尚未确认 (上次保存结果未确认), `addTitle` is 新增抬头 (新增发票抬头), `deleteConfirm` is 删除该抬头？不影响已提交的申请。 (删除后不影响已提交的申请。), `defaultTitle` is 默认抬头 (默认). Strings, the view, the catalog, the Xcode project, and the CI ledger were not changed.

Tests: `InvoiceLaunchTitlesPageTests` and `Tests/ContractChecks/test_subpackage_member_invoice_titles_index.py`. Existing `InvoiceLaunchTitleRulesTests` were not changed. No Swift run and no Xcode Cloud result.
