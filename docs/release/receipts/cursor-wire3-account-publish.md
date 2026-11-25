# cursor-wire3-account-publish

Base `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` (`origin/ui/combined-r7`, message starts "Integrate Cursor round 4"). Branch `cursor/wire3-account-publish`. No pull request. Not rebased.

`swiftc` was not run. No parse is claimed. `AccountPublishMPContract.moneyEnabled` is still `false`. Zero pay, withdrawal, or pass writes were enabled. No request builder was added. `SettingsView` and `TeamHomeView` signatures were not changed. `AppSession.swift` was not edited.

Where a production allowlist would have refused the existing contract body, that allowlist now also admits the contract shape. The previous shape stays admitted for senders that did not move.

## Sites moved

- `SettingsAccountProfileClient.refresh` posts `userInfoRequest` (`POST api/user/info`, form `member_id`) and reads `settingsAccess` plus `homeAccount.isClubLeader`. Empty role stays a failure. `App/AppSession+SettingsAccountProfile.swift` still calls this client. `WalletHistoryReadRoute` also admits that form body for `api/user/info`. Multipart `member_id` stays admitted.
- `ProfileEditCoordinator.read`, when the service is `ProfileEditService`, posts `userInfoRequest` with the session account id and decodes the same `ProfileEditSnapshot`. `ProfileEditService.read(token:)` is unchanged.
- `MemberHomeHeader` `MemberIdentityCardSection.load`, when the lane is absent and the reader is `MemberHomeSessionReader`, calls `contractIdentity()`, which posts `userInfoRequest` and decodes `MemberIdentitySnapshot`. Other readers still call `reader.identity()`.
- `AccountComplianceService.status`, when no original deregistration client is installed, GETs `deregisterStatusRequest`. `AccountComplianceCompositionRoute` also admits that GET.
- `AccountComplianceService.precheck`, when no original client is installed, posts `deregisterPrecheckRequest`. The route also admits that empty form POST.
- `AccountComplianceService.boundPhone` posts `userInfoRequest` and still reads `phone` from `data`.
- `AccountComplianceService.apply`, when no original client is installed, posts `deregisterApplyRequest` (`requestId` then `smscode`). The route also admits that form. The original-client apply path is unchanged.
- `AccountComplianceService.cancel` posts `deregisterCancelRequest`. The route also admits that empty form POST.
- `AuthChannelService.sendBoundDeregistrationCode` posts `smsSendRequest` (form `phone`, no `Authorization`). `CNAccountSessionService.accepts` also admits that form. `sendSMSCode` stays multipart.
- `NearbyTeamHTTPWriteAdapter.submit` for `.handle` posts `teamHandleRequest` (`api/team/command`, string `memberId` and `targetId`, `action` `handle`, 32-hex `requestId`). The adapter's own grant check still uses the `api/team/handle` descriptor path. `ReviewedNearbyTeamWriteRoute` also admits the contract command. Apply and withdraw stay on their old JSON.
- `AccountPublishGapClient.handleTeamApplication` posts `teamHandleRequest`. `memberId` is the applicant. `targetId` is the team.
- `TeamCommandWriter.submit` for `api/team/command` when `action` is `join`, `quit`, `kick`, `disband`, or `join-mode` writes JSON in mini-program order: payload fields, then `targetId`, `action`, `requestId`. `joinMode` is a JSON number when the field is an integer. Query and cancel stay sorted-key JSON. No new contract builder was added.
- `ClubCommunityService.read` for `.feed` posts `clubPostFeedRequest` (`{"scope":"all","limit":N}` plus optional `beforeId`). `ClubCommunityReadRoute` compares the feed body to that contract. The row decode still requires `clubCount` and `hasMore`. Other operations still use sorted keys.
- `WalletCommerceFixtureHost` answers a form `api/user/info` read with the earnings payload and passes that payload through `earningsBalance`. The `--design-fixture` answer is the same payload. `WithdrawalParityFixtureHost` answers `/api/user/info` with balance `12.30` and passes it through `earningsBalance`.
- `MPParityPassMarketModel.reload` in `App/MPParityPassSession.swift`, when the session has an account id, calls `PlatformPass.points(token:memberID:)`, which posts `userInfoRequest` and reads `point`. No pass write.

## Sites still on the old sender

- `ProfileEditService.read(token:)` still posts multipart `api/user/info` with no `member_id`. Protocol callers and `ProfileEditSyntheticService` still use that method. The production coordinator does not.
- `MemberHomeService.identity(token:)` and `identityPage(token:)` still do the body-less `api/userInfo` read, then the empty multipart counters read. `MemberHomeSessionReader.identity()` and `identityPage()` still call those. The lane-absent header does not.
- `AccountComplianceService` status, precheck, and apply still use the original deregistration client when one is installed.
- `AuthChannelService.sendSMSCode` still posts multipart `phone`. The protocol default `sendBoundDeregistrationCode` still forwards to `sendSMSCode` for types that do not override it.
- `NearbyTeamRequest.action` for handle still builds sorted JSON `{teamId, memberId, approved}` on `/api/team/handle`. Synthetic `NearbyTeamService.submit` still uses that descriptor. Apply and withdraw still post those paths.
- `TeamCommandWriter.query`, `TeamCommandWriter.cancel`, and `submit` for any path other than `api/team/command` or any action other than join, quit, kick, disband, and join-mode still use sorted keys.
- `ownClubPostsRequest` has no App call site. Nothing in this slice posts `author` `me`.
- `WalletCommerceService.withdrawalBalance` still posts multipart `member_id`. No pay or withdrawal write was added.
- `PlatformPass.points(token:)` still posts `api/user/info` with no body. The pass-market reload uses it only when the session has no account id. Purchase, quote, order, and claim stay unreachable.
- `fabuOwner`, `activityOwner`, and `boundMobile` were not in the call-site list and were not wired.

`moneyEnabled` is `false`. No money write was enabled.
