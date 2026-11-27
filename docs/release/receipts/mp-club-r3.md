# Receipt — mp-club (round 3, 2026-11-27)

Branch `mp/r3-club` from `origin/ui/combined-r7`. Scope: tab 俱乐部 (`pages/talent/list/index`) and the `pages/club/*` subpackage, player side (club owners and admins are players; merchant features left alone). The MP source is `origin/mp-source:chengyinhub-xcx`. Nothing was deployed.

The 21 MP pages were compared section by section, top to bottom, against their native screens. Two pages (talent/list, club/detail) were read in full by hand. The other 19 were split across three read-only diff passes, and each reported difference was then checked in code before it was fixed or skipped.

## Gates (last run, on head of branch)

| Gate | Result |
|---|---|
| `python3 tools/generate_project.py` | OK |
| `python3 tools/check_scaffold.py` | PASS (no FAIL lines; typography lint PASS) |
| `python3 -B tools/check_a11y_lint.py` | PASS: 0 new |
| `python3 -B tools/contract_ratchet.py --check` | 104 failing, baseline 104, **new 0**, fixed 0 |

There is no Swift compiler in this environment. Edits are kept type-simple and reuse existing keys, components and patterns.

## Table: MP page → native view → differences → fixed?

| MP page | Native view | Difference (MP ref) | Status |
|---|---|---|---|
| talent/list | `App/ClubHomeView.swift` | The page title is 「发现」 (wxml:19, owner 2026-10-29); native showed 俱乐部. The tab bar item stays 俱乐部 (components/tabBar). This was left as an "owner decision" in fix-r11 A8-06, but the MP answers it. | **Fixed.** `cyRootHeader(.club, titleKey: "club.tab.title")` (new optional `titleKey` on `cyRootHeader`) |
| talent/list · 帖文 | `ClubCommunityFeedView` | A guest's feed is 「登录后查看帖文」 + 登录, not a load failure (wxml:39). Native showed 加载失败 + retry. | **Fixed.** `onSignIn` is passed from ClubHomeView and the view shows a `ContentUnavailableView` with a sign-in button |
| talent/list · 俱乐部 | `ClubHomeView` list | Order matches: 创建俱乐部 → created → joined → nearby; empty, skeleton and error states match. The native inline 加入 pill on nearby rows is not on the MP `cy-club-card`. | Order: matches. Pill: **not changed** (deliberate earlier native addition; flagged for the owner) |
| club/detail · header | `ClubDetailView.swift` `ClubDetailHeader` | The MP header ends at the meta rows (type · N 名成员 / 入会方式). Native added a 「主理人 X · 城市」 line that the MP puts on 概览 (wxml:227-243). | **Fixed.** The host line was removed from the header (also matches the P17 identity header) |
| club/detail · 概览 | `ClubDetailView` overview | The facts grid 主理人 / 俱乐部类型 / 所在城市 under the intro, before 俱乐部勋章, was missing. | **Fixed.** New `ClubOverviewFacts`: 3 cells, value then small label, with a `ViewThatFits` fallback to `LabeledContent` rows (P12). Unknown values read 待补充 |
| club/detail · 帖文 | `ClubCommunityFeedView` (club mode) | MP order is pinned notice → 发帖 pill → posts/empty (wxml:97-158), with the pill above the empty state. Native used a toolbar compose button and put the empty state before the pinned notice. | **Fixed.** Inline composer row (「有什么新鲜好玩的分享吗？」, same gate, same id `club.community.compose`); the empty state now comes after the pill |
| club/detail · 帖文 loading | same | MP: `loading-label` 正在加载帖文. Native showed a bare spinner (P10). | **Fixed.** `ProgressView { Text("club.community.loading") }` |
| club/detail · 活动 | `ClubPublicActivityListView` / `ClubActivityListContent` | Matches: cards, 已报名/节点/路线 stats, 发布 +, empty + 发布主题, 出示团码, 邀约承接. | Matches |
| club/detail · tabs / default | `Core/ClubDetailTabs.swift` | Matches: 帖文 / 活动 / 概览 (+管理), default 概览. | Matches |
| club/detail · join | `ClubActionPanel` | MP: a floating 加入 capsule only on 概览 (wxml:1028-1036), with 退出 in the meta row. Native: a 成员身份 section under the header on every tab. | **Not done.** large (panel lifecycle, contract pins). P17 sticky bottom action is the natural fix |
| club/detail · 概览 chat rows | `ClubDetailView` | The MP removed 进入群聊 from the club page (wxml:83). Native keeps chat / IM / channel rows on 概览. | **Not changed.** Earlier decision CLB-detail-14; flagged |
| club/topic-detail | `ClubGovernanceViews.swift` topicOverview | 未通过原因 must come before 核销 + 台账 (wxml:86 vs 96). | **Fixed** |
| club/topic-detail | same | 接下来 only when there are sessions (wxml:134); native showed a 还没有场次 placeholder. | **Fixed.** The section is hidden unless there are sessions or 管理场次 is allowed |
| club/topic-detail · 更多 | same | MP order (wxml:430-470): 剧情与玩法 → 结束活动 → 核销记录 → 场次管理 → 退出与暂停规则. Native was missing 剧情与玩法 and 核销记录, had 结束活动 last, and had stats/settings/enrollment first. | **Fixed.** MP order; stats/settings/enrollment follow as a second group |
| club/topic-detail | same | Hide 核销/主题/接下来 when the director is active and the topic ended (wxml:94); per-session 团码/run-control/集合时间 rows (MP has one director row); inline settings block in 更多; rules as a footbar half-sheet. | **Not done.** large / behaviour moves |
| club/topic-story | `ClubGovernanceStoryView`, `ClubStoryViews.swift` | Empty states are already title-only (detail is ignored). Missing-param 链接已失效 + 返回; "no answer" chip; templateUnavailable text; answer-sheet title joins the node name. | **Not done.** small, next round |
| club/badges | `ClubBadgeManagementView.swift` | Matches: list, 全部勋章 · N 枚, create, grant picker, states. | Matches |
| club/apply | `ClubGovernanceCommandForm` (hostApply) | Submit must read 成为俱乐部主理人 / 提交中… (wxml:164-165); native read 提交申请. | **Fixed** (existing keys `settings.becomeClubHost`, `gap.club.coopPool.submitting`) |
| club/apply | same | Extra 上一步 button; extra required-fields footer; 状态 row on the done card; done-state loading/error + 可建俱乐部 row. | **Not done** (the done state is large) |
| club/create | `ClubOperationsViews.swift` | 返回上一页 was missing on the no-permission and limit states (wxml:23, 27). | **Fixed.** Secondary `Button("team.page.goBack") { dismiss() }` |
| club/create | same | Extra step checklist on the intro; media above the step header on step 3; extra 上一步; 返回上一页 on the check-failed state. | **Not done.** Step 3 order is large; the rest are small, next round |
| club/enroll | `ClubEnrollmentView.swift` | The stale inline error's action should read 重试更新 (wxml:20). | **Fixed** (`club.enroll.retryUpdate`, also added to `ClubEnrollmentLocalizations.fragment.json`) |
| club/enroll | same | Extra escrow line (pinned by `test_club_member_pages`); the refresh row sits above the sub line; the summary is three rows instead of one line; the ticket count comes from the rows instead of `tk.signups`. | **Not done** |
| club/checkin-detail | `ClubCheckinRailView` via `ClubGovernanceViews` | The server `errorText` should be the missing title / denied sub-line (wxml:13-16); native dropped it on the loaded path. | **Fixed.** `reason: failure?.message` |
| club/checkin-detail | same | Extra 已退款 note on the rail. | Not done (small) |
| club/group-code | `ClubGovernanceCommandForm` (issueGroupCode) | The no-permission exit should be 进入俱乐部管理 (goManage → detail tab=manage); native just dismissed. | **Fixed.** Reuses `ClubGroupCodeMissingLinkView.manageDestination` |
| club/join-requests | `ClubManagementView.swift` | Loading should read 正在加载入会申请 (wxml:11); the empty state is the title only (wxml:20). | **Fixed** (`club.joinRequests.loading`) |
| club/join-requests | `MPReviewedPageScreen.swift` | A link without `clubId` should show the missing-param state with 返回 (wxml:12). | **Fixed.** `MemberMissingLinkState` |
| club/join-requests | same | Native rows push a detail page and 通过/拒绝 go through a review sheet; the MP does both in one tap. | **Not done.** large |
| club/roles | `ClubOpsGovernanceSections.swift` | The owner row is name + 主理人 only; there is no footer line (wxml:23-45). | **Fixed** |
| club/roles | same | No members → full-page 暂无成员. | Not done (small) |
| club/settlement | `ClubGovernanceViews.swift` settlement | The direct ledger is for the owner only (`summary.isOwner`, wxml:9). | **Fixed** |
| club/settlement | same | MP order puts the 已入账 card after the funds stages. The native funds section also carries the withdraw button that the MP shows under the card, so moving the card would split card and button (and `test_club_ops_customer` pins card-before-funds). | **Kept** (reason given) |
| club/event-ops | `ClubOpsEventView.swift` | With no topics and no series, the MP hides 重复方式 (wxml:178). | **Fixed** |
| club/event-ops | same | Inline 日期清单 and 重复方式 forms instead of push rows; 返回 on no-permission; 本场名册 · N 人 as a section title. | **Not done.** large / small |
| club/notify | `ClubGovernanceCommandForm` (sendNotification) | Full-page 当前身份不能发通知; inline 受众预览失败 + 重试; 投递状态 section with 刷新 in the header; extra review fact rows. | **Not done** (send-button wording is a deliberate CLB-notify-01 choice) |
| club/governance | `ClubOpsBanSection` | Full-page 暂无可治理成员; extra appeal-mode headline. | Not done (small) |
| club/customers | `ClubOpsCustomerViews.swift` | The count line sits as the list section header after the filter (native pattern; the count follows the filter); the filtered-empty CTA is outside the empty state. | **Kept** / not done |
| club/customer-detail | `ClubOpsCustomerViews.swift` | In edit mode the header should read 编辑标签与备注, with 取消 in the header. | Not done (small) |
| club/payout-receiver | `ClubPayoutReceiverView.swift` | Binding needs a WeChat code (`PayoutReceiverBridge.payoutOpen`). | Blocked (WeChat/backend), not a view gap |
| club/edit | `ClubOperationsViews.swift` | 改为转让主理人 is only inside the dissolve confirm in the MP; native shows a permanent row. The key is localized (`改为转让主理人` has en). | Not done |
| club/workbench | `MPReviewedPageScreen.swift` redirect | MP error state 没能进入俱乐部管理 + 重试进入 + 返回俱乐部. | Not done (small) |

