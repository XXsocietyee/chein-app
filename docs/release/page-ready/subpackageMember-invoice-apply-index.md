# PAGE-READY `subpackageMember/invoice-apply/index`

CB288. 申请开具发票. Map status stays `partial` on `App/InvoiceLaunchApplyView.swift`. This lane does not edit a view.

- Contract already in the repo: `InvoiceLaunchCoordinator.overview` reads `api/invoice/titles`, `api/invoice/orders/eligible`, and `api/invoice/list`. Submit stays `api/invoice/apply` on `InvoiceLaunchCoordinator.apply`. `InvoiceLaunchApplyPage.load` calls that overview only. `routeMarkedLive` is false. No route was added. `paymentEnabled` is false.
- Capability: `InvoiceLaunchApplyCapability(readsEnabled:mutationsEnabled:)` follows the existing host switches and does not turn either one on. A missing read stays hidden and does not call the coordinator. A missing apply grant leaves `showsApplyAction` false.
- Model: `InvoiceLaunchApplyPage` in `Core/InvoiceLaunchContracts.swift` has loading, empty, error, unknown, and ready. Unknown, null, a numeric string, and a non-number display `—`. A literal 0 stays `0`. The model does not add a calculated total.
- Tests: `testApplyPageStaysHiddenWithoutAReadAndDoesNotCallTheCoordinator`, `testApplyPageLoadingEmptyReadyAndLiteralZero`, `testUnknownAmountsAreEmDashAndALiteralZeroStaysZero`, and `testLoadUsesTheExistingOverviewAndKeepsFailuresOffZero` in `Tests/CoreTests/InvoiceLaunchApplyPageTests.swift`. `Tests/ContractChecks/test_invoice_apply_page_ready.py` checks the partial row, the existing keys, and that payment stays off.

## Missing keys

No new key was written. The keys this model references already have translated en and zh-Hans in `Resources/InvoiceLaunchUI.xcstrings`:

`loading`, `noOrders`, `loadFailed`, `session`, `storage`, `notSaved`, `unknown`, `retry`, `checkResult`.

These eligible-order fields have no key in that catalog. They are not labeled here, and no tax, legal, or support sentence was added for them:

- `issuerName`
- `ticketName`
- `paymentTime`
- `orderTitle` (the view prints the server string, or an em dash when the string is missing)

## Left

`App/InvoiceLaunchApplyView.swift` still reads `InvoiceLaunchPresentation`. It does not read `InvoiceLaunchApplyPage`. When apply writes are off it still shows `applyUnavailable` instead of leaving that sentence out. `invoiceAmount` still formats a required `Decimal` with two fraction digits. A missing `amount` on the existing order decoder still fails the whole read (`loadFailed`); it is not stored as 0. The host in `App/AppCompositionRoot.swift` still passes `mutationsEnabled: { false }`. This machine has no `swift` or `xcodebuild`. The XCTest file was not executed. `python3 -m unittest Tests/ContractChecks/test_invoice_apply_page_ready.py` passed (3 tests). `python3 -B tools/check_scaffold.py` passed.
