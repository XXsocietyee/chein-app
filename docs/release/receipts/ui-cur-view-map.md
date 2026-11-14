# ui-cur-view-map

Inventory of SwiftUI `View` structs on `ui/main` against the 14 page templates in `docs/design/mp-design-system.md` section 5. Docs only. No restyle.

**Base SHA:** `5ba7b0f2c5f10dea10905895da947c350b3e24ac` (`origin/ui/main`).

**Design-doc SHA:** `0b4ca1c3` (`0b4ca1c356c6f99d4fc4b15a5b842351521a6bef` on `origin/docs/mp-design-system`). Section 5 was read from that commit. The design document was not copied onto this branch.

**Map scope:** `App/` on this `ui/main` tree only. One row per SwiftUI `View` struct, including small, private, and section views. Screens that exist only on unmerged branches are not included.

**Rows:** 3242.

| template_id | rows |
|---:|---:|
| 1 | 3 |
| 2 | 7 |
| 3 | 6 |
| 4 | 14 |
| 5 | 21 |
| 6 | 18 |
| 7 | 19 |
| 8 | 17 |
| 9 | 6 |
| 10 | 17 |
| 11 | 8 |
| 12 | 25 |
| 13 | 15 |
| 14 | 11 |
| unmapped | 3055 |

Unmapped is 3055. A view is unmapped when it is a control, banner, modifier, editor control, or other fragment that is not itself one of the 14 page structures. Routes are only paths already written in that Swift file (a comment next to the type, or the file header on the file's own screen). Unknown routes stay an em dash.

**Swift:** no Swift file was edited. No Swift file was added. `generate_project.py` was not run.

**Checks:** `python3 tools/check_scaffold.py` passed (structural checks; the script does not compile Swift). `python3 tools/check_design_lint.py` passed (1633 App Swift files outside DesignSystem and Theme; allowlist unchanged). This receipt does not claim a Swift compile.
