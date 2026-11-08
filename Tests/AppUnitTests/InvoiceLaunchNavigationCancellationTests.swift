import XCTest
import Foundation
@testable import Questify

@MainActor final class InvoiceLaunchNavigationCancellationTests: XCTestCase {
    func testCancelledOverviewDoesNotRetireQueuedDetail() async throws {
        let h = try Harness(), revision = h.model.identityRevision
        let overview = Task { await h.model.refresh() }; await h.wire.waitForPending()
        var began = false
        let b = Task { began = true; await h.model.loadDetail(52) }; await waitUntil { began }
        overview.cancel(); h.wire.resume()
        await overview.value; await b.value
        XCTAssertEqual(h.wire.paths, ["titles", "detail"])
        XCTAssertEqual(h.model.detail?.id, 52)
        XCTAssertEqual(h.model.identityRevision, revision)
        XCTAssertNil(h.model.issue); XCTAssertEqual(h.wire.maxActive, 1)
        XCTAssertFalse(h.model.allows(.apply)); XCTAssertTrue(h.memory.values.isEmpty)
    }
    func testCancellationCannotHideActualIdentityLoss() async throws {
        let h = try Harness(), revision = h.model.identityRevision
        let overview = Task { await h.model.refresh() }; await h.wire.waitForPending()
        var began = false
        let b = Task { began = true; await h.model.loadDetail(52) }; await waitUntil { began }
        h.current = nil; overview.cancel(); h.wire.resume()
        await overview.value; await b.value
        XCTAssertNotEqual(h.model.identityRevision, revision)
        XCTAssertEqual(h.wire.paths, ["titles"])
        XCTAssertNil(h.model.detail); XCTAssertEqual(h.model.issue, "session")
        XCTAssertFalse(h.model.busy); XCTAssertFalse(h.model.allows(.apply))
    }
    func testCancelledDetailDoesNotPublishItsResultOrInventSessionFailure() async throws {
        let h = try Harness(), revision = h.model.identityRevision
        let a = Task { await h.model.loadDetail(51) }; await h.wire.waitForPending()
        a.cancel(); h.wire.resume(); await a.value
        XCTAssertNil(h.model.detail); XCTAssertNil(h.model.issue)
        XCTAssertEqual(h.model.identityRevision, revision); XCTAssertFalse(h.model.busy)
        await h.model.loadDetail(52)
        XCTAssertEqual(h.model.detail?.id, 52); XCTAssertEqual(h.wire.ids, [51, 52])
        XCTAssertEqual(h.wire.maxActive, 1)
    }
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<500 { if condition() { return }; await Task.yield() }
        XCTFail("Synthetic navigation did not start")
    }
    @MainActor private final class Memory: InvoiceLaunchStorage {
        var values: [String: Data] = [:]
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws { values[key] = data }
        func remove(_ key: String) throws { values.removeValue(forKey: key) }
    }
    @MainActor private final class Harness {
        let captured: InvoiceLaunchSession
        var current: InvoiceLaunchSession?
        let wire = Wire(), memory = Memory()
        lazy var service = InvoiceLaunchService(session: captured, transport: wire,
            enabled: { true }, current: { [unowned self] in current })
        lazy var store = InvoiceLaunchPendingStore(session: captured, storage: memory)
        lazy var model = InvoiceLaunchPresentation(coordinator: try! InvoiceLaunchCoordinator(service: service, store: store),
            isCurrent: { [unowned self] in current == captured })
        init() throws {
            captured = try InvoiceLaunchSession(baseURL: URL(string: "https://example.test/native")!,
                namespace: "synthetic-navigation", accountID: 7, role: "player", epoch: 1, token: "synthetic-token")
            current = captured
        }
    }
    // Same CheckedContinuation suspension pattern as existing host tests, kept
    // independent because their fake is private and old fixtures must not change.
    @MainActor private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var pending: CheckedContinuation<Void, Never>?
        var delayNext = true
        var active = 0, maxActive = 0
        var paths: [String] { requests.map { $0.url!.lastPathComponent } }
        var ids: [Int64] { requests.compactMap { request in
            guard request.url?.lastPathComponent == "detail", let body = request.httpBody,
                  let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return nil }
            return (object["id"] as? NSNumber)?.int64Value
        } }
        func waitForPending() async {
            for _ in 0..<500 { if pending != nil { return }; await Task.yield() }
            XCTFail("Synthetic read did not suspend")
        }
        func resume() { let waiter = pending; pending = nil; waiter?.resume() }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request); active += 1; maxActive = max(maxActive, active)
            defer { active -= 1 }
            if delayNext { delayNext = false; await withCheckedContinuation { pending = $0 } }
            let data: Any
            if request.url?.lastPathComponent == "detail" {
                let object = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
                let id = (object["id"] as! NSNumber).int64Value
                data = ["id": String(id), "applicationNo": "SYNTHETIC-\(id)", "status": "SUBMITTED",
                    "titleType": "PERSONAL", "titleName": "Synthetic title", "totalAmount": 1,
                    "orderCount": 1, "orders": [["orderId": "21", "amount": 1]]] as [String: Any]
            } else { data = [] as [Any] }
            return (try JSONSerialization.data(withJSONObject: ["code": 200, "data": data]), 200)
        }
    }
}

