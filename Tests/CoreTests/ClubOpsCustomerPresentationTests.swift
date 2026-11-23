import XCTest
@testable import QuestifyCore

final class ClubOpsCustomerPresentationTests: XCTestCase {
    private let scope = ClubGovernanceScope(clubID: 81, memberID: 704)
    private func item(_ id: Int, extra: [String: ClubGovernanceValue] = [:]) -> ClubGovernanceValue {
        var fields: [String: ClubGovernanceValue] = ["memberId": .integer(id), "verifiedCount": .integer(3), "pendingCount": .integer(0)]
        fields.merge(extra) { _, new in new }; return .object(fields)
    }
    private func list(_ items: [ClubGovernanceValue]) -> ClubGovernanceValue {
        .object(["total": .integer(items.count), "monthNew": .integer(1), "items": .array(items)])
    }
    private func detail(records: [ClubGovernanceValue] = [], summary: [String: ClubGovernanceValue] = [:], extra: [String: ClubGovernanceValue] = [:]) -> ClubGovernanceValue {
        var head: [String: ClubGovernanceValue] = ["memberId": .integer(704), "arrivedCount": .integer(2), "pendingCount": .integer(1), "refundedCount": .integer(0), "paidAmount": .null]
        head.merge(summary) { _, new in new }
        var value: [String: ClubGovernanceValue] = ["summary": .object(head), "records": .array(records), "tags": .array([]), "canEdit": .bool(true)]
        value.merge(extra) { _, new in new }; return .object(value)
    }
    private func record(_ status: String, key: String = "reg-1", occurredAt: String = "2026-09-05") -> ClubGovernanceValue {
        .object(["key": .string(key), "topicId": .integer(91), "title": .string(" Night run "), "occurredAt": .string(occurredAt), "statusCode": .string(status)])
    }

    func testListMetaFollowsMiniProgramPendingFirstRule() throws {
        let presentation = try ClubOpsCustomerListPresentation(value: list([
            item(1, extra: ["pendingCount": .integer(2), "lastTopicName": .string(" City walk "), "lastVisitDate": .string("2026-09-05")]),
            item(2, extra: ["pendingCount": .integer(1)]),
            item(3, extra: ["lastVisitDate": .string("2026-09-05T10:00:00")]),
            item(4, extra: ["lastVisitDate": .string("bad")]),
        ]))
        XCTAssertEqual(presentation.total, 4); XCTAssertEqual(presentation.monthNew, 1)
        XCTAssertEqual(presentation.rows.map(\.meta), [.pending(count: 2, topic: "City walk"), .pending(count: 1, topic: nil),
                                                       .verified(count: 3, monthDay: "09-05"), .verified(count: 3, monthDay: nil)])
    }

    func testListNameRemarkAndPhoneFallbacks() throws {
        let rows = try ClubOpsCustomerListPresentation(value: list([
            item(1, extra: ["displayName": .string("  "), "remark": .string(" VIP "), "phoneText": .string("138****0000")]),
            item(2, extra: ["displayName": .string("Ann"), "phoneText": .string("138****0001"), "phone": .string("13800000001")]),
        ])).rows
        XCTAssertNil(rows[0].displayName); XCTAssertTrue(rows[0].hasRemark); XCTAssertEqual(rows[0].subText, "VIP")
        XCTAssertEqual(rows[1].displayName, "Ann"); XCTAssertFalse(rows[1].hasRemark); XCTAssertEqual(rows[1].subText, "138****0001")
    }

    func testMalformedListFailsClosed() {
        for bad in [list([item(0)]), list([item(1), item(1)]), list([item(1, extra: ["pendingCount": .integer(-1)])]),
                    .object(["total": .integer(1), "items": .array([])]), .object(["total": .integer(1), "monthNew": .integer(0)])] {
            XCTAssertThrowsError(try ClubOpsCustomerListPresentation(value: bad))
        }
    }

