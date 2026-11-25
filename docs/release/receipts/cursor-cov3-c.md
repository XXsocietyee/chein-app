# cursor-cov3-c

Base `6afe54b4acee8786a9f3f3cbe8cd85d90be1e35a`. `origin/ui/combined-r7` was still that commit after fetch. Branch `cursor/cov3-c` stays on that SHA. `swiftc` was not run.

Mini-program: public `liboyang42-cpu/hengyin`, folder `chengyinhub-xcx`, commit `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

`python3 -B tools/check_mp_contract_coverage.py --mp-root <chengyinhub-xcx>`:

`# hengyin 25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`

`# total 1038 matched 779 missing_endpoint 120 missing_test 256`

## Split

Missing-endpoint rows only (Core symbol `MISSING`). Sorted by the `path:line` string. `n = 120`. `n//4 = 30`. This lane owns index `60` up to but not including `90`.

| | row |
|---|---|
| n | 120 |
| first owned row | `pages/topic/index/index.js:13` |
| last owned row | `subpackageMember/market/membership/index.js:27` |
| endpoints added | 0 |
| rows left | 30 |

The row before this lane is `pages/topic/components/cy/node-npc-form/index.js:641`. The next row is `subpackageMember/market/pass-order/index.js:13`.

## Endpoints added

0. Every owned call forwards `url`, keeps two path literals, or is the local request-id predicate in `pages/topic/utils/voice-enrollment-journal.js`. No path was added. Money stays off. `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `project.pbxproj`, and `docs/mp-contract-coverage.md` were not edited. Ceilings were not raised.

## Rows left

All 30 owned rows stay missing-endpoint. Locations are `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

| index | MP file:line | why it stays missing |
|---|---|---|
| 60 | `pages/topic/index/index.js:13` | `recordsRequest` forwards `url`, `method`, `data`, and `header` |
| 61 | `pages/topic/merchantapply/index.js:672` | ternary of `/api/registration/merchant/update` and `/api/registration/merchant/create` (`POST`, `JSON.stringify(requestData)`). Both literals are already in Core |
| 62 | `pages/topic/merchantinfo/merchantinfo.js:3368` | ternary of `/api/club/detail` and `/api/merchant/public-detail` (`POST`, `JSON.stringify({ id })`). Both literals are already in Core |
| 63 | `pages/topic/merchantinfo/merchantinfo.js:646` | ternary of `/api/topic/info-to-merchant` and `/api/topic/info-to-user` (`POST`, fields `id`, `scope`). Both literals are already in Core |
| 64 | `pages/topic/merchantinfo/merchantinfo.js:959` | forwards `url` (`POST`, `JSON.stringify(payload)`) |
| 65 | `pages/topic/pricing/index.js:227` | ternary of `/api/club/detail` and `/api/merchant/public-detail` (`POST`, `JSON.stringify({ id })`). Both literals are already in Core |
| 66 | `pages/topic/pricing/partner/index.js:205` | ternary of `/api/club/detail` and `/api/merchant/public-detail` (`POST`, `JSON.stringify({ id })`). Both literals are already in Core |
| 67 | `pages/topic/utils/voice-enrollment-journal.js:100` | local predicate `request(value.requestId)`. No url |
| 68 | `pages/topic/utils/voice-enrollment-journal.js:18` | local predicate `request(value.active)`. No url |
| 69 | `pages/topic/utils/voice-enrollment-journal.js:20` | local predicate `request(row.requestId)`. No url |
| 70 | `pages/topic/utils/voice-enrollment-journal.js:76` | local predicate `request(result.voiceRequestId)`. No url |
| 71 | `subpackageA/components/scene-member-invite-history/index.js:61` | `Object.assign({}, options, …)` forwards `options` |
| 72 | `subpackageA/pages/myproject/index.js:1130` | forwards `url` (`POST`, fields `id`, `scope`) |
| 73 | `subpackageA/pages/myproject/index.js:696` | forwards `url` and `data` (`POST`) |
| 74 | `subpackageA/pages/video-bounty/index.js:11` | `get(url, data)` forwards `url` (`GET`) |
| 75 | `subpackageA/pages/video-bounty/index.js:20` | `post(url, body)` forwards `url` (`POST`, `JSON.stringify`) |
| 76 | `subpackageJourney/utils/journey-api.js:11` | `call` forwards `url`, `method`, and `data` |
| 77 | `subpackageMember/components/cy/npc-chat/index.js:129` | ternary of `/api/ai/npc/merchant-chat` and `/api/ai/npc/chat` (`POST`, fields `requestId`, `bizId`, `message`). Both literals are already in Core |
| 78 | `subpackageMember/components/cy/profile/index.js:1300` | `req(url, { member_id })` forwards `url`. The assignment on the previous line is a ternary of `/api/user/info` and `/api/user/public-info`. Both literals are already in Core |
| 79 | `subpackageMember/components/cy/profile/index.js:734` | `Object.assign({}, options, …)` forwards `options` |
| 80 | `subpackageMember/components/cy/profile/index.js:83` | `req` forwards `url` (`POST`) |
| 81 | `subpackageMember/components/cy/scene-member-order-detail/index.js:658` | ternary of `/api/registration/cancel-refund` and `/api/registration/cancel` (`POST`, field `id`). Both literals are already in Core. No refund sender was added |
| 82 | `subpackageMember/components/cy/scene-member-order-history/index.js:425` | same cancel / cancel-refund ternary (`POST`, field `id`). Both literals are already in Core. No refund sender was added |
| 83 | `subpackageMember/components/cy/scene-route-content/index.js:260` | forwards `config.url` (`config.method \|\| 'POST'`) |
| 84 | `subpackageMember/components/cy/scene-route-content/index.js:521` | forwards `request.url` (`POST`) |
| 85 | `subpackageMember/components/scene-member-participation-detail/index.js:149` | `Object.assign({}, options, …)` forwards `options` |
| 86 | `subpackageMember/components/scene-member-participation-detail/index.js:636` | ternary of `/api/registration/cancel-refund` and `/api/registration/cancel` (`POST`, field `id`). Both literals are already in Core. No refund sender was added |
| 87 | `subpackageMember/free-explore/index.js:83` | forwards `url` and `method` |
| 88 | `subpackageMember/market/membership/index.js:17` | `request(opts)` forwards `opts` through `Object.assign` |
| 89 | `subpackageMember/market/membership/index.js:27` | `get(url, data)` forwards `url` (`GET`) |
