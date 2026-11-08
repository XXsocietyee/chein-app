# UI-16 report — Club[M-Z]*.swift (dark, player) — NOT COMPILED

Files reviewed: 66 (`App/Club[M-Z]*.swift`). Wave-1/other `cloud/ui-*` branches touch none of them.

| file | change | follows |
|---|---|---|
| App/ClubOperationsViews.swift | counter colour `Color.red/Color.secondary` -> `CYColor.dangerText/CYColor.textSecondary` | CYColor tokens |
| App/ClubSettlementDetail.swift | status capsule `Color.green/Color.secondary` -> `CYColor.successSoft/CYColor.textSecondary` | CYColor tokens |

Skipped: ClubPublicRosterView.swift (uses existing `Theme.Generated` token lookup, not raw colours); ClubPostDiscussion.swift:192 (1pt hidden accessibility fixture text, not visible UI); the other 62 files had no raw colours/fonts and were left as-is (no broad rewrites, per "if unsure, do not change").

New string keys: none (`docs/release/ui-strings-ui-16.json` = `[]`).
Could not do: compile or screenshot (no Swift toolchain).
