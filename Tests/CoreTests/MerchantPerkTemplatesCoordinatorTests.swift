#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@MainActor private final class PerkTestReader: CoopFlowReading {
    var session: CoopFlowSession?
    var list: [CoopFlowJSON] = []
    var listError: Error?
    var reads: [CoopFlowRead] = []
    init() throws { session = try CoopFlowSession(accountID: 7, epoch: 1, token: "synthetic") }
    func read(_ resource: CoopFlowRead) async throws -> CoopFlowJSON {
        reads.append(resource)
        if let listError { throw listError }
        return .array(list)
    }
    func settlement(source: CoopFlowSettlement.Source, id: Int) async throws -> CoopFlowSettlement { throw CoopFlowFailure.unavailable }
}

@MainActor private final class PerkTestExecutor: CoopFlowExecuting {
    var permits = true
    var operations: [CoopFlowMutation] = []
    var failure: Error?
    var onExecute: ((CoopFlowMutation) -> CoopFlowJSON)?
    func permitsDispatch(_ operation: CoopFlowMutation) -> Bool { permits }
    func execute(_ operation: CoopFlowMutation, session: CoopFlowSession) async throws -> CoopFlowJSON {
        operations.append(operation)
        if let failure { throw failure }
        return onExecute?(operation) ?? .object([:])
    }
}

private func perkRow(_ id: Int, name: String = "Synthetic perk", type: Int = 0, retail: Int = 10, quota: Int = 5) -> CoopFlowJSON {
    .object(["id": .id(id), "name": .string(name), "perkType": .id(type), "retailValue": .number(Decimal(retail)),
             "unitCost": .null, "quota": .id(quota), "validEnd": .null])
}

@available(macOS 14.0, *)
@MainActor final class MerchantPerkTemplatesCoordinatorTests: XCTestCase {
    private func draft() -> MerchantPerkTemplateDraft {
        var value = MerchantPerkTemplateDraft()
        value.typeIndex = 1; value.name = "  Two coffees "; value.retailValue = "36.50"; value.unitCost = "12"
        value.quota = "20"; value.validEnd = "2100-01-01"
        return value
    }

    func testLoadReadsTemplateListAndFlagsUnusableRows() async throws {
        let reader = try PerkTestReader()
        reader.list = [perkRow(1), perkRow(2, quota: 0)]
        let model = MerchantPerkTemplatesCoordinator(reader: reader, executor: nil)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(reader.reads, [.templates])
        XCTAssertEqual(model.rows.map(\.id), [1, 2])
        XCTAssertTrue(model.rows[0].usable)
        XCTAssertFalse(model.rows[1].usable)
    }

    func testPermissionRefusalAndFailureAreDistinctRetryableStates() async throws {
        let reader = try PerkTestReader()
        let model = MerchantPerkTemplatesCoordinator(reader: reader, executor: nil)
        reader.listError = CoopFlowFailure.server(403, nil)
        await model.load()
        XCTAssertEqual(model.phase, .permissionDenied)
        reader.listError = CoopFlowFailure.server(500, nil)
        await model.load()
        XCTAssertEqual(model.phase, .failed)
        reader.listError = nil; reader.list = []
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertTrue(model.rows.isEmpty)
    }

    func testMalformedRowFailsClosedInsteadOfShowingPartialList() async throws {
        let reader = try PerkTestReader()
        reader.list = [perkRow(1), .object(["id": .id(2)])]
        let model = MerchantPerkTemplatesCoordinator(reader: reader, executor: nil)
        await model.load()
        XCTAssertEqual(model.phase, .failed)
        XCTAssertTrue(model.rows.isEmpty)
    }

