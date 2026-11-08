# Gap 3/4/5 — friend / user / ugc / support / privacy / welcome-screen / us / registration / pay

Status: **READ-ONLY CLASSIFICATION (docs only).** Every row below is **deployment-pending-verification**. Nothing here states what production runs.

## 0. Basis and caveats

- iOS: `chengyin-app` branch `cloud/gap-5` = `origin/wip/wave4-loc`, plus `docs/release/backend-contract-for-ios.md` from `origin/cloud/doc-5` (Appendix A, MISSING rows for the 9 prefixes: 36 rows).
- Backend: `hengyin@4ac8c249fcad69e4f9c423702711d46deca2755a` (owner-confirmed baseline). The provided checkout was at `147754ba` and did not contain `4ac8c249`; I ran `git fetch origin` there (updates remote-tracking refs only; HEAD, working tree and branches untouched) and read the baseline from a detached worktree outside the checkout. **Nothing was pushed to hengyin.**
- Production version is **unverified** (receipt `19408d49`, deployed 2026-10-21). "Backend" below means "the baseline source", not "production".
- Backend paths are abbreviated: `api/` = `chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/`.
- Appendix A's method column is a heuristic and is **not** used here. Methods below were read from the Swift source.
- Not traced: the exact byte encoding helper for `SocialActionContracts.swift:145` (fields dictionary; `follow_member_id`, `follow`). It is consistent with the backend's request-param binding but I did not confirm form-vs-query on the wire.

## 1. What a follow does and does not cover (applies to every friend row)

Baseline `POST /api/user/follow/action` (`api/ApiUmsMemberController.java:911`, class `@RequestMapping("/api/user")` at :49):

- Params (request params, **no `@RequestBody`**, so a JSON body will not bind): `follow_member_id` (target id), `follow` (`1` follow, `0` unfollow, absent = legacy toggle; any other value -> "关注状态无效").
- Auth: logged-in app member (`getAppUserId()`); otherwise `error("请先登录")`.
- Result: `AjaxResult` with `msg` only (no receipt, no relationship object, no version). Outcomes: 关注成功 / 取消关注成功 / 不能关注自己 / 用户不存在 / 操作失败，请重试 (all `AjaxResult.error` = code 500). Idempotent per desired state (`IUmsMemberFollowService.ApplyResult`, `IUmsMemberFollowService.java:15`).
- Side effect: notifies the followed member on a new follow (`communityPostService.notifyFollow`, :935).

| Friend concept | Follow covers it? |
|---|---|
| request | **No.** Follow is unilateral and immediate. No pending state, no message (iOS requires 1..60 chars), no `request_id` receipt, no payload hash. |
| accept / reject / cancel | **No.** There is nothing pending to act on. |
| remove | **Partly.** `follow=0` removes only the caller's own edge. The other side's edge stays. No `expected_version`, no removal receipt. |
| relationship / mutual state | **Partly.** `public-info` returns `isFollow` (viewer -> target, `PublicMemberVO.java:60`) and `friendNum` = count of **mutual** follows (`PublicMemberMapper.xml` `selectPublicMemberById`). There is no per-peer "is mutual / who follows whom / version / conversationId" read. |
| block | **No.** Block exists only as IM block (`POST /api/im/block`, `api/ApiImController.java:224`, param `target_member_id`), enforced in `ImServiceImpl.startSingle` (:482). |
| notes (remark) / groups / star / progress scope | **No.** No table or endpoint found in baseline. |
| list of followed / followers / friends | **No.** Only counts (`fansNum`, `friendNum`). No list endpoint (`/api/user/list` at `ApiUmsMemberController.java:465` is a public member search, not a relationship list). |

Conclusion: a follow **must not** be presented as a friend-request system. At most the app may show "follow" and (derived) "mutual follow" as a read-only fact.

## 2. Summary counts (36 rows)

| Category | Count |
|---|---|
| ADAPTABLE | 3 |
| PARTIAL | 7 |
| MISSING | 26 |
| **Total** | **36** |