    func testValidationAcceptsCancelledRecordsEmittedByBackend() throws {
        let value = detail(records: [record("CANCELLED"), record("REGISTERED", key: "reg-2"), record("CONTACTED", key: "reg-3")])
        XCTAssertNoThrow(try ClubGovernanceValidation.validate(value, operation: .customer, scope: scope))
        let presentation = try ClubOpsCustomerDetailPresentation(value: value, memberID: 704)
        XCTAssertEqual(presentation.records.map(\.status), [.cancelled, .registered, .contacted])
        XCTAssertThrowsError(try ClubGovernanceValidation.validate(detail(records: [record("LOST")]), operation: .customer, scope: scope))
        XCTAssertThrowsError(try ClubOpsCustomerDetailPresentation(value: detail(records: [record("LOST")]), memberID: 704))
    }

    func testDetailRecordDateTitleAndStatusMapping() throws {
        let presentation = try ClubOpsCustomerDetailPresentation(value: detail(records: [record("VERIFIED")]), memberID: 704)
        let row = try XCTUnwrap(presentation.records.first)
        XCTAssertEqual(row.id, "reg-1"); XCTAssertEqual(row.topicID, 91); XCTAssertEqual(row.title, "Night run")
        XCTAssertEqual(row.day, 5); XCTAssertEqual(row.month, 9)
        XCTAssertEqual(row.status.localizationKey, "clubOps.customer.status.VERIFIED")
        XCTAssertEqual(ClubOpsCustomerRecordStatus.allCases.count, 6)
    }

    func testPaidAmountIsHiddenNotZeroAndUsesTrimMoney() throws {
        XCTAssertNil(try ClubOpsCustomerDetailPresentation(value: detail(), memberID: 704).paidAmountText)
        XCTAssertNil(try ClubOpsCustomerDetailPresentation(value: detail(summary: ["paidAmount": .string("")]), memberID: 704).paidAmountText)
        XCTAssertEqual(try ClubOpsCustomerDetailPresentation(value: detail(summary: ["paidAmount": .integer(120)]), memberID: 704).paidAmountText, "¥120")
        XCTAssertEqual(try ClubOpsCustomerDetailPresentation(value: detail(summary: ["paidAmount": .decimal(88.5)]), memberID: 704).paidAmountText, "¥88.50")
        XCTAssertEqual(try ClubOpsCustomerDetailPresentation(value: detail(summary: ["paidAmount": .integer(0)]), memberID: 704).paidAmountText, "¥0")
        XCTAssertThrowsError(try ClubOpsCustomerDetailPresentation(value: detail(summary: ["paidAmount": .decimal(-1)]), memberID: 704))
    }

    func testInteractionRemarkTagsAndMemberMismatch() throws {
        let presentation = try ClubOpsCustomerDetailPresentation(value: detail(summary: ["lastInteractionTime": .string("2026-03-07 09:00:00")],
            extra: ["remark": .string(" likes tea "), "tags": .array([.string("Regular"), .object(["name": .string("VIP")])])]), memberID: 704)
        XCTAssertEqual(presentation.lastInteraction?.month, 3); XCTAssertEqual(presentation.lastInteraction?.day, 7)
        XCTAssertEqual(presentation.remark, "likes tea"); XCTAssertEqual(presentation.tags, ["Regular", "VIP"]); XCTAssertTrue(presentation.canEdit)
        XCTAssertNil(try ClubOpsCustomerDetailPresentation(value: detail(), memberID: 704).lastInteraction)
        XCTAssertThrowsError(try ClubOpsCustomerDetailPresentation(value: detail(), memberID: 705))
        XCTAssertThrowsError(try ClubOpsCustomerDetailPresentation(value: detail(), memberID: nil))
        XCTAssertThrowsError(try ClubOpsCustomerDetailPresentation(value: detail(extra: ["tags": .array([.string(" ")])]), memberID: 704))
    }

