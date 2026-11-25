# cursor-cov2-club

Base `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` (`origin/ui/combined-r7`, "Integrate Cursor round 4"). Branch `cursor/cov2-club`. No pull request.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Checker: `python3 -B tools/check_mp_contract_coverage.py --mp-root <chengyinhub-xcx>`. The checker does not parse JavaScript. Owned rows are those whose MP path starts with `pages/club/`, except `pages/club/components/`. `utils/`, `app.js`, and `components/` were not taken. The checker, `docs/mp-contract-coverage.md`, `AppSession.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. No new Core type. No App screen edit.

M7 (`origin/cursor/mp-cov-m7` `26464b5ca7307433a5ef01f9ef14176127b80912`) is not in the base. This branch brings `Tests/CoreTests/ClubCoreClubContractTests.swift` and the club slice notes in `docs/mp-contract-coverage/club.md`.

## Checker totals

The generated table was not rewritten. Its header still says total 1038, matched 167, missing endpoint 130, missing test 870. A fresh run:

| | total | matched | missing endpoint | missing test |
|---|---:|---:|---:|---:|
| before | 1038 | 167 | 130 | 870 |
| after | 1038 | 175 | 130 | 862 |

Owned `pages/club/` rows, excluding `components/`: 115. After: matched 11, missing endpoint 5, missing test 104. Before, that slice was matched 7, missing endpoint 5, missing test 108.

A fresh run already records `GrowthCenterService.progress` for `subpackageMember/components/cy/profile/index.js:1395` (`req('/api/play/growth', {})` on that line). The generated table still says `GrowthCenterService.center`. This branch did not edit that row, Core, or the checker.

## Endpoints added

0. Every owned row that already had a path already had a Core symbol. The five rows with no symbol have no single path literal, so they stay missing-endpoint:

| MP file:line | shape |
|---|---|
| `pages/club/detail/index.js:1037` | `Object.assign` forwards `url` |
| `pages/club/event-ops/index.js:935` | ternary of `api/club/event-ops/series/update-future` and `series/create` |
| `pages/club/join-requests/index.js:196` | ternary of `api/club/join-request/approve` and `join-request/reject` |
| `pages/club/settlement/index.js:186` | ternary of `api/club/settlement/mine` and `api/club/settlement/summary` |
| `pages/club/topic-story/index.js:274` | ternary of `api/club/topic-node-answer` and `api/topic/host-node-answer` |

## Tests added

7 functions brought from M7 in `Tests/CoreTests/ClubCoreClubContractTests.swift`:

- `testSettlementMinePinsEmptyPost`
- `testSettlementSummaryPinsClubIdAndPersonalOnlyWhenAsked`
- `testClubMembersPinsClubIdPost`
- `testGovernanceReadsPinClubIdPost`
- `testGovernanceBanUnbanAndTransferPinPostFields`
- `testGovernanceReportAndAppealPinPostFields`
- `testCoopStatusSubscribeIsNotAnHttpContract`

84 functions added in `Tests/CoreTests/ClubPageContractPinTests.swift`.

The checker records 4 of them, because those calls pass a closed object literal:

| test | MP file:line | path | method | fields |
|---|---|---|---|---|
| `testCheckinOwnerCancelPinsIdAndSendsNothing` | `pages/club/checkin-detail/index.js:162` | `api/registration/cancel-by-owner` | `POST` | `id` |
| `testClubDetailFollowPinsMemberIdAndFollow` | `pages/club/detail/index.js:3237` | `api/user/follow/action` | `POST` | `follow_member_id`, `follow` |
| `testTopicParticipationTrendPinsOwnerTypeAndOwnerId` | `pages/club/topic-detail/index.js:1078` | `api/registration/count_by_date` | `POST` | `owner_type`, `owner_id` |
| `testPlanFallbackSharedControlPinsGetActivityId` | `pages/club/topic-detail/plan-fallback.js:30` | `api/game/session/shared/control` | `GET` | `activityId` |

The same follow POST is also recorded at `pages/square/detail/index.js:433`, `pages/square/detail/index.js:583`, `subpackageMember/components/cy/scene-member-order-detail/index.js:883`, and `utils/post-feed-actions.js:83`. Those four are the other half of the matched +8. No endpoint was added for them, and no other row in `utils/`, `app.js`, or `components/` was taken.

The other 80 functions quote the path, the method, and the keys of the object literal passed to `jsonBody(...)` or `JSON.stringify(...)`. The checker does not unwrap those calls, so the field list stays unparsed and the test column stays `MISSING`.

`pages/club/detail/index.js:801` posts `api/club/my` with `jsonBody({})`. A test that only quotes that path and `POST` would also match `pages/topic/index/index.js:1279`, which already has a pin (`StubHTTPTransport.testSettingsClubHostRouteMatchesPickClub`). That quote was not added.

24 owned rows still have no quote test. Their data is a variable, `Object.assign`, a forwarded `method`, a missing data object, or a ternary url. Report, appeal, ban, and unban are covered by the brought M7 tests. The checker still does not record them, because the field list or the method is not a literal.

## Money and coopStatus

Mine stays `POST` with `{}` (`PayoutReceiverRoute.settlementMine`). Summary stays `POST`. `pages/club/detail/index.js:3605` sends `{clubId}` and no `personal` key. `PayoutReceiverService.settlementSummary` sends `personal: true` only when the caller passes true, and `personal: false` when the caller passes false. Neither route was switched to `GET`. Members stay `POST` `{clubId}` (`ClubBadgeManagementRoute.membersPath`).

`coopStatus` appears only as `subscribe.request`. No HTTP endpoint was added.

`PayoutReceiverRoute.receiverBind` and `.receiverUnbind` stay payout routes. `ReleaseMoneyWriteSwitch.payoutEnabled`, `withdrawalEnabled`, and `refundEnabled` stay false when no test derivation is installed. The owner-cancel pin builds the `id` form and then asserts `ClubOwnerRefundService.cancel` throws `.disabled` without sending. Bind and unbind are not sent.

## Not claimed

No `swiftc` run. No parse of JavaScript. No secret and no mini-program screenshot. The generated table's headline totals were not edited.
