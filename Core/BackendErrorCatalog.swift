import Foundation

/// Local map of backend error codes and messages this repository already names.
/// A non-empty unknown code stays the generic sentence and does not reveal the
/// raw code or the server message. Lookup never builds a URL. Call
/// `requireConfiguration` before any request: an empty base URL or realm throws
/// `APIError.notConfigured` and no request is created.
public enum BackendErrorLanguage: Equatable {
    case en
    case zhHans
}

public enum BackendErrorCatalog {
    public struct Sentence: Equatable {
        public let en: String
        public let zhHans: String
        public func text(_ language: BackendErrorLanguage) -> String {
            language == .zhHans ? zhHans : en
        }
    }

    public static let generic = Sentence(en: "Something went wrong. Please try again.", zhHans: "出了点问题，请重试。")

    public static func sentence(code: String?, status: Int? = nil, message: String? = nil, language: BackendErrorLanguage) -> String {
        let token = code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !token.isEmpty {
            return (codes[token] ?? generic).text(language)
        }
        if let status {
            return (codes[String(status)] ?? generic).text(language)
        }
        let text = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty { return generic.text(language) }
        return (messages[text] ?? generic).text(language)
    }

    /// Missing deployment configuration. This returns only after both values are
    /// non-empty, and it does not create a request.
    public static func requireConfiguration(baseURL: String, realm: String) throws {
        let baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let realm = realm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.isEmpty, !realm.isEmpty else { throw APIError.notConfigured }
    }

