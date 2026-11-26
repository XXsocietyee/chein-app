# Parity audit r11: account-publish (player side, 22 pages), against ui/combined-r7 @ b9a9d4d29

Brief: `origin/design/handoff-r2:docs/briefs/audit-r11.md`. Previous report: `origin/design/handoff-r2:docs/audit/parity-r10/account-publish.md` (on `82bcf2c2d`). Receipts read: `docs/release/receipts/fix-r10-acct-a.md`, `fix-r10-acct-b.md`. Review only: no product code was changed.

- **App:** `origin/ui/combined-r7` @ `b9a9d4d29` (588 commits after r10's `82bcf2c2d`, all 11 r10 lanes merged through round 3).
- **MP:** `origin/mp-source:chengyinhub-xcx/` (snapshot 2026-11-24). MP paths below are relative to that folder. This is the first round where the fix lanes' two "blocked: no MP source" rows (B-SZ-10, A8-03) can be read; both are now written up with MP lines.
- **Method:** the same 22 pages, function lines and formula as r10: ✅ = 1, ⚠️ = 0.5, ❌ / Core-only / unmounted = 0. Every r10 row was re-checked in code on `b9a9d4d29` (grep + read), not from receipts or commit messages. Where r10 did not record per-line weights, each r10 queue row is taken as one ⚠️ line (0.5 earned): a fix adds +0.5, a row moved to **merchant release** leaves the denominator (−1 line, −0.5 earned), and a new r11 row adds one line.
- **Scope (owner 11-26):** player + clubs. Merchant-only rows are marked `merchant release` and not counted. Money is ON in Release, virtual goods off. This area has no money path (ticket prices on the publish forms are authoring fields). Scoring is function + MP behaviour + "uses Apple components"; looks are not scored.
- **Native check:** the r10 grep (`CY*` components, `.buttonStyle(.cy…)`, gradients, shadows, `strokeBorder`, materials, `CYNight`, custom radii, `ScrollView` stand-ins) was re-run on every page file and the `App/MPGap/AccountPublish/*` mounts.

## 1. Headline

| | r10 | **r11** | Δ |
|---|---|---|---|
| Parity | 353/384 (92%) | **362.5/384 (94%)** | **+9.5** |
| Native | 0 native / 17 partly / 5 custom (39%) | **20 native / 2 partly / 0 custom (95%)** | +56 pts |
| P0 open | 0 | **0** | — |
| P1 open | 17 parity + 13 native = 30 | **6** (all parity) | −24 |
| P2 open | 11 parity + 16 native = 27 | **9** (6 parity + 3 native nits) | −18 |
| Merchant release (not counted) | — | **2** (C-T3c, A2-10 coop bar) | |
| Regressions | 0 | **0** | |

## 2. Per-page parity (r10 → r11)

| # | MP page | App screen | r10 | **r11** | Δ | native r11 | what moved |
|---|---|---|---|---|---|---|---|
| 1 | pages/member/index/index | AccountView + MemberHomeHeader | 24.5/32 | **25/32 (78%)** | +0.5 | native | A1-08 fixed. A1-02 open (owner). |
| 2 | pages/userinfo/userinfo | SocialPublicProfileView | 13/16 | **13/15 (87%)** | +0.5 −1 line | partly (nit N-30) | A2-02b fixed; A2-10 coop bar → merchant release. |
| 3 | pages/gerenziliao/gerenziliao | ProfileEditView | 16.5/19 | **17/19 (89%)** | +0.5 | native | A3-06 fixed. A3-10 partly, A3-05 owner. |
| 4 | pages/mylike/mylike | AccountCollectionFavoritesView | 19.5/20 | **19.5/20 (98%)** | 0 | native | N-05 held. |
| 5 | pages/address/address | ProfileParticipantsView | 12/12 | **12/12 (100%)** | 0 | native | |
| 6 | pages/addressinfo/addressinfo | ParticipantFormView | 11/12 | **11.5/12 (96%)** | +0.5 | native | A6-02 fixed. |
| 7 | pages/crop/index | MiniCropView | 15.5/16 | **16/16 (100%)** | +0.5 | native (canvas custom by exception) | A7-02 fixed. |
| 8 | pages/talent/list/index | ClubHomeView | 17.5/19 | **18.5/20 (93%)** | +1 (+1 line) | native | A8-02 fixed; A8-03 open; new A8-06. |
| 9 | pages/shezhi/shezhi | SettingsView | 23/23 | **23/23 (100%)** | 0 | native | B-SZ-10 now has MP order (queue only, not scored, as in r10). |
| 10 | pages/shezhi/about/index | SettingsAboutView | 10/10 | **10/10** | 0 | native | |
| 11 | pages/shezhi/marketing/index | AccountComplianceSheet (.marketing) | 12.5/13 | **13/13 (100%)** | +0.5 | native | B-MK-05 fixed. |
| 12 | pages/privacy/index | UsageConsentGateView / … | 22/22 | **22/22** | 0 | native | N-12 `Toggle` held. |
| 13 | pages/agreement/index | SettingsLegalDocumentView | 7/7 | **7/7** | 0 | native | B-AG-04 owner. |
| 14 | pages/deregister/index | AccountComplianceSheet (.cancellation) | 18/19 | **18/19 (95%)** | 0 | native | |
| 15 | subpackagePass/reveal/index | PassRevealView | 11.5/12 | **11.5/12 (96%)** | 0 | native | N-17 held (no `CYNight`/gradient/shadow). |
| 16 | pages/publish/fabu/index | ProjectEditView | 24/28 | **27/29 (93%)** | +3 (+1 line) | native (nit N-32) | C-F8b, C-F7d, C-F4, C-F14b, mode switch fixed; C-F1b partly; new C-F18. |
| 17 | pages/publish/temp/index | TemplateAuthoringView | 17.5/22 | **18.5/21 (88%)** | +1 −1 line | native | C-T5, C-T6b, C-T8b fixed; C-T3c → merchant release. |
| 18 | pages/publish/activity/index | ActivityPublishingView | 19/20 | **20/20 (100%)** | +1 | native (nit N-32) | C-A9-r7, C-A8b fixed. |
| 19 | pages/publish/template-intro/index | TemplateAuthoringIntroExperience | 6/7 | **6/7 (86%)** | 0 | partly (nit N-31) | |
| 20 | pages/square/detail/index | SquareDetailView | 21/22 | **21.5/22 (98%)** | +0.5 | native | C-S10b fixed. |
| 21 | pages/team/detail/index | TeamHomeView + TeamComponents | 19.5/20 | **20/20 (100%)** | +0.5 | native | Team avatars fixed. |
| 22 | pages/team/join/index | NativeNavigationCompletionViews | 12.5/13 | **12.5/13 (96%)** | 0 | native | |
| | **Area** | | **353/384 (92%)** | **362.5/384 (94%)** | **+9.5** | **95%** | |

History: round 1 71% → r7 80% → r8 86% → r9 91% → r10 92% → **r11 94%**.

Native grep on `b9a9d4d29`, area files: the only hits left are `SocialPublicProfileView.swift:377` (`.cyText(.sectionTitle)` on a stat number), `ClubHomeView.swift:345` (rounded thumbnail clip: accepted, system lists round thumbnails), `AccountComplianceViews.swift:629, :748` (`CYScreenOfflineWriteBanner` as a `Section` footer: intended by N-15/N-16), `ProjectEditView.swift:306` + `PublishingModesViews.swift:176` (`CYDomainPalette` tint), `SquareDetailView.swift:691` (`CYEmptyIllustration` = MP empty art inside `ContentUnavailableView`: accepted). `App/MPGap/AccountPublish/*` is clean.

## 3. r10 rows re-checked on b9a9d4d29

### Parity

| r10 id | sev | r11 status | evidence (file:line on b9a9d4d29, SHA) |
|---|---|---|---|
| C-T3c | P1 | **merchant release** | `from=citynode` posts `/api/merchant/city-node/template/submit` (MP temp/index.wxml:105-118). AccountPublishGapRound4Views.swift:150 keeps it off-screen. Not counted. |
| C-F1b | P1 | **partly** (5230eaa6a) | ProjectEditRichStoryForms.swift:101-120 gallery layout `Picker` + altText; :121-145 branch options with add/delete. Gallery cells are still typed URL `TextField`s (:114) → folded into new **C-F18**. |
| C-F8b (+N-18) | P1 | **fixed** (aa4a2904d) | ProjectEditView.swift:1052-1053 `ProjectEditTopicImageField`; AccountPublishR10Mounts.swift:13-111 `PhotosPicker` → uploader, bizType `image_3_4` / `image_16_9`. Centre-crop instead of the MP crop step → new P2 **C-F8c**. |
| C-F7d | P1 | **fixed** (2b94d90c5) | ProjectEditDetailForms.swift:91 → AccountPublishR9Mounts.swift:151-196 `Toggle` bound to `ProjectEditRuntimeActs`. |
| C-F2 (rest) | P1 | **open** (blocked: UI-test fixture) | ProjectEditPendingPresentation.swift:81 and ProjectEditStarterPresentation.swift:38 still `.typedCoordinates()`. Pending has `ProjectPendingNodePlacePickerEntry` (:80); starter has none. |
| C-F4 (rest) | P1 | **fixed** (e9de23527, 4c9e327cb) | ProjectEditView.swift:654-676 ⋯ `Menu` holds 存到本机 (`projectEdit.saveLocal` :663); :683-700 bottom bar 保存草稿 (saveCloudDraft) + 提交草稿. |
| C-T5 (rest) | P1 | **fixed** (812314637, ab7e24fda) | TemplateAuthoringView.swift:402-408 保存到此设备 inside the `templateEditorMenu.more` menu. |
| C-T2b | P1 | **open** (blocked: Core) | `TemplateAuthoringSupportPhase` / `TemplateAdoptionConfirmation` still have no producer outside Core/TemplateAuthoringDomain.swift:61, :66. |
| C-T6b | P1 | **fixed** (591d656cd) | AccountPublishR9Mounts.swift:114 `templateAuthoringEditor(adopting:from:scope:)`. The merchant 保存并绑定 label is merchant release. |
| C-T8b | P1 | **fixed** (ae8faa8c1, 9dd748d79) | TemplateGameplayPickerSheet.swift:12 推理 group from node-game-catalog. |
| A2-02b | P1 | **fixed** (bc03633cf) | AccountPublishR9Mounts.swift:53-73 probe `api/merchant/public-home` → `PublicMerchantHomeView`. |
| A2-10 | P1 | **merchant release** | AccountPublishR9Mounts.swift:64-67 coop bar gated by `PlayerLaunch.merchantCenterEnabled` (Lane G). Not counted. |
| A7-02 (rest) | P1 | **fixed** (8030f38c8) | ProfileLocalCoverSection.swift:255 `MiniCropView(ratio: "16:9")`; CreatorCropExportView.swift:21 for template media. |
| A1-02 | P1 | **open** (owner) | QuestifyApp.swift:409 `PassportView` still the 我的 root. |
| A1-08 | P1 | **fixed** (b16f12b43) | QuestifyApp.swift:410 `WelcomeView()` now renders `ContentUnavailableView` 登录后查看我的主页 + 登录 (WelcomeView.swift:73-76). |
| A3-06 / A6-02 | P1 | **fixed** (9270aa999, 565ebba9a) | ProfileEditView.swift:831-833 `saveProfile` on tap; ParticipantFormView.swift:362 saves on tap, the :383 alert is delete-only (:244). |
| A8-02 | P1 | **fixed** (7623036a3) | ClubCommunityViews.swift:187-194 `creativeSquareLane` merged via `readDiscoverFeed` (MP talent/list/index.js:76 全站帖文). r10 missed it. |
| A8-03 | P1 | **open** (now unblocked) | ClubHomeView.swift:132-176 still adds governance entries, 查找俱乐部, 我创建的俱乐部 and a 俱乐部活动 section. MP talent/list/index.wxml:57-95 has only 创建俱乐部 + one club list. |
| A3-05 | P1 | **open** (owner) | WeChat-only `bindgetphonenumber`. |
| B-MK-05 | P2 | **fixed** (3f81e65d5) | AccountComplianceViews.swift:729 sends on toggle; `MemberMarketingConsentConfirmSheet` only in DesignFixtures. |
| C-A9-r7 | P2 | **fixed** (48e12ac8c) | PublishingModesViews.swift:487 inline `PublisherIdentityRegistrationSection`. |
| C-A8b | P2 | **fixed** (f912b83c5) | PublishingModesViews.swift:453 no per-ticket 开始/结束. |
| C-F14b | P2 | **fixed** (f6ede0224) | ProjectEditView.swift:348 `ProjectEditTicketGap.count`. |
| C-S10b | P2 | **fixed** (2d9330c58) | SquareDetailView.swift:71, :712-721 medal images + sum. |
| Team avatars | P2 | **fixed** (085c11af4) | TeamComponents.swift:141-151 `memberAvatar` → `d_profile`. |
| Mode switch | P2 | **fixed** | ProjectEditView.swift:475-481, :756-757 local copy (复制并切换), no POST. |
| A3-10 | P2 | **partly** | ProfileCurrentAvatarView.swift:46, :78 cover + avatar + nickname; 更换背景 still on 我的 (ProfileLocalCoverSection). |
| C-F16-r7 | P2 | **open** (blocked: simulator) | ProjectEditView.swift:1046 name `TextField` without `axis: .vertical`. |
| B-SZ-10 | P2 | **open** (now unblocked) | See queue: order differs from MP shezhi.wxml:14-35. |
| B-AG-04 | P2 | **open** (owner, MP-first exception) | |

### Native (r10 N-rows)

All 29 r10 native rows (N-01 … N-29) were re-grepped. **27 fixed / held**, none regressed. Two leave small nits, re-queued as N-30 / N-31; the shared `CYDomainPalette` tint is N-32. Notable confirmations: N-12 `Toggle` (UsageConsentGateView.swift:57-59), N-17 no `CYNight`/gradient/shadow in PassMembershipViews.swift, N-19 alerts (ProjectEditView.swift:800-860), N-20 `Form` in `ScrollViewReader` (TemplateAuthoringView.swift:323), N-24 MapKit route map + `ShareLink`, N-26/27 TeamHomeView `List` + `.sheet` (the one `ScrollView` at :437 wraps the invite QR in a sheet: fine).

## 4. Open counts

| | count | ids |
|---|---|---|
| **P0** | **0** | — |
| **P1** | **6** | C-F18 (new), A8-03, C-F2 (rest), C-T2b, A1-02, A3-05 |
| **P2** | **9** | B-SZ-10, A8-06 (new), C-F8c (new), A3-10, C-F16-r7, B-AG-04, N-30, N-31, N-32 |
| merchant release | 2 | C-T3c, A2-10 |

## 5. Fix queue (input for fix round r11)

Columns: id | sev | MP file:line | app file:line | what to change | size. No money rows. No compiler in the cloud: every API named below already exists on the tip.

### P0

None.

### P1

| id | sev | MP file:line | app file:line | what to change | size |
|---|---|---|---|---|---|
| C-F18 (new; absorbs C-F1b rest) | P1 | pages/publish/fabu/index.js:1515-1540 `insertStoryImageAt` (`app.chooseImage(cb, 1)` → bizType `image_free`, app.js:654-685), :1733 `addStoryDreamImage` (album), :2104 `fillStoryGalleryCell`; audio :1553+ `app.chooseDocument` | App/ProjectEditRichStoryForms.swift:56 (image/audio block `ProjectEditReferenceField`), :62 (album image `TextField`), :114 (gallery cell `TextField`) | Replace the typed URL fields with a `PhotosPicker` that uploads through `\.playerContentImageUploader` (same pattern as `ProjectEditTopicImageField`, AccountPublishR10Mounts.swift:13-111) with bizType `image_free`, writing the returned url into the block field. Audio: `.fileImporter(allowedContentTypes: [.audio])` → same uploader if it accepts files, else leave audio as is and note it. Keep the existing accessibility ids. | M |
| A8-03 | P1 | pages/talent/list/index.wxml:57-95 (俱乐部 tab = 创建俱乐部 row + one list, created → joined → nearby; :64-65 comment: nothing else on this page) | App/ClubHomeView.swift:132-176 | Remove the governance-entries / 查找俱乐部 / 我创建的俱乐部 `Section` (:132-157) and the 俱乐部活动 `Section` (:158-176) from the tab root. If those destinations must stay reachable, put 查找俱乐部 in the toolbar (`magnifyingglass`) and leave the rest to club detail. Update the contract tests and XCUITests named in fix-r10-acct-b.md (A8-03 row). Needs a simulator run. | M |
| C-F2 (rest) | P1 | fabu node sheet (map place picker) | App/ProjectEditPendingPresentation.swift:81; App/ProjectEditStarterPresentation.swift:38 | Add a fixture `SearchMapReading` to the UI-test host, then drop `.typedCoordinates()` and use the `ProjectPendingNodePlacePickerEntry` picker in both. Update ProjectPendingNewChapter / ProjectEditStarter / ProjectEditPendingRestore UI flows. Simulator needed. | M |
| C-T2b | P1 | pages/publish/temp/index.wxml:66, :71-72 | App/OwnedTemplateConfigurationView.swift; Core/TemplateAuthoringDomain.swift:61, :66 | Cursor Core: add a producer for `TemplateAuthoringSupportPhase` and `TemplateAdoptionConfirmation`. Then App binds redacted / failed + 重试 and the pending adoption state. | M (Core) + S (App) |
| A1-02 | P1 | pages/member/index/index.wxml:6-7 | App/QuestifyApp.swift:409; App/AccountView.swift:93 | Owner decision: tabbed self profile as the 我的 root vs. today's PassportView + 个人主页 link. | owner |
| A3-05 | P1 | pages/gerenziliao/gerenziliao.wxml:54-56 | App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift:5 | Owner picks the iOS phone bind (SMS or none); WeChat-only API. | owner |

### P2

| id | sev | MP file:line | app file:line | what to change | size |
|---|---|---|---|---|---|
| B-SZ-10 | P2 | pages/shezhi/shezhi.wxml:14-35 (个人资料, 成为俱乐部主理人, 成为商家, 城瘾玩法, 我的收藏, 邀请与收益, 隐私与定位, AI 对话记录, 营销消息与优惠券, 帖文处置与申诉, 投诉建议, 我的申诉, 发票, 用户服务协议, 账号注销, 关于; then 退出账号 :42-47) | App/SettingsView.swift:201-260; App/SettingsSupportSections.swift:27-59 | Reorder to MP: move `NPCChatDataReadSettingsEntry` (:252) right after `SettingsPrivacyLocationEntry` (:217); put the marketing row of `AccountComplianceSettingsSection` next, then 帖文处置 (:253), 投诉建议 (:255), `MemberScoreAppealSettingsEntry` (:240), `SettingsInvoiceEntry` (:241), legal, 账号注销, 关于. App-only rows (notifications :218-224, usage consent :225, region :226, language :229-238, safety :257) go after 关于 and before 退出. Keep all ids. | S |
| A8-06 (new) | P2 | pages/talent/list/index.wxml:19 `nav-title` 发现 (owner 2026-10-29, index.js:59) | App/ClubHomeView.swift:48 `screenTitle = "club.title"` (俱乐部) | Title the tab root 发现 (new key) per MP; conflicts with design hand-off PL-11 ("title matches the tab"), so confirm with the owner first (MP-first rule says 发现). | S |
| C-F8c (new) | P2 | fabu topic-detail-sheet `chooseMedia` → crop page (app.js:681-685 `cropScale`) | App/MPGap/AccountPublish/AccountPublishR10Mounts.swift:106-111 | After the pick, present `MiniCropView(images:ratio:"3:4"/"16:9")` (already used at ProfileLocalCoverSection.swift:255) instead of centre-cropping, then upload the result. | S |
| A3-10 | P2 | pages/gerenziliao/gerenziliao.wxml:20-38 | App/ProfileCurrentAvatarView.swift:46-94 | Add 更换背景 to the first section (needs `ProfileLocalCoverOwner` threaded through the `ProfileEditView(` call sites). | M |
| C-F16-r7 | P2 | pages/publish/fabu/index.wxml:103-117 | App/ProjectEditView.swift:1046 | `axis: .vertical` on the name; switch the 45 XCUITest `textFields["projectEdit.name"]` refs to `textViews`; simulator needed. | S (+ tests) |
| B-AG-04 | P2 | — | App/SettingsLegalDocumentView.swift | Owner: app-only legal wording (MP-first exception). | owner |
| N-30 | P2 | pages/userinfo/userinfo.wxml (stats) | App/SocialPublicProfileView.swift:377 | `.cyText(.sectionTitle)` → `.font(.headline)`. | S |
| N-31 | P2 | pages/publish/template-intro/index.wxml | App/TemplateAuthoringIntroExperience.swift:108-147 | Custom HStack/VStack card row → `List`/`Section` rows (image + caption + title) or a plain `Grid`; keep `creatorIntro.example.*` ids. | S |
| N-32 | P2 | — | App/ProjectEditView.swift:306; App/PublishingModesViews.swift:176 | `CYDomainPalette(.topicEditor)` → `.tint`/semantic colours if only accent use remains. | S |

## 6. Regressions

None. Every r10 fix and every r9 fix that r10 confirmed (C-F5b cast/look carry-over Core/ProjectEditContract.swift:12; C-T3 Round4 mount TemplateAuthoringView.swift:603; A4-04b `R9PublicShareButton` ClubHomeView.swift:199 / PlayerGapViews.swift:406-411; A6-01b ParticipantFormView `participantBoundPhone`; A7-08b MiniCropView.swift:111 `retryCurrent()`; B-PV-04 / N-12 `Toggle`) is still in code on `b9a9d4d29`.

## 7. Notes for the r11 fix lanes

- B-SZ-10 and A8-03 were "blocked: no MP source" in r10. The MP is now on `origin/mp-source:chengyinhub-xcx/`; the lines are in the queue above.
- A1-02, A3-05, B-AG-04, A8-06 need an owner call; C-F2, C-F16-r7, A8-03 need a simulator; C-T2b needs Cursor Core.
- The talent/list feed card for 通票 (MP index.wxml:31-39) is present as `MPPassExploreCard` (ClubHomeView.swift:77). Purchase from it is virtual goods (off in Release) and is not scored here.
