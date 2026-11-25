# MP contract coverage — `api/club`

The global table is `docs/mp-contract-coverage.md`. Its totals count every row the checker emits. This file is the club slice. It does not replace that table.

The M7 delta is below. The section "Historical slice" is the older `request(`-only table at `569fca24195166bfb70cba51a8e2aedff27da2a3`.

## Delta (`cursor/mp-cov-m7`)

Base `d49a476598092f2d6e163137453c372d5be08b24`. Mini-program `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Checker `python3 -B tools/check_mp_contract_coverage.py`. Receipt `docs/release/receipts/cursor-mp-cov-m7.md`.

Rows taken are the ones the expanded checker sees for settlement mine, settlement summary, members, and governance, plus the `coopStatus` call sites. No new Core path literal was added. The symbols already on this base stay the symbols in the global table.

| MP file:line | extracted path | method the checker kept | body the page sends | Core symbol already on the base |
|---|---|---|---|---|
| `pages/club/payout-receiver/index.js:62` | `api/club/settlement/mine` | `POST` | `jsonBody({})` | `PayoutReceiverRoute.settlementMine` |
| `pages/club/settlement/index.js:186` | none (ternary of mine and summary) | `POST` | `jsonBody({ clubId, personal })` | `MISSING` |
| `pages/club/detail/index.js:3605` | `api/club/settlement/summary` | `POST` | `jsonBody({ clubId })` | `PayoutReceiverRoute.settlementSummary` |
| `pages/coop/settlement-detail/index.js:232` | none (ternary of summary, finance, and mybiz) | `POST` | `{ clubId }` or `{ clubId, personal: true }` | `MISSING` |
| `pages/club/badges/index.js:355` | `api/club/members` | `POST` | `jsonBody({ clubId })` | `ClubBadgeManagementRoute.membersPath` |
| `pages/club/detail/index.js:2348` | `api/club/members` | `POST` | `jsonBody({ clubId })` | `ClubBadgeManagementRoute.membersPath` |
| `pages/club/event-ops/index.js:612` | `api/club/members` | `POST` | `jsonBody({ clubId })` | `ClubBadgeManagementRoute.membersPath` |
| `pages/club/governance/index.js:340` | `api/club/members` | `POST` | `jsonBody({ clubId })` | `ClubBadgeManagementRoute.membersPath` |
| `pages/club/roles/index.js:299` | `api/club/members` | `POST` | `jsonBody({ clubId })` | `ClubBadgeManagementRoute.membersPath` |
| `pages/topic/merchantinfo/host-layers.js:208` | `api/club/members` | `POST` | `JSON.stringify({ clubId })` | `ClubBadgeManagementRoute.membersPath` |
| `pages/club/governance/index.js:250` | `api/club/access/me` | `POST` | `jsonBody({ clubId })` | `ClubAccessMeContractAuditInput.expectedPath` |
| `pages/club/governance/index.js:300` | `api/club/governance/cases/mine` | `POST` | `jsonBody({ clubId })` | `ClubGovernanceRead` |
| `pages/club/governance/index.js:374` | `api/club/governance/list` | `POST` | `jsonBody({ clubId })` | `ClubGovernanceRead` |
| `pages/club/governance/index.js:480` | `api/club/governance/ban` | `POST` | `jsonBody(payload)` | `ClubGovernanceMutation` |
| `pages/club/governance/index.js:536` | `api/club/governance/unban` | `POST` | `jsonBody(payload)` | `ClubGovernanceMutation` |
| `pages/club/governance/index.js:592` | `api/club/governance/owner/transfer` | `POST` | `jsonBody({ clubId, targetMemberId, reason, requestId })` | `ClubGovernanceMutation` |
| `pages/club/governance/index.js:700` | `api/club/governance/cases/report` | none (`requestOptions.method`) | `requestOptions.data` | `ClubGovernanceMutation` |
| `pages/club/governance/index.js:711` | `api/club/governance/cases/appeal` | none (`requestOptions.method`) | `requestOptions.data` | `ClubGovernanceMutation` |

`pages/club/settlement/index.js:186` and `pages/coop/settlement-detail/index.js:232` stay missing-endpoint. The url is a ternary, so the checker extracts no path. No endpoint was invented for either call.

`personal` on the payout summary is the boolean the caller passes. `PayoutReceiverService.settlementSummary` sends `personal: true` when that caller passes true, which is the mini-program `personal=1` case, and `personal: false` when the caller passes false. `ClubGovernanceRead.settlement` stays `POST` with `{clubId}` and no `personal` key. That is the settings-count body at `pages/club/detail/index.js:3605`. Mine stays `POST` with `{}`, which is what `pages/club/payout-receiver/index.js` sends. Neither route was switched to `GET`.

`coopStatus` appears only as a subscribe-message key:

| call | form |
|---|---|
| `pages/club/detail/index.js:3821` | `require("../../../utils/subscribe.js").request(['coopStatus'])` |
| `pages/coop/invite/index.js:760` | `subscribe.request(['coopStatus'])` |
| `subpackageMember/components/cy/coop-invite-sheet/index.js:215` | `subscribe.request(['coopStatus'])` |

The checker drops `subscribe.request([...])` and `require("...subscribe.js").request([...])`. Those three calls are not rows. No `coopStatus` HTTP path was added.

The data argument on every extracted row above is `jsonBody(...)`, `JSON.stringify(...)`, or a forwarded `data` value. The checker leaves those fields unparsed, and an unparsed row is not a recorded pin. Report and appeal also forward `method`, so the checker keeps no method. Re-running the checker after the pinning tests left every global-table cell and both totals unchanged.

Pinning tests in `Tests/CoreTests/ClubCoreClubContractTests.swift` name the existing contracts:

| test | shape |
|---|---|
| `testSettlementMinePinsEmptyPost` | `POST api/club/settlement/mine` body `{}` |
| `testSettlementSummaryPinsClubIdAndPersonalOnlyWhenAsked` | payout `POST` `{clubId, personal}`; governance read `{clubId}` |
| `testClubMembersPinsClubIdPost` | `POST api/club/members` `{clubId}` |
| `testGovernanceReadsPinClubIdPost` | access, cases/mine, and list, each `POST` `{clubId}` |
| `testGovernanceBanUnbanAndTransferPinPostFields` | ban, unban, and owner transfer field sets |
| `testGovernanceReportAndAppealPinPostFields` | report (including `evidence: {}`) and appeal |
| `testCoopStatusSubscribeIsNotAnHttpContract` | no read, mutation, or payout route contains `coopStatus` |

`ReleaseMoneyWriteSwitch.payoutEnabled`, `withdrawalEnabled`, and `refundEnabled` stay false when no test derivation is installed. `/api/club/settlement/withdraw` stays refused on the China production host. Settlement mine and summary are not payout routes. No App screen was edited.

## Delta (`cursor/cov2-club`)

Base `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24`. Owned rows are `pages/club/`, including the eight rows under `pages/club/components/`. `utils/`, `app.js`, and other `components/` trees were not taken. The checker and `docs/mp-contract-coverage.md` were not edited.

M7 tests and the M7 section above are on this branch. They do not change a checker cell: those bodies are `jsonBody(...)`, `JSON.stringify(...)`, or a forwarded `data` value, so the field list stays unparsed.

Endpoints added: 0. The five owned rows with no Core symbol have no single path literal.

| MP file:line | why it stays missing-endpoint |
|---|---|
| `pages/club/detail/index.js:1037` | `Object.assign` forwards `url` |
| `pages/club/event-ops/index.js:935` | ternary `series/update-future` / `series/create` |
| `pages/club/join-requests/index.js:196` | ternary `join-request/approve` / `join-request/reject` |
| `pages/club/settlement/index.js:186` | ternary `settlement/mine` / `settlement/summary` |
| `pages/club/topic-story/index.js:274` | ternary `topic-node-answer` / `host-node-answer` |

Mine stays `POST` `{}`. Summary stays `POST`. The detail settings read sends `{clubId}` and no `personal` key. `personal: true` is sent only when `PayoutReceiverService.settlementSummary` is called with `personal: true`. Members stay `POST` `{clubId}`. `coopStatus` is only `subscribe.request`. Bind and unbind stay payout routes and send nothing while `payoutEnabled` is false. Refund and withdrawal stay off.

`ClubPageContractPinTests` quotes each owned call whose data argument is `jsonBody` or `JSON.stringify` of one object literal. The checker still does not record those rows. Four calls already had a closed object, and the checker records those tests:

| MP file:line | path | method | fields |
|---|---|---|---|
| `pages/club/checkin-detail/index.js:162` | `api/registration/cancel-by-owner` | `POST` | `id` |
| `pages/club/detail/index.js:3237` | `api/user/follow/action` | `POST` | `follow_member_id`, `follow` |
| `pages/club/topic-detail/index.js:1078` | `api/registration/count_by_date` | `POST` | `owner_type`, `owner_id` |
| `pages/club/topic-detail/plan-fallback.js:30` | `api/game/session/shared/control` | `GET` | `activityId` |

The follow test is also recorded for the same POST at `pages/square/detail/index.js:433`, `pages/square/detail/index.js:583`, `subpackageMember/components/cy/scene-member-order-detail/index.js:883`, and `utils/post-feed-actions.js:83`. No endpoint was added for those files.

`pages/club/detail/index.js:801` posts `api/club/my` with `jsonBody({})`. A test that only quotes that path and `POST` would also match `pages/topic/index/index.js:1279`, which already has a pin, so that quote was not added.

The eight `pages/club/components/` rows each have a pinning test in `ClubPageContractPinTests`. Endpoints added for them: 0. `fe-reference-range/index.js:34` is a ternary url (`payer` or `merchant`, then `/export`), method `GET`, query keys `from` and `to`, so no path was added. The other seven already had a Core path: `api/club/detail` (`POST`, field `id`) at scene-club-edit lines 103, 574, and 618; `api/club/update-mine` (`POST`, payload keys `id`, `name`, `logo`, `cover`, `description`, `clubType`, `activityPrefs`, `city`, `keywords`, `style`, plus owner keys `operationConfigUpdated`, `prioritySignupEnabled`, `memberReservedQuota`, `joinPolicy`) at line 269; `api/club/dissolve` (`POST`, `id`, `dissolveConfirmed`, `memberConsequencesConfirmed`) at line 312; `api/coop/deposit/refund/retry` (`POST`, `inviteId`) at line 393, which stays off and sends nothing; `api/club/dissolution-blockers` (`POST`, `id`) at line 430. Those bodies are `jsonBody(...)` or `JSON.stringify(payload)`, so the checker still does not record the tests.

Owned re-run: 123 `pages/club/` rows, matched 11, missing endpoint 6, missing test 112. The eight component rows: matched 0, missing endpoint 1, missing test 8. Global re-run: total 1038, matched 175, missing endpoint 130, missing test 862. The generated table was left as it is. Zero cells moved when the eight tests were added.

## Historical slice

Slice of the table on `origin/cursor/mp-contract-coverage` at `569fca24195166bfb70cba51a8e2aedff27da2a3` (`docs/mp-contract-coverage.md` at that commit, receipt `docs/release/receipts/cursor-mp-contract-coverage.md`).

Mini-program source: public `liboyang42-cpu/hengyin`, folder `chengyinhub-xcx`, commit `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

