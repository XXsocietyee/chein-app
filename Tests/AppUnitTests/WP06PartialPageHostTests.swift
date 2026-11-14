import XCTest
import SwiftUI
import UIKit
@testable import Questify

/// Opens the twelve WP-06 screens. Network stays on the injected doubles.
@MainActor final class WP06PartialPageHostTests: XCTestCase {
    func testOpensEveryPartialPageScreen() async throws {
        let profile = WP06ProfileStub()
        let roam = try WP06RoamStub()
        let coop = try WP06CoopStub()
        let invoice = try WP06InvoiceHost.presentation()
        let coupon = try WP06CouponHost.view()
        open(ProfileParticipantsView(reader: profile))
        open(QuickPublishingView(placeSearch: nil, account: nil, openProfessional: { _ in }))
        WP06ComplaintWrite.install()
        XCTAssertNotNil(ProfileComplaintPreparationLink.submitterFactory)
        open(ProfileComplaintPreparationView(reader: coop, isCurrent: { true }))
        open(coupon)
        open(InvoiceLaunchApplyView(model: invoice))
        open(RoamStampAlbumView(reader: roam))
        open(RoamStampCameraView())
        open(RoamCityStampFlowView(kind: nil, place: nil))
        open(RoamHistoryView(reader: roam))
        open(RoamAnniversaryView(reader: nil))
        open(RoamMonthlyRecapView(reader: nil))
        open(RoamExplorationExportView(tools: nil))
        let records = try WP06RoamHistoryClient.records(roam)
        XCTAssertTrue(records.isEmpty)
        let token = try XCTUnwrap(RoamShareToken(String(repeating: "ab", count: 16)))
        let outcome = await WP06RoamHistoryClient.shareSnapshot(WP06ShareStub(), token: token)
        XCTAssertEqual(outcome, .unavailable)
    }

    private func open<V: View>(_ view: V) {
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()
        XCTAssertNotNil(host.view)
    }
}

@MainActor private final class WP06ProfileStub: ProfileReading {
    var isConfigured: Bool { true }
    var identity: ProfileReadIdentity? { ProfileReadIdentity(accountID: 7, epoch: 1) }
    func profileOrders() async throws -> [ProfileOrder] { [] }
    func profileOrder(id: Int) async throws -> ProfileOrder { throw APIError.notConfigured }
    func profileParticipants() async throws -> [ProfileParticipant] { [] }
    func profileParticipant(id: Int) async throws -> ProfileParticipant { throw APIError.notConfigured }
    func profileBadges() async throws -> ProfileBadgeWall { throw APIError.notConfigured }
}

@MainActor private final class WP06RoamStub: RoamExperienceReading {
    let identity: RoamExperienceIdentity?
    var isConfigured: Bool { true }
    var isOfflineExample: Bool { false }
    init() throws {
        let scope = try RoamHistoryScope(market: "cn", deployment: URL(string: "https://example.test/native")!, accountID: 7)
        identity = RoamExperienceIdentity(scope: scope, epoch: 1)
    }
    func history() throws -> [RoamHistoryRecord] { [] }
    func sessionFact(_ query: RoamRecoveryQuery) async throws -> RoamSessionFact { throw APIError.notConfigured }
    func album(page: Int, pageSize: Int) async throws -> RoamAlbumPage { throw APIError.notConfigured }
    func tilePage(afterID: Int, limit: Int) async throws -> RoamTileMemoryPage { throw APIError.notConfigured }
    func shopBadge() async throws -> RoamShopBadge? { throw APIError.notConfigured }
}

@MainActor private final class WP06CoopStub: CoopFlowReading {
    let session: CoopFlowSession?
    init() throws { session = try CoopFlowSession(accountID: 7, epoch: 1, token: "synthetic-complaint-token") }
    func read(_ resource: CoopFlowRead) async throws -> CoopFlowJSON { .array([]) }
    func settlement(source: CoopFlowSettlement.Source, id: Int) async throws -> CoopFlowSettlement { throw APIError.notConfigured }
}

@MainActor private final class WP06ShareStub: RoamShareSnapshotReading {
    func snapshot(_ token: RoamShareToken) async -> RoamShareSnapshotOutcome { .unavailable }
}

private final class WP06HTTP: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) { throw URLError(.cancelled) }
}

@MainActor private final class WP06InvoiceMemory: InvoiceLaunchStorage {
    func read(_ key: String) throws -> Data? { nil }
    func write(_ data: Data, key: String) throws {}
    func remove(_ key: String) throws {}
}

@MainActor private enum WP06InvoiceHost {
    static func presentation() throws -> InvoiceLaunchPresentation {
        let session = try InvoiceLaunchSession(baseURL: URL(string: "https://example.test/native")!, namespace: "synthetic",
                                                accountID: 7, role: "player", epoch: 1, token: "synthetic-invoice-token")
        let service = InvoiceLaunchService(session: session, transport: WP06HTTP(), enabled: { true }, current: { session })
        let coordinator = try InvoiceLaunchCoordinator(service: service, store: InvoiceLaunchPendingStore(session: session, storage: WP06InvoiceMemory()))
        return InvoiceLaunchPresentation(coordinator: coordinator, isCurrent: { true })
    }
}

@MainActor private enum WP06CouponHost {
    static func view() throws -> CouponManagementView {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("wp06-coupon-\(UUID().uuidString)", isDirectory: true)
        let locks = try CouponManagementFileLocks(directory: directory)
        let session = try CouponManagementSession(accountID: 7, namespace: "synthetic", epoch: 1, authorizationRevision: "rev")
        let coordinator = CouponManagementCoordinator(adapter: CouponManagementAdapter(), authorizer: CouponPublisherUnavailable(),
                                                       locks: locks, currentSession: { session })
        return CouponManagementView(coordinator: coordinator, sessionKey: session, isSourceVisible: true)
    }
}
