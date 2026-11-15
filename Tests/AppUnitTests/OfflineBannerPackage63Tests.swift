import XCTest
import SwiftUI
@testable import Questify
#if canImport(QuestifyCore)
@testable import QuestifyCore
#endif

@MainActor
final class OfflineBannerPackage63Tests: XCTestCase {

    func testNetworkReachabilityDeduplicatesUpdatesAndSyncsSharedState() {
        let reachability = NetworkReachability()
        SharedNetworkReachabilityState.shared.setOnline(true)

        XCTAssertFalse(reachability.isOffline)
        reachability.applyConnectivity(online: false)
        XCTAssertTrue(reachability.isOffline)
        XCTAssertFalse(SharedNetworkReachabilityState.shared.isOnline)

        // Recheck without live NWPathMonitor flags stillOfflineAfterRecheck honestly
        XCTAssertFalse(reachability.recheck())
        XCTAssertTrue(reachability.stillOfflineAfterRecheck)

        reachability.applyConnectivity(online: true)
        XCTAssertFalse(reachability.isOffline)
        XCTAssertTrue(SharedNetworkReachabilityState.shared.isOnline)
        XCTAssertFalse(reachability.stillOfflineAfterRecheck)
        XCTAssertNotNil(reachability.lastConnectedAt)
    }

