# Config revision · Batches F and G · execution log

Executor: Opus 5.5 · task `task_c5937d54172e` · 2026-11-16 · file `0YyoybGnU1KG0657wdGCPX` · pages C1 `237:14642`, C2 `235:178`, C3 `235:13237`
Plan: `review/full-config.md` sections 2, 3, batches F (CF-60, CF-63–65) and G (CF-66–78), section 6 defaults (Q-E yes).
Budget: 50 Figma MCP calls today, stop at 45.

## Figma call count
| # | Tool | Purpose | Result |
|---|---|---|---|
| 1 | create_session | session | OK |
| 2 | use_figma | C1 discovery: sections, probe of every frame named in F/G, copy scan | C1 already clean for CF-69 (0 ellipsis, 0 确定, 0 确认删除), 201 reactions, 341 annotations |
| 3 | use_figma | C2 discovery | 34 "第 1 组…", 去登录 ×1, 任务完成! ×1, 19 failure strings, typo 一钟油 ×3 |
| 4 | use_figma | C3 discovery | 19 trailing ellipses, 去登录 ×2, 39 failure strings |
| 5 | use_figma | C1 read: tokens, contrast audit, popup-preview + drag structure | Existing annotations are uncategorised frame descriptions; the 201 reactions are inside components (segmented/chips): **no screen-to-screen prototype exists yet**. Contrast: 159 hits are variable-bound segmented labels (raw-colour false positives); real: 8 `系统键盘` labels #6b6b6b on #e4e4e4 |
| 6 | use_figma | C2 read: contrast, A12 structure, drag frames | A12.3/3b/3c lack Editor/Nav Bar (exit ‹ only). Lifted rows drawn 3 ways, no drop line on C2. Real contrast misses: `238:25705` red on dark, `241:21009` blue link |
| 7 | use_figma | C3 read | Real contrast misses: dark-sheet reds `#e5484d` on #2c2c2e/#2a2a2c/#4d4d4d (16), white on `#e5484d` swipe 删除, placeholder `243:26338` |
| 8 | use_figma | Library kit (6:3) | **New `Editor/Drop Line` `330:911`** (section 276:295). `Editor/List Item` State=Lifted `278:457` shadow set to spec (0 8 24 /.14, was 0 6 18). F/G motion + VoiceOver + keyboard notes appended to 29 component descriptions; Development annotation (CF-74 keyboard) on Editor/Field. No tag icon and no slider component exist in the Library |
| 9 | use_figma | C1 page pass | Failed: `initialVelocity` not accepted in a reaction spring (fixed) |
| 10 | use_figma | C1 page pass retry | Failed: duplicate nodeIds in flowStartingPoints (fixed: keep existing flows) |
| 11 | use_figma | C1 page pass (final) | OK: 6 popup previews redrawn, 171 frames annotated, 8 links, 2 new flows |
| 12 | get_screenshot | `238:11999` | OK (strip scrolls; the selected swatch can sit at the cut edge) |
| 13 | use_figma | C2 page pass | OK: A12 nav on 3/3b/3c, in-betweens `334:23538` `334:23570` `334:23610`, 13 links, 5 drag frames unified + drop lines, 269 frames annotated, 46 copy edits, 10 CF-71 edits. Two copy over-reaches found (fixed in 14): 内容已保留 lost on 3 save-failure lines; 选项加载失败 became a body line |
| 14 | use_figma | C1 F/G section `335:27038` | OK: drop lines `335:27039` `335:27042` `335:27045` `335:27048`; Moved `335:27051`; XXL `335:27195` `335:27321`; CF-77 `335:27521` `335:27601` `335:27686` `335:27794`. XXL scaled only 4 / 9 texts (fix below) |
| 15 | use_figma | C2 F/G section `335:52094` + fixes | OK: copy corrections, pressed tile `334:23561`, Moved `335:52095`, links, XXL `335:52163` (19 texts), CF-77 `335:52447` `335:52576` |
| 16 | use_figma | C3 page pass + F/G section `336:6055` | OK: 35 copy edits, 33 contrast fixes, 157 frames annotated, 4 VoiceOver notes, error-jump link `290:22497 → 237:59532`, CF-77 `336:6057` |
| 17 | use_figma | C1 XXL rebuild | Still only 4 / 9 texts reached: a fresh clone's instance sublayers are not enumerable in the same script |
| 18 | get_screenshot | C1 F/G section | Found: XXL instance texts unscaled; CF-77 dialogs mid-frame on tall clones; Moved card position unclear |
| 19 | use_figma | C1 fixes | CF-77 frames cropped to 852 with the dialog at the bottom; Moved card re-inserted in the list; XXL texts scaled (but double-scaled 4 top-level texts → rebuilt in 20) |
| 20 | use_figma | C1 XXL clean rebuild | `338:28103`, `338:28228` (top-level texts) |
| 21 | use_figma | C2 XXL clean rebuild + CF-77 crop | `338:52458`; `335:52447` `335:52576` cropped |
| 22 | use_figma | C1 XXL instance texts | 24 + 47 instance texts ×1.35 |
| 23 | use_figma | C2 XXL instance texts | 56 instance texts ×1.35 (this crop has no bottom bar) |
| 24 | get_screenshot | C1 F/G section | OK |
| 25 | get_screenshot | C2 A12 section | Found: the three in-between frames were created on the page root (clone of a section child) |
| 26 | get_screenshot | C2 F/G section | OK |
| 27 | use_figma | read: in-between frame parents | Confirmed page-root placement |
| 28 | use_figma | C2: in-betweens moved into A12 `238:25434` at x 3158 / 4184 / 6749 | OK; 0 stray page-root nodes on C2 |
| 29 | use_figma | C2 inline screenshots | P1 / P2 / P3 and `239:19592` OK |
| 30 | use_figma | C1 audit + screenshots | 0 stray page-root nodes; 14 sections in order (F/G last) |
| 31 | use_figma | C3 audit + screenshots | 0 stray page-root nodes; CF-77 `336:6057`, swipe-delete and dark error reds OK |
| 32 | use_figma | C2 CF-73 check | Covers in `238:15346` `239:20809` `238:16088` are already route images (earlier batch). Chip icon not swapped (see Left) |
| 33 | use_figma | C1 drop lines moved to the uncovered slot edge, brought to front | OK (screenshot `237:31986`) |
| 34 | use_figma | C2 switch-reveal prototype | `237:14297` (Switch Row in `237:14274`) → `237:14385`, Smart Animate 220 ms; flow start added |

