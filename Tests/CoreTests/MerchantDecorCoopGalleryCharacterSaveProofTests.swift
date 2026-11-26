#if canImport(QuestifyCore)
import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Proof tests for pages/merchant/decor/coop-setting, pages/merchant/decor/gallery and
/// pages/merchant/decor/ai-npc: each main save goes through the injected Core service with
/// a fake transport, sends the exact source route/body, and only reports success after the
/// fake server acknowledges with code 200. No real host is used.
private final class DecorProofTransport: HTTPTransport {
    var saveReply = #"{"code":200,"msg":"Synthetic saved"}"#
    private(set) var requests: [URLRequest] = []
    private let access = #"{"code":200,"data":{"active":true,"merchant":{"id":31},"roleCode":"MERCHANT_OWNER","permissions":["merchant:profile:write","merchant:coop:manage"]}}"#
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let path = request.url?.path ?? ""
        if path.hasSuffix("/api/merchant/access/me") { return (Data(access.utf8), 200) }
        if path.hasSuffix("/api/merchant/coop-profile/save") || path.hasSuffix("/api/merchant/decor/save") { return (Data(saveReply.utf8), 200) }
        if path.hasSuffix("/api/merchant/coop-profile") {
            return (Data(("{\"code\":200,\"data\":" + MerchantOperationsFixtureData.storeJSON + "}").utf8), 200)
        }
        return (Data(#"{"code":404}"#.utf8), 404)
    }
    func writes(_ suffix: String) -> [URLRequest] { requests.filter { $0.url?.path.hasSuffix(suffix) == true } }
}

@MainActor private final class DecorProofJournal: OperationPendingJournal {
    var record: OperationPendingRecord?
    func pending(ownerKey: String, targetKey: String) throws -> OperationPendingRecord? { record }
    func write(_ record: OperationPendingRecord) throws { self.record = record }
    func clear(_ record: OperationPendingRecord) throws { self.record = nil }
}

@MainActor final class MerchantDecorCoopGallerySaveProofTests: XCTestCase {
    private func reader(_ transport: DecorProofTransport, paths: Set<String>) throws -> (MerchantOperationsSessionReader, DecorProofJournal) {
        let config = try APIConfiguration(baseURL: URL(string: "https://example.test/prod-api")!)
        let session = try MerchantOperationsSession(accountID: 7, epoch: 1, token: "synthetic-token", storageNamespace: "decor-proof")
        let approval = try OperationEndpointApproval(baseURL: config.baseURL, namespace: session.storageNamespace, accountID: session.accountID, paths: paths)
        let journal = DecorProofJournal()
        let reader = MerchantOperationsSessionReader(service: MerchantOperationsService(configuration: config, transport: transport),
                                                     currentSession: { session }, approval: approval, journal: journal)
        return (reader, journal)
    }
    private func body(_ request: URLRequest?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request?.httpBody)) as? [String: Any])
    }

    func testCoopSettingSaveSendsExactCoopProfileRouteAndAcknowledgesOnlyAfterServerOK() async throws {
        let transport = DecorProofTransport()
        let (reader, journal) = try reader(transport, paths: ["api/merchant/coop-profile/save"])
        let owner = MerchantOperationsCoordinator(reader: reader, destination: .cooperation)
        await owner.load()
        guard case .cooperation(var value) = owner.draft else { return XCTFail("Expected cooperation draft") }
        XCTAssertTrue(transport.writes("/api/merchant/coop-profile/save").isEmpty)
        value.demand = "Edited synthetic demand"; owner.edit(.cooperation(value)); owner.prepare()
        let review = try XCTUnwrap(owner.confirmation)
        XCTAssertTrue(transport.writes("/api/merchant/coop-profile/save").isEmpty)
        await owner.confirm(review)
        let saves = transport.writes("/api/merchant/coop-profile/save")
        XCTAssertEqual(saves.count, 1)
        XCTAssertEqual(saves.first?.url?.path, "/prod-api/api/merchant/coop-profile/save")
        XCTAssertEqual(saves.first?.httpMethod, "POST")
        XCTAssertEqual(saves.first?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let fields = try body(saves.first)
        XCTAssertEqual(Set(fields.keys), ["capacity", "availableTime", "chargeType", "demand", "suitActivityTypes", "coopOpen"])
        XCTAssertEqual(fields["demand"] as? String, "Edited synthetic demand")
        XCTAssertEqual(fields["suitActivityTypes"] as? String, "walk;workshop")
        XCTAssertEqual(fields["coopOpen"] as? Int, 1)
        XCTAssertEqual(owner.issue, .key("merchant.operations.acknowledged"))
        XCTAssertFalse(owner.isLocked); XCTAssertFalse(owner.isDirty); XCTAssertNil(journal.record)
        // The frozen review cannot be replayed.
        await owner.confirm(review)
        XCTAssertEqual(transport.writes("/api/merchant/coop-profile/save").count, 1)
    }

    func testCoopSettingServerRejectionIsNotReportedAsSaved() async throws {
        let transport = DecorProofTransport(); transport.saveReply = #"{"code":422,"msg":"Synthetic rejection"}"#
        let (reader, journal) = try reader(transport, paths: ["api/merchant/coop-profile/save"])
        let owner = MerchantOperationsCoordinator(reader: reader, destination: .cooperation)
        await owner.load()
        guard case .cooperation(var value) = owner.draft else { return XCTFail("Expected cooperation draft") }
        value.demand = "Rejected synthetic demand"; owner.edit(.cooperation(value)); owner.prepare()
        await owner.confirm(try XCTUnwrap(owner.confirmation))
        XCTAssertEqual(transport.writes("/api/merchant/coop-profile/save").count, 1)
        XCTAssertEqual(owner.issue, .server("Synthetic rejection"))
        XCTAssertTrue(owner.isDirty); XCTAssertFalse(owner.isLocked); XCTAssertNil(journal.record)
    }

    func testGallerySavePatchesOnlyGalleryOnDecorRouteAfterServerOK() async throws {
        let transport = DecorProofTransport()
        let (reader, journal) = try reader(transport, paths: ["api/merchant/decor/save"])
        let owner = MerchantOperationsCoordinator(reader: reader, destination: .gallery)
        await owner.load()
        guard case .gallery(var value) = owner.draft else { return XCTFail("Expected gallery draft") }
        XCTAssertEqual(value.gallery, ["synthetic-gallery-1", "synthetic-gallery-2"])
        value.gallery = ["synthetic-gallery-2"]; owner.edit(.gallery(value)); owner.prepare()
        let review = try XCTUnwrap(owner.confirmation)
        XCTAssertTrue(transport.writes("/api/merchant/decor/save").isEmpty)
        await owner.confirm(review)
        let saves = transport.writes("/api/merchant/decor/save")
        XCTAssertEqual(saves.count, 1)
        XCTAssertEqual(saves.first?.url?.path, "/prod-api/api/merchant/decor/save")
        let fields = try body(saves.first)
        XCTAssertEqual(Set(fields.keys), ["gallery"])
        XCTAssertEqual(fields["gallery"] as? String, try MerchantStoreDecor.listString(["synthetic-gallery-2"]))
        XCTAssertEqual(owner.issue, .key("merchant.operations.acknowledged"))
        XCTAssertFalse(owner.isLocked); XCTAssertFalse(owner.isDirty); XCTAssertNil(journal.record)
    }

    func testGalleryWithoutApprovedRouteSendsNoWrite() async throws {
        // 4d89b402f (owner, merchant-coop non-money writes on): decor/save is admitted for any approval bound to this
        // base URL, namespace and account. An approval issued for another account approves no route here: no write.
        let transport = DecorProofTransport()
        let config = try APIConfiguration(baseURL: URL(string: "https://example.test/prod-api")!)
        let session = try MerchantOperationsSession(accountID: 7, epoch: 1, token: "synthetic-token", storageNamespace: "decor-proof")
        let foreign = try OperationEndpointApproval(baseURL: config.baseURL, namespace: session.storageNamespace, accountID: 8, paths: ["api/merchant/decor/save"])
        let reader = MerchantOperationsSessionReader(service: MerchantOperationsService(configuration: config, transport: transport),
                                                     currentSession: { session }, approval: foreign, journal: DecorProofJournal())
        let owner = MerchantOperationsCoordinator(reader: reader, destination: .gallery)
        await owner.load()
        guard case .gallery(var value) = owner.draft else { return XCTFail("Expected gallery draft") }
        value.gallery = []; owner.edit(.gallery(value)); owner.prepare()
        await owner.confirm(try XCTUnwrap(owner.confirmation))
        XCTAssertTrue(transport.writes("/api/merchant/decor/save").isEmpty)
        XCTAssertNotEqual(owner.issue, .key("merchant.operations.acknowledged"))
    }
}

