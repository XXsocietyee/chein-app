# cursor/cov4-tests-1

Branch cut from `ebf6c160ce73880807c07cf3cc10aa829e83d75e` and left there. That commit was the tip of `ui/combined-r7` when this branch was created. No rebase. `main`, `master`, `ui/main`, `ui/combined-r7`, `ui/combined-*`, and `ci/acceptance` were not pushed.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Counts are from `tools/check_mp_contract_coverage.py` (`collect`) on that tree plus this branch's `Core/` and `Tests/CoreTests/`. The checker does not parse JavaScript. It was not edited. `docs/mp-contract-coverage.md` was not edited. `AppSession.swift`, `AppCompositionRoot.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. No `swiftc`. No new endpoint. `Tests/CoreTests` is not in the Xcode project.

## Checker

| | before | after |
|---|---:|---:|
| rows | 1038 | 1038 |
| matched | 792 | 798 |
| missing endpoint | 115 | 115 |
| missing test | 242 | 236 |

Owned missing-test rows: 14, every one under `pages/club` (subpackageClub). Six of them now have a test the checker records. Eight stay missing-test. Endpoints added: 0.

## Rows owned

| MP file:line | method the call writes | path the checker reads | literal fields | test |
|---|---|---|---|---|
| `pages/club/badges/index.js:253` | POST | `api/club/badge/create` | clubId, badgeName, badgeDesc | `testBadgeCreatePinsPostAndLiteralFields` |
| `pages/club/components/cy/fe-reference-range/index.js:34` | GET | none | from, to | `testReferenceRangeExportQuotesGetAndLiteralFields` |
| `pages/club/detail/index.js:1037` | POST | none | none on the call | `testClubScanForwardsUrlAndQuotesPost` |
| `pages/club/event-ops/index.js:935` | POST | none | clubId, topicId, recurrenceType, startDate, startTime, occurrenceCount, customDates, capacity, defaultLeadMemberId, waitlistEnabled, offerMinutes; create also requestId; update also seriesId, expectedVersion | `testSeriesSaveQuotesPostAndLiteralFields` |
| `pages/club/event-ops/index.js:1259` | POST | `api/club/event-ops/attendance/correct` | clubId, activityId, memberId, arrived, expectedVersion, reason, requestId | `testAttendanceCorrectPinsPostAndLiteralFields` |
| `pages/club/governance/index.js:700` | identifier `requestOptions.method` (the options object writes POST) | `api/club/governance/cases/report` | clubId, reason, requestId, targetType, targetId, evidence | `testGovernanceReportQuotesPostAndLiteralFields` |
| `pages/club/governance/index.js:711` | identifier `requestOptions.method` (the options object writes POST) | `api/club/governance/cases/appeal` | clubId, reason, requestId | `testGovernanceAppealQuotesPostAndLiteralFields` |
| `pages/club/join-requests/index.js:196` | POST | none | clubId, memberId; reviewReason only when a rejection has a reason | `testJoinReviewQuotesPostAndLiteralFields` |
| `pages/club/notify/index.js:206` | POST | `api/club/event-notification/preview` | clubId, activityId, audienceType, channel, title, content, requestId | `testNotificationPreviewPinsPostAndLiteralFields` |
| `pages/club/notify/index.js:239` | POST | `api/club/event-notification/send` | clubId, activityId, audienceType, channel, title, content, requestId | `testNotificationSendPinsPostAndLiteralFields` |
| `pages/club/roles/index.js:428` | POST | `api/club/roles/assign` | clubId, targetMemberId, roleCode, requestId; activityId for an event role; customerPhoneVisible only for EVENT_CHECKIN when on | `testRoleAssignPinsPostAndLiteralFields` |
| `pages/club/roles/index.js:504` | POST | `api/club/roles/revoke` | clubId, assignmentId, version, reason, requestId; activityId when the assignment scope is EVENT | `testRoleRevokePinsPostAndLiteralFields` |
| `pages/club/settlement/index.js:186` | POST | none | clubId, personal | `testSettlementQuotesPostMineEmptyAndSummaryPersonal` |
| `pages/club/topic-story/index.js:274` | POST | none | club: clubId, topicId, nodeId. host: topicId, nodeId, scope | `testTopicNodeAnswerQuotesPostAndLiteralFields` |

Badge create's payload never carries `iconUrl`. Preview sends `requestId` null and `channel` `IN_APP`. Send sends a `requestId` string and the same `channel`.

The checker records a test on the six calls that already had a path and a literal method. Each of those bodies is `jsonBody(...)`, so the checker stored no field list and did not require one. The tests still quote the literal keys.

## Checker still will not pin

Eight owned rows stay missing-test. No path or method was invented for them.

The url is not one literal, so the checker keeps no path:

- `pages/club/components/cy/fe-reference-range/index.js:34` is a ternary of the payer and merchant routes plus `/export`.
- `pages/club/detail/index.js:1037` is `Object.assign` and forwards `url` and `data`.
- `pages/club/event-ops/index.js:935` is a ternary of `api/club/event-ops/series/update-future` and `api/club/event-ops/series/create`.
- `pages/club/join-requests/index.js:196` is a ternary of `api/club/join-request/approve` and `api/club/join-request/reject`.
- `pages/club/settlement/index.js:186` is a ternary of `api/club/settlement/mine` and `api/club/settlement/summary`.
- `pages/club/topic-story/index.js:274` is a ternary of `api/club/topic-node-answer` and `api/topic/host-node-answer`.

The method is an identifier, so a test cannot pin the row:

- `pages/club/governance/index.js:700` and `:711` forward `requestOptions.method`. The literal `POST` is on the options object at line 681, not on the call.

`api/club/settlement/mine` stays on `ClubCoreClubContractTests.testSettlementMinePinsEmptyPost`. `api/club/settlement/summary` stays on `ClubCoreClubContractTests.testSettlementSummaryPinsClubIdAndPersonalOnlyWhenAsked`. This class sorts after those tests.

## Money

`testPayRefundPayoutWithdrawalPaidOrdersQuoteCreateAndPricingConfirmSendNothing` sets `ReleaseMoneyWriteSwitch.testDerivation` back to nil. Payment, payout, withdrawal, and refund stay off. Quote, registration create, and pricing confirm throw before a request exists. Pay and refund-apply on `PlatformPass` throw `PlatformPassWriteRefusal.unreachable`. The transport recorded no request. Bind and unbind stay payout routes and are not called.

Settlement stays POST. `settlementClubs` posts `api/club/settlement/mine` with `{}`. `ClubGovernanceRead.settlement` is `{clubId}` and has no `personal` key. `settlementSummary` posts `{clubId, personal}`. `personal` is true only when the caller passes true (`personal=1`); the other call sends `personal: false`. Those two reads go to a test transport. No payout request is built.

## Tests added

Fifteen functions in `Tests/CoreTests/ZzZzZzCov4ClubContractPinTests.swift`. Fourteen quote the owned rows. The fifteenth is the money stay-off.

## Not taken

`subpackageMember/components/cy/profile/index.js:2109` still missing-test. Its pattern is `api/club/post/feed`, and its method is empty. The file is the member profile page, not `pages/club` and not the club subpackage. It was left there. No play, roam, merchant, or other member row was taken.
