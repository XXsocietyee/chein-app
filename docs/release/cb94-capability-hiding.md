# CB94 capability hiding

Audit of routes that come back `APIError.notConfigured`. A route the China reviewed deployment refuses is not a control. Password login, bank withdrawal, and virtual goods stay off. No United States API URL is added. Views below were not restyled.

`ChinaReviewedRouteCapability.offersFeature` is the host check. A nil base offers nothing. The China production host offers a path only when `admitsChinaProductionCall` is true. Any other host is a fixture and is left alone.

`RegionalConfiguration.showsRoute` is the capability check on top of that. A hiding capability (`.usernamePassword`, `.merchantPayout`, `.digitalContentPayment`) is shown only when that capability is available. Verifying one of those capabilities on the China host still does not show the route, because `offersFeature` is false first.

## Model and navigation changes

- `AppSession` builds `mapPublicLayerService` only when the deployment both grants the read and `showsRoute("/api/map/public-layers")`. The search reader gets `publicLayerCoordinator` only in that same case. `SearchMapExplorerView` already mounts `MapPublicLayerSectionView` with `if let`, so a hidden route no longer mounts the section.
- `makeBankWithdrawalContext()` also requires `offersFeature("/api/withdrawal/create")`. The factory permit is not enough. The context stays nil. Withdrawal is not enabled.
- `SessionRootView` installs `bankWithdrawalDestination` only when `showsRoute("/api/withdrawal/create")` is true. On the shipped composition and on the China host that value is nil.

`/api/map/public-layers` is missing. `/api/withdrawal/create`, `/api/fund/preflight/**`, `/api/cart/**`, `/api/product/info`, `/api/product/list`, `/api/registration/pay`, `/api/registration/pay/app`, and `/api/login` stay hidden. `/api/withdrawal/list` stays readable. `/api/login/phone` stays eligible.

These tests were added and not executed. This VM has no Swift toolchain.

- `ChinaReviewedRouteCapabilityTests.testHiddenRoutesAreNotOfferedOnChinaOrWithoutAHost`
- `MapPublicLayerAppIntegrationTests.testHiddenPublicLayerRouteIsNotAttached`

`tools/current_ci_manifest.json` was not refreshed.

## View leftovers for design

These files still draw the control. The change is layout, so it was left for design. Do not treat a disabled button or an unavailable line as hidden.

| Surface | What is still on screen | Route |
|---|---|---|
| `App/SessionGlobalSearchView.swift` | The search task always builds a `MapPublicLayerCaller`. | `/api/map/public-layers` (missing) |
| `App/GlobalSearchView.swift` `mapSection` | That caller becomes the public-layers menu item. The section sits outside `if !reader.isConfigured`. The submit button stays, disabled, with `searchMap.notConfigured`, when the reader itself is unconfigured. City search, nearby, and shop discovery stay; those routes are live. | `/api/map/public-layers` |
| `App/MapCoreEntryHubView.swift` | Every `MapCoreEntry` is a button. Pending entries are disabled. `LocationShareExplainerView` keeps a disabled start button. A public-layers link is added when a caller is passed in. | missing map, fog, side-quest, and location-share routes |
| `App/MapPublicLayerSectionView.swift` | If a host still passes a coordinator with `isConfigured == false`, the section draws its title and `mapPublicLayers.notConfigured`. The session no longer passes that coordinator for the hidden route. | `/api/map/public-layers` |
| `App/ApprovedReleaseAuthorPresentation.swift` | `ApprovedReleaseAuthorReadSection` always includes the recovery section. When a submission acknowledgment exists it also shows a disabled snapshot button and `approvedRelease.unconfigured`. `capture()` is already nil. | eight `/api/approved-topic-release/v1/*` paths (missing) |
| `App/ApprovedReleaseOriginalRecovery.swift` | Disabled open button plus `recovery.unavailable` when capture is nil. | same eight paths |
| `App/WithdrawalSupportLandingView.swift` | `bank.withdrawal.entry` is always a navigation link. A nil environment destination falls through to `BankWithdrawalView`. The link does not consult the flag. | `/api/withdrawal/create` |
| `App/BankWithdrawalView.swift` | The review button stays in the form when the adapter is unavailable. It is disabled only for a missing wallet scope or an unresolved outcome. `WalletCommerceFlowTests.testBankFormIsReachableAndClearlyDormant` locks this dormant form on the fixture host. | `/api/withdrawal/create` and `/api/fund/preflight/**` |
| `App/WorkshopPaidInstallEntry` in `App/WorkshopPaidInstallView.swift` | The install button is always shown. A nil factory sets `unavailable` and prints the notConfigured line under the button. | `/api/workshop/**` (missing). Virtual goods stay off. |
| `App/AuthChannelView.swift`, `App/AuthChannelAppleButton.swift`, `App/WeChatAppAuthSection.swift` | Phone send and phone sign-in stay on screen and are disabled when the coordinator cannot start. The Apple control stays. WeChat shows a disabled button and `auth.wechat.notConfigured` when `canStart` is false. Password is already omitted when `canUsePassword` is false. Phone, Apple, and WeChat routes are live; the controls do not follow `isFeatureShown`. | client gate, not a missing route |
| `App/SettingsSupportSections.swift` | With no compliance coordinator, `SettingsUnavailableFeature.allCases` are navigation links into `SettingsUnavailableFeatureView`. `SettingsNativeFlowTests` opens those rows. They are not network routes. | none |
| `App/RoamHomeTabsView.swift` `tileAvailable` | Goals and capsule tiles are always listed. A nil private-tools reader opens `RoamToolUnavailableView`. Those routes are live; the nil service is what throws `notConfigured`. | live `/api/capsules/**` and goal paths |
| Activity destinations in `App/SessionHomeFeedView.swift`, `App/SessionGlobalSearchView.swift`, `App/SessionNearbyTeamView.swift`, `App/QuestifyApp.swift` | `registrationEnabled` is passed as true, so the registration sheet can still offer pay actions. | `/api/registration/pay` and `/api/registration/pay/app` stay hidden. Payment is not enabled. |
