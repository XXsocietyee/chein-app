# ui-cur-fixtures-2 — DEBUG fixtures for the remaining screens

Base: `origin/ui/main` `e3264af9fc694cfadea419e59d31c790aa8163c1`.
Launch: `--design-fixture <name>`. Registry: `CurFixtures2.make` in `App/DesignFixtures/DesignFixtureRegistry.swift`.
Host: `https://fixture.example`. Token: `synthetic-fixture-token`. A missing or unknown value is an em dash. No fixture reports a write, a payment, or a redeem as done.

`moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` are not opened. Club export and merchant invite are asked with API host `www.chengyinhub.com`, so those two switches stay closed. The purchased-workshop list is mounted on a blank `AppSession`, so `paymentsOpen` stays false and the list is not requested.

`swiftc` is not on this machine (`swiftc` and `xcodebuild` are absent). No parse and no typecheck were run. This is not a green typecheck.

## parity-a

| Screen | Normal | Non-happy |
|---|---|---|
| Deep-link landing `MPParityPageEntry` | `cur2-deeplink` (reveal page) | `cur2-deeplink-unavailable` (membership page, unsigned session) |
| Team report sheet | `cur2-team-report` (reason picker, access enabled) | `cur2-team-report-hidden` (entry draws nothing; access is nil) |
| Story-walking author entry | `cur2-walking-author` (`ProjectEditView`, full scope) | `cur2-walking-author-readonly` (whitelist scope, `fullEdit` is false, the link is absent) |
| AIGC label | `cur2-aigc` (label plus filing number) | `cur2-aigc-unlabeled` (not `ai_simple`, no filing number, nothing drawn) |

The report sheet's submitted, unavailable, and failed lines are private `@State` and appear only after submit. The fixture mounts the real picker and the hidden entry.

## G6

| Screen | Normal | Non-happy |
|---|---|---|
| NPC prompt | `cur2-g6-npc` (`roamNpcEvent` true, line 「夜路留神。」) | `cur2-g6-npc-off` (flag false, no bubble) |
| Topic characters | `cur2-g6-characters` | `cur2-g6-characters-empty` (read throws, section stays hidden) |
| AI draft V2 | `cur2-g6-ai` (live source; a FAILED row is in the recovery document) | `cur2-g6-ai-hidden` (no live capabilities, section hidden) |
| Promotions | `cur2-g6-promo` | `cur2-g6-promo-empty` (empty catalog, section hidden) |
| Revenue allocations | `cur2-g6-revenue` | `cur2-g6-revenue-failed` (read throws: 收益暂不可用, never 0) |

The AI history list loads when the open button is tapped. The resting screen is that button. The recovery document is a FAILED row with a null reason, not a success.

## mount-g45

| Screen | Normal | Non-happy |
|---|---|---|
| My posts `SquareMineListView(.posts)` | `cur2-square-posts` | `cur2-square-posts-failed` |
| Bookmarks `SquareMineListView(.bookmarks)` | `cur2-square-bookmarks` | `cur2-square-bookmarks-empty` |
| Account links | `cur2-square-links` | `cur2-square-links-hidden` (no capabilities) |
| Safety summary | `cur2-safety-summary` (SUFFICIENT / NEUTRAL) | `cur2-safety-summary-hidden` (INSUFFICIENT, nothing drawn) |
| Correction sheet | `cur2-correction` | `cur2-correction-failed` (taxonomy throws) |
| Safety rating sheet | `cur2-safety-rating` | `cur2-safety-rating-failed` (taxonomy throws) |
| Report appeal | `cur2-appeal` (appeal button) | `cur2-appeal-unconfirmed` (transport throws; the failure line is after submit) |
| Geocode | `cur2-geocode` | `cur2-geocode-empty` (empty address, button disabled) |
| Shop visitors | `cur2-visitors` | `cur2-visitors-none` |
| Map weather | `cur2-weather` (rain) | `cur2-weather-clear` (nil weather, nothing drawn) |
| Share revoke | `cur2-share-revoke` (pending, write accepted, 「已作废」) | `cur2-share-revoke-failed` (pending kept) |
| Adopt template | `cur2-template-adopt` | `cur2-template-adopt-refused` (result line after the tap; a lost read is unconfirmed, not adopted) |
| Location todos | `cur2-location-todos` | `cur2-location-todos-unread` (failed read draws nothing, not 「没有待办」) |
| Save as template | `cur2-save-as-template` (topic kind only) | `cur2-save-as-template-refused` |
| Unified search | `cur2-unified-search` | `cur2-unified-search-unavailable` (HTTP 503, 「内容搜索暂未开放」) |
| Place search | `cur2-place-search` | `cur2-place-search-unavailable` |
| Public merchant trust | `cur2-merchant-trust` | `cur2-merchant-trust-hidden` |

