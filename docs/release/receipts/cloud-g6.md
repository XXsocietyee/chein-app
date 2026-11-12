# cloud-g6 side-quest player entry

Base `origin/ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`. Branch `ui/cloud-g6-sidequest`. Money stays off. No production payload was added.

## Source

hengyin `chengyinhub-xcx` at `1c80c5aea8f721ca8575e6108048495b100f5576`. `app.json` at that commit registers `pages/searchmap/index` and does not register a side-quest page. The tree has no side-quest page path. `city_sidequest_observation` is a merchant-game template seed, not a player page. No page, route, or `/api/side-quests` client was added to stand in for a page that is not there.

## Shipped

| File | Role |
|---|---|
| `Core/SideQuestPlayerFlow.swift` | Closed production snapshot, unrestricted discovery filter, start/answer/cancel gate |
| `App/SideQuestPlayerEntry.swift` | Player entry rendered from that snapshot |
| `App/SearchMapExplorerView.swift` | Places the entry beside the search map once an area is selected |
| `Tests/CoreTests/SideQuestPlayerFlowTests.swift` | Core tests for the snapshot, filter, em dash, and gate |

`SideQuestPlayerFlow.sourcePagePresent`, `routeInstalled`, and `routeMarkedLive` are false. The search map passes `SideQuestPlayerFlow.production`, which is `sourceAbsent`: total and player status are an em dash (`—`, U+2014), rows are empty, and accept/start/answer/cancel stay hidden. A supplied read is not shown on that production snapshot.

When a caller explicitly presents a supplied read, only `UNRESTRICTED` instances inside the existing discoverable window are listed. `ONCE`, blank, lowercase, and other tokens (including `COUPON`) are omitted. A loaded read that lists nothing uses total `0`. Loading, failed, and unknown reads use an em dash. Missing capacity is an em dash. A literal capacity `0` stays `0`. Reward text is always an em dash. `addsMarkerLayer` is false. No new map pin is added.

`ReleaseMoneyWriteSwitch.paymentEnabled`, `payoutEnabled`, `withdrawalEnabled`, and `virtualGoodsEnabled` stay false. `SideQuestFeature.acceptEnabled` stays false. `perform` returns the same attempt book and does not record a choice. The recorded choice text is an em dash. A passing gate still returns `noAuthoritativeReadback` and writes nothing.

The existing map-core hub route for merchant side quests stays blocked. This entry does not open it.

## Checks

`python3 tools/generate_project.py` after the new Swift files. `python3 tools/check_scaffold.py` before push. Swift is not installed in this environment, so `swift test` was not run.
