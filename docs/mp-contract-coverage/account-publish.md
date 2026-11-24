# Account and publish contracts

Slice for `cursor/mp-cov-account-publish`. Base `origin/ui/combined-r7` `aee32a61f0f69b880bc9e33811463ccc73351bbe`. Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

These call sites use `sendRequest`, `req`, or `sendUiStateRequest`. The coverage checker on `origin/cursor/mp-contract-coverage` (`569fca241951`) only counts a callee named `request(`, so they are not rows in `docs/mp-contract-coverage.md`. This file is the slice. It does not repeat that table.

A POST with no header is `application/x-www-form-urlencoded;` (trailing semicolon), from `utils/transport/request-client.js`. JSON posts set `application/json` and keep object-literal key order. `AccountPublishMPContract.moneyEnabled` stays false. No pay, withdrawal, or pass request is built.

Existing senders stay as they are. `SettingsAccountProfileClient.refresh` and `AccountComplianceService` still post multipart. `AccountPublishGapClient.handleTeamApplication` and `NearbyTeamService.handle` still post JSON `{teamId, memberId, approved}` to `api/team/handle`. `ClubCommunityService` feed still requires `clubCount` and rejects `author`.

| MP file:line | method | path | fields | Core symbol | test |
|---|---|---|---|---|---|
| `pages/shezhi/shezhi.js:403` | `POST` | `api/user/info` | `member_id` | `AccountPublishMPContract.userInfoRequest` / `settingsAccess` | `testUserInfoPinsMemberIDForSettings` |
| `subpackageMember/components/cy/scene-route-content/index.js:84` and `:327` | `POST` | `api/user/info` | `member_id` | `userInfoRequest` / `settingsProfileForm` | `testUserInfoPinsMemberIDForSettingsProfileForm` |
| `pages/index/index.js:974` | `POST` | `api/user/info` | `member_id` | `userInfoRequest` / `homeAccount` | `testUserInfoPinsMemberIDForHome` |
| `pages/gerenziliao/gerenziliao.js:581` | `POST` | `api/user/info` | `member_id` | `userInfoRequest` / `profileEditor` | `testUserInfoPinsMemberIDForProfileEditor` |
| `pages/addressinfo/addressinfo.js:63` | `POST` | `api/user/info` | `member_id` | `userInfoRequest` / `boundMobile` | `testUserInfoPinsMemberIDForBoundPhone` |
| `pages/deregister/deregister-flow.js:204` | `POST` | `api/user/info` | `member_id` | `userInfoRequest` / `deregisterPhone` | `testUserInfoPinsMemberIDForDeregisterSMS` |
| `pages/deregister/deregister-flow.js:213` | `POST` | `api/sms/send` | `phone` | `smsSendRequest` | `testSMSSendPinsPhone` |
| `pages/publish/fabu/index.js:5462` | `POST` | `api/user/info` | `member_id` | `userInfoRequest` / `fabuOwner` | `testUserInfoPinsMemberIDForPublishOwner` |
| `pages/publish/activity/index.js:1300` | `POST` | `api/user/info` | `member_id` | `userInfoRequest` / `activityOwner` | `testUserInfoPinsMemberIDForPublishOwner` |
| `subpackageMember/components/cy/profile/index.js:1299` | `POST` | `api/user/info` | `member_id` | `userInfoRequest` / `selfProfile` | `testUserInfoPinsMemberIDForSelfProfile` |
| `subpackageA/components/scene-asset-earnings/index.js:112` | `POST` | `api/user/info` | `member_id` | `userInfoRequest` / `earningsBalance` | `testUserInfoEarningsBalanceStaysReadOnly` |
| `pages/deregister/deregister-flow.js:131` and `:314` | `GET` | `api/user/deregister/status` | (none) | `deregisterStatusRequest` / `deregisterStatus` | `testDeregisterStatusPinsGet` |
| `pages/deregister/deregister-flow.js:161` | `POST` | `api/user/deregister/precheck` | (none) | `deregisterPrecheckRequest` / `deregisterPrecheck` | `testDeregisterPrecheckPinsPost` |
| `pages/deregister/deregister-flow.js:277` | `POST` | `api/user/deregister/apply` | `requestId`, `smscode` | `deregisterApplyRequest` / `deregisterApply` | `testDeregisterApplyPinsRequestIDAndSMSCode` |
| `pages/deregister/deregister-flow.js:277` | `POST` | `api/user/deregister/apply` | `requestId`, `wxcode` | `deregisterApplyRequest` / `deregisterApply` | `testDeregisterApplyPinsRequestIDAndWXCode` |
| `pages/deregister/deregister-flow.js:348` | `POST` | `api/user/deregister/cancel` | (none) | `deregisterCancelRequest` / `deregisterCancel` | `testDeregisterCancelPinsPost` |
| `pages/team/detail/index.js:371` via `utils/team-event-command.js:92` | `POST` | `api/team/command` | `memberId`, `approved`, `targetId`, `action`, `requestId` | `teamHandleRequest` / `teamHandleReceipt` | `testTeamHandlePinsCommand` |
| `pages/talent/list/index.js:180` | `POST` | `api/club/post/feed` | `scope`, `limit`, `beforeId` | `clubPostFeedRequest` / `discoverFeed` | `testClubPostFeedPinsScopeLimitAndBeforeID` |
| `pages/merchant/relation/index.js:363` | `POST` | `api/club/post/feed` | `scope`, `limit`, `beforeId` | `clubPostFeedRequest` / `discoverFeed` | `testClubPostFeedPinsScopeLimitAndBeforeID` |
| `subpackageMember/components/cy/profile/index.js:2109` | `POST` | `api/club/post/feed` | `scope`, `author`, `limit` | `ownClubPostsRequest` / `ownClubPosts` | `testClubPostFeedPinsAuthorMe` |

`utils/ui-state-request.js:46` lists the same deregister, user-info, and SMS paths for its scanner. The page above is the sender.

The same `POST api/user/info` form `{member_id}` is also sent from `pages/topic/index/index.js:1617`, `pages/activity/baoming/baoming.js:357`, `pages/merchant/index/index.js:1006`, and `subpackageJourney/pages/seats/index.js:79`. Those pages decode play, merchant, or seat fields, so this slice does not add a decoder for them. `subpackageMember/market/passes/index.js:101` posts `api/user/info` with no data and reads `point`. That row is member pass and is not pinned here. `pages/talent/list/index.js:209` is `community.request` to `/api/creativesquare/list`. That is not the club post feed.

Settings stores `res.data.role` as a string and deletes `phone` before `setData`. Home calls `setUserRole(res.data)` on the object, so `isClubLeader` is true when the flag is true or `role` is `club`. Greeting comes from `utils/index/home-greeting.js`. Profile editor shown name is a trimmed non-empty `name`, otherwise `nickname`. Bound mobile is `phone || mobilePhone` and must match `^1[3-9]\d{9}$`. Deregister SMS uses a trimmed non-empty `phone` string, then posts that string as `phone`. The notice tail is `phone.slice(-4)`. Activity publish requires a safe integer id greater than 0 and a trimmed nickname. Self-profile ready uses follow, fans, topic, activity, and like. Discover feed requires boolean `hasMore` and does not require `clubCount`. Content on that feed is display-decoded once. Own posts keep `content` raw. Team handle is the command journal: JSON `{memberId, approved, targetId, action:"handle", requestId}` on `api/team/command`. At this commit the detail page does not post `/api/team/handle`. Earnings balance is a read of `api/user/info.balance`. Missing balance displays `0.00`. A negative or non-numeric balance is invalid. No second request is built.