By prefix: `/api/friend/*` 24 (PARTIAL 4, MISSING 20); `/api/user/*` 2 (ADAPTABLE 1, MISSING 1); `/api/ugc/*` 2 (ADAPTABLE 1, PARTIAL 1); `/api/us/*` 3 (PARTIAL 2, MISSING 1); `/api/support/*` 1 MISSING; `/api/privacy/*` 1 MISSING; `/api/welcome-screen/*` 1 MISSING; `/api/registration/*` 1 MISSING; `/api/pay/*` 1 ADAPTABLE.

Important: all 3 ADAPTABLE rows are **not live HTTP calls** (two are deny-list audit constants, one is a display string). No live friend call can be adapted onto follow without changing product semantics.

## 3. Rows

Legend: Deploy = `dpv` = **deployment-pending-verification** (on every row). Types are the Decodable/Encodable names from Appendix A. `rest` columns give the controller `file:line`, method, consumes, params, auth, response, pagination, error codes. Controller consumes: all baseline `@PostMapping` methods without `@RequestBody` bind request params (form or query); `@RequestBody` ones (community-trust, club welcome-note) consume JSON.

### 3.1 `/api/friend/*` (iOS: JSON, `Authorization: <token>`, strict per-service request validators)

Shared iOS facts: reads are `GET` with query items, writes are `POST` with `Content-Type: application/json` body (`NativeFriendService.swift:128-133`; others use `body == nil ? "GET" : "POST"`). Each service's `Policy.accepts` rejects any request that deviates (fixed key sets, `UUID` request ids, body <= 4096). All gated by short-lived `*Approval` leases; "production composition supplies none" (`NativeFriendService.swift:7`).

