# Parity audit r9: account-publish (22 pages), against ui/combined-r7 @ ebf6c160c

Brief: `origin/design/handoff-r2:docs/briefs/audit-parity-r9.md`. Rule: `owner-decisions-1124.md` (MP-first). Review only: no product code was changed.

- **App:** `origin/ui/combined-r7` @ `ebf6c160c` (2026-11-24 21:55 −0800). r8 audited `4ef0a2840`; 298 commits landed since then. These include `fix/r8-account-publish`, `cursor/r8-account-publish`, `cursor/wire3-account-publish` and `fix/r8-mp-first` (the `-cma` part).
- **MP:** `hengyin/chengyinhub-xcx` @ `06a1639d`. No file under the area's 22 pages changed since r8's base `3a131849e`, so no denominator changes.
- **Method:** the same 22 pages, function lines and denominators as r8 (`origin/audit/parity-r8-account-publish:docs/audit/parity-r8/account-publish.md`). Scoring: ✅ = 1, ⚠️ = 0.5, and ❌ / parked / compiled-but-unmounted = 0.
  - Every r8 queue row was checked in code on `ebf6c160c`. Receipts were not trusted.
  - Lines that are not re-scored keep their r8 status.
  - Under the MP-first rule, every former "owner decision" row is now an app fix that names the MP evidence. The exceptions are rows where the MP does not have the feature, or where its behaviour cannot run on iOS; each of those cites MP file:line.
  - No money path is in scope for this area.

## 1. Area parity

| # | MP page | App screen | r8 | **r9** | Δ |
|---|---|---|---|---|---|
| 1 | pages/member/index/index | AccountView + MemberHomeHeader | 23.5/32 | **24.5/32 (77%)** | +1 |
| 2 | pages/userinfo/userinfo | SocialPublicProfileView | 12/16 | **13/16 (81%)** | +1 |
| 3 | pages/gerenziliao/gerenziliao | ProfileEditView | 13.5/19 | **16.5/19 (87%)** | +3 |
| 4 | pages/mylike/mylike | AccountCollectionFavoritesView | 17.5/20 | **19/20 (95%)** | +1.5 |
| 5 | pages/address/address | ProfileParticipantsView | 11.5/12 | **12/12 (100%)** | +0.5 |
| 6 | pages/addressinfo/addressinfo | ParticipantFormView | 10/12 | **10.5/12 (88%)** | +0.5 |
| 7 | pages/crop/index | MiniCropView | 11/16 | **15/16 (94%)** | +4 |
| 8 | pages/talent/list/index | ClubHomeView | 17/19 | **17/19 (89%)** | 0 |
| 9 | pages/shezhi/shezhi | SettingsView | 22.5/23 | **23/23 (100%)** | +0.5 |
| 10 | pages/shezhi/about/index | SettingsAboutView | 10/10 | **10/10 (100%)** | 0 |
| 11 | pages/shezhi/marketing/index | AccountComplianceSheet (.marketing) | 12.5/13 | **12.5/13 (96%)** | 0 |
| 12 | pages/privacy/index | PrivacyProtection / UsageConsentGate / SettingsPrivacyLocation | 21/22 | **21.5/22 (98%)** | +0.5 |
| 13 | pages/agreement/index | SettingsLegalDocumentView | 7/7 | **7/7 (100%)** | 0 |
| 14 | pages/deregister/index | AccountComplianceSheet (.cancellation) | 17/19 | **18/19 (95%)** | +1 |
| 15 | subpackagePass/reveal/index | PassRevealView | 11/12 | **11.5/12 (96%)** | +0.5 |
| 16 | pages/publish/fabu/index | ProjectEditView | 21/28 | **23/28 (82%)** | +2 |
| 17 | pages/publish/temp/index | TemplateAuthoringView | 16.5/22 | **16.5/22 (75%)** | 0 |
| 18 | pages/publish/activity/index | ActivityPublishingView | 18.5/20 | **19/20 (95%)** | +0.5 |
| 19 | pages/publish/template-intro/index | TemplateAuthoringIntroExperience | 5.5/7 | **6/7 (86%)** | +0.5 |
| 20 | pages/square/detail/index | SquareDetailView | 21/22 | **21/22 (95%)** | 0 |
| 21 | pages/team/detail/index | TeamDetailView | 17.5/20 | **19.5/20 (98%)** | +2 |
| 22 | pages/team/join/index | TeamDetailView (invitation) + TeamInvitationEntryView | 12.5/13 | **12.5/13 (96%)** | 0 |
| | **Area** | | **329.5/384 (86%)** | **348.5/384 (91%)** | **+19 (+5 pts)** |

