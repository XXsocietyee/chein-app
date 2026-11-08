# IWP-2 report — Order status / wallet / reservations

Branch `cloud/iwp-2` (from `origin/cloud/iwp-0`). Cloud builder: **nothing was compiled or run** (no Swift toolchain). Evidence layer: *source written and desk-checked* only.

## Files (all new; no existing file touched)
`Core/BundleOrderReadModel.swift`, `App/BundleReadTransport.swift`, `App/BundleOrderStatusView.swift`, `App/BundleWalletView.swift`, `App/BundleReservationsView.swift`, `Tests/CoreTests/BNDOrderReadModelTests.swift`, `Tests/AppUnitTests/BNDOrderStatusViewTests.swift`, plus `docs/owner-plan/iwp-2-new-strings.md` and this report.

## Public types
- `BundleActivation { pending, active, expired, refunded, unknown }` — from server status ints only: both ints present and `==2` → active (or `refunded` if every unit status is `REFUNDED`, `expired` if every balance has server `expired == true`); present but not 2/2 → pending; missing → unknown. No device clock, no money.
- `BundleBalanceRow`, `BundleReservationRow`, `BundleUnitRow` — value rows copied from IWP-0 types; balance `counts` verbatim; reservations in server order (never re-sorted).
- `BundleOrderReadModel` — `init(view: BundleOrderView)` (rich) and `init(order: FreeExploreLaunchOrder)` (thin, from the existing host entry; `hasBalanceDetail == false`); `isLegacy` when `bundle == nil`.
- `BundleReceiptPollState`, `@MainActor @Observable BundleReceiptPoller(requestId:delaysNanoseconds:fetch:sleep:)` — reads `order/receipt` with the original request id; stops on FOUND; NOT_FOUND / `.outcomeUnknown` / `.busy` keep polling; budget exhausted → `.stillUnconfirmed` (not failure, not proof of no write); other `FreeExploreLaunchFailure` → `.failed`; non-launch errors → `.readUnavailable`. Holds only a read closure (cannot create an order). Clock and backoff injected.
- App (internal): `BundleReadTransport` (exact GET allow-list: `order?registrationId=` and `order/receipt?requestId=` for bound ids; Authorization must equal captured token; 403 retires + `denied`; 1 MiB cap), `BundleOrderStatusPresentation`, `BundleOrderStatusView`, `BundleReceiptPollerBinding`, `BundleWalletView`, `BundleReservationsView`.

## Tests
`BNDOrderReadModelTests` (CoreTests): testActivationDerivedOnlyFromServerStatusInts, testLegacyOrderRoutesToLegacy, testReceiptPollStopsOnFoundAndNeverCreatesOrder, testBalancesRenderCountsFromServerOnly, testExpiredFlagComesFromServer, testReservationRowsSortedByStartAtAsServerOrder; extras: testPollExhaustionIsStillUnconfirmedNotFailure, testPollDefiniteFailureStops.
`BNDOrderStatusViewTests` (AppUnitTests, `@testable import Questify`, no QuestifyCore import): testNotFoundReceiptIsNotShownAsFailed; extras: testActivationKeysAreServerStatesAndNeverPaidCopy, testReadTransportAllowsOnlyBoundOrderAndReceiptGETs, testReadTransport403RetiresAndStaleSessionBlocks.

## Not verified / notes
- **Nothing compiled, nothing run.** Compile risks: `@Observable` + `@ObservationIgnored` on stored closures in a public class; `BundleOrderStatusView` custom init with `BundleReceiptPollerBinding`; `LabeledContent` with `if/else` label content; `Task`-captured `[weak self]` in `start()`.
- Core tests reuse `BNDFixtures` from `BNDContractsDecodingTests.swift` (same test target); fixture-string `replacingOccurrences` edits assume the exact IWP-0 fixture text.
- Test rig coupling: `#filePath`-based source scans assume the repo layout `Tests/CoreTests/<file>`.
- Activation semantics: only the 2/2 pair is documented (`bundle-gap.md §4`); any other int pair is shown as `pending`. Backend spec proposes a server `activation` field (additive) — switch to it when it exists.
- Localization keys are requested in `iwp-2-new-strings.md`; the `BundleCommerce` table does not exist yet, so views fall back to key text until IWP-L.
- Wallet is per order only (backend B-04 missing); `loadWallet` injection is left to IWP-9 composition (these views take an already-loaded model). Nothing mounted, no gate/lease/route changed, `Package.swift`/`.xcodeproj` untouched; new app files not in the Xcode project until the orchestrator regenerates it.
- Red-first step not performed.
