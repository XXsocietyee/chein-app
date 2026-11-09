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

## Codes

| Token | Catalog key | English | 简体中文 |
|---|---|---|---|
| `BOARD_CURSOR_STALE` | `backendError.code.BOARD_CURSOR_STALE` | This list changed. Refresh and try again. | 列表已变化，请刷新后再试。 |
| `CITY_MAP_CURSOR_STALE` | `backendError.code.CITY_MAP_CURSOR_STALE` | The map changed. Refresh and try again. | 地图已变化，请刷新后再试。 |
| `CITY_ORDERED_RESET_REQUIRED` | `backendError.code.CITY_ORDERED_RESET_REQUIRED` | The map needs to be reloaded. | 地图需要重新加载。 |
| `CITY_QUERY_TOO_BROAD` | `backendError.code.CITY_QUERY_TOO_BROAD` | That map area is too large. Zoom in and try again. | 地图范围太大，请放大后再试。 |
| `CITY_SNAPSHOT_CHANGED` | `backendError.code.CITY_SNAPSHOT_CHANGED` | The map changed. Refresh and try again. | 地图已变化，请刷新后再试。 |
| `DIRECTORY_CHANGED` | `backendError.code.DIRECTORY_CHANGED` | The friend list changed. Refresh and try again. | 好友列表已变化，请刷新后再试。 |
| `DIRECTORY_GROUP_NOT_FOUND` | `backendError.code.DIRECTORY_GROUP_NOT_FOUND` | That friend group was not found. | 未找到该好友分组。 |
| `FORBIDDEN` | `backendError.code.FORBIDDEN` | You don't have permission to do that. | 你没有权限执行此操作。 |
| `FRIEND_INVITE_REJECTED` | `backendError.code.FRIEND_INVITE_REJECTED` | This friend invite was declined. | 这条好友邀请已被拒绝。 |
| `FRIEND_NOT_FOUND` | `backendError.code.FRIEND_NOT_FOUND` | That friend was not found. | 未找到该好友。 |
| `GAME_AUTHORITY_CONFLICT` | `backendError.code.GAME_AUTHORITY_CONFLICT` | Play authority changed. Confirm again. | 执行权已变化，请重新确认。 |
| `H5_REJECTED` | `backendError.code.H5_REJECTED` | That page was rejected. | 该页面已被拒绝。 |
| `H5_TIMEOUT` | `backendError.code.H5_TIMEOUT` | That page timed out. | 该页面已超时。 |
| `HANGOUT_CLOSED` | `backendError.code.HANGOUT_CLOSED` | This conversation is closed. | 此会话已关闭。 |
| `IM_CONVERSATION_CLOSED` | `backendError.code.IM_CONVERSATION_CLOSED` | This conversation is closed. | 此会话已关闭。 |
| `LEDGER_OFF` | `backendError.code.LEDGER_OFF` | Reservations are temporarily unavailable. | 预约暂时不可用。 |
| `LOGIN_REQUIRED` | `backendError.code.LOGIN_REQUIRED` | Sign in first. | 请先登录 |
| `MERCHANT_ENVIRONMENT_EXIT` | `backendError.code.MERCHANT_ENVIRONMENT_EXIT` | The original request used the fixed safe exit. | 原请求的固定安全退出 |
| `MERCHANT_EXITED` | `backendError.code.MERCHANT_EXITED` | The merchant has left this program. | 商家已退出该活动。 |
| `MESSAGE_CONTEXT_UNAVAILABLE` | `backendError.code.MESSAGE_CONTEXT_UNAVAILABLE` | That message is unavailable. | 这条消息暂不可用。 |
| `MESSAGE_VERSION_CONFLICT` | `backendError.code.MESSAGE_VERSION_CONFLICT` | This message changed. Refresh and try again. | 这条消息已变化，请刷新后再试。 |
| `NICKNAME_INVALID` | `backendError.code.NICKNAME_INVALID` | That name can't be used. | 这个名字无法使用。 |
| `NICKNAME_SUFFIX_EXHAUSTED` | `backendError.code.NICKNAME_SUFFIX_EXHAUSTED` | No available name suggestion is left. | 没有可用的名字建议了。 |
| `NICKNAME_TAKEN` | `backendError.code.NICKNAME_TAKEN` | That name is already taken. | 这个名字已被使用。 |
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
| `RELATION_UNAVAILABLE` | `backendError.code.RELATION_UNAVAILABLE` | The service refused this relationship. Sharing stopped and the received location was cleared. | 服务端拒绝当前关系授权。已同步停止采集并清除接收位置。 |
| `REQUEST_ID_CONFLICT` | `backendError.code.REQUEST_ID_CONFLICT` | This request conflicts with an earlier one. | 此请求与先前的请求冲突。 |
| `REQUEST_OUTCOME_UNKNOWN` | `backendError.code.REQUEST_OUTCOME_UNKNOWN` | The result is still unknown. Check the original request before trying again. | 结果尚未确定，请先核对原请求再试。 |
| `REQUEST_REJECTED` | `backendError.code.REQUEST_REJECTED` | That request was not accepted. | 请求未被接受。 |
| `RESERVATION_OFF` | `backendError.code.RESERVATION_OFF` | Reservations are temporarily unavailable. | 预约暂时不可用。 |
| `RESERVED_ELSEWHERE` | `backendError.code.RESERVED_ELSEWHERE` | This unit is already reserved elsewhere. | 该次数已预约其他门店。 |
| `SCREENING_PENDING` | `backendError.code.SCREENING_PENDING` | Finish the existing rules first. The welcome screen does not replace them and does not resend a message. | 请先完成原逐条规则。欢迎屏不能替代规则同意，也不触发重发消息。 |
| `UNKNOWN` | `backendError.code.UNKNOWN` | The result is still unknown. Please try again later. | 结果尚未确定，请稍后再试。 |
| `US_APPLE_INVALID_CHALLENGE` | `backendError.code.US_APPLE_INVALID_CHALLENGE` | Sign in with Apple expired. Please try again. | 通过 Apple 登录已过期，请重试。 |
| `US_APPLE_INVALID_IDENTITY` | `backendError.code.US_APPLE_INVALID_IDENTITY` | Apple couldn't confirm this sign-in. | Apple 未能确认这次登录。 |
| `US_APPLE_INVALID_REQUEST` | `backendError.code.US_APPLE_INVALID_REQUEST` | Sign in with Apple couldn't be started. Please try again. | 无法开始通过 Apple 登录，请重试。 |
| `US_APPLE_RATE_LIMITED` | `backendError.code.US_APPLE_RATE_LIMITED` | Too many sign-in attempts. Please wait and try again. | 登录尝试过于频繁，请稍后再试。 |
| `US_APPLE_UNAVAILABLE` | `backendError.code.US_APPLE_UNAVAILABLE` | Sign in with Apple is unavailable right now. | 通过 Apple 登录暂不可用。 |
| `US_SESSION_UNAVAILABLE` | `backendError.code.US_SESSION_UNAVAILABLE` | Sign-in is unavailable right now. Please try again. | 登录暂不可用，请重试。 |
| `VERSION_CONFLICT` | `backendError.code.VERSION_CONFLICT` | This item changed. Refresh and try again. | 内容已变化，请刷新后再试。 |
| `WEBHOOK_RESULT_UNKNOWN` | `backendError.code.WEBHOOK_RESULT_UNKNOWN` | The webhook result is still unknown. | 回调结果尚未确定。 |
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
| `通知不存在` | `backendError.message.noticeMissing` | That notice was not found. | 通知不存在 |
| `非据点核销码` | `backendError.message.notPlaceCode` | That is not a place redemption code. | 非据点核销码 |

