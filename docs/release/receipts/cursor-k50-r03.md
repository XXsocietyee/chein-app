# K50-R3 US launch behaviour

Branch `cursor/1128-k50-r03` from `origin/ui/combined-r7` @ `d5702393c`, then merged `origin/ui/combined-r7` @ `b954de71c` before push. Scope is US launch behaviour only: +1 SMS sign-in order, Stripe / Apple Pay flow labelling, US legal pages as the existing placeholder, and US units / dates / currency on the rows this lane owns. Money switches were not edited. Payments stay off. No US legal copy was written. `App/AppSession.swift` was not edited (7976 lines). Init order `devices`, `sensors`, `artworkHosts` is untouched. Release `PlayerLaunch.merchantCenterEnabled` stays false.

The shipped binary pins the backend market to China, so `operationalMarket` is China for a US player. Presentation follows the storefront.

## Changed

| Behaviour | What changed |
|---|---|
| Sign-in order | `USLaunchPresentation.signInLeadsWithApple` reads the storefront first. A US storefront shows Sign in with Apple, then phone. China and an unknown storefront keep WeChat (when offered), then phone, then Apple. The +1 wire was already E.164: `AuthChannelInput` keeps `+14155550132`, rejects a NANP number whose area starts with 1, and the multipart SMS body keeps the plus. |
| Stripe / Apple Pay label | `RegistrationPayMethod.effective` passes the quote's `paymentChannels` into `options`. A card-only USD quote labels Card. Apple Pay is first only when the device can pay and the quote lists it. A closed payment switch still does not label the button as Pay. No switch was turned on. |
| Quote currency on the registration sheet | `RegistrationUIMoney.quoteDisplayCode` uses the server currency (`RMB` reads as `CNY`). Listed price and marketing adjustments use it, and fall back to CNY when the quote sends none. The total uses the quote currency only when one was sent, so a China total with no currency stays the unconfirmed decimal. Named `*Yuan` deduction rows stay CNY and are not converted. |
| US legal pages | Agreement, privacy, welcome, login, about, support, location, usage-consent, and the compliance privacy link call `UserMarketMemory.legalDocumentMarket`, which is the storefront. For the United States, `SettingsSourceLegalCatalog` already returns `.missing(.regionalTextNotProvided)`. That placeholder is the page. `isReleaseApproved` stays false. |
| Walked distance and passport duration | `LocaleDisplay.walkedKilometers` keeps `%.1f km` in Chinese and uses road miles otherwise. Passport summary, list, and detail, and the merged roam history list, use it. Passport duration keeps `H:MM` in Chinese and uses `LocaleDisplay.duration` otherwise. |

## Left owner-only

| Item | Why it stays with the owner |
|---|---|
| US privacy, terms, and cancellation copy | Not invented. The catalog placeholder is the only US text. |
| Account deletion notice | The agree step needs a versioned source document. Cancellation still loads the deployment (China) notice. The standalone deregister page does the same. |
| Live Stripe / Apple Pay charges | Stripe secret, webhook secret, Apple Pay processing certificate, and merchant id. `ReleaseMoneyWriteSwitch.paymentEnabled` and `MPCommerceGate.purchasesEnabled` were not changed. |
| International SMS delivery | The app already maps `SMS_INTL_NOT_CONFIGURED` to the region-unavailable message. Turning on Aliyun international SMS is an owner config. |
| +1 on participant save | Sign-in sends E.164. The participant / address save still rejects anything but `^1[3-9]\d{9}$` on the backend. |
| List and detail prices with no currency | They stay CNY. This lane formats a currency only when the quote sent one. |
| PayPal | Not in this release. |
| Merchant center | Release `merchantCenterEnabled` stays false. |

## Gates

`python3 tools/check_scaffold.py` PASS · `python3 -B tools/check_a11y_lint.py` 0 new · `python3 -B tools/contract_ratchet.py --check` 46 failing, baseline 46, **new 0**, fixed 0 · `python3 tools/check_appsession_ratchet.py` PASS (7976 ≤ 7977). No new `String(localized:)`. No `xcodebuild`. No secrets, deploys, or SQL.
