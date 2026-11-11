# TestFlight internal build

Branch `rel/testflight-config`. Release configuration only; Debug and the unit/UI test targets keep the
placeholder defaults from `Config/Base.xcconfig`.

## Release identity (owner approved)

| Setting | Value |
| --- | --- |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.chengyinhub.chengyinApp` |
| `DEVELOPMENT_TEAM` | `9VHY8N755R` |
| `QUESTIFY_API_BASE_URL` | `https://www.chengyinhub.com/prod-api/` (xcconfig spelling `https:/$()/www.chengyinhub.com/prod-api/`) |
| `QUESTIFY_SESSION_REALM` | `cn-prod` |
| `QUESTIFY_MARKET` | `CN` |

These live in `Config/Release.xcconfig` (includes `China.Production.xcconfig`), which is the base
configuration of the `Questify` app target's **Release** configuration only. The project is generated:
change `tools/generate_project.py`, then run `python3 tools/generate_project.py`; never hand-edit `project.pbxproj`.

## Fail-closed gate

The first build phase of the app target, **Release Identity Gate**, runs only when `CONFIGURATION=Release`.
It stops the build with `error: Release build blocked: ...` when `QUESTIFY_API_BASE_URL` is empty or not
`https://`, `QUESTIFY_SESSION_REALM` is empty, or the bundle ID is empty, starts with `invalid.`, or is a
placeholder (`example`, `placeholder`, unresolved `$(...)`, not reverse-DNS). Debug and simulator test builds skip it.
`python3 tools/check_release_config.py` (also run by `tools/check_scaffold.py`) extracts the exact script from the
generated project and proves it passes the real values and fails on empty/placeholder ones.

## Archive and upload from Xcode

1. `git checkout rel/testflight-config` (or the branch the owner merges it into) and open `Questify.xcodeproj`.
2. Xcode > Settings > Accounts: sign in with the Apple ID on team `9VHY8N755R`.
3. Select scheme **Questify** and destination **Any iOS Device (arm64)**.
4. Targets > Questify > Signing & Capabilities: Team `9VHY8N755R`, "Automatically manage signing" on, Bundle
   Identifier `com.chengyinhub.chengyinApp` (the Sign in with Apple capability comes from `Config/Questify.entitlements`).
5. Raise `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig` for every upload (`python3 tools/bump_version.py` if used);
   App Store Connect rejects a repeated build number.
6. **Product > Archive**. A failing "Release Identity Gate" means one of the values above is wrong.
7. Organizer > Archives > select the archive > **Distribute App** > **App Store Connect** > **Upload**; keep automatic signing.
8. Wait for processing in App Store Connect > TestFlight (email on completion).

## What this build enables

Against the production backend `https://www.chengyinhub.com/prod-api/` (China market, realm `cn-prod`), through the
reviewed composition in `App/RegionalLaunchConfiguration.swift` (`productionGatesEnabled`):

- Sign in with Apple and SMS sign-in
- Bundled legal catalog
- Wallet history/overview, orders, favorites and coupons **reads**
- Existing reviewed public reads (home/search, map, public templates, official events, play nodes/route state)

## What it does not enable

- `WalletPayoutCapability` stays off; no payment, payout, bank-withdrawal or virtual-goods switch is changed
- Password login stays out of Release
- No US market, no HTTP/ATS exception, no secrets, tokens or provider keys in build settings
- No deploy or backend change; nothing is uploaded by tooling (`tools/archive_unsigned.py` never signs or uploads)

`ReviewedMarketLaunch.approvedBaseURLs` lists only `https://www.chengyinhub.com/prod-api/` for China, matching the
xcconfig URL (checked by `tools/check_release_config.py`).

## Owner still must do

- The App Store Connect app record (Apple ID 6832441069) exists; confirm its bundle ID is `com.chengyinhub.chengyinApp`.
- Register the Sign in with Apple capability on that App ID in the developer portal (automatic signing normally does this).
- Create the internal testing group in TestFlight and add internal testers (App Store Connect users with access).
- Answer export-compliance / encryption questions for the first build.
- Click Archive and Upload in Xcode; the agent run cannot sign or upload.
- Because this build reads production data, use real production test accounts only for sign-in; do not test writes.

## Contract suite ratchet

Before an upload, run `python3 tools/contract_ratchet.py --check` (~2 min). It must report no new failures; after fixing tests run `--update` to shrink `docs/release/contract-failing-baseline.txt`. Xcode Cloud runs it as a non-blocking warning (`ci_scripts/ci_pre_xcodebuild.sh`). Details: `docs/release/receipts/contract-ratchet.md`.
