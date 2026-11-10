# Entry flow UI test fix (ui/e3)

Decision: all failures are **stale test assumptions**; no view change. Sign-in sheet, consent gate and guest browse are untouched.
Evidence (read, not run): `LoginView` / `AuthChannelView` set no navigation title (inline bar with only a Close button);
`WelcomeView.showsMerchantChoice == false` (player-first launch); launch uses `OnboardingFlow` whose final step is
"Let's go" / "出发吧" with `welcome.player` = "Create account" / "创建账号"; the Publish tab root is
`DiscoveryTemplateBrowserView` titled `discovery.templateTab.title` ("Templates" / "模板").
Branch merges `origin/ui/e1` for the `skipOnboardingIfPresent` helper (not on ui/main).
No build or simulator run was done; verification is by reading only.

| test | verdict | change |
|---|---|---|
| EntryFlowTests.testPlayerAndMerchantEntryCanBeClosedAndRepeated | stale | merchant button is hidden by design, so assert it is absent and repeat the player entry 3x; sheet detected by `auth.otherChannels` instead of nav bar "Sign in"; closed via `closeTopSheet()` |
| EntryFlowTests.testGuestBrowsingCanReturnToIdentityEntry | stale | Publish tab nav title is "Templates" (was "Browse templates"); merchant button asserted absent; sign-in detected by `auth.otherChannels` |
| EntryFlowTests.testUnconfiguredPhoneAndAppleCannotDispatch | stale | "More ways to sign in" nav bar has no title; close the top sheet by its hittable Close button |
| EntryFlowTests.testUnconfiguredBuildHidesUnsupportedPasswordAndKeepsPhoneDisabledAfterInput | stale | same sign-in / channel-sheet title removal; `closeTopSheet()` twice |
| EntryFlowTests.testChinesePreferenceSurvivesRelaunchAndSwitchesBack | stale | `welcome.player` label is now "创建账号" / "Create account" (onboarding final step), not "玩家注册" / "Register as a player" |
| EntryFlowTests.testSettingsReopensAfterRepeatedColdLaunch | stale | already uses the e1 helper (merged); no assertion change needed |
| EntryFlowTests.testSimulatorScannerFallbackCanBeCancelled | n/a | passed before; unchanged |
| RegionalEntryFlowTests (CN/US/US-zh) | stale | welcome headline assertions replaced by onboarding title "出发吧" / "Let's go"; "Sign in" / "More ways to sign in" nav bars replaced by `auth.otherChannels` / `region.auth.pending` |
| EntryUsageConsentFlowTests | stale | "Sign in" nav bar replaced by `auth.otherChannels` |
| WeChatAppAuthFlowTests | ok | identifiers + helper only |
| NonCashRewardFlowTests | ok | identifiers + helper only |

Caveat: `welcome.settings` is a Menu item; tests that tap it directly assume it is exposed without opening `welcome.more`. Not changed; re-check on the next UITest run.

## Follow-up (serial run leftovers)

Read-only fixes, not re-run.

| test | verdict | change |
|---|---|---|
| testUnconfiguredBuild...KeepsPhoneDisabledAfterInput | stale | `auth.channels.code` is a 0.02-opacity, possibly disabled overlay (AuthChannelView codeBoxes): match by identifier on any element type, type only if enabled+hittable; nil value treated as empty |
| testChinesePreferenceSurvivesRelaunchAndSwitchesBack | stale | `welcome.settings` lives in the `welcome.more` Menu: new `revealWelcomeSettings(in:)` opens the menu first |
| testSettingsReopensAfterRepeatedColdLaunch | stale | same helper via `openSettings` |
| RegionalEntryFlowTests | stale | launch waits on `welcome.player`; settings opened via the helper |

Not changed (same Menu assumption, outside this task): SettingsSignedOutProfileRowFlowTests, NativeSettingsReuseFlowTests, RetainedImageUITests.

## Follow-up 2 (language row, code field)

| test | verdict | change |
|---|---|---|
| testChinesePreferenceSurvivesRelaunchAndSwitchesBack | stale | Settings language is a menu Picker row; new `selectLanguage(in:option:)` opens the row then picks the option |
| testChinaDefaultsChineseAndLanguagePersistsWithoutChangingMarket | stale | same helper |
| testUSCanChooseChineseWithoutEnablingDomesticPhone | stale | same helper |
| testUnconfiguredBuild...KeepsPhoneDisabledAfterInput | stale | `codeSection` is only rendered after a code is sent, so the code field never exists unconfigured; typing and the empty-value check are now conditional on existence |
