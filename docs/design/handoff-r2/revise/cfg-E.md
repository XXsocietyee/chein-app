# Config revision · Batch E (C3) · execution log

Executor: Opus 5.5 · task `task_66b96b0b0ec3` · 2026-11-15 · file `0YyoybGnU1KG0657wdGCPX` · page C3 `235:13237` only.
Plan: `review/full-config.md` (sections 2, 3, batch E, section 6 defaults). Every changed frame was checked with an inline screenshot after its change.

**Stopped early:** the Figma MCP tool-call limit (Education plan) was reached, so the work stopped partway through. One known defect remains (see "Open defect"). The "Left" list below shows what wasn't done.

## Kit additions (Library `01 Components` 6:3, section `276:295`, left column under Editor/PopUp)

| Component | Node | Why |
|---|---|---|
| `Editor/Step Bar` | set `290:6017` (Step=1 `290:5987`, 2 `290:5997`, 3 `290:6007`), doc `290:6018` | CF-58. 3 segments, 44-high targets, label1-3 text props. The description carries the motion (350 ms slide, 220 ms fill). Library `Step Progress 15:334` has no labels, so it wasn't reused. |
| `Editor/AI Draft Card` | set `291:57324` (Generating `291:57269`, Ready `291:57288`, Failed `291:57306`, Recovering `291:57314`), doc `291:57333` | CF-59. Props: title, eyebrow, body, primary, secondary, showSecondary. Motion is in the description. Note: text-prop defaults are shared, so every instance sets its own copy. |
| `Editor/History Row` | `291:57325`, doc `291:57334` | CF-59. Props: title, time, status (只读 / 本机), showDivider. |

