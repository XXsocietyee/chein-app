# Cloud stubs — replay #1

Parent: `origin/ui/next` `11e7c2c4559ee3a210fdcfacf8abee717c312ff9`.
Ledger (not edited): `origin/ui/stub-ledger` `0ad3cefa5994debfd89f430f1481e58e5ed2aa89` `docs/release/stub-ledger.md`, row #1 only.
`docs/release/contract-failing-baseline.txt` was not edited. `App/AppSession.swift` stayed 8176 lines. `App/AppCompositionRoot.swift` stayed 4307 lines. Money, merchant, password, and presence were not opened.

## English

Row #1 is 再玩一次 on the finish sheet (`PlayThemeReplayBinding` / `\.playThemeReplay`).

`GET /api/play/theme/state` now decodes `replayAllowed` only when the JSON value is boolean `true`. `1` and `"true"` stay not allowed. A `TEAM` scope is not offered. The finish-sheet button is hidden until that flag is true and `sessionId` is the open card.

`POST /api/play/theme/replay` sends exactly `{sessionId}`. It is sent only after a fresh state read still has `replayAllowed === true` for that same session. The client then reads `GET /api/play/theme/state?topicId&sessionId` again. Success is only `playInstanceId == "replay:<old>"` on that queried session, including when the post body names a new session id. A second tap while a request id is saved does not post again. It only reads back.

The request id is kept on the device. It is not a field on the wire. A transport error, a non-2xx response, or a read-back that does not match stays unknown on that same id. The visible unknown mark is an em dash (`—`) in English. A business code other than 200, or HTTP 401, does not report success and does not keep the id. This is not a payment. A body that adds `amount` or `payChannel` is refused by the composition.

The China reviewed route gate already admitted `/api/play/theme/replay` through `wiredPatterns`. No China path was added, and the pinned route counts are unchanged. The composition play list did not include that post, so `api/play/theme/replay` was added there, and the body must be `{sessionId}` only. Theme-state reads were still dropped by the composition query gate, even though the route is live and the backpack reader does not refuse the production host. The existing query-admission line now also names exactly `api/play/theme/state`, and the player-write check allows that GET with an empty body. `POST api/play/theme/state` stays closed. The replay client uses the same production transport as theme state. It does not refuse `www.chengyinhub.com`.

The binding is `App/PlayThemeReplayProduction.swift`, built from the session's regional configuration and `runtimeHTTPTransport`. It is installed on the play screen. `AppSession` gained no API.

Checks on this branch, before push: `python3 tools/generate_project.py`, `python3 tools/check_scaffold.py` PASS, `python3 tools/check_design_lint.py` PASS. Swift is not installed on this machine, so the new Core tests and the composition test were not executed here.

## 简体中文

第 1 行是结算单上的「再玩一次」（`PlayThemeReplayBinding` / `\.playThemeReplay`）。

`GET /api/play/theme/state` 现在读取 `replayAllowed`，只有 JSON 布尔值 `true` 算允许。`1` 和 `"true"` 都不算。`TEAM` 不提供。结算单按钮在标志为真且 `sessionId` 就是当前这局之前保持隐藏。

`POST /api/play/theme/replay` 只发送 `{sessionId}`。发送前会再读一次状态，必须仍是 `replayAllowed === true` 且场次一致。随后再读 `GET /api/play/theme/state?topicId&sessionId`。只有被查询的那一局 `playInstanceId == "replay:<旧场次>"` 才算成功；如果回包给出了新的场次号，就按那个场次号回读。已保存请求号时，再次点按不再 POST，只回读。

请求号留在本机，不放进请求体。传输失败、非 2xx，或回读对不上，都停在同一个请求号上，结果未知。界面上的未知标记是破折号（`—`）。业务码不是 200，或 HTTP 401，不算成功，也不保留该请求号。这不是支付。请求体若带上 `amount` 或 `payChannel`，组合层会拒绝。

中国审核路由门本来就已经通过 `wiredPatterns` 放行 `/api/play/theme/replay`。没有新增中国路径，路由计数没有改。组合层的 play 列表原先没有这条 POST，所以只加入了 `api/play/theme/replay`，并且请求体必须恰好是 `{sessionId}`。主题状态的读取仍会被组合层的查询门丢掉，尽管这条路由已是线上，背包读取也不会拒绝生产域名。原有的查询放行那一行现在多了恰好 `api/play/theme/state`，玩家写入检查只允许空请求体的 GET。`POST api/play/theme/state` 仍然关闭。再玩一次使用和主题状态相同的生产传输，不拒绝 `www.chengyinhub.com`。

绑定在 `App/PlayThemeReplayProduction.swift`，取自会话已有的区域配置和 `runtimeHTTPTransport`，装在游玩页上。`AppSession` 没有新增接口。

推送前检查：`python3 tools/generate_project.py`，`python3 tools/check_scaffold.py` 通过，`python3 tools/check_design_lint.py` 通过。本机没有 Swift，新增的 Core 测试和组合层测试未在此执行。