A row is a callee named `request(`, including `receiver.request(`. `function request(` and a method shorthand `request(...) {` are definitions, not rows. `sendRequest(` and `req(` are different callees and are not rows. The checker is `tools/check_mp_contract_coverage.py` from that commit. It keeps a path only when the call's literal arguments resolve to an `/api` URL.

This file keeps rows whose extracted path is `api/club` or begins with `api/club/`. Merchant ledger, play, and roam rows stay on the coverage receipt.

## Counts

| count | value |
|---|---|
| table rows (`569fca241951`) | 102 |
| table matched | 19 |
| table missing endpoint | 42 |
| table missing test | 82 |
| in-scope paths (`api/club` or `api/club/…`) | 0 |
| in-scope missing rows | 0 |
| Core endpoints added | 0 |
| pinning tests added | 0 |

Re-scan of that checker against `chengyinhub-xcx` at `25eb6a0c` and this branch's `Core/` plus `Tests/CoreTests/` also returns 102 rows. Extracted paths equal to `api/club`, prefixed with `api/club/`, or containing `club`: 0. Symbol and test totals on this branch differ from the table because the play, roam, and pass pins live only on `cursor/mp-contract-coverage`. Those rows were not taken here. This re-scan: matched 2, missing endpoint 42, missing test 100.

