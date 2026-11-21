# R1 · 主题 and gameplay configuration pages — coverage + build specs

Reviewer: Fable 5.2 · task `task_1a93aeb29cfd` · 2026-11-15 · read-only (no Figma or code was edited).
Scope after the owner's change: **coverage only, plus a build spec for every MISSING or PARTIAL screen and state.** References and the optimization review are deferred until all pages are drawn.

## 1 · Result in one screen

**289 screens, sheets and states were identified. 16 are drawn in Figma. 273 are missing.**

| Part | Items | PRESENT | MISSING |
|---|---|---|---|
| A · temp 节点玩法模板编辑 | 89 | 1 | 88 |
| B · fabu 主题编辑器 | 109 | 3 | 106 |
| C · activity 发布活动 1–3 | 23 | 3 | 20 |
| D · simple AI 快速创建 | 11 | 1 | 10 |
| E · templates (intro, market, detail, mine) | 36 | 6 | 30 |
| F · external games | 15 | 2 | 13 |
| G · types with no editor source | 6 | 0 | 6 |
| **Total** | **289** | **16** | **273** |

By route: **1 PRESENT, 11 PARTIAL, 2 MISSING.**

| Route | Status | Drawn / total | Part |
|---|---|---|---|
| `/pages/publish/fabu/index` 主题编辑器 | PARTIAL | 3 / 109 | B |
| `/pages/publish/temp/index` 节点玩法模板编辑 | PARTIAL | 1 / 89 | A |
| `/pages/publish/activity/index` 发布活动 | PARTIAL | 3 / 23 | C |
| `/pages/publish/simple/index` AI 快速创建 | PARTIAL | 1 / 11 | D |
| `/pages/publish/template-intro/index` 创建节点玩法引导 | PARTIAL | 1 / 4 | E1 |
| `/pages/publish/topicadd/topicadd` (legacy redirect; shows the empty editor) | PRESENT | `94:5473` | B1.4 |
| `/pages/template/index` 模板广场 | PARTIAL | 1 / 9 | E2 |
| `/pages/templatedetail/templatedetail` 节点模板详情 | PARTIAL | 1 / 9 | E3 |
| `/pages/templatedetail/topic-preview/index` 主题模板预览 | PARTIAL | 1 / 3 | E4 |
| `/pages/templatedetail/topic-detail/index` 主题模板详情 | PARTIAL | 1 / 4 | E4 |
| `/subpackageMember/mytemplate/mytemplate` 我的节点玩法 | PARTIAL | 1 / 7 | E5 |
| `/subpackageMember/external-games/index` 外部游戏 | MISSING | 0 / 2 | F1 |
| `/subpackageMember/external-game-detail/index` | MISSING | 0 / 2 | F1 |
| App: external game import | PARTIAL | 2 / 11 | F2 |

By gameplay type: the mini-program catalogue has **35 gameplay keys** (the original 19 plus 16 added since); 4 more are wanted but unbuilt (判断, 碎片拼图, 刮刮卡, 音频片段). **0 of the 39 have a config frame.** Part G maps each one to its spec.

The three findings that matter most:
1. **The gameplay template editor is not drawn at all.** The only capture of it (INDEX row 52) is a load-error screen, so R5 holds one error frame for a page with 34 config cards and 12 sheets (Part A).
2. **The topic editor is drawn only at its top level.** The story-flow editor, node sheet, chapter settings, topic detail sheet, ticketing page, publish preview and about 20 nested editors (values, zero-HP recovery, survival, d20, look, bingo, backpack, drops, initial state, arrival rules, next-stop conditions and effects) are missing (Part B). The owner's TE screens cover the main ones as visual reference; the nested editors have no owner frame and must be built from code.
3. **TE screens and current code disagree on the story-flow editor** (question Q1). It needs the owner's answer before B4 is drawn.

## 2 · What was read, and what was not

Read in full (every line of markup, through a structure-and-copy extraction that keeps conditions, labels, placeholders and handlers):
- All WXML under `chengyinhub-xcx/pages/publish/` (6 pages, 7 included templates, 13 of the 22 components; the 9 not read are generic wrappers of 3–14 lines: chips, list-group, list-row, segmented, sheet-nav, stepper, swipe-row, cover-fallback, look-transition), `pages/template`, `pages/templatedetail` (4 pages), `subpackageMember/mytemplate`, `external-games`, `external-game-detail`, and the two publish sheets in `components/cy`, on `origin/integration/backend-app-r3`.
- `advanced-game-config.js`: `defaultConfig()` (every default) and `validateNormalized()` (every range and message).
- `node-game-catalog.js`, `gameplay-support-matrix.js`, `r5-editor.js` (view model), `template-tools.js` constants.

Read for constants, option lists, `data` and every user-visible string (not line by line for logic): `temp/index.js` (4,074 lines), `fabu/index.js` (10,194), all `fabu/theme-*.js`, `activity/index.js`, `simple/index.js`, and about 30 modules in `utils/publish/`.

WXSS: only the class map of `temp/index.wxss` was read. Sizes and colours in the specs come from the owner's own legend frame `5375:13150` (code tokens ÷ 2) and `mp-tokens.json`, not from a pass over the 9,500 lines of WXSS.

Figma: for our file, only the manifests (`mp-restore/*.json`, `optimize/*.json`, `prototype/sources.json`, `final-pass/n1-new-features.json`) and the page list. **No frame in our file was re-rendered**, so PRESENT relies on the manifests. For the owner's file: the TE Screens page (names and ids of all its top-level frames, text of the frames that expose it, screenshots of P8, P9 and P11) and the whole temp page `5375:13149`. Most TE frames are component instances, so their inner copy was not readable from metadata; open each frame with `get_screenshot` when drawing.

Captures read: INDEX rows 4, 48–55, 144 (PNG). Rows 56, 57, 145, 146, 172 were taken from the manifests only.

Native app (DES-ag4, read only): `ExternalGameImportView`, `ExternalGameReviewScreens`, `Core/ExternalGameImport`, `Core/TemplateSensorDraft`, and their strings. The app's other 150 editor views were listed but not read; they are not needed for restoring the mini-program screens.

N1 (`204:7911`) has no page in this scope. P (`204:9667`) only holds copies of the frames above (section H `204:9675`).

## 3 · Rules for the designer who draws from this file

1. **Restore first, 1:1.** Every spec below describes what the mini-program shows today: same sections, order, copy and data. Follow the MP restoration brief (`mp-restore-brief.md`): MP tokens, 393 × 852 plus a full-height version, overlays drawn on top of their page inside one frame, labels above frames, 120 px gaps.
2. **Look**: topic publishing follows the owner's TE screens; the gameplay editor follows the owner's legend `5375:13150` (Part A0). Both are the light "topic editor" mode: page `#F3F4F4`, white cards, black primary pill, accent `#2F6DF0` only for small inline actions.
3. **Copy in backticks is verbatim** from the code. Do not rewrite it. Values in parentheses after a field are its placeholder, then its default, then its limit.
4. **Data**: use the seeded entities already in the file (`外滩钟声 · 老城寻踪三章`, chapters `第一章 · 钟楼与邮局` / `第二章 · 骑楼长街` / `第三章 · 码头旧仓`, template `模板库 · 老城钟楼暗号挑战`, club `海派城市漫游团`, topic template `黄浦老城慢游 · 三站轻探线`). Where a spec says "sample", no capture exists and the value is a suggestion.
5. Unknown values show `—`, never `0`. One primary action per screen.
6. A status of PRESENT means a restored frame exists; it does not mean it was re-checked against this spec.
7. Where a spec says "Q1"–"Q8", stop and ask before drawing that item.

## 4 · Open questions for the owner

| # | Question | Why it blocks |
|---|---|---|
| Q1 | Story-flow editor: draw the **TE P7 / P8 model** (insert seams, bottom `下一步`) or the **code's "编辑器原型 v2"** approved 2026-11-10 (top add bar, drag to reorder)? | 23 items in B4. The specs follow the code. |
| Q2 | Sheet headers and text editing: TE shows a grey ✕ + black `完成` pill and separate text pop-ups (S32–S34); the code uses `退出` / `完成` text buttons (ruling 2026-10-10) and edits inline. Which one? | Every sheet in Part B. |
| Q3 | 判断, 碎片拼图, 刮刮卡, 揭晓式猜图: add 判断 as a preset of 选项问答 now? Show the other three as disabled tags, or leave them out until the backend has them? | G1–G3, G5. |
| Q4 | Several media fields are pasted URLs today (猜图 images, 找东西 scene image, scan reply voice / image / AR image). In the app, should they be upload slots? The stored fields stay the same. | A4.6, A4.18, A11.3. |
| Q5 | Creator monetization for external games offers cash options; the ruling is one currency, 积分. Drop the cash options from the drawing? | F2.11. |
| Q6 | Three tool sheets show raw codes (`FAILED` / `EXPIRED`, `ELAPSED_TIME` / `SCORE` / `COMPLETED_UNITS`, `ACTIVITY` / `TOPIC`). Confirm the Chinese labels proposed in A10.7 and A10.9. | A10.7, A10.9. |
| Q7 | WeChat-only items: `微信运动` wording (计步, 归零恢复) and `订阅消息模板 ID`. Replace with Apple Health wording and remove the template ID in the app? | A4.26, A10.8, B7.5. |
| Q8 | Reordering: the mini-program can reorder story blocks, 自由探索 node rows and effect rows only. **Chapters cannot be reordered, and no list editor in the gameplay page can.** Is chapter and list reordering wanted in the app? It would be new behaviour, not restoration. | B2, all LIST editors in Part A. |

## 5 · Coverage matrix

Every config screen, sheet and state, with its status and frame id. Specs are in the part named by the ID prefix.

**A · temp 节点玩法模板编辑**

| ID | Screen / sheet / state | Status | Frame id or reference |
|---|---|---|---|
| A1.1 | Sign-in required | MISSING | — |
| A1.2 | Loading | MISSING | — |
| A1.3 | Load failed · access | PRESENT | 94:4659 · twin 171:6655 · proto 204:16668 |
| A1.4 | Load failed · generic | MISSING | — |
| A1.5 | Load failed · adoption pending | MISSING | — |
| A1.6 | Editing · nothing chosen | MISSING | — |
| A1.7 | Editing · filled | MISSING | — |
| A1.8 | Support matrix loading / failed | MISSING | — |
| A1.9 | Validation errors | MISSING | — |
| A1.10 | Save failed | MISSING | — |
| A1.11 | Saved result sheet | MISSING | — |
| A1.12 | Leave alert | MISSING | — |
| A1.13 | Read-only personal template | MISSING | — |
| A2.1 | Hero card (cover + title) | MISSING | owner ref 5375:13149 |
| A2.2 | 模板信息 card | MISSING | owner ref 5375:13149 |
| A2.3 | 玩法规则 steps | MISSING | owner ref 5375:13149 |
| A2.4 | 参与方式 (+ 扫完回复) | MISSING | owner ref 5375:13149 |
| A2.5 | 玩法 card (empty / chosen + 呈现方式) | MISSING | owner ref 5375:13149 |
| A2.6 | Resources, relax switch, try button, outcomes list | MISSING | owner ref 5375:13149 |
| A2.7 | Bottom bar × 3 entry modes | MISSING | owner ref 5375:13149 |
| A3 | 选择玩法 sheet × 4 categories | MISSING | TE J6 5222:19302 |
| A3.d | 选择玩法 · disabled row with reason | MISSING | — |
| A4.1 | Config card · 文字问答 qaText | MISSING | — |
| A4.2 | Config card · 逐字猜词 hangman | MISSING | — |
| A4.3 | Config card · 选项问答 qaPick (+多选) | MISSING | — |
| A4.4 | Config card · 人物指认 accusation | MISSING | — |
| A4.5 | Config card · 拍照打卡 qaShot | MISSING | — |
| A4.6 | Config card · 猜图 pricePair | MISSING | — |
| A4.7 | Config card · 闭眼盲品 blindTaste | MISSING | — |
| A4.8 | Config card · 预测 predict | MISSING | — |
| A4.9 | Config card · 拍照审核 photoCheck | MISSING | owner ref 5377:13150 |
| A4.10 | Config card · 拍物成卡 objectCard | MISSING | — |
| A4.11 | Config card · 排序 sort | MISSING | — |
| A4.12 | Config card · 连线 match | MISSING | — |
| A4.13 | Config card · 分类 classify | MISSING | — |
| A4.14 | Config card · 抛硬币 coinFlip | MISSING | — |
| A4.15 | Config card · 掷骰子 diceRoll d6 | MISSING | — |
| A4.16 | Config card · 翻卡 random (random task pool) | MISSING | — |
| A4.17 | Config card · 猜数字 estimate | MISSING | — |
| A4.18 | Config card · 找东西 hiddenObject (pin flow) | MISSING | — |
| A4.19 | Config card · 角色建档 profile | MISSING | — |
| A4.20 | Config card · 留言 note | MISSING | — |
| A4.21 | Config card · 今日城市签 dailySign | MISSING | — |
| A4.22 | Config card · 相册 album | MISSING | owner ref 5399:13149 |
| A4.23 | Config card · 九宫格 bingo (pointer line) | MISSING | — |
| A4.24 | Config card · D20 check | MISSING | owner ref 5390:13149–13232; TE J5 5222:19109 |
| A4.25 | Config card · D20 加值 diceRoll d20 | MISSING | — |
| A4.26 | Config card · 计步挑战 steps | MISSING | — |
| A4.27 | Config card · 变色就点 reaction | MISSING | — |
| A4.28 | Config card · 弹球 ballShake | MISSING | — |
| A4.29 | Config card · 安静挑战 quietHold | MISSING | — |
| A4.30 | Config card · 罗盘指向 compass | MISSING | — |
| A4.31 | Config card · 喊一嗓子 shout | MISSING | — |
| A4.32 | Config card · 倒计时 countdown | MISSING | owner ref 5376:13171 |
| A4.33 | Config card · 精准停表 stopwatch | MISSING | — |
| A4.34 | Config card · 输入挑战 typeIn | MISSING | — |
| A4.35 | Config card · 扫码参与 scan (via A11.3) | MISSING | owner ref 5385:13149 |
| A4.36 | Config card · Legacy cards (text / option / photo / preference JSON) | MISSING | — |
| A5 | 结果反馈 section | MISSING | — |
| A5.3 | Effect row (new + legacy style) | MISSING | — |
| A6.1 | 提示 hint ladder (off / 3 levels / error) | MISSING | — |
| A6.2 | Legacy hints card | MISSING | — |
| A7 | 反馈分段（本站内） | MISSING | — |
| A8 | 完成奖励 (coupon / text / medal) | MISSING | — |
| A9 | 剧情故事 beats (legacy) | MISSING | — |
| A10 | 互动工具 section + picker sheet | MISSING | — |
| A10.1 | Tool sheet · 费用 | MISSING | — |
| A10.2 | Tool sheet · 奖励 (drops) | MISSING | — |
| A10.3 | Tool sheet · 线索 | MISSING | — |
| A10.4 | Tool sheet · 成功使用次数 | MISSING | — |
| A10.5 | Tool sheet · 物资交换 (legacy) | MISSING | — |
| A10.6 | Tool sheet · 投票与投入 | MISSING | — |
| A10.7 | Tool sheet · 限时挑战 | MISSING | — |
| A10.8 | Tool sheet · 时段限定 | MISSING | — |
| A10.9 | Tool sheet · 排行榜 | MISSING | — |
| A10.10 | Tool sheet · 语音讲解 | MISSING | — |
| A10.11 | Tool sheet · 背景音乐 | MISSING | — |
| A11.1 | 添加模块 sheet | MISSING | — |
| A11.3 | 扫完回复 sheet (4 kinds + AR) | MISSING | owner ref 5385:13149 |
| A11.4 | 消耗与效果 / 结果之后 sheet + 添加效果 layer | MISSING | — |
| A11.5 | 添加加值 / 添加代价 sheet | MISSING | — |
| A11.6 | Generic picker (适用场所) | MISSING | — |
| A11.7 | 玩法类别 category sheet | MISSING | — |
| A11.9 | 确认移除模块 alert × 3 | MISSING | — |
| A12.1 | Preview · 5 steps | MISSING | — |
| A12.2 | Preview · gameplay screen + verdict | MISSING | — |
| A12.3 | Result · 模板草稿已保存 | MISSING | — |
| A12.4 | Result · 节点玩法已发布 | MISSING | — |
| A12.5 | Result · 节点玩法已保存 (from topic) | MISSING | — |

**B · fabu 主题编辑器**

| ID | Screen / sheet / state | Status | Frame id or reference |
|---|---|---|---|
| B1.1 | Sign-in required | MISSING | — |
| B1.2 | Loading | MISSING | TE S14 4897:16169 |
| B1.3 | Load failed | MISSING | TE S15 4897:16211 |
| B1.4 | New topic · empty | PRESENT | 94:5473 (twin 171:6575) · 91:1038 (twin 171:6496) |
| B1.5 | Editing with content | PRESENT | 91:658 / 91:789 (twins 171:5929 / 171:6054) · 91:907 (twin 171:6166) |
| B1.6 | Local draft restored toast | MISSING | — |
| B1.7 | Draft conflict alert | MISSING | — |
| B1.8 | Leave-unsaved alert | MISSING | — |
| B1.9 | Locked fields alert | MISSING | — |
| B1.10 | Save / publish failed block | MISSING | TE S16 4897:16253 |
| B1.11 | Undo bar | MISSING | TE S18 4897:16360 |
| B2.1 | 创作 page · 自由探索 chapter with node rows | MISSING | TE S21 4897:16468 |
| B2.2 | 创作 page · Node row drag in progress | MISSING | — |
| B2.3 | 创作 page · 待编排区 | MISSING | TE S17 4897:16295 |
| B2.4 | 创作 page · Map view | MISSING | TE S19 4897:16425 |
| B2.5 | 创作 page · Chapter with red status chips | MISSING | TE S3 4896:15616 |
| B2.6 | 创作 page · Club empty state | MISSING | TE 4899:17620 |
| B2.7 | 创作 page · Merchant · fixed mode card | MISSING | TE M2 4890:14382 |
| B2.8 | 创作 page · 地点待办 row | MISSING | — |
| B3 | 主题模式 picker | MISSING | TE P3 4871:14688 |
| B3.a | 复制为新草稿 alert | MISSING | — |
| B4.a | 故事流 editor · empty chapter | MISSING | TE S37 4933:18225 |
| B4.b | 故事流 editor · filled | MISSING | TE P7 4850:13495 · P8 4850:13592 |
| B4.4.1 | Story block · 段落 | MISSING | TE S4 4896:15718 |
| B4.4.2 | Story block · 图片组 | MISSING | TE S5 4896:15745 |
| B4.4.3 | Story block · 音频 | MISSING | — |
| B4.4.4 | Story block · 分支任务 | MISSING | — |
| B4.4.5 | Story block · 相册 | MISSING | — |
| B4.4.6 | Story block · 伏笔 | MISSING | — |
| B4.4.7 | Story block · 内心声音 | MISSING | — |
| B4.4.8 | Story block · 反转 | MISSING | — |
| B4.4.9 | Story block · 文字效果 | MISSING | — |
| B4.4.10 | Story block · 氛围 | MISSING | — |
| B4.4.11 | Story block · 分割线 | MISSING | — |
| B4.4.12 | Story block · 节点 | MISSING | TE S6 4896:15772 · S24 4897:16624 |
| B4.6 | Drag reorder + split-drop | MISSING | — |
| B4.6u | Undo pill | MISSING | — |
| B4.1m | ⋯ menu (章节设置 / 退出编辑) | MISSING | — |
| B4.4g | Grip menu (上移 / 下移 / 删除) | MISSING | — |
| B4.7.1 | 图片 layout sheet | MISSING | — |
| B4.7.2 | 分支任务 sheet | MISSING | — |
| B4.7.3 | 插入变量 sheet (+ empty) | MISSING | — |
| B4.7.4 | 玩家端弹窗预览 × 6 stages | MISSING | — |
| B4.7.5 | 文字说明 sub-page | MISSING | — |
| B5.1 | 节点 sheet · detail | MISSING | TE P9 4871:14211 · S7 · S25 |
| B5.1s | 节点 sheet · shared template + resource mapping | MISSING | TE S8 4896:15908 |
| B5.2 | 节点 sheet · 玩法模板 view | MISSING | TE P10 4868:14344 · S9 · S35 |
| B5.1m | Map point picker | MISSING | — |
| B5.3 | 到达与引导 (arrival rules) | MISSING | TE J4 5221:19075 |
| B5.4 | 下一站 (conditions + effects) | MISSING | TE S36 4932:18205 |
| B5.4a | 下一站 · 添加条件 / 添加效果 layer | MISSING | — |
| B6.1 | 章节设置 · 城市定向 (full) | MISSING | TE P6 4868:14231 · J3 5221:19016 |
| B6.2 | 章节设置 · 自由探索 + 商家承接 | MISSING | TE M6 4890:14443 |
| B6.3 | 章节设置 · Ending chapter | MISSING | — |
| B6.4 | 章节设置 · Prologue with video / audio | MISSING | TE S23 4937:18230 |
| B7 | 主题详情 sheet | MISSING | TE P4 4864:14623 · P5 4871:14323 · S11 4896:16058 |
| B7.1 | 选择主题类别 | PRESENT | 116:2263 · twin 188:5698 · proto 204:16450 |
| B7.2 | 画面风格 | MISSING | — |
| B7.2p | 风格 preview + 看转场 | MISSING | — |
| B7.3 | 伏笔 | MISSING | — |
| B7.4 | 自定义数值 editor | MISSING | — |
| B7.5 | 生命值归零后 × 5 policies | MISSING | — |
| B7.6 | 进行方式 | MISSING | — |
| B7.6e | 运行结局 | MISSING | — |
| B7.7 | Survival list (休整 / 配给 / 设施) | MISSING | — |
| B7.7a | 休整 / 救助 item | MISSING | — |
| B7.7b | 幕配给 item | MISSING | — |
| B7.7c | 设施 item + 使用条件 | MISSING | — |
| B7.7d | 结果卡 | MISSING | — |
| B7.8 | d20 与角色设定 | MISSING | — |
| B7.8m | d20 · 更多规则 (进度钟 / 特质) | MISSING | — |
| B7.9a | 开局前准备 | MISSING | — |
| B7.9b | 主题通关奖励 | MISSING | TE S40 4978:18888 |
| B7.9c | 宾果九宫格 grid | MISSING | — |
| B7.9d | 宾果 · 编辑格子 | MISSING | — |
| B7.10 | 背包 | MISSING | — |
| B7.11 | 途中彩蛋 (drops) | MISSING | TE S41 4978:18976 |
| B7.12 | 初始状态 | MISSING | — |
| B7.12c | 开局带着 · carry picker | MISSING | — |
| B7.13 | 线索与物品 | MISSING | — |
| B7.17 | 可玩时段 sheet | MISSING | — |
| B8.1 | 票务设置 page | MISSING | TE P11 4871:14509 |
| B8.2 | 票务设置 · 支持组队 on | MISSING | TE S12 4896:16142 |
| B8.3 | Ticket editor · 城市定向 | MISSING | TE P12 4871:14604 |
| B8.4 | Ticket editor · 自由探索 | MISSING | TE S13 4896:16237 · 4962:19404 |
| B8.5 | 发布者实名 block | MISSING | — |
| B8.6 | Date / time picker sheets | MISSING | TE S29 4898:17057 · S30 4898:17120 |
| B9.1 | 剧情预览 · clean | MISSING | TE S38 4960:19158 |
| B9.1b | 剧情预览 · blocking issues | MISSING | TE S26 4898:16900 · J7 5221:19151 |
| B9.1c | 剧情预览 · advisory only | MISSING | TE S27 4898:16955 |
| B9.1d | 阅读剧情 pop-up | MISSING | — |
| B9.2 | 安全预检中 sheet | MISSING | — |
| B9.3.1 | Result · 草稿已保存到云端 | MISSING | — |
| B9.3.2 | Result · 已提交审核 | MISSING | — |
| B9.3.3 | Result · 城市路线已发布 | MISSING | TE S28 4898:17006 |
| B9.3.4 | Result · 已发布 · 后续修改仍在本机 | MISSING | — |
| B9.3.5 | Result · 审核未通过 | MISSING | — |
| B9.3.6 | Result · 这次还没有发布出去 | MISSING | — |
| B9.3.7 | Result · 发布结果待确认 | MISSING | — |
| B9.3.8 | 发布前提示 alert | MISSING | — |
| B10.1 | 发布入口 sheet | MISSING | 新稿 txQoyVyK… 146:396 / 146:436 / 146:477 |
| B10.2 | 俱乐部发布 sheet | MISSING | — |
| B10.3 | 奖励选择 + 新建优惠券 | MISSING | TE S40 |
| B10.4 | 地点待办 sheet | MISSING | — |
| B10.5 | AI 助写 strip × 4 states | MISSING | TE S20 4897:16425 |
| B10.6 | 选择合作者 sheet | MISSING | — |
| B10.7 | 章节闸 preview | MISSING | — |
| B10.8 | Date range picker | MISSING | TE 4983:18885 |
| B10.9 | Text edit pop-ups | MISSING | TE S32–S34 4898:17247 / 17293 / 17339 |

