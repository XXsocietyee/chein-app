# FULL REVIEW · Player app (R1, R6, N1, P)

Reviewer: Fable 5.2 · 2026-11-15 · read-only (no Figma or code was edited).
File `0YyoybGnU1KG0657wdGCPX`. Pages: R1 `90:3` (小程序还原 · 玩家核心, with twins), R6 `91:34` (App 独有页面), N1 `204:7911` (新功能), P `204:9667` (全局原型 · 优化版).

## 0 · What was reviewed, and how

| Page | Sections | Frames | How it was read |
|---|---|---|---|
| R1 | 31 | 203 | 26 of 31 sections rendered at 1×. In each, I read the **optimized twins** ("· 优化") and every **new state frame** (ids `220:*`, `225:*`, `226:*`, `227:*`, `228:*`) at 0.5×. The restored originals (row 1) were not reviewed: they are the reference, not the deliverable. "first screen" twins are crops of their "full" twins and were read through the full frame. **Not rendered:** five template sections (`95:2051`, `97:2187`, `98:1657`, `98:1723`: creator pages, covered by the C3 review and the merchant-creator review) and `106:1640` was read at 0.5× only as a whole (3,041 pt). |
| R6 | 25 | 170 | 17 player sections rendered. All 53 Flutter channel frames (FL, FC, FS, FG, FQ, FT, FD) and all 48 optimized twins A10–A57 read at 0.45×. Tiles opened one by one for FL01–FL12, FC07–FC12, FG, FQ, FT, FD and every A-twin; FL13–FL15, FC01–FC06 and FS01–FS09 were read through their copies on page P (chat, send menu, more menu) and by metadata. **Not reviewed here:** the 7 merchant-and-club sections A01–A07 (`230:*`, `231:*`); they belong to the merchant-creator review. |
| N1 | 11 | 99 | All 10 feature sections rendered; 96 frames read at 0.45× (N01–N97). The component board was not opened. |
| P | 10 | 101 | All 10 sections rendered; all 101 frames read at 0.5×. |

Metadata checks over all four pages: copy lint (seed strings, leaks, ellipses, banned words, currency marks) and text heights. No contrast tool was run (contrast findings are by eye and token). No prototype wiring was inspected: flow findings are from the frames and their order on page P. The owner's Kavsoft video was not playable in this session; sheet behaviour follows the owner's description.

**Result: 49 issues. P0 10 · P1 31 · P2 8.** (Issue IDs are grouped by batch, so the numbering has gaps.)

The five findings that matter most:
1. **The selected tab is a blank white pill** on every tab root. The player cannot see which tab they are on (PL-01).
2. **The play loop has no playable screen in the prototype.** `play` is an error card, `lobby` has no start button, and the real play screen exists only as N87 (PL-02, PL-03).
3. **Two visual systems sit side by side.** The N1 frames (2026-11-15) are one coherent kit: 44 pt white pill, glass top pills, sheets with a grabber. The R1 and R6 twins still use 13 pt text, rectangular buttons, grey "primary" pills and card-style alerts. The prototype cuts between the two on almost every flow (PL-10 to PL-16).
4. **Live roam still covers the map with stacked cards**, and text bleeds under the tab bar: round 1's finding is not fixed (PL-20).
5. **Game moments are static.** Dice, stamp, claim, level-up and payment are single still frames with no stated motion or haptic. This is where the Apple Design Award is won or lost (PL-40 to PL-48).

N1 is the reference quality for the rest of the app. Most of this plan is "make R1 and R6 look and behave like N1".

---

## 1 · References (22, none repeated from round 1 or from the config review)

Apple HIG text was read from Apple's documentation JSON. Quotes are Apple's wording.

### A · Apple HIG

