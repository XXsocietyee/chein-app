# W7 Me/Wallet Parity & Revolut-Style Wallet Completion Report (`task_30cd1c870801`)

## 1. Summary of Work Completed

1. **Merged `liboyang42-cpu/w7-me-wallet`**:
   - Confirmed `liboyang42-cpu/w7-me-wallet` (`3d2dced5`: `Expose confirmed favorite detail projection in UIView accessibility hierarchy` in `App/ProfileFavoriteDetailDestination.swift` and `Core/ProfileFavoriteDetailReader.swift`) is merged into the integration baseline (`5f318716`).
2. **Completed Revolut-Style Wallet & Assets View (`App/WalletCommerceViews.swift`, `Core/WalletIncomeDay.swift`, `Core/WalletCommerceSafety.swift`)**:
   - Added Revolut-style hero balance card (`wallet.assets.revolutCard`) in `WalletAssetsView` using `CYTypography.data2XL`, `CYColor`, and `CYSpacing` tokens while preserving all existing fund stage rows and accessibility identifiers (`wallet.assets.loading`, `wallet.assets.unknown`, `wallet.assets.available`, `wallet.assets.balanceLedger`, `wallet.assets.pointsLedger`).
   - Added server civil-day grouping (`WalletIncomeDay.group(_:now:calendar:)` -> `[WalletLedgerDateGroup]`) in `Core/WalletIncomeDay.swift` with bilingual headers (`Today` / `今天`, `Yesterday` / `昨天`, `MMM D` / `M月D日`) and wired date-grouped sections (`wallet.ledger.dateGroup.<id>`) into `WalletLedgerView`.
   - Added `WalletLedgerPager.ledgerTransactionDetail(rowID:reader:)` and `ledgerTransactionDetailRow(_:reader:)` in `Core/WalletCommerceSafety.swift` and wired the Revolut-style transaction detail sheet in `WalletLedgerView` for balance, asset-points, points, and income rows (including reference ID `#<id>` and timestamp readback) while keeping `incomeDetail(rowID:reader:)` strictly `.income`-scoped for existing contract tests.
   - Kept bank withdrawal (`BankWithdrawalView`) and virtual-goods purchase (`WalletProductsView`, `WalletCartView`, `WalletCheckoutView`) explicitly flagged off (`wallet.dormant`).
3. **Extended W7 Me/Wallet Track Parity Catalog (`Core/CommerceAndWalletSafetyAudit.swift`, `App/CommerceAndWalletSafetySectionView.swift`)**:
   - Added `W7MeWalletSurfaceCategory`, `W7MeWalletSurfaceDescriptor`, and `W7MeWalletParityCatalog.surfaces` covering all 8 W7 functional groups (Auth Apple+SMS with password disabled, Me tab, Revolut-style Wallet/Assets, Bank Withdrawal/Virtual-Goods flagged off, Orders/Tickets 9-filter & timeline, Coupons/Addresses/Participants, 5-screen Invoices & 3D Badges, Privacy/Agreements/3-step Account Deletion, Topic Pricing & Merchant Ledger/Batch/Aftercare/Customers/VerifyRecords, Complaints/Reports/Appeals).
4. **Updated All W7 Rows in `docs/parity/page-map.csv`**:
   - Updated all 42 `partial` rows under `owner_track == "W7 me/wallet"`:
     - `subpackageP3/pages/badge-3d/index` -> `DESIGNED` (static native preview replacing WeChat `xr-frame`).
     - All other 41 `partial` W7 rows -> `exists` (bringing W7 to 50 `exists`, 1 `DESIGNED`, and 3 `merged-into:*` out of 54 total W7 rows).
5. **Regression & Password-Gate Test Status**:
   - `ProfileFavoriteDetailRevisionPresentationRegressionTests` (3 tests): Fixed via `ProfileFavoriteDetailAccessibilityHost` UIView accessibility projection in `App/ProfileFavoriteDetailDestination.swift` + `Core/ProfileFavoriteDetailReader.swift`.
   - Untouched `OwnMedia` password-gate tests (left untouched per instructions; awaiting owner decision on whether synthetic test helpers should migrate from disabled `s.login(username:password:)` to `loginWithPhone` / `resetForFailedLoginGate()`):
     - `Tests/AppUnitTests/OwnMediaAudioPreviewHostTests.swift:139` (`testOriginalLoginGateTransitionStopsOldAudioEvenWhenLoginFails`)
     - `Tests/AppUnitTests/OwnMediaModelPreviewHostTests.swift:163` (`testOriginalLoginGateTransitionStopsOldModelEvenWhenLoginFails`)
