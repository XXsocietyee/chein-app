#!/usr/bin/env python3
"""CB50 local error catalog. Authoring source for the Swift map, the string catalog, and the release note.

The sentences are the user-facing text for codes and messages this repository already
compares or stores. An unknown code stays the generic sentence. Nothing here opens a
socket or names a new endpoint.
"""
from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SWIFT_PATH = ROOT / "Core" / "BackendErrorCatalog.swift"
CATALOG_PATH = ROOT / "Resources" / "BackendErrorCatalog.xcstrings"
DOC_PATH = ROOT / "docs" / "release" / "cb50-errors.md"

GENERIC = {
    "en": "Something went wrong. Please try again.",
    "zh-Hans": "出了点问题，请重试。",
}

# (token, en, zh-Hans). Numeric business and HTTP statuses the client already branches on.
STATUSES = [
    ("2", "Your session has expired. Please sign in again.", "登录已过期，请重新登录。"),
    ("400", "That request was not accepted. Check it and try again.", "请求未被接受，请检查后再试。"),
    ("401", "Your session has expired. Please sign in again.", "登录已过期，请重新登录。"),
    ("403", "You don't have permission to do that.", "你没有权限执行此操作。"),
    ("404", "That item was not found.", "未找到对应内容。"),
    ("405", "That request was refused.", "请求被拒绝。"),
    ("408", "The result is still unknown. Please try again later.", "结果尚未确定，请稍后再试。"),
    ("409", "This item changed. Refresh and try again.", "内容已变化，请刷新后再试。"),
    ("410", "That item is no longer available.", "该内容已不可用。"),
    ("413", "That request is too large.", "请求过大。"),
    ("415", "That request isn't in a supported format.", "请求格式不受支持。"),
    ("422", "That request was not accepted.", "请求未被接受。"),
    ("426", "This app version is no longer supported. Update the app before continuing.", "当前应用版本已不受支持，请更新应用后再继续。"),
    ("429", "Too many attempts. Please wait and try again.", "操作过于频繁，请稍后再试。"),
    ("500", "The service couldn't complete that. Please try again.", "服务未能完成此操作，请重试。"),
    ("503", "The service is unavailable right now. Please try again.", "服务暂不可用，请重试。"),
    ("520", "The original result is still unknown.", "原命令结果仍未知。"),
    ("501", "That action isn't implemented yet. Try a different action.", "此接口尚未实现，请改用其他操作。"),
    ("601", "The service sent a warning. Read it and try again.", "服务返回了警告，请查看后再试。"),
]