    private static let codes: [String: Sentence] = [
        "2": .init(en: "Your session has expired. Please sign in again.", zhHans: "登录已过期，请重新登录。"),
        "400": .init(en: "That request was not accepted. Check it and try again.", zhHans: "请求未被接受，请检查后再试。"),
        "401": .init(en: "Your session has expired. Please sign in again.", zhHans: "登录已过期，请重新登录。"),
        "403": .init(en: "You don't have permission to do that.", zhHans: "你没有权限执行此操作。"),
        "404": .init(en: "That item was not found.", zhHans: "未找到对应内容。"),
        "405": .init(en: "That request was refused.", zhHans: "请求被拒绝。"),
        "408": .init(en: "The result is still unknown. Please try again later.", zhHans: "结果尚未确定，请稍后再试。"),
        "409": .init(en: "This item changed. Refresh and try again.", zhHans: "内容已变化，请刷新后再试。"),
        "410": .init(en: "That item is no longer available.", zhHans: "该内容已不可用。"),
        "413": .init(en: "That request is too large.", zhHans: "请求过大。"),
        "415": .init(en: "That request isn't in a supported format.", zhHans: "请求格式不受支持。"),
        "422": .init(en: "That request was not accepted.", zhHans: "请求未被接受。"),
        "426": .init(en: "This app version is no longer supported. Update the app before continuing.", zhHans: "当前应用版本已不受支持，请更新应用后再继续。"),
        "429": .init(en: "Too many attempts. Please wait and try again.", zhHans: "操作过于频繁，请稍后再试。"),
        "500": .init(en: "The service couldn't complete that. Please try again.", zhHans: "服务未能完成此操作，请重试。"),
        "503": .init(en: "The service is unavailable right now. Please try again.", zhHans: "服务暂不可用，请重试。"),
        "520": .init(en: "The original result is still unknown.", zhHans: "原命令结果仍未知。"),
        "BOARD_CURSOR_STALE": .init(en: "This list changed. Refresh and try again.", zhHans: "列表已变化，请刷新后再试。"),
        "CITY_MAP_CURSOR_STALE": .init(en: "The map changed. Refresh and try again.", zhHans: "地图已变化，请刷新后再试。"),
        "CITY_ORDERED_RESET_REQUIRED": .init(en: "The map needs to be reloaded.", zhHans: "地图需要重新加载。"),
        "CITY_QUERY_TOO_BROAD": .init(en: "That map area is too large. Zoom in and try again.", zhHans: "地图范围太大，请放大后再试。"),
        "CITY_SNAPSHOT_CHANGED": .init(en: "The map changed. Refresh and try again.", zhHans: "地图已变化，请刷新后再试。"),
        "DIRECTORY_CHANGED": .init(en: "The friend list changed. Refresh and try again.", zhHans: "好友列表已变化，请刷新后再试。"),
        "DIRECTORY_GROUP_NOT_FOUND": .init(en: "That friend group was not found.", zhHans: "未找到该好友分组。"),
        "FORBIDDEN": .init(en: "You don't have permission to do that.", zhHans: "你没有权限执行此操作。"),
        "FRIEND_INVITE_REJECTED": .init(en: "This friend invite was declined.", zhHans: "这条好友邀请已被拒绝。"),
        "FRIEND_NOT_FOUND": .init(en: "That friend was not found.", zhHans: "未找到该好友。"),
        "GAME_AUTHORITY_CONFLICT": .init(en: "Play authority changed. Confirm again.", zhHans: "执行权已变化，请重新确认。"),
        "H5_REJECTED": .init(en: "That page was rejected.", zhHans: "该页面已被拒绝。"),
        "H5_TIMEOUT": .init(en: "That page timed out.", zhHans: "该页面已超时。"),
        "HANGOUT_CLOSED": .init(en: "This conversation is closed.", zhHans: "此会话已关闭。"),
        "IM_CONVERSATION_CLOSED": .init(en: "This conversation is closed.", zhHans: "此会话已关闭。"),
        "LEDGER_OFF": .init(en: "Reservations are temporarily unavailable.", zhHans: "预约暂时不可用。"),
        "LOGIN_REQUIRED": .init(en: "Sign in first.", zhHans: "请先登录"),
        "MERCHANT_ENVIRONMENT_EXIT": .init(en: "The original request used the fixed safe exit.", zhHans: "原请求的固定安全退出"),
        "MERCHANT_EXITED": .init(en: "The merchant has left this program.", zhHans: "商家已退出该活动。"),
        "MESSAGE_CONTEXT_UNAVAILABLE": .init(en: "That message is unavailable.", zhHans: "这条消息暂不可用。"),
        "MESSAGE_VERSION_CONFLICT": .init(en: "This message changed. Refresh and try again.", zhHans: "这条消息已变化，请刷新后再试。"),
        "NICKNAME_INVALID": .init(en: "That name can't be used.", zhHans: "这个名字无法使用。"),
        "NICKNAME_SUFFIX_EXHAUSTED": .init(en: "No available name suggestion is left.", zhHans: "没有可用的名字建议了。"),
        "NICKNAME_TAKEN": .init(en: "That name is already taken.", zhHans: "这个名字已被使用。"),
        "NOT_YET_VALID": .init(en: "This offer is not valid yet.", zhHans: "该优惠尚未生效。"),
        "NO_AUTHORITY": .init(en: "You don't have permission to do that.", zhHans: "你没有权限执行此操作。"),
        "NO_BALANCE": .init(en: "You have no available units left.", zhHans: "你没有可用的次数。"),
        "OFFER_EXPIRED": .init(en: "This offer has expired.", zhHans: "该优惠已过期。"),
        "ORIENT_LOGIN_REQUIRED": .init(en: "Sign in to your own account to view this round.", zhHans: "请登录本人账号查看对局"),
        "ORIENT_RECEIPT_NOT_FOUND": .init(en: "That receipt was not found.", zhHans: "未找到该回执。"),
        "OUTCOME_UNKNOWN": .init(en: "The result is still unknown. Check the original request before trying again.", zhHans: "结果尚未确定，请先核对原请求再试。"),
        "OUTSIDE_VALIDITY": .init(en: "The chosen time is outside your validity period.", zhHans: "所选时间不在有效期内。"),
        "POLICY_CHANGED": .init(en: "The service refused the current sharing policy. Sharing stopped and the received location was cleared.", zhHans: "服务端拒绝当前共享政策。已同步停止采集并清除接收位置。"),
        "POLICY_UNAVAILABLE": .init(en: "The service refused the current sharing policy. Sharing stopped and the received location was cleared.", zhHans: "服务端拒绝当前共享政策。已同步停止采集并清除接收位置。"),
        "PREFLIGHT_BINDING_MISMATCH": .init(en: "That check doesn't match this account.", zhHans: "该校验与当前账号不符。"),
        "PREFLIGHT_CONSUMED": .init(en: "That check was already used.", zhHans: "该校验已被使用。"),
        "PREFLIGHT_EXPIRED": .init(en: "That check expired. Start again.", zhHans: "该校验已过期，请重新开始。"),
        "PREFLIGHT_INPUT_INVALID": .init(en: "That check input is not valid.", zhHans: "该校验内容无效。"),
        "PREFLIGHT_INTENT_CLOSED": .init(en: "That request is closed.", zhHans: "该请求已关闭。"),
        "PREFLIGHT_INTENT_CONFLICT": .init(en: "That request conflicts with another one.", zhHans: "该请求与另一请求冲突。"),
        "PREFLIGHT_NOT_FOUND": .init(en: "That check was not found.", zhHans: "未找到该校验。"),
        "PREFLIGHT_REJECTED": .init(en: "That check was not accepted.", zhHans: "该校验未被接受。"),
        "PREFLIGHT_STATE_CHANGED": .init(en: "That check changed. Start again.", zhHans: "该校验已变化，请重新开始。"),
        "PRIVACY_CONFLICT": .init(en: "Privacy settings changed. Refresh and try again.", zhHans: "隐私设置已变化，请刷新后再试。"),
        "PROGRESS_REQUEST_NOT_FOUND": .init(en: "That progress request was not found.", zhHans: "未找到该进度请求。"),
        "RELATION_UNAVAILABLE": .init(en: "The service refused this relationship. Sharing stopped and the received location was cleared.", zhHans: "服务端拒绝当前关系授权。已同步停止采集并清除接收位置。"),
        "REQUEST_ID_CONFLICT": .init(en: "This request conflicts with an earlier one.", zhHans: "此请求与先前的请求冲突。"),
        "REQUEST_OUTCOME_UNKNOWN": .init(en: "The result is still unknown. Check the original request before trying again.", zhHans: "结果尚未确定，请先核对原请求再试。"),
        "REQUEST_REJECTED": .init(en: "That request was not accepted.", zhHans: "请求未被接受。"),
        "RESERVATION_OFF": .init(en: "Reservations are temporarily unavailable.", zhHans: "预约暂时不可用。"),
        "RESERVED_ELSEWHERE": .init(en: "This unit is already reserved elsewhere.", zhHans: "该次数已预约其他门店。"),
        "SCREENING_PENDING": .init(en: "Finish the existing rules first. The welcome screen does not replace them and does not resend a message.", zhHans: "请先完成原逐条规则。欢迎屏不能替代规则同意，也不触发重发消息。"),
        "UNKNOWN": .init(en: "The result is still unknown. Please try again later.", zhHans: "结果尚未确定，请稍后再试。"),
        "US_APPLE_INVALID_CHALLENGE": .init(en: "Sign in with Apple expired. Please try again.", zhHans: "通过 Apple 登录已过期，请重试。"),
        "US_APPLE_INVALID_IDENTITY": .init(en: "Apple couldn't confirm this sign-in.", zhHans: "Apple 未能确认这次登录。"),
        "US_APPLE_INVALID_REQUEST": .init(en: "Sign in with Apple couldn't be started. Please try again.", zhHans: "无法开始通过 Apple 登录，请重试。"),
        "US_APPLE_RATE_LIMITED": .init(en: "Too many sign-in attempts. Please wait and try again.", zhHans: "登录尝试过于频繁，请稍后再试。"),
        "US_APPLE_UNAVAILABLE": .init(en: "Sign in with Apple is unavailable right now.", zhHans: "通过 Apple 登录暂不可用。"),
        "US_SESSION_UNAVAILABLE": .init(en: "Sign-in is unavailable right now. Please try again.", zhHans: "登录暂不可用，请重试。"),
        "VERSION_CONFLICT": .init(en: "This item changed. Refresh and try again.", zhHans: "内容已变化，请刷新后再试。"),
        "WEBHOOK_RESULT_UNKNOWN": .init(en: "The webhook result is still unknown.", zhHans: "回调结果尚未确定。"),
        "WELCOME_SCREEN_NOT_CONFIGURED": .init(en: "This space has no welcome screen yet. Joining did not fail, and you do not need to resend the request.", zhHans: "本空间尚未配置或未启用欢迎屏；不是加入失败，不需要重发申请。"),
        "WITHDRAWAL_CONSENT_REQUIRED": .init(en: "This withdrawal isn't available.", zhHans: "此提现暂不可用。"),
    ]

