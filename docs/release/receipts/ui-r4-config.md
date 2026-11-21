# ui/r4-config · screens r4 config worker receipt (2026-11-21)

Scope (shared brief `docs/briefs/screens-r4.md` on `design/handoff-r2`): the gameplay config and publish frames
`238:16749`, `238:25435`, `237:71933`, `239:24018`, `247:17370`, `243:1964`, `243:3249` with the Editor kit; the
题目图片 / 题目音频 pickers instead of URL fields; drag-to-reorder; delete with an undo toast; the external-game
price hidden.

Base: `origin/ui/h-code-r3-ops` c239789ec (C1 motion set + `CYInPlaceResult`, C2). Branch `ui/r4-config`.
Design source: local copies of `design/handoff-r2` only (`revise/skill-r2/js/_handoff.json`, `review/skill-r2.md`
§2.4 SR2-19 / SR2-20, `review/full-config.md` CF-46 / CF-51 / CF-59 / CF-60 / CF-61 / CF-62 / CF-63 / CF-68,
`revise/cfg-E.md`, `review/xrefs-1.md` Adopt 12, `revise/xrefs-1/js/PAT.js` row 14, `revise/fg/c2body.js`).
Type and chrome: `origin/ui/consist-1:docs/design/type-and-chrome.md` (CYTypography tokens only; no raw
`.system(size:)` in new code; pushed pages and sheets keep the system back / close).

**No Swift toolchain in the cloud.** Nothing here was compiled, run or screenshotted. Every type, initializer and
modifier was checked against existing code in the repo (cited per item below); the local integrator must build,
run the checklist at the end and shoot the screens. Status words therefore mean: **done** = implemented to the
frame's spec in code, awaiting the local build and shots; **partial** = what is left is named; **left** = not done.

## Commits

| Commit | What |
|---|---|
| `179ebbd3c` | 238:16749 option rows (drag with release velocity, ⋯, undo delete), 237:71933 选择玩法 sheet, 题目图片 / 题目音频 pickers |
| `818e20bd9` | 247:17370 小游戏库 header menus, quiet rows, delete with undo, neutral import/confirm chrome, price hidden |
| `6edc487a0` | 238:25435 玩家视角预览 five-step pager |
| `a6ef3b54e` | 239:24018 AI 快速创建 停止生成, skeleton draft card, in-place rewrite; ratchet fix (`includesMedia` order) |
| `d216aaf73` | 243:1964 template plaza default art for no-cover themes, monochrome meta |
| `9d79903eb` | shrinking staggers (story beats, AI stations) |

## Frames