# Machine codes the client already matches. Unknown tokens are not added here.
CODES = [
    ("BOARD_CURSOR_STALE", "This list changed. Refresh and try again.", "列表已变化，请刷新后再试。"),
    ("CITY_MAP_CURSOR_STALE", "The map changed. Refresh and try again.", "地图已变化，请刷新后再试。"),
    ("CITY_ORDERED_RESET_REQUIRED", "The map needs to be reloaded.", "地图需要重新加载。"),
    ("CITY_QUERY_TOO_BROAD", "That map area is too large. Zoom in and try again.", "地图范围太大，请放大后再试。"),
    ("CITY_SNAPSHOT_CHANGED", "The map changed. Refresh and try again.", "地图已变化，请刷新后再试。"),
    ("DIRECTORY_CHANGED", "The friend list changed. Refresh and try again.", "好友列表已变化，请刷新后再试。"),
    ("DIRECTORY_GROUP_NOT_FOUND", "That friend group was not found.", "未找到该好友分组。"),
    ("FORBIDDEN", "You don't have permission to do that.", "你没有权限执行此操作。"),
    ("FRIEND_INVITE_REJECTED", "This friend invite was declined.", "这条好友邀请已被拒绝。"),
    ("FRIEND_NOT_FOUND", "That friend was not found.", "未找到该好友。"),
    ("GAME_AUTHORITY_CONFLICT", "Play authority changed. Confirm again.", "执行权已变化，请重新确认。"),
    ("H5_REJECTED", "That page was rejected.", "该页面已被拒绝。"),
    ("H5_TIMEOUT", "That page timed out.", "该页面已超时。"),
    ("HANGOUT_CLOSED", "This conversation is closed.", "此会话已关闭。"),
    ("IM_CONVERSATION_CLOSED", "This conversation is closed.", "此会话已关闭。"),
    ("LEDGER_OFF", "Reservations are temporarily unavailable.", "预约暂时不可用。"),
    ("LOGIN_REQUIRED", "Sign in first.", "请先登录"),
    ("MERCHANT_ENVIRONMENT_EXIT", "The original request used the fixed safe exit.", "原请求的固定安全退出"),
    ("MERCHANT_EXITED", "The merchant has left this program.", "商家已退出该活动。"),
    ("MESSAGE_CONTEXT_UNAVAILABLE", "That message is unavailable.", "这条消息暂不可用。"),
    ("MESSAGE_VERSION_CONFLICT", "This message changed. Refresh and try again.", "这条消息已变化，请刷新后再试。"),
    ("NICKNAME_INVALID", "That name can't be used.", "这个名字无法使用。"),
    ("NICKNAME_SUFFIX_EXHAUSTED", "No available name suggestion is left.", "没有可用的名字建议了。"),
    ("NICKNAME_TAKEN", "That name is already taken.", "这个名字已被使用。"),
    ("NO_AUTHORITY", "You don't have permission to do that.", "你没有权限执行此操作。"),
    ("NO_BALANCE", "You have no available units left.", "你没有可用的次数。"),
    ("NOT_YET_VALID", "This offer is not valid yet.", "该优惠尚未生效。"),
    ("OFFER_EXPIRED", "This offer has expired.", "该优惠已过期。"),
    ("ORIENT_LOGIN_REQUIRED", "Sign in to your own account to view this round.", "请登录本人账号查看对局"),
    ("ORIENT_RECEIPT_NOT_FOUND", "That receipt was not found.", "未找到该回执。"),
    ("OUTCOME_UNKNOWN", "The result is still unknown. Check the original request before trying again.", "结果尚未确定，请先核对原请求再试。"),
    ("OUTSIDE_VALIDITY", "The chosen time is outside your validity period.", "所选时间不在有效期内。"),
    ("POLICY_CHANGED", "The service refused the current sharing policy. Sharing stopped and the received location was cleared.", "服务端拒绝当前共享政策。已同步停止采集并清除接收位置。"),
    ("POLICY_UNAVAILABLE", "The service refused the current sharing policy. Sharing stopped and the received location was cleared.", "服务端拒绝当前共享政策。已同步停止采集并清除接收位置。"),
    ("PREFLIGHT_BINDING_MISMATCH", "That check doesn't match this account.", "该校验与当前账号不符。"),
    ("PREFLIGHT_CONSUMED", "That check was already used.", "该校验已被使用。"),
    ("PREFLIGHT_EXPIRED", "That check expired. Start again.", "该校验已过期，请重新开始。"),
    ("PREFLIGHT_INPUT_INVALID", "That check input is not valid.", "该校验内容无效。"),
    ("PREFLIGHT_INTENT_CLOSED", "That request is closed.", "该请求已关闭。"),
    ("PREFLIGHT_INTENT_CONFLICT", "That request conflicts with another one.", "该请求与另一请求冲突。"),
    ("PREFLIGHT_NOT_FOUND", "That check was not found.", "未找到该校验。"),
    ("PREFLIGHT_REJECTED", "That check was not accepted.", "该校验未被接受。"),
    ("PREFLIGHT_STATE_CHANGED", "That check changed. Start again.", "该校验已变化，请重新开始。"),
    ("PRIVACY_CONFLICT", "Privacy settings changed. Refresh and try again.", "隐私设置已变化，请刷新后再试。"),
    ("PROGRESS_REQUEST_NOT_FOUND", "That progress request was not found.", "未找到该进度请求。"),
    ("RELATION_UNAVAILABLE", "The service refused this relationship. Sharing stopped and the received location was cleared.", "服务端拒绝当前关系授权。已同步停止采集并清除接收位置。"),
    ("REQUEST_ID_CONFLICT", "This request conflicts with an earlier one.", "此请求与先前的请求冲突。"),
    ("REQUEST_OUTCOME_UNKNOWN", "The result is still unknown. Check the original request before trying again.", "结果尚未确定，请先核对原请求再试。"),
    ("REQUEST_REJECTED", "That request was not accepted.", "请求未被接受。"),
    ("RESERVATION_OFF", "Reservations are temporarily unavailable.", "预约暂时不可用。"),
    ("RESERVED_ELSEWHERE", "This unit is already reserved elsewhere.", "该次数已预约其他门店。"),
    ("SCREENING_PENDING", "Finish the existing rules first. The welcome screen does not replace them and does not resend a message.", "请先完成原逐条规则。欢迎屏不能替代规则同意，也不触发重发消息。"),
    ("UNKNOWN", "The result is still unknown. Please try again later.", "结果尚未确定，请稍后再试。"),
    ("US_APPLE_INVALID_CHALLENGE", "Sign in with Apple expired. Please try again.", "通过 Apple 登录已过期，请重试。"),
    ("US_APPLE_INVALID_IDENTITY", "Apple couldn't confirm this sign-in.", "Apple 未能确认这次登录。"),
    ("US_APPLE_INVALID_REQUEST", "Sign in with Apple couldn't be started. Please try again.", "无法开始通过 Apple 登录，请重试。"),
    ("US_APPLE_RATE_LIMITED", "Too many sign-in attempts. Please wait and try again.", "登录尝试过于频繁，请稍后再试。"),
    ("US_APPLE_UNAVAILABLE", "Sign in with Apple is unavailable right now.", "通过 Apple 登录暂不可用。"),
    ("US_SESSION_UNAVAILABLE", "Sign-in is unavailable right now. Please try again.", "登录暂不可用，请重试。"),
    ("VERSION_CONFLICT", "This item changed. Refresh and try again.", "内容已变化，请刷新后再试。"),
    ("WEBHOOK_RESULT_UNKNOWN", "The webhook result is still unknown. Check the original delivery before trying again.", "回调结果尚未确定，请先核对原投递再试。"),
    ("ADVANCED_FIRST", "Finish this stop's task before arriving.", "请先完成这一站的任务，再记录到达。"),
    ("ANSWER_WRONG", "That answer wasn't accepted. Submit a new answer.", "答案不正确，请提交新的答案。"),
    ("ARRIVE_ACCURACY_INVALID", "Locate again. This is not a cheating verdict.", "请重新定位。这不是作弊判定。"),
    ("ARRIVE_ACCURACY_LOW", "Move into the open and locate again. A weak signal does not widen the stop's area.", "请到开阔处重新定位。信号差不会放宽这一站的范围。"),
    ("ARRIVE_ACCURACY_MISSING", "Locate again so the reading includes its accuracy. This is not a cheating verdict.", "请重新定位，让读数带上精度。这不是作弊判定。"),
    ("ARRIVE_COORD_NOT_CONFIGURED", "Trying again will not help. The organiser needs to fix this stop.", "重试不会成功，需要组织者修正这一站。"),
    ("ARRIVE_FIRST", "Record your arrival at this stop before answering.", "先记录到达这一站，再作答。"),
    ("ARRIVE_GUARD_SPEED", "Sending again would be refused the same way. Check this on the stop again on site.", "再次发送也会被同样拒绝，请在现场重新核验。"),
    ("ARRIVE_GUARD_THROTTLE", "Wait a moment, then locate again.", "请稍等片刻再重新定位。"),
    ("ARRIVE_GUARD_WINDOW_DISTANCE", "Sending again would be refused the same way. Check this on the stop again on site.", "再次发送也会被同样拒绝，请在现场重新核验。"),
    ("ARRIVE_LOCATION_INVALID", "Locate again and send the new reading.", "请重新定位后再提交新的读数。"),
    ("ARRIVE_LOCATION_MISSING", "Allow location for Chein, then locate again.", "请允许城瘾使用定位，然后重新定位。"),
    ("ARRIVE_LOCATION_STALE", "Locate again to send a fresh reading.", "请重新定位，提交新的读数。"),
    ("ARRIVE_NOT_RECORDED", "Record your arrival here before answering.", "先记录到达这一站，再作答。"),
    ("ARRIVE_TOO_FAR", "Walk closer to the stop, then locate again.", "请走近这一站后重新定位。"),
    ("CASH_CLOSED", "This cash case did not complete a payment. Cash payout is closed. Choose a non-cash reason.", "这次现金处理没有完成支付。现金发放已关闭，请改用非现金原因。"),
    ("CHAPTER_REDEEMED", "This chapter is already redeemed. Continue to the next stop.", "本章已核销，请前往下一站。"),
    ("CONFIG_INVALID", "This stop isn't set up. Ask the organiser to fix it.", "这一站尚未配置，请联系组织者修正。"),
    ("EVENT_UNKNOWN", "That event isn't supported. Choose a listed event and try again.", "事件不合法，请选择已列出的事件后再试。"),
    ("FEATURE_CLOSED", "This did not complete a payment. Cash and payout stay closed on this host. Use a non-cash reward, or try again only where payments are open.", "这次没有完成支付。本主机的现金与发放保持关闭。请改用非现金奖励，或仅在支付开放时再试。"),
    ("GUILD_FORBIDDEN", "Join this club before managing it.", "加入后才能操作。"),
    ("INTENT_ACTION_REUSED", "This action was already used for different input. Start a new attempt.", "这次操作已用于另一份输入，请重新开始一次。"),
    ("INTENT_INPUT_INVALID", "That action isn't valid. Check it and try again.", "这次操作无效，请检查后再试。"),
    ("INTENT_PENDING", "Check this same action later. Do not start a new one.", "请稍后查询同一次操作，不要重新开始。"),
    ("INTENT_SCOPE_DENIED", "You don't have permission for this play. Open a run you can join.", "你没有这次游玩的权限，请打开可参加的对局。"),
    ("INTENT_SESSION_ENDED", "This run has ended. Start a new run.", "本局已结束，请开始新的一局。"),
    ("INTENT_SESSION_MISMATCH", "This run is not yours. Open your own run.", "这不是你的对局，请打开自己的对局。"),
    ("INTENT_STALE_STATE", "Refresh this run, then try again.", "请刷新本局后再试。"),
    ("INVALID_INPUT", "That input isn't valid. Check it and try again.", "输入无效，请检查后再试。"),
    ("NODE_DELISTED", "It cannot be completed now. Stops you already finished stay in your history.", "现在无法完成。已完成的站点仍保留在记录中。"),
    ("NODE_NOT_FOUND", "That stop was not found. Refresh the route.", "未找到这一站，请刷新路线。"),
    ("NOT_CONFIRM", "This isn't confirmed yet. Confirm it before continuing.", "尚未确认，请先确认后再继续。"),
    ("NOT_FOUND", "That item was not found. Refresh and try again.", "未找到对应内容，请刷新后再试。"),
    ("PUZZLE_STATE_UNAVAILABLE", "The puzzle couldn't be read. Try again.", "解谜状态暂时读不到，请重试。"),
    ("REVISION_CONFLICT", "This subscription changed. Refresh and try again.", "订阅已被修改，请刷新后再试。"),
    ("ROUTE_EGG_OFFLINE", "Route eggs are offline. Continue without collecting one.", "途中彩蛋已下线。请继续路线，不必再领取。"),
    ("ROUTE_LOCKED", "Refresh to see which stop comes first.", "请刷新，查看应先去哪一站。"),
    ("SCAN_CODE_AMBIGUOUS", "That code matches more than one stop. Scan the code for this stop.", "这个码对应多个站点，请扫描这一站的码。"),
    ("SCAN_CODE_EXPIRED", "That code has expired. Scan a current one.", "这个码已过期，请扫描仍有效的码。"),
    ("SCAN_CODE_INVALID", "That code isn't valid. Scan the code for this stop.", "核销码无效，请扫描这一站的码。"),
    ("SCAN_CODE_NODE_MISMATCH", "That code is for a different stop. Scan this stop's code.", "这个码属于另一站，请扫描这一站的码。"),
    ("SCAN_CODE_USED", "That code was already used. Ask for a new one.", "这个码已使用，请换一个新码。"),
    ("SENSOR_REJECTED", "The sensor check didn't pass. Complete the challenge again.", "传感器判定未通过，请重新完成挑战。"),
    ("STORE_SCAN_REQUIRED", "Location cannot replace the merchant's scan here.", "这里不能用定位代替商家扫码。"),
    ("TASK_REQUIRED", "Arrival alone does not complete this stop.", "仅到达不能完成这一站。"),
    ("TEAM_LEAD_REQUIRED", "The leader releases this chapter before anyone can continue.", "队长放行本章后才能继续。"),
    ("WEBHOOK_BODY_INVALID", "The webhook body must be JSON with content of 1–2000 characters. Fix it and send again.", "Webhook 正文须为含 1–2000 字 content 的 JSON，请修正后再发。"),
    ("WEBHOOK_BODY_TOO_LARGE", "That webhook body is too large. Shorten it and try again.", "Webhook 请求体过大，请缩短后再试。"),
    ("WEBHOOK_CHANGE_INVALID", "That webhook name isn't valid. Use 1–64 characters and try again.", "名称不合法，请使用 1–64 字的名称后再试。"),
    ("WEBHOOK_CHANNEL_UNAVAILABLE", "This channel can't receive the webhook. Check the channel and try again.", "该频道无法接收 Webhook，请检查频道后再试。"),
    ("WEBHOOK_CONTENT_BLOCKED", "That content was blocked. Change it and send again.", "内容未通过审核，请修改后再发。"),
    ("WEBHOOK_CRYPTO_UNAVAILABLE", "Webhook signing isn't configured. Set the encryption key, then try again.", "签名密钥加密未配置，请配置后再试。"),
    ("WEBHOOK_ENDPOINT_PAUSED", "This webhook endpoint is paused. Resume it before sending again.", "该 Webhook 端点已暂停，请恢复后再发送。"),
    ("WEBHOOK_FORBIDDEN", "You can't manage webhooks here. Ask a manager, then try again.", "你无权管理该频道的 Webhook，请联系管理员后再试。"),
    ("WEBHOOK_INBOUND_UNAVAILABLE", "Inbound webhooks aren't configured. Set the receive address and encryption key, then try again.", "入站 Webhook 未配置接收地址或加密密钥，请配置后再试。"),
    ("WEBHOOK_IP_NOT_ALLOWED", "This address isn't allowed. Use an allowed address.", "来源地址不在白名单内，请改用允许的地址。"),
    ("WEBHOOK_NONCE_INVALID", "The webhook nonce isn't valid. Send a new nonce of 16–64 characters.", "Webhook nonce 无效，请使用 16–64 位的新 nonce。"),
    ("WEBHOOK_NOT_FOUND", "That webhook was not found. Refresh the list.", "未找到该 Webhook，请刷新列表。"),
    ("WEBHOOK_PAUSED", "This subscription is paused. Resume it before testing again.", "订阅已暂停，请恢复后再测试。"),
    ("WEBHOOK_RATE_LIMITED", "Too many webhook calls. Wait and try again.", "Webhook 调用过于频繁，请稍后再试。"),
    ("WEBHOOK_REPLAYED", "This webhook was already received. Send a new nonce.", "这条 Webhook 已接收过，请换新的 nonce。"),
    ("WEBHOOK_SECRET_UNRECOVERABLE", "The signing secret can't be recovered. Rotate the secret, then try again.", "签名密钥无法恢复，请轮换密钥后再试。"),
    ("WEBHOOK_SIGNATURE_INVALID", "The signature doesn't match. Sign again with the endpoint secret.", "签名不匹配，请用端点密钥重新签名。"),
    ("WEBHOOK_TIMESTAMP_OUT_OF_WINDOW", "The webhook timestamp is outside the allowed window. Send a current timestamp.", "Webhook 时间戳超出允许窗口，请使用当前时间重发。"),
    ("WELCOME_SCREEN_NOT_CONFIGURED", "This space has no welcome screen yet. Joining did not fail, and you do not need to resend the request.", "本空间尚未配置或未启用欢迎屏；不是加入失败，不需要重发申请。"),
    ("WITHDRAWAL_CONSENT_REQUIRED", "This withdrawal isn't available.", "此提现暂不可用。"),
]

