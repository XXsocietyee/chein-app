# i18n r1 — locale lane receipt (2026-11-27)

Branch `i18n/r1-locale` from `origin/ui/combined-r7` (`fc95e6a19`). Brief: `docs/briefs/i18n-r1.md` (locale row).
No compiler in the cloud: every Foundation API used is iOS 17 / macOS 14 (`Decimal.FormatStyle.Currency`,
`Measurement<UnitLength>.FormatStyle(width:locale:usage:numberFormatStyle:)`, `ListFormatter`,
`RelativeDateTimeFormatter`, `DateComponentsFormatter`, `PersonNameComponents.FormatStyle`,
`Locale.measurementSystem`). Please run `swift test --filter LocaleDisplayTests` and the app build on the Mac.

## Principle

One presentation-only formatter, `Core/LocaleDisplay.swift`. **Chinese output is byte-identical to before**
(`¥12.50`, `yyyy-MM-dd HH:mm`, `1.2 公里`), so the CN launch does not move and existing CN tests stay green.
Every other language gets Apple locale formatting. Server values are never changed; currency comes from the
order (`currencyCode`, default `CNY` because no wire contract carries a currency yet), never from the device.

| Area | en-US result | API |
|---|---|---|
| Money | `CN¥12.50` (CNY order), `$12.50` (USD order) | `LocaleDisplay.money(_:currencyCode:locale:)`, `money(fen:)`, `money(text:)`, `money(_:negative:)`, `currencySymbol` |
| Dates | `Nov 27, 2026, 3:05 PM`, `3:05 PM`, `Nov 27, 3:05 PM` | `day`, `dayTime`, `monthDayTime`, `time`, `month`, `date(zhPattern:template:)` |
| Server civil text | `"2026-11-27 23:30:00"` → `Nov 27, 2026, 11:30 PM` (no zone shift) | `LocaleDisplay.civil(_:locale:)` |
| Distance / speed | `0.9 mi`, `500 ft` (US) · `1.5 km` (en-CN, metric) | `distance(meters:)`, `distance(kilometers:)`, `radius(meters:)`, `speed`, `usesMiles`, `roadNumber` |
| Durations / relative | `1 hr 5 min`, `in 3 hours` | `duration(seconds:)`, `relative(_:to:)` |
| Lists | `Alice, Bob, and Cara` | `LocaleDisplay.list` |
| Names / addresses | given-first in en, family-first in zh; address small→large with commas in en | `personName`, `address` |
| Numbers / percent | `12,480`, `12.5%` | `number`, `percent` |
| Phone | `+1 (415) 555-0132` → wire `+14155550132`; `+86` wire unchanged (`13800138000`) | `PhoneCountryCode` |
| Plurals | `1 stop` / `2 stops` | xcstrings `variations.plural` (en) |

## What changed (file:line)

**Foundation**
- `Core/LocaleDisplay.swift` (new): `LocaleDisplay` + `PhoneCountryCode`.
- `Tests/CoreTests/LocaleDisplayTests.swift` (new): zh byte-identity, en formatting, miles/km, civil re-render, lists, names, addresses, phone wire values.

**Phone entry with country code (+86 / +1)**
- `App/AuthChannelView.swift` `countryMenu` (≈line 205): the fixed `+86` label became a `Menu`/`Picker` chip (dial code only, so the field keeps its width in both languages; rows carry the country names). Placeholder per country (`auth.channels.phone` / `auth.channels.phone.us`). Input sanitising and validation follow the country (`sanitize`, `wireValue`).
- `App/AuthChannelModel.swift:12,30,37`: `country` state; `sendCode`/`signIn` send `country.wireValue(phone)`.
- `Core/AuthChannelService.swift:15`: `AuthChannelInput.phone` also accepts E.164 `+1` NANP numbers. CN rules unchanged (existing invalid-phone tests, including `+8610000000000`, still fail as before).
- In the US build the phone form is still hidden behind `region.usLoginPending` (`supportsDomesticPhoneInput`), as before: the picker is ready for whichever US login method the owner chooses.

