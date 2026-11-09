# UI-03 report — Player play flow (records / backpack)

**Status: NOT COMPILED.** Written without a Swift toolchain; Cursor must build and screenshot.

| Screen file | What changed | Follows | Theme | New string keys |
|---|---|---|---|---|
| `App/PlayThemeRecordsView.swift` | `CYColor.bgPage` background (list chrome hidden); rows use `CYTypography` + tertiary/secondary text, success-tinted completed icon, 44pt min row height, tabular dates/quantities; empty state -> `CYEmptyStateView` (same key); issue text uses `CYColor.dangerText` instead of `.red`; result card title `sheetTitle`, tabular value numerals. Dark + light `#Preview` (DEBUG fixture host). | mini-program `cy-theme-records` (structure unchanged); Revolut tabular numerals / strong empty state | dark (player) | none |
| `App/PlayThemeBackpackView.swift` | `CYColor.bgPage` background; unavailable / no-items / no-clues -> `CYEmptyStateView` (same keys); load, value rows and quantities in `numericBody` tabular numerals; `.red` -> `CYColor.dangerText` (failed, zero marker, review error). Dark + light `#Preview`. | mini-program backpack (structure unchanged); Revolut numerals | dark (player) | none |

All `accessibilityIdentifier`s and text keys preserved. No logic, contract, routing or Core changes. New components: none. New strings: 0 (no `ui-strings-ui-03.json` needed).

## Not done
- Topic detail, run/story/RPG screens (`ChapterStoryView`, `PlayRPGComponents`, `PlayBranchHistoryView`, etc.): not reached in this pass; left for a follow-up. Role colour scheme is enforced at the role root (UI-01), so no per-view `preferredColorScheme` was added.
- Rows in the backpack still use `copy(...)` inline strings (existing mechanism) — untouched.

## Files touched
1. App/PlayThemeRecordsView.swift
2. App/PlayThemeBackpackView.swift
3. docs/release/ui-report-ui-03.md
