# K2 Core receipt — account-publish

Base: `origin/ui/combined-r7` `7fdfad1f177fadb76f7fd54a82b27fa69b82f1f8`.
Mini-program: `liboyang42-cpu/hengyin` `8ece7763e192e13d27a765a0b8664955be6cf4ee` `chengyinhub-xcx`.
Branch: `cursor/core-account-publish` only. No PR. No `project.pbxproj`, no `tools/current_ci_manifest.json`, no new Swift folder, no new gate, no money path.
This VM has no Swift compiler. Tests were not executed and this receipt does not claim a parse.

## Closed in Core

| ID | Contract |
| --- | --- |
| A7-06 | `CropPageModel` offers 使用原图 only when the source phase is error, or a ready frame has `exportFailed`, and the session is not busy. |
| A8-10 | `POST /api/club/post/feed` JSON `{scope:"all", limit, beforeId?}`. Response requires `rows`, boolean `hasMore`, and `clubCount`. `ClubCommunityFeedCursor` continues from the last row `pagingID`. `ClubCommunityRead.feed(page:)` is still first-page only. |
| B-DR-03 | `AccountComplianceService.boundPhone` is `POST /api/user/info` form `member_id`. `sendBoundPhoneSMS` then calls `POST /api/sms/send` with that `phone` (masked numbers included on `AuthChannelService`). Empty phone sets `请先绑定手机号后再获取验证码` and does not send. A success suppresses another send for 60 seconds. Notice copy: `验证码已发送至尾号 xxxx 的手机号`. |
| B-DR-04 | `precheckAndAgree(..., recordConsent: false)` only reads `POST /api/user/deregister/precheck` and moves an eligible SMS account to verify. `apply(..., recordNoticeConsent: true)` records the cancellation AGREE and then submits. Defaults stay on the previous order so existing callers keep compiling. |
| B-SZ-05 | `SettingsClubPickerService.resolveHostRoute` still uses `POST /api/club/my`. Any owned club opens `SettingsClubHostRoute.openManage` with `manageTab == "manage"`. Empty plus `isClubLeader` is `createClub`; otherwise `applyForHost`. `SettingsClubHostRouter` drops a second tap while that read is in flight. `resolveEntry` is unchanged. `isOffered(toRole:isClubLeader:)` hides the apply rows for a leader. |
| B-SZ-09 / B-SZ-14 | `SettingsAccountProfileClient.refresh` is `POST /api/user/info` form `member_id`. HTTP or business 403 is `.denied` (`当前身份不能查看账号信息` / `点击刷新并确认当前账号权限`). 401 is signed out. 200 decodes `role`, `isClubLeader` (missing flag and `role == "club"` counts as leader), and theme `merchant` or `player`. `SessionFact.denied` maps to the existing error phase with `retriesProfileOnTap`. |
| B-MK-06 | `ComplianceMarketingConsent.merchantLogo` decodes the raw string. A missing key is `""`. |
| C-D2 | `AccountPublishGapClient.handleTeamApplication(teamID:memberID:approved:)` is `POST /api/team/handle` JSON `{teamId, memberId, approved}`. |
| C-D12 | `TeamCommandWriter.query` is `POST /api/team/command/query` with only `{requestId}`. `cancel` is `POST /api/team/command/cancel` with the saved command plus `requestId`. Neither mints an id. The saved id clears only when `data.state` is `APPLIED`, `REJECTED`, or `CANCELLED`. `submit` is unchanged and is the retry. Copy matches the detail recovery card. |
| C-S11 | `SquareContentGeneration.showsBookmark` is true only for `communityV1`. |
| C-J2 | `TeamSeatPresentation.showsBuyTicket` is true only for `TICKET_REQUIRED`. Title is `去买这一场的票`. The code was already in `knownBlockers`. |

Strings for the new copy are in `docs/port/strings/cursor-core-account-publish.json`. `Localizable.xcstrings` was not edited.

## F-agent App changes (not done here)

