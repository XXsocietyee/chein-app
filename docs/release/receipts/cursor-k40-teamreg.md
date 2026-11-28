# cursor/1128-k40-teamreg

Base `ui/combined-r7` @ `a7c956335` (pin held; tip had not moved). Lane: teams, registration, waitlist, check-in, official events. Re-checked against that tree. App wiring and Core only. No restyle. No hengyin change. Money switches unchanged. `App/AppSession.swift` stays 7977 lines. `RuntimeDependencyConfiguration` init order was not touched.

Gates on this tree: `check_scaffold.py` pass (no new files, so `generate_project` was not run), `check_a11y_lint.py` 0 new, `contract_ratchet.py --check` 46 failing / baseline 46 / new 0. This Linux pod has no `swiftc` or `xcodebuild`, so the new `VerificationCodePresentationTests` cases were not executed here.

## Closed here

| Row | Status | What changed |
|---|---|---|
| G-05 | fixed | Guest 立即报名 presents `LoginView` over the activity and, after sign-in, opens the registration sheet. A 401 on `api/activity/info` shows sign-in (`auth.expired` / `auth.signIn`) instead of 活动详情无法打开. |
| G-09 | fixed | A ticket entry code reissues once in the last 30s (15s cooldown). At expiry it still clears and waits for a manual retry; city vouchers are unchanged. While the code is showing, `api/registration/info` is re-read every 8s. A finished pass (`OrderPassAvailability.complete`) clears the code and the row says the ticket is used. A verified chapter with an open entitlement keeps the code. |

## Already closed on combined-r7

| Row | Status | Evidence |
|---|---|---|
| T-01 actions, T-02 join, T-03 quit/disband/kick, T-07 join-mode, T-03+ receipt | already fixed @ `48f44e825` | `makeTeamCoordinator` builds `TeamHTTPService` with `TeamCommandWriter`. Join / quit / kick / disband / join-mode post `api/team/command`. Only `data.state == APPLIED` is success. |
| T-04 wallet → team page | already fixed @ `b7aa64a86` | `TicketWalletTeamView` pushes `TeamDetailView(lookup: .id)`. |
| T-05, T-08, T-09 (CN) | already fixed @ `a7c956335` | Apply, withdraw, and nearby reads were already live for China. |
| T-06 REJECTED shown as success | already fixed @ `48f44e825` | `NearbyTeamService.decodeWrite` treats command `REJECTED` as rejected and keeps the row. |
| G-01a detail refresh + 查看门票 | already fixed @ `7270c627f`, `576660fc6` | Registration sheet `onDismiss` reloads the activity. Free success offers the ticket. |
| G-01b paid registration, pay/app, Stripe wire, Alipay, re-pay | already fixed @ `5880f1880`, `eea73b432`, `7332e1b33`, `928cbea98`, `1d05b0d90` | Paid create sends `payChannel=APP` while `ReleaseMoneyWriteSwitch.paymentEnabled` is on. In-app pay uses `.app`. Stripe is form `id` and cents. Alipay is `APP_ALIPAY`. Order re-pay has the Pay-with row; 审核支付 is gone. One `api/registration/info` read decides paid / cancelled / checking. |
| G-02 waitlist | already fixed @ `c6f13a174` | Release issues the waitlist lease. The sheet uses `registrationWaitlistService`, which falls through to that lease. Wallet refreshes on read-back. |
| G-03a per-account ticket cap | already fixed @ `a7c956335` | Superseded by owner ruling C-22. No code gap. |
| G-03b points on FREE_EXPLORE | already fixed @ `a7c956335` | Toggle follows `pointsUsable`. |
| G-04 post-refund link | already fixed @ `ee49714c9` | Refunded / cancelled activity orders link back to the activity. No rebooking. |
| G-10a official reads + signup | already fixed @ `a7c956335` | List, detail, mine, inbox, and signup already send. |
| G-10b arrivals, complete, inbox accept/decline | already fixed @ `2c3d861cd` | `sessionDependencies` supplies `officialActionApproval` for the player participation routes. Merchant stays off. |
| PlayStoreDay 扫码签到 (plan contradiction, func row 532) | already fixed @ `e983dce01` | `PlayStoreDayService` is built with `gates: .playStoreDay` (proof and consent writes on). |

`Fix1128bTeamRegCompositionTests` builds `RegionalLaunchConfiguration.shippedComposition` (reviewed deployment) for the team command writer, the waitlist lease, the order device-payment flag, and official participation.

## Owner-only rows (not changed)

| Row | Why it stays |
|---|---|
| G-06 self-play checkout | `ReleasePlayerServiceAuditTests` pins `selfPlayPayment` nil. Turning the checkout on would fight that gate. Money switches were not changed. |
| G-07 activity list filter | The plan marks it low priority and notes the MP has no product-type or date-range sheet. That is a new surface, not a wiring line. |
| G-08a pass purchase | `virtualGoodsEnabled` stays off. |
| G-08b bundle refund / transfer | The server refuses the writes (`moneyWriteDisabled`). Money switches were not changed, and hengyin was not opened. |

Remainders on rows whose player loop is already fixed, still owner-only:

| Remainder | Why it stays |
|---|---|
| T-01 / T-05 / T-08 / T-09 US | P1-25. Team read and nearby leases stay `market == .china`, the same gate as the rest of US roam. |
| T-02 share link | P1-1. The share is still the code. A universal link needs the owner's associated domain. |
| G-01b WeChat SDK binary | The pay path hands APP params to `WeChatSDKPaymentAdapter`. Linking `WechatOpenSDK` is `QUESTIFY_WECHAT_PAYMENT_SDK_APPROVED`. |

ADA registration rows are not wiring. The consent button staying disabled until it is ticked matches the later design ruling. The registration bar title cap is the system bar cap plus Large Content Viewer. Phone masking, the ¥ / CN¥ split, and a face pile on Registered are visual and were left alone.

Roam POI 打卡 (`R-10b`, `POST /api/roam/checkin`) is the roam lane and was not edited.

## Counts

2 fixed / 19 already fixed / 4 owner-only

The four owner-only rows are G-06, G-07, G-08a, and G-08b. US leases, the invite share link, and the WeChat SDK binary are remainders on rows whose player loop is already fixed.
