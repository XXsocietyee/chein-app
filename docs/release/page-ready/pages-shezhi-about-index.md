# CB277 pages/shezhi/about/index

PAGE-READY for 关于城瘾与版本信息. Native screen `App/SettingsAboutView.swift`. Map status stays exists. No route was added and none was marked live. `Config/Base.xcconfig` stays `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1`. Questify type names were not renamed.

Already on rc: `SettingsAppInformation` reads the bundle display name, short version, and build. Blank and unresolved `$(...)` stay nil. `SettingsPlayerCode` decodes only an HTTPS `data.qr` with no credentials and no fragment. `SettingsSourceContact.phone` is the CN number and nil for US or a missing market. `SettingsLegalCoordinator` already has loading and failed for the legal document, which this page only links to. Views, string catalogs, the Xcode project, and `tools/current_ci_manifest.json` were not edited.

Added in `Core/SettingsIdentityApplications.swift`: `SettingsAboutPageModel` projects that existing contract. Version, build, and name use `SettingsAboutMetadataPhase` (`loading`, `empty`, `error`, `unknown`, `ready`). Unknown text is an em dash (`—`, U+2014), never `0`, `0.1.0`, `1`, or `开发版本`. A bundle string `0` stays `0`. `SettingsAboutPlayerCodePhase` uses the same five cases. With no reader installed, production is `error` and `imageURL` is nil. `routeInstalled` and `routeMarkedLive` stay false. `showsMerchantChoice`, `paymentEnabled`, `payoutEnabled`, `withdrawalEnabled`, and `virtualGoodsEnabled` stay false.

Tests added in `Tests/CoreTests/SettingsNativeTests.swift`: `testAboutPageKeepsSuppliedVersionAndBuildAndLeavesPlayerCodeInError`, `testAboutPageUnknownMetadataIsAnEmDashAndALiteralZeroStaysZero`, `testAboutPlayerCodePhasesDoNotInventAnImage`. Existing player-code, bundle, and contact assertions were not changed. Swift was not run. `xcodebuild` was not run.

## Missing EN+zh-Hans keys

These source strings have no key in `Resources/Localizable.xcstrings`. This lane did not add them.

- `身份码开通后会自动出现` — retry toast on the pending player code (`explainQrPending`).
- `查看服务条款` — description on the user-agreement row.
- `版本、协议、联系与我的二维码` — description on the settings entry that opens this page.

Keys that already exist and were not edited: `settingsNative.about.title`, `tagline`, `version`, `build`, `playerCode`, `playerCodeHint`, `playerCodeUnavailable`, `nameMissing`, `metadataMissing`, `contact`, `contactSource`, `contactUnavailable`, `copyPhone`, plus `settingsNative.legal.user_agreement`, `settingsNative.legal.privacy_policy`, `region.market`, `localCopy.copied`, and `localCopy.failed`.

## Left

`App/SettingsAboutView.swift` still draws the empty player-code block itself and does not read `SettingsAboutPageModel`. `settingsNative.about.playerCodeHint`, `contactSource`, and `contactUnavailable` are catalogued and not rendered. Catalog zh-Hans for `settingsNative.about.playerCodeUnavailable` is `个人二维码还未生成`; the source sentence is `玩家个人码待生成`. Catalog `contactUnavailable` is an em dash in both languages. The player-code POST stays uninstalled.
