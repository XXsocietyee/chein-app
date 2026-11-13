# Cloud stubs — orient score appeal and dispute (ledger row 27)

Branch `ui/cloud-stubs-orient-appeal`. Parent `origin/ui/next` `11e7c2c4559ee3a210fdcfacf8abee717c312ff9`.

Stub-ledger row 27 only. Row 11 (the score loader) is unchanged. `App/AppSession.swift` and `App/AppCompositionRoot.swift` are unchanged. `App/ReviewedPlayerJourneyLeases.swift`, `Core/JourneyLoopSource.swift`, and `App/RegionalLaunchConfiguration.swift` are unchanged. `docs/release/contract-failing-baseline.txt` is unchanged. `ChinaReviewedRouteCapability` already marks `/api/orient/scoring/appeal` and `/api/orient/scoring/dispute` live, so that file was not edited and its counts stay put.

## Grant

The two writes are on the existing reports approval inside `ReviewedProductionGateLeases.reportPaths`. There is no second admission type. `ReviewedProductionFormMutationRoute.acceptsPlayerWrite` admits a form POST only when that grant covers the path, the body carries `idempotencyKey`, `sessionId`, and a 1–500 character reason, and an appeal also carries `entryId` or `nodeId`. The receipt re-read is `GET /api/orient/scoring/receipt` for the same key. Sync, settle, purchase, and payout stay refused.

`OrientScoreReviewFactory.makeSubmitter` returns nil unless the signed-in China player or club writer was constructed. The form stays hidden in that case. The read-only note stays on the score screen when the submitter is absent.

## Request id

The id is kept until a confirmed 2xx with a matching review record, or a confirmed 4xx (HTTP 4xx, or an envelope code 4xx). An unknown outcome, including a transport failure after the request is built, a 5xx, or a lost response, stays locked on that id. The client then re-reads the receipt. A matching receipt is the only way that unknown path succeeds. `NOT_FOUND` and a failed re-read do not become success, and they do not mint a new id. A later id does not replace a locked one. The replay sends the original body.

Sync, settle, purchase, and payout are not called.

## Unknown

An unknown result is an em dash (`—`, U+2014) in both English and zh-Hans (`orientScore.review.unknown`). A missing ledger choice is “Choose a ledger entry” / “请选择一条计分记录”. A confirmed rejection is “The server did not accept this.” / “服务器没有接受这次提交。”. A dispute before the round ends is “A dispute can be sent after the round ends” / “对局结束后才能提交争议”.

## Checks

`python3 tools/check_design_lint.py` and `python3 tools/check_scaffold.py` were run before push. This VM has no Swift compiler, so `OrientScoreReviewWriterTests` and the new model test were not executed.

---

# 云端存根 — 定向成绩申诉与争议（台账第 27 行）

分支 `ui/cloud-stubs-orient-appeal`。父提交 `origin/ui/next` `11e7c2c4559ee3a210fdcfacf8abee717c312ff9`。

只做台账第 27 行。第 11 行（成绩读取）没有改。`App/AppSession.swift` 和 `App/AppCompositionRoot.swift` 没有改。`App/ReviewedPlayerJourneyLeases.swift`、`Core/JourneyLoopSource.swift`、`App/RegionalLaunchConfiguration.swift` 没有改。`docs/release/contract-failing-baseline.txt` 没有改。`ChinaReviewedRouteCapability` 里这两条路径本来就是已上线，所以没有改那个文件，计数也不变。

## 授权

这两次写入放在现有的举报授权 `ReviewedProductionGateLeases.reportPaths` 里，没有另做一套准入类型。`ReviewedProductionFormMutationRoute.acceptsPlayerWrite` 只在该授权覆盖路径时放行表单 POST：正文要有 `idempotencyKey`、`sessionId` 和 1–500 字理由；申诉还要有 `entryId` 或 `nodeId`。回读是同一把钥匙的 `GET /api/orient/scoring/receipt`。同步、结算、购买和打款仍然拒绝。

只有已登录的中国玩家或俱乐部已经构造出这份授权时，`OrientScoreReviewFactory.makeSubmitter` 才不是 nil。否则表单保持隐藏，成绩页仍显示只读说明。

## 请求号

请求号一直留到确认的 2xx（回执记录对得上）或确认的 4xx（HTTP 4xx，或包络码 4xx）。未知结果都锁在这个号上，包括请求已经组好之后的传输失败、5xx 和丢失的响应。客户端接着回读回执。未知这条路上，只有对得上的回执才算成功。`NOT_FOUND` 和回读失败都不算成功，也不会新发一个号。后面的号不能换掉还锁着的号。重放发送的是原来的正文。

不调用同步、结算、购买或打款。

## 未知

未知结果在英文和简体中文都是破折号（`—`，U+2014，`orientScore.review.unknown`）。没选计分条目是 “Choose a ledger entry” / “请选择一条计分记录”。确认被拒绝是 “The server did not accept this.” / “服务器没有接受这次提交。”。对局还没结束就提争议是 “A dispute can be sent after the round ends” / “对局结束后才能提交争议”。

## 检查

推送前跑了 `python3 tools/check_design_lint.py` 和 `python3 tools/check_scaffold.py`。这台机器没有 Swift 编译器，所以 `OrientScoreReviewWriterTests` 和新增的模型测试没有执行。
