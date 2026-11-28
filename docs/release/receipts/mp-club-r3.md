# Receipt — mp-club (round 3, 2026-11-27)

Branch `mp/r3-club` from `origin/ui/combined-r7`. Scope: tab 俱乐部 (`pages/talent/list/index`) and the `pages/club/*` subpackage, player side (club owners and admins are players; merchant features left alone). The MP source is `origin/mp-source:chengyinhub-xcx`. Nothing was deployed.

The 21 MP pages were compared section by section, top to bottom, against their native screens. Two pages (talent/list, club/detail) were read in full by hand. The other 19 were split across three read-only diff passes, and each reported difference was then checked in code before it was fixed or skipped.

## Gates (last run, on head of branch)

| Gate | Result |
|---|---|
| `python3 tools/generate_project.py` | OK |
| `python3 tools/check_scaffold.py` | PASS (no FAIL lines; typography lint PASS) |
| `python3 -B tools/check_a11y_lint.py` | PASS: 0 new |
| `python3 -B tools/contract_ratchet.py --check` | 52 failing, baseline 52 (pass 29, after merging combined-r7 93bff6dcd), **new 0**, fixed 0 |
| `python3 tools/check_design_consistency.py` | PASS |

There is no Swift compiler in this environment. Edits are kept type-simple and reuse existing keys, components and patterns.

## Table: MP page → native view → differences → fixed?

