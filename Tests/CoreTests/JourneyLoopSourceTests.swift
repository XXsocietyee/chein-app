import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Reader coverage for the journey-api.js port. Responses are synthetic and stay in this test target.
final class JourneyLoopSourceTests: XCTestCase {
    func testJourneyCasesMatchTheMiniProgramExportsAndMoneyStaysOff() {
        XCTAssertEqual(JourneyLoopSource.sourceRevision, "1c80c5aea8f721ca8575e6108048495b100f5576")
        XCTAssertEqual(JourneyLoopSource.journey.map(\.name), Array(JourneyLoopSource.Journey.allCases))
        XCTAssertEqual(JourneyLoopSource.journey.filter(\.money).map(\.name), [.issueReferral, .giftClaim])
        XCTAssertTrue(JourneyLoopSource.journey.filter(\.money).allSatisfy { !$0.sendsWhileMoneyOff })
        XCTAssertFalse(JourneyLoopSource.journey.contains { $0.path.contains("release") })
        XCTAssertEqual(JourneyLoopSource.journey(.report).path, "/api/play/player-journey/report")
        XCTAssertEqual(JourneyLoopSource.journey(.seatClaim).method, "POST")
        XCTAssertTrue(JourneyLoopSource.journey(.rate).form)
        XCTAssertFalse(JourneyLoopSource.journey(.rate).json)
        XCTAssertFalse(JourneyLoopSource.moneyWritesEnabled)
        for kind in ReleaseMoneyWriteKind.allCases {
            XCTAssertFalse(ReleaseMoneyWriteSwitch.isEnabled(kind))
        }
    }

    func testIdQueryDropsEmptyZeroAndNullAndKeepsOrder() {
        let items = JourneyLoopSource.idQuery([
            ("activityId", "0"), ("topicId", "12"), ("runId", nil), ("blank", ""), ("kept", "00")
        ])
        XCTAssertEqual(items.map(\.name), ["topicId", "kept"])
        XCTAssertEqual(items.map(\.value), ["12", "00"])
        XCTAssertTrue(JourneyLoopSource.isRequestID("seatinv-abc-abcd1234"))
        XCTAssertFalse(JourneyLoopSource.isRequestID(""))
        XCTAssertFalse(JourneyLoopSource.isRequestID(String(repeating: "a", count: 65)))
        XCTAssertFalse(JourneyLoopSource.isRequestID("has space"))
        XCTAssertTrue(JourneyLoopSource.isID("12"))
        XCTAssertFalse(JourneyLoopSource.isID("0"))
        XCTAssertFalse(JourneyLoopSource.isID("007"))
        let minted = JourneyLoopSource.makeRequestID(prefix: "seatinv", nowMillis: 1_700_000_000_000, entropy: "abcd1234")
        XCTAssertEqual(minted, "seatinv-loyw3v28-abcd1234")
        XCTAssertTrue(JourneyLoopSource.isRequestID(minted ?? ""))
    }

