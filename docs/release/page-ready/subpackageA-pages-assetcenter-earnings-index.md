# PAGE-READY subpackageA/pages/assetcenter/earnings/index

Map status stays `exists`. The screen is `WalletCommerceHomeView` in `App/WalletCommerceViews.swift`, with stage and tab state in `App/WalletEarningsOverview.swift`.

Reads already wired, and left live only where the route map already says so: `WalletCommerceService.withdrawalBalance` posts `api/user/info`, and `stages` posts `api/wallet/stages`. `WalletScreen` plus `WalletFundsStagePhase` already cover loading, empty, failed, and unknown. A known zero stays `0`. Unknown money on this page is U+2014 (`—`), including `wallet.earnings.stages.unknown`.

Withdrawal and payout stay off. `WalletPayoutCapability.isOn` is false, and `ReleaseMoneyWriteSwitch.withdrawalEnabled` and `payoutEnabled` are false. No withdrawal sender was added.

Evidence already on `rc/20261108`: `Tests/AppUnitTests/WalletEarningsOverviewTests.swift` and `Tests/ContractChecks/check_wallet_earnings_overview.py`. This pass adds DEBUG `WalletEarningsOverviewFixtureData` in `Core/WalletCommerceSyntheticFixtures.swift` and `testEarningsOverviewFixtureKeepsUnknownAsEmDashAndKnownZero`. Strings and accessibility identifiers are in `docs/release/ui-strings-subpackageA-pages-assetcenter-earnings-index.json`.

Left: view files were not edited, so the home still draws the em dash and several labels inline. The DEBUG menu host still does not mount the home unless `designHome` is set. `Localizable.xcstrings` and `tools/current_ci_manifest.json` were not changed. No Xcode build was run.
