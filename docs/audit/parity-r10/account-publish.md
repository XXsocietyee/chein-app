# Parity + native audit r10: account-publish (player side, 22 pages), against ui/combined-r7 @ 82bcf2c2d

Briefs: `origin/design/handoff-r2:docs/briefs/audit-parity-r9.md` (method), `native-r2.md` (owner, 2026-11-26: "EVERYTHING native"), `owner-decisions-1124.md` (MP-first). Review only: no product code was changed.

- **App:** `origin/ui/combined-r7` @ `82bcf2c2d` (2026-11-25 21:48 −0800, "native r2 tokens"). r9 audited `ebf6c160c`; 212 commits landed since, including `cursor/r9-account-publish` (03d823dac) and the Core commit 989f8cfb2 (cast / look / 开幕 contracts).
- **MP:** `hengyin/chengyinhub-xcx`, unchanged for this area since r9, so the denominators are unchanged (384 lines).
- **Method (parity):** the same 22 pages and function lines as r9. ✅ = 1, ⚠️ = 0.5, ❌ / Core-only / compiled-but-unmounted = 0. Every r9 queue row was checked in code on `82bcf2c2d`; receipts were not trusted.
- **Method (native):** every page's view files were read and grepped for non-Apple elements: `CY*` components (`CYPillButton`, `CYEmptyState`, `CYListRow`/`CYRowIcon`, `CYSkeleton`, `CYLoadingStateView`, `CYStatusChip`, `CYSectionHeader`, `CYHeroHeader`, `CYCard`, `CYModal`, `CYTabs`, `CYSheetContainer`, …), `.buttonStyle(.cy…)`, gradients, shadows, custom corner radii / stroke borders, materials, `ScrollView` where `List`/`Form` is expected, hex / `CYNight` colours, drawn look-alike controls. A page is **native** only when none remain, **partly** when it is built on `List`/`Form`/`NavigationStack` but still carries CY chrome, **custom** when its structure itself is custom (scroll + cards, hero, custom sheets, custom colours). Native % = (native + 0.5 × partly) / 22.
  - Note: `CYEmptyState` is a wrapper over `ContentUnavailableView` (CYStateKit.swift). It is still listed, because the native-r2 rule says to use `ContentUnavailableView` directly; swapping it is mechanical.
  - `CYColor.*` tokens now resolve to UIKit semantic colours (coordinator commit 82bcf2c2d), so they are **not** flagged. `CYNight.*` (fixed night palette) **is** flagged.
- **Money:** no money path in this area (ticket *prices* on the publish forms are authoring fields, not payments). No row is marked "money, not a gap".

## 1. Headline

| | r9 | **r10** |
|---|---|---|
| Parity | 348.5/384 (91%) | **353/384 (92%)**, +4.5 |
| Native | not measured | **0 native / 17 partly / 5 custom → 39%** |
| P0 open | 2 | **0** (both r9 P0s fixed) |
| P1 open (parity) | 20 | **17** (4 fixed, 1 new split C-T3c) |
| P2 open (parity) | 12 | **11** (C-I5 superseded by native-r2) |
| Native rows queued | — | **29** (P1 13, P2 16) |

Contract coverage (Cursor checker, r9 brief, not re-run): account-publish **84 matched / 11 missing endpoint / 27 missing test** on `ebf6c160c`. No r10 figure was supplied.

## 2. Per-page parity and native status