- **By group:**
  - A, member & profile: 116 → 127.5 /146 (79% → 87%).
  - B, settings, legal & pass: 101 → 103.5 /106 (95% → 98%).
  - C, publish, square & team: 112.5 → 117.5 /132 (85% → 89%).
- **History:** round 1 71% → r7 80% → r8 86% → **r9 91%**.
- No page regressed. Three pages held: talent/list (square merge and the club-hub share are App work that was not done), marketing (per-toggle confirm), and temp (the Core part landed, but the App did not mount it). square/detail and team/join also held; their one open line each (the medal pill, A8 share) did not move.

## 2. Open gaps

| | r8 open | fixed or closed since r8 | **r9 open** |
|---|---|---|---|
| P0 | 7 | 4 fixed, 1 downgraded to P1 (C-F1 is partly fixed) | **2** |
| P1 | 31 | 12 fixed or closed (+1 from C-F1) | **20** |
| P2 | 24 | 12 fixed or closed | **12** |

**By owner (P0 / P1 / P2):**
- Claude App: 1 / 17 / 11.
- Cursor Core: 1 / 2 / 0.
- Owner: 0 / 1 / 1. These are the two MP-first exceptions: A3-05, which cannot run on iOS, and B-AG-04, the app's own legal text, which the MP does not have.

**What changed in kind:** Cursor landed the Core side of almost every r8 Core row: A2-02, A4-04, A6-01, A7-08, B-DR-06, B-PV-02, B-PV-07, C-T2, C-T6, C-T8, C-F14, C-A8, C-S10, team avatars and mode copy. Ten of those Core types still have **no App call site**. The App now owns most of the queue.

**Contract coverage (Cursor checker on `ebf6c160c`, reported, not re-run):** account-publish **84 matched / 11 missing endpoint / 27 missing test**.

## 3. r8 fix queue, re-checked on ebf6c160c