    func testTagDraftMirrorsMiniProgramLimitsAndDedupes() {
        var draft = ClubOpsCustomerTagRemarkDraft(tagsText: "A, B,A,,")
        XCTAssertEqual(draft.tags, ["A", "B"]); XCTAssertEqual(draft.tagsText, "A,B")
        XCTAssertNil(draft.add(" B ")); XCTAssertEqual(draft.tags, ["A", "B"])
        XCTAssertNil(draft.add("C,D")); XCTAssertEqual(draft.tags, ["A", "B", "C", "D"])
        XCTAssertEqual(draft.add(String(repeating: "x", count: 13)), .tagTooLong); XCTAssertEqual(draft.tags.count, 4)
        XCTAssertNil(draft.add("E,F,G,H")); XCTAssertEqual(draft.add("I"), .tooManyTags); XCTAssertEqual(draft.tags.count, 8)
        draft.remove(at: 0); draft.remove(at: 99); XCTAssertEqual(draft.tags.first, "B")
        XCTAssertEqual(ClubOpsCustomerTagRemarkDraft.issue(tagsText: "", remark: String(repeating: "备", count: 201)), .remarkTooLong)
        XCTAssertNil(ClubOpsCustomerTagRemarkDraft.issue(tagsText: "", remark: String(repeating: "备", count: 200)))
        XCTAssertEqual(ClubOpsCustomerTagRemarkDraft.Issue.tooManyTags.localizationKey, "clubOps.customer.issue.tooManyTags")
    }

    func testDraftTextStillProducesTheSameCommandFields() throws {
        var form = ClubGovernanceFormDraft(operation: .saveCustomer, scope: scope, seed: ["tags": .array([.string("A")]), "remark": .string("n")])
        var tags = ClubOpsCustomerTagRemarkDraft(tagsText: form.text["tags"] ?? "")
        XCTAssertNil(tags.add("B")); form.text["tags"] = tags.tagsText
        let command = try form.command()
        XCTAssertEqual(command.fields["tags"], .array([.string("A"), .string("B")]))
        XCTAssertEqual(command.fields["remark"], .string("n"))
        XCTAssertEqual(command.fields["requestId"], .string(form.requestID))
    }

    func testCustomerWriteUsesDirectoryGovernanceRuleAndFailsClosed() throws {
        XCTAssertEqual(ClubGovernanceMutation.saveCustomer.permission, "CUSTOMER_DIRECTORY")
        let command = try ClubGovernanceCommand(operation: .saveCustomer, scope: scope,
            values: ["tags": .array([]), "remark": .string("n"), "requestId": .string("test-operation")])
        func review(roles: [String], permissions: [String]) throws -> ClubGovernanceSnapshot {
            let access = try ClubGovernancePermissions(value: .object(["active": .bool(true), "club": .object(["id": .integer(81)]),
                "roleCodes": .array(roles.map(ClubGovernanceValue.string)), "permissions": .array(permissions.map(ClubGovernanceValue.string)),
                "canManageRoles": .bool(false)]), scope: scope)
            return .init(operation: .customer, scope: scope, permissions: access, value: detail())
        }
        XCTAssertThrowsError(try command.validateReview(review(roles: ["CLUB_OPERATOR"], permissions: ["club:member:list:read"]), accountID: 701))
        XCTAssertNoThrow(try command.validateReview(review(roles: ["CLUB_OPERATOR"], permissions: ["club:member:manage"]), accountID: 701))
        XCTAssertNoThrow(try command.validateReview(review(roles: ["CLUB_OWNER"], permissions: []), accountID: 701))
    }

