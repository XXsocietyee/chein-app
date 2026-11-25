# cursor-cov2-member

Base `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` (`origin/ui/combined-r7`, "Integrate Cursor round 4"). Branch `cursor/cov2-member`. No pull request.

Area: rows in `docs/mp-contract-coverage.md` whose MP path starts with `subpackageMember/`, excluding `components/` and `utils/`. `app.js`, top-level `components/`, top-level `utils/`, and every other prefix were not taken. Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

`docs/mp-contract-coverage.md` was not rewritten. The global totals in that file were not edited. `python3 -B tools/check_mp_contract_coverage.py` was run against the full mini-program tree and this branch's Core and Tests. Writing that output back would change four rows outside this area, because they share a path, method, and field list with a page row. Those rows were left as they are:

- `pages/publishkit/components/reward-selector/index.js:96`
- `pages/square/components/cy/post-compose/index.js:521`
- `subpackageMember/components/cy/scene-qr-coupon/index.js:143`
- `subpackageMember/components/cy/scene-qr-coupon/index.js:283`

## Area counts

| | rows | matched | missing endpoint | missing test |
|---|---:|---:|---:|---:|
| before | 51 | 5 | 15 | 46 |
| after | 51 | 13 | 11 | 38 |

Rows that already had both a Core symbol and a test were not redone: character, pass-order refund-apply, points-history, signup registration info, and signup my-teams.

## Endpoints added

Four Core paths:

- `GET api/channel/redeem/status` — `ChannelRedeemSource.statusPath`. Read of `platformCodeEnabled`. Checker records it on `market/gift/index.js:60` and `market/passes/index.js:55`.
- `POST api/marketing/product/orders/{}/pay` — `PlatformPass.productOrderPayPath`. No `data` key. `payProductOrder` throws `PlatformPassWriteRefusal.unreachable` and does not send. `PlatformPass.moneyEnabled` stays false. Checker records it on `market/pass/index.js:178`.
- `GET api/marketing/product/orders/{}` — `PlatformPass.productOrderDetailPath`. Read only. Checker records it on `market/pass/index.js:201`.
- `POST api/orient/scoring/session/{}/recovery` — `OrientSessionService.recoveryPath`. Field `kind`. Path only; the service does not send it. The page builds the URL as `BASE + '/session/' + id + '/recovery'` with `BASE = '/api/orient/scoring'`. The checker does not resolve `BASE`, so `orient-score/index.js:205` stays missing-endpoint.

Quote, order, claim, and cancel already threw and still throw. Their tests show an empty transport. No money gate was turned on.

## Tests added

40 functions in `Tests/CoreTests/MemberPageContractPinTests.swift`. Each quotes the path, the method, and the literal field names from the page.

The checker records a test on 8 rows, the ones whose call has a literal path, a literal method, and a closed field list:

- `appeal-mine/index.js:57` `GET api/orient/scoring/mine` `pageSize`
- `coupon-qr/index.js:186` `POST api/coupon/qr-token` `couponHistoryId`
- `coupon-qr/index.js:373` `POST api/coupon/status` `couponHistoryId`
- `coupon/coupon.js:164` `POST api/coupon/mypublishlist` `keyword`, `is_select`, `scope`
- `coupon/coupon.js:255` `POST api/coupon/stop` `couponId`, `scope`
- `signup/index.js:383` `POST api/verify/dyncode/issue` `registrationId`
- `signup/index.js:492` and `signup/index.js:552` `POST api/registration/list` `owner_type`, `pageNum`, `pageSize`

The other new tests still quote the path, method, and literal field names. The checker leaves those rows missing-test. On this base it does not pin a call with no `data` key, a `JSON.stringify` body, or a forwarded `data` value, and it does not resolve `BASE`. The checker was not edited.

## Still missing

Missing endpoint, 11. Six calls only forward `url` or `path`, so no path was invented:

- `free-explore/index.js:83` forwards `url`
- `market/membership/index.js:17` forwards `opts`
- `market/membership/index.js:27` forwards `url`
- `market/pass-order/index.js:13` forwards `opts`
- `market/passes/index.js:19` forwards `url`
- `orient-score/index.js:313` forwards `BASE + path`

Five orient-score calls build the URL from `BASE`. Session, leaderboard, receipt, and sync already have Core literals (`OrientScorePage.readPath`, `OrientSessionService` score/leaderboard/sync, `OrientScoreReviewWriter.receiptPath`). Recovery is the new path above. The checker still reports all five missing-endpoint.

Missing test, 38. That is the 11 above plus 27 rows whose path is known but the field list is not a closed object literal.

## Not claimed

No `swiftc` run. The tests were not executed. No parse of the mini-program was claimed. `AppSession.swift`, `project.pbxproj`, `tools/current_ci_manifest.json`, and `tools/check_mp_contract_coverage.py` were not edited.

## Rest of the prefix

The table has 155 `subpackageMember/` rows. The section above is the 51 page rows. This commit covers the other 104: `subpackageMember/components/` and `subpackageMember/utils/`. Top-level `utils/`, `app.js`, and `components/` outside the prefix were not taken. The 51 page rows were not redone. Seventeen component and utils rows already had both a Core symbol and a test and were not redone.

`docs/mp-contract-coverage.md` was still not rewritten, and its global totals were not edited.

### Additional counts

Whole prefix, before this commit and after it. The before column is the 51-page result plus the 104 component and utils rows as they stood on `3bbf2b029080`.

| | rows | matched | missing endpoint | missing test |
|---|---:|---:|---:|---:|
| before this commit | 155 | 30 | 22 | 124 |
| after | 155 | 47 | 21 | 108 |

Rows touched: 155. That is the 51 page rows, the 17 component and utils rows that already had a symbol and a test, the one pay row that gained a path, and the 86 rows that gained a pinning test.

### Endpoint added

One Core path:

- `POST api/platform-pass/orders/{}/pay` — `PlatformPass.passOrderPayPath`. Field `jsCode`. `payPassOrder` throws `PlatformPassWriteRefusal.unreachable` and does not send. The existing `MiniProgramContractPinTests.testPlatformPassPayStaysUnsent` now calls it and asserts an empty transport. Checker records the symbol on `utils/platform-pass-pay.js:76`. `PlatformPass.moneyEnabled` stays false.

The same path, and the existing marketing path `api/marketing/product/orders/{}/pay`, were added to `ReleaseMoneyWriteSwitch.kind` as `.payment`. No switch was turned on.

`POST api/registration/pay` already existed as `Adapt5HighRiskWriteSupplement.registrationPay`. `refuseRegistrationPay(id:)` throws `Adapt5PayRefusal.blocked` and does not send. No new path string.

No path was added for a call that only forwards `url`, or for a URL built from `BASE`, or for a ternary the checker cannot extract. Both arms of each ternary already have a Core literal.

### Tests added

86 functions in `Tests/CoreTests/ZzSubpackageMemberRestPinTests.swift`. The class name sorts after `MemberPageContractPinTests` and `MiniProgramContractPinTests`, so an existing recorded test name stays. Each function quotes the path when the call has one, the method, and the literal field names.

The checker records a test on 16 of those rows, the ones with a literal path, a literal method, and a closed field list:

