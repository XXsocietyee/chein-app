# Receipt: native-r2/flow-games-a (games, half A: shell + templates 1–3)

- Branch: `native-r2/flow-games-a`, from `origin/ui/combined-r7` (2446657fb), merged with `origin/ui/combined-r7` before each push.
- Brief: `docs/briefs/native-r2.md` on `design/handoff-r2` ("EVERYTHING native").
- Spec: `docs/design/native-r2/games.md` on `design/native-r2-games`.
- Status: **held until owner approval** (step 3). Not merged into any `ui/*` branch by this lane.
- Gates: `python3 tools/generate_project.py` then `python3 tools/check_scaffold.py` → `PASS structural checks`. No compiler in the cloud, so every type, modifier and init was checked by grep against the repo and the iOS 17 deployment target (`Config/Base.xcconfig`).

## What is new

All new UI is behind `NativeR2Flags.games` (default `true`, `App/NativeR2/NativeR2Flags.swift`). Turning it off restores the previous kit UI unchanged.

| File | What it holds |
|---|---|
| `App/NativeR2/Games/NativeGameShell.swift` | **The shared shell for both halves.** `NativeGameShell` = optional `NavigationStack` → `List(.insetGrouped)`; inline title; toolbar close (sheet) + hint (`lightbulb`) button; `ProgressView` for multi-question kits; kit controls; wrong reply as a red `Label` under the controls; inline result section; one `.borderedProminent` `.controlSize(.large)` button in a bottom `safeAreaInset` bar; fresh-result sheet with `.presentationDetents([.medium])`, retry (`.bordered`) and continue (`.borderedProminent`). Embedded style (story page) has no List/toolbar. Also `NativeGameSubmit`, `NativeGameProgress`, `NativeGameResultActions`, the `nativeGameHelp` environment value and `NativeGamePermissionView` (`ContentUnavailableView` + Open Settings). |
| `App/NativeR2/Games/NativeGameHintSheet.swift` | Hint ladder as a native `List` sheet (`.medium`/`.large`): rows as `LabeledContent`, free count in the footer, use/skip confirmed with `.confirmationDialog`, receipt in a `DisclosureGroup`. Same `PlayHelpLadderModel` calls and offline opt-in routes as `PlayHelpLadderPanel`. |
| `App/NativeR2/Games/NativeGameScreenHost.swift` | `PlayKitScreen` → shell wiring: title 「第 N 关 · 玩法」 (`stage.ordinal`; kit name alone when unknown), header/status sections, kit dispatch, bottom-bar action, result rules. `NativeGameKits.templateA` lists this lane's kits; `templateB` is the empty hook for half B. |
| `App/NativeR2/Games/NativeGameAnswerKits.swift` | Template 1: qa (type / pick text / pick picture / letter pool / shot), predict, estimate, pricepair, diyname, note, profile. |
| `App/NativeR2/Games/NativeGameSortKits.swift` | Template 2: sort, classify, match, bingo, silentorder; plus walk and slowtask (template 3, screen-held state). |
| `App/NativeR2/Games/NativeGameTimedKit.swift` | Template 3 timing: reaction, stopwatch, countdown, typein. |
| `App/NativeR2/Games/NativeGameSensorKit.swift` | Template 3 sensors: compass, ballshake, shout, quiethold. |

Small edits outside the new folder:
- `App/PlayKitScreen.swift`: native state (`nativeResultShown`, drafts, child action), `dismiss`/`stage`/`offlineWriteSession` made internal for the extension, `screenContainer` routes to `nativeGameContainer` when `usesNativeGame`, the chrome modifier skips its title/close in native mode, the review is always its own sheet in native mode, `clearTransient` resets the native state.
- `App/PlayExperienceView.swift`: sets `\.nativeGameHelp` (same model, team pool, hosts and pool-trim refresh as the existing hint sheet) so the shell's hint button works.
- `tools/generate_project.py`: compiles `App/NativeR2/**/*.swift`.
- Strings: 25 keys in `docs/port/strings/native-r2-games-a.json`, merged into `Resources/Localizable.xcstrings` with `tools/merge_localization_fragments.py`.

## Logic kept identical

