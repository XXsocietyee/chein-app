import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Questify

/// K40 roam: the official-task list and the finished-session archive build the reviewed deployment
/// and admit the exact participation and session-record paths.
@MainActor final class K40RoamOfficialTasksCompositionTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"

    func testReviewedDeploymentAdmitsOfficialTaskActionsAndSessionRecords() throws {
        let build = RegionalLaunchConfiguration.BuildMetadata(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle, realm: realm)
        let deployment = try RegionalLaunchConfiguration.reviewedDeployment(build: build)
        XCTAssertTrue(deployment.productionGatesEnabled)
        XCTAssertTrue(deployment.playerWritesEnabled)
        let composition = RegionalLaunchConfiguration.reviewedComposition(build: build, makeTransport: { K40RoamQuiet() })
        let player = try playerContext(composition)
        let approval = try XCTUnwrap(composition.sessionDependencies(player).officialActionApproval)
        XCTAssertTrue(approval.playerTargets)
        for path in ["api/official/events/{}/signup", "api/official/events/{}/complete", "api/official/events/{}/arrivals"] {
            XCTAssertTrue(approval.endpoints.paths.contains(path), path)
        }
        XCTAssertNil(composition.sessionDependencies(try playerContext(composition, role: "merchant")).officialActionApproval)
        let grant = try XCTUnwrap(composition.playerWriteGrant(player))
        XCTAssertTrue(grant.roamExtras.paths.contains(RoamPlayerExtrasService.sessionRecordsPath))
        XCTAssertNil(composition.playerWriteGrant(try playerContext(composition, role: "merchant")))
        let us = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "US", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { K40RoamQuiet() })
        XCTAssertEqual(us.reviewed?.regional.market, .china)
        XCTAssertNotNil(us.roamLiveApproval(try playerContext(us)))
        let launch = try source("Core/PlayerLaunch.swift")
        XCTAssertTrue(launch.contains("#else\n    public static let merchantCenterEnabled = false\n    #endif"))
    }

    func testOfficialTaskDetailPassesTheSameCoordinator() {
        let coordinator = OfficialActionCoordinator(access: K40OfficialAccess(), locks: K40OfficialLocks())
        let reader = OfficialFixtureReader()
        let detail = RoamOfficialTaskDetail.make(eventID: 8, reader: reader, actions: coordinator)
        XCTAssertTrue(detail.actions === coordinator)
        XCTAssertNil(RoamOfficialTaskDetail.make(eventID: 8, reader: reader).actions)
    }

    private func playerContext(_ composition: AppCompositionRoot, role: String = "player") throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: "player-token", role: role)
        return RuntimeDependencyContext(market: .china, baseURL: base, role: role, session: session)
    }

    private func source(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: "\(#filePath)")
        url.deleteLastPathComponent(); url.deleteLastPathComponent(); url.deleteLastPathComponent()
        return try String(contentsOf: url.appendingPathComponent(relative), encoding: .utf8)
    }
}

@MainActor private final class K40OfficialAccess: OfficialActionAccess {
    var identity: OfficialActionIdentity? { nil }
    var enabled: Bool { true }
    func snapshot(for command: OfficialActionCommand) async throws -> OfficialActionSnapshot { throw APIError.notConfigured }
    func send(_ command: OfficialActionCommand) async throws -> OfficialActionReceipt { throw APIError.notConfigured }
}

@MainActor private final class K40OfficialLocks: OfficialActionLockStore {
    func contains(_ key: String) throws -> Bool { false }
    func insert(_ key: String) throws {}
    func remove(_ key: String) throws {}
}

private final class K40RoamQuiet: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        (Data(#"{"code":200,"data":{}}"#.utf8), 200)
    }
}