@MainActor private final class CharacterProofTransport: HTTPTransport {
    var replies: [String: String] = [:]
    private(set) var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let path = String((request.url?.path ?? "").drop(while: { $0 == "/" }))
        guard let reply = replies[path] else { return (Data(#"{"code":404}"#.utf8), 404) }
        return (Data(reply.utf8), 200)
    }
}

@MainActor final class MerchantStoreCharacterSaveProofTests: XCTestCase {
    private let access = #"{"code":200,"data":{"active":true,"merchant":{"id":31,"name":"Sample"},"roleCode":"MERCHANT_OWNER","permissions":["merchant:profile:write"]}}"#
    private var saveGates: MerchantCityNPCParityGates { var g = MerchantCityNPCParityGates(); g.storeCharacterSaves = true; return g }
    private func coordinator(_ transport: CharacterProofTransport) throws -> StoreCharacterCoordinator {
        let configuration = try APIConfiguration(baseURL: URL(string: "https://example.com/")!)
        let scope = UUID()
        let backend = StoreCharacterServiceBackend(service: StoreCharacterService(configuration: configuration, transport: transport), market: .china,
                                                   gates: saveGates, execution: .injectedOfflineHarness, token: { "synthetic-token" }, currentScope: { scope })
        return StoreCharacterCoordinator(reader: backend, writer: backend, gates: saveGates)
    }
    private func transport(save: String) -> CharacterProofTransport {
        let transport = CharacterProofTransport()
        transport.replies[StoreCharacterEndpoint.access] = access
        transport.replies[StoreCharacterEndpoint.profile] = #"{"code":200,"data":{"name":"Host","avatar":"px1:p01","greeting":"Hi","auditStatus":1}}"#
        transport.replies[StoreCharacterEndpoint.voiceStatus] = #"{"code":200,"voiceStatus":0}"#
        transport.replies[StoreCharacterEndpoint.save] = save
        return transport
    }
    private func saves(_ transport: CharacterProofTransport) -> [URLRequest] {
        transport.requests.filter { $0.url?.path == "/api/merchant/npc/save" }
    }

    func testFieldSaveSendsExactNPCSaveBodyAndShowsSavedOnlyAfterServerOK() async throws {
        let transport = transport(save: #"{"code":200,"msg":"ok"}"#)
        let coordinator = try coordinator(transport)
        await coordinator.load()
        XCTAssertEqual(coordinator.phase, .ready)
        coordinator.editField(.knowledge); coordinator.updateField(" Menu "); coordinator.saveField()
        let confirmation = try XCTUnwrap(coordinator.saveConfirmation)
        XCTAssertTrue(saves(transport).isEmpty); XCTAssertNotEqual(coordinator.notice, .saved)
        await coordinator.confirmSave(confirmation.id)
        let requests = saves(transport)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.httpMethod, "POST")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests.first?.httpBody)) as? [String: String])
        XCTAssertEqual(body, ["name": "Host", "greeting": "Hi", "persona": "", "knowledge": "Menu", "avatar": "px1:p01"])
        XCTAssertEqual(coordinator.notice, .saved)
        XCTAssertNil(coordinator.saveIssue); XCTAssertFalse(coordinator.saveLocked)
        XCTAssertEqual(coordinator.saved.knowledge, "Menu")
    }

    func testFieldSaveServerRejectionDoesNotShowSaved() async throws {
        let transport = transport(save: #"{"code":500,"msg":"Sample rejection"}"#)
        let coordinator = try coordinator(transport)
        await coordinator.load()
        coordinator.editField(.knowledge); coordinator.updateField("Menu"); coordinator.saveField()
        await coordinator.confirmSave(try XCTUnwrap(coordinator.saveConfirmation).id)
        XCTAssertEqual(saves(transport).count, 1)
        XCTAssertNotEqual(coordinator.notice, .saved)
        XCTAssertEqual(coordinator.saveIssue, .rejected("Sample rejection"))
        XCTAssertEqual(coordinator.saved.knowledge, "")
    }
}

/// W5b: the shipped session reader has no approval/journal, so the editor shows the unavailable notice
/// and the save confirmation stays disabled (coop-setting, decor, gallery).
@MainActor final class MerchantOperationsReaderShippedGateTests: XCTestCase {
    func testReaderWithoutApprovalAndJournalCannotSave() {
        let reader = MerchantOperationsSessionReader(service: nil, currentSession: { nil })
        XCTAssertFalse(reader.canSave)
        XCTAssertFalse(reader.isOfflineExample)
        XCTAssertFalse(reader.isAuthenticated)
    }
}
#endif
