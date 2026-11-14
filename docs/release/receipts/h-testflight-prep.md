# TestFlight Preparation Receipt (`ui/h-testflight-prep`)

- **Branch**: `ui/h-testflight-prep`
- **Base**: `origin/ui/main` (`3ac970ec2`)
- **Scope**: Code, release scripts, preflight assertions, unit tests, and runbook documentation only. Per workspace constraints, `xcodebuild`, `swift build`, and `swift test` were **not** executed on this Mac; archive/export (`scripts/release/archive.sh`) and upload (`scripts/release/upload.sh`) were verified with stubbed `xcodebuild`/`xcrun` harnesses in Python `unittest`.

## Deliverables

1. **[scripts/release/archive.sh](../../scripts/release/archive.sh)**
   - Refuses to run unless `RELEASE_CONFIRM=deploy-now`.
   - Runs `./scripts/release/preflight.sh` before building (can only be bypassed with explicit `SKIP_PREFLIGHT=1` if an integrator chooses).
   - Reads `DEVELOPMENT_TEAM` and `CODE_SIGN_STYLE` from `Config/Release.xcconfig` / `Config/Base.xcconfig` (never hard-codes secrets) and generates a transient `ExportOptions.plist` (`method = app-store-connect`, `signingStyle = automatic`, `teamID` from project settings, `uploadSymbols = true`).
   - Archives the `Release` configuration for `generic/platform=iOS` (`ARCHS=arm64`), exports the `.ipa`, and prints discovered `.dSYM` paths inside `Questify.xcarchive/dSYMs`.
   - Supports optional App Store Connect automatic-signing authentication flags when `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, and `APP_STORE_CONNECT_KEY_PATH` are all provided.

2. **[scripts/release/bump-version.sh](../../scripts/release/bump-version.sh)**
   - Sets `MARKETING_VERSION` (`CFBundleShortVersionString` via `GENERATE_INFOPLIST_FILE = YES`) and `CURRENT_PROJECT_VERSION` (`CFBundleVersion`) from positional CLI args (`<marketing-version> <build-number>`) or auto-increments the build number when `--bump-build` is passed.
   - Delegates cleanly to `python3 -B tools/bump_version.py --apply` on `Config/Base.xcconfig` so `Config/Info.plist` and `project.pbxproj` stay compliant with `tools/archive_unsigned.py`.

3. **[scripts/release/preflight.sh](../../scripts/release/preflight.sh)** and **[tools/check_release_preflight.py](../../tools/check_release_preflight.py)**
   - Runs every gate and exits non-zero if any gate fails:
     - `check_scaffold` (`python3 -B tools/check_scaffold.py`)
     - `design_lint` (`python3 -B tools/check_design_lint.py`)
     - `appsession_ratchet` (`python3 -B tools/check_appsession_ratchet.py`)
     - `check_release_config` (`python3 -B tools/check_release_config.py`)
     - `fixture_exclusion` (`python3 -B tools/check_design_fixture_release_exclusion.py`)
     - `client_ops_audit` (`python3 -B tools/audit_client_ops_surfaces.py`)
     - `lint_no_release_print` (`python3 -B tools/lint_no_release_print.py`)
     - `l2_environment_configs` (`python3 -B -m unittest tools/tests/test_l2_environment_configs.py`)
     - `release_preflight_assertions` (`python3 -B tools/check_release_preflight.py`)
     - `contract_ratchet` (`python3 -B tools/contract_ratchet.py --check`)
   - `tools/check_release_preflight.py` verifies `Config/Release.xcconfig` (`DEVELOPMENT_TEAM = 9VHY8N755R`, `PRODUCT_BUNDLE_IDENTIFIER = com.chengyinhub.chengyinApp`, `QUESTIFY_API_BASE_URL = https:/$()/www.chengyinhub.com/prod-api/`, `QUESTIFY_SESSION_REALM = cn-prod`, `QUESTIFY_MARKET = CN`), asserts no DEBUG/TEST or design-fixture/test-host code leaks into the Release projection, asserts production host (`www.chengyinhub.com`) and realm (`cn-prod`), and asserts that the Release money (`ReleaseMoneyWriteSwitch`), merchant payout (`WalletPayoutCapability.isOn`), and password (`passwordLoginCompiledIn` / `canUsePassword`) switches are closed (`false`) in non-`DEBUG` builds.

4. **[docs/release/TESTFLIGHT.md](../TESTFLIGHT.md)**
   - Documents prerequisites, App Store Connect API key env vars (not stored in repo), internal tester group setup, one-command release flow (`RELEASE_CONFIRM=deploy-now`), post-upload verification checklist, and rollback procedures.

5. **[scripts/release/upload.sh](../../scripts/release/upload.sh)**
   - Separate upload/validation script guarded by `RELEASE_CONFIRM=deploy-now`; never invoked automatically by `archive.sh`.
   - Uses `xcrun altool --upload-app` (or `--validate-app` with `--validate-only`) authenticated via `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, and `APP_STORE_CONNECT_KEY_PATH` (mounted in a temporary `API_PRIVATE_KEYS_DIR` cleaned up on exit).

6. **[tools/tests/test_release_prep.py](../../tools/tests/test_release_prep.py)**
   - Unit and script-harness tests covering guard refusals, stubbed `xcodebuild` archive + export + `ExportOptions.plist` + dSYM printing, stubbed `xcrun altool --validate-app`, `bump-version.sh`, `preflight.sh` fail-closed behavior, `check_release_preflight.py` positive/negative checks, and `TESTFLIGHT.md` completeness.

## Verification Log

- `bash -n scripts/release/archive.sh scripts/release/bump-version.sh scripts/release/preflight.sh scripts/release/upload.sh`: PASS (exit 0).
- `python3 -B tools/check_release_preflight.py`: PASS (`PASS release preflight assertions: Release config verified (com.chengyinhub.chengyinApp, https://www.chengyinhub.com/prod-api/, realm=cn-prod), no DEBUG/test-host code in Release, money/merchant/password switches closed for production.`).
- `python3 -B -m unittest -v tools/tests/test_release_prep.py`: PASS (`Ran 9 tests in 25.754s - OK`).
- `python3 -B tools/archive_unsigned.py`: PASS (exit 0; `preflight: ok`, `marketing version: 0.1.0`, `build: 1`).
- `./scripts/release/preflight.sh`: exited with code `1` as expected because `contract_ratchet` already fails on base `origin/ui/main` (`3ac970ec2`):
  - PASS: `check_scaffold`, `design_lint`, `appsession_ratchet`, `check_release_config`, `fixture_exclusion`, `client_ops_audit`, `lint_no_release_print`, `l2_environment_configs` (15 tests OK), `release_preflight_assertions`
  - FAIL: `contract_ratchet` (`contract ratchet: 223 failing, baseline 193, new 36, fixed 6` — pre-existing base drift on `origin/ui/main`, preserved intact without altering the baseline).
- `gitleaks`: 0 leaks across all newly added files.
