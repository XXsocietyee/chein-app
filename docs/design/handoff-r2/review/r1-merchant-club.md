# Merchant and club pages: coverage + build specs

Reviewer pass, 2026-11-15. Read-only: nothing in Figma or in code was changed.
Scope (owner change, same day): coverage only, with a build spec for every MISSING or PARTIAL screen and state. References and the optimization review are deferred until all pages are drawn.

File reviewed: `0YyoybGnU1KG0657wdGCPX` — R3 俱乐部 `91:33`, R4 商家 `90:26`, the club and merchant rows on R1 `90:3`, R2 `91:656` and R5 `90:2`, their optimized twins, R6 `91:34`, N1 `204:7911`, P `204:9667`, index `139:2`.

## 0. Result

| | Count |
|---|---|
| Screens the app must have (merchant, club, cooperation) | **81** |
| PRESENT (every state drawn) | **2** |
| PARTIAL (a frame exists, states or surfaces are missing) | **65** |
| MISSING (no frame at all) | **14** |
| States and surfaces not drawn | **549** = 311 screen-specific (tabs, modes, sheets, alerts, flow steps) + 238 generic (loading, error, no-permission, empty, missing link) |

Per group:

| Group | Screens | PRESENT | PARTIAL | MISSING | Missing states to draw |
|---|---|---|---|---|---|
| A. Club: player-facing | 5 | 0 | 5 | 0 | 66 |
| B. Club: operations | 16 | 0 | 16 | 0 | 129 |
| C. Merchant console | 28 | 0 | 28 | 0 | 225 |
| D. Merchant ↔ topic, cooperation, in-store | 17 | 2 | 15 | 0 | 98 |
| E. In the owner 新稿 but with no route in `backend-app-r3` and no frame in our file | 8 | 0 | 0 | 8 | 15 |
| F. Native app only | 7 | 0 | 1 | 6 | 16 |
| **Total** | **81** | **2** | **65** | **14** | **549** |

**Why almost everything is PARTIAL.** The restored pages were built from the screenshot INDEX, which holds one capture per route (three for a few). The WXML shows that each route also has a loading, error, permission and empty state, and most have sheets. None of those were captured, so none were drawn. The optimized twins change existing frames; they add no states.

**Four routes where the only frame is not the page itself.** These look covered in the index but are not:

| Route | What the frame shows | What is missing |
|---|---|---|
| `pages/play/merchant/index` (017, `95:977`) | "链接已失效" dead-link state (checked against the screenshot) | the whole in-store page: spec B-T15 |
| `pages/club/settlement/index` (082, `97:3905`) | empty state「还没有平台分润记录」 | the page with money on it: spec B-C19 |
| `pages/merchant/predict/index` (108, `94:879`) | empty state | the list of prediction rounds: spec B-M08 |
| `pages/coop/nearby/index` (133, `97:1806`) | empty state「附近暂无商家」 | the merchant list: spec B-T07 |

**Biggest gaps, in the order I would draw them:**
1. 俱乐部主页: 帖文 and 活动 tabs, the visitor (not joined) state, and the 俱乐部设置 sheet (B-C02). This is the club tab's main destination and two of its three member tabs are not drawn.
2. 导演台 `club/topic-detail`: 准备中 and 已结束 states and 17 sheets and alerts (B-C20).
3. 商家入驻: 首屏, 提交成功, 审核状态 and 认领已有门店 (B-M02); 主理人申请 and 建团 首屏 and result screens (B-C03, B-C04). The owner already drew these in 新稿.
4. 到店页 `play/merchant` (B-T15) and 本站准备与运行 `merchant/game-node` (B-M24): the two screens used on site, each drawn in one state out of five.
5. 品牌中心 sub-views and AI 店铺角色 (B-M16, B-M17).
6. Cooperation: 发出的 tab, invite detail in its pending states, 找商家 list (B-T04, B-T05, B-T07).
7. The 14 MISSING screens: 8 from the owner 新稿 with no route in this branch, 6 native-only views.

## 1. Sources and method

| Source | What I used it for |
|---|---|
| Mini-program, `/private/tmp/claude-501/hg`, branch `origin/integration/backend-app-r3`, `chengyinhub-xcx/app.json` | The route list: `pages/club` 20, `pages/merchant` 28, `pages/coop` 8, plus `pages/topic/merchantinfo`, `merchantapply`, `pricing/partner`, `pages/play/merchant`, `pages/talent/list`, `subpackageA/pages/myproject`, `subpackageMember/coupon*`, `subpackageRoam/citynode-code`, `poi-detail` |
| The WXML of each route and of its sheet components | States, sheets, section order and all copy. Every quoted string in this file is from WXML or the page script |
| `~/Desktop/小程序截图-最新/全部页面/INDEX.tsv` (219 rows) | Which states were captured. File name pattern: `<row>-<route with _>--<role>-<state>.png` |
| `scratchpad/redesign/_notes.md` | The seed data visible in each capture (section 4) |
| `mp-restore/r3-club.json`, `r4-merchant.json`, `r5-creator-coop.json`, `r1-player-core.json`, `r2-subpackages.json`, `r6-app-only.json`; `optimize/r2r3.json`, `r4r5.json`, `r1r6.json` | Frame ids of restored frames and twins |
| Figma read tools | Page list; index `139:2`; full node tree of section `94:4778` (俱乐部主页) |
| `owner-figma-audit.md` sections (a) and (c) | Node ids in the owner 新稿 files. I did not reopen those four files |
| `/Users/fanning/orca/workspaces/native-ios/DES-ag4/App` and its string catalogs | Native views and their Chinese copy |

Limits you should know about:
- **Frame presence is taken from the manifests, not from reading every section.** I read one section in full (`94:4778`): it holds exactly the manifest's frames and twins. The manifest counts also match the index page (R3: 28 rows, R4: 33 rows / 42 frames). I did not open the other 60 sections.
- **Pages 15 and 16 are not counted.** `15 创作·俱乐部运营` (`28:2`) and `16 商家工作台` (`30:692`) hold about 190 earlier frames in the first native style, many of them the states missing here (e.g. 审核中 `48:17213`, 筛选 sheet `48:573`). They are not in the mini-program look the owner asked for, so a state that exists only there is MISSING. Where one helps as a layout reference the spec names it as "legacy".
- **Native app.** The app's merchant and club views mirror mini-program routes; I list separately only the views with no route (group F). I classified the ~290 Swift files by name and header comment, not by reading each.
- The roadmap document itself was not found in the scratchpad or the repo. Section 3 maps the four roadmap items named in the brief to what exists.

## 2. Coverage

How to read the tables: "PRESENT" lists the frames that exist (restored id, twin id in brackets). "MISSING" lists every state or surface with no frame; items starting 通用· are generic states drawn from the state kit (section 5). The number after the status is the count of missing items. "Spec" points to section 6; "K" means the state kit and Appendix A are enough.

### A. Club: player-facing

Dark (player) theme. Figma page R3 `91:33`, club tab on R1 `90:3`.

| ID | Screen | Route / source | INDEX | PRESENT (frame → twin) | MISSING states and surfaces | Status | Spec |
|---|---|---|---|---|---|---|---|
| C01 | 俱乐部 tab（发现） | `pages/talent/list/index` | 005–007 | 俱乐部 tab = 96:3245 / full 96:3075 (twins 169:3927 / 169:4120)<br>empty = 96:3407 (169:4313)<br>error = 96:3480 (169:4367) | 1. 帖文 tab (通票卡 + feed)<br>2. 帖文 tab empty「还没有帖文」<br>3. 成员管理 sheet (full)<br>4. 商家视角 · 本城俱乐部 (同城范围 strip, no 创建俱乐部 row)<br>5. 通用·loading skeleton<br>6. 通用·refreshing strip | **PARTIAL** (6) | B-C01 |
| C02 | 俱乐部主页 | `pages/club/detail/index` | 069–071 | 概览 tab + 欢迎加入 sheet = 94:4895 / full 94:4779 (twin full 204:24751)<br>概览 tab, empty leaderboard = 94:5058 / 94:4994 (204:24850 / 204:24899)<br>error = 94:5107 (179:5232)<br>管理 tab = see C06 | 1. 帖文 tab (composer row, pinned notice, post cards, row actions)<br>2. 帖文 tab · comments expanded<br>3. 帖文 tab empty / error<br>4. 活动 tab (event cards + 发布)<br>5. 活动 tab empty / error<br>6. 概览 · visitor (not joined): join bar 加入 / 申请加入<br>7. 概览 · visitor: 等待主理人审核 / 申请未通过 + 重新申请<br>8. 概览 · members list expanded (roles, Lv, 举报)<br>9. 概览 · leaderboard with gap row + sort choice sheet<br>10. 管理 tab · 自由探索期次 expanded<br>11. 管理 tab · 可对接商家 expanded (search + venue cards)<br>12. 管理 tab · 可对接的活动 expanded (申请带队)<br>13. 管理 tab · 收到的合作邀约 expanded<br>14. 管理 tab · 我发出的邀约 expanded<br>15. 管理 tab · 管理员 variant (no 结算, no owner rows)<br>16. sheet 俱乐部设置 (root)<br>17. sheet 俱乐部设置 · 项目工具 panel<br>18. sheet 俱乐部设置 · 成员管理 panel<br>19. sheet 选择要管理的俱乐部<br>20. sheet 发帖 composer<br>21. sheet 带上一次游玩记录<br>22. sheet 编辑动态 (full) + 放弃本轮修改 alert<br>23. sheet 编辑历史 (full)<br>24. sheet AI 策划活动 · input<br>25. sheet AI 策划活动 · 生成中<br>26. sheet AI 策划活动 · result<br>27. sheet AI 策划活动 · error<br>28. sheet 选择场次 (团码)<br>29. sheet 团核销码 QR<br>30. sheet 选择导演场次<br>31. sheet 发布什么？(三选一)<br>32. confirm 删除帖文 / 删除评论 / 退出俱乐部<br>33. 通用·loading skeleton<br>34. 通用·login gate「登录后查看俱乐部」<br>35. 通用·not found / 俱乐部已解散 | **PARTIAL** (35) | B-C02 |
| C03 | 主理人申请 | `pages/club/apply/index` | 058–061 | step 1–4 = 94:947, 94:1023, 94:1109, 94:1185 (twins 204:24431, 204:24471, 204:24516, 204:24556) | 1. intro 首屏「把你带的人，变成你的俱乐部」<br>2. step 1 with field errors<br>3. step 4 submit error<br>4. done「已生效」+ 创建我的俱乐部<br>5. done unknown「主理人状态未确认」<br>6. blocked「这个账号已经是商家」<br>7. 通用·checking skeleton<br>8. 通用·error / login「登录后申请成为主理人」 | **PARTIAL** (8) | B-C03 |
| C04 | 建团 | `pages/club/create/index` | 063–066 | step 1–4 = 94:985, 94:1066, 94:1147, 94:1218 (twins 204:24591, 204:24631, 204:24676, 204:24716) | 1. intro 首屏「建一个俱乐部」<br>2. success「俱乐部已创建」<br>3. success「已重新提交，等待审核」<br>4. blocked「请先成为俱乐部主理人」<br>5. blocked「已达创建上限」<br>6. step 3 with cover + logo filled + name error<br>7. submit error「创建没有完成」<br>8. 通用·checking「正在确认创建资格」<br>9. 通用·login「登录后创建俱乐部」<br>10. 通用·error「创建资格未确认」 | **PARTIAL** (10) | B-C04 |
| C05 | 俱乐部勋章 | `pages/club/badges/index` | 062 | normal = 94:2803 (无需优化) | 1. sheet 创建勋章 (+ 结果未确认 / 没有创建 errors)<br>2. sheet 颁给谁？(member picker)<br>3. confirm 收回勋章<br>4. 通用·loading<br>5. 通用·error「勋章列表没加载成功」<br>6. 通用·empty「还没有俱乐部勋章」<br>7. 通用·missing-param | **PARTIAL** (7) | B-C05 |

### B. Club: operations (host / admin)

Dark theme. Page R3 `91:33`. Owner 新稿 file `s7SEFaoJ3GQUIxJhdqcFUb` covers most of these.

| ID | Screen | Route / source | INDEX | PRESENT (frame → twin) | MISSING states and surfaces | Status | Spec |
|---|---|---|---|---|---|---|---|
| C06 | 管理 tab / 工作台 | `pages/club/workbench/index → club detail 管理 tab` | 085 | 管理 tab (owner) = 100:4454 / full 100:4258 (twins 170:1546 / 170:1744) | 1. 数据看板 loading / error / empty block<br>2. 「现在要做」each owner stage (publish / recruit / review / saleReview / open) + timeline expanded<br>3. 通用·loading<br>4. 通用·error「没能进入俱乐部管理」 | **PARTIAL** (4) | B-C06 |
| C07 | 客户名册 | `pages/club/customers/index` | 068 | normal = 94:3018 / 94:2971 (无需优化) | 1. 通用·loading<br>2. 通用·no-permission「当前岗位没有客户查看权限」<br>3. 通用·error<br>4. 通用·empty「还没有客户」<br>5. 通用·filtered empty「没有符合条件的客户」 | **PARTIAL** (5) | K |
| C08 | 客户详情 | `pages/club/customer-detail/index` | 067 | normal = 94:2916 / 94:2846 (无需优化) | 1. editing mode (标签 + 备注 inline editor, draft error)<br>2. 通用·loading<br>3. 通用·no-permission<br>4. 通用·not found<br>5. 通用·error<br>6. 通用·records empty「暂无参与记录」 | **PARTIAL** (6) | B-C08 |
| C09 | 编辑俱乐部资料 | `pages/club/edit/index` | 072 | normal = 94:5199 / 94:5125 (twin full 170:935) | 1. sheet 俱乐部类型 / 活动倾向 pickers<br>2. confirm 解散俱乐部<br>3. sheet 解散前待处理<br>4. sheet 暂时不能解散<br>5. alert 放弃本轮修改 | **PARTIAL** (5) | B-C09 |
| C10 | 报名名册 | `pages/club/enroll/index` | 073 | normal (one 团 expanded) = 96:4357 / 96:4264 (twins 204:24948 / 204:25026) | 1. 通用·loading<br>2. 通用·denied<br>3. 通用·error<br>4. 通用·empty「还没有城市定向团」<br>5. 通用·expanded 团: loading / 该团暂无票种 / 还没有人报名 | **PARTIAL** (5) | K |
| C11 | 核销详情 | `pages/club/checkin-detail/index` | 074 | 已核销 = 96:4436 (twin 204:25104) | 1. 待核销 + 清退并退款 bar<br>2. 已退款 state<br>3. refund error / 结果待确认<br>4. 通用·loading<br>5. 通用·denied「核销记录不可见」<br>6. 通用·not found<br>7. 通用·error | **PARTIAL** (7) | B-C11 |
| C12 | 活动运营 | `pages/club/event-ops/index` | 075 | normal (已报名 tab, create-series form) = 96:4608 / 96:4496 (twins 170:7584 / 170:7698) | 1. roster tab 候补<br>2. roster tab 已到场 / 未到场 (更正未到 / 标记到场)<br>3. 取消本场: confirm alert<br>4. 取消本场: 提交中 / 已取消 / 未完成<br>5. series row expanded: 日期清单<br>6. 编辑未来场次 mode (locked topic)<br>7. 重复方式 = 每周 (场次数)<br>8. 重复方式 = 自定义日期 (date list)<br>9. checkin-only variant (no 本场管理)<br>10. 通用·loading<br>11. 通用·no-permission<br>12. 通用·error<br>13. 通用·empty「暂无可开场的主题」/「还没有系列场次」 | **PARTIAL** (13) | B-C12 |
| C13 | 成员治理 | `pages/club/governance/index` | 076 | manage mode = 97:3584 (无需优化) | 1. manage mode with ban records + 解封<br>2. report mode「向平台提交治理举报」<br>3. appeal mode · active ban<br>4. appeal mode · no ban<br>5. 我的平台工单 list<br>6. sheet 选择成员<br>7. sheet 选择期限<br>8. confirm 封禁 / 转让主理人 (reason input)<br>9. 通用·loading<br>10. 通用·no-permission<br>11. 通用·error<br>12. 通用·empty「暂无可治理成员」 | **PARTIAL** (12) | B-C13 |
| C14 | 团队核销码 | `pages/club/group-code/index` | 077 | QR sheet ready = 97:3623 (twin 204:25159) | 1. 选择场次 list page<br>2. QR sheet 生成中<br>3. QR sheet error + 重试<br>4. 通用·empty「暂无可带队的场次」<br>5. 通用·invalid「缺少路线或场次信息」<br>6. 通用·no-permission「当前账号没有出码权限」 | **PARTIAL** (6) | B-C14 |
| C15 | 入会申请 | `pages/club/join-requests/index` | 078 | 1 pending = 97:3657 (twin 204:25191) | 1. row action error + stale strip<br>2. 通用·loading<br>3. 通用·missing-param<br>4. 通用·error<br>5. 通用·empty「暂无待审申请」 | **PARTIAL** (5) | K |
| C16 | 群发通知 | `pages/club/notify/index` | 079 | compose = 97:3742 / 97:3687 (twins 170:1313 / 170:1353) | 1. 预览受众 result block (ready / empty / error)<br>2. field errors (标题 / 内容)<br>3. sent result (含 failedCount)<br>4. 通用·loading<br>5. 通用·no-permission<br>6. 通用·error | **PARTIAL** (6) | B-C16 |
| C17 | 个人收款 | `pages/club/payout-receiver/index` | 080 | 已绑定 = 97:3782 (无需优化) | 1. 未绑定 +「同意并绑定」<br>2. 已暂停 + 原因 +「重新绑定」<br>3. confirm 解除绑定<br>4. 通用·loading<br>5. 通用·error<br>6. 通用·empty「还没有自己的俱乐部」 | **PARTIAL** (6) | B-C17 |
| C18 | 角色与权限 | `pages/club/roles/index` | 081 | normal = 97:3808 (twin 204:25205) | 1. sheet 选择成员<br>2. sheet 选择角色<br>3. EVENT_CHECKIN row「可见客户手机号」<br>4. confirm 撤销角色<br>5. 通用·loading<br>6. 通用·missing<br>7. 通用·no-permission<br>8. 通用·error<br>9. 通用·empty | **PARTIAL** (9) | B-C18 |
| C19 | 俱乐部结算 | `pages/club/settlement/index` | 082 | empty「还没有平台分润记录」= 97:3905 / 97:3845 (无需优化) | 1. ready: 已入账分润 + 各场次结算 + 各主题结算<br>2. ready · 金额待核验 / 客诉期 variants<br>3. clubs picker (多个俱乐部)<br>4. personal (mine=1) variant<br>5. 通用·loading<br>6. 通用·error | **PARTIAL** (6) | B-C19 |
| C20 | 活动详情 / 导演台 | `pages/club/topic-detail/index` | 083 | 进行中 (director active) = 100:3945 / full 100:3824 (twin full 170:1433) | 1. 状态: 审核中 / 已确认 (按钮 等待审核中 / 开始准备)<br>2. 状态: 准备中 (准备总览 + 开始活动)<br>3. 状态: 已结束 + 活动复盘<br>4. 状态: 自办 (去核销) / 未通过 (修改并重新提交)<br>5. banner: 操作处理中 / 结果待确认 / 无法安全提交<br>6. sheet 更多 (主题设置)<br>7. sheet 商家<br>8. sheet 报名参与者 (+ 趋势)<br>9. sheet 队伍进度<br>10. sheet 角色分配 (+ 接管)<br>11. sheet 定向广播<br>12. sheet 现场事件<br>13. sheet 章节放行<br>14. sheet 默认结局收尾<br>15. sheet 修改集合时间<br>16. sheet 退出与暂停规则<br>17. sheet 选择场次<br>18. sheet 通用玩法现场运营<br>19. alert 结束这场活动？<br>20. alert 结束主题<br>21. result sheet (success / fail)<br>22. sheet 承接商家 · 按节点招商<br>23. sheet 承接商家 · 按章节招商<br>24. 通用·loading<br>25. 通用·not found「链接已失效」<br>26. 通用·error「活动无法打开」<br>27. 通用·director empty「还没有可管理的活动局」 | **PARTIAL** (27) | B-C20 |
| C21 | 剧情与玩法 | `pages/club/topic-story/index` | 084 | 路线 tab = 100:4162 / 100:4052 (无需优化) | 1. 玩法 tab<br>2. sheet 答案 (题面 / 答案 / 提示)<br>3. AI 生成 banner<br>4. 通用·loading<br>5. 通用·error<br>6. 通用·missing-param<br>7. 通用·empty「暂无路线」/「这一章还没有玩法」 | **PARTIAL** (7) | B-C21 |

### C. Merchant console

Light (merchant) theme. Page R4 `90:26`.

