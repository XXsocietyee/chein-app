import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

private final class StubRetryHTTPTransport: HTTPMetadataTransport, @unchecked Sendable {
    enum Reply {
        case response(Data, Int, [String: String] = [:])
        case failure(Error)
    }

    private let lock = NSLock()
    private var scripted: [Reply]
    private(set) var recordedRequests: [URLRequest] = []
    var onDispatch: ((Int, URLRequest) -> Void)?

    init(_ scripted: [Reply]) {
        self.scripted = scripted
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, status, _) = try await sendWithHeaders(request)
        return (data, status)
    }

    func sendWithHeaders(_ request: URLRequest) async throws -> (data: Data, status: Int, headers: [String: String]) {
        let index: Int
        let next: Reply
        lock.lock()
        index = recordedRequests.count
        recordedRequests.append(request)
        next = scripted.isEmpty ? .response(Data(#"{"code":200}"#.utf8), 200, [:]) : scripted.removeFirst()
        lock.unlock()

        onDispatch?(index, request)

        switch next {
        case .response(let data, let status, let headers):
            return (data, status, headers)
        case .failure(let error):
            throw error
        }
    }
}

private final class DelayRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var delays: [TimeInterval] = []

    func append(_ seconds: TimeInterval) {
        lock.lock()
        delays.append(seconds)
        lock.unlock()
    }
}

final class OfflineRetryPackage63Tests: XCTestCase {

    // MARK: - Read Retry + Backoff + Retry-After

