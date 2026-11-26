# Fix r10 — lane acct-b (account-publish §4: P1 second half, then P2)

Brief: `origin/design/handoff-r2:docs/briefs/fix-r10.md`. Source: `origin/design/handoff-r2:docs/audit/parity-r10/account-publish.md` §4.
Branch `fix/r10-acct-b`, cut from `origin/ui/combined-r7` @ d9832ac50.

Slice. The §4 P1 list has 30 rows: 17 parity rows, then 13 native rows. acct-a owns rows 1–15 (C-T3c … A3-06/A6-02).
This lane owns rows 16–30 (A8-02/03 … N-27) and every P2 row (11 parity + 17 native).

The audit ran on 82bcf2c2d. Since then, ~340 commits have landed, including native-r2 and the r9 lane's round 3 (`docs/release/receipts/fix-r9-account-publish.md` § Round 3).
Rows marked **fixed on tip** were checked again in code on this branch: a grep for `CY*` components, `.buttonStyle(.cy…)`, gradients, shadows, `CYNight`, `strokeBorder`, materials and `ScrollView` stand-ins in the cited files found none left.
The remaining `cySheet`, `cyPageTitle` and `cyPushedChrome` calls are the coordinator's native-r2 codemods for presentation and navigation. They are not chrome.

## Gates

| Gate | Result |
|---|---|
| `python3 tools/check_scaffold.py` | PASS structural checks |
| `python3 -B tools/check_a11y_lint.py` | PASS (0 new) |
| `python3 -B tools/contract_ratchet.py --check` | see the last section. The base already had 1 failure outside the baseline: `test_social_article_content…test_renderer_is_wired_only_to_existing_scoped_article_contents`. It is not in this slice. |
| Contract modules touching each changed file | all OK, except baselined `test_category_roam_registration` pins |

There is no compiler in the cloud. Every API used here was checked by grep, or is iOS 17 SwiftUI/MapKit: `Map(initialPosition:interactionModes:selection:)`, `Marker(_:monogram:coordinate:)`, `.alert(_:isPresented:presenting:actions:message:)`.

## P1 (rows 16–30)

| Row | Status | SHA | App file:line | MP | Note |
|---|---|---|---|---|---|
| A8-02 | fixed on tip | 7623036a3 (pre-audit) | App/ClubCommunityViews.swift:188-192; Core/ClubCommunityService.swift:162; App/AppSession.swift:999 | talent/list/index.js:193-230 | The 帖文 feed already merges the creative-square lane: `relationCreativeSquareLane` → `RelationFeedMerger.merge`. The audit missed it because it only looked at ClubHomeView. Shown when `communityFeatures().read` is on. |
| A8-03 | blocked | — | App/ClubHomeView.swift:132-176 | talent/list/index.wxml:64-76 | Dropping the 发现 / 我的俱乐部 / governance / 活动 sections needs the MP wxml. The MP repo is not reachable from this lane (`add_repo hengyin/chengyinhub-xcx` was denied). Those sections are also pinned by 4 contract tests (`test_club_governance_contracts`, `test_club_feed_read_parity`, `test_club_story_runtime_boundary`, `test_club_enrollment_contracts`) and 3 XCUITest files (`ClubTabTopTabsFlowTests`, `ClubCommunityUITests`, `MerchantClubDiscoveryFlowTests`). `docs/release/visual-parity.md:9` kept them on purpose. Next step: owner OK plus a simulator run. |
| A3-05 | owner | — | App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift:5 | gerenziliao.wxml:54-56 | The MP uses a WeChat-only `bindgetphonenumber`. The owner picks the iOS bind (SMS or none). |
| N-05 | fixed on tip | 2aa2141f8 (native-r2) | App/AccountCollectionFavoritesView.swift | mylike.wxml | No `CYTabs`, material or card button style left. |
| N-09a | fixed on tip | native-r2 | App/ClubHomeView.swift:192; App/DesignSystem/CYPlayerKit.swift:136-150 | talent/list/index.wxml | `cyRootHeader` is only `.navigationTitle` + `.large`, kept so the in-app language switch keeps working. No `CYSectionHeader` or `CYListRow` left. |
| N-09b | fixed | 84c867870 | App/ClubHomeView.swift:131 | talent/list/index.wxml | The offline write banner was repeated in every club row. It is now one `CYScreenOfflineWriteSection`, which collapses when nothing is queued. The rows were already `List` rows with a thumbnail, `.bordered` buttons and `ContentUnavailableView`. |
| N-12 | fixed | 178b4ac5d (r9 lane) | App/UsageConsentGateView.swift | privacy/index.wxml:10, :22 | The checkbox became a `Toggle`, because **iOS has no checkbox control**. |
| N-17 | fixed on tip | native-r2 | App/PassMembershipViews.swift | subpackagePass/reveal | No `CYNight`, gradient or shadow left. |
| N-18 | → acct-a | — | App/ProjectEditView.swift | fabu topic-detail-sheet | Same change as C-F8b (acct-a slice), so it closes with C-F8b. |
| N-20 | fixed on tip | native-r2 | App/TemplateAuthoringView.swift:323 | publish/temp | `Form` inside a `ScrollViewReader`; no hero header. |
| N-21 | fixed on tip | native-r2 | App/PublishingModesViews.swift | publish/activity:1-80 | |
| N-22 | fixed on tip | native-r2 | App/PublishingModesViews.swift | publish/activity:53-221 | |
| N-23 | fixed on tip | native-r2 | App/TemplateAuthoringIntroExperience.swift | publish/template-intro | |
| N-24 | fixed | a41514783 (share, r9 lane) + 7a158c1cb (route map) | App/SquareDetailView.swift:73; App/DesignSystem/CYSquareRouteMapCard.swift:19-80 | square/detail; square/components/route-map | The route map is now a MapKit `Map` with numbered `Marker`s and road `MapPolyline`s (`.tint`). Loading is a `ProgressView`. The night fill, stroke border, skeleton and custom pin are gone. |
| N-26 | fixed on tip | native-r2 | App/TeamHomeView.swift | team/detail | |
| N-27 | fixed on tip | native-r2 | App/TeamComponents.swift; App/TeamHomeView.swift | team/detail | |

