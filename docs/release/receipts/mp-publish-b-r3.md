# Receipt: mp-publish B lane (round 3) — `mp/r3-publish-b`

Brief: `origin/design/handoff-r2:docs/briefs/round3-1127.md`, section "B lanes" (11-28 13:55 UTC). This lane takes the open rows of
`docs/release/receipts/mp-publish-r3.md` (A lane, `mp/r3-publish`) from the **bottom up** and records them here only; it never edits the A receipt.
MP source: `origin/mp-source:chengyinhub-xcx`. Merchant and the story-flow theme stay out of scope. Not run on a simulator (no Swift toolchain in the cloud).

## A-receipt rows finished by the B lane

| A row (Not done) | MP source → native | Result | Level | Evidence |
|---|---|---|---|---|
| "**`publish/fabu` internals:** … (MP reorder of clocks/traits by swipe-row index not ported)" | `publish/components/d20-settings/index.wxml:25,47,66` → `App/MPGap/AccountPublish/ProjectEditD20Sheet.swift` | **Checked, already matches; no change.** In the MP only the 属性 list has `bind:move` (+ `editing`) on its `cy-swipe-row` (wxml:25 → `attrMove`). The 进度钟 (wxml:47) and 特质 (wxml:66) rows bind only `swipe` / `delete`, so the MP cannot reorder them. Native matches: `attributesSection` has `.onMove`, the clock and aspect `ForEach`es have none. The "not ported" note was a misread. | C | `index.js:132` (`attrMove` is the only move handler) |
| "**`publish/fabu/runtime-structure-editor` kind `endings` (运行结局):** … not built" | `fabu/runtime-structure-editor.wxml:35-55` + `theme-runtime-structure.js` `validate` (endings part, :126-144) / `addStructureEnding` / `onStructureEnding` / `chooseStructureFallbackEnding` / `removeStructureEnding` / `saveStructure` / `_locateStructureIssue` + `fabu/index.js:6614-6615,7183,7743` → new `Core/ProjectEditRuntimeEndings.swift`, new `App/MPGap/AccountPublish/ProjectRuntimeEndingsSheet.swift`, `App/ProjectEditView.swift` | **Built (MP-first).** As in the MP, there is no row for it: the publish check (发布前需要修改) gets an issue `runtimeEndings` with the first MP `endings` error (最多 30 个 / 编号重复或无效 / 名称与说明 / 仅一个默认收尾 / 表决方案须选择已保存的结局章), and tapping it opens the 运行结局 sheet (MP `locatePublishIssue` → `_locateStructureIssue('endings')`). A cloud draft skips the check (MP `index.js:7743`). Sheet in MP order: lead line → one section per ending (header 结局 N + 默认收尾 tag; 名称 (≤80, placeholder 例如：成功撤离), 结局说明 (≤2000), 设为默认收尾 with its detail line and a checkmark, 删除) → 添加结局. Toolbar 退出 / 完成: edits are staged, 完成 validates and writes `themeRuntimeConfig.endings` (adds `schemaVersion 1 · capacity 0` to a new config), 退出 drops them. Deleting an ending a theme 表决方案 still ends in is refused (该结局正在被表决方案使用…). Unknown row keys are kept. Native optimizations: `Form` sections, inline title, system toolbar placements, Dynamic Type text styles, `.selection` haptic on the default choice, VoiceOver selected trait + labelled delete. Not ported: the MP also checks plans inside each node's template config on delete; the native editor has no template details, and the server check still applies. | C | test `Tests/CoreTests/ProjectEditRuntimeEndingsTests.swift` (4 cases: add/limit, save/validate, delete in use, issue listed + cloud draft skips + root anchor); strings fragment `docs/port/strings/mp-r3-publish-b.json` (21 keys, en + zh-Hans, merged into `Resources/Localizable.xcstrings`) |

## For other lanes
- none this run.

## Gates (last run on the branch head)
See the commit message of the last push.
