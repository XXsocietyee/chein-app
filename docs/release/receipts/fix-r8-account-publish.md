# Receipt: fix-r8 account-publish (Claude App)

- **Branch:** `fix/r8-account-publish`, from `origin/ui/combined-r7` @ `f5f3006d7`. `ui/combined-r7` was merged again before every push; it had no new commits during this run.
- **Queue:** `origin/audit/parity-r8-account-publish:docs/audit/parity-r8/account-publish.md`. Brief: `docs/briefs/fix-r8.md` on `design/handoff-r2`.
- **Layer:** App only. No Core types changed and no type redeclared. New App code is in one file, `App/MPGap/AccountPublish/AccountPublishR8Mounts.swift`, which `tools/generate_project.py` already covers through its `App/MPGap/**` glob. The coordinator still has to regenerate the project so the target picks up the new file.
- **Strings:** 69 new `fixr8.*` keys (en + zh-Hans) in `docs/port/strings/fix-r8-account-publish.json`. They are also inserted, in sorted position, into `Resources/Localizable.xcstrings`, so `test_localization_key_catalog_contract` stays green; no key clashes. The 5 A-COPY-r8 overrides went straight into the catalog too.
- **Safety:**
  - No money path was touched.
  - No new gate was added.
  - Voice preview stays off, per owner decision #7 (fixture cast, no live cast calls).
  - Nothing was pushed to `main`, `ui/main` or `ui/combined-*`.

## Closed rows