# Exact backend message text the client already compares. Not substrings such as 权限 or 登录.
MESSAGES = [
    ("DIRECTORY_CHANGED", "The friend list changed. Refresh and try again.", "好友列表已变化，请刷新后再试。"),
    ("DIRECTORY_GROUP_NOT_FOUND", "That friend group was not found.", "未找到该好友分组。"),
    ("FRIEND_NOT_FOUND", "That friend was not found.", "未找到该好友。"),
    ("ORIENT_LOGIN_REQUIRED", "Sign in to your own account to view this round.", "请登录本人账号查看对局"),
    ("ORIENT_RECEIPT_NOT_FOUND", "That receipt was not found.", "未找到该回执。"),
    ("REQUEST_ID_CONFLICT", "This request conflicts with an earlier one.", "此请求与先前的请求冲突。"),
    ("仅主题发布者可查看候选池", "Only the topic publisher can view this pool.", "仅主题发布者可查看候选池"),
    ("仅自由探索", "This is only available for free exploration.", "仅自由探索"),
    ("仅主理人与联席主理人可查看分润", "Only the owner and co-owners can view this split.", "仅主理人与联席主理人可查看分润"),
    ("今日AI次数已用完", "Today's AI uses are used up.", "今日AI次数已用完"),
    ("参数错误", "A parameter is not valid.", "参数错误"),
    ("商家不存在或未开放", "This store is unavailable.", "商家不存在或未开放"),
    ("定位精度不足", "Location accuracy is too low.", "定位精度不足"),
    ("已过期", "This has expired.", "已过期"),
    ("当前身份暂不支持", "This account can't do that.", "当前身份暂不支持"),
    ("据点不存在", "That place was not found.", "据点不存在"),
    ("无法访问系统资源", "You can't access this right now. Please sign in again.", "无法访问系统资源"),
    ("无权核销该据点", "You can't redeem at this place.", "无权核销该据点"),
    ("格式错误", "That format is not valid.", "格式错误"),
    ("核销码无效", "That redemption code is not valid.", "核销码无效"),
    ("核销码格式错误", "That redemption code format is not valid.", "核销码格式错误"),
    ("玩家未到店打卡,或该券已核销", "Check in at the store first, or this coupon was already redeemed.", "玩家未到店打卡,或该券已核销"),
    ("登录状态已失效", "Your session has expired. Please sign in again.", "登录已过期，请重新登录。"),
    ("空码", "The redemption code is empty.", "空码"),
    ("签名不匹配", "The signature does not match.", "签名不匹配"),
    ("订单已过期", "This order has expired.", "订单已过期"),
    ("认证失败", "Sign-in could not be verified. Please sign in again.", "认证失败"),
    ("请先登录", "Sign in first.", "请先登录"),
    ("券库存不足,核销失败", "There isn't enough coupon stock, so redemption did not finish.", "券库存不足,核销失败"),
    ("通知不存在", "That notice was not found.", "通知不存在"),
    ("非据点核销码", "That is not a place redemption code.", "非据点核销码"),
    ("途中彩蛋已下线", "Route eggs are offline. Continue without collecting one.", "途中彩蛋已下线。请继续路线，不必再领取。"),
]