| # | MP page | App screen | r9 | **r10** | **NATIVE** | non-Apple elements (app file:line on 82bcf2c2d) |
|---|---|---|---|---|---|---|
| 1 | pages/member/index/index | AccountView + MemberHomeHeader | 24.5/32 | **24.5/32 (77%)** | **partly** | `CYListRow`+`CYRowIcon` ×22 AccountView.swift:69, :80, :84, :88, :96, :100, :120…; `.buttonStyle(.cy…)` AccountView.swift:177, :413; `cyRootHeader` AccountView.swift:202; **gradient** overlay MemberHomeHeader.swift:155; `strokeBorder` :166, :255; `CYSkeleton` :174; `CYStreakRow` :83; `CYPlainStatRow`/`CYPlainStat` :92, :273; `CYStaggerGate` :37; `.buttonStyle(.cy…)` :261, :333, :348 |
| 2 | pages/userinfo/userinfo | SocialPublicProfileView | 13/16 | **13/16 (81%)** | **partly** | `CYEmptyState` SocialPublicProfileView.swift:80; `CYStatusChip` :150-152; `CYPillButton` :282; custom `RoundedRectangle` :377-378; `strokeBorder` :550 |
| 3 | pages/gerenziliao/gerenziliao | ProfileEditView | 16.5/19 | **16.5/19 (87%)** | **partly** | `CYEmptyState` ProfileEditView.swift:638, :640; `CYStatusChip` :715; `CYPillButton` :728, :732, :746, :843, :860; `CYSkeleton` :735 |
| 4 | pages/mylike/mylike | AccountCollectionFavoritesView + CityFavoriteNodesSection | 19/20 | **19.5/20 (98%)** | **partly** | `CYTabs` (custom segmented) AccountCollectionFavoritesView.swift:48; `.thinMaterial` :131; **custom card** `.background(…RoundedRectangle)` + `strokeBorder` :303-304 with `QuestifyCardButtonStyle` :306; `CYLoadingStateView` :99, :275; `CYSkeleton` :152, :340; `CYEmptyState` :116, :284, :290; `CYStatusChip` :93, :269; `CYStaggerGate` :89 |
| 5 | pages/address/address | ProfileParticipantsView | 12/12 | **12/12 (100%)** | **partly** | `CYLoadSlot` ProfileParticipantsView.swift:222; `CYEmptyState` :233, :251, :264, :267; `CYStatusChip` :241; `CYSkeleton` :333 |
| 6 | pages/addressinfo/addressinfo | ParticipantFormView | 10.5/12 | **11/12 (92%)** | **partly** | `CYEmptyState` ParticipantFormView.swift:263, :278, :443, :492; `CYSkeleton` :283, :286, :464, :485; `CYScreenOfflineWriteSection` :346; `CYPillButton` :357, :446 |
| 7 | pages/crop/index | MiniCropView | 15/16 | **15.5/16 (97%)** | **partly** | `.regularMaterial` rounded loading card MiniCropView.swift:87; `CYEmptyState` :66, :69, :75; `CYPillButtonStyle` :127, :148. The crop canvas itself has no Apple control (closest: none in SwiftUI), so it stays custom by exception. |
| 8 | pages/talent/list/index | ClubHomeView | 17/19 | **17.5/19 (92%)** | **custom** | `cyRootHeader` ClubHomeView.swift:52, :200; `CYClubPhotoCard` :304; `CYClubRowCard` :310; `CYListRow`+`CYRowIcon` :142, :150, :383, :385; `CYSectionHeader` :156; `.buttonStyle(.cy…)` :168; `CYSkeleton` :229; `CYEmptyState` :158, :221, :236, :253; `CYScreenOfflineWriteBanner` :323; `RoundedRectangle` :414 |
| 9 | pages/shezhi/shezhi | SettingsView | 23/23 | **23/23 (100%)** | **partly** (near) | custom bordered tile `strokeBorder` SettingsView.swift:367, `RoundedRectangle` :381. Rest is `Form` + `ContentUnavailableView`. |
| 10 | pages/shezhi/about/index | SettingsAboutView | 10/10 | **10/10 (100%)** | **partly** | `RoundedRectangle` SettingsAboutView.swift:115, :129; `strokeBorder` :130; `CYSkeleton` :118, :122; `CYStatusChip` :149 |
| 11 | pages/shezhi/marketing/index | AccountComplianceSheet (.marketing) | 12.5/13 | **12.5/13 (96%)** | **partly** | custom confirm sheet `MemberMarketingConsentConfirmSheet` AccountComplianceViews.swift:758 (also parity B-MK-05); `RoundedRectangle` :682; `clipShape(RoundedRectangle)` :695; `CYScreenOfflineWriteBanner` :707 |
| 12 | pages/privacy/index | UsageConsentGateView / PrivacyProtectionView / SettingsPrivacyLocationView | 21.5/22 | **22/22 (100%)** | **partly** | UsageConsentGateView.swift:57-77 **drawn look-alike checkbox** (`Button` + `square`/`checkmark.square.fill` symbol); :82 `ScrollView` instead of `Form`; :112 `.buttonStyle(.cyPrimary)`. PrivacyProtectionView.swift:57 `CYEmptyState`. SettingsPrivacyLocationView.swift:192 `CYLoadingStateView`, :193-195, :205 `CYEmptyState`, :199 `CYPillButton` |
| 13 | pages/agreement/index | SettingsLegalDocumentView | 7/7 | **7/7 (100%)** | **partly** (near) | `CYLoadingStateView` SettingsLegalDocumentView.swift:32; `CYEmptyState` :35, :41, :47. The `ScrollView` of document text (:26) is acceptable (Settings → Legal does the same). |
| 14 | pages/deregister/index | AccountComplianceSheet (.cancellation) | 18/19 | **18/19 (95%)** | **partly** | `CYSkeleton` AccountComplianceViews.swift:258, :826; `RoundedRectangle` :503, :884; `CYEmptyState` :538, :545; `CYStatusChip` :583-585; `CYScreenOfflineWriteBanner` :631; `CYScreenOfflineWriteSection` :802 |
| 15 | subpackagePass/reveal/index | PassRevealView | 11.5/12 | **11.5/12 (96%)** | **custom** | **fixed dark** background `CYNight.ink0` PassMembershipViews.swift:666 (ignores system Light); `CYNight.ink0` text :706; custom **shadow** `CYNight.passGold0` :722; **gold gradient wash** `LinearGradient` `CYNight.passGold0…3` :730-736 |
| 16 | pages/publish/fabu/index | ProjectEditView | 23/28 | **24/28 (86%)** | **partly** | **custom image inputs**: URL text fields `ProjectEditReferenceField` ProjectEditView.swift:1025-1026 (should be `PhotosPicker`); `ScrollView` :356; `CYPillButtonStyle` bottom bar :666, :673, :681, :688; `CYModal` :795, :812, :826; `CYStatusChip` :1004, :1007, :1010; `CYErrorState` :608; `CYSkeleton` :618; `CYEmptyState` :424; `CYDomainPalette` :306, :1219 |
| 17 | pages/publish/temp/index | TemplateAuthoringView | 16.5/22 | **17.5/22 (80%)** | **partly** | `ScrollView` TemplateAuthoringView.swift:285, :289, :315; `CYHeroHeader` :321, :671; `CYPillButton` :349, :360, :486, :608; `CYPillButtonStyle` :389, :396, :407, :507, :695, :699; `CYEmptyState` :325; `CYDomainPalette` :235, :668 |
| 18 | pages/publish/activity/index | ActivityPublishingView | 19/20 | **19/20 (95%)** | **custom** | `ScrollView` PublishingModesViews.swift:44, :1082; `CYHeroHeader` :46; `CYPillButtonStyle` :50, :304; `CYSectionHeader` ×12 :52, :62, :118, :130, :350, :374…; `CYListRow`+`CYRowIcon` ×10 :54, :56, :63, :70, :74, :77…, and the new chooser row :357-361 (fixed 12 pt icon frame :359); `CYSecondaryButtonStyle` :134; `CYPillButton` :153, :1115, :1120; custom cards `RoundedRectangle` :1075, :1076, :1097 |
| 19 | pages/publish/template-intro/index | TemplateAuthoringIntroExperience | 6/7 | **6/7 (86%)** | **custom** | card grid `cardLayout` with `clipShape(RoundedRectangle)` TemplateAuthoringIntroExperience.swift:115-135 (:132); `CYSkeleton` :155; `CYPillButtonStyle` :160, :179 |
| 20 | pages/square/detail/index | SquareDetailView | 21/22 | **21/22 (95%)** | **partly** | custom share sheet `CYSquareShareSheet` SquareDetailView.swift:168 (+ `CYSquareSharePayload` :304) instead of `ShareLink`; `CYModal` :177; `CYSquareRouteMapCard` :73; `CYPillButton` :117, :575, :601; `CYSkeleton` :50, :52, :109, :570; `Capsule().stroke` :145; `CYEmptyIllustration` :686; `.buttonStyle(.cy…)` :699, :701 |
| 21 | pages/team/detail/index | TeamDetailView (TeamHomeView.swift) + TeamComponents | 19.5/20 | **19.5/20 (98%)** | **custom** | `ScrollView` TeamHomeView.swift:23, :85, :390; `CYCard` :152, :176; `.buttonStyle(.cy…)` ×17 :30, :45, :135, :140, :142, :207…; `CYLoadingState` :32, :89; `CYEmptyState` :35, :101. TeamComponents.swift: `CYSheetContainer` :193, :329; `CYSecondaryButtonStyle` :285, :376; `CYGhostButtonStyle` :290, :381; `CYDestructiveButtonStyle` :313; `CYPrimaryButtonStyle` :315, :370; `RoundedRectangle` :122, :268, :366 |
| 22 | pages/team/join/index | TeamInvitationEntryView (NativeNavigationCompletionViews.swift) | 12.5/13 | **12.5/13 (96%)** | **partly** (near) | `CYPillButton` NativeNavigationCompletionViews.swift:19, :20, :54. Rest is `Form` + `ContentUnavailableView`. |
| | **Area** | | **348.5/384 (91%)** | **353/384 (92%)** | **39%** | |

