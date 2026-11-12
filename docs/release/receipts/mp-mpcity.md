# mp-mpcity: city board (Monopoly-style) layout

Branch `ui/mpcity` (from `origin/ui/main`). Code-only: not compiled here; integrator builds.

## Finding: no mini-program source exists
`liboyang42-cpu/hengyin` `chengyinhub-xcx` (HEAD 2026-11-12) has no city Monopoly. Code search for monopoly / dafuweng / 大富翁 / 棋盘 / 地产 / city-game found nothing relevant (only bingo hits).
`pages/play/utils/play-board-view.js` is a leaderboard projector, `pages/play/circle` is the merchant-offer exploration page, `playkit-diceroll` is a plain 1-2 dice / D20 widget. So there is **no mp page -> native mapping and no parity claim**; this is an app-only feature (allowed by the owner floor rule). No coordinator answer on the source question arrived before building; if a source exists elsewhere, parity must be re-audited against it.

## What was built (layout only, on the existing W20 CITY business game logic)
| Piece | File |
|---|---|
| Turn HUD (round, action pips, die) | `App/DesignSystem/CYCityBoard.swift` `CYCityTurnHUD` |
| Die (tumble, Reduce Motion cross-fade, unknown = em dash) | `CYCityDie` |
| Ring board of city tiles, lit lantern token on held tiles, sliding selection ring (matchedGeometryEffect) | `CYCityBoardRing` |
| Closed/archived verdict | `CYCityVerdict` |
| Property card, review, unknown-outcome, notices | unchanged `CityGamePanel` rows (ids kept), selected tile shows its card |
| Mount | `PlayExperienceView.cityGameModel` (nil = hidden) -> `CityGamePanel(boardLayout: true)` in the orientation list |
| Copy | 5 new `cityGame.*` keys (EN + zh-Hans) in `Resources/CityGame.xcstrings` (added by JSON edit; `build_city_game_catalog.py` has drifted from the catalog, regenerating would drop strings, so not run; add the keys to the script when it is reconciled) |

`CityGameSlot` takes `boardLayout` (default false) so existing list UI tests keep their ids.

## Rules held
No local roll/score/RNG; no other team's token or location; paid actions still go only through the existing quote/consent review and `cityActions` gate (OFF in production: no factory, so board hidden); no mock data; no secrets.

## Needs Cursor / logic
- Die face: `CityGamePanel.boardSection` passes `face: nil` (STUB). Needs a server roll face on the ROLL_ROUND outcome/receipt in `CityGameCoordinator`.
- Production factory/endpoint for `PlayExperienceView.cityGameModel` (GetCitySnapshot not reviewed).
- Per-tile team position/other-team tokens intentionally absent (W20.17).

## MISSING (noticed, outside brief)
Not audited: the full hengyin app.json page list was not enumerated in this task.

Checks: generate_project.py, check_design_lint.py, check_scaffold.py PASS. check_swift_syntax.py could not run (parser dependency missing).
