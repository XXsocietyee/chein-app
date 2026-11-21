# Config revision · Batches A and B · execution log

Executor: Opus 5.5 · task `task_e960604679d3` · 2026-11-15 · file `0YyoybGnU1KG0657wdGCPX`
Plan: `review/full-config.md` (Fable). Canvas notes are yellow `note:<frameId>` boxes placed under the frame inside its section.

## Batch A · defects

| CF | Frames touched | Result |
|---|---|---|
| CF-01 | C1 `237:22192`, `237:51305` (alert title → 复制为新草稿, list in body), `241:1680` `241:2059` `241:2475` `241:2854` `249:41900` `249:42278` `249:42693` `249:43071` (蓝 · 晴空), `249:17076`, `249:33879` `249:34151` `249:34423` `249:34699` `249:34974`, `239:6450` (designer note card `239:6879` deleted); C3 `239:29100` `239:29304` `239:29508` `239:29710` (AIGC line → 内容由 AI 生成 · 备案号 …, sample number noted) | Done. Bracketed notes stripped; each moved to a canvas note. Screenshots: 237:51305, 239:6450 OK. |
| CF-02 | C3 `246:7461` `246:8088` `246:8549` `246:9012` (10 seed names, dates → 11月14日 23:21, 40 letter covers → MP asset images from `237:9072`); `246:2717` `246:2928` `246:2996` `246:3064` `246:7367` (城瘾官方); `247:16929` `247:16992` (外滩钟声快问快答); also `TEST 净销售分成` → 净销售分成 in `249:24688` `249:24757` `249:36244` `249:36313` | Done. Screenshot 246:7461 OK. |
| CF-03 | C3 `249:24548` `249:24653` (审核中 / 未通过 / 已通过, 相机, req id → 复制诊断信息; empty "驳回原因 —" lines replaced by —), `249:24688` `249:24757` `249:36244` `249:36313` (外部游戏 → game name, 绑定节点 → node name), `247:17370`, `248:3258` `248:3357` `248:3448` (链接导入), `248:3589`–`248:3864` (完成并提交结果; WebKit line → 当前设备暂不支持运行这个小游戏) | Done (text). Status still shown as text after the version; tag styling left to batch E (CF-61). |
| CF-04 | C3 `239:29100` `239:29508` `239:29913` `239:30054` (content into a `scroll (clip)` frame ending at 665, gradient bottom bar behind chips + composer; 29913/30054 scrolled so the two buttons sit above the chips); `241:6329` (9 tiles into `hero collage (clip)` 357×160 at y 170); C1 `241:3821` (toast 329 wide, wraps, 12 above the bottom bar); `242:2589` (error line wraps; pop-up option 仅禁止扣该值的任务 → 禁止扣值任务 also in `242:3169`); C2 every 每个结果单独回复 label (48, fill-width + height-auto) | Done. Screenshots 239:29913, 241:6329, 241:3821, 242:2589 OK. `236:15797` (old C2/Switch board) removed with the old kit in batch B. |
| CF-05 | C3 `241:6374` `241:6675` `243:1807` `243:1964` `243:2078` `243:2575` `243:2671` `243:2760` `243:2849` `243:2937` `243:3249`; C1 `249:32604` `249:32735` `249:32865` `249:32995` (under-sheet base) | Done. `OPT/Tab Bar (labelled)` swapped to Library `Tab Bar / Player` · `Selected=发布` (icon + label). Screenshot 243:1807 OK. |
| CF-06 | C3 `237:59532` (活动地点 placeholder); C2 56 frames: lone 先保存为我的玩法 row deleted — `237:43424` `237:43565` `237:43689` `237:44143` `237:44507` `237:44871` `237:45235` `237:46330` `237:46789` `237:47181` `237:47587` `237:47990` `237:48454` `237:53447` `237:53908` `237:54277` `237:54742` `237:55116` `237:55565` `237:55926` `237:56530` `237:56966` `237:57337` `237:57453` `237:57539` `237:58011` `237:59972` `237:60429` `237:60884` `237:61028` `237:61483` `237:61597` `237:62464` `237:62926` `237:63388` `237:63852` `237:71933` `237:72185` `237:72437` `237:72643` `237:72910` `237:73177` `237:73454` `237:73731` `237:73983` `237:74256` `239:20236` `239:20526` `239:28271` `239:28477` `239:28627` `239:28766` `239:30205` `239:30547` `249:36634` `249:37089` | Done. Each frame carries a note "Owner Q-A default". |

## Batch B · one kit

