# Receipt · components r1 · C4 games (`comp/r1-games`)

Brief: `origin/design/handoff-r2:docs/briefs/components-r1.md` (lane C4). Base: `origin/ui/combined-r7` @ `64a344358`.
No compiler in the cloud: every API was grepped against existing app usage (`Text(timerInterval:)` in
`RegistrationSheetView.swift:775`, `.fill.tertiary` in `ClubHomeView.swift:315`, `.symbolEffect(.bounce, value:)`,
`.contentTransition(.numericText(value:))` in the shell). **Needs a coordinator `build_sim`.**

## What was added

| Component | File:line | What it does |
|---|---|---|
| `NativeGameHUDModel` | `App/NativeR2/Games/NativeGameHUD.swift:14` | Server values only: score / points, tries left of cap, uncapped attempts, hint layers revealed / total, question progress. `hints(_:)` reads `PlayHelpLadderModel.rows` (`.review` = revealed). |
| `NativeGameHUD` | `NativeGameHUD.swift:42` | One row of stat pills (`ViewThatFits` → vertical at large Dynamic Type) + thin `ProgressView` for multi-question kits. Container a11y label 「游戏状态」. |
| `NativeGameStatPill` | `NativeGameHUD.swift:96` | SF Symbol + caption + value; `.numericText` roll (off under Reduce Motion or `-nativeR2.motion NO`); VoiceOver "label, value". Local stand-in for C3 `CYStatPill`. |
| `NativeGameCountdownClock` | `NativeGameHUD.swift:142` | `Text(timerInterval:countsDown:true)` over `ProgressView(timerInterval:countsDown:true)`; display only. |
| `NativeGameRewardBadge` | `NativeGameHUD.swift:171` | Result-sheet reward moment: badge springs in + one ripple ring + symbol bounce on a pass. Static under Reduce Motion / flag off. |
| Preview | `NativeGameHUD.swift:212` | HUD, countdown, badge. |

## Where adopted (every game type: all kits draw through the one shell)

- `NativeGameShell.swift:74` new `hud:` init param (default empty, source-compatible); `:128` / `:167` the HUD replaces the old bare progress bar in list and embedded styles; `:180` `liveHUD` merges host values + progress + hint ladder; `:294` result header uses `NativeGameRewardBadge` (keeps the shell's existing success haptic, island and VoiceOver announcement); `:303` result sheet shows what it took (tries, hints) under the rolling score.
- `NativeGameScreenHost.swift:184` `nativeHUD` (server `score`/`points`, `maxTries`/`maxAttempts` vs `attempts`/`tries`). It replaces the former `nativeTriesRow` LabeledContent (same rules, same `playkit.triesLeft` identifier, now a pill).
- `NativeGameTimedKit.swift:153` countdown kit: once START_CHALLENGE is acknowledged the clock counts down by itself instead of showing 「—」; `:342` guard (running, valid seconds); `:372` start stamped in the existing acknowledgement closure. Finishing logic unchanged: the server still decides (`SUBMIT_COUNTDOWN` sends no number).

## MP references (`origin/mp-source:chengyinhub-xcx/`)
- `components/cy/play-header/index.wxml` — progress text + track above the game.
- `pages/playkit/components/playkit-countdown/index.{wxml,js}` — single clock, empties as time runs, server owns the finish.
- `components/cy/result-sheet/index.wxml` — success = badge pops in → ripple → check; reduced-motion variant static.

## Strings
`docs/port/strings/comp-r1-games.json` merged into `Resources/Localizable.xcstrings` (+4: `nativeGames.hud.{label,score,progress,hints}`, zh-Hans + en). Reused `playkit.triesLeft`, `playkit.attempts`, `nativeGames.progress %lld %lld`.

## C3 kit
`origin/comp/r1-kit` was not pushed when this lane ran; local `NativeGameStatPill` / `NativeGameCountdownClock` are used. Follow-up once C3 lands: swap them for `CYStatPill` / `CYCountdown` (one file, `NativeGameHUD.swift`).

## Gates
`check_scaffold.py` PASS structural checks (5205 files, 19698 keys); `check_a11y_lint.py` 0 new; `contract_ratchet.py --check` new 0 (104 failing vs baseline 105, 1 fixed elsewhere). `generate_project.py` run for the new file.

## Coordinator
- Build on simulator (no cloud compiler). No capabilities, entitlements or profiles touched by this lane.