| r8 id | r8 sev | r9 status | evidence (app file:line on ebf6c160c) |
|---|---|---|---|
| A3-01 | P0 | **fixed** (566ab77ef) | App/AppSession+ProfileAvatar.swift:7-26 builds `ProfileAvatarDependencies` from the player grant's avatar approval. All edit entries pass it: AccountView.swift:94, :99, :210; MPReviewedPageScreen.swift:637, :678; ProfileSettingsProfileRoute.swift:106. Pinned by Tests/AppUnitTests/MPFirstCMAGrantTests.swift:11. |
| C-F1 | P0 | **partly** → P1 C-F1b | Core/ProjectEditDraft.swift:66 adds `gallery, branch, line, divider`; Core/ProjectEditRichStoryContract.swift:64 adds them to `richKinds`, so the add menu offers them (ProjectEditDetailForms.swift:208). The block editor (ProjectEditRichStoryForms.swift:101-110) only has text + speaker. It has no gallery image picker / layout and no branch options. The compiled `ProjectEditGapRichStoryBlocksSection` still has 0 call sites. |
| C-T3 | P0 | **partly** (Core done, App open) | Core `TemplateAdvancedDraft.setScanReplyEnabled` (:83) and the `outcomeRules` / `interactionRules` survival (TemplateR5Authoring.swift:7) are in. `TemplateAuthoringGapRound4Section` (AccountPublishGapRound4Views.swift:160) has 0 call sites. TemplateAuthoringView.swift:577 shows only `TemplateAuthoringCompletionFields`. |
| C-F5 | P0 | **partly**: mounted, not saved | ProjectEditView.swift:395 `ProjectEditCastHost` writes `draft.preserved["castConfig"]`. Core/ProjectEditContract.swift:10 `topicCarryOver` does not list `castConfig`, so the cast is not sent on save or publish; it lives only in local drafts. |
| C-D2 | P0 | **fixed** (18b13c9df) | TeamHomeView.swift:172 `TeamDetailApplicantsHost(teamID:)` → AccountPublishR8Mounts.swift:60-97, with POST `{teamId}` and `teamHandleRequest`. |
| A4-01 | P0 | **fixed** | PlayerGapViews.swift:386-388 NavigationLink → MPReviewedPageScreen.swift:194-196 `subpackageRoam/poi-detail/index` → `RoamPOIDetailHost`. |
| C-F6 | P0 | **fixed** (566ab77ef) | Core/ChinaReviewedRouteCapability.swift:35, :37: both gates are `true`. |
| A-COPY-r8 | P1 | **fixed** | Localizable.xcstrings:164841 `participant.form.add` = 参与人信息; `social.interests` :244420. |
| B-DR-04b | P1 | **fixed** | AccountComplianceViews.swift:61-63 runs the entry precheck (read-only). |
| A1-01 | P1 | **fixed** (310de9944) | SocialPublicProfileView.swift:219 `OwnProfileComposerHost`. |
| A2-10-r7 | P1 | **open** (Core part done) | Core decodes `role`. `SocialPublicProfileGapCoopBar` (AccountPublishGapViews.swift:43) has 0 call sites. SocialPublicProfileView has no `merchantHomeTarget` / `PublicMerchantHomeView` swap. |
| A7-01/03/05 | P1 | **fixed** (1da335587) | MiniCropView.swift:159 `MiniCropGapOverlay(shape:cropSize:)`; :160 还原. |
| C-F7 | P1 | **partly** | 序章 + look are mounted (ProjectEditView.swift:399 `ProjectEditLookHost`), but `look` is not in `topicCarryOver` either (see C-F5b). 由工作人员开幕 needs the runtime acts model. |
| C-A4 | P1 | **fixed** (ba98f9658) | PublishingModesViews.swift:421 `ActivityPublishOrganizerHost`. |
| C-D11-r7 | P1 | **fixed** (a9601b4fa) | PlayerGapViews.swift:164 `TeamInviteImageSaveRow`. |
| C-F8 | P1 | **open** | ProjectEditView.swift:1025-1026 are still URL `ProjectEditReferenceField`s. |
| C-F2 (rest) | P1 | **open** | ProjectEditPendingPresentation.swift:81 and ProjectEditStarterPresentation.swift:38 still call `.typedCoordinates()`. |
| C-F4 (rest) | P1 | **open** | ProjectEditView.swift:664-668 `projectEdit.saveLocal` is still in the bar. |
| C-T5 (rest) | P1 | **open** | TemplateAuthoringView.swift:606 `templateAuthor.saveLocal` pill. |
| A7-02 | P1 | **partly** | The avatar is fixed: ProfileAvatarDraftSection.swift:302 `MiniCropView(ratio:"1:1", shape:.circle)`. The cover and template crops are not. |
| A2-02 | P1 | **partly** (Core done) | Core `SocialPublicProfile.role` / `merchantHomeTarget`. No App swap. |
| A4-04 / A8-09-r7 | P1 | **partly** (Core done) | Core/PublicContentShareLink.swift has `poi` / `clubHub`, with 0 App call sites. |
| A6-01 | P1 | **partly** (Core done) | Core/ProfileEditContracts.swift `ProfileParticipantPhone`, with 0 App call sites. ParticipantFormView.swift:267 still edits a phone field. |
| A7-08-r7 (重试) | P1 | **partly** (Core done) | Core/MiniCropSession.swift `retryCurrent()`. MiniCropView.swift:72 has no 重试. |
| B-DR-06 (rest) | P1 | **fixed** | AccountComplianceViews.swift:304, :332, :364 `noteSignedOut()`; :535-548 登录 CTA + `.denied` state. |
| C-T2 / C-T12-r7 | P1 | **partly** (Core done) | `TemplateAuthoringSupportPhase` / `TemplateAdoptionConfirmation` in Core/TemplateAuthoringDomain.swift, with 0 App uses. |
| C-T6 / C-T13 / C-I8 | P1 | **partly** (Core done) | Core sends `scope=MERCHANT`. App/AppSession.swift:4774 `templateAuthoringEditor(adopting:)` still has no `from` / `scope`. |
| C-T8 (rest) | P1 | **partly** (Core done) | Core `TemplateAuthoringGameplayCatalog` has 全部/推理. TemplateGameplayPickerSheet.swift:69 still says the 推理 games are not authorable. |
| B-PV-02 | P1 | **fixed** | SettingsPrivacyLocationView.swift:23, :144 `readPresence` before the toggle. |
| C-D12-r7 grant | P1 (owner) | **fixed** (MP-first) | The shipped China composition has `playerWritesEnabled: true`. Pinned by `MPFirstCMAGrantTests.testC_D12…`. |
| A3-05 | P1 (owner) | **open, an MP-first exception** | MP gerenziliao.wxml:54-56 uses WeChat `bindgetphonenumber`, which does not exist on iOS. This stays with the owner. |
| A1-02 | P1 (owner) | **open → Claude App** | MP member/index.wxml:6-7 mounts `cy-profile viewer="self"` (the tabbed profile) as the 我的 root. In the app, QuestifyApp.swift:357 makes PassportView the root, and the tabbed self profile is a pushed page (AccountView.swift:93-94). |
| A1-08 | P1 (owner) | **open → Claude App** | MP member/index.wxml:6 shows the in-page `cy-empty` 登录后查看我的主页 + 登录. QuestifyApp.swift:358 shows `WelcomeView`. |
| A3-06 / A6-02 | P1 (owner) | **open → Claude App** | MP gerenziliao.wxml:94 (`saveInfo`) and addressinfo.wxml:49 (`saveAddress`) save straight away, with no modal. The app adds a confirm: ParticipantFormView.swift:332 `.alert("participant.form.confirmSave")`; ProfileEditView.swift:41 `confirmation`. |
| A8-02 / A8-03 | P1 (owner) | **open → Claude App** | MP talent/list js:193-230 merges square posts into the feed. |
| B-PV-04 | P1 (owner) | **open → Claude App** | MP privacy/index.wxml:10, :22: 我已阅读并同意 checkbox. UsageConsentGateView.swift:80-84 has one agree button. |
| B-MK-01 | P1 (owner) | **closed**: the MP does not have it | The MP writes one consent row at a time (marketing-consent/index.js:60-80). The master toggle came from hand-off MC-43, not the MP. |
| C-F17-r7 | P1 (owner) | **fixed** (566ab77ef) | Core/ProjectEditHTTPService.swift:161 sends the original `api/topic/v2/create|update` route where the envelope is not granted. |
| A2-03b, A2-08, A4-05b, B-SZ-12b, C-I9-r7, A5-01 | P2 | **fixed** | QuestifyApp (chain2 env); SocialPublicProfileView.swift:232; c556c3994; f5ad350ad (MPReviewedPageScreen.swift:647); 7502729cf; 6739c5d82 |
| B-PR-03 | P2 | **fixed** | PassMembershipViews.swift:641, :680 (redirect semantics). |
| B-PV-07-r7 | P2 | **fixed** | UsageConsentGateView.swift:170 `UsageConsentOfflineRecord.signedOutCopy`. |
| B-SZ-11 | P2 (owner) | **closed**: already matches | MP shezhi.wxml:41 secondary button; the app row is neutral. |
| B-SZ-13 | P2 (owner) | **fixed** (MP-first) | SettingsView.swift:247-248: 商家工具 for merchants only. |
| A-OBJ | P2 (owner) | **closed** | `objects.title` is now 藏品 (Localizable.xcstrings:150783), which matches MP profile wxml:350. |
| test pin | P2 | **fixed** | Tests/ContractChecks/test_team_postjoin_navigation.py:29 |
| C-F14, C-A8, C-S10, team avatars, mode switch | P2 | **partly** (Core done, App open) | 0 App uses of `ProjectEditTicketGap`, `SquarePost.medal*` or `ProjectEditModeCopy`. TeamComponents.swift:145 still says "Core decodes no avatar yet". PublishingModesViews.swift:458 still has per-ticket times. |
| A3-10, C-F16-r7, C-I5 (rest), B-SZ-10 | P2 | **open** | The ProfileEditView hero, the multi-line name, the dark intro stage, and the Settings regroup. B-SZ-10's owner dependencies (B-SZ-11 and B-SZ-13) are now closed. |
| B-MK-05 | P2 (owner) | **open → Claude App** | MP marketing-consent/index.js:60-80 sends on toggle. AccountComplianceViews.swift:753 still opens `MemberMarketingConsentConfirmSheet`. |
| C-A9-r7 | P2 (owner) | **open → Claude App** | MP activity/index.wxml:203-221 has the real-name fields inline. |
| B-AG-04 | P2 (owner) | **open, an MP-first exception** | This is the app's own legal wording (MR-39), which the MP does not have. |

