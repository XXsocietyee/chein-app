import XCTest
import SwiftUI
import SceneKit
@testable import Questify

@MainActor final class ClubBadgeHostDefaultTests: XCTestCase {
    func testEnvironmentDefaultHasNoBadgeEntryOrFactory() {
        let environment = EnvironmentValues()
        XCTAssertNil(environment.clubBadgeHostFactory(7))
        XCTAssertNil(environment.objectCardMedia)
    }
    func testUnconfiguredCompositionDoesNotConstructService() throws {
        let c = RuntimeDependencyContext(market: .china, baseURL: URL(string: "https://badge.example")!, role: "player",
            session: try .init(accountID: 7, epoch: 1, namespace: "synthetic", token: "synthetic"))
        let endpoints = try OperationEndpointApproval(baseURL: c.baseURL, namespace: c.session.namespace,
            accountID: 7, paths: ClubBadgeManagementRoute.paths)
        let approval = try ClubBadgeManagementApproval(endpoints: endpoints, clubIDs: [7], reviewedPolicyVersion: "synthetic", reads: true)
        let root = AppCompositionRoot()
        XCTAssertNil(root.clubBadgeManagementApproval(c))
        XCTAssertNil(root.makeClubBadgeService(context: c, clubID: 7, approval: approval, current: { c }, unauthorized: {}))
    }

    /// CLB-r10-badges-01: the MP-first approval covers every club, reads and writes, China only.
    func testMPFirstBadgeApprovalInChina() throws {
        let c = RuntimeDependencyContext(market: .china, baseURL: URL(string: "https://badge.example")!, role: "player",
            session: try .init(accountID: 7, epoch: 1, namespace: "synthetic", token: "synthetic"))
        let approval = try XCTUnwrap(MPFirstClubApprovals.badges(c))
        XCTAssertTrue(approval.permits(c, clubID: 7, writing: false))
        XCTAssertTrue(approval.permits(c, clubID: 42, writing: true))
        XCTAssertEqual(MPFirstClubApprovals.badges(c)?.revision, approval.revision)
        let global = RuntimeDependencyContext(market: .unitedStates, baseURL: c.baseURL, role: "player", session: c.session)
        XCTAssertNil(MPFirstClubApprovals.badges(global))
    }

    func testBadgeShowroomSceneFactoryBuildsMedallionAndRejectsMalformedAssets() {
        XCTAssertTrue(ObjectBadgeShowroomSceneFactory.isModelAssetURL("https://cdn.example.com/badges/shanghai.glb"))
        XCTAssertFalse(ObjectBadgeShowroomSceneFactory.isModelAssetURL("http://cdn.example.com/badges/shanghai.glb"))
        XCTAssertFalse(ObjectBadgeShowroomSceneFactory.isModelAssetURL("https://cdn.example.com/badges/shanghai.png"))

        let scene = ObjectBadgeShowroomSceneFactory.makeMedallionScene(artwork: nil, title: "Shanghai", style: "enamel", rarity: 3)
        XCTAssertNotNil(scene)
        XCTAssertNotNil(scene?.rootNode.childNode(withName: "badgeTurntable", recursively: false))
        XCTAssertNotNil(scene?.rootNode.childNode(withName: "showroomCamera", recursively: false))
        XCTAssertNotNil(scene?.rootNode.childNode(withName: "badgeMedallion", recursively: true))

        XCTAssertNil(ObjectBadgeShowroomSceneFactory.decodeArtwork(Data("not-an-image".utf8)))
        XCTAssertNil(ObjectBadgeShowroomSceneFactory.prepareLoadedScene(SCNScene()))
    }
}
