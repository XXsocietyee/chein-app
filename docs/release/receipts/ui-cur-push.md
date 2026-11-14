# Subscribe-message taps

Handover 53. Branch `ui/cur-push`. Base `origin/ui/main` `9209d33cb2d7ceed6f95a1b9d90b556e531a63b0`.

Public source is hengyin `73f4f7be45aa5b49381baa2c1aff57e1b2245fad` (2026-11-13 9:05 PM Pacific): `chengyinhub-xcx/utils/subscribe.js`, `chengyinhub-admin/src/main/resources/application.yml` (`wx.subscribe`), `WxSubscribeMsgServiceImpl` landing pages, and `NotifyEvent`. A template is handled only when both the mini-program map and `application.yml` store a non-empty id. curl against TEST 8120 was **NOT RUN**. No payload was invented.

The tap still belongs to `MPNotificationTapRouter` (`page` only, `PushTapRouter`). `willPresent` is still not implemented. `AppSession`, `AppCompositionRoot`, and `RegionalLaunchConfiguration` were not edited. `ReviewedAreaSwitch` was not redeclared. Purchases, payout, and merchant writes on `www.chengyinhub.com` stay closed. The ledger screen is the existing read overview. The order list does not gain a pay button.

## Handled

| Type | Template id | Page in the send call | Screen |
| --- | --- | --- | --- |
| `signupSuccess` / `SIGNUP_SUCCESS` | `NfXW_QNj6Poy4GQj51heJ-LGJiljtJBkAqFlsnWdPuA` | `subpackageMember/order/order` | `ProfileOrdersView` |
| `activityStart` / `BEFORE_START` | `noH01EDe1vqpAFvWSwXMhyqSw1a4YHbP92CG7ehti54` | `subpackageMember/order/order` | `ProfileOrdersView` |
| `refund` / `REFUND` | `hrxJ8GaoNVNNjLBMOn2ZntnNzjxpBZvNqTcAoKjr1Xg` | `subpackageMember/order/order` | `ProfileOrdersView` |
| `coopInvited` / `COOP_INVITED` | `aC5iPgiluAkGT1LkQHT7-qVk_MmxnO9H-updKXyG6KM` | `pages/coop/list/index` | `CooperationBrowserView` received |
| `coopStatus` / `COOP_STATUS` | `Mc6LPLxOGodPlVbeUeyp09pc7wQoOL354MmUwedKr2c` | `pages/coop/list/index?tab=sent` | `CooperationBrowserView` sent |
| `recruit` / `RECRUIT` | `pVihLGRWi3uA4wGvA-Hv-NsuOGvtj1Ts3kV1GmU56Dw` | `subpackageA/pages/myproject/index` | `PublishingProjectsView` |
| `coopSettle` / `COOP_SETTLE` | `Z10x9KV0jciDbFGTS6javEjqz0abOi-ik6x_0e_pt-o` | `pages/merchant/ledger/index` | `MerchantLedgerSettlementOverview` |

## Skipped

| Type | Why no handler |
| --- | --- |
| `refundRejected` | `subscribe.js` has `fqsssX0TRhDO88wNbrAGVdhT4kMIUNK_qXXe0HNoqCk`. `application.yml` has no `tplRefundRejected`, and the sender has no method. The mini-program comment says it is not requested. |
| `clubInterest` / `CLUB_INTERESTED` | `tplClubInterest` is empty in both files. |
| `roamRecall` / `ROAM_RECALL` | `tplRoamRecall` is empty in both files. `pages/roam/index` is not routed. |
| `OFFICIAL_BROADCAST` | No `tplOfficialEvent` in `application.yml`. Official, merchant-home, and club-workbench pages are not routed. |
| `TEAM_STATUS` | `NotifyEvent` says in-app only. No subscribe template. |
| `AFTERCARE_PLATFORM_TAKEOVER` | `NotifyEvent` says in-app only. No subscribe template. |
| APNs / JPush types | Not in the public tree. The notify fanout mentions a missing JPush SDK and does not name a payload type. curl NOT RUN. |

## Checks

`python3 tools/generate_project.py` registers `App/SubscribeMessageTapScreens.swift`. `python3 tools/check_scaffold.py` PASS. `python3 tools/check_design_lint.py` PASS. This machine has no `swiftc`, so the Swift files were not parsed or tested.

Copy on the opened screens is the existing English and zh-Hans catalog. This change adds no new user-facing string.

## 中文

交接 53。分支 `ui/cur-push`，基线 `9209d33cb2d7ceed6f95a1b9d90b556e531a63b0`。

模板只认 hengyin 公开源码 `73f4f7be`（太平洋时间 2026-11-13 晚上 9:05）里小程序 `subscribe.js` 和 `application.yml` 都写了非空编号的那几条。没有请求 TEST 8120，curl **NOT RUN**，没有编造载荷。

点击仍走原来的 `MPNotificationTapRouter`，只读 `page`。没有改 `AppSession`、`AppCompositionRoot`、`RegionalLaunchConfiguration`，也没有重新声明 `ReviewedAreaSwitch`。正式域名上的购买、打款和商家写入仍关闭。订单列表没有新的支付按钮。账本打开的是原来的只读结算页。

已接通七类：报名成功、出发提醒、退款到账都打开订单列表；合作邀约打开收到的合作列表；邀约状态打开已发出列表；招募打开我的项目；结算到账打开商家账本。

跳过：退款被拒（前端有编号，后端 yml 没有这项，也没有发送方法）、俱乐部承接意向和漫游召回（编号为空）、官方广播（yml 没有 `tplOfficialEvent`）、队伍状态和售后转平台（注释写明只走站内信）、APNs / JPush（公开仓库里没有类型）。没有给这些类型加处理。

本机没有 `swiftc`，没有解析，也没有跑测试。界面文案用原有的英文和简体中文，没有新字符串。
