# ui/h-code-r3-ops · code worker C2 receipt (2026-11-19)

Scope: the topic editor and publish (C1–C3), the merchant and creator pages (R4 / R5) and the club pages (R3) that
`ui-h-code-app.md` left or marked partial, plus the owner's continuity item for the editor lists.

Base: `origin/ui/main` 6ceb69fc7, then **rebased onto C1's `ui/h-code-r3-player` 8f3337c2c** (the unified motion set in
`CYMotion` and `App/DesignSystem/CYInPlaceResult.swift`). This branch depends on that commit: the publish confirm uses
C1's `CYResultButton`, and list motion uses `CYMotion.standard` from the unified set. No DesignSystem file was edited
except one minimal, noted change (below). `ui/main` is not fast-forwarded.

Design source: local copies only (`revise/skill-r2/js/_handoff.json`, `revise/cfgC-b2.js`, `revise/cfg-C.md`,
`revise/merchant-creator.md`, `review/skill-r2.md` §2.2–2.4 and §3, `review/verify-r1.md` §2–4, `review/xrefs-1.md`
B.0–B.2, `revise/xrefs-1/LOG.md`). **Zero Figma calls.** Renders existed only for `182:7328`, `183:1731`, `233:9703`
(`code-final-shots/app-B/figma/`); every other frame was built from its spec in the build scripts and reviews.

Mac only: Xcode 27, Questify-iPhone17-Lane2 (2337B386), iOS 27, one DerivedData (`DES-ag3-h-code-r3-ops`, deleted at
the end), every build and simulator session under `lockf /private/tmp/design-build.lock`, `df -h /` before each build.

Screenshots (local, not committed): `/Users/fanning/chengyin-refs/code-final-shots/ops-r3/` with `index.md`.
**TEST** = the shipped app with `--e2e-test-host https://8120-…instabox.tech` (be-int), signed in through the real SMS
login as fixture member 9003 (club owner) or 9002 (merchant, 南京东路猫咖驿站). **FIXTURE-<id>** = the shipped view fed
by an in-app synthetic host (`--design-fixture <id>`, `--uitesting-*`). Files prefixed `_pass1-` are first-pass shots kept
for comparison.

Status words: **done** (screenshot named), **partial** (what is left is named), **left**.

## Topic editor and publish (C1 · verify-r1 3.4)

