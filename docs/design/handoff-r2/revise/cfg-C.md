# Config revision · Batch C (C1 topic editor) · execution log

Executor: Opus 5.5 · task `task_4f40fcfb4935` · 2026-11-15 · file `0YyoybGnU1KG0657wdGCPX` · page C1 `237:14642`
Plan: `review/full-config.md` sections 2, 3, batch C, section 6 defaults (Q-B yes, Q-E yes).

**Status: DONE for batch C scope (day 2). Day 1 stopped on the Figma MCP rate limit; day 2 resumed under a 90-call budget.** Original day-1 note: ("You've reached the Figma MCP tool call limit on the Education plan", team `小程序设计`). The call that hit the limit was rejected whole (nothing half-applied). Every frame listed as Done below was rebuilt in place (same node id, same name, same position) and checked with a screenshot.

Builder scripts used (paste-in preludes, reusable for the rest): `revise/cfgC-b4-head.js` (prelude + helpers), `cfgC-b4-blocks.js` (story-flow blocks + B4 page), `cfgC-b49.js` (CF-24 block types), `cfgC-b2.js` (创作页), `cfgC-c-prelude.js`.

Rendering note: paints bound to Color variables are created with the MP-Light value as the raw colour, and every rebuilt frame gets explicit modes Color=MP-Light, Spacing=MP, Radius=MP (a frame rebuilt without them rendered black).

## New components

