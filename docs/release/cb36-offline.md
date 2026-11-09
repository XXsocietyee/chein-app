# CB36 offline and unknown-result paths

Base `origin/rc/20261108` `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. Branch `cursor/cb36`.

This note is an audit of how Core network call sites treat an unknown result: keep the original request id, and query that original receipt when a route already exists. It does not add a receipt route, a US API URL, a payment route, or legal copy. Payment and withdrawal gates are unchanged. Password login, bank-card withdrawal, and virtual goods stay off. `Config/Base.xcconfig` stays at `0.1.0` (`1`) with an empty `QUESTIFY_API_BASE_URL` and an empty `QUESTIFY_SESSION_REALM`.

`Core/` has 1802 Swift files. 341 of them mention `transport.send` or `.send(`. The audit grouped those call sites by the unknown-result contract. It did not rewrite them, and it did not migrate CB26–CB31 views.

## What was wrong

`MerchantGameNodeHTTPService.readReceipt` queried `api/game/session/receipt` whenever a configuration and a session existed. A `.disabled` execution and the empty `MerchantCityNPCParityGates.reviewedEndpoints` allowlist did not stop that GET. A nil configuration failed inside `send` as a private network error, which the public method mapped to `.networkError`, so the caller never saw `APIError.notConfigured`.

`MerchantGameNodeContentReader.readReceipt` did not send, but it returned a writes-disabled business error instead of `APIError.notConfigured`. That reader is the production binding. It still has no receipt route.

## What changed

The original request id is still the only id used on the receipt query. No new id is minted.

- `MerchantGameNodeHTTPService.readReceipt` throws `APIError.notConfigured` before `send` when `configuration` is nil, when execution is not the offline harness, or when the harness transport is not `MerchantContentOfflineTransport`. The reviewed gate can still name `api/game/session/receipt`, but `stationCommands` stays `false` and `reviewedEndpoints` stays empty, so production does not send.
- The DEBUG offline harness (`injectedOfflineHarness` plus `MerchantContentOfflineTransport`) still GETs `api/game/session/receipt` with that same `requestId`. `testUnknownWriteLocksAndOnlyExactReceiptReleases` still covers that path.
- `MerchantGameNodeContentReader.readReceipt` throws `APIError.notConfigured` and does not call the content service.
- `MerchantGameNodeCoordinator.confirmUnknownWrite` catches that error, clears the in-flight read, and leaves the unknown lock in place. Retry still resubmits the frozen command.

`permitsWrites`, `stationCommands`, and the payment and withdrawal gates were not edited.

## Missing route, unconfigured client

These paths already throw `APIError.notConfigured` before the underlying `transport.send`, and they still do:

- `BusinessRuntimeTransport.send` when `permits` is false.
- `GroupPollService.permit` when the path is not in `enabledPaths`, including `creationReceipt`. Covered by `GroupPollOptionalRecoveryTests.testIndependentReceiptRouteUsesExactGETAndDefaultOff` and `GroupPollTests.testNoGrantNoRequestsAndCreateGrantCannotReadOrVote`.
- `ClubActionWriting` recovery when the service, approval, or session does not match.
- `MerchantContentService` envelope construction when `configuration` is nil.

The game-node receipt query now follows the same rule. Invalid receipt parameters still return the existing parameter business error and still do not send.

Other domains already refuse before `transport.send`, but their locked error is a domain error rather than `APIError.notConfigured`. Those errors were left in place:

- City original receipt and action-budget receipt throw `disabled` when the read grant is nil, then GET `api/city-game/{domain}/request/{requestID}` only for that same id.
- Square report `original` reads with the original `requestId` only when `readsEnabled` is true; the default throws `SquareReportFailure.disabled`.
- Play experience `originalActionReceipt` throws `PlayExperienceError.disabled` unless reads are enabled, and it keeps the original route action id.
- Project edit `terminalReceipt` throws `ProjectEditError.notConfigured` unless the approval names the read path. The UUID-only overload returns nil and does not send.
- Invoice launch checks `enabled()` before its exchange.

## Same request id, no invented receipt route

These sites already keep the unknown lock without a new receipt endpoint. No route was added:

- Registration create keeps the caller request id. `RegistrationService` states that no lookup-by-requestId contract exists. Status is read by registration id.
- Team `receipt(operationID:)` returns nil and does not send. Live team mutations stay unsent without an approval.
- NPC chat deletion does not add a request id and does not resend a lost response (`NPCChatDataTests.testDispatchedRequestWithLostOrUnreadableResponseIsUnknownAndNotResent`).
- City player value retries the exact original body (`CityPlayerValueRecoveryTests.testUnknownBeginExplicitRetryPreservesExactBody`).
- Play session recovery reads the original receipt before changing the projection (`PlayGameSessionRecoveryTests.testRefreshUnknownReadsOriginalReceiptBeforeChangingProjection`).

## Payment and withdrawal

Not modified. `MerchantAICommerceGates.paymentAndCashEnabled` is still the constant `false`. `BusinessRuntimeConfiguration` still defaults `bankChallengeActions` to `[]` and `selfPlayPayment` to `false`. `MerchantCityNPCParityGates.stationCommands` stays `false`. Offer withdrawal, bank withdrawal, workshop commerce, wallet cash, and order payment files are not in this diff.

## Tests added

Swift tests, not executed on this VM:

- `MerchantGameNodeCoordinatorTests.testUnconfiguredOriginalReceiptFailsBeforeAnyRequest`
- `MerchantGameNodeCoordinatorTests.testUnknownWriteStaysLockedWhenOriginalReceiptIsNotConfigured`

Source check, executed here:

- `python3 -m unittest Tests.ContractChecks.test_cb36_offline Tests.ContractChecks.test_w2_19_gameNode`

No existing test was deleted, weakened, or renamed.

## Not run

This VM has no `swift`, `swiftc`, `xcodebuild`, or `xcrun`. Not run:

- `swift test`, `swift build`, `xcodebuild`, `xcrun`
- `flutter test`, `flutter analyze`
- deploy, TestFlight, or any request to `47.103.124.64`
- refresh of `tools/current_ci_manifest.json`

A green Python source check is not a Swift compile or a Swift test pass.
