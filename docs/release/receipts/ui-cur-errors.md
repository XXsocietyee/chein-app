# ui-cur-errors

Branch `ui/cur-errors` from `origin/ui/main` `6feee423adc8962d7613f8ba93b77ffdc93ea1c4`.

## Hengyin commits read

- `master` `73f4f7be45aa5b49381baa2c1aff57e1b2245fad` — `AjaxResult.java`, `HttpStatus.java`, `chengyinhub-ui/src/utils/errorCode.js`, `PlayCommandErrorContract.java`, `ArriveLocationGuard.java`, `ArriveLocationGuardPolicy.java`.
- `integration/backend-app-r2` `5c2017eefaafa1e13377bc82fc78db344e8c994d` — `CashPayoutSwitch.java`, `MiscMoneySwitch.java`, `ApiNonCashRewardController.java`, `ApiPlayerGapsController.java`, `ApiMiscGapController.java`, `ApiChannelGapController.java`, `ChannelWebhookInboundService.java`, `ChannelWebhookService.java`.

No SSH. No TEST host. No curl. Swift was not run on this machine.

`FEATURE_CLOSED`, `CASH_CLOSED`, `ROUTE_EGG_OFFLINE`, and the `WEBHOOK_` error codes below are not on hengyin `master` at that commit. They are on `integration/backend-app-r2` at the commit above. Messages are the next step stated next to those constants, or the arrival next-step copy already in `Resources/PlayRecovery.xcstrings`.

## Presentation

The existing `BackendErrorCatalog` is the map. No second error enum. `playerFacing` shows `—` for a blank value, `0`, or the word `unknown`. The machine code `UNKNOWN` stays its own sentence. An unknown machine code stays the generic sentence and does not reveal the raw code.

`paymentSucceeded` takes the four area flags as arguments. Core does not reference `ReviewedAreaSwitch` and does not import App. `FEATURE_CLOSED` and `CASH_CLOSED` return false even when the flags are true. Any closed money, payout, merchant-write, or password-login flag also returns false. The function does not report that money moved. Pledge cash refusals use that function and show the catalog sentence. The production host `www.chengyinhub.com` still fails `ReviewedAreaSwitch` for those four flags.

## Mapped in this change

Statuses read from `HttpStatus` and added: `501`, `601`.

Codes:

