# pages/activity/official-organizer/index

Official organizer console. Native screen `App/OfficialOrganizerConsoleView.swift` (map status: exists). Not a player-first entry.

Already on `rc/20261108`: `Core/OfficialOrganizer.swift` calls the live reads `GET api/official/v2/events/{id}/publish-check`, `GET api/official/events/{id}`, `GET api/official/my-published`, and `POST api/official/command`, `command/query`, `command/cancel`. `App/AppSession.swift` assigns `coordinator.organizer`. A disabled access sends nothing. `/api/official/v2/events` stays missing and hidden. No ticket, faction, settlement, or appeal route was added.

This change adds `OfficialOrganizerConsoleSnapshot` with loading, empty, error, and unknown. Unknown facts render as `—` (U+2014). A server `0` stays `"0"`. `showsPlayerEntry` is false. Omitted `risks` is unknown, not zero. DEBUG `OfficialOrganizerConsoleFixtureData` holds synthetic payloads only.

Tests added in `Tests/CoreTests/OfficialOrganizerTests.swift`: `OfficialOrganizerConsoleStateTests` and `OfficialOrganizerConsoleFixtureTests`. The ten existing organizer tests are unchanged. Strings and identifiers: `docs/release/ui-strings-pages-activity-official-organizer-index.json`.

Left: the view file was not edited, so the screen still uses its own phase and does not read the snapshot. `official.organizer.empty` and `official.organizer.unknown` are model identifiers only. `tools/current_ci_manifest.json` was not refreshed. No Xcode build was run.
