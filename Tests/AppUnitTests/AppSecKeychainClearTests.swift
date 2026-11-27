import Foundation
import XCTest
@testable import Questify

/// Logout and account-deletion expiry clear the injected token store. Production money stays on
/// `ReviewedAreaSwitch`. The wire is `example.test` only.
@MainActor final class AppSecKeychainClearTests: XCTestCase {
    private struct Harness {
        let session: AppSession
        let vault: Vault
        let wire: Wire
        let defaults: UserDefaults
        let restoreBlockedKey: String
    }

    private func harness() async throws -> Harness {
        let suite = "appsec-keychain-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let endpoint = "https://example.test/appsec-keychain"
        let deployment = try ReviewedAppDeployment(
            market: .china,
            baseURL: endpoint,
            approvedBaseURLs: [.china: [endpoint]],
            verifiedCapabilities: [.domesticChinaPhone],
            bundleIdentifier: "test.appsec.keychain",
            realm: "synthetic"
        )
        let vault = Vault()
        let wire = Wire()
        let root = AppCompositionRoot(
            deployment: .reviewed(deployment),
            storage: .init(defaults: defaults, tokenStore: { _ in vault }),
            makeTransport: { wire }
        )
        let session = root.makeSession()
        await session.bootstrap()
        XCTAssertEqual(session.account?.id, 7)
        XCTAssertEqual(session.token, "synthetic-7")
        return Harness(
            session: session,
            vault: vault,
            wire: wire,
            defaults: defaults,
            restoreBlockedKey: deployment.storageScope.restoreBlockedKey
        )
    }

    func testLogoutClearsTheTokenStore() async throws {
        let h = try await harness()
        await h.session.logout()
        XCTAssertEqual(h.vault.clears, 1)
        XCTAssertNil(h.vault.value)
        XCTAssertNil(h.session.token)
        XCTAssertNil(h.session.account)
        XCTAssertTrue(h.defaults.bool(forKey: h.restoreBlockedKey))
        // Stale since the test landed (7623036a3): `APIConfiguration.url(for:)` appends `api/logout` to the
        // reviewed base URL, so the base path `/appsec-keychain` stays in front (same as the Wire's hasSuffix routing).
        XCTAssertTrue(h.wire.requests.contains { $0.url?.path == "/appsec-keychain/api/logout" })
        XCTAssertTrue(h.wire.requests.allSatisfy { $0.url?.host == "example.test" })
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: ReviewedAreaSwitch.productionAPIHost))
        XCTAssertFalse(ReviewedAreaSwitch.passwordLogin(apiHost: ReviewedAreaSwitch.productionAPIHost))
    }

    func testAccountDeletionExpiryClearsTheTokenStore() async throws {
        let h = try await harness()
        let before = h.wire.requests.count
        h.session.expireIfMatching(
            error: APIError.unauthorized,
            stamp: h.session.gate.currentStamp,
            credential: h.session.token
        )
        XCTAssertEqual(h.vault.clears, 1)
        XCTAssertNil(h.vault.value)
        XCTAssertNil(h.session.token)
        XCTAssertNil(h.session.account)
        XCTAssertEqual(h.session.errorKey, "auth.expired")
        XCTAssertEqual(h.wire.requests.count, before, "deletion expiry clears locally and does not open another request")
        XCTAssertTrue(h.wire.requests.allSatisfy { $0.url?.host == "example.test" })
    }

    func testStaleOrNonUnauthorizedExpiryDoesNotClearTheTokenStore() async throws {
        let h = try await harness()
        let stamp = h.session.gate.currentStamp
        h.session.expireIfMatching(error: APIError.unauthorized, stamp: stamp &- 1, credential: h.session.token)
        h.session.expireIfMatching(error: APIError.notConfigured, stamp: stamp, credential: h.session.token)
        h.session.expireIfMatching(error: APIError.unauthorized, stamp: stamp, credential: "other-token")
        XCTAssertEqual(h.vault.clears, 0)
        XCTAssertEqual(h.vault.value, "synthetic-7")
        XCTAssertEqual(h.session.account?.id, 7)
    }

    func testUnconfiguredKeychainClearIsANoOp() throws {
        let store = KeychainTokenStore(scope: nil)
        try store.clear()
        XCTAssertNil(try store.read())
    }

#if targetEnvironment(simulator)
    func testKeychainStoreClearRemovesTheSessionToken() throws {
        try SystemKeychainAvailability.skipIfEntitlementMissing()
        let endpoint = "https://example.test/appsec-keychain-" + UUID().uuidString
        let configuration = try RegionalConfiguration(
            market: .china,
            baseURL: endpoint,
            approvedBaseURLs: [.china: [endpoint]]
        )
        let scope = try RegionalSessionStorageScope(
            configuration: configuration,
            bundleIdentifier: "test.appsec.keychain",
            realm: "synthetic"
        )
        let store = KeychainTokenStore(scope: scope)
        try store.clear()
        try store.write("synthetic-token")
        XCTAssertEqual(try store.read(), "synthetic-token")
        try store.clear()
        XCTAssertNil(try store.read())
        try store.clear()
    }
#endif
}

private final class Vault: AppTokenStorage {
    var value: String? = "synthetic-7"
    var clears = 0
    func read() throws -> String? { value }
    func write(_ token: String) throws { value = token }
    func clear() throws { value = nil; clears += 1 }
}

private final class Wire: HTTPTransport {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        guard let path = request.url?.path else { throw APIError.invalidRequest }
        if path.hasSuffix("/api/userInfo") {
            return (Data("{\"code\":200,\"appUser\":{\"id\":7,\"role\":\"player\"}}".utf8), 200)
        }
        guard path.hasSuffix("/api/logout") else {
            XCTFail("Unexpected route: \(path)")
            throw APIError.invalidRequest
        }
        return (Data("{\"code\":200}".utf8), 200)
    }
}