    func testReadGetRetriesTransientErrorsWithMiniProgram400msExponentialBackoffAndPreservesRequestID() async throws {
        let okData = Data(#"{"code":200,"data":{"ok":true}}"#.utf8)
        let stub = StubRetryHTTPTransport([
            .failure(URLError(.timedOut)),
            .failure(URLError(.networkConnectionLost)),
            .response(okData, 200)
        ])
        let recorder = DelayRecorder()
        let transport = ReadRetryHTTPTransport(
            underlying: stub,
            policy: ReadRetryPolicy(maxAutoRetries: 2, baseDelayMs: 400, jitterRatio: 0.0, respectsRetryAfterHeader: true),
            isOnline: { true },
            sessionFingerprint: { "acct:7|epoch:1" },
            makeRequestID: { "pkg63readcorr1234" },
            sleep: { recorder.append($0) }
        )

        var req = URLRequest(url: URL(string: "https://example.test/api/roam/pois?lat=30&lng=120")!)
        req.httpMethod = "GET"
        let (data, status) = try await transport.send(req)

        XCTAssertEqual(status, 200)
        XCTAssertEqual(data, okData)
        XCTAssertEqual(stub.recordedRequests.count, 3)
        XCTAssertEqual(recorder.delays, [0.4, 0.8])
        for attemptReq in stub.recordedRequests {
            XCTAssertEqual(attemptReq.value(forHTTPHeaderField: "X-Request-Id"), "pkg63readcorr1234")
        }
    }

    func testRead429And503HonorRetryAfterHeaderFloor() async throws {
        let okData = Data(#"{"code":200}"#.utf8)
        let stub = StubRetryHTTPTransport([
            .response(Data(), 429, ["retry-after": "6"]),
            .response(Data(), 503, ["retry-after": "2"]),
            .response(okData, 200)
        ])
        let recorder = DelayRecorder()
        let transport = ReadRetryHTTPTransport(
            underlying: stub,
            policy: ReadRetryPolicy(maxAutoRetries: 2, baseDelayMs: 400),
            isOnline: { true },
            sleep: { recorder.append($0) }
        )

        var req = URLRequest(url: URL(string: "https://example.test/api/topic/list")!)
        req.httpMethod = "GET"
        let (_, status) = try await transport.send(req)

        XCTAssertEqual(status, 200)
        XCTAssertEqual(stub.recordedRequests.count, 3)
        XCTAssertEqual(recorder.delays, [6.0, 2.0])
    }

    func testReadNeverRetriesBusinessNon200Or401AndAbortsOnSessionChange() async throws {
        // 1. Business error inside HTTP 200 must never be retried
        let bizStub = StubRetryHTTPTransport([
            .response(Data(#"{"code":500,"msg":"bad param"}"#.utf8), 200),
            .response(Data(#"{"code":200}"#.utf8), 200)
        ])
        let bizTransport = ReadRetryHTTPTransport(underlying: bizStub, sleep: { _ in XCTFail("Should not sleep") })
        var bizReq = URLRequest(url: URL(string: "https://example.test/api/activity/info")!)
        bizReq.httpMethod = "GET"
        let (_, bizStatus) = try await bizTransport.send(bizReq)
        XCTAssertEqual(bizStatus, 200)
        XCTAssertEqual(bizStub.recordedRequests.count, 1)

        // 2. Session change aborts immediately without retry
        var currentFingerprint: String? = "acct:1|epoch:1"
        let sessionStub = StubRetryHTTPTransport([
            .failure(URLError(.timedOut)),
            .response(Data(#"{"code":200}"#.utf8), 200)
        ])
        sessionStub.onDispatch = { idx, _ in
            if idx == 0 { currentFingerprint = "acct:2|epoch:1" }
        }
        let sessionTransport = ReadRetryHTTPTransport(
            underlying: sessionStub,
            sessionFingerprint: { currentFingerprint },
            sleep: { _ in XCTFail("Session changed, must not retry") }
        )
        var req2 = URLRequest(url: URL(string: "https://example.test/api/club/detail")!)
        req2.httpMethod = "GET"
        do {
            _ = try await sessionTransport.send(req2)
            XCTFail("Expected CancellationError when session changed")
        } catch is CancellationError {
            XCTAssertEqual(sessionStub.recordedRequests.count, 1)
        }
    }

    func testWritesAndMoneyRoutesAreNeverAutomaticallyRetried() async {
        let paths: [(String, String)] = [
            ("POST", "/api/club"),
            ("POST", "/api/roam/reveal"),
            ("POST", "/api/roam/stamp/create"),
            ("POST", "/api/pay/create"),
            ("POST", "/api/withdrawal/create"),
            ("POST", "/api/merchant/commerce/order"),
            ("POST", "/api/registration/pay"),
            ("POST", "/api/cart/order/settlement"),
            ("DELETE", "/api/topic/attribute-author")
        ]
        for (method, path) in paths {
            let stub = StubRetryHTTPTransport([
                .failure(URLError(.timedOut)),
                .response(Data(#"{"code":200}"#.utf8), 200)
            ])
            let transport = ReadRetryHTTPTransport(
                underlying: stub,
                sleep: { _ in XCTFail("Writes must never sleep/retry: \(method) \(path)") }
            )
            var req = URLRequest(url: URL(string: "https://example.test\(path)")!)
            req.httpMethod = method
            do {
                _ = try await transport.send(req)
                XCTFail("Expected write error for \(method) \(path)")
            } catch {
                XCTAssertEqual(stub.recordedRequests.count, 1, "Write \(method) \(path) must send once")
            }
        }
    }

    // MARK: - Queued Offline Writes + Idempotency Keys + Never Replay Money Writes

    func testOfflineWriteQueueRejectsAllMoneyWritesAndNeverReplaysThem() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pkg63-money-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let scope = try OfflineWriteQueueScope(accountID: 42, realm: "cn-e2e-test", baseURL: "https://8120.test")
        let queue = try OfflineIdempotentWriteQueue(fileURL: url)

        let moneyPaths = [
            "/api/pay/create",
            "/api/withdrawal/create",
            "/api/asset/withdraw",
            "/api/wallet/withdraw",
            "/api/registration/pay",
            "/api/registration/pay/app",
            "/api/merchant/commerce/order",
            "/api/marketing/group-checkout/create",
            "/api/club/settlement/withdraw",
            "/api/coupon/publish",
            "/api/coupon/stop",
            "/api/coop/deposit/create",
            "/api/invoice/apply",
            "/api/platform-pass/orders",
            "/api/ai/npc/voice-chat"
        ]

        for path in moneyPaths {
            var req = URLRequest(url: URL(string: "https://8120.test\(path)")!)
            req.httpMethod = "POST"
            req.httpBody = Data(#"{"requestId":"req12345678"}"#.utf8)
            XCTAssertThrowsError(try queue.enqueueOfflineWrite(req, scope: scope), path) { err in
                XCTAssertEqual(err as? OfflineWriteQueueError, .moneyWriteNeverAutoReplayed)
            }
        }
        XCTAssertTrue(queue.pendingItems(for: scope).isEmpty)
    }

    func testOfflineWriteQueueInjectsIdempotencyKeysPersistsAcrossReloadAndFlushesWithSameKey() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pkg63-queue-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let queueURL = dir.appendingPathComponent("queue.json")
        let opURL = dir.appendingPathComponent("opids.json")
        let opStore = try FileClientOperationIDStore(fileURL: opURL)
        let scope = try OfflineWriteQueueScope(accountID: 99, realm: "cn-e2e-test", baseURL: "https://8120.test")

        let queue = try OfflineIdempotentWriteQueue(fileURL: queueURL, operationIDStore: opStore)

        // 1. JSON body requestId route
        var req1 = URLRequest(url: URL(string: "https://8120.test/api/roam/presence-visibility")!)
        req1.httpMethod = "POST"
        req1.httpBody = Data(#"{"visible":true}"#.utf8)
        let item1 = try queue.enqueueOfflineWrite(req1, scope: scope, explicitKey: "pres12345678")
        // Duplicate offline tap must deduplicate cleanly
        let dup1 = try queue.enqueueOfflineWrite(req1, scope: scope, explicitKey: "pres12345678")
        XCTAssertEqual(item1.id, dup1.id)

        // 2. JSON body idempotencyKey route
        var req2 = URLRequest(url: URL(string: "https://8120.test/api/play/advanced/action")!)
        req2.httpMethod = "POST"
        req2.httpBody = Data(#"{"sessionId":12,"action":"ROLL"}"#.utf8)
        let item2 = try queue.enqueueOfflineWrite(req2, scope: scope, explicitKey: "advact123456")

        // 3. Form body idempotencyKey route
        var req3 = URLRequest(url: URL(string: "https://8120.test/api/roam/stamp/create")!)
        req3.httpMethod = "POST"
        req3.httpBody = Data("picUrl=https%3A%2F%2Fcdn.test%2Fa.jpg&caption=hello".utf8)
        let item3 = try queue.enqueueOfflineWrite(req3, scope: scope, explicitKey: "stamp1234567")

        // 4. Custom Header idempotency route (/api/club/join)
        var req4 = URLRequest(url: URL(string: "https://8120.test/api/club/join")!)
        req4.httpMethod = "POST"
        req4.httpBody = Data(#"{"clubId":5}"#.utf8)
        let item4 = try queue.enqueueOfflineWrite(req4, scope: scope, explicitKey: "clubjoin1234")

        // Ensure Authorization is never stored on disk
        let rawDisk = try String(contentsOf: queueURL, encoding: .utf8)
        XCTAssertFalse(rawDisk.contains("secret-token"))

        // Reload queue from disk in a fresh instance
        let reloaded = try OfflineIdempotentWriteQueue(fileURL: queueURL, operationIDStore: opStore)
        XCTAssertEqual(reloaded.queuedItems(for: scope).count, 4)

        let stub = StubRetryHTTPTransport([
            .response(Data(#"{"code":200}"#.utf8), 200),
            .response(Data(#"{"code":200}"#.utf8), 200),
            .response(Data(#"{"code":200}"#.utf8), 200),
            .response(Data(#"{"code":200}"#.utf8), 200)
        ])
        let api = try APIConfiguration(baseURL: URL(string: "https://8120.test")!)
        let report = try await reloaded.flushPending(
            scope: scope,
            configuration: api,
            token: "Bearer secret-token",
            currentScope: { scope },
            isOnline: { true },
            transport: stub
        )

        XCTAssertEqual(report.succeededCount, 4)
        XCTAssertEqual(report.remainingQueuedCount, 0)
        XCTAssertEqual(stub.recordedRequests.count, 4)
        XCTAssertEqual(stub.recordedRequests[0].value(forHTTPHeaderField: "X-Request-Id"), item1.idempotencyKey)
        XCTAssertEqual(stub.recordedRequests[1].value(forHTTPHeaderField: "X-Request-Id"), item2.idempotencyKey)
        XCTAssertTrue(String(decoding: stub.recordedRequests[2].httpBody ?? Data(), as: UTF8.self).contains("idempotencyKey=stamp1234567"))
        XCTAssertEqual(stub.recordedRequests[3].value(forHTTPHeaderField: "X-Club-Admission-Request-Id"), item4.idempotencyKey)
    }

    func testPostDispatchTimeoutLocksItemWithoutSilentAutoReplay() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pkg63-unknown-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let scope = try OfflineWriteQueueScope(accountID: 7, realm: "cn-e2e-test", baseURL: "https://8120.test")
        let queue = try OfflineIdempotentWriteQueue(fileURL: url)
        var req = URLRequest(url: URL(string: "https://8120.test/api/club")!)
        req.httpMethod = "POST"
        req.httpBody = Data(#"{"name":"Test Club"}"#.utf8)
        _ = try queue.enqueueOfflineWrite(req, scope: scope, explicitKey: "clubcrt12345")

        let stub = StubRetryHTTPTransport([.failure(URLError(.timedOut))])
        let api = try APIConfiguration(baseURL: URL(string: "https://8120.test")!)
        let report = try await queue.flushPending(
            scope: scope,
            configuration: api,
            token: "Bearer tok-123",
            currentScope: { scope },
            isOnline: { true },
            transport: stub
        )
        XCTAssertEqual(report.succeededCount, 0)
        XCTAssertEqual(report.remainingQueuedCount, 0)
        XCTAssertEqual(report.lockedUnknownCount, 1)
    }

    // MARK: - Roam Sync Status Tracker (roam-sync-status.js parity)

    func testRoamSyncStatusRequiresTwoConsecutiveNetFailuresOrOfflinePath() {
        var tracker = RoamSyncStatusTracker(systemConnected: true)
        XCTAssertFalse(tracker.isOffline)

        // Single net failure does not show banner yet
        XCTAssertFalse(tracker.recordOutcome(netFail: true))
        // Business error does not increment transport failure threshold
        XCTAssertFalse(tracker.recordOutcome(netFail: false, code: 500))
        // Second net failure flips offline
        XCTAssertTrue(tracker.recordOutcome(netFail: true))
        // 200 clears banner
        XCTAssertFalse(tracker.recordOutcome(netFail: false, code: 200))

        // System connectivity drop sets offline immediately and clears on reconnect
        XCTAssertTrue(tracker.recordSystemConnectivity(isConnected: false))
        XCTAssertFalse(tracker.recordSystemConnectivity(isConnected: true))
    }

    // MARK: - Follow-up 63b Screen Opt-In, Form-Urlencoded & Registration Guard Tests

    func testPreSendUnreachableClassificationVsTimeouts() {
        XCTAssertTrue(OfflineIdempotentWriteQueue.isPreSendUnreachable(URLError(.notConnectedToInternet)))
        XCTAssertTrue(OfflineIdempotentWriteQueue.isPreSendUnreachable(URLError(.cannotFindHost)))
        XCTAssertTrue(OfflineIdempotentWriteQueue.isPreSendUnreachable(URLError(.cannotConnectToHost)))
        XCTAssertTrue(OfflineIdempotentWriteQueue.isPreSendUnreachable(URLError(.dnsLookupFailed)))
        XCTAssertTrue(OfflineIdempotentWriteQueue.isPreSendUnreachable(URLError(.dataNotAllowed)))
        XCTAssertTrue(OfflineIdempotentWriteQueue.isPreSendUnreachable(URLError(.internationalRoamingOff)))

        XCTAssertFalse(OfflineIdempotentWriteQueue.isPreSendUnreachable(URLError(.timedOut)))
        XCTAssertFalse(OfflineIdempotentWriteQueue.isPreSendUnreachable(URLError(.networkConnectionLost)))
        XCTAssertFalse(OfflineIdempotentWriteQueue.isPreSendUnreachable(CancellationError()))
    }

    func testFormEncodedJsonBodySpecRoutesResolveAndInjectKey() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pkg63b-form-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let scope = try OfflineWriteQueueScope(accountID: 51, realm: "cn-e2e-test", baseURL: "https://8120.test")
        let queue = try OfflineIdempotentWriteQueue(fileURL: dir.appendingPathComponent("queue.json"))

        var addrReq = URLRequest(url: URL(string: "https://8120.test/api/user/address/action")!)
        addrReq.httpMethod = "POST"
        addrReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        addrReq.httpBody = Data("action=create&realName=Alex".utf8)
        let addrItem = try queue.enqueueOfflineWrite(addrReq, scope: scope, explicitKey: "addrkey12345")

        var tplReq = URLRequest(url: URL(string: "https://8120.test/api/template/topic-template/use")!)
        tplReq.httpMethod = "POST"
        tplReq.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        tplReq.httpBody = Data("templateId=9".utf8)
        let tplItem = try queue.enqueueOfflineWrite(tplReq, scope: scope, explicitKey: "tplkey123456")

        let stub = StubRetryHTTPTransport([
            .response(Data(#"{"code":200}"#.utf8), 200),
            .response(Data(#"{"code":200}"#.utf8), 200)
        ])
        let api = try APIConfiguration(baseURL: URL(string: "https://8120.test")!)
        let report = try await queue.flushPending(
            scope: scope,
            configuration: api,
            token: "Bearer tok-form",
            currentScope: { scope },
            isOnline: { true },
            transport: stub
        )

        XCTAssertEqual(report.succeededCount, 2)
        XCTAssertEqual(Set(report.succeededPaths), ["/api/user/address/action", "/api/template/topic-template/use"])
        XCTAssertEqual(stub.recordedRequests.count, 2)
        let addrBody = String(decoding: stub.recordedRequests[0].httpBody ?? Data(), as: UTF8.self)
        let tplBody = String(decoding: stub.recordedRequests[1].httpBody ?? Data(), as: UTF8.self)
        XCTAssertTrue(addrBody.contains("requestId=\(addrItem.idempotencyKey)"))
        XCTAssertTrue(tplBody.contains("requestId=\(tplItem.idempotencyKey)"))
    }

    func testRegistrationCreateAllowsFreeAndExcludesPaidMoneyRequests() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pkg63b-reg-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let scope = try OfflineWriteQueueScope(accountID: 52, realm: "cn-e2e-test", baseURL: "https://8120.test")
        let queue = try OfflineIdempotentWriteQueue(fileURL: url)

        var paidByChannel = URLRequest(url: URL(string: "https://8120.test/api/registration/create")!)
        paidByChannel.httpMethod = "POST"
        paidByChannel.httpBody = Data(#"{"activityId":10,"payChannel":"APP","requestId":"regpaid0001"}"#.utf8)
        XCTAssertTrue(BackendIdempotentWriteRouteCatalog.isMoneyOrCashSensitiveRequest(paidByChannel))
        XCTAssertThrowsError(try queue.enqueueOfflineWrite(paidByChannel, scope: scope)) { err in
            XCTAssertEqual(err as? OfflineWriteQueueError, .moneyWriteNeverAutoReplayed)
        }

        var paidByAmount = URLRequest(url: URL(string: "https://8120.test/api/registration/create")!)
        paidByAmount.httpMethod = "POST"
        paidByAmount.httpBody = Data(#"{"activityId":10,"payableAmount":19.9,"requestId":"regpaid0002"}"#.utf8)
        XCTAssertTrue(BackendIdempotentWriteRouteCatalog.isMoneyOrCashSensitiveRequest(paidByAmount))
        XCTAssertThrowsError(try queue.enqueueOfflineWrite(paidByAmount, scope: scope)) { err in
            XCTAssertEqual(err as? OfflineWriteQueueError, .moneyWriteNeverAutoReplayed)
        }

        var freeReq = URLRequest(url: URL(string: "https://8120.test/api/registration/create")!)
        freeReq.httpMethod = "POST"
        freeReq.httpBody = Data(#"{"activityId":10,"payableAmount":0,"requestId":"regfree0001"}"#.utf8)
        XCTAssertFalse(BackendIdempotentWriteRouteCatalog.isMoneyOrCashSensitiveRequest(freeReq))
        let item = try queue.enqueueOfflineWrite(freeReq, scope: scope)
        XCTAssertEqual(item.path, "/api/registration/create")
        XCTAssertEqual(item.idempotencyKey, "regfree0001")
    }

    func testChinaReviewedProductionTransportCapturesPreSendUnreachableOnly() async throws {
        let stub = StubRetryHTTPTransport([
            .failure(URLError(.notConnectedToInternet)),
            .failure(URLError(.timedOut)),
            .failure(URLError(.notConnectedToInternet))
        ])
        let transport = ChinaReviewedProductionTransport(underlying: stub)

        final class CapturedList: @unchecked Sendable {
            private let lock = NSLock()
            var requests: [URLRequest] = []
            func append(_ req: URLRequest) {
                lock.lock()
                requests.append(req)
                lock.unlock()
            }
        }
        let captured = CapturedList()
        let box = OfflinePreSendCaptureBox { req, _ in
            captured.append(req)
        }

        try await OfflineWriteCaptureContext.$current.withValue(box) {
            var feedbackReq = URLRequest(url: URL(string: "https://8120.test/api/play/feedback/submit")!)
            feedbackReq.httpMethod = "POST"
            feedbackReq.httpBody = Data(#"{"runId":1,"content":"gate closed","requestId":"fbreq123456"}"#.utf8)
            do {
                _ = try await transport.send(feedbackReq)
                XCTFail("Expected offline error")
            } catch {}

            var timeoutReq = URLRequest(url: URL(string: "https://8120.test/api/play/feedback/submit")!)
            timeoutReq.httpMethod = "POST"
            timeoutReq.httpBody = Data(#"{"runId":1,"content":"timeout","requestId":"fbtmo123456"}"#.utf8)
            do {
                _ = try await transport.send(timeoutReq)
                XCTFail("Expected timeout error")
            } catch {}
        }

        // Outside opt-in context, pre-send offline error must not capture
        var unoptedReq = URLRequest(url: URL(string: "https://8120.test/api/play/feedback/submit")!)
        unoptedReq.httpMethod = "POST"
        do {
            _ = try await transport.send(unoptedReq)
            XCTFail("Expected offline error")
        } catch {}

        XCTAssertEqual(captured.requests.count, 1)
        XCTAssertEqual(captured.requests.first?.url?.path, "/api/play/feedback/submit")
    }

    // MARK: - ui/cur-offline-tests: existing queue behavior only

    func testUnreachableWriteIsQueuedOnlyWhenTheCaptureContextOptsIn() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cur-offline-optin-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let scope = try OfflineWriteQueueScope(accountID: 63, realm: "cn-e2e-test", baseURL: "https://8120.example.test")
        let queue = try OfflineIdempotentWriteQueue(fileURL: url)
        let captured = OfflineRequestCapture()
        let stub = StubRetryHTTPTransport([
            .failure(URLError(.notConnectedToInternet)),
            .failure(URLError(.notConnectedToInternet)),
            .failure(URLError(.notConnectedToInternet))
        ])
        let transport = OfflineWriteCaptureTransport(underlying: stub)
        let opted = try Self.fixtureRequest(
            path: "/api/play/feedback/submit",
            body: #"{"runId":1,"content":"offline","requestId":"optin0000001"}"#
        )

        do {
            _ = try await transport.send(opted)
            XCTFail("unreachable write must fail")
        } catch {
            XCTAssertTrue(OfflineIdempotentWriteQueue.isPreSendUnreachable(error))
        }
        XCTAssertTrue(captured.requests.isEmpty)
        XCTAssertTrue(queue.pendingItems(for: scope).isEmpty)

        let box = OfflinePreSendCaptureBox { request, _ in
            captured.append(request)
        }
        try await OfflineWriteCaptureContext.$current.withValue(box) {
            do {
                _ = try await transport.send(opted)
                XCTFail("opted-in unreachable write must fail")
            } catch {
                XCTAssertTrue(OfflineIdempotentWriteQueue.isPreSendUnreachable(error))
            }
            let plain = try Self.fixtureRequest(
                path: "/api/play/action",
                body: #"{"requestId":"nooptin00001"}"#
            )
            do {
                _ = try await transport.send(plain)
                XCTFail("non-catalog unreachable write must fail")
            } catch {
                XCTAssertTrue(OfflineIdempotentWriteQueue.isPreSendUnreachable(error))
            }
        }

        XCTAssertEqual(captured.requests.count, 2)
        let queued = try queue.enqueueOfflineWrite(captured.requests[0], scope: scope)
        XCTAssertEqual(queued.path, "/api/play/feedback/submit")
        XCTAssertEqual(queued.idempotencyKey, "optin0000001")
        XCTAssertThrowsError(try queue.enqueueOfflineWrite(captured.requests[1], scope: scope)) { error in
            XCTAssertEqual(error as? OfflineWriteQueueError, .routeNotIdempotent)
        }
        XCTAssertEqual(queue.queuedItems(for: scope).map(\.path), ["/api/play/feedback/submit"])
        for request in stub.recordedRequests {
            XCTAssertEqual(request.url?.host, "8120.example.test")
        }
    }

    func testFlushRetryReusesTheStoredIdempotencyKey() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cur-offline-retry-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let scope = try OfflineWriteQueueScope(accountID: 64, realm: "cn-e2e-test", baseURL: "https://8120.example.test")
        let queue = try OfflineIdempotentWriteQueue(fileURL: url)
        let request = try Self.fixtureRequest(
            path: "/api/capsules/create",
            body: #"{"text":"note","requestId":"capsulekey01"}"#
        )
        let item = try queue.enqueueOfflineWrite(request, scope: scope)
        XCTAssertEqual(item.idempotencyKey, "capsulekey01")

        let stub = StubRetryHTTPTransport([
            .failure(URLError(.notConnectedToInternet)),
            .response(Data(#"{"code":200}"#.utf8), 200)
        ])
        let api = try APIConfiguration(baseURL: try XCTUnwrap(URL(string: "https://8120.example.test")))
        let first = try await queue.flushPending(
            scope: scope,
            configuration: api,
            token: "Bearer tok-retry",
            currentScope: { scope },
            isOnline: { true },
            transport: stub
        )
        XCTAssertEqual(first.succeededCount, 0)
        XCTAssertEqual(first.remainingQueuedCount, 1)
        XCTAssertEqual(queue.queuedItems(for: scope).map(\.idempotencyKey), ["capsulekey01"])

        let second = try await queue.flushPending(
            scope: scope,
            configuration: api,
            token: "Bearer tok-retry",
            currentScope: { scope },
            isOnline: { true },
            transport: stub
        )
        XCTAssertEqual(second.succeededCount, 1)
        XCTAssertEqual(second.remainingQueuedCount, 0)
        XCTAssertEqual(stub.recordedRequests.count, 2)
        XCTAssertEqual(stub.recordedRequests[0].value(forHTTPHeaderField: "X-Request-Id"), "capsulekey01")
        XCTAssertEqual(stub.recordedRequests[1].value(forHTTPHeaderField: "X-Request-Id"), "capsulekey01")
        XCTAssertEqual(stub.recordedRequests[0].httpBody, stub.recordedRequests[1].httpBody)
        let body = String(decoding: stub.recordedRequests[0].httpBody ?? Data(), as: UTF8.self)
        XCTAssertTrue(body.contains("capsulekey01"))
        XCTAssertEqual(stub.recordedRequests[0].url?.host, "8120.example.test")
    }

    func testMoneyAndPayoutWritesAreNotQueuedAndProductionHostIsRefused() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cur-offline-money-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let scope = try OfflineWriteQueueScope(accountID: 65, realm: "cn-e2e-test", baseURL: "https://8120.example.test")
        let queue = try OfflineIdempotentWriteQueue(fileURL: url)
        let blocked = ["/api/pay/create", "/api/merchant/payout-account/save", "/api/withdrawal/create"]
        for path in blocked {
            let request = try Self.fixtureRequest(path: path, body: #"{"requestId":"moneykey0001"}"#)
            XCTAssertThrowsError(try queue.enqueueOfflineWrite(request, scope: scope), path) { error in
                XCTAssertEqual(error as? OfflineWriteQueueError, .moneyWriteNeverAutoReplayed)
            }
        }
        XCTAssertTrue(queue.pendingItems(for: scope).isEmpty)

        let productionBase = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        var production = URLRequest(url: productionBase.appendingPathComponent("api/pay/create"))
        production.httpMethod = "POST"
        production.httpBody = Data(#"{"requestId":"payprod00001"}"#.utf8)
        XCTAssertEqual(production.url?.host, "www.chengyinhub.com")
        let wire = StubRetryHTTPTransport([])
        let transport = ChinaReviewedProductionTransport(underlying: wire)
        do {
            _ = try await transport.send(production)
            XCTFail("www.chengyinhub.com must refuse /api/pay/create")
        } catch {
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
        XCTAssertEqual(wire.recordedRequests.count, 0)
        XCTAssertThrowsError(try queue.enqueueOfflineWrite(production, scope: scope)) { error in
            XCTAssertEqual(error as? OfflineWriteQueueError, .moneyWriteNeverAutoReplayed)
        }
        XCTAssertTrue(queue.pendingItems(for: scope).isEmpty)
    }

    func testRegistrationGuardQueuesFreeAndRefusesPaidAmounts() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cur-offline-reg-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let scope = try OfflineWriteQueueScope(accountID: 66, realm: "cn-e2e-test", baseURL: "https://8120.example.test")
        let queue = try OfflineIdempotentWriteQueue(fileURL: url)

        let paidAmount = try Self.fixtureRequest(
            path: "/api/registration/create",
            body: #"{"activityId":10,"payAmount":1,"requestId":"regpayamt01"}"#
        )
        let paidTotal = try Self.fixtureRequest(
            path: "/api/registration/create",
            body: #"{"activityId":10,"totalAmount":2,"requestId":"regtotal001"}"#
        )
        for request in [paidAmount, paidTotal] {
            XCTAssertTrue(BackendIdempotentWriteRouteCatalog.isMoneyOrCashSensitiveRequest(request))
            XCTAssertThrowsError(try queue.enqueueOfflineWrite(request, scope: scope)) { error in
                XCTAssertEqual(error as? OfflineWriteQueueError, .moneyWriteNeverAutoReplayed)
            }
        }

        let free = try Self.fixtureRequest(
            path: "/api/registration/create",
            body: #"{"activityId":10,"requestId":"regfreebody1"}"#
        )
        XCTAssertFalse(BackendIdempotentWriteRouteCatalog.isMoneyOrCashSensitiveRequest(free))
        let item = try queue.enqueueOfflineWrite(free, scope: scope)
        XCTAssertEqual(item.path, "/api/registration/create")
        XCTAssertEqual(item.idempotencyKey, "regfreebody1")
        XCTAssertEqual(queue.queuedItems(for: scope).map(\.path), ["/api/registration/create"])
    }

    func testQueuedWritesReplayInEnqueueOrder() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cur-offline-order-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let scope = try OfflineWriteQueueScope(accountID: 67, realm: "cn-e2e-test", baseURL: "https://8120.example.test")
        let queue = try OfflineIdempotentWriteQueue(fileURL: url)
        let paths = ["/api/play/feedback/submit", "/api/capsules/create", "/api/exploration-goals/create"]
        for (offset, path) in paths.enumerated() {
            let key = "orderkey000\(offset)"
            let request = try Self.fixtureRequest(path: path, body: #"{"requestId":"\#(key)"}"#)
            let item = try queue.enqueueOfflineWrite(request, scope: scope)
            XCTAssertEqual(item.path, path)
            XCTAssertEqual(item.idempotencyKey, key)
        }
        XCTAssertEqual(queue.queuedItems(for: scope).map(\.path), paths)

        let stub = StubRetryHTTPTransport([
            .response(Data(#"{"code":200}"#.utf8), 200),
            .response(Data(#"{"code":200}"#.utf8), 200),
            .response(Data(#"{"code":200}"#.utf8), 200)
        ])
        let api = try APIConfiguration(baseURL: try XCTUnwrap(URL(string: "https://8120.example.test")))
        let report = try await queue.flushPending(
            scope: scope,
            configuration: api,
            token: "Bearer tok-order",
            currentScope: { scope },
            isOnline: { true },
            transport: stub
        )
        XCTAssertEqual(report.succeededCount, 3)
        XCTAssertEqual(report.succeededPaths, paths)
        XCTAssertEqual(report.remainingQueuedCount, 0)
        let replayed = stub.recordedRequests.map { ChinaReviewedRouteCapability.normalized($0.url?.path ?? "") }
        XCTAssertEqual(replayed, paths)
        XCTAssertEqual(stub.recordedRequests.map { $0.value(forHTTPHeaderField: "X-Request-Id") }, ["orderkey0000", "orderkey0001", "orderkey0002"])
        for request in stub.recordedRequests {
            XCTAssertEqual(request.url?.host, "8120.example.test")
        }
    }

    private static func fixtureRequest(path: String, body: String) throws -> URLRequest {
        let url = try XCTUnwrap(URL(string: "https://8120.example.test\(path)"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        return request
    }
}

private final class OfflineRequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URLRequest] = []

    func append(_ request: URLRequest) {
        lock.lock()
        stored.append(request)
        lock.unlock()
    }

    var requests: [URLRequest] {
        lock.lock()
        let copy = stored
        lock.unlock()
        return copy
    }
}
