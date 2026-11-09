# Developer guide: onboarding, build, and release

Checked against `origin/rc/20261108` at `88e981b3308558939e405606cd731b4b29fc9499`. This page records what is in the tree. It does not add a signing identity, a certificate, a provisioning profile, or a workflow file.

Marketing version stays **0.1.0**. Build number stays **1**. Both values are `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig`. This guide does not change them.

**A Release build was not run.** This workspace has no Xcode. Nothing in this change invoked `xcodebuild`, `tools/archive_unsigned.py --archive`, or a store upload.

## What this checkout is

Questify is a SwiftUI iOS app in `Questify.xcodeproj`, plus a pure-domain Swift package (`Package.swift`, library `QuestifyCore`). The README is the product overview. This guide is the path from a fresh checkout to a local Debug build, a design fixture, and the release boundary that is already written down.

| Piece | Path |
|---|---|
| App, design system, DEBUG fixtures | `App/`, `App/DesignSystem/`, `App/DesignFixtures/` |
| Domain | `Core/` |
| Tests | `Tests/CoreTests`, `Tests/AppUnitTests`, `Tests/AppUITests`, `Tests/ContractChecks` |
| Build settings | `Config/Base.xcconfig` (app and UI-test base). `Config/AppUnitTests.xcconfig` (app-unit base) |
| Shared schemes | `Questify.xcodeproj/xcshareddata/xcschemes/Questify.xcscheme`, `QuestifyAppUnitTests.xcscheme` |
| Version and bundle id | `Config/Base.xcconfig` |

`tools/generate_project.py` writes the Xcode project. The app target's Debug and Release configurations both use `Config/Base.xcconfig`. `Config/China.Production.xcconfig` is a profile file. It is not the target base configuration. The generator sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS` to `DEBUG $(inherited)` on the Debug app configuration and on the Debug app-unit configuration. The Release app configuration does not add `DEBUG`.

Deployment target in `Config/Base.xcconfig` is iOS 17.0. `Package.swift` asks for iOS 17 and macOS 14. The README says the CI Apple toolchain recorded for current runs is GitHub-hosted macOS 26 / Xcode 26.6, and that older Xcode is not assumed to be compatible.

## Onboarding