| # | Reference | Key guidance (quoted) | Lesson for the player app |
|---|---|---|---|
| 1 | [HIG · Designing for games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games) | "Let people play as soon as installation completes." "Provide great default settings." "Make sure text is always legible." "Make sure buttons are always easy to use. Buttons that are too small or too close together can frustrate players." | The lobby must start a game in one tap. In-game text is 17 pt, buttons 44 pt and 12 pt apart: the N87 HUD does this; the 014–019 twins do not. |
| 2 | [HIG · Searching](https://developer.apple.com/design/human-interface-guidelines/searching) | "Aim to make your app's content searchable through a single location." "Provide suggestions to make searching easier." | One search entry (the 首页 header). The twin `169:10047` already offers suggestions and categories: keep it, and remove the second search bar on the roam home `185:5327`. |
| 3 | [HIG · Collections](https://developer.apple.com/design/human-interface-guidelines/collections) | "Use the standard row or grid layout whenever possible." "Consider using a table instead of a collection for text." "Make it easy to choose an item… Use adequate padding around images." | The home feed's 20 cards with three key–value rows each are text in card clothing. Use an image-led card with one meta line. |
| 4 | [HIG · Scroll views](https://developer.apple.com/design/human-interface-guidelines/scroll-views) | "Make it apparent when content is scrollable… displaying partial content at the edge." "Consider showing a page control when a scroll view is in page-by-page mode." "Avoid putting a scroll view inside another scroll view with the same orientation." | Carousels peek the next card and show a page control (the roam carousel does). Sheets must not nest a second vertical scroll: section 3. |
| 5 | [HIG · Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) | "Choose items deliberately to avoid overcrowding." "Provide a useful title for each window." "Don't title windows with your app name." "Consider temporarily hiding toolbars for a distraction-free experience." | Five tab roots, one header pattern. Titles match the tab label. Play and roam hide the tab bar. |
| 6 | [HIG · Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy) | "Request permission only when your app clearly needs access." "Include only one button and make it clear that it opens the system alert. People can feel manipulated when a custom screen… includes a button that doesn't open the alert." | Permission primers: one button that opens the system prompt (`允许使用位置`), and "以后再说" as a plain text link below, not a second button. Two primer styles exist today (PL-25). |
| 7 | [HIG · Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications) | "Provide concise, informative notifications." "Avoid sending multiple notifications for the same thing." "Use an alert — not a notification — to display an error message." | 被抢 (N40) and 收租 are notification moments: one notification per event, the detail in the app. |
| 8 | [HIG · Gestures](https://developer.apple.com/design/human-interface-guidelines/gestures) | "Give people more than one way to interact with your app." "Make custom gestures easy to learn." "Use shortcut gestures to supplement standard gestures, not replace them." | Hold-to-start "走起" and the dice roll need a visible ring that teaches the hold, and a VoiceOver action that does the same thing with a double tap. |
| 9 | [HIG · Charts](https://developer.apple.com/design/human-interface-guidelines/charts) | "Make every chart in your app accessible." "Let people interact with the data… but don't require interaction to reveal critical information." | The six-stat radar (N64) needs the bar list as its accessible twin: N73 already draws it. Use it as the Dynamic Type and VoiceOver form. |
| 10 | [HIG · Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) | "Avoid offering an app-specific appearance setting." "Aim for sufficient color contrast in all appearances." "Use the system-provided label colors." | The player app is dark by role. Remove the one light fog map `185:6209` unless it is the system light appearance. Grey-on-grey buttons fail contrast (PL-12). |
| 11 | [HIG · Activity views](https://developer.apple.com/design/human-interface-guidelines/activity-views) | "Use the Share button to display an activity view." "Avoid creating duplicate versions of common actions that are already available in the activity view." | Share sheets with 保存图片 / 系统分享 circles (`169:4937`, `169:8082`) duplicate the system sheet. Show the card preview, then one `ShareLink`. |
| 12 | [HIG · Managing accounts](https://developer.apple.com/design/human-interface-guidelines/managing-accounts) | "Ask people to create an account only if your core functionality requires it; otherwise, let people enjoy your app or game without one." "Always identify the authentication method you offer." | "先随便看看" on the welcome screen is right. Give it a proper secondary button, not a blue link. |
| 13 | [HIG · Ratings and reviews](https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews) | "Avoid interrupting people while they're performing a task or playing a game." "Look for natural breaks." | The 评价安全感受 sheet (`228:5712`) appears after 核销: a natural break. Keep it skippable, one tap per rating. |
| 14 | [HIG · Going full screen](https://developer.apple.com/design/human-interface-guidelines/going-full-screen) | "Let people choose when to exit full-screen mode." "Consider deferring system gestures to prevent accidental exits in a full-screen app or game." | Play, camera, dice and celebrations are full screen with one explicit exit (✕), and swipe-back is disabled while a roll or a claim check is running. |

### B · Outdoor, location and game apps (Mobbin)

| # | Reference | What it shows | Lesson |
|---|---|---|---|
| 15 | AllTrails · [explore feed](https://mobbin.com/screens/ff4665a2-2e2f-4fb6-b486-acc6b39fde69) | Full-bleed card: the trail drawn on a satellite image, name, one meta line (4.6 · Easy · 10.60 mi), two small pills. A floating "Map" pill switches list and map. | The home feed card: route art as the cover, name, one line. No key–value rows. A floating list ↔ map pill instead of a separate nearby page. |
| 16 | AllTrails · [trail detail](https://mobbin.com/screens/fc4f4c20-dc64-4ee6-b5f9-a3f093e30db7) | Photo hero with glass circle buttons; title; a 2 × 2 stat grid with big numbers and small units; a toast with an inline "Edit". | 主题详情: the cover comes first, the title is in the first screen, stats are 4 large cells, not 5 tiny ones. |
| 17 | Strava · [feed post with route](https://mobbin.com/screens/f9216faa-47b8-4b6c-9e69-6464b21c3d74) | Author row, title, three stats in one row, the route on a real map, kudos row. | A roam share and a 广场 post should lead with the route on the map, then three numbers. The roam share card today shows a person placeholder. |
| 18 | Strava · [laps](https://mobbin.com/screens/f99cb5ad-6c1e-456b-9bfc-5542dd13611a) | A chart on top, then a plain table of numbers. | 本局战报 and 漫游记录: a small chart, then rows. Detail behind disclosure. |
| 19 | corner · [map home](https://mobbin.com/screens/85cd09a0-af86-4ab8-9305-576288116ffa) | The map is the whole screen; category chips float above a glass tab bar; two glass buttons in the corners. | Roam: the map stays visible; controls are glass and at the edges; the list is a sheet. |
| 20 | Starbucks · [store locator](https://mobbin.com/screens/2a29a650-39a6-400f-9187-e15665a22777) | Map in the top third, a list below with three tabs (Nearby / Previous / Favorites), status tags per row. | 附近 as a half sheet with tabs is a habit people already have. The nearby sheet `185:5902` matches it; apply the same to 漫游 root's 附近活动. |
| 21 | Duolingo · [quests complete](https://mobbin.com/screens/d530dada-6595-4901-8541-1895451c7863), [quest progress](https://mobbin.com/screens/75eb49d6-36de-47cd-85e2-d4a821a546d0), [reward reveal](https://mobbin.com/screens/53295092-90a0-4bba-8acb-6481757faaa5) | A reward screen is: art, one line, a filled progress bar, one button. The reveal names the rarity, shows the item, and offers "wearing now" plus share. | 结算, 升级 and 新徽章: art, one headline, the progress it moved, one primary. "佩戴称号" on level-up (N68) is the same idea: make it a full-screen moment, not a small dialog. |
| 22 | Airbnb · [experience detail](https://mobbin.com/screens/eebb8639-f481-4062-95f3-eeaab6f64f86), [sticky booking bar](https://mobbin.com/screens/f5de44f9-d5f8-4bb7-afd2-b8eceeb9ce57); Apple Wallet · [event pass](https://mobbin.com/screens/e1061c73-0be8-42ba-aaed-3bb1c3321a4e) | Detail: image, title, rating line, host row; a sticky bar with the price at the left and one filled button at the right. Wallet pass: image strip, two labelled fields, the code. | 活动详情 and 主题详情 get a sticky bar: price left, one primary right. The ticket in 票夹 is a pass: cover strip, date, place, code. |

---

## 2 · Shared decisions (taken from the N1 kit, which is the best work in the file)

| Topic | Decision | Where it already exists |
|---|---|---|
| Primary button | White pill, 44 high (52 on full-screen moments), 16 Semibold black label, full width minus 16 gutters. One per screen. | N08, N18, N22 |
| Secondary button | Dark pill `#1C1C1E`, same size, white label. Never grey-filled with dark text. | N22 "告诉战队", N38 |
| Tertiary | Text button 15 pt, white 70%. | A18 "完成" |
| Top bar on maps and play | Glass circle back (44), a glass pill with up to three stats, a glass circle at the right. | N07 |
| Page header | Back chevron (44 target), large left title 28, one-line subtitle 13. | N46, N56, N64 |
| Tab root header | Large left title = the tab's label; actions as glass circles at the right. | to be built (PL-05) |
| Sheet | Grabber, title left 20 Bold, round ✕ right (32 visual, 44 target), content, one primary pill at the bottom. | N08, N18, N47 |
| Status tag | Soft fill, 12 px icon, text. Never a dot alone. | N01 我的地盘 tags |
| States | Skeleton that mirrors the layout; inline empty and error on the page (icon tile, title, one line, one button). | N02–N06, N52–N54 |
| Unknown value | "—" with the reason in the caption. | A43, `228:4790` |
| Currency | 积分 with the coin glyph. "¥" only on real-money tickets and orders, and always with two decimals in bills. | N18 |
| Toast | Dark glass pill, bottom, above the tab bar or bottom bar; 2 s; optional action. | AllTrails ref 16 |

---

## 3 · Sheets: resizable scrollable sheets (owner reference)

Behaviour and values are the same as in `full-config.md` section 3: the sheet opens at the smallest detent that shows its content, grows by drag, scrolls only at its largest detent, and moves with `spring(response: 0.38, dampingFraction: 0.86)`; haptic `.selection` on settle; Reduce Motion cross-fades. The one difference for the player app: **map sheets leave the map interactive** (`presentationBackgroundInteraction(.enabled(upThrough: .medium))`) and have no scrim.

`fit` = `.height(content)`, capped at 62% of the screen.

| Sheet | Frames | Detents | Notes |
|---|---|---|---|
| 地产卡 (可圈地 / 他人 / 我的 / 未点亮) | `204:23400`, `204:23542`, `204:23691`, `204:23832`, `204:23956` | `fit`, `.large` | Map stays interactive. `.large` shows history and visitors. |
| 圈地确认 / 校验 / 失败 | `204:26708`, `204:26790`, `204:26924`, `204:27073`, `204:27181`, `204:27271`, `204:27353` | `fit` | Height changes as checks resolve: animate with the spring. Not dismissible while 校验中. |
| 挑战确认 and its states | `204:34263`, `204:34572`, `204:34634`, `204:34695`, `204:34759` | `fit` | |
| 开护盾 / 升级 / 风化详情 | `205:8475`, `205:8580`, `205:8686`, `205:8786` | `fit` | |
| 街区卡 (领地图层 bottom card) | `204:23260` | `.height(96)`, `.medium`, `.large` | Peek shows the district name and progress; pull up for the cell list. |
| 附近 (roam map) | `185:5902` and the peek in `185:5707`, `185:5755`, `185:5803`, `185:5850`, `185:5980` | `.height(64)`, `.medium`, `.large` | The peek is already drawn ("附近 · 5"). Search focuses to `.large`. |
| 实时漫游 详情 (new, replaces the stacked cards) | `185:5431`, `185:5510`, `185:5592` | `.height(120)`, `.medium` | See PL-20. |
| 队伍聊天 (play HUD) | `209:15012` | `.medium`, `.large` | Keyboard raises it to `.large`. |
| 街区频道入口卡 | `209:15117` | `fit` | |
| 提示 (play) | `169:5299` | `fit`, `.medium` | Today a centred dialog: becomes a sheet (PL-15). |
| 本站任务 / 结果 / 到店任务 | `228:5242`, `228:5361`, `228:5487` | `fit` | |
| 评价安全感受 / 已提交 | `228:5712`, `228:5849` | `fit` | |
| 选择票种 | `169:5885` | `fit` | |
| 登录 / 验证码 | `204:21385`, `204:21508` | `.large` only | Keyboard is the system's. |
| 分享本次漫游 / 分享主题 | `169:4937`, `169:8082` | `.large` only | Preview first, then the system share sheet. |
| 俱乐部欢迎 | `204:15551` | `fit` | |
| 成员管理 | `226:5342` | `.medium`, `.large` | |
| 票夹筛选 | `209:15850` | menu, not a sheet | Keep the pull-down menu. |
| 聊天发送菜单 / 更多 | `159:1356`, `159:1512` | system action sheet | Follows Flutter; already native. |
| 选择承接节点 / 路线模式介绍 / 选择章节 / 打卡码 / 分润明细 | `226:4087`, `226:4230`, `226:4378`, `226:4515`, `226:4692`, `226:4869` | `fit`, `.large` (介绍 and 分润); `fit` (the rest) | Light merchant theme; black pill. |
| 选择可配合日期 / 时间 | `227:12113`, `227:12350` | `fit` | Native `DatePicker`; the drawn calendar and wheel go (PL-36). |
| 报名已提交 / 修改已保存 | `227:11791`, `227:12001` | `fit` | |

---

## 4 · The plan

Format: **ID · severity · title**, then frames, problem, optimize, implement (Figma; SwiftUI; motion where it applies).

### Batch A · Defects (no design decisions)

**PL-01 · P0 · The selected tab renders as a blank white pill**
- Frames: R1 twins `166:2557`, `166:3175`, `166:3225`, `169:4853`, `169:5088`, `169:5164`, `169:3739`, `169:3927`, `169:4313`, `169:4367`, `169:4417`, `169:4655`; R1 states `226:5149`, `226:5272`, `226:5572`, `226:5777`, `226:5846`; R6 `185:5327`, `185:5373`, `185:5431`, `185:5510`, `185:5592`; N1 `207:2311`; P `210:8239`, `210:8322`, `210:8374`, `210:8452`, `210:8603`, `210:10097`, `210:10154`, `210:10232`; component `174:3515` (OPT/Tab Bar) and `R6/App Tab Bar`.
- Problem: the selected item's icon and label are white on a white pill, so the current tab is invisible.
- Optimize: neutral selection per the owner ruling: selected = white icon and label at full opacity, weight Semibold, on a 12%-white capsule (or no capsule and a filled symbol); unselected = 60% white, regular. Glass bar, floating.
- Implement: Figma: fix the `Selected` variant in `174:3515` (bind icon and label to `mp/ink`, capsule to `mp/surface-3`), make `R6/App Tab Bar` an instance of it, and check all 33 placements. SwiftUI: native `TabView`; `.tint(.white)`. Motion: system. Haptic: none.

**PL-02 · P0 · The prototype's play screen is an error card**
- Frames: P `210:9330` (play), `210:9379` (playerr), `210:9344` (hint); R1 twins `169:5237`, `169:5268`, `169:5349`, `169:5375`, `169:5406`.
- Problem: the capture behind rows 014–019 was an error, so the "normal" twins show only "加载失败，请稍后重试 / 重新加载 / 返回活动详情" under a ghost search bar. Flow 2 on page P therefore goes lobby → error.
- Optimize: the play screen is N87 (`209:14900`): top glass status pill, chapter text, next-stop card, `我到了`, bottom row 提示 / 队伍 / 背包. Use it as `play` in the prototype. Rename the five twins "… / error · 优化" and restyle them as the inline error state (section 2), without the search bar.
- Implement: Figma: replace `210:9330` with a copy of `209:14900`; relink flow 2. Redraw the five error twins with the shared state component. SwiftUI: `PlayView` with `.toolbar(.hidden, for: .tabBar)`.

**PL-03 · P0 · The lobby has no way to start**
- Frames: P `204:15032` (开局大厅, marked 无需优化).
- Problem: the frame shows a title, the topic row and "以 玩家小城 身份游玩 · 编辑". No button, no team, no rules. It is a dead end as drawn.
- Optimize: lobby = topic cover strip, team slots (avatars, "邀请" slot), a three-line "怎么玩" with icons (站数, 时长, 需要到场), and the primary `开始` at the bottom (hold-to-start, see PL-42). Role row stays as a chevron row.
- Implement: Figma: redraw on the N1 kit; add states: waiting for team, ready, starting. SwiftUI: `LobbyView`; `Button` with `onLongPressGesture(minimumDuration: 0.8)`.

**PL-04 · P0 · Seed, English and QA strings in player frames**
- Frames: `185:5191`, `185:5246`, P `210:10544` ("Synthetic official city", "Synthetic cafe", "CITY 经营权与原回执"); `185:5305` (杭州 seeds in a 上海 app); `185:5902`, P `210:10410` ("Dongmen Night Market", "Laojie Teahouse", "Binjiang Park Stage"); `185:6400`, `185:6428`, P `210:9996`, `210:10023` ("Old Town Night Walk bu…", "BND-20261110-0 007" wrapping); `185:6464`, `185:6488` ("Lantern Gate (example)"); `185:6512`, `185:6550`, `185:6726`, P `210:10045`, `210:10082` ("Night Walker", "Lantern Gate Night Walker of the Old Quarter (example)"); `185:6705`, P `210:10344` ("ROAM MEMORY"); `185:6943`, `185:6968` ("Game rw.quiz1794649681", "E2E e2e.adm1…", "v1.0.0 · 4+ · E2E · NONE"); `169:10801`, `169:11148` ("smoke-team-1f1c", "E2E API smoke check"); `169:10736` ("城瘾官方E2E").
- Optimize: Chinese seeded names from the file's own data (外滩钟声 · 老城寻踪三章, 老麦咖啡馆, 武康大楼, 夜行者 for the badge). Order numbers on one line in a monospaced style. "ROAM MEMORY" → `漫游记忆`.
- Implement: Figma text swaps.

**PL-05 · P0 · Annotation text and WeChat-only wording in the UI**
- Frames: `169:5299`, P `210:9344` ("本局剩余免费次数：—（提示没有加载出来）", title "提示"); `160:1259` ("二维码图占位 · issue.qrcodeUrl（运行时由服务端下发）"); `169:8082` (a failure toast drawn on the normal share sheet: "个人码生成服务繁忙，请稍后重试"); `169:6672`, `169:6813` ("北京时间 YYYY-MM-DD" format strings as labels, and typed "纬度 / 经度（地图选点）" fields); P `204:14919` ("微信实付"); P `209:16053` ("手机号或微信号").
- Optimize: remove the bracketed notes; the hint count reads `—` with caption `次数没取到`. The QR frame shows a real code image. The share sheet's normal state has no toast; draw the failure as its own frame. Date fields are pickers (labels: `签到开始`). 实付 reads `实付` with the method as a value (`Apple Pay` or the actual channel). Contact field: `手机号`.
- Implement: Figma text and asset swaps; one new frame `089 share-sheet / error`.

**PL-06 · P1 · Overlapping and bleeding content**
- Frames: `185:5431`, `185:5510`, `185:5592`, P `210:10154`, `210:10232` (skeleton rows overlap the list; "再走近 455 米" and a place name sit under the tab bar); P `210:8239` (the feed title shows through the tab bar); `166:3280` (three section titles with nothing under them after the error block).
- Optimize: resolved by PL-20 for roam. Home: content insets by the tab bar height; in the error state, hide the empty section titles.
- Implement: Figma: set bottom padding 96 on scroll content; delete the orphan titles. SwiftUI: `safeAreaInset`; conditional sections.

### Batch B · One kit: bring R1 and R6 twins up to N1

**PL-10 · P0 · Two type scales and two button systems in one flow**
- Frames (old kit: 13–14 pt body, 36–40 pt rectangular or grey buttons): every R1 twin `166:*` and `169:*`; R6 twins `185:5191` – `185:6968`. Frames (new kit): N1 `204:*`, `205:*`, `207:*`, `208:*`, `209:*`; R1 states `228:*`.
- Problem: on page P a flow steps from a new-kit frame to an old-kit frame at almost every tap (e.g. `204:32786` CITY 棋盘 → `210:10544` old CITY; `209:14900` HUD → `210:9344` hint dialog; `204:33163` 圈地成功 → `210:10344` share card).
- Optimize: adopt section 2 everywhere. Body 15, caption 13, minimum 11; card title 17 Semibold; page title 28.
- Implement: Figma: publish the N1 local components (`204:7912`) as the player kit: `Player/Button` (Kind = Primary / Secondary / Text; Size = 44 / 52; State = Default / Pressed / Disabled / Loading), `Player/Top Pill`, `Player/Sheet`, `Player/State`, `Player/Status Tag`, `Player/Stat Tile`. Swap instances in all twins; bind text to the MP type styles. SwiftUI: `ButtonStyle`s `.playerPrimary`, `.playerSecondary`; `Font` tokens.

**PL-11 · P1 · Five different tab-root headers; titles that do not match their tab**
- Frames: P `210:8239` (logo, "Hi, 玩家小城!", avatar), `210:8322` (avatar, large "漫游"), `210:8374` (bell centred, icon tabs, search), `210:8452` (bell left, centred "发现"), `210:8603` (gear left, centred "主页"); R1 twins `166:2557`, `169:4853`, `169:3739`, `169:3927`, `169:4417`.
- Problem: the tab says 俱乐部, the page says 发现; the tab says 我的, the page says 主页. The bell moves between left, centre and absent.
- Optimize: one header: large left title equal to the tab label (首页 uses the greeting as its subtitle, not its title), and up to two glass circles at the right (消息 with badge, then the page's own action: search, settings). 消息 lives in the same place on all five.
- Implement: Figma: `Player/Root Header` (Title, Subtitle, Action1, Action2). SwiftUI: `.navigationTitle` large + `ToolbarItem(.topBarTrailing)`. Motion: large title collapses on scroll (system).

**PL-12 · P0 · Primary buttons that look disabled**
- Frames: `185:6355` (选择照片: grey pill), `185:6830`, `185:6865`, `185:6893` (继续扫描 / 重试: grey pills), P `210:8790` and `169:5653` (the only action on checkout is a dark "重新检查支付服务"), `204:15096` (a copy of frame 216 from another page; 看排行榜 is the primary on the result screen; 完成 is a text link), `169:11495` (加入队伍 page's only button is 查看队伍), `185:6927`, `185:6935` (显示队伍码 as a dark outline).
- Optimize: white pill for the one action that moves the player forward. Checkout: `支付 ¥29` enabled; when the pay service is unavailable, an inline line above it says why and the pill reads `重试`. Settle: primary `完成`, secondary `看排行榜`. Join: primary `加入队伍`.
- Implement: Figma: swap to `Player/Button` Primary. SwiftUI: as PL-10.

**PL-13 · P1 · Card-style alerts used for errors and loading**
- Frames: `169:5237`, `169:5268`, `169:5349`, `169:5375`, `169:5406` (a centred card with two stacked buttons); `185:6274`, `185:6296` (permission cards floating mid-screen); `185:6800` (核验成功 card); `205:8866` (地盘已释放 dialog); `207:2460` (level-up dialog).
- Optimize: errors are inline page states. Permission primers are full pages (PL-25). 已释放 is a sheet with the place's card. Level-up is a full-screen moment (PL-45).
- Implement: Figma: redraw with `Player/State` and `Player/Sheet`.

**PL-14 · P1 · Status by colour alone**
- Frames: the dot at the top right of `185:5707`, `185:5755`, `185:5803`, `185:5850`, `185:5980` (grey / amber / green with no label); the dot in the stat card of `185:5373`, `185:5431`; blue chips "线下活动 / 未开始" in P `204:14885`; the selected visibility chip in `169:4937`.
- Optimize: a status tag with icon and word: `定位中`, `记录中`, `已暂停`. Blue is not a status colour for "未开始": use the neutral tag.
- Implement: `Player/Status Tag` (State = Neutral / Live / Paused / Warning / Done). SwiftUI: `Label` in a capsule.

**PL-15 · P1 · The hint is a centred dialog titled "提示"**
- Frames: `169:5299`, P `210:9344`; entry in `209:14900`.
- Optimize: a `fit` sheet titled `要点提示吗` with the cost on each row as a coin value (`免费`, `5 积分`), the locked tier dimmed with `先看上一层`, and the remaining free count as a tag. The score breakdown is a disclosure row.
- Implement: `Player/Sheet`; rows as buttons. Motion: on reveal, the hint text unblurs over 300 ms; haptic `.impact(.light)`; if it costs 积分, the coin count in the HUD ticks down (`numericText`).

**PL-16 · P1 · Two CITY homes and two roam homes**
- Frames: CITY: N01 `204:21814` (城市大富翁) versus A10 `185:5191`, `185:5246`, P `210:10544`, and 收藏据点 `185:5305`, `185:5318`, P `210:10597`. Roam: R1 twin `169:4853` (carousel, 附近活动) versus R6 A13 `185:5327` (search bar, segmented 走起 / 漫游护照, "请先选择搜索区域").
- Problem: the prototype shows the old CITY page next to the new board, and the file holds two different roam roots.
- Optimize: CITY home is N01; A10 is retired from the prototype (keep it on R6 marked "superseded by N01"). 收藏据点 becomes a row inside N01. Roam root: one page (PL-21).
- Implement: Figma: remove `210:10544` and `210:10597` from flow 4; add a "已被 N01 取代" label to the R6 frames. Ask the owner once (Q-A).

### Batch C · Pages and flows

**PL-20 · P0 · Live roam covers the map (round 1, still open)**
- Frames: `185:5373`, `185:5431`, `185:5510`, `185:5592`; P `210:10097`, `210:10154`, `210:10232`.
- Problem: a stat card, a "本次漫游" list, two information rows ("锁屏后仍在记录轨迹", "附近玩家看不到你"), a 附近 block and the tab bar are stacked over the map. On the consent frame there are two primaries (`同意并出发` and the hold button `走起`).
- Optimize: the map is the screen. Top: glass back, a glass pill with three live numbers (用时 · 格子 · 公里), a glass layers button. Bottom: a `.height(120)` sheet with the pause control (large white circle), and 结束 as a secondary; pulled to `.medium` it shows 点亮格子, 同步状态 and 附近. The two information rows appear once as a 4-second glass banner at start, then live under an ⓘ. No tab bar during a session. Consent: one button (`允许使用位置`) that opens the system prompt; hold-to-start appears only after permission is granted.
- Implement: Figma: rebuild A14–A17 from the A19–A24 map frames plus `Player/Top Pill` and the new sheet; delete the stacked cards. SwiftUI: `Map` full-bleed, `.safeAreaInset(edge: .top)`, `.sheet` with detents and `presentationBackgroundInteraction(.enabled)`, `.toolbar(.hidden, for: .tabBar)`. Motion: numbers tick with `contentTransition(.numericText())`; a newly lit cell fades from fog over 600 ms with a soft outward ripple (PL-43); pause: the control morphs ❚❚ → ▶ in 220 ms, the route line dims to 50%; haptic `.impact(.medium)` on pause and resume.

**PL-21 · P1 · The roam root has a 150 pt void and a text link for location**
- Frames: `169:4853`, `169:5088`, `169:5164`, P `210:8322`.
- Problem: between the carousel and 附近活动 there is an empty band; "开启定位" is a small text link; the empty state is a card.
- Optimize: the root is the fog map preview (the player's lit cells, live) filling the top 55%, with the `走起` control over it; below, a peeking 附近 sheet. The carousel's two other cards (漫游护照, 地图) become glass buttons on the map. Without location: the map is dimmed and one button `打开定位` sits in its centre.
- Implement: Figma: compose from A19 `185:5707` and the 附近 peek. SwiftUI: same `Map` as PL-20 in idle state. Motion: on appear, lit cells fade in from the centre outward over 800 ms, once per launch.

**PL-22 · P1 · Home feed: a promo before the content, then 20 identical cards**
- Frames: `166:2866`, `166:2557`, `166:3175`, P `210:8239`.
- Problem: the first 250 pt is a "成为俱乐部" carousel. The feed is 6,700 pt of cards that all show the same placeholder route and three key–value rows (价格 免费 / 时间 长期开放 / 地点 …), about 210 pt each. "即将上线" cards carry four lines of text over art at unreadable size.
- Optimize: order by what the player came for: 编辑精选 (one large card), 附近活动 (horizontal), then the theme list. The promo carousel moves below 附近活动 as one slim banner. Theme card: cover (the route drawn on the real map, or the creator's cover), title, one meta line with icons (`免费 · 长期 · 黄浦区`), 132 pt tall. 即将上线: cover, title, date tag only.
- Implement: Figma: `Player/Theme Card` (Size = Large / Row / Tile; Cover = Photo / Route / Default). Default cover is the handbook's 一起玩 art, not the route glyph. SwiftUI: `LazyVStack`; `AsyncImage` with the route as a `MapSnapshot`. Motion: cards rise 12 pt and fade as they enter, 220 ms, once; press scale .97; card → detail uses a zoom transition (`matchedTransitionSource` + `.navigationTransition(.zoom)`).

**PL-23 · P0 · 主题详情 opens on two empty screens**
- Frames: `169:6954`, `169:7170`, `169:7386`, `169:7527`, `169:7668`, `169:7875`; P `210:9137`.
- Problem: the first 430 pt is a dark card with a route glyph and "查看详情与报名"; the next 270 pt is another empty hero with the same glyph; the title starts at about 730 pt. The stat strip has five 10–11 pt cells.
- Optimize: one hero: cover image full-bleed for 300 pt with glass back and share circles, then title, organiser row, and a four-cell stat row (评价 · 时长 · 站数 · 已参加) with 20 pt numbers. Tabs 详情 / 故事 / 路线 stick under the nav on scroll. A sticky bottom bar: price at the left (`免费` or `¥29 起`), the primary at the right (`报名` / `去票夹` / `开始`), bookmark as a glass circle in the nav.
- Implement: Figma: delete the first preview block; `Player/Detail Hero`, `Player/Sticky Bar`. SwiftUI: `ScrollView` + `.safeAreaInset(edge: .bottom)`; pinned `Picker` via `LazyVStack(pinnedViews:)`. Motion: hero parallax 0.5×, nav title fades in after 120 pt of scroll; tab underline slides 220 ms; haptic `.selection` on tab change.

**PL-24 · P1 · 活动详情 and checkout**
- Frames: `169:5432`, `169:5532`, `169:5653`, `169:5772`, `169:5885`; P `210:8708`, `210:8790`, `210:8892`.
- Problem: the page title "活动详情" sits above a card that repeats the activity name in 22 pt (two titles). "分类 未分类" prints an unknown as a value. Two equal buttons at the bottom (分享, 查看报名). Checkout shows a green banner "你已报名这场活动" on a page whose purpose is to pay; 积分抵扣 is a lone radio.
- Optimize: the activity name is the title; rows with unknown values are hidden. Sticky bar as PL-23. Checkout for someone already registered routes to the ticket instead of the pay page. 积分抵扣 is a switch row with the amount (`用 200 积分抵 ¥2`).
- Implement: Figma: redraw both; reuse `Player/Sticky Bar`. SwiftUI: `Toggle`; `PKPaymentButton` where Apple Pay applies.

**PL-25 · P1 · Two permission-primer styles, each with two buttons**
- Frames: `185:6274`, `185:6296` (floating cards), `185:6310`, `185:6333`, `185:6355` (full pages), `185:6379` (inline), `204:27378` (camera, N27), `207:2624` (steps, N72), `208:2661` (Live Activity, N86).
- Optimize: one full-page primer: the 3D icon, a headline that states the benefit, one sentence, then **one** white pill that opens the system prompt, and `以后再说` as a text link (HIG Privacy, ref 6). The "denied" variant's pill reads `去设置`. The inline variant keeps one button.
- Implement: Figma: `Player/Primer` (Permission = Location / Camera / Photos / Health / LiveActivity; State = First / Denied). SwiftUI: one `PermissionPrimerView`.

**PL-26 · P1 · Payment results**
- Frames: `185:6400`, `185:6428`, `185:6451`; P `210:9996`, `210:10023`.
- Problem: full-bleed green, red and amber gradients are the only large colour fields in the app; the ring icon is static; the amount row and order number wrap.
- Optimize: keep the black page; the colour lives in the icon and a soft 200 pt glow behind it. Success shows the ticket itself (the pass card slides up) with `查看票` as primary. Failure states the reason and offers `重试`; "返回套餐" is the text button.
- Implement: Figma: redraw three frames; reuse the 票夹 pass card. SwiftUI: `PKPaymentAuthorizationController` result → view. Motion: PL-46.

**PL-27 · P1 · 票夹 and participation**
- Frames: P `209:15819`, `209:15850`, `204:14885`, `204:14919`.
- Problem: the pass shows a route glyph on a grey field; "开始游戏" floats below it; the order page mixes ¥ lines with a status timeline.
- Optimize: a Wallet-style pass (ref 22): cover strip, title, date and place as two labelled fields, a QR or code area when needed, and the action inside the pass (`开始`). Passes stack; swipe between them.
- Implement: Figma: `Player/Pass`. SwiftUI: `TabView(.page)` or a stacked `ScrollView` with `.scrollTargetBehavior(.viewAligned)`. Motion: passes fan from the stack 300 ms on open; haptic `.selection` on page.

**PL-28 · P1 · Share sheets rebuild the system sheet, and the roam card shows a person placeholder**
- Frames: `169:4937`, `169:8082`, `185:6705`, `185:6726`; P `210:10344`, `210:10082`.
- Problem: 保存图片 / 发到广场 / 系统分享 as three custom circles; the roam card's hero is a grey person glyph; sharing a roam that has not started shows "— — —".
- Optimize: the card previews the real content: the route on the fog map, three numbers, date. One style picker (colour dots) and one switch (`带上路线`). Actions: primary `分享` (system sheet, which already has Save Image) and secondary `发到广场`. If there is nothing to share yet, the share entry is hidden.
- Implement: Figma: redraw A46 with the A45 route. SwiftUI: `ShareLink(item:preview:)` with a rendered `Image` (`ImageRenderer`). Motion: the card flips in 3D 400 ms when the style changes; haptic `.selection`.

**PL-29 · P1 · Search results and empty states use three different languages**
- Frames: `169:10147` (grey gradient cards without covers), `169:10223` (the only illustrated empty state in the file), `169:10309` (a blue banner for an error).
- Optimize: results reuse `Player/Theme Card` Row. Empty and error use `Player/State` (the illustration may stay as the icon of the empty state if the same style is drawn for the other empties; otherwise use the icon tile). The banner becomes the inline error.
- Implement: instance swaps.

**PL-30 · P1 · 我的: money, role tags and empty covers**
- Frames: `169:4417`, `169:4536`, `169:4655`, `169:4754`; P `210:8603`; N67 `207:2311`.
- Problem: a "BIZ" tag on a player profile; "账户余额 ¥288.50" beside the single currency 积分; the order card is a grey block; N67 already draws the better profile (原型 tag, mini six-stat row) but the twins do not use it.
- Optimize: adopt N67 as the profile header. Assets: 积分 first (large), 账户余额 only if real money exists for this user (Q-B). Orders show the pass thumbnail.
- Implement: Figma: replace the twin header with the N67 block. SwiftUI: none special. Motion: the six-stat mini bars grow from 0 on first appear, 400 ms, stagger 40 ms.

**PL-31 · P1 · 队伍详情 and 加入队伍**
- Frames: `169:10801`, `169:11148`, `169:11495`.
- Problem: 3,041 pt and about 900 characters on one page (round 1); the join page has two 22 pt titles and its button does not join.
- Optimize: team page = header (name, 2/4, status), members as an avatar row with roles, then three disclosure rows (规则, 记录, 邀请). Join page: team name as the title, members, `加入队伍` primary, expiry as a tag.
- Implement: Figma: redraw; `DisclosureGroup` rows. Motion: on join, the player's avatar drops into the empty slot with `spring(response: .35, dampingFraction: .6)`; haptic `.success`.

**PL-32 · P1 · Official activity pages are text lists of actions**
- Frames: `169:6340` (invites: three grey chips of text per card), `169:6555` (11 cards each with a row "主办控制台 · 发布 / 暂停 / 恢复"), `169:6813` (3,188 pt console: four chip groups, four text areas, a red full-width 暂停活动, then underline fields on a grey block).
- Problem: actions are written as slash-separated words; the console mixes three field styles and asks for latitude and longitude as typed text.
- Optimize: invites: role, time and quota as three icon–value pairs; 接受 primary, 拒绝 text. My activities: a status tag and one chevron; actions live in the console. Console: sections with one reason picker (pop-up) and one optional note instead of four chip groups and four text areas; the location is a map-pick row; 暂停活动 is a destructive row with a confirmation dialog.
- Implement: Figma: redraw with the player kit's rows. SwiftUI: `Form` in dark; `Picker(.menu)`; `confirmationDialog`. This is an organiser tool: restrained motion only.

**PL-33 · P1 · The 017 state frames are good; align their details**
- Frames: `228:4790`, `228:4894`, `228:5003`, `228:5109`, `228:5242`, `228:5361`, `228:5487`, `228:5606`, `228:5712`, `228:5849`, `228:5981`, `228:6090`.
- Problem: small ones: the status pill is a dot plus text (fine) but in three colours without icons; "现场参考" tiles show "—" with a two-line caption at 11 pt; the 已核销 state's primary is a disabled-looking "已核销" pill; the amber "结果待确认 · 点这里确认" bar is a link that looks like a banner.
- Optimize: status tag with icon. 已核销: the pill is replaced by a green check row and `评价` becomes the primary. The pending bar becomes a row with a chevron.
- Implement: instance swaps. Motion: each step in 现场记录 completes with the number morphing to a check (220 ms) and the connector line filling downward (300 ms); haptic `.success` on 核销.

**PL-34 · P1 · Club creation and club home**
- Frames: P `209:16053`, `209:16076`, `209:16104`, `209:16127`, `209:16004`, `204:15551`.
- Problem: steps 1 and 2 show a greyed 下一步 with no reason; step 3's options look like square checkboxes; the last step's primary is "成为俱乐部主理人" but the flow is a submission that needs review.
- Optimize: enabled primary that points at the first missing field; multi-select rows with trailing check marks; the last button reads `提交申请`, followed by a result sheet that says what happens next. (Detailed club findings are in the member-club review.)
- Implement: as config CF-17 for the error jump. Motion: step change slides 350 ms; the progress segment fills 220 ms.

**PL-35 · P2 · Messages (follows Flutter)**
- Frames: `156:624` – `157:1226`, `158:922` – `159:1285`, `159:1356` – `159:1991`; P `204:17590` – `204:18068`.
- Problem (within the Flutter structure): the top-right ✓ (mark all read) has no label and is the only control in the bar; avatars are single characters; "[消息为空]" bubbles and "图片 1" placeholders are shown as content; "合作池" sits above the inbox filter though it is a creator entry.
- Optimize: ✓ becomes a "⋯" menu with `全部标为已读`. Seed real thumbnails. Empty messages are not rendered. 合作池 moves under the filter as the first row of 通知与服务, or out of the player inbox (Q-C).
- Implement: Figma swaps. SwiftUI: `Menu`. Motion: sending: the bubble rises from the composer 220 ms; failed: a single shake and the red outline; haptic `.error`.

**PL-36 · P1 · Drawn system components**
- Frames: P `204:21385`, `204:21508` (a hand-drawn number pad); `227:12113` (calendar), `227:12350` (time wheels); `185:6742` – `185:6893` (scanner chrome is fine, but the viewfinder is a drawn QR).
- Problem: handbook d.5 forbids drawing the keyboard, calendar and pickers.
- Optimize: use the Apple iOS 27 kit's keyboard and date picker instances, or leave the area empty with a note. The verification field uses the system one-time-code autofill.
- Implement: Figma: instance swaps from the Apple kit. SwiftUI: `.textContentType(.oneTimeCode)`, `DatePicker`.

**PL-37 · P1 · The fog map's selected area reads as a rendering bug**
- Frames: `185:6028`, `185:6087`, `185:6124`, `185:6209`; P `210:10487`.
- Problem: selected or unconfirmed areas are solid black blocks with an orange outline and hatched patches, with no legend. N07's territory layer shows the same world far better.
- Optimize: fog is a soft grey veil; explored cells are clear; unconfirmed cells are clear with a dashed outline; the selected cell lifts with a white 2 pt ring. A legend row sits in the bottom card as in N07 (我的 / 别人的 / 可圈 / 未点亮). Remove the light variant.
- Implement: Figma: rebuild from `N1/迷雾地图`. SwiftUI: `MapPolygon` overlays; fog as a blurred `Canvas` mask. Motion: PL-43.

**PL-38 · P2 · Welcome and login**
- Frames: P `204:21349`, `204:21385`, `204:21508`.
- Problem: blue text links ("先随便看看", "进入商家版") in a neutral app; the agreement is a 16 pt circle.
- Optimize: `先随便看看` as the secondary pill; `我是商家` as a text button in 70% white. Agreement row is 44 pt high with the check at the left. `通过 Apple 登录` uses the system button and comes first (HIG ref 12).
- Implement: `SignInWithAppleButton`; `Player/Button`. Motion: the route line on the welcome screen draws itself once, 1.2 s ease-in-out, then the dots pulse once; Reduce Motion: static.

**PL-39 · P2 · Lists that print raw structure**
- Frames: `169:9760` (catalogue: "1 分钟 · 3 站", "未开售" tags are fine, covers mixed with placeholders), `169:9973` (catalogue detail: a large empty cover glyph), `169:6021`, `169:6155` (official activity list and detail with "—" in the first stat cell and disabled chips).
- Optimize: default cover art for missing covers; hide stat cells that have no value rather than leading with "—".
- Implement: instance swaps.

### Batch D · Game moments: motion and haptics (specs to annotate on the frames)

All of these are the handbook's game tier: one short animation each, skippable by tap, with a Reduce Motion fallback (cross-fade, haptic kept).

**PL-40 · P0 · No frame states its motion or haptic**
- Frames: every interactive player frame; the round-1 `motion-spec.md` exists but is not attached to frames.
- Optimize: annotate each frame type with the table in PL-48, and prototype the eight moments below.
- Implement: Figma annotations (category "Motion") plus Smart Animate prototypes.

**PL-41 · P1 · Page transitions are not specified**
- Optimize:
  - Push: system slide. Card → detail (theme, activity, club, pass): zoom transition from the card's cover.
  - Tab change: system cross-fade; tapping the current tab scrolls to top.
  - Into play / roam / camera / dice: full-screen cover rising from the button, 400 ms `spring(response: .45, dampingFraction: .86)`; exit reverses.
  - Map ↔ list: the sheet's detent, not a page change.
- Implement: SwiftUI `.navigationTransition(.zoom(sourceID:in:))`, `fullScreenCover`. Figma: Smart Animate with matching layer names for the cover.

**PL-42 · P1 · Hold-to-start "走起" has no progress or feedback**
- Frames: `185:5707`, `185:5755`, `185:5373`, P `210:10097`; lobby `204:15032`.
- Optimize: a ring fills around the pill during the 0.8 s hold; the map zooms in 6% with it; release early and the ring unwinds in 200 ms.
- Motion: ring `linear` 800 ms; on completion the pill bursts into the HUD pill (matched geometry, 350 ms). Haptic: a rising ramp (`CHHapticEngine` continuous, intensity 0.3 → 1.0) and `.success` at the end; cancel: `.impact(.soft)`. VoiceOver: double tap starts (`accessibilityAction`).
- Implement: Figma: three frames (rest, 50%, done). SwiftUI: `onLongPressGesture(minimumDuration:perform:onPressingChanged:)` + `trim(from:to:)`.

**PL-43 · P1 · Fog reveal and cell lighting**
- Frames: `185:5803`, `185:5850`, `185:6028`, `204:23260`.
- Optimize: when a cell lights, the fog over it dissolves from the player's position outward; the "发现新区域 · 38%" pill counts up.
- Motion: mask radius 0 → cell size, 600 ms ease-out; the cell's outline flashes white 20% → 0 over 400 ms; percentage `numericText`. Haptic `.impact(.light)` per cell, at most one per 2 s; a new district: `.success`. Reduce Motion: the cell cross-fades in 200 ms.
- Implement: SwiftUI `Canvas` with an animated mask; `TimelineView`.

**PL-44 · P1 · Claim: camera, four checks, success**
- Frames: `204:26708`, `204:26816`, `204:26924`, `204:26968`, `204:27073`, `204:27181`.
- Optimize and motion:
  - Shutter: the ring contracts 90% and springs back (160 ms); the photo flies into the sheet's thumbnail (350 ms). Haptic `.impact(.rigid)`.
  - Checks: each row's icon turns from a spinner to a check in order, 220 ms each with 150 ms between; a failing row shakes once and turns red. Haptic `.selection` per pass, `.error` on fail.
  - Success ("圈下了"): the flag plants on the map pin: it drops from 40 pt above with `spring(response: .4, dampingFraction: .55)`, the cell fills with the player's colour outward (500 ms), the 积分 pill ticks down. Haptic `.impact(.heavy)` at the plant, then `.success`. Total under 1.4 s; tap skips to the result card.
- Implement: Figma: add two in-between frames to N22. SwiftUI: `KeyframeAnimator`, `sensoryFeedback`.

**PL-45 · P1 · d20 challenge and level-up are still images**
- Frames: `204:34340`, `204:34369`, `204:34407`, `204:34440`, `204:34476`, `204:34510`; `207:2460`.
- Optimize and motion:
  - Roll: on `掷骰` the wireframe d20 tumbles (3D rotation on two axes) for 1.0–1.4 s while the server result is fetched; it lands with a bounce on the result face. If the server is slow, it keeps a slow idle spin (never a text "骰子在转…"). Haptic: light ticks every 120 ms while tumbling, `.impact(.heavy)` on landing.
  - Result: the number scales 1.4 → 1 and the sum line (`14 + 3 = 17`) counts in; win: the die turns green and the place card flips to the player's colour, `.success`; loss: the die dims and settles, `.warning` (no shake, no red flood).
  - 被抢 (N40): the flag on the card tips over (300 ms); calm, one `.warning`.
  - Level-up (N68): full-screen: the attribute's icon rises from its radar axis, the axis extends to the new value (600 ms), the new title appears; one primary `佩戴称号`. Haptic `.success`.
- Implement: Figma: 3 frames per moment. SwiftUI: `SceneKit` or a pre-rendered sprite for the die; `PhaseAnimator` elsewhere.

**PL-46 · P1 · Stamp, badge, settle and payment**
- Frames: `185:6464`, `185:6488`, `185:6512`, `185:6550`, `185:6588` – `185:6663`, `185:5674`, `204:15096`, `185:6400`.
- Optimize and motion:
  - Stamp: the seal drops and presses (scale 1.3 → 0.95 → 1, the handbook stamp spring `(.2,1.4,.5,1)`, 600 ms), ink ring spreads 200 ms; haptic `.impact(.heavy)` at contact. The counter (`12`) rolls.
  - Badge: the shield rises with a slow 3D tilt, stars fade in around it, 800 ms; tilt follows device motion afterwards. `.success`.
  - 这一趟: the route draws itself on the map (1.0 s), then the three numbers count up (400 ms). Replace the cloud-icon box (`185:6588`, `185:6638`) and the bare circle (`185:6663`) with the real route.
  - Settle: the trophy is replaced by what was earned: nodes fill 0 → 6 as dots, then the badge if any.
  - Payment success: the check draws (300 ms), the pass slides up (400 ms); `.success`.
- Implement: Figma: in-between frames; SwiftUI: `KeyframeAnimator`, `CMMotionManager` for tilt, `MapPolyline` with `trim`.

**PL-47 · P2 · Rent and leaderboard feedback**
- Frames: `204:33843`, `204:33946`, `205:9048`, `205:9126`, `205:9195`, `204:21814`.
- Optimize: when rent arrives while the board is open, the "+186" counts up and a coin arcs from the property row to the total (500 ms), `.impact(.light)`, at most once per visit. Leaderboard: the player's row slides to its new rank if it changed (400 ms spring) and the "我" row is pinned at the bottom when off-screen.
- Implement: SwiftUI `matchedGeometryEffect`; `safeAreaInset` for the pinned row.

**PL-48 · P1 · Utility motion and haptic table (annotate on frames)**

| Interaction | Motion | Haptic |
|---|---|---|
| Button / card press | scale .97, 80 ms; release 120 ms | none |
| Chip, tab, segmented | 140 ms cross-fade; underline slides 220 ms | `.selection` |
| Sheet present, detent, dismiss | section 3 | `.selection` on settle |
| Pull to refresh | system | system |
| Toast | rises 12 pt + fade 220 ms; leaves 180 ms | none; `.warning` if it reports a failure |
| Inline error appears | fade 140 ms | `.error` once |
| Skeleton → content | cross-fade 200 ms, after a 200 ms delay | none |
| Like / bookmark | icon fills with a 1.2× pop, 220 ms | `.impact(.light)` |
| Pin select on map | ring + scale 1.15, `spring(.3, .7)`; sheet rises | `.selection` |
| Scan recognised | corners snap inward 160 ms, green flash | `.success` |
| Number change (积分, 格子, 时间) | `numericText` roll | none |
| Destructive confirm | action sheet | `.warning` |

### Batch E · Accessibility and copy

**PL-50 · P1 · Text smaller than the game needs**
- Frames: stat labels and meta lines at 11 pt across the twins (e.g. `169:7170` stat strip, `166:2866` 即将上线 cards, `169:6340` chips, `204:21814` district rows, `207:2026` helper lines under each attribute).
- Optimize: 11 pt only for captions that are not needed to act. Meta lines 13, row values 15. The six-stat helper line ("今天 +45 / 200 · 下一个：Lv25 …") splits into a progress bar and a single next-goal chip.
- Implement: text style swaps; one `Player/Progress Row`.

**PL-51 · P1 · Dynamic Type has one proof frame**
- Frames: N73 `207:2683` is the only large-text frame.
- Optimize: add XXL proofs for the four most-used screens: home, 主题详情, play HUD (N87) and a property sheet (N08). Stat rows stack; pills grow to two lines; the HUD's three numbers become a vertical list.
- Implement: Figma frames; SwiftUI `ViewThatFits`, `@ScaledMetric`.

**PL-52 · P1 · Touch targets**
- Frames: glass ✕ on sheets (24–28 pt, N08 etc.), map pins (28 pt circles in `204:23260`, `185:5707`), the 16 pt agreement circle (`204:21385`), small text links ("开启定位" `169:4853`, "编辑" `204:15032`, "退出" in `209:16004`), "⋯" in feed posts (`161:1315`).
- Optimize: 44 pt hit areas; pins keep their size but get a 44 pt tappable region and cluster when closer than 44 pt.
- Implement: hit layers in components; `MapKit` clustering.

**PL-53 · P2 · VoiceOver labels and alternatives**
- Frames: icon-only glass buttons (layers, locate, flashlight, shutter), map pins, the radar chart, the dice.
- Optimize: labels in component descriptions (`图层`, `回到我的位置`, `拍照`); pins read "武康大楼，我的地盘，保护中"; the radar exposes six values as an accessible chart; the dice announces the result.
- Implement: `.accessibilityLabel`, `AXChartDescriptor`, `AccessibilityNotification.Announcement`.

**PL-54 · P2 · Copy**
- Frames and fixes: "Hi, 玩家小城!" (`166:2557` and five siblings) → `小城，今天去哪` as the subtitle; "网络开小差了" (`166:3225`, `169:5164`, `169:5632`) → `网络没连上，请重试`; "重新加载" → `重试`; "提示" as a title (`169:5299`, and the HUD button label may stay 提示 as a noun); ellipses "骰子在转…", "正在校验照片…", "正在加载地盘…", "发消息...", "消息加载中…" → no ellipsis; "内容已加载完" (`169:10147`) → remove; "选好了" (`169:5885`) → `选这张`; "知道了 / 好的" on result screens → `完成`. "圈下了！" and "拿下了！" keep their single mark (player celebration).
- Implement: find-and-replace per page.

**PL-55 · P2 · Currency marks**
- Frames: `169:4417` (¥288.50 balance), `169:5653`, `169:5885` (¥29 ticket), `185:6400` (¥199.00), `226:5149` (城市通票 ¥39.00).
- Optimize: real-money prices keep ¥ (lists: no decimals; bills: two). Everything earned or spent in play is 积分 with the coin glyph. Never both on one line without a label.
- Implement: text pass; Q-B.

**PL-56 · P2 · Merchant-theme frames on the player page**
- Frames: `225:17833` – `225:19690`, `226:4087` – `226:4869`, `227:11692` – `227:12673`, `220:7022` – `220:7159`, `169:8600`, `169:8660`.
- Note: these are light merchant pages placed on R1 (role = merchant, so light is right). They are consistent with each other (black pill, grey sheet). Findings: `225:18021` crowds four small chip-buttons per node (配置节点 / 供给无变化，重新确认 / 暂停供给 / 退出供给); the readiness list in `225:18644` uses square checkboxes; `227:11692` shows a red failure banner and a red field error at once. They are handed to the merchant-creator review for the full plan.

---

## 5 · Batch order

| Batch | Issues | Scope | Depends on |
|---|---|---|---|
| A · Defects | PL-01 – PL-06 | Tab bar component, prototype play and lobby, seed and leak text. | — |
| B · One kit | PL-10 – PL-16 | Publish the N1 kit; swap twins. | A |
| C · Pages and flows | PL-20 – PL-39 | Roam, home, detail, checkout, primers, share, profile. | B |
| D · Motion | PL-40 – PL-48 | In-between frames, prototypes, annotations. | C |
| E · A11y and copy | PL-50 – PL-56 | Type sizes, XXL proofs, targets, wording. | C |

## 6 · Questions for the owner (defaults used)

| # | Question | Default |
|---|---|---|
| Q-A | N01 城市大富翁 and the older A10 CITY 城市经营 are both in the prototype. Retire A10? | Yes: N01 is the CITY home. |
| Q-B | 我的 shows 账户余额 ¥288.50. Does the player hold real money, or only 积分? | Show 积分 first; show a ¥ balance only when it exists. |
| Q-C | 合作池 sits at the top of the player's 消息. Keep it there (Flutter does), or move it to the creator area? | Keep the Flutter position; restyle as a row. |

## 7 · Severity count

P0 10 · P1 31 · P2 8 · total 49.