def _pairs(rows):
    found = {}
    for token, en, zh in rows:
        if token in found:
            raise SystemExit(f"duplicate token {token}")
        if not token.strip() or token != token.strip() or not en.strip() or not zh.strip():
            raise SystemExit(f"empty catalog text for {token!r}")
        found[token] = {"en": en, "zh-Hans": zh}
    return found


CODES_BY_TOKEN = _pairs([(token, en, zh) for token, en, zh in STATUSES] + CODES)
MESSAGES_BY_TOKEN = _pairs(MESSAGES)


def sentence(code=None, message=None, language="en", status=None):
    """Unknown non-empty code stays generic and does not read the message."""
    lang = "zh-Hans" if language in ("zh-Hans", "zh") else "en"
    token = (code or "").strip()
    if token:
        return CODES_BY_TOKEN.get(token, GENERIC)[lang]
    if status is not None:
        return CODES_BY_TOKEN.get(str(status), GENERIC)[lang]
    text = (message or "").strip()
    if not text:
        return GENERIC[lang]
    return MESSAGES_BY_TOKEN.get(text, GENERIC)[lang]


def require_configuration(base_url, realm):
    if not (base_url or "").strip() or not (realm or "").strip():
        raise LookupError("notConfigured")


def _swift_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _swift_map(name, rows):
    lines = [f"    private static let {name}: [String: Sentence] = ["]
    for token, en, zh in rows:
        lines.append(
            f"        {_swift_string(token)}: .init(en: {_swift_string(en)}, zhHans: {_swift_string(zh)}),"
        )
    lines.append("    ]")
    return "\n".join(lines)