| ID | Screen | Route / source | INDEX | PRESENT (frame → twin) | MISSING states and surfaces | Status | Spec |
|---|---|---|---|---|---|---|---|
| M01 | 商家工作台 | `pages/merchant/index/index` | 097–099 | normal = 91:267 / full 91:125 (twins 182:7328 / 182:7428)<br>empty = 91:405 (180:7074)<br>error (收入没更新) = 91:517 (180:7140) | 1. 入驻审核中 status card +「查看申请进度」<br>2. 我的消息 expanded stack + 清空<br>3. 我的消息「都看完了」<br>4. limited-role variant (核销员: only 扫码 + 更多)<br>5. sheet 更多 menu<br>6. sheet 选择本次核销的章节<br>7. sheet 选择本次核销的节点<br>8. result sheet 核销成功<br>9. result sheet 核销失败 / 待复核<br>10. 通用·login gate「登录后查看经营台」<br>11. 通用·projects loading<br>12. 通用·projects error | **PARTIAL** (12) | B-M01 |
| M02 | 商家入驻 | `pages/merchant/apply/index` | 100–103 | step 1–4 = 92:539, 92:600, 92:666, 92:797 / full 92:725 (twins 182:7504, 182:7546, 182:7590, 182:7628 / 182:7693) | 1. intro 首屏「把你的店 放进玩家的路线里」<br>2. step 5 提交成功<br>3. status 审核中<br>4. status 未通过 + 重新申请<br>5. status 已通过<br>6. card 主理人身份处理 (俱乐部移交)<br>7. step 1–2 with field errors<br>8. step 3 with licence + 品牌形象图 uploaded<br>9. sheet 认领已有门店 · search<br>10. sheet 认领已有门店 · form<br>11. sheet 认领已有门店 · 已提交 / 被驳回<br>12. sheet 行业类型<br>13. sheet 设置经营时间<br>14. 通用·checking「正在确认申请资格」<br>15. 通用·error / login | **PARTIAL** (15) | B-M02 |
| M03 | 订单与结算（账本） | `pages/merchant/ledger/index` | 104 | 核销记录 view (全部) = 94:601 (twin 180:7203) | 1. 结算 view (概览 + 收入明细 + 对公结算 + 到账提醒)<br>2. 项目动态 view<br>3. 核销记录 other filters (待处理 / 已处理 / 不结现金)<br>4. finance-hidden variant (no amounts)<br>5. 通用·loading<br>6. 通用·error<br>7. 通用·empty ×4<br>8. 通用·access denied<br>9. 通用·missing-param<br>10. 通用·refreshing strip | **PARTIAL** (10) | B-M03 |
| M04 | 核销记录详情 | `pages/merchant/ledger/order-detail/index` | 105 | normal = 94:689 (twin 180:7276) | 1. 通用·loading<br>2. 通用·missing-param<br>3. 通用·missing-record<br>4. 通用·error<br>5. 通用·stale-error strip | **PARTIAL** (5) | K |
| M05 | 对公打款批次详情 | `pages/merchant/ledger/batch-detail/index` | 106 | normal = 94:755 (twin 182:7757) | 1. 通用·loading<br>2. 通用·missing-param<br>3. 通用·missing-record<br>4. 通用·error | **PARTIAL** (4) | K |
| M06 | 售后工作台 | `pages/merchant/aftercare/index` | 107 | 待回应 = 94:821 (twin 182:7816) | 1. 处理中 tab<br>2. 已完成 tab<br>3. 通用·loading<br>4. 通用·error<br>5. 通用·no-permission<br>6. 通用·empty ×3<br>7. 通用·search empty「没有找到」 | **PARTIAL** (7) | K |
| M07 | 售后退款详情 | `pages/merchant/aftercare/detail/index` | 109 | 待回应 = 94:3190 / 94:3065 (twins 183:1731 / 183:1819) | 1. sheet 处理 · 同意 (step 1 说明)<br>2. sheet 处理 · 不同意 (原因必填)<br>3. sheet 处理 · 补充凭证 (upload)<br>4. sheet 处理 · step 2 确认<br>5. 已处理 state (不可再回应)<br>6. 工单 (manual case) variant<br>7. 通用·loading<br>8. 通用·error<br>9. 通用·no-permission | **PARTIAL** (9) | B-M07 |
| M08 | 预测待答 | `pages/merchant/predict/index` | 108 | empty「没有等你给答案的预测」= 94:879 (无需优化) | 1. ready list (rounds + options, one row open)<br>2. alert 公布答案「…」？<br>3. 通用·login<br>4. 通用·loading<br>5. 通用·error<br>6. 通用·no-permission | **PARTIAL** (6) | B-M08 |
| M09 | 商家公开主页 | `pages/merchant/profile/index` | 110 | 关于 tab = 94:3480 / 94:3303 (twins 182:7862 / 182:7964) | 1. 帖文 tab<br>2. 信息纠错 flow (哪里不对 → form → result)<br>3. 通用·loading<br>4. 通用·error「资料加载失败」<br>5. 通用·invalid link<br>6. 通用·not found「商家不存在或未开放」 | **PARTIAL** (6) | B-M09 |
| M10 | 营销首页 | `pages/merchant/marketing/index` | 111 | normal = 95:1649 / 95:1552 (twins 182:8065 / 182:8176) | 1. 通用·login<br>2. 通用·denied inline<br>3. 通用·loading<br>4. 通用·error (hero must not show 0)<br>5. 通用·empty「还没有主题和活动」<br>6. 通用·no coupon | **PARTIAL** (6) | K |
| M11 | 口碑 / 评价 | `pages/merchant/reviews/index` | 112 | manage mode = 95:1753 (twin 183:1906) | 1. public mode: 写下这次体验 form<br>2. public mode: not eligible note<br>3. manage: reply input open<br>4. manage: 修改回复 inline<br>5. manage: 举报 inline form<br>6. banner 回复结果待确认<br>7. confirm 删除回复<br>8. 通用·loading<br>9. 通用·no-permission<br>10. 通用·login<br>11. 通用·error<br>12. 通用·missing<br>13. 通用·empty<br>14. 通用·filter empty | **PARTIAL** (14) | B-M11 |
| M12 | AI 店铺参谋 | `pages/merchant/marketing/ai-insight/index` | 113 | normal = 96:2111 / 96:1935 (twins 182:8263 / 182:8356) | 1. sheet 推荐主题 detail<br>2. data-unknown shell「基础数据暂未完整返回」<br>3. 通用·loading<br>4. 通用·error | **PARTIAL** (4) | B-M12 |
| M13 | 发现（协作关系） | `pages/merchant/relation/index` | 114 | 帖文 tab = 100:2885 / 100:2221 (无需优化) | 1. 俱乐部 tab (可合作俱乐部 cards)<br>2. sheet 发帖 composer<br>3. 通用·login<br>4. 通用·loading<br>5. 通用·error<br>6. 通用·empty ×2 | **PARTIAL** (6) | B-M13 |
| M14 | 成为城市节点 | `pages/merchant/citynode/index` | 115 | normal = 103:1747 / 103:1678 (twins 182:8448 / 182:8485) | 1. application rows: 审核中 (撤回) / 已驳回 + 理由<br>2. sheet 认领平台节点<br>3. sheet 到店打卡码<br>4. popover 节点是什么<br>5. quota full / zero variants<br>6. 通用·loading<br>7. 通用·error<br>8. 通用·no-permission<br>9. 通用·empty「还没有节点」 | **PARTIAL** (9) | B-M14 |
| M15 | 报名成为节点 | `pages/merchant/citynode/create/index` | 116 | initial = 103:1804 (twin 182:8521) | 1. ready to submit (① 已配置 ② 已确认)<br>2. submitted / 申请状态更新中<br>3. alert 放弃未提交草稿吗<br>4. 通用·login<br>5. 通用·loading<br>6. 通用·no-permission<br>7. 通用·error | **PARTIAL** (7) | B-M15 |
| M16 | 品牌中心（店铺装修） | `pages/merchant/decor/index` | 117 | home view = 103:1865 (无需优化) | 1. view 品牌介绍 (故事 + 特色标签)<br>2. view 合作经营 (承接 / 主推 / 口碑 / 权益 / 升级权益)<br>3. view 门店信息 (read + 编辑)<br>4. view 入驻资料<br>5. sheet text field (single / multiline)<br>6. sheet 标签 picker + 自定义标签<br>7. sheet 经营时间<br>8. full-screen 修改 Logo / 封面<br>9. sheet 还没有保存<br>10. 升级权益 checkout states (支付确认中 / 待确认)<br>11. 通用·loading<br>12. 通用·no-permission<br>13. 通用·error<br>14. 通用·empty | **PARTIAL** (14) | B-M16 |
| M17 | AI 店铺角色 | `pages/merchant/decor/ai-npc/index` | 118 | home + intro sheet step 1 = 103:1960 (twin 170:3821) | 1. home, no sheet (已上线 / 审核中 / 已驳回)<br>2. home · 编辑 mode<br>3. view 上传角色形象<br>4. intro sheet steps 2–4<br>5. sheet 选现成的<br>6. sheet 名字 / 招呼语 / 店铺知识<br>7. sheet 性格设定<br>8. sheet 角色声音 · 录制<br>9. sheet 角色声音 · 生成中 / 可用 / 失败 / 结果未知<br>10. sheet 还没有保存<br>11. 通用·loading<br>12. 通用·error | **PARTIAL** (12) | B-M17 |
| M18 | 承接设置 | `pages/merchant/decor/coop-setting/index` | 119 | normal = 112:506 (twin 183:1981) | 1. sheet 编辑字段<br>2. sheet 还没有保存<br>3. 通用·loading<br>4. 通用·no-permission<br>5. 通用·error<br>6. 通用·empty | **PARTIAL** (6) | K |
| M19 | 门店相册 | `pages/merchant/decor/gallery/index` | 120 | normal = 112:554 (无需优化) | 1. sheet 还没有保存<br>2. 通用·login<br>3. 通用·loading<br>4. 通用·no-permission<br>5. 通用·error<br>6. 通用·empty | **PARTIAL** (6) | K |
| M20 | 常备权益 | `pages/merchant/decor/perks/index` | 121 | list = 112:650 (twin 183:2067) | 1. form 添加常备权益<br>2. form with field errors / 保存状态待确认<br>3. confirm 删除<br>4. sheet 还没有保存<br>5. 通用·loading<br>6. 通用·no-permission<br>7. 通用·error<br>8. 通用·empty「还没有常备权益」 | **PARTIAL** (8) | B-M20 |
| M21 | 合作中心 | `pages/merchant/coop-center/index` | 122 | one tab = 112:834 / 112:685 (twins 183:2102 / 183:2192) | 1. the other tab (官方活动 ↔ 广场)<br>2. 通用·loading<br>3. 通用·error ×2<br>4. 通用·empty ×2 | **PARTIAL** (4) | B-M21 |
| M22 | 客户名册 | `pages/merchant/customer/index` | 123 | normal = 115:573 (twin 183:2281) | 1. sheet 筛选客户<br>2. sheet 管理 (批量标签 / 导出 / 触达记录)<br>3. 批量选择 mode<br>4. export banner (生成中 / 已就绪 / 失败 / 已过期)<br>5. result sheet<br>6. 通用·login<br>7. 通用·no-permission<br>8. 通用·loading<br>9. 通用·error<br>10. 通用·empty | **PARTIAL** (10) | B-M22 |
| M23 | 客户详情 | `pages/merchant/customer/detail/index` | 125 | normal = 115:750 (twin 183:2355) | 1. sheet 编辑标签与备注 (+ 更正)<br>2. 通用·loading<br>3. 通用·error<br>4. 通用·missing<br>5. 通用·no-permission<br>6. 通用·records empty | **PARTIAL** (6) | B-M23 |
| M24 | 本站准备与运行 | `pages/merchant/game-node/index` | 124 | 待开场 (READY) = 115:660 (twin 170:3884) | 1. 节点邀请 (接受 / 拒绝)<br>2. 准备清单 form<br>3. 运行中 (出示打卡码 / 暂停接待 / 核验)<br>4. 已暂停 + 恢复接待<br>5. station switcher (多站)<br>6. banner 操作结果待确认<br>7. sheet 拒绝节点邀请<br>8. sheet 暂停接待<br>9. sheet 核验游戏提交<br>10. sheet 服务时段<br>11. sheet 本站打卡码 QR<br>12. 通用·loading<br>13. 通用·empty「暂无本站任务」<br>14. 通用·error ×2 | **PARTIAL** (14) | B-M24 |
| M25 | 核销流水 | `pages/merchant/verify-records/index` | 126 | 已核销 = 117:597 (twin 183:2416) | 1. 已撤销 tab<br>2. 通用·loading<br>3. 通用·error<br>4. 通用·no-permission<br>5. 通用·empty ×2 | **PARTIAL** (5) | K |
| M26 | 收款账户 | `pages/merchant/payout-account/index` | 127 | 已开通 = 117:656 (无需优化) | 1. 待签约 / 待验证 + 复制链接<br>2. 通用·loading<br>3. 通用·error<br>4. 通用·no-permission<br>5. 通用·empty「收款账户暂未开放」<br>6. 通用·empty「还没有开通收款账户」 | **PARTIAL** (6) | B-M26 |
| M27 | 触达记录 | `pages/merchant/crm-campaigns/index` | 128 | list = 117:692 (twin 183:2465) | 1. sheet 触达明细<br>2. 通用·loading<br>3. 通用·error<br>4. 通用·no-permission<br>5. 通用·empty | **PARTIAL** (5) | B-M27 |
| M28 | 经营团队 | `pages/merchant/team/index` | 129 | manager view = 117:728 (twin 183:2495) | 1. 加入经营团队 (接受邀请)<br>2. 邀请已创建 card + 待接受邀请 list<br>3. sheet 选择邀请岗位<br>4. sheet 调整岗位 (+ 移除)<br>5. confirm 移除 / 撤销邀请<br>6. non-manager variant「进入工作台」<br>7. 通用·login<br>8. 通用·loading<br>9. 通用·error | **PARTIAL** (9) | B-M28 |

### D. Merchant ↔ topic, cooperation, in-store

Mixed themes (noted per row). Pages R1 `90:3`, R2 `91:656`, R5 `90:2`.

| ID | Screen | Route / source | INDEX | PRESENT (frame → twin) | MISSING states and surfaces | Status | Spec |
|---|---|---|---|---|---|---|---|
| T01 | 主题招商详情 / 承接进度 | `pages/topic/merchantinfo/merchantinfo` | 091 | 承接方进度 view = 113:1167 / 113:979 (twins 169:8188 / 169:8363) | 1. browse view: 详情 tab + 申请承接<br>2. browse view: 任务向导 tab<br>3. block 我在这条路线上的承接 (节点 + 申请 states)<br>4. host view (project-host)<br>5. progress states: 待确认 / 被驳回 / 进行中 / 已结束<br>6. sheet 选择承接节点<br>7. sheet 路线模式介绍<br>8. sheet 章节选择<br>9. sheet 本站打卡码 / 本主题二维码<br>10. sheet 分润明细<br>11. 通用·missing-param<br>12. 通用·login<br>13. 通用·no access<br>14. 通用·error | **PARTIAL** (14) | B-T01 |
| T02 | 申请成为合作点位 | `pages/topic/merchantapply/index` | 092 | form = 116:993 (twin 169:8538) | 1. form filled + errors<br>2. success 提交成功<br>3. edit mode「保存修改」<br>4. sheet 选择可配合日期<br>5. sheet 可配合时间<br>6. 通用·login<br>7. 通用·loading<br>8. 通用·error<br>9. 通用·permission | **PARTIAL** (9) | B-T02 |
| T03 | 合作方分账明细 | `pages/topic/pricing/partner/index` | 094 | normal = 116:1116 (twin 169:8660) | 1. 通用·loading<br>2. 通用·error<br>3. 通用·invalid link<br>4. 通用·missing info | **PARTIAL** (4) | K |
| T04 | 协作邀请列表 | `pages/coop/list/index` | 130 | 收到的 = 96:2599 / 96:2754 (twins 186:5836 / 186:5944) | 1. 发出的 tab<br>2. card kinds: 带队申请 / 承接报名 / 官方邀约 / 章节承接记录<br>3. card with 保证金 actions<br>4. 通用·login<br>5. 通用·loading<br>6. 通用·permission<br>7. 通用·error<br>8. 通用·empty ×2<br>9. 通用·action receipt / error strips | **PARTIAL** (9) | B-T04 |
| T05 | 协作邀约详情 | `pages/coop/invite-detail/index` | 131 | 已接受 = 96:2911 / 96:2992 (twins 186:6051 / 186:6119) | 1. 待确认 · received (拒绝 / 接受合作 + 理由 input)<br>2. 待确认 · sent (撤回邀约)<br>3. 已拒绝 / 已撤回 / 已结束<br>4. sheet 申报本次供给<br>5. sheet 这次合作打几分 → 评价<br>6. 通用·loading<br>7. 通用·missing<br>8. 通用·not found<br>9. 通用·error | **PARTIAL** (9) | B-T05 |
| T06 | 发起协作邀请 | `pages/coop/invite/index` | 132 | locked-target form = 97:1757 (twin 186:6186) | 1. open target: 俱乐部 / 商家 tabs + selection<br>2. sheet 编辑邀约语 (send)<br>3. result sheet sent / failed<br>4. banner 原请求仍待确认<br>5. supply-station picker rows<br>6. 通用·login<br>7. 通用·loading<br>8. 通用·permission<br>9. 通用·error<br>10. 通用·no topics<br>11. 通用·no targets | **PARTIAL** (11) | B-T06 |
| T07 | 附近可邀约商家 | `pages/coop/nearby/index` | 133 | empty「附近暂无商家」= 97:1806 (twin 186:6231) | 1. ready list (venue merchant cards + 电话联系)<br>2. sheet 选择补位操作<br>3. 通用·loading<br>4. 通用·login<br>5. 通用·location permission<br>6. 通用·missing-param<br>7. 通用·error | **PARTIAL** (7) | B-T07 |
| T08 | 合作分账中心 | `pages/coop/finance/index` | 134 | normal = 97:1874 (twin 186:6257) | 1. 通用·loading<br>2. 通用·error<br>3. 通用·empty | **PARTIAL** (3) | K |
| T09 | 分账结算单详情 | `pages/coop/settlement-detail/index` | 135 | normal = 97:4788 / 97:4854 (twins 186:6297 / 186:6364) | 1. 通用·loading<br>2. 通用·missing-param<br>3. 通用·missing-record<br>4. 通用·error | **PARTIAL** (4) | K |
| T10 | 合作收益提现 | `pages/coop/withdraw/index` | 136 | normal = 97:4922 (twin 189:3482) | — | **PRESENT** (0) | — |
| T11 | 合作提现记录 | `pages/coop/withdraw/records/index` | 137 | normal = 97:4991 (twin 189:3520) | 1. 通用·redirecting<br>2. 通用·error<br>3. 通用·empty | **PARTIAL** (3) | K |
| T12 | 我的项目（商家） | `subpackageA/pages/myproject/index?scope=merchant` | 029 | 主题 tab = 91:1165 / 91:1288 (无需优化) | 1. 活动 tab<br>2. 模板 tab<br>3. sheet 行操作 (编辑 / 收到的申请 / 审核记录 / 另存为模板 / 删除)<br>4. sheet 审核记录 (+ 申诉)<br>5. confirm ×5 (删除 / 取消 / 下架 …)<br>6. 通用·login<br>7. 通用·loading<br>8. 通用·access denied<br>9. 通用·error<br>10. 通用·empty | **PARTIAL** (10) | B-T12 |
| T13 | 我发布的优惠券 | `subpackageMember/coupon/coupon?scope=merchant` | 167 | normal = 105:1558 (twin 204:29429) | 1. 通用·loading<br>2. 通用·error<br>3. 通用·empty | **PARTIAL** (3) | K |
| T14 | 创建 / 设置优惠券 | `subpackageMember/couponInfo/couponInfo?scope=merchant` | 168 | normal = 105:1590 (twin 204:29444) | 1. field errors + saved result | **PARTIAL** (1) | K |
| T15 | 商家打卡游玩（到店） | `pages/play/merchant/index` | 017 | 链接已失效 = 95:977 (twin 169:5349). The capture is the dead-link state, not the page. | 1. normal · 待到店<br>2. 已到店 → 拍摄凭证<br>3. 照片已记录 → 出示核销码<br>4. 已核销 + 评价<br>5. card 本站任务 (选择题 / 填空 / 结果)<br>6. card 到店任务<br>7. block 当前门店授权 + 撤回<br>8. sheet 评价安全感受 + 已提交<br>9. degraded / 结果待确认 strip<br>10. 通用·login gate | **PARTIAL** (10) | B-T15 |
| T16 | 据点核销码 | `subpackageRoam/citynode-code/index` | 195 | QR sheet = 124:1158 (twin 204:30633) | 1. 通用·missing「这个核销码无法打开」 | **PARTIAL** (1) | K |
| T17 | 据点详情 | `subpackageRoam/poi-detail/index` | 197 | normal = 124:2216 (无需优化) | — | **PRESENT** (0) | — |

### E. In the owner 新稿 but with no route in `backend-app-r3` and no frame in our file

Source: owner file `s7SEFaoJ3GQUIxJhdqcFUb` (club) and `txQoyVyKb3aQdFCnc8qmhj` (merchant), node ids from owner-figma-audit.md. These are whole screens to draw.

