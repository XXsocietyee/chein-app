# W5a close-the-gap report (cloud/cl-w5a)

Nothing here was compiled or run (Linux, no Swift toolchain). `tools/check_scaffold.py` is the only check run.

| row | what I built (file:line) | test (file::name) | remaining gap | hook needed |
|---|---|---|---|---|
| pages/coop/nearby/index | Distinct states: `.locationDenied` (grant refused; Settings link + retry), `.permissionDenied` (server 401/403/permission/inactive-merchant), retry button for `.locationFailed/.failed`: Core/NearbyMerchantCoordinator.swift `failurePhase` (~:96), App/NearbyMerchantView.swift body (openSettings / retry / permissionDenied blocks); en+zh-Hans keys `nearbyMerchant.retry/.locationDenied.*/.openSettings/.permissionDenied.*` in Resources/Localizable.xcstrings | Tests/CoreTests/NearbyMerchantPermissionStateTests.swift::testDeniedLocationGrantIsDistinctRecoverableStateAndNeverReads, ::testServerPermissionRefusalIsPermissionDeniedNotGenericFailure, ::testOtherReadFailureRemainsRetryableFailure | Topic-scoped `chapter-application/invitable` merge, replacement invites and pull-to-refresh snapshot retention are not ported (topic-scoped entry exists in merchant chapter-invitation views); live use still needs the dormant runtime nearby approval | none new (existing `RuntimeDependencyFactory.allowsNearbyLocation` approval stays dormant) |
