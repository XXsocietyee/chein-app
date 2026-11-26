# Receipt: fix-r10-acct-a

Lane **acct-a**, branch `fix/r10-acct-a`, base `origin/ui/combined-r7` @ d9832ac50.
Brief: `origin/design/handoff-r2:docs/briefs/fix-r10.md`. Source: `origin/design/handoff-r2:docs/audit/parity-r10/account-publish.md` §4.

**Slice:** §4 has no P0. "P1 first half" = the first 15 of the 30 P1 rows in table order, which is the whole
"P1: parity" table except the last two (A8-02/A8-03 and A3-05 go to acct-b with the 13 "P1: native" rows).

The audit ran on 82bcf2c2d. Nine rows in this slice were already fixed on the tip by `fix/r9-account-publish`
(rounds 2-3); each was re-checked in code here (grep on d9832ac50), not taken from the old receipt.

**No compiler in the cloud:** Swift is unbuilt and XCUITests were not run. Every type/member used was grepped first.

## Rows

| Row | Status | SHA | App file:line | MP source | Note |
|---|---|---|---|---|---|
| C-T3c | **merchant release** | — | Core/TemplateAuthoringContract.swift:149; App/MPGap/AccountPublish/AccountPublishGapRound4Views.swift:150 | temp/index.wxml:105-118; `/api/merchant/city-node/template/submit` | `from=citynode` posts to a merchant endpoint; merchant center is gated off in Release. Also still needs a Core submit request (Cursor). |
| C-F1b | fixed (earlier) | 5230eaa6a | App/ProjectEditRichStoryForms.swift:101, :122 | fabu/index.wxml:484-604, 836-857 | Gallery (layout `Picker`, cells, altText) + branch editors are on the tip. Gallery cells are still image references; uploading them goes through the same uploader as C-F8b (follow-up). |
| C-F8b (+ N-18) | **fixed** | aa4a2904d | App/ProjectEditView.swift:1046-1048; App/MPGap/AccountPublish/AccountPublishR10Mounts.swift:13; App/PlayerContentImageUpload.swift:23 | fabu topic-detail-sheet chooseMedia; app.js:617-700, :654-683 | URL text fields → `PhotosPicker`, uploaded through the host `playerContentImageUploader` (`api/common/uploadOSS`) with bizType `image_3_4` (cover) / `image_16_9` (gallery, ≤9, joined with `,`, swipe to delete). Photos are centre-cropped to the ratio; the interactive crop page is **not** wired (partly vs. the MP crop step). |
| C-F7d | fixed (earlier) | 2b94d90c5 | App/ProjectEditDetailForms.swift:91; App/MPGap/AccountPublish/AccountPublishR9Mounts.swift:151 | fabu/index.wxml:1324-1334; theme-runtime-structure.js:215 | `Toggle` 由工作人员开幕 per chapter. |
| C-F2 (rest) | **blocked** | — | App/ProjectEditPendingPresentation.swift:81; App/ProjectEditStarterPresentation.swift:38 | fabu node sheet | Pending already has `ProjectPendingNodePlacePickerEntry` (:80); the starter has no picker target. The three UI flows (ProjectPendingNewChapter, ProjectEditStarter, ProjectEditPendingRestore) type 经度/纬度 to fill fixtures, and no UI test drives `projectPlace.*`. Needs a fixture `SearchMapReading` in the UI-test host plus a simulator run before the typed fields can go. |
| C-F4 (rest) | **fixed** | e9de23527, 4c9e327cb | App/ProjectEditView.swift:656 | fabu/index.js (saveDraft=1) | Bar = 保存云草稿 (saveDraft=1) + 下一步 / 提交草稿. 存到本机 is the first item of the ⋯ menu (`projectEdit.more`, now always shown). 15 UI test files go through the new `tapEditorMenuItem` helper (Tests/AppUITests/FailureScreenshot.swift); readiness helpers measure against 下一步. |
| C-T5 (rest) | **fixed** | 812314637, ab7e24fda | App/TemplateAuthoringView.swift:398 | temp/index.wxml:1492-1494 | 保存到此设备 moved from the form's last section into a toolbar ⋯ menu (`templateEditorMenu.more`). 7 UI test files + 3 source contracts updated (MP cited in each). |
| C-T2b | **blocked** | — | App/OwnedTemplateConfigurationView.swift; Core/TemplateAuthoringDomain.swift:61, :66 | temp/index.wxml:66, 71-72 | `TemplateAuthoringSupportPhase` / `TemplateAdoptionConfirmation` still have no producer in Core (no support-matrix read, no adoption state). Cursor Core first. |
| C-T6b | fixed (earlier) | 591d656cd | App/MPGap/AccountPublish/AccountPublishR9Mounts.swift:114; App/MPReviewedPageScreen.swift:289 | temp/index.js (from/scope); template-intro/index.js:296 | `templateAuthoringEditor(from:scope:)`. The merchant 保存并绑定 label is merchant release. |
| C-T8b | fixed (earlier) | ae8faa8c1, 9dd748d79 | App/TemplateGameplayPickerSheet.swift:12 | node-game-catalog.js:105-120 | 推理 group (排序 / 连线 / 分类). |
| A2-02b / A2-10 | fixed (earlier) | bc03633cf | App/MPGap/AccountPublish/AccountPublishR9Mounts.swift:57, :73, :80; App/MPReviewedPageScreen.swift:815 | cyp js:900-1040, wxml:578-582; userinfo.js:55-58 | `PublicMerchantHomeView` swap + 发起合作 bar. |
| A7-02 (rest) | fixed (on tip) | 8030f38c8 | App/ProfileLocalCoverSection.swift:255; App/TemplateMediaReviewPanel.swift:111 → App/CreatorCropExportView.swift:21 | app.js:617-700 | Cover (16:9) goes through `MiniCropView` (r9). Template media crops already go through `CreatorCropExportView` → `MiniCropView`; `TemplateImageCropView` has **no** App call site (dead, still pinned by contract checks). Not changed: the route-node photo crop (App/ProjectNodeImageCrop.swift, 4:3 sliders) is outside this row and its source is SHA-pinned by test_category_roam_registration. |
| A1-02 | **blocked (owner)** | — | App/QuestifyApp.swift:409; App/AccountView.swift:93 | member/index.wxml:6-7 | Making the tabbed self profile the 我的 root restructures the whole tab. That conflicts with the owner's "no visual redesign" pause (fix-r10 brief), and the `account.*` UI tests all start from the current root. Today 我的 → 个人主页 (`account.publicProfile`) opens the same `SocialPublicProfileView`. Needs an owner call + simulator. |
| A1-08 | fixed (earlier) | b16f12b43 | App/WelcomeView.swift:76 (mounted at App/QuestifyApp.swift:410) | member/index.wxml:6 | `ContentUnavailableView` 登录后查看我的主页 + 登录. |
| A3-06 / A6-02 | fixed (earlier) | 565ebba9a, 9270aa999 | App/ParticipantFormView.swift; App/ProfileEditView.swift | gerenziliao.wxml:94; addressinfo.wxml:49 | Save on tap, no confirm. |