- `coop-invite-sheet/index.js:141` and `utils/coop-publisher-access.js:16` `POST api/topic/list` `is_my`, `scope`, `pageNum`, `pageSize`
- `coop-invite-sheet/index.js:178` and `utils/coop-publisher-access.js:9` `POST api/topic/invite-chapters` `id`, `scope`
- `npc-chat/index.js:315` `GET api/ai/npc/chat/request` `requestId`, `scope`, `bizId`
- `order-center-entry/index.js:119` `POST api/order-center/detail` `outTradeNo`
- `scene-game-coupon-wallet/index.js:143` `POST api/coupon/myrecvlist` `keyword`
- `scene-member-order-detail/index.js:698` and `scene-member-order-history/index.js:462` `POST api/registration/pay` `id` (throw, empty transport)
- `scene-member-order-detail/index.js:835` `POST api/registration/explore-completion` `id`
- `scene-member-order-detail/index.js:883` `POST api/user/follow/action` `follow_member_id`, `follow`
- `scene-member-order-history/index.js:203` `POST api/registration/list` `pageNum`, `pageSize`, `owner_type`, `status`
- `scene-member-withdraw-history/index.js:86` `POST api/withdrawal/list` `pageNum`, `pageSize`
- `scene-play-activity-detail/index.js:475` `POST api/activity/cancel_preview` `id`
- `scene-roam-poi-detail/index.js:622` `POST api/comment/list` `owner_type`, `owner_id`, `pageNum`, `pageSize`
- `scene-roam-poi-detail/index.js:645` `POST api/comment/delete` `id`

The other new tests still quote the path, method, and literal field names. The checker leaves them missing-test. `req()` in `profile/index.js` always sends `POST`, and the invoice callers in `invoice/base.js` pass `method: 'POST'`, but the checker does not see a method on those calls, so it does not pin them. `JSON.stringify` of a variable, a forwarded `data` value, and a missing `data` key stay unparsed. The checker was not edited.

`confirmPassOrder` is called from the platform-pass confirm test, throws, and leaves the transport empty. `moneyEnabled` stays false.

### Still missing an endpoint

21 for the whole prefix. Eleven are the page rows listed above. Ten more are component rows. No path was invented for them:

- `npc-chat/index.js:129` chooses `'/api/ai/npc/merchant-chat'` or `'/api/ai/npc/chat'`. Both literals already exist. The checker does not extract a ternary.
- `profile/index.js:83` `req` forwards `url`.
- `profile/index.js:734` forwards `options`.
- `profile/index.js:1300` forwards `url`. The two literals are existing `'/api/user/info'` and `'/api/user/public-info'`.
- `scene-member-order-detail/index.js:658`, `scene-member-order-history/index.js:425`, and `scene-member-participation-detail/index.js:636` choose existing `'/api/registration/cancel-refund'` or `'/api/registration/cancel'`. Cancel-refund stays blocked. The tests send nothing. `moneyEnabled` stays false.
- `scene-route-content/index.js:260` forwards `config.url`.
- `scene-route-content/index.js:521` forwards `request.url`.
- `scene-member-participation-detail/index.js:149` forwards `options`.

### Still missing a test

108 for the whole prefix. That is the 38 page rows from the first section, plus 70 component and utils rows whose call has no literal path, no literal method, or no closed field list. Each of those 70 has a pinning test in `ZzSubpackageMemberRestPinTests`. The checker does not record it.

### Shared pins outside this prefix

A full rewrite of `docs/mp-contract-coverage.md` would also mark these rows, which share a path, method, and field list with a test added here. They were left as they are:

- `pages/activity/baoming/baoming.js:2111`
- `pages/club/detail/index.js:3237`
- `pages/mylike/mylike.js:619`
- `pages/play/components/scene-qr-ticket/index.js:86`
- `pages/square/detail/index.js:433`
- `pages/square/detail/index.js:493`
- `pages/square/detail/index.js:534`
- `pages/square/detail/index.js:583`
- `pages/square/detail/index.js:902`
- `pages/square/detail/index.js:1146`
- `subpackageA/components/earnings-overview/index.js:75`
- `subpackageA/pages/assetcenter/analysis/index.js:51`
- `subpackageP3/pages/growthcenter/index/index.js:317`
- `subpackageRoam/nearby/index.js:965`
- `utils/post-feed-actions.js:83`

The four rows named in the first section are unchanged.

No `swiftc` run. The new tests were not executed. No parse was claimed. `AppSession.swift`, `project.pbxproj`, `docs/mp-contract-coverage.md`, and the checker were not edited.
