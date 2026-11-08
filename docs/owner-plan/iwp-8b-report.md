# IWP-8b report — Renewal intent (T-14; EP-BND-23)

Branch `cloud/iwp-8b` (from `origin/cloud/iwp-0`). Cloud builder: **nothing was compiled or run** (no Swift toolchain). Evidence layer: *source written and desk-checked only*. Backend EP-BND-23 does not exist yet; no real data path was built.

## Files (all new; IWP-0 files untouched)
- `Core/BundleRenewalClient.swift`
- `Core/BundleRenewalModel.swift`
- `App/BundleRenewalIntentView.swift`
- `Tests/CoreTests/BNDRenewalModelTests.swift`
- `docs/owner-plan/iwp-8b-new-strings.md`, this report

## Public types
- `BundleRenewalIntent` (`WILL_RENEW|MAYBE|NO`, CaseIterable)
- `BundleRenewalCommand` — throwing init; note trimmed, blank→nil, >200 chars rejected (never truncated); key 1–64 `[A-Za-z0-9_-]`
- `BundleRenewalRecord` (Decodable) — id, registrationId, holderMemberId?, intent (String), note?, supersedesId?, idempotencyKey?, createTime?; no money field; unknown keys ignored
- `@MainActor protocol BundleRenewalServing` (`isCurrent`, `permitsWrites`, `latestIntent`, `submitIntent`)
- `BundleRenewalUnavailableService` — default; every call throws `.disabled`, `permitsWrites == false`
- `@MainActor @Observable BundleRenewalModel` — `load/submit/retry/recover/retire`, `phase`, `latest`, `canSubmit/canRetry/canRecover`
- `BundleRenewalIntentView` (internal, unmounted)

Behaviour: latest wins by server record id (older record never replaces a newer one). Unknown write outcome keeps the pending command and retries with the SAME key; `recover()` resolves only if the server echoes that key (a read without it proves nothing). Definite refusals (`.response`, `.invalid`, `.staleSession`, `.busy`, 401) clear the pending command. Copy states intent only; the view has no price/payment/purchase vocabulary.

## Tests (`Tests/CoreTests/BNDRenewalModelTests.swift`)
Required: `testRenewalNeverShowsPriceOrPaymentUI`, `testLatestIntentWins`.
Extra: `testDefaultServiceIsUnavailableAndNeverWrites`, `testSubmitBlockedWhenWritesNotPermitted`, `testUnknownOutcomeRetriesWithSameKeyAndNeverRekeys`, `testRecoverResolvesOnlyWhenServerEchoesTheKey`, `testDefiniteRefusalClearsPendingAndAllowsNewSubmit`, `testCommandValidation`, `testRetiredModelHidesDataAndStopsWork`.

## NOT verified / gaps
- **Not compiled, no test run.** Risks: `@Observable` in Core with `@testable` private test double; `Mirror` field check; `onChange(of:)` two-arg form (iOS 17 ok); `TextField(text:axis:label:)`.
- `testRenewalNeverShowsPriceOrPaymentUI` locates the view via `#filePath` (needs source tree at test time) and does a substring scan; the forbidden list includes "order" and "pay" and may need tuning if the view later adds legitimate text.
- **No HTTP client**: the `<RenewalIntent>` response shape and exact path under `/api/free-explore/bundle/` are unconfirmed (backend spec only), and `BundleAPIClient.fetch` is private and IWP-0 files must not be edited. A concrete `BundleRenewalServing` must be added once B-23 ships.
- **Pending command is memory-only.** A durable owner-bound store (spec: "durable pending command") is not in the 8b file list; an app restart loses an unknown-outcome command (the server key is then unrecoverable client-side). Needs an owner decision to add a store file.
- Strings table `BundleCommerce` does not exist yet; keys listed in `iwp-8b-new-strings.md`. Eligibility window (≤30 days after valid_to) is server-side and unverified.
- Not added to `.xcodeproj`; nothing mounted; no gates touched.
