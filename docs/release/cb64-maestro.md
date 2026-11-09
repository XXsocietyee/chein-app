# CB64 Maestro flows

Flows live in `.maestro/` and select controls only by accessibility identifiers that already exist in the SwiftUI sources. This change does not add or edit identifiers, Swift, the Xcode project, Config xcconfig files, or anything under `.github`.

Each flow launches a DEBUG build with one argument, `--design-fixture <name>`. The name is a `case` that `DesignFixtureRegistry.make` in `App/DesignFixtures/DesignFixtureRegistry.swift` already returns for that screen. The registry is compiled only inside `#if DEBUG`. A Release build does not take this branch.

The app id is the committed `PRODUCT_BUNDLE_IDENTIFIER` in `Config/Base.xcconfig`: `invalid.example.questify.ios`. Version stays `0.1.0` (`1`).

Maestro's iOS driver keeps a launch-argument key that already starts with `-`, then appends the string value. The map key is therefore the literal `--design-fixture`, which is the flag `fixtureArgument` in `App/QuestifyApp.swift` looks up. The value is the fixture name.

These flows were not executed in this workspace. The `maestro` CLI is not installed here, so this change does not claim a Maestro run. This workspace also has no Swift compiler and no `xcodebuild`, so this change does not claim a compile.

Wiring these flows into GitHub Actions needs the owner. This change does not add a workflow.

## Screens

| Screen | Fixture `DesignFixtureRegistry.make` returns | Flow |
|---|---|---|
| Orders | none | none |
| Wallet | none | none |
| Club | `d4-directory` | `.maestro/club.yaml` |
| Merchant home | none | none |
| Settings | `d4-settings` | `.maestro/settings.yaml` |

### Orders: none

`OrdersWalletFixtures.make` in `App/DesignFixtures/OrdersWalletFixtures.swift` defines `orders-list`, `orders-empty`, `order-detail`, `order-detail-bottom`, and `order-detail-full`. `DesignFixtureRegistry.make` does not call `OrdersWalletFixtures.make` and has no orders `case`. Those names hit the default branch and render `Unknown design fixture: <name>`. They are not wired, so there is no orders flow.

### Wallet: none

`OrdersWalletFixtures.make` also defines `wallet`, plus `ticket-list`, `ticket-detail`, and `coupons`. `DesignFixtureRegistry.make` does not return any of those names. `--design-fixture wallet` is not a wired fixture, so there is no wallet flow.

### Club: `d4-directory`

`d4-directory` returns `D4ClubFixture(.directory)`, which hosts `ClubDirectoryView`. The fixture reader uses `ClubFixtureScenario.visitor`. That reader is signed in (account 701, not guest), and `clubDirectory` returns fixture clubs 81 and 82. The flow waits for `club.directory.81`, then checks `club.directory.82` and the toolbar `club.directory.refresh`.

Other wired club names are different screens and are not this flow: `d4-detail`, `d4-owner-detail`, `d4-channels`, `d4-channel-chat`, `d4-confirm`.

### Merchant home: none

`DesignFixtureRegistry.make` has no merchant-home `case`. `kit-merchant` and `kit-merchant-2` return `KitGalleryFixture` for the merchant theme, which is a component gallery, not the merchant home screen. Public merchant home is opened by the separate DEBUG flag `--public-merchant-home-fixture` in `App/QuestifyApp.swift`. That flag is not a `--design-fixture` name `DesignFixtureRegistry.make` returns, so there is no merchant-home flow.

### Settings: `d4-settings`

`d4-settings` returns `D4MeFixture(screen: .settings)`, which hosts `SettingsView` with a new `AppSession` and `NativeOriginalUnreadBadgeState`. The design-fixture root replaces the normal window content, so the root `.task { await session.bootstrap() }` in `App/QuestifyApp.swift` does not run. The fresh session stays signed out, and `settingsNative.profileSignedOut` is the stable marker.

## Commands

Run these against a DEBUG install of `invalid.example.questify.ios` on a booted simulator:

```sh
maestro test .maestro/club.yaml
maestro test .maestro/settings.yaml
```

## Identifiers used

| Identifier | Source | Flow |
|---|---|---|
| `club.directory.81` | `App/ClubDirectoryView.swift` (`club.directory.` + fixture club id 81) | club |
| `club.directory.82` | `App/ClubDirectoryView.swift` (`club.directory.` + fixture club id 82) | club |
| `club.directory.refresh` | `App/ClubReadScreen.swift` (`accessibilityPrefix` + `.refresh`, prefix `club.directory`) | club |
| `settingsNative.profileSignedOut` | `App/ProfileSettingsProfileRoute.swift` | settings |
| `settings.playGuide` | `App/SettingsView.swift` | settings |
| `region.market.value` | `App/SettingsView.swift` | settings |
| `settings.supportSafety` | `App/SettingsSupportSafetyEntry.swift` | settings |
| `settingsNative.openSound` | `App/SettingsSupportSections.swift` | settings |
| `settingsNative.openLegal.privacy_policy` | `App/SettingsSupportSections.swift` (`settingsNative.openLegal.` + `SettingsLegalType.privacyPolicy`) | settings |
| `settingsNative.openAbout` | `App/SettingsSupportSections.swift` | settings |

`SettingsLegalType.privacyPolicy` in `Core/SettingsLegalContracts.swift` has raw value `privacy_policy`.

## Omitted steps

The flows do not type, do not tap a row or link, and do not tap refresh, search, Done, sign-out, payment, or a credential control. They pass no URL.

These identifiers exist on the settings screen only in states this fixture does not enter, so the settings flow does not require them:

- `settings.becomeClubHost` and `settings.becomeMerchant` appear only when `SettingsIdentityApplications.isOffered` is true. A nil role returns false.
- `settings.privacyLocation` appears only when `session.account != nil`.
- `settingsNative.openFavorites` appears only when favorites access is current.
- `settings.invoices` appears only when `makeInvoiceLaunchPresentation()` returns a value.
- `settings.signOut` appears only when `session.account != nil`.

The language picker in `SettingsView` has no accessibility identifier. The Done toolbar button is `Button("action.done")` and has no accessibility identifier. The club search field comes from `.searchable` and has no accessibility identifier. The flows do not target those controls.

`club.directory.loading`, `club.directory.empty`, `club.directory.error`, `club.directory.signIn`, and `club.directory.retry` are other states of `ClubReadScreen`. The visitor directory fixture loads clubs 81 and 82, so the flow waits for the loaded row instead.