The mount entries (`PlayStoreDaySafetyRatingEntry`, `PlayStoreDayGeocodeEntry`, `RoamPlaceVisitorsLine`, `RoamMapWeather`, `RoamShareRevokeEntry`, `TemplateAdoptEntry`, `TemplateLocationTodosEntry`, `MyProjectSaveAsTemplateEntry`, `UnifiedSearchEntry`) are the hosts of the views above. The fixtures mount those views. `MapPlaceSearchModel` is the model behind `MapPlaceSuggestions`.

## be-gap

| Screen | Normal | Non-happy |
|---|---|---|
| IM desk | `cur2-im` | `cur2-im-missing` (`clubID` 0) |
| Club board | `cur2-club` | `cur2-club-withheld` (nil token) |
| Reward pledges | `cur2-rewards` (one AWARDED row) | `cur2-rewards-failed` (retry, list not shown as empty success). `cur2-rewards-closed` is the grant-off line `rewards.unavailable` |
| Purchased workshop | `cur2-ws-purchased` (purchase reads off, list not requested) | `cur2-ws-purchased-unavailable` (nil browser) |
| Paid install entry | `cur2-ws-install` | `cur2-ws-install-unconfigured` (nil controller) |
| Merchant hub | `cur2-merchant` | `cur2-merchant-unknown` |
| Play-gap misc | `cur2-playgap` | `cur2-playgap-device` (line starts as —) |

IM result text and the club reply start as an em dash. A missing id or a withheld call stays that em dash after the button. The merchant hub reads `ReviewedAreaSwitch.current` and does not override it. An open switch on that hub says not sent. Unknown merchant fields are em dashes. Redeem and cash stay off. The device page does not invent a status.

The paid-install `notConfigured` line is shown after the button. Both install names mount that entry. The sample item decodes only when the purchased-metadata JSON matches the contract; a decode failure shows an em dash instead of a fake license.

## External games

| Screen | Normal | Non-happy |
|---|---|---|
| Catalog | `cur2-ext-catalog` (author and summary nil, shown as —) | `cur2-ext-catalog-failed` |
| Submit | `cur2-ext-submit` (submit button; no session, catalog fails closed) | `cur2-ext-submit-unknown` (unconfirmed request, not a success) |
| My submissions | `cur2-ext-submissions` (PENDING, reject reason —) | `cur2-ext-submissions-failed` |
| Report | `cur2-ext-report` (the report form) | `cur2-ext-report-unknown` |

`ExternalGameReportSheet` does not render `reportOutcome`. The lost-result line is the submissions screen's 「结果未知，仍保留请求 req-unknown。」 Catalog install is not claimed: there is no session, so a download is unavailable.

## Not fixtured

- `BundleExitSwapView`. `FreeExploreBundleReadHost` returns nil unless approval, origin, and account match, and `makeExitSwap()` needs the live order service. No `AppSession` seam was added.
- A populated purchased-workshop list. `WorkshopPurchasedLibraryView` requests the list only when `ReviewedAreaSwitch.paymentsOpen` is true. Payments stay closed on a blank session and on `www.chengyinhub.com`. The closed copy and the nil-browser link are the fixtures.
- Workshop settlement and income as their own confirmed-money screens. No separate view was found that can show a settled amount without opening payments. Wallet income already has the `e4-wallet-income` fixtures. `CASH_CLOSED` is the rewards notice, not a workshop screen.
- `TemplateProjectActions(.template)` market-submit. It is not mounted. Own-shelf screens do not dispatch market-submit.

`swiftc` did not run on this VM. A later Mac parse of `9f3afe08` rejected `CurFixtures2.swift`. The follow-up only changes that file:

- `Cur2.down` is a function. The seven call sites that passed the function instead of a transport now call `Cur2.down()`.
- `page` and `roam` store the view builder in `Cur2Page.content`, so both closures are `@escaping`.
- `gameStore()` is `@MainActor`, matching `ExternalGameStore.init`.

Scaffold, design lint, and the design-fixture release exclusion gate passed on the first tree. `docs/release/contract-failing-baseline.txt` was not changed. This note is not a typecheck.