    func testSaveSendsSourceShapedBodyAndShowsSavedOnlyAfterListConfirmsIt() async throws {
        let reader = try PerkTestReader()
        let executor = PerkTestExecutor()
        executor.onExecute = { _ in reader.list = [perkRow(9, name: "Two coffees", type: 1, retail: 36, quota: 20)]; return .object(["id": .id(9)]) }
        let model = MerchantPerkTemplatesCoordinator(reader: reader, executor: executor)
        await model.load()
        await model.save(draft())
        XCTAssertEqual(executor.operations.count, 1)
        guard case .createTemplate(let template) = executor.operations[0] else { return XCTFail("expected createTemplate") }
        XCTAssertEqual(template.name, "Two coffees"); XCTAssertEqual(template.type, 1)
        XCTAssertEqual(template.quota, 20); XCTAssertEqual(template.validEnd, "2100-01-01")
        let body = try executor.operations[0].body()
        XCTAssertEqual(body["perkType"].integer, 1); XCTAssertEqual(body["quota"].integer, 20)
        XCTAssertEqual(body["name"].text, "Two coffees"); XCTAssertEqual(body["validEnd"].text, "2100-01-01")
        XCTAssertEqual(executor.operations[0].path, "api/coop/perk-template/save")
        XCTAssertEqual(model.action, .saved)
        XCTAssertEqual(model.rows.map(\.id), [9])
    }

    func testSaveAcknowledgedButMissingFromListIsUnconfirmedNotSaved() async throws {
        let reader = try PerkTestReader()
        let executor = PerkTestExecutor()
        executor.onExecute = { _ in .object(["id": .id(9)]) }
        let model = MerchantPerkTemplatesCoordinator(reader: reader, executor: executor)
        await model.load()
        await model.save(draft())
        XCTAssertEqual(model.action, .unconfirmed)
    }

    func testGatedWriteIsHonestlyUnavailableAndNeverExecutes() async throws {
        let reader = try PerkTestReader()
        let executor = PerkTestExecutor(); executor.permits = false
        let model = MerchantPerkTemplatesCoordinator(reader: reader, executor: executor)
        await model.load()
        await model.save(draft())
        XCTAssertEqual(model.action, .notAvailableYet)
        await model.delete(id: 4)
        XCTAssertEqual(model.action, .notAvailableYet)
        XCTAssertTrue(executor.operations.isEmpty)
        let unwired = MerchantPerkTemplatesCoordinator(reader: reader, executor: nil)
        await unwired.save(draft())
        XCTAssertEqual(unwired.action, .notAvailableYet)
    }

    func testInvalidDraftNeverReachesTheExecutor() async throws {
        let reader = try PerkTestReader()
        let executor = PerkTestExecutor()
        let model = MerchantPerkTemplatesCoordinator(reader: reader, executor: executor)
        var bad = draft(); bad.retailValue = "1.234"
        XCTAssertFalse(bad.canSave)
        await model.save(bad)
        XCTAssertEqual(model.action, .invalid)
        bad = draft(); bad.quota = "0"; XCTAssertFalse(bad.canSave)
        bad = draft(); bad.name = "   "; XCTAssertFalse(bad.canSave)
        bad = draft(); bad.validEnd = "2000-01-01"
        await model.save(bad)
        XCTAssertEqual(model.action, .invalid)
        XCTAssertTrue(executor.operations.isEmpty)
    }

    func testDeleteSendsIdAndConfirmsByRefreshedList() async throws {
        let reader = try PerkTestReader()
        reader.list = [perkRow(4), perkRow(5)]
        let executor = PerkTestExecutor()
        executor.onExecute = { _ in reader.list = [perkRow(5)]; return .object([:]) }
        let model = MerchantPerkTemplatesCoordinator(reader: reader, executor: executor)
        await model.load()
        await model.delete(id: 4)
        XCTAssertEqual(executor.operations, [.deleteTemplate(id: 4)])
        XCTAssertEqual(executor.operations[0].path, "api/coop/perk-template/delete")
        XCTAssertEqual(try executor.operations[0].body()["id"].integer, 4)
        XCTAssertEqual(model.action, .deleted)
        XCTAssertEqual(model.rows.map(\.id), [5])
    }

    func testServerRejectionOnDeleteKeepsListAndReportsFailure() async throws {
        let reader = try PerkTestReader()
        reader.list = [perkRow(4)]
        let executor = PerkTestExecutor(); executor.failure = CoopFlowFailure.server(500, "boom")
        let model = MerchantPerkTemplatesCoordinator(reader: reader, executor: executor)
        await model.load()
        await model.delete(id: 4)
        XCTAssertEqual(model.action, .failed)
        XCTAssertEqual(model.rows.map(\.id), [4])
        executor.failure = CoopFlowFailure.permission
        await model.delete(id: 4)
        XCTAssertEqual(model.action, .permissionDenied)
    }
}
#endif
