# PAGE-READY `subpackageA/pages/assetcenter/analysis/index`

CB221. 资产余额变动分析明细. Map status `exists`. Native entry is `WalletIncomeAnalysisView` from `App/WalletCommerceViews.swift` (`wallet.analysis.open`). No view file was edited.

Already on `rc/20261108`: `WalletIncomeAnalysisReader` reads the existing `POST api/user/balance/list` via `WalletCommerceReader.ledger(.income(.all))`. `WalletIncomeAnalysisPresentation` keeps a missing direction, amount, currency, or date out of the sum. `wallet.analysis.unverified` is an em dash in `Resources/WalletIncomeAnalysis.xcstrings`. Proof: `Tests/AppUnitTests/WalletIncomeAnalysisClosureTests.swift` (12 tests) and `Tests/ContractChecks/test_wallet_income_analysis_closure.py`.

Added: `AssetCenterAnalysisPageModel` phases loading, empty, error, unknown, and ready. Unknown money text is `—`; a known zero stays `0`. The reader exposes `pageModel` for the slice it already loaded and does not open a new route. DEBUG `AssetCenterAnalysisFixtureData` is in `Core/WalletCommerceSyntheticFixtures.swift`. EN and zh-Hans keys plus the four accessibility identifiers are in `docs/release/ui-strings-subpackageA-pages-assetcenter-analysis-index.json`.

Left: no DEBUG host mounts this screen (`docs/release/ui-fixture-index.md`). Screenshot is still none. Payment, payout, withdrawal, and virtual goods stay off. Xcode was not run.
