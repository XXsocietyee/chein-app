# fix-1128b-social receipt (second wave, lane social / mp-publish)

Branch `fix/1128b-social` from `origin/ui/combined-r7` @ `3348aa51f`. Plan: `origin/audit/1128-plan:docs/audits/1128-plan.md`
(gaps #1, #2, #3, #4, #26, #27). Backend: hengyin `origin/us/r3-functional` (`ApiCommunityPostController`,
`CommunityPostServiceImpl`, `ApiCommonController.uploadOSS`, `ApiActivityController`). MP reference: `chengyinhub-xcx/`
(`pages/square/detail/index.js:493-540`, `subpackageA/pages/myproject/index.js:508,580,1195-1216`, `wx.chooseLocation`).

There is no Swift compiler in this environment. Nothing was built or run on a simulator, and no live backend was called.
Only the Swift-free gates below ran.

## Root cause and how it was switched on

The screens and request bodies already matched the backend. Release never issued their approvals. The changes:

- **Layer 1, app approvals.** Four gaps now get approvals from the Release composition:
  - #1–#3 get `SquareCommunityWriteApproval`, issued by `MPFirstSocialApprovals.community`.
  - #4 gets the `.publishingRead/.publishingWrite` routes in the Release `BusinessRuntimeConfiguration`.
  - #27 gets `ActivityEditingGrants`, issued by `MPFirstSocialApprovals.activityEditing`.
- **Layer 2, the composition transport.** `ReviewedProductionFormMutationRoute.acceptsPlayerWrite` now admits:
  - the publishing and activity-edit POSTs;
  - the report receipt GETs.

  `admitsPlayerWriteQuery` admits `community-trust/reports/mine?requestId=`. The v1 community writes were already admitted under `grant.square`.
- **Layer 3, the China production allow-list.** `PublishingTabRoutes.productionOwnerGrant` adds the publishing and edit paths to `ChinaReviewedRouteCapability.admitsChinaProductionCall`. They were marked `liveInProduction` but were not wired. This set is kept outside `wiredPatterns`, so the counts do not move.

Every approval is issued only when this viewer has a live player-write grant, `ReviewedProductionGateLeases.playerWriters`. That requires all of:
- a reviewed deployment with player writes on;
- the China market;
- the role `player` or `club`.

**Merchant stays off.** A merchant account never gets a player-write grant, and no merchant path is in any new set.

## Gaps

| # | Gap | Fix | Files | Proof (tests) |
|---|---|---|---|---|
| 1 | Square like / bookmark / comment / reply / comment-like never send (M-01b/c, M-13b) | See the #1 section below the table | Core/SquareCommunityActionAccess.swift (new); Core/SocialMemberActionSessionOwner.swift; App/AppSession.swift (one argument on an existing line); App/MPFirstSocialApprovals.swift (new); App/SquareDetailView.swift | Tests/CoreTests/SquareCommunityActionAccessTests.swift (templates, binding, the exact POST body, DELETE unbookmark, rejection → `.rejected`, no approval → nothing sent, receipt decoding); Tests/AppUnitTests/MPFirstSocialApprovalsTests.swift `testReleaseCompositionIssuesTheCommunityWriterForPlayersAndClubs`, `testCompositionTransportAdmitsTheSquareWritesTheWriterSends` |
| 2 | Square composer can't post (M-02a/c) | See the #2 section below the table | App/AppSession.swift (two existing lines); App/MPFirstSocialApprovals.swift; App/SquareBrowserView.swift; App/MPGap/AccountPublish/AccountPublishR8Mounts.swift; App/AccountView.swift | `testReleaseCompositionIssuesTheCommunityWriterForPlayersAndClubs` (grants live / media / legal); `testCompositionTransportAdmitsTheSquareWritesTheWriterSends` (posts, publish) |
| 3 | UGC report on posts and comments (M-04a; App Store 1.2) | See the #3 section below the table | App/AppSession.swift (existing lines); App/MPFirstSocialApprovals.swift; App/ReviewedPlayerWriteLeases.swift; App/AppCompositionRoot.swift (same line); App/SquareDetailView.swift | `testReportReceiptReadsAreAdmittedAndTheWriteRidesTheSquareGrant` |
| 4 | 发布 tab "+" and club 发布活动 do nothing (H-06a, H-13a) | See the #4 section below the table | Core/PublishingTabRoutes.swift (new); Core/ChinaReviewedRouteCapability.swift (one line); App/ReviewedPlayerWriteLeases.swift; App/MPFirstSocialApprovals.swift | `testReleaseCompositionGrantsThePublishingRoutesToPlayersAndClubs`, `testMerchantGetsNoPublishingRoutes`, `testCompositionTransportAndProductionHostAdmitThePublishingWrites` |
| 26 | Place pickers return nothing (H-07) | See the #26 section below the table | App/PublishingPlaceDropPin.swift (new); App/PublishingMapKitAdapter.swift; App/PublishingModesViews.swift; App/SessionPublishingModesView.swift; App/ProjectNodePlacePicker.swift | `testPlayerPublishPickersUseAnEnabledMapKitAdapterAndADroppedPinIsAPlace` |
| 27 | Activity 编辑 is a dead control (H-13b, O-11c) | See the #27 section below the table | App/MyProjectActivityEditEntry.swift (new); App/AppCompositionRoot.swift (same line); App/ProjectOwnedContentViews.swift; App/MyProjectTabViews.swift; App/MyProjectActivityEditorAdapter.swift; App/SessionPublishingModesView.swift; App/ActivityDetailView.swift | `testReleaseCompositionIssuesStableActivityEditingGrants`, `testActivityEditRowRuleMatchesTheMiniProgramCanEdit`, and the `api/activity/info|update` rows of `testCompositionTransportAndProductionHostAdmitThePublishingWrites` |