Shared gap components mounted on these pages also carry CY chrome: AccountPublishGapViews.swift:53, :160, :162, :278, :283, :365 (`CYPillButtonStyle`), :154 (`CYStatusChip`), :220-226 (`CYLoadingState` / `CYEmptyState` / `CYCard`); AccountPublishGapRound4Views.swift:107; AccountPublishGapRemainingViews.swift:91, :165; AccountPublishR8Mounts.swift:397-492 (`CYEmptyState`/`CYLoadingState`), :591 (`clipShape(RoundedRectangle)`). AccountPublishR9Mounts.swift is clean (`ShareLink` + `Label`).

**Not found anywhere in the area files:** hex `Color(red:)` / `CYRGB`, `.font(.system(size:))`, `.font(.custom…)`, `.preferredColorScheme(.dark)`. Forced-dark exists only as the `CYNight` palette on PassReveal (row 15).

**History:** round 1 71% → r7 80% → r8 86% → r9 91% → **r10 92%**. No page regressed.

## 3. r9 fix queue, re-checked on 82bcf2c2d

| r9 id | r9 sev | r10 status | evidence (app file:line on 82bcf2c2d) |
|---|---|---|---|
| C-F5b | P0 | **fixed** (989f8cfb2) | Core/ProjectEditContract.swift:12 `topicCarryOver` now has `castConfig`, `look`; :45-47 posts both as JSON strings; :148-150 loads them from edit-detail. |
| C-T3 | P0 | **fixed** (e1dafdb5b), with a split | TemplateAuthoringView.swift:582-583 mounts `TemplateAuthoringGapRound4Section` (扫完回复 → `setScanReplyEnabled` AccountPublishGapRound4Views.swift:186; 松一点 → `setLowHPRelax` :218; 可触发的结果). Only mounted when `draft.finishEnabled` (default true, Core/TemplateAuthoringDomain.swift:94). citynode 玩法形态 is deliberately off-screen (:163-165) because the personal pipe cannot post `/api/merchant/city-node/template/submit` → new row **C-T3c**. |
| C-F1b | P1 | **open** | ProjectEditRichStoryForms.swift:101 `case .gallery, .branch, .line, .divider` still has no fields; `ProjectEditGapRichStoryBlocksSection` (AccountPublishGapRound4Views.swift:5) has 0 call sites. |
| C-F8 | P1 | **partly** (Core done) | Core/RetainedImageContracts.swift:15 `topicCover, topicGallery, topicRichMedia`; Core/ImageUploadJournal.swift:46-50. App still uses URL fields ProjectEditView.swift:1025-1026 → **C-F8b** (Claude App). |
| C-F7c | P1 | **partly** (Core done, 989f8cfb2) | Core/ProjectEditRuntimeActs.swift:7 (`acts[].hostUnlock` toggle copy). 0 App call sites → **C-F7d** (Claude App). |
| C-F2 (rest) | P1 | **open** | ProjectEditPendingPresentation.swift:81, ProjectEditStarterPresentation.swift:38 `.typedCoordinates()`. |
| C-F4 (rest) | P1 | **open** | ProjectEditView.swift:663 `model.saveLocal()` still in the bar. |
| C-T5 (rest) | P1 | **open** | TemplateAuthoringView.swift:608 `templateAuthor.saveLocal` pill. |
| C-T2b | P1 | **open** | 0 App uses of `TemplateAuthoringSupportPhase` / `TemplateAdoptionConfirmation`. |
| C-T6b | P1 | **open** | AppSession.swift:4774 `templateAuthoringEditor(adopting:)` still has no `from:` / `scope:`. |
| C-T8b | P1 | **open** | TemplateGameplayPickerSheet.swift:69 still says 推理 games are not authorable. |
| A2-02b / A2-10 | P1 | **open** | 0 App uses of `merchantHomeTarget` or `SocialPublicProfileGapCoopBar(`. |
| A4-04b | P1 | **fixed** (cc5349192) | PlayerGapViews.swift:395-404 据点 swipe + context-menu share; ClubHomeView.swift:201-207 hub share; both via `R9PublicShareButton` → `ShareLink` (AccountPublishR9Mounts.swift:34-47). |
| A6-01b | P1 | **fixed** (885531d50) | ParticipantFormView.swift:211-241 bound phone read through `participantBoundPhone()` (AccountPublishR9Mounts.swift:11-27, MP `/api/user/info`). |
| A7-08b | P1 | **fixed** (06a7477e2) | MiniCropView.swift:75-78 重试 → :107-111 `session.retryCurrent()`. |
| A7-02 (rest) | P1 | **open** | `MiniCropView(` is used only by ProfileAvatarDraftSection.swift:302, CreatorCropExportView.swift:24 and the fixture; cover / template crops do not route through it. |
| A1-02 | P1 | **open** | QuestifyApp.swift:357 `PassportView` is still the 我的 root. |
| A1-08 | P1 | **open** | QuestifyApp.swift:358 `WelcomeView()` when signed out. |
| A3-06 / A6-02 | P1 | **open** | ProfileEditView.swift:41 `confirmation`; ParticipantFormView.swift:381 `.alert("participant.form.confirmSave")`. |
| A8-02 / A8-03 | P1 | **open** | ClubHomeView feed has no square merge (only `authorSquare` reader :27). |
| B-PV-04 | P1 | **fixed** (a51182d9f) | UsageConsentGateView.swift:53-78 checkbox, :113 `.disabled(!agreementChecked)`. Native note: the checkbox is drawn (see N-12). |
| A3-05 | P1 | **open, MP-first exception (cannot run on iOS)** | MP gerenziliao.wxml:54-56 `bindgetphonenumber` is WeChat-only. Owner. |
| B-MK-05 | P2 | **open** | AccountComplianceViews.swift:758 `MemberMarketingConsentConfirmSheet`. |
| C-A9-r7 | P2 | **open** | No inline real-name fields in PublishingModesViews.swift. |
| C-A8b | P2 | **open** | PublishingModesViews.swift:462-467 per-ticket 开始 / 结束 fields remain. |
| C-F14b | P2 | **open** | 0 App uses of `ProjectEditTicketGap`. |
| C-S10b | P2 | **open** | 0 App uses of `SquarePost.medal*`. |
| Team avatars | P2 | **open** | TeamComponents.swift:145 comment still "Core decodes no avatar yet". |
| Mode switch | P2 | **open** | 0 App uses of `ProjectEditModeCopy`. |
| A3-10 | P2 | **open** (re-worded for native) | No hero in ProfileEditView. Under native-r2 this becomes one `Image` header in the first `Section`, not a custom hero. |
| C-F16-r7 | P2 | **open** | ProjectEditView.swift:1023 only the description is `axis: .vertical`; the name is not. |
| C-I5 (rest) | P2 | **superseded** by native-r2 | "Dark stage" for the intro is forced dark, which native-r2 forbids on player/editor pages. Replaced by N-23. |
| B-SZ-10 | P2 | **open** | SettingsView section order unchanged. |
| B-AG-04 | P2 | **open, MP-first exception** | App-only legal wording (the MP has none). Owner. |

