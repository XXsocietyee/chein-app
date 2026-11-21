# FULL REVIEW · Topic and gameplay configuration (C1, C2, C3)

Reviewer: Fable 5.2 · task `task_be11bd871857` · 2026-11-15 · read-only (no Figma or code was edited).
File `0YyoybGnU1KG0657wdGCPX`. Pages: C1 `237:14642` (主题配置 · 编辑器), C2 `235:178` (玩法配置 · 模板编辑), C3 `235:13237` (发布 · 票务 · 模板 · 外部游戏).

## 0 · What was reviewed, and how

| Page | Sections | Frames | How it was read |
|---|---|---|---|
| C1 | 12 | 186 | Every section rendered at 1× and read as tiles at 0.6×. The 45 "· 首屏" frames are crops of their "(full)" twins and were checked through the full frame only. |
| C2 | 21 | 288 | Every section rendered at 1×. All frames read at 0.6×, except 12 of the 14 "· full" editor-body frames in A2 (`237:29523`), read at 0.42× because they repeat `237:43689` with one section changed. `237:43689` and `237:46330` were read at 0.6×. Two kit boards read at 1×. The G6 component board (`255:14134`, 222 variants) was not opened variant by variant; it was judged through its 147 placed instances. |
| C3 | 13 | 155 | Every section rendered at 1× and read at 0.55×. Not opened as images: the tail tiles of five state rows (加载 / 失败 / 空 repeats in 发布活动 `_02`, `_11`; AI `_02`, `_05`; 模板 `_02`; 详情 `_01`, `_04`; 主题模板预览; 我的玩法 `_02`; 外部游戏详情; external `_02`, `_05`, `_07`) and the asset board `237:9072`. Their copy and geometry were covered by the metadata checks below. |

Metadata checks ran over all 629 frames (text content, text heights, control sizes): copy lint (sample leaks, raw codes, ellipses, banned words), and a size census of every button, pill, chip, switch, stepper, close and handle.

Not done: no contrast was measured with a tool (contrast findings are by eye and by token value); no prototype links were inspected; the owner's Kavsoft video could not be played in this session, so the sheet behaviour below follows the owner's description of it and the spring values are proposals, not values taken from the video.

**Result: 75 issues. P0 14 · P1 47 · P2 14.** (IDs CF-07 to CF-09 are unused.)

The five findings that matter most:
1. **The editor is drawn with two component kits and five sheet headers.** The same section (结果反馈) appears as grey fields on a white card in one frame and as white fields on a grey panel in the next. An Apple Design Award page has one of each (CF-10, CF-11).
2. **Sheets stack three deep** in the node editor, chapter settings and reward picker. HIG and the owner's handbook both allow one. Every sheet should become a resizable scrollable sheet with pushed sub-pages (CF-12, CF-13, section 3).
3. **Text does the work that controls should do.** Seven button verbs for "open this row", raw codes as option labels (`1 · 字偶尔闪`), colour names instead of swatches, units inside labels, status as sentences (CF-30 to CF-45).
4. **Three pages are far too long**: gameplay editor 4,940 pt, topic detail 3,123 pt, chapter settings 1,962 pt, with no outline, no completeness signal and no way to jump (CF-20, CF-24, CF-26).
5. **Fourteen frames ship defects**: annotation text inside the UI, QA seed strings, clipped labels, a composer floating over content, a blank centre tab (CF-01 to CF-05).

---

## 1 · References (24, none repeated from round 1)

Apple HIG text was read from Apple's documentation JSON (`developer.apple.com/tutorials/data/design/human-interface-guidelines/<page>.json`). Quotes are Apple's wording.

### A · Apple HIG: editing, forms, pickers