    private static let messages: [String: Sentence] = [
        "DIRECTORY_CHANGED": .init(en: "The friend list changed. Refresh and try again.", zhHans: "好友列表已变化，请刷新后再试。"),
        "DIRECTORY_GROUP_NOT_FOUND": .init(en: "That friend group was not found.", zhHans: "未找到该好友分组。"),
        "FRIEND_NOT_FOUND": .init(en: "That friend was not found.", zhHans: "未找到该好友。"),
        "ORIENT_LOGIN_REQUIRED": .init(en: "Sign in to your own account to view this round.", zhHans: "请登录本人账号查看对局"),
        "ORIENT_RECEIPT_NOT_FOUND": .init(en: "That receipt was not found.", zhHans: "未找到该回执。"),
        "REQUEST_ID_CONFLICT": .init(en: "This request conflicts with an earlier one.", zhHans: "此请求与先前的请求冲突。"),
        "仅主理人与联席主理人可查看分润": .init(en: "Only the owner and co-owners can view this split.", zhHans: "仅主理人与联席主理人可查看分润"),
        "仅主题发布者可查看候选池": .init(en: "Only the topic publisher can view this pool.", zhHans: "仅主题发布者可查看候选池"),
        "仅自由探索": .init(en: "This is only available for free exploration.", zhHans: "仅自由探索"),
        "今日AI次数已用完": .init(en: "Today's AI uses are used up.", zhHans: "今日AI次数已用完"),
        "券库存不足,核销失败": .init(en: "There isn't enough coupon stock, so redemption did not finish.", zhHans: "券库存不足,核销失败"),
        "参数错误": .init(en: "A parameter is not valid.", zhHans: "参数错误"),
        "商家不存在或未开放": .init(en: "This store is unavailable.", zhHans: "商家不存在或未开放"),
        "定位精度不足": .init(en: "Location accuracy is too low.", zhHans: "定位精度不足"),
        "已过期": .init(en: "This has expired.", zhHans: "已过期"),
        "当前身份暂不支持": .init(en: "This account can't do that.", zhHans: "当前身份暂不支持"),
        "据点不存在": .init(en: "That place was not found.", zhHans: "据点不存在"),
        "无权核销该据点": .init(en: "You can't redeem at this place.", zhHans: "无权核销该据点"),
        "无法访问系统资源": .init(en: "You can't access this right now. Please sign in again.", zhHans: "无法访问系统资源"),
        "核销码无效": .init(en: "That redemption code is not valid.", zhHans: "核销码无效"),
        "核销码格式错误": .init(en: "That redemption code format is not valid.", zhHans: "核销码格式错误"),
        "格式错误": .init(en: "That format is not valid.", zhHans: "格式错误"),
        "玩家未到店打卡,或该券已核销": .init(en: "Check in at the store first, or this coupon was already redeemed.", zhHans: "玩家未到店打卡,或该券已核销"),
        "登录状态已失效": .init(en: "Your session has expired. Please sign in again.", zhHans: "登录已过期，请重新登录。"),
        "空码": .init(en: "The redemption code is empty.", zhHans: "空码"),
        "签名不匹配": .init(en: "The signature does not match.", zhHans: "签名不匹配"),
        "订单已过期": .init(en: "This order has expired.", zhHans: "订单已过期"),
        "认证失败": .init(en: "Sign-in could not be verified. Please sign in again.", zhHans: "认证失败"),
        "请先登录": .init(en: "Sign in first.", zhHans: "请先登录"),
        "通知不存在": .init(en: "That notice was not found.", zhHans: "通知不存在"),
        "非据点核销码": .init(en: "That is not a place redemption code.", zhHans: "非据点核销码"),
    ]
}
