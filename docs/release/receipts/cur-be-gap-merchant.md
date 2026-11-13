# cur-be-gap-merchant

Branch `ui/cur-be-gap-merchant` from `origin/ui/main` `cf28847602bc393ebcead93ca35d85633d23801b`.
`ui/main` was not pushed. `RegionalLaunchConfiguration.swift`, `AppSession.swift`, `AppCompositionRoot.swift`, and the contract baseline were not edited.

`App/ReviewedAreaSwitch.swift` is new. The four switches (`moneyPayments`, `payout`, `merchantWrites`, `passwordLogin`) are true only for a DEBUG build whose API host is not `www.chengyinhub.com`. A release build is closed. An empty DEBUG base URL is not that host, so it stays open for the unit helper.

Screens: `App/BeGapMerchantScreens.swift`, strings in `Resources/BeGapMerchant.xcstrings` (EN and zh-Hans, state translated). Unknown is `—`. Settings links the hub. The merchant-home authoring destination default is that hub, so the existing row is visible. The hub shows the refusal when a switch is off. When a switch is on, the row says the write was not sent. It does not call the network and does not show a write as done. `/api/pay/create` is described as not a payment; digital goods stay on StoreKit.

Owner grant `beGapMerchantOwnerGrant` is appended after `videoBountyOwnerGrant`. `admitsChinaProductionCall` ORs that set. Money paths stay refused first by `ReleaseMoneyWriteSwitch` and `forcedOff`. Marks stay missing. `wiredPatternCount` is unchanged.

Checks on this machine: `python3 tools/generate_project.py`, `tools/check_scaffold.py` PASS, `tools/check_design_lint.py` PASS (no new allowlist hit). Swift/Xcode was not run here, so `BeGapMerchantSwitchTests` was not executed on a simulator.