**C · activity 发布活动 1–3**

| ID | Screen / sheet / state | Status | Frame id or reference |
|---|---|---|---|
| C2.1 | Sign-in required | MISSING | — |
| C2.2 | Checking identity | MISSING | — |
| C2.3 | Identity check failed | MISSING | — |
| C2.4 | Not allowed | MISSING | — |
| C2.5 | Activity failed to load | MISSING | — |
| C2.6 | Step 1 · empty | PRESENT | 94:5281 · twin 186:5655 · proto 207:10738 |
| C2.7 | Step 1 · filled | MISSING | 新稿 99:7136 |
| C2.8 | Step 1 · errors | MISSING | — |
| C2.9 | Step 1 · locked after sales | MISSING | — |
| C2.10 | Step 2 · empty | PRESENT | 94:5345 · twin 186:5718 · proto 207:10785 |
| C2.11 | Step 2 · filled / uploading / failed | MISSING | 新稿 99:7145 |
| C2.12 | Step 3 · empty | PRESENT | 94:5397 · twin 186:5768 · proto 207:10822 |
| C2.13 | Step 3 · two tickets + collaborator | MISSING | 新稿 99:7156 |
| C2.14 | Step 3 · errors | MISSING | — |
| C2.15 | Step 3 · identity block | MISSING | — |
| C2.16 | Edit mode | MISSING | — |
| C2.17 | Submit failed | MISSING | — |
| C2.18 | Success sheet | MISSING | 新稿 99:7167 |
| C2.19 | Leave alert | MISSING | — |
| C3.1 | 设置活动时间 sheet | MISSING | — |
| C3.2 | 活动类型 category sheet | MISSING | — |
| C3.3 | 我的模板 sheet (+ loading / error / empty) | MISSING | — |
| C3.4 | 选择合作者 sheet | MISSING | — |

**D · simple AI 快速创建**

| ID | Screen / sheet / state | Status | Frame id or reference |
|---|---|---|---|
| D1 | Sign-in required | MISSING | — |
| D2 | Start | PRESENT | 94:4532 · twin 189:3397 |
| D3 | Tags selected + text | MISSING | — |
| D4 | Generating | MISSING | — |
| D5 | Failed | MISSING | — |
| D6 | Quota used up | MISSING | — |
| D7 | Result · collapsed card | MISSING | 新稿 99:5962 |
| D8 | Result · review open (确认地点) | MISSING | 新稿 99:6012 |
| D9 | Recovery states | MISSING | — |
| D10 | 选择原起草记录 sheet | MISSING | — |
| D11 | 另起一次 alert | MISSING | — |

**E · templates (intro, market, detail, mine)**

| ID | Screen / sheet / state | Status | Frame id or reference |
|---|---|---|---|
| E1.1 | Intro · normal | PRESENT | 94:5553 · twin 188:5893 |
| E1.2 | Intro · cards loading | MISSING | — |
| E1.3 | Intro · cards failed | MISSING | — |
| E1.4 | Intro · editor did not open | MISSING | — |
| E2.1 | Market · 主题 tab | PRESENT | 95:1975 / 95:1889 · twins 169:3739 / 169:3833 |
| E2.2 | Market · 玩法 tab | MISSING | — |
| E2.3 | Market · category selected | MISSING | — |
| E2.4 | Market · 全部分类 sheet | MISSING | — |
| E2.5 | Market · loading | MISSING | — |
| E2.6 | Market · error | MISSING | — |
| E2.7 | Market · empty | MISSING | — |
| E2.8 | Market · merchant variant | MISSING | — |
| E2.9 | Market · preview-only toast | MISSING | — |
| E3.1 | Template detail · 详情 tab | PRESENT | 97:2056 / 97:1917 · twins 169:10358 / 169:10499 |
| E3.2 | Template detail · 能力 tab | MISSING | — |
| E3.3 | Template detail · loading | MISSING | — |
| E3.4 | Template detail · error | MISSING | — |
| E3.5 | Template detail · refused | MISSING | — |
| E3.6 | 节点交互预览 sheet × 3 | MISSING | — |
| E3.7 | Template detail · my own template | MISSING | — |
| E3.8 | Template detail · official | MISSING | — |
| E3.9 | Template detail · text expanded | MISSING | — |
| E4.1 | Topic preview · cards | PRESENT | 98:1619 / 98:1573 · twins 169:10640 / 169:10688 |
| E4.2 | Topic preview · card flipped | MISSING | — |
| E4.3 | Topic preview · loading / error | MISSING | — |
| E4.4 | Topic detail · 详情 tab | PRESENT | 98:1660 · twin 169:10736 |
| E4.5 | Topic detail · 能力 tab | MISSING | — |
| E4.6 | Topic detail · loading / error | MISSING | — |
| E4.7 | Topic detail · apply flow | MISSING | — |
| E5.1 | My templates · list | PRESENT | 112:1810 / 112:2270 · twins 181:2222 / 181:2668 |
| E5.2 | My templates · ⋯ menu | MISSING | — |
| E5.3 | My templates · empty | MISSING | — |
| E5.4 | My templates · loading | MISSING | — |
| E5.5 | My templates · error | MISSING | — |
| E5.6 | My templates · sign-in / no access | MISSING | — |
| E5.7 | My templates · load more | MISSING | — |

**F · external games**

| ID | Screen / sheet / state | Status | Frame id or reference |
|---|---|---|---|
| F1.1 | MP list | MISSING | — |
| F1.2 | MP list · loading / error / empty | MISSING | — |
| F1.3 | MP detail | MISSING | — |
| F1.4 | MP detail · loading / missing / error | MISSING | — |
| F2.1 | App library · empty | PRESENT | 104:2673 |
| F2.2 | App library · with games | MISSING | — |
| F2.3 | 导入外部游戏 sheet | MISSING | — |
| F2.4 | Import errors | MISSING | — |
| F2.5 | 确认导入 / 确认更新 | MISSING | — |
| F2.6 | Age gate alert | MISSING | — |
| F2.7 | Run container | MISSING | — |
| F2.8 | Block confirm + report sheet | MISSING | — |
| F2.9 | Catalogue 可玩的 HTML 游戏 | PRESENT | 104:2707 |
| F2.10 | 我的提交 | MISSING | — |
| F2.11 | 创作者变现与绑定 | MISSING | — |

**G · types with no editor source**

| ID | Screen / sheet / state | Status | Frame id or reference |
|---|---|---|---|
| G1 | 判断 true / false (preset of 选项问答) | MISSING | — |
| G2 | 碎片拼图 jigsaw (no schema) | MISSING | — |
| G3 | 刮刮卡 scratch (no config type) | MISSING | — |
| G4 | 传感器挑战: 保持静止 / 步数挑战 / 音频片段 audio_clip | MISSING | — |
| G5 | 猜图 · 揭晓式 image-guess reveal (no schema) | MISSING | — |
| G6 | Icon + preview tile set for 32 picker tags | MISSING | — |

---

# Part A · Gameplay template editor (`/pages/publish/temp/index`)

**Status of the whole page in Figma: PARTIAL.** Only the load-failure state exists (restored `94:4659`, twin `171:6655`, prototype copy `204:16668`). The capture in INDEX row 52 (`052-pages_publish_temp_index--creator-normal.png`) is itself the error screen, so nothing of the editor body, its 30+ gameplay cards, or its 12 sheets has been drawn.

**Sources read for this part**
- `pages/publish/temp/index.wxml` (2,079 lines, all), `index.js` (4,074 lines: constants, `data`, every user-visible string, `_collectValidationErrors`, `sendData`), `index.wxss` (class map)
- `temp/r5-editor.js`, `check-section.js`, `after-section.js`, `questo-author.js`, `preview-verdict.js`
- `utils/publish/advanced-game-config.js` (`defaultConfig()` = every default; `validateNormalized()` = every range and message), `node-game-catalog.js`, `gameplay-support-matrix.js`, `template-tools.js`, `outcome-after.js`, `node-outcome-contract.js`
- Schema check: `docs/release/zip-v35/docs/contracts/content-schema.v1.json` (43 sections; section and field names below match it)
- Owner reference: file `ku2oaN9ag1XUMC9lKNnrcr`, page `5375:13149` "玩法段配置页 · temp · 现码还原" (token legend `5375:13150`, section skeleton `5376:13149`, check states `5390:13149 / 13171 / 13199 / 13232`, scan AR `5385:13149`, album `5399:13149`), and TE proposal frames `J5 5222:19109`, `J6 5222:19302`.

## A0 · Visual base for every frame in Part A

Take these from the owner's legend `5375:13150` (values are code tokens ÷ 2, `.theme-topic-editor` day mode):

| Token | Value | Used for |
|---|---|---|
| page / section-container background | `#F3F4F4` | page, `cg-gcfg` grey panels |
| card surface, input fill inside a grey panel | `#FFFFFF` | `cg-card`, inputs |
| section and input stroke | `#E8E8E8`, 0.5 | card and input border |
| chip stroke | `#DBDBDB` | category chips |
| title and input value | `#000000` | |
| label | `#404040` | 12 / 600, 7 below |
| hint | `#6B6B6B` | 12, line height 1.6, 7 above |
| chip, unselected / selected | `#EAEBEE` / `#000000` with white text | |
| secondary inline action (填入示例, 修改原模板) | `#2F6DF0` | |
| error | red stroke + soft red fill on the field, red `cy-inline-error` line below | |

Sizes: section container padding 14, radius 12; input height 44, radius 11, side padding 13, text 14, 12 below; two-column grid gap 8; chip height 44, radius 11, text 12 / 600; media slot height 80, radius 12, a single slot is 120 wide (never full width); switch 44 × 26; bottom buttons height 44, pill.

Rules the code enforces, keep them in the drawing:
1. Section titles (`cg-sec`) sit **outside** the card, no leading bar; an optional text action (`移除`) at the right.
2. Every single-choice control is a **dropdown** (`cy-dropdown`: a 41-high field with a caret; the panel is a floating white list, radius 12, items 39 high, the chosen item has a check). No segmented control except the three-way 难度 in the check card.
3. A two-column grid always holds two fields.
4. Optional is written `· 选填`; required is a trailing `*`.
5. List editors: each row has a small header `<名称> N` with a ✕ at the right, and one dashed `＋ 添加…` row at the bottom (`cg-cfg-add`). There is **no drag reorder** anywhere on this page. Order is add order; delete is the ✕. (iOS note for later: these become `List` + `.onDelete`; reorder is new behaviour and needs an owner ruling.)
6. All half-screen sheets are page-drawn: grabber 38 × 4, header `退出 · 标题 · 完成` (left text button, centred title, right text button), slide up 300 ms, down 250 ms, scrim tap = 退出. 退出 restores the snapshot taken on open; 完成 validates the panel and shows the first error in a red inline line inside the sheet.

## A1 · Page states

| ID | State | Status | Spec |
|---|---|---|---|
| A1.1 | Sign-in required | MISSING | Nav `编辑玩法模板`. Centred empty state: title `登录后编辑玩法模板`, one button (the shared `cy-empty` sign-in action). |
| A1.2 | Loading | MISSING | Nav + centred spinner with `加载中`. |
| A1.3 | Load failed, access | PRESENT `94:4659` (twin `171:6655`) | Title `当前请求无法读取玩法`, reason line (capture: `原采用未通过内容、玩法能力或资产资格校验`), black pill `重新加载`. |
| A1.4 | Load failed, generic | MISSING | Same layout, title `玩法详情加载失败`; reason is one of `网络暂时不可用，玩法详情未加载` / `玩法详情格式异常，请重试` / `玩法详情未加载`. |
| A1.5 | Load failed, adoption pending | MISSING | Title `采用尚未确认`, reason `采用草稿归属未确认`, plus a text button above the error: `查看我的玩法`. |
| A1.6 | Editing, nothing chosen (new template) | MISSING | A2 with the 玩法 card in its empty row. |
| A1.7 | Editing, filled | MISSING | A2 with one gameplay chosen. Draw at least one long "full" frame per gameplay family (see A4). |
| A1.8 | Support matrix loading / failed | MISSING | Grey text line `正在读取玩法支持范围` at the top of the scroll; on failure a red inline error `玩法支持信息未加载，请重试`. Saving while loading toasts `正在读取玩法支持范围，请稍后保存`. |
| A1.9 | Validation errors shown | MISSING | Fields in error get the red treatment; the page scrolls to the first error. Order: 标题 → 玩法看点 → 玩法类别 → 玩法形态 → 玩法 → 玩法设置 → 语音讲解 → 完成奖励. |
| A1.10 | Save failed | MISSING | Red inline block above the bottom bar: title `玩法没有保存成功` (from topic or city node) / `草稿没有保存成功` / `玩法没有发布成功`; sub is the reason, e.g. `网络暂时不可用，内容已保留，请重试`. |
| A1.11 | Saved (result sheet) | MISSING | See A12. |
| A1.12 | Leave with unsaved changes | MISSING | System-style alert: title `放弃未保存的玩法？`, body `本次修改尚未保存为草稿。`, buttons `继续编辑` / `放弃` (destructive). |
| A1.13 | Read-only personal template | MISSING | Toast `此个人模板仅供查看，请从模板广场选用玩法`; fields disabled. |

## A2 · Page body, top to bottom

Entry modes change what shows: **library** (default, from 发布 tab or 我的节点模板), **`from=fabu`** (opened from a topic node; 模板信息 card and 保存草稿 are hidden; primary button `保存并绑定`), **`from=citynode`** (merchant city node; adds 玩法形态; primary `保存玩法`).

1. **Nav bar**: back chevron, title `编辑玩法模板`. In preview the title is `玩家视角预览`, and the bar disappears entirely while a gameplay screen is being played.
2. **Hero card** (one white card):
   - Cover, 1:1, full card width. Empty: diagonal-stripe placeholder, a round `＋` and `上传玩法封面`. Filled: image `aspectFill` with a round ✕ at top right. If the stored cover can no longer be read: overlay line `原封面暂不可用，点按重新上传`.
   - Title input under it, large: placeholder `给这个玩法起个名字`. Error `请填写玩法标题`.
3. **模板信息** section title + card (hidden for `from=fabu`):
   - `玩法看点 *` with a counter `0/30` at the right; textarea, placeholder `一句话介绍这个玩法的看点`. Errors `请填写玩法看点`, `玩法描述不超过30字`.
   - Two columns: `所需材料` input, placeholder `如:手机、笔` | `商铺类型` picker field showing `请选择`, opens picker sheet A11.6.
   - `玩法类别 *`: wrap row of chips (icon + name + ✕), last chip is `＋ 添加类别` and opens the category sheet (A11.7). Error `请选择至少一个玩法类别`. Removing a chip toasts `移除成功`.
   - A plain row with the single label `先保存为我的玩法` (text only; the code has no control in it).
   - Only `from=citynode`: `玩法形态 *` dropdown: 城市故事卡 / 隐藏菜单 / 拍照点 / 到店扫码. Error `请选择玩法形态`.
4. **玩法规则*** section + card: numbered steps. Each row: a filled number dot **outside** the field on the left, an auto-growing textarea (placeholder `第 N 步要玩家做什么`), and a ✕ when there is more than one step. Bottom: `＋ 添加一步` (limit 12, toast `最多 12 步`).
5. **参与方式** section + card: one dropdown, two columns of options: `直接参与` (直接开始) / `定位到达` (到达节点后开始) / `扫码参与` (扫现场码后开始).
   - When `扫码参与`: a switch row `扫完回复`. On → a textarea (placeholder `例如 欢迎来到老城茶馆`, 200 chars) for text replies; for stored voice / image / AR replies it shows a row `语音回复 · <摘要>` with a `配置 ›` pill that opens the scan sheet A11.3.
6. **玩法** section (right action `移除`, asks for confirmation) + card:
   - Empty: one row `选择玩法` with a `选择 ›` pill; error text under the title when missing: `请添加「玩法」并选一个玩法，这是节点体验的核心`.
   - Chosen: a 36 icon in a tinted square (tint by family: 问答 / 推理 / 互动 / 挑战), the gameplay name, and a `更换` pill. Below it `呈现方式` dropdown: `内嵌故事流` (default) / `整屏`. This dropdown is hidden for 九宫格 and 相册.
