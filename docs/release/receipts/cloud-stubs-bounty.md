# Cloud stubs — video bounty (ledger row 24)

Branch `ui/cloud-stubs-bounty`. Parent `origin/ui/next` `11e7c2c4559ee3a210fdcfacf8abee717c312ff9`.

Stub-ledger row 24 only. `mpParity.videoBounty` is filled on the existing `MPParityBindings` struct in `App/MPParityKit.swift` by `fillingVideoBounty` in `App/VideoBountySession.swift`. The struct is not redeclared. `Core/MPParityBindings.swift` was not added. `App/AppSession.swift` and `App/AppCompositionRoot.swift` are unchanged (8176 and 4307 lines). `App/RegionalLaunchConfiguration.swift` is unchanged. `docs/release/contract-failing-baseline.txt` is unchanged.

## Reads

`VideoBountySource` sends three GETs:

- `/api/video-bounty/submission/mine`
- `/api/video-bounty/accrual/mine`
- `/api/video-bounty/campaign/list` (author open campaigns: `campaignKey`, `title`, `description`, `windowDays` only)

The submit form still appears only when the ops link already has `campaignKey` and `topicId`, matching `subpackageA/pages/video-bounty`. The campaign list is not turned into that link. A row without a string `campaignKey` is dropped. An empty list stays empty. A non-array payload stays a failed read. No campaign is synthesized.

## Writes

Submit, appeal, and cancel are the only writes. Each saves one request id before the POST and sends that same id on every retry. HTTP 2xx and 4xx clear the id. A transport failure, or any other status, keeps the id. The next submit, appeal, cancel, or explicit reread posts the saved body again and marks the envelope as a receipt reread. A changed form does not mint a replacement id while the previous one is unconfirmed.

Accrual `payableAmount` is display text. Null, a non-number, or a value that cannot be shown is nil, and the screen draws an em dash. A server 0 stays `¥0.00`. `payoutState`, rate, cap, and gross amount are not shown as a balance. There is no payout, withdraw, redeem, or wallet method. Attribution is not called.

`ChinaReviewedRouteCapability` admits only those six paths, in `videoBountyOwnerGrant`. Points, affiliate, and orient paths were not edited. `wiredPatternCount` stays 672.

## Checks

`python3 tools/generate_project.py`, `python3 tools/check_design_lint.py`, and `python3 tools/check_scaffold.py` passed. This VM has no Swift compiler, so `VideoBountySourceTests` was not executed.

## 中文

分支 `ui/cloud-stubs-bounty`。父提交 `origin/ui/next` `11e7c2c4559ee3a210fdcfacf8abee717c312ff9`。

只补 stub-ledger 第 24 行。`App/VideoBountySession.swift` 里的 `fillingVideoBounty` 给 `App/MPParityKit.swift` 里已有的 `MPParityBindings` 填上 `mpParity.videoBounty`。没有重新声明这个结构体，也没有新增 `Core/MPParityBindings.swift`。`App/AppSession.swift` 与 `App/AppCompositionRoot.swift` 没有改动（仍是 8176 与 4307 行）。`App/RegionalLaunchConfiguration.swift` 没有改动。`docs/release/contract-failing-baseline.txt` 没有改动。

## 读取

`VideoBountySource` 发三个 GET：

- `/api/video-bounty/submission/mine`
- `/api/video-bounty/accrual/mine`
- `/api/video-bounty/campaign/list`（作者侧进行中的活动，只取 `campaignKey`、`title`、`description`、`windowDays`）

投稿表单仍只在运营链接已经带了 `campaignKey` 和 `topicId` 时出现，与 `subpackageA/pages/video-bounty` 一致。活动列表不会被写成这条链接。没有字符串 `campaignKey` 的行会被丢掉。空列表保持为空。不是数组的载荷算读取失败。不会编造活动。

## 写入

只有投稿、申诉、取消三个写入。每个写入在 POST 之前保存一个请求 id，之后每次重试都带这同一个 id。HTTP 2xx 和 4xx 会清掉这个 id。传输失败，以及其他状态，会留着这个 id。下一次投稿、申诉、取消，或显式的回读，会再次提交已保存的正文，并把结果标成回执重读。上一次结果尚未确认时，改了表单也不会另发一个新 id。

应计的 `payableAmount` 只是展示文案。空值、非数字，或无法展示的值是 nil，界面画成破折号。服务端的 0 仍显示 `¥0.00`。`payoutState`、费率、封顶和未封顶金额不会被画成余额。没有兑付、提现、兑换或钱包方法。不调用归因接口。

`ChinaReviewedRouteCapability` 只放行这六条路径，写在 `videoBountyOwnerGrant`。积分、联盟和定向的路径没有改。`wiredPatternCount` 仍是 672。

## 检查

已通过 `python3 tools/generate_project.py`、`python3 tools/check_design_lint.py` 和 `python3 tools/check_scaffold.py`。这台机器没有 Swift 编译器，所以没有执行 `VideoBountySourceTests`。
