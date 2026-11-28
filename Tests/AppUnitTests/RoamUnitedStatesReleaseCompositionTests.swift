import XCTest
@testable import Questify

/// Function audit P1-25 (mp-roam): "The US market has no live roam, roam writes or nearby teams."
/// Since US launch r1 the shipped US build composes the shared reviewed backend (backend market CN, storefront US),
/// so the runtime context and the roam identity both carry market CN and the China-only leases are issued.
/// These tests build the shipped Release composition for a US build and prove the leases are ON.
@MainActor final class RoamUnitedStatesReleaseCompositionTests: XCTestCase {
    private final class Vault: AppTokenStorage {
        var value: String?
        func read() throws -> String? { value }
        func write(_ token: String) throws { value = token }
        func clear() throws { value = nil }
    }

    private func shippedUnitedStates() throws -> AppCompositionRoot {
        let suite = "roam-us-release-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let vault = Vault()
        let build = RegionalLaunchConfiguration.BuildMetadata(market: "US", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: "invalid.example.questify.ios", realm: "us-prod")
        return RegionalLaunchConfiguration.shippedComposition(build: build,
            storage: .init(defaults: defaults, tokenStore: { _ in vault }))
    }

    private func context(_ root: AppCompositionRoot, role: String = "player") throws -> RuntimeDependencyContext {
        let reviewed = try XCTUnwrap(root.reviewed)
        let api = try XCTUnwrap(reviewed.regional.apiConfiguration)
        return RuntimeDependencyContext(market: reviewed.regional.market, baseURL: api.baseURL, role: role,
            session: try PlayExperienceSession(accountID: 7, epoch: 1, namespace: reviewed.storageScope.service,
                token: "synthetic-us-7", role: role))
    }

    func testShippedUnitedStatesBuildIssuesTheLiveRoamApprovalForTheRoamIdentity() throws {
        let root = try shippedUnitedStates()
        let reviewed = try XCTUnwrap(root.reviewed)
        XCTAssertTrue(reviewed.productionGatesEnabled)
        let api = try XCTUnwrap(reviewed.regional.apiConfiguration)
        let viewer = try context(root)
        let approval = try XCTUnwrap(root.roamLiveApproval(viewer), "US players must get live roam (P1-25)")
        XCTAssertTrue(RoamLiveApproval.requiredPaths.isSubset(of: approval.endpoints.paths))
        XCTAssertTrue(approval.endpoints.paths.contains("api/roam/presence"))
        // AppSession builds the roam identity from `regional.market.rawValue`, the same value as the context.
        let scope = try RoamHistoryScope(market: reviewed.regional.market.rawValue, deployment: api.baseURL,
            accountID: 7, namespace: reviewed.storageScope.service)
        let identity = try RoamExperienceSession(scope: scope, epoch: 1, token: "synthetic-us-7").identity
        XCTAssertTrue(approval.allows(identity, api: api))
    }

    func testShippedUnitedStatesBuildIssuesLiveRoamWritesAndNearbyTeams() throws {
        let root = try shippedUnitedStates()
        let viewer = try context(root)
        XCTAssertNotNil(root.roamLiveWriteApproval(viewer), "roam writes (visit / discover) for US players")
        for role in ["player", "club", "merchant"] {
            let teamViewer = try context(root, role: role)
            XCTAssertNotNil(root.nearbyTeamReadApproval(teamViewer), role)
            let write = try XCTUnwrap(root.nearbyTeamWriteApproval(teamViewer), role)
            XCTAssertEqual(write.paths, ["api/team/apply", "api/team/withdraw", "api/team/handle"], role)
        }
        XCTAssertNil(root.nearbyTeamReadApproval(try context(root, role: "guest")))
    }
}
