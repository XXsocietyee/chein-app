# US launch r1 — lane one-app receipt (2026-11-27)

Branch `us/r1-one-app` from `origin/ui/combined-r7`. `origin/us/r1-login-config` and `origin/us/r1-pay` were already merged into combined-r7 (nothing left to merge). Re-merged `origin/ui/combined-r7` at `a3e45ed73` (clean). Brief: `docs/briefs/us-launch-r1.md` on `origin/design/handoff-r2`; traps from `docs/briefs/COORDINATOR-HANDOVER.md` §4.

Owner decisions 2026-11-27:
1. **One App Store app** for China and the US (bundle `com.chengyinhub.chengyinApp`), not a separate US build.
2. The English brand name is **Chein**. Chinese stays 城瘾.

No compiler in the cloud. Every API was checked with grep. **Not built and not run.** The coordinator's `build_sim` is the first build.

## (a) Language follows the phone

| File | Change |
|---|---|
| `Core/AppPreferences.swift` | `AppLanguage.deviceDefault(preferredLanguages:)`: the first `Locale.preferredLanguages` entry `zh*` → `.simplifiedChinese`, anything else (or none) → `.english`. `AppLanguagePreference.language`: a stored choice wins (System included); with no stored choice → `deviceDefault`. The derived default is **never written**, so it keeps following the phone. |
| `Core/RegionalConfiguration.swift` | `RegionalMarket.language(storedValue:preferredLanguages:)`: no stored value → `deviceDefault`, for both markets. `defaultLanguage` is kept, but it is no longer the first-launch default. |
| `App/RegionalLaunchConfiguration.swift` | `language(nil)` → `AppLanguage.deviceDefault()`, so `@AppStorage` defaults in `QuestifyApp`, `SettingsView`, `LanguageSwitcher` and `IslandWindow` all follow the phone. The in-app switch is unchanged (key `preferences.language`). |

Tests updated in this commit: `AppLanguageSwitchTests.testFirstLaunchFollowsThePhoneAndExplicitChoiceSurvives` (replaces the per-market default test), `RegionalConfigurationTests.testFirstLaunchDefaultsAndExistingChoices`, `LanguageSwitcherTests`.

Behaviour change to note: a China user with an English phone who never touched the switch now sees English (before: Chinese). That's the requested behaviour.

## (b) Market at runtime

| File | Change |
|---|---|
| `Core/UserMarket.swift` (new) | `UserMarketResolver.resolve(accountRegion:signInPhone:deviceRegion:buildDefault:)`. The first match wins: (1) account region `CN/CHN/US/USA`; (2) sign-in phone `+86…` or the bare China 11 digits → CN, `+1…` → US; (3) device region `CN`/`US`; (4) the build market (`QUESTIFY_MARKET`), else China. |
| `App/UserMarketMemory.swift` (new) | Device-local hints in UserDefaults: `preferences.userMarket.accountRegion` and `preferences.userMarket.signInDialCode` (`+86`/`+1`). No phone number, token or account id is stored. Each sign-in drops the previous account region. A phone sign-in stores its dial code, and an Apple sign-in clears it. Catalogued in `docs/ops-safety/client-data-catalog.json`. |
| `App/AuthChannelModel.swift`, `App/AuthChannelView.swift` | The model remembers the country of the last phone sign-in attempt (`signInCountry`; Apple attempt → nil). The view records it on `state.signedIn`, in the existing `onChange`. The model itself still writes no defaults. |
| `Core/MemberHome.swift`, `App/MemberIdentityCardReadOwner.swift` | `MemberIdentitySnapshot.accountRegion` decodes `region` or `countryCode` from `/api/user/info` when present (lenient; nil today, because the backend has no such field, per the app-us receipt). When it's recognizable, `publish` records it. |
| `App/RegionalLaunchConfiguration.swift` | `storefrontMarket` is now the per-user market: `UserMarketMemory.resolve(buildDefault: market)`. DEBUG `--uitesting-market` still pins the build value for UI tests. `market` (Info.plist `QuestifyMarket`) stays the build default/fallback. The backend deployment is unchanged: one reviewed host, deployment market CN for both, the same realm `cn-prod`. |
| `App/StripePayBridge.swift` | Apple Pay / Stripe now key off `storefrontMarket == .unitedStates`. **Bug fix:** the US build composes the shared deployment with market CN, so the old `session.regionalConfiguration?.market == .unitedStates` gate could never open. A CN user still gets `nil` here, so WeChat Pay / Alipay stays byte-identical. |
| `App/PhoneCountryField.swift` | `PhoneCountryCode.launchDefault` = default of the per-user market (CN → +86, US → +1). The resolver already includes the device region, after the account and sign-in hints. |

Same backend host for both markets (`https://www.chengyinhub.com/prod-api/`), unchanged.

Tests: `Tests/CoreTests/UserMarketResolverTests.swift` (order, phone/region mapping, user-info decode) and `Tests/AppUnitTests/UserMarketMemoryTests.swift` (hint recording/clearing; the language key is never touched).

### Release checks (one market per build → one app, both markets)

- `tools/check_release_preflight.py`: the docstring cites the decision. `QUESTIFY_MARKET = CN` is now documented as the **fallback** market. The new `check_one_app_runtime_market` fails when:
  - any tracked `Config/*.xcconfig` (except Base/AppUnitTests/Local*) names a second App Store bundle ID;
  - `storefrontMarket` stops resolving at runtime;
  - the resolver order changes;
  - the Stripe gate goes back to the deployment market.
