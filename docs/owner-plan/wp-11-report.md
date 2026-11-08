# WP-11 report (cloud builder, branch cloud/wp-11)

## Files written
- Core/ScopedCacheKey.swift (new): `ScopedCacheKey` (account+object+privacy+version, length-prefixed `storageName`), `ScopedCacheIndex` (insert / isReusable / revoke / purgeAccount).
- Core/DevicePushRegistrationLifecycle.swift (append only): `PushMemberBinding`, `PushMemberBindingRegistry` (bind / mayDeliver / revoke). Existing `DevicePushRegistrationLifecycle` untouched.
- Core/ImageAndVideoDiskCacheBudgetAudit.swift (append only): `foreignKeys(in:ownedBy:)` extension. Canonical policies unchanged.

## Tests written
- WP11ScopedCacheKeyTests: testKeyDiffersByAccountObjectPrivacyAndVersion, testRevokedShareImageNotReusable, testLogoutPurgesAccountKeys
- WP11PushMemberBindingTests: testAccountSwitchDropsOldAudience, testEnvironmentChangeRebindsMember, testRevokeDeregistersToken

## NOT verified
- Nothing compiled or run (Linux cloud, no Swift toolchain). Source written only.
- Symbols checked by grep: `NotifyFailure.missingOriginalRequestID`, `DevicePushRegistrationLifecycle.requireEnvironment` (internal, same module).
- Not done: APNs wiring, push dedup, AppSession integration, ChannelRevokeIsolation hook (WP-13). No app code calls the new types yet.
- Design choice to review: invalid blank member/installation/token reuses `NotifyFailure.missingOriginalRequestID` (no new error case added to avoid touching ImmutableReceiptProducer).
