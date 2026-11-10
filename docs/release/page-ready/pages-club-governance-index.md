# pages/club/governance/index

CB247 page-ready on `rc/20261108`. Map status stays `partial` on `App/ClubOpsGovernanceSections.swift`. This lane does not edit a view, a string catalog, or the Xcode project.

`ClubOpsGovernancePage` in `Core/ClubOpsGovernancePresentation.swift` wires the existing reads `.bans` (`api/club/governance/list`), `.cases` (`api/club/governance/cases/mine`), and `.members` (`api/club/members`). `routeMarkedLive` is false. No route was added. `includedInPlayerFirstEntry` is false, and appeal or report mode does not read the member-governance lists. A missing grant stays hidden and does not call the reader.

Loading, empty, error, unknown, and ready are separate. Unknown, null, a numeric string, and a non-integer display `—` and are never stored as 0. A literal JSON 0 stays `0`. A missing appeal fact stays hidden rather than 0. A known absence of an active ban is 0.

Tests: `testGovernancePageStaysHiddenWithoutCapabilityAndOffPlayerEntry`, `testGovernancePageLoadingEmptyReadyAndLiteralZero`, `testGovernanceUnknownCountsAreEmDashNeverZero`, and `testGovernanceLoadUsesExistingReadsAndHidesADeniedGrant` in `Tests/CoreTests/ClubOpsGovernancePageTests.swift`. `test_governance_page_states_stay_off_player_entry` in `Tests/ContractChecks/test_club_governance_page_ready.py`. DEBUG-only `ClubOpsGovernancePageFixtureData`.

## Missing EN and zh-Hans keys

These copy keys are not in `Resources/ClubOpsGovernance.xcstrings` or `Resources/Localizable.xcstrings`. Catalogs were not edited. Existing keys used by the page (`clubOpsGov.failed`, `clubOpsGov.retry`, `clubOpsGov.bans.empty`, `clubOpsGov.cases.empty`, `clubOpsGov.members.empty`, `clubOpsGov.appeal.empty`, `clubOpsGov.denied.title`, `clubOpsGov.denied.body`, `club.gov.bans`, `club.gov.cases`) already have both languages.

| Key | EN | zh-Hans |
|---|---|---|
| `clubOpsGov.page.loading` | Loading governance | 正在加载治理记录 |
| `clubOpsGov.page.empty` | Nothing to review | 暂无治理内容 |
| `clubOpsGov.page.unknown` | Governance figures are unavailable | 治理数字暂未返回 |
| `clubOpsGov.count.bans` | Bans | 封禁记录 |
| `clubOpsGov.count.cases` | Cases | 工单 |
| `clubOpsGov.count.members` | Members | 可治理成员 |
| `clubOpsGov.count.activeBan` | Active ban | 生效封禁 |

Left: `App/ClubOpsGovernanceSections.swift` still draws the section lists and does not read `ClubOpsGovernancePage`. Production writes stay gated. Map status stays partial. Xcode was not run.
