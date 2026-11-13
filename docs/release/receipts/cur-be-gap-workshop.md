# cur-be-gap-workshop

HANDOVER 22 plus the 2026-11-13 owner correction.

Branch `ui/cur-be-gap-workshop` was cut from `origin/ui/main` `cf28847602bc393ebcead93ca35d85633d23801b`. That tip later gained `4f38fb85b`; this branch was not rebased and `ui/main` was not pushed.

`App/ReviewedAreaSwitch.swift` is new. `moneyPayments`, `payout`, `merchantWrites`, `passwordLogin`, and `externalGames` are true only in TEST/DEBUG when the host is non-empty and is not `www.chengyinhub.com`. Release builds and the production host stay false.

Purchased list/detail, StoreKit purchase, paid install, settlement, and income screens stay on screen. Those calls run only while the matching switch is on. Unknown income text stays an em dash. Writes are not reported as success when the switch is off.

Non-money workshop/mod prefixes are appended in `workshopModOwnerGrant`. `wiredPatternCount` is unchanged. `RegionalLaunchConfiguration.swift`, `AppSession`, and `AppCompositionRoot` were not grown.

`python3 tools/generate_project.py`, `tools/check_scaffold.py`, and `tools/check_design_lint.py` passed. This machine cannot compile Swift.

Backend pair: `feature/be-gap-workshop` on hengyin, parent `e10a8e98f22b07f490a82d207d40692caaa67402`. Curl evidence is `docs/delivery/be-gap-workshop/RESULT.md` in that repo.
