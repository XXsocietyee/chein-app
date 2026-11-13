# Integration batch: mount-g45, E2E R-fixes, g-partials + parity-a + parity-b + fixtures-g (2026-11-13)

Integrator branch `integ/next`, pushed to `ui/next` and `ui/main` (fast-forward only).

## Merged

| Branch | Head | Notes |
| --- | --- | --- |
| `ui/mount-g45` | `b554d161c` | G4+G5 with view mounts (pushed earlier as `d041b834d`) |
| `ui/parity-a` | `ba26398e3` | contains `ui/g-partials` `6adbae522` (G1 + G7/G8 + partial rows) |
| `ui/fixtures-g` | `b42635c49` | contains `ui/parity-b` `f1adac9e9` |

Unions: the player-write lease (`playPaths` from an array, so a repeated path is harmless; `capabilityReadPaths`,
`playRuntimeReadPaths`) and the China owner grants (`socialRoamOwnerGrant`, `playRuntimeOwnerGrant`,
`playerGapOwnerGrant`, `playerParityBOwnerGrant`). `api/registration/scan_group_member_ticket` is ticket verification and
is in no money list. `d7.imFile.readFailed` keeps the 10 MB server limit (channels contract item 13).
The G7/G8 view `MerchantCityNodeRow` was renamed `MerchantCityNodeFavoriteRow` (it collided with the Core model).

## Owner items

- **TEAM backpack command grant: DONE.** `POST api/game/session/command` is in the player lease (`playPaths`). The China
  capability already wired it. Covered by the composition test.
- **TODO (Cursor) — TEAM backpack command UI.** `App/PlayTeamBackpackView.swift` still draws no buttons for the TEAM commands
  (item use/discard/receive, quest actions, trade open/confirm/cancel). Needed: a command client that sends
  `api/game/session/command` with the mini-program bodies (`utils/game-session-client.js:395`, `pages/play/utils/theme-backpack.js:494`),
  reads the receipt (`api/game/session/receipt`) with a retained request id, and buttons in `PlayTeamBackpackSections`
  (`content(snapshot)`), refreshing through `reload()`. Grant and admission are already in place.
- **TODO (Cursor) — team create.** `SessionTeamCreateView` (`App/SessionTeamViews.swift:29`) is still not reachable.
  Needed: (1) an `AppSession` extension accessor (new file; the `AppSession.swift` line ratchet is at its ceiling) that
  exposes `teamJournal`, `orderLifecycleService` and `currentTeamSession` narrowly; (2) a team write lease for
  `POST api/team/create` (live and wired in the China capability) in the player grant; (3) compose `TeamHTTPService` with the
  owned registration's `OrderLifecycleTeamSource` in `makeTeamCoordinator(creationSource:)` for the approved branch (today
  it has no `creationLoader`); (4) mount `SessionTeamCreateView` from the order detail when `teamOpen` holds
  (activity registration, status 2, not completed, `teamMode` 1 or 2; mini-program `scene-member-order-detail.startOrderTeam`);
  (5) a composition test that the create is admitted and money stays closed.
- **TODO (Cursor) — U08-02 finish-route card.** The card view and its mount already exist
  (`App/PlayExperienceView.swift:339`, `PlayFinishRouteCardView`); the session path passes no `finishRouteModel`.
  Needed: (1) a production `PlayFinishRouteReading` that reads `api/activity/list` around the origin coordinate
  (`Core/PlayFinishRouteRecommendation.swift:32`, fields as decoded there); (2) the `finishNearbyRoute` flag from
  `LaunchFeatureFlagsReader.load` (`api/config/features` is already admitted for players); (3) build
  `PlayFinishRouteRecommendationCoordinator(featureEnabled:reader:currentActivityID:currentTopicID:sourceRunID:)` in
  `SessionPlayRuntimeView` once the flag is known and pass it with a detail destination.

## Verification

See the batch report (build, gates, Core and AppUnit suites, core UITests).
