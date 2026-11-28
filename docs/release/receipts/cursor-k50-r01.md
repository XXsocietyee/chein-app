# K50-R1 remote push

Branch `cursor/1128-k50-r01` from `origin/ui/combined-r7` pin `d5702393c9ba984dbceb2d5a7ecd978fb8951de3`. Client path only. No APNs auth key, no SQL, no deploy, no `xcodebuild`.

## Wired (no APNs key)

| Piece | Where | What it does |
|---|---|---|
| Device-token upload request shape | `Core/DevicePushTokenUpload.swift` | `POST api/device/push-token`. `Authorization` is the session token. `Accept` and `Content-Type` are `application/json`. Body keys are sorted. |
| Settings 通知权限 | `App/NativeNotificationPermissionNudgeView.swift` | After the system permission is read or changes, the screen calls `RemotePushRegistrationClient.consider`. The settings row still only opens this screen. |
| Client path for `registerForRemoteNotifications` | `App/RemotePushRegistrationClient.swift` | The call sits behind `guard uploadAdmitted`. The production default is `DevicePushTokenUpload.compositionAdmitsUpload()`. |

```json
{
  "bundleId": "com.chengyinhub.chengyinApp",
  "environment": "SANDBOX",
  "token": "<64 lowercase hex digits, 32 token bytes>"
}
```

`environment` is `SANDBOX` or `PRODUCTION`. The fixture label `PRODUCTION_LABEL` and a `fixture-` token are not this body. A well-formed body needs a non-empty bundle id with no whitespace. The reply this client would accept is not sent: `deliverableRequest` returns nil while the composition refuses the path.

`App/AppSession.swift` was not edited (7976 lines, ceiling 7977). The devices, sensors, artworkHosts initializer order was not edited. `PlayerLaunch.merchantCenterEnabled` stays false in Release. `ReleaseMoneyWriteSwitch` was not edited. No new `String(localized:)`.

## Refused path (register is not called)

`POST /api/device/push-token` is not in `ChinaReviewedRouteCapability` (`mark` is nil, `admitsChinaProductionCall` is false). No player-write grant lists it, so `ReviewedProductionFormMutationRoute.acceptsPlayerWrite` does not cover it, and `CompositionHTTPTransport` refuses the POST (`APIError.notConfigured`). It is not a money route (`ReleaseMoneyWriteSwitch.blocks` is false) and the money switches were not opened to admit it.

`RemotePushRegistrationClient.consider` returns before `registerForRemoteNotifications` while that admission is false, and it does not touch `UIApplication` on that path. Settings 通知权限 still asks `UNUserNotificationCenter` for local permission. No app delegate is installed, because there is no device token to upload.

`Config/Questify.entitlements` keeps `aps-environment` = `development`. That entitlement does not register a device.

## Owner-only

The APNs auth key is not in the app. The placeholder name is `chein-apns-unset`, under the backend environment name `QUESTIFY_APNS_AUTH_KEY` (`docs/release/owner-values.md`). The app does not read it. The real key stays with the owner and is not committed.

## Gates

No Swift compiler was run (`xcodebuild` was not used). The request shape and the refused call are source-checked.

| Check | Result |
|---|---|
| `python3 tools/check_scaffold.py` | PASS. `App/AppSession.swift` 7976, ceiling 7977, file not edited |
| `python3 -B tools/check_a11y_lint.py` | PASS, 0 new |
| `python3 -B tools/contract_ratchet.py --check` | 46 failing, baseline 46, new 0, fixed 0 |
