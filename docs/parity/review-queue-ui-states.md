# Review queue: keyboard handling, sheet presentation, fetch states (FP-M15, review queue only)

Source: `docs/parity/fix-plan.md` FP-M15 (from AN-4 P3). The AN-4 heuristic counts (148 form files, 359 sheets, 114 fetch screens)
over-count: many hits are fixture hosts or sub-views whose parent supplies the state. **No code was changed for FP-M15.** This is the
per-file review queue; each row needs a human or a follow-up fix with a device check. Counts below were taken with `grep` on this
branch (`wip/gm-fix3`) and are static, not observed on a device.

How to close a row: open the file in the simulator at the largest Dynamic Type size, with a hardware keyboard off, and tick the checks.
Add a test only if the fix changes behaviour; do not add a blanket test.

| File | Lines | Sheets / covers | `presentationDetents` | Drag indicator | Text inputs | Keyboard handling (`scrollDismissesKeyboard`, `FocusState`, `submitLabel`) | What to check |
|---|---|---|---|---|---|---|---|
| `App/ActivityEditingView.swift` | 235 | 0 | 0 | 0 | 1 | none | Form scroll dismisses keyboard; number pads have a Done control; fetch failure of the editing seed shows retry. |
| `App/ClubOperationsViews.swift` | 1071 | 2 | 0 | 0 | 1 | none | Two sheets: labelled Close in each `NavigationStack`; add `.scrollDismissesKeyboard(.interactively)` on the form; loading/empty/error per operations read. |
| `App/MerchantAuthoringView.swift` | 106 | 0 | 0 | 0 | 17 | none | Largest input count: `.submitLabel(.next)` chain and keyboard dismissal; confirm the parent supplies loading/error. |
| `App/NativeChannelMessageConversationHost.swift` (lines 89-162) | 488 | 12 | 0 | 1 (line 74) | 0 | none | Picker-style sheets (poll, location, chain, check-in): add `[.medium, .large]` detents and drag indicator; each needs a labelled Close. |
| `App/SessionHomeFeedView.swift` (lines 25-108) | 217 | 7 | 0 | 0 | 0 | none | Seven home sheets: confirm `NavigationStack` plus Close toolbar item; add detents only where content is short. |
| `App/RegistrationSheetView.swift` (lines 153-181) | 659 | 4 nested | 0 | 0 | 2 | partial (1 `scrollDismissesKeyboard`, 2 `FocusState`/`submitLabel`) | Four sheets inside a sheet: waitlist and order sheets need `.presentationDetents([.large])` and a labelled Cancel. The toolbar Close already has `action.close`. |

## Related items already handled in this wave
- FP-A4 added `.presentationDetents([.large])` and a visible drag indicator to the two `ActivityDetailView` sheets.
- AN-4 also names `ClubDetailView`, `CreatorApplicationView`, `ClubEventCalendarView`, `ClubTerminalSessionView` for missing loading, error or
  empty states. They are not in FP-M15's file list; review them with the same checklist.

## Not done, and why
- Not a defect list: a row stays open until someone looks at the screen on a device.
- No localization keys were added; any new visible string must go through the strings owner.
