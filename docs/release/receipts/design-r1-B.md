# Design hand-off r1 · config (C1–C3) · build receipt

Branch `ui/d-r1-config` from `origin/ui/main` (15205f9b). Specs: `docs/design/handoff-r1/review/full-config.md`
(sections 2, 3, 4 batches A–G, 6 defaults), `revise/cfg-AB.md`, `cfg-C.md`, `cfg-D.md`, `cfg-E.md`, `revise/kit*.js`,
`kit-state.json`, `cfg*.js`, `detent.js`, `swap.js` on `origin/design/handoff-r1`.

**Evidence boundary.** No Swift toolchain in this workspace: nothing here was compiled, run on a simulator,
or screenshotted. Every type, initializer and modifier was checked against existing repo usage; new and touched
Swift files pass the repo's Tree-sitter preflight (`tools/check_swift_syntax.py`, a parse check only). UI tests
that were edited were not run. Unit tests in `Tests/CoreTests/EditorKitModelTests.swift` were authored, not run.

Section 6 defaults used: Q-A remove `先保存为我的玩法` (no such control exists in the native editor, so nothing
to remove); Q-B regroup long forms (yes); Q-C 奖励分 = 积分; Q-D keep the dropdown for D20 难度; Q-E handbook
load-error wording.

Shared pieces built locally and marked `// HANDOFF-R1: replace with DS component from ui/d-r1-foundation-player`:
`EditorKitPillButtonStyle` (white/black pill) and `EditorSheetHost` (resizable sheet). No shared design-system
or theme file was edited.

## Editor kit (feature-local)

Files sit flat in `App/` with an `EditorKit` prefix, next to `TemplateAuthoring*` / `ProjectEdit*`. A subfolder was
not used because `tools/generate_project.py` and the `check_scaffold.py` key scan only read `App/*.swift`: a folder
would need a generator change and would escape the localization and lint gates.