All four receipts for this area in `cursor/r9-account-publish` (A4-04b, A6-01b, B-PV-04, A7-08b) and the C-T3 mount were found in code. The Core C-F5b fix is pinned in Core and holds.

## 4. Fix queue (r10)

Columns: id | severity | MP file:line | app file:line | what to do | owner. Each row is about one agent-hour. MP paths are relative to `hengyin/chengyinhub-xcx`. No money rows in this area.

### P0

None. Both r9 P0s (C-F5b, C-T3) are fixed.

### P1: parity

| id | sev | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| C-T3c | P1 | pages/publish/temp/index.wxml:105-118 (citynode 玩法形态), merchant `/api/merchant/city-node/template/submit` | Core/TemplateAuthoringContract.swift (`TemplateCityNodeInteraction`); App/MPGap/AccountPublish/AccountPublishGapRound4Views.swift:163-165 | Add a city-node submit request to the template authoring pipe when `from=citynode`, then expose the 玩法形态 `Picker` in the Round4 section for that entry only. | Cursor Core (then 1 App row) |
| C-F1b | P1 | pages/publish/fabu/index.wxml:484-604, 836-857 | App/ProjectEditRichStoryForms.swift:101 | Gallery: `PhotosPicker` list + `layout` `Picker` + `altText` `TextField`. Branch: option rows with add / delete (swipe). Divider: no fields. | Claude App |
| C-F8b | P1 | fabu topic-detail-sheet.wxml (chooseMedia) | App/ProjectEditView.swift:1025-1026 | Replace the URL `ProjectEditReferenceField`s with `PhotosPicker` uploading to `RetainedImageScope.Destination.topicCover / .topicGallery` (Core done). Same fix closes N-18. | Claude App |
| C-F7d | P1 | theme-runtime-structure.js:215 (`acts[].hostUnlock`) | App/ProjectEditView.swift:399 (`ProjectEditLookHost` area); Core/ProjectEditRuntimeActs.swift:7 | Add a `Toggle` 由工作人员开幕 per chapter bound to `ProjectEditRuntimeActs`; show Core's player-mode validation in the section footer. | Claude App |
| C-F2 (rest) | P1 | fabu node sheet | App/ProjectEditPendingPresentation.swift:81; App/ProjectEditStarterPresentation.swift:38 | Drop `.typedCoordinates()`; use a MapKit place picker. Update the 3 XCUITests. | Claude App |
| C-F4 (rest) | P1 | fabu/index.js (saveDraft=1) | App/ProjectEditView.swift:663-668 | Bar 保存草稿 = server draft; 存到本机 into the ⋯ `Menu`. Update `projectEdit.saveLocal` tests. | Claude App |
| C-T5 (rest) | P1 | temp/index.wxml:1492-1494 | App/TemplateAuthoringView.swift:608 | Move 保存到此设备 into the ⋯ `Menu`. Update the 6 tests. | Claude App |
| C-T2b | P1 | temp/index.wxml:66, 71-72 | App/OwnedTemplateConfigurationView.swift:82-98 | Bind `TemplateAuthoringSupportPhase` (redacted / failed + 重试) and `TemplateAdoptionConfirmation.pending`. | Claude App |
| C-T6b | P1 | temp/index.js (from/scope); template-intro/index.js:296 | App/AppSession.swift:4774 | Add `from:` / `scope:` to `templateAuthoringEditor`; merchants get 保存并绑定 / 保存玩法. | Claude App |
| C-T8b | P1 | utils/publish/node-game-catalog.js:105-120 | App/TemplateGameplayPickerSheet.swift:68-75 | Drive the picker from `TemplateAuthoringGameplayCatalog` (全部 + 推理). | Claude App |
| A2-02b / A2-10 | P1 | cyp js:900-1040, wxml:578-582; userinfo.js:55-58 | App/SocialPublicProfileView.swift; App/MPGap/AccountPublish/AccountPublishGapViews.swift:43 | Swap to `PublicMerchantHomeView` when `merchantHomeTarget` resolves; mount the coop bar for merchant viewers. | Claude App |
| A7-02 (rest) | P1 | app.js:617-700 | App/ProfileLocalCoverSection.swift; App/TemplateImageCropView.swift | Route cover (16:9) and template crops through `MiniCropView`; update crop pins. | Claude App |
| A1-02 | P1 | member/index.wxml:6-7 | App/QuestifyApp.swift:357; App/AccountView.swift:93-94 | Make the tabbed self profile the 我的 root; account entries go in its 我的 tab. | Claude App |
| A1-08 | P1 | member/index.wxml:6 | App/QuestifyApp.swift:358 | Signed-out 我的 = `ContentUnavailableView` 登录后查看我的主页 + 登录 button, not `WelcomeView`. | Claude App |
| A3-06 / A6-02 | P1 | gerenziliao.wxml:94; addressinfo.wxml:49 | App/ProfileEditView.swift:41; App/ParticipantFormView.swift:381-388 | Remove the confirm-before-save; save on tap, keep progress → `.sensoryFeedback(.success)`. | Claude App |
| A8-02 / A8-03 | P1 | talent/list/index.js:193-230; wxml:64-76 | App/ClubHomeView.swift; App/ClubCommunityViews.swift | Merge square posts into the hub feed; drop root sections the MP lacks. | Claude App |
| A3-05 | P1 | gerenziliao.wxml:54-56 (`bindgetphonenumber`) | App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift:5 | MP-first exception: WeChat-only API. Owner picks the iOS bind (SMS or none). | owner |

