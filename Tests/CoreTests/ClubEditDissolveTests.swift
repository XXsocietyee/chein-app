import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

/// club/edit: owner-only dissolve entry and the dissolve command body (`api/club/dissolve`).
final class ClubEditDissolveTests: XCTestCase {
    private func snapshot(target: ClubOperationsTarget, owner: Bool, admin: Bool) throws -> ClubOperationsSnapshot {
        let json = #"{"id":81,"name":"Fixture club","city":"Fixture city","isOwner":"# + (owner ? "true" : "false") + #","viewerIsAdmin":"# + (admin ? "true" : "false") + #"}"#
        let profile = try JSONDecoder().decode(ClubOperationsProfile.self, from: Data(json.utf8))
        return ClubOperationsSnapshot(target: target, profile: profile)
    }
    func testDissolveEntryIsOwnerOnly() throws {
        XCTAssertTrue(ClubEditDissolveAccess.isAvailable(snapshot: try snapshot(target: .club(81), owner: true, admin: false)))
        XCTAssertFalse(ClubEditDissolveAccess.isAvailable(snapshot: try snapshot(target: .club(81), owner: false, admin: true)))
        XCTAssertFalse(ClubEditDissolveAccess.isAvailable(snapshot: try snapshot(target: .club(82), owner: true, admin: false)))
        XCTAssertFalse(ClubEditDissolveAccess.isAvailable(snapshot: try snapshot(target: .create, owner: true, admin: false)))
        XCTAssertFalse(ClubEditDissolveAccess.isAvailable(snapshot: nil))
    }
    func testDissolveCommandNeedsExplicitConfirmationAndCarriesClubID() throws {
        var form = ClubGovernanceFormDraft(operation: .dissolve, scope: ClubGovernanceScope(clubID: 81))
        XCTAssertThrowsError(try form.command()) { XCTAssertEqual($0 as? ClubGovernanceFailure, .invalidRequest) }
        form.flags["dissolveConfirmed"] = true
        let command = try form.command()
        XCTAssertEqual(command.operation.path, "api/club/dissolve")
        XCTAssertEqual(command.fields["id"], .integer(81))
        XCTAssertEqual(command.fields["dissolveConfirmed"], .bool(true))
        XCTAssertEqual(command.fields["memberConsequencesConfirmed"], .bool(false))
    }
}
#endif
