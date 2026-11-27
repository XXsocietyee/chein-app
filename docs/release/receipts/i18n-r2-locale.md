# i18n r2 — locale lane receipt (2026-11-27)

Branch `i18n/r2-locale` from `origin/ui/combined-r7`. Brief: `docs/briefs/round2-1127.md` (row `i18n-r2-locale`),
scope = the "Not done" list of `i18n-r1-locale.md`. No compiler in the cloud. Please run
`swift test --filter LocaleDisplayR2Tests`, `swift test --filter LocaleDisplayTests`, and the app build on the Mac.

**Rule kept from r1:** Chinese output is byte-identical (every new path returns the old string first when the
locale is `zh`). English gets Apple formatting. China-time server values stay on the China wall clock (no zone shift,
MP `utils/datetime.js` +08:00); owner question 3 of r1 (phone zone for US players) is still open.

## Done

**Locale overloads / civil re-render (dates)**
- `ClubOccurrenceClock.display(_:locale:)` (`Core/ClubSeriesOccurrencePresentation.swift`), `OrderLifecycleTime.display(_:locale:)`
  (`Core/OrderLifecycleContracts.swift`), `JourneyDateFormatterHelper.monthDayTime(_:locale:)` (`Core/MPGap/PlayRoam/PlayRoamRound2Models.swift`).
- `RegistrationQuoteDelivery.windowText(locale:)`; `rows(locale:)` now uses it (`2026.01.01 08:00 起` zh unchanged; `Jan 1, 2026, 8:00 AM onward` en).
- View sites that print China-time text now go through `LocaleDisplay.civil` (zh returns input unchanged):
  `ClubCheckinRailView.swift` (rail session/status time, detail rows `sessionTimeText`/`statusTimeText`/`*TimeText` rows),
  `ProfileOrderSourceDetailSections.swift` (timeline step time, payment/registration/verified/expires),
  `OrderLifecycleView.swift` (timeline row time), `OrientScoreReviewSection.swift` (dispute deadline — the `OrientSession…` string).
- `ClubSeriesOccurrenceBrowser` was already locale-aware through `ClubOpsEventClock.occurrenceText(_:locale:)` — unchanged.

**Money (`¥` via the money formatter)**
- New `LocaleDisplay.yuanAmounts(in:locale:)`: re-labels `¥<amount>` inside Core/MP-built text (`CN¥30.00` in English; never touches `CN¥`, so it is idempotent; zh unchanged).
- Publisher: `PublisherLifecycleViews.swift` floor hero, floor/maximum slider labels, slider a11y value, settlement-pending rows, partner fixed fee.
- Host tip: `HostTipViews.swift` intent amount (`HostTipSource.amountText`).
- PlatformPass / pass market: `PassMarketViews.swift` (order rows, catalog orders, `PassPriceText`, pay modes, order detail amount/refund), `PassMembershipViews.swift` plan price.
- `IMCoopInviteCards.termsLine` at `IMCoopInviteStripView.swift`.
- `TopicPricingXcx` fee/take-home texts and the below-floor line (`TopicAndOfficialGapSections.swift`, new key `topicPricing.belowFloor.amount %@`).
- External game creator test prices (`ExternalGameReviewScreens.swift`, `externalGameMoney` → `LocaleDisplay.money(fen:)`).
- `tools/locale_format_baseline.json` lowered: hard-coded `¥` 19 → 15.

**Distance keys that spelled `km` next to an argument** — new unit-free keys; the argument carries its unit via
`LocaleDisplay.distanceArgument(meters:zhText:locale:)` (zh gets the exact old text, en-US gets `0.7 mi` / `500 ft`):
`roam.w208.entry.away %@` (was `.distance`), `topicXcx.routeNote.walkDistance %@` (was `.walk`),
`playx.finishRoute.distance %@` + `playx.finishRoute.metaDistance %@ %@` (were `km`/`m`/`metaKm`/`metaM`),
`roam.share.square.copyDistance` (was `.copy`). Old keys stay in the catalog (pinned by fragments/docs).
`roamSub.w208.history.strip` has no Swift caller (only an accessibility identifier) — converted to substitutions only.

**Multi-argument count strings** — `tools/add_i18n_r2_substitutions.py` (idempotent, `--check` ratchet wired into
`tools/check_locale_format.py`): 18 English values now use xcstrings `substitutions` (`%1$lld of %#@day@ left`,
`%arg day` / `%arg days`), e.g. `d7.checkinRank.detail`, `mp.member.daysLeft`, `ticketWallet.explore.redeemed`,
`playFree.story.unlocked.count`, `fixr3.team.seats.a11y`, `nativeR2.city.*.progress`. All callers use `LocalizedStringKey`
interpolation (`Text("key \(a) \(b)")`). Fragments that round-trip byte for byte were updated too
(`comp-r1-nav`, `fix-r3-account-publish-b`, `fix-r9-club-a`, `p2`). `tools/check_catalog_coverage.py` understands substitutions.

**Strings**: fragment `docs/port/strings/i18n-r2-locale.json` (6 new keys) merged into `Resources/Localizable.xcstrings`.
**Tests**: `Tests/CoreTests/LocaleDisplayR2Tests.swift` (zh identity + en formatting for every overload/helper).

## Not done

- `club.calendar.day %@ %lld` (pinned by `tools/check_club_event_calendar.py` and its Resources fragment), `cast.ending.footer`
  and `comp.kit.streak.value` (their fragments do not round-trip, so rewriting would churn them), `official.summary.search`,
  `playHelp.charged` stay plain — need their pinning check/fragment updated in the same commit.
- `roam.share.square.copyDistance` keeps "lit up %2$ld shops" without plural: the call site uses `String(format:)`, where a `%#@…@` substitution is not safe.
- `PlatformPass` price/order strings still contain Chinese words (`积分`, `首次游玩起…天内有效`) in English — wording belongs to i18n-r2-strings.
- `TopicPricingXcx.feeTexts` keeps fullwidth `（6%）` parentheses in English.
- `HostTipSource.amountText` non-CNY shows `USD 5.00` (code + digits) — could use `LocaleDisplay.money(currencyCode:)` once host tips can be non-CNY.
- `PointsHistoryPageModel` row `timeText` and `OrderInfoPageModel.timeText` have no current view caller in App; left on the zh format.

## Risks for first compile

- New `@Environment(\.locale) private var locale` in `PassMarketView`, `PassPriceText`, `PassDetailView`, `PassOrderDetailView`,
  `PassMembershipView`, `HostTipPlayerScreen`, `PlayFinishRouteCardView`, `RoamEntryCardView`, `RoamEntryMetaLine`,
  `OrientScoreReviewSection`, `ProfileOrderSourceDetailSections`, `ProfileOrderTimelineStepRow`, `TopicPricingGapSection`:
  if any of these already declares a `locale` member out of view of my grep, rename.
- `RoamEntryMetaLine` gained `var locale: Locale? = nil` (memberwise init `RoamEntryMetaLine(card:locale:)`; existing `RoamEntryMetaLine(card:)` still valid).
- `LocaleDisplay.yuanAmounts` uses `NSRegularExpression` with a lookbehind and `NSMutableString` — Foundation only.
- `PublisherPricingView.loadPricingExtra` (async) reads `locale` — the view is `@MainActor`.
- Substitution format (`%#@name@` + `argNum`/`formatSpecifier`) follows Xcode's string-catalog schema; open the catalog in Xcode once to confirm it shows no warnings.

## Gates (pushed head)

See the commit message / bottom of this file for results.