def render_swift():
    status_rows = [(token, CODES_BY_TOKEN[token]["en"], CODES_BY_TOKEN[token]["zh-Hans"]) for token, _, _ in STATUSES]
    code_rows = sorted(CODES, key=lambda row: row[0])
    message_rows = sorted(MESSAGES, key=lambda row: row[0])
    body = f"""import Foundation

/// Local map of backend error codes and messages this repository already names.
/// A non-empty unknown code stays the generic sentence and does not reveal the
/// raw code or the server message. Lookup never builds a URL. Call
/// `requireConfiguration` before any request: an empty base URL or realm throws
/// `APIError.notConfigured` and no request is created.
public enum BackendErrorLanguage: Equatable {{
    case en
    case zhHans
}}

public enum BackendErrorCatalog {{
    public struct Sentence: Equatable {{
        public let en: String
        public let zhHans: String
        public func text(_ language: BackendErrorLanguage) -> String {{
            language == .zhHans ? zhHans : en
        }}
    }}

    public static let generic = Sentence(en: {_swift_string(GENERIC["en"])}, zhHans: {_swift_string(GENERIC["zh-Hans"])})

    /// A missing value. Never `0` and never blank.
    public static let unknownMark = "—"

    public static func sentence(code: String?, status: Int? = nil, message: String? = nil, language: BackendErrorLanguage) -> String {{
        let token = code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !token.isEmpty {{
            return (Self.codes[token] ?? Self.generic).text(language)
        }}
        if let status {{
            return (Self.codes[String(status)] ?? Self.generic).text(language)
        }}
        let text = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {{ return Self.generic.text(language) }}
        return (Self.messages[text] ?? Self.generic).text(language)
    }}

    /// Blank, `0`, and the word `unknown` are an em dash. A known code stays its sentence.
    /// An unknown machine code stays the generic sentence. Any other token is left as written.
    public static func playerFacing(code: String?, status: Int? = nil, message: String? = nil, language: BackendErrorLanguage) -> String {{
        let token = code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if token == "0" || token == "unknown" {{ return Self.unknownMark }}
        if token.isEmpty, status == nil {{
            let text = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty || text == "0" || text == "unknown" {{ return Self.unknownMark }}
            if Self.messages[text] != nil {{ return Self.sentence(code: nil, message: text, language: language) }}
            return text
        }}
        if !token.isEmpty, Self.codes[token] != nil {{
            return Self.sentence(code: token, language: language)
        }}
        if token.range(of: "^[A-Z][A-Z0-9_]{{0,63}}$", options: .regularExpression) != nil {{
            return Self.sentence(code: token, language: language)
        }}
        if token.isEmpty {{ return Self.sentence(code: nil, status: status, message: message, language: language) }}
        return token
    }}

    /// Closed money, payout, merchant writes, and password login are not a completed payment.
    /// `FEATURE_CLOSED` and `CASH_CLOSED` are refusals even when those switches are open.
    /// This catalog does not confirm that money moved.
    public static func paymentSucceeded(code: String?, moneyPaymentsOpen: Bool, payoutOpen: Bool, merchantWritesOpen: Bool, passwordLoginOpen: Bool) -> Bool {{
        let token = code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let closedCode = token == "FEATURE_CLOSED" || token == "CASH_CLOSED"
        let areaClosed = !moneyPaymentsOpen || !payoutOpen || !merchantWritesOpen || !passwordLoginOpen
        if closedCode || areaClosed {{ return false }}
        return false
    }}

    /// Missing deployment configuration. This returns only after both values are
    /// non-empty, and it does not create a request.
    public static func requireConfiguration(baseURL: String, realm: String) throws {{
        let baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let realm = realm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.isEmpty, !realm.isEmpty else {{ throw APIError.notConfigured }}
    }}

{_swift_map("codes", status_rows + code_rows)}

{_swift_map("messages", message_rows)}
}}
"""
    return body


