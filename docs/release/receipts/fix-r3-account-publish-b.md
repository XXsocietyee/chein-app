# Receipt: fix/r3-account-publish-b (wave ×10, Claude F-agent, account-publish half b)

- **Brief:** `origin/design/handoff-r2:docs/briefs/wave-x10.md`.
- **Base:** `origin/ui/combined-r7` (7fdfad1f1).
- **Restyle branches merged first:** `restyle/r4-me-account`, `restyle/r3-merchant-creator`, `restyle/r6-system-rest` and `restyle/r1-player-front`. The r1 merge had one conflict in `Tests/ContractChecks/test_global_chrome_domain_contract.py`, resolved by keeping both rule blocks.
- **Scope:** pages 12–22 of the round-1 audit (`audit/parity-account-publish`): privacy, agreement, deregister, pass reveal, fabu, temp, activity, template-intro, square detail, team detail and team join.
- **Gap source:** the r7 fix queue `audit/parity-r7-account-publish:docs/audit/parity-r7/account-publish.md`, Claude-owned items. The `review/r7-rev-{a,b,c}` reviews have no findings on these files.
- **Layer:** App only. No Core types were changed.
- **Strings:**
  - New keys are in `docs/port/strings/fix-r3-account-publish-b.json`. They use the `fixr3.*` prefix and the default table.
  - The `config.gameplay.category.*` keys were added directly to `Resources/ConfigR4.xcstrings`, because that is a feature table, not Localizable.
- **Acceptance routes:** `docs/port/accept/f-account-publish-b.txt`.

## Fixed

