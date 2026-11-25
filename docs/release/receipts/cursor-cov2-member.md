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