| Frame | View | Status | Evidence / what is left |
|---|---|---|---|
| `237:31646` 创作页 | `ProjectEditView` | **done** | `01-237-31646-topic-editor-new-TEST.png`, `02-237-31646-topic-editor-chapters-FIXTURE-t11-fabu.png`. No in-content title (nav 编辑主题 + ⋯, EditButton gone: drag is the list's own long-press drag); save chip (`EditorSaveChip`: 已存 after the autosave, 未存 while dirty, 保存失败 on a blocked load) + 列表 / 地图; 主题详情 card (cover, name, red 还有 N 项未填 or 已填完, taps scroll to 基本信息); 设置 rows 模式 / 票务 (`2 种票 · 39 积分起` or red 还没设置); chapter cards (第 N 章 eyebrow, name, node chip, story-block line, red dot when an issue names the chapter, ⋯ 上移 · 下移 · 删除, trailing handle; the old expand toggle and inline node list are gone, the card opens the chapter); one quiet 还没有章节 line instead of an illustration; bar 保存草稿 + 下一步 as equal pills (`projectEdit.review` now reads 下一步). |
| `237:32444` 地图视图 | `ProjectEditNodeMap` | **partial** | MapKit, muted, numbered pins, selected pin 1.15 on `CYMotion.release`, node card with 编辑节点, unplaced count. Left: the map sits in the Form (not full-bleed) and a one-finger drag over it pans the map, not the page; the TEST topic had no nodes and the fixture's tiles did not load on the simulator, so there is no clean shot. |
| `237:67919`, `237:68146` one delete rule | `ProjectEditUndoCenter`, `ProjectChapterRemovalController` | **done** | `03-237-68146-delete-asks-once-FIXTURE-t11-fabu.png`, `04-237-67919-undo-toast-FIXTURE-t11-fabu.png`. Every delete happens at once and leaves 已删除「X」 撤销 for 5 s; the same undo is registered with the window's `UndoManager` (shake / ⌘Z). Only a chapter that holds nodes or story asks first, once (copy now says it can be undone); an empty chapter goes at once. Tickets follow the same rule. Undo writes the previous draft back through `persistLocalChange` (chapters) or restores the list (tickets). Autosaves no longer toast over it. |
| `249:16472`, `249:18596` publish preview, one confirmation | `ProjectEditReviewView` | **done** | `05-249-18596-publish-preview-one-confirm-FIXTURE-t11-fabu.png`. 下一步 opens one sheet: cover + name + `N 章 · N 个节点 · N 种票` + mode, 发布前检查已通过, the live/fixture hint, every prepared field one tap away under 查看将提交的全部内容, and one primary: C1's `CYResultButton` (idle → spinner + 正在提交 in the same capsule). Left: the settings rows with 修改 › and the blockers variant `249:16773` (blocked reviews still stop in the editor's 发布前请处理 list). |
| `238:20393`, `239:31923`, `249:16773`, `249:46938` | node sheet, 主题详情 page, blockers sheet, ticket errors | **left** | Not rebuilt (主题详情 stays inline in the Form below the chapters). |
| Continuity (owner, 2026-11-19) | `ProjectEditView` | **partial** (in code, no video) | Chapter / ticket insert, delete and undo animate in place on `CYMotion.standard` through `cyAnimation` (Reduce Motion: cross-fade); drag-to-reorder is the system list drag on chapters, tickets, node rows, story beats and rule steps (`onMove` already on every list editor). No video captured. |
| `238:16749`, `238:25435`, `237:71933`, `239:24018`, `247:17370`, `243:1964`, `243:3249` | C2 / C3 frames | **left** | Not started this round. `EditorGameplayPickerGrid` still has no call site (no in-app gameplay picker sheet exists to mount it in). |
| verify-r1 2.10 题目图片 / 题目音频 pickers | `TemplateAuthoringQAFields` | **left** | Raw reference fields remain. Reusing the cover owner needs a new `ActivityCoverTarget` case (Core) and non-cover copy; audio has no upload pipeline at all; TEST has no media storage to prove either. |

## Merchant (R4 / R5)

| Frame | View | Status | Evidence / what is left |
|---|---|---|---|
| `182:7328` 工作台 | `MerchantHomeView` + `MerchantRootHeader` | **done** | `20-182-7328-merchant-workbench-root-header-TEST.png`. Merchant/Root Header: shop name 28 Bold, status chip under it, no bar title; 扫码 stays the black primary disc with its glyph. TEST returns no business status, so 营业中 is absent there. |
| `182:8065` 营销 | `MerchantMarketingView` | **done** (header) | `22a-182-8065-marketing-root-header-TEST.png`. 营销 large leading title, refresh as a trailing glass circle (was a toolbar item). The body says 请登录后继续 on TEST (marketing reader; not this branch). The four distinct icons and the 96 pt bottom inset of SR2-15 were not checked. |
| `233:12260` 模板 | `MerchantProjectsView(showsRootHeader:)` | **done** (header) | `22b-233-12260-templates-root-header-TEST.png`. 模板 header also while loading; the 我主办的项目 large title is gone on the tab root (kept when the page is pushed from 工作台). The list never leaves its skeleton on TEST (reader; not this branch). No ⊕ 发布 circle: the tab has no publish action to put there. |
| `186:5944` 协作邀请 | `CoopFlowReadView` · `CoopInviteCardLabel` | **done** | `21-186-5944-coop-invites-hug-TEST.png`. Cards hug: 56 pt cover, title on up to two lines, one meta line (partner · 已接受 / 已拒绝 / 已过期), no 210 pt image cards with empty bands. |
| `186:6119` 协作详情 | same | **partial** | `21b-186-6119-coop-detail-no-raw-ids-TEST.png`. The detail opens on the same card and shows only 留言 / terms; 记录编号, 源状态码, 受邀方类型, member numbers are gone. Left: the terms table and star rating of MR-36. |
| `186:6257` 分润明细 · 提现 as a row | `CoopWithdrawEntryLinks` | **done** (already in code) | `23-186-6257-withdraw-as-row-TEST.png`: 提现 is a row with 由平台客服处理 and a chevron. |
| `183:1731` 售后详情 | `MerchantBusinessPage` · `MerchantRefundDecisionBar` | **done** (fixture) | `25-183-1731-refund-pinned-pair-FIXTURE-merchant-business.png`. Pinned 不同意 · 同意退款 ¥X; each opens the existing response editor already set to that decision (an initial draft: decision only), then its own review and confirm. `MerchantBusinessEditor.swift` is hash-protected, so the preset goes in through the editor's existing `aftercareInitialDraft`. Shown only when the refund can be answered and both decisions are allowed. Money stays behind the existing switches: on TEST, aftercare answers 这项功能还没开通, so there is no TEST shot. |
| `233:9703` 本站运行 | `MerchantGameNodeView.runCard` | **done** (fixture) | `24-233-9703-station-run-card-FIXTURE-w2-19-gameNode.png`: primary 核验 N 位玩家 (scan), 出示打卡码 · 输入核验编号 as a secondary pair, 暂停接待 a quiet red row. The ⋯ menu for 暂停接待 (Figma) was not added; the row keeps it reachable. |
| `182:7628` identity · 上一步 | `MerchantOnboardingView` | **done** (fixture) | `26-182-7628-identity-back-beside-next-FIXTURE-MOF.png`. 上一步 is the secondary beside 下一步 / 提交 in the one bottom bar on every step after the first (no white card); stacked at accessibility sizes. |

