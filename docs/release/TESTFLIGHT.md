# TestFlight Release Runbook

This runbook documents the one-command Release archive/export pipeline, version bumping, preflight gates, internal TestFlight group, post-upload verification, and rollback for Questify iOS.

## Release Identity & Production Boundaries

| Setting | Release Value | Source |
| --- | --- | --- |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.chengyinhub.chengyinApp` | `Config/Release.xcconfig` |
| `DEVELOPMENT_TEAM` | `9VHY8N755R` | `Config/Release.xcconfig` |
| `QUESTIFY_API_BASE_URL` | `https://www.chengyinhub.com/prod-api/` | `Config/Release.xcconfig` + `Config/China.Production.xcconfig` |
| `QUESTIFY_SESSION_REALM` | `cn-prod` | `Config/Release.xcconfig` + `Config/China.Production.xcconfig` |
| `QUESTIFY_MARKET` | `CN` | `Config/Release.xcconfig` |
| `QUESTIFY_DEPLOYMENT_ENVIRONMENT` | `production` | `Config/China.Production.xcconfig` |
| App Store Connect Apple ID | `6832441069` | App Store Connect record |
| Signing | Automatic (`app-store-connect`, `arm64`) | `Config/Base.xcconfig` + `ExportOptions.plist` |
| Entitlement | Sign in with Apple (`Default`) | `Config/Questify.entitlements` |

### Closed Production Switches

In `Release` (`DEBUG` and `TEST` unset):
- `ReleaseMoneyWriteSwitch` (`Core/ChinaReviewedRouteCapability.swift`): `paymentEnabled`, `payoutEnabled`, `withdrawalEnabled`, and `virtualGoodsEnabled` are constant `false`.
- `ReviewedAreaSwitch` (`App/ReviewedAreaSwitch.swift`): `moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` stay `false` for `Release` and `www.chengyinhub.com`.
- `AppSession.passwordLoginCompiledIn` and `canUsePassword` (`App/AppSession.swift`): compile to `false`.
- `WalletPayoutCapability.isOn` (`App/WalletCommerceViews.swift`): `false`.
- `App/DesignFixtures/*`, `App/AppStoreReviewDemoAccountAndFixtureSectionView.swift`, and `E2ETestHostOverride` (`--e2e-test-host`): excluded from `Release` by `EXCLUDED_SOURCE_FILE_NAMES` and `#if DEBUG`.

## Prerequisites (Signing Mac)

1. macOS with Xcode (iOS 17+ SDK) and `xcrun altool` available.
2. Clean checkout on the approved release branch; no uncommitted `Config/Local*.xcconfig` overriding version or Release identity.
3. App Store Connect API Key (`.p8` file kept **outside** the repository, never committed):
   - `APP_STORE_CONNECT_KEY_ID` — 10-character Key ID from App Store Connect > Users and Access > Integrations > App Store Connect API.
   - `APP_STORE_CONNECT_ISSUER_ID` — Issuer UUID from the same page.
   - `APP_STORE_CONNECT_KEY_PATH` — path to `AuthKey_<KEY_ID>.p8` outside the repo (or place `AuthKey_<KEY_ID>.p8` in `~/.appstoreconnect/private_keys/`).
   - Required role on the API key: **App Manager** or **Admin** (or **Developer** with upload access).

## Exact Steps

### 1. Bump Version and Build Number

Never reuse a `(CFBundleShortVersionString, CFBundleVersion)` pair already uploaded to App Store Connect.

```sh
./scripts/release/bump-version.sh <MARKETING_VERSION> <BUILD_NUMBER>
# Example:
./scripts/release/bump-version.sh 0.1.0 2
```

- Updates `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig` (which Xcode writes into `CFBundleShortVersionString` and `CFBundleVersion` via `GENERATE_INFOPLIST_FILE = YES`).
- Commit the bumped `Config/Base.xcconfig` before building the release archive.
- To inspect the current pair without editing: `./scripts/release/bump-version.sh --print`.

### 2. Run Preflight Gates (Optional Standalone Check)

```sh
./scripts/release/preflight.sh
```

Runs all repo gates (`check_scaffold`, `check_design_lint`, `check_appsession_ratchet`, `check_release_config`, `check_design_fixture_release_exclusion`, `audit_client_ops_surfaces --check`, `lint_no_release_print`, `check_l2_environment_configs`, `check_release_preflight`, and `contract_ratchet --check`). Exits non-zero on any failure.

### 3. Archive & Export IPA ("deploy now" release build)

`scripts/release/archive.sh` refuses to run unless `RELEASE_CONFIRM=deploy-now` is set. It runs `preflight.sh` first, reads `DEVELOPMENT_TEAM` from the project's `Release` settings, archives `Release` for `generic/platform=iOS` (`arm64`), exports an `app-store-connect` IPA with automatic signing, and prints all `.dSYM` paths:

