# Cloud stubs — points history and statistics (ledger row 26)

Branch `ui/cloud-stubs-points`. Parent `origin/ui/next` `11e7c2c4559ee3a210fdcfacf8abee717c312ff9`.

Stub-ledger row 26 only (`origin/ui/stub-ledger` `0ad3cefa` `docs/release/stub-ledger.md`, not edited). The pass-market balance card no longer hard-codes `pointsDestination: nil`. `App/AppSession.swift` stays 8176 lines and `App/AppCompositionRoot.swift` stays 4307 lines. `Core/ChinaReviewedRouteCapability.swift` was not edited: `/api/points/list`, `/api/user/points/statistics`, and `/api/points/result_list` were already live and wired (996 / 622 / 0 / 374, wired 672). Journey, affiliate, bounty, and orient paths were not touched. `docs/release/contract-failing-baseline.txt` was not edited. `App/RegionalLaunchConfiguration.swift` was not edited. No redeem, withdraw, payout, or other write was added.

## Reads

The mini-program posts all three. Nothing here sends GET, and nothing sends `api/user/points/list` (that is the other, paged ledger).

| Endpoint | Method | Existing view |
|---|---|---|
| `/api/points/list` | POST, empty form, one full list | `WalletLedgerView` kind `.assetPoints` |
| `/api/user/points/statistics` | POST, no body | `ProfileWeeklyPointsSection` on the signed-in profile |
| `/api/points/result_list` | POST, empty form | `WalletPointsTasksView`, the ledger's existing tasks link |

`PassMarketPointsReadTransport` forwards only those three posts. Cart redeem, withdrawal, payout, a query string, and GET are refused. On the China production host the request still has to pass `ChinaReviewedRouteCapability.refuseUnwiredChinaProduction`. The transport is the same raw transport the pass-market reads already use (`composition.makeTransport()`), held off `AppSession` by `PassMarketPointsBridge`.

A missing points amount is an em dash (`—`, U+2014). A decoded `0` stays `0`. The points ledger hero and the after-balance line already used that mark. The change amount on a points row, the earn-rule value, and the done count now use the same mark when the field is missing, and they omit the points unit next to a missing change. Money rows still use the existing unknown label. Weekly statistics that omit `weekPoints` do not decode, so the existing section stays on its failure row instead of showing zero. The ledger does not add rows.

## Wiring

`PassMarketPointsRootModifier` sets `\.passMarketPointsDestination`. `PassMarketHost` passes that closure into the balance card. The card opens `WalletLedgerView(reader:kind: .assetPoints)`. With no modifier the closure stays nil and the card stays read-only. The profile's weekly section now uses `PassMarketPointsStatisticsReader` instead of the lease-gated `session.profileWeeklyPointsReader`. That session reader is unchanged and still refuses a read when no weekly-points lease is installed.

## Checks

`python3 tools/generate_project.py` registered the new Swift files. `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` passed. `python3 tools/contract_ratchet.py --check` reports the same one failure already present on the parent: `test_audit_tool_catalog_is_complete` for `App/HomeCityLocationConsentHost.swift` (`userDefaults`). That file was not edited, and `docs/release/contract-failing-baseline.txt` was not rewritten. The wallet source contracts (`test_wallet_number_localization`, `test_wallet_commerce_integration`) passed. This VM has no Swift compiler, so `Tests/CoreTests/PassMarketPointsReadsTests.swift` was not executed.

## 中文

只接账本第 26 行。通行证市集的积分卡片不再把 `pointsDestination` 写死为 nil。`AppSession` 仍是 8176 行，`AppCompositionRoot` 仍是 4307 行。`ChinaReviewedRouteCapability` 没有改：这三个路径本来就是已上线且已接线。没有兑换、提现、打款或其他写入。合同失败基线没有上调。

小程序这三个接口都是 POST。`/api/points/list` 进现有的积分流水（`.assetPoints`）。`/api/user/points/statistics` 进现有的每周积分段。`/api/points/result_list` 进流水页里原有的积分任务链接。不请求分页的 `/api/user/points/list`。未知积分是破折号「—」，解码出来的 0 仍是 0。积分变动、任务分值和完成次数缺字段时也是「—」，旁边不再带单位。金额流水仍用原来的「未知」文案。周统计缺 `weekPoints` 时整段解码失败，不显示成 0。本环境没有 Swift 编译器，新的 Core 测试没有在这里跑。