    func testPageFailureCopyIsScopedToCustomerAndSettlementReads() {
        XCTAssertEqual(ClubOpsFailureCopy(operation: .customers, failure: .forbidden)?.titleKey, "clubOps.customers.forbidden")
        XCTAssertNil(ClubOpsFailureCopy(operation: .customers, failure: .forbidden)?.retryKey)
        XCTAssertEqual(ClubOpsFailureCopy(operation: .customers, failure: .malformed)?.retryKey, "clubOps.customers.retry")
        XCTAssertEqual(ClubOpsFailureCopy(operation: .customer, failure: .unknown(message: nil))?.titleKey, "clubOps.customer.failed")
        XCTAssertEqual(ClubOpsFailureCopy(operation: .settlement, failure: .malformed)?.titleKey, "clubOps.settlement.failed")
        XCTAssertNil(ClubOpsFailureCopy(operation: .settlement, failure: .forbidden))
        XCTAssertNil(ClubOpsFailureCopy(operation: .customers, failure: .signedOut))
        XCTAssertNil(ClubOpsFailureCopy(operation: .roles, failure: .malformed))
    }

    func testCustomerDetailPageStaysHiddenWithoutDirectoryCapability() {
        let page = ClubCustomerDetailPage.project(value: ClubCustomerDetailFixtureData.ready, memberID: 704, capability: .absent)
        XCTAssertTrue(page.hidden)
        XCTAssertNil(page.phase)
        XCTAssertNil(page.metrics)
        XCTAssertNil(page.detail)
        XCTAssertNil(page.displayName)
        XCTAssertFalse(ClubCustomerDetailPage.includedInPlayerFirstEntry)
        XCTAssertFalse(ClubCustomerDetailPage.routeMarkedLive)
        XCTAssertEqual(ClubCustomerDetailPage.readOperation, .customer)
        XCTAssertEqual(ClubCustomerDetailPage.readOperation.path, "api/club/crm/customers/detail")
        let scope = ClubCustomerDetailFixtureData.scope
        XCTAssertTrue(ClubCustomerDetailCapability(permissions: permissions(roles: ["CLUB_OWNER"], codes: []), scope: scope).granted)
        XCTAssertTrue(ClubCustomerDetailCapability(permissions: permissions(roles: ["CLUB_OPERATOR"], codes: ["club:member:manage"]), scope: scope).granted)
        XCTAssertFalse(ClubCustomerDetailCapability(permissions: permissions(roles: ["CLUB_OPERATOR"], codes: ["club:member:list:read"]), scope: scope).granted)
        XCTAssertFalse(ClubCustomerDetailCapability(permissions: permissions(roles: ["EVENT_CHECKIN"], codes: ["club:event:checkin"]), scope: scope).granted)
        XCTAssertFalse(ClubCustomerDetailCapability(permissions: nil, scope: scope).granted)
    }

    func testCustomerDetailPageLoadingEmptyReadyAndLiteralZero() throws {
        let loading = ClubCustomerDetailPage.loading(clientCapabilityPresent: true)
        XCTAssertEqual(loading.phase, .some(.loading))
        XCTAssertTrue(loading.hidden)
        XCTAssertNil(loading.metrics)
        let ready = ClubCustomerDetailPage.project(value: ClubCustomerDetailFixtureData.ready, memberID: 704, capability: .granted)
        XCTAssertEqual(ready.phase, .some(.ready))
        XCTAssertFalse(ready.hidden)
        XCTAssertEqual(ready.metrics?.arrived.literal, 2)
        XCTAssertEqual(ready.metrics?.pending.displayText, "1")
        XCTAssertEqual(ready.metrics?.refunded.literal, 0)
        XCTAssertEqual(ready.metrics?.refunded.displayText, "0")
        XCTAssertEqual(ready.paidAmount, .some(.withheld))
        XCTAssertNil(ready.paidAmount?.displayText)
        XCTAssertEqual(ready.detail?.memberID, 704)
        XCTAssertGreaterThan(ready.recordCount ?? 0, 0)
        let empty = ClubCustomerDetailPage.project(value: ClubCustomerDetailFixtureData.emptyBody, memberID: 704, capability: .granted)
        XCTAssertEqual(empty.phase, .some(.empty))
        XCTAssertEqual(empty.recordCount, 0)
        XCTAssertEqual(empty.metrics?.arrived.literal, 0)
        XCTAssertEqual(empty.metrics?.arrived.displayText, "0")
        XCTAssertEqual(empty.metrics?.pending.displayText, "0")
        XCTAssertEqual(empty.metrics?.refunded.displayText, "0")
        XCTAssertEqual(empty.paidAmount?.displayText, "¥0")
        XCTAssertFalse(empty.hasTagsOrRemark)
        let tagged = try taggedEmpty()
        let withTag = ClubCustomerDetailPage.project(value: tagged, memberID: 704, capability: .granted)
        XCTAssertEqual(withTag.phase, .some(.ready))
        XCTAssertTrue(withTag.hasTagsOrRemark)
        XCTAssertEqual(withTag.recordCount, 0)
    }

