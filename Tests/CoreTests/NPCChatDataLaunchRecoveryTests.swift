import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// All responses and credentials below are synthetic. This suite never opens a
// URLSession or calls a live export/deletion endpoint.
private let launchNPCExport = #"{"code":200,"data":{"records":[{"id":"9007199254740993","userId":7,"userMsg":"Synthetic question","npcReply":"Synthetic reply"}]}}"#

@MainActor private final class LaunchNPCReply<Value> {
    private var response: CheckedContinuation<Value, Never>?
    private var started: CheckedContinuation<Void, Never>?
    func wait() async -> Value {
        await withCheckedContinuation {
            response = $0; started?.resume(); started = nil
        }
    }
    func waitUntilStarted() async {
        guard response == nil else { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish(_ value: Value) throws {
        let pending = try XCTUnwrap(response)
        response = nil; pending.resume(returning: value)
    }
}

private final class LaunchNPCHTTP: HTTPTransport {
    var requests: [URLRequest] = []
    var duringSend: (() -> Void)?
    var error: Error?
    var reply: (() async -> Data)?
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request); duringSend?()
        if let error { throw error }
        let bytes = await reply?() ?? Data(#"{"code":200,"data":{"deleted":1}}"#.utf8)
        return (bytes, 200)
    }
}

final class NPCChatDataLaunchDeletionEnvelopeTests: XCTestCase {
    func testDefiniteRejectionIsIndependentOfTheSuccessPayloadShape() {
        for data in [#"{"deleted":"wrong-type"}"#, #"{"deleted":true}"#, #""error-detail""#, "[]", "null"] {
            let bytes = Data((#"{"code":403,"data":"# + data + "}").utf8)
            XCTAssertThrowsError(try NPCChatLogDeletion.decode(bytes)) {
                XCTAssertEqual($0 as? NPCChatDataFailure, .rejected)
            }
        }
    }
    func testUnreadableSuccessAndOversizedBodyRemainUnknown() throws {
        for json in [#"{"code":200,"data":"wrong-type"}"#, #"{"code":"200","data":{"deleted":1}}"#] {
            XCTAssertEqual(try NPCChatLogDeletion.decode(Data(json.utf8)), .unknown)
        }
        XCTAssertEqual(try NPCChatLogDeletion.decode(Data(count: 65_537)), .unknown)
    }
}

@MainActor final class NPCChatDataLaunchDeletionServiceTests: XCTestCase {
    private let session = ComplianceSession(accountID: 7, epoch: 1, market: "CN", namespace: "synthetic.invalid")
    private var configuration: APIConfiguration { try! .init(baseURL: URL(string: "https://synthetic.test")!) }
    private func approval(extraRead: Bool = false) throws -> OperationEndpointApproval {
        try .init(baseURL: configuration.baseURL, namespace: session.namespace, accountID: session.accountID,
                  paths: extraRead ? [NPCChatLogDeletion.path, NPCChatData.path] : [NPCChatLogDeletion.path])
    }
    func testRevokedOrReplacedApprovalRetiresBothSuccessAndTransportFailure() async throws {
        for replacement in [false, true] {
            for fails in [false, true] {
                let http = LaunchNPCHTTP()
                var accepted: OperationEndpointApproval? = try approval()
                let next = replacement ? try approval(extraRead: true) : nil
                let service = NPCChatLogDeletionService(configuration: configuration, transport: http,
                    current: { self.session }, token: { "synthetic-test-token" }, approval: { accepted })
                http.duringSend = { accepted = next }
                if fails { http.error = URLError(.networkConnectionLost) }
                do { _ = try await service.delete(session: session); XCTFail("Retired grant returned a result") }
                catch { XCTAssertEqual(error as? NPCChatDataFailure, .staleSession) }
                XCTAssertEqual(http.requests.count, 1)
            }
        }
    }
    func testLostResponseAfterIdentityChangeCannotEscapeAsAnotherSessionsUnknown() async throws {
        for variant in 0..<4 {
            let http = LaunchNPCHTTP(), accepted = try approval()
            var current: ComplianceSession? = session
            var token = "synthetic-test-token"
            let service = NPCChatLogDeletionService(configuration: configuration, transport: http,
                current: { current }, token: { token }, approval: { accepted })
            http.duringSend = {
                switch variant {
                case 0: current = .init(accountID: 7, epoch: 2, market: "CN", namespace: "synthetic.invalid")
                case 1: current = .init(accountID: 7, epoch: 1, market: "US", namespace: "synthetic.invalid")
                case 2: current = .init(accountID: 7, epoch: 1, market: "CN", namespace: "other.invalid")
                default: token = "replacement-synthetic-token"
                }
            }
            http.error = URLError(.networkConnectionLost)
            do { _ = try await service.delete(session: session); XCTFail() }
            catch { XCTAssertEqual(error as? NPCChatDataFailure, .staleSession) }
            XCTAssertEqual(http.requests.count, 1)
        }
    }
    func testCancellationBeforeDispatchSendsNothing() async throws {
        let http = LaunchNPCHTTP(), accepted = try approval()
        let service = NPCChatLogDeletionService(configuration: configuration, transport: http,
            current: { self.session }, token: { "synthetic-test-token" }, approval: { accepted })
        let task = Task { try await service.delete(session: session) }
        task.cancel()
        do { _ = try await task.value; XCTFail() }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(http.requests.isEmpty)
    }
    func testCancellationAfterDispatchIsUnknownAndNeverResends() async throws {
        let http = LaunchNPCHTTP(), accepted = try approval(), reply = LaunchNPCReply<Data>()
        http.reply = { await reply.wait() }
        let service = NPCChatLogDeletionService(configuration: configuration, transport: http,
            current: { self.session }, token: { "synthetic-test-token" }, approval: { accepted })
        let task = Task { try await service.delete(session: session) }
        await reply.waitUntilStarted(); task.cancel()
        try reply.finish(Data(#"{"code":200,"data":{"deleted":1}}"#.utf8))
        let result = try await task.value
        XCTAssertEqual(result, .unknown); XCTAssertEqual(http.requests.count, 1)
    }
}

@MainActor final class NPCChatDataLaunchCoordinatorTests: XCTestCase {
    private let session = ComplianceSession(accountID: 7, epoch: 1, market: "CN", namespace: "synthetic.invalid")
    private func data() throws -> NPCChatData { try .decode(Data(launchNPCExport.utf8), expectedAccountID: 7) }

    func testRevocationDuringDeletionRetiresOutcomeAndSkipsAutomaticReadback() async throws {
        for revokeRead in [false, true] {
            for outcome in [NPCChatLogDeletionOutcome.deleted(count: 1), .unknown] {
                let reply = LaunchNPCReply<NPCChatLogDeletionOutcome>(), value = try data()
                var reads = 0, deletes = 0, readAllowed = true, deleteAllowed = true
                let flow = NPCChatDataCoordinator(current: { self.session }, available: { _ in readAllowed },
                    read: { _ in reads += 1; return value }, deletionAvailable: { _ in deleteAllowed },
                    deleteLogs: { _ in deletes += 1; return await reply.wait() })
                flow.appear(active: true); await flow.load(); flow.requestDeletion()
                let task = Task { await flow.confirmDeletion() }
                await reply.waitUntilStarted()
                if revokeRead { readAllowed = false } else { deleteAllowed = false }
                try reply.finish(outcome); await task.value
                XCTAssertNil(flow.data); XCTAssertEqual(flow.deletion, .idle)
                XCTAssertEqual(reads, 1); XCTAssertEqual(deletes, 1)
                await flow.confirmDeletion(); XCTAssertEqual(deletes, 1)
            }
        }
    }
    func testIdentityFailureClearsPreviouslyLoadedPrivateText() async throws {
        for failure in [NPCChatDataFailure.signedOut, .staleSession] {
            let value = try data()
            let flow = NPCChatDataCoordinator(current: { self.session }, available: { _ in true }, read: { _ in value },
                deletionAvailable: { _ in true }, deleteLogs: { _ in throw failure })
            flow.appear(active: true); await flow.load(); flow.requestDeletion(); await flow.confirmDeletion()
            XCTAssertNil(flow.data); XCTAssertEqual(flow.deletion, .failed(failure))
            XCTAssertFalse(flow.canRequestDeletion)
        }
    }
    func testUnknownSurvivesFailedReadbackAndExplicitReloadWithoutResending() async throws {
        let value = try data(); var reads = 0, deletes = 0
        let flow = NPCChatDataCoordinator(current: { self.session }, available: { _ in true }, read: { _ in
            reads += 1; if reads == 2 { throw NPCChatDataFailure.failed }; return value
        }, deletionAvailable: { _ in true }, deleteLogs: { _ in deletes += 1; return .unknown })
        flow.appear(active: true); await flow.load(); flow.requestDeletion(); await flow.confirmDeletion()
        XCTAssertEqual(flow.deletion, .unknown); XCTAssertNil(flow.data); XCTAssertEqual(flow.phase, .unavailable)
        XCTAssertFalse(flow.canRequestDeletion); XCTAssertEqual(reads, 2); XCTAssertEqual(deletes, 1)
        await flow.confirmDeletion(); XCTAssertEqual(deletes, 1)
        await flow.load()
        XCTAssertEqual(flow.deletion, .unknown); XCTAssertNotNil(flow.data)
        XCTAssertEqual(reads, 3); XCTAssertEqual(deletes, 1)
        flow.invalidate()
        let reopened = NPCChatDataCoordinator(current: { self.session }, available: { _ in true },
            read: { _ in reads += 1; return value }, deletionAvailable: { _ in true },
            deleteLogs: { _ in deletes += 1; return .unknown })
        reopened.appear(active: true)
        XCTAssertNil(reopened.data); XCTAssertEqual(reopened.deletion, .idle)
        await reopened.confirmDeletion(); XCTAssertEqual(deletes, 1); XCTAssertEqual(reads, 3)
        await reopened.load(); XCTAssertEqual(reads, 4); XCTAssertEqual(deletes, 1)
    }
    func testLateDeletionFromPriorLifecycleCannotEraseNewExplicitRead() async throws {
        let reply = LaunchNPCReply<NPCChatLogDeletionOutcome>(), value = try data(); var reads = 0
        let flow = NPCChatDataCoordinator(current: { self.session }, available: { _ in true },
            read: { _ in reads += 1; return value }, deletionAvailable: { _ in true }, deleteLogs: { _ in await reply.wait() })
        flow.appear(active: true); await flow.load(); flow.requestDeletion()
        let task = Task { await flow.confirmDeletion() }
        await reply.waitUntilStarted(); flow.suspend(); flow.foreground(); await flow.load()
        try reply.finish(.deleted(count: 1)); await task.value
        XCTAssertNotNil(flow.data); XCTAssertEqual(flow.deletion, .idle); XCTAssertEqual(reads, 2)
    }
    func testSameAccountEpochChangeDiscardsLateExportWithoutHostNotification() async throws {
        let reply = LaunchNPCReply<NPCChatData>(), value = try data()
        var current: ComplianceSession? = session
        let flow = NPCChatDataCoordinator(current: { current }, available: { _ in true }, read: { _ in await reply.wait() })
        flow.appear(active: true); let task = Task { await flow.load() }
        await reply.waitUntilStarted()
        current = .init(accountID: 7, epoch: 2, market: "CN", namespace: "synthetic.invalid")
        try reply.finish(value); await task.value
        XCTAssertNil(flow.data); XCTAssertEqual(flow.phase, .idle)
    }
    func testLifecycleExitFromLoadingNotificationPreventsDispatch() async throws {
        let value = try data(); var reads = 0
        let flow = NPCChatDataCoordinator(current: { self.session }, available: { _ in true }, read: { _ in reads += 1; return value })
        flow.onChange = { [weak flow] in if flow?.phase == .loading { flow?.invalidate() } }
        flow.appear(active: true); await flow.load()
        XCTAssertEqual(reads, 0); XCTAssertNil(flow.data); XCTAssertFalse(flow.canLoad)
    }
    func testLifecycleExitFromDeletingNotificationPreventsDispatch() async throws {
        let value = try data(); var deletes = 0
        let flow = NPCChatDataCoordinator(current: { self.session }, available: { _ in true }, read: { _ in value },
            deletionAvailable: { _ in true }, deleteLogs: { _ in deletes += 1; return .deleted(count: 1) })
        flow.onChange = { [weak flow] in if flow?.deletion == .deleting { flow?.invalidate() } }
        flow.appear(active: true); await flow.load(); flow.requestDeletion(); await flow.confirmDeletion()
        XCTAssertEqual(deletes, 0); XCTAssertNil(flow.data); XCTAssertEqual(flow.deletion, .idle)
    }
}
