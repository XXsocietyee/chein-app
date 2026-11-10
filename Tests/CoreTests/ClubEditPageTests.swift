import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

/// pages/club/edit/index: loading, empty, error, and unknown counts stay an em dash.
/// Edit and dissolve stay on the existing commands and off the player-first entry.
final class ClubEditPageTests: XCTestCase {
    private func page(_ raw: String, surface: ClubEditPage.Surface = .manage, clubID: Int = 81, governance: Bool = true, blockers: String? = nil) -> ClubEditPage {
        ClubEditPage.make(read: .detail(Data(raw.utf8), blockers: blockers.map { Data($0.utf8) }), surface: surface, clubID: clubID, governanceAvailable: governance)
    }
    private func ownerProfile() throws -> ClubOperationsProfile {
        try JSONDecoder().decode(ClubOperationsProfile.self, from: Data(ClubEditFixtureData.owner.utf8))
    }

    func testLoadingEmptyAndErrorUseTheEmDashAndHideActions() {
        for read in [ClubEditPage.Read.loading, .empty, .error, .unknown] {
            let value = ClubEditPage.make(read: read, surface: .manage, clubID: 81, governanceAvailable: true)
            XCTAssertEqual(value.reservedQuotaText, ClubEditPage.unknownMark)
            XCTAssertEqual(value.memberCountText, ClubEditPage.unknownMark)
            XCTAssertEqual(value.blockerCountText, ClubEditPage.unknownMark)
            XCTAssertNotEqual(value.reservedQuotaText, "0")
            XCTAssertFalse(value.showsEdit)
            XCTAssertFalse(value.showsDissolve)
            XCTAssertNil(value.updatePath)
            XCTAssertNil(value.dissolvePath)
            XCTAssertFalse(value.entryVisible)
        }
        XCTAssertEqual(ClubEditPage.unknownMark, "—")
    }

    func testExplicitZeroStaysZeroAndUnknownQuotaStaysAnEmDash() throws {
        let zero = page(ClubEditFixtureData.explicitZero, blockers: ClubEditFixtureData.blockersEmpty)
        XCTAssertEqual(zero.state, .ready)
        XCTAssertEqual(zero.reservedQuotaText, "0")
        XCTAssertEqual(zero.memberCountText, "0")
        XCTAssertEqual(zero.blockerCountText, "0")
        XCTAssertTrue(zero.showsEdit)
        XCTAssertTrue(zero.showsDissolve)

        let missing = page(ClubEditFixtureData.missingQuota, blockers: ClubEditFixtureData.blockersEmpty)
        let collapsed = try JSONDecoder().decode(ClubOperationsProfile.self, from: Data(ClubEditFixtureData.missingQuota.utf8))
        XCTAssertEqual(collapsed.memberReservedQuota, 0)
        XCTAssertEqual(missing.state, .ready)
        XCTAssertEqual(missing.reservedQuotaText, "—")
        XCTAssertEqual(missing.memberCountText, "—")
        XCTAssertNotEqual(missing.reservedQuotaText, "0")
        XCTAssertFalse(missing.showsEdit)
        XCTAssertTrue(missing.showsDissolve)

        let unknown = page(ClubEditFixtureData.unknownQuota, blockers: ClubEditFixtureData.blockersEmpty)
        XCTAssertThrowsError(try JSONDecoder().decode(ClubOperationsProfile.self, from: Data(ClubEditFixtureData.unknownQuota.utf8)))
        XCTAssertEqual(unknown.reservedQuotaText, "—")
        XCTAssertEqual(unknown.memberCountText, "—")
        XCTAssertNotEqual(unknown.reservedQuotaText, "0")
        XCTAssertFalse(unknown.showsEdit)
        XCTAssertFalse(unknown.showsDissolve)
        XCTAssertNil(unknown.updatePath)
    }

    func testOwnerAdminAndMemberCapabilitiesStayOnExistingPaths() throws {
        let owner = page(ClubEditFixtureData.owner, blockers: ClubEditFixtureData.blockersEmpty)
        let profile = try ownerProfile()
        let update = ClubOperationsCommand.update(ClubOperationsDraft(profile: profile), original: profile).path
        XCTAssertTrue(owner.showsEdit)
        XCTAssertTrue(owner.showsDissolve)
        XCTAssertTrue(owner.entryVisible)
        XCTAssertEqual(owner.updatePath, update)
        XCTAssertEqual(owner.dissolvePath, ClubGovernanceMutation.dissolve.path)
        XCTAssertEqual(owner.blockersPath, ClubGovernanceRead.dissolutionBlockers.path)
        XCTAssertEqual(owner.reservedQuotaText, "4")
        XCTAssertEqual(owner.blockerCountText, "0")

        let admin = page(ClubEditFixtureData.admin)
        XCTAssertTrue(admin.showsEdit)
        XCTAssertFalse(admin.showsDissolve)
        XCTAssertNil(admin.dissolvePath)
        XCTAssertNil(admin.blockersPath)
        XCTAssertEqual(admin.blockerCountText, "—")
        XCTAssertEqual(admin.updatePath, update)

        let member = page(ClubEditFixtureData.member)
        XCTAssertEqual(member.state, .ready)
        XCTAssertFalse(member.showsEdit)
        XCTAssertFalse(member.showsDissolve)
        XCTAssertFalse(member.entryVisible)
        XCTAssertNil(member.updatePath)
    }

