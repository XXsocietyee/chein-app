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

    /// A missing value. Never `0` and never blank.
    public static let unknownMark = "—"

    public static func sentence(code: String?, status: Int? = nil, message: String? = nil, language: BackendErrorLanguage) -> String {
        let token = code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !token.isEmpty {
            return (Self.codes[token] ?? Self.generic).text(language)
        }
        if let status {
            return (Self.codes[String(status)] ?? Self.generic).text(language)
        }
        let text = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty { return Self.generic.text(language) }
        return (Self.messages[text] ?? Self.generic).text(language)
    }

    /// Blank, `0`, and the word `unknown` are an em dash. A known code stays its sentence.
    /// An unknown machine code stays the generic sentence. Any other token is left as written.
    public static func playerFacing(code: String?, status: Int? = nil, message: String? = nil, language: BackendErrorLanguage) -> String {
        let token = code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if token == "0" || token == "unknown" { return Self.unknownMark }
        if token.isEmpty, status == nil {
            let text = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty || text == "0" || text == "unknown" { return Self.unknownMark }
            if Self.messages[text] != nil { return Self.sentence(code: nil, message: text, language: language) }
            return text
        }
        if !token.isEmpty, Self.codes[token] != nil {
            return Self.sentence(code: token, language: language)
        }
        if token.range(of: "^[A-Z][A-Z0-9_]{0,63}$", options: .regularExpression) != nil {
            return Self.sentence(code: token, language: language)
        }
        if token.isEmpty { return Self.sentence(code: nil, status: status, message: message, language: language) }
        return token
    }

    /// Closed money, payout, merchant writes, and password login are not a completed payment.
    /// `FEATURE_CLOSED` and `CASH_CLOSED` are refusals even when those switches are open.
    /// This catalog does not confirm that money moved.
    public static func paymentSucceeded(code: String?, moneyPaymentsOpen: Bool, payoutOpen: Bool, merchantWritesOpen: Bool, passwordLoginOpen: Bool) -> Bool {
        let token = code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let closedCode = token == "FEATURE_CLOSED" || token == "CASH_CLOSED"
        let areaClosed = !moneyPaymentsOpen || !payoutOpen || !merchantWritesOpen || !passwordLoginOpen
        if closedCode || areaClosed { return false }
        return false
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
        "501": .init(en: "That action isn't implemented yet. Try a different action.", zhHans: "此接口尚未实现，请改用其他操作。"),
        "601": .init(en: "The service sent a warning. Read it and try again.", zhHans: "服务返回了警告，请查看后再试。"),
        "ADVANCED_FIRST": .init(en: "Finish this stop's task before arriving.", zhHans: "请先完成这一站的任务，再记录到达。"),
        "ANSWER_WRONG": .init(en: "That answer wasn't accepted. Submit a new answer.", zhHans: "答案不正确，请提交新的答案。"),
        "ARRIVE_ACCURACY_INVALID": .init(en: "Locate again. This is not a cheating verdict.", zhHans: "请重新定位。这不是作弊判定。"),
        "ARRIVE_ACCURACY_LOW": .init(en: "Move into the open and locate again. A weak signal does not widen the stop's area.", zhHans: "请到开阔处重新定位。信号差不会放宽这一站的范围。"),
        "ARRIVE_ACCURACY_MISSING": .init(en: "Locate again so the reading includes its accuracy. This is not a cheating verdict.", zhHans: "请重新定位，让读数带上精度。这不是作弊判定。"),
        "ARRIVE_COORD_NOT_CONFIGURED": .init(en: "Trying again will not help. The organizer needs to fix this stop.", zhHans: "重试不会成功，需要组织者修正这一站。"),
        "ARRIVE_FIRST": .init(en: "Record your arrival at this stop before answering.", zhHans: "先记录到达这一站，再作答。"),
        "ARRIVE_GUARD_SPEED": .init(en: "Sending again would be refused the same way. Check this on the stop again on site.", zhHans: "再次发送也会被同样拒绝，请在现场重新核验。"),
        "ARRIVE_GUARD_THROTTLE": .init(en: "Wait a moment, then locate again.", zhHans: "请稍等片刻再重新定位。"),
        "ARRIVE_GUARD_WINDOW_DISTANCE": .init(en: "Sending again would be refused the same way. Check this on the stop again on site.", zhHans: "再次发送也会被同样拒绝，请在现场重新核验。"),
        "ARRIVE_LOCATION_INVALID": .init(en: "Locate again and send the new reading.", zhHans: "请重新定位后再提交新的读数。"),
        "ARRIVE_LOCATION_MISSING": .init(en: "Allow location for Chein, then locate again.", zhHans: "请允许城瘾使用定位，然后重新定位。"),
        "ARRIVE_LOCATION_STALE": .init(en: "Locate again to send a fresh reading.", zhHans: "请重新定位，提交新的读数。"),
        "ARRIVE_NOT_RECORDED": .init(en: "Record your arrival here before answering.", zhHans: "先记录到达这一站，再作答。"),
        "ARRIVE_TOO_FAR": .init(en: "Walk closer to the stop, then locate again.", zhHans: "请走近这一站后重新定位。"),
        "BOARD_CURSOR_STALE": .init(en: "This list changed. Refresh and try again.", zhHans: "列表已变化，请刷新后再试。"),
        "CASH_CLOSED": .init(en: "This cash case did not complete a payment. Cash payout is closed. Choose a non-cash reason.", zhHans: "这次现金处理没有完成支付。现金发放已关闭，请改用非现金原因。"),
        "CHAPTER_REDEEMED": .init(en: "This chapter is already redeemed. Continue to the next stop.", zhHans: "本章已核销，请前往下一站。"),
        "CITY_MAP_CURSOR_STALE": .init(en: "The map changed. Refresh and try again.", zhHans: "地图已变化，请刷新后再试。"),
        "CITY_ORDERED_RESET_REQUIRED": .init(en: "The map needs to be reloaded.", zhHans: "地图需要重新加载。"),
        "CITY_QUERY_TOO_BROAD": .init(en: "That map area is too large. Zoom in and try again.", zhHans: "地图范围太大，请放大后再试。"),
        "CITY_SNAPSHOT_CHANGED": .init(en: "The map changed. Refresh and try again.", zhHans: "地图已变化，请刷新后再试。"),
        "CONFIG_INVALID": .init(en: "This stop isn't set up. Ask the organizer to fix it.", zhHans: "这一站尚未配置，请联系组织者修正。"),
        "DIRECTORY_CHANGED": .init(en: "The friend list changed. Refresh and try again.", zhHans: "好友列表已变化，请刷新后再试。"),
        "DIRECTORY_GROUP_NOT_FOUND": .init(en: "That friend group was not found.", zhHans: "未找到该好友分组。"),
        "EVENT_UNKNOWN": .init(en: "That event isn't supported. Choose a listed event and try again.", zhHans: "事件不合法，请选择已列出的事件后再试。"),
        "FEATURE_CLOSED": .init(en: "This did not complete a payment. Cash and payout stay closed on this host. Use a non-cash reward, or try again only where payments are open.", zhHans: "这次没有完成支付。本主机的现金与发放保持关闭。请改用非现金奖励，或仅在支付开放时再试。"),
        "FORBIDDEN": .init(en: "You don't have permission to do that.", zhHans: "你没有权限执行此操作。"),
        "FRIEND_INVITE_REJECTED": .init(en: "This friend invite was declined.", zhHans: "这条好友邀请已被拒绝。"),
        "FRIEND_NOT_FOUND": .init(en: "That friend was not found.", zhHans: "未找到该好友。"),
        "GAME_AUTHORITY_CONFLICT": .init(en: "Play authority changed. Confirm again.", zhHans: "执行权已变化，请重新确认。"),
        "GUILD_FORBIDDEN": .init(en: "Join this club before managing it.", zhHans: "加入后才能操作。"),
        "H5_REJECTED": .init(en: "That page was rejected.", zhHans: "该页面已被拒绝。"),
        "H5_TIMEOUT": .init(en: "That page timed out.", zhHans: "该页面已超时。"),
        "HANGOUT_CLOSED": .init(en: "This conversation is closed.", zhHans: "此会话已关闭。"),
        "IM_CONVERSATION_CLOSED": .init(en: "This conversation is closed.", zhHans: "此会话已关闭。"),
        "INTENT_ACTION_REUSED": .init(en: "This action was already used for different input. Start a new attempt.", zhHans: "这次操作已用于另一份输入，请重新开始一次。"),
        "INTENT_INPUT_INVALID": .init(en: "That action isn't valid. Check it and try again.", zhHans: "这次操作无效，请检查后再试。"),
        "INTENT_PENDING": .init(en: "Check this same action later. Do not start a new one.", zhHans: "请稍后查询同一次操作，不要重新开始。"),
        "INTENT_SCOPE_DENIED": .init(en: "You don't have permission for this play. Open a run you can join.", zhHans: "你没有这次游玩的权限，请打开可参加的对局。"),
        "INTENT_SESSION_ENDED": .init(en: "This run has ended. Start a new run.", zhHans: "本局已结束，请开始新的一局。"),
        "INTENT_SESSION_MISMATCH": .init(en: "This run is not yours. Open your own run.", zhHans: "这不是你的对局，请打开自己的对局。"),
        "INTENT_STALE_STATE": .init(en: "Refresh this run, then try again.", zhHans: "请刷新本局后再试。"),
        "INVALID_INPUT": .init(en: "That input isn't valid. Check it and try again.", zhHans: "输入无效，请检查后再试。"),
        "LEDGER_OFF": .init(en: "Bookings temporarily unavailable.", zhHans: "预约暂时不可用。"),
        "LOGIN_REQUIRED": .init(en: "Sign in first.", zhHans: "请先登录"),
        "MERCHANT_ENVIRONMENT_EXIT": .init(en: "The original request used the fixed safe exit.", zhHans: "原请求的固定安全退出"),
        "MERCHANT_EXITED": .init(en: "The merchant has left this program.", zhHans: "商家已退出该活动。"),
        "MESSAGE_CONTEXT_UNAVAILABLE": .init(en: "That message is unavailable.", zhHans: "这条消息暂不可用。"),
        "MESSAGE_VERSION_CONFLICT": .init(en: "This message changed. Refresh and try again.", zhHans: "这条消息已变化，请刷新后再试。"),
        "NICKNAME_INVALID": .init(en: "That name can't be used.", zhHans: "这个名字无法使用。"),
        "NICKNAME_SUFFIX_EXHAUSTED": .init(en: "No available name suggestion is left.", zhHans: "没有可用的名字建议了。"),
        "NICKNAME_TAKEN": .init(en: "That name is already taken.", zhHans: "这个名字已被使用。"),
        "NODE_DELISTED": .init(en: "It cannot be completed now. Stops you already finished stay in your history.", zhHans: "现在无法完成。已完成的站点仍保留在记录中。"),
        "NODE_NOT_FOUND": .init(en: "That stop was not found. Refresh the route.", zhHans: "未找到这一站，请刷新路线。"),
        "NOT_CONFIRM": .init(en: "This isn't confirmed yet. Confirm it before continuing.", zhHans: "尚未确认，请先确认后再继续。"),
        "NOT_FOUND": .init(en: "That item was not found. Refresh and try again.", zhHans: "未找到对应内容，请刷新后再试。"),
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
        "PUZZLE_STATE_UNAVAILABLE": .init(en: "The puzzle couldn't be read. Try again.", zhHans: "解谜状态暂时读不到，请重试。"),
        "RELATION_UNAVAILABLE": .init(en: "The service refused this relationship. Sharing stopped and the received location was cleared.", zhHans: "服务端拒绝当前关系授权。已同步停止采集并清除接收位置。"),
        "REQUEST_ID_CONFLICT": .init(en: "This request conflicts with an earlier one.", zhHans: "此请求与先前的请求冲突。"),
        "REQUEST_OUTCOME_UNKNOWN": .init(en: "The result is still unknown. Check the original request before trying again.", zhHans: "结果尚未确定，请先核对原请求再试。"),
        "REQUEST_REJECTED": .init(en: "That request was not accepted.", zhHans: "请求未被接受。"),
        "RESERVATION_OFF": .init(en: "Bookings temporarily unavailable.", zhHans: "预约暂时不可用。"),
        "RESERVED_ELSEWHERE": .init(en: "This unit is already reserved elsewhere.", zhHans: "该次数已预约其他门店。"),
        "REVISION_CONFLICT": .init(en: "This subscription changed. Refresh and try again.", zhHans: "订阅已被修改，请刷新后再试。"),
        "ROUTE_EGG_OFFLINE": .init(en: "Route eggs are offline. Continue without collecting one.", zhHans: "途中彩蛋已下线。请继续路线，不必再领取。"),
        "ROUTE_LOCKED": .init(en: "Refresh to see which stop comes first.", zhHans: "请刷新，查看应先去哪一站。"),
        "SCAN_CODE_AMBIGUOUS": .init(en: "That code matches more than one stop. Scan the code for this stop.", zhHans: "这个码对应多个站点，请扫描这一站的码。"),
        "SCAN_CODE_EXPIRED": .init(en: "That code has expired. Scan a current one.", zhHans: "这个码已过期，请扫描仍有效的码。"),
        "SCAN_CODE_INVALID": .init(en: "That code isn't valid. Scan the code for this stop.", zhHans: "核销码无效，请扫描这一站的码。"),
        "SCAN_CODE_NODE_MISMATCH": .init(en: "That code is for a different stop. Scan this stop's code.", zhHans: "这个码属于另一站，请扫描这一站的码。"),
        "SCAN_CODE_USED": .init(en: "That code was already used. Ask for a new one.", zhHans: "这个码已使用，请换一个新码。"),
        "SCREENING_PENDING": .init(en: "Finish the existing rules first. The welcome screen does not replace them and does not resend a message.", zhHans: "请先完成原逐条规则。欢迎屏不能替代规则同意，也不触发重发消息。"),
        "SENSOR_REJECTED": .init(en: "The sensor check didn't pass. Complete the challenge again.", zhHans: "传感器判定未通过，请重新完成挑战。"),
        "STORE_SCAN_REQUIRED": .init(en: "Location cannot replace the merchant's scan here.", zhHans: "这里不能用定位代替商家扫码。"),
        "TASK_REQUIRED": .init(en: "Arrival alone does not complete this stop.", zhHans: "仅到达不能完成这一站。"),
        "TEAM_LEAD_REQUIRED": .init(en: "The leader releases this chapter before anyone can continue.", zhHans: "队长放行本章后才能继续。"),
        "UNKNOWN": .init(en: "The result is still unknown. Please try again later.", zhHans: "结果尚未确定，请稍后再试。"),
        "US_APPLE_INVALID_CHALLENGE": .init(en: "Sign in with Apple expired. Please try again.", zhHans: "通过 Apple 登录已过期，请重试。"),
        "US_APPLE_INVALID_IDENTITY": .init(en: "Apple couldn't confirm this sign-in.", zhHans: "Apple 未能确认这次登录。"),
        "US_APPLE_INVALID_REQUEST": .init(en: "Sign in with Apple couldn't be started. Please try again.", zhHans: "无法开始通过 Apple 登录，请重试。"),
        "US_APPLE_RATE_LIMITED": .init(en: "Too many sign-in attempts. Please wait and try again.", zhHans: "登录尝试过于频繁，请稍后再试。"),
        "US_APPLE_UNAVAILABLE": .init(en: "Sign in with Apple is unavailable right now.", zhHans: "通过 Apple 登录暂不可用。"),
        "US_SESSION_UNAVAILABLE": .init(en: "Sign-in is unavailable right now. Please try again.", zhHans: "登录暂不可用，请重试。"),
        "VERSION_CONFLICT": .init(en: "This item changed. Refresh and try again.", zhHans: "内容已变化，请刷新后再试。"),
        "WEBHOOK_BODY_INVALID": .init(en: "The webhook body must be JSON with content of 1–2000 characters. Fix it and send again.", zhHans: "Webhook 正文须为含 1–2000 字 content 的 JSON，请修正后再发。"),
        "WEBHOOK_BODY_TOO_LARGE": .init(en: "That webhook body is too large. Shorten it and try again.", zhHans: "Webhook 请求体过大，请缩短后再试。"),
        "WEBHOOK_CHANGE_INVALID": .init(en: "That webhook name isn't valid. Use 1–64 characters and try again.", zhHans: "名称不合法，请使用 1–64 字的名称后再试。"),
        "WEBHOOK_CHANNEL_UNAVAILABLE": .init(en: "This channel can't receive the webhook. Check the channel and try again.", zhHans: "该频道无法接收 Webhook，请检查频道后再试。"),
        "WEBHOOK_CONTENT_BLOCKED": .init(en: "That content was blocked. Change it and send again.", zhHans: "内容未通过审核，请修改后再发。"),
        "WEBHOOK_CRYPTO_UNAVAILABLE": .init(en: "Webhook signing isn't configured. Set the encryption key, then try again.", zhHans: "签名密钥加密未配置，请配置后再试。"),
        "WEBHOOK_ENDPOINT_PAUSED": .init(en: "This webhook endpoint is paused. Resume it before sending again.", zhHans: "该 Webhook 端点已暂停，请恢复后再发送。"),
        "WEBHOOK_FORBIDDEN": .init(en: "You can't manage webhooks here. Ask a manager, then try again.", zhHans: "你无权管理该频道的 Webhook，请联系管理员后再试。"),
        "WEBHOOK_INBOUND_UNAVAILABLE": .init(en: "Inbound webhooks aren't configured. Set the receive address and encryption key, then try again.", zhHans: "入站 Webhook 未配置接收地址或加密密钥，请配置后再试。"),
        "WEBHOOK_IP_NOT_ALLOWED": .init(en: "This address isn't allowed. Use an allowed address.", zhHans: "来源地址不在白名单内，请改用允许的地址。"),
        "WEBHOOK_NONCE_INVALID": .init(en: "The webhook nonce isn't valid. Send a new nonce of 16–64 characters.", zhHans: "Webhook nonce 无效，请使用 16–64 位的新 nonce。"),
        "WEBHOOK_NOT_FOUND": .init(en: "That webhook was not found. Refresh the list.", zhHans: "未找到该 Webhook，请刷新列表。"),
        "WEBHOOK_PAUSED": .init(en: "This subscription is paused. Resume it before testing again.", zhHans: "订阅已暂停，请恢复后再测试。"),
        "WEBHOOK_RATE_LIMITED": .init(en: "Too many webhook calls. Wait and try again.", zhHans: "Webhook 调用过于频繁，请稍后再试。"),
        "WEBHOOK_REPLAYED": .init(en: "This webhook was already received. Send a new nonce.", zhHans: "这条 Webhook 已接收过，请换新的 nonce。"),
        "WEBHOOK_RESULT_UNKNOWN": .init(en: "The webhook result is still unknown. Check the original delivery before trying again.", zhHans: "回调结果尚未确定，请先核对原投递再试。"),
        "WEBHOOK_SECRET_UNRECOVERABLE": .init(en: "The signing secret can't be recovered. Rotate the secret, then try again.", zhHans: "签名密钥无法恢复，请轮换密钥后再试。"),
        "WEBHOOK_SIGNATURE_INVALID": .init(en: "The signature doesn't match. Sign again with the endpoint secret.", zhHans: "签名不匹配，请用端点密钥重新签名。"),
        "WEBHOOK_TIMESTAMP_OUT_OF_WINDOW": .init(en: "The webhook timestamp is outside the allowed window. Send a current timestamp.", zhHans: "Webhook 时间戳超出允许窗口，请使用当前时间重发。"),
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
        "券库存不足,核销失败": .init(en: "Not enough coupons. Redeem failed.", zhHans: "券库存不足,核销失败"),
        "参数错误": .init(en: "Bad parameter.", zhHans: "参数错误"),
        "商家不存在或未开放": .init(en: "This store is unavailable.", zhHans: "商家不存在或未开放"),
        "定位精度不足": .init(en: "Location accuracy is too low.", zhHans: "定位精度不足"),
        "已过期": .init(en: "This has expired.", zhHans: "已过期"),
        "当前身份暂不支持": .init(en: "This account can't do that.", zhHans: "当前身份暂不支持"),
        "据点不存在": .init(en: "That place was not found.", zhHans: "据点不存在"),
        "无权核销该据点": .init(en: "You can't redeem at this place.", zhHans: "无权核销该据点"),
        "无法访问系统资源": .init(en: "Can't access this resource.", zhHans: "无法访问系统资源"),
        "核销码无效": .init(en: "Bad code.", zhHans: "核销码无效"),
        "核销码格式错误": .init(en: "Bad code format.", zhHans: "核销码格式错误"),
        "格式错误": .init(en: "Bad format.", zhHans: "格式错误"),
        "玩家未到店打卡,或该券已核销": .init(en: "Check in at the store first, or this coupon was already redeemed.", zhHans: "玩家未到店打卡,或该券已核销"),
        "登录状态已失效": .init(en: "Your session has expired. Please sign in again.", zhHans: "登录已过期，请重新登录。"),
        "空码": .init(en: "No code", zhHans: "空码"),
        "签名不匹配": .init(en: "Sign doesn't match.", zhHans: "签名不匹配"),
        "订单已过期": .init(en: "This order has expired.", zhHans: "订单已过期"),
        "认证失败": .init(en: "Sign-in failed.", zhHans: "认证失败"),
        "请先登录": .init(en: "Sign in first.", zhHans: "请先登录"),
        "途中彩蛋已下线": .init(en: "Route eggs are offline. Continue without collecting one.", zhHans: "途中彩蛋已下线。请继续路线，不必再领取。"),
        "通知不存在": .init(en: "That notice was not found.", zhHans: "通知不存在"),
        "非据点核销码": .init(en: "That is not a place redemption code.", zhHans: "非据点核销码"),
    ]
}
