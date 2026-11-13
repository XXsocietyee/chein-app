# cloud-pwave

Branch `ui/cloud-pwave`. Base `origin/ui/next` `bdd0a90b3b3c1abb52c767d2fe877effed428755`.

Owner approval 2026-11-12, verbatim choice "Yes, allow them".

## What the shipped China composition constructs

`ReviewedProductionGateLeases` mints the readers only when `playerWritesEnabled` is on, the market is China, and the base URL is `https://www.chengyinhub.com/prod-api/`. Production gates alone do not. The process-default composition and `reviewedMarketDeployment` still return nil.

- `JourneyLoopSource` for the invite landing (`POST /api/referral/landing/referral` and `/gift`), seats lobby (`GET` seats plus empty-multipart `POST /api/user/info` for the signed-in nickname), run report, memory, choices, quest rank, and team ranking.
- `PWaveReader` with the player-read grant: battle report, invite landing, play mode, ticket seats, theme collection, run memory, member board. Not affiliate, not city pass.
- `PublicCatalogHost` on `PublicCatalogHostWiring.host` for anonymous `POST /api/public-catalog/city/list`, `list`, `filters`, and `info`.
- `MPParityBindings.journeyLanding`, `journeySeats`, `journeyReport`, and `journeySettle` filled on the existing bindings value. `journeyPromo` stays nil.

Seat invite, claim, and cancel use the player-write approval already on this composition. An unknown or 5xx answer stays on the saved request id. Rating is `POST /api/comment/add` (form), owner type 1 for a topic and 2 for a session. A rating that is not a confirmed 2xx does not draw thanks.

Unknown numbers stay an em dash. Share does not issue a referral token, so `shareURL` stays nil until the server returns an https URL for a seat invite.

## Stayed off

Pass purchase, gift purchase, gift claim (`/api/marketing/product/gifts/claim`), referral-token issue (`/api/marketing/referral/token`), affiliate summary and payout, catalog map/ids, every money path, merchant and coop operator writes, password login, and roam presence. `ReleaseMoneyWriteSwitch.blocks` and `forcedOff` are unchanged. `MPCommerceGate` purchases, claims, and payout stay false, so the landing claim button stays the gate note. Door scan and binding stay false. `App/RegionalLaunchConfiguration.swift` was not edited.
