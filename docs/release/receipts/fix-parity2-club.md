# Receipt: fix-parity2-club (parity r2, area = club)

- Brief: `origin/design/handoff-r2:docs/briefs/fix-parity-r2.md`
- Findings: `origin/audit/parity-club:docs/audit/parity/club.md`; round 1: `docs/release/receipts/fix-parity-club.md`
- Branch: `fix/parity2-club`, from `origin/ui/combined-r5` @ 65eb1def4
- Swift is not installed in the cloud. Nothing here was compiled or run on a simulator. Every change copies an existing pattern (`cyPageTitle`, `CYEmptyState`, `CYSheetHeader`, `CYAvatarView`, `CYPillButtonStyle`, `.cyText`); the local verifier's build is the first compile.

## Gates

| gate | result |
|---|---|
| `python3 -B tools/check_scaffold.py` | PASS |
| `python3 -B tools/check_design_lint.py` | PASS. Typography: raw text style 1173, Theme.Font 63, raw size 67, back chevron 12, hidden back 7, large title 11, all equal to the base. No baseline file edited. |
| `python3 -B tools/contract_ratchet.py --check` | Final full run: the only failure outside the baseline is the base one below. Two branch regressions found in that run were fixed in place (governance fragment key count; `docs/community-media-templates/catalogs/ClubCommunity.xcstrings` now carries 暂无帖文). The base already had one failure outside the baseline: `test_workshop_paid_professional…test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging`, which is not a club test. |
| `python3 -B tools/report_chrome.py` (club files) | Only "keep" items and fixture hosts remain in club files (calendar pager, apply wizard 上一步, `ClubFixtureSupport` / `ClubGovernanceFixtureHost` / `ClubOperationsFixtureSupport` DEBUG hosts). Channel files are untouched (channel follows the Flutter app). |

## Round-1 P0s still open (step 1)

| id | status | why / what is needed |
|---|---|---|
| CLB-detail-03 (follow, link share) | deferred | Follow is still on the author's profile. A link share needs a club universal link, which does not exist yet. |
| CLB-detail-07 邀约承接 | deferred | Needs a native route to `topic/merchantinfo?topicId=&scope=MERCHANT`. The merchant project view is only reachable from the merchant workspace. |
| CLB-detail-08 扫码核销 | deferred | Needs a club-scoped verification workflow. `NativeVerificationWorkflow` is merchant-scoped. |
| CLB-detail-09 活动导演台 | deferred | Needs the project → session list on the 管理 tab. |
| CLB-detail-10 coop pool | deferred | Not started. |
| CLB-detail-11 带票分享 | blocked-platform | Unchanged from r1. This needs an iOS attribution path; see Backend needed. |
| CLB-detail-12 带上一次游玩记录 | deferred | The read exists (`PlayerJourneyService` → `api/registration/my-joined`). The write goes through the dormant original-post family (`api/club/post/operation/create`), whose pending-record identity hashes `content` and `images`. Adding `refType` / `refId` to it changes the idempotency identity, the review and the receipt matching. That is too risky to do without a compiler, so it is left for a local pass. |
| CLB-topic-detail-02 / -03 | deferred | Rejected → 修改并重新提交 needs a native topic editor by id. Director sections are not embedded. |
| CLB-settlement-02 | deferred | The FE reference settlement is a money write. It stays out per the owner rule (money is TEST-only). |
| CLB-payout-receiver-01 | blocked (owner decision) | Unchanged. |

## P1 fixed in this round

