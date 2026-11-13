# cloud-g-club-misc: capability gaps G7 + G8 (club, events, team, tickets, auth, misc)

Base: `origin/ui/main` `ec2e42ba8`. Source list: `ui/capgraph` `docs/release/capability-graph.md` §(1) MP-ONLY.
Mini-program logic ported from hengyin `92eda912` `chengyinhub-xcx` (paths per row below).
City: `origin/ui/citygame-prod` is not merged into ui/main and does not call either city route, so both are done here.

## What was added

- `Core/PlayerGapRoutes.swift`: `PlayerGapService` (one request per call, no retry, 4xx-only refusal) plus mini-program shapers:
  `OfficialRoamActiveCard`, `OfficialSignupCommandFlow` (+ `OfficialSignupCommandDefaultsStore`), `TeamInviteQRView`, `TeamTrailModel`,
  `RegistrationJoinInfo`, `ActivityPublishPrecheck`, `ClubPostLikeState`, `CityFavoriteNode`, `CityMerchantNode`, `MediaAssetCredit`, `PlayerCode`.
- `App/PlayerGapViews.swift`: sections for each route, reading `\.playerGapService` from the environment. `SessionRootView` injects it,
  and only when the shipped China composition built the player grant. Fixtures and non-China builds leave it nil, so every section hides.
- Grants (both places, per the H8 lesson): `ReviewedProductionGateLeases.playPaths` and `ChinaReviewedRouteCapability.playerGapOwnerGrant`.
  `acceptsPlayerWrite` now also admits a bodyless GET on a `grant.play` path (previously only the friends lease admitted GETs).
- Tests: `Tests/CoreTests/PlayerGapRoutesTests.swift` (stub transport per route: method, path, body, shaping);
  `ReviewedChinaLaunchCompositionTests.testShippedChinaAdmitsPlayerGapRoutesAndKeepsMoneyAndHostClosed` (shipped China composition
  sends every gap route; money routes and the host-only routes it checks stay closed: payment-readiness, personal-receiver ×3,
  settlement/mine and settlement/withdraw, wallet withdraw, registration/pay, empty-reason, release-station, scan ticket).
- Localizable.xcstrings: 58 `playerGap.*` keys, en + zh-Hans.

## Path → native file → status