**Money (no hard-coded ¥ in English)**
- Shared helpers now locale-aware, Chinese unchanged: `App/E1CommerceComponents.swift:110-126` (`E1Money`), `App/ClubKit/ClubMPArt.swift:79-91` (`ClubMoneyText.display`, one-arg form uses `Locale.current`), `App/ProfileOrdersView.swift:864-871` (`ProfileOrderYuan`).
- Direct sites: `TopicXcxSections.swift:283,719`, `ActivityPresentationComponents.swift:89`, `ActivityDetailView.swift:326,707`, `TopicDetailView.swift:561`, `ClubMemberWelcomeSheet.swift:133`, `NativeR2/CityOrientation/CityOrientationEventDetailList.swift:103`.
- Cooperation finance (club pages): `CoopFinanceSummarySection.swift:36`, `CoopFinanceProfitView.swift:164,210`, `CoopSettlementDetailView.swift:119,121,185` → `LocaleDisplay.money(_:negative:locale:)` (keeps the U+2212 sign and two decimals). Pinned source test updated in the same commit: `Tests/AppUnitTests/CoopFinancePresentationClosureTests.swift:62-69`.
- Fee input prefix: `CooperationContextualViews.swift:617` → `LocaleDisplay.currencySymbol`.

**Distance (miles in US, km in CN)**
- `CityKit/CityTokens.swift:55` (`CityCopy.distance`), `CityKit/CityLiveOnMap.swift:178,204` (live stat value + unit), `RoamLiveSessionView.swift:595,615`, `GrowthCenterView.swift:210`, `ProfileSelfGrowthSection.swift:54`, `RoamExperienceComponents.swift:323`, `RoamHistoryShareView.swift:125`, `RoamSubpageParityViews.swift:277`, `PlayerParityBViews.swift:89`, `ClubActivityListContent.swift:101`, `TopicXcxSections.swift:622`, `NearbyTeamMapViews.swift:111,149,179`, `NearbyTeamViews.swift:128,331`, `SquareCloudFeedViews.swift:128`, `NearbyMerchantView.swift:195`.
- `Measurement` formats gained `usage: .road`: `SearchRoutePreviewView.swift:51,58`, `SearchMapDetailViews.swift:38,41`, `RoamComponents.swift:47`, `ActiveDestinationSummary.swift:55`, `NativeR2/MapHome/RoamMapHomeRoutes.swift:53`.

**Dates / times**
- `CityKit/CityTokens.swift:69` (`CityCopy.clock`), `NativeR2/CityOrientation/CityOrientationNavComponents.swift:24` (ETA arrival clock), `SettingsPostGovernanceView.swift:53-56`.
- Server civil text re-rendered with `LocaleDisplay.civil` (Chinese returns input unchanged): `ClubActivityListContent.swift:110`, `ClubManagedProjectsSection.swift:35`, `RoamStampViews.swift:396,477`, `NativeR2/FreeExplore/NativeStampAlbumView.swift:235`, `NativeNotificationDeliveryLogView.swift:39`, `GrowthCenterView.swift:357`, `ClubEditionsShareSection.swift:74`.

**Lists**
- `JourneyRoleViewSection.swift:92`, `PlayerParityBViews.swift:542`, `AccountDeregistrationImpactSection.swift:52` → `LocaleDisplay.list`.

**Plurals**
- `tools/add_i18n_r1_plurals.py` (new, idempotent): 54 English count strings now vary by plural (`one`/`other`), e.g. `club.story.stopCount %lld`, `d7.checkin.streak.value %lld`, `g6.promo.remain.days %lld`, `club.ops.clubLimit.count %lld`, `activityParity.header.registeredCount %lld`. Rules: one integer argument only, a known noun right after it (verbs like "stops working" excluded), never `merchant.*`, and never a key spelled anywhere in tools/, Tests/ or docs/ (contract checks and fragments compare those as plain stringUnits; 55 more candidates stay plain for that reason and need their fragment/test updated in a later pass). Chinese keeps its single stringUnit.
- Tools taught to read `variations.plural`: `tools/check_scaffold.py:31-38`, `tools/check_catalog_coverage.py` (`string_units`, per-form specifier check), `tools/check_nearby_team_module.py:15`.