/// Drives the invoice presentation's main actions (apply / withdraw) through a fake transport.
/// Mutations succeed only when the host grant (`mutationsEnabled`) is on, and the presentation
/// reports success only after the coordinator's read-back, never from the write response alone.
@MainActor final class InvoiceLaunchPresentationActionTests: XCTestCase {
    func testWithdrawSendsOneCancelThenReportsSuccessAfterReadback() async throws {
        let h = try Harness(mutations: true)
        await h.model.refresh()
        XCTAssertNotNil(h.model.overview)
        let ok = await h.model.cancel(51)
        XCTAssertTrue(ok)
        XCTAssertEqual(h.wire.paths.filter { $0 == "cancel" }.count, 1)
        let body = try XCTUnwrap(h.wire.body(for: "cancel"))
        XCTAssertEqual((body["id"] as? NSNumber)?.int64Value, 51)
        XCTAssertEqual(h.wire.authorization(for: "cancel"), "synthetic-token")
        XCTAssertTrue(h.memory.values.isEmpty)
        XCTAssertFalse(h.model.unresolved)
        XCTAssertNil(h.model.issue)
    }
    func testWithdrawNotConfirmedByReadbackStaysUnresolvedAndReportsFailure() async throws {
        let h = try Harness(mutations: true)
        h.wire.cancelStatus = "SUBMITTED"
        await h.model.refresh()
        let ok = await h.model.cancel(51)
        XCTAssertFalse(ok)
        XCTAssertEqual(h.wire.paths.filter { $0 == "cancel" }.count, 1)
        XCTAssertTrue(h.model.unresolved)
        XCTAssertEqual(h.model.issue, "unknown")
        XCTAssertFalse(h.memory.values.isEmpty)
    }
    func testApplySendsExactBodyAndSucceedsOnlyAfterReadback() async throws {
        let h = try Harness(mutations: true)
        await h.model.refresh()
        let ok = await h.model.apply(titleID: 11, orderIDs: [21])
        XCTAssertTrue(ok)
        XCTAssertEqual(h.wire.paths.filter { $0 == "apply" }.count, 1)
        let body = try XCTUnwrap(h.wire.body(for: "apply"))
        XCTAssertEqual(Set(body.keys), ["requestId", "titleId", "orderIds"])
        XCTAssertEqual((body["titleId"] as? NSNumber)?.int64Value, 11)
        XCTAssertEqual((body["orderIds"] as? [NSNumber])?.map(\.int64Value), [21])
        XCTAssertTrue(h.memory.values.isEmpty)
    }
    func testSaveTitleSendsFlatDraftAndSucceedsOnlyWhenListedAfterwards() async throws {
        let h = try Harness(mutations: true)
        await h.model.refresh()
        let draft = try InvoiceLaunchTitleDraft(titleType: "PERSONAL", titleName: "Synthetic title")
        let ok = await h.model.save(draft)
        XCTAssertTrue(ok)
        XCTAssertEqual(h.wire.paths.filter { $0 == "save" }.count, 1)
        let body = try XCTUnwrap(h.wire.body(for: "save"))
        XCTAssertEqual(body["titleType"] as? String, "PERSONAL")
        XCTAssertEqual(body["titleName"] as? String, "Synthetic title")
        XCTAssertEqual(h.model.overview?.titles.map(\.id), [11])
        XCTAssertTrue(h.memory.values.isEmpty)
    }
    func testDeleteTitleSendsIDAndSucceedsOnlyWhenAbsentAfterwards() async throws {
        let h = try Harness(mutations: true)
        h.wire.titleRows = [Wire.title]
        await h.model.refresh()
        XCTAssertEqual(h.model.overview?.titles.map(\.id), [11])
        let ok = await h.model.delete(11)
        XCTAssertTrue(ok)
        XCTAssertEqual(h.wire.paths.filter { $0 == "delete" }.count, 1)
        let body = try XCTUnwrap(h.wire.body(for: "delete"))
        XCTAssertEqual((body["id"] as? NSNumber)?.int64Value, 11)
        XCTAssertEqual(h.model.overview?.titles.count, 0)
        XCTAssertTrue(h.memory.values.isEmpty)
    }
    func testMutationsStayGatedWhenHostGrantIsOff() async throws {
        let h = try Harness(mutations: false)
        await h.model.refresh()
        let applied = await h.model.apply(titleID: 11, orderIDs: [21])
        let cancelled = await h.model.cancel(51)
        XCTAssertFalse(applied); XCTAssertFalse(cancelled)
        XCTAssertFalse(h.wire.paths.contains("apply")); XCTAssertFalse(h.wire.paths.contains("cancel"))
        XCTAssertTrue(h.memory.values.isEmpty)
    }