**Receipt claims that did not hold or held only in part:**
- **fix-r8-account-publish C-F5 / C-F7:** "stores the MP `castConfig` / `look`". True, but only in local drafts, because `topicCarryOver` has neither key. The receipt itself flagged this for Cursor, and it did not land.
- **cursor-r8 C-F1:** the Core side is in, but nobody mounted the editor.
- **cursor-r8 C-T3:** the Core side is in, but nobody mounted the section.

Everything else claimed for this area by fix-r8-account-publish, cursor-r8-account-publish, cursor-wire3-account-publish and fix-r8-mp-first-cma was found in the code.

## 4. Fix queue (r9)

Columns: id | severity | MP file:line | app file:line | what to do | owner. Each row is about one agent-hour.

### P0

| id | sev | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| C-F5b | P0 | pages/publish/fabu/index.wxml:172-187; theme-cast.js:305-320 (castConfig on the topic payload); look-sheet.wxml | Core/ProjectEditContract.swift:10 (`topicCarryOver`); App writes in AccountPublishR8Mounts.swift:101-106 | Add `castConfig` (object) and `look` (JSON string) to `topicCarryOver`, so they load from the topic and are sent on v2/create and v2/update. Add a Core test that pins both on the save payload. | Cursor Core |
| C-T3 | P0 | pages/publish/temp/index.wxml:105-118, 973-975, 986, 1310 | App/TemplateAuthoringView.swift:577; App/MPGap/AccountPublish/AccountPublishGapRound4Views.swift:160 | Mount `TemplateAuthoringGapRound4Section` beside `TemplateAuthoringCompletionFields`. Bind 状态不好时松一点 → `setLowHPRelax`, 扫完回复 → `setScanReplyEnabled`, and 可触发的结果 → `outcomeRules`. If citynode 玩法形态 has no Core field, raise it as a separate Core row. | Claude App |

