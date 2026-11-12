# cloud-b1 journey

Branch `ui/cloud-b1-journey` rebased onto `origin/ui/next`.

Source: `liboyang42-cpu/hengyin` `chengyinhub-xcx/subpackageJourney/utils/journey-api.js` at `1c80c5aea8f721ca8575e6108048495b100f5576`, plus the landing and seat pages that call it (`pages/landing/index.js`, `pages/seats/index.js`). The port keeps that client: one call per export, JSON on POST except `rate` (form), `idQuery` drops nil / "" / "0" / 0. No new routes and no seat release (the page does not call `/release`).

## JourneyLoopSource

`Core/JourneyLoopSource.swift` sends the read exports and the three seat writes through an injected transport. A production endpoint class, and the hosts this repo already treats as production (`chengyinhub.com`, `chengyinhub.cn`, `47.103.124.64`), are refused before a request exists.

`JourneyLoopSource.journey` is one case per export. The table stays on the reader: `App/MPParityKit.swift` already defines `struct MPParityBindings` for the view factories, and this branch does not add `Core/MPParityBindings.swift`. `issueReferral` and `giftClaim` are marked money. `JourneyLoopSource.moneyWritesEnabled` is false, and those two methods throw `JourneyRefusal.moneyOff` without writing a request id or calling the transport. `ReleaseMoneyWriteSwitch` is unchanged and still off. Affiliate is the existing summary read (`limit=20`); it does not pay out.

Seat invite, claim, and cancel save the request id before the POST and reuse it. The id matches the server rule `[A-Za-z0-9._:-]{1,64}`. Storage keys: `journey-seat-invite:<registrationId>` and `journey-claim:seat:` plus the last 24 characters of the token (the page's `journey-claim:` key). Cancel is kept as `journey-seat-cancel:<invitationId>` so a timeout can re-read; the page only held that id in memory. A finished answer (including HTTP/business 4xx) drops the id. `netFail`, `code == "fail"`, or a code >= 500 keeps it.

`rereadSeatInvite` / `rereadSeatClaim` / `rereadSeatCancel` POST that saved id once and do not mint a replacement. That is the receipt re-read: the server replays the stored request record for the same id. There is no separate GET-by-requestId. `GET /api/play/seat-invitations/{invitationId}` stays the status read already in `journey-api.js`.

## Deep links

`CheinDeepLink` still parses `chein://roam/go`, `chein://ticket/<id>`, and `chein://club/<id>/join` with the same limits. It also accepts:

- `chein://referral/<token>`, `chein://gift/<token>`, `chein://seat/<token>` with optional `/aid/<id>` and `/tid/<id>` on a seat
- `chein://landing?k=r|g|s&t=<token>` and optional `aid` / `tid`
- the mini-program path `subpackageJourney/pages/landing/index` through `JourneyLoopSource.journeyLink`

A token is the page rule: 1...512 UTF-16 code units, no control characters. `aid` and `tid` are positive canonical decimal ids. The owning tab is Explore. Replay records a `JourneyLinkIntake` and does not claim, pay, or start a run.

## Tests

- `Tests/CoreTests/JourneyLoopSourceTests.swift` — reader paths, `idQuery`, form `rate`, money methods send nothing, production refusal
- `Tests/CoreTests/JourneySeatRecoveryTests.swift` — saved request id, unconfirmed keep, receipt re-read, conflict clears, cancel path
- `Tests/CoreTests/CheinDeepLinkTests.swift` and `Tests/AppUnitTests/RootPresentationCoordinatorTests.swift` — landing intake

This environment has no Swift compiler, so the Swift tests were not executed here. `python3 tools/check_design_lint.py` passed. `python3 tools/build_page_route_table.py --check` passed (260 pages). `python3 tools/check_scaffold.py` still stops on the AppSession line ratchet, which is already over on `origin/ui/next` (`AppSession.swift` 8206 > 8181, `AppCompositionRoot.swift` 4784 > 4498). This change adds no lines to either file.