    @MainActor private final class Memory: InvoiceLaunchStorage {
        var values: [String: Data] = [:]
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws { values[key] = data }
        func remove(_ key: String) throws { values.removeValue(forKey: key) }
    }
    @MainActor private final class Harness {
        let captured: InvoiceLaunchSession
        let wire = Wire(), memory = Memory()
        let mutations: Bool
        lazy var service = InvoiceLaunchService(session: captured, transport: wire,
            enabled: { true }, mutationsEnabled: { [unowned self] in self.mutations },
            current: { [unowned self] in self.captured })
        lazy var store = InvoiceLaunchPendingStore(session: captured, storage: memory)
        lazy var model = InvoiceLaunchPresentation(coordinator: try! InvoiceLaunchCoordinator(service: service, store: store),
            isCurrent: { true }, permits: { _ in true })
        init(mutations: Bool) throws {
            self.mutations = mutations
            captured = try InvoiceLaunchSession(baseURL: URL(string: "https://example.test/native")!,
                namespace: "synthetic-actions", accountID: 7, role: "player", epoch: 1, token: "synthetic-token")
        }
    }
    @MainActor private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var cancelStatus = "CANCELLED"
        var titleRows: [[String: Any]] = []
        static let title: [String: Any] = ["id": 11, "titleType": "PERSONAL", "titleName": "Synthetic title", "isDefault": false]
        var paths: [String] { requests.map { $0.url!.lastPathComponent } }
        func body(for path: String) -> [String: Any]? {
            guard let data = requests.first(where: { $0.url?.lastPathComponent == path })?.httpBody else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        func authorization(for path: String) -> String? {
            requests.first(where: { $0.url?.lastPathComponent == path })?.value(forHTTPHeaderField: "Authorization")
        }
        private func application(status: String, summary: Bool) -> [String: Any] {
            ["id": "51", "applicationNo": "SYNTHETIC-51", "status": status, "titleType": "PERSONAL",
             "titleName": "Synthetic title", "totalAmount": 1, "orderCount": 1,
             "orders": summary ? [] as [Any] : [["orderId": "21", "amount": 1]] as [Any]]
        }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let data: Any
            switch request.url?.lastPathComponent {
            case "cancel": data = application(status: cancelStatus, summary: false)
            case "apply": data = application(status: "SUBMITTED", summary: false)
            case "detail":
                let isCancelFlow = requests.contains { $0.url?.lastPathComponent == "cancel" }
                data = application(status: isCancelFlow ? cancelStatus : "SUBMITTED", summary: false)
            case "list": data = [application(status: "SUBMITTED", summary: true)] as [Any]
            case "titles": data = titleRows as [Any]
            case "save": titleRows = [Wire.title]; data = Wire.title
            case "delete":
                titleRows = []
                return (try JSONSerialization.data(withJSONObject: ["code": 200]), 200)
            default: data = [] as [Any]
            }
            return (try JSONSerialization.data(withJSONObject: ["code": 200, "data": data]), 200)
        }
    }
}
