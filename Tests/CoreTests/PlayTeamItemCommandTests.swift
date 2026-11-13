import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class PlayTeamItemCommandTests: XCTestCase {
    func testOnlyTeamItemActionsMatchTheCommandBody() throws {
        let use = #"{"action":"ITEM_USE","activityId":41,"expectedRevision":3,"nodeId":null,"payload":{"contentId":"tea"},"requestId":"pg-theme-abc12345"}"#
        XCTAssertTrue(PlayTeamItemCommandBody.accepts(Data(use.utf8)))
        let choice = use.replacingOccurrences(of: "ITEM_USE", with: "PLAYER_CHOICE")
        XCTAssertFalse(PlayTeamItemCommandBody.accepts(Data(choice.utf8)))
        XCTAssertFalse(PlayTeamItemCommandBody.accepts(Data(#"{"action":"ITEM_USE","activityId":41,"amount":1,"expectedRevision":3,"nodeId":null,"payload":{"contentId":"tea"},"requestId":"pg-theme-abc12345"}"#.utf8)))
    }

    func testAppliedReceiptIsSuccessAndUnknownIsNot() throws {
        let applied = try wire(#"{"activityId":41,"requestId":"pg-theme-abc12345","action":"ITEM_USE","outcome":"APPLIED","receiptId":9,"revision":4}"#)
        guard case .applied(let receipt) = PlayTeamCommandInterpretation.interpret(payload: applied, activityID: 41, requestID: "pg-theme-abc12345", action: "ITEM_USE") else {
            return XCTFail("expected applied")
        }
        XCTAssertEqual(receipt.receiptID, 9)
        let pending = try wire(#"{"activityId":41,"requestId":"pg-theme-abc12345","action":"ITEM_USE","outcome":"PENDING","receiptId":9,"revision":4}"#)
        XCTAssertEqual(PlayTeamCommandInterpretation.interpret(payload: pending, activityID: 41, requestID: "pg-theme-abc12345", action: "ITEM_USE"), .unknown(requestID: "pg-theme-abc12345"))
        let mismatch = try wire(#"{"activityId":41,"requestId":"other-request","action":"ITEM_USE","outcome":"APPLIED","receiptId":9,"revision":4}"#)
        XCTAssertEqual(PlayTeamCommandInterpretation.interpret(payload: mismatch, activityID: 41, requestID: "pg-theme-abc12345", action: "ITEM_USE"), .unknown(requestID: "pg-theme-abc12345"))
        let failed = try wire(#"{"activityId":41,"requestId":"pg-theme-abc12345","action":"ITEM_DISCARD","outcome":"FAILED","receiptId":8,"revision":4,"reason":"Empty"}"#)
        guard case .failed(let failedReceipt, let reason) = PlayTeamCommandInterpretation.interpret(payload: failed, activityID: 41, requestID: "pg-theme-abc12345", action: "ITEM_DISCARD") else {
            return XCTFail("expected failed")
        }
        XCTAssertEqual(failedReceipt.outcome, "FAILED")
        XCTAssertEqual(reason, "Empty")
        XCTAssertFalse(PlayTeamCommandInterpretation.dash.isEmpty)
    }

    func testClosedCommandCapabilityDoesNotSend() async throws {
        let transport = CommandWire()
        let config = try APIConfiguration(baseURL: XCTUnwrap(URL(string: "https://example.com/fixture/")))
        let service = PlayExperienceService(configuration: config, transport: transport, enabled: [.reads])
        let client = PlayTeamItemCommandClient(service: service)
        let answer = await client.submit(activityID: 41, action: "ITEM_USE", contentID: "tea", revision: 3, authorityEpoch: 2,
                                         requestID: "pg-theme-abc12345", token: "player-token")
        XCTAssertEqual(answer, .refused)
        let other = await client.submit(activityID: 41, action: "PLAYER_CHOICE", contentID: "tea", revision: 3, authorityEpoch: nil,
                                        requestID: "pg-theme-abc12345", token: "player-token")
        XCTAssertEqual(other, .refused)
        XCTAssertTrue(transport.paths.isEmpty)
    }

    func testCommandClientKeepsUnknownOffTheSuccessPath() async throws {
        let transport = CommandWire()
        transport.body = #"{"code":200,"data":{"activityId":41,"requestId":"pg-theme-abc12345","action":"ITEM_USE","outcome":"PENDING","receiptId":9,"revision":4}}"#
        let config = try APIConfiguration(baseURL: XCTUnwrap(URL(string: "https://example.com/fixture/")))
        let service = PlayExperienceService(configuration: config, transport: transport, enabled: [.playerCommands])
        let client = PlayTeamItemCommandClient(service: service)
        let unknown = await client.submit(activityID: 41, action: "ITEM_USE", contentID: "tea", revision: 3, authorityEpoch: nil,
                                          requestID: "pg-theme-abc12345", token: "player-token")
        XCTAssertEqual(unknown, .unknown(requestID: "pg-theme-abc12345"))
        XCTAssertEqual(transport.paths, ["api/game/session/command"])
        transport.body = #"{"code":409,"msg":"Busy"}"#
        let business = await client.submit(activityID: 41, action: "ITEM_USE", contentID: "tea", revision: 3, authorityEpoch: nil,
                                           requestID: "pg-theme-abc12345", token: "player-token")
        XCTAssertEqual(business, .businessError(requestID: "pg-theme-abc12345", message: "Busy"))
    }

    private func wire(_ json: String) throws -> PlayWireValue {
        try JSONDecoder().decode(PlayWireValue.self, from: Data(json.utf8))
    }
}

@MainActor final class PlayTeamBackpackStateTests: XCTestCase {
    func testReadyAndUnknownReceipt() async throws {
        let raw = PlayWireValue.object([
            "scope": .string("TEAM"), "activityId": .int(41), "revision": .int(3),
            "availableActions": .array([.string("ITEM_USE")]),
            "contents": .array([.object(["kind": .string("ITEM"), "id": .string("tea"), "name": .string("Tea"), "stat": .string("hp"), "quantity": .int(1)])])
        ])
        let snapshot = try PlayTeamBackpackSnapshot(raw: raw, activityID: 41)
        let model = PlayTeamBackpackCoordinator(activityID: 41, reader: FixedTeamBackpack(snapshot), client: nil, token: { nil })
        await model.reload()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.items.map(\.id), ["tea"])
        model.present(.unknown(requestID: "pg-theme-unknown"))
        XCTAssertEqual(model.receipt.kind, .unknown)
        XCTAssertFalse(model.receipt.succeeded)
        XCTAssertEqual(model.receipt.receiptID, PlayTeamCommandInterpretation.dash)
        XCTAssertEqual(model.receipt.outcome, PlayTeamCommandInterpretation.dash)
    }

    func testEmptyAndPersonalScope() async throws {
        let empty = PlayWireValue.object(["scope": .string("TEAM"), "activityId": .int(41), "revision": .int(0), "contents": .array([])])
        let model = PlayTeamBackpackCoordinator(activityID: 41, reader: FixedTeamBackpack(try PlayTeamBackpackSnapshot(raw: empty, activityID: 41)), client: nil, token: { nil })
        await model.reload()
        XCTAssertEqual(model.phase, .empty)
        let personal = PlayWireValue.object(["scope": .string("PERSONAL"), "activityId": .int(41), "revision": .int(1)])
        XCTAssertThrowsError(try PlayTeamBackpackSnapshot(raw: personal, activityID: 41))
    }
}

private final class CommandWire: HTTPTransport {
    var paths: [String] = []
    var body = #"{"code":200,"data":{}}"#
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        paths.append(request.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? "")
        return (Data(body.utf8), 200)
    }
}

@MainActor private final class FixedTeamBackpack: PlayTeamBackpackReading {
    let snapshot: PlayTeamBackpackSnapshot
    init(_ snapshot: PlayTeamBackpackSnapshot) { self.snapshot = snapshot }
    func projection(activityID: Int) async throws -> PlayTeamBackpackSnapshot { snapshot }
}
