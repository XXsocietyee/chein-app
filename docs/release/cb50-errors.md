# CB50 error catalog

Base: `origin/rc/20261108`. This map covers backend error codes and messages the client already compares or stores in `Core/` and `App/`. It does not add an endpoint, and it does not treat a gap-report quotation as a new code.

Lookup is local. `BackendErrorCatalog.sentence` does not read the base URL and does not send a request.

1. A non-empty code is matched after trimming. A known code returns its sentence. An unknown code returns the generic sentence below and does not reveal the raw code or the server message, even when that message is known.
2. A blank code may use one of the numeric statuses listed below. An unknown status is the same generic sentence.
3. With no code and no status, the exact trimmed message is matched. A longer sentence that only contains a known phrase stays generic. Substring classifiers such as `权限` and `登录` are not messages.
4. `UNKNOWN` is a known outcome token. It is not the generic sentence.

Generic sentence, catalog key `backendError.unknown`:

- English: Something went wrong. Please try again.
- 简体中文: 出了点问题，请重试。

`BackendErrorCatalog.requireConfiguration(baseURL:realm:)` throws `APIError.notConfigured` when the base URL or the realm is empty or whitespace. That throw is the whole body of the function, so no request is created. A non-empty pair returns without creating a request. `Config/Base.xcconfig` still leaves `QUESTIFY_API_BASE_URL` and `QUESTIFY_SESSION_REALM` empty. Password login, bank-card withdrawal, and virtual goods stay off. These sentences do not enable those writes. Version stays 0.1.0 (1).

The same pairs are in `Resources/BackendErrorCatalog.xcstrings` and `Core/BackendErrorCatalog.swift`.

## Statuses

| Token | Catalog key | English | 简体中文 |
|---|---|---|---|
| `2` | `backendError.status.2` | Your session has expired. Please sign in again. | 登录已过期，请重新登录。 |
| `400` | `backendError.status.400` | That request was not accepted. Check it and try again. | 请求未被接受，请检查后再试。 |
| `401` | `backendError.status.401` | Your session has expired. Please sign in again. | 登录已过期，请重新登录。 |
| `403` | `backendError.status.403` | You don't have permission to do that. | 你没有权限执行此操作。 |
| `404` | `backendError.status.404` | That item was not found. | 未找到对应内容。 |
| `405` | `backendError.status.405` | That request was refused. | 请求被拒绝。 |
| `408` | `backendError.status.408` | The result is still unknown. Please try again later. | 结果尚未确定，请稍后再试。 |
| `409` | `backendError.status.409` | This item changed. Refresh and try again. | 内容已变化，请刷新后再试。 |
| `410` | `backendError.status.410` | That item is no longer available. | 该内容已不可用。 |
| `413` | `backendError.status.413` | That request is too large. | 请求过大。 |
| `415` | `backendError.status.415` | That request isn't in a supported format. | 请求格式不受支持。 |
| `422` | `backendError.status.422` | That request was not accepted. | 请求未被接受。 |
| `426` | `backendError.status.426` | This app version is no longer supported. Update the app before continuing. | 当前应用版本已不受支持，请更新应用后再继续。 |
| `429` | `backendError.status.429` | Too many attempts. Please wait and try again. | 操作过于频繁，请稍后再试。 |
| `500` | `backendError.status.500` | The service couldn't complete that. Please try again. | 服务未能完成此操作，请重试。 |
| `503` | `backendError.status.503` | The service is unavailable right now. Please try again. | 服务暂不可用，请重试。 |
| `520` | `backendError.status.520` | The original result is still unknown. | 原命令结果仍未知。 |
| `501` | `backendError.status.501` | That action isn't implemented yet. Try a different action. | 此接口尚未实现，请改用其他操作。 |
| `601` | `backendError.status.601` | The service sent a warning. Read it and try again. | 服务返回了警告，请查看后再试。 |

## Codes

