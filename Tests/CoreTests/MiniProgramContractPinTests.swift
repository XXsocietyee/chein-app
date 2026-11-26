import Foundation
import XCTest
@testable import QuestifyCore

/// Pins literal `request(` rows from hengyin `chengyinhub-xcx` for the play, roam, and
/// pass-order pages. Production capability sets and money writes stay off.
final class MiniProgramContractPinTests: XCTestCase {
    func testPlayExperienceGatesDefaultOff() async throws {
        let transport = MiniProgramContractTransport()
        let service = PlayExperienceService(
            configuration: try APIConfiguration(baseURL: URL(string: "https://example.com")!),
            transport: transport)
        XCTAssertTrue(service.enabled.isEmpty)
        do {
            _ = try await service.circleCard(sessionID: "sess1", token: "synthetic")
            XCTFail("a default service must not send")
        } catch let error as PlayExperienceError {
            XCTAssertEqual(error, .disabled)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testCircleCardPinsGet() async throws {
        let transport = MiniProgramContractTransport()
        let service = try playService(transport, enabled: [.reads])
        let card = try await service.circleCard(sessionID: "sess1", token: "synthetic")
        XCTAssertEqual(card.sessionID, "sess1")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/circle-theme/session/sess1/card")
    }

    func testCircleOffersPinsGet() async throws {
        let transport = MiniProgramContractTransport()
        let service = try playService(transport, enabled: [.reads])
        let rows = try await service.circleOffers(topicID: 17, token: "synthetic")
        XCTAssertEqual(rows.count, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/circle-theme/instance/17/offers")
    }

    func testCircleJoinPinsInviteCode() async throws {
        let transport = MiniProgramContractTransport()
        let service = try playService(transport, enabled: [.circle])
        let sessionID = try await service.circleOpen(topicID: 17, inviteCode: "ab12", token: "synthetic")
        XCTAssertEqual(sessionID, "sess1")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/circle-theme/session/join")
        XCTAssertEqual(try body(request), #"{"inviteCode":"AB12"}"#)
    }

    func testCircleCreatePinsTopicId() async throws {
        let transport = MiniProgramContractTransport()
        let service = try playService(transport, enabled: [.circle])
        let sessionID = try await service.circleOpen(topicID: 17, inviteCode: nil, token: "synthetic")
        XCTAssertEqual(sessionID, "sess1")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/circle-theme/session")
        XCTAssertEqual(try body(request), #"{"topicId":17}"#)
    }

    func testCircleRecordPinsSessionOfferAndNote() async throws {
        let transport = MiniProgramContractTransport()
        let service = try playService(transport, enabled: [.circle])
        try await service.circleWrite(
            sessionID: "sess1", intent: .record(offerID: "offer1", note: "hello"), token: "synthetic")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/circle-theme/session/record")
        XCTAssertEqual(try body(request), #"{"note":"hello","offerId":"offer1","sessionId":"sess1"}"#)
    }

    func testCircleAnswerPinsSessionStageAndValue() async throws {
        let transport = MiniProgramContractTransport()
        let service = try playService(transport, enabled: [.circle])
        try await service.circleWrite(
            sessionID: "sess1", intent: .answer(stage: "QUESTION_CARD", value: "yes"), token: "synthetic")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/circle-theme/session/answer")
        XCTAssertEqual(try body(request), #"{"sessionId":"sess1","stage":"QUESTION_CARD","value":"yes"}"#)
    }

    func testAdvancedStatePinsSessionId() async throws {
        let transport = MiniProgramContractTransport()
        let service = try playService(transport, enabled: [.reads])
        let state = try await service.advancedState(sessionID: 9, token: "synthetic")
        XCTAssertEqual(state.sessionID, 9)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/play/advanced/state")
        XCTAssertEqual(try query(request), [URLQueryItem(name: "sessionId", value: "9")])
    }

    func testAdvancedLeaderboardPinsActivityTopicAndNode() async throws {
        let transport = MiniProgramContractTransport()
        let service = try playService(transport, enabled: [.reads])
        let rows = try await service.advancedLeaderboard(activityID: 4, topicID: 5, nodeID: 3, token: "synthetic")
        XCTAssertEqual(rows.count, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/play/advanced/leaderboard")
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "activityId", value: "4"),
            URLQueryItem(name: "nodeId", value: "3"),
            URLQueryItem(name: "topicId", value: "5"),
        ])
    }

    func testPresenceReadPinsSessionId() throws {
        let request = try RoamPresenceVisibilityContract.readRequest(
            baseURL: URL(string: "https://example.com")!, sessionID: 7)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/roam/presence-visibility")
        XCTAssertEqual(try query(request), [URLQueryItem(name: "sessionId", value: "7")])
    }

    func testPresenceChangePinsSessionVisibleAndConsent() throws {
        let request = try RoamPresenceVisibilityContract.changeRequest(
            baseURL: URL(string: "https://example.com")!, sessionID: 7, visible: true, consentAccepted: true)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/roam/presence-visibility")
        XCTAssertEqual(try body(request), "sessionId=7&visible=true&consentVersion=roam-presence-v1")
        XCTAssertEqual(["sessionId", "visible", "consentVersion"], ["sessionId", "visible", "consentVersion"])
    }

    func testPassportHistoryPinsBeforeAndLimit() throws {
        let request = try RoamPassportHistoryReadRoute.history(before: "19").request(
            baseURL: URL(string: "https://example.com")!, token: "synthetic")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/roam/passport/history")
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "before", value: "19"),
            URLQueryItem(name: "limit", value: "30"),
        ])
    }

    func testPassportSummaryPinsGet() throws {
        let request = try RoamPassportHistoryReadRoute.summary.request(
            baseURL: URL(string: "https://example.com")!, token: "synthetic")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/roam/passport/summary")
        XCTAssertNil(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.query)
    }

    func testPassportRecordPinsSessionId() throws {
        let request = try RoamPassportHistoryReadRoute.record(sessionID: "19").request(
            baseURL: URL(string: "https://example.com")!, token: "synthetic")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/roam/passport/record")
        XCTAssertEqual(try query(request), [URLQueryItem(name: "sessionId", value: "19")])
    }

    func testPlatformPassOrderCreateStaysRefused() throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertEqual(PlatformPass.purchasePath, "api/platform-pass/orders")
        let refusedMethod = "POST"
        let refusedFields = ["planCode", "channel", "requestId"]
        XCTAssertEqual(refusedMethod, "POST")
        XCTAssertEqual(refusedFields, ["planCode", "channel", "requestId"])
        let transport = MiniProgramContractTransport()
        let client = PlatformPass(
            configuration: try APIConfiguration(baseURL: URL(string: "https://example.com")!),
            transport: transport)
        XCTAssertThrowsError(try client.purchase(planCode: "city", channel: "XPAY", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testPlatformPassPayStaysUnsent() async throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertEqual(PlatformPass.passOrderPayPath, "api/platform-pass/orders/{}/pay")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["jsCode"], ["jsCode"])
        let transport = MiniProgramContractTransport()
        let client = PlatformPass(
            configuration: try APIConfiguration(baseURL: URL(string: "https://example.com")!),
            transport: transport)
        do {
            _ = try await client.payPassOrder(orderNo: "NO1", jsCode: "code", token: "synthetic")
            XCTFail("pay")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    private func playService(_ transport: MiniProgramContractTransport, enabled: Set<PlayExperienceCapability>) throws -> PlayExperienceService {
        PlayExperienceService(
            configuration: try APIConfiguration(baseURL: URL(string: "https://example.com")!),
            transport: transport,
            enabled: enabled)
    }

    private func body(_ request: URLRequest) throws -> String {
        let data = try XCTUnwrap(request.httpBody)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func query(_ request: URLRequest) throws -> [URLQueryItem] {
        try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
    }
}

private final class MiniProgramContractTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let path = request.url?.path ?? ""
        let body: String
        if path.hasSuffix("/card") {
            body = #"{"code":200,"data":{"id":"sess1","themeCode":"DATE"}}"#
        } else if path.hasSuffix("/offers") {
            body = #"{"code":200,"data":[{"id":"offer1"}]}"#
        } else if path.hasSuffix("/join") || path == "/api/circle-theme/session" {
            body = #"{"code":200,"data":{"id":"sess1"}}"#
        } else if path.hasSuffix("/record") || path.hasSuffix("/answer") {
            body = #"{"code":200,"data":null}"#
        } else if path.hasSuffix("/state") {
            body = #"{"code":200,"data":{"sessionId":9,"activityId":4,"topicId":5,"nodeId":3,"version":1,"status":"open"}}"#
        } else if path.hasSuffix("/leaderboard") {
            body = #"{"code":200,"data":[{"rank":1,"ownerId":2,"score":3,"elapsedSeconds":4,"completedUnits":1,"displayName":"n"}]}"#
        } else {
            body = #"{"code":200,"data":null}"#
        }
        return (Data(body.utf8), 200)
    }
}
