# cursor/cov3-a

Base `6afe54b4acee8786a9f3f3cbe8cd85d90be1e35a` (`ui/combined-r7` at the moment this branch was cut). The branch stayed on that SHA. No pull of `main`, `master`, `ui/main`, or `ui/combined-*`.

Mini-program: public `liboyang42-cpu/hengyin`, folder `chengyinhub-xcx`, commit `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

Checker: `python3 -B tools/check_mp_contract_coverage.py --mp-root <chengyinhub-xcx>`. It does not parse JavaScript. A path is taken from a literal only. A call that forwards `url`, or whose url is a ternary or a spread that clears the literal, stays missing-endpoint.

## Split

The checker prints `# total 1038 matched 779 missing_endpoint 120 missing_test 256`. `n` is the missing-endpoint count, 120. Rows are sorted lexicographically by `path:line`. This lane owns index 0 up to but not including `n//4` = 30.

| edge | location |
|---|---|
| first owned row | `app.js:374` |
| last owned row | `pages/merchant/reviews/reply-recovery.js:76` |
| first row after this lane | `pages/merchant/team/index.js:715` |

## Counts

`docs/mp-contract-coverage.md` totals were not edited. A fresh run before and after this change prints the same header: total 1038, matched 779, missing_endpoint 120, missing_test 256.

Owned rows: 30. After this change, missing-endpoint among them is still 30. The new Core literal is not attached, because the checker does not keep that call's path.

## Endpoint added

1. `POST api/login/code` — `Cov3AMPContract.loginCodePath`, from `app.js:374`. The call is `wx.request` with `url: that.globalData.siteBaseUrl + '/api/login/code'`, method `POST`, form field `code`, header `application/x-www-form-urlencoded;`. `Cov3AMPContract.loginCode` returns that request and does not send it. `Tests/CoreTests/Cov3AContractTests.testLoginCodePinsPostAndCode` quotes `api/login/code`, `"POST"`, and `"code"`.

The checker still reports `app.js:374` as missing-endpoint. `path_pattern` joins the concatenation to `{}/api/login/code` and then drops it, because that string does not start with `api/` or `/api/`. No second path was invented.

`tools/generate_project.py` registered `Core/Cov3AMPContract.swift` in `Questify.xcodeproj/project.pbxproj`. That file was not hand-edited.

## One path literal, symbol already present

These calls have one `/api` path. The Core literal was already there, so no second symbol was added. The checker still has no symbol for them.

| MP file:line | path | why it stays missing-endpoint |
|---|---|---|
| `pages/merchant/aftercare/detail/index.js:285` | `api/merchant/aftercare/respond` | Query template. The checker marks the row templated, then strips `?refundId=`, so the key has no `{}` and the exact literal on `MerchantBusinessMutation.request` is not consulted. `MerchantAftercareResponseGuideTests.testValidDraftSendsRefundQueryAndJSONBodyThroughFakeTransport` already quotes the path and `"POST"`. This lane does not send a refund. |
| `pages/merchant/aftercare/index.js:115` | `api/merchant/aftercare/list` | Same query-template shape (`bucket`, `pageNum`, `pageSize`). Exact literal already on `MerchantBusinessQuery.request`. `MiniProgramMerchantCoopContractPinTests.testAftercareListPinsBucketQueryAndEmptyJSON` already quotes the path and `"POST"`. |
| `pages/merchant/ledger/index.js:360` | `api/merchant/aftercare/list` | Same path and the same existing pin. The page helper supplies `POST`. |
| `pages/merchant/reviews/reply-recovery.js:76` | `api/merchant/reviews/reply/receipt` | The recorded call is the outer `request(callbacks => ...)`. The one path sits on the nested `sendRequest`, which is not its own row. `MerchantReviewReplyOriginal.receiptPath` already exists. `ZzMerchantCoopLaneBContractTests.testReviewReceiptPinsReviewActionAndRequest` already quotes the path, `"POST"`, and `reviewId`, `action`, `requestId`. |

## Still missing-endpoint

