# 商家 / 合作 / 台账 / 结算 / 核销 / `api/im/read`

真源：`liboyang42-cpu/hengyin` `chengyinhub-xcx` `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`。
覆盖表：`origin/cursor/mp-contract-coverage` `569fca24195166bfb70cba51a8e2aedff27da2a3`。
本分支基线：`origin/ui/combined-r7` `aee32a61f0f69b880bc9e33811463ccc73351bbe`。

口径沿用该覆盖提交的 `tools/check_mp_contract_coverage.py`：一行是名为 `request(` 的调用。`sendRequest(`、`req(`、函数定义 `function request(`、方法简写 `request(...) {` 不是行。字段不是闭合对象字面量时，工具把该行标成未解析，未解析行不算钉住。台账页的 `request(url, data, done)` 和回复恢复的 `request(url, payload, done)` 都带尾随回调，所以工具仍报 `MISSING`。本页的测试直接驱动 Core 构造器，并在源码里写出路径、`"POST"` 和字段名。

俱乐部治理、玩法、漫游、会员券不在本页。`api/club/settlement/summary` 保持 `POST {clubId}`，没有改回 GET。打款、退款回应、提现开关保持关闭。IM 已读开关保持关闭。

## 已钉的 `request(` 行

| MP | 方法与路径 | 小程序实际发送 | Core | 测试 |
|---|---|---|---|---|
| `pages/merchant/ledger/index.js:292` | POST `api/merchant/events` | JSON `{}` | `MerchantService.events` | `testMerchantEventsPinsPostEmptyObject` |
| `pages/merchant/ledger/index.js:324` | POST `api/merchant/finance/redemptions` | JSON `filter`、`pageNum`、`pageSize`，有主题时加 `topicId` | `MerchantFinanceRedemptionList.request` / `.redemptions` | `testLedgerRedemptionsPinsFilterPageAndTopic` |
| `pages/merchant/ledger/index.js:360` | POST `api/merchant/aftercare/list` | 查询 `bucket`、`pageNum`、`pageSize`，正文 JSON `{}` | `MerchantBusinessQuery.aftercare` | `testAftercareListPinsBucketQueryAndEmptyJSON` |
| `pages/merchant/ledger/index.js:490` | POST `api/merchant/finance/overview` | JSON `{}` | `.overview` | `testLedgerOverviewPinsPostEmptyObject` |
| `pages/merchant/ledger/index.js:492` `:549` | POST `api/merchant/finance/settlement-entries` | JSON `pageNum`、`pageSize`（20）、`source`（缺省 `all`） | `.entries` | `testSettlementEntriesPinsPageAndSource` |
| `pages/merchant/ledger/index.js:496` `:551` | POST `api/merchant/finance/public-transfer-batches` | JSON `pageNum`、`pageSize`（20） | `.batches` | `testPublicTransferBatchesPinsPage` |
| `pages/merchant/ledger/index.js:547` | POST `api/merchant/finance/redemptions` | 与 `:324` 相同，无 `topicId` | `.redemptions` | `testLedgerRedemptionsPinsFilterPageAndTopic` |
| `pages/merchant/reviews/reply-recovery.js:67` | POST `api/merchant/reviews/reply`、`reply/update`、`reply/delete` | JSON `reviewId`（十进制字符串）、`expectedVersion`、`requestId`；删除不带 `content` | `MerchantBusinessMutation.review` | `testReviewReplyPinsDecimalIdAndStaysUnsent` |
| `pages/merchant/reviews/reply-recovery.js:76` | POST `api/merchant/reviews/reply/receipt` | JSON `reviewId`、`action`、`requestId` | `MerchantReviewReplyOriginal.receiptFields` | `testReviewReceiptPinsReviewActionAndRequest` |
| `subpackageMember/components/cy/profile/index.js:914` | POST `api/merchant/public-home` | JSON `{"memberId": ...}` | `PublicMerchantHomeHTTPReader.home` | `testPublicHomePinsMemberId` |

`:360` 的模板字符串让工具按 `{bucket}` 形状去对符号，Core 里的固定字面量 `api/merchant/aftercare/list` 仍被标成缺端点。请求本身是查询参数加空 JSON，不是路径插值。

## 额外钉住的 `sendRequest`（不是表里的 `request(` 行）

| MP | 方法与路径 | 小程序实际发送 | Core | 测试 |
|---|---|---|---|---|
| `pages/merchant/verify-records/index.js` | POST `api/merchant/finance/redemptions` | JSON `filter: "all"`、`pageNum`、`pageSize: 50` | `.verificationRecords` | `testVerificationRecordsPinsFilterAndPageSize` |
| `pages/merchant/index/index.js`、`subpackageB/pages/im/list/index.js` | POST `api/im/read` | 无自定义头，因此 `application/x-www-form-urlencoded;`，正文只有 `conversation_id` | `IMExpandedService.merchantInboxMarkReadRequest` | `testIMReadPinsConversationIdAndStaysOff` |
| `subpackageB/pages/im/chat/index.js` `markRead` | POST `api/im/read` | 同上编码，字段是 `conversation_id` 与 `read_to`，没有 `request_id` | 既有 `performOrdinaryRead` 未改（仍是 multipart，且带 `request_id`） | 同一测试只引用字段名，并断言默认开关关闭 |

会员券核销、`api/merchant/desk/arrivals/today`、扫码路由都是 `sendRequest` 或既有读路径，本页不新增。

## 表内仍缺、且不是 HTTP

| MP | 原因 |
|---|---|
| `pages/merchant/ledger/index.js:799` | `subscribe.request(['coopSettle'])` |
| `pages/merchant/utils/voice-enrollment-journal.js:18` `:20` `:76` `:100` | 本地谓词 `request(entries, index)` |
| `pages/coop/invite/index.js:760` | `subscribe.request(['coopStatus'])`。真正的 `POST /api/coop/invite` 是 `sendRequest`，本页不打开 |
| `subpackageMember/components/cy/coop-invite-sheet/index.js:215` | 同上 |
| `subpackageB/pages/im/list/index.js:246` | `subscribe.request(['coopInvited'])`，不是 `api/im/read` |

## 同目录里明确不取

| MP | 原因 |
|---|---|
| `pages/merchant/relation/index.js:388` | `community.request` 指向 `api/creativesquare/list`，不是商家/合作/台账/结算/核销 |
| `subpackageMember/components/cy/profile/index.js:83` | 通用 `req({ url })`，URL 是变量 |
| `subpackageMember/components/cy/profile/index.js:1789` | `POST api/im/start`，不在指定范围 |
| 俱乐部治理、玩法、漫游、会员券 | 任务排除 |
