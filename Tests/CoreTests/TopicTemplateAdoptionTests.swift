#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@MainActor final class TopicTemplateAdoptionTests: XCTestCase {
    override func tearDown() { W8Text.languageOverride = nil; super.tearDown() }

    private func delivery(_ json: String) throws -> TopicTemplateContentDelivery {
        try JSONDecoder().decode(TopicTemplateContentDelivery.self, from: Data(json.utf8))
    }

    // MARK: U02-01

    func testConditionRowsOnlyFromAuthoritativeFacts() throws {
        W8Text.languageOverride = "zh-Hans"
        let unknown = try delivery(#"{"operatingRequirementsVisibility":"NOT_PROVIDED","evidence":{"evidenceLevel":null},"runtimeSupport":{"platformExecution":"UNKNOWN"},"license":{"status":"UNKNOWN"}}"#)
        XCTAssertEqual(TopicTemplateAdoptionConditions.rows(unknown), [], "no fact -> no row, never 待补充/0/已验证")
        XCTAssertEqual(TopicTemplateAdoptionConditions.rows(nil), [])
        let full = try delivery(#"""
        {"revision":{"contentRevisionId":12,"revisionNo":4},
         "locationRequirement":{"physicalPlaceRequired":true,"stationWithAddressCount":3,"cityCode":"440300"},
         "operatingRequirementsVisibility":"PARTNER_ONLY",
         "evidence":{"evidenceLevel":"ESTIMATED"},
         "license":{"status":"AUTHORITATIVE","licensedEntity":"某工作室","validTo":"2027-01-31T00:00:00"},
         "sourceLocale":"zh-CN","translationStatus":"SINGLE_LOCALE"}
        """#)
        let rows = TopicTemplateAdoptionConditions.rows(full, canViewEvidence: true, chinese: true)
        XCTAssertEqual(rows.map(\.key), ["place", "operating", "evidence", "locale", "license", "revision"])
        XCTAssertEqual(rows[0].value, "需要到现场 · 3 个地点")
        XCTAssertEqual(rows[1].label, "运营资料")
        XCTAssertEqual(rows[1].value, "仅合作商家可见")
        XCTAssertEqual(rows[2].value, "预估，未实地验证")
        XCTAssertEqual(rows[3].value, "简体中文")
        XCTAssertEqual(rows[4].value, "某工作室 · 至 2027-01-31")
        XCTAssertEqual(rows[5].value, "第 4 版")
        let hiddenEvidence = TopicTemplateAdoptionConditions.rows(full, chinese: true)
        XCTAssertFalse(hiddenEvidence.contains { $0.key == "evidence" })
        let english = TopicTemplateAdoptionConditions.rows(full, canViewEvidence: true, chinese: false)
        XCTAssertEqual(english.first { $0.key == "locale" }?.value, "Simplified Chinese only (no translation yet)")
    }

    func testMalformedDeliveryDoesNotBreakTheDetail() throws {
        let json = #"{"id":5,"name":"t","contentDelivery":{"revision":"oops","locationRequirement":{"physicalPlaceRequired":"yes"}}}"#
        let detail = try JSONDecoder().decode(PublicTopicTemplateDetail.self, from: Data(json.utf8))
        XCTAssertEqual(detail.id, 5)
        XCTAssertNil(detail.contentDelivery?.revision)
        XCTAssertNil(detail.contentDelivery?.locationRequirement?.physicalPlaceRequired)
        let none = try JSONDecoder().decode(PublicTopicTemplateDetail.self, from: Data(#"{"id":6}"#.utf8))
        XCTAssertNil(none.contentDelivery)
    }

    // MARK: U02-02 receipt

    func testUseReceiptKeepsTopicIdObjectAndIncrement() throws {
        let json = #"{"topicId":901,"sourceTemplateTopicId":"55","sourceContentRevisionId":null,"bindingIntent":"SAME_CITY","pendingRebindSlotKeys":["loc-1",null],"bindingIssues":[{"slotKey":"loc-1","code":"REBIND","level":"error","required":true,"message":"请重绑"}]}"#
        let receipt = try JSONDecoder().decode(TopicTemplateUseReceipt.self, from: Data(json.utf8))
        XCTAssertEqual(receipt.topicId, 901)
        XCTAssertNil(receipt.sourceContentRevisionId, "old source: unlocked revision stays nil, never 1")
        XCTAssertEqual(receipt.pendingRebindSlotKeys, ["loc-1"])
        XCTAssertEqual(receipt.blockingCount, 1)
        XCTAssertThrowsError(try JSONDecoder().decode(TopicTemplateUseReceipt.self, from: Data(#"{"topicId":0}"#.utf8)))
    }

    func testRequestIdFormat() {
        XCTAssertTrue(AuthorWriteRequestID.isValid(AuthorWriteRequestID.make(prefix: "tpluse")))
        XCTAssertFalse(AuthorWriteRequestID.isValid("short"))
        XCTAssertFalse(AuthorWriteRequestID.isValid("has space in it"))
        XCTAssertNil(TopicTemplateUseRequest(id: 1, scope: nil, requestId: "bad id!").body["requestId"])
    }

    // MARK: U02-03

    private let statusJSON = #"""
    {"topicId":"901","contract":{"locationSlots":[
       {"slotKey":"loc-1","title":"钟楼","observationTarget":"","observationAction":"","alternativePolicy":"NONE"},
       {"slotKey":"loc-2","title":"码头","observationTarget":"石碑","alternativePolicy":"ALTERNATE_NODE"},
       {"slotKey":"loc-3","title":"","alternativePolicy":"NONE"}],
     "locationBindings":[{"slotKey":"loc-1","nodeId":"11","bindingRevision":1,"verificationStatus":"BOUND_UNVERIFIED"},
                         {"slotKey":"loc-2","bindingRevision":0,"verificationStatus":"REBIND_REQUIRED"}]},
     "bindingIssues":[{"slotKey":"loc-2","level":"error","message":"必填地点未重绑"},{"slotKey":"loc-3","level":"warn","message":"沿用未复核"}]}
    """#

    func testTodosOnlyErrorBlocksAndUnknownStatusIsNotBound() throws {
        let status = try JSONDecoder().decode(TopicLocationBindingStatus.self, from: Data(statusJSON.utf8))
        let todos = try XCTUnwrap(TopicLocationTodos(status))
        XCTAssertEqual(todos.rows.map(\.status), [.boundUnverified, .rebindRequired, .unbound])
        XCTAssertEqual(todos.blockingCount, 1)
        XCTAssertEqual(todos.warningCount, 1)
        XCTAssertFalse(todos.rows[2].blocking, "warn never blocks on device")
        XCTAssertEqual(todos.rows[0].revision, 1)
        let empty = try JSONDecoder().decode(TopicLocationBindingStatus.self, from: Data(#"{"contract":{}}"#.utf8))
        XCTAssertNil(TopicLocationTodos(empty), "no place contract -> block hidden")
    }

    func testEditorNodeMappingClaimsOnlyUniqueSameName() throws {
        let status = try JSONDecoder().decode(TopicLocationBindingStatus.self, from: Data(statusJSON.utf8))
        let todos = try XCTUnwrap(TopicLocationTodos(status))
        let nodes = [TopicLocationEditorNode(id: "11", name: "钟楼", address: "中山路1号", hasCoordinates: false),
                     TopicLocationEditorNode(id: "12", name: "码头", address: "", hasCoordinates: true),
                     TopicLocationEditorNode(id: "local-uuid", name: "码头", address: "x", hasCoordinates: false),
                     TopicLocationEditorNode(id: "13", name: "无地点", address: "", hasCoordinates: false)].compactMap { $0 }
        XCTAssertEqual(nodes.map(\.id), ["11", "12"], "unsaved ids and placeless nodes are not bindable")
        XCTAssertEqual(todos.editorNode(for: todos.rows[0], in: nodes)?.node.id, "11")
        XCTAssertEqual(todos.editorNode(for: todos.rows[0], in: nodes)?.claimed, false)
        XCTAssertEqual(todos.editorNode(for: todos.rows[1], in: nodes)?.claimed, true)
        XCTAssertNil(todos.editorNode(for: todos.rows[2], in: nodes))
    }

    private final class FakeBinding: TopicLocationBindingClient {
        var status: TopicLocationBindingStatus?
        var outcome: TopicLocationBindOutcome = .bound
        var reads = 0
        var binds: [(String, String, Int?)] = []
        func status(topicId: Int, scope: String?) async throws -> TopicLocationBindingStatus {
            reads += 1
            guard let status else { throw APIError.httpStatus(503) }
            return status
        }
        func bind(topicId: Int, scope: String?, slotKey: String, nodeId: String, expectedRevision: Int?) async -> TopicLocationBindOutcome {
            binds.append((slotKey, nodeId, expectedRevision)); return outcome
        }
    }

    func testTodosModelKeepsLastViewOnFailureAndRereadsOnUnknown() async throws {
        let client = FakeBinding()
        client.status = try JSONDecoder().decode(TopicLocationBindingStatus.self, from: Data(statusJSON.utf8))
        let model = TopicLocationTodosModel(client: client, topicId: 901, scope: nil)
        await model.load()
        let loaded = try XCTUnwrap(model.todos)
        client.status = nil
        await model.load()
        XCTAssertEqual(model.todos, loaded, "a failed read never turns into 'no to-dos'")
        client.outcome = .unknown
        await model.bind(loaded.rows[0], nodeId: "11")
        XCTAssertEqual(client.binds.count, 1, "unknown is not resent")
        XCTAssertEqual(client.binds[0].2, 1, "expectedRevision carried")
        XCTAssertNotNil(model.rowErrors["loc-1"])
        XCTAssertEqual(client.reads, 3)
        client.outcome = .rejected(code: 409, message: "已被他人更新")
        await model.bind(loaded.rows[0], nodeId: "11")
        XCTAssertEqual(model.rowErrors["loc-1"], "已被他人更新")
        XCTAssertEqual(client.reads, 4, "409 re-reads")
    }

    // MARK: U02-05

    func testCreditShowsAttributionOnly() {
        XCTAssertNil(MediaAttributionCredit.text(attribution: "  "))
        XCTAssertEqual(MediaAttributionCredit.text(attribution: String(repeating: "a", count: 50))?.count, 40)
    }
}
#endif