```sh
RELEASE_CONFIRM=deploy-now ./scripts/release/archive.sh
```

If running headless without an Xcode-signed Apple ID session, also pass the App Store Connect API key env vars:

```sh
RELEASE_CONFIRM=deploy-now \
  APP_STORE_CONNECT_KEY_ID="<KEY_ID>" \
  APP_STORE_CONNECT_ISSUER_ID="<ISSUER_ID>" \
  APP_STORE_CONNECT_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8" \
  ./scripts/release/archive.sh
```

Outputs under `.build/release/` (gitignored):
- `.build/release/Questify.xcarchive`
- `.build/release/ExportOptions.plist`
- `.build/release/export/Questify.ipa`
- `.build/release/Questify.xcarchive/dSYMs/*.dSYM` (printed by `archive.sh`; retain these for crash symbolication)

### 4. Upload to TestFlight (Separate Manual Step)

Uploading never runs automatically. Validate first if desired, then upload:

```sh
# Optional pre-upload App Store Connect validation:
RELEASE_CONFIRM=deploy-now \
  APP_STORE_CONNECT_KEY_ID="<KEY_ID>" \
  APP_STORE_CONNECT_ISSUER_ID="<ISSUER_ID>" \
  APP_STORE_CONNECT_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8" \
  ./scripts/release/upload.sh --validate-only .build/release/export/Questify.ipa

# Upload to App Store Connect / TestFlight:
RELEASE_CONFIRM=deploy-now \
  APP_STORE_CONNECT_KEY_ID="<KEY_ID>" \
  APP_STORE_CONNECT_ISSUER_ID="<ISSUER_ID>" \
  APP_STORE_CONNECT_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8" \
  ./scripts/release/upload.sh .build/release/export/Questify.ipa
```

## Internal Tester Group

- **App Store Connect** > **Apps** > **Questify** (`6832441069` / `com.chengyinhub.chengyinApp`) > **TestFlight** > **Internal Testing**.
- Create or select the **Internal Testers** group (App Store Connect team members on team `9VHY8N755R` with Admin, App Manager, Developer, or Marketing roles).
- Internal TestFlight builds skip Beta App Review and become available once App Store Connect finishes build processing and export compliance is answered.
- Because this build points at production (`https://www.chengyinhub.com/prod-api/`, realm `cn-prod`), internal testers must use real production test accounts and avoid destructive test writes against live user data.

## What to Check After Upload

1. **Upload command**: `scripts/release/upload.sh` exited `0` without errors from `xcrun altool`.
2. **Processing & Export Compliance**: In App Store Connect > TestFlight > iOS Builds, the new `(CFBundleShortVersionString, CFBundleVersion)` transitions from *Processing* to *Ready to Submit* / *Testing*. Answer the export compliance prompt (`ITSAppUsesNonExemptEncryption` is unset in `Config/Info.plist`).
3. **Device Install Smoke (iPhone on iOS 17+)**:
   - **Settings -> About**: displays the exact `Version` and `Build` bumped in Step 1.
   - **Launch & Consent**: usage-consent gate appears; guest Browse enters the tab shell without crashing.
   - **Auth Surfaces**: Sign in with Apple and China SMS sign-in are available; password sign-in is absent.
   - **Production Switch Safety**: no payment submission, bank withdrawal/payout entry, virtual-goods purchase, merchant write tools, or DEBUG fixture/test-host UI is reachable.
4. **dSYM Retention**: archive the `.dSYM` bundles printed by `archive.sh` alongside the release tag/receipt for crash symbolication.

## Rollback

See also `docs/release/app-rollback-plan.md`.

1. **Stop distribution immediately**: In App Store Connect > TestFlight > iOS Builds, select the faulty build and click **Expire Build** (and/or remove it from the internal tester group). Testers who already installed it retain that binary until they update to a newer build or it expires.
2. **Never reuse or downgrade build numbers**: Apple rejects duplicate `(CFBundleShortVersionString, CFBundleVersion)` uploads, and older builds cannot be re-activated as an update over a higher build number.
3. **Cut a rollback build from the last known-good commit**:
   - Check out the last known-good commit in a clean worktree (never force-reset `ui/main`).
   - Bump `CFBundleVersion` strictly higher than the expired bad build:
     ```sh
     ./scripts/release/bump-version.sh <MARKETING_VERSION> <HIGHER_BUILD_NUMBER>
     ```
   - Verify preflight, archive, and upload:
     ```sh
     ./scripts/release/preflight.sh
     RELEASE_CONFIRM=deploy-now ./scripts/release/archive.sh
     RELEASE_CONFIRM=deploy-now ./scripts/release/upload.sh .build/release/export/Questify.ipa
     ```
   - Confirm **Settings -> About** on a TestFlight device shows the new higher build number.
