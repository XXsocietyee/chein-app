# ui-cur-fixtures-9

Branch `ui/cur-fixtures-9` started at `origin/ui/main` `5ba7b0f2c5f10dea10905895da947c350b3e24ac`. The three source branches were merged in order and were not moved.

## Merge SHAs

| Order | Source | Source SHA | Merge SHA |
|---|---|---|---|
| 1 | `ui/h-visual-bugs` | `9cf026368e23fda9ba08a86e40c03f6ca440e17b` | `ecf41f13b16cc8313a260af1a69e7acccbb8cd3f` |
| 2 | `ui/h-offline-2` | `d65e36f51d4b1f3fc9e8e7e10005e82531b79c40` | `c3428c83032b71faee7a50a5c24d9ed93334e1cf` |
| 3 | `ui/h-sweep-2` | `1fa9c019ae09827a3d87ddcd0869f551f1f4d480` | `63b2eac1704851ec76b493cd0a910987b3de191b` |

`ui/h-offline-2` and `ui/h-sweep-2` were 44 commits behind. Conflict notes:

- `Core/AuthService.swift` keeps the ui/main `RequestReferenceLedger` record and the offline-2 response headers.
- `docs/release/completeness-matrix.csv` keeps the ui/main rows. The four new `PKG-63-*` rows from offline-2 were appended. Sweep-2 had no new row ids; its rewrites of existing rows were not taken, so a ui/main `DONE` row was not replaced with `MISSING`.
- `App/RegionalLaunchConfiguration.swift` kept the ui/main switches and the `ReadRetryHTTPTransport` wrap that offline-2 already had. No further behavior was added.
- `App/AppSession.swift` and `App/AppCompositionRoot.swift` were not given new methods. `docs/release/contract-failing-baseline.txt` was not edited.
- `ReviewedAreaSwitch` is still one enum. `moneyPayments`, `payout`, `merchantWrites`, and `passwordLogin` stay closed for `www.chengyinhub.com`.
- Sweep-2 redeclared `ClubDirectLedgerSection`, `ClubEditionEmptyReasonView`, and `PlayGuardAppealCommand`. The ui/main types stayed. The sweep ledger view is `Sweep2ClubDirectLedgerSection`. The sweep command is `Sweep2GuardAppealCommand`. The duplicate edition view was dropped because `ClubEditionEmptyReasonView` in `PlayCreatorTailViews.swift` is the one the governance screen calls.
- `App/OwnerDecisionFixtureHost.swift` and `App/OwnerDecisionPayoutViews.swift` stay removed. The sweep-2 merge tried to add the host; the file and any project reference were dropped. `OwnerDecisionFixtureHost` stays removed.

## Fixtures

`App/DesignFixtures/Cur9Fixtures.swift` is `#if DEBUG`. `DesignFixtureRegistry.make` hands `cur9-*` to `Cur9Fixtures.make`. Release exclusion includes `Cur9Fixtures.swift` plus the names ui/main already excluded (`CurFixtures2`, `CurFixtures3`, `Cur4Fixtures`, and the rest of `App/DesignFixtures`). `CurFixtures6` and `Cur7Fixtures` are not files and were not exclusion names on ui/main, so they were not invented. `DesignFixtureReleaseExclusionAudit` lists the new symbols.

No visual restyle, no new color, no layout change. Unknown is an em dash (`—`). XCUITests were not run on this VM.

| Branch | Fixture id | Screen | What it shows |
|---|---|---|---|
| visual-bugs | `cur9-growth-pushed` | `GrowthCenterView` pushed inside the player `TabView` / `CYNightTabBar` | Tab bar hidden via the existing `cyHideTabBar()`. Score row uses the palette contrast already on that view (`palette.textPrimary`, `palette.bgElevated`, `palette.bgRaised`). Synthetic reader, no network. |
| visual-bugs | `cur9-tab-root` | Same tab shell, root only | Tab bar stays visible. Non-happy pair for the hide. |
| offline-2 | `cur9-offline-sync` | `CYStatusOfflineBanner` + `CYOfflineWriteStatusBanner` | Roam sync status after two in-memory transport failures (`RoamSyncStatusTracker`, key `roam.sync.offline`) and a queued write. No retry action and no network call. |
| offline-2 | `cur9-offline-still` | Same banners | `stillOffline` plus write status `.rejected`. The failed / still-offline copy that already exists. |
| sweep-2 | `cur9-ledger` | `Sweep2ClubDirectLedgerSection` (merchant) and `ClubPersonalSettlementSection` | Ledger read uses `https://8120.example.test` and an in-memory transport. The open row is the parser's own yuan text. Settlement is pointed at `https://www.chengyinhub.com`, where `ReviewedAreaSwitch.payout` is closed, so the existing closed chip shows and the transport is not asked. That host is never reported as a successful request. |
| sweep-2 | `cur9-ledger-unknown` | Same two sections | The ledger payload does not parse, so the section shows its existing unavailable line and no total. The fixture draws `—`. It does not show `0` or a stand-in amount. |

## Not on the merged tree

- No existing ledger or settlement view draws an em dash for an unknown amount. A failed parse becomes the unavailable line; an empty bucket inside a parsed ledger is the parser's `¥0.00`. The non-happy fixture adds the em dash rather than a new amount style.
- The ready settlement club list stays behind `ReleaseMoneyWriteSwitch.blocks("/api/club/settlement/mine")`. This branch does not install `testDerivation` and does not open payout on `www.chengyinhub.com`, so that list is not shown.
- `OwnerDecisionFixtureHost` stays removed.
- XCUITests (`Cur9VisualBugsFixtureTests`, `Cur9OfflineFixtureTests`, `Cur9SweepFixtureTests`) each launch one `--design-fixture` and only read the screen. They were not run on this VM.

## Gates

- `python3 tools/generate_project.py`
- `python3 tools/check_design_fixture_release_exclusion.py --write`, then the check without `--write`
- `python3 tools/check_scaffold.py` PASS
- `python3 tools/check_design_lint.py` PASS
- `swiftc` / `xcodebuild` / XCUITest were not run.
