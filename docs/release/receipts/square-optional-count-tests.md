# square-optional-count-tests

Branch `ui/e1s`, base `5e2aeabb1`. Core tests only; not compiled or run here (no builds by instruction).

- Searched `Tests/` for old-contract expectations of `SquarePost.likeCount/commentCount` and `SquareComment.likeCount` as `Int` (compared with 0, 0-valued text, `SquareCountDisplay`). None found: `SquareDetailInteractionTests`, `CoreGapReaderBodyTests` and `AccountCollectionTests` already assert nil -> em dash, known 0 -> "0". No existing test was changed.
- Added `SquareOptionalCountModelTests`: model-level nil vs 0 for post and comment (omitted, null, negative, numeric string = nil; literal 0 = 0), `likeNum` alias, `SquareCountDisplay.text`.
- Not resolved: the 8 Square detail failures, 2 NativeChannel original-writer journal failures and 1 SquareReport case-reference failure reported by the integrator. Exact failing test names were not available; waiting for them.

## Round 2: the 7 named failures (code-only, not run)

All 7 were already failing on the base; none comes from the optional-count change (`SquarePost`/`SquareComment` do not feed these paths).

| tests | root cause | verdict | fix |
| --- | --- | --- | --- |
| SquareDetailPageReadyTests: testOmittedCountsStayUnknownAndLiteralZeroStaysZero, testKnownFactsDoNotBorrowAnotherField, testCommentPageDoesNotInventContinuationOrACount, testDebugFixtureDataCoversReadyUnknownZeroAndEmpty | Production bug. `SquareDetailWire.wholeNumber` rejected `value is Bool`; on Darwin a JSON number 0 or 1 parsed by JSONSerialization is an NSNumber that bridges to Bool, so a real 0 or 1 count showed an em dash. Every failing test has a 0 or 1 count. Introduced with 7e7896137 (pre-e1). | production | removed the `is Bool` test; the existing CFBoolean type-ID check still rejects JSON true/false. Same defect and fix in `AccountCollectionFavoritesWire.wholeNumber`. |
| NativeChannelMessageOriginalWriterJournalTests.testLegacyMultipartAllowlistDoesNotGainUnprovedReferenceFields | Stale test. The reviewed route now admits `reply_to_id` as `.quotedSend` (and mention fields as `.mentionedSend`); the test still expected nil. Same snapshot f9ca1f424 as the route. | stale test | asserts `reply_to_id` is exactly `.quotedSend`, a malformed reply id is nil, and any other reference field (channel, mapping revision, reference id, lone mention fields) is still nil. |
| NativeChannelMessageOriginalWriterJournalTests.testPlainReceiptCannotSettleReferenceButOriginalLookupKeyRemainsExact | Stale test. A reference intent's receipt goes through `originalQuotedReceipt`; a plain message with no state/proof is unknown and throws `.malformedResponse`, not `.notConfigured`. Still never settles; request key unchanged. | stale test | expects `.malformedResponse` (still a specific throw, not success). |
| SquareReportTests.testAcknowledgedCaseReferenceSurvivesCoordinatorReplacementWithoutStoringDescription | Stale DEBUG fixture. Recovery now reads the original request via `GET api/community-trust/reports/mine?requestId=`; `SquareReportFixtureTransport` had no such route and threw invalid. | stale fixture | fixture serves `reports/mine` for the exact requestId (the one submitted row) and an empty list otherwise. Test unchanged. |

Checks: `swiftc -parse` clean on touched files.
