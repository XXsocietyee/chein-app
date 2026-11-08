# UI-15 report (Club[A-L]*.swift, dark) — NOT COMPILED

Reviewed: 47 files matching `App/Club[A-L]*.swift`.
Skipped (already changed by wave 1 `cloud/ui-04` / `cloud/ui-11`): `ClubChannelMessagingView.swift`, `ClubEventCalendarView.swift`.

| file | change | theme | new keys |
|---|---|---|---|
| ClubAccessAndSettlementSectionView | raw `Color.green/orange/red` -> `CYColor.successText/warningText/dangerText` | dark | none |
| ClubActivityListContent | `Color.green` -> `CYColor.successText` | dark | none |
| ClubAndTeamCoopGovernanceSectionView | green/orange 0.15 fills -> `CYColor.successSoft/warningSoft` | dark | none |
| ClubEnrollmentView | check-in status colours -> CYColor tokens | dark | none |
| ClubGovernanceCommandForm | `.red` -> `CYColor.dangerText` | dark | none |
| ClubGovernanceViews | `.red/.green/Color.red/Color.green` -> CYColor tokens | dark | none |

Not done: no layout/state/typography rewrites (rest of files use system semantic `.secondary` and text styles; left as is per "if unsure, do not change"). Remaining 41 files reviewed and left unchanged.
New string keys: 0 (no `ui-strings-ui-15.json` needed).
