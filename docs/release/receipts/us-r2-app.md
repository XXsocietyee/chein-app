# US launch r2 — lane us-r2-app receipt (2026-11-27)

Branch `us/r2-app` from `origin/ui/combined-r7`. Brief: `docs/briefs/round2-1127.md` (design/handoff-r2), row `us-r2-app`, plus the coordinator's English-sweep row ("From ¥12.50" under en_US).
Open items taken from `docs/release/receipts/us-r1-app-pay.md`.
No compiler in the cloud: every API was checked by grep and by reading. **Not built and not run on a device.**

## Done

| Item | Files | What changed |
|---|---|---|
| Order-detail pay step can show the US rows | `Core/OrderLifecycleContracts.swift`, `App/RegistrationPaySection.swift`, `App/OrderLifecycleView.swift` | `OrderLifecycleDetail.currency` (new, optional, lenient: blank/non-string → nil, trimmed + uppercased). `paymentChannels` was already decoded. `RegistrationPaySection` takes `orderCurrency` / `orderPaymentChannels` (default nil); the quote wins when present, else the order's own fields. `OrderLifecycleView` passes `detail.currency` / `detail.paymentChannels`, so a USD order listing `APPLE_PAY` / `APP_STRIPE` in the US market gets the Apple Pay / card rows on the order page too. China orders (no currency, no Stripe channel) keep the China "Pay now" button exactly as before (`StripePayEligibility.applies` needs US market + USD + a Stripe channel). |
| `RegistrationUIMoney.display` uses the order currency | `Core/RegistrationUIForm.swift` | With a currency code: `Decimal.FormatStyle.Currency(code:locale:).presentation(.narrow)` with the shared two-decimal rule → `USD` → `$12.50`, `CNY` → `¥12.50` in **every** locale (the locale only picks separators; it never re-labels the currency: no `CN¥`, no `US$`). Without a code it stays the bare decimal as before. `RMB` is read as `CNY`. New `RegistrationUIMoney.dollarCurrencyCode`. |
| Pay-step / order amount follow the order currency | `App/RegistrationPaySection.swift`, `App/OrderCardComponents.swift`, `App/OrderLifecycleView.swift` | "Amount due" uses the quote/order currency; a backend without `currency` is the China one, so it shows `¥` (MP `money.wxs` `amount2` shows `¥` on the order detail). `OrderAmountHero` takes an optional `currencyCode`; with one it shows the symbolled amount and drops the "currency unconfirmed" caveat; without one it is unchanged. |
| Prices follow the event's currency, never the locale (English sweep) | `Core/LocaleDisplay.swift`, `App/HomeFeedView.swift`, `App/QuestifyImageEntityCard.swift`, `App/PlayFinishRouteCardView.swift` | `LocaleDisplay.money` (the shared formatter behind E1Money, activity cards, detail pinned line) now uses `.presentation(.narrow)`: CNY → `¥` and USD → `$` in every locale (was `CN¥` in English). Home feed cards, the shelf card, the home status row, topic cards and the play finish-route card no longer use the key `playx.finishRoute.priceFrom` whose text had `¥` baked in ("From ¥%@"); they format the amount through `LocaleDisplay.money(…, currencyCode: item.currencyCode)` and use the existing key `activity.pinned.price %@` ("From %@" / "%@ 起"). zh-Hans output for CNY is byte-identical (`¥12.50 起`). Topic card price is now two decimals (owner decision 9) instead of 0…2. |
| `SignInWithAppleFlowTests.testRepositoryEntitlementIsTheOnlySignInValue` | `Tests/CoreTests/SignInWithAppleFlowTests.swift` | No longer asserts the entitlements file has one key (it has 4: aps, applesignin, in-app-payments, app group). It checks the `com.apple.developer.applesignin` value is exactly `["Default"]`. Test name kept (pinned by `test_sign_in_with_apple_flow.py`). |
| Tests | `Tests/CoreTests/RegistrationUIFormTests.swift`, `Tests/CoreTests/LocaleDisplayTests.swift` | `testDisplayUsesTheOrderCurrencySymbolInEveryLocale` (USD/CNY in en_US and zh_Hans_CN), `testOrderDetailCurrencyAndPaymentChannelsDecodeLeniently`; LocaleDisplay English CNY now expects `¥12.50` (not `CN¥`), USD in Chinese expects `$12.50` (not `US$`). The order-detail decode test lives in `RegistrationUIFormTests` because `OrderLifecycleTests.swift` is hash-pinned in `tools/current_ci_manifest.json`. |

No new user-facing strings (reused `activity.pinned.price %@`, already en + zh-Hans), so no `docs/port/strings/us-r2-app.json` fragment. The key `playx.finishRoute.priceFrom %@` is now unused in code but left in `Localizable.xcstrings` (i18n lanes can drop it).

## Not done

- **Event-level currency on lists/detail.** `HomeFeedItem.currencyCode` is still `nil` (pinned by `test_native_design_motion.py`), and `ActivitySummary` / topic list contracts carry no currency — the backend lane `us-r2-backend` adds `currency` only to the order detail. Every price call site now passes through the currency formatter, so once the list/detail payload has `currency`, decoding it and returning it from `HomeFeedItem.currencyCode` (and updating that contract pin) is the only change left.
- `LocaleDisplay.currencySymbol` (input-field prefix) still uses `NumberFormatter.currencySymbol`, which is `CN¥` in English. Only used for text-field prefixes; left for i18n-r2-locale to avoid a conflict in their file.
- Registration sheet rows (`RegistrationAmountRow`, summary total) still pass `yuanCurrencyCode` / nil as before; only the pay step and order detail read the quote/order currency. A USD quote's breakdown rows will show the bare decimal + "currency unknown" until they pass `quote.currency` (one-line change per row; left out to keep this lane to the pay step and order detail).

## Risks for first compile

- `Decimal.FormatStyle.Currency(code:locale:).presentation(.narrow).precision(.fractionLength(ClosedRange<Int>))` — iOS 15+ API; check the `.narrow` member resolves (`CurrencyFormatStyleConfiguration.Presentation.narrow`).
- `RegistrationPaySection.init` gained two trailing defaulted params after the `onExpiredRebuild` closure; existing calls use labels, so trailing-closure calls (none today) would bind to the last closure param — none affected.
- `OrderAmountHero(label:amount:currencyCode:)` relies on the memberwise init skipping the defaulted `showsCurrencyCaveat`.
- `PlayFinishRouteCardView` gained `@Environment(\.locale) private var locale`; its memberwise init is used from two files (labels unchanged).
- ICU narrow symbols: `CNY` narrow is `¥` and `USD` narrow is `$` in en_US and zh_Hans_CN on iOS 17/18 — the new tests pin this; if an OS returns `CN¥`, those tests will say so.

## Gates

- `python3 tools/generate_project.py` → project unchanged (no new files)
- `python3 tools/check_scaffold.py` → PASS structural checks (5250 Swift files)
- `python3 -B tools/check_a11y_lint.py` → PASS, 0 new
- `python3 -B tools/contract_ratchet.py --check` → RATCHET_RESULT

Nothing deployed. Merchant and story-flow theme untouched.
