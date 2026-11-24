# cursor-wire2-account-publish

Base `b0ac0108d0a5a9739ababecbbc61284cae5a8043` (`origin/ui/combined-r7`, message starts "Integrate F-agent round 2"). Branch `cursor/wire2-account-publish`. No pull request. Not rebased.

`swiftc` was not run. No parse is claimed. `AccountPublishMPContract.moneyEnabled` is still `false`. Zero pay, withdrawal, or pass writes were enabled. The 18 `AccountPublishMPContractTests` and the 10 request builders were not edited.

`SessionRootView` installs `AccountPublishContractLane` on the production session. Design fixtures that replace that root do not install it, and those screens keep the old sender.

## Sites moved

- `App/SettingsView.swift` `refreshAccountProfile` posts `AccountPublishMPContract.userInfoRequest` (`POST api/user/info`, form `member_id`). The card nickname comes from `settingsProfileForm`. `settingsAccess` drops `phone` from `viewKeys`, and this page does not display a phone. `isClubLeader` comes from `homeAccount` on the same body. The level number is still `session.account.level`, and only after that read succeeds. The struct signature is unchanged.
- `App/ProfileEditView.swift` `ProfileEditModel.load` still loads the save snapshot, then decodes `profileEditor`. The name row shows `shownName`. An empty draft introduction shows the editor introduction. A non-empty `phoneMasked` replaces the old phone row.
- `App/PlayerJourneyReadBindings.swift` `PlayerJourneySeatsModel.editMe` prefetches `profileEditor` before opening `pages/gerenziliao/gerenziliao`.
- `App/MemberHomeHeader.swift` `MemberIdentityCardSection.load`, when the lane is installed, posts `userInfoRequest` and decodes `homeAccount` (nickname, greeting, role, `userType`, `isClubLeader`) and `earningsBalance`. The balance line uses that read-only display (missing balance shows `0.00`). It does not call `reader.identity()` on that path, and it does not start a pay or withdrawal. When the lane is absent, `reader.identity()` remains.
- `App/AccountComplianceViews.swift` precheck button posts `deregisterPrecheckRequest` (empty POST). The SMS button posts `userInfoRequest`, reads `deregisterPhone`, then `smsSendRequest` (form `phone`). Both apply buttons post `deregisterApplyRequest` with `requestId` and `smscode`. The cancel confirm posts `deregisterCancelRequest` (empty POST). This screen collects an SMS code, so it does not send `wxcode`. When the lane is absent, those buttons still call the coordinator. Cancellation AGREE, when `recordNoticeConsent` is true, still goes through `AccountComplianceService.consent` before the contract apply. That consent call is not one of the 10 shapes.
- `App/NearbyTeamViews.swift` `NearbyTeamScreenModel.confirmReviewed` posts `teamHandleRequest` for `.handle` when the lane is installed (`memberId` is the applicant id, `targetId` is the team id, `approved` is a JSON bool, `action` is `handle`, `requestId` is 32 hex). Other actions still call `coordinator.confirm`. When the lane is absent, handle still calls `coordinator.confirm`.
- `App/MPGap/AccountPublish/AccountPublishGapViews.swift` `TeamDetailGapApplicantsSection` approve and reject post `teamHandleRequest` (`memberId` is `TeamApplicantItem.userID`, `targetId` is `teamID`). They do not call `AccountPublishGapClient.handleTeamApplication`. `teamID` defaults to `0` so existing initializers still compile; `0` fails the contract id check and does not post.
- `App/TeamHomeView.swift` `teamRecoveryButtons` retry, only the call: when `fields["action"]` is `handle` and the lane is installed, it posts `teamHandleRequest` (`memberId`, `approved`, `targetId`). The struct signature is unchanged. Join, quit, kick, disband, and join-mode still call `TeamCommandWriter.submit`. The recovery card built by `TeamScreenModel.recoveryCommand` does not store a handle command today.
- `App/ClubCommunityViews.swift` `ClubCommunityViewModel.load` for `.feed` calls `ClubCommunityService.readDiscoverFeed`, which posts `clubPostFeedRequest` (`{"scope":"all","limit":N}` plus optional `beforeId`) and decodes `discoverFeed`. `clubCount` is not required. Paging still uses `beforeId` from `loadMoreFeed`. This path does not send `author` `me`. `read()` is unchanged for every other operation.

## Sites still on the old sender

- `SettingsAccountProfileClient.refresh` still posts multipart `member_id`. `SettingsView` no longer calls it.
- `ProfileEditService.read` (via `ProfileEditCoordinator.load`) still posts multipart `api/user/info` with no `member_id`. That read remains the save snapshot. `profileEditor` does not replace it.
- `MemberHomeService.identity` (body-less `api/userInfo`, then multipart counters) still runs when the lane is absent, and for every other `reader.identity()` caller.
- `AccountComplianceViews.loadCancellation` still calls `AccountComplianceCoordinator.load`, which GETs deregister status through `AccountComplianceService`. The production action buttons above do not use that GET.
- `AccountComplianceService` precheck, bound-phone multipart `api/user/info`, multipart apply (`smscode` + `requestId`), and empty multipart cancel stay in place. `AccountComplianceCoordinator.sendBoundPhoneSMS` still calls `auth.sendBoundDeregistrationCode`. Those run when the lane is absent, and for any caller other than the buttons listed above.
- `NearbyTeamService` still posts `/api/team/handle` for apply, withdraw, and for handle when the lane is absent.
- `AccountPublishGapClient.handleTeamApplication` still posts `api/team/handle`. The gap buttons do not call it.
- `TeamCommandWriter.submit` still JSON-encodes `[String: String]` with sorted keys. `App/AppCompositionRoot.swift` still builds that writer. `App/ReviewedPlayerWriteLeases.swift` still only lists `api/team/command`, `api/team/command/query`, and `api/team/command/cancel`.
- `ClubCommunityService.read(.feed)` still requires `clubCount` and still builds the old field dictionary. Callers of `read(.feed)` were not switched. The feed view no longer uses `read` for `.feed`.
- `ownClubPostsRequest` (`{"scope":"all","author":"me","limit":20}`) has no App call site. Nothing in this slice posts it.
- `App/WalletCommerceFixtureHost.swift` and `App/WithdrawalParityFixtureHost.swift` are still the earnings read fixtures. No pay or withdrawal write was added. `WalletCommerceService.withdrawalBalance` was not changed.
- `App/PassMarketViews.swift` point read of `api/user/info` stays out of this slice.
- `fabuOwner`, `activityOwner`, and `boundMobile` were not in the call-site list and were not wired.

`moneyEnabled` is `false`. No money write was enabled.
