# App Review notes (draft)

Not submitted. Not signed. Not uploaded. Version stays `0.1.0` (`1`). This draft does not contain a demo password. None is configured in this tree.

Checked against `origin/rc/20261108` at `88e981b3308558939e405606cd731b4b29fc9499` on 2026-11-09 02:02 PT. This workspace has no Swift compiler and no `xcodebuild`. Nothing here is a Release compile.

## Demo account

The demo account is not configured.

No App Review username, phone number, SMS code, or password is stored in this repository. `Config/Local.xcconfig` is absent. Do not invent a password, a phone number, or a one-time code for App Store Connect.

`Core/AppStoreReviewDemoAccountAndFixtureReadinessAudit.swift` marks four walkthrough names compliant by default, and `AppStoreReviewDemoSnapshot.defaultReady` says credentials are redacted and Guideline 2.1 is ready. Those flags are a self-check. They are not a seeded account, and they are not these notes. Do not paste "Ready (4/4 Personas Verified)" into App Store Connect.

## What a reviewer can open on this build

`Config/Base.xcconfig` sets `MARKETING_VERSION = 0.1.0`, `CURRENT_PROJECT_VERSION = 1`, `QUESTIFY_MARKET = CN`, `QUESTIFY_DEPLOYMENT_ENVIRONMENT = unconfigured`, an empty `QUESTIFY_API_BASE_URL`, an empty `QUESTIFY_SESSION_REALM`, and `PRODUCT_BUNDLE_IDENTIFIER = invalid.example.questify.ios`.

`RegionalLaunchConfiguration.shippedComposition` calls `ReviewedMarketLaunch.admitsShippedChina` before it will select the reviewed China host. An empty base URL does not match `https://www.chengyinhub.com/prod-api/`, so `composition` stays `makeComposition(reviewed: nil, build: .current)`. The unconfigured composition does not call a backend. `AppSession.isConfigured` is `storageScope != nil`, so this build is not configured. `AuthChannelCoordinator.canStart` requires `service != nil`, so phone sign-in cannot start.

A reviewer can:

1. Launch the app and open the usage-consent gate (`authEntry.gate.details`, then agree or decline).
2. On the welcome screen, tap Browse (`welcome.browse`). That sets guest browsing and enters the tab shell without an account. Decline on the consent gate does the same. This build has no API host, so those tabs do not load a backend. This note does not claim they show live city content.
3. Open sign-in from the player welcome action. The username and password section is hidden because `canUsePassword` is false. The sheet can show the China phone fields and the WeChat button after consent, plus the unconfigured label (`auth.notConfigured`). The send-code and phone sign-in buttons stay disabled. Sign in with Apple (`auth.channels.appleSignIn`) appears only when Apple configuration is marked verified.

There is no second step that signs the reviewer into a player, merchant, or club-admin account. Those walkthroughs are not available until an owner configures a real host and a real account outside this file.

## Not demo features

Password login, bank-card withdrawal, and virtual goods stay off. They are not demo features. Do not ask a reviewer to use them.

- Password login is compiled out of every non-DEBUG build. `AppSession.passwordLoginCompiledIn` and `canUsePassword` are `false` outside `#if DEBUG`. `login(username:password:)` returns `auth.notConfigured` before it can call `AuthService`. The Release app target does not set `SWIFT_ACTIVE_COMPILATION_CONDITIONS` to `DEBUG`.
- Bank-card withdrawal is not a review path. The unconfigured composition leaves runtime dependencies dormant, so `makeBankWithdrawalContext()` returns nil. The reviewed gate helper `ReviewedProductionGateLeases.sessionDependencies` builds a `BusinessRuntimeConfiguration` whose routes are IM routes only, and that set does not include `bankPrepare` or `bankCreate`. The DEBUG-only wallet fixture link titled "Bank withdrawal" is inside `#if DEBUG` in `App/WalletCommerceFixtureHost.swift`.
- Virtual goods stay off. `workshopCommerceApproval` is nil unless a reviewed deployment sets it. `WorkshopCommerceComposition` builds a StoreKit factory only when that approval exists and `enableApprovedStoreKit` is true. This note does not enable either one.

## Release exclusion

`tools/check_design_fixture_release_exclusion.py` is not in the tree. The named Python check was not run. It did not pass, and it did not fail: there was no script to execute.

Source inspection, still not a compile:

| Check | Result |
|---|---|
| Questify app target, configuration `Release` (`DD75E2CB1C510A828AC72D96`) | `EXCLUDED_SOURCE_FILE_NAMES = $(inherited) AppStoreReviewDemoAccountAndFixtureSectionView.swift`. `DEBUG` is not an active compilation condition. Optimization is `-O`. |
| Questify app target, configuration `Debug` | Compiles that section view. Sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG $(inherited)`. |
| `QuestifyAppUnitTests` Debug | Excludes the same section-view filename, so the test bundle does not compile it twice while the Debug app already does. |
| `QuestifyAppUnitTests` Release | Does not set that exclude list. A Release test bundle can still compile the section view. The shared scheme archives the app with the app target's Release configuration, which excludes the file. The test bundle is not the shipped app. |
| `App/DesignFixtures/` (6 files) | Each file starts with `#if DEBUG` and ends with `#endif`. `DesignFixtureRegistry` is reached only from the `#if DEBUG` branch in `QuestifyApp.body`. |
| `tools/generate_project.py` | Puts `App/DesignFixtures/*.swift` in the app sources and puts only `AppStoreReviewDemoAccountAndFixtureSectionView.swift` in `release_test_fixture_names`. The generated Release exclude list matches the committed `project.pbxproj`. |
| Fixture, mock, and synthetic Swift in `App/` and `Core/` | 179 files whose names contain `Fixture`, `Mock`, or `Synthetic`. 159 have no Release-visible code, or are the section view excluded by filename. 17 leave only `import` lines. `Core/RoamPassportPrivateToolsFixture.swift` also leaves `RoamPrivateToolsOfflineExample.pageSize`, a page-size constant with no records. Two audit types remain in the app target and contain no account, password, or fixture records: `AppStoreReviewDemoAccountAndFixtureReadinessAudit` and `AppSessionCompositionAndFixtureShortCircuitAudit`. |
| Fixture launch | `AppSessionContainer.init` builds a fixture session only inside `#if DEBUG`. The Release path calls `RegionalLaunchConfiguration.composition.makeSession()`. |

Executable fixture and mock payloads are excluded from the Release app target by `#if DEBUG` or by `EXCLUDED_SOURCE_FILE_NAMES`. That source exclusion passed. String catalogs still contain fixture-labeled sentences, including "Switch fixture account" and "Synthetic fixtures only. No real club actions" in `Resources/Localizable.xcstrings`. Those sentences are resources, not a demo account. The views that present them sit inside `#if DEBUG`, so a Release launch does not open those fixture screens. This inspection did not strip the catalogs.

## Owner still has to fill

- A real demo account, created outside this repository, if sign-in is required for review. Put the username or phone in App Store Connect. Do not commit the password.
- The bundle id, team, distribution signing, and a host that `admitsShippedChina` accepts, if this build should call the reviewed China API. This draft does not edit `Config/*.xcconfig` or `App/RegionalLaunchConfiguration.swift`.
- The decision to submit. This branch does not submit.
