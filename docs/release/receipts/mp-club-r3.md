# Receipt — mp-club (round 3, 2026-11-27)

Branch `mp/r3-club` from `origin/ui/combined-r7`. Scope: tab 俱乐部 (`pages/talent/list/index`) and the `pages/club/*` subpackage, player side (club owners and admins are players; merchant features left alone). The MP source is `origin/mp-source:chengyinhub-xcx`. Nothing was deployed.

The 21 MP pages were compared section by section, top to bottom, against their native screens. Two pages (talent/list, club/detail) were read in full by hand. The other 19 were split across three read-only diff passes, and each reported difference was then checked in code before it was fixed or skipped.

## Gates (last run, on head of branch)

| Gate | Result |
|---|---|
| `python3 tools/generate_project.py` | OK |
| `python3 tools/check_scaffold.py` | PASS (no FAIL lines; typography lint PASS) |
| `python3 -B tools/check_a11y_lint.py` | PASS: 0 new |
| `python3 -B tools/contract_ratchet.py --check` | 52 failing, baseline 52 (pass 13, after merging combined-r7 again), **new 0**, fixed 0 |
| `python3 tools/check_design_consistency.py` | PASS |

There is no Swift compiler in this environment. Edits are kept type-simple and reuse existing keys, components and patterns.

## Table: MP page → native view → differences → fixed?

