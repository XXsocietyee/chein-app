import XCTest
@testable import QuestifyCore

final class BackendErrorCatalogTests: XCTestCase {
    func testUnknownCodeStaysGenericAndHidesServerText() {
        let generic = BackendErrorCatalog.generic
        XCTAssertEqual(
            BackendErrorCatalog.sentence(code: "NOT_A_REAL_CODE", status: 401, message: "请先登录", language: .en),
            generic.en)
        XCTAssertEqual(
            BackendErrorCatalog.sentence(code: "NOT_A_REAL_CODE", message: "请先登录", language: .zhHans),
            generic.zhHans)
        XCTAssertFalse(generic.en.contains("NOT_A_REAL_CODE"))
        XCTAssertFalse(BackendErrorCatalog.sentence(code: "NOPE", message: "raw server text", language: .en).contains("raw server text"))
    }

    func testKnownCodeMessageAndStatus() {
        XCTAssertEqual(BackendErrorCatalog.sentence(code: "FORBIDDEN", language: .en), "You don't have permission to do that.")
        XCTAssertEqual(BackendErrorCatalog.sentence(code: "FORBIDDEN", language: .zhHans), "你没有权限执行此操作。")
        XCTAssertEqual(
            BackendErrorCatalog.sentence(code: "UNKNOWN", language: .en),
            "The result is still unknown. Please try again later.")
        XCTAssertNotEqual(BackendErrorCatalog.sentence(code: "UNKNOWN", language: .en), BackendErrorCatalog.generic.en)
        XCTAssertEqual(BackendErrorCatalog.sentence(code: nil, message: "请先登录", language: .zhHans), "请先登录")
        XCTAssertEqual(BackendErrorCatalog.sentence(code: nil, message: "请先登录", language: .en), "Sign in first.")
        XCTAssertEqual(BackendErrorCatalog.sentence(code: nil, status: 401, language: .zhHans), "登录已过期，请重新登录。")
        XCTAssertEqual(BackendErrorCatalog.sentence(code: nil, status: 418, language: .en), BackendErrorCatalog.generic.en)
        XCTAssertEqual(
            BackendErrorCatalog.sentence(code: "  FORBIDDEN  ", message: "请先登录", language: .en),
            "You don't have permission to do that.")
    }