| Code | Where it was read |
|---|---|
| `ADVANCED_FIRST` | `PlayCommandErrorContract` |
| `ANSWER_WRONG` | `PlayCommandErrorContract` |
| `ARRIVE_ACCURACY_INVALID` | `ArriveLocationGuard.ACCURACY_INVALID` |
| `ARRIVE_ACCURACY_LOW` | `PlayCommandErrorContract` |
| `ARRIVE_ACCURACY_MISSING` | `ArriveLocationGuard.ACCURACY_MISSING` |
| `ARRIVE_COORD_NOT_CONFIGURED` | `PlayCommandErrorContract` |
| `ARRIVE_FIRST` | `PlayCommandErrorContract` |
| `ARRIVE_GUARD_SPEED` | `ArriveLocationGuardPolicy.SPEED` |
| `ARRIVE_GUARD_THROTTLE` | `ArriveLocationGuardPolicy.THROTTLE` |
| `ARRIVE_GUARD_WINDOW_DISTANCE` | `ArriveLocationGuardPolicy.WINDOW_DISTANCE` |
| `ARRIVE_LOCATION_INVALID` | `PlayCommandErrorContract` |
| `ARRIVE_LOCATION_MISSING` | `PlayCommandErrorContract` |
| `ARRIVE_LOCATION_STALE` | `PlayCommandErrorContract` |
| `ARRIVE_NOT_RECORDED` | `PlayCommandErrorContract` |
| `ARRIVE_TOO_FAR` | `PlayCommandErrorContract` |
| `CASH_CLOSED` | `ApiNonCashRewardController.rejection` (message token; `errorCode` becomes `FEATURE_CLOSED`) |
| `CHAPTER_REDEEMED` | `PlayCommandErrorContract` |
| `CONFIG_INVALID` | `PlayCommandErrorContract` |
| `EVENT_UNKNOWN` | `ChannelWebhookService.events` |
| `FEATURE_CLOSED` | `CashPayoutSwitch.FEATURE_CLOSED`, `MiscMoneySwitch.closed` |
| `GUILD_FORBIDDEN` | `ChannelWebhookService.manage` |
| `INTENT_ACTION_REUSED` | `PlayCommandErrorContract` |
| `INTENT_INPUT_INVALID` | `PlayCommandErrorContract` |
| `INTENT_PENDING` | `PlayCommandErrorContract` |
| `INTENT_SCOPE_DENIED` | `PlayCommandErrorContract` |
| `INTENT_SESSION_ENDED` | `PlayCommandErrorContract` |
| `INTENT_SESSION_MISMATCH` | `PlayCommandErrorContract` |
| `INTENT_STALE_STATE` | `PlayCommandErrorContract` |
| `INVALID_INPUT` | `ApiNonCashRewardController.status` |
| `NODE_DELISTED` | `PlayCommandErrorContract` |
| `NODE_NOT_FOUND` | `PlayCommandErrorContract` |
| `NOT_CONFIRM` | `ApiNonCashRewardController.status` |
| `NOT_FOUND` | `ApiNonCashRewardController.status` |
| `PUZZLE_STATE_UNAVAILABLE` | `PlayCommandErrorContract` |
| `REVISION_CONFLICT` | `ChannelWebhookService.requireRevision` |
| `ROUTE_EGG_OFFLINE` | `ApiPlayerGapsController.EGG_OFFLINE` |
| `ROUTE_LOCKED` | `PlayCommandErrorContract` |
| `SCAN_CODE_AMBIGUOUS` | `PlayCommandErrorContract` |
| `SCAN_CODE_EXPIRED` | `PlayCommandErrorContract` |
| `SCAN_CODE_INVALID` | `PlayCommandErrorContract` |
| `SCAN_CODE_NODE_MISMATCH` | `PlayCommandErrorContract` |
| `SCAN_CODE_USED` | `PlayCommandErrorContract` |
| `SENSOR_REJECTED` | `PlayCommandErrorContract` |
| `STORE_SCAN_REQUIRED` | `PlayCommandErrorContract` |
| `TASK_REQUIRED` | `PlayCommandErrorContract` |
| `TEAM_LEAD_REQUIRED` | `PlayCommandErrorContract` |
| `WEBHOOK_BODY_INVALID` | `ChannelWebhookInboundService` reason `BODY_INVALID` |
| `WEBHOOK_BODY_TOO_LARGE` | `ApiChannelGapController.inbound` |
| `WEBHOOK_CHANGE_INVALID` | `ChannelWebhookService.name` |
| `WEBHOOK_CHANNEL_UNAVAILABLE` | `ChannelWebhookInboundService` reason `CHANNEL_UNAVAILABLE` |
| `WEBHOOK_CONTENT_BLOCKED` | `ChannelWebhookInboundService` reason `CONTENT_BLOCKED` |
| `WEBHOOK_CRYPTO_UNAVAILABLE` | `ChannelWebhookService.requireCrypto` |
| `WEBHOOK_ENDPOINT_PAUSED` | `ChannelWebhookInboundService` reason `ENDPOINT_PAUSED` |
| `WEBHOOK_FORBIDDEN` | `ChannelWebhookService.manage` |
| `WEBHOOK_INBOUND_UNAVAILABLE` | `ChannelWebhookService.inboundUnavailable` |
| `WEBHOOK_IP_NOT_ALLOWED` | `ChannelWebhookInboundService` reason `IP_NOT_ALLOWED` |
| `WEBHOOK_NONCE_INVALID` | `ChannelWebhookInboundService` reason `NONCE_INVALID` |
| `WEBHOOK_NOT_FOUND` | `ChannelWebhookInboundService`, `ChannelWebhookService.notFound`, `ApiChannelGapController` |
| `WEBHOOK_PAUSED` | `ChannelWebhookService.requireActive` |
| `WEBHOOK_RATE_LIMITED` | `ChannelWebhookInboundService` reason `RATE_LIMITED` |
| `WEBHOOK_REPLAYED` | `ChannelWebhookInboundService` reason `REPLAYED` |
| `WEBHOOK_RESULT_UNKNOWN` | already in the catalog; the sentence now says to check the original delivery |
| `WEBHOOK_SECRET_UNRECOVERABLE` | `ChannelWebhookInboundService` reason `SECRET_UNRECOVERABLE` |
| `WEBHOOK_SIGNATURE_INVALID` | `ChannelWebhookInboundService` reason `SIGNATURE_INVALID` |
| `WEBHOOK_TIMESTAMP_OUT_OF_WINDOW` | `ChannelWebhookInboundService` reason `TIMESTAMP_OUT_OF_WINDOW` |

Exact message added: `途中彩蛋已下线` from `ApiPlayerGapsController.collectEgg`.

`HttpStatus` values read and not added, because they are not errors: `200`, `201`, `202`, `204`, `301`, `303`, `304`. `errorCode.js` `401`, `403`, `404` were already mapped. Its `default` key is not a code.

## Unseen

These names appear in this app and were not in a file opened for this map, so they are not mapped:

- `WEBHOOK_CONTEXT_ENDPOINT_APPROVAL_UNAVAILABLE`
- `WEBHOOK_CONTEXT_UNAVAILABLE`
- `WEBHOOK_CURRENT_CHANNEL_SOURCE_UNAVAILABLE`
- `WEBHOOK_CURRENT_MANAGEMENT_CONTEXT_UNAVAILABLE`
- `WEBHOOK_EVENT_CATALOGUE_UNAVAILABLE`
- `WEBHOOK_NATIVE_RBAC_AUTHORIZATION_VERSION_SOURCE_UNAVAILABLE`
- `WEBHOOK_NATIVE_SCOPE_RBAC_FACTORY_UNAVAILABLE`
- `WEBHOOK_READ_UNAVAILABLE`
- `WEBHOOK_REAL_CHANNEL_MANAGEMENT_CONTEXT_UNAVAILABLE`
- `WEBHOOK_REGISTERED_EVENT_CATALOGUE_UNAVAILABLE`
- `WEBHOOK_REQUEST_REJECTED`
- `WEBHOOK_REVIEWED_ENDPOINT_APPROVAL_UNAVAILABLE`
- `WEBHOOK_ROUTE_INVALID`
- `WEBHOOK_RUNTIME_FACTORY_UNAVAILABLE`
- `WEBHOOK_STORAGE_OR_SOURCE_UNAVAILABLE`

`REVIEW_REQUIRED` in `ChannelWebhookInboundService.accept` is a log reason on a result whose `errorCode` is null. It is not mapped.
