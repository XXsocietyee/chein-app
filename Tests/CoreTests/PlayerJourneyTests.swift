import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class PlayerJourneyTests: XCTestCase {
    private let record = #"{"id":71,"ownerType":1,"ownerId":91,"registrationStatus":2,"paymentStatus":2,"verificationStatus":0,"cmsTopic":{"id":91,"name":"Synthetic route","startDate":"2099-01-01 10:00:00","productType":2},"refundInfo":{"refundable":true}}"#
    func testParticipationIsNotParticipantAndFiltersUseOrderProjection() throws {
        let row = try JSONDecoder().decode(ParticipationRecord.self, from: Data(record.utf8))
        XCTAssertEqual(row.id, 71); XCTAssertEqual(row.destination, .topic(91)); XCTAssertTrue(row.isFreeExplore)
        XCTAssertTrue(ParticipationFilter.notStarted.includes(row, now: Date(timeIntervalSince1970: 0)))
        XCTAssertFalse(ParticipationFilter.completed.includes(row, now: Date(timeIntervalSince1970: 0)))
    }
    func testCancellationUsesCurrentMiniStatusNotThreeDayHeuristic() throws {
        let detail = try JSONDecoder().decode(ParticipationDetail.self, from: Data(record.utf8))
        let nearStart = try XCTUnwrap(OrderLifecycleTime.date("2099-01-01 09:59:00"))
        XCTAssertTrue(detail.canCancel(now: nearStart)); XCTAssertEqual(detail.cancellationAction, .refund)
        let cancelled = record.replacingOccurrences(of: "\"registrationStatus\":2", with: "\"registrationStatus\":3")
        XCTAssertFalse(try JSONDecoder().decode(ParticipationDetail.self, from: Data(cancelled.utf8)).canCancel(now: nearStart))
    }
    func testMissingAndInvalidVerificationCountsStayUnknown() throws {
        let raw = String(record.dropLast()) + #", "status":1,"totalOrderNum":2,"verifiedNum":3}"#
        let detail = try JSONDecoder().decode(ParticipationDetail.self, from: Data(raw.utf8))
        XCTAssertTrue(detail.showOrderStats); XCTAssertNil(detail.total); XCTAssertNil(detail.pending)
    }
    func testCompletedDestinationUsesActivityThenTopicAndNeverZero() throws {
        let values = try JSONDecoder().decode([CompletedPlayRecord].self, from: Data(#"[{"activityId":3,"topicId":4},{"activityId":0,"topicId":4},{"activityId":0,"topicId":0},{"total":0}]"#.utf8))
        XCTAssertEqual(values[0].destination, .activity(3)); XCTAssertEqual(values[1].destination, .topic(4))
        XCTAssertNil(values[2].destination); XCTAssertNil(values[3].doneCount)
    }
    func testExactReadOnlyPostContractsAndStringEnvelopeCode() async throws {
        let transport = JourneyTestTransport(replies: [Data("{\"code\":\"200\",\"data\":[\(record)]}".utf8),
            Data("{\"code\":200,\"data\":\(record)}".utf8), Data(#"{"code":200,"data":[]}"#.utf8)])
        let service = try makeService(transport, enabled: true)
        _ = try await service.participations(token: "synthetic-token")
        _ = try await service.detail(id: 71, token: "synthetic-token")
        _ = try await service.completed(token: "synthetic-token")
        let requests = await transport.requests
        XCTAssertEqual(requests.map { $0.url!.path }, ["/api/registration/my-joined", "/api/registration/info", "/api/play/my-completed"])
        XCTAssertTrue(requests.allSatisfy { $0.httpMethod == "POST" })
        XCTAssertNil(requests[0].httpBody); XCTAssertNil(requests[2].httpBody)
        let detailBody = try XCTUnwrap(requests[1].httpBody).utf8String
        XCTAssertTrue(detailBody.contains("name=\"id\"\r\n\r\n71\r\n"))
        XCTAssertFalse(detailBody.contains("merchant"))
    }
    func testPublicReferenceReadIsGetAndLeavesTheHistoryGrantClosed() async throws {
        let body = Data(#"{"code":200,"data":[{"activityId":7,"name":"Night","doneCount":0,"total":2,"topicId":4}]}"#.utf8)
        let transport = JourneyTestTransport(replies: [body])
        let rows = try await makeService(transport, enabled: false).completedForPublicReference(token: "synthetic-token")
        XCTAssertEqual(rows.map(\.activityID), [7])
        XCTAssertEqual(rows[0].doneCount, 0)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].httpMethod, "GET")
        XCTAssertNil(requests[0].httpBody)
        XCTAssertEqual(requests[0].url?.path, "/api/play/my-completed")
        XCTAssertEqual(URLComponents(url: requests[0].url!, resolvingAgainstBaseURL: false)?.queryItems,
                       [URLQueryItem(name: "for_public_reference", value: "true")])
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        let blocked = JourneyTestTransport(replies: [])
        do { _ = try await makeService(blocked).completed(token: "synthetic-token"); XCTFail("History read stays closed") }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        let count = await blocked.requests.count
        XCTAssertEqual(count, 0)
    }
    func testPublicReferenceReadRejectsMalformedUnauthorizedAndABadToken() async throws {
        let malformed = JourneyTestTransport(replies: [Data(#"{"code":200,"data":{}}"#.utf8)])
        do { _ = try await makeService(malformed).completedForPublicReference(token: "synthetic-token"); XCTFail("Object is not a list") }
        catch { XCTAssertEqual(error as? APIError, .malformedResponse) }
        let denied = JourneyTestTransport(replies: [Data(#"{"code":401}"#.utf8)], status: 401)
        do { _ = try await makeService(denied).completedForPublicReference(token: "synthetic-token"); XCTFail("Unauthorized") }
        catch { XCTAssertEqual(error as? APIError, .unauthorized) }
        let quiet = JourneyTestTransport(replies: [])
        for badToken in ["", "   ", " bad", "bad ", " bad ", "非ASCII", "tok-é"] {
            do { _ = try await makeService(quiet).completedForPublicReference(token: badToken); XCTFail("Bad token: \(badToken.debugDescription)") }
            catch { XCTAssertEqual(error as? APIError, .invalidRequest) }
        }
        let count = await quiet.requests.count
        XCTAssertEqual(count, 0)
    }
    func testPublicReferenceRowsKeepLiteralZeroAndUnknownAsAnEmDash() throws {
        let raw = #"[{"activityId":7,"name":" Night ","cover":" https://cdn.example/a.jpg ","doneCount":0,"total":3,"topicId":9},{"activityId":8,"topicId":0,"doneCount":-1,"total":"no"},{"activityId":0,"name":"drop"},{"name":"noid"},{"activityId":"4","name":""}]"#
        let records = try JSONDecoder().decode([CompletedPlayRecord].self, from: Data(raw.utf8))
        let rows = SquareActivityPicker.publicReferenceRows(records)
        XCTAssertEqual(rows.map(\.id), [7, 8, 4])
        XCTAssertEqual(rows[0].name, "Night")
        XCTAssertEqual(rows[0].cover, "https://cdn.example/a.jpg")
        XCTAssertEqual(rows[0].doneCount, 0)
        XCTAssertEqual(rows[0].total, 3)
        XCTAssertEqual(rows[0].topicID, 9)
        XCTAssertEqual(rows[1].name, SquareCountDisplay.unknownMark)
        XCTAssertNil(rows[1].doneCount)
        XCTAssertNil(rows[1].total)
        XCTAssertNil(rows[1].topicID)
        XCTAssertNotEqual(rows[1].name, "0")
        XCTAssertEqual(rows[2].name, SquareCountDisplay.unknownMark)
    }
    func testDisabledServiceNeverDispatches() async throws {
        let transport = JourneyTestTransport(replies: [])
        do { _ = try await makeService(transport).completed(token: "synthetic-token"); XCTFail("Expected disabled read") }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        let count = await transport.requests.count; XCTAssertEqual(count, 0)
    }
    func testMalformedListIsNotEmptyAndWrongDetailIDIsRejected() async throws {
        let transport = JourneyTestTransport(replies: [Data(#"{"code":200,"data":{}}"#.utf8), Data("{\"code\":200,\"data\":\(record)}".utf8)])
        let service = try makeService(transport, enabled: true)
        do { _ = try await service.completed(token: "synthetic-token"); XCTFail("Malformed list") } catch { XCTAssertEqual(error as? APIError, .malformedResponse) }
        do { _ = try await service.detail(id: 72, token: "synthetic-token"); XCTFail("Wrong detail") } catch { XCTAssertEqual(error as? APIError, .malformedResponse) }
    }
    @MainActor func testReloginDuringReadRejectsStaleResponseAndStaleUnauthorized() async throws {
        let transport = JourneySuspendedTransport()
        var current = try PlayerJourneySession(accountID: 1, epoch: 1, namespace: "cn", token: "synthetic-a")
        var expired = 0
        let reader = PlayerJourneySessionReader(service: try makeService(transport, enabled: true), currentSession: { current }, onUnauthorized: { _ in expired += 1 })
        let scope = reader.scope
        let request = Task { try await reader.completed() }
        await transport.waitUntilStarted()
        current = try PlayerJourneySession(accountID: 1, epoch: 2, namespace: "cn", token: "synthetic-b")
        XCTAssertNotEqual(scope, reader.scope)
        await transport.finish(Data(#"{"code":401,"msg":"Expired"}"#.utf8))
        do { _ = try await request.value; XCTFail("Stale result") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(expired, 0)
    }
    private func makeService(_ transport: any HTTPTransport, enabled: Bool = false) throws -> PlayerJourneyService {
        try PlayerJourneyService(configuration: APIConfiguration(baseURL: URL(string: "https://example.com")!), transport: transport, readsEnabled: enabled)
    }
    func testParticipationDateRangeMatchesSourceFormat() {
        XCTAssertEqual(ParticipationDateText.range(start: "2026-5-1 09:00:00", end: "2026/05/03"), "05.01 - 05.03")
        XCTAssertEqual(ParticipationDateText.range(start: "2026-12-31", end: nil), "12.31")
        XCTAssertEqual(ParticipationDateText.range(start: "bad", end: "2026.07.08"), "07.08")
        XCTAssertNil(ParticipationDateText.range(start: nil, end: "soon"))
    }
}
private extension Data { var utf8String: String { String(decoding: self, as: UTF8.self) } }
private actor JourneyTestTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var replies: [Data]
    var status: Int
    init(replies: [Data], status: Int = 200) { self.replies = replies; self.status = status }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        // An unexpected extra request fails the test instead of trapping the whole runner.
        guard !replies.isEmpty else { throw APIError.httpStatus(599) }
        return (replies.removeFirst(), status)
    }
}
private actor JourneySuspendedTransport: HTTPTransport {
    private var continuation: CheckedContinuation<Data, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let data = await withCheckedContinuation { continuation in self.continuation = continuation; waiter?.resume(); waiter = nil }
        return (data, 200)
    }
    func waitUntilStarted() async { if continuation != nil { return }; await withCheckedContinuation { waiter = $0 } }
    func finish(_ data: Data) { continuation?.resume(returning: data); continuation = nil }
}
