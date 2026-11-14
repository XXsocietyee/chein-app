# Receipt: `ui/cur-t8` — Template 8 lists, directories, inboxes, and records

- **Branch**: `ui/cur-t8`
- **Base**: `origin/ui/main` (`5ba7b0f2c5f10dea10905895da947c350b3e24ac`)
- **Cut from**: `origin/ui/h-design-v1` at `5d652cc08ac5ccc668db315fc57253b909b9e058` (that branch was not moved)
- **Spec read, not copied**: `DESIGN.md` and `design/tokens.yaml` on `origin/docs/design-md` at `b9193733e6539da09f016d134465b00c53a82317`. The 29 routes are template 8 in `docs/design/mp-design-system.md` on `origin/docs/mp-design-system` at `0b4ca1c356c6f99d4fc4b15a5b842351521a6bef` (DESIGN.md section 5 row 8 only names representatives and the count).
- **Restyled**: 28 existing screens. **Missing routes**: none. **Left as already compliant**: invoice detail (status chip already leads the card).
- **Not merged**: `ui/cur-t1-2`, `ui/cur-t7-14`, `ui/cur-l10n-qa`.
- **Not edited**: `HomeFeedView.swift`, `HomeSearchTabParityViews.swift`, `SquareBrowserView.swift`, `DiscoveryTemplateBrowserView.swift`, `ClubHomeView.swift`, profile shell, settings, chat, map, `RegionalLaunchConfiguration`, `AppSession`, `AppCompositionRoot`, contract baseline. No `ReviewedAreaSwitch` redeclaration. No `OwnerDecisionFixtureHost`. No new network call. No new Swift file.

Shared pieces already on this branch: `CYFilterChip`, `CYStatusChip`, `CYEmptyState`, `CYLoadingState`, `CYLoadingStateView`, `CYStateLayout` / `CYStateKind`, `CYPillButton`, `.cyDomainCard`, `.cyDomainScreen`, `CYTypography`, `CYSpacing`, `CYRadius.sm/md/lg/xl`. Player domain is dark. Creator “my project” stays on the light studio domain it already used. Purple is not added. Cards are borderless. Unknown values stay an em dash. Copy keys are existing; no new labels.

Orders, ticket wallet, and favorites are template 5 / 7 in the same audit, not these 29 routes, so they were not restyled.

## Screens

