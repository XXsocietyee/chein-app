# Receipt: components r1, lane C3 kit (`comp/r1-kit`)

Brief: `origin/design/handoff-r2:docs/briefs/components-r1.md` (C3 row). Base: `origin/ui/combined-r7` @ `64a344358`.
Date: 2026-11-27. No compiler in the cloud: every API was checked by grep and by hand against the
COORDINATOR-HANDOVER §4 traps. **This needs an Xcode `build_sim` before merge.**

## Components (`App/NativeR2/Components/`): first push `2eb9766c3`

| Component | File | What it is | Apple API |
|---|---|---|---|
| `CYCountdown` | `CYCountdown.swift:8` | `init(until:)` counts down to a date and swaps to `endedKey` at the target. `init(since:)` counts up. `style` / `tint` nil inherit the caller's font and colour | `Text(timerInterval:countsDown:)`, `TimelineView(.explicit([date]))` (wakes once, at the target) |
| `CYRing` | `CYRing.swift:6` | Circular progress, default centre `42%` (`CYRingPercentLabel`, `:75`) or any view. Helpers in `CYRingMath.clamp/fraction` (`:88`) | `Circle().trim`, `.contentTransition(.numericText(value:))`, `.smooth` |
| `CYLiveCounter` | `CYLiveCounter.swift:6` | Rolling Int count. `compact` gives `1.2K` / `1.2万`. Optional signed `delta` (`+36`) in success or danger colour | `.numericText(value:)`, `.number.notation(.compactName)`, `.sign(strategy: .always())` |
| `CYStreakGrid` | `CYStreakGrid.swift:5` | Day-cell grid, oldest first. `init(activeDays:dayCount:endingOn:)` builds it from dates. Also `dayFlags`, `currentStreak` | `Grid` / `GridRow` |
| `CYWaveform` | `CYWaveform.swift:6` | Bar waveform. `progress` tints the played part. `isLive` animates the bars. `placeholderLevels(count:seed:)` gives a fixed shape for audio that has no levels | `TimelineView(.animation(minimumInterval:))` |
| `CYStatPill` | `CYStatPill.swift:5` | Capsule with an SF Symbol and a value: a text value, or a `count:` that uses `CYLiveCounter` | `Image(systemName:)`, `Capsule` |
| `CYJoinCountdownRow` | `CYJoinCountdownRow.swift:6` | Row reading "距开始 3:51 · 加入". Shows "进行中" once the event starts, and "已加入" with a check after joining | `.borderedProminent` + `.capsule`, 44 pt minimum height |

Shared modifiers: `CYOptionalTextStyle` / `CYOptionalForeground` (`CYCountdown.swift:68,81`) and `CYOptionalAccessibilityLabel` (`CYLiveCounter.swift:66`).

Every component has the following:
- A `#Preview` using the player-dark theme.
- Dynamic Type through `.cyText` and `@ScaledMetric`.
- Reduce Motion support: no roll or ring animation, and no live waveform movement.
- One VoiceOver element with a label and value. `CYWaveform` is the exception: it is decorative, and the player control beside it carries the label.
- Colours from `CYColor` tokens only, with no hex values.

Strings: 8 keys, `comp.kit.*`, in zh-Hans and en. The fragment is `docs/port/strings/comp-r1-kit.json` and is already merged into `Resources/Localizable.xcstrings`.

## Adoption pass

| Where | File | Change | MP reference |
|---|---|---|---|
| Official event card and detail facts | `App/OfficialEventComponents.swift` (`OfficialCountdownText`, `OfficialEvent.countdownTarget`), `App/OfficialEventDetailView.swift` (`OfficialDetailFactsStrip.countdownTarget`) | Under one hour, "距开始/距结束 N 分钟" becomes a live mm:ss `CYCountdown`, switching to 即将开始/即将结束 at zero. Spans of an hour or more keep the source's rounded units. `.unknown` and every test path are unchanged: the new `target` parameter defaults to nil | `pages/activity/official-detail/index.js` `_countdown` / `_dur` |
| Activity list card | `App/ActivityPresentationComponents.swift` (`ActivityPresentation.imminentStart`, `stateLabel`) | The "即将开始" chip shows "距开始 mm:ss" when the start is within an hour. It uses the same date parse as `E1ActivityState.of` | `pages/activity/list` status badge |
| Passport stamp count | `App/PassportView.swift` (`PassportRollingCount`) | The hand-rolled numericText is replaced by `CYLiveCounter(style: .dataXL)`. The em dash for an unknown count is unchanged | passport header |
| Free exploration "已核销环" | `App/FreeExplorationViews.swift` | `Gauge(.accessoryCircularCapacity)` is replaced by `CYRing` with a `done/total` centre. It stays hidden from VoiceOver, and the combined "已核销 n/m" label is unchanged | MP 已核销环 |

Not adopted, left on purpose:
- **Game HUD (C4), run panel (C6), and channel/community like and unread counters (C5).** Those lanes own the files. The components are on this branch for them to adopt.
- **Wallet.** Its figures are formatted money strings, not Int counts.
- **Club stats.** These are text `LabeledContent` rows, matching the MP.
- **Streak grid on roam history.** The MP history page has no streak block, so adding one there would not be parity. C2 uses it in the widget.
- **List collective bar "全城已点亮".** It stays a linear bar, as in the MP `oe-bar`.

## Gates (run before each push)

- `check_scaffold.py`: PASS (structural checks; 19702 bilingual keys).
- `check_a11y_lint.py`: PASS, 0 new.
- `check_typography_lint.py` and `check_design_lint.py`: PASS.
- `contract_ratchet.py --check`: **new 0**. The command still exits 1, because one baseline entry now passes: `test_profile_read_failure_remote_admission…test_raw_creator_positive_contract_is_independent_of_all_history`. That test is unrelated to this lane (no profile files were touched), so I did not touch the baseline. The coordinator can run `--update`.
- `check_swift_syntax.py`: not run. Its tree-sitter wheel is pinned to CPython 3.12, which is not this container's Python.

## For the coordinator

- No capabilities or profiles are needed for C3. The App Group is C2's job.
- Run `build_sim`. These are the spots most likely to fail to compile:
  - `CYRing` generic init plus the `where Center == CYRingPercentLabel` extension init.
  - `TimelineView(.explicit([date]))`.
  - `Text(delta, format: .number.sign(strategy: .always()))`.
  - The `@ViewBuilder` `stateLabel` switch in `ActivityListCard` (it was `return Label…`).
