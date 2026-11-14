# WP-04 coop invites and square delete

Branch `ui/cur-wp-04` from `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46` (`ui/main`). Source text is the WP-04 section of `docs/release/completeness-missing.md` at `e1969026e9469669e165937013e0e4f5c61b4252`. That commit is not the base.

`docs/release/completeness-matrix.csv` is not on `ui/main`. It was not imported. Row status is only in this receipt.

`ReviewedAreaSwitch` was not redeclared. Money, payout, merchant writes, and password login stay closed on `www.chengyinhub.com`. These five paths are player content: they are in `ReviewedPlayerWriteLeases.playPaths` and `ChinaReviewedRouteCapability.wp04OwnerGrant`. Marks, `wiredPatterns`, and the live/missing/wired counts were not edited.

`App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` were not edited. `docs/release/contract-failing-baseline.txt` was not raised. No new `App/` or `Core/` file, so `generate_project.py` was not required.

## Rows

| Row | Status |
| --- | --- |
| PAGE-pages/coop/invite/index | DONE |
| PAGE-pages/coop/invite-detail/index | DONE |
| PAGE-pages/merchant/relation/index | DONE |
| PAGE-pages/mylike/mylike | DONE |
| PAGE-pages/square/detail/index | DONE |
| PAGE-pages/talent/list/index | DONE |
| API-/api/coop/invite/read | DONE |
| API-/api/coop/invite/request | DONE |
| API-/api/coop/invite/requests | DONE |
| API-/api/coop/supply-stations | DONE |
| API-/api/creativesquare/delete | DONE |

Rows still missing: none.

## Screens

`CoopInviteReceiptSections` on the invite composer loads `GET api/coop/invite/requests` and, when a row has a request id, `GET api/coop/invite/request`. Confirmed stations load `GET api/coop/supply-stations` when the kind is merchant, a topic is chosen, and merchants are selected. Loading, empty, and error stay on screen. Unknown fields are `—`. Copy is zh-Hans and English.

`CoopInviteReadReceiptRow` on a received invite posts `api/coop/invite/read` through `CoopFlowService.markInviteRead`. A sent invite shows that opening it does not mark it read and does not post. A missing reader or a failed post stays as an error with retry.

`CreativeSquareAuthorDeleteSection` is on the square detail (when the viewer is the author; member id `0` is `—`), the favorites screen, the talent-list feed, and the merchant relation list. Delete is `POST api/creativesquare/delete` with form field `id`, then `POST api/creativesquare/list` (`is_my=1`). The returned ids must not include the deleted post. A nil square reader on talent list or relation shows `—`.

## Checks

`python3 tools/check_scaffold.py` PASS. `python3 tools/check_design_lint.py` PASS. This VM has no `swiftc` and no `swift`, so changed Swift files were not parsed, compiled, or tested. `Tests/CoreTests/WP04CoopSquareDeleteTests.swift` builds each path from the client type and, on an in-memory transport, deletes post 7 and re-reads the list as `[9]`.

## 中文

分支 `ui/cur-wp-04`，基线 `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46`。只读了 `e1969026e9469669e165937013e0e4f5c61b4252` 里 WP-04 那一节。`completeness-matrix.csv` 不在 `ui/main`，没有整表导入。十一行都是 DONE，没有未完成行。

没有重新声明 `ReviewedAreaSwitch`。`www.chengyinhub.com` 上的支付、提现、商家写入和密码登录仍关闭。五条路径在玩家写入租约和 `wp04OwnerGrant` 里，没有改 marks。没有改 `AppSession`、`AppCompositionRoot`、`RegionalLaunchConfiguration`，也没有抬高 contract-failing baseline。

邀请页读取原请求和据点。收到的邀请详情标记已读；自己发出的邀请不标记。广场详情、喜欢、达人列表和商家关系都显示作者删除，删除后重读列表。未知显示破折号。中英文都在界面上。

`check_scaffold.py` 与 `check_design_lint.py` 通过。本机没有 `swiftc`，没有解析，没有编译，也没有跑测试。