### P1

| id | sev | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| C-F1b | P1 | fabu/index.wxml:484-604, 836-857 | App/ProjectEditRichStoryForms.swift:101-110 | Gallery: an image list (PhotosPicker, after C-F8 destinations) plus `layout` and `altText`. Branch: an options editor. Divider: no fields. Or mount `ProjectEditGapRichStoryBlocksSection` in their place. | Claude App |
| C-F8 | P1 | topic-detail-sheet.wxml (chooseMedia) | App/ProjectEditView.swift:1025-1026 | Upload destinations for the topic cover, gallery and rich media (`RetainedImageScope.Destination`). The App swap follows. | Cursor Core |
| C-F7c | P1 | theme-runtime-structure.js:215 (`acts[].hostUnlock`) | App/ProjectEditView.swift:399 | Runtime acts model for 由工作人员开幕. | Cursor Core |
| C-F2 (rest) | P1 | fabu node sheet | App/ProjectEditPendingPresentation.swift:81; App/ProjectEditStarterPresentation.swift:38 | Drop `.typedCoordinates()` and add a place picker. Update the 3 XCUITests in the same change. | Claude App |
| C-F4 (rest) | P1 | fabu/index.js (saveDraft=1) | App/ProjectEditView.swift:664-668 | The bar's 保存草稿 becomes the server draft, and 存到本机 moves into ⋯. Update the `projectEdit.saveLocal` tests. | Claude App |
| C-T5 (rest) | P1 | temp/index.wxml:1492-1494 | App/TemplateAuthoringView.swift:606 | Move 保存到此设备 into ⋯. Update the 6 tests. | Claude App |
| C-T2b | P1 | temp/index.wxml:66, 71-72 | App/OwnedTemplateConfigurationView.swift:82-98 | Bind `TemplateAuthoringSupportPhase` (loading / failed + 重试) and `TemplateAdoptionConfirmation.pending` (采用尚未确认). | Claude App |
| C-T6b | P1 | temp/index.js (from/scope); template-intro/index.js:296 | App/AppSession.swift:4774; App/MPReviewedPageScreen.swift (temp / intro cases) | Add `from:` and `scope:` to `templateAuthoringEditor` and honour the link. For merchants, show the 保存并绑定 / 保存玩法 labels and the merchant skin. | Claude App |
| C-T8b | P1 | utils/publish/node-game-catalog.js:105-120 | App/TemplateGameplayPickerSheet.swift:68-75 | Drive the picker from `TemplateAuthoringGameplayCatalog`: 全部 plus the 推理 group (sort / match / classify). | Claude App |
| A2-02b / A2-10 | P1 | cyp js:900-1040, wxml:578-582; userinfo.js:55-58 | App/SocialPublicProfileView.swift (bottom `safeAreaInset`); AccountPublishGapViews.swift:43 | Probe `merchantHomeTarget` with the public-home reader. When it returns a home, swap to `PublicMerchantHomeView`. For merchant viewers of another account, mount `SocialPublicProfileGapCoopBar` → `pages/coop/invite/index`. | Claude App |
| A4-04b | P1 | mylike.wxml:87-92; talent/list/index.js:789-805 | App/PlayerGapViews.swift (据点 rows); App/ClubHomeView.swift | Add `ShareLink` through `PublicContentShareLink.poi(id:)` / `.clubHub(tab:)`. Fall back to the copy-text helpers. | Claude App |
| A6-01b | P1 | addressinfo.wxml:29-30, js:59-72 | App/ParticipantFormView.swift:263-268 | Show `ProfileParticipantPhone` read-only (the bound number) in place of the editable phone field. | Claude App |
| A7-08b | P1 | crop/index.wxml:25-35 | App/MiniCropView.swift:72 | Add 重试 → `session.retryCurrent()` on the source error. | Claude App |
| A7-02 (rest) | P1 | app.js:617-700 | ProfileLocalCoverSection.swift; TemplateImageCropView.swift | Route the cover (16:9) and template crops through MiniCropView, and update their crop pins in the same change. | Claude App |
| A1-02 | P1 | member/index.wxml:6-7 (`cy-profile viewer="self"`) | App/QuestifyApp.swift:357; App/AccountView.swift:93-94 | Make the tabbed self profile (我的 · 帖文 · 成就 · 关于) the 我的 root, as the MP does. Keep the account entries in its 我的 tab. | Claude App |
| A1-08 | P1 | member/index.wxml:6 | App/QuestifyApp.swift:358 | When signed out, 我的 shows the in-page empty state 登录后查看我的主页 + 登录 (`ContentUnavailableView`), not `WelcomeView`. | Claude App |
| A3-06 / A6-02 | P1 | gerenziliao.wxml:94; addressinfo.wxml:49 | App/ProfileEditView.swift:41 (`confirmation`); App/ParticipantFormView.swift:332 | Remove the confirm-before-save steps: the MP saves on tap. Keep the progress → success. | Claude App |
| A8-02 / A8-03 | P1 | talent/list/index.js:193-230; wxml:64-76 | App/ClubHomeView.swift; App/ClubCommunityViews.swift | Merge square posts into the club-hub feed as the MP does, and drop the root sections that the MP does not have. | Claude App |
| B-PV-04 | P1 | privacy/index.wxml:10, :22 | App/UsageConsentGateView.swift:80-84 | Add the 我已阅读并同意 checkbox, with 同意 disabled until it is checked. Update the `authEntry.gate.agree` UI tests. | Claude App |
| A3-05 | P1 | gerenziliao.wxml:54-56 (`bindgetphonenumber`) | App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift:5 | The MP flow cannot run on iOS (it uses a WeChat-only API). Decide on the native bind (SMS bind or none). Do not mount the gap row as it is. | owner |