### P1: native (owner rule "EVERYTHING native")

| id | sev | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| N-05 | P1 | pages/mylike/mylike.wxml (tab bar) | App/AccountCollectionFavoritesView.swift:48, :131, :303-306 | `CYTabs` → `Picker(.segmented)` in the toolbar/first row; drop `.thinMaterial`; post cards → plain `List` rows (no background / stroke / `QuestifyCardButtonStyle`). | Claude App |
| N-09a | P1 | pages/talent/list/index.wxml | App/ClubHomeView.swift:52, :200, :142, :150, :156, :383, :385 | `cyRootHeader` → `.navigationTitle` (large); `CYSectionHeader` → `Section` header; `CYListRow`/`CYRowIcon` → `NavigationLink` + `Label`. | Claude App |
| N-09b | P1 | pages/talent/list/index.wxml | App/ClubHomeView.swift:168, :229, :304, :310, :323, :414 | `CYClubPhotoCard` / `CYClubRowCard` → `List` rows with an `MPAsset`/`AsyncImage` thumbnail; offline banner → `Section` footer; skeleton → `.redacted`; `.cy` button → `.bordered`. | Claude App |
| N-12 | P1 | pages/privacy/index.wxml:10, :22 | App/UsageConsentGateView.swift:57-77, :82, :112 | Drawn checkbox → `Toggle` (iOS has no checkbox; note it in the receipt); `ScrollView` → `Form` with the two document `NavigationLink`s; 同意 → `.borderedProminent`. Keep `authEntry.gate.*` ids. | Claude App |
| N-17 | P1 | subpackagePass/reveal/index.wxss | App/PassMembershipViews.swift:666, :706, :722, :730-736 | Remove `CYNight.ink0` background (use system background, Light + Dark), the gold `LinearGradient` wash and the gold `.shadow`. Keep the MP image via `MPAsset` and the toolbar 跳过. | Claude App |
| N-18 | P1 | fabu topic-detail-sheet.wxml | App/ProjectEditView.swift:1025-1026 | Same change as C-F8b (URL text inputs are custom inputs). Close together. | Claude App |
| N-20 | P1 | pages/publish/temp/index.wxml | App/TemplateAuthoringView.swift:285, :289, :315, :321, :671 | `ScrollView` + `CYHeroHeader` → `Form` with `.navigationTitle`; MP cover as an `Image` in the first `Section`. | Claude App |
| N-21 | P1 | pages/publish/activity/index.wxml:1-80 | App/PublishingModesViews.swift:44-77 | `ScrollView` + `CYHeroHeader` + `CYSectionHeader` + `CYListRow`/`CYRowIcon` chooser → `Form` sections with `NavigationLink`/`LabeledContent`. | Claude App |
| N-22 | P1 | pages/publish/activity/index.wxml:53-221 | App/PublishingModesViews.swift:134, :153, :304, :350-374, :357-361, :1075-1120 | Remaining `CYSectionHeader` → `Section` headers; chooser row → `LabeledContent` + chevron (no fixed 12 pt icon frame); rounded cards → `Section`s; pills → `.bordered*`. | Claude App |
| N-23 | P1 | pages/publish/template-intro/index.wxml | App/TemplateAuthoringIntroExperience.swift:115-135, :155, :160, :179 | Card grid → `List` rows (MP image via `MPAsset` / `DiscoveryArtwork` as row image); skeleton → `.redacted`; CTA → one `.borderedProminent`. Replaces C-I5 (no dark stage). | Claude App |
| N-24 | P1 | pages/square/detail/index.wxml (share) | App/SquareDetailView.swift:73, :168, :177, :304 | `CYSquareShareSheet` → `ShareLink`; `CYModal` → `.sheet` + detents or `.confirmationDialog`; route map card → MapKit `Map` + `Marker` in a `Section`. | Claude App |
| N-26 | P1 | pages/team/detail/index.wxml | App/TeamHomeView.swift:23, :85, :152, :176, :390 | `ScrollView` + `CYCard` → `List` (inset grouped) sections; keep applicant rows as list rows with swipe actions. | Claude App |
| N-27 | P1 | pages/team/detail/index.wxml | App/TeamComponents.swift:122, :193, :268, :285-381; App/TeamHomeView.swift:30-207 (`.buttonStyle(.cy…)` ×17) | `CYSheetContainer` → `.sheet` + `.presentationDetents`; `CY*ButtonStyle` → `.borderedProminent / .bordered / .borderless` (`role: .destructive` for 移出); drop custom radii. | Claude App |