| Path | iOS call site | Method / encoding | Swift types | Nearest backend | Category | Semantic note | Deploy |
|---|---|---|---|---|---|---|---|
| `/api/friend/` | `NativeFriendService.swift:127` (`"api/friend/"+suffix`, built :128) | prefix builder, not a route | Header, Payload, NativeFriendPage | none | MISSING | Not a route; family has no baseline controller (grep of non-test Java for `/api/friend` finds only `SecurityConfig`/login tests). | dpv |
| `/api/friend/list` | `NativeFriendService.swift:13`; read at `:59-67` | GET, query `cursor`,`limit`(1..100) | NativeFriendPage | none. Closest: `ApiUmsMemberController.java:465` `/api/user/list` POST params `user_type`,`keyword`, PageHelper `pageNum/pageSize`, `TableDataInfo{total,rows}`, anon-capable search | MISSING | Search of all public members, not the caller's relationships. No follow-list. | dpv |
| `/api/friend/requests` | `NativeFriendService.swift:13`; `reviewPage` :69 | GET `cursor`,`limit`,`review_cursor` | NativeFriendPage | none | MISSING | No pending requests exist; follow is immediate. | dpv |
| `/api/friend/request` | `NativeFriendService.swift:14`; `write` :98 | POST JSON `peer_id,request_id,msg[,source_*]` | NativeFriendPage, NativeFriendReceipt | `ApiUmsMemberController.java:911` follow/action POST params `follow_member_id`,`follow`; auth token; msg-only reply; errors code 500 strings (§1) | MISSING | Follow != request: no message, no pending outcome (`PENDING_REVIEW`), no receipt/payload hash, JSON body would not bind. Do **not** map. | dpv |
| `/api/friend/accept` | `NativeFriendService.swift:14` | POST JSON `+expected_version` | NativeFriendReceipt | none | MISSING | Nothing to accept. | dpv |
| `/api/friend/reject` | `NativeFriendService.swift:14` | POST JSON | NativeFriendReceipt | none | MISSING | Nothing to reject. | dpv |
| `/api/friend/cancel` | `NativeFriendService.swift:14` | POST JSON `+review_id` | NativeFriendReceipt | none | MISSING | Cancel of a pending request; unfollow (`follow=0`) is a different operation. | dpv |
| `/api/friend/receipt` | `NativeFriendService.swift:13`; `receipt` :119 | GET `peer_id,action,request_id` | NativeFriendReceipt | none | MISSING | No request-id receipt ledger for follow; retry safety is state-based only. | dpv |
| `/api/friend/relationship` | `NativeFriendService.swift:13`; `relationship` :90; also `NativeFriendRemovalService.swift:48` | GET `peer_id` | NativeFriendRelationship | `ApiUmsMemberController.java:504` `/api/user/public-info` POST param `member_id`; anon allowed (`SecurityConfig.java:159`); viewer relation only if logged in; returns `PublicMemberVO` (`isFollow`, `fansNum`, `friendNum`); unknown/disabled member -> `error(MEMBER_UNAVAILABLE)` | PARTIAL | Gives one direction (`isFollow`) only. No `version`, no `conversationID`, no peer->viewer flag. Cannot express pending/blocked/removed. | dpv |
| `/api/friend/remove` | `NativeFriendRemovalService.swift:13`; `send` :60 | POST JSON `peer_id,expected_version,request_id` | NativeFriendRelationship, NativeFriendRemovalReceipt | `ApiUmsMemberController.java:911` with `follow=0` | PARTIAL | Removes only caller's edge; no version CAS, no receipt; peer still follows caller. Not a friend removal. | dpv |
| `/api/friend/removal/receipt` | `NativeFriendRemovalService.swift:12`; :66 | GET `peer_id,expected_version,request_id` | NativeFriendRemovalReceipt | none | MISSING | No removal ledger. | dpv |
| `/api/friend/removal/settle` | `NativeFriendRemovalService.swift:14` | POST (iOS marks `canSettle=false`, "no formal settlement writer", metadata service :36) | NativeFriendRemovalReceipt | none | MISSING | Never called by iOS today; no backend. | dpv |
| `/api/friend/directory` | `NativeFriendDirectoryService.swift:11`; read :43 | GET query fields | Header, Payload, NativeFriendDirectoryPage | `ApiUmsMemberController.java:465` `/api/user/list` (see list row) | PARTIAL | Member search overlaps "directory" browse only; no friend filter, no grouping/stars, response shape (`TableDataInfo`) differs from `NativeFriendDirectoryPage`. | dpv |
| `/api/friend/directory/detail` | `NativeFriendDirectoryService.swift:11`; :63 | GET `peer_id` | NativeFriendDirectoryDetail | `ApiUmsMemberController.java:504` public-info | PARTIAL | Public profile only; no friend-specific fields (remark/group/progress). | dpv |
| `/api/friend/metadata` | `NativeFriendMetadataService.swift:15`; :57 | GET `peer_id` | NativeFriendMetadata | none | MISSING | No remark/group/star/notification/progress-scope store. | dpv |
| `/api/friend/metadata/receipt` | `NativeFriendMetadataService.swift:15`; :74 | GET `action,target_id,request_id` | NativeFriendMetadataReceipt | none | MISSING | as above | dpv |
| `/api/friend/metadata/settle` | `NativeFriendMetadataService.swift:17` | POST (settle path only declared; no writer, `canSettle=false` :36) | NativeFriendMetadata | none | MISSING | not called | dpv |
| `/api/friend/remark` | `NativeFriendMetadataContracts.swift:46`; approval `NativeFriendMetadataService.swift:18` | POST JSON | NativeFriendMetadata(+Group/Groups) | none | MISSING | Notes not stored anywhere in baseline. | dpv |
| `/api/friend/group/list` | `NativeFriendMetadataService.swift:16`; :62 | GET (no fields) | NativeFriendMetadataGroups | none | MISSING | no groups | dpv |
| `/api/friend/group/save` | `NativeFriendMetadataContracts.swift:46` | POST JSON | NativeFriendMetadataGroup | none | MISSING | no groups | dpv |
| `/api/friend/group/delete` | `NativeFriendMetadataContracts.swift:46` | POST JSON | NativeFriendMetadataGroup | none | MISSING | no groups | dpv |
| `/api/friend/progress` | `NativeFriendProgressService.swift:11`; request :55-59 | GET `peer_id,expected_friend_version` | Header, Payload | none | MISSING | Friend progress sharing; needs relationship `version` which follow lacks. | dpv |
| `/api/friend/channel-invite/` | `NativeFriendChannelInviteService.swift:11`; subroutes `picker,batch,landing,mine,notice,receipt` (GET), `command` (POST JSON) :12-13 | prefix + 7 sub-routes | NativeFriendChannelInviteCommand/Picker/Batch/Receipt | none | MISSING | Invites to channels, selected from a friend list; no list, no channel-invite store. | dpv |
| `/api/friend/team-invite/` | `NativeFriendTeamInviteService.swift:7`; subroutes `picker,landing,mine,receipt` :9 | prefix | NativeFriendTeamInvitePicker | none (team features exist elsewhere in baseline but not a friend-picker/offer API; not evaluated further) | MISSING | needs friend list | dpv |

