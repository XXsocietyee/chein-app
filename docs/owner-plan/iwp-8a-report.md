# IWP-8a report — Reviews (T-13; EP-BND-20/22)

Branch `cloud/iwp-8a` (from `origin/cloud/iwp-0`). Cloud builder: **nothing was compiled or run** (no Swift toolchain). Evidence layer: *source written and desk-checked* only.

## Files (all new; no existing file touched)
`Core/BundleReviewClient.swift`, `Core/BundleReviewModel.swift`, `App/BundleReviewComposeView.swift`, `App/BundleReviewListView.swift`, `Tests/CoreTests/BNDReviewModelTests.swift`, this report, `iwp-8a-new-strings.md`.

## Public types
- `BundleReviewClient.swift`: `BundleReviewCommand` (rating 1…5, trimmed content 1…500 chars, key 1–64 `[A-Za-z0-9_-]`, throws `.invalid`), `BundleReview`, `BundleReviewMine` (eligible/reasonCode/review), `BundleReviewPage`, `@MainActor protocol BundleReviewServing` (`mine`, `list`, `submit`), `UnavailableBundleReviewClient` (every call throws `.disabled`).
- `BundleReviewModel.swift`: `BundleReviewStatusKind` (PENDING→underReview "审核中"/"Under review", APPROVED, REJECTED, HIDDEN, unknown), `BundleReviewPendingStore` (owner-bound durable command, `TemplateAuthoringStorage`), `BundleReviewComposeState`, `BundleReviewComposeModel` (load / submit / recover / retryOriginal), `BundleReviewListModel` (approved-only, de-duplicated, cursor paging).
- Views are unmounted, take their model by injection, strings are inline `W8Text.t` (listed in `iwp-8a-new-strings.md`).

## Behaviour encoded
Eligibility comes only from the server (`mine`); command persisted before dispatch; unknown outcome → read back via `mine`, re-send only the SAME persisted command (same key) and only after a read-back found nothing; business 409 `LOGIN_REQUIRED` keeps the pending command; any other business refusal is shown verbatim (`.rejected(code:)`) and releases it; a PENDING review is shown to its author as "under review", never published; the list filters to `APPROVED`.

## Tests (`BNDReviewModelTests`)
Required: `testComposeBlockedWhenServerSaysNotEligible`, `testPendingReviewShownAsUnderReview`, `testDuplicateReviewShowsServerCode`.
Extra: `testPendingCommandIsPersistedBeforeDispatch`, `testUnknownOutcomeReadsBackThenResendsSameKeyOnly`, `testReadBackFindingSameKeyResolvesWithoutResend`, `testLoginRequiredKeepsPendingCommand`, `testUnavailableDefaultNeverReturnsData`, `testListShowsApprovedOnlyAndDeduplicates`, `testCommandValidationBounds`, `testReviewDecodesWithStringIdsAndUnknownStatus`.

## NOT verified / decisions to review
- **Nothing compiled, no test run, red-first not performed.** Likely compile risks: `catch … where` patterns, `try?` on `Void` calls, `private` test doubles in signatures, `@MainActor` closure assigned to `onSubmit`.
- **No HTTP implementation.** EP-BND-20/22 do not exist; the wire shapes are from `bundle-backend-spec.md B-20` only, and the endpoint paths/response envelope are unconfirmed. The `mine` response (`eligible`, `reasonCode`, `review`) is an **assumption of this WP**; the spec does not define how the server reports eligibility. The concrete client + allow-listing transport belong to a later WP once the backend lands (could reuse `BundleAPIClient`'s private `fetch` pattern; not edited here, per rules).
- Business codes for duplicate/not-eligible are unknown; tests use synthetic codes.
- Views never rendered or previewed; accessibility identifiers are my own naming.
- Pending store holds the user's review text on-device until resolved (no token/credential).
- Not added to `.xcodeproj`; merchant reply (EP-21) intentionally out of scope. Nothing mounted, no gate/route/lease/composition change.