| id | status | files | local verification |
|---|---|---|---|
| CLB-governance-13 / CLB-topic-detail-08 / X1 (governance reads) | fixed | App/ClubGovernanceViews.swift | Any governance read (治理记录, 客户, 客户详情, 核销详情, 结算, 通知成员, 活动详情): the page-type title is the inline bar title. There is no 34 pt hero in the content. |
| X3 / CLB-notify-03 / CLB-customers-04 / CLB-checkin-detail-03 (stacking) / CLB-topic-detail-09 (partial) | fixed | App/ClubGovernanceViews.swift, App/ClubOpsCustomerViews.swift, App/ClubOpsJoinNotifyViews.swift, App/ClubOpsGovernanceSections.swift | Fixture `customerDenied`: one block with 当前岗位没有客户查看权限 and its detail, no generic line, no 刷新. Notify without permission: only the notify denial. Bans/members/roles denied: only the page note. Any other failure: one block (title, server sentence, 重试). The `club.gov.error` id stays on the reason line. |
| CLB-topic-story-07 | fixed | App/ClubGovernanceViews.swift, Localizable + ClubStoryLocalizations.fragment (`club.story.failed`) | 剧情与玩法: inline title. Failure → 剧情与玩法无法打开 + 重试. No standing 刷新 pill; pull to refresh works. |
| (events hub) | fixed | App/ClubGovernanceViews.swift | `ClubGovernanceEventView`: inline title 活动. |
| CLB-badges-01 / -05 / -06 / -07 | fixed | App/ClubBadgeManagementView.swift, ClubBadge.xcstrings | 俱乐部勋章: inline title; a 全部勋章 · N 枚 header; pull to refresh (no toolbar 刷新). List error reads 勋章列表没加载成功, refresh error 列表没刷新成功. The grant confirm reads 把「X」颁给 Y？ and never shows a member id. |
| CLB-event-ops-04 / -07 | fixed | App/ClubOpsEventView.swift, Localizable, ClubGovernanceLocalizations.fragment, tools/build_club_governance_catalog.py | 活动运营: inline title, no 168 pt art, and the page inherits the workspace domain (no forced dark). The cancel row has no consequence subtitle. The pushed titles read 本场管理 / 本场名册 / 重复方式. |
| CLB-join-requests-01 (title only) / -02 / -03 | partial | App/ClubManagementView.swift | 俱乐部管理: inline title. Each request row shows the join message (3 lines) and 拒绝 / 通过 pills (44 pt, 12 pt apart). Both open the existing review; swipe still works. **Left:** the owner member list still sits on this page (moving it changes the r1 UI tests). |
| CLB-governance-02 / CLB-roles-08 | fixed | App/ClubGovernanceViews.swift | Roles: 撤销 is a red inline action (44 pt), not a full-width pill. Member governance: 封禁 / 转让主理人 are the same. 解封 is unchanged. |
| CLB-governance-07 | fixed | App/ClubOpsGovernanceSections.swift, ClubOpsGovernance.xcstrings | The count rows read 共 N 条记录 / 共 N 名成员 / 共 N 条工单, never a lone number. |
| CLB-governance-08 / CLB-roles-06 | fixed | ClubOpsGovernance.xcstrings, App/ClubOpsGovernanceSections.swift | Denied: 当前身份不能管理成员 · 仅主理人和管理员可用 (roles: 当前身份不能管理角色 · 仅主理人可分配角色), with a 返回 button. |
| CLB-governance-09 | fixed | App/ClubGovernanceCommandForm.swift | 我的平台工单 → 提交平台举报 inside a club: only the 事实 field. Type and id are anchored to the club (draft default CLUB + clubId, as before). |
| CLB-governance-10 | fixed | App/ClubOpsGovernanceSections.swift, ClubOpsGovernance.xcstrings | No active ban: 当前没有可申诉的封禁 + 仅限期封禁可申诉. |
| CLB-governance-15 | fixed | App/ClubOpsGovernanceSections.swift | 请提交可核实的事实 appears once, in the form. |
| CLB-customers-02 / CLB-customer-detail-02 | fixed | Core/ClubOpsCustomerPresentation.swift (`avatar`), App/ClubOpsCustomerViews.swift | Customer rows and the detail head show the customer's avatar (`CYAvatarView`, HTTPS only). If there is none: initial / generated art. The backend already sends `avatar` (`ClubCrmAppServiceImpl` rows and summary). |
| CLB-customer-detail-06 | fixed | App/ClubOpsCustomerViews.swift | 最近互动 M月D日 no longer repeats the remark. The backend has no `lastInteractionText`, so the client date line stays. |
| CLB-checkin-detail-05 | fixed | App/ClubCheckinRailView.swift | Check-in head: the person is on the left and the status on the right. At AX sizes the person comes first. |
| CLB-detail-33 | fixed | App/ClubMembersView.swift | 成员 sheet: `CYSheetHeader` title (22 pt). ✕ stays in the toolbar. |
| CLB-detail-28 | fixed | App/ClubReadScreen.swift (opt-in `usesClubPageStates`, default off), App/ClubDetailView.swift, Localizable `club.detail.signIn` | Signed out on a club: 登录后查看俱乐部 + 登录. Dissolved or closed club (business rejection with a sentence): the server sentence + 返回. Other readers of `ClubReadScreen` are unchanged. |
| CLB-detail-29 | fixed | App/ClubMemberWelcomeSheet.swift, ClubMemberWelcome.xcstrings | Join an open club: 欢迎加入「name」. The items are 发帖文和大家聊 / 报名俱乐部的局 (· 成员优先报名) / 认识成员、攒贡献. Two exits (去看活动, 知道了), no toolbar 关闭. |
| CLB-detail-15 | fixed | App/ClubCommunityViews.swift, Localizable | Club feed: the next page loads when the end of the list scrolls in (no 下一页). No standing 刷新; 重试 only when nothing loaded. Empty: 暂无帖文 (+ 入会后可发布 for viewers who cannot post). |
| X1 sweep (other pushed club pages) | fixed | App/ClubDirectoryView.swift, ClubStatsOverviewView.swift, ClubLeadProgressView.swift, ClubTerminalSessionView.swift, ClubEventCalendarView.swift | 查找俱乐部, 我创建的俱乐部, 数据概况, 带队进度, 现场, 俱乐部活动 calendar: inline bar titles, no hero headers. |
| CLB-apply-03 | fixed | App/ClubGovernanceCommandForm.swift, Localizable `club.host.submit` | 成为主理人 step 4: the button reads 提交申请 and submits directly (prepare then confirm). The fact review shows only if the submit could not finish. |
| CLB-apply-08 (bootstrap error) | partial | Core/ClubOpsJoinNotifyPresentation.swift, ClubOpsGovernance.xcstrings, Tests/CoreTests/ClubOpsGovernancePresentationTests.swift | Host-status read failure: 主理人资格未确认 + 重新检查. **Left:** the guest copy 登录后申请成为主理人. |
| CLB-create-05 / CLB-edit-04 | fixed | App/ClubOperationsViews.swift, Localizable `club.ops.placeholder.*`, `club.ops.createDescription` | Create and edit fields: a persistent label above each field (* on 名称 / 城市) and the MP placeholder as the prompt. Create's description label is 一句话介绍（选填）. |
| CLB-edit-02 (copy) | partial | App/ClubOperationsViews.swift, Localizable | Edit → 危险操作 section; footer: 成员将失去俱乐部与群聊入口，已报名不会自动退款。 **Left:** 改为转让主理人 in the consequence sheet. |
| CLB-notify-02 | fixed | App/ClubGovernanceViews.swift (`localizesEnums`, review only), App/ClubGovernanceCommandForm.swift, Localizable `club.gov.choice.IN_APP/AVAILABLE/UNAVAILABLE` (not added to the governance fragment, whose key count is pinned) | 通知成员 review: 全体成员 / 站内通知 / 可用 / 暂不可用 instead of ALL_MEMBERS / IN_APP / AVAILABLE. Read pages keep their values (a UI test reads EVENT_CHECKIN on roles). |