def _unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def catalog_key(kind, token):
    if kind == "status":
        return f"backendError.status.{token}"
    if kind == "code":
        return f"backendError.code.{token}"
    slug = {
        "DIRECTORY_CHANGED": "directoryChanged",
        "DIRECTORY_GROUP_NOT_FOUND": "directoryGroupNotFound",
        "FRIEND_NOT_FOUND": "friendNotFound",
        "ORIENT_LOGIN_REQUIRED": "orientLoginRequired",
        "ORIENT_RECEIPT_NOT_FOUND": "orientReceiptNotFound",
        "REQUEST_ID_CONFLICT": "requestIdConflict",
        "仅主题发布者可查看候选池": "publisherPoolOnly",
        "仅自由探索": "freeExploreOnly",
        "仅主理人与联席主理人可查看分润": "ownerSplitOnly",
        "今日AI次数已用完": "aiQuotaUsed",
        "参数错误": "badParameter",
        "商家不存在或未开放": "storeUnavailable",
        "定位精度不足": "locationAccuracy",
        "已过期": "expired",
        "当前身份暂不支持": "identityUnsupported",
        "据点不存在": "placeMissing",
        "无法访问系统资源": "resourceDenied",
        "无权核销该据点": "redeemForbidden",
        "格式错误": "badFormat",
        "核销码无效": "redeemCodeInvalid",
        "核销码格式错误": "redeemCodeFormat",
        "玩家未到店打卡,或该券已核销": "checkInOrRedeemed",
        "登录状态已失效": "sessionInvalid",
        "空码": "emptyCode",
        "签名不匹配": "signatureMismatch",
        "订单已过期": "orderExpired",
        "认证失败": "authenticationFailed",
        "请先登录": "signInFirst",
        "券库存不足,核销失败": "couponStock",
        "通知不存在": "noticeMissing",
        "非据点核销码": "notPlaceCode",
        "途中彩蛋已下线": "routeEggOffline",
    }[token]
    return f"backendError.message.{slug}"


