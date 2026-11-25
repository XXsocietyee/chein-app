# cursor-cov2-player-content-b

Base `0e1cf578a0e710803d49e6bc1151a53b4a8dfe24` (`origin/ui/combined-r7`, message starts "Integrate Cursor round 4"). Branch `cursor/cov2-player-content-b`. No pull request.

Mini-program: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`. Row source: `docs/mp-contract-coverage.md`. The global totals in that file were not edited.

## Split

Player-content rows are those whose mini-program path starts with `pages/topic/`, `pages/activity/`, `pages/square/`, `pages/search2/`, `pages/searchmap/`, `pages/template/`, `pages/templatedetail/`, `pages/mylike/`, `pages/index/`, `subpackageA/`, `subpackageB/`, or `subpackageP3/`. `utils/`, `app.js`, and `components/` are outside this set.

257 rows. Sorted by the full file path, then source line. That is the order already in `docs/mp-contract-coverage.md`. Lane A owns the first 129 (the odd row stays with A). Lane B owns the last 128.

- Lane A ends at `pages/topic/merchantinfo/merchantinfo.js:1015`.
- Lane B starts at `pages/topic/merchantinfo/merchantinfo.js:1056`.
- Lane B ends at `subpackageP3/pages/stamp-camera/index/index.js:389`.

## Counts for this half

| | before | after |
|---|---:|---:|
| rows | 128 | 128 |
| matched | 23 | 69 |
| missing endpoint | 14 | 13 |
| missing test | 105 | 59 |

Rows that already had a Core symbol and a test (23) were not redone.

A fresh run of `tools/check_mp_contract_coverage.py` prints `# total 1038 matched 219 missing_endpoint 129 missing_test 818`. That is the tool's print. The published totals line in `docs/mp-contract-coverage.md` was left as generated.

## Endpoint added

One. `PlayerContentMPContract.auditTaskDetailPath(auditTaskID:)` returns `api/audit/\(auditTaskID)/detail`. That is the shape of `GET /api/audit/${auditTaskId}/detail` at `subpackageB/pages/im/chat/index.js:1160`. The call has no data object, so the checker still records the test as missing.

The other 13 missing-endpoint calls do not keep one literal `/api` path. No path was invented for them.

## Tests added

46 functions in `Tests/CoreTests/PlayerContentBContractPinTests.swift`. Each quotes the path, the method, and the literal field names the checker recorded.

| call | method | path | fields |
|---|---|---|---|
| `pages/topic/merchantinfo/merchantinfo.js:1056` | POST | `api/merchant/chapter-node/mine` | topicId |
| `pages/topic/merchantinfo/merchantinfo.js:1094` | POST | `api/registration/merchant/select` | id |
| `pages/topic/merchantinfo/merchantinfo.js:2040` | POST | `api/registration/merchant/info` | id |
| `pages/topic/merchantinfo/merchantinfo.js:2243` | POST | `api/merchant/chapter-node/pending` | topicId, scope |
| `pages/topic/merchantinfo/merchantinfo.js:2339` | POST | `api/merchant/chapter-node/audit` | nodeId, approve, reason, scope |
| `pages/topic/merchantinfo/merchantinfo.js:2450` | POST | `api/merchant/upcoming-runs` | topicId |
| `pages/topic/merchantinfo/merchantinfo.js:3928` | POST | `api/topic/info-to-merchant` | id, scope |
| `pages/topic/merchantinfo/merchantinfo.js:3961` | POST | `api/topic/info-to-user` | id, scope |
| `pages/topic/merchantinfo/merchantinfo.js:4169` | POST | `api/topic/chapter/recruit` | chapterId, enabled, scope |
| `pages/topic/merchantinfo/merchantinfo.js:4201` | POST | `api/topic/publish-draft` | id, scope |
| `pages/topic/merchantinfo/merchantinfo.js:4310` | POST | `api/topic/chapter/finish` | chapterId, scope |
| `pages/topic/merchantinfo/merchantinfo.js:4449` | POST | `api/topic/info-to-user` | id, scope |
| `pages/topic/merchantinfo/merchantinfo.js:4639` | POST | `api/merchant/chapter-node/poster-code` | nodeId |
| `pages/topic/merchantinfo/merchantinfo.js:4694` | POST | `api/topic/host-qrcode` | id, scope |
| `pages/topic/merchantinfo/merchantinfo.js:4855` | POST | `api/registration/merchant/cancel` | id |
| `pages/topic/utils/wx-phone-bind.js:27` | POST | `api/getwxbindphone` | code |
| `subpackageA/components/earnings-overview/index.js:75` | POST | `api/user/balance/list` | pageNum, pageSize |
| `subpackageA/components/scene-how-to-play-detail/index.js:39` | POST | `api/common/infomation_detail` | id |
| `subpackageA/components/scene-member-invite-history/index.js:244` | POST | `api/user/invite_list` | pageNum, pageSize |
| `subpackageA/components/scene-member-invite-history/index.js:250` | POST | `api/user/points/list` | pageNum, pageSize |
| `subpackageA/pages/assetcenter/analysis/index.js:51` | POST | `api/user/balance/list` | pageNum, pageSize |
| `subpackageA/pages/infomation/infomation.js:221` | POST | `api/common/infomation_list` | pageNum, pageSize |
| `subpackageA/pages/infomationdetail/infomationdetail.js:64` | POST | `api/common/infomation_detail` | id |
| `subpackageA/pages/myproject/index.js:561` | POST | `api/template/topic-template/save-as` | id, scope |
| `subpackageA/pages/myproject/index.js:616` | POST | `api/activity/cancel_preview` | id, scope |
| `subpackageA/pages/myproject/index.js:637` | POST | `api/topic/cancel_preview` | id, scope |
| `subpackageA/pages/myproject/index.js:742` | POST | `api/template/my-list` | is_quote, keyword, category_id, pageNum, pageSize, scope |
| `subpackageA/pages/myproject/index.js:993` | POST | `api/template/{}/market-submit` | scope |
| `subpackageA/pages/myproject/index.js:1103` | POST | `api/topic/cancel` | id, reason, scope, cancellationEpoch |
| `subpackageB/pages/im/chat/index.js:200` | GET | `api/v1/community/notifications` | limit |
| `subpackageB/pages/im/chat/index.js:331` | POST | `api/im/messages` | conversation_id, cursor_id, size |
| `subpackageB/pages/im/chat/index.js:404` | POST | `api/im/messages` | conversation_id, cursor_id, size |
| `subpackageB/pages/im/chat/index.js:674` | POST | `api/im/send-receipt` | conversation_id, client_message_id |
| `subpackageB/pages/im/chat/index.js:707` | POST | `api/im/messages` | conversation_id, cursor_id, size |
| `subpackageB/pages/im/chat/index.js:812` | POST | `api/topic/list` | is_my, keyword |
| `subpackageB/pages/im/chat/index.js:927` | POST | `api/im/report` | message_id, reason |
| `subpackageB/pages/im/chat/index.js:1026` | POST | `api/im/delete` | conversation_id |
| `subpackageB/pages/im/chat/index.js:1287` | POST | `api/im/messages` | conversation_id, cursor_id, size |
| `subpackageB/pages/im/list/index.js:447` | POST | `api/im/delete` | conversation_id |
| `subpackageB/pages/im/list/index.js:515` | POST | `api/im/mute` | conversation_id, muted |
| `subpackageP3/pages/growthcenter/index/index.js:317` | POST | `api/growth/leaderboard` | metric, period, limit |
| `subpackageP3/pages/growthcenter/leaderboard/index.js:137` | GET | `api/growth/leaderboard` | metric, period, limit |
| `subpackageP3/pages/object-cards/index/index.js:139` | POST | `api/object-card/list` | pageNum, pageSize, category |
| `subpackageP3/pages/object-cards/index/index.js:440` | POST | `api/object-card/rename` | id, title |
| `subpackageP3/pages/stamp-album/index/index.js:109` | POST | `api/roam/stamp/list` | pageNum, pageSize |
| `subpackageP3/pages/stamp-camera/index/index.js:389` | POST | `api/roam/stamp/create` | picUrl, idempotencyKey |

