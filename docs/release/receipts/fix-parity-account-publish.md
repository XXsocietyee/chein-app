# Receipt: fix-parity r1 — account-publish

Brief: `origin/design/handoff-r2:docs/briefs/fix-parity-r1.md`. Findings: `origin/audit/parity-account-publish:docs/audit/parity/account-publish.md`.
Branch `fix/parity-account-publish`, cut from `origin/ui/combined-r4` (0443305c8). No Swift toolchain in the cloud: every change
follows existing patterns and is unverified by a compiler; the local integrator should build it.

## Gates (run on the branch head)

| gate | result |
|---|---|
| `python3 -B tools/check_scaffold.py` | PASS (AppSession.swift kept at its 8171-line ratchet) |
| `python3 -B tools/check_design_lint.py` | PASS; typography lint lowered (raw text style 1181 → 1169, back chevron 15 → 14, hidden back 15 → 14, large title 26 → 20); baseline updated with `--update` after lowering |
| `python3 -B tools/contract_ratchet.py --check` | the base itself (`origin/ui/combined-r4`) reports 11 new failures against the baseline; this branch adds **none** beyond those 11 (compared id by id). Source pins changed on purpose are listed under "Tests touched". |

## Status per finding

Legend: **fixed** · **partial** (what is left is named) · **blocked-backend** · **deferred** (not started; plan kept from the audit) · **owner** (waits on an owner ruling listed in the audit; not coded).

### P0 (18)

| id | status | files | local verification |
|---|---|---|---|
| A2-01 | fixed | Core/MiniProgramPageLink.swift, App/MPReviewedPageScreen.swift | open `chein://mp/pages/userinfo/userinfo?userId=<id>&tab=about` → profile opens on 关于 |
| A3-01 | deferred | — | needs an upload path for 探索作品 (≤ 9) and 联系二维码: new draft fields in `Core/ProfileEditContracts.swift`, payload + review summary, reuse `ProfileAvatarUploadClient`; the avatar contract tests pin those files byte-for-byte, so this wants its own slice |
| A4-01 | partial | App/PlayerGapViews.swift | 我的 › 据点收藏: 56 pt cover, swipe / long-press 取消收藏 → confirm → row leaves only when the server answers `favorited=false`, error line otherwise. Left: tap → place detail (the app has no standalone poi-detail page) and node share |
| B-SZ-01 | fixed | App/SettingsView.swift, Localizable (`profile.complaint.title` → 投诉建议) | 设置: 投诉建议 row after 帖文处置与申诉 |
| B-PV-01 | fixed | Core/OwnMediaStatus.swift, Core/OwnMediaReview.swift, App/OwnMediaStatusButton.swift, App/SettingsPrivacyLocationView.swift, App/AppCompositionRoot.swift, OwnMediaStatus.xcstrings | TEST account with a REJECTED asset: 设置 › 隐私与定位 › 我的待审媒体 shows 重新提审; tap → list re-reads. Rides the existing own-media status approval (no new route mark; see "Gate review") |
| C-F1 | deferred | — | `branch` / `gallery` / `line` story blocks + dialogue speaker: new `ProjectEditBlock.Kind` cases, wire mapping in `Core/ProjectEditStoryContract.swift`, editors; too wide for a blind edit |
| C-F2 | partial | App/ProjectEditDetailForms.swift, ProjectEditPendingPresentation.swift, ProjectEditStarterPresentation.swift | node editor: no 经度/纬度 fields, a 地点 row says 已在地图上选定 / 还没选地点 next to the place picker. Left: the two new-node sheets (pending / starter) still type coordinates because they have no picker (`typedCoordinates()`) |
| C-F5 | deferred | — | cast editor + `/api/topic/cast/voice` (no Core contract yet) |
| C-F6 | deferred | — | free-explore visit config `/api/topic/free-explore/visit-config` (no Core contract yet) |
| C-T1 | fixed | MPReviewedPageScreen, App/TemplateAuthoringView.swift (`startsInEditor`) | `chein://mp/pages/publish/temp/index?id=<own template>` → owned template editor; bare path → editor, not the intro |
| C-T2 | fixed | App/OwnedTemplateConfigurationView.swift | template by id with reads off / failing: 玩法详情加载失败 or 当前请求无法读取玩法, 重新加载, 查看我的玩法 |
| C-T3 | deferred | — | 状态不好时松一点, 可触发的结果, 扫完回复, `from=citynode` 玩法形态 rows |
| C-A1 | fixed | MPReviewedPageScreen, App/SessionPublishingModesView.swift (`SessionActivityPublishingDestination`) | `…/pages/publish/activity/index` → 发布活动 form; `?id=` → activity editor |
| C-S1 | fixed | App/SquareDetailView.swift, App/SquareRelatedTopicView.swift | a template post's detail shows the play card: 可直接开局的模板, 看看模板 (only while the topic-template write is live), 试玩 |
| C-S2 | fixed | Core/SquareContracts.swift (`isBookmarked`), App/SquareDetailView.swift | community post: star fills when saved, VoiceOver says 取消收藏 / 收藏帖文 and selected |
| C-D1 | fixed | MiniProgramPageLink, MPReviewedPageScreen | `…/pages/team/detail/index?teamId=<id>` → that team |
| C-D2 | deferred | — | applicant review exists only in the nearby-team view and requires the team in that coordinator's nearby list. Needs `NearbyTeamCoordinator` to adopt the leader's team from detail (or a team-scoped review owner) |
| C-J1 | fixed | Core/NativeNavigationCompletion.swift, MiniProgramPageLink, App/NativeNavigationCompletionViews.swift | `…/pages/team/join/index?entry=code` → 加入码 field (≤ 40, 粘贴队长给的加入码) + 下一步; same screen from 我的队伍 |