def render_catalog():
    strings = {
        "backendError.unknown": {
            "localizations": {
                "en": _unit(GENERIC["en"]),
                "zh-Hans": _unit(GENERIC["zh-Hans"]),
            }
        }
    }
    for token, _, _ in STATUSES:
        entry = CODES_BY_TOKEN[token]
        strings[catalog_key("status", token)] = {
            "localizations": {"en": _unit(entry["en"]), "zh-Hans": _unit(entry["zh-Hans"])}
        }
    for token, _, _ in sorted(CODES, key=lambda row: row[0]):
        entry = CODES_BY_TOKEN[token]
        strings[catalog_key("code", token)] = {
            "localizations": {"en": _unit(entry["en"]), "zh-Hans": _unit(entry["zh-Hans"])}
        }
    for token, _, _ in sorted(MESSAGES, key=lambda row: row[0]):
        entry = MESSAGES_BY_TOKEN[token]
        strings[catalog_key("message", token)] = {
            "localizations": {"en": _unit(entry["en"]), "zh-Hans": _unit(entry["zh-Hans"])}
        }
    document = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    return json.dumps(document, ensure_ascii=False, indent=2) + "\n"


def _table(title, rows, key_kind):
    lines = [f"## {title}", "", "| Token | Catalog key | English | 简体中文 |", "|---|---|---|---|"]
    for token, en, zh in rows:
        lines.append(f"| `{token}` | `{catalog_key(key_kind, token)}` | {en} | {zh} |")
    lines.append("")
    return "\n".join(lines)


