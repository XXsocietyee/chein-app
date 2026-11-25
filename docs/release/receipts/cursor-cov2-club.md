# cursor-cov2-club

Base `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` (`origin/ui/combined-r7`, "Integrate Cursor round 4"). Branch `cursor/cov2-club`. No pull request.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Checker: `python3 -B tools/check_mp_contract_coverage.py --mp-root <chengyinhub-xcx>`. The checker does not parse JavaScript. Owned rows are those whose MP path starts with `pages/club/`, including the eight rows under `pages/club/components/`. `utils/`, `app.js`, and other `components/` trees were not taken. The checker, `docs/mp-contract-coverage.md`, `AppSession.swift`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited. No new Core type. No App screen edit.

M7 (`origin/cursor/mp-cov-m7` `26464b5ca7307433a5ef01f9ef14176127b80912`) is not in the base. This branch brings `Tests/CoreTests/ClubCoreClubContractTests.swift` and the club slice notes in `docs/mp-contract-coverage/club.md`.

## Checker totals

The generated table was not rewritten. Its header still says total 1038, matched 167, missing endpoint 130, missing test 870. A fresh run:

| | total | matched | missing endpoint | missing test |
|---|---:|---:|---:|---:|
| before | 1038 | 167 | 130 | 870 |
| after | 1038 | 175 | 130 | 862 |

Owned `pages/club/` rows: 123. After: matched 11, missing endpoint 6, missing test 112. The 115 rows outside `pages/club/components/` are matched 11, missing endpoint 5, missing test 104. The eight component rows are matched 0, missing endpoint 1, missing test 8. Before the first pass, the 115 were matched 7, missing endpoint 5, missing test 108.

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

92 functions added in `Tests/CoreTests/ClubPageContractPinTests.swift`. Eight of them cover `pages/club/components/`.

The checker records 4 of them, because those calls pass a closed object literal:

| test | MP file:line | path | method | fields |
|---|---|---|---|---|
| `testCheckinOwnerCancelPinsIdAndSendsNothing` | `pages/club/checkin-detail/index.js:162` | `api/registration/cancel-by-owner` | `POST` | `id` |
| `testClubDetailFollowPinsMemberIdAndFollow` | `pages/club/detail/index.js:3237` | `api/user/follow/action` | `POST` | `follow_member_id`, `follow` |
| `testTopicParticipationTrendPinsOwnerTypeAndOwnerId` | `pages/club/topic-detail/index.js:1078` | `api/registration/count_by_date` | `POST` | `owner_type`, `owner_id` |
| `testPlanFallbackSharedControlPinsGetActivityId` | `pages/club/topic-detail/plan-fallback.js:30` | `api/game/session/shared/control` | `GET` | `activityId` |

The same follow POST is also recorded at `pages/square/detail/index.js:433`, `pages/square/detail/index.js:583`, `subpackageMember/components/cy/scene-member-order-detail/index.js:883`, and `utils/post-feed-actions.js:83`. Those four are the other half of the matched +8. No endpoint was added for them, and no other row in `utils/`, `app.js`, or `components/` was taken.

The other 80 functions quote the path, the method, and the keys of the object literal passed to `jsonBody(...)` or `JSON.stringify(...)`. The checker does not unwrap those calls, so the field list stays unparsed and the test column stays `MISSING`.

## `pages/club/components/`

Endpoints added for these eight rows: 0. Seven already had a Core path. The export call's url is a ternary, so no path was added.

