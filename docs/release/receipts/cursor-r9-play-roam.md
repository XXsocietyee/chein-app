# cursor/r9-play-roam

Parent: `d9115273d70e5b88343b2a14f81d111bf515c561`. Not rebased. `origin/ui/combined-r7` was not followed if it moved.

swiftc was not run. This receipt does not claim a parse or a device run.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.
`pages/roam/index.js:5748` is `GET /api/roam/entry/nearby`. `:2833` is `POST /api/roam/nearby-runners`. `:724` is the 2026-11-14 note that a guest reads public play and a personal profile waits for login. No path was invented.

## Rows

| id | status | SHA | file:line |
|---|---|---|---|
| ROAM-7 | fixed | `83c3f2e91af6a1a33c5c06dc595ae3a87267cb44` | `App/ReviewedPlayerWriteLeases.swift:1208`, `App/ReviewedPlayerWriteLeases.swift:1220`, `App/AppCompositionRoot.swift:539`, `App/AppCompositionRoot.swift:3075`, `Core/RoamEntryNearby.swift:66`, `Core/RoamEntryNearby.swift:300`, `Core/RoamNearbyEventsEntryState.swift:10`, `App/RoamHomeTabsView.swift:159` |

Only the exact owner `Cursor Core` was taken. Claude App rows and `Cursor Core, then Claude App` were left.

## What the SHA does

- China production gates issue `RoamEntryNearbyReadAccess` and `RoamNearbyPlayersReadAccess` for player, club, and merchant. Unconfigured and gates-off stay nil. An injected closure still wins.
- A guest with no account, no role, no token, and no `Authorization` may GET the manual-centre `api/roam/entry/nearby` when the China production gates are on. Nearby runners stay a signed-in read.
- The entry reader sends that public GET when a deployment exists and no session is current. The peek loads for that guest. The login fixture keeps `allowsPublicEntry` false, so the login wall stays.

## Left off

- `giftClaim` throws `JourneyRefusal.moneyOff` at `Core/JourneyLoopSource.swift:236` and sends nothing.
- `PlayStageAnalyticsGate.enabled` stays false (`Core/PlayGameStage.swift:113`).
- Platform-pass refund-apply, cancel, and confirm throw `PlatformPassWriteRefusal.unreachable` (`Core/PlatformPass.swift:295`, `Core/PlatformPass.swift:301`, `Core/PlatformPass.swift:307`) unless a TEST derivation is on.
- Pay, payout, withdrawal, quote, registration create, and pricing confirm were not given a send.
- `App/AppSession.swift` stays 7994 lines. Its ceiling was not changed.
- `App/AppCompositionRoot.swift` is 4175 lines. The ceiling in `tools/check_appsession_ratchet.py` was lowered from 4177 to 4175. It was not raised.
- No new Swift file. `project.pbxproj` and `tools/current_ci_manifest.json` were not hand-edited and were not regenerated.
