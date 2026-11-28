# K40 notifications, Live Activities, widgets

Branch `cursor/1128-k40-notifications` from `origin/ui/combined-r7` pin `a7c956335e765f618f7bc86480aa523015bc6e30`. Behaviour and wiring only. No layout restyle.

Rows rechecked / already fixed / closed this run: **16 / 8 / 4**. Three stay blocked on a missing backend. One ADA row is a layout restyle and was left alone. P1-9 is the same gap as M-11b. The audience-counts part of P1-12 is the same fix as C-06 and functions row 374.

## Closed this run

`AppSession.squareGovernance()` now builds `SquareNotificationLease.service`. Reads, mark-read and appeal turn on only while `ChinaReviewedRouteCapability` admits all three of `/api/v1/community/notifications`, `/api/v1/community/notifications/{}/read` and `/api/v1/community/appeals`. Preference writes, comment approve and comment delete stay off. A dormant `SquareGovernanceService` (the default init) still has reads and every grant off. `ReportProgressUnreadReader.markOpened()` still returns false and sends nothing.

The China player write lease already admits a GET of `api/v1/community/notifications` and a POST of mark-read or appeal that carries `requestId`. This change does not add a firewall path.

| Audit | Was | Now | Proof |
|---|---|---|---|
| Plan M-11a | Reads off, mark-read has no grant, 我的举报 badge stays nil | Lease on for list, mark-read, appeal | `Tests/CoreTests/SquareNotificationLeaseTests.swift`, `Tests/AppUnitTests/K40NotificationLeaseTests.swift` |
| Functions 300 | Audit said Works; plan says the badge is nil because reads are off | Unread count is 1 for an unread `REPORT_*` row and ignores a read report and an unread LIKE | Same core test, `ReportProgressUnreadReader.unreadCount` |
| Functions 301 | Mark-read path exists but the production grant excludes it | `POST api/v1/community/notifications/81/read` body `{requestId}` is built and the player lease admits it | Same tests |
| Functions 456 帖文处置与申诉 | Entry calls `squareGovernance()`; the appeal button is disabled unless `service.allows` | Appeal is in the lease, so the existing button at `App/SettingsPostGovernanceView.swift:232` can enable. Preferences stay disabled | `K40NotificationLeaseTests` asserts `.appeal` is allowed and `.preferences` is not |

`App/AppSession.swift` stays at 7977 lines. The devices, sensors, artworkHosts initializer order was not edited. `PlayerLaunch.merchantCenterEnabled` was not edited. `ReleaseMoneyWriteSwitch` was not edited. No new `String(localized:)`.

## Already fixed

| Audit | Status | SHA / evidence |
|---|---|---|
| Plan C-06, functions 374, P1-12 audience-counts | `api/club/event-notification/audience-counts` is on `MPFirstClubWriteRoute.governancePaths` with `ReadShape(ids: ["clubId"], optional: ["activityId"])`. Send, preview and status were already admitted. The unlabeled fallback in `App/ClubNotificationAudienceView.swift` remains for a non-fatal counts error | `b43ea6ed4149edf31ad512fcdeec97337232f865` (`MPFirstClubWriteRouteR10Tests.testAdmitsOwnerReadsOnTheirExactBody`) |
| Plan M-11c local Live Activities and widgets | Walk and play activities, the plan activity, the widget extension, `NSSupportsLiveActivities`, App Group home/lock/StandBy widgets, `widgetURL` and `ProgressView` are present. `QuestLiveActivityCenter` still requests `pushType: nil` | Live Activity `a32887723906f9df60188b8a5bbb8713e6d911cd`; plan activity and token client `4882db52f6e67385b8837179e00251a98cc8b251`; widgets `702fc050081bce8ce3e5159ad4bcdf24f634c01b`; widgetURL / ProgressView `b5ddf753645f306da285582efc3cc5d416944817` |
| Plan M-12c, functions 132, functions 303 | Local tap routing is present at the pin: `MPNotificationTapRouter` reads `page`, skips City 稍后 and dismiss, and calls `receiveNativeIntent`. A remote tap cannot arrive until M-11b | `App/MPParityDeepLinkEntry.swift:117-178` at `a7c956335` |
| Functions 304 | Foreground IM posts `foregroundMessageArrived` and shows the island or the system banner | `App/MPParityDeepLinkEntry.swift:152-169` at `a7c956335` |
| Functions 468 | Channel mute, read and preference still go to `api/im/mute`, `api/im/read` and `api/im/notify-pref`. The delivery log is `api/im/notify-log` (`Core/NativeChannelNotificationService.swift:131,145-147`). The audit's `api/im/device/attempts` is not the path this screen calls | Re-checked at `a7c956335` |

