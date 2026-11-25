# cursor-mp-cov-pin

Base `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` (`origin/ui/combined-r7`, "Integrate Cursor round 4"). Branch `cursor/mp-cov-pin`. No pull request.

Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Checker: `tools/check_mp_contract_coverage.py`, re-run on this tree. Table: `docs/mp-contract-coverage.md`. The checker does not parse JavaScript. No `swiftc` run. No new Core endpoints and no new contract tests.

## Totals

| | total | matched | missing endpoint | missing test |
|---|---:|---:|---:|---:|
| old | 1038 | 167 | 130 | 870 |
| new | 1038 | 423 | 130 | 611 |

`matched` is a row with both a Core symbol and a pinning test. 259 rows that were missing a test now name one. 256 of those also have a Core symbol, so matched rises by 256. The other 3 stay missing-endpoint:

| MP file:line | path the checker already read | test |
|---|---|---|
| `pages/merchant/aftercare/detail/index.js:285` | `api/merchant/aftercare/respond` | `MerchantAftercareResponseGuideTests.testValidDraftSendsRefundQueryAndJSONBodyThroughFakeTransport` |
| `pages/merchant/aftercare/index.js:115` | `api/merchant/aftercare/list` | `MiniProgramMerchantCoopContractPinTests.testAftercareListPinsBucketQueryAndEmptyJSON` |
| `pages/merchant/ledger/index.js:360` | `api/merchant/aftercare/list` | `MiniProgramMerchantCoopContractPinTests.testAftercareListPinsBucketQueryAndEmptyJSON` |

No row lost a pin. No row was added or dropped. No Core symbol changed. Missing endpoint stays 130.

A row is pinned when one function in `Tests/CoreTests` contains the path and the quoted method. Literal field names are still required when the checker can read them. Each of the 259 had an unread field list, so the pin is the path and the quoted method. A body passed through `jsonBody(...)`, `JSON.stringify(...)`, a forwarded data value, `Object.assign`, a spread, a variable, or no data object stays in that unread set. `subscribe.request([...])` and `require("...subscribe.js").request([...])` are not rows. A call that only forwards `url` stays missing-endpoint.
