# Receipt: fix-parity r2 — account-publish

Brief: `origin/design/handoff-r2:docs/briefs/fix-parity-r2.md`. Findings: `origin/audit/parity-account-publish:docs/audit/parity/account-publish.md`.
Round 1: `docs/release/receipts/fix-parity-account-publish.md`. Branch `fix/parity2-account-publish`, cut from `origin/ui/combined-r5` (65eb1def4).
No Swift toolchain in the cloud: every change follows existing patterns and has not been compiled; the local integrator should build it.

## Gates (branch head)

| gate | result |
|---|---|
| `python3 -B tools/check_scaffold.py` | PASS (4943 Swift files; new file `Core/ProfileMediaUpload.swift` registered in the project) |
| `python3 -B tools/check_design_lint.py` | PASS. Typography ratchet lowered with `check_typography_lint.py --update` after the sweep: raw text style 1173 → 1165, back chevron 12 → 10, hidden back 7 → 3 (decreases only) |
| `python3 -B tools/contract_ratchet.py --check` | The base (`ui/combined-r5`) itself fails 185 ids against the 184-id baseline (`test_workshop_paid_professional…bounded_paging` is new on the base). This branch fails the **same 185 ids**, compared id by id against a clean worktree of the base: no new failures. Pins changed on purpose are listed under "Tests touched". |

## Status per finding

Legend: **fixed** · **partial** (what is left is named) · **blocked-backend** · **deferred** (not started) · **owner** (waits on an owner ruling; not coded).

### Round-1 deferred / partial P0s

