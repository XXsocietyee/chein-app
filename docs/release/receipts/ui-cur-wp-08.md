# WP-08 host tip, attribution, OTA channel code, landing SEO

Branch `cursor/wp-08-host-tip-fa87` from `origin/ui/main` `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46`. Spec read from `e1969026e9469669e165937013e0e4f5c61b4252` (`docs/completeness-2`), WP-08 section only. That commit is not the base.

`docs/release/completeness-matrix.csv` is not on `ui/main`. It was not imported. Row ids and status are listed here.

## Rows

| row | was | now | what landed |
|---|---|---|---|
| `OWN-C` | MISSING | DONE | `POST /api/host-tip/config`, `GET /api/host-tip/config/mine`. `HostTipConfigScreen` |
| `OWN-D` | MISSING | DONE | `POST /api/host-tip/prepare`, `POST /api/host-tip/intent/{id}/cancel`, `GET /api/host-tip/intent/mine`. `HostTipPlayerScreen`. `paymentSucceeded` stays false |
| `OWN-G` | MISSING | DONE | `GET /api/video-bounty/submission/{id}/attribution`, `GET /api/video-bounty/campaign/{id}/attribution`. Missing status is the word UNKNOWN. Unconfirmed counts are an em dash |
| `OWN-十六-12` | MISSING | DONE | same host-tip config, prepare, and intent/mine screens |
| `OWN-十六-13` | MISSING | DONE | `POST /api/channel/redeem`. `ChannelRedeemSheet` |
| `OWN-十六-14` | IN-PROGRESS | DONE | public catalog list was already present. `POST /api/content-landing/info` is now called from the catalog detail and `ContentLandingScreen` |
| `OWN-20.1` | MISSING | DONE | content-landing info, save, translation/save. City catalog list was already present |
| `OWN-20.2` | MISSING | DONE | `/api/channel/redeem` |
| `OWN-十八` | MISSING | DONE | rollup children C, D, G are the three that were open. Those three are implemented. The other five children were already DONE on the completeness snapshot and were not reopened |
| `OWN-十三-10` | MISSING | DONE | same C, D, G children |
| `OWN-十三-11` | MISSING | DONE | children 20.1 and 20.2 |

Rows still missing: none of these 11.

## Screens

Account → 主持小费 is always visible. It is not hidden when a parity binding is nil.

- Config: loading, empty, error, signed-out. Channel off keeps the switch grey and shows 暂不可开通. A 501 `CHANNEL_NOT_ENABLED` does not show 已保存.
- Player intents: loading, empty, error. Statuses CREATED, AWAITING_PAYMENT, PAID, CANCELLED, REFUNDED, CHANNEL_UNSUPPORTED stay distinct. Cancel is only offered for CREATED and AWAITING_PAYMENT. Prepare with payable false or 501 shows 收款暂未开通，已记录你的意向. A payable true response still shows 收款通道关闭，没有打开支付，也没有支付成功. There is no pay page.
- Attribution sheet on the video-bounty screen: loading, empty, error. UNBOUND and OWNER_NOT_SET use the named sentences. Counts render only when status is BOUND and confirmed is true. A literal 0 in that case stays 0. Any other case, including a JSON 0, is —.
- Channel redeem sheet: the idle copy stays on screen and says the provider is off until a code is submitted. PROVIDER_NOT_CONFIGURED and REFUND_DECISION_POINT_MISSING show 该兑换码暂不可兑换. Success shows 已兑换, product name, seat count, valid from, valid to, and registration number. 去使用 reveals the registration number. It does not open pay or scan. `replayed` true does not play a second success state.
- Landing editor: loading, empty, error, signed-out. Null eligibility is undeclared. A 409 keeps the typed version and does not retry. Sending status APPROVED is refused by the lease and is not in the save body. After a successful translation save of a previously APPROVED row, the screen says 译文已改，需要重新审校. The SEO note says sitemap, hreflang, and robots are not live.

English and zh-Hans keys are in `Resources/Localizable.xcstrings`.

## Grants

The same eleven paths are `ChinaReviewedRouteCapability.hostTipSurfaceGrant` and `ReviewedProductionFormMutationRoute.wp08Paths` inside `ReviewedPlayerWriteLeases`. `wiredPatternCount` stays 677. `ReviewedAreaSwitch` is not redeclared. `moneyPayments` and `payout` stay false for `www.chengyinhub.com`. `/api/registration/pay`, pay/app, withdrawal, wallet withdraw, coupon usability, host-tip pay, and video-bounty payout are not in the grant and are not admitted. WP-01, WP-02, and WP-05 were not implemented.

`GET /api/host-tip/intent/received` and the back-office landing review desk are not in the WP-08 route list, so they were not added.

`App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` were not edited. `docs/release/contract-failing-baseline.txt` was not raised.

## Checks

`python3 tools/generate_project.py` completed. `python3 tools/check_scaffold.py` PASS. `python3 tools/check_design_lint.py` PASS.

`swiftc` is not installed on this VM (`type swiftc` → not found). `swiftc -parse` did not run. No Swift compile and no test execution. This is not a typecheck result.

## 中文

分支 `cursor/wp-08-host-tip-fa87`，基线 `a2a9d82e78459df7c22c5545e2c5bf19f2f0ff46`。只读了 completeness 提交里 WP-08 那一节。`ui/main` 上没有 `completeness-matrix.csv`，没有把整表引进来。

十一行都有对应客户端调用和可见界面：主持小费配置与意向、视频归因、渠道兑换码、落地页 info/save/译文。501 与通道关闭显示暂不可用，不显示支付成功。未确认的归因数字是破折号，缺状态是 UNKNOWN。兑换码入口一直可见，服务商关闭时写明暂不可兑换。支付和提现仍走 `ReviewedAreaSwitch`，在 `www.chengyinhub.com` 上保持关闭。

本机没有 `swiftc`，没有解析，没有编译，也没有跑测试。没有抬高 contract-failing baseline，没有改 `AppSession`、`AppCompositionRoot`、`RegionalLaunchConfiguration`。