Block / notes / groups: block has only the IM-level equivalent (see `/api/ugc/block` below); notes and groups are MISSING (rows above).

### 3.2 `/api/user/*`

| Path | iOS call site | Method / encoding | Swift types | Nearest backend | Category | Semantic note | Deploy |
|---|---|---|---|---|---|---|---|
| `/api/user/follow-list` | `ProfileFollowListService.swift:8` (path), request built :96-99 | GET query `cursor`,`kind`(`following`/`followers`),`limit=50`; `Accept: application/json`, no Content-Type | SocialValue, Payload (`ProfileFollowListPage`: `owner_id,kind,rows,has_more,next_cursor`) | none. Counts only: `fansNum` / `friendNum` in public-info (`ApiUmsMemberController.java:504`). Table `ums_member_follow` exists (`sql/base_schema_20260818.sql:5781`) | MISSING | The data exists; no read endpoint. This is the backend task most directly unblocking the "follow" product. | dpv |
| `/api/user/sms/send` | `RegionalEndpointAllowlistAudit.swift:12` (`RegionalHighRiskWriteRoute.userSMSSend`) | **not a call**: fail-closed deny-list constant | - | The real SMS route is `api/sms/send` (iOS `AuthEndpoint.smsSend`, `APIConfiguration.swift:31`) = `api/ApiLoginController.java:494` POST param `phone`, anon, rate limit inside `SmsVerificationService`, returns `AjaxResult` msg | ADAPTABLE | Rename/add the audit constant so the deny-list names the route that exists. Adding is stricter, not looser. | dpv |

### 3.3 `/api/ugc/*`, `/api/support/*`, `/api/privacy/*`, `/api/welcome-screen/*`, `/api/registration/*`, `/api/pay/*`