**Total today: 34 Figma MCP calls (budget 50, stop line 45).**

## Results by CF

| CF | Nodes | Result |
|---|---|---|
| CF-60 reorder | Kit: **new `Editor/Drop Line` `330:911`** (section 276:295); `Editor/List Item` State=Lifted `278:457` shadow → 0 8 24 /.14 (was 0 6 18), full lift/move/drop/cancel spec in its description. C1 drop lines `335:27039` (`237:31986`) `335:27042` (`237:67490`) `335:27045` (`237:67711`) `335:27048` (`239:6450`). C2 lifted rows unified to the one shadow, black borders removed, drop line added above the landing slot: `239:19634` (`239:19592`), `241:21657` (`241:21572`), `237:33800` (`237:33756`), `237:42237` (`237:42181`), `237:50911` (`237:50816`). Moved frames: C1 `335:27051` (B2.3c), C2 `335:52095` (A4.11c). Prototype Rest → Lifted → Moved: C1 `291:42207` (chapter card in `237:31646`, mouse-down 180 ms) → `237:31986` → (drag, spring 300/26) `335:27051`; C2 `239:19573` → `239:19592` → `335:52095` | **Done.** Scale 1.03 is in the spec and the component description; it is not drawn on the C2 rows (they sit in auto-layout panels, scaling would reflow them). |
| CF-63 player preview | C2 A12 `238:25434`: Editor/Nav Bar added to A12.3 `238:25538`, 3b `238:25573`, 3c `238:25615` (exit ‹ removed, content moved down 48). 任务完成! → 任务完成 (`238:25757`). **In-between frames** `334:23538` 答题按下 (tile `334:23561` at .97), `334:23570` 对勾绘制中 (overlay +24 pt, 55 %, check 40 %), `334:23610` 奖章放大中 (medal `334:23637` at .6, 50 %); section widened, later frames shifted right. Prototype: 1 → 2 → 3 (tap or swipe, push 350 ms ease-out .22,.61,.36,1) → P1 (80 ms) → P2 (after 80 ms, 220 ms) → 3b (spring 224/24 ≈ response .42 damping .8) → 4 → P3 → 5 (stamp curve .2,1.4,.5,1, 600 ms); 3c → back to 3; 3d → 4; 5 → 1. Motion + haptic annotations on every A12 frame | **Done.** |
| CF-64 motion | Native Figma annotations, category **Interaction**, label `Motion · 动效与触感 (CF-64)`, one per screen frame, rows chosen from the frame's own components (press, sheet §3, push, switch reveal, pop-up, select, add, remove, reorder, inline error, jump to error, counter, upload, slider, stepper, save chip, result, leave, compass, map pin, toast, loading, seam): **C1 171, C2 269 (+3 in-betweens), C3 157 frames.** C3 frames with Step Bar / AI draft / install / swipe-delete get their specific rows (CF-58, CF-59, CF-62). Kit: motion + haptics appended to 29 Editor/* component descriptions. Prototypes for the eight most-seen: **sheet detent** `249:40292` ⇄ `239:24873` (drag, spring 290/27/1); **push** row `299:15476` in `239:31923` → `241:1680` (push 350 ms), header `300:20171` → Back; **switch reveal** `237:14297` → `237:14385`; **add row** `305:38635` (`238:10642`) → `238:10960`; **reorder** (CF-60 above); **seam expand** `291:71362` (`237:65700`) → `237:51859`; **error jump** bottom bar `290:22497` (`237:59431`) → `237:59532`; **preview step** (CF-63). Flow starting points named `F · …` added where the node had none | **Done.** |
| CF-65 interruption / Reduce Motion | Closing line of every Motion annotation; Editor/Sheet, Toast, State, Field descriptions | **Done.** |
| CF-66 contrast | C1: 8 `系统键盘` labels → ink-2. C2: `238:25705` wrong-answer red on dark → #FF6B6B; `241:21009` 添加属性 blue → ink; 已标好 (×3 in `239:22803`) gets a check icon (`icon/check · status`, ok colour). C3: 33 fixes — dark-sheet error reds → #FF6B6B (import sheet errors, 删除节点玩法, 屏蔽, 删除游戏, 未通过), action-sheet grey #4d4d4d → #2c2c2e, swipe 删除 background → `bad` #b3261e (`322:18253`, `322:18304`), placeholder `243:26338` → #B0B0B0 | **Done** for every real failure the audit found. The plan's named rows `237:73731` `237:73983` `237:74256` (unavailable rows), `238:19113` (amber), `244:16953` (应用) already passed after batches D/E; the other audit hits were variable-bound paints read at their raw colour (false positives, e.g. segmented labels, 试看). |
| CF-67 Dynamic Type | F/G sections: C1 `338:28103` XXL 创作页, `338:28228` XXL 节点 sheet; C2 `338:52458` XXL 玩法编辑器首屏. All text ×1.35 (xxxLarge), status bar excluded, truncation off, chip rows wrap, bottom bar → 「⋯」 + full-width primary (C1). Accessibility annotation explains the accessibility-size rules | **Done** (proof frames). The two-column grid stack rule found no matching layout in these three screens; it is stated in the annotation and Bottom Bar description. |
| CF-68 VoiceOver | Kit descriptions (Handle 调整顺序, List Item ⋯ 更多操作, Sheet Header 关闭/返回/完成, Nav Bar, Stepper 减少/增加, Answer Option 正确答案，已选中, Tool Chip, Swatch, Save Chip …) + C1 page components `290:23460` Seam 在这里插入, `290:23403`, `290:23581`, `290:23583`, `290:23587`, `290:23504`, `290:23405`. Accessibility annotations on nodes: segmented `291:42152` (`237:31646`), seams `291:77950` `291:71362` `291:71129`, handles `291:54766` `294:12082`, AI send `239:24138`, share `244:16396`, library ＋ `291:77751` and ⋯ `291:77753` | **Done.** |
| CF-69 words | C1 already clean (0 hits). C2: 34+ `第 1 组…` → `第 1 组`, 去登录 → 登录. C3: 去登录 ×2 → 登录, 15 trailing ellipses removed (加载中/placeholder/正在签名提交...). 确定 / 确认删除: 0 left on all three pages | **Done.** Kept on purpose: 6 import-error templates whose `…` stands for a variable value (`包含不允许的文件类型：…`, `游戏包体积超限（…）` etc.) and a lone `…` glyph `246:2589`. |
| CF-70 failure wording (Q-E yes) | C2 + C3 Editor/State and inline errors: `<对象>加载失败` → `<对象>没加载出来`; body → `网络没连上，请重试`; 重新加载 → 重试; save failures keep their meaning: `网络没连上，内容已保留，请重试` (`237:62463` `237:62925` `237:63387`); single-line inline: `选项没加载出来，请重试`, `精选示例没加载出来，请重试` | **Done** (C1 was done in batch C). |
| CF-71 explanations | `20–100，步长 5` removed ×6 (A11.3 frames), `（从上到下就是答案）` stripped ×4 (`239:19542` `239:19603` `239:20352` `239:20613`). 结果反馈 numbered lines: none left in `237:14274` / `237:43689` (removed earlier) | **Partly.** No `Editor/Slider` exists in the kit, so slider min/max end labels were not added. |
| CF-72 numerals | `249:35830` 第 1 章 / 共 3 章 → 第一章 · 共三章. No `第1章` / `票单名称1` left on any page | **Done.** |
| CF-73 covers | Covers in the named frames are already route images (`cover 1:1` IMAGE) | **Covers done earlier; chip icon not changed:** the Library icon set has no tag glyph and `237:43689` has no tag instance to copy. |
| CF-74 keyboard | Development annotation + description on `Editor/Field` `276:638`; Development annotations on `239:33463`, `239:33587` | **Done.** |
| CF-75 popup previews | `238:11777` `238:11850` `238:11923` `238:11999` `238:12075` `238:12156`: the 311 pt control panel is removed; popup card centred as the hero; 6 page dots; one bottom strip (style pills 星尘/纸本/末世/夜城 + 5 colour swatches, 44 pt targets, scrolls sideways). Pages linked by drag (push 350 ms). `249:35825` 章节闸: copy + motion annotation | **Done.** Note: on a 393 screen the strip scrolls, so the selected swatch can sit at the cut edge. |
| CF-76 branch destinations | `238:10642` `238:10960` | Done in batch C (Editor/PopUp per branch). Not touched. |
| CF-77 unsaved changes | Editor/Confirm Dialog (Destructive): 要放弃这次修改吗？ / 刚才的改动还没保存。 / 放弃修改 / 继续编辑 on a 20 % scrim, one per sheet family: C1 `335:27521` 节点编辑, `335:27601` 章节设置, `335:27686` 票种编辑器, `335:27794` 文本编辑; C2 `335:52447` 列表工具 sheet, `335:52576` 扫完回复; C3 `336:6057` 导入外部游戏. Each source sheet's header links to its frame | **Done.** |
| CF-78 draft conflict | `237:21833` | Done in batch C. Not touched. |

