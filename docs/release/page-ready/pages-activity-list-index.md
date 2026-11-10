# pages/activity/list/index

Native screen `App/OfficialEventsBrowserView.swift` (map status exists). This lane did not edit views.

Already on `rc/20261108`: `OfficialEventService` GET `events`, `myEvents`, and `canPublish` through `OfficialSessionReader`; empty copy on `OfficialEventBrowseQuery`; DEBUG fixture `OfficialEventSyntheticFixtures`; tests `OfficialEventTests`, `OfficialEventBrowseStateViewTests`, and `test_official_event_contracts.py`.

Added `OfficialActivityListPage` / `OfficialActivityListCoordinator` in `Core/OfficialEventContracts.swift`. Phases are loading, empty, error, unknown, and ready. Unknown counts are an em dash (`—`); a known zero stays `0`. The publish link stays hidden unless `canPublish` is true. Strings and accessibility identifiers: `docs/release/ui-strings-pages-activity-list-index.json`. New test: `testActivityListPageStatesKeepUnknownCountsAsEmDash`.

Left: the browser still draws `OfficialReadScreen` and does not read this model. No route was added. Xcode was not run.
