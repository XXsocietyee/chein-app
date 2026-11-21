# FULL REVIEW · Merchant and creator (R4, R5)

Reviewer: Fable 5.2 · 2026-11-15 · read-only (no Figma or code was edited).
File `0YyoybGnU1KG0657wdGCPX`. Pages: R4 `90:26` (小程序还原 · 商家), R5 `90:2` (小程序还原 · 创作与合作).

## 0 · What was reviewed, and how

Two reviewers contributed. An earlier Fable reviewer covered R4 and part of R5 and left working notes (`review/full-mc-work/notes.md`); I then read R5 myself and re-checked part of R4. The findings below say which they rest on.

| Page | Sections | Frames | How it was read |
|---|---|---|---|
| R4 | 31 | 343 | **Earlier reviewer:** all 30 screen sections viewed (twins and new C frames at 1×; generic states at 0.56× for 10 sections, the rest audited by component only), plus a programmatic audit of all 339 screen frames (type sizes, button sizes, control heights, contrast values, component use, prototype reactions). **This pass:** I rendered and read 11 of the 30 sections myself at 0.45× (工作台 `91:625`, 入驻 `92:854`, 账本 `94:687`, 售后详情 `94:3300`, 营销 `95:1750`, 口碑 `95:1876`, 品牌中心 `103:1958`, 合作中心 `112:968`, 本站准备与运行 `115:748`, 成员管理 `117:777`, 商家 Tab 根页 `233:12462`) and confirmed the notes on them. The other 19 sections rest on the earlier reviewer's notes; I did not re-open them. |
| R5 | 29 | 127 | **This pass:** all 28 screen sections rendered at 1×; every twin, every new D state frame (`220:*`, `223:*`, `224:*`, `225:*`) and every page without a twin read at 0.45×. The earlier reviewer's programmatic audit (layout mode, type sizes, contrast) is used for the numbers. |

Not reviewed here: the merchant frames that live on other pages (R1 `113:1347`, `116:1169`, `116:1171`, `116:1173`; R2 `105:1588`, `105:1620`, `124:1856`; R3 `233:3449`; R6 `230:*`, `231:*`). They were read for the player and member-club reviews, which note their main issues; an executor should apply this file's kit decisions to them. The topic-publishing twins on R5 (rows 48–57) are superseded by pages C1–C3 and are reviewed in `full-config.md`.

Contrast ratios quoted below are the earlier reviewer's computed values from fills; I did not re-measure them. No prototype reactions exist on either page (0 of 465 frames), so flow findings are from the frames. The owner's Kavsoft video was not playable; sheet behaviour follows the owner's description.

**Result: 42 issues. P0 11 · P1 27 · P2 4.** (Issue IDs are grouped by batch, so the numbering has gaps.)

The five findings that matter most:
1. **Merchant onboarding cannot be finished.** The step 4 twin has no submit button, and it asks for new required fields (真实姓名, 身份证号) on a page titled "确认这份入驻信息" (MR-01).
2. **Twins and new state frames are two designs of the same pages.** Button shape (pill versus 12-radius), type scale (44 versus 42 hero; 16 Regular versus 18 Bold headers), chips (black versus dark grey; 40 versus 34 high), headers (four nav styles, three sheet headers), tab bars (wrong tab selected) all differ inside single flows (MR-10 to MR-16).
3. **Engineering language and spec notes are in the UI.** "读取原回复请求 / 复制原请求号", "查询原请求 / 确认后另起独立请求", and seven "…时显示：…" notes drawn as copy (MR-02, MR-03).
4. **Status colours contradict each other.** 审核中 is amber in one frame and blue in the next; "准备完成" is blue here and green there; the timeline's "done" dot is green in one flow and black in another (MR-17).
5. **A running station hides its urgent task.** With 2 players waiting to be verified, the primary is 出示打卡码 and "2 待核验" is a plain number (MR-30).

Strong work to keep: the refund flow's two-step sheet (`223:8522` – `223:8943`), the discard alert used consistently across 117–121, the "这一站怎么接待" guidance block (`233:9703`), the result sheets on the workbench (`218:2439` – `218:2707`), and the coop invite send / fail results (`224:6245`, `224:6292`).

---

## 1 · References (20, none repeated from the other reviews)

### A · Merchant and creator apps (Mobbin)