## P2: parity

| Row | Status | SHA | App file:line | MP | Note |
|---|---|---|---|---|---|
| B-MK-05 | fixed | 3f81e65d5 (r9) | App/AccountComplianceViews.swift | marketing-consent/index.js:60-80 | |
| C-A9-r7 | fixed | 48e12ac8c | App/PublishingModesViews.swift:485-489 | activity/index.wxml:203-221 | `PublisherIdentityRegistrationSection` sits inline in the form when `requiresIdentity`. The pushed page from CF-58 is gone. |
| C-A8b | fixed | f912b83c5 | App/PublishingModesViews.swift:453; Core/ActivityPublishingWizard.swift:271 | activity/index.wxml:158-186 | Removed the per-ticket 开始 / 结束 fields and the wizard check that required them. The wire already sends the activity span (Core/PublishModesDomain.swift:124-130). Updated the mirrored model in `Tests/ContractChecks/test_activity_publishing_wizard.py`, with an MP citation. |
| C-F14b | fixed | f6ede0224 (r9) | App/ProjectEditView.swift | fabu/index.wxml:163-165 | |
| C-S10b | fixed | 2d9330c58 (r9) | App/SquareDetailView.swift | square/detail/index.wxml:57 | |
| Team avatars | fixed | 085c11af4 (r9) | App/TeamComponents.swift | team/detail/index.wxml:102 | |
| Mode switch | fixed on tip | — | App/ProjectEditModeReviewController.swift:36; Core/ProjectEditCoordinator.swift:124-133 | fabu/index.js `navigateTo fabu?mode=` | 复制并切换 makes a local copy through `ProjectDraftModeCopy.copy` into a new coordinator. Nothing is posted. |
| A3-10 | partly (on tip) | native-r2 + combined-r7 | App/ProfileCurrentAvatarView.swift:46-94 | gerenziliao.wxml:20-38 | The first section is the MP `.rv-bg` image, the avatar and now the saved nickname (`.rv-name`, :31; 城瘾玩家 fallback). Only 更换背景 is missing: it stays on 我的 (`ProfileLocalCoverSection`, App/AccountView.swift:103). Moving it needs a `ProfileLocalCoverOwner` + `SocialAccountReading` threaded through the 7 `ProfileEditView(` call sites, which is not safe to do without a compiler. |
| C-F16-r7 | blocked | — | App/ProjectEditView.swift:1046 | fabu/index.wxml:103-117 | With `axis: .vertical`, XCUI sees `textViews`, not `textFields`. 45 XCUITest references and the `project_editor_readiness.json` fixture pin `textFields["projectEdit.name"]`, so this needs a simulator run. |
| B-SZ-10 | blocked | — | App/SettingsView.swift | shezhi.wxml:9-36 | Needs the MP row order. The MP repo is not reachable from this lane. |
| B-AG-04 | owner | — | App/SettingsLegalDocumentView.swift | — | App legal wording (MR-39). |

