# cursor/cov2-merchant-coop-b

Base `origin/ui/combined-r7` `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` (message starts "Integrate Cursor round 4"). Tip had not moved. No rebase. Branch `cursor/cov2-merchant-coop-b`. No pull request. `docs/mp-contract-coverage.md` was not edited, so its global totals are unchanged. The checker was not edited. `AppSession.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. `swiftc` was not run.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Counts below are from `python3 tools/check_mp_contract_coverage.py` against that tree. The checker does not parse JavaScript.

## Split

Merchant-coop rows are those whose MP path starts with `pages/merchant/` or `pages/coop/`. Sorted by the full MP path, that set has 175 rows. Lane a owns the first half, and the odd row stays with lane a: 88 rows. This lane owns the second half: 87 rows.

| | MP file:line |
|---|---|
| Last row of lane a | `pages/merchant/decor/ai-npc/index.js:314` |
| First row of lane b | `pages/merchant/decor/coop-setting/index.js:117` |

`app.js` and `components/` were not taken. The four `pages/merchant/utils/voice-enrollment-journal.js` rows are covered below. `api/creativesquare/list` (`pages/merchant/relation/index.js:388`) was not taken.

## Endpoints added

`Core/MerchantCoopLaneBContract.swift`. `App/` has no type of that name.

| Core symbol | Path | Checker |
|---|---|---|
| `arrivalsTodayPath` | `api/merchant/desk/arrivals/today` | Attached to `pages/merchant/verify-records/index.js:153`. POST, no body. |
| `reviewReplyPath` | `api/merchant/reviews/reply` | Literal matches the nested `sendRequest` in `pages/merchant/reviews/reply-recovery.js:67`. The checker row is the outer `request(` and has no url, so the symbol stays missing on that row. |
| `reviewReplyUpdatePath` | `api/merchant/reviews/reply/update` | Same row. |
| `reviewReplyDeletePath` | `api/merchant/reviews/reply/delete` | Same row. Delete does not send `content`. |

## Voice enrollment journal

`Core/MerchantVoiceEnrollmentJournal.swift`. `App/` has no type of that name. Line 6 is `const request = value => …`, a local id check: `sample:` plus 64 lowercase hex digits, or 8-4-4-4-12 lowercase hex. The four calls pass one property. They do not forward `url`, and they have no HTTP method. No API path was added.

| Row | Call shape | Literal fields | Test |
|---|---|---|---|
| `:18` | `request(value.active)` | `active` | `testVoiceJournalActiveCallQuotesActiveAndSendsNothing` |
| `:20` | `request(row.requestId)` | `createdAt`, `intentId`, `previousIntentId`, `requestId`, `state` | `testVoiceJournalRecordCallQuotesRequestIdAndSendsNothing` |
| `:76` | `request(result.voiceRequestId)` | `voiceRequestId` | `testVoiceJournalObserveCallQuotesVoiceRequestIdAndSendsNothing` |
| `:100` | `request(value.requestId)` | `requestId`, `intentId`, `state` | `testVoiceJournalRecoverCallQuotesRequestIdAndSendsNothing` |

`httpMethod` is nil. The tests send nothing. Payout, refund, withdrawal, and both IM mark-read switches are unchanged.

No path was invented for a call that only forwards `url`: `pages/merchant/ledger/index.js:196`, `pages/merchant/reviews/index.js:624`, and `pages/merchant/index/index.js:1387` (forwards `options`). Ternary urls at `decor/index.js:367`, `reviews/index.js:253`, and `team/index.js:715` already have Core literals. `api/merchant/aftercare/list` (`ledger/index.js:360`) is already a Core literal; the checker marks that row templated because the query string is interpolated, and a fixed literal does not fill a templated lookup. `api/merchant/reviews/reply/receipt` was already `MerchantReviewReplyOriginal.receiptPath`.

## Tests added

`Tests/CoreTests/ZzMerchantCoopLaneBContractTests.swift`: 58 functions. 53 quote a path, `"POST"`, and the literal field names for 73 owned rows. Four more quote the journal call shape and its literal field names. The class name sorts after existing CoreTests classes, so a shared path keeps the test it already had. One function only asserts the money switches.

The checker counts a test only when the row's method and field list are literals. It counts these three:

| Test | Rows |
|---|---|
| `testBusinessStatusUpdatePinsBusinessStatus` | `decor/index.js:951`, `index/index.js:196` — `business_status` |
| `testLiveCheckinCodePinsNodeId` | `game-node/index.js:607` — `nodeId` |
| `testPredictSettlePinsNodeDayAndOption` | `predict/index.js:212` — `nodeId`, `playDay`, `settledOption` |

The other quoting tests stay uncounted because the data is `JSON.stringify`, a trailing callback, a missing `data` key, or a url the checker does not keep. Six rows that already had a Core symbol and a test were not redone. `api/creativesquare/list` was not quoted.

## Switches

`testPayoutRefundAndWithdrawalStayOff` sets `ReleaseMoneyWriteSwitch.testDerivation` back to `nil` and asserts payout, withdrawal, and refund are off. It sends nothing. The payout-account row is the read `POST api/merchant/payout-account` with no body; that test does not send it. Both IM mark-read switches were already pinned by `MiniProgramMerchantCoopContractPinTests.testIMReadPinsConversationIdAndStaysOff` and were not opened. Club settlement summary is not in this half (`pages/club/...` and `pages/coop/settlement-detail` sort before the split). `PayoutReceiverClient.settlementSummary` was not edited and was not flipped to GET.

## This half after the checker

| | Count |
|---|---|
| Rows | 87 |
| Matched | 10 |
| Missing endpoint | 13 |
| Missing test | 77 |

Matched was 6 on the base and is 10 now. Missing endpoint was 14 and is 13 (arrivals today gained a symbol; its test stays missing because there is no data object). Missing test was 81 and is 77.

The checker still reports the 4 journal rows as missing endpoint and missing test: it only keeps a literal API url, and these calls have none. The other 9 missing endpoints are the 3 url-forward calls, the 3 ternary calls, the templated aftercare list, and the two reply-recovery rows whose urls sit inside the outer `request(`.