## New sections (one per page, last in order)
- C1 `335:27038` **F/G · 动效原型与无障碍证明 (config batches F, G)**: Moved `335:27051`, XXL `338:28103` `338:28228`, CF-77 ×4.
- C2 `335:52094`: Moved `335:52095`, XXL `338:52458`, CF-77 ×2.
- C3 `336:6055`: CF-77 `336:6057`.
Each frame has a label above it. 0 stray page-root nodes on C1, C2, C3 (checked in calls 28, 30, 31).

## Left / for the owner
- CF-71: no `Editor/Slider` in the kit; slider end labels need that component first.
- CF-73: no tag icon in the Library icon set; chip icons unchanged.
- C2 copy owner: 倒计时 description `一钟油，时间走它就退` (`307:29668` `307:29778` `307:29953`) is a source typo; the intended wording is unknown, so it was left as is.
- Prototype detail: the reorder "lift" uses Mouse down 180 ms (Figma has no long-press trigger); C2 lifted rows are not drawn at 1.03 scale (spec in annotations).
- Batch-B note still holds: under-sheet base copies on C2 use the older editor header.

## Method notes (for the next executor)
- `clone()` of a frame inside a section put the clone on the **page root** here; always `section.appendChild(clone)` afterwards.
- In a fresh clone, instance sublayers are not returned by `findAll` in the same script; scale them in a second call (ids start with `I`).
- Reaction springs reject `initialVelocity`; `flowStartingPoints` rejects duplicate node ids.
- Scripts: `revise/fg/` (common.js, c1body.js, c2body.js, c3body.js, proof.js, xxl2.js).
