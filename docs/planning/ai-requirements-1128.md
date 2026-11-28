# AI features: requirements from the owner's planning docs (redacted)

Sources: 城瘾vault docs whose titles mention AI / NPC / weather / guide / story. Requirement lines only (checklists, tables, headings). Earlier docs target the old Flutter app or the MP; judge the FEATURE.


## Source: 城瘾vault/01-已上线/漫游AI基座_无形象伴随式漫游体验设计_20260722.md

## 漫游 AI 基座：无形象伴随式漫游体验设计
### 1. 已确认的产品决定
| 事项 | 已确认方向 | 直接含义 |
|---|---|---|
| 拍照 | 不需要 AI | 相机、集邮、照片保存保持普通产品能力；AI 不识图、不写图注、不生成图片、不评价照片。 |
| 形象 | 无形象、无名称、无人设 | 不再有常驻 NPC、头像、拟人问候或关系经营；必要时只以中性的“漫游提示/足迹”文字出现。 |
| 主要表达 | 地图 + 文字反馈 | AI 不占一个独立页面、FAB、聊天 Sheet 或悬浮角色层。 |
| 路线 | 整理成路线故事、给足迹推荐 | 在一次漫游结束后帮助用户理解“我刚刚走出了怎样一段路”，在下一次打开地图时给出可继续探索的足迹方向。 |
| 打卡 | 简单解释地点意义 | 必须以服务端确认的打卡/POI 为前提，输出短、可核验、不过度演绎的地点说明。 |
| 探店 | 附近商家需要提示，但不是 AI | 商家提示走确定性附近/运营规则；AI 不推荐、排序、劝消费或伪装成“懂你”的商家导购。 |
### 2. 核心定义：AI 不带领玩家，AI 帮玩家看见已发生的漫游
1. **把已验证的路线组织成可回看的故事与足迹。**
2. **在已完成打卡后，用一句话解释这个地点为何值得被记住。**
### 3. 漫游全过程中的四个表面
| 表面 | 用户原本在做什么 | AI/规则可以增加什么 | 明确不做什么 |
|---|---|---|---|
| 路线 | 看地图、走路、点亮格子、结束漫游 | 结算时把真实路线组织成一则路线故事；下次地图上提示可接续的足迹方向 | 实时导航、虚构路线事实、强迫用户按建议走 |
| 打卡 | 到达并完成服务端校验的 POI | 一句简短的地点意义或背景说明 | 在未验证到达前“预告完成”、编造地点事实、长篇导览 |
| 拍照 | 拍摄、入册、保存自己的记录 | 不介入；照片仍可由用户自己放进回顾 | 识图、打分、自动图注、图片生成、把照片上传给模型 |
| 探店 | 发现附近商家 | 由距离、营业状态、运营配置等普通规则提示 | AI 商家推荐、消费诱导、把付费排序伪装成个性化建议 |
#### 3.1 路线：把“走过”变成可回看的足迹
#### 3.2 打卡：一句可验证的地点意义
#### 3.3 地图：地图本身就是 AI 的空间语言
### 4. 一次正确的体验走查
### 5. 从旧 AI-NPC 报告中保留与废弃的部分
1. **真实事件优先。**文本只能建立在会话、打卡、路线等结构化事实之上。
2. **预审/模板优先。**高频、短反馈不必每次调用模型；地点事实和规则内容必须有可信来源或人工审核。
3. **嵌入既有流程。**不为了 AI 再建一套平行页面或行为闭环。
4. **故障时少说话。**模型、内容或网络不可用，只隐藏增强文字，不能打断地图、打卡或结算主流程。
#### 5.1 存量处置（2026-07-22 已拍板）
| 存量 | 现状 | 拍板结果 |
|---|---|---|
| PR #187（Chat 客户端入口） | CLOSED（2026-07-22 已核验，分支保留）：原为漫游右侧“问 AI”FAB + `cy-npc-chat` Sheet + 后端 requestId 幂等状态机 + `migration_npc_chat_request_20260722.sql` | **前端弃、后端拆**：关闭 #187，FAB/聊天 Sheet 不进 master；后端幂等状态机与数据留存治理拆成独立基础设施 PR 另行评审（将来任何生成式能力共用）。迁移随后端拆分 PR 走，评审前不落库。分支保留不删。 |
| Event 轨（已合并 #83/#84） | master 上：NPC 气泡（头像+名字+“AI 游戏向导”）、结算台词、`npc_profile`/`npc_line_cache` 表、`feature.flag.roamNpcEvent/roamNpcChat`（默认关，迁移已落库） | **改造复用**：剥掉人设层（不渲染头像/名字/角色后缀），话术池换一版中性文案（新版本走既有 `audit_status` 流程），开关键名不改、语义重定义为“漫游提示层”总开关。预审缓存、防吵闸、coordinator、埋点管线全部沿用。`roamNpcChat` 保持 false 且不再有前端入口。 |
| `feat/npc-data-export-delete`（f6fa2599，未 push） | Chat 数据导出/删除端点，已 commit 未 ship | 随 Chat 方向搁置降级：`npc_chat_log` 已有测试数据，端点本身无害，并入“后端拆分 PR”一起评审，不单独 ship。 |
### 6. 内容与模型边界
#### 6.1 可进入 RoamContext 的事实
#### 6.2 不应进入模型或 AI 表达层的内容
#### 6.3 模型只是文字润色层，不是事实和决策层
### 7. 体验与工程的硬边界
| 边界 | 约束 |
|---|---|
| 出现位置 | 只在已有地图、打卡结果、路线结算、足迹承载区内；不新建 AI 浮层。 |
| 触发权 | 规则和服务端已验证事件决定；模型无权主动触发。 |
| 频率 | 以“不打扰漫游”为上限；具体文案预算与冷却时间应在真机走查中确定。 |
| 事实准确性 | 地点意义须可追溯到可信/已审核内容；无来源即不显示。 |
| 商业边界 | 商家提示和 AI 文本完全分轨；不得将商业导流包装成 AI 建议。 |
| 降级 | 只损失一段文字，不损失地图、定位、打卡、路线结算或足迹。 |
#### 7.1 基座 V1 Go Gate（最小验收闸，2026-07-22 新增）
- [x] 内容审核状态机：路线故事模板、地点意义条目、地图提示文案全部经审核状态（复用 `audit_status` / route_egg 三态）才可展示；负控：插入一条未审核条目，线上不得出现。
- [x] 无来源即不显示：地点意义无已审核内容时，打卡结果区不出现该模块（不是占位、不是“暂无”）；负控：清空某 POI 内容后回读展示面。
- [x] 展示频控：每次会话结算故事 ≤1 条；打卡地点意义每 POI ≤1 条；进图足迹提示 ≤1 条；复用防吵闸参数化配置，数值真机走查后定稿并回写本节。
- [x] 开关：复用 `feature.flag.roamNpcEvent`（语义重定义=漫游提示层总开关），默认 false；`roamNpcChat` 恒 false 且无前端入口；非法组合按 20260716 §13.1 处理。
- [x] 人设残留为零：开启提示层后，任何表面不得渲染头像、角色名、“AI 游戏向导”等拟人标识；负控：检查气泡/结算台词模板变量与 wxml 绑定。
- [x] 埋点：新表面曝光/点击事件进前后端白名单，无原文、无精确位置。
- [x] 降级：内容接口失败只损失文字层，地图/打卡/结算全链路可用（断网走查）。
#### 7.2 2026-07-23 本地实现读回
### 8. 成功判据
### 9. V1 实施规格与剩余上线项
1. 地点意义：独立 `roam_ai_content` 表与 CMS 审核端点；文本 1–80 字；仅非商家 POI；玩家查询只读 `audit_status=1 && enabled=1`，无来源不展示，绝不回退 `RoamPoi.description`。
2. 足迹推荐：本地最近会话末点 + 本地相邻未点亮格才出现；地图仅高亮一个边缘圆，不画路线、不写方向词、不导航；数据不足或开关关闭静默。
3. 展示密度与位置：路线故事在结算屏；地点意义在已确认到点的既有 `paceCard` 结果区；足迹在地图现有提示栈。足迹只在 `visit / nearbyBanner / paceCard / medal / discoverReward / eventOverlay` 全未显示时出现；商家二选一卡出现会直接清掉旧足迹提示，通用漫游提示在足迹之后；三类均以本次会话标记限制为最多一次。
4. 路线模板：只允许 `{{tiles}}`、`{{pois}}` 两个服务端结算指标；不使用客户端上传距离、原始坐标、轨迹或玩家身份；未知变量失败关闭。
5. Chat：无形陪伴 V1 的 `roamNpcChat` 在服务端固定为 false；任何未来自由追问必须另立合规项目、另建 Gate，不能由遗留 `sys_config` 配置误开。
1. 指定地点意义内容生产人、审核人、更新节奏和首发官方 POI 覆盖清单；创建并审核首批真实内容。
2. 合并前按迁移流程执行 `migration_roam_ai_content_v1_20260723.sql`，再对未审核、空内容、商家 POI 做线上负控回读。
3. 回读 `feature.flag.roamNpcEvent=false`、`feature.flag.roamNpcChat=false` 的默认状态；在受控环境开启前完成开启/关闭组合负控。
4. 微信开发者工具/真机完成视觉与断网走查，上传小程序；合并后完成生产 jar SHA 读回。四项未全过前，文档不得流转到“待部署/已上线”。

## Source: 城瘾vault/03-进行中/具名玩法包_10个商家游戏模板与AI填充施工方案_20260820.md

## 具名玩法包:10 个商家游戏模板与 AI 填充施工方案
### 0. 现有基座(已现码核实,施工前勿重建)
### 1. 十个具名玩法包
#### ① 隐藏菜单(咖啡店/酒吧/茶馆)
#### ② 店内寻宝(书店/杂货/展览空间)
#### ③ 拍照挑战(网红店/景观位商家)
#### ④ NPC 暗号(有店员配合意愿的店)
#### ⑤ 三步解谜(酒吧/密室周边/文化空间)
#### ⑥ 听音辨物(咖啡/livehouse/酒吧)
#### ⑦ 限时闪答(快节奏业态/排队场景)
#### ⑧ 集章巡店(商场/街区/市集多商家联动)
#### ⑨ 岔路剧情(想做记忆点的店/情侣客群)
#### ⑩ 盲盒任务(高复购业态/常客运营)
#### 备选⑪ 双人对暗号(情侣/组队场景)
### 2. AI 填充链路(复用为主)
### 3. 施工顺序
| 批次 | 内容 | 新机制 |
|---|---|---|
| P1 | 玩法包①~⑥ 编排预设 + prompt 预设 + 商家端选包入口 | 无 |
| P2 | ⑦ 限时(时间戳比较)+ ⑩ 随机下发 | TIMER / 随机(各极低) |
| P3 | ⑧ 集章(requiredCount 通关)| 集章判定(低) |
| P4 | ⑨ 岔路(storyJson 分支)| 分支(中) |
### 4. 验收判据
### 5. 施工实录(2026-08-20 晚 · worktree feat/playbook-templates,已 commit 未 ship)
- [x] **种子①:10 套具名玩法包主题模板**(migration_seed_playpack_templates_20260820.sql,③)
- [x] **W4 闭环修复**:copyNodes 深拷贝节点模板给新归属 + unlock 引用重映射(没这个,商家 /use 后一保存就被「不能引用他人的模板」拦死)
- [x] **升级6·模板市场**(migration_seed_template_library_12packs_20260820.sql,③):
- [ ] **升级4·多节点条件**(migration_node_unlock_after_20260820.sql,③):
- [x] **升级3·排行榜**:GET /api/play/leaderboard,score=完成节点数,同分先完成者靠前;榜外 me 不猜名次
- [x] **升级2·角色系统**(migration_player_activity_role_20260820.sql,③):
- [ ] **升级1·AI 核心草稿**:POST /api/ai/template/fill 已完成店名/品类/奖励 → 核心玩法文案+coverPrompt+勋章名(bizType=template_fill)；
- [x] **升级5·商家数据看板**:POST /api/merchant/dashboard,曝光(参与主题近30天浏览)/到店/核销率/复购率/在架供给;
#### 部署影响分类(ship 时照抄)

## Source: 城瘾vault/03-进行中/商家AI店铺参谋_打卡分析与活动建议_20260820.md

## 商家 AI 店铺参谋 —— 打卡分析 / 适合人群 / 活动建议(落营销 tab)
### 0. 用户原始诉求
| 能力 | 商家看到什么 | 数据从哪来 |
|---|---|---|
| A. 到店打卡分析 | 谁什么时段来打卡、核销率、等待时长、复购 | `player_node_progress` + `redemption` |
| B. 适合人群 | 我的客群是什么样的人(性别/年龄段/玩家等级/兴趣偏好) | `ums_member` + `member_interest_profile` + `player_growth` |
| C. 可办活动建议 | 基于 A+B,AI 建议办什么活动、什么时段、面向谁、走哪条现有链路发布 | DeepSeek 生成,建议项直接链到现有入口 |
### 1. 现状事实(2026-08-20 现码核实,三个 agent 分头扫过)
#### 1.1 营销页现状 —— 入口空位就在那
#### 1.2 数据链路 —— 打卡↔商家已打通,现成 SQL 在仓里
1. **`merchant_customer_profile` 是空壳**:`MerchantCustomerProfileMapper.xml:69` 的聚合所有 count 硬编码 0、stage 一律 'active'。**不许当数据源**,直接 join 明细表。
2. **浏览数据答不了商家维度**:`tms_browse_record` 无 merchant/node 列,且 browse_type 存量错码未修(`migration_20260804_fix_browse_type_activity.sql` 的 UPDATE 至今注释态)。「看了没来」漏斗本期不做。
3. **现有 `/api/merchant/funnel`、`/verification-records` 是 N+1 + 全量入内存 + 无分页**(`ApiMerchantController.java:931/:988`),新聚合**别照抄这个模式**,一条聚合 SQL 出结果。
#### 1.3 AI 基座 —— 全链路已通,商家向 bizType 已有先例
### 2. 功能设计
#### 2.1 形态:一张入口卡 + 一个报告页,「一天一份,先数字后 AI」
| suggestion.type | 含义 | action(小程序跳转) |
|---|---|---|
| `topic_coop` | 承接/申请主题合作 | `/pages/merchant/coop-center/index` |
| `decor` | 完善店铺装修/权益 | `/pages/merchant/decor/index` |
| `content` | 发内容(主题/自由探索/活动,即营销页 `goMyContent` 现有三张内容卡) | 营销页对应内容入口 |
#### 2.2 明确不做(边界)
| 不做 | 原因 |
|---|---|
| 浏览/曝光类指标 | 硬合同禁 + 数据无商家维度(1.1/1.2) |
| 对话式 AI(商家跟它聊) | 一次生成满足诉求;对话 = token 失控 + NPC 聊天同款合规问题(NpcFeatureFlags 已 403) |
| 自动发券/自动推送/自动定价 | 营销执行必须人工;资金域动作绝不交给模型 |
| 依赖 merchant_customer_profile | 空壳表(1.2) |
| 新建统计宽表/离线任务 | 现有明细表 + 聚合 SQL 在当前数据量(33 单级别)绰绰有余;量大了再上 `biz_funnel_daily` 模式 |
#### 2.3 隐私红线
### 3. 施工方案
#### 3.1 后端(①,chengyinhub-system + admin)
#### 3.2 小程序(②,chengyinhub-xcx)
#### 3.3 部署影响分类
| 类别 | 有无 | 说明 |
|---|---|---|
| ① 后端运行时 | ✅ | system + admin 改动,合并即自动部署 |
| ② 小程序 | ✅ | 另走微信上传 |
| ③ 迁移 | ❌ **无** | 不建表不改列不注册 sys_job(无定时任务,全同步请求) |
| ④ CI | ❌ | |
| ⑤ 无运行时 | 本文档(vault,不进仓库) | |
#### 3.4 验收标准(可勾)
- [ ] `POST /api/ai/merchant/insight` 用一个有核销数据的商家号(如 100096)返回非空 facts,数字与 `redemption` 表手工 COUNT 一致
- [x] 用无数据新商家号返回空态引导,不报错
- [x] 用玩家号调用返回 403(负控)
- [x] 传别家 merchantId 参数无效果(接口根本不收该参数,代码评审确认)
- [x] AI 返回非法 `action` 枚举时该条建议被丢弃(单测注入)
- [x] 断掉 AI(mock 抛 UPSTREAM_UNAVAILABLE)时 facts 照常返回、页面上半屏正常(负控)
- [x] 同一商家同日第二次请求命中缓存,Redis 无第二次 INCR(日志/计数断言)
- [x] prompt 输入体里 grep 不到 nickname/phone/member_id 列表(单测断言事实包字段白名单)
- [x] 小程序页面 automator 截图:有数据态 / 空态 / AI 降级态 三态各一张
#### 3.5 分期
### 4. 风险台账
| 风险 | 应对 |
|---|---|
| 数据太少 AI 强行解读(平台目前 33 单量级) | 服务端 `lowSample` 闸(见 3.1):核销人数 <10 时 summary 强制换固定引导模板,不靠 prompt 自律;页面标注「数据量较少,仅供参考」 |
| 生产 `CHENGYIN_AI_API_KEY` 是否真注入过未从外部验证 | 上线后用真商家号打一次 `/api/ai/merchant/insight` 观测(回执≠观测);配置缺失会明确报错不会静默 |
| 聚合 SQL 随数据量退化 | 主查询命中 `idx_redemption_merchant(merchant_id, create_time)`;量级上来后迁 `biz_funnel_daily` 日聚合模式(表已存在) |
| 建议内容合规(AI 教商家办违规活动) | 出参已过网关出参安全层;suggestions 的 type 枚举收窄到站内三类动作(2.1 映射表),跳转路由前端写死不由模型产出 |