| Frame | View | Status | Files | Notes / what is left |
|---|---|---|---|---|
| `238:16749` QuestionCardView (CF-46, CF-60, CF-74) | `TemplateChoiceOptionRowsEditor` | **done** | `App/TemplateChoiceOptionRowsEditor.swift`, `App/ConfigR4Kit.swift` (`EditorDragReorderStack`, `EditorDragReorderMotion`, `configUndoCenter`), `Core/TemplateChoiceOptionRows.swift` (`.move`: text, media and the correct answer follow the row), `Tests/CoreTests/TemplateChoiceOptionRowsTests.swift` | 52 pt rows, correct-answer circle in front, ⋯ (上移 / 下移 / 删除) and a trailing handle. Long-press 180 ms lifts (1.03, float shadow, `.impact(.medium)`); neighbours slide on `CYMotion.standard`; a 2 pt drop line marks the slot (`.selection` per slot); release settles on the CF-60 spring (stiffness 300, damping 26) **seeded with the finger's release velocity**, `.impact(.light)`. Delete is immediate with C2's 已删除「X」 撤销 toast + `UndoManager`. Return moves to the next row / adds one. |
| `237:71933` GameplayPickerSheet (CF-51, SR2-19) | `TemplateGameplayPickerSheet` | **done** | `App/TemplateGameplayPickerSheet.swift`, `App/TemplateAuthoringView.swift` (完成方式 row opens it) | Kit `EditorGameplayPickerGrid` now has its call site: category chips, two-column tiles, one monochrome SF Symbol per gameplay, selection = neutral 1.5 pt border + check (`.selection`). **One** confirm: 完成 in the header, disabled until a tile is picked; ✕ leading; no bottom bar. Locked (advanced games on): every type in the unavailable group with the reason once. |
| verify-r1 2.10 题目图片 / 题目音频 | `TemplateQuestionMediaFields` | **done** (image) / **partial** (audio) | `App/TemplateQuestionMediaPickers.swift`, `App/TemplateAuthoringDetailForms.swift` (`includesMedia: false` in the editor; owner inspection keeps the read-only rows), `Core/ActivityCoverAuthoring.swift` (`.templateQuestionImage` target) | Image uses the cover's picker → crop → upload owner with its own target. Audio: picks a local file and checks it, then says it is not uploaded (there is no audio upload pipeline on the backend; TEST has no media storage). 清空 in each tile's ⋯ with undo. |
| `247:17370` MiniGameLibraryView (CF-62, CF-11) | `ExternalGameImportView` | **done** | `App/ExternalGameImportView.swift`, `App/ExternalGameReviewScreens.swift`, 2 UI tests' identifiers | Title 小游戏库; ＋ pull-down (链接 / 扫码 / 文件) and ⋯ (提交审核 / 我的提交) as 44 pt circles; rows = name + v·分级 (no package id), 运行 secondary pill, ⋯ / context menu 举报 · 删除游戏. Delete immediate with undo toast; the package is removed when the toast window closes. Import sheet and permission confirm in the neutral tint; confirm is the pinned white pill; permissions as icon rows. |
| Owner Q6 external-game price hidden | `ExternalGameReviewScreens` | **done** | `App/ExternalGameReviewScreens.swift` | The 付费购买（测试） pricing option only appears when the TEST money switch is on (or the game is already PAID); the catalog label shows 付费（测试） with no ¥ unless `moneyOn`. 积分 stays the only currency in copy. |
| `238:25435` PlayerPreviewView (CF-63) | `TemplatePlayerPreviewPager` in `TemplateAuthoringPreviewView` | **done** | `App/TemplatePlayerPreviewPager.swift` (new, in pbxproj), `App/TemplateAuthoringView.swift`, `Resources/ConfigR4.xcstrings` | Nav: inline 玩家视角预览 + the sheet's ✕ on all five steps. Five-segment progress (tappable, fills on `CYMotion.standard`); `TabView(.page)` so swipe pages, a tap on the content moves on. 到达: card rises 24 pt + fades on `CYMotion.moment` (.42/.8). 剧情: beats fade up 12 pt (120 ms then shrinking gaps). 任务 (选择题): tile presses (.97 via `cyPressable`), then correct → `success` border + check (`.success`) or wrong → shake 3 × 6 pt in 240 ms (`.error`), then moves to 成功 / 失败; other gameplays get 看完成 / 看失败. 成功: **任务完成** (no mark), the check draws, the medal (if any) lands on `CYMotion.seal` with `.impactHeavy` at the peak. 失败: the card shakes once (`.error`), 再试一次 returns to 任务. Reduce Motion: fades only, haptics kept. The per-gameplay rehearsal entries stay below (no feature hidden). Not done: the reward "flying to its slot" (no slot exists in the sheet; the medal lands in place). |
| `239:24018` AIQuickCreateView (CF-59, CF-68, xrefs Adopt 12) | `PublishingAIDraftSheet` | **done** | `App/PublishingAIDraftSheet.swift`, `Core/PublishingAIDraftFlow.swift` (`stop()`), `Tests/CoreTests/PublishingAIDraftFlowTests.swift` (`testStopRetiresInFlightDraftAndKeepsIdea`) | The prompt already led (r1). Now: while generating, the send pill becomes **停止生成** in the same slot (`stop.fill`, label cross-fades); `stop()` retires the request by its generation stamp and keeps the idea, candidate and quota. The draft card appears at once as a skeleton (`CYSkeleton(.card)`) with 正在生成. Generated fields rewrite in place with `blurReplace` 250 ms at 0 / 40 / 70 / 90 ms from the top (`CYMotion.Stagger.rewrite`); stations follow (shrinking gaps, rise 8 pt); a new generation retargets. `.success` once when a draft lands. Reduce Motion: cross-fade. Not done: the route line drawing on the card (the card has no route line), and moving the composer into `safeAreaInset(.bottom)` (kept at the top of the Form, where r1 placed it; the brief's owner layout is prompt-first). |
| `243:1964` TemplatePlazaView (CF-61, SR2-20) | `DiscoveryTemplateBrowserView` | **partial** | `App/DiscoveryTemplateBrowserView.swift`, `App/DiscoveryTemplateBrowserView+Port.swift`, `App/DiscoveryComponents.swift` | No-cover themes show the default art seeded by the name (`CYCoverArt`), not the 图片暂不可用 glyph tile (kept for a cover that fails to load). 实验预览 / 实验 stay as tertiary text with no flask glyph (owner: never hide; SR2-20 monochrome). The shelf switch is the native segmented control (no colour icons; accepted as iOS-native instead of `Player/Chip`). No clock heading and no floating bell exist in this view. Left: the 发布 tab bar (CF-05) is the app's `TabView`, owned by the tabs/continuity branch; `DiscoveryHomeView` thumbs (other area) still pass no seed and get the default art seeded by the placeholder name. |
| `243:3249` TemplatePlazaView · toast (Player/Toast, toast spring) | `cyToast(verbatimMessage:)` | **partial** | — | The view's toast is `CYToastPill`, coloured from `CYColor` (domain-resolved), so on the dark player page it is the dark Player toast, not the white Editor one. Left: this view never sets `toastMessage` (no trigger to shoot), and the shared toast enters on easeOut 0.2 s, not `CYMotion.sheet`; changing it is a DesignSystem-wide change, left to the DS owner. |

## Shared changes (minimal, noted)

- **No DesignSystem file edited.**
- Core: `PublishingAIDraftFlow.stop()` (new public method, + Core test); `TemplateChoiceOptionRows.move` (+ Core test);
  `ActivityCoverTarget.templateQuestionImage`.
- `TemplateAuthoringQAFields` declares `includesMedia` before `includesHints` so the existing legacy-hint contract's
  call-site marker (`includesHints: false, includesChoiceOptions: false)`) still matches.
- Strings: all new copy in `Resources/ConfigR4.xcstrings` (zh-Hans source + en).

## Skill rules applied

- **apple-design-motion** — springs over fixed easing (option drop, arrival, medal); *interruptible + velocity handoff*
  (the drop spring starts at the release velocity; a new lift retargets a settling row; a new AI generation retargets
  the rewrite); every action gets feedback (press .97, haptics from the one `CYHaptics` map); Reduce Motion → fades.
- **apple-design-interaction** — skeletons for content-shaped waits (AI draft card), never block input behind a spinner
  (停止生成 is always available while generating); design every state (no story → 这个玩法没有剧情; no medal → hidden);
  every gesture has a visible fallback (⋯ 上移 / 下移 and VoiceOver actions next to drag; segments next to swipe).
- **apple-design-os / tactics** — one confirm in a sheet header (选择玩法), system back / close untouched, inline 17 pt
  nav titles on pushed/sheet pages.
- **apple-design-foundations** — CYTypography tokens only (Dynamic Type), monochrome SF Symbols for gameplay identity.
- **emil choreograph** — one entrance per container; no uniform stagger (beats and stations use shrinking gaps, total
  ≈ 300 ms); never stagger high-frequency UI (option rows, library rows appear together); choreography never blocks.
- **emil gestures** — 1:1 tracking during the drag (offset from the gesture, no spring while tracking); release finishes
  with a spring seeded by velocity; snap-back is fast; ≥ 44 pt hit targets.
- **emil break-ui** — edge data: empty title (未命名玩法), blank options skipped, no correct answer (no tile turns green,
  all picks shake), story off, medal blank, 0 options (method label + 看完成 / 看失败).
- **mifb** — scale on press; interruptible animations; skip animation on first load where it adds nothing; tabular
  numbers untouched; minimum hit area.

## Gates (cloud, text only)

- `python3 -B tools/check_scaffold.py` — PASS (appsession ratchet, 263 page routes, 4922 Swift files, bilingual keys,
  references, scheme, project equivalence).
- `python3 -B tools/check_design_lint.py` — PASS (1718 files, 0 violations).
- `python3 -B tools/contract_ratchet.py --check` — see the result line appended below. Before this round's fix it
  reported 3 new failures; 1 was this branch's (`test_template_legacy_hints`, fixed in `a6ef3b54e`).
  `test_workshop_paid_professional…bounded_paging` fails identically on the base (`ui/h-code-r3-ops`; the marker
  `value.businessType == "TOPIC"` is absent there too) — not touched by this branch.

## LOCAL VERIFICATION CHECKLIST

Build: Xcode 27, iPhone 17 simulator, iOS 27; light editor and dark player themes; also `--uitesting-reduce-motion`,
`--uitesting-large-text`, `--uitesting-dark`.

1. **Compile first.** New file `App/TemplatePlayerPreviewPager.swift` is in the Questify target (pbxproj IDs
   `840AF721…` / `531A5F0E…`). Watch for: `PlayerPreviewCard` result-builder init, `ForEach(Step.allCases)` with
   `TabView(selection:)` tags, `AnyTransition(.blurReplace)`, `cyHaptic(_:trigger:where:)` trailing closure with
   `Int?`, `CYPillButtonStyle(style: .secondary, …)`.
2. **238:16749** — `--design-fixture t11-template-author`, 完成方式 = 选择题 with 4 options:
   long-press a row → lifts; drag across two slots (drop line + 2 selection ticks); flick and slow drop (flick lands
   with momentum); start a new drag while a row settles; ⋯ 上移 / 下移; delete → toast 撤销 restores text, media and
   the correct circle; shake-to-undo. Reduce Motion: no scale, cross-fade settle.
3. **237:71933** — same fixture, tap 完成方式 → 选择玩法 sheet: 完成 disabled until a tile is picked; pick → confirm →
   row updates; `t11-template-author-locked` → all types unavailable with one reason.
4. **题目图片 / 题目音频** — 选择题 / 文字题: pick an image → crop → upload state on TEST; audio → local check +
   未上传 note; ⋯ 清空 → undo.
5. **238:25435** — from the editor tap 预览 (with no publish issues; fixture `t11-template-author`):
   shoot 到达 / 剧情 / 任务 / 成功 / 失败. Check: nav 玩家视角预览 + ✕ on every step; segment taps jump; swipe pages;
   arrival rise on first open and on returning to step 1; correct pick → green border + check + `.success` → 成功;
   wrong pick → shake + `.error` → 失败 → 再试一次 → 任务; 任务完成 has no ！; medal lands with heavy haptic.
   Edge: blank title, story off, no medal, 0 options, no correct answer, Large Text (pager min height 340 —
   check nothing clips at AX sizes). The rehearsal rows below still open.
6. **239:24018** — `--design-fixture t11-quick-ai` (and `cur2-g6-ai`): send → 停止生成 pill + skeleton card; stop →
   idea kept, 生成 returns; send again → fields blur-rewrite top-down, stations follow, one `.success`; send a second
   time over an existing draft → rewrite retargets; quota exhausted / unavailable lines unchanged.
7. **247:17370** — `--design-fixture hfeat-external-game-catalog`, `e5-external-game`: header ＋ menu and ⋯ menu,
   row ⋯ / long-press menu, delete → undo toast → let it expire (package removed); import sheet + permission confirm
   (white pill, icon rows). `hfeat-external-game-monetization`: 付费 option hidden with money off, shown on TEST with
   the money switch; no ¥ anywhere with money off.
8. **243:1964** — `--design-fixture template-topics` (dark player): a theme without `imgUrl` shows default art (no
   图片暂不可用); a broken cover URL still shows the unavailable tile; 实验预览 row (fixture id 802) shows text, no
   flask. `template-topics-offline`, `template-games`, `hfeat-publish-tab-root` for the tab root.
9. **243:3249** — trigger any toast on the plaza in dark mode (none is wired in this view; use `cur6-shelf-games` if
   it toasts) and confirm the dark pill.

Ratchet result (this tree):
