# Cloud stubs audit — row 28

Parent: `origin/ui/next` `bdd0a90b3b3c1abb52c767d2fe877effed428755`. Branch `ui/cloud-stubs-audit`.

`App/AppSession.swift` stays 8176 lines and `App/AppCompositionRoot.swift` stays 4307 lines. `docs/release/contract-failing-baseline.txt` was not edited. `ChinaReviewedRouteCapability` counts stay 996 / 622 / 0 / 374, and the wired-pattern count stays 672. This branch does not mark a route live.

## English

Stub-ledger row 28 only. `IMReviewAuditReading` now has a reader next to the IM code (`App/IMReviewAuditReader.swift`). It sends one `GET /api/audit/{taskId}/detail` and reads `data.task` for the 「当前审核记录」 section. Timeline rows are `data.timeline` on that same payload (or `data.task.timeline` when the sibling list is absent). The session reader is injected from `CloudB3RootModifier`. It does not add a method to `AppSession`.

Known status values 0–4 and actions `SUBMIT`, `APPROVE`, `REJECT`, and `REVERT` use the mini-program labels, in English and Simplified Chinese (`mpd.review.status.*`, `mpd.review.action.*`). A missing task is a failed read. A missing or unrecognized status, action, or time is an em dash (`—`). A blank reason is omitted. Booleans are not turned into a status. The two closed-group card titles do not send the request.

The reader does not call `POST /api/audit/appeal`, does not mark notifications read, and does not turn governance reads or writes on. `ReportProgressUnreadReader.markOpened()` is unchanged. China production still refuses this path at the existing unwired-route gate, because this change does not add the path to the route catalog.

`python3 tools/generate_project.py` registered the new Swift file. `tools/check_design_lint.py` and `tools/check_scaffold.py` were run before push. This VM has no Swift compiler, so the new unit tests were not executed.

## 简体中文

只补台账第 28 行。`IMReviewAuditReading` 在现有 IM 代码旁新增读取器（`App/IMReviewAuditReader.swift`）。它只发一次 `GET /api/audit/{taskId}/detail`，用 `data.task` 填「当前审核记录」。时间线取同一份响应里的 `data.timeline`；没有这份列表时才看 `data.task.timeline`。会话读取器从 `CloudB3RootModifier` 注入，不给 `AppSession` 加方法。

状态 0–4 与动作 `SUBMIT`、`APPROVE`、`REJECT`、`REVERT` 用小程序原文案，并提供英文和简体中文。没有 `task` 算读取失败。状态、动作或时间缺失或无法识别时显示破折号（`—`）。空的理由不显示。布尔值不当成状态。两张「组局已关闭」卡片不发这个请求。

不调用 `POST /api/audit/appeal`，不把通知标为已读，也不打开治理读或写。`ReportProgressUnreadReader.markOpened()` 没有改。中国区生产环境仍由原有的未接线拦截拒绝这条路径，因为这次没有把路径写进路由目录。

新的 Swift 文件由 `python3 tools/generate_project.py` 登记。推送前已跑 `tools/check_design_lint.py` 和 `tools/check_scaffold.py`。这台机器没有 Swift 编译器，新增的单元测试没有执行。
