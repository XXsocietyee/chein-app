# Config revision · Batch D (C2 玩法配置 · 模板编辑) · execution log

Executor: Opus 5.5 · task `task_1d65a3efa589` · 2026-11-15 · file `0YyoybGnU1KG0657wdGCPX` · page C2 `235:178` only (plus additions to the Editor kit section `276:295` on Library `6:3`).
Plan: `review/full-config.md` sections 2, 3, 4 (batch D), 6 (owner defaults Q-A to Q-E used as stated).

**Status: done for CF-44 to CF-57 and the C2 leftovers.** Session 1 stopped at the Figma MCP rate limit. Session 2 (2026-11-16, RESUME) used **16 of the 55 allowed Figma calls** (running count below). The one item left is optional and listed at the end.

## Kit additions (Library `6:3`, section `276:295`, column at x 5609; existing Editor/* left unchanged)

| Component | Node | Variants · properties | For |
|---|---|---|---|
| Editor/Section Bar Item | `290:16267` | State Default/Current/Error/Done · label | CF-44 |
| Editor/Section Bar | `290:16299` | 6 exposed items (信息 · 规则 · 玩法 · 反馈 · 奖励 · 工具), 393×44, sticky at y 100 | CF-44 |
| Editor/Card | `290:16320` | Collapsed=true/false · title, summary, showError | CF-44 |
| Editor/Number Row | `290:16350` | Control=Field/Stepper · label (exposed Field Kind=Number / Stepper) | CF-47 |
| Editor/Card Footer | `290:16420` | Unlimited=false/true: 次数上限 (stepper) → 不限次数 (switch) → 奖励 (number, 积分) | CF-47, CF-48 |
| Editor/ReadOnly Group | `290:16441` | lock + 旧设置，保存时原样保留 + 5 label/value rows (rows 2–5 optional) | CF-57 |
| Editor/Answer Option | `290:22102` | Kind Single/Multi/Survey × State Collapsed/Expanded/Error × Correct (15 variants) · text, showThumb, error | CF-46 |
| Editor/Tool Chip | `290:22123` | State Available/Added/Blocked · label | CF-53 |
| Editor/Popover | `290:22135` | title, body, action | CF-53 |
| Editor/Result | `290:22148` | title, body, primary, secondary, showSecondary | CF-52 (CF-41 shape) |
| Editor/Preview Tile | `290:22166` | Selected true/false · label | CF-54 |
| Shared/Reward Picker | `290:22217` | sheet: header 选择奖励 ✕/完成 · segmented 优惠券 \| 体验卡 · check-mark list · dashed ＋ 新建优惠券 | CF-54 |

New, not a fork: Editor/Answer Option is a separate component because Editor/Option Row is the pick-one row used inside sheets. The batch-C executor added Editor/Save Chip (`290:20194`) to the same section at the same time; there is no overlap.

## Done on C2

| CF | Frames / nodes | Result |
|---|---|---|
| CF-46 options | 136 option list items → Editor/Answer Option on 45 frames: every page frame in A1/A2 (3 options each), A4 `238:16749` (single, option 1 expanded), `238:16930` (multi, 2 correct), `238:17139` (survey), `238:17275` `238:17563`, `238:23751` `238:23850` (猜图), `238:23952` (盲品), `238:24917` `238:25111` | Done. Shot: `238:16749`, `238:23952`. Issue: the 盲品 option texts were lost during the swap and rewritten as `A · 冰美式 / B · 桂花拿铁 / C · 海盐芝士` (they need checking against the source). **Not done:** 人物指认 as a people row plus a pushed sub-page; legacy `239:23200` and `239:23321` (different structure). |
| CF-47 / CF-48 numbers | 89 cards: `dd row/次数上限`, `field/次数上限*`, `field/奖励分` → one Editor/Card Footer at the end of the card (split footers merged in `238:24355` `238:24406` `238:24466` `238:24518` `243:25306`; G2 `239:20066` `239:20118` `239:20166` 提交次数上限 folded in). 43 label edits: units moved from the label into the field suffix (秒 / 度 / 分 / 条 / 积分), 毫秒 → 秒 with value ÷1000 (`243:24405`, `243:24473`, `243:25232`), DC → 难度值 (`243:23964` `243:24053` `243:24173`, `237:73177` `237:73454` `237:73983`), 奖励分 → 奖励 + 积分 (A11.3 `238:12643`–`238:13611`). Stale hint "0 表示不限，最多 10 次" removed (`243:25232`). | Done. Shot: `243:25232`, `238:24355`. |
| CF-44 outline | 50 editor frames transformed by one script (`d/cf44.js` in the worker scratchpad): 16:9 cover with the title over a bottom gradient (title input removed; title errors kept under the cover, e.g. `237:60884`); sticky Editor/Section Bar at y 100 with Current / Done / Error per frame; an opaque nav background; valid cards other than 玩法设置 collapsed into Editor/Card with generated summaries; expanded headers get a chevron; 可触发的结果 and 需要的资源 moved into 玩法设置 as read-only chips. Full frames: `237:43689` (4940 → 2294), `237:46330`, `237:45599`, `237:47990`, `237:53447`, `237:54277`, `237:55116`, `237:55926`, `237:57539`, `239:20236`, `239:30205`, `239:28271`, `239:28627`, `237:43424`, `237:57337` (the last two are new templates: nothing collapsed). Crops are re-anchored to their original scroll position (+44 for the bar), and the sections in view stay expanded: `237:44143` `237:44507` `237:44871` `237:45235` `237:46007` `237:46789` `237:47181` `237:47587` `237:48454` `237:53908` `237:54742` `237:55565` `237:56530` `237:57453` `237:58011` `239:20526` `239:28477` `239:28766` `239:30547`, plus A1 states `237:59972` `237:60429` `237:60884` `237:61028` `237:61483` `237:61597` `237:62048` `237:62464` `237:62926` `237:63388` `237:63852`. | Done. Shot: `237:43689`, `237:44871`, `237:60884`, `237:48454`. **Left:** the editor bases under sheets (A3, A5, A8, A10, A11, A12 save) still show the old 1:1 hero (mostly covered by the scrim and sheet); the canvas notes of the shrunk full frames still sit at the old frame bottoms and need restacking. |
| CF-45 preview | Bottom bar 查看预览 → 预览 on all transformed frames; 试玩 text button removed from every body; A5 试玩 cards removed (`237:14274` `237:14385` `237:14540` `237:25477` `237:25577` `237:25689`). The three A2.10 toast frames `237:56966`, `249:36634`, `249:37089` were deleted (A2 row repacked) and replaced in A12 by `291:80402` A12.0a 还要再填, `291:80453` A12.0b 相册没有照片, `291:80504` A12.0c D20 在旅程里掷骰: Editor/State on the dark preview base at step 3/5 with `去填写 ›`. | Done. Shot: `291:80402`. |

