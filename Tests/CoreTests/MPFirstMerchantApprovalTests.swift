import XCTest
@testable import QuestifyCore

/// Owner 2026-11-25 MP-first rule: merchant writes the MP sends go out with the MP's path, method and body,
/// and the server's permission check decides. These tests pin the request shape and the approval behaviour.
@MainActor final class MPFirstMerchantApprovalTests: XCTestCase {
    private let url = URL(string: "https://example.com")!
    private func context(account: Int = 7) throws -> RuntimeDependencyContext {
        RuntimeDependencyContext(market: .china, baseURL: url, role: "merchant",
                                 session: try .init(accountID: account, epoch: 1, namespace: "merchant-cn", token: "synthetic-token"))
    }
    private func approval() throws -> MerchantBusinessProductionApproval {
        try MerchantBusinessProductionApproval(mpFirstMarket: .china,
            endpoints: .init(baseURL: url, namespace: "merchant-cn", accountID: 7, paths: ["api/merchant/aftercare/respond"]))
    }
    private func keys(_ request: MerchantBusinessRequest) -> Set<String> {
        guard case .json(let fields) = request.body else { return [] }
        return Set(fields.keys)
    }

    func testMPFirstRequestShapesMatchTheMiniProgram() throws {
        let customer = try MerchantCustomerID(61001)
        // pages/merchant/customer/detail/index.js:178 / :230 / :262 / :300
        let note = try MerchantBusinessMutation.addNote(customer: customer, content: "回访", correctsNoteID: nil).request(requestID: "mp-first-1")
        XCTAssertEqual(note.path, "api/merchant/crm/customers/61001/notes")
        XCTAssertEqual(keys(note), ["content", "requestId", "correctsNoteId"])
        let hide = try MerchantBusinessMutation.hideNote(customer: customer, noteID: 5, expectedVersion: 1).request(requestID: "mp-first-1")
        XCTAssertEqual(hide.path, "api/merchant/crm/customers/61001/notes/hide")
        XCTAssertEqual(keys(hide), ["noteId", "expectedVersion", "requestId"])
        let removeTag = try MerchantBusinessMutation.removeTag(customer: customer, tagID: 3).request(requestID: "mp-first-1")
        XCTAssertEqual(removeTag.path, "api/merchant/crm/customers/61001/tags/remove")
        XCTAssertEqual(keys(removeTag), ["tagId", "requestId"])
        // pages/merchant/aftercare/detail/index.js:288 POST ?refundId= with {decision, content, requestId}
        let aftercare = try MerchantBusinessMutation.aftercare(refund: MerchantRefundID(62001), decision: .reject, content: "已发货", evidenceKey: nil).request(requestID: "mp-first-1")
        XCTAssertEqual(aftercare.path, "api/merchant/aftercare/respond")
        XCTAssertEqual(aftercare.query, ["refundId": "62001"])
        XCTAssertEqual(keys(aftercare), ["decision", "content", "requestId"])
        // pages/merchant/reviews/index.js reply / reply/update / reply/delete / manage/report
        let review = try MerchantBusinessReviewID(81)
        XCTAssertEqual(try MerchantBusinessMutation.review(id: review, version: 2, action: .reply, content: "谢谢").request(requestID: "mp-first-1").path, "api/merchant/reviews/reply")
        XCTAssertEqual(try MerchantBusinessMutation.review(id: review, version: 2, action: .update, content: "谢谢").request(requestID: "mp-first-1").path, "api/merchant/reviews/reply/update")
        XCTAssertEqual(try MerchantBusinessMutation.review(id: review, version: 2, action: .delete, content: "").request(requestID: "mp-first-1").path, "api/merchant/reviews/reply/delete")
        let report = try MerchantBusinessMutation.review(id: review, version: 2, action: .report, content: "广告").request(requestID: "mp-first-1")
        XCTAssertEqual(report.path, "api/merchant/reviews/manage/report")
        XCTAssertEqual(keys(report), ["reviewId", "expectedVersion", "requestId", "reason"])
        // pages/merchant/team/index.js:570 / :626 / :718
        XCTAssertEqual(try MerchantBusinessMutation.inviteOperator(role: "MERCHANT_MANAGER").request(requestID: "mp-first-1").path, "api/merchant/operators/invite")
        let role = try MerchantBusinessMutation.operatorRole(id: MerchantOperatorID(4), version: 1, role: "MERCHANT_CHECKIN").request(requestID: "mp-first-1")
        XCTAssertEqual(role.path, "api/merchant/operators/role")
        XCTAssertEqual(keys(role), ["operatorId", "roleCode", "version", "requestId"])
        let remove = try MerchantBusinessMutation.removeOperator(id: MerchantOperatorID(4), version: 1, reason: "店主在经营团队页移除成员").request(requestID: "mp-first-1")
        XCTAssertEqual(remove.path, "api/merchant/operators/remove")
        XCTAssertEqual(keys(remove), ["operatorId", "version", "reason", "requestId"])
        XCTAssertEqual(try MerchantBusinessMutation.revokeInvite(id: MerchantOperatorInviteID(9), version: 1, reason: "撤销").request(requestID: "mp-first-1").path, "api/merchant/operators/invite/revoke")
    }