## P17 (club home order) where the MP allows

- Identity header: cover, logo + name, 「类型 · N 名成员 · 入会方式」, a face pile with +N, and 邀请成员 for owner/admin. The host/city line moved to 概览, so the header now reads like P17's identity header.
- "Next event card with countdown" and "pinned poll" between the header and the feed: the MP has neither on the club page. It has tabs, with 活动 as its own tab, so nothing was added.
- "Sticky primary action at the bottom": the MP has the floating 加入 capsule on 概览, which native does not have yet (listed above as not done). This is the top candidate for the next round.

## Strings added (en + zh-Hans)

Fragment `docs/port/strings/mp-club-r3.json` and `Resources/Localizable.xcstrings`:

| Key | en | zh-Hans |
|---|---|---|
| `club.community.composerPrompt` | Anything fun to share? | 有什么新鲜好玩的分享吗？ |
| `club.community.signInToView` | Sign in to see posts | 登录后查看帖文 |
| `club.topic.more.story` | Story & play | 剧情与玩法 |
| `club.topic.more.ledger` | Check-in records | 核销记录 |
| `club.enroll.retryUpdate` | Try updating again | 重试更新 |
| `club.joinRequests.loading` | Loading join requests | 正在加载入会申请 |

## Contract test pins updated (with reason)

- `test_community_media_integration.test_club_public_entry_is_outside_governance`: the ClubHomeView feed call now also passes `onSignIn` (guest 登录后查看帖文). The public, non-governance entry it guards is unchanged.
- `test_club_detail_page_ready`: comment only. The pending key is now used by `ClubOverviewFacts` on 概览, not the header.

## Commits

1. 概览 facts row (主理人 / 俱乐部类型 / 所在城市) and the header trim.
2. 发现 title, club 帖文 composer pill + guest sign-in, topic-detail MP order.
3. Club ops pages: MP wording and gates (join-requests, enroll, checkin-detail, group-code, settlement, apply).
4. Roles, event-ops and join-requests MP states.
5. This receipt.
6. 创建俱乐部 no-permission / limit: 返回上一页.