    func testCustomerDetailUnknownCountsAreEmDashNeverZero() {
        let page = ClubCustomerDetailPage.project(value: ClubCustomerDetailFixtureData.unknownCounts, memberID: 704, capability: .granted)
        XCTAssertEqual(page.phase, .some(.unknown))
        XCTAssertFalse(page.hidden)
        XCTAssertNil(page.detail)
        XCTAssertNil(page.recordCount)
        XCTAssertEqual(page.displayName, "Fixture customer")
        for count in [page.metrics?.arrived, page.metrics?.pending, page.metrics?.refunded] {
            XCTAssertNil(count?.literal)
            XCTAssertEqual(count?.displayText, "—")
            XCTAssertNotEqual(count?.displayText, "0")
        }
        XCTAssertEqual(page.paidAmount, .some(.unknown))
        XCTAssertEqual(page.paidAmount?.displayText, "—")
        XCTAssertEqual(ClubCustomerDetailCount.parse(.string("0")).displayText, "—")
        XCTAssertNil(ClubCustomerDetailCount.parse(.string("0")).literal)
        XCTAssertNil(ClubCustomerDetailCount.parse(.null).literal)
        XCTAssertNil(ClubCustomerDetailCount.parse(.decimal(2)).literal)
        XCTAssertNil(ClubCustomerDetailCount.parse(.integer(-1)).literal)
        XCTAssertEqual(ClubCustomerDetailCount.parse(.integer(0)).literal, 0)
        XCTAssertEqual(ClubCustomerDetailPaidAmount.parse(.string("88.50")), .unknown)
        XCTAssertEqual(ClubCustomerDetailPaidAmount.parse(.string("")), .withheld)
        XCTAssertEqual(ClubCustomerDetailPaidAmount.parse(.null), .withheld)
        XCTAssertEqual(ClubCustomerDetailPaidAmount.parse(.integer(0)).displayText, "¥0")
        let mismatch = ClubCustomerDetailPage.project(value: ClubCustomerDetailFixtureData.ready, memberID: 705, capability: .granted)
        XCTAssertEqual(mismatch.phase, .some(.error(.malformed)))
        XCTAssertNil(mismatch.metrics)
        XCTAssertNil(mismatch.detail)
        let missingRecords = ClubGovernanceFixtures.json(#"{"summary":{"memberId":704,"arrivedCount":1,"pendingCount":0,"refundedCount":0,"paidAmount":null},"tags":[]}"#)
        let broken = ClubCustomerDetailPage.project(value: missingRecords, memberID: 704, capability: .granted)
        XCTAssertEqual(broken.phase, .some(.error(.malformed)))
        XCTAssertNil(broken.metrics)
    }

    @MainActor func testCustomerDetailLoadUsesExistingReadAndHidesADeniedGrant() async {
        var reads = 0
        let denied = ClubGovernanceFixtureAccess()
        denied.onRead = { reads += 1 }
        let hidden = await ClubCustomerDetailPage.load(access: denied, scope: ClubCustomerDetailFixtureData.scope, capability: .absent)
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)
        XCTAssertEqual(reads, 0)
        let access = ClubGovernanceFixtureAccess()
        access.onRead = { reads += 1 }
        let loaded = await ClubCustomerDetailPage.load(access: access, scope: ClubCustomerDetailFixtureData.scope, capability: .granted)
        XCTAssertEqual(loaded.phase, .some(.ready))
        XCTAssertEqual(reads, 1)
        XCTAssertNil(loaded.detail?.paidAmountText)
        access.readFailure = .malformed
        let failed = await ClubCustomerDetailPage.load(access: access, scope: ClubCustomerDetailFixtureData.scope, capability: .granted)
        XCTAssertEqual(failed.phase, .some(.error(.malformed)))
        XCTAssertNil(failed.detail)
        access.readFailure = .forbidden
        let refused = await ClubCustomerDetailPage.load(access: access, scope: ClubCustomerDetailFixtureData.scope, capability: .granted)
        XCTAssertTrue(refused.hidden)
        XCTAssertNil(refused.detail)
        XCTAssertNil(refused.metrics)
    }