| Path | iOS call site | Method / encoding | Swift types | Nearest backend | Category | Semantic note | Deploy |
|---|---|---|---|---|---|---|---|
| `/api/ugc/report` | `App/PublishTopicAndCommentModerationSectionView.swift:80` (default arg), rendered :194 | **no HTTP call**: string shown in a governance board; `isReady` only checks non-empty (:68) | - | `api/ApiCommunityTrustController.java:36` `POST /api/community-trust/reports/submit`, consumes JSON `CommunityReportSubmitRequest{targetType,targetId,reasonCode,policyVersion,description,evidenceAssetIds,requestId}`, targetType in MEMBER/MERCHANT/CLUB/ACTIVITY/CONTENT/COMMENT/SAFETY_RATING, auth token (`unauthorized()` when absent), 400 on missing body; plus `GET /reports/taxonomy`:49, `/reports/mine`:54, `/reports/{id}`:66. Message-level report already used by iOS: `api/im/report` (`NativeChannelReportFlow.swift:153`, backend `ApiImController.java:264` params `message_id`,`reason`) | ADAPTABLE | Semantically equivalent to a report. Change the displayed/declared endpoint default to the real route (and keep the readiness check). | dpv |
| `/api/ugc/block` | `App/PublishTopicAndCommentModerationSectionView.swift:81`, rendered :197 | **no HTTP call** (same as above) | - | `api/ApiImController.java:224` `POST /api/im/block` params `target_member_id`, token; `/unblock`:244; business errors via `bizError` (code from `ServiceException`, 500 default); enforcement `ImServiceImpl.java:482` | PARTIAL | Blocks **direct chat only** ("对方暂不可联系"). Does not hide the blocked member's posts/comments. Do not claim Guideline 1.2 content-block coverage from this. | dpv |
| `/api/support/tickets` | `SupportTicketReadContracts.swift:103` (root; real paths `/list`,`/detail` :105); `SupportTicketReadReader.swift:66-69` | POST JSON: history `{cursor}`, detail `{ticket_no,cursor}`, timeline `{ticket_no,cursor,event_cursor}` | Int64, String, T | none. `ApiCommunityTrustController` `reports/mine` is the user's moderation reports, not support tickets | MISSING | No support-ticket domain. | dpv |
| `/api/privacy/progress` | `NativeChannelProgressService.swift:58` (GET, query `channel_id`), :63 (POST, JSON `command.wireBody()`); receipt via `api/progress/requests/{id}` :68 | GET + POST JSON | NativeChannelProgressDefinitions, NativeChannelProgressOverview, NativeChannelProgressPrivacy | none. Different domain: `api/ApiComplianceController.java:64` `/api/compliance/consents` (legal consent), :125 `/consents/latest` | MISSING | Per-channel progress-visibility privacy setting; no store. | dpv |
| `/api/welcome-screen/get` | `NativeChannelWelcome.swift:9` (path), request :65-67 | POST JSON `{guild_kind,guild_id}`, `Accept`/`Content-Type` json | Header (`NativeChannelWelcome`: `title,description,signposts,version,...`) | none for read. Only a **write** of a club welcome note: `api/ApiClubController.java:836` POST `/open-settings/welcome-note` consumes JSON `Club{id,welcomeNote}` (<=200 chars) | MISSING | No welcome-screen read, no signposts/entry channel. Note field is text-only, club-scoped. | dpv |
| `/api/registration/original-event` | `ProfileOrderEventHost.swift:8` (path), call :46; `ProfileService.swift:49-54` | POST form-style (`form(path, fields:["id": id])`), token | (audit rows) | `api/ApiRegistrationController.java:332` `POST /api/registration/info` (the sibling iOS already calls, :7 of the same file). No event/audit read | MISSING | Needs an order audit-event read model (`targetType == "ORDER"` rows). | dpv |
| `/api/pay/create` | `RegionalEndpointAllowlistAudit.swift:9` (`payCreate`) | **not a call**: deny-list constant | - | Real pay routes: `api/ApiRegistrationController.java:158` `POST /api/registration/pay`, :193 `POST /api/registration/pay/app` | ADAPTABLE | Deny-list should name the routes that exist; keep old constant too. | dpv |

### 3.4 `/api/us/*` (US Sign in with Apple; iOS uses origin `deployment.origin`, no Authorization, "No cookie/device/market/realm header")

| Path | iOS call site | Method / encoding | Swift types | Nearest backend | Category | Semantic note | Deploy |
|---|---|---|---|---|---|---|---|
| `/api/us/auth/apple/challenges` | `USAppleService.swift:92` | POST JSON `{}` (`execute` :62-76) | Int, String, Status; `USAppleChallenge` | none. CN `api/ApiLoginController.java:738` `/api/login/apple` takes `identityToken` only (no challenge/state) | MISSING | No server-issued challenge/nonce. | dpv |
| `/api/us/auth/apple/exchange` | `USAppleService.swift:104` | POST JSON `ExchangeBody{challengeId,state,identityToken}` | ExchangeBody, SafeProfile | `api/ApiLoginController.java:738` `POST /api/login/apple` param `identityToken`; anon; response `AjaxResult{token,data:LoginResponseVO}`; errors: 参数有误, Apple登录未配置, Apple 身份校验失败, 账号已被冻结/已删除 | PARTIAL | Verifies the Apple JWT (signature, iss/aud/exp) but ignores challenge/state, does not return `market:"US"` (iOS rejects otherwise, :109), consumes form params not JSON, and is the **CN** realm. | dpv |
| `/api/us/auth/session` | `USAppleService.swift:121` | **GET**, `Authorization: Bearer <token>`, no body | USAppleVerifiedCurrentAccount | `api/ApiLoginController.java:263` `POST /api/userInfo` (token) -> `AjaxResult` with account | PARTIAL | Same purpose (verify token -> account) but POST vs GET, different auth header form, and no US realm proof. | dpv |

