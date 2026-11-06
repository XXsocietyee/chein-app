import XCTest
@testable import QuestifyCore

@MainActor final class ModInstallationQaTests: XCTestCase {
    // Actual QmodTopicCompiler output of the original R2 synthetic fixture; no real user content.
    private let graph = #"{"adapter":"r2-native-qa-pick-topic-1","description":"合成数据，不代表已发布内容","guide":"QMOD source / r2-native-qa-pick-topic-1\nsourceManifestHash=1d60d3db7988d1740594bcb2976924bedbdb33bc0d97c81c92b27de21c783757\ncontent.json bytes=769 sha256=cd78b2c28caea6fde4ac3b3fe2b45b72acca604acdb2564f86bb5b7cc75e2221\nzh-Hans.json bytes=281 sha256=ed0504c3fc5353cb7289e7555f4ba75088e1bdf8e6df04175bce5b04ff58abb3","locale":"zh-Hans","nodes":[{"advancedConfigJson":"{\"schemaVersion\":1,\"qa\":{\"enabled\":true,\"mode\":\"PICK\",\"title\":\"选择正确答案\",\"options\":[{\"id\":\"a\",\"label\":\"甲\",\"correct\":true},{\"id\":\"b\",\"label\":\"乙\",\"correct\":false}]}}","body":"选择正确答案","sourceNodeId":"intro","sourceType":"ADVANCED_GAME","title":"开始"},{"advancedConfigJson":"{\"branch\":{\"enabled\":true,\"startStepId\":\"__entry\",\"steps\":[{\"body\":\"\",\"id\":\"__entry\",\"options\":[{\"id\":\"left\",\"label\":\"左边\",\"nextStepId\":\"__result_0\"},{\"id\":\"right\",\"label\":\"右边\",\"nextStepId\":\"__result_1\"}],\"terminal\":false,\"title\":\"选择路线\"},{\"body\":\"\",\"id\":\"__result_0\",\"options\":[],\"outcomeCode\":\"left\",\"outcomeLabel\":\"左边\",\"terminal\":true,\"title\":\"左边\"},{\"body\":\"\",\"id\":\"__result_1\",\"options\":[],\"outcomeCode\":\"right\",\"outcomeLabel\":\"右边\",\"terminal\":true,\"title\":\"右边\"}]},\"schemaVersion\":1}","body":"","choices":[{"id":"left","label":"左边","next":"end"},{"id":"right","label":"右边","next":"end"}],"fallbackChoiceId":"left","sourceNodeId":"choice","sourceType":"CHOICE","title":"选择路线"},{"advancedConfigJson":"{\"branch\":{\"enabled\":true,\"startStepId\":\"__entry\",\"steps\":[{\"body\":\"本段结束。\",\"id\":\"__entry\",\"options\":[],\"outcomeCode\":\"COMPLETED\",\"outcomeLabel\":\"结束\",\"terminal\":true,\"title\":\"结束\"}]},\"schemaVersion\":1}","body":"本段结束。","sourceNodeId":"end","sourceType":"END","title":"结束"}],"route":{"edges":[{"conditions":[],"effects":[],"fromNodeKey":"intro","id":"intro.next","maxVisits":1,"once":true,"priority":0,"toNodeKey":"choice","trigger":{"outcomeCode":"COMPLETED","type":"CHOICE"},"weight":1},{"effects":[],"id":"choice.left","trigger":{"outcomeCode":"left","type":"ADVANCED_RESULT"},"priority":0,"maxVisits":1,"fromNodeKey":"choice","once":true,"conditions":[],"toNodeKey":"end","weight":1},{"effects":[],"id":"choice.right","trigger":{"outcomeCode":"right","type":"ADVANCED_RESULT"},"priority":0,"maxVisits":1,"fromNodeKey":"choice","once":true,"conditions":[],"toNodeKey":"end","weight":1}],"fallbacks":[{"fromNodeKey":"choice","toNodeKey":"end"}],"nodeRequirements":[],"schemaVersion":1,"startNodeKey":"intro","terminalNodeKeys":["end"],"variables":{}},"title":"本地合同样例"}"#
    private let qa = #"{"schemaVersion":1,"qa":{"enabled":true,"mode":"PICK","title":"Question","options":[{"id":"a","label":"A","correct":true},{"id":"b","label":"B","correct":false}]}}"#
    private let fixtureHash = String(repeating: "a", count: 64)
    private func installation() -> ModInstallationReceipt {
        .init(schema: "mod-installation-receipt-v1", requestId: "00000000-0000-0000-0000-000000000001",
              licenseId: "license", moduleId: "module", releaseId: "release", contentHash: fixtureHash, termsHash: fixtureHash,
              state: .installed, merchantId: 10, anchorPoiId: 20, region: "test", bindingHash: fixtureHash, draftId: 30,
              editKind: "TOPIC", createdAt: "2026-10-21T00:00:00.000000Z", errorCode: nil, published: false, executable: false,
              requiredGates: ["MERCHANT_FACT_CONFIRMATION", "THEME_CONTENT_REVIEW", "W02_PUBLISH"], bindings: [])
    }
    private func pending() throws -> ModInstallationQaEditPending {
        .init(installation: installation(), command: .init(editRequestId: "00000000-0000-0000-0000-000000000002", sourceNodeId: "intro", expectedDraftHash: fixtureHash,
              config: try JSONDecoder().decode([String: TemplateAuthoringJSON].self, from: Data(qa.utf8))), templateId: 31, receipt: nil)
    }
    private func context(account: Int = 7, epoch: UInt64 = 1) throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: URL(string: "https://example.com/native")!, role: "merchant",
              session: try .init(accountID: account, epoch: epoch, namespace: "synthetic-qa-edit", token: "synthetic-session", role: "merchant"))
    }
    private final class Memory: TemplateAuthoringStorage {
        var values: [String: Data] = [:]; var failWrite = false; var failRead = false
        func read(_ key: String) throws -> Data? { if failRead { throw ModInstallationIssue.storageUnavailable }; return values[key] }
        func write(_ data: Data, key: String) throws { if failWrite { throw ModInstallationIssue.storageUnavailable }; values[key] = data }
        func remove(_ key: String) throws { values.removeValue(forKey: key) }
    }
    func testOriginalQaCarrierAndChoiceRemainDifferentNativeMechanics() throws {
        let value = try ModInstallationTopicGraph(json: graph)
        XCTAssertEqual(value.locale, "zh-Hans"); XCTAssertEqual(value.nodes.map(\.sourceType), ["ADVANCED_GAME", "CHOICE", "END"])
        let question = try ModInstallationQaPick(json: value.nodes[0].advancedConfigJson)
        XCTAssertEqual(question.options.map(\.id), ["a", "b"]); XCTAssertEqual(question.options.filter(\.correct).count, 1)
        XCTAssertTrue(value.edges.contains { $0.fromNodeKey == "intro" && $0.trigger.type == "CHOICE" && $0.trigger.outcomeCode == "COMPLETED" })
        XCTAssertEqual(value.nodes[1].fallbackChoiceId, "left")
    }
    func testWrongCarrierAndHiddenCapabilitiesAreRejectedWithoutDowngrade() throws {
        XCTAssertThrowsError(try ModInstallationQaPick(json: qa.replacingOccurrences(of: "\"enabled\":true", with: "\"enabled\":true,\"imageUrl\":\"forbidden\"")))
        XCTAssertThrowsError(try ModInstallationQaPick(json: qa.replacingOccurrences(of: "\"correct\":false", with: "\"correct\":true")))
        XCTAssertThrowsError(try ModInstallationTopicGraph(json: graph.replacingOccurrences(of: "r2-native-qa-pick-topic-1", with: "r2-native-choice-topic-1")))
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(graph.utf8)) as? [String: Any])
        var route = try XCTUnwrap(root["route"] as? [String: Any]), edges = try XCTUnwrap(route["edges"] as? [[String: Any]])
        let index = try XCTUnwrap(edges.firstIndex { $0["fromNodeKey"] as? String == "intro" })
        edges[index]["trigger"] = ["type": "ADVANCED_RESULT", "outcomeCode": "COMPLETED"]; route["edges"] = edges; root["route"] = route
        let changed = try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: root), encoding: .utf8))
        XCTAssertThrowsError(try ModInstallationTopicGraph(json: changed))
    }
    func testOriginalEditJournalSurvivesRestartAndAccountFence() throws {
        let memory = Memory(), original = try pending()
        let store = ModInstallationPendingStore(storage: memory, context: try context(), identity: installation().identity)
        try store.beginQaEdit(original)
        let restored = ModInstallationPendingStore(storage: memory, context: try context(epoch: 2), identity: installation().identity)
        XCTAssertEqual(try restored.loadQaEdit(installation: installation()), original)
        XCTAssertNil(try ModInstallationPendingStore(storage: memory, context: context(account: 8), identity: installation().identity).loadQaEdit(installation: installation()))
        let replacement = ModInstallationQaEditPending(installation: installation(), command: .init(editRequestId: UUID().uuidString.lowercased(), sourceNodeId: "intro", expectedDraftHash: fixtureHash, config: original.command.config), templateId: 31, receipt: nil)
        XCTAssertThrowsError(try restored.beginQaEdit(replacement))
    }
    func testExactReceiptReadbackBeforeAnotherEditAndStorageFailureBlocksDispatch() throws {
        let memory = Memory(), original = try pending(), store = ModInstallationPendingStore(storage: memory, context: try context(), identity: installation().identity)
        memory.failWrite = true; XCTAssertThrowsError(try store.beginQaEdit(original)); XCTAssertNil(try store.loadQaEdit(installation: installation()))
        memory.failWrite = false; try store.beginQaEdit(original)
        let receipt = ModInstallationQaEditReceipt(schema: "mod-installation-qa-edit-receipt-v1", installationRequestId: installation().requestId,
            editRequestId: original.command.editRequestId, sourceNodeId: "intro", previousDraftHash: fixtureHash, resultDraftHash: String(repeating: "b", count: 64), advancedConfigJson: qa, topicId: 30, templateId: 31)
        try receipt.validate(original); var acknowledged = original; acknowledged.receipt = receipt; try store.acceptQaEdit(acknowledged)
        XCTAssertEqual(try store.loadQaEdit(installation: installation())?.receipt, receipt)
        let wrong = ModInstallationQaEditReceipt(schema: receipt.schema, installationRequestId: receipt.installationRequestId, editRequestId: receipt.editRequestId,
            sourceNodeId: receipt.sourceNodeId, previousDraftHash: fixtureHash, resultDraftHash: receipt.resultDraftHash, advancedConfigJson: qa, topicId: 30, templateId: 999)
        XCTAssertThrowsError(try wrong.validate(original))
    }
    func testNewClientVersionDoesNotRewriteOldPendingCommands() throws {
        let receipt = installation(); XCTAssertEqual(try ModInstallationAttempt(restoring: receipt).request.clientVersion, 4)
        let old = ModInstallationRequest(requestId: receipt.requestId, licenseId: receipt.licenseId, merchantId: 10, anchorPoiId: 20, bindings: [], clientVersion: 3, runtimeVersion: 1)
        try old.validate(); XCTAssertEqual(try JSONDecoder().decode(ModInstallationRequest.self, from: JSONEncoder().encode(old)).clientVersion, 3)
    }
    private final class Service: ModInstallationServing {
        var failCurrent = false
        var isCurrent = true; var canMutate = true; var writes = 0; var reads = 0
        let installation: ModInstallationReceipt; let initialConfig: String
        var committed: ModInstallationQaEditReceipt?
        init(installation: ModInstallationReceipt, config: String) { self.installation = installation; initialConfig = config }
        func invalidate() { isCurrent = false }
        func qaEditor(_ installation: ModInstallationReceipt) async throws -> ModInstallationQaEditorState {
            if failCurrent { throw ModInstallationIssue.unavailable }
            return .init(schema: "mod-installation-qa-editor-v1", installationRequestId: installation.requestId, licenseId: installation.licenseId,
                  bindingHash: installation.bindingHash, draftContentHash: committed?.resultDraftHash ?? installation.bindingHash, locale: "en", topicId: 30,
                  nodes: [.init(sourceNodeId: "intro", title: "Question", advancedConfigJson: committed?.advancedConfigJson ?? initialConfig, nodeId: 32, templateId: 31)])
        }
        func saveQaEdit(_ pending: ModInstallationQaEditPending) async throws -> ModInstallationQaEditReceipt {
            writes += 1
            committed = .init(schema: "mod-installation-qa-edit-receipt-v1", installationRequestId: installation.requestId,
                editRequestId: pending.command.editRequestId, sourceNodeId: pending.command.sourceNodeId, previousDraftHash: pending.command.expectedDraftHash,
                resultDraftHash: String(repeating: "b", count: 64), advancedConfigJson: pending.command.configJSON, topicId: 30, templateId: pending.templateId)
            throw ModInstallationIssue.unavailable // Explicit test double: server committed, response lost.
        }
        func qaEditReceipt(_ pending: ModInstallationQaEditPending) async throws -> ModInstallationQaEditReceipt {
            reads += 1; guard let committed else { throw ModInstallationIssue.requestNotFound }; return committed
        }
        func options(identity: ModInstallationIdentity, merchantId: Int64?) async throws -> ModInstallationOptions { throw ModInstallationIssue.unavailable }
        func prepare(_ attempt: ModInstallationAttempt) async throws -> ModInstallationReceipt { throw ModInstallationIssue.unavailable }
        func request(_ requestId: String, identity: ModInstallationIdentity) async throws -> ModInstallationReceipt { throw ModInstallationIssue.unavailable }
        func install(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt { throw ModInstallationIssue.unavailable }
        func cancel(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt { throw ModInstallationIssue.unavailable }
        func preview(_ receipt: ModInstallationReceipt) async throws -> ModInstallationPreview { throw ModInstallationIssue.unavailable }
        func facts(_ receipt: ModInstallationReceipt) async throws -> ModInstallationFacts { throw ModInstallationIssue.unavailable }
        func confirmFacts(_ facts: ModInstallationFacts, receipt: ModInstallationReceipt) async throws -> ModInstallationFacts { throw ModInstallationIssue.unavailable }
        func history(identity: ModInstallationIdentity) async throws -> [ModInstallationReceipt] { throw ModInstallationIssue.unavailable }
    }
    func testLostEditResponseRecoversOriginalReceiptWithoutAnotherWrite() async throws {
        let memory = Memory(), receipt = installation(), service = Service(installation: receipt, config: qa)
        let store = ModInstallationPendingStore(storage: memory, context: try context(), identity: receipt.identity)
        let editor = ModInstallationQaEditor(installation: receipt, service: service, store: store)
        await editor.open(); editor.setText("title", value: "Edited question"); editor.prepareReview()
        let reviewed = try XCTUnwrap(editor.review); await editor.confirm(reviewed)
        XCTAssertEqual(service.writes, 1); XCTAssertNil(editor.pending?.receipt); XCTAssertFalse(editor.canEdit)
        let restored = ModInstallationQaEditor(installation: receipt, service: service,
            store: ModInstallationPendingStore(storage: memory, context: try context(epoch: 2), identity: receipt.identity))
        await restored.open()
        XCTAssertEqual(service.writes, 1); XCTAssertEqual(service.reads, 1)
        XCTAssertEqual(restored.pending?.receipt?.editRequestId, reviewed.command.editRequestId)
        service.isCurrent = false; restored.prepareReview(); XCTAssertFalse(restored.canEdit); XCTAssertNil(restored.review)
    }

    func testRecoveredReceiptAndCurrentFailureRemainSeparateAcrossRestart() async throws {
        let memory = Memory(), original = installation(), service = Service(installation: original, config: qa)
        let store = ModInstallationPendingStore(storage: memory, context: try context(), identity: original.identity)
        let editor = ModInstallationQaEditor(installation: original, service: service, store: store)
        await editor.open(); editor.setText("title", value: "Changed"); editor.prepareReview()
        await editor.confirm(try XCTUnwrap(editor.review))
        XCTAssertNil(editor.pending?.receipt); XCTAssertFalse(editor.canEdit); XCTAssertEqual(service.writes, 1)
        service.failCurrent = true; await editor.open()
        XCTAssertNotNil(editor.pending?.receipt); XCTAssertNil(editor.state); XCTAssertNil(editor.node)
        XCTAssertFalse(editor.canEdit); editor.prepareReview(); XCTAssertNil(editor.review)
        XCTAssertEqual(try store.loadQaEdit(installation: original)?.receipt, editor.pending?.receipt)
        let restarted = ModInstallationQaEditor(installation: original, service: service,
            store: ModInstallationPendingStore(storage: memory, context: try context(epoch: 2), identity: original.identity))
        await restarted.open(); XCTAssertNotNil(restarted.pending?.receipt); XCTAssertNil(restarted.state)
        XCTAssertFalse(restarted.canEdit); XCTAssertEqual(service.writes, 1)
        service.failCurrent = false; await restarted.open()
        XCTAssertTrue(restarted.canEdit); XCTAssertEqual(restarted.text("title"), "Changed"); XCTAssertEqual(service.writes, 1)
        service.isCurrent = false; await restarted.open()
        XCTAssertNil(restarted.state); XCTAssertNil(restarted.node); XCTAssertNotNil(restarted.pending?.receipt)
        XCTAssertFalse(restarted.canEdit)
    }
    func testFailedJournalRefreshCannotRetainOldQASelectionAsCurrent() async throws {
        let memory = Memory(), original = installation(), service = Service(installation: original, config: qa)
        let editor = ModInstallationQaEditor(installation: original, service: service,
            store: ModInstallationPendingStore(storage: memory, context: try context(), identity: original.identity))
        await editor.open(); editor.setText("title", value: "Unsaved"); editor.prepareReview()
        XCTAssertNotNil(editor.review); memory.failRead = true; await editor.open()
        XCTAssertNil(editor.state); XCTAssertNil(editor.node); XCTAssertNil(editor.review)
        XCTAssertFalse(editor.canEdit); XCTAssertEqual(editor.text("title"), "Unsaved"); XCTAssertEqual(service.writes, 0)
    }

}
