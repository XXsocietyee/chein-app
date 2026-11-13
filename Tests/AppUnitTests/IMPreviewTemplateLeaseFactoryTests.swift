import Foundation
import XCTest
@testable import Questify

@MainActor final class IMPreviewTemplateLeaseFactoryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_763_000_000)

    private func context(role: String = "player", market: RegionalMarket = .china) throws -> RuntimeDependencyContext {
        let base = try XCTUnwrap(URL(string: "https://composition.example.test"))
        return .init(market: market, baseURL: base, role: role,
                     session: try .init(accountID: 7, epoch: 1, namespace: "tests", token: "synthetic-token", role: role))
    }

    func testFactoryIssuesOnlyCatalogTemplatesForTheBoundConversation() throws {
        let gates = ReviewedProductionGateLeases()
        let player = try context()
        let template = try XCTUnwrap(IMPreviewRouteTemplates.template(for: .imFilePreview))
        XCTAssertNil(gates.imPreviewLease(player, conversationID: 11, template: template, now: now))
        gates.notePlayerWrites(true)
        let lease = try XCTUnwrap(gates.imPreviewLease(player, conversationID: 11, template: template, now: now))
        XCTAssertEqual(gates.imPreviewLease(player, conversationID: 11, template: template, now: now), lease)
        XCTAssertNil(lease.issue(method: "GET", path: "api/im/file/message/../preview", messageID: 42, messageConversationID: 11, viewer: player, now: now))
        XCTAssertNil(lease.issue(method: "GET", path: "api/im/file/message/42%2Fpreview", messageID: 42, messageConversationID: 11, viewer: player, now: now))
        XCTAssertNil(lease.issue(method: "POST", path: "api/im/file/message/42/preview", messageID: 42, messageConversationID: 11, viewer: player, now: now))
        XCTAssertNil(lease.issue(method: "GET", path: "api/im/file/message/42/preview", messageID: 42, messageConversationID: 22, viewer: player, now: now))
        XCTAssertNil(lease.issue(method: "GET", path: "api/im/file/message/42/preview", messageID: 42, messageConversationID: 11, viewer: player, now: lease.expiresAt))
        let route = try XCTUnwrap(lease.issue(method: "GET", path: "api/im/file/message/42/preview", messageID: 42, messageConversationID: 11, viewer: player, now: now))
        XCTAssertEqual(route.method, "GET")
        XCTAssertEqual(route.path, "api/im/file/message/42/preview")
        XCTAssertNil(gates.imPreviewLease(player, conversationID: 0, template: template, now: now))
        let merchant = try context(role: "merchant")
        let unitedStates = try context(market: .unitedStates)
        let club = try context(role: "club")
        XCTAssertNil(gates.imPreviewLease(merchant, conversationID: 11, template: template, now: now))
        XCTAssertNil(gates.imPreviewLease(unitedStates, conversationID: 11, template: template, now: now))
        let invented = try XCTUnwrap(BusinessRuntimeRouteTemplate(method: "GET", path: "api/channels/{id}/members", feature: .imChannelMentionMemberRead))
        XCTAssertNil(gates.imPreviewLease(player, conversationID: 11, template: invented, now: now))
        XCTAssertNotNil(gates.imPreviewLease(club, conversationID: 11, template: template, now: now))
        let other = try XCTUnwrap(gates.imPreviewLease(player, conversationID: 22, template: template, now: now))
        XCTAssertNotEqual(other, lease)
        XCTAssertEqual(ReviewedProductionGateLeases.imPreviewTemplates, IMPreviewRouteTemplates.all)
        let dependencies = gates.sessionDependencies(player)
        let routes = dependencies.businessConfiguration?.routes ?? [:]
        for feature in [BusinessRuntimeFeature.imFilePreview, .imFilePreviewStatus, .imVideoPreview, .imVideoPreviewStatus, .imVoicePlayback, .imVoicePlaybackStatus] {
            XCTAssertNil(routes[feature], "\(feature) stays out of the exact route table")
        }
    }
}
