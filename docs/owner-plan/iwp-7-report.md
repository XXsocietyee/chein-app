# IWP-7 report — Voucher appeal (T-12, EP-BND-19)

Branch `cloud/iwp-7` (from `origin/cloud/iwp-0`). Cloud builder: **nothing was compiled or run** (no Swift toolchain). Evidence layer: *source written and desk-checked* only. Tests were written together with the code; red-first was not performed.

EP-BND-19 does not exist in the backend (`bundle-gap.md` row 19, `bundle-backend-spec.md` B-19). Everything is built against `BundleAppealServing` with `UnavailableBundleAppealService` as default. No canned data anywhere. Copy says "submitted for review"; nothing says refunded/consumed/redeemed.

## Files (all new)
`Core/BundleAppealClient.swift`, `Core/BundleAppealModel.swift`, `Core/BundleAppealPendingStore.swift`, `App/BundleAppealView.swift`, `App/BundleAppealTransport.swift`, `Tests/CoreTests/BNDAppealModelTests.swift`, `docs/owner-plan/iwp-7-new-strings.md`, this report. No existing file, xcstrings or hot file touched; nothing mounted, no routes/leases, gates untouched.

## Public types
- `BundleAppealReason` (`MERCHANT_FORGOT_SCAN|OTHER`), `BundleAppealLimits` (6 refs, 500 chars; mirrored for early feedback, server validates again)
- `BundleAppealCommand` (Codable; `init(...) throws` validates note/refs/key `[A-Za-z0-9_-]{1,64}`)
- `BundleAppeal`, `BundleAppealReceipt` (`provesNoWrite == false`) — Decodable; status/applyState stay strings
- `protocol BundleAppealServing` (`submit`, `receipt(idempotencyKey:)`, `list(registrationID:)`), `UnavailableBundleAppealService` (throws `.disabled`), `BundleAppealHTTPClient` (concrete, never constructed in production)
- `BundleAppealPendingStore` (owner-bound, `load/save/clear`, never replaces an unresolved command)
- `BundleAppealPresentation` (`showsUnitAsRedeemed` always false), `BundleAppealState`, `BundleAppealModel` (`restore/submit/recover/retryOriginal/refresh`)
- App: `BundleAppealTransport` (allow-list: POST `…/voucher/appeal`, GET `…/voucher/appeal/receipt?idempotencyKey=`, GET `…/voucher/appeal?registrationId=`; Authorization == token, body ≤16 KiB, Content-Length, post-call recheck, 403 retires, 401 callback), `BundleAppealView`

## Behaviour
Command persisted before dispatch (no persist → nothing sent). Unknown outcome / malformed / stale → `awaitingReadback`; `recover()` reads back by the SAME key and never re-sends. NOT_FOUND keeps the command (not proof of no write); only explicit `retryOriginal()` re-sends the same key. Business refusal (e.g. already-open appeal) clears the lock and shows the server's `businessCode` verbatim. `LOGIN_REQUIRED`/401 keep the command. `disabled` clears and shows unavailable.

## Tests (`BNDAppealModelTests`)
Required: testSubmitPersistsCommandBeforeDispatch, testUnknownOutcomeReadsBackBySameKey, testSecondAppealForSameUnitBlockedByServerCodeShown, testApprovedAppealDoesNotShowUnitAsRedeemedUntilServerSaysSo.
Extra: testStorageFailureSendsNothing, testReceiptNotFoundKeepsCommandAndDoesNotResendAutomatically, testLoginRequiredKeepsPendingCommand, testCommandLimitsAndUnavailableDefault.

## NOT verified / deviations
- **Nothing compiled or run.** Compile risks: `@MainActor` local class in a test, `onChange(of:){_,_ in}` (matches existing usage), pattern `case FreeExploreLaunchFailure.response(_, _, let code)` on `Error`.
- Spec file list has the test only in `Tests/CoreTests`; transport/view have no tests (no `Tests/AppUnitTests` file allowed by the WP).
- Wire shape of `<Appeal>`, the receipt envelope (`{idempotencyKey, receipt: FOUND|NOT_FOUND, appeal}`) and list envelope (`{items:[…]}`) and business codes are **guesses** from B-19 text; the backend does not exist.
- Evidence uploads: view takes `evidenceRefs` as a binding; hooking the existing own-media uploader (`Core/OwnMedia*`, `ProjectTopicImageUpload`) was not done — those take typed project contexts, so the host (IWP-9) must supply media ids. Not wired.
- Copy uses inline `W8Text.t` (no catalog keys); strings listed in `iwp-7-new-strings.md`. Not added to `.xcodeproj`.
