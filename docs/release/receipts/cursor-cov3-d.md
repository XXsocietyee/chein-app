# cursor-cov3-d

Base `6afe54b4acee8786a9f3f3cbe8cd85d90be1e35a`. Branch `cursor/cov3-d` stays on that SHA. Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

`python3 -B tools/check_mp_contract_coverage.py --mp-root` on that tree. Missing-endpoint rows only, sorted by the `path:line` string. `n = 120`. This lane owns index `3*(n//4) = 90` through `119` (30 rows, the remainder included).

- First owned row: `subpackageMember/market/pass-order/index.js:13`
- Last owned row: `utils/ui-state-request.js:4`

`app.js` and top-level `components/` do not fall in this quartile. Every top-level `utils/` row that does was taken: five got an endpoint, and the rest are listed under rows left. None were skipped.

Fresh run after this lane: `# total 1038 matched 784 missing_endpoint 115 missing_test 251`. Missing-endpoint was 120 before these five symbols. `docs/mp-contract-coverage.md` totals were not edited.

## Endpoints added

5. All on `PlayerContentMPContract`. Each is a path constant. None of them build or send a request. `moneyEnabled` stays false. `pricingGrantEnabled` stays false. `ReleaseMoneyWriteSwitch` was not edited.

| call | method | path | fields | symbol |
|---|---|---|---|---|
| `utils/checkout/selfplay-xpay-pay.js:48` | POST | `api/registration/xpay/confirm` | id | `xpayConfirmPath` |
| `utils/fe-author-sale.js:92` | GET | `api/topic/fe/sale-readiness` | topicId | `feSaleReadinessPath` |
| `utils/fe-author-sale.js:106` | POST | `api/topic/fe/publish-for-sale` | (unread, `JSON.stringify`) | `fePublishForSalePath` |
| `utils/fe-author-sale.js:120` | POST | `api/topic/chapter/self-supply` | (unread, `JSON.stringify`) | `chapterSelfSupplyPath` |
| `utils/fe-author-sale.js:133` | POST | `api/topic/chapter/self-supply/withdraw` | (unread, `JSON.stringify`) | `chapterSelfSupplyWithdrawPath` |

Pins are `Tests/CoreTests/Cov3DContractPinTests.swift`. Each quotes the path, the method, and the literal field names the checker recorded. The three `JSON.stringify` calls have no recorded field list, so those tests quote the path and the method only. The checker now names these five symbols and these five tests. No other row picked up a `Cov3DContractPinTests` pin.

`xpay/confirm` is a virtual-payment confirm. `publish-for-sale` writes ticket prices. Both constants stop at the path. `self-supply/withdraw` withdraws a self-supply offer. It is not a wallet or settlement withdrawal, and it was not added to the money switch.

## Rows left

25. Still missing-endpoint. No path was invented for them.

Forwards `url` or `opts` (the call has no path string):

- `subpackageMember/market/pass-order/index.js:13` — `sendRequest(Object.assign(..., opts, ...))`
- `subpackageMember/market/passes/index.js:19` — `get(url, data)` passes `url` through
- `subpackageP3/pages/growthcenter/index/index.js:35` — `requestGrowthData(url, ...)`
- `subpackageRoam/citystamp/index.js:29` — `req(url, data)`
- `subpackageTools/utils/features/exploration-export.js:26` — `send(url, ...)`
- `utils/features/capsule-client.js:34` — `request(url, method, data)`
- `utils/features/exploration-goals.js:63` — `request(url, method, data, readToken)`
- `utils/roam-passport-read.js:55` — `request(path, data)`
- `utils/roam-place-detail.js:9` — `read(app, url, data)`
- `utils/roam-place-media.js:52` — `url` is `manifestPath(key)`
- `utils/ui-state-request.js:4` — `sendKnown` forwards `url`. The `switch` literals are not this call.

Two path literals, so the checker keeps neither:

- `subpackageRoam/components/cy/scene-roam-stamp-album/index.js:66` — `received` or `list`
- `utils/club-post-repost.js:92` — `REPOST_URL` or `UNDO_URL`
- `utils/game-session-client.js:457` — `shared/export` or `shared/control`
- `utils/post-feed-actions.js:53` — `creativesquare/like` or `club/post/like`

`BASE` plus a suffix, not one literal (`BASE` is `'/api/orient/scoring'`):

- `subpackageMember/orient-score/index.js:91` — `BASE + '/session/' + id`
- `subpackageMember/orient-score/index.js:117` — `BASE + '/session/' + id + '/leaderboard'`
- `subpackageMember/orient-score/index.js:155` — `BASE + '/receipt'`
- `subpackageMember/orient-score/index.js:205` — `BASE + '/session/' + id + '/recovery'`
- `subpackageMember/orient-score/index.js:240` — `BASE + '/session/' + id + '/sync'`
- `subpackageMember/orient-score/index.js:313` — `BASE + path`, and `path` is chosen in the page

No single literal on the call:

- `utils/community-post-api.js:84` — `sendRequest(request)`. `request.url` is `BASE + path`, with one conditional overwrite.
- `utils/community-post-api.js:297` — `Object.assign` sets `url: BASE + path`
- `utils/roam-share-snapshot.js:22` — `sendRequest(Object.assign(..., options, ...))` forwards `options`
- `utils/theme-records.js:132` — the first argument is the literal `'/api/play/theme/state'`, and the data object contains a spread. The checker drops that literal, so the row stays missing-endpoint. `PlayThemeBackpack` and `PlayThemeRecords` already hold `api/play/theme/state`. It was not added again.

## Left as it was

`App/AppSession.swift` and `App/AppCompositionRoot.swift` were not edited. Ceilings were not raised. `Questify.xcodeproj/project.pbxproj` was not edited. `docs/mp-contract-coverage.md` was not edited. `tools/check_mp_contract_coverage.py` was not edited. No `swiftc` run. This receipt does not claim a parse.