| # | Reference | What it shows | Lesson for R4 / R5 |
|---|---|---|---|
| 1 | Shopify · [setup guide on home](https://mobbin.com/screens/fc78e9ee-0629-4e84-a80d-89090a648363) | A collapsible "Get ready to sell" card: six tasks, each a row with an empty ring, a title and a chevron; the card can be collapsed or dismissed. | 入驻审核中 and the first days after approval: a setup checklist on the workbench (上传门头, 设营业时间, 加员工, 设权益) with rings that fill. Today the page is one status card. |
| 2 | Shopify · [customer detail](https://mobbin.com/screens/eef0daad-490b-4e23-862c-2f97c11f1b6a) | Name, "since" line, two yellow tags; an Insights group of three label–value rows; contact as two equal buttons (Email, Phone); a Note group with a blue "Edit". | 客户详情 (125): three numbers as rows, contact as two buttons, the note inline with one edit action. No tiles for three small numbers. |
| 3 | Shopify · [orders empty state](https://mobbin.com/screens/eb6621e4-0513-440e-98ec-4a59bc34aa83) | An illustration, one headline, one sentence, one filled button. The page title is a pull-down ("Orders ⌄"). | Empty states: art, one line, one action that starts the first item. The ledger's three views could be one page with a title pull-down instead of three titles. |
| 4 | Stripe Dashboard · [home](https://mobbin.com/screens/fba86a00-cfc6-43b3-af79-052679faa58e) | "Today": three numbers in one card (Gross volume, Payments, Customers). Then range chips (1W … ALL) and charts that always show the comparison period and the change in percent. | The workbench hero: today's three numbers, not one cumulative total. AI 参谋 charts need a scale, a comparison and a value: today they are lavender bars with none. |
| 5 | YouTube Studio · [dashboard](https://mobbin.com/screens/fa7accb9-f22b-4c47-996e-d8be80d93023), [analytics](https://mobbin.com/screens/fbf3b744-cc68-41f0-ba07-55bafa180cec), [breakdowns](https://mobbin.com/screens/fb1145af-8ba9-4e54-ab71-f7228ba47734) | Dashboard: two metric tiles, the latest item with its three numbers, latest comments. Analytics: underline tabs, filter chips, one chart with axis labels and a page control, ranked lists with thumbnails, labelled bars with percentages, and "Nothing to show for these dates" inside the module. | A creator or merchant dashboard is modules, each with its own empty line. 营销 and 口碑 should rank and label; an empty module says so in place, not with a page-level banner. |
| 6 | Wealthfront · [review step](https://mobbin.com/screens/74e29b4b-353d-48eb-90c8-aa50c4db281b) | A question as the title ("Is your tax information up-to-date?"), three label–value rows, then **Looks good** (filled) and **Update my tax info** (tinted). | The review step of onboarding: read-only rows, one confirm, one "change". No new fields on a review page. |
| 7 | Venmo · [confirm and submit](https://mobbin.com/screens/dd5f3f2e-54a2-42a7-a986-24ee5a55e234) | The legal text, then one sentence that says what tapping means, then **Confirm and submit**. | Consent is a sentence above the button plus the button's own label. Not an 11 pt line beside a circle that reads as a radio. |
| 8 | Lightyear · [confirm details sheet](https://mobbin.com/screens/24b60a4b-3e76-420f-abf0-f18d403af92e) | A sheet over the form: the looked-up business details as rows, a line that says where to fix them, Cancel and Confirm. | 认领已有门店: after picking the shop, a confirm-details sheet, not a second long form. |
| 9 | Trainline · [refund overview](https://mobbin.com/screens/1650f9a6-33ae-482f-8f8e-378c7dea3ac8) | The item, an "Eligible for refund" tag, a summary table that ends in a bold total, one filled button, two footnotes on what happens next. | 售后详情: the request, the amount table with the total in bold, **one** primary. Today three equal chips ask for the decision, then a sheet asks again. |
| 10 | talabat · [cancelled order with refund](https://mobbin.com/screens/a02eeba5-8d85-4d80-866f-0050e2fb63c3), Swiggy · [refund status](https://mobbin.com/screens/99a107b3-e8bf-4a9d-897a-9e5a40a57cd7) | Refund amount, status as a filled tag ("Refunded"), "Refund to" as a link; completed refunds as cards with a green check and the date. | Refund states are one tag vocabulary with one colour each. |
| 11 | Savee · [collaborators](https://mobbin.com/screens/763c9eb1-34ab-4926-bef7-210ab30445d4) | Members list; tapping a role opens a menu (Admin, ✓ Editor, Viewer, then Remove with an icon); pending invites in their own section. | 门店成员: the role is a pull-down on the row; 移除 is the last item of the same menu. No separate 调整岗位 sheet with a pink 移除 button. |
| 12 | Slack · [invite sheet](https://mobbin.com/screens/e7166ddd-377a-4395-8646-40fa80ce5f96), talabat · [member invite](https://mobbin.com/screens/ce0a336f-8314-4173-859d-83e2d4840911) | One filled "Share a Link" with "Expires in 17 days · Deactivate link" under it; other ways as outlined buttons. Or: three numbered steps and a QR to scan. | 邀请员工: one share action with the expiry and a revoke link beside it; the QR as the in-person option. |

### B · Official design documentation

| # | Reference | Key guidance (quoted where the page rendered) | Lesson |
|---|---|---|---|
| 13 | [Stripe Apps · Design patterns](https://docs.stripe.com/stripe-apps/patterns) | Patterns exist for lists, filter controls, onboarding, action buttons, communicating state, empty state, loading, progress stepping and waiting screens. "Follow these patterns as you design your app so that it functions in a consistent, clear, and scalable manner." | The merchant app needs the same short list of patterns, each drawn once. Today each page re-invents them. |
| 14 | [Stripe Apps · Action buttons](https://docs.stripe.com/stripe-apps/patterns/action-buttons.md) | "Keep action buttons in a consistent place." "Place action buttons in the header to make sure they're visible to users, even when content flows off-screen." "When content areas don't require a scroll bar, place buttons below the content." Up to three buttons, "with the primary action first". | One position for the primary per page type: pinned bottom bar on forms and detail pages. Today the same flow pins it in twins and floats it inline in new states. |
| 15 | [Stripe Apps · Communicating state](https://docs.stripe.com/stripe-apps/patterns/communicating-state.md) | Toast: "temporary", triggered by the user's action, "fewer than four words on one line", "maximum character length for a toast is 30". Banner: "persistent", for "unexpected system-level requirements, changes, or issues", with a required action, placed "under [the] header". | Banner = something the merchant must act on. A permission state or a partial-data notice is not a red banner. A banner that says "do not retry" cannot sit above an enabled retry button. |
| 16 | [Shopify · App Home patterns](https://shopify.dev/docs/api/app-home/patterns) (the older `polaris-react.shopify.com` pages now redirect to shopify.dev; only one-line descriptions rendered) | Templates: Index ("manage collections of resources, and perform actions on them"), Details, Settings, Homepage ("quick access to key information and actions"). Compositions: Setup guide ("interactive checklists and progress tracking"), Metrics card ("key metrics, statistics, or trends at a glance"). | Four page types cover all 30 merchant sections: home, index, details, settings. Each gets one nav style and one layout. |
| 17 | [HIG · Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators) | "When possible, use a determinate progress indicator." "Keep progress indicators moving so people know something is continuing to happen." "Avoid vague terms like loading or authenticating." "Display a progress indicator in a consistent location." | Voice generation (118) and upload states show progress, not a manual "刷新状态" button. A dynamic QR shows its countdown. |
| 18 | [HIG · Color](https://developer.apple.com/design/human-interface-guidelines/color) | "Avoid using the same color to mean different things." "Avoid relying solely on color to differentiate between objects, indicate interactivity, or communicate essential information." | One colour per status across the app (MR-17). Blue is not both "link" and "pending". |
| 19 | [HIG · SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) | "Use symbol animations to communicate information more efficiently." "Apply symbol animations judiciously." | Result icons (核销成功, 已发送) animate once: a check draws, a clock ticks. The icon-only tab bar needs symbols that read without labels, or labels. |
| 20 | [HIG · Settings](https://developer.apple.com/design/human-interface-guidelines/settings) and Kavsoft · [Resizing Scrollable Sheets](https://youtu.be/WRgYhvxNOqE) (owner reference; not playable here) | "When possible, prefer letting people modify task-specific options without going to your settings area." Sheets: detents follow content; scroll only at full height; a spring between detents. | 门店信息 and AI 角色 should not need a read mode then an edit mode. Section 3 lists every sheet with detents. |

Square and Toast searches on Mobbin returned no screens in this session, so they are not cited.

---

## 2 · Shared decisions for the merchant (light) theme

These settle "twin or new frame" once. Where the two disagree, the value below wins and both are redrawn to it.

| Topic | Decision | Source of the choice |
|---|---|---|
| Type scale | 11 · 12 · 14 · 16 · 18 · 22 · 29 · 32 · 42 (handbook integers). Data hero 42 Bold. Section header 18 Bold. Off-scale sizes (13, 15, 19, 21, 23, 25, 27, 31, 44) are removed. | Owner answer 4; new C frames |
| Primary button | Black, radius 12, 46 high, full width, **pinned in a bottom bar** on forms and details; inline only on result sheets and empty states. One per screen. | Handbook d.4 (buttons 12); Stripe ref 14 |
| Secondary button | `#EEEEEE` fill, same shape and height. Small (34) buttons are removed; rows carry the tap. | Earlier audit: Small = 34 in about 25 frames |
| Chips | 36 visual on a 44 target; unselected = `#EEEEEE` capsule with ink text; selected = black capsule with white text. Never bare text. | Twin 107 (black), with a container on unselected |
| Nav | Home pages (tab roots): large left title, no back. Index, details, settings: back chevron + large left title (handbook N2/N3 allows either; pick the large left title because most twins use it). Generic states keep the page's title. | Twins 105, 119 |
| Sheet header | Grabber, centred title 18 Bold, round ✕ at the right. Text-button headers (取消 / 标题 / 发布) are removed. | Majority of new frames |
| Tab bar | The shared merchant tab bar with a real selected state per tab; labels shown (工作台 · 营销 · 模板 · 合作 · 我的). | Earlier audit: no selected variants; HIG Tab bars |
| Links | Ink text with a chevron, or a secondary button. Blue `#2563EB` is not used for actions. | Handbook d.3 |
| Status colours | Pending / needs me: amber. In review by someone else: grey with a clock. Live / done: green. Failed / rejected: red. Info: grey. One tag component with an icon. | MR-17 |
| Timeline | Done = black filled dot; current = black ring; pending = grey ring; newest first. | Twins 105 / 106 |
| Money | ¥ with two decimals in bills and settlements; hero amounts 42 Bold. `0.00` is never prefilled in an empty field. | Handbook d.7 |
| Unknown outcome | Both actions secondary: `查看结果` first, `重试` second. Never a primary "再试一次". | Kit rule K8; `233:9891` does it right |

---

## 3 · Sheets: resizable scrollable sheets (owner reference)

Behaviour and values as in `full-config.md` section 3: opens at the smallest detent that fits, grows by drag, scrolls only at the largest detent, `spring(response: 0.38, dampingFraction: 0.86)`, `.selection` on settle, cross-fade under Reduce Motion. `fit` = `.height(content)` capped at 62%. Sheets on a page with its own primary hide that primary while open (the earlier audit found two primaries visible in `221:2905`, `221:2996`, `221:3051`, `227:17985`, `233:10091`).

| Sheet | Frames | Detents | Notes |
|---|---|---|---|
| 工作台 · 更多 | `218:1993` | `fit` | Tiles fill the width (3 × 2). |
| 选择章节 / 选择节点 (核销) | `218:2159`, `218:2299` | `fit`, `.large` | |
| 核销结果 (成功 / 失败 / 待复核) | `218:2439`, `218:2577`, `218:2707` | `fit` | |
| 认领已有门店 (搜索 / 表单) | `221:2830`, `221:2905` | `.medium`, `.large` | Keyboard raises to `.large`. |
| 认领结果 (已提交 / 被驳回) | `221:2996`, `221:3051` | `fit` | |
| 行业类型 | `221:3108` | `fit` | |
| 设置经营时间 | `221:3188`, `227:18092` | `fit` | Native time pickers. |
| 售后 · 同意 / 不同意 / 补充凭证 / 确认 | `223:8522`, `223:8672`, `223:8822`, `223:8943` | `.medium`, `.large` | Two steps push inside one sheet. |
| 纠错 (哪里不对 / 填写 / 结果) | `223:9773`, `223:9945`, `223:10111`, `223:10265`, `223:10422` | `fit`, `.large` | |
| 口碑 · 写评价 | `225:7412` | `.medium`, `.large` | |
| 到店打卡码 / 本站打卡码 | `225:9842`, `233:10254` | `fit` | Brightness up; countdown ring. |
| 认领平台节点 | `225:9754` | `.medium`, `.large` | |
| 确认店址 (map) | `225:10521` | `.large` only | A map task. |
| 品牌 · 字段 (单行 / 多行) | `227:17808`, `227:17892` | `.height(200)` / `.medium`, `.large` | Sits above the keyboard. |
| 特色标签 (+ 自定义) | `227:17985` | `fit`, `.large` | 自定义标签 becomes an inline field in the same sheet, not a second sheet. |
| AI 角色 · 引导 1–4 | `170:3821`, `227:18742`, `227:18806`, `227:18870` | `.large` only | One style for all four (edge-to-edge). |
| AI 角色 · 选现成的 / 字段 / 性格 / 声音 | `227:18934`, `227:19015`, `227:19075`, `227:19138`, `227:19212` – `227:19560` | `fit`, `.large` | Recording locks dismissal. |
| 到店权益 · 添加 | `230:8847`, `230:8916` | `.medium`, `.large` | |
| 筛选客户 | `230:9592` | `fit`, `.large` | |
| 客户 · 管理 / 批量 | `230:9724`, `230:9833` | `fit` | |
| 编辑标签与备注 | `230:10275` | `.medium`, `.large` | |
| 拒绝节点邀请 / 暂停接待 | `233:9948`, `233:9998` | `fit` | |
| 核验游戏提交 | `233:10091` | `.medium`, `.large` | |
| 服务时段 | `233:10169` | `fit` | Native pickers replace the drawn wheel. |
| 选择邀请岗位 | `233:11628` | `fit` | |
| 调整岗位 | `233:11700` | menu | A pull-down on the member row (ref 11). |
| 协作 · 申报本次供给 | `224:2553` | `fit`, `.large` | |
| 协作 · 评价 | `224:2647` | `fit` | |
| 协作 · 编辑邀约语 | `224:6175` | `.medium`, `.large` | |
| 协作 · 已发送 / 发送失败 | `224:6245`, `224:6292` | `fit` | |
| 选择补位操作 | `225:2761` | `fit` | |
| 主题类别 (R5 twin) | `188:5698` | superseded | Use C1's category sheet. |
| 隐私保护 | `188:5912` | `fit`, `.large` | Switch rows (MR-41). |

---

## 4 · The plan

Format: **ID · severity · title**, then frames, problem, optimize, implement (Figma; SwiftUI; motion where it applies). "(notes)" marks a finding taken from the earlier reviewer's notes that I did not re-open; "(confirmed)" marks one I re-checked.

### Batch A · Defects (no design decisions)

**MR-01 · P0 · Merchant onboarding step 4 has no submit button, and it is not a review step (confirmed)**
- Frames: twins `182:7628`, `182:7693`; the flow `182:7504`, `182:7546`, `182:7590`; result states `221:2267`, `221:2339`, `221:2407`, `221:2477`.
- Problem: the last step is titled "确认这份入驻信息" and shows a read-only summary, then introduces two new required fields (真实姓名, 身份证号) and an 11 pt consent line beside a circle. No button exists in either frame, so the flow cannot be completed in the design. The summary shows "行业类型 —" although step 1 requires it. 已通过's only button is 返回; 审核中 has a black 返回 for a passive state.
- Optimize: five steps become four real ones plus a review. Step 4 collects the operator's identity (真实姓名, 身份证号, with why: `用于发布人身份核验，不对外展示`). The review page shows all answers as rows with `修改` per group, one consent sentence above the button, and the pinned primary `提交入驻申请`. 已通过: primary `进入工作台`. 审核中: no primary; a secondary `返回` and the setup checklist (ref 1). 未通过: `重新申请` opens the step that failed.
- Implement: Figma: add the review frame and the bottom bar; move the two fields to their own step; fix the summary data. SwiftUI: `NavigationStack` path with five destinations; `Form` + `LabeledContent`. Motion: step push 350 ms; progress segment fills 220 ms; on submit the button shows progress, then the result sheet rises and the check draws (220 ms); haptic `.success`.

**MR-02 · P0 · Spec notes drawn as UI copy (notes; `225:7661` confirmed)**
- Frames: `225:7661` ("提交后显示：举报已提交审核"), `225:10521` ("没有店址时显示：请在地图上选择店门口 + 在地图上标店址"), `225:10578` ("失败时显示：投放申请未提交"), `227:18696` ("处理中显示：正在处理形象，请稍候"), `227:19212` ("麦克风被拒绝时显示：去设置开启麦克风"), `233:11311` ("没有逐人结果时显示：这次触达没有逐人结果"), `233:11529` ("接受后显示：已加入经营团队，去工作台开始核销").
- Optimize: delete the notes from the frames and draw each described state as its own frame.
- Implement: Figma: seven text deletions, seven new state frames from the same base.

**MR-03 · P0 · Spec boards drawn as phone screens (notes; `221:3542` confirmed)**
- Frames: `221:3542` (three filter states stacked), `225:10210` ("节点配额的四种状态"), `227:18300` (six payment states), `230:9905` ("导出横幅的五种状态").
- Optimize: one state per frame, or move the board out of a phone frame and label it.
- Implement: Figma: split.

**MR-04 · P0 · Engineering wording in recovery states (confirmed for 口碑 and 协作)**
- Frames: `225:7735` ("读取原回复请求 / 复制原请求号"), `227:19560` ("查询原请求 / 确认后另起独立请求"), `224:6382` ("查询原请求", "查找原邀请请求（含其他设备）"), `233:9891` (wording fine; the reference).
- Problem: a shop owner is asked to reason about requests and request numbers.
- Optimize: one pattern (section 2 "Unknown outcome"): a calm amber card: `回复可能已经发出` · `先看一下结果，再决定要不要重发` · buttons `查看结果` and `重新发送`. The request number sits behind "复制诊断信息" in a "⋯".
- Implement: Figma: `Merchant/Outcome Unknown` component; text swaps. SwiftUI: one `OutcomeUnknownView`.

**MR-05 · P0 · Seed and QA strings (notes; R5 confirmed)**
- Frames: R4: `180:7203` ("E2E 玩家小城 19:33"), `183:2281` ("E2E 玩家小城" × 2, "smoke note"), `183:2355` ("备注：smoke note"). R5: `171:6496` ("烟测草稿主题"). The apply flow uses three different shops and addresses ("南京东路188号" in `182:7862`, "南京东路 299 号" in the status frames, "外滩九号书店驿站" in twins 100–103).
- Optimize: one seeded shop everywhere (南京东路猫咖驿站, 南京东路 299 号), seeded customers (玩家小城, 阿兰).
- Implement: text swaps.

**MR-06 · P1 · Layout bugs (notes unless marked)**
- Frames: `233:12356` (我的资产 row: "¥1280.00" overlaps "¥220.20"); `182:7862`, `182:7964` and all 110 states (the cover fade ends at about y 495 and cuts through the first line of body text); `218:1993` (the 3-column grid leaves about 30 pt at the right); `227:18200` (no nav bar instance); `224:6672` (confirmed: "合作对象加载失败" is struck through by another text line); `224:6522`, `224:6596`, `224:6672` (confirmed: a "¥ 0.00" field stays visible under error and loading blocks; two state blocks in one frame); `221:3966` ("正在确认最新记录…" and "最新记录暂未取回" shown together).
- Optimize: fix the layouts; one state per frame; the money field hides until the form is usable.
- Implement: Figma auto-layout fixes.

**MR-07 · P1 · WeChat-only hand-offs with no next step**
- Frames: `233:11034`, `233:11078` ("签约链接需要在微信中打开" + "复制签约链接"); `189:3482` (confirmed: "联系平台客服提现 · 添加客服微信，线下处理"); `186:6257` ("联系平台客服提现").
- Optimize: the app opens the signing page in an in-app browser (`SFSafariViewController`); if it truly must be WeChat, the page says so, offers `复制链接` and `打开微信`, and shows what to expect after. Withdrawal by support is named as such with the reply time (same decision as member-club MC-29).
- Implement: text and one new frame "已复制，去微信打开"; ask the owner (Q-A).

### Batch B · One kit: twins and new frames become one design

**MR-10 · P0 · Type scale and hero size differ between twins and new frames (notes; workbench confirmed)**
- Frames: hero 44 Regular in twins `182:7328`, `182:7428`, `180:7074`, `180:7140`, `182:8065` versus 42 Bold in `218:1805`, `218:2895` and twins 105 / 106; section headers 16 Regular in twins versus 18 Bold in new frames; off-scale sizes in twin 113 (`182:8263`: 13, 21, 25, 27), twin 122 (`183:2102`: 13, 21), twin 125 (`183:2355`: 13, 22, 27), twin 112 (`183:1906`: 23), twin 110 (`182:7862`: 13, 15); R5 publish twins (12, 13, 14, 15, 16, 31); `225:2730` (11.2), twin 150 (23.5); K/State text 15.
- Optimize: section 2 scale.
- Implement: Figma: bind every text to the nine text styles; run a selection by non-style text and fix. SwiftUI: `Font` tokens only.

**MR-11 · P0 · Two button systems in one flow (confirmed in 入驻)**
- Frames: apply twins 100–102 (`182:7504`, `182:7546`, `182:7590`: pill, pinned near the bottom; disabled grey on steps 1 and 3) versus new apply frames (`221:2615`, `221:2681`, `221:2747`: 12-radius, inline under the last card); twin 116 (`182:8521`) versus `225:10463`; twin 121 (`183:2067`: pill in a bottom bar) versus `230:8847`; twin 115 (`182:8448`: a full-width black bar with a left label and an arrow, "投放节点 →"); twin 118 (`170:3821`: pill, inset card).
- Optimize: section 2 "Primary button": radius 12, 46 high, pinned bottom bar. The bar-with-arrow style is removed. A disabled primary is replaced by an enabled one that jumps to the first missing field (same rule as config CF-17).
- Implement: Figma: one `Merchant/Button` (Kind = Primary / Secondary / Destructive / Text; State = Default / Pressed / Loading / Disabled), one `Merchant/Bottom Bar`; swap in both generations. SwiftUI: `.safeAreaInset(edge: .bottom)`.

**MR-12 · P1 · Four nav styles and titles that change with state (notes; partly confirmed)**
- Frames: large left title (twins 105 `180:7276`, 119 `183:1981`, 115 `182:8448`); centred title (twin 106 `182:7757`, twin 116 `182:8521`, twin 121 `183:2067`, 117 `103:1865`, 124 states); title left beside the back chevron (twin 122 `183:2102`, `183:2192`); root with an empty 70 pt band (workbench twins). 115 is "成为节点" in the twin and "城市节点" in `225:9682`. 工作台 is "经营台" in `218:1623` and `218:2837`. The ledger is 核销与退款 / 结算 / 项目动态 / 核销记录 / 账本 across `180:7203`, `221:3406`, `221:3493`, `221:3623`, `221:3896`, `221:3930`. 105's generic states use a centred title while the loaded page uses a large left one.
- Optimize: section 2 "Nav". One name per page: 工作台, 账本 (with a view switcher: 核销 · 结算 · 动态), 城市节点.
- Implement: Figma: `Merchant/Nav Bar` (Type = Root / Back; Title); rename; redraw the generic states inside the real page. SwiftUI: `.navigationTitle` + `.navigationBarTitleDisplayMode(.large)`; the ledger's switcher is a `Picker(.segmented)` under the title.

**MR-13 · P0 · The tab bar shows the wrong tab, has no labels, and is opaque (notes; confirmed on 营销 and 工作台)**
- Frames: every tab-root frame of 营销 (`182:8065`, `182:8176`, `223:10741` – `223:11119`), 114 relation frames (`225:8609`, `225:9360` – `225:9611`) show the first tab (工作台) selected; the component `91:9` (R4/Merchant Tab Bar) has no selected variants. N08 frames (`233:12260`, `233:12356`) show the right tab. 111's twin uses a Back nav with a tab bar while its states use Root.
- Problem: five icon-only tabs (grid, megaphone, document, chat bubble, person) are not self-explaining for 营销 / 模板 / 合作, and the selection is wrong.
- Optimize: section 2 "Tab bar": labels on, selection by a filled symbol and ink weight, floating glass bar. The handbook said icon-only; HIG says "Include tab labels" (round-1 ref 3); the player bar already uses labels. Keep labels and flag the handbook conflict once (Q-B).
- Implement: Figma: add `Selected = 工作台 | 营销 | 模板 | 合作 | 我的` to `91:9`; replace all placements. SwiftUI: `TabView`.

**MR-14 · P1 · Three sheet headers and two sheet bodies (notes; partly confirmed)**
- Frames: centred title + round ✕ (most); text buttons 取消 / 发帖 / 发布 (`225:8697`); 取消 / title / 重置 in blue (`230:9592`); a step counter at the left of a centred title (`223:8522`); an inset floating card with a pill CTA and 跳过 (`170:3821`) versus edge-to-edge sheets for steps 2–4 (`227:18742` – `227:18870`); sheet on sheet (`227:17985`).
- Optimize: section 2 "Sheet header". Step counters go into a small progress bar under the header. 重置 becomes a text button at the left of the bottom bar.
- Implement: Figma: `Merchant/Sheet` (Header, Progress, Body, Bottom Bar); swap. SwiftUI: section 3.

**MR-15 · P1 · Chips, small buttons and selection differ (notes; partly confirmed)**
- Frames: selected chip black 40 high in twin 107 (`182:7816`) versus dark grey 34 high in `223:8043`; unselected chips as bare text in `221:3108` and `230:9592`; day circles black versus grey in `221:3188`, `227:18092`; 104's 4-segment bar with a tinted track in the twin and a white track in new frames (`221:3542`); Button Small (34 high) in about 25 frames (e.g. `221:2830` 搜索 58 × 34, `221:2545` 前往移交, `225:8609` 邀请合作); black mini pills about 22 high in R5 (`186:5944`, `223:4343`); × badges of 12–20 px (`218:1688`, `221:2747`, `230:8602`).
- Optimize: section 2 "Chips", "Secondary button". Removing an uploaded photo is by a 28 pt ✕ with a 44 pt target or by long-press → 删除; the helper "点 × 可移除" goes.
- Implement: one `Merchant/Chip`, one `Merchant/Segmented`; hit layers.

**MR-16 · P1 · Generic states come from two kits (notes; confirmed on 账本 and 协作)**
- Frames: R4 states use K/State from the R3 kit with hand-drawn loading and no home indicator; R5 states use a different K/State (component id 219:5570 per the earlier audit; it is not on these two pages) with skeleton components; state text is 15 pt (off scale); the action is a small black pill (about 36 high); the empty glyph is an inbox icon while restored empties 108, 133 and 136 use the lime mascot; top-pinned blocks start about 200 pt down.
- Optimize: one `Merchant/State` (Kind = Loading-skeleton / Empty / Error / NoPermission / SignedOut / Gone), centred at 40%, action 46 high, type on scale. Mascot only for first-use empties of the merchant's own lists (same rule as member-club MC-42).
- Implement: Figma: build once in the light theme (variable-bound so it serves the dark kit too); swap about 120 instances. SwiftUI: `ContentUnavailableView` styled.

**MR-17 · P0 · Status colours and timeline dots contradict each other (notes; partly confirmed)**
- Frames: 审核中 amber (`221:2339`), 待复核 amber (`218:2707`), but 认领申请已提交 uses a blue clock (`221:2996`); 平台审核中 is amber in twin 109 (`183:1731`) and blue in `223:9095` and `223:8043`; 准备完成 is blue in `170:3884` and green in `233:9834`; 待接受 blue in `233:9577`. Timelines: done = green, current = black in the apply flow (`221:2339`); done = black, current = green ring in ledger details (`180:7276`, `182:7757`); a third style with a blue bar in twin 109. Red filled buttons are used for both irreversible (确认拒绝 `233:9948`) and reversible (确认暂停 `233:9998`) actions. A permission state uses a red error banner (`223:10798`); a partial-data notice is red (`225:8609`, confirmed).
- Optimize: section 2 "Status colours" and "Timeline". Red fill only for actions that cannot be undone. Permission and partial-data notices are neutral banners with an icon.
- Implement: Figma: `Merchant/Status Tag` (State = NeedsMe / Waiting / Live / Done / Failed / Info), `Merchant/Timeline`, `Merchant/Banner` (Tone = Neutral / Warning / Error). Swap all. SwiftUI: one `enum Status` with colour and symbol.

**MR-18 · P1 · Blue text links as actions (notes; confirmed on 品牌中心 and 协作)**
- Frames: `227:17435` (编辑), `227:17510` (去发布一个活动, 联系运营开通), `227:17603` (上传二维码), `225:9682` (撤回), `233:11700` (移除 is pink), `221:2905` (换一家), `221:2200` (认领已有门店), `186:6119` (a blue block "邀请你承接 … 主题详情 →"), `223:9389` (system-blue alert buttons).
- Optimize: section 2 "Links". Alerts take the app tint (ink).
- Implement: text style swap; `.tint(.primary)`.

**MR-19 · P1 · Contrast below 4.5:1 (notes; values not re-measured)**
- Frames: placeholder and disabled `#6F6F6F` on `#EEEEEE` / `#EFEFEF` (4.3–4.4) in all inputs and disabled buttons; on `#E4E4E4` (4.0) in `182:7628`; rating stars `#F59F00` on white (2.1) in the 112 frames; destructive text `#D0323B` on `#EEEEEE` (4.3) in `183:1906`, `233:11700`, `182:7590`; "领取 5 · 核销 5" `#6B6B6B` on black (3.9) in `182:8065`; BIZ tag `#F8F8F8` on `#4C86FF` (3.2) in twin 153 (`189:4165`); "暂时无法注销" `#E5484D` on `#3A3A3C` (2.9) in `189:4271`.
- Optimize: placeholder `#5C5C5C`; disabled labels with a reason line; stars get a 1 pt `#B36B00` outline or sit on a dark chip, and the number carries the meaning; destructive `#B3261E` on light; red on dark `#FF6B6B`.
- Implement: token edits; re-run the check on the listed frames.

### Batch C · Merchant pages (R4)

**MR-20 · P1 · Workbench: an empty band, one cumulative number, unlabelled tabs (confirmed)**
- Frames: `182:7328`, `182:7428`, `180:7074`, `180:7140`, `218:1623` – `218:3099`.
- Problem: about 70 pt between the status bar and the greeting carry nothing. The hero is "累计收入 ¥1280.00". Partial failures use a blue info banner in twin 099 and a red inline error in `218:2997`, `218:3099`. 消息 rows have a 12 px × each and "清空" has no confirmation. Quick actions are circles here and rounded squares on 营销. No scanner surface is drawn (viewfinder, torch, manual code, camera denied).
- Optimize: header = shop name, the 营业中 tag and the avatar on one line at the top. Hero = today: 今日核销 · 今日收入 · 待处理 (ref 4), with 累计 behind 账本. The one alert row ("有 1 笔售后待回应") stays directly under it. Quick actions use one shape (circles) everywhere. Messages are swipe-to-dismiss; 清空 asks once. Partial failure: a neutral inline row in the failed module with `重试`. Add the four scanner frames (reuse the player scanner twins A48–A53 in the light chrome).
- Implement: Figma: `Merchant/Today Card`, `Merchant/Quick Action`; four new scanner frames. SwiftUI: `List` + `.swipeActions`; `DataScannerViewController`. Motion: numbers count up once on first load (400 ms); a new alert row slides in 220 ms; scan success: corners snap, check draws, `.success`.

**MR-21 · P1 · Ledger: three views with no switcher (confirmed)**
- Frames: `180:7203`, `221:3406`, `221:3493`, `221:3542`, `221:3623`, `221:3774` – `221:3859`, `180:7276`, `182:7757`, `223:7797`.
- Problem: three pages share one route with no visible way to move between them; the filter is a 4-segment bar here and chips on 107; the stale strip in `223:7797` sits above the title and pushes it down; the settlement switch is iOS green while other switches differ.
- Optimize: one 账本 page with a 3-segment switcher (核销 · 结算 · 动态). Filters are chips under it. The stale strip is a neutral banner under the title. 105 and 106 share one detail layout (amount, status tag, timeline, breakdown).
- Implement: Figma: one page, three content frames; `Merchant/Detail` template. SwiftUI: `Picker(.segmented)`; `.refreshable`. Motion: segment change cross-fades 180 ms; pull to refresh is the system's.

**MR-22 · P0 · Refund: the decision is asked twice and has no primary (confirmed)**
- Frames: twins `183:1731`, `183:1819`; sheets `223:8522`, `223:8672`, `223:8822`, `223:8943`; `223:9095`.
- Problem: three equal white chips (同意 · 不同意 · 补充凭证) at the top, an unlabelled round icon button beside the amount, then a sheet that asks the same three-way choice again as a segmented control. The hero amount is 32 Bold in the twin and 42 Bold in `223:9095`.
- Optimize: the page shows the request, the evidence and the amount table (ref 9). Bottom bar: primary `同意退款 ¥39.00`, secondary `不同意`; 补充凭证 is a row in the page. Each button opens its own sheet directly at the right step (no second choice). The two-step confirm (1/2 → 2/2) stays: it is good.
- Implement: Figma: redraw the twin; remove the segmented control from the sheet. SwiftUI: two `sheet(item:)`s. Motion: on confirm, the button shows progress, then the status tag changes with a 220 ms cross-fade and the timeline gains a row (300 ms); haptic `.success`.

**MR-23 · P1 · 口碑: the twin and the new frames are different pages (confirmed)**
- Frames: twin `183:1906` (rating line, 2 × 2 KPI tiles with tinted icons, chips with counts, text actions 修改回复 / 删除回复 / 举报) versus `225:7535`, `225:7596`, `225:7801`, `225:8052` (a header card, four chips, no tiles); reply and 发送 / 取消 buttons 34 high; rating stars at 2.1:1.
- Optimize: one page: header `5.0 · 1 条评价` with the distribution as five thin bars; chips 全部 · 待回复 · 低分 · 有图 with counts; each review card ends with one action (`回复`, or `修改回复` once replied) and a "⋯" for 删除回复 and 举报.
- Implement: Figma: one `Merchant/Review Card` (State = New / Replied / Reported). SwiftUI: `Menu`. Motion: sending a reply: the reply block expands under the review (220 ms), `.success`.

**MR-24 · P1 · AI 店铺参谋: charts without scale; contradicting numbers (notes)**
- Frames: `182:8263`, `182:8356`, `225:8155`, `225:8321`.
- Problem: lavender bars (the brand violet used in a chart) and a dot matrix with no axis, legend or values; "0 位玩家到店" beside "核销 2"; the greeting truncates; the recommended theme's cover is a blank gradient.
- Optimize: each module states one number, its comparison and a labelled chart (ref 4, 5): `本周到店 12 人 · 比上周 +3`. Neutral ink bars, the current period highlighted. Fix the data. "—" with its reason stays (it is right).
- Implement: Swift Charts `BarMark` with axis marks and `AXChartDescriptor`; Figma: `Merchant/Metric Module`. Motion: bars grow 400 ms on appear, once.

**MR-25 · P1 · 城市节点 and 报名成为节点: two layouts for one page (notes)**
- Frames: twins `182:8448`, `182:8485`, `182:8521`; states `225:9682`, `225:9754`, `225:10153`, `225:10463`, `225:10521`, `225:10578`.
- Problem: the twin of 116 is a centred title with a 4-dot stepper (current dot blue) and "待确认" in green; the new frames are a large left title with numbered cards. The map in `225:10521` is a four-block mock. 115's info card is nearly empty; "下线" is bare bold text.
- Optimize: keep the numbered-card layout (two steps do not need a stepper). The map uses a real map snapshot with a draggable pin and an address line. 下线 moves into a "⋯" with a confirmation.
- Implement: Figma: delete the twin layout; map asset. SwiftUI: `Map` + pin as in config CF-31.

**MR-26 · P1 · 品牌中心 and AI 店铺角色: read mode, then edit mode (confirmed for 品牌中心)**
- Frames: `227:17603` (门店信息 read) and `227:17672` (编辑, with 完成编辑); `227:18542` and `227:18612` (AI 角色); `227:17892` (error "暂未完成", button "重试保存"); `227:18934` (five of six characters are the same default memoji); headlines ending with a Latin full stop in `170:3821`, `227:18742` – `227:18870`.
- Problem: a settings list that must first be switched into edit mode adds a tap to every change; the save error says nothing.
- Optimize: rows are directly editable: each opens its field sheet and saves on 完成. The page has no edit mode and no 完成编辑. Errors name the cause (`网络没连上，请重试`). Distinct character art for the six presets. Chinese full stops or none.
- Implement: Figma: remove the two edit frames; each row's value updates in place. SwiftUI: `NavigationLink` / sheet per row; optimistic update with rollback. Motion: after saving, the row's value cross-fades (180 ms) and flashes its background once (400 ms); no toast.

**MR-27 · P1 · AI voice: no level, no timer, a manual refresh (notes)**
- Frames: `227:19212`, `227:19289`, `227:19366`, `227:19432`, `227:19495`.
- Problem: hold-to-talk is a black circle (good and tactile) with no level meter or timer; 生成中 has a "刷新状态" button; 清除声音 is a red text link.
- Optimize: while holding: a live waveform ring around the button and a count-up timer with the target (`0:08 / 0:15`). 生成中: a determinate or at least moving progress with what is happening (`正在学习你的声音，大约 1 分钟`), polling automatically. 清除声音 in a "⋯".
- Implement: `AVAudioRecorder` metering → `Canvas`; `ProgressView(value:)`. Motion: the ring follows the level each frame; release: the ring collapses into a playable waveform (300 ms); haptic `.impact(.medium)` on press, `.success` on a valid take, `.error` when too short.

**MR-28 · P1 · 合作中心: two card languages and two nav styles on one page (confirmed)**
- Frames: `183:2102`, `183:2192`, `230:9269`.
- Problem: the 广场 tab is nine near-identical dark navy gradient cards with the same date range inside a light page; 官方活动 is white cards with photo covers. "正在刷新官方活动…" has an ellipsis.
- Optimize: one card: cover photo (or the default art), title, date, one status tag, on the light surface. Dark cards are removed from the merchant theme.
- Implement: `Merchant/Opportunity Card`.

**MR-29 · P1 · 客户, 核销流水, 触达, 成员 (notes; 成员 confirmed)**
- Frames: `183:2281`, `230:9592` – `230:9975`, `183:2355`, `230:10275`, `183:2416`, `233:10782`, `183:2465`, `233:11311`, `183:2495`, `233:11564` – `233:11863`.
- Problem: 126 uses chips with counts in the twin and a 2-segment bar in `233:10782`; 128's five stat tiles have very small labels; 调整岗位 is a sheet with a pink 移除 button; 确认移除 and 撤销邀请 use system-blue alert buttons; row arrows are "→".
- Optimize: 成员: role as a pull-down on the row with 移除 last (ref 11); invites in their own section with the expiry and `撤销`. 客户详情 as ref 2. Tiles become rows when there are more than three numbers. Chevrons, not arrows.
- Implement: `Menu`; `Section`s. Motion: role change: the tag cross-fades 180 ms, `.selection`.

**MR-30 · P0 · 本站准备与运行: the urgent task is not the primary (confirmed)**
- Frames: `233:9703` (运行中), `233:9577`, `233:9629`, `233:9773`, `233:9834`, `233:9891`, `233:10091`, `233:10169`, `233:10254`.
- Problem: with "2 待核验" the primary is 出示打卡码 and three grey buttons follow (暂停接待, 输入核验编号, 扫码核验); the count is a plain number; nothing shows the station is live. The 准备清单 uses square checkboxes. 服务时段 is a hand-drawn wheel. The dynamic QR says "一次有效，扫后自动更新" with no countdown.
- Optimize: the primary follows the state: `核验 2 位玩家` when anyone is waiting, otherwise `出示打卡码`. 暂停接待 moves to "⋯". The 运行中 tag gets a pulsing dot (once every 2 s, stopped under Reduce Motion). Checklist rows use check marks. Native pickers. The QR has a countdown ring and refreshes itself.
- Implement: Figma: `Station/Primary` variants by state; `Station/Live Tag`. SwiftUI: state-driven button; `TimelineView` for the QR ring. Motion: when a player arrives, the count ticks up and the primary swaps label with a 220 ms cross-fade; haptic `.impact(.medium)`; a Live Activity mirrors the count (same three-number rule as the player's).

**MR-31 · P1 · 公开主页 and 纠错 (notes)**
- Frames: `182:7862`, `182:7964`, `223:9582`, `223:9773` – `223:10422`.
- Problem: the nav title "主页" and a grey tagline sit on a blurred photo; stats read "0 好友 / 0 关注 / 0 粉丝"; `223:10422` (结果未知) makes "再试一次" the primary although the copy says the request may have arrived.
- Optimize: a bottom gradient under any text on the cover; zero-value social stats are hidden; the unknown-outcome rule (section 2).
- Implement: gradient layer; swap to `Merchant/Outcome Unknown`.

**MR-32 · P1 · 营销, 预测, 到店权益 (confirmed for 营销)**
- Frames: `182:8065`, `182:8176`, `223:11032`, `223:11119`, `223:9334`, `223:9389`, `230:8916`.
- Problem: empty cards have a centred title and a left-aligned button; the coupon card is a black block on the light page with 3.9:1 text; 预测's answers 会 / 不会 are two identical grey buttons and the irreversible "公布并结算" is not marked; `230:8916` shows a banner "原请求可能已经保存，请先刷新列表再决定是否重试" above an enabled 保存权益.
- Optimize: empty modules as ref 5 (one line and one button, same alignment). Coupon card on the light surface. 公布答案: pick the answer (selected state), then a red-outlined `公布并结算` with a consequence sheet. The save-unknown case follows the unknown-outcome rule and the save button is replaced by `查看列表`.
- Implement: component swaps; one consequence sheet.

**MR-33 · P2 · 商家 Tab 根页 (confirmed)**
- Frames: `233:12260`, `233:12356`.
- Problem: 模板 squeezes a segmented control and a search field on one row with a floating "+ 发布" pill above the tab bar; 我的 says "推文" where the rest of the app says 帖文; stats show "—" with a long explanation line.
- Optimize: search under the title, the segmented control below it; `发布` as a nav bar button. `帖文`. Hide stats that are not open to merchants instead of explaining them.
- Implement: layout and text edits.

### Batch D · Creator and cooperation pages (R5)

**MR-34 · P1 · R5 publish twins are superseded but still on the page (confirmed)**
- Frames: `171:5929`, `171:6054`, `188:5698`, `171:6166`, `171:6496`, `189:3397`, `171:6655`, `186:5655`, `186:5718`, `186:5768`, `171:6575`, `188:5893`.
- Problem: these twins show an older editor (three black "编辑故事流" buttons, a category sheet with square checkboxes, 发布活动 steps with no bottom bar in the frame). Pages C1–C3 hold the complete flows. Two versions of one route invite the wrong one to be built; page P's flow 7 still links the old ones.
- Optimize: label the R5 publish twins "已被 C1–C3 取代" and point page P at the C frames once the config batches land.
- Implement: Figma labels; relink.

**MR-35 · P1 · 协作邀请 list: text-heavy cards and 22 pt buttons (confirmed)**
- Frames: `186:5836`, `186:5944`, `223:4343`, `223:4478`, `223:4571`.
- Problem: each card holds a status tag, a source line, a cover (the same route placeholder six times), three or four lines of 12 pt body and one or two black mini pills (拒绝, 接受合作, 查看合作, 缴纳保证金, 确认占槽, 回邀约). `223:4571` shows a green banner, a red banner and "支付处理中…" at once.
- Optimize: card: cover, title, who and what in one line (`城瘾跑团 邀你承接第 1 站`), the terms as two icon–value pairs (`票款 18%` · `保证金 ¥200`), the status tag, and the whole card opens the detail. Only the one action that matters stays on the card as a 36 pt button (`接受` on pending). One banner at a time.
- Implement: `Coop/Invite Card` (State = Pending / Accepted / Declined / Ended / NeedsDeposit). Motion: accepting: the card's tag changes with a 220 ms cross-fade and the card moves to its section (300 ms); `.success`.

**MR-36 · P1 · 协作详情 and 发起协作邀请 (confirmed)**
- Frames: `186:6051`, `186:6119`, `224:2093` – `224:2647`, `186:6186`, `224:6059` – `224:6382`.
- Problem: detail: a blue link block, "→" arrows, "取消合作" in red text among normal rows, square checkboxes in 申报本次供给, a five-row star list ("★★★★★ 非常好") for a rating. Invite form: a money field prefilled "¥ 0.00 /人"; black "已选" pills; the engineering wording of MR-04.
- Optimize: detail: terms as a table with the split as the bold row; actions as a grouped list with chevrons; 取消合作 in its own last group. Rating: five tappable stars with the word under them changing as you tap. Supply: rows with check marks. Invite: the amount field is empty with a placeholder; pick rows show a check; the primary keeps its count (`发送给 2 家`: it is good).
- Implement: component swaps. Motion: star rating: stars fill left to right with a 40 ms stagger and a 1.15× pop on the tapped one; `.selection` per star.

**MR-37 · P1 · 找商家承接 (confirmed)**
- Frames: `186:6231`, `225:2730`, `225:2761`.
- Problem: cards put tags ("场地免费", "可承接 20 人"), the name, hours and address as text over a busy photo; "正在刷新附近商家…" has an ellipsis; the sheet's button is "确定".
- Optimize: photo on top with only the distance tag on it; text below on the card surface; the two capability tags as chips. The sheet commits on tap (pick-one), no 确定.
- Implement: `Coop/Merchant Card`; sheet per section 2.

**MR-38 · P1 · 分润, 结算详情, 提现 (confirmed)**
- Frames: `186:6257`, `186:6297`, `186:6364`, `189:3482`, `189:3520`.
- Problem: "¥0.00" hero with a grey "联系平台客服提现"; "我的分润 —" as a hero; a mascot page whose whole content is "联系平台客服提现 · 添加客服微信，线下处理"; "-¥198.80 提现成功" with a raw date.
- Optimize: unknown hero amounts show `—` with a `核算中` tag (never a lone dash in 42 pt). The withdrawal hand-off as MR-07. Records: amount, status tag, `11月13日 19:26`.
- Implement: text and component swaps.

**MR-39 · P2 · Personal pages on R5 that duplicate R2 or lack a twin**
- Frames: 设置 `102:1763` (no twin here; R2 has the twin `190:5455`), 关于 `189:3869`, `189:3930` (and R2's `181:1966`), 地图搜索 `100:5026`, 合作与推荐 `103:2913`, 我的收藏 `105:3130`, 图片裁剪 `105:3206`, 用户服务协议 `111:1567`.
- Problem: the same routes exist on two pages with different twins; four pages have no twin and no "无需优化" label.
- Optimize: keep one twin per route (the R2 ones), mark the R5 copies as duplicates; add twins or the 无需优化 label to the four. 用户服务协议 still names "小程序用户隐私保护指引": the app needs its own wording (legal owner to confirm).
- Implement: labels; twins from the player kit.

**MR-40 · P1 · 账号注销 and 隐私保护 (confirmed)**
- Frames: `189:4271`, `188:5912`.
- Problem: 注销: a centred card with a red title at 2.9:1, a bullet list of blockers and one black button "我已处理，重新检查". 隐私保护: each setting has two black pills side by side (开启 / 关闭) instead of a switch, and "撤回" as a third style.
- Optimize: 注销: the same "待处理" sheet pattern as the club's 解散前待处理 (`236:8799` on R3): each blocker is a row with its status and `去处理 ›`; the button re-checks. 隐私: switch rows with one explanation line each; 撤回授权 as a row that opens a confirmation.
- Implement: reuse the club component; `Toggle`.

**MR-41 · P2 · Dark and light on R5**
- Frames: dark: `189:3550`, `100:5026`, `189:3719`, `189:3835`, `189:3996`, `189:4165`, `105:3130`, `105:3206`, `188:5912`, `111:1567`, `189:4271`; light: 130–137 and the publish twins.
- Note: the split follows the role rule (personal = dark, creator and cooperation = light). It is correct. Check the one crossing: opening 协作 from a dark personal page should push into light with the standard transition, not cross-fade.

### Batch E · Motion, accessibility, copy

**MR-42 · P1 · No motion or haptic is stated on any frame; no prototype reactions exist**
- Frames: all 465 (the earlier audit found 0 prototype reactions on R4 and R5).
- Optimize: the merchant tier is the handbook's utility tier: restrained, no celebration ("No celebration on destructive confirmation or on the merchant console"). Annotate with this table and wire the six key flows (入驻, 核销, 售后, 邀请员工, 协作邀请, 本站运行).

| Interaction | Motion | Haptic |
|---|---|---|
| Button, row press | scale .97, 80 ms | none |
| Chip, segment | 140 ms cross-fade; thumb slides 220 ms | `.selection` |
| Sheet present, detent, dismiss | section 3 | `.selection` on settle |
| Step push in a flow | slide 350 ms ease-out; progress fills 220 ms | none |
| Submit (any form) | the button shows progress in place; then the result sheet | `.success` / `.error` |
| 核销 success | check draws 220 ms in the result icon; the amount counts up 300 ms | `.success` |
| 核销 failed / 待复核 | icon cross-fades; no shake | `.error` / `.warning` |
| Status tag change | 220 ms cross-fade; the timeline gains its row in 300 ms | none |
| Inline error | text fades 140 ms; jump to the field 300 ms | `.error` once |
| Row removed (message, photo, perk) | collapse + fade 180 ms; undo toast where reversible | `.impact(.rigid)` |
| Number refresh (today card) | `numericText` roll | none |
| Pull to refresh | system | system |
| Toast | bottom, 220 ms in, 180 ms out; ≤ 12 Chinese characters (ref 15: toasts are short) | none |
| Destructive confirm | consequence sheet | `.warning` |

- Implement: Figma annotations + prototype links; SwiftUI `MerchantMotion` constants.

**MR-43 · P1 · Dynamic Type and touch targets**
- Frames: two-button rows (`218:2439`), stat tiles with small labels (`233:11311`, `183:2416`), chips, the 34 pt buttons listed in MR-15, × badges, bare text actions (`183:1906`, `182:8448`).
- Optimize: 44 pt targets everywhere; XXL proofs for the workbench (`182:7428`), a form step (`221:2681`) and a detail (`183:1819`): tiles become rows, two-button rows stack, the bottom bar keeps the primary full width.
- Implement: hit layers; three proof frames; `ViewThatFits`.

**MR-44 · P2 · Copy**
- Frames and fixes: "确定" (`221:3108`, `221:3188`, `225:2761`) → the action's name or commit on tap; ellipses ("支付处理中…" `223:4571`, "正在刷新官方活动…" `183:2192`, "正在确认最新记录…" `221:3966`, "正在刷新附近商家…" `225:2730`) → none; helper text that explains a control ("点开始或结束时间，用滚轮选择" `221:3188`, "已上传 1 张 · 点 × 可移除" `221:2747`) → removed; "已经到底了" → removed; "全部 14 →" versus "全部 ›" → `全部 14 ›`; step titles that differ for the same step ("告诉大家怎样找到你" `182:7546` versus "店在哪、几点开" `221:2681`; "补齐审核需要的资料" `182:7590` versus "上传经营资料" `221:2747`) → keep the shorter ones (店在哪、几点开; 上传经营资料); "去登录" → `登录`; "知道了" on result sheets → `完成`.
- Implement: find-and-replace.

---

## 5 · Batch order

| Batch | Issues | Scope | Depends on |
|---|---|---|---|
| A · Defects | MR-01 – MR-07 | Onboarding submit and review step, spec notes and boards, wording, seeds, layout bugs. | — |
| B · One kit | MR-10 – MR-19 | Type, buttons, nav, tab bar, sheets, chips, states, status, links, contrast. Components first, then swap page by page. | A |
| C · Merchant pages | MR-20 – MR-33 | R4 pages. | B |
| D · Creator and coop | MR-34 – MR-41 | R5 pages. | B |
| E · Motion, a11y, copy | MR-42 – MR-44 | Prototype wiring, proofs, wording. | C, D |

C and D can run in parallel. For the 19 R4 sections that this pass did not re-open, the executor should look at the frame before changing it and report any finding that no longer matches.

## 6 · Questions for the owner (defaults used)

| # | Question | Default |
|---|---|---|
| Q-A | 签约 and 提现 hand off to WeChat or to support. Can signing open in an in-app browser, and is withdrawal really manual? | Keep the hand-offs, name them, show the next step. |
| Q-B | The handbook says merchant tabs are icon-only; HIG and the player bar use labels, and the five merchant icons are not self-explaining. Show labels? | Yes, show labels. |
| Q-C | The workbench hero is cumulative income. Change it to today's three numbers? | Yes; cumulative moves to 账本. |

## 7 · Severity count

P0 11 · P1 27 · P2 4 · total 42.