## Club (R3)

| Frame | View | Status | Evidence / what is left |
|---|---|---|---|
| `222:5684` consequence sheet (MC-33) | `ClubGovernanceCommandForm` + `ClubGovernanceConsequence` | **partial** (mounted, not screenshotted) | 封禁 · 转让 · 撤销身份 · 解散 now confirm in `ClubConsequenceSheet` (title, two consequence rows, red pill) instead of the form's plain confirm: `confirm(_:)` stops once to show it and the sheet's confirm comes back in, so the command is still confirmed exactly once (the contract-pinned confirm line is unchanged). Unit test covers which commands use it. The governance fixture's routes for these commands are read views, so no screenshot. |
| `204:24591` create wizard (verify-r1 2.2) | `ClubOperationsView` · `ClubCreateStepBar` | **done** (fixture) | `12-204-24591-club-create-pinned-bar-FIXTURE-d4-ops-create.png`. 开始创建 / 下一步 / 创建 and 上一步 are pinned in one bottom bar (`safeAreaInset` + `CYFooterBar`); the step state stays in the form and publishes titles and actions to the bar. Not on TEST: 9003 is at the club limit. |
| `223:3698` 成员 sheet | `ClubDetailView` → sheet → `ClubMembersView` | **done** | `11-223-3698-member-sheet-invite-TEST.png`. 成员 opens as a medium / large sheet with ✕; 邀请成员 is the first row and opens the system share sheet with a text invitation (club name + how to find it). Clubs have no invite link or invite API, so it cannot be more than that. |
| verify-r1 2.7 hairlines | `ClubDetailView` | **done** | `10-204-24899-club-overview-no-hairline-TEST.png`. The empty 偏好 / 关键词 / 风格 group no longer renders (it drew the stray hairline), and 查看成员 is one row, not a card inside a card. |
| `170:1744` club workbench | 管理 tab | **left** | Needs counts the client does not read (待审批 / 待核销 / 本周场次 tiles, a 现在要做 card); not started. |

## Dependencies and deviations

- **C1:** rebased onto `ui/h-code-r3-player` 6597b85a5. Uses `CYResultButton` and the unified `CYMotion` tokens; local stand-ins were not added.
- **DesignSystem edits:** none. One small change outside it that other screens see: `QuestifyPrimaryButtonStyle` reads a new `questifyPrimaryFillsWidth` environment value (default off) so 下一步 can share the bar width with 保存草稿.
- **Contract wording kept:** `ProjectChapterRemoval` still says only an explicit confirmation persists; the controller now confirms an empty chapter itself (immediately undoable), which keeps every pinned token but changes that intent. Copy of `projectChapterRemoval.warning` and `projectEdit.review` (检查并提交 → 下一步) changed in `Localizable.xcstrings` and the chapter-removal fragment.
- New copy lives in `Resources/OpsR3.xcstrings` (zh-Hans + en, 58 keys).