| Token | Catalog key | English | 简体中文 |
|---|---|---|---|
| `ADVANCED_FIRST` | `backendError.code.ADVANCED_FIRST` | Finish this stop's task before arriving. | 请先完成这一站的任务，再记录到达。 |
| `ANSWER_WRONG` | `backendError.code.ANSWER_WRONG` | That answer wasn't accepted. Submit a new answer. | 答案不正确，请提交新的答案。 |
| `ARRIVE_ACCURACY_INVALID` | `backendError.code.ARRIVE_ACCURACY_INVALID` | Locate again. This is not a cheating verdict. | 请重新定位。这不是作弊判定。 |
| `ARRIVE_ACCURACY_LOW` | `backendError.code.ARRIVE_ACCURACY_LOW` | Move into the open and locate again. A weak signal does not widen the stop's area. | 请到开阔处重新定位。信号差不会放宽这一站的范围。 |
| `ARRIVE_ACCURACY_MISSING` | `backendError.code.ARRIVE_ACCURACY_MISSING` | Locate again so the reading includes its accuracy. This is not a cheating verdict. | 请重新定位，让读数带上精度。这不是作弊判定。 |
| `ARRIVE_COORD_NOT_CONFIGURED` | `backendError.code.ARRIVE_COORD_NOT_CONFIGURED` | Trying again will not help. The organiser needs to fix this stop. | 重试不会成功，需要组织者修正这一站。 |
| `ARRIVE_FIRST` | `backendError.code.ARRIVE_FIRST` | Record your arrival at this stop before answering. | 先记录到达这一站，再作答。 |
| `ARRIVE_GUARD_SPEED` | `backendError.code.ARRIVE_GUARD_SPEED` | Sending again would be refused the same way. Check this on the stop again on site. | 再次发送也会被同样拒绝，请在现场重新核验。 |
| `ARRIVE_GUARD_THROTTLE` | `backendError.code.ARRIVE_GUARD_THROTTLE` | Wait a moment, then locate again. | 请稍等片刻再重新定位。 |
| `ARRIVE_GUARD_WINDOW_DISTANCE` | `backendError.code.ARRIVE_GUARD_WINDOW_DISTANCE` | Sending again would be refused the same way. Check this on the stop again on site. | 再次发送也会被同样拒绝，请在现场重新核验。 |
| `ARRIVE_LOCATION_INVALID` | `backendError.code.ARRIVE_LOCATION_INVALID` | Locate again and send the new reading. | 请重新定位后再提交新的读数。 |
| `ARRIVE_LOCATION_MISSING` | `backendError.code.ARRIVE_LOCATION_MISSING` | Allow location for Chein, then locate again. | 请允许城瘾使用定位，然后重新定位。 |
| `ARRIVE_LOCATION_STALE` | `backendError.code.ARRIVE_LOCATION_STALE` | Locate again to send a fresh reading. | 请重新定位，提交新的读数。 |
| `ARRIVE_NOT_RECORDED` | `backendError.code.ARRIVE_NOT_RECORDED` | Record your arrival here before answering. | 先记录到达这一站，再作答。 |
| `ARRIVE_TOO_FAR` | `backendError.code.ARRIVE_TOO_FAR` | Walk closer to the stop, then locate again. | 请走近这一站后重新定位。 |
| `BOARD_CURSOR_STALE` | `backendError.code.BOARD_CURSOR_STALE` | This list changed. Refresh and try again. | 列表已变化，请刷新后再试。 |
| `CASH_CLOSED` | `backendError.code.CASH_CLOSED` | This cash case did not complete a payment. Cash payout is closed. Choose a non-cash reason. | 这次现金处理没有完成支付。现金发放已关闭，请改用非现金原因。 |
| `CHAPTER_REDEEMED` | `backendError.code.CHAPTER_REDEEMED` | This chapter is already redeemed. Continue to the next stop. | 本章已核销，请前往下一站。 |
| `CITY_MAP_CURSOR_STALE` | `backendError.code.CITY_MAP_CURSOR_STALE` | The map changed. Refresh and try again. | 地图已变化，请刷新后再试。 |
| `CITY_ORDERED_RESET_REQUIRED` | `backendError.code.CITY_ORDERED_RESET_REQUIRED` | The map needs to be reloaded. | 地图需要重新加载。 |
| `CITY_QUERY_TOO_BROAD` | `backendError.code.CITY_QUERY_TOO_BROAD` | That map area is too large. Zoom in and try again. | 地图范围太大，请放大后再试。 |
| `CITY_SNAPSHOT_CHANGED` | `backendError.code.CITY_SNAPSHOT_CHANGED` | The map changed. Refresh and try again. | 地图已变化，请刷新后再试。 |
| `CONFIG_INVALID` | `backendError.code.CONFIG_INVALID` | This stop isn't set up. Ask the organiser to fix it. | 这一站尚未配置，请联系组织者修正。 |
| `DIRECTORY_CHANGED` | `backendError.code.DIRECTORY_CHANGED` | The friend list changed. Refresh and try again. | 好友列表已变化，请刷新后再试。 |
| `DIRECTORY_GROUP_NOT_FOUND` | `backendError.code.DIRECTORY_GROUP_NOT_FOUND` | That friend group was not found. | 未找到该好友分组。 |
| `EVENT_UNKNOWN` | `backendError.code.EVENT_UNKNOWN` | That event isn't supported. Choose a listed event and try again. | 事件不合法，请选择已列出的事件后再试。 |
| `FEATURE_CLOSED` | `backendError.code.FEATURE_CLOSED` | This did not complete a payment. Cash and payout stay closed on this host. Use a non-cash reward, or try again only where payments are open. | 这次没有完成支付。本主机的现金与发放保持关闭。请改用非现金奖励，或仅在支付开放时再试。 |
| `FORBIDDEN` | `backendError.code.FORBIDDEN` | You don't have permission to do that. | 你没有权限执行此操作。 |
| `FRIEND_INVITE_REJECTED` | `backendError.code.FRIEND_INVITE_REJECTED` | This friend invite was declined. | 这条好友邀请已被拒绝。 |
| `FRIEND_NOT_FOUND` | `backendError.code.FRIEND_NOT_FOUND` | That friend was not found. | 未找到该好友。 |
| `GAME_AUTHORITY_CONFLICT` | `backendError.code.GAME_AUTHORITY_CONFLICT` | Play authority changed. Confirm again. | 执行权已变化，请重新确认。 |
| `GUILD_FORBIDDEN` | `backendError.code.GUILD_FORBIDDEN` | Join this club before managing it. | 加入后才能操作。 |
| `H5_REJECTED` | `backendError.code.H5_REJECTED` | That page was rejected. | 该页面已被拒绝。 |
| `H5_TIMEOUT` | `backendError.code.H5_TIMEOUT` | That page timed out. | 该页面已超时。 |
| `HANGOUT_CLOSED` | `backendError.code.HANGOUT_CLOSED` | This conversation is closed. | 此会话已关闭。 |
| `IM_CONVERSATION_CLOSED` | `backendError.code.IM_CONVERSATION_CLOSED` | This conversation is closed. | 此会话已关闭。 |
| `INTENT_ACTION_REUSED` | `backendError.code.INTENT_ACTION_REUSED` | This action was already used for different input. Start a new attempt. | 这次操作已用于另一份输入，请重新开始一次。 |
| `INTENT_INPUT_INVALID` | `backendError.code.INTENT_INPUT_INVALID` | That action isn't valid. Check it and try again. | 这次操作无效，请检查后再试。 |
| `INTENT_PENDING` | `backendError.code.INTENT_PENDING` | Check this same action later. Do not start a new one. | 请稍后查询同一次操作，不要重新开始。 |
| `INTENT_SCOPE_DENIED` | `backendError.code.INTENT_SCOPE_DENIED` | You don't have permission for this play. Open a run you can join. | 你没有这次游玩的权限，请打开可参加的对局。 |
| `INTENT_SESSION_ENDED` | `backendError.code.INTENT_SESSION_ENDED` | This run has ended. Start a new run. | 本局已结束，请开始新的一局。 |
| `INTENT_SESSION_MISMATCH` | `backendError.code.INTENT_SESSION_MISMATCH` | This run is not yours. Open your own run. | 这不是你的对局，请打开自己的对局。 |
| `INTENT_STALE_STATE` | `backendError.code.INTENT_STALE_STATE` | Refresh this run, then try again. | 请刷新本局后再试。 |
| `INVALID_INPUT` | `backendError.code.INVALID_INPUT` | That input isn't valid. Check it and try again. | 输入无效，请检查后再试。 |
| `LEDGER_OFF` | `backendError.code.LEDGER_OFF` | Reservations are temporarily unavailable. | 预约暂时不可用。 |
| `LOGIN_REQUIRED` | `backendError.code.LOGIN_REQUIRED` | Sign in first. | 请先登录 |
| `MERCHANT_ENVIRONMENT_EXIT` | `backendError.code.MERCHANT_ENVIRONMENT_EXIT` | The original request used the fixed safe exit. | 原请求的固定安全退出 |
| `MERCHANT_EXITED` | `backendError.code.MERCHANT_EXITED` | The merchant has left this program. | 商家已退出该活动。 |
| `MESSAGE_CONTEXT_UNAVAILABLE` | `backendError.code.MESSAGE_CONTEXT_UNAVAILABLE` | That message is unavailable. | 这条消息暂不可用。 |
| `MESSAGE_VERSION_CONFLICT` | `backendError.code.MESSAGE_VERSION_CONFLICT` | This message changed. Refresh and try again. | 这条消息已变化，请刷新后再试。 |
| `NICKNAME_INVALID` | `backendError.code.NICKNAME_INVALID` | That name can't be used. | 这个名字无法使用。 |
| `NICKNAME_SUFFIX_EXHAUSTED` | `backendError.code.NICKNAME_SUFFIX_EXHAUSTED` | No available name suggestion is left. | 没有可用的名字建议了。 |
| `NICKNAME_TAKEN` | `backendError.code.NICKNAME_TAKEN` | That name is already taken. | 这个名字已被使用。 |
| `NODE_DELISTED` | `backendError.code.NODE_DELISTED` | It cannot be completed now. Stops you already finished stay in your history. | 现在无法完成。已完成的站点仍保留在记录中。 |
| `NODE_NOT_FOUND` | `backendError.code.NODE_NOT_FOUND` | That stop was not found. Refresh the route. | 未找到这一站，请刷新路线。 |
| `NOT_CONFIRM` | `backendError.code.NOT_CONFIRM` | This isn't confirmed yet. Confirm it before continuing. | 尚未确认，请先确认后再继续。 |
| `NOT_FOUND` | `backendError.code.NOT_FOUND` | That item was not found. Refresh and try again. | 未找到对应内容，请刷新后再试。 |
| `NOT_YET_VALID` | `backendError.code.NOT_YET_VALID` | This offer is not valid yet. | 该优惠尚未生效。 |
| `NO_AUTHORITY` | `backendError.code.NO_AUTHORITY` | You don't have permission to do that. | 你没有权限执行此操作。 |
| `NO_BALANCE` | `backendError.code.NO_BALANCE` | You have no available units left. | 你没有可用的次数。 |
| `OFFER_EXPIRED` | `backendError.code.OFFER_EXPIRED` | This offer has expired. | 该优惠已过期。 |
| `ORIENT_LOGIN_REQUIRED` | `backendError.code.ORIENT_LOGIN_REQUIRED` | Sign in to your own account to view this round. | 请登录本人账号查看对局 |
| `ORIENT_RECEIPT_NOT_FOUND` | `backendError.code.ORIENT_RECEIPT_NOT_FOUND` | That receipt was not found. | 未找到该回执。 |
| `OUTCOME_UNKNOWN` | `backendError.code.OUTCOME_UNKNOWN` | The result is still unknown. Check the original request before trying again. | 结果尚未确定，请先核对原请求再试。 |
| `OUTSIDE_VALIDITY` | `backendError.code.OUTSIDE_VALIDITY` | The chosen time is outside your validity period. | 所选时间不在有效期内。 |
| `POLICY_CHANGED` | `backendError.code.POLICY_CHANGED` | The service refused the current sharing policy. Sharing stopped and the received location was cleared. | 服务端拒绝当前共享政策。已同步停止采集并清除接收位置。 |
| `POLICY_UNAVAILABLE` | `backendError.code.POLICY_UNAVAILABLE` | The service refused the current sharing policy. Sharing stopped and the received location was cleared. | 服务端拒绝当前共享政策。已同步停止采集并清除接收位置。 |
| `PREFLIGHT_BINDING_MISMATCH` | `backendError.code.PREFLIGHT_BINDING_MISMATCH` | That check doesn't match this account. | 该校验与当前账号不符。 |
| `PREFLIGHT_CONSUMED` | `backendError.code.PREFLIGHT_CONSUMED` | That check was already used. | 该校验已被使用。 |
| `PREFLIGHT_EXPIRED` | `backendError.code.PREFLIGHT_EXPIRED` | That check expired. Start again. | 该校验已过期，请重新开始。 |
| `PREFLIGHT_INPUT_INVALID` | `backendError.code.PREFLIGHT_INPUT_INVALID` | That check input is not valid. | 该校验内容无效。 |
| `PREFLIGHT_INTENT_CLOSED` | `backendError.code.PREFLIGHT_INTENT_CLOSED` | That request is closed. | 该请求已关闭。 |
| `PREFLIGHT_INTENT_CONFLICT` | `backendError.code.PREFLIGHT_INTENT_CONFLICT` | That request conflicts with another one. | 该请求与另一请求冲突。 |
| `PREFLIGHT_NOT_FOUND` | `backendError.code.PREFLIGHT_NOT_FOUND` | That check was not found. | 未找到该校验。 |
| `PREFLIGHT_REJECTED` | `backendError.code.PREFLIGHT_REJECTED` | That check was not accepted. | 该校验未被接受。 |
| `PREFLIGHT_STATE_CHANGED` | `backendError.code.PREFLIGHT_STATE_CHANGED` | That check changed. Start again. | 该校验已变化，请重新开始。 |
| `PRIVACY_CONFLICT` | `backendError.code.PRIVACY_CONFLICT` | Privacy settings changed. Refresh and try again. | 隐私设置已变化，请刷新后再试。 |
| `PROGRESS_REQUEST_NOT_FOUND` | `backendError.code.PROGRESS_REQUEST_NOT_FOUND` | That progress request was not found. | 未找到该进度请求。 |
| `PUZZLE_STATE_UNAVAILABLE` | `backendError.code.PUZZLE_STATE_UNAVAILABLE` | The puzzle couldn't be read. Try again. | 解谜状态暂时读不到，请重试。 |
| `RELATION_UNAVAILABLE` | `backendError.code.RELATION_UNAVAILABLE` | The service refused this relationship. Sharing stopped and the received location was cleared. | 服务端拒绝当前关系授权。已同步停止采集并清除接收位置。 |
| `REQUEST_ID_CONFLICT` | `backendError.code.REQUEST_ID_CONFLICT` | This request conflicts with an earlier one. | 此请求与先前的请求冲突。 |
| `REQUEST_OUTCOME_UNKNOWN` | `backendError.code.REQUEST_OUTCOME_UNKNOWN` | The result is still unknown. Check the original request before trying again. | 结果尚未确定，请先核对原请求再试。 |
| `REQUEST_REJECTED` | `backendError.code.REQUEST_REJECTED` | That request was not accepted. | 请求未被接受。 |
| `RESERVATION_OFF` | `backendError.code.RESERVATION_OFF` | Reservations are temporarily unavailable. | 预约暂时不可用。 |
| `RESERVED_ELSEWHERE` | `backendError.code.RESERVED_ELSEWHERE` | This unit is already reserved elsewhere. | 该次数已预约其他门店。 |
| `REVISION_CONFLICT` | `backendError.code.REVISION_CONFLICT` | This subscription changed. Refresh and try again. | 订阅已被修改，请刷新后再试。 |
| `ROUTE_EGG_OFFLINE` | `backendError.code.ROUTE_EGG_OFFLINE` | Route eggs are offline. Continue without collecting one. | 途中彩蛋已下线。请继续路线，不必再领取。 |
| `ROUTE_LOCKED` | `backendError.code.ROUTE_LOCKED` | Refresh to see which stop comes first. | 请刷新，查看应先去哪一站。 |
| `SCAN_CODE_AMBIGUOUS` | `backendError.code.SCAN_CODE_AMBIGUOUS` | That code matches more than one stop. Scan the code for this stop. | 这个码对应多个站点，请扫描这一站的码。 |
| `SCAN_CODE_EXPIRED` | `backendError.code.SCAN_CODE_EXPIRED` | That code has expired. Scan a current one. | 这个码已过期，请扫描仍有效的码。 |
| `SCAN_CODE_INVALID` | `backendError.code.SCAN_CODE_INVALID` | That code isn't valid. Scan the code for this stop. | 核销码无效，请扫描这一站的码。 |
| `SCAN_CODE_NODE_MISMATCH` | `backendError.code.SCAN_CODE_NODE_MISMATCH` | That code is for a different stop. Scan this stop's code. | 这个码属于另一站，请扫描这一站的码。 |
| `SCAN_CODE_USED` | `backendError.code.SCAN_CODE_USED` | That code was already used. Ask for a new one. | 这个码已使用，请换一个新码。 |
| `SCREENING_PENDING` | `backendError.code.SCREENING_PENDING` | Finish the existing rules first. The welcome screen does not replace them and does not resend a message. | 请先完成原逐条规则。欢迎屏不能替代规则同意，也不触发重发消息。 |
| `SENSOR_REJECTED` | `backendError.code.SENSOR_REJECTED` | The sensor check didn't pass. Complete the challenge again. | 传感器判定未通过，请重新完成挑战。 |
| `STORE_SCAN_REQUIRED` | `backendError.code.STORE_SCAN_REQUIRED` | Location cannot replace the merchant's scan here. | 这里不能用定位代替商家扫码。 |
| `TASK_REQUIRED` | `backendError.code.TASK_REQUIRED` | Arrival alone does not complete this stop. | 仅到达不能完成这一站。 |
| `TEAM_LEAD_REQUIRED` | `backendError.code.TEAM_LEAD_REQUIRED` | The leader releases this chapter before anyone can continue. | 队长放行本章后才能继续。 |
| `UNKNOWN` | `backendError.code.UNKNOWN` | The result is still unknown. Please try again later. | 结果尚未确定，请稍后再试。 |
| `US_APPLE_INVALID_CHALLENGE` | `backendError.code.US_APPLE_INVALID_CHALLENGE` | Sign in with Apple expired. Please try again. | 通过 Apple 登录已过期，请重试。 |
| `US_APPLE_INVALID_IDENTITY` | `backendError.code.US_APPLE_INVALID_IDENTITY` | Apple couldn't confirm this sign-in. | Apple 未能确认这次登录。 |
| `US_APPLE_INVALID_REQUEST` | `backendError.code.US_APPLE_INVALID_REQUEST` | Sign in with Apple couldn't be started. Please try again. | 无法开始通过 Apple 登录，请重试。 |
| `US_APPLE_RATE_LIMITED` | `backendError.code.US_APPLE_RATE_LIMITED` | Too many sign-in attempts. Please wait and try again. | 登录尝试过于频繁，请稍后再试。 |
| `US_APPLE_UNAVAILABLE` | `backendError.code.US_APPLE_UNAVAILABLE` | Sign in with Apple is unavailable right now. | 通过 Apple 登录暂不可用。 |
| `US_SESSION_UNAVAILABLE` | `backendError.code.US_SESSION_UNAVAILABLE` | Sign-in is unavailable right now. Please try again. | 登录暂不可用，请重试。 |
| `VERSION_CONFLICT` | `backendError.code.VERSION_CONFLICT` | This item changed. Refresh and try again. | 内容已变化，请刷新后再试。 |
| `WEBHOOK_BODY_INVALID` | `backendError.code.WEBHOOK_BODY_INVALID` | The webhook body must be JSON with content of 1–2000 characters. Fix it and send again. | Webhook 正文须为含 1–2000 字 content 的 JSON，请修正后再发。 |
| `WEBHOOK_BODY_TOO_LARGE` | `backendError.code.WEBHOOK_BODY_TOO_LARGE` | That webhook body is too large. Shorten it and try again. | Webhook 请求体过大，请缩短后再试。 |
| `WEBHOOK_CHANGE_INVALID` | `backendError.code.WEBHOOK_CHANGE_INVALID` | That webhook name isn't valid. Use 1–64 characters and try again. | 名称不合法，请使用 1–64 字的名称后再试。 |
| `WEBHOOK_CHANNEL_UNAVAILABLE` | `backendError.code.WEBHOOK_CHANNEL_UNAVAILABLE` | This channel can't receive the webhook. Check the channel and try again. | 该频道无法接收 Webhook，请检查频道后再试。 |
| `WEBHOOK_CONTENT_BLOCKED` | `backendError.code.WEBHOOK_CONTENT_BLOCKED` | That content was blocked. Change it and send again. | 内容未通过审核，请修改后再发。 |
| `WEBHOOK_CRYPTO_UNAVAILABLE` | `backendError.code.WEBHOOK_CRYPTO_UNAVAILABLE` | Webhook signing isn't configured. Set the encryption key, then try again. | 签名密钥加密未配置，请配置后再试。 |
| `WEBHOOK_ENDPOINT_PAUSED` | `backendError.code.WEBHOOK_ENDPOINT_PAUSED` | This webhook endpoint is paused. Resume it before sending again. | 该 Webhook 端点已暂停，请恢复后再发送。 |
| `WEBHOOK_FORBIDDEN` | `backendError.code.WEBHOOK_FORBIDDEN` | You can't manage webhooks here. Ask a manager, then try again. | 你无权管理该频道的 Webhook，请联系管理员后再试。 |
| `WEBHOOK_INBOUND_UNAVAILABLE` | `backendError.code.WEBHOOK_INBOUND_UNAVAILABLE` | Inbound webhooks aren't configured. Set the receive address and encryption key, then try again. | 入站 Webhook 未配置接收地址或加密密钥，请配置后再试。 |
| `WEBHOOK_IP_NOT_ALLOWED` | `backendError.code.WEBHOOK_IP_NOT_ALLOWED` | This address isn't allowed. Use an allowed address. | 来源地址不在白名单内，请改用允许的地址。 |
| `WEBHOOK_NONCE_INVALID` | `backendError.code.WEBHOOK_NONCE_INVALID` | The webhook nonce isn't valid. Send a new nonce of 16–64 characters. | Webhook nonce 无效，请使用 16–64 位的新 nonce。 |
| `WEBHOOK_NOT_FOUND` | `backendError.code.WEBHOOK_NOT_FOUND` | That webhook was not found. Refresh the list. | 未找到该 Webhook，请刷新列表。 |
| `WEBHOOK_PAUSED` | `backendError.code.WEBHOOK_PAUSED` | This subscription is paused. Resume it before testing again. | 订阅已暂停，请恢复后再测试。 |
| `WEBHOOK_RATE_LIMITED` | `backendError.code.WEBHOOK_RATE_LIMITED` | Too many webhook calls. Wait and try again. | Webhook 调用过于频繁，请稍后再试。 |
| `WEBHOOK_REPLAYED` | `backendError.code.WEBHOOK_REPLAYED` | This webhook was already received. Send a new nonce. | 这条 Webhook 已接收过，请换新的 nonce。 |
| `WEBHOOK_RESULT_UNKNOWN` | `backendError.code.WEBHOOK_RESULT_UNKNOWN` | The webhook result is still unknown. Check the original delivery before trying again. | 回调结果尚未确定，请先核对原投递再试。 |
| `WEBHOOK_SECRET_UNRECOVERABLE` | `backendError.code.WEBHOOK_SECRET_UNRECOVERABLE` | The signing secret can't be recovered. Rotate the secret, then try again. | 签名密钥无法恢复，请轮换密钥后再试。 |
| `WEBHOOK_SIGNATURE_INVALID` | `backendError.code.WEBHOOK_SIGNATURE_INVALID` | The signature doesn't match. Sign again with the endpoint secret. | 签名不匹配，请用端点密钥重新签名。 |
| `WEBHOOK_TIMESTAMP_OUT_OF_WINDOW` | `backendError.code.WEBHOOK_TIMESTAMP_OUT_OF_WINDOW` | The webhook timestamp is outside the allowed window. Send a current timestamp. | Webhook 时间戳超出允许窗口，请使用当前时间重发。 |
| `WELCOME_SCREEN_NOT_CONFIGURED` | `backendError.code.WELCOME_SCREEN_NOT_CONFIGURED` | This space has no welcome screen yet. Joining did not fail, and you do not need to resend the request. | 本空间尚未配置或未启用欢迎屏；不是加入失败，不需要重发申请。 |
| `WITHDRAWAL_CONSENT_REQUIRED` | `backendError.code.WITHDRAWAL_CONSENT_REQUIRED` | This withdrawal isn't available. | 此提现暂不可用。 |