### #1 Square writes

**The writer.** `SquareCommunityActionAccess` sits in front of the member access, so follow and 私信 are unchanged. It sends the v1 commands that `SocialActionRequestBuilder` already builds, and only on these exact routes (ApiCommunityPostController.java:128-183):
- `POST posts/{id}/actions` and `DELETE posts/{id}/actions/{LIKE|BOOKMARK}`;
- `POST posts/{id}/comments`;
- `POST comments/{id}/actions` and `DELETE comments/{id}/actions/LIKE`.

**The server's answer decides the result:**
- `code 200` means confirmed;
- a business code or a 401 means rejected;
- an unreadable answer means the outcome is unknown, and the write is never resent automatically.

**The MP toggle.** Like, bookmark, comment-like and double-tap like now toggle at once through `SocialActionCoordinator.sendImmediately`, with no review sheet, as in the MP. The post or the thread is then re-read, so the counts and the liked/saved state come from the server.

**UI states:**
- an inline message for not sent, rejected or unknown;
- the controls are disabled while a write is in flight;
- a signed-out viewer does not see the controls.

**Comments and replies** keep their editor. When it closes, the post and the thread are re-read. Legacy square posts keep the reviewed editors.

### #2 Square composer

- `squareWorkspace()` gets a live `SquareWorkspaceService`, plus `SquareWorkspaceGrants` live, media and legal when the writer is issued.
- The publish loop is: guideline → `uploadOSS` (`bizType=COMMUNITY_POST`, up to 6 images) → `media/register` → `POST posts` → `publish` → read the post back.
- The backend accepts the returned URL as `objectKey` through `canonicalMediaKey` (CommunityPostServiceImpl.java:145-152).
- The retained workspace is rebuilt when the grants change.
- The square feed reloads after a confirmed publish.
- The own-profile composer opens the same workspace.

### #3 Report

- `squareReportContext()` builds `SquareReportService(readsEnabled: on, grant: on ? .reviewedInjection : .disabled)`, so:
  - the reasons load (`capabilities`);
  - `POST api/v1/community/reports` is sent with the body that already matched `CommunityReportSubmitRequest`.
- The receipt and own-request reads (`community-trust/reports/{id}`, `/mine?requestId=`) are admitted.
- **已举报:** a reported post (in the ⋯ menu) or comment (the inline 举报) now reads 已举报 and is disabled. This is the coordinator's durable lock, so it survives a relaunch.

### #4 发布 routes

- `MPFirstSocialApprovals.publishingRoutes` adds the read and write routes to `sessionDependencies` for player and club. It applies the same `served` filter as `projectEditorRoutes`.
- With those routes, `publishingService` is non-nil, so the 发布 tab "+" and the club 发布活动 sheet open and can submit.
- The AI quota keeps its own grant.

