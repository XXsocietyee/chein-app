# K50-R7 offline states

Branch `cursor/1128-k50-r07` from `origin/ui/combined-r7`. Player screens that failed blank, or that would send a write again after it had already succeeded, now keep a cache or show an explicit offline state, and a confirmed idempotency key is not replayed. Merchant screens stay gated. No money-switch edits. `AppSession.swift` is unchanged and stays under the 7977-line cap. `RuntimeDependencyConfiguration.init` argument order stays `devices, sensors, artworkHosts`. No `String(localized:)`.

## Screens

| Screen | Change |
|---|---|
| Hint sheet (`PlayHelpLadderPanel`) | A failed hint read keeps the rows already on screen and shows the offline line. With no rows, the sheet shows the offline state and a retry. Signing out still clears the ladder. |
| Team backpack (`PlayTeamBackpackView`) | A failed reload keeps the items and pending rows and shows the existing failure row. An unknown `ITEM_USE` / `ITEM_DISCARD` / `ITEM_RECEIVE` keeps that request id; the next tap of the same action sends that id again. A definite applied, failed, refused, or business result clears it so a later action is a new request. |
| Map home search (`RoamMapHomeSheet`) | A failed search with no pins shows the search-failed state and retry. Pins from a search that did return stay, with the failed footer. |
| In-game channel (`InGameChannelToolbarButton`, `InGameChannelRowButton`) | A failed unread refresh keeps the last summary. With no summary, the control shows the offline glyph and, on the row, the offline title. Opening the channel still uses the existing error alert. |

## Queued writes

`performWriteOptIn` still queues a pre-send unreachable non-money write. If a later live send of that same idempotency key returns HTTP 2xx with JSON `code` 200, the queued copy is dropped and is not flushed. Empty 200 and `{success:true}` without `code` 200 are not treated as confirmed. Money routes are not queued and `dropConfirmedWrite` refuses them. Timeouts and connection loss stay `.waitingExplicitConfirmation` and are not auto-replayed.

## Left as they were

Participation history still keeps its snapshot on a failed refresh. Team backpack money is not on this path. Official-route passport card still hides on a failed read, matching the mini-program. Merchant center, merchant staff, and money switches are untouched. `merchantCenterEnabled` stays false in Release.

Gates on this branch: `tools/generate_project.py`, `tools/check_scaffold.py` PASS, `tools/check_a11y_lint.py` 0 new, `tools/check_design_consistency.py` PASS, `tools/check_appsession_ratchet.py` PASS (`AppSession.swift` 7976), `tools/contract_ratchet.py --check` new 0 (46 failing, baseline 46). No `xcodebuild`.