## Session 2 (RESUME, 2026-11-16) · Figma call count: 16 / 55

| # | Call | CF | Frames / nodes | Result |
|---|---|---|---|---|
| 1 | use_figma | CF-51 | 10 选择玩法 frames `237:71933` `237:72185` `237:72437` `237:72643` `237:72910` `237:73177` `237:73454` `237:73731` `237:73983` `237:74256` | Row list → 2-column grid of G6/Gameplay Preview tiles (158 wide, name + 2-line description). Selected = 1.5 pt border + black check. Unavailable types sit in one `这个主题里用不了 · N 种` row (expanded with the reason once in `237:73983`). A dot on the category chip marks the pick; footer 预览 → secondary 试看. Missing descriptions written: 闭眼盲品 "闭上眼尝一口，猜是哪一款", 今日城市签 "每天抽一支城市签，看看今天的运势". G6 type mapped by list order. |
| 2 | get_screenshot | CF-51 | `237:73983` | Found the group row and reason not full width → fixed in call 3. |
| 3 | use_figma | CF-51 fix + read | group rows 361 wide; structure dump for CF-49/52–57 | OK |
| 4 | use_figma | CF-49, CF-52 | `239:22352`, `239:22435` (卡片 ID fields removed; error frame repurposed as **A4.16 翻卡 · 卡片名为空**), `239:27826`, `239:27886` (ID fields name/job/clerk/watchman removed; `counter.instability` → PopUp 不安; `{picked}` `{assigned}` → 〔选中的项〕 〔分配的角色〕), `237:33571` (counter.energy → PopUp 能量), `239:23486` (raw JSON field → row `查看原始配置 · 只读`); `239:20809` `239:20874` result sheets → Editor/Result (继续编辑 / 回到我的玩法; 查看玩法 / 完成; "大约 3 分钟后可以在模板库里看到。") | OK |
| 5 | use_figma | CF-49 fix + read | `237:33571` hint text "变量名，如 …" → 从主题的数值里选; tag hint stripped | OK |
| 6 | use_figma | CF-57, 53, 54, 55, 56 | CF-57: Editor/ReadOnly Group in `239:23106` `239:23417` `237:58011` `237:57539` (`旧X：Y` lines → label/value rows) and `243:25926` (类型 row). CF-53: `237:64541` `237:64724` pills → Editor/Tool Chip (Added / Available / Blocked + icons); red hint line in `237:64541` → Editor/Popover under the blocked 投票与投入 chip; `237:25689` toast → inline error on 效果作用于; `237:74836` (unsupported tool opened as a sheet) **deleted** with its label and the A10 row repacked, because unsupported tools are no longer offered as a sheet. CF-54: `237:53314` sheet → Shared/Reward Picker instance; 勋章样式 pop-up → two Editor/Preview Tile (二维发光 / 3D 珐琅) in `237:52843` `237:52934` `237:53023` `237:53114` (renamed **A8.5 完成奖励 · 勋章样式（选 3D 珐琅）**, dropdown removed) `237:53214`. CF-55: base of `238:15880` `238:15942` `238:16017` rebuilt from `241:20710` (难度 = drop-down per owner Q-D, dashed ＋ 添加加值). CF-56: blue tiles → G6/Gameplay Icon in `238:12379` `238:12462` `238:12545`. | OK |
| 7 | use_figma (composite screenshot) | check | `237:64541` `237:52843` `239:23106` `238:15880` `239:20809` `239:27886`; medal art filled from asset board `284:63807` | OK. Found leftover 查看预览 labels on frames the CF-44 pass did not touch → fixed in call 8. |
| 8 | use_figma | leftovers | 查看预览 → 预览 page-wide (118). CF-18: `237:59761` SignedOut, `237:59795` Loading skeleton (no scrim / card), `237:59829` `237:59864` `237:59899` Error, `237:59934` → Editor/State centred at 40%. CF-17: `237:63852` bar → "这是别人的模板，只能查看" + black `去模板广场选用`, toast removed. CF-16: `237:56530` "最多 12 步" toast → Add Row State=Limit `12/12`; `237:55565` `238:15824` "移除成功" toasts removed. CF-12 scan: no C2 frame has two sheet headers. Notes restacked under resized frames (14). | OK |
| 9 | use_figma | CF-13 + text fix | Large companions: `237:64911`→`310:26958`, `237:69390`→`310:26814`, `237:69781`→`310:26672`, `237:70572`→`310:26510`, `238:12643`→`310:27106`, `237:25791`→`310:27346`, `237:33216`→`310:27174` (sheet top at y 54, same scrim). Fixed the SignedOut / 采用尚未确认 state copy. | OK. 选择玩法 has no Large companion because its frames are already drawn near full height. |
| 10 | use_figma | CF-50 | New **Gameplay/Param Visual** set `311:23431` (G6 section `255:14133`, x 920): Kind steps / react / shake / quiet / compass / shout / countdown / stopwatch / typeIn, 332 wide, monochrome, caption prop. Placed under the title of every challenge card in `241:20608` (17 frames: 计步 `243:24265` `243:24334`, 变色 `243:24405` `243:24473`, 弹球 `243:24543` `243:24610`, 安静 `243:24682`, 罗盘 `243:24749` `243:24841` `243:24934`, 喊 `243:25029`, 倒计时 `243:25096` `243:25163`, 停表 `243:25232`, 输入 `243:25306` `243:25394`); 计步 "以「健康」App…" disabled input → footnote with heart icon. | OK (G4 retried in 11) |
| 11 | use_figma (composite) | CF-50 check | 4 stray text nodes from the failed G4 attempt removed; screenshot `243:24749` `243:25232` `243:25634` `237:63852` `237:59761` `310:26958` | Found captions all showing the default and G4 not matched → call 12 |
| 12 | use_figma | CF-50 fix | per-kind captions on 16 instances; G4 `243:25478` `243:25544` `243:25634` `243:25705` `243:25782` `243:25853`: grey disclaimer box + "配置数值有效…" line → one footnote "仅预览，不会录音、计步、上传或申请权限。"; black 预览传感器配置 → secondary `试看传感器` | OK |
| 13 | use_figma | CF-46 | 人物指认 `238:17275` `238:17563`: three 385 pt person blocks → Editor/Row (chevron) rows + `＋ 添加人物`; new pushed page **`311:32275` A4.4b 人物指认 · 人物详情（推入）** (nav title 钟表匠老周, person card, red `移除这个人物`), inserted after `238:17563` with the row shifted | OK |
| 14 | use_figma | CF-46 | legacy `239:23200` `239:23321`: A/B/C option rows → Editor/Answer Option (key · text, filled control = correct); label → 选项; "最多 4 个选项" toast → Add Row State=Limit | OK |
| 15 | use_figma (composite) | check | `238:17275` `311:32275` `239:23321` `243:25634` `237:72437` `311:23431` | OK; person row values fixed in 16 |
| 16 | use_figma | tidy | person rows 已填写 / 未填写 (error frame: 仓库管理员 · 还没写证词 + dot); notes restacked; sections fitted; 0 stray page nodes | OK |

## 闭眼盲品 (A4.7) option texts
The original option labels are not recorded in any review note, build JSON or source. The spec (`review/r1-theme-gameplay.md` A4.7) only fixes the shape: each option = **key (A, B…) + player-facing label**, 2–6 options, default answer A. The contract vector (`chengyinhub-admin … content-contract-v1-vectors.json`, section-blindTaste) uses `a 咖啡 / b 茶`. The frame's `A · 冰美式 / B · 桂花拿铁 / C · 海盐芝士` follows that shape and suits the 向店员领盲品小样 step, so it was kept. Change it if the owner has the real list.

## Left (optional, not in the plan's frame list)
- Editor pages drawn **under sheets** (A3, A5, A8, A10, A11, A12 save bases) still use the old 1:1 hero and have no section bar. They are almost entirely covered by the scrim and the sheet. Run `revise/cfg-D-cf44.js` on them if batch F needs pixel-consistent bases.
- Param Visual captions are fixed sample copy per kind. Binding them to each card's live values is a code concern (SwiftUI reads the numbers).
- Copy flagged for batch G: 倒计时 description "一钟油，时间走它就退" (typo in source), load-failure strings (CF-70).