### #26 Place pickers

- `PublishingMapKitAdapter.playerPublishing` (enabled) powers the activity 选择地点 and quick-publish pickers. They search with `MKLocalSearch`.
- The picker always shows a map. A tap drops a pin: the name comes from `CLGeocoder` reverse geocoding (otherwise 地图选点), and the coordinate fills `draft.place` and `addressName` (name, lat, lng).
- The topic-editor stop picker can choose its search centre on the map (fills the latitude and longitude). Stops still bind to `/api/city/nodes`, as the server requires.
- Merchant pickers keep the off adapter.

### #27 Activity 编辑

- `makeSession()` passes `activityEditingApproval: MPFirstSocialApprovals.activityEditing(self)`. That is one stable read/update grant per viewer, because the transport compares `currentGrant == grants`.
- **The 编辑 row.** 我的项目 activity rows get 编辑 first in the long-press / ⋯ menu, following the MP `canEdit` rule: running, notStarted, offline, pending or rejected, and not merchant-taken. It opens `MyProjectActivityEditorDestination`.
- **After a server-acknowledged save:**
  - the list re-reads (existing `acceptSave`);
  - `ActivityEditSavedBroadcast` makes the activity detail behind the editor re-read (`.cyActivityEditSaved`).

## Strings (en + zh-Hans, Resources/Localizable.xcstrings)

The new keys:
- `social1128.instant.signedOut`, `.notSent`, `.rejected`, `.unknown`;
- `social1128.reported`;
- `social1128.place.dropped`, `.mapHint`, `.tapHint`, `.pickCenter`.

## Contract tests updated (old behaviour deliberately changed, gap #1)

- `Tests/ContractChecks/test_bk_backend_sync.py::test_legacy_square_bookmark_never_routes_through_community_id`. The star stays inside the `communityV1` branch, but it now calls `bookmarkTapped`. The reviewed bookmark editor is the fallback.
- `Tests/ContractChecks/test_w2_07_square_parity.py::test_detail_action_row_reuses_reviewed_editors`. Like and bookmark call `likeTapped` / `bookmarkTapped`. The reviewed editors are pinned as `fallback:` routes.

## Gates (final tree)

| Gate | Result |
|---|---|
| `python3 tools/generate_project.py` | 909 app-unit classes in 4 shards (MPFirstSocialApprovalsTests included) |
| `python3 tools/check_scaffold.py` | PASS structural checks, 21352 bilingual keys |
| `python3 tools/check_appsession_ratchet.py` | PASS. AppSession.swift 7977 / 7977 and AppCompositionRoot.swift 4175 / 4175: the glue sits on existing lines, and new code is in new files |
| `python3 tools/contract_ratchet.py --check` | see the final run in the PR / commit message (target: new 0) |
| `python3 tools/check_design_consistency.py` | PASS |
| `python3 tools/check_a11y_lint.py` | PASS, 0 new |

## Owner actions

1. **US market.** The type `SquareCommunityWriteApproval` accepts any market. But the US composition has no player-write grant: `notePlayerWrites` is China-only, as are `playerWriters` and `admitsPlayerWriteQuery`. So in the US build, square writes, 发布 and activity edit still stay closed at the composition transport. Opening US player writes is one cross-cutting switch. It needs an owner decision, and it is not done here. `testUnitedStatesHasNoPlayerWriteGrantYet` pins the current state.
2. **Backend: report follow-ups (P1-7 / M-04b / M-04c).**
   - Route MEMBER/ACTIVITY report targets of `/api/v1/community/reports` to `communityTrustService.submitReport`.
   - Add a per-(reporter, target) de-dup and a rate limit.

   The app's 已举报 is a client lock only.
3. **Deploy setting.** `CommunityPostFeatureGate.canWrite` must be on for the production host, or every v1 write answers "feature unavailable". The app shows this as rejected.
4. **Device run.** Run 发布 "+" → 自由探索 / 城市定向 / 互动, club 发布活动 → 选择地点 (search and pin), the square like and post with images, the report, and 我的项目 → ⋯ → 编辑 on a running activity. Nothing in this lane was compiled.

No xcconfig or owner-only values were added. No secrets, deploys, SQL or `main` changes.
