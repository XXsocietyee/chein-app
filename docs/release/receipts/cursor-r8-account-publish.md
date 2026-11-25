# Cursor r8 account-publish

Cut from `f5f3006d781ac4d61c225a079ef74e2e2a86befd`, then rebased onto `b5b9d900373c2062c4daf916f64a0184e20c63af`. The visit-config gates stay this branch's pair (`freeExploreVisitConfigRead` / `freeExploreVisitConfigWrite`) and the path stays on `creatorEditorAndOrderCenterOwnerGrant`. The other side's `mpFirstCMAOwnerGrant` for the same path was dropped.

No `swiftc`. No parse is claimed. `AppSession.swift`, `AppCompositionRoot.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. Money stays off: pay, refund, payout, withdrawal, and paid orders send nothing.

## Rows taken

P0

- **C-F6.** `PlayRuntimePortRouteGate.freeExploreVisitConfigRead` and `freeExploreVisitConfigWrite` are true. `POST/GET /api/topic/free-explore/visit-config` is on the creator-editor China grant. The body stays `{nodeId, visitCheck, visitRadius}` from `FreeExplorationVisitConfigChange`.
- **C-F1.** `ProjectEditBlock.Kind` adds `gallery`, `branch`, `line`, and `divider`. Materialized blocks and shape checks follow the mini-program pro-editor payloads (gallery `layout`/`images`/`altText`, branch `content`/`options`, dialogue `speaker`/`content`/`audioUrl`, divider type+key). Empty galleries are omitted. `ProjectEditRichStoryContract.richKinds` includes them.
- **C-T3.** Relax, scan reply, and triggerable results already live in the advanced JSON (`variants`, `scan.kind`, `outcomeRules`). This round lets `outcomeRules` / `interactionRules` / `interactionTools` survive save, adds `setLowHPRelax(path:delta:)` (`sys.hp` LTE 3), and `setScanReplyEnabled` (`TEXT` / `NONE`).
- **A3-01 grant.** The shipped China player grant already sets avatar `nativePicker`. Composing `ProfileAvatarDependencies` is an App call site, listed below. No screen was given a new upload client.

P1

- **C-T6.** Draft and publish payloads include `scope=MERCHANT` when `TemplateAuthoringDraft.operationScope` is `MERCHANT`. Players still omit `scope`. `cityNodeSubmitPath` and `cityNodeBody` match `toNodeTemplate`. The editor factory still lives in `AppSession`.
- **C-T8.** `TemplateAuthoringGameplayCatalog` lists 全部/问答/推理/互动/挑战 and the three 推理 games (`sort`, `match`, `classify`) on the existing advanced sections. Validation methods 8/9/10 were not added; the 0...5 remote gate is unchanged.
- **C-T2.** `TemplateAuthoringSupportPhase` (idle/loading/ready/failed, loading copy 正在读取玩法支持范围) and `TemplateAdoptionConfirmation.pending` (采用尚未确认). The matrix GET `api/play/theme/support-matrix` was already a live read.
- **A2-02.** `SocialPublicProfile.role` decodes `role`. `merchantHomeTarget` is the member id the mini-program posts to `api/merchant/public-home`. The merchant row id stays `PublicMerchantHome.id`.
- **A2-10 link rule.** `pages/userinfo/userinfo` accepts `topicId`, `chapterId`, `scope=MERCHANT`, and `preview=1`.
- **A4-04 / A8-09-r7.** `PublicContentShareLink.poi(id:)` and `clubHub(tab:)` return a URL only when an existing parser accepts the path. Otherwise `poiCopyText` / `clubHubCopyText` are path text, not a new host.
- **A6-01.** `ProfileParticipantPhone` keeps the read-only bound phone (11–15 digits). The masked `ProfileBoundPhoneDisplay` on the edit snapshot is unchanged and still does not keep the raw phone.
- **A7-08-r7 and the reset hook.** `MiniCropSession.retryCurrent()` and `reset()` restore scale and offset on the current image and do not advance.
- **B-DR-06.** `ComplianceStep.denied`, `noteAccessDenied()`, and `noteSignedOut()` (selects `.freshLogin`). The sheet switch has a denied row so the enum stays exhaustive.
- **B-PV-02.** `RoamPresenceVisibilityService.readPresence` uses the existing GET. The path was not added to roam extras. Disable stays the only write.

P2

- **C-F14.** `ProjectEditTicketGap.count` matches `_ticketMissing` (date keys, `ticket*` keys, three identity cells) and the `* 还有 N 项未填` line.
- **C-A8.** Activity ticket wire sends the activity `startDate`/`endDate` as every ticket's `startTime`/`endTime`. Per-ticket times are not required and are not sent.
- **B-PV-07-r7.** `UsageConsentOfflineRecord.owedWhileSignedOut` with copy 已同意，联网后会自动补记同意记录. Nothing is posted from that flag.
- **C-S10.** `SquarePost.medalGold` / `medalSilver` / `medalBronze` are optional counts. Omitted stays nil.
- **Team avatars.** `TeamMember.memberAvatar` decodes `avatar`, including invitation previews.
- **Mode switch.** `ProjectEditModeCopy.copied` is a local product-type copy (ticket `mode` in local metadata). Merchant owner returns nil. No HTTP copy.
- **Test pin.** `test_team_postjoin_navigation.py` now expects `if !readOnly, let pending = model.coordinator.pending`.

Owner decisions whose Core switch was already on, or that are not a Core send:

- **C-D12.** Shipped China `playerWritesEnabled` already builds `TeamCommandWriter` for `api/team/command`, `query`, `cancel`, and `api/team/create`. `AppCompositionRoot` was not edited. The stale pin above was the leftover.
- **B-MK-01.** The mini-program posts one marketing consent row at a time. `AccountComplianceService.setMarketing` already does that. A master batch write is not what the mini-program sends, so it was not added.
- **C-F17.** `api/topic/v2/create` and `api/topic/v2/update` stay the save/publish paths. The edit-requests envelope was not treated as a replacement, and backend acceptance was not claimed.
- **A3-05.** WeChat `getPhoneNumber` (`pages/gerenziliao/gerenziliao.wxml` bindgetphonenumber) cannot run on iOS. No native bind was invented.

Not taken: Claude App rows (including C-F2 / C-F4 / C-T5 XCUITests), and owner-decision UI or legal rows (tabbed 我的, confirm-before-save, square merge, legal checkbox, real-name page vs inline, 商家工具 for every player, confirm sheet on every marketing toggle).

## App call sites left for Claude

Exhaustive switches were given a case so the new Core enums compile. Those arms do not mount the gap sections.

- **A3-01.** Pass `ProfileAvatarDependencies` into `ProfileEditView` at `App/AccountView.swift` (both edit entries), `App/MPReviewedPageScreen.swift` (both), `App/ProfileSelfEditAccess.swift`, `App/ProfileSettingsProfileRoute.swift`. The type and the nil-means-未开放 UI are in `App/ProfileAvatarDraftSection.swift`. `AppSession` already builds `avatarDispatch` when player writes are on; this file was not edited.
- **C-F1.** Mount `ProjectEditGapRichStoryBlocksSection`. The chapter list and rich editor only gained exhaustive cases in `App/ProjectEditDetailForms.swift` and `App/ProjectEditRichStoryForms.swift`.
- **C-T3 / C-T6 / C-T8.** `App/AppSession.swift` `templateAuthoringEditor(adopting:)` still does not take `from` or `scope`. City-node submit must call `TemplateAuthoringContract.cityNodeSubmitPath` with `cityNodeBody`. Merchant skin, 全部, and the 推理 group belong on `App/TemplateGameplayPickerSheet.swift` and `App/OwnedTemplateConfigurationView.swift`.
- **C-T2.** Bind `TemplateAuthoringSupportPhase` and `TemplateAdoptionConfirmation` on `OwnedTemplateConfigurationView`.
- **A2-02.** After public-info, probe `merchantHomeTarget` with the existing public-home reader and swap to `PublicMerchantHomeView` only when that read returns a home.
- **A4-04.** Share buttons should call `poi` / `clubHub` and fall back to the copy-text helpers.
- **A6-01.** Show `ProfileParticipantPhone` read-only where the mini-program shows the bound number (`App/ParticipantFormView.swift` still edits a phone field; `App/ProfileEditView.swift` still shows the mask).
- **A7.** `MiniCropView` should call `retryCurrent()` on the source error and `reset()` for 还原.
- **B-DR-06.** `noteSignedOut` / `noteAccessDenied` need a host. `App/AccountComplianceViews.swift` shows `compliance.denied.identity` for `.denied` (copy in `docs/port/strings/cursor-r8-account-publish.json`). The 登录 button is still the existing signed-out empty state; wire it to sign-in after the sheet closes.
- **B-PV-02.** `App/SettingsPrivacyLocationView.swift` only calls `disableRoamPresenceVisibility()`. Read with `readPresence` before showing the toggle.
- **B-PV-07.** `App/UsageConsentGateView.swift` should show `UsageConsentOfflineRecord.signedOutCopy` when the viewer is signed out.
- **C-F14.** `App/ProjectEditTicketSummary.swift` should show `ProjectEditTicketGap.summary`.
- **C-A8.** Drop per-ticket time fields in the activity publisher (`PublishingModesViews`).
- **C-S10.** Medal counts on the square post card (`SquarePost.medalGold` / `Silver` / `Bronze`).
- **Team avatars.** `App/TeamComponents.swift` still comments that Core has no avatar. Draw `memberAvatar`.
- **Mode switch.** Confirm with `ProjectEditModeCopy` copy, then open the copied draft. Do not POST a copy.