## Blocked (hengyin 404)

`gh api repos/XXsocietyee/hengyin` returned `404 Not Found`. `git ls-remote https://github.com/XXsocietyee/hengyin.git` returned `remote: Repository not found.` No backend branch was created. No `registerForRemoteNotifications`, no device-token upload, no APNs key, no SQL, and no firewall entry for a route the server does not have.

These rows stay open for that reason: plan M-11b / P1-9, functions 302, functions 467 (settings 通知权限 still only asks `UNUserNotificationCenter` for local permission). Push-to-start for M-11c stays on the same block. `Config/Questify.entitlements` already has `aps-environment` = `development`; that entitlement alone does not register a device.

### Device token

The app has no remote-notification registration and no upload body. `Core/DevicePushRegistrationLifecycle.swift` stores fixture tokens only (`fixtureTokenPrefix` is the literal `fixture-`). There is nothing to POST until a device-token route exists. This lane does not invent one.

### Live Activity token the app already builds

`QuestPlanActivityTokenService` (`Core/QuestPlanActivityTokenService.swift:11`) builds `POST api/live-activity/token` and `QuestPlanActivityCenter` will call it when a token exists. `ChinaReviewedRouteCapability` does not list that path, and the player write lease does not admit it, so the composition refuses the call. The path stays refused.

Auth header: `Authorization: <session token>`. `Accept` and `Content-Type` are `application/json`. Body keys are sorted. `token` is lowercase hex of the APNs token bytes (`QuestPlanActivityTokenRequest.hex`) and is absent for `ENDED`. `planKey` is absent for `PUSH_TO_START`. `activityId` is ActivityKit's local id for `ACTIVITY` and `ENDED`.

```json
{
  "activityId": "<ActivityKit id>",
  "attributesType": "QuestPlanActivityAttributes",
  "bundleId": "com.chengyinhub.chengyinApp",
  "environment": "SANDBOX",
  "locale": "zh_CN",
  "planKey": "offer:<uuid>",
  "scope": "ACTIVITY",
  "token": "<APNs hex>"
}
```

`scope` is one of `PUSH_TO_START`, `ACTIVITY`, `ENDED`. `environment` is `SANDBOX` in DEBUG and `PRODUCTION` otherwise (`App/QuestPlanActivityCenter.swift:78-81`). `locale` is `Locale.current.identifier`. `bundleId` is `Bundle.main.bundleIdentifier`. `planKey` is `offer:<uuid>`, `team-status:<teamId>`, `club-event:<eventId>`, or a server key. A well-formed body requires a non-empty token for `PUSH_TO_START` and `ACTIVITY`, a nil `planKey` for `PUSH_TO_START`, and a non-empty `planKey` for `ACTIVITY` and `ENDED`.

The reply the client accepts is an envelope whose `code` is 200 and whose HTTP status is 2xx (`QuestPlanActivityTokenReply`). The server contract in `docs/release/receipts/comp-r1-island-steps.md` says the write is idempotent by `(account, scope, attributesType, planKey, activityId)` and the newest token replaces older ones.

Push-to-start, which this app does not send (it only registers the token), is APNs `apns-push-type: liveactivity`, topic `<bundle>.push-type.liveactivity`, `event: "start"`, `attributes-type: "QuestPlanActivityAttributes"`, `attributes: {kind, planKey, title, targetID}`, `content-state` the `QuestPlanContent` fields, optional `alert`, same `planKey` for every invited member. Updates are `event: "update"` or `"end"` to the per-activity tokens. Do not send `tucked`.

## Skipped

ADA `wave-today-club` asks for a widget frame versus an in-app event card. That is a layout restyle, outside this lane.

## Gates

No Swift compiler in this environment. The new tests are the request-shape proof CI compiles.

| Check | Result |
|---|---|
| `python3 tools/check_appsession_ratchet.py` | PASS, `App/AppSession.swift` 7977 |
| `python3 tools/check_scaffold.py` | PASS |
| `python3 -B tools/check_a11y_lint.py` | PASS, 0 new |
| `python3 tools/check_design_consistency.py` | PASS |
| `python3 -B tools/contract_ratchet.py --check` | 46 failing, baseline 46, new 0, fixed 0 |
