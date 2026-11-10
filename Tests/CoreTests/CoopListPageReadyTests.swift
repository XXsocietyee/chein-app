import XCTest
@testable import QuestifyCore

final class CoopListPageReadyTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func invites(_ json: String) throws -> CooperationInvites {
        try decode(CooperationInvites.self, json)
    }

    private func applications(_ json: String = "[]") throws -> [CooperationApplication] {
        try decode([CooperationApplication].self, json)
    }

    private func registrations(_ json: String = #"{"rows":[]}"#) throws -> CooperationRegistrations {
        try decode(CooperationRegistrations.self, json)
    }

    private func inbox(direction: CooperationDirection = .received,
                       invitations: CooperationSection<CooperationInvites>,
                       applications: CooperationSection<[CooperationApplication]>,
                       registrations: CooperationSection<CooperationRegistrations>? = nil) -> CooperationInbox {
        CooperationInbox(direction: direction, invitations: invitations, applications: applications, registrations: registrations)
    }

    func testHiddenCapabilityDoesNotBindOrInventZero() {
        let page = CoopListPageCoordinator.project(direction: .received, canRead: false, inbox: nil,
                                                   canComposeInvite: true, canReadFlowLegs: true)
        XCTAssertTrue(page.isHidden)
        XCTAssertEqual(page.phase, .loading)
        XCTAssertEqual(page.invitationCountText, "—")
        XCTAssertEqual(page.applicationCountText, "—")
        XCTAssertNil(page.registrationCountText)
        XCTAssertNotEqual(page.invitationCountText, "0")
        XCTAssertFalse(page.showsNewInvite)
        XCTAssertFalse(page.showsOfficialInvites)
        XCTAssertFalse(page.showsChapterApplications)
        XCTAssertFalse(page.showsShare)
        XCTAssertFalse(page.showsMerchantChoice)
        XCTAssertFalse(page.paymentEnabled)
        XCTAssertFalse(page.payoutEnabled)
        XCTAssertFalse(page.withdrawalEnabled)
        XCTAssertFalse(page.virtualGoodsEnabled)
        XCTAssertTrue(page.slotFacts.isEmpty)
    }

    func testLoadingCancellationAndWholeReadFailuresStayOffZero() throws {
        let loading = CoopListPageCoordinator.project(direction: .received, canRead: true, inbox: nil, canComposeInvite: true)
        XCTAssertFalse(loading.isHidden)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.invitationCountText, CoopListPage.unknownMark)
        XCTAssertEqual(CoopListPage.unknownMark, "—")
        XCTAssertEqual(loading.registrationCountText, "—")
        XCTAssertNotEqual(loading.invitationCountText, "0")
        XCTAssertTrue(loading.showsNewInvite)
        XCTAssertFalse(loading.showsOfficialInvites)
        XCTAssertFalse(loading.showsShare)

        let sentLoading = CoopListPageCoordinator.project(direction: .sent, canRead: true, inbox: nil)
        XCTAssertNil(sentLoading.registrationCountText)
        XCTAssertEqual(sentLoading.invitationCountText, "—")
        XCTAssertFalse(sentLoading.showsNewInvite)

        let cancelled = CoopListPageCoordinator.project(direction: .received, canRead: true, inbox: .failure(CancellationError()),
                                                        canReadFlowLegs: true)
        XCTAssertEqual(cancelled.phase, .loading)
        XCTAssertEqual(cancelled.invitationCountText, "—")
        XCTAssertTrue(cancelled.showsOfficialInvites)
        XCTAssertTrue(cancelled.showsChapterApplications)
        XCTAssertFalse(cancelled.showsShare)

        let failed = CoopListPageCoordinator.project(direction: .received, canRead: true, inbox: .failure(APIError.httpStatus(503)))
        XCTAssertEqual(failed.phase, .error)
        XCTAssertEqual(failed.invitationCountText, "—")
        XCTAssertEqual(failed.applicationCountText, "—")
        XCTAssertEqual(failed.registrationCountText, "—")
        XCTAssertNotEqual(failed.invitationCountText, "0")
        XCTAssertTrue(failed.slotFacts.isEmpty)
        XCTAssertFalse(failed.paymentEnabled)

        let unknown = CoopListPageCoordinator.project(direction: .sent, canRead: true,
                                                      inbox: .failure(APIError.malformedResponse), canComposeInvite: true)
        XCTAssertEqual(unknown.phase, .unknown)
        XCTAssertEqual(unknown.invitationCountText, "—")
        XCTAssertNil(unknown.registrationCountText)
        XCTAssertNotEqual(unknown.invitationCountText, "0")
        XCTAssertTrue(unknown.showsNewInvite)
        XCTAssertFalse(unknown.showsOfficialInvites)
        XCTAssertFalse(unknown.showsChapterApplications)

        let decoded = CoopListPageCoordinator.project(direction: .received, canRead: true,
                                                      inbox: .failure(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "synthetic"))))
        XCTAssertEqual(decoded.phase, .unknown)
        XCTAssertEqual(decoded.registrationCountText, "—")
    }

    func testKnownEmptyIsZeroAndSentRegistrationsStayHidden() throws {
        let emptyReceived = try inbox(invitations: .content(invites(#"{"sent":[{"id":9}],"received":[]}"#)),
                                      applications: .content(applications()),
                                      registrations: .content(registrations()))
        let received = CoopListPageCoordinator.project(direction: .received, canRead: true, inbox: .success(emptyReceived))
        XCTAssertEqual(received.phase, .empty)
        XCTAssertEqual(received.invitationCountText, "0")
        XCTAssertEqual(received.applicationCountText, "0")
        XCTAssertEqual(received.registrationCountText, "0")
        XCTAssertFalse(received.isPartial)
        XCTAssertTrue(received.slotFacts.isEmpty)
        XCTAssertFalse(received.showsShare)

        let emptySent = try inbox(direction: .sent, invitations: .content(invites(#"{"sent":[],"received":[{"id":9}]}"#)),
                                  applications: .content(applications()))
        let sent = CoopListPageCoordinator.project(direction: .sent, canRead: true, inbox: .success(emptySent), canReadFlowLegs: true)
        XCTAssertEqual(sent.phase, .empty)
        XCTAssertEqual(sent.invitationCountText, "0")
        XCTAssertNil(sent.registrationCountText)
        XCTAssertFalse(sent.showsOfficialInvites)
        XCTAssertTrue(sent.showsChapterApplications)
    }

    func testReadyRowsKeepLiteralZeroAndDoNotFallThroughSlots() throws {
        let list = try invites(#"""
        {"received":[{"id":7,"topicId":3,"gameId":4},{"id":7,"topicId":8},{"id":11,"topicId":3,"gameId":9}],
         "slots":{"byGame":{"4":{"pending":0,"cap":0},"9":{"pending":2}},"byTopic":{"3":{"accepted":1,"cap":5},"8":{"accepted":-1,"cap":3}}}}
        """#)
        XCTAssertEqual(list.occupancy(for: list.received[0])?.count, 0)
        XCTAssertNil(list.occupancy(for: list.received[2]), "An incomplete game slot still does not become the topic slot")
        let applications = try applications(#"[{"applyId":81,"topicId":3,"status":0}]"#)
        let regs = try registrations(#"{"rows":[{"id":91},{"id":92}],"hasMore":true}"#)
        let page = CoopListPageCoordinator.project(direction: .received, canRead: true, inbox: .success(
            inbox(invitations: .content(list), applications: .content(applications), registrations: .content(regs))),
                                                   canComposeInvite: true, canReadFlowLegs: true)
        XCTAssertEqual(page.phase, .ready)
        XCTAssertEqual(page.invitationCountText, "3")
        XCTAssertEqual(page.applicationCountText, "1")
        XCTAssertEqual(page.registrationCountText, "2")
        XCTAssertEqual(page.slotFacts.map(\.ordinal), [0, 1, 2])
        XCTAssertEqual(page.slotFacts.map(\.inviteID), [7, 7, 11])
        XCTAssertEqual(page.slotFacts.map(\.countText), ["0", "—", "2"])
        XCTAssertEqual(page.slotFacts.map(\.capacityText), ["0", "3", "—"])
        XCTAssertEqual(page.slotFacts.map(\.kind), [.gamePending, .topicAccepted, .gamePending] as [CooperationOccupancy.Kind])
        XCTAssertNotEqual(page.slotFacts[1].countText, "0")
        XCTAssertNotEqual(page.slotFacts[2].capacityText, "0")
        XCTAssertNotEqual(page.slotFacts[2].countText, "1")
        XCTAssertTrue(page.showsNewInvite)
        XCTAssertTrue(page.showsOfficialInvites)
        XCTAssertFalse(page.showsShare)
        XCTAssertFalse(page.paymentEnabled)
    }

    func testPartialFailureKeepsKnownZeroAndUnknownCountsApart() throws {
        let list = try invites(#"{"received":[],"sent":[{"id":4}]}"#)
        let mixed = inbox(invitations: .content(list), applications: .content(try applications()),
                          registrations: .failure(.server("Registrations unavailable")))
        let page = CoopListPageCoordinator.project(direction: .received, canRead: true, inbox: .success(mixed))
        XCTAssertEqual(page.phase, .error)
        XCTAssertTrue(page.isPartial)
        XCTAssertEqual(page.invitationCountText, "0")
        XCTAssertEqual(page.applicationCountText, "0")
        XCTAssertEqual(page.registrationCountText, "—")
        XCTAssertNotEqual(page.registrationCountText, "0")

        let sibling = inbox(invitations: .failure(.server("down")),
                            applications: .content(try applications(#"[{"applyId":1,"topicId":2}]"#)),
                            registrations: .content(try registrations()))
        let ready = CoopListPageCoordinator.project(direction: .received, canRead: true, inbox: .success(sibling))
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.invitationCountText, "—")
        XCTAssertEqual(ready.applicationCountText, "1")
        XCTAssertEqual(ready.registrationCountText, "0")
        XCTAssertTrue(ready.slotFacts.isEmpty)
    }

    func testMalformedInvitePayloadIsUnknownAndNumericStringsAreNotZero() throws {
        let malformed = inbox(invitations: .failure(.malformed),
                              applications: .content(try applications(#"[{"applyId":3,"topicId":4}]"#)),
                              registrations: .content(try registrations(#"{"rows":[{"id":1}]}"#)))
        let page = CoopListPageCoordinator.project(direction: .received, canRead: true, inbox: .success(malformed))
        XCTAssertEqual(page.phase, .unknown)
        XCTAssertEqual(page.invitationCountText, "—")
        XCTAssertEqual(page.applicationCountText, "1")
        XCTAssertEqual(page.registrationCountText, "1")
        XCTAssertNotEqual(page.invitationCountText, "0")
        XCTAssertTrue(page.slotFacts.isEmpty)

        let siblingOnly = inbox(invitations: .content(try invites(#"{"received":[]}"#)),
                                applications: .failure(.malformed),
                                registrations: .content(try registrations()))
        let unknownSibling = CoopListPageCoordinator.project(direction: .received, canRead: true, inbox: .success(siblingOnly))
        XCTAssertEqual(unknownSibling.phase, .unknown)
        XCTAssertEqual(unknownSibling.invitationCountText, "0")
        XCTAssertEqual(unknownSibling.applicationCountText, "—")

        XCTAssertThrowsError(try invites(#"{"received":[{"id":1,"gameId":4}],"slots":{"byGame":{"4":{"pending":"UNKNOWN","cap":1}}}}"#))
        XCTAssertThrowsError(try invites(#"{"received":[{"id":1,"gameId":4}],"slots":{"byGame":{"4":{"pending":"0","cap":1}}}}"#))
        let missing = try invites(#"{"received":[{"id":1,"gameId":4}],"slots":{"byGame":{"4":{"pending":null,"cap":0}}}}"#)
        XCTAssertNil(missing.occupancy(for: missing.received[0]))
        let projected = CoopListPageCoordinator.project(direction: .received, canRead: true, inbox: .success(
            inbox(invitations: .content(missing), applications: .content(try applications()), registrations: .content(try registrations()))))
        XCTAssertEqual(projected.phase, .ready)
        XCTAssertEqual(projected.slotFacts.map(\.countText), ["—"])
        XCTAssertEqual(projected.slotFacts.map(\.capacityText), ["0"])
        XCTAssertNotEqual(projected.slotFacts.map(\.countText), ["0"])
        let literal = try invites(#"{"received":[{"id":1,"gameId":4}],"slots":{"byGame":{"4":{"pending":0,"cap":1}}}}"#)
        XCTAssertEqual(literal.occupancy(for: literal.received[0])?.count, 0)
    }

    func testMismatchedDirectionDoesNotBorrowTheOtherListAsZero() throws {
        let sent = try inbox(direction: .sent, invitations: .content(invites(#"{"sent":[{"id":4}],"received":[]}"#)),
                             applications: .content(applications()))
        let page = CoopListPageCoordinator.project(direction: .received, canRead: true, inbox: .success(sent))
        XCTAssertEqual(page.phase, .unknown)
        XCTAssertEqual(page.invitationCountText, "—")
        XCTAssertEqual(page.applicationCountText, "—")
        XCTAssertEqual(page.registrationCountText, "—")
        XCTAssertNotEqual(page.invitationCountText, "0")
        XCTAssertFalse(page.isPartial)
    }
}
