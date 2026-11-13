# cur-be-gap-club

Branch `ui/cur-be-gap-club`. Parent `origin/ui/main` `cf28847602bc393ebcead93ca35d85633d23801b`.

Handover 20 and the 2026-11-13 owner correction. Working screens for the 22 club and merchant-club paths. `App/AppSession.swift` and `App/AppCompositionRoot.swift` are unchanged. `RegionalLaunchConfiguration.swift` and `docs/release/contract-failing-baseline.txt` are unchanged.

## Calls

`Core/ClubGapClient.swift` posts JSON with sorted keys, or GET `/api/club/lead?activityId=`. Authorization is the raw token. Success is HTTP 2xx and body `code` 200. A bool is not a code. A missing message is an em dash, not 0. A transport failure is sent and not successful. A withheld call is not sent.

`/api/club/settlements/export` is sent only when `allowsPayout` is true. The merchant invite `POST /api/coop/invite` is sent only when `allowsMerchantWrite` is true. Proxy enroll is sent and the 403 stays a failure.

`App/ReviewedAreaSwitch.swift` is new. `payout`, `moneyPayments`, `merchantWrites`, and `passwordLogin` are true only when the build is TEST/DEBUG and the API host is non-empty and not `www.chengyinhub.com`. `externalGames` is true only for a non-empty host that is not that production host.

The China production grant admits the 21 non-export paths. Marks, `missingCount` 375, `callSiteCount` 997, and `wiredPatternCount` 677 stay. The player-write lease admits those same 21 paths and does not admit export.

## Checks

`python3 tools/check_design_lint.py` passed. `python3 tools/check_scaffold.py` passed (catalogs, release config, privacy, design lint, project equivalence, AppSession ratchet, page route table). This VM has no Swift compiler, so `ClubGapClientTests` and `ReviewedAreaSwitchTests` were not executed.