Library page `01 Components` (6:3), section **`276:295` "Editor · 编辑器组件 (CF-10–19 · config revision)"** at x 12000. Explicit modes on the section: Color MP-Light, Spacing MP, Radius MP. All fills, strokes and radii are bound to Color / Radius variables (ink, ink-2, ink-3, ink-inv, surface, bg, surface-3, sep, sep-strong, bad, cta, cta-ink, skel, mp/input-filled, mp/placeholder, mp/disabled, mp/btn-secondary, mp/sheet-handle, mp/switch-on, mp/radius-md). Text uses the MP/* text styles (body, body-strong, label, card-title, button, button-secondary). Each component's description carries its rule. Ledger: `revise/kit-state.json`.

| Component | Node | Variants · properties |
|---|---|---|
| Editor/Field | `276:638` | Kind Line/Area/Number × State Empty/Filled/Focus/Error/Disabled × Surface OnCard/OnGrey (30) · label, showLabel, required, value, suffix, showSuffix, help, showHelp, counter, showCounter |
| Editor/PopUp | `276:739` | State Empty/Filled/Open/Error/Disabled × Surface (10) · label, showLabel, required, value, help, showHelp |
| Editor/Switch | `276:302` | State On/Off · 51×31 native |
| Editor/Switch Row | `278:311` | label, sub, showSub, nested switch exposed |
| Editor/Row (picker cell) | `278:407` | Accessory Chevron/PopUp/Switch/Stepper/None · label, value, showValue, showIcon, icon (instance swap), showDot, showDivider |
| Editor/Option Row | `278:435` | Style List/Card × Selected · label, sub, showSub |
| Editor/Stepper | `278:345` | State Default/AtMin/AtMax · value · 32 visual in 44 hit |
| Editor/List Item | `278:458` | State Default/Lifted · title, meta, showMeta, showMore (⋯), showHandle (trailing) |
| Editor/Add Row | `278:467` | State Default/Limit · label, count, showCount |
| Editor/Handle | `276:307` | 44×44 hit, trailing |
| Editor/Sheet Header | `280:410` | Leading Close/Back/None × Trailing Done/None · title, eyebrow, showEyebrow, done, showGrabber |
| Editor/Sheet | `280:465` | Detent Fit/Medium/Large · header exposed · content overflow vertical only at Large · spring values in description |
| Editor/Toast | `280:479` | Icon none/success/info · text · ink/ink-inv so it inverts on dark pages |
| Editor/State | `280:527` | Kind Loading/Empty/Error/SignedOut/NoPermission · showBody, showAction (copy edited per instance) |
| Editor/Nav Bar | `280:585` | Trailing None/More/Action · title, action · 393×100 incl. status bar |
| Editor/Bottom Bar | `280:593` | left, middle, primary, showLeft, showMiddle |

Deviations from the plan, by its own rules: Field Surface is OnCard / OnGrey (section 2 gives sheet and panel the same white field; keeps the set at 30 variants). Toast has no Theme variant (tokens invert it on dark pages, verified on `243:3249`). The plan's token names `mp/input`, `mp/input-strong`, `mp/surface`, `mp/page` do not exist; the nearest existing ones are used (`mp/input-filled` #EFEFEF, `surface` #FFF, `bg` #F3F4F4).

| CF | What changed (frames / counts) | Result |
|---|---|---|
| CF-10 | C2: 101 grey `cg-gcfg panel`s inside white cards flattened (no fill, no side padding), so plain fields sit OnCard. Swapped by script with text and state carried over: C2/Input 1059, C2/Dropdown 416, TE/Field 411, TE/Textarea 86 → Editor/Field or Editor/PopUp, Surface picked from the nearest filled ancestor (1331 OnCard, 641 OnGrey). TE/Switch Row 151 → Editor/Switch Row, TE/List Item Header 106 → Editor/List Item, TE/Add Row 106 → Editor/Add Row, TE/Editor Bottom Bar 109 → Editor/Bottom Bar, C2/Drag Handle 345 → Editor/Handle. Old kit boards `236:14482` (TE/*) and `236:15762` (C2/*) deleted; 0 instances of the old kits remain on C2. The TE board also held 7 image swatches; they were rebuilt as section `284:63794` "A2 · 本页图片素材" from the 12 images in use on the page. | Done for C2. Screenshots `237:14385`, `237:43806`, `237:64911` OK. **Left:** C1 and C3 fields are raw frames (C1 has 153 `input` frames), not kit instances; they move to Editor/Field when batches C and E redraw those screens. |
| CF-11 | C2: TE/Sheet Header 49 + C2/Sheet Header 10 swapped; raw headers in `238:15554` `238:15744`* `238:15880` `238:15942` `238:16017`. C1: 217 raw headers (close/back + 完成 + title frame; ✕ + spacer; ‹ + title + text 完成; 取消 + title + 完成) → Editor/Sheet Header with eyebrow/title carried over, grabber off on fit-only sheets; title-left headers `249:32604` `249:32735` `249:32865`; pattern g `241:3540` `241:3821` (bottom 完成 moved into the header pill); result sheets `249:19029` `249:19340` `249:19653` `249:19962` `249:20272` `249:20582` lose the top ✕. C3: 22 title-left/✕-right headers (`239:625` `239:771`* `239:919`* `239:1084`* `239:1210`* `239:1333`* `239:1509`* `239:1632`* `239:1749`* `239:21290`–`239:22084` `239:31173` `239:31330` `239:31468` `243:2078` `243:26185` `243:26341` `243:26503`). (* = the bottom 确定/完成 button was removed because the header now carries 完成.) | Done. Screenshots `239:6450`, `239:24873`, `238:15744`, `239:919` OK. Not converted (different structure, review in C): C1 `238:22851` `238:23143` `239:3206` `249:17994`; C2 result sheets `239:20864` `239:20929` `239:20999` have no header by design. |
| CF-12 | — | **Not done.** It is a redraw (one sheet edge, pushed sub-pages) of C1 frames; the kit supports it (Sheet Header Leading=Back, Editor/Sheet). Hand to batch C. |
| CF-13 | `Editor/Sheet` with `Detent` property built. Detent + spring annotations (blue `note:<id>:detent`) on every sheet frame in section 3.3: C1 92, C2 63, C3 31 frames. | Annotations done. **Left:** the extra `Large` companion frames for two-detent sheets were not drawn. |
| CF-14 | Editor/Switch 51×31 everywhere: C2 627 instances (TE/Switch 154 + C2/Switch 473), C1 177 raw `toggle/on|off` frames, C3 1 raw switch (`248:3864`). | Done. One switch component in C1–C3. |
| CF-15 | 44×44 hit areas are built into Handle, Stepper buttons, Sheet Header ✕/‹, Nav back/⋯, List Item ⋯; rows have min height 44/50. Every C2 drag handle is now 44. | Done at component level. **Left:** raw C1 controls (10 px seam ＋, chips, verb pills) are redrawn in batch C (CF-23, CF-27). |
| CF-16 | Editor/Toast replaces every toast: TE/Toast 15 on C2; raw toasts C1 19 frames, C2 10, C3 12; all bottom-anchored 12 above the bottom bar or tab bar (C1/C2/C3 frames listed in the contact sheet). | Done (one component). **Left:** the validation and limit toasts named in CF-16 still exist as toasts; turning them into inline states is a per-screen redraw (batches C/D/E). |
| CF-17 | Bottom Bar component documents "never disabled". | **Not done:** the six 发布活动 frames, `249:16773` and `237:63852` are redraws (batch E / C). |
| CF-18 | Editor/State built; C3 K/State 30 instances swapped with copy kept (`237:58981` `237:59132` `237:59207` `237:59281` `237:59355` `239:1632` `239:1749` `239:21619` `239:21768` `239:23979` `243:2671` `243:2760` `243:2849` `243:2937` `243:26106` `243:26145` `246:2637` `246:2676` `246:2850` `246:2889` `246:7932` `246:7989` `246:8022` `246:8055` `247:17110` `247:17152` `247:17291` `247:17329` `248:3693` `248:3734`). | Done for C3. **Left:** C1 modal loading cards (`237:21650` `237:21681` `249:17706`) and C2 top-pinned states (`237:59761`–`237:59934`) need redraws. |
| CF-19 | Editor/Nav Bar swapped for MP/Nav Bar: C2 all sections 180 (编辑玩法模板 ×109, 玩家视角预览 ×6, untitled ×65 under sheets), C3 发布活动 + AI 46 + 20 (快速配置 → AI 快速创建), C1 B1/B2/B8 33; stray `back-circle` overlays removed. | Done. **Left:** 发布活动 and C1 B2 still have a large in-content title; the nav title stays empty until batches C/E remove it (avoids a duplicate title). |

## Owner question defaults used
- Q-A (CF-06): applied on 56 C2 frames, each with a "Owner Q-A default" note. Q-B to Q-E affect batches C/D/G only; no frame was changed for them here.
