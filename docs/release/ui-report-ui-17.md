# UI-17 report — Native[A-L]*.swift (dark) — NOT COMPILED

Reviewed: 86 files matching `App/Native[A-L]*.swift`.
Skipped (changed by wave 1, not edited): NativeChannelMessageActionSheet.swift, NativeChannelReportSheet.swift, NativeChannelTextComposer.swift (their `.red` usages left for the wave-1 owner).

| file | change | theme | new keys |
|---|---|---|---|
| NativeChannelAppealEntry, NativeChannelMentionEntry, NativeChannelModerationEntry, NativeChannelRoleEntry, NativeConditionAuthorFieldForm, NativeConditionAuthorView | raw `.foregroundStyle(.red)` -> `CYColor.dangerText` (AA contrast, dark/light values) | dark | none |

Files already clean (system text styles, semantic `.secondary`, Dynamic Type safe, ids kept): all other owned files; no change.
Not done: NativeAuthorPresentation `Color(uiColor: .systemGroupedBackground)` and NativeChannelHistoryView `.tertiarySystemFill` left as system semantic colours; NativeAttributeAuthorViews:373 builds a data-driven colour from user RGB (not a theme colour). Wider restructuring skipped: cannot compile, "if unsure, do not change".
Files touched: 6 (+ report, strings json). New component files: 0. New string keys: 0.