- `tools/tests/test_release_prep.py`: the isolated-copy test now copies the three inputs, plus negative cases for a second bundle ID and for a build-keyed Stripe gate.
- `tools/check_release_config.py`: comment on `QUESTIFY_MARKET: 'CN'` (fallback, owner 2026-11-27). Values unchanged.
- `Config/UnitedStates*.xcconfig` stay as development/test profiles. They're no longer an App Store path. This resolves item 3 ("Release identity") of `us-r1-app-us.md`.

## (c) Brand: Chein

- **Catalogs:** 62 English values across `Resources/*.xcstrings` and `LiveActivityWidget/Localizable.xcstrings` (widget `Open a Chein page`). Rules: `Chengyin`/`Chengyin Hub`/`CHENGYIN`/`Questify`/lower-case `chein` as the app name → `Chein`. Mini-program references → `Chein (城瘾) mini program`, so users can still find it in WeChat. zh-Hans is untouched. The 12 catalogs that don't round-trip through `json.dumps` had no brand hits.
- **Sources kept in sync:** the `Resources/*.fragment.json` and `docs/**/…localizations.json` / `docs/port/strings/*.json` / `docs/release/ui-strings-*.json` fragments; the generators `tools/build_auth_entry_catalog.py`, `tools/add_mp_drift_localizations.py` and `tools/backend_error_catalog.py` (re-run with `--write`: Swift + catalog + `docs/release/cb50-errors.md`).
- **Home-screen name:** `Resources/InfoPlist.xcstrings` gains `CFBundleDisplayName` / `CFBundleName` (en Chein, zh-Hans 城瘾). The fallback `INFOPLIST_KEY_CFBundleDisplayName = Chein` is set in `Config/Base.xcconfig` and `tools/generate_project.py`, and the project is regenerated. Before this change the home-screen name was `Questify` in every language.
- **Permission prompts:** none of the InfoPlist usage strings named the app. The in-app notification primer (`CYPermissionPrimer`) now says Chein.
- **Swift literals:**
  - `ObjectBadgeViews` share text;
  - `RegistrationStripePaySection` Apple Pay label `c.t("城瘾", "Chein")`. This also fixes the zh typo `澄音`;
  - player fallbacks in `SquareCloudComposerView` and `OfficialEventContracts`;
  - `ExternalGameImport` author `Chein Workshop`;
  - `BackendErrorCatalog`;
  - a DEBUG preview in `SettingsAboutView`.
- **App Store drafts / support docs (docs/release):** `app-store-pack.md` (name en-US Chein, description, review notes), `cb42-app-store-copy.md`, `app-store-metadata-checklist.md`, `support-playbook(.zh-Hans).md`, `community-guidelines(.zh-Hans).md`. The zh docs say 城瘾.
- **Not renamed:**
  - the legal company name "Shanghai Chengyin Technology Co., Ltd." (no catalog hit carried it);
  - code identifiers (`Questify` targets/scheme/xcodeproj, `QuestifyApp.swift`, `questify.mod`/`questify.h5` package formats, `chein://` scheme, `X-Chengyin-*` / `X-Questify-*` headers, Keychain/file names);
  - build artifact names in `TESTFLIGHT.md`;
  - Swift comments;
  - historical receipts.
- **Pinned contract test updated in the same commit:** `test_object_badge_wall_layout` (detail hash, with a provenance comment). `BackendErrorCatalogTests` and `ExternalGameImportTests` were also updated.

## Gates (merged tree, after re-merging combined-r7 `a3e45ed73`)

- `python3 tools/check_scaffold.py` → PASS structural checks (5250 Swift files, 19894 bilingual keys)
- `python3 tools/check_a11y_lint.py` → PASS, 0 new
- `python3 tools/contract_ratchet.py --check` → 104 failing, baseline 104, **new 0**
- `python3 tools/check_release_preflight.py` → PASS (now includes the one-app check); `python3 tools/check_release_config.py` → passed; `python3 -m unittest tools.tests.test_release_prep` → OK
- `tools/archive_unsigned.py` → the same 6 FAILs as before this lane (US-profile, UIBackgroundModes, entitlement set, account-deletion), none new.

## Owner / coordinator actions

| What | Where |
|---|---|
| Rename the App Store Connect app record (today "Questify" in `TESTFLIGHT.md`): name en-US **Chein**, zh-Hans **城瘾**; enable the US storefront on the same app | App Store Connect |
| Account region: if the backend adds `region` / `countryCode` to `/api/user/info`, the app picks it up with no client change. Values `CN`/`US` (or `CHN`/`USA`) | hengyin (optional) |
| `+1` SMS and USD quotes with `APPLE_PAY`/`APP_STRIPE` still depend on lane be-us. Until it deploys, a US user sees the China pay button for CNY quotes, and `+1` SMS returns the backend's invalid-phone error | hengyin `us/r1-backend` |
| US legal texts (privacy, terms) are still served by the shared deployment (`us-r1-app-us.md` item 4) | owner / backend |
| Apple Pay merchant `merchant.com.chengyinhub.chengyinApp` + Stripe processing cert (`us-r1-app-pay.md`) | Apple Developer / Stripe |
| Review notes still say "mainland China phone number". Add `+1` once be-us is live | `docs/release/app-store-pack.md` §5 |

## Compile risks to watch on the first `build_sim`

- `RegionalMarket.language(storedValue:preferredLanguages:)` and `AppLanguagePreference(defaults:market:preferredLanguages:)` gained defaulted parameters. Every existing call site keeps the old labels.
- `MemberIdentitySnapshot` gained a stored `let accountRegion` (assigned at the end of `init(from:)`). It has no memberwise init anywhere.
- `UserMarketMemory` is a plain (non-actor) enum in Swift 5 mode, called from `@MainActor` and nonisolated code.

No secrets in git.