## 4. Adaptation plan (ADAPTABLE rows only)

No ADAPTABLE row is a live request; each is a constant/string. One worker is enough per group; none requires a backend change.

### Worker A — moderation endpoint strings (`/api/ugc/report`)
- File: `App/PublishTopicAndCommentModerationSectionView.swift:80` (default `"api/ugc/report"` -> `"api/community-trust/reports/submit"`). Leave the `isReady` non-empty check (:68) untouched.
- Tests to extend: `Tests/AppUnitTests/PublishTopicAndCommentModerationSectionViewTests.swift` — update the expected default string and add an assertion that it names a route present in Appendix A with a backend match (not `**MISSING**`). Do not delete or relax the existing readiness assertions.
- Note: this fixes only the label. The actual product report flow already exists (`NativeChannelReportFlow.swift:153` -> `api/im/report`). A general content-report UI (members/posts/comments) is separate work.

### Worker B — high-risk write deny-list (`/api/user/sms/send`, `/api/pay/create`)
- File: `Core/RegionalEndpointAllowlistAudit.swift:8-13`. **Add** `smsSend = "/api/sms/send"`, `registrationPay = "/api/registration/pay"`, `registrationPayApp = "/api/registration/pay/app"` and keep `userSMSSend`/`payCreate`. Adding routes is fail-closed (stricter).
- Tests to extend: the audit's tests (find with `grep -rl RegionalHighRiskWriteRoute Tests`) — extend the `canonicalPaths`/`allCases` expectations and the "blocked in CN and US by default" assertion with the three new routes. Never remove or loosen the existing cases.
- Risk: an existing test may pin `allCases.count`; update the count in the same commit (this tightens).

### Not adaptable (do not attempt)
All `/api/friend/*` rows. Mapping `request/accept/reject/cancel/remove` onto `follow/action` would silently change meaning (see §1). Product must choose: (a) ship "follow" UI only (needs `/api/user/follow-list` backend), or (b) build real `/api/friend/*` in the backend.

## 5. Backend tasks (hengyin; for the backend owner, not done here)

