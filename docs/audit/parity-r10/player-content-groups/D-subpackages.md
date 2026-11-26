# Group D: player-content parity + native-iOS audit r10 (subpackageA / subpackageB)

- App commit: `origin/ui/combined-r7` @ `82bcf2c2d`. r9 audited `ebf6c160c`. Deltas come from `git log ebf6c160c..HEAD -- <file>` and `git diff ebf6c160c HEAD -- <file>`.
- MP source: `hengyin/chengyinhub-xcx`: `subpackageA/pages/myproject`, `infomation`, `infomationdetail`, `assetcenter/{income-detail,earnings,analysis}`, `video-bounty`; `subpackageB/pages/im/{list,chat}`.
- Method: the same as r9. ✅ present / ⚠️ partial / ❌ missing / 💥 broken / N/A. **Page parity = (✅ + ⚠️) / (lines − N/A)**. The group has no N/A lines. Status was checked in the code, not in commit messages.
- Native check (rules: `native-r2.md`): every view file that renders the page was grepped for CY*/MP* components, card chrome, `RoundedRectangle`/`Capsule` backgrounds, gradients, hex/`CYNight`/`CYRGB` colours, forced dark, fixed fonts, `ScrollView` where `List`/`Form` is expected, and `onTapGesture`. Verdict: native = essentially none; partly = system containers with some custom chrome; custom = custom chrome dominates. Group native % = (native 1, partly 0.5, custom 0) / pages.
- MP-first (`owner-decisions-1124.md`). No row in this group is money: the MP 提现 only opens a CS popup with no write (`earnings/index.js:59-76`).
- Since r9, only four of this group's files changed: `MPReviewedPageScreen.swift` (other routes), `WalletCommerceViews.swift` (139e06853, payout switch for production, not the D5 gate), `PublishingModesViews.swift` (d726425db, icons only) and `PlayerContentRound2Views.swift` (13edb1f90, a failed article image is now dropped instead of leaving a blank block). No D queue row was closed.

## 1. Per-page parity (r9 → r10) and native verdict

| page | r9 | r10 | native | non-Apple elements |
|---|---|---|---|---|
| D1 myproject/index | 24/24 | 24/24 | custom | ~20 |
| D2 infomation | 15/16 | 15/16 | custom | ~14 |
| D3 infomationdetail | 10/10 | 10/10 | partly | ~9 |
| D4 income-detail | 14/14 | 14/14 | partly | ~6 |
| D5 earnings/index | 15/15 | 15/15 | custom | ~17 |
| D6 analysis/index | 12/12 | 12/12 | partly | ~8 |
| D7 video-bounty | 16/16 | 16/16 | custom | ~22 |
| D8 im/list | 19/19 | 19/19 | partly | ~9 |
| D9 im/chat | 21/21 | 21/21 | custom | ~35 |
| **total** | **146/147 (99.3%)** | **146/147 (99.3%)** | **22% native** (4 partly, 5 custom) | |

No line changed status. The D3 #8 img/a line stays ⚠️: 13edb1f90 hides failed images but blocks still come after the text.

## 2. r9 row status

