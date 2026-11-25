# cursor-cov3-e

Parent `ebf6c160ce73880807c07cf3cc10aa829e83d75e`. Branch `cursor/cov3-e` stays on that SHA. Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

`python3 -B tools/check_mp_contract_coverage.py --mp-root` that tree, against this branch's `Core/` and `Tests/CoreTests/`. The checker does not parse JavaScript. No path was invented. `docs/mp-contract-coverage.md` totals were not edited.

## Checker header

Before this rule, the same command printed:

```
# hengyin 25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf
# total 1038 matched 792 missing_endpoint 115 missing_test 242
```

After:

```
# hengyin 25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf
# total 1038 matched 792 missing_endpoint 49 missing_test 242 matched_indirect 66
```

66 rows moved from missing-endpoint to matched-indirect. `matched` is still a row with a Core symbol and a pinning test. An indirect row has no single path, so it is not in `matched` and its test column stays `MISSING`. `missing_test` does not move. The symbol column for these 66 rows is `INDIRECT`.

## Rule

A row with no path literal is matched-indirect only when the call forwards `url`, `requestJson`, or `_request`, or the url is a ternary whose every path literal is already a Core string literal. Both arms are required. A nested ternary counts every leaf. One arm that is not a literal, or a literal that is not already in Core, leaves the row missing-endpoint.

Not indirect:

- a concatenation such as `siteBaseUrl + '/api/...'`, `BASE + '/session/...'`, or `(payer ? payerPath : merchantPath) + '/export'`
- a data spread that drops a path literal (`utils/theme-records.js:132`, `pages/roam/index.js:1801`, `pages/roam/index.js:1830`)
- a call that only forwards `opts` or `options`, including `Object.assign` of `opts` or `options`, unless a later source shows `url`, `requestJson`, or `_request`
- an identifier that is not one of those three (`request`, `path`, `URL`, `REPOST_URL`)
- a template string with `${...}`

`options.url`, `config.url`, and `request.url` count because the property is `url`. On this tree the `requestJson` and `_request` wrappers forward `url` into `sendRequest`, so those rows are recorded as `forwards url`. The fixture test covers a call that forwards the names `requestJson` and `_request` directly.

## Allowlist

`tools/mp_contract_indirect_allowlist.txt`. 66 rows, `MP file:line` and a short reason. 38 forward `url` (34 the identifier, plus `options.url`, `config.url`, and two `request.url`). 28 are ternaries whose path literals are already in Core. The checker applies the rule. The file records the rows. Adding a line to the file does not mark a concatenation.

## Still missing-endpoint

49. These are the concatenations, opts/options forwards, data spreads, query templates, non-literal ternaries, and calls whose url is not one of the three names. The eight `voice-enrollment-journal.js` rows are the local `request(...)` predicate, not an HTTP url. No path was filled in for them.

## Money

No sender was added for pay, refund execution, payout, withdrawal, paid orders, quote, registration create, or pricing confirm. Three cancel-refund ternaries (`api/registration/cancel-refund` and `api/registration/cancel`) are indirect because both literals were already in Core. `api/registration/merchant/create` was already a literal on `MerchantContentCommands`. This change does not send either call.

## Not edited

`docs/mp-contract-coverage.md`, `Questify.xcodeproj/project.pbxproj`, `tools/current_ci_manifest.json`, `App/AppSession.swift`, `App/AppCompositionRoot.swift`. No `swiftc` and no `xcodebuild`. This receipt does not claim a parse.
