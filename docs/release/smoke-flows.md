# Maestro smoke flows

Flows live in `.maestro/` and select controls only by accessibility identifiers that already exist in the SwiftUI sources. This change does not add or edit identifiers, Swift, or the Xcode project.

`authEntry.gate.body` sits inside a collapsed `DisclosureGroup` (`App/UsageConsentGateView.swift`). Each smoke flow taps `authEntry.gate.details` once, then asserts the body. A second tap would collapse it, so the flows do not tap it again.

The app id is the committed `PRODUCT_BUNDLE_IDENTIFIER` in `Config/Base.xcconfig`: `invalid.example.questify.ios`.

Each flow starts with `launchApp` `clearState: true` and `clearKeychain: true`, and passes no launch arguments. Clearing state stops a saved token from being restored. The flows contain no URL, do not type into any field, and do not tap a password, code, WeChat, Apple, or payment control.

These flows were not executed in this workspace. It has no iOS Simulator or Maestro install.

## Files

| Flow | File |
|---|---|
| Launch | `.maestro/launch.yaml` |
| Consent | `.maestro/consent.yaml` |
| Welcome | `.maestro/welcome.yaml` |
| Sign-in | `.maestro/sign-in.yaml` |

`.maestro/sweep-welcome.yaml` is a screenshot helper. It is not one of the four smoke flows, and this change does not edit it. It does not clear the keychain and it does not pass the consent gate.

## Identifiers used

| Identifier | Source | Flows |
|---|---|---|
| `authEntry.gate.details` | `App/UsageConsentGateView.swift` | launch, consent, welcome, sign-in |
| `authEntry.gate.body` | `App/UsageConsentGateView.swift` | launch, consent, welcome, sign-in |
| `authEntry.gate.privacyGuide` | `App/UsageConsentGateView.swift` | launch, consent |
| `authEntry.gate.agreement` | `App/UsageConsentGateView.swift` | consent |
| `authEntry.gate.checkbox` | `App/UsageConsentGateView.swift` | consent, welcome, sign-in |
| `authEntry.gate.decline` | `App/UsageConsentGateView.swift` | launch, consent |
| `authEntry.gate.agree` | `App/UsageConsentGateView.swift` | consent, welcome, sign-in |
| `welcome.player` | `App/WelcomeView.swift` (`welcome.` + `RegistrationIntent.player`) | consent, welcome, sign-in |
| `welcome.merchant` | `App/WelcomeView.swift` (`welcome.` + `RegistrationIntent.merchant`) | welcome |
| `welcome.settings` | `App/WelcomeView.swift` | welcome |
| `welcome.browse` | `App/WelcomeView.swift` | welcome |
| `ownerDraft.guestEntry` | `App/WelcomeView.swift` | welcome |
| `language.switcher` | `App/LanguageSwitcher.swift` | welcome |
| `auth.otherChannels` | `App/LoginView.swift` | sign-in |
| `auth.wechat.signIn` | `App/WeChatAppAuthSection.swift` | sign-in |
| `auth.channels.phone` | `App/AuthChannelView.swift` | sign-in |
| `auth.channels.code` | `App/AuthChannelView.swift` | sign-in |
| `auth.channels.sendCode` | `App/AuthChannelView.swift` | sign-in |
| `auth.channels.phoneSignIn` | `App/AuthChannelView.swift` | sign-in |

`welcome.player` and `welcome.merchant` are the existing interpolation `welcome.\(role.rawValue)`. `RegistrationIntent` in `Core/AppPreferences.swift` is `player` and `merchant`.

## Omitted steps

The generated launch screen (`INFOPLIST_KEY_UILaunchScreen_Generation` in `Config/Base.xcconfig`) has no accessibility identifier. `.maestro/launch.yaml` does not assert that screen. After a cleared launch the first stable identifier is `authEntry.gate.details`. The flow opens it once, then asserts `authEntry.gate.body`.

Do not pass extra launch arguments. In a DEBUG build, any argument other than `--uitesting-usage-consent-pending` treats consent as already granted (`UsageConsentEnvironment` in `App/UsageConsentGateView.swift`), so the gate identifiers are absent.

These controls have no stable identifier, so the flows do not tap them:

- Close on the consent document sheet, sign-in sheet, and phone sheet (`Button("action.close")` in `App/UsageConsentGateView.swift`, `App/LoginView.swift`, and `App/AuthChannelView.swift`)
- Password field (`SecureField("auth.password")` in `App/LoginView.swift`)
- Username field (`TextField("auth.username")` in `App/LoginView.swift`)
- Unconfigured-endpoint label (`Label("auth.notConfigured")` in `App/LoginView.swift` and `App/AuthChannelView.swift`)
- Phone-sheet agreement and privacy buttons (`Button("auth.channels.userAgreement")` and `Button("auth.channels.privacyPolicy")` in `App/AuthChannelView.swift`)

These identifiers exist but are conditional, so the flows do not require them:

- `authEntry.gate.checkRequired` appears only after an agree attempt with the checkbox off. The agree button is disabled until the checkbox is on, so the flow never takes that path.
- `authEntry.gate.requiredForSignIn` and `authEntry.gate.review` appear only when sign-in is opened before consent. The flows agree first.
- `welcome.upgradeRequired` appears only when a session upgrade error is set.
- `auth.signIn` appears only when `canUsePassword` is true. The flow never taps it and never types a password.
- `auth.error` appears only after a failed sign-in.
- `auth.restore.retry` appears only when session restoration can be retried. Tapping it would read the account from the configured host.
- `auth.wechat.cancel`, `auth.wechat.error`, and `auth.wechat.gate` depend on WeChat phase. The flow asserts `auth.wechat.signIn` and does not tap it.
- `auth.channels.appleSignIn` appears only when Apple configuration is marked verified.
- `auth.channels.error` and `auth.channels.upgradeRequired` appear only after a channel failure.
- `region.auth.pending` replaces the China phone fields when the market is not China. The committed default in `Config/Base.xcconfig` is `QUESTIFY_MARKET = CN`, so the sign-in flow waits for `auth.channels.phone`. A US build does not show that identifier.

These identifiers exist, and the flows still do not tap them, because the tap leaves the smoke path or can reach a host:

- `authEntry.gate.decline` opens guest browsing. The home feed loads from the configured endpoint when one is set.
- `authEntry.gate.privacyGuide` and `authEntry.gate.agreement` open bundled legal text, and the close control has no identifier.
- `welcome.browse` enters the tab shell. The same home-feed load applies.
- `welcome.settings` opens settings, and the close control has no identifier.
- `ownerDraft.guestEntry` pushes the guest draft screen, and the back control has no identifier.
- `language.switcher` opens a menu. The flow only checks that the control is present.
- `auth.channels.sendCode` and `auth.channels.phoneSignIn` submit to the configured API. The flow only checks that they are present.