### P1 done in this pass

| id | status | files | local verification |
|---|---|---|---|
| A1-03 | fixed | MemberHomeHeader.swift | 我的 name at 18 bold |
| A1-06 | fixed | AccountView.swift | 我的 › 邮票 → stamp album, 勋章 → badge wall |
| A1-11 | fixed | MemberProfile.xcstrings | default name 城瘾玩家 |
| A2-05 | fixed | SocialPublicProfileView.swift, `social.profile` → 个人主页 | inline title 个人主页 |
| A2-06 | fixed | SocialPublicProfileView.swift (`initialTab`) | link `tab=about` / `achievements` / `projects` |
| A3-02 | fixed | ProfileEditView.swift (`cyGuardedBack`) | clean editor: system back + swipe; dirty: guarded back asks |
| A3-03 | fixed | ProfileEditView.swift, `profile.edit.title` → 个人资料 | inline 个人资料 |
| A3-08 | fixed | ProfileEditView.swift (`initialField`), MPReviewedPageScreen | `gerenziliao?field=introduction` opens the intro editor |
| A4-03 | fixed | AccountCollectionFavoritesView.swift | one inline 我的收藏 title |
| A5-02 | fixed | MPReviewedPageScreen | `pages/address/address` link can add / edit / delete |
| A8-04 | fixed | ClubHomeView.swift (`initialTopTab`), MPReviewedPageScreen | `talent/list?tab=feed` opens 帖文 |
| B-AB-01 | fixed | SettingsAboutView.swift, `settingsNative.about.entryHint` | no 我的二维码 block until a code exists |
| B-AB-02 | fixed | SettingsAboutView.swift | inline 关于 |
| B-AB-03 | fixed | SettingsAboutView.swift | no phone → 联系我们 row to the support contact page |
| B-AG-01 | fixed | SettingsLegalDocumentView.swift | one inline title, no second in-content title |
| B-AG-02 | fixed | MiniProgramPageLink, MPReviewedPageScreen | `agreement/index?type=cancellation_notice` |
| B-DR-01 | fixed | AccountComplianceViews.swift | no 「影响清单尚未取得…」 line; request ids and the on-device consent record under 详情 |
| B-MK-02 | partial | AccountCompliance / Localizable / MarketingConsentOriginalPresentation xcstrings | copy fixed (站内活动消息, 商家优惠券, 还没有商家消息); the extra explanation / scope / header text is still on the page |
| B-MK-04 | fixed | MPReviewedPageScreen | `shezhi/marketing/index` link opens the page (no close button) |
| B-SZ-02 | fixed | AppSession.swift, SettingsAccountEntries.swift | airplane mode → 退出账号 → still signed in, red line 退出没有完成…; online → signs out once |
| B-SZ-03 | fixed | SettingsView.swift, SettingsSupportSections.swift | one 「AI 对话记录」 row |
| B-SZ-04 | fixed | SettingsView.swift | signed-out row opens sign-in |
| B-SZ-06 | fixed | Localizable (`settings.signOut` 退出账号), MemberScoreAppealList (`score.mine.title` 我的申诉) | Settings labels |
| B-SZ-08 | partial | SettingsView.swift | subtitle → meta; name / initial fonts left |
| B-SZ-12 (P2) | fixed | MiniProgramPageLink, MPReviewedPageScreen | `shezhi?scene=settings-deregister` → 账号注销 |
| B-PR-01 | fixed | PassMembershipViews.swift | 开始 disabled without a destination |
| C-A3 | fixed | PublishingModesViews.swift | one inline 发布活动 title |
| C-A5 | fixed | PlayerGapViews.swift, `playerGap.publish.signIn` → 登录后发布活动 | signed out: 去登录 |
| C-A6 | fixed | PublishingModesViews.swift | merchant account runs the merchant precheck |
| C-D3 | fixed | TeamHomeView.swift | non-leader sees 举报队伍 (when its access is on) |
| C-D4 / C-J4 | fixed | TeamHomeView.swift, `team.invitation` → 加入队伍 | inline titles |
| C-D6 | fixed | TeamHomeView.swift | 进度/排名 above 退出/解散 |
| C-D8 (P2) | fixed | `team.members.title` → 队伍成员 | — |
| C-F4 | partial | `projectEdit.saveLocal` → 存到本机 | label no longer claims 保存草稿; the bar does not yet save a server draft |
| C-F9 | fixed | ProjectEditView.swift, `projectEdit.signIn` → 登录后创建主题 | 去登录 |
| C-F11 | fixed | MPReviewedPageScreen, Core/ProjectEditRemoteTarget.swift | `fabu?id=` (edit-detail), `mode=2`, `clubId=`, `scope=MERCHANT` (merchant accounts only) |
| C-F12 | partial | ProjectEditView.swift | four raw fonts → tokens |
| C-I1 – C-I4, C-I7 | fixed | MPReviewedPageScreen, TemplateAuthoringView.swift, TemplateAuthoringIntroExperience.swift, CreatorIntroExamples | template-intro link; no hero on the intro; no empty sentence; both value lines 22 bold ink; 重试 |
| C-J3 | partial | `team.join` → 接受邀请并加入 | label fixed; the review sheet before joining stays |
| C-S6 | partial | SquareDetailView.swift | comment meta font |
| C-S7 | fixed | SquareDetailView.swift, `square.detail` → 动态 | inline 动态 |
| C-T6 | partial | `templateAuthor.reviewPublish` → 发布玩法 | 保存并绑定 variant left |
| C-T7 | fixed | TemplateAuthoringView.swift, `templateAuthor.signIn` → 登录后编辑玩法模板 | 去登录 |

