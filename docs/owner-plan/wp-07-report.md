# WP-07 report (cloud builder, Linux — nothing compiled)

## Files written
- `Core/SafetyDisclosure.swift` (edit: appended `SafetyDisclosurePolicy`; existing code untouched)
- `App/SafetyDisclosureBanner.swift` (new: mounts existing `AIIdentityDisclosureView` / `OfflineNodeSafetyView`)
- `App/ShopNPCView.swift` (edit: `safetyPolicy` property + `SafetyDisclosureBanner` in the always-visible header)
- `docs/owner-plan/wp-07-new-strings.md` (one missing key: `opsSafety.pay.noAutoFunds`)

## Tests written (not run)
- `Tests/CoreTests/WP07DisclosurePolicyTests`: `testNPCReplyAlwaysCarriesAIIdentity`, `testOfflineNodeShowsUnknownSafetyWhenNoSignal`, `testNoAutoFundsClauseShownBeforePayAction`
- `Tests/AppUnitTests/WP07ShopNPCDisclosureTests`: `testBannerPresentInProductionShopNPCView`, `testBannerAbsentDoesNotCrashWhenPolicyNil`

## NOT verified
- Nothing compiled or run (no Swift toolchain/Xcode); no red-first run. Names grepped against source only.
- Missing localization key: no existing key covers the "no auto funds" clause; per rules I did not edit Resources. The key is listed in the new-strings doc and only renders if a caller sets `hasPayAction: true` (ShopNPCView does not), so no raw key shows in the shop NPC screen.
- The walking-navigation info section part of the WP scope is NOT done: WP-03 owns `WalkingNavigation*`, and the Create/edit list excludes it. `SafetyDisclosureBanner(showsNodeSafety:)` is ready for it; mounting is a follow-up.
- `testBannerPresentInProductionShopNPCView` reads `App/ShopNPCView.swift` via `#filePath`; it fails (not skips) if the simulator cannot read source. It checks the mount by string, not by rendering — no view-hierarchy/UI check, no device/visual check.
- Swift concurrency/Sendable warnings on `static let defaultSafetyPolicy` in a `@MainActor` struct are unchecked.
- `_ = SafetyDisclosureBanner(policy: nil).body` compile validity is assumed.