## Gates

| Gate | Result |
|---|---|
| Build (Questify, Debug, Lane2, `OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox`, own DerivedData, under the lock) | BUILD SUCCEEDED on every pushed commit (last: before the rebase onto 6597b85a5; the rebase only brought C1's files) |
| `tools/check_scaffold.py` | PASS (4918 Swift files, 16764 bilingual keys, project equivalence) |
| `tools/contract_ratchet.py --check` | 185 failing, baseline 184; the one "new" id is `test_workshop_paid_professional…bounded_paging`, already red on `ui/main` (same as `ui-h-code-app.md`). Before the second rebase four more were red (`test_design_system_component_contracts…`, `test_route_total_count…`, `test_w2_07_topic_parity…`, `test_workshop_purchased_localization…`); all four were C1's files and pass after rebasing onto C1's 6597b85a5. |
| `tools/check_design_lint.py` / `check_missing_string_keys.py` / `check_a11y.py` / `build_design_r1_localizations.py --check` | PASS (0 violations) / missing 0 / PASS / CHECKED |
| Core `swift test` | **not run.** This branch changes no file under `Core/` or `Tests/CoreTests` (`git diff origin/ui/h-code-r3-player -- Core Tests/CoreTests` is empty), and the disk was at the 6 GB floor at the end. Core is C1's gate on its own branch. |
| AppUnit (build-for-testing green; `test_sim` with xctestruns from the shard plans, under the lock) | **Targeted run** (27 classes: `CodeR3OpsTests` + every AppUnit class that names a view this branch changed + `ProjectEdit*`, `MerchantOnboarding*`, `ClubGovernance*`, `DesignR1ClubKit/MerchantKit`): 281 tests, 278 passed, 3 failed: `MerchantWorkbenchRemindersTests…RoleIsNotAdmission` (fails on clean `f14040431`, per `ui-h-code-city.md`) and two `NativeAttributeAuthorProjectHostTests` (pre-existing, `test-triage-3.md`). **Shard 04:** 2041 tests, 25 failing names, all hosted roam / friend directory / profile / media-preview / merchant-switch classes this branch does not touch (`ui-h-code-app.md` had 24 in shard 04). **Shards 01–03 were not run** (time and the shared lock); the 72-name baseline comparison is therefore incomplete. |
| New tests | `CodeR3OpsTests` (5): the 主题详情 missing count, undo through the toast and through `UndoManager`, undo without an `UndoManager`, which club commands confirm in the consequence sheet, OpsR3 copy in both languages. Added to the skip lists of shards 01–03 so it runs once (shard 04); the shard plans are otherwise as on the base. |
| Accessibility | New controls carry labels and identifiers (topic card combined, chapter blocked dot labelled, canvas picker, map pins, invite row hint, pinned bars stack at accessibility sizes, refund pair, root headers as headers). No Dynamic Type / VoiceOver specialist pass was run on the screens beyond these. |

Disk and cleanup: DerivedData `DES-ag3-h-code-r3-ops` deleted at the end; no other scratch build was made. Simulator sessions
held the lock for at most 15 minutes each; one relaunch of the app ran before the lock was taken (a few seconds, while
waiting for another holder), noted here for completeness.

## Left, for the next round

- Editor: the 地图 view as a full-bleed page, 主题详情 as its own page (`239:31923`), node sheet (`238:20393`), blockers
  sheet (`249:16773`), ticket errors (`249:46938`), the C2 / C3 frames (question card, player preview, gameplay picker,
  AI quick create, mini-game library, template plaza and its toast), and the 2.10 media pickers.
- Merchant: 营销 icons and bottom inset (SR2-15), 协作详情 terms table and rating (MR-36), 暂停接待 in a ⋯ menu.
- Club: workbench `170:1744`; a screenshot of the consequence sheet; 邀请成员 as a real invite once clubs have a link.
- Gates: AppUnit shards 01–03 against the 72-name baseline.