**Catalog keys added** (fragment `docs/port/strings/i18n-r1-locale.json`, merged): `unit.mile.abbr`, `club.activityList.miles`, `parityB.passport.mi`, `auth.phone.country.cn`, `auth.phone.country.us`, `auth.phone.countryCode`, `auth.channels.phone.us`.

**Ratchet**
- `tools/check_locale_format.py` + `tools/locale_format_baseline.json`: per-file counts of hard-coded `¥`, fixed `dateFormat` literals, literal km/公里 units, `joined(separator: "、")`, and `UnitLength` measurements without `usage:` in player/club App code. Counts can only go down; it also runs the plural ratchet.

## Counts before → after (player/club App files, `tools/check_locale_format.py`)

| Rule | Before (`fc95e6a19`) | After |
|---|---|---|
| `¥` glued to an amount | 27 | 19 (most remaining are the kept zh branches of the shared helpers, plus creator/publisher screens) |
| fixed `dateFormat` literal | 8 | 6 (wallet parsers are wire parsing, not display) |
| `joined(separator: "、")` | 11 | 8 (remaining: creator/mod tools) |
| `UnitLength` measurement without `usage:` | 6 | 1 (map-home radius picker, keeps km options on purpose) |
| literal km / 公里 unit | 13 | 13 (all remaining are Chinese-only branches; English goes through `LocaleDisplay`) |
| English count strings with plural variants | 0 | 54 (55 more blocked by pinned fragments/tests) |
| Money/date/distance call sites through `LocaleDisplay` | 0 | 57 |

Gates on the pushed head: `check_scaffold.py` PASS; `check_a11y_lint.py` 0 new; `contract_ratchet.py --check` new 0 (104 baseline);
`check_locale_format.py` PASS; `check_catalog_coverage.py` gaps 0.

## Not done in this round (next pass)

- Core display strings that still carry a fixed CN pattern and are shown from many call sites (`ClubOccurrenceClock.display`, `OrderLifecycleTime.display`, `OrientSession…`, `ClubCheckinRail`, `RegistrationQuoteDelivery.windowText`, `JourneyDateFormatterHelper.monthDayTime`): wrap their view sites in `LocaleDisplay.civil`, or give them a `locale:` overload.
- Creator/publisher money (`PublisherLifecycleViews`, `ExternalGameReviewScreens`, `MPParityPassSession`, `HostTipViews`), Core `PlatformPass`/`IMCoopInviteCards`/`TopicPricingXcx` `¥` strings.
- Unit-label keys whose English value embeds `km` next to an argument (`roam.w208.entry.distance %@`, `topicXcx.routeNote.walk %@`, `playx.finishRoute.km %@`, `roamSub.w208.history.strip …`, `roam.share.square.copy`) — need a formatted-distance argument and an English value without the unit.
- Multi-argument count strings (for example `club.calendar.day %@ %lld`, `d7.checkinRank.detail %lld %lld`) need xcstrings substitutions, not a plain plural variation.

## Owner questions

1. **US currency.** US orders: will the server send a currency code (USD) on quotes/orders? Until it does, every amount is presented as CNY (`CN¥` in English). `LocaleDisplay.money(…, currencyCode:)` takes the code as soon as the contract has it.
2. **US phone login.** The +1 picker sends E.164 (`+14155550132`). Confirm the US backend accepts that format (or tell us the expected shape) when the US login method is chosen; CN keeps the bare 11 digits.
3. **Time zone for City/Monopoly and orienteering clocks.** They are still shown in Beijing time (now with a locale-correct clock format). For US players, should these switch to the phone's time zone (reform plan U03 says UI shows the phone zone)?
4. **Distance unit choice.** We follow the device locale (US English → miles; English in China → km). Confirm that is wanted rather than forcing km for China-hosted routes.