| id | status | files | local verification |
|---|---|---|---|
| A3-01 | fixed (needs the upload grant composed) | Core/ProfileMediaUpload.swift (new), Core/ProfileAvatarUpload.swift, Core/ProfileAvatarFlow.swift, Core/ProfileEditContracts.swift, Core/ProfileEditCoordinator.swift, Core/ProfileEditService.swift, Core/ProfileEditReviewSummary.swift, App/ProfileAvatarDraftSection.swift, App/ProfileEditView.swift, App/ProfileContactQREditor.swift, App/ProfileCasePortfolioSection.swift, App/ProfileDraftReviewSection.swift, Localizable | 我的 › 编辑个人资料 with `ProfileAvatarDependencies` injected (TEST account): 探索作品 › 添加作品图片 → pick → 上传 → 加入作品 → thumbnail + 移除 row; at 9 pictures in all the row reads 最多只能上传9张图片. 联系二维码 › 上传二维码 / 更换二维码 → 使用这张二维码 → status 将更换. 保存 → review lists 新增作品图片 n / 联系二维码 新上传的图片 → `/api/user/update` carries `casePics` = kept + `;` + new URLs and `wechat` = new URL. Without the dependencies (today's production composition, same as the avatar) the rows say 图片上传暂未开放，已保存的图片保持不变。 |
| A4-01 | partial (unchanged) | — | left: tap → place detail (no standalone poi-detail screen) and node share |
| C-F1, C-F5, C-F6 | deferred | — | new story block kinds / cast + voice / free-explore visit config: Core contracts and editors not started |
| C-F2 | partial (unchanged) | — | the pending sheet already mounts `ProjectPendingNodePlacePickerEntry`, so `.typedCoordinates()` there could go, but three XCUITests type 经度/纬度 in the pending and starter sheets and the starter sheet has no picker; left for a slice that can run those UI tests |
| C-T3 | deferred | — | 状态不好时松一点 / 可触发的结果 / 扫完回复 / `from=citynode` rows |
| C-D2 | deferred | — | needs `NearbyTeamCoordinator` to accept a leader team confirmed by the detail read (today `loadApplicants` and `allowed(.handle)` require the team in the nearby list); plan: `adoptLeaderTeam(teamID)` + a `TeamApplicationsSection` reusing the nearby review sheet |

### P1 fixed in this pass

| id | status | files | local verification |
|---|---|---|---|
| A3-04 | fixed | Core/ProfileFieldLimit.swift, App/ProfileTextFieldEditor.swift | 昵称 sheet: counter N/24, 完成 disabled above 24; 个人介绍 stays N/140 |
| A3-07 | fixed | Core/ProfileService.swift (`ProfileReadFailure.errorCode`), Core/ProfileEditService.swift, Core/ProfileEditCoordinator.swift, App/ProfileEditView.swift, Localizable | TEST server answering `/api/user/update` with `errorCode: NICKNAME_TAKEN` → status 这个昵称已被占用，换一个试试 and the nickname sheet reopens (live check + suggestions); `NICKNAME_INVALID` → 昵称不符合规则 |
| A1-05 | fixed | Core/SocialAccountContracts.swift, App/SocialPublicProfileView.swift, Localizable `profile.about.joinDate` | 个人主页 › 关于: 加入时间 2026.01.02 (createTime first ten chars); row hidden when absent |
| A2-04 / X5 | fixed | App/SocialPublicProfileView.swift | 个人主页 tabs are underline `CYTabs` (我的 only for self) |
| A4-02 | fixed | App/AccountCollectionFavoritesView.swift | 我的收藏 has no 删除我的帖文 block (still on 帖文详情 and 俱乐部) |
| A4-03 follow-up / X5 | fixed | App/AccountCollectionFavoritesView.swift | 我的收藏 帖文 / 主题 / 据点 are underline `CYTabs` |
| A5-03 | fixed | App/ProfileParticipantsView.swift | 参与人 page: inline title |
| B-MK-03 | fixed | App/AccountComplianceViews.swift | 营销消息 pushed from 设置: inline title 营销消息, no 34 pt in-content title |
| B-DR-05 | partial | App/AccountComplianceViews.swift | 账号注销 sheet: inline nav title instead of the in-content 34 pt title. Left: `CYSheetHeader` 22 pt and the notice/warning raw fonts (pinned by contract tests) |
| B-PV-03 | fixed | App/SettingsPrivacyLocationView.swift, App/PrivacyProtectionView.swift | 隐私与定位, 我的待审媒体, 隐私保护指引: inline system titles, no CYHeroHeader in content |
| B-SZ-08 | fixed | App/SettingsView.swift, App/AccountComplianceViews.swift | Settings account card and rows: no raw fonts left (chevrons on `.cyText(.meta)`) |
| C-F3 / X3 | fixed | App/ProjectEditView.swift (`locallySavedBytes`, `exitNeedsGuard`), App/ProjectEditExitGuard.swift | 主题编辑: open, change nothing → system back + edge swipe; type → guarded back; after the 0.4 s autosave the system back returns |
| C-T4 / X3 | fixed | App/TemplateAuthoringExitGuard.swift, Resources/CreatorExitGuard.xcstrings (`templateAuthorExit.back` removed) | 玩法模板编辑: clean (matches the on-device checkpoint) → system back; unsaved / unverified → guarded back with the existing confirm |
| X3 (NPC) | fixed | App/ProjectEditFlowParity.swift | 节点 NPC sheet: `cyGuardedBack(when: dirty)` instead of hidden back + 取消 |
| X3 (participant) | fixed | App/ParticipantManagementDetailView.swift | 参与人详情 keeps the system back while a delete runs (outcome lives in the shared coordinator) |
| C-A2 | fixed | App/PublishingModesViews.swift, Tests/AppUITests/PublishingModesFlowTests.swift | 发布活动 step 1: 场地名称 / 开始 / 结束 are read-only rows (— until 选择地点 / 选择时间段) |
| C-D5 | fixed | App/TeamHomeView.swift | leader's recruiting team: one 公开招募 switch; flip → existing review; cancel leaves it unchanged |
| C-F13 | fixed | App/ProjectEditView.swift, Localizable | 主题编辑 chapter cards: 剧情已写 / 缺剧情, N 个待选地点, 玩法 a/b chips |
| C-S3 | fixed | App/SquareDetailView.swift (`SquareDetailIssueView`), Localizable | 帖文详情 when the post fails: 社区暂未开放 / 没有找到这条帖文 (404) / 这条帖文暂不可用 / 动态加载失败 + 重试, each with 返回上一页 |
| C-S4 | fixed | App/SquareDetailView.swift | comment row: heart toggles the like in place, 回复 visible; ⋯ only when it holds 屏蔽 / 删除 |
| C-F10 | fixed | Core/ProjectEditCoordinator.swift, Localizable `projectEdit.quotaFull` | TEST club with themesRemaining 0: 主题编辑 opens, 保存草稿 works; 发布 → 在架已满，可先存草稿或下架旧项目 (other refusals keep 当前发布权限…) |
| C-S5 | fixed | App/SquareDetailView.swift | comment 举报: 44 × 44 target |

### Not done (deferred unless marked)

owner (unchanged from the audit): A1-02, A1-08, A3-06, A6-02, A8-02, A8-03, B-SZ-07, B-PV-04, B-MK-05, B-SZ-11, B-SZ-13.

deferred: A1-01, A1-04, A1-07, A2-02, A2-03, A3-05, A4-04, A4-05, A5-01, A6-01, A7-01 – A7-04, A8-01,
B-SZ-05, B-SZ-09, B-MK-01, B-MK-02 (rest), B-PV-02, B-DR-02, B-DR-03, B-DR-04, B-DR-06, B-PR-02,
C-F4 (rest), C-F7, C-F8, C-F12 (rest: the remaining raw fonts in ProjectEditDetailForms are pinned by contract tests), C-T5, C-T6 (rest), C-T8,
C-A4, C-S6 (rest), C-D7 (already on tokens at this base), C-J2 (needs the detail's `viewer` blocker / join `errorCode: TICKET_REQUIRED` modelled in Core), C-J3 (rest), all P2s.
The type codemod on `App/PublishingModesViews.swift` was reverted: that file's quick-route slice is hash-pinned by `test_activity_publishing_wizard`.

## Backend needed

None. A3-01 uses the existing `POST /api/common/uploadOSS` (bizType `image_free`, as the mini-program's `app.chooseImage` without a crop) and `POST /api/user/update` (`casePics`, `wechat`). A3-07 reads the existing `errorCode` (`NICKNAME_TAKEN` / `NICKNAME_INVALID`) of `/api/user/update`.

## Gate review (not changed here)

A3-01 reuses the avatar's checked upload capability end to end (`ProfileAvatarUploadClient` approval, `ProfileAvatarJournal`, `ProfileAvatarFlow`, the checked `saveAvatar` transport). Nothing new is composed: like the avatar, the uploads stay off until `ProfileAvatarDependencies` is injected by the reviewed composition.

## Shared / DesignSystem changes

None in `App/DesignSystem`. Shared Core: `ProfileReadFailure` gained an optional `errorCode` (init default nil); `ProfileEditDraft` / `ProfileEditPayload` gained `addedCasePictures`, `contactQRReplacement`, `stagedUploads`, `carriesUpload` (payload `wechat` / `casePics` became `private(set) var`); `ProfileAvatarTarget.init(mediaScope:…)`; `ProfileAvatarFlow` gained a `kind` (default `.avatar`); `ProfileEditReviewValue.newImage`; `SocialPublicProfile.joinDate`; `ProfileFieldLimit.nicknameMaxUTF16`. `ProfileContactQRSection` is now generic over an upload row (EmptyView convenience init kept).

## Tests touched

- `test_profile_avatar.py`: "image-bearing" now means any staged upload (`payload.carriesUpload`, `uploads.allSatisfy { permits }`); the ordinary-save comparison strips the new `errorCode` argument.
- `test_profile_case_portfolio.py`: readback ordering anchor `if carriesUpload`.
- `test_p02_editor_presentation_closeout.py`, `test_template_author_exit_guard.py`: pin `cyGuardedBack(when:)` instead of the hidden back; CreatorExitGuard catalog 7 → 6 keys.
- `test_pkg03_favorites_closure.py`, `test_account_collection_structure.py`: 我的收藏 tabs are `CYTabs` items.
- `test_square_detail_page_ready.py`: 动态加载失败 / 这条帖文暂不可用 / 没有找到这条帖文 left the "still missing copy" list.
- `Tests/AppUITests/PublishingModesFlowTests.swift`: the activity start row is found by identifier, not as a text field (not run here).
- Not run here and may need a look on device: XCUITests that tap `social.profile.tabs` as a menu (they fall back to the tab title), `ProfileAvatarTests` (Swift) still construct avatar-only drafts and should pass unchanged.
