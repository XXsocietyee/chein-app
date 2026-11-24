# cursor-mp-cov-scan

Base `b0ac0108d0a5a9739ababecbbc61284cae5a8043` (`origin/ui/combined-r7`, "Integrate F-agent round 2"). Branch `cursor/mp-cov-scan`. No pull request.

Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Checker: `tools/check_mp_contract_coverage.py`, re-run on this tree. The checker does not parse JavaScript. No `swiftc` run. No new contract pins and no new endpoints.

## Totals

Old is the checker from `b0ac0108d` before this change, run on the same mini-program commit. The numbers previously written in `docs/mp-contract-coverage.md` (matched 19, missing endpoint 42, missing test 82) were from an earlier Core tree.

| | total | matched | missing endpoint | missing test |
|---|---:|---:|---:|---:|
| old checker | 102 | 28 | 39 | 73 |
| new checker | 1038 | 167 | 130 | 870 |

`matched` is a row with both a Core symbol and a pinning test. Twelve `subscribe.request([...])` rows, including `require("...subscribe.js").request([...])`, left the table. Each of those twelve was missing endpoint and missing test. They are not HTTP rows.

## Newly visible rows

948 rows are in the new run and were not in the old run.

| source | rows |
|---|---:|
| `sendRequest(` | 842 |
| `req(` | 105 |
| `wx.request(` | 0 |
| `uploadFile(` | 1 |

`wx.request(` was already counted as `request(`. The two calls in `app.js` stay rows. `uploadFile(` is `wx.uploadFile(opts)` in `app.js`. `opts` has no path string, so that row stays missing-endpoint.

537 of the 948 do not pass a closed object literal:

| argument | rows |
|---|---:|
| `Object.assign` | 21 |
| spread | 17 |
| variable | 5 |
| extra `++readEpoch` | 0 |
| object the closed-key reader rejects | 391 |
| positional, not an options object | 103 |

21 + 17 + 5 + 391 + 103 = 537. The two existing `request(..., ++readEpoch)` calls were already in the old 102, so they are not newly visible. 211 of the 948 pass no data object. A call that only forwards `url`, with no path string, stays missing-endpoint. A spread or `Object.assign` source after a url literal is not kept as the path.

Five rows that were already visible gained a symbol because the url literal sat in an object the old key reader rejected. No path was invented.

| MP file:line | path literal now read |
|---|---|
| `pages/merchant/relation/index.js:388` | `api/creativesquare/list` |
| `pages/square/detail/index.js:680` | `api/creativesquare/report` |
| `pages/square/detail/index.js:851` | `api/comment/report` |
| `pages/square/detail/index.js:902` | `api/comment/delete` |
| `pages/talent/list/index.js:209` | `api/creativesquare/list` |

`pages/square/detail/index.js:680` and `:851` also match the existing `UGCContentSafetyServiceTests.testFormReportsSendTheLabelAndCommunityReportsSendTheDetailText`. That test was already in this tree. It was not added here.