| id | r9 sev | r10 status | evidence (HEAD `82bcf2c2d`) |
|---|---|---|---|
| R7-PC-D1-4 | P1 | **open** | App/MyProjectTabViews.swift:72-86. The 模板 tab is still one 查看我的节点玩法 `NavigationLink` (:77-79). No inline `/api/template/my-list` rows. |
| R9-PC-D9-1 | P2 | **partly** | App/MessagingHistoryView.swift:203 still maps every `+` item to `{ _ in showingAttachControls = true }`; :219 pushes the generic controls page. Menu at App/MessageActionComposer.swift:136-141. |
| R9-PC-D4-1 | P2 | **partly** | Deep link still builds `WalletIncomeView(... showsCooperationFinance: false)` with no `organizerFinance` (App/MPReviewedPageScreen.swift:162-165). 主办分润 is still a separate tab bar (App/WalletCommerceViews.swift:794, `WalletEarningsTabBar`), not the 4th chip. |
| R9-PC-D5-1 | P2 | **partly** | App/WalletCommerceViews.swift:235-238 shows 提现 → `WithdrawalSupportContactView` with no `withdrawable` gate and no 暂无提现权限 toast. `MemberRoleInfo` already decodes `permission.withdrawable` (App/MemberHomeFixture.swift:58), so the read exists. |
| R9-PC-D1-1 | P2 | **partly** | App/PublishingModesViews.swift:253-255 (`openProjectsAfterResult`) and :717 (receipt link) still open the old `PublishingProjectsView`. |
| R9-PC-D3-1 | P2 | **partly** | App/SocialGuideViews.swift:66-74 still renders text, then media blocks. Images still have no accessibility label (App/MPGap/PlayerContent/PlayerContentRound2Views.swift:177-181, `SocialArticleRemoteImage` :198-230). 13edb1f90 only drops failed images. |
| R7-PC-D2-4 | P2 | **open** | App/SocialGuideViews.swift:30-33. The doc row is still a `NavigationLink` push, not a sheet. |
| R9-PC-D9-2 | P2 | **open** | App/CommunityMemberReportSheet.swift is unchanged: `ScrollView` :108, hand-styled field :183-191, `CYPillButton` rows :136-137, :163-171, :202-203. |
| R9-PC-D7-1 | P2 | **open** | App/VideoBountyView.swift is unchanged: `ScrollView` :140, `MPCard` :199, hand-padded `TextField`s :200-208. |
| R9-PC-D7-2 | P2 | **open** | Dead attribution code is still there: App/VideoBountyView.swift:111-112, 126-127, 179, 223-238, 316-365. |

**Counts: 0 fixed · 5 partly · 5 open (10 r9 rows).**

## 3. Native findings per page

**D1 myproject (custom).** The container is a `List(.insetGrouped)`, but every row is a custom card and the type tabs are hand-drawn.
- App/CreatorContentViews.swift:170-190 custom underline tab strip (`Button` + `Capsule` underline :180, `.buttonStyle(.plain)`) in place of a segmented `Picker`.
- App/CreatorContentViews.swift:133-142 card rows (`QuestifyCardButtonStyle` :138, `.overlay` more button :141, `.questifyCardListRow` :142, :146).
- App/CreatorContentViews.swift:199-229 `card()` with cover `clipShape(RoundedRectangle)` :206, `CYStatusChip` :209, `Divider().overlay` :216, `.cyDomainCard(radius:padding:)` :229.
- App/CreatorContentViews.swift:45-65 issue view: hand-built state with `CYPillButton` :61, :65 (should be `ContentUnavailableView` + `.borderedProminent`).
- App/CreatorContentViews.swift:101 `CYStatusChip` offline badge; :124 `CYLoadingStateView`; :151-152 `.cyDomainScreen`, `.cyHideTabBar`.
- App/MyProjectTabViews.swift:81 `CYEmptyState`; :98-99 `CYStateArt` + `cyText`; :113 `CYEmptyState`; :164 red `Circle` dot.
- App/ProjectOwnedContentViews.swift:136 `CYEmptyState`.

**D2 infomation (custom).** `List` container, but the top mode cards use fixed dark hex colours on a player page.
- App/SocialGuideXcxParity.swift:27-47 mode card: `CYNight.ink2` disc :31, glass edge :32, white `RoundedRectangle` 去看看 pill :41, `CYNight.ink1` card background :46, stroke border :47. `CYNight` is `CYRGB(hex:)` (near-black), so these cards stay dark in Light mode.
- App/SocialGuideTemplateSection.swift:148-151 cover `clipShape(RoundedRectangle)`; :163-165 white `RoundedRectangle` 开始 pill; :133, :174 `CYEmptyState`; :185 `CYLoadingStateView`.
- App/SocialGuideViews.swift:25 `CYEmptyState`; :33 `CYListRow` with `clipShape(RoundedRectangle)` art; :41 `.cyDomainPageBackground()`; :119-133 `SocialInformationArt` `RoundedRectangle` tile.