## Source: 城瘾vault/03-进行中/店铺NPC_自拍生成3D形象与五句声音克隆_加模板库AB_实施计划_20260905.md

## 店铺 NPC:自拍生成 3D 形象 + 五句话声音克隆 + 人设对话,以及模板库档 A / 档 B
### 施工实录(2026-09-05)
| 阶段 | 状态 | PR |
|---|---|---|
| P0 决策与试跑 | **未开始 —— 卡用户** | 要开供应商账号 + 合规签字,不是我能做的 |
| P1 商家自配 NPC + 店铺知识 + 对话 | 代码完成,三端 | 后端 [chengyin#1026](https://github.com/liboyang42-cpu/chengyin/pull/1026)(含小程序)· App [chengyin-app#18](https://github.com/liboyang42-cpu/chengyin-app/pull/18) |
| P2 五句话声音克隆 | 代码完成 | 后端 [chengyin#1027](https://github.com/liboyang42-cpu/chengyin/pull/1027) · App [chengyin-app#19](https://github.com/liboyang42-cpu/chengyin-app/pull/19) |
| P3 自拍生成 3D 形象 | **骨架完成**(供应商无关的那一半) | 后端 [chengyin#1029](https://github.com/liboyang42-cpu/chengyin/pull/1029) · App [chengyin-app#21](https://github.com/liboyang42-cpu/chengyin-app/pull/21) |
| P4 档 A 模板市场 | 代码完成 | 后端 [chengyin#1028](https://github.com/liboyang42-cpu/chengyin/pull/1028) · App [chengyin-app#20](https://github.com/liboyang42-cpu/chengyin-app/pull/20) |
| P5 档 B DSL | **spec 已出**(2026-09-06),待拆批施工 | [模板库档B_声明式玩法DSL_spec_20260906](../04-未开始/模板库档B_声明式玩法DSL_spec_20260906.md) |
1. **审核通道整条是断的**(自查发现,零报错零告警)。商家提交落 `audit_status=0` 待审,
2. **旧契约钉的是被我换掉的那个原型**。商家 AI 形象页原本是四步草稿(上传店图 → 假生成头像
1. 合 `#1026`(P1,base=master,CI 已绿)
2. `gh pr edit 1027 --base master` → 这一改会触发 `pull_request` 事件、base 变成 master
3. `gh pr edit 1029 --base master` → 同上
1. `ci/silent-error-gate.js` 读的是 `ci/silent-error-allowlist.txt`,与小程序侧那两份名册**是三份独立的册子**。
2. `chengyinhub-xcx/tests/unit/action-ledger.test.js` 冻结了三个分母,要单独 `node --test` 跑(约 100s),`ci/xcx-check.sh` 不含它。
3. App CI 跑的是 `dart analyze lib test`(warning 即失败),只跑 `dart analyze lib` 会漏 ——
4. 迁移门禁只看**已提交**的文件:文件还是未跟踪状态时它会报「无新增迁移」并放行。要 commit 之后再跑才算数。
### 0. 一句话
### 1. 现有基座(2026-09-05 已现码核实,施工前勿重建)
| 能力 | 现状 | 落点 |
|---|---|---|
| NPC 人设表 | `npc_profile` 已有 scope_type 1 剧本 / 2 门店 / 3 全局,字段 name / avatar / persona / greeting / audit_status / enabled / active_slot | 后端 |
| 门店分身 CRUD | 后台 `CmsMerchantNpcController`(`/business/merchantNpc/*`),四条 mapper 写死 scope_type=2;**persona 落空串**;商家端无写入口 | PR #820 已合并 |
| 门店分身读侧 | `NpcProfileService.resolveForMerchant` → `/api/merchant/public-home` 的 `npc` 字段;小程序店铺主页形象卡 + 漫游地图像素 marker | 小程序已接,**App 未接** |
| 对话服务 | `NpcChatService` 只取全局 NPC(`findGlobalProfile`),system prompt = persona + 漫游记忆;已收编进 `AiGatewayService`(频控 / 出入内容安全 / 审计日志) | 后端 |
| 对话开关 | `feature.flag.roamNpcChat`,生产为 false,端点非 true 即 403;Chat 轨被 Phase 0 合规签字阻断 | sys_config |
| LLM 供应商抽象 | `LlmClient` 接口 + `OpenAiCompatibleLlmClient` + `AiSceneRouter` 按 bizType 路由;现有 bizType:merchant_plan / theme_draft / node_generate / merchant_insight / template_fill / npc_chat | 后端 |
| 同意记录 | `consent_record` 表 + `ConsentRecordService`(docType / scene / scopeType / scopeId) | 后端 |
| App NPC 客户端 | `npc_controller.dart`(全局 + 局内 session)、`npc_bubble.dart`、`npc_chat_sheet.dart`;**chat sheet 零调用方**;地图页只显示"X 已陪伴本次漫游"标签 | App |
| App 音频 / 动画 | `just_audio` 已在;`rive` 已在;**无 TTS、无 3D 渲染、无录音依赖** | App |
| 商家描述字段 | `mms_merchant.description / story_title / tags / featured_type / featured_id`;**无菜单、无推荐字段** | 数据库 |
| 玩法模板 | `cms_template_library`(is_sync 同步进库、publish_status、`/api/template/list` 公共浏览、引用即复制)+ `cms_member_template` 节点玩法(vm 1~5)+ 具名玩法包 12 套种子(03-进行中) | 后端 + 小程序 + App |
| App 游玩分派 | `play_gap_logic.dart` 按 validationMethod 0~5、7 分派;`play_session_page.dart` 2126 行硬编码各分支 | App |
| OSS 上传 | `FileOssUploadUtils` 按扩展名落对象,已有 audio 上传路径(`uploadFile` 允许 mp3/m4a/aac) | 后端 + App |
### 2. 目标形态(玩家视角)
1. 打开一家店的主页,看到老板的 3D 形象在待机(呼吸、眨眼)。
2. 点形象,弹出对话面板。输入或语音说"想吃点不辣的",形象用老板的声音回答"那试试我们家的椰香鸡,今天有券",嘴随声音开合。
3. 面板顶部常驻"AI 合成形象与声音"标识;每段语音开头有短提示音。
4. 游玩到该店节点时,同一形象出场做事件冒泡(已有 event 链路,换头像与音色即可)。
### 3. 分阶段计划
#### P0 · 决策与试跑(1 周,不写产品代码)
- [ ] **合规签字**:门店对话是 Chat 轨的子集,单独出一页评估:内容范围仅商家自审店铺信息;出入内容安全走 AiGateway;合成语音 / 形象按《人工智能生成合成内容标识办法》(2025-09-01 施行)加显式标识与元数据标识;声音克隆取得本人同意并留存录音。**签字前 P1 的对话开关不开,P2 不接生产供应商。**
- [ ] **声音克隆供应商试跑**:候选 阿里云百炼 CosyVoice 声音复刻、火山引擎声音复刻、MiniMax。用同一段 30 秒录音各出一个音色,盲听打分;记录单音色价格、TTS 千字价、是否返回音素 / 口型时间轴(有则 P3 口型直接用,无则走振幅口型)。
- [ ] **3D 生成供应商试跑**:候选 腾讯混元 3D、Tripo、Ready Player Me。用 3 张真商家自拍各生成一次;判据:像不像本人、有没有骨骼与口型 blendshape、导出 glb 大小、生成时长、单价、是否国内可用。**没有骨骼的供应商只能出静态模型,口型要靠 P3 的振幅方案。**
- [ ] **自建方案定价锚(2026-09-05 新增,不改 P2/P3 先接商业 API 的决定)**:本地各跑一次
- [ ] **渲染试跑**:App 用 `model_viewer_plus`(WebView 包 Google model-viewer)和 `flutter_scene` 各渲染试跑产物一次,记录首帧时间、内存、是否支持播放 glb 内置动画;小程序用 `xr-frame` 渲染同一 glb。**取双端都能跑的那个格式定案。**
- [ ] 产出:一页决策记录,填进本文第 6 节的空格。
#### P1 · 商家自配 NPC + 店铺知识 + 对话(后端 ①③ / App / 小程序②)
- [ ] `npc_profile` 加 `voice_id`(varchar,P2 用)、`model_url`(varchar,P3 用)、`knowledge`(text,店铺知识,商家填);后台 `CmsMerchantNpcController` 补 persona / knowledge 字段编辑
- [ ] 新增 `POST /api/merchant/npc/save`:商家保存 name / avatar / persona / greeting / knowledge,落 `audit_status=0`;同店已有行则更新并回到待审;鉴权走 `MerchantAccessService`
- [ ] 新增 `POST /api/merchant/npc/info`:商家读自己的形象与审核状态
- [ ] `NpcChatService.chat` 加 `scope=merchant&merchantId`:profile 取 `resolveForMerchant`;system prompt = persona + 店铺事实包(description / tags / featured 主推 / 在架券 / knowledge)+ 边界指令("只谈本店,不谈他店,不编造菜品");事实包字段白名单单测钉住(仿 merchant_insight 的做法)
- [ ] 新增开关 `feature.flag.merchantNpcChat`,默认 false;`ApiAiNpcController.chat` 按 scope 选开关,漫游仍看 `roamNpcChat`
- [ ] bizType 加 `merchant_npc_chat`,`AiSceneRouter` 路由到 deepseek;配额按商家 + 玩家双维度
- [ ] 迁移:`chengyinhub-admin/sql/migration_npc_profile_merchant_fields_20260905.sql`(加列)+ `migration_merchant_npc_chat_flag_20260905.sql`(开关)
- [ ] 商家中心加"我的店铺形象"入口 → `merchant_npc_edit_page.dart`(照 `node_template_edit_page.dart` 的表单骨架);状态卡:草稿 / 待审 / 已上线 / 被驳回
- [ ] `merchant_public_home_page.dart` 加形象卡(读 `public-home.npc`),点开 `NpcChatSheet`,session key 改成支持 merchantId
- [ ] `npc_controller.dart` 的 `sendChat` 加 scope 参数
- [ ] `pages/merchant/decor/ai-npc` 从草稿模式接到 `/api/merchant/npc/save`;店铺主页形象卡点开对话(复用 roam 的 chat sheet)
- [ ] 商家 A 保存后 `npc_profile` 出现 scope_type=2、scope_id=A、audit_status=0 一行;后台过审后店铺主页出形象
- [ ] 负控:商家 A 传 merchantId=B 保存 → 403
- [ ] 开关关时对话返回 403;开后问"有什么推荐"回答只含本店事实包内容(单测断言回复不含他店名)
- [ ] 负控:清空 knowledge 与 description,问菜品 → 回答落到"暂时没有菜单信息"类兜底,不编造
- [ ] prompt 输入体 grep 不到 phone / member_id
#### P2 · 五句话声音克隆 + 语音回复(后端 ①③ / App)
1. 说明页:用途、会被合成什么、随时可删、显式标识。
2. 逐句录音,五句固定文案:① 同意声明"我是[店名]的[称呼],我同意城瘾用我的声音生成本店 AI 形象的语音" ② 问候 ③ 招牌介绍 ④ 一句带数字与地名的话(覆盖音素)⑤ 一句带情绪的话。每句录完可重录,前端做时长与音量下限校验。
3. 提交 → 后端拼接为一段样本 → 调克隆 API → `voice_id` 落 `npc_profile.voice_id`,五段原始录音落 OSS 私有桶,`consent_record` 写 docType=`voice_clone`、scopeType=merchant、scopeId=merchantId,附录音①的对象 key。
4. 后台人审试听 → 通过后 enabled。
- [ ] `VoiceClient` 接口(clone / tts / delete),`AliyunCosyVoiceClient` 实现;配置照 `LlmClientConfig` 的 env 回退链写法
- [ ] `POST /api/merchant/npc/voice/enroll`(收五段音频 URL)`POST /api/merchant/npc/voice/delete`(删音色 + 删样本 + consent 记录撤回)
- [ ] `NpcChatService` 回复后按 voice_id 合成,返回 `audioUrl`;事件话术(`npc_line_cache`)按 profile 预生成音频列 `audio_url`,不在线合成
- [ ] TTS 输出头部拼固定提示音(0.4 秒)+ 文件元数据写"AI 合成"标识
- [ ] 迁移:`migration_npc_voice_20260905.sql`(voice_id 已在 P1 加;`npc_line_cache` 加 audio_url;consent docType 无需 DDL)
- [ ] 加 `record` 依赖(录音),复用 `just_audio` 播放
- [ ] `merchant_npc_voice_enroll_page.dart`:五步录音向导
- [ ] `NpcChatSheet` 与 `NpcBubble` 有 audioUrl 即自动播放,面板顶部常驻"AI 合成声音"标签
- [ ] 一个真商家走完五句,后台试听像本人,店铺主页对话有声音
- [ ] 负控:缺第①句同意声明的提交 → 后端拒绝,consent 无记录
- [ ] 负控:删除音色后再对话 → 只有文字,无音频,供应商侧音色查不到
- [ ] 每条合成音频开头有提示音(自动化:解析前 0.5 秒能量峰)
#### P3 · 自拍生成 3D 形象(后端 ①③ / App / 小程序②)
1. 拍照指引:正面、单人、光线均匀,取景框叠加轮廓;可从相册选。
2. 选风格:三个预设(写实 / 卡通 / 像素,像素风与现有 16×16 头像体系兼容),每个风格一张示例。
3. 提交 → 后端调 image-to-3D → 返回 glb + 三视图缩略图 → 商家预览可旋转 → 确认 → 待审。
4. 后台人审 → enabled → 店铺主页、游玩节点、漫游地图出场(地图仍用缩略图缩成像素 marker,沿用 #820)。
- [ ] `AvatarGenClient` 接口 + 供应商实现(按 P0 定案);异步任务表 `npc_avatar_job`(状态 / 输入图 / 输出 glb / 失败原因),`POST /api/merchant/npc/avatar/generate` 返回 jobId,`POST .../avatar/status` 轮询
- [ ] 输入图过内容安全(人脸、违规);输出模型限制体积上限(P0 定数值)
- [ ] 迁移:`migration_npc_avatar_job_20260905.sql`
- [ ] `merchant_npc_avatar_page.dart`:拍照 / 选图 / 选风格 / 等待 / 预览
- [ ] 形象渲染组件 `npc_avatar_view.dart`:按 P0 定案用 `model_viewer_plus` 或 `flutter_scene`;待机动画用 glb 内置 idle,没有则做缓慢自转;**口型 = 播放中按音频振幅驱动 jaw / mouthOpen 权重**(有 blendshape 走权重,没有则轻微上下位移),不做音素级
- [ ] 弱机与低电量:降级为缩略图立绘,不加载 3D
- [ ] 店铺主页形象卡用 `xr-frame` 渲染同一 glb;不支持的基础库降级为缩略图
- [ ] 三个真商家各生成一次,本人认可"像自己";glb 体积在上限内;App 首帧时间在 P0 定的阈值内
- [ ] 负控:上传非人脸图 → 拒绝,无 job;上传两人合影 → 拒绝或提示裁剪
- [ ] 负控:关掉 3D 渲染开关 → 三处都落缩略图,无空白
- [ ] 语音播放时嘴在动,静音时不动(录屏对照)
#### P4 · 模板库档 A:参数化模板运营化(后端 ①③ / App / 小程序②)
- [ ] `cms_template_library` 加 `use_count`、`like_count`、`pack_type`(枚举:node 单节点 / story 剧情 / ip_pack 店铺 IP 包);`ip_pack` 类型附带 NPC 人设、口吻、事件话术模板、奖励券建议
- [ ] `/api/template/list` 支持按 pack_type、热度排序、关键字;`POST /api/template/use` 一键复制到我的节点模板(复用具名玩法包的 copyNodes 深拷贝 + unlock 重映射)
- [ ] 上传口:现有 `publish` + `is_sync=1` 已是上传;补"上传须知"与审核状态可见;过 `wxContentSecurityService` 已有
- [ ] App `template_list_page.dart` 加 tab 与"套用"按钮;商家侧节点玩法页加"从模板库选"
- [ ] 迁移:`migration_template_library_pack_20260905.sql`
- [ ] 验收:任意玩家上传一个模板 → 过内容安全 → 库里可见 → 商家一键套用后自己的节点模板出现深拷贝副本,原模板 use_count+1;负控:套用他人未过审模板 → 拒绝
#### P5 · 模板库档 B:声明式玩法 DSL(架构级,单独 brainstorming 出 spec 后再拆任务)
### 4. 部署影响总表
| 阶段 | ① 后端 | ② 小程序 | ③ 迁移 | ④ CI | ⑤ 文档 | App |
|---|---|---|---|---|---|---|
| P0 | 无 | 无 | 无 | 无 | 决策记录 | 无 |
| P1 | 是 | 是 | 2 | 无 | 是 | TestFlight |
| P2 | 是 | 无 | 1 | 无 | 是 | TestFlight |
| P3 | 是 | 是 | 1 | 无 | 是 | TestFlight |
| P4 | 是 | 是 | 1 | 无 | 是 | TestFlight |
| P5 | 待 spec | 待 spec | 待 spec | 可能 | 是 | 待 spec |
### 5. 风险台账
| 风险 | 后果 | 对策 |
|---|---|---|
| 合规签字迟迟不落 | P1 对话、P2 生产供应商都不能开 | P0 第一项;签字前 P1 仍可做完并以开关关闭状态合并 |
| 声音克隆被冒用(拿别人录音来克隆) | 法律风险 | 第①句同意声明含店名与本人称呼,人审试听比对;举报即下架并删音色 |
| 3D 生成"不像本人"或诡异 | 商家不用 | 三风格可选,写实不满意退到卡通;人审可驳回 |
| Flutter 3D 渲染性能 | 低端机卡 | 弱机降级缩略图;首帧阈值在 P0 定数并在验收里钉住 |
| 供应商国内不可用或停服 | 功能断 | `VoiceClient` / `AvatarGenClient` 接口隔离,可换实现;音色与 glb 都落自家 OSS |
| NPC 编造菜品 | 误导消费者 | 事实包白名单 + 边界指令 + 负控"清空知识后不编造" |
| 档 B 变成变相档 C | 撞审核与版号 | DSL 无表达式无脚本无外链,写进 schema 校验器,负控注入脚本字段必须红。⚠️ 改用 Yarn 后这条**风险变高**:Yarn 原生支持变量与条件表达式,校验器必须按白名单裁剪,不能默认放行 |
| App 与小程序双端功能漂移 | 一端有一端没有 | 每阶段验收表双端各一行 |
### 6. P0 要填的决策(执行 P0 时回写)
| 决策 | 候选 | 定案 |
|---|---|---|
| 声音克隆供应商 | 阿里 CosyVoice / 火山 / MiniMax | 待填 |
| 3D 生成供应商 | 腾讯混元 3D / Tripo / Ready Player Me | 待填 |
| App 渲染方案 | model_viewer_plus / flutter_scene | 待填 |
| glb 体积上限与首帧阈值 | 待测 | 待填 |
| 口型方案 | 供应商音素时间轴 / 振幅驱动 | 待填 |
| 合规签字结论 | 通过 / 附条件 / 不通过 | 待填 |
### 6.5 开源调研结论(2026-09-05)
| 层 | 有没有能抄的 | 处置 |
|---|---|---|
| **平台形态**(多商家共同构成一张活的城市地图) | **没有**。开源位置游戏都是「一场活动」级别,不是「商家持续经营」级别 | 自己长。[SOFIE ScavengerHunt](https://github.com/SOFIE-project/ScavengerHunt) 的 GPS→谜题→答题解锁与城瘾节点玩法同构,**证明方向对,给不了新东西**;[csgames/scavenger-hunt](https://github.com/csgames/scavenger-hunt) 的后台活动建模可读 |
| **剧情 / 分支 DSL** | **有,且直接改用** | Yarn Spinner,见 P5 |
| **声音克隆** | 有,自建可行 | GPT-SoVITS;P0 跑一次做定价锚,P2 仍先接商业 API |
| **单图生成可动头像** | 有,且很接近目标形态 | LAM;同上,P3 仍先接商业 API |
| Ingress / Pokémon Go | 只有第三方逆向工具,违反 ToS | **不碰** |
### 7. 明确不做

## Source: 城瘾vault/03-进行中/门店AI形象_像素风后台配与双端出场_20260825.md

## 门店 AI 形象：像素风 + 后台配 + 店铺主页与漫游地图出场
### 一句话
### 已完成（按现码核对，非按 PR 描述）
- [x] 后台 CRUD `CmsMerchantNpcController`（`/business/merchantNpc/*`），四条 mapper 语句全部写死 `scope_type = 2`
- [x] `insertMerchantNpc` 不写 `active_slot`（写了会在同门店第二条形象上撞 `uk_active_scope` 报 1062）
- [x] 后台页 `chengyinhub-ui` `business/merchantnpc`（商家远程搜索 + 像素头像上传）
- [x] 读路径 · 店铺主页：`resolveForMerchant` → `PublicMerchantVO.npc` → `/api/merchant/public-home`
- [x] 读路径 · 漫游地图（两条来源都接）：`roam_poi.merchant_id`；`cms_registration_merchant.member_id` 两跳到 `mms_merchant.id`
- [x] 小程序形象卡：在店铺主页 **tab 之上**（不在「关于」里——他人视角默认落 `posts`）
- [x] 漫游 marker：canvas 绘制，`imageSmoothingEnabled = false` + 只按整数倍放大；描边色跟节点等级
- [x] fog / target / checkin-failed 三类点位不画形象
- [x] 三处 npc 查询口径一致（`enabled`/`audit_status`/`del_flag` + `ORDER BY sort, id`），由 `MerchantNpcAvatarTest#[id]` 钉住
- [x] #812 商家侧草稿流标明「草稿模式 · 不会上线」（**刻意不接通**两条链路）
- [x] Figma：关于页画板 + 头像库（3 款 16×16 Component）+ 规格板
- [x] 实测坐实 `image-rendering: pixelated` 在微信渲染器生效（同图 A/B 对照）
### 未完成 / 待上线动作
- [ ] **③ 迁移落库**：`chengyinhub-admin/sql/migration_merchant_npc_menu_20260824.sql`（合并**前**跑；不跑=后台没菜单且直连 403，零告警）
- [ ] 合并 PR #820（① 后端运行时，合并即真部署）
- [ ] `chengyinhub-ui` 单独构建部署（`ci/deploy-ui.sh`，不在 jar 链路里）
- [ ] ② 小程序微信上传
- [ ] **`www.chengyinhub.com` 加进 downloadFile 合法域名**（canvas 取图需要，`<image>` 不需要；没配则地图头像 `onerror` 零提示，长得跟「运营还没配」一样）
- [ ] 配一个真商家形象，走一遍：后台新增 → 回读 `npc_profile` 确认 `active_slot IS NULL` → 小程序看店铺主页 → 看漫游地图
- [ ] 地图 marker 真实渲染的实机观测（本地只能测 data URI，不是生产的 https+downloadFile 路径，故未造假绿）
### 后续可做（本批刻意不做）

## Source: 城瘾vault/04-未开始/提审后产品积压_20260812/小程序AI技能升级_TODO_2026-06-27.md

## 城瘾小程序 AI 技能升级 · TODO
### M0 · 前置与合规(用户/运营侧,非代码)
- [ ] 确认小程序主体为**企业**(微信公众平台 → 基本设置)—— M4 类目前提
- [ ] 微信"服务市场"下单一个**境内备案大模型**服务(通常 0 元),保存**订单截图 + 算法备案截图**
- [ ] 选定模型供应商与接入方式(通义/文心/豆包/DeepSeek 任一,需境内 + 已备案)
- [ ] 隐私政策/用户协议补充"AI 辅助生成内容"说明
- [ ] (M4 前)申请"深度合成-AI问答"服务类目,提交模型方算法备案 + 双方合作协议
- [ ] (M4 前)配置消息推送 URL + `wx.msgpush.[redacted]
### M1 · AI 商家组题助手(第一优先级 ★)
#### M1.1 后端 · 规则筛选层(事实由系统给,不交 AI)
- [x] 新建商家候选筛选服务:按位置/距离/营业时间/商家类型/审核状态/可接待/奖励库存过滤
- [ ] 候选集**上限 Top-15**(距离 × 评分 × 库存加权排序),控成本与幻觉
- [x] 复用现有商家/活动数据源,不新建商家业务表
#### M1.2 后端 · AI 网关 + 接口
- [x] 新建 `POST /api/ai/theme/merchant-plan`(JWT + roleGuard,仅俱乐部/商家身份开放)
- [x] 接入境内大模型调用封装(超时、重试、降级兜底) · **2026-08-05 核 master**:`AiGatewayServiceImpl` + `AiGatewayServiceImplTest` 均在
- [x] **入参内容安全** `checkText`:命中风险直接拒绝
- [x] **出参内容安全** `checkText`/`media_check_async`:命中→不展示或替换;检测异常→只存草稿不放行
- [x] AI 输出 JSON 结构对齐 `fabu` 编辑器字段(主题→节点→任务/提示,见报告 §6.1)
- [x] 频控(单用户/日)+ 单次 token 上限 + 成本记录 · **2026-08-05 核 master**:`/api/ai/theme/draft/quota` 端点在,`pages/publish/simple` 在调
- [x] 写 `ai_generation_log` + `ai_merchant_match_snapshot`
#### M1.3 数据表
- [x] `ai_generation_log`(用户/角色/场景/输入摘要/输出摘要/模型/耗时/安全结果/token)
- [x] `ai_merchant_match_snapshot`(候选商家/筛选条件/AI 选择理由)
- [ ] 草稿:**优先复用** `/api/template/draft`;不足时再评估 `ai_draft_plan` 或扩字段
- [ ] DB 迁移按 [[chengyin-db-migrate]] 安全路径执行(只读预检 + 用户确认)
#### M1.4 小程序前端
- [x] 俱乐部侧入口:一句话想法输入框(放俱乐部管理台/发布入口) · **2026-08-05 核 master**:`/api/ai/club/design` 由 `pages/club/detail/index.js` 调用
- [x] 调 `merchant-plan`,展示 2~3 套**方案卡**(主题名/路线故事/节点/适配理由/风险) · **2026-08-05 核 master**:`/api/ai/theme/merchant-plan` 端点在
- [ ] "选用此方案"→ 保存为主题草稿,跳 `fabu` 可继续编辑
- [x] 方案卡显式标注"AI 辅助生成" · **2026-08-05 核 master**:`components/cy/ai-assist` 与 `pages/club/detail` 均有 AI 标识文案
- [ ] 走现有 `app.sendRequest` 通道 + roleGuard 身份校验
#### M1.5 验收
- [ ] 输入一句想法 → 得到 2~3 套含**真实候选商家**的可编辑方案
- [ ] 选中方案 → 生成可在 `fabu` 继续编辑的主题草稿
- [x] AI 不写距离/库存/审核状态(全部由规则提供)
- [x] 全链路留痕(log + snapshot),发布仍走现有审核
### M2 · 节点任务 + 草稿助手 + 发布前预检
#### M2.1 接口
- [x] `POST /api/ai/theme/draft`:一句话→主题草稿;补齐标题/副标题/简介/亮点
- [x] `POST /api/ai/node/generate`:节点问答/店内任务/拍照打卡/扫码提示/三层提示/通关语
- [x] `POST /api/ai/safety/precheck`:发布前缺口与风险(缺封面/缺票/缺节点/距离/营业冲突)
- [x] 三接口同样:JWT + roleGuard + 入出参内容安全 + log + 频控
#### M2.2 前端接入
- [x] `pages/publish/fabu` 接草稿助手("一句话生成"/"按节点补剧情")
- [ ] `pages/publish/temp` 节点编辑器接 `node/generate`
- [x] 发布前调 `safety/precheck` 展示缺口/风险提示 · **2026-08-05 核 master**:`/api/ai/safety/precheck` 由 `pages/publish/fabu/index.js` 调用
#### M2.3 边界(必须守)
- [x] 只生成草稿,不自动 `topic/create`、`activity/publish`
- [x] 不做 AI 自动判答/判图/给分/发奖励/改进度
- [ ] AI 配图(若有)写隐式水印 + 显式"AI 生成"标识
### M3 · 商家 / 俱乐部工作台(建议,不控制)
#### M3.1 接口
- [x] `POST /api/ai/merchant/ta[redacted]
- [x] `POST /api/ai/club/design`:活动策划/路线优化/活动文案/风险提示/活动复盘
#### M3.2 前端
- [x] 商家侧:"我适合参与哪些主题"建议入口 · **2026-08-05 核 master**:`/api/ai/merchant/ta[redacted] 由 `pages/merchant/marketing/index.js` 调用
- [x] 俱乐部侧:"哪些商家适合我的活动"建议入口 · **2026-08-05 核 master**:同上,`/api/ai/club/design` 已接通
- [ ] 产出可直接用于沟通/编辑;不自动发券/改库存/上架/群发
### M4 · 玩家侧轻量 NPC
#### M4.1 不触发类目部分(可先做)
- [x] 预生成事件话术(脚本化):打卡/答错/通关弹 NPC 文案
- [x] 性能:事件话术 ≤200ms 出字;AI 限流时话术照常(降级兜底)
- [ ] 对接 [[城瘾Questify_AI-NPC陪伴系统_设计报告_2026-06-27]] 的人设/记忆设计
#### M4.2 触发类目部分(M0 类目+备案齐备后才上线)
- [ ] 实时开放追问(调大模型)+ 入出参内容安全 + AIGC 标识
- [ ] 上线前确认:企业主体 + 深度合成类目 + 算法备案材料齐备
### 红线(全程不做)
- [x] ⛔ AI 自动发布 / 自动审核 / 自动判图判答 / 自动发券 / 自动报名支付 / 自动改积分进度 / 自动群发营销
### 已完成

## Source: 城瘾vault/05-参考资料/AI创作助手_TODO_2026-06-27.md

## 城瘾小程序 AI 创作助手 · TODO
### 任务清单
#### A. 后端地基
- [x] A1 `application.yml` 加 `ai:` 配置块 + `AiModelConfig`(@Value 读取) → e09b5df
- [x] A2 `LlmClient` 接口 + `MockLlmClient`(确定性假数据)+ `QwenLlmClient`/`DeepSeekLlmClient` 骨架 → 81885bc
- [x] A3 `AiGatewayService`(频控 + 入/出 checkText + 落 ai_generation_log) → dd2f42d
- [x] A4 迁移:`migration_ai_generation_log.sql` + `migration_ai_merchant_match_snapshot.sql`(待 chengyin-db-migrate 落库) → 4d66b20
#### B. 后端 4 接口
- [x] B1 候选商家:`ApiAiMapper` + `ApiAiMapper.xml`(Haversine 扩列)+ `MerchantCandidateVO` → b574bed
- [x] B2 DTO/VO:`ai/` 下 4 组请求 + `AiThemePlan/AiPlanNode/AiNodeContent` 等 → dc03670
- [x] B3 `AiCreatorServiceImpl`:merchant-plan / theme-draft / node-generate / safety-precheck 编排 → c4e7c6b
- [x] B4 `ApiAiController`:4 个 `/api/ai/*` 接口(身份门禁 + getAppUserId) → 74bafeb
#### C. 小程序
- [x] C1 AI 创作页 `subpackageP3/pages/ai/theme-plan/` 四件套 + app.json 注册 → 3f9ed61
- [x] C2 role/center 入口(club/merchant 显)+ 跳转 → 3f9ed61
- [x] C3 fabu 回填钩子:onLoad/onShow 读 `ai_topic_draft`(isBlankTopicDraft 门控)+ 玩法逐节点建模板回填 → 3f9ed61
#### D. 收尾
- [x] D1 自验证:后端 `mvn compile` 编译过 + 关键链路自查(mock 往返/频控/安全分支) → 8deb930
- [x] D2 对抗式 review(多代理)→ push 到 Codeup
### 变更记录
#### 2026-06-27 · 第 1 版 / AI 创作三件套初版(M1+M2,mock模型)
### 待部署清单(攒着统一上传,push≠部署)

## Source: 城瘾vault/05-参考资料/AI创作助手_系统设计_2026-06-27.md

## 城瘾小程序 AI 创作助手 · 系统设计
### 0. 已核验底座(写码前必读的纠正项)
| 维度 | 真实事实(已核验) |
|---|---|
| 包根 | `com.chengyinhub`(非 ruoyi) |
| 取登录用户 | `BaseController.getAppUserId()`(L202);未登录抛异常 → `try/catch` 返回 `error("请先登录")` |
| 鉴权 | `/api/ai/**` 不进白名单即**自动需登录**(SecurityConfig L143 `anyRequest().authenticated()`,JWT filter 按 `/api/` 前缀走 App[redacted] |
| 统一响应 | `AjaxResult`(`success(data)`/`error(msg)`),`{code,msg,data}` |
| 内容安全 | `IWxContentSecurityService.checkText(content, openid)` 返回 **String:null=放行,非null=拦截文案**;当前 **fail-open**;`joinText(...)` 拼多段;**不要改公共实现**(7 处复用) |
| 主题/节点 | **双实体**:`cms_topic_node`(地点/坐标/order)+ `cms_member_template`(玩法),靠 `templateId` 串;节点层无 merchantId/role 字段;hint 仅 `hint1`/`hint2`(+`answerReveal`) |
| 附近商家 | 经纬度在 `cms_registration_merchant`;**现成 Haversine** `ApiMapMapper.selectNearbyNodes`(复用扩列) |
| 落库入口 | `ICmsTopicService.createTopic(TopicCreateDTO, memberId, username)`;`ITemplatePublishService.saveOrUpdateDraft(CmsTemplatePublishRequest, memberId, username)` |
| 出站 HTTP | `HttpUtils.sendPost` **不支持自定义 header** → 用 hutool `cn.hutool.http.HttpRequest`(已在依赖)带 `Authorization: Bearer` |
| Redis | `RedisCache`(set/get/expire,无 increment);原子自增用 `RedisTemplate.opsForValue().increment` |
| 迁移 | `chengyinhub-admin/sql/migration_<topic>.sql`;`del_flag`(0存在/2删除)、`create_time`;`CREATE TABLE IF NOT EXISTS`;**先落库再部署 jar** |
### 1. 模块拆解
| 模块 | 职责 | 落点(绝对路径) |
|------|------|------|
| AI 配置 | `ai.model.*` 配置项 + 读取 | `chengyinhub-admin/src/main/resources/application.yml`(末尾);`chengyinhub-common/.../common/config/AiModelConfig.java` |
| LlmClient 抽象 | 可切换模型接口 + mock/qwen/deepseek | `chengyinhub-system/.../business/service/ai/LlmClient.java` + `impl/{MockLlmClient,QwenLlmClient,DeepSeekLlmClient}.java` |
| AI 网关 | 频控 + 入/出内容安全 + 落 log | `chengyinhub-system/.../business/service/ai/AiGatewayService.java`(+impl) |
| 候选商家查询 | Haversine 扩列 Top-15 | `chengyinhub-system/.../business/mapper/ApiAiMapper.java` + `resources/mapper/business/ApiAiMapper.xml` + `domain/vo/MerchantCandidateVO.java` |
| AI 创作服务 | 组题/草稿/节点/预检 4 能力编排 | `chengyinhub-system/.../business/service/IAiCreatorService.java` + `impl/AiCreatorServiceImpl.java` |
| 控制器 | `/api/ai/*` 4 接口 | `chengyinhub-admin/.../web/controller/api/ApiAiController.java` |
| DTO/VO | 入参出参 | `chengyinhub-system/.../business/domain/dto/ai/*` + `domain/vo/ai/*` |
| 迁移 | 2 张表 | `chengyinhub-admin/sql/migration_ai_generation_log.sql`、`migration_ai_merchant_match_snapshot.sql` |
| 小程序 AI 页 | 组题/草稿/节点助手/预检 UI + 回填 | `chengyinhub-xcx/subpackageP3/pages/ai/theme-plan/index.{js,wxml,wxss,json}` |
| 小程序入口 | role/center 跳转 | `chengyinhub-xcx/pages/role/center/index.{js,wxml}`(最小新增) |
| 回填钩子 | fabu 读 ai_topic_draft | `chengyinhub-xcx/pages/publish/fabu/index.js`(onLoad/onShow 最小新增) |
### 2. 数据库设计(本期 +2 表;用 chengyin-db-migrate 落库,勿直连)
#### 2.1 `ai_generation_log` — AI 调用审计(所有 `/api/ai/*` 都写)
#### 2.2 `ai_merchant_match_snapshot` — 组题候选快照(复盘/申诉)
### 3. 候选商家查询(M1 事实源,复用 Haversine)
### 4. LlmClient 抽象(可切换;本期 mock)
1. 每日频控:`RedisCache` key `ai:gen:limit:{memberId}:{yyyyMMdd}` ≥ dailyLimit → 抛 `ServiceException("今日AI次数已用完")`(或返回 safety verdict)。命中后 `RedisTemplate.increment` + 首次 `expire(86400s)`。
2. 入参 `checkText(userPrompt摘要, openid)` → 非 null:记 `safety_flag=1`、抛拦截。
3. `llmClient.chat(systemPrompt, userPrompt)` 计时;异常/超时 → 记录并抛"AI 繁忙稍后再试"。
4. 出参 `checkText(modelText, openid)` → 非 null:记 `safety_flag=2`、抛"生成内容未通过安全检测"。
5. 落 `ai_generation_log`(brief 截断 512)。返回 `{traceId, text}`。
### 5. 接口契约(`/api/ai/*`,全部新增,不改现有发布接口)
#### 5.1 `POST /api/ai/theme/merchant-plan`(M1 组题)
#### 5.2 `POST /api/ai/theme/draft`(M2 主题草稿)
#### 5.3 `POST /api/ai/node/generate`(M2 节点/谜题助手)
#### 5.4 `POST /api/ai/safety/precheck`(M2 发布前预检)
### 6. AI 输出 → 小程序回填 fabu 映射(头号结构性适配点)
| AI 字段 | → fabu formData 路径 | 适配 |
|---|---|---|
| `title/subtitle/storyline` | `name/subtitle/description` | 直填(storyline→description) |
| `nodes[].order` | `chapters[0].nodes[j].sortID` | 回填时自算 `j+1`,不信 AI 序号 |
| `nodes[].merchantName/address` | `nodes[j].name?/address` | address 直填;name 用节点名 |
| `nodes[].longitude/latitude` | `nodes[j].longitude/latitude` | **必须 `String()`**(fabu 全程字符串) |
| `nodes[].businessTime` | `nodes[j].businessTime` | 直填 |
| 玩法(task/question/hint/feedback) | **不能直挂节点** | 需先 `POST /api/template/draft` 拿 `templateId` → 写 `nodes[j].templateId/templateName/templateInfo` |
| 封面 imgUrl | `formData.imgUrl` | **留空逼用户上传**(AI 无真实图) |
| 分类 categoryIds | — | AI 给不了真实 ID,留空,用户在标签页选(否则 validateForm 拦) |
| tickets | `formData.tickets` | AI 不产出,默认免费体验票兜底 `{name:'体验票',price:0,totalStock:100,mode:2}` |
| `_localId/_collapsed/showTemplate` | — | 不让 AI 生成,回填后 `_ensureLocalIds()` 自动补 |
### 7. 前后端职责划分
### 8. 核心逻辑与边界
### 9. 合规 Checklist(对齐报告 §9)
- [ ] 输入命中安全 → 直接拒绝(safety_flag=1)。
- [ ] 输出命中安全 → 不展示,返回安全提示(safety_flag=2)。
- [ ] AI 内容显式标识"AI 辅助生成"(方案卡 + 回填 description 带标注)。
- [ ] 发布前必须用户确认(AI 只回填草稿,发布走现有链路 + 人工审核)。
- [ ] 奖励/价格/库存/核销 → 走规则,AI 不决定(rewardSuggest 仅文案)。
- [ ] 每次调用落 `ai_generation_log`;频控生效。
- [ ] 真模型上线前补"深度合成-AI问答"类目(本期 mock + 草稿模式,不触发)。

## Source: 城瘾vault/05-参考资料/_重复/AI创作助手_项目总览_2026-06-27.md

## 城瘾小程序 AI 创作助手 · 项目总览
### 项目目标
### 使用场景
### 核心功能(本期 = Report1 创作三件套)
1. **AI 商家组题助手(M1)** — `POST /api/ai/theme/merchant-plan`:附近商家 → 规则筛 Top-15 → AI 出 2~3 套主题方案。
2. **AI 主题草稿助手(M2)** — `POST /api/ai/theme/draft`:一句话 → 主题草稿骨架(对齐 fabu 数据树)。
3. **AI 节点/谜题助手(M2)** — `POST /api/ai/node/generate`:为节点生成任务/答题/三层提示/反馈语。
4. **AI 发布前安全预检(M2)** — `POST /api/ai/safety/precheck`:内容安全双检 + AI 缺口/风险提示。
### MVP 范围
### 技术栈
### 架构说明
### 关键决策与假设(开工前已锁定)
### 相关文档

## Source: 城瘾vault/05-参考资料/小程序AI技能升级_可落地报告_2026-06-27.md

## 城瘾小程序 AI 技能升级 · 可落地报告
### 0. TL;DR(给决策者)
### 1. 当前系统可用底座(已逐条代码核验 2026-06-27)
| 能力 | 位置 | 核验 |
|---|---|---|
| 请求统一收口 + 自动注入认证头 | `chengyinhub-xcx/app.js:315`(`sendRequest` 收口到 `utils/transport/request-client.js`) | ✅ |
| 三身份权限单一事实源 | `utils/roleGuard.js`(缓存 `/api/role/info`)+ `utils/identity/identity-policy.js` | ✅(注意路径在 `utils/identity/` 下) |
| 文本内容安全(同步) | `IWxContentSecurityService.checkText()` → 微信 `msgSecCheck v2` | ✅ |
| 图片内容安全(异步)+ 违规自动下架 | `WxContentSecurityServiceImpl.checkMediaAsync/submitMediaCheck/handleMediaCheckResult` + `/api/content-sec/callback` | ✅ |
| 主题/活动发布链路 | `pages/publish/fabu/index.js:2303` → `/api/topic/create`;`pages/publish/activity/index.js:251` → `/api/activity/publish` | ✅ |
| 草稿能力 | `pages/publish/simple/index.js:460` → `/api/template/draft` | ✅(AI 草稿应优先复用,见 §8) |
| 后端业务域 | `ApiTopicController` / `ApiActivityController` / 模板 / 商家 / 俱乐部 / 广场 / IM / 审核工作台 | ✅ 已存在 |
### 2. 微信平台与法规口径(必须先看清)
#### 2.1 两条技术路线
| 路线 | 说明 | 城瘾选择 |
|---|---|---|
| **微信"小程序 AI 开发模式"** | 微信官方 AI 能力,需把小程序能力封装成原子接口/组件/SKILL 供其调用;官方文档提示 **beta、暂未开放代码提审**,不应合入正式审核版 | ❌ 暂不走 |
| **小程序内自建 AI** | 自己的页面调自己的后端 `/api/ai/*`,后端再接**境内备案模型** | ✅ 走这条 |
#### 2.2 内容安全(强约束,已具备)
#### 2.3 深度合成类目 + 算法备案(关键门槛 + 分期优势)
#### 2.4 法规与 AIGC 标识
### 3. 功能总蓝图(按身份)
### 4. 第一优先级 ★ AI 商家组题助手(M1)
#### 4.1 用户场景
1. **后端规则筛选**:按位置、距离、营业时间、商家类型、审核状态、可接待能力、奖励库存,选出候选商家(限 Top-N,见 §4.3)。
2. **AI 只拿"已筛好的候选商家"做组合**(不碰距离/库存/审核)。
3. AI 输出 **2~3 套主题方案**。
4. 每套方案含:主题名、路线故事、节点顺序、每家商家的任务角色、奖励建议、适合该俱乐部的理由、风险提示。
5. 俱乐部选一套 → **保存为主题草稿**。
6. 用户人工确认 → 走现有 `/api/topic/create` 发布 → 现有内容安全 + 审核。
#### 4.2 AI vs 规则 的分工(本方案的核心设计)
| AI 负责(策划与表达) | 规则/系统负责(事实与边界) |
|---|---|
| 主题命名、剧情包装 | 距离、营业时间 |
| 节点任务生成 | 商家审核状态、库存 |
| 商家匹配解释、俱乐部适配理由 | 权限与配额 |
| 活动宣传文案、风险提示文案 | 是否可发券 / 是否能发布 / 是否进审核 |
#### 4.3 工程边界
### 5. 第二/第三优先级
#### 5.1 AI 主题/路线草稿助手(M2)
#### 5.2 AI 节点/谜题助手(M2 内)
#### 5.3 商家侧 AI(M3)
#### 5.4 玩家侧轻量 NPC(M4)
### 6. 后端接口契约(全部新增,不改现有发布接口)
| 接口 | 用途 | 阶段 |
|---|---|---|
| `POST /api/ai/theme/merchant-plan` | 附近商家组题,输出多套主题方案 | M1 |
| `POST /api/ai/theme/draft` | 生成主题草稿 | M2 |
| `POST /api/ai/node/generate` | 生成节点任务/谜题/提示 | M2 |
| `POST /api/ai/merchant/ta[redacted] | 商家任务建议 | M3 |
| `POST /api/ai/club/design` | 俱乐部活动策划 | M3 |
| `POST /api/ai/safety/precheck` | 发布前 AI 风险预检 | M2 |
#### 6.1(=§7.1) `merchant-plan` 契约示例
### 7. 数据表建议(第一期最小)
| 表 | 用途 |
|---|---|
| `ai_generation_log` | 用户、角色、场景、输入摘要、输出摘要、模型、耗时、安全结果、token/成本 |
| `ai_draft_plan` | 保存 AI 主题/节点/商家方案草稿(若现有草稿表可加字段承载,则优先扩字段) |
| `ai_merchant_match_snapshot` | 某次组题的候选商家、筛选条件、AI 选择理由(复盘/申诉用) |
### 8. 架构与数据流
### 9. 合规与安全边界 Checklist
- [ ] 输入命中风险 → 直接拒绝。
- [ ] 输出命中风险 → 不展示或替换为安全提示。
- [ ] 检测异常 → **不得直接放行发布**,仅存草稿或提示稍后重试。
- [ ] AI 内容显式标识"AI 生成/AI 辅助";AI 配图写隐式水印(若有)。
- [ ] 商家/俱乐部/活动/主题相关 AI 内容,**发布前必须用户确认**。
- [ ] 涉及商家奖励/价格/库存/核销 → 走规则与人工配置,AI 不决定。
- [ ] 定位仅前台按需采集,**不后台持续定位**。
- [ ] M4 实时对话上线前:企业主体 + "深度合成-AI问答"类目 + 模型方算法备案材料齐备。
- [ ] 每次 AI 调用留 `ai_generation_log`;频控 + 成本上限生效。
### 10. 分期路线与验收
| 阶段 | 内容 | 验收标准 |
|---|---|---|
| **M1** AI 商家组题助手 | 规则筛附近已审核商家 → AI 出 3 套方案 → 方案卡 → 俱乐部选后存草稿 | 输入一句想法,能得到 2~3 套含真实候选商家的可编辑方案,选中即生成可继续编辑的主题草稿 |
| **M2** AI 节点任务助手 + 草稿助手 + 发布前预检 | 为选中商家/地点生成任务/谜题/提示;接入发布页草稿;`safety/precheck` | 草稿可一键补全;发布前能给出缺口与风险提示;输出过内容安全 |
| **M3** 商家/俱乐部工作台 | 商家"我适合参与哪些主题";俱乐部"哪些商家适合我";合作话术/活动文案 | 两身份各有一个 AI 建议入口,产出可直接用于沟通/编辑 |
| **M4** 轻量 NPC | 预生成事件话术(打卡/答错/通关);实时追问(需先办类目+备案) | 事件话术 ≤200ms 出字;AI 限流时话术照常(降级兜底) |
### 11. 风险与红线(汇总)
### 12. 用户需要做的事(非代码)
1. **确认小程序主体为企业**(微信公众平台 → 基本设置)——M4 类目前提。
2. **微信"服务市场"下单一个境内大模型服务(通常 0 元)**——拿订单截图 + 算法备案截图,既是模型接入,也是 M4 类目申请材料。
3. M4 前:补"深度合成-AI问答"服务类目;配置消息推送 URL + `wx.msgpush.[redacted]
4. 准备/更新隐私政策与用户协议,加入"AI 辅助生成内容"说明。
### 13. 最终建议

## Source: 城瘾vault/05-参考资料/归档_20260803/状态终审_原03/漫游AI_远征玩法重构与状态机设计_20260722.md

## 漫游 AI 远征玩法重构与状态机设计
### 1. 决策摘要
#### 1.1 这次不再做什么
1. 玩家必须先想到问题，AI 才出现；这把“下一步该做什么”的负担交回给玩家。
2. AI 与格子点亮、POI 到访、拍照、盖销票、结算等已有系统割裂，只能说一句话，不能推进游戏。
3. Sheet 与附近提示、探店卡、结算层争夺注意力，最终成为又一个可关闭的信息层。
#### 1.2 要做成什么
#### 1.3 北极星
### 2. 当前体验诊断
#### 2.1 已有的正确底盘
#### 2.2 断裂点
| 现有能力 | 当前表现 | 造成的问题 |
|---|---|---|
| 当前目标层 | 提示“开定位 / 去看看 / 继续走” | 只有操作提示，没有主题、章节或完成意义 |
| 事件 NPC | 开场、首次 POI、25/80 格、结算时展示气泡 | 是一次性文案，不形成可继续的任务链 |
| Chat | 右侧 FAB 打开 Sheet，自由输入 | 是工具入口，不是游戏状态；与主循环抢注意力 |
| 集邮 | 拍摄、盖销、收藏可沉淀 | 与 AI 没有叙事或任务关系，收藏的“为什么”缺席 |
| 结算 | 显示已完成的战绩 | 缺少“本次远征完成了什么、下次还可追什么”的闭环 |
#### 2.3 设计判断
### 3. 产品模型：AI 远征导演，而非 AI 陪伴或聊天机器人
#### 3.1 AI 的三项职责
| 角色 | 对玩家的价值 | AI 可以做什么 |
|---|---|---|
| 导演 | 让玩家随时知道“为何走、下一步选什么” | 从已审核的探索线中选择合适章节，给出 1 个当前目标与 2–3 个方向 |
| 叙事者 | 让真实行动拥有上下文和情绪回报 | 用短文本解释本次发现的意义，串联章节，不拟人依附 |
| 策展人 | 让路线、照片、邮票成为可回看的成果 | 为远征页生成标题、摘要、线索标签和收藏编排建议 |
#### 3.2 AI 绝不能拥有的权力
### 4. 核心玩法循环
#### 4.1 一次远征的五幕
| 幕 | 玩家看到什么 | 玩家做什么 | 系统获得的可信证据 |
|---|---|---|---|
| 1. 出发 | 本次探索线及一条简短承诺，例如“沿着街区收集三种城市纹理” | 选一条探索线，或直接开始默认线 | 会话开始、用户选择 |
| 2. 定向 | 常驻远征 HUD 显示当前章节、目标和可选方向 | 选择一个方向或跟随默认目标 | 已选 branch、目标版本 |
| 3. 探索 | 地图上只显示与当前目标有关的轻量提示 | 走路、点亮格子、首次到访、拍照/盖销 | 服务端格子、POI、照片、会话事件 |
| 4. 发现 | 一个短促的“章节推进时刻”，不是阻塞弹窗 | 查看发现、选择下一分支或继续走 | 已验证 evidence 触发状态转移 |
| 5. 沉淀 | 远征结算页：本次路线、完成章节、照片/邮票、未解线索 | 收藏、分享、开始下一次远征 | 会话结算、收藏资产、完成记录 |
#### 4.2 三种首发探索线（内容样例，不代表最终命名）
1. **拾取城市纹理**：完成指定数量的格子、首次发现或照片证据，收集“光 / 声 / 旧物”等主题标签。
2. **街区微远征**：在一个可验证的片区完成“抵达—发现—沉淀”三步，形成一页远征记录。
3. **盖销巡游**：围绕真实漫游会话拍摄、盖销和集邮册页，AI 负责把单张票组织为章节，而非生成图片资产。
#### 4.3 目标的最小规格
### 5. 远征状态机
#### 5.1 核心实体
#### 5.2 状态与转移
#### 5.3 转移的唯一输入
| 输入事件 | 可推进什么 | 不可由它推进什么 |
|---|---|---|
| `SESSION_STARTED` | 发放默认探索线 | 直接发奖励 |
| `TILE_REVEALED` / 唯一格子数变化 | 目标进度、章节候选 | 认定到访商家 |
| `POI_FIRST_VISIT` | 首次发现目标、线索解锁 | 重复刷进度 |
| `STAMP_CREATED` / 已验证照片 | 收藏型目标、远征页素材 | 绕过图片审核 |
| `SESSION_FINISHED` | 强制收束到结算、产出摘要 | 给未验证目标补完成 |
| 用户跳过 | 回到安全默认目标 | 处罚、扣已有收益 |
| 内容/规则/安全/开关故障 | 进入 `DEGRADED`，退回现有目标层 | 伪造章节、伪造目标完成 |
#### 5.4 结算规则
### 6. 体验结构：从弹窗改为远征 HUD
#### 6.1 常驻层级
1. **远征 HUD（主层）**：展示探索线、当前章节、一个目标、一个进度与一个下一步动作；不可随手关闭，但可最小化。
2. **地图行动层**：只在与当前目标有关的位置/时刻给出轻量提示；不叠加营销卡、气泡和大段文案。
3. **发现时刻（瞬时层）**：证据被验证后出现 1–2 秒的章节推进反馈，再回到 HUD。
4. **结算远征页（沉淀层）**：在现有结算中增加“本次远征”而非新增平行页面。
5. **旅程工具（次级层）**：可包含“为什么这个目标”“如何完成”“报告问题”。自由问答如保留，只能在这里，绝不是主入口。
#### 6.2 必须消失的模式
#### 6.3 文案原则
### 7. 内容系统与模型边界
#### 7.1 内容资产
#### 7.2 模型可做与不可做
| 能力 | 允许方式 | 禁止方式 |
|---|---|---|
| 章节文案 | 基于已验证结构化摘要生成短文，输出审核后展示 | 传入精确轨迹、联系方式或自由历史全文 |
| 分支建议 | 只在已配置 branch 集合内排序/解释 | 生成未审核的新奖励、新地点事实或消费任务 |
| 远征摘要 | 读取已结算的统计、照片/邮票标题 | 决定资产归属、审核或公开范围 |
| 玩家提问 | 解释当前规则和下一步，可随时退出 | 发展陪伴、专业建议或实时商业/导航承诺 |
#### 7.3 Phase B 的固定决策顺序
1. 规则引擎读取已验证 evidence，决定状态转移
2. 规则引擎从已审核 thread / objective / branch 白名单中选出唯一候选
3. 生成结构化 NarrativeRequest（不含隐私原文、精确轨迹、奖励资格）
4. 模型仅生成短叙事、标题或候选解释
5. 输出安全审核；通过才展示，失败则回退到同一目标的预审文案
#### 7.4 安全与合规继承
### 8. 指标与验收
#### 8.1 玩法指标
#### 8.2 验收门槛
### 9. 分期路线
#### Phase A：无生成模型的远征底盘
#### Phase B：AI 受限叙事与分支解释
#### Phase C：旅程工具中的受限问答
#### Phase D：远征系列与 Live Ops
### 10. 对现有 Phase 3 / PR #187 的建议性范围影响（待产品拍板）
#### 10.1 保留的能力
#### 10.2 草案建议不作为产品交付的内容
#### 10.3 若采纳本草案，后续实施前必须完成的书面变更
1. 在旧 AI 方案中把“Chat 稳定入口 / Sheet”改标为“基础设施或次级旅程工具”，不再作为主玩法验收项。
2. 新建远征状态、内容资产、HUD 与结算沉淀的独立需求清单；不得把它们塞进现有 Chat 卡继续扩张。
3. 重新定义 Event Go Gate 与生成式 Go Gate：Event 首先服务远征状态机，不再只验证气泡是否出现。
4. 在产品、合规、内容运营共同确认前，生产 `roamNpcEvent`/`roamNpcChat` 继续保持 false。
### 11. 非目标与风险清单
#### 11.1 非目标
#### 11.2 最大风险与对策
| 风险 | 对策 |
|---|---|
| 远征只是换皮任务清单 | 每个目标必须有主题、证据、章节变化和沉淀，不只加计数器 |
| 模型胡编任务或事实 | 目标/分支白名单，模型只表达和排序 |
| 玩法打断真实漫游 | HUD 常驻但可最小化；瞬时反馈不阻塞；跳过无惩罚 |
| 内容很快重复 | 先扩充策划资产和组合规则，再扩大生成比例 |
| 安全与合规被“游戏感”掩盖 | 继续使用既有独立 Go Gate，生成失败一律降级 |
### 12. 历史草案中原列的待拍板问题（不适用当前 AI 基座）
1. 首发是只做一条“默认远征”，还是同时做 2–3 条探索线？
2. 玩家是显式选择探索线，还是默认进入、在第一次分支时才选择？
3. 首发的核心沉淀是邮票、远征页，还是两者同时出现？
4. Phase A 是否完全不用模型，以确定性内容先验证玩法？
5. 旧 Chat PR 是保留为技术底座、拆出后端能力，还是继续作为内部调试工具？
6. 谁拥有探索线、目标模板和文案版本的审核发布权？

## Source: 城瘾vault/05-参考资料/归档_20260803/状态终审_原03/漫游AI功能_最优架构安全治理与实施补充方案_20260716.md

## 漫游 AI 功能最优架构、安全治理与实施补充方案
### 1. 执行摘要
#### 1.1 最终结论
1. **把 V1 产品定位为“会话内城市探索 AI 游戏向导”，不是长期情感陪伴产品。**
2. **将预审事件 NPC 与自由追问拆成两个独立能力、两个独立开关。**
3. **预审事件话术先上线；自由追问必须完成后端生产门禁与合规闸门后再灰度。**
4. **NPC chat 不再绕过 AI 网关直接调用模型，而是复用统一的频控、安全、路由、日志和降级机制。**
5. **V1 不使用服务端 SSE：采用普通 POST 返回完整审核结果，客户端收到 PASS 后仅做本地逐字呈现。**
6. **模型供应商不靠代码注释拍板，必须通过同一套离线评测决定主模型和备用模型。**
7. **V1 只使用当前漫游会话的游戏进度，不建立长期情绪记忆，不默认把聊天内容用于训练。**
8. **上线采用后端先行、开关默认关闭、体验版灰度、线上回读观测的分阶段路径。**
#### 1.2 Go / No-Go 判定
| 能力 | 当前判定 | 说明 |
|---|---|---|
| 预审事件气泡 | 有条件 Go | 修复 GET 鉴权、远程开关、埋点、UI 层级和确定性测试后可先上线 |
| 结算 NPC 台词 | 有条件 Go | 与事件气泡共用安全缓存能力，不调用模型 |
| 自由追问 chat | No-Go | 当前缺少真实日限、并发限制、输入校验、安全输出顺序、合规与数据治理闭环 |
| 长期记忆/情感陪伴 | 明确不做 | 不属于本期目标，且显著扩大产品、合规和未成年人风险 |
| 语音陪伴/后台持续对话 | 明确不做 | 需要新的隐私、音频标识、审核与平台能力评估 |
### 2. 产品定位与边界
#### 2.1 V1 产品定义
#### 2.2 为什么不把 V1 定义为“AI 陪伴”
#### 2.3 明确不做
### 3. 仓库现状核实
#### 3.1 已有能力
| 能力 | 当前实现 | 结论 |
|---|---|---|
| NPC profile | `ApiAiNpcController` + `NpcProfileService` | 接口存在，可解析全局 NPC |
| 事件话术 | `NpcEventService` + `npc_line_cache` | 支持任意 `event_type`，缓存命中时不调用模型 |
| Chat SSE | `NpcChatService` + `SseEmitter` | 现有链路存在，但 V1 不沿用；改为审核后一次性 POST 响应 |
| 模型客户端 | `LlmClient` + `OpenAiCompatibleLlmClient` | 可接 DeepSeek/MiniMax 等兼容端点 |
| 创作 AI 网关 | `AiGatewayServiceImpl` | 已有日限、输入/输出安全、模型选择和日志框架 |
| 场景路由 | `AiSceneRouter` | 代码中已有 `npc_chat -> minimax`、`npc_event -> cache` 的目标映射 |
| 微信内容安全 | `WxContentSecurityServiceImpl` | 已集中封装，启用后多数异常走 fail-close |
| NPC 对话日志 | `npc_chat_log` | 已有原始输入/输出、模型、延时和安全状态字段 |
| 小程序统一请求 | `request-client.js` | POST 默认带 token；GET 默认不带 token |
| 漫游埋点 | `analytics.js` | 已有 roam 开始、POI、结算事件，但新事件需双端白名单 |
| 远程开关 | `/api/config/features` | 通道存在，但目前没有 roam NPC 的开关键 |
#### 3.2 关键缺口
### 4. 最优目标架构
#### 4.1 总体原则
1. 页面只发送游戏领域事件，不管理 NPC 网络、节流和定时器细节。
2. 所有模型调用统一经过一个生产策略模块，不允许业务模块直接调用 provider。
3. 预审缓存与生成式对话完全分层，任何一层可独立关闭。
4. 默认 fail-close：安全、合规或成本门禁不可用时，关闭 chat，但不影响漫游主流程。
5. 原始聊天内容最小化、短周期、可删除；分析埋点只保留非敏感元数据。
6. 模型可替换，但业务接口、测试和用户体验不随供应商变化。
#### 4.2 架构图
#### 4.3 小程序深模块：`RoamNpcCoordinator`
#### 4.4 后端深模块：`AiInvocationPolicy`
1. 登录用户、功能资格与场景合法性。
2. 请求幂等和 requestId。
3. 输入长度、空值和枚举校验。
4. 每日、每分钟、单会话、并发和全局成本预算。
5. 输入内容安全与高风险意图识别。
6. 场景到模型 provider 的动态路由。
7. 超时、熔断、重试和备用 provider。
8. 输出内容安全。
9. 模型、[redacted]
10. 统一降级结果。
#### 4.5 Provider seam
### 5. 模型选择与评测方案
#### 5.1 不直接指定永久赢家
#### 5.2 评测集
#### 5.3 评分权重
| 指标 | 权重 | 硬门槛 |
|---|---:|---|
| 安全与边界遵守 | 35% | 高风险集不得出现严重漏放 |
| 角色一致性 | 20% | 不假装真人，不发展亲密依赖 |
| 城市探索实用性 | 20% | 回答与当前会话和玩法相关 |
| 延时与稳定性 | 15% | 满足目标 SLO |
| 单次成本 | 10% | 满足预算上限 |
#### 5.4 V1 推荐策略
### 6. 内容安全与对话边界
#### 6.1 V1 安全输出策略
1. 校验请求与频控。
2. 对用户输入做内容安全检查。
3. 调模型生成完整短回答。
4. 对完整回答做输出安全检查。
5. 只有 PASS 才通过普通 POST 返回完整 `safeText`。
6. 客户端收到结果后可本地逐字展示；HOLD/BLOCK 只返回预审安全回复。
#### 6.2 安全结果统一枚举
#### 6.3 Prompt 规则
#### 6.4 微信内容安全状态
#### 6.5 高风险处置矩阵
| 风险 | 判定 | 用户侧动作 | 记录/升级 |
|---|---|---|---|
| 明确即时自伤/伤人危险 | `REVIEW_REQUIRED` | 停止角色扮演；展示现实求助、联系身边可信人员及当地紧急服务的模板 | 高优先级安全事件；不得自动联系第三方，除非已有合法授权流程 |
| 一般极端情绪但无即时危险 | `INPUT_BLOCK` | 共情但不拟人依附；建议寻求现实支持，结束游戏建议 | 仅存最小安全分类和 requestId |
| 医疗/法律/金融确定性建议 | `INPUT_BLOCK` | 说明能力边界，建议咨询合格专业人士 | 常规安全统计 |
| 隐私、联系方式、精确住址 | `INPUT_BLOCK` | 提醒删除敏感信息，不复述原文 | 原文按最短期限；analytics 不入原文 |
| 线下危险、闯入、违规交通 | `INPUT_BLOCK` | 给公共安全与守法模板 | 常规安全统计 |
| 恋爱、亲属、真人身份绑定 | `INPUT_BLOCK` | 重申 AI 游戏向导身份，不延续关系设定 | 角色边界指标 |
| 消费诱导或商家导流 | `OUTPUT_BLOCK` | 返回中性探索兜底，不换 provider 重试 | 模型/Prompt 回归样本 |
| 未成年人高风险请求 | `INPUT_BLOCK` | 使用适龄安全模板；必要时建议寻求监护人帮助 | 安全负责人复核规则命中率 |
### 7. 合规与用户权益设计
#### 7.1 显式 AI 标识
#### 7.2 服务协议与同意
#### 7.3 未成年人策略
#### 7.4 用户退出、复制、删除与投诉
### 8. 数据最小化与记忆策略
#### 8.1 V1 只允许会话内游戏记忆
#### 8.2 `NpcMemoryBuilder` 目标行为
#### 8.3 日志治理
| 数据 | 目的 | 默认期限 | 删除/导出 | 访问与保护 |
|---|---|---:|---|---|
| message/reply 原文 | 投诉定位与短期质量排障 | 30 天 | JSON 导出；用户删除后 7 天内主库硬删 | 独立 RBAC、字段加密、查看审计 |
| 请求元数据 | 稳定性、成本和安全审计 | 180 天 | 可导出；删除时去标识化，法定保留例外单列 | 最小权限、不可含精确位置 |
| 举报关联证据 | 处理具体举报 | 结案后 180 天或合规确认期限 | 受保留例外约束并告知 | 仅安全/投诉角色 |
| Redis 额度/幂等键 | 频控和防重复 | 最长 48 小时 | 不进入用户导出；自动过期 | 不存原文 |
| Provider 请求 | 完成本次推理 | 供应商侧 0 训练、最短留存 | 合同/API 配置必须可证明 | 传输加密、禁止非必要字段 |
| 备份中的已删数据 | 灾备 | 随备份轮换，最长 30 天 | 不恢复到生产使用；到期物理淘汰 | 恢复操作审计 |
### 9. 事件 NPC 设计
#### 9.1 推荐事件类型
#### 9.2 里程碑口径
#### 9.3 话术治理
#### 9.4 防吵规则
### 10. Chat 协议与请求状态机
#### 10.1 请求契约
| 字段 | 来源 | 服务端约束 |
|---|---|---|
| token/userId | 登录态 | token 解析；永不信任 body 中的 userId |
| requestId | 客户端 | UUID 格式；与 userId 组成幂等键 |
| bizId | 客户端 | `roam_session.user_id = currentUserId`；状态与时间窗有效 |
| scene/profileId | 服务端 | 固定 ROAM；从当前已审核启用配置派生 |
| gameContext | 服务端 | 从归属已校验的会话聚合；客户端值一律忽略 |
| message | 客户端 | 长度、内容安全、隐私规则 |
| provider/model/promptVersion | 服务端 | 只由策略和版本配置决定 |
#### 10.2 响应契约
#### 10.3 幂等、额度与并发状态机
| 当前状态/事件 | 行为 | 额度 |
|---|---|---|
| 无记录 + 合法新请求 | 原子检查资格/频控，创建 `PROCESSING` 和 20 秒并发租约 | 预占 1 次 |
| 相同 requestId + `PROCESSING` | 返回 `REQUEST_IN_PROGRESS`，附 retryAfter | 不重复扣 |
| 相同 requestId + 终态 | 返回保存的同一终态摘要 | 不重复扣 |
| 输入安全拒绝 | 写 `REJECTED/INPUT_BLOCK`，释放并发租约 | 计 1 次，防探测滥用 |
| provider 未调用前的系统故障 | 写 `FAILED`，释放租约 | 返还预占 |
| provider 已调用后超时/失败 | 写 `FAILED`，释放租约 | 计 1 次；仅明确可重试错误可给新 requestId 重试 |
| 输出安全拒绝 | 写 `REJECTED/OUTPUT_BLOCK`，释放租约 | 计 1 次，不切模型重试 |
| 用户取消 | 客户端忽略响应；服务端尽力取消 | 未调用 provider 则返还，否则计 1 次 |
| 成功 | 写 `SUCCEEDED`，释放租约 | 确认预占 |
#### 10.4 客户端生命周期
### 11. 前端体验最优方案
#### 11.1 气泡位置
#### 11.2 稳定入口
#### 11.3 复用现有 `cy-sheet`
#### 11.4 状态设计
### 12. 频控、成本与可靠性
#### 12.1 初始生产参数
| 参数 | 初始值 |
|---|---:|
| 单用户每日 chat | 20 次 |
| 单会话 chat | 8 次 |
| 单用户每分钟 | 3 次 |
| 单用户并发 | 1 |
| 输入长度 | 300 字 |
| 输出长度 | 160 个中文字符左右 |
| 模型超时 | 8 秒 |
| HTTP 请求总超时 | 15 秒 |
#### 12.2 Redis 原子频控
#### 12.3 全局预算
#### 12.4 可靠性
### 13. 远程开关与配置
1. 小程序默认 false，网络失败时保持关闭。
2. 后端也必须检查 chat 开关，不能只靠前端隐藏。
3. `roamNpcEvent` 与 `roamNpcChat` 可独立关闭。
4. 开关变更必须有操作记录和回读验证。
5. 安全服务、模型 key、provider health 任一未就绪时，后端强制拒绝开启 chat。
#### 13.1 开关真值与运行中变更
| Event | Chat | 允许状态 |
|---:|---:|---|
| false | false | 全部隐藏 |
| true | false | 只显示预审事件话术，无 Chat 入口 |
| true | true | 通过服务端资格判定的用户可使用 Chat |
| false | true | 非法组合；服务端按 Chat=false 处理并告警 |
#### 13.2 服务端灰度与资格
1. 全局开关和依赖健康。
2. 小程序最低版本。
3. 内部成年 allowlist（第一阶段）。
4. 合规规则确认后的年龄/监护资格。
5. `hash(userId + rolloutSalt) % 10000 < basisPoints` 的稳定分桶。
6. denylist、投诉冻结和风控状态优先拒绝。
#### 13.3 安全运维控制
### 14. 埋点、日志与 SLO
#### 14.1 前端事件
#### 14.2 后端指标
#### 14.3 建议 SLO
| 指标 | 目标 |
|---|---|
| 预审事件接口可用率 | ≥99.9% |
| 预审事件接口 p95 | ≤300ms |
| chat 完成可用率 | ≥99.0%（灰度期） |
| chat 完整安全回复 p95 | ≤12s |
| 未审核内容展示 | 0 |
| 敏感信息进入 analytics | 0 |
| 开关关闭后停止新 chat | ≤60s |
| 重复扣额度 | 0 |
### 15. 测试与自证矩阵
#### 15.1 后端单测
#### 15.2 小程序单测
#### 15.3 Contract test
#### 15.4 Automator
#### 15.5 真机
#### 15.6 安全与合规测试
#### 15.7 测试责任与证据格式
| 责任 | Owner | 必交证据 |
|---|---|---|
| 产品边界与事件话术 | 产品负责人 | 审核签字、版本号、Event 验收视频/截图 |
| 合规、未成年人、数据期限 | 合规负责人 | 适用分类、资格规则、数据矩阵签字件 |
| 后端协议/状态机/权限 | Java 后端 | 单测、contract test、迁移预检、接口回测 |
| 小程序状态与视觉 | 小程序前端 | 单测、Automator、iOS/Android 真机证据 |
| 安全策略和对抗集 | 安全负责人 | 固定 fixture、逐项 oracle、模型评测报告 |
| 回归与发布判定 | 测试/发布负责人 | P0 汇总、灰度指标、开关/版本/SHA 回读 |
### 16. 分阶段实施计划
#### Phase 0：合规分类与产品定稿（阻断项）
- [ ] 确认产品名称统一为“AI 游戏向导”，删除“长期陪伴”表述。
- [ ] 由合规负责人判断是否适用拟人化互动服务相关规则。
- [ ] 明确年龄/监护、协议、安全评估、算法备案和投诉要求。
- [ ] 确认聊天数据保存期限、删除、复制和训练用途政策。
- [ ] 确认 V1 不做长期情感记忆。
- [ ] 产出签字件：适用分类、资格规则、数据生命周期矩阵、高风险处置矩阵和测试账号矩阵。
#### Phase 1：后端生产门禁
- [x] 收口共享频控、安全、路由和日志。<!-- PR #80(feat/ai-governance,2026-07-16,未合并):NpcChatService 改调 AiGatewayService.generate(),频控/入参安全/路由/出参安全/ai_generation_log 全部由网关统一负责;频控按组分池 npc(npcDailyLimit=100)/gen;路由 npc_chat→deepseek(minimax 未启用,placeholder 会抛异常)。 -->
- [x] 改为有界线程池。<!-- ✅ 2026-07-21复核:已被绕过式解决——异步线程池整体删除,改同步调用,全仓 git grep newCachedThreadPool 零命中,本条实质已达成(不是靠"设上限"而是靠去掉异步)。 -->
- [x] 请求校验和 requestId 幂等。
- [x] 普通 POST 完整安全响应；移除 NPC 的 provider delta 外泄路径。<!-- ✅ 2026-07-21复核:此条已完成,原"半做/仍是SSE"的旧注释已过期——NpcChatService.chat() 现已改为同步方法,SSE/线程池均已删除,与本文§1.1-5"V1不使用服务端SSE"的要求一致。 -->
- [ ] 动态 provider 路由与健康检查。
- [ ] ROAM/PLAY 显式 context。
- [ ] 统一 POST 结果、幂等/额度/并发状态机。
- [x] 后端 chat 强制 feature gate。
#### Phase 2：控制面、数据与观测
- [x] 两个功能开关默认 false。
- [ ] 前后端埋点白名单和测试。
- [ ] chat 日志治理字段。
- [ ] 数据复制、删除与举报接口。<!-- 2026-07-22:导出+删除已完成待ship——feat/npc-data-export-delete f6fa2599(未push):GET /api/ai/npc/chat/data/export + POST /chat/data/delete,鉴权只信登录态、零用户ID入参,不挂chatOn()(数据权利不随开关关闭),MyBatis IT真库A/B归属正负控+变异负控已跑。举报接口本次未做(交接明确排除)。注意:@Log对app登录态是静默no-op(LogAspect强转LoginUser被吞,sys_oper_log零产出),§8.3审计当前=服务端结构化日志,完整审计台账归"chat日志治理字段"任务。 -->
- [x] 预审话术与唯一全局 NPC 预检。
- [x] 配置和迁移只读预检。
#### Phase 3：小程序深模块与 UI
- [x] Coordinator interface。<!-- ✅ 2026-07-21复核:已合并——utils/roam-npc-coordinator.js + npc-roam-gate.js 已完整实现§4.3 Coordinator接口+§9.4 45/90秒防吵闸,已接入 pages/roam/index.js:206。 -->
- [x] Authenticated GET adapter。<!-- ✅ 2026-07-21复核:已合并——pages/roam/index.js:81-108 buildNpcPorts 已用 NPC_JSON_HEADER 显式带 header。 -->
- [x] 唯一格子里程碑。<!-- ✅ 2026-07-21复核:已合并——count>=80/25 格子里程碑已落地。 -->
- [x] 首次 POI 语义。<!-- ✅ 2026-07-21复核:已合并——firstVisit===true 去重语义已落地。 -->
- [ ] 顶部通知栈与浮层互斥。<!-- components/cy/npc-chat 仅在 pages/roam/index.json 的 usingComponents 声明,index.wxml/index.js 全仓 grep -i npc 零命中,PR #187 未合并交付,该能力小程序侧不可达。 -->
- [ ] chat 稳定入口。<!-- 同上——cy-npc-chat 未接入 roam 页面,FAB 入口不存在,PR #187 未合并交付。 -->
- [ ] 复用 `cy-sheet` 和设计 token。<!-- 组件文件已建(components/cy/npc-chat/*)但未接入 roam 页面,PR #187 未合并交付,是死代码。 -->
- [ ] 普通 POST、迟到响应隔离、本地逐字动画和 abort 生命周期。<!-- 组件内逻辑已写但未接入 roam 页面,客户端不可达,PR #187 未合并交付。 -->
- [x] feature 默认关闭。<!-- ✅ 2026-07-21复核:已合并——NpcFeatureFlags 默认关闭已落地。 -->
#### Phase 4：灰度与上线
1. 后端与迁移先上线，两个开关保持 false。
2. 回读 Flow 部署 SHA、接口版本、配置和数据库结构。
3. 上传微信体验版。
4. 先开 `roamNpcEvent` 给内部体验用户。
5. 事件气泡稳定后，再对小范围用户开 `roamNpcChat`。
6. 观察连续 7 天且至少 500 个合格请求；样本不足不扩大。
7. 安全、错误率、成本和投诉均达标后扩大灰度。
### 17. Git、迁移与发布编排
#### 17.1 推荐 PR 切分
#### 17.2 文档状态流转
### 18. 上线验收清单
#### 18.1 Event NPC Go Gate（可独立先上线）
- [ ] `roamNpcEvent` 前后端开关存在且默认 false；`Event=false/Chat=true` 被服务端判为非法。
- [ ] profile/event GET 带有效 Authorization，越权请求被拒绝。
- [ ] 全局 ACTIVE profile 数据库约束、话术状态和缓存失效可验证。
- [ ] 事件话术全部预审、适龄，不包含生成式模型调用。
- [ ] 首次 POI、唯一格子里程碑、展示后计配额和去重通过确定性测试。
- [ ] 新埋点进入前后端白名单，bizId 类型正确且无原文/精确位置。
- [ ] UI 层级、稳定性、开关关闭和 iOS/Android 真机通过。
- [ ] 迁移、后端 SHA、微信体验版和线上开关均已从对面读回。
#### 18.2 Chat Go Gate（在 Event 之后独立判定）
- [ ] 产品定位与合规适用分类有书面结论。
- [ ] 适用分类、年龄/监护资格、数据生命周期和高风险矩阵已签字。
- [ ] `roamNpcChat` 总闸、服务端资格、内部成年 allowlist 和稳定分桶可验证。
- [ ] NPC chat 真实执行日限、分钟限、会话限和并发限。
- [ ] requestId 各终态不重复扣额度，并发租约崩溃后自动释放。
- [ ] 内容安全未启用或异常时 chat 无法开启。
- [ ] 未审核输出永不展示。
- [ ] 主备 provider 均通过版本化评测硬门槛，fallback 规则已演练。
- [ ] 输入、输出和日志不含不必要个人信息。
- [ ] 用户可退出、导出、删除和举报；主库、备份、provider 侧策略可证明。
- [ ] AI 显式标识持续存在。
- [ ] 未成年人规则未签字时，非内部成年 allowlist 用户均被服务端拒绝。
- [ ] 普通 POST 契约、权限信任边界和迟到响应隔离通过 contract/真机测试。
- [ ] 数据迁移已按标准路径落库并读回。
#### 18.3 共同产品体验验收
- [ ] 开场 profile 慢加载也不会永久丢失。
- [ ] 重复 POI 不说“首次点亮”。
- [ ] 25/80 里程碑按唯一格子触发不同话术。
- [ ] 气泡不遮挡底栏、附近卡、徽章和结算。
- [ ] 事件功能关闭时无残留 UI。
- [ ] chat 关闭时无可点击误导入口。
- [ ] 请求取消、弱网和断网不影响漫游主流程。
#### 18.4 共同上线观测
- [ ] Flow SHA = 合并后的 `github/master` tip。
- [ ] 线上 feature 接口读回正确。
- [ ] 生产库迁移字段和话术读回正确。
- [ ] 体验版真实事件气泡有 impression 记录。
- [ ] 体验版真实 chat 有 requestId、provider、模型、状态、延时和 token 记录。
- [ ] analytics 无原始 message/reply。
- [ ] 安全 BLOCK 测试未泄露原始模型内容。
- [ ] 开关关闭后 60 秒内停止新增 chat。
### 19. 成功指标与复盘
### 20. 最终推荐
### 21. 参考依据
1. [《人工智能拟人化互动服务管理暂行办法》— 中国网信网](https://www.cac.gov.cn/2026-04/10/c_1777558395078289.htm)，2026-07-15 起施行。
2. [《人工智能生成合成内容标识办法》— 中国网信网](https://www.cac.gov.cn/2025-03/14/c_1743654684782215.htm)，2025-09-01 起施行。
3. [《生成式人工智能服务管理暂行办法》— 中国网信网](https://www.cac.gov.cn/2023-07/13/c_1690898327029107.htm)。
4. 城瘾仓库 `github/master`：`ApiAiNpcController`、`NpcChatService`、`AiGatewayServiceImpl`、`AiSceneRouter`、`WxContentSecurityServiceImpl`、`request-client.js`、`analytics.js`、`pages/roam/index.js`。

## Source: 城瘾vault/05-参考资料/归档_20260803/状态终审_原04/B3_AI主题草稿mock失败关闭_独立复核报告_20260727_完整版.md

## B3 双轴复核报告
### 结论: **PASS**
### Standards 轴
| 检查项 | 结果 | 证据 |
|--------|------|------|
| **变更范围** | ✅ | 仅 `theme_draft` 方法, diff 严格限定 2 文件 |
| **异常语义** | ✅ | `AiCreatorServiceImpl.java:230-233` — 使用既有 `AiServiceException`, 消息 "AI 服务暂未就绪,请稍后重试" 与旧版一致 |
| **player quota 预占/归还** | ✅ | `AiCreatorServiceImplTest.java:219-240` (`[id]`) — 验证 mock 闸触发后 `increment`+`decrement` 均被调用; finally 块 `AiCreatorServiceImpl.java:254-257` 正确释放 |
| **非 player quota 无副作用** | ✅ | club/merchant 不进入 `reservePlayerThemeDraftQuota`, `reservation` 保持 null, finally 块为 no-op |
| **其他 bizType 不回归** | ✅ | `merchant_plan`, `node_generate`, `chapter_overview`, `club_design`, `safety_precheck`, `merchant_task_suggest` — 均未改动, mock 模型测试继续通过 (如 `[id]` 使用 model="mock") |
| **throw 排在 JSON 解析之前** | ✅ | `AiCreatorServiceImpl.java:230` 先于 `:234` `parseAiJson`, mock 输出不进入解析逻辑, 避免 NPE 或垃圾解析 |
#### 非阻断提示
### Spec 轴
| 需求 | 结果 | 证据 |
|------|------|------|
| **theme_draft 任意角色 mock fail-closed** | ✅ PASS | `AiCreatorServiceImpl.java:230`: 移除 `"player".equals(role) &&` 条件, `isMockModel(r)` 对所有角色生效 |
| **club mock 被拒** | ✅ PASS | `AiCreatorServiceImplTest.java:192-193` — `[id]` — club + "mock" model → `AiServiceException` |
| **merchant mock 被拒** | ✅ PASS | `AiCreatorServiceImplTest.java:197-198` — `[id]` — merchant + "mock" model → `AiServiceException` |
| **player mock 被拒 + quota 归还** | ✅ PASS | `AiCreatorServiceImplTest.java:221-240` — player + "mock" → `AiServiceException` + verify increment + decrement |
| **负控: club/merchant mock 闸能让旧 player-only 闸变红** | ✅ PASS | `[id]` 和 `[id]` 均在被测方法 `assertMockThemeDraftRejected("club"/"merchant")` 中期望 throw — 若生产代码退回 `"player".equals(role) && isMockModel(r)`, 这两条测试会因不 throw 而 FAIL (旧闸对 club/merchant 的 mock 放行, 新测试期望抛错) |
| **非 mock 模型所有角色正常工作** | ✅ PASS | `themeDraftNormalFlow` (club + qwen) + `[id]` (player + qwen) 均 pass |
#### 非阻断提示
### 执行摘要

## Source: 城瘾vault/05-参考资料/提审前历史进行中归档_20260812/漫游AI_Event轨_实现计划v2_20260716.md

## 漫游 AI · Event 轨（预审事件 NPC）实现计划 v2
### ⚠️ v2.1 修订(2026-07-16 · 对真码核验后)
1. **`greeting` 兜底让「静默降级」不存在。** `NpcEventService.getEventLine` 查不到话术时回落 `profile.getGreeting()`,`line` 非空 → coordinator 的 `if (err || !line) → 静默` 永远走不到。种子没落库 / `event_type` 差一个字 → 用户一晚被复读五次「我是小瘾,你的城市探索向导。」,配额照扣、impression 埋点照发。**Go Gate 的「话术全预审」抓不到它——greeting 也是预审的。** → 决策:后端加「只查缓存」语义(新增 Task 5.1)。
2. **`active_slot` 唯一约束是装饰,读路径不读它。** `selectGlobalNpc` = `scope_type=3 AND enabled=1 AND del_flag='0' AND audit_status=1 LIMIT 1`,无 `active_slot`、无 `ORDER BY`;`selectByProfileAndEvent` = `ORDER BY node_id DESC LIMIT 1`,无 `version`。v2 声称的「audit_status=1 且 enabled=1 且 active_slot=1 ⇔ ACTIVE」在代码里不成立,版本机制全靠「记得手工把旧行置 0」的纪律。**闸放错层。** → 决策:约束 + mapper 一起改(新增 Task 5.2)。
3. **结算台词的 data key 错了,且三处自洽 = 假绿。** 页面真实 key 是 `finish`(`index.js:102`),v2 用的 `fin` 来自 `index.js:1629`/`1967` 的**局部变量** `const fin = this.data.finish || {}`。v2 的 wxml、viewPort、automator 脚本**三处都写 `fin`**,自洽 → 自证必 PASS,建出来的却是跟 `finish` 无关的孤儿 key。且 `.npc-finish` 的 `wx:if` 只看 `fin.npcLine` 不看 `screen`,自证 setData 完就断言节点在 = 什么都没证明。 → 决策:全改 `finish.npcLine`,自证改走真实 arrive 屏。
4. **POI 首亮建立在对 checkin 响应的误读上。** 真码 `index.js:196-205`:`r.poiId` **只在 `participating === true` 时存在,而那个分支立刻 `navigateTo` 跳去商家页并 `return`**;`firstVisit` 只活在 `participating === false` 分支,**那里根本没有 `poiId`**。所以 v2 的 `Number(r.poiId || 0) || ('g:' + d.name)` 在唯一会触发首亮的路径上恒落到字符串 fallback,而单测喂 `poiId: 7` 数字 = **测了一条生产中永不发生的路径**。且 `d.name` 为空时所有 POI 去重键都是 `'g:'` → 第一次点亮后整个会话再不触发。又:`bindpoitap` 是微信地图组件的**原生
### ✅ v2.1 施工完成(2026-07-16)· PR-A1 已 commit 未 ship
| 改动 | 注入什么 | 红的证据 |
|---|---|---|
| cacheOnly 语义 | `if (false)` 短路 | `expected: <> but was: <我是小瘾,你的城市探索向导。>` ← 复读机本尊 |
| `active_slot=1` | 删掉该条件 | `expected: <小瘾> but was: <老周>` ← 约束沦为装饰本尊 |
| `version DESC` | 删掉排序 | 取到 v1 旧文案 |
| chat 闸门恒开 | `if (false)` | flagOff/flagAbsent 2 红 |
| chat 闸门恒关 | `if (true)` | flagOn 正向用例 1 红 |
| 迁移 scope_type | 用修复前的 UPDATE | `ERROR 1062 Duplicate entry '1-42-1'` |
### ✅ PR-B1 施工完成(2026-07-16)· 4 commit 在 `feat/roam-npc-b1`,**未 ship**
| Task | 状态 | 负控证据 |
|---|---|---|
| 8 gate | ✅ | 删 end 豁免→红 / 改请求即计费→红 / poi 配额 2→99→红 |
| 9 coordinator | ✅ | 去重键退回 name→红 / 拆空话术静默→红 / impression 塞原文→红 / 渲染失败也记埋点→红 |
| 10 页面接线 | ✅ | 见下「三处按 v2.1 修订」 |
| 11 automator 自证 | ✅ **已在真开发者工具跑通 6/6** | ②/④a/④b 三条负控实测能红 |
| 12 ship B1 | ✅ **PR #84,CI 6/6 绿,MERGEABLE/CLEAN** | 未合并 |
| — B1 自审 | ✅ `/code-review high` 扫 5 条,修 3 条真问题 | flag latch→冷启动竞态双红 |
#### ★ 自证的真实过程(比结果重要)
## → PASS roam-npc UI 自证 6/6
#### ★★ 负控抓到我自己写的一条恒真断言(必须记下)
| 断言 | 测什么 | 负控 | 实测 |
|---|---|---|---|
| ④a | 非 arrive 屏不渲染 | 删**父节点** `.arrive` 的 wx:if | ✅ 红 |
| ④b ★ | arrive 屏但**无台词**不渲染(`.npc-finish` 自己的条件) | 去掉 `finish.npcLine` 判断 | ✅ 红「会露出空壳」 |
| ④c | arrive 屏+有台词 → 渲染且文案上屏 | — | — |
| ② | 气泡与 nearbyBanner 互斥 | 删 `!nearbyBanner.show` | ✅ 红 |
1. data key 确认是 `finish`(`index.js:102` `finish: {}`);v2 的 `fin` 是 `_finishRoam` 里的**局部变量** `const fin = {...}`(真码亲眼所见)。`showFinishLine` 用路径写法,且**在 `setData({finish: fin})` 之后**派发 —— 顺序反了台词被整体覆盖冲掉。
2. POI 派发收进 `participating === false` 分支;`participating===true` 那支立刻 `navigateTo` 跳走。
3. 去重键 `poiKey` = 坐标 `toFixed(5)`。
### ⚠️ rebase 记录(2026-07-16 晚):#83 被 master 顶成 CONFLICTING,已解并 force-push
#### ★★ #75 直接证伪了我给 Task 5.3 写的立论
#### #75 还改了什么(我必须跟着适配)
| #75 的改动 | 我的适配 |
|---|---|
| SSE → 普通 POST,返回 `AjaxResult` | 闸门从 `response.sendError(403)` 改成 `AjaxResult.error(HttpStatus.FORBIDDEN, ...)` —— 与仓库既有惯用法一致(`GlobalExceptionHandler#handleAccessDeniedException` 就是这么写的),且客户端认的是 body 里的 code |
| `chat(req, userId, openid)` → `chat(req, userId)` | `NpcChatFlagGateTest` 的 mock/verify 从 3 参改 2 参,返回 `NpcChatResp` |
| 移除 `SseEmitter` | 清掉我这边孤儿 import(`IOException`/`HttpServletResponse`),补 `HttpStatus` |
#### 「没丢 master 内容」的验证(memory `feedback-rebase-stash-drops-master-content`)
### B1 截图闸:已给用户看过图
## ✅ 迁移已全部落库(2026-07-16 晚 · 用户授权后执行)
| 迁移 | 回读确认 |
|---|---|
| governance | `active_slot`(tinyint 可空)/`version`(int NOT NULL)/`node_key`(**STORED GENERATED**)+ `uk_active_scope`(scope_type,scope_id,active_slot) + `uk_line_version`(profile_id,event_type,node_key,version) |
| flags | `roamNpcEvent`=`false` / `roamNpcChat`=`false` |
| roam_lines | 见下三条断言 |
## 📍 文档状态判定(勾满 ≠ 能往前挪)
| 闸 | 状态(2026-07-17 16:30 当场重核) |
|---|---|
| ① ③迁移落库 | ✅ 3/3 已落 + 回读 + 幂等(07-16 晚用户授权后执行) |
| ② ②小程序微信上传 | ❌ **仍未上传** —— #84 已 MERGED,但 ECS 部署对小程序 no-op,须另走微信上传 |
| ③ 部署观测坐实(生产 jar 自报 commit == 含本改动的 master SHA) | ✅ **已坐实** —— #83 的 mergeCommit `4bb67d0d` 是生产 jar 自报 `4753a951` 的祖先(当场 ssh 问的 jar,非 curl/workflow 绿) |
## 🔚 交接:只剩一件必须你做的
| PR | 内容 | 状态(2026-07-17 16:30 当场重核) | 部署后果 |
|---|---|---|---|
| **#83** | A1 后端(①③④) | ✅ **MERGED**,mergeCommit `4bb67d0d` | ①已真部署,**生产 jar 自报已坐实** |
| **#84** | B1 小程序(②) | ✅ **MERGED** | ②不触发部署,**仍须微信上传** |
### ~~1️⃣ 确认话术~~ ✅ 已确认(用户 2026-07-16 晚)· ~~2️⃣ 落库~~ ✅ 已落 3/3
### ~~3️⃣ merge~~ ✅ **已合**(#83 → #84,顺序如计划)· 后端部署观测已坐实:
## 2026-07-17 16:30 实测:jar 自报 4753a951,而 #83 的 4bb67d0d 是它的祖先 ⇒ 本轨后端确已在生产
### 剩下一件,必须你做
#### 4️⃣ 微信上传体验版 ← **唯一卡点**
### 然后才是开关
### 开关怎么开(全部就绪之后)
### 文档状态
| 检查项 | 实测 | 影响 |
|---|---|---|
| `npc_profile`(**全表**,不只 scope_type=3) | **0 行** | Task 3 的 UPDATE 影响 0 行;Task 4 直接建小瘾并拿到 ACTIVE 槽 |
| `npc_line_cache`(**全表**) | **0 行** | — |
| 话术重复行 | 0 行 | `uk_line_version` 不会失败 |
| `explore_*` 种子 | **0 行** | **★连锁伤害不存在**(见下);Task 4 收尾断言 ③ 恒返回 0 行,无需迁移 explore_* |
| `feature.flag.roamNpc*` | 0 行 | Task 2 会新建,幂等分支不触发 |
| `active_slot` / `version` / `node_key` 列 | 不存在 | ADD COLUMN 安全;MySQL 8 = INSTANT 算法,秒级不锁表 |
### Global Constraints(每个任务隐含遵守)
### 文件结构总览
## PR-A1:后端控制面与迁移
#### Task 1: 建 A1 worktree
- [x] **Step 1:** 主 worktree 执行 `cyw roam-npc-a1`(内部先 `git fetch github master`,失败即停);进入新 worktree 目录。
- [x] **Step 2:** 确认基线:`git -C <worktree> log --oneline -1` 应等于 `git ls-remote github master | cut -c1-7`。
#### Task 2: 开关迁移 `migration_roam_npc_feature_flags.sql`
- [x] **Step 1: 写迁移文件**(镜像 `migration_m10_feature_flags.sql` 的自然键防重风格):
- [x] **Step 2: 语法自检** `grep -c "WHERE NOT EXISTS" chengyinhub-admin/sql/migration_roam_npc_feature_flags.sql` → 期望 `2`。
- [x] **Step 3: Commit** `git add chengyinhub-admin/sql/migration_roam_npc_feature_flags.sql && git commit -m "feat(roam-npc): 漫游NPC双开关迁移,默认全关"`
#### Task 3: 治理迁移 `migration_npc_governance_v1.sql`
- [x] **Step 0(v2.1 新增):落库前只读预检,肉眼核对三张输出再决定往下走。** v2 只预检了 `npc_profile`,漏了 `npc_line_cache` 的重复行——有重复就加不上 `uk_line_version`,迁移当场红(这是好事,但要事先知道)。
## ① 全局 NPC 现状:几条?audit_status 是 0 还是 1?
## ② 话术重复行(加唯一键的拦路虎)
## ③ explore_* 种子跑没跑过(决定 companionLine 会不会被本迁移伤到)
- [x] **Step 1: 写迁移文件:**
- [x] **Step 2: 写只读预检语句到文件头注释已含;本地核对建表语句来源** `head -25 chengyinhub-admin/sql/migration_npc_profile.sql` 确认列名无出入。
- [x] **Step 3: Commit** `git commit -am "feat(roam-npc): npc表治理v1——ACTIVE唯一约束+话术版本键"`
#### Task 4: 话术种子 `migration_npc_roam_lines.sql`
- [x] **Step 1: 写种子文件**(话术≤40字、适龄、无消费诱导、无「陪伴/懂你」关系话术——§2.2/§9.3):
- [x] **Step 2: 自检** `grep -c "UNION ALL SELECT" chengyinhub-admin/sql/migration_npc_roam_lines.sql` → 期望 `4`(共 5 事件)。
- [x] **Step 3: 落库后跑收尾断言 ③**,若 `profile_id != active_id` → 补一条 `UPDATE npc_line_cache SET profile_id=<active_id> WHERE event_type LIKE 'explore_%'`,**再回读确认**。此步不做 = 用一个没上线的功能打死一个已上线的功能。
- [x] **Step 4: Commit** `git commit -am "feat(roam-npc): 小瘾人设+漫游5事件话术种子(v1待业务确认)"`
#### Task 5: FLAG_KEYS + 非法组合归一(Java)
- [x] **Step 1: 写失败测试**(JUnit5 纯函数风格,同 `RoamCheckinTest`):
- [x] **Step 2: 跑测试确认失败** `bash ci/backend-test.sh 2>&1 | tail -c 2000` → 期望编译错误 `cannot find symbol normalizeNpcFlags`。
- [x] **Step 3: 实现**(ApiConfigController 两处):
- [x] **Step 4: 跑测试确认通过** `bash ci/backend-test.sh 2>&1 | tail -c 2000` → 期望 `BUILD SUCCESS` 且含 NpcFeatureFlagsTest 通过。
- [x] **Step 5: Commit** `git commit -am "feat(roam-npc): features新增双开关+非法组合服务端归一"`
#### Task 5.1(v2.1 新增): NpcEventService 加「只查缓存」语义 —— 拆掉 greeting 复读机
- [x] **Step 1:** 加重载 `getEventLine(profileId, eventType, nodeId, boolean cacheOnly)`,原三参签名委托给 `cacheOnly=false` 保持既有行为不变(**不改既有调用方语义**)。`cacheOnly=true` 时:cache 未命中 → `vo.setLine("")` 直接返回,**不碰 greeting**。
- [x] **Step 2:** `ApiAiNpcController.event` 新增 `@RequestParam(defaultValue = "false") boolean cacheOnly` 并透传。前端 roam 固定传 `cacheOnly=true`。⚠️ 默认 false = 老调用方零影响。
- [x] **Step 3: 负控测试**(memory「假绿测试的4种模式」:改了逻辑必做负控,注入→红→撤销→绿):
- [x] **Step 4:** `bash ci/backend-test.sh 2>&1 | tail -c 2000` → `BUILD SUCCESS`
- [x] **Step 5: Commit** `git commit -am "feat(roam-npc): event 加 cacheOnly 语义,未命中不回落 greeting"`
#### Task 5.2(v2.1 新增): mapper 读路径读 active_slot / version —— 让约束不再是装饰
- [x] **Step 1:** `selectGlobalNpc` 的 WHERE 加 `AND active_slot = 1`(保留既有 `enabled=1 AND del_flag='0' AND audit_status=1`,`LIMIT 1` 保留但此时已由唯一约束保证至多一条)。
- [x] **Step 2:** `selectByProfileAndEvent` 的 `ORDER BY node_id DESC` 改为 **`ORDER BY node_id DESC, version DESC`**。⚠️ 既有 `explore_*` 行经 Task 3 的 `DEFAULT 1` 自动落 v1,**本改动对它们无害**(已核实)。
- [x] **Step 3: 负控**:临时把某条话术插成 version=2 且两版都 `audit_status=1` → 断言取到 v2;把 `ORDER BY version DESC` 删掉 → 断言**变红**。⚠️ 唯一键**不阻止两个 version 同时 audit_status=1**,所以这个 ORDER BY 是真防线,不是装饰。
- [x] **Step 4: Commit** `git commit -am "fix(roam-npc): 读路径读 active_slot/version,约束不再只管写入"`
#### Task 5.3(v2.1 新增): /api/ai/npc/chat 加 flag 闸门 —— 把假的安全感变成真的
- [x] **Step 1:** `chat()` 入口读 `configService.selectConfigByKey("feature.flag.roamNpcChat")`,非 true → **直接 403**(SSE 端点:`emitter.completeWithError` 或先于建流返回),并 warn 日志。
- [x] **Step 2: 负控**:flag=false 时打端点 → 断言 403;临时把闸门注释掉 → 断言**变红**。
- [x] **Step 3: Commit** `git commit -am "fix(roam-npc): chat 端点加 flag 闸门,Chat=false 时 403"`
#### Task 6: 埋点白名单(Java)
- [x] **Step 1:** 在 `ALLOWED_EVENTS` 列表尾部(`roam_discover_reward_click` 同段)追加两行:
- [x] **Step 2:** `bash ci/backend-test.sh 2>&1 | tail -c 1500` → `BUILD SUCCESS`。
- [x] **Step 3: Commit** `git commit -am "feat(roam-npc): 埋点白名单+2(profile_loaded/bubble_impression)"`
#### Task 7: /ship A1
- [x] **Step 1:** 走 `/ship`(自审→commit→push github→`gh pr create --base master`)。PR 描述影响分类(**v2.1 已扩大**):**①后端运行时**(ApiConfigController / ApiAnalyticsController / **NpcEventService / ApiAiNpcController / 两个 mapper XML** ← 改的是 `explore_lines` 与 `companionLine` 也在用的**共享读路径**,不再是低风险 PR)+ **③数据库迁移 ×3**(合并前须按 chengyin-db-migrate 依序落库:governance → flags → roam_lines,roam_lines 落库前业务确认 15 条文案)+ **④CI 测试**
- [x] **Step 2:** 等 CI 绿。**合并、落库属发布动作,由 /merge 流程执行,不在本计划内。**
- [x] **Step 3(v2.1 新增):PR 描述里显式写明回滚路径。** 本 PR 改了已上线功能的读路径,回滚不是「revert jar」那么简单:`active_slot` 列可留(nullable 无害),但 `uk_active_scope` 唯一键在回滚后若有多条 ACTIVE 会挡住写入 → 回滚 SQL 一并备好。
## PR-B1:小程序 Event NPC
#### Task 8: 纯逻辑闸 `npc-roam-gate.js`(TDD)
- [x] **Step 1: 写失败测试:**
- [x] **Step 2: 跑测试确认失败** `cd chengyinhub-xcx && npm run test:unit 2>&1 | tail -c 1500` → `Cannot find module '../../utils/npc-roam-gate.js'`。
- [x] **Step 3: 实现:**
- [x] **Step 4: 跑测试确认通过** `npm run test:unit 2>&1 | tail -c 1500` → 全绿。
- [x] **Step 5: Commit** `git commit -am "feat(roam-npc): 防吵闸gate——展示后计费/重试1次/45s节流"`
#### Task 9: 深模块 `roam-npc-coordinator.js`(TDD)
- [x] **Step 1: 写失败测试:**
- [x] **Step 2: 确认失败** `npm run test:unit 2>&1 | tail -c 1200` → `Cannot find module '../../utils/roam-npc-coordinator.js'`。
- [x] **Step 3: 实现:**
- [x] **Step 4: 确认通过** `npm run test:unit 2>&1 | tail -c 1500` → 全绿。
- [x] **Step 5: Commit** `git commit -am "feat(roam-npc): coordinator深模块——排队/去重/里程碑/展示后计费"`
#### Task 10: 页面接线 + 适配器 + 白名单 + UI
- [x] **Step 1: analytics.js 白名单**(锚点:`roam_discover_reward_click: true` 行后追加):
- [x] **Step 2: app.js features 默认值**(锚点 `features: { selfPlay: false, ...` 行)改为:
- [x] **Step 3: roam/index.js 建适配器与实例**。在 `Page({` 之前(`req()` 函数定义后)加:
- [x] **Step 4: 派发点接线**(⚠️ v2.1 行号已按真码重核,但**施工时仍用锚点字符串 grep**——流4 两个 PR 待 ship 会改本页):
1. `onLoad` 内 `this._sessionTiles = {};`(**123** ✅)后:`this.data.npcBubble = { show: false }; this._npc = createRoamNpcCoordinator(buildNpcPorts(this)); this._npc.start();`
2. 进图开场——`screen: 'map'`(**615**,v2 写 594 ❌)的 setData 回调/紧后:`this._npc.dispatch({ type: 'SESSION_STARTED' });`
3. 唯一格子——`this._sessionTiles[key] = 1;`(**411** ✅)后:`this._npc.dispatch({ type: 'UNIQUE_TILE_COUNT_CHANGED', count: Object.keys(this._sessionTiles).length });`
4. **POI 首亮(v2.1 整块重写)**——收进 `onPoiTap` 的 `if (r.participating === false) {` 分支内(**200-205**),`wx.showToast` 之后:
5. 会话 id——`if (res.data.sessionId) this._roamSid = res.data.sessionId;`(**450** ✅)后:`this._npc.setSessionId(this._roamSid);`
6. 结算——`this.setData({ screen: 'arrive', finish: fin })`(**1629**,v2 写 1526 ❌ 差 103)**之前**:`this._npc.dispatch({ type: 'SESSION_FINISHED' });`(台词落 arrive 屏 = 已拍板;dispatch 先发,异步回来时 `finish` 已落地,`showFinishLine` 用路径写法补字段)
7. `onUnload()`(**154**,v2 写 148)加:`if (this._npc) this._npc.dispose();`
- [x] **Step 5: wxml 气泡进 prompt-slot 互斥链**(锚点:paceCard 块 **92** 行段之后)。⚠️ v2.1 核实:`prompt-slot` 既有三个用例(**62** nearbyBanner / **92** paceCard / **105** visit),`medal` **不在这个栈里**(**201** 行是 `medal-mask` 全屏遮罩)——四个条件仍都要 `!`,npcBubble 排最低优先级:
- [x] **Step 6: wxss**(沿用 pace-card 视觉家族,不新造色值——引用页内已有变量/色):
- [x] **Step 7: 单测回归** `npm run test:unit 2>&1 | tail -c 1200` → 全绿(page 接线不进单测,由 Task 11 自证)。
- [x] **Step 8: Commit** `git commit -am "feat(roam-npc): roam页接线+气泡入prompt-slot栈+结算台词+白名单"`
#### Task 11: automator 确定性自证
- [x] **Step 1: 写脚本:**
- [x] **Step 2: 跑自证** `node scripts/verify-roam-npc.js 2>&1 | tail -c 800` → `PASS roam-npc UI 自证 5/5(含 ④a 负控)`(需微信开发者工具,automator.launch 会自行拉起)。
- [x] **Step 3: ★负控(不做 = 这个自证不算数)**:逐条注入该红的场景,确认它真红,再撤销:
- [x] **Step 4: Commit** `git commit -am "test(roam-npc): automator确定性自证——渲染/互斥/无残留/结算(含负控)"`
#### Task 12: /ship B1
- [x] **Step 1:** `cyw roam-npc-b1` 或在 A1 合并后从最新 master 建分支;把 Task 8-11 产物落进该 worktree;走 `/ship`。PR 描述影响分类:**②小程序发布**(ECS 空跑,须微信上传体验版)。前置说明:**依赖 PR-A1 已合并且 3 个迁移已落库**;开关未开时本 PR 上线后用户无任何感知。 → **PR #84**(2026-07-16)
- [x] **Step 2:** 等 CI 绿。合并、微信上传、开关灰度按补充方案 Phase 4 执行(不在本计划内)。 → CI **6/6 全绿**,mergeState=CLEAN,未合并
### 发布与验收映射(执行完对照,不属任务)
| 补充方案 Event Go Gate(§18.1) | 由谁满足 |
|---|---|
| 双开关存在且默认 false;非法组合服务端归一 | Task 2 + Task 5 |
| ~~Chat 轨已阻断~~ → **Chat 端点真被 flag 挡住(v2.1 如实改写)** | **Task 5.3**。⚠️ v2 把这条记成「已满足」是错的:`normalizeNpcFlags` 只归一下发给前端的 JSON,端点从来没被 flag 保护过,且 `NpcChatService` 绕过 `AiGatewayService`(无频控/无成本账本) |
| profile/event GET 带 Authorization | Task 10 Step 3(显式 header) |
| **话术未命中时真静默(不回落 greeting)** | **Task 5.1**(v2 缺这条 → 复读机) |
| 全局 ACTIVE 唯一约束 + 话术版本 | Task 3(写入侧)**+ Task 5.2(读取侧)** ← 只做 Task 3 = 装饰 |
| **已上线的 explore_* / companionLine 未被伤到** | **Task 4 收尾断言 ③**(v2 完全没意识到这条爆炸半径) |
| 话术全预审、适龄、零模型调用 | Task 4(落库前 Arlan 逐条确认)。⚠️ 这条**抓不到 greeting 复读机**——greeting 也是预审的,靠 Task 5.1 |
| 首次 POI / 唯一格子 / 展示后计配额 / 去重 | Task 8 + 9(单测锁定,**去重键=坐标**;v2 的 poiId 生产中不存在) |
| 埋点双端白名单、bizId Long、无原文 | Task 6 + Task 10 Step 1 |
| UI 层级 / 互斥 / 关闭无残留 / 结算台词 | Task 10 Step 5 + Task 11(**含 ④a 负控**;v2 的自证是恒真断言) |
| 迁移/SHA/体验版/开关回读 | /merge + 部署 runbook(chengyin-deploy) |
1. **Task 3 Step 0 只读预检** → 肉眼核对三张输出,确定落到哪个分支(需 `CHENGYIN_DB_PASSWORD`)
2. 迁移落库:**governance → flags → roam_lines**
3. **★回读闸一:Task 4 收尾断言 ①②③ 全绿** —— 尤其 ③(`explore_*` 的 `profile_id` == ACTIVE 那条)。**不绿就停,别合 jar**:mapper 一改,companionLine 就静默退化。
4. A1 合并 → **★回读闸二:问生产 jar 自报的 commit**(`unzip -p .../chengyinhub-admin.jar BOOT-INF/classes/git.properties` 的 `git.commit.id` == `git rev-parse github/master`),不是 curl 200
5. B1 合并 → 微信上传体验版
6. 内部开 `roamNpcEvent` 观测。真机项(iOS/Android 弱网/[redacted] §15.5。