def render_doc():
    status_rows = [(token, CODES_BY_TOKEN[token]["en"], CODES_BY_TOKEN[token]["zh-Hans"]) for token, _, _ in STATUSES]
    code_rows = sorted(
        [(token, CODES_BY_TOKEN[token]["en"], CODES_BY_TOKEN[token]["zh-Hans"]) for token, _, _ in CODES],
        key=lambda row: row[0],
    )
    message_rows = sorted(MESSAGES, key=lambda row: row[0])
    return f"""# CB50 error catalog

Base: `origin/rc/20261108`. This map covers backend error codes and messages the client already compares or stores in `Core/` and `App/`. It does not add an endpoint, and it does not treat a gap-report quotation as a new code.

Lookup is local. `BackendErrorCatalog.sentence` does not read the base URL and does not send a request.

1. A non-empty code is matched after trimming. A known code returns its sentence. An unknown code returns the generic sentence below and does not reveal the raw code or the server message, even when that message is known.
2. A blank code may use one of the numeric statuses listed below. An unknown status is the same generic sentence.
3. With no code and no status, the exact trimmed message is matched. A longer sentence that only contains a known phrase stays generic. Substring classifiers such as `权限` and `登录` are not messages.
4. `UNKNOWN` is a known outcome token. It is not the generic sentence.

Generic sentence, catalog key `backendError.unknown`:

- English: {GENERIC["en"]}
- 简体中文: {GENERIC["zh-Hans"]}

`BackendErrorCatalog.requireConfiguration(baseURL:realm:)` throws `APIError.notConfigured` when the base URL or the realm is empty or whitespace. That throw is the whole body of the function, so no request is created. A non-empty pair returns without creating a request. `Config/Base.xcconfig` still leaves `QUESTIFY_API_BASE_URL` and `QUESTIFY_SESSION_REALM` empty. Password login, bank-card withdrawal, and virtual goods stay off. These sentences do not enable those writes. Version stays 0.1.0 (1).

The same pairs are in `Resources/BackendErrorCatalog.xcstrings` and `Core/BackendErrorCatalog.swift`.

{_table("Statuses", status_rows, "status")}
{_table("Codes", code_rows, "code")}
{_table("Messages", message_rows, "message")}
"""


def write_outputs():
    SWIFT_PATH.write_text(render_swift(), encoding="utf-8")
    CATALOG_PATH.write_text(render_catalog(), encoding="utf-8")
    DOC_PATH.write_text(render_doc(), encoding="utf-8")


def main(argv):
    if argv != ["--write"]:
        raise SystemExit("usage: python3 tools/backend_error_catalog.py --write")
    write_outputs()
    print(f"wrote {SWIFT_PATH.relative_to(ROOT)}, {CATALOG_PATH.relative_to(ROOT)}, {DOC_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main(sys.argv[1:])