| ID | Page | What changed | Files |
|---|---|---|---|
| B-PV-02 | privacy | 首页城市自动定位 is now one system `Toggle`. It starts from the latest `home_city_location` consent row (no row reads as off). Turning it on confirms first, then records AGREE; turning it off records REVOKE. 撤回授权 is now a plain disclosure row, not a pill. | App/SettingsPrivacyLocationView.swift |
| B-PV-05 | privacy | `.secondary` → `CYColor.textSecondary` on the privacy page. The holds row uses `.cyText(.bodyCompact)`. | App/SettingsPrivacyLocationView.swift, App/SessionLocationHoldsSection.swift |
| B-PV-06 | privacy (roam sheet) | A partial withdrawal (server revoked, local cleanup pending) or a failed one shows an inline row 撤回尚未完成，请重试 with 重试. The revoke logic moved into `performRoamRevoke()`; its behaviour is unchanged. | App/AccountComplianceViews.swift |
| B-AG-01 | agreement | The top version block is gone. There is one footer 「版本 x · 生效日期 y」, which wraps to two lines at large text sizes. The version identifier is kept for UI tests. | App/SettingsLegalDocumentView.swift; contract test_native_ui_accessibility_semantics updated |
| B-AG-03 | agreement | Section heading uses `.cyText(.cardTitle)`; the extra `lineSpacing` is dropped. | App/SettingsLegalDocumentView.swift |
| B-DR-02 | deregister | A BLOCKED card with the neutral title 暂时无法注销, 「请先处理以下事项：」, one row per blocker and 「我已处理，重新检查」 in place of 刷新状态. Blockers are no longer listed twice. | App/AccountComplianceViews.swift |
| B-DR-05 | deregister | `.headline`/`.subheadline`/`.footnote` → `.cyText(.cardTitle/.body/.bodyMedium/.meta)`. | App/AccountComplianceViews.swift |
| B-DR-06 (partial) | deregister | `.freshLogin` is now an empty state 登录后查看账号注销条件, with the existing explanation as detail. | App/AccountComplianceViews.swift |
| B-DR-07 | deregister | The Settings search results for 注销账号 and 漫游定位 open the same sheet as the Settings rows, through `AccountComplianceSheetStack`. | App/SettingsView.swift, App/AccountComplianceViews.swift |
| B-DR-08 | deregister | Step circles use the accent fill (`actionPrimaryBg`) with `textOnAccent` digits and checks. | App/AccountComplianceViews.swift |
| B-DR-09-r7 | deregister | MP copy: 我已阅读并理解注销后果, 获取验证码 / 重新发送, 短信验证码 and 确认申请注销. 正在核验注销条件 shows under the skeleton, and 注销条件核验失败 titles a failed read. | App/AccountComplianceViews.swift, strings fragment |
| B-PR-02 | pass reveal | The MP gold wash (#2A1E08→#8A6414→#D4A72C→#F2CF63) rises over the lower 62 %. After the reveal the key breathes slowly (PhaseAnimator); with Reduce Motion it stays still. | App/PassMembershipViews.swift, App/DesignSystem/CYNight.swift (passGold0–3) |
| B-PR-04 | pass reveal | Eyebrow tracking 3.5, white at 72 %. Title and line are white on the wash. The CTA is the MP inverse 50 pt white pill. | App/PassMembershipViews.swift |
| B-PR-05 | pass reveal | The stage tap/drag skip and the press dim are removed; only the toolbar 跳过 skips. | App/PassMembershipViews.swift |
| B-PR-06-r7 | pass reveal | `.toolbarBackground(.hidden, for: .navigationBar)`. | App/PassMembershipViews.swift |
| **C-F6 (P0)** | fabu | The built 到访方式 editor (`FreeExplorationVisitConfigView`) is mounted in `ProjectEditView` for saved free-explore topics. It is composed through an app-root environment factory (`session.freeExplorationVisitConfigModel`). Reads need `PlayRuntimePortRouteGate.freeExploreVisitConfigRead`; writes need the write gate and the editor's approved author authority (`canSubmit && !canSimulate`). **Both gates stay default off**, so the row is hidden until they are turned on. | App/FreeExplorationVisitConfigView.swift, App/ProjectEditView.swift, App/QuestifyApp.swift |
| C-F12 (rest) | fabu | All 14 raw `.font(.…)` in the detail forms are now `.cyText` tokens. | App/ProjectEditDetailForms.swift |
| C-F15-r7 | fabu | 这份主题加载失败 with one full-width 重新加载 (the `projectEdit.reload` identifier is kept). | App/ProjectEditFlowParity.swift |
| C-F18-r7 | fabu | 下一步 uses `CYPillButtonStyle(.primary)`, matching the bar. | App/ProjectEditView.swift; test_project_edit_review_availability BUTTON pin updated |
| C-T5 (partial) | temp | 保存草稿 moved into the bottom bar as a secondary action, keeping its identifier. | App/TemplateAuthoringView.swift |
| C-T8 | temp | Gameplay picker categories follow the MP: 问答 (text, choice, photo) / 互动 (manual, preference) / 挑战 (scan, gps, sensor). | App/TemplateGameplayPickerSheet.swift, Resources/ConfigR4.xcstrings |
| C-T10 | temp | `.font(.caption)` → `.cyText(.caption)`. | App/TemplateAuthoringView.swift |
| C-T11 (partial) | temp | The raw "Request: uuid" line shows in DEBUG builds only. | App/TemplateAuthoringView.swift |
| C-A7 | activity | The activity form uses the single `.topicEditor` domain, which was `.merchant` before; its sheets already used it. | App/PublishingModesViews.swift (outside the hash-pinned slices) |
| C-I5 (partial) | template-intro | Literal spacings are replaced by CYSpacing tokens. | App/TemplateAuthoringIntroExperience.swift |
| C-S9 | square detail | Reaching the end of the comments loads the next page (MP onReachBottom). The button stays for VoiceOver. | App/SquareDetailView.swift; Tests/AppUITests/SquareFlowTests.swift |
| C-D9 | team detail | 重新加载 shows only after a failed read or when no detail is loaded; pull-to-refresh is unchanged. | App/TeamHomeView.swift |
| C-J3 | team join | 加入队伍 now joins directly and reads 加入中… while the request runs. The join review sheet is suppressed when a submit authority exists; without one, the review sheet still explains why. Other team actions keep their review sheets. | App/TeamHomeView.swift; Tests/AppUITests/TeamFlowTests.swift (2 tests drop the confirm tap; names kept because planning contracts reference them) |

## Left open (with reasons)

| ID | Sev | Reason / next owner |
|---|---|---|
| B-PV-02 (presence) | P1 | There is no read of the current nearby-presence state, so an "off-only Toggle" would claim a state we don't know. The button is kept. **Cursor:** add a presence-visibility read. |
| B-PV-07-r7 | P2 | The launch gate runs signed out, where `pendingRecords(accountID:)` has no account. **Cursor:** add a "record owed" signal that is visible before sign-in. |
| B-DR-03 / B-DR-04 | P1 | Owned by Cursor (Core). |
| B-DR-06 (rest) | P1 | 登录 CTA: the compliance sheet has no sign-in hook. There is also no DENIED step in `ComplianceStep`. **Cursor:** add a `.denied` step; the App will then show 当前身份不能查看注销条件 + 刷新. |
| B-PR-03 | P2 | Replacing the reveal in the path needs the parity router to support replace-top; `mpParityRouteDestination` only pushes. |
| C-F2 (rest) | P1 | The starter sheet has no place-picker target (`ProjectNodePlacePickerHost` takes chapter/node or a pending target only). The 3 XCUITests type coordinates and need a fixture place reader. Recommend one change that covers the host, the fixture and the tests. |
| C-F4 (rest) | P1 | Moving 存到本机 into ⋯ breaks about 20 XCUITests that tap `projectEdit.saveLocal` in the bar. This needs a coordinated test update in the acceptance loop. |
| C-F8 | P1 | PhotosPicker for the story/node image URL fields is size M, and the fields are pinned by story-media contracts. Not attempted in this window. |
| C-F14 | P2 | 「还有 N 项未填」 needs the MP `ticketMissing` rule in Core (EditorTicketSummary has no required-field count). **Cursor.** |
| C-F16-r7 | P2 | A vertical-axis TextField changes the XCUI element type that `ProjectEditFlowTests` queries (`textFields["projectEdit.name"]`). |
| C-T2 (rest), C-T12-r7 | P1 | These need Core signals: an adoption-pending error kind, and a support-matrix read with loading and error states. **Cursor.** |
| C-T5 (rest) | P1 | 保存到此设备 was not moved into ⋯ because 6 XCUITests tap `templateAuthor.saveLocal` in the form. |
| C-T6 (rest), C-T13-r7, C-I8-r7 | P1 | `from=fabu|citynode` and `scope=MERCHANT` need `templateAuthoringEditor(scope:origin:)` in AppSession/Core. In the app, the fabu-bound flow saves a draft and then 返回 binds it. **Cursor/Core.** |
| C-T9 | P2 | `TemplateAuthoringField` already passes `limit` (30) to the editor field; nothing to change found. |
| C-A8 | P2 | Core validation (`ActivityPublishingWizard` ticketStart/ticketEnd) requires per-ticket times, so dropping the fields would block publishing. **Cursor:** default the ticket window to the activity span. |
| C-A9-r7, C-I9-r7, C-S4, C-S8, C-S10, C-D10, C-J5, C-J6 | P2 | Polish; not reached. C-D10 already loads on demand. |
| Gemini / owner items | — | C-F1, C-F5, C-F7, C-D2, C-D11, C-J2, C-T3, C-A4 (Gemini, parked MPGap) and B-PV-04, C-F17 (owner) were not touched. |

## Skipped because in-flight branches cover them

- `restyle/*`: visual only, and merged into this branch first (r1, r3, r4, r6).
- `gap/g2-ops`: compile fixes for the parked `App/MPGap/AccountPublish` views (C-A4, C-D2, C-J2, C-F5); not touched here.
- `cursor/*` and `port/*`: none touch these screens beyond what r7 already has. `cursor/mp-assets` does not exist yet, so no MPAsset swaps were made. The pass reveal key emblem is still `PassKeyEmblem`, which uses no SF Symbol for brand art.

## Checks run in the cloud

- `tools/contract_ratchet.py --check` on the merged base, before my edits: 195 failing, 11 new against the 184 baseline. All 11 come from the restyle merges.
- After my edits, the 2 new failures I introduced were fixed: `test_native_ui_accessibility_semantics` (legal footer pin) and `test_settings_native` (one NavigationStack). Final run on `aae081a4a`: **195 failing, baseline 184, new 11**. This is the same set as the merged base, so this branch adds 0 new failures.
- `tools/check_typography_lint.py`: PASS.
- `tools/check_appsession_ratchet.py`: PASS. `AppSession.swift` is untouched.
- `tools/check_scaffold.py` fails on `origin/ui/combined-r7` as well (pre-existing); no new Swift files were added.
- **Not compiled.** The coordinator should watch for:
  - `phaseAnimator` (iOS 17) in PassMembershipViews.
  - `FreeExplorationVisitConfigModel` (`@Observable`, `@available(macOS 14)`) created in an `AppSession` extension.
  - `Toggle(isOn: Binding(get:set:))` in SettingsPrivacyLocationView.
  - `if a && b && c, d || e` in TeamHomeView.
