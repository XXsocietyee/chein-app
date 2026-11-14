import XCTest
@testable import QuestifyCore

@MainActor enum WorkshopPaidTextFixture {
    static let requestID = "00000000-0000-4000-8000-000000000001"
    static let source = #"{"schema":"w18-member-text-v1","title":" 原文🙂 ","merchantGuide":" 保密说明 ","questionName":" Q? ","questionAnswer":" A ","hint1":"一","hint2":"二","answerReveal":"答案","bindings":{}}"#
    static let terms = Data("opaque synthetic frozen terms".utf8)
    static func data(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: .sortedKeys) }
    static func decode<T: Decodable>(_ type: T.Type, _ value: [String: Any]) throws -> T { try WorkshopPaidInstallWire.decode(type, data: data(value), maximum: 2_097_152) }
    static func item() throws -> WorkshopPurchasedItem { var value = WorkshopPurchasedTestData.item; value["contentHash"] = ContentDraftRecord.hash(source); return try decode(WorkshopPurchasedItem.self, value) }
    static func command() throws -> WorkshopPaidInstallCommand {
        try .init(requestId: requestID, licenseId: "WKO_0000000000000000000000000000000b", moduleId: Int64(item().moduleId)!, purchasedVersionId: item().purchasedVersionId,
            contentHash: ContentDraftRecord.hash(source), termsHash: item().termsHash, targetDraftId: 91, targetRevision: 1,
            businessType: "MEMBER_TEMPLATE", targetPayloadHash: String(repeating: "c", count: 64), planningRegion: "110101", commercialUse: false)
    }
    static func receipt() throws -> WorkshopPaidInstallOutcome {
        var value = try JSONSerialization.jsonObject(with: command().wireData()) as! [String: Any]
        value["schema"] = "workshop-private-draft-install-outcome-v2"; value["state"] = "INSTALLED_PRIVATE_DRAFT"; value["mode"] = "PRIVATE_COPY"
        value["holdDeadline"] = "2026-10-05T00:05:00Z"; value["ownedDraftId"] = 101; value["installedAt"] = "2026-10-05T00:00:01Z"
        value["professionalTemplateStatus"] = "MATERIALIZATION_REQUIRED"; value["published"] = false; value["executable"] = false
        return try decode(WorkshopPaidInstallOutcome.self, value)
    }
    static func reference() throws -> WorkshopPaidInstalledTextReference { try .init(item: item(), receipt: receipt()) }
    static func member() throws -> [String: Any] { try JSONSerialization.jsonObject(with: Data(source.utf8)) as! [String: Any] }
    static func text() throws -> WorkshopPaidInstalledText {
        WorkshopPaidInstalledText(reference: try reference(), fields: try WorkshopPaidInstalledTextFields.decode(source, component: false), sourceJSON: source)
    }
    static func envelope() throws -> Data { try data(["code":200,"data":member()]) }
}
@MainActor final class WorkshopPaidInstalledTextTests: XCTestCase {
    @MainActor private final class Wire: HTTPTransport {
        var requests: [URLRequest] = [], delay = false
        var response: (Data,Int)
        var suspended: CheckedContinuation<(Data,Int),Never>?
        init() throws { response = (try WorkshopPaidTextFixture.envelope(),200) }
        func send(_ request: URLRequest) async throws -> (Data,Int) { requests.append(request); if delay { delay = false; return await withCheckedContinuation { suspended = $0 } }; return response }
        func wait() async { for _ in 0..<1000 { if suspended != nil { return }; await Task.yield() }; XCTFail("Expected suspended real service transport") }
        func resume(_ value: (Data,Int)) { let old = suspended; suspended = nil; old?.resume(returning:value) }
    }
    @MainActor private final class Harness {
        let context: RuntimeDependencyContext, wire: Wire, reference: WorkshopPaidInstalledTextReference
        var current: RuntimeDependencyContext?, approval: WorkshopPaidInstalledTextApproval?, unauthorized = 0
        lazy var lease = ContentDraftSessionLease(context: context, current: { [weak self] in self?.current })
        lazy var service = WorkshopPaidInstalledTextService(api: try! APIConfiguration(baseURL: context.baseURL), transport: wire, lease: lease, approval: approval, currentApproval: { [weak self] in self?.approval }, onUnauthorized: { [weak self] _ in self?.unauthorized += 1 })
        lazy var controller = WorkshopPaidInstalledTextController(reference: reference, service: service, lease: lease)
        init(approved: Bool = true) throws {
            context = .init(market: .china, baseURL: URL(string: "https://example.com/native")!, role: "player", session: try .init(accountID: 7, epoch: 1, namespace: "synthetic", token: "synthetic-test-7", role: "player"))
            current = context; wire = try Wire(); reference = try WorkshopPaidTextFixture.reference()
            approval = approved ? try .init(context: context, expiresAt: .distantFuture) : nil
        }
        func read(_ a: WorkshopPaidInstalledTextAppearance) async throws { await (try XCTUnwrap(controller.appear(a)))() }
    }
    func testExactProtectedSourceAndAllFieldsArePreservedAndDebugRedacted() throws {
        let body = try WorkshopPaidTextFixture.text()
        XCTAssertTrue(body.matches(try WorkshopPaidTextFixture.reference())); XCTAssertEqual(body.sourceJSON,WorkshopPaidTextFixture.source)
        XCTAssertEqual(body.version,"—"); XCTAssertEqual(body.checkedAt,"—")
        XCTAssertEqual(body.installedFields["merchantGuide"]," 保密说明 "); XCTAssertEqual(body.installedFields["questionAnswer"]," A ")
        XCTAssertEqual(body.installedFields["hint1"],"一"); XCTAssertEqual(body.installedFields["hint2"],"二"); XCTAssertEqual(body.installedFields["answerReveal"],"答案")
        XCTAssertEqual(body.sourceFields, body.installedFields); XCTAssertFalse(String(describing:body).contains("保密")); XCTAssertFalse(String(reflecting:body.installedFields).contains("保密"))
    }
    func testChangedOriginalComponentTermsAndUnknownFieldsAreRejected() throws {
        var value = try WorkshopPaidTextFixture.member(); value["templateId"] = 99
        XCTAssertThrowsError(try WorkshopPaidInstalledTextFields.decode(String(data: try WorkshopPaidTextFixture.data(value), encoding: .utf8)!, component: false))
        value = try WorkshopPaidTextFixture.member(); value["merchantGuide"] = 7
        XCTAssertThrowsError(try WorkshopPaidInstalledTextFields.decode(String(data: try WorkshopPaidTextFixture.data(value), encoding: .utf8)!, component: false))
    }
    func testNullOptionalFieldIsAbsentAndUnknownKeyIsRejected() throws {
        var value = try WorkshopPaidTextFixture.member(); value["description"] = NSNull()
        let decoded = try WorkshopPaidInstalledTextFields.decode(String(data: try WorkshopPaidTextFixture.data(value), encoding: .utf8)!, component: false)
        XCTAssertNil(decoded["description"])
        value["unknown"] = "x"; XCTAssertThrowsError(try WorkshopPaidInstalledTextFields.decode(String(data: try WorkshopPaidTextFixture.data(value), encoding: .utf8)!, component: false))
    }
    func testDifferentReceiptCannotBindToCapturedInstallation() throws {
        let text = try WorkshopPaidTextFixture.text()
        XCTAssertTrue(text.matches(try .init(item: WorkshopPaidTextFixture.item(), receipt: WorkshopPaidTextFixture.receipt())))
        let foreign = try WorkshopPaidInstallCommand(requestId: "00000000-0000-4000-8000-000000000009", licenseId: text.licenseID, moduleId: Int64(text.moduleID)!, purchasedVersionId: text.purchasedVersionID, contentHash: text.contentHash, termsHash: text.termsHash, targetDraftId: 91, targetRevision: 1, businessType: "MEMBER_TEMPLATE", targetPayloadHash: String(repeating: "c", count: 64), planningRegion: "110101", commercialUse: false)
        var receipt = try JSONSerialization.jsonObject(with: foreign.wireData()) as! [String: Any]
        receipt["schema"] = "workshop-private-draft-install-outcome-v2"; receipt["state"] = "INSTALLED_PRIVATE_DRAFT"; receipt["mode"] = "PRIVATE_COPY"
        receipt["holdDeadline"] = "2026-10-05T00:05:00Z"; receipt["ownedDraftId"] = 101; receipt["installedAt"] = "2026-10-05T00:00:01Z"
        receipt["professionalTemplateStatus"] = "MATERIALIZATION_REQUIRED"; receipt["published"] = false; receipt["executable"] = false
        let otherReceipt = try WorkshopPaidTextFixture.decode(WorkshopPaidInstallOutcome.self, receipt)
        XCTAssertFalse(text.matches(try .init(item: WorkshopPaidTextFixture.item(), receipt: otherReceipt)))
    }
    func testNestedUnknownUnmappedAndInferredMethodCannotPassFieldReader() throws {
        for text in [#"{"schema":"w18-member-text-v1","title":"x","bindings":{},"unknown":"x"}"#,#"{"schema":"w18-member-text-v1","title":"x","bindings":{},"validationMethod":2}"#] { XCTAssertThrowsError(try WorkshopPaidInstalledTextFields.decode(text,component:true)) }
        XCTAssertThrowsError(try WorkshopPaidInstalledTextFields.decode(String(repeating:"[",count:1000)+"0"+String(repeating:"]",count:1000),component:false))
    }
    func testMissingBodyApprovalPerformsNoRequestDespiteRealMetadataReference() async throws {
        let h = try Harness(approved:false); try await h.read(.init()); XCTAssertTrue(h.wire.requests.isEmpty); XCTAssertEqual(h.controller.issue,.disabled); XCTAssertNil(h.controller.content)
    }
    func testActualServiceLoadsBodyAndBackImmediatelyClearsIt() async throws {
        let h = try Harness(), a = WorkshopPaidInstalledTextAppearance(); try await h.read(a)
        XCTAssertEqual(h.controller.phase,.loaded); XCTAssertNotNil(h.controller.content); XCTAssertEqual(h.wire.requests.count,1)
        h.controller.close(a); XCTAssertNil(h.controller.content); XCTAssertEqual(h.controller.phase,.idle); XCTAssertNil(h.controller.appear(a))
    }
    func testQueuedReadAfterBackCannotDispatchOrTouchReopenedBody() async throws {
        let h = try Harness(), old = WorkshopPaidInstalledTextAppearance(), queued = try XCTUnwrap(h.controller.appear(old)); h.controller.close(old)
        let fresh = WorkshopPaidInstalledTextAppearance(); try await h.read(fresh); let before = h.wire.requests.count
        await queued(); h.controller.close(old); XCTAssertNil(h.controller.appear(old)); XCTAssertEqual(h.wire.requests.count,before); XCTAssertEqual(h.controller.phase,.loaded); XCTAssertNotNil(h.controller.content)
    }
    func testNewerOfferInvalidatesQueuedOlderOfferBeforeDispatch() async throws {
        let h = try Harness(), a = WorkshopPaidInstalledTextAppearance(), old = try XCTUnwrap(h.controller.appear(a)), fresh = try XCTUnwrap(h.controller.offerReload(a))
        await old(); XCTAssertTrue(h.wire.requests.isEmpty); await fresh(); await fresh(); XCTAssertEqual(h.wire.requests.count,1)
    }
    func testSuspendedClosed401CannotExpireSessionOrClearReplacementBody() async throws {
        let h = try Harness(), a = WorkshopPaidInstalledTextAppearance(); h.wire.delay = true
        let action = try XCTUnwrap(h.controller.appear(a)), task = Task { await action() }; await h.wire.wait(); h.controller.close(a)
        try await h.read(.init()); h.wire.resume((Data(),401)); await task.value
        XCTAssertEqual(h.unauthorized,0); XCTAssertEqual(h.controller.phase,.loaded); XCTAssertNotNil(h.controller.content)
    }
    func testCurrent401StillCallsUnauthorizedExactlyOnce() async throws {
        let h = try Harness(); h.wire.response = (Data(),401); try await h.read(.init()); XCTAssertEqual(h.unauthorized,1); XCTAssertNil(h.controller.content)
    }
    func testTaskCancellationFencesLate401() async throws {
        let h = try Harness(), a = WorkshopPaidInstalledTextAppearance(); h.wire.delay = true
        let action = try XCTUnwrap(h.controller.appear(a)), task = Task { await action() }; await h.wire.wait(); task.cancel(); h.wire.resume((Data(),401)); await task.value
        XCTAssertEqual(h.unauthorized,0); XCTAssertNil(h.controller.content)
    }
    func testIdentityReplacementInvalidatesQueuedReadWithZeroDispatch() async throws {
        let h = try Harness(), a = WorkshopPaidInstalledTextAppearance(), queued = try XCTUnwrap(h.controller.appear(a)); h.current = nil
        await queued(); XCTAssertTrue(h.wire.requests.isEmpty); XCTAssertEqual(h.controller.phase,.invalidated)
    }
    func testReplacedApprovalFencesSuspended401() async throws {
        let h = try Harness(), a = WorkshopPaidInstalledTextAppearance(); h.wire.delay = true
        let action = try XCTUnwrap(h.controller.appear(a)), task = Task { await action() }; await h.wire.wait()
        h.approval = try .init(context:h.context,expiresAt:.distantFuture); h.wire.resume((Data(),401)); await task.value
        XCTAssertEqual(h.unauthorized,0); XCTAssertNil(h.controller.content)
    }
    func testOversizedAndDuplicateResponseNeverReachProtectedState() async throws {
        for payload in [Data(repeating:0,count:2_097_153),Data(#"{"code":200,"code":401,"data":{}}"#.utf8)] {
            let h = try Harness(); h.wire.response = (payload,200); try await h.read(.init()); XCTAssertNil(h.controller.content); XCTAssertEqual(h.controller.issue,.malformed); XCTAssertEqual(h.unauthorized,0)
        }
    }
    func testExactRequestMatcherRejectsWriteAliasesOwnerInjectionAndUnknownLength() async throws {
        let h = try Harness(); try await h.read(.init()); let request = try XCTUnwrap(h.wire.requests.first)
        XCTAssertTrue(WorkshopPaidInstalledTextRequest.accepts(request,baseURL:h.context.baseURL))
        var bad = request; bad.url = h.context.baseURL.appendingPathComponent("api/workshop/purchased/installed-text/publish"); XCTAssertFalse(WorkshopPaidInstalledTextRequest.accepts(bad,baseURL:h.context.baseURL))
        bad = request; bad.httpBody = Data("license_id=WKO_0000000000000000000000000000000b&request_id=\(WorkshopPaidTextFixture.requestID)&owner=7".utf8); bad.setValue(String(bad.httpBody!.count),forHTTPHeaderField:"Content-Length"); XCTAssertFalse(WorkshopPaidInstalledTextRequest.accepts(bad,baseURL:h.context.baseURL))
        bad = request; bad.setValue(nil,forHTTPHeaderField:"Content-Length"); XCTAssertFalse(WorkshopPaidInstalledTextRequest.accepts(bad,baseURL:h.context.baseURL))
    }
}
