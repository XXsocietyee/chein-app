# US launch r1 — lane app-us receipt

Branch `us/r1-login-config` from `origin/ui/combined-r7` (fc95e6a19) + `origin/i18n/r1-locale` (9a09a00c9, merged cleanly as a fast-forward; it already had the +86/+1 sign-in picker, `PhoneCountryCode` and locale-aware money/units — this lane builds on that, it doesn't duplicate it). Brief: `docs/briefs/us-launch-r1.md` (lane app-us) on `origin/design/handoff-r2`.

No compiler in the cloud: every API was checked with grep. The Swift is not compiled; the coordinator's `build_sim` is the first build.

## 1. `Config/UnitedStates.Production.xcconfig`

- `QUESTIFY_API_BASE_URL = https:/$()/www.chengyinhub.com/prod-api/` (same host as China).
- `QUESTIFY_SESSION_REALM = cn-prod`. **Why I reused the China realm:** the backend (`XXsocietyee/hengyin` `origin/main` 6553fe07) has no market split. I found no market, region or country field on members, orders, tokens or the login/SMS services; the only `region` field is `AiVoiceConfig`. The same phone number is the same account, and a token from either storefront is valid for the same backend. The realm only names the local session namespace (keychain/defaults). A separate `us-prod` would make one account look like two local sessions on the same backend without isolating anything server-side. If the backend adds a market split later, change the realm to `us-prod`; `Local.UnitedStates.Production.xcconfig` can already override it.
- US Staging and the market-only `UnitedStates.xcconfig` stay empty (fail closed).
- Composition: `ReviewedMarketLaunch.admitsShippedUnitedStates` (Core/RegionalConfiguration.swift) admits a US build only on the reviewed host with a usable bundle and realm. `RegionalLaunchConfiguration.shippedComposition` then composes the **same backend deployment** as China: backend market CN, the same reads, `.activityAndTopic` detail reads, `productionGatesEnabled` and `playerWritesEnabled`. All 322 backend route gates (`market == .china`) keep working unchanged, with no per-gate US fork. `approvedBaseURLs` still has no US key.
- `RegionalLaunchConfiguration.storefrontMarket` (Info.plist `QuestifyMarket` = US) drives presentation only: the phone country default, the Settings market label, and the language default (already from `RegionalLaunchConfiguration.market`).

## 2. Phone entry: +1 / +86, E.164, US formatting

| Entry | File | Change |
|---|---|---|
| Login (SMS send + sign-in) | `App/AuthChannelView.swift`, `App/AuthChannelModel.swift` | i18n picker kept; default now `PhoneCountryCode.launchDefault` (`Locale.current.region` US/CN → that country, else the storefront market). The field shows `(555) 123-4567` while typing; the wire value comes from the sanitized digits: China bare 11 digits (byte-identical), US `+1XXXXXXXXXX`. Sign in with Apple untouched. |
| Register (activity sign-up) | `App/RegistrationSheetView.swift`, `Core/RegistrationUIForm.swift` | `PhoneCountryField` (new, `App/PhoneCountryField.swift`). The draft stores the wire value. Validation accepts the China rule as before, or a complete `+1` NANP number. |
| Profile (participants) | `App/ParticipantFormView.swift`, `Core/ParticipantForm.swift` | Same field and validation. A stored masked China value is shown as it came and never rebuilt. |
| Bind phone | `Core/MPGap/AccountPublish/AccountPublishGapRemaining.swift` | **No native bind form exists.** `bindPhone` throws `notConfigured` (OWN-D-09: the MP bind uses a WeChat phone code, and an SMS bind is a different route), and `ProfileEditGapPhoneBindRow` is not mounted. Nothing to change until an SMS bind route is specified. |

Helpers (Core/LocaleDisplay.swift `PhoneCountryCode`): `default(region:marketCode:)`, `fieldText`, `draftWire`, `split(wire:)`, `isValidUnitedStatesWire`. Unit tests: `LocaleDisplayTests.testUSLaunchPhoneEntryHelpers`, `ReviewedChinaLaunchTests.testShippedUnitedStatesAdmissionSharesOnlyTheReviewedHost`, `ReviewedChinaLaunchCompositionTests.testShippedUnitedStatesBuildSharesTheReviewedBackend`.

Not changed (outside the brief's four entries): `TopicSelfPlaySheet`, `TopicDetailView` contact phone, `JourneySeatTransferSheet`, `BundleTransferSendView`, merchant onboarding, bank withdrawal.

## 3. US market composition

- Player features: on. The US build gets exactly the China player deployment (see §1).
- Merchant: off. `PlayerLaunch.merchantCenterEnabled` is `false` in every Release build, both storefronts (the contract `test_player_release_gate` pins it as a `static let`, so I didn't make it market-computed). Under DEBUG/TEST it stays on for fixtures.
- Currency and units come from the locale through `i18n/r1-locale` (`LocaleDisplay`, miles/km). Money stays behind the Release money switch (`ReviewedAreaSwitch`), unchanged.

## Blockers / owner & coordinator actions

1. **Backend, outside lane be-us scope:** `POST api/user/address/action` (participant save, `ApiUmsMemberController.java:843`) rejects anything but `^1[3-9]\d{9}$`, so a `+1` participant phone fails server-side. Check the registration create's phone validation too. be-us covers only the SMS send/login/register/bind endpoints. Until the backend accepts E.164 there, US participant and registration saves with a +1 number will fail.
2. **SMS +1** depends on be-us (E.164 on `SmsVerificationService`, which today is `^1\d{10}$`, plus Aliyun international SMS). Until that deploys, `+1` send/login returns the backend's invalid-phone error. China is unaffected.
3. **Release identity:** `Config/Release.xcconfig` (checked by `tools/check_release_config.py`) pins `QUESTIFY_MARKET = CN`, bundle `com.chengyinhub.chengyinApp`, realm `cn-prod`. A US App Store build needs the owner to decide between a separate US scheme/Release config (US bundle id, `QUESTIFY_MARKET = US`) and shipping one binary to both storefronts. If it's one binary, the storefront has to come from the App Store storefront or region at runtime rather than from the build. I did not change it.
4. **Legal / consent:** the US build reads legal documents and the usage-consent gate through the shared backend deployment (backend market CN). US-specific agreement and privacy texts must be served by the backend or selected by `storefrontMarket` in a follow-up.

## Config keys the owner/coordinator must set

| Key | Where | Value |
|---|---|---|
| `QUESTIFY_API_BASE_URL` | `Config/UnitedStates.Production.xcconfig` (tracked) | set: `https://www.chengyinhub.com/prod-api/` |
| `QUESTIFY_SESSION_REALM` | same (tracked); override in gitignored `Config/Local.UnitedStates.Production.xcconfig` | set: `cn-prod` (change to `us-prod` only if the backend splits markets) |
| `PRODUCT_BUNDLE_IDENTIFIER`, `DEVELOPMENT_TEAM` | US release config (owner decision, item 3) | not set by this lane |
| backend `sms.intl.signName`, `sms.intl.templateCode` | hengyin server config (lane be-us) | owner |

No secrets in git.

## Gates

- `python3 tools/check_scaffold.py`: PASS structural checks (5232 Swift files).
- `python3 tools/check_a11y_lint.py`: PASS, 0 new.
- `python3 tools/contract_ratchet.py --check`: 104 failing, baseline 104, **new 0**, fixed 0.
- `python3 tools/check_l2_environment_configs.py`: 15 tests OK (updated for the US production profile).
- Contract checks touched: `test_pages_shezhi_shezhi`, `test_native_presentation_reuse`, `test_pages_activity_baoming_baoming`, `test_profile_participant_validation`, `test_sign_in_with_apple_flow`: OK. `test_profile_reload_discard` fails at base `origin/i18n/r1-locale` too (2 hash pins), so it isn't from this lane.