| id | sev | what changed | files |
|---|---|---|---|
| C-D2 | P0 | Mounted `TeamDetailGapApplicantsSection` for the leader of a recruiting team, with the real `teamID`. Loads `POST /api/team/applications {teamId}`, decoding rows with `NearbyApplicant` (the same row shape as the map half-sheet, per MP js:340). States: `入队申请 · N`, loading, `入队申请没读到` + 重试, `暂无申请`. Rows show the avatar (`d_profile` default), name and message. 拒绝 uses the MP `team.reject` danger confirm, 同意 runs straight away, and both go through `teamHandleRequest`. A `REJECTED` receipt shows its message, and the list reloads after every action. Rows are 44 pt with VoiceOver labels `拒绝 / 同意 {name}`. | App/TeamHomeView.swift, App/MPGap/AccountPublish/AccountPublishGapViews.swift, AccountPublishR8Mounts.swift |
| C-F5 | P0 | 角色 card on fabu: switch + 角色列表 + 「N 位」, opening the cast editor sheet. Shown for city themes only, never in WHITELIST (MP wxml:172). The editor covers name (≤ 8), one-line identity (≤ 30), voice preset (MP PRESETS + 不出声), add (≤ 12) and swipe-to-delete. It stores the MP `castConfig` shape in `draft.preserved["castConfig"]` and keeps member fields it does not edit: avatar, colour (MP's six literals), clues and ending lines. The 试听 button is hidden per owner decision #7. | App/ProjectEditView.swift, AccountPublishGapViews.swift, AccountPublishGapRound4Views.swift, AccountPublishR8Mounts.swift |
| A4-01 | P0 | Each 据点 favourite row is now a NavigationLink to `subpackageRoam/poi-detail/index?poiId=` (MP mylike.js:435). The new MPReviewedPageScreen case opens the same `RoamItemDetailView` the map uses, seeded by `poiId` only; the detail view reads `roamNodeDetail(id:)` itself. Both `poiId` and the canonical `id` are accepted. | App/PlayerGapViews.swift, App/MPReviewedPageScreen.swift, AccountPublishR8Mounts.swift |
| A-COPY-r8 | P1 | Catalog values: `social.interests` 兴趣标签, `profile.incompleteLink.backHome` 返回, `participant.form.save` 保存参与人信息, `participant.form.add` / `participant.form.edit` 参与人信息. | Resources/Localizable.xcstrings |
| B-DR-04b | P1 | The notice step runs the read-only `deregister/precheck` on entry, so blockers show above the agreement in the same BLOCKED card copy, with 我已处理，重新检查. 下一步 stays disabled while blockers remain. The agreed precheck on 下一步 is unchanged. | App/AccountComplianceViews.swift |
| A1-01 | P1 | The 有什么新鲜好玩的分享吗？ row (`MPAsset.FeatureIcon.iconPen`, 44 pt) shows on the 帖文 tab of your own profile only and opens `SquareCloudComposerView`. The join-date part is dropped. | App/SocialPublicProfileView.swift, AccountPublishGapViews.swift, AccountPublishR8Mounts.swift |
| A7-01/03/05 | P1 | `MiniCropView`: the whole image stays visible under a dimmed mask. The frame-sized cut-out comes from `MiniCropGeometry.frame(ratio:)` and shows the rule-of-thirds grid or a circle (new `shape:` parameter). The crop-frame `.clipped()` is gone; only the canvas edges clip. 还原 resets to scale 1, centred, through `session.applyGesture(scale: 1, x: 0, y: 0)`, so Core needs no `reset()`. | App/MiniCropView.swift, AccountPublishGapRemainingViews.swift |
| A7-02 | P1 (avatar part) | The avatar crop now goes through MiniCropView (1:1, circle). Its source rect maps back onto `MerchantImageCropRect(.logo)` and the existing renderer. | App/ProfileAvatarDraftSection.swift |
| C-F7 | P1 (App part) | 添加序章 / 编辑序章 next to 添加章节 (city only; 添加 is hidden in WHITELIST), creating an opening chapter like MP `_createChapterDirect('', true)`. A 画面风格 section offers style (星尘 / 纸本 / 末世 / 夜城), 主题配色 (unset, or the 5 MP palettes) and 故事字体. It writes the MP `look` JSON string into `draft.preserved["look"]`, resets a style's params to MP defaults when the style changes, and keeps the other keys. Hidden in WHITELIST. 结局章 was already mounted. | App/ProjectEditView.swift, AccountPublishR8Mounts.swift |
| C-A4 | P1 | Step 3 (合作者) reads `/api/user/info` and shows 发起人信息未加载 / 发起人信息加载失败，请重试 + 重试 only when the read fails (MP wxml:135, js:1302). | App/PublishingModesViews.swift, AccountPublishR8Mounts.swift |
| C-D11-r7 | P1 | 保存图片 under the team code image opens the in-page privacy notice (`TeamDetailGapSaveInviteImageRow`). It then downloads the server image (https only) and adds it to Photos (add-only, existing `NSPhotoLibraryAddUsageDescription`), and reports 已保存到相册 or 保存失败，请重试. | App/PlayerGapViews.swift, AccountPublishGapRound4Views.swift, AccountPublishR8Mounts.swift |
| A2-03b | P2 | `\.socialConversationDestination` is injected once at the session root (`chain2`), so 发消息 opens the chat in place from square, club, activity and every other `SocialPublicProfileView` host. | App/QuestifyApp.swift |
| A2-08 | P2 | Own profile only: club posts (`POST /api/club/post/feed {scope:all, author:me, limit:20}`) follow the community posts. A row opens `pages/club/detail?id=&postId=`. | App/SocialPublicProfileView.swift, AccountPublishR8Mounts.swift |
| A4-05b | P2 | 分享 (44 pt `ShareLink`, public posts only via `PublicContentShareLink.squarePost`) beside the ··· menu on favourite post cards. | App/AccountCollectionFavoritesView.swift |
| B-SZ-12b | P2 | `?scene=settings-identity-picker` opens 选择要申请的身份, showing the identity application rows on their own page. It covers loading, signed-out, denied, failed + 重试, and none-available. | App/MPReviewedPageScreen.swift, AccountPublishR8Mounts.swift |
| C-I9-r7 | P2 | Template-intro covers drift slowly, each on its own period, and stay still under Reduce Motion. | App/TemplateAuthoringIntroExperience.swift, AccountPublishR8Mounts.swift |
| A5-01 | P2 | Removed the dead `onSelect` select mode from `ProfileParticipantsView` (no callers). 报名 keeps its one participant sheet. | App/ProfileParticipantsView.swift |

## Not done, with reasons

| id | why | next |
|---|---|---|
| A2-10-r7 (coop bar) | The bar must show only when the viewed subject is a merchant (MP `isMerchantView && !isSelf`), and the app cannot tell yet. That depends on A2-02 (Core decode of role / merchant id). The `pages/coop/invite` screen already exists. | After A2-02: mount `SocialPublicProfileGapCoopBar` in a bottom `safeAreaInset` → `MPReviewedPageScreen(page: "pages/coop/invite/index", query: ["type": "0", "toId": …])`. |
| A7-02 (cover 16:9, template crop) | Both already have their own gesture/slider croppers, pinned by `ProfileLocalCoverFlowTests`, `ProfileCoverCropGesturesAppTests`, `test_profile_local_cover.py` and `test_template_image_crop.py` (`template.imageCrop.*` ids). Rerouting them through MiniCropView means changing Tests/ as well. | Cursor (Tests/) + Claude, in one change. |
| C-F8 | No upload target exists for the topic cover, gallery or rich-media URL fields; `RetainedImageScope.Destination` has no topic case. Uploads also wait on the owner's upload grant (A3-01). | Cursor: topic cover/gallery destinations; then Claude swaps `ProjectEditReferenceField` for PhotosPicker. |
| C-F2 (rest), C-F4 (rest), C-T5 (rest), C-F16-r7 | Each one moves or retypes a control that 3 / ~20 / 6 / several XCUITests address directly: `.typedCoordinates()`, `projectEdit.saveLocal`, `templateAuthor.saveLocal`, and the name `TextField` → text view. Changing the App alone would turn those suites red, and Tests/ is Cursor's layer. | One coordinated change with Cursor's test update. |
| C-F7 由工作人员开幕 | Lives in `themeRuntimeConfig.gameplayRuntime.acts[].hostUnlock` (MP theme-runtime-structure.js:215). The app has no runtime-structure model. | Cursor: runtime acts model. |
| C-I5 (rest) | The intro hosted outside the Form on a dark stage is a structural restyle of `TemplateAuthoringView` (restore section, step switch). It is visual only. | `restyle/*` agent for publish. |
| A3-10, B-PR-03 | Already done by `fix/r3-account-publish-a` round 4 (A3-10) and `fix/r3-account-publish-b` round 4 (B-PR-03); those commits are not on r7 yet. | Integrate round 4. |
| B-SZ-10 | Waits on owner decisions B-SZ-11 and B-SZ-13. | Owner. |

## For Cursor (Core / Tests)

1. **`castConfig` and `look` on the save contract.** Add both to `ProjectEditContract.topicCarryOver` (load and save). The App already writes them in MP shape to `draft.preserved["castConfig"]` (object) and `draft.preserved["look"]` (JSON string). Today they persist only in local drafts.
2. **A2-02.** Decode the subject's role and merchant id from `api/user/public-info`. That unblocks A2-10 (发起合作 bar) and the merchant swap.
3. **Topic media upload destinations** (cover / gallery / rich media) for C-F8, after the owner's upload grant.
4. **Runtime acts model** (`themeRuntimeConfig.gameplayRuntime.acts[].hostUnlock`) for 由工作人员开幕.
5. **Tests to move with the App:**
   - C-F2: the 3 XCUITests on `.typedCoordinates()`.
   - C-F4: the ~20 tests on `projectEdit.saveLocal`.
   - C-T5: the 6 tests on `templateAuthor.saveLocal`.
   - C-F16: `ProjectEditFlowTests` for the name field.
   - A7-02: the cover and template crop pins.
6. **Optional:** `MiniCropSession.reset()`. The App gets the same result from `applyGesture(scale: 1, x: 0, y: 0)`, so this is only for clarity.

## Other agents

- `fix/r3-account-publish-a/b` round 4 commits (not yet on r7) touch these files I also edit:
  - TeamHomeView: 1 line, the seat strip.
  - AccountComplianceViews: 1 line, the deregister row.
  - SocialPublicProfileView: +9 lines.
  - ProfileAvatarDraftSection: the upload tile.
  - AccountCollectionFavoritesView: 4 lines.
  - ProfileParticipantsView: 4 lines.
  - PublishingModesViews: 2 lines.

  None of their hunks overlaps mine, which are small and placed elsewhere in those files.
- Skipped as in flight elsewhere: `restyle/*` (visual), `cursor/*`, `gap/*`, `port/*`.

## Verification

- No compiler in the cloud. Every API used was grepped on `ui/combined-r7` first, including:
  - `CYEmptyState` inits, `CYLoadingState`, `CYStateKind.failure`, `NearbyApplicant`.
  - `AccountPublishContractLane` `send` / `userInfo` / `baseURL` / `token`, and `AccountPublishMPContract` `ownClubPostsRequest` / `ownClubPosts` / `deregisterPrecheckRequest` / `activityOwner` / `settingsAccess` / `homeAccount`.
  - `RoamItemDetailView.init`, `SquareCloudComposerView`, `PublicContentShareLink.l5Post`, `MPAsset.AvatarDefault.dProfile`, `MPAsset.FeatureIcon.iconPen`, `ProjectEditJSON` accessors.
- `Tests/ContractChecks` (all 826 files, `python3 -m unittest discover`): this branch fails exactly the same 222 tests as the `ui/combined-r7` base, with no new failures. Two new failures from the first run (catalog keys, and a bare `String(localized:)`) are fixed.
