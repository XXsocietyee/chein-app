import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class CooperationInviteDetailPageTests: XCTestCase {
    private func invites(_ json: String) throws -> CooperationInvites {
        try JSONDecoder().decode(CooperationInvites.self, from: Data(json.utf8))
    }

    private func detail(id: Int, direction: CooperationDirection, json: String) throws -> CooperationInviteDetail {
        let list = try invites(json)
        let row = try XCTUnwrap(list.rows(direction).first { $0.id == id })
        return CooperationInviteDetail(row: row, occupancy: list.occupancy(for: row), slotLine: list.slotLine(for: row))
    }

    func testUnknownSlotCountsAreEmDashNeverZero() throws {
        let json = #"{"received":[{"id":7,"topicId":3,"gameId":4,"status":0}],"slots":{"byGame":{"4":{"pending":"UNKNOWN","cap":"0","accepted":null}},"byTopic":{"3":{"accepted":1,"cap":5}}}}"#
        let list = try invites(json)
        let row = try XCTUnwrap(list.received.first)
        let line = try XCTUnwrap(list.slotLine(for: row))
        XCTAssertEqual(line.kind, .gamePending)
        XCTAssertEqual(line.count, .unknown)
        XCTAssertEqual(line.capacity, .unknown)
        XCTAssertNil(line.count.literal)
        XCTAssertNil(line.capacity.literal)
        XCTAssertEqual(line.count.displayText, "—")
        XCTAssertEqual(line.capacity.displayText, "—")
        XCTAssertNotEqual(line.count.displayText, "0")
        XCTAssertNotEqual(line.capacity.displayText, "0")
        XCTAssertNil(list.occupancy(for: row), "An unreadable game slot must not become the topic slot or a zero")
        let negative = try invites(#"{"received":[{"id":7,"gameId":4}],"slots":{"byGame":{"4":{"pending":-1,"cap":2.5}}}}"#)
        let bad = try XCTUnwrap(negative.slotLine(for: negative.received[0]))
        XCTAssertEqual(bad.count.displayText, "—")
        XCTAssertEqual(bad.capacity.displayText, "—")
        XCTAssertNil(bad.count.literal)
    }

    func testLiteralZeroSlotStaysZeroAndMissingSlotIsWithheld() throws {
        let zero = try detail(id: 7, direction: .received, json: #"{"received":[{"id":7,"gameId":4,"status":1}],"slots":{"byGame":{"4":{"pending":0,"cap":4}}}}"#)
        XCTAssertEqual(zero.occupancy?.count, 0)
        XCTAssertEqual(zero.occupancy?.capacity, 4)
        XCTAssertEqual(zero.slotLine?.count.literal, 0)
        XCTAssertEqual(zero.slotLine?.count.displayText, "0")
        XCTAssertEqual(zero.slotLine?.capacity.displayText, "4")
        let page = CooperationInviteDetailPage.project(key: .init(id: 7, direction: .received), result: .success(zero))
        XCTAssertEqual(page.phase, .ready)
        XCTAssertEqual(page.slotCount, .text("0"))
        XCTAssertEqual(page.slotCapacity, .text("4"))
        let bare = try detail(id: 8, direction: .sent, json: #"{"sent":[{"id":8,"status":1}]}"#)
        let hidden = CooperationInviteDetailPage.project(key: .init(id: 8, direction: .sent), result: .success(bare))
        XCTAssertEqual(hidden.phase, .ready)
        XCTAssertEqual(hidden.slotCount, .withheld)
        XCTAssertEqual(hidden.slotCapacity, .withheld)
        XCTAssertNil(bare.slotLine)
        XCTAssertNil(bare.occupancy)
    }

    func testIncompleteGameSlotDoesNotUseTopicCounts() throws {
        let list = try invites(#"{"received":[{"id":7,"topicId":3,"gameId":4}],"slots":{"byGame":{"4":{"pending":2}},"byTopic":{"3":{"accepted":1,"cap":5}}}}"#)
        let row = list.received[0]
        XCTAssertNil(list.occupancy(for: row))
        let line = try XCTUnwrap(list.slotLine(for: row))
        XCTAssertEqual(line.kind, .gamePending)
        XCTAssertEqual(line.count.displayText, "2")
        XCTAssertEqual(line.capacity.displayText, "—")
        XCTAssertNotEqual(line.capacity.displayText, "5")
    }

    func testPagePhasesKeepUnknownCountsAsEmDash() throws {
        let key = CooperationInviteKey(id: 7, direction: .received)
        let loading = CooperationInviteDetailPage.project(key: key, result: nil)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.copyKey, CooperationInviteDetailPage.Copy.loading)
        XCTAssertEqual(loading.slotCount, .text("—"))
        let empty = CooperationInviteDetailPage.project(key: key, result: .failure(CooperationReadFailure.unavailable))
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.copyKey, "cooperation.unavailable")
        XCTAssertNil(empty.detail)
        XCTAssertEqual(empty.slotCount, .text("—"))
        XCTAssertNotEqual(empty.slotCount, .text("0"))
        let malformed = CooperationInviteDetailPage.project(key: key, result: .failure(APIError.malformedResponse))
        XCTAssertEqual(malformed.phase, .unknown)
        XCTAssertEqual(malformed.copyKey, "cooperation.malformed")
        let ambiguous = CooperationInviteDetailPage.project(key: key, result: .failure(CooperationReadFailure.ambiguousIdentity))
        XCTAssertEqual(ambiguous.phase, .unknown)
        XCTAssertEqual(ambiguous.copyKey, "cooperation.ambiguous")
        let cancelled = CooperationInviteDetailPage.project(key: key, result: .failure(CancellationError()))
        XCTAssertEqual(cancelled.phase, .loading)
        let failed = CooperationInviteDetailPage.project(key: key, result: .failure(APIError.unauthorized))
        XCTAssertEqual(failed.phase, .error)
        XCTAssertEqual(failed.copyKey, "cooperation.login")
        XCTAssertEqual(failed.slotCapacity, .text("—"))
        let unidentified = CooperationInviteDetailPage.project(key: .init(id: 0, direction: .sent), result: .success(try detail(id: 7, direction: .received, json: #"{"received":[{"id":7,"status":0}]}"#)))
        XCTAssertEqual(unidentified.phase, .unknown)
        XCTAssertNil(unidentified.detail)
        XCTAssertEqual(unidentified.slotCount, .text("—"))
        XCTAssertFalse(CooperationInviteDetailPage.routeMarkedLive)
        XCTAssertFalse(CooperationInviteDetailPage.opensNewInviteSurface)
        XCTAssertEqual(CooperationInviteDetailPage.readPath, "api/coop/list")
        XCTAssertEqual(CooperationInviteDetailPage.unknownDisplay, "—")
    }

    func testReadyUnknownStatusStillShowsTheRow() throws {
        let row = try detail(id: 7, direction: .received, json: #"{"received":[{"id":7,"status":99,"topicId":3}],"slots":{"byTopic":{"3":{"accepted":0,"cap":null}}}}"#)
        let page = CooperationInviteDetailPage.project(key: .init(id: 7, direction: .received), result: .success(row))
        XCTAssertEqual(page.phase, .ready)
        XCTAssertEqual(page.detail?.row.statusKey, "cooperation.status.unknown")
        XCTAssertEqual(page.slotCount, .text("0"))
        XCTAssertEqual(page.slotCapacity, .text("—"))
        XCTAssertNil(page.copyKey)
    }

    @MainActor func testLoadUsesExistingDetailAndSkipsAnUnconfirmedId() async {
        let reader = InviteDetailPageStub()
        let hidden = await CooperationInviteDetailPage.load(reader: reader, key: .init(id: 0, direction: .received))
        XCTAssertEqual(hidden.phase, .unknown)
        XCTAssertEqual(reader.detailCalls, 0)
        reader.detailResult = .failure(CooperationReadFailure.unavailable)
        let missing = await CooperationInviteDetailPage.load(reader: reader, key: .init(id: 7, direction: .received))
        XCTAssertEqual(missing.phase, .empty)
        XCTAssertEqual(reader.detailCalls, 1)
        XCTAssertEqual(missing.slotCount, .text("—"))
    }

    func testDetailReadKeepsListRouteAndSlotFacts() async throws {
        let json = #"{"code":200,"data":{"sent":[{"id":71,"topicId":301,"status":1}],"received":[{"id":71,"gameId":401,"topicId":301,"status":0}],"slots":{"byGame":{"401":{"pending":"UNKNOWN","cap":0}},"byTopic":{"301":{"accepted":1,"cap":3}}}}}"#
        let transport = InviteDetailTransport(["/api/coop/list": json])
        let api = try CooperationService(configuration: APIConfiguration(baseURL: URL(string: "https://example.com/test/")!), transport: transport)
        let received = try await api.detail(key: .init(id: 71, direction: .received), token: "synthetic-token")
        XCTAssertNil(received.occupancy)
        XCTAssertEqual(received.slotLine?.kind, .gamePending)
        XCTAssertEqual(received.slotLine?.count.displayText, "—")
        XCTAssertEqual(received.slotLine?.capacity.displayText, "0")
        XCTAssertNil(received.slotLine?.count.literal)
        XCTAssertEqual(received.slotLine?.capacity.literal, 0)
        let sent = try await api.detail(key: .init(id: 71, direction: .sent), token: "synthetic-token")
        XCTAssertEqual(sent.occupancy?.kind, .topicAccepted)
        XCTAssertEqual(sent.slotLine?.count.displayText, "1")
        XCTAssertEqual(sent.slotLine?.capacity.displayText, "3")
        let paths = await transport.paths
        XCTAssertEqual(paths, ["/test/api/coop/list", "/test/api/coop/list"])
    }
}

@MainActor private final class InviteDetailPageStub: CooperationReading {
    var detailCalls = 0
    var detailResult: Result<CooperationInviteDetail, Error> = .failure(APIError.invalidRequest)
    var isConfigured: Bool { true }
    var isAuthenticated: Bool { true }
    var isOfflineExample: Bool { false }
    let scope = UUID()
    func inbox(direction: CooperationDirection) async throws -> CooperationInbox { throw APIError.invalidRequest }
    func detail(key: CooperationInviteKey) async throws -> CooperationInviteDetail {
        detailCalls += 1
        return try detailResult.get()
    }
    func pool() async throws -> CooperationPool { throw APIError.invalidRequest }
    func candidates(topicID: Int) async throws -> CooperationCandidates { throw APIError.invalidRequest }
}

private actor InviteDetailTransport: HTTPTransport {
    let replies: [String: String]
    private(set) var paths: [String] = []
    init(_ replies: [String: String]) { self.replies = replies }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let path = request.url?.path ?? ""
        paths.append(path)
        let body = replies[path.replacingOccurrences(of: "/test", with: "")] ?? #"{"code":200,"data":{}}"#
        return (Data(body.utf8), 200)
    }
}