    func testCYStatusOfflineBannerCapturesSeriousAndCachedOptions() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let banner = CYStatusOfflineBanner(
            messageKey: "cy.state.offline.banner.title",
            detailKey: "cy.state.offline.queue.moneyNoAutoReplay",
            cachedAt: now,
            stillOffline: true,
            serious: true,
            actionTitleKey: "cy.state.offline.banner.retry",
            onRetry: {}
        )
        XCTAssertEqual(banner.messageKey, "cy.state.offline.banner.title")
        XCTAssertEqual(banner.detailKey, "cy.state.offline.queue.moneyNoAutoReplay")
        XCTAssertEqual(banner.cachedAt, now)
        XCTAssertTrue(banner.stillOffline)
        XCTAssertTrue(banner.serious)
    }

    func testCYOfflineWriteStatusBannerCarriesStatusAndOnlineFlag() {
        let banner = CYOfflineWriteStatusBanner(
            status: .queued(count: 1),
            isOnline: false,
            accessibilityID: "cy.offlineWrite.status"
        )
        XCTAssertEqual(banner.status, .queued(count: 1))
        XCTAssertFalse(banner.isOnline)
        XCTAssertEqual(banner.accessibilityID, "cy.offlineWrite.status")
    }

    func testSessionOfflineSyncModelTracksQueuedSyncedAndExcludedMoneyStatus() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pkg63b-app-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        final class TokenVault: AppTokenStorage {
            var value: String?
            func read() throws -> String? { value }
            func write(_ token: String) throws { value = token }
            func clear() throws { value = nil }
        }
        @MainActor final class StubTransport: HTTPTransport {
            var failFeedbackOffline = false
            var replayedFeedbackPaths: [String] = []
            func send(_ request: URLRequest) async throws -> (Data, Int) {
                let path = request.url?.path ?? ""
                if path.hasSuffix("/api/login/phone") {
                    return (Data(#"{"code":200,"token":"tok-63b","data":{"id":77,"role":"player"}}"#.utf8), 200)
                }
                if path.hasSuffix("/api/userInfo") {
                    return (Data(#"{"code":200,"appUser":{"id":77,"role":"player"}}"#.utf8), 200)
                }
                if path == "/api/play/feedback/submit" {
                    if failFeedbackOffline {
                        throw URLError(.notConnectedToInternet)
                    }
                    replayedFeedbackPaths.append(path)
                    return (Data(#"{"code":200,"data":{"ok":true}}"#.utf8), 200)
                }
                return (Data(#"{"code":200}"#.utf8), 200)
            }
        }

        let suite = "pkg63b-app-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }

        let deployment = try ReviewedAppDeployment(
            market: .china,
            baseURL: "https://8120.test",
            approvedBaseURLs: [.china: ["https://8120.test"]],
            verifiedCapabilities: [.domesticChinaPhone],
            bundleIdentifier: "test.questify.pkg63b",
            realm: "pkg63b-test",
            productionGatesEnabled: true,
            playerWritesEnabled: true
        )
        let stub = StubTransport()
        let root = AppCompositionRoot(
            deployment: .reviewed(deployment),
            storage: .init(defaults: defaults, tokenStore: { _ in TokenVault() }),
            makeTransport: { stub }
        )
        let session = root.makeSession()
        await session.authChannels.loginWithPhone(phone: "10000000000", code: "123456")
        XCTAssertNotNil(session.account)
        let token = try XCTUnwrap(session.token)

        let model = SessionOfflineSyncModel(directory: dir)
        model.bind(session: session)

        // 1. Offline failure during performWriteOptIn enqueues non-money write through real composition transport
        stub.failFeedbackOffline = true
        await model.performWriteOptIn(session: session, routes: ["/api/play/feedback/submit"]) {
            var req = URLRequest(url: URL(string: "https://8120.test/api/play/feedback/submit")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(token, forHTTPHeaderField: "Authorization")
            req.httpBody = Data(#"{"runId":12,"content":"gate offline","requestId":"fb63b000001"}"#.utf8)
            _ = try? await session.runtimeHTTPTransport.send(req)
        }
        XCTAssertEqual(model.queuedCount, 1)
        XCTAssertEqual(model.status(for: ["/api/play/feedback/submit"], isOnline: false), .queued(count: 1))

        // 2. Reconnect replays queued write through real composition transport and marks screen .synced
        stub.failFeedbackOffline = false
        await model.flushIfOnline(session: session, isOnline: { true })
        XCTAssertEqual(stub.replayedFeedbackPaths, ["/api/play/feedback/submit"])
        XCTAssertEqual(model.queuedCount, 0)
        XCTAssertEqual(model.status(for: ["/api/play/feedback/submit"], isOnline: true), .synced)

        // 3. Money write is strictly excluded and surfaces .moneyExcluded without enqueueing
        var moneyReq = URLRequest(url: URL(string: "https://8120.test/api/pay/create")!)
        moneyReq.httpMethod = "POST"
        moneyReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        moneyReq.setValue(token, forHTTPHeaderField: "Authorization")
        moneyReq.httpBody = Data(#"{"requestId":"pay123456789"}"#.utf8)
        await model.performWriteOptIn(session: session, routes: ["/api/pay/create"]) {
            _ = try? await session.runtimeHTTPTransport.send(moneyReq)
        }
        XCTAssertEqual(model.queuedCount, 0)
        XCTAssertFalse(model.enqueueNonMoneyIdempotentWrite(moneyReq, session: session))
        XCTAssertTrue(model.blockedMoneyWarningVisible)
        XCTAssertEqual(model.status(for: ["/api/pay/create"], isOnline: false), .moneyExcluded)
        model.dismissSynced(for: ["/api/pay/create", "/api/play/feedback/submit"])
        XCTAssertEqual(model.status(for: ["/api/pay/create"], isOnline: false), .none)
    }

    func testPerformWriteOptInQueuesOnlyTheNamedRoute() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cur-offline-optin-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        final class TokenVault: AppTokenStorage {
            var value: String?
            func read() throws -> String? { value }
            func write(_ token: String) throws { value = token }
            func clear() throws { value = nil }
        }
        final class StubTransport: HTTPTransport, @unchecked Sendable {
            private let lock = NSLock()
            private var storedHosts: [String] = []
            func send(_ request: URLRequest) async throws -> (Data, Int) {
                let host = request.url?.host ?? ""
                lock.lock()
                storedHosts.append(host)
                lock.unlock()
                let path = request.url?.path ?? ""
                if path.hasSuffix("/api/login/phone") {
                    return (Data(#"{"code":200,"token":"tok-63b","data":{"id":77,"role":"player"}}"#.utf8), 200)
                }
                if path.hasSuffix("/api/userInfo") {
                    return (Data(#"{"code":200,"appUser":{"id":77,"role":"player"}}"#.utf8), 200)
                }
                throw URLError(.notConnectedToInternet)
            }
            var hosts: [String] {
                lock.lock()
                let copy = storedHosts
                lock.unlock()
                return copy
            }
        }

        let suite = "cur-offline-optin-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }

        let deployment = try ReviewedAppDeployment(
            market: .china,
            baseURL: "https://8120.example.test",
            approvedBaseURLs: [.china: ["https://8120.example.test"]],
            verifiedCapabilities: [.domesticChinaPhone],
            bundleIdentifier: "test.questify.curoffline",
            realm: "cur-offline-test",
            productionGatesEnabled: true,
            playerWritesEnabled: true
        )
        let stub = StubTransport()
        let root = AppCompositionRoot(
            deployment: .reviewed(deployment),
            storage: .init(defaults: defaults, tokenStore: { _ in TokenVault() }),
            makeTransport: { ChinaReviewedProductionTransport(underlying: stub) }
        )
        let session = root.makeSession()
        await session.authChannels.loginWithPhone(phone: "10000000000", code: "123456")
        XCTAssertNotNil(session.account)
        // The composition gate admits a player write only for the signed-in viewer under the player-write grant.
        let token = try XCTUnwrap(session.token)

        let model = SessionOfflineSyncModel(directory: dir)
        model.bind(session: session)

        let feedback = try Self.writeRequest(path: "/api/play/feedback/submit", body: #"{"runId":12,"content":"gate offline","requestId":"fb63b000001"}"#, token: token)
        _ = try? await session.runtimeHTTPTransport.send(feedback)
        XCTAssertEqual(model.queuedCount, 0)
        XCTAssertEqual(model.status(for: ["/api/play/feedback/submit"], isOnline: false), .none)

        let other = try Self.writeRequest(path: "/api/capsules/create", body: #"{"text":"skip","requestId":"capskip00001"}"#, token: token)
        let payment = try Self.writeRequest(path: "/api/pay/create", body: #"{"requestId":"payblocked01"}"#, token: token)
        await model.performWriteOptIn(session: session, routes: ["/api/play/feedback/submit"]) {
            _ = try? await session.runtimeHTTPTransport.send(feedback)
            _ = try? await session.runtimeHTTPTransport.send(other)
            _ = try? await session.runtimeHTTPTransport.send(payment)
        }

        XCTAssertEqual(model.queuedCount, 1)
        XCTAssertEqual(model.status(for: ["/api/play/feedback/submit"], isOnline: false), .queued(count: 1))
        XCTAssertEqual(model.status(for: ["/api/capsules/create"], isOnline: false), .none)
        // The release money switch refuses the payment at the composition gate, so it is never sent and there is
        // nothing to capture. The excluded-money status of a captured money write is asserted in
        // testSessionOfflineSyncModelTracksQueuedSyncedAndExcludedMoneyStatus.
        XCTAssertEqual(model.status(for: ["/api/pay/create"], isOnline: false), .none)
        XCTAssertFalse(stub.hosts.contains("www.chengyinhub.com"))
        XCTAssertTrue(stub.hosts.allSatisfy { $0 == "8120.example.test" })
    }

    private static func writeRequest(path: String, body: String, token: String) throws -> URLRequest {
        let url = try XCTUnwrap(URL(string: "https://8120.example.test\(path)"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.httpBody = Data(body.utf8)
        return request
    }
}
