# FULL REVIEW · Member and club (R2, R3)

Reviewer: Fable 5.2 · 2026-11-15 · read-only (no Figma or code was edited).
File `0YyoybGnU1KG0657wdGCPX`. Pages: R2 `91:656` (小程序还原 · 我的与分包), R3 `91:33` (小程序还原 · 俱乐部).

## 0 · What was reviewed, and how

| Page | Sections | Frames | How it was read |
|---|---|---|---|
| R3 | 22 | 273 | All 21 screen sections rendered at 1×. I read every **optimized twin** and every **new state frame** (ids `219:*` – `237:*`, the A/B club frames) at 0.45×, plus the frames labelled 无需优化. Restored originals that have a twin were not reviewed. The state-kit board `217:4466` was not opened. Montage sheets opened: 22 of 26; the four not opened hold repeats of generic states (登录 / 加载中 / 加载失败 rows for 申请, 报名设置, 核销详情 and 治理), which were checked by metadata only. |
| R2 | 68 | 171 | All 68 sections rendered at 1×. For each page I read the **deliverable**: the twin where one exists, otherwise the restored frame (these pages carry no twin, so the restored frame is the final design), plus all new state frames (`220:*`, `222:*`). Read at 0.45×, except `181:2668` (我的节点玩法, 13,252 pt) and `181:4089` (游戏主题库, 8,314 pt), read at 0.3× as a whole. `181:2046` (营销消息) was legible only in the second pass. |

Three merchant-facing pages sit on R2 (优惠券（商家） `105:1588`, 优惠券详情（商家） `105:1620`, 城市节点领券码 `124:1856`); they are read here for consistency and handed to the merchant-creator review for the plan.

Metadata checks over both pages: copy lint (seeds, raw ids, raw timestamps, WeChat wording, ellipses, spec notes). No contrast tool was run. No prototype wiring was inspected. The owner's Kavsoft video was not playable; sheet behaviour follows the owner's description.

**Result: 39 issues. P0 7 · P1 26 · P2 6.** (Issue IDs are grouped by batch, so the numbering has gaps.)

The five findings that matter most:
1. **The 创建俱乐部 twins show the wrong flow.** Twins 063–066 are the 申请主理人 form again; the real create flow (类型 → 方向 → 资料 → 城市) exists only in the new state frames. The prototype on page P uses the wrong ones (MC-01).
2. **Two generations of frames disagree** inside one flow: twins use a disabled grey primary and square check rows; the new state frames use red-field validation, inverted white selection and small centred pills. Titles even change style between "loaded" and "loading" (MC-10 to MC-14).
3. **Organiser pages put actions in tiny text.** "退出", "举报", "权限 / 临时封禁 / 移除", "填写原因并封禁", "标记到场": coloured 11–12 pt words, often three in a row, some destructive (MC-20, MC-21).
4. **Collections have no art.** Every badge is the same star; badges are also listed as rows with a single character; stamps, collectibles and the 3D badge are placeholders (MC-30).
5. **Spec boards are drawn as screens.** Seven frames stack several results or alerts in one phone (MC-03).

The best work in scope, to copy elsewhere: the 主题管理详情 phase frames (`229:4738` – `229:5267`: one primary per phase), the "现在要做" card (`170:1546`, `236:8305`), the 解散前待处理 sheet (`236:8799`), and the delete dialogs that list consequences (`222:5684` – `222:6126`).

---

## 1 · References (20, none repeated from round 1, the config review or the player review)

### A · Community and club apps (Mobbin)

