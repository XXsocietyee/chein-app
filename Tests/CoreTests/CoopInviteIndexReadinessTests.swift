#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class CoopInviteIndexReadinessTests: XCTestCase {
    func testUnknownCountIsEmDashAndLiteralZeroStaysZero() {
        XCTAssertEqual(CoopInviteIndexReadiness.unknownDisplay, "—")
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: .id(0)).display, "0")
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: .id(0)).value, 0)
        XCTAssertFalse(CoopInviteIndexReadiness.Count(json: .id(0)).isUnknown)
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: .string("0")).display, "0")
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: .string("12")).display, "12")
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: nil).display, "—")
        XCTAssertNil(CoopInviteIndexReadiness.Count(json: nil).value)
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: .null).display, "—")
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: .string("UNKNOWN")).display, "—")
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: .string("")).display, "—")
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: .string("00")).display, "—")
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: .string("1.5")).display, "—")
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: .bool(false)).display, "—")
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: .number(Decimal(string: "1.5")!)).display, "—")
        XCTAssertEqual(CoopInviteIndexReadiness.Count(json: .id(-3)).display, "—")
        XCTAssertEqual(CoopInviteIndexReadiness.Count.known(0).display, "0")
        XCTAssertEqual(CoopInviteIndexReadiness.Count.known(-1).display, "—")
    }

    func testDirectoryPhasesAreLoadingEmptyErrorUnknownAndReady() {
        let loading = CoopInviteIndexReadiness.topics(loading: true, payload: nil, failed: true)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertNil(loading.messageKey)
        XCTAssertEqual(loading.count.display, "—")

        let missing = CoopInviteIndexReadiness.topics(loading: false, payload: nil, failed: false)
        XCTAssertEqual(missing.phase, .unknown)
        XCTAssertEqual(missing.count.display, "—")
        XCTAssertNotEqual(missing.count.display, "0")

        let token = CoopInviteIndexReadiness.topics(loading: false, payload: .string("UNKNOWN"), failed: false)
        XCTAssertEqual(token.phase, .unknown)
        XCTAssertEqual(token.count.display, "—")

        let empty = CoopInviteIndexReadiness.topics(loading: false, payload: topics([]), failed: false)
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.messageKey, "context.picker.empty")
        XCTAssertEqual(empty.count.display, "0")
        XCTAssertEqual(empty.count.value, 0)

        let failed = CoopInviteIndexReadiness.topics(loading: false, payload: topics([openTopic(7)]), failed: true)
        XCTAssertEqual(failed.phase, .error)
        XCTAssertEqual(failed.messageKey, "coopflow.read.failed")
        XCTAssertTrue(failed.rows.isEmpty)
        XCTAssertEqual(failed.count.display, "—")

        let ready = CoopInviteIndexReadiness.topics(loading: false, payload: topics([openTopic(7)]), failed: false)
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.rows.map(\.id), [7])
        XCTAssertEqual(ready.rows.first?.window, .open)
        XCTAssertEqual(ready.count.display, "1")

        let broken = CoopInviteIndexReadiness.topics(loading: false, payload: .object([:]), failed: false)
        XCTAssertEqual(broken.phase, .error)
        XCTAssertEqual(broken.count.display, "—")

        let duplicate = CoopInviteIndexReadiness.topics(loading: false, payload: topics([openTopic(7), openTopic(7)]), failed: false)
        XCTAssertEqual(duplicate.phase, .error)
        XCTAssertTrue(duplicate.rows.isEmpty)
    }

    func testClubMemberCountZeroStaysZeroAndUnknownStaysEmDash() throws {
        let rows: [(CoopFlowJSON?, String)] = [
            (.id(0), "0"),
            (.id(4), "4"),
            (.string("0"), "0"),
            (.string("12"), "12"),
            (nil, "—"),
            (.null, "—"),
            (.string("UNKNOWN"), "—"),
            (.string("00"), "—"),
            (.number(Decimal(string: "1.5")!), "—"),
            (.id(-1), "—"),
        ]
        for (count, display) in rows {
            let directory = CoopInviteIndexReadiness.targets(kind: .club, loading: false, payload: .array([club(3, count: count)]), failed: false)
            XCTAssertEqual(directory.phase, .ready, "\(String(describing: count))")
            XCTAssertEqual(directory.rows.first?.memberCountText, display)
            XCTAssertTrue(directory.rows.first?.showsMemberCount == true)
        }

        let zero = try XCTUnwrap(CoopFlowTargetCandidate(kind: .club, row: club(3, count: .id(0))))
        XCTAssertEqual(zero.memberCount, 0)
        let missing = try XCTUnwrap(CoopFlowTargetCandidate(kind: .club, row: club(3, count: nil)))
        XCTAssertNil(missing.memberCount)
        let padded = try XCTUnwrap(CoopFlowTargetCandidate(kind: .club, row: club(3, count: .string("00"))))
        XCTAssertEqual(padded.memberCount, 0)
    }

    func testMerchantMemberCountStaysHidden() {
        let row: CoopFlowJSON = .object([
            "id": .id(99), "memberId": .id(4), "name": .string("Store"),
            "memberCount": .id(8), "suitActivityTypes": .string("Walk"),
        ])
        let directory = CoopInviteIndexReadiness.targets(kind: .merchant, loading: false, payload: .array([row]), failed: false)
        XCTAssertEqual(directory.phase, .ready)
        XCTAssertEqual(directory.rows.first?.id, "0:4")
        XCTAssertNil(directory.rows.first?.memberCount)
        XCTAssertNil(directory.rows.first?.memberCountText)
        XCTAssertEqual(directory.rows.first?.showsMemberCount, false)
        XCTAssertEqual(directory.rows.first?.merchantMeta, "Walk")

        let empty = CoopInviteIndexReadiness.targets(kind: .merchant, loading: false, payload: .array([]), failed: false)
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.count.display, "0")
        let unknown = CoopInviteIndexReadiness.targets(kind: .merchant, loading: false, payload: .string("UNKNOWN"), failed: false)
        XCTAssertEqual(unknown.phase, .unknown)
        XCTAssertEqual(unknown.count.display, "—")
        XCTAssertNotEqual(unknown.count.display, "0")
    }

    func testClosedAndUnknownWindowsCannotInviteAndSendStaysHidden() {
        let open = CoopInviteIndexReadiness.topics(loading: false, payload: topics([openTopic(7)]), failed: false)
        let closed = CoopInviteIndexReadiness.topics(loading: false, payload: topics([topic(7, window: .bool(false))]), failed: false)
        let unknown = CoopInviteIndexReadiness.topics(loading: false, payload: topics([topic(7, window: .null)]), failed: false)
        let clubs = CoopInviteIndexReadiness.targets(kind: .club, loading: false, payload: .array([club(3, count: .id(2))]), failed: false)
        let selected = Set([clubs.rows[0].id])

        XCTAssertEqual(open.rows.first?.window, .open)
        XCTAssertTrue(CoopInviteIndexReadiness.canContinue(topic: open.rows.first, selected: selected, targets: clubs.rows))
        XCTAssertEqual(closed.rows.first?.window, .closed)
        XCTAssertFalse(closed.rows.first?.window.canInvite ?? true)
        XCTAssertFalse(CoopInviteIndexReadiness.canContinue(topic: closed.rows.first, selected: selected, targets: clubs.rows))
        XCTAssertEqual(unknown.rows.first?.window, .unknown)
        XCTAssertFalse(CoopInviteIndexReadiness.canContinue(topic: unknown.rows.first, selected: selected, targets: clubs.rows))
        XCTAssertFalse(CoopInviteIndexReadiness.canContinue(topic: open.rows.first, selected: [], targets: clubs.rows))

        let page = CoopInviteIndexReadiness.snapshot(topics: open, targets: clubs, selected: .known(1))
        XCTAssertEqual(page.phase, .ready)
        XCTAssertEqual(page.selected.display, "1")
        XCTAssertFalse(page.showsInviteSend)
        XCTAssertFalse(page.showsShare)
        XCTAssertFalse(page.showsLockedTarget)
        XCTAssertFalse(page.showsMerchantChoice)
        XCTAssertFalse(page.paymentEnabled)
        XCTAssertFalse(page.payoutEnabled)
        XCTAssertFalse(page.withdrawalEnabled)
        XCTAssertFalse(page.virtualGoodsEnabled)
        XCTAssertFalse(CoopInviteIndexReadiness.inviteSendOffered)
        XCTAssertFalse(CoopInviteIndexReadiness.shareOffered)
        XCTAssertFalse(CoopInviteIndexReadiness.showsLockedTarget(toId: 4, originApplyId: 9))
        XCTAssertFalse(CoopInviteIndexReadiness.showsLockedTarget(toId: nil, originApplyId: nil))

        let unselected = CoopInviteIndexReadiness.snapshot(topics: open, targets: clubs, selected: .unknown)
        XCTAssertEqual(unselected.phase, .unknown)
        XCTAssertEqual(unselected.selected.display, "—")
    }

    func testSupportingReadsAreLiveAndInviteRouteIsNotMarkedLive() {
        for kind in [CoopFlowTargetKind.merchant, .club] {
            let reads = CoopInviteIndexReadiness.supportingReads(kind: kind, scope: nil, page: 1)
            XCTAssertEqual(reads.count, 2)
            XCTAssertTrue(reads.allSatisfy(CoopInviteIndexReadiness.supportingReadIsLive))
            XCTAssertFalse(reads.contains { $0.path == "api/coop/invite" })
        }
        XCTAssertFalse(CoopInviteIndexReadiness.inviteRouteMarkedLive)
        XCTAssertNotEqual(ChinaReviewedRouteCapability.mark(for: CoopInviteIndexReadiness.invitePath), .liveInProduction)
        XCTAssertEqual(CoopInviteIndexReadiness.missingKeys, ["toId", "originApplyId", "merchantName", "share", "coopInvited", "originalRequest", "countdown"])
    }

    private func topics(_ rows: [CoopFlowJSON]) -> CoopFlowJSON { .object(["rows": .array(rows)]) }

    private func openTopic(_ id: Int) -> CoopFlowJSON { topic(id, window: .bool(true)) }

    private func topic(_ id: Int, window: CoopFlowJSON) -> CoopFlowJSON {
        .object(["id": .id(id), "name": .string("Topic \(id)"), "inviteWindowOpen": window, "startDate": .string("2026-11-09"), "addressName": .string("Hall")])
    }

    private func club(_ id: Int, count: CoopFlowJSON?) -> CoopFlowJSON {
        var fields: [String: CoopFlowJSON] = ["id": .id(id), "name": .string("Club \(id)"), "city": .string("Shanghai")]
        if let count { fields["memberCount"] = count }
        return .object(fields)
    }
}
#endif
