# ui/cur-team-u0802

Handover 27. Parent `d041b834dd7f048f94f186ef78259decb28f4bed` (`origin/ui/main`). `docs/release/receipts/integ-batch-g-partials.md` is not on that commit, so this receipt follows the handover text.

`App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` are unchanged. `docs/release/contract-failing-baseline.txt` is unchanged. `moneyPayments`, payout, merchant writes, and password login stay off for `www.chengyinhub.com`.

Swift was not compiled on this Linux VM. Screenshots were not taken.

## 1. TEAM command UI

`PlayTeamBackpackView` is a separate screen from the personal backpack. It loads `GET api/game/session/view` (`perspective=PLAYER`) and shows loading, empty, error, and a command receipt.

Buttons send only `ITEM_USE`, `ITEM_DISCARD`, and `ITEM_RECEIVE` through `POST api/game/session/command`, matching `utils/game-session-client.js` `submitAction` and `pages/play/utils/theme-backpack.js` `_themeGameplayCommand`. Other game commands are not built and are refused by the body check.

An APPLIED receipt with a matching terminal (`receiptId` > 0 and a revision) is the only success. PENDING, a mismatched receipt, a transport failure, or a missing field is unknown: the outcome, receipt, and revision render as an em dash (`U+2014`), and the row is not marked success. A business failure shows the safe server message or the failed label, still not success.

The play screen links here when the activity scope can build the client. The finish-route card mount is unchanged.

## 2. Team create

`AppSession.teamCreateCoordinator(registrationID:)` lives in `App/SessionTeamCreateComposition.swift`. It builds `TeamHTTPService` with a creation loader that re-reads that registration and returns `teamCreationSource` only when the owner matches.

`POST api/team/create` is on the player team grant. The body must be `ownerType` 2, `ownerId`, `maxMembers` 2...4, and optional `joinMode` 1. Money fields and other keys are refused.

`SessionTeamCreateView` always shows `TeamCreateView`. The order detail shows "Create a team" when `teamOpen` is true (owner type 2, registration status 2, team mode 1 or 2, and the order is not completed). Mode 2 is still the only creation source.

When the write lease is closed, the review button stays visible. Tapping it records `team.writesDisabled` / `.notSent` and does not call the transport. `TeamHTTPService.submit` also returns `.notSent` before the network when approval is missing. A closed lease never sends `api/team/create`.

## 3. U08-02 card

`ProductionPlayFinishRouteReader` reads `POST api/activity/list` (`is_my=0`, `sort_type=1`, page 1, five rows, longitude, latitude) from the completed-node origin. It does not sample device location.

`SessionPlayRuntimeView` loads `finishNearbyRoute` with `LaunchFeatureFlagsReader` (`POST api/config/features`) and builds `PlayFinishRouteRecommendationCoordinator` there. The card uses the existing `PlayExperienceView` mount (`finishRouteModel?.card`). There is no second mount. The flag off, a refused read, or an empty page leaves the card unset.

## Leases

These paths were already live in `ChinaReviewedRouteCapability` (`wiredPatternCount` stays 677). No catalog line was added. The player-write grant newly lists:

- `api/team/create` on the team endpoint (body allowlist above)
- `api/game/session/command` on the play endpoint (ITEM_USE / ITEM_DISCARD / ITEM_RECEIVE only)
- `api/game/session/view` and `api/game/session/receipt` as play GETs

`api/activity/list` and `api/config/features` were already readable. No unrelated contract count moved.

## Fixtures

- `playTeamBackpack` — normal team items and buttons. `--play-team-backpack=unknown` shows the same items with an unknown receipt (em dash, not success).
- `sessionTeamCreate` — open synthetic creation. `--session-team-create=closed` keeps the review button visible and sends nothing.
- `playFinishRoute` — existing finish card fixture (normal and disabled). This change does not add a second card screen.

## Checks

`python3 tools/generate_project.py` completed. `python3 tools/check_scaffold.py` passed (structural checks, bilingual catalog, appsession ratchet, page route table). `python3 tools/check_design_lint.py` passed (no new violations). `swiftc` was not run. Screenshots were not taken.