| File | Contents |
|---|---|
| `Core/EditorKitModel.swift` | Section 3.3 detent table, fit cap 62 %, scroll-only-at-largest rule, motion constants (3.2, CF-60, CF-64), one reorder rule, 次数上限 / 不限次数 model, units, ms → s, `—` for unknowns, live counter, save states, review status (no raw codes), outline sections, step progress, ticket summary, no-sheet-on-sheet rule, single-choice control rule with the D20 owner override |
| `Tests/CoreTests/EditorKitModelTests.swift` | 17 tests for the above (authored, not run) |
| `App/EditorKitFoundation.swift` | text table helper, surfaces (OnCard #EFEFEF / OnGrey white via palette tokens), kit geometry, motion, 44 pt hit target, pill stand-in, selected border, card surface |
| `App/EditorKitSheet.swift` | `EditorSheetHeader` (grabber, grey ✕ / ‹, black 完成 pill, 20 Bold title, eyebrow), `EditorSheetPage` (pinned header, scroll locked below the largest detent, 放弃修改？ dialog, error banner), `EditorSheetHost` + `.editorSheet(item:/isPresented:family:)` |
| `App/EditorKitFields.swift` | `EditorField` (line/area, counter, one help/error slot), `EditorNumberField`, `EditorNumberRow` (unit suffix, stepper ≤ 20, range only as error), `EditorStepper`, `EditorPopUp`, `EditorSwitchRow`, `EditorRow`, `EditorOptionRow`, `EditorReadOnlyGroup` |
| `App/EditorKitCards.swift` | `EditorCard` (collapsed one-line summary), `EditorCardFooter` (次数上限 stepper, 不限次数 switch, 奖励 in 积分), `EditorSectionBar`, `EditorSaveChip` (+ popover), `EditorStepBar`, `EditorBottomBar` |
| `App/EditorKitLists.swift` | `EditorRowActionsMenu` (上移 / 下移 / 复制 / 删除 red last), `EditorDragHandle`, `EditorListItemHeader`, VoiceOver reorder actions, `EditorAddRow` (n/limit), `EditorDropLine`, `EditorReorderableStack` (drag/drop for non-List editors), `EditorAnswerOptionRow` |
| `App/EditorKitFeedback.swift` | `EditorToast` + `.editorToast`, `.editorConfirm` (confirmationDialog), `EditorToolChip` + `EditorPopoverContent` |
| `App/EditorKitResults.swift` | `EditorResultContent`, `EditorStateView` (handbook wording), `EditorInsertSeam`, `EditorGameplayPickerGrid` |
| `Resources/EditorKit.xcstrings` | 86 bilingual keys |

## CF issues

Status: **done** (built and wired), **partial** (part wired, rest named), **left** (not done). "Figma-only" items
have no SwiftUI work in the plan.

| CF | Status | Files | Notes |
|---|---|---|---|
| CF-01 | done | `Resources/Localizable.xcstrings` (`mpd.aigc.filing`) | Rest is Figma-only. AIGC line now `内容由 AI 生成 · 备案号 %@`. |
| CF-02 | done | — | Figma-only (seed strings). |
| CF-03 | partial | `App/ExternalGameReviewScreens.swift`, `Core/EditorKitModel.swift` (`EditorReviewStatus`) | Submissions and catalog show 审核中 / 未通过 / 已通过 (`—` unknown), no game ID; the game is picked by name; `节点编号` label. Left: node picked by name (no node list in this sheet); 复制诊断信息 menu. |
| CF-04 | done | `App/EditorKitFeedback.swift` | Layout defects are Figma; the toast wraps at 329 max width. |
| CF-05 | left | — | Tab bar belongs to the shared player shell (foundation agent). |
| CF-06 | done | — | Q-A: no `先保存为我的玩法` row exists natively. 活动地点 placeholder already correct. |
| CF-10 | partial | `App/EditorKitFields.swift`, `App/EditorKitFoundation.swift` | One field kit built. Existing `TemplateAuthoringField` keeps its renderer (gains unit suffix and counter); full swap of every Form field to `EditorField` left. |
| CF-11 | partial | `App/EditorKitSheet.swift`, `App/TemplateAuthoringView.swift` | Header built; used by the new 还不能预览 sheet. Existing sheets keep their headers. |
| CF-12 | done | `App/EditorKitSheet.swift`, `Core/EditorKitModel.swift` | Static audit of topic editor / gameplay / publish: story flow, chapter, node and ticket editors are pushed pages; no sheet presents a sheet. Kit sub-editors push (`EditorSheetPage` leading `.back`). |
| CF-13 | partial | `App/EditorKitSheet.swift`, `Core/EditorKitModel.swift` | Detent table, fit measurement, spring, haptic, scroll lock built. Existing sheets still use `cyDomainSheet` detents. |
| CF-14 | done | `App/EditorKitFields.swift` | Native `Toggle` only. |
| CF-15 | partial | kit files | 44 pt targets on every kit control. Untouched legacy controls left. |
| CF-16 | partial | `App/EditorKitFeedback.swift`, `App/TemplateAuthoringRuleFields.swift` | One toast built; rule-step limit shows `12/12` on the add row instead of a toast. Other validation toasts left. |
| CF-17 | done | `App/TemplateAuthoringView.swift`, `App/ActivityPublishingWizardView.swift` | 发布 stays enabled for missing data, jumps to the first section with an error (`.error` haptic); stays disabled only when locked or local-only. Duplicate submit in the status bar removed. 发布活动 already keeps the primary enabled with inline errors. |
| CF-18 | partial | `App/EditorKitResults.swift` | `EditorStateView` built with skeleton; used for the preview gate. |
| CF-19 | partial | `Resources/Localizable.xcstrings`, `App/ActivityPublishingWizardView.swift` | AI page titled `AI 快速创建`; 发布活动 in-content heading removed. Nav component left to the shared shell. |
| CF-20 | partial | `App/ProjectEditView.swift` | Chapter rows: one ⋯ (上移 / 下移 / 删除), trailing handle, drag reorder (existing `.onMove`). Left: whole-card tap target redesign, progress bar, list/map segmented. |
| CF-21 | left | — | Figma state frames. |
| CF-22 | done | `App/EditorKitCards.swift`, `App/TemplateAuthoringView.swift`, `App/ActivityPublishingWizardView.swift` | Save chip replaces the status bars in the gameplay editor and 发布活动. |
| CF-23 | partial | `App/EditorKitResults.swift` (`EditorInsertSeam`) | Seam built; story-flow block list still the existing `ProjectEditChapterView` (already `.onMove`). |
| CF-24 | left | — | Effect tiles / swatches. |
| CF-25 | left | — | Delete rules unchanged (chapter delete uses the existing removal review). |
| CF-26 | left | — | Chapter settings regroup. |
| CF-27 | left | — | Topic detail list. |
| CF-28 | partial | `App/TemplateAuthoringView.swift` | Live `n/30`, `n/32` counters on 看点 and 标题; static limits removed from labels. |
| CF-29 – CF-32 | left | — | Node sheet, template picker, map pickers, rule sentences. |
| CF-33 | partial | `App/EditorKitLists.swift`, rule steps, chapters, tickets (topic + activity), choice options | ⋯ menu, trailing handle, swipe as shortcut, dashed add row. Other list editors left. |
| CF-34 | partial | `App/EditorKitFields.swift` | Neutral selection components built. |
| CF-35 – CF-37 | left | — | |
| CF-38 | partial | `App/ProjectEditView.swift`, `App/ProjectEditTicketSummary.swift` | Ticket rows show `39 积分 · 20 张` (`—` unknown), summary `2 种票 · 39 积分起` / red `还没设置`, reorder. Ticket editor as a sheet left (still a pushed page). |
| CF-39 | left | — | Native date pickers already used in activity time; topic dates unchanged. |
| CF-40, CF-41 | partial | `App/EditorKitResults.swift` | `EditorResultContent` built; publish flow not rewired. |
| CF-42, CF-43 | left | — | |
| CF-44 | partial | `App/TemplateAuthoringView.swift`, `App/TemplateAuthoringDetailForms.swift`, `App/TemplateAuthoringCoverHeader.swift` | Sticky section bar with error dots and jump; 16:9 cover with title. Collapsed cards (`EditorCard`) built but sections not collapsed. |
| CF-45 | done | `App/TemplateAuthoringView.swift` | One `预览` entry; with missing data it opens 还不能预览 + `去填写` which jumps to the first problem. |
| CF-46 | partial | `App/TemplateChoiceOptionRowsEditor.swift`, `App/EditorKitLists.swift` | Choice options: correct control in front, text, attachments expand only for the edited option, ⋯ 删除. Option reorder left (core supports add/remove only; letters carry media). 人物指认 sub-page left. |
| CF-47 | partial | `App/TemplateAuthoringView.swift`, `App/TemplateCreatorConfigurationView.swift`, `App/EditorKitCards.swift` | Units moved to suffixes (秒, 度, 积分); `EditorCardFooter` with 不限次数 switch built. Left: ms → s display on `goalMs` / `toleranceMs`; footer mounted in cards; `0 为不限` labels on fields without a switch. |
| CF-48 | done | strings, `App/ExternalGameReviewScreens.swift`, `App/PublishingModesViews.swift`, `App/ProjectEditTicketSummary.swift` | 奖励 with 积分 suffix; prices carry 积分; external-game cash price TEST-only behind the money switch; traffic rewards in 积分. |
| CF-49, CF-50 | left | — | |
| CF-51 | partial | `App/EditorKitResults.swift` (`EditorGameplayPickerGrid`) | Grid built; the completion-method picker stays a pop-up because five UI tests drive it by identifier. |
| CF-52 | partial | `App/EditorKitResults.swift` | Result component built; save-result sheets not rewired. |
| CF-53 | partial | `App/EditorKitFeedback.swift` | Tool chip + popover built; not mounted. |
| CF-54 | left | — | |
| CF-55 | done | `Core/EditorKitModel.swift` | Q-D: D20 keeps the dropdown (rule encoded). |
| CF-56, CF-57 | partial | `App/EditorKitFields.swift` (`EditorReadOnlyGroup`) | Read-only group built; not mounted. |
| CF-58 | partial | `App/ActivityPublishingWizardView.swift`, `App/PublishingModesViews.swift` | Tappable step bar; real-name as a pushed page shown only when needed (consent already a switch); ticket ⋯, 积分 suffix, dashed add row. Ticket cards opening a sheet left. |
| CF-59 | partial | `App/PublishingAIDraftSheet.swift` | Prompt first, suggestions after, notice last. Draft card states left. |
| CF-60 | partial | `App/EditorKitLists.swift`, rule steps, chapters, tickets, poems | Drag, ⋯ and VoiceOver share one rule (`EditorReorder`); lift/insertion line via List or `EditorReorderableStack`. Story-flow paragraph split left. |
| CF-61 | partial | — | Unknown adoption conditions are already omitted by `TopicTemplateAdoptionConditions`; the `还有 N 项信息待补充 ›` line, default cover art and white primary left. |
| CF-62 | partial | `App/ExternalGameReviewScreens.swift` | Neutral wording, status words, money gating. Library header menus and swipe delete left. |
| CF-63 – CF-65 | partial | `Core/EditorKitModel.swift`, `App/EditorKitFoundation.swift` | Motion and haptic constants; Reduce Motion cross-fades in every kit animation. Preview animations left. |
| CF-66 | partial | kit files | Error text on the card surface, never on a pink fill; status words carry icons. |
| CF-67 | partial | `App/EditorKitCards.swift`, `App/EditorKitFields.swift` | Bottom bar moves secondaries into ⋯ at accessibility sizes; number rows stack. |
| CF-68 | done | kit files | Labels: 调整顺序, 在这里插入, 更多, 正确答案 + 已选中. |
| CF-69 | partial | strings | Ellipses removed from config loading strings; 确定删除 → object question. Remaining ellipses outside these keys left. |
| CF-70 | done | strings + side manifests | Q-E handbook wording on config load failures. |
| CF-71 | partial | `App/TemplateAuthoringRuleFields.swift` | Numbered rows carry the order. Other explainers left. |
| CF-72, CF-73 | left | — | |
| CF-74 | partial | `App/EditorKitFields.swift` | Number pad, `.next` submit label. |
| CF-75, CF-76 | left | — | |
| CF-77 | done | `App/EditorKitSheet.swift` | Dirty kit sheets cannot be swiped away; ✕ asks 放弃修改？. |
| CF-78 | left | — | |

## Checks

- `python3 -B tools/check_scaffold.py`: PASS (includes design lint, a11y lint, catalog coverage, missing keys).
- `python3 -B tools/check_design_lint.py`: PASS (0 allowlisted).
- `python3 -B tools/check_a11y.py`: PASS.
- `python3 -B tools/contract_ratchet.py --check`: see the final line appended below. On `origin/ui/main` before any
  change the ratchet already reported 2 new failures (`test_play_task_outcome_journey…missing_node_during_readback`,
  `test_workshop_paid_professional…bounded_paging`); they are not caused by this branch.
- Contract tests updated for owner-approved changes: `test_template_rule_editor.py` (reorder now required),
  `test_template_author_exit_guard.py` (preview gate), `test_template_own_shelf_read_state.py` (handbook wording).
- UI test updated: `TemplateEditorControlsFlowTests` deletes a rule step through its ⋯ menu.

Final ratchet on this branch head: `contract ratchet: 186 failing, baseline 184, new 2, fixed 0` — the same two
pre-existing `origin/ui/main` failures listed above; no new failure from this branch.