- Every write still goes `prepare` → `PlayKitActionReview` → `model.submit` with the same action names and payloads (`SUBMIT_QA`, `SUBMIT_PREDICT`, `SUBMIT_ESTIMATE`, `SUBMIT_PRICE_PAIR`, `SUBMIT_DIY_NAME`, `SUBMIT_NOTE`, `SUBMIT_PROFILE`, `SUBMIT_SORT/MATCH/CLASSIFY`, `START_/CLAIM_SLOW_TASK`, `START_CHALLENGE`, `SUBMIT_REACTION/STOPWATCH/COUNTDOWN/TYPE_IN`, `SUBMIT_BALL_SHAKE/QUIET_HOLD/COMPASS/SHOUT`).
- Validation stays in `PlayKitInputContract`; timing and sensor runs use the same Core machines (`PlayKitTimingRun`, `PlayKitReactionRun`, `PlayKitSensorStageModel`, `PlayKitQuietRun`, `PlayKitBallRun`, `PlayKitCompassRun`, `PlayKitShoutRun`), the same 20 ms ticker, revision guards and interruption rules.
- Result labels follow `PlayGameOutcome` / `PlayKitNoRightAnswer` / `reasoningFeedback` exactly; continue uses `PlayGameOutcome.showsContinue`; retry is offered only for `notPassed` while the game is still open.
- steps and timewindow keep their existing host views (`NativeStepsHostView`, `NativeTimeWindowHostView`), which were already system controls; they now sit in a shell `Section`.
- accessibilityIdentifiers kept: `playkit.screen.*`, `playkit.submit.*`, `playkit.qa.wrongReply`, `playkit.challenge.start/measure/submit`, `playkit.reaction.target`, `playkit.sensor.*`, `playkit.estimate.result/wheel`, `playkit.type.result`, `playkit.reasoning.result`, `playkit.story.continue`, `playkit.close`, `playkit.review.confirm`, `playkit.triesLeft`, `playkit.profile.*`, `playkit.bingo.*`, `playkit.walk.remaining`, `playkit.slowTask.*`, `playHelp.*`.

## Closest Apple control where the MP has none (noted per the brief)

- **Bottom bar for child kits.** Timed and sensor kits publish their primary action (start → stop → submit; calibrate → start → submit) to the shell's single bottom button. The reaction tap target stays inline as one large `.borderedProminent` button (it is the game, not a submit).
- **Countdown** keeps today's rule: no server instant, so the clock shows "—" and does not finish from the device clock (unchanged from `PlayKitTimedChallengeView`).
- **Stopwatch/typein clock** is a large rounded monospaced `Text`; the hand-drawn ring is gone.
- **Ball shake**: one `circle.fill` SF Symbol on a plain `.quaternary` fill (spec open question 1).
- **Compass**: `location.north.fill` rotated + `Gauge(.accessoryCircularCapacity)` for the hold; the drawn dial and ticks are gone.
- **Scratch card (slowtask)** dropped: the unlock text shows as `Text` after claim.
- **Counters** ("n/16", "n/40") dropped from fields; the binding still enforces the limit (brief: no counters drawn by us).
- **Sort** uses system drag handles (`List` in edit mode + `.onMove`) with VoiceOver move up/down actions.
- **Classify**: one section per bin plus 未分类, a menu `Picker` per row, swipe to take back.
- **Bingo**: 3×3 `LazyVGrid` of `.bordered` buttons; a tap opens a popover (sheet on iPhone) explaining the cell.

## Not done in this lane / follow-ups

- Templates 4–6 (camera, chance, story choice) and hidden / blindtaste: half B (`NativeGameKits.templateB`).
- Letter-pool qa keeps the existing `PlayKitQuestionLetterPoolView` (with its own submit) inside a shell section.
- `PlayKitScreen`'s review sheet confirm button and the leave-with-unsaved-answer dialog still use the old `.questifyPrimary` / `cyModalConfirm`; spec wants `.borderedProminent` / `.confirmationDialog`.
- "跳过这一站" in the permission view is not wired (skip lives in the hint sheet).
- `CYScreenOfflineWriteBanner` is reused as is inside the status section (shared component, owned elsewhere).
- Needs a real build: please run `build_sim` on the coordinator machine; nothing here was compiled.