### P2

| id | sev | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| B-MK-05 | P2 | marketing-consent/index.js:60-80 | App/AccountComplianceViews.swift:733-760 | Send on toggle with no confirm sheet, then toast 已同意 / 已退订. | Claude App |
| C-A9-r7 | P2 | activity/index.wxml:203-221 | App/PublishingModesViews.swift:470-490 | Show the real-name fields inline, as the MP does. | Claude App |
| C-A8b | P2 | activity/index.wxml:158-186 | App/PublishingModesViews.swift:458 | Drop the per-ticket time fields (Core now sends the activity span). | Claude App |
| C-F14b | P2 | fabu/index.wxml:163-165 | App/ProjectEditTicketSummary.swift:5 | Show the `ProjectEditTicketGap.summary` line `* 还有 N 项未填`. | Claude App |
| C-S10b | P2 | square/detail/index.wxml:57 | App/SquareDetailView.swift | Add the medal pill from `SquarePost.medalGold/Silver/Bronze`. | Claude App |
| Team avatars | P2 | team/detail/index.wxml:102 | App/TeamComponents.swift:145 | Draw `TeamMember.memberAvatar`, falling back to `d_profile`. | Claude App |
| Mode switch | P2 | fabu/index.js `navigateTo fabu?mode=` | ProjectEditCoordinator | 复制并切换 through `ProjectEditModeCopy.copied`, then open the copy. Send no POST. | Claude App |
| A3-10 | P2 | gerenziliao.wxml:20-38 | App/ProfileEditView.swift | Hero: centred avatar, name, 更换背景. | Claude App |
| C-F16-r7 | P2 | fabu/index.wxml:103-117 | App/ProjectEditView.swift (name field) | Make the name field multi-line, and update `ProjectEditFlowTests`. | Claude App |
| C-I5 (rest) | P2 | template-intro/index.wxss:7-36 | App/TemplateAuthoringIntroExperience.swift | Host the intro outside the Form, on a dark stage. | Claude App |
| B-SZ-10 | P2 | shezhi.wxml:9-36 | App/SettingsView.swift | Regroup the Settings sections in MP order. Its dependencies, B-SZ-11 and B-SZ-13, are closed. | Claude App |
| B-AG-04 | P2 | — (the MP has no app legal text) | App/SettingsLegalDocumentView.swift | Legal wording for the app (MR-39). | owner |