1. Clone `liboyang42-cpu/chengyin-app` and start from `rc/20261108` (this guide's base is the SHA above).
2. Open `Questify.xcodeproj`. The shared `Questify` scheme launches and tests with configuration **Debug**. Its archive action names configuration **Release**. The shared scheme commits no launch arguments (`xcuserdata/` is gitignored).
3. Leave signing on the committed defaults. `CODE_SIGN_STYLE = Automatic`. No committed xcconfig sets `DEVELOPMENT_TEAM` or `CODE_SIGN_IDENTITY`. The committed bundle id is `invalid.example.questify.ios`. App-unit and UI-test ids are `invalid.example.questify.ios.appunittests` and `invalid.example.questify.ios.uitests`. GLTFKit2's own project uses `com.metalbyexample.gltfkit2` and an empty `DEVELOPMENT_TEAM`.
4. Local overrides, when an owner has them, go in gitignored `Config/Local.xcconfig` or `Config/Local.*.xcconfig`, copied from the commented placeholders in `Config/Local.xcconfig.example`. Do not commit that file. `.gitignore` also ignores `*.p12`, `*.p8`, and `*.mobileprovision`.
5. `QUESTIFY_API_BASE_URL` and `QUESTIFY_SESSION_REALM` are empty in `Config/Base.xcconfig`. `QUESTIFY_MARKET` is `CN`. `QUESTIFY_DEPLOYMENT_ENVIRONMENT` is `unconfigured`. Login stays unavailable on that empty base. See the README.

Python checks that do not compile Swift, from the README:

```sh
python3 tools/generate_project.py
python3 tools/check_scaffold.py
```

`generate_project.py` rewrites `Questify.xcodeproj`. Run it only when you intend to regenerate the project. This guide did not run it.

## Build

The Debug-shaped unsigned simulator command recorded in the README is:

```sh
xcodebuild -project Questify.xcodeproj -scheme Questify \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
swift test
```

That command does not pass `-configuration Release`. The shared scheme's launch action is Debug, so this is the local build a developer runs before any archive. `swift test` is the Swift package domain suite (`QuestifyCoreTests`). It needs a Mac toolchain. This workspace did not run either command.

The same README line is the one to use on a Mac. Pass `CODE_SIGNING_ALLOWED=NO` until an owner has put a team in the gitignored local xcconfig. The committed tree has no distribution certificate and no provisioning profile.

`QuestifyAppUnitTests` is the app-hosted XCTest scheme. Its test action is Debug. UI tests are the `QuestifyUITests` target on the `Questify` scheme, also Debug.

Release configuration exists as an Xcode configuration name. The app target's Release settings turn optimization to `-O`, emit dSYM, and exclude `AppStoreReviewDemoAccountAndFixtureSectionView.swift` from the app target (`tools/generate_project.py`). That exclusion is a project-generation fact. It is not a Release compile result from this workspace.

## Design workflow

Design work already in the tree is a spec, a DEBUG fixture, kit components, and a report. Player domain is dark. Merchant domain is light. Components read `@Environment(\.cyPalette)` and the screen sets the domain once with `.themeDomain(.player)` or `.themeDomain(.merchant)` (`docs/release/design-report-K.md`).

| Pass | Spec | Report | Fixture source |
|---|---|---|---|
| Kit | report only | `docs/release/design-report-K.md` | `App/DesignFixtures/KitGalleryFixture.swift` |
| D1 welcome, consent, login | `docs/release/design-spec-d1.md` | `docs/release/design-report-d1.md` | `App/DesignFixtures/OnboardingFixtures.swift` |
| D2 home, search, square, roam | `docs/release/design-spec-d2.md` | `docs/release/design-report-d2.md` and `docs/release/design-report-d2-shots/` | `App/DesignFixtures/D2Fixtures.swift` |
| D3 orders, tickets, wallet, coupons | `docs/release/design-spec-d3.md` | `docs/release/design-report-d3.md` | `App/DesignFixtures/OrdersWalletFixtures.swift` |
| D4 clubs, channels, me | `docs/release/design-spec-d4.md` | `docs/release/design-report-d4.md` | `App/DesignFixtures/D4Fixtures.swift` |

The loop those reports follow:

1. Read the spec. Keep existing identifiers. New visible copy is English and zh-Hans.
2. Build the screen from `App/DesignSystem` (`CYHeroHeader`, `CYPillButton`, `CYSectionHeader`, `CYListRow`, `CYImageCard`, `CYStatusChip`, `CYEmptyState`, `CYErrorState`, `CYSkeleton`, and the token files). The kit report says violet is not used by kit components.
3. Host the real view in `App/DesignFixtures/` with synthetic, labelled data, inside `#if DEBUG`.
4. Add one `case` in `DesignFixtureRegistry.make` (`App/DesignFixtures/DesignFixtureRegistry.swift`).
5. Launch a **Debug** build with `--design-fixture <name>` (see below). The shared scheme does not store that argument.
6. Write the result in `docs/release/design-report-*.md`. Extra strings for a pass live in `docs/release/ui-strings-*.json`. Several reports say those JSON keys are not yet merged into `Resources/*.xcstrings`.

`docs/release/design-report-K.md` cites `design-run.sh k <worktree> --design-fixture <name>`. `docs/release/design-report-d4.md` cites `design-run.sh`. That script is not a file in this checkout. The launch path that is in the tree is the `--design-fixture` argument below.

### Names the registry returns

`QuestifyApp` checks `--design-fixture` first, and only inside `#if DEBUG`. `fixtureArgument` takes the next token when that token does not start with `--`. `DesignFixtureRegistry.make` returns a view for these names:

| Name | View |
|---|---|
| `kit`, `kit-2` | `KitGalleryFixture` player (dark). `kit-2` is the lower half |
| `kit-merchant`, `kit-merchant-2` | same gallery, merchant (light) |
| `d4-directory`, `d4-detail`, `d4-owner-detail` | `D4ClubFixture` |
| `d4-channels`, `d4-channel-chat`, `d4-confirm` | `D4ClubFixture` |
| `d4-settings`, `d4-growth`, `d4-leaderboard`, `d4-badges` | `D4MeFixture` |

Any other name hits the `default` arm and shows the text `Unknown design fixture: <name>`.

The D1, D2, and D3 fixture types are in the tree, and the design reports name them, and they are not cases in `DesignFixtureRegistry.make` on this commit:

| Report name | Declared in | Registry on this commit |
|---|---|---|
| `welcome`, `welcome-menu`, `consent`, `login-player` | `OnboardingFixtures.swift` and `design-report-d1.md` | no `case` |
| `d2-home`, `d2-search`, `d2-square`, `d2-roam` | `D2Fixtures.swift` and `design-report-d2.md` | no `case` |
| `orders-list`, `orders-empty`, `order-detail`, `order-detail-bottom`, `order-detail-full`, `ticket-list`, `ticket-detail`, `coupons`, `wallet` | `OrdersWalletFixtures.make` and `design-report-d3.md` | `make` is not called from the registry |

`D4Fixtures.swift`'s comment lists `d4-directory`, `d4-detail`, `d4-owner-detail`, `d4-channels`, `d4-settings`, `d4-growth`, `d4-leaderboard`, and `d4-badges`. The registry also returns `d4-channel-chat` and `d4-confirm`.

## DEBUG fixture launch arguments

Every branch below is inside `#if DEBUG` in `App/QuestifyApp.swift` unless the row says otherwise. A Release compile does not set `DEBUG`, so these branches are not in a Release binary. That is a source fact. A Release build was not run, so it was not observed in a built product.

The first matching branch wins. `--design-fixture` is first. Later flags do not run when an earlier flag matches.

Passing any extra argument on a DEBUG launch treats usage consent as already granted in memory, except `--uitesting-usage-consent-pending`, which keeps the real gate on isolated storage (`UsageConsentEnvironment` in `App/UsageConsentGateView.swift`). A plain launch with no extra arguments uses UserDefaults. Maestro smoke flows rely on that and are described in `docs/release/smoke-flows.md`. Those flows pass no launch arguments. They were not executed for this guide.

Add arguments on a local Run action, or set `XCUIApplication.launchArguments` from a UI test. Do not commit them into the shared scheme.

### Arguments read before the root switch

| Argument | Effect |
|---|---|
| `--uitesting-reset-language` | Sets `preferences.language` to the system value in `UserDefaults` |
| `--uitesting-first-launch-language` | Removes `preferences.language` |
| `--uitesting-usage-consent-pending` | Consent gate stays pending (`App/UsageConsentGateView.swift`) |
| `--uitesting-dark`, `--uitesting-light` | Fixture theme modifier leaves appearance alone. Otherwise a fixture root with `merchant` anywhere in the argument string uses the merchant domain, and any other fixture root uses the player domain |

### Root switch, in order

The value column is the following token from `fixtureArgument`, unless the row says otherwise. When the value is omitted, the default in the source is used.

| # | Argument | Host |
|---|---|---|
| 1 | `--design-fixture <name>` | `DesignFixtureRegistry.make` |
| 2 | `--owner-draft-fixture [mode]` | `OwnerDraftFixtureHost`, default `ready` |
| 3 | `--ops-safety-fixture [scenario]` | `OpsSafetyFixtureHost`, default `theme` |
| 4 | `--group-poll-fixture [scenario]` | `GroupPollFixtureRoot`, default `success` |
| 5 | `--native-navigation-fixture [mode]` | `NativeNavigationFixtureView`, default `error` |
| 6 | `--native-verification-fixture [scenario]` | `NativeVerificationFixtureView`, default `success` |
| 7 | `--merchant-npc-fixture` | `MerchantNPCFixtureView` |
| 8 | `--merchant-ai-commerce-fixture` | `MerchantAICommerceFixtureHost` |
| 9 | `--publisher-lifecycle-fixture` | `PublisherLifecycleFixtureRoot` |
| 10 | `--retained-images-fixture [mode]` | `RetainedImageFixtureView`, default `success` |
| 11 | `--square-governance-fixture` | `SquareGovernanceFixtureHost` |
| 12 | `--shop-npc-fixture <value>` | `ShopNPCFixtureView`. Enabled only when the value is `enabled` |
| 13 | `--club-community-fixture` | `ClubCommunityFixtureRoot` |
| 14 | `--public-merchant-home-fixture [scenario]` | `PublicMerchantHomeFixtureView`, default `profile` |
| 15 | `--door-referral-fixture` | `DoorReferralFixtureView` |
| 16 | `--merchant-marketing-fixture [surface]` | `MerchantMarketingFixtureHost`. Scenario token is `--merchant-marketing-scenario`, default `normal`. Surface default is `dashboard` |
| 17 | `--im-expanded-fixture` | `IMExpandedFixtureRoot`. The scenario is the **last** process argument, default `dormant` |
| 18 | `--ui-coupon-management` | `CouponManagementFixtureHost` |
| 19 | `--wallet-commerce-fixture` | `WalletCommerceFixtureHost` |
| 20 | `--ui-publishing-modes` | `PublishingModesFixtureHost` |
| 21 | `--nearby-team-fixture` | `NearbyTeamFixtureRoot` |
| 22 | `--official-action-fixture` | `OfficialActionFixtureHost` |
| 23 | `--second-registration-fixture [scenario]` | `SecondRegistrationFixtureHost`, default `mature` |
| 24 | `--uitesting-merchant-engagement-fixture` | `MerchantEngagementFixtureHostView` |
| 25 | `--uitesting-merchant-business-fixture` | `MerchantBusinessFixtureHostView` |
| 26 | `--merchant-city-template-handoff-fixture` | `MerchantCityTemplateHandoffFixtureHost` |
| 27 | `--uitesting-merchant-content-fixture` | `MerchantContentFixtureScenarioView` |
| 28 | `--cooperation-flow-fixture` | `CoopFlowFixtureHost` |
| 29 | `--uitesting-club-governance` | `ClubGovernanceFixtureHost` |
| 30 | `--ui-template-authoring` | `TemplateAuthoringFixtureHostView` |
| 31 | `--uitesting-order-lifecycle-fixture` | `OrderLifecycleFixtureHostView` |
| 32 | `--roam-subpage-fixture` | `RoamSubpageFixtureHost` |
| 33 | `--uitesting-roam-experience` | `RoamExperienceFixtureHostView` |
| 34 | `--uitesting-roam-home` | `RoamHomeFixtureHostView` |
| 35 | `--uitesting-activity-fixture <raw>` | `ActivityFixtureRootView`. Raw values in `App/ActivityFixtureSupport.swift`: `tickets`, `people`, `reviews`, `reviews-empty`, `reviews-unknown`, `club-gate`, `retry`, `pagination`, `meta` |
| 36 | `--uitesting-merchant-fixture <raw>` | `MerchantFixtureRootView`. Raw values in `App/MerchantFixtureSupport.swift`: `owner`, `finance`, `inactive`, `retry`, `empty`, `projectBrowser` |
| 37 | `--uitesting-merchant-operations-fixture` | `MerchantOperationsFixtureHostView` |
| 38 | `--uitesting-merchant-onboarding-fixture <name>` | `MerchantOnboardingFixtureRoot` |
| 39 | `--uitesting-club-fixture <raw>` | `ClubFixtureRootView`. Raw values are the `ClubFixtureScenario` cases in `App/ClubFixtureSupport.swift` |
| 40 | `--uitesting-club-operations <raw>` | `ClubOperationsFixtureHostView`. Raw values are the `ClubOperationsFixtureScenario` cases in `Core/ClubOperationsSyntheticFixtures.swift`: `owner`, `admin`, `ordinary`, `limit`, `unknown`, `denied`, `delayed`, `changed`, `readbackUnavailable`, `missingSettings`, `unverified`. Optional extra flag `--uitesting-club-operations-host-apply` |
| 41 | `--uitesting-club-management-fixture <raw>` | `ClubManagementFixtureRootView`. Raw values are the cases in `App/ClubManagementFixtureSupport.swift` |
| 42 | `--uitesting-profile-invite-reward-review` | `ProfileInviteRewardReviewFixtureHost`. Scenario `--profile-invite-reward-review-scenario`, default `complete` |
| 43 | `--uitesting-profile-participation-schedule` | `ProfileParticipationScheduleFixtureHost`. Scenario `--profile-participation-schedule-scenario`, default `near` |
| 44 | `--uitesting-profile-order-filters` | `ProfileOrderFilterFixtureHost`. `--profile-order-filters-empty` selects the empty host |
| 45 | `--uitesting-profile-self-orders` | `ProfileSelfOrdersFixtureHost`. Scenario `--profile-self-orders-scenario`, default `content` |
| 46 | `--uitesting-profile-complaint` | `ProfileComplaintPreparationFixtureView`. Scenario `--profile-complaint-scenario`, default `content` |
| 47 | `--uitesting-profile-local-cover` | `ProfileLocalCoverFixtureHost` |
| 48 | `--uitesting-profile-favorite-removal` | `ProfileFavoriteRemovalFixtureHost`. Scenario `--profile-favorite-removal-scenario`, default `content` |
| 49 | `--uitesting-profile-self-edit-return` | `ProfileSelfEditFixtureHost`. Scenario `--profile-self-edit-scenario`, default `own` |
| 50 | `--uitesting-profile-self-medals` | `ProfileSelfMedalsFixtureHost`. Scenario `--profile-self-medals-scenario`, default `content` |
| 51 | `--uitesting-member-parity` | `MemberParityFixtureRouter`. Page `--member-parity-page` default `home`. Scenario `--member-parity-scenario` default `ready` (`App/MemberHomeFixture.swift`) |
| 52 | `--uitesting-profile-self-growth` | `ProfileSelfGrowthFixtureHost`. Scenario `--profile-self-growth-scenario`, default `content` |
| 53 | `--uitesting-profile-self-projects` | `ProfileSelfProjectsFixtureHost`. Scenario `--profile-self-projects-scenario`, default `content` |
| 54 | `--uitesting-profile-author-posts-refresh` | `ProfileAuthorPostsRefreshFixtureHost`. Scenario `--profile-author-posts-scenario`, default `content` |
| 55 | `--uitesting-profile-edit-fixture <scenario>` | `ProfileEditFixtureHost` (`App/ProfileEditFixtureSupport.swift`) |
| 56 | `--uitesting-club-action-fixture <raw>` | `ClubActionFixtureRootView`. Raw values are the cases in `App/ClubActionFixtureSupport.swift` |
| 57 | `--uitesting-registration-fixture <raw>` | `RegistrationFixtureHostView`. Raw values are the cases in `App/RegistrationFixtureSupport.swift` |
| 58 | `--uitesting-map-core-entry` | `MapCoreEntryFixtureHost` |
| 59 | `--uitesting-module <raw>` | `ModuleFixtureRootView` |

`--uitesting-module` raw values are `ModuleFixture` in `App/ModuleFixtureSupport.swift`. The string is the case name, except the four explicit raw values `square-workspace`, `home-feed`, `merchant-city-npc`, and `mini-crop`:

`playDirector`, `playPrefab`, `playPrefabBoot`, `ownedOrderHistory`, `signedInContentDetail`, `publicTemplateDetail`, `publicPlayTemplate`, `templateDetailParity`, `templateTabStaff`, `playOpening`, `playFinishRoute`, `playCircleLink`, `playThemeRecords`, `playEntryCode`, `playBackpack`, `privateHome`, `cityGame`, `homeReturn`, `nativeEnrollment`, `nativePlatform`, `playBranchHistory`, `playExperience`, `compareGame`, `journeyContent`, `square-workspace`, `objectCards`, `socialAccount`, `searchMap`, `teams`, `settingsNative`, `presentationPatterns`, `home-feed`, `merchant-city-npc`, `mini-crop`, `ticketWallet`, `square`, `cooperation`, `accountCollections`, `creatorContent`, `growthCenter`, `officialEvents`, `projectEdit`, `discovery`, `profile`, `messaging`, `roam`, `participants`, `play`, `composer`, `topic`, `localization`.

An unknown module token does not select `ModuleFixture`. The app then falls through to the session root.

### Flags that keep a session root

These are still DEBUG-only. They do not replace `SessionRootView`.

| Argument | Where |
|---|---|
| `--uitesting-coupon-runtime [mode]` | `CouponRuntimeFixture` in `App/CouponRuntimeFixture.swift`. The source accepts `ready`, `readOnly`, `unknown`, `revokeOnConfirm`, `commandUnknown`, `commandReadOnly`, `commandNotFound`. Anything else becomes `readOnly`. Optional `--coupon-runtime-journal <uuid>` |
| `--uitesting-integrated-native [ready\|denied]` | `IntegratedNativeAcceptanceFixture`. Omitted value is `denied` |
| `--uitesting-scanner` | On the session root, presents `NativeQRScanner` |

`--uitesting-max-text` is read by individual fixtures (for example `ShopNPCFixtureView` and `ModuleFixtureRootView`). It is not a root selector. UI tests also pass Apple arguments such as `-AppleLanguages`, `-AppleLocale`, and `-UIPreferredContentSizeCategoryName`. Those are process arguments, not names defined by Questify.

Many hosts read further `--` flags after they are selected (project-edit, wallet, template authoring, content detail, and others). The host file is the list. This guide does not add flags.

## Cloud CI, the Xcode description already in the tree

The description that exists is the Cloud CI pipeline. Its screen title is `Cloud CI 流水线与测试分片`. The workflow row label is `工作流配置`. The path it shows is `.github/workflows/native-ios.yml`. Source: `App/CloudCIShardStatusSectionView.swift`. The matching validator is `Core/CloudCIShardExecutionContract.swift` (“the repository's `ubuntu-24.04` + `macos-26` cloud CI pipeline”).

This checkout has no Apple Xcode Cloud workflow. There is no `ci_scripts/` directory and no `ci_workflows/` file. Do not add one from this guide. The GitHub Actions files below are the workflows that are in the tree.

### Status snapshot (presentation model)

`CIPipelineReadinessSnapshot.defaultNativePipeline` is the snapshot the section renders. `Tests/AppUnitTests/CloudCIShardStatusSectionViewTests.swift` locks these rows. The summary string for this default is `通过 1 · 待机执行 6 · 失败 0`.

| id | title | runner | state | detail in the snapshot |
|---|---|---|---|---|
| `controls` | controls | `ubuntu-24.04` | `PASSED` | `check_scaffold.py + check_swift_syntax.py` |
| `build` | build | `macos-26` | `NOT_RUN` | `build-for-testing (Questify + QuestifyAppUnitTests + QuestifyUITests)` |
| `core` | test (core) | `macos-26` | `NOT_RUN` | `swift test --filter QuestifyCoreTests` |
| `app-unit` | test (app-unit) | `macos-26` | `NOT_RUN` | `test-without-building -only-testing:QuestifyAppUnitTests` |
| `ui-0` | test (ui-0) | `macos-26` | `NOT_RUN` | `QuestifyUITests shard 0` |
| `ui-1` | test (ui-1) | `macos-26` | `NOT_RUN` | `QuestifyUITests shard 1` |
| `ui-2` | test (ui-2) | `macos-26` | `NOT_RUN` | `QuestifyUITests shard 2` |

Badge text is `PASSED`, `NOT_RUN` (for `pendingRunner`), or `FAILED`.

That snapshot is a SwiftUI model. It is not a second workflow file. Its `controls` detail names `check_scaffold.py + check_swift_syntax.py`. The workflow file's `controls` job, quoted in the next section, runs a different command list.

### Execution contract (validator)

`CloudCIShardExecutionContract` describes the same pipeline as data:

- Runners: `ubuntu-24.04` for control gates, `macos-26` for test shards.
- Control-gate order: `current_ci.py check`, `test_current_ci`, `check_scaffold.py`, `check_roam_private_tools.py`, `ContractChecks`.
- Shards: `core` and `app-unit` use `build-and-test`. `ui-0`, `ui-1`, and `ui-2` use `test-without-building` and require a `build-for-testing` artifact (`receipt.json` and `products.tar.gz`) whose commit, tree, run id, and attempt match the source.
- Limits on the validator: 1500 seconds and 900 methods per shard.

The validator is a Swift type. It does not start a runner.

### Workflow file that the description names

`.github/workflows/native-ios.yml` is named **Current native checks**. Triggers in that file:

- `push` to `main`, `integration/wave2-20261019`, and `codex/ios-main-integration-20261101`
- `workflow_dispatch` with input `mode`: `related` (default) or `full`

`rc/20261108` is not in that push list. The file has no `pull_request` trigger. The README “CI scope” paragraph still says `Native iOS checks` runs on `main`, `migration/native-ios`, pull requests, and manual dispatch. The workflow file is the trigger list on this commit.

Jobs in the file:

| Job | Runner | What the file runs |
|---|---|---|
| `controls` | `ubuntu-24.04` | `python3 -B tools/current_ci.py check`, unittest of `tools.tests.test_current_ci`, `tools.tests.test_current_native`, and `tools.tests.test_export_current_ui_audit`, then `python3 -B tools/check_scaffold.py`, then `git diff --exit-code`. Plans with `tools/current_ci.py plan`. Mode `full` writes scope `full-current-regression`. Mode `related` writes scope `current-related-and-smoke` (`tools/current_ci.py`). Push to `integration/wave2-20261019` selects `related`. Other pushes select `full`. |
| `secrets` | `ubuntu-24.04` | Gitleaks `8.24.3`, redacted, full history |
| `native` | `macos-26` | `python3 -B tools/current_native.py run` for matrix roles `core` and `app-unit` |
| `ui_build` | `macos-26` | `current_native.py run --role ui-build`. On success it uploads `receipt.json` and `products.tar.gz` |
| `ui` | `macos-26` | `current_native.py run --role ui` against that same-run build, one shard index at a time |
| `platforms` | `macos-26` | Only when scope is `full-current-regression` and the UI build succeeded. See the Release lines below |
| `current-checks` | `ubuntu-24.04` | `current_native.py aggregate` over the result artifacts |

`platforms` is the only place this workflow passes `-configuration Release`. Both commands set `CODE_SIGNING_ALLOWED=NO`:

```sh
xcodebuild -project Questify.xcodeproj -scheme Questify -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$RUNNER_TEMP/questify-device" CODE_SIGNING_ALLOWED=NO build
```

```sh
xcodebuild -project Questify.xcodeproj -scheme Questify -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$RUNNER_TEMP/questify-us-device" \
  QUESTIFY_MARKET=US QUESTIFY_API_BASE_URL= CODE_SIGNING_ALLOWED=NO build
```

The device job also builds `QuestifyAppUnitTests` for `iphoneos` as **Debug** `build-for-testing`, still with `CODE_SIGNING_ALLOWED=NO`. The US job then runs `tools/check_built_profile.py --market US` and `tools/check_gltf_linked.py` on that unsigned Release app. Those lines are the workflow text. **A Release build was not run** for this guide, on this workspace or as a claimed CI result.

The workflow does not sign a distribution IPA and does not upload to a store. Artifact retention in the file is one day.

### The other workflow in the tree

`.github/workflows/native-targeted.yml` is named **Manual historical source audit**. It runs only on `workflow_dispatch` with a 40-character `audit_sha`, on `ubuntu-24.04`. The step prints `No current product test or release admission is claimed by this manual source audit.` It is not a daily build and not a release workflow.

`tools/tests/fixtures/run130_receipt_semantics/.github/workflows/native-ios.yml` is fixture content for a test. It is not a live workflow entry.

## Release

Version on this branch stays **0.1.0 (1)**. `Config/Base.xcconfig` holds both numbers. `INFOPLIST_KEY_CFBundleDisplayName` is `Questify`. This guide does not edit that file and does not bump the version.

**A Release build was not run.**

Signing material that is in the tree:

- `Config/Questify.entitlements` is Sign in with Apple `[Default]` only. Debug and Release app configurations set `CODE_SIGN_ENTITLEMENTS` to that file. The developer-portal switch for the App ID is owner work (`docs/release/ship-prep.md`).
- `tools/check_signing_evidence.py` reads a settings file you pass in. It exits 0 only when `CODE_SIGNING_ALLOWED` is `YES`, `DEVELOPMENT_TEAM` is ten letters or digits, the bundle id is not a placeholder, and the API URL and realm are present and not a placeholder. The committed `Config/Base.xcconfig` does not meet that bar. The script never runs `xcodebuild`.

Signing material that is not in the tree, so this guide does not name a certificate or a profile:

- No `DEVELOPMENT_TEAM` assignment in a committed xcconfig.
- No distribution certificate, `.p12`, `.p8`, or `.mobileprovision`.
- `Config/China.Production.xcconfig` sets the reviewed China API input `https://www.chengyinhub.com/prod-api/` (written `https:/$()/www.chengyinhub.com/prod-api/`) and `QUESTIFY_SESSION_REALM = cn-prod`. It does not set `PRODUCT_BUNDLE_IDENTIFIER` or `DEVELOPMENT_TEAM`. It is not the app target's base configuration. Shipping still depends on `RegionalLaunchConfiguration` selecting a composition. `docs/release/ship-prep.md` records the shipped call as `makeComposition(reviewed: nil, build: .current)`.

Unsigned archive, owner signing, and the App Store checklist already live in:

- `docs/release/ship-prep.md`
- `docs/release/app-store-metadata-checklist.md`
- `tools/archive_unsigned.py`

`python3 -B tools/archive_unsigned.py` runs the preflight and does not invoke `xcodebuild`. `python3 -B tools/archive_unsigned.py --archive` is the archive command. It forces `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, an empty `CODE_SIGN_IDENTITY`, and `AD_HOC_CODE_SIGNING_ALLOWED=NO`. Output path is `.build/unsigned-archive/Questify.xcarchive` (gitignored via `.build/`). The script rejects upload and signing arguments. This workspace did not run `--archive`. `docs/release/ship-prep.md` already says the same for its own pass.

Do not treat a green `controls` job, an unsigned compile, or this document as App Store submission. Store listing, privacy-policy URL, screenshots, age rating, export compliance, and the account-deletion answer stay on the owner checklist.

## Related pages

- `README.md` — product scope and the unsigned simulator command
- `docs/release/ship-prep.md` — privacy manifest, entitlements, unsigned archive
- `docs/release/app-store-metadata-checklist.md` — owner checklist, nothing submitted
- `docs/release/smoke-flows.md` — Maestro flows, no launch arguments
- `docs/release/design-report-K.md` and `design-spec-d1.md` through `design-spec-d4.md` — design passes
