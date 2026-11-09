# Launch status

Checked on `origin/rc/20261108` at `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` (2026-11-08 10:26 PM PT). That commit is `Merge origin/ui/d1 into rc/20261108.`

This note records git facts for that tip. It records no test pass, no simulator run, and no workflow run. It does not restyle UI. It does not refresh `tools/current_ci_manifest.json`. It does not deploy.

`git merge-base --is-ancestor` exits 0 for every lane tip below against `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. `origin/cursor/cb1` through `origin/cursor/cb8`, `origin/ui/kit` at `292417cddde11e98ceae91580c2aff963851353f`, and `origin/ui/d1` at `da6bed72d31bec4033382f90f5e43e9b3ca3336b` are in that commit.

## Lane table

| Lane | state | SHA | blockers | next | owner decisions |
|---|---|---|---|---|---|
| `origin/rc/20261108` | candidate tip | `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` | `ios-current-ci` is the known-red gate. The CI ledger has not had its final refresh. The US API URL is unknown. No deploy has happened. | This note does not ship the tip. | Signing, upload, `deploy now`, account deletion, and export compliance stay with the owner. See `cursor/cb7` and `cursor/cb8`. |
| `origin/cursor/cb1` | contained. First parent of merge `b3908cf4f0ca47375cac77c2b115d522797cdc0a`. No merge subject names `cursor/cb1`. | `5f44d2cead78a5a4cb33fad31b196924f880f44b` | None recorded in that commit. | None recorded. | None recorded. The commit changes `App/ClubGovernanceCommandForm.swift` so the discard sheet uses `appLocalized` for the four existing `club.gov` keys. |
| `origin/cursor/cb2` | contained. Merge `b3908cf4f0ca47375cac77c2b115d522797cdc0a`. | `d3c9f6d39e6d93d5974762d0fd683c5374504b1f` | `docs/release/cb2-core-unexpected.md` says this environment did not re-run `swift test`. Six unexpected names are not listed there. | None recorded as a product fix. The doc marks the proved rows `baseline`. | The doc keeps the fail-closed checks. It does not loosen them to match the stale fixtures. |
| `origin/cursor/cb3` | contained. Merge `a4b9c9be835b1c58b4b9ae8a661ecc1fd3b57231`. | `f273c806c04edd9395c993048f188791e937fb94` | `docs/release/cb3-appunit-groups.md` says AppUnit was not re-run and the note does not replace the Mac failure count. | None recorded. | Copy mismatches in that note are left as owner decisions. `makeComposition(reviewed: nil)` stays unchanged in that note. |
| `origin/cursor/cb4` | contained. Merge `03d82ebf297b7bbf05fa2ca2208037eec30550c8`. | `c1232ba82a780b49049a2b6d97b898bbde608c50` | `docs/release/pwave-core.md` says backend execution in the source package is `NOT_RUN`. | None recorded. | `RegionalLaunchConfiguration.composition` remains `makeComposition(reviewed: nil)` in that note. |
| `origin/cursor/cb5` | contained. Merge `97408299e2b80f23051bb25fcd335996b7e7bfc8`. | `0f03149bd3334e7c55e01e0b3261bf9e1b6b7e3f` | `docs/release/ug-core.md` says backend execution is `NOT_RUN`. Help, skip, hangman submit, and accusation submit throw `writesNotAvailable`. A paid workshop install does not complete. | None recorded. | `composition` remains `makeComposition(reviewed: nil)` in that note. |
| `origin/cursor/cb6` | contained. Merge `a4366920fa6cd3b6b1457cef298443cf135091a1`. | `b82cbcc4031612f4704925e3794c1bd4094cd784` | The US market has no reviewed host. The default target still uses `Config/Base.xcconfig`, whose API URL and realm are empty, so that build stays `makeComposition(reviewed: nil, build: .current)`. | None recorded. | Password login, bank-card withdrawal, and virtual goods stay off. Recorded in the commit message and in `docs/release/wire-1-grants.md`. |
| `origin/cursor/cb7` | contained. Merge `d7cc03e1004e49873941c5a84d607242ebc55d39`. | `6c3dfe6bbccaac52768457bedd8fba723cead235` | `docs/release/backend-deploy-plan.md` says no deploy is performed. The schema script does not open a socket. | Deploy stays unperformed until the owner writes `deploy now`. | `deploy now` is the owner's phrase. This file is not that phrase. |
| `origin/cursor/cb8` | contained. Merge `4b85c1da5fca4c87bebe11ab4e348099e4a21929`. | `748e1c4b0e3c630eaee4e67df428c825e7dccb06` | `docs/release/ship-prep.md` says this workspace did not run `tools/archive_unsigned.py --archive`. `docs/release/smoke-flows.md` says the Maestro flows were not executed. | Archive signing and App Store upload stay owner-only. | Whether account deletion ships. Export compliance (`ITSAppUsesNonExemptEncryption` is unset). The App ID switch for Sign in with Apple. The App Store Connect fields in `docs/release/app-store-metadata-checklist.md`. |
| `origin/ui/kit` | contained. Merge `8be34852e1d108df8161fba2d554e66d27167837`. | `292417cddde11e98ceae91580c2aff963851353f` | `docs/release/design-report-K.md` leaves Dynamic Type XL, 简体中文, and a light scrim over real photos unchecked. | This note does not restyle the kit. | None added here. The report records `BUILD_EXIT=0` for its own `design-run.sh`. This note did not re-run that command and does not treat that line as a launch pass. |
| `origin/ui/d1` | contained. Second parent of `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. | `da6bed72d31bec4033382f90f5e43e9b3ca3336b` | `docs/release/design-report-d1.md` titles the report `PARTIAL`. The role picker was not screenshotted. Welcome menu, Welcome XL/zh, and the small-phone safe-area check are open. | This note does not restyle onboarding. | None added here. |
| CI ledger | not finally refreshed | last write `a6871477c497c6440ce06417035572d7278ea830`; blob `743958754af4608942e3a86019e71fa499eba78b` is the same blob at the candidate tip | 73 paths differ between that commit and `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. `tools/current_ci_manifest.json` is not one of them. `verified_manifest` in `tools/current_ci.py` requires the ledger snapshot to equal the tree. | This note does not refresh the ledger. | No further refresh is recorded on this tip. `comparison_base` inside the ledger is `5f318716e596dcd12ad2b84e83ad85046ce99f73`. |
| `ios-current-ci` | known-red | no commit on this tip uses that name | The in-tree check is `python3 -B tools/current_ci.py check` in `.github/workflows/native-ios.yml`. That command uses `verified_manifest`. The ledger snapshot does not match the tree, so this note records no pass. Push branches in that workflow file are `main`, `integration/wave2-20261019`, and `codex/ios-main-integration-20261101`. | This note does not refresh the ledger and does not start a workflow. | None recorded under the name `ios-current-ci`. |
| US API URL | unknown | tree `67053ccb33c0e1ad35a7508f8546ae9076fd82e5` | `QUESTIFY_API_BASE_URL` is empty in `Config/UnitedStates.xcconfig`, `Config/UnitedStates.Production.xcconfig`, and `Config/UnitedStates.Staging.xcconfig`. `Config/UnitedStates.Development.xcconfig` sets `http://127.0.0.1:8099`. That is a loopback input, not a US API URL. | This note does not set a US URL. | `Config/UnitedStates.xcconfig` says US auth contracts and provider verification remain pending. `Config/China.Production.xcconfig` does set `https://www.chengyinhub.com/prod-api/` and `QUESTIFY_SESSION_REALM = cn-prod`. |
| deploy | not done | no deploy commit on `a6871477c497c6440ce06417035572d7278ea830..67053ccb33c0e1ad35a7508f8546ae9076fd82e5` | `docs/release/backend-deploy-plan.md` says deploy happens only after the owner writes `deploy now`, and that the plan does not deploy. | Unperformed. | The owner writes `deploy now`. Rollback in that plan names backend commit `014fc0d8` on `liboyang42-cpu/chengyin` and a jar prefix `655a377a`. The full jar digest is not in this repo. |

## Ledger mismatch checked on this tree

These paths are absent from `snapshot.sources` in the ledger blob above, and the files exist at the candidate tip:

- `Core/PWaveP2AffiliateCenter.swift`
- `Core/UGGameplay.swift`
- `Tests/CoreTests/PWaveSecondWaveTests.swift`
- `Tests/CoreTests/PlayActionReceiptTests.swift`
- `Tests/CoreTests/UGGameplayTests.swift`

These paths are in the ledger, and the file bytes at the candidate tip hash to a different SHA-256 than the ledger row:

- `App/AppCompositionRoot.swift`
- `App/ClubGovernanceCommandForm.swift`
- `App/DesignSystem/CYSkeleton.swift`
- `App/LoginView.swift`
- `Questify.xcodeproj/project.pbxproj`
- `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift`
- `Tests/CoreTests/PWaveCoreTests.swift`
- `Tests/CoreTests/ReviewedChinaLaunchTests.swift`
- `Tests/CoreTests/WP04OwnerDecisionGuardTests.swift`

That list is the set hashed for this note. It is not the full 73-path diff. `python3 -B tools/current_ci.py check` was not executed here, and `python3 -B tools/current_ci.py refresh` was not executed here.