1. `GET /api/user/follow-list` (`kind`, `cursor`, `limit<=50`) returning `{owner_id,kind,rows[],has_more,next_cursor}`; rows need `id,isFollow`. Data: `ums_member_follow`.
2. Per-peer relationship read (viewer->peer, peer->viewer, mutual) if the app wants to show "mutual" without the full friend API.
3. Decide product: real friend system (`/api/friend/*` 20 MISSING rows incl. request ledger with `request_id`/payload hash/version, remark, groups, progress, invites) or drop those client paths.
4. Content-level block (`/api/ugc/block` semantics: hide blocked member's posts/comments), or document that only IM block exists.
5. `/api/support/tickets/{list,detail}`, `/api/privacy/progress` (+ `/api/progress/requests/{id}`), `/api/welcome-screen/get`, `/api/registration/original-event` — new read models.
6. US Apple (`/api/us/auth/apple/*`): challenge/state/nonce, `market` field in the response, realm separation — only if the US build ships.
7. Confirm production version against `4ac8c249` before any row is promoted from `dpv`.

## 6. Password login entry points

Backend fact: `POST /api/login` (`api/ApiLoginController.java:121`, params `username,password,code`) first resolves a **mini-program WeChat `code`** via `getOpenID(code)` (:127); on failure returns `WECHAT_SERVICE_UNAVAILABLE`. The iOS client sends only `username,password` (`AuthService.swift:70`), so the call cannot succeed against this route even if enabled. (The repo's own comment: `RegionalConfiguration.swift` "The retained password route requires a mini-program WeChat code; a capability flag cannot supply it.")

### Current state (baseline `wip/wave4-loc`)
`implementedCapabilities` is `[.domesticChinaPhone]` for China (`Core/RegionalConfiguration.swift:90-92`), so `availability(of: .usernamePassword)` is `.implementationPending` and `canUsePassword` is `false` in **every** build, debug or release (it would also need `verifiedCapabilities`). So all UI entry points below are currently unreachable; the remaining risk is a future edit to `implementedCapabilities`/`verifiedCapabilities`.

### Every code path that reaches `AuthService.login`
| # | file:line | What |
|---|---|---|
| 1 | `Core/AuthService.swift:68` `login`, `:70` `execute(.password …)`, `Core/APIConfiguration.swift:28` `case password = "api/login"` | The only network call to `/api/login` |
| 2 | `App/AppSession.swift:7468` `func login(username:password:)`, `:7481` `service.login(...)` | Sole caller of `AuthService.login` (grep of `.login(username` in App/Core) |
| 3 | `App/AppSession.swift:7287` | Constructs `AuthService` only when `availability(of:.usernamePassword) == .available`, else `service = nil` (so #2 returns `auth.notConfigured` at :7470) |
| 4 | `App/AppSession.swift:1067` `canUsePassword` | Single UI/logic gate |
| 5 | `App/LoginView.swift:18` `if session.canUsePassword {` | Hides the username/password Section (`TextField` :20, `SecureField` :25, `Button` :27-35, `auth.signIn` id :37) |
| 6 | `App/LoginView.swift:24` `.onSubmit { focusedField = .password }` and `:27` `.onSubmit { submit() }` | Keyboard submit |
| 7 | `App/LoginView.swift:108-113` `submit()` | Guards `session.canUsePassword` (:109) then `session.login(...)` (:113) |
| 8 | `App/WelcomeView.swift:57,65` | Navigates to `LoginView(intent:)` (entry to #5-#7) |

Other `AuthService(` constructions (`Core/ClubOperationsService.swift:17`, `Core/ClubGovernanceService.swift:84`, `Core/CNAccountSessionService.swift:20`, `Core/AuthChannelService.swift:54`, `Core/WeChatAppAuth.swift:74`) only use `currentAccount`/phone/WeChat routes, not `.password`. No other `.password` AuthEndpoint use was found. NOT FOUND: any other UI path (deep link, URL scheme, UI-test launch argument) that supplies a password.

### Minimal change to hide/disable in a release build, keeping tests
Tests run in Debug, so compile-time `#if !DEBUG` hardening does not affect them.
1. `App/AppSession.swift:1067`: `var canUsePassword: Bool { #if DEBUG storageScope != nil && regionalConfiguration?.availability(of:.usernamePassword) == .available #else false #endif }`.
2. `App/AppSession.swift:7287`: in release force `service = nil` (same `#if`), so `AuthService` is never created for password.
3. `App/AppSession.swift:7468` `login(...)`: add at the top `#if !DEBUG errorKey = "auth.notConfigured"; return #endif` (defence in depth if a caller bypasses the UI).
4. `App/LoginView.swift:18-37` needs no change (it follows `canUsePassword`). Optionally wrap the Section in `#if DEBUG` to strip the strings from release binaries.
5. Keep `Core/AuthService.swift:68` and its tests (`Tests/CoreTests/AuthFoundationTests.swift:61,70,81`) untouched; they call the service directly.
6. Tests to keep green / extend (do not loosen): `Tests/CoreTests/RegionalConfigurationTests.swift:84-85`, `Tests/AppUnitTests/AppCompositionRootTests.swift:168-178` (`canUsePassword == false`, no requests recorded), `Tests/AppUITests/EntryFlowTests.swift:19,70` (`auth.signIn` absent), `Tests/ContractChecks/test_cn_native_login_contract.py:22,39`. Add a contract check asserting the three `#if` markers above exist and that `AuthEndpoint.password` stays out of the allowed-routes list in `App/AppCompositionRoot.swift` (already asserted at `test_cn_native_login_contract.py:14` as `assertNotIn('[AuthEndpoint.password,', root)`).
