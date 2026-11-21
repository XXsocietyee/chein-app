# VERIFY r1 · Did the revisions fix the full-review issues?

Reviewer: Fable 5.2 · task `task_0a49d58cd090` · 2026-11-16 · review only (no Figma or code was edited).
Scope: the 205 issues in `full-config.md` (75), `full-player.md` (49), `full-member-club.md` (39), `full-merchant-creator.md` (42), against the Figma revision (file `0YyoybGnU1KG0657wdGCPX`) and the app on `ui/main` 165f6d593 plus `ui/h-polish-d-r1` 200edb508.

**Verdict.** The Figma file is in good shape: of 42 P0 issues, 32 are fixed and 10 are partly fixed; none is untouched. The app is a different story: 6 P0 are fixed, 21 partly, 6 not at all (9 are Figma-only), and the integration introduced one new P0 of its own: light editor pages opened from the dark player shell render with two themes at once, so 发布活动 on the real backend is unreadable (label contrast 1.13:1 to 1.29:1). Most of what the app "fixed" is a kit that exists in code but is not mounted on the pages, so the screens people see still look like round 0.

| | Fixed | Partial | Not fixed | No app work, or not checked |
|---|---:|---:|---:|---:|
| **Figma · P0 (42)** | 32 | 10 | 0 | — |
| **Figma · P1 (131)** | 96 | 32 | 3 | — |
| **App · P0 (42)** | 6 | 21 | 6 | 9 |
| **App · P1 (131)** | 10 | 50 | 65 | 6 |

The 32 P2 issues were not verified one by one.

---

## 0 · Method, and what I could and could not see

**Read in full:** the four reviews; the eight revision logs and their contact sheets (`revise/player.md`, `member-club.md`, `merchant-creator.md`, `cfg-AB.md`, `cfg-C.md`, `cfg-D.md`, `cfg-E.md`, `cfg-FG.md`); the five receipts on `ui/h-polish-d-r1` (`design-r1-A/B/C.md`, `integ-d-r1.md`, `polish-d-r1.md`); both screenshot indexes.

**Seen directly:**
- App: all 25 simulator screenshots in `integ-d-r1-shots/` and the 7 in `polish/` (paths below are relative to `/Users/fanning/chengyin-refs/integ-d-r1-shots/`). Contrast figures in this report were measured from the PNG pixels (WCAG relative luminance), not estimated.
- Code: targeted reads on `ui/h-polish-d-r1` to find root causes (`App/Theme/Theme.swift`, `App/Theme/RoleTheme.swift`, `App/DesignSystem/CYScreenStyle.swift`, `App/PublishingModesViews.swift`, `App/RoamLiveSessionView.swift`, `App/JourneyLandingViews.swift`, `App/ClubMembersView.swift`, string catalogs).
- Figma: **17 calls used of the 20 allowed** (1 `create_session`, which the server requires before any file tool, and 16 `get_screenshot`). Frames rendered: `210:8239`, `204:15032`, `185:5431`, `169:6954`, `182:7693`, `182:8065`, `183:1731`, `233:9703`, `186:5944`, `204:24591`, `204:30158`, `223:3698`, `238:20393`, `246:6728`, `249:16773`, `237:43689`. One of them (`186:5944`) came back 150 px wide because the frame is 2,370 pt tall; it shows layout gaps only.

**Evidence marks used in the tables:** **seen** = I rendered the frame or the screenshot shows it; **log** = the executor's log or receipt says so and I did not see it. A "fixed (log)" is a claim, not a check.

**What I could not see:**
- About 2,300 Figma frames were changed by script. I rendered 16. Everything else rests on the executors' own "Screenshot OK" lines.
- No tool measured Figma contrast or control sizes after the revision; the size census from the config review was not re-run.
- Prototype links, Smart Animate transitions and annotations are not visible in a still frame.
- App screens with no screenshot: play HUD, hint sheet, settle, payment, wallet, share, search, team, badges, merchant tab bar, refund, station, every sheet except registration. Their status comes from the receipts.
- `00-welcome.png` shows the home tab with a location card, not the welcome or login page, so PL-38 has no app evidence.
- **`06-live-roam.png` is not the shipped screen.** It is the `d6-live` design-fixture host. Receipt A says the shipped `RoamLiveSessionView` still uses the `List` HUD (`App/RoamLiveSessionView.swift:98`). See N-03.
- Receipts A, B and C were written without a Swift compiler. The integration build did succeed and 109 affected tests passed, but "done" in those receipts meant "written", and only the screens with screenshots have been looked at by anyone.
- Motion and haptics cannot be judged from stills. Reduce Motion handling exists in the kits (`QuestifyReduceMotion`, `CYMotion.resolve`), which I checked in code.

Mini-program screenshots were not opened or copied.

### New references used (none cited in the earlier reviews)

