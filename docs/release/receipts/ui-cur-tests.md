# ui-cur-tests

Handover 43. Core test coverage for service requests added in `04b244ff9..ui/main` (`a2a9d82e7`). Parent of this branch is that tip.

`App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, and `App/AppCompositionRoot.swift` are unchanged. `docs/release/contract-failing-baseline.txt` is unchanged. No completeness-matrix import. `ReviewedAreaSwitch` is not redeclared.

`swiftc` is not on this machine. XCTest was not run. No typecheck is claimed.

curl to TEST 8120 was **not run**. Decoder fixtures below are copied from complete JSON already stored in this repo. A truncated log line is not a body.

## What counts as a new request

A new request is an HTTP call whose sending code was added under `Core/` in that range. Path strings that only flipped in `ChinaReviewedRouteCapability`, and the extra `CityGameProductionLease.paths` entries, are catalog or lease text. The city-game services that already send those routes (`CityActionBudget*`, `CityAcquisitionService`, `CityNeutralTaskService`, `CityOnsiteTaskService`, `CityArrivalEvidenceService`, `CityMerchantOperationsService`) are not in the diff.

`IMPreviewTemplateLease` issues a route object. It does not open a transport. `Tests/CoreTests/IMPreviewTemplateLeaseTests.swift` already covers it.

## Requests

| Request | Coverage |
|---|---|
| POST `api/club-compensation/quality/evidence` | new stub `ClubGapClientTests.testRemainingCatalogCallsPinMethodAndPath` |
| POST `api/club/activity/cancel` | new stub, same test |
| POST `api/club/activity/detail` | new stub, same test |
| POST `api/club/activity/join` | new stub, same test |
| POST `api/club/channels` | already `ClubGapClientTests.testSuccessRequiresHTTPAndBodyCodeAndUnknownStaysAnEmDash` |
| POST `api/club/events` | new stub, same catalog test |
| POST `api/club/events/Checkin` | new stub, same catalog test |
| POST `api/club/events/proxy-enroll` | new stub, same catalog test |
| POST `api/club/events/save` | new stub, same catalog test |
| POST `api/club/group-code` | new stub, same catalog test |
| POST `api/club/group-code/save` | new stub, same catalog test |
| POST `api/club/join-requests/apply` | new stub, same catalog test |
| GET `api/club/lead` | already `ClubGapClientTests.testMerchantWriteIsWithheldAndLeadUsesGET` |
| POST `api/club/notices` | new stub, same catalog test |
| POST `api/club/notices/send` | new stub, same catalog test |
| POST `api/club/post` | already `ClubGapClientTests.testGuestPostSendsAndASignedOutWriteDoesNot` |
| POST `api/club/post/operation` | new stub, same catalog test |
| POST `api/club/post/operation/comment` | new stub, same catalog test |
| POST `api/club/roles` | new stub, same catalog test |
| POST `api/club/settlements/export` | already `ClubGapClientTests.testExportStaysUnsentUntilPayoutAndNeverTreatsAnErrorAsSuccess` |
| POST `api/club/workbench` | new stub, same catalog test |
| POST `api/coop` | new stub, same catalog test |
| POST `api/coop/invite` | new stub `ClubGapClientTests.testMerchantInvitePinsPostWhenTheWriteSwitchIsOn` |
| GET `api/external-game/signing-key` | already `ExternalGameReviewClientTests.testCatalogDownloadAndUnknownSubmitKeepsTheRequestID` |
| GET `api/external-game/catalog` | already, same test |
| POST `api/external-game/submissions` | already, same test |
| GET `api/external-game/submissions/mine` | new stub `ExternalGameReviewClientTests.testUncoveredReadsPinGetPaths` |
| GET `api/external-game/catalog/{gameID}` | new stub, same test (`downloadApproved`) |
| GET `api/external-game/catalog/{gameID}/package` | new stub, same test (`downloadPackage`) |
| POST `api/external-game/submissions/{id}/cancel` | new stub `ExternalGameReviewClientTests.testCancelResubmitAndReportPinPostPaths` |
| POST `api/external-game/submissions/{id}/resubmit` | new stub, same test |
| POST `api/external-game/reports` | new stub, same test |
| POST `api/user/info` (member counters) | already `MemberHomePageReadyTests.testCountersComeFromUserInfoWhenTheSessionReadHasNone` |
| GET `api/game/session/view` (`perspective=PLAYER`) | already `PlayGapPartialsTests.testTeamBackpackReadsThePlayerProjectionAndMergesTeamScope`. `PlayTeamBackpackHTTP` is a second caller of that same request |
| POST `api/game/session/command` (ITEM_USE / ITEM_DISCARD / ITEM_RECEIVE) | already `PlayTeamItemCommandTests.testCommandClientKeepsUnknownOffTheSuccessPath` |
| POST `api/activity/list` | already `ProductionPlayFinishRouteTests.testReaderPostsActivityList` |
| POST `api/compliance/consents` (activity sign-up) | already `RegistrationServiceTests.testActivitySignupConsentUsesSortedJSONAndNoPaymentField` |
| POST `api/team/create` | already `OperationHTTPAdapterTests` (the new file only checks the body). Closed lease: `TeamCreateClosedLeaseTests` |
| POST `api/workshop/v2/purchased/list` | new stub `WorkshopPurchasedV2PathTests.testListAndDetailPostTheV2Paths` |
| POST `api/workshop/v2/purchased/detail` | new stub, same test |

`ExternalGameReviewPaths.detail` is a path helper. No method sends it.

Counts: **27** requests got a new stub pin (18 club catalog + merchant invite + 6 external-game + 2 workshop v2). **13** requests already had a stub or a built-request assertion and were left alone.

## Decoders

Real bodies, cited, not relabeled:

| Body | File | Test |
|---|---|---|
| `{"msg":"请求路径不存在","code":404}` for GET signing-key, catalog, and submissions/mine | `docs/release/e2e/20261113b/requests.batch1.log` lines 5, 8, 11 | `testCapturedRouteAbsentBodyDoesNotDecodeAGame`. The mine stub also returns this body with status 404. It is not a catalog or a key |
| POST `api/activity/list` empty page | `docs/release/e2e/20261113b/requests.batch1.log` line 15 | `testCapturedEmptyActivityListDecodesNoRows` |
| POST `api/user/info` | `docs/release/e2e/20261113b/requests.batch2.log` line 68 | `testCapturedUserInfoKeepsLiteralZeros`. Literal 0 stays `0`. A missing count stays `—` |
| POST `api/compliance/consents` | `docs/release/e2e/requests.02-home.log` line 2 | `testCapturedConsentEnvelopeIsAccepted`. The captured scene is `home_city_location`, not activity sign-up. The service only requires `code` 200 |

`docs/release/e2e/20261113b/requests.batch4.log` line 41 (`GET api/play/nodes`) is cut off at `"imgArr":nul`. That is not a body. The null-option decoder change has **curl NOT RUN** and no new fixture.

curl NOT RUN, so no decoder fixture, for:

- every new `ClubGapClient` path (no complete captured body for those exact paths)
- GET `api/external-game/catalog/{gameID}`, GET `.../package`, POST cancel, POST resubmit, POST reports
- POST `api/workshop/v2/purchased/list` and `detail`
- the truncated `api/play/nodes` line

The new club, external write, catalog-detail, package, and workshop stubs return an empty 500 or 503. They assert method and path only. They do not treat that empty payload as a TEST capture.

## Checks

- `python3 tools/generate_project.py` completed (3595 native sources). It reordered two existing id lists in `Questify.xcodeproj/project.pbxproj`. No App or Core source was added by hand.
- `python3 tools/check_scaffold.py` PASS (structural checks, bilingual catalog, appsession ratchet, page route table).
- `python3 tools/check_design_lint.py` PASS (1613 App Swift files, allowlist unchanged at 30 files / 46 existing violations).
- `swiftc` was not run. XCTest was not run.