30 owned rows. No path was invented for a forward or a call with more than one path literal.

| MP file:line | why |
|---|---|
| `app.js:374` | one literal `api/login/code`, symbol added above; checker drops the `siteBaseUrl +` concatenation |
| `app.js:395` | `wx.request(opts)` forwards `opts` |
| `app.js:421` | `uploadFile(opts)` forwards `opts` |
| `app.js:447` | `sendRequest(options)` forwards `options` |
| `components/cy/club-direct-ledger/index.js:38` | ternary of `api/club-direct-merchant/club` and `api/club-direct-merchant/merchant` (both already in Core) |
| `components/cy/fe-reference-settlement/index.js:39` | ternary of `api/fe/reference-settlement/payer` and `api/fe/reference-settlement/merchant` (both already in Core) |
| `components/cy/fe-reference-settlement/index.js:98` | forwards `url` |
| `pages/activity/official-inbox/index.js:110` | forwards `url` (three concatenations assigned above the call) |
| `pages/club/components/cy/fe-reference-range/index.js:34` | ternary of payer and merchant plus `'/export'` |
| `pages/club/detail/index.js:1037` | `Object.assign` forwards `url` |
| `pages/club/event-ops/index.js:935` | ternary of `api/club/event-ops/series/update-future` and `series/create` (both already in Core) |
| `pages/club/join-requests/index.js:196` | ternary of `api/club/join-request/approve` and `join-request/reject` (both already in Core) |
| `pages/club/settlement/index.js:186` | ternary of `api/club/settlement/mine` and `api/club/settlement/summary` (both already in Core) |
| `pages/club/topic-story/index.js:274` | ternary of `api/club/topic-node-answer` and `api/topic/host-node-answer` (both already in Core) |
| `pages/coop/list/index.js:391` | ternary of `api/merchant/chapter-application/owner-mine` and `mine` (both already in Core) |
| `pages/coop/settlement-detail/index.js:232` | ternary of `api/club/settlement/summary`, `api/coop/finance`, and `api/coop/mybiz` (all already in Core) |
| `pages/index/index.js:1057` | forwards `url` |
| `pages/merchant/aftercare/detail/index.js:105` | ternary of `api/merchant/aftercare/manual-case-detail` and `api/merchant/aftercare/detail` (both already in Core) |
| `pages/merchant/aftercare/detail/index.js:285` | query template; symbol already present (see above) |
| `pages/merchant/aftercare/index.js:115` | query template; symbol already present (see above) |
| `pages/merchant/components/cy/fe-reference-range/index.js:34` | ternary of payer and merchant plus `'/export'` |
| `pages/merchant/decor/ai-npc/index.js:272` | forwards `url` |
| `pages/merchant/decor/index.js:367` | ternary of `api/merchant/info` and `api/merchant/coop-profile` (both already in Core) |
| `pages/merchant/index/index.js:1387` | `Object.assign` of `options`; no path literal |
| `pages/merchant/ledger/index.js:196` | forwards `url` |
| `pages/merchant/ledger/index.js:360` | query template; symbol already present (see above) |
| `pages/merchant/reviews/index.js:253` | ternary of `api/merchant/reviews/manage` and `api/merchant/reviews/public` (both already in Core) |
| `pages/merchant/reviews/index.js:624` | forwards `url` |
| `pages/merchant/reviews/reply-recovery.js:67` | outer `request(` holds three nested urls (`reply`, `reply/update`, `reply/delete`); no single path. All three literals already exist on `MerchantCoopLaneBContract` |
| `pages/merchant/reviews/reply-recovery.js:76` | one nested receipt path; symbol already present (see above) |

Rows left: 30.

## Money

Pay, refund, payout, withdrawal, paid orders, quote, registration create, and pricing confirm send nothing from this change. No sender was added for them. `Cov3AMPContract.loginCode` does not send.

## Not edited

`tools/check_mp_contract_coverage.py`, `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `docs/mp-contract-coverage.md`, ratchet ceilings in `tools/check_appsession_ratchet.py`. No `swiftc`.
