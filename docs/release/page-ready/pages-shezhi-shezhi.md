# CB276 pages/shezhi/shezhi

PAGE-READY model on rc/20261108. Native screen `App/SettingsView.swift`. Map status stays exists. No route was invented and none was marked live. `SettingsHomePage.routeMarkedLive` is false. Logout stays the existing route and this type does not call it.

`SettingsHomePage` projects the session and market the form already reads. Loading is `SessionFact.loading`. Empty is a nil role (signed out), copy `member.settings.signedOut`. Error is `SessionFact.failed`. UNKNOWN is a role outside player, merchant, and club, or a nil market on a known role. Ready is a known role with CN or US. Identity rows still use `SettingsIdentityApplications.isOffered` only for those three roles. An unknown role does not fall through to that function.

A missing count, a numeric string, a nil market, and an unknown role display as `—` (U+2014). A literal integer 0 stays `0`. `Account` decoding was not changed. The view still shows `effectiveRole` and is not bound to this model.

Legal bodies, the support contact, the ICP filing number, and the UGC policy were not replaced. `[SUPPORT_CONTACT_PLACEHOLDER]`, `[ICP_FILING_PLACEHOLDER]`, and `[UGC_POLICY_PLACEHOLDER]` stay placeholders. `showsMerchantChoice` and the money switches were not set true.

Missing EN+zh-Hans keys:

- `settings.home.loading`
- `settings.home.error`
- `settings.home.unknown`

`settings.title`, `region.market`, and `member.settings.signedOut` already have en and zh-Hans. `SettingsSupportSafetyEntry` still has no catalog key for 客服与安全 / Support and safety, 内容规范 / Content rules, 联系客服 / Contact support, 查看客服联系方式 / Show support contact, or the content-rules clause.

Left: `SettingsView` does not read `SettingsHomePage`. Sign-out, legal, sound, and about stay on their existing types. Support, ICP, and UGC placeholders stay. Strings, the view, the catalog, the Xcode project, and the CI ledger were not changed.

Tests: `SettingsIdentityApplicationsTests` (existing offer test kept) and `Tests/ContractChecks/test_pages_shezhi_shezhi.py`. No Swift run and no Xcode Cloud result.
