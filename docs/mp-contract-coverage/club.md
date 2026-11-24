# MP contract coverage — `api/club`

Slice of the table on `origin/cursor/mp-contract-coverage` at `569fca24195166bfb70cba51a8e2aedff27da2a3` (`docs/mp-contract-coverage.md`, receipt `docs/release/receipts/cursor-mp-contract-coverage.md`).

Mini-program source: public `liboyang42-cpu/hengyin`, folder `chengyinhub-xcx`, commit `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

A row is a callee named `request(`, including `receiver.request(`. `function request(` and a method shorthand `request(...) {` are definitions, not rows. `sendRequest(` and `req(` are different callees and are not rows. The checker is `tools/check_mp_contract_coverage.py` from that commit. It keeps a path only when the call's literal arguments resolve to an `/api` URL.

This file keeps rows whose extracted path is `api/club` or begins with `api/club/`. Merchant ledger, play, and roam rows stay on the coverage receipt.

## Counts

| count | value |
|---|---|
| table rows (`569fca241951`) | 102 |
| table matched | 19 |
| table missing endpoint | 42 |
| table missing test | 82 |
| in-scope paths (`api/club` or `api/club/…`) | 0 |
| in-scope missing rows | 0 |
| Core endpoints added | 0 |
| pinning tests added | 0 |

Re-scan of that checker against `chengyinhub-xcx` at `25eb6a0c` and this branch's `Core/` plus `Tests/CoreTests/` also returns 102 rows. Extracted paths equal to `api/club`, prefixed with `api/club/`, or containing `club`: 0. Symbol and test totals on this branch differ from the table because the play, roam, and pass pins live only on `cursor/mp-contract-coverage`. Those rows were not taken here. This re-scan: matched 2, missing endpoint 42, missing test 100.

Path prefixes on the re-scan: `-` 37, `api/merchant` 10, `api/play` 10, `api/circle-theme` 9, `api/creativesquare` 7, `api/platform-pass` 5, `api/capsules` 5, `api/exploration-goals` 5, `api/roam` 5, `api/comment` 4, `api/compliance` 2, `api/user` 2, `api/im` 1.

## In-scope rows

None.

## Club page call that is not this path

| MP file:line | callee | extracted path | why it stays out |
|---|---|---|---|
| `pages/club/detail/index.js:3821` | `subscribe.request(['coopStatus'])` | unknown | Subscription-message request. The coverage receipt already left it missing. The path is not `api/club`. |

## Money

No in-scope money row, so no money contract and no money pinning test were added. `ReleaseMoneyWriteSwitch.payoutEnabled` stays the release constant `false` (`Core/ChinaReviewedRouteCapability.swift`). `PayoutReceiverRoute.isPayout` is only personal-receiver bind and unbind. `PayoutReceiverTransport` still throws `APIError.notConfigured` for those two while the switch is off.

The production settlement caller stays POST.

- `PayoutReceiverRoute.settlementMine` (`api/club/settlement/mine`) and `.settlementSummary` (`api/club/settlement/summary`) use the route default method `POST` (`Core/PayoutReceiverClient.swift`). `PayoutReceiverService.settlementClubs` and `settlementSummary` send those routes.
- `CoopFlowRead.clubSettlementSummary` is absent from `usesGet`. `CoopFlowService.makeRequest` builds the URL with `AuthRequestBuilder.makeFormRequest`, which sets `httpMethod` to `POST` (`Core/AuthRequestBuilder.swift`). The GET override does not apply.

The mini-program settlement page sends the same two URLs with `method: 'POST'` through `app.sendRequest` (`pages/club/settlement/index.js:186`). That callee is not a coverage row, so it was not turned into a new Core endpoint. The existing POST caller was left in place.

## App call sites

No new Core type and no App screen edit. Existing settlement call sites, left as they are:

| call site | Core method | method |
|---|---|---|
| `App/ClubPayoutReceiverView.swift:143` | `PayoutReceiverService.settlementClubs` | POST |
| `App/ClubPayoutReceiverView.swift:222` | `PayoutReceiverService.settlementClubs` | POST |
| `App/ClubPayoutReceiverView.swift:319` | `PayoutReceiverService.settlementSummary` | POST |
| `App/CooperationFlowFixtures.swift:34` | fixture arm for `CoopFlowRead.clubSettlementSummary` | POST when the service sends it |

`CoopFlowService.read(.clubSettlementSummary)` has no other App screen caller on this branch.