### P2: parity

| id | sev | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| B-MK-05 | P2 | marketing-consent/index.js:60-80 | App/AccountComplianceViews.swift:733-760 | Send on toggle, no confirm sheet; result as section footer text. Closes the custom sheet in N-15. | Claude App |
| C-A9-r7 | P2 | activity/index.wxml:203-221 | App/PublishingModesViews.swift (real-name block) | Real-name fields inline in the `Form`. | Claude App |
| C-A8b | P2 | activity/index.wxml:158-186 | App/PublishingModesViews.swift:462-467 | Drop per-ticket 开始 / 结束 fields. | Claude App |
| C-F14b | P2 | fabu/index.wxml:163-165 | App/ProjectEditTicketSummary.swift:5 | `ProjectEditTicketGap.summary` as the section footer. | Claude App |
| C-S10b | P2 | square/detail/index.wxml:57 | App/SquareDetailView.swift | Medal as a `Label` with the MP medal `MPAsset` (no pill chrome). | Claude App |
| Team avatars | P2 | team/detail/index.wxml:102 | App/TeamComponents.swift:145 | Draw `TeamMember.memberAvatar`, fall back to `d_profile`. | Claude App |
| Mode switch | P2 | fabu/index.js `navigateTo fabu?mode=` | ProjectEditCoordinator | 复制并切换 via `ProjectEditModeCopy.copied`; no POST. | Claude App |
| A3-10 | P2 | gerenziliao.wxml:20-38 | App/ProfileEditView.swift | First `Section`: avatar + name + 更换背景 as one `Image` header (system style, no custom hero). | Claude App |
| C-F16-r7 | P2 | fabu/index.wxml:103-117 | App/ProjectEditView.swift (name `TextField`) | `axis: .vertical` on the name; update `ProjectEditFlowTests`. | Claude App |
| B-SZ-10 | P2 | shezhi.wxml:9-36 | App/SettingsView.swift | Regroup `Form` sections in MP order. | Claude App |
| B-AG-04 | P2 | — (MP has no app legal text) | App/SettingsLegalDocumentView.swift | App legal wording (MR-39). MP-first exception. | owner |