The same function also matches six calls outside this half, because the checker pins any call whose path, method, and field names are contained in the test. Those calls were not given their own tests:

- `pages/topic/merchantapply/index.js:318` (same `POST api/registration/merchant/info` fields `id`)
- `pages/topic/components/cy/chapter-node-form/index.js:358` and `pages/topic/components/cy/chapter-target-picker/index.js:100` (`POST api/template/my-list`, field `scope` only)
- `pages/gerenziliao/gerenziliao.js:837` (same `POST api/getwxbindphone` field `code`)
- `pages/publish/activity/index.js:1487` (`POST api/template/my-list`, fields `is_quote`, `keyword`)
- `subpackageMember/components/cy/scene-play-activity-detail/index.js:475` (`POST api/activity/cancel_preview`, field `id` only)

## Still missing in this half

Missing endpoint 13. Missing test 59. Every missing-endpoint row is also missing a test.

No single literal path (13). Three calls choose `/api/club/detail` or `/api/merchant/public-detail` with a ternary (`merchantinfo.js:3368`, `pricing/index.js:227`, `pricing/partner/index.js:205`). Both path strings already exist on `PlayerContentMPContract`. Four `request(` calls in `pages/topic/utils/voice-enrollment-journal.js` are the local predicate, not HTTP. The other six forward `url` (`scene-member-invite-history/index.js:61`, `myproject/index.js:696`, `myproject/index.js:1130`, `video-bounty/index.js:11`, `video-bounty/index.js:20`, `growthcenter/index/index.js:35`).

Field list or method left unparsed (46), so a test cannot pin them:

- 32 pass `data` through `JSON.stringify(...)`, including `POST api/topic/pricing/confirm` at `pages/topic/pricing/index.js:440`.
- 12 have no closed `data` object (`content-report.js` passes `data`, several GETs and POSTs omit `data`, and the new audit detail GET is in this group).
- 2 are `req('/api/medal/wall')` and `req('/api/badge/wall-v2')` at `subpackageP3/pages/badge-wall/index/index.js:245`. The method is not on that call. `ProfileService.badgeWall` already holds both paths.

## Left as it was

`PlayerContentMPContract.moneyEnabled` is false. `PlayerContentMPContract.pricingGrantEnabled` is false. `registrationQuote`, `registrationCreate`, and `pricingConfirm` still throw before a request exists, and they still send nothing.

`App/WalletIncomeAnalysisReader.swift` was not edited. `TopicClubShareLink` still assigns `clubCode` with `Self.clubCode(trimmed)` and keeps `init(clubCode: String?)`. `App/AppSession.swift` was not edited. `tools/check_mp_contract_coverage.py`, `project.pbxproj`, and `tools/current_ci_manifest.json` were not edited.

No `swiftc` run. This receipt does not claim a parse.
