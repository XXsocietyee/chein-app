# K40 · ADA behaviour (`cursor/1128-k40-ada`)

Source: `origin/audit/1128-ada:docs/audits/1128-ada.md`, the five biggest award gaps. Only empty, error, and loading states, and haptics and celebrations (P39). Layout, spacing, colour, and typography were not changed. `1128-plan` and `1128-functions` were skimmed so this lane does not take another domain's row.

Base: `origin/ui/combined-r7` at `a7c956335` (tip matched the pin at branch time). No `String(localized:)` added. `App/AppSession.swift` stays 7977 lines and was not edited (init order untouched). Merchant gates and money switches were not edited. No backend field was required, so `hengyin` was not changed. No secrets, deploys, or SQL.

P39 as applied here: one success haptic on the rising edge (still under Reduce Motion), one burst that `CYBurst` / `CYConfettiBurst` does not draw under Reduce Motion or Low Power, and the burst is an overlay so the existing frames stay put.

## Closed in this commit (n = 6)

| Row | What was wrong | What closed it |
|---|---|---|
| Home stream before the first page | Once the reader matched, an empty `ContentUnavailableView` could show in the frame before `loadingPage` became true. `streamReadiness` already said loading; the stream did not use it. | `HomeFeedModel.streamPlaceholder` is `.loading` until a page has loaded, `.empty` only after that page has no rows, `.error` on failure. The stream shows `ProgressView("homeFeed.loading")` until then. `testStreamPlaceholderStaysLoadingUntilAPageSettles`. |
| Stripe payment success | WeChat Pay and Alipay use `RegistrationPaidTicketMoment` (burst, none under Reduce Motion). Stripe paid was a static check. | The paid row uses the same moment. The stage-change `.sensoryFeedback(.success)` and the View ticket button stay. |
| Badge unlock haptic | Confetti and the stamp-slam were there. The comment said a success haptic; the slam is an impact. | `.cyHaptic(.success, trigger: celebrated, where: CYHapticTransition.turnedOn)` once on appear. Confetti stays in `CYConfettiBurst`. |
| Created-stamp haptic | The burst comment says the caller keeps the success haptic. The slip did. The created-stamp read-back did not. | `.cyHaptic(.success)` when `lookup.phase` becomes `.found`. The burst on the card is unchanged. |
| Wrap-up burst | The seal already bounced once and fired `.cyHaptic(.success)`. There was no particle burst. | One `CYBurst` overlay while `sealSuccess` is set, omitted under Reduce Motion. Tap-to-skip and the haptic stay. |
| Chapter complete burst | `CYChapterEndCard` already fired a success haptic and scaled the seal. No burst. | One `CYBurst` overlay on the seal, omitted under Reduce Motion. The card's type, colours, and size are unchanged. |

## Already fixed (m = 14)

| Row | Where | SHA |
|---|---|---|
| Home shows loading words before the reader matches | `HomeFeedView` `ProgressView("homeFeed.loading")` | `3250a067ab` |
| Home feed-down / offline is one `ContentUnavailableView` with Retry | `feedDownState` | `134c951869` |
| Stamp slip: success haptic when the caption is revealed | `RoamSubpageParityViews` | `674a9ec3c8` |
| Stamp collected burst, once, drawn by `CYBurst` (nothing under Reduce Motion) | slip and created stamp | `0104b75c41` |
| Wrap-up seal bounces once with the success haptic; Reduce Motion keeps it still | `JourneyReportViews` overview | `ae402bfb81` |
| City-orientation finish: one confetti burst and a success haptic; Reduce Motion reveals at once | `CityOrientationFinishSummaryView` | `13aee05b9c` |
| WeChat Pay and Alipay paid moment (burst, none under Reduce Motion) plus success / warning haptics | `RegistrationPaidTicketMoment`, pay rows | `928cbea984` |
| Badge unlock confetti (Reduce Motion draws nothing) | `PlayRewardBadgeRows` / `CYConfettiBurst` | `941e7dfae2` |
| Chapter-complete success haptic | `CYChapterEndCard` | `ced953e4d2` |
| Ticket wallet empty state (`ContentUnavailableView`, 去探索) | `TicketWalletView` | `9e369e82d5` |
| Stamp album empty, denied, sign-in, and retry states | `NativeStampAlbumView` | `2a60221139` |
| Enrollment roster empty, denied, and load-failed states | `ClubEnrollmentView` | `35852c11d4` |
| Public profile posts: `ContentUnavailableView` when there are no posts, pull to refresh, no refresh row | `ProfileAuthorPostsSection` | `5eadf204cc` |
| Roam map home: area required, location denied, nearby loading / failed / empty, in words | `RoamMapHomeSheet` | `3118b9e800`, nearby empty copy `b79a8a09c0` |

## Skipped (k = 10)

Visual layout, or another domain. Not edited.

| Item | Why it is out of this lane |
|---|---|
| Collections are not one object (badge and stamp art, names, totals) | Visual identity. Not an empty, error, loading, haptic, or celebration behaviour. |
| Roam tab map tiles, fog, explored area, position | Visual. Status words on the sheet are already the rows above. |
| Tickets drawn as a pass | Visual. The empty state is already fixed. |
| `wave-today-club` one card and a large spacer | Fixture frame. The card is `HomeTodayCard`. |
| Free-explore as a pass object instead of a form | Visual. |
| Club directory indent and the empty space under a short list | Layout of rows that exist. |
| Stamp album background and stamp shape | Visual. |
| Currency, dates, and count wording | Locale lane (`cursor/1128-l10n-art`), not a state or a celebration. |
| `ia-tabs` grey house glyph | Tab-chrome fixture. The player home loader is the Home rows above. |
| Order lookup as a list, and reward-screen colour (Done looking disabled) | Not an empty, error, loading, haptic, or celebration behaviour. |

## Tests and gates

`Tests/ContractChecks/test_k40_ada_behaviour.py` locks the placeholder order, the named success haptics, the Reduce Motion gates on the new bursts, and the Stripe paid moment. `Tests/AppUnitTests/HomeFeedReturnModelTests.testStreamPlaceholderStaysLoadingUntilAPageSettles` locks the model. Swift was not compiled in this environment.

`python3 -B tools/check_scaffold.py` PASS. `python3 -B tools/check_a11y_lint.py` 0 new. `python3 -B tools/contract_ratchet.py --check` 46 failing, baseline 46, **new 0**. `tools/check_appsession_ratchet.py` PASS (`AppSession.swift` 7977).