### Added to the shared kit (Library `6:3`, section `276:295`, x 1960, y 1700–3500; section grown to 3607 high)
| Component | Node | Variants · props | For |
|---|---|---|---|
| Editor/Save Chip | `290:20194` | State Saved / Syncing / Unsaved / Failed (copy fixed per state: 已存 · 同步中 · 未存 · 保存失败; colour only on Failed) | CF-22 |
| Editor/Sample Tile | `290:20206` | Selected true/false · sample, name | CF-24, CF-36 |
| Editor/Swatch | `290:20217` | Selected true/false · name; override fill of `color` | CF-24, CF-26 |
| Editor/Token | `290:20228` | State Default / Error · value | CF-32 |
| Editor/Result | `290:20551` | State Success / Pending / Failed / Rejected (copy per variant, override on instance; no text props because Figma shares a text-prop default across variants) | CF-41 (and D's CF-52) |
| Editor/Confirm Dialog | `290:20572` | Destructive true/false · title, message, action, cancel, action2 + showAction2 | CF-25, CF-77, CF-78 |
No existing Editor/* component was changed except Editor/Confirm Dialog (my own, second action added). `Editor/Option Row` (Style=Card/List × Selected) is used as the CF-34 choice row; no Editor/Choice Row was added.

### Page-local components (new section `290:23341` "B11 本页组件 · 创作页 / 故事流 / 节点 (config batch C)", at the bottom of C1)
| Component | Node | Variants |
|---|---|---|
| Topic/Chapter Card | `290:23403` | State Default / Lifted / Empty / Blocked · ⋯ 44 + trailing handle |
| Story/Block Type Tile | `290:23405` | label, icon (instance swap) · 48 × 56 |
| Story/Seam | `290:23460` | State Rest (44 row, 28 ＋) / Expanded (7 type tiles) |
| Node/Gameplay Card | `290:23504` | State Empty / Set / Shared / Error (G6/Gameplay Icon 44) |
| Rule/Sentence | `290:23581` | Kind Next / Condition / Effect (Editor/Token inside, ⋯ + handle) |
| Map/Search | `290:23583` | glass search pill 44 |
| Map/Locate | `290:23587` | glass 44 circle |
Ticket rows use `Editor/Row` (label + value); no Ticket/Row component (not needed).

## Frames

| CF | Frames | Result |
|---|---|---|
| CF-20, CF-22, CF-19 (C1 leftover) | B2 `237:31646` (full, now 852: everything fits one screen), `249:37911` (首屏), `237:31806` (自由探索 nodes), `237:31986` (drag chapters, Lifted card over drop slot), `237:32141` (drag node rows), `237:32292` (待编排 list, ⋯ to 放进章节), `237:32538` (地点待办 row + Blocked chapter + 票务 还没设置 in red), `237:32682` (empty chapters: one card with Add Row, no black button; chip 同步中), `237:32772` (商家 mode fixed) | **Done.** Nav = Editor/Nav Bar "编辑主题" + ⋯ (no large in-content title). Row under nav: Save Chip + segmented 列表 / 地图. 主题详情 card with cover, red dot + "还有 2 项未填". 模式 / 票务 as Editor/Row (票务 shows "2 种票 · 39 积分起", CF-38 summary). Chapter cards = Topic/Chapter Card (whole card opens story flow; ⋯ 编辑章节/复制/删除; trailing handle). One Add Row "＋ 添加章节" + quiet "添加序章". Bottom bar = 保存草稿 + 下一步 only. Screenshots OK. |
| CF-31 (map view part) | `237:32444` 地图视图 | **Done.** Full-bleed map, glass status row with segmented 地图 selected, selected pin ring + 1.15, Map/Locate, node card as a fit sheet (编辑节点 / 看故事流), no toast. Screenshot OK. `238:22215` (节点地图选点) **not done**. |
| CF-21, CF-18 (C1 loading/error), CF-22 | B1 `237:21622` (SignedOut state), `237:21650` (skeleton mirroring the 创作页, no scrim, no card), `237:21681` (inline Error: 主题没加载出来 / 网络没连上，请重试 / 重试 — Q-E default), `237:21719` (toast 已恢复本机草稿 · 14:02), `237:21833` (Confirm Dialog with times, newer marked, 7-day recovery — also CF-78 copy), `237:21953` (destructive dialog 仍要返回 / 继续编辑), `237:22073` (locked: info banner + lock rows, no alert, no handles), `237:22192` (red banner "这次没存到云端" + 重试, chip 保存失败), `237:22339` (toast 已移到待编排 · 撤销) | **Done**, all on the new B2 base. Screenshots OK. |
| CF-34, CF-11 | B3 `237:51012`, `237:51154`, `237:51305` | **Done.** Fit sheet over the new 创作页 with Editor/Sheet Header (✕, "使用此模式", eyebrow 主题模式), Option Row Card × 2 (neutral selection, no green). `51154` uses Confirm Dialog (复制并切换). `51305` is now the copied draft page with an info banner "已复制为新草稿 · 还需要重新选… · 去设置" instead of an alert. |
| CF-23, CF-12 (story flow is a page) | B4 `237:51424` (empty chapter, seam expanded with hint), `237:65700`, `237:51859` (seam expanded between blocks), `237:65956` (text selected; styling only in the keyboard accessory bar; in-block chip row gone; keyboard not drawn), `237:66174` (image selected: 版式 row + 说明 field), `237:66404` (待编排 placement: banner + seams between every block), `237:66638` (end seam expanded), `237:66866` (完成方式 pop-up menu open) | **Done.** Page with Editor/Nav Bar "第一章 · 故事流" + 预览, save chip "改动自动存到本机", blocks as white cards with Editor/List Item header (type · ⋯ · trailing handle), Story/Seam, one primary 下一步 (no header 完成). Scrolled frames get a nav backdrop. Screenshots OK. |
| CF-24, CF-76 | `237:67108` (full, now 3045 high), `249:38071` (首屏) | **Done.** 文字效果 = 4 Sample Tiles rendering 钟声 (正常 / 偶尔闪 / 褪色错位 / 等宽字); 氛围 = 5 Swatches; 内心声音 = voice tiles + segmented 所有人 / 满足条件的人; branch destinations are Editor/PopUp per option; no "可选：…" sentences, no numeric codes. Screenshots OK. **Left:** the full frame grew; its notes/label below need re-stacking and section `237:51423` needs its height grown (tidy pass not run). |
| CF-25, B4.10–B4.15 | `237:67490` `237:67711` `237:67919` `237:68146` `237:68581`; delete `237:68363` | **Not done** — the call was written (in this log's scripts) and was the one refused by the rate limit. |

## Not started (rate limit)
CF-25 (B4.12–15, `238:21479`, `239:27044`), CF-26 (B6 chapter settings), CF-27 (B7 topic detail), CF-28 (text pop-ups), CF-29 / CF-30 / CF-31 (`238:22215`) / CF-32 (B5 node sheet, template picker, rules), CF-33 / CF-35 / CF-36 / CF-37 (B7.x sub-editors), CF-38 / CF-39 (B8 ticketing, native date pickers), CF-40 / CF-41 / CF-17 (B9 publish), CF-42 / CF-43 (B10), CF-12 for B5/B6/B7/B10 sheets (sub-editors pushed with ‹), CF-13 Large companion frames (分支任务, 插入变量, 节点编辑, 章节设置, 票种编辑器, 选择奖励, 选择合作者), raw C1 field frames in B5–B10 → Editor/Field, B4.7 story sheets (`238:10350`) re-based on the new story-flow page, section tidy (notes under grown frames).

## Owner defaults used
Q-B (regroup into lists / pushed pages): yes — applied in B2 only so far. Q-E (handbook failure wording): yes — `237:21681`.

---
## Day 2 · 2026-11-16 (resumed under the 90-call budget; stop at 85)
Figma call count today: **24 of 90** (final).

| CF | Frames | Result |
|---|---|---|
| CF-25, B4.10–B4.15 | `237:67490` (drag), `237:67711` (drag into paragraph → split), `237:67919` (undo toast, node gone), `237:68146` (permanent delete asks once: Confirm Dialog), `237:68581` (⋯ menu 上移/下移/复制/移到待编排/删除节点); `237:68363` + label deleted (text blocks never ask); B4 section notes re-stacked | Done (call 1) |
| CF-29, CF-12, CF-25, CF-31 | B5.1 `238:19720` `238:20056` `238:20393` (full, .large) `249:38453` (首屏 + shared-template confirmationDialog) `238:20772` `238:21136` `238:21479` (permanent delete dialog) `238:21851` (red title + inline error, no toast) `238:22215` (map pick pushed at .large: Map/Search, lifted centre pin, Map/Locate, 用这个位置) | Done. Node sheet = one sheet over the story-flow PAGE at .fraction(0.62); title is the name; Node/Gameplay Card; locked resource row with footnote; quiet red 删除节点. |
| CF-30, CF-12 | `239:2948` `238:22593` `238:22885` | Done. Pushed (‹) at .large; G6/Gameplay Icon rows with 看点 line; header 完成 commits, no 确定 bar; inline failure with 重试; skeleton rows. |
| CF-32, CF-34 | 到达与引导 `239:3280` `249:38831` `239:3768` (red sheet banner + field errors) `239:4264` (unsaved-node block removed: fresh page) | Done. Multi-select = Option Row List (check marks); scan warning = row 扫码配置 with red dot. |
| CF-32, CF-33 | 下一站 `239:4607` `239:5014` `249:39318` `239:6450` (drag) `239:5505` `239:5982` `239:6886` `249:39808` | Done. Rules are Rule/Sentence with Editor/Token (Error token for unset); trailing ⋯ + handle; one dashed add row; quiet red 删除这组条件. |
| CF-26, CF-25, CF-12, CF-13 | B6 `239:24873` (full, .large) `249:40292` (.medium opening detent = CF-13 pair) `239:25247` / `249:40665` (same pair) `239:25461` `239:25642` `239:25811` `239:26091` `239:26351` (over the story-flow page, one sheet edge) `239:26778` (alert → banner) `239:27044` (删除第三章？2 个节点会移到待编排) `239:27314` (native menu) | Done. Root = 名称, 完成要求 (+ stepper), 配色 swatches, 奖励, 更多设置 chevron rows, 设为结局 switch, quiet red 删除章节. |
| CF-27, CF-28, CF-39 | B7 `239:31923` (full) `249:40880` `239:32500` (red dots on required) `239:32749` / `249:41456` (error inline under 通关条件, legacy footnote) `239:33192` (清空本地草稿 moved to 创作页 ⋯ + dialog) `239:33463` (name edited in the header slot, counter) `239:33587` `239:33711` (pushed editors, live counter, AI 助写 secondary) `239:33835` (native compact time pickers, one 完成) | Done. Grouped list 基本信息 / 玩法规则 / 数值与状态 / 奖励 / 高级, no verb pills, cover thumbnails in rows, support note removed. |
| CF-36, CF-12 | B7.2 画面风格 `241:1680` `249:41900` `241:2059` `249:42278` `241:2475` `249:42693` `241:2854` `249:43071`, 风格预览 `241:3231` | Done. Pushed (‹) at .large; persistent 预览 row at the top; the four existing style thumbnails kept; style options as segmented / pop-up; 主题配色 swatches; 字体 tiles render 城瘾 in their own face (Long Cang 手写, Noto Serif SC 宋体, LXGW WenKai TC 楷体, Noto Sans SC 黑体); 文字动效 and 转场 = paged Sample Tile rows + 全部 N 种 ›. |
| CF-35, CF-34, CF-33, CF-12 | 伏笔 `241:3540` `241:3821`; 自定义数值 `241:4114` (quiet red row, empty card gone); 归零后 `242:1967` `242:2287` `242:2589` (inline error) `242:2890` (legacy read-only line) `242:3169` (native menu); 进行方式 `242:3471` (Option Row Card, neutral); 运行结局 `242:3777` (list items ⋯ + handle, Switch Row 设为默认收尾) | Done. |
| CF-33, CF-35, CF-37 | 休整/配给/设施/结果卡 `242:4102` `249:43447` `242:4500` `242:4824` `242:5141` `249:43844` `242:5534`; d20 `243:5502` `249:44236` (each switch has a footnote saying what "on" does); 高级规则 `243:5918` `249:44651` | Done. Delete = one quiet red row per module; conditions as Rule/Sentence. |
| CF-12, CF-37, CF-33 | `243:6286` `243:6646` `243:6962` (renamed "B7.9b2 → 选择奖励（推入同一张 sheet）": pushed, no stacked sheet) `243:7267` `243:7558` `243:7832` `249:45018` `243:8206` `249:45391` (inline error) `243:8571` `249:45755` (属性 / 属性版本, consent = switch row 使用这套属性) `243:8923` `243:9240` `243:9590` | Done. |
| CF-38, CF-39, CF-17, CF-13 | B8 page `246:5536` `249:46117` `246:5687` `246:6396` `246:6568` `249:46779`; ticket sheet `246:5882` (.large) / `249:46267` (.medium), `246:6169` / `249:46553`, `246:7094` / `249:46938` (errors inline, 价格 field with 积分 suffix); date pickers `246:6728` `246:6908` | Done. One back (nav), ticket rows = Editor/Row (name + 积分 · 张), ticket editor is a sheet, bottom bar 预览 + 发布 (发布 enabled with missing data: banner says it jumps to the first item). Custom wheels deleted; fit sheet holds a labelled placeholder for the system DatePicker(.graphical) + compact time pill (no iOS kit picker exists in this file); the end picker's range blocks invalid times (no toast). |
| CF-40, CF-41, CF-17 | B9 `249:16472` (full) `249:47215` `249:16773` (blockers, 发布 stays enabled) `249:17076` `249:17706` (check runs inside the pill: "◌ 检查中", modal card gone) `249:17998` `249:17369` (阅读剧情 pushed) `249:18596` (one confirmation with real summary) `249:18913` (toast above bar) results `249:19029` `249:19340` `249:19653` `249:19962` `249:20272` `249:20582` (Editor/Result, no ✕) `249:32506` (inline name error, no toast); **deleted** `249:18299` (发布前提示 alert) + label | Done. Pill says 发布; passed checks collapse to one row; settings read-only with 修改 ›. |
| CF-42, CF-43, CF-12 | `249:32604` `249:32735` `249:32865` `249:32995` (entry sheets in MP-Dark over the player page, one header without 完成, locked rows say why) `249:33124` `249:33404` (pushed) `249:33706` (地点待办 quiet rows, one primary) AI 助写 `249:33879` `249:34151` (shimmer) `249:34423` `249:34699` `249:34974` (button visible but disabled + "今天的 5 次已用完，明天 0 点恢复") 合作者 `249:35244` `249:35539` ("无法邀请" with reason; skeleton row instead of "正在加载…") | Done. |
| B4.7 + CF-13 | `238:10351` `238:10642` `238:10960` `238:11297` `238:11545` `238:12236` re-based on the new story-flow page (one sheet edge); branch 去向 = Editor/PopUp (CF-76); Add Row with 3/3 limit. **New Large companions:** `305:39123` (分支任务 .large), `305:39278` (插入变量 .large), `305:39368` (选择合作者 .large); rows to their right shifted by 513 | Done. 弹窗预览 `238:11777`–`238:12156` untouched (CF-75 is batch G). |
| Tidy | All C1 sections: notes re-stacked under their frames (109 notes), section heights grown, sections re-stacked vertically so none overlap; audit: 0 raw `input` / `button/pri` / `toggle` frames left in C1 screens, 0 frame overlaps | Done. |

### Left (not in batch C or deliberately skipped)
- `238:11777`–`238:12156` popup previews and `249:35825` 章节闸 (player-facing; CF-75 / batch G).
- No Apple iOS-kit DatePicker component exists in this file, so the graphical calendar is a labelled placeholder (CF-39 says not to draw a custom one).
- Base layers under sheets are clones of the new pages (static copies); if a page is redrawn again, its clones under sheets need a refresh.
- Batches F (motion annotations / prototype links) and G (contrast, Dynamic Type, labels, copy) not touched.
