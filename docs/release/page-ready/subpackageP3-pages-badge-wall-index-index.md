# PAGE-READY `subpackageP3/pages/badge-wall/index/index`

勋章墙展示页. Native screen remains `App/ObjectBadgeViews.swift` (not edited). Map status stays `exists`.

Evidence already on `rc/20261108`: `ProfileService.badgeWall` reads live `api/badge/wall-v2` and `api/medal/wall` (`Core/ChinaReviewedRouteCapability.swift`). `ProfileSessionReader.profileBadges()` is the only read. `ObjectBadgeWallOrdering.litFirst` and `ObjectBadgeWallSummary` stay as they were. `ProfileFixtureReader` and `--design-fixture d4-badges` still mount the view.

Added because the model had no unknown count: `ObjectBadgeWallPageState` in `Core/ObjectBadgeWallOrdering.swift` (loading, empty, error, unknown, plus hidden when the reader is signed out or unconfigured). Unknown counts are `—`, and a decoded zero stays `0`. `ObjectBadgeWallPageCoordinator` calls `profileBadges()` only. DEBUG-only `ObjectBadgeWallFixtureData` is the offline payload. Strings and identifiers: `docs/release/ui-strings-subpackageP3-pages-badge-wall-index-index.json`.

Tests: `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` and `Tests/ContractChecks/test_object_badge_wall_page_state.py`. No new route. Payment, payout, withdrawal, and virtual-goods flags are untouched. Swift tests were not executed here (no Swift toolchain; xcodebuild was not run).