    private func permissions(roles: [String], codes: [String]) -> ClubGovernancePermissions? {
        try? ClubGovernancePermissions(value: .object([
            "active": .bool(true), "club": .object(["id": .integer(81)]),
            "roleCodes": .array(roles.map(ClubGovernanceValue.string)),
            "permissions": .array(codes.map(ClubGovernanceValue.string)),
            "canManageRoles": .bool(false)
        ]), scope: ClubCustomerDetailFixtureData.scope)
    }

    private func taggedEmpty() throws -> ClubGovernanceValue {
        var value = try XCTUnwrap(ClubCustomerDetailFixtureData.emptyBody.object)
        value["tags"] = .array([.string("Regular")])
        return .object(value)
    }

    func testPagesAppendDedupedUntilTotal() throws {
        // CLB-customers-01: MP customers/index.js:139,179-189.
        let size = ClubOpsCustomerListPresentation.pageSize
        func page(_ ids: ClosedRange<Int>, total: Int) throws -> ClubOpsCustomerListPresentation {
            try .init(value: .object(["total": .integer(total), "monthNew": .integer(0), "items": .array(ids.map { item($0) })]))
        }
        let first = try page(1...size, total: size + 3)
        XCTAssertTrue(first.hasMoreAfterFirstPage)
        let second = first.appending(try page((size - 1)...(size + 3), total: size + 3))
        XCTAssertEqual(second.list.rows.count, size + 3); XCTAssertFalse(second.hasMore)
        XCTAssertFalse(try page(1...3, total: 3).hasMoreAfterFirstPage)
        let fields = try ClubGovernanceRead.customers.fields(scope: .init(clubID: 81), options: ["pageNum": .integer(2), "pageSize": .integer(size)])
        XCTAssertEqual(fields["pageNum"], .integer(2)); XCTAssertEqual(fields["pageSize"], .integer(size))
        XCTAssertEqual(try ClubGovernanceRead.customers.fields(scope: .init(clubID: 81), options: [:])["pageNum"], .integer(1))
    }

    func testPhoneCallNeedsServerGrantAndMobileNumber() {
        // CLB-customer-detail-01 / CLB-checkin-detail-02: MP utils/club-phone-call.js.
        XCTAssertEqual(ClubPhoneCall.url(phoneText: " 13800138000 ", callable: true)?.absoluteString, "tel:13800138000")
        XCTAssertNil(ClubPhoneCall.url(phoneText: "13800138000", callable: false))
        XCTAssertNil(ClubPhoneCall.url(phoneText: "138****8000", callable: true))
        XCTAssertNil(ClubPhoneCall.url(phoneText: "仅主理人可见", callable: true))
        XCTAssertNil(ClubPhoneCall.url(phoneText: "23800138000", callable: true))
    }
}
