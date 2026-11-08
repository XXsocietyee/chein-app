import Foundation
import XCTest
@testable import QuestifyCore

final class WP13RulesAgreementGateTests: XCTestCase {
    private func identity() throws -> ChannelAccount4Identity { try ChannelAccount4Identity(accountID: 7, epoch: 1) }
    private func catalog(published: Int = 3, pending: Int? = nil, expected: Int = 3) throws -> ChannelCatalogEntry {
        try ChannelCatalogEntry(channelID: 21, conversationID: 12, kind: .group,
                                rules: try ChannelRulesCAS(publishedVersion: published, pendingVersion: pending,
                                                           expectedVersion: expected))
    }
    private func joined(_ catalog: ChannelCatalogEntry) throws -> ChannelGovernanceProjection {
        var value = ChannelGovernanceProjection(catalog: catalog, identity: try identity())
        try value.consentToPublishedRules(try ChannelRulesAdmission(identity: try identity(), consentedVersion: catalog.rules.publishedVersion))
        try value.submitInviteOrApply(kind: 1, spaceID: 12, requestID: "wp13-join-01") { _, _, _, _, _, request in
            ["request_id": request, "status": 0, "join_state": "PENDING_REVIEW"]
        }
        try value.assignMemberRole(.member)
        return value
    }

    func testFirstPostRefusedUntilRulesAgreed() throws {
        let entry = try catalog()
        XCTAssertThrowsError(try ChannelRulesAdmission.firstPostGate(consentedVersion: nil, catalog: entry)) {
            XCTAssertEqual($0 as? ChannelAuthorizationError, .rulesConsentRequired)
        }
        var fresh = ChannelGovernanceProjection(catalog: entry, identity: try identity())
        XCTAssertThrowsError(try fresh.authorizeReadWrite()) {
            XCTAssertEqual($0 as? ChannelAuthorizationError, .notMember)
        }
        XCTAssertThrowsError(try fresh.submitInviteOrApply()) {
            XCTAssertEqual($0 as? ChannelAuthorizationError, .rulesConsentRequired)
        }
    }

    func testAgreeOnceThenPostAllowed() throws {
        let entry = try catalog()
        XCTAssertNoThrow(try ChannelRulesAdmission.firstPostGate(consentedVersion: 3, catalog: entry))
        var value = try joined(entry)
        XCTAssertNoThrow(try value.authorizeReadWrite())
        // Agreement is not asked again for the same published version.
        XCTAssertNoThrow(try value.authorizeReadWrite())
    }

    func testRulesUpgradeRequiresSeparateReconsent() throws {
        var value = try joined(try catalog())
        _ = try value.authorizeReadWrite()
        // Published version moves to 4; the old consent (3) no longer satisfies the gate.
        let upgraded = try catalog(published: 4, pending: nil, expected: 4)
        XCTAssertThrowsError(try ChannelRulesAdmission.firstPostGate(consentedVersion: 3, catalog: upgraded)) {
            XCTAssertEqual($0 as? ChannelAuthorizationError, .rulesConsentRequired)
        }
        XCTAssertThrowsError(try ChannelMemberAuthorizationProjection.authorize(
            identity: try identity(), catalog: upgraded, role: .member, consentedRulesVersion: 3, capability: .write)) {
            XCTAssertEqual($0 as? ChannelAuthorizationError, .rulesConsentRequired)
        }
        XCTAssertNoThrow(try ChannelRulesAdmission.firstPostGate(consentedVersion: 4, catalog: upgraded))
    }

    func testStaleCASConflictKeepsPending() throws {
        // Client holds expected 3 but published is already 4 with 5 pending: CAS conflict, not consent.
        let stale = try catalog(published: 4, pending: 5, expected: 3)
        XCTAssertThrowsError(try ChannelRulesAdmission.firstPostGate(consentedVersion: 4, catalog: stale)) {
            XCTAssertEqual($0 as? ChannelAuthorizationError, .rulesCASConflict)
        }
        // Consenting to the pending version does not admit: pending stays pending.
        let pendingCatalog = try catalog(published: 3, pending: 4, expected: 3)
        let admission = try ChannelRulesAdmission(identity: try identity(), consentedVersion: 4)
        XCTAssertThrowsError(try admission.admit(identity: try identity(), catalog: pendingCatalog)) {
            XCTAssertEqual($0 as? ChannelAuthorizationError, .rulesCASConflict)
        }
        XCTAssertEqual(pendingCatalog.rules.pendingVersion, 4)
        XCTAssertEqual(pendingCatalog.rules.publishedVersion, 3)
    }
}
