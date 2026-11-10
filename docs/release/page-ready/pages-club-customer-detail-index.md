# pages/club/customer-detail/index

PAGE-READY for 俱乐部客户详情与标签备注. Map status stays `exists` on `App/ClubOpsCustomerViews.swift`. This lane does not edit a view.

- Contract already in the repo: `ClubGovernanceRead.customer` is `api/club/crm/customers/detail` (`Core/ClubGovernanceContracts.swift`). `ClubCustomerDetailPage.readOperation` uses that read. `routeMarkedLive` is false. No route was added.
- Capability: `ClubCustomerDetailCapability` follows `CUSTOMER_DIRECTORY` / `allowsCustomerDirectory`. A missing grant stays hidden and does not call the reader. `includedInPlayerFirstEntry` is false.
- Model: `ClubCustomerDetailPage` in `Core/ClubOpsCustomerPresentation.swift` has loading, empty, error, unknown, and ready. Unknown counts and an unknown paid amount display `—`. A literal JSON 0 stays 0. Null paid amount stays withheld.
- Tests: `testCustomerDetailPageStaysHiddenWithoutDirectoryCapability`, `testCustomerDetailPageLoadingEmptyReadyAndLiteralZero`, `testCustomerDetailUnknownCountsAreEmDashNeverZero`, and `testCustomerDetailLoadUsesExistingReadAndHidesADeniedGrant` in `Tests/CoreTests/ClubOpsCustomerPresentationTests.swift`. `test_customer_detail_page_states_stay_off_player_entry` in `Tests/ContractChecks/test_club_ops_customer.py`.
- Strings: `docs/release/ui-strings-pages-club-customer-detail-index.json` has en and zh-Hans keys plus accessibility identifiers.
- Fixture: `ClubCustomerDetailFixtureData` is compiled only inside `#if DEBUG`.

Left: `App/ClubOpsCustomerViews.swift` still draws `ClubOpsCustomerDetailPresentation` integers. Binding these phases is a later view change. Xcode was not run.