No existing Editor/* component was changed. `Ticket/Row` was **not** created. Ticket rows use `Editor/List Item` (title + meta `39 积分 · 20 张` + ⋯ + handle) so this batch doesn't clash with batch C's CF-38.

## Results

| CF | Frames | Result |
|---|---|---|
| CF-58 发布活动 | Step 1: `237:59431` `237:59532` `237:59657` `238:19444`. Step 2: `238:14231` `238:14318` `238:14405` `238:14501`. Step 3: `238:14596` `238:14747` `238:14857` `238:14996` `238:17887` `238:18023` `238:18118` `238:18242` `238:18325` `238:18475` `238:18584` `238:18736` `238:18847` `238:19000` `238:19113` `238:19278` `238:19557` | Done. The in-content large title and dot stepper are gone. `Editor/Nav Bar` was re-instanced with its title (发布活动 / 编辑活动), because the old instances had lost their title text node. `Editor/Step Bar` sits under the nav, the content is in a `scroll (clip)` frame, and `Editor/Bottom Bar` holds 取消 or 上一步 plus the primary. Fields are `Editor/Field` OnGrey. Times and type are `Editor/Row` chevron rows in white cards. The cover is a 16:9 slot the width of the card, in 4 states (filled / uploading 62% / failed + 点此重试 / empty-error dashed). Step 3 order: 合作者 card (avatar rows, 主理人 tag, ⋯, `＋ 添加合作者`), then 票单 as `Editor/List Item` + `Editor/Add Row` with a `2/10` count, then (when needed) the 发布者实名 row, then the 发布前摘要 / 修改摘要 card last. Submit failures are a red banner at the top of the content. Toasts removed: `287:43098` (已售出, the lock note stays as help text) and `287:43100` `287:43102` (已添加: 小鹿). Prices use 积分. |
| CF-58 real-name | `238:18023` renamed **C2.15 第3步 · 发布者实名 · 实名页（push）** (label updated) | The step-3 page shows a `发布者实名 · 待填写` row (red). Its pushed page has fields 真实姓名 / 身份证号 and an `Editor/Switch Row` consent (Off) instead of the square checkbox, with primary 完成. |
| CF-58 under-sheet bases | `239:625` `239:771` `239:919` `239:1084` `239:1210` `239:1333` `239:1509` `239:1632` `239:1749` `239:21290` `239:21462` `239:21619` `239:21768` `239:21916` `239:22084` | Done. The base pages behind the sheets now use the new layout. The 时间设置完成 toast `287:43104` was removed from `239:771` (CF-16). |
| CF-17 | `237:59532` `238:14501` `238:14857` `238:14996` `238:17887` `238:18023` (the 6 发布活动 frames), plus AI D8 `239:29100` `239:29304` | Done. The primary is always enabled (black), and errors show inline under the field or row. D8: the 请逐个确认地点 toast `287:43108` was replaced by an inline error above the now-enabled primary. **Not added:** a canvas note for the scroll-to-first-error / shake / `.error` haptic motion (batch F). |
| CF-59 AI 快速创建 | Input/state: `239:24018` `239:24151` `239:24276` `239:24415` `239:24557` `239:24700`. Recovery: `239:29913` `239:30881` `239:30054` `239:31022`. Results: `239:28946` `239:29100` `239:29304` `239:29508` `239:29710`. Sheets: `239:31173` `239:31330` `239:31468` `239:31606` | Done. Prompt-first layout: a 想玩一条什么样的路线？ intro, 试试这样说 suggestions, then a single 偏好 row of 6 Library `Chip`s (scrolls sideways) with 更多 ›. State cards use `Editor/AI Draft Card` (D4 Generating, with the send button turned into a stop square; D5 Failed 重试; D5b / D9 Recovering 等它完成 / 重新起草, with 查看 turned back into the send arrow; D6 quota as Failed + 手动创建, chips disabled). The two record rows became one `起草记录 · 3 条` row at the end. In D3 empty-send, the toast became an inline red hint above the composer. D7/D8: categories were removed and the record row moved after the result. D10 sheet: `Editor/History Row` list, close header, no bottom 取消, fit height. The nav title was fixed across the AI section. |
| CF-61 templates | No-cover art: `243:1964` `243:3025` `243:3137` `243:3249` (hero cards `243:2009` `243:3071` `243:3184` `243:3294` + thumbs) | Done. The route glyph was replaced by the default 一起玩 art (`img/club_cover_default`, hash `a30e807f…`) with a bottom shade, and the text is `on-media`. 实验预览 · was dropped from 3 meta lines. |
| CF-61 应用 primary | `243:26024` `243:26211` `243:26367` `243:26529` `244:16979` `244:17123` `246:2745` `246:2956` `246:3024` `246:3092` `246:7378` | Done: `cta` / `cta-ink` (white pill on dark). `246:2928`: the 正在配置 toast was removed, and the button reads 正在应用 with a spinner. |
| CF-61 采用条件 | `246:2717` `246:7367` | Done. The 4 unknown rows collapsed into `还有 4 项信息待补充 · 查看 ›` (`291:70274`, `291:70278`). |
| CF-61 我的节点玩法 | `246:7461` `246:8088` `246:8549` `246:9012` (10 cards each) | Done. The 评分 / 个人审核 / 模板广场 / 时长 / 创建时间 rows were replaced by one meta row: Library `Tag` for review (审核中 Warn / 草稿 / 已通过 OK), Tag for the square (未上广场 / 已上广场 OK), and the date `11月14日`. List positions were re-anchored, and the ⋯ menu in `246:7461` was re-anchored to the first card. |
| CF-62 external games | Library header: `247:17370` `247:17427` `247:17464` `247:17512` `247:17565` `247:17619` `248:3258` `248:3357` `248:3448` | Done. Title `小游戏库` with two 44 circles: ＋ (a pull-down; the menu `247:17454` is now 链接导入 / 扫码导入 / 从文件导入) and ⋯ (提交审核 / 我的提交). The red trash icons were removed (delete becomes swipe). |
| CF-62 sheets | `247:17464` `247:17512` `247:17565` `247:17619` (导入外部游戏, grabber), `248:3258` `248:3357` `248:3448` (确认导入 / 确认更新, large-only, no grabber), `248:3864` (举报, Trailing Done 提交) | Done. The blue 取消 / title / action nav was replaced by `Editor/Sheet Header` (dark tokens). The confirm sheets get a pinned bottom bar with Library `Button` Primary block 确认安装 / 确认更新. Permissions are icon rows 存档 / 触感 / 声音 with grey detail + ✓. BROKEN → 无法运行. |
| CF-62 tint | Whole section `247:17368` | Done. 64 `link` (blue) fills and strokes were rebound to `ink` (white on dark). 保存并提交审核 is a white pill in `249:24688` `249:24757` `249:36244` `249:36313`. `¥12.60` → `1,260 积分` (积分 is the only currency; **the number is a placeholder**, because the real conversion is unknown). 我的提交 `249:24548` `249:24653`: status is now a Tag (审核中 / 未通过 / 已通过), and the empty `—` / `驳回原因 —` lines were removed. |
| CF-10 leftover (raw C3 fields) | D8 cy-card `292:81864`…`292:81934` (4 frames); import `292:81944` `292:81954` `292:81964` `292:81974` | Done. Field and textarea frames are now `Editor/Field` (OnCard in the AI card, OnGrey in the import sheet). Import errors moved into the field's Error slot, and the separate result row was removed. The 发布活动 fields were done under CF-58. Search bars (`cy-search`, `search`) were left as search controls. |
| CF-13 Large frames | `291:49240` 活动类型 · Large, `291:49379` 我的模板 · Large, `291:49554` 选择合作者 · Large (all in the sheets row of `237:58979`, x 7775–8801; section widened to 9274); `291:49687` D10 选择原起草记录 · Large (AI recovery row, x 4184; section widened) | Done. Each sheet sits at the top detent (y 59), the list is extended so the inner scroll shows, and the label reads `…（拖到最高 · 内部滚动）`. `243:2078` 全部分类 and `247:17464` 导入外部游戏 were already drawn at Large, so no companion was added. |
| CF-12 (C3) | — | **Not assessed.** No C3 frame was checked for stacked sheets; the stacked frames listed in the plan are all C1. |

## Open defect (FIXED 2026-11-16, see resume session)
- `247:17512` F2.3 导入 · 二维码内容: field `292:81954` is in **State=Error** with help 签名清单已通过，可预览权限. That message is a success, so it should be `State=Filled` with the help shown. The rate limit hit on the call that fixes it.

## Left (not done)
- Swipe-to-delete state + `confirmationDialog` for a library row (CF-62) isn't drawn; only the trash icons were removed.
- Monetization values have neutral colour, but no ⌃⌄ pop-up accessory (CF-62).
- Install motion (confirm pill fills as progress, row slides in) isn't annotated (batch F).
- CF-17 motion note (scroll 300 ms, 3 × 6 pt shake, `.error`) isn't on the canvas (batch F).
- The result sheets in `238:19113` `238:19278` still show `2026-11-21 19:30:00 · 2 个票种` (batch G copy).
- `239:625` `239:771` still have the hand-drawn date picker (CF-39 belongs to batch C, but these frames are on C3).
- `246:2996` 使用模板失败 toast and the `246:3064` staff read-only bar weren't reworked.
- AI "full" twins `239:30881` `239:31022` now have empty space below the content (the new layout fits in 852).
- No blue `note:<id>:detent` boxes for the 4 new Large frames (the detent is in their labels).

## Resume checklist (in order, when Figma access is back)
1. `247:17512`: set field instance `292:81954` to `State=Filled` (keep showHelp + help 签名清单已通过，可预览权限). Screenshot to verify.
2. CF-12 on C3: check every C3 sheet frame for a sheet on a sheet. If one exists, redraw it as one sheet with a pushed sub-page (`Editor/Sheet Header` Leading=Back).
3. CF-62: draw one library row in `247:17370` in the swiped state (red 删除) plus a `confirmationDialog` frame. Add a ⌃⌄ pop-up accessory to the 定价模式 / 流量激励模式 / 通道手续费 values in `249:24688` `249:24757` `249:36244` `249:36313`.
4. Copy: in `238:19113` / `238:19278`, change the result line `2026-11-21 19:30:00 · 2 个票种` to `11月21日 19:30 · 2 种票`.
5. `246:2996`: replace the 使用模板失败 toast with an inline failure in the 应用 area. `246:3064`: replace the read-only bar with one sentence + one useful action (CF-17).
6. Optional: native graphical DatePicker in `239:625` / `239:771` (CF-39 is batch C scope, but these frames sit on C3). Blue `note:<id>:detent` boxes for `291:49240` `291:49379` `291:49554` `291:49687`. Trim the empty space in AI full twins `239:30881` `239:31022`.
Status as of the stop: no Figma calls after the rate-limit error. Everything in the Results table above has been applied and screenshot-verified.

## Resume session · 2026-11-16 (2 Figma calls used, budget 18)
| Item | Nodes | Result |
|---|---|---|
| Open defect | `292:81954` in `247:17512` | **Fixed.** State=Filled, help 签名清单已通过，可预览权限 shown. Screenshot OK. |
| CF-12 on C3 | whole page `235:13237` | **Checked: 0 frames** have more than one sheet layer, more than one scrim, or a sheet nested in a sheet. Nothing to redraw on C3. |
| CF-62 swipe-delete | new frames `322:18204` "F2.2 游戏库 · 左滑删除" (x 3158) and `322:18255` "F2.2 游戏库 · 删除确认" (x 3671), both in row:lib of section `247:17368` (section widened to 4144), with labels | Done. The last row slides left 88 to reveal a red 删除 action (`322:18252`). The confirm frame adds a scrim and a `confirmationDialog` (`322:18307`): title 删除「夜行地图拼图」？, message 本机存档会一起删除，之后可以重新导入。, destructive 删除游戏, then 取消. |
| CF-62 pop-up accessory | 定价模式 / 流量激励模式 / 通道手续费 rows in `249:24688` `249:24757` `249:36244` `249:36313` (12 rows) | Done. Each value is wrapped in `pop-up value` with an ink-2 value + ⌃⌄ (chevron.up.chevron.down) in ink-3. |
| Result-sheet date copy | `238:19277` (`238:19113`), `238:19443` (`238:19278`) | Done: `11月21日 19:30 · 2 种票`. |
| CF-39 date pickers (C3) | `239:625` `239:771` sheet `设置活动时间` | Done. The custom wheels, range switch and bottom 下一步 were removed. The header is now Close + 完成, and the sheet fits its content (h 291). A white card holds rows 开始 / 结束 with compact date and time capsules; the active one is outlined (start in 625, end in 771). A note says the end time's minimum equals the start. The capsules are a drawn stand-in for the Apple kit `Date Picker (.compact)`: no iOS UI-kit instance was searched for, to stay inside the call budget. |

### Still left after this session
- `246:2996` 使用模板失败 toast → inline failure; `246:3064` staff read-only bar → one sentence + one action (CF-17).
- Blue `note:<id>:detent` boxes for `291:49240` `291:49379` `291:49554` `291:49687`.
- Empty space in the AI full twins `239:30881` `239:31022`.
- Swap the drawn compact-date capsules in `239:625` / `239:771` for the Apple iOS 27 kit `Date Picker` instance, if that library is available.
- Motion notes (CF-17 error scroll/shake, CF-62 install) belong to batch F.

## Resume session 2 · 2026-11-16 (2 more Figma calls; 4 used today)
| Item | Nodes | Result |
|---|---|---|
| CF-17 `246:2996` E4.7 应用失败 | inline error `323:8998` | Done. The 使用模板失败 toast was removed. 应用 stays enabled (white pill), and an inline red line under it reads 没能应用这个模板，你的内容没有变化。再点一次「应用」重试。 The tabs and body moved down to make room. Screenshot OK. |
| CF-17 `246:3064` E4.7 店员仅可浏览 | action row `246:3091` | Done. The 当前岗位仅可浏览模板 toast was removed. 应用 and the share icon were replaced by one sentence (应用模板需要店主操作 / 店员可以浏览，也可以把它发给店主。) and one useful action: a secondary pill 发给店主. Screenshot OK. |
| CF-13 detent notes | `323:9007` (`291:49240`), `323:9009` (`291:49379`), `323:9011` (`291:49554`), `323:9013` (`291:49687`) | Done. These are clones of the blue `note:<id>:detent` style, placed 10 below each Large frame. Each states the detent pair, that this frame is the .large state, the scroll rule and the spring values. |
| Trim AI full twins | `239:30881` `239:31022` | Done. Both are now 852 high: composer at y 740, clip 632, home indicator at y 839. The new layout fits in one screen, so each twin now matches its base frame (`239:29913` / `239:30054`); the names were kept so existing links still resolve. |

### Still left (outside this batch)
- Swap the drawn compact-date capsules in `239:625` / `239:771` for the Apple iOS 27 kit `Date Picker` instance, if that library is available.
- Motion notes: CF-17 error scroll/shake/haptic, CF-62 install fill + row slide-in, CF-58 step slide, CF-59 station stagger. These belong to batch F; the specs are already in the component descriptions.
Nothing else from the batch E checklist is open.