## Messages

| Token | Catalog key | English | 简体中文 |
|---|---|---|---|
| `DIRECTORY_CHANGED` | `backendError.message.directoryChanged` | The friend list changed. Refresh and try again. | 好友列表已变化，请刷新后再试。 |
| `DIRECTORY_GROUP_NOT_FOUND` | `backendError.message.directoryGroupNotFound` | That friend group was not found. | 未找到该好友分组。 |
| `FRIEND_NOT_FOUND` | `backendError.message.friendNotFound` | That friend was not found. | 未找到该好友。 |
| `ORIENT_LOGIN_REQUIRED` | `backendError.message.orientLoginRequired` | Sign in to your own account to view this round. | 请登录本人账号查看对局 |
| `ORIENT_RECEIPT_NOT_FOUND` | `backendError.message.orientReceiptNotFound` | That receipt was not found. | 未找到该回执。 |
| `REQUEST_ID_CONFLICT` | `backendError.message.requestIdConflict` | This request conflicts with an earlier one. | 此请求与先前的请求冲突。 |
| `仅主理人与联席主理人可查看分润` | `backendError.message.ownerSplitOnly` | Only the owner and co-owners can view this split. | 仅主理人与联席主理人可查看分润 |
| `仅主题发布者可查看候选池` | `backendError.message.publisherPoolOnly` | Only the topic publisher can view this pool. | 仅主题发布者可查看候选池 |
| `仅自由探索` | `backendError.message.freeExploreOnly` | This is only available for free exploration. | 仅自由探索 |
| `今日AI次数已用完` | `backendError.message.aiQuotaUsed` | Today's AI uses are used up. | 今日AI次数已用完 |
| `券库存不足,核销失败` | `backendError.message.couponStock` | There isn't enough coupon stock, so redemption did not finish. | 券库存不足,核销失败 |
| `参数错误` | `backendError.message.badParameter` | A parameter is not valid. | 参数错误 |
| `商家不存在或未开放` | `backendError.message.storeUnavailable` | This store is unavailable. | 商家不存在或未开放 |
| `定位精度不足` | `backendError.message.locationAccuracy` | Location accuracy is too low. | 定位精度不足 |
| `已过期` | `backendError.message.expired` | This has expired. | 已过期 |
| `当前身份暂不支持` | `backendError.message.identityUnsupported` | This account can't do that. | 当前身份暂不支持 |
| `据点不存在` | `backendError.message.placeMissing` | That place was not found. | 据点不存在 |
| `无权核销该据点` | `backendError.message.redeemForbidden` | You can't redeem at this place. | 无权核销该据点 |
| `无法访问系统资源` | `backendError.message.resourceDenied` | You can't access this right now. Please sign in again. | 无法访问系统资源 |
| `核销码无效` | `backendError.message.redeemCodeInvalid` | That redemption code is not valid. | 核销码无效 |
| `核销码格式错误` | `backendError.message.redeemCodeFormat` | That redemption code format is not valid. | 核销码格式错误 |
| `格式错误` | `backendError.message.badFormat` | That format is not valid. | 格式错误 |
| `玩家未到店打卡,或该券已核销` | `backendError.message.checkInOrRedeemed` | Check in at the store first, or this coupon was already redeemed. | 玩家未到店打卡,或该券已核销 |
| `登录状态已失效` | `backendError.message.sessionInvalid` | Your session has expired. Please sign in again. | 登录已过期，请重新登录。 |
| `空码` | `backendError.message.emptyCode` | The redemption code is empty. | 空码 |
| `签名不匹配` | `backendError.message.signatureMismatch` | The signature does not match. | 签名不匹配 |
| `订单已过期` | `backendError.message.orderExpired` | This order has expired. | 订单已过期 |
| `认证失败` | `backendError.message.authenticationFailed` | Sign-in could not be verified. Please sign in again. | 认证失败 |
| `请先登录` | `backendError.message.signInFirst` | Sign in first. | 请先登录 |
| `途中彩蛋已下线` | `backendError.message.routeEggOffline` | Route eggs are offline. Continue without collecting one. | 途中彩蛋已下线。请继续路线，不必再领取。 |
| `通知不存在` | `backendError.message.noticeMissing` | That notice was not found. | 通知不存在 |
| `非据点核销码` | `backendError.message.notPlaceCode` | That is not a place redemption code. | 非据点核销码 |