| Screen | Mini-program route | Sections (source order) | Components |
| --- | --- | --- | --- |
| `OfficialEventsBrowserView` | `pages/activity/list/index` | Search (hidden on 我的), chip tabs, summary links, list or empty | `CYFilterChip`, existing `CYEmptyState` sparkles, `.cyDomainScreen(.player)` |
| `OfficialInboxView` | `pages/activity/official-inbox/index` | Status, title, time, paused note | `CYStatusChip` first, wrapping title |
| `OfficialPublishedView` | `pages/activity/official-mine/index` | Broadcast status then title; event status then title and city | `CYStatusChip` first |
| `CreatorContentProjectsView` card | `subpackageA/pages/myproject/index` | State, type, title | `CYStatusChip`, `.cyDomainCard(lg)`. Tabs and identifiers unchanged. Studio domain kept. |
| `SocialPlayGuideView` | `subpackageA/pages/infomation/infomation` | Page title, guide rows, template section | `.cyDomainPageBackground()` |
| `SocialInformationView` art | `subpackageA/pages/infomationdetail/infomationdetail` | Cover, then the existing document | Elevated fill, text-style icon. No fixed 56 pt font. |
| `VideoBountyView` | `subpackageA/pages/video-bounty/index` | Status, platform, URL, window, note, attribution | `CYStatusChip` first, `.cyDomainScreen(.player)`. Accruals stay recorded; payout stays off. |
| `ClubBadgeManagementView` | `pages/club/badges/index` | Existing list, empty, error | `.cyDomainScreen(.player)` on the list |
| `ClubOpsCustomerRowView` | `pages/club/customers/index` | Remark badge, name, meta, sub | `CYStatusChip` before the name. Em dash initial when unnamed. |
| `ClubOpsCustomerMetricTile` | `pages/club/customer-detail/index` | Metric value then label | `.cyDomainCard(md)`, no stroke |
| `ClubManagementView` list | `pages/club/join-requests/index` | Existing request sections | `.cyDomainScreen(.player)` on the list |
| Roles members empty | `pages/club/roles/index` | Members empty | `CYEmptyState` (`clubOpsGov.members.empty`). Denied state left as it was. |
| `ClubCheckinRailView` head | `pages/club/checkin-detail/index` | Status, then identity | Order only. Governance file not rewritten. |
| `ClubOpsSettlementViews` summary | `pages/club/settlement/index` | Amount, then the existing breakdown | `.cyDomainCard(xl)`. Unknown stays the existing em dash. |
| `ParticipationHistoryView` | `subpackageMember/mycanyu/mycanyu` | Filter, rows or empty | `CYEmptyState` kind `.orders`, `.cyDomainScreen(.player)` |
| `ParticipationIssueView` | `subpackageMember/mycanyuinfo/mycanyuinfo` | Title, detail, retry | `CYStateLayout`: not configured = offline, failed = failure, sign-in = generic |
| `SocialInviteHistoryView` | `subpackageMember/myinvite/myinvite` | Nickname, reward, existing rows | Wrapping nickname, secondary pill fill |
| `TemplateAuthoringMineView` | `subpackageMember/mytemplate/mytemplate` | Existing workshop list | `.cyDomainScreen(.player)` only |
| `AccountCollectionCouponsView` | `subpackageMember/coupon-wallet/index` | Status, title, dates, empty / filtered empty | `.cyDomainCard(lg)`, `CYEmptyState` `.orders` / `.search` |
| `ProfileWeeklyPointsSection` | `subpackageMember/points-history/index` | Loading, offline, sign-in, changed, failed, then ledger | `CYLoadingState`, `CYEmptyState`, `CYStateKind`. Profile shell not edited. |
| `SquareReportProgressView` | `subpackageMember/report-mine/index` | Stage, title, time, number | Token capsule using the report string table, wrapping title |
| `MemberReportProgressDetailView` | `subpackageMember/report-detail/index` | Stage, title, number, time | `CYStatusChip` first |
| `MemberScoreAppealRowLabel` | `subpackageMember/appeal-mine/index` | Status, icon, copy | `MemberScoreStatusChip` first |
| `InvoiceLaunchHistoryView` | `subpackageMember/invoice/index` | Status, title, date, amount, tax | `CYStatusChip` first, wrapping title, em dash when the title is empty |
| `InvoiceLaunchDetailView` | `subpackageMember/invoice-detail/index` | Status already first | No layout edit this pass |
| `InvoiceLaunchTitlesView` | `subpackageMember/invoice-titles/index` | Name, then the existing title fields | Wrapping name, em dash when empty |
| `RoamHistoryView` | `subpackageRoam/history/index` | Live entry, summary, runs, detail | `RoamExperienceCard` instead of the stroked night card. Live-entry branch order unchanged. |
| `NearbyTeamsView` | `subpackageRoam/my-teams/index` | Notice, then team card and its status action | `.cyDomainCard` on the notice and the team card. One action per status. |
| `OfficialRouteListView` / `OfficialRouteCard` | `subpackageRoam/official-routes/index` | Status, city, name, distance | Borderless `CYRadius.lg` card, status first, empty city is an em dash. Offline (`URLError` not connected / connection lost) is separate from failed and empty. `.cyDomainScreen(.player)`. |

## Fixtures (existing DEBUG hosts)

- `e1-official-empty` — official activity list, empty reader.
- `e1-routes-empty` — official route list, empty reader.
- `coupons-empty` — coupon wallet, empty collection scenario.
- `cur3-video-bounty-empty` — video bounty submissions and accruals ready and empty.

## Checks

- `python3 tools/check_design_lint.py` — pass (allowlist entry for the removed fixed font in `SocialGuideViews.swift` dropped).
- `python3 tools/check_scaffold.py` — pass.
- Source contracts for the touched screens were re-run. No new failing test name was added to the baseline. The baseline file was not edited.
- Swift was not compiled (`swiftc` / `xcodebuild` not run).
