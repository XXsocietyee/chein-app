# CB49 — locale formats

Base `origin/rc/20261108`. Branch `cursor/cb49`. This note is the audit of dates, numbers, currency, and plurals, and the rules locked by `tools/locale_formats.py`.

`swift`, `swiftc`, and `xcodebuild` were not run. No Swift test pass is claimed. Views were not restyled. `tools/current_ci_manifest.json` was not refreshed. Nothing was deployed, and `47.103.124.64` was not contacted.

## Rules now locked

`tools/locale_formats.py` is display-only. It does not open a socket and it does not choose a backend.

| Rule | What the formatter does |
|---|---|
| Locale | `zh-Hans` / `zh-CN` / `zh_Hans_CN` are Simplified Chinese. `en` / `en-US` / `en-GB` are English. Any other tag raises. An unknown locale does not fall through to English. |
| Numbers | Both locales use grouping `,` and decimal `.`. `1234.5678` is `1,234.5678`. Non-canonical text (`01`, `1,234`, blanks) is left unchanged. Floats are not accepted. |
| Unknown money | `None`, blank, `UNKNOWN`, `NaN`, `null`, a float, or a non-canonical string is U+2014 `—`. The result contains no digit, so it is never `0`, `0.00`, `¥0.00`, or `$0.00`. |
| Known zero | Integer `0`, `"+0"`, and `"-0"` with an explicit code are `¥0.00` or `$0.00`. Zero fen is the same. |
| CNY vs USD | The code is the only selector. English UI with `CNY` stays `¥`. Chinese UI with `USD` stays `$`. Half-up to two places: `1.005` USD is `$1.01`, `-1.005` CNY is `-¥1.01`. `9900` fen CNY is `¥99.00`. |
| No conversion | A known amount with no code is the number only (`12.50`). `EUR` stays `12.50 EUR`. Nothing is rewritten into the other currency. |
| US backend | `api_host("US")` is `None`. `api_host("CN")` is the existing reviewed host `https://www.chengyinhub.com/prod-api/`. USD formatting does not change either result. |
| Plurals | English `one` is an integer whose absolute value is 1 (`1`, `+1`, `-1`). `0`, `2`, and `1.0` are `other`. Chinese is `other` for every count and refuses a catalog that has only `one`. |
| Civil date | `2024-02-29` is `2024年2月29日` or `Feb 29, 2024`. `2023-02-29`, offsets, and timestamps stay verbatim. |
| Civil clock | Wall time is not shifted. Chinese keeps `yyyy-MM-dd HH:mm:ss`. English uses `MMM d, yyyy h:mm a` and drops seconds (`00:05:09` is `12:05 AM`). |
| Instant | The caller names the zone. `2026-10-23T12:00:00Z` is `2026-10-23 20:00:00` in `Asia/Shanghai` and `Oct 23, 2026 8:00 AM` in `America/New_York`. The same instant in January is `7:00 AM` because New York is on standard time. A naive datetime raises. Chinese with a New York zone stays 24-hour; the locale does not replace the zone. |

`format_count` groups the count: `10000` is `10,000 members` or `10,000 名成员`.

## What the Swift call sites already do

These files were read and not edited.

- `App/WalletCivilDateLocalization.swift` parses `yyyy-MM-dd` with `en_US_POSIX` and UTC, then displays `yMMMd` in the selected locale. The new civil-date rows match the strings those tests already expect (`Feb 29, 2024`, `2024年2月29日`). Invalid dates and timestamps stay verbatim there too.
- `Core/VersionedLocaleDisplay.swift` uses `yyyy-MM-dd HH:mm:ss` for CN and `MMM d, yyyy h:mm a` for US, with the caller’s zone. The instant rows use those patterns. That type still refuses to format an instant until a zone is passed (`WAITING_SOURCE`). This module does not remove that gate.
- `Core/MerchantContracts.swift` `MerchantMoney.display` is CNY, exact `Decimal`, and returns `—` for a missing or non-numeric string. A literal zero remains `¥0.00`. No grouping. Left as it is.
- `Core/MerchantBusinessValue.swift` prints `CNY` plus the raw text, or `—`. It does not infer USD.
- `App/WalletNumberLocalization.swift` groups with the UI locale and will not invent `CNY` or `USD`. A missing amount uses `wallet.unknown` (`Unknown` / `待确认`), not an em dash. A missing currency uses `wallet.currencyUnknown`. Those strings stay, because changing them would restyle the wallet.
- `App/WalletCommerceViews.swift` `WalletCurrencySymbol` maps an explicit `CNY`/`RMB` to `¥` and `USD` to `$`. A nil code is nil. The earnings hero draws `—` in the symbol slot only. Asset rows use `—` while amounts are unknown.
- `Core/HomeFeedContracts.swift` leaves `currencyCode` nil on list rows so the device locale cannot invent a currency. `HomeFeedDate.display` still formats with the caller’s zone and locale. Not restyled.
- `Core/RegistrationUIForm.swift` formats a verified `CNY` deduction with the UI locale’s number format and returns nil when the amount is missing. `App/RegistrationSheetView.swift` already substitutes `—`.

## Plural difference that was not applied to views

`App/ClubComponents.swift` selects the singular catalog key only when `count == 1`, for English and Chinese. `Tests/AppUnitTests/ClubMemberCountLocalizationTests.swift` locks that, including `-1` on the plural key (`-1 members`) and the same Chinese measure word for 0, 1, and 2.

`WalletFormatting.pointsUnit` treats both `1` and `-1` as singular, which matches the English absolute-value rule, then looks up `walletNumber.point` / `walletNumber.points`. Both Chinese strings are `积分`.

CB49’s rule is the English absolute-value category, and Chinese always reads `other` even if a `one` string is present. The club and wallet selectors were not rewritten, so those tests and the views stay as they are. New Python callers use `format_count`.

## Left off

- Version in `Config/Base.xcconfig` is `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1`.
- `Config/UnitedStates.Production.xcconfig` sets `QUESTIFY_MARKET = US` and leaves `QUESTIFY_API_BASE_URL` empty. It contains no `https://` host.
- `ReviewedMarketLaunch.approvedBaseURLs` still has only the China production URL.
- Password login stays the release `#else` branch of `AppSession.canUsePassword` (`false`).
- Bank-card withdrawal still requires `makeBankWithdrawalContext()` permits. This change does not grant them.
- Virtual goods stay off: `WalletCommerceVisibility.mall` defaults to `false`, and `SessionWalletCommerceView` does not turn mall on.

Checked with `python3 -m unittest tools.tests.test_locale_formats`.