- `App/AccountComplianceViews.swift` verify section: remove the phone `TextField` (line 303). Call `sendBoundPhoneSMS(explicitlyRequested:now:intent:)` instead of `sendSMS(phone:)`. Show `state.smsNotice`, or `state.error` when it is `DeregistrationBoundPhone.missingMessage`.
- Same file, precheck button (line 293): pass `recordConsent: false`. Apply buttons (lines 332 and 337): pass `recordNoticeConsent: true` and the displayed consent version. Show precheck `blockers` before agree when the step is `.blocked`.
- `App/SettingsAccountEntries.swift` line 17: pass `isClubLeader` from `SettingsAccountProfile` into `isOffered`. Replace `loadSettingsClubEntry()` for this button with `SettingsClubHostRouter.resolve`. `createClub` opens club create. `openManage` opens that club on `SettingsClubHostRoute.manageTab`. Keep `App/AppSession+MemberPopups.swift` `loadSettingsClubEntry` and `App/AppSession+PopupsClose.swift` on `SettingsClubPickerOutcome`; that enum did not grow a case.
- `App/SettingsView.swift` line 69: on appear, call `SettingsAccountProfileClient.refresh` and pass `accessDenied: true` into `sessionFact` on 403. The denied row (`retriesProfileOnTap`) taps that read again. Do not paint the page from the cached session account alone.
- `App/AccountComplianceViews.swift` marketing row (line 493): show `row.merchantLogo` when it is non-empty, and keep the initial fallback when it is `""`.
- `App/ClubCommunityViews.swift` `ClubCommunityViewModel`: keep a `ClubCommunityFeedCursor`. On `.feed`, `snapshot = try cursor.accept`. `canLoadMore` when `clubID == nil && cursor.hasMore`. `loadMore` calls `.feed(limit: 20, beforeID: cursor.beforeID)`. The progress row at line 307 must also run for the cross-club feed. `App/ClubCommunityFixture.swift` feed payload needs boolean `hasMore`.
- `App/TeamHomeView.swift` lines 213–218: beside 核对上次操作结果, add 查询原请求, 按原输入重试, and 终止尚未执行的请求, plus `TeamCommandRecoveryCopy.abortNote`. Wire them to `TeamCommandWriter.query`, `submit` (retry, same key and fields), and `cancel`. `checkOutcome()` stays synthetic-only.
- `App/SquareDetailView.swift` line 262 already hides the star outside `communityV1`. Use `post.generation.showsBookmark` if that button is touched.
- Join ticket CTA: `TeamSeatPresentation.showsBuyTicket` / `buyTicketTitle`. Mounting it on the join screen stays with the F-agent. Do not add a second manual code field.
- A3-01 stays blocked on the upload-grant approval. When that grant exists, construct `ProfileAvatarDependencies` at `App/AccountView.swift` line 92, `App/MPReviewedPageScreen.swift` line 348, and the other `ProfileEditView` call sites. Do not turn the gate on in this branch.

## Skipped

- `restyle/r4-me-account`, `restyle/r2-club-social`, `restyle/r1-player-front`, `restyle/r3-merchant-creator`, `restyle/r6-system-rest`: visual. Not edited.
- `gap/g2-ops`: `teamApplications` POST `{teamId}` and the cast-voice rename / `audioUrl` decode (review F-C08). Those functions were not edited. The handle body was still `{applicationId, action}` on this base, so C-D2 was taken.
- `origin/review/r7-rev-a`: play runtime, not this area.
- `origin/review/r7-rev-b` Cursor rows B-11, B-12, B-13, B-17, B-18: settlement, IM, invoice, merchant review. Not account-publish.
- `origin/review/r7-rev-c` F-C07 and the rest of the Gemini gap rows: Gemini owns `App/` and the gap screens. Only the handle contract was Cursor's.
- `port/*` already merged. `fix/r3-account-publish-b` is the F-agent App branch.
- A3-05 phone/WeChat bind, C-F1 / C-F5 / C-F6 story blocks, C-T3, A4-01 POI detail: not Cursor Core rows. Left open.
- Club governance `POST /api/club/post/feed` with only `{limit:20}` (`ClubGovernanceContracts` / `ClubFeedReadLifecycleTests`) is a different reader and was not changed.

## Leftovers

- Screen wiring in the list above. Defaults of `precheckAndAgree` and `apply` still record consent before SMS until the F-agent passes the new flags.
- `SettingsClubHostRoute.openManage` passes the first owned `ClubRecord` because the app route needs an id. The mini-program opens `/pages/club/detail/index?owner=1&tab=manage` with no id.
- `ClubCommunityReadRuntimeTests.testPaginationAcrossPostsFeedAndCommentsPlusHistoryRefreshAndRetry` still keys the second page off `pageNum` and expects a replaced page of 2 rows. The live cursor merges by `beforeId`. That mismatch was already on this base; `hasMore` was added to the shared fixture so the feed body can decode.
- A3-01 upload grant and avatar composition.
- Ticket CTA mount, and any gap screen that still calls a manual join code, stay with Gemini / the F-agent.
