# Receipt: fix-parity-club (parity r1, area = club)

- Brief: `origin/design/handoff-r2:docs/briefs/fix-parity-r1.md`
- Findings: `origin/audit/parity-club:docs/audit/parity/club.md` (32 P0, 135 P1, 59 P2)
- Branch: `fix/parity-club`, rebased on `origin/ui/combined-r4` @ 90a5c8200 (the integrator's "make it build" commit)
- Swift is not installed in the cloud. Nothing here was compiled or run on a simulator. Every change copies an existing pattern; the local integrator's build is the first compile.

## Gates

| gate | result |
|---|---|
| `python3 -B tools/check_scaffold.py` | PASS (bilingual keys, references, project equivalence) |
| `python3 -B tools/check_design_lint.py` | PASS. Typography lint: raw text style 1180 (baseline 1181, **one lower**), others unchanged. No new custom back chevron or hidden back. |
| `python3 -B tools/contract_ratchet.py --check` | No new failures from this branch. The base `ui/combined-r4` already has 11 tests outside the baseline (listed below); this branch adds none. Three branch regressions found mid-run were fixed in place (see "Contract tests updated"). |
| `python3 -B tools/report_chrome.py` (club files) | Only "keep" items remain: the calendar pager glyphs and the apply wizard's in-content 上一步. Channel files are left alone (channel follows the Flutter app). |

Base failures outside the ratchet baseline (present on `origin/ui/combined-r4` before this branch): test_activity_publishing_wizard (untouched slices), test_club_leaderboard_member_navigation (byte spans), test_club_story_runtime_boundary (gameplay identifier), test_coop_fixture_lifecycle_diagnostic, test_global_search_category_recovery ×2, test_merchant_station_submission_import, test_object_badge_wall_layout, test_project_editor_readiness, test_workshop_paid_professional, test_workshop_protected_text_lifecycle.

## P0 (32)

| id | status | files | local verification |
|---|---|---|---|
| CLB-detail-01 | fixed | Core/ClubActionContracts.swift, Core/ClubActionWriting.swift, Tests/CoreTests/ClubActionCoordinatorTests.swift, ClubViewerUnavailableCurrentContractTests.swift | TEST merchant account → any club detail → 概览 header shows 加入 / 申请加入 (not 商家账号无法在此加入俱乐部); join completes. Activity signup stays merchant-blocked. |
| CLB-detail-02 | fixed | App/ClubDetailView.swift, App/ClubPublicActivityListView.swift, App/SessionClubPublicActivityListView.swift | Club detail → 活动 tab, as guest and as member: activity cards inline (no 公开活动 push, no counts, no calendar, no 已结束). Tap card → topic detail. Owner sees 发布主题. Empty club → 暂时俱乐部还没有活动. The public-topics route gate is unchanged, so a build without that grant shows the existing 不可用 state. |
| CLB-detail-03 | partial | Core/ClubCommunityContracts.swift, App/ClubCommunityViews.swift | Club feed post: 转发 / 撤销转发 goes through the reviewed write sheet to `api/club/post/repost[/undo]` `{postId}`; 分享 opens the share sheet with 「俱乐部」：first line. **Left:** share has no link (no club universal link exists yet); follow stays on the author's public profile (tap the author). |
| CLB-detail-04 | fixed | App/ClubCommunityViews.swift | Open a club feed, wait over 60 s, open a post's ⋯: 编辑 / 置顶 / 删除 / 举报 still listed; the action re-reads evidence at prepare. |
| CLB-detail-05 | fixed | App/ClubCommunityViews.swift | Club with a pinned 公告 (type 2): the feed opens with one 「📌 公告 · text ›」 row; tap opens the post detail. |
| CLB-detail-06 | fixed | Core/ClubCommunityContracts.swift, Tests/CoreTests/ClubCommunityTests.swift | Admin TEST account on someone else's post: ⋯ shows 删除 (backend `canModerate` already allows it). |
| CLB-detail-07 | deferred | — | 邀约承接 needs a native route to the topic's merchant page (`topic/merchantinfo?topicId=&scope=MERCHANT`); the app's merchant project view is only reachable from the merchant workspace. Merchants can still open the card's topic detail. |
| CLB-detail-08 | deferred | — | The native verification flow (`NativeVerificationWorkflow`) is merchant-scoped. A club-scoped scan (owner/admin/`club:activity:manage`, server judges) needs a club verification workflow. `scan=1` links open the club page. |
| CLB-detail-09 | deferred | — | 活动导演台 row per managed project needs the project→session list on the 管理 tab. Partial path: topic page primary for director phases opens the session screen (see CLB-topic-detail-02). |
| CLB-detail-10 | deferred | — | Coop pool + 我的合作 on the club 管理 tab not started. |
| CLB-detail-11 | blocked-platform | — | 带票分享 attribution only works through an MP share card (`/pages/topic/index/index?id=&sourceClubId=&clubCode=`). The iOS share sheet cannot produce that card, and the app's universal-link parser does not accept `sourceClubId` / `clubCode`, nor does registration carry them. Needs a decision on an iOS attribution path. |
| CLB-detail-12 | partial | Core/ClubCommunityContracts.swift, Core/ClubPostOriginalService.swift, App/ClubCommunityViews.swift | Owner/admin TEST account → 发布动态: toggle 作为公告发布; the request body carries `type: 2`. Member: no toggle. **Left:** 带上一次游玩记录 picker (`/api/registration/my-joined`). |
| CLB-topic-detail-01 | fixed | Core/MiniProgramPageLink.swift, App/MPReviewedPageScreen.swift, Tests | Open `pages/club/topic-detail/index?topicId=91&clubId=81` (chein:// or internal link) → topic overview. |
| CLB-topic-detail-02 | partial | App/ClubGovernanceViews.swift, Core/ClubTopicDetailPort.swift, Localizable `club.topic.primary.selfrun` = 去核销 | Topic page bottom: one primary per phase. reviewing → disabled 等待审核中; ended → 查看结算报告 → settlement; 去选一场 / 去开场 → event ops; director phases → the session screen. **Left:** rejected 修改并重新提交 (no native topic editor by id); the director actions are not inline. Not a pinned footer yet (last section). |
| CLB-topic-detail-03 | deferred | — | Director sections inside the topic page (`PlayDirectorCoordinator`) not embedded. |
| CLB-topic-detail-04 | fixed | Core/ClubTopicDetailPort.swift (`stateKey`, `notOnSaleKey`), App/ClubGovernanceViews.swift, Core/ClubGovernanceSyntheticFixtures.swift (numeric status) | Fixture topic (status 1 + startedAt) → chip 进行中, 核销 card with 3 / 2 / 8 from topic-manage-stats. Production: status 0 → 审核中, 2 → 未通过; lifecycle 2 → 定价中 · 未开售. |
| CLB-topic-story-01 | fixed | Core/MiniProgramPageLink.swift, App/MPReviewedPageScreen.swift | `pages/club/topic-story/index?topicId=91&clubId=81` → topic overview; 剧情与玩法 is one row down. |
| CLB-event-ops-01 | fixed | Core/MiniProgramPageLink.swift, App/MPReviewedPageScreen.swift, App/ClubGovernanceViews.swift | `pages/club/event-ops/index?clubId=81&topicId=91` → event ops. Topic page 接下来 → 管理场次. |
| CLB-roles-01 | fixed | Core/ClubGovernanceCommands.swift, Core/ClubGovernanceFormDraft.swift, App/ClubGovernanceCommandForm.swift, Tests/CoreTests/ClubRoleAssignmentOptionsTests.swift | Session roles → 分配 → role 本场核销: 可见客户手机号 switch + explanation; on → body has `customerPhoneVisible: true`; other roles never send it. |
| CLB-apply-01 | fixed | App/ClubOperationsContext.swift, App/QuestifyApp.swift (one environment line), App/ClubGovernanceViews.swift, App/ClubGovernanceCommandForm.swift | Host account → 成为主理人 done card → 创建我的俱乐部 → create flow. Same button under the host-apply receipt. |
| CLB-create-01 | fixed | App/ClubOperationsViews.swift | Create flow step 3: 封面 / Logo pickers above the name (same media service as edit); created club carries both. |
| CLB-enroll-01 | fixed | Core/ClubEnrollmentContracts.swift, App/ClubEnrollmentView.swift, fragments | Owner → 报名名册 → expand a team: per-session rows 「实收 ¥ · 已退 ¥ · 实收减退款 ¥」 (+ 已取消), tabular digits. Read only; the server sends it to owners only. |
| CLB-settlement-01 | fixed | Core/PayoutReceiverClient.swift, App/ClubPayoutReceiverView.swift, App/ClubGovernanceViews.swift | 管理 → 结算: 各场次结算 section, same rows as the personal page. |
| CLB-settlement-02 | deferred | — | FE reference settlement (`/api/fe/reference-settlement/{,payer,merchant,settle,dispute}`) not ported; 标记已结清 is a money write and would need the TEST-only switch. |
| CLB-customer-detail-01 | fixed | Core/ClubOpsCustomerPresentation.swift (`ClubPhoneCall`), App/ClubOpsCustomerViews.swift | Owner TEST account, customer with an 11-digit `phoneText` and `phoneCallable: true` → phone glyph (44 pt) → tel:. Masked text or no grant → no button. |
| CLB-checkin-detail-01 | fixed | Core/ClubCheckinRail.swift, App/ClubGovernanceViews.swift | Check-in detail with `canRefund: true` → 清退并退款 panel with the destructive review sheet. Dispatch stays behind the refund coordinator's TEST-only gate. |
| CLB-checkin-detail-02 | fixed | App/ClubCheckinRailView.swift | As customer-detail-01 on the check-in detail (`phoneCallable` top level). |
| CLB-group-code-01 | fixed | App/ClubGroupCodePresentation.swift | Issue a group code → 保存到相册 under the code → share sheet → 存储图像. |
| CLB-customers-01 | fixed | Core/ClubGovernanceContracts.swift, Core/ClubOpsCustomerPresentation.swift, App/ClubOpsCustomerViews.swift, App/ClubGovernanceViews.swift | Club with > 50 customers → scroll to the bottom: next page appends (no duplicates), spinner while loading, retry row on failure. |
| CLB-payout-receiver-01 | blocked (owner decision) | — | Bind needs a WeChat auth code (`SendAuthReq`) or the owner's call to hide bind. Unchanged. |
| CLB-workbench-01 | fixed | Core/MiniProgramPageLink.swift, App/MPReviewedPageScreen.swift | `pages/club/workbench/index?id=81` (or `clubId=81`) → club page on 管理. |
| CLB-workbench-02 | fixed | App/MPReviewedPageScreen.swift | `pages/club/workbench/index` with no id (and `detail?owner=1`) → 我创建的俱乐部 list. |

## P1 (fix-plan order)

| id | status | files | local verification |
|---|---|---|---|
| CLB-detail-13 | fixed | Core/ClubDetailTabs.swift, tests | Owner and member open a club → 概览 selected. |
| CLB-detail-16 | fixed (membership) | App/ClubCommunityViews.swift | Non-member signed in → club feed has no 发布动态. `memberPostAllowed` is still enforced by the server only. |
| CLB-detail-17 | fixed | App/ClubCommunityViews.swift | Unedited post → no 编辑历史; edited (version > 0) → shown. |
| CLB-detail-18 / B13 | fixed | Core/ClubCommunityContracts.swift | Admin sees 举报 on another member's comment. |
| CLB-detail-19 | partial | App/ClubPublicActivityListView.swift (embedded) | Ended, counts and calendar gone from the tab; the 时区 helper line in `ClubActivityListContent` remains. |
| CLB-detail-20 | partial | App/ClubDetailView.swift | Owner gets 发布主题 above the list; failure keeps the existing retry. Non-owner activity managers do not get 发布 yet. |
| CLB-detail-23 | fixed | App/ClubGovernanceViews.swift, App/ClubDetailView.swift | Plain member 概览 → row reads 我的治理记录. |
| CLB-detail-24 | fixed | App/ClubDetailView.swift, App/ClubMembersView.swift | Member: no 邀请朋友加入 / 邀请成员; owner and admin keep them. |
| CLB-detail-25 | no change needed | — | 重新申请 was already in base (`club.action.reapply`). |
| CLB-detail-31 | partial | App/MPReviewedPageScreen.swift | `tab=manage|overview` and `owner` honoured. `postId` scroll and `scan=1` are parsed but not acted on (scan: see CLB-detail-08). |
| CLB-detail-32 | fixed | App/ClubDetailView.swift | Club page: glass back + share on the cover; scroll → system bar with back, name, share. Edge swipe works. |
| CLB-detail-34 | deferred | — | `test_club_feed_read_parity` pins that the governance-feed detail must not inherit action/management/community context. Needs a reviewer decision before changing. |
| CLB-detail-44 | fixed | App/ClubReadScreen.swift (opt-out param), App/ClubDetailView.swift | Club page bar: no 刷新; pull to refresh works. |
| X2 / CLB-governance-14 / CLB-roles-05 / CLB-topic-detail-12 | fixed (governance reads) | App/ClubGovernanceViews.swift | Any governance read: no standing 刷新 pill; a failed read shows one secondary 重试. `ClubManagementView`'s 刷新 is kept (UI tests drive it). |
| X10 | partial | App/ClubCommunityViews.swift, App/ClubManagementView.swift, App/ClubRoleAssignmentPicker.swift | Feed review sheet shows the post words, not 俱乐部/帖子/评论 ids; join confirm drops (#id); role picker drops 场次/用户 ids. Other id rows (报名编号 etc.) remain. |
| CLB-governance-05 | fixed | Localizable, ClubGovernanceLocalizations.fragment.json, tools/build_club_governance_catalog.py | 转让主理人. |
| CLB-governance-06 | fixed | Localizable | Workspace subtitle 被封禁的成员. |
| CLB-governance-11 | partial | App/MPReviewedPageScreen.swift | Deep links resolve through `ClubGovernanceEntryRoute`: manage → workspace, report/appeal → 我的平台工单. `memberId` preselect not wired. |
| CLB-roles-02 / -03 | fixed | App/ClubRoleAssignmentPicker.swift | Role picker: 本场活动的角色; member rows show names (未命名 fallback), no ids. |
| CLB-edit-03 | fixed | Localizable | Edit hero chip 主理人. |
| CLB-badges-03 | fixed | ClubBadge.xcstrings | 勋章名最多 120 个字，说明最多 255 个字。 |
| CLB-badges-08, CLB-notify-07, CLB-customer-detail-07, CLB-checkin-detail-06, CLB-join-requests-07, CLB-customers-05 | fixed | Core/MiniProgramPageLink.swift, App/MPReviewedPageScreen.swift | Each MP link with its keys opens its screen (see `testEveryClubPageOpensWithItsMiniProgramKeys`). |
| CLB-join-requests-04 | fixed | App/ClubManagementView.swift, Tests/AppUITests/ClubManagementFlowTests.swift | Approve/reject confirm shows names only. |
| CLB-enroll-03 | fixed | Localizable, ClubEnrollmentLocalizations.fragment.json | Unknown check-in reads —. |
| CLB-topic-detail-07 | fixed | App/ClubGovernanceViews.swift | Topic page 接下来 → 管理场次 → event ops. |
| CLB-customers-03 | fixed | App/ClubOpsCustomerViews.swift | 备注 tag after the name. |
| Chrome (step 3) | fixed | ClubAIDesignView, ClubCalendarSessionRows, ClubEnrollmentView, ClubGovernanceCommandForm, ClubHostApplicationMaterials, ClubOperationsViews, ClubPostImagePicker, ClubSeriesScheduleEditor, ClubSettlementDetail, ClubPayoutReceiverView, ClubProfileChoiceEditor, ClubProfileMediaEditor, ClubWelcomeNoteEditor, ClubEventCalendarView | Pushed club pages set the inline title mode (no inherited large title); calendar pager uses chevron.left. |
| all other P1s | deferred | — | Not reached in this run (governance single-page merge, notify composer, join-request row buttons, badges sheet, create/edit direct save, story sheet, event-ops inline roster, X1 hero titles, X3 single failure, X4 confirmations, X5 destructive style). |
| X7 raw fonts | deferred | — | `codemod_typography.py` finds no unpinned site in club files: 26 are pinned by contract tests, the rest are SF Symbol sizes / monospaced. Needs the pinning tests updated together. |
| P2 | not started | — | — |

## Backend needed

- `POST /api/club/post/create`: accepts `type` from the body with no role check (`post.setType(body.getType() …)`). The 公告 (type 2) gate is client-only (owner/admin). Server should require owner / admin / `club:content:manage` for `type == 2`.
- 带票分享 (CLB-detail-11): no backend change; needs an iOS attribution path (universal link `pages/topic/index/index?id=&sourceClubId=&clubCode=` parsed and carried into registration as `sourceChannelCode`).

## Owner decisions still open

- CLB-payout-receiver-01: wire WeChat auth (`SendAuthReq`) for 同意并绑定, or hide bind with a one-line pointer to the mini-program.
- CLB-detail-34: may a club opened from the governance feed carry join/quit, posts and activities (contract currently says no)?

## Shared changes outside club files (minimal)

- `Core/MiniProgramPageLink.swift`: club rows moved from `openPages` / `identifiedPages` into per-page rules.
- `App/MPReviewedPageScreen.swift`: club cases + small helpers (`clubDetail`, `ownedClubs`, `clubGovernance`, `clubRead`, `clubOperations`, `clubQueryID`, `queryID`).
- `App/QuestifyApp.swift`: one `.environment(\.clubOperationsFactory, …)` line.
- `App/ClubReadScreen.swift` (also used by profile/roam reads): `showsToolbarRefresh` parameter, default `true` (no behaviour change for other callers).
- No DesignSystem file changed. No `tools/*_baseline.json` changed.

## Contract tests updated with the parity rulings

- `test_club_detail_tabs.py`, `test_club_detail_events_section.py`, `docs/release/ui-strings-pages-club-detail-index.json`: 活动 inline, default tab 概览.
- `test_club_customer_permissions.py`: strips the pagination hunk before the historical byte restore, as it already strips R4's.
- `test_global_chrome_domain_contract.py`: club page uses `cyHeroChrome` + `CYHeroBackButton`.
- `Tests/AppUITests/ClubDetailTabsFlowTests.swift`, `ClubManagementFlowTests.swift`: 概览 default; no `(#id)` in the confirm sheet (test names unchanged for the CI manifests).
