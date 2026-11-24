# cursor-mp-cov-account-publish

Base `aee32a61f0f69b880bc9e33811463ccc73351bbe` (`origin/ui/combined-r7`). Branch `cursor/mp-cov-account-publish`. No pull request.

Coverage source: `origin/cursor/mp-contract-coverage` `569fca24195166bfb70cba51a8e2aedff27da2a3`. Mini-program source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Slice table: `docs/mp-contract-coverage/account-publish.md`. The shared 102-row table is not copied.

`swiftc` was not run. No App screen was edited. `AccountPublishMPContract.moneyEnabled` is false. Zero pay, withdrawal, or pass writes were enabled.

## Counts

| count | value |
|---|---|
| tests added | 18 |
| request shapes | 10 |
| decode surfaces | 17 |
| money writes enabled | 0 |
| App files edited | 0 |
| pins redone from `569fca241951` | 0 |

The 10 request shapes are: `POST api/user/info` form `member_id`; `POST api/sms/send` form `phone`; `GET api/user/deregister/status`; `POST api/user/deregister/precheck` with an empty body; `POST api/user/deregister/apply` form `requestId` then `smscode`; the same apply path with `wxcode`; `POST api/user/deregister/cancel` with an empty body; `POST api/team/command` JSON `memberId`, `approved`, `targetId`, `action`, `requestId`; `POST api/club/post/feed` JSON `scope`, `limit`, optional `beforeId`; `POST api/club/post/feed` JSON `scope`, `author`, `limit`.

The 17 decode surfaces are `settingsAccess`, `settingsProfileForm`, `homeAccount`, `profileEditor`, `boundMobile`, `deregisterPhone`, `fabuOwner`, `activityOwner`, `selfProfile`, `earningsBalance`, `deregisterStatus`, `deregisterPrecheck`, `deregisterApply`, `deregisterCancel`, `teamHandleReceipt`, `discoverFeed`, and `ownClubPosts`.

These topics are `sendRequest`, `req`, or `sendUiStateRequest`. The checker that produced the 102-row table does not list them, so this branch does not change that table's missing-endpoint or missing-test totals. The 16 pins already on `569fca241951` (`testPlayExperienceGatesDefaultOff` through `testPlatformPassPayStaysUnsent`) are not on this base and were not added again.

Not taken: member coupon and pass (including `subpackageMember/market/passes/index.js:101` reading `point`), merchant ledger, play, roam, and `pages/talent/list/index.js:209` (`/api/creativesquare/list`).

## App call sites still on the old senders

Screens were not switched. These are the places that still need to call `AccountPublishMPContract`:

- `App/SettingsView.swift:18` paints `session.account` nickname and level. It does not post `api/user/info` or drop `phone` before display.
- `App/ProfileEditView.swift` and `App/PlayerJourneyReadBindings.swift:141` open the profile editor from the existing snapshot. They do not decode `profileEditor`.
- `App/MemberHomeHeader.swift:176` uses the session nickname. It does not decode `homeAccount` (role, `userType`, `isClubLeader`, greeting).
- `App/MemberHomeHeader.swift:118` shows a cached balance preview. Earnings stays a read of `api/user/info.balance` with the gate off. `App/WalletCommerceFixtureHost.swift:62` and `App/WithdrawalParityFixtureHost.swift:39` are fixtures for that read. Do not enable a pay or withdrawal write from them.
- `App/AccountComplianceViews.swift:293` calls `precheckAndAgree`. `:303` takes a typed phone and `:306` calls `sendSMS(phone:)`. The mini-program reads the bound phone from `api/user/info`, then posts `/api/sms/send` with that string. `:332` and `:337` call `apply(explicitlyConfirmed:)`. The mini-program posts form `requestId` plus exactly one of `smscode` or `wxcode`.
- `App/NearbyTeamViews.swift:397` sends `.handle(team:applicant:approved:)`, which `NearbyTeamService` posts to `/api/team/handle`. The mini-program posts `/api/team/command` with `action` `handle`.
- `App/MPGap/AccountPublish/AccountPublishGapViews.swift:212` draws approve and reject. Those buttons are not wired to the command body. `AccountPublishGapClient.handleTeamApplication` still posts `api/team/handle` and was left in place.
- `App/AppCompositionRoot.swift:624` can build a `TeamCommandWriter`. `App/ReviewedPlayerWriteLeases.swift:630` already lists `api/team/command`, `api/team/command/query`, and `api/team/command/cancel`. The writer submit body is still `[String: String]` and does not send `memberId`, `approved`, and `action`.
- `App/ClubCommunityViews.swift:259` loads `.feed(page:)` for the cross-club list, with no `beforeId` and no `author` `me`. `:307` loads another page only when `clubID` is set. The discover contract is `{"scope":"all","limit":20}` plus optional `beforeId`, and it does not require `clubCount`. Own posts are `{"scope":"all","author":"me","limit":20}`.
- `App/PassMarketViews.swift:140` reads `point` from `api/user/info`. That is the member-pass row and stays out of this slice.

`AccountPublishMPContract` was added to the existing file `Core/MPGap/AccountPublish/AccountPublishGapModels.swift`. `App/` had no type of that name. No new Core file was added, and the Xcode project was not edited.
