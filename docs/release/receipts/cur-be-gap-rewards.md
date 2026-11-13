# cur-be-gap-rewards

Branch `ui/cur-be-gap-rewards` from `ui/main` `cf28847602bc393ebcead93ca35d85633d23801b`.

Handover 21 and the 2026-11-13 owner correction. Points, badges, and non-cash rewards stay on screen and callable. Cash value, redeem-for-money, and payout stay behind `ReviewedAreaSwitch.moneyPayments` and `payout`. Those flags, plus `merchantWrites`, `passwordLogin`, and `externalGames`, are true only in a DEBUG build whose `QuestifyAPIBaseURL` host is set and is not `www.chengyinhub.com`. Release, an empty host, and the production host stay off. The screens are not hidden. A cash case (`CASH_REFUND`) shows `CASH_CLOSED` and does not report success. The Core client still refuses that reason before the network, matching `RewardPledgeTests`.

| item | state |
| --- | --- |
| `App/ReviewedAreaSwitch.swift` | new. Five flags, one host rule. |
| `ChinaReviewedRouteCapability.admitsRewardPledge` | prefix for `/api/reward-pledge` and `/api/rewards/noncash`; exact `/api/coupon` only. `callSiteCount` 997, `missingCount` 375, `wiredPatternCount` 677 unchanged. `/api/coupon/command-receipt` stays false. |
| `ReviewedProductionGateLeases.rewardPledgePaths` | the 19 roots, appended. `acceptsPlayerWrite` admits those roots and their id children, and not coupon children. |
| `sessionDependencies` | China sessions receive the existing non-cash approval flags. `AppSession` and `AppCompositionRoot` were not grown. |
| `RewardPledgeViews.openSupport` | switch off refuses locally. Switch on follows the Core refusal and keeps the notice `CASH_CLOSED`. |
| Unknown | existing notice token stays `unknown` where tests read it. No new unknown label was added. |

`RegionalLaunchConfiguration.swift` was not edited. `ReleaseMoneyWriteSwitch` stays all false.
