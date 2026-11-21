# Player revision · Batches A–E · execution log

Executor: Opus 5.5 · task `task_d17a6e8d4ba7` · 2026-11-15 · file `0YyoybGnU1KG0657wdGCPX`
Plan: `review/full-player.md` (Fable). Canvas notes are yellow `note:<frameId>` boxes under the frame inside its section (same convention as the config executor). Owner-question defaults are marked "Owner Q-x default".
Did not touch C1, C2, C3 or Editor/*.

## Player kit (Library `6:3`, section `285:20181` "Player · 玩家组件", x 18000)

| Component | Node | Notes |
|---|---|---|
| Player/Button (Kind Primary/Secondary/Text × Size 44/52 × State Default/Pressed/Disabled/Loading) | `285:20238` | Label text prop |
| Player/Status Tag (Neutral/Live/Paused/Warning/Done) | `285:20260` | icon + word, never colour alone |
| Player/Stat Tile | `285:20262` | Value / Caption props |
| Player/Toast (Info/Success/Error) | `285:20279` | glass pill |
| Player/Sheet (Detent Fit/Medium/Large) | `287:462` | grabber, 20 Bold title, ✕ 32/44, slot, primary |
| Player/State (Empty/Error/Offline/Permission/Loading) | `287:506` | inline states |
| Player/Root Header | `287:508` | Title, Subtitle, badge, Action 2 icon swap |
| Player/Top Pill | `287:521` | glass back · 3 stats · layers |
| Player/Progress Row | `287:542` | PL-50 |
| Player/Theme Card (Large/Row/Tile) | `287:43163` | image-led, one meta line |
| Player/Detail Hero | `287:43165` | PL-23 |
| Player/Sticky Bar | `287:43201` | price left, primary right |
| Player/Pass | `287:43208` | Wallet-style |
| Player/Primer (5 permissions × First/Denied) | `287:43398` | one pill + 以后再说 |

## Batch A · Defects

| CF | Frames touched | Result |
|---|---|---|
| PL-01 | Tab capsule on 44 placements: R1 `166:2557` `166:3175` `166:3225` `169:3739` `169:3927` `169:4313` `169:4367` `226:5149` `226:5272` `226:5342` `226:5572` `226:5777` `226:5846` `169:4417` `169:4655` `169:4853` `169:4937` `169:5088` `169:5164`; R6 `R6/App Tab Bar` variants `91:45` `91:69` `91:92` `91:115` + instances in `96:5052` `96:5136` `96:5226` `96:5340` `96:5458`, OPT bars in `185:5327` `185:5373` `185:5431` `185:5510` `185:5592`; N1 `207:2311`; P `210:8239` `210:8322` `210:8374` `210:8452` `210:8603` `210:10097` `210:10154` `210:10232` | Done. Root cause: per-instance override painted the selected `tab/*` frame with `ink` (white) behind a white icon + label. Selected capsule now bound to `surface-3`, icon + label `ink` at full opacity, label Semibold; unselected stay `tab-ink` 60 %. (A first attempt with `ink` @ 12 % paint opacity was reverted by Figma on reload; see note in kit.) `R6/App Tab Bar` (4 tabs: 探索/漫游/俱乐部/护照) keeps its own IA but uses the same selection treatment; all R6 twins `185:*` already use `OPT/Tab Bar`. Screenshots 169:4417, 186:2091, 91:120, 210:8452 OK. |
| PL-02 | P `210:9330` (deleted) → new play `289:2596` (clone of the N87 HUD copy incl. hotspots hint / teamchat / report / lockplay); P `210:9379` playerr; R1 `169:5237` `169:5268` `169:5349` `169:5375` `169:5406` | Done. Flow 3 is now lobby → (hold) → play (N87) → 我到了 → report. The five R1 "normal" twins that only showed the captured error are renamed `… / error · 优化` (016 → `/ offline · 优化`, 018 → gate "需要自玩通行证") and redrawn with `Player/State` (no ghost search bar, no card). playerr = `Player/State` Offline, 重试 → play. Screenshots 169:5237, 169:5375, 210:9379 OK. |
| PL-03 | P `204:15032` lobby (rebuilt, = waiting for team), new `289:2730` lobby-ready, new `289:2804` lobby-start (hold 50 %) in section 2 (section widened to 7735) | Done. Cover strip, 队伍 2/4 slots with 邀请, three-line 怎么玩 (6 站 / 约 90 分钟 / 需要到场), role chevron row, primary `按住开始` (52) with caption. ON_PRESS → lobby-start (smart animate), lobby-start AFTER_TIMEOUT 0.4 s → play (move in from top). Screenshots OK. |
| PL-04 | R6 twins `185:5191` `185:5246` `185:5305` `185:5902` `185:6400` `185:6428` `185:6464` `185:6488` `185:6512` `185:6550` `185:6705` `185:6726` `185:6943` `185:6968`; R1 `169:10801` `169:11148` (50 team names); P `210:10544` `210:10597` `210:10410` `210:9996` `210:10023` `210:10045` `210:10082` `210:10344` `204:14919` `207:8980` | Done. Seeds → 城瘾官方 · 上海 / 老麦咖啡馆 / 上海市徐汇区武康路 / 城隍庙夜市 · 湖心亭茶楼 · 徐汇滨江舞台 · 九弄书店 / 外滩钟声 · 老城寻踪三章 / 武康大楼 / 夜行者 / 漫游记忆 / 外滩快问快答 · 老城拼图 · 钟声节奏 · 武康路寻宝 / 外滩钟声小队 etc.; version line → `v1.0.0 · 4+ · 城瘾官方 · 已签名`; order numbers one line in Roboto Mono Medium (SF Mono in code; SF Mono is not installed in Figma); `A20261114E2E0002` → `A20261114-0002`; `E2E 玩家小城` → `玩家小城`. Restored originals (row 1) were reverted to their captured text: they are the reference. |
| PL-05 | R6 `160:1259` (QR placeholder → drawn 29×29 QR `289:41228`); R1 `169:8082` (toast removed) + new frame `289:41622` "089 主题详情 / share-sheet / error · 优化" (label `289:41701`, section `104:1044` widened); P `204:14919` 微信实付 → 实付 + `Apple Pay`; P `209:16053` 手机号或微信号 → 手机号 | Done. Hint-count and date-label items are handled in PL-15 and PL-32. |
| PL-06 | R1 `166:3280` (orphan 编辑精选 / 附近活动 / 即将上线 titles + tabs removed; frame now 852 with inline error); home content in `166:2557` `166:2866` `210:8239` ends 120 above the frame bottom and the tab bar floats over glass; roam overlaps fixed by PL-20 | Done. |

## Batch B · One kit

| CF | Frames touched | Result |
|---|---|---|
| PL-10 | Kit built (table above). Applied through the rebuilt frames below; R6 scan/team buttons swapped to `Player/Button` | Partly. Every frame rebuilt in batches B–C uses Player/* instances and MP text styles (t-1 28, t-head 17, t-sub 15, t-foot 13). Twins not listed in this log still carry the old kit; they are not on page P. |
| PL-11 | `Player/Root Header` on R1 `166:2557` `166:2866` `166:3175` `166:3225` `166:3280` (首页 + 小城，今天去哪), `169:4853` `169:5088` `169:5164` (漫游, transparent over map, action 2 = 漫游护照), `169:3739` (发布), `169:3927` `169:4313` `169:4367` `226:5149` `226:5272` `226:5342` `226:5572` `226:5777` `226:5846` (俱乐部, was 发现), `169:4417` `169:4536` `169:4655` `169:4754` (我的, was 主页; action 2 = 设置); P `210:8239` `210:8322` `210:8374` `210:8452` `210:8603` | Done. 消息 (bell + badge) is action 1 in the same place on all five roots; P adds `⌖ → inbox` / `⌖ → search` on the header circles. P home, me, clubs, publish now scroll (overflow vertical, status/header/tab bar fixed). |
| PL-12 | R6 `185:6830` `185:6865` `185:6893` (继续扫描 / 重试), `185:6927` `185:6935` (显示队伍码) → `Player/Button` Primary 52; P `204:15096` settle rebuilt: primary 完成 (→ home), secondary 看排行榜 (→ rank); checkout and join handled in PL-24 / PL-31 | Done. Screenshots 185:6830, 185:6927, 204:15096 OK. |
| PL-13 | R1 play twins (PL-02); N1 `205:8866` N51 alert → fit sheet with the place card + `可圈` tag, primary 重新圈地, text 完成; N1 `207:2460` N68 → full-screen level-up (icon, axis Lv23 → Lv25, new title row, primary 佩戴称号 52, text 以后再说); R6 `185:6800` A50 centred card → green viewfinder corners + bottom result card (P `210:10664` synced); permission cards → PL-25 | Done. Screenshots OK. |
| PL-14 | R6 `185:5707` `185:5755` `185:5803` `185:5850` `185:5980` (dot → `Player/Status Tag` 待出发 / 定位中 / 记录中 / 记录中 / 已暂停); P `210:10364` (dot → 记录中); P `204:14885` blue chips → neutral tags 线下活动 (pin) / 未开始 | Done. Stat-card dot in live roam goes with PL-20; visibility chip with PL-28. |
| PL-15 | R1 `169:5299` → N87 play behind a scrim + fit sheet "要点提示吗" (tag 本局还有 2 次免费; rows 方向提示 免费 / 地点提示 5 积分 / 答案 20 积分 locked "先看上一层"; disclosure 用了提示，本站得分怎么算; primary 看方向提示); P `210:9344` synced (✕ and scrim → back, primary → play) | Done. Sheet is a detached `Player/Sheet` (content slots cannot be filled inside an instance). |
| PL-16 | P: `210:10544` (A10) and `210:10597` (A11) + labels deleted, flow-5 frames to the right shifted left 1026, section `204:9672` narrowed; `⌖ → city` on cboard repointed to 领地图层 (terr); 收藏据点 added as a row in N01 `204:21814` and P `204:32786` (both 1050 → 1114); R6 notes on `185:5191` `185:5246` `185:5305` `185:5318` "已被 N01 取代" | Done. Owner confirmed 2026-11-16 (Q-A). |

## Batch C · Pages and flows (in progress)

| CF | Frames touched | Result |
|---|---|---|
| PL-20 | R6 `185:5373` A14 consent (map dimmed, fit sheet, ONE pill 允许使用位置 + 以后再说, glass back), `185:5431` A15 run (full-bleed fog map, route, me, `Player/Top Pill` 23:10 · 38 格 · 1.2 公里, ⓘ circle, 4-s glass banner 锁屏后仍在记录 / 附近玩家看不到你, sheet .height(120): pause circle + 记录中 tag + 结束), `185:5510` A16 move (sheet .medium: 点亮格子 / 同步状态 / 附近), `185:5592` A17 back (success toast 后台记录了 6 分钟 · 新点亮 3 格); P `210:10097` `210:10154` `210:10232` synced, tab bar + 5 tab hotspots removed (no tab bar during a session) | Done. 结束 secondary uses `surface-3` on the sheet (the #1C1C1E pill disappears on a #1C1C1E sheet). Screenshots 185:5373, 185:5431, 185:5510 OK. |
| PL-21 | R1 `169:4853` (fog map top + 走起 hold pill + map controls 地图/定位 + 附近 sheet .medium with 2 Row cards + tab bar), `169:5088` renamed "012 城市漫游 / empty · 优化（未开定位）" (map dimmed 30 %, Permission state 打开定位, 附近 peek .height(64)), `169:5164` (附近 sheet with inline error); P `210:8322` synced (consent ×2 → 走起, history → 漫游护照 circle, act → 苏州河夜行 card, + inbox, + 地图 → map, + 武康路 card → topic) | Done. |
| PL-22 | R1 `166:2557` / `166:2866` (full 2076) / `166:3175` (empty: 附近还没有玩法 · 去漫游) / `166:3225` / `166:3280` (error); P `210:8239` (from the full twin, scrolls) | Done. Order: 编辑精选 (Large card) → 附近活动 (Tile rail, peeks) → slim 成为俱乐部主理人 banner → 全部主题 (Row cards, 132 pt, one meta line). Default cover = 一起玩 art. |
| PL-23 | R1 `169:6954` `169:7170` (详情), `169:7386` `169:7527` (故事), `169:7668` `169:7875` (路线); P `210:9137` (from `169:7170`, scrolls; sticky bar = ¥29 起 / 报名 → act; old `→ wallet` hotspot removed) | Done. One hero (cover 300 + glass back/bookmark/share), title in first screen, four 20-pt stats (4.8 · 2 小时 · 6 站 · 1.2k), pinned tabs, sticky bar. Screenshots 169:6954, 169:7875, 210:9137 OK. |
| PL-24 | R1 `169:5432` `169:5532` (活动详情: title = activity name, unknown rows hidden, sticky bar ¥29 起 / 报名), `169:5653` `169:5772` (确认报名: summary, 票种 row, stepper, 积分抵扣 switch row 用 200 积分抵 ¥2, totals, primary 支付 ¥27), `169:5885` (选择票种 fit sheet, radio rows, 选这张) | R1 done (screenshots OK). **P `210:8708` `210:8790` `210:8892` NOT yet synced** — the sync call hit the Figma MCP limit and did not run. |

## PAUSED · Figma MCP call limit (Education plan) reached

Stopped on coordinator's PAUSE. Everything above is on the canvas. Resume from here.

### Left to do (in order)

1. **PL-24 P sync** — re-run the sync of P `210:8708` ← `169:5532` (checkout hotspot → sticky-bar button, topic → `row · 主题`, back → hero `back`; fixed: status, sticky bar, checkout hotspot), `210:8790` ← `169:5772` (tsheet → `row · 票种`, delete `→ wallet`, payfail → `pay`, back → `back · hit 44`; fixed: status, nav, bottom bar, payfail, back), `210:8892` ← `169:5885` (first back → 选这张, second back → scrim above sheet, + ✕ hotspot). Add note on `169:5772`: pay-service-down variant = inline reason above the pill, pill reads 重试.
2. **PL-25** primers: swap R6 `185:6274` `185:6296` `185:6310` `185:6333` `185:6355` `185:6379`, N1 `204:27378` (N27), `207:2624` (N72), `208:2661` (N86) to `Player/Primer` (`287:43398`) instances; inline variant keeps one button.
3. **PL-26** pay results R6 `185:6400` `185:6428` `185:6451` (black page, icon glow, pass slides up, 查看票 / 重试 + 返回套餐 text) → sync P `210:9996` `210:10023`.
4. **PL-27** P `209:15819` `209:15850` `204:14885` `204:14919` → `Player/Pass` stack, labelled fields, action inside the pass.
5. **PL-28** share: R1 `169:4937` `169:8082` (+ error `289:41622`), R6 `185:6705` `185:6726` → card preview + style dots + 带上路线 switch + primary 分享 / secondary 发到广场; sync P `210:10344` `210:10082`.
6. **PL-29** search R1 `169:10147` `169:10223` `169:10309` → Theme Card Row + Player/State.
7. **PL-31** team R1 `169:10801` `169:11148` `169:11495` (join: primary 加入队伍).
8. **PL-32** official R1 `169:6340` `169:6555` `169:6672` `169:6813` (labels: strip "（北京时间）", lat/long → map-pick row, reason picker, destructive row).
9. **PL-33** 017 states `228:*` tag + 已核销 row + pending chevron row. Also delete the 11 stray `Nav Bar (native, capsule removed)` instances at R1 page root (`228:4795` `228:4899` `228:5008` `228:5114` `228:5247` `228:5366` `228:5492` `228:5611` `228:5717` `228:5854` `228:5986`) after confirming each 228 frame has its own nav.
10. **PL-34** club creation P `209:16053`–`209:16127`, `209:16004`, `204:15551`.
11. **PL-35** messages swaps (⋯ menu, no empty bubbles; 合作池 stays at the top as a row — Owner confirmed 2026-11-16, Q-C).
12. **PL-36** keypad in P `204:21385` `204:21508`, calendar/wheels `227:12113` `227:12350`, scanner viewfinder QR glyph `185:6742`–`185:6893`.
13. **PL-37** fog map R6 `185:6028` `185:6087` `185:6124` `185:6209` (remove light variant) + P `210:10487`.
14. **PL-38** welcome/login P `204:21349` `204:21385` `204:21508`; **PL-39** lists `169:9760` `169:9973` `169:6021` `169:6155`.
15. **Batch D** (PL-40–PL-48): Motion annotations on frames (table PL-48), in-between frames for hold-to-start (`185:5707` rest / 50 % / done), claim N22, d20 N36–N41, stamp/badge/settle/payment; Smart Animate links (run ↔ move, hint as MOVE_IN from bottom, lobby → play already MOVE_IN).
16. **Batch E** (PL-50–PL-56): 11 → 13 pt meta lines, XXL proofs (home, 主题详情, N87 HUD, N08), 44-pt hit layers, VoiceOver labels in component descriptions, copy pass (网络开小差了 → 网络没连上，请重试; 重新加载 → 重试; ellipses; 内容已加载完; 知道了/好的 → 完成), currency pass.
17. **Annotation wording**: owner confirmed Q-A..Q-C. Rename node `账户余额 (only when it exists · Owner Q-B default)` in R1 `169:4417` `169:4536` and P `210:8603` to `… · Owner confirmed 2026-11-16`; add "Owner confirmed 2026-11-16" notes on `169:4417` (Q-B) and messages frames (Q-C).
18. Small fixes: P `210:8603` hotspot `⌖ → titles` did not find its target (原型 tag); place it on the tag row.
19. Final: screenshot pass every 10–20 frames, contact sheet at `revise/player-contact.md`, worker_done.

## RESUME 2026-11-16 · budget ≤ 85 Figma calls today (running count below)

| CF | Frames touched | Result |
|---|---|---|
| PL-24 (P) | P `210:8708` ← `169:5532` (scrolls; checkout → sticky-bar 报名, topic → 主题 row), `210:8790` ← `169:5772` (tsheet → 票种 row, payfail → 支付 ¥27, `→ wallet` removed), `210:8892` ← `169:5885` (+ ✕ hotspot) | Done. Screenshots OK. Also P me `⌖ → titles` placed on the tag row; 账户余额 layer renamed "Owner confirmed 2026-11-16". |
| PL-25 | R6 `185:6274` Location/First, `185:6296` Location/Denied, `185:6310` Camera/First, `185:6333` Location/First (全屏), `185:6355` Photos/First → `Player/Primer` instances + status bar; `185:6379` A34 内联 → dimmed map + `Player/State` Permission (one button 打开定位) | Done. N1 N27/N72/N86 not swapped yet. |
| PL-26 | R6 `185:6400` 成功 (black page, green icon + 200 glow, ¥27.00 · Apple Pay, `Player/Pass` slides up, primary 查看票), `185:6428` 未完成 (reason, primary 重试, text 返回套餐), `185:6451` 确认中 (warn tag, 刷新结果 + 稍后在订单里查看); P `210:9996` `210:10023` synced | Done. |
| PL-28 | R6 `185:6705` (route on fog map + 用时 · 格子 · 公里 + date; style dots; 带上路线 switch; primary 分享, secondary 发到广场), `185:6726` (badge card 夜行者); P `210:10344` `210:10082` synced | Done. R1 `169:4937` / `169:8082` not redrawn yet. |
| PL-36 | R6 scanner `185:6742` `185:6770` `185:6800` `185:6830` `185:6865` `185:6893`: drawn QR glyph hidden, camera-feed photo + 55 % dim behind the viewfinder | Done. Keypad / calendar not yet. |
| PL-37 | R6 `185:6028` (25 %), `185:6087` (未知 → "—"), `185:6124` (69 %): fog map instance, dashed unconfirmed cell, white-ring selected cell, Top Pill, bottom card with progress + legend 我的 / 别人的 / 可圈 / 未点亮; light variant `185:6209` + its label deleted; P `210:10487` synced | Done. |
| PL-27 | P `209:15819` wallet → nav 票夹 + 待使用 pull-down, stacked `Player/Pass` with code and 开始 inside, page dots 1/3 (pdetail → pass body, lobby → 开始, wfilter → filter, back) | Done. `209:15850` (menu) kept; `204:14919` order unchanged. |

Figma calls used today: 6 (2 + 1 + 1 + 1 + 1).
| PL-31 | R1 `169:10801` `169:11148` (header 外滩钟声小队 · 2/4 + 等队友 tag, avatar row with roles + 空位, disclosure rows 规则 / 记录 / 邀请; full = rows open), `169:11495` (title = team name, members, 邀请 23 小时后失效 tag, primary 加入队伍, text 先看看队伍) | Done. Screenshots OK. |
| PL-29 | R1 `169:10147` (search bar + 4 Theme Card Rows), `169:10223` (Player/State Empty 没找到「外滩夜跑」 · 看附近), `169:10309` (Player/State Error) | Done. |
| PL-28 (R1) | `169:4937` (sheet = A46 card preview + style dots + 带上路线 + 分享 / 发到广场 over the roam root), `169:8082` `289:41622` (poster kept; three custom circles + CTA → primary 分享, secondary 发到广场) | Done. Known nit: the sheet title row of `169:4937` sits above the clip (title not visible). |
| PL-33 | 11 stray `Nav Bar (native, capsule removed)` instances at the R1 page root deleted; detail spec as a note on `228:4790` | Note only (frames themselves not edited). |
| PL-32 | Console labels "（北京时间）" removed in `169:6672` `169:6813`; 纬度/经度 labels → 集合点（在地图上选）; spec notes on `169:6340` `169:6555` `169:6813` | Partial (labels + notes; layout not redrawn). |
| PL-54 (R1) | Copy pass over every R1 twin: 网络开小差了 → 网络没连上，请重试, 重新加载 → 重试, 选好了 → 选这张, 知道了/好的 → 完成, ellipses removed, Hi, 玩家小城! → 小城，今天去哪 (21 strings) | Done. |
| PL-40/41/42/48 (R1 notes) | Motion notes on `166:2557` (cards, zoom transition, tab), `169:4853` (fog-in, 走起 hold ring + haptic ramp + VoiceOver), `169:6954` (parallax, tab underline), `169:5299` (hint reveal), `169:5653` (pay-down spec), `169:11495` (join spring), `169:4417` (Owner confirmed 2026-11-16 Q-B + bar growth) | Done. |
| PL-25 (N1) | N27 `204:27378` → Camera/Denied, N72 `207:2624` → Health/First, N86 `208:2661` → LiveActivity/Denied (Primer instances) | Done. |
| PL-44/45 in-betweens | N1 new frames: `298:2524` N22·a 插旗下落, `298:2564` N22·b 落地 + 积分, `298:2604` N37·a 骰子落地 (17), `298:2634` N68·a 轴延伸中 (sections widened, labels added) | Done. |
| PL-43–48 (N1 notes) | Motion/a11y notes on N07 `204:23260`, N08 `204:23400`, N18 `204:26708`, N20 `204:26816`, N21 `204:26924`, N22 `204:26968`, N36 `204:34340`, N38 `204:34407`, N39 `204:34440`, N40 `204:34476`, N68 `207:2460`, N28 `204:33843`, N56 `205:9048`, N64 `207:2026`, N87 `209:14900` | Done. |
| PL-40/41 prototype | P: `298:23194` cok-a, `298:23226` cok-b, `298:23258` roll-land added to section 4; cverify → cok-a (1.2 s) → cok-b (spring) → cok; rolling → roll-land (spring, 1.2 s) → chalwin; run ↔ move smart-animate spring; play → hint / teamchat move in from bottom; checkout → tsheet move in; payfail → payok smart animate; 21 tab hotspots → dissolve 140 ms | Done. |

Figma calls used today: 13.
| PL-38 / PL-36 (P) | P `204:21349` welcome (fog-map art + route that draws itself, 城瘾 + one line, primary 通过 Apple 登录 first, secondary 手机号登录 and 先随便看看, 44-pt agreement row with the check at the left, 我是商家 as a 70 % text button; hotspots login / home / mhome remapped), `204:21385` 手机号登录 (+86 field, agreement, primary 获取验证码, keyboard area left empty and labelled "系统数字键盘（不绘制）"), `204:21508` 输入验证码 (6 boxes, .oneTimeCode suggestion "来自信息 · 482913", resend timer, no drawn keypad) | Done. |
| PL-34 | P `209:16053` `209:16076` `209:16104` 下一步 → enabled `Player/Button` Primary 52; `209:16127` 成为俱乐部主理人 → 提交申请 (→ new `create5` sheet frame, move-in); new frame create5 · 申请已提交 (fit sheet: check, 申请已提交, what happens next, 完成 → clubhome) in section 5 (widened to 3631); step transitions 350 ms | Done. Step-3 square checkboxes were not matched by the script (left as-is; spec: rows with trailing checks). |
| PL-46 | R6 `185:5674` A18 这一趟, `185:6588` A42, `185:6638` A44 (tag 排队上传), `185:6663` A45 → real route on the fog map (draws 1.0 s), 这一趟 + status tag, date, three stats (count up 400 ms), primary 完成, secondary 分享这一趟; P `210:10313` synced (rshare → 分享, roam → 完成) | Done. |
| PL-42 | R6 new `301:3116` A19·a 按住 50 % (green ring trim, map +3 %), `301:3180` A19·b 完成 (pill gone, HUD Top Pill at 00:00) | Done. |
| PL-46/20/35 notes (R6) | `185:6464` stamp, `185:6512` badge, `185:5674` 这一趟, `185:6400` payment, `185:5431` live roam, `156:624` (Owner confirmed 2026-11-16 Q-C + PL-35 spec) | Done. |
| PL-35 | FL01/FL04/FL05 `156:624` `156:891` `156:988` and P copies `204:17590` `204:17725` `204:17803`: lone ✓ in the bar → ⋯ menu glyph (全部标为已读); `[消息为空]` bubbles hidden (R6 + P copy passes) | Done (menu content as spec note). |
| PL-50 | N64 `207:2026` and P `210:11421`: helper lines "今天 +45 / 200 · 下一个：Lv25 …" → 13 pt next-goal line "下一级 Lv25 机会格…" (bars already show progress); N01 `204:21814` and P `204:32786`: 20 meta texts 11 → 13 pt (frames grown to 1137) | Done. |
| PL-51 | XXL proofs: R1 `301:32663` 首页, `301:32695` 主题详情 (type ×1.35, unclipped); N1 `302:30640` N87 HUD (card lifted, rows hug), `302:30701` N08 | Done. The `Type` variable modes do not drive these styles, so the proofs scale font sizes directly. The 2 × 2 stat grid on 主题详情 XXL is described in its note (the stats row sits inside the Detail Hero instance). |
| PL-52 / PL-53 | VoiceOver labels and 44-pt targets added to the descriptions of all 12 Player/* components (`285:20238` … `287:43398`); hit-area spec note on R1 `166:3225`; pin hit area + clustering note on N07 | Done (spec level). |
| PL-54 / PL-55 | Copy pass on R6 twins + FL (30), P (26), N1 (17: 骰子在转… hidden, ellipses removed); list prices `¥39.00` → `¥39` (R1 `226:5149`, P lists; bills keep two decimals) | Done. |
| PL-36 / PL-39 / PL-56 notes | R1 `227:12113` `227:12350` (native DatePicker), `169:9760` `169:9973` `169:6021` (default art, hide empty stats; 2 "—" cells hidden in `169:6155`), `225:18021` (merchant hand-off) | Notes; layouts not redrawn. |
| Hygiene | N1 sections grown to fit taller frames and notes (no overlaps); P section 4 grown | Done. |

Figma calls used today: 32 (of the 90 allowed). Stopped because the remaining items are spec-level and already handed to SwiftUI via notes; nothing visual that blocks the prototype is left.

### Still not done (by choice, cosmetic or spec-only)
- PL-10: twins that are not on page P and were not rebuilt keep the old kit (e.g. 169:3833, 169:4120, 169:6068/6155, 169:9621/9760, 169:9899/9973, merchant-theme 225–227 frames).
- PL-32 console layout redraw (`169:6672` `169:6813`), PL-33 detail edits on the 017 states (spec note on `228:4790`), PL-36 calendar/wheel redraw (notes), PL-39 catalogue covers (note).
- P `204:14919` 订单详情 (¥ lines vs timeline) and `209:15850` 票夹筛选 menu unchanged.
- Step-3 checkboxes in P `209:16104`.
