#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// MP `pages/coop/invite` 核销据点 (wxml:114-131, js:578-650, 1015-1017): one confirmed station per merchant,
/// sent as `supplyStationId` on `POST /api/coop/invite`.
final class CoopInviteSupplyStationTests: XCTestCase {
    private func session() throws -> CoopFlowSession { try CoopFlowSession(accountID: 1, epoch: 1, token: "synthetic-token") }
    private func context(_ id: Int, kind: CoopFlowTargetKind = .merchant, session: CoopFlowSession) throws -> CoopFlowInvitationContext {
        let topic = try XCTUnwrap(CoopFlowOwnedTopic(row: .object(["id": .id(3), "name": .string("Topic"), "inviteWindowOpen": .bool(true)])))
        let row: CoopFlowJSON = .object([kind == .merchant ? "memberId" : "id": .id(id), "name": .string("Target \(id)")])
        let candidate = try XCTUnwrap(CoopFlowTargetCandidate(kind: kind, row: row))
        return try XCTUnwrap(CoopFlowInvitationContext(candidate: candidate, topic: topic, scope: nil, session: session))
    }

    func testParseFollowsTheMiniProgramShapeRules() {
        let ok: CoopFlowJSON = .object(["requiresSupplyStation": .bool(true), "stations": .array([
            .object(["supplyStationId": .id(11), "stationName": .string("East gate")]),
            .object(["supplyStationId": .string("12"), "stationName": .string("West hall")]),
        ])])
        XCTAssertEqual(CoopInviteSupplyStations.parse(ok),
                       .init(required: true, stations: [.init(id: 11, name: "East gate"), .init(id: 12, name: "West hall")]))
        XCTAssertEqual(CoopInviteSupplyStations.parse(.object(["requiresSupplyStation": .bool(false)])), .init(required: false, stations: []))
        XCTAssertNil(CoopInviteSupplyStations.parse(.object([:])))
        XCTAssertNil(CoopInviteSupplyStations.parse(.object(["requiresSupplyStation": .bool(true)])))
        let blank: CoopFlowJSON = .object(["requiresSupplyStation": .bool(true), "stations": .array([
            .object(["supplyStationId": .id(11), "stationName": .string("  ")])])])
        XCTAssertNil(CoopInviteSupplyStations.parse(blank))
        let duplicate: CoopFlowJSON = .object(["requiresSupplyStation": .bool(true), "stations": .array([
            .object(["supplyStationId": .id(11), "stationName": .string("A")]),
            .object(["supplyStationId": .id(11), "stationName": .string("B")])])])
        XCTAssertNil(CoopInviteSupplyStations.parse(duplicate))
    }

    func testReadyNeedsAListedPickForEveryMerchantOnlyWhenRequired() {
        let a = CoopInviteStationOption(id: 11, name: "A"), b = CoopInviteStationOption(id: 12, name: "B")
        XCTAssertTrue(CoopInviteSupplyStations.ready(required: false, merchantIDs: [2], stations: [:], picks: [:]))
        XCTAssertFalse(CoopInviteSupplyStations.ready(required: true, merchantIDs: [2, 5], stations: [2: [a], 5: [b]], picks: [2: a]))
        XCTAssertFalse(CoopInviteSupplyStations.ready(required: true, merchantIDs: [2], stations: [2: [a]], picks: [2: b]))
        XCTAssertTrue(CoopInviteSupplyStations.ready(required: true, merchantIDs: [2, 5], stations: [2: [a], 5: [b]], picks: [2: a, 5: b]))
    }

    func testChosenStationReachesTheInviteBody() throws {
        let s = try session()
        let contexts = try [context(2, session: s), context(5, session: s)]
        let picks: [Int: CoopInviteStationOption] = [2: .init(id: 11, name: "A"), 5: .init(id: 12, name: "B")]
        XCTAssertNil(CoopInviteSupplyStations.attach(contexts, required: true, picks: [2: .init(id: 11, name: "A")]))
        let attached = try XCTUnwrap(CoopInviteSupplyStations.attach(contexts, required: true, picks: picks))
        XCTAssertEqual(attached.map(\.supplyStationID), [11, 12])
        XCTAssertEqual(attached.map(\.supplyStationName), ["A", "B"])
        let drafts = try XCTUnwrap(CoopFlowBatchInvite.drafts(contexts: attached, message: "Hi", defaultMessage: "D",
                                                              fixed: false, fee: "", currentSession: s))
        XCTAssertEqual(drafts.map(\.supplyStationID), [11, 12])
        let body = try CoopFlowMutation.invite(drafts[0]).body()
        XCTAssertEqual(body["supplyStationId"], .id(11))
    }

    func testNoStationWhenNotRequiredOrForClubs() throws {
        let s = try session()
        let merchant = try context(2, session: s)
        let plain = try XCTUnwrap(CoopInviteSupplyStations.attach([merchant], required: false, picks: [2: .init(id: 11, name: "A")]))
        XCTAssertNil(plain[0].supplyStationID)
        let draft = try plain[0].invitation(message: "Hi", compensation: .traffic, currentSession: s)
        XCTAssertEqual(try CoopFlowMutation.invite(draft).body()["supplyStationId"], .null)
        let club = try context(7, kind: .club, session: s).withSupplyStation(.init(id: 11, name: "A"))
        XCTAssertNil(club.supplyStationID)
    }
}
#endif