## P2: native

| Row | Status | SHA | App file:line | Note |
|---|---|---|---|---|
| N-01, N-02, N-03, N-04, N-06, N-10, N-11, N-13, N-14, N-28 | fixed on tip | native-r2 | (files in the audit) | No CY chrome left. SocialPublicProfileView's `CYTabItem` only supplies data to a segmented `Picker`. |
| N-07 | fixed | 59d575d2c (r9) | App/ParticipantFormView.swift | |
| N-08 | fixed | 2dda6eae1 (r9) | App/MiniCropView.swift | The **crop canvas stays custom**: Apple has no crop control. |
| N-15 | fixed | 15f5e6b45 | App/AccountComplianceViews.swift:747 | The offline banner moved to the Section footer. The merchant logo tile (rounded image, initial fallback) is the MP's `mc-logo` image and stays. The confirm sheet is gone (B-MK-05). |
| N-16 | fixed | 3b29cdf8c | App/AccountComplianceViews.swift:628 | The roam-consent offline banner moved to the Section footer. The other chips and states were already system ones. |
| N-19 | fixed | 2528f55e5 | App/ProjectEditView.swift:800-860 | The three `CYModal` overlays (草稿版本选择 / 清空本地草稿 / 发布前提示) are now `.alert(presenting:)`, hosted on a background view so the long modifier chain stays small. The bottom bar was already a `ToolbarItemGroup(.bottomBar)`. |
| N-25 | fixed | d57768ea7 | App/SquareDetailView.swift:139 | `CYFooterBar` → `Divider` + `.bar`. `CYEmptyIllustration` stays as the `ContentUnavailableView` icon because it is MP empty art (image parity). |
| N-29 | fixed | 748c298d6 | App/MPGap/AccountPublish/AccountPublishR8Mounts.swift:367 | Last `.cyText(.sectionTitle)` header removed. The gap components are otherwise clean. |

## Merchant release

None. No row in this slice is merchant-only.

## Round 2 (2026-11-26)

Merged `origin/ui/combined-r7` (tip 05caead53) into this branch. No conflicts.

- **No open fixable rows left.** Every row in the slice was already fixed, fixed on tip, moved to acct-a, blocked or owner after round 1.
- **Regression check after the merge.** All cited files were grepped again for CY chrome (`CYNight`, gradients, shadows, `strokeBorder`, `CYModal`, `CYFooterBar`, `CYTabs`, `CYSkeleton`, `CYStatusChip`, `.cyText(.sectionTitle)`, materials, `.buttonStyle(.cy…)`). Nothing came back. The only hits are the two `CYScreenOfflineWriteBanner` section footers from N-15 and N-16, which are intended, and comments.
- **Blocked rows (A8-03, B-SZ-10) are still blocked.** I tried to attach the MP repo again under the new owner (`add_repo XXsocietyee/chengyinhub-xcx`). It was denied: not found, or no access. The repo docs (`docs/mp-gap`, `docs/alignment`, `docs/parity`) don't record the `shezhi.wxml:9-36` row order or the `talent/list/index.wxml:64-76` sections. I won't guess MP order.
- **Rows waiting on someone else:** A3-05 and B-AG-04 need an owner decision. C-F16-r7 and A8-03 need a simulator run. A3-10 is still partly done.
- **Gates:** scaffold PASS; a11y PASS (0 new); contract ratchet 192 failing = baseline 192, new 0.

## Round 3 (2026-11-26)

Merged `origin/ui/combined-r7` (tip ae477be47, which already holds this lane's round 2). No conflicts.

- **A3-10:** the nickname is now in the first section on tip (App/ProfileCurrentAvatarView.swift:80-94). The row stays **partly**, because 更换背景 is still on 我的. See the P2 table.
- **Regression grep** over every cited file (`CYNight`, `CYModal`, `CYFooterBar`, `CYTabs`, `CYSkeleton`, `LinearGradient`, `.shadow(`): only the two r10 comments (SquareDetailView.swift:139, ProjectEditView.swift:804).
- **Unchanged:** A8-03 and B-SZ-10 are blocked on MP source access. I did not retry `add_repo`, because it was denied twice. C-F16-r7 needs a simulator run. A3-05 and B-AG-04 need an owner decision.
- **Gates:** scaffold PASS; a11y PASS (0 new); contract ratchet 192 failing = baseline 192, new 0.
