# CB286 page-ready — subpackageMember/invoice/index

Base: `rc/20261108` `86fa48b0c5833bbadd97c09f246ad05f7af1b8b0`.
Branch: `cursor/cb286`.

Page: 我的发票记录列表. Native screen: `App/InvoiceLaunchHistoryView.swift`. Page-map status: `exists`.

This lane is already complete on rc. No Core, test, view, string catalog, ui-strings JSON, project, or ledger file was edited. Payment stays disabled. `/api/invoice/` was already `.liveInProduction` in `Core/ChinaReviewedRouteCapability.swift` and was not retouched.

## Already on rc

- Read model: `InvoiceLaunchCoordinator.overview()` loads titles, eligible orders, and `InvoiceLaunchService.applications()` (`InvoiceLaunchRoute.list` → `api/invoice/list`). Account and settings mount `InvoiceLaunchPresentation` with mutation permits omitted, so apply, title writes, and withdraw stay hidden. The service still rejects those calls as `.disabled`.
- Loading: `busy` shows the `loading` key.
- Empty: `InvoiceLaunchHistoryRules.emptyKey` is `empty` when there are no applications or the filter is `all`, and `emptyFiltered` for any other empty filter.
- Error: `issue` is `session`, `unavailable`, `storage`, `notSaved`, or `loadFailed`, with `retry`.
- UNKNOWN: a pending journal, or `outcomeUnknown` / `originalReadUnavailable` / `pendingConflict`, sets `unresolved` and the `unknown` key (`checkResult`). `ISSUE_UNKNOWN` decodes as a processing row (`filterKey` `SUBMITTED`, label `SUBMITTED`) and does not fail the list. A status outside the contract still fails closed.
- Amounts: `totalAmount` and each order `amount` decode as `Decimal`. A missing, null, or non-numeric amount throws. It is not stored as 0. `validate` rejects NaN. A literal `0` stays `0`. The existing view formatter prints that zero and uses an em dash (`—`, U+2014) only when formatting fails. The formatter was not changed.

## Missing keys

The history screen looks these keys up in `Resources/InvoiceLaunchUI.xcstrings`. Each one has a translated `en` value and a translated `zh-Hans` value.

Missing keys: none.

`CANCELLED`, `COMPANY`, `ISSUED`, `PAUSED`, `PERSONAL`, `REJECTED`, `SUBMITTED`, `all`, `amount`, `apply`, `checkResult`, `created`, `empty`, `emptyFiltered`, `history`, `keep`, `loadFailed`, `loading`, `notSaved`, `orderCount`, `retry`, `session`, `status`, `storage`, `taxNo`, `titleType`, `titles`, `unavailable`, `unknown`, `withdraw`, `withdrawConfirm`, `withdrawn`.

This list does not look up a tax-policy, legal, or support key. None was added.

## Left

- The history row does not print an issuer name. `InvoiceLaunchOrder.issuerName` is already decoded. Showing it would be a view change, which this lane does not make.
- No test taps the SwiftUI swipe withdraw. Existing coordinator and `InvoiceLaunchHistoryRules` tests already cover confirmation and a success notice only after the service succeeds. Cancel and payment stay off.
- `xcodebuild` was not run. No Swift test run is claimed, because no model or test changed.