### P1 not done (deferred unless marked)

owner: A1-02, A1-08, A3-06, A6-02, A8-02, A8-03, B-SZ-07, B-PV-04 (audit "Decisions for the owner").
deferred: A1-01, A1-04, A1-05, A1-07, A2-02, A2-03, A2-04, A3-04, A3-05, A3-07, A4-02, A4-04, A4-05, A5-01, A5-03, A6-01, A7-01 – A7-04, A8-01,
B-SZ-05, B-SZ-09, B-MK-01, B-MK-03, B-PV-02, B-PV-03, B-DR-02 – B-DR-06, B-PR-02, C-F3, C-F7, C-F8, C-F10, C-F13, C-T4, C-T5, C-T8, C-A2, C-A4,
C-S3, C-S4, C-S5, C-D5, C-D7, C-J2. C-F3 / C-T4 (back rule on the topic and template editors) need a dirty flag first: both guards save to the
device on every exit, so switching to the system back while "clean" would skip that save.

## Backend needed

None new. B-PV-01 uses the existing `POST /api/media/asset/{id}/retry` (`ApiMediaAssetController.retry`).

## Gate review (not changed here)

`/api/media/asset/{}/retry` has no mark in `ChinaReviewedRouteCapability`; per the owner rule the reviewed route gate stays as it is. The
transport admits the retry only under the own-media status approval (`OwnMediaReadApproval.allowsStatus`), so production behaviour follows
that approval. If the gate review wants an explicit mark, add it there.

## Shared / DesignSystem changes

None in `App/DesignSystem`. Shared Core: `MiniProgramPageLink` (rules + value sets), `NativeNavigationCompletion` (`entry=code`),
`ProjectEditRemoteTarget.init(topicID:owner:readerScope:)`, `SquarePost.isBookmarked`, `OwnMediaRetryRoute` / `OwnMediaRetryWriting`.
`SquareRelatedTopicLink` gained an optional `titleKey`.

## Tests touched

- `Tests/CoreTests/MiniProgramPageLinkTests.swift`, `Tests/AppUnitTests/MPParityDeepLinkRouteTests.swift`: rows for the new query keys and rejections.
- `Tests/ContractChecks/test_profile_exit_discard.py`: pins the guarded back instead of the hidden back (A3-02, intended).
- `Tests/ContractChecks/test_p02_editor_presentation_closeout.py`: field label pinned at `.cyText(.label)` instead of raw `.subheadline` (C-F12).
- `Tests/ContractChecks/test_template_intro_experience.py`: `creatorIntro.empty` is no longer rendered (C-I3), three named-table keys.
- `Tests/ContractChecks/test_mylike_page_ready.py`, `test_square_detail_page_ready.py`: 「收藏帖文」 is no longer missing copy (C-S2).
- XCUITests that type 经度/纬度 in the node editor (`ProjectPendingNewChapterFlowTests`, `ProjectEditStarterFlowTests`,
  `ProjectEditPendingRestoreFlowTests`) run in the pending / starter sheets, which keep coordinate entry; not run here.
