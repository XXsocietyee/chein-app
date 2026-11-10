# PAGE-READY `pages/roam/index`

Screen `App/RoamBrowserView.swift` (map status exists). Views, `Localizable.xcstrings`, the Xcode project, test plans, and `tools/current_ci_manifest.json` were not edited. Xcode was not run.

Already on `rc/20261108`: `RoamEntryNearbyReader` for live `GET /api/roam/entry/nearby`; `RoamNearbyEventsEntryState` (`loading`, then peek `empty` / `failed` / `unavailable`); `RoamPassportOverviewState` for the local journal; `RoamScreenIssue` for map errors. A missing read stays `.unavailable`. No route was added or marked live. `ReleaseMoneyWriteSwitch` stays false. Presence sharing stays off.

Added: `RoamPassportSummary` text (`—` for UNKNOWN, `0` / `0.0` for a real zero), `RoamHomeIndexPassportPresentation` (`loading`, `empty`, `error`, `ready`), DEBUG `RoamHomeIndexFixtureData`, and `RoamPassportOverviewTests.testHomeIndexStatesKeepUnknownAsEmDashAndKnownZeroNumeric`. EN and zh-Hans keys plus accessibility identifiers are in `docs/release/ui-strings-pages-roam-index.json`.

Left: the home views still draw the dash themselves; the new presentation is not mounted. Passport tiles for goals and capsule stay listed when the private reader is nil. The home journal is still local, not `GET /api/roam/passport/summary`.
