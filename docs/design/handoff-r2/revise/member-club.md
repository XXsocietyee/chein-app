# Member & club revision · execution log (R2 / R3)

Executor: Opus 5.5 · task `task_091a10c36f72` · 2026-11-15/16 · file `0YyoybGnU1KG0657wdGCPX`
Plan: `review/full-member-club.md` (Fable). Did not touch C1, C2, C3, R1, R6, N1, P, Editor/* or Player/* (reused read-only).
Canvas notes: yellow `note:<frameId>:mc` boxes under each changed frame inside its section.
Owner questions Q-A/Q-B/Q-C: owner CONFIRMED the defaults (coordinator msg 2026-11-16); annotations read "Owner confirmed 2026-11-16".

**STATUS: DONE for this pass 2026-11-16 — 35 Figma MCP calls used today (budget 60, stop line 55).** Earlier 'Not done (blocked …)' list is superseded by the call table and the 'Left' list at the end.
`use_figma` returns the paywall error; read tools (get_metadata) still work. Remaining work is listed at the end.

## Club kit (Library `6:3`, new section `291:60973` "Club · 俱乐部组件 (MC-10–MC-35 · member & club revision)", x 23000, MP-Dark explicit mode)

| Component | Node | Variants / props | Plan |
|---|---|---|---|
| Wizard/Step Header | `291:61016` | Step 1–4 · eyebrow, title, sub, showSub | MC-10 |
| Wizard/Option Card | `291:61054` | Kind Single/Multi × State Default/Selected · title, sub, showSub, icon (swap) | MC-10, section 2 |
| Club/Row | `291:61114` | Accessory Menu/Chevron/Check/Unchecked/Tag/None · title, sub, showSub, initial, showAvatar, showDivider | MC-20, section 2 |
| Club/Action Row | `291:61126` | Tone Default/Destructive · label, icon, showDivider | MC-20 (退出 / 举报 at end of 概览) |
| Club/Row Menu | `291:61128` | ⋯ pull-down: 举报 · 设为管理员 · 临时封禁 · 移除 (red, last) | MC-20 |
| Club/Spec Label | `291:61149` | "状态板，不是页面 · Spec board, not a screen" | MC-03 |
| Club/Header | `291:66013` | State Visitor/Pending/Rejected/Member/Manager | MC-22 |
| Club/Consequence Sheet | `291:66015` | fit sheet, consequence rows, alt secondary, red pill | MC-33 / section 2 |
| Club/Roster Card | `291:66095` | State Collapsed/Expanded | MC-25 |
| Club/Request Card | `291:66097` | 拒绝 / 通过 44 pt, 12 apart | MC-21 |
| Member/Order Card | `291:66210` | State Unpaid/Upcoming/Live/Done/Cancelled/Pending | MC-35 |
| Badge/Art | `291:70467` | 12 badges × Lit On/Off (shield = 探索, hexagon = 成就, crest = 俱乐部) | MC-30 |
| Badge/Tile | `291:70507` | State Earned/Locked/InProgress (ring 3/7) | MC-30 |

Screenshots of the section: OK (two passes; fixed Action Row icons and Secondary-on-card fills to surface-3).

## Batch A

| CF | Frames touched | Result |
|---|---|---|
| MC-01 | R3 twins `204:24591` (类型), `204:24631` (方向), `204:24676` (资料), `204:24716` (城市) | **Done.** Rebuilt from the real create flow on the kit (Wizard/Step Header + Option Card + Editor/Field + Editor/Row picker + Player/Button). Screenshot of section `94:946` OK. Page P create1–4 (`209:16053` …) not relinked: P is out of scope for this executor. |
| MC-10 (create) | R3 `225:13493` → "063 类型 · 未选择", `225:13553` → "064 方向 · 已选满", `225:13605` → "065 资料 · 名称已被使用", `225:13652` → "066 城市 · 选择城市" (city picker sheet, fit → .large), `225:13694` 066 提交失败 (inline banner) | **Done.** Same kit as the twins: always-enabled primary, inline errors, option cards with check badge, same title style. MC-04 "已选 2 / 3" overlap fixed in `225:13553`. Screenshots `204:24591`, `225:13652`, section OK. |
| MC-10 (apply) | `204:24431` `225:13107` `204:24471` `204:24516` `204:24556` `225:13162` | **Not run** (blocked by the limit). Script ready: `revise/member-club-js/apply.js`. |
| MC-02 – MC-05 | — | Not started (blocked). MC-05 "手机号或微信号" in `204:24591` is gone with the rebuild. |

## Not done (blocked by the Figma MCP limit)
Batch A: MC-02 seed/raw strings, MC-03 seven spec boards, MC-04 remaining layout bugs, MC-05 WeChat wording (R2).
Batch B: MC-10 apply flow, MC-11 titles, MC-12 generic states, MC-13 switches, MC-14 chevrons.
Batch C: MC-20 – MC-31 (row ⋯ menus, organiser buttons, club home header, settings, 活动运营, roster, 群发, phases, workbench, settlement, badges art placement, AI 策划).
Batch D: MC-32 – MC-43. Batch E: MC-50 – MC-54. Sheet detent + spring annotations (section 3) not yet placed.

## Resume 2026-11-16 · call counter
| # | Call | Result |
|---|---|---|
| 1 | use_figma: MC-10 apply flow `204:24431` `225:13107` `204:24471` `204:24516` `204:24556` `225:13162` + R3 copy lint | Done. Inline shot of `94:945` OK. Lint changed 114 texts (E2E 玩家小城 ×15, 玩家二号 ×8, raw dates ×60, 主题#/系列# ids ×6, 场次 #992031, 申请人 9005, 商家二号, 去登录 → 登录, ellipses ×3, 手机号或微信号). |
| 2 | use_figma: R2 copy lint + inventory | Done. 244 texts: 烟测抬头 ×18, E2E API smoke check ×36, RW TEST ×20, smoke-tpl ×8, smoke-team ×4, E2E 商家优惠券, 老城三章 E2E, E2E 举报/咨询, 商家二/三/四号, raw dates ×113, 微信实付 → 实付 ×8, 微信 → 微信支付 ×4, 手机号/微信 → 手机号（选填）, 版本 开发版本 → 3.2.0 (1024) ×4; hidden 已经到底了 / 玩家个人码待生成 ×7. |
| 3–6 | 2 failed scripts (rolled back atomically), 1 read | — |
| 7 | use_figma: MC-03 + MC-22 + MC-26/MC-04 | Done. Spec section `306:33728` on R3 (y 55200) holds the 7 boards with Club/Spec Label + origin; MC-22 Club/Header in 16 club-home frames (Visitor `222:4578`, Pending `222:4679`, Rejected `222:4747`, Member `204:24850` `204:24899` `222:4816` `222:4917` `222:5555` `219:3335` `219:3463` `219:3581` `219:3634` `219:3687` `219:3803` `219:3861` `204:24751`); info tiles + floating 加入 + 退出 word removed; 举报俱乐部 / 退出俱乐部 rows `306:34041` at end of 概览 in `204:24899`. 群发 `170:1313` `170:1353` `236:14845` `236:14908`: 选择/已选 → check circles, 无成员 rows dimmed, 发送站内通知 → 发送给 1 人; MC-04 `236:14845` error/label overlap fixed. Inline shots `222:4578`, `204:24899` OK. |
| 8 | use_figma R3: MC-20 ⋯ menus + MC-20 governance form + MC-21 checks | Done. Row words → ⋯ (`223:3698` ×3 + open Club/Row Menu, `222:4816` ×3 + open menu, `219:3463` ×5, `233:13154` ×3). 成员治理 `97:3584` `233:13436`: 成员 / 期限 / 原因 rows, red-outlined `封禁 30 天`, 转让主理人 in its own card. Inline shots OK. |
| 9 | use_figma R3: MC-21 approvals + picker checks | Done. `204:25191` `236:14727` → Club/Request Card (`307:30131`, `307:30146`; 44 pt pills 12 apart). 选择/已选/颁发 pills → check circles in `236:15069` (3) `236:15141` (4) `236:8101` (3). |
| 10 | use_figma R3: MC-11 / MC-12 | Done. 58 K/State → Player/State at 40 % height, 45 state frames get the page's own large left title (nav title hidden): 俱乐部勋章 · 客户 · 玩家小城 · 报名名册 · 核销详情 · 活动运营 · 成员治理 · 入会申请 · 群发通知 · 个人收款 · 角色与权限 · 俱乐部结算. Skeletons moved below the title. 去登录 → 登录; 链接已失效 返回 → 回到俱乐部 / 回到工作台. |
| 11 | use_figma R3: state copy fix + §3 detents + switches | Done. 58 state bodies rewritten per kind. 50 blue `note:<id>:detent` boxes (fit / fit→large / medium→large / large / menu / keyboard) with the spring line. Only 2 switch instances found on R3 (raw switches remain, see left-overs). |
| 12 | read R2 structures | — |
| 13 | use_figma R2: MC-30 / MC-40 | Done. Badge wall `204:30158` `204:30041`: 3-column Badge/Tile grid, 10 distinct earned badges + 点亮一隅 (in progress) + 开门成社 (locked); growth center `204:29258` `204:29139`: 4 Player/Stat Tiles + latest three badges as art + 查看全部 9 枚; 3D `94:4064`: Badge/Art 220 + caption + tilt hint; 藏品 `94:4087`: 6 collectible cards; 邮票 empty `204:30010`: stamp art + 打开集邮相机; 集章相机 `128:1266`: viewfinder corners, guidance pill, shutter. Inline shots OK. |
| 14 | R2 hug heights + reads | `204:30158` 1885→1238, `204:29258` 1270→709. |
| 15 | use_figma R2 Batch D | Done. MC-33: 5 delete dialogs → Club/Consequence Sheet (fit, consequence rows with icons, softer alternative, red pill) `222:5684` `222:5798` `222:5906` `222:6014` `222:6126`. MC-32: 61 project cards get ⋯; hint → 轻点 ⋯ 或长按卡片管理; 模板 tab 24 pt pills removed. MC-35: 12 order cards → Member/Order Card (`181:3114`, `181:3294`). MC-38: counts row removed, 26 进入队伍 pills → chevrons, 我带的队 → 带队中, 已通过 → 已加入 (`184:7016` `184:7219`). MC-37/MC-04: Player/Sticky Bar with 开通 on `181:3539` (¥39 / 30 天 · 或 390 积分) and `181:3603`. MC-34: mode cards = one line + chevron, 开始 pills surface-3, 模 tiles → icon (`181:1536` `181:1711`). MC-43: 退出账号 centred red, stray › removed (`190:5223` `190:5455`). |
| 16 | use_figma R3: switches / arrows + reads | 9 raw green switches → neutral (ink track, ink-inv knob; Owner confirmed 2026-11-16 Q-B); 63 `icon/arrow` frames → chevrons (MC-14). |
| 17 | use_figma R3 Batch C | MC-25 roster `204:25026` `204:24948`: 7 Club/Roster Cards (real covers, capacity bars, one expanded with 实收/已退/净额 + status tags). MC-30 club badges `94:2803`: 7 photos → Badge/Art. MC-31 AI presets → 静安夜游 / 外滩亲子 / 苏州河摄影, ellipses dropped (`224:5082`–`224:5321`). MC-29 / Q-C: 联系平台客服提现 → 申请提现 + explanation line (`236:15318` and 3 more), 金额待核验 → — + 核验中 tag; notes "Owner confirmed 2026-11-16". |
| 18 | use_figma R3 Batch C | MC-28 workbench `170:1744` `170:1546`: Now card (one primary 去招商 + text 先开一场), 3 tappable tiles (待审批/待核销/本周场次), 项目 rows with status sub-line + chevron (pills gone), grouped 合作与期次 list; 5 round actions → 扫码 + 团码 in nav. MC-24: `170:7698` → "075 优化 · 本场" (status banner, 标记到场 44 pt, masked phone, rows 日期清单 / 创建系列场次); new frame `311:32028` "075 优化 · 创建系列场次" (picker rows, 1 天 instead of 1440, 11月15日 周六). Settlement explanation moved out of the button. |
| 19 | use_figma R3: MC-50 notes + MC-54 + reads | 9 green motion notes (`note:<id>:motion`) on join `222:4578`, approve `204:25191`, scan `224:5619`, send `236:14908`, award `236:8101`, start/end `229:4893`, like `219:3335`, publish `223:3888`, dissolve `236:8711`. 知道了 → 完成 ×8; welcome copy without "！". |
| 20 | use_figma R3 | K/Alert → Club/Consequence Sheet: 结束活动 `231:3995`, 结束主题 `231:4062`, 解散俱乐部 `236:8711`. Welcome sheet `204:24751`: 去看活动 full-width primary, 完成 text button. MC-27 `170:1433`: 接下来 = next session + "还有 4 场 ›", lock pill → plain text with lock glyph. MC-04: 18 overlapping switches moved to the trailing edge (incl. `170:935`, `236:8711`). MC-23: `223:3698` is now the pushed 成员管理 page (back ‹, title, members only); `223:3573` title → 项目工具. |
| 21 | use_figma R2 | MC-12: 8 K/State → Player/State (`222:3001` `222:3052` `222:3103` `222:3154` `222:3206` `220:9730` `220:9772` `220:9816`); MC-13: 12 raw switches neutral; MC-52: 提交投诉 / 提交申请 buttons → white primary (`104:1576` `104:1518` `183:4804`); MC-51: red 11 pt text → 13 pt `bad`; consequence titles 取消活动 / 取消主题; 12 §3 detent notes on R2 sheets/menus (`222:2761` `204:29958` menu; `222:2890` `124:2216` medium→large; 5 delete sheets + `222:6320` fit; `105:778` `204:30633` fit + brightness). |
| 22 | read R2 | — |
| 23 | use_figma R2 | MC-35 order detail `184:6718` `184:6584`: dates 11月29日, 订单进度 moved under the amount, five key–value blocks → two collapsed rows (支付信息, 报名人信息) + order number line, bottom bar 联系客服 (secondary) + 查看票 (primary). MC-37 pass banner `181:3507` neutral card. MC-39 月度回顾 `129:1360`: 5 weekly bars with values, current week highlighted. |
| 24 | use_figma R2 | MC-36 我的参与 `204:29459` `204:29646`: 8 cards → cover on top, text on the card surface, neutral 未开始 tags. MC-41 twins created (clone + kit pass + note): `314:3734` (玩法详情), `314:3764` (收益明细), `314:3806` (分析), `314:3871` (视频悬赏, Owner confirmed 2026-11-16 Q-A), `314:3918` (邀请与收益), `314:3955` (朋友邀请), `314:4020` (通行证揭晓). MC-42 notes on `114:790` `118:2236` `181:2101` `132:1631`. MC-21: 38 small pills on R2 → 36 pt. |
| 25 | use_figma R3 | MC-26: 可见客户手机号 segmented → neutral switch; 分配 enabled (white) in 6 frames; MC-21: 34 small pills on R3 → 36 pt; MC-22: `222:5555` sort is a pull-down menu on "综合 ▾" (sheet removed). |
| 26 | use_figma R2 | Q-C: 提现 hand-off renamed 申请提现 + explanation + note (`204:29996` and one more). MC-43: master switch 接收营销消息 (`181:2046`). MC-37: dual prices "¥99 或 990 积分" ×4. |
| 27 | use_figma R2 | Master switch moved to its own group at the top of `181:2046`. MC-04 附近 `204:34773`: yellow line and cropped cover NOT found as editable layers (left). |
| 28 | use_figma R3 | Sort menu check icon; MC-29 会费 `233:3264`: 价格 ¥39 / 期限 30 天 (units in values, not labels); 解除绑定 red outline (`97:3782` `236:14951` `236:14982` `236:15030`). |
| 29 | read R2 | — |
| 30 | use_figma R2 | MC-12: 2 MP/State → Player/State (`183:4904` …); top-pinned states moved to 40 % (`100:5314` + 1), 返回 → 回到我的. MC-39: Roam/Route Thumb on 6 官方线路 cards (`128:1962`) and route on map for 6 history cards (`181:4674` `181:4520`). |
| 31 | read R3 | — |
| 32 | use_figma R3 | MC-31: preset chips get icons (12 chips in `224:5082`–`224:5321`). MC-27: 结束主题 is already the last, red group in `231:2826`. |
| 33 | use_figma R3 | Section check: spec section `306:33728` and 入社申请审批 `97:3656` OK; no stray top-level nodes on R3; section order ends 主理人工作台 · K 状态组件 · 会费 · 规格板. |
| 34–35 | use_figma R3 | `236:14727`: inline error and request card moved clear of the stale-list strip. |

## Left (not done in this pass)
- MC-04: `204:34773` 附近 yellow diagonal + cropped cover are not editable layers (likely inside a raster); needs a manual look. `181:3539` / `181:3603` got the sticky bar; verify the segmented ¥ / 积分 choice in code.
- MC-11: R2 state frames already had large titles; only R3 was changed. Nav-bar variants on R3 are hidden, not swapped to Editor/Nav Bar.
- MC-20: `236:8395` tag chips × are vectors, unchanged. `219:3463` comment rows got ⋯ but no open menu drawn.
- MC-23: 俱乐部设置 group order (成员 · 内容 · 运营 · 经营 · 资料 · 解散) not re-ordered in `223:3376`; 编辑历史 `223:4213` had no "v2/v1/v0" text nodes left to replace.
- MC-24: 日期清单 page not drawn as its own frame (row only); `233:12652`–`233:13236` state frames still use the old long layout.
- MC-27: phase frames `229:*` untouched (kept as the reference pattern); 角色分配 `231:3203` nested 接管 form not split.
- MC-29: 结算 fee lines behind the row not done; N02 `233:3365` untouched.
- MC-30: 集邮相机 `183:4653` keeps the permission state (no viewfinder); badge tiles on R3 颁给谁 `236:8101` use checks, no art.
- MC-34: templates use the Icon/layers glyph, not `G6/Gameplay Icon` (config kit not looked up).
- MC-37: 发票 chips already 34 pt — left; 申请开票 bottom bar unchanged apart from contrast.
- MC-39: 本次漫游 `184:6938` `184:6977` "—" cells and empty box, 探索目标 progress bars (`129:1515`) and 那年今日 `129:1564` not done.
- MC-41: twins are clones with a light kit pass + notes, not full redesigns.
- MC-53: XXL Dynamic Type proofs not drawn.
- Page P create1–4 relink (MC-01) — P is outside this executor's scope.