**D3 infomationdetail (partly).** A `List` with mostly plain text.
- App/SocialGuideViews.swift:55, 77, 80, 84, 87 `CYEmptyState` (use `ContentUnavailableView`).
- App/SocialGuideViews.swift:100 `.cyDomainPageBackground()`; :102 `.tint(CYDomainPalette(.player).brand)`.
- App/SocialGuideViews.swift:141-157 hand-padded cover header (`Divider().overlay`, custom padding); could be a plain `Section` header.
- App/MPGap/PlayerContent/PlayerContentRound2Views.swift:219 image `clipShape(RoundedRectangle)`.

**D4 income-detail (partly).** `List` + a real `UISegmentedControl` tab bar (App/WalletEarningsAccessibleTabs.swift:27), but each row is a card.
- App/WalletCommerceViews.swift:753, 758-762 `WalletIncomeListCard` → `.cyDomainCard` on every income row.
- App/WalletCommerceViews.swift:710 `Circle` icon background; :715-721 `Capsule` source badge.
- App/WalletCommerceViews.swift:584 `CYSkeleton`; :862 `CYEmptyState`; :878 `CYPillButton`.

**D5 earnings (custom).** A `.plain` `List` with a hidden background, a custom hero and card surfaces.
- App/WalletCommerceViews.swift:163, 190 `List` `.listStyle(.plain).scrollContentBackground(.hidden)`; :1235-1270 `WalletEarningsHero` custom amount hero.
- App/WalletCommerceViews.swift:1185-1210 `WalletQuickAction` circle buttons (`.background(... in: Circle())` :1204).
- App/WalletCommerceViews.swift:272, 291, 296, 325 `.orderCardSurface()` cards; :342, :382 `CYRowIcon` / `CYListRow(card: true)`.
- App/WalletCommerceViews.swift:167, 294 `CYSkeleton`; :352-378 the 更多 sheet: hidden-background `List`, `.cyDomainPageBackground`, `.cyDomainSheet`.
- App/WalletEarningsParity.swift:26 `CYEmptyIllustration`; :33 `CYPillButton`.
- App/WalletEarningsOverview.swift:63 `CYSkeleton`; :114 `CYStatNumber`; :165-166 custom page background.

**D6 analysis (partly).** `List(.insetGrouped)` + system `Picker` (:82-85, :191), but the charts are hand-drawn.
- App/WalletIncomeAnalysisView.swift:141-142 `GeometryReader` + `Capsule` bars; :169-173 `GeometryReader` + `RoundedRectangle` month chart (use Swift Charts `BarMark`).
- App/WalletIncomeAnalysisView.swift:34, 46 `CYSkeleton`; :101 `CYEmptyState`; :116 `CYStatNumber`; :50 custom background; :66 `.cyDomainScreen`.

**D7 video-bounty (custom).** `ScrollView` + `VStack` with MP kit components. The appeal sheet is forced dark.
- App/VideoBountyView.swift:140 `ScrollView`; :153, :195 `MPChipTabs` (tabs and platform); :172, :334 `MPNightGround`; :173, :188 `.cyDomainScreen`.
- App/VideoBountyView.swift:199-213 `MPCard` + hand-padded `TextField`s (:200-208), `MPDivider` :205, `MPInlineError` :198, :212-213.
- App/VideoBountyView.swift:214 `CYMorphButton` (use `.borderedProminent`).
- App/VideoBountyView.swift:249-309 `MPLoadSwitch`, `MPRows`, `MPRow`, `MPGatedNote`; `CYEmptyState` :145, :149, :251, :301, :329; `CYStatusChip` :260.
- App/VideoBountyView.swift:392-403 appeal sheet: hand-padded `TextField` on `CYNight.ink1` `RoundedRectangle` :396, page ground `CYNight.ink0` :403. This is fixed near-black hex, so the sheet is dark in Light mode.