    func testMPFirstApprovalPermitsEveryMPActionForAnyStoreAndTarget() throws {
        let approval = try approval()
        let context = try context()
        let customer = try MerchantCustomerID(61001)
        let mutations: [MerchantBusinessMutation] = [
            .addNote(customer: customer, content: "回访", correctsNoteID: nil),
            .assignTag(customer: customer, name: "常客", color: "#FF6A00"),
            .batchTag(customers: [customer, try MerchantCustomerID(61002)], name: "常客", color: "#FF6A00"),
            .aftercare(refund: try MerchantRefundID(62001), decision: .agree, content: "", evidenceKey: nil),
            .review(id: try MerchantBusinessReviewID(81), version: 2, action: .reply, content: "谢谢"),
            .inviteOperator(role: "MERCHANT_MANAGER"),
            .removeOperator(id: try MerchantOperatorID(4), version: 1, reason: "店主在经营团队页移除成员")
        ]
        for mutation in mutations {
            XCTAssertTrue(approval.permits(mutation, merchantID: 9, context: context), "\(mutation.action)")
            XCTAssertTrue(approval.permits(mutation, merchantID: 31, context: context), "\(mutation.action)")
            XCTAssertFalse(approval.permits(mutation, merchantID: 0, context: context), "\(mutation.action)")
        }
        let report = MerchantBusinessMutation.review(id: try MerchantBusinessReviewID(81), version: 2, action: .report, content: "广告")
        XCTAssertFalse(approval.permits(report, merchantID: 9, context: context))
        let sku = MerchantBusinessMutation.saveSku(productID: 3, skuID: 44, name: "door", price: "1", stock: 2,
            originalPrice: nil, pic: nil, bookable: false, slotMinutes: 60, capacityPerSlot: 0, ruleVersion: 4)
        XCTAssertFalse(approval.permits(sku, merchantID: 9, context: context))
    }

    func testMPFirstApprovalStillPinsAccountAndHost() throws {
        let approval = try approval()
        let mutation = MerchantBusinessMutation.inviteOperator(role: "MERCHANT_MANAGER")
        XCTAssertFalse(approval.permits(mutation, merchantID: 9, context: try context(account: 8)))
        let otherHost = RuntimeDependencyContext(market: .china, baseURL: URL(string: "https://other.example.com")!, role: "merchant",
                                                 session: try .init(accountID: 7, epoch: 1, namespace: "merchant-cn", token: "synthetic-token"))
        XCTAssertFalse(approval.permits(mutation, merchantID: 9, context: otherHost))
    }

    func testMPFirstFactoryBuildsAProductionServiceForTheMPWrite() throws {
        let context = try context()
        let factory = MerchantBusinessProductionFactory(api: try .init(baseURL: url), approval: try approval(),
                                                        transport: MPFirstNoWire(), current: { context })
        XCTAssertNotNil(factory.service(for: .inviteOperator(role: "MERCHANT_MANAGER"), merchantID: 9))
        let open = MerchantBusinessProductionFactory(api: try .init(baseURL: url), approval: nil, transport: MPFirstNoWire(), current: { context })
        XCTAssertNotNil(open.service(for: .inviteOperator(role: "MERCHANT_MANAGER"), merchantID: 9))
        let report = MerchantBusinessMutation.review(id: try MerchantBusinessReviewID(81), version: 2, action: .report, content: "广告")
        XCTAssertNil(open.service(for: report, merchantID: 9))
    }

    /// pages/merchant/team/index.js:806-818: POST api/merchant/operators/invite/accept {token, requestId}.
    func testMPFirstAcceptInvitationShapeAndApproval() throws {
        let command = MerchantEngagementCommand.acceptInvitation(try .init(token: "synthetic-invitation-token"))
        let request = try command.request(requestID: "mp-first-accept-1")
        XCTAssertEqual(request.path, "api/merchant/operators/invite/accept")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.fields?.keys.sorted(), ["requestId", "token"])
        let endpoints = try OperationEndpointApproval(baseURL: url, namespace: "merchant-cn", accountID: 7,
                                                      paths: [MerchantEngagementProductionApproval.acceptInvitationPath])
        let open = try MerchantEngagementProductionApproval(market: .china, endpoints: endpoints, grants: [],
                                                            reviewedPolicyVersion: MerchantCoopLiveWrites.policyVersion)
        XCTAssertFalse(open.permits(command, merchantID: 0, context: try context()))
        XCTAssertTrue(open.permits(command, merchantID: 9, context: try context()))
        XCTAssertFalse(open.permits(command, merchantID: 9, context: try context(account: 8)))
        let other = try OperationEndpointApproval(baseURL: url, namespace: "merchant-cn", accountID: 7, paths: ["api/merchant/crm/segments"])
        let closed = try MerchantEngagementProductionApproval(market: .china, endpoints: other, grants: [], reviewedPolicyVersion: "reviewed")
        XCTAssertFalse(closed.permits(command, merchantID: 9, context: try context()))
    }
}

private final class MPFirstNoWire: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) { throw URLError(.notConnectedToInternet) }
}
