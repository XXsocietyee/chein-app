# cursor-mp-cov-club

Base `aee32a61f0f69b880bc9e33811463ccc73351bbe` (`origin/ui/combined-r7`). Branch `cursor/mp-cov-club`. No pull request.

Coverage table and receipt: `origin/cursor/mp-contract-coverage` at `569fca24195166bfb70cba51a8e2aedff27da2a3`. Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Slice write-up: `docs/mp-contract-coverage/club.md`.

Scope is missing coverage rows whose extracted path is `api/club` or `api/club/…`. Merchant ledger, play, and roam rows were not taken. `sendRequest(` and `req(` are not rows.

## Counts

| count | value |
|---|---|
| table rows | 102 |
| table matched | 19 |
| table missing endpoint | 42 |
| table missing test | 82 |
| in-scope `api/club` rows | 0 |
| in-scope missing rows | 0 |
| Core endpoints added | 0 |
| pinning tests added | 0 |
| new Core types | 0 |
| App screen edits | 0 |
| settlement caller method changes | 0 |
| payout routes enabled | 0 |

The same checker, run against this branch's `Core/` and `Tests/CoreTests/`, still finds 102 `request(` rows and 0 paths under `api/club`. Its matched count on this branch is 2 and its missing-test count is 100, because the 16 pins from `569fca241951` are not on this base. Those play, roam, and pass rows were left there.

## What was checked

`pages/club/detail/index.js:3821` is `require('../../../utils/subscribe.js').request(['coopStatus'])`. The extracted path is unknown. It is the only `request(` in a club page, and it is not an `api/club` row.

Club HTTP calls in the mini-program, including settlement, go through `app.sendRequest`. Production JavaScript at `25eb6a0c` contains 100 distinct `/api/club…` string literals. They are outside the row definition and were not given new endpoints.

## Settlement and payouts

The production settlement caller stays POST.

- `PayoutReceiverService.settlementClubs` posts `api/club/settlement/mine`.
- `PayoutReceiverService.settlementSummary` posts `api/club/settlement/summary`.
- `CoopFlowService.read(.clubSettlementSummary)` posts `api/club/settlement/summary`, because that read is not in `CoopFlowRead.usesGet` and `AuthRequestBuilder.makeFormRequest` sets `POST`.

App call sites of those callers, unchanged:

- `App/ClubPayoutReceiverView.swift:143` `settlementClubs`
- `App/ClubPayoutReceiverView.swift:222` `settlementClubs`
- `App/ClubPayoutReceiverView.swift:319` `settlementSummary`
- `App/CooperationFlowFixtures.swift:34` fixture arm only

`pages/club/settlement/index.js:186` already sends those two URLs as `POST` via `sendRequest`. That call is not a coverage row.

`ReleaseMoneyWriteSwitch.payoutEnabled` stays `false` on release builds. Personal-receiver bind and unbind stay the only payout routes on `PayoutReceiverRoute`, and `PayoutReceiverTransport` still sends neither while the switch is off.

## Not claimed

No `swiftc` run. No App screen edit. No new Core type, so no new symbol was searched for under `App/`. No secret and no mini-program screenshot. The checker does not parse JavaScript concatenation; this slice does not promote an unknown path into `api/club`.