## Gates (final push)

- `python3 tools/check_scaffold.py` → PASS structural checks.
- `python3 -B tools/check_a11y_lint.py` → PASS (0 new).
- `python3 -B tools/contract_ratchet.py --check` → my rows add **0** new failures. The run shows 1 "new" failure,
  `test_social_article_content…test_renderer_is_wired_only_to_existing_scoped_article_contents`, which also fails on a clean
  `origin/ui/combined-r7` worktree (d9832ac50): base issue, not touched here. Two failures my first pass caused were fixed:
  `test_global_chrome_domain_contract` (bar pin, 4c9e327cb) and `test_square_detail_page_ready` (更多操作 is pinned
  as missing copy, so the menu label is 更多, ab7e24fda).
- New file `App/MPGap/AccountPublish/AccountPublishR10Mounts.swift` → `python3 tools/generate_project.py` run.
- Strings: `fixr10.ap.*` (7 keys, zh-Hans + en) added to `Resources/Localizable.xcstrings`.

## For the coordinator

- The 22 UI test files touched for C-F4 / C-T5 are authored only. On first simulator run, check that
  `tapEditorMenuItem` finds the Menu item by identifier (`projectEdit.saveLocal` / `templateAuthor.saveLocal`).
- `ProjectEditTopicImageField` reads `\.playerContentImageUploader` (injected at App/QuestifyApp.swift:569). Without it
  (signed out / fixtures) the pickers are disabled and show 登录后可上传图片.