**D8 im/list (partly).** `List(.insetGrouped)` with a segmented `Picker` (:23).
- App/MessagingHomeView.swift:39-46 outbox is a `ScrollView` with `CYEmptyState` :43.
- App/MessagingHomeView.swift:114, 264 `CYPillButtonStyle`; :249 `CYEmptyState`; :123 `.cyDomainPageBackground`; :182 `.cyDomainScreen`.
- App/IMInboxViews.swift:102 `CYIMCoverArt` avatar; :161 `CYStatusChip` 官方 tag.

**D9 im/chat (custom).** Chat bubbles themselves have no system control and are accepted. Everything around them is custom.
- App/MessagingHistoryView.swift:652-690 `CYOptionSheet` / `CYOptionSheetItem` (use `confirmationDialog`); :905-910 `CYConfirmConsequence` / `CYConfirmSheet` (use `.alert` / `confirmationDialog`); :649, :663 `.cyDomainSheet`.
- App/MessagingHistoryView.swift:546-562 system-notice card (`Circle` background :547, `RoundedRectangle` card :562); :187, :195 hand-styled reply bars; :253 `CYIMCoverArt`; :280 `.cyDomainPageBackground`.
- App/MessagingHistoryView.swift:318-324 `CYListRow` + `CYRowIcon`; :790 `CYSkeleton`; :803, :819, :837 `CYEmptyState`.
- App/MessageActionComposer.swift:192, 196 `.blur` send animation; :202 `Circle` send button; :216 `RoundedRectangle` field background; :221 custom bar; :245-254 `CYConfirmSheet` + `.cyDomainSheet`; :291 `RoundedRectangle` receipt bubble.
- App/CommunityMemberReportSheet.swift:108-113 `ScrollView` + custom background; :132 `CYSkeleton`; :136-137, :163-171, :202-203 `CYPillButton`; :150, :188 `RoundedRectangle` backgrounds; :183-191 hand-styled text field (R9-PC-D9-2).

## 4. Group fix queue (D), r10