## 5. Native-iOS check (area files)

- **Text size:** no text is set below `.caption`. `CYTextStyle.micro` maps to `.caption` (App/DesignSystem/CYDesignTokens.swift:334). The two `.micro` uses in the area are AccountComplianceViews.swift:895 and PassMembershipViews.swift:256.
- **Dynamic Type:** every `cyText` style resolves to a `Font.TextStyle`. There are no fixed-point `Font.system(size:)` calls in the area's screens or in `App/MPGap/AccountPublish/*`.
- **Empty and error states:** the r8 mounts use `CYEmptyState`, which is built on `ContentUnavailableView` (CYStateKit.swift:188-189).
- **Custom chrome where a system control is expected:**
  - The marketing per-toggle confirm (B-MK-05) is a custom `.sheet` that the MP does not have. It should simply go away.
  - The save confirms (A3-06 / A6-02) are extra `.alert`s.
  - Signed-out 我的 (A1-08) should be a `ContentUnavailableView` with 登录, not the full `WelcomeView`.
  - The team applicants block (TeamHomeView.swift:172) is a `VStack` card inside the page's scroll view, not a `List` section. This is acceptable because the page is card-based; no row is queued.
- No other findings.

## 6. Go-live blockers (P0 only)

1. **C-F5b (Cursor Core):** the cast (角色) and 画面风格 are edited in fabu but never sent to the server, because `topicCarryOver` lacks `castConfig` and `look`. A published project loses them.
2. **C-T3 (Claude App):** temp still has no 状态不好时松一点, 可触发的结果, 扫完回复 or citynode 玩法形态. Core landed the fields; mount `TemplateAuthoringGapRound4Section`.

Five of r8's seven P0s are closed or downgraded: A3-01, C-D2, A4-01 and C-F6 are fixed, and C-F1 is now P1 (the blocks can be added, but the gallery and branch editors are thin).
