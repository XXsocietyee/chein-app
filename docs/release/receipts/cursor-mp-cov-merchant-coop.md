# cursor/mp-cov-merchant-coop

- 基线：`origin/ui/combined-r7` `aee32a61f0f69b880bc9e33811463ccc73351bbe`（短 SHA `aee32a61f0f6`，与预期一致）
- 覆盖表：`origin/cursor/mp-contract-coverage` `569fca24195166bfb70cba51a8e2aedff27da2a3`（未并入本分支）
- 小程序：`liboyang42-cpu/hengyin` `chengyinhub-xcx` `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`
- 分支：`cursor/mp-cov-merchant-coop`。无 PR。未推 `main`、`master`、`ui/main`、`ui/combined-*`
- 未跑 `swiftc` / `swift test`。无密钥，无小程序截图
- 明细：`docs/mp-contract-coverage/merchant-coop.md`

## 计数

覆盖表在 `569fca24` 上的全表是 total 102、matched 19、missing_endpoint 42、missing_test 82。那 19 个 matched 里的玩法/漫游钉住测试不在本基线。

本树用同一只检查器重跑（脚本只存在于覆盖提交，未抄进本分支）：

| 项 | 数 |
|---|---|
| total | 102 |
| matched | 2 |
| missing_endpoint | 42 |
| missing_test | 100 |

这 2 个 matched 是基线上已有的玩法回执和漫游护照，不是本页。

指定范围里的 `request(` 行 21 条：

| 项 | 数 |
|---|---|
| 已按小程序正文对齐并被测试引用 | 12 |
| 非 HTTP，保持 missing | 8 |
| 不取（`api/creativesquare/list`） | 1 |
| 检查器仍标 test=MISSING | 21 |

12 条是台账 9 条（`:292` `:324` `:360` `:490` `:492` `:496` `:547` `:549` `:551`）、回复恢复 2 条（`:67` `:76`）、公开主页 1 条（`profile/index.js:914`）。检查器不把它们算进 matched：台账和回复的参数后面还有回调，公开主页包了 `JSON.stringify`，售后列表还被当成带 `{}` 的路径。

额外钉住、但不是 `request(` 行：核销记录（`pageSize` 50）1 条，`api/im/read` 1 条。

新增测试函数：12，都在 `Tests/CoreTests/MiniProgramMerchantCoopContractPinTests.swift`。另改了两条既有断言（售后空 JSON、收件箱已读的 urlencoded 正文）。

## 契约改动

- 售后列表改为查询参数加 JSON `{}`。原先正文是 `.none`。
- 评价回复 / 更新 / 删除 / 回执的 `reviewId` 改为十进制字符串。`expectedVersion` 仍是数字。删除仍不带 `content`。
- 商家收件箱已读改为 `Content-Type: application/x-www-form-urlencoded;`，正文只有 `conversation_id`。聊天 `markRead` 的 `read_to` 仍走原有 `performOrdinaryRead`，编码未改。
- 未新增 Core 类型。新增的是 `MerchantBusinessRequest.queryJSON`、`MerchantReviewReplyOriginal.receiptPath` / `receiptFields`，以及 `IMExpandedService.merchantInboxMarkReadRequest`。写之前在 `App/` 检索过，没有现成同名构造。

## 开关

- `ReleaseMoneyWriteSwitch.payoutEnabled` 与 `withdrawalEnabled` 在测试里复位为 `nil` 后为 false。
- 售后回应 `MerchantBusinessService.execute(.aftercare)` 默认 `permits == false`，并抛 `MerchantBusinessFailure.disabled`。
- `canWriteInboxConversationRead` 与 `canWriteOrdinaryRead` 默认 false。`markInboxConversationRead` 在关闭时抛 `APIError.notConfigured`，传输层无请求。
- `api/club/settlement/summary` 未改，仍是 `POST {clubId}`。

## App 调用点（未改屏幕）

- 事件：`App/MerchantReading.swift`、`App/AppSession.swift`、`App/MerchantHomeView.swift`、`App/MerchantProjectRecentEventsView.swift`
- 台账 / 结算 / 核销 / 售后读：`App/MerchantBusinessViews.swift`、`App/MerchantHomeView.swift`、`App/MerchantLedgerSettlementOverview.swift`、`App/MerchantSettlementOverviewView.swift`、`App/MerchantPersonalIncomeHandoff.swift`、`App/NativeVerificationView.swift`、`App/MPReviewedPageScreen.swift`
- 售后回应界面（Core 仍拒绝发送）：`App/MerchantBusinessEditor.swift`
- 评价回复与回执：`App/MerchantBusinessEditor.swift`、`App/MerchantReviewOriginalRecoveryEntry.swift`、`App/AppSession.swift`、`App/AppCompositionRoot.swift`
- 公开主页：`App/PublicMerchantHomeFixtureView.swift`、`App/AppCompositionRoot.swift`、`App/AppSessionSocialRoam.swift`、`App/BundleCommerceMount.swift`
- 已读：`App/AppSession.swift` 仍只把 `ordinaryReadRequestEnabled` 交给既有 `permits(.imRead)`。本分支没有把 `inboxConversationReadEnabled` 打开