| id | severity | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| R7-PC-D1-4 | P1 | subpackageA/pages/myproject/index.wxml:68-114 | App/MyProjectTabViews.swift:72-86 | Render the `/api/template/my-list` rows inline on the 模板 tab (提交广场 / 上下架广场 / 审核记录 / 删除) in place of the single link. Reuse the shelf host's row actions. | Claude App |
| R10-PC-D-N13 | P1 | subpackageA/pages/video-bounty/index.wxml | App/VideoBountyView.swift:385-405 | Native: the appeal sheet is forced dark (`CYNight.ink0` / `ink1` hex). Rebuild as a `Form` with a vertical `TextField` section and toolbar 提交 / 取消, on system background. | Claude App |
| R9-PC-D9-1 | P2 | subpackageB/pages/im/chat/index.wxml:196; index.js:45 | App/MessagingHistoryView.swift:203,219; App/MessageActionComposer.swift:136-141 | Route each `+` item to its own flow: 图片 → image picker, 位置 → location send, 路线 → `ContextualTopicPicker`. | Claude App |
| R9-PC-D4-1 | P2 | subpackageA/components/scene-asset-income-detail/index.js:35-38 | App/MPReviewedPageScreen.swift:162-165; App/WalletCommerceViews.swift:794 | Pass `organizerFinance` on the income-detail deep link too. Show 主办分润 as the 4th filter segment, not a separate tab bar. | Claude App |
| R9-PC-D5-1 | P2 | subpackageA/pages/assetcenter/earnings/index.js:61-76 | App/WalletCommerceViews.swift:235-238 | Gate 提现 → CS on `permission.withdrawable` (already decoded in `MemberRoleInfo`); without it, show 暂无提现权限. No write. | Claude App |
| R9-PC-D1-1 | P2 | subpackageA/pages/myproject/index.wxml:8-10 | App/PublishingModesViews.swift:253-255, 717 | Point the post-publish 我的项目 links at `makeProjects`, then retire `PublishingProjectsView`. | Claude App |
| R9-PC-D3-1 | P2 | subpackageA/pages/infomationdetail/infomationdetail.js:116-125 | App/SocialGuideViews.swift:66-74; App/MPGap/PlayerContent/PlayerContentRound2Views.swift:162-230 | Render text / img / a in document order as one block list. Add accessibility labels to images. | Claude App |
| R7-PC-D2-4 | P2 | subpackageA/pages/infomation/infomation.wxml:78-83 | App/SocialGuideViews.swift:30-33 | Open the doc detail as a sheet that closes back to the list, not a push. | Claude App |
| R9-PC-D9-2 | P2 | subpackageMember/components/cy/report-sheet/index.wxml | App/CommunityMemberReportSheet.swift:108-113,132-137,150,163-205 | Native: rebuild as a `Form` (reason section, text section, toolbar 提交), `ContentUnavailableView` for load-failed / result, system buttons. | Claude App |
| R9-PC-D7-1 | P2 | subpackageA/pages/video-bounty/index.wxml | App/VideoBountyView.swift:140,195-213 | Native: URL and group fields in `Form` / `Section` rows instead of `MPCard` + padded `TextField`s. | Claude App |
| R9-PC-D7-2 | P2 | subpackageA/pages/video-bounty/index.wxml:22-55 | App/VideoBountyView.swift:111-112,126-127,179,223-238,316-365 | Delete the unused attribution sheet and callbacks. | Claude App |
| R10-PC-D-N1 | P2 | subpackageA/pages/myproject/index.wxml | App/CreatorContentViews.swift:170-190 | Native: replace the hand-drawn underline tab strip with a segmented `Picker`. | Claude App |
| R10-PC-D-N2 | P2 | subpackageA/pages/myproject/index.wxml:30-60 | App/CreatorContentViews.swift:133-146,199-229 | Native: drop `cyDomainCard` / `QuestifyCardButtonStyle` / `questifyCardListRow`; use plain `List` rows (thumbnail, title, secondary text); `CYStatusChip` → secondary `Text`. | Claude App |
| R10-PC-D-N3 | P2 | subpackageA/pages/myproject/index.wxml | App/CreatorContentViews.swift:45-65,101,124; App/MyProjectTabViews.swift:81,98-99,113; App/ProjectOwnedContentViews.swift:136 | Native: states → `ContentUnavailableView` with `.borderedProminent` actions; `CYLoadingStateView` → `ProgressView`. | Claude App |
| R10-PC-D-N4 | P2 | subpackageA/pages/infomation/infomation.wxml | App/SocialGuideXcxParity.swift:20-55 | Native: mode cards → plain `List` rows (`Label` + `.bordered` 去看看). Remove `CYNight` hex colours and `RoundedRectangle` chrome. | Claude App |
| R10-PC-D-N5 | P2 | subpackageA/pages/infomation/infomation.wxml | App/SocialGuideTemplateSection.swift:133,148-166,174,185 | Native: template rows without the white `RoundedRectangle` pill (`.bordered` button or chevron row); `ContentUnavailableView` / `ProgressView` for states. | Claude App |
| R10-PC-D-N6 | P2 | subpackageA/pages/infomation/infomation.wxml | App/SocialGuideViews.swift:25,33,41,119-133 | Native: doc rows as standard `NavigationLink` labels (no `CYListRow`, no custom art tile); `ContentUnavailableView`; drop `cyDomainPageBackground`. | Claude App |
| R10-PC-D-N7 | P2 | subpackageA/pages/infomationdetail/infomationdetail.wxml | App/SocialGuideViews.swift:55,77-87,100-102,141-157; App/MPGap/PlayerContent/PlayerContentRound2Views.swift:219 | Native: `ContentUnavailableView` for the five states; drop custom page background / palette tint; plain title header; no image clip shape. | Claude App |
| R10-PC-D-N8 | P2 | subpackageA/pages/assetcenter/income-detail/income-detail.wxml | App/WalletCommerceViews.swift:584,710,715-721,753-762,862,878 | Native: income rows as plain `List` rows (no `cyDomainCard`); badge as secondary text; `ContentUnavailableView`; `.bordered` button. | Claude App |
| R10-PC-D-N9 | P2 | subpackageA/pages/assetcenter/earnings/index.wxml | App/WalletCommerceViews.swift:163-190,1235-1270 | Native: `.insetGrouped` `List` with system background; hero as a `Section` with large system-styled amount; `CYSkeleton` → `ProgressView` / `.redacted`. | Claude App |
| R10-PC-D-N10 | P2 | subpackageA/pages/assetcenter/earnings/index.wxml | App/WalletCommerceViews.swift:272-325,342,352-382,1185-1210 | Native: replace `orderCardSurface` with `Section`s; quick actions as `Label` buttons in a `Section`; `CYListRow` / `CYRowIcon` → `Label`; 更多 sheet as a standard `List`. | Claude App |
| R10-PC-D-N11 | P2 | subpackageA/pages/assetcenter/earnings/index.wxml | App/WalletEarningsParity.swift:20-40; App/WalletEarningsOverview.swift:63,114,165-166 | Native: zero-balance note → `ContentUnavailableView` + `.borderedProminent`; system background; plain `Text` amounts. | Claude App |
| R10-PC-D-N12 | P2 | subpackageA/pages/assetcenter/analysis/index.wxml | App/WalletIncomeAnalysisView.swift:34-66,101,116,130-180 | Native: Swift Charts `BarMark` for both charts; `ContentUnavailableView`; `ProgressView`; system background. | Claude App |
| R10-PC-D-N14 | P2 | subpackageA/pages/video-bounty/index.wxml | App/VideoBountyView.swift:140-188 | Native: page container → `List`; `MPChipTabs` tabs → segmented `Picker`; drop `MPNightGround`; `CYMorphButton` (:214) → `.borderedProminent`. | Claude App |
| R10-PC-D-N15 | P2 | subpackageA/pages/video-bounty/index.wxml | App/VideoBountyView.swift:145-149,249-309 | Native: `MPLoadSwitch` / `MPRows` / `MPRow` / `MPGatedNote` → `List` rows + footer; `CYEmptyState` → `ContentUnavailableView`; `CYStatusChip` → secondary text. | Claude App |
| R10-PC-D-N16 | P2 | subpackageB/pages/im/list/index.wxml | App/MessagingHomeView.swift:39-46,114,123,182,249,264 | Native: outbox as a `List` with `ContentUnavailableView`; `CYPillButtonStyle` → `.bordered` / `.borderedProminent`; drop custom page background. | Claude App |
| R10-PC-D-N17 | P2 | subpackageB/pages/im/list/index.wxml | App/IMInboxViews.swift:102,161 | Native: inbox row avatar and 官方 tag without `CYIMCoverArt` / `CYStatusChip` (system image avatar, secondary text tag). | Claude App |
| R10-PC-D-N18 | P2 | subpackageB/pages/im/chat/index.wxml | App/MessagingHistoryView.swift:649-690,905-910 | Native: `CYOptionSheet` → `confirmationDialog`; `CYConfirmSheet` → `.alert` / `confirmationDialog`. | Claude App |
| R10-PC-D-N19 | P2 | subpackageB/pages/im/chat/index.wxml | App/MessagingHistoryView.swift:187-195,253,280,318-324,546-562,790-837 | Native: notice card without `RoundedRectangle`; `CYListRow` / `CYRowIcon` → `Label`; states → `ContentUnavailableView` / `ProgressView`; drop custom page background. Bubbles stay. | Claude App |
| R10-PC-D-N20 | P2 | subpackageB/pages/im/chat/index.wxml | App/MessageActionComposer.swift:192-221,245-254,291 | Native: composer field as a system `TextField` (no custom `RoundedRectangle` / blur), send as a system button; `CYConfirmSheet` → `confirmationDialog`. | Claude App |

**Open in D after r10: P0 0 · P1 2 · P2 28** (10 carried r9 rows: 1 P1 + 9 P2; 20 new native rows: 1 P1 + 19 P2). **Fixed since r9: 0.** No money rows. No owner-decision rows.
