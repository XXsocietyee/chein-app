# Cloud G2 — bundle transports, factories, refund apply/progress

Branch `ui/cloud-g2-bundle` from `origin/ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`.
Pushed only this branch. `main`, `rc`, and `ui/main` were not pushed.

## What landed

IWP-9 wiring plus the IWP-R refund skeleton from `docs/owner-plan/bundle-ios-spec.md`.

- `AppCompositionRoot.bundleApprovals` is a `BundleApprovalSet`. Every closure defaults to nil (`.closed`).
- `AppSession.makeBundlePorts()` forwards to `AppCompositionRoot.makeBundlePorts(session:)`.
- Factories for read, cancel, appeal, transfer, and refund live in `App/BundleComposition.swift`. A factory returns a transport or client only when a matching `BundleFeatureApproval` is accepted for a reviewed China deployment whose market, base URL, and storage namespace match the signed-in session. Shipped composition never supplies an approval, so every provider stays nil and no transport is constructed.
- Shelf, voucher, offer, review, and renewal return the existing unavailable clients only behind an accepted approval. Without an approval they stay nil.
- Refund apply is `POST /api/free-explore/bundle/order/refund` with body keys exactly `registrationId`, `unitIds`, `idempotencyKey`, `expectedRoute`, `expectedAmount`. Progress is `GET` of the same path with `registrationId`. `expectedRoute` and `expectedAmount` are the server quote's `route` and `amount.text`, copied verbatim.
- Apply is whole-order only. A proposed unit set that is not the full order is rejected. The apply screen has no unit picker.
- `showsRefunded` is true only for the exact server state `REFUNDED`. `PROCESSING`, `PENDING`, `HELD`, `REFUND_PENDING`, `APPROVED`, `UNKNOWN`, `MANUAL_PAYOUT`, `MANUAL`, `REJECTED`, and any other string are not shown as refunded.
- Apply and progress screens are unmounted. No route, catalog, `ProfileOrdersView`, `FreeExploreBundleReadEntry`, or `RegionalLaunchConfiguration` change. `makeComposition(reviewed: nil)` still returns unconfigured. `FreeExploreCancelFactory.makeCanceler` still returns `GatedFreeExploreReservationCanceler`. Reservation dispatch stays default false.

`makeFreeExploreBundleReadHost` moved into the composition extension so `AppSession` stays at 8181 lines and `AppCompositionRoot` shrinks from 4507 to 4498. The ratchet ceiling for the composition file is now 4498. `makeTransport`, `composition`, and `expireIfMatching` are internal so the extension can build transports and retire a session on 401.

## Money gates (all closed)

`ReleaseMoneyWriteSwitch` was not edited.

- `paymentEnabled = false`
- `payoutEnabled = false`
- `withdrawalEnabled = false`
- `virtualGoodsEnabled = false`

`BundleMoneyWriteGate.allowsRefundApply` is a separate constant `false`. It does not read `ReleaseMoneyWriteSwitch`, so flipping that switch does not open a refund POST. `BundleRefundHTTPClient.permitsWrites` ANDs the gate with `writeAllowed()`. A caller that passes `writeAllowed: { true }` still cannot POST. Pre-send refusal is `.disabled`, not `outcomeUnknown`. Cancel, appeal, and transfer writes stay behind `permitsWrites`, which shipped composition never sets true.

An unknown apply outcome keeps the idempotency key on the in-memory model and does not POST again for the life of that model. `refresh()` is GET only. There is no durable refund journal: IWP-R's file list does not include one, and the closed gate means no refund POST leaves the device.

## Tests

- `Tests/AppUnitTests/BNDMountGuardTests.swift`: `testShippedCompositionStillUnconfigured`, `testNoBundleProviderNonNilInShippedBuild`, `testReservationDispatchStillOffByDefault`, `testCancelFactoryStillGatedByDefault`, plus money-switch and closed-factory checks.
- `Tests/CoreTests/BNDRefundProgressModelTests.swift`: verbatim quote route and amount, partial selection rejected, processing/unknown/manual payout/approved are not refunded, unavailable client does not apply, a closed gate does not send even when the write closure is true, progress GET does not treat processing as refunded, and a source scan rejects client-side amount math.

## Checks

`python3 tools/check_scaffold.py` PASS after `python3 tools/generate_project.py`:

- missing_keys 0, untranslated_values 0, key_identifier_mismatches 0, gaps 0
- release config, privacy manifest, design lint, appsession ratchet, page route table (248), structural checks (4467 Swift files, 14711 bilingual keys)

This VM has no Swift toolchain. `swift`, `swiftc`, and `xcodebuild` are absent, so the new tests were not compiled or executed. Evidence is source review plus `check_scaffold.py`.

## Safety checklist

1. Shipped build still resolves `reviewed: nil` to unconfigured. `RegionalLaunchConfiguration` was not edited.
2. New writes sit behind an approval whose `permitsWrites` defaults false, plus an exact-URL transport. Refund POST also requires `BundleMoneyWriteGate.allowsRefundApply`, which is false.
3. No literal price, refund amount, threshold, or sample voucher was added. The amount shown is the server quote text. A source-scan test rejects `Decimal(`, `Double(`, `NumberFormatter`, and `0.20` in the new refund files.
4. UNKNOWN keeps the same in-memory idempotency key and does not POST again. It is not written to disk.
5. The apply screen says the refund is not available yet and that no refund is sent. The submit control is compiled only inside `if model.canApply`, which is false while the gate is closed.
6. No token, code, or phone is written to logs, storage, pasteboard, or analytics by these files.
7. File set is the composition/session wiring, the refund skeleton, the mount-guard tests, the regenerated Xcode project and unit-test shards, and this receipt. Full `Tests/CoreTests` and `Tests/AppUnitTests` were not run (no Swift toolchain). Do not treat this receipt as a green suite.