### P2: native (pages already on `List` / `Form`; mechanical swaps)

| id | sev | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| N-01 | P2 | member/index.wxml | App/AccountView.swift:69-120 (×22), :177, :202, :413 | `CYListRow`+`CYRowIcon` → `NavigationLink { } label: { Label(…, systemImage:) }`; `.cy` buttons → `.bordered*`; `cyRootHeader` → `.navigationTitle`. | Claude App |
| N-02 | P2 | member/index.wxml (header) | App/MemberHomeHeader.swift:37, :83, :92, :155, :166, :174, :255, :261, :273, :333, :348 | Remove the `LinearGradient` overlay and `strokeBorder`s; stats → `LabeledContent`/`Gauge`; skeleton → `.redacted`; buttons → `.bordered*`. | Claude App |
| N-03 | P2 | pages/userinfo/userinfo.wxml | App/SocialPublicProfileView.swift:80, :150-152, :282, :377-378, :550 | `ContentUnavailableView`; chips → `.secondary` `Text`; pill → `.borderedProminent`; drop custom radii / strokes. | Claude App |
| N-04 | P2 | pages/gerenziliao/gerenziliao.wxml | App/ProfileEditView.swift:638, :640, :715, :728, :732, :735, :746, :843, :860 | Same swaps (states, chip, pills, skeleton). | Claude App |
| N-06 | P2 | pages/address/address.wxml | App/ProfileParticipantsView.swift:222, :233-267, :241, :333 | `CYLoadSlot`/`CYSkeleton` → `.redacted`/`ProgressView`; `CYEmptyState` → `ContentUnavailableView`; chip → `.secondary` text. | Claude App |
| N-07 | P2 | pages/addressinfo/addressinfo.wxml | App/ParticipantFormView.swift:263-492, :346, :357, :446 | States → system; offline section → `Section` footer; pills → toolbar `confirmationAction` button. | Claude App |
| N-08 | P2 | pages/crop/index.wxml | App/MiniCropView.swift:66-75, :87, :127, :148 | Loading → bare `ProgressView` (no material card); `CYEmptyState` → `ContentUnavailableView` with 重试; bar buttons → `.bordered*`. Canvas stays (no Apple equivalent; note in receipt). | Claude App |
| N-10 | P2 | shezhi.wxml | App/SettingsView.swift:367, :381 | Remove the bordered rounded tile; plain `Form` row. | Claude App |
| N-11 | P2 | shezhi/about/index.wxml | App/SettingsAboutView.swift:115-130, :118, :122, :149 | Drop rounded/stroke chrome; `.redacted`; chip → `.secondary` text. | Claude App |
| N-13 | P2 | privacy/index.wxml | App/SettingsPrivacyLocationView.swift:192-205; App/PrivacyProtectionView.swift:57 | `CYLoadingStateView`/`CYEmptyState`/`CYPillButton` → `ProgressView` / `ContentUnavailableView` with `.bordered` action. | Claude App |
| N-14 | P2 | agreement/index.wxml | App/SettingsLegalDocumentView.swift:32-47 | States → `ProgressView` / `ContentUnavailableView`. Keep the text `ScrollView`. | Claude App |
| N-15 | P2 | shezhi/marketing/index.wxml | App/AccountComplianceViews.swift:682, :695, :707, :758 | Drop rounded chrome; offline banner → `Section` footer; sheet removed with B-MK-05. | Claude App |
| N-16 | P2 | pages/deregister/index.wxml | App/AccountComplianceViews.swift:258, :503, :538, :545, :583-585, :631, :802, :826, :884 | States → system; chips → `.secondary` text; offline banner/section → `Section` footer; drop rounded chrome. | Claude App |
| N-19 | P2 | pages/publish/fabu/index.wxml | App/ProjectEditView.swift:356, :424, :608, :618, :666-688, :795, :812, :826, :1004-1010 | Bottom bar → `.toolbar { ToolbarItemGroup(placement: .bottomBar) }` with `.borderedProminent` for 发布; `CYModal` → `.sheet` / `.alert`; chips → `.secondary` text; states → system. | Claude App |
| N-25 | P2 | pages/square/detail/index.wxml | App/SquareDetailView.swift:50, :52, :109, :117, :145, :570, :575, :601, :686, :699, :701 | Skeleton → `.redacted`; pills / `.cy` buttons → `.bordered*`; drop capsule stroke; `CYEmptyIllustration` → `ContentUnavailableView`. | Claude App |
| N-28 | P2 | pages/team/join/index.wxml | App/NativeNavigationCompletionViews.swift:19, :20, :54 | `CYPillButton` → `.borderedProminent` (one) + `.bordered`. | Claude App |
| N-29 | P2 | (gap mounts on fabu / temp / userinfo / team) | App/MPGap/AccountPublish/AccountPublishGapViews.swift:53-365, :154, :220-226; AccountPublishGapRound4Views.swift:107; AccountPublishGapRemainingViews.swift:91, :165; AccountPublishR8Mounts.swift:397-492, :591 | Same mechanical swaps in the shared gap components (pill styles, chip, `CYCard`, states, rounded clip). | Claude App |

## 5. Go-live blockers (P0)

None for parity. The two r9 P0s are fixed: the cast and 画面风格 now reach the server (C-F5b), and temp has 扫完回复 / 状态不好时松一点 / 可触发的结果 (C-T3; citynode 玩法形态 follows as C-T3c, P1).

For the owner's native rule, the five **custom** pages are the biggest visible gaps: talent/list (N-09a/b), pass reveal (N-17, fixed-dark gold stage), activity publish (N-21/22), template intro (N-23), team detail (N-26/27). None of the 22 pages is fully native yet.