| # | Reference | Quote | Where it sharpens a finding |
|---|---|---|---|
| R1 | [HIG · Status bars › Best practices](https://developer.apple.com/design/human-interface-guidelines/status-bars) | "Be sure to keep the status bar readable, and don't imply that content behind it is interactive." | N-01: the status bar is white on a light page (1.10:1 and 1.12:1). |
| R2 | [HIG · Accessibility › Color and effects](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Minimum contrast: text up to 17 pt 4.5:1; 18 pt or bold 3:1. "If your app supports Dark Mode, make sure to check the minimum contrast in both light and dark appearances." | N-01, N-02: the numbers that fail. |
| R3 | [HIG · Sheets › Best practices and iOS](https://developer.apple.com/design/human-interface-guidelines/sheets) | "Include a grabber in a resizable sheet." "For sheets with a single view, the Cancel button belongs on the leading edge of the top toolbar. When present, the Done button belongs on the trailing edge." "If you provide a Done button, always pair it with a Cancel button." | D-06, N-08: the app's 关闭 text pill with no grabber is a fourth sheet header; Figma now has three by theme. |
| R4 | [HIG · Layout › Best practices, Guides and safe areas](https://developer.apple.com/design/human-interface-guidelines/layout) | "Respecting the safe area is essential to make sure system UI and hardware features… don't obstruct content and controls." "Instead of applying a solid or semi-opaque background color beneath controls, use a scroll edge effect to visually elevate controls above content." | N-10, N-11: the floating back circle covers titles; list text collides with tab-bar labels. |
| R5 | [HIG · Search fields › iOS](https://developer.apple.com/design/human-interface-guidelines/search-fields) | Three entry points: "As a tab in a tab bar · In a toolbar at the bottom or top of the screen · Directly inline with content". Inline search is for "more than one search field" where location matters. | N-12: the home root shows a search button and a search field for the same global search, 100 pt apart. |

Design skills used as lenses: `apple-design-review` (audit order and severity), `apple-design-interaction` (navigation model, disabled-with-reason, every state), `apple-design-os` (sheets, bars, button hierarchy), `apple-design-motion` (hold-to-start, press feedback, Reduce Motion), `apple-design-tactics` (contrast, colour-alone).

---

## 1 · Issue-by-issue status

Status words: **fixed**, **partial**, **not fixed**, **n/a** (no work for that side). Node ids are Figma frames; `shots/…` are app screenshots.

### 1.1 · P0 issues (42)

#### Config (14)

| ID | Figma | App | Evidence |
|---|---|---|---|
| CF-01 annotation text in UI | fixed (log) | fixed (AIGC line) | `cfg-AB.md`. But the revision added new in-frame placeholder text; see F-07. |
| CF-02 QA and seed strings | fixed (log) | n/a | `cfg-AB.md`: 10 names, 40 covers swapped. |
| CF-03 raw codes and ids | fixed (log) | partial | Tags in batch E (`249:24548`). App: status words done; node still picked by id, no 复制诊断信息 menu (receipt B). |
| CF-04 broken layouts | fixed (log) | n/a | `cfg-AB.md`; not re-rendered. |
| CF-05 blank centre tab | fixed (log) | **fixed (seen)** | `243:1807` per log; same component family seen in `210:8239`. App: `shots/03-tab-publish.png`. |
| CF-06 copy bug, dead text | fixed (log) | fixed (seen) | 56 frames; `shots/13-publish-activity-fixture.png` shows 活动地点. |
| CF-10 two field kits | **fixed (seen)** | partial | `237:43689`: one kit, filled fields on white cards. App still draws underline rows inside white cards (`shots/polish/12…`, `12b…`, `13…`): the kit is built, not mounted. |
| CF-11 five sheet headers | **fixed (seen)** | partial | `238:20393`, `246:6728`, `249:16773` share one header. Four C1 frames were listed as "not converted" in batch B (`238:22851`, `238:23143`, `239:3206`, `249:17994`) and no later log names them. App: only the new 还不能预览 sheet uses it. |
| CF-12 sheets three deep | **fixed (seen)** | fixed (receipt, static audit) | `238:20393` has one sheet edge; C2 and C3 scans report 0. Bases under sheets are static clones (F-12). |
| CF-15 targets under 44 pt | partial | partial | Hit areas are in the kit components (log). No size census was re-run; text links such as 去修改, 阅读剧情 ›, 修改 › in `249:16773` have no stated target. |
| CF-25 delete says three things | fixed (log) | **not fixed** | `237:68146`, `239:27044` redrawn, `237:68363` deleted. App: receipt B "left". |
| CF-39 hand-drawn date pickers | **partial (seen)** | partial | `246:6728`: wheels gone, replaced by a box that reads "系统日历 · DatePicker(.graphical)". `239:625` / `239:771` use drawn capsules. No system-kit instance anywhere. App: activity dates already native; topic dates unchanged. |
| CF-40 完成 pill that publishes | **fixed (seen)** | **not fixed (seen)** | `249:16773`: pill says 发布, blockers with 去修改, passed checks collapsed. App `shots/11…`: a disabled 提交审核 in the page and 检查并提交 in the bar, two submit buttons. |
| CF-52 dead-end result sheets | partial | partial | C2 `239:20809`, `239:20874` swapped to Editor/Result (log). The two C3 frames (`238:19113`, `238:19278`) got a date-copy fix only; no log says they gained buttons. App: component built, sheets not rewired. |

#### Player (10)

| ID | Figma | App | Evidence |
|---|---|---|---|
| PL-01 blank selected tab | **fixed (seen)** | **fixed (seen)** | `210:8239`; all five tab shots. |
| PL-02 play screen is an error card | fixed (log) | partial | `289:2596` replaces `210:9330`. App keeps the old play layout (receipt A). |
| PL-03 lobby cannot start | **fixed (seen)** | **partial (seen)** | `204:15032`: cover, 队伍 2/4, 怎么玩, 按住开始. App `shots/polish/10-lobby.png`: hold-to-start works, but no cover and no 怎么玩; the button says 去起点. |
| PL-04 seed and English strings | fixed (log) | n/a | 50+ strings (`player.md`). |
| PL-05 annotation and WeChat wording | fixed (log) | not checked | Receipt A: "no app strings found". |
| PL-10 two type scales, two button systems | partial | partial | Log says "Partly": twins off page P keep the old kit (`169:3833`, `169:4120`, `169:6068`, `169:9621`, `169:9899` and others). App: kit in place, pages adopt it "as touched". |
| PL-12 primaries that look disabled | fixed (log) | partial | Settle done; checkout 重试 variant is a note only. |
| PL-20 live roam covers the map | **fixed (seen)** | **partial, and the screenshot overstates it** | `185:5431`: full-bleed map, top pill, 120 pt sheet. App: the shipped view keeps the List HUD (receipt A); the screenshot is a fixture host (N-03). |
| PL-23 topic detail opens on empty screens | **fixed (seen)** | **not fixed (seen)** | `169:6954`: photo hero, four stats, sticky bar. App `shots/07-topic-detail.png`: route-glyph card, one stat, 未知 as a value, a blue chip. |
| PL-40 no frame states its motion | partial | partial | Notes on about 30 player frames and a wired prototype, not "every interactive frame". App: constants and the hold ring. |

#### Member and club (7)

| ID | Figma | App | Evidence |
|---|---|---|---|
| MC-01 创建 twins show the 申请 form | **partial (seen)** | fixed (flow), drifted (look) | R3 twins are right (`204:24591`). Page P `209:16053`–`209:16127` still shows the apply form as "create", and the player executor polished it further (F-01). App `shots/15…`, `15b…`. |
| MC-02 QA and raw strings | fixed (log) | **not fixed (seen)** | 358 text edits. App `shots/polish/17…`: "加入 2026-11-16 05:46:11" on every member row. |
| MC-03 spec boards as phone screens | fixed (log) | n/a | Section `306:33728` with labels. |
| MC-04 layout bugs | partial | n/a | `204:34773` 附近 (yellow line, cropped cover) left: not editable layers. |
| MC-10 wizards: three looks | fixed (log + seen) | partial (seen) | `204:24591` on the kit. App: enabled primary and cards, but a white header card on black and no check badge (N-08). |
| MC-20 destructive actions are tiny words | **partial (seen)** | partial (seen) | `223:3698`: ⋯ menu drawn, but a stray back circle and a black bar in the menu (F-03); `236:8395` chip × and the comment menu are left. App: member ⋯ and page-end rows done (`shots/polish/17…`, `16b…`); comment and post menus left. |
| MC-30 badges have no art | **fixed (seen)** | partial | `204:30158`: 12 badges in three shapes, locked and in-progress states. 集邮相机 `183:4653` left. App: art in rows only; no grid, no 3D detail. |

#### Merchant and creator (11)

| ID | Figma | App | Evidence |
|---|---|---|---|
| MR-01 onboarding has no submit | **fixed (seen)** | **partial (seen)** | `182:7693`: 5/5, four groups with 修改, consent, pinned 提交入驻申请. App `shots/polish/19…`: review and submit exist, but four steps (no identity step) and a white status bar. |
| MR-02 spec notes as UI copy | fixed (log) | n/a | Seven notes removed, seven state frames added (`318:7890` …). |
| MR-03 spec boards as screens | partial | n/a | Log: "labelled, not split". The four boards stay in their page sections. |
| MR-04 engineering wording | fixed (log) | partial | Card built, not wired. The app gained new engineering copy elsewhere (N-06). |
| MR-05 seed strings | fixed (log) | n/a | 30 texts. |
| MR-10 type scale | fixed (log) | partial | 1,254 bindings, 313 size fixes; R5 absolute twins got sizes only. |
| MR-11 two button systems | fixed (log + seen) | **partial, regressed** | `182:7693`, `183:1731`: radius 12, pinned. App: the stand-in swap turned merchant buttons into capsules (N-05). |
| MR-13 tab bar wrong tab, no labels | **fixed (seen)** | partial (receipt), not seen | `182:8065`: labels, 营销 selected. App: labels exist, selection tint left (receipt C); no screenshot shows the merchant tab bar. |
| MR-17 status colours contradict | **partial (seen)** | partial | `183:1731`: 平台审核中 is amber and 等待商家意见 is grey, the reverse of the rule (F-05). App: enum built, not swapped in. |
| MR-22 refund asked twice | **fixed (seen)** | **not fixed** | `183:1731`: pinned 不同意 / 同意退款 ¥39.00. App: receipt C "left". |
| MR-30 urgent task not primary | **fixed (seen)** | **not fixed** | `233:9703`: 核验 2 位玩家. 暂停接待 has no ⋯ to live in (F-04). App: "left". |

### 1.2 · P1 issues (131)

One line each. "F" = Figma, "A" = app. Evidence is the log or receipt unless a frame or screenshot is named.

#### Config (47)

| ID | F | A | Note |
|---|---|---|---|
| CF-13 resizable sheets | fixed | partial | 186 detent notes, 14 Large companions; app engine built, old sheets still use `cyDomainSheet`. |
| CF-14 two switch sizes | fixed | fixed | Tint now differs: Figma green, app black (F-08). |
| CF-16 toast styles | partial | partial | One component; not every validation toast was converted (no audit after batches C–E). |
| CF-17 disabled primaries | fixed | fixed | `shots/13…` shows an enabled 下一步. |
| CF-18 modal loading cards | fixed | partial | |
| CF-19 two nav families | fixed (seen `237:43689`) | partial | App editor has a 34 pt in-content title 创作玩法模板 and no nav title (`shots/polish/12…`). |
| CF-20 创作页 | fixed | partial | `shots/11…` is not the new page (D-08). |
| CF-21 B1 states | fixed | n/a | |
| CF-22 save chip | fixed | partial | Chip on two editors; the topic editor shows an amber 有未保存修改 pill instead. |
| CF-23 story flow | fixed | partial | Seam built, not mounted. |
| CF-24 effects as codes | fixed | not fixed | |
| CF-26 章节设置 | fixed | not fixed | |
| CF-27 主题详情 rows | fixed | not fixed | |
| CF-28 text pop-ups | fixed | partial | Live counters on two fields. |
| CF-29 node sheet | fixed (seen `238:20393`) | not fixed | |
| CF-30 template picker | fixed | not fixed | |
| CF-31 map pickers | fixed | not fixed | |
| CF-32 rule builder | fixed | not fixed | |
| CF-33 delete and add patterns | fixed | partial | |
| CF-34 selection | fixed | partial | |
| CF-35 destructive blocks | fixed | not fixed | |
| CF-36 画面风格 | fixed | not fixed | |
| CF-37 d20 vocabulary | fixed | not fixed | |
| CF-38 票务设置 | fixed | partial | |
| CF-41 result sheets | fixed | partial | |
| CF-42 entry sheets | fixed | not fixed | |
| CF-43 AI 助写 and others | fixed | not fixed | |
| CF-44 editor outline | fixed (seen) | partial (seen) | App has the section bar and cover; cards are not collapsed and the title is shown three times (N-09). |
| CF-45 two previews | fixed | fixed | |
| CF-46 option editors | fixed (seen) | partial | |
| CF-47 numbers and units | fixed (seen) | partial | |
| CF-48 奖励分 | fixed | fixed | |
| CF-49 typed identifiers | fixed | **not fixed (seen)** | 题目图片链接 and 题目音频链接 are raw URL fields (`shots/12b…`). |
| CF-50 sensor challenges | fixed | not fixed | |
| CF-51 选择玩法 | fixed | partial | |
| CF-53 tool sheets | fixed | partial | Built, not mounted. |
| CF-54 rewards as text | fixed | not fixed | |
| CF-55 D20 two ways | fixed | fixed | |
| CF-58 发布活动 | fixed | partial (seen) | Step bar present; fields are placeholder-only rows. |
| CF-59 AI 快速创建 | fixed | partial | The entry still reads 快速配置 (`shots/03…`). |
| CF-60 reorder motion | fixed | partial | |
| CF-61 template store | fixed | partial | |
| CF-62 external games | fixed | partial | 1,260 积分 is a placeholder number (Q6). |
| CF-63 static preview | fixed | partial | |
| CF-64 motion on frames | fixed | partial | 597 annotated frames, 8 prototypes. |
| CF-66 low contrast | fixed | partial | The app has new failures (N-01). |
| CF-67 Dynamic Type | fixed | partial | Three XXL proofs. |

#### Player (31)

| ID | F | A | Note |
|---|---|---|---|
| PL-06 overlapping content | partial (seen) | partial (seen) | `210:8239`: banner text shows through the tab bar. App: N-11. |
| PL-11 tab-root headers | fixed (seen) | partial (seen) | App: five header controls on 首页, centred title and no bell on 漫游, bell position moves (N-12). |
| PL-13 card alerts | fixed | fixed | |
| PL-14 status by colour | fixed | partial | Blue chips remain: 即将开始 (`shots/08…`), 城市定向 (`shots/07…`). |
| PL-15 hint dialog | fixed | fixed | |
| PL-16 two CITY and roam homes | fixed | fixed | |
| PL-21 roam root | fixed | **not fixed (seen)** | `shots/02-tab-roam.png`: white NO.01 card on black, 请先选择搜索区域. |
| PL-22 home feed | partial (seen) | partial | `210:8239` meta line overlaps (F-02). App: placeholder moon card. |
| PL-24 activity detail, checkout | fixed | partial (seen) | Two titles in `shots/08…`. |
| PL-25 permission primers | fixed | partial | |
| PL-26 payment results | fixed | not fixed | |
| PL-27 票夹 | partial | not fixed | `204:14919`, `209:15850` unchanged. |
| PL-28 share sheets | fixed | not fixed | `169:4937` title is clipped (log). |
| PL-29 search states | fixed | not fixed | |
| PL-30 我的 | fixed | partial (seen) | 积分 first; 账户余额 reads "560.00" with no ¥ (`shots/05…`). |
| PL-31 team | fixed | not fixed | |
| PL-32 official activity | partial | not fixed | Labels and notes only. |
| PL-33 017 states | **not fixed** | not fixed | Note only. |
| PL-34 club creation | partial | see MC-10 | Wrong flow on P (F-01); step-3 checkboxes left. |
| PL-36 drawn system components | partial | not fixed | Keypad and scanner done; calendar and wheels are notes. |
| PL-37 fog map | fixed | not fixed | |
| PL-41 page transitions | fixed | partial | |
| PL-42 hold-to-start | fixed | fixed (seen) | Ring and VoiceOver action; label mismatch (N-13). |
| PL-43 fog reveal | partial | not fixed | |
| PL-44 claim | fixed | not fixed | |
| PL-45 d20, level-up | fixed | partial | |
| PL-46 stamp, settle, payment | fixed | not fixed | |
| PL-48 utility motion table | fixed | partial | |
| PL-50 small text | partial | not fixed | Only N64 and N01. |
| PL-51 Dynamic Type proofs | fixed | not checked | Four proofs. |
| PL-52 touch targets | partial | not checked | Component descriptions only. |

#### Member and club (26)

| ID | F | A | Note |
|---|---|---|---|
| MC-05 WeChat wording | fixed | not fixed | |
| MC-11 title changes with state | fixed | not fixed | R3 only; nav variants hidden, not swapped. |
| MC-12 generic states | fixed | not fixed | |
| MC-13 switch tints | fixed | partial | |
| MC-14 arrows and chevrons | fixed | **not fixed (seen)** | Two chevrons on one row (`shots/16…`, `16b…`). |
| MC-21 buttons under 44 pt | fixed | partial | |
| MC-22 club home | fixed | partial (seen) | Three truncating tiles remain (`shots/16b…`). |
| MC-23 club settings | partial | not fixed | Group order not changed. |
| MC-24 活动运营 | partial | not fixed | State frames keep the long layout. |
| MC-25 roster, 核销详情 | partial | partial (seen) | App mounts the card on the members screen, a different use (N-14). |
| MC-26 群发, 角色 | fixed | not fixed | |
| MC-27 主题管理详情 | partial | not fixed | 接管 form not split. |
| MC-28 工作台 | fixed | not fixed | |
| MC-29 结算, 会费 | partial | partial | |
| MC-32 我的项目 | fixed | not fixed | |
| MC-33 delete dialogs | fixed | partial | Built, not swapped in. |
| MC-34 城瘾玩法 | partial | not fixed | Not the G6 icons. |
| MC-35 orders | fixed | partial | |
| MC-36 我的参与 | fixed | not fixed | |
| MC-37 money pages | partial | not fixed | |
| MC-38 我的队伍 | fixed | not fixed | |
| MC-39 roam history | partial | not fixed | |
| MC-40 成长中心 | fixed | not fixed | |
| MC-50 motion | partial | partial | Nine notes. |
| MC-51 text under 12 pt | partial | not fixed | Red 11 pt only. |
| MC-52 contrast | partial | not fixed | Three buttons. |

#### Merchant and creator (27)

| ID | F | A | Note |
|---|---|---|---|
| MR-06 layout bugs | fixed | n/a | |
| MR-07 WeChat hand-offs | fixed | fixed | |
| MR-12 nav styles | partial (seen) | not fixed (seen) | `182:8065` has no page title at all. App: centred 商家工作台 over "Hi, …" (`shots/18…`). |
| MR-14 sheet headers | fixed | not fixed | |
| MR-15 chips | partial | partial | `221:3108` not redrawn. |
| MR-16 generic states | fixed | not fixed | |
| MR-18 blue links | partial (seen) | not fixed | A blue copy icon in `183:1731`. |
| MR-19 contrast | fixed | not fixed | Token edits; not re-measured. |
| MR-20 workbench | fixed | partial (seen) | N-07. |
| MR-21 ledger | partial | partial | |
| MR-23 口碑 | fixed | not fixed | |
| MR-24 AI 参谋 | **not fixed** | not fixed | Note only. |
| MR-25 城市节点 | partial | not fixed | |
| MR-26 品牌中心 | partial | not fixed | Annotated, frames dimmed. |
| MR-27 AI voice | **not fixed** | not fixed | Only 清除声音 → ⋯. |
| MR-28 合作中心 | fixed | not fixed | |
| MR-29 客户, 成员 | partial | not fixed | Menu annotated, not drawn. |
| MR-31 公开主页 | fixed | not fixed | |
| MR-32 营销 | partial (seen) | not fixed | Grey bar behind the coupon card in `182:8065`. |
| MR-34 superseded twins | fixed | n/a | Left on the page at 45% opacity (F-10). |
| MR-35 协作邀请 | partial (seen) | not fixed | `186:5944`: holes where text was hidden. |
| MR-36 协作详情 | partial | not fixed | |
| MR-37 找商家承接 | partial | not fixed | |
| MR-38 分润, 结算 | fixed | partial | |
| MR-40 注销, 隐私 | fixed | not fixed | |
| MR-42 motion | fixed | partial | 25 reactions. |
| MR-43 Dynamic Type, targets | fixed | partial | Three proofs. |

---

## 2 · New problems the revisions introduced

Severity uses the same scale as the reviews. "N" = app, "F" = Figma.

### 2.1 · App

**N-01 · P0 · Light pages inside the dark player shell render in two themes**
- `shots/14-publish-activity.png` (发布活动 from the 发布 tab on TEST): page `#000000`, cards `#1C1C1E`, but labels use the light palette's ink. Measured: 选择地点 and 活动日期 `#000000` on `#1C1C1E` = **1.23:1**; placeholders 活动标题, 开始时间 `#262629` on `#1C1C1E` = **1.13:1**; step label 活动内容 = **1.29:1**; step 1 (基本信息) is not visible at all (1.0:1). The bottom bar and the save chip are light. The same page in the fixture (`shots/13…`) is fine, so the fixture hides the bug.
- `shots/11-topic-editor-story-flow.png` (topic editor): the reverse mix. Page `#F2F2F7` and white cards, but the values 城市定向 and 1 · 1 · 1 are `#F8F8F8` on white = **1.06:1**, the 模式 label 2.38:1, the status bar white on light = **1.12:1**, and the bottom bar is black. The back button is drawn for the dark scheme, so it is invisible and its circle cuts the first glyph of the title and the subtitle ("城市定向" reads "戈市定向").
- `shots/polish/19-merchant-onboarding-step4.png`: status bar **1.10:1** (the polish receipt lists this as open item 5b).
- Why (most likely; read from the code, not run): `themeDomain(_:)` (`App/Theme/Theme.swift:28`) sets the palette, the environment colour scheme and `preferredColorScheme` for the page, but the role root also forces `.dark` (`CYScreenStyle.swift:18`, `RoleTheme.swift:35`) and wins for the window. Palette colours follow the page; UIKit-backed surfaces (Form and List backgrounds, the status bar, bar buttons) follow the window. Two sources of truth, three different mixes on three pages. The sampled colours fit this: `#1C1C1E` and `#F2F2F7` are system grouped backgrounds, not palette tokens.
- Rule broken: R2 (4.5:1; 3:1 for bold) and R1 ("keep the status bar readable").

**N-02 · P0 · The topic editor is the worst screen in the set and nothing in the receipts says so**
- `shots/11…`: besides N-01, it has two submit controls (a disabled 提交审核 with no reason, and 检查并提交), a 发布状态 card of four numbered chips that duplicates the step idea, a disabled-looking row 查看已保存的原发布请求 with the sentence "当前账号、编辑目标或读取权限不支持查看原请求。这不代表本机没有记录。", and a bottom bar whose pills are not full width. None of the Figma 创作页 (`237:31646`) is there. Receipt B marks CF-20 "partial" on the strength of row menus that this screenshot does not show.

**N-03 · P1 · The live-roam screenshot is of a fixture, not of the shipped view**
- `shots/polish/06-live-roam.png` comes from the `d6-live` design host (`App/DesignFixtures/DesignFixtureRegistry.swift`). The shipped `RoamLiveSessionView` is still a `List` HUD (`App/RoamLiveSessionView.swift:98`, receipt A: "the List HUD remains"). So there are now three live-roam designs: Figma `185:5431`, the fixture, and the real one. A reviewer looking at the contact sheet would mark PL-20 done.

**N-04 · P1 · Kits were built but not mounted, and the receipts read as progress**
- About 40 issues are "partial" because a component exists with no call site: `EditorCard`, `EditorCardFooter`, `EditorResultContent`, `EditorInsertSeam`, `EditorGameplayPickerGrid`, `EditorToolChip`, `EditorReadOnlyGroup`, `ClubConsequenceSheet`, `MerchantR1OutcomeUnknownCard`, `MerchantR1Status`. Unmounted code is not a fix and it rots. The next round should count only what a screenshot shows.

**N-05 · P1 · Merchant buttons lost their shape in the integration**
- The integration replaced `MerchantR1ButtonStyle` (radius 12, 46 high, the merchant rule) with `CYPillButtonStyle` (a capsule). `shots/polish/19…` shows 提交入驻申请 as a capsule; Figma `182:7693` and `183:1731` draw radius 12. The merchant and player themes now differ only by colour.

**N-06 · P1 · New engineering wording, the thing MR-04 set out to remove**
- "“—”表示服务端还没有给出今天的数字。" (`Resources/DesignR1Merchant.xcstrings`, `shots/18…`).
- "照片会先在本机裁成16:9。上传、填入模板和保存模板是三个独立动作。" (`Resources/ActivityCoverAuthoring.xcstrings`, `shots/polish/12…`).
- "当前账号、编辑目标或读取权限不支持查看原请求。这不代表本机没有记录。" (`Resources/ApprovedReleaseOriginalRecovery.xcstrings`, `shots/11…`).
- "暂时无法保存修改。" on a page where nothing is being saved (`shots/15a…`).

**N-07 · P1 · The merchant Today card shows two dashes and a footnote**
- `shots/18…`: 今日核销 "—", 今日收入 "—", 待处理 3. Owner default Q-C moved the hero to "today" before the server could answer it, so the hero is two-thirds empty every day. The old cumulative number was at least a number. Also: centred nav title 商家工作台 plus a 34 pt "Hi, …" greeting (two titles), and 待办事项 as a grey regular header.

**N-08 · P1 · Club create wizard: a white card on black, a jumping primary, a missing count**
- `shots/15…`, `15b…`: the step header is a white card on a black page (Figma `204:24591` draws a four-segment bar, eyebrow and title on the page). 下一步 sits at 93% of the screen height in step 1 and at 67% in step 2, because it follows the content instead of being pinned. Step 2 shows no "已选 2 / 3". Options use a hollow circle with no check badge. The 关闭 pill is grey and reads as disabled; there is no back between steps in the shot.

**N-09 · P1 · Gameplay editor: the title three times, the bar above the title**
- `shots/polish/12…`: 创作玩法模板 (34 pt), then the template name on the cover, then the 名称 field. The section bar sits above the big title, so it is not a sticky outline under the nav as in `237:43689`. The cover title is white on a pale grey placeholder. Fields are underline rows, not the kit's filled fields.

**N-10 · P1 · A floating back circle covers content**
- `shots/08…`, `16…`, `16b…`: the back circle sits below the nav bar, half over the hero's corner. When the page scrolls it stays and covers the section heading ("成员身份" reads "戊员身份" in `16b`). The pages also keep a centred nav title (活动详情, 俱乐部详情) that repeats nothing useful. R4.

**N-11 · P1 · List content collides with the floating tab bar**
- `shots/03…` (the next row's label shows through 发布 and 我的 as broken glyphs), `shots/polish/04…`, `shots/05…`. The bar is glass over scrolling text with no scroll-edge effect, so two layers of text are read at once. R4.

**N-12 · P1 · Tab-root headers are still five different headers**
- 首页: language, ＋, search, ⋯, bell, and a search field under them, and a role line, and a 更多玩法 menu (`shots/polish/01…`). 漫游: centred small title, ⋯, no bell (`shots/02…`). 发布: layers, ⋯, bell. 俱乐部: bell, refresh. 我的: gear, bell. The bell is first on one tab, last on three, absent on one. PL-11 asked for "up to two" actions with 消息 in one place. R5 for the doubled search.

**N-13 · P1 · Lobby: the label and the gesture disagree**
- `shots/polish/10…`: the button reads 去起点 with the caption 按住开始. A tap does nothing visible. Figma `204:15032` puts 按住开始 on the button. The 房主 badge is brown text on a brown fill and cannot be read; 撤回 is a 13 pt red word (the pattern MC-20 removed).

**N-14 · P2 · Members screen: the roster card was mounted where it does not belong**
- `shots/polish/17…`: MC-25 designed the card for 报名名册 (capacity bar, 实收 · 已退 · 净额). On 成员 it repeats the club name that is already the subtitle 20 pt above it, and ends with a bare "4". Rows show raw timestamps (MC-02).

**N-15 · P1 · 创建俱乐部 leads to a dead end with contradicting numbers**
- `shots/polish/04…`: a white primary 创建俱乐部 sits above a warning that says the limit is reached ("你已创建 5 个俱乐部，上限是 2 个"). Tapping it opens `shots/15a…`: "你已创建两个俱乐部", an unrelated "暂时无法保存修改。", a hairline that starts mid-screen, and no action except 关闭.

**N-16 · P2 · Small ones**
- 账户余额 "560.00" with no currency mark beside 积分 820 (`shots/05…`); 票夹 appears as a white primary and again as a circle 250 pt lower.
- Club detail: a full-width card that holds one chip; a 成员身份 section whose only content is "创建者不能退出自己的俱乐部。"; hairlines at the top inside cards (`shots/16…`).
- Activity detail: the stat strip is cut at the right edge ("11月21日 14:"); "¥58 起" three times (`shots/08…`).
- Registration sheet: 合计 and 票种 values render as white bars (`shots/09…`).

### 2.2 · Figma

**F-01 · P0 · Two executors fixed "create a club" in opposite directions**
- The member-club executor rebuilt the R3 twins from the real flow (类型 → 方向 → 资料 → 城市, `204:24591` …). The player executor, working on page P, kept the wrong frames (`209:16053`–`209:16127`, the 申请主理人 form), enabled their buttons, renamed the last one 提交申请 and added a "申请已提交" sheet. The prototype's flow 5 is called 创建俱乐部 and walks the apply form. MC-01's own fix line ("relink page P flow 5") is still open, and it is now harder to notice.

**F-02 · P1 · Home card meta line overlaps itself**
- `210:8239`: under 外滩钟声 · 老城寻踪三章 the meta reads "免费免费 · 长期长期 · 浦黄浦区": icon-and-text pairs are clipped into each other. This is the first card of the first screen of the prototype. Check every `Player/Theme Card` Large instance.

**F-03 · P1 · Member sheet: a stray back button and a broken menu**
- `223:3698`: the log says this is now "the pushed 成员管理 page (back ‹)". The frame shows ✕ in the header and a back circle floating at the left edge at mid-height. The menu has an opaque black bar between 临时封禁 and 移除. All three members share one avatar.

**F-04 · P1 · "Moved to ⋯" without a ⋯**
- `233:9703`: the log says 暂停接待 moved to ⋯. The frame's header has only a back chevron, so pausing a station is not reachable in the design. The same phrase appears for 下线 (`182:8448`), 清除声音 (MR-26, MR-27), and 移除 (`233:11700`, "menu annotated, not drawn"). A feature that exists only in a note will be dropped by the next person who builds from the frame.

**F-05 · P1 · Refund page: status colours reversed, a raw date, a blue icon**
- `183:1731`: 平台审核中 is amber although the platform (someone else) is acting, and 等待商家意见 is grey although the merchant must act. The merchant rule says the opposite (needs me: amber; waiting on someone else: grey with a clock). 申请时间 reads "2026-11-14 19:28". The copy icon is blue. The 申请原因 and 补充凭证 cards touch with no gap.

**F-06 · P2 · 营销 root has no title**
- `182:8065`: the nav band is empty; the page starts with "近 30 天报名". A grey rounded bar shows behind the coupon card. "管理 →" still uses an arrow.

**F-07 · P1 · Placeholder text inside phone frames is back**
- `246:6728` ("系统日历 · DatePicker(.graphical)", "可选范围：今天之后"), `204:21385` ("系统数字键盘（不绘制）"), and drawn capsule stand-ins in `239:625` and `239:771`. CF-01 removed designer notes from frames; these are new ones, and the two date stand-ins differ (a graphical placeholder in C1, compact capsules in C3).

**F-08 · P1 · Three answers for the switch tint**
- Editor frames use green (`mp/switch-on`, seen in `237:43689` and `246:6728`). Player and club frames were moved to neutral (owner Q-B). The app's editor draws a black track (`shots/12b…`).

**F-09 · P2 · Blue text links in C1**
- `249:16773`: 阅读剧情 › and 修改 › are blue. Batch E rebound 64 blue fills to ink on C3 and the merchant pass removed 81 more; C1 was not swept.

**F-10 · P2 · Retired frames left in place, dimmed**
- `227:17672`, `227:18612` (50% opacity), the 12 R5 publish twins (45%), `182:8521`, and the R6 A10 and A11 frames with notes. Dimmed frames still render in exports and searches. Move them to an "Archive" page.

**F-11 · P1 · Duplicate and parallel components**
- Two components are both named `Editor/Result`: `290:20551` (batch C) and `290:22148` (batch D), with different properties.
- Four kits each carry their own button, state, status tag, toast and sheet (`Editor/*`, `Player/*`, `Club/*`, `Merchant/*`), and the club frames mix `Editor/Field` and `Editor/Row` into dark pages. This is workable while they are token-bound, but nobody owns the overlap.

**F-12 · P2 · Pages under sheets are stale clones**
- Batch C: "Base layers under sheets are clones of the new pages (static copies)". Batch D: editor bases under A3, A5, A8, A10, A11, A12 still show the old 1:1 hero. A sheet appears to open over an older version of its own page.

**F-13 · P2 · Small ones**
- `204:15032`: the back circle is cut by the frame's left edge and overlaps the eyebrow; the primary touches the role row.
- `169:6954`: the status bar is white over a pale sky (R1).
- `238:20393`: the log says the sheet ends with a quiet red 删除节点; the frame I rendered does not show it. Please confirm.
- Device chrome differs between frames (Dynamic Island on C1 sheets, plain status bar elsewhere).
- `186:5944`: empty bands inside cards where text was hidden.
- `Editor/Sheet` header (✕ left, 完成 right, title centred below), `Player/Sheet` (title left, ✕ right) and `Merchant/Sheet Header` (centred title, ✕ right) are three decisions made by three reviews. That is defensible per theme, but it should be written down once (Q10). R3.

---

## 3 · Figma versus code drift

"Drift" here means the app does not match the *revised* Figma. Rows are ordered by how much a player or creator sees them.

| # | Screen | Revised Figma | App today | What differs |
|---|---|---|---|---|
| D-01 | 首页 | `210:8239` | `shots/polish/01-home.png` | Figma: title, subtitle, two circles (消息, 搜索), photo card, 附近 rail. App: five header controls, a search field, a role line, a 更多玩法 menu, then a placeholder card. |
| D-02 | 漫游 root | `169:4853` (map first, 走起 over it, 附近 sheet) | `shots/02-tab-roam.png` | App is the old page: centred title, segmented 走起 / 漫游护照, white carousel cards, 请先选择搜索区域. |
| D-03 | Live roam | `185:5431` | shipped `RoamLiveSessionView` (List HUD); fixture in `shots/polish/06…` | Three designs. Even the fixture lacks back, the info banner, the 结束 label and the sheet. |
| D-04 | 主题详情 | `169:6954` | `shots/07-topic-detail.png` | Photo hero and four stats versus a glyph card and one stat; price-left sticky bar versus a button and an oversized share circle; nav title 路线详情. |
| D-05 | 活动详情 | `169:5432` | `shots/08-activity-detail.png` | Title is the activity name versus 活动详情 plus the name; sticky bar layout; blue status chip. |
| D-06 | Ticket and registration sheet | `169:5885` (grabber, title left, ✕ right, 选这张) | `shots/09-ticket-sheet.png` | 关闭 text pill at the left, centred title, no grabber. |
| D-07 | 开局大厅 | `204:15032` | `shots/polish/10-lobby.png` | Cover and 怎么玩 missing; 去起点 versus 按住开始; status tag 等队友加入 missing. |
| D-08 | 创作页 (topic editor) | `237:31646` | `shots/11-topic-editor-story-flow.png` | Nothing matches: nav, chip, segmented control, chapter cards, bottom bar. |
| D-09 | 玩法编辑器 | `237:43689` | `shots/polish/12…`, `12b…` | Nav title, sticky bar position, collapsed cards, filled fields, option rows, card footer; switch tint. |
| D-10 | 发布活动 | `237:59431` | `shots/13…`, `14…` | Fields are placeholder-only underline rows; no back in the fixture; unreadable on TEST (N-01). |
| D-11 | 创建俱乐部 | `204:24591` | `shots/15…`, `15b…` | Header card, progress bar, check badge, back, pinned primary (N-08). |
| D-12 | 俱乐部主页 | `204:24899` (`Club/Header`) | `shots/16…`, `16b…` | Old header; three tiles; extra 成员身份 section; double chevrons. |
| D-13 | 成员 | `223:3698` (sheet with 邀请成员) | `shots/polish/17…` | A pushed page with a roster card; no 邀请成员; raw dates; initials instead of avatars. |
| D-14 | 商家工作台 | `182:7328` (shop name 22 Bold, 营业中, Today card with numbers) | `shots/18-merchant-workbench.png` | Centred title plus greeting; dashes; no 营业中. |
| D-15 | 商家入驻 review | `182:7693` (5/5, five-segment bar, radius-12 button) | `shots/polish/19…` | "4. 预览确认", no progress bar, capsule button, labels heavier than values. |
| D-16 | 我的 | `169:4417` (N67 header) | `shots/05-tab-me.png` | Old header; balance with no ¥; duplicate 票夹. |

The pattern: the Figma executors redrew whole screens; the app agents built components and changed a few rows. Only the tab bar, the root titles, the club create flow's logic and the merchant review step are recognisably the same design on both sides.

---

## 4 · Prioritised fix list for the next Opus round

Each item: the issue, how to fix it, how to implement it (files or nodes), and the batch. Batches are ordered; inside a batch, do the items in the order listed.

### Batch 1 · App: make every screen readable (blocking; do first)

| # | Issue | How to fix | How to implement |
|---|---|---|---|
| 1.1 | N-01 two themes on one page | One source of truth for the scheme. A light-domain page decides the window's scheme while it is on screen; the root stops forcing dark unconditionally. | `App/Theme/Theme.swift`: in `themeDomain(_:)` keep `.environment(\.colorScheme, …)` and add `.preference(key: CYShellSchemeKey.self, value: domain.colorScheme)` (reducer: last non-nil wins, so the deepest pushed page decides). At the role root (`roleTheme` in `App/Theme/RoleTheme.swift:35` and `CYScreenStyle` in `App/DesignSystem/CYScreenStyle.swift:18`): hold `@State shellScheme`, read it with `.onPreferenceChange`, apply `.preferredColorScheme(shellScheme ?? role.domain.colorScheme)`, and stop calling `.preferredColorScheme` from inside `themeDomain` (`Theme.swift:31`), so only the root sets it. A preference clears itself on pop, so no `onAppear` / `onDisappear` bookkeeping. Sheets are unaffected: a presentation owns its scheme, and their content already calls `themeDomain(.topicEditor)`. This is a proposal from reading the code, not something I ran; the polish receipt (item 5b) reached the same diagnosis. Test: a new `DesignR1ThemeArbitrationTests` that pushes each editor from the player shell and asserts the hosting controller's `userInterfaceStyle` is `.light`; plus Lane2 screenshots of 发布活动 (TEST, from the 发布 tab), the topic editor and merchant onboarding. Accept when every text pair measures at least 4.5:1 (3:1 bold) and the status bar is dark on light. If the preference route fails, the fallback is to present these three flows with `fullScreenCover`, which owns its scheme (Q5). |
| 1.2 | N-02 topic editor | After 1.1, remove the duplicate submit and the engineering row; make the bar one secondary and one primary, full width. | `App/ProjectEditView.swift`: delete the 提交审核 button inside the 发布状态 card (keep 检查并提交 in the bar, renamed 发布 to match `249:16773`); hide 查看已保存的原发布请求 unless it can be opened; bottom bar through `EditorBottomBar`. This is a stop-gap until 3.4 rebuilds the page. |
| 1.3 | N-10 back circle over content | The back button lives in the navigation bar on pages that scroll; the glass circle is only for a full-bleed hero and scrolls away with it. | `App/DesignSystem/CYScreenStyle.swift` (`CYHeroPushedChromeModifier`): place the circle inside the hero's own overlay (top-leading, safe-area inset) instead of a screen overlay; when the hero has scrolled out, show the system back in a `.toolbar`. Apply to activity detail and club detail; drop their centred titles (use the object's name with `.inline` after the hero scrolls out). |
| 1.4 | N-11 text under the tab bar | Give the floating bar a scroll-edge effect so content fades before it reaches the labels. | Where the bar is installed (`CYNightTabBar.swift` / `CYDomainTabBar.swift`): on iOS 26+, `.scrollEdgeEffectStyle(.soft, for: .bottom)` on the tab roots' scroll views; before that, a 32 pt gradient mask from the page colour under the bar. Check all five roots at scroll rest and mid-scroll. |
| 1.5 | MC-02 raw timestamps; N-16 balance | Dates as `11月16日`; money with ¥ and two decimals. | `App/ClubMembersView.swift:267` (`displayedJoinTime`): format with `Date.FormatStyle` (`.dateTime.month().day()`, locale-aware). `App/MemberHomeHeader.swift`: `.currency(code: "CNY")`. |
| 1.6 | N-06 engineering wording | Say what the person can do, not how the system works. | `Resources/DesignR1Merchant.xcstrings`: "“—”表示…" → `今天还没有数据`. `Resources/ActivityCoverAuthoring.xcstrings`: → `封面会裁成 16:9`. `Resources/ApprovedReleaseOriginalRecovery.xcstrings`: hide the row when unavailable. `shots/15a` "暂时无法保存修改。": remove from the limit state in `App/ClubOperationsViews.swift`. |

### Batch 2 · App: undo the regressions from the polish and integration passes

| # | Issue | How to fix | How to implement |
|---|---|---|---|
| 2.1 | N-05 merchant button shape | Restore radius 12, 46 high for the merchant domain. | `App/DesignSystem/CYPillButton.swift`: add a shape parameter driven by the domain (`palette.buttonShape`: capsule for player, `RoundedRectangle(cornerRadius: 12)` for merchant and editor) rather than a second style. Update `DesignR1MerchantKitTests`. |
| 2.2 | N-08 club wizard | Match `204:24591`. | `App/ClubKit/ClubCreateKit.swift`, `App/ClubOperationsViews.swift`: replace the white header card with a four-segment progress bar, 13 pt eyebrow and 28 pt title on the page; selected card = 1.5 pt white border plus a filled check; add "已选 2 / 3" at the trailing end of the title row in step 2; pin 下一步 with `.safeAreaInset(edge: .bottom)`; leading control is ‹ after step 1 and ✕ on step 1. Motion: step slide 350 ms, segment fill 220 ms, check badge scale .6 → 1 in 220 ms, `.selection`; cross-fade under Reduce Motion. |
| 2.3 | N-15 create at the limit | Do not offer what cannot be done. | `App/ClubHomeView.swift`: when `leaderStatus.canCreate` is false, replace the primary with a secondary `管理我的俱乐部` and keep the warning tag; the limit page (`ClubOperationsViews`) gets one sentence with the real numbers from `LeaderStatus.quota` and one button. |
| 2.4 | N-13 lobby | The button says what it needs. | `App/JourneyLandingViews.swift:587`: label key → `按住开始` (new key; keep `mp.seats.goStart` for VoiceOver's action name `开始`); caption becomes the reassurance line from `204:15032`. A tap shows a 200 ms nudge of the ring and the caption `按住 1 秒开始` so a tap is not silent. 房主 badge: `CYStatusTag(.neutral)` with a crown symbol. 撤回 goes into a ⋯ menu on the row. |
| 2.5 | N-12 root headers | One header: large title, 消息 then one page action. | `App/DesignSystem/CYPlayerKit.swift` (`cyRootHeader`): enforce at most two trailing items with 消息 first. 首页: keep 消息 and the inline search field; move language into 我的 → 设置, ＋ is the 发布 tab, ⋯ items into the role line's menu. 漫游: apply the header (large left title, 消息, 漫游护照). 俱乐部: refresh becomes pull-to-refresh. `HomeFeedView.swift`, `RoamBrowserView.swift`, `ClubHomeView.swift`. |
| 2.6 | N-14 members screen | Remove the roster card from 成员; keep it for 报名名册. | `App/ClubMembersView.swift`: delete the `ClubRosterCard` header; put the role counts in the subtitle (`创建者 1 · 管理员 1 · 成员 2`). Mount `ClubRosterCard` in `ClubRosterBucketContent` where MC-25 wanted it. Add `邀请成员` as the first row (Figma `223:3698`). |
| 2.7 | MC-14 double chevrons, stray hairlines | One accessory per row. | `App/ClubDetailView.swift`: the row is a `NavigationLink` inside a custom row that draws its own chevron; drop one. Remove the top `Divider()` in the card builder. |
| 2.8 | N-07 Today card | Never ship a hero of dashes. | `App/MerchantHomeView.swift`: until the server has day-scoped counts, show `待处理` large and the two 7-day numbers with the label `近 7 天` (Q4). Nav: no centred title; shop name 22 Bold with 营业中. |
| 2.9 | N-09 gameplay editor title | One title. | `App/TemplateAuthoringView.swift`: `.navigationTitle("编辑玩法模板")` inline; delete the 34 pt heading; pin `EditorSectionBar` under the nav with `.safeAreaInset(edge: .top)`; remove the 名称 field (the cover title is tappable, with a pencil, as in `237:43689`); add a 40% bottom scrim on the cover so the white title reaches 4.5:1. |
| 2.10 | CF-49 raw URL fields | Media is picked, not typed. | `App/TemplateAuthoringDetailForms.swift`: replace 题目图片链接 and 题目音频链接 with the same picker flow the cover now uses (`ActivityCoverAuthoringSection` pattern); 清空 moves into the tile's ⋯. |

### Batch 3 · App: build the P0 screens to the revised Figma (mount the kits)

Rule for this batch: an item is done when a Lane2 screenshot of the **shipped** view, on the TEST backend where possible, matches the frame. Fixture hosts do not count.

| # | Issue | Figma | Files |
|---|---|---|---|
| 3.1 | PL-23 topic detail | `169:6954`, `169:7170` | `App/TopicDetailView.swift`: hero image 300 pt with glass back, bookmark, share; title; organiser row; four stats at 20 pt; pinned tabs (`LazyVStack(pinnedViews:)`); `safeAreaInset` bar with price left and primary right. Hide rows with unknown values instead of 未知. |
| 3.2 | PL-20 live roam | `185:5373`–`185:5592` | `App/RoamLiveSessionView.swift`: replace the `List` HUD with a full-bleed `Map`, `Player/Top Pill`, a `.height(120)` / `.medium` sheet with `presentationBackgroundInteraction(.enabled(upThrough: .medium))`. Point the `d6-live` fixture at this view so there is one implementation. |
| 3.3 | PL-03 lobby | `204:15032`, `289:2730`, `289:2804` | `App/JourneyLandingViews.swift`: cover strip, 怎么玩 three rows (needs 站数 and 时长 on the seats read; if the API lacks them, hide the rows, do not print "—"). |
| 3.4 | CF-20, CF-40, CF-25 topic editor and publish | `237:31646`, `249:16472`–`249:18596`, `237:68146` | `App/ProjectEditView.swift`: chapter cards, save chip, segmented 列表 / 地图, bar 保存草稿 + 下一步; publish preview with collapsed checks and one confirmation sheet; one delete rule with `UndoManager`. |
| 3.5 | CF-10, CF-11, CF-44 mount the editor kit | `237:43689` | Swap `TemplateAuthoringField` for `EditorField`; collapse valid sections into `EditorCard`; mount `EditorCardFooter`; use `EditorSheetHeader` on every editor sheet. |
| 3.6 | MR-22 refund, MR-30 station | `183:1731`, `233:9703` | The merchant refund detail and station views (receipt C lists MR-22 to MR-37 as untouched): pinned pair bar; state-driven primary. Money screens stay behind the existing switches. |
| 3.7 | PL-21 roam root, PL-22 home cards | `169:4853`, `210:8239` | `RoamBrowserView.swift`, `HomeFeedView.swift`. After Q7. |
| 3.8 | MC-22 club header, MC-33 consequence sheet | `204:24899`, `222:5684` | `ClubDetailView.swift`, `ClubActionPanel.swift`; swap the five delete dialogs to `ClubConsequenceSheet`. |
| 3.9 | D-06 sheet header | `169:5885` | `App/RegistrationSheetView.swift` and other player sheets: `CYSheetHeader` (grabber, title, round ✕), not a 关闭 pill. |

### Batch 4 · Figma: defects the revision introduced

| # | Issue | Nodes | Fix |
|---|---|---|---|
| 4.1 | F-01 wrong create flow on P | `209:16053`, `209:16076`, `209:16104`, `209:16127`, the create5 sheet | Replace with copies of `204:24591`, `204:24631`, `204:24676`, `204:24716`; relink flow 5; the result sheet reads `俱乐部已创建` with `去看看`. Keep the apply form only under 申请主理人. |
| 4.2 | F-02 meta line | `Player/Theme Card` `287:43163`, instance in `210:8239`, twins `166:2557`, `166:2866` | Set the meta row to horizontal auto-layout, hug, gap 4; remove the duplicate text layers. |
| 4.3 | F-03 member sheet | `223:3698`, `Club/Row Menu` `291:61128` | Delete the stray back circle; the header is either ✕ (root) or ‹ (pushed), not both; replace the black bar with a 0.5 pt separator; give the three rows different avatars. |
| 4.4 | F-04 missing ⋯ | `233:9703`, `182:8448`, `233:11700`, the MR-26 and MR-27 frames | Add `Merchant/Nav Bar` Trailing = More and draw one frame with the menu open for each. |
| 4.5 | F-05, MR-17 status mapping | `183:1731`, then every `Merchant/Status Tag` on R4 | Re-map by who must act: merchant → NeedsMe (amber), platform or customer → Waiting (grey, clock). Date `11月14日 19:28`. Copy icon in ink. 12 pt gap between the two cards. |
| 4.6 | F-07, CF-39 date picker | `246:6728`, `246:6908`, `239:625`, `239:771`, `204:21385` | Import the Apple iOS UI kit's Date Picker (compact and graphical) and Keyboard, and place instances. If the library cannot be added on this plan, move the placeholder label outside the phone frame and leave the area as a plain neutral block. Use one stand-in for both pages. |
| 4.7 | F-08 switch tint | `Editor/Switch` `276:302` | Apply Q3's answer in one place. |
| 4.8 | F-11 duplicates | `290:20551`, `290:22148` | Merge into one `Editor/Result` (State = Success / Pending / Failed / Rejected; text and two buttons as properties); re-point instances. |
| 4.9 | F-09, F-06, F-13 | `249:16773`; `182:8065`; `204:15032`, `169:6954`, `238:20393` | Links to ink; add the 营销 title and remove the grey bar; move the back circle inside the frame; add a top scrim under the status bar; confirm the 删除节点 row. |
| 4.10 | F-10, F-12 | dimmed frames; under-sheet bases | Move retired frames to an Archive page. Re-clone bases from the current pages (run `revise/cfg-D-cf44.js` on the C2 bases). |

### Batch 5 · Figma: finish the partial P0s and the three untouched P1s

| # | Issue | Nodes | Fix |
|---|---|---|---|
| 5.1 | CF-52 | `238:19113`, `238:19278` | Swap to `Editor/Result` with `查看活动` / `完成`. |
| 5.2 | MR-03 | `221:3542`, `225:10210`, `227:18300`, `230:9905` | Split into one frame per state, or move the boards to a spec section as member-club did (`306:33728`). |
| 5.3 | MC-04 | `204:34773` | The yellow line and cropped cover are inside a raster: replace the map image. |
| 5.4 | MC-20 leftovers | `236:8395`, `219:3463` | 28 pt ✕ on a 44 target; draw the open comment menu. |
| 5.5 | PL-10 old-kit twins | `169:3833`, `169:4120`, `169:6068`, `169:6155`, `169:9621`, `169:9760`, `169:9899`, `169:9973` | Instance swap to `Player/*`. |
| 5.6 | PL-33, MR-24, MR-27 | `228:4790`–`228:6090`; `182:8263`; the 声音 frames | These three were notes only. Redraw. |
| 5.7 | CF-15 | C1–C3 | Re-run the size census script from the config review and attach the table; fix any control under 44 pt. |
| 5.8 | PL-40, MC-50 | player and club frames | Use native annotations (category Interaction) as the config pass did, so motion is in one place and one format. |

### Batch 6 · Evidence for the next verification

| # | What | How |
|---|---|---|
| 6.1 | Screenshots of shipped views | Re-shoot every P0 screen from the real view on TEST; label fixture shots as fixtures in the file name. Add the screens with no shot today: play HUD, hint, settle, wallet, payment result, refund, station, merchant tab bar, a sheet at each detent. |
| 6.2 | Light and dark entry paths | For each light page, one shot entered from the player shell and one from the merchant root. |
| 6.3 | Contrast and size | A small script over the screenshots (as used here) for the pairs listed in N-01; XXL Dynamic Type shots of home, topic detail, lobby and the gameplay editor. |
| 6.4 | Receipts | A status of "done" needs a screenshot path next to it. "Built, not mounted" is its own status. |

---

## 5 · Open questions for the owner

| # | Question | Default if no answer |
|---|---|---|
| Q1 | The polish pass added `api/club/members` to the approved player read list. Confirm? | Keep it (non-money read; backend enforces the permission). |
| Q2 | Merchant onboarding: Figma has a fifth step for 真实姓名 and 身份证号; the app and the contract do not have the fields. Add them to the backend, or drop the step from Figma? | Drop the step from Figma until the contract has the fields. |
| Q3 | Switch tint in the editor: green (Figma) or neutral black (app)? | Neutral, to match the player and club ruling. |
| Q4 | The merchant Today card has no day-scoped numbers from the server. Show 7-day numbers until it does? | Yes. |
| Q5 | Light editor pages opened from the dark player app: keep them as pushes (needs the root scheme change in 1.1), or present them as full-screen covers? | Keep pushes; fall back to covers only if 1.1 fails. |
| Q6 | External-game price shows "1,260 积分" as a placeholder. What is the conversion from ¥12.60? | Hide the price until the rule exists. |
| Q7 | The roam root in Figma is map-first and retires the 走起 / 漫游护照 page the app ships. Build it? | Yes. |
| Q8 | 账户余额 is real money. Show it as ¥560.00? | Yes. |
| Q9 | 首页 header: which two actions stay? | 消息 and search; the rest move as in 2.5. |
| Q10 | Sheet headers differ by theme (editor: ✕ left, 完成 right; player: title left, ✕ right; merchant: centred title, ✕ right). Keep three, or one for the whole app? | Keep three, written into the handbook. |
