# cursor-cov3-tests-1

Base `6afe54b4acee8786a9f3f3cbe8cd85d90be1e35a`. Branch `cursor/cov3-tests-1`. The branch stays on that commit. `main`, `master`, `ui/main`, and `ui/combined-*` were not pushed.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

Checker: `python3 tools/check_mp_contract_coverage.py --mp-root` that tree. `docs/mp-contract-coverage.md` was not edited. The totals below are the tool's print.

Owned files: `pages/play/`, `pages/playkit/components/play-stage/`, `subpackageJourney/`, `pages/playkit/components/playkit-journey-check/`, `utils/registration-seat.js`, `pages/team/utils/team-seats.js`. Roam, member, and merchant rows were not taken. `pages/play/merchant/` was left out with them.

## Counts

| count | value |
|---|---|
| checker total | 1038 |
| checker matched | 779 |
| checker missing_endpoint | 120 |
| checker missing_test | 256 |
| owned missing-test rows with an endpoint | 7 |
| tests added | 8 |
| owned rows the checker newly marks pinned | 0 |
| endpoints added | 0 |

The same command before the tests printed the same four counts. Matched does not rise. The seven calls pass `method` and `data` as identifiers, so the checker reads a path and does not read a method or a field list. A test cannot pin a row whose method is empty. The tests quote the path and do not invent a method or fields.

## Rows owned

| MP file:line | Core symbol | path the checker reads |
|---|---|---|
| `pages/play/index.js:420` | `OrientSessionService.current` | `api/play/orient/session/current` |
| `pages/play/index.js:421` | `OrientSessionService.prepare` | `api/play/orient/session/prepare` |
| `pages/play/index.js:422` | `OrientSessionService.path` | `api/play/orient/session/start` |
| `pages/play/index.js:423` | `OrientSessionService.abandon` | `api/play/orient/session/abandon` |
| `pages/play/index.js:424` | `OrientSessionService.path` | `api/play/orient/session/receipt` |
| `pages/play/index.js:427` | `OrientSessionService.path` | `api/play/orient/session/task/{}/result` |
| `pages/play/index.js:429` | `OrientScorePage.readPath` | `api/orient/scoring/session/{}` |

The quoted `GET` and `POST`, and the object keys, are in `pages/play/utils/orient-lifecycle.js`, which calls `send`. That call is not a checker row. The wrapper at the lines above is the row.

## Tests added

`Tests/CoreTests/PlayCov3ContractPinTests.swift`

- `testOrientCurrentQuotesThePathTheCheckerReads`
- `testOrientPrepareQuotesThePathTheCheckerReads`
- `testOrientStartQuotesThePathTheCheckerReads`
- `testOrientAbandonQuotesThePathTheCheckerReads`
- `testOrientReceiptQuotesThePathTheCheckerReads`
- `testOrientTaskResultQuotesThePathTheCheckerReads`
- `testOrientScoreQuotesThePathTheCheckerReads`
- `testQuoteCreatePayRefundAndPricingConfirmSendNothing`

## Left alone

`pages/playkit/components/play-stage/index.js` has no `request`, `req`, `sendRequest`, or `uploadFile` row. `pages/play/utils/stage-events.js` calls `analytics.track`. `PlayStageAnalyticsGate.enabled` stays false.

`subpackageJourney/utils/journey-api.js:11` forwards `url`. The checker marks it missing an endpoint. No path was added.

Seat calls that already have a test were not repeated: `subpackageJourney/pages/seats/index.js:67`, `subpackageJourney/pages/seats/index.js:79`, `subpackageJourney/pages/settle/index.js:121`, `utils/registration-seat.js:61`. `pages/team/utils/team-seats.js` has no request row.

## Money

Quote, create, pay, refund, and pricing confirm send nothing. `registrationQuote` and `registrationCreate` throw `PlayerContentMPContract.Refusal.moneyDisabled`. `pricingConfirm` throws `PlayerContentMPContract.Refusal.pricingGrantDisabled`. `Adapt5HighRiskWriteSupplement.refuseRegistrationPay` throws `Adapt5PayRefusal.blocked` and does not build a request. `PlatformPass.quote`, `payPassOrder`, and `refundApplyPassOrder` throw `PlatformPassWriteRefusal.unreachable`. The transport recorded no request.

## Not edited

`AppSession` and `AppCompositionRoot` were not edited. `project.pbxproj` was not edited. The checker was not edited. No `swiftc`.