| MP file:line | test | path | method | literal fields | what was added |
|---|---|---|---|---|---|
| `pages/club/components/cy/fe-reference-range/index.js:34` | `testPin_fe_reference_range_34` | ternary of payer and merchant plus `/export` | `GET` | `from`, `to` | quote only; stays missing-endpoint |
| `pages/club/components/cy/scene-club-edit/index.js:103` | `testPin_scene_club_edit_103` | `api/club/detail` | `POST` | `id` | quote of `ClubBadgeManagementRoute.detailPath` |
| `pages/club/components/cy/scene-club-edit/index.js:269` | `testPin_scene_club_edit_269` | `api/club/update-mine` | `POST` | `id`, `name`, `logo`, `cover`, `description`, `clubType`, `activityPrefs`, `city`, `keywords`, `style`, `operationConfigUpdated`, `prioritySignupEnabled`, `memberReservedQuota`, `joinPolicy` | quote of `RePoint03ClubUpdateAdapter.path` |
| `pages/club/components/cy/scene-club-edit/index.js:312` | `testPin_scene_club_edit_312` | `api/club/dissolve` | `POST` | `id`, `dissolveConfirmed`, `memberConsequencesConfirmed` | quote of `ClubGovernanceMutation.dissolve` |
| `pages/club/components/cy/scene-club-edit/index.js:393` | `testPin_scene_club_edit_393` | `api/coop/deposit/refund/retry` | `POST` | `inviteId` | quote of `CoopFlowFinancialContract.refundRetryPath`; `retryDepositRefund(..., allowsMoneyWrite: false)` returns false and sends nothing |
| `pages/club/components/cy/scene-club-edit/index.js:430` | `testPin_scene_club_edit_430` | `api/club/dissolution-blockers` | `POST` | `id` | quote of `ClubGovernanceRead.dissolutionBlockers` |
| `pages/club/components/cy/scene-club-edit/index.js:574` | `testPin_scene_club_edit_574` | `api/club/detail` | `POST` | `id` | quote of `ClubBadgeManagementRoute.detailPath` |
| `pages/club/components/cy/scene-club-edit/index.js:618` | `testPin_scene_club_edit_618` | `api/club/detail` | `POST` | `id` | quote of `ClubBadgeManagementRoute.detailPath` |

`scene-club-edit` line 269 passes `JSON.stringify(payload)`. Lines 103, 312, 393, 430, 574, and 618 pass `jsonBody(...)`. The checker does not unwrap either form, so those seven test cells stay `MISSING`. The export row stays `MISSING` / `MISSING`. A fresh run changed 0 cells. Global totals stay matched 175, missing endpoint 130, missing test 862.

`pages/club/detail/index.js:801` posts `api/club/my` with `jsonBody({})`. A test that only quotes that path and `POST` would also match `pages/topic/index/index.js:1279`, which already has a pin (`StubHTTPTransport.testSettingsClubHostRouteMatchesPickClub`). That quote was not added.

24 owned rows still have no quote test. Their data is a variable, `Object.assign`, a forwarded `method`, a missing data object, or a ternary url. Report, appeal, ban, and unban are covered by the brought M7 tests. The checker still does not record them, because the field list or the method is not a literal.

## Money and coopStatus

Mine stays `POST` with `{}` (`PayoutReceiverRoute.settlementMine`). Summary stays `POST`. `pages/club/detail/index.js:3605` sends `{clubId}` and no `personal` key. `PayoutReceiverService.settlementSummary` sends `personal: true` only when the caller passes true, and `personal: false` when the caller passes false. Neither route was switched to `GET`. Members stay `POST` `{clubId}` (`ClubBadgeManagementRoute.membersPath`).

`coopStatus` appears only as `subscribe.request`. No HTTP endpoint was added.

`PayoutReceiverRoute.receiverBind` and `.receiverUnbind` stay payout routes. `ReleaseMoneyWriteSwitch.payoutEnabled`, `withdrawalEnabled`, and `refundEnabled` stay false when no test derivation is installed. The owner-cancel pin builds the `id` form and then asserts `ClubOwnerRefundService.cancel` throws `.disabled` without sending. Bind and unbind are not sent.

## Not claimed

No `swiftc` run. No parse of JavaScript. No secret and no mini-program screenshot. The generated table's headline totals were not edited.
