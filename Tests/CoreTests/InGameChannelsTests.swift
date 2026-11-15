import Foundation
import XCTest
@testable import QuestifyCore

private final class MockInGameChannelHTTPTransport: HTTPTransport {
    var recordedRequests: [URLRequest] = []
    var nextStatus = 200
    var nextData = Data()
    var nextError: Error?

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        recordedRequests.append(request)
        if let nextError { throw nextError }
        return (nextData, nextStatus)
    }
}

final class InGameChannelsTests: XCTestCase {
    private let config = try! APIConfiguration(baseURL: URL(string: "https://example.test")!)
    private let allPaths: Set<String> = [
        InGameChannelService.resolvePath,
        InGameChannelService.summaryPath,
    ]

    func testScopeFieldsAndValidity() {
        XCTAssertTrue(InGameChannelScope.activity(id: 42).isValid)
        XCTAssertFalse(InGameChannelScope.activity(id: 0).isValid)
        XCTAssertEqual(InGameChannelScope.activity(id: 42).fields, ["scope": "activity", "activity_id": "42"])

        XCTAssertEqual(InGameChannelScope.topic(id: 9).fields, ["scope": "topic", "topic_id": "9"])
        XCTAssertEqual(InGameChannelScope.team(id: 17).fields, ["scope": "team", "team_id": "17"])

        XCTAssertTrue(InGameChannelScope.roam(district: "").isValid)
        XCTAssertEqual(InGameChannelScope.roam(district: "  ").fields, ["scope": "roam", "district": "nearby"])
        XCTAssertEqual(InGameChannelScope.roam(district: "静安区").fields, ["scope": "roam", "district": "静安区"])

        XCTAssertFalse(InGameChannelScope.cityTeam(teamID: nil, boardID: "  ").isValid)
        XCTAssertTrue(InGameChannelScope.cityTeam(teamID: nil, boardID: "b-1").isValid)
        XCTAssertEqual(InGameChannelScope.cityTeam(teamID: "t-1", boardID: "b-1").fields, [
            "scope": "city_team",
            "city_team_id": "t-1",
            "board_id": "b-1",
        ])
    }

    func testResolveEncodesFormRequestAndDecodesChannelRef() async throws {
        let transport = MockInGameChannelHTTPTransport()
        transport.nextData = Data(#"""
        {
          "code": 200,
          "data": {
            "conversationId": 88,
            "type": 4,
            "scope": "team",
            "bizKey": "team_17",
            "title": "第17小队频道",
            "unread": 3,
            "muted": 0,
            "memberCount": 4,
            "lastMsgText": "[系统] 小队打卡成功",
            "teamId": 17
          }
        }
        """#.utf8)

        let service = InGameChannelService(configuration: config, transport: transport, enabledPaths: allPaths)
        let ref = try await service.resolve(token: "tok-valid-1", target: .team(id: 17))

        XCTAssertEqual(ref.conversationId, 88)
        XCTAssertEqual(ref.bizKey, "team_17")
        XCTAssertEqual(ref.unread, 3)
        XCTAssertEqual(ref.teamId, 17)
        XCTAssertEqual(ref.asConversation.id, 88)
        XCTAssertEqual(ref.asConversation.kind, .group)
        XCTAssertEqual(ref.asConversation.counterparty?.nickname, "第17小队频道")
        XCTAssertEqual(transport.recordedRequests.first?.httpMethod, "POST")
        XCTAssertEqual(transport.recordedRequests.first?.url?.path, "/api/im/ingame/resolve")
        XCTAssertEqual(transport.recordedRequests.first?.value(forHTTPHeaderField: "Authorization"), "tok-valid-1")
    }

    func testSummaryEncodesQueryAndHandlesEmptyChannel() async throws {
        let transport = MockInGameChannelHTTPTransport()
        transport.nextData = Data(#"""
        {
          "code": 200,
          "data": {
            "exists": true,
            "conversationId": 91,
            "scope": "roam",
            "bizKey": "roam_nearby",
            "title": "附近漫游频道",
            "unread": 5,
            "muted": 1,
            "lastMsgText": "打卡完成"
          }
        }
        """#.utf8)

        let service = InGameChannelService(configuration: config, transport: transport, enabledPaths: allPaths)
        let summary = try await service.summary(token: "tok-valid-2", target: .roam(district: "nearby"))

        XCTAssertTrue(summary.exists)
        XCTAssertEqual(summary.conversationId, 91)
        XCTAssertEqual(summary.unread, 5)
        XCTAssertEqual(summary.muted, 1)
        XCTAssertEqual(transport.recordedRequests.first?.httpMethod, "GET")
        let query = transport.recordedRequests.first?.url?.query ?? ""
        XCTAssertTrue(query.contains("district=nearby"))
        XCTAssertTrue(query.contains("scope=roam"))
    }

    func testReaderPropagates401UnauthorizedCallback() async {
        let transport = MockInGameChannelHTTPTransport()
        transport.nextStatus = 401
        let service = InGameChannelService(configuration: config, transport: transport, enabledPaths: allPaths)
        guard let session = try? IMSafetySession(accountID: 7, epoch: 2, token: "tok-expired") else {
            return XCTFail("Expected valid IMSafetySession")
        }

        final class SessionRecorder: @unchecked Sendable {
            var sessions: [IMSafetySession] = []
        }
        let recorder = SessionRecorder()
        let reader = await MainActor.run {
            InGameChannelReader(service: service, session: { session }, onUnauthorized: { recorder.sessions.append($0) })
        }

        do {
            _ = try await reader.resolveChannel(.activity(id: 12))
            XCTFail("Expected HTTP 401 failure")
        } catch let failure as MessagingReadFailure {
            XCTAssertEqual(failure.httpStatus, 401)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.sessions, [session])
    }

    func testReviewedRouteAndRuntimeFeatureContainInGameRoutes() throws {
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/im/ingame/resolve"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/im/ingame/summary"))
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/im/ingame/resolve"), .liveInProduction)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/im/ingame/summary"), .liveInProduction)
        XCTAssertTrue(try BusinessRuntimeFeature.inGameChannels.accepts(BusinessRuntimeRoute(method: "POST", path: "api/im/ingame/resolve")))
        XCTAssertTrue(try BusinessRuntimeFeature.inGameChannels.accepts(BusinessRuntimeRoute(method: "GET", path: "api/im/ingame/summary")))
    }
}