| # | Reference | What it shows | Lesson for R2 / R3 |
|---|---|---|---|
| 1 | Strava · [club overview](https://mobbin.com/screens/fb3cb106-e75f-4e35-b0c4-2d9224fd256e) | Admins as rows with an "ADMIN" tag; "View all members ›"; sections with plain chevron rows; **Leave Club** and **Report Club** as two full-width buttons at the very end of the page. | "退出" is not a 11 pt word beside 公开加入. It lives at the end of 概览, full width, once. 举报 sits beside it. |
| 2 | Strava · [invite to club](https://mobbin.com/screens/f9ee4d9a-fcf9-4d38-8e93-9386a3bd566c) | Sheet: Close · title · Invite (disabled until a pick); three large icon actions (Copy Link, QR Code, Share); search; rows with a trailing check box. | 邀请成员, 选择成员 and 颁给谁: one pattern. Icon actions on top, multi-select rows, the confirm in the header, disabled until something is picked. |
| 3 | Strava · [challenges](https://mobbin.com/screens/f4783627-f3aa-4592-a33f-654142ef4ce2) | Three underline tabs; filter chips with icons; cards with badge art, one sentence, dates, one **Join** button. | A club activity or goal card: art, one line, dates, one button. 探索目标 (`129:1515`) has no art and no progress bar. |
| 4 | Discord · [server sheet](https://mobbin.com/screens/c010d8ae-2788-4f47-ad16-ffa066c70ca5) | Grouped list: plain rows, switch rows with a one-line explanation under the label, then "Report Server" and a red "Leave Server" as rows in their own group. | 俱乐部设置 already looks like this. Add the one-line explanations under switches, use one switch tint, and put destructive rows in their own last group. |
| 5 | Discord · [channels and roles onboarding](https://mobbin.com/screens/deb6d3b3-6f1e-457e-a520-4cca12a8a3d3), [multi-select cards](https://mobbin.com/screens/b49ee8f7-13c5-4364-b208-fa33a26a6f28) | Question as a headline; option cards with an icon, a title and one line; the selected card gets a border and a check badge; a footnote says what the choice does ("You will receive the @… role"). | 申请主理人 and 创建俱乐部 steps: option cards with a check badge, not rows with a square box or an inverted white row. A footnote says what the answer changes. |
| 6 | Luma · [event page](https://mobbin.com/screens/fc225571-3761-4e53-96d8-ae3ad2d5ecd0) | Cover, title, host row, date, an amber "3 Spots Left" line, then a row of three buttons: one filled (Register) and two quiet (Contact, More). | Club header actions: one filled primary (加入 / 报名), two quiet. Scarcity as one coloured line, not a tag pile. |
| 7 | Luma · [registration](https://mobbin.com/screens/ff8bd7fd-4a6e-4d7a-81b0-009dcc75c48f), [waitlist form](https://mobbin.com/screens/fbac8eac-b349-45f8-bac4-18fb28ee7df6) | Event summary on top; ticket as a row; one consent line with a circle check; the total; the button carries the amount ("Pay US$5.00"). Waitlist: the same form with "Join Waitlist". | 候补 and 报名 are the same sheet with a different verb on the button. The button names the amount. |
| 8 | Partiful · [host event bar](https://mobbin.com/screens/6e1aa0f0-958f-46fe-83c9-d4c31d960efc) | A host sees a floating bar: Edit · Text Blast · **0 Pending** (large, centre) · Invite · More. | The organiser's bar leads with the number that needs action (待审批, 待核销), not with five equal icons. Matches the "现在要做" card. |
| 9 | Facebook · [group page](https://mobbin.com/screens/12336515-67fb-42ac-959a-2449b3135cf9), Cal AI · [groups list](https://mobbin.com/screens/74453193-0f6b-4a4d-951f-4d5cefdd8df4) | Cover, name, "Public group · 106.6K members", one full-width **Join group**, chips, composer, feed. List: avatar, name, member count, one line, "+ Join" pill. | The 加入 button is in the header, full width, before the tabs. Today it floats over the leaderboard. |

### B · Membership, orders, collections (Mobbin)

| # | Reference | What it shows | Lesson |
|---|---|---|---|
| 10 | talabat · [orders](https://mobbin.com/screens/dc389c20-f77b-4bb3-9dd8-ae52517fe5b2) | Each order: a coloured status tag with the time on top, the merchant row, the amount with "View details" as a link, and **one** pill for the next action (Track order filled; Order again outlined). | 我的订单: status as a tag, one action per card that depends on state (去支付 / 开始 / 再来一次). Not two 20 pt pills. |
| 11 | Wolt · [your orders](https://mobbin.com/screens/1571d997-30f5-4d0f-b371-91e0fb45358f) | Two equal tinted buttons under each order (View details, Order again); a two-segment switch on top. | When there are two actions, they are full-width and 44 pt, not text. |
| 12 | Shopify · [order timeline](https://mobbin.com/screens/4b1b9a6d-3fe4-44ee-aba3-f0766270ecea) | A dated vertical timeline: time above each event, one sentence, an inline link for the follow-up. | 订单进度, 举报进度 and 治理记录: one timeline component, newest first, time above the event. Three different timelines exist today. |
| 13 | Reddit · [achievements](https://mobbin.com/screens/74ea7ef7-6fc8-4ca8-af3d-2ad3e160a256) | A 3-column grid; every badge has its own art; a count chip for repeats; one button "View your achievements". | Each badge needs its own art. A grid of ten identical stars is a placeholder, not a collection. |
| 14 | Cal AI · [locked badges](https://mobbin.com/screens/a67ac8fb-bd7b-49c5-ba86-29d70fc21024) | Locked badges are the same shape embossed in grey, with the name and the condition under each; earned ones are in colour. | Locked = the same art in monochrome plus the condition. Round 1 said the same; it is still open. |
| 15 | Apple Games · [achievements](https://mobbin.com/screens/43c701fa-a4b4-4191-bdc2-ba5bd7a84a5b) | Locked achievements show a ring with the percentage, the name and the goal. | In-progress badges show progress (`3 / 7 天`), which 探索目标 and 勋章 both lack. |

### C · Official guidance

| # | Reference | Key guidance | Lesson |
|---|---|---|---|
| 16 | [Material 3 · Lists](https://m3.material.io/components/lists/guidelines) (the page did not render in this session; points below are from the search summary of that page and from the [Compose `ListItem` documentation](https://kotlinlang.org/api/compose-multiplatform/material3/androidx.compose.material3/-list-item.html)) | Supporting text is capped at three lines. Visuals and primary text keep a fixed position from row to row. Secondary actions belong in the trailing slot; a leading icon must be relevant to the label. Slots: overline, headline, supporting, leading, trailing. | A row has one trailing element. Today rows carry three trailing text actions (成员管理), or a pill plus a tag plus a chevron (我的队伍). Keep rows to: leading visual, headline, one supporting line, one trailing element. |
| 17 | [Android · Lists](https://developer.android.com/design/building-blocks/lists.html) | Elements align to the top once a row is 88 dp or taller or has three or more lines. | The tall rows (活动运营 日期清单, 报名名册) should top-align their trailing control instead of centring it against four lines of text. |
| 18 | [HIG · Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) | "Use an info button only to reveal more information about a row's content." "Keep item text succinct." "Provide appropriate feedback when people select a list item." | Chevron = navigates. Check = selected. A word like "选择 / 已选" in the trailing slot is neither. |
| 19 | [HIG · Action sheets](https://developer.apple.com/design/human-interface-guidelines/action-sheets) and [Menus](https://developer.apple.com/design/human-interface-guidelines/menus) | "Use an action sheet — not an alert — to offer choices related to an intentional action." "Make destructive choices visually prominent." Context menus: "Always make context menu items available in the main interface, too." | 我的项目 hides all management behind "长按卡片管理". Long-press may stay as a shortcut, but each card needs a visible "⋯". |
| 20 | Kavsoft · [Resizing Scrollable Sheets Using SwiftUI](https://youtu.be/WRgYhvxNOqE) (owner reference; not playable in this session) | Detents resize with the content; scroll only at full height; a spring between detents. | Section 3 lists every sheet in scope with detents. |

---

## 2 · Shared decisions (the player kit from `full-player.md` section 2 applies; additions for organiser pages)

| Topic | Decision |
|---|---|
| Row | Leading visual (avatar 36, icon 24, or thumbnail 44), headline 15, one supporting line 13, **one** trailing element: chevron, check, switch, tag, or a "⋯" menu. Minimum height 52. |
| Row actions | In the "⋯" pull-down (or swipe). Destructive last and red. Never a word in the value column. |
| Pick-one / pick-many sheets | Rows with a trailing check mark (many) or a check on the picked row (one). The confirm is the sheet's primary, with the count: `选好了 · 2 人`. |
| Option cards (wizards) | Card with icon, title, one line; selected = 1.5 pt white border + check badge. |
| Status | `Player/Status Tag` with icon: 进行中 (green), 待处理 (amber), 已结束 (grey), 未通过 (red). Blue is not used. |
| Money | Real money (orders, tickets, settlement) keeps ¥ with two decimals in bills. Points are 积分 with the coin. A row never shows both without labels. |
| Dates | `11月22日 周六 14:00`. Never `2026-11-12 19:26:07`, never a raw id as a subtitle. |
| Nav title | One style per page in every state: large left title with a back chevron. Generic states keep the same title. |
| Destructive page action | A quiet red row in its own last group (Discord, Strava). A red filled button is used only inside the confirmation. |
| Confirmation | Reversible or light: `confirmationDialog`. Heavy with consequences (refunds, deletion of sessions): the existing consequence dialog, rebuilt as a `fit` sheet with a red primary. |

---

## 3 · Sheets: resizable scrollable sheets (owner reference)

Behaviour and values as in `full-config.md` section 3: opens at the smallest detent that fits, grows by drag, scrolls only at the largest detent, `spring(response: 0.38, dampingFraction: 0.86)`, `.selection` on settle, cross-fade under Reduce Motion. `fit` = `.height(content)` capped at 62%.

| Sheet | Frames | Detents | Notes |
|---|---|---|---|
| 欢迎加入 | `204:24751` | `fit` | |
| 俱乐部设置 | `223:3376`, `223:3573`, `223:3698` | `.large` only | A settings list is a full-height task. 成员管理 and 项目工具 push inside it instead of expanding inline. |
| 选择要管理的俱乐部 / 选择俱乐部 | `223:3815`, `236:15461` | `fit` | |
| 发帖 / 编辑动态 | `223:3888`, `223:4059` | `.medium`, `.large` | Keyboard raises to `.large`. Not dismissible by swipe when there is text. |
| 带上一次游玩记录 | `223:3974` | `fit`, `.large` | Pushes inside 发帖 rather than opening over the page. |
| 编辑历史 | `223:4213` | `.medium`, `.large` | |
| AI 策划活动 | `224:5082`, `224:5158`, `224:5236`, `224:5321` | `.medium`, `.large` | Grows to `.large` when the plan arrives: the clearest use of the spring in this area. |
| 选择场次 / 选择导演场次 | `224:5459`, `224:5542`, `231:3815`, `236:14605` | `fit` | |
| 团核销码 / 活动核验团码 | `224:5619`, `204:25159`, `236:14648`, `236:14686` | `fit` | Screen brightness up while open. |
| 发布什么 | `224:5687` | `fit` | |
| 排序方式 | `222:5555` | menu | A three-item sort is a pull-down menu on the "综合" label, not a sheet. |
| 创建勋章 | `236:8032` | `fit` | |
| 颁给谁 | `236:8101` | `.medium`, `.large` | |
| 俱乐部类型 / 活动倾向 | `236:8491`, `236:8596` | `fit` | |
| 解散前待处理 / 暂时不能解散 | `236:8799`, `236:8924` | `fit`, `.large` | |
| 选择成员 / 选择角色 / 选择期限 | `236:15069`, `236:15141`, `233:13671`, `233:13751` | `fit`, `.large` | |
| 主题管理 · 更多 | `231:2826` | `.large` only | |
| 商家 / 报名参与者 / 队伍进度 | `231:2955`, `231:3033`, `231:3131` | `.medium`, `.large` | |
| 承接商家 (节点 / 章节) | `231:4209`, `231:4307` | `.medium`, `.large` | |
| 角色分配 / 定向广播 / 现场事件 / 章节放行 / 默认结局收尾 / 通用玩法现场运营 | `231:3203`, `231:3301`, `231:3394`, `231:3481`, `231:3554`, `231:3895` | `fit`, `.large` | Forms: keyboard raises to `.large`. |
| 修改集合时间 | `231:3629` | `fit` | Native date and time pickers. |
| 退出与暂停规则 | `231:3715` | `.medium`, `.large` | Reading sheet. |
| 结果 (活动已开始 / 没有结束成功) | `231:4129` | `fit` | One result per frame (MC-03). |
| 答案 (钟楼报时) | `236:15627` | `.medium`, `.large` | |
| 我的项目 · 管理 | `222:2761` | system menu | Becomes a context menu on the card's "⋯". |
| 审核记录 + 申诉 | `222:2890` | `.medium`, `.large` | |
| 删除 / 取消 confirmations | `222:5684`, `222:5798`, `222:5906`, `222:6014`, `222:6126` | `fit` | Rebuilt as sheets with the consequence list; red primary. |
| 优惠券核销码 | `105:778`, `204:30633` | `fit` | |
| 节点详情 (店铺相册) | `124:2216` | `.medium`, `.large` | |
| 票夹筛选 | `204:29958` | menu | Already a pull-down. |
| 优惠券已发布 (商家) | `222:6320` | `fit` | |

---

## 4 · The plan

Format: **ID · severity · title**, then frames, problem, optimize, implement (Figma; SwiftUI; motion where it applies).

### Batch A · Defects (no design decisions)

**MC-01 · P0 · The 创建俱乐部 twins show the 申请主理人 form**
- Frames: twins `204:24591`, `204:24631`, `204:24676`, `204:24716` (titles "先认识一下你 / 你带过多少场？ / 你能自己做哪些？ / 有资质就传一份", last button "成为俱乐部主理人"); they copy the restored captures `94:985`, `94:1066`, `94:1147`, `94:1218`, which were taken while the account was not yet a host. The real flow is in `225:13448` (首屏), `225:13493` (类型), `225:13553` (方向), `225:13605` (资料), `225:13652` (城市). Page P uses the wrong twins as create1–4 (`209:16053`, `209:16076`, `209:16104`, `209:16127`).
- Optimize: the twins of 063–066 are rebuilt from the four real steps. The apply form stays only under 申请俱乐部.
- Implement: Figma: replace the four twins with redrawn copies of the `225:*` steps on the kit of MC-10; relink page P flow 5. SwiftUI: two separate flows, `ClubHostApplyFlow` and `ClubCreateFlow`.

**MC-02 · P0 · QA, seed and raw strings in member and club frames**
- Frames: R2: `181:2119` (发票抬头: "烟测幂等抬头", "烟测个人抬头", "烟测临时抬头" × 8), `181:2222`, `181:2668` (smoke-tpl ids, `2026-11-14 23:21:54`), `184:7016`, `184:7219` ("E2E API smoke check" × 10, "smoke-team-7a5a"), `204:29429`, `204:30275` ("RW TEST pledge coupon"), `105:778` ("E2E 商家优惠券"), `181:3539` ("老城三章 · E2E 测试主题"), `181:3637` ("订单号 PPO_SH_9004_001"), `181:2101` ("订单号 A20261114BFD9A9D0" as the page's first line), `184:6584`, `184:6718` ("A20261114E2E0002"), `116:1650` ("E2E 举报流程示例（用于举报详情与进度页展示）"), `104:1518`, `104:1576` ("E2E 咨询：…"), `181:3474` (`2026-11-12 19:26:07`), `204:29833` ("商家二号 / 三号 / 四号"). R3: `94:2846`, `94:2916`, `94:2971`, `94:3018` ("E2E 玩家小城", avatar "E"), `204:24948`, `204:25026` ("E2E 玩家小城", "E2E 玩家二号"), `170:7584`, `170:7698` ("E2E 玩家二号"), `204:25191` ("商家二号"), `236:14727` ("申请人 9005"), `97:3808` ("场次 #992031"; the twin `204:25205` already shows the date), `96:4496` ("主题 #992001 · 系列 #992531"; fixed in the twin `170:7698`).
- Optimize: seeded Chinese names (玩家小城, 阿兰, 小李, 周行), real titles, order numbers on one monospaced line under 更多信息, dates per section 2.
- Implement: Figma text swaps.

**MC-03 · P0 · Spec boards drawn as phone screens**
- Frames: `224:5777` (three alerts in one frame: 删除帖文, 删除评论, 退出俱乐部), `233:12879` (three results of 取消本场 stacked), `236:14771` ("预览结果 · 三种状态" under the send button), `229:5341` (four status blocks: 操作处理中, 结果待确认, 无法安全提交, 默认结局收尾), `231:4129` (a success and a failure result in one sheet), `236:8305` (six "现在要做" cards stacked), `236:8240` (three states of the stats block stacked).
- Problem: an executor or engineer will read these as real screens.
- Optimize: one state per frame, or move the board outside a phone frame and label it "状态板，不是页面".
- Implement: Figma: split into frames (reuse the base page); name them by state.

**MC-04 · P0 · Layout bugs**
- Frames: `225:13553` ("已选 2 / 3" overlaps the fourth chip row); `222:4578` (the floating 加入 pill covers the first leaderboard row's score); `94:5125` restored switches overlap their labels (fixed in the twin `170:935`: verify the three switches); `236:14845` (error text overlaps the field label "内容"); `181:3539`, `181:3603` (通行证详情 and 通行证（会员）have no purchase button in the frame); `204:34773` (附近: the bottom card's cover is a cropped avatar; a yellow diagonal line crosses the map).
- Optimize: fix the auto-layout; the join button moves into the header (MC-22); pass pages get a sticky bar with the price and `开通`.
- Implement: Figma layout fixes.

**MC-05 · P1 · WeChat-only wording**
- Frames: `184:6584`, `184:6718` ("支付方式 微信", "微信实付"); `104:1518`, `104:1576` ("手机号/微信（可选）"); `204:24591` ("手机号或微信号").
- Optimize: the payment method is a value (`Apple Pay`, `微信支付`) under the label `支付方式`; `实付`. Contact: `手机号`.
- Implement: text edits.

### Batch B · One kit across twins and new states

**MC-10 · P0 · Wizards: three looks for one flow**
- Frames: 申请: twins `204:24431`, `204:24471`, `204:24516`, `204:24556`; states `225:13062`, `225:13107`, `225:13162`, `225:13208`. 创建: states `225:13448` – `225:13781`.
- Problem: twin step 1 has a grey disabled 下一步 with a filled phone number; the validation state `225:13107` shows red fields **and** a disabled button (disabled, yet errors are showing). Step 3 options are rows with a square box; 类型 (`225:13493`) marks the selected row by turning it white with a black radio; 方向 uses white chips. 城市 (`225:13652`) is a typed text field.
- Optimize: one wizard kit: 4-segment progress, eyebrow, question headline, option cards (section 2), an always-enabled primary that jumps to the first missing answer, inline errors under fields. 城市 is a picker row (current city preselected). The last apply step's button reads `提交申请`.
- Implement: Figma: `Wizard/Step` (Progress, Eyebrow, Title), `Wizard/Option Card` (Kind = Single / Multi; State = Default / Selected), reuse `Player/Button`. SwiftUI: `TabView(.page)` or a `NavigationStack` path; `ScrollViewReader` + `@FocusState` for the error jump. Motion: step slides 350 ms ease-out; progress segment fills 220 ms; option select: border draws 140 ms and the check badge pops (scale .6 → 1, 220 ms); haptic `.selection`; error jump: shake 240 ms, `.error`.

**MC-11 · P1 · The title changes style between "loaded" and "loading / empty / error"**
- Frames: 客户名册 `94:2971` (large left "客户") versus its states `234:4145`, `234:4198`, `234:4236`, `234:4274`, `234:4311` (centred "客户名册"); 客户详情 `94:2846` (centred "客户") versus `234:4348` – `234:4460` (centred "客户详情"); 报名名册 `204:25026` (large left) versus `234:4498` – `234:4627` (centred); 核销详情, 入会申请, 角色与权限, 群发通知 (large left "群发通知" versus centred "通知成员" in `234:5097`, `234:5133`, `234:5171`), 俱乐部勋章, 活动运营, 结算, 剧情与玩法 and 主理人工作台 (centred "俱乐部管理" in `234:4067`, `234:4107`) follow the same split.
- Problem: the page jumps when data arrives, and two names are used for one page.
- Optimize: one name and one title style per page (section 2). Generic states are the page's own layout with the content area replaced.
- Implement: Figma: `Player/State` placed inside the real page frame (title kept); rename to the page's one name. SwiftUI: state switches inside one view; `.navigationTitle` constant.

**MC-12 · P1 · Generic states: small pill, position and wording vary**
- Frames: all K/State frames in R3 (about 70) and R2 (`222:3001` – `222:3206`, `183:4904`, `184:6889`, `220:9675` – `220:9816`). Top-pinned variants in R2: `100:5314`, `183:4666`, `183:4873`.
- Problem: the action is a 36 pt white pill; the block sits at about 20% from the top in some frames, 45% or 60% in others; "去登录" (`224:5895`) versus "登录" (`225:13372`, `222:3001`).
- Optimize: one component at 40% height; action 44 pt; `登录`; `重试`; `返回` only where there is nowhere else to go.
- Implement: `Player/State` from the player kit; swap all instances.

**MC-13 · P1 · Two switch tints and mixed row accessories in settings**
- Frames: `223:3376` (俱乐部公开可见: green; 允许成员发帖: white knob on grey, both "on"-looking), `231:2826` (green), `170:7698` (满员后开启候补: green), `181:2046` (green on, white off), `170:935` (white), `204:24556` (white).
- Optimize: one switch component and one tint (neutral white on-track per the owner's neutral ruling, or system green: pick one for the whole player theme; the plan uses neutral). Each switch row gets one explanation line.
- Implement: Figma: single `Player/Switch`; swap. SwiftUI: `Toggle().tint(...)`.

**MC-14 · P1 · Arrows, chevrons and "查看"**
- Frames: "→" arrows in `170:1744` (five accordion rows), `104:1576`, `204:29996`, `181:1966`, `116:1650`; chevrons in the state frames `222:5036` – `222:5463`; "查看" as trailing text in `204:29258`.
- Optimize: chevron for navigation everywhere; nothing else.
- Implement: icon swap in the row component.

### Batch C · Club pages (R3)

**MC-20 · P0 · Destructive and moderation actions are tiny coloured words**
- Frames: `204:24850`, `204:24899` ("退出" in 11 pt grey at the right of 公开加入); `222:4816` ("举报" on every member row); `219:3463` ("举报 / 删除" on every comment); `223:3698` (three words per member: 权限 · 临时封禁 · 移除 in red); `97:3584`, `233:13436` ("填写原因并封禁" in red and "选择成员" in amber as row values); `233:13154` (red "移除" per date); `236:8395` (tag chips with a 10 pt ×).
- Problem: actions that remove people or content are the smallest text on the page, sit 6 pt apart, and have no confirmation drawn for most.
- Optimize: member, comment and post rows get one "⋯" menu (举报, 设为管理员, 临时封禁, 移除: destructive last, red). 退出俱乐部 and 举报俱乐部 move to the end of 概览 as two rows (ref 1). 成员治理 becomes a short form: 成员 (picker row), 期限 (picker row), 原因 (text), then one red-outlined button `封禁`; 转让主理人 is its own row that opens its own confirmation.
- Implement: Figma: `Player/Row` with `Menu` accessory; redraw `97:3584` as a form. SwiftUI: `Menu`, `.swipeActions`, `.confirmationDialog`. Motion: a removed row collapses and fades 180 ms; haptic `.warning` on the confirmation, `.success` after.

**MC-21 · P1 · Buttons under 44 pt across organiser pages**
- Frames (visual height): 通过 / 拒绝 28 (`204:25191`, `236:14727`); 颁发 28 (`236:8101`); 选择 / 已选 pills 24 (`236:15069`, `236:15141`); 标记到场 / 更正未到 26 (`233:12699`, `233:12748`); 出示团码 and "⋯" 24 (`219:3687`); 活动导演台 / 场次工具 22 (`170:1744`); 发送 28 (`219:3463`); "+ 发布" 24 (`219:3687`); 审核记录 / 删除 / 从广场下架 24 (`222:2722`); 查看详情 / 申请退款 / 取消报名 20 (`181:3294`); 进入队伍 22 (`184:7219`); 编辑 28 (`94:2846`).
- Optimize: rows are the tap target (52 pt). Where a row needs an explicit button (审批, 到场), it is a 36 pt visual pill with a 44 pt target, and the pair is 12 pt apart. Approve / reject also works by swipe.
- Implement: component hit areas; `.swipeActions(edge: .trailing) { 通过 }`. Motion for 审批: the card slides out in the swipe direction 220 ms, the count in the header ticks down; haptic `.success` (通过) or `.impact(.light)` (拒绝).

**MC-22 · P1 · Club home: the join button floats; three truncating tiles; an oversized welcome**
- Frames: `222:4578` (未加入), `222:4679` (申请中), `222:4747` (未通过), `204:24850`, `204:24899`, `222:4917`, `204:24751`.
- Problem: 加入 is a small pill floating over the leaderboard; the three info tiles truncate ("海派城市漫…"); the sort control "综合" is 11 pt; the welcome sheet has two buttons of equal weight.
- Optimize: header: cover, name, "城市探索 · 4 名成员 · 公开加入", then one full-width primary (`加入` / `申请中` disabled with the reason / `重新申请`), with share as a glass circle. The tiles become one line of text under the description (`主理人 海派城市漫游团 · 上海`). 贡献榜 keeps the "我" row pinned. Welcome: one primary `去看活动`, 知道了 as a text button.
- Implement: Figma: `Club/Header` (State = Visitor / Pending / Rejected / Member / Manager). SwiftUI: `safeAreaInset` not needed; the button is in the header. Motion: on join, the button morphs into the member state (220 ms), the member count ticks up, the welcome sheet rises; haptic `.success`.

**MC-23 · P1 · Club settings: inline expansion, raw version labels**
- Frames: `223:3376`, `223:3573`, `223:3698`, `223:4213` ("v2 / v1 / v0" as labels).
- Problem: 项目工具 and 成员管理 expand inside the sheet and push the list; the edit history shows version codes.
- Optimize: both push to their own page inside the sheet. History rows read `11月14日 19:26 · 修改了正文`. Groups get the order: 成员 · 内容 · 运营 · 经营 · 资料 · (last) 解散俱乐部 in red.
- Implement: `NavigationStack` in the sheet; text edits.

**MC-24 · P1 · 活动运营 mixes four tasks on one 2,000 pt page**
- Frames: `170:7584`, `170:7698`, `233:12652` – `233:13236`.
- Problem: 本场管理, 本场名册, 日期清单 and the 重复方式 form with 容量与候补 share one scroll. An amber two-line warning sits as body text. Dates and times are dropdowns ("2026-11-15", "09:00"); "候补认领时长 1440" is in minutes with "1 天" beside it.
- Optimize: the page is 本场: status, the attendance list with its count chips, and one primary for today's task (`核销` / `标记到场`). 日期清单 is a row that opens the schedule page; 创建系列场次 is a pushed form with native date and time pickers and a duration picker (`1 天`). The warning becomes a status banner with an icon.
- Implement: Figma: split into three frames; reuse `Editor/Field` number-with-unit from the config kit for capacity. SwiftUI: `DatePicker`, `Picker` for duration. Motion: 标记到场: the row's avatar gets a check badge (220 ms pop), the row moves to 已到场 with a 300 ms slide when the filter is 全部; the chip count rolls; haptic `.success`.

**MC-25 · P1 · 报名名册 and 核销详情**
- Frames: `204:24948`, `204:25026`, `236:9110`, `204:25104`, `236:9181`, `236:9241`, `236:9297`.
- Problem: seven cards with the same route placeholder; the expanded card prints "实收 ¥78.00 已退 ¥0.00 净额 ¥78.00" at 10–11 pt; attendee status is coloured text only. 核销详情's tracker has four 10 pt labels; the 待核销 state's only button is a red full-width "清退并退款"; the phone is unmasked in one state and masked in another.
- Optimize: roster rows: cover thumbnail, title, date, `5 / 50` with a thin capacity bar. Expanded: a three-number row (实收 · 已退 · 净额) at 15 pt, then attendees with status tags. 核销详情: primary `核销` (white); 清退并退款 moves to "⋯" with a consequence sheet. Phones are always masked with a "显示" tap.
- Implement: Figma: `Club/Roster Card`, reuse `Player/Status Tag`. SwiftUI: `DisclosureGroup`. Motion: capacity bar fills on appear 400 ms; expansion 300 ms.

**MC-26 · P1 · 群发通知 and 角色与权限: "选择 / 已选" as text**
- Frames: `170:1313`, `170:1353`, `236:14771`, `236:14845`, `236:14908`, `204:25205`, `236:15069`, `236:15141`, `236:15220`.
- Problem: audience rows end in the words "选择", "已选" or "无成员"; the "可见客户手机号 是 / 否" control is a tiny two-segment; the 分配 button is disabled without a reason.
- Optimize: audience rows are multi-select with a trailing check and the count (`本场已报名 · 1 人`); empty audiences are dimmed with `0 人`. The primary carries the number: `发送给 1 人`. 可见客户手机号 is a switch row with an explanation. 分配 stays enabled and points at the missing pick.
- Implement: `List(selection:)`; `Toggle`. Motion: sending: the button shows progress, then the result sheet (`已发送给 1 人`) with the check drawing; haptic `.success`.

**MC-27 · P1 · 主题管理详情: keep the phase model, fix the edges**
- Frames: `170:1433`, `229:4738` – `229:5267`, `231:2826` – `231:4307`.
- Problem: the phase frames are the best pattern in scope (one primary per phase: 开始准备 → 开始活动 → 去核销 → 查看结算报告). Edges: the 接下来 list is five grey rows of three lines each; "已有报名 · 已锁定" is a pill that looks tappable; 角色分配 (`231:3203`) holds a nested form with its own 取消接管 / 确认接管 above the sheet's 确认分配 (two primaries); 结束主题 is a red row among normal rows; the irreversible alerts are plain system alerts while lighter deletions elsewhere get the consequence dialog.
- Optimize: 接下来 shows the next session large and the rest as a "还有 4 场 ›" row. Locked values are plain text with a lock glyph. 接管 pushes to its own page. 结束主题 moves to the last group. 结束活动 and 结束主题 use the consequence sheet (they refund people).
- Implement: Figma: reuse `Club/Phase Card`; move rows. SwiftUI: as section 2. Motion: starting an activity: the status tag changes with a 220 ms cross-fade, the primary morphs to the next phase's label, the readiness checklist collapses (300 ms); haptic `.success`.

**MC-28 · P1 · 主理人工作台: the "现在要做" card is right; the rest dilutes it**
- Frames: `170:1546`, `170:1744`, `222:5036` – `222:5463`, `236:8240`.
- Problem: five equal icon actions above the card; a statistics table with rows like "0 / 0 · —" at 10 pt; seven theme rows each with two 22 pt pills; then five accordion rows.
- Optimize: order: 现在要做 (first, with its one primary), then three numbers that matter (待审批 · 待核销 · 本周场次) as tappable tiles, then 项目 as rows with a status tag and a chevron (the two pills move into the project page), then the five management entries as a plain grouped list. Icon actions shrink to two (扫码, 团码) in the nav.
- Implement: Figma: reorder; `Club/Now Card`, `Player/Stat Tile`. SwiftUI: `List`. Motion: the Now card's amber dot pulses once on appear (600 ms), not in a loop.

**MC-29 · P1 · 结算, 个人收款, 会费**
- Frames: `236:15318`, `236:15388`, `236:15514`, `97:3782`, `236:14951`, `236:14982`, `233:3264`, `233:3365`.
- Problem: the withdraw action is "联系平台客服提现" (a support hand-off as the primary); "金额待核验" is amber 20 pt text where the amount should be; settlement rows print fee lines at 10 pt; 会费设置 shows plan fields as static key–value rows with units in labels ("价格(元) 39", "期限(天) 30").
- Optimize: say what the button does: `申请提现`, and if it truly opens support, a line above explains why (`提现由平台客服办理，1 个工作日内回复`). Pending amounts show `—` with a tag `核验中`. Settlement rows: title, date, the net amount; fee lines behind the row. 会费: plan cards (name, `¥39 / 30 天`, status tag) that open an editor with number fields and unit suffixes.
- Implement: Figma: redraw N01 with `Editor/Field` number-with-unit; `Player/Status Tag`. SwiftUI: `Form`.

**MC-30 · P0 · Badges and collections have no art**
- Frames: `204:30158`, `204:30041` (ten identical star badges, two greyed), `204:29258`, `204:29139` (badges as rows with one character: 初, 通, 城, 连), `94:2803` (club badges with photos as their art), `94:4064` (徽章 3D: a flat gold circle), `94:4087` (藏品: scattered white squares), `204:30010` (邮票: an empty gradient), `183:4653` (集邮相机: a grey box), `128:1266` (集章相机: a black box and a circle).
- Problem: the reward system is what players collect, and it is drawn with placeholders. The Apple Design Award criteria ask for "high-quality animations with a distinctive and cohesive theme".
- Optimize: a badge art set in one style (the A40 shield family: shape by category, emblem by badge). Grid of three per row; locked = the same art embossed in grey with its condition; in progress = a ring with `3 / 7`. 成长中心 shows the latest three badges as art, not rows. The badge detail is the 3D view with tilt. Stamp and collectible cameras reuse the claim camera from N20 (viewfinder, shutter, guidance line).
- Implement: Figma: `Badge/Art` component set (at least the 12 badges named in the frames), `Badge/Tile` (State = Earned / Locked / InProgress). SwiftUI: `LazyVGrid`; detail with `CMMotionManager` tilt. Motion: grid tiles rise in a 30 ms stagger on first appear; unlocking plays the stamp spring from the player review (PL-46); haptic `.success`.

**MC-31 · P2 · 剧情与玩法, 承接商家, AI 策划**
- Frames: `100:4052`, `236:15574`, `236:15627`, `236:15676`, `231:4209`, `231:4307`, `224:5082` – `224:5321`.
- Problem: small ones. The route timeline is good. AI presets are plain sentences in chips ("静安 情侣 夜间 Citywalk 90分钟"); the generated plan is one long block of text; "生成中…" has an ellipsis.
- Optimize: presets as chips with an icon and two words; the plan as sections (路线 with numbered stops, 风险提示 as rows, 宣传文案 with a copy button), collapsed to their headers when the sheet is at `.medium`.
- Implement: `DisclosureGroup`s. Motion: stops appear in a 120 ms stagger; the route line draws 600 ms; `.success` when ready.

### Batch D · Member pages (R2)

**MC-32 · P1 · 我的项目 hides management behind a long press**
- Frames: `91:1288`, `222:2633`, `222:2722`, `222:2761`.
- Problem: the only hint is "长按卡片管理" in 11 pt. The 模板 tab instead shows three 24 pt pills per card (从广场下架, 审核记录, 删除) and three lines of red rejection text.
- Optimize: every card gets a "⋯" button that opens the same menu the long press does (ref 19). Status is a tag at the cover's corner. The rejection reason is one line with `查看原因 ›`.
- Implement: `.contextMenu` plus `Menu`. Motion: context menu is the system's (lift + haptic).

**MC-33 · P1 · The delete dialogs are good content in a custom card**
- Frames: `222:5684`, `222:5798`, `222:5906`, `222:6014`, `222:6126`.
- Problem: they list consequences and offer a softer alternative ("改为下架场次 ›"), which is right. They are drawn as centred cards with a red filled button and a wrapping title.
- Optimize: a `fit` sheet: title on one line (`删除场次`), the object name under it, the consequence rows with icons, the softer alternative as the secondary button, the destructive action as a red pill at the bottom. This is the heavy-confirmation pattern for the whole app (section 2).
- Implement: Figma: `Player/Consequence Sheet`. SwiftUI: `.sheet` with `presentationDetents([.height(h)])`. Haptic `.warning` on present.

**MC-34 · P1 · 城瘾玩法: the twin removed the only primary buttons**
- Frames: `181:1536`, `181:1711`.
- Problem: the restored page had white 去看看 / 开始 pills; the twin turned all nine into dark grey buttons on dark cards. Template tiles are grey squares with the character "模". The three mode cards hold only a label and a button.
- Optimize: mode cards are whole-card links with an icon, one line of what the mode is, and a chevron. Templates use `G6/Gameplay Icon` (from the config kit) and one `开始` pill each in the secondary style; the page has no filled primary because it is a directory.
- Implement: instance swaps. Motion: none beyond press.

**MC-35 · P1 · 我的订单 and 订单详情**
- Frames: `181:3114`, `181:3294`, `184:6584`, `184:6718`.
- Problem: status is blue or grey text at the card's corner; actions are 20 pt pills (查看详情, 申请退款, 取消报名); "实付款：— 待确认" mixes an unknown with a status. The detail page has six blocks of key–value rows and two equal dark buttons at the bottom.
- Optimize: card: status tag, cover, title, date, amount, and **one** action for the state (去支付 / 开始 / 查看票 ; refund and cancel live in the detail's "⋯"). Detail: amount and status at the top, the timeline (ref 12), then two collapsed groups (支付信息, 报名人信息); bottom bar: `查看票` primary, `联系客服` secondary.
- Implement: Figma: `Member/Order Card` (State = Unpaid / Upcoming / Live / Done / Cancelled / Pending). SwiftUI: `DisclosureGroup`.

**MC-36 · P1 · 我的参与: text on busy covers**
- Frames: `204:29459`, `204:29646`, `184:6549`.
- Problem: each card is a large route-art cover with the title, dates and tags written over it; legibility depends on the art. Blue "未开始" tags.
- Optimize: cover on top (16:9, with a bottom gradient only for the status tag), text below on the card surface. Neutral tag.
- Implement: reuse `Player/Theme Card` (Row).

**MC-37 · P1 · 发票, 提现, 通行证: the money pages**
- Frames: `183:4710`, `183:4760`, `183:4804`, `181:2119`, `183:4873`, `204:29996`, `181:3474`, `181:3487`, `181:3539`, `181:3603`, `181:3637`.
- Problem: filter chips are 22 pt; 申请开票's submit is a dark low-contrast button; 提现 again is "联系客服提现"; the pass list has an orange gradient banner (the only colour block in the member area); pass detail and membership have no visible buy button; "¥99.00 / 990 积分" is a dual price without saying which applies.
- Optimize: chips 32 pt with 44 targets. Primary pills per the kit. Pass banner becomes a neutral card with the 3D ticket art (already drawn in `181:3539`). Pass detail: sticky bar with a two-way choice (`¥39` / `390 积分`) as a segmented control and one `开通` button.
- Implement: Figma: redraw the bars; `Player/Sticky Bar`. SwiftUI: `Picker(.segmented)`; StoreKit or the payment sheet.

**MC-38 · P1 · 我的队伍**
- Frames: `184:7016`, `184:7219`, `128:1891`.
- Problem: four counts in a row at the top (已通过 · 审核中 · 带队 · 未通过), a two-segment switch, then 13 rows each with a "队长" tag, "已组 1/4" and a 22 pt 进入队伍 pill.
- Optimize: sections by state (带队中, 已加入, 审核中) with counts in the section headers; rows: avatars stack, team name, `1 / 4 · 11月22日 14:00`, chevron. The counts row goes.
- Implement: `List` with `Section`s.

**MC-39 · P1 · Roam history, session, tools**
- Frames: `181:4520`, `181:4674`, `184:6938`, `184:6977`, `204:34773`, `128:1962`, `128:2012`, `129:1360`, `129:1436`, `129:1515`, `129:1564`, `129:1618`.
- Problem: history cards show one dot on a grid instead of the route; the session page is a large empty box with "这台设备没有本次路线…" and rows of "—"; 官方线路 is text-only cards; 探索目标 has no progress bar; 那年今日 cards are brown gradients; 月度回顾's chart has one bar and no scale.
- Optimize: history: the route drawn on the map snapshot, or when the route is not on this device, the visited cells highlighted and one line `路线只保存在记录它的设备上`. 官方线路: a map thumbnail with the stops. Goals: a progress bar and `0 / 7 天`. 那年今日: the day's photo or route. 月度回顾: five weekly bars with values, the current week highlighted.
- Implement: Figma: `Roam/Route Thumb`; Swift Charts `BarMark` with `AXChartDescriptor`. Motion: bars grow 400 ms on appear; the route draws 800 ms on the history detail.

**MC-40 · P1 · 成长中心, 排行榜, 积分明细**
- Frames: `204:29139`, `204:29258`, `94:1630`, `204:29896`.
- Problem: 成长中心 lists 我的足迹 as four key–value rows and badges as text rows; the leaderboard podium has two people and an empty third place.
- Optimize: four stat tiles (探索值, 徽章, 主题, 距离) with 22 pt numbers; badges as art (MC-30); the podium hides when fewer than three ranks exist and the list starts at 1.
- Implement: `Player/Stat Tile`. Motion: numbers count up once (400 ms).

**MC-41 · P2 · Sparse or text-only pages without a twin**
- Frames: `92:347` (玩法详情: the page title and the article title, both large), `92:375` (收益明细: one highlighted row), `93:373` (分析: one bar), `93:436` (视频悬赏: TikTok / Instagram Reels / YouTube chips and "YouTube · 已取消"), `132:1631` (邀请与收益: a mascot and "暂无可核实记录"), `132:1517` (朋友邀请), `132:1732` (通行证揭晓: a 3D key with 跳过).
- Optimize: these pages have no twin and read as unfinished. Each needs the kit pass (title once, state component, tiles). 视频悬赏's platform list should match what the product supports in its market (Q-A). 通行证揭晓 is a reward moment: give it the player review's reveal treatment (art rises, one headline, one primary).
- Implement: add twins for these seven frames.

**MC-42 · P2 · Illustration is used for some empty states and icons for others**
- Frames: mascot illustration in `114:790` (订单 empty), `118:2236` (票夹 empty), `97:3845` (结算 empty), `181:2101`, `132:1631`; icon tile in all other empties.
- Optimize: one rule: the mascot for first-use empties of a player's own space (订单, 票夹, 收集册); the icon tile for filtered or permission empties and for organiser pages.
- Implement: `Player/State` gets `Art = Mascot | Icon`.

**MC-43 · P2 · 设置, 关于, 营销消息**
- Frames: `190:5223`, `190:5455`, `181:1886`, `181:1966`, `181:2046`.
- Problem: small ones. 退出账号 has a stray "›" before its label; 关于 says "版本 开发版本" and "玩家个人码待生成"; the marketing page lists switches per sender without a master switch.
- Optimize: 退出账号 as a centred red row in its own group; the version number; hide the QR block until the code exists; a master switch on top of 营销消息.
- Implement: text and row edits.

### Batch E · Motion, accessibility, copy

**MC-50 · P1 · Motion and haptics are not stated on any frame**
- Optimize: annotate with the player table (PL-48) plus these club moments:

| Moment | Motion | Haptic |
|---|---|---|
| Join a club | MC-22 | `.success` |
| Approve / reject a request | MC-21 | `.success` / `.impact(.light)` |
| Mark arrived | MC-24 | `.success` |
| Scan a group code | viewfinder corners snap 160 ms, check draws 220 ms | `.success` |
| Send a notification | MC-26 | `.success` |
| Award a badge | the badge flies from the picker to the member's row (350 ms spring) | `.impact(.medium)` |
| Start / end an activity | MC-27 | `.success` / `.warning` before the confirmation |
| Like a post | heart fills with a 1.2× pop, 220 ms; the count rolls | `.impact(.light)` |
| Publish a post | the sheet drops, the new post slides in at the top of the feed (300 ms) | `.success` |
| Dissolve a club | consequence sheet only; no animation | `.warning` |

- Implement: Figma annotations; prototype the first four.

**MC-51 · P1 · Text under 12 pt carries meaning**
- Frames: finance lines in `204:25026` and `236:15318`; meta lines in `184:7219`; tags and counts in `170:1744`; the amber warning in `170:7698`; the tracker labels in `204:25104`; consent and footnotes in `170:1353`.
- Optimize: 13 pt minimum for anything a person needs in order to act; 11 pt only for timestamps.
- Implement: text style swaps.

**MC-52 · P1 · Contrast**
- Frames: dark grey buttons on dark cards (`181:1711`, `104:1576` 提交投诉, `183:4804` 提交申请, `181:1966` rows); grey disabled text on dark (`204:24431`); red 11 pt text on black (`222:2722`, `223:3698`).
- Optimize: secondary buttons use `#1C1C1E` with white labels (at least 4.5:1); disabled labels at least 3:1 with a reason line; red text at 13 pt minimum and `#FF6B6B` on black.
- Implement: token binding; check the eight frames.

**MC-53 · P2 · Dynamic Type and VoiceOver**
- Optimize: XXL proofs for the club home (`204:24899`), the roster (`204:25026`) and 我的订单 (`181:3294`): rows wrap, trailing elements drop under the text. Labels for icon-only actions (分享, 设置, 团码, "⋯"). Leaderboard rows read "第 2 名，海派城市漫游团，5 分".
- Implement: Figma frames; `.accessibilityElement(children: .combine)`.

**MC-54 · P2 · Copy**
- Frames and fixes: "欢迎加入城瘾跑团，查看置顶活动开启第一条路线！" (`204:24751`): keep one sentence, drop the mark (the organiser's own words are data; the template default should be plain); "写评论…", "生成中…", "正在提交取消…", "请详细描述遇到的问题..." → no ellipsis; "提示" as a sheet label (`236:15627`) → it is a field name here and may stay; "去登录" → `登录`; "已经到底了" (`183:4998`, `116:1697`) → remove; "知道了" → `完成`; "链接已失效" with "返回" → say where the person can go (`回到俱乐部`).
- Implement: find-and-replace.

---

## 5 · Batch order

| Batch | Issues | Scope | Depends on |
|---|---|---|---|
| A · Defects | MC-01 – MC-05 | Wrong twins, seeds, spec boards, layout bugs. | — |
| B · One kit | MC-10 – MC-14 | Wizard kit, title rule, state component, switch, chevrons. Uses the player kit. | A; player batch B |
| C · Club | MC-20 – MC-31 | Row actions, club home, organiser pages, badges. | B |
| D · Member | MC-32 – MC-43 | Projects, orders, money pages, roam history, twins for seven untouched pages. | B |
| E · Motion, a11y, copy | MC-50 – MC-54 | Annotations, proofs, wording. | C, D |

C and D can run in parallel.

## 6 · Questions for the owner (defaults used)

| # | Question | Default |
|---|---|---|
| Q-A | 视频悬赏 lists TikTok, Instagram Reels and YouTube. Are these the intended platforms? | Keep as data; only restyle. |
| Q-B | Player switches: neutral white on-track (neutral ruling) or system green? | Neutral. |
| Q-C | "联系客服提现" appears on 提现申请 and 俱乐部结算. Is withdrawal really a support hand-off? | Yes for now: keep the hand-off, but name it and explain it. |

## 7 · Severity count

P0 7 · P1 26 · P2 6 · total 39.