| # | Reference | Key guidance (quoted) | Lesson for C1–C3 |
|---|---|---|---|
| 1 | [HIG · Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data) | "When possible, offer choices instead of requiring text entry." "Dynamically validate field values." "Get information from the system whenever possible." "make the button available only after people enter the required data." | Replace typed codes and IDs (`clue_1`, `counter.instability`) with pickers or generated values. Validate on blur, not on 完成. Compass 取值 and 地图选点 already take data from the system: extend that to steps and audio length. |
| 2 | [HIG · Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields) | "match the size of a text field to the quantity of anticipated text." "Show a hint in a text field." "show the appropriate keyboard type." "Use a number formatter." | 奖励分, 次数, 秒 are full-width fields for a two-digit number. Make numeric fields short, right-aligned, with the unit as a suffix and a number pad. |
| 3 | [HIG · Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers) | "Avoid switching views to show a picker." "Use a compact date picker when space is constrained." "Consider providing less granularity when specifying minutes." | Dates and hours are native compact `DatePicker`s (5-minute steps), never a drawn wheel (B8g, C3.1) and never a dropdown of "20 点". |
| 4 | [HIG · Pop-up buttons](https://developer.apple.com/design/human-interface-guidelines/pop-up-buttons) | "Use a pop-up button to present a flat list of mutually exclusive options." "Provide a useful default selection." "Within a popover or modal view, consider using a pop-up button instead of a disclosure indicator." | Every `cy-dropdown` becomes a native pop-up button (`Picker(.menu)`). The drawn floating panel goes away; the system menu gives the check mark, haptic and animation for free. |
| 5 | [HIG · Menus](https://developer.apple.com/design/human-interface-guidelines/menus) and [Pull-down buttons](https://developer.apple.com/design/human-interface-guidelines/pull-down-buttons) | "Show people when a menu item is unavailable." "Prefer listing important or frequently used menu items first." "Let people know when a pull-down button's menu item is destructive, and ask them to confirm." "Consider using a More pull-down button." | Row actions (上移 / 下移 / 复制 / 删除) live in one "⋯" pull-down per row, destructive last and red. This removes the red text links, the pink blocks and half of the ✕ buttons. |
| 6 | [HIG · Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) | "Prefer displaying text in a list or table." "Let people edit a table when it makes sense. People appreciate being able to reorder a list." "Keep item text succinct." | 主题详情 and 章节设置 are settings lists: grouped inset list, label left, value right, chevron. Not 30 rows with 30 pill buttons. |
| 7 | [HIG · Steppers](https://developer.apple.com/design/human-interface-guidelines/steppers) and [Sliders](https://developer.apple.com/design/human-interface-guidelines/sliders) | "Make the value that a stepper affects obvious." "Consider pairing a stepper with a text field when large value changes are likely." "Consider giving live feedback as the value of a slider changes." "Use tick marks." | One stepper (native size, value between the buttons) for 1–10 ranges; field + unit for larger ranges. Sliders (轮廓浓淡, 刮开多少, 图片宽度) show the result live on the thumbnail. |
| 8 | [HIG · Toggles](https://developer.apple.com/design/human-interface-guidelines/toggles) | "Use the switch toggle style only in a list row." "Use a checkbox instead of a switch if you need to present a hierarchy of settings" (macOS). | iOS has no square checkbox. Multi-select rows use a trailing check mark; on/off uses one switch size. Remove the 22 px squares. |
| 9 | [HIG · Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls) | "Limit the number of segments… no more than about five segments on iPhone." "Use nouns or noun phrases for segment labels." | Rule for single choice: 2–3 short options that change the form below → segmented; 4 or more, or long labels → pop-up button; visual options → tile grid. Today all four controls are used without a rule. |
| 10 | [HIG · Disclosure controls](https://developer.apple.com/design/human-interface-guidelines/disclosure-controls) | "Use a disclosure control to hide details until they're relevant." "Place controls that people are most likely to use at the top… with more advanced functionality hidden by default." | 幸运 / 生命值越低越困难 / 魔鬼交易, 章末配给, 互斥选项 sit behind one "高级" disclosure per card. |
| 11 | [HIG · Drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop) | "Offer alternative ways to accomplish drag-and-drop actions." "Prefer letting people undo a drag-and-drop operation." "Show people whether a destination can accept dragged content." "Display a drag image as soon as people drag a selection about three points." | Reorder needs: a lifted row, an insertion line, a non-drag alternative (the "⋯" menu, already in B4.15) and undo. Dropping a node into a paragraph must show the split line before release. |
| 12 | [HIG · Undo and redo](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo) | "Show the results of an undo or redo." "Let people undo multiple times." | Deleting a block is undoable, so it needs no confirmation alert. Undo scrolls to and flashes the restored block. |
| 13 | [HIG · Action sheets](https://developer.apple.com/design/human-interface-guidelines/action-sheets) | "Use an action sheet — not an alert — to offer choices related to an intentional action." "Avoid displaying more than four buttons." "Make destructive choices visually prominent." | Leaving with unsaved changes, draft conflict and "delete chapter" are `confirmationDialog`s anchored to the button, not centred alerts. |
| 14 | [HIG · Modality](https://developer.apple.com/design/human-interface-guidelines/modality) | "Let people dismiss a modal view before presenting another one. Allowing multiple modal views to be visible at the same time tends to create visual clutter." "Make it easy to identify a modal view's task." | One sheet. Sub-editors push inside it. The sheet title names the task, once. |
| 15 | [HIG · Writing](https://developer.apple.com/design/human-interface-guidelines/writing) | "Check each word to be sure it needs to be there." "When labeling buttons and links, it's almost always best to use a verb." "Keep settings labels clear and simple… If the setting label isn't enough, add an explanation." | Cut explainer paragraphs (结果反馈 three-line intro, 支持矩阵 note). Each switch gets at most one footnote line that says what "on" does. |

### B · Form guidance outside Apple

| # | Reference | Key guidance | Lesson |
|---|---|---|---|
| 16 | [Atlassian Design · Form](https://atlassian.design/components/form/usage) | "Use one form column as it's easier to follow." "Never disable a submit button, even if all of the required fields aren't filled in." "Labels are required for all form inputs." Mark required with an asterisk; validate inline. | The primary stays enabled; tapping it scrolls to the first error and focuses it (the mini-program already does this in A1.9). Remove the disabled-and-red states (CF-17). |
| 17 | [Material 3 · Text fields](https://m3.material.io/components/text-fields/guidelines) | The page did not render in this session, so no quote is given. The published spec's rule is that error text replaces supporting text in the same slot and the counter stays at the trailing end. | One slot under each field: hint, or error, never both. Live counter `12/30` instead of the static "最多 30 字" (B7e). |

### C · Editors and builders (Mobbin)

| # | Reference | What it shows | Lesson |
|---|---|---|---|
| 18 | Apple Fitness · [Edit Activity](https://mobbin.com/screens/a3c6508b-01b0-4cbf-9286-47973f1dafd6) | Sheet with round ✕ left and round ✓ right, a large left title, two pop-up rows (Day, Activity Type), a row of five circular time chips, one destructive button at the bottom. | This is the TE header done natively. Durations are five tappable chips, not a number field. Delete is one full-width quiet button at the very end, once. |
| 19 | Apple Fitness · [weekly schedule](https://mobbin.com/screens/01e6de48-395e-4adf-b282-750de5fc5095) and [reorder stack](https://mobbin.com/screens/8a8359e5-e964-489d-a8cc-d699cc8cb695) | Day cards with one outlined "Add Activity" and quiet "Edit" pills; one filled primary at the bottom. Reorder: lifted row, handle at the trailing edge. | The pattern for the 创作页 chapter cards: one primary on the page, row actions quiet. Drag handle always trailing. |
| 20 | Kahoot! · [question editor](https://mobbin.com/screens/f4bc3527-1ea4-4aaa-a1d0-53bf01bd1faf) and [empty question](https://mobbin.com/screens/e6b54ab5-c467-4e99-8460-87b8fed0c917) | The editor looks like the played question: media on top, question, four answer tiles; the correct one carries a check on the tile; the question type is a pop-up in the nav; time limit is a chip on the media. | Edit in the shape of the result. 选项问答 options should be the answer tiles themselves, with the correct mark on the tile, not a 210 pt form card per option. |
| 21 | Kahoot! · [question list](https://mobbin.com/screens/f763899c-6f1a-4af8-8933-549cd09a6271) | Each question collapses to a thumbnail, type and one line, with a chevron to expand. | List editors collapse to one-line summaries; one item is open at a time (already done in A11.4, not in A4). |
| 22 | Notion · [block actions sheet](https://mobbin.com/screens/ffbb0bcf-8417-4242-a446-dd95101be27f) and [Move to](https://mobbin.com/screens/f78b07ed-7338-4cce-9f23-0df19c0630f4) | One sheet with grouped actions (insert, replace, duplicate, move, delete in red). "Move to" is a searchable list in a sheet with Done. | Story-flow block menu (B4.15) should carry every block action, including "移到另一章", so drag is never the only way. |
| 23 | Snapchat · [New Plan](https://mobbin.com/screens/31961a56-8a1b-4864-b120-5665de4c634a), Google Calendar · [new event](https://mobbin.com/screens/c7f19ec9-451c-4630-9ddb-6c8b07b27c2f), Reddit · [event label sheet](https://mobbin.com/screens/b3d86230-53c3-47b9-b81b-d62490f0b8f2) | Start / end as two rows of compact date and time pills. Title as a large borderless field. Multi-select in a content-height sheet with one Done. | 发布活动 step 1 and 票务 dates: two rows, native compact pickers. Category multi-select is a content-height sheet. |

### D · Sheets (owner reference)

| # | Reference | What it gives | Lesson |
|---|---|---|---|
| 24 | Kavsoft · [Resizing Scrollable Sheets Using SwiftUI](https://youtu.be/WRgYhvxNOqE) (owner reference; not playable in this session). Supporting articles: [Nil Coalescing · resizable sheet APIs](https://nilcoalescing.com/blog/ResizableSheetInSwiftUI/), [Daniel Saidi · size a sheet to its content](https://danielsaidi.com/blog/2026/05/22/making-a-swiftui-sheet-automatically-size-to-fit-its-content), [Swift in SG · sheets](https://swiftinsg.org/learn/sheets) | The owner's description: detents resize with scroll content; drag to grow; content scrolls only at full height; a smooth spring between detents. The articles confirm the APIs: a measured `.height` detent, `selection:` binding, and that a sheet resizes before it scrolls by default. | Section 3 applies this to every sheet family in scope (33 rows), with detents and spring values. |

---

## 2 · Shared decisions the batches rely on

These settle the "which one wins" questions once, so executors do not re-decide per frame.

| Topic | Decision | Basis |
|---|---|---|
| Sheet header | `Editor/Sheet Header`: grabber 36 × 5; row of round ✕ (left, 44 pt target, 32 visual) and black `完成` pill (right, 44 high); title 20 Bold centred below, optional 12 pt eyebrow above it. Pushed sub-pages swap ✕ for ‹. | Owner answer Q2 (TE screens) |
| Surfaces | Sheet and page `#F3F4F4`; cards `#FFFFFF`, radius 12, no stroke; fields inside a card `#EFEFEF`; fields directly on the grey sheet `#FFFFFF`. A grey panel inside a white card is not used. | Owner answer 5, handbook d.3 |
| Primary | One black pill per screen or sheet, 44 high. Everything else is `sec` (grey `#EAEBEE` pill, 36 visual, 44 target) or a text action. | Owner rule, HIG Buttons |
| Single choice | 2–3 short options → segmented. 4+ or long → pop-up button. Visual → tile grid. | Ref 9 |
| Multi choice | List rows with a trailing check mark. No square checkboxes, no radios. | Ref 8 |
| Selected state | Neutral: 1.5 px black border plus a filled black check. No green tint, no black fill on list rows. | Owner answer 3 (neutral) |
| Row "open" affordance | Chevron row with the current value in grey at the right. No verb pill. | Ref 6 |
| Add | One dashed row `＋ 添加…`, 44 high, at the end of its list. | A0 rule 5 |
| Row actions | Trailing "⋯" pull-down: 上移, 下移, 复制, 删除 (red, last). Swipe-to-delete as the shortcut. Drag handle trailing, 44 pt target. | Refs 5, 11, owner Q8 |
| Remove a whole module | One quiet red text row at the end of that module's sheet: `移除<名称>`. Confirm with a `confirmationDialog`. | Refs 13, 18 |
| Toast | One component `Editor/Toast`: dark pill, optional icon, bottom-anchored above the bottom bar, 2 s. Used only for results of an action elsewhere. Never for validation or limits. | HIG Feedback (round 1) |
| Errors | Inline, in the slot under the field. Sheet-level errors as one red banner under the header. | Refs 1, 16, 17 |

---

## 3 · Sheets: resizable scrollable sheets (owner reference 24)

### 3.1 Behaviour, for every bottom sheet in scope

- The sheet opens at its **smallest detent that shows its content** and grows by drag. The inner scroll view is locked until the sheet is at its largest detent; then the same drag continues as a scroll. Dragging down from scroll-top shrinks the sheet first, then dismisses.
- The move between detents is one spring. Content that changes the sheet's natural height (a pop-up choice revealing fields, an added row, an error banner) animates the detent with the same spring.
- The header (✕, title, 完成) stays pinned. The grabber is visible on every resizable sheet and hidden on a single-detent sheet.
- Dirty sheets cannot be swiped away: swipe-down rubber-bands and shows the "放弃修改？" dialog. ✕ does the same.
- Never a sheet on a sheet. A sub-editor pushes inside the sheet's own navigation stack (‹ replaces ✕; 完成 stays).

### 3.2 Values

| Item | Value |
|---|---|
| Spring between detents | `spring(response: 0.38, dampingFraction: 0.86)`, i.e. `.snappy(duration: 0.38, extraBounce: 0.04)`. Proposal; matches the handbook's 350 ms sheet timing. |
| Present | system sheet spring (about 350 ms). Dismiss 280 ms (handbook: exit 20% faster). |
| Content-height change | same spring; fields fade in over 180 ms, 60 ms after the height starts moving. |
| Haptic | `.selection` when the sheet settles on a new detent by drag; none on programmatic growth. `.impact(.light)` is not used for detents. |
| Reduce Motion | detent changes cross-fade in 200 ms, no spring. |
| Scrim | 40% black under `.large`; under a short sheet the page stays readable. `presentationBackgroundInteraction(.disabled)` everywhere (these are edit tasks). |

SwiftUI shape (one modifier for all editor sheets):

```swift
.sheet(item: $sheet) { s in
  NavigationStack { s.content
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fit = min($0 + chrome, maxFit) }
      .scrollDisabled(detent != .large)            // scroll only at full height
  }
  .presentationDetents(s.detents(fit: fit), selection: $detent)
  .presentationContentInteraction(.resizes)        // grow before scrolling
  .presentationDragIndicator(s.isResizable ? .visible : .hidden)
  .presentationCornerRadius(24)
  .interactiveDismissDisabled(s.isDirty)
  .animation(.spring(response: 0.38, dampingFraction: 0.86), value: fit)
}
```

Figma: each sheet gets a component property `Detent = Fit | Medium | Large`. Prototype: drag on the grabber between variants, Smart Animate, Spring (stiffness 290, damping 27, mass 1). The inner list frame has "Overflow: vertical" only in the `Large` variant.

### 3.3 Detents per sheet

`fit` = `.height(content)`, capped at 62% of the screen. Where two are listed, the first is the opening detent.

| Sheet | Frames | Detents | Notes |
|---|---|---|---|
| **C1** 主题模式 | `237:51012` | `fit` | Three radio cards; no scroll. |
| 图片版式 | `238:10351` | `fit` | |
| 分支任务 | `238:10642`, `238:10960` | `.medium`, `.large` | Grows when a third branch is added. |
| 插入变量 | `238:11297`, `238:11545` | `fit`, `.large` | |
| 节点编辑 (root) | `238:19720` – `238:22215`, `249:38453` | `.fraction(0.62)`, `.large` | Opens with the story flow still visible above. Sub-pages (玩法模板, 到达与引导, 下一站, 添加条件 / 效果, 地图选点) push and force `.large`. |
| 章节设置 | `239:24873` – `239:27314` | `.medium`, `.large` | After CF-26 the root is short; sub-pages push. |
| 主题详情 | `239:31923` – `239:33192`, all of `241:1679` | `.large` only | A long settings list is a full-height task (handbook T3). Every B7.x sub-editor pushes. |
| 文本编辑 (名称 / 描述 / 剧情) | `239:33463`, `239:33587`, `239:33711` | `.height(200)`, `.medium`, `.large` respectively | Sits above the keyboard; grows as lines are added up to `.large`. |
| 可玩时段 | `239:33835` | `fit` | |
| 开始 / 集合时间 | `246:6728`, `246:6908` | `fit` (about 420) | Native graphical `DatePicker`. |
| 票种编辑器 | `246:5882`, `246:6169`, `246:7094` | `.medium`, `.large` | Moves out of the inline accordion into a sheet (CF-28). |
| 剧情预览 / 发布检查 | `249:16472` – `249:17369` | `.large` only | |
| 发布确认 | `249:18596` | `fit` | |
| 发布结果 | `249:19029` – `249:20582` | `fit` | |
| 发布入口, 发布什么 | `249:32604` – `249:32995` | `fit` | |
| 选择奖励 / 新建优惠券 | `249:33124`, `249:33404`, `243:6962`, C2 `237:53314` | `.medium`, `.large` | 新建优惠券 pushes. |
| 选择合作者 | `249:35244`, `249:35539`, C3 `239:21290` – `239:22084` | `.medium`, `.large` | Focusing search jumps to `.large`. |
| **C2** 选择玩法 | `237:71933` – `237:74256` | `.fraction(0.62)`, `.large` | Category chips and the preview footer stay pinned. |
| 互动工具选择 | `237:64541`, `237:64724` | `fit` | |
| 费用, 奖励, 线索, 投票与投入 | `237:64911` – `237:69968`, `237:70572` – `237:71146` | `.medium`, `.large` | List tools. |
| 成功使用次数, 限时挑战, 时段限定, 排行榜, 语音讲解, 背景音乐, 物资交换 | `237:70136` – `237:70439`, `237:74533` – `237:76180` | `fit` | 3–5 controls each. |
| 扫完回复 | `238:12643` – `238:13611` | `fit`, `.large` | Height changes with 文字 / 语音 / 图片 / 显形: the clearest use of the spring. |
| 消耗与效果, 结果之后, 添加效果 | `237:25791` – `237:33389` | `.medium`, `.large` | 添加效果 pushes (it is already drawn with ‹). |
| 添加模块, 添加加值 / 代价, 选择场所, 玩法类别 | `238:15426` – `238:16017` | `fit` | |
| 保存结果 | `239:20809`, `239:20874`, `239:20944` | `fit` | |
| **C3** 设置活动时间 | `239:625`, `239:771` | `fit` | |
| 活动类型 | `239:919` – `239:1210` | `fit`, `.large` | |
| 我的模板 | `239:1333` – `239:1749` | `.medium`, `.large` | |
| 选择原起草记录 | `239:31173`, `239:31330`, `239:31468` | `fit`, `.large` | |
| 全部分类 | `243:2078` | `.medium`, `.large` | |
| 节点交互预览 | `243:26185`, `243:26341`, `243:26503` | `fit` | |
| 导入外部游戏 | `247:17464`, `247:17512`, `247:17565`, `247:17619` | `.medium`, `.large` | Keyboard raises it to `.large`. |
| 确认导入 / 更新 | `248:3258`, `248:3357`, `248:3448` | `.large` only | Permission review needs the whole list visible. |
| 发布成功 / 保存成功 | `238:19113`, `238:19278` | `fit` | |

---

## 4 · The plan

Format per issue: **ID · severity · title** — frames — problem — optimize — implement (Figma; SwiftUI; motion where it applies). Batches are ordered so that each one only depends on earlier ones.

### Batch A · Defects that must not ship (do first; no design decisions)

**CF-01 · P0 · Annotation and sample text is inside the UI**
- Frames: `237:22192` "（示例原因）"; `237:51305` "（示例）" and a truncated alert title "复制后需要重新选择：…"; `249:17076` "主题详情（示例）", "第三章 · 码头旧仓（示例）"; `249:33879`, `249:34151`, `249:34423`, `249:34699`, `249:34974` "（来源说明）", and `249:34699` "（示例原因）"; `241:1680`, `241:2059`, `241:2475`, `241:2854` and their 首屏 copies `249:41900`, `249:42278`, `249:42693`, `249:43071` "蓝 · 晴空（选中项下方显示说明）"; `239:6450` holds a designer note card inside the phone frame; `239:29100`, `239:29304`, `239:29508`, `239:29710` "AIGC 备案号：以线上配置 aigcFilingNo 为准".
- Problem: designer notes read as product copy.
- Optimize: delete the bracketed notes from the text; move each to a canvas annotation outside the frame. Alert title becomes `复制为新草稿` with the list in the body. AIGC line reads `内容由 AI 生成 · 备案号 <号>` with a sample number marked on the canvas.
- Implement: Figma text edits only; add `note:` stickies beside the frames. SwiftUI: none.

**CF-02 · P0 · QA and seed strings**
- Frames: `246:7461`, `246:8088`, `246:8549`, `246:9012` (`smoke-tpl-2612a0`, `smoke-draft-…`, `RW TEST licensed text`, cover letter "S", `2026-11-14 23:21:54`); `246:2717`, `246:2928`, `246:2996`, `246:3064`, `246:7367` ("城瘾官方E2E"); `247:16929`, `247:16992` ("Game rw.quiz1794649681").
- Optimize: use the seeded entities named in r1 rule 4 (`老城钟楼暗号挑战`, `海派城市漫游团`, `黄浦老城慢游 · 三站轻探线`). Dates as `11月14日 23:21`.
- Implement: Figma text and image swaps from the C3 asset board `237:9072`.

**CF-03 · P0 · Raw status codes and internal IDs shown to people**
- Frames: `249:24548`, `249:24653` (`PENDING`, `REJECTED`, `APPROVED`, `req-7f3a2c19`, `camera`); `249:24688`, `249:24757`, `249:36244`, `249:36313` (`外部游戏 gameId`, `节点 ID (nodeId) 992021`); `247:17370` (`campfire-puzzle · 链接导入 (URL)`); `248:3589` – `248:3734` ("完成并签名上报结果", "WebKit 沙盒视图").
- Optimize: 审核中 / 未通过 / 已通过 as status tags (soft fill, 12 px icon, text). Reason line `申请了未授权的权限：相机`. The game is picked by name; IDs are not shown. Request reference moves behind "复制诊断信息" in the "⋯" menu. Runner button: `完成并提交结果`.
- Implement: Figma: reuse the MP status tag component; replace texts. SwiftUI: `enum ReviewStatus` with `localizedTitle` and `symbol`; never print `rawValue`.

**CF-04 · P0 · Broken layouts and clipped text**
- Frames and fixes:
  - `239:29100`, `239:29508`: the composer floats in the middle of the page over the station cards. Pin it to the bottom safe area (`safeAreaInset(edge: .bottom)`); in the full frames `239:29304`, `239:29710` it is already at the end.
  - `239:29913`, `239:30054`: two buttons overlap the suggestion chips. Stack: status block, two buttons, then chips and composer pinned.
  - `241:6329`: decorative circles are scattered over the page and the error block. Restore the hero collage to its container (clip content on) as in `241:6261`.
  - `241:3821`: toast runs off the right edge. Use `Editor/Toast` (max width 329, wraps to two lines).
  - `237:14274`, `237:14385`, `237:25477`, `237:25689` and every "· full" body frame in `237:29523`: label "每个结果单独回复" is clipped at its last character. Set the text to auto-width.
  - `242:2589`: error line truncated; let it wrap. `242:3169`: pop-up value wraps to two lines; shorten the option labels to ≤ 10 characters and move the explanation to a footnote.
  - `236:15797`: `C2/Switch` instance is clipped on the kit board.
- Implement: Figma layout fixes; set "Clip content" correctly; auto-layout hug on labels.

**CF-05 · P0 · The centre tab is a blank white pill**
- Frames: `241:6374`, `241:6675`, `243:1807`, `243:1964`, `243:2575` – `243:2937`, `243:3249`.
- Problem: the 发布 tab has no icon and no label, and reads as a selected empty tab. The page is the 发布 tab's own root (owner ruling: 发布 opens the template square).
- Optimize: use the shared neutral 5-tab bar instance (首页 / 漫游 / 发布 / 俱乐部 / 我的) with 发布 selected: icon plus label, selection by weight and shape, not a white fill.
- Implement: Figma: swap to the shared `Tab Bar/Player` component, variant `selected=发布`. SwiftUI: native `TabView`.

**CF-06 · P0 · Copy bug and dead text**
- Frames: `237:59532` (the 活动地点 field's placeholder says "活动标题"); every A2 body frame, e.g. `237:43689`, `237:46330` (a lone grey line "先保存为我的玩法" with no control).
- Optimize: placeholder `活动地点`. The lone label is a mini-program remnant: remove it. If the owner wants the behaviour, it becomes a switch row "同时保存到我的玩法"; ask once (question Q-A in section 6).
- Implement: Figma text edit; delete the row in the `模板信息` card component.

### Batch B · One kit (components first; every later batch uses these)

**CF-10 · P0 · Two field kits in one editor**
- Frames: `C2/*` kit `236:15762` (used by A1, A2, A4: `237:29522`, `237:29523`, `238:16388`, `239:19530`, `239:22274`, `241:20608`, `243:25477`) versus `TE/*` kit `236:14482` (used by A5–A11: `237:14273`, `237:41065`, `237:49529`, `237:52776`, `237:64308`, `238:12378`, `238:15289`). A third look (white fields with a hairline on a white card) in `238:15346`, `238:15290` and `237:70572`.
- Problem: 结果反馈 in `237:43689` is grey fields on a white card; the same section in `237:14385` is white fields on a grey panel inside a white card. Scrolling the real page would show one or the other, never both.
- Optimize: one kit, per section 2 "Surfaces". Cards are white; nested list items are `#F3F4F4` panels with white fields only when they are list items (选项 1, 第 1 层); plain fields in a card are `#EFEFEF`.
- Implement: Figma: create `Editor/Field` (variants State = Empty / Filled / Focus / Error / Disabled; Kind = Line / Area / Number+Suffix; Surface = OnCard / OnPanel / OnSheet), `Editor/PopUp`, `Editor/Switch Row`, `Editor/List Item`, `Editor/Add Row`. Swap all `C2/Input`, `C2/Dropdown`, `TE/Field`, `TE/Textarea` instances by name; delete the two old sets. Bind fills to `mp/input`, `mp/input-strong`, `mp/surface`, `mp/page`. SwiftUI: `EditorField`, `EditorSection` (a `Section` in a `Form` with `.listRowBackground`).

**CF-11 · P0 · Five sheet headers**
- Frames: (a) one row ✕ · title · 完成: `237:71933` set; (b) ✕ / 完成 row, title below: all of `237:64308`, `238:12378`, C1 B5, B7; (c) title left, ✕ right: `238:15554`, C3 `239:919`, `239:1333`, `239:21290`, `243:2078`, C1 `249:32604`; (d) title left, count right, bottom black button: `238:15744`; (e) ✕ and centred 16 pt title, no 完成: `238:15880` – `238:16017`; (f) text buttons 取消 / 标题 / 完成: C1 `239:24873` – `239:27314`, `239:33463` – `239:33835`; (g) ✕ only at top, 完成 at the bottom: `241:3540`, `241:3821`; (h) ✕ at top right on result sheets: `249:19029` – `249:20582`.
- Optimize: `Editor/Sheet Header` from section 2 for every editing sheet. Pick-one sheets that commit on tap (选择场所, 添加加值, 发布入口) use the same header without 完成. Result sheets have no ✕; they end with buttons (CF-52).
- Implement: Figma: one component, properties `Leading = Close | Back | None`, `Trailing = Done | None`, `Eyebrow` (boolean + text), `Title`. Replace all eight patterns. SwiftUI: `.toolbar { ToolbarItem(.cancellationAction) … ToolbarItem(.confirmationAction) }` inside the sheet's `NavigationStack`, with `navigationBarTitleDisplayMode(.inline)` replaced by a custom large centred title view in `.safeAreaInset(edge: .top)`.

**CF-12 · P0 · Sheets stacked three deep**
- Frames: `239:2948`, `238:22593`, `238:22885` (玩法模板 on 节点 on 故事流); `239:3280` – `239:4264`; `239:4607` – `239:6886`; `239:26351` (章节 on 故事流); `243:6962` (优惠券 on 奖励 on 主题详情); `249:33404`; `249:35244`, `249:35539`; `239:33463` – `239:33835` (text pop-up on 主题详情).
- Problem: three sheet edges are visible at once; HIG and handbook T4 allow one sheet (plus an alert).
- Optimize: the story flow is a page, not a sheet (it is entered from the 创作页 and has its own back). Node, chapter and topic-detail are one sheet each; their sub-editors push inside it with ‹.
- Implement: Figma: redraw the listed frames with one sheet edge; header `Leading = Back`. Prototype: Push (slide left, 350 ms, ease-out `.22,.61,.36,1`) inside the sheet frame. SwiftUI: `NavigationStack(path:)` inside each sheet; `navigationDestination(for:)` per sub-editor.

**CF-13 · P1 · Every sheet becomes a resizable scrollable sheet**
- Frames: all sheets in section 3.3.
- Optimize and implement: as section 3. Add the `Detent` property to `Editor/Sheet` and draw the opening detent in each frame; for the eleven sheets with two detents, add one `Large` frame next to the existing one.

**CF-14 · P1 · Two switch sizes**
- Frames: C1 `toggle/on` 51 × 31 (177 instances) versus C2 `C2/Switch` and `TE/Switch` 44 × 26 (475 instances), C3 `switch` 44 × 26.
- Optimize: native size 51 × 31 everywhere, one component, on-colour from the token already used.
- Implement: Figma: swap C2 and C3 instances to the C1 component; rows are 44 high minimum so nothing reflows. SwiftUI: `Toggle` with `.tint`.

**CF-15 · P0 · Touch targets under 44 pt across the editor**
- Census (visual size): seam "＋" icon 10 × 10 (237 instances in C1, e.g. `237:51859`, `237:65700`); sheet ✕ 36 (C1), 28 (C3 `239:919` …); `button/sec` 34 high (500+ instances); verb pills 30–32 high (C2, 480 instances); chips 26 high; stepper 34 high with 12 px glyphs (`239:24873`, `239:6886`, `241:20710`); row ✕ 16–18 (C2, 400 instances); drag handle 20 × 20 (346); radio rows 21 high (`238:16749` …); check squares 22.
- Optimize: keep the visual sizes where they look right, but give every control a 44 × 44 hit area, and raise the ones that are also hard to see: seam "＋" becomes a 28 pt circle on a 44 pt-high seam row; sheet ✕ 32 visual; secondary pill 36 visual; row actions move into the "⋯" menu (CF-33), which removes the 16 px ✕.
- Implement: Figma: add a transparent 44 × 44 `hit` layer inside each control component (documented in the component description); list rows min-height 44. SwiftUI: `.frame(minWidth: 44, minHeight: 44).contentShape(.rect)`; steppers are native `Stepper`.

**CF-16 · P1 · Four toast styles, and toasts used for validation**
- Frames: black rectangle, radius 6 (C2 `237:59972`, `237:56530`, `237:56966`, `249:36634`); dark-grey rounded (`243:24841`, `243:24934`); pill with icon (C1 `237:21719`, `237:22339`); light pill on dark (C3 `243:3249`, `247:17110`). Toasts that should not be toasts: `238:21851` "请填写节点名称"; `237:56530` "最多 12 步"; `237:55565` and `238:15824` "移除成功"; `239:771` "时间设置完成"; `238:14596` "已添加: 小鹿"; `239:25461`; `239:4264`; `249:32506`; `246:6908`.
- Problem: toasts land wherever there is room, cover the control they refer to, and vanish before a slow reader finishes.
- Optimize: one `Editor/Toast` (section 2). Validation moves to the field. Limits are shown by disabling the add row with a count (`12/12`). Confirmations of visible changes (a chip disappearing, a row appearing) need no toast.
- Implement: Figma: one component, variants Icon = none / success / info, Theme = light-page / dark-page; place at bottom, 12 above the bottom bar. Delete the listed toasts and draw the inline state instead. SwiftUI: a single `ToastCenter` overlay in the root; `sensoryFeedback(.success/.warning)` replaces the confirmation toasts.

**CF-17 · P1 · Primary buttons disabled without a reason, or disabled while errors show**
- Frames: `237:59532`, `238:14501`, `238:14857`, `238:14996`, `238:17887`, `238:18023` (发布活动); `249:16773` (完成 greyed with blockers); `237:63852` (read-only template: all three bottom buttons greyed).
- Optimize: the primary stays enabled. Tapping it with missing data scrolls to the first problem, focuses it and shows its inline error (the mini-program does this in A1.9). Where the action is truly unavailable (read-only, no permission), replace the bar with one sentence and one useful action (`去模板广场选用`).
- Implement: Figma: redraw the listed frames with the enabled primary and one focused error. SwiftUI: `ScrollViewReader.scrollTo(firstError, anchor: .center)` + `@FocusState`. Motion: scroll 300 ms ease-out, then the field shakes 3 × 6 pt over 240 ms; haptic `.error` once.

**CF-18 · P1 · Loading and failure are drawn as modal cards**
- Frames: `237:21650` (skeleton + scrim + spinner card), `237:21681` (alert-like card over a dimmed skeleton), `249:17706` (spinner card), `237:59795`, `246:7964` (spinner only), `238:22885` ("加载中…").
- Optimize: first load = skeleton that mirrors the final layout, no scrim, no card. Failure = inline state on the page: icon tile, `<对象>没加载出来`, one `重试` button. In a sheet list, skeleton rows.
- Implement: Figma: one `Editor/State` component (Kind = Loading-skeleton / Empty / Error / SignedOut / NoPermission), icon tile 64, title 16 Semibold, body 13, one button; centred at 40% height. C2 states (`237:59761` – `237:59934`, top-pinned without icon) and C3 states use it too. SwiftUI: `ContentUnavailableView` styled; `.redacted(reason: .placeholder)` for skeletons, shown after 200 ms.

**CF-19 · P1 · Two nav families inside one creation flow**
- Frames: C1 pages use a back circle and a large left title (`237:31646`, `246:5536`); C2 uses a plain chevron and a centred 18 pt title (`237:43689`); C3 发布活动 uses a plain chevron and a large left title (`237:59431`); AI 快速创建 a centred title "快速配置" (`239:24018`).
- Optimize: creation pages are light, second-level pages: back chevron in a 44 pt circle, centred 17 Semibold title once (handbook N3 for tools), no large title. The page name matches its entry: `AI 快速创建`, `编辑玩法模板`, `发布活动`, `票务设置`.
- Implement: Figma: one `Editor/Nav Bar` component; swap in all page frames of C1 (B1, B2, B8), C2 (all), C3 (活动, AI). SwiftUI: native `NavigationStack`, `.navigationBarTitleDisplayMode(.inline)`.

### Batch C · C1 structure and flows (topic editor)

**CF-20 · P1 · 创作页: four black buttons and an ambiguous chapter card**
- Frames: `237:31646`, `249:37911`, `237:31806`, `237:32292`, `237:32538`, `237:32682`, `237:32772`, and the B1 set `237:21719` – `237:22339`.
- Problem: each chapter card carries a chevron, a black "编辑故事流" and a grey "编辑章节"; with three chapters and 下一步 the screen has four primaries. The bottom bar holds four controls, including an unlabelled list/map toggle with a dot.
- Optimize: the whole chapter card opens its story flow (that is what people come to do). Chapter settings move to the card's "⋯" (编辑章节, 复制, 删除). The card shows state by design: node count, a thin progress bar of "写好的块 / 全部块", and a red dot only when something blocks publishing. List / map is a two-segment control under the title, not in the bottom bar. Bottom bar: `保存草稿` (secondary) and `下一步` (primary).
- Implement: Figma: `Topic/Chapter Card` component (State = Default / Lifted / Empty / Blocked), 72 high, radius 16; segmented `列表 | 地图` at 16 below the nav. SwiftUI: `List` + `.onMove`; `Picker(.segmented)`; card is a `NavigationLink`. Motion: card press scale .97, 80 ms; list ↔ map cross-fade 220 ms with the pins scaling from .8 (stagger 20 ms).

**CF-21 · P1 · B1 state frames are drawn on an older page base**
- Frames: `237:21719`, `237:21833`, `237:21953`, `237:22073`, `237:22192`, `237:22339`, `237:51012` – `237:51305`.
- Problem: they show "主题详情 还差 2 项" in grey, no save chip and no 保存草稿, while B2 shows "* 还有 2 项未填" in red with a chip.
- Optimize: rebuild these states on the CF-20 page. The save chip is the only save status (remove "保存中…" inside the button in `237:32682`; ellipsis is also banned by the handbook).
- Implement: Figma: duplicate the final B2.1 frame and re-apply each overlay.

**CF-22 · P1 · Save status chip: six states by text only**
- Frames: `237:31646` (已存本机), `237:31806`, `237:31986`, `237:32682` and others (已存云端 / 本机未存 / 待确认 / 保存中 / 云端未存).
- Optimize: a 12 px icon plus two characters: ✓ 已存 · ↑ 同步中 · ! 未存. "本机" and "云端" detail appears on tap in a small popover with the time ("本机 14:02 · 云端 13:58"). Colour only for the failure state.
- Implement: Figma: `Editor/Save Chip` (State = Saved / Syncing / Unsaved / Failed). SwiftUI: `Label` + `.popover`. Motion: icon swaps with a 140 ms cross-fade; on Saved the check draws in over 220 ms; no haptic (frequent event).

**CF-23 · P1 · Story flow: tiny seams, duplicate styling controls, two exits**
- Frames: `237:51424`, `237:51859`, `237:65700`, `237:65956`, `237:66174`, `237:66404`, `237:66638`, `237:66866`, `237:67108`, `249:38071`.
- Problem: the insert seam is a 10 px "＋"; the type chips are 26–30 high with two of seven filled black. A selected text block shows its style chips inside the block and again above the keyboard. The header has a text "完成" and the bottom has a black "下一步": two ways forward.
- Optimize: seam = a 44 pt-high row with a hairline and a 28 pt "＋" circle that appears between blocks (always visible at the end, on tap between blocks). The type picker is one row of seven equal icon-over-label tiles (文字, 图片, 音频, 分支, 分割线, 地点, 玩法), none filled. Text styling lives only in the keyboard accessory bar. One exit: the nav back returns to the 创作页 (edits are auto-saved to the device, as the save chip says); 下一步 stays as the single primary and goes to chapter settings as TE P8 shows.
- Implement: Figma: `Story/Seam` (State = Rest / Expanded), `Story/Block Type Tile` 48 × 56; delete the in-block chip row in `237:65956`. SwiftUI: `ScrollView` of blocks; seam is a `Button` revealing a horizontal tile row; `ToolbarItemGroup(placement: .keyboard)`. Motion: seam expand: tiles fade and rise 8 pt, 220 ms ease-out, stagger 15 ms; haptic `.selection`. Insert: new block scales from .96 and fades in 220 ms; haptic `.impact(.light)`.

**CF-24 · P1 · Story-flow blocks describe effects in codes and words**
- Frames: `237:67108`, `249:38071`.
- Problem: 文字效果 shows "1 · 字偶尔闪" with a helper "可选：0·正常 / 1·字偶尔闪 / 2·褪色错位 / 3·等宽字…"; 氛围 shows "蓝" with "可选：黑 / 蓝 / 红 / 黄 / 白"; 内心声音 is a dropdown showing "心".
- Optimize: design language. 文字效果 is a row of four sample tiles, each rendering "钟声" in that effect. 氛围 is five colour swatches (as 章节配色 already is in `239:24873`). 内心声音 is a tile row of voice icons. No numbers, no "可选" sentences.
- Implement: Figma: `Editor/Swatch Row` (reuse from B6), `Editor/Sample Tile` 72 × 56 with the effect drawn. SwiftUI: `LazyVGrid` of selectable tiles; selection = 1.5 px border + check. Motion: the selected tile's sample plays its effect once (600 ms) on select; haptic `.selection`.

**CF-25 · P0 · Deleting a node says three different things**
- Frames: `237:68146` ("5 秒内可以撤销，过后不可恢复"), `237:68363`, `237:67919` (undo toast), `238:21479` ("节点会移到待编排区"), `239:27044` ("删除后不可恢复" without saying what happens to its nodes).
- Problem: the consequence is unclear, and a confirmation alert plus an undo toast is double friction.
- Optimize: one rule. Removing a node from a chapter moves it to 待编排 with no alert and a 5-second undo toast (`已移到待编排 · 撤销`). Deleting from 待编排 or from the node sheet is permanent and asks once in a `confirmationDialog` (`删除节点「钟楼」？它的玩法设置会一起删除。`). Deleting a chapter states the consequence: `删除第二章？3 个节点会移到待编排。` Deleting a text block never asks; undo covers it.
- Implement: Figma: redraw the five frames to this rule; delete `237:68363`. SwiftUI: `UndoManager` registration per delete; `.confirmationDialog(titleVisibility: .visible)`. Motion: removed block collapses height and fades, 220 ms; undo re-expands and flashes the row background for 600 ms; haptic `.impact(.rigid)` on delete, `.success` on undo.

**CF-26 · P1 · 章节设置 is one 1,962 pt form on an inverted surface**
- Frames: `239:24873`, `249:40292`, `239:25247`, `249:40665`, `239:25461`, `239:25642`, `239:25811`, `239:26091`, `239:27314`.
- Problem: 17 settings in one scroll; white sheet with grey panels (the reverse of B5 and B7); custom 20 px steppers; red "移除" on every row plus always-visible handles.
- Optimize: the root shows what every chapter needs: 名称, 完成要求 (pop-up), 配色 (swatches), 奖励 (row). Then one group "更多设置" of chevron rows with values: 章末配给 (4 项), 章末消耗 (2 项), 互斥选项, 音频, 初始状态, 背包, 途中彩蛋, 工作人员开幕. 设为结局 is a switch row. 删除章节 is the last, quiet red row. Surface per section 2.
- Implement: Figma: rebuild on `Editor/Sheet` with grouped list rows (`Editor/Row`: Label, Value, Accessory = Chevron / Switch / PopUp / Stepper). Each "更多设置" item gets a pushed sub-page reusing the existing content blocks. SwiftUI: `Form` with `Section`s; `LabeledContent`; `NavigationLink`. Flag: this regroups the mini-program's single form; contents and order inside each group are unchanged (question Q-B).

**CF-27 · P1 · 主题详情: 30 rows, seven button verbs**
- Frames: `239:31923`, `249:40880`, `239:32500`, `239:32749`, `249:41456`, and the same base under every B7.x frame in `241:1679`.
- Problem: each row ends in a 34 pt pill reading 编辑, 修改, 选择, 配置, 添加, 上传 16:9, ＋上传 or 更换. Some rows have a pill and a switch. The title is editable only by tapping it, with no affordance. A support note ("支持状态以玩法支持矩阵为准。反馈或工单是独立渠道…") and a full-width pink "清空本地草稿" sit among the settings.
- Optimize: grouped inset list. Row = icon, label (with a red dot when required and empty), current value or thumbnail at the right, chevron. No verbs. Covers show a 44 pt thumbnail or a dashed slot. Rows that are on/off keep only the switch; turning it on reveals a chevron sub-row. The title gets a pencil glyph. Five groups get sticky headers: 基本信息, 玩法规则, 数值与状态, 奖励, 高级. Remove the support note (it belongs in help). `清空本地草稿` moves to the nav "⋯" menu.
- Implement: Figma: `Editor/Row` as in CF-26; replace 30 rows; group headers 13 Semibold `#6B6B6B`. SwiftUI: `List(.insetGrouped)`; `Section(header:)`; `.listSectionHeaderPinning`. Motion: switch reveal: sub-row height animates 220 ms ease-out with fade.

**CF-28 · P1 · Text pop-ups: static limits, duplicate confirm**
- Frames: `239:33463`, `239:33587`, `239:33711`, `239:33835`.
- Problem: "最多 30 字" is static; 可玩时段 has 完成 in the header and a black 完成 at the bottom.
- Optimize: live counter `12/30` at the trailing end, turning red at the limit; one 完成 (header pill). Name edits inline in the header title when tapped (one field does not need a pop-up); 描述 and 剧情 keep the pushed editor per the owner's Q2 answer.
- Implement: Figma: `Editor/Field` with `Counter` on. SwiftUI: `TextField(axis: .vertical)` + `.onChange` clamp; counter `contentTransition(.numericText())`.

**CF-29 · P1 · Node sheet: the name is shown twice, the 玩法 card is dense**
- Frames: `238:19720`, `238:20056`, `238:20393`, `249:38453`, `238:20772`, `238:21136`, `238:21851`.
- Problem: the header title repeats the 名称 field under it. The shared-template panel offers "仅为本站另存副本" and "修改原模板 · 影响 2 个节点" as two text links; 对应主题资源 rows show a disabled reason as a dropdown value ("请先启用主题资源"). A missing name is reported by a toast.
- Optimize: header eyebrow `节点 3 · 第一章`, title = the name itself, editable in place (no separate 名称 field). 玩法 card: G6 icon, name, one line of summary; a quiet tag `共用 · 2 个节点`. Tapping 编辑 on a shared template opens a `confirmationDialog`: `只改这一站（另存副本）` / `修改原模板（影响 2 个节点）`. Resource rows that cannot be set show a grey lock and the reason as a footnote, not as a control. Missing name: the title field turns red with `请填写节点名称`.
- Implement: Figma: redraw B5.1 frames; `Node/Gameplay Card` component (State = Empty / Set / Shared / Error). SwiftUI: inline `TextField` in the header; `.confirmationDialog`. Motion: none beyond CF-17 for the error.

**CF-30 · P1 · Template picker uses coloured "玩" squares and says 确定**
- Frames: `239:2948`, `238:22593`, `238:22885`.
- Problem: tiles are red, black, cyan, orange, purple and green squares with a "玩" glyph, not the G6 icon system; the bottom button says "确定" (banned by the handbook); the failure state has no retry.
- Optimize: rows use `G6/Gameplay Icon` by gameplay type and show the template's 看点 line. Choosing a row selects it; the header 完成 pill commits (no bottom button). Failure: inline state with 重试.
- Implement: Figma: swap tiles to `G6/Gameplay Icon` 44; delete the bottom bar; use `Editor/State`. SwiftUI: `List(selection:)`.

**CF-31 · P1 · Map pickers lack search and "my location"**
- Frames: `238:22215` (节点地图选点), `237:32444` (地图视图; a toast covers the selected pin and the title repeats in the sheet).
- Optimize: a search field at the top of the map, a 44 pt glass "定位" button at the trailing edge, the centre pin lifts while panning and drops on settle, and the address resolves in a bottom card with `用这个位置`. In 地图视图 the selected node's card is a `fit` sheet, the pin gets a ring and 1.15 scale, and no toast.
- Implement: Figma: add `Map/Search`, `Map/Locate` (glass circle). SwiftUI: `Map` + `MapCameraPosition`, `.onMapCameraChange(frequency: .onEnd)`, `MKLocalSearchCompleter`. Motion: pin lift 6 pt while dragging (80 ms), drop with `spring(response: .3, dampingFraction: .6)`; haptic `.impact(.light)` on drop.

**CF-32 · P1 · 到达与引导 and 下一站: a rule builder made of six control types**
- Frames: `239:3280`, `249:38831`, `239:3768`, `239:4264`, `239:4607`, `239:5014`, `249:39318`, `239:5505`, `239:5982`, `239:6450`, `239:6886`, `249:39808`.
- Problem: radios, a segmented control, accordions, chips, small red text links (换一个名字 / 删除) and a custom stepper share one page. The eyebrow is a three-line path. A warning ("扫码尚未配置有效码，请先完成扫码配置") has no link. `239:4264` blocks the row with a toast "先点「完成」保存这个节点".
- Optimize: write each rule as one sentence with tappable tokens, in the Apple Shortcuts style: **如果** `体力` `≥` `3` **则去** `码头旧仓`. Each token is a pop-up button. Rules are list items (handle, "⋯"). 备用节点 is a multi-select list with check marks. The warning becomes a row with a chevron that opens 扫码配置. The unsaved-node block is removed: the sheet saves the node silently when a sub-page is opened.
- Implement: Figma: `Rule/Sentence` component: auto-layout wrap, tokens = `Editor/Token` (pill 32 high on a 44 row, `#EAEBEE`, value in Semibold). SwiftUI: a custom `FlowLayout` of `Menu` buttons. Motion: adding a rule: row expands 220 ms; a token change cross-fades 140 ms; haptic `.selection`. Flag: same data, new presentation of the mini-program's form (question Q-B).

**CF-33 · P1 · Five delete patterns, four add patterns, handles on both sides**
- Frames (delete): red text "删除 / 移除" (`239:24873`, `241:20710`, `237:25961`, `238:14596`); swipe action (`243:5502`, `243:6286`); trash icon (`239:6450`, `237:65956`, `247:17370`); 80 pt pink block with left-aligned text (`241:4114`, `242:4500`, `242:4824`, `242:5141`, `242:5534`, `241:3540`); ✕ (all of C2 A4); grey "移除" (`237:64911` – `237:71146`); three wordings of the centred red link in A10. Add: dashed row; blue "＋ 添加消耗" link (`237:25791`); black ＋ circle (`238:15426`); input plus black 添加 pill (`243:5502`, `243:5918`). Handles: leading in `239:24873`, `242:3777`, `243:7832`, all C2; trailing in `242:4102`, `243:5502`, `243:6286`, `239:31923`, `243:9240`.
- Optimize: per section 2: "⋯" pull-down per list item, swipe as shortcut, handle trailing, one dashed add row, one quiet red row to remove a module. D20 rows that have both ✕ and "删除" (`241:20710`, `241:21404`) keep neither; they get "⋯".
- Implement: Figma: `Editor/List Item` header = title · handle · "⋯"; replace in all list editors of C1 and C2 (about 900 instances; do it at component level). SwiftUI: `.swipeActions`, `.contextMenu`, `Menu`, `.onMove`. Motion: see CF-60.

**CF-34 · P1 · Selection looks different on every sheet**
- Frames: green tint and green text (`237:51012`); black outline (`242:3471`, `241:1680`); black fill with white text (`238:15554`); black chips (`237:64541`); radio circles for multi-select (`239:919`); square checks (`239:3280`, `242:4102`, `242:4500`, `243:8571`, `238:15744`, `241:20928`).
- Optimize: section 2 "Selected state" and "Multi choice".
- Implement: Figma: `Editor/Choice Row` (Selected on/off; Kind = Single / Multi) and `Editor/Choice Tile`; replace. SwiftUI: `List(selection:)` / custom tile with `.overlay(RoundedRectangle().stroke())`.

**CF-35 · P1 · Destructive blocks are broken components**
- Frames: `241:4114`, `242:4500`, `242:4824`, `242:5141`, `242:5534`.
- Problem: an 80 pt pink block with small left-aligned "删除" text, sometimes inside a tall empty white card.
- Optimize and implement: covered by CF-33; listed separately because these frames need redrawing, not only an instance swap. Remove the empty card height in `241:4114`.

**CF-36 · P1 · 画面风格: choices described in words**
- Frames: `241:1680`, `241:2059`, `241:2475`, `241:2854`, `241:3231`.
- Problem: four style thumbnails are good. Below them, 字体 chips are not set in their own typeface, 文字动效 is 14 text chips and 转场 16 text chips with no preview; chips are 26–32 high.
- Optimize: font tiles render "城瘾" in that face. 文字动效 and 转场 become a horizontally paged row of preview tiles that play on tap; the long tail sits behind `全部 16 种 ›`. The style preview (`241:3231`) is reachable from a persistent "预览" row at the top rather than only at the end.
- Implement: Figma: `Editor/Sample Tile` (CF-24) with motion thumbnails; Smart Animate variants for 3 representative effects. SwiftUI: `ScrollView(.horizontal)` + `.scrollTargetBehavior(.viewAligned)`; tiles run their `PhaseAnimator` once on selection. Haptic `.selection`.

**CF-37 · P1 · d20 and 初始状态 use system vocabulary**
- Frames: `243:5502`, `249:44236`, `243:5918`, `249:44651`, `243:8571`, `249:45755`, `243:8923`.
- Problem: switches 天然 20 和天然 1 / 魔鬼交易 / 动量 have no explanation; 初始状态 speaks of 注册属性, 注册定义, 注册版本 and "我确认采用这项注册定义".
- Optimize: each switch gets one footnote that says what "on" does for the player (e.g. `掷出 20 必成功，掷出 1 必失败`). 初始状态 says `属性` and `属性版本`; the consent line becomes a switch row `使用这套属性`. Advanced items sit behind one `高级规则` disclosure.
- Implement: Figma: `Editor/Switch Row` with `Footnote`; text edits. SwiftUI: `Section(footer:)`; `DisclosureGroup`.

**CF-38 · P1 · 票务设置: two back buttons and an inline editor with three black buttons**
- Frames: `246:5536`, `249:46117`, `246:5687`, `246:5882`, `249:46267`, `246:6169`, `249:46553`, `246:6396`, `246:6568`, `249:46779`, `246:7094`, `249:46938`.
- Problem: a back circle at the top and another at bottom-left; the ticket editor opens as an accordion inside the list with a black "编辑中" pill, a black 保存票种 and a black 预览. The price label reads "票单价格 (积分)". The 票务 card on the 创作页 says only "票务设置 / 编辑 ›".
- Optimize: one back (nav). Ticket rows show name, price, stock; tapping opens the ticket editor as a `.medium/.large` sheet with the standard header. Bottom bar: `预览` (secondary) and `发布` (primary). Price field: value with a `积分` suffix. The 创作页 card shows a summary: `2 种票 · 39 积分起`, or `还没设置` in red.
- Implement: Figma: `Ticket/Row`, ticket sheet built from `Editor/Field`. SwiftUI: `List` + `.sheet(item:)`. Motion: sheet per section 3.

**CF-39 · P0 · Date and time pickers are drawn by hand**
- Frames: `246:6728`, `246:6908`, C3 `239:625`, `239:771`; hour dropdowns "20 点" in `238:24057`, `238:24147`, `238:24238`; "23:00" dropdowns in `237:74963`.
- Problem: handbook d.5: "Never draw a system keyboard, calendar…". Three different drawings exist. `246:6908` reports an invalid time with a toast.
- Optimize: field rows with native compact date and time pickers; the end picker's minimum is the start, so the invalid case cannot be chosen. In Figma, show the field and the iOS 27 kit's picker component, not a custom wheel.
- Implement: Figma: place the Apple iOS 27 UI kit `Date Picker` (compact) instance in a `fit` sheet; delete the custom wheels. SwiftUI: `DatePicker(selection:in:displayedComponents:)`, `.datePickerStyle(.compact)`, `minuteInterval = 5` via `UIDatePicker.appearance()`.

**CF-40 · P0 · Publishing: a "完成" pill that publishes, behind three confirmations**
- Frames: `249:16472`, `249:47215`, `249:16773`, `249:17076`, `249:17369`, `249:17706`, `249:17998`, `249:18299`, `249:18596`.
- Problem: the header pill says 完成 but starts publishing; then an alert titled "发布前提示" (the handbook bans 提示 as a title), then a 发布确认 sheet with 确认发布. The pass checklist lists all nine passed items (180 pt). Switches for 俱乐部承接 / 商家承接 are editable inside a preview.
- Optimize: the pill says `发布`. Passed checks collapse to one row `9 项检查通过 ›`; only blockers and suggestions are listed, each with `去修改 ›` that jumps to the field. Settings shown in the preview are read-only values with `修改 ›`. One confirmation: the 发布确认 sheet (it carries the real summary: name, chapters, tickets, who can see it). The pre-check runs inline in the pill (spinner replaces the label), not in a modal card.
- Implement: Figma: redraw B9.1a–h; delete `249:18299` and `249:17706`'s modal card. SwiftUI: `Button` with `ProgressView` label state; `.sheet` for the confirmation. Motion: check rows resolve top to bottom, 60 ms stagger, each check draws 220 ms; when all pass, the list collapses to the summary row over 300 ms. Haptic `.success` when the check set passes, `.warning` when a blocker is found.

**CF-41 · P1 · Publish result sheets: static, inconsistent, one without a reason**
- Frames: `249:18913`, `249:19029`, `249:19340`, `249:19653`, `249:19962`, `249:20272`, `249:20582`, `249:32506`.
- Problem: ✕ sits at the top right (elsewhere left); `249:20272` "这次还没有发布出去" gives no reason; `249:19653` is hard to parse; `249:18913` is a two-line toast over the buttons.
- Optimize: one `Editor/Result` sheet: icon, title (the object's state: `已提交审核`), one line of what happens next with a time (`通常 1 个工作日内有结果`), one primary (`查看主题`), one secondary (`继续编辑`). Failure states name the cause and offer `重试`. No ✕.
- Implement: Figma: component with State = Success / Pending / Failed / Unknown. SwiftUI: `fit` sheet. Motion: creation tone is restrained (handbook: celebration is for players only): the icon scales .8→1 with a 220 ms ease-out and the check draws once; haptic `.success` / `.error`.

**CF-42 · P1 · Entry sheets are light panels over a dark player page**
- Frames: `249:32604`, `249:32735`, `249:32865`, `249:32995`.
- Problem: a white sheet rises over the black player home; the two entry sheets use different headers.
- Optimize: the entry sheet takes the theme of the page it sits on (player: glass dark, per handbook T1); the light editor theme starts when the editor opens. One header (title left is acceptable for T1 pick-one sheets, but pick one and use it in both: use `Editor/Sheet Header` without 完成).
- Implement: Figma: switch the sheet's variable mode to MP-Dark; rows keep their icons. SwiftUI: `.presentationBackground(.regularMaterial)` + `.preferredColorScheme(.dark)` on the sheet content.

**CF-43 · P1 · AI 助写, 地点待办, 合作者: small rule breaks**
- Frames: `249:33879` – `249:34974`; `249:33706`; `249:35244`, `249:35539`, C3 `239:21290`.
- Problem: 地点待办 cards each carry black buttons (several primaries); "无法邀请" gives no reason; the AI quota state is a full-width grey button reading "今日AI次数已用完".
- Optimize: 地点待办 rows are quiet (`去设置 ›`); the single primary is the sheet's 完成. "无法邀请" gets a second line with the reason (`对方未开启合作邀请`). Quota: the generate button stays visible but disabled with a footnote `今天的 5 次已用完，明天 0 点恢复`.
- Implement: Figma text and button-style swaps. SwiftUI: none special. Motion (AI generating): the text field shows a shimmer sweep, 1.2 s loop, stopped under Reduce Motion; generated text types in by line over 400 ms; haptic `.success` when done.

### Batch D · C2 structure and gameplay cards

**CF-44 · P1 · The gameplay editor is one 4,940 pt scroll with no map of itself**
- Frames: `237:43689`, `237:46330`, `237:45599`, `237:47990`, `237:53447`, `237:54277`, `237:55116`, `237:55926`, `237:57539`, `239:20236`, `239:30205`, `239:28271`.
- Problem: eleven sections, 5.8 screens. A 1:1 cover fills the first screen. There is no outline, no completeness signal and no way to jump to the section with the error.
- Optimize (keeps the mini-program's single page and section order): (1) cover becomes 16:9 with the title over its bottom gradient, saving 150 pt; (2) a sticky section bar under the nav: `信息 · 规则 · 玩法 · 反馈 · 奖励 · 工具`, the current one underlined, a red dot on any section with an error, tap to jump; (3) each card's header shows a one-line summary when the card is collapsed, and cards other than 玩法设置 start collapsed once they are valid; (4) 可触发的结果 and 需要的资源 become read-only chips inside 玩法设置's footer instead of separate cards.
- Implement: Figma: `Editor/Section Bar` (6 items, State per item = Default / Current / Error / Done), `Editor/Card` with `Collapsed` property and `Summary` text; redraw `237:43689` and the eleven sibling full frames from it. SwiftUI: `ScrollViewReader` + `.scrollPosition(id:)` driving the bar; `DisclosureGroup`-like card. Motion: bar underline slides with `matchedGeometryEffect`, 220 ms; card expand 300 ms ease-out, content fades 180 ms; jump scroll 350 ms; haptic `.selection` on bar tap.

**CF-45 · P1 · Two previews with different rules**
- Frames: `237:43689` (a mid-page "▶ 按这份配置试玩" card and a bottom-bar "查看预览"); `237:56966`, `249:36634`, `249:37089` (toasts explaining why 试玩 cannot run); `237:14274` – `237:14540` (the 试玩 card pinned at the top of 结果反馈).
- Optimize: one entry: the bottom bar's `预览` opens the player-view preview at the gameplay step; the five-step pager lets people go back to 到达 and forward to 奖励. The mid-page card is removed. When the preview cannot run, the button stays enabled and the preview opens on a state that says what is missing with `去填写 ›`.
- Implement: Figma: delete the 试玩 card component from all body frames; add `A12.0 预览 · 还不能演` using `Editor/State` on the dark preview base. SwiftUI: `fullScreenCover` with a pager. Motion: see CF-63.

**CF-46 · P1 · Option editors: 210 pt per option, the correct mark at the bottom**
- Frames: `238:16749`, `238:16930`, `238:17139`, `238:17275`, `238:17563`, `238:24917`, `238:25111`, `238:23751`, `238:23850`, `238:23952`, `239:23200`, `239:23321`; in the page: `237:43689`.
- Problem: three options take 640 pt. The "设为正确答案" radio is a 21 pt row at the bottom of each card; 人物指认 nests three levels and reaches 3,192 pt.
- Optimize: an option is one 52 pt row: a leading correct-answer control (circle for single, rounded square for multi, hidden for 问卷), the text, an optional 36 pt image thumbnail, the handle. Only the option being edited expands to show 选中后的反馈, 配图 and 记住这个选择. 人物指认 becomes a pushed sub-page per person (avatar, name, role, testimonies) reached from a people row.
- Implement: Figma: `Editor/Option Row` (Kind = Single / Multi / Survey; State = Collapsed / Expanded / Error; Correct on/off). SwiftUI: `ForEach` rows with `@State expandedID`; `.onMove`. Motion: expand 300 ms ease-out; marking correct: the control fills with a 220 ms scale-in (.6→1) and the previously correct one empties; haptic `.selection`.

**CF-47 · P1 · Numbers: three controls for 次数上限, units inside labels**
- Frames: 次数上限 as a pop-up "3 次" (`238:16749`), as a field with placeholder "0 表示不限" (`238:16389`, `238:23751`, `239:22703`), as a field labelled "(1–10)" (`238:24355`); labels carrying units: "要安静多久（秒）" `243:24682`, "达标毫秒" `243:24405`, "目标方位（度）" `243:24749`, "时长（秒）" `237:74533`, "难度 DC · 1 至 40" `243:23964`. The order of 奖励分 and 次数上限 flips between `238:16389` and `238:23751`.
- Optimize: one `Editor/Number` control: label, right-aligned value, unit suffix (秒, 次, 步, 度, 积分), stepper for ranges up to 20. "不限" is a switch (`不限次数`) that hides the number, not a magic 0. Range hints appear only as the error text. Fixed order at the end of every card: 次数上限, then 奖励. Milliseconds are shown in seconds with one decimal (`0.3 秒`). "DC" reads `难度值`.
- Implement: Figma: variant of `Editor/Field` Kind = Number+Suffix, 120 wide; a `Card Footer` sub-component holding the two standard rows. SwiftUI: `TextField(value:format:)` + `.keyboardType(.numberPad)` + `Stepper`; `contentTransition(.numericText())`.

**CF-48 · P1 · "奖励分" versus the single currency**
- Frames: every A4 card footer (e.g. `238:16389`, `243:24265`), `238:12643` ("奖励分 0 至 200"), hint cost "消耗积分" in `237:41118`; C3 `238:14596` price "39" with no unit; `249:24688` "TEST 净销售分成 ¥12.60".
- Problem: the ruling is one currency, 积分. The editor says 奖励分 in cards and 积分 in hints; prices show no unit.
- Optimize: label `奖励` with the suffix `积分` everywhere it is that currency; if 奖励分 is a separate in-game score, name it `得分` and say so once in the 完成奖励 card. Prices carry `积分`. The TEST cash row stays TEST-only (owner Q5) with a `测试` tag beside it.
- Implement: text edits in `Card Footer`; question Q-C for the owner.

**CF-49 · P1 · Identifiers typed by hand**
- Frames: `239:22352`, `239:22435` (卡片 ID `clue_1`, error "卡片 ID 不能重复"); `239:27826`, `239:27886` (`name`, `job`, `clerk`, `watchman`, `counter.instability`, `{picked}`, `{assigned}`); `237:33571` (`counter.energy`, `tag.hurried`); `239:23486` (a raw JSON textarea).
- Optimize: IDs are generated and hidden; duplicates cannot happen. Keys become pickers over the theme's named values (`不安`), and placeholders are inserted through the existing 插入变量 sheet as chips (`〔选中的项〕`). Legacy JSON is read-only behind `查看原始配置`, with the parsed preview (already drawn in `239:23486`) as the main content.
- Implement: Figma: remove the ID fields; token chips inside text areas. SwiftUI: `AttributedString` tokens; `Picker` for keys.

**CF-50 · P1 · Sensor challenges are forms of numbers; they should look like the challenge**
- Frames: `243:24265` – `243:25394` (计步, 变色就点, 弹球, 安静, 罗盘, 喊一嗓子, 倒计时, 精准停表, 输入挑战), `243:25478` – `243:25926` (G4).
- Problem: every challenge is "标题 + two number fields". The 计步 note "以 Apple 健康同步的步数为准" is styled as a disabled input.
- Optimize: one small visual per card that the numbers drive: 罗盘 a dial with the target wedge (容差 = wedge width), set by rotating the phone (已有 "对准方向取值") or dragging; 精准停表 a timeline bar with the tolerance band; 安静 / 喊 a level meter with the threshold line; 弹球 a phone outline with a hit counter; 计步 a progress ring. The note becomes a footnote with a heart icon. G4's grey box of disclaimers shrinks to one footnote.
- Implement: Figma: `Gameplay/Param Visual` set (9 variants, 120 high, monochrome like G6). SwiftUI: `Canvas` / `Gauge`; compass via `CLLocationManager.heading`. Motion: visuals track the value with `spring(response: .3, dampingFraction: .8)`; compass capture: wedge snaps, haptic `.impact(.medium)`; drag over detents (every 15°) `.selection`.

**CF-51 · P1 · 选择玩法: previews exist but only in the footer**
- Frames: `237:71933`, `237:72185`, `237:72437`, `237:72643`, `237:72910`, `237:73177`, `237:73454`, `237:73731`, `237:73983`, `237:74256`.
- Problem: the list is icon + name + sentence; the owner asked for "icons and visual previews of each gameplay type". Two black pills (完成, 预览). Descriptions of "—" (闭眼盲品, 今日城市签). Eight disabled rows repeat the same two-line reason in light grey. Nothing shows which category holds the current pick.
- Optimize: a two-column grid of `G6/Gameplay Preview` tiles (120 × 90) with the name under each; tap selects and plays the tile's 1-second loop once; the footer shows the picked type's description and a secondary `试看`. Unavailable types move to a collapsed group at the end, headed by the reason once (`这个主题里用不了 · 8 种 ›`). The category chip of the current pick carries a dot. Write the two missing descriptions.
- Implement: Figma: grid of existing `G6/Gameplay Preview` instances; `Selected` variant; one `Group Header`. SwiftUI: `LazyVGrid(columns: 2)`; `Section` with `DisclosureGroup`. Motion: tile select: border draws 140 ms, preview loop plays once (600–1000 ms), haptic `.selection`; category change: grid cross-fades 180 ms and the chip underline slides.

**CF-52 · P0 · Save result sheets are dead ends**
- Frames: `239:20809`, `239:20874` (no button and no ✕); C3 `238:19113`, `238:19278` (same); `239:20944` (has two buttons: correct).
- Optimize: `Editor/Result` (CF-41) with actions: draft → `继续编辑` / `回到我的玩法`; published → `查看玩法` / `完成`; activity → `查看活动` / `完成`. "预计 3 分钟" becomes part of the sentence (`大约 3 分钟后可以在模板库里看到`).
- Implement: Figma: instance swap. SwiftUI: `fit` sheet; `.interactiveDismissDisabled(false)`.

**CF-53 · P1 · Tool sheets: conflicts explained after the fact**
- Frames: `237:64541` (red line "投票不能与费用、奖励、线索或次数叠加，请先移除投票" after tapping), `237:64724`, `237:25689` (toast "请先移除投票工具"), `237:74836` ("此玩法不支持限时" inside an opened sheet), `237:71146`.
- Optimize: incompatible tools are visibly unavailable before the tap: dimmed chip with a small link icon; tapping shows a popover anchored to the chip with the reason and the fix (`移除投票后可用`). A tool the gameplay does not support is not offered as a sheet at all.
- Implement: Figma: `Tool Chip` State = Available / Added / Blocked; popover component. SwiftUI: `.popover(attachmentAnchor:)` with `.presentationCompactAdaptation(.popover)`. Haptic `.warning` on a blocked tap.

**CF-54 · P1 · 完成奖励 and 勋章样式 are text**
- Frames: `237:52777` – `237:53314`.
- Problem: 勋章样式 is a pop-up of "二维发光 / 3D 珐琅" with no picture; 选择奖励 here uses chips, a black `新建优惠券` and a 完成 pill, while C1 `243:6962` and `249:33124` draw the same shared sheet with a segmented control and a grey "＋ 新建优惠券".
- Optimize: medal style is two preview tiles showing the uploaded art in each finish. The reward picker is one shared sheet: segmented `优惠券 | 体验卡`, list with check marks, a dashed `＋ 新建优惠券` row, header 完成.
- Implement: Figma: make `Shared/Reward Picker` a component and place it in C1 and C2. SwiftUI: one `RewardPickerSheet`.

**CF-55 · P1 · D20 is drawn two ways**
- Frames: `241:20609` – `241:21572` (难度 as a pop-up, dashed add row) versus the page behind `238:15880`, `238:15942`, `238:16017` (难度 as a segmented control, blue "＋ 添加加值" link).
- Optimize: 难度 has three short options that change nothing below → segmented (section 2 rule). The owner's reference draws a dropdown; the rule in section 2 would change it. Keep the owner's dropdown unless the owner accepts the rule (question Q-D). Either way, both frames must match; the add control is the dashed row.
- Implement: Figma: rebuild the base of the three A11.5 frames from `241:20710`.

**CF-56 · P2 · G6 icons are not used everywhere**
- Frames: `238:12379`, `238:12462`, `238:12545` (blue tinted tile); C1 `239:2948` (CF-30); C3 `243:2078` (3D emoji-like chips), `243:25998` and siblings (emoji section icons 📖 🧩 🔍).
- Optimize: gameplay identity is always `G6/Gameplay Icon`. Section headers use the coolicons outline set. The 3D category art stays only where it is content (the store's hero tiles).
- Implement: instance swaps.

**CF-57 · P2 · Legacy and read-only blocks**
- Frames: `239:23106`, `239:23417`, `237:58011`, `237:57539`, `243:25926`.
- Problem: read-only values are drawn as disabled inputs, which invites tapping.
- Optimize: read-only data is plain label–value text in a grey panel with a lock glyph and one line: `旧设置，保存时原样保留`.
- Implement: Figma: `Editor/ReadOnly Group`. SwiftUI: `LabeledContent` in a `Section`.

### Batch E · C3 pages

**CF-58 · P1 · 发布活动: a stepper that does not look like one, tickets in a flat list**
- Frames: `237:59431`, `237:59532`, `237:59657`, `238:14231` – `238:14501`, `238:14596`, `238:14747`, `238:14857`, `238:17887` – `238:18475`, `238:18584` – `238:19000`.
- Problem: the three steps are 11 pt dots and words. Ticket fields are a flat run ("票单名称1 *", 价格, 库存, "票单名称2 *"…) with a red "删除"; the 发布前摘要 box sits between the tickets and "添加票单". The cover slot is a full-width white card around a 44 pt thumbnail. Real-name fields and a square consent checkbox appear inline on step 3. `237:59657` says "已售出" twice (note and toast).
- Optimize: a three-segment progress bar under the nav (handbook T3), each segment tappable once visited, labels 13 pt. Each ticket is a card (`早鸟票 · 39 积分 · 20 张`) that opens the ticket sheet (same as CF-38). Order on step 3: 合作者, tickets, `＋ 添加票单`, then the summary as the last block above the bar. Cover: a 16:9 slot the width of the card. Real-name is its own pushed step shown only when needed, with a switch-style consent row. The lock note stays; the toast goes.
- Implement: Figma: `Editor/Step Bar` (3 segments), `Ticket/Row` (shared with C1), redraw step 3. SwiftUI: `TabView(.page)` or a `NavigationStack` path per step. Motion: step change slides 350 ms ease-out in the travel direction; progress segment fills 220 ms; haptic none (navigation).

**CF-59 · P1 · AI 快速创建: tags before the prompt, a confusing recovery state**
- Frames: `239:23979` – `239:24700`, `239:28946`, `239:29100` – `239:29710`, `239:29913` – `239:31022`, `239:31173` – `239:31606`.
- Problem: 18 tag chips fill the first 250 pt before the one thing people came to do (say what they want). While generating, the send button shows "…". The recovery state says "这次没能继续 / 原起草还在进行中" with a send button relabelled "查看". History rows are unstyled sentences ("只读历史 · 11月15日 14:02 · …").
- Optimize: the composer and three suggestion chips lead; tags collapse to one row of the 6 most used with `更多 ›`. Generating: the draft card appears at once as a skeleton that fills in (name, then stations one by one). Recovery: one card `上一次起草还在生成` with a progress line and two actions `等它完成` / `重新起草`. History rows: title, time, a status tag (只读 / 本机).
- Implement: Figma: reorder; `AI/Draft Card` State = Generating / Ready / Failed; `History Row`. SwiftUI: `safeAreaInset(edge: .bottom)` composer. Motion: stations appear with a 120 ms stagger, each rising 8 pt and fading 220 ms; the route line on the card draws 600 ms; haptic `.success` when ready; all skippable by scroll. Reduce Motion: fade only.

**CF-60 · P1 · Drag-to-reorder needs one motion spec (owner Q8)**
- Frames: `237:31986`, `237:32141`, `237:67490`, `237:67711`, `239:6450`, `239:19592`, `241:21572`, `237:33756`, `237:42181`, `237:50816`.
- Problem: the lifted state is drawn in three ways (shadow only; black border and shadow in `239:19592`; shadow and scale in `241:21572`), and none shows the insertion line.
- Optimize and motion spec:
  - Lift: long-press 180 ms on the row or immediate on the handle. Row scales 1.03, shadow `0 8 24 rgba(0,0,0,.14)`, 140 ms ease-out. Haptic `.impact(.medium)`.
  - Move: neighbours slide out of the way with `spring(response: .32, dampingFraction: .82)`; a 2 pt black insertion line shows the landing slot. Haptic `.selection` each time the slot changes.
  - Drop: row settles with `spring(response: .28, dampingFraction: .78)`; shadow fades 140 ms. Haptic `.impact(.light)`.
  - Drop into a paragraph (story flow): the paragraph opens a gap at the nearest sentence break before release; on drop, an undo toast `已拆成两段 · 撤销`.
  - Auto-scroll when within 60 pt of an edge. Cancel (drop outside): row returns 220 ms, no haptic.
  - Alternative: "⋯" → 上移 / 下移 (CF-33). VoiceOver: `accessibilityAction(named: "上移")`.
- Implement: Figma: `Editor/List Item` State = Lifted; a `Drop Line` component; prototype Smart Animate between Rest → Lifted → Moved frames, Spring (stiffness 300, damping 26). SwiftUI: `.onMove` in `List`, or `draggable` / `dropDestination` with a custom reorder for the story flow.

**CF-61 · P1 · Template store and detail pages**
- Frames: `241:6374` – `243:3249`; `243:25998` – `244:17097`; `246:2533` – `246:7367`; `246:7461` – `246:9012`.
- Problem: theme cards with no cover show a small route glyph on a dark block with "实验预览". The detail page's primary `应用` is dark grey on black in `244:16953`, `246:2717` while `244:16367` uses a white primary. 采用条件 lists six rows of unknowns (待补充, 未实测, 待核实, 许可信息未提供). 我的节点玩法 cards print raw rows (个人审核, 模板广场, 创建时间).
- Optimize: no-cover themes use the handbook's default art (`一起玩`), not a glyph. The primary is always the white pill on dark. Unknown conditions collapse to one line `还有 4 项信息待补充 ›`. My-template cards: cover, name, two status tags (审核 / 广场), the time as `11月14日`; details behind the card.
- Implement: Figma: instance swaps and row regrouping. SwiftUI: none special. Motion: `应用` shows progress in the button, then pushes the editor (350 ms); the "正在配置，请稍候" toast (`246:2928`) goes.

**CF-62 · P1 · External games use stock blue iOS chrome inside the dark player app**
- Frames: `247:17370` – `247:17619`, `248:3258` – `248:3864`, `249:24548` – `249:36313`.
- Problem: blue text buttons (取消, 确认安装, 撤回, 保存并提交审核) and blue links, while the rest of the player app uses neutral white primaries. The library header crams a wrapping title and two text actions. Each row has a red trash icon with no confirmation drawn. Monetization is a list of blue values.
- Optimize: the app's own tint (white on dark) for bar buttons; the confirm action is a white pill. Header: title `小游戏库`, one "＋" pull-down (链接 / 扫码 / 文件), `提交审核` inside the "⋯" menu. Delete by swipe with a `confirmationDialog`. Permissions are icon rows (存档, 触感, 声音) with check marks, not sentences in brackets. Monetization values are pop-up rows in the neutral style.
- Implement: Figma: switch to MP-Dark tokens; replace blue text styles; `Editor/Sheet Header` (dark mode). SwiftUI: `.tint(.white)` on the stack; `Menu`. Motion: install: the confirm pill fills as progress, then the new row slides into the library list (300 ms) with `.success`.

### Batch F · Motion, haptics and preview (specs to annotate on the frames)

**CF-63 · P1 · The player preview is static where the game is animated**
- Frames: `238:25435` – `238:25821`.
- Problem: this is the one player-facing surface in C2, and it is the creator's only look at how the gameplay feels. Success and failure are static icon cards; A12.3 frames drop the status bar and nav that A12.1 has; "任务完成!" uses a half-width exclamation mark.
- Optimize: the preview plays the real moments, each skippable by tap: arrival card rises; story beats reveal one by one; an answer tile presses, then resolves; success shows the check drawing and the reward flying to its slot; failure is a short shake. Keep the nav (`玩家视角预览`, ✕) on all five steps. Copy: `任务完成` (no mark).
- Motion spec (game tier; the handbook allows the 600 ms celebrate and the stamp spring for players):
  - Step change: horizontal slide 350 ms `ease-out (.22,.61,.36,1)`; the five-segment progress fills 220 ms. Swipe also pages. Haptic none.
  - Answer press: tile scale .97, 80 ms. Correct: tile border turns green and a check draws, 220 ms; haptic `.success`. Wrong: tile shakes 3 × 6 pt, 240 ms; haptic `.error`.
  - Result card: rises 24 pt and fades, `spring(response: .42, dampingFraction: .8)`.
  - Reward: medal scales .6→1 with the stamp spring `(.2,1.4,.5,1)`, 600 ms; haptic `.impact(.heavy)` at the peak. Reduce Motion: fade only, haptic kept.
- Implement: Figma: add 3 in-between frames (answer pressed, check drawing, medal mid-scale) and wire Smart Animate; annotate each with the values above. SwiftUI: `PhaseAnimator` / `KeyframeAnimator`; `sensoryFeedback`.

**CF-64 · P1 · No frame states its motion or haptic**
- Frames: all interactive states in C1–C3.
- Optimize: annotate with this table (utility tier unless marked).

| Interaction | Trigger | Motion | Haptic |
|---|---|---|---|
| Button, pill, tile press | touch down | scale .97, 80 ms ease-out; release 120 ms | none |
| Switch | tap | system | system |
| Switch reveals fields | value change | height + fade 220 ms ease-out; hide 180 ms | none |
| Pop-up button | tap | system menu | system |
| Chip / segmented select | tap | fill cross-fade 140 ms; thumb slides 220 ms | `.selection` |
| Add list item | tap `＋ 添加` | new row expands from 0 height, 220 ms, then focuses its first field | `.impact(.light)` |
| Remove list item | menu or swipe | collapse + fade 180 ms; undo toast | `.impact(.rigid)` |
| Reorder | CF-60 | CF-60 | CF-60 |
| Inline error appears | blur or submit | text fades in 140 ms; field border to red 140 ms | `.error` once per submit |
| Jump to first error | tap primary | scroll 300 ms, shake 240 ms | `.error` |
| Counter near limit | typing | number roll (`numericText`); turns red at limit | `.warning` once at limit |
| Image upload | pick | thumbnail appears blurred, ring progress, sharpens 220 ms when done | `.success` on finish |
| Slider | drag | live value; preview updates each frame | `.selection` at ticks |
| Stepper | tap | number roll 140 ms | system |
| Sheet present / detent / dismiss | section 3 | section 3 | section 3 |
| Push inside sheet | tap row | slide 350 ms ease-out | none |
| Save draft | tap | chip: ↑ then ✓ draws 220 ms | none (frequent) |
| Publish success | result sheet | CF-41 | `.success` |
| Leave with changes | back / swipe-down | action sheet | `.warning` |
| Compass capture | tap 取值 | CF-50 | `.impact(.medium)` |
| Map pin drop | pan end | CF-31 | `.impact(.light)` |

- Implement: Figma: one "Motion" annotation per frame type using the file's annotation categories; prototype the eight most-seen ones (sheet detent, push, switch reveal, add row, reorder, seam expand, error jump, preview step). SwiftUI: a single `EditorMotion` namespace of `Animation` constants; `sensoryFeedback(_:trigger:)`.

**CF-65 · P2 · Reduce Motion and interruption rules are not stated**
- Optimize: every animation above is interruptible (tap or scroll cancels to the end state). Reduce Motion: springs become 200 ms cross-fades; shimmer and preview loops stop; haptics stay.
- Implement: annotation; SwiftUI `@Environment(\.accessibilityReduceMotion)`.

### Batch G · Accessibility and copy

**CF-66 · P1 · Low-contrast text**
- Frames: unavailable rows in `237:73731`, `237:73983`, `237:74256` (light grey on white, two lines of reason); placeholders on `#EFEFEF`; red 11–12 pt error text on a pink field fill (`237:60884`, `238:16459`); green "已标好" 12 pt (`239:22803`); amber meta on white (`238:19113`); dark-grey `应用` label on dark (`244:16953`).
- Optimize: disabled text `#8C8C8C` minimum on white for the title, and the reason in `#6B6B6B` (it is information, not disabled content). Error text sits below the field on the card surface, never on the pink fill; error red `#C62828` or darker on white. Status words carry an icon as well as colour.
- Implement: Figma: bind to `mp/ink-3`, `mp/error`; move error text outside the fill; run the contrast check on the six frames. SwiftUI: semantic colours with increased-contrast variants.

**CF-67 · P1 · Dynamic Type would break the fixed layouts**
- Frames: two-column grids (`238:16389` 次数上限 | 奖励分; `243:23964`; `239:22606`), fixed 34 pt pills with long labels (`239:31923` "上传 16:9"), three-button bottom bar (`237:43689`), chips in rows (`237:64541`), option tiles.
- Optimize: at accessibility sizes the two-column grid stacks to one column; the bottom bar keeps the primary full width and moves 保存草稿 and 预览 into a "⋯" beside it; chips wrap; nothing truncates (labels wrap to two lines).
- Implement: Figma: add one `XXL` frame for the three key screens (创作页, gameplay editor first screen, node sheet) as proof. SwiftUI: `ViewThatFits` / `dynamicTypeSize` checks; `@ScaledMetric` for 44 pt minimums.

**CF-68 · P2 · Icon-only controls have no stated VoiceOver label**
- Frames: list/map toggle (`237:31646`), seam "＋", drag handles, "⋯", row ✕, upload slot ✕, AI send button (`239:24018`), share (`244:16367`).
- Optimize: add the label in the component description (e.g. handle: `调整顺序`; seam: `在这里插入`). Correct-answer controls announce `正确答案，已选中`.
- Implement: Figma component descriptions; SwiftUI `.accessibilityLabel`, `.accessibilityValue`, `.accessibilityAction`.

**CF-69 · P2 · Banned or inconsistent words**
- Frames and fixes: "确定" → `完成` (`239:2948`, `238:22593`, `238:22885`); alert title "发布前提示" → removed by CF-40; "确认删除" → the object question (`238:21479`, `239:27044`, `237:68146`); ellipses "加载中…", "保存中...", "正在加载更多合作者…", "正在查找历史起草记录…", "正在签名提交…" → no ellipsis (63 in C1, 31 in C2, 24 in C3; placeholders such as "写下这个主题的故事…" also lose it); "任务完成!" → `任务完成` (`238:25709`); "已添加: 小鹿" (half-width colon) → removed by CF-16; "去登录" (`237:59761`) versus "登录" (`246:8022`) → `登录`.
- Implement: Figma find-and-replace per page.

**CF-70 · P2 · Failure wording differs from the handbook**
- Frames: `237:59829` – `237:59899` ("玩法详情加载失败 / 网络暂时不可用，玩法详情未加载"), `243:26106`, `246:2850`, `247:17110`, `239:1632`.
- Optimize: handbook wording: title `<对象>没加载出来`, body `网络没连上，请重试`, button `重试` (not 重新加载). These are code strings; list them for the copy owner rather than changing silently (question Q-E).
- Implement: text edits once approved.

**CF-71 · P2 · Explanations that a design element can carry**
- Frames: 结果反馈's three numbered lines (`237:14274`, `237:43689`); "按正确顺序排好（从上到下就是答案）" (`239:19531`); "选项 · 点圆圈设为正确答案" (`239:23200`); "0 表示不限，最多 10 次" (`243:25232`); "10% 至 90%，默认 45%" (`239:22519`); "20–100，步长 5" (`238:12993`); G4's two grey disclaimer boxes (`243:25478` – `243:25853`).
- Optimize: remove; the control shows it (numbered handles, the leading correct control, slider end labels, CF-47's 不限 switch). 结果反馈 keeps one footnote: `玩家看到反馈后继续`.
- Implement: text deletions; slider min/max labels in `Editor/Slider`.

**CF-72 · P2 · Numerals and separators**
- Frames: "第1章 · 故事流" (`237:51424`) versus "第一章 · 钟楼与邮局" (`237:31646`); "票单名称1" (`238:14596`).
- Optimize: chapters always `第一章`; counters always Arabic with a space (`票种 1`).
- Implement: text edits.

**CF-73 · P2 · Cover placeholders**
- Frames: `238:15346`, `238:15290`, `239:20809` – `239:21126`, `238:16088` – `238:16196` (flat purple block) versus the route art elsewhere; category chips with a star icon here and a tag icon in `237:43689`.
- Optimize: one seeded cover (`route-city`) and one chip icon (tag) in every C2 frame.
- Implement: instance swaps from the kit board `236:14482`.

**CF-74 · P2 · Keyboard behaviour is not drawn**
- Frames: any frame with a focused field; only `237:65956` shows a keyboard.
- Optimize: state on the kit: number fields use the number pad with a `完成` accessory; `Return` moves to the next field in a list item and adds a new item on the last one (fast option entry, as in Reminders); the sheet's 完成 pill stays visible above the keyboard.
- Implement: annotation on `Editor/Field`. SwiftUI: `.submitLabel(.next)`, `.onSubmit`, `ToolbarItemGroup(placement: .keyboard)`.

**CF-75 · P2 · Popup-preview controls take a third of the screen**
- Frames: `238:11777` – `238:12156`.
- Optimize: 阶段 becomes a swipe pager with six dots (the popup itself swipes); 风格 and 配色 collapse into one bottom strip of swatches. The popup is the hero.
- Implement: Figma: redraw one frame and duplicate. SwiftUI: `TabView(.page)`. Motion: page slide 350 ms; popup re-plays its entrance on each page.

**CF-76 · P2 · Branch destinations as wrapping chips**
- Frames: `238:10642`, `238:10960`.
- Problem: "继续本章 / 结束本章 / 跳到第2章 / 跳到第3章" per branch does not scale past three chapters.
- Optimize: one pop-up button per branch (`去向：跳到第二章`).
- Implement: `Editor/PopUp`. SwiftUI: `Picker(.menu)`.

**CF-77 · P2 · Unsaved-changes handling on sheets is not drawn**
- Frames: every editing sheet; only `237:63388`, `238:19444`, `238:19557` (page level) exist.
- Optimize: one frame per sheet family showing ✕ or swipe-down with changes: action sheet `放弃修改` (red) / `继续编辑`.
- Implement: Figma: `Shared/Discard Dialog` using the iOS kit action sheet. SwiftUI: `.interactiveDismissDisabled(isDirty)` + `.confirmationDialog`.

**CF-78 · P2 · Draft conflict gives no way to compare**
- Frames: `237:21833`.
- Problem: "使用已保存版本 / 使用本地草稿" with no times and no default.
- Optimize: show both times and sizes (`本机 14:02 · 3 章` / `云端 13:40 · 2 章`), mark the newer one, and keep the other as a recoverable copy for 7 days so the choice is not destructive.
- Implement: Figma: action sheet with two detail rows. SwiftUI: `.confirmationDialog` with `message`.

---

## 5 · Batch order for the executor

| Batch | Issues | Scope | Depends on |
|---|---|---|---|
| A · Defects | CF-01 – CF-06 | Text and layout fixes on about 60 frames. No decisions. | — |
| B · One kit | CF-10 – CF-19 | Build the `Editor/*` components, then swap instances page by page. | A |
| C · C1 flows | CF-20 – CF-43 | Redraw 创作页, story flow, node / chapter / topic sheets, ticketing, publish. | B |
| D · C2 | CF-44 – CF-57 | Editor outline, option rows, numbers, picker grid, tools, rewards. | B |
| E · C3 | CF-58, CF-59, CF-61, CF-62 | Activity, AI, templates, external games. | B |
| F · Motion | CF-60, CF-63 – CF-65 | Prototype links, in-between frames, annotations. | C, D, E |
| G · A11y and copy | CF-66 – CF-78 | Contrast, Dynamic Type proofs, labels, wording. | C, D, E |

Batches C, D and E are independent of each other and can run in parallel once B is merged.

## 6 · Questions for the owner (the plan proceeds on the stated default)

| # | Question | Default used |
|---|---|---|
| Q-A | "先保存为我的玩法" is a label with no control in the mini-program. Remove it, or make it a switch? | Remove (CF-06). |
| Q-B | CF-26, CF-27, CF-32 and CF-44 regroup long mini-program forms into lists with pushed sub-pages or collapsed cards. Contents and order are kept; the layout is not 1:1. Accept? | Yes. If not, apply only the kit and density fixes and keep the single scroll. |
| Q-C | Is 奖励分 the same thing as 积分? | Yes; label it 奖励 with the suffix 积分 (CF-48). |
| Q-D | D20 难度: the owner reference draws a dropdown; the control rule says segmented for three short options. | Keep the owner's dropdown (CF-55). |
| Q-E | Load-failure strings differ from the handbook wording. Change the copy? | Yes, to the handbook wording (CF-70). |

## 7 · Severity count

P0 14 · P1 47 · P2 14 · total 75.
