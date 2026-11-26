import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor final class CharacterCardPageReadTests: XCTestCase {
    func testBlankPhasesAndWireStatsNeverTurnUnknownIntoZero() {
        let dash = CharacterCardPageModel.unknownStat
        for phase in [CharacterCardPageModel.Phase.loading, .empty, .error, .unknown, .ready] {
            let model = CharacterCardPageModel(phase)
            XCTAssertEqual(model.attributeCountText, dash)
            XCTAssertNotEqual(model.attributeCountText, "0")
            XCTAssertEqual(model.breakdownTotalText, dash)
            XCTAssertEqual(model.breakdownDieText, dash)
            XCTAssertEqual(model.momentumText, dash)
            XCTAssertTrue(model.attributeValueTexts.isEmpty)
            XCTAssertTrue(model.equipmentQuantityTexts.isEmpty)
        }
        XCTAssertEqual(CharacterCardPageModel(.ready).phase, .unknown)
        XCTAssertEqual(CharacterCardPageModel.statText(.int(0)), "0")
        XCTAssertEqual(CharacterCardPageModel.statText(.null), dash)
        XCTAssertEqual(CharacterCardPageModel.statText(.string("0")), dash)
        XCTAssertEqual(CharacterCardPageModel.statText(.string("UNKNOWN")), dash)
        XCTAssertEqual(CharacterCardPageModel.statText(nil), dash)
        XCTAssertEqual(CharacterCardPageModel.percentText(value: 0, min: 0, max: 20), "0")
        XCTAssertEqual(CharacterCardPageModel.percentText(value: 0, min: 0, max: 0), dash)
        XCTAssertEqual(CharacterCardReadRoute.paths, ["api/play/character", "api/play/rpg/status"])
        XCTAssertFalse(PlayWriteAvailability.current(for: .characterSheetSave).isAvailable)
    }

    func testLiteralZeroStaysZeroAndStatusSheetDoesNotInventARoute() async throws {
        let transport = Transport()
        transport.card = card(attributes: [
            attribute(key: "counter.str", value: 0, min: 0, max: 20),
            attribute(key: "counter.point", value: 0, min: 0, max: 0)
        ], definitionSource: .string("UNKNOWN"), inventory: true)
        transport.status = .object([
            "topicId": .int(71),
            "definitionSource": .string("  SESSION_SNAPSHOT_V1  "),
            "rpg": .object(["enabled": .bool(true), "momentum": .int(0), "momentumMax": .int(6)])
        ])
        let model = try make(transport, activityID: 41)
        XCTAssertEqual(model.pageModel.phase, .loading)
        XCTAssertEqual(model.pageModel.attributeCountText, "—")
        await model.load()
        let page = model.pageModel
        XCTAssertEqual(page.phase, .ready)
        XCTAssertEqual(page.attributeCountText, "2")
        XCTAssertEqual(page.attributeValueTexts, ["0", "0"])
        XCTAssertEqual(page.attributePercentTexts, ["0", "—"])
        XCTAssertEqual(page.momentumText, "0")
        XCTAssertEqual(page.equipmentQuantityTexts, ["0", "—"])
        XCTAssertEqual(page.breakdownTotalText, "—")
        XCTAssertEqual(page.breakdownDieText, "—")
        XCTAssertEqual(model.card?.rpgSheet?.momentum?.value, 0)
        XCTAssertEqual(model.card?.definitionSource, "SESSION_SNAPSHOT_V1")
        XCTAssertNotEqual(model.card?.definitionSource, "UNKNOWN")
        model.acceptBreakdown(.object(["total": .int(0)]))
        XCTAssertEqual(model.pageModel.breakdownTotalText, "0")
        XCTAssertEqual(model.pageModel.breakdownDieText, "—")
        XCTAssertNil(model.card?.breakdown.die)
        model.acceptBreakdown(.object(["total": .string("0")]))
        XCTAssertNil(model.card?.breakdown.total)
        XCTAssertEqual(model.pageModel.breakdownTotalText, "—")
        XCTAssertNotEqual(model.pageModel.breakdownTotalText, "0")
        // rpg/status without a party falls back to the read-only PLAYER projection (game/session/view since 6adbae522).
        XCTAssertEqual(transport.requests.map { $0.url?.path }, ["/api/play/character", "/api/play/rpg/status", "/api/game/session/view"])
        XCTAssertTrue(transport.requests.allSatisfy { $0.httpMethod == "GET" && $0.httpBody == nil })
        XCTAssertFalse(PlayWriteAvailability.current(for: .characterSheetSave).isAvailable)
    }

    func testEmptyErrorAndUnknownStayDistinctFromALiteralZero() async throws {
        let dash = CharacterCardPageModel.unknownStat
        let emptyTransport = Transport()
        emptyTransport.card = card(attributes: [], definitionSource: .string("   "), inventory: false)
        let empty = try make(emptyTransport, activityID: nil)
        await empty.load()
        XCTAssertEqual(empty.pageModel.phase, .empty)
        XCTAssertEqual(empty.pageModel.attributeCountText, "0")
        XCTAssertTrue(empty.pageModel.attributeValueTexts.isEmpty)
        XCTAssertEqual(empty.pageModel.momentumText, dash)
        XCTAssertNil(empty.card?.definitionSource)
        XCTAssertEqual(empty.availability, .ready)

        let malformedTransport = Transport()
        malformedTransport.card = .object(["topicId": .int(71)])
        let malformed = try make(malformedTransport, activityID: nil)
        await malformed.load()
        XCTAssertEqual(malformed.availability, .unknown)
        XCTAssertEqual(malformed.pageModel.phase, .unknown)
        XCTAssertNil(malformed.card)
        XCTAssertEqual(malformed.pageModel.attributeCountText, dash)
        XCTAssertNotEqual(malformed.pageModel.attributeCountText, "0")

        let numericTransport = Transport()
        numericTransport.card = card(attributes: [
            attribute(key: "counter.str", valueWire: .string("0"), min: 0, max: 20)
        ], definitionSource: nil, inventory: false)
        let numeric = try make(numericTransport, activityID: nil)
        await numeric.load()
        XCTAssertEqual(numeric.pageModel.phase, .unknown)
        XCTAssertNil(numeric.card)
        XCTAssertEqual(numeric.pageModel.attributeValueTexts, [])
        XCTAssertNotEqual(numeric.pageModel.attributeCountText, "0")

        let failedTransport = Transport()
        failedTransport.failure = .network
        let failed = try make(failedTransport, activityID: nil)
        await failed.load()
        XCTAssertEqual(failed.pageModel.phase, .error)
        XCTAssertEqual(failed.availability, .unknown)
        XCTAssertEqual(failed.pageModel.momentumText, dash)

        let deniedTransport = Transport()
        deniedTransport.failure = .unauthorized
        let denied = try make(deniedTransport, activityID: nil)
        await denied.load()
        XCTAssertEqual(denied.pageModel.phase, .error)
        XCTAssertNil(denied.card)
        XCTAssertEqual(denied.pageModel.attributeCountText, dash)

        let owner = try Owner()
        let staleTransport = Transport()
        staleTransport.card = card(attributes: [attribute(key: "counter.str", value: 0, min: 0, max: 5)], definitionSource: nil, inventory: false)
        let stale = try make(staleTransport, activityID: nil, owner: owner)
        await stale.load()
        XCTAssertEqual(stale.pageModel.phase, .ready)
        XCTAssertEqual(stale.pageModel.attributeValueTexts, ["0"])
        owner.value = try PlayExperienceSession(accountID: 8, epoch: 1, namespace: "synthetic", token: "synthetic-token")
        await stale.load()
        XCTAssertEqual(stale.availability, .unknown)
        XCTAssertEqual(stale.pageModel.phase, .error)
        XCTAssertNil(stale.card)
        XCTAssertEqual(stale.pageModel.attributeCountText, dash)
    }

    func testSignedOutReaderSurfacesSignInAndReadsAgainWhenTheSessionReturns() async throws {
        let owner = try Owner()
        let transport = Transport()
        transport.card = card(attributes: [attribute(key: "counter.str", value: 5, min: 0, max: 20)], definitionSource: nil, inventory: false)
        owner.value = nil
        let model = try make(transport, activityID: nil, owner: owner)
        await model.load()
        XCTAssertEqual(model.issue, .unauthorized)
        XCTAssertNil(model.card)
        XCTAssertEqual(model.pageModel.phase, .error)
        XCTAssertNotEqual(model.pageModel.phase, .empty)
        XCTAssertEqual(model.pageModel.attributeCountText, "—")
        XCTAssertNotEqual(model.pageModel.attributeCountText, "0")
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertNil(model.cardIfCurrent())
        XCTAssertEqual(model.issue, .unauthorized)
        XCTAssertFalse(model.isCurrent)

        owner.value = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: "synthetic", token: "synthetic-token")
        await model.load()
        XCTAssertNil(model.issue)
        XCTAssertEqual(model.pageModel.phase, .ready)
        XCTAssertEqual(model.card?.attributes.first?.value, 5)
        XCTAssertEqual(transport.requests.map { $0.url?.path }, ["/api/play/character"])
        XCTAssertTrue(transport.requests.allSatisfy { $0.httpMethod == "GET" })
    }

    func testFailedRefreshKeepsTheLastCardAndDoesNotBecomeAnEmptySuccess() async throws {
        let transport = Transport()
        transport.card = card(attributes: [attribute(key: "counter.str", value: 5, min: 0, max: 20)], definitionSource: nil, inventory: false)
        let model = try make(transport, activityID: nil)
        await model.load()
        XCTAssertEqual(model.pageModel.phase, .ready)
        XCTAssertEqual(model.pageModel.attributeValueTexts, ["5"])
        let reads = transport.requests.count

        transport.failure = .network
        await model.load()
        XCTAssertEqual(model.issue, .unknownResult)
        XCTAssertEqual(model.availability, .ready)
        XCTAssertEqual(model.card?.attributes.first?.value, 5)
        XCTAssertEqual(model.pageModel.phase, .ready)
        XCTAssertEqual(model.pageModel.attributeValueTexts, ["5"])
        XCTAssertNotEqual(model.pageModel.phase, .empty)
        XCTAssertNotEqual(model.pageModel.phase, .unknown)
        XCTAssertNotEqual(model.pageModel.attributeCountText, "0")
        XCTAssertNotEqual(model.pageModel.attributeCountText, "—")
        XCTAssertEqual(transport.requests.map { $0.url?.path }, Array(repeating: "/api/play/character", count: reads + 1))

        transport.failure = nil
        transport.card = .object(["topicId": .int(71)])
        await model.load()
        XCTAssertEqual(model.issue, .malformed)
        XCTAssertEqual(model.availability, .ready)
        XCTAssertEqual(model.card?.attributes.first?.value, 5)
        XCTAssertEqual(model.pageModel.phase, .ready)
        XCTAssertEqual(model.pageModel.attributeValueTexts, ["5"])
        XCTAssertNotEqual(model.pageModel.phase, .unknown)
        XCTAssertNotEqual(model.pageModel.phase, .empty)

        transport.card = card(attributes: [], definitionSource: nil, inventory: false)
        await model.load()
        XCTAssertNil(model.issue)
        XCTAssertEqual(model.pageModel.phase, .empty)
        XCTAssertTrue(model.card?.attributes.isEmpty == true)
    }

    func testUnauthorizedRefreshClearsTheCardInsteadOfAnEmptySuccess() async throws {
        let transport = Transport()
        transport.card = card(attributes: [attribute(key: "counter.str", value: 5, min: 0, max: 20)], definitionSource: nil, inventory: false)
        let owner = try Owner()
        let model = try make(transport, activityID: nil, owner: owner)
        await model.load()
        transport.failure = .unauthorized
        await model.load()
        XCTAssertNil(model.card)
        XCTAssertEqual(model.issue, .unauthorized)
        XCTAssertFalse(model.isCurrent)
        XCTAssertEqual(model.pageModel.phase, .error)
        XCTAssertEqual(model.pageModel.attributeCountText, "—")
        XCTAssertNotEqual(model.pageModel.phase, .empty)
        XCTAssertNotEqual(model.pageModel.attributeCountText, "0")
        XCTAssertEqual(Set(transport.requests.map { $0.url?.path ?? "" }), ["/api/play/character"])

        transport.failure = nil
        await model.load()
        XCTAssertNil(model.issue)
        XCTAssertEqual(model.pageModel.phase, .ready)
        XCTAssertEqual(model.card?.attributes.first?.value, 5)
    }

    private func attribute(key: String, value: Int, min: Int, max: Int) -> PlayWireValue {
        attribute(key: key, valueWire: .int(value), min: min, max: max)
    }

    private func attribute(key: String, valueWire: PlayWireValue, min: Int, max: Int) -> PlayWireValue {
        .object(["stateKey": .string(key), "label": .string(key), "value": valueWire,
                 "min": .int(min), "max": .int(max), "displayType": .string("bar"), "persistScope": .string("run")])
    }

    private func card(attributes: [PlayWireValue], definitionSource: PlayWireValue?, inventory: Bool) -> PlayWireValue {
        var root: [String: PlayWireValue] = [
            "topicId": .int(71), "created": .bool(true), "running": .bool(false),
            "attributes": .array(attributes),
            "rpg": .object(["enabled": .bool(true)])
        ]
        if let definitionSource { root["definitionSource"] = definitionSource }
        if inventory {
            root["inventory"] = .object([
                "lantern": .object(["quantity": .int(0), "status": .string("VALID")]),
                "map": .object(["status": .string("VALID")])
            ])
        }
        return .object(root)
    }

    private func make(_ transport: Transport, activityID: Int?, owner: Owner? = nil) throws -> CharacterCardReadback {
        let owner = try owner ?? Owner()
        let service = PlayExperienceService(configuration: try .init(baseURL: URL(string: "https://example.test")!),
                                            transport: transport, enabled: [.reads])
        return try XCTUnwrap(CharacterCardReadback(topicID: 71, activityID: activityID, service: service,
                                                   currentSession: { owner.value }))
    }
}

@MainActor private final class Owner {
    var value: PlayExperienceSession?
    init() throws { value = try .init(accountID: 7, epoch: 1, namespace: "synthetic", token: "synthetic-token") }
}

private final class Transport: HTTPTransport {
    enum Failure { case network, unauthorized }
    @MainActor var requests: [URLRequest] = []
    @MainActor var card: PlayWireValue = .null
    @MainActor var status: PlayWireValue = .null
    @MainActor var failure: Failure?
    func send(_ request: URLRequest) async throws -> (Data, Int) { try await execute(request) }
    @MainActor private func execute(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if failure == .network { throw URLError(.networkConnectionLost) }
        if failure == .unauthorized {
            return (try JSONEncoder().encode(PlayWireValue.object(["code": .int(401), "data": .null])), 200)
        }
        let path = request.url?.path ?? ""
        let data: PlayWireValue
        switch path {
        case "/api/play/character": data = card
        case "/api/play/rpg/status": data = status == .null ? card : status
        default: throw APIError.invalidRequest
        }
        return (try JSONEncoder().encode(PlayWireValue.object(["code": .int(200), "data": data])), 200)
    }
}
