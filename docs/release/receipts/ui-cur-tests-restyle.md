# Receipt: `ui/cur-tests-restyle`

The restyle branches changed which control owns each accessibility identifier. Identifier strings stayed the same. XCUITest and Maestro queries now use the control that is on screen. No flow was deleted. No screen was added. No restyle. XCUITest and Maestro were not run.

`RegionalLaunchConfiguration`, `AppSession`, `AppCompositionRoot`, and `docs/release/contract-failing-baseline.txt` were not edited. Money switches stay closed on `www.chengyinhub.com`. `ReviewedAreaSwitch` was not redeclared. `OwnerDecisionFixtureHost.swift` and `OwnerDecisionPayoutViews.swift` were not re-added.

Every Maestro file edited below was already on `origin/ui/h-e2e-ids` (`25db611f6292cf1dbcc68a2ac33faf9d2cb28927`). No Maestro file from outside that branch was edited.

## Identifier moves

| Surface | Old place | New place | Identifier |
|---|---|---|---|
| Global search result kind | Unused `kindPicker` segment text | Chip button inside `searchMap.resultKinds` | `searchMap.kind.activity`, `searchMap.kind.merchant` (and the other `searchMap.kind.<rawValue>` chips). Strings unchanged. |
| Club top tabs | `UISegmentedControl` | `CYTabs` segmented buttons | `clubTab.topTabs` unchanged |
| Official event buckets | Treated as segmented segments | `CYFilterChip` buttons inside the filter row | `official.filter` unchanged |
| Growth issue retry | Standalone button | Action button inside the `growth.issue` empty state | `growth.retry` unchanged. Parent `growth.issue` unchanged. |
| Home mini games | Direct banner tap | Menu item. Open `homeIndex.actionBanner.menu` first | `homeIndex.actionBanner.mini_games` unchanged |

## Tests and flows

| File | Old identifier | New identifier |
|---|---|---|
| `Tests/AppUITests/SearchMapFlowTests.swift` | `searchMap.kind.merchant` on a global button | `searchMap.kind.merchant` on the chip inside `searchMap.resultKinds` |
| `Tests/AppUITests/ClubTabTopTabsFlowTests.swift` | `clubTab.topTabs` as `segmentedControls` | `clubTab.topTabs` as the `CYTabs` container. Button labels 俱乐部 / 帖文 unchanged |
| `Tests/AppUITests/OfficialEventFlowTests.swift` | Bucket titles as global buttons under `official.filter` | Same titles as chip buttons inside `official.filter` |
| `Tests/AppUITests/ProfileSelfGrowthFlowTests.swift` | `growth.retry` | `growth.retry` inside `growth.issue` |
| `Tests/AppUITests/GrowthBadgeStampParityFlowTests.swift` | `growth.retry` | `growth.retry` inside `growth.issue` |
| `e2e/maestro/search-filters.yaml` | `searchMap.kind.activity` | `searchMap.kind.activity` (chip under `searchMap.resultKinds`) |
| `e2e/maestro/external-game.yaml` | `homeIndex.actionBanner.mini_games` | `homeIndex.actionBanner.mini_games` after `homeIndex.actionBanner.menu` |

## Checks

`python3 tools/check_scaffold.py` PASS. `python3 tools/check_design_lint.py` PASS. `swiftc`, XCUITest, and Maestro were not run, and they are not claimed to have passed.