    func testMissingConfigurationThrowsBeforeAnyRequest() {
        XCTAssertThrowsError(try BackendErrorCatalog.requireConfiguration(baseURL: "", realm: "realm")) { error in
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
        XCTAssertThrowsError(try BackendErrorCatalog.requireConfiguration(baseURL: "https://example.invalid", realm: "")) { error in
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
        XCTAssertThrowsError(try BackendErrorCatalog.requireConfiguration(baseURL: "  ", realm: "realm")) { error in
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
        XCTAssertNoThrow(try BackendErrorCatalog.requireConfiguration(baseURL: "https://example.invalid", realm: "realm"))
    }

    func testNewlyMappedCodesSayWhatToDoNext() {
        let table: [(String, String, String)] = [
            ("501", "That action isn't implemented yet. Try a different action.", "此接口尚未实现，请改用其他操作。"),
            ("601", "The service sent a warning. Read it and try again.", "服务返回了警告，请查看后再试。"),
            ("ADVANCED_FIRST", "Finish this stop's task before arriving.", "请先完成这一站的任务，再记录到达。"),
            ("ANSWER_WRONG", "That answer wasn't accepted. Submit a new answer.", "答案不正确，请提交新的答案。"),
            ("ARRIVE_ACCURACY_INVALID", "Locate again. This is not a cheating verdict.", "请重新定位。这不是作弊判定。"),
            ("ARRIVE_ACCURACY_LOW", "Move into the open and locate again. A weak signal does not widen the stop's area.", "请到开阔处重新定位。信号差不会放宽这一站的范围。"),
            ("ARRIVE_ACCURACY_MISSING", "Locate again so the reading includes its accuracy. This is not a cheating verdict.", "请重新定位，让读数带上精度。这不是作弊判定。"),
            ("ARRIVE_COORD_NOT_CONFIGURED", "Trying again will not help. The organizer needs to fix this stop.", "重试不会成功，需要组织者修正这一站。"),
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
            ("CONFIG_INVALID", "This stop isn't set up. Ask the organizer to fix it.", "这一站尚未配置，请联系组织者修正。"),
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
        ]
        for row in table {
            XCTAssertEqual(BackendErrorCatalog.sentence(code: row.0, language: .en), row.1, row.0)
            XCTAssertEqual(BackendErrorCatalog.sentence(code: row.0, language: .zhHans), row.2, row.0)
            XCTAssertNotEqual(row.1, "0", row.0)
            XCTAssertNotEqual(row.1, "—", row.0)
            XCTAssertFalse(row.1.isEmpty, row.0)
            XCTAssertFalse(row.2.isEmpty, row.0)
        }
        XCTAssertEqual(
            BackendErrorCatalog.sentence(code: nil, message: "途中彩蛋已下线", language: .en),
            "Route eggs are offline. Continue without collecting one.")
        XCTAssertFalse(BackendErrorCatalog.sentence(code: "FEATURE_CLOSED", language: .en).contains("Payment complete"))
        XCTAssertFalse(BackendErrorCatalog.sentence(code: "FEATURE_CLOSED", language: .zhHans).contains("支付成功"))
        XCTAssertFalse(BackendErrorCatalog.sentence(code: "CASH_CLOSED", language: .en).contains("Payment complete"))
        XCTAssertFalse(BackendErrorCatalog.sentence(code: "CASH_CLOSED", language: .zhHans).contains("支付成功"))
    }

    func testUnknownMarkIsAnEmDashAndClosedCodesAreNotPayments() {
        XCTAssertEqual(BackendErrorCatalog.unknownMark, "—")
        XCTAssertNotEqual(BackendErrorCatalog.unknownMark, "0")
        XCTAssertFalse(BackendErrorCatalog.unknownMark.isEmpty)
        XCTAssertEqual(BackendErrorCatalog.playerFacing(code: nil, language: .en), "—")
        XCTAssertEqual(BackendErrorCatalog.playerFacing(code: "0", language: .zhHans), "—")
        XCTAssertEqual(BackendErrorCatalog.playerFacing(code: "unknown", language: .en), "—")
        XCTAssertEqual(BackendErrorCatalog.playerFacing(code: "  ", message: "0", language: .en), "—")
        XCTAssertEqual(
            BackendErrorCatalog.playerFacing(code: "FEATURE_CLOSED", language: .zhHans),
            "这次没有完成支付。本主机的现金与发放保持关闭。请改用非现金奖励，或仅在支付开放时再试。")
        XCTAssertNotEqual(
            BackendErrorCatalog.sentence(code: "UNKNOWN", language: .en),
            BackendErrorCatalog.unknownMark)
        XCTAssertFalse(BackendErrorCatalog.paymentSucceeded(
            code: "FEATURE_CLOSED", moneyPaymentsOpen: true, payoutOpen: true, merchantWritesOpen: true, passwordLoginOpen: true))
        XCTAssertFalse(BackendErrorCatalog.paymentSucceeded(
            code: "CASH_CLOSED", moneyPaymentsOpen: true, payoutOpen: true, merchantWritesOpen: true, passwordLoginOpen: true))
        XCTAssertFalse(BackendErrorCatalog.paymentSucceeded(
            code: nil, moneyPaymentsOpen: false, payoutOpen: false, merchantWritesOpen: false, passwordLoginOpen: false))
        XCTAssertFalse(BackendErrorCatalog.paymentSucceeded(
            code: nil, moneyPaymentsOpen: true, payoutOpen: true, merchantWritesOpen: true, passwordLoginOpen: true))
    }
}