    func testReadsUseTheJourneyPathsAndDoNotSendDroppedIds() async throws {
        let wire = Wire(body: Data(#"{"code":200,"msg":"ok","data":{"state":"VALID"}}"#.utf8))
        let source = try make(wire)
        let report = try await source.report(activityID: "0", topicID: "12", runID: nil, token: "session-token")
        XCTAssertTrue(report.ok)
        XCTAssertEqual(report.message, "ok")
        XCTAssertFalse(report.unconfirmed)
        XCTAssertEqual(wire.requests[0].httpMethod, "GET")
        XCTAssertEqual(wire.requests[0].url?.path, "/api/play/player-journey/report")
        XCTAssertEqual(query(wire.requests[0]), ["topicId": "12"])
        XCTAssertEqual(wire.requests[0].value(forHTTPHeaderField: "Authorization"), "session-token")
        XCTAssertNil(wire.requests[0].httpBody)

        _ = try await source.memory(activityID: "3", topicID: nil, runID: "9", token: "session-token")
        XCTAssertEqual(wire.requests[1].url?.path, "/api/play/player-journey/memory")
        XCTAssertEqual(query(wire.requests[1]), ["activityId": "3", "runId": "9"])

        _ = try await source.choices(activityID: nil, topicID: "4", token: "session-token")
        XCTAssertEqual(wire.requests[2].url?.path, "/api/play/player-journey/choices")
        XCTAssertEqual(query(wire.requests[2]), ["topicId": "4"])

        _ = try await source.seats(registrationID: "15", token: "session-token")
        XCTAssertEqual(wire.requests[3].url?.path, "/api/play/player-journey/seats")
        XCTAssertEqual(query(wire.requests[3]), ["registrationId": "15"])

        _ = try await source.rank(scope: "quest", scopeID: "0", period: "all", token: "session-token")
        XCTAssertEqual(wire.requests[4].url?.path, "/api/rank/list")
        XCTAssertEqual(query(wire.requests[4]), ["scope": "quest", "period": "all"])

        _ = try await source.teamDetail(teamID: "8", token: "session-token")
        XCTAssertEqual(wire.requests[5].url?.path, "/api/orient/team/detail")
        XCTAssertEqual(query(wire.requests[5]), ["teamId": "8"])

        _ = try await source.teamRanking(ownerType: 2, ownerID: "6", token: "session-token")
        XCTAssertEqual(wire.requests[6].url?.path, "/api/orient/team/ranking")
        XCTAssertEqual(query(wire.requests[6]), ["ownerType": "2", "ownerId": "6"])

        let referral = try await source.referral(token: "invite-token", sessionToken: "session-token")
        XCTAssertTrue(referral.ok)
        XCTAssertEqual(wire.requests[7].httpMethod, "POST")
        XCTAssertEqual(wire.requests[7].url?.path, "/api/referral/landing/referral")
        XCTAssertEqual(wire.requests[7].value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(json(wire.requests[7]), ["token": "invite-token"])

        _ = try await source.gift(token: "gift-token", sessionToken: "session-token")
        XCTAssertEqual(wire.requests[8].url?.path, "/api/referral/landing/gift")
        XCTAssertEqual(json(wire.requests[8]), ["token": "gift-token"])

        _ = try await source.affiliate(token: "session-token")
        XCTAssertEqual(wire.requests[9].url?.path, "/api/marketing/affiliate/summary")
        XCTAssertEqual(query(wire.requests[9]), ["limit": "20"])

        _ = try await source.seatInvitation(id: "44", token: "session-token")
        XCTAssertEqual(wire.requests[10].httpMethod, "GET")
        XCTAssertEqual(wire.requests[10].url?.path, "/api/play/seat-invitations/44")
        XCTAssertNil(wire.requests[10].url?.query)

        let rated = try await source.rate(ownerType: 1, ownerID: "9", rating: 5, contents: "一起玩", requestID: "rateintent0000001", token: "session-token")
        XCTAssertTrue(rated.ok)
        XCTAssertEqual(wire.requests[11].url?.path, "/api/comment/add")
        XCTAssertEqual(wire.requests[11].value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded;")
        XCTAssertEqual(String(data: wire.requests[11].httpBody ?? Data(), encoding: .utf8),
                       "owner_type=1&owner_id=9&rating=5&contents=%E4%B8%80%E8%B5%B7%E7%8E%A9&reply_id=0&request_id=rateintent0000001")
        let before = wire.requests.count
        do {
            _ = try await source.rate(ownerType: 1, ownerID: "9", rating: 5, contents: "一起玩", requestID: "short", token: "session-token")
            XCTFail("short request id")
        } catch JourneyRefusal.invalidRequest {}
        XCTAssertEqual(wire.requests.count, before)
    }

    func testMoneyWritesAndBadIdsSendNothing() async throws {
        let wire = Wire()
        let source = try make(wire)
        XCTAssertThrowsError(try source.issueReferral(targetType: 1, targetID: "3", token: "session-token")) { error in
            XCTAssertEqual(error as? JourneyRefusal, .moneyOff)
        }
        XCTAssertThrowsError(try source.giftClaim(token: "gift-token", requestID: "req-1", sessionToken: "session-token")) { error in
            XCTAssertEqual(error as? JourneyRefusal, .moneyOff)
        }
        do {
            _ = try await source.seats(registrationID: "0", token: "session-token")
            XCTFail("zero id")
        } catch JourneyRefusal.invalidRequest {}
        do {
            _ = try await source.seatInvitation(id: "../44", token: "session-token")
            XCTFail("path")
        } catch JourneyRefusal.invalidRequest {}
        do {
            _ = try await source.teamRanking(ownerType: 3, ownerID: "6", token: "session-token")
            XCTFail("owner")
        } catch JourneyRefusal.invalidRequest {}
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testSeatPhoneTransferSendsJSONAndGiftClaimStillSendsNothing() async throws {
        let wire = Wire(body: Data(#"{"code":200,"data":{"ok":true}}"#.utf8))
        let source = try make(wire)
        XCTAssertEqual(JourneySeatPhoneTransfer.nameError("  "), "请填写称呼")
        XCTAssertEqual(JourneySeatPhoneTransfer.nameError(String(repeating: "字", count: 21)), "最多 20 个字")
        XCTAssertNil(JourneySeatPhoneTransfer.nameError(" 阿宁 "))
        XCTAssertEqual(JourneySeatPhoneTransfer.phoneError("123"), "手机号格式不对")
        XCTAssertEqual(JourneyLoopSource.normalizeMobile("+86 138-0013-8000"), "13800138000")
        XCTAssertEqual(JourneySeatPhoneTransfer.who(channel: "PHONE", state: "INVITED", name: "阿宁", maskedPhone: "138****8000"), "阿宁 138****8000")
        XCTAssertEqual(JourneySeatPhoneTransfer.who(channel: "LINK", state: "INVITED", name: "阿宁", maskedPhone: "138****8000"), "")
        XCTAssertTrue(JourneySeatPhoneTransfer.canTransfer(state: "AVAILABLE", seatNo: 2, phoneTransferSupported: true, buyerIsCaller: true, readOnly: false))
        XCTAssertFalse(JourneySeatPhoneTransfer.canTransfer(state: "AVAILABLE", seatNo: 1, phoneTransferSupported: true, buyerIsCaller: true, readOnly: false))
        do {
            _ = try await source.seatTransferPhone(registrationID: "15", seatNo: 2, name: "阿宁", phone: "123", token: "session-token")
            XCTFail("bad phone")
        } catch JourneyRefusal.invalidRequest {}
        XCTAssertTrue(wire.requests.isEmpty)
        wire.body = Data(#"{"code":503}"#.utf8)
        let sent = try await source.seatTransferPhone(registrationID: "15", seatNo: 2, name: " 阿宁 ", phone: "+86 138-0013-8000", token: "session-token")
        XCTAssertTrue(sent.unconfirmed)
        XCTAssertEqual(wire.requests[0].httpMethod, "POST")
        XCTAssertEqual(wire.requests[0].url?.path, "/api/play/seat-invitations/transfer-phone")
        XCTAssertEqual(wire.requests[0].value(forHTTPHeaderField: "Content-Type"), "application/json")
        let object = try JSONSerialization.jsonObject(with: wire.requests[0].httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(object?["name"] as? String, "阿宁")
        XCTAssertEqual(object?["phone"] as? String, "13800138000")
        XCTAssertEqual((object?["registrationId"] as? NSNumber)?.intValue, 15)
        XCTAssertEqual((object?["seatNo"] as? NSNumber)?.intValue, 2)
        XCTAssertEqual(object?["requestId"] as? String, "seatphone-loyw3v28-abcd1234")
        let again = try await source.seatTransferPhone(registrationID: "15", seatNo: 2, name: "阿宁", phone: "13800138000", token: "session-token")
        XCTAssertTrue(again.unconfirmed)
        let retry = try JSONSerialization.jsonObject(with: wire.requests[1].httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(retry?["requestId"] as? String, "seatphone-loyw3v28-abcd1234")
        wire.body = Data(#"{"code":200,"data":{}}"#.utf8)
        let claimed = try await source.seatClaimPhone(token: "seat-token", sessionToken: "session-token")
        XCTAssertTrue(claimed.ok)
        XCTAssertEqual(wire.requests[2].url?.path, "/api/play/seat-invitations/claim-phone/seat-token")
        XCTAssertEqual(wire.requests[2].httpBody, Data("{}".utf8))
        _ = try await source.seatMine(token: "session-token")
        XCTAssertEqual(wire.requests[3].httpMethod, "GET")
        XCTAssertEqual(wire.requests[3].url?.path, "/api/play/seat-invitations/mine")
        XCTAssertNil(wire.requests[3].httpBody)
        let before = wire.requests.count
        XCTAssertThrowsError(try source.giftClaim(token: "gift-token", requestID: "req-1", sessionToken: "session-token")) { error in
            XCTAssertEqual(error as? JourneyRefusal, .moneyOff)
        }
        XCTAssertEqual(wire.requests.count, before)
        XCTAssertFalse(JourneyLoopSource.journey(.seatTransferPhone).money)
        XCTAssertFalse(JourneyLoopSource.journey(.seatClaimPhone).money)
        XCTAssertFalse(JourneyLoopSource.journey(.seatMine).money)
        XCTAssertFalse(JourneyLoopSource.moneyWritesEnabled)
    }

    func testProductionHostsAndTheProductionClassAreRefused() throws {
        let wire = Wire()
        for host in ["https://chengyinhub.com", "https://api.chengyinhub.cn", "https://47.103.124.64"] {
            XCTAssertThrowsError(try JourneyLoopSource(configuration: APIConfiguration(baseURL: URL(string: host)!), transport: wire)) { error in
                XCTAssertEqual(error as? JourneyRefusal, .productionEndpoint, host)
            }
        }
        XCTAssertThrowsError(try make(wire, endpoint: .production)) { error in
            XCTAssertEqual(error as? JourneyRefusal, .productionEndpoint)
        }
    }

    func testStringAndNumericSuccessAreOkAndServerErrorsStayUnconfirmed() {
        let numeric = JourneyLoopSource.envelope(data: Data(#"{"code":200,"data":{"invitationId":8}}"#.utf8), status: 200, receiptReread: false)
        XCTAssertTrue(numeric.ok)
        XCTAssertEqual(numeric.httpStatus, 200)
        XCTAssertFalse(numeric.receiptReread)
        let text = JourneyLoopSource.envelope(data: Data(#"{"code":"200"}"#.utf8), status: 200, receiptReread: false)
        XCTAssertTrue(text.ok)
        let conflict = JourneyLoopSource.envelope(data: Data(#"{"code":409,"msg":"席位邀请已过期"}"#.utf8), status: 200, receiptReread: false)
        XCTAssertFalse(conflict.ok)
        XCTAssertFalse(conflict.unconfirmed)
        XCTAssertEqual(conflict.message, "席位邀请已过期")
        let unavailable = JourneyLoopSource.envelope(data: Data(#"{"code":503}"#.utf8), status: 503, receiptReread: true)
        XCTAssertTrue(unavailable.unconfirmed)
        XCTAssertTrue(unavailable.receiptReread)
        let broken = JourneyLoopSource.envelope(data: Data("not-json".utf8), status: 502, receiptReread: false)
        XCTAssertEqual(broken.code, "502")
        XCTAssertTrue(broken.unconfirmed)
        XCTAssertEqual(JourneyEnvelope.networkFailure.code, "fail")
        XCTAssertTrue(JourneyEnvelope.networkFailure.netFail)
        XCTAssertEqual(JourneyEnvelope.networkFailure.message, "网络异常，请重试")
    }

    private func make(_ wire: Wire, url: String = "https://example.test",
                      endpoint: JourneyLoopSource.EndpointClass = .nonProduction) throws -> JourneyLoopSource {
        try JourneyLoopSource(configuration: APIConfiguration(baseURL: URL(string: url)!), transport: wire, endpointClass: endpoint,
                              nowMillis: { 1_700_000_000_000 }, entropy: { "abcd1234" })
    }

    private func query(_ request: URLRequest) -> [String: String] {
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    private func json(_ request: URLRequest) -> [String: String] {
        guard let data = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: data) else { return [:] }
        return object as? [String: String] ?? [:]
    }

    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var body: Data
        init(body: Data = Data()) { self.body = body }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (body, 200)
        }
    }
}
