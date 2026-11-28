# Chengyin app requirements, extracted from the owner's planning documents (2026-07 to 2026-09)

Source: local planning folders (城瘾文档, 城瘾vault). Only requirement lines are kept: checklist items, decisions and table rows naming pages, endpoints or features. Phone numbers, emails, keys and local paths are redacted. Older docs describe the earlier Flutter app; the requirement is the feature, not the old file path.


## Source: 城瘾文档/App对齐小程序_交接_20260916.md

### 1. 硬规则(违反任一条都会出事)
| R7 | 外观一律 **iOS 27 原生**(规则手册 `docs/ios27-design-language.md` + `AGENTS.md`,已在 main);对齐对象是**结构**:页面/入口/字段/文案/接口/状态/业务规则 1:1 跟小程序。地图(D7)、消息页(D9)是 App 独有体验,不追小程序外观 | 决策 D7/D8/D9/D10 |
### 2. 基线读数([number] 记录 / **[number] 本机复跑**)
| **manifest 自洽性(新)** | 113 条落点的 `source` 文件 + `marker` 类名**全部存在**(唯一例外 `pages/crop/index`,是文档写明的平台例外) |
| 小程序产品代码口径端点 | 424 | 424 |
| App 够不着 | 50 | **35** |
| 真待接(扣掉已登记等价) | 46 | **31** |
| App 侧声明了没人调 | 38 | **27** |
### 3. 已完成(已合入 App main)
| #43 | 结构对照台 `tool/visual_parity/`:静态解析小程序 wxml 区块/按钮/状态分支/文案/接口 ↔ App 页面,**不截图、不用 automator**(已核合入版 `build_review.py` 与 README),外观差异默认 accepted | Task 0.3(按 R1/D8 改造) |
| #45 | 重写 `AGENTS.md` + `docs/ios27-design-language.md`(规则来源、降级表、35 行对照表、共用层 30 组件分批 P0–P4、原生桥 B1–B4),已按 D10 更新 | Task 2.1 扩展 |
| #46 | 定位 + `MKDirections` 路线规划 + App 内分步导航 + 一键交给 Apple 地图 | Task 1.5 / D7 |
#### 4.2 没开 PR 的半成品分支
| `liboyang42-cpu/p4-club-crm` | 同上 | 俱乐部客户列表/详情、签到详情、结算页 + manifest 登记。`/api/club/settlement/withdraw` **故意未封装**(见 R10) | ⚠️ | 线 6(W2) |
#### 5.1 页面(小程序 130 页,24 页 App 无落点)
| `pages/club/topic-detail/index` | **无人** | 线 16(W6) |
| `pages/club/topic-story/index` | **无人** | 线 16(W6) |
| `pages/merchant/predict/index` | **无人** | 线 9(W3) |
| `pages/coop/invite-detail/index` | **无人** | 线 9(W3) |
| `pages/club/customers/index` · `customer-detail` · `checkin-detail` · `settlement` | p4-club-crm ⚠️ | 线 6(W2) |
| `subpackageRoam/nearby/index` · `citystamp` | p4-roam-social ⚠️ | 线 3(W1) |
| `pages/team/detail/index` · `team/join` | parity/team 已有路由 `/team/:teamId` `/team/join`,**漏登记 manifest** | 线 8(W3) |
| `pages/play/circle/index` | #30 → #48 | 线 5(W2) |
| `pages/club/event-ops` · `governance` · `notify` · `roles` | #30 | 线 14(W5) |
| `pages/merchant/aftercare` · `aftercare/detail` · `reviews` · `game-node` · `customer/detail` · `team` | #30 **与** figma-confirmed 重复 | 线 4 去重(W2) |
| `pages/merchant/decor/ai-npc/index`(小程序新增) | #30 | 线 4(W2) |
#### 5.2 接口:没人做的 52 条(按域)
| club/event-ops | 13 | `attendance/correct` `cancel` `occurrence/status` `roster` `series/{create,detail,list,occurrences,update-future}` `topics` `waitlist/{cancel,join,status}` | 4-B(#30 的 event-ops 页只有壳) |
| merchant/chapter-node | 7 | `live-checkin-code` `poster-code` `npc/{detail,save}` `npc/voice/{enroll,reset,status}` | 4-C |
| team(**新功能**) | 7 | `apply` `applications` `handle` `join-mode` `my-applications` `nearby` `withdraw` | 4-D:9-15「地图组队 P 方案」,不是搬运 |
| club/topic-setting | 3 | `detail` `save` `end` | 4-B |
| club/open-settings | 3 | `member-post` `merchant-coop` `public-visible` | 4-B |
| merchant/crm | 3 | `exports` `exports/{taskId}/status` `exports/{taskId}/download` | 4-C |
| topic/chapter | 2 | `finish` `recruit` | 4-B |
| merchant/predict | 2 | `inbox` `settle` | 4-C |
| merchant/npc | 2 | `profile` `voice/status` | 4-C |
| coop/pool | 2 | `mine` `received` | 4-C |
| 其余各 1 | 10 | `club/settlement/withdraw`(**按 R10 不接**:提现改弹窗,登记为 documented equivalent)· `club/crm/topic-customers` · `club/event-notification/audience-counts` · `club/recruit/overview` · `club/topic-node-answer` · `game/session/recap/export` · `play/scan-entry` · `roam/session` | 4-B / 4-C |
#### 5.5 非页面类未完成(按总规划 Task)
| D9 消息页 iOS「信息」式 + 左右滑动(D10⑤) | 未开始;`chat-complete-0909` 可参考 |
| 4.1 玩法互动组件 ~30 种(playkit-*) | 未开始;D5 先出 iOS 交互稿 |
#### 6.3 线卡(分支 / 写集 / 依赖 / 模型 / 验收)
| 1 | **#47 资金改造** | `parity/account-money`(PR 已有) | `feature/account/**` `feature/money/**` | — | Opus medium | 先 rebase main 去掉 #44 原始提交(`577301f`、`f8c307e`);删提现风险确认闭环与银行卡跳转;`grep -rn "withdraw\|提现" lib` 全部改 R10 弹窗(号码常量,见 §9 待拍板 1);保留默认地址、资产明细;测试:点提现**不发任何提现请求** · 弹窗显示号码 · 「复制」写剪贴板;PR 描述写明依据 R10 |
| 2 | **p1-apple-maps 验收** | `liboyang42-cpu/p1-apple-maps` | `core/map/**` `ios/**` `pubspec` `Podfile` `android/**` | — | Opus high | 与 #46 冲突:保留 #46 的 directions/route_guidance 与 map_page 路线入口,**两者共存**;`map_platform_gate_test` 绿;`release_build_flags_test` 负控(临时加回 `amap_map` 必须红);`tool/verify_ios_arm64_simulator.sh` 输出 `IOS_ARM64_SIMULATOR_OK`;`xcrun simctl` 截图 `/map` `/roam` `/play/<id>` `/topi
| 3 | **p4-roam-social 收口** | `liboyang42-cpu/p4-roam-social` | `feature/roam/**` + roam api | — | DeepSeek | ⚠️ 未跑过 analyze;**先按 R8 审在途改动性质**;漫游约伴(nearby 的局)+ 城市纪念章 citystamp + 5 组测试;rebase → analyze + 相关测试 → 开 PR |
| 4 | **parity/merchant-ops 新建** | 新分支(从最新 main) | `feature/merchant/**` | — | DeepSeek | 售后 / 售后详情 / 口碑 / 客户详情 / 经营团队 / 游戏节点 / ai-npc **7 页**;**#30 与 figma-confirmed 二选一**(按接口覆盖数与测试完整度),另一份不带入;来源 `git cherry-pick` #30 对应 commit + `git checkout <分支> -- <路径>` |
| 5 | **parity/play-advanced 收口** | `parity/play-advanced` | `feature/play/**` | — | DeepSeek | 从 `feature/figma-confirmed-0909` 补入 `play/advanced/*` 等 **7 条独有接口**的调用链(`play/advanced/{action,leaderboard,start,state}` · `play/leaderboard` · `play/os/{topicId}` · `play/tag/{tagId}/revoke`)→ 测试 → 开 PR |
| 6 | **p4-club-crm 收口** | `liboyang42-cpu/p4-club-crm` | `feature/club/**` | — | Opus medium(资金) | 客户列表/详情、签到详情、结算页;结算页按 R10:**照常展示应得金额/结算摘要(`club/settlement/summary`),「提现」按钮 = R10 弹窗**,`/api/club/settlement/withdraw` **故意不封装**、不跳银行卡表单 |
| 7 | **B1 原生 sheet 收尾** | `liboyang42-cpu/ios27-b1-native-sheet` | `core/**` `ios/**` | 承 p1(同为 ios 写集) | Opus | 删 `lib/b1_harness_main.dart`(**非产品代码,合前必删**);Dart 回退分支单测;iOS 26+ 模拟器截图证明真玻璃/grabber/medium-large/键盘避让;关闭 10 次 deinit 计数 |
| 8 | **parity/team 收口** | `parity/team` | `feature/team/**` | — | DeepSeek | rebase → `flutter analyze` + `test/feature/team/**` → 补 manifest 登记 `team/detail`→`/team/:teamId`、`team/join`→`/team/join`(**路由已在分支里,只是漏登记**)→ 开 PR;与 `fix/activity-waitlist-review-0827` 的候补实现**比较取一**,写进 PR 描述 |
| 9 | **4-C 商家零散** | 新分支 | `feature/merchant/**` `coop/**` `game/**` | 承 #4 | DeepSeek | `merchant/predict` `coop/invite-detail` 两页 + chapter-node 7 + crm/exports 3 + predict 2 + npc 2 + coop/pool 2 + game/session/recap/export + play/scan-entry + roam/session |
| 10 | **§5.4 广场回归核查** | 只读,不开分支 | — | — | DeepSeek | 结论三选一:**等价替代 / gate 关时丢功能 / 无法判定**;不得停在「待核」 |
| 11 | **4-D 地图组队(新功能)** | 新分支 | `feature/team/**` | 承 #8 | DeepSeek | team apply **7 条**,按 9-15「地图组队 P 方案」:公开队伍可申请;满员/进行中/解散/审核中不显示;申请 24h 或活动结束失效;被拒不能再申;Figma `txQoyVyK 590:1014`。**先读小程序与后端 master 实现,不是 1:1 搬旧页** |
| 12 | **消息页 D9** | 新分支 | `feature/im/**` | — | Opus medium | 手册 §3.9 与 IM2:iOS「信息」式会话列表 · 会话行左右滑动(置顶/已读/删除,删除走 `cyConfirm`)· 长按菜单一致;`feature/app-chat-complete-0909` **只作参考**,逐文件判断取舍;**允许比小程序更丰富**(用户 09-17,见 §9) |
| 13 | **主题编辑器浅色** | `liboyang42-cpu/p2-topic-editor-light`(空分支) | `feature/**topic*` | — | Opus medium | 决策 D10⑥ |
| 14 | **parity/club-ops 新建** | 新分支 | `feature/club/**` | 承 #6 | DeepSeek | `club/event-ops` `governance` `notify` `roles` **4 页**(来自 #30);#30 的 event-ops 只有壳,壳不算完成 |
| 15 | **小分支收口 3 条** | 各自 worktree | 分散 | — | DeepSeek | `feature/merchant-network-mvp-0910`、`pr/community-post-completion-0912`、`fix/creator-reapply-receipt-0825`:各自 rebase → 相关测试 → 开 PR;**内容已在 main 等价存在的不开**,写证据;`fix/creator-reapply-receipt-0825` 落后 main 30 |
| 16 | **4-B 俱乐部主题运营** | 新分支 | `feature/club/**` | 承 #14 | DeepSeek | `club/topic-detail` `club/topic-story` 两页 + event-ops 13 + topic-setting 3 + open-settings 3 + topic/chapter 2 + recruit/overview + topic-node-answer + event-notification/audience-counts + crm/topic-customers。⚠️ **俱乐部线生产从未被真人走过**,只能单测覆盖,PR 描述注明「上线前需真号冒烟」 |
| 17 | **裁判立基线** | `tool/` | `tool/**` | 全部域线合并后 | DeepSeek | `EXPECTED_XCX_PAGE_COUNT = 130`;删 §5.1 的 7 条消失页;未落点页登记 `kind: gap`(priority/phase 按 §5.1 归属);`GAP_BASELINE` = 实测数;负控(**删一条 gap 必须 exit 1**);顺带把 §2 读数表更新进总规划 §基线读数 |
| 18 | **#30 收尾** | 总控旁路 | — | W3 后 | — | 观测 `git diff origin/main origin/feature/parity-missing-pages-0909 --stat -- lib test \| tail -1`,残留文件逐个标「丢弃理由 / 补进哪个 PR」,**不许默认丢**;然后 #30 评论列去向 → `gh pr close 30`(不删分支) |

## Source: 城瘾文档/App对齐小程序_总规划_20260914.md

### 0. 决策记录(已拍板,执行时不再讨论)
| D1 | **Android 暂不管**。Android 上地图组件直接走「地图暂时不可用」降级,不维护双实现 | 用户 [number] |
| D2 | **地图换 Apple Maps**(iOS),整体移除高德 SDK | 用户 [number] |
| D3 | **不换 SwiftUI 重写**,继续 Flutter。上架后再按具体屏评估 | [number] 建议,用户转入规划 |
| D4 | **不走 Figma → Claude Design → 代码**。小程序即设计稿;Figma 手册只承载「代码表达不了的规则」,颜色/间距真源仍是 `chengyinhub-xcx/style/tokens.wxss` | 同上 |
| D5 | Claude Design 只用于**不该 1:1 搬、要按 iOS 重做交互**的部分(玩法小组件) | 同上 |
| D7 | **地图是 App 独有的 Apple 原生体验,不 1:1 跟小程序**:Apple Maps 底图 + 定位(蓝点/跟随/朝向)+ **真实道路路线规划**(MapKit `MKDirections`,步行默认,可切驾车/公交,距离与 ETA)+ **路线导航**(App 内分步引导 + 偏航重算,一键「在地图中打开」交给 Apple 地图)。小程序只有 `wx.openLocation` 和节点直线连线,视觉对照里地图相关差异一律 accepted | 用户 [number] |
| D8 | **全 App 采用 iOS 27 设计语言**,范围 = 系统层(导航栏/Tab Bar/Sheet/菜单/搜索/工具栏/弹窗)+ 列表与表单(设置/我的/订单/表单页用 iOS 分组列表、原生开关与选择器)+ 玩家内容页(首页流/活动详情/玩法页的材质与排版,品牌视觉随之调整)+ 商家后台全部原生。**对齐的对象从「像素」改为「结构」**:页面、入口、字段、文案、接口、状态(空/加载/错误/权限)、业务规则 1:1 跟小程序;外观与交互一律 iOS 27 原生。视觉对照台(0.3)用于核「结构/信息是否一致」,外观差异默认 accepted(注明「iOS 27 原生化」)。**覆盖 D6②**(Liquid Glass 不再只限系统层,按 iOS 27 HIG 使用)。Phase 3 相应改为「按 iOS 27 规则手册重做外观 + 结构对照」 | 用户 [number]
| D9 | **消息页 App 就该与小程序不同**:做成 iOS「信息」式原生体验,不 1:1;视觉/交互差异全部 accepted;会话数据与接口仍以后端为准 | 用户 [number] |
| D10 | **iOS 27 手册拍板(PR #45 §7 七问)**:① 商家后台**恒浅**,不跟随系统 ② 玩家**恒暗**保留,token 补齐浅色值 ③ **要真玻璃**:立项原生桥 **B1 `native_flutter_sheet`**(UISheetPresentationController 承载 Flutter 内容);B2 滚动联动大标题**不做**(随 ④)④ 一级页**不改**导航栏大标题,`CyPageTitle` 保留(撤销手册 P2「替换」项)⑤ IM 列表**加**左右滑动操作(置顶/已读/删除),属 D9 批次 ⑥ 主题编辑器**浅色**保留(Task 2.2 照做)⑦ Global Constraints 已同步 | 用户 [number] |
| D6 | Brand Handbook 规则:① 小程序原结构 + Apple 原生 UI/UX,不重新设计 ② Liquid Glass 只用于 Tab Bar、Sheet、Menu 与悬浮系统层 ③ 角色外观:玩家=暗色、商家=浅色、主题编辑器=浅色 | Figma 封面 |
#### 1.3 功能缺口(四路审计汇总,静态 grep 所得,❌ 可信、✅ 只代表接口接上)
| 玩家核心 | 17 | 9 | 2(+ ~30 个玩法组件) |
| 发布 / 会员 / 资产 / 设置 | 25 | 8 | 0 |
| 商家 + 主题 | 15 | 7 | 7 |
| 俱乐部 / 合作 / 组队 / 广场 | 18 | 3 | 12 |
#### 1.3b 含在途分支的真实缺口([number] 预读,Task −1.5 合并后再正式重算)
| 接口 | 155 | **56 条没人做** | #30 独有补 41 条;#39 / figma / chat / reapply / mnet / waitlist / polish 独有 0;party 独有 1(`team/my`) |
#### 2.1 标准单页循环(所有 Phase 3/4 任务都按这 8 步)
- [ ] **S1 读真源**:`git -C ~/Downloads/chengyin show github/master:chengyinhub-xcx/P.{wxml,wxss,js,json}`,以及它引用的组件。⚠️ 永远读 `github/master`,不读工作区([number] 因工作区落后 4 commit 下错结论)。
- [ ] **S2 查已有判定**:`test/endpoint_reachability_test.dart` 的 `kKnownUnreachable`、`test/blocked_by_backend_test.dart`、`tool/page_parity_manifest.json`。**已判过的不重复做**([number] 派出 19 条里 18 条已有判定)。
- [ ] **S3 列清单**:该页的 接口(按 `endpoint_parity.py` 口径)· 状态(normal/empty/loading/error/…,对照 `shot-matrix.js` 里该页的行)· 文案 · 交互入口。
- [ ] **S4 写失败测试**:golden(按 shot-matrix 同一 fixture 数据)+ 行为测试(按钮 → 调哪个 API)。跑一次确认红。
- [ ] **S5 实现**:按 `AGENTS.md` 对照表翻译;控件用 Cupertino / 原生,禁 Material 控件(已有门禁 `no_material_*_test.dart`)。
- [ ] **S6 过裁判**:`flutter analyze` 零警告 · `flutter test` 相关用例绿 · `python3 tool/page_parity.py` / `endpoint_parity.py` / `copy_parity.py` 该页不再报 · `manifest` 登记。
- [ ] **S7 视觉对照**:`python3 tool/visual_parity/build_review.py --only <shotId>` 生成左右对照页,Claude 读两张图列差异 → 修 → 重生成,直到差异只剩「有意的 iOS 原生化」并在 pairs.json 的 `accepted` 里写明。
- [ ] **S8 登记 + 提交**:更新 `tool/page_parity_manifest.json`(gap→route)、`tool/visual_parity/pairs.json`、本文档对应勾;commit(pathspec)。
#### Task −1.1: 给所有脏 worktree 做无侵入快照(不改工作区、不碰 stash 栈)
- [ ] **Step 1: 刷新盘点**
- [ ] **Step 2: 对每个 `脏 > 0` 的 worktree 做快照分支**(用临时 index,工作区、真实 index、stash 栈都不动;包含未跟踪文件,遵守 .gitignore)
- [ ] **Step 3: 观测** —— 每个快照 `git diff --shortstat HEAD <快照>` 的行数应与 Step 1 的 `git -C <wt> diff --shortstat` 同量级(快照多出未跟踪文件);`git -C <wt> status --porcelain | wc -l` 与快照前**相同**(证明工作区没被动)。
- [ ] **Step 4: 推备份**:`git push github 'refs/heads/wip-snapshot/*:refs/heads/wip-snapshot/*'`,再 `git ls-remote github 'refs/heads/wip-snapshot/*'` 回读确认条数。
#### Task −1.2: 先合三个小 PR(#41 → #35 → #39)
- [ ] `gh pr view 41 --json mergeable,statusCheckRollup` 复核仍绿 → `gh pr merge 41 --squash --match-head-commit <合前 headRefOid>`
- [ ] #35:在新 worktree `git fetch github && git switch -c fix/disabled-button-fg github/fix/disabled-button-fg && git rebase github/main`,解冲突 → `flutter analyze` + `flutter test --exclude-tags needs-local-env` → push `--force-with-lease` → CI 绿 → squash 合
- [ ] #39:同上;冲突多半在 `lib/feature/play/` 与 #38 之后的改动
- [ ] 每合一个都重查剩余 PR 的 mergeable(合并会把干净 PR 顶成冲突)
#### Task −1.3: 拆分并落地 #30
- [ ] **Step 1: 分清未提交部分是什么** —— 在快照分支上 `git diff --stat HEAD wip-snapshot/parity-missing-pages-[number] -- lib | sort -k3 -rn | head -40`,按 `lib/feature/<域>` 归类;`artifacts/`、`assets/home/*`(未跟踪图片)判断是否属于小程序资源搬运。
- [ ] **Step 2: 去重** —— 以下与已合 / 先合的 PR 重叠,**以先合的为准,从 #30 里丢弃**:
- [ ] **Step 3: 按域重开 PR**(每个都从最新 `github/main` 建分支,`git cherry-pick` 对应 commit + 从快照分支 `git checkout <snapshot> -- <该域路径>` 带入未提交部分):
- [ ] **Step 4**: 每个新 PR 走 CI;全部合并后关闭 #30(评论里列出去向),回收其 worktree。
- [ ] **Step 5: 观测** —— `git diff github/main wip-snapshot/parity-missing-pages-[number] --stat -- lib | tail -1` 剩下的就是「没被任何新 PR 带走」的改动,逐文件判定「丢弃 / 补进某 PR」,不许默认丢。
#### Task −1.4: 回收与主 checkout 归位
- [ ] 从主 checkout `~/城瘾app/app` 执行;对每个待回收 worktree 核四条:PR state=MERGED(或已判定废弃)· 快照分支已推远端 · `status --porcelain` 为空或已快照 · 用户确认无活会话。四条全过才 `git worktree remove`。
- [ ] 主 checkout:快照已推 → `git -C ~/城瘾app/app switch main`(工作区有改动会拒绝,此时 `git restore -SW .` 前**再次确认快照分支存在于远端**)。
- [ ] theme-world:`git push github liboyang42-cpu/theme-world-app-party-0910` 备份顶端 → 回收 6 个祖先 worktree。
- [ ] 回收完 `git worktree list | wc -l` 记录进本文。
#### Task −1.5: 在新 main 上重算缺口
- [ ] 重跑 `page_parity.py` / `endpoint_parity.py`,把真实数字写回 §1.2、§1.3,并**改写 Phase 4 清单**:在 −1.3 已落地的条目前打 ✅ 并注明 PR 号。Phase 0 Task 0.2 的 `GAP_BASELINE` 用这里的真实 gap 数,不再用 23。
#### Task 0.1: 修复 `copy_parity.py` 崩溃
- [ ] **Step 1: 写失败测试**
- [ ] **Step 2: 确认红**
- [ ] **Step 3: 最小修复** —— `EXEMPT` 的语义在 `d1a37c8` 后由 manifest 里 `kind == "system"` 的条目承载:
- [ ] **Step 4: 确认绿**
- [ ] **Step 5: 负控** —— 临时把 `exempt` 改回 `P.EXEMPT` 跑一次必须红,再改回。
- [ ] **Step 6: Commit**
#### Task 0.2: page manifest 升到 130 页,缺口显式登记为 `gap` 并加 ratchet
- [ ] **Step 1: 写失败测试**(追加到 `test/page_parity_test.dart` 的 `main()`)
- [ ] **Step 2: 确认红**
- [ ] **Step 3: `_validate_bindings` 增加 gap 分支**(放在 `if kind == "system":` 之前)
- [ ] **Step 4: 更新 manifest** —— 删除 `pages/club/edition-report/index`、`pages/merchant/discover/index`、`subpackageTalent/search/index`、`pages/publish/biaoqian/biaoqian`、`pages/club/dissolution-blockers/index`、`subpackageP3/pages/creator/index/index` 六条;追加 23 条,priority/phase 按下表:
| pages/team/detail/index · pages/team/join/index | P0 | 4.1 |
| pages/merchant/aftercare/index · pages/merchant/aftercare/detail/index | P1 | 4.2 |
| pages/merchant/team/index · pages/club/roles/index | P1 | 4.2 |
| pages/club/settlement/index | P1 | 4.2 |
| pages/club/governance/index · pages/club/notify/index · pages/club/event-ops/index · pages/club/customers/index · pages/club/customer-detail/index · pages/club/checkin-detail/index | P2 | 4.3 |
| pages/merchant/reviews/index · pages/merchant/customer/detail/index | P2 | 4.3 |
| pages/club/topic-detail/index | P2 | 4.3 |
| pages/merchant/game-node/index · pages/merchant/predict/index | P3 | 4.4 |
| pages/play/circle/index · pages/club/topic-story/index | P3 | 4.4 |
| subpackageRoam/nearby/index · subpackageRoam/citystamp/index · pages/coop/invite-detail/index | P3 | 4.4 |
- [ ] **Step 5: 确认绿 + 负控**
- [ ] **Step 6: Commit**
#### Task 0.3: 视觉对照台(小程序截图 ↔ App golden 配对)
- [ ] **Step 1: 采集小程序全量截图**(在小程序仓,不改其代码)★ 09-17 本机注:**已作废**——R1 禁截图矩阵且 `~/Downloads/chengyin` 不存在;跳过本 Step。
- [ ] **Step 2: 写 `build_review.py`**
- [ ] **Step 3: 生成 `pairs.json` 初稿** —— 从 `shot-matrix.js` 读出所有非 blocked 行,全部 `status: "todo"`,`appGolden` 先按文件名/页面人工配对能配就配,配不上填 `null`:
- [ ] **Step 4: 自检 + 生成对照页**
- [ ] **Step 5: README 写清三件事**:采集命令、配对规则(同一 fixture 数据)、`accepted` 只能写「有意的 iOS 原生化」(例:小程序自绘导航栏 → iOS 大标题导航)。
- [ ] **Step 6: Commit**(`build/` 不进仓)
#### Task 0.4: 记录首轮基线 + 开 PR
- [ ] 跑三个脚本 + 对照台,把数字填进本文 §1.2 下方「基线读数」表(日期、SHA、页面 gap、接口缺口、文案 <60% 页数、视觉 todo/diff/accepted)。
- [ ] `git push github <分支>` → `gh pr create --base main`,描述写本 Phase 所有数字。
- [ ] **本文档移到 `03-进行中`**。
| | | | 23 | 152 | | |
#### Task 1.1: Spike —— 坐标系与 API 验证(先观测,再动手)
- [ ] **Step 1: 加依赖**
- [ ] **Step 2: 写 `apple_scene_view.dart`**(保持与 `amap_scene_view.dart` 同样的 marker 状态色、围栏、轨迹线语义)
- [ ] **Step 3: 坐标观测(决定 Phase 1 能否继续的闸)**
- [ ] **Step 4: Commit(spike 可保留)**
#### Task 1.2: 所有消费方切到 `AppleSceneView`
- [ ] **Step 1: 改门禁测试(先红)**
- [ ] **Step 2: 确认红** —— `flutter test test/core/map_platform_gate_test.dart 2>&1 | tail -c 2000` → FAIL
- [ ] **Step 3: 替换**(用 serena `find_referencing_symbols` 找全 `AmapSceneView` 引用,逐个改 import `../../core/map/apple_scene_view.dart` 与类名)。`map_page` / `play_session_page` 里原来挡 `Env.hasAmapKey` 的页面级降级改成挡 `Platform.isIOS`,**保留** `play_session_page` 的隐私同意判断。
- [ ] **Step 4: 确认绿** —— `flutter analyze 2>&1 | tail -c 2000`(零警告)+ `flutter test 2>&1 | tail -c 3000`
- [ ] **Step 5: 视觉观测** —— 模拟器依次深链进入 `/map`、`/roam`、`/play/<真实activityId>`、`/topic/<id>`,各截一张,检查 marker、围栏圈、轨迹线都在。
- [ ] **Step 6: Commit**
#### Task 1.3: 选点页改为「搜索 + 点地图」,原生 `MKLocalSearch` 桥
- [ ] **Step 1: Dart 侧失败测试**
- [ ] **Step 2: 确认红** —— `flutter test test/core/map/place_search_test.dart 2>&1 | tail -c 1500`
- [ ] **Step 3: `place_search.dart`**
- [ ] **Step 4: Swift 侧**(`AppDelegate.swift` 顶部 `import MapKit`;在 `nativeTextInputAlertChannel = inputChannel` 之后追加)
- [ ] **Step 5: 改 `poi_pick_page.dart`**:顶部 `CupertinoSearchTextField` → 调 `searchPlaces` → 结果列表(`CupertinoListSection`)→ 选中后地图移到该点并显示底部确认栏;地图本体用 `AppleSceneView`,选中点作为单个 `MapPoint`。报错时显示「搜索失败,可以先跳过选点」(保留原「发布后再补上地点」的替代说明)。`_selected` 类型从 `AMapPoi?` 改为 `PlaceResult?`,确认回传结构保持原来的 name/lat/lng 字段名不变(grep 调用方 `publish_pro_page` 核对)。
- [ ] **Step 6: 确认绿 + 观测** —— 单测 PASS;模拟器进 `/publish/poi` 搜「人民广场」,截图确认有结果、点选后回到发布页地点字段已填;**把返回坐标与 Task 1.1 的已知 GCJ 节点比对,偏差 < 20 m**。
- [ ] **Step 7: Commit**
#### Task 1.4: 拆除高德
- [ ] **Step 1**: `grep -rn "amap\|AMap\|AMAP" lib test tool ios/Podfile docs pubspec.yaml 2>&1 | head -c 4000`,逐条归类「删 / 改 / 保留(map_launcher)」写进 commit message。
- [ ] **Step 2**: 按清单删改;`release_build_flags_test` 改为断言「pubspec 中不含 amap」。
- [ ] **Step 3**: `flutter pub get && cd ios && pod install && cd ..` → `flutter analyze` 零警告 → `flutter test --exclude-tags needs-local-env 2>&1 | tail -c 3000` 全绿。
- [ ] **Step 4 观测**:`tool/verify_ios_arm64_simulator.sh 2>&1 | tail -c 2000` 输出 `IOS_ARM64_SIMULATOR_OK`,且 `lipo -archs build/ios/iphonesimulator/Runner.app/Runner` 含 `arm64` —— **不再需要替身 plugin 与 pod 切换**。
- [ ] **Step 5**: 负控 —— 临时把 `amap_map` 加回 pubspec,`release_build_flags_test` 必须红;撤回。
- [ ] **Step 6**: Commit + push + PR(`--base main`),描述附 Task 1.1/1.2/1.3 的截图观测结论。
#### Task 2.1: 重写 `AGENTS.md` 的过时段落,加入翻译对照表
- [ ] **Step 1**: 删「现状(WS4.1…)」整节;「主题」一行改为「token 由 `tool/gen_tokens.py` 从小程序 `style/tokens.wxss` 生成到 `core/theme/cy_tokens.g.dart`,禁手改 .g.dart」;「地图」改为「Apple Maps(`core/map/apple_scene_view.dart`),Android 暂不支持」。
- [ ] **Step 2**: 新增「## 设计总则(Brand Handbook,Figma 5aU5V8MXZ5nPT0GtcOEEC7)」三条,原文照 §0 D6。
- [ ] **Step 3**: 新增「## 小程序 → App 翻译对照表」:
| `wx.request` / `utils/request.js` | `lib/data/api/<域>_api.dart` 方法,经 `dioClientProvider` | feature 不直接发 http |
| `wx.navigateTo({url:'/pages/x/index?id=1'})` | `context.push('/x/1')`(go_router,路由登记 `app_router.dart`) | 新页必须登记 `page_parity_manifest.json` |
| `wx.requestPayment` | `lib/feature/payment/wechat_payment.dart`(fluwx,`/api/registration/pay/app`) | 虚拟道具禁用 |
- [ ] **Step 4**: 新增「## 标准单页循环」,把 §2.1 的 S1–S8 原样写入。
- [ ] **Step 5**: Commit `docs(agents): 重写过时的现状与地图段落,加入设计总则与小程序翻译对照表`。
#### Task 2.2: 主题编辑器浅色外观
- [ ] **Step 1**: 在 `token_codegen_test.dart` 加断言:生成物含 `class CyTokensTopicEditor` 且至少含 `colorBgPage`/`colorTextPrimary`,值等于 `tokens.wxss` 主题编辑器选择器块里的同名变量。跑红。
- [ ] **Step 2**: `gen_tokens.py` 已能解析主题编辑器块,只把它加入输出快照(仿照商家浅色的输出分支),`python3 tool/gen_tokens.py`。
- [ ] **Step 3**: `app_theme.dart` 加 `static ThemeData topicEditor()`;主题编辑相关路由(`/publish/pro`、`/template/edit`、`/template/new` —— 以小程序实际套用主题编辑器 class 的页面为准,grep `tokens.wxss` 选择器名在 wxml 中的使用)套用。
- [ ] **Step 4**: 测试绿 + 对应 golden 重生成 + 视觉对照台核这几页。
- [ ] **Step 5**: Commit。
#### Task 2.3: 试跑 3 页(验证循环与手册)
- [ ] 每页走完 S1–S8。
- [ ] 结束后写「试跑复盘」到本文 §附录 A:哪一步卡住、对照表缺了哪条、裁判有没有误报/漏报。**卡点一律回改 `AGENTS.md` / 脚本**,不在页面里打补丁。
- [ ] `GAP_BASELINE` 23 → 20。
- [ ] PR。
| 3.A | A(填) | 57 | | | / |
| 3.B | B(填) | 67 | | | / |
| 3.C | C(填) | 56 | | | / |
| 3.D | D(填) | 39 | | | / |
| 3.E | E(填) | 32 | | | / |
| 3.F | F(填) | 53 | | | / |
- [ ] `build_review.py --status todo,diff --only <本域 id>` 出对照页
- [ ] 逐组 S7:Claude 读左右两张图 → 列差异(布局/间距/字号/颜色/文案/缺元素/多元素)→ 修 → golden 重生成 → 重出对照页
- [ ] 同一差异在 ≥3 组出现 → **改共用组件或 token,不逐页改**,并回写 `AGENTS.md`
- [ ] 本域全部 `accepted`(有意差异写明)或 `diff`(阻塞原因写明)后 PR
- [ ] 合并条件:CI 绿 · 三个 parity 脚本数字不升 · 本域 visual todo = 0
#### 4.1 P0 —— 不补就没法正式用
- [ ] 〔#30〕**组队**:`team/detail`、`team/join` 页 + 票夹/报名列表的「我的队伍」入口(`/api/team/info` `join` `dismiss` `kick` `quit` `my`)
- [ ] **玩法互动组件**:小程序 `pages/play/components/playkit-*` ~30 种。**先用 Claude Design 出 iOS 交互稿**(决策 D5:触感、震动、传感器),每 5 个组件一 PR;`play_session_page` 占位控件逐个替换
- [ ] 〔#30 部分 / #39 偏好〕**游玩流程接口**:`puzzle/hint` `puzzle/reveal` `route-state`(断点续玩) `preference` `tag` `play/leaderboard`
#### 4.2 P1 —— 资金与权限
- [ ] **权限底座**:`/api/merchant/access/me`、`/api/club/access/me` 接进 `role_provider.dart`,商家首页/俱乐部详情管理 tab 按角色显隐(先做,下面几项依赖它)
- [ ] 〔#30〕商家**售后退款**:`merchant/aftercare` + `aftercare/detail`(`aftercare/list` `detail` `respond`)
- [ ] 订单页**取消并退款**:`orders_page` / `order_detail_sheet` 接已有 `cancel-refund`
- [ ] 〔#30 提现风险确认,需核是否含 preflight〕**提现预检**:`/api/fund/preflight/bank-withdrawal` + 可提现权限拦截
- [ ] 〔#30 商家侧〕商家**店员管理** `merchant/team`(`operators/*`)· 俱乐部**角色** `club/roles`(`roles/list|assign|revoke`)
- [ ] 俱乐部**结算** `club/settlement`(试跑已做则勾掉)
#### 4.3 P2 —— 主理人 / 商家运营
- [ ] 俱乐部后台:`governance` `notify` `event-ops` `customers` `customer-detail` `checkin-detail`
- [ ] 俱乐部详情:开放设置三开关 `open-settings/*`、帖子置顶/编辑/历史
- [ ] 主题导演台 `club/topic-detail`:`topic-setting/detail|save|end`、`recruit/overview`、`crm/topic-customers`;接上已写未用的 `club_lead_api.start/arrive`
- [ ] 〔#30〕商家:`reviews`(列表/回复/举报/公开)、CRM 分群/批量打标/营销发券/导出、`customer/detail`
- [ ] 主题运营 `topic/merchantinfo`:`topic/chapter/finish` `recruit`、圈子供给暂停/重确认;接上已写未用的 `pendingChapterNodes` `auditChapterNode` `chapterNodePosterCode`
- [ ] 活动编辑:`/api/activity/update` + 「我的项目」编辑入口
- [ ] 模板 AI 填充 `/api/ai/template/fill`;设置页营销授权开关 `crm/marketing-consents`、俱乐部入口创建/申请/管理分流
#### 4.4 P3 —— 玩家体验补完
- [ ] 〔#41〕到店 NPC 对话 `ai/npc/shop-chat` `voice-chat`
- [ ] 〔#30〕圈子主题 `play/circle`(`circle-theme/*`)· 剧情节点答题 `club/topic-story`
- [ ] 漫游社交:`subpackageRoam/nearby`(约伴全套)、`roam/presence` `nearby-runners` `shop/visitors` `roam/tiles/page`
- [ ] 邮票兑换 `citystamp`(`roam/stamp/exchange`)· 〔#30〕现场签到码 `merchant/game-node` · 竞猜 `merchant/predict`
- [ ] 零碎:首页扫码 `play/scan-entry`、〔#30〕活动候补 `event-ops/waitlist/*`、营销 7/30 天切换、合作中心官方活动列表、`topic/beta/graduate`、主题评价入口、`coop/invite-detail` 深链页
- [ ] 【用户】developer.apple.com → Membership 确认 **Active**,记下 **Team ID**
- [ ] 【用户】Identifiers → `com.chengyinhub.chengyinApp` 勾 **Sign in with Apple**、**Associated Domains**
- [ ] 【用户】微信开放平台注册「移动应用」,拿真 appid(≠ 小程序 appid),登记 Universal Link `https://www.chengyinhub.com/app/`
- [ ] 【agent】`project.pbxproj` 三处 `DEVELOPMENT_TEAM = <TeamID>`;`kWechatAppId` + `Info.plist` URL scheme 同时替换(`release_readiness_test` 会自动开始逐字比对)
- [ ] 【agent 写 / 用户部署】`https://www.chengyinhub.com/.well-known/apple-app-site-association`,内容含 `<TeamID>.com.chengyinhub.chengyinApp`,`Content-Type: application/json`;**观测**:`curl -sI` 看 content-type + `curl -s | python3 -m json.tool` 看 appID
- [ ] 【agent】`flutter build ipa --release 2>&1 | tail -c 3000`;**回读**:`plutil -convert xml1 -o - build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Info.plist | grep -c wxYOURAPPID` 必须 0;`codesign -d --entitlements - <Runner.app>` 含 applesignin 与 associated-domains
- [ ] 【用户】Transporter / Xcode Organizer 上传 → TestFlight 内测
- [ ] 【用户】真机验:Apple 登录、微信登录回跳、微信支付(线下核销类)、地图定位打卡

## Source: 城瘾文档/收款模型_主办方自收与平台自动分账_定稿_20260915.md

### 2. 收款规则(按主办方)
| 1 | **官方主办**(探店日 / 官方自由探索等) | 官方(平台自己的商户号) | 全款 | 俱乐部报酬、商家结算**全部线下谈**,小程序不设计结算 |
| 2 | **自由定向 · 俱乐部主办** | 俱乐部子商户号 | 自动分账抽成 | 俱乐部邀约的商家:写好分成模式/比例做展示,线下合同算钱 |
| 3 | **经典定向 · 俱乐部主办** | 俱乐部子商户号 | 自动分账抽成 | 同 2 |
| 4 | **商家主办** | 商家子商户号 | 自动分账抽成 | 商家找俱乐部带队:条款只展示,线下算钱 |
| 5 | **个人主办** | 个人小微商户号 | 自动分账抽成 | 同上 |
| 6 | **自玩票** | 谁发布的主题给谁 | 自动分账抽成 | — |
| 7 | **漫游 / 商家入驻官方活动** | 不收钱 | — | — |
### 6. 现码差距与施工清单
| 参与方提现 | 余额提现 / 转零钱(`ApiWalletController` 开关默认 false)、`pages/coop/withdraw`、`pages/club/settlement` | 显示应得金额 + 点击弹出主办方微信号 |

## Source: 城瘾vault/_未完成项_优先级排序_20260712.md

### P0 · 资损 / 信任 / 发版硬门槛(必须先做)
| 1 | **报名/收货 PII 加密迁移**(`cms_registration.realName/phone`、`oms_order.receiver*` 明文→加密列 + 历史迁移)—— 全仓仅密码哈希 + 提现 PII 加密,报名/收货仍明文 | 【码】 | 合规整改 177/178/228(grep 复核确认未做) |
| 2 | **UGC HOLD 展示 + 审核积压 SLA 监控** —— xcx 无 UGC "仅自己可见"态(现有"审核中"都是商家/主题审核,非 UGC 内容);后端 task 目录无审核积压监控 job | 【码】 | 合规整改 84/85/223(grep 复核确认未做) |
| 3 | **留存清理 job**(`tms_browse_record`…`biz_event_log` 按保留期清理)—— task 目录仅有结算/提现/订单类,无清理类 | 【码】 | 合规整改 183(grep 复核确认未做) |
| 4 | **法律文案填充**(隐私政策/用户协议/退款规则等八份 v1.1)—— 代码判不了,真上线前硬门槛 | 【法】 | 合规整改 195/232、商业化 U-09 |
### P1 · 核心链路功能缺口(影响三角色平台完整性)
| 8 | **三角色「我的项目」分层**(owner_type 玩家/商家/俱乐部分 tab,现只后端二值) | 【码】 | 获奖级 452/453/792 |
| 9 | **参与结束一周隐藏 + 只留订单详情可查**(全仓无一周隐藏逻辑) | 【码】 | 获奖级 450/451/484 |
| 10 | **订单七态模型**(待支付…不可退款重排,现只五态) | 【码】 | 获奖级 477 · `order.wxml` |
| 11 | **AI 前端三个入口**:俱乐部侧方案卡入口、发布前 `safety/precheck`、商家/俱乐部双端 AI 工作台(后端全做完,前端只接了 fabu 内联两口) | 【码】 | AI技能 42-46/67/83-85 |
| 12 | **发布器四路拆分**(主题/活动/自由探索/城市定向)+ 自由探索"开放范围"必填 | 【码】 | 获奖级 534/537/538 |
| 13 | **俱乐部排行榜改本团贡献**(现取全局 `m.point`)+ 距离/完成时间维度 | 【码】 | 俱乐部 BE-5.4 · `ClubMemberMapper.xml:71` |
| 14 | **俱乐部经营配置**:优先报名/优惠价/名额保留/收益管理 | 【码】 | 获奖级 522/523/756 |
| 15 | **乙-2 定价含发起人保底 + 同城参考价**(现 P_min 未扣保底率,参考价无实现)+ 前端滑杆 | 【码】 | 承接分账 170/181 |
| 16 | **客诉前端入口**(后端受理接口已在,前端无统一入口) | 【码】 | 承接分账 185 |
| 17 | **举报去重限频**((bizType,bizId,submitterId) 去重,现直插) | 【码】 | 俱乐部 BE-5.6 |
| 18 | **勋章前端入口**(后端 badge 接口在,xcx 零调用,空墙) | 【码】 | 俱乐部 BE-5.5 |
| 19 | **订单详情商家/主理人信息卡 + 结构化退改规则表**(现仅文案说明) | 【码】 | 获奖级 479/480 |
### P2 · 体验打磨 / 收尾
| 20 | **全站 token 迁移收尾**:`index` 首页语义灰/卡片底仍硬编码(`#6A7282`/`#999`/`#f3f3f3`)+ 低频页 S4 + 全站 174 处裸 button 统一 | 【码】 | token迁移 S3/S4、商业化 D-09 |
| 21 | **IM 消息中心**:分私信/俱乐部/系统 tab、群聊主题上下文、富消息卡(位置/路线/报名)、空/失败/未读/免打扰态 | 【码】 | 获奖级 551-554 |
| 22 | **探店浮卡重构**:去重店名 + 真实门头图 + 集章进度 | 【码】 | 点亮城市 37 · `roam/index.wxml:56` |
| 23 | **勋章配置化**(硬编码"三店连亮"→ fabu 配置) | 【码】 | 点亮城市 40 |
| 24 | **足迹卡 canvas 真图生成 + 保存相册** | 【码】 | 点亮城市 47 |
| 25 | **分享渠道收口**(广场直连/朋友圈足迹卡图,去占位 toast) | 【码】 | 点亮城市 48 |
| 26 | **roam 结算页导流购票推荐卡** | 【码】 | 自由探索 R5、三模式 62 |
| 27 | **roam Core Loop 埋点漏斗** | 【码】 | 自由探索 R6 |
| 28 | **P3 growth/world/creator 降级**(仍注册主路径,应隐藏/占位) | 【码】 | 获奖级 563/565/763/764/765 |
| 29 | **首页继续探索卡渲染 + 统一 CTA**(JS 脚手架在,wxml 未渲染) | 【码】 | 获奖级 358/360 |
| 30 | **userinfo 改"城市探索者名片"** | 【码】 | 获奖级 709 |
| 31 | **专业版创作器收尾**:游戏 sheet 搜索/筛选、面包屑、"待配游戏"占位、文案统一"保存玩法" | 【码】 | 创作器 187/188/190 |
### P3 · 二期 / 远期(明确后置,最后做)
| 32 | **官方活动通道整块**(官方→商家邀约、官方授权节点、后台审核台/管理页)—— 代码零实现,注意是有意后置 | 店铺装修 E3、商家据点 P3 |
| 33 | 彩蛋 AI 自动生成管线(routeGeometry 采样→LLM→入库) | 自由探索 L2、三模式 68 |
| 34 | 章节结算卡 + 终章大揭晓 + 旅程图 | 自由探索 L3、三模式 69 |
| 35 | 完成后 24-72h 订阅消息召回 | 自由探索 L5、三模式 71 |
| 36 | 商户自助后台(据点投放 + 认领节点) | 自由探索 L6、三模式 72 |
| 37 | 客户 CRM(复购/异常/触达) | 商家端架构 1518 |
| 38 | 后台批量导入线下商家 | 附近商家 321 |
| 39 | 底图风格切换(暗色/卫星)、时段玩法、Blackbird 式邀请 | 点亮城市 32/41/42 |
| 40 | E4 商家端商业化收费(前缀路由/分账/订阅配额叠加)+ E5 搜索 geo 排序 | 店铺装修 E4/E5 |

## Source: 城瘾vault/02-待部署/Figma玩法UI动效稿_v5.1新玩法组件落实_20260826.md

### 0. 起因:这份稿的落实率盘点
| 🧩 可复用组件库 v5 | 17 | 17 ✅ | 17 ✅ |
| 📱 Demo A–H(8 屏) | 8 | 8 ✅ | 8 ✅ |
| 📱 Demo v5.5 三身份 12 态 | 12 | 12 ✅ | 12 ✅ |
| Anim/* 动效关键帧 | 6 组 | 5 | **6 ✅**(补了路线流光) |
| 📐 规范 v5 + Foundations v5.2 | 3 | 3 ✅ | 3 ✅ |
| 🧩 组件库 v5.2 · GameTimerSheet | 1 | ⚠️ 半(倒计时内联在 advanced-game) | **1 ✅**(抽成独立组件) |
| 🧩 **组件库 v5.1 · 新玩法** | 16 | **0 ❌** | **12 ✅**(另 4 个是 App 端) |
#### 组件库 v5.1(node 45:248)—— 落到小程序的 12 个
- [x] `cy-mascot` 猫向导(normal / blindfold 两态,用 Figma 导出的 SVG,不手绘)
- [x] `cy-playkit-timewindow` 时段限定·未开放(node 45:293)
- [x] `cy-playkit-blindtaste` 盲品挑战(46:259)
- [x] `cy-playkit-silentorder` 沉默点单·店员见证(46:295)
- [x] `cy-playkit-diyname` DIY 作品命名(47:270)
- [x] `cy-playkit-musiccorner` 治愈音乐角(47:289)
- [x] `cy-playkit-steps` 计步挑战(48:270)
- [x] `cy-playkit-woodfish` 赛博木鱼·氛围件(48:283)
- [x] `cy-playkit-stickerbook` 城市贴纸图鉴(53:292)
- [x] `cy-playkit-dailysign` 今日城市签(53:337)
- [x] `cy-ai-score-card` AI 参考分(47:319)
#### 组件库 v5.2 · P0(node 68:303)
- [x] `cy-game-timer` 计时快答 Sheet,Ready/Running/Critical/Result 四态
- [x] `cy-ring-meter` 分段环形读数(计步与计时共用)
#### Anim/路线流光(node 42:294)
- [x] roadmap 路线段沿路循环高光,只在走过的段亮,reduced-motion 整条撤掉
#### 接线
- [x] `cy-playkit` 分发器把九种玩法壳收成一个出口,事件统一成 `kitaction`
- [x] play 页挂载:玩法 sheet 由 **cy-advanced-game 抛出的会话视图**驱动(#857 改;#853 里那个
- [x] 需服务端裁决的动作走**既有**的 `/api/play/advanced/action` 幂等通道,未新造协议
### 3. 上线后玩家仍看不到 —— 但原因和上一版不同了
- [ ] **在模板或节点的 `advanced_config_json` 里真配出七段之一**
- [ ] AI 参考分同理:`/api/play/photo` 回执里带 `aiScore` 才出现这张卡

## Source: 城瘾vault/02-待部署/俱乐部页视觉重做_参考调研_对标Strava与NRC_20260825.md

### 0. 先纠一个基线:这次是「视觉重做」,不是「IA 重做」
| 管理 tab 以「项目」为组织单位,点进 `merchantinfo` 主办视图 | ✅ `goManageTopic()` → `/pages/topic/merchantinfo` |
### 9. Figma 文件([number] 已建)
| A 俱乐部详情 · 主理人 | 7 | 暗 |
| B 俱乐部详情 · 会员 | 4 | 暗 |
| C 俱乐部详情 · 访客 | 1 | 暗 |
| D 配置 · 编辑资料与解散 | 7 | 暗 |
| E 项目主办视图 · 俱乐部态 | 4 | **浅** |
| F 活动导演台 | 2 | **浅** |
| G 建团 | 4 | 暗 |
| H 成为主理人 | 4 | 暗 |
| I 入会申请 | 2 | 暗 |
| J 报名名册 | 2 | 暗 |
| K 质量证据 | 1 | 暗 |
| L 解散前待处理 | 1 | 暗 |
#### 批 1 已完成(PR #841)
- [x] `scene-club-edit` 封面占位:说明挪到字段 hint,框内只留「＋」,不再被 `overflow:hidden` 裁切
- [x] `edition-report` 维度触发器:新增 `dimensionLabel` 显示中文,提交仍用 `dimension`(key),不动接口契约
- [x] 门禁:`lint:ui` / `ds-hardcode-gate` / `test:unit` / `audit:actions` 全绿
- [x] 负控:干净 `github/master` 上 `audit:actions` = PASS,证明台账变红由本次改动引起
- [x] automator 实拍复核两处修复(含切换维度的负控)
#### 批 2+3 已完成(PR #843)
- [x] Hero 400→240rpx;logo 128→96rpx 仍压封面下沿;名字+元信息并成一栏挪到 logo 右侧
- [x] 分享从整宽按钮收成导航图标(与齿轮并排)
- [x] 头部去掉没有项目上下文的经营动作;阶段式 primary 搬进管理 tab 的 NOW 卡
- [x] 管理 tab 九块 → 三块(NOW 卡 / 项目组 / 经营四条折叠)
- [x] 撤掉项目工具七宫格与待带队场次(与项目列表同源)
- [x] 治理搬进齿轮「俱乐部设置」弹窗,成员管理与项目工具在弹窗内二级展开(不嵌 sheet)
- [x] 帖文对齐 `pages/talent/list` 的 `.post`;改成显示**作者**而不是俱乐部(后端本来就返回 nickname/avatar)
- [x] 发帖区默认收起成 pill
- [x] 折叠动效落地:展开 300ms `emphasized-decelerate` / 收起 200ms `accelerate`
- [x] 四份契约测试同步更新(位置变了、不变量没变)

## Source: 城瘾vault/02-待部署/帖文UI整改与新功能施工文档_20260902.md

#### B · UI 对齐：3 处
| B1 | `pages/square/list` 行内 composer | 占位文案整行通栏，与头像右边缘不齐 | 头像 40 靠左 12，**昵称/正文/工具栏一律从 64 起** |
| B2 | `pages/square/detail` 评论条 | `<cy-btn>发送</cy-btn>` 文字键 | 改成图标键（圆形实底 + 上箭头） |
| B3 | `pages/square/list` feed 加载态 | `cy-skeleton type="card"` | 鱼骨：头像 40 + 三条长短不一的线（105/299/233 × 10, r=5）+ 媒体块 + 操作行 |
#### 3.2 A 的最大坑：token 一改要同步**六处**
| 1 | `style/tokens.wxss` 的 `page{}` | — |
| 2 | `style/tokens.wxss` 的 `.theme-merchant`（含 `.theme-light`） | — |
| 3 | `style/tokens.wxss` 的 `.theme-topic-editor` | `topic-editor-theme-contract` |
| 4 | `style/tokens.wxss` 的 `.theme-dark` | `system-darkmode-contract` ②「深色块键集与 .theme-light 完全一致」 |
| 5 | `style/merchant-light.wxss`（浅色块 **和** 它自己的深色块两处） | 浅色块→`ds-theme-sync-check.sh`；深色块→**只有** `system-darkmode-contract` ③ |
| 6 | `style/dark-mode.wxss` 的 `@media (prefers-color-scheme: dark)` | `system-darkmode-contract` ② |
#### 3.5 新增可点控件必须进台账
| `:272` | `interactionMode === 'tap'` | 1413 |
| `:301` | `componentAction` | 697 |
| `:302` | `eventContract` | 972 |
| `:303` | 上面两者之和 | 1669 |
| `:739` | `ledger.controlCount` | 3292 |
#### A1 · 6 个 token
- [x] `tokens.wxss` `page{}` 加 6 档
- [x] `tokens.wxss` `.theme-merchant` 加 6 档
- [x] `tokens.wxss` `.theme-topic-editor` 加 6 档
- [x] `tokens.wxss` `.theme-dark` 加 6 档
- [x] `merchant-light.wxss` 浅色块 + 深色块各加 6 档
- [x] `dark-mode.wxss` 系统深色块加 6 档
- [x] 跑 `npm run test:unit`，确认 `system-darkmode-contract` 与 `topic-editor-theme-contract` 全绿
- [x] 跑 `ds-theme-sync-check.sh`，确认失配数仍是 6（不是 0）
- [x] 在 `danger-on-interactive` 的注释里写死 AA 豁免的**边界**（只给危险文字 on interactive 表面）
#### A2 · 5 个图标
- [x] `design/icons/coolicons/` 加 `comment.svg` `draft.svg` `more-circle.svg` `send.svg`
- [x] ~~替换 `image.svg`~~ —— **核码后取消**：现有 image.svg 已是「相框+日头+山」(5 段子路径含日头圆点)，无需替换
- [x] `pin.svg` 改描边 weight 2；实心版另存 `pin-solid.svg`（均重画为 24×24）
- [x] 跑 `python3 scripts/ds-build-icons.py` 重新生成
- [x] **四处**位图收编（比预计多一处）：`post-card` ×2、`detail` 的 `icon_msg.png`，外加 `detail` 评论项「回复」键的 `icon_msg2.png`。全仓再无 `icon_msg` 引用
- [x] `icon_msg2.png` 已一起收编（它紧挨 `<cy-icon name="heart">`，同一问题）
- [x] 同步改 3 条硬编码断言（`square-feed-card-contract` ×2、`post-card-shared-contract` ×1）
- [x] **文档漏写的一步**：每枚 cy-icon 在 `components/cy/icon/spec.json` 的 `optical.icons` 里必须恰有一条元数据，
- [x] 撤掉补丁 —— master 上是 `invert(0.75)` 版（那 3 个未推提交才改成 `invert(1)`）。连带清掉 4 条失效规则：post-card 的 filter + `--light` 覆盖、detail 的 `.ic-white` 与 `.item-link image`
- [x] 已评估 `heart-filled.svg`：**本轮不收编**。它现在靠 SVG 自带红 + `grayscale(1)` 压灰，换 cy-icon 就变成 currentColor 取色 —— 是视觉行为改变而非等价替换，需真机截图验收，不与本轮的位图→矢量等价替换混做
- [x] 回读确认：56 → **61 枚**，`comment/draft/more-circle/send/pin-solid` 各命中 1
#### B · UI 对齐
- [x] B1 composer 拆 `compose-row`(头像列) + `compose-col`(内容列)。对齐值实算：`--cy-page-x` 32 + 头像 `--cy-space-7` 80 + gap `--cy-space-2` 16 = 128rpx = 64pt，三个 token 都是既有的、头像本来就是 40
- [x] B2 发送键改图标：`cy-btn` 新增 `shape="circle"` 变体（放组件里 —— cy-btn 是 `styleIsolation:isolated`，页面样式够不到内部 `.btn`），用 A2 的 `send`。loading/disabled/无障碍名称全保留
- [x] B2 遗留已确认:`github/master` 上 `.david_nplok`「完成」仍在,**有意保留** ——
- [x] B3 `cy-skeleton` 新增 `post-card` 档：头像 + 三条长短不一(31%/89%/70% ← 105/299/233÷335) + 媒体块 + 操作行，与 cy-post-card 同构
- [x] 全量 4830 pass / 0 fail；`audit:actions:update` 已重建(3287 controls)；连带改了 `ann-a-ui-contract` 断言与 `uiux-state-foundation-contract` 棘轮 10→11
- [x] ⚠️ **真机截图验收** —— 做了,而且**抓到两件所有静态检查都漏掉的事**:
#### C · 新功能（**先过 §6 的拍板**）
- [x] C0 定 C3：行内 composer 与新建页的关系 —— **已定,落在选项 1(行内=入口)**。
- [x] C0 **呈现模型:新建帖文是弹窗,不是页面**([number] 用户定)。
- [x] C0 草稿存哪:**已定** —— 复用 `utils/publish/pro-editor-draft.js`(uuid + setData autosave
- [x] C1 新建帖文：~~路由~~ **组件** `components/cy/post-compose` + 顶栏（取消 / 标题 / 草稿+更多）
- [x] C1 编辑区：头像 + 串联线 + 昵称 + 正文 + 附件工具栏（三枚均为占位,到期日 [number]）
- [x] C1 底部工具条：小头像 + 字数 + 发布（空文 40% 禁用,已截图确认灰态）
- [x] C2 草稿弹层：玻璃底 + 弹窗叠弹窗（底层不卸载）—— 已截图确认三层同屏
- [x] C2 草稿列表：Loading 鱼骨 / Filled 一条 + 删除 + 「只有 N 条草稿」
- [x] C2 **删除草稿的确认闸放进组件**，不放页面
- [x] C2 面板高度:**70vh,不是整屏**。稿 379:922 实测 y=190 h=430 / 画板 620 = 69.4%,
- [x] 台账每轮重建并对齐棘轮(现 3271 controls;rebase 后 tap 1396 / event-contract 1665 均按实测重对)
- [x] 「设置」入口：已按拍板**不做**,做成占位 toast + 到期日 [number] + 责任人注释

## Source: 城瘾vault/02-待部署/探店日部署交接清单_20260819.md

### 一、本轮改动与是否触发部署
| #737 ✅已合 | 5 条链路死按钮 + D6 CAS + `publish_mode` 内容闸绕过 | ①②④ | **是**（已部署坐实） |
### 七、本轮抓到的「绿是廉价的」清单（存档）
| 1 | **两条假负控**：`^…$` 锚删 `$` 后 selftest 照绿；`MIN_SHARED_SEGMENTS 2→1` 照绿 |
| 2 | **一整份测试 12 条里 8 条已假绿** —— 红的那 4 条反而是唯一还在工作的 |
| 3 | **恒真断言**：写前 guard 走不到、库干净时必然读到 0 ⇒ 没有任何输入能让它红 |
| 4 | **管道吞 exit code**：`cmd \| tail` 报的是 tail 的 0，`ledger audit` 真值一直是 exit 2 |
| 5 | **CI 里没有 master ref** ⇒ 棘轮外锚静默降级成不校验，日志还打了句指向错误成因的假解释 |
| 6 | **门禁只有一个方向** ⇒ 截图矩阵漏 15 页；44%（64/144）断言拿根容器当锚点、永远不会红 |
| 7 | **md5 判据被状态栏时钟稀释** ⇒ 5 组同图判绿 |
| 8 | **属性名断言被兄弟属性接住**：`/retry="/` 被 `bind:retry=""` 接住 |
| 9 | **`~/.m2` 共用** ⇒ test 步不带 `-am` 吃的是谁最后装的 jar |
| 10 | **`CREATE DATABASE IF NOT EXISTS`** ⇒ 把上次崩掉的现场当成合法初始态 |
| 11 | **git 看不见的语义冲突** ⇒ 两条分支各自对，合起来 `cms_topic` 被建两次 |

## Source: 城瘾vault/02-待部署/漫游四模式_原型逐条搬运_进度_20260909.md

### 原型总量
| 组局 | 14 | `subpackageRoam/nearby` |
| 漫游·迷雾 | 32 | `pages/roam` |
| 城市定向 | 14 | `pages/play`(mode 1) |
| 自由探索 | 8 | `pages/play`(mode 2) |
### 已搬
- [x] **投信箱换一张**(`sgWrite`/`sgDeliver`/`sgNoteDrag`/`sgPrint`/`sgPaper`/`sgScratch`/`sgDone`/`sgnav`/`sgbarcode`/`camPanel`)
- [x] **三键 `trio` / `tbtn` / `bindHold`** → `pages/roam` + `pages/play`。
- [x] **读数卡 `dcard`** → 两页。左右 31→23rpx · 高 273→246rpx · 圆角 31→38rpx ·
- [x] **顶部提示白卡 `topcard`** → 漫游五个提示槽收成一件白卡。
- [x] **输入地址 `searchBar` + `addrScreen`** → 重做成两个状态(白条 / 压暗层 + 结果列表)。
- [x] **商家横滑卡 `shopCards` + `stripDots`** → 卡高/左栏定宽/字号/头像/计数点逐条对齐;
- [x] **工具抽屉 `drawer`** → 删掉内层那张 #1E2028 卡(原型没有,行直接排在黑面上);
- [x] **地图点位 `marker`** → `drawMarker` 按原型 .mk 的 52px 盒重写(挂件挑出盒外,
- [x] **玩法说明 `howtoScreen` + `.kv` 行**([number])→ `pages/roam` 的「自由漫游怎么玩」半屏。
#### 已搬完(这一轮)
- [x] `sheet` / `topicSheet` / `otherSheet` 半屏 —— 壳在 `style/proto-sheet.wxss`,三页共用
- [x] `drawer` / `drow` 抽屉行 —— 漫游 `f-more`、组局 `h-tools`、游玩(城市定向/自由探索)同一份
- [x] `freeBar` / `cityTrio` 三键 —— 含长按 3 秒结束的进度环
- [x] `setScreen` 设置 · `howtoScreen` 玩法说明 · `journalScreen` 旅程手记
- [x] `avs` 头像堆 · `btnRow`(`.btn2`)· `countUp` 数字滚动 · `grabHandle`
- [x] `IC` / `DIC` 图标集 —— `style/proto-icons.wxss` 由 `scripts/_gen_proto_icons.py` 从原型生成
#### 还欠
- [ ] `dragScroll` / `stripDots` —— 横滑图片带在小程序里靠 `scroll-view` 自带惯性,
- [ ] `wireFallbacks` —— 原型的规矩是「不许有按下去没反应的按钮」,现码还没有对应的静态检查

## Source: 城瘾vault/02-待部署/漫游四模式_设计裁决与说明_20260909.md

#### 三处缺口已补齐（[number] 后端）
| 商家卡的头像堆 + `+N` | 新接口 `POST /api/roam/shop/visitors`。数据源是既有的 `roam_shop_visit`，按 `source_id` 分组、先按人去重再取最近来的前 5 张脸；`+N` 用的是去重到人的总数，不是头像条数（头像被截断过）。 |
| 输入地址的拼音 / 首字母 | `/api/map/nearby` 增补 `namePinyin` / `nameInitials`，读的时候用 pinyin4j 算、带 LRU 缓存。同批补了 `productType`，地图上主题点位的绿蓝描边靠它分。**前端仍不带拼音字典**——那要塞进主包，而主包资源棘轮只准降。 |
| 投一张换一张 | 新表 `roam_stamp_exchange` + 新接口 `POST /api/roam/stamp/exchange`、`POST /api/roam/stamp/received`。一行 = 一次交换，同时兼幂等（一张投出的票只兑换一次）、去重（同一个人不会两次收到同一张）、收件箱三件事。 |

## Source: 城瘾vault/02-待部署/漫游附近的局_施工计划_20260905.md

#### Task 1: 迁移 `migration_roam_hangout_20260905.sql`
- [x] **Step 1: 写迁移**
- [x] **Step 2: 跑门禁** `bash ci/migration-layout-check.sh` → 绿;`python3 ci/migration_gates.py`(若要求登记 ledger 按提示补)。
- [x] **Step 3: Commit** `feat(sql): 漫游附近的局 roam_hangout 表与过期任务注册`
#### Task 2: 后端 domain + mapper(`nearby` SQL 含人数/isMember/拉黑过滤)
- [x] **Step 1: 写契约测试**(反射断言 mapper 方法存在 + XML 里 `selectNearby` 含 `im_block`、`im_conversation_member`、`6371000`)
- [x] **Step 2: 跑 → 红(文件不存在)**
- [x] **Step 3: 写 domain / mapper / XML**。`selectNearby` 核心:
- [x] **Step 4: 跑 → 绿;`mvn -q -pl chengyinhub-admin -am compile`**
- [x] **Step 5: Commit** `feat(roam): 附近的局 domain 与 mapper`
#### Task 3: IM 群:`getOrCreateHangoutGroup` / `closeHangoutGroup` + send 守卫
- [x] **Step 1: 契约测试**:反射断言三方法存在;读 `ImServiceImpl.java` 源码断言 `"hangout_"` 出现 ≥3 次且 `closeHangoutGroup` 体内含 `[id]`(行锁)。
- [x] **Step 2: 红 → 实现 → 绿**
- [x] **Step 3: Commit** `feat(im): 附近的局群聊建群/关群`
#### Task 4: `IRoamHangoutService` + `ApiRoamHangoutController`(7 接口 + 三道闸)
- [x] **Step 1: 写 Mockito 单测**(mapper/imService/security 全 mock):
- [x] **Step 2: 红 → 实现 → 绿**
- [x] **Step 3: 补一个 Controller 路由契约测试**(反射断言 7 个 mapping 值)
- [x] **Step 4: Commit** `feat(roam): 附近的局接口与三道闸`
#### Task 5: 过期任务 `RoamHangoutExpireTask`
- [x] 红 → 实现 → 绿 → Commit `feat(roam): 附近的局过期关闭任务`
#### Task 6: 小程序页 `subpackageRoam/nearby`
- [x] **Step 1: 单测**
- [x] **Step 2: 红 → 写 utils → 绿**
- [x] **Step 3: 写页面**(wxml 结构见设计 §7.1;`free-map` `scene="explore"` `map-markers="{{markers}}"` `bind:markertap`;`cy-sheet` 三种内容用 `sheet` 切;建局:`pickLocation` 选点、`wx.chooseImage`+现有 OSS 上传函数(照 roam `_uploadOne`)、提交 `POST /create` 成功后 `navigateTo` 群聊页 `/subpackageB/pages/im/chat/index?conversationId=&type=4&name=`)
- [x] **Step 4: `node scripts/uiaudit/build-route-matrix.js`(刷新路由矩阵)+ `npm run lint` + `node ci/silent-error-gate.js`(若新页有 silentError 需登记)+ `node ci/api-existence-gate.js`**
- [x] **Step 5: Commit** `feat(xcx): 漫游附近的局页`
#### Task 7: 漫游首屏入口卡
- [x] 红 → 实现 → 绿 → `npm run test:unit` 全绿 → Commit `feat(xcx): 漫游首屏附近的局入口`
#### Task 8: 收尾
- [x] `mvn -q -pl chengyinhub-admin -am test` 全绿;`npm run test:unit` + `npm run lint` 全绿
- [x] `/code-review`(禁肉眼)
- [x] 设计文档 §10 打勾;`/ship` 时按分类标 ①③② 三类,说明「H1 迁移合并前先落库」

## Source: 城瘾vault/02-待部署/漫游附近的局_玩家自组局_系统设计与TODO_20260905.md

### 0 元信息
| Figma 游戏化重设计([number] 拍板 B骨A皮) | 同文件新页「漫游·附近的局 · 游戏化重设计(B骨A皮) · 20260905」<[private Figma link]>:语言层(色板 / 局气泡 LOD 组件 near·far·activity·player / chip / 主键)+ S01 地图 · S02 空态探半径 · S03 看列表 · S04/05/06 局卡片路人·已在群·局主 · S07/07b 建局与校验错 · S08 漫游首屏入口卡 · S09 加入成功。**不套小程序 cy-* 规范**;色值取自 MAP_AVATAR_COLORS(青 #4FD3D0 / 琥珀 #E7A84B / 粉 #D77BB4 / 面板 #132A2E / 奶油 #FFF
| Figma 实拍全景 | 主稿 `ku2oaN9ag1XUMC9lKNnrcr` 新页「漫游·附近的局 · 实拍全景 · 20260905」<[private Figma link]>:19 块 = A 地图 4 / B 列表与卡片 6 / C 建局表单 4 / D 原生弹窗 3 / E 入口与落点 2,每块标 wx:if 原文;D3 举报 actionSheet 是微信原生层 automator 拍不到,放的是触发前卡片。driver 副本 `assets/_shot_roam_hangout_pano_20260905.js` |
#### 1.2 待拍板(文档按「默认」写,拍板不同再改,不阻塞施工计划)
| P4 | 局群人数上限 | **200** | 50 | 微信群感受;im_conversation_member 无上限约束,要在 join 里闸 |
### 2 产品参考:TripBFF 长什么样
| 5 | 拉近地图,气泡带文字标签 | `<map>` marker 的 callout(漫游已用) |
| 8 | 点气泡 → 卡片:封面 / 标题 / 13 members / 六个头像 / **Join chat** 👋 / Maybe later | 局卡片,主 CTA = 进群 |
| 9 | 进群后回地图 | 群聊页 = 现有 `subpackageB/pages/im/chat` |
### 3 现码积木盘点(每条带出处,可复核)
| 地图头像气泡 + 文字标签 | 漫游 `_syncMarkers`:商家/NPC 头像做圆框 iconPath,`callout` 常显 | `chengyinhub-xcx/pages/roam/index.js:1514-1656` | 局 marker 走同一条链,cat=`hangout` |
| 按半径查点 | `/api/map/nearby` haversine `6371000*acos(...)`,半径上限 50km,limit 上限 200 | `ApiMapController.java:53-96` + `ApiMapMapper.xml:23` | 抄 SQL 骨架换表 |
| 活动画到地图 | searchmap 页 `createMarkersFromActivities`,无坐标不落假点 | `pages/searchmap/index.js:489` | 规则照抄:**无坐标不画** |
| 群聊页 | `/subpackageB/pages/im/chat/index?conversationId=&type=4&name=` | `pages/club/detail/index.js:2044` | 直接跳 |
| 选位置 | 漫游 `chooseLocationFromTencent` → `pickLocation` 封装 | `pages/roam/index.js:3346` | 建局落点复用 |
| 漫游首屏入口卡 | `_loadIntroTopics` 生成 `introCards`,没报名时回落两张入口卡 | `pages/roam/index.js:483-508` | 加一张「附近的局 · N 个进行中」 |
### 8 审核、治理、安全
| 局主注销账号 | 复用 deregister 流程里 club 的处理:局转关 | 查 `pages/deregister` 对应后端 |
#### 9.1 验收(按代码实况打勾,不按记忆)
- [x] 迁移落库:生产 `information_schema.tables` 有 `roam_hangout`;`sys_job` 有 `roamHangoutExpireTask` 且 status=0
- [ ] `nearby`:真库两个局 + 一个带坐标活动,3km 内回 3 条、100m 内回 0 条且带 `suggestedRadius`(半径 + 探半径都生效);拉黑局主后该局消失
- [ ] `create`:标题塞违规词 → 返回「标题含违规内容」而不是 500;第 4 个局 → 「同时最多开 3 个局」
- [ ] `join` 幂等:连点两次同一 conversationId;第 201 人 → 「群已满」
- [ ] 小程序:automator `callMethod` 喂 3 个 fixture 局 → marker 数 = 3;点第一个 → sheet 标题一致(memory `wechat-miniprogram-verify`)
- [ ] 过期任务:手改一条 `start_at` 到昨天 → 30 分钟内 status=1、群只读
### 10 施工批次(可勾选 · 每批一个 PR · 可单独回滚)
| **H3** | 小程序:`subpackageRoam/nearby` 一页三态 + 建局表单 + 漫游首屏入口卡 + fixture + automator 断言 | ② 微信上传 | H2 部署 |
- [x] H1 迁移写好并本地 `migration_layout` 门禁绿([number])
- [x] H1 生产落库 + `information_schema` 回读
- [x] H2 后端 + 单测,`mvn -pl chengyinhub-admin -am test` 绿([number],872 报告零失败;含 /code-review 后补的审核台处置 / 注销关局 / 破环)
- [x] H2 `/ship` 已开 PR <https://github.com/liboyang42-cpu/chengyin/pull/1035>([number],已 merge 最新 master;/code-review 两轴 finding 全部修:活动档期入 SQL / 已关局不被举报复活 / MSG_BUSY / 详情要登录 / 群访问只查状态 / danger-confirm / 时间角标 / 清死字段);push 后 master 又合了 #1033/#1034(toast/modal 收口),二次 merge:页内 toast 改走 utils/toast,举报回执改成卡片上的「已举报」界面状态(成功 toast 棘轮只减不增)
- [x] H2 CI 7/7 绿 → 合并 → `verify-deployed.sh` 绿 → `audit_sys_job.py` 对账(ship 时本地未设 `CHENGYIN_DB_PASSWORD`,对账没跑)
- [x] H3 小程序代码完成(unit 5064 绿 · lint 绿 · xcx-check 绿);automator 六态截图已出(`~/Desktop/hangout-shots/`)
- [x] H3b **v2.1 设计落码**([number],commit 81c08fda3 + 55ad77651):三个 sheet 纯黑(`--cy-comp-sheet-bg: var(--cy-color-play-page)`)、常驻 peek 面板取代 FAB、玻璃定位钮、图例、`utils/roam-hangout-marker.js` 离屏 canvas 按七类角色规范画 marker(个人圆环 / 商家方框店招棚 / 限时活动粉框;青已加入 / 金商家 / 灰已满 / 奶油个人;LOD ≤300m 头像否则角色色远距点);tokens.wxss 补 `--cy-play-role-*`。unit 5069 绿 · lint 绿 · xcx-check 绿 · ds-hardcode 绿。七态实拍 `~/Desktop/hangout-shots-v2/`(driv
- [x] H3c **按 Figma 逐屏对齐**([number] 用户「你做的和 figma 上的不一样」后并排比对 S01/S02/S03/S04/S04b/S07 修):去掉页标题只留小注胶囊;「我」青环头像 marker + 300 m 淡青圈;图例挂在 peek 上沿;peek 副标「最近的一局 350 m · 3 人已加入」;行副标「今晚 8:00 · 地点 · 距离」;marker 角标=人数(已加入青/已满灰「满」),商家局右下红徽 + 金色名牌「商家局 · N 人」,限时活动粉名牌倒计时;卡片顶行「● 进行中 · 120M · 今晚 8:00」/「● 商家局 · 店名 · 800M」,成员写名字,主键「加入」,打开卡片地图停到该局;建局表单改分组行内输入 + 顶部「别人在地图上看到的样子」预览;空态进 peek 面板(还没有局 / 看远一点 / 或者,在这里开一局)
- [x] H3d **地图纳入已发布主题 + 弹窗纯黑**([number] 用户「不仅是漫游,发的城市定向、自由探索、活动出现在这个地图上就好;弹窗要纯黑不是透明的」):`CmsTopicMapper.selectNearbyTopics`(公开口径同 selectPublicCmsTopicList,按第一个有坐标节点落点,吐 productType/ownerRole)→ nearby 多一类 kind=topic;小程序 marker id*10+3、海报卡框色按发布者(商家金 / 玩家奶油)、铭牌写「定向/探索」、列表 chip「城市定向/自由探索」、点开进主题页;「附近 N 个局」数全部能去的。弹窗:cy-sheet 玻璃档在组件内自设 `--cy-comp-sheet-bg`,页面覆盖它无效,要覆盖 `--cy-comp-sheet-role-glass` 为 `--cy-
- [x] H3e **可交互 HTML 原型**([number] 用户「设计还是不好看，没有苹果设计风格，做成 html 加上动效」):<[private artifact link]>,离线副本 `assets/hangout_v2_prototype_20260906.html`。内容:程序生成的黑底描线地图(答「买不起个性化 subkey 之前它长什么样」)、七类角色点位、可拖拽三档半屏面板(跟手 + 越界橡皮筋 + 按速度回弹 + 地图视差压暗)、选中让位、限时活动真倒计时、建局时地图上的实时预览、开局后点位弹落。动效曲线:面板 `cubic-bezier(.32,.72,0,1)`,点位与按压 `cubic-bezier(.16,1,.3,1)` 指数减速(不回弹,回弹是 web 味不是 i
- [x] H4 **漫游改成「两种玩法」的页面重构稿([number],用户提出)**:Figma 页「漫游 · 两种玩法(组局 / 迷雾) · 20260907」node **5075:13150**(文件 ku2oaN9ag1XUMC9lKNnrcr)。
- [x] H3h **点位体系定稿([number])**:只留白与红两色,形状承担全部类型区分。人=白描边圆头像 · 商铺=方块+红白店招棚(棚宽出方块、下缘更宽) · 城市定向=黑白方格终点旗 · 自由探索=素白三角旗 · 限时活动=素白方旗+红色走字倒计时牌 · 我=实心点+白环+柔光晕 · 据点=中性小圆徽 · 更远只是点。点击泛涟漪并抬起。商家九品类不进地图颜色、进列表文字。定义书 <[private artifact link]>
- [x] H3g **原型三版 · 照 Pangea Charging 重做点位**([number] 用户「看不出来商家了、棚子很好、先参考其他 app」):参考图存 `assets/ref_pangea_*.png`。三条落地——①填充比描边强(暗底细环那版商家会消失);②每个点位加尖角,才是地图对象不是贴纸;③定主次:**商家最响**(红白店招棚回归 + 金框 + 更大)> 限时活动(粉框 + 铭牌走字倒计时)> 玩家局/主题(安静暗底)> 远距点。选中态抬起 4px 并放大。列表头像与地图同源,商家行也戴棚子。
- [x] H3f **原型二版 · 收颜色**([number] 用户「很塑料、AI 味重、不高级」):一屏只让颜色出现两三次;环退 1px 且只标状态(已加入青 / 限时粉);商家雨棚收成底边一根金线;角标由彩色贴纸改灰字;名牌只给最近三个;**删图例**(需要图例解释的颜色编码就是编码失败);chip 改「小圆点 + 文字」;行间发丝线不做卡片;饱和度整体降一档。
- [ ] H3 微信上传
- [x] 本文档移 `03-进行中`([number] 开 PR #1035 时,施工计划与 assets 一并移)
- [ ] → `02-待部署` / `01-已上线`(三闸全过才 01:③迁移落库 · ②微信上传 · 部署观测)

## Source: 城瘾vault/02-待部署/自由探索App同步_批1实施计划_20260909.md

#### Task 1: 模型扩四个字段 + 章节表
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红**
- [x] **Step 3: 写最小实现**
- [x] **Step 4: 跑测试确认它绿**
- [x] **Step 5: 跑全量,确认没碰坏既有解析**
- [x] **Step 6: 提交**
#### Task 2: 六宫格排布的几何(纯函数)
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红**
- [x] **Step 3: 写最小实现**
- [x] **Step 4: 跑测试确认它绿**
- [x] **Step 5: 提交**
#### Task 3: 分段圆弧进度环(几何纯函数 + Painter)
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红**
- [x] **Step 3: 写最小实现**
- [x] **Step 4: 跑测试确认它绿**
- [x] **Step 5: 提交**
#### Task 4: 屏① 通行证首屏
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红**
- [x] **Step 3: 写实现**
- [x] **Step 4: 跑测试确认它绿**
- [x] **Step 5: 提交**
#### Task 5: 按 mode 分支接进 PlaySessionPage + golden
- [x] **Step 1: 写 golden 测试**
- [x] **Step 2: 跑测试确认它红(还没有基准图)**
- [x] **Step 3: 生成基线并**人眼看图
- [x] **Step 4: 在 PlaySessionPage 里加分支**
- [x] **Step 5: 跑全量测试**
- [x] **Step 6: 静态检查**
- [x] **Step 7: 提交**

## Source: 城瘾vault/02-待部署/自由探索App同步_批2a实施计划_20260909.md

#### Task 1: 把三步判据与显示态抽成可测的纯函数
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红**
- [x] **Step 3: 写最小实现**
- [x] **Step 4: 跑测试确认它绿**
- [x] **Step 5: 提交**
#### Task 2: 最小卡片详情页(章节头 + 到店三步 + 主 CTA)
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红**
- [x] **Step 3: 写实现**
- [x] **Step 4: 跑测试确认它绿**
- [x] **Step 5: 提交**
#### Task 3: 接线 —— 屏① 进详情,详情驱动现场三步
- [x] **Step 1: 先跑基线,记下必须保持的数字**
- [x] **Step 2: 写失败测试**
- [x] **Step 3: 跑测试确认它红**
- [x] **Step 4: 实现接线**
- [x] **Step 5: 跑接线测试**
- [x] **Step 6: ★跑那条守卫,必须仍是 7/7**
- [x] **Step 7: 全量 + 静态检查**
- [x] **Step 8: 提交**

## Source: 城瘾vault/02-待部署/自由探索App同步_批2b实施计划_20260909.md

#### Task 1: 转角状态机(纯函数)
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红**
- [x] **Step 3: 写实现**
- [x] **Step 4: 跑测试确认它绿**
- [x] **Step 5: 提交**
#### Task 2: CardBox3d widget
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红**
- [x] **Step 3: 写实现**
- [x] **Step 4: 跑测试确认它绿**
- [x] **Step 5: 提交**
#### Task 3: 接进卡片详情 + Hero 飞入
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红**
- [x] **Step 3: 实现**
- [x] **Step 4: 跑测试**
- [x] **Step 5: 全量 + 静态检查 + 守卫**
- [x] **Step 6: 提交**

## Source: 城瘾vault/02-待部署/自由探索App同步_批2c实施计划_20260909.md

#### Task 1: 模型补齐游戏段字段
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红**
- [x] **Step 3: 写实现**
- [x] **Step 4: 跑测试确认它绿,并跑全量 data 层**
- [x] **Step 5: 提交**
#### Task 2: 段② 店铺卡 + 独立导航行
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红**
- [x] **Step 3: 写实现**
- [x] **Step 4: 跑测试确认它绿**
- [x] **Step 5: 接进 `CardDetailPage`(章节段之后、到店三步之前),提交**
#### Task 3: 段③ 游戏 + 段⑤ 本店权益
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红**
- [x] **Step 3: 写实现**
- [x] **Step 4: 跑测试确认它绿;接进 `CardDetailPage`(游戏段在店铺段之后,权益段在到店三步之后)**
- [x] **Step 5: 提交**
#### Task 4: 随滚动缩进顶栏
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑测试确认它红** → `flutter test test/feature/play/card_collapse_test.dart`
- [x] **Step 3: 写实现**
- [x] **Step 4: 跑测试确认它绿;在 `CardDetailPage` 用 `NotificationListener<ScrollNotification>` 接上**
- [x] **Step 5: 提交**
#### Task 5: 屏② golden
- [x] **Step 1: 写 golden 测试**
- [x] **Step 2: 跑测试确认它红**(基准图不存在)
- [x] **Step 3: 生成基线并**人眼看图
- [x] **Step 4: 全量 + 静态 + 守卫**
- [x] **Step 5: 提交**(把两张 png 一起 add)
### 施工实况([number] 收尾补记)
| 1 | 复审 12 条:游戏段判据、duration 单位、地址消失、时区、44pt 与按钮语义等 |
| 2 | 卡盒挪出滚动流做浮层、收缩几何按样机、gameTitle 的 vm 回落 |
| 3 | **PlayChapter 三字段名与后端对不上(生产恒 null)**,fixture 全部改走 `fromJson` |
| 4 | 手势补 `hold` 转交、修掉一条假绿断言、`duration==0`、导航入口照样机 |

## Source: 城瘾vault/02-待部署/自由探索App同步_批3实施计划_20260909.md

#### Task 1: 分段构造(`story_lines.dart`)
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑,确认失败**(`函数未定义`)
- [x] **Step 3: 实现**
- [x] **Step 4: 跑,确认通过**
- [x] **Step 5: commit**
#### Task 2: 显形判定(`story_reveal.dart`)
- [x] **Step 1: 写失败测试**
- [x] **Step 2-5:** 同 Task 1 的循环(跑红 → 实现 → 跑绿 → commit)
#### Task 3: 行的三形态与进出场(`widgets/story_line_view.dart`)
| opacity | 0 | 1 |
| translateY | `1.95em`(`fromTop` 时 `-1.95em`) | 0 |
| scale | 0.78 | 1 |
| blur | 22rpx ≈ 11px | 0 |
- [x] **Step 1: 写失败测试** —— 三形态各渲一次;`shown: false` 时 opacity 为 0;`fromTop: true` 时位移取负。
- [x] **Step 2-5:** 跑红 → 实现 → 跑绿 → commit
#### Task 4: 两层粒子(`widgets/story_dust.dart`)
- [x] **Step 1: 写失败测试** —— 降级时 `AnimationController` 不启动(可断言 `tester.binding.hasScheduledFrame` 或注入的 ticker 计数为 0);粒子数按层配置。
- [x] **Step 2-5:** 跑红 → 实现 → 跑绿 → commit
#### Task 5: 页面组装(`chapter_story_page.dart`)
- [x] **Step 1: 写失败测试**
- [x] **Step 2-5:** 跑红 → 实现 → 跑绿 → commit
#### Task 6: 入口接线
- [x] **Step 1: 写失败测试** —— 点卡片进故事流;description 为空时不进、出提示;拖拽仍能翻面、竖拖仍能滚。
- [x] **Step 2-5:** 跑红 → 实现 → 跑绿 → commit
#### Task 7: golden 基线
- [x] **Step 1:** 写测试 → `--update-goldens` 生成
- [x] **Step 2:** **解码 PNG 复量**确认排版对(段距、左右边距、音频键位置与尺寸),把量到的数字写进报告
- [x] **Step 3:** 负控 —— 改掉一个排版常量,确认基线变红
- [x] **Step 4:** commit

## Source: 城瘾vault/02-待部署/自由探索游玩页_施工文档_20260907.md

#### 1.1 前端(chengyinhub-xcx)
| 卡包撕开 + 发牌弧线 + 六宫格 | `pages/play/index.wxml:280-330` | 已上线 |
| NPC 聊天组件 | `components/cy/npc-chat` | **只挂在 `pages/roam/index.json`,play 页没引** |
#### 1.2 后端
| NPC 自由追问 | `POST /api/ai/npc/chat`,闸 `feature.flag.roamNpcChat` | `ApiAiNpcController.java:140` |
### 4. 待裁决 —— 卡在这几条上,请先定
| D1 | 故事流五套配色 vs 现有五套氛围预设 | 现码是 default/night(蓝)/archive(褐)/moss(绿)/neon(紫);样机是 黑/蓝/红/黄/白。**只有蓝一套对得上** | 复用 `atmospherePreset` 这个字段,但把色板重调成样机那五套。新加一套枚举等于让商家已选的 moss/neon 失效 |
| D2 | 谁来选故事流配色 | 商家在报名时选?俱乐部在章节上选?还是按 `atmospherePreset` 自动映射 | 按 D1 走,就是章节上已有的那个字段,商家不用多做一步 |
| D3 | 主题音乐挂哪 | ① `CmsTopic` 新增 `bgmUrl` 字段(要迁移) ② 复用章节 blocksJson 的第一个音频块(不用迁移) | ②。少一次迁移,而且音乐本来就是「这一章的氛围」,不是整个主题的 |
| D4 | NPC 自由追问的闸 | `feature.flag.roamNpcChat` 现在是给漫游用的。自由探索复用同一个开关,还是新开一个 | 复用。两处都是「门店分身对话」,分开会出现一边开一边关的不一致态 |
| D5 | 白色配色下的导航栏 | `navigationBarTextStyle` 是全局的,白底黑字那套下会变成白字白底看不见 | 故事流进入时用 `wx.setNavigationBarColor` 动态切,退出还原 |
| D6 | 3D 形象接什么 | glb(要引三方库,包体成本)/ Rive(仓里已有,`chengyin-pack-rive-drag-tear` 用过 0.14)/ 先留人形占位 | 先占位上线,形象作为后续独立任务。占位已在样机里做好 |
### 5. 施工顺序
| 1 | B1 `hookText` 下发 | ①后端运行时 | 真库拉一次 `/api/play/nodes`,断言带 hookText 的节点回来的是自己那句、不是 description |
| 2 | 屏② 卡片详情五段重做 | ②小程序 | 单测锁「章节/店铺/游戏三段各自的数据来源不串」;模拟器实拍五段 |
| 3 | B2 门店 NPC 摘要下发 | ①后端运行时 | 断言自玩形态(activityId=0)也能拿到 npc 对象 —— 这是最容易漏的一条 |
| 4 | 屏④ NPC 对话接线 | ②小程序 | 引 `cy-npc-chat`;实拍问候语态 / 打字态 / 加载态 / 通话态四张 |
| 5 | B3 图片块 + 音频块(编译器 → 投影 → 编辑器三步) | ①后端 + ③迁移(如果块结构要落库校验) | **负控**:造一个 image 块,确认不加投影 case 时它不下发、加了之后下发 |
| 6 | 屏③ 故事流 | ②小程序 | Canvas 粒子分层;滚动停下才显形;快滚无字;五套配色实拍 |
| 7 | B4/D3 主题音乐 | 视 D3 而定 | 常驻按钮播放/暂停可用 |
#### 7.1 六条待裁决怎么定的
| D1 | **本轮不开配色选择器,故事流恒用默认(黑)** | 施工时发现自由探索连氛围预设选择器都没有(`fabu/index.wxml:844` 是 `productType === 1` 专属)。五套配色的代码结构留着按 `atmospherePreset` 映射,自由探索接上块化路径时一行 `wx:if` 就能开 |
| D2 | 同 D1,商家不用多做一步 | — |
| D3 | ~~主题音乐不做~~ → **做了,改为「这一章的音频」** | 我先判「没有数据源」,复核时发现判错:`audioUrl`/`audioDuration` 一直随节点下发、`normNode` 也留着。自由探索一张卡就是一章一个节点,那就是「这一章的音频」。作者没配就不渲染这颗按钮 |
| D4 | ~~复用 `feature.flag.roamNpcChat`~~ → **改为独立键 `feature.flag.shopNpcChat`,默认关** | 我先按「复用」做了,自审时发现 `NpcFeatureFlags.chatOn()` 是**硬编码 false** 的合规闸,注释明写「无形陪伴 V1 不提供自由追问……将来若另立 Chat 合规项目,需新建开关与完整 Gate,**不能复用本基座的提示层开关**」。挂上去两个后果:①这条链路永远开不了,门禁全绿、接口存在、玩家永远 403 ②哪天为漫游放开会把门店分身一起放开,而两者合规评估不是同一件事。已改独立键并加契约测试 + 注入负控 |
| D5 | 故事流用页面自绘深色层,不动 `navigationBarTextStyle` | 白色配色本轮没上,不需要动全局导航栏 |
| D6 | ~~人形留白占位~~ → **真做了一个低模 3D 人形** | 我把「3D 形象」等同于「得有人给我一个模型文件」,这是错的。几何可以直接生成:头 + 躯干 + 肩 + 脖 + 两条手臂,约 200 顶点 340 面,自己算投影、背面剔除、画家算法与平面着色,canvas 2d 画得动,不用 glb、不用 Rive、不用把 three.js 塞进包体 |

## Source: 城瘾vault/03-进行中/App上线交接_20260819.md

### 一、你现在要做的四件事(按最短路径排)
| 1 | **Android 签名证书** | 跑下面那条命令,密码自己定 | **5 分钟** | keytool 的完整输出 |
| 2 | **微信移动应用 appid** | 微信开放平台申请「移动应用」 | 1-3 天 | appid(形如 wx1234...) |
| 3 | **域名 ICP → App 备案** | 工信部,挂在 www.chengyinhub.com 下 | ~20 工作日 | 备案号 |
| 4 | **企业开发者账号** | Apple,需 D-U-N-S 编码 | 1-2 周 | 账号可用即可 |
### 二、备案「特征信息」要填的值(已核实,可直接抄)
| 安卓公钥 / 证书 MD5 | 待第 1 件完成后由我提取 |

## Source: 城瘾vault/03-进行中/App对齐小程序_交接_20260916.md

### 1. 硬规则(违反任一条都会出事)
| R7 | 外观一律 **iOS 27 原生**(规则手册 `docs/ios27-design-language.md` + `AGENTS.md`,已在 main);对齐对象是**结构**:页面/入口/字段/文案/接口/状态/业务规则 1:1 跟小程序。地图(D7)、消息页(D9)是 App 独有体验,不追小程序外观 | 决策 D7/D8/D9/D10 |
### 2. 基线读数([number] 记录 / **[number] 本机复跑**)
| **manifest 自洽性(新)** | 113 条落点的 `source` 文件 + `marker` 类名**全部存在**(唯一例外 `pages/crop/index`,是文档写明的平台例外) |
### 3. 已完成(已合入 App main)
| #43 | 结构对照台 `tool/visual_parity/`:静态解析小程序 wxml 区块/按钮/状态分支/文案/接口 ↔ App 页面,**不截图、不用 automator**(已核合入版 `build_review.py` 与 README),外观差异默认 accepted | Task 0.3(按 R1/D8 改造) |
| #45 | 重写 `AGENTS.md` + `docs/ios27-design-language.md`(规则来源、降级表、35 行对照表、共用层 30 组件分批 P0–P4、原生桥 B1–B4),已按 D10 更新 | Task 2.1 扩展 |
| #46 | 定位 + `MKDirections` 路线规划 + App 内分步导航 + 一键交给 Apple 地图 | Task 1.5 / D7 |
#### 4.2 没开 PR 的半成品分支
| `liboyang42-cpu/p4-club-crm` | 同上 | 俱乐部客户列表/详情、签到详情、结算页 + manifest 登记。`/api/club/settlement/withdraw` **故意未封装**(见 R10) | ⚠️ | 线 6(W2) |
#### 5.1 页面(小程序 130 页)
| `pages/club/topic-detail/index` | **无人** | 线 16(W6) |
| `pages/club/topic-story/index` | **无人** | 线 16(W6) |
| `pages/merchant/predict/index` | **无人** | 线 9(W3) |
| `pages/coop/invite-detail/index` | **无人** | 线 9(W3) |
| `pages/club/customers/index` · `customer-detail` · `checkin-detail` · `settlement` | p4-club-crm ⚠️ | 线 6(W2) |
| `subpackageRoam/nearby/index` · `citystamp` | p4-roam-social ⚠️ | 线 3(W1) |
| `pages/team/detail/index` · `team/join` | parity/team 已有路由 `/team/:teamId` `/team/join`,**漏登记 manifest** | 线 8(W3) |
| `pages/play/circle/index` | #30 → #48 | 线 5(W2) |
| `pages/club/event-ops` · `governance` · `notify` · `roles` | #30 | 线 14(W5) |
| `pages/merchant/aftercare` · `aftercare/detail` · `reviews` · `game-node` · `customer/detail` · `team` | #30 **与** figma-confirmed 重复 | 线 4 去重(W2) |
| `pages/merchant/decor/ai-npc/index`(小程序新增) | #30 | 线 4(W2) |
#### 5.2 接口:没人做的 52 条(按域)
| club/event-ops | 13 | `attendance/correct` `cancel` `occurrence/status` `roster` `series/{create,detail,list,occurrences,update-future}` `topics` `waitlist/{cancel,join,status}` | 4-B(#30 的 event-ops 页只有壳) |
| merchant/chapter-node | 7 | `live-checkin-code` `poster-code` `npc/{detail,save}` `npc/voice/{enroll,reset,status}` | 4-C |
| team(**新功能**) | 7 | `apply` `applications` `handle` `join-mode` `my-applications` `nearby` `withdraw` | 4-D:9-15「地图组队 P 方案」,不是搬运 |
| club/topic-setting | 3 | `detail` `save` `end` | 4-B |
| club/open-settings | 3 | `member-post` `merchant-coop` `public-visible` | 4-B |
| merchant/crm | 3 | `exports` `exports/{taskId}/status` `exports/{taskId}/download` | 4-C |
| topic/chapter | 2 | `finish` `recruit` | 4-B |
| merchant/predict | 2 | `inbox` `settle` | 4-C |
| merchant/npc | 2 | `profile` `voice/status` | 4-C |
| coop/pool | 2 | `mine` `received` | 4-C |
| 其余各 1 | 10 | `club/settlement/withdraw`(**按 R10 不接**:提现改弹窗,登记为 documented equivalent)· `club/crm/topic-customers` · `club/event-notification/audience-counts` · `club/recruit/overview` · `club/topic-node-answer` · `game/session/recap/export` · `play/scan-entry` · `roam/session` | 4-B / 4-C |
#### 5.2c ★ 数据驱动的真缺口([number]:35 扫描,取代前面两张表)
| **`pages/merchant/customer/index`** | **7/8** | `crm/customers/list` · `crm/customers/tags/batch` · `crm/segments` · `crm/campaigns`(增删改查重试) · `crm/campaigns/coupons` · `crm/campaigns/preview` · `crm/campaigns/{id}/dispatch` · `crm/exports` | **★ 最大单点缺口**:小程序这一页是**整套 CRM 运营台**(分群 / 营销活动 / 批量打标签 / 导出),**1517 行**;App 的 `merchant_customer_page.dart` 只有 **176 行**,是个纯列表。导出链路 #71 在补,**分群 / 营销活动 / 标签批量
| `subpackageRoam/nearby/index` | 7/8 | `/api/team/{apply,applications,handle,my,my-applications,nearby,withdraw}` | 在途 = #75(4-D) |
| `pages/topic/merchantinfo/merchantinfo` | 5/33 | `merchant/chapter-node/npc/{detail,save}` · `npc/voice/{enroll,reset,status}` | 在途 = `parity/merchant-4c`(4-C) |
| `pages/topic/merchantinfo/merchantinfo` | 2/33 | `coop/offer/circle-supply/{pause,reconfirm-current}` | 归属未定,待核小程序调用点 |
| `pages/topic/merchantinfo/merchantinfo` | 1/33 | `circle-theme/instance/review` | 归属未定 |
| `pages/coop/list/index` | 2/10 | `coop/pool/{mine,received}` | 在途 = `parity/merchant-4c` |
| `pages/merchant/decor/ai-npc/index` | 2/8 | `merchant/npc/{profile,voice/status}` | 在途 = `parity/merchant-4c` |
| `pages/merchant/game-node/index` | 1/3 | `merchant/chapter-node/live-checkin-code` | 4-C 顺手 |
| `pages/topic/index/index` | 1/8 | `topic/beta/graduate` | 待核小程序调用点 |
| `pages/template/index` | 1/6 | `template/topic-template/list` | 待核 |
| `pages/roam/index` | 1/34 | `roam/session` | 待核(#57 im-rich-d9 那条线留下的?) |
| `pages/merchant/decor/index` | 1/13 | `merchant/commerce/order/status` | 待核 |
| `pages/publish/temp/index` | 1/10 | `ai/template/fill` | 待核(AI 填充) |
| `pages/index/index` | 1/9 | `play/scan-entry` | 待核 |
#### 5.5 非页面类未完成(按总规划 Task)
| Phase 3 iOS 27 外观重做 | **共用层 P0→P4 已完成**(#52/#56/#73);剩 B1 原生玻璃 sheet 半成品、D9 消息页(在途) |
| D9 消息页 iOS「信息」式 + 左右滑动(D10⑤) | 未开始;`chat-complete-0909` 可参考 |
| 4.1 玩法互动组件 ~30 种(playkit-*) | 未开始;D5 先出 iOS 交互稿 |
#### 6.3 线卡(分支 / 写集 / 依赖 / 模型 / 验收)
| 1 | **#47 资金改造** | `parity/account-money`(PR 已有) | `feature/account/**` `feature/money/**` | — | Opus medium | 先 rebase main 去掉 #44 原始提交(`577301f`、`f8c307e`);删提现风险确认闭环与银行卡跳转;`grep -rn "withdraw\|提现" lib` 全部改 R10 弹窗(号码常量,见 §9 待拍板 1);保留默认地址、资产明细;测试:点提现**不发任何提现请求** · 弹窗显示号码 · 「复制」写剪贴板;PR 描述写明依据 R10 |
| 2 | **p1-apple-maps 验收** | `liboyang42-cpu/p1-apple-maps` | `core/map/**` `ios/**` `pubspec` `Podfile` `android/**` | — | Opus high | 与 #46 冲突:保留 #46 的 directions/route_guidance 与 map_page 路线入口,**两者共存**;`map_platform_gate_test` 绿;`release_build_flags_test` 负控(临时加回 `amap_map` 必须红);`tool/verify_ios_arm64_simulator.sh` 输出 `IOS_ARM64_SIMULATOR_OK`;`xcrun simctl` 截图 `/map` `/roam` `/play/<id>` `/topi
| 3 | **p4-roam-social 收口** | `liboyang42-cpu/p4-roam-social` | `feature/roam/**` + roam api | — | DeepSeek | ⚠️ 未跑过 analyze;**先按 R8 审在途改动性质**;漫游约伴(nearby 的局)+ 城市纪念章 citystamp + 5 组测试;rebase → analyze + 相关测试 → 开 PR |
| 4 | **parity/merchant-ops 新建** | 新分支(从最新 main) | `feature/merchant/**` | — | DeepSeek | 售后 / 售后详情 / 口碑 / 客户详情 / 经营团队 / 游戏节点 / ai-npc **7 页**;**#30 与 figma-confirmed 二选一**(按接口覆盖数与测试完整度),另一份不带入;来源 `git cherry-pick` #30 对应 commit + `git checkout <分支> -- <路径>` |
| 5 | **parity/play-advanced 收口** | `parity/play-advanced` | `feature/play/**` | — | DeepSeek | 从 `feature/figma-confirmed-0909` 补入 `play/advanced/*` 等 **7 条独有接口**的调用链(`play/advanced/{action,leaderboard,start,state}` · `play/leaderboard` · `play/os/{topicId}` · `play/tag/{tagId}/revoke`)→ 测试 → 开 PR |
| 6 | **p4-club-crm 收口** | `liboyang42-cpu/p4-club-crm` | `feature/club/**` | — | Opus medium(资金) | 客户列表/详情、签到详情、结算页;结算页按 R10:**照常展示应得金额/结算摘要(`club/settlement/summary`),「提现」按钮 = R10 弹窗**,`/api/club/settlement/withdraw` **故意不封装**、不跳银行卡表单 |
| 7 | **B1 原生 sheet 收尾** | `liboyang42-cpu/ios27-b1-native-sheet` | `core/**` `ios/**` | 承 p1(同为 ios 写集) | Opus | 删 `lib/b1_harness_main.dart`(**非产品代码,合前必删**);Dart 回退分支单测;iOS 26+ 模拟器截图证明真玻璃/grabber/medium-large/键盘避让;关闭 10 次 deinit 计数 |
| 8 | **parity/team 收口** | `parity/team` | `feature/team/**` | — | DeepSeek | rebase → `flutter analyze` + `test/feature/team/**` → 补 manifest 登记 `team/detail`→`/team/:teamId`、`team/join`→`/team/join`(**路由已在分支里,只是漏登记**)→ 开 PR;与 `fix/activity-waitlist-review-0827` 的候补实现**比较取一**,写进 PR 描述 |
| 9 | **4-C 商家零散** | 新分支 | `feature/merchant/**` `coop/**` `game/**` | 承 #4 | DeepSeek | `merchant/predict` `coop/invite-detail` 两页 + chapter-node 7 + crm/exports 3 + predict 2 + npc 2 + coop/pool 2 + game/session/recap/export + play/scan-entry + roam/session |
| 10 | **§5.4 广场回归核查** | 只读,不开分支 | — | — | DeepSeek | 结论三选一:**等价替代 / gate 关时丢功能 / 无法判定**;不得停在「待核」 |
| 11 | **4-D 地图组队(新功能)** | 新分支 | `feature/team/**` | 承 #8 | DeepSeek | team apply **7 条**,按 9-15「地图组队 P 方案」:公开队伍可申请;满员/进行中/解散/审核中不显示;申请 24h 或活动结束失效;被拒不能再申;Figma `txQoyVyK 590:1014`。**先读小程序与后端 master 实现,不是 1:1 搬旧页** |
| 12 | **消息页 D9** | 新分支 | `feature/im/**` | — | Opus medium | 手册 §3.9 与 IM2:iOS「信息」式会话列表 · 会话行左右滑动(置顶/已读/删除,删除走 `cyConfirm`)· 长按菜单一致;`feature/app-chat-complete-0909` **只作参考**,逐文件判断取舍;**允许比小程序更丰富**(用户 09-17,见 §9) |
| 13 | **主题编辑器浅色** | `liboyang42-cpu/p2-topic-editor-light`(空分支) | `feature/**topic*` | — | Opus medium | 决策 D10⑥ |
| 14 | **parity/club-ops 新建** | 新分支 | `feature/club/**` | 承 #6 | DeepSeek | `club/event-ops` `governance` `notify` `roles` **4 页**(来自 #30);#30 的 event-ops 只有壳,壳不算完成 |
| 15 | **小分支收口 3 条** | 各自 worktree | 分散 | — | DeepSeek | `feature/merchant-network-mvp-0910`、`pr/community-post-completion-0912`、`fix/creator-reapply-receipt-0825`:各自 rebase → 相关测试 → 开 PR;**内容已在 main 等价存在的不开**,写证据;`fix/creator-reapply-receipt-0825` 落后 main 30 |
| 16 | **4-B 俱乐部主题运营** | 新分支 | `feature/club/**` | 承 #14 | DeepSeek | `club/topic-detail` `club/topic-story` 两页 + event-ops 13 + topic-setting 3 + open-settings 3 + topic/chapter 2 + recruit/overview + topic-node-answer + event-notification/audience-counts + crm/topic-customers。⚠️ **俱乐部线生产从未被真人走过**,只能单测覆盖,PR 描述注明「上线前需真号冒烟」 |
| 17 | **裁判立基线** | `tool/` | `tool/**` | 全部域线合并后 | DeepSeek | `EXPECTED_XCX_PAGE_COUNT = 130`;删 §5.1 的 7 条消失页;未落点页登记 `kind: gap`(priority/phase 按 §5.1 归属);`GAP_BASELINE` = 实测数;负控(**删一条 gap 必须 exit 1**);顺带把 §2 读数表更新进总规划 §基线读数 |
| 18 | **#30 收尾** | 总控旁路 | — | W3 后 | — | 观测 `git diff origin/main origin/feature/parity-missing-pages-0909 --stat -- lib test \| tail -1`,残留文件逐个标「丢弃理由 / 补进哪个 PR」,**不许默认丢**;然后 #30 评论列去向 → `gh pr close 30`(不删分支) |
#### 11.[number]:00–10:40 CST:三笔合并 + #78 修饰 + 下一波 6 条
| `coop/offer/circle-supply/pause` | `pages/topic/merchantinfo/merchantinfo.js` | ⛔ **§10 主题世界线,已暂停 —— 不要推进** |
| `topic/beta/graduate` | `pages/topic/index/index.js` | ⛔ 同上 |
| `merchant/commerce/order/status` | `pages/merchant/decor/index.js` | ✅ **真缺口**(商家装修域,与 CRM 线同域,派活时要么并进 CRM 线要么错开文件) |
| `ai/template/fill` | `pages/publish/temp/index.js` | ✅ **真缺口**(发布器 AI 模板填充,与帖文发布器同域,注意和帖文线错开文件) |
| `play/scan-entry` | `pages/index/index.js:393`(门店码 scene 1047/1048/1049) | ⛔ **不接**:等价物是「扫门店码→深链进 App」,码的载体(Universal Link / 扫码器)与发行是上线决策,客户端单方面接不掉 |

## Source: 城瘾vault/03-进行中/App对齐小程序_总规划_20260914.md

### 0. 决策记录(已拍板,执行时不再讨论)
| D1 | **Android 暂不管**。Android 上地图组件直接走「地图暂时不可用」降级,不维护双实现 | 用户 [number] |
| D2 | **地图换 Apple Maps**(iOS),整体移除高德 SDK | 用户 [number] |
| D3 | **不换 SwiftUI 重写**,继续 Flutter。上架后再按具体屏评估 | [number] 建议,用户转入规划 |
| D4 | **不走 Figma → Claude Design → 代码**。小程序即设计稿;Figma 手册只承载「代码表达不了的规则」,颜色/间距真源仍是 `chengyinhub-xcx/style/tokens.wxss` | 同上 |
| D5 | Claude Design 只用于**不该 1:1 搬、要按 iOS 重做交互**的部分(玩法小组件) | 同上 |
| D7 | **地图是 App 独有的 Apple 原生体验,不 1:1 跟小程序**:Apple Maps 底图 + 定位(蓝点/跟随/朝向)+ **真实道路路线规划**(MapKit `MKDirections`,步行默认,可切驾车/公交,距离与 ETA)+ **路线导航**(App 内分步引导 + 偏航重算,一键「在地图中打开」交给 Apple 地图)。小程序只有 `wx.openLocation` 和节点直线连线,视觉对照里地图相关差异一律 accepted | 用户 [number] |
| D8 | **全 App 采用 iOS 27 设计语言**,范围 = 系统层(导航栏/Tab Bar/Sheet/菜单/搜索/工具栏/弹窗)+ 列表与表单(设置/我的/订单/表单页用 iOS 分组列表、原生开关与选择器)+ 玩家内容页(首页流/活动详情/玩法页的材质与排版,品牌视觉随之调整)+ 商家后台全部原生。**对齐的对象从「像素」改为「结构」**:页面、入口、字段、文案、接口、状态(空/加载/错误/权限)、业务规则 1:1 跟小程序;外观与交互一律 iOS 27 原生。视觉对照台(0.3)用于核「结构/信息是否一致」,外观差异默认 accepted(注明「iOS 27 原生化」)。**覆盖 D6②**(Liquid Glass 不再只限系统层,按 iOS 27 HIG 使用)。Phase 3 相应改为「按 iOS 27 规则手册重做外观 + 结构对照」 | 用户 [number]
| D9 | **消息页 App 就该与小程序不同**:做成 iOS「信息」式原生体验,不 1:1;视觉/交互差异全部 accepted;会话数据与接口仍以后端为准 | 用户 [number] |
| D10 | **iOS 27 手册拍板(PR #45 §7 七问)**:① 商家后台**恒浅**,不跟随系统 ② 玩家**恒暗**保留,token 补齐浅色值 ③ **要真玻璃**:立项原生桥 **B1 `native_flutter_sheet`**(UISheetPresentationController 承载 Flutter 内容);B2 滚动联动大标题**不做**(随 ④)④ 一级页**不改**导航栏大标题,`CyPageTitle` 保留(撤销手册 P2「替换」项)⑤ IM 列表**加**左右滑动操作(置顶/已读/删除),属 D9 批次 ⑥ 主题编辑器**浅色**保留(Task 2.2 照做)⑦ Global Constraints 已同步 | 用户 [number] |
| D6 | Brand Handbook 规则:① 小程序原结构 + Apple 原生 UI/UX,不重新设计 ② Liquid Glass 只用于 Tab Bar、Sheet、Menu 与悬浮系统层 ③ 角色外观:玩家=暗色、商家=浅色、主题编辑器=浅色 | Figma 封面 |
#### 1.3 功能缺口(四路审计汇总,静态 grep 所得,❌ 可信、✅ 只代表接口接上)
| 玩家核心 | 17 | 9 | 2(+ ~30 个玩法组件) |
| 发布 / 会员 / 资产 / 设置 | 25 | 8 | 0 |
| 商家 + 主题 | 15 | 7 | 7 |
| 俱乐部 / 合作 / 组队 / 广场 | 18 | 3 | 12 |
#### 1.3b 含在途分支的真实缺口([number] 预读,Task −1.5 合并后再正式重算)
| 接口 | 155 | **56 条没人做** | #30 独有补 41 条;#39 / figma / chat / reapply / mnet / waitlist / polish 独有 0;party 独有 1(`team/my`) |
#### 2.1 标准单页循环(所有 Phase 3/4 任务都按这 8 步)
- [ ] **S1 读真源**:`git -C ~/Downloads/chengyin show github/master:chengyinhub-xcx/P.{wxml,wxss,js,json}`,以及它引用的组件。⚠️ 永远读 `github/master`,不读工作区([number] 因工作区落后 4 commit 下错结论)。
- [ ] **S2 查已有判定**:`test/endpoint_reachability_test.dart` 的 `kKnownUnreachable`、`test/blocked_by_backend_test.dart`、`tool/page_parity_manifest.json`。**已判过的不重复做**([number] 派出 19 条里 18 条已有判定)。
- [ ] **S3 列清单**:该页的 接口(按 `endpoint_parity.py` 口径)· 状态(normal/empty/loading/error/…,对照 `shot-matrix.js` 里该页的行)· 文案 · 交互入口。
- [ ] **S4 写失败测试**:golden(按 shot-matrix 同一 fixture 数据)+ 行为测试(按钮 → 调哪个 API)。跑一次确认红。
- [ ] **S5 实现**:按 `AGENTS.md` 对照表翻译;控件用 Cupertino / 原生,禁 Material 控件(已有门禁 `no_material_*_test.dart`)。
- [ ] **S6 过裁判**:`flutter analyze` 零警告 · `flutter test` 相关用例绿 · `python3 tool/page_parity.py` / `endpoint_parity.py` / `copy_parity.py` 该页不再报 · `manifest` 登记。
- [ ] **S7 视觉对照**:`python3 tool/visual_parity/build_review.py --only <shotId>` 生成左右对照页,Claude 读两张图列差异 → 修 → 重生成,直到差异只剩「有意的 iOS 原生化」并在 pairs.json 的 `accepted` 里写明。
- [ ] **S8 登记 + 提交**:更新 `tool/page_parity_manifest.json`(gap→route)、`tool/visual_parity/pairs.json`、本文档对应勾;commit(pathspec)。
#### Task −1.1: 给所有脏 worktree 做无侵入快照(不改工作区、不碰 stash 栈)
- [ ] **Step 1: 刷新盘点**
- [ ] **Step 2: 对每个 `脏 > 0` 的 worktree 做快照分支**(用临时 index,工作区、真实 index、stash 栈都不动;包含未跟踪文件,遵守 .gitignore)
- [ ] **Step 3: 观测** —— 每个快照 `git diff --shortstat HEAD <快照>` 的行数应与 Step 1 的 `git -C <wt> diff --shortstat` 同量级(快照多出未跟踪文件);`git -C <wt> status --porcelain | wc -l` 与快照前**相同**(证明工作区没被动)。
- [ ] **Step 4: 推备份**:`git push github 'refs/heads/wip-snapshot/*:refs/heads/wip-snapshot/*'`,再 `git ls-remote github 'refs/heads/wip-snapshot/*'` 回读确认条数。
#### Task −1.2: 先合三个小 PR(#41 → #35 → #39)
- [ ] `gh pr view 41 --json mergeable,statusCheckRollup` 复核仍绿 → `gh pr merge 41 --squash --match-head-commit <合前 headRefOid>`
- [ ] #35:在新 worktree `git fetch github && git switch -c fix/disabled-button-fg github/fix/disabled-button-fg && git rebase github/main`,解冲突 → `flutter analyze` + `flutter test --exclude-tags needs-local-env` → push `--force-with-lease` → CI 绿 → squash 合
- [ ] #39:同上;冲突多半在 `lib/feature/play/` 与 #38 之后的改动
- [ ] 每合一个都重查剩余 PR 的 mergeable(合并会把干净 PR 顶成冲突)
#### Task −1.3: 拆分并落地 #30
- [ ] **Step 1: 分清未提交部分是什么** —— 在快照分支上 `git diff --stat HEAD wip-snapshot/parity-missing-pages-[number] -- lib | sort -k3 -rn | head -40`,按 `lib/feature/<域>` 归类;`artifacts/`、`assets/home/*`(未跟踪图片)判断是否属于小程序资源搬运。
- [ ] **Step 2: 去重** —— 以下与已合 / 先合的 PR 重叠,**以先合的为准,从 #30 里丢弃**:
- [ ] **Step 3: 按域重开 PR**(每个都从最新 `github/main` 建分支,`git cherry-pick` 对应 commit + 从快照分支 `git checkout <snapshot> -- <该域路径>` 带入未提交部分):
- [ ] **Step 4**: 每个新 PR 走 CI;全部合并后关闭 #30(评论里列出去向),回收其 worktree。
- [ ] **Step 5: 观测** —— `git diff github/main wip-snapshot/parity-missing-pages-[number] --stat -- lib | tail -1` 剩下的就是「没被任何新 PR 带走」的改动,逐文件判定「丢弃 / 补进某 PR」,不许默认丢。
#### Task −1.4: 回收与主 checkout 归位
- [ ] 从主 checkout `~/城瘾app/app` 执行;对每个待回收 worktree 核四条:PR state=MERGED(或已判定废弃)· 快照分支已推远端 · `status --porcelain` 为空或已快照 · 用户确认无活会话。四条全过才 `git worktree remove`。
- [ ] 主 checkout:快照已推 → `git -C ~/城瘾app/app switch main`(工作区有改动会拒绝,此时 `git restore -SW .` 前**再次确认快照分支存在于远端**)。
- [ ] theme-world:`git push github liboyang42-cpu/theme-world-app-party-0910` 备份顶端 → 回收 6 个祖先 worktree。
- [ ] 回收完 `git worktree list | wc -l` 记录进本文。
#### Task −1.5: 在新 main 上重算缺口
- [ ] 重跑 `page_parity.py` / `endpoint_parity.py`,把真实数字写回 §1.2、§1.3,并**改写 Phase 4 清单**:在 −1.3 已落地的条目前打 ✅ 并注明 PR 号。Phase 0 Task 0.2 的 `GAP_BASELINE` 用这里的真实 gap 数,不再用 23。
#### Task 0.1: 修复 `copy_parity.py` 崩溃
- [ ] **Step 1: 写失败测试**
- [ ] **Step 2: 确认红**
- [ ] **Step 3: 最小修复** —— `EXEMPT` 的语义在 `d1a37c8` 后由 manifest 里 `kind == "system"` 的条目承载:
- [ ] **Step 4: 确认绿**
- [ ] **Step 5: 负控** —— 临时把 `exempt` 改回 `P.EXEMPT` 跑一次必须红,再改回。
- [ ] **Step 6: Commit**
#### Task 0.2: page manifest 升到 130 页,缺口显式登记为 `gap` 并加 ratchet
- [ ] **Step 1: 写失败测试**(追加到 `test/page_parity_test.dart` 的 `main()`)
- [ ] **Step 2: 确认红**
- [ ] **Step 3: `_validate_bindings` 增加 gap 分支**(放在 `if kind == "system":` 之前)
- [ ] **Step 4: 更新 manifest** —— 删除 `pages/club/edition-report/index`、`pages/merchant/discover/index`、`subpackageTalent/search/index`、`pages/publish/biaoqian/biaoqian`、`pages/club/dissolution-blockers/index`、`subpackageP3/pages/creator/index/index` 六条;追加 23 条,priority/phase 按下表:
| pages/team/detail/index · pages/team/join/index | P0 | 4.1 |
| pages/merchant/aftercare/index · pages/merchant/aftercare/detail/index | P1 | 4.2 |
| pages/merchant/team/index · pages/club/roles/index | P1 | 4.2 |
| pages/club/settlement/index | P1 | 4.2 |
| pages/club/governance/index · pages/club/notify/index · pages/club/event-ops/index · pages/club/customers/index · pages/club/customer-detail/index · pages/club/checkin-detail/index | P2 | 4.3 |
| pages/merchant/reviews/index · pages/merchant/customer/detail/index | P2 | 4.3 |
| pages/club/topic-detail/index | P2 | 4.3 |
| pages/merchant/game-node/index · pages/merchant/predict/index | P3 | 4.4 |
| pages/play/circle/index · pages/club/topic-story/index | P3 | 4.4 |
| subpackageRoam/nearby/index · subpackageRoam/citystamp/index · pages/coop/invite-detail/index | P3 | 4.4 |
- [ ] **Step 5: 确认绿 + 负控**
- [ ] **Step 6: Commit**
#### Task 0.3: 视觉对照台(小程序截图 ↔ App golden 配对)
- [ ] **Step 1: 采集小程序全量截图**(在小程序仓,不改其代码)★ 09-17 本机注:**已作废**——R1 禁截图矩阵且 `~/Downloads/chengyin` 不存在;跳过本 Step。
- [ ] **Step 2: 写 `build_review.py`**
- [ ] **Step 3: 生成 `pairs.json` 初稿** —— 从 `shot-matrix.js` 读出所有非 blocked 行,全部 `status: "todo"`,`appGolden` 先按文件名/页面人工配对能配就配,配不上填 `null`:
- [ ] **Step 4: 自检 + 生成对照页**
- [ ] **Step 5: README 写清三件事**:采集命令、配对规则(同一 fixture 数据)、`accepted` 只能写「有意的 iOS 原生化」(例:小程序自绘导航栏 → iOS 大标题导航)。
- [ ] **Step 6: Commit**(`build/` 不进仓)
#### Task 0.4: 记录首轮基线 + 开 PR
- [ ] 跑三个脚本 + 对照台,把数字填进本文 §1.2 下方「基线读数」表(日期、SHA、页面 gap、接口缺口、文案 <60% 页数、视觉 todo/diff/accepted)。
- [ ] `git push github <分支>` → `gh pr create --base main`,描述写本 Phase 所有数字。
- [ ] **本文档移到 `03-进行中`**。
| | | | 23 | 152 | | |
#### Task 1.1: Spike —— 坐标系与 API 验证(先观测,再动手)
- [ ] **Step 1: 加依赖**
- [ ] **Step 2: 写 `apple_scene_view.dart`**(保持与 `amap_scene_view.dart` 同样的 marker 状态色、围栏、轨迹线语义)
- [ ] **Step 3: 坐标观测(决定 Phase 1 能否继续的闸)**
- [ ] **Step 4: Commit(spike 可保留)**
#### Task 1.2: 所有消费方切到 `AppleSceneView`
- [ ] **Step 1: 改门禁测试(先红)**
- [ ] **Step 2: 确认红** —— `flutter test test/core/map_platform_gate_test.dart 2>&1 | tail -c 2000` → FAIL
- [ ] **Step 3: 替换**(用 serena `find_referencing_symbols` 找全 `AmapSceneView` 引用,逐个改 import `../../core/map/apple_scene_view.dart` 与类名)。`map_page` / `play_session_page` 里原来挡 `Env.hasAmapKey` 的页面级降级改成挡 `Platform.isIOS`,**保留** `play_session_page` 的隐私同意判断。
- [ ] **Step 4: 确认绿** —— `flutter analyze 2>&1 | tail -c 2000`(零警告)+ `flutter test 2>&1 | tail -c 3000`
- [ ] **Step 5: 视觉观测** —— 模拟器依次深链进入 `/map`、`/roam`、`/play/<真实activityId>`、`/topic/<id>`,各截一张,检查 marker、围栏圈、轨迹线都在。
- [ ] **Step 6: Commit**
#### Task 1.3: 选点页改为「搜索 + 点地图」,原生 `MKLocalSearch` 桥
- [ ] **Step 1: Dart 侧失败测试**
- [ ] **Step 2: 确认红** —— `flutter test test/core/map/place_search_test.dart 2>&1 | tail -c 1500`
- [ ] **Step 3: `place_search.dart`**
- [ ] **Step 4: Swift 侧**(`AppDelegate.swift` 顶部 `import MapKit`;在 `nativeTextInputAlertChannel = inputChannel` 之后追加)
- [ ] **Step 5: 改 `poi_pick_page.dart`**:顶部 `CupertinoSearchTextField` → 调 `searchPlaces` → 结果列表(`CupertinoListSection`)→ 选中后地图移到该点并显示底部确认栏;地图本体用 `AppleSceneView`,选中点作为单个 `MapPoint`。报错时显示「搜索失败,可以先跳过选点」(保留原「发布后再补上地点」的替代说明)。`_selected` 类型从 `AMapPoi?` 改为 `PlaceResult?`,确认回传结构保持原来的 name/lat/lng 字段名不变(grep 调用方 `publish_pro_page` 核对)。
- [ ] **Step 6: 确认绿 + 观测** —— 单测 PASS;模拟器进 `/publish/poi` 搜「人民广场」,截图确认有结果、点选后回到发布页地点字段已填;**把返回坐标与 Task 1.1 的已知 GCJ 节点比对,偏差 < 20 m**。
- [ ] **Step 7: Commit**
#### Task 1.4: 拆除高德
- [ ] **Step 1**: `grep -rn "amap\|AMap\|AMAP" lib test tool ios/Podfile docs pubspec.yaml 2>&1 | head -c 4000`,逐条归类「删 / 改 / 保留(map_launcher)」写进 commit message。
- [ ] **Step 2**: 按清单删改;`release_build_flags_test` 改为断言「pubspec 中不含 amap」。
- [ ] **Step 3**: `flutter pub get && cd ios && pod install && cd ..` → `flutter analyze` 零警告 → `flutter test --exclude-tags needs-local-env 2>&1 | tail -c 3000` 全绿。
- [ ] **Step 4 观测**:`tool/verify_ios_arm64_simulator.sh 2>&1 | tail -c 2000` 输出 `IOS_ARM64_SIMULATOR_OK`,且 `lipo -archs build/ios/iphonesimulator/Runner.app/Runner` 含 `arm64` —— **不再需要替身 plugin 与 pod 切换**。
- [ ] **Step 5**: 负控 —— 临时把 `amap_map` 加回 pubspec,`release_build_flags_test` 必须红;撤回。
- [ ] **Step 6**: Commit + push + PR(`--base main`),描述附 Task 1.1/1.2/1.3 的截图观测结论。
#### Task 2.1: 重写 `AGENTS.md` 的过时段落,加入翻译对照表
- [ ] **Step 1**: 删「现状(WS4.1…)」整节;「主题」一行改为「token 由 `tool/gen_tokens.py` 从小程序 `style/tokens.wxss` 生成到 `core/theme/cy_tokens.g.dart`,禁手改 .g.dart」;「地图」改为「Apple Maps(`core/map/apple_scene_view.dart`),Android 暂不支持」。
- [ ] **Step 2**: 新增「## 设计总则(Brand Handbook,Figma 5aU5V8MXZ5nPT0GtcOEEC7)」三条,原文照 §0 D6。
- [ ] **Step 3**: 新增「## 小程序 → App 翻译对照表」:
| `wx.request` / `utils/request.js` | `lib/data/api/<域>_api.dart` 方法,经 `dioClientProvider` | feature 不直接发 http |
| `wx.navigateTo({url:'/pages/x/index?id=1'})` | `context.push('/x/1')`(go_router,路由登记 `app_router.dart`) | 新页必须登记 `page_parity_manifest.json` |
| `wx.requestPayment` | `lib/feature/payment/wechat_payment.dart`(fluwx,`/api/registration/pay/app`) | 虚拟道具禁用 |
- [ ] **Step 4**: 新增「## 标准单页循环」,把 §2.1 的 S1–S8 原样写入。
- [ ] **Step 5**: Commit `docs(agents): 重写过时的现状与地图段落,加入设计总则与小程序翻译对照表`。
#### Task 2.2: 主题编辑器浅色外观
- [ ] **Step 1**: 在 `token_codegen_test.dart` 加断言:生成物含 `class CyTokensTopicEditor` 且至少含 `colorBgPage`/`colorTextPrimary`,值等于 `tokens.wxss` 主题编辑器选择器块里的同名变量。跑红。
- [ ] **Step 2**: `gen_tokens.py` 已能解析主题编辑器块,只把它加入输出快照(仿照商家浅色的输出分支),`python3 tool/gen_tokens.py`。
- [ ] **Step 3**: `app_theme.dart` 加 `static ThemeData topicEditor()`;主题编辑相关路由(`/publish/pro`、`/template/edit`、`/template/new` —— 以小程序实际套用主题编辑器 class 的页面为准,grep `tokens.wxss` 选择器名在 wxml 中的使用)套用。
- [ ] **Step 4**: 测试绿 + 对应 golden 重生成 + 视觉对照台核这几页。
- [ ] **Step 5**: Commit。
#### Task 2.3: 试跑 3 页(验证循环与手册)
- [ ] 每页走完 S1–S8。
- [ ] 结束后写「试跑复盘」到本文 §附录 A:哪一步卡住、对照表缺了哪条、裁判有没有误报/漏报。**卡点一律回改 `AGENTS.md` / 脚本**,不在页面里打补丁。
- [ ] `GAP_BASELINE` 23 → 20。
- [ ] PR。
| 3.A | A(填) | 57 | | | / |
| 3.B | B(填) | 67 | | | / |
| 3.C | C(填) | 56 | | | / |
| 3.D | D(填) | 39 | | | / |
| 3.E | E(填) | 32 | | | / |
| 3.F | F(填) | 53 | | | / |
- [ ] `build_review.py --status todo,diff --only <本域 id>` 出对照页
- [ ] 逐组 S7:Claude 读左右两张图 → 列差异(布局/间距/字号/颜色/文案/缺元素/多元素)→ 修 → golden 重生成 → 重出对照页
- [ ] 同一差异在 ≥3 组出现 → **改共用组件或 token,不逐页改**,并回写 `AGENTS.md`
- [ ] 本域全部 `accepted`(有意差异写明)或 `diff`(阻塞原因写明)后 PR
- [ ] 合并条件:CI 绿 · 三个 parity 脚本数字不升 · 本域 visual todo = 0
#### 4.1 P0 —— 不补就没法正式用
- [ ] 〔#30〕**组队**:`team/detail`、`team/join` 页 + 票夹/报名列表的「我的队伍」入口(`/api/team/info` `join` `dismiss` `kick` `quit` `my`)
- [ ] **玩法互动组件**:小程序 `pages/play/components/playkit-*` ~30 种。**先用 Claude Design 出 iOS 交互稿**(决策 D5:触感、震动、传感器),每 5 个组件一 PR;`play_session_page` 占位控件逐个替换
- [ ] 〔#30 部分 / #39 偏好〕**游玩流程接口**:`puzzle/hint` `puzzle/reveal` `route-state`(断点续玩) `preference` `tag` `play/leaderboard`
#### 4.2 P1 —— 资金与权限
- [ ] **权限底座**:`/api/merchant/access/me`、`/api/club/access/me` 接进 `role_provider.dart`,商家首页/俱乐部详情管理 tab 按角色显隐(先做,下面几项依赖它)
- [ ] 〔#30〕商家**售后退款**:`merchant/aftercare` + `aftercare/detail`(`aftercare/list` `detail` `respond`)
- [ ] 订单页**取消并退款**:`orders_page` / `order_detail_sheet` 接已有 `cancel-refund`
- [ ] 〔#30 提现风险确认,需核是否含 preflight〕**提现预检**:`/api/fund/preflight/bank-withdrawal` + 可提现权限拦截
- [ ] 〔#30 商家侧〕商家**店员管理** `merchant/team`(`operators/*`)· 俱乐部**角色** `club/roles`(`roles/list|assign|revoke`)
- [ ] 俱乐部**结算** `club/settlement`(试跑已做则勾掉)
#### 4.3 P2 —— 主理人 / 商家运营
- [ ] 俱乐部后台:`governance` `notify` `event-ops` `customers` `customer-detail` `checkin-detail`
- [ ] 俱乐部详情:开放设置三开关 `open-settings/*`、帖子置顶/编辑/历史
- [ ] 主题导演台 `club/topic-detail`:`topic-setting/detail|save|end`、`recruit/overview`、`crm/topic-customers`;接上已写未用的 `club_lead_api.start/arrive`
- [ ] 〔#30〕商家:`reviews`(列表/回复/举报/公开)、CRM 分群/批量打标/营销发券/导出、`customer/detail`
- [ ] 主题运营 `topic/merchantinfo`:`topic/chapter/finish` `recruit`、圈子供给暂停/重确认;接上已写未用的 `pendingChapterNodes` `auditChapterNode` `chapterNodePosterCode`
- [ ] 活动编辑:`/api/activity/update` + 「我的项目」编辑入口
- [ ] 模板 AI 填充 `/api/ai/template/fill`;设置页营销授权开关 `crm/marketing-consents`、俱乐部入口创建/申请/管理分流
#### 4.4 P3 —— 玩家体验补完
- [ ] 〔#41〕到店 NPC 对话 `ai/npc/shop-chat` `voice-chat`
- [ ] 〔#30〕圈子主题 `play/circle`(`circle-theme/*`)· 剧情节点答题 `club/topic-story`
- [ ] 漫游社交:`subpackageRoam/nearby`(约伴全套)、`roam/presence` `nearby-runners` `shop/visitors` `roam/tiles/page`
- [ ] 邮票兑换 `citystamp`(`roam/stamp/exchange`)· 〔#30〕现场签到码 `merchant/game-node` · 竞猜 `merchant/predict`
- [ ] 零碎:首页扫码 `play/scan-entry`、〔#30〕活动候补 `event-ops/waitlist/*`、营销 7/30 天切换、合作中心官方活动列表、`topic/beta/graduate`、主题评价入口、`coop/invite-detail` 深链页
- [ ] 【用户】developer.apple.com → Membership 确认 **Active**,记下 **Team ID**
- [ ] 【用户】Identifiers → `com.chengyinhub.chengyinApp` 勾 **Sign in with Apple**、**Associated Domains**
- [ ] 【用户】微信开放平台注册「移动应用」,拿真 appid(≠ 小程序 appid),登记 Universal Link `https://www.chengyinhub.com/app/`
- [ ] 【agent】`project.pbxproj` 三处 `DEVELOPMENT_TEAM = <TeamID>`;`kWechatAppId` + `Info.plist` URL scheme 同时替换(`release_readiness_test` 会自动开始逐字比对)
- [ ] 【agent 写 / 用户部署】`https://www.chengyinhub.com/.well-known/apple-app-site-association`,内容含 `<TeamID>.com.chengyinhub.chengyinApp`,`Content-Type: application/json`;**观测**:`curl -sI` 看 content-type + `curl -s | python3 -m json.tool` 看 appID
- [ ] 【agent】`flutter build ipa --release 2>&1 | tail -c 3000`;**回读**:`plutil -convert xml1 -o - build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Info.plist | grep -c wxYOURAPPID` 必须 0;`codesign -d --entitlements - <Runner.app>` 含 applesignin 与 associated-domains
- [ ] 【用户】Transporter / Xcode Organizer 上传 → TestFlight 内测
- [ ] 【用户】真机验:Apple 登录、微信登录回跳、微信支付(线下核销类)、地图定位打卡

## Source: 城瘾vault/03-进行中/App端专属玩法_传感器与AR类_施工方案_20260821.md

### 5. 任务清单
- [x] 后端 vm=7 + `/api/play/sensor-result` + 模板 `sensor_type`/`sensor_config` 迁移(生产迁移 22/22 + 新连接精确回读;PR #775 → master `329927664`;post-merge CI/Funds/Deploy 全绿;生产 jar 自报完整 SHA 一致)
- [x] B1 静止检测引擎(不动如山 + 街头摆烂两皮;App `feature/sensor-play-0821@57c46c9` 已 push 并回读完整 SHA;三轴滑窗方差/晃动重置/后台暂停/用途确认后采集/XP 徽章回读均有测试,`dart analyze` 干净)
- [x] B3 伪 AR 滤镜相机(夜视/宠物 POV,后端 PR #785 head `188a5faaa`,App Codeup `feature/filter-camera-0821@8ad24c129`;两端远端 SHA 均回读一致,复用 `upload→/photo`,XP/徽章回执,末端权限回读与负控已完成;PR required checks 11 成功/3 skip/0 失败,真机/UI 截图另列 `EXTERNAL_GATE`)
- [ ] B2 会话级计步(极限计步 + 低碳行动两皮)
- [ ] B4 喵语翻译(record + AiGateway `pet_translate`)
- [ ] 编辑器 vm=7 tile(App 专属标记)+ 小程序 vm=7 引导卡
- [ ] 上架闸复核:隐私政策更新(新增 相机/麦克风/运动 权限用途声明)

## Source: 城瘾vault/03-进行中/Questify_第二组五个圈层自由探索主题_落地方案与TODO_20260821.md

### API
| POST | `/api/circle-theme/instance/configure` | 代理选择 3—4 个候选并保存实例策略 |
| POST | `/api/coop/offer/enroll` | 既有入口扩展供给快照；服务端按主题策略校验 |
| POST | `/api/coop/offer/circle-supply/reconfirm` | 商家重新确认自己的供给，追加当前版本并回读核验 |
| GET | `/api/circle-theme/instance/{topicId}/offers` | 仅公开 3—4 家有效商户的供给 |
| POST | `/api/circle-theme/session` | 创建玩家探索会话 |
| POST | `/api/circle-theme/session/join` | 熟人邀请码加入 |
| POST | `/api/circle-theme/session/record` | 自助记录一家供给，不触发核销 |
| POST | `/api/circle-theme/session/answer` | 保存主题轻互动 |
| GET | `/api/circle-theme/session/{sessionId}/card` | 满足 2 家 + 互动后回读记录卡 |
### 任务清单
- [x] T1 工程理解、领域词汇、数据边界与测试 seams
- [x] T2 [③] 主题/章节圈层字段与供给/玩家事实表迁移，含 dry-run 与合同测试
- [x] T3 [①] 城市实例 8 选 3—4 + 三作用发布门禁
- [x] T4 [③] 五主题、40 候选及模板元数据幂等种子
- [x] T5 [①] 商家供给快照写入、专项校验与有效性回读
- [ ] T6 [②] 代理候选配置 + 商家供给确认 UI
- [x] T7 [①] 玩家会话、自助记录、轻互动与记录卡 API
- [ ] T8 [②] 玩家跨天记录与记录卡 UI
- [ ] T9 红绿测试、迁移 dry-run、负控、微信模拟器截图自证
- [x] T10 `/code-review`、commit、push、PR、文档状态流转

## Source: 城瘾vault/03-进行中/专业发布页_Figma落码台账_20260905.md

### A. 已经在工作区、但还没提交的(更早几轮定的)
| A1 | 插入缝去掉「＋音频」,改由故事流底栏统一追加 | `pages/publish/fabu/index.wxml` | 已改,未提交 |
#### F4 · 弹窗颜色样式按手册 T3(以「选择路线类别」为样板)
| 行高 | 44 | **56** |
#### 已落码
| D4 空态三起点收敛成「＋ 创建章节」 | b30e76d25 |
| D1 节点卡带图 · D2 待编排素材缩略图 | e6ed605df |
| D3 故事流底栏单颗「下一步」 · G15 叠层/单层两种呈现 · G7/A3 待编排区拆白卡 | 51e37c48e |
#### I 段之后新增的改动
| **D6 = 「就写在里面」** | 商家承接段装回章节弹窗(开关 / 品类 / 承接条款 / 权益门槛 / 名额上限) |

## Source: 城瘾vault/03-进行中/交互反馈全量排查_按钮要知道点过了_20260826.md

#### P0 —— 用户点名的那件事
- [ ] **P0-1 一次性动作的完成态**([number] 逐条核过现码,范围比原来小很多):
- [x] ~~**P0-2 20 个裸奔提交按钮**~~ **已做,但数是错的**:复核后真缺口 **1 个**(见 §1.2b)。
#### P1 —— 游戏域手感
- [x] **P1-1 playkit 触感铺开** —— **[number] 已做**(PR #889)。
- [ ] **P1-2 玩法结果的持久痕迹**:木鱼功德数、步数进度、贴纸册收集度 —— 关掉再进来还在
#### P2 —— 减 toast
- [ ] **P2-1 toast 分流**:817 次里,凡是「有对应界面状态可改」的,改状态、删 toast。
- [ ] **P2-2 乐观更新**:只给赞/藏/关注三类轻动作,**动钱动库存的一律不动**
### 5. 建议配的门禁
- [x] **G-A 提交按钮在途保护** —— **已做**(PR #868 立 `submit-inflight-guard-contract`,
- [x] **G-B 成功 toast 棘轮** —— **[number] 已做**(PR #889 `success-toast-ratchet`,当前 106,只减不增)。
- [x] **G-C 玩法壳触感覆盖** —— **[number] 已做**(PR #889 `playkit-haptic-coverage-contract`)。

## Source: 城瘾vault/03-进行中/俱乐部端重做_代码落地施工文档_20260902.md

#### 3.1 `--cy-color-bg-surface-strong` 浅色域从未重声明
- [x] `style/tokens.wxss` 的 `page.theme-light,` 块补 `--cy-color-bg-surface-strong: #E4E4E4;`
- [x] `style/dark-mode.wxss` 的 `@media (prefers-color-scheme: dark)` 块同步补（否则契约②判红）
- [x] `style/merchant-light.wxss` 的 `page {}` 与它的深色镜像各补一份（契约③）
- [x] **实际是六个块，不是四个** —— 补的时候查出 `.theme-topic-editor` 同样在继承 `#3B3B3D`；
- [x] 值取 `#E4E4E4` —— Brand Handbook `color/bg/surface-strong` 的 Merchant / Topic editor 档，
- [x] **加一条新契约**：每个 `--cy-color-bg-*` 在四个主题块里都必须有值。
- [x] 负控：把新补的那行删掉，确认新契约判红
#### 4.1 T3「全屏」实际只有 68.6%
- [x] 改成 `92vh`
- [x] 删掉那个孪生 `--cy-comp-sheet-full-max-height`（`components/cy/scene-sheet/index.wxss:52-55` 一并改）
#### 4.2 peek 与 half 实拍像素级相同
- [x] 删掉 `min-height`
- [x] 两档合并成 T1 一档（上限 70vh）
- [x] 全仓 grep `ss--peek` 的调用方，统一改 `ss--half` 或去掉修饰符
#### 4.3 z 分档被越过
- [x] `cy-advanced-game` 改回 —— ⚠️ **没用 `--cy-z-celebrate`**：990 依然压过 modal 900，
- [x] 加契约：`tests/unit/z-index-ceiling-contract.test.js`（判据读 token 不读常量）。
#### 4.4 另外两个 token 缺口（手册有、代码无）
- [x] `--cy-color-status-danger-on-interactive: #FF3B4F`
- [ ] `--cy-color-status-*-strong`（软底上的状态文字，商家/创建域有独立值）
#### 5.2 新建 `pages/club/topic-detail/`
- [x] 新建页面与路由，`app.json` 注册
- [x] `goTopic` / `goManageTopic` 在 `canGovern() || canManageActivities` 时改指它
- [x] 纯玩家仍走 `pages/topic/index/index`，**不动**
- [x] `merchantinfo` **不动**（它是商家的，别为了复用去改它）
#### 5.3 四个圆钮点开什么
| 团码 | 出示团码 | T1 | **代码已实现**：`pages/club/detail/index.js:2117 showGroupCode()` 已弹窗化，直接搬 |
- [x] 商家弹窗：联系方式字段要后端确认下发时机（合作 accepted 之后）
- [x] 「编辑」弹窗里的开关用 `cy-switch`，**不要写文字「已开/已关」**
#### 5.4 底部主键三段（导演台收编）
| 准备总览 | **新增「准备中」态整页** | D1 |
| 活动收尾 · 结束活动 | **T2 居中确认**（无顶栏无 ✕，只能点按钮） | D2 |
| 章节控制 · 手动解锁 | T1 弹窗 | D4 |
| 队伍进度 / 队伍协作 | T1 弹窗 | D5 |
| 角色分配 / 角色接管 | T1 弹窗 | D6 |
| 定向广播 | T1 弹窗 | D7 |
| 现场事件（商家暂停/兜底/驳回） | T1 弹窗 | D8 |
| 活动漏斗 / 复盘 / 榜单可见性 | 已结束态整页 | D9 |
- [x] `game-director` 页面**保留路由**（深链兼容），但站内入口改指新页
- [x] 若保留该页，把 `theme-merchant` 改掉 —— 俱乐部端恒暗
- [x] 「提示与揭示」**不做** —— 提示机制玩家端已有（[number] 用户裁决）
#### 5.5 剧情与玩法（整页，不是弹窗）
- [x] 新建 `pages/club/topic-story/`（或作为 topic-detail 的子页）
- [x] 顶部两个 tab：**路线 | 玩法**
- [x] **路线**：按章节分组的站点时间轴。站点卡规格见 Figma 组件 `站点卡 / Stop card`：
- [x] 站与站之间「15min 步行」**8px Medium**
- [x] **玩法**：章节 chip → 本章剧情（可展开全文）→ 本章玩法（模板卡列表）
- [x] 模板卡样式复用 `PostCard / 分享模板` 的 `模板封面`（343×248 r16 + 渐变遮罩 + 角标 + 文案 + 按钮组）
- [x] 按钮按有无答案分两态：**有答案** = `看看模板` + `查看答案`；**无答案** = `看看模板` 单键占满
- [x] `看看模板` → 模板介绍页（**代码已有，不要改**）
- [x] `查看答案` → T1 弹窗（题面 / 答案 / 提示 1、2 / 玩家答错反馈）
#### 5.6 场次系列（event-ops 收编）
- [x] 「接下来」区加「管理场次 ›」，进场次系列页（Figma `E1`）
- [x] 内容：日期清单（已锁定/可编辑/已取消）· 重复方式 · 容量与候补 · 默认负责人 · 本场管理
- [x] 取消本场 → **T2 居中确认**（Figma `E2`）：列已报名人数 / 需退款金额 / 候补队列
- [x] 判断 `event-ops` 页面是复用还是废弃
### 六、P2-B · 客户系统（新建，代码零）
- [x] 新建 `pages/club/customers/`（列表，Figma `K1`）
- [x] 新建 `pages/club/customer-detail/`（详情，Figma `K2` 六态：
- [x] 主题内客户 = **T3 全屏弹窗**（Figma `J2`），从活动详情的「客户」圆钮进
- [x] 管理页加「查看客户」入口（Figma `M 管理` 第一条）
- [x] 状态色：**已核销 = 绿 `#12B886`**；待核销/已接洽 = `#D58300`；已退款 = `#EB6F73`
- [x] 手机号可见性受 `roles` 控制 —— 核销员默认看不到完整手机号（Figma `R1`）
- [x] 后端：客户聚合接口（按人聚合报名/核销/退款）+ 标签备注读写 + 手机号脱敏分级
#### 7.1 六个独立页对齐 Figma
| `club/group-code` | `R5 团核销码` | detail 已弹窗化；页面路由仅 `pages/play` 在用 |
- [x] 六页逐页对齐：色阶七档、间距 20/16/12、弹层四型
- [x] 标题下**不要小标题**（[number] 用户裁决，全线删除）
#### 7.1b 三个「桩」待定位（用户 [number] 提出）
- [ ] **先跟用户确认**是 Figma 死链还是某个我没找到的代码位置
- [ ] 若是前者：三处各补一张稿
- [ ] 「退出与暂停规则」正文代码里已有可直接搬：
#### 7.2 孤儿页处置
- [x] `club/images` —— 全仓无入口，判是否废弃
- [x] `club/event-ops` —— 无页面入口，见 §5.6
- [x] `club/workbench` —— 旧深链兼容壳，保留不画
- [x] `club/edition-report`（探店日质量证据）—— **稿已删**（[number] 用户裁决
#### 7.3 契约补强　✅ 已完成
- [x] 「每个 `--cy-color-bg-*` 在玩家档之外的五个块里都必须有值」+ 负控 → 契约 ⑨
- [x] 「`z-index` 字面量不得超过 `--cy-z-celebrate`」+ **三个**负控
- [x] 每条新契约都要做**负控**：构造该红的场景，确认它真的红
#### 堆叠层(base = `claude/club-pages-redesign-e72697`,#981 合并后自动改指 master)
| [#984](https://github.com/liboyang42-cpu/chengyin/pull/984) | D1/D2/D4–D9 | 导演台 10 张卡收编成 `cy-club-director-*` 组件;`game-director` 改暗底(顺带修了 `ui-theme-unit-lint` 里把 club 特判成浅色的门禁) |
### 十二、[number] 全稿真读:我的初判被推翻
| 已一致 | 2 |
| **复核推翻** | 2 |
### 十三、★ 合并后必须做的「接线」(别漏)
| 主题卡「打开剧情与玩法 ›」 | `pages/club/topic-story` 路由 | #988 |
#### 仍未做的 5 条(不要再当成做完了)
| 141 | `--cy-color-status-*-strong` 全套 | tokens.wxss 只有 `info-strong` / `warning-strong`,缺 `success` / `danger` |
| 200 | 商家弹窗联系方式下发时机 | 待后端确认,非前端可独立完成 |
| 201 | 「编辑」弹窗开关用 `cy-switch` | 未核到,需逐页看 |
| 280 | 后端客户聚合接口 | 现有客户页走的是既有接口,聚合接口未建 |
| 312 | `--cy-color-bg-*` 四主题块齐全契约 | 仓库里没有这道门禁 |
### [number] 截图走查(改动后真的看了图)
| 1 | 活动详情页错误态被微信胶囊压住,标题上半截被切 | 真 UI bug。`cy-nav-bar overlay` 无封面垫底时整块滑到胶囊下 |
| 2 | 俱乐部详情导航栏设置图标是**蓝的** | 真 UI bug。`icon_setting3.svg` 写死 `fill="#000DFF"`,`filter: brightness(10)` 拉亮没拉白 |
| 3 | 结算页「已入账分润 ¥12,480」正下方写「已入账金额待确认」 | 文案自相矛盾,且在动钱页面 |
| 4 | F17 / F57 两条矩阵注入态字段名过期 | 截图恒拍空态 ⇒ 这两条截图从没证明过任何事 |

## Source: 城瘾vault/03-进行中/小程序交互反馈补全_盘点与施工_20260821.md

### 已完成(PR #782)
- [x] **弹窗退场动画**:新增 `behaviors/exit-motion.js`,show 置 false 先播退场再卸载;20+ 调用方全受益
- [x] **退场快于进场**:遵 DS 文档3 §B.1(进场慢/退场快 ~20%、上限 300ms)。sheet 350→220、modal 220→140
- [x] **按压态 94 处**:index / roam / template / talent 四页 76 处 + cy-profile 组件 18 处
- [x] **金额滚动**:countUp 首次真接线(收益卡);只写展示值,真值与空态判断不受污染
- [x] **骨架屏淡切**:`.cy-fade-in` 铺到 47 个 wxml;单一真源 `style/fade-in.wxss`
- [x] **触感收口**:新增 `motion.haptic()`(减动效不震 + 兜机型 reject),七个成功时刻统一走它
- [x] **门禁修真空白**:setdata-dead-field 门禁不认 behaviors,会把 cy-modal/cy-sheet 调用方误判成死字段;已改成跟进 behaviors 并补正例+负控自证
### 未做(P2,非遗漏)
- [ ] 41 处裸 `<button>` 收敛到 cy-btn(自动获得按压 + loading)
- [ ] 14 个自造 mask/popup 收敛到 cy-sheet ⚠️ **动之前先核对「页面↔场景双份实现」的契约保护**,确认哪份是真源
- [ ] 列表页补下拉刷新(全仓仅 4 页开了 `enablePullDownRefresh`)
- [ ] cy-profile 3 处 `<image>` 缩略图按压态 —— 平台不支持,需包 wrapper view,会改 scroll-view/grid 子结构
- [ ] 淡切剩余站点:8 处因契约冲突撤回、4 处 `<block>` 挂不了 class

## Source: 城瘾vault/03-进行中/探店日开工计划_20260814.md

#### 5-3 这一批的负控
| 让 `/api/play/checkin` 返 500 | 玩家侧必须有可见错误,**不得静默** |
### 一、UI 有效性门禁(每批都跑,不是最后才查)
| **U1** | 小程序里每个 `url: '/api/…'` 的路径,后端必须有对应 `@*Mapping` | **按钮有、handler 有、接口不存在** —— 最隐蔽,且 `silentError` 会把它变成完全无声 | 🔴 |
### 二、迁移清单(要在库上跑的)
| 0 | `product_type` 回填(3 个混票主题) | DML,**部署前必做** |
| 1 | `PENDING_REVIEW` 生命周期态、开售快照表、`max_ticket_per_account` | DDL |
| 2 | 进店事实列 / 批次容量三列(`batch_size`/`batch_interval_minutes`) | DDL |
| 3 | `club_payable` / `club_payable_batch`、成本录入表、`user_permission.player.withdrawable` 0→1 | DDL + DML |

## Source: 城瘾vault/03-进行中/探店日施工基线_差异裁决表_20260814.md

#### 1.3 玩家流程(6 条)
| **C1** | **进店用玩家扫店内静态码**,不用 GPS(不准) | 码换节点的链路已通:`/api/play/checkin` 读 `cms_topic_node.checkin_code`。探店日商家取码:`POST /api/merchant/chapter-node/poster-code`(master 已有端点)。PR #969:承接详情出示/下载接到该端点,中标站可回落取同一份静态码。漫游先例仍在:`ApiMerchantNodeController` `/api/merchant/city-node/poster-code` |
| **C3** | **拍照从「平行验证方式」改成「扫码后的第二步」** | 现在 `/api/play/checkin` 与 `/api/play/photo`(`:742`)是 `validation_method` 的两个平行选项,扫一个就完事。探店日要串成先后 |
| **C4** | **扫码入口挪到商家详情页** | `wx.scanCode` 现在在 play 页(`pages/play/index.js:1441` / `:1621`),要挪进 `pages/play/merchant/`(PR #730,[number] 合入) |
| **C6** | **规则与上传要求由后端按进店态下发** | 现在随 `/api/play/nodes` 一次性全量下发(`pages/play/index.js:735`),等于没到店就能看到全部四家的玩法。改为逐节点按「该玩家在该节点的进店态」裁字段 |
#### 1.5 第二批裁决([number] 晚,11 条)
| **H8** | **删除发布者分润,改为发积分** | ⚠️ **有两个出口,只删一个没用**:①主题线 `CmsTopicServiceImpl:989` `publisherCommission → addBalance`;②活动线 `CmsActivityServiceImpl:203` `designerCommission → addBalance`(`designerRate = rule.getCreatorRate()`,`resolveDesignerMemberId` 取的就是主题创作者)。<br>⚠️ **活动线有配平约束**:`totalRate = platformRate + merchantRate + designerRate`,`CmsActivityServiceImpl:159-172` 校验**三档之和强制 == 1.0**。不能只把 `des
### 六、五份审计的边界与依赖
| 1 | **交易骨架** | 期入口(B1)、场次三列(B2/B3)、票/席位、开场线 24/30、阶梯 k 与 k_min、N_BE、条件预售池、开售快照冻结、退改转、后台建期入口 | 缺任一快照字段必须拒售 |
| 2 | **资金域** | 瀑布六量与守恒式 `G_cash + U_in = G_earned + U_out + R_refund`、跨期负债台账、俱乐部 F/Q/票源三段(A4)、商家零现金闸(A2/A3)、CM 十项扣减与成本录入、G5 | 守恒式本身就是负控 |
| 3 | **核销与现场** | 进店扫码(C1)、扫码降级(C2)、拍照第二步(C3)、入口迁移(C4)、通关真源换侧(C5)、规则按进店态下发(C6)、A/S1/S3/C 漏斗、**`queue_joined_at`/`service_started_at`/人工批次容量**、G2 等待 P90 硬门 | 等待样本覆盖率 <95% 或单店 P90 >20 分钟必须判门失败;规则字段在未进店时不得下发 |
| 4 | **三身份与数据边界** | 身份互斥、主办方判定(恒平台)、商家可见字段收窄(偏离 2 的三个约束)、俱乐部可见数据、用户关系分层、G3 | 用非超管账号验收,越权字段必须拿不到;无进店记录的玩家必须查不到 |
| 5 | **漫游与导流** | 免费层红线守护(无路线/无顺序/无箭头导航)、核销后余位分流、兴趣定向、7 日复访 | 出现路线/顺序/箭头导航即红 |
#### 7.2 总控裁决(7 条,不占用用户)
| **F6** | 漫游红线:**轨迹 + `routeStory` 留,分享卡「漫游路线」文案改** | `routeStory` 挂在 `pages/roam/index.wxml:514` 的 **finish 屏**(结算屏),数据来自 `ApiRoamController:433 approvedRouteStory(session)` —— **事后回顾,不是事前指引**,与轨迹回放同性质。但对外话术把它叫「路线」就等于承认它是路线。<br>⚠️ **附加负控**:`routeStory` 是 AI 生成的,文案不得出现「下次/建议/先…再…」这类**前瞻指引** —— 一旦出现就从记录变成了指引 |

## Source: 城瘾vault/03-进行中/探店日施工审计_3_核销与现场_20260814.md

#### 1.1 已有且通电
| 玩家出动态核销码 | `ApiVerifyController:70` `/api/verify/dyncode/issue` | HMAC 签名 + 5 分钟 TTL(`:41`);归属闸(只能给自己的单出码 `:89`);已支付闸(`:93`);「消费完了不再出码」判据是 `isTicketFullyConsumed`(`:105`)而**不是**裸 `verification_status`——③ 首章核销就置位,裸判会当场断掉多章链路 |
| 玩家侧出码入口 | `pages/play/index.js:488 openEntryQr` → `pages/play/components/scene-qr-ticket/index.js:58` | 商家详情页 `pages/play/merchant/index.js:59 openVerifyCode` 通过 `navigateBack` 回 play 页再调它 |
| 商家扫码端(小程序) | `pages/merchant/index/index.js:618` + `:680`;`components/cy/profile/index.js:1097` + `:1153` | 判据是**载荷** `d.needChapterChoice` 不是 code——新老客户端共存 |
| 玩家投诉工单(链路本体) | `ApiCoopController:634` `/api/coop/complaint/report` + `subpackageMember/complaint/index` | 表 `coop_complaint`;后台处置 `CoopComplaintController` 有 advance/close。**小程序整页在跑**(`index.js:135` POST,`scene-registry.js:65` 挂了路由),主题下拉取 `item.cmsTopic.id`(`:64-66`)⇒ 玩家选得到正确 topicId。闸的问题见 S9 |
| **人级四段(①口径)** | `ProjectPlayerReadServiceImpl:147-150` → 端点 `ApiProjectController:127` | 按 topicId 聚合 `paidCount` / `arrivedCount` / `pendingCount` / `refundedCount`,来源是 `registration.verification_status` / `payment_status`,**不是** `biz_event_log`。商家侧同型在 `[id]:326-380`(四段带 rate,端点 `ApiMerchantController:497`,小程序 `pages/merchant/marketing/index.js:54` 真在消费) |
| 节点打卡码 | `cms_topic_node.checkin_code`(`migration_play_progress_points.sql:5`,存量已回填 `:7`) | `/api/play/checkin:571` 按码反查节点 |
| 集章展示三处真渲染 | `utils/roam-poi-group.js:98 stampProgress`;`pages/play/index.js:839 seatTiles`;订单详情逐章(上一行) | |
#### 1.2 半成品(有码没通电 / 能力在但没接到探店日这条链上)
| **`/api/play/arrive` 的反作弊闸是有条件的,不是恒拒**(更正) | `ApiPlayProgressController:681`(端点)、`:707-713`(闸) | 闸的完整条件是 `node.getTemplateId() != null` **且** 模板 `validationMethod ∈ {1,2,3,4}` 才拒;注释 `:708` 明写「仅 0/null(到点即完成)或 5(GPS)放行」。**节点没绑模板 ⇒ 闸整段跳过,`/arrive` 直接放行。** 而 0 号表 B5 定的是「app 不承载玩法」⇒ 探店日节点本就不绑玩法模板 ⇒ `/arrive` 可用。⇒ **A 不用 `/arrive` 是我的口径选择(要商家坐实的硬证据),不是「它恒拒」**(见 S7) |
| **`ApiMerchantNodeController:303 poster-code` 是漫游的,不是探店日的** | 它读 `roamMapper.selectMerchantNodeDetail(poiId)`,归属比的是 `roam_poi.merchant_id` vs `mms_merchant.id` | 0 号表说它是「先例」,准确。探店日另开了 `POST /api/merchant/chapter-node/poster-code`(见 T2,已接通)。⚠️ 工作台 DTO 刻意把码拦掉(`TopicWorkspaceServiceImplTest:377` 断言「工作台节点不得暴露核销码」)——**那是契约不是遗漏** |
### 四、边界引用
| **一账号一票**(`max_ticket_per_account=1`,进开售快照,闸在 `createRegistrationInternal`)(D3)—— S1 的进店幂等键因此不必含 `registration_id` | 0 号表 D3 → 字段落在**文档 1 · 开售快照** |
| **③ 关闭积分抵扣**(D2)—— `payable_amount` 与 `wechat_payment_amount` 等价,S8 退款票率的分母不再有口径分叉 | 0 号表 D2 |
| **`copyTopicTicketsToActivity` 的字段同步**(`OmsTicketServiceImpl:284-299` 手抄清单,已在漏 `gatherLng`/`gatherLat`/`signupDeadline`)—— 活动壳下**被卖的那张票**才是 S7 读 `start_time` 的对象 | 见**文档 1 · 交易骨架**(D1 的连带,文档 1 头号施工项) |
### 五、待验证(需真机/真库/现场实测,不是待拍板)
| V3 | `subpackageMember/complaint` 用 `owner_type:3` 拉可投诉对象,对 ③ 活动单返不返行 | 真机走一遍 S9 修复后的投诉流程 | 若返空,修 `/api/registration/list` 对 `owner_type=3` 的语义(0 号表 §7.4 第一行即此项) |
#### T2 · 探店日的商家取码端点 ~~不存在~~ → 已有端点；商家页取码由 PR #969 接通
- [x] `POST /api/merchant/chapter-node/poster-code` 已在 master(`[id]`),出图内容是 `cms_topic_node.checkin_code`,不是漫游 `VerifyDynCodeUtil` 串
- [x] PR #969:承接详情 `pages/topic/merchantinfo`「出示二维码 / 下载到本地」接到该端点;城市定向中标站补 `assignedStationPosterNode` 回落
- [x] 工作台 DTO 仍不暴露核销码(`TopicWorkspaceServiceImplTest`)——契约未破
- [ ] 第 5 批端到端走通(四角色真跑)仍未做;一次性 `live-checkin-code` 仍在后端与孤儿页 `pages/merchant/game-node/`,工作台不再进入

## Source: 城瘾vault/03-进行中/日期与区间选择_组件统一方案_20260826.md

#### 1.2 真正的病灶:"区间"没有组件
| `subpackageMember/couponInfo` | **4 个** | 同上,券有效期 |
#### 第一批 —— 真区间,收益最大
- [x] `pages/activity/list`(`:96` `:99`)两个独立 `cy-date-field` → 一个 `cy-date-range-sheet` —— **[number] 已做**(PR 待开)
- [x] `publish/components/reward-selector`(`:92`–`:138`)**4 个滚轮** → **[number] 已做**(PR #881)
- [x] `subpackageMember/couponInfo`(`:96`–`:142`)**4 个滚轮** → **[number] 已做**(PR #881)
#### 第二批 —— 时段收口([number] 做完,5 处里换了 2 处)
- [x] `merchant/game-node`(`:106` `:110`)→ `cy-time-range` —— **原本零校验**,而 `serviceStartAt/serviceEndAt` 是直接拼给后端的
- [x] `pages/play/celebrate`(`:65` `:69`)→ `cy-time-range` —— **原本零校验**,且旁边「120—210 分钟」全仓没人算过
- [ ] ~~`topic/merchantapply`~~ **不换**。`final-review-fixes-contract` 逐字锁着这个弹窗的结构(cy-sheet + 无多余「取消」+ 一个「完成」),那是一次**有意的交互改造**不是顺手写死的值;而且这页本来就有校验。按「契约冲突撤站点」撤回
- [ ] ~~`merchant/apply`~~ **不换**。它的时段是「经营日(星期多选)+ 营业时段」**同一个面板的一部分**,换成独立弹窗会变成弹窗套弹窗。⚠️ 可做的是把校验接进去(它现在也走 `isEndAfterStart`,但没有时长显示)
- [ ] ~~`publish/activity`~~ **不换**。它是 **datetime** range(日期+时间)且已有 start/end 切换态与校验提示,做得比其他几处都好,换成 `cy-time-range` 会丢功能
- [ ] `pages/play/celebrate` 的**角色行**(`:138`)仍是逐角色内联编辑(`data-role`/`data-field`),形态不同,未动
#### 第三批 —— 日历带业务信息(要后端配合)
- [ ] `pages/club/detail`(`:501` 场次日期)→ `cy-calendar` 单选 + `marks` 显示当天场次数
- [ ] `search2` / `searchmap` 筛选日期 → `cy-calendar` 单选
### 8. 判红门禁(照例,没门禁就会漂)
- [ ] `date-picker-single-source-contract`:新增手写 `picker-view` 判红,**除非登记豁免**。⚠️ 现在有 8 页手写,门禁先按棘轮锁死这个数,只减不增
- [ ] `date-range-validation-contract`:所有区间组件必须做「结束 ≥ 开始」校验,**负控:把校验摘掉必须判红**
- [ ] `cy-calendar` 的 WXS 计算要有单测(纯函数,可直接跑):偏移量、枚举 type 判定、跨月边界

## Source: 城瘾vault/03-进行中/自由探索App同步_批4实施计划_20260909.md

### File Structure
| `lib/data/api/npc_api.dart`(或并入 `play_api.dart`,看现码) | `shopChat` / `voiceChat` 两个调用 |
#### Task 1: API 与模型
- [x] **Step 1: 写失败测试**
- [x] **Step 2: 跑,确认失败** → **Step 3: 实现** → **Step 4: 跑,确认通过** → **Step 5: commit**
#### Task 2: 纯逻辑(`shop_npc_logic.dart`)
- [x] **Step 1: 写失败测试**
- [x] **Step 2-5:** 跑红 → 实现 → 跑绿 → commit
#### Task 3: 人形舞台(`widgets/npc_figure.dart`)
- [x] **Step 1: 写失败测试** —— 几何纯函数逐点断言;降级时不启动 `AnimationController`;
- [x] **Step 2-5:** 跑红 → 实现 → 跑绿 → commit
#### Task 4: 消息流(`widgets/npc_message_list.dart`)
- [x] **Step 1: 写失败测试**
- [x] **Step 2-5:** 跑红 → 实现 → 跑绿 → commit
#### Task 5: 输入条(`widgets/npc_input_bar.dart`)
- [x] **Step 1-5:** 同上循环
#### Task 6: 语音链路(**可砍的一棒**)
- [x] **Step 1-5:** 同上循环
#### Task 7: 页面组装 + 入口接线 + golden
- [x] **Step 1-5:** 同上循环,golden 要解码复量

## Source: 城瘾vault/03-进行中/自由探索游玩页_App同步_设计文档_20260909.md

### 0. 三条已拍板的前提
| 1 | **App 改接 `shop-chat`**,不给后端补 `merchant-chat` | 后端已有 `/api/ai/npc/shop-chat` + `/voice-chat` 并已部署;再补一套等于把合规闸/归属校验/计费各做两遍,两端契约长期分叉 |
| 2 | **完全还原样机** | 3D 卡盒、分层粒子、程序化人形、滚动显形都照做,不降级成占位 |
| 3 | **屏④ 入口在,点开显示服务端原话** | 与小程序 9-08 的行为一致;开关一开两端同时生效 |
### 7. 明确不做
| 商家侧自助配店铺形象 | 后端 `/api/merchant/npc/info|save` 不存在,记进 blocked |

## Source: 城瘾vault/03-进行中/节点玩法模板_十九个玩法与编辑页_施工文档_20260909.md

### 7. 待裁决
| 2 | 选项问答是否支持一组题(如五道) | 现在一个节点一道题,次数按选项数封顶。「五道选择题错三次」需要节点装多道题,是模板结构要改 |
| 3 | 体验卡奖励 | 后端没有,要新建表和核销链路。做不做、什么时候做 |
| 4 | 拍照打卡的判定 | 接 AI 审核,还是明确定义成「上传即完成」并去掉审核开关 |

## Source: 城瘾vault/04-未开始/App_parity_未完成项持续清单_20260820.md

### 本批编排
| D1 资金域 | `task_d53e8dd8c3b6` | `ctx_4ee0ac9c60ad` | parity-D1-money | **空任务,已回滚收尾**(`490367c`,净 diff=0) |
| D2 零散四条 | `task_610f351eafac` | `ctx_35172c102c09` | parity-D2-scattered | 交付 `cd485d8`,**打回一处**(funnel) |
### ★★ 总控四次错误前提(病根同一个,必须写下来)
| ① | 任务书让 worker 读 `~/Downloads/chengyin`,而它**落后 github/master 4 个 commit** | D1 抽查发现 | D1/D2 都基于旧真源下了错结论;修复后又把所有 worker 的全量测试打红 |
| ③ | **D1 整个任务是空的** —— `activity_api.dart:218 payApp` + `orders_page.dart:61` 早就接通 | 总控自查 | 一个 worker 整轮白干 |
| ④ | `merchant/funnel` 不该接 —— marketing-home 已聚合(`[id]:265`) | **没拦住** | D2 为了让门禁绿**删掉了那条论证**,已打回 |
#### 来源:总控自查([number])
| [number] | C 块(微信 appid) | `/api/login/code`、`/api/getwxbindphone`、分享三条被占位 appid `wxYOURAPPID` 卡死,**不是代码活**,本批未派。 | 中 | 未处理(阻塞在用户侧) |
#### E(已合并,回执完整)
| [number] | `endpoint_reachability_test.dart:63` | `/api/play/companionLine` 仍未接(App 走 `/api/ai/npc/*`,是有意的) | 中 | 已立卡 |
#### E(已合并 `789c219`;收尾回执已收,工作区干净)
| [number] | `endpoint_reachability_test.dart:63` | `/api/play/companionLine` 未接(App 走 `/api/ai/npc/*`,有意的) | 中 | 已立卡 |
#### D2(已合并 `c4233a7`;收尾回执已收,工作区 clean)
| [number] | `kKnownUnreachable` 的 `/api/map/reverse-geocode` | 该条标注是 `// 未核`,已要求 D2 用结论替换它 | 低 | 已派 |
| [number] | coop deposit | 后端只给 JSAPI 参数,缺 App 六元组;D2 已 fail-closed 接线不伪造签名。**后端待补 App 保证金支付契约** | 中 | 未处理 |
#### A(在途)
| [number] | 小程序 `pages/roam/index.js:3154` | `_shopBadgeThreshold()` 在勋章停用(`badge/shop-streak` 返 null)时仍按兜底阈值 3 弹章,与后端 `ApiRoamController:310` 的 `// 停用则前端也不弹卡` 相悖。**小程序侧待修**,App 已裁决按 null 不弹 | 中 | 未处理 |
### UI 持续对齐([number] 晚新增)
| [number] | `pages/play/merchant` 到店任务文案 | ★ B 收尾回执**明确确认**:「到店任务整套文案**完全没做**,也未落在其他文件」。原在 B 范围内,随撤销 consents 时一并没了。缺的是「到店任务 / 去拍照 / 导航去这里 / 商家核销的时刻才算服务开始 / 写下你的答案」整套(该页文案命中率 32%) | 中 | 未处理(已确认需另立条目) |

## Source: 城瘾vault/04-未开始/App与小程序一致性盘点_代码侧收口清单_20260820.md

### 二、B 块:玩法内的三处零散未接
| `/api/play/egg/collect` 彩蛋收集 | `pages/play/index.js:1511` | **发布端能编辑彩蛋**(`publish_pro_sheets.dart`,15 个上限),玩家端收不了 |
| `/api/play/hint/unlock` 提示解锁 | `pages/play/index.js:1991` | 未接 |
| `/api/official/events/{id}/arrivals` 官方活动到达 | `pages/activity/official-detail` | 未接 |
### 三、C 块:被微信 appid 卡着的两条(不是代码问题)
| `/api/login/code` | 微信登录。App 的移动应用 appid 仍是占位 `wxYOURAPPID` |
| `/api/getwxbindphone` | 微信绑定手机号,同上 |
### 四、D 块 —— ★★ 已推翻并重判([number] 晚)
| `/api/registration/pay` | 「App 能下单,补不了款」列为最急 | ❌ **不是缺口** | `activity_api.dart:218 payApp` + `orders_page.dart:61` **早已接通**。小程序用 `/pay`(JSAPI)、App 用 `/pay/app`(trade_type=APP),同一件事的两种平台实现。整个 D1 任务因此作废 |
| `/api/registration/join_info` | 「一条就清掉页面层 2 页缺口」 | ❌ **有意不接** | 票夹 `/registration/list` 行上带 `registrationStatus`(==2 即进行中,`activity.dart:292 TicketState.ready`)。再接一个 = 同一事实两个来源必然分叉 |
| `/api/merchant/funnel` | 「商家经营漏斗未接」 | ❌ **不该接** | `marketing-home` 已聚合它(`[id]:265`),而 App 营销页 `merchant_marketing_page.dart:14` 走的正是它。再接一遍 = 同一屏两次网络 + 解析路径漂移 |
| `/api/compliance/consents/latest` | 「到店任务的合规同意」 | ❌ **设计差异,不是缺口** | App 两处同意都是即时写入即时用,不需要读回;写入侧 `/api/compliance/consents` 已通。等要做「记住上次同意」时再接 |
| `/api/coop/deposit/create` | 「合作保证金支付」 | ✅ **已接**(`c4233a7`) | 后端只给 JSAPI 参数(`createGenericOrder` 带 openid),缺 fluwx 六元组 ⇒ **fail-closed 并明确提示,未伪造签名**。真实付款待后端补 App 契约 |
| `/api/city/nodes` | 「地图搜城市节点」 | ✅ **已接**(`c4233a7`) | 清单里旧理由「要落在 map_page.dart(用户在改)」已过期 —— 那批 NPC 改动已于 `64001e08` 合入 |
| `/api/map/reverse-geocode` | 「逆地理编码」 | ✅ **已接**(`c4233a7`) | 原清单标注是 `// 未核`,已用结论替换:经纬度仅随当次请求发送,不落盘、不打日志 |
### 四之二、原 D 块内容(已作废,保留供追溯)
| `/api/registration/join_info` | `components/cy/profile/index.js:759` | **这一条造成页面层仅有的 2 页缺口**:`pages/member/index/index`、`pages/userinfo/userinfo` |
| `/api/registration/pay` | `scene-member-order-{history,detail}` | 订单**再支付**。App 能下单,补不了款 |
| `/api/coop/deposit/create` | `pages/coop/list/index.js:346` | 合作保证金支付 |
| `/api/merchant/funnel` | `pages/merchant/index/index.js:79` | 商家经营漏斗(报名→核销→收入) |
| `/api/compliance/consents/latest` | `pages/play/merchant/index.js:266` | 到店任务的合规同意 |
| `/api/city/nodes` | `pages/searchmap/index.js:413` | 地图搜城市节点 |
| `/api/map/reverse-geocode` | `pages/index/index.js:1487` | 逆地理编码(首页城市名) |
### 七、文案层:5 页命中率偏低(线索,不是判决)
| `pages/merchant/profile/index` | 1/8 12% | 商家主页、商家不存在或未开放、资料加载失败 | **像真缺**:商家公开主页的四态 |
| `pages/play/index` | 28/111 25% | 节点实拍、扫码到达、编辑此节点、你的城市故事 | 部分真缺(编辑态/扫码提示) |
| `pages/play/merchant/index` | 8/25 32% | 到店任务、去拍照、导航去这里、商家核销的时刻才算服务开始 | **像真缺**:到店任务全套 |
| `pages/roam/index` | 34/97 35% | 仅浏览、做微任务、不绑定路线随走随发现 | 归 **A 块**,漫游页没建 |
| `pages/searchmap/index` | 15/28 53% | 关联主题路线、商家发现、地图图层说明 | 部分真缺 |

## Source: 城瘾vault/04-未开始/App未完成项持续清单_20260818.md

### 二之二、看图新增([number] 总控逐张复核)
| V9 | `topic_detail_page.dart` | 主题详情**无底部动作条**;小程序那页有整套售票门禁(`pages/topic/index/index.wxml:330-339`:招募中/定价中未开售、「查看场次」+「¥X 随时开玩」双按钮、「去参加」)。**但严重度按「中」不按「高」**:该页在 App 内**没有任何入口**(只在 `app_router.dart:186` 注册,无处 push),且 `TopicDetail` 模型缺 `lifecycle` / `selfPlayPrice`,数据也不全。③ 买票主链走的是 活动列表→活动详情→买票,那条是通的 | 中 | **未处理** —— 补它等于扩范围(要同时补入口+后端字段+门禁),不阻断上线 |
### 二之三、上线就绪核查([number] · 真跑了一次 iOS 构建之后)
| ~~V18~~ | `activity_detail_page.dart` | **游客点进活动详情是死路**:生产 `/api/activity/info` 对无 token 请求返回 401,而路由让游客直接浏览;通用错误态误导(说"后端未连接",实为要登录;且「重试」永远还是 401)。**审核员正是游客** | **高** | ✅ `1ed3f03` 改为「去登录」可恢复引导 |
| ~~V19 代码半边~~ | `/api/activity/list` 响应 | 不返回 `productType` ⇒ App 无法按 ③ 过滤 | 高 | ✅ **已合并并在生产验证**。PR #739(修复本就存在,我上一轮说「前端修不了」时漏了这句,更正)。<br>它此前 BLOCKED 于 `Funds MySQL IT` 红:`CmsActivityMapper` 新加的 `(select t.product_type from cms_topic …)` 子查询撞上 `[id]` **建了 cms_activity 却没建 cms_topic** ⇒ 整套报 `Table '…cms_topic' doesn't exist`(50跑/2fail/13error)。本地真库复现数字与 CI 逐个吻合;补表后 50/0/0,完整门禁 98/0/0 skipped=0。推 `
| **V20** | 生产内容 | `/api/activity/list` 实测**总共只有 1 条**,且是「上海滨江10KM骑行挑战赛」= ① 类,不是 ③ 探店日 ⇒ 现在上线的话,App 全部目录就是一条做不了的 ① 活动 | **高** | **未处理** —— 内容/运营问题,需先在后台发布 ③ 探店日场次 |
#### 跑起来后拿到的证据
| 启动第一屏 | ❌→✅ 52pt 地图图标用了 `nodeGlow`(#00E5D4 青),而城瘾是黑白系;**该 token 自己的注释就写着「不要拿来做主色」**。已改 `textSecondary` + 加闸(`8344252`)。改后整屏彩色像素 **738 → 0** |
### 二之四、生产实测([number] · 以游客身份打生产接口)
| Apple 登录端到端 | ✅ **通**。App Store 4.8(有微信登录就必须有 Apple 登录)这条不成问题 | `/api/login/apple` 拿假 token 返回 `{"code":500,"参数有误"}` = 被列为公开路径**且有真实处理器**;对照组(不存在路径)返回 401,两者可分辨 |
| V18 的前提 | ✅ **成立**,不是误判 | `/api/activity/info` 确实存在(`ApiActivityController.java:711`);白名单 `SecurityConfig.java:140` 只放行 `/api/activity/list` 与 `/api/topic/list` ⇒ 详情对游客必然 401 |
| 游客可见内容普查 | banner **2** 条 · 创意广场 **10** 条 · **主题 0 个** · 活动 **1** 个(且是①骑行赛) | 依次 POST `/api/common/banner`、`/api/creativesquare/list`、`/api/topic/list`、`/api/activity/list` |

## Source: 城瘾vault/04-未开始/App设计token生成链_方案C_20260820.md

#### 3.1 ★ 37% 的 token 是 `var()` 引用,而且跨块会被覆写
| hex 色值 | 161 | 24% |
| `rpx` 尺寸 | 91 | 13% |
| `rgba()` | 85 | 12% |
| 其他(渐变/函数/关键字) | 56 | 8% |
| 纯数字 | 11 | 1% |
| 含 rpx 的复合值(阴影/边框) | 7 | 1% |
#### 阶段 1:筛选清单(先做,它决定后面所有工作量)
- [x] 产出 `tool/token_allowlist.txt`:**哪些 token 该进 App**
- [x] 起点:现有 `cy_tokens.dart` 的 65 个常量(32 Color + 33 double)反查对应 wxss 名
- [x] 加上 `CyPalette` 的 25 个语义字段在两套块下的取值
- [x] ⚠️ 379 个不要全收:组件私有 token(`--cy-comp-*`)默认不进,除非 App 真的用到
- [x] 每条写一行「为什么要它」——空着的一律当未核(照 `kKnownUnreachable` 的规矩)
- [x] 用清单跑一遍现状,确认清单里的每条都能在 wxss 里找到(找不到就是清单写错了)
#### 阶段 2:生成器
- [x] `tool/gen_tokens.py`
- [x] 解析四个块,产出 `{块名: {token=[redacted]
- [x] **展开 `var()` 引用链**,按块各自求值;循环引用要报错不要死循环
- [x] 形态换算:hex / rgba / rpx(÷2);认不出的跳过并计数打印
- [x] 按 allowlist 过滤
- [x] 输出 `lib/core/theme/cy_tokens.g.dart`,文件头写死:
- [x] 打印摘要:生成 N 条 / 跳过 M 条(附形态)/ allowlist 里没找到 K 条
- [x] 首次生成,与现有 `cy_tokens.dart` 的值**逐条比对**
- [x] ★ 不一致的**逐条查明原因**再改 —— 可能是生成器错,也可能是手抄本来就漂了。
#### 阶段 3:接线
- [x] `cy_tokens.dart` 改为引用 `cy_tokens.g.dart` 的值,保留全部决策注释与语义别名
- [x] `cy_palette.dart` 的 dark / light 两套改为从生成值装配
- [x] `flutter test` 全绿(基线见文末)+ `dart analyze lib` 0 error
- [x] golden 测试若因取值微调而红 → **逐张确认是"值本来就该变"还是"生成器算错了"**,
#### 阶段 4:门禁 + 负控
- [x] `test/theme/token_codegen_test.dart`,判据照 §4.2
- [ ] 三个负控全部真跑,输出贴进 PR(照 §4.3)
- [x] 退役今天临时加的 `test/theme/cy_palette_parity_test.dart`
#### 阶段 5:文档与交接
- [x] `cy_palette.dart:13` 那句注释订正:现在它指向 `cy_palette_parity_test.dart`,
- [x] 在 `docs/` 或本文件补一段「小程序改了 token 之后,App 侧要做什么」的三行操作指引

## Source: 城瘾vault/04-未开始/Figma玩法稿_UX借鉴板待办清单_20260827.md

### 1. ADA 借鉴卡(node 52:292)—— 5 条,带成本评估
- [x] **A. 城市贴纸图鉴** ← CapWords(2025 Delight 得主)· 成本低
- [x] **B. 天色系统** ← Moonlitt(2026 Interaction)+ Tide Guide(2026 Visuals)· 成本中
- [ ] **C. 过程即满足** ← PowerWash Simulator(2026 Delight 得主)· 成本中
- [x] **D. 每日一句** ← grug(2026 Delight 得主)· 成本极低,稿建议「首个上」
- [ ] **E. 零文字上手** ← Sago Mini(2026 Interaction+Inclusivity 双得主)· 成本低
#### 与已做玩法直接相关(建议优先)
- [ ] 🗺 **优秀地图 UX · 探索、导航与回忆闭环** — Fog of World / Geocaching / Polarsteps
- [ ] 🏅 **获奖 UX · 现实行动、内在动机与收藏** — CapWords / Spark / Any Distance
- [ ] 🌙 **低压游戏循环 UX** — Focus Friend / Pokémon Sleep / Waterllama
- [ ] 🕰 **反 FOMO UX · 错过仍可追回** — Pocket Camp / DRG Season
#### 团队与社交(俱乐部/组队相关)
- [ ] 🤝 社交游戏循环 — Pokémon GO Weekly / Pikmin Bloom / Forest
- [ ] 🤝 共同决策与温和进度 — 让团队真的走到下一步
- [ ] 🤝 公平竞争与低压力社交 — Apple Fitness / Peloton / Duolingo Friends Quest
- [ ] 👥 共享会话 UX — Wavelength / Spotify Jam(建房、加入、共同操作、重开)
- [ ] 🛟 实时同行与安全到达 — Flighty / Transit / Apple Check In
#### 任务与反馈质量
- [ ] 🧭 现实任务与无障碍 — 3D City Route Replay / Opal / Stamply
- [ ] ✦ Field Mission UX — Goosechase / Seek / Too Good To Go
- [ ] ✦ Event Attendance & Recovery — Partiful / Luma / Be My Eyes
- [ ] 🫧 低注意力持续任务 — Crouton / SmartGym
- [ ] 🧭 渐进式目标 — Stitch / Alba(全局契约 → 局部行动 → 确定回执)
#### 交互质感
- [ ] ✦ 优秀动效 UX — Been / Vercel map morph / Spotify bouquet
- [ ] ✋ 直接操控 UX — Flashback Zipper / Google Pay Scratch / Threads Overscroll
- [ ] 🫳 低说明成本 UX — Rytmos(撕开、画线、转动手机)
- [ ] 🧭 路线与人性化 — AllTrails Preview / Strava Flyover / Gentler Streak
- [ ] 🎧 环境感知与即时发现 — Shazam / Merlin(听见、对齐、确认)
#### 失败与复玩(容错设计)
- [ ] ↩️ 可逆挑战 — Art of Fauna(换解法、保全损失、离开后继续)
- [ ] ↩️ 失败之后仍然想继续 — Hades(可逆编辑、分级提示、失败前进)
- [ ] 🌱 非操纵复玩 — 世界会继续,回来没有债

## Source: 城瘾vault/04-未开始/Questify_住得更像自己_一平方米空间焕新_即插即用自由探索模板_20260820.md

#### 4.6 MVP城市实例的标准供给
| ORDER | 2 | 提供不同成本或服务方式 |
| FUNCTION | 2 | 提供不同功能路径 |
| CHARACTER | 2 | 提供不同表达方向 |

## Source: 城瘾vault/04-未开始/Questify_第三个大众自由探索候选_市场研究与方向选择_20260820.md

### 2. 三候选加权评分
| 大众需求广度 | 18 | 16 | 18 | 12 |
| 可重复触发频率 | 10 | 7 | 10 | 6 |
| 商家商业意图 | 14 | 11 | 13 | 13 |
| 商家角色互补性 | 14 | 12 | 11 | 10 |
| 结果相对现有产品的增量价值 | 18 | 14 | 5 | 9 |
| 即插即用与静态数据适配 | 16 | 10 | 4 | 8 |
| 与既有Questify主题错位 | 10 | 9 | 4 | 3 |

## Source: 城瘾vault/04-未开始/俱乐部信息架构真源_双身份视图与按项目组织_20260809.md

### 1. 术语对齐
| **进入群聊** | CTA:`index.wxml:85-86` → `goGroupChat()`(`index.js:842-856`)→ `POST /api/club/chat` → `/subpackageB/pages/im/chat/index` | 与「群组」同源,是真正清晰可预期的入口。member 删掉 quick-act 后仍从这里进群聊。 |
| **发布主题** | 当前按钮写「发布路线」:`index.wxml:88` → `onCreateTeam()`(`index.js:689-698`)→ `/pages/publish/topicadd/topicadd?clubId=…&mode=…` | **用户叫法比现码准确**:路由是 `topicadd`,行为是创建俱乐部主题,按钮误写成「发布路线」。目标文案统一改为**发布主题**,不再沿用「路线」。 |
| **我的项目** | `goProject()`:`detail/index.js:277-280` → `/subpackageA/pages/myproject/index`;详情页入口在概览「运营管理」项目格 `index.wxml:181-183`;工作台还有一处 `workbench/index.wxml:116-121` | 现有「我的项目」是**全账号、跨身份、跨俱乐部**的项目容器(主题 / 活动 / 模板),路由不带 `clubId`,`onLoad` 也不消费 `clubId`。**它不等于「当前俱乐部的项目」。** |
| **商家(主理人页面下面是商家)** | owner-only「可对接商家」:`index.wxml:248-262`;数据 `/api/club/merchants`(`index.js:247-257`);卡片进 `/pages/merchant/profile/index`;「发邀请」进 `/pages/coop/invite/index?type=0…`(`index.js:396-409`) | 这里的「商家」是 **owner 的合作资源区**,不是「商家访客身份」。区块确实存在,但排在运营管理、收益、简介、成员、贡献榜之后,K09-s3 才看到。 |
| **主理人** | `club.isOwner`,由 `/api/club/detail` 按当前 memberId 与 `club.member_id` 比较后设置(`ApiClubController.java:447-465`) | 详情页 owner 真源。**不能拿 `app.getUserRole()==='club'` 代替** —— 角色与「是否拥有当前 clubId」不是一回事。 |
#### 7.1 【已拍板】工作台回到俱乐部页,按项目组织,收益全部搬走
| 俱乐部页活动列表点进去 | `detail/index.js:862` → `/pages/topic/index/index?id=`(**玩家视图**) | 主理人 → `/pages/topic/merchantinfo/merchantinfo?topicId=`(主办视图) |
| 主办视图入口 | 全仓只有 `subpackageA/pages/myproject/index.js:221` 一处 | 俱乐部页的项目列表直接进 |
#### 7.4 owner 顶部阶段链:发布主题 → 邀请商家 → 查看邀请进度 → 管理项目
| 当前俱乐部没有主题 | `发布主题` | 进入 `topicadd`,绑定当前 `clubId` | `club.topicCount` 已由 `/api/club/detail` 返回(`java:455-459`) |
| 有主题、没有发出有效邀请 | `邀请商家` | 先选择**当前俱乐部主题**,再进入商家邀请 | 详情页没有 ready 字段;工作台用 `/api/coop/list.sent` + 当前 club 的 `topics[].id` 派生(`workbench/index.js:216-269`) |
| 至少一个主题已由商家承接 | `管理项目`(文案见 §10 P2) | 进入本俱乐部项目列表 → 主办详情 | `/api/project/my` 行已有 `clubId` 与 `acceptStatus`;俱乐部主题被商家接受时为 `merchantAccepted`(`ApiProjectController.java:246-288`) |
#### 11.1 会撞的既有契约
| 「开一场」仅 owner,可开主题来自 `/api/club/open-session-topics` | `club-session-open.test.js:41-71` | 即使「开一场」移入项目/管理 tab,身份与生效合作门禁不能放宽给 admin。 |

## Source: 城瘾vault/04-未开始/城瘾App_Flutter全量化施工规划_20260818.md

#### 1.2 已通的能力（可直接继承，不要重做）
| **四种打卡闭环**：扫码 / GPS到达 / 答题 / 拍照传OSS | commit `c87131f` `a7e8524` `972196c` `fda4189`，接 `/api/play/*` |
### 2. 缺口矩阵（111 页 vs 46 dart）
| 商家端 `pages/merchant` | 18 | **0** | 18 | 账本/装修(story,gallery,perks,coop-setting)/招商/核销/客户/城市节点 |
| 招商 `pages/coop` | 8 | **0** | 8 | 邀约/附近/候选/财务/结算明细/**提现×2** |
| 发布器 `pages/publish` | 8 | 1（壳） | ~7 | 最重单块：复杂表单+地图选点+路线编辑 |
| 俱乐部 `pages/club` | 9 | 3 | 6 | 工作台/入会审批/解散闸/群码/申请/创建/编辑 |
| 主题 `pages/topic` | 5 | 2 | 3 | 商家申请/定价/伙伴定价（招商侧） |
| 会员 `subpackageMember` | 14 | 2 | ~10 | 订单/参与/邀请/**提现×2**/投诉/券码/报名 |
| 集邮+勋章墙 `subpackageP3` | 7 | 0 | 7 | ⚠️含 `xr-badge` (xr-frame WebGL 3D) |
| 漫游 `subpackageRoam` | 4 | 3(基础地图) | ~3 | 会话/历史/POI详情/城市节点码 |
| 活动 `pages/activity` | 6 | 3 | 3 | 官方局：详情/收件箱/我的 |
| 资产 `subpackageA` | 5 | 1 | 4 | 收益明细/收入详情/资讯 |
### 3. 苹果 iOS 上架合规件
| **App 内账号删除**（Guideline 5.1.1(v)） | 后端**已有** `/api/user/deregister`（预检/申请/撤销/状态四接口） | 前端接一下即可，低成本 |
#### 阶段二 · App 只做探店日（约 2 个月，后半段可与阶段一并行）
| 苹果合规件 | 账号注销（后端 `/api/user/deregister` 已有，接即可）＋ `PrivacyInfo.xcprivacy` | 0.5 周 |
#### v1.0 — C 端玩家闭环（约 2.5 个月到上架）
- [ ] 落地 8 个未提交改动 / 决定去留
- [ ] **接口 diff：追平 6-25 → 8-18 的后端漂移**
- [ ] **后端新增 APP 支付下单**（trade_type=APP）+ 开放平台移动应用申请 + 商户号绑 APPID
- [ ] Flutter 结算页 + fluwx 支付回调 + 幂等
- [ ] 会员订单侧：订单/订单详情/我的参与/参与详情/票券/券码
- [ ] 官方活动 3 页
- [ ] 设置/协议/个人资料/地址/裁图/收藏
- [ ] **账号注销**（接 `/api/user/deregister`，苹果硬要求）
- [ ] **PrivacyInfo.xcprivacy**
- [ ] 真机全链路联调 + 审核材料
#### v1.1 — 商家与招商（+1.5 个月）
- [ ] 商家端 18 页
- [ ] 招商 coop 8 页（**提现/财务见 v1.2 资金纪律**）
- [ ] 主题招商定价 3 页
- [ ] 俱乐部管理 6 页
#### v1.2 — 资金域 + 重块（+1.5 个月）
- [ ] 资金域：提现×2 / 账本 / 结算明细 / 分账台账 / 收益
- [ ] 发布器 8 页
- [ ] 集邮 + 勋章墙 3D（建议 WebView 复用现有 WebGL 引擎）
- [ ] **漫游补全**：会话/历史/POI详情/城市节点码（按 §5.0 后置至此）

## Source: 城瘾vault/04-未开始/小程序做不到而App能做_能力盘点与落地方案_20260820.md

### 6. 拍板记录([number])
| 1 | 推送通道选型 | 极光 JPush | **✅ 极光 JPush**(采纳) | 第 1 周启动极光 + 五家厂商账号注册 |
| 2 | 后台定位隐私政策增补谁定稿 | 我起草、你终审 | **✅ 我起草、你终审** | 草案见 §7,待终审 |
| 3 | 小组件/灵动岛做不做 | 上线后再评估 | **✅ 现在就排**(推翻我的建议) | 提级 P1-3;`app_device_token` 加 `token_type`;工期 3 周 → 5 周 |

## Source: 城瘾vault/04-未开始/探店日方案_三玩法三身份商业模式总纲_20260813.md

#### 1.3 容量守恒
| 5 分钟 | 2 | 54 人 | 容量充足，但必须防止体验过浅 |
| 6–7 分钟 | 2 | 38–45 人 | **默认区间** |
| 8–10 分钟 | 3 | 40–50 人 | 仅适合专业微体验，须另用 20 分钟批次 |
| 15 分钟 | 4 | 36 人 | 默认禁用，成本和排队过重 |

## Source: 城瘾vault/04-未开始/探店日施工审计_1_交易骨架_20260814.md

### 〇、一页结论
| P0 | 商家主题的俱乐部承接 | 商家发主题不能直接开售；必须有已接受的 type=1 商家→俱乐部承接关系，俱乐部从主题履约窗内排场次。删掉 type=2 商家→商家节点邀约。 | `CoopInvite:22-35`；`pages/coop/invite/index.js:14-17,328-332`；`TopicSaleTimeValidator:74-93` |
### 一、现状全表
| 已有 | D1 活动壳购买路径真实通电：活动票回溯 `activity.topicId`，按主题 `productType` 推导 `EXPLORE_PASS`，并预占权益。 | `CmsRegistrationServiceImpl:394-412,509,573-595`；`ExploreSellGateTest:130-147` |
| 已有 | 商家→俱乐部邀约 type=1 已是现有交互方向，邀约页也默认 type=1。 | `pages/coop/invite/index.js:14-17,330-332`；`CoopInvite:22-35` |
| 半成品 | 退款+新购可由现有退款与活动报名串联；小程序活动报名仅处理未支付失败取消，没有改场选择或可审计的推荐流程。 | `ApiRegistrationController:173-199,281-300`；`pages/activity/baoming/baoming.js:946-965` |
| 不存在 | 商家主题必须由已承接俱乐部开售的 FREE_EXPLORE 专属闸；现有码仅有邀约 UI，不见该终检。 | `pages/coop/invite/index.js:14-17,330-332`；`[id]:82-100` |
### 二、施工项
| S1 | **修活动票投影，且只修应修的 6 字段。** 在 `OmsTicketServiceImpl.copyTopicTicketsToActivity` 统一复制 `signupDeadline/gatherLng/gatherLat/refundRule/subType/needAudit`，并保留 owner、id、remaining inventory 等目标侧重置语义；`minPeople/maxPeople/teamStatus` 显式不复制。同步补 `views/business/activity/detail.vue` 手建活动票表单的集合点、经纬度、报名截止与退款/审核所需字段；主题表单同口径。 | D1 下玩家买的是活动票，自动复制与手建票都是写入口。把旧成团字段复制过去会把从未通电的语义重新接回；只修复制不修手建入口仍可绕过。依据：`OmsTicketSer
| S6 | **商家主题必须转交俱乐部承接。** 在商业局开售审前/终检内增加 FREE_EXPLORE 专属断言：若主题由商家发起，必须存在与该主题关联、已接受、有效的 type=1 商家→俱乐部承接；承接俱乐部作为场次配置和履约组织责任方。场次开始/结束仍由俱乐部在主题履约窗内指定，不取 `ClubSessionServiceImpl` 的整天 dayBoundary 作票时段。 | ①已具备“商家主题绑俱乐部”方向，③补缺口。商家不具主办招商、现场组织、客服能力；俱乐部才有开场、巡场、收尾的排期需求。此项不等同 H7 资质审，后者明确暂缓。依据：`CoopInvite:22-35`、`pages/coop/invite/index.js:14-17,330-332`、`TopicSaleTimeValidator:74-93`、`ClubSessionServiceImpl:95`
| S7 | **删除 type=2 商家→商家节点派发。** 删除 `CoopInvite` type=2 受理/校验/候选入口、`pages/coop/invite/index.js` 的 tab、`pages/coop/invite/index.wxml` 的 tabs 与相关测试；旧数据仅只读展示或按不可操作历史处理，不迁移成新的主办关系。 | type=2 的“你来卖你自己的东西”假设不再成立；活动组织是主办责任，商家没有此能力。此项不删除 `cms_topic_node.merchant_member_id`：商家仍可由俱乐部/平台招商进入节点，只是入口不再是商家派商家。依据：`CoopInvite:22-35`、`pages/coop/invite/index.js:14-17,328-332`、`pages/coop/invite/index.wxml:5-6`、裁决表 H
| S14 | **保留退款+新购，不造改场负债。** 退款成功后仅引导到活动票列表；可基于同 SKU/同价展示“改场建议”，但不得改写原 registration 的 ticket、不得承诺目标库存、不得建立跨期本金转移。后台审核退款补票库存回补。 | 现有小程序没有改场选择，专门的改票 service 也不存在；伪造改场会漏库存、退款截止和权益重算。后台审核退款不回补是独立已知缺口。依据：`CmsRegistrationMapper.xml:322`、`pages/activity/baoming/baoming.js:946-965`、`RefundServiceImpl:607-645`、`CmsRegistrationServiceImpl:2196-2201`。 |
| S15 | **一账号一票与积分关闭按既定 D2/D3 收口。** 在活动壳的注册建单前按 member+topic 有效票限一；对 FREE_EXPLORE 明确禁用 `isUsePoint`，使开售审快照的全价和实际成交口径一致。并发以数据库唯一/锁定策略而非单纯先读后写兜底。 | 当前 qty=1 不是账号期次唯一；积分计算仍可扣，导致票价事实失真。此项不复活最低报名人数。依据：`CmsRegistrationServiceImpl:442-455,463-480,693-698,950-975`；裁决表 D2/D3/H11。 |
### 三、负控判据
| S15 D2/D3 | FREE_EXPLORE 传 `isUsePoint=1`；同 member 同 topic 第二次建单；第一张退款后再次购买。 | 第一种在建单前拒绝且无扣积分；第二种拒绝且无库存/权益变化；第三种按有效票口径放行。 |
### 五、待验证
| 退款+新购的小程序真机体验 | 裁决已限定“退款+新购”，未知的是支付回调、退款完成页和目标票售尽提示是否在真实微信端可达。 | 真机完成退款、回到活动票列表、售尽目标点击；不得出现“已改场”或占位承诺。`pages/activity/baoming/baoming.js:946-965`。 |
### 七、合并记录
| B 补入 | **6 条成立信息**：`ExploreSellGateTest:130-147` 作为活动壳真实路径证据；`pages/activity/baoming/baoming.js:946-965` 不承载改场选择；退款+新购仅可作同 SKU/同价建议、不建跨期负债；不存在结论采用完整 `rg` 方法纪律；本次仓库只读声明；活动壳复制与活动票终检的简洁风险表述。 |

## Source: 城瘾vault/04-未开始/探店日施工审计_4_三身份与数据边界_20260814.md

### 〇、一页结论
| P0 | 商家读面收窄并补身份门禁 | `/api/merchant/customers` 仅取登录 memberId 后直接下发名册，无 `isActiveMerchant`；服务按中标主题和本人主题聚集全量报名，并下发 `totalAmount`。`ApiMerchantController.java:1082-1088`；`ProjectPlayerReadServiceImpl.java:231-263,296-339`。探店日必须改为“本店进店事实 ∪ 本店核销”且只用白名单 VO。 |
### 一、现状全表
| 商家俱乐部列表 | 不安全 | 接口直接返回 `clubService.selectClubList(query)`，未取 current member，更未 `isActiveMerchant`；相邻接口已有可复用门禁。 | `ApiMerchantController.java:460-466,468-510`；`ClubMapper.xml:61`；`PublicClubVO.java:7` | 改成商家门禁 + `PublicClubVO`，并逐字段核对 `pages/coop/invite/index.js:211`。 |
| 商家客户名册 | 不安全 | 端点无商家能力门禁；服务按“中标主题 + 本人主题 + 自办活动”汇总主题全量报名，逐行含金额、画像、电话。 | `ApiMerchantController.java:1080-1088`；`ProjectPlayerReadServiceImpl.java:231-263,296-339,438-444`；`pages/merchant/customer/index.js:174-187` | 探店日不复用跨项目 CRM 名册；改新窄投影，只给本店进店或已核销的人，删除金额/画像/跨店状态。 |
| `/api/project/players` | 发布者或有任意中标记录者可读主题已付和退款报名；行含 `registrationId,ticketId,ticketName,ticketNo,participateDate,state,arrived,arrivedTime,avatar,name,phone`。 | 仅 FREE_EXPLORE 分支替换为本店章节窄投影；①②保持现状。退款/失效 entitlement 不在探店日名单。 | `ProjectPlayerReadServiceImpl.java:79-111,125-158`；`ApiProjectController.java:108-131` |
| `/api/merchant/customers` | 中标主题、本人成题和自办活动均被并入；跨主题按人折叠，含本店外的计数、最近行为、分层、金额及可能电话。 | FREE_EXPLORE 不进入该跨项目 CRM 名册；另设按商家×期×章节的现场名单。 | `ProjectPlayerReadServiceImpl.java:231-263,286-339,438-450`；`pages/merchant/customer/index.wxml:32-40` |
| `/api/merchant/verification-records` | 以登录 merchant memberId 过滤自身核销流水，实体字段较多但范围正确。 | 不用它替代按章节名单；继续只允许运营/商家自身访问，必要时另做白名单。 | `ApiMerchantController.java:1005-1018` |
| `/api/merchant/orders` | 以 `mms_merchant_id` 锁卖家，收货姓名/电话/地址经 TypeHandler 解密后直出，业务上用于发货。 | 该物流面不因探店日名单收窄而改变；不得以它证明商家有权读现场玩家电话。 | `ApiMerchantController.java:1021-1078`；`migration_order_pii_encryption.sql` |
| `/api/merchant/upcoming-runs` | 无 PII，但 `paidCount` 按整主题已付人数统计。 | 探店日改成本商家章节“已售/已核销”，不得把它称为到场 A 或 `in_store_load`。 | `[id].java:46-144`；裁决表“人级漏斗”引用 |
| `/api/merchant/funnel` | signup/verified 统计中标 topic 的全量报名，而非本商家站点。 | 探店日以章节 entitlement 过滤；到场率直接引用文档 3 的漏斗查询，禁止在本文另造 A/C。 | `ApiMerchantController.java:940-991`；`[id].java:133-134` |
| `/api/merchant/relation-home` | 联系方式仅在显式 topicId、该邀约、已接受三条件同时成立时展示。 | 可复用其“具体对象+已建立关系”形状，但不能复用为现场玩家同意。 | `[id].java:193-231`；`ApiMerchantController.java:468-493` |
| 公开俱乐部资料 | `PublicClubVO` 已声明不得含申请资料、联系方式、审核内部字段；公开 list/detail 使用它。 | `/api/merchant/clubs` 也必须使用同一 VO，不准第二套手写白名单。 | `PublicClubVO.java:7`；`ApiClubController.java`；`ApiMerchantController.java:460-466` |
### 二、施工项
| S1 | **堵两条商家读面。** `ApiMerchantController.clubs` 加登录和 `isActiveMerchant`，返回 `PublicClubVO`；`customers` 同样先校验有效商家。位置：`ApiMerchantController.java:460-466,1082-1088`、`PublicClubVO`、对应 controller tests。 | 防普通登录用户拿俱乐部电话/审核资料，也防 PLAYER 用本人主题拿名单。`/clubs` 唯一 XCX 消费方是 `pages/coop/invite/index.js:211`，变更前需按实际 key 做兼容核对。 |
| S2 | **探店日新建本店名单投影，替换而非污染共享路径。** 在 `ProjectPlayerReadServiceImpl.listPlayers` 以 `ProductType.FREE_EXPLORE` 分支；探店日只查询商家中标章节 C 内、存在本店 `player_node_progress` 进店事实或本店 `registration_entitlement.status=1` 核销事实的人。位置：`ProjectPlayerReadServiceImpl.java:70-111,228-345`，新 mapper/VO；`ApiProjectController`、`ApiMerchantController`、`pages/topic/merchantinfo/*`、`pages/merchant/customer/*`。 | ①②继续需要主题主办方全量名单，不能被
### 三、负控判据
| S1 `/clubs` | 用普通 PLAYER 调 `/api/merchant/clubs`；或把 `PublicClubVO` 换回 `Club` 实体。 | 前者业务拒绝；后者隐私契约测试必须检测到 `phone/rejectReason/certImages` 等键而红。 |
| S1 `/customers` | PLAYER 自建一条主题后调用 `/api/merchant/customers`；或把 `isActiveMerchant` 删除。 | 必须拒绝，不能因 topic.memberId 相同得到名单。 |
### 四、边界引用
| 裁决表 0 号表 | D1 活动壳；D2 积分抵扣关闭；D3 一账号一票；H1–H11；偏离 3；玩家能力边界 |
### 七、合并记录
| B 补入（7 条归并） | 补入 `/api/merchant/customers` 无商家门禁的 PLAYER 越权 P0、CRM 迁移/回填不能由静态代码证明、发布路径须 API/service 双层拒绝、迁移应先扩展/回填/对账再切读、会员权益不得交换手机号、测试实际接线、俱乐部工作区尚未通电到 XCX。 |

## Source: 城瘾vault/04-未开始/探店日施工审计_5_漫游与导流_20260814.md

### 〇、一页结论
| P0 | 免费层隔离与红线门禁 | 漫游只写漫游到访，不再调用 `/api/play/arrive`；禁止付费墙、前置顺序、指向性导航、非本人轨迹的路线和带前瞻指引的回顾内容。 | `pages/roam/index.js:2785-2982`；`ApiPlayProgressController.java:681-733`；`OfficialEventV2ServiceImpl.java:667/798/822/1691-1733` |
| P1 | 首三期导流位 | 只在「首次发现商家」二选一卡中向符合地理半径与运营开关的玩家显示活动壳入口；不复活结算页 reco，不启用画像或人群快照表。 | `pages/roam/index.js:2919-2938`；`pages/roam/index.wxml:591-593`；`utils/wxs/hud-slots.wxs:56-59` |
### 一、现状全表
| 已有 | `migration_roam.sql:38-55` 的 `roam_poi` 保存类型、坐标、半径、XP、券模板、城市与状态；`pages/roam/index.js:1276` 的 `node_level` 只影响 marker 样式。 | 当前 schema 没有 POI 前置/解锁字段；展示等级不可被误用为可达性。 |
| 已有 | `pages/roam/index.js:2259-2269,2494-2503` 的地图线来自本地 `this._track`；全 roam 目录未见 `wx.openLocation`，`arrowLine` 不在 roam 页。 | 这是玩家已发生的个人轨迹回看，可保留；不得替换为服务器路线、目标连线或导航。对外不能再命名为「漫游路线」。 |
| 半成品（需收口的正向契约） | 结算把 `res.data.routeStory` 放入 `finish.routeStory`（`pages/roam/index.js:1139-1144`），WXML 渲染该字段（`index.wxml:514-518`），后端构造/记录「漫游路线故事」（`ApiRoamController.java:433-437`）。`tests/unit/roam-ai-foundation-contract.test.js:11,47-65` 断言它存在。 | `routeStory` 可保留为事后足迹回顾；需要把测试补成禁止「下次/建议/先…再…」等前瞻引导，并把 UI/分享文案从路线改为足迹。 |
| 已有 | 商户型 `roam_poi` 在 `onMarkerTap` 先分流到 `roam-poi-detail`（`pages/roam/index.js:2648-2652`），页面完成调用 `/api/city/nodes/{id}/complete`（`components/cy/scene-roam-poi-detail/index.js:190-218`），服务端做距离、扫码和幂等校验（`ApiCityNodeController.java:158-224`）。 | 商户型漫游 POI 已有独立完整路径；不得因删除 `/api/play/arrive` 误伤它。 |
| 缺口（已通电的越线能力） | 官方活动任务在运行期调用 `prerequisitesCompleteNow`（`OfficialEventV2ServiceImpl.java:667,798,822,1691-1707`），完成还比较前置证据时间（`:1713-1733`）；任务 overlay 在 roam 页构建（`pages/roam/index.js:1000-1016`）。 | `prerequisite_json` 不是哑字段；只要后台存量有值，漫游免费层可出现任务先后关系。应按裁决移除输入、标记字段弃用，并把它列进红线门禁。 |
| 缺口 | 漫游打卡并行调用 `_sendCheckin` → `/api/play/arrive` 与 `_apiShopVisit` → `/api/roam/shop/visit`（`pages/roam/index.js:2785-2786,2952,2982`）。前者带 play 域校验（`ApiPlayProgressController.java:681-733`）。 | 同一玩家动作写入两套语义账本；免费层会碰到主题通行证或进度条件。必须删除前端到 play 的调用，而非放宽 play 控制器。 |
| 已有 | `/api/map/nearby` 映射给漫游的报名商家仅含 `nodeId/topicId/regId`，没有 `activityId`（`pages/roam/index.js:818-846`）；`resolveCtx` 在无活动上下文时走自玩路径（`ApiPlayProgressController.java:1013-1043`）。 | 没有主题通行证的漫游玩家会先撞自玩通行证闸；这是当前最常见的免费层付费话术来源。 |
| 半成品「三层死」 | `_fetchReco`、`retryReco`、`onRecoTap` 在 `pages/roam/index.js:3215-3241`；WXML 已把对应入口下线为注释（`pages/roam/index.wxml:591-593`）。 | 结算页 reco 已被裁决不复活；相关 data、请求、点击和埋点应随导流位迁移删除。 |
| 缺口 | 客户端独有且实际 fire 的包括 `roam_discover_reward_click`（`pages/roam/index.js:2932,2937`）、`finish_route_recommendation_shown/click`（`pages/play/index.js:2281`、`finish-route-recommendation.js:40`）及 `npc_chat_submit/complete/cancel`（`components/cy/npc-chat/index.js:77,185,212`）。 | 需要将实际投递事件纳入服务端或收敛客户端；`roam_share_channel` 两端均无而被静默丢弃（`pages/roam/index.js:3303`），应两端同步补齐。 |
| 缺口（低于 P0） | `_realTick` 对精度差、静止和单帧大于 120m 分别直接返回；大跳分支只更新 `_player`（`pages/roam/index.js:2458-2470`）。 | 锁屏/后台恢复后的首帧可能少累计端上距离、少一段足迹、少一次附近检查；服务端到点请求仍取更新后的 `_player` 并二次距离校验，故不等同于伪造或丢失服务端到访事实。 |
| 不存在 | 全库没有可用商圈实体；`district` 仅见展示性字符串，且无商圈表/键。漫游玩家侧也没有独立探店日页，`pages/explore/index.js` 是空脚手架。 | 「同商圈」首三期只能由活动集合点与玩家当前坐标的固定地理半径表达；CTA 先落主题详情/活动壳，不虚构新页。 |
### 二、施工项
| S1 | **删除漫游对 play 的调用。** 在 `chengyinhub-xcx/pages/roam/index.js:2804-2831,2950-2963` 删除 `_apiCheckin/_sendCheckin` 和 `/api/play/arrive` 请求；由 `/api/roam/shop/visit` 的 `recorded` 决定漫游完成态，保留其来源 `regId` 的 server-side 校验。 | `ApiPlayProgressController.java:681-733` 是经典定向/其他玩法的共用进度入口，不能为漫游加豁免。删除客户端调用即可隔离语义，不改后端 play 判定，也不把漫游 GPS 到访写成文档 3 的 `player_node_progress`。 | 免费漫游玩家不再看到买票/上一站话术；持主题票者不再意外推进主题进度；`A
| S2 | **免费层红线门禁与足迹表达收口。** 在 `chengyinhub-xcx/scripts/roam-redline-gate.js` 新建带 `--selftest` 的门禁，并同时挂到覆盖 `chengyinhub-xcx/**`、`ApiRoamController.java`、`RoamMapper.xml`、`ApiPlayProgressController.java` 的 CI job。保留来自 `this._track` 的个人轨迹与 `routeStory` 事后回顾，但将 UI/分享卡 `routeName` 及「漫游路线」标题改为足迹回看，并限制 AI 回顾不得出现下一步建议、顺序或导航。对应改 `pages/roam/index.js:2259-2269,2494-2503,1139-1144`、`index.wxml:514-518`、`ApiRo
| S3 | **首三期最小导流位。** 复用 `pages/roam/index.js:2919-2938` 的「首次发现商家」`discoverReward` 二选一卡，增加第三个可关闭选项；不复活 `reco`。新增只读 `GET /api/roam/nearby-exploreday`：只返回已由平台开售审核通过、允许漫游导流且集合点距当前坐标不超过固定 1500m 的活动壳候选；无候选则不渲染第三项。`cms_topic` 增「允许漫游导流」逐期运营开关，默认关闭；曝光/点击用 `roam_exploreday_reco_shown/click`，订单归因按文档 2 的不可变票源规则记录。 | 首三期用「地理半径 + 平台手动开关」，不是画像、不是人群名单表、不是实时商圈实体。开售资格必须来自新裁决：商家发主题先由俱乐部承接；只有商业局（收费票、招商、商家供给位任一为真）走立项审
| S7 | **恢复首帧附近检查，不造后台定位。** 在 `pages/roam/index.js:2458-2470` 将大跳的「更新 `_player` 后直接返回」改为按时间/速度判定：可疑瞬移不累距、不连线、但仍执行当前位置附近检查；合理的恢复位移可记录断段和当前点揭雾，绝不沿未知路径连线或揭雾。`gapCount` 随既有 finish 请求上报，仅作观测。 | 当前 bug 是端上展示/浮卡机会缺口：`onHide` 已显式暂停（`pages/roam/index.js:548-556`），服务端 `/poi/discover` 与 `/shop/visit` 仍用当前坐标二次 haversine 校验。不能把它夸大成服务端履约证据缺失，也不能以开启后台定位解决。 | 漫游 HUD、距离显示、足迹/分享渲染、位置单测。需先检查 `_calcArch`（`pages/roam/
| 顺序与前置 | `pages/roam/**`、`ApiRoamController`、`RoamMapper.xml` 及 roam 页实际请求的接口；重点扫描 `nextNodeId`、`unlockAfter`、`isPrevDone`、`prerequisite`、`prev*` 和「请先完成上一」类返回。 | 非漫游页面的经典定向进度；仅用于后台迁移兼容且不可从 roam 请求到达的历史代码。 | POI 的可见、发现、揭雾、完成或奖励取决于另一个 POI/任务；官方任务 overlay 中出现运行期前置求值。 |
### 三、负控判据
| S1 免费层隔离 | 用无主题通行证账号对 `/api/map/nearby` 返回的报名商家打卡。 | 改前应能复现 `/api/play/arrive` 的「请先购买自玩通行证」或 `checkinOk=false`；改后若漫游仍发该请求、出现该文案或写入 `player_node_progress`，测试/接口回放必须失败。 | `/api/roam/shop/visit` 返回 `recorded=true`，完成态正常，`player_node_progress` 无新行。 |
| S1 防误伤 | 对 type=2 的 `roam_poi` 执行 `onMarkerTap → roam-poi-detail → /api/city/nodes/{id}/complete`。 | 删除 `_sendCheckin` 后若该路径无法完成、扫码错店未拒绝或幂等失效，必须红。 | 改动前后行为一致，仍由 `ApiCityNodeController.java:158-224` 校验。 |
| S2 导航 | 在 `pages/roam/**` 加 `wx.openLocation`、`arrowLine:true`、下一站坐标或方向文字。 | gate 必须红；不得只靠文案单测放过图形导航。 | 现有 footprint 文案测试仍绿，且静态 gate 覆盖 JS/WXML/map 数据绑定。 |
| S2 访问权付费墙 | 在 `selectPoisNear` 增加 registration/ticket/entitlement 过滤，或让漫游可达接口返回「请先购买」。 | gate 必须红；这条应先对现有 `/api/play/arrive` 路径做一次变异/回放，证明门禁能抓真实漏洞。 | 免费玩家仍可发现、到点和完成普通漫游点；商业活动 CTA 只是可关闭推荐，非继续游玩的条件。 |
### 五、待验证
| 复访报表 | 观察窗与生产数据成熟度只能随时间出现；不能在今天凭空证明 D90。 | 真库只读样本：同会话去重、跨会话计入、未成熟 cohort 明确标注；D7/D30/D90 分别在到期日后复核。 |
### 七、合并记录
| A 版贡献 | 保留并压缩为：漫游事实三分、`/api/play/arrive` 穿透链、官方任务前置活链、白名单整批阻塞、首次发现商家卡、双复访口径、首帧丢段、召回关闭、跨栈 gate、三类 ID/时间字段陷阱、商户型 POI 分流保护等可施工结论。 | 14 条 |
| B 版补入 | 吸收：`routeStory` 的后端/页面/CI 正向契约、分享卡「漫游路线」文案、画像 upsert 覆盖陷阱、`route` 多义性扫描边界。B 提出的结算页卡位、人群快照表、商圈实体假设及把 D90 付款并入本文，均未采用。 | 4 条 |

## Source: 城瘾vault/04-未开始/探店日未派发遗留持续清单_20260815.md

### [number] UI 修复批遗留(commit `a35ba59a1`,分支 `liboyang42-cpu/tandianri-uifix-play-0815`,未 push)
| U4 | [number] | subpackageMember/signup + /api/registration/list | 票夹场次 tab 时间源仍为 cmsActivity.startDate(活动级);场次槽级时间需列表接口附票种快照 | 低 | 待派 |
| U5 | [number] | pages/topic/index | F8 已购态 CTA 置灰(现仅活动详情层有 isSignUp toast 兜底) | 低 | 待派 |
| U6 | [number] | pages/play/index.js:1496 | preview/mock 态 mode2 扫码仍走 onComplete(仅预览态可达,不影响真实玩家) | 观察 | 未处理 |
### [number] 跨批终审新增持续遗留
| N1 | `ApiMerchantController.java:456-462` | P0（存量） | 未处理：master 既有 `/api/merchant/clubs` PII 暴露面，需独立安全修复。 |
| N6 | `pages/play/merchant/index.js:171-178` | 低 | 未处理：客户端同意态未比较 `docVersion`，服务端仍 fail-closed。 |

## Source: 城瘾vault/04-未开始/模板库档B_声明式玩法DSL_spec_20260906.md

### 1. 为什么要做 —— 一个能数出来的理由
| 1 | 文字答案 | 后端 |
| 2 | 拍照打卡(可带 `filter_shot` 伪 AR 子类) | 后端 + App 滤镜 |
| 3 | 选项题 | 后端 |
| 4 | 扫码核销 | 后端 |
| 5 | GPS 到达 | 后端 |
| 6 | 偏好题组 | 后端 |
| 7 | App 专属传感器(still / steps / audio_clip) | App 采集 + 后端指纹校验 |

## Source: 城瘾vault/04-未开始/毛孩子探店日_合伙人俱乐部计划书_三deck整合_20260816.md

### 三、新计划书逐页蓝图(17 页)
| 1 | 封面:城瘾 × 毛孩子探店日 | 主标语「让城市变得好玩」+ 副题「第一场:毛孩子探店日」 | 微信版 P1 视觉 + 微信版 P7 宠物卡氛围 |
| 2 | 我们在做什么 | 线下商业多元交互平台;体验化、游戏化、第三生活空间 | 微信版 P1-2 文案原用 |
| 3 | 问题 | 线下有好店,缺「出门的理由」;流量买得到、体验留不住 | Downloads P3 + CityFix P10 那句金句(重做页面) |
| 4 | 解法:城市即平台 | 商户=可参与的任务节点;剧本像「点单」一样简单 | CityFix P4/P5 叙事重排(删残留) |
| 5 | 产品(真实能力) | 小程序:售票/报名/核销/图鉴/漫游地图,**用自家真实截图** | 替换 Downloads P7 英文样机;参考 Downloads P8 四步路径 |
| 6 | 玩法资产库 | 店内挑战卡墙精选 6–8 张 + 主题库精选 | CityFix P26/P27 原卡重排 |
| 7 | 我们办过的事 | 真实活动照片拼贴(与城市对望/长桌共绘/city walk 折页…) | CityFix P7 整页迁移 |
| 8 | **毛孩子探店日:活动定义** | 一个周末·一个商圈·¥69 四店全含票·一人一宠·集中场次(3小时/场,每场≤30人,最多4场=120人) | 总纲 §一(成稿见 §四.1) |
| 9 | 四店四动词 | 表达/动手/获得/互动,每店一项 6–10 分钟微体验,当场有结果、有可带走物 | 总纲 §1.4(成稿见 §四.2) |
| 10 | 宠物安全与善意 | 三不强迫 + A/B/C 替代任务 + 可接触标识;这页同时是给俱乐部看的专业度证明 | 总纲 §1.5 |
| 11 | **给俱乐部:角色** | 你是联名主理人,不是主持劳务:共同开场/巡场/摄影组织/收尾/社群承接;联名固定「城瘾探店日 × 俱乐部名」 | 总纲 §1.6/§3.2(成稿见 §四.3) |
| 12 | **给俱乐部:钱与关系** | 固定执行费+质量绩效+票源奖励(单期 ¥2,600–4,600 量级)→ 三期后转分成(40%→50%,原创活动 70–80%);自愿关注/社群归你 | 总纲 §2.1.2/§3.3/§3.4(成稿见 §四.3) |
| 13 | 给商家(俱乐部帮谈时也要懂) | 零现金结算:出一项微体验,换真实到访+联名内容包+聚合报告;我们不承诺爆文不承诺销售额 | 总纲 §3.1 + CityFix P13 话术翻新(成稿见 §四.4) |
| 14 | 账摊开算 | ¥69×120 演示瀑布:票款→物料/保险/支付费→俱乐部结算→平台贡献;**标注「演示公式,非承诺」** | 总纲 §2.1.3 |
| 15 | 90 天怎么验证 | 预售→彩排→首期→复办→第三期独立履约;五门(需求/履约/商家/俱乐部/平台)任一失败就修,不吹规模 | 总纲 §四/§七 |
| 16 | 团队(真实) | 真实主理人 + 协作网络照实写;删掉一切虚构名单 | 新拍/新写,**不用任何现有素材** |
| 17 | CTA | 找的人:想成为本地宠物圈线下主理人的组织/个人;下一步:一起定四店与首场档期;联系方式 | 新写 |
### 五、外发前必修清单
- [ ] P12 右上删「小红书号:[number]」水印(证据级硬伤,必修)
- [ ] P5 删图上摄影师水印 ©Viewfinderthis
- [ ] P6「各式各样的的」去重字;P11「真实世(界)的连接」补漏字;全册统一 AI/XR 写法
- [ ] 「5+ 城市试点/300+ 活动已发布」二选一:给出口径,或直接删数字
- [ ] P6 整页重做:删 JHK 盗图与虚构创始人名单,换真实团队
- [ ] P13 删「1000+ 场线下活动/>500 次多商家联动营销/>500万开发者年投入」
- [ ] P11 「+30%/+80%/+15%」三个效果数字删掉或改为「首场实测后回填」
- [ ] P10 「Tirgger」→「Trigger」;P9 删三面国旗;P12 换样机内英文收据屏
- [ ] 全册清版权素材:黑神话悟空(P8)、Fortnite(P2/9/14)、Minecraft(P14)、模拟人生(P7)
### 七、状态与下一步
- [ ] 微信版 2 处水印修复(用户侧/设计工具)
- [x] 正式版 17 页新 deck 已在 Figma 建成([number],17 页全部逐页截图验收):
- [ ] deck 内 3 处占位待替换:P5 小程序真实截图 / P16 主理人真实照片与介绍 / P17 联系方式
- [ ] 首场四店与集合点确定后,回填 P8/P9 具体店名与体验项

## Source: 城瘾vault/04-未开始/玩法形态与规则归属_全量排查_20260906.md

### 0. 结论一句话
| A. 节点基础判定 `validationMethod` 0–7 | 一个节点一次判定 | **底部半屏 sheet**(`.gp2`,max 86vh,地图仍可见;注释写明「任务=弹窗不是全屏(用户裁决)」`pages/play/index.wxss:707-709`) | 后端 |
### 5. 补问:模板库里那些**具体游戏**,商家承接后能改什么([number] 二问)
| **主题级玩法包** `POST /api/template/topic-template/use` → 整包复制成草稿 → 进 `fabu` 编辑器 | 节点层:点位名/地址坐标(种子无坐标,必填)/图片/描述/时间/钩子文案/xp/前置解锁;**换掉**节点挂的玩法模板(选自己的或再建一个) | **游戏内容本身**(题干/答案/选项/提示/拍照要求/剧情/奖励券)。副本模板已深拷贝给商家(`copyTemplateForOwner`,member_id=商家),但小程序**没有编辑既有模板的入口**:`temp` 只读 `/api/template/info`(公共库表),`/api/template/publish` 只 INSERT;「我的模板→开始应用」把会员模板 id 打到公共库表 | `CmsTopicServiceImpl.java:815-843`;`temp/in
| **节点级插件** `temp?id=库id` → `/api/template/info`(非 owner 剥 questionAnswer/correctAnswer/hint1/2/answerReveal + 高级机制秘密)→ 商家改完 `publish` 成私有新模板 → 在 fabu 挂到节点 | **全部字段**,且答案/提示被剥空、校验又要求必填 ⇒ **被迫填自己的** | 无(blindTaste.answerKey / dailySign.poems 由服务端从源模板回填,商家看不到也改不了) | `TemplateSecrets.java:32-40`;`backfillAdoptedSecrets` `TemplatePublishServiceImpl.java:645` |

## Source: 城瘾vault/04-未开始/美容探店日_项目计划书_20260818.md

### 九、开售前必须冻结的清单(本主题特有项)
- [ ] 其余 3 家商家签约 + 逐家过 §2.3 验收(含资质复印件)
- [ ] 每店微体验一句话话术 + 三步 SOP + A/B/C 替代方案彩排
- [ ] 参与单位条款(1 票 1 成人,无宠物条款)写进购票页
- [ ] 致敏提示文案(购票页 + 开场宣读稿)
- [ ] 检测数据留存边界:肤质检测结果只给玩家本人,商家不得留存用于营销外呼(写进商家合同)
- [ ] 集合点授权/容量/雨备/责任方
- [ ] 场次阶梯预算表(1–4 场各档 H_plan/F_contract/N_BE)
- [ ] 退款/改场/取消条款(同 SKU 同票价逐票跨期,总纲规则)
- [ ] 图鉴与印章物料设计
- [ ] 保险覆盖范围确认(皮肤过敏类客诉是否在保单内,不在则准备金 I 上调)

## Source: 城瘾vault/04-未开始/自由探索九个玩法_施工文档_20260906.md

#### 1.6 两个前置阻塞(不修,本批全部落不了地)
| **P0-A** | **商家改不了已有模板** | 承接后模板副本已归商家(`CmsTopicServiceImpl.java:815`),但小程序没有编辑入口:`temp` 只读 `/api/template/info`(公共库表),`/api/template/publish` 只 INSERT。后端唯一更新方法 `updateAdminTemplate` 只给后台 Vue 用 | 商家「填自己的题」这个动作根本做不了。**本批九个玩法全部依赖它** |
| **P0-B** | **改造指南泄给玩家** | `rule_instructions` 在玩家到达后原样下发并渲染成规则文案(`ApiPlayProgressController.java:455`;`pages/play/index.js:2055`) | 玩家现在看到的是「商家改造指南:①把题面里的细节换成…」。「神秘店员的暗号」更糟,店员剧本连回令一起发,等于题目自带答案 |
### 2. 落点决策 —— 新玩法一律走 `advancedConfigJson`,不动 `validationMethod`
| 前端 6 | `pages/publish/temp/index.wxml` | 商家编辑器 UI |
#### ③ 估数 —— 新 section `estimate`
| 偏离 | 其他 | 0 |
#### ⑨ 扫码领券 —— 纯营销,零代码
| `validationMethod` | 4 |
#### 7.1 Figma 落点([number] 实地勘察后更正)
| 内容宽 | 335 |

## Source: 城瘾vault/04-未开始/自由探索获客联盟_商业模式与领取制_定稿_20260812.md

### 二、人宠局具体配置
| 10% | 80 | ¥1,860 | ¥11,318 | **¥26,622（66.9%）** |
| 20% | 160 | ¥3,720 | ¥13,205 | **¥22,875（57.5%）** |
| 30% | 240 | ¥5,580 | ¥15,091 | **¥19,129（48.1%）** |
| **40%（达标）** | 320 | ¥7,440 | **¥16,978（期末预算的 90%）** | **¥15,382（38.6%）** |
| 60% | 480 | ¥11,160 | ¥17,606 | **¥11,034（27.7%）** |
| 100% | 800 | ¥18,600 | **¥18,864** | **¥2,336（5.9%）** |
### 四、八步流程与现状
| 1 | 俱乐部建主题：4 席位、每席一品类、每席只招 1 家、设招募截止、填票价与目标核销率 | 🔴 席位四项配置在发布器里**点不出来**（handler 在、wxml 零绑定，8-10 摘除，注释说改到项目详情页但那页没建）；只能走 Web 后台 `PUT /business/topicchapter`<br>🔴 **订单级卖方类型字段不存在** —— 现码的 `PLATFORM` 是主题内容槽（`CmsRegistrationServiceImpl.isPlatformOwned`），订单上没有 seller_type，需新建并随订单快照冻结 |
| 2 | 线下谈 4 家 + 商家入驻：每席选择唯一履约模板，填写零售价、结算价、履约承诺总量、有效期与预约规则 | 🟢 承接链路已具备“一商家一席位一模板”形状<br>🔴 **结算价字段不存在**（现只有 retail_value / unit_cost）<br>🟢 现有 `quota_total/quota_used` 直接就是履约承诺总量与容量真源，**不新增计数列**，也不再新增领取并发容量 |
| 3 | 招募截止 → 确认每席商家结算义务与受益人唯一 → 冻结全部经济/履约快照 → 终检 → 开卖 | 🟣 收费票开售修复已在未 push 分支真库验过，**master 尚未具备**。原“判零现金”不适用本模型，因为商家存在按核销现金结算 |
| 4 | 玩家买票 ¥199，原子锁定全部 4 席履约承诺；订单立即显示 4 个应得权益 | 🟡 现有买票即全席位预占的商业方向保留，需补合同版本与经济快照；**权益状态复用现表三态 + `invalid_reason`，只新增 `EXPIRED_UNUSED` 取值（零迁移）** |
| 5 | 玩家使用权益：无需预约的到店生成短时核销码；需预约的锁真实日期/时段 | 🔴 预约规则与记录待施工；不建设领取上限、7 天到期或领取并发任务<br>🟡 总履约窗口截止任务仍需自带 `sys_job` 注册 SQL |
| 6 | 到店核销：商家扫码 → 记录该席位核销 | 🟢 按席位核销/越席位拒/重复扫码幂等，真库已验 |
| 7 | 结算：商家按核销、俱乐部按公式、平台拿残差，T+7 打款进站内余额 | 🟢 现有结算入账与站内余额链路可复用<br>🔴 商家应付来源要从 `coop_order` 换成权益核销；俱乐部报酬要按本期冻结公式新算；合同残差须单独入账，不得把它直接展示成平台净利润 |
| 8 | 复盘续期：新客数、核销率、跨店来源、30 日复购 | 🟢 新客/复购/沉睡分段已有<br>🔴 **跨店来源、30 日复购归因零实现** |
### 六、施工顺序
| 1 | 商家结算价 + 唯一履约模板快照 + 完整经济快照（含 c）+ 履约承诺总量/预约规则字段 + 订单级卖方类型 + `assertAllianceAffordable` 支付回调闸 | 2、4、5、6、7 —— **地基，不做全盘空转** |
| 2 | 结算改造：由全核销可分毛差生成俱乐部预算，商家按核销结、俱乐部按新公式、平台拿合同残差 | 7 |
| 3 | 跨店来源 + 复购归因 | 8 —— 决定商家续不续 |
| 4 | 权益履约制（买票生成全席应得权益、预约与核销分离、总履约窗口截止、新增 `EXPIRED_UNUSED` 取值） | 4、5 |
| 5 | 主办方规则（双向改闸） | 1、5 |
| 6 | 席位配置可写入口（后台够用，发布器缺） | 1 |
