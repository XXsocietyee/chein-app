import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

final class MemberAreaPopupClosureTests: XCTestCase {
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

    func testDisableRoamPresencePostsVisibleFalseAndReturnsDisabledOnFalseEcho() async {
        let transport = StubHTTPTransport { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/roam/presence-visibility")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
            let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
            XCTAssertTrue(body.contains("visible=false"))
            XCTAssertFalse(body.contains("roam-presence-v1"))
            return (Data(#"{"code":200,"data":false}"#.utf8), 200)
        }
        let service = RoamPresenceVisibilityService(configuration: baseConfig, transport: transport)
        let outcome = await service.disablePresence(token: "Bearer token-123")
        XCTAssertEqual(outcome, .disabled)
        XCTAssertEqual(transport.requests.count, 1)

        let missingToken = await service.disablePresence(token: nil)
        XCTAssertEqual(missingToken, .unavailable)
    }

    func testRoamConsentWithdrawalFeedbackTransitions() {
        XCTAssertEqual(
            RoamConsentWithdrawalFeedback.evaluate(previous: .idle, current: .complete, error: nil),
            .withdrawn
        )
        XCTAssertEqual(
            RoamConsentWithdrawalFeedback.evaluate(previous: .idle, current: .serverConfirmed, error: "err"),
            .partialLocalPending
        )
        XCTAssertEqual(
            RoamConsentWithdrawalFeedback.evaluate(previous: .idle, current: .idle, error: "err"),
            .failed
        )
    }

    func testSettingsClubPickerServiceRoutesOwnedAndErrors() async {
        let oneTransport = StubHTTPTransport { request in
            XCTAssertEqual(request.url?.path, "/api/club/my")
            return (Data(#"{"code":200,"data":{"owned":[{"id":41,"name":"Solo Club","city":"Shanghai"}]}}"#.utf8), 200)
        }
        let oneOutcome = await SettingsClubPickerService(configuration: baseConfig, transport: oneTransport)
            .resolveEntry(token: "token-abc")
        if case .openClub(let club) = oneOutcome {
            XCTAssertEqual(club.id, 41)
            XCTAssertEqual(club.name, "Solo Club")
        } else {
            XCTFail("Expected .openClub, got \(oneOutcome)")
        }

        let manyTransport = StubHTTPTransport { _ in
            (Data(#"{"code":200,"data":{"owned":[{"id":1,"name":"Alpha"},{"id":2,"name":"Beta"}]}}"#.utf8), 200)
        }
        let manyOutcome = await SettingsClubPickerService(configuration: baseConfig, transport: manyTransport)
            .resolveEntry(token: "token-abc")
        if case .chooseClub(let clubs) = manyOutcome {
            XCTAssertEqual(clubs.map(\.id), [1, 2])
        } else {
            XCTFail("Expected .chooseClub, got \(manyOutcome)")
        }

        let emptyTransport = StubHTTPTransport { _ in
            (Data(#"{"code":200,"data":{"owned":[]}}"#.utf8), 200)
        }
        let emptyOutcome = await SettingsClubPickerService(configuration: baseConfig, transport: emptyTransport)
            .resolveEntry(token: "token-abc")
        XCTAssertEqual(emptyOutcome, .applyForHost)

        let networkTransport = StubHTTPTransport { _ in throw URLError(.notConnectedToInternet) }
        let netOutcome = await SettingsClubPickerService(configuration: baseConfig, transport: networkTransport)
            .resolveEntry(token: "token-abc")
        XCTAssertEqual(netOutcome, .failed(message: SettingsClubPickerService.networkFailureMessage))

        let serverErrorTransport = StubHTTPTransport { _ in
            (Data(#"{"code":500,"msg":"server error"}"#.utf8), 500)
        }
        let errOutcome = await SettingsClubPickerService(configuration: baseConfig, transport: serverErrorTransport)
            .resolveEntry(token: "token-abc")
        XCTAssertEqual(errOutcome, .failed(message: SettingsClubPickerService.loadFailureMessage))
    }

    func testSettingsClubHostRouteMatchesPickClub() async {
        let empty = StubHTTPTransport { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/club/my")
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
            XCTAssertTrue(body.isEmpty)
            return (Data(#"{"code":200,"data":{"owned":[]}}"#.utf8), 200)
        }
        let service = SettingsClubPickerService(configuration: baseConfig, transport: empty)
        let leader = await service.resolveHostRoute(token: "token-abc", isClubLeader: true)
        XCTAssertEqual(leader, .createClub)
        let player = await service.resolveHostRoute(token: "token-abc", isClubLeader: false)
        XCTAssertEqual(player, .applyForHost)

        let many = StubHTTPTransport { _ in
            (Data(#"{"code":200,"data":{"owned":[{"id":1,"name":"Alpha"},{"id":2,"name":"Beta"}]}}"#.utf8), 200)
        }
        let owned = await SettingsClubPickerService(configuration: baseConfig, transport: many)
            .resolveHostRoute(token: "token-abc", isClubLeader: false)
        if case .openManage(let club) = owned {
            XCTAssertEqual(club.id, 1)
            XCTAssertEqual(SettingsClubHostRoute.manageTab, "manage")
        } else {
            XCTFail("Expected manage tab for any owned club, got \(owned)")
        }
    }

    func testHostRouterDropsASecondTapWhileClubMyIsInFlight() async {
        actor Gate {
            private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
            private var releaseWaiters: [CheckedContinuation<Void, Never>] = []
            private var entered = false
            private var released = false
            private(set) var hits = 0
            func enteredOnce() async {
                hits += 1
                entered = true
                enteredWaiters.forEach { $0.resume() }
                enteredWaiters.removeAll()
                if released { return }
                await withCheckedContinuation { releaseWaiters.append($0) }
            }
            func waitUntilEntered() async {
                if entered { return }
                await withCheckedContinuation { enteredWaiters.append($0) }
            }
            func release() {
                released = true
                releaseWaiters.forEach { $0.resume() }
                releaseWaiters.removeAll()
            }
        }
        final class Transport: HTTPTransport {
            let gate: Gate
            init(_ gate: Gate) { self.gate = gate }
            func send(_ request: URLRequest) async throws -> (Data, Int) {
                await gate.enteredOnce()
                return (Data(#"{"code":200,"data":{"owned":[]}}"#.utf8), 200)
            }
        }
        let gate = Gate()
        let router = await MainActor.run {
            SettingsClubHostRouter(configuration: baseConfig, transport: Transport(gate))
        }
        let first = Task { await router.resolve(token: "token-abc", isClubLeader: true) }
        await gate.waitUntilEntered()
        let dropped = await router.resolve(token: "token-abc", isClubLeader: true)
        XCTAssertNil(dropped)
        await gate.release()
        let route = await first.value
        XCTAssertEqual(route, .createClub)
        XCTAssertEqual(await gate.hits, 1)
    }

    func testNPCChatExportFormatterAndDeepLinkExitPolicy() throws {
        let json = #"{"code":200,"data":{"retentionDays":30,"records":[{"id":9,"userId":5,"userMsg":"Hi","npcReply":"Hello","createTime":"2026-11-14"}]}}"#
        let data = try NPCChatData.decode(Data(json.utf8), expectedAccountID: 5)
        let formatted = NPCChatDataExportFormatter.formatTranscript(from: data)
        XCTAssertTrue(formatted.contains("Q: Hi"))
        XCTAssertTrue(formatted.contains("A: Hello"))

        XCTAssertEqual(DeepLinkSceneExitPolicy.evaluate(isDirty: false), .closeImmediately)
        if case .confirmDiscard(let prompt) = DeepLinkSceneExitPolicy.evaluate(isDirty: true) {
            XCTAssertEqual(prompt.title, "放弃当前修改？")
            XCTAssertEqual(prompt.confirmTitle, "放弃并关闭")
            XCTAssertEqual(prompt.cancelTitle, "继续编辑")
        } else {
            XCTFail("Expected confirmDiscard when dirty")
        }
    }

    func testInvoiceIssuerGroupingAndMixedIssuerGuard() throws {
        let payload = #"""
        [
            {"orderId":101,"issuerId":10,"issuerName":"Issuer A","amount":28.50,"orderTitle":"Order A1"},
            {"orderId":102,"issuerId":10,"issuerName":"Issuer A","amount":12.00,"orderTitle":"Order A2"},
            {"orderId":103,"issuerId":20,"issuerName":"Issuer B","amount":30.00,"orderTitle":"Order B1"},
            {"orderId":104,"issuerId":null,"issuerName":null,"amount":18.00,"orderTitle":"Pending Issuer"}
        ]
        """#
        let orders = try JSONDecoder().decode([InvoiceLaunchOrder].self, from: Data(payload.utf8))
        let groups = InvoiceIssuerSelectionGuard.group(orders: orders)
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0].orders.map(\.orderId), [101, 102])
        XCTAssertTrue(groups[0].isEnabled)
        XCTAssertFalse(groups[2].isEnabled)

        var selected = Set<Int64>()
        if case .updated(let first) = InvoiceIssuerSelectionGuard.toggle(order: orders[0], in: orders, currentlySelected: selected) {
            selected = first
        } else {
            XCTFail("First enabled order should select")
        }

        if case .updated(let sameIssuer) = InvoiceIssuerSelectionGuard.toggle(order: orders[1], in: orders, currentlySelected: selected) {
            selected = sameIssuer
        } else {
            XCTFail("Same issuer order should select")
        }

        let mixed = InvoiceIssuerSelectionGuard.toggle(order: orders[2], in: orders, currentlySelected: selected)
        XCTAssertEqual(mixed, .rejectedMixedIssuers(message: InvoiceIssuerSelectionGuard.mixedIssuersMessage))

        let disabled = InvoiceIssuerSelectionGuard.toggle(order: orders[3], in: orders, currentlySelected: selected)
        XCTAssertEqual(disabled, .rejectedUnenabledIssuer(message: InvoiceIssuerSelectionGuard.unenabledIssuerMessage))
    }

    func testCoopInviteDraftValidationAndTrimming() {
        var draft = MemberCoopInviteDraft()
        XCTAssertFalse(draft.isReadyToSend)
        draft.selectedChapterID = 7
        draft.note = "  欢迎合作  "
        XCTAssertTrue(draft.isReadyToSend)
        XCTAssertEqual(draft.normalizedNote, "欢迎合作")
    }
}