| MP page | Native view | Difference (MP ref) | Status |
|---|---|---|---|
| talent/list | `App/ClubHomeView.swift` | The page title is 「发现」 (wxml:19, owner 2026-10-29); native showed 俱乐部. The tab bar item stays 俱乐部 (components/tabBar). This was left as an "owner decision" in fix-r11 A8-06, but the MP answers it. | **Fixed.** `cyRootHeader(.club, titleKey: "club.tab.title")` (new optional `titleKey` on `cyRootHeader`) |
| talent/list · nav | `App/ClubHomeView.swift` | MP 发现 has a 消息 bell with an unread badge in the nav bar (wxml P-13). Native 发现 has 查找俱乐部 + 分享 in the toolbar; messages are reached from 我的 only, and no other tab root has a messages button. | **Not done, flagged.** Adding it needs the messaging session plumbed into ClubHomeView and an app-wide decision (OWNER RULE 2: same toolbar pattern on every root) |
| talent/list · 帖文 | `ClubCommunityFeedView` | A guest's feed is 「登录后查看帖文」 + 登录, not a load failure (wxml:39). Native showed 加载失败 + retry. | **Fixed.** `onSignIn` is passed from ClubHomeView and the view shows a `ContentUnavailableView` with a sign-in button |
| talent/list · 俱乐部 | `ClubHomeView` list | Order matches: 创建俱乐部 → created → joined → nearby; empty, skeleton and error states match. The native inline 加入 pill on nearby rows is not on the MP `cy-club-card`. | Order: matches. Pill: **not changed** (deliberate earlier native addition; flagged for the owner) |
| club/detail · header | `ClubDetailView.swift` `ClubDetailHeader` | The MP header ends at the meta rows (type · N 名成员 / 入会方式). Native added a 「主理人 X · 城市」 line that the MP puts on 概览 (wxml:227-243). | **Fixed.** The host line was removed from the header (also matches the P17 identity header) |
| club/detail · 概览 | `ClubDetailView` overview | The facts grid 主理人 / 俱乐部类型 / 所在城市 under the intro, before 俱乐部勋章, was missing. | **Fixed.** New `ClubOverviewFacts`: 3 cells, value then small label, with a `ViewThatFits` fallback to `LabeledContent` rows (P12). Unknown values read 待补充 |
| club/detail · 帖文 | `ClubCommunityFeedView` (club mode) | MP order is pinned notice → 发帖 pill → posts/empty (wxml:97-158), with the pill above the empty state. Native used a toolbar compose button and put the empty state before the pinned notice. | **Fixed.** Inline composer row (「有什么新鲜好玩的分享吗？」, same gate, same id `club.community.compose`); the empty state now comes after the pill |
| club/detail · 帖文 loading | same | MP: `loading-label` 正在加载帖文. Native showed a bare spinner (P10). | **Fixed.** `ProgressView { Text("club.community.loading") }` |
| club/detail · 帖文 公告 (`components/club-pinned-notice`, `utils/club-pinned-notice.js`) | `ClubCommunityFeedView` (club mode) | MP: section 「公告 · 新人先看」 listing the newest ≤2 pinned 公告 (type 2), each a one-line summary with an unread dot (read ids kept on this device per club, last 50), 「（无文字内容）」 when empty, VoiceOver 「未读公告：…」. Native showed only the first pinned 公告 under a 「公告」 label, no unread state, 「—」 when empty. | **Fixed (pass 6).** `ClubPinnedNoticeReads` (same storage key `cy_club_notice_read_<clubId>`, newest-first, max 2, keep 50; catalogued in `docs/ops-safety/client-data-catalog.json`); a `Section` headed 公告 · 新人先看 with one row per notice (tint dot when unread, `.quaternary` when read, chevron, 44 pt), opening marks it read |
| club/detail · 活动 | `ClubPublicActivityListView` / `ClubActivityListContent` | Matches: cards, 已报名/节点/路线 stats, 发布 +, empty + 发布主题, 出示团码, 邀约承接. | Matches |
| club/detail · tabs / default | `Core/ClubDetailTabs.swift` | Matches: 帖文 / 活动 / 概览 (+管理), default 概览. | Matches |
| club/detail · join | `ClubActionPanel` | MP: a floating 加入 capsule only on 概览 (wxml:1028-1036), with 退出 in the meta row on every tab. Native: a 成员身份 section under the header on every tab. | **Partly fixed (pass 4).** Non-members see the 加入 / 申请加入 / 审核中 section on 概览 only; members keep 退出 on every tab. The floating capsule itself (P17 sticky bottom action) is **not done** (panel lifecycle, contract pins) |
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
| club/event-ops | same | Inline 日期清单 and 重复方式 forms instead of push rows. | **Not done.** large |
| club/notify | `ClubGovernanceCommandForm` (sendNotification) | 当前身份不能发通知 | Already present (`ClubOpsNotifyDeniedText`, a `ContentUnavailableView`) |
| club/notify | `ClubGovernanceCommandForm.swift` | A failed 预览受众 is inline 受众预览失败 + reason + 重试 (wxml:59-62); native showed the generic form error. | **Fixed (pass 3).** Dedicated section before any review, 重试 re-runs the preview (`club.notify.previewFailed`) |
| club/notify | same | 投递状态 is its own section with 刷新 / 刷新中… in the section head, then the five counts and 只重试失败项 (wxml:72-111); native mixed the counts and a 刷新 row into the generic 已提交 receipt section (a parallel pass-4 run had only retitled that section). | **Fixed (pass 5).** New `Section` headed 投递状态 (`club.notify.deliveryStatus` from the parallel pass-4 run, header trait) with a `.borderless` 刷新 button (`notifyRefreshButton`, same id `club.notify.refreshCampaign`) in the header; counts, 只重试失败项 and the refresh notice moved into it |
| club/notify | same | Extra review fact rows: after 预览受众 the MP shows only the preview card 「N 人」 (+ 该分群暂无成员 at 0, wxml:55-64); native repeated 受众/标题/内容 and 站内/订阅消息 as fact rows above it. | **Fixed (pass 7).** The notify review section is the preview summary + the send button only (title/content stay in the form above). Send-button wording 发送给 N 人 kept (deliberate CLB-notify-01 choice) |
| club/governance | `ClubGovernanceViews.swift` (.bans), `ClubOpsMemberActionCard.swift` | Full-page 暂无可治理成员 (wxml:18, js:403: no members and no bans). | **Fixed (pass 3).** The card reports its member count (`onLoaded`); no bans + 0 members shows a `ContentUnavailableView` instead of the records section |
| club/governance | same | Appeal mode: MP page title 封禁申诉 (js:224); native drew it as an in-content headline section. | **Fixed (pass 3).** Inline bar title via `pageTitleKey` (`club.gov.casesAppeal`); headline section removed (OWNER RULE 2) |
| club/customers | `ClubOpsCustomerViews.swift` | The count line sits as the list section header after the filter (native pattern; the count follows the filter); the filtered-empty CTA 查看全部客户 is a borderless button under the empty state, not inside it. | **Kept** (the CTA's fences are pinned in place by `test_club_customer_clear_filters`; moving it needs the clear closure threaded into the list view) |
| club/customer-detail | `ClubOpsCustomerViews.swift`, `ClubCustomerInlineEditor.swift` | In edit mode the editor replaces the card, the heading reads 编辑标签与备注 and 取消 sits in the heading (wxml:82-99). | **Fixed (pass 2).** The editor owns the 标签与备注 section; 取消 moved from a row into the header (VoiceOver: 取消编辑标签与备注) |
| club/payout-receiver | `ClubPayoutReceiverView.swift` | Binding needs a WeChat code (`PayoutReceiverBridge.payoutOpen`). | Blocked (WeChat/backend), not a view gap |
| club/edit | `ClubOperationsViews.swift` | 改为转让主理人 is only inside the dissolve confirm in the MP (scene-club-edit `cy-danger-confirm` alt, utils/danger-actions.js `club.dissolve.alt`); native shows a permanent row. | Not done (pass 5 re-checked: the native confirm is `ClubGovernanceConsequence.sheet` inside the command form, reached through the blockers page; adding the alt there needs a new callback through that shared sheet, too risky without a compiler) |
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

## For other lanes
- mp-home / coordinator: `5e2a0a57f` (17:23) made design fixtures run without `AppSession`; the three fixtures that quit in the 18:15 sweep (d4-badges, d4-stamps/e2-stamp-album, e4-tickets) all touch that path, but no earlier clean sweep covered them, so this is a lead, not a cause. Please attach the simulator crash log to the next sweep so the owning lane can fix the exact line.
- ~~en-layout / fixtures: `D4Fixtures.swift:108-109` channel categories~~ fixed in pass 12.
- mp-mine / mp-roam: d4-badges and d4-stamps (same readers as e5b-badge-wall / e2-stamp-album) still show English data in zh-Hans: `App/ProfileFixtureSupport.swift:50-52` (Fixture city medal, Synthetic unlock condition) and the `RoamExperienceFixtureReader` stamp names. `RoamBadgeWallFlowTests` pins "Fixture city medal" in English, so use a design-only flag like `ClubFixtureReader.designCopy`.