| ID | Screen | Route / source | INDEX | PRESENT (frame → twin) | MISSING states and surfaces | Status | Spec |
|---|---|---|---|---|---|---|---|
| N01 | 会费设置 | `新稿 R2 290:444 (`pages/club/membership/*`)` | — | — | 1. 会费设置 page | **MISSING** (1) | B-N01 |
| N02 | 我的账单（会员） | `新稿 R3 290:680` | — | — | 1. 我的账单 page | **MISSING** (1) | B-N01 |
| N03 | 管理 · 管理员视角 | `新稿 350:424` | — | — | 1. 管理员管理页面 | **MISSING** (1) | B-C02 |
| N04 | 场次系列 | `新稿 E1 289:393, E2 289:489` | — | — | 1. E1 系列列表<br>2. E2 系列编辑 | **MISSING** (2) | B-C12 |
| N05 | 招商（节点 / 章节） | `新稿 J3-A/B 155:118, 158:118; J4 201:118; J5 164:118; J7 297:409` | — | — | 1. J3 招商 sheet ×2<br>2. J4 候选池<br>3. J5 招募条件 | **MISSING** (3) | B-C20 |
| N06 | 商家：我的站点运营 | `新稿 A5 447:1156; 469:1002; 469:1025; 469:1087; 281:494` | — | — | 1. A5 我的站点运营<br>2. 这一站怎么接待<br>3. 服务时段与接待容量<br>4. 本站复盘 | **MISSING** (4) | B-M24 |
| N07 | 商家：承接报名成功 / 进度五态 | `新稿 365:957; 88:4014, 88:4170, 88:4368, 88:3776, 88:4583, 88:4798, 126:310` | — | — | 1. see T01 / T02 | **MISSING** (1) | B-T01 |
| N08 | 商家 Tab：模板 / 我的 | `app handbook 290:547, 290:997` | — | — | 1. 商家 · 模板 tab root<br>2. 商家 · 我的 tab root | **MISSING** (2) | B-N08 |

### F. Native app only (in `DES-ag4/App`, no mini-program route, no frame on R6 or N1)

R6 (`91:34`) holds no merchant or club screen. Copy below is from the app string catalogs.

| ID | Screen | Route / source | INDEX | PRESENT (frame → twin) | MISSING states and surfaces | Status | Spec |
|---|---|---|---|---|---|---|---|
| A01 | 俱乐部活动 · 日历视图 | `App/ClubEventCalendarView.swift` | — | — | 1. 列表 / 日历 switch + month grid<br>2. day selected + 当天活动<br>3. empty month / undated list | **MISSING** (3) | B-A01 |
| A02 | 成员与活动概况（全页） | `App/ClubStatsOverviewView.swift` | — | block inside 管理 tab = 100:4454 | 1. full page with scope notes + 项目完成情况 | **PARTIAL** (1) | B-A02 |
| A03 | 场次状态 | `App/ClubTerminalSessionView.swift` | — | — | 1. 场次状态 page (当前场次 + 结算入口) | **MISSING** (1) | B-A03 |
| A04 | 本店 CITY 接入与暂停 | `App/CityMerchantOperationsView.swift` | — | — | 1. ready<br>2. confirm 确认提交本店意愿？<br>3. review / receipt / unknown states | **MISSING** (3) | B-A04 |
| A05 | 商品规格（Desk SKU） | `App/MerchantDeskSkuPage.swift` | — | — | 1. 商品 → 规格 list<br>2. edit + 核对修改<br>3. confirm + saved / unknown | **MISSING** (3) | B-A05 |
| A06 | NPC 本地知识草稿 | `App/MerchantNPCKnowledgeDraftView.swift` | — | — | 1. form (营业时间 / 商品 / 活动优惠 / 常见问答 / 禁止表述)<br>2. validation errors<br>3. saved | **MISSING** (3) | B-A06 |
| A07 | 触达 · 新建与预览 | `App/MerchantEngagementComposer.swift` | — | — | 1. compose (channel + audience)<br>2. 预览并核对 | **MISSING** (2) | B-A07 |


## 3. Roadmap club operations

| Roadmap item | Where it lives | In Figma | Gap |
|---|---|---|---|
| Manage tab | 俱乐部主页 → 管理 tab (`pages/club/detail`, tab `manage`); `pages/club/workbench` redirects to it | PRESENT: `100:4454` / `100:4258`, twins `170:1546` / `170:1744` (owner view, all sections collapsed) | Five expandable sections, the admin view, and the 俱乐部设置 sheet: B-C02, B-C06 |
| Dashboard | Block「成员与活动概况」on the 管理 tab (4 totals + per-project rows); native full page `ClubStatsOverviewView` | PRESENT as a block inside `100:4454` (9 项目 / 3 / 3 / 100.0%) | Loading, error and empty block states; the full page with the scope notes: B-C06, B-A02 |
| Nearby | (a) nearby clubs: third list on the 俱乐部 tab; (b) nearby merchants for a host: `pages/coop/nearby`; (c) player map: `subpackageRoam/nearby` | (a) PRESENT `96:3245`, not labelled as "nearby"; (b) empty state only `97:1806`; (c) PRESENT `124:2486`, twin `204:34773` (map) | (b) the list itself: B-T07. (a) has no section header in WXML either, so nothing to add |
| Leaderboard | (a)「本团贡献榜 · 本周」on 概览; (b) 排行榜 block on 导演台; (c) CITY 赛季榜 · 俱乐部 | (a) PRESENT `94:4779` (4 rows) and empty `94:5058`; (b) PRESENT, empty, inside `100:3824`; (c) PRESENT N58 on N1 | (a) sort sheet and the "⋯ 中间 N 人" gap row; (b) a populated board and 隐藏榜单 / 显示榜单: B-C02, B-C20 |

## 4. Real data to use

Use these in every new frame so the set reads as one account. All of it is from the E2E seed visible in the captures.

| Thing | Value |
|---|---|
| Club | 城瘾跑团 (id 7001) · 城市探索 · 上海市 · 4 名成员 · 公开加入 · 简介「每周举办外滩与法租界城市定向、实景解谜与徒步社交活动，欢迎新老玩家加入。」 · 欢迎语「欢迎加入城瘾跑团，查看置顶活动开启第一条路线！」 |
| Host (主理人) | 海派城市漫游团 (member 9003) |
| Members | 你 (玩家, 9004) · 海派城市漫游团 · 沪上寻踪搭子 · 平台运营. Pending applicant: member 9005 |
| Leaderboard | 你 1 场 · 0.0 km · 10.0 分; 海派城市漫游团 5.0 分; 沪上寻踪搭子 0.0 分; 平台运营 0.0 分 |
| Merchant | 南京东路猫咖驿站 (merchant 9002, store 8001) · 城市探索合作驿站 · 营业中 · 累计收入 ¥1280.00 · 标签 手冲咖啡、撸猫打卡、线索驿站 · 节点配额 在架 1/3 |
| Topics (real titles and covers in the file) | 外滩夜探 · 老店招牌文字迷宫 · 黄浦江风味补给夜行 · 南京路霓虹声景寻踪 · 深夜书摊寻宝物语 · 猫咖夜游. Main topic 992001, activity 992031, node 992021 (第 1/6 站, 老城钟楼) |
| Customer | 玩家小城 (9004), 手机 139****0004, 累计实付 ¥97, 到店 2 / 待核销 1 / 已退款 0, 标签 已到店、VIP |
| Money | 核销 +¥150.00; 本月核销 2 笔 / 待结算 ¥220.20 / 已入账 ¥400.00; 退款 ¥39.00 待回应; 对公批次 2026-11 净额 ¥150.00; 提现 -¥198.80 |
| Perk | 到店赠美式一杯 · 优惠券 · 零售价 ¥32 · 成本 ¥12 · 可接待 200 份 · 长期有效 |
| Cooperation invite | 来自 城瘾跑团 → 南京东路猫咖驿站 · 分成型 · 票款 18% · 已接受 (invite 992651) |
| Team | 1 人, 核销员 (operator 992656) |
| Reviews | 5.0 ★, 1 条, 作者「玩***城」, 核销已验证 |

Rules that apply to every new frame (from `optimize-brief.md`): one currency, 积分; unknown values show "—" with a reason, never 0; no raw ids such as "#992031"; text at least 11 pt; one primary button per screen; the 城 mark; neutral tab selection; sheets are native iOS sheets (grabber, detents, swipe down to close).

## 5. State kit (K): the generic states

238 of the missing states are the same five patterns. Draw each once per theme, then make one frame per route with the copy from Appendix A.

Canvas rule for all new frames, following the existing pages: put the frame in the route's existing section, in the first row, to the right of the last restored frame, 120 px gap, same top edge, with a label above it `<INDEX row> <state>` (for example `069 帖文`). For a route with no INDEX row use the ID from section 2 (`N01 会费设置`). Frame size 393 × 852; taller content gets a second `· full` frame as elsewhere.

| Kit item | Mini-program component | Layout | Notes |
|---|---|---|---|
| K1 Loading | `cy-skeleton` types `list`, `card`, `detail`, `amount`, `merchant-metric`, `form-section`, `text` | Nav bar and page title stay; content area shows grey blocks in the shape of the real layout: `list` = 5 rows (40 circle + two bars); `card` = 2 cards 361 wide; `detail` = cover block + 3 bars + 2 cards; `amount` = one wide bar 32 high; `merchant-metric` = 3 tiles in a row | Shimmer note in the annotation; no spinner in the page centre |
| K2 Error | `cy-error` (title, sub, 重试) | Centred block starting about 280 from the top (as in twin `179:5232`, instance `MP/State`): icon, title 17 semibold, sub 14 secondary, one button 重试 | Title is the route's own (Appendix A). Sub is the server text: use「网络没连上，请重试」or「请稍后重试」, the handbook wording used in rows 71, 163, 175, 189 |
| K3 No permission / login | `cy-access-gate` (kinds `login`, `club`, `merchant`), `cy-empty kind=no-permission`, `cy-state-shell kind=no-permission` | Same centred block; lock icon; title; sub; button: 去登录 for login gates, none for role gates (sub says 请联系店主开通 / 仅主理人和管理员可用) | The gate replaces the whole page under the nav bar |
| K4 Empty | `cy-empty kind=empty` | Centred block; the lime illustration `MP/Empty Art (local)` `97:150` where the capture shows it (rows 082, 108, 133, 136), otherwise the line icon; title; optional sub; optional action | Filters, tabs and search stay visible above an empty list |
| K5 Missing link / not found | `cy-empty kind=missing-param` or `not-found`, `cy-state-shell kind=missing-param` | Centred block as in `95:977`: info icon,「链接已失效」, button 返回 | Twin `169:5349` adds a reason and a next step; copy it |
| K6 Inline error | `cy-inline-error` | A row inside the content: icon + title + sub + 重试 text button; 44 high minimum; sits directly under the block that failed | Used for partial failures: the rest of the page keeps its data |
| K7 Refreshing strip | `cy-progress-status` or a plain text row | One 13 pt secondary line under the title:「正在更新…」| Old data stays visible underneath |
| K8 Unknown-write banner | plain views in `topic-detail`, `game-node`, `reviews` | Full-width card at the top: title「操作结果待确认」, the message, buttons 确认操作结果 (secondary) and 重试原操作 (secondary) | Never auto-retries; both buttons are secondary |
| K9 Discard confirm | `cy-modal`「放弃本轮修改」/ `cy-sheet`「还没有保存」 | iOS alert: title, body「离开后，本次修改不会保留。」, buttons 继续编辑 (default) and 确认放弃 / 放弃修改 (destructive) | One component, two title variants |
| K10 Danger confirm | `cy-danger-confirm` | iOS alert with a destructive button; title and body set by the page script | Each spec lists the title |
| K11 Result sheet | `cy-result-sheet` kinds `success`, `fail`, `loading` | Medium-detent sheet: 64 circle with check or cross, title, sub, primary button, optional secondary | Success motion is the spring in owner file 3, board `356:4674` |
| K12 QR sheet | `cy-qr-voucher` | Medium sheet: title, QR 220 × 220 on white, name under it, desc line, optional 保存到相册 | Existing examples: `97:3623`, `124:1158` |
| K13 Option sheet | `cy-option-sheet` | Medium sheet: title, list of single-choice rows 50 high with a check on the selected one, confirm button | |
| K14 Scene sheet | `cy-scene-sheet variant=half / full` | Half = medium detent with large as second detent; full = large detent with a title row and ✕ | Sheet-on-sheet follows owner rule: lower sheet scales to 0.94, two layers at most |

Themes: club and player routes are dark (`MP-Dark`); merchant console routes are light. Three routes cross over and must keep the theme of the capture: `topic/merchantinfo`, `topic/merchantapply`, `coop/nearby` are light even when a club host opens them.


## 6. Build specs

Each spec gives: the source (route, WXML, capture), the reference to follow (owner 新稿 first, then the restored frame), the frames to create, the sections in order with the real copy, and the states. WXML paths are under `chengyinhub-xcx/` on `origin/integration/backend-app-r3`. Captures are in `~/Desktop/小程序截图-最新/全部页面/`. 新稿 club file = `s7SEFaoJ3GQUIxJhdqcFUb`, 新稿 merchant file = `txQoyVyKb3aQdFCnc8qmhj`, 新稿 apply file = `fPpJDigsR0friyEDuaDdCA`, card file = `hxL7fvfpNshL1ke8nLIU69`.

Precedence when sources disagree (from the brief): owner rulings > owner 新稿 > owner DS and handbooks > mini-program. Flutter is not a reference for any page in this file.

### 6.1 Club

#### B-C01 · 俱乐部 tab（发现）
- **Source:** `pages/talent/list/index.wxml` (120 lines). Captures 005 (俱乐部 tab), 006 empty, 007 error. Section on R1 holding `96:3245`.
- **Reference:** club card 0928, card file `101:2` (eight states). Feed post card: R4 `100:2885` shows the same `cy-post-card` in the light theme; redraw it dark.
- **Frames to create (6):**
  1. `005 帖文`: header (bell with unread badge, capped "99+", title 发现), top tabs 帖文 | 俱乐部 with 帖文 selected. Then, in order: the pass card (optional; title, meta line, up to 3 cover thumbs, price, button 获取通票); the feed of post cards (avatar, name, club link, time, text, images, like / comment / share counts).
  2. `005 帖文 · 空`: same header; K4 with「还没有帖文」.
  3. `005 成员管理 sheet`: full sheet titled with the club name (城瘾跑团), heading 成员管理, rows: avatar 36, nickname, second line「主理人」or「加入时间 2026-11-01」, trailing text button 移除 (not shown on the host row). States inside the sheet: K1 list, error「成员加载失败」, strip「正在更新成员」, empty「暂无成员」.
  4. `005 俱乐部 · 商家视角`: same list without the row「创建你自己的俱乐部 / 创建俱乐部」; only the nearby list; strip「正在确认同城范围」; empty copy「本城还没有俱乐部」. Capability tags on the card (能设计路线, 能出 NPC, 能对接商家) per card file.
  5. `005 加载中`: K1 `card`.
  6. `005 更新中`: normal list with strip「正在更新俱乐部」.
- **Present, for reference:** player club tab = row「创建你自己的俱乐部」+ button 创建俱乐部, then 我创建的, 我加入的, 附近的 clubs as one run of cards (no section headers in WXML).

#### B-C02 · 俱乐部主页
- **Source:** `pages/club/detail/index.wxml` (1085 lines), `components/cy/club-publish-sheet`, `pages/club/components/club-pinned-notice`. Captures 069, 070, 071. Section `94:4778`.
- **Reference:** 新稿 club file, member view: 普通会员 `88:5857`, 帖子 N1b `47:2`, 活动 N2 `20:52`, N2-A 空态 `282:350`, N2-B 有活动 `282:499`, 概览 N3 `20:137`; admin view: 管理·主理人 `268:223`, 管理员管理页面 `350:424`; sheet rules `298:392`; PostCard `211:270`, Event card `281:360`.
- **Shared header (already drawn in `94:4779`):** cover 393 × 181, logo 54, name, share button, line「城市探索 · 4 名成员」, line「公开加入」with trailing 退出 (members only), tabs 帖文 | 活动 | 概览 (+ 管理 for host and delegated roles), gear in the nav bar for host and delegated roles.

**Tabs and page states (15 frames)**

1. `069 帖文`: tab 帖文 selected. In order: pinned notice card (component `club-pinned-notice`: one line + chevron); composer row (avatar「我」, nickname, placeholder「有什么新鲜好玩的分享吗？」, three icons image / pin / flag) shown to members when posting is allowed; post cards. Each card has an action row under it, shown by permission: 编辑, 置顶 / 取消置顶 (moderators, notices only), 历史 (if edited), 删除, 举报. A post that quotes a removed record shows「引用不可用」.
2. `069 帖文 · 评论展开`: one card open: comment rows「昵称：内容」with 删除 or 举报 at the end; empty「还没有评论，来抢沙发」; input「写评论…」+ 发送 (members).
3. `069 帖文 · 空`: K4「暂无帖文」, sub「入会后可发布」for non-members. Also draw the error variant「帖文加载失败」as K6.
4. `069 活动`: tab 活动 selected. Button 发布 (plus icon) at the top right for host and activity managers. Event cards: tag chip, title, line「地点 · 分类」, three optional facts (已报名 N, 节点 N, 路线 x km), action row by role: 邀约承接 (merchant viewer), 出示团码 (managers), ⋯ (report). Use 外滩夜探 and 老店招牌文字迷宫.
5. `069 活动 · 空`:「暂时俱乐部还没有活动」; error variant「活动列表加载失败」.
6. `069 概览 · 未加入`: visitor. Header shows no 退出. Member strip replaced by「加入后可看成员名单」(or「通过审核后可看成员名单」when the club needs approval); leaderboard replaced by「加入后可看贡献榜」/「通过审核后可看贡献榜」. Fixed bottom bar with one primary button: 加入 (open club) or 申请加入 (approval club).
7. `069 概览 · 申请中 / 未通过`: two small variants of frame 6. Pending: the bar is a disabled label「等待主理人审核」. Rejected: a line under the header「申请未通过：<原因>」and the button reads 重新申请.
8. `069 概览 · 成员展开`: member list rows: avatar 36, nickname, badge 主理人 or 管理员, line「Lv.3 · 公开资料 ›」+「· 创建俱乐部」or「· 加入 2026-11-01」, trailing 举报 (not on your own row). Notice row when identity cannot be confirmed:「成员身份暂时无法确认，管理员工具暂不可用。」Host-only block at the bottom「治理与安全」with rows 封禁申诉 and 举报俱乐部.
9. `069 概览 · 榜单长`: leaderboard with the gap row「⋯ 中间 12 人」between top rows and your own row, and the sort control (label 综合) opened as K13 with the sort options from the page script.
10–14. `085 管理 · <section>` (five frames): the 管理 tab (`100:4258`) with one section open each:
    - **自由探索期次:** rows「<主题名>」+「<日期> · 执行俱乐部期次」+ button 带票分享; empty and error「期次加载失败」.
    - **可对接商家:** link row 我的合作 ›; search「搜商家名 / 承接能力 / 地区」; merchant cards in the venue variant (card file `105:2` state 05: capacity, venue fee, suitable play types); empty「还没有开放对接的商家」/「没有匹配的商家，换个关键词试试」.
    - **可对接的活动:** rows: topic name + state chip,「<商家> 发布」, subtitle, deadline, button 申请带队 (→ 提交中…) or link 查看申请 ›; empty「暂无开放承接的主题」; no-permission「暂不能看可对接的活动」.
    - **收到的合作邀约:** rows: status, partner name, time, chevron; empty「暂无合作邀约」.
    - **我发出的邀约:** rows: partner, topic,「发出于 <时间>」, status; empty「还没有发出邀约」.
15. `085 管理 · 管理员`: admin view per 新稿 `350:424`: quick actions 扫码, 出示二维码, 分享, 设置 (no 结算); no「现在要做」buttons, no 成员与活动概况, no owner-only sections; project list reads「暂无分配给你的项目」when empty.

Generic (3): K1 `detail`; K3「登录后查看俱乐部」; K5 not found, and the gone state with the server sentence as title.

**Sheets (17 frames).** All are native sheets over the dimmed page.

| # | Frame | Detent | Content in order |
|---|---|---|---|
| 16 | `069 俱乐部设置` | large | Group 客户与项目: 查看客户 (value「2 位」), 报名名册 (「7 个团」), 活动运营, 项目工具 ›. Group 成员与权限: 入会申请 (badge 1), 成员管理 (4), 角色与权限 (「1 已委派」), 成员治理, 通知成员, 俱乐部勋章. Group 开放设置 (host): 俱乐部公开可见, 开放商家承接, 允许成员发帖 — each a row with value 已开启 / 已关闭 / 保存中…; 入会欢迎语 (two lines + 修改 / 去写). Group 经营: 俱乐部分润 (amount). Group 俱乐部资料: 编辑资料. Inline error under a failed switch:「开关没有保存成功」 |
| 17 | `069 俱乐部设置 · 项目工具` | large | Row 项目工具 open: three tiles 发布主题, 开一场, AI 策划 |
| 18 | `069 俱乐部设置 · 成员管理` | large | Row 成员管理 open: 邀请成员 ›, then member rows with trailing text buttons 权限, 临时封禁, 移除 |
| 19 | `069 选择要管理的俱乐部` | medium | List of the host's clubs, one per row |
| 20 | `069 发帖` | large | Full composer (`cy-post-compose`): text area, image row, 带上一次游玩记录, 发布. Follow 新稿 N1b `47:2` |
| 21 | `069 带上一次游玩记录` | medium | Rows: record name + sub line + chevron; states K1, error「游玩记录加载失败」, empty「还没有可以带的记录」 |
| 22 | `069 编辑动态` | large | Text area「输入动态内容」, note「编辑记录将公开」, primary 保存修改. Plus alert K9「放弃本轮修改」|
| 23 | `069 编辑历史` | large | Rows「v2 · 11月14日 19:26」+ content (or「（仅图片动态）」); empty「暂无编辑记录」 |
| 24 | `069 AI 策划 · 输入` | large | Idea chips; text area「一句话描述想法，如"静安 情侣 夜间 Citywalk 90分钟"」; inputs 俱乐部风格(选填), 时长(分钟); button 生成方案 |
| 25 | `069 AI 策划 · 生成中` | large | Same with fields disabled, label「生成中…」and text button 取消 |
| 26 | `069 AI 策划 · 方案` | large | Title, subtitle, tags,「约 90 分钟」, storyline,「为什么适合:…」,「路线节点 · 5」numbered rows (name + address), 风险提示 bullets, 可对接商家建议 bullets, 宣传文案 with 复制; button 换一版; primary 用这个方案去发布 with note「发布前需补充封面和分类」 |
| 27 | `069 AI 策划 · 失败` | large | Inline error「方案没能生成」+ 重试 |
| 28 | `069 选择场次` | medium | Note「仅限本场次」, rows of sessions with chevron |
| 29 | `069 团核销码` | medium | K12, title「<场次名> · 团核销码」, desc「合作商家扫码登记」 |
| 30 | `069 选择导演场次` | medium | Rows of sessions |
| 31 | `069 发布什么？` | medium | Title 发布什么？; option rows icon + title + desc. Three options: 城市定向「需设置具体的集合时间与地点，适合强组织的团体活动。」; 自由探索「只需设置有效期，用户在规定时间内自由前往体验。」; 活动「一次性的线下聚会:定时间、地点与票种，不含路线与节点。」. 新稿 G1 `151:115` |
| 32 | `069 确认` | alert | Three K10 alerts on one frame: delete post, delete comment, 退出俱乐部 |

#### B-C03 · 主理人申请
- **Source:** `pages/club/apply/index.wxml`. Captures 058–061. Section holding `94:947`.
- **Reference:** 新稿 apply file v2: H0 `10:2`, H1 `6:2`, H2 `7:2`, H3 `7:43`, H4 `7:86`; the 17 code states `1:2` … `1:66` show every state of this page.
- **Frames (8):**
  1. `058a 首屏`: H0. Headline「把你带的人，变成你的俱乐部」, three facts, one primary button 成为主理人. No progress bar.
  2. `058 校验`: step 1 with errors under 实名/昵称 and 联系方式; note「联系方式不对外展示」; 下一步 disabled.
  3. `061 提交失败`: step 4 with inline error「提交没有完成」+ reason above the button 成为俱乐部主理人.
  4. `061a 已生效`: title 成为主理人; card「已生效」with rows 主理人 = 海派城市漫游团, 可建俱乐部 = 最多 2 个; primary 创建我的俱乐部.
  5. `061b 状态未确认`: K2「主理人状态未确认」.
  6. `058b 已是商家`: K3「这个账号已经是商家」, sub「一个账号不能同时是商家和俱乐部主理人，切换到商家端继续经营」.
  7. `058c 校验中`: K1 `card`.
  8. `058d 未登录 / 失败`: K3「登录后申请成为主理人」and K2「主理人资格未确认」.
- **Step copy already drawn (for consistency):** step 2 options 没有经验 / 1-5场 / 5-20场 / 20场以上 + 最大带队人数（选填）, 平均参与人数（选填）; step 3 toggles 能设计城市路线, 能设计任务 · 解谜, 能带 NPC · 角色, 能与商家联动 +「已选 N 项」; step 4 持导游 / 旅游资质 + 资质 / 案例图 upload.

#### B-C04 · 建团
- **Source:** `pages/club/create/index.wxml`. Captures 063–066. **Reference:** 新稿 apply file G0 `15:2`, G1 `2:14`, G2 `2:65`, G3 `2:98`, G4 `2:141`.
- **Frames (10):**
  1. `063a 首屏`: G0. Headline「建一个俱乐部」, primary 开始创建.
  2. `065 已填`: step 3 with a cover (16:9) and logo (1:1) chosen, name filled, and the name error line shown once.
  3. `066 提交失败`: step 4 (城市 *, 核心关键词（选填）, 风格/调性（选填）) with「创建没有完成」.
  4. `066a 已创建`: K11-style full page: check,「俱乐部已创建」, sub「城瘾跑团 · 上海」, button to the club.
  5. `066b 等待审核`: same with「已重新提交，等待审核」.
  6. `063b 需先成为主理人`: K3「请先成为俱乐部主理人」, sub「申请通过后即可创建与管理俱乐部」, button to the apply flow.
  7. `063c 已达上限`: K4「已达创建上限」, sub「每位主理人最多创建 2 个俱乐部」, button to manage.
  8–10. K1-style shell「正在确认创建资格」(and「正在前往主理人申请」/「即将打开申请页」); K3「登录后创建俱乐部」; K2「创建资格未确认」.
- **Step 1 options:** 校园社团「学生组织 · 校园路线」, 旅行组织「城市探索 · 户外带队」, 兴趣社群「同好聚集 · 城市路线」, 商业活动组织方「品牌路线 · 商业执行」, 内容创作团队「内容产出 · IP 运营」, 其他. Step 2 counter「已选 2 / 3」.

#### B-C05 · 俱乐部勋章
- **Source:** `pages/club/badges/index.wxml`. Capture 062 (`94:2803`).
- **Frames (7):** `062 创建勋章` medium sheet: fields 勋章名 (placeholder「例如：开荒元老」), 说明（选填）(「这枚勋章颁给谁、为什么」), primary 创建; error lines「勋章没有创建」and「创建结果未确认」. `062 颁给谁？` medium sheet: line「勋章：开荒元老」, member rows (host tagged 主理人), states「正在读取成员名单」,「成员名单没加载成功」,「暂无成员」. `062 确认` K10. Generic: K1, K2「勋章列表没加载成功」, K4「还没有俱乐部勋章」, K5.

#### B-C06 · 管理 tab blocks
- **Source:** `pages/club/detail/index.wxml`, tab `manage`; `pages/club/workbench/index.wxml` (redirect shell). Capture 085.
- **Frames (4):**
  1. `085 概况 · 状态`: the block「成员与活动概况」three times on one frame: K1, error「数据看板加载失败」, and ready-but-empty (totals shown, then「还没有可统计的项目数据」).
  2. `085 现在要做 · 各阶段`: the task card once per owner stage, stacked, with its label and hint: 发布主题「先发布一个俱乐部项目」; 邀请商家「选择一个项目，开始对接商家」; 查看邀请进度「邀请已发出，等待商家回应」; 管理项目「商家已接受，进入项目主办视图」; 活动运营「已承接项目，可查看全部项目的场次运营」; 查看合作邀约. Show the timeline (`cy-timeline`) expanded on one of them, and the secondary button 开一场 where allowed. In the two review stages the primary button is absent.
  3–4. K1; K2「没能进入俱乐部管理」.

#### B-C08 · 客户详情: editing
- **Source:** `pages/club/customer-detail/index.wxml`. Capture 067. **Reference:** 新稿 K2 `141:140` and states `146:90`, `146:132`, `146:177`, `146:188`, `146:199`.
- **Frame (1 + 5 generic):** `067 编辑`: the 标签与备注 card in edit mode: tag chips with ✕, input to add a tag, note text area, error line on save failure, 保存 / 取消. Generic: K1 `card`; K3「当前岗位没有客户查看权限」; K5 with the server sentence; K2「客户详情加载失败」; records block empty「暂无参与记录」.

#### B-C09 · 编辑俱乐部资料: sheets
- **Source:** `pages/club/components/cy/scene-club-edit/index.wxml` (236 lines). Capture 072. **Reference:** 新稿 P6 解散前待处理 `31:38`; type and preference rows that open a bottom sheet (新稿 note: two 62 px rows).
- **Frames (5):** `072 俱乐部类型` and `072 活动倾向` medium sheets (chips with icons, counter「已选 2 个」, primary 应用); `072 解散确认` K10 for 解散俱乐部 (button state「正在解散…」); `072 解散前待处理` large sheet: intro「这些资金事实即使原合作或主题已隐藏也会保留。逐笔处理、系统确认终态后才能解散。」, then rows: title, status, meta, action 去处理 ›; `072 暂时不能解散` medium sheet with K2「解散条件未通过」+ reason. Alert K9.

#### B-C11 · 核销详情: other states
- **Source:** `pages/club/checkin-detail/index.wxml`. Capture 074 (已核销). **Reference:** 新稿 K3, eight states `454:414`, `455:414`, `455:454`, `455:494`, `455:534`, `456:414`, `456:454`, `456:461`.
- **Frames (3 + 4):** `074 待核销`: same layout with status 待核销, 核销时间 / 核销门店 / 操作人 =「—」+ reason, and a bottom bar with one destructive button 清退并退款 (→「正在退款…」). `074 已退款`: status chip 已退款, no bar. `074 退款失败`: inline error above the bar,「退款没有完成」or「退款结果待确认」. Generic: K1, K2「核销记录不可见」(denied), K5, K2「核销凭证加载失败」. Section order of the page: person row (avatar, name, session time, masked phone + call) → status + time → order card (cover, topic, 单号) → rows 票种, 下单时间, 实付, 核销时间, 核销门店, 操作人 → 4-step rail.

#### B-C12 · 活动运营
- **Source:** `pages/club/event-ops/index.wxml` (280 lines). Capture 075. **Reference:** 新稿 E1 `289:393`, E2 `289:489`, P4 报名名册 `30:48`.
- **Page order (present frame):** 本场管理 (本场名册, 主持小费「暂不可开通」, 取消本场「会下架本场、处理退款并终止候补」) → 本场名册 · N 人 with chip tabs 已报名 / 候补 / 已到场 / 未到场 (count in each label) → 日期清单 (series rows) → form 重复方式 → 容量与候补 → button 创建系列场次.
- **Frames (9 + 4):**
  1. `075 候补`: tab 候补; rows show the waitlist state instead of the phone; no attendance button.
  2. `075 已到场 / 未到场`: rows with ghost button 更正未到 (已到场) or 标记到场 (未到场); the correction-window line above the tabs.
  3. `075 取消本场 · 确认`: alert「确认取消本场？」, body「会下架本场、处理退款并终止候补。已核销的部分不退。」, buttons 再想想 / 取消本场 (destructive).
  4. `075 取消本场 · 结果`: the row in three states: 「正在提交取消…」; 「本场已取消」with「原因：…」and the summary line; inline error「本场取消未完成」with 刷新 or 重试取消本场.
  5. `075 日期清单展开`: a series row「外滩夜探 · 每周」, chip「候补开启」, link 编辑未来场次, and the opened list「日期清单（含已过去与已取消的场次）」: date, meta, badge per occurrence; empty「暂无场次」; button 添加日期.
  6. `075 编辑未来场次`: form in edit mode: banner「已锁定主题与负责人策略；退出编辑可换系列」+ 退出编辑; 主题 shown as locked (show the topic name, not "#992001"); button 保存未来场次.
  7. `075 每周`: 重复方式 = 每周 with 首次日期 and 场次数 (placeholder「1–64」).
  8. `075 自定义日期`: 重复方式 = 自定义日期 with a date list, each row with 移除, and 添加日期. Common fields: 集合时刻 * with note「集合前 24 小时停止退款」; 默认负责人; 容量（可选）「沿用票种」; switch 满员后开启候补; 候补认领时长 *「5 分钟 – 1 天」.
  9. `075 仅核销`: check-in-only role: no 本场管理 actions; row 本场名册 notes「仅核销权限可见」.
  Generic: K1; K3「你没有活动运营的权限」sub「需「活动运营」或「本场核销」权限」; K2「活动运营暂时不可用」; empties「暂无可开场的主题」,「还没有系列场次」,「这一段暂时没有成员」.

#### B-C13 · 成员治理
- **Source:** `pages/club/governance/index.wxml`. Capture 076 (manage mode, no records). **Reference:** 新稿 R6 `290:621`.
- **Frames (8 + 4):**
  1. `076 治理记录`: manage mode with records: rows「成员「沪上寻踪搭子」」, line「俱乐部封禁 · 11月10日 · 30 天后到期」(platform bans add「· 仅平台可解封」), status, optional「解封说明：…」, button 解封.
  2. `076 举报`: mode report. Card「向平台提交治理举报」: 举报目标 = the target; note「请提交可核实的事实」; primary 填写事实并提交平台. Below: 我的平台工单.
  3. `076 申诉 · 有封禁`: page title 封禁申诉. Card「对当前有效封禁提出申诉」: the ban row, 封禁原因, note「申诉通过后解封，需重新入会」, primary 填写理由并提交申诉.
  4. `076 申诉 · 无封禁`: same card with K4「当前没有可申诉的封禁」sub「仅限期封禁可申诉」.
  5. `076 我的平台工单`: rows: type, reason,「提交于 <时间>」, optional「平台说明：…」, status; empty「暂无已提交工单」.
  6. `076 选择成员` medium sheet: avatar + nickname + 选择 / 已选.
  7. `076 选择期限` medium sheet: 7 天 / 30 天 / 90 天.
  8. `076 确认`: the reason-input alerts for 封禁 and for 转让主理人 (note「转让后你将失去主理人权限」).
  Generic: K1; K3「你没有成员治理的权限」sub「仅主理人和管理员可用」; K2「治理功能暂时不可用」; K4「暂无可治理成员」.

#### B-C14 · 团队核销码
- **Source:** `pages/club/group-code/index.wxml`, `pages/club/components/club-game-code-sheet`. Capture 077. **Reference:** 新稿 J6 `297:392`.
- **Frames (3 + 3):** `077 选择场次`: page title, list of sessions the viewer can lead, one per row. `077 生成中`: the sheet 活动核验团码 with a placeholder square and「生成中」. `077 失败`: sheet with「团码暂时没能生成，请稍后重试」+ 重试. Generic: K4「暂无可带队的场次」; K2「缺少路线或场次信息」; K2「当前账号没有出码权限」sub「仅主理人、管理员或本场领队可出码」.

#### B-C16 · 群发通知
- **Source:** `pages/club/notify/index.wxml`. Capture 079. **Reference:** 新稿 R4 `290:526`.
- **Frames (3 + 3):** `079 预览受众`: the result block under the button in three states (ready with counts, empty, error). `079 校验`: errors under 标题 and 内容. `079 已发送`: result with delivered count and, when some failed, the failed count. Generic: K1; K3「你没有发通知的权限」sub「需「通知成员」权限，请联系主理人」; K2「通知工具暂时不可用」.

#### B-C17 · 个人收款
- **Source:** `pages/club/payout-receiver/index.wxml`. Capture 080 (已绑定). Legacy layouts: `48:33039` 未绑定, `48:33079` 收款未开通, `48:33028` 解除绑定 alert.
- **Frames (3 + 3):** `080 未绑定`: rows 状态 = 未绑定, 收款 = the payout line; primary 同意并绑定. `080 已暂停`: rows 状态, 原因, 收款; primary 重新绑定; secondary 解除绑定. `080 解除绑定` K10. Generic: K1; K2「个人收款加载失败」; K4「还没有自己的俱乐部」.

#### B-C18 · 角色与权限
- **Source:** `pages/club/roles/index.wxml`. Capture 081. **Reference:** 新稿 R1 `290:393`.
- **Frames (4 + 5):** `081 选择成员` and `081 选择角色` medium sheets (role rows have a name and a one-line summary; trailing 选择 / 已选); `081 本场核销`: the form with role 本场核销 selected, which adds the row「可见客户手机号 · 是 / 否」; `081 撤销` K10. Generic: K1, K5「链接已失效」, K3「你没有管理角色的权限」sub「仅主理人可分配角色」, K2「角色管理暂时不可用」, K4「暂无成员」.

#### B-C19 · 俱乐部结算: the page with data
- **Source:** `pages/club/settlement/index.wxml`, `components/cy/club-direct-ledger`. Capture 082 is the empty state. **Reference:** 新稿 G2 `105:6`; owner file `ku2oaN9ag1XUMC9lKNnrcr` C60 `4338:13118`.
- **Frames (4 + 2):**
  1. `082 有数据`: in order: title 俱乐部结算; direct-ledger block (club kind); funds stages strip (`cy-funds-stages`); row 个人收款 › (host); card 已入账分润 with the amount and, when some records lack proof, the line「2 笔已结算记录缺少入账证据，合计待核验」; button 联系平台客服提现; section 各场次结算: rows with name, net amount, date,「销售额 ¥…」, fee line,「商家核销费 ¥…」, payee; section 各主题结算: rows with name, amount, lines 原始应结 / 已执行调整 / 核算净额, arrival text, status chip 已入账 / 待入账 / 待核验 / 已作废.
  2. `082 待核验 · 客诉期`: the amount replaced by「金额待核验」; button disabled with the note「客诉期结束后可提现」; non-host note「仅主理人可发起提现」.
  3. `082 选择俱乐部`: list of the host's clubs, one per row.
  4. `082 个人`: the personal variant (`mine=1`): no 销售额 or fee lines, no direct ledger.
  Generic: K1; K2「结算数据暂不可用」.

#### B-C20 · 活动详情 / 导演台
- **Source:** `pages/club/topic-detail/index.wxml` (706 lines) and `pages/club/components/club-director-*` (ready, recap, row-list, chip-group, and the sheets broadcast, chapter, incident, role, team, end-confirm), `club-topic-end-confirm`, `components/cy/club-topic-merchants`, `club-topic-onboarding`. Capture 083 (进行中). Section holding `100:3945`.
- **Reference:** 新稿 club file: 活动详情 by state H1–H6 `127:6`, `132:21`, `132:116`, `133:51`, `133:162`, `133:263`; director D1 准备中 `286:393`, D2 `286:440`, D4 `287:446`, D5 `288:393`, D6 `288:442`, D7 `288:496`, D8 `288:546`, D9 复盘 `289:523`; sheets C1–C3 `471:449`, `472:449`, `473:449`; 招商 J3-A/B `155:118`, `158:118`, J4 `201:118`, J5 `164:118`; 团码 J6 `297:392`; 商家 J7 `297:409`; 规则 J8 `419:414`. Owner rule: four round buttons, each a bottom sheet; the bottom primary button changes with state (开始准备 → 开始活动 → 结束活动 → 复盘).
- **Page order (present frame):** hero (status, title, date range, verify mode, chips) → four round actions 商家, 报名参与者, 团码, 更多 → 核销 block (台账 link; tiles 待核销, 我已核销, 本场总人数) → 主题 card (opens 剧情与玩法) → 接下来 (sessions; link 管理场次) → 集合时间 row (修改 or「已有报名 · 已锁定」) → director blocks → 排行榜 → link 退出与暂停规则 → primary button.

**State frames (5).** Status text and bottom button per state, from the page script: 审核中 → 等待审核中 (disabled); 未通过 → 修改并重新提交; 已确认 → 开始准备; 准备中 → 开始活动; 进行中 → 结束活动; 自办 (进行中) → 去核销; 已结束 → 查看结算报告.
1. `083 审核中 / 已确认`: two variants of the page before the director is active: no 核销 block; 审核中 has a disabled button 等待审核中; 已确认 has the primary 开始准备 and the sessions list.
2. `083 准备中`: status 准备中. Block 准备总览 (`club-director-ready`): station list with a sub line, team list with a sub line, caption. Bottom primary 开始活动. If a merchant hold blocks the start: the fail text above the button and a button 联系商家. Stations empty:「开始准备后显示节点状态」.
3. `083 已结束`: no 核销 / 主题 / 接下来 blocks. Block 活动复盘 (`club-director-recap`): metric tiles (value, unit, label), completion rows, leaderboard rows (or「暂无榜单记录」), station rows, caption. Buttons 隐藏榜单 / 显示榜单 and 复制复盘数据 (→ 复制中). Before the recap exists:「复盘尚未生成」. Bottom primary 查看结算报告.
4. `083 自办 / 未通过`: 自办: status 进行中, bottom button 去核销, and the 更多 sheet gains 结束活动. 未通过: a card「未通过原因」+ reason, bottom button 修改并重新提交.
5. `083 操作状态`: the K8 banner in its three titles: 操作处理中, 结果待确认 (with 确认结果 and 重试原操作), 无法安全提交. Also the block 默认结局收尾 with its sentence and button 填写收尾原因, and the block 通用玩法现场运营 with its action buttons.

**Sheets and alerts (18).** Half sheets unless noted.

| # | Frame | Content in order |
|---|---|---|
| 5 | `083 更多` | Rows: 剧情与玩法, 核销记录, 场次管理, 退出与暂停规则. Then the topic settings: topic name + lifecycle; 编辑主题内容; 确认终价 (when pricing is pending); 承接审核 ›; switch 开放商家对接 /「开放商家承接」; group「在俱乐部页的展示」with switches 置顶在俱乐部主页 and 只对成员可见; destructive row 结束主题 with the two notes「未核销票原价退回」and「已核销订单转平台处理」. States: K1, empty「暂时不能查看主题设置」, error「主题设置获取失败」 |
| 6 | `083 商家` | Rows: initial avatar, merchant name, station name, contact text, copy icon. Footer note「商家接受后显示联系方式」. Empty「这个主题还没有承接商家」; error「商家信息获取失败」. Use 南京东路猫咖驿站 · 第 1 站 |
| 7 | `083 报名参与者` | Stat chips; filter chips 全部, 待核销, 已接洽, 已核销; rows: initial, name, time, masked phone, call button, status, verify text; row 定向广播 (disabled variant shows the reason). Second block「按参与日期 · 报名人数」: date + count rows. Empties「还没有人报名」,「这一档还没有人 / 换个筛选试试」,「还没有带参与日期的报名」 |
| 8 | `083 队伍进度` | Team rows (per team: 卡点节点, 提示层级, 最近有效事件); optional second list for collaboration |
| 9 | `083 角色分配` | Title「角色分配 · <成员>」; member list; role chips; takeover list; primary 确认分配. Takeover form inside the sheet: dropdown「选择同队待分配成员」, 接管原因 * (「写明为什么要接管，会进审计记录」), buttons 取消接管 / 确认接管 |
| 10 | `083 定向广播` | 发给 + count; horizontal people picker; 范围 chips (全部 / by target); target rows with 选择 / 已选; 内容 * text area (「写点什么，比如：第 3 站临时排队，先去第 4 站」), counter「0/50」; primary 发送 |
| 11 | `083 现场事件` | Event rows; a mode chip group; primary 确认处理; caption |
| 12 | `083 章节放行` | Title = the unlock button text; note「玩家进度与发放状态保持不变」; 现场原因（选填）「写明放行原因」; primary 放行 |
| 13 | `083 默认结局收尾` | 收尾原因 (「说明本场无法继续执行方案的原因」); primary 确认收尾; when a write is pending, a link 查看上次操作结果 |
| 14 | `083 修改集合时间` | 集合日期, 集合时间 pickers; note「退款截止为集合前 24 小时」; buttons 取消 / 保存 (→ 提交中…) |
| 15 | `083 退出与暂停规则` | Five groups: 退出俱乐部, 退出队伍, 退出以后的钱, 暂停一个节点, 取消一整场; each a list of「标题。说明」lines from the page script |
| 16 | `083 选择场次` | Rows: when + who |
| 17 | `083 通用玩法现场运营` | Note「时间为北京时间」; ledger lines; fields by type (dropdown, switch, text, text area); inline error; buttons 取消 / 确认并提交 |
| 18 | `083 结束活动` (alert) |「结束这场活动？」/「结束后不能再核销、不能再改队伍与角色；已产生的结算事实会保留。此操作不可撤销。」/ 再想想 / 结束活动 |
| 19 | `083 结束主题` (alert) | Title 结束主题; body from the page script; buttons 再想想 / 结束并退款 |
| 20 | `083 结果` | K11 success and fail |
| 21 | `083 承接商家 · 节点` | Half sheet 承接商家: note「先选要招商的节点，再去招商。一个节点只能有一家承接。」; progress「已招 1/6 站 · 1 家待确认」; per chapter: name +「6 站 · 已招 1」; node rows: number, name, sub; either merchant + status or button 去招商; footer link 查看候选池. Empty「还没有可招商的节点 / 回到编辑主题页配置后再来招商」 |
| 22 | `083 承接商家 · 章节` | Heading「自由探索 · 按章节招商」+ intro; per chapter card: name, status, line「<品类> · 需可容纳 <人数>」; when recruiting: tags,「已通过 1 / 上限 3 家」, threshold line, buttons 设置招募条件 and 查看申请 2; when closed:「开放后，同品类商家可申请承接本章节」+ 开放招募. Footer note「商家申请通过后，还要各自提交节点并过节点审核，才会出现在玩家路线上。」 |

Generic (4): K1 `detail`; K5「链接已失效」; K2「活动无法打开」; K4「还没有可管理的活动局」sub「先从俱乐部管理区开一场，再进入导演台。」(also director errors「导演台读取失败」,「网络连接失败」).

#### B-C21 · 剧情与玩法
- **Source:** `pages/club/topic-story/index.wxml`. Capture 084 (路线 tab). **Reference:** 新稿 J1-A `228:125`, J1-B `228:142`, J1-C `241:126`.
- **Frames (3 + 4):** `084 玩法`: tab 玩法: chapter selector, play cards per chapter (tag chips, title, short rule), empty「这一章还没有玩法」. `084 答案`: half sheet titled with the play name: 题面, 答案, 提示 list, 玩家答错时的反馈, and the note「答案只给主办方和这一站的接待方看，用于现场判定玩家能否通过。玩家端看不到这一段。」; states「正在取答案…」and「答案没取到」. `084 AI 生成`: the AI-generated banner at the top of the page. Generic: K1, K2「剧情与玩法无法打开」, K5「链接已失效」, K4「暂无路线」.

#### B-N01 · 会费设置 and 我的账单 (新稿 only)
- **Source:** no route in this branch (`pages/club/membership/*` appears only in the owner 新稿). **Reference:** 新稿 club file R2 会费设置 `290:444`, R3 我的账单 `290:680`.
- **Frames (2, dark):** copy the two owner frames into a new section on R3 named「会费 · 新稿」, labels `N01 会费设置` and `N02 我的账单`, with the seed data from section 4. Do not invent fields beyond the owner frames. Mark both in the annotation as「新稿有、现码无路由」so the executor does not look for WXML.


### 6.2 Merchant console

All frames in this group are light (merchant theme) on page R4 `90:26`.

#### B-M01 · 商家工作台
- **Source:** `pages/merchant/index/index.wxml` (357 lines). Captures 097, 098, 099. Section holding `91:267`.
- **Reference:** owner note「以现码为准」, so follow the restored frame; project card M15, 新稿 merchant file `134:185`. Scan itself is drawn on R6 (A48–A53: scanning, detected, success, used, expired, offline).
- **Page order (present):** greeting「Hi，南京东路猫咖驿站」+ 营业中 / 已打烊 chip (tappable for profile editors) + avatar → 累计收入 → quick actions 扫码, 客户, 财务, 更多 (each only with permission) → alert rows「有 1 笔售后待回应」,「有 1 轮预测待给答案」 → 项目 (horizontal cards; header link「全部 N」) → 我的消息 (stacked cards; link 全部).
- **Frames (9 + 3):**
  1. `097 入驻审核中`: the page for an account whose application is not approved: one card with a status label and sentence, button 查看申请进度; no greeting, no quick actions, no 我的消息.
  2. `097 消息展开`: 我的消息 stack opened: each card shows icon, title, sub, time and a dismiss ✕; a row 清空 (trash icon) under the stack.
  3. `097 消息看完`: single row with a check「都看完了」. (The empty capture 098 shows「还没有消息」; the read-failure wording is「消息暂时没读到」.)
  4. `097 核销员`: limited role: quick actions only 扫码 and 更多; no 累计收入, no 项目.
  5. `097 更多`: half sheet with tiles, by permission: 协作邀请, 退款售后, 核销记录, 收款账户, 管理优惠券, 品牌资料.
  6. `097 选择章节`: half sheet「选择本次核销的章节」, rows of chapter names; an already-used one reads「<章节>（已核销，请勿重复提供权益）」.
  7. `097 选择节点`: half sheet「选择本次核销的节点」.
  8. `097 核销成功`: K11 success; primary 继续扫码, secondary 完成.
  9. `097 核销失败 / 待复核`: K11 fail; for the review case the primary is 查看核销记录.
  Generic: K3「登录后查看经营台」; project row K1 `list`; project error「项目和待办加载失败」; top inline error「商家工作台加载失败」.

#### B-M02 · 商家入驻
- **Source:** `pages/merchant/apply/index.wxml` (347 lines), `pages/merchant/components/merchant-claim-sheet`, `cy/tag-sheet`. Captures 100–103. Section holding `92:539`.
- **Reference:** 新稿 apply file v2 (light): M0 首屏 `15:19`, M1 `21:2`, M2 `21:35`, M3 `22:2`, M4 `22:34`; review states in 新稿 merchant file A-8 `127:310`, A-9 `127:347`, A-10 `127:384`; owner file `ku2oaN9ag1XUMC9lKNnrcr` C04–C07 `4386:13253`, `4386:13282`, `4401:13087`, `4401:13119`. Legacy layouts for 审核中 / 未通过: `48:17213`, `48:17281`.
- **Frames (13 + 2):**
  1. `100a 首屏`: M0. Headline「把你的店 放进玩家的路线里」, primary 开始入驻, text link under it「门店已在城瘾上线？认领已有门店」.
  2. `104 提交成功` (step 5): nav title 提交成功; check 64,「你的申请已提交」,「预计 1–3 个工作日完成审核」; card 店铺名称 / 联系电话; timeline card: 提交申请「已提交」→ 资料初审「审核团队审核中」→ 资质核验「等待上一步完成」→ 审核结果「等待上一步完成」; primary 返回首页.
  3. `104 审核中`: nav title 审核状态; heading 商家入驻申请; card: status badge + sentence, rows 店铺名称, 联系电话, 店铺地址; timeline card: 提交申请 (date) → 资料初审「审核团队审核中」→ 审核结果; primary 返回.
  4. `104 未通过`: same with a rejected badge and reason; timeline 资料初审「已完成」; primary 重新申请.
  5. `104 已通过`: same with the approved badge; primary 返回.
  6. `100 俱乐部移交`: above the form, section「主理人身份处理」with a card「商家账号生效前，须完成俱乐部移交」, note「仅已生效的俱乐部可移交」, one row per owned club (name, status badge, button 前往移交).
  7. `100 校验`: steps 1 and 2 with field errors under 店铺名称, 行业类型, 联系电话 (11位手机号), 店铺地址 (「点击选择位置」), 经营时间 (「点击设置营业日与时段」); the legend「标 * 的是必填」.
  8. `102 已上传`: step 3 with the licence thumbnail (✕ to remove) and 品牌形象图（选填）with 3 of 6 tiles filled.
  9. `100 认领 · 搜索`: medium sheet 认领已有门店: line「认领已上线、无人管理的门店」, search input「输入门店名称搜索」+ 搜索, result rows, no result「未找到门店，可申请入驻」.
  10. `100 认领 · 表单`: large:「已选：南京东路猫咖驿站」+ 换一家; inputs 联系人, 联系电话, 补充说明（选填，说明你与这家门店的关系）;「证明材料（营业执照或门店实拍，1-10 张）」upload grid; error「提交未完成」; primary 提交认领.
  11. `100 认领 · 结果`: two variants: submitted (title + sentence + 知道了) and rejected (「驳回原因：…」+ 补充材料重新提交).
  12. `100 行业类型`: tag sheet, multi-select chips, primary 确定.
  13. `101 设置经营时间`: medium sheet: 经营日 * as seven day chips; 营业时段 * with 开始时间 → 至 → 结束时间 rows opening the time wheel; primary 完成.
  Generic: shell「正在确认申请资格」/「正在检查已有申请」; K2 / K3「登录后申请商家入驻」,「网络没连上」,「页面状态暂时不可用」.
- **Step 4 (present) for reference:** summary card (店铺名称, 行业类型, 联系电话, 店铺地址, 营业时间, 店铺介绍) → 营业执照 → 品牌形象图 → 经营者实名 (真实姓名「与身份证一致」, 身份证号「18 位」, consent check) → error「申请暂未提交」→ primary 提交申请.

#### B-M03 · 账本（核销与结算）
- **Source:** `pages/merchant/ledger/index.wxml` (181 lines). Capture 104 (核销 view). Legacy: `48:573` 筛选 sheet, `48:882` 对公结算, `48:1025` 空.
- **Frames (4 + 6):**
  1. `104 结算`: view `settlement`. In order: card「本月个人账户<净额>」with the big amount, badge「¥… 调整待处理」when pending, three rows 个人账户毛额, 已执行调整, 待对公结算; button 去我的资产; row 结算到账提醒 with a switch and a hint (「已允许微信通知」in the mini-program; in the app write the push-notification wording); section 收入明细: rows with source, time, status badge, optional split line, amount; section 对公结算: rows「2026-11 对公结算」, status badge, invoice badge, amount.
  2. `104 项目动态`: view for one project:「本项目近期收入与核销」, rows label + content + time; empty「近期暂无项目动态」.
  3. `104 筛选`: the 核销 view with 待处理, then 已处理, then 不结现金 selected (one frame, three cropped lists is enough).
  4. `104 无财务权限`: role without finance: no 合作分润 row, no tabs, summary shows only 本月核销, rows have no amount.
  Generic: K1 `list` and `merchant-metric`; K2「核销记录加载失败」/「结算数据加载失败」sub「请稍后重试」; empties「还没有记录」,「还没有已成立的收入明细」,「还没有对公结算批次」,「近期暂无项目动态」; K3「当前身份不能查看这份商家账本」; K5「链接已失效」; strips「正在确认最新记录…」,「最新记录暂未取回」.

#### B-M07 · 售后详情: respond sheet
- **Source:** `pages/merchant/aftercare/detail/index.wxml` (195 lines). Capture 109. Legacy: `48:9694` 同意退款 确认, `48:9762` 不同意退款 校验错误, `48:9573` 已同意.
- **Frames (6 + 3):** the sheet is full height with two steps.
  1. `109 同意`: header (source, 退款单号 · time, amount ¥39.00); field「说明（选填）」, counter「0 / 500」, placeholder「写下可供平台审核的订单事实」; 审核凭证（选填）: upload row 选择图片并上传; primary 继续.
  2. `109 不同意`: label「不同意的原因 *」; 继续 disabled until filled.
  3. `109 补充凭证`: 审核凭证 * with an uploaded state (凭证已上传 · 移除).
  4. `109 确认`: step 2: the consequence sentence, rows 处理意见, 说明 (or「未填写」), 审核凭证 (「已上传 1 张」/「未上传」); error「售后处理未提交」; primary = the action's submit text (→ 提交中…).
  5. `109 已处理`: page without the three action pills; a sentence explains why it can no longer be answered; 处理记录 shows the merchant response with「售后凭证 · 查看」.
  6. `109 工单`: manual-case variant: no 商家意见 / 款项结果 / 退款金额 rows; the number row is labelled 工单编号.
  Generic: K1 `card`; K2「退款售后加载失败」; K3「当前岗位没有售后查看权限」sub「请联系店主开通」.

#### B-M08 · 预测待答: the list
- **Source:** `pages/merchant/predict/index.wxml`. Capture 108 is the empty state. Legacy: `48:19958`.
- **Frames (2 + 4):** `108 列表`: rows of prediction rounds (title, topic, deadline, status badge); one row open, showing its answer options as buttons. `108 公布答案`: alert「公布答案「<选项>」？」, body from the page script, buttons 再想想 / 公布并结算. Generic: K3「登录后查看预测」; K1; K2「待答列表加载失败」; K3「当前岗位不能公布预测答案」sub「请联系店主开通」.

#### B-M09 · 商家公开主页
- **Source:** `pages/merchant/profile/index.wxml` (shell) → public-home scene; `subpackageMember/components/cy/merchant-correction-sheet`. Capture 110 (关于 tab).
- **Frames (2 + 4):** `110 帖文`: tab 帖文 with the merchant's post cards, or empty. `110 信息纠错`: four small frames in one row: (a) option sheet「哪里不对」+ 下一步; (b) sheet 信息纠错:「问题类型：<类型>」, field 具体说明 (「写一下哪里不对、正确的信息是什么」), buttons 换个类型 / 提交纠错; (c) result「纠错已提交」+「平台审核后才会更新商家信息。」+ 知道了; (d) result「纠错没有提交成功」(返回修改 / 取消) and「提交结果未知」(再试一次 / 稍后再说). Generic: K1; K2「资料加载失败」; K5「链接已失效」; K4「商家不存在或未开放」.

#### B-M11 · 口碑
- **Source:** `pages/merchant/reviews/index.wxml` (258 lines). Capture 112 (manage). Legacy: `48:19743` 修改回复 sheet, `48:19808` 删除回复 alert.
- **Frames (7 + 7):**
  1. `112 写评价` (public mode, player, dark or light per the entry — the capture is light): rating header; card「写下这次体验 *」with five stars, note「过审后公开」, text area「说说环境、服务和真实到店感受」, counter「0 / 1000」, image grid (up to 9, tile 添加图片), error「评价未提交」, primary 提交真实评价.
  2. `112 暂不能评价`: the note in place of the form:「到店完成核销后才能评价」/「历史订单未关联门店，暂不能评价」/「登录后查看评价资格」.
  3. `112 回复中`: a review card with the input「写下公开回复…」focused and a send button.
  4. `112 修改回复`: the reply block in edit mode: input「修改公开回复…」, 取消, send.
  5. `112 举报`: under a card:「提交平台复核 *」, text area「请说明不实、攻击、广告或其他违规事实」, 取消 / 提交举报; after sending the line「举报已提交审核」.
  6. `112 回复待确认`: top banner「回复结果待确认：<请求号>」, buttons 读取原回复请求, 复制原请求号, row 联系平台客服.
  7. `112 删除回复`: K10.
  Generic: K1 `card`; inline「没有口碑管理权限」;「登录后查看口碑管理」;「评价加载失败」; K5「商家信息不完整」; K4「还没有真实到店评价」; filter empty「还没有符合条件的评价」; list end「已经到底了」/ 加载更多.

#### B-M12 · AI 店铺参谋
- **Source:** `pages/merchant/marketing/ai-insight/index.wxml` (305 lines), `pages/merchant/components/cy/club-pool-cards`. Capture 113.
- **Frames (2 + 2):** `113 推荐主题`: sheet opened from a recommended topic card: cover, title, meta line, the call to action from the page script. `113 数据暂缺`: the hero replaced by a shell「基础数据暂未完整返回」sub「数据暂缺」, the rest of the page unchanged. Generic: K1; K2 with three titles:「请先登录」,「当前账号没有查看权限」,「店铺数据加载失败」.

#### B-M13 · 发现（商家）
- **Source:** `pages/merchant/relation/index.wxml`. Capture 114 (帖文 tab).
- **Frames (2 + 4):** `114 俱乐部`: tab 俱乐部: club cards in the merchant variant (card file `101:2`, capability tags); strip「正在更新合作对象」; inline「部分俱乐部资料暂不可用」; empty「暂无可合作俱乐部」. `114 发帖`: the composer sheet (same as B-C02 #20, light). Generic: K3「登录后查看发现」; K1; K2「帖文加载失败」; inline「合作数据加载失败」.

#### B-M14 · 成为城市节点
- **Source:** `pages/merchant/citynode/index.wxml` (139 lines), `cy/info-pop`, `cy/code-text`. Capture 115. **Reference:** owner file `ku2o…` C18 `4337:13077`. Legacy: `48:28960` 下线节点 alert, `48:29054` 节点码.
- **Frames (5 + 4):**
  1. `115 申请中`: 我的节点 with application rows above the nodes:「节点投放 · 南京东路猫咖驿站」+ badge 审核中;「节点认领 · <节点>」+ badge 审核中 + text button 撤回 (→ 处理中); a rejected row with「驳回理由」+ sentence; inline error「认领申请撤回失败」.
  2. `115 认领平台节点`: medium sheet: rows name + description + button 申请认领 (→ 提交中); inline「认领申请未提交」; empty「还没有可认领的节点」; error「可认领节点加载失败」.
  3. `115 到店打卡码`: medium sheet: QR (or the text code), node name, note「长按保存后张贴，长期有效」(in the app: a 保存到相册 button); error「打卡码加载失败」.
  4. `115 节点是什么`: popover from the title's info icon:「节点是门店在漫游地图上的打卡点，审核通过后玩家才能看到。」
  5. `115 配额`: the quota line in its variants:「在架节点 3/3 · 已满，先下线一个再投放」,「在架节点 0/0 · 当前没有节点配额，暂不能投放新节点」,「正在读取节点配额」, inline「节点配额暂未取回」.
  Generic: K1; K2「商家权限加载失败」/「节点加载失败」; K3「当前岗位不能管理节点」; K4「还没有节点」sub「申请上漫游地图」.

#### B-M15 · 报名成为节点
- **Source:** `pages/merchant/citynode/create/index.wxml`. Capture 116 (nothing configured). Legacy: `48:28971`.
- **Frames (3 + 4):** `116 可提交`: ① 店铺玩法 shows the chosen template title, a summary line, badge 已配置, button 重新配置; ② 确认店址 shows the store name and address, check + 已确认, button 重新选择店址; primary enabled. Intermediate copy for ②:「玩家需到达店址 80 米内，请确认位置」with 确认这个店址 / 重新选择; with no address:「请在地图上选择店门口」+ 在地图上标店址. `116 已提交`: after submit, with inline「申请状态更新中」or the error「投放申请未提交」. `116 离开确认`: alert「放弃未提交草稿吗」/「玩法或店址还没有提交，直接离开会丢失本页草稿。」/ 继续编辑 / 离开. Generic: K3「登录后配置节点」; line「正在确认经营团队权限…」; K3「当前岗位不能管理节点」; inline「商家权限加载失败」.

#### B-M16 · 品牌中心
- **Source:** `pages/merchant/decor/index.wxml` (556 lines), `decor/components/hours`, `cy/tag-sheet`. Capture 117 (home view). Legacy: `48:33170`.
- **Home (present):** logo + name (edit), cover (edit), 营业中 switch, 看公开主页, rows 门店信息, 品牌介绍, 门店相册「6 张照片」, AI 店铺角色, 合作经营, and 入驻资料「执照 · 品牌材料」while not yet active.
- **Frames (10 + 4):**
  1. `117 品牌介绍`: view `brand`: city role or name with 编辑; row 一句话介绍; 品牌故事 with 编辑 and the text (placeholder「把店铺和这座城市的故事，讲给路过的人听。」); 特色标签: an expandable picker with grouped chips, custom chips, link 添加自定义标签, button 完成; collapsed it shows the chosen tags or「选几个标签，让更多人找到你的店」.
  2. `117 合作经营`: view `coop`: 承接设置 (summary or「完善你的承接能力」); 合作诉求; 招牌主推 (expandable: 不设置主推, list of activities, states「正在载入活动…」,「… · 重试」, link 去发布一个活动); 口碑; 常备权益「1 项」/「添加权益」; 衍生权益; 升级权益 (expandable: status sentences, 生效授予记录 rows with name + period + usage, tier rows with name + description and「可开通」, row 联系运营开通); 成为城市节点.
  3. `117 门店信息`: view `basic`, read mode: rows 店铺名称, 经营类目, 行业类型, 联系电话, 门店微信, 门店二维码 (查看 / 上传二维码), 店铺地址, 经营时间; unset values read「未设置」; bottom button 编辑. Add the edit-mode variant (rows show chevrons; button reads 完成编辑).
  4. `117 入驻资料`: view `qualification`: rows 营业执照「已提交 · 查看」, 品牌形象图「3 张 · 查看」.
  5. `117 字段`: two variants of the field sheet: single-line (bottom sheet: input, counter, 保存) and multi-line (large sheet: text area, 保存); error「暂未完成」turns the button into 重试保存.
  6. `117 标签`: tag sheet + the small sheet 自定义标签 (input「填写标签，最多 16 字」, button 添加).
  7. `117 经营时间`: the hours sheet (same content as B-M02 #13).
  8. `117 修改图片`: full screen, dark: title「修改 Logo」or「修改封面图」, ✕, the image (or「选择一张图片」with a camera icon), buttons 从相册选择 and「使用这个 Logo」/「使用这张封面」.
  9. `117 还没有保存`: K9.
  10. `117 升级权益 · 支付状态`: the sentences as separate small states:「正在确认支付结果…」,「支付结果待确认，请勿重复支付。」,「支付已确认，正在确认权益。」,「支付已确认，权益待确认，请勿重复购买。」,「自助开通暂未开放，可联系运营。」,「权益读取失败，当前状态未知。」+ row 重新读取权益.
  Generic: K1 `detail`; K3「暂无装修权限」sub「请切换到已审核的商家账号」; K2「品牌中心加载失败」; K4「暂时无法装修店铺」sub「完成商家入驻后可用」; top inline「资料暂未保存」.

#### B-M17 · AI 店铺角色
- **Source:** `pages/merchant/decor/ai-npc/index.wxml` (312 lines). Capture 118 = home with the intro sheet at step 1. Legacy: `48:33274` 底页, intro 1–4 `48:33304`, `48:33364`, `48:33449`, `48:33526`.
- **Frames (10 + 2):**
  1. `118 底页`: no sheet. Title AI 店铺角色; avatar (pixel art 咖啡掌柜 or the uploaded photo); name; status badge 已上线 / 审核中 / 已驳回 (+「驳回理由：…」); rows 角色形象 (已设置), 角色声音 (生成中 / 可用 / …), 名字, 招呼语, 性格设定, 店铺知识「菜单与招牌」, 漫游落点; button 编辑.
  2. `118 编辑`: same with editable rows (角色形象 reads「上传 / 更换」); button 完成编辑.
  3. `118 上传角色形象`: view with nav title 上传角色形象: preview area with「预览效果」or「正在处理形象，请稍候」; buttons 上传照片 and 选现成的; error「暂未完成」; primary 保存形象.
  4. `118 引导 2–4`: the intro sheet at steps 2, 3, 4 (three sheets on one frame). Copy: 1「它是你的店在城瘾里的分身」/「出现在漫游地图和店铺主页上，替你招呼路过的玩家」; 2「玩家路过，它先打招呼」/「按你写的招呼语和性格说话」; 3「菜单和营业时间它都答得上」/「读的是你门店资料里的内容」; 4「起个名字、选个性格就能用」/「温柔、可爱、毒舌，随时可改」. Controls: back chevron, dots, 跳过, primary 下一步 (last step: 知道了). The trailing full stop is neutral, not purple (twin `170:3821`).
  5. `118 选现成的`: medium sheet: grid of preset avatars with names, primary 使用这个形象.
  6. `118 字段`: sheet for 名字 / 招呼语 (single line with counter「6/12」) and 店铺知识 (large, multi-line); button 保存.
  7. `118 性格设定`: sheet with three rows: 温柔「轻声细语，耐心周到」, 可爱「活泼俏皮，爱用语气词」, 毒舌「嘴上不饶人，心里很热情」; a check on the chosen one.
  8. `118 声音 · 录制`: sheet「让店铺角色用你的声音说话」: consent check「我确认这是本人声音，或已获得声音权利人的明确授权；同意将本段录音提供给阿里云百炼生成店铺角色音色。」; heading 录制声音 with three progress dots; the sentence to read; a large button「按住说话」/「松开结束」; then 确认这句; after three:「三句已录好」+「18 秒 · 确认声音清晰、没有背景音乐」, 试听录音, 重新录音, primary 确认并生成声音. Microphone denied: button 去设置开启麦克风.
  9. `118 声音 · 状态`: four small sheets: 声音生成中 (skeleton line +「声音正在生成，可以先返回继续装修店铺。」+ 刷新状态); 声音可用 (「角色的声音已准备好。」+ 试听原录音, 重新录音, 清除声音); failed (「声音生成失败，请重新录一段清晰的声音。」); unknown (「原结果未知，仍可能完成并占用额度。不会自动重发。」+ 查询原请求, 确认后另起独立请求).
  10. `118 还没有保存`: K9.
  Generic: K1 `detail`; K2「角色资料没能打开」.

#### B-M20 · 常备权益: form
- **Source:** `pages/merchant/decor/perks/index.wxml` (234 lines). Capture 121 (list). Legacy: `48:36447`, `48:36487`.
- **Frames (4 + 4):** `121 添加`: nav title 添加常备权益; fields in order: 权益类型 * (dropdown: 礼品, 优惠券, 折扣), 权益名称 * (「例如：双人咖啡券」), 零售价 * (「请输入金额」), 成本 with note「· 仅自己可见」, 可接待份数 * (「请输入正整数」), 有效期 (「请选择日期」); primary 保存权益. `121 校验`: the form with field errors and the bottom error「常备权益保存状态待确认」. `121 删除` K10. `121 还没有保存` K9. An expired perk on the list shows the badge「已失效 · 请重新添加」. Generic: K1; K3「暂无编辑权限」; K2「权益加载失败」; K4「还没有常备权益」.

#### B-M21 · 合作中心: the other tab
- **Source:** `pages/merchant/coop-center/index.wxml`. Capture 122. Tabs: 官方活动 | 广场 (default 广场), bell at the right. **Reference:** 新稿 merchant file 02 `234:276` (a decision view: mode, seats left, schedule, settlement terms, deadline).
- **Frames (1 + 4):** draw the tab that `112:834` does not show. 广场 cards: cover, mode chip, seat chip, title, line「上海 · 11.13–12.13 · <条款>」, station count, deadline, pill 看详情; footer scope line. 官方活动 cards: city (or 全城), title, subtitle, recruitment gap label + text, pill 查看活动. Generic: K1 `card`; errors「路线加载失败」,「官方活动加载失败」; empties「还没有开放的路线」,「还没有官方活动」; strips「正在刷新开放承接路线…」,「正在刷新官方活动…」.

#### B-M22 · 客户名册: tools
- **Source:** `pages/merchant/customer/index.wxml` (190 lines). Capture 123. **Reference:** 新稿 merchant file `471:6605`; owner file `ku2o…` F08 `4368:13083`.
- **Frames (5 + 5):**
  1. `123 筛选客户`: large sheet: header 取消 · 筛选客户 · 重置; 我的分群 chips (saved segments); 客户类型: 全部, 回头客, 新客, 有备注 (check on the selected); 客户来源: 全部, 主题, 活动; 来源时间: two date fields 开始日期 至 结束日期; 客户标签: 全部标签 + tags (已到店, VIP); row 存为分群 (+); primary「查看 2 位客户」.
  2. `123 管理`: small sheet with three rows: 批量标签, 导出, 触达记录.
  3. `123 批量`: list in select mode: a bar「已选 2 / 100」+ 取消批量 + input「输入标签名称」+ 添加; rows gain a check circle; error「标签未添加」.
  4. `123 导出`: the banner above the list in each state:「正在生成脱敏 Excel，可继续浏览客户」;「导出已就绪（2 行）」+ download button;「导出文件已生成，这台手机没能下载下来」+ 重新下载;「导出已过期，请重新创建」;「导出失败」.
  5. `123 结果`: K11.
  Generic: K3「当前岗位没有客户查看权限」sub「请联系店主开通」(or「当前账号不能查看客户」); K1 `card`; K2「客户名单加载失败」; K4 with the segment-specific title; list end「共 2 位客户 · 已全部显示」.

#### B-M23 · 客户详情: editor
- **Source:** `pages/merchant/customer/detail/index.wxml`. Capture 125.
- **Frame (1 + 5):** `125 编辑标签与备注`: large sheet: 客户标签: chips with ✕ (已到店, VIP) or「还没有店内标签」, input「输入新标签」+ 添加标签; 客户备注: text area「记录偏好、承诺事项或下次联系计划」, 保存; when correcting:「正在更正备注 #…；系统追加新记录，不改原文。」+ 取消更正 (show a date, not the raw id); 跟进与触达: history rows with 更正 and 隐藏这条跟进. Errors「标签未添加」,「备注未保存」. Generic: K1; K2「客户详情加载失败」; K4「找不到这位客户」; K3; records empty「暂无参与记录」.

#### B-M24 · 本站准备与运行
- **Source:** `pages/merchant/game-node/index.wxml` (276 lines), `cy/time-range`. Capture 124 = status 准备完成 / 待开场. **Reference:** 新稿 merchant file: 暂停接待 `281:494`, 这一站怎么接待 `469:1002`, 服务时段与接待容量 `469:1025`, 本站复盘 `469:1087`, A5 我的站点运营 `447:1156`. Legacy: `48:26675`.
- **Page order (present):** station card (name「南京东路猫咖驿站 · 老城钟楼」, status, summary; tiles 接待容量 30, 待核验 0, 玩家状态 待开场 / 可接待 / 不可接待) → 这一站怎么接待 → 最近操作 → 本站复盘.
- **Frames (11 + 4):**
  1. `124 节点邀请`: card 节点邀请 with 拒绝邀请 (secondary) and 接受邀请 (primary).
  2. `124 准备清单`: checklist rows with check boxes; 接待容量 * (「每个时段最多接待人数」); 服务日期 *; 服务时段 * (opens the range sheet); 准备备注（选填）「给主办方留一句现场说明」; primary 确认准备完成; field errors.
  3. `124 运行中`: tile 可接待; block 本站运行 with 出示打卡码 (primary), 暂停接待 (secondary), 输入核验编号 (secondary), 扫码核验 (primary — keep one primary: 出示打卡码; draw 扫码核验 as secondary); 这一站怎么接待 filled: 你要做的 / 玩家会做什么 / 不能说的, and the closing line「这三条会毁掉后面几站的体验 —— 主办方设计的剧情你看不到，也不需要看到。」
  4. `124 已暂停`: block 暂停信息: 暂停原因, 预计恢复, 备用方案; note「暂停期间如需退款请联系平台客服。」; primary 恢复接待.
  5. `124 多站`: a dropdown above the card to switch stations (「切换」).
  6. `124 结果待确认`: K8 with 确认操作结果 and 重试原操作.
  7. `124 拒绝节点邀请`: sheet: note「拒绝原因将告知主办方」; reasons 档期冲突, 现场资源不足, 本站暂不适合承接; destructive 确认拒绝.
  8. `124 暂停接待`: sheet: note「暂停后玩家立即不可预约本站」; reasons 现场满员, 人员暂时离岗, 设备或道具异常, 现场突发情况; 预计恢复 * (date + time); 备用方案（选填）dropdown「选择已审核的备用方案」; preview「玩家将看到：…」or the note「当前没有已审核的备用方案，可以直接暂停；玩家会看到本站暂停和预计恢复时间。」; destructive 确认暂停.
  9. `124 核验游戏提交`: large sheet: 核验编号 * (「输入玩家提交页显示的正整数编号」); two choices 通过 / 驳回; when 驳回: reasons 答案不正确, 凭证无法辨认, 重复提交; primary 提交核验结论.
  10. `124 服务时段`: time-range sheet (start and end wheels).
  11. `124 本站打卡码`: K12, desc「一次有效，扫后自动更新」.
  本站复盘 rows for a played station: 到站玩家, 任务提交, 核验通过 / 驳回, 证据已记录, 正常完成 / 保底完成, 暂停事件, 公开授权内容; before data:「复盘数据待确认」(the twin `170:3884` already shows "—").
  Generic: K1 `card`; K4「暂无本站任务」; K2「暂时不能查看本站」,「本站状态加载失败」.

#### B-M26 · 收款账户
- **Source:** `pages/merchant/payout-account/index.wxml`. Capture 127 (已开通). **Reference:** owner file `ku2o…` C58 `4338:13077`. Legacy: `48:12668`.
- **Frames (1 + 5):** `127 待签约`: rows 开通状态 = 待签约 (or 待验证), 商户号, 更新于, a description line, primary 复制签约链接 (or 复制验证链接). Generic: K1; K2「收款账户加载失败」; K3「当前岗位没有财务查看权限」; K4「收款账户暂未开放」; K4「还没有开通收款账户」.

#### B-M27 · 触达记录: detail
- **Source:** `pages/merchant/crm-campaigns/index.wxml`. Capture 128. Legacy: `48:21999` 新建触达 sheet.
- **Frame (1 + 4):** `128 触达明细`: medium sheet titled with the campaign name: five counters 名单人数, 已送达, 未同意, 频控跳过, 未送达; note「名单不含联系方式」; recipient rows, or「这次触达没有逐人结果」; error「触达明细加载失败」. Generic: K1; K2「触达记录加载失败」; K3「当前岗位没有营销数据查看权限」; K4「还没有触达记录」.

#### B-M28 · 经营团队
- **Source:** `pages/merchant/team/index.wxml` (118 lines). Capture 129. **Reference:** owner file `ku2o…` F29 `4339:13158`. Legacy: `48:36558` 邀请员工 sheet.
- **Frames (6 + 3):**
  1. `129 加入经营团队`: invite landing: title 加入经营团队, line「南京东路猫咖驿站 · 核销员」, primary 接受邀请, result line after accepting.
  2. `129 邀请已创建`: a card「核销员邀请已创建」+「<时间> 前有效」+ button 立即分享; section 待接受邀请「1 条」with rows「核销员邀请 · <时间> 失效」(tap to revoke).
  3. `129 选择邀请岗位`: half sheet: role rows with a name and a permission summary line, chevron.
  4. `129 调整岗位`: same sheet for a member: the current role is marked「当前」; a destructive row 移除 at the bottom.
  5. `129 确认`: K10 for 移除 and for 撤销邀请.
  6. `129 员工视角`: non-manager: rows 门店, 我的岗位; primary 进入工作台; no list.
  Generic: K3「登录后查看经营团队」/「登录后查看邀请」; K1; inline「经营团队加载失败」/「请确认登录或经营权限」; block error「团队名单加载失败」; empty line「还没有员工」.


### 6.3 Merchant ↔ topic, cooperation, in-store

#### B-T01 · 主题招商详情 / 承接进度
- **Source:** `pages/topic/merchantinfo/merchantinfo.wxml` (571 lines; role views `project-join`, `project-host`, and the browse view). Capture 091 = the merchant's 承接进度 view (light). Section on R1 holding `113:1167`.
- **Reference:** 新稿 merchant file: 03 主题详情 TD-1 `181:575`; 04 选承接标的 `159:346`; 07 承接进度 states M1 待确认 `88:4014`, M2 被驳回 `88:4170`, M3 已确认 `88:4368`, M4 进行中 `88:3776`, M5 已结束 `88:4583`, M6 自发布 `88:4798`, M11 加载失败 `126:310`; 主办方视图 H1–H6 `118:311`, `125:325`, `123:310`, `124:310`, `124:318`, `124:326`; 更多 sheets `468:960`, `468:1009`, `468:1086`, `468:1126`.
- **Conflict to settle before drawing:** the code's browse tabs are 详情 | 任务向导. The owner file records that the tab names are 详情 / 路线节点 / 路线 and that "任务向导" is wrong (archive TD-2 `181:715`). Follow the owner naming and say so in the annotation.
- **Frames (10 + 4):**
  1. `091 浏览 · 详情`: browse view. Full-bleed hero: cover, type label 自由探索 or 城市定向, title, one-line intro (fallback「一条可由商家承接的城市路线，看看你的店铺能参与哪一站」), a down arrow. Second screen: cover, category chips, a horizontal stat bar (label, value, stars or sub), tabs, then: title + subtitle; 节点介绍 (horizontal template cards: image, title, players, minutes); 主题介绍; 活动内容 bullets. Bottom primary 申请承接 (or 承接进度 once applied).
  2. `091 浏览 · 路线节点`: the guide tab: per chapter: name, meta (time, place, play), blocks of text, images, audio, numbered node steps with image carousel + title + description. Empty「暂无任务向导」.
  3. `091 我的承接`: block「我在这条路线上的承接」. 我的节点: name, address (or「未填地址」),「· 待审核 / 已通过 / 已驳回」,「驳回原因：…」, button 节点NPC (approved) or the note「审核通过后可配置节点内容」. 我的承接申请: link 申请承接其他章节; rows「<章节> · <状态>」+ terms; buttons by state: 配置节点, 填写实际供给, 接受邀请, 拒绝邀请 / 撤回; lines「实际供给已生效 · 剩余 N · 最近确认 <时间>」, 退出供给,「实际供给待审核」, 供给无变化，重新确认, 暂停供给.
  4. `091 主办方`: host view per 新稿 H1 `118:311`.
  5. `091 进度 · 待确认 / 被驳回 / 进行中 / 已结束`: four variants of the present frame following M1, M2, M4, M5 (the present frame is M3 已确认 · 未开始).
  6. `091 选择承接节点`: medium sheet: topic name,「已选：…」, row 承接方式 (opens #7), 选择节点 chips, primary 报名.
  7. `091 路线模式介绍`: large sheet: intro line, then two cards. 自由探索模式 ·「灵活安排时间」:「玩家在主题周期内自由到店打卡完成任务。」, two bullets, 商家收益 paragraph. 城市定向模式 ·「固定时间出发」:「玩家在指定时间统一出发，按路线顺序完成任务。」, two bullets, 商家收益 paragraph. Copy in Appendix B.
  8. `091 选择章节`: the chapter target picker (自由探索 topics).
  9. `091 打卡码`: K12 in two variants:「本站打卡码」/「长期有效，可保存后张贴」and「本主题二维码」/「玩家用微信扫一扫，直接进入这个主题」(rewrite the scan wording for the app), secondary 保存到相册.
  10. `091 分润明细`: medium sheet: lock note「档位按章节在开售时定好，不能改」; tier chips per party; 本主题已入账 + 待结算 + 已售; block「每卖出 1 份」with a split bar and legend (怎么分); 各方到手 rows; 结算 steps; link 全部收益. States「正在读取…」,「分润明细没读到」,「这个主题还没有分润记录，开售并核销后会出现在这里」.
  Generic: K5; K3「登录后查看主题」;「当前账号无权查看」; K2「加载失败」.

#### B-T02 · 申请成为合作点位
- **Source:** `pages/topic/merchantapply/index.wxml` (256 lines). Capture 092 (empty form, light). **Reference:** 新稿 merchant file 05 承接报名表单 `133:310` (owner decision 2026-09-04: a full page, not a sheet), 06 报名成功 `365:957`.
- **Form order (present):** 承接标的 (node, topic · chapter) → 你的门店 card (cover, hours, name, address) → 承接地点 * → 承接说明 * (「填写可用空间、接待安全条件、拍摄许可、现场可配置物料」, 0/500) → 承接图片 * (「上传现场照片」,「5:3 横图，1–9 张」) → 可配合的时间: 可配合日期 * (「点击选择日期区间」), 每日可接待时段 选填 → 限定人数 (「不填则不限」) → primary 提交报名.
- **Frames (5 + 4):** `092 已填`: all fields filled with three photos, one field error and the bottom error「报名暂未保存」. `092 报名已提交`: success:「报名已提交」,「主理人确认后生效，预计 1–3 天」, the target summary, primary 查看承接进度; success motion per owner board `356:4674`. `092 修改`: edit mode with button 保存修改, and its success「修改已保存 / 已重新提交审核」with 查看承接进度 + 返回商家首页. `092 选择可配合日期`: date-range sheet. `092 可配合时间`: sheet with two wheel pairs 开始时间 至 结束时间, primary 完成. Generic: K3「登录后填写报名」; K1 `form-section`; K2「报名信息加载失败」; K3「当前账号没有商家报名权限」/「这份报名现在不能修改」.

#### B-T04 · 协作邀请列表
- **Source:** `pages/coop/list/index.wxml` (268 lines). Capture 130 (收到的). **Reference:** 新稿 club file 02b `393:414`, 02c `394:414`, bell badge `356:405`; 新稿 merchant file `261:277`, `261:349`; owner file `ku2o…` 邀约 V2 `5455:19337`.
- **Frames (3 + 6):**
  1. `130 发出的`: tab 发出的. Card: status chip,「发给 南京东路猫咖驿站」, thumbnail + title + line「<类型> · <席位>」, terms, 核销据点 line, contact + 复制, deposit line, message. Footer by status: 待确认 → 撤回邀约; 已拒绝 → note「对方已拒绝，可再邀其他商家。」+ 再邀别人; 已接受 → 查看合作 (+ 缴纳保证金).
  2. `130 卡片种类`: one frame with the four other card kinds, each once: 章节承接记录 (status, topic, chapter · merchant, link「查看承接」/「查看与补供给」/「查看退出记录」); 带队申请 (拒绝 / 回邀约; 查看合作详情); 承接报名 (确认占槽; 发邀约); 官方邀约 (「来自 平台」, 拒绝 / 接受合作).
  3. `130 保证金`: a card with 缴纳保证金 (→ 支付处理中…) and one with 重试保证金退款; the top strips for a finished action and for「操作未完成」.
  Also: a topic filter line with 看全部; incomplete-data cards「邀约信息待确认」,「邀请信息不完整」.
  Generic: K3「登录后查看协作邀请」; K1; K3「当前账号不能查看协作邀请」; K2「协作邀请加载失败」; K4「还没有收到协作邀请」,「还没有发出协作邀请」.

#### B-T05 · 协作邀约详情
- **Source:** `pages/coop/invite-detail/index.wxml` (215 lines). Capture 131 = 已接受, received. **Reference:** 新稿 club file `378:426`, `390:413`, `390:475`, `390:526`, `390:575`. Legacy: `48:24326` 待确认, `48:24569` 接受合作 sheet, `48:24635` 拒绝 alert.
- **Page order (present):** status + 「来自 城瘾跑团 · 11月14日 19:26」 + topic + type → banner「邀请你承接 / 南京东路猫咖驿站」→ 主题详情 → 合作条款 (合作双方, 分润, 核销据点, 席位, 保证金, credit line) → 联系方式 → 留言 → 合作操作 → status line.
- **Frames (5 + 4):**
  1. `131 待确认 · 收到`: status 待确认 + countdown; 联系方式 reads「接受合作后可查看联系方式」; no 合作操作; a reason field (label and placeholder from the page script, counter「0 / 100」); bottom bar 拒绝 (secondary) + 接受合作 (primary).
  2. `131 待确认 · 发出`:「发给 …」; contact line「对方接受后可查看联系方式」; bottom button 撤回邀约.
  3. `131 已结束`: 已拒绝 / 已撤回: 留言 shows the handling reason with「我方 / 对方 · 处理理由」; contact line「邀约已结束，无法联系对方」; bottom line「这条邀约已拒绝」. Add the read-only legacy note「历史商家节点邀约仅供查看」as a variant.
  4. `131 申报本次供给`: large sheet: rows「优惠券 · 到店赠美式一杯」+「成本 ¥12 · 配额 200」with check boxes; primary 确认申报 (→ 申报中…); empty「还没有常备权益」sub「去「承接档案」维护后再来」; error「常备权益加载失败」.
  5. `131 评价`: option sheet「这次合作打几分」+ 下一步, then the 合作操作 row in its done state「已评价 ★★★★★」.
  The 合作操作 row 取消合作 has two forms: tappable, and locked with the note「已锁价，修改请联系客服」.
  Generic: K1 `card`; K2「无法打开这条邀约」;「这条邀约不在当前列表里了」;「协作详情加载失败」.

#### B-T06 · 发起协作邀请
- **Source:** `pages/coop/invite/index.wxml` (168 lines). Capture 132 = target locked. **Reference:** owner file `ku2o…` C57 `4386:13083`, `4386:13136`.
- **Frames (5 + 6):**
  1. `132 选择对象`: no preset target. ① 关联主题 * as a dropdown「选择我发布的主题」(note「该主题不在招商期」when closed); ② 合作条款: 引流合作（不产生现金结算） or the fee option with an amount field「¥ 0.00」; ③ 邀请对象: list rows name + 「4 位成员 · 上海」(clubs) or name + suitable types (merchants), trailing 邀请 / 已选; counter「已选 2」; link「附近商家 · 含未入驻商家可电话联系」; fixed bottom bar「发送邀约(2)」.
  2. `132 核销据点`: block 核销据点:「每条邀约明确选择一个据点；商家接受后冻结，订单间不能重复使用。」, one dropdown per chosen merchant; hints「先选择合作商家，再选择该商家的已确定据点。」,「暂无已确定据点」.
  3. `132 编辑邀约语`: sheet: 邀请对象 · 已锁定 (name, meta); 拟议条款 · 对方接受并成单后锁定; per merchant「核销据点：…」; 协作邀请 card「关联主题 · 外滩夜探」; note「对方会在「收到的」中确认本次协作。」; 邀请语 text area「写下想对对方说的话」; link「主题条款没配好？去编辑主题(票价/内容)」after a failure; primary「发送邀约(1)」(→ 发送中…).
  4. `132 结果`: K11 sent and failed.
  5. `132 结果待确认`: top block「以下邀请结果待确认，请勿重复发送。记录未出现也不能证明未发送；无法确认时请联系平台处理。」with names, 查询原请求, 查看已发出邀请. Do not show raw request or invite ids.
  Generic: K3「登录后发起协作邀请」; K1; K3「当前账号不能读取主题」/「当前账号无权查看合作对象」; K2「主题加载失败」/「合作对象加载失败」; K4「还没有可关联的主题」sub「先发布主题后再发起协作邀请」; K4「还没有可邀请的俱乐部」/「还没有可合作的商家」.

#### B-T07 · 附近可邀约商家: the list
- **Source:** `pages/coop/nearby/index.wxml` (56 lines). Capture 133 is the empty state (light). **Reference:** merchant card 0928, card file `105:2` state 05 (找场地: capacity, venue fee, suitable play types); owner file `ku2o…` E03 `4339:13077`. Legacy: `48:17421` 有商家, `48:17492` 需要位置权限.
- **Frames (2 + 5):** `133 有商家`: title 附近商家; merchant cards in the venue variant; under a card that is not on the platform, a small secondary button 电话联系; strip「正在刷新附近商家…」. Use 南京东路猫咖驿站 plus two more venues with real photos already in the file. `133 选择补位操作`: K13. Generic: K1; K3「登录后查看」; K3「当前无法查看附近商家」sub「需要定位权限才能找附近商家」(draw the iOS location primer per R6 A29–A34); K5「主题信息无效」; K2「附近商家加载失败」.

#### B-T12 · 我的项目（商家）
- **Source:** `subpackageA/pages/myproject/index.wxml` (189 lines). Capture 029 (主题 tab). **Reference:** 新稿 merchant file 08 `260:277`, `260:370`; owner file `ku2o…` B32 `4363:13083`.
- **Frames (5 + 5):**
  1. `029 活动`: tab 活动: same cards (date dot, status, title, address, last line「0 报名 · 0 浏览」or the pending-verify / accept status text).
  2. `029 模板`: tab 模板: 主题模板 cards; 节点玩法 cards with market status, short status, title,「3 次引用 · 20 分钟」, reason lines「个人审核：…」,「广场：…」, row actions 提交广场, the market toggle, 审核记录, 删除. Empty「还没有模板」.
  3. `029 管理`: action sheet from a long press (hint line「长按卡片管理」): 编辑, 收到的申请, the publish toggle, 取消主题并退款 / 取消活动, 审核记录, 另存为模板, and 删除 in a separate destructive group. In the app this is a context menu or a ⋯ button; note it in the annotation.
  4. `029 审核记录`: sheet: record rows (label + sub); block 申诉 with the appeal text, attachments (up to 6, note「最多6张，须本人上传并通过内容安全审核；以平台校验为准」), button 申诉 with note「每条内容可申诉一次」; pending state 读取原申诉结果; empty「暂无记录」.
  5. `029 确认`: the five K10 alerts: delete activity, cancel activity, cancel topic (with refund), delete route, delete template.
  Generic: K3「登录后查看我的项目」; shell「项目加载中」; K3「当前身份不能查看这些项目」; K2「项目加载失败」; K4 with the tab's title; footer「仅显示最近 200 条」.

#### B-T15 · 商家打卡游玩（到店页）
- **Source:** `pages/play/merchant/index.wxml` (130 lines), `components/safety-rating-sheet`. Capture 017 is the dead-link state, so there is no capture of the page. Dark (player). Native counterpart: `App/PlayStoreDayMerchantView.swift`. Use 南京东路猫咖驿站.
- **Frames (9 + 1):**
  1. `017 待到店`: in order: hero image with a back button and a status pill 待到店; name; fact rows 营业 (hours) and 现场 (「可前往」/「排队中，建议先去别家」/「—」); block 现场记录 with three numbered steps: 1 扫描门店码「仅记录到店时间」, 2 拍摄现场凭证「到店后显示拍摄要求」, 3 商家核销「商家核销的时刻才算服务开始」; block 现场参考 with three tiles: 已到店待核销, 每小时接待, 预计等待(分) (unknown = "—"); block 商家信息: address row with 导航; bottom bar: 地址 (icon button) + primary 扫描门店码 (→ 记录中…).
  2. `017 已到店`: pill 已到店; step 1 done; step 2 shows the photo requirement; the rule text appears; primary 拍摄到店凭证 (→ 上传中…).
  3. `017 照片已记录`: pill 照片已记录; primary 出示核销码 (→ 确认授权中…).
  4. `017 已核销`: pill 已核销; bottom bar: 评价 (star) and a disabled label 已核销.
  5. `017 本站任务`: bottom card over the page: title (or 本站任务), the question, either lettered options or an input「写下你的答案」, primary 提交答案 (→ 提交中… / 结果待确认), error line with「· 再确认一次」; result state with the result text and the button「下一步 · 拍现场凭证」or 完成.
  6. `017 到店任务`: bottom card: title 到店任务, the photo requirement, the rule, primary 去拍照, text button 稍后再拍.
  7. `017 门店授权`: block 当前门店授权:「仅 南京东路猫咖驿站 可按现场事实查看必要信息」+ text button 撤回授权 (→ 撤回中…).
  8. `017 评价安全感受`: sheet: note「评价仅平台可见」, three chips 安心 / 一般 / 不安心, field 说说原因 (「例如：照明、店员引导、周边环境」), primary 提交评价; then K11「评价已提交」+ 知道了. States「正在读取评价选项…」,「评价选项没有加载」,「评价没有提交成功」.
  9. `017 待确认`: a strip above the bar「结果待确认 · 点这里确认」, and the degraded-message strip.
  Generic: K3 login gate. (K5「链接已失效」is the existing frame `95:977`.)

### 6.4 In the owner 新稿 only

B-N01 (会费设置, 我的账单) is in 6.1. N03 is frame 15 of B-C02, N04 is covered by B-C12, N05 by B-C20 frames 21–22, N06 by B-M24, N07 by B-T01 and B-T02. Where the mini-program and the 新稿 both exist, the 新稿 layout wins and the mini-program supplies data and copy.

#### B-N08 · 商家 Tab roots: 模板 and 我的
- **Source:** app handbook `5aU5V8MXZ5nPT0GtcOEEC7`: Merchant 模板 `290:547`, Merchant 我的 `290:997`; the merchant tab bar component on R4. No restored frame exists for either (the audit maps 我的 only loosely to the public profile `94:3480`).
- **Frames (2, light):** `N08 模板` and `N08 我的`, in a new section on R4 named「商家 Tab 根页」, next to the two roots that exist (工作台 `91:267`, 营销 `95:1649`) and 合作 `112:834`. Follow the handbook frames; tab bar with the neutral selected colour. For 模板, the page content is the merchant's templates (same cards as B-T12 frame 2); legacy layout `52:9582`. Ask the owner before drawing if the five merchant tabs are still 工作台 / 营销 / 模板 / 合作 / 我的: the owner ruling in the brief lists only the player tabs.

### 6.5 Native app only

These views exist in `DES-ag4/App` with no mini-program route. Copy is from the app's zh-Hans string catalogs. Put them in a new section on R6 named「商家与俱乐部 · 仅 App」, labels as given. Several carry engineering wording (回执, 原请求, 事实版本); draw the screen with the catalog copy and leave rewording to the review round.

#### B-A01 · 俱乐部活动 · 日历 (dark)
- **Source:** `App/ClubEventCalendarView.swift`; `docs/club-event-calendar.md` (from mini-program revision `f859cd6`, which had a list / calendar switch on the 活动 tab; the `backend-app-r3` WXML no longer has it).
- **Frames (3):** `A01 日历`: title 俱乐部活动; segmented control 列表 | 日历 (label 活动显示方式); month header with 上一个月 / 下一个月; weekday row 一 二 三 四 五 六 日 (Monday first); month grid, days with events marked; note「按活动开始日期显示，日期不代表仍有名额或报名已确认。」; hint「选择日期查看当天活动。」. `A01 选中日期`: a day selected with its event cards below, or「当天暂无开始的活动。」. `A01 空月 / 日期待明确`:「本月暂无开始的活动，可切换其他月份查看。」; a section 日期待明确 with the hint「以下活动暂未提供可用的开始日期，仍可查看活动详情。」.

#### B-A02 · 成员与活动概况（全页）(dark)
- **Source:** `App/ClubStatsOverviewView.swift`; `docs/club-stats-overview.md`.
- **Frame (1):** `A02 概况`: title 成员与活动概况; four totals 项目 9, 游玩人次 3, 完成人次 3, 完成率 100.0%; scope note「仅统计本俱乐部自办项目，不含承接来的项目。游玩人次为到过节点的去重玩家，不是报名人数。」; section 项目完成情况 with rows name + completed / participants + rate, note「展示前 5 个项目。」; rate note「完成率 = 完成人次 ÷ 游玩人次。缺失的数据显示为未知。」; a row with no participants reads「暂无游玩人次，完成率不适用」; empty「还没有可统计的项目数据」.

#### B-A03 · 场次状态 (dark)
- **Source:** `App/ClubTerminalSessionView.swift`; `docs/club-terminal-session-settlement.md`.
- **Frame (1):** `A03 场次状态`: title 场次状态; entry row「查看场次状态与结算」on the project; block 当前场次 with the session and its state; button 查看俱乐部结算报告 once the session has ended, otherwise the line「本场尚未结束，暂不提供此结算入口。」; 刷新当前场次; states「正在读取当前场次」,「这个主题还没有场次」,「场次状态暂不可用」,「场次上下文已变化，请从主题重新进入。」.

#### B-A04 · 本店 CITY 接入与暂停 (light)
- **Source:** `App/CityMerchantOperationsView.swift`, `SessionCityMerchantValueView.swift`. The merchant side of City Monopoly; N1 has no merchant frame. Entry: 品牌中心 row「本店 CITY 接入与暂停」.
- **Frames (3):** `A04 接入`: heading 本店 CITY 接入; rows 门店, 已发布棋盘, 规则发布, 事实版本; current fact line「经营事实：沿用平台规则」or「经营事实：暂停」; status sentence「仅可申请本店暂停或恢复，不会修改费率、规则或其他队伍资产」; block 提交本店意愿 with a reason field (请填写原因) and buttons 申请暂停本店 / 申请恢复本店; disclaimer「提交只是申请。授权审查与事实生效是后续步骤，不能据此认定游戏运行已暂停或恢复。」; link 返回品牌中心. `A04 确认`: alert「确认提交本店意愿？」with 门店 / 版本 / 原因 and the line「只修改本店经营意愿，等待授权审查。」, buttons 取消 / 确认提交. `A04 状态`: the status sentence in its main variants:「本店意愿已记录，等待授权审查；尚未改变运行状态」;「申请未获批准，原经营事实保持不变」;「提交结果仍未知。只能查询原请求，不能重复发送」+ button 只查询原请求结果;「本店 CITY 接入尚未获部署审批，暂不可用」;「当前服务器未开放商家写入。没有发送。」.

#### B-A05 · 商品规格 (light)
- **Source:** `App/MerchantDeskSkuPage.swift`.
- **Frames (3):** `A05 规格列表`: title 商品规格; product list → 规格 list; each row 规格名称, 参考价格, 「库存：20」; empties「当前权限范围内暂无商品。」,「该商品目前暂无规格。」; note「仅编辑既有 SKU 供给。所示价格仅供参考，保存保留服务端当前价格，不上架或售卖商品。」. `A05 编辑`: fields 规格名称, 将保存的库存, read-only「参考价格 · 保存保留服务端当前价格」; button 核对修改. `A05 确认`: sheet 确认规格修改 with the values, buttons 确认保存 / 返回编辑，不保存; results「修改已保存」,「提交结果待确认」+ 仅重读当前状态,「暂时无法完成修改」.

#### B-A06 · NPC 本地知识草稿 (light)
- **Source:** `App/MerchantNPCKnowledgeDraftView.swift`; `docs/c06-knowledge-journal-APPLY.md`. Opened from AI 店铺角色 → 店铺知识.
- **Frames (3):** `A06 草稿`: title NPC 本地知识草稿; banner「本地草稿 · 未提交审核 · 未用于 AI 回答」; five sections, each with an add button and removable rows: 营业时间 (星期, 开始营业, 结束营业, 时区; 添加营业日), 商品 (商品名称, 价格, 币种; 添加商品), 活动优惠 (标题, 开始时间, 结束时间; 添加活动优惠), 常见问答 (问题, 回答; 添加问答), NPC 禁止表述 (添加禁止表述); notes「请只填写可公开的经营事实。…」and「仅暂存在此 NPC 页面内存中。…」; primary 暂存本地草稿. `A06 校验`: block「请检查以下字段」with two example errors (「同一个星期只能填写一次。」,「结束时间须严格晚于开始时间，营业时间须在同一天内。」). `A06 已暂存`: confirmation「已暂存到此页面内存」; failure「仅限有资料编辑权限的有效商家所有者使用，本地内容已清除。」+ 重新检查权限并开始.

#### B-A07 · 触达 · 新建与预览 (light)
- **Source:** `App/MerchantEngagementComposer.swift` (`MerchantEngagementComposer`, `MerchantCRMFilterSummary`, `MerchantEngagementReviewView`). The mini-program only lists past campaigns (B-M27). Legacy layout: `48:21999` 新建触达 sheet.
- **Frames (2):** `A07 新建`: channel choice 站内消息 / 商家优惠券 (placeholder 请选择) and the audience summary taken from the customer filter, with the label 预计受众. `A07 预览并核对`: the review step (title 预览并核对) showing channel and audience before sending. I read only this view's string keys, not its layout: open the Swift file for the remaining fields before drawing.

## 7. What to draw first

A suggested order for the executor. Each batch is one section of this file.

| Batch | Specs | Missing items (section 2 count) | Why first |
|---|---|---|---|
| 1 | State kit K1–K14, dark and light | 14 components × 2 themes | Everything else instances these |
| 2 | B-C02 (incl. N03) | 33 | The club tab's main destination |
| 3 | B-M02, B-C03, B-C04 | 26 | Entry flows; the owner 新稿 already exists |
| 4 | B-T15, B-M24 (incl. N06) | 24 | On-site screens; one has no drawing at all |
| 5 | B-C20, B-C12, B-C13 (incl. N04, N05) | 45 | Host operations on event day |
| 6 | B-M01, B-M03, B-M07, B-M11, B-M22 | 31 | Daily merchant work |
| 7 | B-M16, B-M17, B-M20, B-M14, B-M15 | 32 | Store setup |
| 8 | B-T01, B-T02, B-T04, B-T05, B-T06, B-T07, B-T12 (incl. N07) | 36 | Cooperation loop |
| 9 | All remaining club, merchant and cooperation specs | 64 | Smaller gaps |
| 10 | B-N01, B-N08, B-A01–B-A07 | 20 | New screens; two need an owner answer |
| 11 | Generic states per route, from Appendix A | 238 | Mechanical once the kit exists |

Batches 2–10 add up to the 311 screen-specific items. Some items become more than one frame and a few share a frame, as each spec says, so the frame count will differ slightly.

Open questions for the owner:
1. Merchant tab bar: is it still 工作台 / 营销 / 模板 / 合作 / 我的 (app handbook `290:5`–`290:997`)? Two of the five roots have no frame.
2. 会费设置 and 我的账单 are in the 新稿 but have no route in `backend-app-r3`. Draw them now, or wait for the route?
3. `topic/merchantinfo` tab names: the code says 详情 / 任务向导, the 新稿 says 详情 / 路线节点 / 路线.
4. The club 活动 tab calendar exists in the native app (from an older mini-program revision) but not in the current WXML. Keep it?


## Appendix A. Copy for every generic state, by route

Extracted from the WXML (`cy-empty`, `cy-error`, `cy-access-gate`, `cy-state-shell`). "When" is the condition as written in the template. A title in double braces is chosen at run time; the alternatives are inside it. Where "Sub" is a variable (`errorText`, `loadError` …) the text comes from the server: use the handbook sentence「网络没连上，请重试」or「请稍后重试」.

| Route | When (WXML condition) | Kind | Title | Sub / note |
|---|---|---|---|---|
| `pages/club/apply` | `bootstrapState === 'error'` | shell · {{bootstrapErrorKind ¦¦ 'dat | {{bootstrapErrorKind === 'no-permission' ? '登录后申请成为主理人' : '主理人资格未确认'}} | {{bootstrapError}} |
| `pages/club/apply` | `bootstrapState === 'merchant'` | shell · no-permission | 这个账号已经是商家 | {{merchantActive ? '一个账号不能同时是商家和俱乐部主理人，切换到商家端继续经营' : '这个账号有商家入驻记录，一个账号不能同时是商家和俱乐部主理人'}} |
| `pages/club/apply` | `bootstrapState === 'ready' && mode==='done' && doneState!=='ready' && ` | error | 主理人状态未确认 |  |
| `pages/club/badges` | `state === 'missing-param'` | shell · missing-param | (component default copy) |  |
| `pages/club/badges` | `state === 'error'` | shell · {{errorKind}} | 勋章列表没加载成功 | {{errorText}} |
| `pages/club/badges` | `state === 'empty'` | shell · empty | 还没有俱乐部勋章 |  |
| `pages/club/badges` | `membersState === 'empty'` | shell · empty | 暂无成员 |  |
| `pages/club/checkin-detail` | `` | gate · login | (access gate: login) |  |
| `pages/club/checkin-detail` | `state === 'denied'` | error | 核销记录不可见 | {{errorText}} |
| `pages/club/checkin-detail` | `state === 'missing'` | empty · not-found | {{errorText}} |  |
| `pages/club/checkin-detail` | `state !== 'ready'` | error | 核销凭证加载失败 | {{errorText}} |
| `pages/club/create` | `bootstrapState === 'checking' ¦¦ bootstrapState === 'redirecting'` | shell · loading | {{bootstrapState === 'redirecting' ? '正在前往主理人申请' : '正在确认创建资格'}} | {{bootstrapState === 'redirecting' ? '即将打开申请页' : ''}} |
| `pages/club/create` | `bootstrapState === 'error'` | shell · {{bootstrapErrorKind}} | 创建资格未确认 | {{bootstrapError}} |
| `pages/club/create` | `bootstrapState === 'guest'` | shell · no-permission | 登录后创建俱乐部 |  |
| `pages/club/create` | `bootstrapState === 'no-permission'` | shell · no-permission | 请先成为俱乐部主理人 | 申请通过后即可创建与管理俱乐部 |
| `pages/club/create` | `bootstrapState === 'limit'` | shell · empty | 已达创建上限 | 每位主理人最多创建 2 个俱乐部 |
| `pages/club/create` | `submitState === 'success'` | empty · success | {{submissionPending ? '已重新提交，等待审核' : '俱乐部已创建'}} | {{submissionReceipt.name}} · {{submissionReceipt.city}} |
| `pages/club/customer-detail` | `` | gate · club | (access gate: club) |  |
| `pages/club/customer-detail` | `state === 'no-permission'` | error | 当前岗位没有客户查看权限 | {{errorText}} |
| `pages/club/customer-detail` | `state === 'refused'` | empty · not-found | {{errorText}} |  |
| `pages/club/customer-detail` | `state === 'network-error'` | error | 客户详情加载失败 | {{errorText}} |
| `pages/club/customer-detail` | `state === 'error'` | error | 客户详情加载失败 | {{errorText}} |
| `pages/club/customer-detail` | `else` | empty | 暂无参与记录 |  |
| `pages/club/customers` | `` | gate · club | (access gate: club) |  |
| `pages/club/customers` | `state === 'no-permission'` | error | 当前岗位没有客户查看权限 | {{errorText}} |
| `pages/club/customers` | `state === 'network-error'` | error | 客户名单加载失败 | {{errorText}} |
| `pages/club/customers` | `state === 'error'` | error | 客户名单加载失败 | {{errorText}} |
| `pages/club/customers` | `state === 'empty' && (filterKey !== 'all' ¦¦ keyword)` | empty | 没有符合条件的客户 | 换个筛选试试 |
| `pages/club/customers` | `state === 'empty'` | empty | 还没有客户 |  |
| `pages/club/detail` | `notFound` | error | (component default copy) |  |
| `pages/club/detail` | `loginRequired` | empty · no-permission | 登录后查看俱乐部 |  |
| `pages/club/detail` | `clubGoneText` | error | {{clubGoneText}} |  |
| `pages/club/detail` | `commentsError` | error | 评论加载失败 | {{commentsError}} |
| `pages/club/detail` | `commentsLoaded && !comments.length` | empty | 还没有评论，来抢沙发 |  |
| `pages/club/detail` | `postsError` | error | 帖文加载失败 | {{postsError}} |
| `pages/club/detail` | `postsLoaded` | empty | 暂无帖文 | {{canSeeMembers ? '' : '入会后可发布'}} |
| `pages/club/detail` | `else` | empty | 暂时俱乐部还没有活动 |  |
| `pages/club/detail` | `topicState === 'error'` | error | 活动列表加载失败 |  |
| `pages/club/detail` | `membersState === 'business-error'` | error | 成员列表加载失败 |  |
| `pages/club/detail` | `membersState === 'network-error'` | error | 网络连接失败 |  |
| `pages/club/detail` | `members.length === 0` | empty | 暂无成员 |  |
| `pages/club/detail` | `else` | empty | 加入俱乐部后可查看成员 |  |
| `pages/club/detail` | `leaderboardError` | error | 榜单加载失败 | {{leaderboardError}} |
| `pages/club/detail` | `leaderboardLoaded` | empty | {{leaderboardEmptyTitle}} |  |
| `pages/club/detail` | `clubStatsState === 'error'` | error | 数据看板加载失败 | {{clubStatsError}} |
| `pages/club/detail` | `else` | empty | 还没有可统计的项目数据 |  |
| `pages/club/detail` | `topicState === 'error'` | error | 项目列表加载失败 |  |
| `pages/club/detail` | `club.isOwner ¦¦ canManageActivities` | empty | 还没有项目 |  |
| `pages/club/detail` | `else` | empty | 暂无分配给你的项目 |  |
| `pages/club/detail` | `shareEditionState === 'error'` | error | 期次加载失败 |  |
| `pages/club/detail` | `shareEditionEmptyRetry` | empty | {{shareEditionEmptyTitle}} | {{shareEditionEmptySub}} |
| `pages/club/detail` | `else` | empty | {{shareEditionEmptyTitle}} | {{shareEditionEmptySub}} |
| `pages/club/detail` | `merchantsError` | error | 商家列表加载失败 | {{merchantsError}} |
| `pages/club/detail` | `merchantsLoaded && !merchants.length` | empty | {{merchantKeyword ? '没有匹配的商家，换个关键词试试' : '还没有开放对接的商家'}} |  |
| `pages/club/detail` | `coopPoolState === 'permission'` | empty · no-permission | 暂不能看可对接的活动 | {{coopPoolError}} |
| `pages/club/detail` | `coopPoolState === 'error'` | error | 合作池加载失败 | {{coopPoolError}} |
| `pages/club/detail` | `!coopPool.length` | empty | 暂无开放承接的主题 |  |
| `pages/club/detail` | `messageState === 'error'` | error | 合作消息加载失败 |  |
| `pages/club/detail` | `else` | empty | 暂无合作邀约 |  |
| `pages/club/detail` | `inviteFeedbackState === 'error'` | error | 邀约反馈加载失败 |  |
| `pages/club/detail` | `else` | empty | 还没有发出邀约 |  |
| `pages/club/detail` | `postRefState === 'error'` | error | 游玩记录加载失败 | {{postRefErrorText}} |
| `pages/club/detail` | `postRefOptions.length === 0` | empty | 还没有可以带的记录 |  |
| `pages/club/detail` | `membersState === 'business-error'` | error | 成员列表加载失败 |  |
| `pages/club/detail` | `membersState === 'network-error'` | error | 网络连接失败 |  |
| `pages/club/detail` | `members.length === 0` | empty | 暂无成员 |  |
| `pages/club/detail` | `postHistoryState === 'ready' && !postHistoryRows.length` | empty | 暂无编辑记录 |  |
| `pages/club/edit` | `` | gate · club | (access gate: club) |  |
| `pages/club/enroll` | `` | gate · login | (access gate: login) |  |
| `pages/club/enroll` | `permissionState === 'business-error'` | error | 暂时无法确认查看权限 | {{permissionError}} |
| `pages/club/enroll` | `permissionState === 'network-error'` | error | 网络连接失败 | {{permissionError}} |
| `pages/club/enroll` | `permissionState === 'denied'` | error | {{permissionDeniedTitle}} | {{permissionDeniedSub}} |
| `pages/club/enroll` | `teamsState === 'business-error'` | error | 报名名册加载失败 |  |
| `pages/club/enroll` | `teamsState === 'network-error'` | error | 网络连接失败 |  |
| `pages/club/enroll` | `teamsState === 'ready' && teams.length === 0` | empty · empty | 还没有城市定向团 |  |
| `pages/club/enroll` | `team._detailState === 'business-error'` | error | 报名详情加载失败 |  |
| `pages/club/enroll` | `team._detailState === 'network-error'` | error | 网络连接失败 |  |
| `pages/club/enroll` | `team.tickets.length === 0` | empty | 该团暂无票种 |  |
| `pages/club/enroll` | `else` | empty | 还没有人报名 |  |
| `pages/club/event-ops` | `` | gate · login | (access gate: login) |  |
| `pages/club/event-ops` | `state === 'no-permission'` | error | 你没有活动运营的权限 | {{errorText ¦¦ '需「活动运营」或「本场核销」权限'}} |
| `pages/club/event-ops` | `state === 'network-error'` | error | 网络连接失败 | {{errorText}} |
| `pages/club/event-ops` | `state === 'error'` | error | 活动运营暂时不可用 | {{errorText}} |
| `pages/club/event-ops` | `rosterState === 'error'` | error | 名册加载失败 | {{rosterError}} |
| `pages/club/event-ops` | `activeRoster.length === 0` | empty | 这一段暂时没有成员 |  |
| `pages/club/event-ops` | `topicsLoaded && topics.length === 0 && seriesState === 'empty'` | empty | 暂无可开场的主题 |  |
| `pages/club/event-ops` | `seriesState === 'error'` | error | 系列列表加载失败 | {{seriesError}} |
| `pages/club/event-ops` | `seriesState === 'empty'` | empty | 还没有系列场次 |  |
| `pages/club/event-ops` | `occurrenceState === 'error'` | error | (component default copy) |  |
| `pages/club/event-ops` | `topics.length === 0` | empty | 暂无可开场的主题 |  |
| `pages/club/governance` | `` | gate · login | (access gate: login) |  |
| `pages/club/governance` | `state === 'no-permission'` | error | 你没有成员治理的权限 | {{errorText ¦¦ '仅主理人和管理员可用'}} |
| `pages/club/governance` | `state === 'network-error'` | error | 网络连接失败 | {{errorText}} |
| `pages/club/governance` | `state === 'error'` | error | 治理功能暂时不可用 | {{errorText}} |
| `pages/club/governance` | `state === 'empty'` | empty | 暂无可治理成员 |  |
| `pages/club/governance` | `` | empty | 当前没有可申诉的封禁 | 仅限期封禁可申诉 |
| `pages/club/governance` | `else` | empty | 暂无治理记录 |  |
| `pages/club/governance` | `else` | empty | 暂无已提交工单 |  |
| `pages/club/group-code` | `state === 'empty'` | empty · empty | 暂无可带队的场次 |  |
| `pages/club/group-code` | `` | error | 缺少路线或场次信息 |  |
| `pages/club/group-code` | `` | error | 当前账号没有出码权限 | {{errMsg ¦¦ '仅主理人、管理员或本场领队可出码'}} |
| `pages/club/join-requests` | `` | gate · club | (access gate: club) |  |
| `pages/club/join-requests` | `state === 'missing-param'` | empty · missing-param | 无法打开入会申请 |  |
| `pages/club/join-requests` | `state === 'business-error'` | error | 入会申请加载失败 | {{errorText}} |
| `pages/club/join-requests` | `state === 'network-error'` | error | 网络连接失败 | {{errorText}} |
| `pages/club/join-requests` | `requests.length === 0` | empty | 暂无待审申请 |  |
| `pages/club/notify` | `` | gate · login | (access gate: login) |  |
| `pages/club/notify` | `state === 'no-permission'` | error | 你没有发通知的权限 | {{errorText ¦¦ '需「通知成员」权限，请联系主理人'}} |
| `pages/club/notify` | `state === 'network-error'` | error | 网络连接失败 | {{errorText}} |
| `pages/club/notify` | `state === 'error'` | error | 通知工具暂时不可用 | {{errorText}} |
| `pages/club/payout-receiver` | `state === 'error'` | error | 个人收款加载失败 | {{errorText}} |
| `pages/club/payout-receiver` | `state === 'no-club'` | empty · empty | 还没有自己的俱乐部 |  |
| `pages/club/roles` | `` | gate · login | (access gate: login) |  |
| `pages/club/roles` | `state === 'missing'` | empty · missing-param | 链接已失效 |  |
| `pages/club/roles` | `state === 'no-permission'` | error | 你没有管理角色的权限 | {{errorText ¦¦ '仅主理人可分配角色'}} |
| `pages/club/roles` | `state === 'network-error'` | error | 网络连接失败 | {{errorText}} |
| `pages/club/roles` | `state === 'error'` | error | 角色管理暂时不可用 | {{errorText}} |
| `pages/club/roles` | `state === 'empty'` | empty | 暂无成员 |  |
| `pages/club/roles` | `members.length === 0` | empty | 暂无成员 |  |
| `pages/club/roles` | `members.length === 0` | empty | 暂无成员 |  |
| `pages/club/settlement` | `` | gate · login | (access gate: login) |  |
| `pages/club/settlement` | `state === 'network-error'` | error | 网络连接失败 | {{errorText}} |
| `pages/club/settlement` | `state === 'error'` | error | 结算数据暂不可用 | {{errorText}} |
| `pages/club/settlement` | `state === 'empty'` | empty · empty | 还没有平台分润记录 |  |
| `pages/club/topic-detail` | `` | gate · login | (access gate: login) |  |
| `pages/club/topic-detail` | `loadError && (missingParam ¦¦ loadRefusal)` | empty · not-found | {{loadRefusal ¦¦ '链接已失效'}} |  |
| `pages/club/topic-detail` | `loadError` | error | 活动无法打开 |  |
| `pages/club/topic-detail` | `` | error | 导演台读取失败 | {{errorText}} |
| `pages/club/topic-detail` | `` | error | 网络连接失败 | {{errorText}} |
| `pages/club/topic-detail` | `` | empty | 还没有可管理的活动局 | {{errorText ¦¦ '先从俱乐部管理区开一场，再进入导演台。'}} |
| `pages/club/topic-detail` | `directorActive && loadState === 'ready' && stations.length === 0` | empty | 开始准备后显示节点状态 |  |
| `pages/club/topic-detail` | `!leaderboard.rows.length` | empty | 暂无榜单记录 |  |
| `pages/club/topic-detail` | `settingState === 'denied'` | empty | 暂时不能查看主题设置 | {{settingErrorText}} |
| `pages/club/topic-detail` | `settingState !== 'ready'` | error | 主题设置获取失败 | {{settingErrorText}} |
| `pages/club/topic-detail` | `merchantState === 'denied'` | empty | {{merchantDeniedReason ¦¦ '商家信息获取失败'}} |  |
| `pages/club/topic-detail` | `merchantState !== 'ready'` | error | 商家信息获取失败 |  |
| `pages/club/topic-detail` | `!merchantRows.length` | empty | 这个主题还没有承接商家 |  |
| `pages/club/topic-detail` | `customerState !== 'ready'` | error | 报名名单获取失败 | {{customerErrorReason}} |
| `pages/club/topic-detail` | `!customerRows.length` | empty | {{customerFilter ? '这一档还没有人' : '还没有人报名'}} | {{customerFilter ? '换个筛选试试' : ''}} |
| `pages/club/topic-detail` | `trendState === 'error'` | error | 报名趋势获取失败 | {{trendError}} |
| `pages/club/topic-detail` | `!trendRows.length` | empty | 还没有带参与日期的报名 |  |
| `pages/club/topic-story` | `missingParam` | empty · missing-param | 链接已失效 |  |
| `pages/club/topic-story` | `loadError` | error | 剧情与玩法无法打开 | {{loadError}} |
| `pages/club/topic-story` | `else` | empty | 这一章还没有节点 |  |
| `pages/club/topic-story` | `!chapters.length` | empty · empty | 暂无路线 |  |
| `pages/club/topic-story` | `!activeChapter.plays.length` | empty · empty | 这一章还没有玩法 |  |
| `pages/club/topic-story` | `else` | empty · empty | 暂无路线 |  |
| `pages/club/workbench` | `state === 'error'` | error | 没能进入俱乐部管理 | {{errorText}} |
| `pages/coop/invite-detail` | `` | gate · login | (access gate: login) |  |
| `pages/coop/invite-detail` | `state === 'missing'` | error | 无法打开这条邀约 |  |
| `pages/coop/invite-detail` | `state === 'notfound'` | error | 这条邀约不在当前列表里了 |  |
| `pages/coop/invite-detail` | `state !== 'ready'` | error | 协作详情加载失败 | {{errorText}} |
| `pages/coop/invite-detail` | `perkState === 'error'` | error | 常备权益加载失败 | {{perkErrorText}} |
| `pages/coop/invite-detail` | `!perkTemplates.length` | empty | 还没有常备权益 | 去「承接档案」维护后再来 |
| `pages/coop/invite` | `topicsState === 'login' ¦¦ targetsState === 'login'` | empty | 登录后发起协作邀请 |  |
| `pages/coop/invite` | `receiptError` | empty · error | 原请求仍待确认 | {{receiptError}} |
| `pages/coop/invite` | `topicsState === 'permission'` | error | 当前账号不能读取主题 | {{topicsErrorText}} |
| `pages/coop/invite` | `topicsState === 'error'` | error | 主题加载失败 |  |
| `pages/coop/invite` | `else` | empty | 还没有可关联的主题 | 先发布主题后再发起协作邀请 |
| `pages/coop/invite` | `targetsState === 'permission'` | error | 当前账号无权查看合作对象 |  |
| `pages/coop/invite` | `targetsState === 'error'` | error | 合作对象加载失败 |  |
| `pages/coop/invite` | `!clubs.length` | empty | 还没有可邀请的俱乐部 |  |
| `pages/coop/invite` | `!merchants.length` | empty | 还没有可合作的商家 |  |
| `pages/coop/invite` | `supplyTopicState === 'error'` | error | 无法确认主题 | {{supplyTopicError}} |
| `pages/coop/invite` | `item.supplyState === 'error'` | error | 据点读取失败 | {{item.supplyError}} |
| `pages/coop/invite` | `item.supplyState === 'ready' && !item.supplyStations.length` | empty | 暂无已确定据点 |  |
| `pages/coop/list` | `listState === 'login'` | empty | 登录后查看协作邀请 |  |
| `pages/coop/list` | `listState === 'permission'` | error | 当前账号不能查看协作邀请 | {{listErrorText}} |
| `pages/coop/list` | `listState === 'error'` | error | 协作邀请加载失败 | {{listErrorText}} |
| `pages/coop/list` | `item.identityError` | error | 邀约信息待确认 | {{item.identityError}} |
| `pages/coop/list` | `item.status===0 && !item.decisionReady` | error | 邀请信息不完整 | 邀约信息不完整 |
| `pages/coop/list` | `chapterState === 'ready' && !chapterReceived.length && receivedApplySt` | empty · empty | 还没有收到协作邀请 |  |
| `pages/coop/list` | `listState === 'permission'` | error | 当前账号不能查看协作邀请 | {{listErrorText}} |
| `pages/coop/list` | `listState === 'error'` | error | 协作邀请加载失败 | {{listErrorText}} |
| `pages/coop/list` | `item.identityError` | error | 邀约信息待确认 | {{item.identityError}} |
| `pages/coop/list` | `chapterState === 'ready' && !chapterSent.length && sentApplyState === ` | empty · empty | 还没有发出协作邀请 |  |
| `pages/coop/nearby` | `else` | empty · empty | 附近暂无商家 |  |
| `pages/coop/nearby` | `pageState === 'guest'` | empty · no-permission | 登录后查看 |  |
| `pages/coop/nearby` | `pageState === 'permission'` | empty · permission | 当前无法查看附近商家 | {{errorText ¦¦ '需要定位权限才能找附近商家'}} |
| `pages/coop/nearby` | `pageState === 'missing-param'` | empty · missing-param | 主题信息无效 | {{errorText}} |
| `pages/coop/nearby` | `pageState === 'error'` | error | 附近商家加载失败 | {{errorText}} |
| `pages/coop/nearby` | `else` | error | 附近商家暂不可用 |  |
| `pages/coop/settlement-detail` | `source === 'ledger'` | gate · merchant | (access gate: merchant) |  |
| `pages/coop/settlement-detail` | `loadState === 'missing-param'` | empty · missing-param | 缺少结算记录信息 |  |
| `pages/coop/settlement-detail` | `loadState === 'missing-record'` | empty · empty | 结算记录不可见 |  |
| `pages/coop/settlement-detail` | `else` | error | 结算详情加载失败 | {{errorText}} |
| `pages/coop/withdraw` | `` | gate · merchant | (access gate: merchant) |  |
| `pages/coop/withdraw` | `` | empty · empty | 联系平台客服提现 | 添加客服微信，线下处理 |
| `pages/coop/withdraw/records` | `` | gate · merchant | (access gate: merchant) |  |
| `pages/coop/withdraw/records` | `state === 'redirecting'` | empty · loading | 正在打开提现记录 | 即将前往银行卡提现记录 |
| `pages/coop/withdraw/records` | `state === 'error'` | error | 页面打开失败 | {{message}} |
| `pages/merchant/aftercare/detail` | `pageState === 'error'` | error | 退款售后加载失败 | {{errorMessage}} |
| `pages/merchant/aftercare/detail` | `pageState === 'no-permission'` | error | 当前岗位没有售后查看权限 | 请联系店主开通 |
| `pages/merchant/aftercare` | `` | gate · login | (access gate: login) |  |
| `pages/merchant/aftercare` | `pageState === 'error'` | error | 售后列表加载失败 | {{errorMessage}} |
| `pages/merchant/aftercare` | `pageState === 'no-permission'` | error | 当前岗位没有售后查看权限 | 请联系店主开通 |
| `pages/merchant/aftercare` | `` | empty · empty | {{bucket === 'PENDING' ? '没有待回应售后' : (bucket === 'PROCESSING' ? '没有处理中的售后' : '还没有已完成售后')}} |  |
| `pages/merchant/aftercare` | `keyword && !groups.length` | empty · not-found | 没有找到 | 换个关键词试试 |
| `pages/merchant/apply` | `` | shell · loading | 正在确认申请资格 |  |
| `pages/merchant/apply` | `` | shell · loading | 正在检查已有申请 |  |
| `pages/merchant/apply` | `` | shell · {{bootstrapErrorKind ¦¦ 'err | {{bootstrapErrorKind === 'no-permission' ? '登录后申请商家入驻' : bootstrapErrorKind === 'network' ? '网络没连上' : '暂时无法确认申请状态'}} | {{bootstrapError}} |
| `pages/merchant/apply` | `` | shell · error | 页面状态暂时不可用 |  |
| `pages/merchant/citynode/create` | `accessState === 'login'` | empty | 登录后配置节点 |  |
| `pages/merchant/citynode/create` | `` | error | 当前岗位不能管理节点 | {{accessErrorText ¦¦ '请联系店主开通'}} |
| `pages/merchant/citynode` | `` | gate · login | (access gate: login) |  |
| `pages/merchant/citynode` | `accessState === 'error' ¦¦ (accessState === 'ready' && loadErr)` | error | {{accessState === 'error' ? '商家权限加载失败' : '节点加载失败'}} | {{accessState === 'error' ? accessErrorText : ''}} |
| `pages/merchant/citynode` | `accessState === 'no-permission'` | error | 当前岗位不能管理节点 | 请联系店主开通 |
| `pages/merchant/citynode` | `nodes.length === 0 && applications.length === 0` | empty · empty | 还没有节点 | 申请上漫游地图 |
| `pages/merchant/citynode` | `claimState === 'error' && !claimable.length` | error | 可认领节点加载失败 | {{claimError}} |
| `pages/merchant/citynode` | `claimState === 'ready' && !claimable.length` | empty | 还没有可认领的节点 |  |
| `pages/merchant/citynode` | `posterSheet.state === 'error'` | error | 打卡码加载失败 | {{posterSheet.errorText}} |
| `pages/merchant/coop-center` | `` | gate · merchant | (access gate: merchant) |  |
| `pages/merchant/coop-center` | `routesError && !routes.length` | error | 路线加载失败 | {{routesError}} |
| `pages/merchant/coop-center` | `!routes.length` | empty | 还没有开放的路线 |  |
| `pages/merchant/coop-center` | `eventsError && !events.length` | error | 官方活动加载失败 | {{eventsError}} |
| `pages/merchant/coop-center` | `!events.length` | empty | 还没有官方活动 |  |
| `pages/merchant/crm-campaigns` | `pageState === 'error'` | error | 触达记录加载失败 | {{errorMessage}} |
| `pages/merchant/crm-campaigns` | `pageState === 'no-permission'` | error | 当前岗位没有营销数据查看权限 | 请联系店主开通 |
| `pages/merchant/crm-campaigns` | `pageState === 'empty'` | empty · empty | 还没有触达记录 |  |
| `pages/merchant/customer/detail` | `` | gate · login | (access gate: login) |  |
| `pages/merchant/customer/detail` | `pageState === 'error'` | error | 客户详情加载失败 | {{errorMessage}} |
| `pages/merchant/customer/detail` | `pageState === 'missing'` | empty · empty | 找不到这位客户 |  |
| `pages/merchant/customer/detail` | `pageState === 'no-permission'` | empty · no-permission | {{notMerchant ? '当前账号不能查看客户' : '当前岗位没有客户查看权限'}} | {{notMerchant ? '' : '请联系店主开通'}} |
| `pages/merchant/customer/detail` | `` | empty · empty | 暂无参与记录 |  |
| `pages/merchant/customer` | `` | gate · login | (access gate: login) |  |
| `pages/merchant/customer` | `noPermission` | empty · no-permission | {{notMerchant ? '当前账号不能查看客户' : '当前岗位没有客户查看权限'}} | {{notMerchant ? '' : '请联系店主开通'}} |
| `pages/merchant/customer` | `error && !rows.length` | error | 客户名单加载失败 | {{error}} |
| `pages/merchant/customer` | `!rows.length` | empty · empty | {{emptyTitle}} | {{emptySub}} |
| `pages/merchant/decor/ai-npc` | `` | gate · merchant | (access gate: merchant) |  |
| `pages/merchant/decor/ai-npc` | `loadError` | error | 角色资料没能打开 | {{loadError}} |
| `pages/merchant/decor/coop-setting` | `` | gate · merchant | (access gate: merchant) |  |
| `pages/merchant/decor/coop-setting` | `` | empty · no-permission | 当前账号不能编辑承接设置 | 请切换到已审核的商家账号 |
| `pages/merchant/decor/coop-setting` | `` | error | {{loadErrorKind === 'network' ? '网络没连上' : '承接设置加载失败'}} | {{loadError}} |
| `pages/merchant/decor/coop-setting` | `` | empty · empty | 暂时无法编辑承接设置 | 完成商家入驻后可用 |
| `pages/merchant/decor/gallery` | `loadState !== 'login'` | gate · merchant | (access gate: merchant) |  |
| `pages/merchant/decor/gallery` | `loadState === 'login'` | empty | 登录后编辑门店相册 |  |
| `pages/merchant/decor/gallery` | `loadState === 'permission'` | empty · no-permission | 当前账号不能编辑门店相册 | 请切换到已审核的商家账号 |
| `pages/merchant/decor/gallery` | `loadState === 'error'` | error | {{loadErrorKind === 'network' ? '网络没连上' : '相册加载失败'}} | {{loadError}} |
| `pages/merchant/decor/gallery` | `loadState === 'empty'` | empty · empty | 暂时无法上传门店相册 | 完成商家入驻后可用 |
| `pages/merchant/decor` | `` | gate · merchant | (access gate: merchant) |  |
| `pages/merchant/decor` | `` | empty · no-permission | 暂无装修权限 | 请切换到已审核的商家账号 |
| `pages/merchant/decor` | `` | error | 品牌中心加载失败 | {{loadErrSub}} |
| `pages/merchant/decor` | `` | empty · empty | 暂时无法装修店铺 | 完成商家入驻后可用 |
| `pages/merchant/decor/perks` | `` | gate · merchant | (access gate: merchant) |  |
| `pages/merchant/decor/perks` | `loadState === 'permission'` | empty · no-permission | 暂无编辑权限 | 请切换到已审核的商家账号 |
| `pages/merchant/decor/perks` | `loadState === 'error'` | error | 权益加载失败 | {{loadError}} |
| `pages/merchant/decor/perks` | `!perks.length` | empty · empty | 还没有常备权益 |  |
| `pages/merchant/game-node` | `` | gate · merchant | (access gate: merchant) |  |
| `pages/merchant/game-node` | `viewState === 'empty'` | empty · empty | 暂无本站任务 |  |
| `pages/merchant/game-node` | `viewState === 'business-error'` | error | 暂时不能查看本站 | {{errorMessage}} |
| `pages/merchant/game-node` | `viewState === 'network-error'` | error | 本站状态加载失败 | {{errorMessage}} |
| `pages/merchant/game-node` | `!recentReceipts.length` | empty | 本次进入页面后还没有已确认操作 |  |
| `pages/merchant/index` | `consoleLogin` | empty · no-permission | 登录后查看经营台 |  |
| `pages/merchant/index` | `joinError ¦¦ hostError` | error | 项目和待办加载失败 |  |
| `pages/merchant/ledger/batch-detail` | `` | gate · merchant | (access gate: merchant) |  |
| `pages/merchant/ledger/batch-detail` | `loadState === 'missing-param'` | empty · missing-param | 缺少结算批次信息 |  |
| `pages/merchant/ledger/batch-detail` | `loadState === 'missing-record'` | empty · empty | 结算批次不可见 |  |
| `pages/merchant/ledger/batch-detail` | `else` | error | 结算详情加载失败 | {{errorText}} |
| `pages/merchant/ledger` | `` | gate · login | (access gate: login) |  |
| `pages/merchant/ledger` | `accessDenied` | empty · no-permission | 当前身份不能查看这份商家账本 |  |
| `pages/merchant/ledger` | `routeError` | shell · missing-param | 链接已失效 |  |
| `pages/merchant/ledger` | `error && !hasLoaded` | error | 核销记录加载失败 | 请稍后重试 |
| `pages/merchant/ledger` | `!loading && !error && !redemptionGroups.length` | empty · empty | 还没有记录 |  |
| `pages/merchant/ledger` | `error && !hasLoaded` | error | 近期动态加载失败 | 请稍后重试 |
| `pages/merchant/ledger` | `!loading && !error` | empty · empty | 近期暂无项目动态 |  |
| `pages/merchant/ledger` | `error && !hasLoaded` | error | 结算数据加载失败 | 请稍后重试 |
| `pages/merchant/ledger` | `!settlementLoading.entries && !settlementErrors.entries` | empty · empty | 还没有已成立的收入明细 |  |
| `pages/merchant/ledger` | `!settlementLoading.batches && !settlementErrors.batches` | empty · empty | 还没有对公结算批次 |  |
| `pages/merchant/ledger/order-detail` | `` | gate · merchant | (access gate: merchant) |  |
| `pages/merchant/ledger/order-detail` | `loadState === 'missing-param'` | empty · missing-param | 缺少核销记录信息 |  |
| `pages/merchant/ledger/order-detail` | `loadState === 'missing-record'` | empty · empty | 核销记录不可见 |  |
| `pages/merchant/ledger/order-detail` | `else` | error | 核销详情加载失败 | {{errorText}} |
| `pages/merchant/marketing/ai-insight` | `` | gate · merchant | (access gate: merchant) |  |
| `pages/merchant/marketing/ai-insight` | `error && !facts` | error | {{errorNeedsLogin ? '请先登录' : errorIsDenied ? '当前账号没有查看权限' : '店铺数据加载失败'}} | {{error}} |
| `pages/merchant/marketing/ai-insight` | `factState === 'unknown'` | shell · data | 基础数据暂未完整返回 | 数据暂缺 |
| `pages/merchant/marketing` | `guestLogin` | empty · no-permission | 登录后查看营销 |  |
| `pages/merchant/marketing` | `marketingLoaded && marketingDataState === 'empty'` | empty · empty | 还没有主题和活动 |  |
| `pages/merchant/marketing` | `else` | empty | 还没有优惠券 |  |
| `pages/merchant/payout-account` | `pageState === 'error'` | error | 收款账户加载失败 | {{errorMessage}} |
| `pages/merchant/payout-account` | `pageState === 'no-permission'` | error | 当前岗位没有财务查看权限 |  |
| `pages/merchant/payout-account` | `` | empty · empty | 收款账户暂未开放 |  |
| `pages/merchant/payout-account` | `` | empty · empty | 还没有开通收款账户 |  |
| `pages/merchant/predict` | `pageState === 'login'` | empty | 登录后查看预测 |  |
| `pages/merchant/predict` | `pageState === 'error'` | error | 待答列表加载失败 | {{errorMessage}} |
| `pages/merchant/predict` | `pageState === 'no-permission'` | empty · no-permission | 当前岗位不能公布预测答案 | {{errorMessage ¦¦ '请联系店主开通'}} |
| `pages/merchant/predict` | `pageState === 'empty'` | empty · empty | 没有等你给答案的预测 |  |
| `pages/merchant/profile` | `state === 'network-error'` | error | 资料加载失败 | {{message}} |
| `pages/merchant/profile` | `state === 'invalid'` | empty · missing-param | 链接已失效 |  |
| `pages/merchant/profile` | `else` | empty · empty | 商家不存在或未开放 |  |
| `pages/merchant/relation` | `` | gate · merchant | (access gate: merchant) |  |
| `pages/merchant/relation` | `guestLogin` | empty · no-permission | 登录后查看发现 |  |
| `pages/merchant/relation` | `feedState === 'error'` | error | 帖文加载失败 | {{feedError}} |
| `pages/merchant/relation` | `feedState === 'empty'` | empty · empty | {{feedEmptyTitle}} |  |
| `pages/merchant/relation` | `!clubError` | empty · empty | 暂无可合作俱乐部 |  |
| `pages/merchant/reviews` | `mode === 'manage'` | gate · merchant | (access gate: merchant) |  |
| `pages/merchant/reviews` | `pageState === 'missing'` | empty · missing-param | 商家信息不完整 |  |
| `pages/merchant/reviews` | `pageState === 'empty'` | empty · empty | 还没有真实到店评价 |  |
| `pages/merchant/team` | `accessState === 'login'` | empty · no-permission | {{hasIncomingInvite ? '登录后查看邀请' : '登录后查看经营团队'}} |  |
| `pages/merchant/team` | `` | error | 团队名单加载失败 | {{teamError}} |
| `pages/merchant/verify-records` | `pageState === 'error'` | error | 核销记录加载失败 | {{errorMessage}} |
| `pages/merchant/verify-records` | `pageState === 'no-permission'` | error | 当前岗位没有核销记录查看权限 | 请联系店主开通 |
| `pages/merchant/verify-records` | `` | empty · empty | {{bucket === 'VERIFIED' ? '还没有已核销记录' : '没有已撤销记录'}} |  |
| `pages/play/merchant` | `` | gate · login | (access gate: login) |  |
| `pages/play/merchant` | `notFound` | empty · missing-param | 链接已失效 |  |
| `pages/talent/list` | `feedState === 'error'` | error | {{feedLoginRequired ? '登录后查看帖文' : '动态加载失败'}} | {{feedError}} |
| `pages/talent/list` | `else` | empty | 还没有帖文 |  |
| `pages/talent/list` | `clubsError && clubsState !== 'stale-error'` | error | {{clubsLoginRequired ? '登录后查看我的俱乐部' : clubsPermissionDenied ? '当前账号无法查看俱乐部' : '俱乐部列表加载失败'}} | {{clubsErrorText}} |
| `pages/talent/list` | `!isMerchantViewer` | empty | 还没有俱乐部 |  |
| `pages/talent/list` | `else` | empty | 本城还没有俱乐部 |  |
| `pages/talent/list` | `clubMembersState === 'error'` | error | 成员加载失败 | {{clubMembersError}} |
| `pages/talent/list` | `clubMembersLoaded && clubMembersState === 'empty'` | empty | 暂无成员 |  |
| `pages/topic/merchantapply` | `` | error | 登录后填写报名 |  |
| `pages/topic/merchantapply` | `` | error | 报名信息加载失败 | {{loadError}} |
| `pages/topic/merchantapply` | `` | error | {{registrationId ? '这份报名现在不能修改' : '当前账号没有商家报名权限'}} | {{loadError ¦¦ '当前状态不能修改'}} |
| `pages/topic/merchantinfo/merchantinfo` | `` | empty · missing-param | (component default copy) |  |
| `pages/topic/merchantinfo/merchantinfo` | `projectReadAuth === 'login'` | empty · login | 登录后查看主题 |  |
| `pages/topic/merchantinfo/merchantinfo` | `else` | empty · error | 当前账号无权查看 |  |
| `pages/topic/merchantinfo/merchantinfo` | `browseLoadError` | error | 加载失败 | {{browseLoadError}} |
| `pages/topic/merchantinfo/merchantinfo` | `!info.chaptersList.length` | empty | 暂无任务向导 |  |
| `pages/topic/pricing/partner` | `invalidLink` | empty · missing-param | 合作链接已失效 |  |
| `pages/topic/pricing/partner` | `loadError` | error | 合作信息加载失败 | {{loadError}} |
| `pages/topic/pricing/partner` | `!name && !detailItems.length` | empty · missing-param | 缺少合作方信息 |  |
| `subpackageA/pages/myproject` | `` | empty · no-permission | 登录后查看我的项目 |  |
| `subpackageA/pages/myproject` | `` | empty · loading | 项目加载中 |  |
| `subpackageA/pages/myproject` | `projectAccessDenied` | empty · no-permission | 当前身份不能查看这些项目 |  |
| `subpackageA/pages/myproject` | `else` | error | 项目加载失败 | {{projectErrorMsg}} |
| `subpackageA/pages/myproject` | `` | empty · empty | {{emptyTit}} | {{emptySub}} |
| `subpackageA/pages/myproject` | `tplAccessDenied` | empty · no-permission | 当前身份不能查看这些模板 |  |
| `subpackageA/pages/myproject` | `!tplAccessDenied && !tplLoading && tplErrorMsg && !tplLoaded` | error | {{tplErrorMsg}} |  |
| `subpackageA/pages/myproject` | `tplLoaded && !tplErrorMsg && tplList.length===0 && loaded && topicTemp` | empty | 还没有模板 |  |
| `subpackageRoam/citynode-code` | `` | empty · missing-param | 这个核销码无法打开 |  |

## Appendix B. 路线模式介绍 sheet, full copy (`topic/merchantinfo`)

Intro:「选择最适合你的品牌参与方式，根据你的时间安排和社交偏好选择最适合的方式」

| | 自由探索模式 | 城市定向模式 |
|---|---|---|
| Tag | 灵活安排时间 | 固定时间出发 |
| Lead | 玩家在主题周期内自由到店打卡完成任务。 | 玩家在指定时间统一出发，按路线顺序完成任务。 |
| Bullet 1 | 玩家可以按照自己的节奏和时间安排完成探索 | 玩家按照固定的时间和路线完成探索 |
| Bullet 2 | 品牌可以自定义互动模式，构建有趣的的互动场景 | 品牌可参与统一调度，提供限时互动体验 |
| 商家收益 | 商家可选择模板并二次定义奖励机制，享受到店客流及二次消费。 | 商家可利用集中客流提升转化，享受限时活动带来的高峰流量。 |

Note: bullet 2 of 自由探索 has a doubled「的的」in the source; fix it when drawing.

## Appendix C. Every sheet, alert and confirm, by route (raw extract)

One line per overlay component in the WXML, followed by the text found inside it. Use it to check that no overlay was skipped. `cy-modal` with no attributes is the page's shared alert host, not a screen.

```
## pages/club/apply/index.wxml
  <cy-modal >
## pages/club/badges/index.wxml
  <cy-modal >
  <cy-sheet show="{{createVisible}}" title="创建勋章">
      创建 ¦ 勋章名 ¦ 例如：开荒元老 ¦ 说明（选填） ¦ 这枚勋章颁给谁、为什么 ¦ 创建结果未确认 ¦ 勋章没有创建
  <cy-sheet show="{{memberPickerVisible}}" title="颁给谁？">
      勋章：{{grantBadge.badgeName}} ¦ 主理人 ¦ 正在读取成员名单 ¦ 成员名单没加载成功 ¦ 暂无成员
  <cy-danger-confirm >
## pages/club/checkin-detail/index.wxml
  <cy-modal >
## pages/club/create/index.wxml
  <cy-modal >
## pages/club/customer-detail/index.wxml
  <cy-modal >
## pages/club/customers/index.wxml
  <cy-modal >
## pages/club/detail/index.wxml
  <cy-modal >
  <cy-post-compose show="{{composerOpen}}">
  <cy-sheet show="{{postRefPickerShow}}" title="带上一次游玩记录">
      游玩记录加载失败 ¦ 还没有可以带的记录
  <cy-sheet show="{{settingsShow}}" title="俱乐部设置">
      客户与项目 ¦ 查看客户 ¦ 报名名册 ¦ 活动运营 ¦ 项目工具 ¦ 发布主题 ¦ 开一场 ¦ AI 策划 ¦ 成员与权限 ¦ 入会申请 ¦ 邀请成员 ¦ 主理人 ¦ 管理员 ¦ Lv.{{item.levelId}} · ¦ 公开资料 ¦ · 创建俱乐部 ¦ · 加入 {{item.joinTime}} ¦ 权限 ¦ 临时封禁 ¦ 移除 ¦ 角色与权限 ¦ 成员治理 ¦ 通知成员 ¦ 俱乐部勋章 ¦ 开放设置 ¦ 俱乐部公开可见 ¦ 开放商家承接 ¦ 允许成员发帖 ¦ 入会欢迎语 ¦ 经营 ¦ 俱乐部分润 ¦ 俱乐部资料 ¦ 编辑资料 ¦ 成员列表加载失败 ¦ 网络连接失败 ¦ 打开成员主页 ¦ 暂无成员 ¦ 开关没有保存成功 ¦ 编辑入会欢迎语 ¦ 欢迎语没有保存成功
  <cy-sheet show="{{ownerPickerShow}}" title="选择要管理的俱乐部">
  <cy-sheet show="{{postEditShow}}" title="编辑动态">
      编辑记录将公开 ¦ 保存修改 ¦ 输入动态内容
  <cy-modal show="{{postEditDiscardConfirm}}" title="放弃本轮修改" confirm-text="确认放弃" cancel-text="继续编辑">
  <cy-sheet show="{{postHistoryShow}}" title="编辑历史">
      正在读取… ¦ 暂无编辑记录
  <cy-sheet show="{{aiSheetShow}}" title="AI 策划活动">
      生成中… ¦ 取消 ¦ 重试 ¦ 约 {{ aiPlan.estDurationMin === 0 ? 0 : (aiPlan.estDurationMin || '--') }} 分钟 ¦ 为什么适合:{{aiPlan.fitReason}} ¦ 路线节点 · {{aiPlan.nodes.length}} ¦ 风险提示 ¦ · {{item}} ¦ 可对接商家建议 ¦ 宣传文案 ¦ 复制 ¦ 用这个方案去发布 ¦ 发布前需补充封面和分类 ¦ 一句话描述想法，如“静安 情侣 夜间 Citywalk 90分钟” ¦ 俱乐部风格(选填) ¦ 时长(分钟) ¦ 方案没能生成
  <cy-sheet show="{{groupCodeVisible && groupCodeState === 'selecting'}}" title="选择场次">
      仅限本场次
  <cy-sheet show="{{directorActivityPickerShow}}" title="选择导演场次">
  <cy-sheet show="{{choiceSheetShow}}" title="{{choiceSheetTitle}}">
  <cy-qr-voucher wx:if="{{groupCodeVisible && groupCodeState !== 'selecting'}}" show="{{true}}" title="{{groupCodeTitle}} · 团核销码" desc="合作商家扫码登记">
  <cy-sheet show="{{welcomeShow}}" title="欢迎加入{{club.name ? '「' + club.name + '」' : '俱乐部'}}">
      主理人说 ¦ 知道了 ¦ 去看活动
  <page-container show="{{!sceneBackGuardOff && sceneCurrent && sceneCurrent.id === 'club-edit' && (sceneDirty || ">
  <cy-scene-sheet show="{{true}}" title="{{sceneCurrent.title}}">
  <cy-scene-club-edit >
  <cy-modal show="{{sceneConfirm}}" title="放弃本轮修改" confirm-text="确认放弃" cancel-text="继续编辑">
  <cy-privacy-gate show="{{privacyGateShow}}">
  <cy-danger-confirm >
  <cy-danger-confirm >
  <cy-danger-confirm >
## pages/club/edit/index.wxml
  <cy-modal >
  <cy-scene-club-edit wx:if="{{routeReady && !gateDenied}}">
  <cy-modal show="{{confirm.show}}" title="放弃本轮修改" confirm-text="确认放弃" cancel-text="继续编辑">
  <page-container show="{{!backGuardOff && (dirty || confirm.show)}}">
## pages/club/enroll/index.wxml
  <cy-modal >
## pages/club/event-ops/index.wxml
  <cy-modal >
  <cy-modal show="{{cancelConfirmShow}}" title="确认取消本场？" content="会下架本场、处理退款并终止候补。已核销的部分不退。" confirm-text="取消本场" cancel-text="再想想">
## pages/club/governance/index.wxml
  <cy-modal >
  <cy-sheet show="{{memberPickerVisible}}" title="选择成员">
  <cy-sheet show="{{durationPickerVisible}}" title="选择期限">
## pages/club/group-code/index.wxml
  <cy-modal >
  <cy-club-game-code-sheet show="{{true}}" title="活动核验团码">
  <cy-privacy-gate show="{{privacyGateShow}}">
## pages/club/join-requests/index.wxml
  <cy-modal >
## pages/club/notify/index.wxml
  <cy-modal >
## pages/club/payout-receiver/index.wxml
  <cy-modal >
  <cy-danger-confirm >
## pages/club/roles/index.wxml
  <cy-modal >
  <cy-sheet show="{{memberPickerVisible}}" title="选择成员">
      暂无成员
  <cy-sheet show="{{rolePickerVisible}}" title="选择角色">
  <cy-danger-confirm >
## pages/club/settlement/index.wxml
  <cy-modal >
## pages/club/topic-detail/index.wxml
  <cy-modal >
  <cy-scene-sheet show="{{genericOpsSheet}}" title="{{genericOpsTitle}}">
      时间为北京时间 ¦ 录入队伍答案，提交后核验 ¦ 取消 ¦ 确认并提交 ¦ 取消运营操作 ¦ 确认并提交运营操作
  <cy-club-director-ready wx:if="{{statusKey === 'preparing'}}" title="准备总览" primary-text="">
  <cy-club-director-row-list >
  <cy-club-director-recap wx:if="{{statusKey === 'ended' && recap}}" title="活动复盘">
  <cy-club-director-end-confirm show="{{directorEndConfirmShow}}" title="结束这场活动？" content="结束后不能再核销、不能再改队伍与角色；已产生的结算事实会保留。此操作不可撤销。" cancel-text="再想想" confirm-text="结束活动">
  <cy-club-director-chapter-sheet show="{{unlockSheetVisible}}" title="{{unlockButtonText}}" confirm-text="放行">
      现场原因（选填） ¦ 写明放行原因
  <cy-club-director-team-sheet show="{{teamSheetVisible}}" title="队伍进度">
  <cy-club-director-role-sheet show="{{roleSheetVisible}}" title="{{ roleDraft.memberName ? '角色分配 · ' + roleDraft.memberName : '角色分配' }}" confirm-text="确认分配">
      接管给 ¦ 接管原因 ¦ * ¦ 取消接管 ¦ 确认接管 ¦ 写明为什么要接管，会进审计记录
  <cy-club-director-broadcast-sheet show="{{broadcastSheetVisible}}" title="定向广播" content="{{broadcastDraft.content}}" confirm-text="{{broadcastSendText}}">
  <cy-club-director-incident-sheet show="{{incidentSheetVisible}}" title="现场事件" confirm-text="确认处理">
  <cy-scene-sheet show="{{settingSheetVisible}}" title="更多">
      剧情与玩法 ¦ 结束活动 ¦ 核销记录 ¦ 场次管理 ¦ 退出与暂停规则 ¦ 编辑主题内容 ¦ 确认终价 ¦ 承接审核 ¦ 开放商家对接 ¦ 开放商家承接 ¦ 在俱乐部页的展示 ¦ 置顶在俱乐部主页 ¦ 只对成员可见 ¦ 结束主题 ¦ 未核销票原价退回 ¦ 已核销订单转平台处理 ¦ 暂时不能查看主题设置 ¦ 主题设置获取失败 ¦ 承接审核与项目协作
  <cy-club-director-row-list >
  <cy-scene-sheet show="{{merchantSheetVisible}}" title="商家">
      商家接受后显示联系方式 ¦ 商家信息获取失败 ¦ 这个主题还没有承接商家
  <cy-scene-sheet show="{{customerSheetVisible}}" title="报名参与者">
      定向广播 ¦ 按参与日期 · 报名人数 ¦ 报名名单获取失败 ¦ 报名趋势获取失败 ¦ 还没有带参与日期的报名
  <cy-club-topic-end-confirm show="{{endConfirmVisible}}">
  <cy-scene-sheet show="{{opsTimeSheetVisible}}" title="修改集合时间">
      集合日期 ¦ 集合时间 ¦ 退款截止为集合前 24 小时 ¦ 取消 ¦ 取消修改集合时间 ¦ 保存集合时间
  <cy-result-sheet show="{{resultSheet.show}}" kind="{{resultSheet.kind}}" title="{{resultSheet.title}}" sub="{{resultSheet.sub}}">
  <cy-scene-sheet show="{{rulesSheetVisible}}" title="退出与暂停规则">
  <cy-scene-sheet show="{{sessionPickVisible}}" title="选择场次">
  <cy-club-director-chapter-sheet show="{{planFallbackSheet}}" title="默认结局收尾" confirm-text="确认收尾">
      收尾原因 ¦ 查看上次操作结果 ¦ 必填的默认结局收尾原因 ¦ 说明本场无法继续执行方案的原因 ¦ 确认原收尾请求的结果
## pages/club/topic-story/index.wxml
  <cy-modal >
  <cy-scene-sheet show="{{answerVisible}}" title="{{answerTitle}}">
      正在取答案… ¦ 题面 ¦ 答案 ¦ 提示 ¦ 玩家答错时的反馈 ¦ 答案只给主办方和这一站的接待方看，用于现场判定玩家能否通过。玩家端看不到这一段。 ¦ 答案没取到
## pages/club/workbench/index.wxml
  <cy-modal >
## pages/coop/finance/index.wxml
  <cy-modal >
## pages/coop/invite-detail/index.wxml
  <cy-modal >
  <cy-sheet show="{{showPerkPick}}" title="申报本次供给">
      成本 {{money.amount(item.unitCost)}}{{item.quota ? ' · 配额 ' + item.quota : ''}} ¦ 常备权益加载失败 ¦ 还没有常备权益 ¦ 确认申报本次供给
  <cy-option-sheet show="{{reviewSheetShow}}" title="这次合作打几分" confirm-text="下一步">
## pages/coop/invite/index.wxml
  <cy-modal >
  <cy-sheet show="{{inviteModal.show}}" title="编辑邀约语">
      邀请对象 · 已锁定 ¦ 已锁定 ¦ 拟议条款 · 对方接受并成单后锁定 ¦ 核销据点：{{item.supplyStationName}} ¦ 协作邀请 ¦ 对方会在「收到的」中确认本次协作。 ¦ 邀请语 ¦ 主题条款没配好？去编辑主题(票价/内容) ¦ 写下想对对方说的话 ¦ 去编辑主题的票价与内容 ¦ 确认发送协作邀约
  <cy-result-sheet show="{{resultSheet.show}}" kind="{{resultSheet.kind}}" title="{{resultSheet.title}}" sub="{{resultSheet.sub}}">
## pages/coop/list/index.wxml
  <cy-modal >
## pages/coop/nearby/index.wxml
  <cy-modal >
  <cy-option-sheet show="{{replacementSheetShow}}" title="选择补位操作">
  <cy-privacy-gate show="{{privacyGateShow}}">
## pages/coop/settlement-detail/index.wxml
  <cy-modal >
## pages/coop/withdraw/index.wxml
  <cy-modal >
## pages/coop/withdraw/records/index.wxml
  <cy-modal >
## pages/merchant/aftercare/detail/index.wxml
  <cy-modal >
  <cy-sheet show="{{respondOpen}}">
      * ¦ 审核凭证{{decision === 'EVIDENCE' ? '' : '（选填）'}} ¦ 凭证已上传 ¦ 移除 ¦ 选择图片并上传 ¦ 处理意见 ¦ 说明 ¦ 审核凭证 ¦ 继续 ¦ 写下可供平台审核的订单事实 ¦ 预览已上传凭证 ¦ 移除凭证 ¦ 选择图片并上传凭证 ¦ 售后处理未提交
## pages/merchant/aftercare/index.wxml
  <cy-modal >
## pages/merchant/apply/index.wxml
  <cy-modal >
  <cy-merchant-claim-sheet show="{{claimShow}}">
  <cy-tag-sheet show="{{industrySheet.show}}" title="行业类型" confirm-text="确定">
  <cy-sheet show="{{hoursPickerShow}}" title="设置经营时间">
      经营日 ¦ * ¦ 营业时段 ¦ 开始时间 ¦ 至 ¦ 结束时间 ¦ 完成 ¦ 开始营业时间 ¦ 结束营业时间
  <cy-privacy-gate show="{{privacyGateShow}}">
## pages/merchant/citynode/create/index.wxml
  <cy-modal >
  <cy-modal show="{{showLeaveConfirm}}" title="放弃未提交草稿吗" content="玩法或店址还没有提交，直接离开会丢失本页草稿。" confirm-text="离开" cancel-text="继续编辑">
  <cy-privacy-gate show="{{privacyGateShow}}">
## pages/merchant/citynode/index.wxml
  <cy-modal >
  <cy-info-pop title="节点是什么" content="节点是门店在漫游地图上的打卡点，审核通过后玩家才能看到。">
  <cy-sheet show="{{showClaim}}" title="认领平台节点">
      可认领节点加载失败 ¦ 可认领节点没有更新 ¦ 还没有可认领的节点 ¦ 认领申请未提交
  <cy-sheet show="{{posterSheet.show}}" title="到店打卡码">
      长按保存后张贴，长期有效 ¦ 打卡码加载失败
  <cy-privacy-gate show="{{privacyGateShow}}">
## pages/merchant/coop-center/index.wxml
  <cy-modal >
## pages/merchant/crm-campaigns/index.wxml
  <cy-modal >
  <cy-sheet show="{{detailOpen}}" title="{{detail ? detail.titleText : '触达明细'}}">
      名单人数 ¦ 已送达 ¦ 未同意 ¦ 频控跳过 ¦ 未送达 ¦ 名单不含联系方式 ¦ 这次触达没有逐人结果 ¦ 触达明细加载失败
## pages/merchant/customer/detail/index.wxml
  <cy-modal >
  <cy-sheet show="{{editorOpen}}" title="编辑标签与备注">
      客户标签 ¦ × ¦ 还没有店内标签 ¦ 客户备注 ¦ 正在更正备注 #{{correctsNoteId}}；系统追加新记录，不改原文。 ¦ 取消更正 ¦ 跟进与触达 ¦ 更正 ¦ 保存 ¦ 输入新标签 ¦ 添加标签 ¦ 标签未添加 ¦ 记录偏好、承诺事项或下次联系计划 ¦ 备注未保存 ¦ 追加更正 ¦ 隐藏这条跟进
## pages/merchant/customer/index.wxml
  <cy-modal >
  <cy-sheet show="{{toolsOpen}}">
      触达记录 ¦ 导出脱敏客户资料 ¦ 查看触达记录
  <cy-sheet show="{{filterOpen}}">
      取消 ¦ 筛选客户 ¦ 重置 ¦ 我的分群 ¦ 客户类型 ¦ 客户来源 ¦ 全部 ¦ 主题 ¦ 活动 ¦ 来源时间 ¦ 至 ¦ 客户标签 ¦ 全部标签 ¦ 0 ? '查看 ' + castCount + ' 位客户' : '查看结果'}} ¦ 重置筛选 ¦ 保存分群暂未更新 ¦ 选择开始日期 ¦ 选择结束日期 ¦ 存为分群
  <cy-result-sheet show="{{resultSheet.show}}" kind="{{resultSheet.kind}}" title="{{resultSheet.title}}" sub="{{resultSheet.sub}}">
## pages/merchant/decor/ai-npc/index.wxml
  <cy-modal >
  <cy-sheet show="{{introVisible}}">
      跳过 ¦ . ¦ 上一步
  <cy-sheet show="{{presetVisible}}" title="选现成的">
      使用这个形象
  <cy-sheet show="{{field !== null && !discardVisible}}" title="{{field.label}}">
      保存 ¦ 暂未完成
  <cy-sheet show="{{personaSheet}}">
      性格设定 ¦ 暂未完成
  <cy-sheet show="{{discardVisible}}" title="还没有保存">
      离开后，本次修改不会保留。 ¦ 放弃修改 ¦ 继续编辑
  <cy-sheet show="{{voiceVisible}}" title="{{!voiceFile && voiceStatus === 1 ? '声音生成中' : !voiceFile && voiceStatus === 2 ? '声音可用' : '">
      让店铺角色用你的声音说话 ¦ 声音正在生成，可以先返回继续装修店铺。 ¦ 刷新状态 ¦ 角色的声音已准备好。 ¦ 重新录音 ¦ 清除声音 ¦ 声音生成失败，请重新录一段清晰的声音。 ¦ 录制声音 ¦ 正在保存… ¦ 确认这句 ¦ 三句已录好 ¦ 确认并生成声音 ¦ 原结果未知，仍可能完成并占用额度。不会自动重发。 ¦ 查询原请求 ¦ 确认后另起独立请求 ¦ 原声音请求 · {{dl.voice(item.state)}} ¦ 查看原结果 ¦ 去设置开启麦克风 ¦ 查询生成状态 ¦ 三句录音进度 ¦ 暂未完成
  <cy-privacy-gate show="{{privacyGateShow}}">
## pages/merchant/decor/coop-setting/index.wxml
  <cy-modal >
  <cy-sheet show="{{editor !== null && !discardVisible}}" title="{{editor ? editor.label : ''}}">
      完成 ¦ 合作诉求
  <cy-sheet show="{{discardVisible}}" title="还没有保存">
      放弃修改 ¦ 继续编辑
## pages/merchant/decor/gallery/index.wxml
  <cy-modal >
  <cy-sheet show="{{discardVisible}}" title="还没有保存">
      离开后，本次相册修改不会保留。 ¦ 放弃修改 ¦ 继续编辑
## pages/merchant/decor/index.wxml
  <cy-modal >
  <cy-sheet show="{{fieldSheet.show && !discardVisible}}" title="{{fieldSheet.label}}">
      暂未完成
  <cy-tag-sheet show="{{chipSheet.show}}" title="{{chipSheet.title}}" confirm-text="{{saveError ? '重试保存' : '保存'}}">
  <cy-sheet show="{{customTagVisible}}" title="自定义标签">
      添加 ¦ 填写标签，最多 16 字
  <cy-sheet show="{{discardVisible}}" title="还没有保存">
      离开后，本次修改不会保留。 ¦ 放弃修改 ¦ 继续编辑
  <cy-privacy-gate show="{{privacyGateShow}}">
  <page-container show="{{!backGuardOff && !imagePicking && (imageEditor || fieldSheet.show || discardVisible || c">
## pages/merchant/decor/perks/index.wxml
  <cy-modal >
  <cy-danger-confirm >
  <cy-sheet show="{{discardVisible}}" title="还没有保存">
      放弃修改 ¦ 继续编辑
  <page-container show="{{!backGuardOff && (formVisible || discardVisible)}}">
## pages/merchant/game-node/index.wxml
  <cy-modal >
  <cy-sheet show="{{declineSheetShow}}" title="拒绝节点邀请">
      拒绝原因将告知主办方 ¦ 确认拒绝
  <cy-sheet show="{{pauseSheetShow}}" title="暂停接待">
      暂停后玩家立即不可预约本站 ¦ 预计恢复 ¦ * ¦ 备用方案（选填） ¦ 玩家将看到：{{pauseDraft.playerMessage}} ¦ 当前没有已审核的备用方案，可以直接暂停；玩家会看到本站暂停和预计恢复时间。 ¦ 选了备用方案，玩家会被引导到那一站；不选则只显示本站暂停。 ¦ 确认暂停
  <cy-sheet show="{{verifySheetShow}}" title="核验游戏提交">
      核验编号 ¦ * ¦ 通过 ¦ 驳回 ¦ 提交核验结论 ¦ 输入玩家提交页显示的正整数编号
  <cy-privacy-gate show="{{privacyGateShow}}">
  <cy-qr-voucher wx:if="{{checkinVisible}}" show="{{true}}" title="本站打卡码" desc="一次有效，扫后自动更新">
## pages/merchant/index/index.wxml
  <cy-modal >
  <cy-scene-sheet show="{{true}}" title="{{sceneCurrent.title}}">
      协作邀请 ¦ 退款售后 ¦ 核销记录 ¦ 收款账户 ¦ 管理优惠券 ¦ 品牌资料 ¦ 打开协作邀请 ¦ 打开退款售后 ¦ 打开核销记录 ¦ 打开收款账户 ¦ 打开品牌资料
  <cy-scene-sheet show="{{true}}" title="{{sceneCurrent.title}}">
      选择本次核销的章节
  <cy-scene-sheet show="{{true}}" title="{{sceneCurrent.title}}">
      选择本次核销的节点
  <cy-result-sheet show="{{true}}" kind="{{verificationResult.kind}}" title="{{verificationResult.title}}" sub="{{verificationResult.sub}}" primary-text="{{verificationResult.review ? '查看核销记录' : (merchantAccess.canVerify ? '继续扫码' : '完成')}}" secondary-text="{{merchantAccess.canVerify || verificationResult.review ? '完成' : ''}}">
  <cy-scene-sheet show="{{true}}" title="{{sceneCurrent.title}}">
  <cy-scene-sheet show="{{true}}" title="{{sceneCurrent.title}}">
  <cy-scene-sheet show="{{true}}" title="{{sceneCurrent.title}}">
  <cy-modal show="{{sceneConfirm.show}}" title="放弃本轮修改" confirm-text="确认放弃" cancel-text="继续编辑">
  <cy-privacy-gate show="{{privacyGateShow}}">
## pages/merchant/ledger/batch-detail/index.wxml
  <cy-modal >
## pages/merchant/ledger/index.wxml
  <cy-modal >
## pages/merchant/ledger/order-detail/index.wxml
  <cy-modal >
## pages/merchant/marketing/ai-insight/index.wxml
  <cy-modal >
## pages/merchant/marketing/index.wxml
  <cy-modal >
## pages/merchant/predict/index.wxml
  <cy-modal >
  <cy-modal show="{{confirm.show}}" title="公布答案「{{confirm.label}}」？" content="{{confirm.content}}" confirm-text="公布并结算" cancel-text="再想想">
## pages/merchant/profile/index.wxml
  <cy-modal >
## pages/merchant/relation/index.wxml
  <cy-modal >
  <cy-post-compose show="{{composerOpen}}">
## pages/merchant/reviews/index.wxml
  <cy-modal >
  <cy-danger-confirm >
## pages/merchant/team/index.wxml
  <cy-modal >
  <cy-scene-sheet show="{{roleSheet.show}}" title="{{roleSheet.mode === 'operator' ? '调整岗位' : '选择邀请岗位'}}">
      当前 ¦ 移除
  <cy-danger-confirm >
## pages/merchant/verify-records/index.wxml
  <cy-modal >
## pages/play/merchant/index.wxml
  <cy-modal >
  <cy-privacy-gate show="{{privacyGateShow}}">
  <cy-safety-rating-sheet show="{{safetyRatingShow}}">
## pages/talent/list/index.wxml
  <cy-modal >
  <cy-sheet show="{{clubManageShow}}" title="{{managingClub.name || '成员管理'}}">
      成员管理 ¦ 主理人 ¦ 加入时间 {{item.joinTime || '—'}} ¦ 移除 ¦ 成员加载失败 ¦ 正在更新成员 ¦ 暂无成员
## pages/topic/merchantapply/index.wxml
  <cy-modal >
  <cy-sheet show="{{true}}">
      承接标的 ¦ 你的门店 ¦ 承接地点 ¦ * ¦ 承接说明 ¦ 承接图片 ¦ 上传现场照片 ¦ 5:3 横图，1–9 张 ¦ 添加照片 ¦ 可配合的时间 ¦ 可配合日期 ¦ 每日可接待时段 ¦ 选填 ¦ 限定人数 ¦ 主理人确认后生效，预计 1–3 天 ¦ 保存修改 ¦ 提交报名 ¦ 查看承接进度 ¦ 返回商家首页 ¦ 登录后填写报名 ¦ 报名信息加载失败 ¦ 点击选择承接地点 ¦ 填写可用空间、接待安全条件、拍摄许可、现场可配置物料 ¦ 添加场地照片 ¦ 选择可配合日期区间 ¦ 不填则不限 ¦ 报名暂未保存
  <cy-date-range-sheet show="{{availabilityPickerShow}}" title="选择可配合日期">
  <cy-sheet show="{{timePicker.show}}" title="可配合时间">
      开始时间 ¦ 至 ¦ 结束时间 ¦ 完成
## pages/topic/merchantinfo/merchantinfo.wxml
  <cy-modal >
  <cy-sheet show="{{topicShow && selectedMode !== 2}}" title="选择承接节点">
      已选：{{selectedModeText}}{{selectedMode === 2 && selectedChapterText ? '，' + selectedChapterText : ''}}{{selectedMode === 1 && selectedNodeText ? '，' + selectedNodeText : ''}} ¦ 承接方式 ¦ 选择节点 ¦ 报名
  <cy-sheet show="{{davidShow}}" title="路线模式介绍">
      选择最适合你的品牌参与方式，根据你的时间安排和社交偏好选择最适合的方式 ¦ 自由探索模式 ¦ 灵活安排时间 ¦ 玩家在主题周期内自由到店打卡完成任务。 ¦ 玩家可以按照自己的节奏和时间安排完成探索 ¦ 品牌可以自定义互动模式，构建有趣的的互动场景 ¦ 商家收益 ¦ 商家可选择模板并二次定义奖励机制，享受到店客流及二次消费。 ¦ 城市定向模式 ¦ 固定时间出发 ¦ 玩家在指定时间统一出发，按路线顺序完成任务。 ¦ 玩家按照固定的时间和路线完成探索 ¦ 品牌可参与统一调度，提供限时互动体验 ¦ 商家可利用集中客流提升转化，享受限时活动带来的高峰流量。
  <cy-chapter-target-picker show="{{topicShow && selectedMode === 2}}">
  <cy-option-sheet show="{{stationSheetShow}}" title="{{stationSheetTitle}}">
  <cy-qr-voucher wx:if="{{checkinVisible}}" show="{{true}}" title="{{checkinHost ? '本主题二维码' : '本站打卡码'}}" desc="{{checkinHost ? '玩家用微信扫一扫，直接进入这个主题' : '长期有效，可保存后张贴'}}" secondary-text="{{checkinQrState === 'ready' && checkinQrUrl ? '保存到相册' : ''}}">
  <cy-sheet show="{{profitSheet.show}}" title="分润明细">
      档位按章节在开售时定好，不能改 ¦ 正在读取… ¦ 这个主题还没有分润记录，开售并核销后会出现在这里 ¦ 本主题已入账 ¦ 待结算 ¦ 已售 ¦ 每卖出 1 份 ¦ 怎么分 ¦ 各方到手 ¦ 结算 ¦ 全部收益 ¦ 分润明细没读到 ¦ 查看全部收益
  <cy-privacy-gate show="{{privacyGateShow}}">
  <cy-danger-confirm >
## pages/topic/pricing/partner/index.wxml
  <cy-modal >
## subpackageA/pages/myproject/index.wxml
  <cy-modal >
  <cy-sheet show="{{opsSheet.show}}">
      编辑 ¦ 收到的申请 ¦ 审核记录 ¦ 另存为模板 ¦ 删除
  <cy-sheet show="{{auditSheet.show}}" title="审核记录">
      加载中 ¦ 重试 ¦ 暂无记录 ¦ 申诉 ¦ 移除附件 {{index + 1}} ¦ 添加申诉图片 ¦ 最多6张，须本人上传并通过内容安全审核；以平台校验为准 ¦ 读取原申诉结果 ¦ 每条内容可申诉一次
  <cy-danger-confirm >
  <cy-danger-confirm >
  <cy-danger-confirm >
  <cy-danger-confirm >
  <cy-danger-confirm >
## subpackageRoam/citynode-code/index.wxml
  <cy-modal >
  <cy-qr-voucher show="{{true}}" title="{{name}}" desc="出示给商家扫码领券">
```
