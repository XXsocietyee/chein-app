# ui/cur-offline-tests

Tests only. No product behavior, restyle, layout, or copy change.

## Source branches

- Created `ui/cur-offline-tests` from `origin/ui/cur-merchant-mode` at `353a9710b47c6b603f197cb6a6b244220fdb3599`.
- Merged `origin/ui/h-offline-2` at `d65e36f51d4b1f3fc9e8e7e10005e82531b79c40`.
- `ui/cur-merchant-mode` and `ui/h-offline-2` were not moved. `ui/main`, `master`, `ui/next`, `rc`, and `rc/20261108` were not pushed. No force-push.

Merge conflicts:

- `Core/AuthService.swift` keeps the ui/main `RequestReferenceLedger.shared.record` and the offline-2 response headers.
- `docs/release/completeness-matrix.csv` keeps the ui/main rows and appends only the new PKG-63 ids (`PKG-63-READ-RETRY`, `PKG-63-MONEY-NO-REPLAY`, `PKG-63-WRITE-QUEUE`, `PKG-63-OFFLINE-BANNERS`). No DONE row was replaced with MISSING.
- `App/RegionalLaunchConfiguration.swift` kept the ui/main switches and the `ReadRetryHTTPTransport` wrap from offline-2. It was not edited again. `moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` were not opened for `https://www.chengyinhub.com`.
- No methods were added to `App/AppSession.swift` or `App/AppCompositionRoot.swift`.
- `ReviewedAreaSwitch` stays one enum in `App/ReviewedAreaSwitch.swift`.
- `App/OwnerDecisionFixtureHost.swift` and `App/OwnerDecisionPayoutViews.swift` were not re-added.
- `docs/release/contract-failing-baseline.txt` was not edited.
- Merchant-mode behavior from `353a9710` stays: `adoptSignedInAccount`, `initialRequestedMode`, and the consumer hold.

## Queue

The queue under test is `OfflineIdempotentWriteQueue` (`Core/OfflineIdempotentWriteQueue.swift`). Screen opt-in goes through `OfflineWriteCaptureContext` and `SessionOfflineSyncModel.performWriteOptIn`, which enqueues on that same type. No second queue was added.

Host for the new tests is `https://8120.example.test` with an in-memory `HTTPTransport`. Nothing in these tests is sent to `www.chengyinhub.com`. The production-host case expects `APIError.notConfigured` and an empty transport log.

This VM has no `swiftc`. These XCTest cases were not executed.

## Five offline cases

1. Opt-in. Already implemented. `OfflineWriteCaptureTransport` records a pre-send unreachable write only while `OfflineWriteCaptureContext.current` is set. `SessionOfflineSyncModel.performWriteOptIn(routes:)` then enqueues only a path in that route list. A write with no capture context is not queued. A path outside the named routes (for example `/api/capsules/create` while opted into `/api/play/feedback/submit`) is not queued. A path with no idempotency spec (`/api/play/action`) is refused with `routeNotIdempotent`.
2. Retry reuses the same idempotency key. Already implemented. `flushPending` replays `OfflineQueuedWriteItem.idempotencyKey` and the stored body. A pre-send failure leaves the item queued; the next flush sends that same key. It does not mint a new one.
3. Money writes are never queued. Already implemented. `enqueueOfflineWrite` throws `moneyWriteNeverAutoReplayed` for `/api/pay/create`, `/api/merchant/payout-account/save`, and `/api/withdrawal/create`. Production switches were not opened. `ChinaReviewedProductionTransport` refuses `https://www.chengyinhub.com/prod-api/api/pay/create` before the in-memory transport sees it.
4. Free versus paid registration. Already implemented for the guard that exists. `BackendIdempotentWriteRouteCatalog.isMoneyOrCashSensitiveRequest` treats `/api/registration/create` as paid when `payChannel` is a non-empty string or when `payableAmount`, `payAmount`, or `totalAmount` is a JSON number greater than zero. That paid request is not queued. A create body with none of those fields is queued. The guard does not treat a numeric string as an amount. That distinction was not added. `payChannel` and `payableAmount` were already covered by `testRegistrationCreateAllowsFreeAndExcludesPaidMoneyRequests`; this commit adds `payAmount` and `totalAmount`.
5. Replay order. Already implemented. `enqueueOfflineWrite` appends, and `flushPending` walks `.queuedOffline` items in that array order. Three opted-in writes replay as feedback, then capsules, then exploration goals.

## Merchant mode

Not duplicated:

- `Tests/CoreTests/HomeSearchTabParityTests.swift` `testConsumerAndMerchantRootTabBarSpecifications` already covers `initialRequestedMode`: role `merchant` or `userType` 2 requests merchant; a player stays consumer.
- `Tests/AppUnitTests/MerchantWorkbenchRemindersTests.swift` already covers `adoptSignedInAccount` and the consumer hold.
- `MerchantRootModeCoordinator` stays in App. It was not moved into Core.
- `I00SessionAdmissionBaselineTests` was not edited. `userType` is not session admission.

Added one Core case that was missing: `testInitialRequestedModeDoesNotOpenMerchantTabs`. The predicate can return `.merchant` while a fresh `RootTabBarParity.TabBarState` stays on the consumer tabs and `.consumerHome`. The predicate does not itself open merchant tabs.