7. **玩法设置** section: the config card(s) for the chosen gameplay (A4). 九宫格 shows only the line `九宫格在主题编辑页配置`.
8. `需要的资源` list (only if the template declares resource slots): rows `数值 · <名称>` / `物资 · <名称>`.
9. `状态不好时松一点` switch (only for gameplays that have something to relax). On → a dropdown whose options are generated from the current config, e.g. `血量低时多给 30 秒`, `血量低时多 2 次机会`, `血量低时次数不限`, `血量低时弹球多给 5 秒`.
10. `▶ 按这份配置试玩` full-width text button (only when a gameplay is chosen). Toasts when it cannot run: `这个玩法还要再填一点才能试玩`, `请先为相册添加照片`, `D20 在旅程里掷骰，编辑页演不了`.
11. `可触发的结果`: read-only list of outcome labels this node can produce (e.g. `完成节点`, `检定成功`, `检定失败`, or the author's named endings). Hidden for 相册.
12. **结果反馈** section (A5).
13. **提示** section (A6).
14. `反馈分段（本站内）` (A7).
15. `旧设置（只读，保存时原样保留）` (only for old templates): grey rows `<标签>：<值>`, e.g. `旧答题次数：3`.
16. **完成奖励** section, action `移除` (A8). Not shown for 相册.
17. **剧情故事** card (A9, only on old templates that already have it).
18. **互动工具** section (A10): one row per added tool, plus 语音讲解 and 背景音乐 rows when present, then `＋ 添加互动工具`.
19. Empty-modules state: card `还没有添加玩法模块` / `先设置完成方式`, and a dashed `＋ 添加模块` button that opens A11.1.
20. **Bottom bar** (fixed): `保存草稿` (secondary; library mode only) · `查看预览` (secondary) · primary: `发布玩法` / `保存并绑定` / `保存玩法`.

## A3 · 选择玩法 sheet (A11.2) and the catalogue

Tall sheet. Header `退出 · 选择玩法 · 完成`. Under the header a horizontally scrolling row of category tags: `问答` `推理` `互动` `挑战` (selected = black). Body: a vertical list of the selected category only; each row is icon tile + name + one-line description (or, when unavailable, the reason in grey) + a check when picked; unavailable rows are dimmed and not tappable. Footer strip: the picked gameplay's name and description (empty state: `选一个玩法`) and a `预览` button that plays a sample of it.

All 32 tags, in order, with the exact description line:

| Category | Tag (catalogue key → schema section) | Description shown |
|---|---|---|
| 问答 | 选项问答 (`qaPick` → `qa`, mode PICK) | 2-4 个选项里选一个 |
| | 猜图 (`pricePair`) | 几张图里挑出正确的那张 |
| | 闭眼盲品 (`blindTaste`) | — |
| | 预测 (`predict`) | 今天选一个，到期商家给答案 |
| | 文字问答 (`qaText` → `qa` TYPE; also hosts 逐字猜词 `hangman`) | 出一道题，玩家打字作答 |
| | 拍照打卡 (`qaShot` → `qa` SHOT) | 给一句提示词，玩家拍一张交上来 |
| | 拍照审核 (`photoCheck`) | 拍一张，写清要拍到什么，提交后等待判定 |
| | 拍物成卡 (`objectCard` → `photoCheck`, mode CARD) | 拍下一件东西，生成一张能转着看的藏品卡 |
| 推理 | 排序 (`sort`) | 把几条按正确顺序排好 |
| | 连线 (`match`) | 两列里一一配对 |
| | 分类 (`classify`) | 每条归到对的那一类 |
| 互动 | 抛硬币 (`coin` → `coinFlip`) | 正反面各配一句，抛完照做 |
| | 掷骰子 (`dice` → `diceRoll`, d6) | 掷到几就做第几件事 |
| | 翻卡 (`random`) | 一副卡池抽一张，翻开就是这一关的任务 |
| | 猜数字 (`estimate`) | 猜一个数，按接近程度分档给分 |
| | 找东西 (`hidden` → `hiddenObject`) | 在你上传的图上点中藏起来的目标 |
| | 角色建档 (`profile`) | 设置问题，填写角色资料 |
| | 留言 (`note`) | 写一句话，留给下一个来这里的人 |
| | 今日城市签 (`dailySign`) | — |
| | 相册 (`album`) | 上传照片，翻阅一段回忆 |
| | 九宫格 (`bingo`) — always disabled | 在主题里配置 |
| 挑战 | D20 (`check`) | 掷一个二十面骰，点数够难度就成功 |
| | D20 加值 (`d20` → `diceRoll`, d20) | 二十面骰 + 加值，对照 DC 判定结果 |
| | 计步挑战 (`steps`) | 以微信运动同步的步数为准 |
| | 变色就点 (`react` → `reaction`) | 屏幕一变色就点，比谁快 |
| | 弹球 (`shake` → `ballShake`) | 倾斜手机，让球撞够手机边缘的次数 |
| | 安静挑战 (`quiet` → `quietHold`) | 一直安静到时间到，响一下从头再来 |
| | 罗盘指向 (`compass`) | 把手机转向目标方位，对准保持几秒 |
| | 喊一嗓子 (`shout`) | 让这儿的声音够大，连续喊满几秒 |
| | 倒计时 (`countdown`) | 一钟油，时间走它就退 |
| | 精准停表 (`stopwatch`) | 盲停在目标秒数上，差多少算多少 |
| | 输入挑战 (`typeIn`) | 照着一行字打，超时或打错不算 |

Reasons a row can be disabled (draw one disabled row with one of these as its sub-line): `这种玩法暂时无法确认是否完成` · `这种主题里每一站都要能确认玩家完成，这种玩法确认不了，请换一种玩法` · `这种玩法的成绩只在手机上测，确认不了玩家真的完成，请换一种玩法` · `预测要由承接商家给答案，没有承接商家的站点在这里不能用` · `这种玩法不能用作归零挑战` · `此玩法暂不支持归零恢复，请选择其他挑战节点` · `当前身份未解锁「分支 / 条件玩法」` · `在主题里配置`.

Icons today are generic line icons reused across types (`edit` ×7, `camera` ×3, `star` ×3, `clock` ×3). **Each tag needs its own glyph in the redesign**; that is the owner's "icons and visual previews of each gameplay type" request and is listed in Part G.

## A4 · Config card for each gameplay

Format: fields in visual order. `*` = required. Control types: **T** single-line text, **TA** textarea, **N** number field, **DD** dropdown, **SW** switch, **IMG** image slot (upload), **LIST** list editor. Ranges and messages are the validator's.

### 问答 family

**A4.1 文字问答 `qaText`** (`qa`, mode TYPE). Card header `题目`.
| Field | Control | Placeholder / default | Rule and message |
|---|---|---|---|
| 逐字猜词 | SW (first row of the card) | off | On switches the card to A4.2 |
| 题干 * | T | `例如 这座桥建于哪一年？` | 1–120 chars: `问答题干不能为空` / `…不能超过 120 字` |
| 正确答案 * | T | `可填多个，用、分隔` | Hidden when the template is an adopted copy. `打字问答必须填正确答案`; ≤ 200 |
| 其他可接受写法 | LIST of T | `例如 一九三七`; `＋ 添加写法` | ≤ 20; `写法不能为空`, `写法不能重复` |
| 次数上限 | N | `0 表示不限`, default 0 | 0–10: `问答可以答几次须为 0 至 10,0 表示不限` |
| 奖励分 | N | `0 至 200`, default 0 | `问答的奖励分须为 0 至 200` |
The last two sit in a two-column grid. A shared card **题干附件** follows on legacy templates: two slots `配图` and `配音` (filled audio shows `已配音频` + ✕).

**A4.2 逐字猜词 `hangman`**
| Field | Control | Placeholder / default | Rule |
|---|---|---|---|
| 答案 * | T | `例如 ENDLESS` | ≤ 40 chars: `请填写答案`, `答案最多 40 个字`, `答案至少要有一个可补的字母或数字` |
| 格子 | tap grid | One 28-px cell per character, in one dense row; spaces and punctuation render as separators | Tap toggles a cell between "given" (shows the letter, filled) and "player fills" (empty). `至少留一格给玩家补` |
| 其他可接受写法 | LIST of T | `例如 NICOLAS AND PERNELLE`; `＋ 添加写法` | ≤ 10; `别名不能为空`, `别名与答案或其他别名重复` |
| 区分大小写 | SW | off | |

**A4.3 选项问答 `qaPick`** (`qa`, mode PICK). Sub-headers inside one card: `题目`, `作答规则`, `选项`, `指认结案`.
| Field | Control | Placeholder / default | Rule |
|---|---|---|---|
| 题干 * | T | `例如 这座桥建于哪一年？` | as A4.1 |
| 判断答案对错 | SW | on | Off = a survey question: the three rows below and every "correct" radio disappear; only 奖励分 remains |
| 选择方式 | DD row | `单选` / `多选` | Multi: `多选问答至少要指定两个正确答案`, `多选问答不能把全部选项都设为正确答案` |
| 次数上限 | DD row | 不限次数 / 1 次 / 2 次 / 3 次 / 5 次 / 10 次 | |
| 次数用完后 | DD row | `不亮出答案` (default) / `亮出正确答案` | |
| 奖励分 | N | `0 至 200` | |
| 选项 (2–4) | LIST | Each row: header `选项 N` + ✕; a 44 image slot (`image` icon, tap to upload, ✕ to clear) **beside** a T `玩家看到的文案`; `选中后的反馈` TA (`选了它之后玩家看到的文字`, ≤ 120) with up to 3 `配图` thumbnails; SW `记住这个选择（结局和后文可以用）`; a radio/checkbox row `设为正确答案` → `这个是正确答案` (multi: `勾为正确答案`) | `选项问答须为 2 至 4 个选项`, `问答选项文案不能为空`, `…不能超过 32 字`, `配了图的选项要写文案`, `每个选项最多 3 张反馈图片`. `＋ 添加选项` hides at 4 |
| 把选项做成人物指认 | SW (single-choice + judged only) | off | On → A4.4. `指认只能用在单选的选项问答上` |

**A4.4 人物指认 `accusation`** (inside A4.3)
- One card per option: avatar slot (round, upload) + the option text as name + T `身份`. Testimony list: each row T `证词` + ✕, and under it T `拿到哪条线索后显示`. `＋ 添加证词`.
- `线索板`: one image slot.
- `指认正确的结局 *` TA `玩家指认正确后看到的结局`; `指认错误的结局 *` TA `机会用完仍指认错误时看到的结局`.
- `允许提前指认` SW; on → T `提前结案的记录名`.
- Errors: `每个人物都要有头像`, `证词要同时写线索和内容`, `请写指认正确的结局`, `请写指认错误的结局`, `允许提前指认时要写结束记录名`.

**A4.5 拍照打卡 `qaShot`** (`qa`, mode SHOT)
| Field | Control | Placeholder | Rule |
|---|---|---|---|
| 题干 * | T | `例如 这座桥建于哪一年？` | |
| 前置说明 * | T | `例如 先闭上眼睛尝一口` | ≤ 60; `拍照打卡要写一句提示词，告诉玩家拍什么` |
| 补充说明 | T | `例如 站在树的左边，把整棵树都框进去` | ≤ 56 |
| 次数上限 · 奖励分 | N · N | `0 表示不限` · `0 至 200` | |

**A4.6 猜图 `pricePair`**
| Field | Control | Placeholder / default | Rule |
|---|---|---|---|
| 题目 * | T | `例如 哪一张是这家店的招牌` | 1–64 |
| 图 (3–8) | LIST | Row header `图 N` + ✕; T `这张图叫什么，如 冰美式`; T `图片地址(https 或站内路径)`; radio row `设为正确答案` → `这张是正确答案` | Default 3 rows, first is correct. `猜图的图片须为 3 至 8 张`, `猜图图片说明不能为空`, `猜图必须指定且只指定一张正确答案` |
| ＋ 添加一张 | | | |
| 奖励分 · 次数上限 | N · N | `0 至 200` · `0 表示不限` | 0–200; 0–10 |
Note: the image is a pasted URL today. In the app draw an **image slot** per row instead (ask the owner; the stored field stays `imageUrl`).

**A4.7 闭眼盲品 `blindTaste`**
| Field | Control | Placeholder / default | Rule |
|---|---|---|---|
| 闭眼盲品 | SW header row | on | |
| 标题 * | T | `例如 闭上眼 先尝再猜` | 1–64 |
| 步骤说明 | T | `① 向店员领盲品小样 ② 闭眼尝 ③ 睁眼作答` | ≤ 120 |
| 旁白 | T | `例如 别偷看，舌头比眼睛诚实` | ≤ 60 |
| 选项与正确答案 (2–6) | LIST | Row: `选项 N` + ✕; T `选项 key，如 A`; T `玩家看到的文案`; radio `设为正确答案` → `正确答案` | Default A, B; answer A. `盲品选项须为 2 至 6 项`, toast `盲品选项最多 6 项` |
| 奖励分 | N | `0 表示不给分` | 0–1000 |

**A4.8 预测 `predict`**
| Field | Control | Placeholder / default | Rule |
|---|---|---|---|
| 问题 * | T | `例如 猜猜今天哪款卖得最多` | 1–120 |
| 说明 | T | `例如 明早由店里给出答案` | ≤ 60 |
| 选项 (2–4) | LIST | `选项 N` + ✕; T `玩家看到的文案`; `＋ 添加选项` | |
| 当天截止（点） | DD | 0–23, default `20 点` | |
| 第几天揭晓 | DD | 当天 / 明天 (default) / 后天 / 第 N 天 … 30 | |
| 揭晓时间（点） | DD | 0–23, default `20 点` | `当天揭晓的话,揭晓时间要晚于收注截止时间` |
| 奖励分 | N | `0 表示不给分` | 0–1000 |

**A4.9 拍照审核 `photoCheck`** and **A4.10 拍物成卡 `objectCard`** (same card; CARD mode adds one field)
| Field | Control | Placeholder / default | Rule |
|---|---|---|---|
| 标题 * | T | `例如 拍一张窗外` | |
| 默认卡名 (CARD only) | T | `例如 一枚旧弹壳` | ≤ 64 |
| 提示词 | T | `例如 把窗框也拍进去` | |
| 要拍到什么才算过 * | T | `例如 画面里要能看见窗外的街景，窗框入镜` | 1–60: `拍照审核要写清楚拍到什么才算过，1 至 60 字` |
| 取景轮廓 | IMG, single 120-wide slot | `轮廓图`; filled = `aspectFit` + ✕ | optional |
| 轮廓浓淡 | slider 0–100, step 5, value shown | 40 | only when an outline is set |
| 识别通过分（0–100） · 次数上限（1–10）* | N · N | 60 · 3 | |
| 次数用尽还没过 | DD | `让他重拍` (default) / `放过他` | |
| 奖励分 | N | `0 表示不给分` | |

### 推理 family (errors appear live inside the card)

**A4.11 排序 `sort`**: `题干 *` T (`例如 把冲泡顺序排好`); `按正确顺序排好（从上到下就是答案） *` LIST: rows `第 N 步` + ✕, T `例如 先温杯`; `＋ 添加一步`. 2–8 rows (default 3). Toasts `排序最多 8 条`, `排序至少 2 条`. **This list is the one place where order is the answer**, so in the app it needs drag handles.

**A4.12 连线 `match`**: `题干 *` T (`例如 把工具和它的用途连起来`); `一对一配好（左 | 右） *` LIST: rows `第 N 对` + ✕, two T side by side (`左，如 手冲壶` | `右，如 装水`); `＋ 添加一对`. 2–6 pairs (default 2). `连线的左右两列数量必须一致，一一对应才能配对`.

**A4.13 分类 `classify`**: `题干 *` T (`例如 把这几样东西分到的类别里`); `类别（2 至 4 个） *` LIST: `类别 N` + ✕, T `例如 器具 / 耗材`, `＋ 添加类别`; `条目（2 至 10 条，每条选一个类别） *` LIST: `条目 N` + ✕, T `例如 滤杯`, DD of the categories, red `未选择类别` when empty; `＋ 添加条目`. `分类的每一条都要选一个类别`.

Below any of the three (and below 选项问答 / 文字问答): dropdown button `＋ 再加一段题目`, options from 选项问答 / 文字问答 / 排序 / 连线 / 分类 not yet used. An added segment renders as its own card with header `<名称>` and a `移除` action.

### 互动 family

**A4.14 抛硬币 `coinFlip`**: `标题 *` T (`例如 抛一次，认结果`, ≤ 32); `正面`: two T in a grid (`叫什么，如 正面` default `正面` | `那就做什么，如 这杯店家请`); `反面`: (`叫什么，如 反面` default `反面` | `那就做什么，如 这杯你请`).

**A4.15 掷骰子 `diceRoll` d6**: `标题 *` T (`例如 掷到几就做第几件事`); `几颗` DD `一颗` / `两颗`; `六个面各写一件事 *`: six fixed rows, number badge 1–6 + T `掷到 N 要做什么`. No add or delete.

**A4.16 翻卡 `random`**: `这副卡叫什么` T (`如 今日线索卡`, ≤ 20); `每局抽取数量 *` N (default 1, 1…number of cards: `翻开数量须在卡片数量范围内`); LIST `物品 N` + ✕: T `唯一 ID，如 clue_1`, T `玩家看到的名称`, N `权重`, TA `抽中后展示的内容`; `＋ 添加卡片`. Default one card `线索卡`, weight 1. Errors `随机卡至少配置 1 张卡片`, `卡片的 ID、名称和权重不能为空`, `卡片 ID 不能重复`. **This is the "random task pool".**

**A4.17 猜数字 `estimate`**: `题干 *` T (`例如 这罐咖啡豆有多少颗`); grid `单位` T (`颗 / 杯 / 本`, ≤ 8) · `奖励分` N; grid `量程下限` N (0) · `量程上限` N (1000); grid `正确答案 *` N (500) · `容差 *` N (50) (both hidden on adopted copies); `揭晓文字` TA (`例如 一共 480 颗，老板数了两遍`, ≤ 200). Errors `估数量程的下限必须小于上限`, `估数答案必须落在量程之内`, `估数容差必须大于 0`, `估数容差不能超过量程的一半`.

**A4.18 找东西 `hiddenObject`**: `标题 *` T (`例如 找出藏在店里的三只猫`); `提示` T (`例如 窗台、书架、收银台后面`, ≤ 60); `次数上限` N (`0 表示不限`); `场景图地址 *` T (`https 链接或站内路径`); **`在图上点出每个目标`**: the scene image at its natural ratio (empty placeholder text: `先填上面的场景图地址，再回来节点置`), numbered round pins on it; LIST `目标 N` + ✕: T `目标名，如 窗台上的橘猫`, a button `标位置` (armed state: `点图上的位置`, black) and a status `还没标` / `已标好`; `＋ 添加目标`; `奖励分` N. 3–5 targets (default 3). Errors `找东西要标 3 至 5 个目标`, `找东西的两个目标挨得太近,请把它们分开一些`; toast `图还没加载好，过一下再标`. Flow to draw: (a) no image, (b) image + 3 pins, (c) one target armed with the image outlined, (d) error "too close".

**A4.19 角色建档 `profile`**: `标题 *` T (`例如 出生登记`); `引导语` T (`例如 填完这张表，你就有了身份`); SW `填写后添加头像` (on) → SW `头像必填` (off); LIST of questions (1–8), each card `问题 N · 必答` + ✕: T `玩家看到的问题，如 你叫什么`, T `变量名，如 name（字母开头，最多 16 位）`, DD `打字答` / `选项答`;
- 打字答: N `最多几个字` (12).
- 选项答: LIST of options (2–6): `选项 N` + ✕, T `玩家看到的文案，如 店员`, T `存下来的值，如 clerk`, SW `记住这个选择（结局和后文可以用）`, sub-list `选了它之后的效果` (A5.3 effect rows, header `加成 N`, `＋ 添加加成`, max 16); `＋ 添加选项`. Then SW `咔哒 · 条件够了改写成标准答案`; on → grid `这个状态` T (`counter.instability`) · `到几就触发` N (`4`); `改写成哪一项` DD of the options; `改写后那句内心声音` T (`这一栏已经填好了。你想当{picked}，表格上写的是{assigned}。`, ≤ 120).
- `＋ 添加问题`; `奖励分` N. Toasts `建档最多 8 个问题`, `建档至少留一个问题`, `选项题至少留 2 个选项`.

**A4.20 留言 `note`**: `标题 *` T (`例如 写一句留给下一个人`); `提示词 *` T (`例如 你看到窗外什么`); grid `最多几个字` N (40) · `展示条数（0–5）` N (3); `预设短句（最多 6 条）` LIST: `短句 N` + ✕, T `例如 天是灰的`, `＋ 添加短句`; `奖励分` N.

**A4.21 今日城市签 `dailySign`**: SW header `今日城市签`; `开场签 *` LIST: `开场签 N` + ✕, TA `一行一句，最多 4 行，每行 24 字以内`, `＋ 添加开场签` (1–60); `开场签落款` T (`例如 店主老王`, ≤ 16).

**A4.22 相册 `album`**: `照片（1 至 6 张） *` LIST: `照片 N` + ✕, an image slot (tap to choose / replace), T `这一张的配文` (≤ 40); `＋ 添加照片` hides at 6. No 呈现方式, no 结果反馈, no 完成奖励, no tools (`相册暂不支持叠加工具`).

**A4.23 九宫格 `bingo`**: no card; the line `九宫格在主题编辑页配置`. Its real editor is the theme-level sheet B7.9.

### 挑战 family

**A4.24 D20 `check`** (grouped list that expands in place; one row open at a time). Owner reference: `5390:13149 / 13171 / 13199 / 13232`.
- Row `加上属性` → value. Three states: theme has no attributes (`技能` shown as a plain text field); loading failed (red `没有读取成功，请再试一次。`, tap to retry); normal (expands to a checklist of the theme's attributes, or `＋ 添加属性` which returns to the theme's d20 settings).
- `难度`: three-way segmented `简单` / `中等` (default) / `困难`.
- `情境加值` group: rows `<条件> · +N`; expanded: stepper `至少 N`, choice `固定加值` / `加上属性值`, stepper `加值 +N` or an attribute checklist, `删除`. `＋ 添加加值` opens sheet A11.5.
- `魔鬼交易` SW (only when the theme enables it); on → T `说明`, chips `加值 +1 / +2 / +3`, group `代价`: rows with a quantity stepper and `删除`; `＋ 添加代价` (sheet A11.5).
- `过了说一句` TA; `没过说一句` TA (≤ 200 each).
- `判定通过后的效果` / `判定失败后的效果`: effect rows (A5.3), only when present.
- SW `幸运` → row `幸运加分` expanding to: `幸运高多 1 分` / `幸运低少 1 分` / `幸运高多 1 分，幸运低少 1 分`.
- SW `生命值越低越困难`.

**A4.25 D20 加值 `diceRoll` d20**: `标题 *` T (`例如 能否找到暗门`); grid `难度 DC · 1 至 40 *` N (10) · `加值（−20–20）` N (0); `掷骰方式` DD `普通 · 掷一颗` / `优势 · 两颗取高` / `劣势 · 两颗取低`; `成功结果 *` TA (`成功后发生什么`); `失败结果 *` TA (`失败后发生什么，玩家接下来做什么`), 1–200 chars each.

**A4.26 计步挑战 `steps`**: `目标步数 *` N (`100 至 100000`, default 6000); `小标题` T (`例如 低碳行动 · 今日步数`, ≤ 32); `奖励分` N (`0 表示不给分`, 0–1000).

**A4.27 变色就点 `reaction`**: `标题 *` T (`例如 变绿就点`); grid `几轮 *` N (`1 至 10`, 3) · `达标毫秒 *` N (`120 至 2000`, 320).

**A4.28 弹球 `ballShake`**: `标题 *` T (`例如 撞够 30 次`); `要撞多少次 *` N (`1 至 200`, 30); SW `限时` (off) → `时限（秒） *` N (`3 至 300`, 12).

**A4.29 安静挑战 `quietHold`**: `标题 *` T (`例如 别出声`); `要安静多久（秒） *` N (`5 至 300`, 15); `说明` T (`例如 声音过线就从头再来`).

**A4.30 罗盘指向 `compass`**: `标题 *` T (`例如 把手机转向钟楼`); `目标方位（度） *`: N (`0 至 359，正北是 0`, empty by default) with a button beside it `对准方向取值` (reads the device heading; toasts `已记下当前方向` / `这台设备没报出方向，请在真机上试`); grid `容差（度） *` N (`5 至 90`, 15) · `保持几秒 *` N (`1 至 10`, 3); `提示语` T (`例如 它比你想的更靠右`, ≤ 60); `奖励分` N; SW `允许跳过` (off).

**A4.31 喊一嗓子 `shout`**: `标题 *` T (`例如 一起喊，让这儿听见`); `要连续喊满几秒 *` N (`5 至 300`, 5); `奖励分` N (default 10).

**A4.32 倒计时 `countdown`**: `标题 *` T (`例如 倒计时`); `倒计时长（秒） *` N (`5 至 3600`, 90); `到点时说什么 *` T (`例如 时间到。`, ≤ 60).

**A4.33 精准停表 `stopwatch`**: `标题 *` T (`例如 把手机拿到面前，随时可以开始`); grid `目标时间（秒） *` N (`3 至 120`, 10) · `允许误差（毫秒） *` N (`50 至 5000`, 300); `次数上限` N (`0 表示不限`, default 3, max 10).

**A4.34 输入挑战 `typeIn`**: `标题 *` T (`例如 打出这行字`); `要打的那行字（1 至 40 字） *` T (`例如 hello world`); grid `限时（3 至 120 秒） *` N (10) · `次数上限（0 = 不限）` N (0) (on new-style templates only the tries field shows, the time limit moves to the 限时挑战 tool); SW `区分大小写`; SW `终端样式（黑底白字，打对后整屏收成一条线）`; `奖励分` N.

### Participation and legacy

**A4.35 扫码参与 `scan`**: configured in 参与方式 + sheet A11.3, not as a gameplay tag.

**A4.36 Legacy cards, drawn only for the "old template" state**: (a) `问题 * / 正确答案 *` text question; (b) option question `选项 · 点圆圈设为正确答案`: rows with a letter radio A–D, T `选项 A`, ✕ (min 2, max 4: `至少需要 2 个选项`, `最多 4 个选项`) and per-option `＋ 配图` / `＋ 音频` chips; (c) `拍照要求` TA (`告诉玩家要拍什么，例如:与这棵古树合影`); (d) `偏好题配置`: a JSON textarea (`填写 steps / dimensions / results / tagOutput`), link `填入可编辑示例` (blue), and `全部结果分支预览` cards (code, title, body, `下一步 · …`); (e) legacy 提示 card (A6.2).

## A5 · 结果反馈 (result feedback: reply, cost, effect, next segment)

Section title `结果反馈`, one grey panel.
1. Three numbered lines describing the flow. Line 1 depends on the gameplay (`玩家打字作答` / `玩家从选项里选一个` / `玩家拍一张照片交上来` / `玩家抛硬币` / `玩家掷 D20` / `玩家掷骰子` / `玩家猜一个数` / `玩家挑一张图` / `玩家在图上找目标` / `玩家抽一张卡` / `玩家选一个答案` / `玩家闭眼尝一口再选` / `玩家把几条排好顺序` / `玩家把两列一一连好` / `玩家把每条归到一类` / `玩家拍照提交` / `玩家走够步数` / `玩家等屏幕变色再点` / `玩家倾斜手机让球撞够次数` / `玩家保持安静到时间` / `玩家把手机对准方位` / `玩家喊到声音够大` / `玩家在倒计时里完成` / `玩家盲停在目标秒数` / `玩家照着一行字打出来` / fallback `玩家完成这一关`). Lines 2–3: `达成就是成功，没达成就是失败` + `玩家看到成功或失败的反馈，然后继续`; for completion-only gameplays: `做完就算完成` + `玩家看到完成反馈，然后继续`.
2. SW row `成功反馈` (completion-only: `完成反馈`). On → TA (placeholder `成功反馈的文字`, ≤ 2000), a photo grid of up to 3 images with a `＋` cell, and a row `消耗与效果 · N 项 ›` (opens A11.4).
3. SW row `失败反馈`, same body.
4. `每个结果单独回复` (only gameplays with discrete results): one row per result with an `编辑 ›` pill and a summary. Labels: `选「<选项>」之后`, `抽到「<卡名>」之后`, `正面之后` / `反面之后`, `掷到 N 之后`. Disabled reasons: `多选题请使用通过/没通过之后`, `多张翻卡请使用通过/没通过之后`, `此形式请使用通过/没通过之后`, `暂未开放`, `旧后段只读，暂未开放`.
5. `效果作用于` DD: `本人或本队` / `已参与的队伍` / `全场有效队伍` (some disabled with a reason; changing while a vote tool exists toasts `请先移除投票工具`).

**A5.3 Effect row** (reused in 角色建档, D20, and A11.4). New style: DD `选择需要的数值` (the template's declared values, plus an inline "name a new one" field: `给需要的数值起名（1 至 20 字），采用到主题时再对应` with `确认` / `取消`), DD `增加` / `恢复到至少`, N `数量 1 至 999`. Warning text when the value was deleted: `数值已删除，请重选`. Old style (kept on old templates): T `变量名，如 counter.energy`, DD `加` / `设为` / `挂标记`, value field (`1`, or `tag.hurried（tag. 开头）`). Max 16 per list: `一项最多配 16 条效果`.

## A6 · 提示 (hint ladder)

**A6.1 New ladder** (schema `hintLadder[]` + `hintFreeUsesPerRun`). Section `提示`.
- SW `本题启用提示`.
- `整局免费次数` N (`0`), 0–1000: `免费次数须为 0 至 1000 的整数`.
- Up to 6 levels. Each level card: header `第 N 层` + ✕; grid `类型` DD (`文字` / `图片` / `首字` / `数字` / `答案` / `跳过`) · `消耗积分` N (`0 表示免费`); then by type: 文字 → TA `提示文字`; 答案 → TA `揭晓时的文字(可不填)`; 首字 → N `揭示第几个字(不填为第 1 个)`; 图片 → image slot `提示图`; 数字 and 跳过 → nothing more. Row errors in red: `请填写提示文字`, `请上传提示图片`, `位置须为 1 起的整数`, `积分须为非负整数`.
- `＋ 添加一层` hides at 6.
- Frames to draw: off; on with 3 levels (文字 free, 图片 5 积分, 答案 20 积分); one level in error.

**A6.2 Legacy hints** (only old text / option / GPS templates): header row with an info icon, `提示`, and a switch; on → three inputs: `一级提示，如:留意脚下的石板`, `二级提示(可选),更明确的引导`, `备用答案，卡住时直接给出`.

## A7 · 反馈分段（本站内） (in-node feedback segments)

Header: `反馈分段（本站内）` (old templates: `分支剧情（旧设置）`). LIST of segments (max 50): `步骤 N` + ✕, T `步骤标题`, TA `这一段的反馈内容`, SW `这一段结束反馈`. A non-ending segment has options (max 12): `选项 N` + ✕, T `选项文案`, DD "goes to" (the other segments). Old templates also show T `名称（仅自己可见）` (`例如 找到钟楼`) on ending segments and N `得分` on options. `＋ 添加选项`, `＋ 添加反馈分段`. Toasts `最多配置 50 段反馈`, `每段最多配置 12 个选项`.

## A8 · 完成奖励 (rewards)

Section `完成奖励` + `移除`. Three switch rows, each opening a sub-card:
1. `优惠券`: a coupon picker field, label `节点完成奖励`, placeholder `选择优惠券`, with create-new allowed. This is the shared reward selector (B9.3).
2. `文字反馈` (shown only if an old template already has it): TA `例如:恭喜你解开了老城的第一个秘密!`.
3. `勋章`: a 64 image slot (`＋`), T `勋章名称，如 老城探秘者`, ✕ to clear; `勋章样式` DD `二维发光` / `3D 珐琅`.
Errors: `请至少配置一种奖励`, `勋章需同时上传图片和名称`.

## A9 · 剧情故事 (story beats, legacy module)

Card header: edit icon, `剧情故事`, a remove action. LIST of time nodes: header `N 时间节点` + ✕ (when more than one); TA `这一刻发生了什么?写下玩家此时读到的片段…`; T `时刻标签，如「此刻」`; `配图（最多 6 张）` with a counter `n/6`, thumbnails with ✕, `＋ 加图`. Bottom: `＋ 添加时间节点 · 延长时间线`. Toast `每个节点最多6张`.

## A10 · 互动工具 (tools and modifiers)

Section `互动工具`. Rows: `<工具名>` + grey summary + `配置 ›`. Summaries are generated, e.g. `行动 ×1`, `第 1 组…`, `线索（公开）`, `成功上限 3 次 · 同场共用 · 须已到达`, `允许物资交换`, `3 个选项`; 语音讲解 shows the file name or `未上传`; 背景音乐 shows the title, or `已上传音乐` / `未上传`, plus ` · 循环`.

`＋ 添加互动工具` opens **A11.8 tool picker**: header `退出 · 互动工具 · 完成`; wrap of tag pills (icon + label; an added tool shows a check and tapping it goes straight to its sheet; an unavailable one is dimmed and tapping it shows the reason in the hint line at the bottom). Pills: `费用` · `奖励` · `线索` · `成功使用次数` · `投票与投入` · `限时挑战` · `时段限定` · `排行榜` · `多人协作` (always disabled: `规则待定义`) · `语音讲解` · `背景音乐`. Reasons: `请先选择主玩法`, `相册暂不支持叠加工具`, `请先移除费用或次数规则`, `这种玩法暂时无法确认是否完成`, `需在主题里选全场共享的组队进行方式`, `投票与结果规则不能同时使用`, `投票不能再设置扣费、次数或效果`, `归零挑战不能再设置扣费、次数或效果`, `当前玩法不支持限时挑战`.

Each tool sheet has the same shell, and a red text button at the bottom `移除这个工具` (modifiers: `移除这条附加规则`).

| ID | Sheet | Fields |
|---|---|---|
| A10.1 | 费用 `cost` | SW `任选一组费用`. Groups (fixed: one group titled `固定费用`; optional: 2–4 groups `费用组 N` with T `组名，可不填` and a remove). Rows (max 32): `费用 N` + remove, DD `数值` / `物资`, DD of declared resources, T `给需要的资源起名（1 至 20 字）` when new, N `数量 1 至 999`. `＋ 添加费用`, `＋ 添加费用组`. Then `需要的资源` list with a rename field per slot. Errors: `请添加至少一项费用`, `数量须为 1 至 999`, `同一资源合计不超过 999`, `任选费用须有 2 至 4 组`, `组名不超过 20 字`, `「结果之后」已设置消耗，费用只能在一处设置`. |
| A10.2 | 奖励 `reward` (**drops**) | SW `任选一组奖励`. Groups `固定奖励` / `奖励组 N`. Rows `物资 N`: DD of items, T `给需要的物资起名（1 至 20 字）`, N `数量 1 至 999`. `＋ 添加物资`, `＋ 添加奖励组`. Errors `请添加至少一项奖励`, `任选奖励须有 2 至 4 组`. |
| A10.3 | 线索 `clue` | Rows (max 10) `线索 N` + remove: T `线索名称` (≤ 20, unique), a grey line with its content (`内容：剧情第 N 段` or `未配内容`), SW `全场公开`. `＋ 添加线索`. SW `只首次生效`. Errors `请填写线索名称`, `线索名称不能重复`, `只首次生效需要至少一条全场公开线索`, `只首次生效需要把成功次数设为同场共用`. |
| A10.4 | 成功使用次数 `uses` | N `成功上限` (`1 至 99`); DD `次数计算方式` `本人或本队` / `同场共用`; SW `效果对象须已到达`. Errors `成功次数须为 1 至 99`, `请选择次数归属`. |
| A10.5 | 物资交换 `trade` (old templates) | SW `允许物资交换`. |
| A10.6 | 投票与投入 `vote` | Optional grey condition line at top. LIST of options (1–30): `选项 N` + `移除`, T `选项名称` (≤ 80), T `选项说明，可不填`; sub-list `投入物资 N` + `移除`: DD item, T new-item name, N `数量 1 至 999`; `＋ 添加投入物资`; sub-list `需要的线索`: `线索 N` + `移除`, T `与公开线索同名`; `＋ 添加需要的线索`. `＋ 添加投票选项`. When there are options: `没有方案执行时` T `标题` (1–80), T `内容，可不填`. Then `需要的资源`. Errors `请添加 1 至 30 个选项`, `同一选项不能重复投入同一物资`, `投票不能与费用、奖励、线索或次数叠加，请先移除投票`. |
| A10.7 | 限时挑战 `timer` | SW `限时挑战` (or the grey line `此玩法不支持限时`); on → N `时长（秒） *` (default 300; `计时时长须为 10 秒至 24 小时`), DD `超时结果` (`FAILED` / `EXPIRED`; raw codes today, write them as 判失败 / 判过期 and flag to the owner). |
| A10.8 | 时段限定 `timeWindow` | SW; on → grid `开放起 *` (`23:00`) · `开放止 *` (`01:00`) (defaults 20:00–23:00; cross-midnight allowed), T `小标题` (`例如 午夜电台 · 时段限定`), T `未开放时的标题` (`例如 还没到开播时间`), T `订阅消息模板 ID` (`留空则不提供开播提醒`; WeChat-only, omit in the app). |
| A10.9 | 排行榜 `leaderboard` | SW; on → DD `排名依据` (`ELAPSED_TIME` / `SCORE` / `COMPLETED_UNITS` → 用时 / 得分 / 完成数), DD `排行范围` (`ACTIVITY` / `TOPIC` → 本场 / 本主题), N `展示人数` (default 50, 1–100). |
| A10.10 | 语音讲解 `voice` | Empty: a dashed upload row `上传音频文件`. Filled: a card with a `播放` / `暂停` button, file name (default `导览音频`), ✕; then `时长（秒，选填）` N (`例如:45`). Error `请上传音频文件`; toast `预听失败`. Bottom `移除语音讲解`. |
| A10.11 | 背景音乐 `backgroundMusic` | `音乐名称` T (`例如 老城茶馆`); `音乐 *` upload row or a file card with ✕; SW `循环播放` (on). Bottom `移除背景音乐`. |

## A11 · Other sheets

| ID | Sheet | Spec |
|---|---|---|
| A11.1 | 添加模块 | Header `退出 · 添加模块 · 完成`. Cards: `玩法`, `完成奖励` (`优惠券 / 勋章`) with a `＋` at the right; each can carry a small tag. Empty: `全部模块已添加`. |
| A11.2 | 选择玩法 | A3. |
| A11.3 | 扫完回复 (scan reply) | Header `退出 · 扫完回复 · 完成`. `扫码后回什么` DD: `文字` (扫完弹一段话) / `语音` (扫完放一段录音) / `图片` (扫完出一张图) / `显形` (扫完东西出现在镜头里). 文字 → `回复内容 *` TA (`例如 欢迎来到这家店，今天的手冲是耶加雪菲。`, ≤ 200). 语音 → `语音地址 *`. 图片 → `图片地址 *`. 显形 → `显形图地址 *`, `图片宽度（%）` slider 20–100 step 5 (60), `东西怎么出来` DD: `不开` (镜头上叠一张图) / `放在地上` (识别地面或桌面，点一下放在那儿) / `认一张图` (认出你拍的实物照片，贴着它长出来); 认一张图 → `识别图地址（现场那件实物的正面照片） *`; any AR mode → `3D 模型` row: `＋ 上传 .glb 模型` or `✓ 已上传 3D 模型` + clear. Last: `奖励分` N (`0 至 200`). Errors: `扫码回文字就得写一句话`, `扫码回语音就得配一段语音`, `扫码回图片就得配一张图`, `扫码要显形就得配一张叠加图`, `图像识别要配一张识别图`, `3D 模型只支持 .glb`. Owner reference `5385:13149`. **This is the AR config.** |
| A11.4 | 消耗与效果 / 结果之后 | Header `取消 · <消耗与效果 or the result label> · 完成`. For a per-result row: `回复一句` T (`例如 你稳住了呼吸`) and `配图` (≤ 3). Group `消耗`: sentence rows `<数值> −N ›`; expanded: stepper `数量` (1–999) and `删除`. `＋ 添加消耗` expands a list of declared values and `新建数值`. Group `效果`: rows `<数值> +N` or `<数值> 恢复到至少 N`; expanded: choice `增加` / `恢复到至少`, stepper `数量`, `删除`. `＋ 添加效果` pushes a second layer (back arrow, title `添加效果`): kinds listed, tap a kind to expand the value names, tap a name to add. Row `之后 · <不进入下一段 / 段名> ›` expanding to a checklist of feedback segments. Errors prefixed with the row label, e.g. `…：消耗/效果最多 20 项`, `…：消耗目标不能重复`, `…：回复不能超过 2000 字`. |
| A11.5 | 添加加值 / 添加代价 | Stacked half sheet, header `取消 · 添加加值` (or `添加代价`). One column of kinds with chevrons; tapping a kind expands its names in place; tapping a name adds it and closes. |
| A11.6 | Generic picker (`选择适用场所`) | Title left, ✕ right. Options as full-width rows, selected in black: 景区 / 公园绿地 / 商圈街区 / 古镇老街 / 博物馆 / 校园 / 室内场馆. Failure toasts `暂无可选项，请稍后重试`, `选项加载失败，请重试`. |
| A11.7 | 玩法类别 category sheet | The shared category sheet (same as B6.2), multi-select. |
| A11.8 | 互动工具 picker | A10. |
| A11.9 | 确认移除模块 | Alert, only when the module has content. 玩法: `移除玩法？` / `题目、选项和结果反馈会一起清空`. 完成奖励: `移除完成奖励？` / `优惠券和勋章设置会一起清空`. 剧情故事: `移除剧情故事？` / `剧情节点和配图会一起清空`. Confirm button `移除`. |

## A12 · Preview (`查看预览`) and save flows

**Preview** is a full-screen dark layer, five swipeable steps with a segmented progress bar and the line `<步骤名> n / 5`: `到达节点` → `剧情解锁` → `节点任务` → `任务完成` → `获得奖励`. Bottom: round `‹`, `n / 5`, round `›`.
1. 到达节点: cover image, `你已抵达`, the title, the difficulty (`未设置难度`), the description.
2. 剧情解锁: one block per story beat (label `时刻 N` or the author's tag, images, text), button `继续`.
3. 节点任务: the real gameplay screen, full screen or as a card inside a story-flow mock with `继续故事` under it; a round `‹` at top left exits; a verdict overlay (win / lose with the author's feedback text and images); toast `试玩只看样子，不判对错`. Legacy methods render a simple card instead: method chip, prompt (`请回答下面的问题` / `请选择正确答案` / `拍下你在现场的照片` / `扫描现场的二维码` / `走到目标位置` / `点击下方按钮完成打卡`), the input, `需要提示？`, and a submit button (`提交答案` / `上传并完成` / `完成扫码` / `我已到达此处` / `完成打卡`); wrong answer line `回答不正确，再试一次`.
4. 任务完成: check mark, `任务完成!`, `你解开了这个节点的秘密`, button `领取奖励` or `完成`.
5. 获得奖励: `获得奖励`, coupon card (`券`, name, `到店核销`), medal card (image or `章`, name, `已收入你的成就墙`), feedback text card, or `未配置奖励模块`.

**Save flows**
- `保存草稿`: no validation beyond shape; result sheet `模板草稿已保存` / `可以随时回到模板库继续编辑。`; closes to the template library after 2 s. From a topic or city node it is replaced by the toast `节点玩法请配置完成后直接保存`.
- `发布玩法`: full validation (A1.9). Success result sheet `节点玩法已发布` / `已进入你的模板库，可以用于新的城市路线。` with a meta pill `预计 N 分钟`.
- `保存并绑定` (from the topic editor): success sheet `节点玩法已保存` with two actions `返回路线编辑` / `继续编辑玩法`.
- `保存玩法` (city node): toast `玩法已保存`, returns. Blocked staff: `当前岗位没有节点管理权限`.
- Failure keeps everything and shows A1.10.

## A13 · Frames to draw for Part A (build list)

Draw on a new section "temp · 节点玩法模板编辑" next to `94:4659`. 393 × 852 first screen plus a full-height frame where the content is longer.

| # | Frame | Covers |
|---|---|---|
| 1 | Editor, new, nothing chosen (full) | A2 items 1–6 empty, 19, 20 |
| 2 | Editor, 选项问答 filled (full) | A4.3, A5, A6.1, A8, A10 rows |
| 3–5 | States: sign-in, loading, two more load errors | A1.1, A1.2, A1.4, A1.5 |
| 6 | Validation errors | A1.9 |
| 7 | Save failed | A1.10 |
| 8 | Leave alert | A1.12 |
| 9 | 选择玩法 sheet × 4 categories + one disabled row | A3 |
| 10–43 | One 玩法设置 card frame per gameplay (card only, 361 wide, on the page background) | A4.1–A4.34 |
| 44 | 找东西 flow × 4 | A4.18 |
| 45 | D20 check × 4 (default, configured, luck open, bargain on) | A4.24 |
| 46 | 结果反馈 open + 消耗与效果 sheet + 添加效果 layer | A5, A11.4 |
| 47 | 提示 ladder × 3 | A6.1 |
| 48 | 反馈分段 | A7 |
| 49 | 完成奖励 with coupon + medal | A8 |
| 50 | 互动工具 picker + 11 tool sheets | A10 |
| 51 | 扫完回复 sheet × 4 kinds (+ AR × 3 modes) | A11.3 |
| 52 | 添加模块 sheet, picker sheet | A11.1, A11.6 |
| 53 | Preview × 5 steps + verdict | A12 |
| 54 | Result sheets × 3 | A12 |
| 55 | Legacy template state (old cards + 旧设置 list) | A4.36, A6.2, A9 |

---

# Part B · Topic editor (`/pages/publish/fabu/index`)

**Status in Figma: PARTIAL.** Drawn: the 创作 page with three chapters (`91:658`, full `91:789`, twins `171:5929` / `171:6054`), the same page as the plain "category" capture (`91:907`, twin `171:6166`), the category sheet (`116:2263`, twin `188:5698`), the empty draft (`91:1038`, twin `171:6496`) and the new-topic entry (`94:5473`, twin `171:6575`). Prototype copies: `204:16277` tenew, `204:16341` teedit, `204:16450` tecat, `204:16605` tedraft. **Nothing else exists**: no story-flow editor, node sheet, chapter settings, topic detail sheet, mode picker, ticketing page, ticket editor, publish preview, or any of the ~20 nested editors.

**Sources read**
- `fabu/index.wxml` (2,034 lines, all), `topic-detail-sheet.wxml`, `step3.wxml`, `look-sheet.wxml`, `runtime-editor.wxml`, `runtime-structure-editor.wxml`, `survival-editor.wxml`, `zero-hp-editor.wxml`
- Components: `story-rule-editor`, `topic-state-keys`, `d20-settings`, `reward-selector`, `ai-assist`, `attribute-binding-editor`, `location-todos`, `collaborator-picker`, `look-preview`, `start-prep`, `creation-success`, `chapter-gate`, `choice-sheet` (the generic row, group, stepper, segmented and swipe wrappers were not opened)
- `fabu/index.js` (10,194 lines: constants, every user-visible string by method), all `fabu/theme-*.js`, and `utils/publish/`: `publish-validation-bag`, `pro-editor-policy`, `pro-editor-story`, `story-rule-sentence`, `story-rule-form`, `story-vocabulary`, `story-ending`, `story-initial-state`, `theme-look`, `location-todos`, `server-draft`
- Captures: INDEX rows 48, 49, 50, 56
- Owner reference: **TE · Screens** `ku2oaN9ag1XUMC9lKNnrcr` `4843:13332`: rows 玩家 `4890:14114` (P1–P12), 俱乐部 `4890:14115` (C1–C12), 商家 `4890:14116` (M1–M12), all component states `4896:15484` (S1–S42), proposals J1–J7 `5220:18855`, publish confirm `S38 4960:19158`.

**How to combine TE and code.** The TE screens set the look (white cards radius 20 on `#F3F4F4`, round 40 icon tiles, grey pill actions, black pill primary, a left grey ✕ and a right black `完成` on sheets). The code on `integration/backend-app-r3` is newer in three places and sets structure and copy there:
1. **Story-flow editor**: TE P7 / P8 use insert seams (`＋` between blocks) and a bottom `下一步`. The code implements "编辑器原型 v2" (owner-approved 2026-11-10): a top add bar, article-style text, drag to reorder, no bottom button. **Open question Q1: which one does the owner want drawn?** The specs below follow the code and name the TE frame for the look.
2. **Node sheet**: TE P9 has three cards (地点 / 配置模板 / 照片). The code (prototype A, 2026-10-28) is a grouped list with `取消 · 编辑节点 · 完成`.
3. **Sheet headers**: owner ruling 2026-10-10 in code: every editing header is `退出` left, `完成` right (text buttons). TE shows ✕ and a black pill.
Three publisher roles (player / club `?clubId=` / merchant `?scope=MERCHANT`) share every screen; differences are called out inline.

## B1 · Page states and system dialogs

| ID | State | Status | Spec |
|---|---|---|---|
| B1.1 | Sign-in required | MISSING | Empty state, title `登录后创建主题`. |
| B1.2 | Loading an existing topic | MISSING (TE `S14 4897:16169`) | Centred spinner, `加载中`. |
| B1.3 | Load failed | MISSING (TE `S15 4897:16211`) | Error title `这份主题加载失败` (access: `当前请求无法读取主题`), reason (`网络暂时不可用，主题未加载` / `主题内容不完整，请重试` / `主题未加载`), and a **full-width black pill pinned to the bottom**: `重新加载`. |
| B1.4 | New topic, empty | PRESENT `94:5473`, `91:1038` | B2 with the empty chapters card. |
| B1.5 | Editing with content | PRESENT `91:658` / `91:789` | B2. |
| B1.6 | Local draft restored | MISSING | Toast `已恢复上次本地草稿` or `已恢复上次未编排完的 N 个素材`. |
| B1.7 | Draft conflict | MISSING | Alert, title `另一端草稿已更新` (or `上次发布结果待确认`), body `其他设备上的草稿已更新，是否用本机草稿覆盖？` (or `是否保留本机草稿，或使用当前已保存版本？`), buttons `使用已保存版本` / `使用本地草稿`. |
| B1.8 | Leave while unsaved to device | MISSING | Alert `草稿还没有保存` / `本机存储空间可能不足，直接返回会丢失本次修改。` / `继续编辑` · `仍要返回`. |
| B1.9 | Locked fields after approval | MISSING | Alert `这些改动存不下来` / `主题已过审开卖，开始/结束日期、章节节点结构、票种与价格都不能再改了。` + `要改这些只能先下架 → 退款 → 重发。其余文案与图片的修改可以正常保存。` / `知道了`. |
| B1.10 | Save / publish failed | MISSING (TE `S16 4897:16253`) | Red inline block above the bottom bar: title `这次还没有保存`, reason line; under it a disclosure `为什么会这样` that opens to `修改后重试` or `草稿已存本机，可稍后重试`. |
| B1.11 | Undo bar | MISSING (TE `S18 4897:16360`) | A dark pill above the bottom bar for 5 s: `节点已移到待编排区` + `撤销`. |

## B2 · 创作 page (page 1)

Top to bottom (capture 048; TE `P2 4857:13672`, `M2 4890:14382`):
1. Floating round back button (40, white, shadow) at top left. No nav title.
2. **Topic name**: large multi-line title field, placeholder `未命名主题`; wraps instead of truncating. A red `*` sits before it while empty or invalid (the twins already removed the star per TE).
3. **Save-state chip** under the title (grey pill; green tint when saved): one of `已存本机` · `本机未存` · `保存中` · `已存云端` · `云端未存` · `待确认`.
4. **主题详情** card (whole card taps to B7): title `主题详情`, sub-line in red `* 还有 N 项未填` (hidden when complete), chevron.
5. Two cards side by side:
   - 模式: flag icon tile, eyebrow `模式`, value `城市定向` or `自由探索`, action `切换 ›` → B3. Merchant role: plain text `商家发布固定`, no chevron, not tappable.
   - 票务: ticket icon tile, eyebrow `票务`, value `票务设置`, then `编辑` or, when incomplete, red `* 还有 N 项未填`. Opens page 2 (B8).
6. `地点待办` row (only on topics adopted from a template): title + `N 个地点` + chevron → B10.4.
7. Section title **章节**.
8. Empty state card (capture 050; TE `P1 4857:13772`): grey round tile with a solid pin, `还没有章节`, black pill `＋ 创建章节`.
9. **待编排区** (only when loose materials exist; TE `S17 4897:16295`): section title `待编排区` + `N 个素材尚未进入章节`, optional text button `继续录入地点`. One white card per material: 48 thumbnail (or image placeholder), tag `地点素材` / `节点素材`, name (`未命名素材`), description (`待补文字说明`), status chip `地点已配置 · 待归章` or red `待选地点 · 不能发布`, a trash icon at top right, and three actions: `补内容`, a dropdown `选择章节与插入点` (自由探索: `放入已有章节`), `新建章节并编排` (自由探索: `新建章节并放入`).
10. **Chapter cards**, one per chapter.
    - Header row (tappable → story flow): `第一章 · 钟楼与邮局` + chevron. Ending chapters show their own name only.
    - Chips: `✓ 剧情已写` (green) or `缺剧情` (red); `2 节点`; `N 个待选地点` (red); `玩法 1/2` when some nodes lack gameplay.
    - 自由探索 adds a line: `已开放承接 · <品类 or 待选择商家品类> · N 家可承接` (or `名额不限`), or `未开放商家承接`.
    - Hairline, then two buttons: 城市定向 = black `编辑故事流` + grey `编辑章节`. 自由探索 = the node list (below) and then grey `编辑章节` + black `＋ 创建节点`.
    - **自由探索 node rows** (fixed height, **long-press the number to drag and reorder** within the chapter; the other rows freeze while dragging): number badge (tap = locate on the map), 48 photo slot (`＋ 照片`, badge `共N张`), name (`添加地点`), address (`选择地点`), and a `⋯` button that opens the node sheet.
11. Bottom of list: dashed full-width `＋ 添加章节` and, for 城市定向, a grey pill `添加序章`.
12. **Bottom bar** (fixed): left, two view icons `列表` / `地图` with a dot under the active one; right, grey pill `保存草稿` (only for unpublished drafts; label `保存中...` while saving) and black pill `下一步 →` (always enabled; goes to page 2).
13. **Map view** (TE `S19 4897:16425`): the top ~45% becomes a map with numbered pins and a route line; a dark-to-clear scrim protects the status bar; the content becomes a bottom sheet. Tapping a pin on a story topic toasts `已定位到故事流，请点节点卡编辑`.

Frames still to draw for B2: 自由探索 variant with node rows (TE `S21 4897:16468`), drag-in-progress, 待编排区, map view, club empty state (TE `4899:17620`), error block, chapter with red chips (TE `S3 4896:15616`).

## B3 · 主题模式 picker — MISSING (TE `P3 4871:14688`)

Half sheet. Header `退出` / `使用此模式`. Title `主题模式`, subtitle `这个主题怎么玩？`. Two option cards with a radio dot: flag icon `城市定向` / `固定集合时间与地点`; explore icon `自由探索` / `有效期内自由前往`. Footnote `切换后另存为新草稿，原稿保留`. Confirming asks: alert `复制为新草稿？` / `当前草稿会保留不变；将复制一份并切换主题模式。` / `复制并切换`. After copying, a notice may list what must be re-chosen: `复制后需要重新选择：…` / `知道了`.

## B4 · 故事流编辑器 (story-flow editor, 城市定向 only) — MISSING

Full-screen layer over the page (TE look: `P7 4850:13495`, `P8 4850:13592`, states `S4`–`S6`, `S22`–`S24`, `S37`).

**B4.1 Top bar**: left `草稿 · <保存状态>`; right text buttons `预览` and `完成`, then a `⋯` menu (`章节设置` → B6, `退出编辑`).

**B4.2 Add bar** (sticky under the top bar; six icon + label buttons): `段落` · `图片` · `音频` · `玩法` · `分支` · `分割线`. Each inserts at the cursor. Toasts: `已添加段落`, `已添加图片`, `已添加音频`, `已添加分割线`, `已添加分支任务`.

**B4.3 章节开始 card** (fixed first, not draggable): cover slot (`添加封面`; filled shows the image with a ✕), eyebrow `章节开始`, a small `预览弹窗` link, field `章节名称` (30), field `开场白:玩家进入本章先看到的话` (500).

**B4.4 Blocks** (each non-text block has a grip at the left; tap the grip for a menu `上移` / `下移` / `删除`; long-press and drag to move; a selected block shows a ✕ or trash at its top right):
| Block | Look and fields |
|---|---|
| 段落 text | Borderless auto-growing text; first block placeholder `开始撰写`. Styles: plain, bullet `•`, numbered `1.`; inline marks. Enter or paste splits paragraphs. Deleting asks `删除这段文字？` / `前后的文字块会保持原样，不会自动合并。` |
| 图片组 gallery | 1–4 cells in a fixed layout; empty cell says `选图`; caption field `图片说明` (200). |
| 音频 audio | Empty: a tall grey box with `▶ 上传音频`. Filled: play button, file name (`音频片段`), duration `45″`. |
| 分支任务 branch | Card: turn icon `分支任务`, links `编辑` and `预览`; the question (`写一个问题`); rows `A <选项> → <去向>`. Tap opens B4.7. |
| 相册 dream | Title field `相册（不填就叫相册）` (20), counter `n / 6 张`; rows of thumbnail + one-line field `这一张的一句话` (40) + delete; `＋ 加一张`; empty warning `一张都没有的相册不会保存，先加一张。` |
| 伏笔 thought | Chip row: `伏笔` + the name (dropdown to change). |
| 内心声音 voice | `内心声音` + who (dropdown: 规矩 / 窗外 / 心 / 精密 / 咔哒), field `它说了什么` (200), condition chip `所有人都听得到` or `有条件`. |
| 反转 reveal | `反转`, field `对面是谁(可空)` (20), textarea `对面回的话，一行一条` (500). |
| 文字效果 odd | `文字效果` + level dropdown: `0 · 正常` / `1 · 字偶尔闪` / `2 · 褪色错位` / `3 · 等宽字、声音改名`. |
| 氛围 mood | `氛围` + palette dropdown: 黑 / 蓝 / 红 / 黄 / 白. |
| 分割线 divider | A hairline. |
| **节点 node** | Number badge, 56 thumbnail (or image placeholder), name (`未命名`), second line `<地址> · 玩法已配` / `· 玩法待配` or `点击选择地点`; a role dropdown at the right: `计入完成` (default) / `额外节点 · 单独额度（…一次）` / `额外节点 · 与「…」共用（…共一次）`. Tap opens the node sheet B5. Selected shows a trash; deleting asks `确认删除节点` / `删除后 5 秒内可以撤销，过后不可恢复。` |

A helper strip appears when a loose material was chosen for placement: `待编排节点已选，请把光标放到要插入的位置，再点「地点」`.

**B4.5 章节结束 card** (fixed last): eyebrow `章节结束`, `预览弹窗` link, field `结语:本章完成时弹窗里的话` (500), read-only row `去向 · 下一章 · 第 2 章` or `结束主题`.

**B4.6 Drag and drop** (the only true reorder on these pages): the lifted block shows a shadow; dropping between blocks moves it (toast `已移到第 N 位`); dropping inside a paragraph splits it and shows the paragraph as "upper half · slot · lower half" while dragging (toast `已插到第 N 段中间,段落拆成两段`). After any move, insert, delete or split, an undo pill shows for 5 s: text + `撤销` (toast `已撤销`).

**B4.7 Sheets inside the editor**
- 图片 layout sheet: title `图片` + ✕; four layout tiles `单图` / `双图` / `三图` / `四图`.
- 分支任务 sheet: title `分支任务` + ✕; `问题` field (`玩家在分支点看到的问题`, 200); `分支`: 2–3 rows, each a letter badge, field `玩家看到的选项` (40), a remove ✕ when more than two, and `去向` chips: `继续本章` / `结束本章` / `跳到第 N 章`; `添加分支`; link `预览玩家看到的分支弹窗`.
- 插入变量 sheet: title `插入变量` + ✕; rows of a token (`{name}`) + label; empty text `这个主题还没有可用变量：先在某个节点的玩法里配「角色建档」或「作品命名」，它们的答案才能被写进故事。`
- **玩家端弹窗预览**: darkened chapter cover; ✕; caption `<风格> · <阶段>`; a centred pop-up card (kicker, optional mark icon, title, body, meta, options `A …`, CTA) tinted by the theme style; bottom controls: stage chips `主题开始` / `章节开始` / `章节结束` / `玩法开始` / `玩法结束` / `分支选择` (玩法结束 adds `成功` / `失败`), style chips, and `主题配色` swatches. Sample copy the code generates: `城瘾 · 城市剧情` / topic name / `3 章 · 约 2 小时` / `开始`; `第 1 章` / chapter name / `进入本章`; `本章完成` / `下一章`.
- Node narrative sub-page (自由探索 only): back, title `文字说明`, node name + chapter name, large textarea `添加文字说明` (2000), button `完成`.

## B5 · 节点编辑 sheet — MISSING (TE `P9 4871:14211`, `S7`, `S8`, `S25`, `S35`)

**B5.1 Detail view.** Header `取消` · `新建节点` / `编辑节点` (story game: `新建玩法` / `编辑玩法`) · `完成`. Grouped list:
1. Group: `名称` (inline field, `给这个节点起个名字`, 40) · `地点` (value = place name or address, chevron; opens the map picker: drag the map under a fixed centre pin, hint `拖动地图对准位置后确认`). Coordinates are never shown.
2. Group (hidden for AI simple drafts): `玩法` switch row; when on, `玩法模板` row with the bound template's name and chevron → B5.2.
   - If the bound template is shared: grey block `此玩法用于 N 个节点` with the node names, a button `仅为本站另存副本` (`正在另存…`), and a blue row `修改原模板 · 影响 N 个节点 ›`.
   - Support reason line when the gameplay cannot be used here (grey).
   - `对应主题资源`: one row per resource the template needs: `<名称> <数值 / 物资>` + a dropdown pill with the mapped theme resource, or `请先启用主题资源`.
   - `方案对应的结局`: one row per vote plan: `<方案> 方案通过并执行后进入` + dropdown `选择结局`.
3. Group: `到达与引导` (chevron → B5.3) · `下一站` (城市定向, saved nodes only; value `下一站 N 条`; → B5.4) · `照片` with counter `n/9`, expanding to a photo grid with a `＋` cell (limit 9: `每个节点最多9张`).
4. 自由探索 only: `文字说明` card with a textarea `玩家到这里要观察、寻找或完成什么？` (500).
5. Red text row `删除节点` (existing nodes). Confirm: `确认删除` / `节点会移到待编排区，5 秒内可以撤销。`
Errors on 完成: `请填写节点名称`, `玩法详情未加载，请稍后再完成节点`. Results: `已插入故事流`, `节点已更新`, `地点待补，已移到待编排区`.

**B5.2 玩法模板 view** (same sheet, pushed; TE `P10 4868:14344`, `S9 4896:15960`). Header `返回` · `玩法模板`. Fixed bottom button `确定`. Three lists, one row per template (56 thumbnail, title, `<人数> · <时长>分钟`, optional reason, a source tag, a check when selected):
- `公共模板` (tag `公共`): states `加载中…`, `暂无公共模板`, error `公共模板加载失败`.
- `我的故事玩法草稿` (tag `草稿`; reason suffix `（通用结算）`).
- `我的模板` (tag `我的`): first row `＋ 自己建一个` → opens Part A with `from=fabu`.
Errors: `请先选择一个模板`; adoption messages such as `已存为我的玩法草稿并绑定`, `采用结果待确认；再次选择此玩法将查询原请求，不会另建请求`.

**B5.3 到达与引导 (arrival rules)** — sheet-nav title `到达与引导` (TE proposal `J4 5221:19075`).
- Group: `到达地点` dropdown (`选择本主题节点`, or an existing shared place) · `工作人员引导答题` switch (needs an objective-question gameplay: `请选择已有客观题玩法；引导使用该玩法原有题目和答案`).
- Group `找不到时换个方式`: three switch rows `扫码` / `答题` / `拍照`. 答题 on → `题目` + `答案` fields; 拍照 on → `拍摄内容`; 扫码 needs a configured code (`扫码尚未配置有效码，请先完成扫码配置`).
- Group: `备用节点` (expandable checklist of the theme's other saved nodes, max 20; empty: `请先保存其它节点`).
- Errors: `请填写题目和答案`, `请填写拍摄内容`, `最多选择 20 个备用节点`, `先点「完成」保存这个节点，再设置到达与引导`, `归零挑战站不设置到达与引导`.
Schema: `arrivalPolicy`, `arrivalReading` (fallback modes: 4 values in `x-cy-enums.arrivalFallbackMode`).

**B5.4 下一站 (route mapping, with conditions and effects)** — sheet-nav title `下一站` (TE `S36 4932:18205`, `S24`).
- Subtitle: the bound template's name. One row per result of this node (`节点完成结果`, or each named outcome): label + target (`继续故事流` default, `故事流结束`, or a node) + chevron. Opening a row shows, in place: `去往` (expandable checklist of targets) and the **rule editor**:
  - Group `条件`: optional segmented `条件怎样算满足` (`全部满足` / `任一满足`). Each condition is one sentence row, e.g. `线索 · 签收联`, `到过节点 · 钟楼 至少 1 次`, `检定结果 · 通过`, `一组条件 · 任一满足 2 条`. Opening a row shows editors as needed: segmented `肯定或否定` (已获得 / 未获得, 带着 / 没带, 装备着 / 没装备, 有 / 没有, 完成过 / 没完成过), a name list, `换一个名字`, segmented `检定结果` (通过 / 未通过), segmented `比较` (至少 / 至多 / 正好 / 多于 / 少于 / 不是) with a stepper (`次数` or `数值`), and red `删除`. Nested groups show `这一组怎样算满足`, `添加条件`, `删除这组条件` (max 10 per group, 3 levels).
  - `添加条件` pushes a layer: kinds `已获得线索` · `装备着物品` · `有标签` · `有特质` · `属性` · `进度钟` · `数值` · `到过节点` · `完成过节点` · `检定结果` · `一组条件`; a kind expands to a search field and names (`没有找到` / `还没有可选的名字`).
  - Group `效果` with a header action `编辑` / `完成`: in edit mode each row shows **up / down arrows** to reorder. Sentences: `获得线索 · …`, `给物品 · …`, `装备物品 · …`, `卸下物品 · …`, `加上标签 · …`, `加上特质 · …`, `去掉特质 · …`, `进度钟 · …`, `<属性/数值> 增加 / 减少 / 设为 N`, `给探索值 N`. Editors: segmented `怎样改`, `换一个名字`, stepper (`数量` / `格数` / `数值`), `删除`. `添加效果` kinds: 获得线索 · 给物品 · 装备物品 · 卸下物品 · 加上标签 · 加上特质 · 去掉特质 · 进度钟 · 属性 · 数值 · 给探索值.
- Footer row: `其他结果` + the fallback target.
- Errors: `<结果>：有一句还没选完`, `<结果>：请先选择下一站，再保存条件与效果`, `请先保存节点`, `请先重新选择玩法模板`.

## B6 · 章节设置 sheet — MISSING (TE `P6 4868:14231`, `J3 5221:19016`, `S23 4937:18230`)

Header `退出` · `添加章节` / `编辑章节` · `完成`. Fields in order (城市定向 unless noted):
1. `章节名称*` field (30). Error `请输入章节名称`.
2. `章节奖励` field `选填` (24) — not on prologue or ending chapters.
3. 自由探索 only: `章节剧情 · 选填` textarea `这一章讲什么？（选填）`.
4. `完成要求`: dropdown pill `全部完成` / 至少完成几站. When "any N": `至少完成几站` number field (`填写站数`) and a dropdown `超出后补做一站` (`不允许` / `单独额度（…一次）` / `与「…」共用（…共一次）`).
5. `章末配给`: switch + status (`已开启` / `不消耗物品`), a grey reason when unavailable (`请先选择进行方式` / `本章节点还没有绑定玩法` / `请先保存本章节点` / `请先在主题里添加物品`). On → dropdown `消耗物品`, number `每次数量`, dropdown `物品不够时减少` (a theme value), number `减少数量`.
6. `章末消耗`: rows `<数值名>` + number + `移除`; dropdown button `＋ 添加章末消耗`.
7. `互斥选项`: groups `第N组` + `移除`, each a wrap of node chips to toggle (min 2 per group); `＋ 添加互斥组`. Toasts `请先保存本章至少 2 个节点`, `该节点已在其他互斥组`.
8. `章节音频`: empty `＋ 添加音频`; filled: `预听` / `暂停`, file name (`章节音频`), duration, delete.
9. Prologue / ending only: `开场视频` / `结尾视频` with `＋ 添加视频` / `更换视频` and `移除`. Limits as messages: `请选择 mp4 视频`, `视频不能超过 30 秒`, `视频不能超过 10 MB`; success `视频已提交审核，通过后可发布`.
10. `章节配色` (when the theme has no global look): five swatches 黑 (石墨) / 蓝 (晴空) / 红 (落霞) / 黄 (暖杏) / 白 (珍珠); the note shows under the selected one.
11. Rows (first chapter only): `初始状态 · 第一章开局数值配置 ›` → B7.12; `背包 · 配置 ›` → B7.10; `途中彩蛋 · 配置 ›` → B7.11.
12. `由工作人员开幕` switch with a lock icon; sub-line `工作人员确认后，队伍才能开始本章` / `本章开始即可进行` or a disabled reason (`个人独立进行不能设置工作人员开幕`).
13. `设为结局` switch (not on the prologue). On → `什么时候播` dropdown: `默认（其它结局都不满足时）` / `某个伏笔应验了` / `选过某个选项` / `到过某个节点`, then the matching dropdown: `哪个伏笔应验` (`还没有伏笔，先到主题详情里埋一个`), `选过哪个选项` (`还没有记住选择的选项，先到玩法里打开「记住这个选择」`), `到过哪一站` (`还没有保存过的节点`). Errors: `结局章里不能放节点或玩法`, `结局章不能开放商家承接`, `要恰好一个默认结局…`.
14. `商家承接` (club host or merchant; mainly 自由探索): switch `本章开放商家承接`. On → `商家品类*` row (`请选择类别`, pill `选择品类`), `承接条款*` segmented `给权益` / `只引流` / `俱乐部计酬` (club topics only), then `权益门槛 (¥)` (`不限`) or `计酬上限 (¥/人次)*` with the note `俱乐部直接付款` (`请输入`), and `名额上限 (家)` (`不限`). Errors: `请选择适合商家的招募品类`, `请选择平台条款档`, `商家名额填 0 到 127 的整数`, `权益门槛请输入大于0的金额`.
15. Red `删除章节` (existing chapters, not when opened from the story editor). Confirm `确认删除章节` / `删除后不可恢复。`
A follow-up alert can appear on save: `还差一步` / `…要重新打开玩法，点一次保存，才能和这一章的设置一起用` / `知道了`.

## B7 · 主题详情 sheet and everything under it — MISSING (TE `P4 4864:14623`, `P5 4871:14323`, `S11`, `S32`–`S34`, `S40`, `S41`, `J1`, `J2`)

Full-height sheet. Header `取消` / `完成`. Large title = the topic name (`未命名主题`). White cards, each row: 40 round icon tile + title / sub-line + a grey pill at the right.

| # | Row | Control and copy |
|---|---|---|
| 1 | 主题描述* | Inline field `填写主题描述` (20) with an edit icon. |
| 2 | 主题类别* | Pill `选择类别` or the chosen names → B7.1. |
| 3 | 竖版封面* | Pill `上传 3:4` → `已上传` with a thumbnail and `删除`. Error `请上传主题封面`. |
| 4 | 横版封面 | Pill `上传 16:9`; thumbnails with ✕ below. |
| 5 | 主题配乐 | `＋ 上传` / `更换`, `移除`. |
| 6 | 画面风格 | Sub-line = summary; pill `选择` → B7.2. |
| 7 | 剧情详情* | Textarea `写下这个主题的故事…` (1000). Hosts the `AI 助写` strip (B10.5). |
| 8 | 伏笔 | Sub-line = the foreshadow's name; pill `添加` / `编辑` → B7.3. |
| 9 | 玩法支持 note | Grey text: `支持状态以玩法支持矩阵为准。反馈或工单是独立渠道，提交后不会改变支持状态。` |
| 10 | Values group | Rows for `生命值`, `幸运值`, `行动次数` (custom names allowed) with a switch each and a summary `已启用 · 玩家可见 · 0 至 N` / `未启用`, pill `编辑`. Expanding shows `显示名称` (20) and `上限`. 生命值 adds a row `归零后 · <摘要> ›` → B7.5. Then custom values: `<名称> 已启用 · 玩家可见 · 0 至 10` + switch + `编辑` → B7.4; `＋ 自定义整数值 · 添加`. Switch `没有实际效果时也消耗` with the explanation `数值已满时使用恢复，仍扣费用并计一次` / `…不扣费用、不计次数`. |
| 11 | 进行方式 | Summary; pill `选择` → B7.6. If shared-world: switch `队伍之间可以交换物资` and dropdown `表决方式` (`过半数` / `全体同意` / `过半接受（平票可复议）`). |
| 12 | 结果卡 | Summary (`默认` / `已自定义`); pill `配置` → B7.7 card section. |
| 13 | 允许再玩一次 | Switch. Error `队伍玩法不支持个人重玩，请关闭再玩一次`. |
| 14 | 同场路线 | Switch. |
| 15 | d20 检定 | Switch; on → row `d20 与角色设定 · <N 项属性> ›` → B7.8. |
| 16 | Legacy note | `旧版配置仍按原样运行` + summary (old topics only). |
| 17 | 可玩时段 | Value `不限` / `只在白天` / `只在夜间` / `自定义` → dropdown; custom opens a small sheet `可玩时段` with `开始` and `结束` time fields and `完成`. Hidden for club topics. |
| 18 | 开局前准备 | `N 项` / `未设置` → B7.9a. |
| 19 | 主题通关奖励 | `配置 ›` → B7.9b. |
| 20 | 通关条件 | Switch (城市定向); on → sentence `完成 [N] / 6 个节点即通关`. Errors `必达数不能超过节点总数` (TE `S11`). |
| 21 | 宾果九宫格 | A 3 × 3 mini grid preview, `配置` → B7.9c. |
| 22 | 发布到创意广场 | Switch. |
| 23 | 归属俱乐部 | Dropdown of my clubs, `未选择` (only when the user hosts clubs). |
| 24 | 线索与物品 | Row `线索与物品 · N 项` → B7.13; before the first save: `线索与物品保存为主题后，才能在这里添加线索与物品。` |
| 25 | 清空本地草稿 | Red text at the very bottom. Confirm `清空本地草稿？` / `当前未发布的章节和待编排素材都会从本机删除。` / `清空`. |

**B7.1 选择主题类别** — PRESENT `116:2263` (twin `188:5698`, TE `S31 4898:17183`). Title + ✕; a list of categories with check marks; footer `已选择 N 个` + black `保存选择`.

**B7.2 画面风格** (TE has no frame; build from code). Header `关闭` / `完成`, title `画面风格`.
- Four style tiles with a live sample: `星尘` · `纸本` · `末世` · `夜城`.
- Parameter chip rows for the chosen style: 星尘 → `浮尘` 稀 / 中 / 密, `飘动` 慢 / 中 / 快, `光色` 白 / 暖 / 冷. 纸本 → `纸张` 牛皮纸 / 宣纸 / 深色卡纸, `纸纹` 轻 / 中 / 重, `印章` 已核实 / 到此一游 / 朱文方印. 末世 → `天气` 晴 / 雨 / 雷暴 / 沙尘暴, `变化` 平稳 / 多变 / 剧烈, `屏幕边缘` 跟随体力 / 固定 / 关闭. 夜城 → `霓虹` 黄青 / 青粉 / 红青, `电流` 弱 / 中 / 强, `故障` 只在转场 / 关闭.
- 末世 only: one chip row per chapter (`第 1 章` …): 清晨 / 正午 / 日落 / 夜晚.
- `主题配色` swatches: 黑 / 蓝 / 红 / 黄 / 白 (note under the chosen one).
- `字体` chips: 手写 / 宋体 / 楷体 / 黑体 / 粗斜 (each drawn in its own face).
- `文字动效` chips: 跟随风格 / 浮现 / 打字机 / 墨晕 / 聚星 / 呼吸光 / 擦出 / 落定 / 风吹 / 信号 / 雾散 / 霓虹点亮 / 扫描 / 解码.
- Related sheet `look-preview`: a phone-frame sample (kicker, title, story text, option A) with buttons `看转场` and `使用这个风格`. Transitions list: 跟随风格 / 淡出 / 光圈 / 翻页 / 擦除 / 百叶 / 像素 / 跃迁 / 风刮 / 调频 / 故障 / 电流 / 墨晕 / 幕布 / 推近.

**B7.3 伏笔**: header `退出`, title `伏笔`. One card: field `步数*` (`输入步数`, 1–100000), textarea `输入文字*` (`输入伏笔文字`, 60), button `删除伏笔`; warning when old data has several: `只能配置一个伏笔，当前旧配置包含多个`; bottom button `完成`. Errors `请输入伏笔文字`, `请输入步数`, `正文或结局仍引用这条伏笔，请先移除对应引用再删除`.

**B7.4 自定义数值 editor**: header `退出` / `完成`, title = the value's name. `名称` field (24) + switch `玩家可见`; group `范围`: steppers `最小值`, `最大值`; group `关联`: switch `下降时一起扣生命值`; red delete row. Errors `数值名称须为 1 至 24 字`, `请先移除引用：…`.

**B7.5 生命值归零后**: header `退出` / `完成`, title `生命值归零后`. Dropdown `归零后` (two columns; unavailable options carry a reason): `仅禁止扣该值的任务` (其他任务仍可参与) · `主题失败` (本次主题结束) · `完成恢复挑战` (完成指定节点后恢复) · `走够步数` (达到恢复步数后恢复) · `等待一段时间` (等待指定分钟后恢复).
- 完成恢复挑战: row `用哪个节点的玩法` (dropdown of eligible nodes; empty text `请先保存主题和挑战节点，才能选择挑战节点。`), `备选节点（最多 3 个）` chips (`添加 · <节点>` / `已选 · <节点>`, with a reason when ineligible), grid `需完成几次` · `限时（秒）`, grid `恢复到` · `最多恢复几次`, dropdown `次数用完后` (`主题失败` / `仅禁止扣该值的任务`).
- 走够步数: `走够步数`, `恢复到`, `最多恢复几次`, `次数用完后`, note `以归零后第一次同步的微信运动步数为起点累计。` (the app uses HealthKit; reword).
- 等待一段时间: `等待（分钟）`, `恢复到`, `最多恢复几次`, `次数用完后`.
- All: textarea `归零时对玩家说` (`例如 你冻得发抖，先暖和过来再走`, 2000). 主题失败 shows the note `本次游玩结束，按主题「结果卡」显示失败结果。`
- Old topics: read-only line `旧版归零设置 … · 只读，保存时原样保留`.
- Errors: `体能或传感器主挑战须配题目类备选挑战`, `最多选择 3 个备选挑战`, `等待分钟须为 1 至 10080 的整数`, `恢复步数须为 1 至 100000 的整数`.

**B7.6 进行方式**: header `退出` / `完成`; title `进行方式`, subtitle `队伍怎样一起玩？`. Three radio cards with icon, name, and description: `个人独立进行` (每人独立完成任务、支付资源；不使用工作人员开幕或跨队交易、表决。) · `队伍独立进行` (同队共用任务进度和资源，各队分别完成；工作人员可开幕、核验到达和引导答题。) · `队伍共用现场` (各队保留自己的资源，在同一现场交易、投入和表决；工作人员可开幕和引导。). A disabled card shows its reason (`请先关闭章节的工作人员开幕`, `跨队交易、表决和共享设施需要队伍共用现场`). Sibling view `运行结局`: note `队伍表决的方案执行后，按这里的结局收场。剧情结局在「剧情结局」中另行编写。`; cards `结局 N` (+ tag `默认收尾`) with `删除`, fields `名称` (`例如：成功撤离`), `结局说明` (`玩家看到的结果说明`), row `设为默认收尾 · 没有方案通过时，工作人员可用它收尾`; `＋ 添加结局` (max 30).

**B7.7 休整、配给、设施、结果卡 (survival editor)**: two levels. List level header `退出` / `完成`; item level has a back arrow and its own `完成`, delete in a red card at the bottom.
- Section `休整与救助` + `添加`: rows label + summary (`增加 2 · 最多 3 次`); empty `还没有。生命值降低后，队伍可在这里设置的休整或救助中恢复。` Item: `恢复方式` (`休整：增加数值` / `救助：恢复至下限`), number `生命值增加` / `生命值恢复到`, `最多使用次数`, `适用的幕` checklist (`所有幕` / `已选 N`; note `都不选表示所有幕都可使用。`).
- Section `幕配给` + `添加`: empty `还没有。每幕开始时消耗物品，不足时扣生命值。` Item: `哪一幕`, `消耗物品`, `数量`, `不足时扣生命值`.
- Section `设施` + `添加`: rows; generated ones read `<名称> · 由节点「…」的玩法工具生成` + `在节点中编辑`; empty `暂无设施`. Item: `哪一幕`, `次数按谁计` (`每队 / 每人` / `全场共用`), `最多使用次数`, `作用于` (`本队 / 本人` / `选择参与队伍` / `全场队伍`), `生命值变化` (`例如 2 或 -1`), `到场核验` (node or `不要求工作人员核验`), `操作节点` (`不绑定操作节点`; note `先保存主题与节点，才能选择操作节点。`), and `使用条件 · 全部满足` + `添加`: rows `条件 N` + `移除`, operator dropdown (等于 / 不等于 / 大于 / 至少 / 小于 / 至多 / 持有物品 / 曾获得物品 / 已完成节点), then an item + `数量`, a node, or a value + `数值`; empty `没有条件时，到场即可使用。`
- Section `结果卡`: cover slot `上传封面` (`不上传则用主题封面` / `点图片更换`, `移除`), `卡片上显示` checklist: 场景 / 结局 / 生命值 / 幸运值 / 行动次数 / 勋章 / 物品 / 故事 / 救助记录, switch `显示已解锁内容`, red `恢复默认结果卡`.

**B7.8 d20 与角色设定** (list-group style, with swipe-to-delete rows): `规则难度`: three preset cards with difficulty dots: `轻松` / `标准` / `硬核`. `规则`: switches `天然 20 和天然 1`, `魔鬼交易`, `动量`. `属性`: rows `<名称> … / 10`, expanding to steppers `最小值`, `最大值`, `开局值` and `删除`; an add field `属性名称` with suggestion chips 观察 / 胆量 / 体魄 / 灵感 / 敏捷 / 魅力 / 运气. Row `更多规则 ›` → second level: `进度钟` (rows expand to `名称`, `进度钟类型` 坏事逼近 / 事情进展, `格数` 4 格 / 6 格 / 8 格, `删除`; `添加进度钟`, max 6) and `特质` (rows with a description, `移除`; chips to add: 夜行者 · 受了伤 · 眼尖 · 胆大 · 手巧 · 记性好 · 被盯上了).

**B7.9a 开局前准备**: list `准备项` with swipe-to-delete; add field `添加准备项` + `添加`; `建议` rows: 手机电量充足 / 带手电筒 / 戴帽子 / 穿运动鞋 / 带水 / 和同伴约好集合地点.

**B7.9b 主题通关奖励** (TE `S40 4978:18888`): `优惠券` row (`选择优惠券` → B10.3), `勋章或物品` row with a clear action, and `通关勋章`: image slot + field `勋章名称`; read-only state shows the medal + `未解锁`.

**B7.9c 宾果九宫格**: a 3 × 3 grid of cells labelled with their names or 1–9 (defaults: 完成第 1 个点 / 完成 3 个点 / 完成 5 个点 / 一天内完成 3 个点 / 两天各来一次 / 连续两天来 / 周末来一次 / 完成 8 个点 / 中午前完成一次). Tap a cell → `编辑格子`: `标题` (`填写标题`) and `完成反馈`; back returns to the grid.

**B7.10 背包**: `＋ 添加勋章` · `＋ 添加物品`; `物品容量` number + switch `允许丢弃`; item cards: tag `勋章` / `物品` + `删除`, image slot `上传图片`, `名称` (`请输入名称`), and for items: `发放时机` (不自动发放 / 章节开始 / 章节结束), `如何使用` (展示 / 生命值 / 幸运值 / a custom value), `每件占格`, `发放数量`, and the effect value (`例如 1 或 -1`; label `<数值>变化` or `减耗数值`). Errors: `请输入物品或勋章名称`, `请上传物品或勋章图片`, `物品容量请输入 1 到 999 的整数`.

**B7.11 途中彩蛋** (**drops**; TE `S41 4978:18976`): `＋ 添加彩蛋`; cards `彩蛋 N` + `删除`: `名称`, `触发方式` (时间 / 步数) with a number labelled `章节开始后（分钟）` or `本章累计步数`, `内容`, reward rows (item dropdown + quantity, removable), `＋ 添加奖励`. Errors `请填写彩蛋名称和内容`, `请填写彩蛋触发方式与数值`, `请选择彩蛋奖励并填写数量`.

**B7.12 初始状态** (first chapter): header `退出` / `完成`; eyebrow `主题配置`, title `初始状态`. `开局带着`: chips `<名称> <线索 / 标签>` with ✕, `＋ 添加` → carry picker (header `返回` · `添加` · `添加`; search field; row `＋ 新建…` / `新建「<关键词>」` expanding to kind chips `线索` / `标签`, `名称` field, `新建`; grouped rows with check marks or `已添加`; max 32). `数值`: the registered-attribute block (`启用的注册属性`, a checklist, difference lines `…：旧配置 X；注册定义 Y`, checkbox `我确认采用这项注册定义`, buttons `确认启用与定义选择` / `重新读取注册版本` / `查看或调整注册定义`); steppers `开局生命值`, `开局幸运值`, and one per custom value (`<名称> 0 至 10`); `添加初始状态`: two cards `精力 · 游戏失败时消耗` and `幸运 · D20 失败后重掷`. Error `开局值超出当前范围，请修改后完成`.

**B7.13 线索与物品**: header `退出` / `完成`. Groups (线索, 物品 …): rows expand to `名称` field, `用在` list of places, and `删除` (disabled while in use). Per group: `＋ 添加<组名>` → inline field + `添加`. States: loading `…`, error `没有读取成功，请再试一次。`, read-only `这个主题现在不能修改。`

## B8 · 票务设置 (page 2) — MISSING (TE `P11 4871:14509`, `S12 4896:16142`; ticket editor `P12 4871:14604`, `S13 4896:16237` / `4962:19404`)

Same route, second page. Page title `票务设置`. Sections (each section title can carry a red `* 还有 N 项未填`):
1. **档期**: rows `开始日期*` / `结束日期*` (calendar icon; value `未设置` or the date; open the date + time picker sheets `选择开始时间` / `选择结束时间`: wheel columns for date, hour `09时`, minute `30分`; error `结束时间必须晚于开始时间`). When the topic recruits merchants: `招商截止日期*`.
2. **商家招商** (club hosts): switch `开放给商家承接`; when on, an info line `开放招商需要俱乐部主理人身份，发布时会再核一次`.
3. **俱乐部承接** (城市定向, no club, not merchant): switch `邀请俱乐部带队`.
4. **玩家组队**: switch `支持组队`; on → segmented `入口时机` `报名时` / `报名后`; dropdown `队伍人数上限` (2–… , default `4 人`).
5. **票务**: one row per ticket: ticket icon, name (`未命名票种`), sub-line `¥149 · 城市定向 · 20 张` (empty price: `未填票价` / `开售前定价`), pill `编辑` (`编辑中`). Dashed `＋ 添加票种` (`添加新票种`).
6. **Ticket editor** (expands inline under the list; no extra sheet): header `添加票种` / `编辑票种` + `收起`.
   - `票种名称*` (`例如：早鸟票、团体票`, 20).
   - Grid: `票单价格 (¥)*` (`0.00`; 自由探索: `开售前定价`) · `发行数量 (张)` (`100`).
   - Rows `售票开始*`, `售票结束*` (clock icon, `未设置`).
   - Sub-section `定向活动配置` (城市定向): `集合时间*`, `集合结束*`, `建议组队 (人)` (`不限`), `集合地点*` (map pick). Or `探索有效期` (自由探索): switch `与主题日期保持一致`; off → `开始日期*`, `结束日期*`.
   - Read-only row with a lock: `退款规则` + `集合时间前可全额退款；错过集合或已核销不退` (自由探索: `有效期开始前可全额退款；开始后或已核销不退`).
   - `特别提示` textarea (`例如：建议穿着运动鞋，自备饮用水…`).
   - Black button `保存票种`. Errors `请填写票种名称`, `请选择集合地点`, `请填写票价`, `价格格式错误`, `至少保留一个票价`.
   - Defaults for a new ticket: name `城市定向票` / `自由探索票`, note `集合出发，按路线完成现场节点互动。` / `全点开放，玩家可在有效期内自由安排顺序。`
7. **发布者实名** (only when required and not yet registered): fields `真实姓名` (`与身份证一致`), `身份证号` (`18 位`), a consent check, the note `修改实名请联系客服`; error block `实名没有登记`.
8. **Bottom bar**: round back button at the left (returns to page 1), black pill `预览 →` at the right (`发布中...` while publishing). If items are missing it scrolls to the first one and toasts `还有 N 项未填`.

## B9 · 剧情预览 / publish check and publish flows — MISSING (TE `S38 4960:19158`, `S26`, `S27`, `S28`, `J7 5221:19151`)

**B9.1 剧情预览 layer** (light, same language as the editor; swipe from the left edge or ✕ returns). Top bar: ✕ at the left, black `完成` at the right (**this is the publish button**; disabled while blocking issues exist).
1. Head: cover (or placeholder), topic name, mode, chips (`3 章 · 6 个节点`, `约 2 小时`, …).
2. **Blocking issues** (red rows): `<问题> · <位置>` + `去修改 ›` (tapping jumps to the field).
3. **Advisory issues** (amber rows, same layout; do not block).
4. Description text.
5. `票务` rows: `档期`, `售票`, each ticket (`未命名票种` · `免费` / `开售前定价`); a flagged row is red.
6. `主题设置` rows with icons and chevrons: `模式`, `通关规则` (`完成全部节点` / `完成任意 N 个节点`), `组队` (`支持 · 最多 4 人` / `不支持`), d20 summary.
7. `发布后的合作`: rows with a note and a switch, a lock, or the tag `必须`: `俱乐部承接` (`必须先邀 1 家俱乐部承办才能开售`), `商家承接` (`每一站按档位邀商家（权益 / 计酬 / 引流）`); merchant note `商家发的城市定向只能自己带，不能邀俱乐部和商家`; locked note `主题已过审，合作设置不能在内容编辑器中修改`.
8. `画面风格`: rows `风格`, `主题配色`, `每章时间`, `字体`, `文字动效`; style tiles and palette swatches are tappable here too.
9. `剧情`: one row per chapter (number, name, meta `2 站` or a red flag), then a button `阅读剧情`.
10. Medal row: star icon, `通关勋章` + name.
**阅读剧情 pop-up** (light): title `剧情` + ✕; per chapter: name, meta with a check, story text (red when flagged), then per node: number, its text, and a card with the photo, the gameplay name and `<地址> <名称>` (`无需到达地点` / `未选地点`).

**B9.2 Pre-publish items** the check produces. Passed list (TE `S27`): `主题名称已填写` · `主题封面已上传` · `主题简介已填写` · `已编排 N 个章节` · `已放置 N 个节点` · `已配置 N 种票单` · `通关规则已确定` · `内容安全预检通过` · `发布者实名已登记`. Blocking examples: `请填写主题名称`, `请填写一句话介绍`, `请填写完整介绍`, `请上传竖版封面`, `请选择至少一个路线类别`, `至少需要一个章节`, `第N章至少需要一个节点`, `第N章第M个节点还没有选地点`, `缺少剧情`, `还有 N 个素材未编排进章节`, `N 个节点未配置玩法`, `分支路线配置不完整`, `路线模拟存在无候选死路`, `第N个票务：请填写票价`, `发布者实名还没登记`. Precheck states: result sheet `安全预检中`; skipped lines `AI 次数已用完，本次跳过安全预检(不影响发布)` / `安全预检暂不可用，本次跳过(不影响发布)`.

**B9.3 Result sheets** (shared `cy-result-sheet` / `creation-success`: scallop or icon, eyebrow, title, detail, two meta pills, primary + optional secondary button, ✕).
| Case | Title | Detail | Notes |
|---|---|---|---|
| Draft saved | `草稿已保存到云端` | `已存草稿，可在「我的项目」继续编辑` | toast-level |
| Submitted | `已提交审核` | `主题与引用的玩法将一起审核。` | meta `N 个章节` |
| Published (TE `S28 4898:17006`) | `城市路线已发布` | `接下来去招商家承接节点、找俱乐部带团。` / `路线已进入你的项目列表。` | actions: 去我的项目 / 去项目主页招商 |
| Published, later edits local | `已发布` | `已发布提交时的版本；后续修改仍在本机，请继续编辑后另行保存。` | pill `草稿仍在本机` |
| Review rejected | `审核未通过` | `内容仍保留，可以修改后重新提交。` | |
| Failed | `这次还没有发布出去` | `修改后重试` | pill `草稿仍在本机` |
| Unknown | `发布结果待确认` | `发布结果暂时无法确认，请到项目列表确认。为避免重复创建，当前草稿不会再次发布，内容仍在本机。` | pill `请先确认项目列表` |
| Pre-publish warning | alert `发布前提示` | list of warnings | `再改改` / `继续发布` |

**B9.4 Flow summary** (for prototype wiring): 创作 page → `保存草稿` (name required: `先给主题起个名字，再保存草稿`) saves to the cloud and stays → `下一步` → 票务设置 → `预览` → 剧情预览 → `完成` → identity gate if needed → safety precheck → publish → result sheet. Autosave runs to the device continuously (chip states in B2.3) and failures surface as `自动保存未成功：…`.

## B10 · Shared pieces used by Parts A–C

| ID | Piece | Status | Spec |
|---|---|---|---|
| B10.1 | 发布入口 sheet (`cy-publish-sheet`, on the 发布 tab) | MISSING in R1–R6 (owner 新稿 file `txQoyVyKb3aQdFCnc8qmhj` E1 `146:396`, E2 `146:436`, E3 `146:477`) | Dim layer with four illustrated tiles: `自由探索`, `城市定向`, `互动`, `返回`. |
| B10.2 | 俱乐部发布 sheet (`club-publish-sheet`) | MISSING | Half sheet, title `发布什么？`, option rows: icon, title, description. |
| B10.3 | 奖励选择 `reward-selector` | MISSING (TE `S40`) | Field: label + occasion + value or placeholder. Sheet `选择奖励`: kind tabs (优惠券 / 体验卡), first row `不发奖励`, rows of name + description (`商家优惠券` / `到店体验权益`), loading `正在加载`, empty `暂无可选优惠券` / `还没有体验卡`, footer button `新建优惠券` / `新建体验卡`. Create sheet (full): `优惠券名称*`, `有效期*` (range picker `选择优惠券有效期`), `投放数*`, `类型*` dropdown (体验卡: fixed `体验卡`), `说明`, button `发布优惠券`. |
| B10.4 | 地点待办 `location-todos` | MISSING | Sheet `地点待办`: rows with title, a tag `挡住发布` (red) or `待复核` (amber), the place, a status (`未绑定` / `待在新城市重绑` / `已绑定 · 未现场核验` / `沿用 · 未复核`), and actions `替换地点`, `确认地点` (`确认中…`) or `选择节点` (`绑定中…`). |
| B10.5 | AI 助写 `ai-assist` | MISSING (TE `S20 4897:16425` is the upgrade of an AI draft) | Collapsed: a pill `AI 助写`. Expanded: title + `收起`, suggestion chips, an idea field, and a state row: default `一键生成`; generating: spinner `生成中…` + `取消`; done: `已生成，可继续编辑` + `换一版`; error: reason + `重试`. A source note line can follow. Quota text `今日AI次数已用完`. |
| B10.6 | 选择合作者 `collaborator-picker` | MISSING | Sheet: note `合作者可编辑内容，不参与结算`, search, rows avatar + name + `关注：…` + button `邀请` / `已邀请` / `无法邀请`; states skeleton, `合作者列表加载失败`, `暂无可邀请用户`, `正在加载更多合作者…`. |
| B10.7 | 章节闸 `chapter-gate` (preview of a chapter opening) | MISSING | Full-screen card: `第 1 章 / 共 3 章` (or `序章`), title, subtitle, progress bars, `轻点继续`. |
| B10.8 | Date and time pickers | MISSING (TE `S29 4898:17057`, `S30 4898:17120`, corrected range picker `4983:18885`) | Wheel sheets as in B8.1; the owner's range picker: tap first and last day, the span fills in grey, not violet. In the app use the native date picker and do not draw it. |
| B10.9 | Text edit pop-ups | MISSING (TE `S32`–`S34`) | Name / subtitle / description editing pop-ups from the older design; the code now edits these inline in B7. Draw only if the owner keeps the TE version (Q2). |

## B11 · Frames to draw for Part B (build list)

| # | Frame group | Count | Reference |
|---|---|---|---|
| 1 | Page states B1.1–B1.3, B1.7–B1.11 | 8 | TE S14–S16, S18 |
| 2 | 创作 page variants (自由探索 with node rows, dragging, 待编排区, map view, red chips, club empty, merchant fixed mode) | 7 | TE S3, S17, S19, S21, C1, M2 |
| 3 | 主题模式 picker + copy alert | 2 | TE P3 |
| 4 | 故事流 editor: empty, filled (all block types across 2 frames), block selected, dragging, split-drop, undo pill, ⋯ menu, grip menu | 9 | TE P7, P8, S4–S6, S22, S24, S37 |
| 5 | Story sheets: 图片 layout, 分支任务, 插入变量 (+ empty), 弹窗预览 × 6 stages | 10 | — |
| 6 | 节点 sheet: new, with place, template bound (shared), 自由探索 variant; 玩法模板 view (3 lists + empty/error); map picker | 7 | TE P9, P10, S7–S9, S25, S35 |
| 7 | 到达与引导; 下一站 (collapsed, row open, 添加条件 layer, effects in sort mode) | 5 | TE S36, J4 |
| 8 | 章节设置: 城市定向 (full), 自由探索 with 商家承接, ending chapter, prologue with video | 4 | TE P6, J3, S23 |
| 9 | 主题详情 sheet (2 full frames) + error state | 3 | TE P4, P5, S11 |
| 10 | Nested editors B7.2–B7.13 | 22 | TE S40, S41 |
| 11 | 票务设置 page, with team mode, ticket editor (城市定向, 自由探索), identity block, pickers | 6 | TE P11, P12, S12, S13, S29, S30 |
| 12 | 剧情预览 (clean, with blocking, with advisory), 阅读剧情 pop-up | 4 | TE S38, S26, S27, J7 |
| 13 | Result sheets and alerts B9.3 | 8 | TE S28 |
| 14 | Shared pieces B10.1–B10.7 | 9 | 新稿 E1–E3, TE S20, S40 |

---

# Part C · 发布活动, steps 1–3 (`/pages/publish/activity/index`)

**Status: PARTIAL.** The three steps exist as empty forms: step 1 `94:5281` (twin `186:5655`), step 2 `94:5345` (twin `186:5718`), step 3 `94:5397` (twin `186:5768`); prototype copies `207:10738 / 10785 / 10822`. Every other state and all four sheets are missing. Owner 新稿 for this flow: file `txQoyVyKb3aQdFCnc8qmhj`, J0 `99:11045`, J1–J4 `99:7136 / 7145 / 7156 / 7167`, N6–N8 `99:7998 / 8025 / 8047`.

Sources read: `activity/index.wxml` (340 lines, all), `index.js` (strings, `validateForm`, `sendData`), captures 053–055.

## C1 · Page frame

- Nav: back chevron only. Large left title `发布活动` (edit mode: `编辑活动`).
- Step row under the title: three dots with labels `基本信息` · `活动内容` · `票务与合作`; done and current dots are black, current label is bold. Each step has a one-line question the page can show: `这场活动叫什么、在哪儿办？` / `这场活动玩什么？` / `这场活动怎么卖票？`.
- Fields: label above (16, with a red `*`), white field 48 high, radius 12, grey placeholder.
- **Bottom bar** (fixed; check that the restored frames show it, the captures were cut above it): step 1 `取消` + `下一步`; step 2 `上一步` + `下一步`; step 3 `上一步` + `发布` (edit mode: `保存`).

## C2 · States

| ID | State | Status | Spec |
|---|---|---|---|
| C2.1 | Sign-in required | MISSING | Empty state `登录后发布活动`. |
| C2.2 | Checking identity | MISSING | Centred spinner under the title. |
| C2.3 | Identity check failed | MISSING | Error `暂时无法确认身份` + reason (`身份校验失败，请重试`). |
| C2.4 | Not allowed | MISSING | Empty state `暂时不能发布活动` + reason: `发布单场活动需要俱乐部主理人身份。` or `发布单场活动需要店主的「项目管理」权限，请让店主在团队里给你开通。` |
| C2.5 | Existing activity failed to load | MISSING | Error `活动加载失败` + `活动加载失败，请重试`. |
| C2.6 | Step 1 empty | PRESENT `94:5281` | |
| C2.7 | Step 1 filled | MISSING | No filled capture exists. Suggested fill from the seeded test entities (sample, not from a capture): 活动标题 `外滩夜探`; 活动地点 a real Shanghai address; 活动日期 `11月21日 19:30` – `11月21日 21:30` (format `M月D日 HH:mm`); 活动类型 `城市探索、夜游` (names joined with `、`). |
| C2.8 | Step 1 errors | MISSING | Red line under each field: `请填写活动标题`, `请填写活动地点`, `请选择开始日期` / `请选择结束日期`, `请选择至少一个活动类型`. |
| C2.9 | Step 1 locked (tickets sold) | MISSING | Grey note under the date: `已售出，时间和地点不可改`; tapping toasts `已售出，时间不可改` / `已售出，地点不可改`. |
| C2.10 | Step 2 empty | PRESENT `94:5345` | 活动说明 textarea, 活动封面 slot (80 × 80 dashed `＋` inside a white field), 选择模板 row `请选择模板 ›`. |
| C2.11 | Step 2 filled / uploading / upload failed | MISSING | Cover slot shows the image (tap to replace), a progress overlay while uploading, a red badge when it failed. Errors: `请填写活动说明`, `请上传活动封面`, `封面上传未完成，请重试或删除`. Template row shows the chosen title. |
| C2.12 | Step 3 empty | PRESENT `94:5397` | Collaborator card: owner row (avatar, `海派城市漫游团`, tag `主理人`) + `＋ 添加合作者`; `票单名称1*`; grid `票面价格*` · `票单库存*`; grey summary box `发布前摘要` + `未命名活动，时间待补充，地点：待选择，共 1 种票单。`; grey pill `＋ 添加票单`. |
| C2.13 | Step 3 with two tickets and a collaborator | MISSING | Second collaborator row with a remove ✕; second ticket block `票单名称2*` with a delete icon at the right of its label. Summary: `<活动名>，<开始> 至 <结束>，地点：<地点>，共 2 种票单。` Toasts `已添加: <昵称>`, `该合作者已添加`, `已移除: <昵称>`, `至少保留一个票单`. |
| C2.14 | Step 3 errors | MISSING | `请填写票单名称`, `请填写不小于 0 的有效票价`, `请填写有效的库存数量`. Owner fix already in the twin: stock placeholder `请输入库存`, not `0`. |
| C2.15 | Step 3, identity block | MISSING | Section `发布者实名`: `真实姓名*` (`与身份证一致`), `身份证号*` (`18 位`), consent check; registered state shows one grey line instead. |
| C2.16 | Edit mode | MISSING | Title `编辑活动`; summary label `修改摘要` plus the note `本次保存只更新上面这些内容，不会改变活动的公开范围。`; primary `保存`. |
| C2.17 | Submit failed | MISSING | Red inline block above the bottom bar: `活动尚未发布` (edit: `修改没有保存`) + `发布失败，请重试` or `还没确认是否保存成功，再提交一次即可，不会重复保存`. |
| C2.18 | Success | MISSING | Result sheet: `活动已发布` / `发布成功，活动已进入项目列表。` + pill `N 个票种` (edit: `活动已更新` / `保存成功，活动已进入项目列表。`). |
| C2.19 | Leave alert | MISSING | `放弃未发布的活动？` / `已填写的活动内容不会保留。` (edit: `放弃未保存的修改？` / `这次改动不会写回活动。`), buttons `继续编辑` / `放弃`. |

## C3 · Sheets

| ID | Sheet | Status | Spec |
|---|---|---|---|
| C3.1 | 设置活动时间 | MISSING | Title `设置活动时间`. Two selectable point cards at the top: `开始` + preview value, and `结束（下一步）` + `下一步后自动建议` (locked until the start is confirmed; then `结束` + value). Below: two wheel columns groups, `日期` (`11月21日` …) and `时间` (`19时`, `30分`). One footer button: first tap confirms the start and moves to the end, second confirms both. Toasts `请选择完整的开始时间`, `结束时间必须晚于开始时间`, `时间设置完成`. In the app this is the native date picker in a two-step sheet; draw the two point cards and leave the wheel area as the system component. |
| C3.2 | 活动类型 category sheet | MISSING | Shared multi-select category sheet (as B7.1). |
| C3.3 | 我的模板 | MISSING | Title `我的模板`; search field `搜索关键字`; rows: 72 cover with a rating badge and `N 使用`, title, chips for players and `N分钟`, a radio at the right; footer button `完成`. States: skeleton, error `模板加载失败` + reason, empty `还没有可用模板`. Toast `模板选择成功`. |
| C3.4 | 选择合作者 | MISSING | B10.6. |

## C4 · Ticket settings: where each kind lives

| Ticket surface | Route | Part |
|---|---|---|
| Single activity tickets (name, price, stock) | `publish/activity` step 3 | C2.12–C2.14 |
| Topic tickets (name, price, quantity, sale window, meeting time and place or validity, refund rule, note) | `publish/fabu` page 2 | B8 |
| Team mode, merchant and club recruiting switches, recruit deadline | `publish/fabu` page 2 | B8 |

---

# Part D · AI 快速创建 (`/pages/publish/simple/index`)

**Status: PARTIAL.** Only the start state exists: `94:4532` (twin `189:3397`). Owner 新稿 (older, chat-style): `txQoyVyKb3aQdFCnc8qmhj` F1–F5 `99:5915 / 5940 / 5962 / 6012 / 5984`, N3–N5 `99:7934 / 7974 / 7987`. The code moved to interest tags + a bottom input bar; the twin follows the code.

Sources read: `simple/index.wxml` (131 lines, all), `index.js` (all strings), capture 051.

| ID | State | Status | Spec |
|---|---|---|---|
| D1 | Sign-in required | MISSING | Nav `快速配置`; empty state `登录后配置路线`. |
| D2 | Start | PRESENT `94:4532` | White card of interest tags (multi-select; selected = black): 城市探索 · 美食探店 · 咖啡巡游 · 历史人文 · 文艺展览 · 夜游 · 亲子 · 解谜 · 沉浸剧情 · 摄影打卡 · 骑行 · 徒步 · 户外 · 运动 · 音乐 · 宠物 · 手作 · 购物 (each with a line icon). Card with two rows `历史起草记录 ›`, `本机保留记录 ›`. Bottom: prompt chips `老城建筑与咖啡` · `周末亲子探险` · `雨天室内漫游`; input `说说你想要的路线…`; round black send button with an up arrow. |
| D3 | Tags selected + text typed | MISSING | Three tags black; the input holds a short request (sample: `从外滩走到豫园，两小时`); send enabled. Empty send toasts `先说说你想做什么路线。` |
| D4 | Generating | MISSING | A compact progress block replaces the tag card's lower area: `正在生成主题草稿` / `完成后仍需你确认地点`; the send button shows `…`. |
| D5 | Failed | MISSING | Inline error `这次没能继续` + reason (e.g. `AI 生成的主题不完整，请换一种说法重试`, `AI 草稿最多只能包含不超过 3 个节点，请换一种说法重试。`, `网络暂时不可用，原起草结果还没确认，请查看原结果。`). |
| D6 | Quota used up | MISSING | Inline error `今日额度已用完` / `可改用手动创建`; send button greyed. |
| D7 | Result, collapsed card | MISSING | A line with the request, built as `<标签、标签> · <输入>` (sample: `城市探索、夜游 · 从外滩走到豫园`); a card: cover thumbnail, title, `AI 生成 · 3 站`, button `打开草稿`; a numbered list of the stops. Bottom chips switch to tweaks: `再加一站` · `换成晚上` · `缩短到 1 小时`. The send button reads `查看` while a draft is pending. |
| D8 | Result, review open | MISSING | Header `AI 为你整理的初稿` + tag `AI 生成 · 可编辑` (or `AI 生成 · 只读 · 原模式待确认`). Fields `主题名称*`, `故事简介`. Section `确认地点` + `3 个节点`. One card per stop: number, name field, description field, and a row `在地图中确认地点 →` (confirmed: the address). Primary button `确认地点，进入编辑器 →`. A filing line (AIGC 备案号) at the bottom. Toasts: `请逐个在地图中确认地点后再继续。`, `请选择一个有坐标的具体地点。` |
| D9 | Recovery states | MISSING | Under the tag card: a status label (`已准备` / `处理中` / `结果待确认` / `已成功` / `已失败`), an identity line, `正在查找历史起草记录…`, and buttons `继续原起草` and `确认后另起一次`. Messages such as `原起草还在进行中，请稍后查看原结果。` |
| D10 | 选择原起草记录 sheet | MISSING | Option sheet `选择原起草记录`: rows labelled `只读历史 · …` / `本机保留 · …`, plus `更多记录` / `返回最新记录`; empty `还没有起草记录` / `当前账号没有本机保留记录。` |
| D11 | Confirm "start another" alert | MISSING | `另起一次 AI 起草？` / `上一次的结果仍可能返回。原记录会保留；另起一次不是重试，可能额外占用 AI 额度。是否明确另起？` / `保留原记录` · `确认另起`. |

After D8 the flow enters the topic editor with an AI draft; the editor shows the upgrade notice of TE `S20 4897:16425`, and every generated text carries the suffix `[AI 辅助生成]`.

---

# Part E · Template intro, market, detail, my templates

## E1 · 创建节点玩法引导 (`/pages/publish/template-intro/index`) — PARTIAL

Drawn: `94:5553` (twin `188:5893`). Black full-screen page with a canvas of orbiting sample cards behind the copy; two-line headline `把你玩过的一段路` / `做成别人也能走的玩法`; white pill `开始创建` at the bottom; transparent nav.

| ID | State | Status | Spec |
|---|---|---|---|
| E1.1 | Normal | PRESENT `94:5553` | |
| E1.2 | Cards loading | MISSING | Headline and button present; a small spinner where the cards would be. |
| E1.3 | Cards failed | MISSING | Inline error near the top: `精选示例暂未加载` + `精选示例加载失败，请重试`. The button still works. |
| E1.4 | Could not open the editor | MISSING | Inline error above the button: `创建页面没有打开` + `创建页面没有打开，请重试`. |

## E2 · 模板广场 / 发布 tab (`/pages/template/index`, component `templatedetail/shelf`) — PARTIAL

Drawn: 主题 tab `95:1975` (full `95:1889`; twins `169:3739`, `169:3833`). Capture 004 data: featured card `城市定向` / `黄浦老城慢游 · 三站轻探线` / `1 个玩法 · 2 分钟`; shelves `全部主题 ›`, `两小时内玩完 ›`; row sub-line `两小时读懂百年街区与骑楼故事`.

| ID | State | Status | Spec |
|---|---|---|---|
| E2.1 | 主题 tab | PRESENT `95:1975` | Two 3D icon tabs `主题` / `玩法` with an underline; search field `搜索主题与玩法模板`; bell at top right. Featured carousel with page dots; filter chips `全部` + tags + `全部分类`; shelves (two-row horizontal grids, or single-row large cards). |
| E2.2 | 玩法 tab | MISSING | Same shell. Featured carousel of gameplay cards: group name, a two-tone headline (lead + rest), cover, title + short line, a `使用` pill. Chips. Shelves in columns of rows: 56 icon tile, title, short line. Gameplay titles to use: `老城钟楼暗号挑战` (单节点文字验证 + 三级阶梯提示), plus one per family from A3. |
| E2.3 | Category selected | MISSING | One chip black; the shelves are replaced by a single list under the category name: cover, `<类型> · <章数/时长>`, name, sub-line, description (topics) or icon tile, title, short line (gameplay). |
| E2.4 | 全部分类 sheet | MISSING | Sheet `全部分类`: groups with a name and a wrap of tag chips (icon + name). |
| E2.5 | Loading | MISSING | Skeleton: tabs + grey featured block + three grey rows. |
| E2.6 | Error | MISSING | `主题模板加载失败` / `玩法模板加载失败` with retry. |
| E2.7 | Empty | MISSING | `还没有可复用的主题模板` / `还没有玩法模板`. |
| E2.8 | Merchant variant | MISSING | Light theme; a page title `模板`; note for staff without rights: `仅店主、店长可发布和复制`; a floating publish button at bottom right for owners (opens B10.1). Toast `当前岗位没有项目发布权限`. |
| E2.9 | Preview-only template tapped | MISSING | Toast `这是预览模板，保存后才能查看`; tags `实验预览` / `实验模板` on such cards. |

## E3 · 节点模板详情 (`/pages/templatedetail/templatedetail`) — PARTIAL

Drawn: 详情 tab `97:2056` (full `97:1917`; twins `169:10358`, `169:10499`). Capture 144 data: `模板库 · 老城钟楼暗号挑战` / `创作者`; button `应用`; stats `12 采用次数` · `5.0 评分` · `15 分钟 预计时长`; 简介 `单节点文字验证 + 三级阶梯提示模板，适合地标建筑物观察。`; 规则 `1 到点位后观察匾额作答。`; 怎么验证: 核验方式 `文字验证`, 节点题面 `钟楼正门匾额共有几个汉字？`; chips `难度 简单` · `15 分钟` · `1-4人`; 分类与适用场景 `城市探索` · `人民广场` · `钟楼`; 所需物料 `无`; 包含内容 `模板库 · 老城钟楼暗号挑战 · 标准玩法`; 评价 `5.0` + `来自真实到店玩家`; footer box `这是玩法模板，不能直接开团` / `「应用」会把这个玩法复制成你自己的玩法模板；玩家要在活动发布后才能玩到。`

| ID | State | Status | Spec |
|---|---|---|---|
| E3.1 | 详情 tab | PRESENT `97:2056` | |
| E3.2 | 能力 tab | MISSING | Rows of `标签 + chips`: `节点预览` (a chip with an arrow that opens E3.6), `方式`, `场景`, `来源`; a long row collapses with a `更多` toggle. Same footer box. |
| E3.3 | Loading | MISSING | Cover blur + spinner. |
| E3.4 | Error | MISSING | `玩法没能打开` + reason (`玩法详情加载失败，请重试。` / `网络异常，玩法详情加载失败。`). |
| E3.5 | Refused / expired link | MISSING | Empty state with the refusal text (`链接已失效`, `系统繁忙，请稍后重试`). |
| E3.6 | 节点交互预览 sheet | MISSING | Sheet `节点交互预览`. Text question: the prompt, a field `输入预览答案`, button `完成预览`. Option question: the prompt, option rows A–D (selected = filled), `完成预览` (disabled tap toasts `请先作答再完成预览`). Other methods: one line `该玩法验证方式为「拍照打卡」，请报名参与活动后体验。` |
| E3.7 | My own template | MISSING | Primary button is black and reads `继续编辑` (or `去模板广场选用` when view-only); a line `审核反馈：<原因>` under the description; footer text `这是你的玩法模板，可以继续编辑；玩家要在活动发布后才能玩到。` |
| E3.8 | Official publisher | MISSING | Small tag `官方` beside the title; publisher `城瘾`. |
| E3.9 | Description / rules expanded | MISSING | `更多` / `收起` toggles under long text. |

## E4 · 主题模板预览 and 主题模板详情 — PARTIAL

Drawn: preview `98:1619` (full `98:1573`; twins `169:10640`, `169:10688`); detail `98:1660` (twin `169:10736`).

| ID | State | Status | Spec |
|---|---|---|---|
| E4.1 | Preview, cards | PRESENT `98:1619` | A deck of flip cards (cover on the front; back: title, numbered steps, a foot line), the name, check lines (`3 章节 6 节点`, `约 2 小时`, `勋章「…」`), intro text and chapters with guides, button `查看详情`. |
| E4.2 | Preview, card flipped | MISSING | One card showing its back. |
| E4.3 | Preview, loading / error | MISSING | Spinner; error text with `重试`, or `返回` when refused (`缺少模板ID`, `主题模板加载失败`). |
| E4.4 | Detail, 详情 tab | PRESENT `98:1660` | Cover, name, author, `官方` tag, `应用` + share; tabs `详情` / `能力`; gallery; `剧情` (opening + chapters with `第 1 章`, text, stops `第 1 站 …`); stats `章节` / `节点` / `总时长`; `节点` cards (name, teaser, credit); `通关勋章` (image, name, `走完全部节点时点亮`). |
| E4.5 | Detail, 能力 tab | MISSING | Summary chips (`城市定向`, `可以跨天`, `3 个玩法`, `6 站`, `约 2 小时`); a numbered list of stops: name, gameplay, what to do, duration with a clock; `采用条件` table: 地点 (`需要到现场 · 6 个地点` / `不需要到现场`), 投入 (`主持约 20 分钟`, `同时最多 4 组`, `需预约`), 验证 (`已实地验证` / `已试点` / `预估，未实地验证` / `未实测`), 端侧, 语言 (`简体中文`), 许可 (`已登记许可` / `许可信息未提供`), 版本 (`第 2 版`). Unknown values read `待核实` / `待补充`. |
| E4.6 | Detail, loading / error | MISSING | `主题模板没能打开` + reason. |
| E4.7 | Apply flow | MISSING | Toast `正在配置，请稍候` → opens the topic editor with the copied draft; failures `使用模板失败`, `网络错误，请重试`; staff: `当前岗位仅可浏览模板`. |

## E5 · 我的节点玩法 (`/subpackageMember/mytemplate/mytemplate`) — PARTIAL

Drawn: list `112:1810` (full `112:2270`; twins `181:2222`, `181:2668`).

| ID | State | Status | Spec |
|---|---|---|---|
| E5.1 | List | PRESENT `112:1810` | Title `我的节点玩法`. Card: cover (or a letter tile, default `玩`) with a rating badge and `N 次引用`; title + `⋯`; description; rows `评分`, `个人审核` (`已发布` / `未发布` / `审核中`), `模板广场` (market status), optional `审核反馈` / `广场反馈`, `时长` (`— 未设置` when empty, per the twin), `创建时间`. |
| E5.2 | `⋯` menu open | MISSING | Dropdown under the card header: `提交广场审核` (or the market toggle label) and red `删除节点玩法`. Toasts `已提交广场审核`, `删除成功`. |
| E5.3 | Empty | MISSING | `还没有节点玩法`. |
| E5.4 | Loading | MISSING | `正在加载你的节点玩法`. |
| E5.5 | Error | MISSING | Error with the reason (`玩法草稿加载失败`, `刷新失败，请重试`). |
| E5.6 | Sign-in / no access | MISSING | `登录后查看我的节点玩法` / `当前账号无法查看节点玩法`. |
| E5.7 | Load more | MISSING | Footer `加载更多`, a loading row, or the inline error `更多玩法加载失败`. |

---

# Part F · 外部游戏 (external game catalogue and import)

**Status: PARTIAL.** The mini-program only lists and describes external games (they run in the app). The import flow exists only in the native app. In Figma: R6 `A56 104:2673` (app, empty library) and `A57 104:2707` (app, catalogue sheet). The submit sheet was not restored (blank capture). Nothing from the mini-program pages is drawn (no capture in INDEX).

Sources read: `subpackageMember/external-games/index.wxml`, `external-game-detail/index.wxml`; native `App/ExternalGameImportView.swift`, `ExternalGameReviewScreens.swift`, `Core/ExternalGameImport.swift`, and the `playx.externalGame.*` strings in `Resources/Localizable.xcstrings` (DES-ag4, read only).

## F1 · Mini-program catalogue

| ID | Screen / state | Status | Spec |
|---|---|---|---|
| F1.1 | 外部游戏 list | MISSING | Title `外部游戏`. Rows: 56 icon, name + a rating tag (`12+`), one-line summary, meta `<作者> · v1.2.0 · 2.4 MB`, chevron. Footer `加载更多` or `已经到底了`. |
| F1.2 | List loading / error / empty | MISSING | Skeleton; `目录加载失败` (toast `加载失败，稍后再试`); `还没有上架的外部游戏`. |
| F1.3 | Detail | MISSING | Title = game name; tags rating + `v1.2.0`; summary; a full-width notice card `在城瘾 App 中游玩`; a table: `作者`, `大小`, `权限`, `上架`. |
| F1.4 | Detail loading / missing / error | MISSING | Skeleton; `游戏已下架或不存在`; `详情加载失败`. |

## F2 · App import flow (native; draw in the mini-program look per the N1 rules)

| ID | Screen / state | Status | Spec |
|---|---|---|---|
| F2.1 | Library section, empty | PRESENT `104:2673` | Section `扩展小游戏库（沙盒）`; empty text `还没有导入的游戏` + hint `支持通过 HTTPS 链接、二维码或文件导入带签名清单的 HTML5 互动包，仅在受限沙盒中运行。`; menu button `导入游戏` with two items `链接 / 扫码导入`, `从文件导入 (.json)`; text button `提交审核`. |
| F2.2 | Library with games | MISSING | Row per game: name, `v1.0.0 · 12+`, `<gameId> · 链接导入 (URL)` (or `扫码导入 (QR)` / `文件导入 (Files / 分享)`), button `运行`, a red remove icon (`移除游戏`). Sample: `篝火谜题小游戏` / `在背包沙盒内运行的轻量解谜互动`. |
| F2.3 | 导入外部游戏 sheet | MISSING | Nav title `导入外部游戏`, `取消`. Segmented `导入方式`: `HTTPS 链接` / `二维码内容`. Section `游戏包 HTTPS 地址` (or `扫码识别出的安全链接`): a URL field `https://example.com/game.json`. A result row (shield icon + message) after checking. Button `校验签名清单并预览权限`. |
| F2.4 | Import errors | MISSING | Red triangle + one of: `仅允许从安全的 HTTPS 地址导入：…`, `游戏包缺少数字签名或哈希摘要`, `游戏包数字签名校验未通过`, `游戏包内容哈希（SHA-256）与清单不一致`, `游戏包体积超限（…）`, `包含不允许的文件类型：…`, `请求了未授权或禁止的权限：…`, `外部导入游戏禁止包含支付或内购调用：…`, `内容分级无效（…），仅支持 4+、9+、12+、17+`, `游戏包格式损坏或无法解析`, `你已屏蔽「…」，无法导入或运行`. |
| F2.5 | 确认导入外部游戏 | MISSING | Nav title `确认导入外部游戏` (update: `确认更新外部游戏`), `取消`, primary `确认安装` (`确认更新`). Sections: `游戏包来源与签名核验` (名称, 版本 with `1.0.0 → 1.1.0` on update, 内容分级, 导入来源); `申请的沙盒权限` (shield rows: `本地进度存档（仅限本游戏沙盒）`, `触感反馈（轻触震动）`, `背景音效播放`, or `无额外权限（纯离线静态互动）`); `允许访问的 HTTPS 域名白名单` (lock rows, or `完全离线（禁止任何外部网络请求）`); a notice: `安全承诺：该内容仅在隔离的 WKWebView 沙盒内运行，不共享登录凭据，禁止任何应用内购买或外部支付，且仅开放受版本控制的只读/存档桥接接口。` |
| F2.6 | Age gate | MISSING | Alert `年龄分级`: `这个游戏的分级是 12+。确认你的年龄符合这个分级后再开始。` / `取消` · `符合分级`. |
| F2.7 | Run container | MISSING | Nav: game name, `关闭`, a `⋯` menu `举报或屏蔽` (`向服务器举报`, red `屏蔽此游戏及创作者`). Header row: lock-shield + `<名称> (v1.0.0)`, sub-line `分级 12+ · 沙盒隔离`. The web view area. Footer button `完成并签名上报结果` (`正在签名提交...`), then a result line `结果已签名上报：+20 探索值 · 勋章第3名 · 节点已通关`. Error states: `入口文件未通过沙盒校验`, `当前环境不支持 WebKit 沙盒视图`. |
| F2.8 | Block confirm / report sheet | MISSING | Alert: `屏蔽后将关闭并无法再导入或运行此游戏及其创作者的其他游戏包。` / `取消` · `屏蔽`. Report sheet: `原因` picker, `补充说明`, switch `同时在本机屏蔽`, `取消` / `提交举报`. |
| F2.9 | Catalogue `可玩的 HTML 游戏` | PRESENT `104:2707` | Rows with price (`免费`, `流量激励`), `下载并安装`; notes `已下架并从本机移除：…`, `目录没有加载出来。`, `还没有已通过的游戏。`; links `我的提交`, `创作者定价与流量收益`. |
| F2.10 | 我的提交 | MISSING | List with `审核状态`, `驳回原因`, actions `撤回`, `重新提交`; states `提交列表没有加载出来。`, `还没有提交。`, `结果未知，仍保留请求 <id>。` |
| F2.11 | 创作者变现与绑定 | MISSING | Sheet `创作者变现与绑定`, `关闭`. `创作者收益概览` (付费订单数, 净销售分成, 有效流量游玩, 已结算流量积分); `定价与流量激励配置（发布后可设）`: `外部游戏 gameId`, `定价模式` (仅流量激励 / 付费购买 / 免费无激励), `售价（元）`, `流量激励模式` (积分 / 现金 / 关闭), `通道手续费` (创作者承担 / 平台承担), button `保存并提交审核`; `绑定到主题节点`: `节点 ID`, `最低通关分 (0 不限)`, button `绑定外部游戏到此节点`. **Owner ruling: one currency, 积分.** Draw only the 积分 options and flag the cash options as out of scope (Q5). |

---

# Part G · The "19 + 4" gameplay types, one by one, and what has no source

"19" is the original template document (`节点玩法模板_十九个玩法与编辑页`). The mini-program catalogue has since grown to 35 keys. "+4" are the types the product map lists as wanted but not built as types: 判断 (true/false), 碎片拼图 (jigsaw), 刮刮卡 (scratch) and 音频片段 (audio clip). **Not one of the 19 + 4 has a config frame in Figma today.**

## G0 · Where each of the 19 is configured

| # | Type (doc key) | Schema section | Config spec | Extra sheets and states that apply |
|---|---|---|---|---|
| 1 | 文字问答 `qaText` | `qa` (TYPE), `answerPolicy` | A4.1 | 逐字猜词 A4.2; 题干附件; 结果反馈 A5; 提示 A6.1; tools A10 |
| 2 | 选项问答 `qaPick` (+ 多选) | `qa` (PICK, `multi`) | A4.3 | 人物指认 A4.4; per-option result A11.4; A5; A6.1; A10 |
| 3 | 拍照打卡 `qaShot` | `qa` (SHOT) | A4.5 | A5 (completion only); A10 |
| 4 | 分支剧情 `branch` | `branch` | A7 (in-node segments) and the story block 分支任务 B4.4 / B4.7 | 下一站 B5.4 for cross-node routing |
| 5 | 猜数字 `estimate` | `estimate` | A4.17 | A5; A6.1; 限时 A10.7 |
| 6 | 猜图 `pricePair` | `pricePair` | A4.6 | per-image result A11.4; A5; A6.1 |
| 7 | 找东西 `hidden` | `hiddenObject` | A4.18 (4-frame pin flow) | A5; A6.1; 限时 |
| 8 | 竞猜 / 预测 `predict` | `predict` | A4.8 | per-option result; needs a host shop (disabled reason in A3) |
| 9 | 抽卡 / 翻卡 `random` | `random` | A4.16 | per-card result A11.4 |
| 10 | 九宫格 `bingo` | theme level | B7.9c (grid + cell editor) | A4.23 is only a pointer line |
| 11 | 计步 `steps` | `steps` | A4.26 | A5; 归零恢复 "走够步数" B7.5 |
| 12 | 变色就点 `react` | `reaction` | A4.27 | A5; 状态不好时松一点; 限时 |
| 13 | 弹球 `shake` | `ballShake` | A4.28 | A5; relax option `血量低时弹球多给 5 秒` |
| 14 | 安静挑战 `quiet` | `quietHold` | A4.29 | A5 |
| 15 | 倒计时 `countdown` | `countdown` | A4.32 | A5 |
| 16 | 精准停表 `stopwatch` | `stopwatch` | A4.33 | A5 |
| 17 | 抛硬币 `coin` | `coinFlip` | A4.14 | `正面之后` / `反面之后` A11.4 |
| 18 | 掷骰子 `dice` (+ D20) | `diceRoll` (d6 / d20), `check` | A4.15, A4.25, A4.24 | `掷到 N 之后` A11.4; 添加加值 / 代价 A11.5; theme d20 settings B7.8 |
| 19 | 扫码 `scan` (+ AR 显形) | `scan` (`kind`, `arMode`) | 参与方式 in A2 + A11.3 | 到达与引导 B5.3 |

Catalogue types beyond the 19, all specified in Part A: 闭眼盲品 A4.7 · 拍照审核 A4.9 · 拍物成卡 A4.10 · 排序 A4.11 · 连线 A4.12 · 分类 A4.13 · 角色建档 A4.19 · 留言 A4.20 · 今日城市签 A4.21 · 相册 A4.22 · 罗盘指向 A4.30 · 喊一嗓子 A4.31 · 输入挑战 A4.34 · 人物指认 A4.4 · 逐字猜词 A4.2. Removed from the editor and shown only as read-only `旧规则` rows: 默契点单 `silentOrder`, DIY 起名 `diyName`, 音乐角 `musicCorner`, 慢任务 `slowTask`, 多人协作 `multiplayer`. GPS 到达 is now a participation mode (`定位到达`), 偏好题组 survives only as the legacy JSON card A4.36d.

## G1–G6 · The "+4" and other gaps

| ID | Type | State of the product | Status in Figma | Build spec |
|---|---|---|---|---|
| G1 | 判断 (true / false) | No dedicated type in backend, mini-program or app. A 2-option 选项问答 does the same job. | MISSING | Draw as a **preset of A4.3**, stored as `qa` PICK with two options (no schema change): `题干 *`; a two-way answer control `对` / `错` (pick the correct one); `答对的反馈` and `答错的反馈` textareas (the option `fb` fields); `次数上限`, `次数用完后`, `奖励分`. In the 选择玩法 sheet it would be a 9th tag under 问答 with the line `一句话，判断对或错`. **Needs an owner ruling before it is added to the picker (Q3).** |
| G2 | 碎片拼图 (jigsaw) | Not in the schema, backend, mini-program or app. The owner's TE gameplay library (`P10 4868:14344`) only names it as a sample template: `碎片拼图 · 按线索拼出完整地图`. | MISSING | **No source to restore from.** Draw only a disabled tag in the 选择玩法 sheet with the reason `暂未开放`. A config card cannot be specified until a schema section exists (Q3). |
| G3 | 刮刮卡 (scratch) | Play-side reveal effect exists (`scratch` component in the mini-program, `CYScratchCard` in the app). No config type and no schema section. | MISSING | Same as G2: disabled tag `暂未开放`; no config card until the type exists (Q3). |
| G4 | 音频片段 `audio_clip` (声音密码), with 保持静止 and 步数挑战 | Backend sensor policy exists (validation method 7). The app has a local config model and view (`Core/TemplateSensorDraft.swift`, `App/TemplateSensorDraftConfigurationView.swift`). The mini-program has no editor for it. | MISSING | One card, title `传感器挑战类型`. A picker with three kinds: `保持静止` · `步数挑战` · `音频片段`; nothing is preselected (`请选择类型；不会自动填写默认值`). Fields by kind, integers only: 保持静止 → `静止目标时长（秒）` 1–600; 步数挑战 → `目标步数` 1–100000 and `计步时间窗（秒）` 1–86400; 音频片段 → `音频最短时长（秒）` 1–60. Empty value shows `未填写`. Field error: `请输入所示范围内的整数。空白值会保持缺失状态。` Status lines: `当前输入不完整或无效，仍可保存为本地草稿。` / `配置数值有效，尚未验证设备运行效果。` Scope note: `仅预览设置。不会录音、计步、上传或发布，也不会申请权限。` Unsupported stored data: `此已保存的设置暂不支持，无法编辑，已原样保留。` Button `预览传感器配置`. Frames: nothing chosen, each kind filled (3), field error, read-only. |
| G5 | 猜图 · 揭晓式 (pixelated / zoom-in reveal) | Not built anywhere; only the scratch reveal effect is close. | MISSING | No source; treat as G2 (Q3). |
| G6 | Icon and preview-tile set for the 32 picker tags | The picker reuses generic line icons (`edit` × 7, `camera` × 3, `star` × 3, `clock` × 3); the app has no gameplay art at all. | MISSING | One 36-px glyph and one small preview tile per tag in A3 (32 tags + G1 if approved). This is the base for the later optimization review; list it now so the frames in A3 leave room for a 44 icon tile and an optional 120 × 90 preview. |

AR is covered: the only AR config is the 显形 reply of 扫码参与 (A11.3: 不开 / 放在地上 / 认一张图, optional `.glb` model).
---

# Appendix · Earlier app-style frames (content reference only, not counted)

Page `28:2` "15 创作·俱乐部运营" holds first-pass frames in the invented style the owner rejected. They are **not** restorations and are not counted as PRESENT, but they show one earlier reading of several states that are missing above. Use them for content ideas only; rebuild in the MP look.

| Earlier frame | Id | Corresponds to |
|---|---|---|
| I2b 主题编辑器 · 切换模式 | `44:327` | B3 |
| I2c 发布检查 · 还有 4 项未填 / 全部通过 | `44:359` / `44:514` | B9.1b / B9.1 |
| I2d 提交成功 | `44:657` | B9.3.2 |
| I4 AI 快速创建 · 草稿 / 生成中 / 生成失败 | `46:1291` / `46:1358` / `46:1409` | D7 / D4 / D5 |
| I5a 节点玩法模板编辑 · 默认 | `47:2492` | A1.7 |
| I11 我的节点玩法 · 空 | `47:7131` | E5.3 |
| I6a 发布活动 第 1 步 · 校验错误 | `48:5529` | C2.8 |
| I6b 第 2 步 · 上传中 / 上传失败 | `48:5613` / `48:5680` | C2.11 |
| I6c 第 3 步 · 校验错误 | `48:5842` | C2.14 |
| I6d 提交成功 | `48:5935` | C2.18 |
| I39a 外部玩法列表 | `48:20283` | F1.1 |
| I39b 外部玩法 · 网页容器 载入中 / 载入超时 | `48:20354` / `48:20392` | F2.7 |

## Answers to section 4 (2026-11-15)
- Q1: OWNER says follow the TE screens P7/P8 (insert seams, bottom 下一步), not the code's v2 editor.
- Q2: OWNER says follow the TE screens: grey ✕ plus black 完成 pill, and separate text pop-ups (S32–S34).
- Q3 (coordinator): include 判断, 碎片拼图, 刮刮卡 and 揭晓式猜图 as full gameplay types. The backend branch feature/game-types adds them.
- Q4 (coordinator): media fields become upload slots (camera, photos, files). The stored fields stay the same.
- Q5 (coordinator): keep the creator price option. Real money is TEST-only behind the money switch; traffic rewards are in 积分.
- Q6 (coordinator): use the Chinese labels proposed in A10.7 and A10.9.
- Q7 (coordinator): use Apple Health wording for steps, and remove the WeChat subscription template ID in the app.
- Q8: OWNER says yes: add drag-to-reorder for chapters and every list editor (options, hints, rewards, effects and others), with drag handles and haptics.
