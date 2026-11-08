# close-w5d (cloud/cl-w5d) — W5 partial rows, index % 4 == 3

Nothing here was compiled or run (Linux, no Swift toolchain). New Swift files are registered via `python3 tools/generate_project.py` (pbxproj diff = file registrations only); `python3 tools/check_scaffold.py` exit 0 observed after each row. page-map.csv statuses untouched.

Shared helper: `App/CloseW5dPageState.swift` (CloseW5dPageState pure resolver, CloseW5dStateView loading/empty/error-retry/denied, CloseW5dGatedNotice). Shared strings `closew5d.state.*` in Resources/Localizable.xcstrings (en + zh-Hans).

| row | what I built (file:line) | test (file::name) | remaining gap | hook needed |
|---|---|---|---|---|
| pages/merchant/crm-campaigns/index | Page-level state banner (loading / error+retry / permission-denied) at App/MerchantEngagementViews.swift:24-26 via `MerchantEngagementPageState.resolve` (App/CloseW5dPageState.swift, bottom); honest "approved-to-send" footer on the outreach section (MerchantEngagementViews.swift outreach Section footer, key `merchant.engagement.campaigns.gated`). Request shapes unchanged (Core/MerchantEngagementContracts.swift POST api/merchant/crm/campaigns). | Tests/AppUnitTests/CloseW5dPageStateTests.swift::testMerchantEngagementMapping, ::testPrecedenceDeniedThenCachedThenErrorThenLoading, ::testBlockingFlagsAndIdentifiersAreDistinct; existing Tests/CoreTests/MerchantEngagementProductionTests.swift covers create-campaign via fake `Wire` transport | Production POST api/merchant/crm/campaigns still gated: `NativeRuntimeDependencies.merchantEngagementApproval` is nil (App/NativeRuntimeDependencies.swift:27/57). Not bypassed. | G1 composition: set `NativeRuntimeDependencies.merchantEngagementApproval` to a reviewed `MerchantEngagementProductionApproval` once the grant exists |