## Not reached (deferred)

topic-detail 05/06/07/10/11/13 (structure, 更多 sheet, director, 报名参与者), topic-story 02–05, event-ops 02/03/05/06, governance-01/03/04/12, roles-04/07, apply-02/04/05/06/07, create-02/03/04/06, edit-01/05/06, enroll-02/04, badges-02/04, notify-01/04/05/06, settlement-03..07, customer-detail-03/04/05, checkin-detail-04 (the 报名编号 row is the UI-test arrival signal), join-requests-05/06, group-code-02..06, workbench-03/04, detail-14/21/22/26/27/30/35, all P2.

## Backend needed

- Unchanged from r1: `POST /api/club/post/create` should require owner / admin / `club:content:manage` for `type == 2`.
- 带票分享 (CLB-detail-11): no backend change; this needs an iOS attribution path.
- CLB-customer-detail-06: if the MP line 「最近互动…」 should be server-rendered, `POST /api/club/crm/customers/detail` needs `summary.lastInteractionText` (the MP binds it, but `ClubCustomerVO.Summary` has no such field today).

## Shared changes outside club-only files (minimal)

- `App/ClubReadScreen.swift` (also used by the profile and roam reads): a new `usesClubPageStates` parameter, default `false`, so other callers do not change.
- No DesignSystem file changed. No `tools/*_baseline.json` changed.

## Contract tests updated with the parity rulings

- `test_club_ops_governance.py`: denial copy and the appeal sub now match the MP; the revoke/ban/transfer edit calls carry `role: .inlineDestructive`.
- `test_club_ops_event.py`: the hub asserts the inline `navigationTitle` instead of `CYHeroHeader`.
- `test_club_ops_join_notify.py`: `ClubOpsPageFailureSection(copy:reason:)`.
- `test_club_leaderboard_member_navigation.py`: the byte pin of the span starting at `if operation == .customers {` runs into `bodyNavigation` and was re-hashed. The customer filter rows inside it are unchanged.
