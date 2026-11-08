# IWP-5 report — Voucher + redeem result (T-07, T-08)

Branch `cloud/iwp-5` (from `origin/cloud/iwp-0`). Cloud builder: **nothing was compiled or run** (no Swift toolchain). Evidence layer: *source written and desk-checked* only.

**Backend status:** endpoints B-09 (voucher), B-10 (voucher/version), B-17 (redemption/result) do not exist (`bundle-gap.md` rows 09/10/17). Per the rules this WP ships only value types, a protocol, an `unavailable` default, the presentation model and unmounted views. No HTTP client, no canned data, nothing wired into AppSession/AppCompositionRoot, no routes, no gate changes.

## Files (all new; nothing existing edited)
`Core/BundleVoucherClient.swift`, `Core/BundleVoucherModel.swift`, `App/BundleVoucherView.swift`, `App/BundleRedeemResultView.swift`, `Tests/CoreTests/BNDVoucherModelTests.swift`, `docs/owner-plan/iwp-5-new-strings.md`, this report. IWP-0 files untouched. (`Resources/xcstrings` untouched; strings are only listed.)

## Public types
- `BundleVoucher`, `BundleVoucherSubCode` — plain value types (not `Decodable`: wire shape is unverified, so decoding belongs to the future real client). `description`/`debugDescription`/`customMirror` redact codes (`bundleVoucherRedactedCode`).
- `BundleVoucherFetchOutcome`, `BundleVoucherVersionOutcome` (`version(_, pollIntervalHint:)`), `BundleRedeemOutcome` (`success/review/rejected/notRedeemed/unknown(String)`, `init(serverValue:)`), `BundleRedeemResult`, `BundleRedeemResultOutcome`.
- `@MainActor protocol BundleVoucherServing` (voucher / version / redeemResult) + `UnavailableBundleVoucherClient` (every call → `.unavailable`).
- `BundleVoucherModel` (`ObservableObject`): `appear()`, `disappear()`, `reload()`, `loadRedeemResult(unitID:)`, internal `pollOnce()`; state `BundleVoucherState`, `BundleRedeemResultState`; `BundleRedeemPresentation` (unknown outcome → `.processing`).
- Behaviour: polls only while visible; `disappear()` cancels the loop, bumps a generation (in-flight results are discarded) and drops the voucher from memory; full voucher refetched only when polled version differs from the one on screen; interval ≥5 s, server hint honoured (clamped 5–60 s), exponential backoff on failure (10, 20, 40, 60 s cap), reset on success; `.unavailable` stops polling. Injected `sleep` closure (no real clock in tests beyond a 1 ms sleep in one test).
- Views `BundleVoucherView`, `BundleRedeemResultView`: internal, unmounted. Codes are `privacySensitive`, not selectable, hidden while `scenePhase != .active`.

## Tests (`BNDVoucherModelTests`)
Required: testPollStopsWhenViewDisappears, testRefetchOnlyOnVersionChange, testCodeNeverPersisted, testUnknownOutcomeRendersNeutral, testVersionPollBackoffOnFailure. Extra: testUnavailableDefaultShowsUnavailableNotData.

## NOT verified
- Nothing compiled or run. Risks: `Mirror(_:children:)` dictionary-literal overload, `dump(_, to:)`, `@Published` in a Core file (mirrors `FreeExploreCancelModel`), `[weak self]`/`guard let self` inside the polling `Task`.
- `testPollStopsWhenViewDisappears` uses a 1 ms real sleep and a bounded wait loop; could be timing-sensitive.
- `testCodeNeverPersisted` can only prove no code in `UserDefaults.standard` and redacted printing; it cannot prove absence from other stores (the model has no storage dependency by construction).
- Screen-capture convention: grepped `isCaptured`/`userDidTakeScreenshot`/`capturedDidChange` in App/ and Core/: no existing convention found. The view hides on inactive scene and marks text private; it does not detect screen recording.
- Wire shapes follow `bundle-backend-spec.md` B-09/10/17 (spec only, no real responses). `main.code` semantics are an open owner question (spec Q5).
- Views never rendered (no previews, no UI tests); strings missing from any catalog until the orchestrator adds them (`iwp-5-new-strings.md`). Not added to `.xcodeproj`.
- Red-first step not performed.
