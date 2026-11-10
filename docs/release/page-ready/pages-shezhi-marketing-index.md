# pages/shezhi/marketing/index — CB278

Page-ready read model on rc/20261108 at 86fa48b0c5833bbadd97c09f246ad05f7af1b8b0. Branch cursor/cb278. Map status stays exists. The native surface stays App/MarketingConsentOriginalPresentation.swift. Views were not edited.

Wired contract: GET `/api/merchant/crm/marketing-consents` is already live. `ShezhiMarketingIndexPageModel.offersListRoute` reads that catalog entry and does not mark it live. `/api/merchant/crm/marketing-consents/result` is not in the reviewed catalog, so `offersResultRoute` stays false. No route was added.

States: loading is `compliance.loading` while busy; empty is `compliance.marketing.empty` when the current list loaded with no merchants; error is the existing coordinator error key; UNKNOWN is an unresolved original request or a current list that is not loaded (`compliance.marketing.unknown`, `marketingOriginal.current.unconfirmed`). A loaded empty list count stays `0`. An unknown count, a non-positive merchant or record id, and a missing choice stay `—`. A request id the server sent as `0` stays `0`.

Missing catalog keys: none. User-facing keys already have en and zh-Hans in `Resources/Localizable.xcstrings`, `Resources/AccountCompliance.xcstrings`, or `Resources/MarketingConsentOriginalPresentation.xcstrings`, including `compliance.loading`, `compliance.marketing.empty`, `compliance.marketing.unknown`, `compliance.channel.IN_APP`, `compliance.channel.COUPON`, `marketingOriginal.current.unconfirmed`, and `marketingOriginal.outcome.unknown`.

Not catalog keys (accessibility identifiers only): `compliance.marketing.refresh`, `compliance.marketing.confirm`, `compliance.error`.

`WelcomeView.showsMerchantChoice` stays false. `ReleaseMoneyWriteSwitch.paymentEnabled`, `payoutEnabled`, `withdrawalEnabled`, and `virtualGoodsEnabled` stay false. `nsPrivacyTracking` stays false. Catalogs, views, the Xcode project, and `tools/current_ci_manifest.json` were not edited.

Tests: `ShezhiMarketingIndexPageTests`, `MarketingOriginalSettingsJourneyTests.testShezhiMarketingIndexPageReadsLoadedStateWithoutAnotherRequest`, `Tests/ContractChecks/test_shezhi_marketing_index_page_ready.py`. Existing marketing tests were not removed or weakened.

Left: `AccountComplianceSheet` still renders `ComplianceState` directly and does not read `shezhiMarketingIndexPage`. No DEBUG host mounts `MarketingConsentOriginalReceiptView`. Swift was not compiled. `xcodebuild` was not run. No Xcode Cloud result is claimed.
