# UI-CUR-WP-06 receipt

Handover 35, WP-06 only. Base is `ui/main` `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46`. Source of the twelve rows is the WP-06 section of `docs/release/completeness-missing.md` at `e1969026e9469669e165937013e0e4f5c61b4252` (not the base). Branch pushed: `cursor/ui-cur-wp-06-c9c1`. `ui/main`, `ui/next`, `main`, `master`, `rc`, `production`, and `hengyin` were not pushed.

`docs/release/completeness-matrix.csv` is not on `ui/main`. It was not imported. Row status is listed here.

## Checks

- `python3 tools/check_scaffold.py`: pass
- `python3 tools/check_design_lint.py`: pass
- `swiftc`: absent on this machine. `swiftc -parse` did not run. No typecheck and no XCTest run was invented.
- `docs/release/contract-failing-baseline.txt`: not edited
- `App/RegionalLaunchConfiguration.swift`, `App/AppSession.swift`, and `App/AppCompositionRoot.swift`: not edited
- `ReviewedAreaSwitch`: not redeclared. Coupon publish and stop are admitted only when `ReviewedAreaSwitch.merchantWrites(apiHost:)` is true, the method is POST, and the body is a non-empty JSON object. That switch is false on `www.chengyinhub.com`.
- `api/roam/share/snapshot` is in `ChinaReviewedRouteCapability.wp06PartialPagesOwnerGrant` (it was already `.liveInProduction`). It is not named in `App/ReviewedPlayerWriteLeases.swift` because BK E06-17 forbids a new consumer of that literal there. `WP06RoamHistoryClient` calls the existing history and share readers.

## Rows

All twelve page-map rows are `exists`. None are still missing.

| Row | Status | What closed the gap |
|---|---|---|
| PAGE-pages/address/address | exists | List, empty, error, and an unknown total (`—`) already go through `ProfileParticipantListCoordinator`. Dedicated participant transport keeps the address calls. Hosted recovery suites were not re-run; this machine has no iOS 27 simulator. |
| PAGE-pages/publish/simple/index | exists | `QuickPublishSimpleJourneyService.confirmAndSeed` checks the title, at least one stop, and a name plus a map place on every stop, then calls `professionalSeed`. `QuickPublishSimplePageCoordinator` reads home and AI quota. Loading, empty, error, and an unknown quota (`—`) stay on the form. |
| PAGE-subpackageMember/complaint/index | exists | `ProfileComplaintPreparationLink` installs `WP06ComplaintWrite`. The report is POST `api/coop/complaint/report` with a body. The reader-only initializer still leaves `submitter` nil. Topics and progress keep loading, empty, and error. Other cooperation writes stay closed. |
| PAGE-subpackageMember/couponInfo/couponInfo | exists | The editor already shows loading, empty, and error. There is no `/api/coupon/update` contract, so `saveEnabled` stays false. Publish and stop stay behind `merchantWrites` and stay closed on `www.chengyinhub.com`. |
| PAGE-subpackageMember/invoice-apply/index | exists | Recover already accepts an original apply when `titleId`, `matches(command)`, and `applicationID` agree. `ExactID` reads the string `11`. Payment stays off (`routeMarkedLive = false`, `paymentEnabled = false`). |
| PAGE-subpackageP3/pages/stamp-album/index/index | exists | Album screen stays in `App/RoamStampViews.swift`. Hosted lifetime suites were not re-run (no iOS 27 simulator). |
| PAGE-subpackageP3/pages/stamp-camera/index/index | exists | Camera, denied state, and create upload stay in `App/RoamStampCameraView.swift`. String catalog `mapStatus` is `exists`. Hosted lifetime suites were not re-run. |
| PAGE-subpackageRoam/citystamp/index | exists | Three-step flow stays in `App/RoamSubpageParityViews.swift`. Hosted lifetime suites were not re-run. |
| PAGE-subpackageRoam/history/index | exists | `App/RoamHistoryViews.swift` was not edited (byte-frozen). `WP06RoamHistoryClient` drives `history()` and the share snapshot. The hosted test opens `RoamHistoryView`. Loading, empty, and error are already on that screen. |
| PAGE-subpackageTools/anniversary/index | exists | `RoamAnniversaryView` already shows loading, empty, and error. Hosted hub suites were not re-run. |
| PAGE-subpackageTools/exploration-export/index | exists | `RoamExplorationExportView` already shows loading, empty, and error. Hosted recovery suites were not re-run. |
| PAGE-subpackageTools/monthly-recap/index | exists | `RoamMonthlyRecapView` already shows loading, empty, and error. Hosted hub suites were not re-run. |

`Tests/AppUnitTests/WP06PartialPageHostTests.swift` opens all twelve screens in a `UIHostingController` and calls the history client. It was not executed.

Strings for the quick-publish status live in `Resources/WP06PartialPages.xcstrings` (`en` and `zh-Hans`). Unknown quota text is `—`.

## Tip and PR

Filled in the follow-up commit after push.