    func testPlayerFirstEntryHidesEditAndDissolve() throws {
        let value = page(ClubEditFixtureData.owner, surface: .playerFirst, blockers: ClubEditFixtureData.blockersEmpty)
        XCTAssertTrue(value.isPlayerFirstEntry)
        XCTAssertEqual(value.state, .ready)
        XCTAssertEqual(value.reservedQuotaText, "4")
        XCTAssertFalse(value.showsEdit)
        XCTAssertFalse(value.showsDissolve)
        XCTAssertFalse(value.entryVisible)
        XCTAssertNil(value.updatePath)
        XCTAssertNil(value.dissolvePath)
        XCTAssertNil(value.blockersPath)
        XCTAssertEqual(value.blockerCountText, "—")
    }

    func testMissingGovernanceHidesDissolveAndKeepsOwnerEdit() {
        let value = page(ClubEditFixtureData.owner, governance: false, blockers: ClubEditFixtureData.blockersEmpty)
        XCTAssertTrue(value.showsEdit)
        XCTAssertFalse(value.showsDissolve)
        XCTAssertNil(value.dissolvePath)
        XCTAssertEqual(value.blockerCountText, "—")
        XCTAssertNotEqual(value.blockerCountText, "0")
    }

    func testUnknownBlockersAreNotCountedAsZero() {
        let missing = page(ClubEditFixtureData.owner, blockers: ClubEditFixtureData.blockersMissing)
        XCTAssertEqual(missing.blockerCountText, "—")
        XCTAssertTrue(missing.showsDissolve)
        let broken = page(ClubEditFixtureData.owner, blockers: #"{"deposits":[1],"settlements":[]}"#)
        XCTAssertEqual(broken.blockerCountText, "—")
        XCTAssertNotEqual(broken.blockerCountText, "0")
        let absent = page(ClubEditFixtureData.owner, blockers: nil)
        XCTAssertEqual(absent.blockerCountText, "—")
    }

    func testEnvelopeWrongClubAndFailedBody() {
        let envelope = page(ClubEditFixtureData.envelopeOwner, blockers: ClubEditFixtureData.blockersEmpty)
        XCTAssertEqual(envelope.state, .ready)
        XCTAssertEqual(envelope.reservedQuotaText, "4")
        XCTAssertTrue(envelope.showsEdit)
        XCTAssertTrue(envelope.showsDissolve)
        XCTAssertEqual(page(ClubEditFixtureData.owner, clubID: 82).state, .unknown)
        XCTAssertEqual(page(ClubEditFixtureData.owner, clubID: 0).state, .unknown)
        XCTAssertEqual(page(ClubEditFixtureData.emptyDocument).state, .empty)
        XCTAssertEqual(page(ClubEditFixtureData.failedEnvelope).state, .error)
        XCTAssertEqual(page(#"{"id":81,"name":"Fixture club","city":"Fixture city","isOwner":true,"viewerIsAdmin":false,"memberReservedQuota":-1,"memberCount":-3,"prioritySignupEnabled":1,"joinPolicy":1,"joinPolicySupported":true}"#).reservedQuotaText, "—")
    }

    func testCoordinatorReadbackDoesNotInventANumberFromTheSnapshot() throws {
        let profile = try ownerProfile()
        let snapshot = ClubOperationsSnapshot(target: .club(81), profile: profile)
        let missingBody = ClubEditPage.make(readback: .received(snapshot), write: .idle, surface: .manage, clubID: 81, governanceAvailable: true, detailBody: nil, blockersBody: Data(ClubEditFixtureData.blockersEmpty.utf8))
        XCTAssertEqual(missingBody.state, .unknown)
        XCTAssertEqual(missingBody.reservedQuotaText, "—")
        XCTAssertNotEqual(missingBody.reservedQuotaText, "0")
        XCTAssertNotEqual(missingBody.reservedQuotaText, "4")
        XCTAssertFalse(missingBody.showsEdit)

        let locked = ClubEditPage.make(readback: .received(snapshot), write: .outcomeUnknown(.transport), surface: .manage, clubID: 81, governanceAvailable: true, detailBody: Data(ClubEditFixtureData.owner.utf8), blockersBody: nil)
        XCTAssertEqual(locked.state, .unknown)
        XCTAssertFalse(locked.showsEdit)
        XCTAssertFalse(locked.showsDissolve)
        XCTAssertNil(locked.updatePath)

        XCTAssertEqual(ClubEditPage.make(readback: .loading, write: .idle, surface: .manage, clubID: 81, governanceAvailable: true, detailBody: nil, blockersBody: nil).state, .loading)
        XCTAssertEqual(ClubEditPage.make(readback: .unavailable, write: .idle, surface: .manage, clubID: 81, governanceAvailable: true, detailBody: nil, blockersBody: nil).state, .error)
        XCTAssertEqual(ClubEditPage.make(readback: .idle, write: .idle, surface: .manage, clubID: 81, governanceAvailable: true, detailBody: nil, blockersBody: nil).state, .empty)
        XCTAssertEqual(ClubEditPage.make(readback: .idle, write: .submitting, surface: .manage, clubID: 81, governanceAvailable: true, detailBody: Data(ClubEditFixtureData.owner.utf8), blockersBody: nil).state, .loading)
    }
}
#endif
