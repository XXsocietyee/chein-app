# pages/member/index/index page-ready

Lane CB199. Native screen `App/AccountView.swift`. Map status stays exists. No view file was edited.

`Core/MemberHome.swift` already reads `AuthEndpoint.userInfo` (`api/userInfo`) and `MemberRoleInfoReadRoute` (`api/role/info`). `MemberHomePageModel` adds loading, empty, error, unknown, and ready for those reads. Unknown numbers use "—". A literal 0 stays "0". Source `friendCount` still uses display zero when a counter is missing.

Banner and the points sheet stay hidden. `showsMerchantChoice`, `paymentEnabled`, `payoutEnabled`, `withdrawalEnabled`, and `virtualGoodsEnabled` stay false.

EN and zh-Hans keys, plus accessibility identifiers, are in `docs/release/ui-strings-pages-member-index-index.json`. `MemberHomeFixtureData` is DEBUG-only.

Tests: `Tests/CoreTests/MemberHomePageReadyTests.swift` and `Tests/ContractChecks/test_member_home_page_ready.py`.

Left: `MemberHomeHeader` still shows the source integer for a missing counter. Wiring that header to `friendCountText` is view work.
