import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

final class PopupCloseParityTests: XCTestCase {
    private final class StubHTTPTransport: HTTPTransport {
        var requests: [URLRequest] = []
        let handler: (URLRequest) throws -> (Data, Int)

        init(_ handler: @escaping (URLRequest) throws -> (Data, Int)) {
            self.handler = handler
        }

        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return try handler(request)
        }
    }

    private let baseConfig = try! APIConfiguration(baseURL: URL(string: "https://8120.example.test/")!)

    func testNearbyTeamApplyRequestEncodesTrimmedOptionalMessageAndRejectsOverlong() throws {
        let reqWithMessage = try NearbyTeamRequest.action(.apply(NearbyTeamID(18)), message: "  今晚七点到  ")
        XCTAssertEqual(reqWithMessage.method, "POST")
        XCTAssertEqual(reqWithMessage.path, "/api/team/apply")
        XCTAssertEqual(reqWithMessage.mutation, true)
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: XCTUnwrap(reqWithMessage.body)) as? [String: Any]
        )
        XCTAssertEqual((json["teamId"] as? NSNumber)?.intValue, 18)
        XCTAssertEqual(json["message"] as? String, "今晚七点到")

        let reqBlank = try NearbyTeamRequest.action(.apply(NearbyTeamID(18)), message: "   \n  ")
        let blankJson = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: XCTUnwrap(reqBlank.body)) as? [String: Any]
        )
        XCTAssertNil(blankJson["message"])

        let overlong = String(repeating: "a", count: NearbyTeamRequest.maxApplyMessageLength + 1)
        XCTAssertThrowsError(try NearbyTeamRequest.action(.apply(NearbyTeamID(18)), message: overlong))
    }

    func testPlanFallbackStatusAndSubmitCommand() async throws {
        let controlPayload = PlayWireValue.object([
            "revision": .integer(4),
            "availableActions": .array([.string("PLAN_FALLBACK")]),
            "world": .object(["fallbackAvailable": .bool(true)])
        ])
        let ready = PlayPlanFallbackStatus.present(control: controlPayload, expectedRevision: 4)
        XCTAssertTrue(ready.known)
        XCTAssertTrue(ready.available)
        XCTAssertEqual(ready.controlRevision, 4)

        let stale = PlayPlanFallbackStatus.present(control: controlPayload, expectedRevision: 5)
        XCTAssertFalse(stale.available)
        XCTAssertEqual(stale.reason, "场次状态已更新，请重新加载后确认")

        let blockedPayload = PlayWireValue.object([
            "revision": .integer(4),
            "availableActions": .array([]),
            "world": .object([
                "fallbackAvailable": .bool(false),
                "fallbackDisabledReason": .string("BALLOT_NOT_FINISHED")
            ])
        ])
        let blocked = PlayPlanFallbackStatus.present(control: blockedPayload, expectedRevision: 4)
        XCTAssertFalse(blocked.available)
        XCTAssertEqual(blocked.reason, "尚未完成表决或全队拒绝确认")

        let transport = StubHTTPTransport { request in
            XCTAssertEqual(request.url?.path, "/api/game/session/command")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            XCTAssertEqual(body["action"] as? String, "PLAN_FALLBACK")
            let payload = body["payload"] as? [String: Any]
            XCTAssertEqual(payload?["reason"] as? String, "队员一致同意默认收尾")
            return (Data(#"{"code":200,"data":{"outcome":"APPLIED","result":{"result":{"title":"和平落幕","endingKey":"PEACE"}}}}"#.utf8), 200)
        }
        let service = PlayExperienceService(configuration: baseConfig, transport: transport, enabled: [.reads, .directorCommands])
        let result = try await service.submitPlanFallback(
            activityID: 91,
            expectedRevision: 4,
            reason: "队员一致同意默认收尾",
            requestID: "req_12345678",
            token: "Bearer token-123"
        )
        XCTAssertEqual(result.title, "和平落幕")
        XCTAssertEqual(result.endingKey, "PEACE")
        XCTAssertEqual(transport.requests.count, 1)
    }

    @MainActor
    func testOfficialAttendanceFetchContactAndRotateCommand() async throws {
        let transport = StubHTTPTransport { request in
            switch request.url?.path {
            case "/api/official/events/42/attendance/manage":
                return (Data(#"{"code":200,"data":{"dutyState":"CLAIMED","configVersion":3,"config":{"meetingName":"静安寺广场","meetingAddress":"南京西路1686号","phone":"13800001234"},"mine":{"credential":"abc123","checkedAt":"2026-11-14 19:00"},"activeParticipation":true}}"#.utf8), 200)
            case "/api/play/contact":
                return (Data(#"{"code":200,"data":{"name":"主理人阿哲","phone":"13900004321"}}"#.utf8), 200)
            case "/api/official/command":
                return (Data(#"{"code":200,"data":{"receipt":{"requestId":"req-att-1","state":"APPLIED","message":"rotated"}}}"#.utf8), 200)
            default:
                return (Data(#"{"code":404}"#.utf8), 404)
            }
        }
        let service = OfficialAttendanceService(configuration: baseConfig, transport: transport)
        let snapshot = try await service.fetchAttendance(eventID: 42, organizer: true, token: "Bearer token-xyz")
        XCTAssertEqual(snapshot.dutyState, "CLAIMED")
        XCTAssertEqual(snapshot.configVersion, 3)
        XCTAssertEqual(snapshot.meetingName, "静安寺广场")
        XCTAssertTrue(snapshot.activeParticipation)

        let contact = await service.fetchContact(activityID: 42, token: "Bearer token-xyz")
        XCTAssertEqual(contact?.name, "主理人阿哲")
        XCTAssertEqual(contact?.phone, "13900004321")

        let receipt = try await service.sendCommand(
            eventID: 42,
            action: .attendanceRotate,
            fields: [:],
            token: "Bearer token-xyz",
            requestId: "req-att-1"
        )
        XCTAssertEqual(receipt?.state, .applied)
        XCTAssertEqual(receipt?.message, "rotated")
    }

    func testChinaReviewedRouteGrantsForPopupCloseRoutesAndMoneySwitchClosure() {
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/topic/beta/graduate"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/topic/transfer-to-club"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/my"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/official/events/42/attendance"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/official/events/42/attendance/manage"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/play/contact"))

        XCTAssertFalse(ReleaseMoneyWriteSwitch.isEnabled(.payments))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/pay/create"))
    }
}