Path prefixes on the re-scan: `-` 37, `api/merchant` 10, `api/play` 10, `api/circle-theme` 9, `api/creativesquare` 7, `api/platform-pass` 5, `api/capsules` 5, `api/exploration-goals` 5, `api/roam` 5, `api/comment` 4, `api/compliance` 2, `api/user` 2, `api/im` 1.

## In-scope rows

None.

## Club page call that is not this path

| MP file:line | callee | extracted path | why it stays out |
|---|---|---|---|
| `pages/club/detail/index.js:3821` | `subscribe.request(['coopStatus'])` | unknown | Subscription-message request. The coverage receipt already left it missing. The path is not `api/club`. |

## Money

No in-scope money row, so no money contract and no money pinning test were added. `ReleaseMoneyWriteSwitch.payoutEnabled` stays the release constant `false` (`Core/ChinaReviewedRouteCapability.swift`). `PayoutReceiverRoute.isPayout` is only personal-receiver bind and unbind. `PayoutReceiverTransport` still throws `APIError.notConfigured` for those two while the switch is off.

The production settlement caller stays POST.

- `PayoutReceiverRoute.settlementMine` (`api/club/settlement/mine`) and `.settlementSummary` (`api/club/settlement/summary`) use the route default method `POST` (`Core/PayoutReceiverClient.swift`). `PayoutReceiverService.settlementClubs` and `settlementSummary` send those routes.
- `CoopFlowRead.clubSettlementSummary` is absent from `usesGet`. `CoopFlowService.makeRequest` builds the URL with `AuthRequestBuilder.makeFormRequest`, which sets `httpMethod` to `POST` (`Core/AuthRequestBuilder.swift`). The GET override does not apply.

The mini-program settlement page sends the same two URLs with `method: 'POST'` through `app.sendRequest` (`pages/club/settlement/index.js:186`). That callee is not a coverage row, so it was not turned into a new Core endpoint. The existing POST caller was left in place.

## App call sites

No new Core type and no App screen edit. Existing settlement call sites, left as they are:

| call site | Core method | method |
|---|---|---|
| `App/ClubPayoutReceiverView.swift:143` | `PayoutReceiverService.settlementClubs` | POST |
| `App/ClubPayoutReceiverView.swift:222` | `PayoutReceiverService.settlementClubs` | POST |
| `App/ClubPayoutReceiverView.swift:319` | `PayoutReceiverService.settlementSummary` | POST |
| `App/CooperationFlowFixtures.swift:34` | fixture arm for `CoopFlowRead.clubSettlementSummary` | POST when the service sends it |

`CoopFlowService.read(.clubSettlementSummary)` has no other App screen caller on this branch.