| Path | Verb | Native | Status |
|---|---|---|---|
| /api/official/active-for-roam | GET | `PlayerGapService.activeOfficialForRoam`; `OfficialRoamActiveCardView` in `RoamPassportOverviewView` | PARTIAL: card shows; tapping it does not navigate yet (no event route is passed into the passport header) |
| /api/official/signup-command | POST | `OfficialSignupCommandFlow.start/retry`; `OfficialSignupCommandSection` in `OfficialParticipationActions` (replaces the `.signup` button when the grant is present) | DONE |
| /api/official/signup-command/query | POST | `OfficialSignupCommandFlow.query` (body `{requestId}` only) | DONE |
| /api/official/signup-command/cancel | POST | `OfficialSignupCommandFlow.cancel` | DONE |
| /api/team/invite-qrcode | POST | `teamInviteQRCode` + `TeamInviteQRView.normalizeJoinCode`; `TeamInviteQRSection` in `TeamDetailView` (member/leader of a recruiting team) | DONE |
| /api/team/trail/state | GET | `TeamTrailModel.load`; `TeamTrailSection` in `PlayLeadSection` | DONE |
| /api/team/trail/consent | POST | `TeamTrailModel.consent` (unconfirmed off stays off) | DONE |
| /api/team/trail/sync | POST | `TeamTrailModel.tick/finish` (12 s, back-off to 60 s, ≤40 new points, `finished` on exit) | PARTIAL: the section does not pass the run's walked points yet (`points` defaults to `[]`), so it syncs `done` and reads teams but uploads no route; the team rail is a list, not map polylines |
| /api/registration/join_info | POST form | `joinInfo(memberID:)`; `PlayerCodeAndJoinSection` (Account → My invite code) | DONE |
| /api/registration/payment-readiness | POST | — | HIDDEN: money (pre-payment check) |
| /api/registration/scan_group_member_ticket | POST | — | HIDDEN: club leader-only ticket verification |
| /api/getwxbindphone | POST | — | NOT APPLICABLE: needs WeChat mini-program `getPhoneNumber` encrypted data; the app binds phone through `api/login/phone` |
| /api/login/code | POST | — | NOT APPLICABLE: exchanges a mini-program `wx.login` code; the app signs in with `api/login/wechat/app` |
| /api/city/nodes/favorites | GET | `favoriteCityNodes`; `CityFavoriteNodesSection` (Account → Saved spots) | DONE |
| /api/city/nodes/merchant/{} | GET | `merchantCityNode` + `toggleCityNodeFavorite` (existing granted `api/city/nodes/{}/favorite`); `MerchantCityNodeRow` in `PublicMerchantHomeView` | DONE |
| /api/activity/publish_precheck | POST form | `publishPrecheck`; `ActivityPublishPrecheckGate` wraps the activity publishing form in `PublishingModesViews` | DONE (also runs when editing; the mini-program skips it on edit) |
| /api/media/asset/attribution | GET | `assetCredit` (attribution only, ≤40 chars); `AssetCreditText` under the gallery in `MemberTemplateDetailView` | DONE |
| /api/object-card/rename | POST form | `renameObjectCard`; `ObjectCardRenameButton` in `ObjectCardDetailView` | DONE |
| /api/user/player-code | POST | `playerCode` (http(s) `data.qr` only); `PlayerCodeAndJoinSection` | DONE |
| /api/club-compensation/editions/empty-reason | POST | — | HIDDEN: club host share-edition panel |
| /api/club/event-ops/host/request | POST JSON | `requestHost`; `ClubHostRequestButton` in the registration waitlist section | DONE |
| /api/club/lead/arrive | POST form | `leadArrive` (one approved GCJ-02 fix via `RuntimeNativeLocationProvider`); `LeadMemberActionsSection` in `PlayLeadSection` for non-leaders | DONE |
| /api/club/lead/broadcast | POST form | `leadBroadcast`; `LeadMemberActionsSection` | DONE (member broadcast; leader broadcast stays on the existing `.leader` path) |
| /api/club/lead/release-station | POST | — | HIDDEN: leader-only |
| /api/club/lead/settle | POST | existing `PlayLeadAction.settle` behind `.leader` | HIDDEN: leader-only money action (whole-team settlement) |
| /api/club/lead/start | POST | existing `PlayLeadAction.start` behind `.leader` | HIDDEN: leader-only |
| /api/club/lead/unlock-chapter | POST | existing `PlayLeadAction.unlockChapter` behind `.leader` | HIDDEN: leader-only |
| /api/club/lead/unlock-chapter-receipt | GET | — | HIDDEN: leader-only |
| /api/club/personal-receiver/bind | POST | — | HIDDEN: money (payout receiver) |
| /api/club/personal-receiver/status | GET | — | HIDDEN: money |
| /api/club/personal-receiver/unbind | POST | — | HIDDEN: money |
| /api/club/post/like-state | POST JSON | `clubPostLikeState`; `ClubPostLikeStateButton` in `ClubCommunityPostDetailView` when a `like` pending record is open for that post | DONE |
| /api/club/post/pin | POST | — | HIDDEN: moderator-only (`canModerateContent`) |
| /api/club/settlement/mine | POST | — | HIDDEN: money |

## Gates run here

- `tools/generate_project.py` (2 App/Core sources + 1 Core test added to the project), `tools/check_scaffold.py` PASS, `tools/check_design_lint.py` PASS.
- `xcrun swiftc -parse` on every changed Swift file: clean.
- Core tests: see the commit message for the `swift test --filter PlayerGapRoutesTests` result.
- Not run here (integrator): the xcodebuild app build and `ReviewedChinaLaunchCompositionTests`.
