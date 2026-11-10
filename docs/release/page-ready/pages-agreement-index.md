# pages/agreement/index

Screen `App/SettingsLegalDocumentView.swift` was not edited. Map status stays `exists`.

The bundled contract is already wired: `SettingsLegalCoordinator`, `SettingsBundledLegalReader`, and `SettingsSourceLegalCatalog`. `api/agreement/get` is absent from `ChinaReviewedRouteCapability`, so `SettingsLegalAgreementPage.agreementGetStaysHidden` stays true and the page does not call it.

`SettingsLegalAgreementPage` in `Core/SettingsIdentityApplications.swift` projects loading, empty, error, and unknown. Unknown counts, blank versions, and blank dates are `—` (U+2014). A loaded document with zero sections stays `0`.

Tests added: `Tests/CoreTests/SettingsLegalAgreementPageTests.swift` and `Tests/ContractChecks/test_pages_agreement_index.py`. Existing legal tests were left in place.

EN and zh-Hans keys plus accessibility identifiers are in `docs/release/ui-strings-pages-agreement-index.json`. `SettingsLegalAgreementFixtureData` is DEBUG-only and uses synthetic labels.

`isReleaseApproved` stays false. Money and merchant-choice switches were not turned on. No legal body, support contact, ICP number, or UGC policy was written. `Localizable.xcstrings` and the Xcode project were not changed. Swift tests were not executed on this machine.