| MP page | Native view | Difference (MP ref) | Status |
|---|---|---|---|
| talent/list | `App/ClubHomeView.swift` | The page title is 「发现」 (wxml:19, owner 2026-10-29); native showed 俱乐部. The tab bar item stays 俱乐部 (components/tabBar). This was left as an "owner decision" in fix-r11 A8-06, but the MP answers it. | **Fixed.** `cyRootHeader(.club, titleKey: "club.tab.title")` (new optional `titleKey` on `cyRootHeader`) |
| talent/list · nav | `App/ClubHomeView.swift` | MP 发现 has a 消息 bell with an unread badge in the nav bar (wxml P-13). Native 发现 has 查找俱乐部 + 分享 in the toolbar; messages are reached from 我的 only, and no other tab root has a messages button. | **Already present (re-checked pass 29).** Production wraps the club tab root in `SessionMessagingToolbarEntry` (`App/QuestifyApp.swift:427`, `App/SessionMessagingEntry.swift:66`): a signed-in player gets the `bell` + `IMUnreadEntryBadge` as the first trailing toolbar item, opening `SessionMessagingHome`, the same entry as the other tab roots (hand-off r1 PL-11). Hidden for guests, like the MP. Only the offline d4 fixtures mount `ClubHomeView` without it |
| talent/list · 帖文 | `ClubCommunityFeedView` | A guest's feed is 「登录后查看帖文」 + 登录, not a load failure (wxml:39). Native showed 加载失败 + retry. | **Fixed.** `onSignIn` is passed from ClubHomeView and the view shows a `ContentUnavailableView` with a sign-in button |
| talent/list · 俱乐部 | `ClubHomeView` list | Order matches: 创建俱乐部 → created → joined → nearby; empty, skeleton and error states match. The native inline 加入 pill on nearby rows is not on the MP `cy-club-card`. | Order: matches. Pill: **not changed** (deliberate earlier native addition; flagged for the owner) |
| club/detail · header | `ClubDetailView.swift` `ClubDetailHeader` | The MP header ends at the meta rows (type · N 名成员 / 入会方式). Native added a 「主理人 X · 城市」 line that the MP puts on 概览 (wxml:227-243). | **Fixed.** The host line was removed from the header (also matches the P17 identity header) |
| club/detail · 概览 | `ClubDetailView` overview | The facts grid 主理人 / 俱乐部类型 / 所在城市 under the intro, before 俱乐部勋章, was missing. | **Fixed.** New `ClubOverviewFacts`: 3 cells, value then small label, with a `ViewThatFits` fallback to `LabeledContent` rows (P12). Unknown values read 待补充 |
| club/detail · 帖文 | `ClubCommunityFeedView` (club mode) | MP order is pinned notice → 发帖 pill → posts/empty (wxml:97-158), with the pill above the empty state. Native used a toolbar compose button and put the empty state before the pinned notice. | **Fixed.** Inline composer row (「有什么新鲜好玩的分享吗？」, same gate, same id `club.community.compose`); the empty state now comes after the pill |
| club/detail · 帖文 loading | same | MP: `loading-label` 正在加载帖文. Native showed a bare spinner (P10). | **Fixed.** `ProgressView { Text("club.community.loading") }` |
| club/detail · 帖文 公告 (`components/club-pinned-notice`, `utils/club-pinned-notice.js`) | `ClubCommunityFeedView` (club mode) | MP: section 「公告 · 新人先看」 listing the newest ≤2 pinned 公告 (type 2), each a one-line summary with an unread dot (read ids kept on this device per club, last 50), 「（无文字内容）」 when empty, VoiceOver 「未读公告：…」. Native showed only the first pinned 公告 under a 「公告」 label, no unread state, 「—」 when empty. | **Fixed (pass 6).** `ClubPinnedNoticeReads` (same storage key `cy_club_notice_read_<clubId>`, newest-first, max 2, keep 50; catalogued in `docs/ops-safety/client-data-catalog.json`); a `Section` headed 公告 · 新人先看 with one row per notice (tint dot when unread, `.quaternary` when read, chevron, 44 pt), opening marks it read |
| club/detail · 活动 | `ClubPublicActivityListView` / `ClubActivityListContent` | Matches: cards, 已报名/节点/路线 stats, 发布 +, empty + 发布主题, 出示团码, 邀约承接. | Matches |
| club/detail · tabs / default | `Core/ClubDetailTabs.swift` | Matches: 帖文 / 活动 / 概览 (+管理), default 概览. | Matches |
| club/detail · join | `ClubActionPanel` | MP: a floating 加入 capsule only on 概览 (wxml:1028-1036), with 退出 in the meta row on every tab. Native: a 成员身份 section under the header on every tab. | **Partly fixed (pass 4).** Non-members see the 加入 / 申请加入 / 审核中 section on 概览 only; members keep 退出 on every tab. **Fixed (pass 16):** the floating capsule, see Pass 16 |
| club/detail · 概览 chat rows | `ClubDetailView` | The MP removed 进入群聊 from the club page (wxml:83). Native keeps chat / IM / channel rows on 概览. | **Not changed.** Earlier decision CLB-detail-14; flagged |
| club/topic-detail | `ClubGovernanceViews.swift` topicOverview | 未通过原因 must come before 核销 + 台账 (wxml:86 vs 96). | **Fixed** |
| club/topic-detail | same | 接下来 only when there are sessions (wxml:134); native showed a 还没有场次 placeholder. | **Fixed.** The section is hidden unless there are sessions or 管理场次 is allowed |
| club/topic-detail · 更多 | same | MP order (wxml:430-470): 剧情与玩法 → 结束活动 → 核销记录 → 场次管理 → 退出与暂停规则. Native was missing 剧情与玩法 and 核销记录, had 结束活动 last, and had stats/settings/enrollment first. | **Fixed.** MP order; stats/settings/enrollment follow as a second group |
| club/topic-detail | same | Hide 核销/主题/接下来 when the director is active and the topic ended (wxml:92, C-11 review state). | **Fixed (pass 3).** `directorReview` wraps those three blocks |
| club/topic-detail | same | Per-session 团码/run-control/集合时间 rows (MP has one director row); inline settings block in 更多; rules as a footbar half-sheet. | **Not done.** large / behaviour moves |
| club/topic-detail · 结束主题 (`components/cy/club-topic-end-confirm`) | `ClubGovernanceConsequence.endTopic` sheet | MP body 「停止售卖并把未核销的票原价退回。只是想让它不再露出的话，下架就够了。」, confirm 结束并退款, cancel 再想想. Native lines said 「未开始的场次全部取消…」/「已付款的报名自动退款，个别订单转人工处理」 and the confirm read 结束主题. | **Fixed (pass 6).** OpsR3 lines = the MP's two sentences (refund, then the 下架 alternative; symbols `arrow.uturn.backward.circle` / `eye.slash`), confirm 结束并退款 / End and refund. Manual-order counts still show in the result row. The 「主题名」 first line: **fixed (pass 8)**: the 更多 entry seeds `topicName` from the topic-setting read (MP `setting.topicName`, wxml:648); the form passes it to `ClubGovernanceConsequence.endTopic.sheet`, which shows it as the sheet's object line above the consequences (title stays 结束主题, CU-C-154). The draft keeps only the `cancellationEpoch` anchor, so the request body is unchanged |
| club/topic-story | `ClubGovernanceStoryView`, `ClubStoryViews.swift` | Missing-param 链接已失效 + 返回 (wxml:13). | Already present (`MPReviewedPageScreen` `club.story.missingTopic`, CLB-r9-topic-story-01) |
| club/topic-story | `ClubStoryViews.swift` `ClubStoryGameplayCard` | Extra orange "no answer" chip on play rows (MP: an unanswerable play just has no 查看答案 button). | **Fixed (pass 3).** Chip removed |
| club/topic-story | `ClubGovernanceViews.swift` answer sheets | Sheet title was 「答案 · node」; MP (wxml:117, CU-C-152) titles it 答案 and shows the play title as a wrapping sub line. | **Fixed (pass 3).** Title = 答案; play title (MP `data-title`) as a `.subheadline` secondary line, both the club and host answer sheets |
| club/topic-story | same | No template id: MP shows a dead 看看模板; native says 模板暂不可用. | **Kept** (native explains instead of a dead button; UI test pins the text) |
| club/badges | `ClubBadgeManagementView.swift` | Matches: list, 全部勋章 · N 枚, create, grant picker, states. | Matches |
| club/apply | `ClubGovernanceCommandForm` (hostApply) | Submit must read 成为俱乐部主理人 / 提交中… (wxml:164-165); native read 提交申请. | **Fixed** (existing keys `settings.becomeClubHost`, `gap.club.coopPool.submitting`) |
| club/apply | same | 上一步 button: the MP nav back steps back (js:212 `onBack` → `step - 1`); native is a sheet with 关闭 in the bar, so 上一步 carries that behaviour. | **Kept** (reason given) |
| club/apply | same | Extra required-fields footer; 状态 row on the done card; done-state loading/error + 可建俱乐部 row. | Footer: **kept** (pass 7 re-check: it carries the MP `*` required marks and the MP 联系方式仅用于审核 note, wxml:63-80, as a native footer, CLB-r10-nat-apply-03). Done state: **re-checked (pass 12): matches** MP wxml:168-186: 已生效 status, 主理人 name when present, 可建俱乐部 (allowance), then 创建我的俱乐部 (`ClubCreateMyClubLink`) |
| club/create | `ClubOperationsViews.swift` | 返回上一页 was missing on the no-permission and limit states (wxml:23, 27). | **Fixed.** Secondary `Button("team.page.goBack") { dismiss() }` |
| club/create | same | 创建资格未确认 needs primary 重新检查 + secondary 返回上一页 (wxml:16-18). | **Fixed (pass 2).** 重新检查 `.borderedProminent`, 返回上一页 `.bordered` |
| club/create | same | Extra step checklist on the intro; media above the step header on step 3; extra 上一步. | **Fixed (pass 12).** Intro = title + 开始创建 (pinned step bar) only, the R-steps checklist removed (MP wxml:34-37). Step 3: the 封面 / Logo section moved under the step header and above 名称 (MP wxml:57-97) through a `stepMedia` slot on `ClubOperationsProfileForm`; edit and the flat UI-test form keep it before the form. 上一步: kept (MP nav back steps back, js `onBack`) |
| club/enroll | `ClubEnrollmentView.swift` | The stale inline error's action should read 重试更新 (wxml:20). | **Fixed** (`club.enroll.retryUpdate`, also added to `ClubEnrollmentLocalizations.fragment.json`) |
| club/enroll | same | MP order is sub line → 正在更新报名名册… → stale error (wxml:17-20); native had the sub line last. | **Fixed (pass 2)** |
| club/enroll | same | Extra escrow line (pinned by `test_club_member_pages`); the ticket count comes from the rows instead of `tk.signups`; MP hides zero-signup tickets once any ticket has signups (js:421-422 `hideEmpty`), native listed them all. | **Fixed (pass 11).** Escrow 「报名费由平台担保托管」 removed (not in any MP page; pin flipped to assertNotIn). Count re-checked: MP `signups: regs.length` (js:397) = native `registrants.count`, matches. `visibleTickets` applies hideEmpty |
| club/enroll | same | The 已支付 · 可退款 · 截止 summary is one dot line in the MP (wxml:50-53); native shows three `LabeledContent` rows. | **Kept** (same fields, same order; native rows keep each value readable at large Dynamic Type and in English, P12) |
| club/checkin-detail | `ClubCheckinRailView` via `ClubGovernanceViews` | The server `errorText` should be the missing title / denied sub-line (wxml:13-16); native dropped it on the loaded path. | **Fixed.** `reason: failure?.message` |
| club/checkin-detail | same | Extra 已退款 note on the rail (MP: the rail is just unlit; the header status says 已退款). | **Fixed (pass 2).** Visible line removed; the sentence is now the rail's VoiceOver hint |
| club/group-code | `ClubGovernanceCommandForm` (issueGroupCode) | The no-permission exit should be 进入俱乐部管理 (goManage → detail tab=manage); native just dismissed. | **Fixed.** Reuses `ClubGroupCodeMissingLinkView.manageDestination` |
| club/group-code → `components/club-game-code-sheet` | `ClubGovernanceCommandForm` (issueGroupCode), `ClubGroupCodePresentation.swift` | MP sheet order: title 活动核验团码 → code card → 主题/场次名 under the code → 保存到相册 (wxml:9-24, group-code wxml:38-39). Native put the session name in the Section header above the card and never passed `sessionName`, so it read name → title → code. | **Fixed (pass 8).** The form passes `sessionName` (`ClubRoleActivityLabel.entry`) and drops the header; the presentation shows it under the code, before the expiry timer and 保存到相册. Error state (CU-C-148 one-line error + 重试) and the save path were already present (sweep: no group-code fixture in `docs/sweeps/latest/mp-club`) |
| club/detail · `components/cy/timeline`, club/settlement · `components/cy/fe-reference-range`, topic-detail · `components/club-director-*` (10 sheets) | management / director surfaces | Owner-stage timeline, settlement date range + 导出, and the live-run director sheets (ready, recap, chapter, team, role, incident, broadcast, end confirm). | **Not done.** Checked for scope: all are owner/director tools under the large topic-detail director row above; queued after the floating 加入 capsule |
| club/join-requests | `ClubManagementView.swift` | Loading should read 正在加载入会申请 (wxml:11); the empty state is the title only (wxml:20). | **Fixed** (`club.joinRequests.loading`) |
| club/join-requests | `MPReviewedPageScreen.swift` | A link without `clubId` should show the missing-param state with 返回 (wxml:12). | **Fixed.** `MemberMissingLinkState` |
| club/join-requests | same | Native rows push a detail page and 通过/拒绝 go through a review sheet; the MP does both in one tap. | **Re-checked (pass 12): matches.** The MP does not act in one tap either: 通过 opens a named confirm modal and 拒绝 a named reason sheet (js:131-157, `confirmReview` / `askRejectReason`). Native rows already carry visible 拒绝 (`.bordered`) / 通过 (`.borderedProminent`) like the card (wxml:31-40), plus 申请于 and the join message. The row's detail push is kept (no MP section added or reordered) |
| club/roles | `ClubOpsGovernanceSections.swift` | The owner row is name + 主理人 only; there is no footer line (wxml:23-45). | **Fixed** |
| club/roles | same | No members → full-page 暂无成员 (wxml:19, js:364). | **Fixed.** `ContentUnavailableView` when there are no delegable members and no assignments |
| club/settlement | `ClubGovernanceViews.swift` settlement | The direct ledger is for the owner only (`summary.isOwner`, wxml:9). | **Fixed** |
| club/settlement | same | MP order puts the 已入账 card after the funds stages. The native funds section also carries the withdraw button that the MP shows under the card, so moving the card would split card and button (and `test_club_ops_customer` pins card-before-funds). | **Kept** (reason given) |
| club/event-ops | `ClubOpsEventView.swift` | With no topics and no series, the MP hides 重复方式 (wxml:178). | **Fixed** |
| club/event-ops | same | 当前身份不能运营活动 needs 返回 (wxml:15-16). | **Fixed (pass 3).** `.bordered` 返回 (`action.back`) on the denied `ContentUnavailableView` |
| club/event-ops | same | 本场名册 · N 人 as the roster title. | Already present (CLB-event-ops-02) |
| club/event-ops | same | Inline 日期清单 and 重复方式 forms instead of push rows. | **日期清单 fixed (pass 25)**; 重复方式 inline form still **Not done** (large: the create form lives in `ClubGovernanceCommandForm` with its own review/return flow) |
| club/notify | `ClubGovernanceCommandForm` (sendNotification) | 当前身份不能发通知 | Already present (`ClubOpsNotifyDeniedText`, a `ContentUnavailableView`) |
| club/notify | `ClubGovernanceCommandForm.swift` | A failed 预览受众 is inline 受众预览失败 + reason + 重试 (wxml:59-62); native showed the generic form error. | **Fixed (pass 3).** Dedicated section before any review, 重试 re-runs the preview (`club.notify.previewFailed`) |
| club/notify | same | 投递状态 is its own section with 刷新 / 刷新中… in the section head, then the five counts and 只重试失败项 (wxml:72-111); native mixed the counts and a 刷新 row into the generic 已提交 receipt section (a parallel pass-4 run had only retitled that section). | **Fixed (pass 5).** New `Section` headed 投递状态 (`club.notify.deliveryStatus` from the parallel pass-4 run, header trait) with a `.borderless` 刷新 button (`notifyRefreshButton`, same id `club.notify.refreshCampaign`) in the header; counts, 只重试失败项 and the refresh notice moved into it |
| club/notify | same | Extra review fact rows: after 预览受众 the MP shows only the preview card 「N 人」 (+ 该分群暂无成员 at 0, wxml:55-64); native repeated 受众/标题/内容 and 站内/订阅消息 as fact rows above it. | **Fixed (pass 7).** The notify review section is the preview summary + the send button only (title/content stay in the form above). Send-button wording 发送给 N 人 kept (deliberate CLB-notify-01 choice) |
| club/governance | `ClubGovernanceViews.swift` (.bans), `ClubOpsMemberActionCard.swift` | Full-page 暂无可治理成员 (wxml:18, js:403: no members and no bans). | **Fixed (pass 3).** The card reports its member count (`onLoaded`); no bans + 0 members shows a `ContentUnavailableView` instead of the records section |
| club/governance | same | Appeal mode: MP page title 封禁申诉 (js:224); native drew it as an in-content headline section. | **Fixed (pass 3).** Inline bar title via `pageTitleKey` (`club.gov.casesAppeal`); headline section removed (OWNER RULE 2) |
| club/customers | `ClubOpsCustomerViews.swift` | The count line sits as the list section header after the filter (native pattern; the count follows the filter); the filtered-empty CTA 查看全部客户 is a borderless button under the empty state, not inside it. | **Kept** (the CTA's fences are pinned in place by `test_club_customer_clear_filters`; moving it needs the clear closure threaded into the list view) |
| club/customer-detail | `ClubOpsCustomerViews.swift`, `ClubCustomerInlineEditor.swift` | In edit mode the editor replaces the card, the heading reads 编辑标签与备注 and 取消 sits in the heading (wxml:82-99). | **Fixed (pass 2).** The editor owns the 标签与备注 section; 取消 moved from a row into the header (VoiceOver: 取消编辑标签与备注) |
| club/payout-receiver | `ClubPayoutReceiverView.swift` | Binding needs a WeChat code (`PayoutReceiverBridge.payoutOpen`). | Blocked (WeChat/backend), not a view gap |
| club/edit | `ClubOperationsViews.swift` | 改为转让主理人 is only inside the dissolve confirm in the MP (scene-club-edit `cy-danger-confirm` alt, utils/danger-actions.js `club.dissolve.alt`); native shows a permanent row. | **Fixed (pass 17).** See pass 17
| club/edit · 解散 confirm (`utils/danger-actions.js` `club.dissolve`) | `ClubGovernanceConsequence` (dissolve) | MP lists three consequences: 全部成员会被移出俱乐部，同时失去群聊入口 / 俱乐部名下的活动与会员权益一并下架；已报名的不会自动取消，也不会自动退款 / 此操作不可撤销. Native had two lines, and the first said upcoming events close, which reads as if sign-ups were cancelled (the MP says they are **not** cancelled or refunded automatically). | **Fixed (pass 8).** OpsR3 `r3club.consequence.dissolve.line1-3` = the MP's three sentences (en + zh-Hans), symbols `person.2.slash` / `calendar.badge.minus` / `exclamationmark.triangle`. Title 解散「name」？: **fixed (pass 10)**: the edit page's `ClubDissolvedReturn` now carries `profile.club.name` through the blockers page into the form, and the sheet titles itself `club.gov.consequence.dissolve.titleNamed` (Dissolve “%@”? / 解散「%@」？); without a name it keeps 解散这个俱乐部？ |
| club/detail · 退出 confirm (`utils/danger-actions.js` `club.quit`) | `ClubActionPanel` confirmation dialog | MP: 退出「name」？, 重新进来时… line, three consequences, confirm 退出俱乐部. | Matches (pass 8 check): system confirmation dialog with 退出「name」？, the rejoin line and `ClubLeaveConsequences` (the MP's three sentences). The MP alt 只关掉群聊提醒 is not offered (no per-club mute in the native panel); flagged |
| club/workbench | `MPReviewedPageScreen.swift` redirect | MP error state 没能进入俱乐部管理 + 重试进入 + 返回俱乐部. | Already present (CLB-workbench-03, CLB-r11-workbench-01) |

## Pass 2: OWNER RULE 2 (navigation + one design system)

Scan of every `App/Club*.swift` player file:

- `.font(.system(size:))`, `.tracking`, `.kerning`, custom font names, `Color(red:)`, `LinearGradient`, custom `.shadow`: **none**.
- Club home (`ClubHomeView`) is a tab root: `cyRootHeader` sets `.navigationTitle` + `.navigationBarTitleDisplayMode(.large)` (title 发现).
- Pushed club pages: every file that sets a navigation title also sets `.navigationBarTitleDisplayMode(.inline)` (37 files, titles = inline count in each).
- Per-page styling found: the club list thumbnail was hand-built twice (`ClubHomeView`, `ClubDirectoryView`, radius 10). **Fixed:** one shared `ClubRowThumbnail` in `ClubComponents.swift` on the `CYRadius.md` token.

## P17 (club home order) where the MP allows

- Identity header: cover, logo + name, 「类型 · N 名成员 · 入会方式」, a face pile with +N, and 邀请成员 for owner/admin. The host/city line moved to 概览, so the header now reads like P17's identity header.
- "Next event card with countdown" and "pinned poll" between the header and the feed: the MP has neither on the club page. It has tabs, with 活动 as its own tab, so nothing was added.
- "Sticky primary action at the bottom": the MP's floating 加入 capsule on 概览 is native since pass 16 (`ClubActionPanel` `.floating`).

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
| `clubR11.customer.cancelEditA11y` | Cancel editing tags and remark | 取消编辑标签与备注 |
| `club.notify.previewFailed` | Audience preview failed | 受众预览失败 |
| `club.gov.casesAppeal` | Ban appeal | 封禁申诉 |
| `r3club.consequence.dissolve.line1` (OpsR3, value changed) | Every member is removed from the club and loses the group chat. | 全部成员会被移出俱乐部，同时失去群聊入口 |
| `r3club.consequence.dissolve.line2` (OpsR3, value changed) | The club’s events and member perks are taken down. Existing sign-ups aren’t cancelled or refunded automatically. | 俱乐部名下的活动与会员权益一并下架；已报名的不会自动取消，也不会自动退款 |
| `r3club.consequence.dissolve.line3` (OpsR3, new) | This can’t be undone. A dissolved club can’t be restored. | 此操作不可撤销，解散后无法恢复这个俱乐部 |
| `club.notify.deliveryStatus` | Delivery status | 投递状态 |
| `club.gov.consequence.dissolve.titleNamed %@` | Dissolve “%@”? | 解散「%@」？ |
| `club.community.pinnedNoticesTitle` | Notices · Start here | 公告 · 新人先看 |
| `club.community.noticeNoText` | (No text) | （无文字内容） |
| `club.community.noticeUnreadA11y %@` | Unread notice: %@ | 未读公告：%@ |
| `club.community.noticeA11y %@` | Notice: %@ | 公告：%@ |
| `club.ops.locked.sub` | Only the host can set these | 仅主理人可设置 |

## Contract test pins updated (with reason)

- Pass 3: `test_club_ops_join_notify.test_appeal_mode_and_roles_title`: the appeal-mode title moved from an in-content headline to the inline bar title (OWNER RULE 2); the pin now checks the same `appealMode` gate in `pageTitleKey`.

- Pass 2: `test_club_ops_customer.test_detail_keeps_topic_route_edit_gate_and_hidden_amount` and the `operation == .customer` span hash in `test_club_leaderboard_member_navigation`: the inline editor now owns the 标签与备注 section (MP edit heading 编辑标签与备注 + 取消). The route, edit gate and hidden amount they guard are unchanged.

- `test_community_media_integration.test_club_public_entry_is_outside_governance`: the ClubHomeView feed call now also passes `onSignIn` (guest 登录后查看帖文). The public, non-governance entry it guards is unchanged.
- `test_club_detail_page_ready`: comment only. The pending key is now used by `ClubOverviewFacts` on 概览, not the header.

## Commits

1. 概览 facts row (主理人 / 俱乐部类型 / 所在城市) and the header trim.
2. 发现 title, club 帖文 composer pill + guest sign-in, topic-detail MP order.
3. Club ops pages: MP wording and gates (join-requests, enroll, checkin-detail, group-code, settlement, apply).
4. Roles, event-ops and join-requests MP states.
5. This receipt.
6. 创建俱乐部 no-permission / limit: 返回上一页.
7. 角色与权限 empty state 暂无成员.
9. Pass 3: topic-story answer sheet title + no-answer chip, event-ops denied 返回, notify 受众预览失败 + 重试.
10. Pass 3: governance 暂无可治理成员 full-page empty state; topic-detail director-ended review hides 核销/主题/接下来.
11. Pass 3: governance appeal-mode title 封禁申诉 in the nav bar.
12. Pass 4: merge combined-r7; club detail 加入 section on 概览 only.
13. Pass 4 (parallel run): notify receipt section titled 投递状态; 发现 message bell flagged.
14. Pass 5: merge combined-r7 (xcstrings: both sides' keys, 22 added); notify 投递状态 section with 刷新 in its header.
16. Pass 6: 结束主题 confirm in MP copy (结束并退款, 下架就够了).
15. Pass 6: merge combined-r7 (xcstrings: both sides' keys, 28 added); club 帖文 公告 · 新人先看 (≤2 pinned notices with unread dots).
17. Pass 7: merge combined-r7 (xcstrings: both sides' keys, 16 added); notify review = preview card only (MP wxml:55-64).
18. Pass 8: merge combined-r7 (xcstrings: combined is a superset; 35 keys take its newer values); 出示团码 card in MP order (code → session name → 保存到相册); 结束主题 confirm names the topic; 解散 confirm in the MP's three consequences.
20. Pass 10: merge combined-r7 (xcstrings: combined is a superset); 查找俱乐部 split into 你的俱乐部 / 发现 rows (P25); 解散 confirm titled 解散「name」？.
19. Pass 9: merge combined-r7 (xcstrings: combined is a superset); d4 club detail mounts the 帖文 feed (18:15 sweep); d4-badges / d4-stamps crash written up.
21. Pass 11: 报名名册 escrow line removed, hideEmpty tickets, team row colours.
22. Pass 12: merge combined-r7 (xcstrings: combined is a superset, plural variants); club fixtures follow the UI language; 创建俱乐部 intro without the checklist and 封面/Logo under the step-3 header; join-requests and apply done re-checked.
23. Pass 17: merge combined-r7; 改为转让主理人 moved into the 解散 confirm as the MP alternative (with its hint).
29. Pass 24: merge combined-r7; club join / apply / leave haptics for success, refusal and prepare failure.
28. Pass 23: merge combined-r7; club detail join action as a full-width bottom bar (01:20 sweep).
27. Pass 22: topic-detail director load states (empty / network / business error, a refused read no longer renders nothing).
26. Pass 21: merge combined-r7; apply note moved into an MP-style 申请加入 sheet, capsule always enabled (d4-detail).
25. Pass 19: merge combined-r7; declined club detail follows the MP (no red tag, reason line only, 重新申请 capsule in d4-detail).
24. Pass 18: merge combined-r7 (xcstrings: combined + our `club.ops.dissolve.transferHint`); club/edit full re-check, extra header row and admin note removed, locked card gets 仅主理人可设置.
8. Pass 2: shared club thumbnail, customer-detail edit heading, create check-failed 返回上一页, enroll order, check-in rail refund note.

## Sweep check (pass 7, build 070117595, `docs/sweeps/latest/mp-club/sheet-zh-Hans.jpg`)
Most tiles are the launch logo (coordinator 17:40: taken under load, ignore). Readable tiles: `d4-enroll` 报名名册 and `d4-members` 成员 look right (inline titles, grouped lists). `d4-channels` shows the category headers 「Announcements」/「Community」 in the Chinese UI, but those are channel-category names from `App/DesignFixtures/D4Fixtures.swift:108-109` (server data), not app copy. Re-check on the clean sweep.

## Pass 9: coordinator sweep 18:15 UTC (build 95b4643ab, `docs/sweeps/latest/mp-club/sheet-zh-Hans.jpg`)

| MP page | Native | Sweep finding | Status |
|---|---|---|---|
| `pages/club/detail` 帖文 tab (wxml:96-158, `/api/club/post/list`) | `App/ClubDetailView.swift:111-168`, fixture `App/DesignFixtures/D4Fixtures.swift` | `zh-Hans-d4-tab-posts.jpg`: 帖文 showed 「当前版本暂不可查看俱乐部帖子」. The view is right: with a community context it mounts `ClubCommunityFeedView` (MP post list, 公告 · 新人先看, composer pill, MP empty state). The d4 fixture never passed one, so the sweep hit the no-community fallback. | **Fixed (fixture).** `ClubCommunityFixture.context(identity:clubID:)` (offline transport, rows carry the requested club id); `d4-tab-*` and `d4-detail` pass it for viewer 701 / club 81. Re-check on the next sweep |
| `pages/talent/*` badge wall / stamp album (d4-badges, d4-stamps; also mp-roam `e2-stamp-album`, same `D4MeFixture(.stamps)`) | `D4MeFixture` → `ObjectBadgeWallView`, `RoamStampAlbumView` | App quits right after launch (home-screen tile), in both languages. | **Not done: not reproducible here** (no simulator in the cloud run). Checked statically: both cases resolve in `DesignFixtureRegistry.make` (lines 99, 103, 129); no `fatalError`/force-unwrap on the badge path; the only `try!` is `RoamExperienceFixtureReader.scope` (stamps only, constant input). Common to all three quitting fixtures (with mp-mine `e4-tickets`): `.cyHideTabBar()` + `cyPageTitle` on a fixture `NavigationStack` with **no** `AppSession` — new since 17:23, when design fixtures stopped building the production session (`5e2a0a57f`, mp-home). Needs the crash log from `xcrun simctl launch … --design-fixture d4-badges` (`~/Library/Logs/DiagnosticReports`). **Fixed by the coordinator in `1300a48db`** (palette `.accentColor` ↔ root `.tint` recursion); the 19:36 sweep renders both |

## Pass 10: P25 / P26 (design-principles e08794fe6)

| MP page | Native | Difference | Status |
|---|---|---|---|
| none (查找俱乐部 has no MP page; the MP searches clubs through unified search, and talent/list wxml:74 keeps one unsplit list on the tab root) | `App/ClubDirectoryView.swift` | `en-d4-directory.jpg`: every result was the same three-line row (name / style · city / N members) with an "Apply to join" pill, whether or not the viewer was already in the club. P25: the viewer's clubs are navigation, other clubs are a decision. | **Fixed.** Section 你的俱乐部 (`club.home.yours`; owner / joined): thumbnail, name, member count, chevron. Section 发现 (`club.home.discover`, header shown only when both sections exist): thumbnail, name, one secondary line (N 名成员 · description, else style · city, `.lineLimit(1)`) and one trailing `.bordered` `+ 加入` / 申请加入 (`.fixedSize()`, same ids `club.directory.<id>.join`); pending keeps 审核中. 我创建的俱乐部 (`ClubOwnedView`) uses the 你的俱乐部 row. Existing keys only. Talent/list tab root **not split** (MP UI-19 comment: 不再分「我的 / 附近」两段) |
| club/detail 帖文 (P26) | `ClubDetailView` 帖文 tab | Non-member must see real posts, never a "not available in this version" placeholder; one prominent Join. | Feed mounted in pass 9 (fixture). Join stays the 概览 加入 section (MP floating capsule is 概览-only); no second CTA on 帖文. Re-check on the next sweep |

## Pass 11: sweep 18:54 UTC (build 1300a48db, `docs/sweeps/latest/mp-club/sheet-zh-Hans.jpg`, `sheet-en.jpg`)
| Screen (shot) | Native view | Seen | Fixed? |
|---|---|---|---|
| club/enroll (`zh-Hans-d4-enroll.jpg`) | `ClubEnrollmentView` | Sub line followed by 「报名费由平台担保托管」 (not in the MP); the team row (title + 时间待定 · 已报名 8 人) drawn in tint blue / light blue because `.primary`/`.secondary` resolve against the Button's tint. | **Fixed.** Escrow row removed (see table); team Button `.tint(.primary)` so the title reads primary and the meta secondary, row highlight kept |
| club/detail 帖文 (`zh-Hans-d4-tab-posts.jpg`) | `ClubDetailView` | Still 「当前版本暂不可查看俱乐部帖子」. | Build predates pass 9 (`bb15728bd` mounts the feed in the d4 fixture); re-check on the next sweep |

## Pass 12: sweep 19:36 UTC (build 3568fe51b, `docs/sweeps/latest/mp-club/sheet-zh-Hans.jpg`, `sheet-en.jpg`) + Not done rows
| Screen (shot) | Native view | Seen / difference | Fixed? |
|---|---|---|---|
| club/detail 帖文 (`zh-Hans-d4-tab-posts.jpg`) | `ClubDetailView` | Shows the MP feed now (composer pill, post card). | ✓ re-checked (pass 9 fix landed) |
| club/detail, members, posts, channels, channel chat (`zh-Hans-d4-detail.jpg`, `-d4-members`, `-d4-tab-posts`, `-d4-channels`, `-d4-channel-chat`) | `ClubFixtureReader`, `ClubCommunityFixture`, `D4ChannelsHost` | Fixture data English in the Chinese UI (Fixture club 81, Offline sample club description, Fixture creator/type/city, Announcements / Community, club-news, Saturday route…), coordinator 19:50 "fixture data must follow the UI language". | **Fixed.** `ClubFixtureReader.designCopy` (set only by the D4 design fixture, so UI tests keep their English pins) and `ClubCommunityFixture.context(…, designCopy:)` pick zh-Hans copy when the UI is Chinese; channel categories, names, senders and messages use `tt(en, zh)` (the en golden-path pin "Saturday route…" is unchanged) |
| club/create intro + step 3 | `ClubOperationsViews.swift` | See table row club/create. | **Fixed** |
| club/join-requests, club/apply done | see table | Re-checked against the MP js/wxml. | Matches |
| club/detail (`zh-Hans-d4-detail.jpg`) | `ClubDetailView` | ~60 pt gap between the header card and the 帖文/活动/概览 bar. Not reproducible without a simulator (likely list section spacing around the tab-bar row). | **Fixed (pass 13)**, see below |

## Pass 13: sweep 20:11 UTC (build a250afd77, `docs/sweeps/latest/mp-club/sheet-zh-Hans.jpg`, `zh-Hans-d4-detail.jpg`)
| Screen (shot) | Native view | Seen / difference | Fixed? |
|---|---|---|---|
| club/detail (`zh-Hans-d4-detail.jpg`) | `ClubDetailView.pageHeader`, `ClubDetailTabBar` | Still ~55 pt of empty space between the header card and the 帖文/活动/概览 picker, and again under it. Cause: the app-wide 24 pt `listSectionSpacing` (CYScreenStyle) plus the clear picker row's default 44 pt row padding. The MP tabs sit right under the header (detail wxml:96-110). | **Fixed.** Header section and tab-bar section use `.listSectionSpacing(.compact)` (same per-section pattern as `ProjectEditView`); the picker row insets are `CYSpacing.xs` vertical / `CYSpacing.lg` horizontal. Re-check on the next sweep |
| club/detail, members, posts, channels (`zh-Hans-*`) | fixtures | Still English data in Chinese. | Build a250afd77 predates pass 12 (`09e019a4d`, not yet in `ui/combined-r7`); re-check once merged |

## Pass 14: contract cleanup (20:40) + sweep 20:45 UTC (build bb76e327c, `docs/sweeps/latest/mp-club/sheet-zh-Hans.jpg`, `sheet-en.jpg`)
| Item | Native | Seen / difference | Fixed? |
|---|---|---|---|
| Contract cleanup `/api/club/update` | `Core/ChannelDiscordMessaging.swift` `ClubTabAndAdminParityCatalog` (club.create_edit) | The catalog still listed the native-only name `api/club/update`. Every real call already goes to the MP route `POST /api/club/update-mine` (`ClubOperationsContracts.swift:135`, `RePoint03ClubUpdate`). | **Fixed.** The catalog row lists `api/club/update-mine` under `backendEndpoints` (a MATCH row in `backend_route_status.csv`); `api/club/update` is gone from the app's call literals (the missing→production adapter row in `ChinaReviewedRouteCapability` stays, pinned by `test_club_edit_page_ready`) |
| Contract cleanup `/api/im/poll/create-receipt` | `Core/GroupPollCoordinator.swift`, `GroupPollService.swift`, `BusinessRuntimeConfiguration.swift:162`, `App/GroupPollViews.swift`, `App/BeGapImDesk.swift:181` | Drop; use the `create` reply / `result`. | **Fixed (pass 20) in production:** the route is no longer granted (`ReviewedPlayerWriteLeases.beGapImRoutes` drops `.imPollCreateReceipt`), so `client.permits("api/im/poll/create-receipt")` is false, `canRecoverCreationReceipt` is false, the 只回读原投票创建请求 button never shows and a lost create reply reads as `poll.unknown` (the `create` reply / `result` read is the record, as in the MP). The BeGapImDesk tool's poll-receipt read is removed. The dormant service method, feature case and its unit tests stay until a compiler run can delete them together (left literal: `GroupPollService.swift:15`, `BusinessRuntimeConfiguration.swift:162`, acknowledged in `no_backend_allowlisted_routes.txt`). Earlier note: the receipt read is the relaunch recovery for an unanswered create (journal + draft + 6 permit checks) with ~20 Swift unit tests (`GroupPollOptionalRecoveryTests`, `NativeChannelHostIndependentReadGateTests`) built around it; removing it safely needs a compiler run. Next pass: gate `canRecoverCreationReceipt` off, read `result` instead, delete the receipt tests with the feature |
| club/enroll (`zh-Hans-d4-enroll.jpg`) | `D4ClubOpsFixture(.enroll)` | Topic row 「Fixture topic」 in the Chinese UI. | **Fixed.** The enroll fixture overrides the `.topics` read with 示例主题 when the UI is Chinese (en unchanged) |
| d4-badges (`zh-Hans-d4-badges.jpg`) | `ProfileFixtureReader.profileBadges` | Fixture city medal / Fixture achievement / Fixture identity / Synthetic unlock condition in Chinese. | **Fixed.** Names and conditions follow the UI language (same pattern as mp-roam's stamp album fixture); English unchanged for `RoamBadgeWallFlowTests` |
| club/detail (`zh-Hans-d4-detail.jpg`) | `ClubDetailView` | Header → tab bar gap still visible. | Build bb76e327c predates pass 13 (`3de78d3c3`); re-check after the next combined merge |

## Pass 15: sweep 21:09 UTC (build 405948d58, `docs/sweeps/latest/mp-club/sheet-zh-Hans.jpg`, `sheet-en.jpg`)
| Screen (shot) | Native view | Seen / difference | Fixed? |
|---|---|---|---|
| club/detail 帖文 (`zh-Hans-d4-tab-posts.jpg`, `en-d4-tab-posts.jpg`) | `ClubCommunityViews.swift` post tile action bar | The like button shows its name 「点赞或取消点赞」 and wraps to three lines; in English the row truncates to "Like / Com / Re / Shar". MP `components/cy/post-card/index.wxml:120-148`: the action row is icon-only 赞 / 评论 / 转发 / 分享 with the count beside the icon and nothing at 0 (`{{post.likeCount \|\| ''}}`); the spoken name sits in `aria-label`. | **Fixed.** New `actionCount` helper: icon + count when > 0, icon only at 0 (`.labelStyle(.iconOnly)`); 转发 / 分享 / ··· are icon-only labels. Spoken names stay (`accessibilityLabel` on like/comments, the Label title on the others); every control is ≥ 44 pt. The 收起评论 state keeps its text |
| club/detail (`zh-Hans-d4-detail.jpg`) | `ClubDetailView` | Header → tab-bar gap is gone (pass 13 landed). | ✓ re-checked |
| d4-badges, d4-enroll (`zh-Hans-d4-badges.jpg`, `zh-Hans-d4-enroll.jpg`) | fixtures | Fixture names still English in Chinese. | Build 405948d58 predates pass 14 (`67a8a927c`); re-check after the next combined merge |


## Pass 16: Not done row club/detail · join (floating 加入 capsule, P17)
No new coordinator finding for mp-club since 21:20 (latest sweep is still build 405948d58, checked in pass 15).
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| `pages/club/detail` wxml:1028-1036, js:2530-2590 | `ClubDetailView.floatingJoin` → `ClubActionPanel(placement: .floating)` | Floating 加入 / 申请加入 / 重新申请 capsule on 概览 only, bottom-right, hidden for the owner and for members; greyed 等待主理人审核 when pending; guests sign in first (js:2531); apply asks for the required 60-char note (js:2537-2548) | **Fixed.** 概览 no longer draws the 成员身份 section under the header for non-members: the action is a `.borderedProminent` capsule (`.large`) in the List's bottom `safeAreaInset`, trailing like the MP; pending is the same capsule disabled. Status, the 申请留言 field + help/required/too-long text, progress, errors and the unknown-outcome readback sit in one `.regularMaterial` card above the capsule only when there is something to read. The same panel instance stays mounted after a join so the joined chip and the server readback stay visible (members then see nothing there; 退出 stays the page-end row on 概览 and the header row on the other tabs). Same confirmation dialog, identifiers (`club.action.join/apply/gated/signIn`, `club.application.message`) and request path as before, so `ClubActionFlowTests` keep their queries. Not copied: the scroll-to-hide animation (the capsule stays, P17 sticky action). Needs a look on the next sweep (no d4 fixture is a non-member yet) |


## Pass 17: Not done row club/edit · 改为转让主理人 (sweep 22:11 UTC, build 8fa84e4d3, `docs/sweeps/latest/mp-club/sheet-zh-Hans.jpg`, `sheet-en.jpg`)
Sweep check: all nine club tiles read in the UI language now (d4-badges, d4-enroll, d4-detail fixture data in zh). `d4-detail` still shows the 入会申请已拒绝 status with no capsule: build 8fa84e4d3 predates pass 16 (`603876c21`), re-check next sweep. `d4-stamps` grey discs belong to mp-roam (22:20 sweep, same `RoamStampAlbumView`).
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| `pages/club/edit` + `components/cy/scene-club-edit` 危险操作, `utils/danger-actions.js` `club.dissolve` (alt `{ text: 改为转让主理人, hint: 把俱乐部交给别人打理，成员和内容都留着 }`), edit js:35-39 `goGovernance` | `ClubOperationsViews.swift` (危险操作 section), `ClubGovernanceCommandForm.transferInsteadAction`, `ClubGovernanceConsequence.sheet(alternative:)`, `ClubConsequenceSheet` | 危险操作 = 解散俱乐部 + its consequence line only; the transfer is the lighter alternative inside the dissolve confirm | **Fixed.** The permanent 改为转让主理人 row under 解散 is gone. The 解散「name」？ consequence sheet now shows 改为转让主理人 in its own section above the destructive confirm, with the MP hint as the section footer (`club.ops.dissolve.transferHint`, en + zh-Hans). Tapping it cancels the review, closes the dissolve form without dissolving, and pushes 成员治理 (governance, where the transfer lives) from the blockers page via `ClubDissolvedReturn.transferInstead` → `.navigationDestination(isPresented:)`. Only the edit page passes the callback, so other consequence sheets are unchanged |

## Pass 18: club/edit full page (no new coordinator finding; latest sweep is still build 8fa84e4d3, checked in pass 17)
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| `pages/club/edit` → `components/cy/scene-club-edit/index.wxml` (whole page, not only 危险操作) | `ClubOperationsViews.swift` `ClubOperationsProfileForm.editSections` + edit page | MP order: load states (正在读取俱乐部资料 / missing-param / 暂无编辑权限 / 编辑资料没能打开 / 网络连接失败) → draft panel → 俱乐部形象 (头像, 封面) → 基础信息 (名称* 城市* 关键词 风格) → 俱乐部介绍 (200 counter) → 定位 (俱乐部类型, 活动倾向 as disclosure rows + half sheets) → 会员经营配置 (owner: 成员优先报名, 入会需要审批, 成员保留名额 个; admin: locked card) → 危险操作 (owner) → 保存修改. Native: all ✓ in MP order (draft recovery section, load states, 形象 → … → 危险操作, bottom save). Extra: a cover · name · city · 主理人/管理员 header row above the form (CLB-r10-nat-edit-01 cited an MP club head that the MP snapshot does not have; 头像/封面 already sit in 俱乐部形象), and a 「你是管理员 · 只能改展示信息」 line at the top of 基础信息 for admins (not on the MP page). Missing: the locked card's 「仅主理人可设置」 sub line (wxml:124) | **Fixed.** Header row removed (`clubIdentityHero`; `test_club_operations_contracts` no longer requires `PlayerFeedRemoteImage` in the edit UI, reason in the pin). Admin note removed; the locked card reads 只有主理人能改经营配置 → 仅主理人可设置 (`club.ops.locked.sub`, en + zh-Hans, one combined VoiceOver element) → 当前: … . Pins: `test_club_member_pages.test_edit_admin_note_and_locked_settings` now asserts the note is gone and the sub line present; `ClubEditAdminLockFlowTests` admin test renamed and asserts no note. Kept: 当前: with an ASCII colon (two string fragments pin it) |

## Pass 19: coordinator sweep 23:20 UTC (build b3b03703a, `docs/sweeps/latest/mp-club/zh-Hans-d4-detail.jpg`)
Merged `origin/ui/combined-r7` (xcstrings: combined + our `club.ops.locked.sub`).
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| `pages/club/detail` declined applicant (wxml:82, 280-283, 342-345, 1028-1038) | `ClubDetailView.statusTags`, `App/DesignFixtures/D4Fixtures.swift` | MP for `myJoinStatus === 2`: no status tag; 「申请未通过：reason」 in secondary text under the header only when the server sent a reason; the locked 通过审核后可看成员名单 / 通过审核后可看贡献榜 lines stay (they are in the MP for every non-member of a 需审核 club); the one action is the floating 重新申请 capsule on 概览. Shot: red 「入会申请已拒绝」 tag in the header and no capsule (the d4 fixture passed no action coordinator, so the panel never mounted). | **Fixed.** Red rejected tag removed; the reason line is `.secondary` (MP `--cy-text-secondary`) and only drawn with a reason. d4-detail (visitor) now passes a synthetic `ClubActionCoordinator` (`D4ClubActionWriter`, never sends) so the 重新申请 capsule renders. Locked rows **kept** (MP content). Re-check next sweep |

## Pass 20: contract cleanup Not done row (no new coordinator finding for mp-club; sweep 23:50 is build 793c3190b, before pass 19)
| Item | Native | Fix |
|---|---|---|
| `/api/im/poll/create-receipt` (drop) | `App/ReviewedPlayerWriteLeases.swift` `beGapImRoutes`, `App/BeGapImDesk.swift` | Production grant and the desk caller removed; see the Pass 14 row. Gates: generate OK, scaffold PASS, a11y 0 new, ratchet 52/52 new 0, design consistency PASS |

## Pass 21: coordinator sweep 00:20 UTC (build 283dd3b52, `docs/sweeps/latest/mp-club/zh-Hans-d4-detail.jpg`, `en-d4-detail.jpg`)
Merged `origin/ui/combined-r7`. Rest of the sheet re-checked in both languages: d4-directory, d4-tab-posts, d4-members, d4-badges, d4-stamps, d4-enroll, d4-channels, d4-channel-chat all render in the UI language, with no debug text and native titles.
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| `pages/club/detail` join / apply (js:2530-2550 `onJoin`: approval clubs open `modal.show({ title: 申请加入, content: 给主理人说一句吧，比如你是谁、想跟哪种局（必填，60 字内）。, editable, placeholderText: 朋友推荐来的，想跟一次夜行, confirmText: 提交申请 })`; wxml:1028-1036 capsule) | `App/ClubActionPanel.swift` floating placement (`floatingBar`, new `applyForm`) | Shot: the 重新申请 capsule is greyed out (it stays disabled until the required note is filled), and the note field + help sit in a see-through `.regularMaterial` card over 成员 · 3 / 本团贡献榜, so the list text shows through the field. In the MP the capsule is always tappable and the note is asked in the modal. | **Fixed.** On 概览 the capsule (申请加入 / 重新申请, same id `club.action.apply`) is enabled and opens a `.sheet` (`.medium`/`.large` detents): inline title 申请加入 / 重新申请, the club name as the section header, the MP prompt line, the note `TextField` with the MP placeholder, 取消 (cancellation) and 提交申请 (confirmation, `admission.submit`, disabled while the note is empty or over 60 characters, with the too-long line in the footer). 提交申请 is the one confirmation, as in the MP: it prepares and sends directly, with no second dialog. The material card now shows only status, progress and errors. Join (open clubs), leave and the header/page-end placements keep the system confirmation dialog. New keys `club.application.prompt`, `club.application.placeholder` (en + zh-Hans). `ClubActionFlowTests` apply cases now go through the sheet (`openApplication` / `submitApplication`, ids `club.application.submit` / `club.application.cancel`). Re-check on the next sweep |

## Pass 22: Not done row topic-detail director (no new coordinator finding for mp-club; latest sweep f8574edab predates pass 21, so the 申请加入 sheet is re-checked on the next sweep)
The ten director sheets were compared by MP copy against native. 结束这场活动？ (`club-director-end-confirm`, wxml:343-348) already matches (`club.topic.directorEnd.*` alert). The chapter / team / role / broadcast / incident sheets still open the generic director page (`PlayDirectorView`), so that Not done row stays; first fix the director's own load states, which the MP keeps apart from the page body.
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| `pages/club/topic-detail` director load states (wxml:159-171; director.js:378-385 `classifyLoadError`, 812-818) | `App/ClubTopicDirectorMount.swift` `ClubTopicDirectorEmbeddedMount` | MP: loading skeleton; `business-error` 导演台读取失败 + server sentence (default 活动导演台暂时无法打开) + 重新加载; `network-error` 网络连接失败 + 重新连接; `empty` (NOT_FOUND) 还没有可管理的活动局 + 先从俱乐部管理区开一场，再进入导演台。 Native drew only one 导演台加载失败 state for transport errors, and **nothing at all** when the server refused the read (`phase == "rejected"`), so the director block silently vanished. | **Fixed.** `loadState(phase:issue:)` maps the coordinator: `rejected(404)` → empty (server sentence or the MP sub line), other refusals → 导演台读取失败 + sentence + 重新加载, `failed` with `.unknownResult` (transport / non-2xx) → 网络连接失败 + 重新连接, other `failed` → 导演台读取失败. All `ContentUnavailableView`, `.bordered` retry (same id `club.topic.director.retry`). zh title now reads the MP 导演台读取失败. New keys `club.topic.director.empty`, `.emptySub`, `.network`, `.reconnect`, `.failedSub` (en + zh-Hans). Test `ClubTopicDirectorLoadStateTests` |

## Pass 23: coordinator sweep 01:20 UTC (build 907570051, `docs/sweeps/latest/mp-club/en-d4-detail.jpg`, `zh-Hans-d4-detail.jpg`)
Merged `origin/ui/combined-r7`.
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| `pages/club/detail` join capsule on 概览 (wxml:1028-1036) | `App/ClubActionPanel.swift` `floatingBar` (mounted by `ClubDetailView.floatingJoin` in the List's `.safeAreaInset(edge: .bottom)`) | Shot: "Apply again" / 重新申请 is a centred capsule floating over the 概览 list and covers the "Club contribution this week" header. MP content unchanged: one 加入 / 申请加入 / 重新申请 action on 概览, greyed 等待主理人审核 when pending, guests sign in first. | **Fixed.** The action is now a bottom bar: full-width `.borderedProminent` capsule (`.large`) on `.bar` material with a top divider, extending under the home indicator; the list scrolls above it so nothing is covered. Status / progress / error lines sit above the button inside the same bar (the separate see-through material card is gone). The bar draws only when it holds something (`floatingHasContent`), so members and the owner get no empty strip. Same ids (`club.action.join/apply/gated/signIn`), apply sheet and confirmation dialog. Re-check on the next sweep |

## Pass 24: brief 01:40 "Next round" item 2 (motion and feedback); no open coordinator finding for mp-club (sweep a32387e9b predates pass 23, so the bottom bar is re-checked on the next sweep)
Merged `origin/ui/combined-r7` (a32387e9b). Every MP club page already has a row above, so this pass starts the 01:40 list.
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| `pages/club/detail` 加入 / 申请加入 / 退出 (js `onJoin` / `onQuit`: success toast, failure toast) | `App/ClubActionPanel.swift` `submit` / `prepare` | MP content unchanged (same actions, same confirmations, same copy). Before: only a successful join / apply played a haptic; a successful leave, a server refusal and a failed prepare were silent. | **Fixed.** Leave acknowledged → `CYHaptics.success`; `.rejected` (join / apply / leave) → `CYHaptics.warning`; prepare failure (资格已变化 / 准备失败) → `CYHaptics.warning`. State changes keep the existing `.animation(reduceMotion ? nil : .default)`. Already present elsewhere: `.selection` on the detail tab bar and the create/edit type pickers, `.impact(.light)` on post likes, `.success` on the reward chip |
| `pages/club/detail` 帖文 + `components/cy/post-compose` (发帖, 评论, 点赞以外的 置顶 / 删除 / 举报: success toast, failure toast) | `App/ClubCommunityViews.swift` `ClubCommunityViewModel.confirm` | MP content unchanged. Before: confirming a post / comment / pin / delete / report in the review sheet was silent. | **Fixed.** The write landing (or queued for moderation) plays `CYHaptics.success`; a refused or unknown write plays `CYHaptics.warning` next to the existing notice. In the model, not the view, because `confirm` returns true for a failure too (the sheet closes and the notice shows) |
| `pages/club/join-requests` 通过 / 拒绝 (js:131-157, failure toast) | `App/ClubManagementView.swift` `confirm` | MP content unchanged. Success already played `CYHaptics.success`; a refused 通过 / 拒绝 (row marked failed) was silent. | **Fixed.** `.rejected` → `CYHaptics.warning` with the failed-row mark |

## Pass 25: Not done row club/event-ops 日期清单 (sweep 02:10 UTC, build 41374363f, `docs/sweeps/latest/mp-club/en-d4-detail.jpg`: pass 23 bottom bar renders full width under the list, nothing covered ✓)
Merged `origin/ui/combined-r7` (41374363f). No new coordinator finding for mp-club.
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| `pages/club/event-ops` 日期清单 card (wxml:117-170) | `App/ClubOpsEventView.swift` `.series` section, new `ClubOpsEventSeriesInlineRows` | MP card: loading skeleton → 系列列表加载失败 + 重试 → 还没有系列场次 → per series 「主题 · 重复方式」 + 候补开启/关闭 with trailing 编辑未来场次 (tap = edit that series) → 日期清单（含已过去与已取消的场次） → 添加日期. Native: one 日期清单 push row; the series only showed after a push. | **Fixed.** The hub now reads the series list with the topics and draws it inline in the 日期清单 section (header 日期清单, footer rule 仅可修改无报名的未来场次): error line + `.bordered` 重试 (`clubOpsEvent.series.retry`), empty 还没有系列场次, else one `NavigationLink` per series (`ClubOpsEventSeriesRowView` + tinted 编辑未来场次, `ViewThatFits` stacks it under the title in long English / large type) opening the series detail where the edit lives (`clubOpsEvent.series.edit.<id>`), then 日期清单（含已过去与已取消的场次） opening the full list with the per-series date browser (same id `clubOpsEvent.open.series`). 添加日期 stays the 重复方式 row below (it opens the create form). The 发布主题 empty rule (`publishEmpty`) is unchanged. New keys `clubOpsEvent.series.allDates`, `.editFuture`, `.loadFailed` (en + zh-Hans). Needs a look on a sweep (no event-ops fixture yet) |

## Pass 26: brief 01:40 "Next round" item 3 (a design fixture per state); no open coordinator finding for mp-club (brief ends at the 02:20 sweep, nothing for mp-club)
Merged `origin/ui/combined-r7` (ad55acd94).
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| `pages/club/event-ops` (日期清单 card, wxml:117-170) | `App/DesignFixtures/D4Fixtures.swift` `D4ClubOpsFixture(.eventOps)`, `DesignFixtureRegistry` | Pass 25 could not be checked on a sweep: no fixture reached `ClubOpsEventView`. | **Added** `--design-fixture d4-event-ops` (owner, one weekly series: 「示例主题 · 每周」 + 候补开启 + 编辑未来场次, then 日期清单（含已过去与已取消的场次）) and `d4-event-ops-empty` (no series: 还没有系列场次). Synthetic `ClubGovernanceFixtureAccess` data; topic name follows the UI language like d4-enroll. Coordinator: please add both to the mp-club sweep row |

## Pass 27: sweep 03:04 UTC (build ad55acd94, `docs/sweeps/latest/mp-club/sheet-en.jpg`, `sheet-zh-Hans.jpg`, `en-d4-channels.jpg`); no new coordinator finding for mp-club
Merged `origin/ui/combined-r7` (already up to date). Not done rows re-checked: 重复方式 inline form, topic-detail per-session rows and the director sheets stay large behaviour moves (the 重复方式 flow is two push levels: `.eventTopics` → `createSeries` form with its own review/return); the 消息 bell stays flagged.
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| club channels list (app-only club workspace; no MP page) | `App/DesignFixtures/D4Fixtures.swift` `D4ChannelsHost` | Shot `en-d4-channels.jpg` / zh: the channel list has no navigation title at all (just 公告 / 社区 sections under an empty bar). Production `ClubChannelMessagingHostView` sets the inline title 「俱乐部名 · 频道」; the fixture mounted the inner view without it. | **Fixed (fixture).** Same inline title as production (`tt(en, zh)`), so d4-channels / d4-channel-chat show what players see |
| club channel conversation, announcement channel (`d4-channel-chat`) | `App/ClubChannelMessagingView.swift` | Shot: a member in the read-only 俱乐部动态 channel is asked twice to accept the channel rules (top 发言前请先阅读频道公约 + 查看公约 row and the bottom 请先在上方阅读并同意…后再发言) although they cannot post there at all. | **Fixed.** New `isReadOnlyForViewer` (announcement channel and no moderate permission): the rules gate row and the locked composer line are skipped there and the composer shows the existing 当前为公告频道，仅主理人与管理员可发布通知 line. Rules stay mandatory before posting in every channel the viewer can post in (`sendOptimisticChannelMessage` guard unchanged). Re-check on the next sweep |

## Pass 28: brief 01:40 "Next round" item 1 (P31 composer); no open coordinator finding for mp-club (sweep 04:00 build 733bfb368 predates pass 27, so the channel title / read-only channel fixes are re-checked on the next sweep)
Merged `origin/ui/combined-r7` (733bfb368). Checked `docs/sweeps/latest/mp-club/sheet-zh-Hans.jpg`, `sheet-en.jpg`: nothing new.
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| club/detail 帖文 composer (`pages/square/components/cy/post-compose`, club mode; `index.js:87-98` `draftIdentity(memberId, clubId)`, `persist` on close, restore on show) | `App/ClubCommunityViews.swift` `ClubCommunityComposer`, new `App/ClubPostDraftStore.swift` | MP field order kept: text → images → 带上一次游玩记录 → 作为公告发布. MP keeps one local draft per member + club and restores it; native lost the words on Cancel / swipe-down. | **P31 applied.** The text field is focused on open (new post); 确认内容 / Review is `.borderedProminent` and stays disabled until there is content; Cancel with content asks 要保存为草稿吗？ → 保存草稿 / 不保存 (destructive) / 继续编辑 (`ClubPostDraftExitDialog`, a `ViewModifier` per the 03:50 compile rule); swipe-down saves like the MP `persist`; the draft (text + uploaded image refs) is keyed by account id + club id (guests keep nothing) and is cleared when the post goes to review. Edit mode (`ClubPostEditExitControl`) unchanged. New keys `club.community.draftTitle/.draftMessage/.draftSave/.draftDelete/.draftKeep` (en + zh-Hans). UI tests unchanged (cancel on an empty composer still closes at once). The new store is listed in `docs/ops-safety/client-data-catalog.json` (`tools/audit_client_ops_surfaces.py --check` PASS) |

## Pass 29: brief 01:40 "Next round" item 2 (motion and feedback) for the owner/admin governance forms; no open coordinator finding for mp-club (latest sweep is still 733bfb368, 03:49Z, before passes 27-28)
Merged `origin/ui/combined-r7` (93bff6dcd). Every MP club page has a row; the remaining Not done rows (重复方式 inline form, topic-detail per-session rows, director sheets) are behaviour moves through `ClubGovernanceCommandForm`'s review/return flow and stay queued. The 消息 bell row was stale and is now marked Already present (see the table).
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| `pages/club/notify`, `roles`, `badges` (grant), `event-ops` (create/edit series, cancel date), `governance` (transfer, ban/unban), `edit` (dissolve), `topic-detail` (结束主题, settings), `group-code`, `customer-detail` (保存): every write goes through `wx.showToast` success / failure in the MP | `App/ClubGovernanceCommandForm.swift` `prepare` / `confirm` (the one review→confirm path all of these use) | MP content unchanged (same fields, review, confirm sheets and copy). Before: a confirmed governance write and a refused one were both silent; only club detail, posts and join requests (pass 24) gave feedback. | **Fixed.** An acknowledged write plays `CYHaptics.success`; a refused confirm, a failed prepare (validation / stale review) and an 结束主题 that left sessions uncancelled (form stays open with 「N 场没能取消」) play `CYHaptics.warning` next to the existing error line. Imperative `.play()` inside the async functions (no new closure on the long body, per the 03:50 compile rule and the 04:20 untyped-haptic gate: still 103 = baseline). State changes keep the existing animations / Reduce Motion fallbacks |

## Pass 30: sweep 04:46 UTC (build 13a6690eb, `docs/sweeps/latest/mp-club/sheet-en.jpg`, `sheet-zh-Hans.jpg`); no open coordinator finding for mp-club
Merged `origin/ui/combined-r7`. Passes 27-29 render as intended (channel titles, read-only announcement footer, composer card, 重新申请 bottom bar). One debug-looking line left on the sheets:
| MP page | Native view | MP sections | Optimizations / fix |
|---|---|---|---|
| `pages/talent/*` badge wall (d4-badges, en: locked badge reads "Synthetic unlock condition") | `App/ProfileFixtureSupport.swift` (fixture data for `ObjectBadgeWallView`) | MP shows the unlock condition under a locked badge; unchanged | **Fixed.** Fixture conditions read like MP copy in both languages: "Check in at 3 spots in one city" / 在同一城市打卡 3 个点位, "Collect every stamp in the city" / 集齐本城全部印章, identity statement "Explorer identity card" / 探索者身份卡. No test pins these strings (badge names stay as `RoamBadgeWallFlowTests` pins them) |

## For other lanes
- mp-home / coordinator: `5e2a0a57f` (17:23) made design fixtures run without `AppSession`; the three fixtures that quit in the 18:15 sweep (d4-badges, d4-stamps/e2-stamp-album, e4-tickets) all touch that path, but no earlier clean sweep covered them, so this is a lead, not a cause. Please attach the simulator crash log to the next sweep so the owning lane can fix the exact line.
- ~~en-layout / fixtures: `D4Fixtures.swift:108-109` channel categories~~ fixed in pass 12.
- ~~mp-mine / mp-roam: d4-badges and d4-stamps~~ (badges fixed in pass 14; stamps fixed by mp-roam): d4-badges and d4-stamps (same readers as e5b-badge-wall / e2-stamp-album) still show English data in zh-Hans: `App/ProfileFixtureSupport.swift:50-52` (Fixture city medal, Synthetic unlock condition) and the `RoamExperienceFixtureReader` stamp names. `RoamBadgeWallFlowTests` pins "Fixture city medal" in English, so use a design-only flag like `ClubFixtureReader.designCopy`.
