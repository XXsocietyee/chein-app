# ChinaReviewedRouteCapability rows still `.missing` after TEST r2 067da9748 (2026-11-13)

App tree `ui/main` a2a9d82e7 plus the run-session read. There are 204 literal `.missing` marks. Each was probed on TEST 8120
(r2 067da9748) as player 9004:
- POST with an empty JSON body, `{}` path segments replaced by `1` and a trailing `/` removed.
- When POST answered "请求路径不存在" or "method not supported", a GET as well.

Prefix rows (ending in `/`) are call-site prefixes. Their children may exist even when the bare prefix is 404.

Counts: answers on TEST r2 067da9748: 145, backend 404 on TEST r2 067da9748: 59.

`/api/merchant/offer-withdrawal/request` is the one coordinator-listed path still 404 (backend fix pending).

| Path | Reason | Probe evidence (first 110 chars) |
|---|---|---|
| `/api/activity/create-requests/read` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"协议版本不符","code":400} |
| `/api/activity/create-requests/resume-post-processing` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"协议版本不符","code":400} |
| `/api/activity/create-requests/submit` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"协议版本不符","code":400} |
| `/api/approved-topic-release/v1/prepare` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"缺少字段","code":400} |
| `/api/approved-topic-release/v1/publish` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"缺少字段","code":400} |
| `/api/approved-topic-release/v1/review/current` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"缺少字段","code":400} |
| `/api/approved-topic-release/v1/review/prepare` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"缺少字段","code":400} |
| `/api/approved-topic-release/v1/review/sources` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"缺少字段","code":400} |
| `/api/approved-topic-release/v1/review/status` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"缺少字段","code":400} |
| `/api/approved-topic-release/v1/review/submit` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"缺少字段","code":400} |
| `/api/approved-topic-release/v1/status` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"缺少字段","code":400} |
| `/api/channel-platform/admission/requests/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/channel-platform/governance/moderation/requests/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/channel-platform/governance/reports/requests/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/channel-platform/governance/requests/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/channel-platform/requests/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/channel/{}/board` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"request_id 不合法","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/channel/{}/board/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"request_id 不合法","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/channel/{}/board/{}` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/channel/{}/progress/overview` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"频道不存在","code":404,"errorCode": |
| `/api/channel/{}/progress/privacy` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"body","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/city-game/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/{}/request/{}` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"没有这条请求的回执","code":404,"errorCo |
| `/api/city-game/acquisition` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/acquisition/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/action-budget` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/action-budget/command` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"预算指令无效","code":400,"errorCode":"CITY_BUDGET_INVALID"} |
| `/api/city-game/action-budget/request/{}` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"没有这条请求的回执","code":404,"errorCo |
| `/api/city-game/action-budget/state` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 're |
| `/api/city-game/arrival-evidence` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/arrival-evidence/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/merchant/operations` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/merchant/operations/availability` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 're |
| `/api/city-game/merchant/operations/intent` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"门店指令无效","code":400,"errorCode":"OBJECT_SCOPE"} |
| `/api/city-game/merchant/operations/request/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/neutral-tasks` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/neutral-tasks/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/onsite-tasks` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/onsite-tasks/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/player-rules` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"regionId invalid","code":400," |
| `/api/city-game/state/deltas` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"cursor invalid","code":400,"er |
| `/api/city-game/state/snapshot` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"regionId invalid","code":400," |
| `/api/city-game/task-history` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 're |
| `/api/city-game/team-participation` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/city-game/team-participation/command` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"requestId invalid","code":400,"errorCode":"requestId"} |
| `/api/city-game/team-participation/invite` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 're |
| `/api/city-game/team-participation/state` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 're |
| `/api/city-value/visits` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"到访请求无效","code":400,"errorCode":"CITY_VALUE_INVALID"} |
| `/api/city-value/visits/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"到访请求无效","code":400,"errorCode":"CITY_VALUE_INVALID"} |
| `/api/city-value/visits/feedback` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"到访不存在","code":404,"errorCode":"CITY_VALUE_VISIT_NOT_FOUND"} |
| `/api/city-value/visits/services` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"regionId invalid","code":400," |
| `/api/city/nodes/complete` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"请求参数类型不匹配，参数[id]要求类型为：'Long'，但 |
| `/api/city/nodes/favorite` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"请求参数类型不匹配，参数[id]要求类型为：'Long'，但 |
| `/api/city/walking/target` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'po |
| `/api/club/admission/receipt` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"读回参数无效","code":400} |
| `/api/club/badge/original-receipt` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"读回参数无效","code":400} |
| `/api/club/event-ops/series/original-result` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"读回参数无效","code":400} |
| `/api/club/event-ops/waitlist/{}` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/club/open-settings/welcome-note-receipt` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"读回参数无效","code":400} |
| `/api/club/post/operation/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/club/post/operation/comment/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/club/post/operation/receipt` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"原始操作参数无效","code":400} |
| `/api/club/roles/assign-receipt` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"读回参数无效","code":400} |
| `/api/club/roles/revoke-receipt` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"读回参数无效","code":400} |
| `/api/club/settings/notify-level` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"body","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/club/settlements` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/club/update` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/common/uploadOSS/receipt` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"读回参数无效","code":400} |
| `/api/compliance/usage-records` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"操作成功","code":200,"data":{"acco |
| `/api/config/public` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/coupon/command-receipt` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"参数缺失","code":400} |
| `/api/free-explore/bundle/transfer` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"套票退款与转赠在当前版本不开放","businessCode":"BUNDLE_MONEY_WRITE_DISABLED","code":409} |
| `/api/free-explore/bundle/voucher/appeal` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"自由探索套票暂未开放","businessCode":"BUNDLE_LEDGER_OFF","code":409} |
| `/api/friend/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/friend/channel-invite/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/friend/directory` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'se |
| `/api/friend/directory/detail` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'pe |
| `/api/friend/group/delete` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"INVALID_FIELD","code":400,"errorCode":"INVALID_FIELD","detail":"request_id"} |
| `/api/friend/group/list` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"操作成功","code":200,"data":{"viewer_id":9004,"list":[{"id":null,"name":"未分组","position":0,"version":0 |
| `/api/friend/group/save` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"INVALID_FIELD","code":400,"errorCode":"INVALID_FIELD","detail":"request_id"} |
| `/api/friend/metadata` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'pe |
| `/api/friend/metadata/receipt` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'ac |
| `/api/friend/metadata/settle` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"INVALID_FIELD","code":400,"errorCode":"INVALID_FIELD","detail":"target_id"} |
| `/api/friend/progress` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'pe |
| `/api/friend/remark` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"INVALID_FIELD","code":400,"errorCode":"INVALID_FIELD","detail":"request_id"} |
| `/api/friend/removal/receipt` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'pe |
| `/api/friend/removal/settle` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"INVALID_FIELD","code":400,"errorCode":"INVALID_FIELD","detail":"peer_id"} |
| `/api/friend/remove` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"INVALID_FIELD","code":400,"errorCode":"INVALID_FIELD","detail":"body"} |
| `/api/friend/team-invite/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/growth/leaderboard/anonymous` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"操作成功","code":200,"data":{"metric":"point","period":"total","list":[{"rank":1,"score":100,"nickname":"匿 |
| `/api/invite/revoke` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"request_id","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/join-request/approve` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"request_id","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/join-request/cancel` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"request_id","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/join-request/reject` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"request_id","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/join-request/submit` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"request_id","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/location-share/personal` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/map/public-layers` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"图层请求无效","code":400} |
| `/api/marketing/affiliate/summary` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"操作成功","code":200,"data":{"link |
| `/api/marketing/product` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/marketing/product/list` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"操作成功","code":200,"data":[]} |
| `/api/marketing/product/orders` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"操作成功","code":200,"data":[]} |
| `/api/merchant/authoring/player/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/merchant/crm/campaigns/{}/{}` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/merchant/offer-withdrawal/request/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/merchant/reviews/{}` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/mod-commerce/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"工坊购买暂未开放","code":503,"errorCode":"WORKSHOP_COMMERCE_DISABLED"} |
| `/api/mod-installation/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"WORKSHOP_FEATURE_NOT_ENABLED","code":503} |
| `/api/mod-owned-report/licenses/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"WORKSHOP_FEATURE_NOT_ENABLED","code":503} |
| `/api/mod-settlement/mine` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"WORKSHOP_FEATURE_NOT_ENABLED","code":503} |
| `/api/mod-settlement/mine/income` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"WORKSHOP_FEATURE_NOT_ENABLED","code":503} |
| `/api/mod-upgrade/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"WORKSHOP_FEATURE_NOT_ENABLED","code":503} |
| `/api/native/channels/read-through` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"Required request parameter 'conversation_id' for method parameter type String is not present","code":5 |
| `/api/official/v2/events` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/official/v2/organizer-invites/{}/{}` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/onboarding/get` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"guild_kind","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/onboarding/submit` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"request_id","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/order/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/play/advanced/time-window` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"参数有误","code":400} |
| `/api/play/city-orientation/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/play/city-orientation/answer` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"作答请求无效","code":400,"errorCode":"CITY_ORIENTATION_INVALID"} |
| `/api/play/city-orientation/receipt` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'se |
| `/api/play/egg/collect` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"途中彩蛋已下线","code":410,"errorCode":"ROUTE_EGG_OFFLINE"} |
| `/api/play/player-journey/choices` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"参数有误","code":500} |
| `/api/play/player-journey/memory` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"参数有误","code":500} |
| `/api/play/player-journey/report` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"参数有误","code":500} |
| `/api/play/player-journey/seats` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"参数有误","code":500} |
| `/api/play/route-action` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'se |
| `/api/play/seat-invitations` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"参数有误","code":400} |
| `/api/privacy/progress` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"body","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/progress/meter` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'ch |
| `/api/progress/requests` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 're |
| `/api/progress/requests/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 're |
| `/api/progress/requests/{}` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"request_id","code":400,"errorC |
| `/api/project/state-requests/context` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"参数无效","code":400} |
| `/api/project/state-requests/read` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"读回参数无效","code":400} |
| `/api/project/state-requests/submit` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"协议版本不符","code":400} |
| `/api/public-catalog/city/list` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"操作成功","code":200,"data":{"total":1,"rows":[{"cityCode":null,"cityName":null,"cityPath":null,"topicCoun |
| `/api/public-catalog/filters` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"操作成功","code":200,"data":{"cities":[{"cityCode":null,"cityName":null,"cityPath":null,"topicCount":3,"on |
| `/api/public-catalog/ids` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"操作成功","code":200,"data":[]} |
| `/api/public-catalog/info` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"id 参数不合规","code":400} |
| `/api/public-catalog/list` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"操作成功","code":200,"data":{"total":3,"rows":[{"id":"992901","canonicalPath":"/quest/992901","cityCode":n |
| `/api/public-catalog/map` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"操作成功","code":200,"data":{"total":3,"rows":[{"id":"992901","canonicalPath":"/quest/992901","name":"E2E  |
| `/api/rank/list` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"scope 不合法","code":500} |
| `/api/referral/landing/gift` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"操作成功","code":200,"data":{"kind":"GIFT","state":"INVALID_TOKEN","reasonCode":"TOKEN_REQUIRED","product" |
| `/api/referral/landing/referral` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"操作成功","code":200,"data":{"kind":"REFERRAL","state":"INVALID_TOKEN","reasonCode":"TOKEN_REQUIRED","invi |
| `/api/reward-pledge` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/reward-pledge/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/reward-pledge/awards/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"FORBIDDEN","code":403,"errorCo |
| `/api/reward-pledge/ops/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"FORBIDDEN","code":403,"errorCo |
| `/api/reward-pledge/review/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"操作成功","code":200,"data":{"stor |
| `/api/reward-pledge/versions/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"FORBIDDEN","code":403,"errorCo |
| `/api/rewards/noncash/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"操作成功","code":200,"data":[]} |
| `/api/rewards/noncash/subjects/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"NOT_FOUND","code":404,"errorCo |
| `/api/rewards/noncash/versions/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"NOT_FOUND","code":404,"errorCo |
| `/api/roam/check-in.` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/roam/finished` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/roam/point/{}` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/roam/route/{}` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/roam/routes` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/space/join-pause` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"request_id","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/space/leave` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"request_id","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/stamps` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/support/tickets` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/team/{}` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/team/original-request` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"INVALID_FIELD","code":400,"errorCode":"INVALID_FIELD","detail":"envelope"} |
| `/api/template/author-requests/read` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"协议版本不符","code":400} |
| `/api/template/author-requests/submit` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"协议版本不符","code":400} |
| `/api/template/report-receipt` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/topic/attribute-author` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"缺少原始请求标识","code":400,"errorCode":"ATTRIBUTE_REQUEST_INVALID"} |
| `/api/topic/attribute-author/references` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'to |
| `/api/topic/attribute-author/request` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"topicId invalid","code":400,"e |
| `/api/topic/attribute-author/validate` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"属性请求无效","code":400,"errorCode":"ATTRIBUTE_REQUEST_INVALID"} |
| `/api/topic/cover` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/topic/cover/{}/content` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'so |
| `/api/topic/cover/selection` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"封面选择请求无效","code":400,"errorCode":"COVER_SELECTION_INVALID"} |
| `/api/topic/cover/selection/current` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'to |
| `/api/topic/cover/selection/status` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"封面选择请求无效","code":400,"errorCode":"COVER_SELECTION_INVALID"} |
| `/api/topic/cover/upload` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"上传数据无法解析，请重试或更换文件","code":400} |
| `/api/topic/detail` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/topic/edit-requests/read` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"编辑请求无效","code":400,"errorCode":"EDIT_REQUEST_INVALID"} |
| `/api/topic/edit-requests/resume-post-processing` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"编辑请求无效","code":400,"errorCode":"EDIT_REQUEST_INVALID"} |
| `/api/topic/edit-requests/submit` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"编辑请求无效","code":400,"errorCode":"EDIT_REQUEST_INVALID"} |
| `/api/topic/module-preflight` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'to |
| `/api/topic/publish-status` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"参数不合规","code":500} |
| `/api/user/coupons/{}/use` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/user/follow-list` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | POST:{"msg":"Request method 'POST' is not supported","code":500} // GET:{"msg":"Required request parameter 'ki |
| `/api/user/stamps/received` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/welcome-screen/get` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"guild_kind","code":400,"errorCode":"INVALID_FIELD","outcome_known":true} |
| `/api/workshop/creator/pending-packages` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"WORKSHOP_FEATURE_NOT_ENABLED","code":503} |
| `/api/workshop/creator/pending-packages/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"WORKSHOP_FEATURE_NOT_ENABLED","code":503} |
| `/api/workshop/creator/public-theme-use` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"WORKSHOP_FEATURE_NOT_ENABLED","code":503} |
| `/api/workshop/creator/public-theme-use/` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"WORKSHOP_FEATURE_NOT_ENABLED","code":503} |
| `/api/workshop/owned` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/workshop/owned/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/workshop/owned/detail` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"领取编号无效","code":400} |
| `/api/workshop/owned/list` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"列表不接受参数","code":400} |
| `/api/workshop/owned/package` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"领取编号无效","code":400} |
| `/api/workshop/purchased` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/workshop/purchased/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/workshop/purchased/detail` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"WORKSHOP_CONTRACT_UPGRADE_REQUIRED","code":409} |
| `/api/workshop/purchased/install` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/workshop/purchased/install/` | backend 404 on TEST r2 067da9748 (POST and GET) | POST:{"msg":"请求路径不存在","code":404} // GET:{"msg":"请求路径不存在","code":404} |
| `/api/workshop/purchased/installed-text/detail` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"WORKSHOP_CONTRACT_UPGRADE_REQUIRED","code":409} |
| `/api/workshop/purchased/list` | answers on TEST r2 067da9748 (route exists; flip candidate after a contract check) | {"msg":"WORKSHOP_CONTRACT_UPGRADE_REQUIRED","code":409} |
